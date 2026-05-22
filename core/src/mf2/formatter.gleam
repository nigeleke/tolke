import gleam/dict
import gleam/float
import gleam/list
import gleam/option as gleam_option
import gleam/string

import mf2/annotated_value.{type AnnotatedValue} as av
import mf2/binder/model.{
  type BoundAttribute, type BoundDeclaration, type BoundElement,
  type BoundExpression, type BoundFunction, type BoundIdentifier,
  type BoundMarkup, type BoundMessage, type BoundOperand, type BoundOption,
  type BoundOptions, type BoundValue, type BoundValueRef, type BoundVariable,
}
import mf2/diagnostic
import mf2/runtime.{type RuntimeContext}

pub type FormatContext {
  FormatContext(runtime: RuntimeContext, declarations: List(BoundDeclaration))
}

pub type Formatter =
  fn(BoundMessage, RuntimeContext) -> AnnotatedValue(String)

pub fn format(
  message: BoundMessage,
  context: RuntimeContext,
) -> AnnotatedValue(String) {
  let context = case message {
    model.Simple(_) -> FormatContext(context, list.new())
    model.Complex(declarations, _) -> FormatContext(context, declarations)
  }

  case message {
    model.Simple(pattern) -> context |> format_elements(pattern)
    model.Complex(_, elements) -> context |> format_elements(elements)
  }
  |> av.transpose_list
  |> av.map(string.join(_, ""))
}

fn format_elements(
  context: FormatContext,
  elements: List(BoundElement),
) -> List(AnnotatedValue(String)) {
  elements
  |> list.map(format_element(context, _))
}

fn format_element(
  context: FormatContext,
  element: BoundElement,
) -> AnnotatedValue(String) {
  case element {
    model.Text(s) -> av.annotate(s)
    model.Expression(e) -> context |> format_expression(e)
    model.Markup(m) -> context |> format_markup(m)
    model.Fallback(s) -> av.annotate(s)
  }
}

fn format_expression(
  context: FormatContext,
  expression: BoundExpression,
) -> AnnotatedValue(String) {
  case expression {
    model.BoundExpression(function, operand, _attributes) ->
      case function {
        gleam_option.Some(function) ->
          context
          |> invoke_function(function, operand)

        gleam_option.None ->
          context
          |> format_operand(operand)
      }

    model.BoundMatcher(_selectors, _variants) ->
      av.annotate("TODO format matcher expression")
  }
}

fn format_markup(
  context: FormatContext,
  markup: BoundMarkup,
) -> AnnotatedValue(String) {
  case markup {
    model.Standalone(name, options, attributes) ->
      context
      |> format_tag_parts("<", name, options, attributes, "/>")

    model.Open(name, options, attributes) ->
      context
      |> format_tag_parts("<", name, options, attributes, ">")

    model.Close(name, options, attributes) ->
      context
      |> format_tag_parts("/v", name, options, attributes, ">")
  }
}

fn format_tag_parts(
  context: FormatContext,
  open: String,
  name: BoundIdentifier,
  options: BoundOptions,
  attributes: List(BoundAttribute),
  close: String,
) -> AnnotatedValue(String) {
  let tag = context |> format_identifier(name)
  let opts = context |> format_options(options)
  let attrs = context |> format_attributes(attributes)

  av.map3(tag, opts, attrs, fn(tag, opts, attrs) {
    open <> tag <> opts <> attrs <> close
  })
}

fn format_options(
  context: FormatContext,
  options: BoundOptions,
) -> AnnotatedValue(String) {
  options
  |> dict.to_list()
  |> list.map(format_option(context, _))
  |> av.transpose_list
  |> av.map(string.join(_, " "))
}

fn format_option(
  context: FormatContext,
  option: #(BoundIdentifier, BoundOption),
) -> AnnotatedValue(String) {
  let #(key, value) = option

  let key = context |> format_identifier(key)
  let value = context |> format_value_ref(value)

  av.map2(key, value, fn(key, value) { key <> " = " <> value })
}

fn format_attributes(
  context: FormatContext,
  attributes: List(BoundAttribute),
) -> AnnotatedValue(String) {
  attributes
  |> list.map(format_attribute(context, _))
  |> av.transpose_list
  |> av.map(string.join(_, " "))
}

fn format_attribute(
  context: FormatContext,
  attribute: BoundAttribute,
) -> AnnotatedValue(String) {
  case attribute {
    model.FlagAttribute(v) -> context |> format_identifier(v)
    model.ValueAttribute(k, v) -> {
      let k = context |> format_identifier(k)
      let v = context |> format_value(v)

      av.map2(k, v, fn(k, v) { k <> "=" <> v })
    }
  }
}

fn format_value(
  _context: FormatContext,
  value: BoundValue,
) -> AnnotatedValue(String) {
  case value {
    model.VString(s) -> av.annotate(s)
    model.VNumber(n) -> av.annotate(float.to_string(n))
  }
}

fn format_variable(
  context: FormatContext,
  variable: BoundVariable,
) -> AnnotatedValue(String) {
  let fallback = variable_fallback(variable)
  context |> lookup(variable, fallback)
}

fn format_value_ref(
  context: FormatContext,
  value: BoundValueRef,
) -> AnnotatedValue(String) {
  case value {
    model.Literal(l) -> context |> format_value(l)
    model.Variable(v) -> context |> format_variable(v)
  }
}

fn format_operand(
  context: FormatContext,
  operand: BoundOperand,
) -> AnnotatedValue(String) {
  case operand {
    model.BoundValueRef(ref) ->
      case ref {
        model.Literal(l) -> context |> format_value(l)
        model.Variable(v) -> context |> format_variable(v)
      }
    model.NoOperand -> av.annotate("")
  }
}

fn format_identifier(
  _context: FormatContext,
  identifier: BoundIdentifier,
) -> AnnotatedValue(String) {
  let model.BoundIdentifier(name) = identifier
  av.annotate(name)
}

// Helpers...
fn lookup(
  context: FormatContext,
  variable: BoundVariable,
  fallback: AnnotatedValue(String),
) -> AnnotatedValue(String) {
  let model.BoundVariable(name) = variable

  case context |> lookup_declaration(name) {
    Ok(expression) -> expression |> av.and_then(invoke_expression(context, _))

    Error(_) ->
      case context |> lookup_inputs(name) {
        Ok(value) -> av.annotate(value)
        Error(_) -> fallback
      }
  }
}

fn lookup_declaration(
  context: FormatContext,
  key: String,
) -> Result(AnnotatedValue(BoundExpression), Nil) {
  let expression_if_key_matches = fn(declaration) {
    let model.BoundDeclaration(value_ref, expression) = declaration
    case value_ref == model.Variable(model.BoundVariable(key)) {
      True -> Ok(expression)
      False -> Error(Nil)
    }
  }

  let expressions =
    context.declarations
    |> list.filter_map(expression_if_key_matches)

  case expressions {
    [] -> Error(Nil)
    [first] -> Ok(av.annotate(first))
    [first, ..] -> {
      let diagnostics = [diagnostic.DuplicateDeclaration]
      Ok(av.annotate_with_diagnostics(first, diagnostics))
    }
  }
}

fn lookup_inputs(context: FormatContext, key: String) -> Result(String, Nil) {
  context.runtime.inputs |> dict.get(key)
}

fn invoke_expression(
  context: FormatContext,
  expression: BoundExpression,
) -> AnnotatedValue(String) {
  let assert model.BoundExpression(function, operand, _) = expression

  case function {
    gleam_option.Some(function) -> context |> invoke_function(function, operand)
    gleam_option.None -> context |> format_operand(operand)
  }
}

fn invoke_function(
  context: FormatContext,
  function: BoundFunction,
  operand: BoundOperand,
) -> AnnotatedValue(String) {
  let model.BoundFunction(name, options) = function
  let model.BoundIdentifier(name) = name

  let operand_fallback = operand_fallback(operand)
  let function_fallback = function_fallback(function, operand)

  let function = context.runtime.functions |> dict.get(name)

  let operand = case operand {
    model.BoundValueRef(ref) ->
      case ref {
        model.Literal(l) -> av.annotate(gleam_option.Some(l))
        model.Variable(v) ->
          context
          |> lookup(v, operand_fallback)
          |> av.map(model.VString)
          |> av.map(gleam_option.Some)
      }

    model.NoOperand -> av.annotate(gleam_option.None)
  }

  case function {
    Ok(function) -> operand |> av.and_then(function(_, options))
    Error(_) -> function_fallback
  }
}

fn operand_fallback(value: BoundOperand) -> AnnotatedValue(String) {
  case value {
    model.BoundValueRef(value) -> bound_value_ref_fallback(value)
    model.NoOperand -> av.annotate("")
  }
}

fn bound_value_ref_fallback(value: BoundValueRef) -> AnnotatedValue(String) {
  case value {
    model.Literal(l) -> literal_fallback(l)
    model.Variable(v) -> variable_fallback(v)
  }
}

fn variable_fallback(variable: BoundVariable) -> AnnotatedValue(String) {
  let model.BoundVariable(name) = variable

  let diagnostics = [diagnostic.UnresolvedVariable]
  av.annotate_with_diagnostics("{$" <> name <> "}", diagnostics)
}

fn function_fallback(
  function: BoundFunction,
  operand: BoundOperand,
) -> AnnotatedValue(String) {
  let diagnostics = [diagnostic.UnknownFunction]
  case operand {
    model.BoundValueRef(value) ->
      bound_value_ref_fallback(value)
      |> av.map_with_diagnostics(fn(a) { a }, diagnostics)

    model.NoOperand -> {
      let model.BoundFunction(identifier, _) = function
      let model.BoundIdentifier(name) = identifier
      av.annotate_with_diagnostics("{:" <> name <> "}", diagnostics)
    }
  }
}

fn literal_fallback(value: BoundValue) -> AnnotatedValue(String) {
  let value = case value {
    model.VString(s) -> s
    model.VNumber(n) -> float.to_string(n)
  }

  av.annotate("{|" <> value <> "|}")
}
