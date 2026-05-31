import gleeunit

import framework/runner

import parser

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parser_parses_valid_messages_test() {
  runner.run_tests(
    "../dev_test/fixtures/tests/syntax.json",
    fn(_) { Nil },
    fn(_, test_) { parser.parse(test_.src) },
    fn(result, _) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(error) -> Error(runner.UnexpectedFailure(error))
      }
    },
  )
}

pub fn parser_rejects_invalid_messages_test() {
  runner.run_tests(
    "../dev_test/fixtures/tests/syntax-errors.json",
    fn(_) { Nil },
    fn(_, test_) { parser.parse(test_.src) },
    fn(result, _) {
      case result {
        Ok(ok) -> Error(runner.UnexpectedSuccess(ok))
        Error(error) ->
          case error {
            parser.NoMatch -> Ok(Nil)
            other -> Error(runner.UnexpectedFailure(other))
          }
      }
    },
  )
}
