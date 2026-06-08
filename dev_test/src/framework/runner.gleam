import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import simplifile

import framework/tests_schema_ast.{
  type Assertion, type DefaultTestProperties, type RawTest, type RawTestFile,
  type Test, type TestFile,
} as test_ast
import framework/tests_schema_parser as tsp

pub type RunnerError(success, error, issues, parts) {
  UnexpectedFailure(error)
  UnexpectedSuccess(success)
  AssertionFailure(success, success)
  IssuesMismatch(issues, issues)
  PartsMismatch(parts, parts)
}

pub fn run_tests(
  from filename: String,
  ignoring ignored_tests: List(String),
  given given: fn(Test) -> precondition,
  when when: fn(precondition, Test) -> actual,
  then then: fn(actual, Test) -> Result(Nil, RunnerError(_, _, _, _)),
) {
  let assert Ok(content) = simplifile.read(filename)
  let assert Ok(raw_test_file) =
    json.parse(content, tsp.raw_test_file_decoder())
  let assert Ok(test_file) = resolve_test_file(raw_test_file)

  io.println(test_scenario_header(test_file))

  let tests = test_file.tests |> select_tests

  let result =
    tests
    |> list.filter(fn(test_) {
      let ignore = ignored_tests |> list.contains(test_.description)
      !ignore
    })
    |> list.try_each(run_test(given, when, then, _))

  let assert Ok(_) = result
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

fn run_test(
  given,
  when,
  then,
  test_: Test,
) -> Result(Nil, RunnerError(_, _, _, _)) {
  io.println(test_header(test_))

  given(test_)
  |> when(test_)
  |> then(test_)
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
