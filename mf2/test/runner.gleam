import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list

import framework/runner
import framework/tests_schema_ast.{type ExpError, type ExpPart, type Test} as test_ast

import context.{type Context}
import diagnostic
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
    False -> Error(runner.ExactAssertionFailure(actual, expected))
  }
}

fn assert_parts(
  actual: Outcome(FormattedMessage),
  expected_parts: List(ExpPart),
) {
  let outcome.Ok(actual, _) = echo actual |> outcome.map(fn(m) { m.parts })

  let assert Ok(comparison_list) = list.strict_zip(actual, expected_parts)

  comparison_list
  |> list.try_each(fn(zipped_entry) {
    let #(actual, expected) = zipped_entry
    let expected = case expected {
      test_ast.MarkupPart(test_ast.MarkupOpen, name, _, _) ->
        fm.MarkupOpen(name)
      _ -> todo
    }

    case actual == expected {
      True -> Ok(Nil)
      False -> Error(runner.ExpectedPartMismatch(actual, expected))
    }
  })
}

fn assert_errors(
  actual: Outcome(FormattedMessage),
  expected_errors: List(ExpError),
) {
  let actual = echo actual.diagnostics
  let _ = echo expected_errors

  let assert Ok(comparison_list) = list.strict_zip(actual, expected_errors)

  comparison_list
  |> list.try_each(fn(zipped_entry) {
    let #(actual, expected) = zipped_entry
    let expected = case expected {
      test_ast.SyntaxError -> diagnostic.SyntaxError
      test_ast.VariantKeyMismatch -> diagnostic.VariantKeyMismatch
      test_ast.MissingFallbackVariantS -> diagnostic.MissingFallbackVariant
      test_ast.MissingSelectorAnnotation -> diagnostic.MissingSelectorAnnotation
      test_ast.DuplicateDeclaration -> diagnostic.DuplicateDeclaration
      test_ast.DuplicateOptionName -> diagnostic.DuplicateOptionName
      test_ast.DuplicateVariant -> diagnostic.DuplicateVariant
      test_ast.UnresolvedVariable -> diagnostic.UnresolvedVariable
      test_ast.UnknownFunction -> diagnostic.UnknownFunction
      test_ast.BadSelector -> diagnostic.BadSelector
      test_ast.BadOperand -> diagnostic.BadOperand
      test_ast.BadOption -> diagnostic.BadOption
      test_ast.BadVariantKey -> diagnostic.BadVariantKey
    }

    case actual == expected {
      True -> Ok(Nil)
      False -> Error(runner.ExpectedDiagnosticMismatch(actual, expected))
    }
  })
}
