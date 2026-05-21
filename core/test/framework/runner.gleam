import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import simplifile

import mf2.{type Engine, type Error as EngineError}
import mf2/annotated_value.{type AnnotatedValue} as av

import framework/tests_schema_ast.{
  type Assertion, type DefaultTestProperties, type RawTest, type RawTestFile,
  type Test, type TestFile as TestFile,
} as test_ast
import framework/tests_schema_parser as tsp

pub type RunnerError {
  UnexpectedFailure(List(EngineError))
  UnexpectedSuccess(String)
  ExactAssertionError(String, String)
}

pub fn run_tests(filename: String) {
  let assert Ok(content) = simplifile.read(filename)
  let assert Ok(raw_test_file) =
    json.parse(content, tsp.raw_test_file_decoder())
  let assert Ok(test_file) = resolve_test_file(raw_test_file)

  io.println(test_scenario_header(test_file))

  let engine = mf2.engine()
  let tests = test_file.tests |> select_tests

  tests
  |> list.try_each(run_test(engine, _))
}

fn select_tests(tests: List(Test)) -> List(Test) {
  let tests_marked_as_only =
    tests
    |> list.filter(fn(test_) { test_.only })

  case tests_marked_as_only {
    [] -> tests
    _ -> tests_marked_as_only
  }
}

fn test_scenario_header(file: TestFile) -> String {
  "Scenario: " <> file.scenario <> " - " <> file.description
}

fn run_test(engine: Engine, test_: Test) -> Result(Nil, RunnerError) {
  io.println(test_header(echo test_))

  let params = get_params(test_)
  let result = engine |> mf2.translate_string(test_.src, test_.locale, params)

  test_.assertions
  |> list.try_each(fn(assertion) {
    case assertion {
      test_ast.Exact(expected) -> result |> assert_response(expected)
      test_ast.Parts(expected_parts) -> result |> assert_parts(expected_parts)
      test_ast.Errors(expected_errors) ->
        result |> assert_errors(expected_errors)
    }
  })
}

fn get_params(test_: Test) -> dict.Dict(String, String) {
  test_.params
  |> list.map(fn(param) {
    case param {
      test_ast.GenericVar(name, value) -> #(name, dynamic_to_string(value))
      test_ast.DatetimeVar(name, value) -> #(name, value)
    }
  })
  |> dict.from_list
}

fn assert_response(
  result: AnnotatedValue(String),
  response expected: String,
) -> Result(Nil, RunnerError) {
  let av.AnnotatedValue(actual, _) = result

  case actual == expected {
    True -> Ok(Nil)
    False -> Error(ExactAssertionError(actual, expected))
  }
}

fn assert_parts(
  _result: AnnotatedValue(String),
  expected_parts: List(test_ast.ExpPart),
) {
  let _ = echo "expected parts"
  let _ = echo expected_parts
  Error(UnexpectedSuccess("Expecting parts - dont know how to test yet"))
}

fn assert_errors(
  _result: AnnotatedValue(String),
  expected_errors: List(test_ast.ExpError),
) {
  let _ = echo "expected errors"
  let _ = echo expected_errors
  Error(UnexpectedSuccess("Expecting errors - dont know how to test yet"))
}

pub fn dynamic_to_string(dynamic: Dynamic) -> String {
  let decoder = case dynamic |> dynamic.classify {
    "String" -> decode.string
    other -> {
      let expected = "need to decode: " <> other
      decode.failure(expected, expected)
    }
  }

  let assert Ok(result) = decode.run(dynamic, decoder)
  result
}

fn test_header(test_: Test) -> String {
  test_.description
}

pub type ResolveError {
  MissingLocale
  MissingSrc
  MissingAssertion
}

fn resolve_test_file(file: RawTestFile) -> Result(TestFile, ResolveError) {
  let defaults =
    file.default_test_properties
    |> option.unwrap(test_ast.DefaultTestProperties(
      locale: option.None,
      src: option.None,
      bidi_isolation: option.None,
      params: option.None,
      tags: option.None,
      exp: option.None,
      exp_parts: option.None,
      exp_errors: option.None,
    ))

  let scenario = file.scenario |> option.unwrap("**** >> scenario << ****")
  let description = file.description |> option.unwrap("")

  file.tests
  |> list.map(resolve_test(defaults, _))
  |> result.all
  |> result.map(fn(tests) { test_ast.TestFile(scenario:, description:, tests:) })
}

fn resolve_test(
  defaults: DefaultTestProperties,
  test_: RawTest,
) -> Result(Test, ResolveError) {
  let description =
    test_.description
    |> option.unwrap("test: " <> test_.src |> option.unwrap("[no src]"))

  let locale = test_.locale |> option.unwrap("en-US")

  use src <- result.try(required(test_.src, defaults.src, MissingSrc))

  let params =
    first_some(test_.params, defaults.params)
    |> option.unwrap([])

  let tags =
    first_some(test_.tags, defaults.tags)
    |> option.unwrap([])

  use assertions <- result.try(resolve_assertions(defaults, test_))

  let only =
    test_.only
    |> option.unwrap(False)

  Ok(test_ast.Test(
    description:,
    locale:,
    src:,
    params:,
    tags:,
    assertions:,
    only:,
  ))
}

fn resolve_assertions(
  defaults: DefaultTestProperties,
  test_: RawTest,
) -> Result(List(Assertion), ResolveError) {
  let exp =
    first_some(test_.exp, defaults.exp)
    |> option.map(test_ast.Exact)

  let exp_parts =
    first_some(test_.exp_parts, defaults.exp_parts)
    |> option.map(test_ast.Parts)

  let exp_errors =
    first_some(test_.exp_errors, defaults.exp_errors)
    |> option.map(test_ast.Errors)

  [exp, exp_parts, exp_errors]
  |> list.filter_map(option.to_result(_, Nil))
  |> fn(exps) {
    case list.is_empty(exps) {
      True -> Error(MissingAssertion)
      False -> Ok(exps)
    }
  }
}

fn required(value: Option(a), default: Option(a), error: e) -> Result(a, e) {
  case first_some(value, default) {
    option.Some(value) -> Ok(value)
    option.None -> Error(error)
  }
}

fn first_some(first: Option(a), second: Option(a)) -> Option(a) {
  case first {
    option.Some(_) -> first
    option.None -> second
  }
}
