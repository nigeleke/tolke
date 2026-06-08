import gleam/float
import gleam/list
import gleam/option
import gleam/string

import internal/evaluate/model.{
  type EvaluatedAttribute, type EvaluatedElement, type EvaluatedMarkup,
  type EvaluatedMessage, type EvaluatedValue,
} as em
import internal/format/context.{type Context}
import internal/format/model.{
  type FormattedAttribute, type FormattedMessage, type FormattedMessagePart,
}
import internal/unresolved_value.{type UnresolvedValue}

pub fn format(message: EvaluatedMessage, context: Context) -> FormattedMessage {
  let parts = format_to_parts(message, context)
  let value = parts_to_string(parts, context)
  model.FormattedMessage(value:, parts:)
}

fn format_to_parts(
  message: EvaluatedMessage,
  _context: Context,
) -> List(FormattedMessagePart) {
  let non_empty = fn(part) -> Bool { part != model.Text("") }

  let em.EvaluatedMessage(parts) = message

  format_elements(parts)
  |> list.filter(non_empty)
}

fn parts_to_string(
  parts: List(FormattedMessagePart),
  _context: Context,
) -> String {
  parts
  |> list.filter_map(fn(part) {
    case part {
      model.Text(s) -> Ok(s)
      model.MarkupOpen(_, _) -> Error(Nil)
      model.MarkupClose(_) -> Error(Nil)
      model.MarkupStandalone(_, _) -> Error(Nil)
    }
  })
  |> string.join("")
}

fn format_elements(
  elements: List(EvaluatedElement),
) -> List(FormattedMessagePart) {
  elements
  |> list.map(format_element)
}

fn format_element(element: EvaluatedElement) -> FormattedMessagePart {
  case element {
    em.Text(text) -> model.Text(text)
    em.Value(value) -> format_value(value)
    em.Markup(markup) -> format_markup(markup)
  }
}

fn format_value(value: EvaluatedValue) -> FormattedMessagePart {
  case value {
    em.VString(s) -> model.Text(s)
    em.VNumber(n) -> model.Text(float.to_string(n))
    em.Unresolved(u) -> format_unresolved(u)
  }
}

fn format_unresolved(value: UnresolvedValue) -> FormattedMessagePart {
  case value {
    unresolved_value.UnresolvedVariable(name) -> "{$" <> name <> "}"

    unresolved_value.UnresolvedFunction(name, operand) ->
      case operand {
        option.None -> "{:" <> name <> "}"

        option.Some(unresolved_value.Variable(variable_name)) ->
          "{$" <> variable_name <> " :" <> name <> "}"

        option.Some(unresolved_value.Literal(literal)) ->
          "{|" <> literal <> "|}"
      }
  }
  |> model.Text
}

fn format_markup(markup: EvaluatedMarkup) -> FormattedMessagePart {
  case markup {
    em.Standalone(name, attrs) ->
      model.MarkupStandalone(name, format_attributes(attrs))

    em.Open(name, attrs) -> model.MarkupOpen(name, format_attributes(attrs))

    em.Close(name) -> model.MarkupClose(name)
  }
}

fn format_attributes(
  attrs: List(EvaluatedAttribute),
) -> List(FormattedAttribute) {
  attrs
  |> list.map(format_attribute)
}

fn format_attribute(attribute: EvaluatedAttribute) -> FormattedAttribute {
  case attribute {
    em.Flag(name) -> model.Flag(name)
    em.KeyValue(name, value) -> model.KeyValue(name, format_value(value))
  }
}
