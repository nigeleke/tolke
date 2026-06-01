import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option

import framework/runner
import framework/tests_schema_ast.{type ExpError, type ExpPart, type Test} as test_ast

import context.{type Context}
import issue
import mf2
import outcome.{type Outcome}
import value.{type Value}

import internal/format/model.{type FormattedMessage} as fm

pub fn run_tests(filename: String) {
  runner.run_tests(
    filename,
    fn(test_) { create_context(test_) },
    fn(context, test_) {
      let result = mf2.parse(test_.src)
      let assert Ok(message) = result.value
      message
      |> mf2.format_to_string_and_parts(context)
    },
    fn(actual, test_) {
      test_.assertions
      |> list.try_each(fn(assertion) {
        case assertion {
          test_ast.Exact(expected) -> assert_text(actual, expected)
          test_ast.Parts(expected) -> assert_parts(actual, expected)
          test_ast.Errors(expected) -> assert_errors(actual, expected)
        }
      })
    },
  )
}

fn create_context(test_: Test) -> Context {
  test_.params
  |> list.map(fn(param) {
    case param {
      test_ast.GenericVar(name, value) -> #(name, dynamic_to_value(value))
      test_ast.DatetimeVar(name, value) -> #(name, value.String(value))
    }
  })
  |> dict.from_list
  |> context.Context
}

fn dynamic_to_value(dynamic: Dynamic) -> Value {
  let decoder = case dynamic |> dynamic.classify {
    "String" -> decode.string |> decode.map(value.String)
    "Float" -> decode.float |> decode.map(value.Float)
    other -> {
      let expected = "need to decode: " <> other
      decode.failure(value.String(expected), expected)
    }
  }

  let assert Ok(result) = decode.run(dynamic, decoder)
  result
}

fn assert_text(actual: Outcome(FormattedMessage), response expected: String) {
  let outcome.Ok(actual, _) = actual |> outcome.map(fn(m) { m.value })

  case actual == expected {
    True -> Ok(Nil)
    False -> Error(runner.AssertionFailure(actual, expected))
  }
}

fn assert_parts(
  actual: Outcome(FormattedMessage),
  expected_parts: List(ExpPart),
) {
  let outcome.Ok(actual_parts, _) = actual |> outcome.map(fn(m) { m.parts })

  let expected_parts =
    expected_parts
    |> list.map(fn(part) {
      case echo part {
        test_ast.MarkupPart(test_ast.MarkupOpen, name, _, _) ->
          fm.MarkupOpen(name)
        test_ast.MarkupPart(test_ast.MarkupClose, name, _, _) ->
          fm.MarkupClose(name)
        test_ast.ExpressionPart(
          test_ast.StringExpression,
          _,
          _,
          _,
          option.Some(value),
        ) -> fm.Text(dynamic_to_value(value) |> value.to_string)
        _ -> todo
      }
    })

  case actual_parts == expected_parts {
    True -> Ok(Nil)
    False -> Error(runner.PartsMismatch(actual_parts, expected_parts))
  }
}

fn assert_errors(
  actual: Outcome(FormattedMessage),
  expected_errors: List(ExpError),
) {
  let actual_issues = actual.issues
  let expected_issues =
    expected_errors
    |> list.map(fn(error) {
      case error {
        test_ast.SyntaxError -> issue.SyntaxError
        test_ast.VariantKeyMismatch -> issue.VariantKeyMismatch
        test_ast.MissingFallbackVariant -> issue.MissingFallbackVariant
        test_ast.MissingSelectorAnnotation -> issue.MissingSelectorAnnotation
        test_ast.DuplicateDeclaration -> issue.DuplicateDeclaration
        test_ast.DuplicateOptionName -> issue.DuplicateOptionName
        test_ast.DuplicateVariant -> issue.DuplicateVariant
        test_ast.UnresolvedVariable -> issue.UnresolvedVariable
        test_ast.UnknownFunction -> issue.UnknownFunction
        test_ast.BadSelector -> issue.BadSelector
        test_ast.BadOperand -> issue.BadOperand
        test_ast.BadOption -> issue.BadOption
        test_ast.BadVariantKey -> issue.BadVariant
      }
    })

  case actual_issues == expected_issues {
    True -> Ok(Nil)
    False -> Error(runner.IssuesMismatch(actual_issues, expected_issues))
  }
}
