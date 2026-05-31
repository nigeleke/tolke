import ast.{type Message as ParsedMessage}
import parser

import context.{type Context}
import issue
import outcome.{type Outcome}

import internal/bind
import internal/bind/context as bc
import internal/evaluate
import internal/evaluate/context as ec
import internal/format
import internal/format/context as fc
import internal/format/model.{type FormattedMessage, type FormattedMessagePart} as fm

pub type Error {
  ParseError
}

pub type Message =
  FormattedMessage

pub type MessagePart =
  FormattedMessagePart

pub fn parse(input: String) -> Outcome(Result(ParsedMessage, Error)) {
  case parser.parse(input) {
    Ok(message) -> outcome.pure(Ok(message))
    Error(_) -> outcome.pure_with_issue(Error(ParseError), issue.SyntaxError)
  }
}

pub fn format_to_string_and_parts(
  message: ParsedMessage,
  context: Context,
) -> Outcome(Message) {
  let context.Context(params) = context
  let bind_context = bc.from_dict(params)
  let evaluate_context = ec.from_dict(params)
  let format_context = fc.from_dict(params)

  message
  |> bind.bind(bind_context)
  |> outcome.flat_map(evaluate.evaluate(_, evaluate_context))
  |> outcome.map(format.format(_, format_context))
}

pub fn format(message: ParsedMessage, context: Context) -> Outcome(String) {
  format_to_string_and_parts(message, context)
  |> outcome.map(fn(message) {
    let fm.FormattedMessage(value, _) = message
    value
  })
}

pub fn format_to_parts(
  message: ParsedMessage,
  context: Context,
) -> Outcome(List(MessagePart)) {
  format_to_string_and_parts(message, context)
  |> outcome.map(fn(message) {
    let fm.FormattedMessage(_, parts) = message
    parts
  })
}
