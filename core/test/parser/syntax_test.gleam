import gleam/dynamic/decode.{type Decoder, type Dynamic}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleeunit
import simplifile

pub type TestSuite {
  TestSuite(scenario: String, tests: List(TestCase))
}

pub type TestCase {
  TestCase(
    description: Option(String),
    src: String,
    params: Option(List(Param)),
    exp: Option(String),
    exp_errors: Option(List(Error)),
    locale: Option(String),
    bidi_isolation: Option(String),
    exp_parts: Option(List(Dynamic)),
  )
}

pub type Param {
  Param(name: String, value: Dynamic)
}

pub type Error {
  Error(type_: String)
}

pub fn main() {
  gleeunit.main()
}

pub fn syntax_test() {
  let assert Ok(content) = simplifile.read("test/fixtures/syntax.json")
  let assert Ok(suite) = json.parse(from: content, using: suite_decoder())

  io.println("Loaded Scenario: " <> suite.scenario)

  list.each(suite.tests, fn(t) { invoke_parser(t.src) })
}

fn suite_decoder() -> decode.Decoder(TestSuite) {
  use scenario <- decode.field("scenario", decode.string)
  use tests <- decode.field("tests", decode.list(test_case_decoder()))
  decode.success(TestSuite(scenario:, tests:))
}

pub fn test_case_decoder() -> decode.Decoder(TestCase) {
  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use src <- decode.field("src", decode.string)

  use params <- decode.optional_field(
    "params",
    option.None,
    decode.optional(params_decoder()),
  )

  use exp <- decode.optional_field(
    "exp",
    option.None,
    decode.optional(decode.string),
  )

  use exp_errors <- decode.optional_field(
    "expErrors",
    option.None,
    decode.optional(decode.list(error_decoder())),
  )

  use locale <- decode.optional_field(
    "locale",
    option.None,
    decode.optional(decode.string),
  )

  use bidi_isolation <- decode.optional_field(
    "bidiIsolation",
    option.None,
    decode.optional(decode.string),
  )

  use exp_parts <- decode.optional_field(
    "expParts",
    option.None,
    decode.optional(decode.list(decode.dynamic)),
  )

  decode.success(TestCase(
    description:,
    src:,
    params:,
    exp:,
    exp_errors:,
    locale:,
    bidi_isolation:,
    exp_parts:,
  ))
}

fn params_decoder() -> Decoder(List(Param)) {
  decode.list(param_decoder())
}

fn param_decoder() -> Decoder(Param) {
  use name <- decode.field("name", decode.string)
  use value <- decode.field("value", decode.dynamic)
  decode.success(Param(name, value))
}

fn error_decoder() -> Decoder(Error) {
  use type_ <- decode.field("type", decode.string)
  decode.success(Error(type_))
}

fn invoke_parser(src: String) -> String {
  io.println(src)
  src
}
