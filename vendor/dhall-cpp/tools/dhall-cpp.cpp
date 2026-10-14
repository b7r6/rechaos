// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//                                                           // rechaos // vendor // dhall-cpp
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
//   command-line driver: parse, resolve local imports, normalize, emit JSON
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Usage:
//   dhall-cpp to-json FILE     normalize FILE and print its JSON, following the
//                              conventions of the reference `dhall-to-json`:
//                              None fields omitted, Some x as x, homogeneous
//                              lists of {mapKey, mapValue} as objects, keys sorted
//   dhall-cpp check FILE       parse, resolve, normalize; print nothing (exit 0 or 1)
//   dhall-cpp normalize FILE   print the normal form as Dhall text
//
// n.b. There is no type checker in this evaluator; `check` is not `dhall type`.
// See ../NOTICE.md.

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <format>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include <spdlog/spdlog.h>

#include "straylight/dhall/import.hpp"
#include "straylight/dhall/parser.hpp"

namespace fs = std::filesystem;
using namespace continuity::dhall;

namespace {

struct NotConvertible : std::runtime_error {
  using std::runtime_error::runtime_error;
};

void write_json_string(std::string& out, std::string_view s) {
  out.push_back('"');
  for (unsigned char c : s) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (c < 0x20) {
          out += std::format("\\u{:04x}", static_cast<unsigned>(c));
        } else {
          out.push_back(static_cast<char>(c));
        }
    }
  }
  out.push_back('"');
}

bool is_none(ValuePtr v) {
  return v->kind == Value::Kind::Builtin && v->builtin.b == Builtin::None && v->builtin.args &&
         v->builtin.args->size() == 1;
}

bool is_some(ValuePtr v) {
  return v->kind == Value::Kind::Builtin && v->builtin.b == Builtin::Some && v->builtin.args &&
         v->builtin.args->size() == 1;
}

bool is_text(ValuePtr v) { return v->kind == Value::Kind::Lit && v->lit.kind == Lit::Kind::Text; }

// Look through any number of Some wrappers: dhall-to-json renders Some x as x,
// so a None under a Some is still an absent field.
ValuePtr strip_some(ValuePtr v) {
  while (is_some(v)) {
    v = (*v->builtin.args)[0];
  }
  return v;
}

// The record type { mapKey : Text, mapValue : _ }: what an empty annotated map
// carries as its element type.
bool is_map_type(Interner& interner, ValuePtr type) {
  if (!type || type->kind != Value::Kind::Record || !type->fields || type->fields->size() != 2) {
    return false;
  }
  ValuePtr* key = type->fields->lookup(interner.intern("mapKey"));
  ValuePtr* value = type->fields->lookup(interner.intern("mapValue"));
  return key && value && (*key)->kind == Value::Kind::Builtin && (*key)->builtin.b == Builtin::Text;
}

// A list whose every element is a record with exactly mapKey : Text and
// mapValue, which dhall-to-json renders as an object (the default --maps). An
// empty list counts when its annotation says so.
bool is_map(Interner& interner, ValuePtr v) {
  if (v->kind != Value::Kind::List || !v->list.elems) {
    return false;
  }
  if (v->list.elems->empty()) {
    return is_map_type(interner, v->list.type);
  }
  for (ValuePtr e : *v->list.elems) {
    if (e->kind != Value::Kind::RecordLit || !e->fields || e->fields->size() != 2) {
      return false;
    }
    ValuePtr* key = e->fields->lookup(interner.intern("mapKey"));
    ValuePtr* value = e->fields->lookup(interner.intern("mapValue"));
    if (!key || !value || !is_text(*key)) {
      return false;
    }
  }
  return true;
}

class JsonEmitter {
  Interner& interner_;
  std::string out_;

  void emit_lit(const Lit& lit) {
    switch (lit.kind) {
      case Lit::Kind::Bool: out_ += lit.b ? "true" : "false"; break;
      case Lit::Kind::Nat: out_ += std::to_string(lit.n); break;
      case Lit::Kind::Int: out_ += std::to_string(lit.i); break;
      case Lit::Kind::Double:
        if (!std::isfinite(lit.d)) {
          throw NotConvertible("non-finite Double cannot be rendered as JSON");
        }
        out_ += std::format("{}", lit.d);
        break;
      case Lit::Kind::Text: write_json_string(out_, std::string_view(lit.text.data, lit.text.len)); break;
      case Lit::Kind::BigInt:
        // The evaluator keeps integers past 64 bits as a double; the digits are
        // gone, so refuse rather than print an approximation with exit 0.
        throw NotConvertible("integer literal beyond 64 bits cannot be rendered exactly");
      case Lit::Kind::Bytes: throw NotConvertible("Bytes cannot be rendered as JSON");
    }
  }

  void emit_object(const Fields<ValuePtr>& fields) {
    std::vector<std::pair<std::string_view, ValuePtr>> sorted;
    sorted.reserve(fields.size());
    for (const auto& entry : fields) {
      if (is_none(strip_some(entry.value))) {
        continue;  // dhall-to-json omits null-valued fields by default, through Some
      }
      sorted.emplace_back(interner_.get(entry.name), entry.value);
    }
    std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) { return a.first < b.first; });
    out_.push_back('{');
    bool first = true;
    for (const auto& [name, value] : sorted) {
      if (!first) out_.push_back(',');
      first = false;
      write_json_string(out_, name);
      out_.push_back(':');
      emit(value);
    }
    out_.push_back('}');
  }

  void emit_map(ValuePtr list) {
    // Last write wins on a duplicate key, as the reference's object does.
    std::vector<std::pair<std::string_view, ValuePtr>> entries;
    Name key_name = interner_.intern("mapKey");
    Name value_name = interner_.intern("mapValue");
    for (ValuePtr e : *list->list.elems) {
      ValuePtr key = *e->fields->lookup(key_name);
      ValuePtr value = *e->fields->lookup(value_name);
      std::string_view name(key->lit.text.data, key->lit.text.len);
      auto existing = std::find_if(entries.begin(), entries.end(), [&](const auto& kv) { return kv.first == name; });
      if (existing != entries.end()) {
        existing->second = value;
      } else {
        entries.emplace_back(name, value);
      }
    }
    out_.push_back('{');
    bool first = true;
    for (const auto& [name, value] : entries) {
      if (!first) out_.push_back(',');
      first = false;
      write_json_string(out_, name);
      out_.push_back(':');
      emit(value);
    }
    out_.push_back('}');
  }

 public:
  explicit JsonEmitter(Interner& interner) : interner_(interner) {}

  void emit(ValuePtr v) {
    if (!v) throw NotConvertible("null value");
    if (is_none(v)) {
      out_ += "null";
      return;
    }
    if (is_some(v)) {
      emit((*v->builtin.args)[0]);
      return;
    }
    switch (v->kind) {
      case Value::Kind::Lit: emit_lit(v->lit); return;
      case Value::Kind::RecordLit:
        if (!v->fields) {
          out_ += "{}";
          return;
        }
        emit_object(*v->fields);
        return;
      case Value::Kind::List: {
        if (is_map(interner_, v)) {
          emit_map(v);
          return;
        }
        out_.push_back('[');
        bool first = true;
        if (v->list.elems) {
          for (ValuePtr e : *v->list.elems) {
            if (!first) out_.push_back(',');
            first = false;
            emit(e);
          }
        }
        out_.push_back(']');
        return;
      }
      case Value::Kind::Field:
        // A nullary constructor selected from a union type that the evaluator
        // left as a field access: dhall-to-json renders it as its name.
        if (v->field.record->kind == Value::Kind::Union) {
          write_json_string(out_, interner_.get(v->field.name));
          return;
        }
        throw NotConvertible("stuck field access cannot be rendered as JSON");
      default:
        throw NotConvertible(std::format("value of kind {} cannot be rendered as JSON",
                                         static_cast<int>(v->kind)));
    }
  }

  std::string take() { return std::move(out_); }
};

std::string read_file(const fs::path& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) throw std::runtime_error(std::format("cannot open {}", path.string()));
  std::ostringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

int usage() {
  std::fprintf(stderr, "usage: dhall-cpp (to-json|check|normalize) FILE\n");
  return 2;
}

}  // namespace

int main(int argc, char** argv) {
  // stdout is the JSON and nothing else; the evaluator's logging is silenced.
  spdlog::set_level(spdlog::level::off);
  if (argc != 3) return usage();
  std::string_view command = argv[1];
  fs::path path = fs::absolute(argv[2]);
  if (command != "to-json" && command != "check" && command != "normalize") return usage();
  try {
    std::string source = read_file(path);
    Arena arena;
    Interner interner;
    Parser parser(source, arena, interner);
    auto parsed = parser.parse();
    if (!parsed) {
      std::fprintf(stderr, "%s: parse error: %s\n", argv[2], parsed.error().message.c_str());
      return 1;
    }
    ImportResolver resolver(arena, interner);
    // Local imports may reach anywhere on the filesystem, as the reference does;
    // the sandbox is the root.
    resolver.set_sandbox_root(fs::path("/"));
    ExprPtr resolved = resolver.resolve(*parsed, path.parent_path());
    Evaluator evaluator(arena, interner);
    evaluator.set_fuel(0);  // trusted local inputs: no step budget, like the reference
    Env env;
    ValuePtr value = evaluator.eval(env, resolved);
    if (command == "check") return 0;
    if (command == "normalize") {
      std::string text = serialize(interner, value);
      std::fwrite(text.data(), 1, text.size(), stdout);
      std::fputc('\n', stdout);
      return 0;
    }
    JsonEmitter emitter(interner);
    emitter.emit(value);
    std::string json = emitter.take();
    std::fwrite(json.data(), 1, json.size(), stdout);
    std::fputc('\n', stdout);
    return 0;
  } catch (const std::exception& e) {
    std::fprintf(stderr, "%s: %s\n", argv[2], e.what());
    return 1;
  }
}
