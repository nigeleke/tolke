import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/result

import internals/mf2/annotated_value.{type AnnotatedValue}
import internals/mf2/binder.{type Binder}
import internals/mf2/diagnostic
import internals/mf2/formatter.{type Formatter}
import internals/mf2/formatter/model.{
  type Message as FormattedMessage, type MessagePart,
}
import internals/mf2/parser.{type ParseError}
import internals/mf2/parser/ast.{type ParsedMessage}
import internals/mf2/runtime
import registry.{type Registry}

pub opaque type Message {
  Message(FormattedMessage)
}

pub fn format_to_parts(
  params variables: Dict(String, String),
) -> AnnotatedValue(Message) {
  todo
}

pub fn translate_string(
  engine: Engine,
  source: String,
  locale: String,
  params variables: Dict(String, String),
) -> AnnotatedValue(String) {
  case engine.parse(source) {
    Ok(message) -> translate_ast_message(engine, message, locale, variables)
    Error(_error) ->
      outcome.annotate_with_diagnostics("", [diagnostic.SyntaxError])
  }
}

fn translate_ast_message(
  engine: Engine,
  message: Message,
  locale: String,
  params inputs: Dict(String, String),
) -> AnnotatedValue(String) {
  let context = runtime.RuntimeContext(locale:, inputs:, functions: dict.new())

  message
  |> engine.bind(context)
  |> outcome.and_then(engine.format(_, context))
}
