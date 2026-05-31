/// Used to recreate and layout the original message source - formatted
///
import gleam/list
import gleam/option.{type Option as GleamOption} as gleam_option
import gleam/string

import ast.{
  type Attribute, type ComplexBody, type ComplexMessage, type Declaration,
  type Expression, type Function, type FunctionExpression, type Identifier,
  type InputDeclaration, type Key, type Literal, type LiteralExpression,
  type LocalDeclaration, type Markup, type MatchStatement, type Matcher,
  type Message, type MessageElement, type Option, type OptionElement,
  type OptionalWhitespace, type Pattern, type Placeholder, type QuotedPattern,
  type Selector, type SimpleMessage, type SimpleStart, type UnquotedLiteral,
  type Variable, type VariableExpression, type Variant,
}

fn list_to_string(list: List(a), f: fn(a) -> String) -> String {
  "[" <> list.map(list, f) |> string.join(", ") <> "]"
}

fn gleam_option_to_string(opt: GleamOption(a), f: fn(a) -> String) -> String {
  case opt {
    gleam_option.Some(value) -> "Some(" <> f(value) <> ")"
    gleam_option.None -> "None"
  }
}

pub fn prettify(message: Message) -> String {
  case message {
    ast.Simple(simple) ->
      "MessageSimple(" <> simple_message_to_string(simple) <> ")"
    ast.Complex(complex) ->
      "MessageComplex(" <> complex_message_to_string(complex) <> ")"
  }
}

fn simple_message_to_string(simple: SimpleMessage) -> String {
  let ast.SimpleMessage(ws, opt) = simple
  "SimpleMessageBody("
  <> optional_whitespace_to_string(ws)
  <> ", "
  <> gleam_option_to_string(opt, fn(t) {
    let #(start, pattern) = t
    simple_start_to_string(start) <> ", " <> pattern_to_string(pattern)
  })
  <> ")"
}

fn simple_start_to_string(start: SimpleStart) -> String {
  case start {
    ast.Text(c) -> "SimpleStartChar(" <> c <> ")"
    ast.Escaped(e) -> "SimpleStartEscapedChar(" <> e <> ")"
    ast.Placeholder(p) ->
      "SimpleStartPlaceholder(" <> placeholder_to_string(p) <> ")"
  }
}

// ─────────────────────────────────────────────────────────────
// Pattern
// ─────────────────────────────────────────────────────────────

fn pattern_to_string(pattern: Pattern) -> String {
  "Pattern(" <> list_to_string(pattern, pattern_element_to_string) <> ")"
}

fn pattern_element_to_string(elem: MessageElement) -> String {
  case elem {
    ast.Text(t) -> "Text(" <> t <> ")"
    ast.Escaped(e) -> "Escaped(" <> e <> ")"
    ast.Placeholder(p) -> "Placeholder(" <> placeholder_to_string(p) <> ")"
  }
}

fn placeholder_to_string(placeholder: Placeholder) -> String {
  case placeholder {
    ast.PlaceholderExpression(e) ->
      "Expression(" <> expression_to_string(e) <> ")"
    ast.PlaceholderMarkup(m) -> "Markup(" <> markup_to_string(m) <> ")"
  }
}

// ─────────────────────────────────────────────────────────────
// Complex Message
// ─────────────────────────────────────────────────────────────

fn complex_message_to_string(complex: ComplexMessage) -> String {
  let ast.ComplexMessage(declarations, body) = complex
  "ComplexMessageBody("
  <> list_to_string(declarations, declaration_to_string)
  <> ", "
  <> complex_body_to_string(body)
  <> ")"
}

fn declaration_to_string(declaration: Declaration) -> String {
  case declaration {
    ast.DeclarationInput(input) ->
      "Input(" <> input_declaration_to_string(input) <> ")"
    ast.DeclarationLocal(local) ->
      "Local(" <> local_declaration_to_string(local) <> ")"
  }
}

fn complex_body_to_string(body: ComplexBody) -> String {
  case body {
    ast.ComplexBodyQuotedPattern(qp) ->
      "QuotedPattern(" <> quoted_pattern_to_string(qp) <> ")"
    ast.ComplexBodyMatcher(m) -> "Matcher(" <> matcher_to_string(m) <> ")"
  }
}

// ─────────────────────────────────────────────────────────────
// Declarations
// ─────────────────────────────────────────────────────────────

fn input_declaration_to_string(input: InputDeclaration) -> String {
  let ast.InputDeclaration(var_expr) = input
  "InputDeclaration(" <> variable_expression_to_string(var_expr) <> ")"
}

fn local_declaration_to_string(local: LocalDeclaration) -> String {
  let ast.LocalDeclaration(var, expr) = local
  "LocalDeclaration("
  <> variable_to_string(var)
  <> " = "
  <> expression_to_string(expr)
  <> ")"
}

// ─────────────────────────────────────────────────────────────
// Quoted Pattern & Matcher
// ─────────────────────────────────────────────────────────────

fn quoted_pattern_to_string(qp: QuotedPattern) -> String {
  let ast.QuotedPattern(pattern) = qp
  "QuotedPattern(" <> pattern_to_string(pattern) <> ")"
}

fn matcher_to_string(matcher: Matcher) -> String {
  let ast.Matcher(match_stmt, first_variant, rest_variants) = matcher
  "Matcher("
  <> match_statement_to_string(match_stmt)
  <> ", "
  <> variant_to_string(first_variant)
  <> ", "
  <> list_to_string(rest_variants, variant_to_string)
  <> ")"
}

fn match_statement_to_string(ms: MatchStatement) -> String {
  let ast.MatchStatement(selectors) = ms
  "Match(" <> list_to_string(selectors, selector_to_string) <> ")"
}

fn selector_to_string(selector: Selector) -> String {
  let ast.Selector(var) = selector
  "Selector(" <> variable_to_string(var) <> ")"
}

fn variant_to_string(variant: Variant) -> String {
  let ast.Variant(key, keys, quoted_pattern) = variant
  "Variant("
  <> key_to_string(key)
  <> ", "
  <> list_to_string(keys, key_to_string)
  <> ", "
  <> quoted_pattern_to_string(quoted_pattern)
  <> ")"
}

fn key_to_string(key: Key) -> String {
  case key {
    ast.KeyLiteral(lit) -> "Key(" <> literal_to_string(lit) <> ")"
    ast.KeyOther -> "Key(*)"
  }
}

// ─────────────────────────────────────────────────────────────
// Expressions
// ─────────────────────────────────────────────────────────────

fn expression_to_string(expr: Expression) -> String {
  case expr {
    ast.ExpressionLiteral(le) ->
      "LiteralExpr(" <> literal_expression_to_string(le) <> ")"
    ast.ExpressionVariable(ve) ->
      "VariableExpr(" <> variable_expression_to_string(ve) <> ")"
    ast.ExpressionFunction(fe) ->
      "FunctionExpr(" <> function_expression_to_string(fe) <> ")"
  }
}

fn literal_expression_to_string(le: LiteralExpression) -> String {
  let ast.LiteralExpression(lit, _func, _attrs) = le
  "{" <> literal_to_string(lit) <> "}"
}

pub fn variable_expression_to_string(ve: VariableExpression) -> String {
  let ast.VariableExpression(var, _func, _attrs) = ve
  "{" <> variable_to_string(var) <> "}"
}

fn function_expression_to_string(fe: FunctionExpression) -> String {
  let ast.FunctionExpression(func, attrs) = fe
  "FunctionExpr("
  <> function_to_string(func)
  <> ", "
  <> list_to_string(attrs, attribute_to_string)
  <> ")"
}

// ─────────────────────────────────────────────────────────────
// Markup, Function, Option, Attribute
// ─────────────────────────────────────────────────────────────

fn markup_to_string(markup: Markup) -> String {
  case markup {
    ast.MarkupStandalone(id, opts, attrs) ->
      "MarkupStandalone("
      <> identifier_to_string(id)
      <> ", "
      <> list_to_string(opts, option_to_string)
      <> ", "
      <> list_to_string(attrs, attribute_to_string)
      <> ")"

    ast.MarkupOpen(id, opts, attrs) ->
      "MarkupOpen("
      <> identifier_to_string(id)
      <> ", "
      <> list_to_string(opts, option_to_string)
      <> ", "
      <> list_to_string(attrs, attribute_to_string)
      <> ")"

    ast.MarkupClose(id, opts, attrs) ->
      "MarkupClose("
      <> identifier_to_string(id)
      <> ", "
      <> list_to_string(opts, option_to_string)
      <> ", "
      <> list_to_string(attrs, attribute_to_string)
      <> ")"
  }
}

fn function_to_string(func: Function) -> String {
  let ast.Function(id, opts) = func
  ":" <> identifier_to_string(id) <> list_to_string(opts, option_to_string)
}

fn option_to_string(opt: Option) -> String {
  let ast.Option(id, elem) = opt
  identifier_to_string(id) <> "=" <> option_element_to_string(elem)
}

fn option_element_to_string(elem: OptionElement) -> String {
  case elem {
    ast.OptionElementLiteral(lit) -> literal_to_string(lit)
    ast.OptionElementVariable(var) -> variable_to_string(var)
  }
}

fn attribute_to_string(attr: Attribute) -> String {
  case attr {
    ast.FlagAttribute(id) -> "@" <> identifier_to_string(id)
    ast.ValueAttribute(id, li) ->
      "@" <> identifier_to_string(id) <> " = " <> literal_to_string(li)
  }
}

// ─────────────────────────────────────────────────────────────
// Variables & Literals
// ─────────────────────────────────────────────────────────────

fn variable_to_string(var: Variable) -> String {
  let ast.Variable(name) = var
  "$" <> name
}

fn literal_to_string(lit: Literal) -> String {
  case lit {
    ast.LiteralQuoted(q) -> "|" <> q <> "|"
    ast.LiteralUnquoted(u) -> unquoted_literal_to_string(u)
  }
}

fn unquoted_literal_to_string(u: UnquotedLiteral) -> String {
  let ast.UnquotedLiteral(value) = u
  value
}

fn identifier_to_string(id: Identifier) -> String {
  let ast.Identifier(namespace, name) = id
  case namespace {
    gleam_option.Some(ns) -> ns <> ":" <> name
    gleam_option.None -> name
  }
}

fn optional_whitespace_to_string(_ws: OptionalWhitespace) -> String {
  " "
}
