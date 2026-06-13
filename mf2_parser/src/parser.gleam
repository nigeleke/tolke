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
import gleam/result
import gleam/string

import parsley.{type ParseError, type Parser} as p

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
        False -> Error(p.UnconsumedInput(parsed.rest))
      }
    Error(error) -> Error(error)
  }
}

// resource          = o resource-entry *(o resource-entry)
fn resource() -> Parser(Resource) {
  p.pair(
    p.right(optional_whitespace(), resource_entry()),
    p.zero_or_more(p.right(optional_whitespace(), resource_entry())),
  )
  |> p.map(fn(result) {
    let #(head, tail) = result
    ast.Resource([head, ..tail])
  })
  |> p.trace("resource")
}

// resource-entry    = resource-start message
fn resource_entry() -> Parser(ResourceEntry) {
  p.pair(resource_start(), resource_message())
  |> p.map(fn(result) { ast.ResourceEntry(result.0, result.1) })
  |> p.trace("resource-entry")
}

fn resource_message() -> Parser(Message) {
  p.take_until(next_resource_entry())
  |> p.and_then(fn(src) {
    fn(rest) {
      case parse(src) {
        Ok(message) -> Ok(p.Parsed(message, rest))
        Error(error) -> Error(error)
      }
    }
  })
}

// [lookahead] resource-entry    = resource-start message
fn next_resource_entry() -> Parser(Nil) {
  p.lookahead(resource_start())
  |> p.map(fn(_) { Nil })
}

// resource-start    = resource-name o ":="
fn resource_start() -> Parser(ResourceName) {
  p.triple(resource_name(), optional_whitespace(), p.exact(":="))
  |> p.map(fn(result) { result.0 })
}

// resource-name     = name
fn resource_name() -> Parser(ResourceName) {
  name()
  |> p.trace("resource-name")
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
        False -> Error(p.UnconsumedInput(parsed.rest))
      }
    Error(error) -> Error(error)
  }
}

/// message           = simple-message / complex-message
fn message() -> Parser(Message) {
  p.choice([
    simple_message() |> p.map(ast.Simple),
    complex_message() |> p.map(ast.Complex),
  ])
  |> p.trace("message")
}

/// simple-message = o [simple-start pattern]
fn simple_message() -> Parser(SimpleMessage) {
  p.pair(optional_whitespace(), simple_message_body())
  |> p.map(fn(result) { ast.SimpleMessage(result.0, result.1) })
  |> p.trace("simple-message")
}

fn simple_message_body() -> Parser(List(MessageElement)) {
  p.choice([
    p.pair(simple_start(), pattern())
      |> p.map(fn(result) { [result.0, ..result.1] }),

    p.empty()
      |> p.map(fn(_) { [] }),
  ])
}

/// simple-start      = simple-start-char / escaped-char / placeholder
fn simple_start() -> Parser(SimpleStart) {
  p.choice([
    simple_start_char() |> p.map(ast.Text),
    escaped_char() |> p.map(ast.Escaped),
    placeholder() |> p.map(ast.Placeholder),
  ])
}

/// pattern           = *(text-char / escaped-char / placeholder)
fn pattern() -> Parser(Pattern) {
  p.zero_or_more(
    p.choice([
      text_char() |> p.map(ast.Text),
      escaped_char() |> p.map(ast.Escaped),
      placeholder() |> p.map(ast.Placeholder),
    ]),
  )
  |> p.trace("pattern")
}

/// placeholder       = expression / markup
fn placeholder() -> Parser(Placeholder) {
  p.choice([
    expression() |> p.map(ast.PlaceholderExpression),
    markup() |> p.map(ast.PlaceholderMarkup),
  ])
  |> p.trace("placeholder")
}

/// complex-message   = o *(declaration o) complex-body o
fn complex_message() -> Parser(ComplexMessage) {
  p.pair(
    p.right(
      optional_whitespace(),
      p.zero_or_more(p.left(declaration(), optional_whitespace())),
    ),
    p.left(complex_body(), optional_whitespace()),
  )
  |> p.map(fn(result) {
    let #(declarations, body) = result
    ast.ComplexMessage(declarations, body)
  })
  |> p.trace("complex-message")
}

/// declaration       = input-declaration / local-declaration
fn declaration() -> Parser(Declaration) {
  p.choice([
    input_declaration() |> p.map(ast.DeclarationInput),
    local_declaration() |> p.map(ast.DeclarationLocal),
  ])
  |> p.trace("declaration")
}

/// complex-body      = quoted-pattern / matcher
fn complex_body() -> Parser(ComplexBody) {
  p.choice([
    quoted_pattern() |> p.map(ast.ComplexBodyQuotedPattern),
    matcher() |> p.map(ast.ComplexBodyMatcher),
  ])
  |> p.trace("complex-body")
}

/// input-declaration = input o variable-expression
fn input_declaration() -> Parser(InputDeclaration) {
  p.triple(input(), optional_whitespace(), variable_expression())
  |> p.map(fn(result) { ast.InputDeclaration(result.2) })
  |> p.trace("input-declaration")
}

/// local-declaration = local s variable o "=" o expression
fn local_declaration() -> Parser(LocalDeclaration) {
  fn(in: String) {
    use local <- p.bind(local(), in)
    use s <- p.bind(required_whitespace(), local.rest)
    use variable <- p.bind(variable(), s.rest)
    use o0 <- p.bind(optional_whitespace(), variable.rest)
    use equal <- p.bind(p.exact("="), o0.rest)
    use o1 <- p.bind(optional_whitespace(), equal.rest)
    use expression <- p.bind(expression(), o1.rest)

    let body = ast.LocalDeclaration(variable.value, expression.value)

    Ok(p.Parsed(body, expression.rest))
  }
  |> p.trace("local-declaration")
}

/// quoted-pattern    = "{{" pattern "}}"
fn quoted_pattern() -> Parser(QuotedPattern) {
  p.triple(p.exact("{{"), pattern(), p.exact("}}"))
  |> p.map(fn(result) { ast.QuotedPattern(result.1) })
  |> p.trace("quoted-pattern")
}

/// matcher           = match-statement s variant *(o variant)
fn matcher() -> Parser(Matcher) {
  fn(in: String) {
    use statement <- p.bind(match_statement(), in)
    use s <- p.bind(required_whitespace(), statement.rest)
    use variant0 <- p.bind(variant(), s.rest)
    use variants <- p.bind(
      p.zero_or_more(p.right(optional_whitespace(), variant())),
      variant0.rest,
    )

    let body = ast.Matcher(statement.value, variant0.value, variants.value)

    Ok(p.Parsed(body, variants.rest))
  }
  |> p.trace("matcher")
}

/// match-statement   = match 1*(s selector)
fn match_statement() -> Parser(MatchStatement) {
  p.right(match(), p.one_or_more(p.right(required_whitespace(), selector())))
  |> p.map(ast.MatchStatement)
}

/// selector          = variable
fn selector() -> Parser(Selector) {
  variable()
  |> p.map(ast.Selector)
  |> p.trace("selector")
}

/// variant           = key *(s key) o quoted-pattern
fn variant() -> Parser(Variant) {
  p.triple(
    key(),
    p.zero_or_more(p.right(required_whitespace(), key())),
    p.right(optional_whitespace(), quoted_pattern()),
  )
  |> p.map(fn(result) { ast.Variant(result.0, result.1, result.2) })
  |> p.trace("variant")
}

/// key               = literal / "*"
fn key() -> Parser(Key) {
  p.choice([
    literal() |> p.map(ast.KeyLiteral),
    p.exact("*") |> p.map(fn(_) { ast.KeyOther }),
  ])
  |> p.trace("key")
}

/// ; Expressions
/// expression          = literal-expression
///                     / variable-expression
///                     / function-expression
fn expression() -> Parser(Expression) {
  p.choice([
    literal_expression() |> p.map(ast.ExpressionLiteral),
    variable_expression() |> p.map(ast.ExpressionVariable),
    function_expression() |> p.map(ast.ExpressionFunction),
  ])
  |> p.trace("expression")
}

/// literal-expression  = "{" o literal [s function] *(s attribute) o "}"
fn literal_expression() -> Parser(LiteralExpression) {
  fn(in: String) {
    use open_brace <- p.bind(p.exact("{"), in)
    use o0 <- p.bind(optional_whitespace(), open_brace.rest)
    use literal <- p.bind(literal(), o0.rest)
    use function <- p.bind(
      p.optional(p.right(required_whitespace(), function())),
      literal.rest,
    )
    use attributes <- p.bind(
      p.zero_or_more(p.right(required_whitespace(), attribute())),
      function.rest,
    )
    use o1 <- p.bind(optional_whitespace(), attributes.rest)
    use close_brace <- p.bind(p.exact("}"), o1.rest)

    let body =
      ast.LiteralExpression(literal.value, function.value, attributes.value)

    Ok(p.Parsed(body, close_brace.rest))
  }
  |> p.trace("literal-expression")
}

/// variable-expression = "{" o variable [s function] *(s attribute) o "}"
fn variable_expression() -> Parser(VariableExpression) {
  fn(in: String) {
    use open_brace <- p.bind(p.exact("{"), in)
    use o0 <- p.bind(optional_whitespace(), open_brace.rest)
    use variable <- p.bind(variable(), o0.rest)
    use function <- p.bind(
      p.optional(p.right(required_whitespace(), function())),
      variable.rest,
    )
    use attributes <- p.bind(
      p.zero_or_more(p.right(required_whitespace(), attribute())),
      function.rest,
    )
    use o1 <- p.bind(optional_whitespace(), attributes.rest)
    use close_brace <- p.bind(p.exact("}"), o1.rest)

    let body =
      ast.VariableExpression(variable.value, function.value, attributes.value)

    Ok(p.Parsed(body, close_brace.rest))
  }
  |> p.trace("variable-expression")
}

/// function-expression = "{" o function *(s attribute) o "}"
fn function_expression() -> Parser(FunctionExpression) {
  fn(in: String) {
    use open_brace <- p.bind(p.exact("{"), in)
    use o0 <- p.bind(optional_whitespace(), open_brace.rest)
    use function <- p.bind(function(), o0.rest)
    use attributes <- p.bind(
      p.zero_or_more(p.right(required_whitespace(), attribute())),
      function.rest,
    )
    use o1 <- p.bind(optional_whitespace(), attributes.rest)
    use close_brace <- p.bind(p.exact("}"), o1.rest)

    let body = ast.FunctionExpression(function.value, attributes.value)

    Ok(p.Parsed(body, close_brace.rest))
  }
  |> p.trace("function-expression")
}

/// markup = "{" o "#" identifier *(s option) *(s attribute) o ["/"] "}"  ; open and standalone
///        / "{" o "/" identifier *(s option) *(s attribute) o "}"  ; close
/// Warning: Parser is order dependent & relies on longest parse wins.
fn markup() -> Parser(Markup) {
  p.choice([
    markup_open_or_standalone(),
    markup_close(),
  ])
  |> p.trace("markup")
}

fn markup_open_or_standalone() -> Parser(Markup) {
  markup_common(
    p.exact("#"),
    p.optional(p.exact("/")),
    fn(identifier, options, attributes, standalone) {
      case standalone {
        True -> ast.MarkupStandalone(identifier, options, attributes)
        False -> ast.MarkupOpen(identifier, options, attributes)
      }
    },
  )
  |> p.trace("markup-open-or-standalone")
}

fn markup_close() -> Parser(Markup) {
  markup_common(
    p.exact("/"),
    p.succeed(gleam_option.None),
    fn(identifier, options, attributes, _suffix) {
      ast.MarkupClose(identifier, options, attributes)
    },
  )
  |> p.trace("markup-close")
}

fn markup_common(
  prefix: Parser(String),
  suffix: Parser(GleamOption(String)),
  build: fn(Identifier, List(Option), List(Attribute), Bool) -> Markup,
) -> Parser(Markup) {
  fn(in: String) {
    use open_brace <- p.bind(p.exact("{"), in)
    use o0 <- p.bind(optional_whitespace(), open_brace.rest)
    use prefix <- p.bind(prefix, o0.rest)
    use identifier <- p.bind(identifier(), prefix.rest)
    use options <- p.bind(
      p.zero_or_more(p.right(required_whitespace(), option())),
      identifier.rest,
    )
    use attributes <- p.bind(
      p.zero_or_more(p.right(required_whitespace(), attribute())),
      options.rest,
    )
    use o1 <- p.bind(optional_whitespace(), attributes.rest)
    use suffix <- p.bind(suffix, o1.rest)
    use close_brace <- p.bind(p.exact("}"), suffix.rest)

    Ok(p.Parsed(
      build(
        identifier.value,
        options.value,
        attributes.value,
        gleam_option.is_some(suffix.value),
      ),
      close_brace.rest,
    ))
  }
  |> p.trace("markup-common")
}

/// ; Expression and literal parts
/// function       = ":" identifier *(s option)
fn function() -> Parser(Function) {
  p.triple(
    p.exact(":"),
    identifier(),
    p.zero_or_more(p.right(required_whitespace(), option())),
  )
  |> p.map(fn(result) { ast.Function(result.1, result.2) })
  |> p.trace("function")
}

/// option         = identifier o "=" o (literal / variable)
fn option() -> Parser(Option) {
  fn(in: String) {
    use identifier <- p.bind(identifier(), in)
    use o0 <- p.bind(optional_whitespace(), identifier.rest)
    use equal <- p.bind(p.exact("="), o0.rest)
    use o1 <- p.bind(optional_whitespace(), equal.rest)
    use element <- p.bind(
      p.choice([
        literal() |> p.map(ast.OptionElementLiteral),
        variable() |> p.map(ast.OptionElementVariable),
      ]),
      o1.rest,
    )

    let body = ast.Option(identifier.value, element.value)

    Ok(p.Parsed(body, element.rest))
  }
  |> p.trace("option")
}

/// attribute      = "@" identifier [o "=" o literal]
fn attribute() -> Parser(Attribute) {
  p.right(
    p.exact("@"),
    p.choice([
      p.pair(identifier(), assign_literal())
        |> p.map(fn(result) { ast.ValueAttribute(result.0, result.1) }),
      identifier() |> p.map(ast.FlagAttribute),
    ]),
  )
}

fn assign_literal() -> Parser(Literal) {
  fn(in: String) {
    use o0 <- p.bind(optional_whitespace(), in)
    use equal <- p.bind(p.exact("="), o0.rest)
    use o1 <- p.bind(optional_whitespace(), equal.rest)
    use literal <- p.bind(literal(), o1.rest)

    Ok(literal)
  }
}

/// variable       = "$" name
fn variable() -> Parser(Variable) {
  p.right(p.exact("$"), name())
  |> p.map(ast.Variable)
  |> p.trace("variable")
}

/// literal          = quoted-literal / unquoted-literal
fn literal() -> Parser(Literal) {
  p.choice([
    quoted_literal() |> p.map(ast.LiteralQuoted),
    unquoted_literal() |> p.map(ast.LiteralUnquoted),
  ])
  |> p.trace("literal")
}

/// quoted-literal   = "|" *(quoted-char / escaped-char) "|"
fn quoted_literal() -> Parser(QuotedLiteral) {
  p.triple(
    p.exact("|"),
    p.zero_or_more(p.choice([quoted_char(), escaped_char()]))
      |> p.map(p.joined),
    p.exact("|"),
  )
  |> p.map(fn(result) { result.1 })
  |> p.trace("quoted-literal")
}

/// unquoted-literal = 1*name-char
fn unquoted_literal() -> Parser(UnquotedLiteral) {
  p.one_or_more(name_char())
  |> p.map(p.joined)
  |> p.map(ast.UnquotedLiteral)
  |> p.trace("unquoted-literal")
}

/// ; Keywords; Note that these are case-sensitive
/// input = %s".input"
fn input() -> Parser(Input) {
  p.exact(".input")
  |> p.trace("input")
}

/// local = %s".local"
fn local() -> Parser(Local) {
  p.exact(".local")
  |> p.trace("local")
}

/// match = %s".match"
fn match() -> Parser(Match) {
  p.exact(".match")
  |> p.trace("match")
}

/// ; Names and identifiers
/// ; identifier matches https://www.w3.org/TR/REC-xml-names/#NT-QName
/// ; name matches https://www.w3.org/TR/REC-xml-names/#NT-NCName but excludes U+FFFD and U+061C
/// identifier = [namespace ":"] name
fn identifier() -> Parser(Identifier) {
  p.pair(p.optional(p.left(namespace(), p.exact(":"))), name())
  |> p.map(fn(result) { ast.Identifier(result.0, result.1) })
  |> p.trace("identifier")
}

/// namespace  = name
fn namespace() -> Parser(Namespace) {
  name()
  |> p.trace("namespace")
}

/// name       = [bidi] name-start *name-char [bidi]
fn name() -> Parser(Name) {
  fn(in: String) {
    use bd1 <- p.bind(p.optional(bidi()), in)
    use name_start <- p.bind(name_start(), bd1.rest)
    use name_chars <- p.bind(p.zero_or_more(name_char()), name_start.rest)
    use bd2 <- p.bind(p.optional(bidi()), name_chars.rest)

    let name =
      bd1.value |> gleam_option.unwrap("")
      <> name_start.value
      <> name_chars.value |> p.joined
      <> bd2.value |> gleam_option.unwrap("")

    Ok(p.Parsed(name, bd2.rest))
  }
  |> p.trace("name")
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
  p.choice([
    p.grapheme_in_range("A", "Z"),
    p.grapheme_in_range("a", "z"),
    p.exact("+"),
    p.exact("_"),
    p.grapheme_in_range("\u{A1}", "\u{61B}"),
    p.grapheme_in_range("\u{61D}", "\u{167F}"),
    p.grapheme_in_range("\u{1681}", "\u{1FFF}"),
    p.grapheme_in_range("\u{200B}", "\u{200D}"),
    p.grapheme_in_range("\u{2010}", "\u{2027}"),
    p.grapheme_in_range("\u{2030}", "\u{205E}"),
    p.grapheme_in_range("\u{2060}", "\u{2065}"),
    p.grapheme_in_range("\u{206A}", "\u{2FFF}"),
    p.grapheme_in_range("\u{3001}", "\u{D7FF}"),
    p.grapheme_in_range("\u{E000}", "\u{FDCF}"),
    p.grapheme_in_range("\u{FDF0}", "\u{FFFD}"),
    p.grapheme_in_range("\u{10000}", "\u{1FFFD}"),
    p.grapheme_in_range("\u{20000}", "\u{2FFFD}"),
    p.grapheme_in_range("\u{30000}", "\u{3FFFD}"),
    p.grapheme_in_range("\u{40000}", "\u{4FFFD}"),
    p.grapheme_in_range("\u{50000}", "\u{5FFFD}"),
    p.grapheme_in_range("\u{60000}", "\u{6FFFD}"),
    p.grapheme_in_range("\u{70000}", "\u{7FFFD}"),
    p.grapheme_in_range("\u{80000}", "\u{8FFFD}"),
    p.grapheme_in_range("\u{90000}", "\u{9FFFD}"),
    p.grapheme_in_range("\u{A0000}", "\u{AFFFD}"),
    p.grapheme_in_range("\u{B0000}", "\u{BFFFD}"),
    p.grapheme_in_range("\u{C0000}", "\u{CFFFD}"),
    p.grapheme_in_range("\u{D0000}", "\u{DFFFD}"),
    p.grapheme_in_range("\u{E0000}", "\u{EFFFD}"),
    p.grapheme_in_range("\u{F0000}", "\u{FFFFD}"),
    p.grapheme_in_range("\u{100000}", "\u{10FFFD}"),
  ])
}

/// name-char  = name-start / DIGIT / "-" / "."
fn name_char() -> Parser(NameChar) {
  p.choice([
    name_start(),
    p.grapheme_from(digits0_9 <> "-."),
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
  p.choice([
    p.grapheme_in_range("\u{01}", "\u{08}"),
    p.grapheme_in_range("\u{0B}", "\u{0C}"),
    p.grapheme_in_range("\u{0E}", "\u{1F}"),
    p.grapheme_in_range("\u{21}", "\u{2D}"),
    p.grapheme_in_range("\u{2F}", "\u{5B}"),
    p.grapheme_in_range("\u{5D}", "\u{7A}"),
    p.grapheme_from("\u{7C}"),
    p.grapheme_in_range("\u{7E}", "\u{2FFF}"),
    p.grapheme_in_range("\u{3001}", "\u{10FFFF}"),
  ])
}

/// text-char         = %x01-5B        ; omit NULL (%x00) and \ (%x5C)
///                   / %x5D-7A        ; omit { (%x7B)
///                   / %x7C           ; omit } (%x7D)
///                   / %x7E-10FFFF
fn text_char() -> Parser(TextChar) {
  p.choice([
    p.grapheme_in_range("\u{01}", "\u{5B}"),
    p.grapheme_in_range("\u{5D}", "\u{7A}"),
    p.grapheme_from("\u{7C}"),
    p.grapheme_in_range("\u{7E}", "\u{10FFFF}"),
  ])
}

/// quoted-char       = %x01-5B        ; omit NULL (%x00) and \ (%x5C)
///                   / %x5D-7B        ; omit | (%x7C)
///                   / %x7D-10FFFF
fn quoted_char() -> Parser(QuotedChar) {
  p.choice([
    p.grapheme_in_range("\u{01}", "\u{5B}"),
    p.grapheme_in_range("\u{5D}", "\u{7B}"),
    p.grapheme_in_range("\u{7D}", "\u{10FFFF}"),
  ])
}

/// ; Character escapes
/// escaped-char = backslash ( backslash / "{" / "|" / "}" )
fn escaped_char() -> Parser(EscapedChar) {
  p.right(p.exact("\\"), p.grapheme_from("\\{|}"))
}

/// backslash    = %x5C ; U+005C REVERSE SOLIDUS "\"
/// [unused]
///
/// ; Required whitespace
/// s = *bidi ws o
fn required_whitespace() -> Parser(RequiredWhitespace) {
  fn(in: String) {
    use bidis <- p.bind(p.zero_or_more(bidi()), in)
    use ws <- p.bind(whitespace(), bidis.rest)
    use o <- p.bind(optional_whitespace(), ws.rest)

    let body = bidis.value |> p.joined <> ws.value <> o.value

    Ok(p.Parsed(body, o.rest))
  }
}

/// ; Optional whitespace
/// o = *(ws / bidi)
fn optional_whitespace() -> Parser(OptionalWhitespace) {
  p.zero_or_more(
    p.choice([
      whitespace(),
      bidi(),
    ]),
  )
  |> p.map(p.joined)
}

/// ; Bidirectional marks and isolates
/// ; ALM / LRM / RLM / LRI, RLI, FSI & PDI
/// bidi = %x061C / %x200E / %x200F / %x2066-2069
fn bidi() -> Parser(Bidi) {
  p.grapheme_from("\u{061C}\u{200E}\u{200F}\u{2066}\u{2067}\u{2068}\u{2069}")
}

/// ; Whitespace characters
/// ws = SP / HTAB / CR / LF / %x3000
fn whitespace() -> Parser(Whitespace) {
  p.grapheme_from(" \t\r\n\u{3000}")
}
