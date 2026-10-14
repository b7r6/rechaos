// Continuity.Codec.Dhall - Lexer Implementation
// straylight.software · 2026

#include "straylight/dhall/lexer.hpp"

#include <cctype>
#include <cmath>
#include <cstdlib>
#include <charconv>
#include <cstring>
#include <limits>
#include <string>

namespace continuity::dhall {

static bool is_path_char(char c);


// ═══════════════════════════════════════════════════════════════════════════════
// BUILTIN LOOKUP
// ═══════════════════════════════════════════════════════════════════════════════

BuiltinName lookup_builtin(std::string_view name) {
  // Sorted for binary search potential, but linear is fine for ~30 entries
  if (name == "Bool") {
    return BuiltinName::Bool;
  }
  if (name == "Double") {
    return BuiltinName::Double;
  }
  if (name == "Double/show") {
    return BuiltinName::Double_show;
  }
  if (name == "False") {
    return BuiltinName::False;
  }
  if (name == "Integer") {
    return BuiltinName::Integer;
  }
  if (name == "Integer/clamp") {
    return BuiltinName::Integer_clamp;
  }
  if (name == "Integer/negate") {
    return BuiltinName::Integer_negate;
  }
  if (name == "Integer/show") {
    return BuiltinName::Integer_show;
  }
  if (name == "Integer/toDouble") {
    return BuiltinName::Integer_toDouble;
  }
  if (name == "List") {
    return BuiltinName::List;
  }
  if (name == "List/build") {
    return BuiltinName::List_build;
  }
  if (name == "List/fold") {
    return BuiltinName::List_fold;
  }
  if (name == "List/head") {
    return BuiltinName::List_head;
  }
  if (name == "List/indexed") {
    return BuiltinName::List_indexed;
  }
  if (name == "List/last") {
    return BuiltinName::List_last;
  }
  if (name == "List/length") {
    return BuiltinName::List_length;
  }
  if (name == "List/reverse") {
    return BuiltinName::List_reverse;
  }
  if (name == "Natural") {
    return BuiltinName::Natural;
  }
  if (name == "Natural/build") {
    return BuiltinName::Natural_build;
  }
  if (name == "Natural/even") {
    return BuiltinName::Natural_even;
  }
  if (name == "Natural/fold") {
    return BuiltinName::Natural_fold;
  }
  if (name == "Natural/isZero") {
    return BuiltinName::Natural_isZero;
  }
  if (name == "Natural/odd") {
    return BuiltinName::Natural_odd;
  }
  if (name == "Natural/show") {
    return BuiltinName::Natural_show;
  }
  if (name == "Natural/subtract") {
    return BuiltinName::Natural_subtract;
  }
  if (name == "Natural/toInteger") {
    return BuiltinName::Natural_toInteger;
  }
  if (name == "None") {
    return BuiltinName::None;
  }
  if (name == "Optional") {
    return BuiltinName::Optional;
  }
  if (name == "Some") {
    return BuiltinName::Some;
  }
  if (name == "Text") {
    return BuiltinName::Text;
  }
  if (name == "Text/replace") {
    return BuiltinName::Text_replace;
  }
  if (name == "Text/show") {
    return BuiltinName::Text_show;
  }
  if (name == "True") {
    return BuiltinName::True;
  }
  if (name == "showConstructor") {
    return BuiltinName::ShowConstructor;
  }
  if (name == "Bytes") {
    return BuiltinName::Bytes;
  }
  return BuiltinName::Unknown;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WHITESPACE AND COMMENTS
// ═══════════════════════════════════════════════════════════════════════════════

void Lexer::skip_whitespace_and_comments() {
  while (!at_end()) {
    char c = current();
    if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
      advance();
    } else if (c == '-' && peek_char() == '-') {
      skip_line_comment();
    } else if (c == '{' && peek_char() == '-') {
      skip_block_comment();
    } else {
      break;
    }
  }
}

void Lexer::skip_line_comment() {
  // Skip --
  advance(2);
  // Consume until newline
  while (!at_end() && current() != '\n') {
    advance();
  }
}

void Lexer::skip_block_comment() {
  // Skip {-
  advance(2);
  int depth = 1;
  while (!at_end() && depth > 0) {
    if (current() == '{' && peek_char() == '-') {
      advance(2);
      depth++;
    } else if (current() == '-' && peek_char() == '}') {
      advance(2);
      depth--;
    } else {
      advance();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN LEXER
// ═══════════════════════════════════════════════════════════════════════════════

Token Lexer::next() {
  skip_whitespace_and_comments();

  if (at_end()) {
    return make_token(TokenKind::Eof, offset(), 0);
  }

  std::uint32_t start = offset();
  char c = current();

  // Single-character tokens
  switch (c) {
    case '(':
      advance();
      return make_token(TokenKind::LParen, start, 1);
    case ')':
      advance();
      return make_token(TokenKind::RParen, start, 1);
    case '{':
      advance();
      // Track nested braces within interpolation
      if (!interpol_stack_.empty()) {
        interpol_stack_.back().brace_depth++;
      }
      return make_token(TokenKind::LBrace, start, 1);
    case '}':
      advance();
      // Check if this closes an interpolation
      if (!interpol_stack_.empty()) {
        if (interpol_stack_.back().brace_depth == 0) {
          // This } closes the interpolation - continue lexing the string
          char quote_type = interpol_stack_.back().quote_type;
          interpol_stack_.pop_back();
          // Continue lexing the rest of the string
          return lex_text_continuation(quote_type);
        } else {
          interpol_stack_.back().brace_depth--;
        }
      }
      return make_token(TokenKind::RBrace, start, 1);
    case '[':
      advance();
      return make_token(TokenKind::LBracket, start, 1);
    case ']':
      advance();
      return make_token(TokenKind::RBracket, start, 1);
    case '<':
      advance();
      return make_token(TokenKind::LAngle, start, 1);
    case '>':
      advance();
      return make_token(TokenKind::RAngle, start, 1);
    case ',':
      advance();
      return make_token(TokenKind::Comma, start, 1);
    case '@':
      advance();
      return make_token(TokenKind::At, start, 1);
    case '*':
      advance();
      return make_token(TokenKind::Times, start, 1);
    case '\\':
    case '\xce': // λ (UTF-8 first byte)
      if (c == '\xce' && peek_char() == '\xbb') {
        advance(2);
        return make_token(TokenKind::Backslash, start, 2);
      }
      advance();
      return make_token(TokenKind::Backslash, start, 1);
    default:
      break;
  }

  // Multi-character operators and tokens
  return lex_operator();
}

Token Lexer::lex_operator() {
  std::uint32_t start = offset();
  char c = current();

  // Handle operators by first character
  switch (c) {
    case ':':
      advance();
      if (match(':')) {
        return make_token(TokenKind::DoubleColon, start, 2);
      }
      return make_token(TokenKind::Colon, start, 1);

    case '.':
      // Check for path: ./ or ..
      if (peek_char() == '/') {
        return lex_path();
      }
      if (peek_char() == '.' && peek_char(2) == '/') {
        return lex_path();
      }
      advance();
      return make_token(TokenKind::Dot, start, 1);

    case '=':
      advance();
      if (match('=')) {
        if (match('=')) {
          return make_token(TokenKind::Equivalent, start, 3); // ===
        }
        return make_token(TokenKind::DoubleEqual, start, 2); // ==
      }
      return make_token(TokenKind::Equal, start, 1); // =

    case '!':
      advance();
      if (match('=')) {
        return make_token(TokenKind::NotEqual, start, 2);
      }
      return make_error("expected !=", start);

    case '|':
      advance();
      if (match('|')) {
        return make_token(TokenKind::Or, start, 2);
      }
      return make_token(TokenKind::Pipe, start, 1);

    case '&':
      advance();
      if (match('&')) {
        return make_token(TokenKind::And, start, 2);
      }
      return make_error("expected &&", start);

    case '+':
      advance();
      if (match('+')) {
        return make_token(TokenKind::TextAppend, start, 2);
      }
      // Check if followed by digit (positive integer)
      if (std::isdigit(static_cast<unsigned char>(current()))) {
        // Back up and lex as integer
        ptr_--;
        col_--;
        return lex_number();
      }
      return make_token(TokenKind::Plus, start, 1);

    case '-':
      advance();
      if (match('>')) {
        return make_token(TokenKind::Arrow, start, 2);
      }
      // Check if followed by digit (negative integer)
      if (std::isdigit(static_cast<unsigned char>(current()))) {
        ptr_--;
        col_--;
        return lex_number();
      }
      // Check for -Infinity
      if (static_cast<std::size_t>(end_ - ptr_) >= 8 && std::string_view(ptr_, 8) == "Infinity") {
        ptr_ += 8;
        Token t = make_token(TokenKind::DoubleLit, start, 9); // "-Infinity"
        t.double_val = -std::numeric_limits<double>::infinity();
        return t;
      }
      // Standalone - is not valid, but handle gracefully
      return make_error("unexpected -", start);

    case '/':
      // rechaos: an absolute local import (/path/to/file), which the standard
      // grammar allows alongside ./ and ../; the operators //, //\\ and /\\ keep
      // their meaning because they never start with a path character.
      if (is_path_char(peek_char()) && peek_char() != '/' && peek_char() != '\\') {
        return lex_path();
      }
      advance();
      if (match('/')) {
        if (match('\\')) {
          if (match('\\')) {
            return make_token(TokenKind::CombineTypes, start, 4);
          }
          return make_error("expected //\\\\", start);
        }
        return make_token(TokenKind::Prefer, start, 2);
      }
      if (match('\\')) {
        return make_token(TokenKind::Combine, start, 2);
      }
      return make_error("unexpected /", start);

    case '#':
      advance();
      return make_token(TokenKind::ListAppend, start, 1);

    case '?':
      advance();
      return make_token(TokenKind::Alternative, start, 1);

    case '"':
      return lex_text();

    case '\'':
      if (peek_char() == '\'') {
        return lex_multiline_text();
      }
      return make_error("unexpected '", start);

    case '`':
      return lex_quoted_label();

    case '\xe2': // UTF-8 multi-byte
      // ∀ = E2 88 80
      if (peek_char() == '\x88' && peek_char(2) == '\x80') {
        advance(3);
        return make_token(TokenKind::Forall, start, 3);
      }
      // → = E2 86 92
      if (peek_char() == '\x86' && peek_char(2) == '\x92') {
        advance(3);
        return make_token(TokenKind::Arrow, start, 3);
      }
      // Check for ∧ (U+2227, 0xe2 0x88 0xa7) - combine/and
      if (ptr_[0] == '\xe2' && ptr_ + 2 < end_ && ptr_[1] == '\x88' && ptr_[2] == '\xa7') {
        advance(3);
        return make_token(TokenKind::Combine, start, 3);
      }
      // Check for ⩓ (U+2A53, 0xe2 0xa9 0x93) - CombineTypes
      if (ptr_[0] == '\xe2' && ptr_ + 2 < end_ && ptr_[1] == '\xa9' && ptr_[2] == '\x93') {
        advance(3);
        return make_token(TokenKind::CombineTypes, start, 3);
      }
      // Check for ⫽ (U+2AFD, 0xe2 0xab 0xbd) - Prefer
      if (ptr_[0] == '\xe2' && ptr_ + 2 < end_ && ptr_[1] == '\xab' && ptr_[2] == '\xbd') {
        advance(3);
        return make_token(TokenKind::Prefer, start, 3);
      }
      // Check for ∀ (U+2200, 0xe2 0x88 0x80) - forall
      if (ptr_[0] == '\xe2' && ptr_ + 2 < end_ && ptr_[1] == '\x88' && ptr_[2] == '\x80') {
        advance(3);
        return make_token(TokenKind::Forall, start, 3);
      }
      // Check for λ (U+03BB, 0xce 0xbb) - lambda
      if (ptr_[0] == '\xce' && ptr_ + 1 < end_ && ptr_[1] == '\xbb') {
        advance(2);
        return make_token(TokenKind::Backslash, start, 2);
      }
      return make_error("unexpected character", start);

    default:
      break;
  }

  // Numbers
  if (std::isdigit(static_cast<unsigned char>(c))) {
    return lex_number();
  }

  // Labels (identifiers) and keywords
  if (std::isalpha(static_cast<unsigned char>(c)) || c == '_') {
    return lex_label_or_keyword();
  }

  // Unknown character
  advance();
  return make_error("unexpected character", start);
}

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBERS
// ═══════════════════════════════════════════════════════════════════════════════

Token Lexer::lex_number() {
  std::uint32_t start = offset();

  bool negative = false;
  bool has_sign = false; // +N is Integer, N is Natural
  if (current() == '+') {
    has_sign = true;
    advance();
  } else if (current() == '-') {
    negative = true;
    has_sign = true;
    advance();
  }

  // Check for hex: 0x
  if (current() == '0' && (peek_char() == 'x' || peek_char() == 'X')) {
    advance(2);
    // Check for bytes literal: 0x"..."
    if (current() == '"') {
      advance(); // consume opening "
      // Lex hex digits until closing "
      while (!at_end()) {
        char c = current();
        if (c == '"') {
          advance();
          return make_token(TokenKind::BytesLit, start, offset() - start);
        }
        // Must be hex digit
        if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
          advance();
        } else {
          return make_error("invalid character in bytes literal", start);
        }
      }
      return make_error("unterminated bytes literal", start);
    }
    std::uint64_t val = 0;
    bool has_digit = false;
    while (!at_end()) {
      char c = current();
      if (c >= '0' && c <= '9') {
        val = val * 16 + (c - '0');
        has_digit = true;
        advance();
      } else if (c >= 'a' && c <= 'f') {
        val = val * 16 + (c - 'a' + 10);
        has_digit = true;
        advance();
      } else if (c >= 'A' && c <= 'F') {
        val = val * 16 + (c - 'A' + 10);
        has_digit = true;
        advance();
      } else {
        break;
      }
    }
    if (!has_digit) {
      return make_error("expected hex digit", start);
    }
    Token t = make_token(TokenKind::NaturalLit, start, offset() - start);
    t.natural_val = val;
    return t;
  }

  // Decimal integer or double
  std::uint64_t int_part = 0;
  bool overflowed = false;
  const char* digits_start = ptr_; // Remember start of digits for strtod

  while (!at_end() && std::isdigit(static_cast<unsigned char>(current()))) {
    int digit = current() - '0';
    if (!overflowed) {
      // Check for overflow before multiplying
      constexpr std::uint64_t max_before_mul = UINT64_MAX / 10;
      constexpr std::uint64_t max_last_digit = UINT64_MAX % 10;
      if (int_part > max_before_mul ||
          (int_part == max_before_mul && static_cast<std::uint64_t>(digit) > max_last_digit)) {
        // Overflow! Will use strtod later for accurate parsing
        overflowed = true;
      } else {
        int_part = int_part * 10 + digit;
      }
    }
    advance();
  }

  // For overflowed integers, use strtod for accurate conversion
  double big_int_val = 0.0;
  if (overflowed) {
    // Create null-terminated string from digits for strtod
    std::size_t digits_len = ptr_ - digits_start;
    std::string digits_str(digits_start, digits_len);
    big_int_val = std::strtod(digits_str.c_str(), nullptr);
  }

  // Check for double
  bool is_double = false;
  double double_val = overflowed ? big_int_val : static_cast<double>(int_part);

  if (current() == '.') {
    // Could be double or field access - peek ahead
    if (std::isdigit(static_cast<unsigned char>(peek_char()))) {
      is_double = true;
      advance(); // consume .
      double frac = 0.0;
      double place = 0.1;
      while (!at_end() && std::isdigit(static_cast<unsigned char>(current()))) {
        frac += (current() - '0') * place;
        place *= 0.1;
        advance();
      }
      double_val += frac;
    }
  }

  // Exponent
  if (current() == 'e' || current() == 'E') {
    is_double = true;
    advance();
    bool exp_neg = false;
    if (current() == '+') {
      advance();
    } else if (current() == '-') {
      exp_neg = true;
      advance();
    }
    int exp = 0;
    while (!at_end() && std::isdigit(static_cast<unsigned char>(current()))) {
      exp = exp * 10 + (current() - '0');
      advance();
    }
    if (exp_neg) {
      exp = -exp;
    }
    double multiplier = 1.0;
    for (int i = 0; i < (exp > 0 ? exp : -exp); i++) {
      multiplier *= 10.0;
    }
    if (exp > 0) {
      double_val *= multiplier;
    } else {
      double_val /= multiplier;
    }
  }

  // rechaos: the digit-by-digit accumulation above is kept only to find the
  // end of the literal; it is not correctly rounded (0.3 became
  // 0.30000000000000004). The value comes from std::from_chars over the whole
  // literal, which is correctly rounded and locale-independent, so doubles
  // round-trip exactly like the reference.
  if (is_double) {
    double parsed = 0.0;
    auto result = std::from_chars(digits_start, ptr_, parsed);
    if (result.ec == std::errc{}) {
      double_val = parsed;
    }
  }

  if (negative) {
    if (is_double) {
      double_val = -double_val;
    } else if (overflowed) {
      // Big negative integer - store as BigIntLit
      Token t = make_token(TokenKind::BigIntLit, start, offset() - start);
      t.big_int.value = big_int_val;
      t.big_int.negative = true;
      return t;
    } else {
      // Negative integer
      Token t = make_token(TokenKind::IntegerLit, start, offset() - start);
      t.integer_val = -static_cast<std::int64_t>(int_part);
      return t;
    }
  }

  if (is_double) {
    Token t = make_token(TokenKind::DoubleLit, start, offset() - start);
    t.double_val = double_val;
    return t;
  }

  // Check for overflowed positive integer
  if (overflowed && has_sign) {
    Token t = make_token(TokenKind::BigIntLit, start, offset() - start);
    t.big_int.value = big_int_val;
    t.big_int.negative = false;
    return t;
  }

  // rechaos: an unsigned literal past 2^64-1 used to keep its pre-overflow
  // prefix as a Natural and evaluate silently wrong; it is a BigInt like the
  // signed case (the driver refuses to render BigInts, since their digits are
  // not preserved exactly).
  if (overflowed) {
    Token t = make_token(TokenKind::BigIntLit, start, offset() - start);
    t.big_int.value = big_int_val;
    t.big_int.negative = false;
    return t;
  }

  // Positive integer with + sign, or natural without sign
  if (has_sign) {
    Token t = make_token(TokenKind::IntegerLit, start, offset() - start);
    t.integer_val = static_cast<std::int64_t>(int_part);
    return t;
  }
  Token t = make_token(TokenKind::NaturalLit, start, offset() - start);
  t.natural_val = int_part;
  return t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LABELS AND KEYWORDS
// ═══════════════════════════════════════════════════════════════════════════════

static bool is_label_start(char c) {
  return std::isalpha(static_cast<unsigned char>(c)) || c == '_';
}

static bool is_label_char(char c) {
  return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-';
}

static bool is_path_char(char c) {
  // Valid in file paths: alphanumeric, _, -, ., /
  return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-' || c == '.' ||
         c == '/';
}

Token Lexer::lex_label_or_keyword() {
  std::uint32_t start = offset();

  // Check for env: prefix (env:VAR_NAME)
  if (static_cast<std::size_t>(end_ - ptr_) >= 4 && ptr_[0] == 'e' && ptr_[1] == 'n' &&
      ptr_[2] == 'v' && ptr_[3] == ':') {
    advance(4); // consume "env:"
    return lex_env();
  }

  // Check for http:// or https://
  if (static_cast<std::size_t>(end_ - ptr_) >= 7 && ptr_[0] == 'h' && ptr_[1] == 't' &&
      ptr_[2] == 't' && ptr_[3] == 'p') {
    if (ptr_[4] == ':' && ptr_[5] == '/' && ptr_[6] == '/') {
      return lex_http();
    }
    if (static_cast<std::size_t>(end_ - ptr_) >= 8 && ptr_[4] == 's' && ptr_[5] == ':' &&
        ptr_[6] == '/' && ptr_[7] == '/') {
      return lex_http();
    }
  }

  while (!at_end() && is_label_char(current())) {
    advance();
  }

  // Handle builtin names with / like Natural/fold
  if (current() == '/' && !at_end()) {
    // Peek ahead to see if this is a builtin
    const char* save = ptr_;
    advance(); // consume /
    while (!at_end() && is_label_char(current())) {
      advance();
    }
    std::string_view full = src_.substr(start, offset() - start);
    BuiltinName bn = lookup_builtin(full);
    if (bn != BuiltinName::Unknown) {
      Token t = make_token(TokenKind::Builtin, start, static_cast<std::uint32_t>(full.size()));
      t.natural_val = static_cast<std::uint64_t>(bn);
      return t;
    }
    // Not a builtin, restore position
    ptr_ = save;
  }

  std::string_view text = src_.substr(start, offset() - start);

  // Check keywords
  if (text == "if") {
    return make_token(TokenKind::If, start, 2);
  }
  if (text == "then") {
    return make_token(TokenKind::Then, start, 4);
  }
  if (text == "else") {
    return make_token(TokenKind::Else, start, 4);
  }
  if (text == "let") {
    return make_token(TokenKind::Let, start, 3);
  }
  if (text == "in") {
    return make_token(TokenKind::In, start, 2);
  }
  if (text == "forall") {
    return make_token(TokenKind::Forall, start, 6);
  }
  if (text == "assert") {
    return make_token(TokenKind::Assert, start, 6);
  }
  if (text == "as") {
    return make_token(TokenKind::As, start, 2);
  }
  if (text == "using") {
    return make_token(TokenKind::Using, start, 5);
  }
  if (text == "merge") {
    return make_token(TokenKind::Merge, start, 5);
  }
  if (text == "toMap") {
    return make_token(TokenKind::ToMap, start, 5);
  }
  if (text == "with") {
    return make_token(TokenKind::With, start, 4);
  }
  if (text == "missing") {
    return make_token(TokenKind::Missing, start, 7);
  }
  if (text == "Type") {
    return make_token(TokenKind::Type, start, 4);
  }
  if (text == "Kind") {
    return make_token(TokenKind::Kind, start, 4);
  }
  if (text == "Sort") {
    return make_token(TokenKind::Sort, start, 4);
  }

  // Check for special double literals
  if (text == "NaN") {
    Token t = make_token(TokenKind::DoubleLit, start, 3);
    t.double_val = std::numeric_limits<double>::quiet_NaN();
    return t;
  }
  if (text == "Infinity") {
    Token t = make_token(TokenKind::DoubleLit, start, 8);
    t.double_val = std::numeric_limits<double>::infinity();
    return t;
  }

  // Check builtins (includes True, False, None, Some, etc.)
  BuiltinName bn = lookup_builtin(text);
  if (bn != BuiltinName::Unknown) {
    Token t = make_token(TokenKind::Builtin, start, static_cast<std::uint32_t>(text.size()));
    t.natural_val = static_cast<std::uint64_t>(bn);
    return t;
  }

  // Check for sha256 hash: sha256:HEXHEXHEX... (64 hex chars)
  if (text == "sha256" && current() == ':') {
    advance(); // consume :
    std::uint32_t hash_start = offset();
    int hex_count = 0;
    while (!at_end() && std::isxdigit(static_cast<unsigned char>(current()))) {
      advance();
      hex_count++;
    }
    if (hex_count == 64) {
      // Valid sha256 hash
      return make_token(TokenKind::Hash, start, offset() - start);
    }
    // Not a valid hash, roll back to return just "sha256" as label
    // (this case shouldn't happen with valid Dhall)
  }

  // Regular label
  return make_token(TokenKind::Label, start, static_cast<std::uint32_t>(text.size()));
}

Token Lexer::lex_quoted_label() {
  std::uint32_t start = offset();
  advance(); // consume opening `

  while (!at_end() && current() != '`') {
    advance();
  }

  if (at_end()) {
    return make_error("unterminated quoted label", start);
  }

  advance(); // consume closing `
  return make_token(TokenKind::QuotedLabel, start, offset() - start);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXT LITERALS
// ═══════════════════════════════════════════════════════════════════════════════

Token Lexer::lex_text() {
  std::uint32_t start = offset();
  advance(); // consume opening "

  while (!at_end()) {
    char c = current();
    if (c == '"') {
      advance();
      return make_token(TokenKind::TextLit, start, offset() - start);
    }
    if (c == '\\') {
      advance();
      if (!at_end()) {
        advance(); // skip escaped char
      }
    } else if (c == '$' && peek_char() == '{') {
      // String interpolation: "foo${expr}bar"
      // Return the text prefix (including opening quote), then start interpolation
      auto text_tok = make_token(TokenKind::TextLit, start, offset() - start);
      advance(2); // consume ${
      interpol_stack_.push_back(
          {'"', 0}); // track that we're in a double-quoted string interpolation
      return text_tok;
    } else {
      advance();
    }
  }

  return make_error("unterminated string", start);
}

Token Lexer::lex_multiline_text() {
  std::uint32_t start = offset();
  advance(2); // consume opening ''

  // Find closing ''
  while (!at_end()) {
    if (current() == '\'' && peek_char() == '\'') {
      // Check it's not '''
      if (peek_char(2) != '\'') {
        advance(2);
        return make_token(TokenKind::TextLit, start, offset() - start);
      }
      // ''' - escaped quote, skip
      advance(3);
    } else if (current() == '$' && peek_char() == '{') {
      // String interpolation
      auto text_tok = make_token(TokenKind::TextLit, start, offset() - start);
      advance(2);                           // consume ${
      interpol_stack_.push_back({'\'', 0}); // track that we're in a multiline string interpolation
      return text_tok;
    } else {
      advance();
    }
  }

  return make_error("unterminated multiline string", start);
}

Token Lexer::lex_text_continuation(char quote_type) {
  // Continue lexing a string after an interpolation closes
  // We're positioned right after the closing }
  std::uint32_t start = offset();

  if (quote_type == '"') {
    // Double-quoted string continuation
    while (!at_end()) {
      char c = current();
      if (c == '"') {
        advance();
        return make_token(TokenKind::TextLit, start, offset() - start);
      }
      if (c == '\\') {
        advance();
        if (!at_end()) {
          advance(); // skip escaped char
        }
      } else if (c == '$' && peek_char() == '{') {
        // Another interpolation
        auto text_tok = make_token(TokenKind::TextLit, start, offset() - start);
        advance(2); // consume ${
        interpol_stack_.push_back({'"', 0});
        return text_tok;
      } else {
        advance();
      }
    }
    return make_error("unterminated string", start);
  } else {
    // Multiline string continuation (quote_type == '\'')
    while (!at_end()) {
      if (current() == '\'' && peek_char() == '\'') {
        if (peek_char(2) != '\'') {
          advance(2);
          return make_token(TokenKind::TextLit, start, offset() - start);
        }
        // ''' - escaped quote
        advance(3);
      } else if (current() == '$' && peek_char() == '{') {
        // Another interpolation
        auto text_tok = make_token(TokenKind::TextLit, start, offset() - start);
        advance(2); // consume ${
        interpol_stack_.push_back({'\'', 0});
        return text_tok;
      } else {
        advance();
      }
    }
    return make_error("unterminated multiline string", start);
  }
}

Token Lexer::peek() {
  // Save state
  const char* saved_ptr = ptr_;
  std::uint32_t saved_line = line_;
  std::uint32_t saved_col = col_;

  Token t = next();

  // Restore state
  ptr_ = saved_ptr;
  line_ = saved_line;
  col_ = saved_col;

  return t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMPORTS
// ═══════════════════════════════════════════════════════════════════════════════

Token Lexer::lex_path() {
  std::uint32_t start = offset();

  // Consume the path: starts with ./, ../, or /
  // Continues with path characters until whitespace or special char
  while (!at_end() && is_path_char(current())) {
    advance();
  }

  return make_token(TokenKind::LocalPath, start, offset() - start);
}

Token Lexer::lex_env() {
  std::uint32_t start = offset();

  // Already consumed "env:"
  // Now consume the variable name
  while (!at_end() && (std::isalnum(static_cast<unsigned char>(current())) || current() == '_')) {
    advance();
  }

  return make_token(TokenKind::EnvVar, start, offset() - start);
}

Token Lexer::lex_http() {
  std::uint32_t start = offset();

  // Consume until whitespace or certain delimiters
  while (!at_end()) {
    char c = current();
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ')' || c == ']' || c == '}' ||
        c == ',' || c == '?') {
      break;
    }
    advance();
  }

  return make_token(TokenKind::HttpUrl, start, offset() - start);
}

} // namespace continuity::dhall
