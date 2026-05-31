import gleam/float
import gleam/list
import gleam/option.{type Option}

import issue
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
  type EvaluatedMessage, type EvaluatedSelector, type EvaluatedValue,
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
      |> merge_declarations(context)
      |> evaluate_complex_body(body, _)
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
    bm.Text(text) -> outcome.pure(model.Text(text))

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
      outcome.pure(model.Close(name))
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
      outcome.pure(model.Flag(name))
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
    bm.VString(value) -> outcome.pure(model.VString(value))
    bm.VNumber(value) -> outcome.pure(model.VNumber(value))
  }
}

fn bound_value_to_string(value: BoundValue) -> String {
  case value {
    bm.VString(s) -> s
    bm.VNumber(n) -> float.to_string(n)
  }
}

fn merge_declarations(
  declarations: List(BoundDeclaration),
  context: Context,
) -> Context {
  declarations
  |> list.fold(context, fn(acc, declaration) {
    let evaluation = echo evaluate_declaration(declaration, context)
    let #(key, value) = evaluation.value
    acc |> context.insert(key, value)
  })
}

fn evaluate_declaration(
  declaration: BoundDeclaration,
  context: Context,
) -> Outcome(#(String, EvaluatedValue)) {
  let bm.BoundDeclaration(variable, expression) = declaration
  let bm.BoundVariable(name) = variable

  evaluate_expression(expression, context)
  |> outcome.map(fn(e) { #(name, e) })
}

fn evaluate_expression(
  expression: BoundExpression,
  context: Context,
) -> Outcome(EvaluatedValue) {
  echo case echo expression {
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
    Ok(value) -> reevaluate_value(value)

    Error(_) -> {
      let value = unresolved_value.UnresolvedVariable(name)
      let value = model.Unresolved(value)
      outcome.pure_with_issue(value, issue.UnresolvedVariable)
    }
  }
}

fn reevaluate_value(value: EvaluatedValue) -> Outcome(EvaluatedValue) {
  case value {
    model.VString(_) -> outcome.pure(value)
    model.VNumber(_) -> outcome.pure(value)
    model.Unresolved(unresolved) -> {
      let issue = case unresolved {
        unresolved_value.UnresolvedVariable(_) -> issue.UnresolvedVariable
        unresolved_value.UnresolvedFunction(_, _) -> issue.UnknownFunction
      }
      outcome.pure_with_issue(value, issue)
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

  let evaluated_operand = echo evaluate_operand(operand, context)

  evaluated_operand
  |> outcome.flat_map(fn(evaluated) {
    case name {
      "string" | "number" -> {
        case evaluated {
          option.Some(v) ->
            outcome.pure_with_issues(v, evaluated_operand.issues)
          option.None -> outcome.pure(fallback(name, operand))
        }
      }

      _ ->
        outcome.pure_with_issue(fallback(name, operand), issue.UnknownFunction)
    }
  })
}

fn evaluate_operand(
  operand: Option(BoundValueRef),
  context: Context,
) -> Outcome(Option(EvaluatedValue)) {
  case operand {
    option.None -> outcome.pure(option.None)
    option.Some(ref) -> {
      evaluate_value_ref(ref, context)
      |> outcome.map(option.Some)
    }
  }
}

fn fallback(
  function_name: String,
  operand: Option(BoundValueRef),
) -> EvaluatedValue {
  let value = case operand {
    option.Some(bm.Variable(bm.BoundVariable(name))) ->
      unresolved_value.UnresolvedVariable(name)

    option.Some(bm.Literal(value)) ->
      unresolved_value.UnresolvedFunction(
        function_name,
        option.Some(unresolved_value.Literal(bound_value_to_string(value))),
      )

    option.None ->
      unresolved_value.UnresolvedFunction(function_name, option.None)
  }

  model.Unresolved(value)
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

    bm.Matcher(matcher) -> echo evaluate_matcher(matcher, context)
  }
}

fn evaluate_matcher(
  matcher: BoundMatcher,
  context: Context,
) -> Outcome(List(EvaluatedElement)) {
  let bm.BoundMatcher(selectors, variants) = echo matcher

  let outcome.Ok(selectors, _) =
    selectors
    |> list.map(evaluate_variable(_, context))
    |> outcome.transpose_list

  let #(valid, invalid) = echo partition_selectors(selectors)

  echo variants

  case list.is_empty(invalid) {
    True -> {
      valid
      |> outcome.transpose_list()
      |> outcome.flat_map(evaluate_variants(_, variants, context))
    }

    False ->
      echo outcome.pure_with_issues(
        [],
        invalid |> list.flat_map(fn(x) { x.issues }),
      )
  }
}

fn partition_selectors(
  selectors: List(EvaluatedValue),
) -> #(List(Outcome(EvaluatedValue)), List(Outcome(EvaluatedValue))) {
  let selectors = selectors |> list.map(validate_selector)
  let #(matchable, unmatchable) =
    selectors
    |> list.fold(#(list.new(), list.new()), fn(acc, selector) {
      let #(valid, invalid) = acc
      let outcome.Ok(value:, issues:) = selector

      case value {
        model.Valid(value) -> #([outcome.pure(value), ..valid], invalid)
        model.Invalid(value) -> #(valid, [
          outcome.pure_with_issues(value, issues),
          ..invalid
        ])
      }
    })

  #(list.reverse(matchable), list.reverse(unmatchable))
}

fn validate_selector(value: EvaluatedValue) -> Outcome(EvaluatedSelector) {
  let issues = fn(unresolved) {
    [
      case unresolved {
        unresolved_value.UnresolvedFunction(_, _) -> issue.UnknownFunction
        unresolved_value.UnresolvedVariable(_) -> issue.UnresolvedVariable
      },
      issue.BadSelector,
    ]
  }

  case value {
    model.Unresolved(v) ->
      outcome.pure_with_issues(model.Invalid(value), issues(v))
    _ -> outcome.pure(model.Valid(value))
  }
}

fn evaluate_variants(
  keys: List(EvaluatedValue),
  variants: List(BoundVariant),
  context: Context,
) -> Outcome(List(EvaluatedElement)) {
  case select_variant(keys, variants) {
    Ok(variant) -> evaluate_complex_body(variant.body, context)
    Error(_) -> outcome.pure_with_issue([], issue.BadVariant)
  }
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
