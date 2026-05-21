/// https://www.unicode.org/reports/tr35/tr35-73/tr35-messageFormat.html#complete-abnf
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
import gleam/list
import gleam/option.{type Option as GleamOption} as gleam_option
import gleam/order
import gleam/string

import mf2/parser/ast.{
  type Attribute, type Bidi, type ComplexBody, type ComplexMessage,
  type ContentChar, type Declaration, type EscapedChar, type Expression,
  type Function, type FunctionExpression, type Identifier, type Input,
  type InputDeclaration, type Key, type Literal, type LiteralExpression,
  type Local, type LocalDeclaration, type Markup, type Match,
  type MatchStatement, type Matcher, type Message, type Name, type NameChar,
  type NameStart, type Namespace, type NumberLiteral, type Option,
  type OptionalWhitespace, type Pattern, type Placeholder, type QuotedChar,
  type QuotedLiteral, type QuotedPattern, type RequiredWhitespace, type Selector,
  type SimpleMessage, type SimpleStart, type SimpleStartChar, type TextChar,
  type UnquotedLiteral, type Variable, type VariableExpression, type Variant,
  type Whitespace,
}

const digits0_9 = "0123456789"

const digits1_9 = "123456789"

/// `Parsed` contains a successfully parsed `a`, together with any remaining
/// non-parsed input.
type Parsed(a) {
  Parsed(value: a, rest: String)
}

pub type ParseError =
  Nil

/// The `Parser` is a function that takes an input String and, if a match
/// is found, returns the `Parsed(out)`.
/// If no match is found then a Error(Nil) is returned.
pub type Parser(out) =
  fn(String) -> Result(Parsed(out), ParseError)

/// Parse into a single mf2 message body.
pub fn parse(in: String) -> Result(Message, ParseError) {
  case message()(in) {
    Ok(parsed) ->
      case string.is_empty(parsed.rest) {
        True -> Ok(parsed.value)
        False -> Error(Nil)
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
  pair(optional_whitespace(), optional(pair(simple_start(), pattern())))
  |> map(fn(result) { ast.SimpleMessage(result.0, result.1) })
  |> trace("simple-message")
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

/// quoted-pattern    = o "{{" pattern "}}"
fn quoted_pattern() -> Parser(QuotedPattern) {
  right(optional_whitespace(), triple(exact("{{"), pattern(), exact("}}")))
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

/// variant           = key *(s key) quoted-pattern
fn variant() -> Parser(Variant) {
  triple(
    key(),
    zero_or_more(right(required_whitespace(), key())),
    quoted_pattern(),
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
  markup_common(exact("#"), optional(exact("/")), ast.MarkupStandalone)
  |> trace("markup-open-or-standalone")
}

fn markup_close() -> Parser(Markup) {
  markup_common(exact("/"), succeed(gleam_option.None), ast.MarkupClose)
  |> trace("markup-close")
}

fn markup_common(
  prefix: Parser(String),
  suffix: Parser(GleamOption(String)),
  build: fn(Identifier, List(Option), List(Attribute)) -> Markup,
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
      build(identifier.value, options.value, attributes.value),
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

/// unquoted-literal = name / number-literal
fn unquoted_literal() -> Parser(UnquotedLiteral) {
  choice([
    name() |> map(ast.UnquotedLiteralName),
    number_literal() |> map(ast.UnquotedLiteralNumber),
  ])
  |> trace("unquoted-literal")
}

/// ; number-literal matches JSON number (https://www.rfc-editor.org/rfc/rfc8259#section-6)
/// number-literal   = ["-"] (%x30 / (%x31-39 *DIGIT)) ["." 1*DIGIT] [%i"e" ["-" / "+"] 1*DIGIT]
fn number_literal() -> Parser(NumberLiteral) {
  fn(in: String) {
    use minus <- bind(optional(exact("-")), in)
    use integral <- bind(
      choice([
        exact("0"),
        pair_joined(
          grapheme_from(digits1_9),
          zero_or_more(grapheme_from(digits0_9)) |> map(joined),
        ),
      ]),
      minus.rest,
    )
    use fractional <- bind(
      optional(pair_joined(
        exact("."),
        one_or_more(grapheme_from(digits0_9)) |> map(joined),
      )),
      integral.rest,
    )
    use exponential <- bind(
      optional(triple_joined(
        grapheme_from("eE"),
        optional(grapheme_from("+-")) |> map(gleam_option.unwrap(_, "")),
        one_or_more(grapheme_from(digits0_9)) |> map(joined),
      )),
      fractional.rest,
    )

    Ok(Parsed(
      minus.value |> gleam_option.unwrap("")
        <> integral.value
        <> fractional.value |> gleam_option.unwrap("")
        <> exponential.value |> gleam_option.unwrap(""),
      exponential.rest,
    ))
  }
  |> trace("number-literal")
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

/// name-start = ALPHA / "_"
///            / %xC0-D6 / %xD8-F6 / %xF8-2FF
///            / %x370-37D / %x37F-61B / %x61D-1FFF / %x200C-200D
///            / %x2070-218F / %x2C00-2FEF / %x3001-D7FF
///            / %xF900-FDCF / %xFDF0-FFFC / %x10000-EFFFF
fn name_start() -> Parser(NameStart) {
  choice([
    grapheme_in_range("A", "Z"),
    grapheme_in_range("a", "z"),
    exact("_"),
    grapheme_in_range("\u{C0}", "\u{D6}"),
    grapheme_in_range("\u{D8}", "\u{F6}"),
    grapheme_in_range("\u{F8}", "\u{2FF}"),
    grapheme_in_range("\u{370}", "\u{37D}"),
    grapheme_in_range("\u{37F}", "\u{61B}"),
    grapheme_in_range("\u{61D}", "\u{1FFF}"),
    grapheme_in_range("\u{200C}", "\u{200D}"),
    grapheme_in_range("\u{2070}", "\u{218F}"),
    grapheme_in_range("\u{2C00}", "\u{2FEF}"),
    grapheme_in_range("\u{3001}", "\u{D7FF}"),
    grapheme_in_range("\u{F900}", "\u{FDCF}"),
    grapheme_in_range("\u{FDF0}", "\u{FFFC}"),
    grapheme_in_range("\u{10000}", "\u{EFFFF}"),
  ])
}

/// name-char  = name-start / DIGIT / "-" / "."
///            / %xB7 / %x300-36F / %x203F-2040
fn name_char() -> Parser(NameChar) {
  choice([
    name_start(),
    grapheme_from(digits0_9 <> "-.\u{00B7}"),
    grapheme_in_range("\u{300}", "\u{36F}"),
    grapheme_in_range("\u{203f}", "\u{2040}"),
  ])
}

/// ; Restrictions on characters in various contexts
/// simple-start-char = content-char / "@" / "|"
fn simple_start_char() -> Parser(SimpleStartChar) {
  choice([content_char(), grapheme_from("@|")])
  |> trace("simple-start-char")
}

/// text-char         = content-char / ws / "." / "@" / "|"
fn text_char() -> Parser(TextChar) {
  choice([content_char(), whitespace(), grapheme_from(".@|")])
  |> trace("text-char")
}

/// quoted-char       = content-char / ws / "." / "@" / "{" / "}"
fn quoted_char() -> Parser(QuotedChar) {
  choice([content_char(), whitespace(), grapheme_from(".@{}")])
  |> trace("quoted-char")
}

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
fn content_char() -> Parser(ContentChar) {
  choice([
    grapheme_in_range("\u{01}", "\u{08}"),
    grapheme_in_range("\u{0B}", "\u{0C}"),
    grapheme_in_range("\u{0E}", "\u{1F}"),
    grapheme_in_range("\u{21}", "\u{2D}"),
    grapheme_in_range("\u{2F}", "\u{3F}"),
    grapheme_in_range("\u{41}", "\u{5B}"),
    grapheme_in_range("\u{5D}", "\u{7A}"),
    grapheme_in_range("\u{7E}", "\u{2FFF}"),
    grapheme_in_range("\u{3001}", "\u{D7FF}"),
    grapheme_in_range("\u{E000}", "\u{10FFFF}"),
  ])
  |> trace("content-char")
}

/// ; Character escapes
/// escaped-char = backslash ( backslash / "{" / "|" / "}" )
fn escaped_char() -> Parser(EscapedChar) {
  right(exact("\\"), grapheme_from("\\{|}"))
  |> trace("escaped-char")
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
  |> trace("required-whitespace")
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
  |> trace("optional-whitespace")
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
  |> trace("whitespace")
}

/// Helpers...
fn exact(value: String) -> Parser(String) {
  fn(in: String) {
    case in |> string.starts_with(value) {
      True -> Ok(Parsed(value, in |> string.drop_start(string.length(value))))
      False -> Error(Nil)
    }
  }
  |> trace("exact")
}

fn zero_or_more(parser: Parser(a)) -> Parser(List(a)) {
  fn(in: String) { zero_or_more_impl(parser, in, []) }
}

fn zero_or_more_impl(parser: Parser(a), in: String, acc: List(a)) {
  case parser(in) {
    Ok(Parsed(value, rest)) ->
      case rest == in {
        True -> Error(Nil)
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
          True -> Error(Nil)
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
      [] -> Error(Nil)

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

fn pair_joined(
  first: Parser(String),
  second: Parser(String),
) -> Parser(String) {
  pair(first, second)
  |> map(fn(parsed) { parsed.0 <> parsed.1 })
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

fn triple_joined(
  first: Parser(String),
  second: Parser(String),
  third: Parser(String),
) -> Parser(String) {
  triple(first, second, third)
  |> map(fn(parsed) { parsed.0 <> parsed.1 <> parsed.2 })
}

fn grapheme_from(graphemes: String) -> Parser(String) {
  fn(in: String) {
    case string.pop_grapheme(in) {
      Ok(#(first, rest)) ->
        case graphemes |> string.contains(first) {
          True -> Ok(Parsed(first, rest))
          False -> Error(Nil)
        }
      Error(_) -> Error(Nil)
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
          _, _ -> Error(Nil)
        }
      }
      Error(_) -> Error(Nil)
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
  fn(in: String) { Ok(Parsed(value: value, rest: in)) }
}

// ------------------------------------
// Choose tracer
// ------------------------------------
fn trace(parser: Parser(a), _name: String) -> Parser(a) {
  parser
}
// ------------------------------------
// import gleam/io

// fn trace(parser: Parser(a), name: String) -> Parser(a) {
//   fn(input) {
//     io.println(">> " <> name)
//     let result = parser(input)

//     case result {
//       Ok(value) -> {
//         io.println("<< " <> name <> " ... ")
//         io.println(" ... '" <> value.rest <> "'")
//         Ok(value)
//       }

//       Error(error) -> {
//         io.println("<! " <> name)
//         Error(error)
//       }
//     }
//   }
// }
// ------------------------------------
