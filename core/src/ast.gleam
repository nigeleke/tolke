import gleam/option.{type Option as GleamOption}

/// message           = simple-message / complex-message
pub type Message {
  MessageSimple(SimpleMessage)
  MessageComplex(ComplexMessage)
}

/// simple-message    = o [simple-start pattern]
pub type SimpleMessage {
  SimpleMessageBody(GleamOption(#(SimpleStart, Pattern)))
}

/// simple-start      = simple-start-char / escaped-char / placeholder
pub type SimpleStart {
  SimpleStartChar(SimpleStartChar)
  SimpleStartEscapedChar(EscapedChar)
  SimpleStartPlaceholder(Placeholder)
}

/// pattern           = *(text-char / escaped-char / placeholder)
pub type Pattern {
  PatternBody(List(PatternElement))
}

pub type PatternElement {
  PatternElementTextChar(TextChar)
  PatternElementEscapedChar(EscapedChar)
  PatternElementPlaceholder(Placeholder)
}

/// placeholder       = expression / markup
pub type Placeholder {
  PlaceholderExpression(Expression)
  PlaceholderMarkup(Markup)
}

/// complex-message   = o *(declaration o) complex-body o
pub type ComplexMessage {
  ComplexMessageBody(List(Declaration), ComplexBody)
}

/// declaration       = input-declaration / local-declaration
pub type Declaration {
  DeclarationInput(InputDeclaration)
  DeclarationLocal(LocalDeclaration)
}

/// complex-body      = quoted-pattern / matcher
pub type ComplexBody {
  ComplexBodyQuotedPattern(QuotedPattern)
  ComplexBodyMatcher(Matcher)
}

/// input-declaration = input o variable-expression
pub type InputDeclaration {
  InputDeclarationBody(VariableExpression)
}

/// local-declaration = local s variable o "=" o expression
pub type LocalDeclaration {
  LocalDeclarationBody(Variable, Expression)
}

/// quoted-pattern    = o "{{" pattern "}}"
pub type QuotedPattern {
  QuotedPatternBody(Pattern)
}

/// matcher           = match-statement s variant *(o variant)
pub type Matcher {
  MatcherBody(MatchStatement, Variant, List(Variant))
}

/// match-statement   = match 1*(s selector)
pub type MatchStatement {
  MatchStatementBody(List(Selector))
}

/// selector          = variable
pub type Selector {
  SelectorBody(Variable)
}

/// variant           = key *(s key) quoted-pattern
pub type Variant {
  VariantBody(Key, List(Key), QuotedPattern)
}

/// key               = literal / "*"
pub type Key {
  KeyLiteral(Literal)
  KeyOther
}

/// ; Expressions
/// expression          = literal-expression
///                     / variable-expression
///                     / function-expression
pub type Expression {
  ExpressionLiteral(LiteralExpression)
  ExpressionVariable(VariableExpression)
  ExpressionFunction(FunctionExpression)
}

/// literal-expression  = "{" o literal [s function] *(s attribute) o "}"
pub type LiteralExpression {
  LiteralExpressionBody(Literal, GleamOption(Function), List(Attribute))
}

/// variable-expression = "{" o variable [s function] *(s attribute) o "}"
pub type VariableExpression {
  VariableExpressionBody(Variable, GleamOption(Function), List(Attribute))
}

/// function-expression = "{" o function *(s attribute) o "}"
pub type FunctionExpression {
  FunctionExpressionBody(Function, List(Attribute))
}

/// markup = "{" o "#" identifier *(s option) *(s attribute) o ["/"] "}"  ; open and standalone
///        / "{" o "/" identifier *(s option) *(s attribute) o "}"  ; close
pub type Markup {
  MarkupStandalone(Identifier, List(Option), List(Attribute))
  MarkupOpen(Identifier, List(Option), List(Attribute))
  MarkupClose(Identifier, List(Option), List(Attribute))
}

/// ; Expression and literal parts
/// function       = ":" identifier *(s option)
pub type Function {
  FunctionBody(Identifier, List(Option))
}

/// option         = identifier o "=" o (literal / variable)
pub type Option {
  OptionBody(Identifier, OptionElement)
}

pub type OptionElement {
  OptionElementLiteral(Literal)
  OptionElementVariable(Variable)
}

/// attribute      = "@" identifier [o "=" o literal]
pub type Attribute {
  AttributeBody(Identifier, GleamOption(Literal))
}

/// variable       = "$" name
pub type Variable {
  VariableBody(Name)
}

/// literal          = quoted-literal / unquoted-literal
pub type Literal {
  LiteralQuoted(QuotedLiteral)
  LiteralUnquoted(UnquotedLiteral)
}

/// quoted-literal   = "|" *(quoted-char / escaped-char) "|"
pub type QuotedLiteral =
  String

/// unquoted-literal = name / number-literal
pub type UnquotedLiteral {
  UnquotedLiteralName(Name)
  UnquotedLiteralNumber(NumberLiteral)
}

/// ; number-literal matches JSON number (https://www.rfc-editor.org/rfc/rfc8259#section-6)
/// number-literal   = ["-"] (%x30 / (%x31-39 *DIGIT)) ["." 1*DIGIT] [%i"e" ["-" / "+"] 1*DIGIT]
pub type NumberLiteral =
  String

/// ; Keywords; Note that these are case-sensitive
/// input = %s".input"
pub type Input =
  String

/// local = %s".local"
pub type Local =
  String

/// match = %s".match"
pub type Match =
  String

/// ; Names and identifiers
/// ; identifier matches https://www.w3.org/TR/REC-xml-names/#NT-QName
/// ; name matches https://www.w3.org/TR/REC-xml-names/#NT-NCName but excludes U+FFFD and U+061C
/// identifier = [namespace ":"] name
pub type Identifier {
  Identifier(GleamOption(Namespace), Name)
}

/// namespace  = name
pub type Namespace =
  String

/// name       = [bidi] name-start *name-char [bidi]
pub type Name =
  String

/// name-start = ALPHA / "_"
///            / %xC0-D6 / %xD8-F6 / %xF8-2FF
///            / %x370-37D / %x37F-61B / %x61D-1FFF / %x200C-200D
///            / %x2070-218F / %x2C00-2FEF / %x3001-D7FF
///            / %xF900-FDCF / %xFDF0-FFFC / %x10000-EFFFF
pub type NameStart =
  String

/// name-char  = name-start / DIGIT / "-" / "."
///            / %xB7 / %x300-36F / %x203F-2040
pub type NameChar =
  String

/// ; Restrictions on characters in various contexts
/// simple-start-char = content-char / "@" / "|"
pub type SimpleStartChar =
  String

/// text-char         = content-char / ws / "." / "@" / "|"
pub type TextChar =
  String

/// quoted-char       = content-char / ws / "." / "@" / "{" / "}"
pub type QuotedChar =
  String

/// content-char      = %x01-08        ; omit NULL (%x00), HTAB (%x09) and LF (%x0A)
///                   / %x0B-0C        ; omit CR (%x0D)
///                   / %x0E-1F        ; omit SP (%x20)
///                   / %x21-2D        ; omit . (%x2E)
///                   / %x2F-3F        ; omit @ (%x40)
///                   / %x41-5B        ; omit \ (%x5C)
///                   / %x5D-7A        ; omit { | } (%x7B-7D)
///                   / %x7E-2FFF      ; omit IDEOGRAPHIC SPACE (%x3000)
///                   / %x3001-D7FF    ; omit surrogates
///                   / %xE000-10FFFF
pub type ContentChar =
  String

/// ; Character escapes
/// escaped-char = backslash ( backslash / "{" / "|" / "}" )
pub type EscapedChar =
  String

/// backslash    = %x5C ; U+005C REVERSE SOLIDUS "\"
/// [unused]
///
/// ; Required whitespace
/// s = *bidi ws o
pub type RequiredWhitespace =
  String

/// ; Optional whitespace
/// o = *(ws / bidi)
pub type OptionalWhitespace =
  String

/// ; Bidirectional marks and isolates
/// ; ALM / LRM / RLM / LRI, RLI, FSI & PDI
/// bidi = %x061C / %x200E / %x200F / %x2066-2069
pub type Bidi =
  String

/// ; Whitespace characters
/// ws = SP / HTAB / CR / LF / %x3000
pub type Whitespace =
  String
