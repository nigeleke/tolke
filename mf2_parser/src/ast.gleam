import gleam/option.{type Option as GleamOption}

pub type ParsedMessage =
  Message

/// message           = simple-message / complex-message
pub type Message {
  Simple(SimpleMessage)
  Complex(ComplexMessage)
}

/// simple-message    = o [simple-start pattern]
pub type SimpleMessage {
  SimpleMessage(OptionalWhitespace, GleamOption(#(SimpleStart, Pattern)))
}

/// internal representation...
pub type MessageElement {
  Text(String)
  Escaped(String)
  Placeholder(Placeholder)
}

/// simple-start      = simple-start-char / escaped-char / placeholder
pub type SimpleStart =
  MessageElement

/// pattern           = *(text-char / escaped-char / placeholder)
pub type Pattern =
  List(MessageElement)

/// placeholder       = expression / markup
pub type Placeholder {
  PlaceholderExpression(Expression)
  PlaceholderMarkup(Markup)
}

/// complex-message   = o *(declaration o) complex-body o
pub type ComplexMessage {
  ComplexMessage(List(Declaration), ComplexBody)
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
  InputDeclaration(VariableExpression)
}

/// local-declaration = local s variable o "=" o expression
pub type LocalDeclaration {
  LocalDeclaration(Variable, Expression)
}

/// quoted-pattern    = "{{" pattern "}}"
pub type QuotedPattern {
  QuotedPattern(Pattern)
}

/// matcher           = match-statement s variant *(o variant)
pub type Matcher {
  Matcher(MatchStatement, Variant, List(Variant))
}

/// match-statement   = match 1*(s selector)
pub type MatchStatement {
  MatchStatement(List(Selector))
}

/// selector          = variable
pub type Selector {
  Selector(Variable)
}

/// variant           = key *(s key) o quoted-pattern
pub type Variant {
  Variant(Key, List(Key), QuotedPattern)
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
  LiteralExpression(Literal, GleamOption(Function), List(Attribute))
}

/// variable-expression = "{" o variable [s function] *(s attribute) o "}"
pub type VariableExpression {
  VariableExpression(Variable, GleamOption(Function), List(Attribute))
}

/// function-expression = "{" o function *(s attribute) o "}"
pub type FunctionExpression {
  FunctionExpression(Function, List(Attribute))
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
  Function(Identifier, List(Option))
}

/// option         = identifier o "=" o (literal / variable)
pub type Option {
  Option(Identifier, OptionElement)
}

pub type OptionElement {
  OptionElementLiteral(Literal)
  OptionElementVariable(Variable)
}

/// attribute      = "@" identifier [o "=" o literal]
pub type Attribute {
  FlagAttribute(Identifier)
  ValueAttribute(Identifier, Literal)
}

/// variable       = "$" name
pub type Variable {
  Variable(Name)
}

/// literal          = quoted-literal / unquoted-literal
pub type Literal {
  LiteralQuoted(QuotedLiteral)
  LiteralUnquoted(UnquotedLiteral)
}

/// quoted-literal   = "|" *(quoted-char / escaped-char) "|"
pub type QuotedLiteral =
  String

/// unquoted-literal = 1*name-char
pub type UnquotedLiteral {
  UnquotedLiteral(Name)
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

/// name-start = ALPHA
///                                     ;          omit Cc: %x0-1F, Whitespace: SPACE, Ascii: «!"#$%&'()*»
///                   / %x2B            ; «+»      omit Ascii: «,-./0123456789:;<=>?@» «[\]^»
///                   / %x5F            ; «_»      omit Cc: %x7F-9F, Whitespace: %xA0, Ascii: «`» «{|}~»
///                   / %xA1-61B        ;          omit BidiControl: %x61C
///                   / %x61D-167F      ;          omit Whitespace: %x1680
///                   / %x1681-1FFF     ;          omit Whitespace: %x2000-200A
///                   / %x200B-200D     ;          omit BidiControl: %x200E-200F
///                   / %x2010-2027     ;          omit Whitespace: %x2028-2029 %x202F, BidiControl: %x202A-202E
///                   / %x2030-205E     ;          omit Whitespace: %x205F
///                   / %x2060-2065     ;          omit BidiControl: %x2066-2069
///                   / %x206A-2FFF     ;          omit Whitespace: %x3000
///                   / %x3001-D7FF     ;          omit Cs: %xD800-DFFF
///                   / %xE000-FDCF     ;          omit NChar: %xFDD0-FDEF
///                   / %xFDF0-FFFD     ;          omit NChar: %xFFFE-FFFF
///                   / %x10000-1FFFD   ;          omit NChar: %x1FFFE-1FFFF
///                   / %x20000-2FFFD   ;          omit NChar: %x2FFFE-2FFFF
///                   / %x30000-3FFFD   ;          omit NChar: %x3FFFE-3FFFF
///                   / %x40000-4FFFD   ;          omit NChar: %x4FFFE-4FFFF
///                   / %x50000-5FFFD   ;          omit NChar: %x5FFFE-5FFFF
///                   / %x60000-6FFFD   ;          omit NChar: %x6FFFE-6FFFF
///                   / %x70000-7FFFD   ;          omit NChar: %x7FFFE-7FFFF
///                   / %x80000-8FFFD   ;          omit NChar: %x8FFFE-8FFFF
///                   / %x90000-9FFFD   ;          omit NChar: %x9FFFE-9FFFF
///                   / %xA0000-AFFFD   ;          omit NChar: %xAFFFE-AFFFF
///                   / %xB0000-BFFFD   ;          omit NChar: %xBFFFE-BFFFF
///                   / %xC0000-CFFFD   ;          omit NChar: %xCFFFE-CFFFF
///                   / %xD0000-DFFFD   ;          omit NChar: %xDFFFE-DFFFF
///                   / %xE0000-EFFFD   ;          omit NChar: %xEFFFE-EFFFF
///                   / %xF0000-FFFFD   ;          omit NChar: %xFFFFE-FFFFF
///                   / %x100000-10FFFD ;          omit NChar: %x10FFFE-10FFFF
pub type NameStart =
  String

/// name-char  = name-start / DIGIT / "-" / "."
pub type NameChar =
  String

/// ; Restrictions on characters in various contexts
/// simple-start-char = %x01-08        ; omit NULL (%x00), HTAB (%x09) and LF (%x0A)
///                   / %x0B-0C        ; omit CR (%x0D)
///                   / %x0E-1F        ; omit SP (%x20)
///                   / %x21-2D        ; omit . (%x2E)
///                   / %x2F-5B        ; omit \ (%x5C)
///                   / %x5D-7A        ; omit { (%x7B)
///                   / %x7C           ; omit } (%x7D)
///                   / %x7E-2FFF      ; omit IDEOGRAPHIC SPACE (%x3000)
///                   / %x3001-10FFFF
pub type SimpleStartChar =
  String

/// text-char         = %x01-5B        ; omit NULL (%x00) and \ (%x5C)
///                   / %x5D-7A        ; omit { (%x7B)
///                   / %x7C           ; omit } (%x7D)
///                   / %x7E-10FFFF
pub type TextChar =
  String

/// quoted-char       = %x01-5B        ; omit NULL (%x00) and \ (%x5C)
///                   / %x5D-7B        ; omit | (%x7C)
///                   / %x7D-10FFFF
pub type QuotedChar =
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
