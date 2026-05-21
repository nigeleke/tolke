import gleam/dict
import gleam/float
import gleam/list
import gleam/option.{type Option as GleamOption} as gleam_option

import mf2/annotated_value.{type AnnotatedValue} as av
import mf2/binder/model.{
  type BoundAttribute, type BoundDeclaration, type BoundElement,
  type BoundExpression, type BoundFunction, type BoundIdentifier, type BoundKey,
  type BoundMarkup, type BoundMessage, type BoundOption, type BoundOptions,
  type BoundValue, type BoundValueRef, type BoundVariable, type BoundVariant,
}
import mf2/diagnostic
import mf2/parser/ast.{
  type Attribute, type ComplexBody, type ComplexMessage, type Declaration,
  type Expression, type Function, type FunctionExpression, type Identifier,
  type InputDeclaration, type Key, type Literal, type LiteralExpression,
  type LocalDeclaration, type Markup, type Matcher, type Message,
  type MessageElement, type Option, type Placeholder, type QuotedPattern,
  type Selector, type SimpleMessage, type Variable, type VariableExpression,
  type Variant,
}
import mf2/runtime.{type RuntimeContext}

pub type Binder =
  fn(Message, RuntimeContext) -> AnnotatedValue(BoundMessage)

pub fn bind(
  message: Message,
  context: RuntimeContext,
) -> AnnotatedValue(BoundMessage) {
  case message {
    ast.Simple(message) -> bind_simple_message(message, context)
    ast.Complex(message) -> bind_complex_message(message, context)
  }
}

fn bind_simple_message(
  message: SimpleMessage,
  _context: RuntimeContext,
) -> AnnotatedValue(BoundMessage) {
  let ast.SimpleMessage(ws, simple_start_and_pattern) = message

  let ws = ast.Text(ws)

  let #(simple_start, pattern_elements) =
    simple_start_and_pattern
    |> gleam_option.unwrap(#(ast.Text(""), list.new()))

  let elements =
    [ws, simple_start, ..pattern_elements]
    |> list.map(bind_element)
    |> av.transpose_list
    |> av.map(coalesce_adjacent_texts)

  elements |> av.map(model.Simple)
}

fn bind_element(element: MessageElement) -> AnnotatedValue(BoundElement) {
  case element {
    ast.Text(s) | ast.Escaped(s) -> av.annotate(model.Text(s))
    ast.Placeholder(p) -> bind_placeholder(p)
  }
}

fn bind_placeholder(placeholder: Placeholder) -> AnnotatedValue(BoundElement) {
  case placeholder {
    ast.PlaceholderExpression(e) -> bind_expression(e)

    ast.PlaceholderMarkup(m) ->
      bind_markup(m)
      |> av.map(model.Markup)
  }
}

fn bind_expression(expression: Expression) -> AnnotatedValue(BoundElement) {
  case expression {
    ast.ExpressionLiteral(e) -> bind_literal_expression(e)
    ast.ExpressionVariable(e) -> bind_variable_expression(e)
    ast.ExpressionFunction(e) -> bind_function_expression(e)
  }
}

fn bind_literal_expression(
  expression: LiteralExpression,
) -> AnnotatedValue(BoundElement) {
  let ast.LiteralExpression(literal, function, attributes) = expression

  let literal =
    bind_literal(literal)
    |> av.map(model.Literal)

  bind_expression_impl(function, gleam_option.Some(literal), attributes)
  |> av.map(model.Expression)
}

fn bind_expression_impl(
  function: GleamOption(Function),
  value: GleamOption(AnnotatedValue(BoundValueRef)),
  attributes: List(Attribute),
) -> AnnotatedValue(BoundExpression) {
  let function =
    function
    |> gleam_option.map(bind_function)
    |> av.transpose_option

  let value = case value {
    gleam_option.Some(value) -> value |> av.map(model.BoundValueRef)
    gleam_option.None -> av.annotate(model.NoOperand)
  }

  let attributes = bind_attributes(attributes)

  av.map3(function, value, attributes, fn(f, v, a) {
    model.BoundExpression(f, v, a)
  })
}

fn bind_function(function: Function) -> AnnotatedValue(BoundFunction) {
  let ast.Function(name, options) = function
  let name = bind_identifier(name)
  let options = bind_options(options)

  av.map2(name, options, fn(name, options) {
    model.BoundFunction(name, options)
  })
}

fn bind_literal(literal: Literal) -> AnnotatedValue(BoundValue) {
  case literal {
    ast.LiteralQuoted(s) -> av.annotate(model.VString(s))
    ast.LiteralUnquoted(ast.UnquotedLiteralName(s)) ->
      av.annotate(model.VString(s))
    ast.LiteralUnquoted(ast.UnquotedLiteralNumber(v)) ->
      case float.parse(v) {
        // Passed during parsing; will not fail now.
        Ok(value) -> av.annotate(model.VNumber(value))
        // Sensible default on failure.
        Error(_) ->
          av.annotate_with_diagnostics(model.VString(v), [
            diagnostic.SyntaxError,
          ])
      }
  }
}

fn bind_identifier(id: Identifier) -> AnnotatedValue(BoundIdentifier) {
  let ast.Identifier(namespace, name) = id

  let identifier = case namespace {
    gleam_option.Some(namespace) -> namespace <> ":" <> name
    gleam_option.None -> name
  }

  av.annotate(model.BoundIdentifier(identifier))
}

fn bind_options(options: List(Option)) -> AnnotatedValue(BoundOptions) {
  options
  |> list.map(bind_option)
  |> av.transpose_list
  |> av.map(dict.from_list)
}

fn bind_option(
  option: Option,
) -> AnnotatedValue(#(BoundIdentifier, BoundOption)) {
  let ast.Option(identifier, value) = option

  let identifier = bind_identifier(identifier)

  let value = case value {
    ast.OptionElementLiteral(l) -> bind_literal(l) |> av.map(model.Literal)
    ast.OptionElementVariable(v) -> bind_variable(v) |> av.map(model.Variable)
  }

  av.pair(identifier, value)
}

fn bind_variable(variable: Variable) -> AnnotatedValue(BoundVariable) {
  let ast.Variable(name) = variable
  av.annotate(model.BoundVariable(name))
}

fn bind_attributes(
  attributes: List(Attribute),
) -> AnnotatedValue(List(BoundAttribute)) {
  attributes |> list.map(bind_attribute) |> av.transpose_list
}

fn bind_attribute(attribute: Attribute) -> AnnotatedValue(BoundAttribute) {
  case attribute {
    ast.FlagAttribute(identifier) -> {
      bind_identifier(identifier) |> av.map(model.FlagAttribute)
    }

    ast.ValueAttribute(identifier, literal) -> {
      av.map2(bind_identifier(identifier), bind_literal(literal), fn(i, l) {
        model.ValueAttribute(i, l)
      })
    }
  }
}

fn bind_variable_expression(
  expression: VariableExpression,
) -> AnnotatedValue(BoundElement) {
  let ast.VariableExpression(variable, function, attributes) = expression
  let variable = bind_variable(variable) |> av.map(model.Variable)

  bind_expression_impl(function, gleam_option.Some(variable), attributes)
  |> av.map(model.Expression)
}

fn bind_function_expression(
  expression: FunctionExpression,
) -> AnnotatedValue(BoundElement) {
  let ast.FunctionExpression(function, attributes) = expression

  bind_expression_impl(
    gleam_option.Some(function),
    gleam_option.None,
    attributes,
  )
  |> av.map(model.Expression)
}

fn bind_markup(markup: Markup) -> AnnotatedValue(BoundMarkup) {
  let bind_common = fn(
    identifier,
    options,
    attributes,
    build: fn(BoundIdentifier, BoundOptions, List(BoundAttribute)) ->
      BoundMarkup,
  ) -> AnnotatedValue(BoundMarkup) {
    let identifier = bind_identifier(identifier)
    let options = bind_options(options)
    let attributes = bind_attributes(attributes)

    av.map3(
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
  context: RuntimeContext,
) -> AnnotatedValue(BoundMessage) {
  let ast.ComplexMessage(declarations, complex_body) = message

  let declarations =
    declarations
    |> list.map(bind_declaration(_, context))
    |> av.transpose_list

  let complex_body = bind_complex_body(complex_body)

  av.map2(declarations, complex_body, fn(ds, cb) { model.Complex(ds, cb) })
}

fn bind_declaration(
  declaration: Declaration,
  _context: RuntimeContext,
) -> AnnotatedValue(BoundDeclaration) {
  case declaration {
    ast.DeclarationInput(d) -> bind_input_declaration(d)
    ast.DeclarationLocal(d) -> bind_local_declaration(d)
  }
}

fn bind_input_declaration(
  declaration: InputDeclaration,
) -> AnnotatedValue(BoundDeclaration) {
  let ast.InputDeclaration(expression) = declaration
  let ast.VariableExpression(variable, function, attributes) = expression

  let variable = bind_variable(variable) |> av.map(model.Variable)

  bind_expression_impl(function, gleam_option.Some(variable), attributes)
  |> av.map2(variable, fn(e, v) { model.BoundDeclaration(v, e) })
}

fn bind_local_declaration(
  declaration: LocalDeclaration,
) -> AnnotatedValue(BoundDeclaration) {
  let ast.LocalDeclaration(variable, expression) = declaration

  let variable = bind_variable(variable) |> av.map(model.Variable)

  let expression = bind_expression(expression)
  let expression =
    av.map2(expression, variable, fn(expression, operand) {
      let assert model.Expression(expression) = expression
      let assert model.BoundExpression(function, _, attributes) = expression
      model.BoundExpression(function, model.BoundValueRef(operand), attributes)
    })

  av.map2(variable, expression, fn(v, e) { model.BoundDeclaration(v, e) })
}

fn bind_complex_body(body: ComplexBody) -> AnnotatedValue(List(BoundElement)) {
  case body {
    ast.ComplexBodyQuotedPattern(pattern) -> bind_quoted_pattern(pattern)

    ast.ComplexBodyMatcher(matcher) ->
      bind_matcher(matcher)
      |> av.map(fn(e) { [e] })
  }
}

fn bind_quoted_pattern(
  pattern: QuotedPattern,
) -> AnnotatedValue(List(BoundElement)) {
  let ast.QuotedPattern(pattern) = pattern

  pattern
  |> list.map(bind_element)
  |> av.transpose_list
}

fn bind_matcher(matcher: Matcher) -> AnnotatedValue(BoundElement) {
  let ast.Matcher(match_statement, variant, variants) = matcher
  let ast.MatchStatement(selectors) = match_statement

  let selector =
    selectors
    |> list.map(bind_selector)
    |> av.transpose_list

  let variants =
    [variant, ..variants]
    |> list.map(bind_variant)
    |> av.transpose_list

  av.map2(selector, variants, fn(s, vs) { model.BoundMatcher(s, vs) })
  |> av.map(model.Expression)
}

fn bind_selector(selector: Selector) -> AnnotatedValue(BoundVariable) {
  let ast.Selector(variable) = selector
  bind_variable(variable)
}

fn bind_variant(variant: Variant) -> AnnotatedValue(BoundVariant) {
  let ast.Variant(key, keys, pattern) = variant

  let keys =
    [key, ..keys]
    |> list.map(bind_key)
    |> av.transpose_list

  let pattern = bind_quoted_pattern(pattern)

  av.map2(keys, pattern, fn(k, b) { model.BoundVariant(k, b) })
}

fn bind_key(key: Key) -> AnnotatedValue(BoundKey) {
  case key {
    ast.KeyLiteral(literal) -> bind_literal(literal) |> av.map(model.Key)
    ast.KeyOther -> av.annotate(model.Wildcard)
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
