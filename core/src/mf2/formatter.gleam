import gleam/dict
import gleam/float
import gleam/list
import gleam/option as gleam_option
import gleam/string

import mf2/annotated_value.{type AnnotatedValue} as av
import mf2/binder/model.{
  type BoundDeclaration, type BoundElement, type BoundExpression,
  type BoundFunction, type BoundMessage, type BoundOperand, type BoundValue,
  type BoundValueRef, type BoundVariable,
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
  |> list.map(fn(e) { format_element(context, e) })
}

fn format_element(
  context: FormatContext,
  element: BoundElement,
) -> AnnotatedValue(String) {
  case element {
    model.Text(s) -> av.annotate(s)
    model.Expression(e) -> context |> format_expression(e)
    model.Markup(_) -> av.annotate("TODO format markup")
    model.Fallback(s) -> av.annotate(s)
  }
}

fn format_expression(
  context: FormatContext,
  expression: BoundExpression,
) -> AnnotatedValue(String) {
  case expression {
    model.BoundExpression(_function, operand, _attributes) ->
      case operand {
        model.BoundValueRef(ref) -> context |> format_value_ref(ref)
        model.NoOperand -> av.annotate("")
      }

    model.BoundMatcher(_selectors, _variants) ->
      av.annotate("TODO format matcher expression")
  }
}

fn format_value_ref(
  context: FormatContext,
  operand: BoundValueRef,
) -> AnnotatedValue(String) {
  case operand {
    model.Literal(l) -> context |> format_value(l)
    model.Variable(v) -> context |> format_variable(v)
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
  context |> lookup(variable)
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

// Helpers...
fn lookup(
  context: FormatContext,
  variable: BoundVariable,
) -> AnnotatedValue(String) {
  let model.BoundVariable(name) = variable
  let fallback = "{$" <> name <> "}"

  case context |> lookup_declaration(name) {
    Ok(expression) -> expression |> av.and_then(invoke_expression(context, _))

    Error(_) ->
      case context |> lookup_inputs(name) {
        Ok(value) -> av.annotate(value)
        Error(_) -> {
          let diagnostics = [diagnostic.UnresolvedVariable]
          av.annotate_with_diagnostics(fallback, diagnostics)
        }
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

  let function = context.runtime.functions |> dict.get(name)

  let operand = case operand {
    model.BoundValueRef(ref) ->
      case ref {
        model.Literal(l) -> av.annotate(gleam_option.Some(l))
        model.Variable(v) ->
          context
          |> lookup(v)
          |> av.map(model.VString)
          |> av.map(gleam_option.Some)
      }

    model.NoOperand -> av.annotate(gleam_option.None)
  }

  case function {
    Ok(function) -> operand |> av.and_then(function(_, options))
    Error(_) -> av.annotate_with_diagnostics(name, [diagnostic.UnknownFunction])
  }
}
