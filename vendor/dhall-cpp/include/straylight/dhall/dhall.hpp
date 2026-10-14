// Continuity.Codec.Dhall - C++23 NbE Evaluator
// Generated from Lean4 specification via Pretty.lean
// Target: <10ms for sensenet's 12K LOC configs
//
// straylight.software · 2026

#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <functional>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <variant>
#include <vector>

#include <spdlog/spdlog.h>

namespace continuity::dhall {

// ═══════════════════════════════════════════════════════════════════════════════
// ARENA ALLOCATOR
// ═══════════════════════════════════════════════════════════════════════════════

class Arena {
  struct Block {
    static constexpr std::size_t SIZE = 1024 * 1024; // 1MB
    alignas(64) std::byte data[SIZE];
    std::size_t used = 0;
  };

  std::vector<std::unique_ptr<Block>> blocks_;
  Block* current_ = nullptr;

public:
  Arena() {
    blocks_.push_back(std::make_unique<Block>());
    current_ = blocks_.back().get();
  }

  template <typename T, typename... Args>
  T* alloc(Args&&... args) {
    constexpr std::size_t align = alignof(T);
    constexpr std::size_t size = sizeof(T);

    std::size_t offset = (current_->used + align - 1) & ~(align - 1);
    if (offset + size > Block::SIZE) {
      blocks_.push_back(std::make_unique<Block>());
      current_ = blocks_.back().get();
      offset = 0;
    }

    void* ptr = current_->data + offset;
    current_->used = offset + size;
    return new (ptr) T(std::forward<Args>(args)...);
  }

  template <typename T>
  std::span<T> alloc_array(std::size_t n) {
    constexpr std::size_t align = alignof(T);
    std::size_t size = sizeof(T) * n;

    std::size_t offset = (current_->used + align - 1) & ~(align - 1);
    if (offset + size > Block::SIZE) {
      blocks_.push_back(std::make_unique<Block>());
      current_ = blocks_.back().get();
      offset = 0;
    }

    T* ptr = reinterpret_cast<T*>(current_->data + offset);
    current_->used = offset + size;
    for (std::size_t i = 0; i < n; ++i) {
      new (ptr + i) T();
    }
    return {ptr, n};
  }

  void reset() {
    for (auto& b : blocks_) {
      b->used = 0;
    }
    current_ = blocks_.front().get();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNED NAMES
// ═══════════════════════════════════════════════════════════════════════════════

struct Name {
  std::uint32_t id;
  std::uint32_t hash;

  bool operator==(const Name& o) const { return id == o.id; }
  bool operator<(const Name& o) const { return id < o.id; }
};

class Interner {
  // String interner - stores unique strings and returns handles
  std::unordered_map<std::string, std::uint32_t> lookup_;
  std::vector<std::string_view> by_id_; // points into lookup_ keys (stable after insert)

public:
  Name intern(std::string_view s) {
    // Convert to string for lookup (std::unordered_map lacks heterogeneous lookup)
    std::string key(s);
    if (auto it = lookup_.find(key); it != lookup_.end()) {
      return {it->second, hash(s)};
    }
    std::uint32_t id = static_cast<std::uint32_t>(by_id_.size());
    auto [it, _] = lookup_.emplace(std::move(key), id);
    by_id_.push_back(it->first); // string_view into map's key (stable)
    return {id, hash(s)};
  }

  std::string_view get(Name n) const { return by_id_[n.id]; }

private:
  static std::uint32_t hash(std::string_view s) {
    std::uint32_t h = 0x811c9dc5;
    for (char c : s) {
      h = (h ^ static_cast<std::uint8_t>(c)) * 0x01000193;
    }
    return h;
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS & BUILTINS
// ═══════════════════════════════════════════════════════════════════════════════

enum class Const : std::uint8_t { Type, Kind, Sort };

enum class Builtin : std::uint8_t {
  Natural,
  NaturalFold,
  NaturalBuild,
  NaturalIsZero,
  NaturalEven,
  NaturalOdd,
  NaturalToInteger,
  NaturalShow,
  NaturalSubtract,
  Integer,
  IntegerClamp,
  IntegerNegate,
  IntegerShow,
  IntegerToDouble,
  Double,
  DoubleShow,
  Text,
  TextShow,
  TextReplace,
  List,
  ListBuild,
  ListFold,
  ListLength,
  ListHead,
  ListLast,
  ListIndexed,
  ListReverse,
  Optional,
  None,
  Some,
  Bool,
  ShowConstructor,
  Bytes,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LITERALS
// ═══════════════════════════════════════════════════════════════════════════════

struct Lit {
  enum class Kind : std::uint8_t { Bool, Nat, Int, Double, Text, BigInt, Bytes };
  Kind kind;
  union {
    bool b;
    std::uint64_t n;
    std::int64_t i;
    double d;
    struct {
      const char* data;
      std::size_t len;
    } text;
    struct {
      double value;  // Double representation of the big integer
      bool negative; // Sign of the big integer
    } big_int;
    struct {
      const char* data;
      std::size_t len;
    } bytes;
  };

  static Lit Bool(bool v) {
    Lit l;
    l.kind = Kind::Bool;
    l.b = v;
    return l;
  }
  static Lit Nat(std::uint64_t v) {
    Lit l;
    l.kind = Kind::Nat;
    l.n = v;
    return l;
  }
  static Lit Int(std::int64_t v) {
    Lit l;
    l.kind = Kind::Int;
    l.i = v;
    return l;
  }
  static Lit Double(double v) {
    Lit l;
    l.kind = Kind::Double;
    l.d = v;
    return l;
  }
  static Lit Text(const char* s, std::size_t len) {
    Lit l;
    l.kind = Kind::Text;
    l.text = {s, len};
    return l;
  }
  // BigInt: integers too large for int64_t, stored as double approximation
  static Lit BigInt(double v, bool negative) {
    Lit l;
    l.kind = Kind::BigInt;
    l.big_int = {v, negative};
    return l;
  }
  // Bytes: hex-encoded byte sequence
  static Lit Bytes(const char* s, std::size_t len) {
    Lit l;
    l.kind = Kind::Bytes;
    l.bytes = {s, len};
    return l;
  }
};
// ═══════════════════════════════════════════════════════════════════════════════
// FIELDS (flat_hash_map for O(1) lookup, cache-friendly iteration)
// ═══════════════════════════════════════════════════════════════════════════════

template <typename T>
class Fields {
public:
  struct Entry {
    Name name;
    T value;
  };

private:
  // flat_hash_map: open addressing, cache-friendly, ~2x faster than std::unordered_map
  std::unordered_map<std::uint32_t, Entry> map_;

public:
  Fields() = default;

  void reserve(std::size_t n) { map_.reserve(n); }

  void insert(Name n, T v) { map_.insert_or_assign(n.id, Entry{n, std::move(v)}); }

  // For bulk loading when we know keys are unique
  void push_back_unchecked(Name n, T v) { map_.emplace(n.id, Entry{n, std::move(v)}); }

  T* lookup(Name n) {
    auto it = map_.find(n.id);
    return it != map_.end() ? &it->second.value : nullptr;
  }

  const T* lookup(Name n) const {
    auto it = map_.find(n.id);
    return it != map_.end() ? &it->second.value : nullptr;
  }

  std::size_t size() const { return map_.size(); }

  // Iterator that exposes Entry references
  struct Iterator {
    using inner_t = typename std::unordered_map<std::uint32_t, Entry>::const_iterator;
    inner_t it;
    const Entry& operator*() const { return it->second; }
    Iterator& operator++() {
      ++it;
      return *this;
    }
    bool operator!=(const Iterator& o) const { return it != o.it; }
  };
  Iterator begin() const { return {map_.begin()}; }
  Iterator end() const { return {map_.end()}; }

  // O(m) right-biased merge when a can be moved, O(n+m) otherwise
  // Takes a by value to enable move semantics
  static Fields merge_prefer(Fields a, const Fields& b) {
    a.map_.reserve(a.size() + b.size());
    for (const auto& [id, entry] : b.map_) {
      a.map_.insert_or_assign(id, entry); // b overwrites
    }
    return a; // NRVO or move
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPRESSION AST
// ═══════════════════════════════════════════════════════════════════════════════

struct Expr;
using ExprPtr = Expr*;

struct Expr {
  enum class Kind : std::uint8_t {
    Const,
    Var,
    Builtin,
    Lam,
    Pi,
    App,
    Let,
    Lit,
    BoolAnd,
    BoolOr,
    BoolEq,  // == (equality comparison)
    BoolNeq, // != (not equal)
    BoolIf,
    NatPlus,
    NatTimes,
    TextAppend, // ++ operator for text concatenation
    ListAppend, // # operator for list concatenation
    List,
    RecordLit,
    Record,
    Union, // Union type: < Foo : T | Bar >
    Field,
    Project,     // Record projection: expr.{ field1, field2 }
    ProjectType, // Record projection by type: expr.(Type)
    Prefer,
    CombineTypes, // ⩓ recursive record type merge
    Combine,      // ∧ recursive record merge
    Assert,       // assert : Expr
    Equiv,        // ≡ equivalence
    With,         // record with field = value
    Merge,        // merge handler union
    ToMap,        // toMap record
    Annot,
    Import, // Local file import (./path.dhall, ../path.dhall)
  };

  Kind kind;

  union {
    Const const_val;
    std::uint32_t var_idx;
    Builtin builtin;
    Lit lit;
    struct {
      Name name;
      ExprPtr type;
      ExprPtr body;
    } lam;
    struct {
      Name name;
      ExprPtr domain;
      ExprPtr codomain;
    } pi;
    struct {
      ExprPtr func;
      ExprPtr arg;
    } app;
    struct {
      Name name;
      ExprPtr type;
      ExprPtr value;
      ExprPtr body;
    } let;
    struct {
      ExprPtr lhs;
      ExprPtr rhs;
    } binop;
    struct {
      ExprPtr cond;
      ExprPtr then_;
      ExprPtr else_;
    } if_;
    struct {
      ExprPtr type;
      ExprPtr* elems;
      std::size_t count;
    } list;
    Fields<ExprPtr>* fields;
    struct {
      ExprPtr record;
      Name name;
    } field;
    struct {
      ExprPtr expr;
      ExprPtr type;
    } annot;
    struct {
      const char* path; // Original path string (arena-allocated)
      std::size_t path_len;
      const char* abs_path; // Resolved absolute path (set during import resolution)
      std::size_t abs_path_len;
      const char* hash;     // SHA256 hash (optional, for integrity checking)
      std::size_t hash_len; // 64 hex chars for sha256 (0 if no hash)
      bool is_http;         // true for https:// URLs
    } import;
    struct {
      ExprPtr record;    // Record expression to project from
      Name* field_names; // Array of field names to project
      std::size_t count; // Number of fields
    } project;
    struct {
      ExprPtr record; // Record expression to project from
      ExprPtr type;   // Type expression specifying fields
    } project_type;
    struct {
      ExprPtr record;       // Base record
      Name* path;           // Path of field names (a.b.c)
      std::size_t path_len; // Length of path
      ExprPtr value;        // New value for the field
    } with;
    struct {
      ExprPtr handler;   // Handler record
      ExprPtr union_val; // Union value
      ExprPtr type;      // Optional result type annotation
    } merge;
    struct {
      ExprPtr record; // Record to convert
      ExprPtr type;   // Optional type annotation
    } tomap;
    struct {
      ExprPtr type; // The type that must be equivalent to True
    } assert_;
    struct {
      ExprPtr lhs;
      ExprPtr rhs;
    } equiv;
  };
};

// ═══════════════════════════════════════════════════════════════════════════════
// VALUES (WHNF)
// ═══════════════════════════════════════════════════════════════════════════════

struct Value;
using ValuePtr = Value*;

struct Env {
  std::vector<ValuePtr> values;

  Env extend(ValuePtr v) const {
    Env e = *this;
    e.values.push_back(v);
    return e;
  }

  ValuePtr lookup(std::uint32_t idx) const {
    if (idx >= values.size()) {
      return nullptr;
    }
    return values[values.size() - 1 - idx];
  }

  std::size_t size() const { return values.size(); }
};

struct Closure {
  Name name;
  Env env;
  ExprPtr body;
  ExprPtr type; // Original type expression (for quote-back)
};

struct Value {
  enum class Kind : std::uint8_t {
    Const,
    Var,
    Lam,
    Pi,
    App,
    Builtin,
    Lit,
    List,
    RecordLit,
    Record,
    Union, // Union type: < Foo : T | Bar >
    Field,
    Project, // Stuck record projection
    Prefer,
    Combine,      // Stuck ∧ recursive record merge
    CombineTypes, // Stuck ⩓ recursive record type merge
    BoolIf,       // Stuck if expression
    BoolAnd,      // Stuck && expression
    BoolOr,       // Stuck || expression
    BoolEq,       // Stuck == expression
    BoolNeq,      // Stuck != expression
    NatPlus,      // Stuck + expression
    NatTimes,     // Stuck * expression
    TextAppend,   // Stuck ++ expression
    ListAppend,   // Stuck # expression
    Assert,       // Stuck assert expression
    Equiv,        // Stuck ≡ expression
    With,         // Stuck with expression
    Merge,        // Stuck merge expression
    ToMap,        // Stuck toMap expression
  };

  Kind kind;

  union {
    Const const_val;
    std::int32_t var_level; // de Bruijn level
    Closure* closure;
    struct {
      ValuePtr domain;
      Closure* codomain;
    } pi;
    struct {
      ValuePtr func;
      ValuePtr arg;
    } app;
    struct {
      Builtin b;
      std::vector<ValuePtr>* args;
    } builtin;
    Lit lit;
    struct {
      ValuePtr type;
      std::vector<ValuePtr>* elems;
    } list;
    Fields<ValuePtr>* fields;
    struct {
      ValuePtr record;
      Name name;
    } field;
    struct {
      ValuePtr record;
      Name* field_names;
      std::size_t count;
    } project;
    struct {
      ValuePtr lhs;
      ValuePtr rhs;
    } prefer;
    struct {
      ValuePtr cond;
      ValuePtr then_;
      ValuePtr else_;
    } if_;
    struct {
      ValuePtr lhs;
      ValuePtr rhs;
    } binop;
    struct {
      ValuePtr type; // For assert and equiv
    } assert_;
    struct {
      ValuePtr record;
      Name* path;
      std::size_t path_len;
      ValuePtr value;
    } with;
    struct {
      ValuePtr handler;
      ValuePtr union_val;
      ValuePtr result_type;
    } merge;
    struct {
      ValuePtr record;
      ValuePtr result_type;
    } tomap;
  };
};

// ═══════════════════════════════════════════════════════════════════════════════
// EVALUATOR
// ═══════════════════════════════════════════════════════════════════════════════

// Forward declare import callback type
class Evaluator;
using ImportCallback = std::function<ValuePtr(Evaluator&, std::string_view abs_path)>;

// Thrown when evaluation exceeds the configured step budget.
struct EvaluationBudgetExceeded : std::runtime_error {
  using std::runtime_error::runtime_error;
};

// Thrown when Natural arithmetic would overflow uint64_t.
struct NaturalOverflow : std::runtime_error {
  using std::runtime_error::runtime_error;
};

class Evaluator {
  Arena& arena_;
  Interner& interner_;
  ImportCallback import_cb_;

  // Evaluation fuel: each NaturalFold/ListFold step consumes one unit.
  // Set to 0 to disable limiting (trusted inputs only).
  std::uint64_t fuel_remaining_;
  static constexpr std::uint64_t DEFAULT_FUEL = 10'000'000ULL;

  // Checked arithmetic helpers for spec-required exact Natural semantics.
  static std::uint64_t checked_add(std::uint64_t a, std::uint64_t b) {
    if (a > std::numeric_limits<std::uint64_t>::max() - b) {
      throw NaturalOverflow("Natural addition overflow: exceeds 2^64-1");
    }
    return a + b;
  }
  static std::uint64_t checked_mul(std::uint64_t a, std::uint64_t b) {
    if (a != 0 && b > std::numeric_limits<std::uint64_t>::max() / a) {
      throw NaturalOverflow("Natural multiplication overflow: exceeds 2^64-1");
    }
    return a * b;
  }

public:
  explicit Evaluator(Arena& arena, Interner& interner, std::uint64_t fuel = DEFAULT_FUEL)
      : arena_(arena), interner_(interner), fuel_remaining_(fuel) {}

  /// Set import callback for value caching.
  void set_import_callback(ImportCallback cb) { import_cb_ = std::move(cb); }

  /// Set evaluation fuel (0 = unlimited; only safe for fully trusted inputs).
  void set_fuel(std::uint64_t fuel) { fuel_remaining_ = fuel; }

  ValuePtr eval(const Env& env, ExprPtr e);
  ExprPtr quote(int level, ValuePtr v);
  ExprPtr normalize(ExprPtr e) { return quote(0, eval({}, e)); }

private:
  ValuePtr apply(ValuePtr f, ValuePtr x);
  ValuePtr evalField(ValuePtr r, Name n);
  ValuePtr evalPrefer(ValuePtr a, ValuePtr b);
  ValuePtr evalCombine(ValuePtr a, ValuePtr b);
  ValuePtr evalCombineTypes(ValuePtr a, ValuePtr b);
  ValuePtr evalWith(ValuePtr r, Name* path, std::size_t path_len, ValuePtr v);
  ValuePtr evalMerge(ValuePtr handler, ValuePtr union_val, ValuePtr result_type);
  ValuePtr evalToMap(ValuePtr r, ValuePtr t);
  ValuePtr tryBuiltin(Builtin b, std::span<ValuePtr> args);

  // Allocation helpers
  template <typename T, typename... Args>
  T* alloc(Args&&... args) {
    return arena_.alloc<T>(std::forward<Args>(args)...);
  }

  ValuePtr mkConst(Const c) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Const;
    v->const_val = c;
    return v;
  }
  ValuePtr mkVar(int level) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Var;
    v->var_level = level;
    return v;
  }
  ValuePtr mkLit(Lit l) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Lit;
    v->lit = l;
    return v;
  }
  ValuePtr mkLam(Closure* c) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Lam;
    v->closure = c;
    return v;
  }
  ValuePtr mkApp(ValuePtr f, ValuePtr x) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::App;
    v->app = {f, x};
    return v;
  }
  ValuePtr mkBuiltin(Builtin b, std::vector<ValuePtr>* args) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Builtin;
    v->builtin = {b, args};
    return v;
  }
  ValuePtr mkRecordLit(Fields<ValuePtr>* fs) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::RecordLit;
    v->fields = fs;
    return v;
  }
  ValuePtr mkField(ValuePtr r, Name n) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Field;
    v->field = {r, n};
    return v;
  }
  ValuePtr mkPrefer(ValuePtr a, ValuePtr b) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Prefer;
    v->prefer = {a, b};
    return v;
  }
  ValuePtr mkList(ValuePtr t, std::vector<ValuePtr>* es) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::List;
    v->list = {t, es};
    return v;
  }
  ValuePtr mkBoolIf(ValuePtr c, ValuePtr t, ValuePtr e) {
    auto* v = alloc<Value>();
    v->kind = Value::Kind::BoolIf;
    v->if_ = {c, t, e};
    return v;
  }
  ValuePtr mkBinop(Value::Kind k, ValuePtr l, ValuePtr r) {
    auto* v = alloc<Value>();
    v->kind = k;
    v->binop = {l, r};
    return v;
  }

  ExprPtr mkExprConst(Const c) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Const;
    e->const_val = c;
    return e;
  }
  ExprPtr mkExprVar(std::uint32_t i) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Var;
    e->var_idx = i;
    return e;
  }
  ExprPtr mkExprLit(Lit l) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Lit;
    e->lit = l;
    return e;
  }
  ExprPtr mkExprBuiltin(Builtin b) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Builtin;
    e->builtin = b;
    return e;
  }
  ExprPtr mkExprApp(ExprPtr f, ExprPtr x) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::App;
    e->app = {f, x};
    return e;
  }
  ExprPtr mkExprLam(Name n, ExprPtr t, ExprPtr b) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Lam;
    e->lam = {n, t, b};
    return e;
  }
  ExprPtr mkExprRecordLit(Fields<ExprPtr>* fs) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::RecordLit;
    e->fields = fs;
    return e;
  }
  ExprPtr mkExprField(ExprPtr r, Name n) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Field;
    e->field = {r, n};
    return e;
  }
  ExprPtr mkExprPrefer(ExprPtr a, ExprPtr b) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::Prefer;
    e->binop = {a, b};
    return e;
  }
  ExprPtr mkExprList(ExprPtr t, ExprPtr* es, std::size_t n) {
    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::List;
    e->list = {t, es, n};
    return e;
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

inline ValuePtr Evaluator::eval(const Env& env, ExprPtr e) {
  switch (e->kind) {
    case Expr::Kind::Const:
      return mkConst(e->const_val);

    case Expr::Kind::Var:
      if (auto* v = env.lookup(e->var_idx)) {
        return v;
      }
      return mkVar(static_cast<int>(env.size()) - 1 - static_cast<int>(e->var_idx));

    case Expr::Kind::Builtin:
      return mkBuiltin(e->builtin, alloc<std::vector<ValuePtr>>());

    case Expr::Kind::Lam: {
      auto* c = alloc<Closure>();
      c->name = e->lam.name;
      c->env = env;
      c->body = e->lam.body;
      c->type = e->lam.type; // Preserve type for quote-back
      return mkLam(c);
    }

    case Expr::Kind::Pi: {
      auto* dom = eval(env, e->pi.domain);
      auto* c = alloc<Closure>();
      c->name = e->pi.name;
      c->env = env;
      c->body = e->pi.codomain;
      c->type = e->pi.domain; // Preserve domain type for quote-back
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Pi;
      v->pi = {dom, c};
      return v;
    }

    case Expr::Kind::App: {
      auto* f = eval(env, e->app.func);
      auto* x = eval(env, e->app.arg);
      return apply(f, x);
    }

    case Expr::Kind::Let: {
      auto* v = eval(env, e->let.value);
      return eval(env.extend(v), e->let.body);
    }

    case Expr::Kind::Lit:
      return mkLit(e->lit);

    case Expr::Kind::BoolAnd: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool && !a->lit.b) {
        return a;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool && !b->lit.b) {
        return b;
      }
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool && a->lit.b) {
        return b;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool && b->lit.b) {
        return a;
      }
      // Equivalent arguments: x && x → x
      if (a == b || (a->kind == Value::Kind::Var && b->kind == Value::Kind::Var &&
                     a->var_level == b->var_level)) {
        return a;
      }
      // Stuck && expression
      return mkBinop(Value::Kind::BoolAnd, a, b);
    }

    case Expr::Kind::BoolOr: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool && a->lit.b) {
        return a;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool && b->lit.b) {
        return b;
      }
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool && !a->lit.b) {
        return b;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool && !b->lit.b) {
        return a;
      }
      // Equivalent arguments: x || x → x
      if (a == b || (a->kind == Value::Kind::Var && b->kind == Value::Kind::Var &&
                     a->var_level == b->var_level)) {
        return a;
      }
      // Stuck || expression
      return mkBinop(Value::Kind::BoolOr, a, b);
    }

    case Expr::Kind::BoolEq: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      // Bool equality
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool) {
        return mkLit(Lit::Bool(a->lit.b == b->lit.b));
      }
      // x == True → x
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool && b->lit.b) {
        return a;
      }
      // True == x → x
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool && a->lit.b) {
        return b;
      }
      // Equivalent arguments: x == x → True
      if (a == b || (a->kind == Value::Kind::Var && b->kind == Value::Kind::Var &&
                     a->var_level == b->var_level)) {
        return mkLit(Lit::Bool(true));
      }
      // Natural equality
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Nat &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Bool(a->lit.n == b->lit.n));
      }
      // Integer equality
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Int &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Int) {
        return mkLit(Lit::Bool(a->lit.i == b->lit.i));
      }
      // Double equality (note: Dhall uses bitwise equality for doubles)
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Double &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Double) {
        return mkLit(Lit::Bool(a->lit.d == b->lit.d));
      }
      // Text equality
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Text &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Text) {
        bool eq = (a->lit.text.len == b->lit.text.len) &&
                  (std::memcmp(a->lit.text.data, b->lit.text.data, a->lit.text.len) == 0);
        return mkLit(Lit::Bool(eq));
      }
      // Stuck == expression
      return mkBinop(Value::Kind::BoolEq, a, b);
    }

    case Expr::Kind::BoolNeq: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      // Bool inequality
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool) {
        return mkLit(Lit::Bool(a->lit.b != b->lit.b));
      }
      // x != False → x
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Bool && !b->lit.b) {
        return a;
      }
      // False != x → x
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Bool && !a->lit.b) {
        return b;
      }
      // Equivalent arguments: x != x → False
      if (a == b || (a->kind == Value::Kind::Var && b->kind == Value::Kind::Var &&
                     a->var_level == b->var_level)) {
        return mkLit(Lit::Bool(false));
      }
      // Stuck != expression
      return mkBinop(Value::Kind::BoolNeq, a, b);
    }

    case Expr::Kind::BoolIf: {
      auto* c = eval(env, e->if_.cond);
      if (c->kind == Value::Kind::Lit && c->lit.kind == Lit::Kind::Bool) {
        return eval(env, c->lit.b ? e->if_.then_ : e->if_.else_);
      }
      auto* t = eval(env, e->if_.then_);
      auto* f = eval(env, e->if_.else_);
      // if x then True else False → x
      if (t->kind == Value::Kind::Lit && t->lit.kind == Lit::Kind::Bool && t->lit.b &&
          f->kind == Value::Kind::Lit && f->lit.kind == Lit::Kind::Bool && !f->lit.b) {
        return c;
      }
      // if x then y else y → y (alternatives identical)
      // Simple pointer equality check, plus structural check for variables
      if (t == f) {
        return t;
      }
      if (t->kind == Value::Kind::Var && f->kind == Value::Kind::Var &&
          t->var_level == f->var_level) {
        return t;
      }
      // Stuck if expression - preserve for quote
      return mkBoolIf(c, t, f);
    }

    case Expr::Kind::NatPlus: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Nat && a->lit.n == 0) {
        return b;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Nat && b->lit.n == 0) {
        return a;
      }
      if (a->kind == Value::Kind::Lit && b->kind == Value::Kind::Lit &&
          a->lit.kind == Lit::Kind::Nat && b->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Nat(checked_add(a->lit.n, b->lit.n)));
      }
      // Stuck plus expression
      return mkBinop(Value::Kind::NatPlus, a, b);
    }

    case Expr::Kind::NatTimes: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Nat && a->lit.n == 0) {
        return a;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Nat && b->lit.n == 0) {
        return b;
      }
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Nat && a->lit.n == 1) {
        return b;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Nat && b->lit.n == 1) {
        return a;
      }
      if (a->kind == Value::Kind::Lit && b->kind == Value::Kind::Lit &&
          a->lit.kind == Lit::Kind::Nat && b->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Nat(checked_mul(a->lit.n, b->lit.n)));
      }
      // Stuck times expression
      return mkBinop(Value::Kind::NatTimes, a, b);
    }

    case Expr::Kind::TextAppend: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      // If both are text literals, concatenate them
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Text &&
          b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Text) {
        // Concatenate the strings
        std::size_t len_a = a->lit.text.len;
        std::size_t len_b = b->lit.text.len;
        char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(len_a + len_b + 1).data());
        std::copy(a->lit.text.data, a->lit.text.data + len_a, data);
        std::copy(b->lit.text.data, b->lit.text.data + len_b, data + len_a);
        data[len_a + len_b] = '\0';
        return mkLit(Lit::Text(data, len_a + len_b));
      }
      // If either is empty string, return the other
      if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Text && a->lit.text.len == 0) {
        return b;
      }
      if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Text && b->lit.text.len == 0) {
        return a;
      }
      // Otherwise create a stuck TextAppend application
      return mkBinop(Value::Kind::TextAppend, a, b);
    }

    case Expr::Kind::ListAppend: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      // If both are lists, concatenate them
      if (a->kind == Value::Kind::List && b->kind == Value::Kind::List) {
        auto* es = alloc<std::vector<ValuePtr>>();
        es->reserve(a->list.elems->size() + b->list.elems->size());
        for (auto* e : *a->list.elems) {
          es->push_back(e);
        }
        for (auto* e : *b->list.elems) {
          es->push_back(e);
        }
        // Use type from whichever has one
        ValuePtr t = a->list.type ? a->list.type : b->list.type;
        return mkList(t, es);
      }
      // [] # x → x
      if (a->kind == Value::Kind::List && a->list.elems->empty()) {
        return b;
      }
      // x # [] → x
      if (b->kind == Value::Kind::List && b->list.elems->empty()) {
        return a;
      }
      // Stuck list append
      return mkBinop(Value::Kind::ListAppend, a, b);
    }

    case Expr::Kind::List: {
      ValuePtr t = e->list.type ? eval(env, e->list.type) : nullptr;
      // If type is `List T`, extract just `T` (the element type)
      if (t && t->kind == Value::Kind::Builtin && t->builtin.b == Builtin::List &&
          t->builtin.args && t->builtin.args->size() == 1) {
        t = (*t->builtin.args)[0];
      }
      auto* es = alloc<std::vector<ValuePtr>>();
      es->reserve(e->list.count);
      for (std::size_t i = 0; i < e->list.count; ++i) {
        es->push_back(eval(env, e->list.elems[i]));
      }
      return mkList(t, es);
    }

    case Expr::Kind::RecordLit: {
      auto* fs = alloc<Fields<ValuePtr>>();
      fs->reserve(e->fields->size());
      for (const auto& entry : *e->fields) {
        fs->push_back_unchecked(entry.name, eval(env, entry.value));
      }
      return mkRecordLit(fs);
    }

    case Expr::Kind::Record: {
      auto* fs = alloc<Fields<ValuePtr>>();
      fs->reserve(e->fields->size());
      for (const auto& entry : *e->fields) {
        fs->push_back_unchecked(entry.name, eval(env, entry.value));
      }
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Record;
      v->fields = fs;
      return v;
    }

    case Expr::Kind::Union: {
      // Union types evaluate the same as record types (they hold constructor types)
      auto* fs = alloc<Fields<ValuePtr>>();
      fs->reserve(e->fields->size());
      for (const auto& entry : *e->fields) {
        fs->push_back_unchecked(entry.name, eval(env, entry.value));
      }
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Union;
      v->fields = fs;
      return v;
    }

    case Expr::Kind::Field:
      return evalField(eval(env, e->field.record), e->field.name);

    case Expr::Kind::Prefer: {
      auto* lhs = eval(env, e->binop.lhs);
      auto* rhs = eval(env, e->binop.rhs);
      return evalPrefer(lhs, rhs);
    }

    case Expr::Kind::Annot:
      return eval(env, e->annot.expr);

    case Expr::Kind::Import: {
      // Import nodes should have abs_path set by import resolver
      if (!e->import.abs_path || !import_cb_) {
        throw std::runtime_error("Import not resolved or no import callback set");
      }
      std::string_view abs_path(e->import.abs_path, e->import.abs_path_len);
      return import_cb_(*this, abs_path);
    }

    case Expr::Kind::Project: {
      auto* r = eval(env, e->project.record);
      // Empty projection always yields empty record
      if (e->project.count == 0) {
        return mkRecordLit(alloc<Fields<ValuePtr>>());
      }
      // If the record is a literal, project the specified fields
      if (r->kind == Value::Kind::RecordLit) {
        auto* fs = alloc<Fields<ValuePtr>>();
        fs->reserve(e->project.count);
        for (std::size_t i = 0; i < e->project.count; ++i) {
          Name n = e->project.field_names[i];
          if (auto* v = r->fields->lookup(n)) {
            fs->push_back_unchecked(n, *v);
          }
        }
        return mkRecordLit(fs);
      }
      // Nested projection: x.{a,b}.{a} -> x.{a} (intersect field sets)
      if (r->kind == Value::Kind::Project) {
        auto intersected = arena_.alloc_array<Name>(e->project.count);
        std::size_t intersect_count = 0;
        for (std::size_t i = 0; i < e->project.count; ++i) {
          Name n = e->project.field_names[i];
          for (std::size_t j = 0; j < r->project.count; ++j) {
            if (r->project.field_names[j] == n) {
              intersected[intersect_count++] = n;
              break;
            }
          }
        }
        if (intersect_count == 0) {
          return mkRecordLit(alloc<Fields<ValuePtr>>());
        }
        auto* v = alloc<Value>();
        v->kind = Value::Kind::Project;
        v->project = {r->project.record, intersected.data(), intersect_count};
        return v;
      }
      // Projection through Prefer: (x ⫽ {a=1,b=2}).{a,c} -> x.{c} ⫽ {a=1}
      // Fields in RHS record literal are extracted, rest come from LHS
      if (r->kind == Value::Kind::Prefer && r->binop.rhs->kind == Value::Kind::RecordLit) {
        auto* rhs_fs = r->binop.rhs->fields;
        auto* rhs_projected = alloc<Fields<ValuePtr>>();
        auto lhs_names = arena_.alloc_array<Name>(e->project.count);
        std::size_t lhs_count = 0;

        for (std::size_t i = 0; i < e->project.count; ++i) {
          Name n = e->project.field_names[i];
          if (auto* v = rhs_fs->lookup(n)) {
            rhs_projected->push_back_unchecked(n, *v);
          } else {
            lhs_names[lhs_count++] = n;
          }
        }

        if (lhs_count == 0) {
          // All fields came from RHS
          return mkRecordLit(rhs_projected);
        }
        if (rhs_projected->size() == 0) {
          // All fields came from LHS - just project LHS
          auto* v = alloc<Value>();
          v->kind = Value::Kind::Project;
          v->project = {r->binop.lhs, lhs_names.data(), lhs_count};
          return v;
        }
        // Some fields from each side: LHS.{fields} ⫽ {rhs_fields}
        auto* lhs_proj = alloc<Value>();
        lhs_proj->kind = Value::Kind::Project;
        lhs_proj->project = {r->binop.lhs, lhs_names.data(), lhs_count};
        return mkPrefer(lhs_proj, mkRecordLit(rhs_projected));
      }
      // Stuck projection
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Project;
      v->project = {r, e->project.field_names, e->project.count};
      return v;
    }

    case Expr::Kind::ProjectType: {
      auto* r = eval(env, e->project_type.record);
      auto* t = eval(env, e->project_type.type);
      // If the record is a literal and type is a record type, project those fields
      if (r->kind == Value::Kind::RecordLit && t->kind == Value::Kind::Record) {
        auto* fs = alloc<Fields<ValuePtr>>();
        fs->reserve(t->fields->size());
        for (const auto& entry : *t->fields) {
          if (auto* v = r->fields->lookup(entry.name)) {
            fs->push_back_unchecked(entry.name, *v);
          }
        }
        return mkRecordLit(fs);
      }
      // Empty type projection yields empty record
      if (t->kind == Value::Kind::Record && t->fields && t->fields->size() == 0) {
        return mkRecordLit(alloc<Fields<ValuePtr>>());
      }
      // Extract field names from type
      if (t->kind == Value::Kind::Record && t->fields) {
        std::size_t type_count = t->fields->size();
        auto type_names = arena_.alloc_array<Name>(type_count);
        std::size_t idx = 0;
        for (const auto& entry : *t->fields) {
          type_names[idx++] = entry.name;
        }
        // Nested projection: if r is already a Project, intersect field sets
        if (r->kind == Value::Kind::Project) {
          auto intersected = arena_.alloc_array<Name>(type_count);
          std::size_t intersect_count = 0;
          for (std::size_t i = 0; i < type_count; ++i) {
            Name n = type_names[i];
            for (std::size_t j = 0; j < r->project.count; ++j) {
              if (r->project.field_names[j] == n) {
                intersected[intersect_count++] = n;
                break;
              }
            }
          }
          if (intersect_count == 0) {
            return mkRecordLit(alloc<Fields<ValuePtr>>());
          }
          auto* v = alloc<Value>();
          v->kind = Value::Kind::Project;
          v->project = {r->project.record, intersected.data(), intersect_count};
          return v;
        }
        // Stuck projection
        auto* v = alloc<Value>();
        v->kind = Value::Kind::Project;
        v->project = {r, type_names.data(), type_count};
        return v;
      }
      // Type is not a record type - stuck with zero fields
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Project;
      v->project = {r, nullptr, 0};
      return v;
    }

    case Expr::Kind::Combine: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      return evalCombine(a, b);
    }

    case Expr::Kind::CombineTypes: {
      auto* a = eval(env, e->binop.lhs);
      auto* b = eval(env, e->binop.rhs);
      return evalCombineTypes(a, b);
    }

    case Expr::Kind::Assert: {
      auto* t = eval(env, e->assert_.type);
      // Assert normalizes to itself with normalized type
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Assert;
      v->assert_ = {t};
      return v;
    }

    case Expr::Kind::Equiv: {
      auto* a = eval(env, e->equiv.lhs);
      auto* b = eval(env, e->equiv.rhs);
      // Equivalence normalizes to itself with normalized operands
      auto* v = alloc<Value>();
      v->kind = Value::Kind::Equiv;
      v->binop = {a, b};
      return v;
    }

    case Expr::Kind::With: {
      auto* r = eval(env, e->with.record);
      auto* v = eval(env, e->with.value);
      return evalWith(r, e->with.path, e->with.path_len, v);
    }

    case Expr::Kind::Merge: {
      auto* handler = eval(env, e->merge.handler);
      auto* union_val = eval(env, e->merge.union_val);
      ValuePtr result_type = e->merge.type ? eval(env, e->merge.type) : nullptr;
      return evalMerge(handler, union_val, result_type);
    }

    case Expr::Kind::ToMap: {
      auto* r = eval(env, e->tomap.record);
      ValuePtr t = e->tomap.type ? eval(env, e->tomap.type) : nullptr;
      return evalToMap(r, t);
    }
  }

  return mkConst(Const::Type); // unreachable
}

inline ValuePtr Evaluator::apply(ValuePtr f, ValuePtr x) {
  if (f->kind == Value::Kind::Lam) {
    return eval(f->closure->env.extend(x), f->closure->body);
  }
  if (f->kind == Value::Kind::Builtin) {
    auto* args = alloc<std::vector<ValuePtr>>(*f->builtin.args);
    args->push_back(x);
    return tryBuiltin(f->builtin.b, *args);
  }
  // Union constructor application: < x : T >.x arg → { x = arg }
  if (f->kind == Value::Kind::Field && f->field.record->kind == Value::Kind::Union) {
    Name n = f->field.name;
    if (f->field.record->fields->lookup(n)) {
      // Create { n = x }
      auto* fs = alloc<Fields<ValuePtr>>();
      fs->insert(n, x);
      return mkRecordLit(fs);
    }
  }
  return mkApp(f, x);
}

inline ValuePtr Evaluator::evalField(ValuePtr r, Name n) {
  if (r->kind == Value::Kind::RecordLit) {
    if (auto* v = r->fields->lookup(n)) {
      return *v;
    }
  }

  // Field selection through projection: x.{a,b}.a -> x.a
  if (r->kind == Value::Kind::Project) {
    // Check if the field is in the projection
    for (std::size_t i = 0; i < r->project.count; ++i) {
      if (r->project.field_names[i] == n) {
        // Field is in the projection, select from the inner record
        return evalField(r->project.record, n);
      }
    }
  }

  // Field selection through prefer: (a ⫽ b).x
  // If b is a record literal containing x, return b.x
  // If b is a record literal NOT containing x, return a.x
  // If a is a record literal NOT containing x, return b.x
  if (r->kind == Value::Kind::Prefer) {
    if (r->binop.rhs->kind == Value::Kind::RecordLit) {
      if (auto* v = r->binop.rhs->fields->lookup(n)) {
        return *v;
      }
      // RHS doesn't have the field, try to get it from LHS
      return evalField(r->binop.lhs, n);
    }
    if (r->binop.lhs->kind == Value::Kind::RecordLit) {
      // LHS is a literal, RHS is not
      if (!r->binop.lhs->fields->lookup(n)) {
        // LHS doesn't have the field, must come from RHS
        return evalField(r->binop.rhs, n);
      }
      // LHS has the field - project only that field from LHS
      // ({ a = 0, b = 1 } ⫽ x).a → ({ a = 0 } ⫽ x).a
      if (r->binop.lhs->fields->size() > 1) {
        auto* projected = alloc<Fields<ValuePtr>>();
        projected->insert(n, *r->binop.lhs->fields->lookup(n));
        auto* new_lhs = mkRecordLit(projected);
        return mkField(mkPrefer(new_lhs, r->binop.rhs), n);
      }
    }
  }

  // Field selection through combine: (a ∧ b).x
  // If both a and b are record literals, recursively combine field values
  if (r->kind == Value::Kind::Combine) {
    if (r->binop.lhs->kind == Value::Kind::RecordLit &&
        r->binop.rhs->kind == Value::Kind::RecordLit) {
      auto* a_val = r->binop.lhs->fields->lookup(n);
      auto* b_val = r->binop.rhs->fields->lookup(n);
      if (a_val && b_val) {
        return evalCombine(*a_val, *b_val);
      } else if (a_val) {
        return *a_val;
      } else if (b_val) {
        return *b_val;
      }
    }
    // If RHS is a record literal not containing the field, get it from LHS
    // (x ∧ { a = 1 }).b → x.b when { a = 1 } doesn't have b
    if (r->binop.rhs->kind == Value::Kind::RecordLit) {
      if (!r->binop.rhs->fields->lookup(n)) {
        return evalField(r->binop.lhs, n);
      }
      // RHS has the field - project only that field from RHS
      // (x ∧ { a = 0, b = 1 }).a → (x ∧ { a = 0 }).a
      if (r->binop.rhs->fields->size() > 1) {
        auto* projected = alloc<Fields<ValuePtr>>();
        projected->insert(n, *r->binop.rhs->fields->lookup(n));
        auto* new_rhs = mkRecordLit(projected);
        auto* result = alloc<Value>();
        result->kind = Value::Kind::Combine;
        result->binop = {r->binop.lhs, new_rhs};
        return mkField(result, n);
      }
    }
    // If LHS is a record literal not containing the field, get it from RHS
    // ({ a = 1 } ∧ x).b → x.b when { a = 1 } doesn't have b
    if (r->binop.lhs->kind == Value::Kind::RecordLit) {
      if (!r->binop.lhs->fields->lookup(n)) {
        return evalField(r->binop.rhs, n);
      }
      // LHS has the field - project only that field from LHS
      // ({ a = 0, b = 1 } ∧ x).a → ({ a = 0 } ∧ x).a
      if (r->binop.lhs->fields->size() > 1) {
        auto* projected = alloc<Fields<ValuePtr>>();
        projected->insert(n, *r->binop.lhs->fields->lookup(n));
        auto* new_lhs = mkRecordLit(projected);
        auto* result = alloc<Value>();
        result->kind = Value::Kind::Combine;
        result->binop = {new_lhs, r->binop.rhs};
        return mkField(result, n);
      }
    }
  }

  // Union constructor: accessing a field from a Union type
  // In normal form, this stays as < ... >.field - we don't reduce it to a lambda.
  // The lambda behavior only emerges when the constructor is APPLIED.
  // For nullary constructors (type is empty record {}): directly return { n = {} }
  if (r->kind == Value::Kind::Union) {
    if (auto* field_type = r->fields->lookup(n)) {
      // Check if this is a nullary constructor (type is empty record)
      bool is_nullary = (*field_type)->kind == Value::Kind::RecordLit && (*field_type)->fields &&
                        (*field_type)->fields->size() == 0;

      if (is_nullary) {
        spdlog::trace("evalField: nullary union constructor for '{}'", interner_.get(n));
        // Return { n = {} } directly
        auto* inner_fs = alloc<Fields<ValuePtr>>();
        auto* empty_record = alloc<Value>();
        empty_record->kind = Value::Kind::RecordLit;
        empty_record->fields = inner_fs;

        auto* outer_fs = alloc<Fields<ValuePtr>>();
        outer_fs->insert(n, empty_record);
        return mkRecordLit(outer_fs);
      }

      // For non-nullary constructors, don't reduce - leave as Field access
      // This will be handled when APPLIED (see eval of App)
      spdlog::trace("evalField: union constructor accessor for '{}' - keeping as Field",
                    interner_.get(n));
    }
  }

  return mkField(r, n);
}

inline ValuePtr Evaluator::evalPrefer(ValuePtr a, ValuePtr b) {
  // Identity: x ⫽ x = x (pointer equality check)
  if (a == b) {
    return a;
  }

  // Empty record identity: {=} ⫽ x = x, x ⫽ {=} = x
  if (a->kind == Value::Kind::RecordLit && a->fields && a->fields->size() == 0) {
    return b;
  }
  if (b->kind == Value::Kind::RecordLit && b->fields && b->fields->size() == 0) {
    return a;
  }

  if (a->kind == Value::Kind::RecordLit && b->kind == Value::Kind::RecordLit) {
    auto merged = Fields<ValuePtr>::merge_prefer(*a->fields, *b->fields);
    auto* fs = alloc<Fields<ValuePtr>>(std::move(merged));
    return mkRecordLit(fs);
  }
  return mkPrefer(a, b);
}

inline ValuePtr Evaluator::evalCombine(ValuePtr a, ValuePtr b) {
  // ∧ recursive record merge: { x = a } ∧ { x = b } = { x = a ∧ b }
  // { x = 1 } ∧ { y = 2 } = { x = 1, y = 2 }
  // { x = { z = 1 } } ∧ { x = { y = 2 } } = { x = { y = 2, z = 1 } }

  // Empty record identity: {=} ∧ x = x, x ∧ {=} = x
  if (a->kind == Value::Kind::RecordLit && a->fields && a->fields->size() == 0) {
    return b;
  }
  if (b->kind == Value::Kind::RecordLit && b->fields && b->fields->size() == 0) {
    return a;
  }

  if (a->kind == Value::Kind::RecordLit && b->kind == Value::Kind::RecordLit) {
    auto* fs = alloc<Fields<ValuePtr>>();
    fs->reserve(a->fields->size() + b->fields->size());

    // First add all fields from a
    for (const auto& entry : *a->fields) {
      if (auto* bv = b->fields->lookup(entry.name)) {
        // Both have this field - recursively combine
        fs->push_back_unchecked(entry.name, evalCombine(entry.value, *bv));
      } else {
        // Only in a
        fs->push_back_unchecked(entry.name, entry.value);
      }
    }
    // Then add fields only in b
    for (const auto& entry : *b->fields) {
      if (!a->fields->lookup(entry.name)) {
        fs->push_back_unchecked(entry.name, entry.value);
      }
    }
    return mkRecordLit(fs);
  }
  // Stuck
  return mkBinop(Value::Kind::Combine, a, b);
}

inline ValuePtr Evaluator::evalCombineTypes(ValuePtr a, ValuePtr b) {
  // ⩓ recursive record type merge

  // Empty record identity: {} ⩓ x = x, x ⩓ {} = x
  if (a->kind == Value::Kind::Record && a->fields && a->fields->size() == 0) {
    return b;
  }
  if (b->kind == Value::Kind::Record && b->fields && b->fields->size() == 0) {
    return a;
  }

  if (a->kind == Value::Kind::Record && b->kind == Value::Kind::Record) {
    auto* fs = alloc<Fields<ValuePtr>>();
    fs->reserve(a->fields->size() + b->fields->size());

    for (const auto& entry : *a->fields) {
      if (auto* bv = b->fields->lookup(entry.name)) {
        fs->push_back_unchecked(entry.name, evalCombineTypes(entry.value, *bv));
      } else {
        fs->push_back_unchecked(entry.name, entry.value);
      }
    }
    for (const auto& entry : *b->fields) {
      if (!a->fields->lookup(entry.name)) {
        fs->push_back_unchecked(entry.name, entry.value);
      }
    }
    auto* v = alloc<Value>();
    v->kind = Value::Kind::Record;
    v->fields = fs;
    return v;
  }
  return mkBinop(Value::Kind::CombineTypes, a, b);
}

inline ValuePtr Evaluator::evalWith(ValuePtr r, Name* path, std::size_t path_len, ValuePtr v) {
  if (path_len == 0) {
    return v;
  }

  Name field = path[0];

  // Check if this is Optional descent (path element is "?")
  if (interner_.get(field) == "?") {
    // Handle Optional values: Some x with ? = v  ->  Some (x with remaining_path = v)
    //                         None T with ? = v  ->  None T
    if (r->kind == Value::Kind::Builtin && r->builtin.b == Builtin::Some &&
        r->builtin.args->size() == 1) {
      // Some x - apply with to inner value and wrap in Some
      ValuePtr inner = r->builtin.args->front();
      ValuePtr updated = evalWith(inner, path + 1, path_len - 1, v);
      return apply(mkBuiltin(Builtin::Some, alloc<std::vector<ValuePtr>>()), updated);
    }
    if (r->kind == Value::Kind::Builtin && r->builtin.b == Builtin::None &&
        r->builtin.args->size() == 1) {
      // None T - return unchanged
      return r;
    }
    // Stuck - not a resolved Optional
    auto* val = alloc<Value>();
    val->kind = Value::Kind::With;
    val->with = {r, path, path_len, v};
    return val;
  }

  if (r->kind == Value::Kind::RecordLit) {
    auto* fs = alloc<Fields<ValuePtr>>();
    fs->reserve(r->fields->size() + 1);

    for (const auto& entry : *r->fields) {
      if (entry.name == field) {
        // This is the field we're updating
        fs->push_back_unchecked(entry.name, evalWith(entry.value, path + 1, path_len - 1, v));
      } else {
        fs->push_back_unchecked(entry.name, entry.value);
      }
    }
    // If field didn't exist, add it
    if (!r->fields->lookup(field)) {
      if (path_len == 1) {
        fs->push_back_unchecked(field, v);
      } else {
        // Create intermediate records
        auto* empty = alloc<Fields<ValuePtr>>();
        auto* empty_rec = mkRecordLit(empty);
        fs->push_back_unchecked(field, evalWith(empty_rec, path + 1, path_len - 1, v));
      }
    }
    return mkRecordLit(fs);
  }
  // Stuck
  auto* val = alloc<Value>();
  val->kind = Value::Kind::With;
  val->with = {r, path, path_len, v};
  return val;
}

inline ValuePtr Evaluator::evalMerge(ValuePtr handler, ValuePtr union_val, ValuePtr result_type) {
  // merge { Alt = f } (< Alt : T >.Alt x) = f x
  // merge { Alt = f } (< Alt >.Alt) = f (when Alt is nullary)
  if (handler->kind == Value::Kind::RecordLit && union_val->kind == Value::Kind::RecordLit) {
    // Union value should be a single-field record like { Alt = x }
    for (const auto& entry : *union_val->fields) {
      if (auto* h = handler->fields->lookup(entry.name)) {
        // Check if this is a nullary constructor (payload is empty record)
        bool is_nullary = entry.value->kind == Value::Kind::RecordLit && entry.value->fields &&
                          entry.value->fields->size() == 0;
        if (is_nullary) {
          // For nullary constructors, return the handler directly
          return *h;
        }
        // Apply handler to the union payload
        return apply(*h, entry.value);
      }
    }
  }

  // Handle Optional values: merge { None = ..., Some = f } (Some x) = f x
  // merge { None = x, Some = ... } (None T) = x
  if (handler->kind == Value::Kind::RecordLit) {
    Name some_name = interner_.intern("Some");
    Name none_name = interner_.intern("None");

    // Check for Some x: Builtin::Some with 1 arg (the payload)
    if (union_val->kind == Value::Kind::Builtin && union_val->builtin.b == Builtin::Some &&
        union_val->builtin.args->size() == 1) {
      if (auto* h = handler->fields->lookup(some_name)) {
        // Apply the Some handler to the payload
        return apply(*h, union_val->builtin.args->front());
      }
    }

    // Check for None T: Builtin::None with 1 arg (the type)
    if (union_val->kind == Value::Kind::Builtin && union_val->builtin.b == Builtin::None &&
        union_val->builtin.args->size() == 1) {
      if (auto* h = handler->fields->lookup(none_name)) {
        // Return the None handler directly (it's not a function)
        return *h;
      }
    }
  }

  // Stuck
  auto* v = alloc<Value>();
  v->kind = Value::Kind::Merge;
  v->merge = {handler, union_val, result_type};
  return v;
}

inline ValuePtr Evaluator::evalToMap(ValuePtr r, ValuePtr t) {
  // toMap { k1 = v1, k2 = v2 } = [ { mapKey = "k1", mapValue = v1 }, ... ]
  if (r->kind == Value::Kind::RecordLit) {
    auto* elems = alloc<std::vector<ValuePtr>>();
    elems->reserve(r->fields->size());

    Name mapKey = interner_.intern("mapKey");
    Name mapValue = interner_.intern("mapValue");

    // Collect and sort field names alphabetically
    std::vector<std::pair<std::string_view, ValuePtr>> sorted;
    sorted.reserve(r->fields->size());
    for (const auto& entry : *r->fields) {
      sorted.emplace_back(interner_.get(entry.name), entry.value);
    }
    std::sort(sorted.begin(), sorted.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    for (const auto& [name, value] : sorted) {
      auto* fs = alloc<Fields<ValuePtr>>();
      // Create text literal for key
      char* key_data = reinterpret_cast<char*>(arena_.alloc_array<char>(name.size() + 1).data());
      std::copy(name.begin(), name.end(), key_data);
      key_data[name.size()] = '\0';
      fs->insert(mapKey, mkLit(Lit::Text(key_data, name.size())));
      fs->insert(mapValue, value);
      elems->push_back(mkRecordLit(fs));
    }

    // Extract element type from List T annotation if present
    // t is the full type annotation: List { mapKey : Text, mapValue : T }
    // which is represented as Builtin::List with args = [{ mapKey : Text, mapValue : T }]
    // We need to extract just { mapKey : Text, mapValue : T } as the element type
    ValuePtr elemType = nullptr;
    if (t && t->kind == Value::Kind::Builtin && t->builtin.b == Builtin::List && t->builtin.args &&
        t->builtin.args->size() == 1) {
      elemType = t->builtin.args->front();
    }

    // Per Dhall spec: only include type annotation for empty lists
    if (elems->empty()) {
      return mkList(elemType, elems);
    }
    return mkList(nullptr, elems);
  }
  // Stuck
  auto* v = alloc<Value>();
  v->kind = Value::Kind::ToMap;
  v->tomap = {r, t};
  return v;
}

inline ValuePtr Evaluator::tryBuiltin(Builtin b, std::span<ValuePtr> args) {
  switch (b) {
    case Builtin::NaturalIsZero:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Bool(args[0]->lit.n == 0));
      }
      break;

    case Builtin::NaturalEven:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Bool(args[0]->lit.n % 2 == 0));
      }
      break;

    case Builtin::NaturalOdd:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Bool(args[0]->lit.n % 2 == 1));
      }
      break;

    case Builtin::NaturalToInteger:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat) {
        return mkLit(Lit::Int(static_cast<std::int64_t>(args[0]->lit.n)));
      }
      break;

    case Builtin::IntegerNegate:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Int) {
        return mkLit(Lit::Int(-args[0]->lit.i));
      }
      break;

    case Builtin::IntegerClamp:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Int) {
        // Clamp to non-negative Natural
        std::int64_t i = args[0]->lit.i;
        return mkLit(Lit::Nat(i < 0 ? 0 : static_cast<std::uint64_t>(i)));
      }
      break;

    case Builtin::IntegerToDouble:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Int) {
        return mkLit(Lit::Double(static_cast<double>(args[0]->lit.i)));
      }
      // Handle BigInt (integers too large for int64_t)
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::BigInt) {
        double val = args[0]->lit.big_int.value;
        if (args[0]->lit.big_int.negative) {
          val = -val;
        }
        return mkLit(Lit::Double(val));
      }
      break;

    case Builtin::DoubleShow:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Double) {
        // Format double as text
        std::string s;
        double d = args[0]->lit.d;
        if (std::isnan(d)) {
          s = "NaN";
        } else if (std::isinf(d)) {
          s = d > 0 ? "Infinity" : "-Infinity";
        } else {
          char buf[32];
          std::snprintf(buf, sizeof(buf), "%.15g", d);
          s = buf;
          if (s.find('.') == std::string::npos && s.find('e') == std::string::npos) {
            s += ".0";
          }
        }
        char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(s.size() + 1).data());
        std::copy(s.begin(), s.end(), data);
        data[s.size()] = '\0';
        return mkLit(Lit::Text(data, s.size()));
      }
      break;

    case Builtin::ListLength:
      if (args.size() == 2 && args[1]->kind == Value::Kind::List) {
        return mkLit(Lit::Nat(args[1]->list.elems->size()));
      }
      break;

    case Builtin::ListReverse:
      if (args.size() == 2 && args[1]->kind == Value::Kind::List) {
        auto* es = alloc<std::vector<ValuePtr>>(*args[1]->list.elems);
        std::reverse(es->begin(), es->end());
        return mkList(args[0], es); // Use args[0] as element type
      }
      break;

    case Builtin::ListHead:
      if (args.size() == 2 && args[1]->kind == Value::Kind::List) {
        if (args[1]->list.elems->empty()) {
          return apply(mkBuiltin(Builtin::None, alloc<std::vector<ValuePtr>>()), args[0]);
        }
        return apply(mkBuiltin(Builtin::Some, alloc<std::vector<ValuePtr>>()),
                     args[1]->list.elems->front());
      }
      break;

    case Builtin::ListLast:
      if (args.size() == 2 && args[1]->kind == Value::Kind::List) {
        if (args[1]->list.elems->empty()) {
          return apply(mkBuiltin(Builtin::None, alloc<std::vector<ValuePtr>>()), args[0]);
        }
        return apply(mkBuiltin(Builtin::Some, alloc<std::vector<ValuePtr>>()),
                     args[1]->list.elems->back());
      }
      break;

    case Builtin::NaturalShow:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat) {
        std::string s = std::to_string(args[0]->lit.n);
        char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(s.size() + 1).data());
        std::copy(s.begin(), s.end(), data);
        data[s.size()] = '\0';
        return mkLit(Lit::Text(data, s.size()));
      }
      break;

    case Builtin::IntegerShow:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Int) {
        std::string s;
        if (args[0]->lit.i >= 0) {
          s = "+" + std::to_string(args[0]->lit.i);
        } else {
          s = std::to_string(args[0]->lit.i);
        }
        char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(s.size() + 1).data());
        std::copy(s.begin(), s.end(), data);
        data[s.size()] = '\0';
        return mkLit(Lit::Text(data, s.size()));
      }
      break;

    case Builtin::NaturalSubtract:
      if (args.size() == 2 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat && args[1]->kind == Value::Kind::Lit &&
          args[1]->lit.kind == Lit::Kind::Nat) {
        // Natural/subtract x y = max(0, y - x)
        std::uint64_t x = args[0]->lit.n;
        std::uint64_t y = args[1]->lit.n;
        return mkLit(Lit::Nat(y > x ? y - x : 0));
      }
      // Natural/subtract 0 y → y
      if (args.size() == 2 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat && args[0]->lit.n == 0) {
        return args[1];
      }
      // Natural/subtract x 0 → 0 (because 0 - x = 0)
      if (args.size() == 2 && args[1]->kind == Value::Kind::Lit &&
          args[1]->lit.kind == Lit::Kind::Nat && args[1]->lit.n == 0) {
        return mkLit(Lit::Nat(0));
      }
      // Natural/subtract x x → 0 (when x and y are the same expression)
      if (args.size() == 2 && args[0] == args[1]) {
        return mkLit(Lit::Nat(0));
      }
      break;

    case Builtin::TextShow:
      if (args.size() == 1 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Text) {
        // Text/show escapes the text and wraps in quotes
        std::string result = "\"";
        for (std::size_t i = 0; i < args[0]->lit.text.len; ++i) {
          char c = args[0]->lit.text.data[i];
          switch (c) {
            case '"':
              result += "\\\"";
              break;
            case '\\':
              result += "\\\\";
              break;
            case '\n':
              result += "\\n";
              break;
            case '\r':
              result += "\\r";
              break;
            case '\t':
              result += "\\t";
              break;
            case '\b':
              result += "\\b";
              break;
            case '\f':
              result += "\\f";
              break;
            case '$':
              // Escape $ as \u0024 to avoid confusion with interpolation
              result += "\\u0024";
              break;
            default:
              if (static_cast<unsigned char>(c) < 0x20) {
                char buf[8];
                std::snprintf(buf, sizeof(buf), "\\u%04x", static_cast<unsigned char>(c));
                result += buf;
              } else {
                result += c;
              }
          }
        }
        result += "\"";
        char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(result.size() + 1).data());
        std::copy(result.begin(), result.end(), data);
        data[result.size()] = '\0';
        return mkLit(Lit::Text(data, result.size()));
      }
      break;

    case Builtin::TextReplace:
      // Text/replace needle replacement haystack
      // args[0] = needle (Text), args[1] = replacement (Text), args[2] = haystack (Text)
      if (args.size() == 3) {
        // Special case: empty needle returns haystack unchanged regardless of other args
        if (args[0]->kind == Value::Kind::Lit && args[0]->lit.kind == Lit::Kind::Text &&
            args[0]->lit.text.len == 0) {
          return args[2];
        }

        // Can only evaluate if needle and haystack are both text literals.
        // Replacement can be any text value (literal, variable, or TextAppend chain).
        // If haystack is not a literal (e.g., contains interpolations), leave as stuck.
        if (args[0]->kind == Value::Kind::Lit && args[0]->lit.kind == Lit::Kind::Text &&
            args[2]->kind == Value::Kind::Lit && args[2]->lit.kind == Lit::Kind::Text) {
          std::string_view needle(args[0]->lit.text.data, args[0]->lit.text.len);
          std::string_view haystack(args[2]->lit.text.data, args[2]->lit.text.len);
          ValuePtr replacement = args[1];

          // Find all positions where needle occurs
          std::vector<std::size_t> positions;
          std::size_t pos = 0;
          while (pos < haystack.size()) {
            std::size_t found = haystack.find(needle, pos);
            if (found == std::string_view::npos) {
              break;
            }
            positions.push_back(found);
            pos = found + needle.size();
          }

          // If no occurrences found, return haystack unchanged
          if (positions.empty()) {
            return args[2];
          }

          // Build result by interleaving literal segments with replacement value.
          // For "aXaXa" with needle "X" and replacement R:
          // Result = "a" ++ R ++ "a" ++ R ++ "a"

          // Helper to create a text literal value
          auto mkTextLit = [this](std::string_view s) -> ValuePtr {
            char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(s.size() + 1).data());
            std::copy(s.begin(), s.end(), data);
            data[s.size()] = '\0';
            return mkLit(Lit::Text(data, s.size()));
          };

          // Helper to concatenate two text values (handles empty strings)
          auto textConcat = [this](ValuePtr a, ValuePtr b) -> ValuePtr {
            // Skip empty string literals
            if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Text &&
                a->lit.text.len == 0) {
              return b;
            }
            if (b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Text &&
                b->lit.text.len == 0) {
              return a;
            }
            // If both are literals, concatenate them directly
            if (a->kind == Value::Kind::Lit && a->lit.kind == Lit::Kind::Text &&
                b->kind == Value::Kind::Lit && b->lit.kind == Lit::Kind::Text) {
              std::size_t len_a = a->lit.text.len;
              std::size_t len_b = b->lit.text.len;
              char* data =
                  reinterpret_cast<char*>(arena_.alloc_array<char>(len_a + len_b + 1).data());
              std::copy(a->lit.text.data, a->lit.text.data + len_a, data);
              std::copy(b->lit.text.data, b->lit.text.data + len_b, data + len_a);
              data[len_a + len_b] = '\0';
              return mkLit(Lit::Text(data, len_a + len_b));
            }
            // Otherwise create a TextAppend
            return mkBinop(Value::Kind::TextAppend, a, b);
          };

          // Build the result
          ValuePtr result = nullptr;
          std::size_t last_end = 0;

          for (std::size_t i = 0; i < positions.size(); ++i) {
            std::size_t match_pos = positions[i];

            // Add the literal segment before this match
            if (match_pos > last_end) {
              ValuePtr segment = mkTextLit(haystack.substr(last_end, match_pos - last_end));
              result = result ? textConcat(result, segment) : segment;
            }

            // Add the replacement
            result = result ? textConcat(result, replacement) : replacement;

            last_end = match_pos + needle.size();
          }

          // Add any remaining literal segment after the last match
          if (last_end < haystack.size()) {
            ValuePtr segment = mkTextLit(haystack.substr(last_end));
            result = result ? textConcat(result, segment) : segment;
          }

          // Handle edge case where result might be null (shouldn't happen if positions not empty)
          if (!result) {
            result = mkTextLit("");
          }

          return result;
        }
      }
      break;

    case Builtin::NaturalFold:
      // Natural/fold n T succ zero
      // args[0] = n (Natural), args[1] = T (Type), args[2] = succ, args[3] = zero
      if (args.size() == 4 && args[0]->kind == Value::Kind::Lit &&
          args[0]->lit.kind == Lit::Kind::Nat) {
        std::uint64_t n = args[0]->lit.n;
        ValuePtr succ = args[2];
        ValuePtr zero = args[3];
        // Guard against DoS via huge naturals.
        // fuel_remaining_ == 0 means unlimited (trusted inputs only).
        if (fuel_remaining_ != 0) {
          if (n > fuel_remaining_) {
            throw EvaluationBudgetExceeded("Natural/fold step count exceeds evaluation budget");
          }
          fuel_remaining_ -= n;
        }
        // Apply succ n times to zero: succ (succ (... (succ zero)))
        ValuePtr result = zero;
        for (std::uint64_t i = 0; i < n; ++i) {
          result = apply(succ, result);
        }
        return result;
      }
      break;

    case Builtin::NaturalBuild:
      // Natural/build f = f Natural (\(x : Natural) -> x + 1) 0
      // args[0] = f
      if (args.size() == 1) {
        ValuePtr f = args[0];
        // Create succ function: \(x : Natural) -> x + 1
        auto* succ_closure = alloc<Closure>();
        succ_closure->name = interner_.intern("x");
        succ_closure->env = Env{};
        // Body: NatPlus (Var 0) 1
        auto* plus_expr = alloc<Expr>();
        plus_expr->kind = Expr::Kind::NatPlus;
        plus_expr->binop = {mkExprVar(0), mkExprLit(Lit::Nat(1))};
        succ_closure->body = plus_expr;
        succ_closure->type = mkExprBuiltin(Builtin::Natural);
        auto* succ_val = alloc<Value>();
        succ_val->kind = Value::Kind::Lam;
        succ_val->closure = succ_closure;

        ValuePtr zero = mkLit(Lit::Nat(0));
        ValuePtr nat_type = mkBuiltin(Builtin::Natural, alloc<std::vector<ValuePtr>>());

        // f Natural succ 0
        ValuePtr r1 = apply(f, nat_type);
        ValuePtr r2 = apply(r1, succ_val);
        return apply(r2, zero);
      }
      break;

    case Builtin::ListFold:
      // List/fold T list R cons nil
      // args[0] = T (element type), args[1] = list, args[2] = R (result type)
      // args[3] = cons, args[4] = nil
      if (args.size() == 5 && args[1]->kind == Value::Kind::List) {
        ValuePtr cons = args[3];
        ValuePtr nil = args[4];
        auto& elems = *args[1]->list.elems;
        // Guard against DoS via huge lists.
        if (fuel_remaining_ != 0) {
          std::uint64_t cost = elems.size();
          if (cost > fuel_remaining_) {
            throw EvaluationBudgetExceeded("List/fold step count exceeds evaluation budget");
          }
          fuel_remaining_ -= cost;
        }
        // Fold right: cons a (cons b (cons c nil))
        ValuePtr result = nil;
        for (auto it = elems.rbegin(); it != elems.rend(); ++it) {
          ValuePtr elem = *it;
          ValuePtr partial = apply(cons, elem);
          result = apply(partial, result);
        }
        return result;
      }
      break;

    case Builtin::ListBuild:
      // List/build T f = f (List T) (\(a : T) -> \(as : List T) -> [a] # as) ([] : List T)
      // args[0] = T (element type), args[1] = f
      if (args.size() == 2) {
        ValuePtr elem_type = args[0];
        ValuePtr f = args[1];

        // Create cons function: \(a : T) -> \(as : List T) -> [a] # as
        // We capture elem_type in the environment so it's properly referenced when quoted
        // Env layout: [elem_type]
        // After outer lambda applied: [elem_type, a]
        // After inner lambda applied: [elem_type, a, as]
        // So: Var 0 = elem_type in outer type, Var 1 = elem_type in inner type
        //     Var 1 = a in inner body, Var 0 = as in inner body

        auto* outer_closure = alloc<Closure>();
        outer_closure->name = interner_.intern("a");
        outer_closure->env = Env{{elem_type}}; // Capture elem_type
        outer_closure->type = mkExprVar(0);    // Reference captured elem_type

        // Inner lambda: \(as : List T) -> [a] # as
        auto* inner_lambda = alloc<Expr>();
        inner_lambda->kind = Expr::Kind::Lam;
        // Type annotation: List T - Var 1 references elem_type (env: [elem_type, a])
        auto* list_type_expr = alloc<Expr>();
        list_type_expr->kind = Expr::Kind::App;
        list_type_expr->app = {mkExprBuiltin(Builtin::List), mkExprVar(1)};

        // Body: [Var 1] # Var 0 (env: [elem_type, a, as])
        // Var 1 = 'a' from outer lambda, Var 0 = 'as' from inner lambda
        auto* singleton = alloc<Expr>();
        singleton->kind = Expr::Kind::List;
        auto elem_span = arena_.alloc_array<ExprPtr>(1);
        elem_span[0] = mkExprVar(1);
        singleton->list = {nullptr, elem_span.data(), 1};

        auto* concat_expr = alloc<Expr>();
        concat_expr->kind = Expr::Kind::ListAppend;
        concat_expr->binop = {singleton, mkExprVar(0)};

        inner_lambda->lam = {interner_.intern("as"), list_type_expr, concat_expr};
        outer_closure->body = inner_lambda;

        auto* cons_val = alloc<Value>();
        cons_val->kind = Value::Kind::Lam;
        cons_val->closure = outer_closure;

        // Empty list: [] : List T
        auto* empty_elems = alloc<std::vector<ValuePtr>>();
        ValuePtr nil = mkList(elem_type, empty_elems);

        // List T
        ValuePtr list_type =
            apply(mkBuiltin(Builtin::List, alloc<std::vector<ValuePtr>>()), elem_type);

        // f (List T) cons nil
        ValuePtr r1 = apply(f, list_type);
        ValuePtr r2 = apply(r1, cons_val);
        return apply(r2, nil);
      }
      break;

    case Builtin::ListIndexed:
      // List/indexed T list = [{ index = 0, value = a }, { index = 1, value = b }, ...]
      // args[0] = T (element type), args[1] = list
      if (args.size() == 2 && args[1]->kind == Value::Kind::List) {
        auto& elems = *args[1]->list.elems;
        auto* result_elems = alloc<std::vector<ValuePtr>>();
        result_elems->reserve(elems.size());

        Name index_name = interner_.intern("index");
        Name value_name = interner_.intern("value");

        for (std::size_t i = 0; i < elems.size(); ++i) {
          auto* fs = alloc<Fields<ValuePtr>>();
          fs->insert(index_name, mkLit(Lit::Nat(i)));
          fs->insert(value_name, elems[i]);
          result_elems->push_back(mkRecordLit(fs));
        }

        // Result type: { index : Natural, value : T }
        auto* result_type_fs = alloc<Fields<ValuePtr>>();
        result_type_fs->insert(index_name,
                               mkBuiltin(Builtin::Natural, alloc<std::vector<ValuePtr>>()));
        result_type_fs->insert(value_name, args[0]);
        auto* result_type = alloc<Value>();
        result_type->kind = Value::Kind::Record;
        result_type->fields = result_type_fs;

        return mkList(result_type, result_elems);
      }
      break;

    case Builtin::ShowConstructor:
      // showConstructor takes a union value (represented as RecordLit with single field)
      // and returns the constructor name as Text
      // Union values are represented as { constructorName = payload }
      if (args.size() == 1 && args[0]->kind == Value::Kind::RecordLit && args[0]->fields &&
          args[0]->fields->size() == 1) {
        // Get the single field's name - that's the constructor name
        const auto& entry = *args[0]->fields->begin();
        std::string_view name_str = interner_.get(entry.name);
        char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(name_str.size() + 1).data());
        std::copy(name_str.begin(), name_str.end(), data);
        data[name_str.size()] = '\0';
        return mkLit(Lit::Text(data, name_str.size()));
      }
      break;

    default:
      break;
  }
  auto* v = alloc<std::vector<ValuePtr>>(args.begin(), args.end());
  return mkBuiltin(b, v);
}

inline ExprPtr Evaluator::quote(int level, ValuePtr v) {
  switch (v->kind) {
    case Value::Kind::Const:
      return mkExprConst(v->const_val);

    case Value::Kind::Var:
      return mkExprVar(static_cast<std::uint32_t>(level - v->var_level - 1));

    case Value::Kind::Lam: {
      auto* fresh = mkVar(level);
      auto body = eval(v->closure->env.extend(fresh), v->closure->body);
      // Use the stored type if available, normalize it in the current env
      ExprPtr typeExpr = v->closure->type ? quote(level, eval(v->closure->env, v->closure->type))
                                          : mkExprConst(Const::Type);
      return mkExprLam(v->closure->name, typeExpr, quote(level + 1, body));
    }

    case Value::Kind::Pi: {
      auto* fresh = mkVar(level);
      auto cod = eval(v->pi.codomain->env.extend(fresh), v->pi.codomain->body);
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Pi;
      e->pi = {v->pi.codomain->name, quote(level, v->pi.domain), quote(level + 1, cod)};
      return e;
    }

    case Value::Kind::App:
      return mkExprApp(quote(level, v->app.func), quote(level, v->app.arg));

    case Value::Kind::Builtin:
      if (v->builtin.args->empty()) {
        return mkExprBuiltin(v->builtin.b);
      } else {
        ExprPtr e = mkExprBuiltin(v->builtin.b);
        for (auto* arg : *v->builtin.args) {
          e = mkExprApp(e, quote(level, arg));
        }
        return e;
      }

    case Value::Kind::Lit:
      return mkExprLit(v->lit);

    case Value::Kind::List: {
      auto span = arena_.alloc_array<ExprPtr>(v->list.elems->size());
      for (std::size_t i = 0; i < v->list.elems->size(); ++i) {
        span[i] = quote(level, (*v->list.elems)[i]);
      }
      return mkExprList(v->list.type ? quote(level, v->list.type) : nullptr, span.data(),
                        span.size());
    }

    case Value::Kind::RecordLit: {
      auto* fs = alloc<Fields<ExprPtr>>();
      fs->reserve(v->fields->size());
      for (const auto& entry : *v->fields) {
        fs->push_back_unchecked(entry.name, quote(level, entry.value));
      }
      return mkExprRecordLit(fs);
    }

    case Value::Kind::Record: {
      auto* fs = alloc<Fields<ExprPtr>>();
      fs->reserve(v->fields->size());
      for (const auto& entry : *v->fields) {
        fs->push_back_unchecked(entry.name, quote(level, entry.value));
      }
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Record;
      e->fields = fs;
      return e;
    }

    case Value::Kind::Union: {
      auto* fs = alloc<Fields<ExprPtr>>();
      fs->reserve(v->fields->size());
      for (const auto& entry : *v->fields) {
        fs->push_back_unchecked(entry.name, quote(level, entry.value));
      }
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Union;
      e->fields = fs;
      return e;
    }

    case Value::Kind::Field:
      return mkExprField(quote(level, v->field.record), v->field.name);

    case Value::Kind::Prefer:
      return mkExprPrefer(quote(level, v->prefer.lhs), quote(level, v->prefer.rhs));

    case Value::Kind::BoolIf: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::BoolIf;
      e->if_ = {quote(level, v->if_.cond), quote(level, v->if_.then_), quote(level, v->if_.else_)};
      return e;
    }

    case Value::Kind::BoolAnd: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::BoolAnd;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::BoolOr: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::BoolOr;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::BoolEq: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::BoolEq;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::BoolNeq: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::BoolNeq;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::NatPlus: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::NatPlus;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::NatTimes: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::NatTimes;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::TextAppend: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::TextAppend;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::ListAppend: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::ListAppend;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::Project: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Project;
      e->project = {quote(level, v->project.record), v->project.field_names, v->project.count};
      return e;
    }

    case Value::Kind::Combine: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Combine;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::CombineTypes: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::CombineTypes;
      e->binop = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::Assert: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Assert;
      e->assert_ = {quote(level, v->assert_.type)};
      return e;
    }

    case Value::Kind::Equiv: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Equiv;
      e->equiv = {quote(level, v->binop.lhs), quote(level, v->binop.rhs)};
      return e;
    }

    case Value::Kind::With: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::With;
      e->with = {quote(level, v->with.record), v->with.path, v->with.path_len,
                 quote(level, v->with.value)};
      return e;
    }

    case Value::Kind::Merge: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Merge;
      e->merge = {quote(level, v->merge.handler), quote(level, v->merge.union_val),
                  v->merge.result_type ? quote(level, v->merge.result_type) : nullptr};
      return e;
    }

    case Value::Kind::ToMap: {
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::ToMap;
      e->tomap = {quote(level, v->tomap.record),
                  v->tomap.result_type ? quote(level, v->tomap.result_type) : nullptr};
      return e;
    }
  }

  return mkExprConst(Const::Type);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERIALIZER - Convert Values/Exprs to Dhall text
// ═══════════════════════════════════════════════════════════════════════════════

class Serializer {
  Interner& interner_;
  std::string out_;
  int indent_ = 0;
  bool compact_ = false;
  std::vector<Name> ctx_; // Context for variable name lookup

  void write(std::string_view s) { out_.append(s); }
  void write(char c) { out_.push_back(c); }

public:
  explicit Serializer(Interner& interner, bool compact = false)
      : interner_(interner), compact_(compact) {}

  /// Serialize a Value to Dhall text
  std::string serialize(ValuePtr v) {
    out_.clear();
    ctx_.clear();
    writeValue(v);
    return std::move(out_);
  }

  /// Serialize an Expr to Dhall text
  std::string serialize(ExprPtr e) {
    out_.clear();
    ctx_.clear();
    writeExpr(e);
    return std::move(out_);
  }

private:
  // Check if a name is a Dhall keyword that needs backtick quoting
  bool needsQuoting(std::string_view name) {
    // Reserved keywords in Dhall
    return name == "if" || name == "then" || name == "else" || name == "let" || name == "in" ||
           name == "as" || name == "using" || name == "merge" || name == "toMap" ||
           name == "forall" || name == "assert" || name == "with" || name == "missing" ||
           name == "Infinity" || name == "NaN";
  }

  // Write a variable name, quoting if necessary
  void writeName(std::string_view name) {
    if (needsQuoting(name)) {
      write('`');
      write(name);
      write('`');
    } else {
      write(name);
    }
  }

  void newline() {
    if (compact_) {
      write(' ');
    } else {
      write('\n');
      for (int i = 0; i < indent_; ++i) {
        write("  ");
      }
    }
  }

  void writeBuiltinName(Builtin b) {
    switch (b) {
      case Builtin::Bool:
        write("Bool");
        break;
      case Builtin::Natural:
        write("Natural");
        break;
      case Builtin::Integer:
        write("Integer");
        break;
      case Builtin::Double:
        write("Double");
        break;
      case Builtin::Text:
        write("Text");
        break;
      case Builtin::List:
        write("List");
        break;
      case Builtin::Optional:
        write("Optional");
        break;
      case Builtin::None:
        write("None");
        break;
      case Builtin::Some:
        write("Some");
        break;
      case Builtin::NaturalFold:
        write("Natural/fold");
        break;
      case Builtin::NaturalBuild:
        write("Natural/build");
        break;
      case Builtin::NaturalIsZero:
        write("Natural/isZero");
        break;
      case Builtin::NaturalEven:
        write("Natural/even");
        break;
      case Builtin::NaturalOdd:
        write("Natural/odd");
        break;
      case Builtin::NaturalSubtract:
        write("Natural/subtract");
        break;
      case Builtin::NaturalToInteger:
        write("Natural/toInteger");
        break;
      case Builtin::NaturalShow:
        write("Natural/show");
        break;
      case Builtin::IntegerClamp:
        write("Integer/clamp");
        break;
      case Builtin::IntegerNegate:
        write("Integer/negate");
        break;
      case Builtin::IntegerToDouble:
        write("Integer/toDouble");
        break;
      case Builtin::IntegerShow:
        write("Integer/show");
        break;
      case Builtin::DoubleShow:
        write("Double/show");
        break;
      case Builtin::ListBuild:
        write("List/build");
        break;
      case Builtin::ListFold:
        write("List/fold");
        break;
      case Builtin::ListLength:
        write("List/length");
        break;
      case Builtin::ListHead:
        write("List/head");
        break;
      case Builtin::ListLast:
        write("List/last");
        break;
      case Builtin::ListIndexed:
        write("List/indexed");
        break;
      case Builtin::ListReverse:
        write("List/reverse");
        break;
      case Builtin::TextShow:
        write("Text/show");
        break;
      case Builtin::TextReplace:
        write("Text/replace");
        break;
      case Builtin::ShowConstructor:
        write("showConstructor");
        break;
      case Builtin::Bytes:
        write("Bytes");
        break;
    }
  }

  void writeConstName(Const c) {
    switch (c) {
      case Const::Type:
        write("Type");
        break;
      case Const::Kind:
        write("Kind");
        break;
      case Const::Sort:
        write("Sort");
        break;
    }
  }

  void writeLit(const Lit& lit) {
    switch (lit.kind) {
      case Lit::Kind::Bool:
        write(lit.b ? "True" : "False");
        break;
      case Lit::Kind::Nat:
        write(std::to_string(lit.n));
        break;
      case Lit::Kind::Int:
        if (lit.i >= 0) {
          write('+');
        }
        write(std::to_string(lit.i));
        break;
      case Lit::Kind::Double: {
        // Handle special values
        if (std::isinf(lit.d)) {
          write(lit.d > 0 ? "Infinity" : "-Infinity");
        } else if (std::isnan(lit.d)) {
          write("NaN");
        } else {
          // Format double with full precision (17 digits for IEEE 754)
          char buf[32];
          std::snprintf(buf, sizeof(buf), "%.17g", lit.d);
          std::string s = buf;
          // Remove '+' from exponent (e.g., e+308 -> e308) for Dhall format
          std::size_t epos = s.find("e+");
          if (epos != std::string::npos) {
            s.erase(epos + 1, 1);
          }
          // Ensure there's a decimal point for Dhall (not an integer)
          if (s.find('.') == std::string::npos && s.find('e') == std::string::npos) {
            s += ".0";
          }
          write(s);
        }
        break;
      }
      case Lit::Kind::BigInt: {
        // Big integer - write as double approximation (for display purposes)
        // In practice, BigInt is converted to Double via Integer/toDouble
        double val = lit.big_int.value;
        if (lit.big_int.negative) {
          val = -val;
        }
        if (std::isinf(val)) {
          write(val > 0 ? "+Infinity" : "-Infinity");
        } else {
          char buf[32];
          std::snprintf(buf, sizeof(buf), "%+.15g", val);
          write(buf);
        }
        break;
      }
      case Lit::Kind::Text: {
        // Check if text contains newlines - if so, use multiline format
        bool hasNewline = false;
        for (std::size_t i = 0; i < lit.text.len; ++i) {
          if (lit.text.data[i] == '\n') {
            hasNewline = true;
            break;
          }
        }
        if (hasNewline) {
          // Multiline string format: ''<newline>content''
          write("''\n");
          for (std::size_t i = 0; i < lit.text.len; ++i) {
            char c = lit.text.data[i];
            if (c == '$' && i + 1 < lit.text.len && lit.text.data[i + 1] == '{') {
              // Escape interpolation syntax
              write("''${");
              ++i; // Skip the '{'
            } else if (c == '\'' && i + 1 < lit.text.len && lit.text.data[i + 1] == '\'') {
              // Escape '' within multiline strings
              write("'''");
              ++i; // Skip the second '
            } else {
              write(c);
            }
          }
          write("''");
        } else {
          write('"');
          // Escape special characters
          for (std::size_t i = 0; i < lit.text.len; ++i) {
            char c = lit.text.data[i];
            switch (c) {
              case '"':
                write("\\\"");
                break;
              case '\\':
                write("\\\\");
                break;
              case '\n':
                write("\\n");
                break;
              case '\r':
                write("\\r");
                break;
              case '\t':
                write("\\t");
                break;
              case '$':
                // Escape $ only if followed by { to prevent interpolation
                if (i + 1 < lit.text.len && lit.text.data[i + 1] == '{') {
                  write("\\u0024");
                } else {
                  write(c);
                }
                break;
              default:
                write(c);
                break;
            }
          }
          write('"');
        }
        break;
      }
      case Lit::Kind::Bytes:
        write("0x\"");
        for (std::size_t i = 0; i < lit.bytes.len; ++i) {
          write(lit.bytes.data[i]);
        }
        write('"');
        break;
    }
  }

  void writeValue(ValuePtr v) {
    if (!v) {
      write("<null>");
      return;
    }

    switch (v->kind) {
      case Value::Kind::Const:
        writeConstName(v->const_val);
        break;

      case Value::Kind::Var:
        write("@");
        write(std::to_string(v->var_level));
        break;

      case Value::Kind::Lam:
        write("\\(");
        writeName(interner_.get(v->closure->name));
        write(" : _) -> <closure>");
        break;

      case Value::Kind::Pi:
        write("forall (");
        writeName(interner_.get(v->pi.codomain->name));
        write(" : ");
        writeValue(v->pi.domain);
        write(") -> <closure>");
        break;

      case Value::Kind::App:
        write('(');
        writeValue(v->app.func);
        write(' ');
        writeValue(v->app.arg);
        write(')');
        break;

      case Value::Kind::Builtin:
        writeBuiltinName(v->builtin.b);
        if (v->builtin.args && !v->builtin.args->empty()) {
          for (auto* arg : *v->builtin.args) {
            write(' ');
            writeValue(arg);
          }
        }
        break;

      case Value::Kind::Lit:
        writeLit(v->lit);
        break;

      case Value::Kind::List:
        write('[');
        if (v->list.elems && !v->list.elems->empty()) {
          write(' ');
          bool first = true;
          for (auto* elem : *v->list.elems) {
            if (!first) {
              write(", ");
            }
            first = false;
            writeValue(elem);
          }
          write(' ');
        }
        write(']');
        break;

      case Value::Kind::RecordLit:
        writeRecordLitValue(v->fields);
        break;

      case Value::Kind::Record:
        write("{ ");
        if (v->fields) {
          // Sort fields alphabetically
          std::vector<std::pair<std::string_view, ValuePtr>> sorted;
          sorted.reserve(v->fields->size());
          for (const auto& entry : *v->fields) {
            sorted.emplace_back(interner_.get(entry.name), entry.value);
          }
          std::sort(sorted.begin(), sorted.end(),
                    [](const auto& a, const auto& b) { return a.first < b.first; });

          bool first = true;
          for (const auto& [name, value] : sorted) {
            if (!first) {
              write(", ");
            }
            first = false;
            write(name);
            write(" : ");
            writeValue(value);
          }
        }
        write(" }");
        break;

      case Value::Kind::Union:
        write("< ");
        if (v->fields) {
          // Sort fields alphabetically
          std::vector<std::pair<std::string_view, ValuePtr>> sorted;
          sorted.reserve(v->fields->size());
          for (const auto& entry : *v->fields) {
            sorted.emplace_back(interner_.get(entry.name), entry.value);
          }
          std::sort(sorted.begin(), sorted.end(),
                    [](const auto& a, const auto& b) { return a.first < b.first; });

          bool first = true;
          for (const auto& [name, value] : sorted) {
            if (!first) {
              write(" | ");
            }
            first = false;
            write(name);
            // Check if constructor has a payload (not empty record)
            bool has_payload = !(value->kind == Value::Kind::RecordLit && value->fields &&
                                 value->fields->size() == 0);
            if (has_payload) {
              write(" : ");
              writeValue(value);
            }
          }
        }
        write(" >");
        break;

      case Value::Kind::Field:
        writeValue(v->field.record);
        write('.');
        write(interner_.get(v->field.name));
        break;

      case Value::Kind::Prefer:
        writeValue(v->prefer.lhs);
        write(" ⫽ ");
        writeValue(v->prefer.rhs);
        break;

      case Value::Kind::BoolIf:
        write("if ");
        writeValue(v->if_.cond);
        write(" then ");
        writeValue(v->if_.then_);
        write(" else ");
        writeValue(v->if_.else_);
        break;

      case Value::Kind::BoolAnd:
        writeValue(v->binop.lhs);
        write(" && ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::BoolOr:
        writeValue(v->binop.lhs);
        write(" || ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::BoolEq:
        writeValue(v->binop.lhs);
        write(" == ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::BoolNeq:
        writeValue(v->binop.lhs);
        write(" != ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::NatPlus:
        writeValue(v->binop.lhs);
        write(" + ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::NatTimes:
        writeValue(v->binop.lhs);
        write(" * ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::TextAppend:
        writeValue(v->binop.lhs);
        write(" ++ ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::ListAppend:
        writeValue(v->binop.lhs);
        write(" # ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::Project:
        writeValue(v->project.record);
        write(".{ ");
        for (std::size_t i = 0; i < v->project.count; ++i) {
          if (i > 0) {
            write(", ");
          }
          write(interner_.get(v->project.field_names[i]));
        }
        write(" }");
        break;

      case Value::Kind::Combine:
        writeValue(v->binop.lhs);
        write(" ∧ ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::CombineTypes:
        writeValue(v->binop.lhs);
        write(" ⩓ ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::Assert:
        write("assert : ");
        writeValue(v->assert_.type);
        break;

      case Value::Kind::Equiv:
        writeValue(v->binop.lhs);
        write(" ≡ ");
        writeValue(v->binop.rhs);
        break;

      case Value::Kind::With:
        writeValue(v->with.record);
        write(" with ");
        for (std::size_t i = 0; i < v->with.path_len; ++i) {
          if (i > 0) {
            write(".");
          }
          write(interner_.get(v->with.path[i]));
        }
        write(" = ");
        writeValue(v->with.value);
        break;

      case Value::Kind::Merge:
        write("merge ");
        writeValue(v->merge.handler);
        write(" ");
        writeValue(v->merge.union_val);
        if (v->merge.result_type) {
          write(" : ");
          writeValue(v->merge.result_type);
        }
        break;

      case Value::Kind::ToMap:
        write("toMap ");
        writeValue(v->tomap.record);
        if (v->tomap.result_type) {
          write(" : ");
          writeValue(v->tomap.result_type);
        }
        break;
    }
  }

  // Write a record literal value in compact format (single line)
  void writeRecordLitValueCompact(Fields<ValuePtr>* fields) {
    if (!fields || fields->size() == 0) {
      write("{=}");
      return;
    }

    // Collect entries and sort alphabetically by field name
    std::vector<std::pair<std::string_view, ValuePtr>> sorted;
    sorted.reserve(fields->size());
    for (const auto& entry : *fields) {
      sorted.emplace_back(interner_.get(entry.name), entry.value);
    }
    std::sort(sorted.begin(), sorted.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    // Compact format: { field1 = value1, field2 = value2 }
    write("{ ");
    bool first = true;
    for (const auto& [name, value] : sorted) {
      if (!first) {
        write(", ");
      }
      first = false;
      write(name);
      write(" = ");
      bool saved_compact = compact_;
      compact_ = true;
      writeValue(value);
      compact_ = saved_compact;
    }
    write(" }");
  }

  // Estimate the length of a compact serialization for a Value
  std::size_t estimateCompactLength(ValuePtr v) {
    if (!v) {
      return 6;
    }

    switch (v->kind) {
      case Value::Kind::Const:
        return 4;
      case Value::Kind::Var:
        return 5;
      case Value::Kind::Builtin:
        return 15;
      case Value::Kind::Lit:
        switch (v->lit.kind) {
          case Lit::Kind::Bool:
            return 5;
          case Lit::Kind::Nat:
            return 5;
          case Lit::Kind::Int:
            return 6;
          case Lit::Kind::Double:
            return 10;
          case Lit::Kind::Text:
            return v->lit.text.len + 2;
          case Lit::Kind::BigInt:
            return 15;
          case Lit::Kind::Bytes:
            return v->lit.bytes.len + 4; // 0x"..." prefix/suffix
        }
        return 10;
      case Value::Kind::Lam:
      case Value::Kind::Pi:
        return 100;
      case Value::Kind::App:
        return estimateCompactLength(v->app.func) + 1 + estimateCompactLength(v->app.arg);
      case Value::Kind::List:
        if (!v->list.elems || v->list.elems->empty()) {
          return 2;
        }
        {
          std::size_t len = 4;
          for (auto* elem : *v->list.elems) {
            len += estimateCompactLength(elem) + 2;
          }
          return len;
        }
      case Value::Kind::RecordLit:
        if (!v->fields || v->fields->size() == 0) {
          return 3;
        }
        {
          std::size_t len = 4;
          for (const auto& entry : *v->fields) {
            len += interner_.get(entry.name).size() + 3;
            len += estimateCompactLength(entry.value) + 2;
          }
          return len;
        }
      default:
        return 50;
    }
  }

  void writeRecordLitValue(Fields<ValuePtr>* fields) {
    // In compact mode, use single-line format
    if (compact_) {
      writeRecordLitValueCompact(fields);
      return;
    }

    if (!fields || fields->size() == 0) {
      write("{=}");
      return;
    }

    // Collect entries and sort alphabetically by field name
    std::vector<std::pair<std::string_view, ValuePtr>> sorted;
    sorted.reserve(fields->size());
    for (const auto& entry : *fields) {
      sorted.emplace_back(interner_.get(entry.name), entry.value);
    }
    std::sort(sorted.begin(), sorted.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    // Estimate total compact length to decide format
    std::size_t total_len = 4;
    for (const auto& [name, value] : sorted) {
      total_len += name.size() + 3;
      total_len += estimateCompactLength(value) + 2;
    }

    // If fits on one line (< 80 chars), use compact format
    if (total_len < 80) {
      writeRecordLitValueCompact(fields);
      return;
    }

    // Multiline format - values that are RecordLit stay on same line
    bool first = true;
    for (const auto& [name, value] : sorted) {
      if (first) {
        write("{ ");
        first = false;
      } else {
        newline();
        write(", ");
      }
      write(name);
      write(" =");

      bool value_on_same_line = (value->kind == Value::Kind::RecordLit);

      if (value_on_same_line) {
        write(' ');
        bool saved_compact = compact_;
        compact_ = true;
        writeValue(value);
        compact_ = saved_compact;
      } else {
        write('\n');
        indent_ += 2;
        for (int i = 0; i < indent_; ++i) {
          write("  ");
        }
        bool saved_compact = compact_;
        compact_ = true;
        writeValue(value);
        compact_ = saved_compact;
        indent_ -= 2;
      }
    }
    newline();
    write('}');
  }

  /// Collect all parts of a TextAppend chain into a vector
  void collectTextAppendParts(ExprPtr e, std::vector<ExprPtr>& parts) {
    if (e->kind == Expr::Kind::TextAppend) {
      collectTextAppendParts(e->binop.lhs, parts);
      collectTextAppendParts(e->binop.rhs, parts);
    } else {
      parts.push_back(e);
    }
  }

  /// Write the inner content of a text literal (without quotes), escaping special characters
  void writeTextLitInner(const Lit& lit) {
    for (std::size_t i = 0; i < lit.text.len; ++i) {
      char c = lit.text.data[i];
      switch (c) {
        case '"':
          write("\\\"");
          break;
        case '\\':
          write("\\\\");
          break;
        case '\n':
          write("\\n");
          break;
        case '\r':
          write("\\r");
          break;
        case '\t':
          write("\\t");
          break;
        case '$':
          // Escape ${ to prevent unintended interpolation
          if (i + 1 < lit.text.len && lit.text.data[i + 1] == '{') {
            write("\\${");
            ++i; // skip the '{'
          } else {
            write(c);
          }
          break;
        default:
          write(c);
          break;
      }
    }
  }

  /// Write a TextAppend chain as an interpolated string: "literal${expr}literal"
  void writeTextAppendAsInterpolated(ExprPtr e) {
    std::vector<ExprPtr> parts;
    collectTextAppendParts(e, parts);

    write('"');
    for (ExprPtr part : parts) {
      if (part->kind == Expr::Kind::Lit && part->lit.kind == Lit::Kind::Text) {
        // Write literal text content directly (without quotes)
        writeTextLitInner(part->lit);
      } else {
        // Write as interpolation: ${expr}
        write("${");
        writeExpr(part);
        write('}');
      }
    }
    write('"');
  }

  void writeExpr(ExprPtr e) {
    if (!e) {
      write("<null>");
      return;
    }

    switch (e->kind) {
      case Expr::Kind::Const:
        writeConstName(e->const_val);
        break;

      case Expr::Kind::Var: {
        // Look up variable name from context using de Bruijn index
        std::uint32_t idx = e->var_idx;
        if (idx < ctx_.size()) {
          Name varName = ctx_[ctx_.size() - 1 - idx];
          writeName(interner_.get(varName));
          // Count how many times this name appears before in context (for shadowing)
          int shadowCount = 0;
          for (std::size_t i = ctx_.size() - 1 - idx + 1; i < ctx_.size(); ++i) {
            if (ctx_[i] == varName) {
              shadowCount++;
            }
          }
          if (shadowCount > 0) {
            write("@");
            write(std::to_string(shadowCount));
          }
        } else {
          // Free variable - shouldn't happen in normalized code
          write("@");
          write(std::to_string(idx));
        }
        break;
      }

      case Expr::Kind::Builtin:
        writeBuiltinName(e->builtin);
        break;

      case Expr::Kind::Lam:
        write("λ(");
        writeName(interner_.get(e->lam.name));
        write(" : ");
        writeExpr(e->lam.type);
        write(") → ");
        ctx_.push_back(e->lam.name);
        writeExpr(e->lam.body);
        ctx_.pop_back();
        break;

      case Expr::Kind::Pi: {
        // Check if this is a non-dependent function type (name is "_")
        std::string_view name = interner_.get(e->pi.name);
        if (name == "_") {
          // Simple arrow type: A → B
          // Still need to push to context for correct de Bruijn index handling
          // If domain is also an arrow type (non-dependent Pi), wrap in parens
          bool domainNeedsParens =
              e->pi.domain->kind == Expr::Kind::Pi && interner_.get(e->pi.domain->pi.name) == "_";
          if (domainNeedsParens) {
            write('(');
          }
          writeExpr(e->pi.domain);
          if (domainNeedsParens) {
            write(')');
          }
          write(" → ");
          ctx_.push_back(e->pi.name);
          writeExpr(e->pi.codomain);
          ctx_.pop_back();
        } else {
          // Dependent function type: ∀(x : A) → B
          write("∀(");
          writeName(name);
          write(" : ");
          writeExpr(e->pi.domain);
          write(") → ");
          ctx_.push_back(e->pi.name);
          writeExpr(e->pi.codomain);
          ctx_.pop_back();
        }
        break;
      }

      case Expr::Kind::App:
        writeExpr(e->app.func);
        write(' ');
        // Wrap argument in parens if it's an application (for correct associativity)
        // or if it's an empty list with type annotation (needs parens for precedence)
        if (e->app.arg->kind == Expr::Kind::App || e->app.arg->kind == Expr::Kind::Lam ||
            e->app.arg->kind == Expr::Kind::Pi || e->app.arg->kind == Expr::Kind::Let ||
            e->app.arg->kind == Expr::Kind::BoolIf ||
            (e->app.arg->kind == Expr::Kind::List && e->app.arg->list.count == 0 &&
             e->app.arg->list.type)) {
          write('(');
          writeExpr(e->app.arg);
          write(')');
        } else {
          writeExpr(e->app.arg);
        }
        break;

      case Expr::Kind::Let:
        write("let ");
        writeName(interner_.get(e->let.name));
        if (e->let.type) {
          write(" : ");
          writeExpr(e->let.type);
        }
        write(" = ");
        writeExpr(e->let.value);
        write(" in ");
        ctx_.push_back(e->let.name);
        writeExpr(e->let.body);
        ctx_.pop_back();
        break;

      case Expr::Kind::Lit:
        writeLit(e->lit);
        break;

      case Expr::Kind::BoolAnd:
      case Expr::Kind::BoolOr:
      case Expr::Kind::BoolEq:
      case Expr::Kind::BoolNeq:
        writeExpr(e->binop.lhs);
        write(e->kind == Expr::Kind::BoolAnd   ? " && "
              : e->kind == Expr::Kind::BoolOr  ? " || "
              : e->kind == Expr::Kind::BoolNeq ? " != "
                                               : " == ");
        writeExpr(e->binop.rhs);
        break;

      case Expr::Kind::BoolIf:
        write("if ");
        writeExpr(e->if_.cond);
        write(" then ");
        writeExpr(e->if_.then_);
        write(" else ");
        writeExpr(e->if_.else_);
        break;

      case Expr::Kind::NatPlus:
      case Expr::Kind::NatTimes:
        writeExpr(e->binop.lhs);
        write(e->kind == Expr::Kind::NatPlus ? " + " : " * ");
        writeExpr(e->binop.rhs);
        break;

      case Expr::Kind::TextAppend:
        // Write as interpolated string: "literal${expr}literal"
        writeTextAppendAsInterpolated(e);
        break;

      case Expr::Kind::ListAppend:
        writeExpr(e->binop.lhs);
        write(" # ");
        writeExpr(e->binop.rhs);
        break;

      case Expr::Kind::List: {
        // Estimate list size to decide format
        std::size_t total_len = 4; // "[ " + " ]"
        for (std::size_t i = 0; i < e->list.count; ++i) {
          total_len += estimateCompactLength(e->list.elems[i]) + 2; // ", "
        }
        bool use_compact = compact_ || total_len < 60;

        write('[');
        if (e->list.count > 0) {
          if (use_compact) {
            // Compact format: [ elem1, elem2, elem3 ]
            write(' ');
            for (std::size_t i = 0; i < e->list.count; ++i) {
              if (i > 0) {
                write(", ");
              }
              bool saved = compact_;
              compact_ = true;
              writeExpr(e->list.elems[i]);
              compact_ = saved;
            }
            write(' ');
          } else {
            // List with elements: comma-first style with each element on its own line
            // [ { mapKey = "bar", mapValue = 4 }
            // , { mapKey = "baz", mapValue = 9 }
            // ]
            for (std::size_t i = 0; i < e->list.count; ++i) {
              if (i == 0) {
                write(' ');
              } else {
                newline();
                write(", ");
              }
              // List elements are written in compact mode
              bool saved_compact = compact_;
              compact_ = true;
              writeExpr(e->list.elems[i]);
              compact_ = saved_compact;
            }
            newline();
          }
        }
        write(']');
        // Only include type annotation for empty lists (where it's required)
        if (e->list.count == 0 && e->list.type) {
          write(" : List ");
          writeExpr(e->list.type);
        }
        break;
      }

      case Expr::Kind::RecordLit:
        writeRecordLitExpr(e->fields);
        break;

      case Expr::Kind::Record:
        if (e->fields && e->fields->size() > 0) {
          write("{ ");
          // Sort fields alphabetically
          std::vector<std::pair<std::string_view, ExprPtr>> sorted;
          sorted.reserve(e->fields->size());
          for (const auto& entry : *e->fields) {
            sorted.emplace_back(interner_.get(entry.name), entry.value);
          }
          std::sort(sorted.begin(), sorted.end(),
                    [](const auto& a, const auto& b) { return a.first < b.first; });

          bool first = true;
          for (const auto& [name, value] : sorted) {
            if (!first) {
              write(", ");
            }
            first = false;
            write(name);
            write(" : ");
            writeExpr(value);
          }
          write(" }");
        } else {
          write("{}");
        }
        break;

      case Expr::Kind::Union:
        if (e->fields && e->fields->size() > 0) {
          write("< ");
          // Sort fields alphabetically
          std::vector<std::pair<std::string_view, ExprPtr>> sorted;
          sorted.reserve(e->fields->size());
          for (const auto& entry : *e->fields) {
            sorted.emplace_back(interner_.get(entry.name), entry.value);
          }
          std::sort(sorted.begin(), sorted.end(),
                    [](const auto& a, const auto& b) { return a.first < b.first; });

          bool first = true;
          for (const auto& [name, value] : sorted) {
            if (!first) {
              write(" | ");
            }
            first = false;
            write(name);
            // Check if constructor has a payload (not empty record literal)
            bool has_payload = !(value->kind == Expr::Kind::RecordLit && value->fields &&
                                 value->fields->size() == 0);
            if (has_payload) {
              write(" : ");
              writeExpr(value);
            }
          }
          write(" >");
        } else {
          write("<>");
        }
        break;

      case Expr::Kind::Field:
        // Field selection binds tighter than binary operators, so wrap in parens if needed
        if (e->field.record->kind == Expr::Kind::Combine ||
            e->field.record->kind == Expr::Kind::CombineTypes ||
            e->field.record->kind == Expr::Kind::Prefer ||
            e->field.record->kind == Expr::Kind::App || e->field.record->kind == Expr::Kind::Lam ||
            e->field.record->kind == Expr::Kind::Pi ||
            e->field.record->kind == Expr::Kind::BoolIf) {
          write('(');
          writeExpr(e->field.record);
          write(')');
        } else {
          writeExpr(e->field.record);
        }
        write('.');
        write(interner_.get(e->field.name));
        break;

      case Expr::Kind::Prefer:
        writeExpr(e->binop.lhs);
        write(" ⫽ ");
        writeExpr(e->binop.rhs);
        break;

      case Expr::Kind::Annot:
        write('(');
        writeExpr(e->annot.expr);
        write(" : ");
        writeExpr(e->annot.type);
        write(')');
        break;

      case Expr::Kind::Import:
        if (e->import.abs_path) {
          write(std::string_view(e->import.abs_path, e->import.abs_path_len));
        } else {
          write("<import>");
        }
        break;

      case Expr::Kind::Project: {
        writeExpr(e->project.record);
        write(".{ ");
        // Sort field names alphabetically
        std::vector<std::string_view> sorted_names;
        sorted_names.reserve(e->project.count);
        for (std::size_t i = 0; i < e->project.count; ++i) {
          sorted_names.push_back(interner_.get(e->project.field_names[i]));
        }
        std::sort(sorted_names.begin(), sorted_names.end());
        for (std::size_t i = 0; i < sorted_names.size(); ++i) {
          if (i > 0) {
            write(", ");
          }
          write(sorted_names[i]);
        }
        write(" }");
        break;
      }

      case Expr::Kind::ProjectType:
        writeExpr(e->project_type.record);
        write(".(");
        writeExpr(e->project_type.type);
        write(")");
        break;

      case Expr::Kind::Combine:
        writeExpr(e->binop.lhs);
        write(" ∧ ");
        writeExpr(e->binop.rhs);
        break;

      case Expr::Kind::CombineTypes:
        writeExpr(e->binop.lhs);
        write(" ⩓ ");
        writeExpr(e->binop.rhs);
        break;

      case Expr::Kind::Assert:
        write("assert : ");
        writeExpr(e->assert_.type);
        break;

      case Expr::Kind::Equiv:
        writeExpr(e->equiv.lhs);
        write(" ≡ ");
        writeExpr(e->equiv.rhs);
        break;

      case Expr::Kind::With:
        writeExpr(e->with.record);
        write(" with ");
        for (std::size_t i = 0; i < e->with.path_len; ++i) {
          if (i > 0) {
            write(".");
          }
          write(interner_.get(e->with.path[i]));
        }
        write(" = ");
        writeExpr(e->with.value);
        break;

      case Expr::Kind::Merge:
        write("merge ");
        writeExpr(e->merge.handler);
        write(" ");
        writeExpr(e->merge.union_val);
        if (e->merge.type) {
          write(" : ");
          writeExpr(e->merge.type);
        }
        break;

      case Expr::Kind::ToMap:
        write("toMap ");
        writeExpr(e->tomap.record);
        if (e->tomap.type) {
          write(" : ");
          writeExpr(e->tomap.type);
        }
        break;
    }
  }

  // Helper to flatten nested single-field records into dotted path
  // Returns (dotted_path, innermost_value) where dotted_path is "a.b.c"
  std::pair<std::string, ExprPtr> flattenNestedRecord(std::string_view name, ExprPtr value) {
    std::string path(name);
    while (value->kind == Expr::Kind::RecordLit && value->fields && value->fields->size() == 1) {
      // Single-field nested record - flatten using dot notation
      const auto& entry = *value->fields->begin();
      path += '.';
      path += interner_.get(entry.name);
      value = entry.value;
    }
    return {path, value};
  }

  // Write a record literal in compact format (single line)
  void writeRecordLitExprCompact(Fields<ExprPtr>* fields) {
    if (!fields || fields->size() == 0) {
      write("{=}");
      return;
    }

    // Collect entries and sort alphabetically
    std::vector<std::pair<std::string_view, ExprPtr>> sorted;
    sorted.reserve(fields->size());
    for (const auto& entry : *fields) {
      sorted.emplace_back(interner_.get(entry.name), entry.value);
    }
    std::sort(sorted.begin(), sorted.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    // Compact format: { field1 = value1, field2 = value2 }
    write("{ ");
    bool first = true;
    for (const auto& [name, value] : sorted) {
      if (!first) {
        write(", ");
      }
      first = false;
      write(name);
      write(" = ");
      bool saved_compact = compact_;
      compact_ = true;
      writeExpr(value);
      compact_ = saved_compact;
    }
    write(" }");
  }

  // Estimate the length of a compact serialization for an expression
  // Returns a rough estimate; used to decide between single-line and multiline format
  std::size_t estimateCompactLength(ExprPtr e) {
    if (!e) {
      return 6; // "<null>"
    }

    switch (e->kind) {
      case Expr::Kind::Const:
        return 4; // "Type", "Kind", "Sort"
      case Expr::Kind::Builtin:
        return 15; // Rough average builtin name length
      case Expr::Kind::Var:
        return 5 + (e->var_idx > 0 ? 3 : 0); // Rough estimate for variable name
      case Expr::Kind::Lit:
        switch (e->lit.kind) {
          case Lit::Kind::Bool:
            return 5;
          case Lit::Kind::Nat:
            return 5;
          case Lit::Kind::Int:
            return 6;
          case Lit::Kind::Double:
            return 10;
          case Lit::Kind::Text:
            return e->lit.text.len + 2;
          case Lit::Kind::BigInt:
            return 15;
          case Lit::Kind::Bytes:
            return e->lit.bytes.len + 4;
        }
        return 10;
      case Expr::Kind::Lam:
      case Expr::Kind::Pi:
        return 100; // Lambdas and Pis are "complex"
      case Expr::Kind::App:
        return estimateCompactLength(e->app.func) + 1 + estimateCompactLength(e->app.arg);
      case Expr::Kind::List:
        if (e->list.count == 0) {
          return 2;
        }
        {
          std::size_t len = 4; // "[ " + " ]"
          for (std::size_t i = 0; i < e->list.count; ++i) {
            len += estimateCompactLength(e->list.elems[i]) + 2; // ", "
          }
          return len;
        }
      case Expr::Kind::RecordLit:
        if (!e->fields || e->fields->size() == 0) {
          return 3; // "{=}"
        }
        {
          std::size_t len = 4; // "{ " + " }"
          for (const auto& entry : *e->fields) {
            len += interner_.get(entry.name).size() + 3;   // " = "
            len += estimateCompactLength(entry.value) + 2; // ", "
          }
          return len;
        }
      default:
        return 50; // Default for complex expressions
    }
  }

  void writeRecordLitExpr(Fields<ExprPtr>* fields) {
    // In compact mode, use single-line format
    if (compact_) {
      writeRecordLitExprCompact(fields);
      return;
    }

    if (!fields || fields->size() == 0) {
      write("{=}");
      return;
    }

    // Collect entries and sort alphabetically (no flattening - use nested records)
    std::vector<std::pair<std::string_view, ExprPtr>> sorted;
    sorted.reserve(fields->size());
    for (const auto& entry : *fields) {
      sorted.emplace_back(interner_.get(entry.name), entry.value);
    }
    std::sort(sorted.begin(), sorted.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    // Estimate total compact length to decide format
    std::size_t total_len = 4; // "{ " + " }"
    for (const auto& [name, value] : sorted) {
      total_len += name.size() + 3;                  // "name = "
      total_len += estimateCompactLength(value) + 2; // ", "
    }

    // If fits on one line (< 80 chars), use compact format
    if (total_len < 80) {
      writeRecordLitExprCompact(fields);
      return;
    }

    // Multiline format - determine if values go on same line or next line
    // Values that are RecordLit stay on same line; others go to next line with indent
    bool first = true;
    for (const auto& [name, value] : sorted) {
      if (first) {
        write("{ ");
        first = false;
      } else {
        newline();
        write(", ");
      }
      write(name);
      write(" =");

      // Decide if value goes on same line or next line
      bool value_on_same_line = (value->kind == Expr::Kind::RecordLit);

      if (value_on_same_line) {
        write(' ');
        bool saved_compact = compact_;
        compact_ = true;
        writeExpr(value);
        compact_ = saved_compact;
      } else {
        // Value on next line with additional indent
        write('\n');
        indent_ += 2;
        for (int i = 0; i < indent_; ++i) {
          write("  ");
        }
        bool saved_compact = compact_;
        compact_ = true;
        writeExpr(value);
        compact_ = saved_compact;
        indent_ -= 2;
      }
    }
    newline();
    write('}');
  }
};

/// Convenience function to serialize a Value
inline std::string serialize(Interner& interner, ValuePtr v, bool compact = false) {
  return Serializer(interner, compact).serialize(v);
}

/// Convenience function to serialize an Expr
inline std::string serialize(Interner& interner, ExprPtr e, bool compact = false) {
  return Serializer(interner, compact).serialize(e);
}

} // namespace continuity::dhall
