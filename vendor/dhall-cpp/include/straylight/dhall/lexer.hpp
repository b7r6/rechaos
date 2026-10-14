// Continuity.Codec.Dhall - Lexer
// Target: <1ms for sensenet's 12K LOC
//
// straylight.software · 2026

#pragma once

#include <cstdint>
#include <string_view>
#include <vector>

namespace continuity::dhall {

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

enum class TokenKind : std::uint8_t {
  // Punctuation (single char)
  LParen,    // (
  RParen,    // )
  LBrace,    // {
  RBrace,    // }
  LBracket,  // [
  RBracket,  // ]
  LAngle,    // <
  RAngle,    // >
  Comma,     // ,
  Dot,       // .
  Colon,     // :
  At,        // @
  Equal,     // =
  Pipe,      // |
  Backslash, // λ or backslash
  Question,  // ?

  // Multi-char operators
  Arrow,        // ->
  FatArrow,     // =>
  DoubleColon,  // ::
  Combine,      // /\  (recursive merge)
  CombineTypes, // //\\ (recursive merge types)
  Prefer,       // //  (right-biased merge)
  Alternative,  // ?   (import alternative)
  Equivalent,   // ===
  DoubleEqual,  // ==  (equality comparison)
  NotEqual,     // !=

  // Boolean operators
  And, // &&
  Or,  // ||

  // Arithmetic
  Plus,  // +
  Times, // *

  // Text
  TextAppend, // ++

  // List
  ListAppend, // #

  // Keywords
  If,
  Then,
  Else,
  Let,
  In,
  Forall, // forall or ∀
  Assert,
  As,
  Using,
  Merge,
  ToMap,
  With,
  Missing,

  // Type keywords
  Type,
  Kind,
  Sort,

  // Builtins (Natural, List, etc.)
  Builtin,

  // Literals
  NaturalLit,
  IntegerLit,
  BigIntLit, // Integer too large for int64_t
  DoubleLit,
  TextLit,
  BytesLit, // 0x"..."

  // Text interpolation markers
  TextInterpolStart, // ${
  TextInterpolEnd,   // } inside text

  // Identifiers
  Label,
  QuotedLabel, // `label`

  // Imports
  LocalPath, // ./path or ../path or /path
  EnvVar,    // env:VAR
  HttpUrl,   // https://...
  Hash,      // sha256:XXXX... (64 hex chars)

  // Special
  Newline,
  Eof,
  Error,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN
// ═══════════════════════════════════════════════════════════════════════════════

struct Token {
  TokenKind kind;
  std::uint32_t offset; // byte offset into source
  std::uint32_t length;

  // Literal values (valid when kind is *Lit)
  union {
    std::uint64_t natural_val;
    std::int64_t integer_val;
    double double_val;
    struct {
      double value;  // Double approximation of large integer
      bool negative; // Sign of the integer
    } big_int;
  };

  // For Label/QuotedLabel - index into source
  std::string_view text(std::string_view source) const { return source.substr(offset, length); }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BUILTIN NAMES
// ═══════════════════════════════════════════════════════════════════════════════

enum class BuiltinName : std::uint8_t {
  // Types
  Bool,
  Natural,
  Integer,
  Double,
  Text,
  List,
  Optional,
  None,

  // Natural operations
  Natural_fold,
  Natural_build,
  Natural_isZero,
  Natural_even,
  Natural_odd,
  Natural_toInteger,
  Natural_show,
  Natural_subtract,

  // Integer operations
  Integer_clamp,
  Integer_negate,
  Integer_toDouble,
  Integer_show,

  // Double operations
  Double_show,

  // Text operations
  Text_show,
  Text_replace,

  // List operations
  List_build,
  List_fold,
  List_length,
  List_head,
  List_last,
  List_indexed,
  List_reverse,

  // Optional
  Some,

  // Boolean
  True,
  False,

  // Union
  ShowConstructor,

  // Bytes
  Bytes,

  Unknown,
};

BuiltinName lookup_builtin(std::string_view name);

// ═══════════════════════════════════════════════════════════════════════════════
// LEXER
// ═══════════════════════════════════════════════════════════════════════════════

class Lexer {
  std::string_view src_;
  const char* ptr_;
  const char* end_;
  std::uint32_t line_ = 1;
  std::uint32_t col_ = 1;

  // Interpolation state tracking
  // Stack of states for nested interpolations (e.g. "foo ${"bar ${x}"}")
  // Each entry is: (start_quote_type, brace_depth)
  // quote_type: '"' for double-quoted, '\'' for multiline
  struct InterpolState {
    char quote_type; // '"' or '\''
    int brace_depth; // tracks nested {} within interpolation
  };
  std::vector<InterpolState> interpol_stack_;

public:
  explicit Lexer(std::string_view source)
      : src_(source), ptr_(source.data()), end_(source.data() + source.size()) {}

  // Are we currently inside an interpolation?
  bool in_interpolation() const { return !interpol_stack_.empty(); }

  Token next();
  Token peek();

  std::uint32_t line() const { return line_; }
  std::uint32_t col() const { return col_; }
  std::uint32_t offset() const { return static_cast<std::uint32_t>(ptr_ - src_.data()); }

private:
  char current() const { return ptr_ < end_ ? *ptr_ : '\0'; }
  char peek_char(int n = 1) const { return ptr_ + n < end_ ? ptr_[n] : '\0'; }
  void advance(int n = 1);
  bool at_end() const { return ptr_ >= end_; }
  bool match(char c);
  bool match(std::string_view s);

  void skip_whitespace_and_comments();
  void skip_line_comment();
  void skip_block_comment();

  Token make_token(TokenKind kind, std::uint32_t start, std::uint32_t len);
  Token make_error(const char* msg, std::uint32_t start);

  Token lex_number();
  Token lex_label_or_keyword();
  Token lex_quoted_label();
  Token lex_text();
  Token lex_multiline_text();
  Token lex_text_continuation(char quote_type);
  Token lex_operator();
  Token lex_path();
  Token lex_env();
  Token lex_http();
};

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

inline void Lexer::advance(int n) {
  while (n-- > 0 && ptr_ < end_) {
    if (*ptr_ == '\n') {
      line_++;
      col_ = 1;
    } else {
      col_++;
    }
    ptr_++;
  }
}

inline bool Lexer::match(char c) {
  if (current() == c) {
    advance();
    return true;
  }
  return false;
}

inline bool Lexer::match(std::string_view s) {
  if (static_cast<std::size_t>(end_ - ptr_) >= s.size() && std::string_view(ptr_, s.size()) == s) {
    advance(static_cast<int>(s.size()));
    return true;
  }
  return false;
}

inline Token Lexer::make_token(TokenKind kind, std::uint32_t start, std::uint32_t len) {
  Token t;
  t.kind = kind;
  t.offset = start;
  t.length = len;
  t.natural_val = 0;
  return t;
}

inline Token Lexer::make_error(const char* msg, std::uint32_t start) {
  Token t;
  t.kind = TokenKind::Error;
  t.offset = start;
  t.length = static_cast<std::uint32_t>(ptr_ - src_.data() - start);
  return t;
}

} // namespace continuity::dhall
