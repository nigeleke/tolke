import gleam/float
import gleam/list
import gleam/option.{type Option}

import diagnostic
import outcome.{type Outcome}

import internal/bind/model.{
  type BoundApplyFunction, type BoundAttribute, type BoundComplexBody,
  type BoundDeclaration, type BoundElement, type BoundExpression,
  type BoundFunction, type BoundIdentityFunction, type BoundKey,
  type BoundMarkup, type BoundMatcher, type BoundMessage, type BoundValue,
  type BoundValueRef, type BoundVariable, type BoundVariant,
} as bm
import internal/evaluate/context.{type Context}
import internal/evaluate/model.{
  type EvaluatedAttribute, type EvaluatedElement, type EvaluatedMarkup,
  type EvaluatedMessage, type EvaluatedValue,
}
import internal/unresolved_value

pub fn evaluate(
  message: BoundMessage,
  context: Context,
) -> Outcome(EvaluatedMessage) {
  case message {
    bm.Simple(elements) -> evaluate_elements(elements, context)
    bm.Complex(declarations, body) ->
      declarations
      |> evaluate_and_merge_declarations(context)
      |> outcome.and_then(evaluate_complex_body(body, _))
  }
  |> outcome.map(model.EvaluatedMessage)
}

fn evaluate_elements(
  elements: List(BoundElement),
  context: Context,
) -> Outcome(List(EvaluatedElement)) {
  elements
  |> list.map(evaluate_element(_, context))
  |> outcome.transpose_list
}

fn evaluate_element(
  element: BoundElement,
  context: Context,
) -> Outcome(EvaluatedElement) {
  case element {
    bm.Text(text) -> outcome.annotate(model.Text(text))

    bm.Expression(expression) ->
      evaluate_expression(expression, context)
      |> outcome.map(model.Value)

    bm.Markup(markup) ->
      evaluate_markup(markup, context)
      |> outcome.map(model.Markup)
  }
}

fn evaluate_markup(
  markup: BoundMarkup,
  context: Context,
) -> Outcome(EvaluatedMarkup) {
  case markup {
    bm.Standalone(identifier, _options, attributes) -> {
      let bm.BoundIdentifier(name) = identifier
      evaluate_attributes(attributes, context)
      |> outcome.map(model.Standalone(name, _))
    }

    bm.Open(identifier, _options, attributes) -> {
      let bm.BoundIdentifier(name) = identifier
      evaluate_attributes(attributes, context)
      |> outcome.map(model.Open(name, _))
    }

    bm.Close(identifier, _options, _attributes) -> {
      let bm.BoundIdentifier(name) = identifier
      outcome.annotate(model.Close(name))
    }
  }
}

fn evaluate_attributes(
  attributes: List(BoundAttribute),
  context: Context,
) -> Outcome(List(EvaluatedAttribute)) {
  attributes
  |> list.map(evaluate_attribute(_, context))
  |> outcome.transpose_list
}

fn evaluate_attribute(
  attribute: BoundAttribute,
  _context: Context,
) -> Outcome(EvaluatedAttribute) {
  case attribute {
    bm.FlagAttribute(identifier) -> {
      let bm.BoundIdentifier(name) = identifier
      outcome.annotate(model.Flag(name))
    }

    bm.ValueAttribute(identifier, value) -> {
      let bm.BoundIdentifier(name) = identifier

      evaluate_value(value)
      |> outcome.map(fn(value) { model.KeyValue(name, value) })
    }
  }
}

fn evaluate_value(value: BoundValue) -> Outcome(EvaluatedValue) {
  case value {
    bm.VString(value) -> outcome.annotate(model.VString(value))
    bm.VNumber(value) -> outcome.annotate(model.VNumber(value))
  }
}

fn bound_value_to_string(value: BoundValue) -> String {
  case value {
    bm.VString(s) -> s
    bm.VNumber(n) -> float.to_string(n)
  }
}

fn evaluate_and_merge_declarations(
  declarations: List(BoundDeclaration),
  context: Context,
) -> Outcome(Context) {
  echo "Merging"
  echo declarations
  echo " into..."
  echo context
  echo " returning..."
  echo {
    declarations
    |> list.fold(outcome.annotate(context), fn(acc, declaration) {
      let evaluation = evaluate_declaration(declaration, context)
      outcome.map2(acc, evaluation, fn(acc, e) {
        let #(key, value) = e
        acc |> context.insert(echo key, echo value)
      })
    })
  }
}

fn evaluate_declaration(
  declaration: BoundDeclaration,
  context: Context,
) -> Outcome(#(String, EvaluatedValue)) {
  let bm.BoundDeclaration(variable, expression) = declaration
  let bm.BoundVariable(name) = variable

  let expression = evaluate_expression(expression, context)

  echo { expression |> outcome.map(fn(e) { #(name, e) }) }
}

fn evaluate_expression(
  expression: BoundExpression,
  context: Context,
) -> Outcome(EvaluatedValue) {
  case expression {
    bm.ApplyFunction(function) -> evaluate_apply_function(function, context)
    bm.IdentityFunction(function) ->
      evaluate_identity_function(function, context)
  }
}

fn evaluate_apply_function(
  function: BoundApplyFunction,
  context: Context,
) -> Outcome(EvaluatedValue) {
  let bm.BoundApplyFunction(function, operand, _) = function
  evaluate_function(function, operand, context)
}

fn evaluate_identity_function(
  function: BoundIdentityFunction,
  context: Context,
) -> Outcome(EvaluatedValue) {
  let bm.BoundIdentityFunction(operand, _) = function
  evaluate_value_ref(operand, context)
}

fn evaluate_value_ref(
  ref: BoundValueRef,
  context: Context,
) -> Outcome(EvaluatedValue) {
  case ref {
    bm.Literal(v) -> evaluate_value(v)
    bm.Variable(variable) -> evaluate_variable(variable, context)
  }
}

fn evaluate_variable(
  variable: BoundVariable,
  context: Context,
) -> Outcome(EvaluatedValue) {
  let bm.BoundVariable(name) = variable

  case context |> context.get(name) {
    Ok(value) -> outcome.annotate(value)

    Error(_) -> {
      let value = unresolved_value.UnresolvedVariable(name)
      let value = model.Unresolved(value)
      let diagnostics = [diagnostic.UnresolvedVariable]
      outcome.annotate_with_diagnostics(value, diagnostics)
    }
  }
}

fn evaluate_function(
  function: BoundFunction,
  operand: Option(BoundValueRef),
  context: Context,
) -> Outcome(EvaluatedValue) {
  let bm.BoundFunction(identifier, _options) = function
  let bm.BoundIdentifier(name) = identifier

  let evaluated_operand = evaluate_operand(operand, context)

  case name {
    "string" -> {
      case evaluated_operand.value {
        option.Some(v) -> outcome.annotate(v)
        option.None -> function_fallback(name, operand)
      }
    }

    "number" -> {
      case evaluated_operand.value {
        option.Some(v) -> outcome.annotate(v)
        option.None -> function_fallback(name, operand)
      }
    }

    _ -> function_fallback(name, operand)
  }
}

fn evaluate_operand(
  operand: Option(BoundValueRef),
  context: Context,
) -> Outcome(Option(EvaluatedValue)) {
  case operand {
    option.None -> outcome.annotate(option.None)
    option.Some(ref) -> {
      evaluate_value_ref(ref, context)
      |> outcome.map(option.Some)
    }
  }
}

fn function_fallback(
  function_name: String,
  operand: Option(BoundValueRef),
) -> Outcome(EvaluatedValue) {
  let #(fallback, diagnostics) = case operand {
    option.Some(bm.Variable(bm.BoundVariable(name))) ->
      echo #(unresolved_value.UnresolvedVariable(name), [
        diagnostic.UnresolvedVariable,
        diagnostic.UnknownFunction,
      ])

    option.Some(bm.Literal(value)) ->
      echo #(
        unresolved_value.UnresolvedFunction(
          function_name,
          option.Some(unresolved_value.Literal(bound_value_to_string(value))),
        ),
        [diagnostic.UnknownFunction],
      )

    option.None ->
      echo #(unresolved_value.UnresolvedFunction(function_name, option.None), [
        diagnostic.UnknownFunction,
      ])
  }

  outcome.Ok(model.Unresolved(fallback), diagnostics)
}

fn evaluate_complex_body(
  body: BoundComplexBody,
  context: Context,
) -> Outcome(List(EvaluatedElement)) {
  case body {
    bm.Pattern(elements) ->
      elements
      |> list.map(fn(e) { evaluate_element(e, context) })
      |> outcome.transpose_list

    bm.Matcher(matcher) -> evaluate_matcher(matcher, context)
  }
}

fn evaluate_matcher(
  matcher: BoundMatcher,
  context: Context,
) -> Outcome(List(EvaluatedElement)) {
  let bm.BoundMatcher(selectors, variants) = matcher

  let evaluated_selectors =
    selectors
    |> list.map(fn(s) { evaluate_variable(s, context) })
    |> outcome.transpose_list

  evaluated_selectors
  |> outcome.and_then(fn(keys) {
    case select_variant(keys, variants) {
      Ok(variant) -> evaluate_complex_body(variant.body, context)
      Error(_) ->
        outcome.annotate_with_diagnostics([], [diagnostic.BadSelector])
    }
  })
}

fn select_variant(
  keys: List(EvaluatedValue),
  variants: List(BoundVariant),
) -> Result(BoundVariant, Nil) {
  variants
  |> list.find(fn(variant) { variant_matches(variant.keys, keys) })
}

fn variant_matches(keys: List(BoundKey), values: List(EvaluatedValue)) -> Bool {
  case list.length(keys) == list.length(values) {
    False -> False
    True ->
      keys
      |> list.zip(values)
      |> list.all(fn(pair) {
        let #(key, value) = pair
        key_matches(key, value)
      })
  }
}

fn key_matches(key: BoundKey, value: EvaluatedValue) -> Bool {
  case key {
    bm.Wildcard -> True
    bm.Key(bound_value) -> evaluate_value(bound_value).value == value
  }
}
