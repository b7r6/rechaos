// Continuity.Codec.Dhall - Parser
// LL(k) with precedence climbing
// Target: <2ms for sensenet's 12K LOC
//
// straylight.software · 2026

#pragma once

#include <expected>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "straylight/dhall/dhall.hpp"
#include "straylight/dhall/lexer.hpp"

namespace continuity::dhall {

// ═══════════════════════════════════════════════════════════════════════════════
// PARSE ERROR
// ═══════════════════════════════════════════════════════════════════════════════

struct ParseError {
  std::string message;
  std::uint32_t offset;
  std::uint32_t line;
  std::uint32_t col;
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER
// ═══════════════════════════════════════════════════════════════════════════════

class Parser {
  Lexer lexer_;
  std::string_view src_;
  Arena& arena_;
  Interner& interner_;

  Token current_;
  Token lookahead_[3]; // LL(4)
  int la_count_ = 0;

  // Scope tracking for de Bruijn index resolution
  // Each entry is a variable name; innermost bindings are at the back
  std::vector<Name> scope_;

  // Resolve a variable name to its de Bruijn index
  // Returns the number of bindings between the reference and the definition
  std::optional<std::uint32_t> resolve_var(Name name) const {
    // Search from innermost (back) to outermost (front)
    for (std::size_t i = scope_.size(); i > 0; --i) {
      if (scope_[i - 1] == name) {
        return static_cast<std::uint32_t>(scope_.size() - i);
      }
    }
    return std::nullopt; // Free variable
  }

  // RAII scope guard for pushing/popping bindings
  struct ScopeGuard {
    Parser& p;
    ScopeGuard(Parser& p, Name n) : p(p) { p.scope_.push_back(n); }
    ~ScopeGuard() { p.scope_.pop_back(); }
  };

public:
  Parser(std::string_view source, Arena& arena, Interner& interner)
      : lexer_(source), src_(source), arena_(arena), interner_(interner) {
    advance(); // Load first token
  }

  std::expected<ExprPtr, ParseError> parse();

private:
  // Token management
  void advance();
  Token peek(int n = 0);
  bool match(TokenKind k);
  bool check(TokenKind k);
  std::expected<void, ParseError> expect(TokenKind k, const char* msg);

  // Error helper
  ParseError error(const char* msg);

  // Expression parsers (precedence climbing)
  ExprPtr parse_expression();
  ExprPtr parse_annotated();
  ExprPtr parse_operator(int min_prec);
  ExprPtr parse_with(); // expr with path = value chains
  ExprPtr parse_application();
  ExprPtr parse_import();
  ExprPtr parse_selector(); // field access only (no with)
  ExprPtr parse_primitive();

  // Specific constructs
  ExprPtr parse_lambda();
  ExprPtr parse_forall();
  ExprPtr parse_if();
  ExprPtr parse_let();
  ExprPtr parse_merge();
  ExprPtr parse_assert();
  ExprPtr parse_tomap();
  ExprPtr parse_record();
  ExprPtr parse_union();
  ExprPtr parse_list();
  ExprPtr parse_text();

  // Operator precedence
  static int get_precedence(TokenKind k);
  static bool is_right_assoc(TokenKind k);

  // Allocation helpers
  template <typename T, typename... Args>
  T* alloc(Args&&... args) {
    return arena_.alloc<T>(std::forward<Args>(args)...);
  }

  ExprPtr mkConst(Const c);
  ExprPtr mkVar(std::uint32_t idx);
  ExprPtr mkBuiltin(Builtin b);
  ExprPtr mkLit(Lit l);
  ExprPtr mkLam(Name n, ExprPtr type, ExprPtr body);
  ExprPtr mkPi(Name n, ExprPtr domain, ExprPtr codomain);
  ExprPtr mkApp(ExprPtr f, ExprPtr x);
  ExprPtr mkLet(Name n, ExprPtr type, ExprPtr value, ExprPtr body);
  ExprPtr mkBinop(Expr::Kind kind, ExprPtr lhs, ExprPtr rhs);
  ExprPtr mkIf(ExprPtr cond, ExprPtr then_, ExprPtr else_);
  ExprPtr mkList(ExprPtr type, std::vector<ExprPtr>& elems);
  ExprPtr mkRecordLit(Fields<ExprPtr>* fields);
  ExprPtr mkRecord(Fields<ExprPtr>* fields);
  ExprPtr mkUnion(Fields<ExprPtr>* fields);
  ExprPtr mkField(ExprPtr record, Name name);
  ExprPtr mkAnnot(ExprPtr expr, ExprPtr type);
  ExprPtr mkImport(std::string_view path, std::string_view hash = {}, bool is_http = false);

  /// Shift de Bruijn indices in an expression by `amount` for indices >= `cutoff`
  ExprPtr shift(ExprPtr e, int amount, std::uint32_t cutoff = 0);
};

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

inline void Parser::advance() {
  if (la_count_ > 0) {
    current_ = lookahead_[0];
    for (int i = 0; i < la_count_ - 1; ++i) {
      lookahead_[i] = lookahead_[i + 1];
    }
    --la_count_;
  } else {
    current_ = lexer_.next();
  }
}

inline Token Parser::peek(int n) {
  if (n == 0) {
    return current_;
  }

  // Fill lookahead buffer as needed
  while (la_count_ < n) {
    lookahead_[la_count_++] = lexer_.next();
  }
  return lookahead_[n - 1];
}

inline bool Parser::match(TokenKind k) {
  if (current_.kind == k) {
    advance();
    return true;
  }
  return false;
}

inline bool Parser::check(TokenKind k) {
  return current_.kind == k;
}

inline std::expected<void, ParseError> Parser::expect(TokenKind k, const char* msg) {
  if (!match(k)) {
    return std::unexpected(error(msg));
  }
  return {};
}

inline ParseError Parser::error(const char* msg) {
  return {msg, current_.offset, lexer_.line(), lexer_.col()};
}

// Operator precedence (higher = tighter binding)
// Based on Dhall spec
inline int Parser::get_precedence(TokenKind k) {
  switch (k) {
    case TokenKind::Arrow:
      return 1; // -> (function type, right-assoc)
    case TokenKind::Equivalent:
      return 2; // ===
    case TokenKind::Alternative:
      return 3; // Import fallback ?
    case TokenKind::Or:
      return 4; // ||
    case TokenKind::Plus:
      return 5; // +
    case TokenKind::TextAppend:
      return 6; // ++
    case TokenKind::ListAppend:
      return 7; // #
    case TokenKind::And:
      return 8; // &&
    case TokenKind::Combine:
      return 9; // /backslash
    case TokenKind::Prefer:
      return 10; // //
    case TokenKind::CombineTypes:
      return 11; // //backslash backslash
    case TokenKind::DoubleColon:
      return 12; // :: (completion)
    case TokenKind::Times:
      return 13; // *
    case TokenKind::NotEqual:
      return 14; // !=
    case TokenKind::DoubleEqual:
      return 14; // == (equality comparison, same precedence as !=)
    // NOTE: Equal (=) is NOT an operator - it's syntax for assignment
    default:
      return 0; // Not an operator
  }
}

inline bool Parser::is_right_assoc(TokenKind k) {
  // In Dhall, most operators are right-associative
  switch (k) {
    case TokenKind::Arrow: // -> is right-assoc
    case TokenKind::Alternative:
      return true;
    default:
      return false;
  }
}

inline ExprPtr Parser::mkConst(Const c) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Const;
  e->const_val = c;
  return e;
}

inline ExprPtr Parser::mkVar(std::uint32_t idx) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Var;
  e->var_idx = idx;
  return e;
}

inline ExprPtr Parser::mkBuiltin(Builtin b) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Builtin;
  e->builtin = b;
  return e;
}

inline ExprPtr Parser::mkLit(Lit l) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Lit;
  e->lit = l;
  return e;
}

inline ExprPtr Parser::mkLam(Name n, ExprPtr type, ExprPtr body) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Lam;
  e->lam = {n, type, body};
  return e;
}

inline ExprPtr Parser::mkPi(Name n, ExprPtr domain, ExprPtr codomain) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Pi;
  e->pi = {n, domain, codomain};
  return e;
}

inline ExprPtr Parser::mkApp(ExprPtr f, ExprPtr x) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::App;
  e->app = {f, x};
  return e;
}

inline ExprPtr Parser::mkLet(Name n, ExprPtr type, ExprPtr value, ExprPtr body) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Let;
  e->let = {n, type, value, body};
  return e;
}

inline ExprPtr Parser::mkBinop(Expr::Kind kind, ExprPtr lhs, ExprPtr rhs) {
  auto* e = alloc<Expr>();
  e->kind = kind;
  e->binop = {lhs, rhs};
  return e;
}

inline ExprPtr Parser::mkIf(ExprPtr cond, ExprPtr then_, ExprPtr else_) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::BoolIf;
  e->if_ = {cond, then_, else_};
  return e;
}

inline ExprPtr Parser::mkList(ExprPtr type, std::vector<ExprPtr>& elems) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::List;
  auto span = arena_.alloc_array<ExprPtr>(elems.size());
  for (std::size_t i = 0; i < elems.size(); ++i) {
    span[i] = elems[i];
  }
  e->list = {type, span.data(), span.size()};
  return e;
}

inline ExprPtr Parser::mkRecordLit(Fields<ExprPtr>* fields) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::RecordLit;
  e->fields = fields;
  return e;
}

inline ExprPtr Parser::mkRecord(Fields<ExprPtr>* fields) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Record;
  e->fields = fields;
  return e;
}

inline ExprPtr Parser::mkUnion(Fields<ExprPtr>* fields) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Union;
  e->fields = fields;
  return e;
}

inline ExprPtr Parser::mkField(ExprPtr record, Name name) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Field;
  e->field = {record, name};
  return e;
}

inline ExprPtr Parser::mkAnnot(ExprPtr expr, ExprPtr type) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Annot;
  e->annot = {expr, type};
  return e;
}

inline ExprPtr Parser::mkImport(std::string_view path, std::string_view hash, bool is_http) {
  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Import;
  // Copy path to arena for stable storage
  char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(path.size() + 1).data());
  std::copy(path.begin(), path.end(), data);
  data[path.size()] = '\0';

  // Copy hash if present
  const char* hash_data = nullptr;
  if (!hash.empty()) {
    char* hd = reinterpret_cast<char*>(arena_.alloc_array<char>(hash.size() + 1).data());
    std::copy(hash.begin(), hash.end(), hd);
    hd[hash.size()] = '\0';
    hash_data = hd;
  }

  e->import = {data, path.size(), nullptr, 0, hash_data, hash.size(), is_http};
  return e;
}

/// Shift de Bruijn indices in an expression by `amount` for indices >= `cutoff`
inline ExprPtr Parser::shift(ExprPtr e, int amount, std::uint32_t cutoff) {
  if (!e) {
    return nullptr;
  }

  switch (e->kind) {
    case Expr::Kind::Const:
    case Expr::Kind::Builtin:
    case Expr::Kind::Lit:
    case Expr::Kind::Import:
      return e; // No variables to shift

    case Expr::Kind::Var:
      if (e->var_idx >= cutoff) {
        auto* ne = alloc<Expr>();
        ne->kind = Expr::Kind::Var;
        ne->var_idx = static_cast<std::uint32_t>(static_cast<int>(e->var_idx) + amount);
        return ne;
      }
      return e;

    case Expr::Kind::Lam: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Lam;
      ne->lam = {e->lam.name, shift(e->lam.type, amount, cutoff),
                 shift(e->lam.body, amount, cutoff + 1)};
      return ne;
    }

    case Expr::Kind::Pi: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Pi;
      ne->pi = {e->pi.name, shift(e->pi.domain, amount, cutoff),
                shift(e->pi.codomain, amount, cutoff + 1)};
      return ne;
    }

    case Expr::Kind::App: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::App;
      ne->app = {shift(e->app.func, amount, cutoff), shift(e->app.arg, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::Let: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Let;
      ne->let = {e->let.name, e->let.type ? shift(e->let.type, amount, cutoff) : nullptr,
                 shift(e->let.value, amount, cutoff), shift(e->let.body, amount, cutoff + 1)};
      return ne;
    }

    case Expr::Kind::BoolAnd:
    case Expr::Kind::BoolOr:
    case Expr::Kind::BoolEq:
    case Expr::Kind::BoolNeq:
    case Expr::Kind::NatPlus:
    case Expr::Kind::NatTimes:
    case Expr::Kind::TextAppend:
    case Expr::Kind::ListAppend:
    case Expr::Kind::Prefer: {
      auto* ne = alloc<Expr>();
      ne->kind = e->kind;
      ne->binop = {shift(e->binop.lhs, amount, cutoff), shift(e->binop.rhs, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::BoolIf: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::BoolIf;
      ne->if_ = {shift(e->if_.cond, amount, cutoff), shift(e->if_.then_, amount, cutoff),
                 shift(e->if_.else_, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::List: {
      auto span = arena_.alloc_array<ExprPtr>(e->list.count);
      for (std::size_t i = 0; i < e->list.count; ++i) {
        span[i] = shift(e->list.elems[i], amount, cutoff);
      }
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::List;
      ne->list = {e->list.type ? shift(e->list.type, amount, cutoff) : nullptr, span.data(),
                  e->list.count};
      return ne;
    }

    case Expr::Kind::RecordLit:
    case Expr::Kind::Record: {
      auto* fs = alloc<Fields<ExprPtr>>();
      fs->reserve(e->fields->size());
      for (const auto& entry : *e->fields) {
        fs->push_back_unchecked(entry.name, shift(entry.value, amount, cutoff));
      }
      auto* ne = alloc<Expr>();
      ne->kind = e->kind;
      ne->fields = fs;
      return ne;
    }

    case Expr::Kind::Field: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Field;
      ne->field = {shift(e->field.record, amount, cutoff), e->field.name};
      return ne;
    }

    case Expr::Kind::Annot: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Annot;
      ne->annot = {shift(e->annot.expr, amount, cutoff), shift(e->annot.type, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::Project: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Project;
      ne->project = {shift(e->project.record, amount, cutoff), e->project.field_names,
                     e->project.count};
      return ne;
    }

    case Expr::Kind::ProjectType: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::ProjectType;
      ne->project_type = {shift(e->project_type.record, amount, cutoff),
                          shift(e->project_type.type, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::Combine:
    case Expr::Kind::CombineTypes: {
      auto* ne = alloc<Expr>();
      ne->kind = e->kind;
      ne->binop = {shift(e->binop.lhs, amount, cutoff), shift(e->binop.rhs, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::Assert: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Assert;
      ne->assert_ = {shift(e->assert_.type, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::Equiv: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Equiv;
      ne->equiv = {shift(e->equiv.lhs, amount, cutoff), shift(e->equiv.rhs, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::With: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::With;
      ne->with = {shift(e->with.record, amount, cutoff), e->with.path, e->with.path_len,
                  shift(e->with.value, amount, cutoff)};
      return ne;
    }

    case Expr::Kind::Merge: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::Merge;
      ne->merge = {shift(e->merge.handler, amount, cutoff),
                   shift(e->merge.union_val, amount, cutoff),
                   e->merge.type ? shift(e->merge.type, amount, cutoff) : nullptr};
      return ne;
    }

    case Expr::Kind::ToMap: {
      auto* ne = alloc<Expr>();
      ne->kind = Expr::Kind::ToMap;
      ne->tomap = {shift(e->tomap.record, amount, cutoff),
                   e->tomap.type ? shift(e->tomap.type, amount, cutoff) : nullptr};
      return ne;
    }
  }

  return e;
}

} // namespace continuity::dhall
