// Continuity.Codec.Dhall - Synchronous Import Resolver
//
// Security fix: local imports are now constrained to the directory tree
// rooted at base_dir.  A Dhall file with ./../../../../etc/shadow can no
// longer read arbitrary filesystem paths.
//
// Coverage fix: resolve_expr previously hit `default: return expr` for
// BoolNeq, ListAppend, Union, Combine, CombineTypes, Assert, Equiv, With,
// Merge, ToMap, Project, ProjectType, and Import-within-Let.  Any imports
// nested inside those constructs were silently left unresolved, producing
// Import nodes with null abs_path that panicked at eval time.  All variants
// are now handled.
//
// straylight.software · 2026

#pragma once

#include <filesystem>
#include <format>
#include <fstream>
#include <unordered_map>
#include <unordered_set>

#include "straylight/dhall/dhall.hpp"
#include "straylight/dhall/parser.hpp"

namespace continuity::dhall {

// ═══════════════════════════════════════════════════════════════════════════════
// IMPORT RESOLVER
// ═══════════════════════════════════════════════════════════════════════════════

class ImportResolver {
  Arena& arena_;
  Interner& interner_;

  // Parsed-AST cache: absolute path -> resolved expression.
  std::unordered_map<std::string, ExprPtr> cache_;

  // Cycle detection: paths currently being resolved.
  std::unordered_set<std::string> resolving_;

  // Sandbox root: all local imports must resolve within this directory tree.
  // If empty, uses base_dir as the sandbox (original behavior).
  std::filesystem::path sandbox_root_;

public:
  ImportResolver(Arena& arena, Interner& interner) : arena_(arena), interner_(interner) {}

  /// Set the sandbox root directory. All local imports must resolve within this tree.
  /// If not set, the base_dir passed to resolve() is used as the sandbox.
  void set_sandbox_root(const std::filesystem::path& root) {
    sandbox_root_ = std::filesystem::weakly_canonical(root);
  }

  // Resolve all imports in `expr`, treating `base_dir` as the root for
  // relative-path resolution.  Local imports that escape outside the sandbox
  // (via ../ traversal) are rejected with std::runtime_error.
  ExprPtr resolve(ExprPtr expr, const std::filesystem::path& base_dir);

  // Load, parse, and recursively resolve imports for a single file.
  ExprPtr load_file(const std::filesystem::path& path);

  std::size_t cache_size() const { return cache_.size(); }

private:
  std::string read_file(const std::filesystem::path& path);

  // Assert that `resolved` is inside the sandbox.  Throws on traversal.
  // Uses sandbox_root_ if set, otherwise falls back to base_dir.
  void check_path_confinement(const std::filesystem::path& resolved,
                              const std::filesystem::path& base_dir) {
    // Use sandbox_root if set, otherwise use base_dir
    const auto& sandbox = sandbox_root_.empty() ? base_dir : sandbox_root_;
    // Walk the resolved path's directory components looking for the base.
    // std::filesystem::path::lexically_relative throws no exception but
    // returns a path beginning with ".." when the target escapes the base.
    auto rel = resolved.lexically_relative(sandbox);
    // Empty result means paths share no common root — treat as escape.
    if (rel.empty() || rel.begin()->string() == "..") {
      throw std::runtime_error(
          std::format("Import path traversal rejected: '{}' escapes sandbox '{}'",
                      resolved.string(), sandbox.string()));
    }
  }

  ExprPtr resolve_expr(ExprPtr expr, const std::filesystem::path& base_dir);

  // Helper: clone a binop node with freshly resolved children.
  ExprPtr clone_binop(Expr::Kind kind, ExprPtr lhs, ExprPtr rhs) {
    auto* e = arena_.alloc<Expr>();
    e->kind = kind;
    e->binop = {lhs, rhs};
    return e;
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

inline std::string ImportResolver::read_file(const std::filesystem::path& path) {
  std::ifstream file(path, std::ios::ate | std::ios::binary);
  if (!file) {
    throw std::runtime_error(std::format("Cannot open file: {}", path.string()));
  }
  static constexpr std::size_t MAX_IMPORT_BYTES = 16ULL * 1024 * 1024;
  auto size = file.tellg();
  // size == -1: pseudo/special file. size == 0: valid empty file (parse will handle it).
  if (size < static_cast<std::streamoff>(0)) {
    throw std::runtime_error(
        std::format("Cannot determine size of pseudo-file: {}", path.string()));
  }
  if (static_cast<std::uint64_t>(size) > MAX_IMPORT_BYTES) {
    throw std::runtime_error(std::format("Import file exceeds size limit ({} > {} bytes): {}",
                                         static_cast<std::uint64_t>(size), MAX_IMPORT_BYTES,
                                         path.string()));
  }
  file.seekg(0);
  std::string content(static_cast<std::size_t>(size), '\0');
  file.read(content.data(), size);
  return content;
}

inline ExprPtr ImportResolver::load_file(const std::filesystem::path& path) {
  auto abs = std::filesystem::weakly_canonical(path);
  auto key = abs.string();

  if (auto it = cache_.find(key); it != cache_.end()) {
    return it->second;
  }

  if (resolving_.count(key)) {
    throw std::runtime_error(std::format("Import cycle detected: {}", key));
  }
  resolving_.insert(key);

  std::string source = read_file(abs);
  Parser parser(source, arena_, interner_);
  auto result = parser.parse();
  if (!result) {
    resolving_.erase(key);
    const auto& err = result.error();
    throw std::runtime_error(
        std::format("Parse error in {}:{}:{}: {}", key, err.line, err.col, err.message));
  }

  auto* resolved = resolve_expr(*result, abs.parent_path());
  resolving_.erase(key);
  cache_[key] = resolved;
  return resolved;
}

inline ExprPtr ImportResolver::resolve(ExprPtr expr, const std::filesystem::path& base_dir) {
  return resolve_expr(expr, base_dir);
}

inline ExprPtr ImportResolver::resolve_expr(ExprPtr expr, const std::filesystem::path& base_dir) {
  if (!expr) {
    return nullptr;
  }

  switch (expr->kind) {
      // ── Binding forms ────────────────────────────────────────────────────────

    case Expr::Kind::Var:
      return expr;

    case Expr::Kind::Lam: {
      auto* t = resolve_expr(expr->lam.type, base_dir);
      auto* b = resolve_expr(expr->lam.body, base_dir);
      if (t == expr->lam.type && b == expr->lam.body) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Lam;
      e->lam = {expr->lam.name, t, b};
      return e;
    }

    case Expr::Kind::Pi: {
      auto* d = resolve_expr(expr->pi.domain, base_dir);
      auto* c = resolve_expr(expr->pi.codomain, base_dir);
      if (d == expr->pi.domain && c == expr->pi.codomain) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Pi;
      e->pi = {expr->pi.name, d, c};
      return e;
    }

    case Expr::Kind::Let: {
      auto* t = expr->let.type ? resolve_expr(expr->let.type, base_dir) : nullptr;
      auto* v = resolve_expr(expr->let.value, base_dir);
      auto* b = resolve_expr(expr->let.body, base_dir);
      if (t == expr->let.type && v == expr->let.value && b == expr->let.body) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Let;
      e->let = {expr->let.name, t, v, b};
      return e;
    }

    case Expr::Kind::App: {
      auto* f = resolve_expr(expr->app.func, base_dir);
      auto* a = resolve_expr(expr->app.arg, base_dir);
      if (f == expr->app.func && a == expr->app.arg) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::App;
      e->app = {f, a};
      return e;
    }

      // ── Boolean binary operators ──────────────────────────────────────────────

    case Expr::Kind::BoolAnd:
    case Expr::Kind::BoolOr:
    case Expr::Kind::BoolEq:
    case Expr::Kind::BoolNeq: { // ← was missing
      auto* l = resolve_expr(expr->binop.lhs, base_dir);
      auto* r = resolve_expr(expr->binop.rhs, base_dir);
      if (l == expr->binop.lhs && r == expr->binop.rhs) {
        return expr;
      }
      return clone_binop(expr->kind, l, r);
    }

    case Expr::Kind::BoolIf: {
      auto* c = resolve_expr(expr->if_.cond, base_dir);
      auto* th = resolve_expr(expr->if_.then_, base_dir);
      auto* el = resolve_expr(expr->if_.else_, base_dir);
      if (c == expr->if_.cond && th == expr->if_.then_ && el == expr->if_.else_) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::BoolIf;
      e->if_ = {c, th, el};
      return e;
    }

      // ── Numeric / text / list operators ──────────────────────────────────────

    case Expr::Kind::NatPlus:
    case Expr::Kind::NatTimes:
    case Expr::Kind::TextAppend:
    case Expr::Kind::ListAppend: // ← was missing
    case Expr::Kind::Prefer:
    case Expr::Kind::Combine:        // ← was missing
    case Expr::Kind::CombineTypes: { // ← was missing
      auto* l = resolve_expr(expr->binop.lhs, base_dir);
      auto* r = resolve_expr(expr->binop.rhs, base_dir);
      if (l == expr->binop.lhs && r == expr->binop.rhs) {
        return expr;
      }
      return clone_binop(expr->kind, l, r);
    }

      // ── Collection literals ───────────────────────────────────────────────────

    case Expr::Kind::List: {
      bool changed = false;
      auto span = arena_.alloc_array<ExprPtr>(expr->list.count);
      for (std::size_t i = 0; i < expr->list.count; ++i) {
        span[i] = resolve_expr(expr->list.elems[i], base_dir);
        if (span[i] != expr->list.elems[i]) {
          changed = true;
        }
      }
      auto* t = expr->list.type ? resolve_expr(expr->list.type, base_dir) : nullptr;
      if (!changed && t == expr->list.type) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::List;
      e->list = {t, span.data(), span.size()};
      return e;
    }

    case Expr::Kind::RecordLit:
    case Expr::Kind::Record:
    case Expr::Kind::Union: { // ← Union was missing
      bool changed = false;
      auto* fields = arena_.alloc<Fields<ExprPtr>>();
      fields->reserve(expr->fields->size());
      for (const auto& entry : *expr->fields) {
        auto* rv = resolve_expr(entry.value, base_dir);
        if (rv != entry.value) {
          changed = true;
        }
        fields->push_back_unchecked(entry.name, rv);
      }
      if (!changed) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = expr->kind;
      e->fields = fields;
      return e;
    }

      // ── Field access / projection ─────────────────────────────────────────────

    case Expr::Kind::Field: {
      auto* r = resolve_expr(expr->field.record, base_dir);
      if (r == expr->field.record) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Field;
      e->field = {r, expr->field.name};
      return e;
    }

    case Expr::Kind::Project: { // ← was missing
      auto* r = resolve_expr(expr->project.record, base_dir);
      if (r == expr->project.record) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Project;
      e->project = {r, expr->project.field_names, expr->project.count};
      return e;
    }

    case Expr::Kind::ProjectType: { // ← was missing
      auto* r = resolve_expr(expr->project_type.record, base_dir);
      auto* t = resolve_expr(expr->project_type.type, base_dir);
      if (r == expr->project_type.record && t == expr->project_type.type) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::ProjectType;
      e->project_type = {r, t};
      return e;
    }

      // ── Record operations ─────────────────────────────────────────────────────

    case Expr::Kind::With: { // ← was missing
      auto* r = resolve_expr(expr->with.record, base_dir);
      auto* v = resolve_expr(expr->with.value, base_dir);
      if (r == expr->with.record && v == expr->with.value) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::With;
      e->with = {r, expr->with.path, expr->with.path_len, v};
      return e;
    }

    case Expr::Kind::Merge: { // ← was missing
      auto* h = resolve_expr(expr->merge.handler, base_dir);
      auto* u = resolve_expr(expr->merge.union_val, base_dir);
      auto* t = expr->merge.type ? resolve_expr(expr->merge.type, base_dir) : nullptr;
      if (h == expr->merge.handler && u == expr->merge.union_val && t == expr->merge.type) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Merge;
      e->merge = {h, u, t};
      return e;
    }

    case Expr::Kind::ToMap: { // ← was missing
      auto* r = resolve_expr(expr->tomap.record, base_dir);
      auto* t = expr->tomap.type ? resolve_expr(expr->tomap.type, base_dir) : nullptr;
      if (r == expr->tomap.record && t == expr->tomap.type) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::ToMap;
      e->tomap = {r, t};
      return e;
    }

      // ── Type-level operators ──────────────────────────────────────────────────

    case Expr::Kind::Assert: { // ← was missing
      auto* t = resolve_expr(expr->assert_.type, base_dir);
      if (t == expr->assert_.type) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Assert;
      e->assert_ = {t};
      return e;
    }

    case Expr::Kind::Equiv: { // ← was missing
      auto* l = resolve_expr(expr->equiv.lhs, base_dir);
      auto* r = resolve_expr(expr->equiv.rhs, base_dir);
      if (l == expr->equiv.lhs && r == expr->equiv.rhs) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Equiv;
      e->equiv = {l, r};
      return e;
    }

    case Expr::Kind::Annot: {
      auto* ex = resolve_expr(expr->annot.expr, base_dir);
      auto* t = resolve_expr(expr->annot.type, base_dir);
      if (ex == expr->annot.expr && t == expr->annot.type) {
        return expr;
      }
      auto* e = arena_.alloc<Expr>();
      e->kind = Expr::Kind::Annot;
      e->annot = {ex, t};
      return e;
    }

      // ── Import ────────────────────────────────────────────────────────────────

    case Expr::Kind::Import: {
      std::string_view path_sv(expr->import.path, expr->import.path_len);

      // HTTP imports are handled by AsyncImportResolver / Http2Fetcher.
      // The synchronous resolver only processes local (file-system) imports.
      if (expr->import.is_http) {
        return expr;
      }

      std::filesystem::path import_path(path_sv);
      std::filesystem::path resolved_abs = std::filesystem::weakly_canonical(
          import_path.is_relative() ? base_dir / import_path : import_path);

      // ── Path traversal guard ────────────────────────────────────────────
      // Dhall's import security model requires that a local import cannot
      // escape its own directory tree.  Reject any path whose canonical form
      // does not start with the sandbox root (base_dir).
      check_path_confinement(resolved_abs, std::filesystem::weakly_canonical(base_dir));

      return load_file(resolved_abs);
    }

      // ── Literals and builtins (no child expressions to recurse into) ──────────

    case Expr::Kind::Const:
    case Expr::Kind::Builtin:
    case Expr::Kind::Lit:
    default:
      return expr;
  }
}

} // namespace continuity::dhall
