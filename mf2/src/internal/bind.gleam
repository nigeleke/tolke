import gleam/dict
import gleam/list
import gleam/option.{type Option as GleamOption} as gleam_option

import ast.{
  type Attribute, type ComplexBody, type ComplexMessage, type Declaration,
  type Expression, type Function, type FunctionExpression, type Identifier,
  type InputDeclaration, type Key, type Literal, type LiteralExpression,
  type LocalDeclaration, type Markup, type Matcher, type Message,
  type MessageElement, type Option, type Placeholder, type QuotedPattern,
  type Selector, type SimpleMessage, type Variable, type VariableExpression,
  type Variant,
}

import outcome.{type Outcome}

import internal/bind/context.{type Context}
import internal/bind/model.{
  type BoundAttribute, type BoundComplexBody, type BoundDeclaration,
  type BoundElement, type BoundExpression, type BoundFunction,
  type BoundIdentifier, type BoundKey, type BoundMarkup, type BoundMatcher,
  type BoundMessage, type BoundOptions, type BoundValue, type BoundValueRef,
  type BoundVariable, type BoundVariant,
}

pub fn bind(message: Message, context: Context) -> Outcome(BoundMessage) {
  case message {
    ast.Simple(message) -> bind_simple_message(message, context)
    ast.Complex(message) -> bind_complex_message(message, context)
  }
}

fn bind_simple_message(
  message: SimpleMessage,
  _context: Context,
) -> Outcome(BoundMessage) {
  let ast.SimpleMessage(ws, simple_start_and_pattern) = message

  let ws = ast.Text(ws)

  let #(simple_start, pattern_elements) =
    simple_start_and_pattern
    |> gleam_option.unwrap(#(ast.Text(""), list.new()))

  let elements =
    [ws, simple_start, ..pattern_elements]
    |> list.map(bind_element)
    |> outcome.transpose_list
    |> outcome.map(coalesce_adjacent_texts)

  elements |> outcome.map(model.Simple)
}

fn bind_element(element: MessageElement) -> Outcome(BoundElement) {
  case element {
    ast.Text(s) | ast.Escaped(s) -> outcome.annotate(model.Text(s))
    ast.Placeholder(p) -> bind_placeholder(p)
  }
}

fn bind_placeholder(placeholder: Placeholder) -> Outcome(BoundElement) {
  case placeholder {
    ast.PlaceholderExpression(e) ->
      bind_expression(e) |> outcome.map(model.Expression)

    ast.PlaceholderMarkup(m) ->
      bind_markup(m)
      |> outcome.map(model.Markup)
  }
}

fn bind_expression(expression: Expression) -> Outcome(BoundExpression) {
  case expression {
    ast.ExpressionLiteral(e) -> bind_literal_expression(e)
    ast.ExpressionVariable(e) -> bind_variable_expression(e)
    ast.ExpressionFunction(e) -> bind_function_expression(e)
  }
}

fn bind_literal_expression(
  expression: LiteralExpression,
) -> Outcome(BoundExpression) {
  let ast.LiteralExpression(literal, function, attributes) = expression

  bind_literal(literal)
  |> outcome.map(model.Literal)
  |> outcome.and_then(bind_operand_to_function(function, _, attributes))
}

fn bind_operand_to_function(
  function: GleamOption(Function),
  operand: BoundValueRef,
  attributes: List(Attribute),
) -> Outcome(BoundExpression) {
  case function {
    gleam_option.Some(function) ->
      bind_apply_function(function, gleam_option.Some(operand), attributes)

    gleam_option.None -> bind_identity_function(operand, attributes)
  }
}

fn bind_apply_function(
  function: Function,
  operand: GleamOption(BoundValueRef),
  attributes: List(Attribute),
) -> Outcome(BoundExpression) {
  let function = bind_function(function)
  let attributes = bind_attributes(attributes)

  outcome.map2(function, attributes, fn(function, attributes) {
    model.BoundApplyFunction(function, operand, attributes:)
  })
  |> outcome.map(model.ApplyFunction)
}

fn bind_identity_function(
  operand: BoundValueRef,
  attributes: List(Attribute),
) -> Outcome(BoundExpression) {
  bind_attributes(attributes)
  |> outcome.map(model.BoundIdentityFunction(operand, _))
  |> outcome.map(model.IdentityFunction)
}

fn bind_function(function: Function) -> Outcome(BoundFunction) {
  let ast.Function(name, options) = function
  let name = bind_identifier(name)
  let options = bind_options(options)

  outcome.map2(name, options, fn(name, options) {
    model.BoundFunction(name:, options:)
  })
}

fn bind_literal(literal: Literal) -> Outcome(BoundValue) {
  case literal {
    ast.LiteralQuoted(s) -> outcome.annotate(model.VString(s))
    ast.LiteralUnquoted(ast.UnquotedLiteral(s)) ->
      outcome.annotate(model.VString(s))
  }
}

fn bind_identifier(id: Identifier) -> Outcome(BoundIdentifier) {
  let ast.Identifier(namespace, name) = id

  let identifier = case namespace {
    gleam_option.Some(namespace) -> namespace <> ":" <> name
    gleam_option.None -> name
  }

  outcome.annotate(model.BoundIdentifier(identifier))
}

fn bind_options(options: List(Option)) -> Outcome(BoundOptions) {
  options
  |> list.map(bind_option)
  |> outcome.transpose_list
  |> outcome.map(dict.from_list)
}

fn bind_option(option: Option) -> Outcome(#(BoundIdentifier, BoundValueRef)) {
  let ast.Option(identifier, value) = option

  let identifier = bind_identifier(identifier)

  let value = case value {
    ast.OptionElementLiteral(l) -> bind_literal(l) |> outcome.map(model.Literal)
    ast.OptionElementVariable(v) ->
      bind_variable(v) |> outcome.map(model.Variable)
  }

  outcome.pair(identifier, value)
}

fn bind_variable(variable: Variable) -> Outcome(BoundVariable) {
  let ast.Variable(name) = variable
  outcome.annotate(model.BoundVariable(name))
}

fn bind_attributes(
  attributes: List(Attribute),
) -> Outcome(List(BoundAttribute)) {
  attributes |> list.map(bind_attribute) |> outcome.transpose_list
}

fn bind_attribute(attribute: Attribute) -> Outcome(BoundAttribute) {
  case attribute {
    ast.FlagAttribute(identifier) -> {
      bind_identifier(identifier) |> outcome.map(model.FlagAttribute)
    }

    ast.ValueAttribute(identifier, literal) -> {
      outcome.map2(bind_identifier(identifier), bind_literal(literal), fn(i, l) {
        model.ValueAttribute(i, l)
      })
    }
  }
}

fn bind_variable_expression(
  expression: VariableExpression,
) -> Outcome(BoundExpression) {
  let ast.VariableExpression(variable, function, attributes) = expression

  bind_variable(variable)
  |> outcome.map(model.Variable)
  |> outcome.and_then(bind_operand_to_function(function, _, attributes))
}

fn bind_function_expression(
  expression: FunctionExpression,
) -> Outcome(BoundExpression) {
  let ast.FunctionExpression(function, attributes) = expression

  bind_apply_function(function, gleam_option.None, attributes)
}

fn bind_markup(markup: Markup) -> Outcome(BoundMarkup) {
  let bind_common = fn(
    identifier,
    options,
    attributes,
    build: fn(BoundIdentifier, BoundOptions, List(BoundAttribute)) ->
      BoundMarkup,
  ) -> Outcome(BoundMarkup) {
    let identifier = bind_identifier(identifier)
    let options = bind_options(options)
    let attributes = bind_attributes(attributes)

    outcome.map3(
      identifier,
      options,
      attributes,
      fn(identifier, options, attributes) {
        build(identifier, options, attributes)
      },
    )
  }

  case markup {
    ast.MarkupStandalone(i, o, a) -> bind_common(i, o, a, model.Standalone)
    ast.MarkupOpen(i, o, a) -> bind_common(i, o, a, model.Open)
    ast.MarkupClose(i, o, a) -> bind_common(i, o, a, model.Close)
  }
}

fn bind_complex_message(
  message: ComplexMessage,
  context: Context,
) -> Outcome(BoundMessage) {
  let ast.ComplexMessage(declarations, complex_body) = message

  let declarations =
    declarations
    |> list.map(bind_declaration(_, context))
    |> outcome.transpose_list

  let complex_body = bind_complex_body(complex_body)

  outcome.map2(declarations, complex_body, fn(ds, cb) { model.Complex(ds, cb) })
}

fn bind_declaration(
  declaration: Declaration,
  _context: Context,
) -> Outcome(BoundDeclaration) {
  case declaration {
    ast.DeclarationInput(d) -> bind_input_declaration(d)
    ast.DeclarationLocal(d) -> bind_local_declaration(d)
  }
}

fn bind_input_declaration(
  declaration: InputDeclaration,
) -> Outcome(BoundDeclaration) {
  let ast.InputDeclaration(expression) = declaration
  let ast.VariableExpression(variable, function, attributes) = expression

  let variable = bind_variable(variable)

  variable
  |> outcome.map(model.Variable)
  |> outcome.and_then(bind_operand_to_function(function, _, attributes))
  |> outcome.map2(variable, fn(e, v) { model.BoundDeclaration(v, e) })
}

fn bind_local_declaration(
  declaration: LocalDeclaration,
) -> Outcome(BoundDeclaration) {
  let ast.LocalDeclaration(variable, expression) = declaration

  let variable = bind_variable(variable)
  let expression = bind_expression(expression)

  outcome.map2(variable, expression, fn(v, e) { model.BoundDeclaration(v, e) })
}

fn bind_complex_body(body: ComplexBody) -> Outcome(BoundComplexBody) {
  case body {
    ast.ComplexBodyQuotedPattern(pattern) ->
      bind_quoted_pattern(pattern)
      |> outcome.map(model.Pattern)

    ast.ComplexBodyMatcher(matcher) ->
      echo {
        bind_matcher(matcher)
        |> outcome.map(model.Matcher)
      }
  }
}

fn bind_quoted_pattern(pattern: QuotedPattern) -> Outcome(List(BoundElement)) {
  let ast.QuotedPattern(pattern) = pattern

  pattern
  |> list.map(bind_element)
  |> outcome.transpose_list
}

fn bind_matcher(matcher: Matcher) -> Outcome(BoundMatcher) {
  let ast.Matcher(match_statement, variant, variants) = matcher
  let ast.MatchStatement(selectors) = match_statement

  let selector =
    echo selectors
      |> list.map(bind_selector)
      |> outcome.transpose_list

  let variants =
    echo [variant, ..variants]
      |> list.map(bind_variant)
      |> outcome.transpose_list

  outcome.map2(selector, variants, fn(s, vs) { model.BoundMatcher(s, vs) })
}

fn bind_selector(selector: Selector) -> Outcome(BoundVariable) {
  let ast.Selector(variable) = selector
  bind_variable(variable)
}

fn bind_variant(variant: Variant) -> Outcome(BoundVariant) {
  let ast.Variant(key, keys, pattern) = variant

  let keys =
    [key, ..keys]
    |> list.map(bind_key)
    |> outcome.transpose_list

  let pattern = bind_quoted_pattern(pattern)
  let body = pattern |> outcome.map(model.Pattern)

  outcome.map2(keys, body, fn(k, b) { model.BoundVariant(k, b) })
}

fn bind_key(key: Key) -> Outcome(BoundKey) {
  case key {
    ast.KeyLiteral(literal) -> bind_literal(literal) |> outcome.map(model.Key)
    ast.KeyOther -> outcome.annotate(model.Wildcard)
  }
}

// Helpers...
fn coalesce_adjacent_texts(elements: List(BoundElement)) -> List(BoundElement) {
  case elements {
    [] -> []

    [model.Text(first), model.Text(second), ..rest] ->
      coalesce_adjacent_texts([model.Text(first <> second), ..rest])

    [first, ..rest] -> [first, ..coalesce_adjacent_texts(rest)]
  }
}
