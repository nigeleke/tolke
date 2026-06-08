/// https://github.com/unicode-org/message-format-wg/blob/main/spec/message.abnf
///
/// The grammar is formally defined below using the ABNF notation [STD68], including
/// the modifications found in RFC 7405.
///
/// RFC7405 defines a variation of ABNF that is case-sensitive. Some ABNF tools are only
/// compatible with the specification found in RFC 5234. To make message.abnf compatible
/// with that version of ABNF, replace the rules of the same name with this block:
///
/// input = %x2E.69.6E.70.75.74  ; ".input"
/// local = %x2E.6C.6F.63.61.6C  ; ".local"
/// match = %x2E.6D.61.74.63.68  ; ".match"
///
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option as GleamOption} as gleam_option
import gleam/order
import gleam/result
import gleam/string

import ast.{
  type Attribute, type Bidi, type ComplexBody, type ComplexMessage,
  type Declaration, type EscapedChar, type Expression, type Function,
  type FunctionExpression, type Identifier, type Input, type InputDeclaration,
  type Key, type Literal, type LiteralExpression, type Local,
  type LocalDeclaration, type Markup, type Match, type MatchStatement,
  type Matcher, type Message, type MessageElement, type Name, type NameChar,
  type NameStart, type Namespace, type Option, type OptionalWhitespace,
  type Pattern, type Placeholder, type QuotedChar, type QuotedLiteral,
  type QuotedPattern, type RequiredWhitespace, type Resource, type ResourceEntry,
  type ResourceName, type Selector, type SimpleMessage, type SimpleStart,
  type SimpleStartChar, type TextChar, type UnquotedLiteral, type Variable,
  type VariableExpression, type Variant, type Whitespace,
}

const digits0_9 = "0123456789"

/// `Parsed` contains a successfully parsed `a`, together with any remaining
/// non-parsed input.
type Parsed(a) {
  Parsed(value: a, rest: String)
}

pub type ParseError {
  UnconsumedInput(String)
  NoMatch
}

/// The `Parser` is a function that takes an input String and, if a match
/// is found, returns the `Parsed(out)`.
/// If no match is found then a Error(Nil) is returned.
pub type Parser(out) =
  fn(String) -> Result(Parsed(out), ParseError)

// ----------------------------------------------------------------------------
// Custom for tolke
pub fn parse_resource_as_dict(
  in: String,
) -> Result(Dict(ResourceName, Message), ParseError) {
  parse_resource(in)
  |> result.map(resource_to_dict)
}

fn resource_to_dict(resource: Resource) -> Dict(ResourceName, Message) {
  let ast.Resource(entries) = resource

  entries
  |> list.map(fn(entry) {
    let ast.ResourceEntry(name, message) = entry
    #(name, message)
  })
  |> dict.from_list
}

pub fn parse_resource(in: String) -> Result(Resource, ParseError) {
  case resource()(in) {
    Ok(parsed) ->
      case string.is_empty(parsed.rest) {
        True -> Ok(parsed.value)
        False -> Error(UnconsumedInput(parsed.rest))
      }
    Error(error) -> Error(error)
  }
}

// resource          = o resource-entry *(o resource-entry)
fn resource() -> Parser(Resource) {
  pair(
    right(optional_whitespace(), resource_entry()),
    zero_or_more(right(optional_whitespace(), resource_entry())),
  )
  |> map(fn(result) {
    let #(head, tail) = result
    ast.Resource([head, ..tail])
  })
  |> trace("resource")
}

// resource-entry    = resource-start message
fn resource_entry() -> Parser(ResourceEntry) {
  pair(resource_start(), resource_message())
  |> map(fn(result) { ast.ResourceEntry(result.0, result.1) })
  |> trace("resource-entry")
}

fn resource_message() -> Parser(Message) {
  take_until(next_resource_entry())
  |> and_then(fn(src) {
    fn(rest) {
      case parse(src) {
        Ok(message) -> Ok(Parsed(message, rest))
        Error(error) -> Error(error)
      }
    }
  })
}

// [lookahead] resource-entry    = resource-start message
fn next_resource_entry() -> Parser(Nil) {
  lookahead(resource_start())
  |> map(fn(_) { Nil })
}

// resource-start    = resource-name o ":="
fn resource_start() -> Parser(ResourceName) {
  triple(resource_name(), optional_whitespace(), exact(":="))
  |> map(fn(result) { result.0 })
}

// resource-name     = name
fn resource_name() -> Parser(ResourceName) {
  name()
  |> trace("resource-name")
}

// ----------------------------------------------------------------------------
// Message Format 2
//
/// Parse into a single mf2 message body.
pub fn parse(in: String) -> Result(Message, ParseError) {
  case message()(in) {
    Ok(parsed) ->
      case string.is_empty(parsed.rest) {
        True -> Ok(parsed.value)
        False -> Error(UnconsumedInput(parsed.rest))
      }
    Error(error) -> Error(error)
  }
}

/// message           = simple-message / complex-message
fn message() -> Parser(Message) {
  choice([
    simple_message() |> map(ast.Simple),
    complex_message() |> map(ast.Complex),
  ])
  |> trace("message")
}

/// simple-message = o [simple-start pattern]
fn simple_message() -> Parser(SimpleMessage) {
  pair(optional_whitespace(), simple_message_body())
  |> map(fn(result) { ast.SimpleMessage(result.0, result.1) })
  |> trace("simple-message")
}

fn simple_message_body() -> Parser(List(MessageElement)) {
  choice([
    pair(simple_start(), pattern())
      |> map(fn(result) { [result.0, ..result.1] }),

    empty()
      |> map(fn(_) { [] }),
  ])
}

/// simple-start      = simple-start-char / escaped-char / placeholder
fn simple_start() -> Parser(SimpleStart) {
  choice([
    simple_start_char() |> map(ast.Text),
    escaped_char() |> map(ast.Escaped),
    placeholder() |> map(ast.Placeholder),
  ])
}

/// pattern           = *(text-char / escaped-char / placeholder)
fn pattern() -> Parser(Pattern) {
  zero_or_more(
    choice([
      text_char() |> map(ast.Text),
      escaped_char() |> map(ast.Escaped),
      placeholder() |> map(ast.Placeholder),
    ]),
  )
  |> trace("pattern")
}

/// placeholder       = expression / markup
fn placeholder() -> Parser(Placeholder) {
  choice([
    expression() |> map(ast.PlaceholderExpression),
    markup() |> map(ast.PlaceholderMarkup),
  ])
  |> trace("placeholder")
}

/// complex-message   = o *(declaration o) complex-body o
fn complex_message() -> Parser(ComplexMessage) {
  pair(
    right(
      optional_whitespace(),
      zero_or_more(left(declaration(), optional_whitespace())),
    ),
    left(complex_body(), optional_whitespace()),
  )
  |> map(fn(result) {
    let #(declarations, body) = result
    ast.ComplexMessage(declarations, body)
  })
  |> trace("complex-message")
}

/// declaration       = input-declaration / local-declaration
fn declaration() -> Parser(Declaration) {
  choice([
    input_declaration() |> map(ast.DeclarationInput),
    local_declaration() |> map(ast.DeclarationLocal),
  ])
  |> trace("declaration")
}

/// complex-body      = quoted-pattern / matcher
fn complex_body() -> Parser(ComplexBody) {
  choice([
    quoted_pattern() |> map(ast.ComplexBodyQuotedPattern),
    matcher() |> map(ast.ComplexBodyMatcher),
  ])
  |> trace("complex-body")
}

/// input-declaration = input o variable-expression
fn input_declaration() -> Parser(InputDeclaration) {
  triple(input(), optional_whitespace(), variable_expression())
  |> map(fn(result) { ast.InputDeclaration(result.2) })
  |> trace("input-declaration")
}

/// local-declaration = local s variable o "=" o expression
fn local_declaration() -> Parser(LocalDeclaration) {
  fn(in: String) {
    use local <- bind(local(), in)
    use s <- bind(required_whitespace(), local.rest)
    use variable <- bind(variable(), s.rest)
    use o0 <- bind(optional_whitespace(), variable.rest)
    use equal <- bind(exact("="), o0.rest)
    use o1 <- bind(optional_whitespace(), equal.rest)
    use expression <- bind(expression(), o1.rest)

    let body = ast.LocalDeclaration(variable.value, expression.value)

    Ok(Parsed(body, expression.rest))
  }
  |> trace("local-declaration")
}

/// quoted-pattern    = "{{" pattern "}}"
fn quoted_pattern() -> Parser(QuotedPattern) {
  triple(exact("{{"), pattern(), exact("}}"))
  |> map(fn(result) { ast.QuotedPattern(result.1) })
  |> trace("quoted-pattern")
}

/// matcher           = match-statement s variant *(o variant)
fn matcher() -> Parser(Matcher) {
  fn(in: String) {
    use statement <- bind(match_statement(), in)
    use s <- bind(required_whitespace(), statement.rest)
    use variant0 <- bind(variant(), s.rest)
    use variants <- bind(
      zero_or_more(right(optional_whitespace(), variant())),
      variant0.rest,
    )

    let body = ast.Matcher(statement.value, variant0.value, variants.value)

    Ok(Parsed(body, variants.rest))
  }
  |> trace("matcher")
}

/// match-statement   = match 1*(s selector)
fn match_statement() -> Parser(MatchStatement) {
  right(match(), one_or_more(right(required_whitespace(), selector())))
  |> map(ast.MatchStatement)
}

/// selector          = variable
fn selector() -> Parser(Selector) {
  variable()
  |> map(ast.Selector)
  |> trace("selector")
}

/// variant           = key *(s key) o quoted-pattern
fn variant() -> Parser(Variant) {
  triple(
    key(),
    zero_or_more(right(required_whitespace(), key())),
    right(optional_whitespace(), quoted_pattern()),
  )
  |> map(fn(result) { ast.Variant(result.0, result.1, result.2) })
  |> trace("variant")
}

/// key               = literal / "*"
fn key() -> Parser(Key) {
  choice([
    literal() |> map(ast.KeyLiteral),
    exact("*") |> map(fn(_) { ast.KeyOther }),
  ])
  |> trace("key")
}

/// ; Expressions
/// expression          = literal-expression
///                     / variable-expression
///                     / function-expression
fn expression() -> Parser(Expression) {
  choice([
    literal_expression() |> map(ast.ExpressionLiteral),
    variable_expression() |> map(ast.ExpressionVariable),
    function_expression() |> map(ast.ExpressionFunction),
  ])
  |> trace("expression")
}

/// literal-expression  = "{" o literal [s function] *(s attribute) o "}"
fn literal_expression() -> Parser(LiteralExpression) {
  fn(in: String) {
    use open_brace <- bind(exact("{"), in)
    use o0 <- bind(optional_whitespace(), open_brace.rest)
    use literal <- bind(literal(), o0.rest)
    use function <- bind(
      optional(right(required_whitespace(), function())),
      literal.rest,
    )
    use attributes <- bind(
      zero_or_more(right(required_whitespace(), attribute())),
      function.rest,
    )
    use o1 <- bind(optional_whitespace(), attributes.rest)
    use close_brace <- bind(exact("}"), o1.rest)

    let body =
      ast.LiteralExpression(literal.value, function.value, attributes.value)

    Ok(Parsed(body, close_brace.rest))
  }
  |> trace("literal-expression")
}

/// variable-expression = "{" o variable [s function] *(s attribute) o "}"
fn variable_expression() -> Parser(VariableExpression) {
  fn(in: String) {
    use open_brace <- bind(exact("{"), in)
    use o0 <- bind(optional_whitespace(), open_brace.rest)
    use variable <- bind(variable(), o0.rest)
    use function <- bind(
      optional(right(required_whitespace(), function())),
      variable.rest,
    )
    use attributes <- bind(
      zero_or_more(right(required_whitespace(), attribute())),
      function.rest,
    )
    use o1 <- bind(optional_whitespace(), attributes.rest)
    use close_brace <- bind(exact("}"), o1.rest)

    let body =
      ast.VariableExpression(variable.value, function.value, attributes.value)

    Ok(Parsed(body, close_brace.rest))
  }
  |> trace("variable-expression")
}

/// function-expression = "{" o function *(s attribute) o "}"
fn function_expression() -> Parser(FunctionExpression) {
  fn(in: String) {
    use open_brace <- bind(exact("{"), in)
    use o0 <- bind(optional_whitespace(), open_brace.rest)
    use function <- bind(function(), o0.rest)
    use attributes <- bind(
      zero_or_more(right(required_whitespace(), attribute())),
      function.rest,
    )
    use o1 <- bind(optional_whitespace(), attributes.rest)
    use close_brace <- bind(exact("}"), o1.rest)

    let body = ast.FunctionExpression(function.value, attributes.value)

    Ok(Parsed(body, close_brace.rest))
  }
  |> trace("function-expression")
}

/// markup = "{" o "#" identifier *(s option) *(s attribute) o ["/"] "}"  ; open and standalone
///        / "{" o "/" identifier *(s option) *(s attribute) o "}"  ; close
/// Warning: Parser is order dependent & relies on longest parse wins.
fn markup() -> Parser(Markup) {
  choice([
    markup_open_or_standalone(),
    markup_close(),
  ])
  |> trace("markup")
}

fn markup_open_or_standalone() -> Parser(Markup) {
  markup_common(
    exact("#"),
    optional(exact("/")),
    fn(identifier, options, attributes, standalone) {
      case standalone {
        True -> ast.MarkupStandalone(identifier, options, attributes)
        False -> ast.MarkupOpen(identifier, options, attributes)
      }
    },
  )
  |> trace("markup-open-or-standalone")
}

fn markup_close() -> Parser(Markup) {
  markup_common(
    exact("/"),
    succeed(gleam_option.None),
    fn(identifier, options, attributes, _suffix) {
      ast.MarkupClose(identifier, options, attributes)
    },
  )
  |> trace("markup-close")
}

fn markup_common(
  prefix: Parser(String),
  suffix: Parser(GleamOption(String)),
  build: fn(Identifier, List(Option), List(Attribute), Bool) -> Markup,
) -> Parser(Markup) {
  fn(in: String) {
    use open_brace <- bind(exact("{"), in)
    use o0 <- bind(optional_whitespace(), open_brace.rest)
    use prefix <- bind(prefix, o0.rest)
    use identifier <- bind(identifier(), prefix.rest)
    use options <- bind(
      zero_or_more(right(required_whitespace(), option())),
      identifier.rest,
    )
    use attributes <- bind(
      zero_or_more(right(required_whitespace(), attribute())),
      options.rest,
    )
    use o1 <- bind(optional_whitespace(), attributes.rest)
    use suffix <- bind(suffix, o1.rest)
    use close_brace <- bind(exact("}"), suffix.rest)

    Ok(Parsed(
      build(
        identifier.value,
        options.value,
        attributes.value,
        gleam_option.is_some(suffix.value),
      ),
      close_brace.rest,
    ))
  }
  |> trace("markup-common")
}

/// ; Expression and literal parts
/// function       = ":" identifier *(s option)
fn function() -> Parser(Function) {
  triple(
    exact(":"),
    identifier(),
    zero_or_more(right(required_whitespace(), option())),
  )
  |> map(fn(result) { ast.Function(result.1, result.2) })
  |> trace("function")
}

/// option         = identifier o "=" o (literal / variable)
fn option() -> Parser(Option) {
  fn(in: String) {
    use identifier <- bind(identifier(), in)
    use o0 <- bind(optional_whitespace(), identifier.rest)
    use equal <- bind(exact("="), o0.rest)
    use o1 <- bind(optional_whitespace(), equal.rest)
    use element <- bind(
      choice([
        literal() |> map(ast.OptionElementLiteral),
        variable() |> map(ast.OptionElementVariable),
      ]),
      o1.rest,
    )

    let body = ast.Option(identifier.value, element.value)

    Ok(Parsed(body, element.rest))
  }
  |> trace("option")
}

/// attribute      = "@" identifier [o "=" o literal]
fn attribute() -> Parser(Attribute) {
  right(
    exact("@"),
    choice([
      pair(identifier(), assign_literal())
        |> map(fn(result) { ast.ValueAttribute(result.0, result.1) }),
      identifier() |> map(ast.FlagAttribute),
    ]),
  )
}

fn assign_literal() -> Parser(Literal) {
  fn(in: String) {
    use o0 <- bind(optional_whitespace(), in)
    use equal <- bind(exact("="), o0.rest)
    use o1 <- bind(optional_whitespace(), equal.rest)
    use literal <- bind(literal(), o1.rest)

    Ok(literal)
  }
}

/// variable       = "$" name
fn variable() -> Parser(Variable) {
  right(exact("$"), name())
  |> map(ast.Variable)
  |> trace("variable")
}

/// literal          = quoted-literal / unquoted-literal
fn literal() -> Parser(Literal) {
  choice([
    quoted_literal() |> map(ast.LiteralQuoted),
    unquoted_literal() |> map(ast.LiteralUnquoted),
  ])
  |> trace("literal")
}

/// quoted-literal   = "|" *(quoted-char / escaped-char) "|"
fn quoted_literal() -> Parser(QuotedLiteral) {
  triple(
    exact("|"),
    zero_or_more(choice([quoted_char(), escaped_char()]))
      |> map(joined),
    exact("|"),
  )
  |> map(fn(result) { result.1 })
  |> trace("quoted-literal")
}

/// unquoted-literal = 1*name-char
fn unquoted_literal() -> Parser(UnquotedLiteral) {
  one_or_more(name_char())
  |> map(joined)
  |> map(ast.UnquotedLiteral)
  |> trace("unquoted-literal")
}

/// ; Keywords; Note that these are case-sensitive
/// input = %s".input"
fn input() -> Parser(Input) {
  exact(".input")
  |> trace("input")
}

/// local = %s".local"
fn local() -> Parser(Local) {
  exact(".local")
  |> trace("local")
}

/// match = %s".match"
fn match() -> Parser(Match) {
  exact(".match")
  |> trace("match")
}

/// ; Names and identifiers
/// ; identifier matches https://www.w3.org/TR/REC-xml-names/#NT-QName
/// ; name matches https://www.w3.org/TR/REC-xml-names/#NT-NCName but excludes U+FFFD and U+061C
/// identifier = [namespace ":"] name
fn identifier() -> Parser(Identifier) {
  pair(optional(left(namespace(), exact(":"))), name())
  |> map(fn(result) { ast.Identifier(result.0, result.1) })
  |> trace("identifier")
}

/// namespace  = name
fn namespace() -> Parser(Namespace) {
  name()
  |> trace("namespace")
}

/// name       = [bidi] name-start *name-char [bidi]
fn name() -> Parser(Name) {
  fn(in: String) {
    use bd1 <- bind(optional(bidi()), in)
    use name_start <- bind(name_start(), bd1.rest)
    use name_chars <- bind(zero_or_more(name_char()), name_start.rest)
    use bd2 <- bind(optional(bidi()), name_chars.rest)

    let name =
      bd1.value |> gleam_option.unwrap("")
      <> name_start.value
      <> name_chars.value |> joined
      <> bd2.value |> gleam_option.unwrap("")

    Ok(Parsed(name, bd2.rest))
  }
  |> trace("name")
}

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
fn name_start() -> Parser(NameStart) {
  choice([
    grapheme_in_range("A", "Z"),
    grapheme_in_range("a", "z"),
    exact("+"),
    exact("_"),
    grapheme_in_range("\u{A1}", "\u{61B}"),
    grapheme_in_range("\u{61D}", "\u{167F}"),
    grapheme_in_range("\u{1681}", "\u{1FFF}"),
    grapheme_in_range("\u{200B}", "\u{200D}"),
    grapheme_in_range("\u{2010}", "\u{2027}"),
    grapheme_in_range("\u{2030}", "\u{205E}"),
    grapheme_in_range("\u{2060}", "\u{2065}"),
    grapheme_in_range("\u{206A}", "\u{2FFF}"),
    grapheme_in_range("\u{3001}", "\u{D7FF}"),
    grapheme_in_range("\u{E000}", "\u{FDCF}"),
    grapheme_in_range("\u{FDF0}", "\u{FFFD}"),
    grapheme_in_range("\u{10000}", "\u{1FFFD}"),
    grapheme_in_range("\u{20000}", "\u{2FFFD}"),
    grapheme_in_range("\u{30000}", "\u{3FFFD}"),
    grapheme_in_range("\u{40000}", "\u{4FFFD}"),
    grapheme_in_range("\u{50000}", "\u{5FFFD}"),
    grapheme_in_range("\u{60000}", "\u{6FFFD}"),
    grapheme_in_range("\u{70000}", "\u{7FFFD}"),
    grapheme_in_range("\u{80000}", "\u{8FFFD}"),
    grapheme_in_range("\u{90000}", "\u{9FFFD}"),
    grapheme_in_range("\u{A0000}", "\u{AFFFD}"),
    grapheme_in_range("\u{B0000}", "\u{BFFFD}"),
    grapheme_in_range("\u{C0000}", "\u{CFFFD}"),
    grapheme_in_range("\u{D0000}", "\u{DFFFD}"),
    grapheme_in_range("\u{E0000}", "\u{EFFFD}"),
    grapheme_in_range("\u{F0000}", "\u{FFFFD}"),
    grapheme_in_range("\u{100000}", "\u{10FFFD}"),
  ])
}

/// name-char  = name-start / DIGIT / "-" / "."
fn name_char() -> Parser(NameChar) {
  choice([
    name_start(),
    grapheme_from(digits0_9 <> "-."),
  ])
}

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
fn simple_start_char() -> Parser(SimpleStartChar) {
  choice([
    grapheme_in_range("\u{01}", "\u{08}"),
    grapheme_in_range("\u{0B}", "\u{0C}"),
    grapheme_in_range("\u{0E}", "\u{1F}"),
    grapheme_in_range("\u{21}", "\u{2D}"),
    grapheme_in_range("\u{2F}", "\u{5B}"),
    grapheme_in_range("\u{5D}", "\u{7A}"),
    grapheme_from("\u{7C}"),
    grapheme_in_range("\u{7E}", "\u{2FFF}"),
    grapheme_in_range("\u{3001}", "\u{10FFFF}"),
  ])
}

/// text-char         = %x01-5B        ; omit NULL (%x00) and \ (%x5C)
///                   / %x5D-7A        ; omit { (%x7B)
///                   / %x7C           ; omit } (%x7D)
///                   / %x7E-10FFFF
fn text_char() -> Parser(TextChar) {
  choice([
    grapheme_in_range("\u{01}", "\u{5B}"),
    grapheme_in_range("\u{5D}", "\u{7A}"),
    grapheme_from("\u{7C}"),
    grapheme_in_range("\u{7E}", "\u{10FFFF}"),
  ])
}

/// quoted-char       = %x01-5B        ; omit NULL (%x00) and \ (%x5C)
///                   / %x5D-7B        ; omit | (%x7C)
///                   / %x7D-10FFFF
fn quoted_char() -> Parser(QuotedChar) {
  choice([
    grapheme_in_range("\u{01}", "\u{5B}"),
    grapheme_in_range("\u{5D}", "\u{7B}"),
    grapheme_in_range("\u{7D}", "\u{10FFFF}"),
  ])
}

/// ; Character escapes
/// escaped-char = backslash ( backslash / "{" / "|" / "}" )
fn escaped_char() -> Parser(EscapedChar) {
  right(exact("\\"), grapheme_from("\\{|}"))
}

/// backslash    = %x5C ; U+005C REVERSE SOLIDUS "\"
/// [unused]
///
/// ; Required whitespace
/// s = *bidi ws o
fn required_whitespace() -> Parser(RequiredWhitespace) {
  fn(in: String) {
    use bidis <- bind(zero_or_more(bidi()), in)
    use ws <- bind(whitespace(), bidis.rest)
    use o <- bind(optional_whitespace(), ws.rest)

    let body = bidis.value |> joined <> ws.value <> o.value

    Ok(Parsed(body, o.rest))
  }
}

/// ; Optional whitespace
/// o = *(ws / bidi)
fn optional_whitespace() -> Parser(OptionalWhitespace) {
  zero_or_more(
    choice([
      whitespace(),
      bidi(),
    ]),
  )
  |> map(joined)
}

/// ; Bidirectional marks and isolates
/// ; ALM / LRM / RLM / LRI, RLI, FSI & PDI
/// bidi = %x061C / %x200E / %x200F / %x2066-2069
fn bidi() -> Parser(Bidi) {
  grapheme_from("\u{061C}\u{200E}\u{200F}\u{2066}\u{2067}\u{2068}\u{2069}")
}

/// ; Whitespace characters
/// ws = SP / HTAB / CR / LF / %x3000
fn whitespace() -> Parser(Whitespace) {
  grapheme_from(" \t\r\n\u{3000}")
}

/// Helpers...
fn exact(value: String) -> Parser(String) {
  fn(in: String) {
    case in |> string.starts_with(value) {
      True -> Ok(Parsed(value, in |> string.drop_start(string.length(value))))
      False -> Error(NoMatch)
    }
  }
}

fn zero_or_more(parser: Parser(a)) -> Parser(List(a)) {
  fn(in: String) { zero_or_more_impl(parser, in, []) }
}

fn zero_or_more_impl(parser: Parser(a), in: String, acc: List(a)) {
  case parser(in) {
    Ok(Parsed(value, rest)) ->
      case rest == in {
        True -> Error(NoMatch)
        False -> zero_or_more_impl(parser, rest, [value, ..acc])
      }
    Error(_) -> Ok(Parsed(list.reverse(acc), in))
  }
}

fn one_or_more(parser: Parser(a)) -> Parser(List(a)) {
  fn(in: String) {
    case parser(in) {
      Ok(Parsed(value, rest)) ->
        case rest == in {
          True -> Error(NoMatch)
          False ->
            case zero_or_more(parser)(rest) {
              Ok(Parsed(values, final_rest)) ->
                Ok(Parsed([value, ..values], final_rest))
              Error(err) -> Error(err)
            }
        }
      Error(err) -> Error(err)
    }
  }
}

fn choice(parsers: List(Parser(out))) -> Parser(out) {
  fn(in: String) {
    case parsers {
      [] -> Error(NoMatch)

      [p, ..rest] ->
        case p(in) {
          Ok(result) -> Ok(result)
          Error(_) -> choice(rest)(in)
        }
    }
  }
}

fn optional(parser: Parser(in)) -> Parser(GleamOption(in)) {
  choice([
    parser |> map(gleam_option.Some),
    succeed(gleam_option.None),
  ])
}

fn pair(first: Parser(in1), second: Parser(in2)) -> Parser(#(in1, in2)) {
  fn(in: String) {
    use parsed1 <- bind(first, in)
    use parsed2 <- bind(second, parsed1.rest)

    let parsed = Parsed(#(parsed1.value, parsed2.value), parsed2.rest)
    Ok(parsed)
  }
}

fn left(first: Parser(in1), second: Parser(in2)) -> Parser(in1) {
  pair(first, second)
  |> map(fn(pair) {
    let #(left, _) = pair
    left
  })
}

fn right(first: Parser(in1), second: Parser(in2)) -> Parser(in2) {
  pair(first, second)
  |> map(fn(pair) {
    let #(_, right) = pair
    right
  })
}

fn triple(
  first: Parser(in1),
  second: Parser(in2),
  third: Parser(in3),
) -> Parser(#(in1, in2, in3)) {
  fn(in: String) {
    use parsed1 <- bind(first, in)
    use parsed2 <- bind(second, parsed1.rest)
    use parsed3 <- bind(third, parsed2.rest)

    let parsed =
      Parsed(#(parsed1.value, parsed2.value, parsed3.value), parsed3.rest)
    Ok(parsed)
  }
}

fn grapheme_from(graphemes: String) -> Parser(String) {
  fn(in: String) {
    case string.pop_grapheme(in) {
      Ok(#(first, rest)) -> {
        let grapheme_codepoints = string.to_utf_codepoints(graphemes)
        let first_codepoints = string.to_utf_codepoints(first)

        let contains =
          first_codepoints
          |> list.all(fn(cp) { grapheme_codepoints |> list.contains(cp) })

        case contains {
          True -> Ok(Parsed(first, rest))
          False -> Error(NoMatch)
        }
      }
      Error(_) -> Error(NoMatch)
    }
  }
}

fn grapheme_in_range(from: String, to: String) -> Parser(String) {
  fn(in: String) {
    case string.pop_grapheme(in) {
      Ok(#(first, rest)) -> {
        let from_compare = string.compare(from, first)
        let to_compare = string.compare(first, to)
        case from_compare, to_compare {
          order.Lt, order.Lt
          | order.Lt, order.Eq
          | order.Eq, order.Lt
          | order.Eq, order.Eq
          -> Ok(Parsed(first, rest))
          _, _ -> Error(NoMatch)
        }
      }
      Error(_) -> Error(NoMatch)
    }
  }
}

fn joined(strings: List(String)) -> String {
  strings |> string.join("")
}

fn map(parser: Parser(in), f: fn(in) -> out) -> Parser(out) {
  parser
  |> and_then(fn(value) { succeed(f(value)) })
}

fn and_then(parser: Parser(in), next: fn(in) -> Parser(out)) -> Parser(out) {
  fn(in: String) {
    use parsed <- bind(parser, in)
    next(parsed.value)(parsed.rest)
  }
}

fn bind(
  parser: Parser(in),
  in: String,
  next: fn(Parsed(in)) -> Result(out, ParseError),
) -> Result(out, ParseError) {
  case parser(in) {
    Ok(parsed) -> next(parsed)
    Error(error) -> Error(error)
  }
}

fn succeed(value: a) -> Parser(a) {
  fn(in: String) { Ok(Parsed(value, in)) }
}

fn empty() -> Parser(Nil) {
  fn(in: String) {
    case string.is_empty(in) {
      True -> Ok(Parsed(Nil, in))
      False -> Error(NoMatch)
    }
  }
}

fn lookahead(parser: Parser(a)) -> Parser(a) {
  fn(input: String) {
    case parser(input) {
      Ok(parsed) -> Ok(Parsed(parsed.value, input))
      Error(error) -> Error(error)
    }
  }
}

fn take_until(stop: Parser(a)) -> Parser(String) {
  fn(input: String) { take_until_loop(stop, input, []) }
}

fn take_until_loop(
  stop: Parser(a),
  input: String,
  acc: List(String),
) -> Result(Parsed(String), ParseError) {
  case stop(input) {
    Ok(_) -> Ok(Parsed(joined(list.reverse(acc)), input))

    Error(_) ->
      case string.pop_grapheme(input) {
        Ok(#(grapheme, rest)) -> take_until_loop(stop, rest, [grapheme, ..acc])
        Error(_) -> Ok(Parsed(joined(list.reverse(acc)), ""))
      }
  }
}

// ------------------------------------
import gleam/io

const trace_enabled = False

fn trace(parser: Parser(a), name: String) -> Parser(a) {
  case trace_enabled {
    True -> parser |> do_trace(name)
    False -> parser
  }
}

fn do_trace(parser: Parser(a), name: String) -> Parser(a) {
  fn(input) {
    io.println(">> " <> name)
    let result = parser(input)

    case result {
      Ok(value) -> {
        io.println("<< " <> name <> " ... ")
        io.println(" ... '" <> value.rest <> "'")
        Ok(value)
      }

      Error(error) -> {
        io.println("<! " <> name)
        io.println(" ... '" <> input <> "'")
        Error(error)
      }
    }
  }
}
// ------------------------------------
