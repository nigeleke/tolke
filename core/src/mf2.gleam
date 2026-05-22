import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/result

import mf2/annotated_value.{type AnnotatedValue} as av
import mf2/binder.{type Binder}
import mf2/diagnostic
import mf2/formatter.{type Formatter}
import mf2/parser.{type ParseError}
import mf2/parser/ast.{type Message}
import mf2/runtime
import registry.{type Registry}

pub type Engine {
  Engine(
    registry: Option(Registry),
    bind: Binder,
    format: Formatter,
    parse: fn(String) -> Result(Message, ParseError),
  )
}

pub type Error {
  RegistryNotProvided
  MissingKey(String)
}

pub fn engine() -> Engine {
  Engine(option.None, binder.bind, formatter.format, parser.parse)
}

pub fn with_registry(engine: Engine, registry: Registry) -> Engine {
  Engine(..engine, registry: option.Some(registry))
}

pub fn default_context(locale: String) {
  runtime.RuntimeContext(locale, inputs: dict.new(), functions: dict.new())
}

pub fn translate(
  engine: Engine,
  key: String,
  locale: String,
  params variables: Dict(String, String),
) -> Result(AnnotatedValue(String), Error) {
  use registry <- result.try(
    engine.registry |> option.to_result(RegistryNotProvided),
  )

  case registry.messages |> dict.get(key) {
    Ok(message) -> Ok(translate_ast_message(engine, message, locale, variables))
    Error(_) -> Error(MissingKey(key))
  }
}

pub fn translate_string(
  engine: Engine,
  source: String,
  locale: String,
  params variables: Dict(String, String),
) -> AnnotatedValue(String) {
  case engine.parse(source) {
    Ok(message) -> translate_ast_message(engine, message, locale, variables)
    Error(_error) -> av.annotate_with_diagnostics("", [diagnostic.SyntaxError])
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
  |> av.and_then(engine.format(_, context))
}
