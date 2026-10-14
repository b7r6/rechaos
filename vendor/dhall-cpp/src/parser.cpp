// Continuity.Codec.Dhall - Parser Implementation
// straylight.software · 2026

#include "straylight/dhall/parser.hpp"

#include <charconv>

namespace continuity::dhall {

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Strip backticks from a QuotedLabel token text
/// Input: "`foo/bar`"  Output: "foo/bar"
inline std::string_view strip_backticks(std::string_view text) {
  if (text.size() >= 2 && text.front() == '`' && text.back() == '`') {
    return text.substr(1, text.size() - 2);
  }
  return text;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN PARSE ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

std::expected<ExprPtr, ParseError> Parser::parse() {
  auto* expr = parse_expression();
  if (!expr) {
    return std::unexpected(error("failed to parse expression"));
  }

  if (!check(TokenKind::Eof)) {
    return std::unexpected(error("unexpected token after expression"));
  }

  return expr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPRESSION
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_expression() {
  // expression = annotated | lambda | forall | let | if | assert | merge

  switch (current_.kind) {
    case TokenKind::Backslash:
    case TokenKind::Forall:
      // Could be lambda or forall - check which
      if (current_.kind == TokenKind::Backslash) {
        return parse_lambda();
      }
      return parse_forall();

    case TokenKind::Let:
      return parse_let();

    case TokenKind::If:
      return parse_if();

    case TokenKind::Assert:
      return parse_assert();

    case TokenKind::Merge:
      return parse_merge();

    case TokenKind::ToMap:
      return parse_tomap();

    default:
      return parse_annotated();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANNOTATED
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_annotated() {
  auto* expr = parse_operator(0);
  if (!expr) {
    return nullptr;
  }

  // Check for type annotation: expr : type
  if (match(TokenKind::Colon)) {
    auto* type = parse_expression();
    if (!type) {
      return nullptr;
    }
    return mkAnnot(expr, type);
  }

  return expr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OPERATOR (PRECEDENCE CLIMBING)
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_operator(int min_prec) {
  auto* lhs = parse_with();
  if (!lhs) {
    return nullptr;
  }

  while (true) {
    int prec = get_precedence(current_.kind);
    if (prec < min_prec || prec == 0) {
      break;
    }

    TokenKind op = current_.kind;
    advance();

    // Right-associative: use same precedence; left-assoc: use prec+1
    int next_prec = is_right_assoc(op) ? prec : prec + 1;
    auto* rhs = parse_operator(next_prec);
    if (!rhs) {
      return nullptr;
    }

    // Create appropriate binary expression
    switch (op) {
      case TokenKind::Arrow: {
        // A -> B is shorthand for forall (_ : A) -> B
        // Shift indices in rhs by 1 to account for the new binding
        Name underscore = interner_.intern("_");
        lhs = mkPi(underscore, lhs, shift(rhs, 1, 0));
        break;
      }
      case TokenKind::And:
        lhs = mkBinop(Expr::Kind::BoolAnd, lhs, rhs);
        break;
      case TokenKind::Or:
        lhs = mkBinop(Expr::Kind::BoolOr, lhs, rhs);
        break;
      case TokenKind::Plus:
        lhs = mkBinop(Expr::Kind::NatPlus, lhs, rhs);
        break;
      case TokenKind::Times:
        lhs = mkBinop(Expr::Kind::NatTimes, lhs, rhs);
        break;
      case TokenKind::Prefer:
        lhs = mkBinop(Expr::Kind::Prefer, lhs, rhs);
        break;
      case TokenKind::TextAppend:
        lhs = mkBinop(Expr::Kind::TextAppend, lhs, rhs);
        break;
      case TokenKind::ListAppend:
        lhs = mkBinop(Expr::Kind::ListAppend, lhs, rhs);
        break;
      case TokenKind::Combine:
        lhs = mkBinop(Expr::Kind::Combine, lhs, rhs);
        break;
      case TokenKind::CombineTypes:
        lhs = mkBinop(Expr::Kind::CombineTypes, lhs, rhs);
        break;
      case TokenKind::Equivalent: {
        auto* e = alloc<Expr>();
        e->kind = Expr::Kind::Equiv;
        e->equiv = {lhs, rhs};
        lhs = e;
        break;
      }
      case TokenKind::Equal:
        lhs = mkBinop(Expr::Kind::Prefer, lhs, rhs); // TODO: figure out what = is for
        break;
      case TokenKind::DoubleEqual:
        lhs = mkBinop(Expr::Kind::BoolEq, lhs, rhs);
        break;
      case TokenKind::NotEqual:
        lhs = mkBinop(Expr::Kind::BoolNeq, lhs, rhs);
        break;
      case TokenKind::Alternative:
        // Import alternative - for now just return lhs
        lhs = rhs; // simplified: just take the rhs
        break;
      case TokenKind::DoubleColon: {
        // Completion operator: T::r desugars to (T.default // r) : T.Type
        // lhs = T (the schema), rhs = r (the record to complete)
        Name default_name = interner_.intern("default");
        Name type_name = interner_.intern("Type");

        // T.default
        auto* t_default = alloc<Expr>();
        t_default->kind = Expr::Kind::Field;
        t_default->field = {lhs, default_name};

        // T.default // r
        auto* merged = mkBinop(Expr::Kind::Prefer, t_default, rhs);

        // T.Type
        auto* t_type = alloc<Expr>();
        t_type->kind = Expr::Kind::Field;
        t_type->field = {lhs, type_name};

        // (T.default // r) : T.Type
        auto* e = alloc<Expr>();
        e->kind = Expr::Kind::Annot;
        e->annot = {merged, t_type};
        lhs = e;
        break;
      }
      default:
        // Unknown operator
        break;
    }
  }

  return lhs;
}

// ═══════════════════════════════════════════════════════════════════════════════
// APPLICATION
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_application() {
  auto* func = parse_import();
  if (!func) {
    return nullptr;
  }

  // Application is left-associative: f x y = (f x) y
  while (true) {
    // Check if next token can start an argument
    // (basically anything except operators, keywords, and string continuations)
    // Note: With is handled at parse_with level, so it stops application
    if (check(TokenKind::Eof) || check(TokenKind::RParen) || check(TokenKind::RBrace) ||
        check(TokenKind::RBracket) || check(TokenKind::RAngle) || check(TokenKind::Comma) ||
        check(TokenKind::Colon) || check(TokenKind::Equal) || check(TokenKind::In) ||
        check(TokenKind::Then) || check(TokenKind::Else) || check(TokenKind::With) ||
        get_precedence(current_.kind) > 0) {
      break;
    }

    // Special check for TextLit: a continuation token (from string interpolation)
    // is just the text after the interpolation, possibly with closing quote.
    // A new string argument must:
    //   - Start with " AND have either: length >= 2 (some content or closing quote), OR
    //   - Start with '' (multiline)
    // A continuation token doesn't start with an opening quote sequence.
    if (check(TokenKind::TextLit)) {
      std::string_view text = current_.text(src_);
      bool is_new_string = false;
      if (text.size() >= 2 && text[0] == '"') {
        // Double-quoted string: "..." - valid new string if at least 2 chars
        is_new_string = true;
      } else if (text.size() >= 4 && text[0] == '\'' && text[1] == '\'') {
        // Multiline string: ''...'' - valid new string if at least 4 chars
        is_new_string = true;
      }
      if (!is_new_string) {
        // This is a continuation token, not a new string - stop here
        break;
      }
    }

    auto* arg = parse_import();
    if (!arg) {
      break;
    }

    func = mkApp(func, arg);
  }

  return func;
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMPORT
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_import() {
  // Handle imports: ./path.dhall, ../path.dhall, env:VAR, https://...
  if (check(TokenKind::LocalPath)) {
    std::string_view path = current_.text(src_);
    advance();

    // Check for sha256 hash token
    std::string_view hash;
    if (check(TokenKind::Hash)) {
      std::string_view hash_tok = current_.text(src_);
      // Token includes "sha256:", skip it
      if (hash_tok.starts_with("sha256:") && hash_tok.size() == 71) {
        hash = hash_tok.substr(7);
      }
      advance();
    }

    return mkImport(path, hash, false);
  }

  if (check(TokenKind::HttpUrl)) {
    std::string_view path = current_.text(src_);
    advance();

    // Check for sha256 hash token
    std::string_view hash;
    if (check(TokenKind::Hash)) {
      std::string_view hash_tok = current_.text(src_);
      if (hash_tok.starts_with("sha256:") && hash_tok.size() == 71) {
        hash = hash_tok.substr(7);
      }
      advance();
    }

    return mkImport(path, hash, true);
  }

  if (check(TokenKind::EnvVar)) {
    std::string_view path = current_.text(src_);
    advance();
    return mkImport(path, {}, false);
  }

  return parse_selector();
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTOR (FIELD ACCESS / WITH)
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// WITH EXPRESSION (record update chains)
// Per Dhall spec: with-expression = import-expression *(whsp "with" whsp1 with-clause)
// This is a separate precedence level above application
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_with() {
  auto* expr = parse_application();
  if (!expr) {
    return nullptr;
  }

  while (match(TokenKind::With)) {
    // with-clause: label ("." label | "." "?")* "=" application-expression
    // The ? token is used for Optional descent
    if (!check(TokenKind::Label) && !check(TokenKind::QuotedLabel) &&
        !check(TokenKind::Alternative)) {
      return nullptr;
    }

    // Parse field path (can be nested like "a.b.c" or "a.?.b")
    std::vector<Name> path;
    while (check(TokenKind::Label) || check(TokenKind::QuotedLabel) ||
           check(TokenKind::Alternative)) {
      if (check(TokenKind::Alternative)) {
        // ? for Optional descent
        path.push_back(interner_.intern("?"));
        advance();
      } else {
        std::string_view field = current_.text(src_);
        // Strip backticks from QuotedLabel tokens
        if (check(TokenKind::QuotedLabel)) {
          field = strip_backticks(field);
        }
        path.push_back(interner_.intern(field));
        advance();
      }
      if (!match(TokenKind::Dot)) {
        break;
      }
    }

    if (!match(TokenKind::Equal)) {
      return nullptr;
    }

    // Per Dhall spec, with-clause value is application-expression
    auto* value = parse_application();
    if (!value) {
      return nullptr;
    }

    // Create proper With expression
    auto path_span = arena_.alloc_array<Name>(path.size());
    std::copy(path.begin(), path.end(), path_span.data());

    auto* e = alloc<Expr>();
    e->kind = Expr::Kind::With;
    e->with = {expr, path_span.data(), path.size(), value};
    expr = e;
  }

  return expr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELECTOR (FIELD ACCESS ONLY - no with)
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_selector() {
  auto* expr = parse_primitive();
  if (!expr) {
    return nullptr;
  }

  while (match(TokenKind::Dot)) {
    // Check for record projection: expr.{ field1, field2 }
    if (match(TokenKind::LBrace)) {
      std::vector<Name> field_names;
      if (!check(TokenKind::RBrace)) {
        do {
          if (!check(TokenKind::Label) && !check(TokenKind::QuotedLabel)) {
            return nullptr;
          }
          std::string_view field = current_.text(src_);
          // Strip backticks from QuotedLabel tokens
          if (check(TokenKind::QuotedLabel)) {
            field = strip_backticks(field);
          }
          field_names.push_back(interner_.intern(field));
          advance();
        } while (match(TokenKind::Comma));
      }
      if (!match(TokenKind::RBrace)) {
        return nullptr;
      }
      // Create Project expression
      auto span = arena_.alloc_array<Name>(field_names.size());
      std::copy(field_names.begin(), field_names.end(), span.data());
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::Project;
      e->project = {expr, span.data(), field_names.size()};
      expr = e;
      continue;
    }

    // Check for record projection by type: expr.(Type)
    if (match(TokenKind::LParen)) {
      auto* type = parse_expression();
      if (!type || !match(TokenKind::RParen)) {
        return nullptr;
      }
      auto* e = alloc<Expr>();
      e->kind = Expr::Kind::ProjectType;
      e->project_type = {expr, type};
      expr = e;
      continue;
    }

    // Field access: expr.field
    // Field names can be Labels, QuotedLabels, or Builtins (like Text, List, etc.)
    // rechaos: and the keyword constants Type, Kind, Sort, which the standard
    // allows as field labels (the `Package.Type` idiom every module here uses).
    if (!check(TokenKind::Label) && !check(TokenKind::QuotedLabel) && !check(TokenKind::Builtin) &&
        !check(TokenKind::Type) && !check(TokenKind::Kind) && !check(TokenKind::Sort)) {
      return nullptr; // expected field name
    }
    std::string_view field = current_.text(src_);
    // Strip backticks from QuotedLabel tokens
    if (check(TokenKind::QuotedLabel)) {
      field = strip_backticks(field);
    }
    Name name = interner_.intern(field);
    advance();
    expr = mkField(expr, name);
  }

  return expr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIMITIVE
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_primitive() {
  switch (current_.kind) {
    case TokenKind::LParen: {
      advance();
      auto* expr = parse_expression();
      if (!expr) {
        return nullptr;
      }
      if (!match(TokenKind::RParen)) {
        return nullptr; // expected )
      }
      return expr;
    }

    case TokenKind::LBrace:
      return parse_record();

    case TokenKind::LBracket:
      return parse_list();

    case TokenKind::LAngle:
      return parse_union();

    case TokenKind::NaturalLit: {
      std::uint64_t val = current_.natural_val;
      advance();
      return mkLit(Lit::Nat(val));
    }

    case TokenKind::IntegerLit: {
      std::int64_t val = current_.integer_val;
      advance();
      return mkLit(Lit::Int(val));
    }

    case TokenKind::BigIntLit: {
      double val = current_.big_int.value;
      bool negative = current_.big_int.negative;
      advance();
      return mkLit(Lit::BigInt(val, negative));
    }

    case TokenKind::DoubleLit: {
      double val = current_.double_val;
      advance();
      return mkLit(Lit::Double(val));
    }

    case TokenKind::TextLit:
      return parse_text();

    case TokenKind::BytesLit: {
      // 0x"HEXHEX..." - the token includes the 0x" and closing "
      // We need to extract just the hex content
      auto text = current_.text(src_);
      // Skip 0x" prefix (3 chars) and " suffix (1 char)
      const char* hex_start = text.data() + 3;
      std::size_t hex_len = text.size() - 4; // minus 0x" and "
      advance();
      return mkLit(Lit::Bytes(hex_start, hex_len));
    }

    case TokenKind::Builtin: {
      BuiltinName bn = static_cast<BuiltinName>(current_.natural_val);
      advance();

      // Convert lexer's BuiltinName to evaluator's Builtin
      switch (bn) {
        case BuiltinName::Bool:
          return mkBuiltin(Builtin::Bool);
        case BuiltinName::True:
          return mkLit(Lit::Bool(true));
        case BuiltinName::False:
          return mkLit(Lit::Bool(false));
        case BuiltinName::Natural:
          return mkBuiltin(Builtin::Natural);
        case BuiltinName::Natural_fold:
          return mkBuiltin(Builtin::NaturalFold);
        case BuiltinName::Natural_build:
          return mkBuiltin(Builtin::NaturalBuild);
        case BuiltinName::Natural_isZero:
          return mkBuiltin(Builtin::NaturalIsZero);
        case BuiltinName::Natural_even:
          return mkBuiltin(Builtin::NaturalEven);
        case BuiltinName::Natural_odd:
          return mkBuiltin(Builtin::NaturalOdd);
        case BuiltinName::Natural_toInteger:
          return mkBuiltin(Builtin::NaturalToInteger);
        case BuiltinName::Natural_show:
          return mkBuiltin(Builtin::NaturalShow);
        case BuiltinName::Natural_subtract:
          return mkBuiltin(Builtin::NaturalSubtract);
        case BuiltinName::Integer:
          return mkBuiltin(Builtin::Integer);
        case BuiltinName::Integer_clamp:
          return mkBuiltin(Builtin::IntegerClamp);
        case BuiltinName::Integer_negate:
          return mkBuiltin(Builtin::IntegerNegate);
        case BuiltinName::Integer_show:
          return mkBuiltin(Builtin::IntegerShow);
        case BuiltinName::Integer_toDouble:
          return mkBuiltin(Builtin::IntegerToDouble);
        case BuiltinName::Double:
          return mkBuiltin(Builtin::Double);
        case BuiltinName::Double_show:
          return mkBuiltin(Builtin::DoubleShow);
        case BuiltinName::Text:
          return mkBuiltin(Builtin::Text);
        case BuiltinName::Text_show:
          return mkBuiltin(Builtin::TextShow);
        case BuiltinName::Text_replace:
          return mkBuiltin(Builtin::TextReplace);
        case BuiltinName::List:
          return mkBuiltin(Builtin::List);
        case BuiltinName::List_build:
          return mkBuiltin(Builtin::ListBuild);
        case BuiltinName::List_fold:
          return mkBuiltin(Builtin::ListFold);
        case BuiltinName::List_length:
          return mkBuiltin(Builtin::ListLength);
        case BuiltinName::List_head:
          return mkBuiltin(Builtin::ListHead);
        case BuiltinName::List_last:
          return mkBuiltin(Builtin::ListLast);
        case BuiltinName::List_indexed:
          return mkBuiltin(Builtin::ListIndexed);
        case BuiltinName::List_reverse:
          return mkBuiltin(Builtin::ListReverse);
        case BuiltinName::Optional:
          return mkBuiltin(Builtin::Optional);
        case BuiltinName::None:
          return mkBuiltin(Builtin::None);
        case BuiltinName::Some:
          return mkBuiltin(Builtin::Some);
        case BuiltinName::ShowConstructor:
          return mkBuiltin(Builtin::ShowConstructor);
        case BuiltinName::Bytes:
          return mkBuiltin(Builtin::Bytes);
        default:
          return nullptr;
      }
    }

    case TokenKind::Type:
      advance();
      return mkConst(Const::Type);

    case TokenKind::Kind:
      advance();
      return mkConst(Const::Kind);

    case TokenKind::Sort:
      advance();
      return mkConst(Const::Sort);

    case TokenKind::Label:
    case TokenKind::QuotedLabel: {
      std::string_view text = current_.text(src_);
      // Strip backticks from QuotedLabel tokens
      if (check(TokenKind::QuotedLabel)) {
        text = strip_backticks(text);
      }
      Name name = interner_.intern(text);
      advance();

      // Check for explicit @n de Bruijn index (for shadowed variables)
      std::uint32_t explicit_idx = 0;
      bool has_explicit_idx = false;
      if (match(TokenKind::At)) {
        if (check(TokenKind::NaturalLit)) {
          explicit_idx = static_cast<std::uint32_t>(current_.natural_val);
          has_explicit_idx = true;
          advance();
        }
      }

      // Resolve the variable using scope tracking
      if (auto resolved = resolve_var(name)) {
        // If explicit @n was given, add it to handle shadowed variables
        // (the explicit index counts how many shadowing bindings to skip)
        std::uint32_t final_idx = *resolved;
        if (has_explicit_idx) {
          // Count occurrences of `name` in scope and adjust
          // For simplicity, just add the explicit index for now
          // (full Dhall semantics: @n skips n bindings of same name)
          final_idx = *resolved + explicit_idx;
        }
        return mkVar(final_idx);
      } else {
        // Free variable - leave as index 0 (will become stuck value)
        return mkVar(explicit_idx);
      }
    }

    // Handle expression-level keywords that can appear inside application context
    // (e.g., in `with x = toMap { ... }` the toMap must be parsed at primitive level)
    case TokenKind::ToMap:
      return parse_tomap();

    case TokenKind::Merge:
      return parse_merge();

    default:
      return nullptr;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LAMBDA
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_lambda() {
  // \ (x : T) -> body
  // λ (x : T) -> body
  advance(); // consume \ or λ

  if (!match(TokenKind::LParen)) {
    return nullptr; // expected (
  }

  if (!check(TokenKind::Label)) {
    return nullptr; // expected parameter name
  }
  std::string_view param_text = current_.text(src_);
  Name param = interner_.intern(param_text);
  advance();

  if (!match(TokenKind::Colon)) {
    return nullptr; // expected :
  }

  // Parse type - parameter is NOT in scope yet
  auto* type = parse_expression();
  if (!type) {
    return nullptr;
  }

  if (!match(TokenKind::RParen)) {
    return nullptr; // expected )
  }

  if (!match(TokenKind::Arrow)) {
    return nullptr; // expected ->
  }

  // Push parameter onto scope for body parsing
  scope_.push_back(param);
  auto* body = parse_expression();
  scope_.pop_back();

  if (!body) {
    return nullptr;
  }

  return mkLam(param, type, body);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORALL (PI TYPE)
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_forall() {
  // forall (x : T) -> U
  // ∀ (x : T) -> U
  advance(); // consume forall or ∀

  if (!match(TokenKind::LParen)) {
    return nullptr;
  }

  if (!check(TokenKind::Label)) {
    return nullptr;
  }
  std::string_view param_text = current_.text(src_);
  Name param = interner_.intern(param_text);
  advance();

  if (!match(TokenKind::Colon)) {
    return nullptr;
  }

  // Parse domain - parameter is NOT in scope yet
  auto* domain = parse_expression();
  if (!domain) {
    return nullptr;
  }

  if (!match(TokenKind::RParen)) {
    return nullptr;
  }

  if (!match(TokenKind::Arrow)) {
    return nullptr;
  }

  // Push parameter onto scope for codomain parsing
  scope_.push_back(param);
  auto* codomain = parse_expression();
  scope_.pop_back();

  if (!codomain) {
    return nullptr;
  }

  return mkPi(param, domain, codomain);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LET
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_let() {
  // let x : T = e in body
  // let x = e in body
  advance(); // consume 'let'

  if (!check(TokenKind::Label)) {
    return nullptr;
  }
  std::string_view name_text = current_.text(src_);
  Name name = interner_.intern(name_text);
  advance();

  ExprPtr type = nullptr;
  if (match(TokenKind::Colon)) {
    type = parse_expression();
    if (!type) {
      return nullptr;
    }
  }

  if (!match(TokenKind::Equal)) {
    return nullptr;
  }

  // Parse value expression - variable is NOT in scope yet
  auto* value = parse_expression();
  if (!value) {
    return nullptr;
  }

  // Push variable onto scope for body parsing
  scope_.push_back(name);

  // Check for chained lets or 'in'
  ExprPtr body;
  if (check(TokenKind::Let)) {
    // Chained let without 'in'
    body = parse_let();
  } else {
    if (!match(TokenKind::In)) {
      scope_.pop_back();
      return nullptr;
    }
    body = parse_expression();
  }

  // Pop variable from scope
  scope_.pop_back();

  if (!body) {
    return nullptr;
  }

  return mkLet(name, type, value, body);
}

// ═══════════════════════════════════════════════════════════════════════════════
// IF
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_if() {
  // if cond then t else f
  advance(); // consume 'if'

  auto* cond = parse_expression();
  if (!cond) {
    return nullptr;
  }

  if (!match(TokenKind::Then)) {
    return nullptr;
  }

  auto* then_ = parse_expression();
  if (!then_) {
    return nullptr;
  }

  if (!match(TokenKind::Else)) {
    return nullptr;
  }

  auto* else_ = parse_expression();
  if (!else_) {
    return nullptr;
  }

  return mkIf(cond, then_, else_);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ASSERT
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_assert() {
  // assert : T (where T should be an equivalence like A ≡ B)
  advance(); // consume 'assert'

  if (!match(TokenKind::Colon)) {
    return nullptr;
  }

  auto* type = parse_expression();
  if (!type) {
    return nullptr;
  }

  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Assert;
  e->assert_ = {type};
  return e;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MERGE
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_merge() {
  // merge handler union : T
  advance(); // consume 'merge'

  auto* handler = parse_import();
  if (!handler) {
    return nullptr;
  }

  auto* union_val = parse_import();
  if (!union_val) {
    return nullptr;
  }

  ExprPtr type = nullptr;
  if (match(TokenKind::Colon)) {
    type = parse_expression();
  }

  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::Merge;
  e->merge = {handler, union_val, type};
  return e;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOMAP
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_tomap() {
  // toMap record : List { mapKey : Text, mapValue : T }
  advance(); // consume 'toMap'

  auto* record = parse_import();
  if (!record) {
    return nullptr;
  }

  ExprPtr type = nullptr;
  if (match(TokenKind::Colon)) {
    type = parse_expression();
  }

  auto* e = alloc<Expr>();
  e->kind = Expr::Kind::ToMap;
  e->tomap = {record, type};
  return e;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECORD
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_record() {
  // { field = value, ... } or { field : type, ... } (record type)
  advance(); // consume '{'

  auto* fields = alloc<Fields<ExprPtr>>();

  // Empty record type: {} or empty record literal: {=}
  if (match(TokenKind::RBrace)) {
    // {} is an empty record TYPE
    return mkRecord(fields);
  }
  if (match(TokenKind::Equal)) {
    // {=} is explicit empty record LITERAL
    if (!match(TokenKind::RBrace)) {
      return nullptr;
    }
    return mkRecordLit(fields);
  }

  // Detect if this is a record literal or record type
  bool is_type = false;

  while (true) {
    // Field names can be Labels, QuotedLabels, Builtins (like None, Some, True, False),
    // or keywords like Type, Kind, Sort when used in field position
    if (!check(TokenKind::Label) && !check(TokenKind::QuotedLabel) && !check(TokenKind::Builtin) &&
        !check(TokenKind::Type) && !check(TokenKind::Kind) && !check(TokenKind::Sort)) {
      return nullptr;
    }

    std::string_view field_text = current_.text(src_);
    // Strip backticks from QuotedLabel tokens
    if (check(TokenKind::QuotedLabel)) {
      field_text = strip_backticks(field_text);
    }
    Name field_name = interner_.intern(field_text);
    advance();

    // Check for dotted field syntax: a.b.c = value -> { a = { b = { c = value } } }
    std::vector<Name> dotted_path;
    dotted_path.push_back(field_name);
    while (match(TokenKind::Dot)) {
      if (!check(TokenKind::Label) && !check(TokenKind::QuotedLabel)) {
        return nullptr;
      }
      std::string_view next_field = current_.text(src_);
      // Strip backticks from QuotedLabel tokens
      if (check(TokenKind::QuotedLabel)) {
        next_field = strip_backticks(next_field);
      }
      dotted_path.push_back(interner_.intern(next_field));
      advance();
    }

    if (check(TokenKind::Equal)) {
      // Record literal: field = value (or a.b.c = value)
      advance();
      auto* value = parse_expression();
      if (!value) {
        return nullptr;
      }

      // Build nested records from inside out for dotted fields
      for (std::size_t idx = dotted_path.size() - 1; idx > 0; --idx) {
        auto* inner_fields = alloc<Fields<ExprPtr>>();
        inner_fields->insert(dotted_path[idx], value);
        value = mkRecordLit(inner_fields);
      }
      // Check for duplicate field - if exists, combine with ∧
      if (auto* existing = fields->lookup(dotted_path[0])) {
        value = mkBinop(Expr::Kind::Combine, *existing, value);
      }
      fields->insert(dotted_path[0], value);
    } else if (check(TokenKind::Colon)) {
      // Record type: field : type (or a.b.c : type)
      is_type = true;
      advance();
      auto* type = parse_expression();
      if (!type) {
        return nullptr;
      }

      // Build nested record types from inside out for dotted fields
      for (std::size_t idx = dotted_path.size() - 1; idx > 0; --idx) {
        auto* inner_fields = alloc<Fields<ExprPtr>>();
        inner_fields->insert(dotted_path[idx], type);
        type = mkRecord(inner_fields);
      }
      fields->insert(dotted_path[0], type);
    } else if (check(TokenKind::Comma) || check(TokenKind::RBrace)) {
      // Punning: { field } means { field = field }
      // Only valid for single field names, not dotted paths
      if (dotted_path.size() > 1) {
        return nullptr;
      }
      // Create a variable reference with the field name, using proper scope tracking
      std::uint32_t var_idx = 0;
      if (auto resolved = resolve_var(field_name)) {
        var_idx = *resolved;
      }
      auto* value = mkVar(var_idx);
      // Check for duplicate field - if exists, combine with ∧
      if (auto* existing = fields->lookup(field_name)) {
        value = mkBinop(Expr::Kind::Combine, *existing, value);
      }
      fields->insert(field_name, value);
    } else {
      return nullptr;
    }

    if (match(TokenKind::RBrace)) {
      break;
    }

    if (!match(TokenKind::Comma)) {
      return nullptr;
    }
  }

  return is_type ? mkRecord(fields) : mkRecordLit(fields);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNION
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_union() {
  // < Constructor : Type | ... >
  advance(); // consume '<'

  auto* fields = alloc<Fields<ExprPtr>>();

  // Empty union
  if (match(TokenKind::RAngle)) {
    return mkUnion(fields);
  }

  while (true) {
    if (!check(TokenKind::Label)) {
      return nullptr;
    }

    std::string_view ctor_text = current_.text(src_);
    Name ctor_name = interner_.intern(ctor_text);
    advance();

    ExprPtr type = nullptr;
    if (match(TokenKind::Colon)) {
      type = parse_expression();
      if (!type) {
        return nullptr;
      }
    } else {
      // Nullary constructor - type is unit
      type = mkRecordLit(alloc<Fields<ExprPtr>>());
    }

    fields->insert(ctor_name, type);

    if (match(TokenKind::RAngle)) {
      break;
    }

    if (!match(TokenKind::Pipe)) {
      return nullptr;
    }
  }

  return mkUnion(fields);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIST
// ═══════════════════════════════════════════════════════════════════════════════

ExprPtr Parser::parse_list() {
  // [ elem, ... ] or [] : List T
  advance(); // consume '['

  std::vector<ExprPtr> elems;

  // Empty list
  if (match(TokenKind::RBracket)) {
    ExprPtr type = nullptr;
    if (match(TokenKind::Colon)) {
      type = parse_expression();
    }
    return mkList(type, elems);
  }

  while (true) {
    auto* elem = parse_expression();
    if (!elem) {
      return nullptr;
    }
    elems.push_back(elem);

    if (match(TokenKind::RBracket)) {
      break;
    }

    if (!match(TokenKind::Comma)) {
      return nullptr;
    }
  }

  return mkList(nullptr, elems);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXT
// ═══════════════════════════════════════════════════════════════════════════════

// Unescape a double-quoted string: \n -> newline, \\ -> backslash, etc.
// Returns the unescaped string and its length
static std::pair<char*, std::size_t> unescape_text(Arena& arena, std::string_view text) {
  // Allocate buffer (unescaped will be <= original length)
  char* data = reinterpret_cast<char*>(arena.alloc_array<char>(text.size() + 1).data());
  std::size_t out_len = 0;

  for (std::size_t i = 0; i < text.size(); ++i) {
    if (text[i] == '\\' && i + 1 < text.size()) {
      char next = text[i + 1];
      switch (next) {
        case 'n':
          data[out_len++] = '\n';
          ++i;
          break;
        case 't':
          data[out_len++] = '\t';
          ++i;
          break;
        case 'r':
          data[out_len++] = '\r';
          ++i;
          break;
        case '"':
          data[out_len++] = '"';
          ++i;
          break;
        case '\\':
          data[out_len++] = '\\';
          ++i;
          break;
        case '/':
          data[out_len++] = '/';
          ++i;
          break;
        case '$':
          data[out_len++] = '$';
          ++i;
          break;
        case 'b':
          data[out_len++] = '\b';
          ++i;
          break;
        case 'f':
          data[out_len++] = '\f';
          ++i;
          break;
        case 'u':
          // Unicode escape: \u{XXXX} (Dhall uses braced form with variable hex digits)
          if (i + 3 < text.size() && text[i + 2] == '{') {
            // Find closing brace
            std::size_t brace_end = text.find('}', i + 3);
            if (brace_end != std::string_view::npos) {
              // Parse hex digits between braces
              std::uint32_t codepoint = 0;
              bool valid = true;
              for (std::size_t j = i + 3; j < brace_end && valid; ++j) {
                char h = text[j];
                if (h >= '0' && h <= '9') {
                  codepoint = (codepoint << 4) | (h - '0');
                } else if (h >= 'a' && h <= 'f') {
                  codepoint = (codepoint << 4) | (h - 'a' + 10);
                } else if (h >= 'A' && h <= 'F') {
                  codepoint = (codepoint << 4) | (h - 'A' + 10);
                } else {
                  valid = false;
                }
              }
              if (valid && codepoint <= 0x10FFFF) {
                // Encode as UTF-8
                if (codepoint < 0x80) {
                  data[out_len++] = static_cast<char>(codepoint);
                } else if (codepoint < 0x800) {
                  data[out_len++] = static_cast<char>(0xC0 | (codepoint >> 6));
                  data[out_len++] = static_cast<char>(0x80 | (codepoint & 0x3F));
                } else if (codepoint < 0x10000) {
                  data[out_len++] = static_cast<char>(0xE0 | (codepoint >> 12));
                  data[out_len++] = static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
                  data[out_len++] = static_cast<char>(0x80 | (codepoint & 0x3F));
                } else {
                  // 4-byte UTF-8 (codepoints >= 0x10000)
                  data[out_len++] = static_cast<char>(0xF0 | (codepoint >> 18));
                  data[out_len++] = static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F));
                  data[out_len++] = static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
                  data[out_len++] = static_cast<char>(0x80 | (codepoint & 0x3F));
                }
                i = brace_end; // skip past \u{...}
                break;
              }
            }
          }
          // Also support \uXXXX (4 hex digits, JSON-style) for compatibility
          if (i + 5 < text.size()) {
            std::uint32_t codepoint = 0;
            bool valid = true;
            for (int j = 0; j < 4 && valid; ++j) {
              char h = text[i + 2 + j];
              if (h >= '0' && h <= '9') {
                codepoint = (codepoint << 4) | (h - '0');
              } else if (h >= 'a' && h <= 'f') {
                codepoint = (codepoint << 4) | (h - 'a' + 10);
              } else if (h >= 'A' && h <= 'F') {
                codepoint = (codepoint << 4) | (h - 'A' + 10);
              } else {
                valid = false;
              }
            }
            if (valid) {
              // Encode as UTF-8
              if (codepoint < 0x80) {
                data[out_len++] = static_cast<char>(codepoint);
              } else if (codepoint < 0x800) {
                data[out_len++] = static_cast<char>(0xC0 | (codepoint >> 6));
                data[out_len++] = static_cast<char>(0x80 | (codepoint & 0x3F));
              } else {
                data[out_len++] = static_cast<char>(0xE0 | (codepoint >> 12));
                data[out_len++] = static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
                data[out_len++] = static_cast<char>(0x80 | (codepoint & 0x3F));
              }
              i += 5; // skip \uXXXX
              break;
            }
          }
          // Invalid unicode escape, keep as-is
          data[out_len++] = text[i];
          break;
        default:
          // Unknown escape, keep backslash and char
          data[out_len++] = text[i];
          break;
      }
    } else {
      data[out_len++] = text[i];
    }
  }

  data[out_len] = '\0';
  return {data, out_len};
}

ExprPtr Parser::parse_text() {
  // "text" or ''multiline text'' or "foo${expr}bar"
  std::string_view text = current_.text(src_);
  advance();

  // Detect quote type and strip opening/closing quotes
  char quote_type = '"';
  bool has_opening = false;
  bool has_closing = false;

  if (text.size() >= 1 && text.front() == '"') {
    has_opening = true;
    text = text.substr(1);
  } else if (text.size() >= 2 && text.substr(0, 2) == "''") {
    quote_type = '\'';
    has_opening = true;
    text = text.substr(2);
  }

  if (text.size() >= 1 && text.back() == '"' && quote_type == '"') {
    has_closing = true;
    text = text.substr(0, text.size() - 1);
  } else if (text.size() >= 2 && text.substr(text.size() - 2) == "''" && quote_type == '\'') {
    has_closing = true;
    text = text.substr(0, text.size() - 2);
  }

  // Create the text literal for this chunk (with escape processing for double-quoted strings)
  ExprPtr result;
  if (quote_type == '"') {
    auto [data, len] = unescape_text(arena_, text);
    result = mkLit(Lit::Text(data, len));
  } else {
    // Multiline strings don't use backslash escapes (use '' escaping instead)
    char* data = reinterpret_cast<char*>(arena_.alloc_array<char>(text.size() + 1).data());
    std::copy(text.begin(), text.end(), data);
    data[text.size()] = '\0';
    result = mkLit(Lit::Text(data, text.size()));
  }

  // If no closing quote, there's an interpolation following
  // Pattern: "prefix${expr}suffix" becomes prefix ++ expr ++ suffix
  // The interpolated expression can be any Dhall expression
  while (!has_closing) {
    // Parse the interpolated expression (can be if-then-else, application, etc.)
    auto* interp_expr = parse_expression();
    if (!interp_expr) {
      return nullptr;
    }

    // Concatenate: result ++ interp_expr
    result = mkBinop(Expr::Kind::TextAppend, result, interp_expr);

    // Now we should have the continuation text
    if (!check(TokenKind::TextLit)) {
      return nullptr; // expected continuation
    }

    std::string_view cont_text = current_.text(src_);
    advance();

    // Continuation text from lexer: NO opening quote, but has closing quote if string ends
    // The continuation only has closing quote, never opening
    has_closing = false;
    if (quote_type == '"') {
      // For double-quoted: continuation might be just `"` (closing) or `text"` (text + closing)
      if (cont_text.size() >= 1 && cont_text.back() == '"') {
        has_closing = true;
        cont_text = cont_text.substr(0, cont_text.size() - 1);
      }
    } else {
      // For multiline: continuation ends with ''
      if (cont_text.size() >= 2 && cont_text.substr(cont_text.size() - 2) == "''") {
        has_closing = true;
        cont_text = cont_text.substr(0, cont_text.size() - 2);
      }
    }

    // Only add to result if there's actual text content
    if (cont_text.size() > 0) {
      ExprPtr cont_lit;
      if (quote_type == '"') {
        auto [cont_data, cont_len] = unescape_text(arena_, cont_text);
        cont_lit = mkLit(Lit::Text(cont_data, cont_len));
      } else {
        char* cont_data =
            reinterpret_cast<char*>(arena_.alloc_array<char>(cont_text.size() + 1).data());
        std::copy(cont_text.begin(), cont_text.end(), cont_data);
        cont_data[cont_text.size()] = '\0';
        cont_lit = mkLit(Lit::Text(cont_data, cont_text.size()));
      }
      result = mkBinop(Expr::Kind::TextAppend, result, cont_lit);
    }
  }

  return result;
}

} // namespace continuity::dhall
