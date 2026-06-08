import gleam/dict
import gleam/list
import gleam/result
import gleeunit

import framework/runner

import parser

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parser_parses_valid_messages_test() {
  runner.run_tests(
    from: "../dev_test/fixtures/tests/syntax.json",
    ignoring: [],
    given: fn(_) { Nil },
    when: fn(_, test_) { parser.parse(test_.src) },
    then: fn(result, _) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(error) -> Error(runner.UnexpectedFailure(error))
      }
    },
  )
}

pub fn parser_rejects_invalid_messages_test() {
  runner.run_tests(
    from: "../dev_test/fixtures/tests/syntax-errors.json",
    ignoring: [],
    given: fn(_) { Nil },
    when: fn(_, test_) { parser.parse(test_.src) },
    then: fn(result, _) {
      case result {
        Ok(ok) -> Error(runner.UnexpectedSuccess(ok))
        Error(_) -> Ok(Nil)
      }
    },
  )
}

pub fn parser_will_parse_resource_messages_test() {
  let messages = [
    "{$points :number}",
    "
    .input {$count :number}
    .match $count
    one {{You have {$count} notification.}}
    *   {{You have {$count} notifications.}}",
    "
    .input {$char :string}
    .match $char
    | |  {{You entered a space character.}}
    |\\|| {{You entered a pipe character.}}
    *    {{You entered something else.}}",
  ]

  messages
  |> list.each(fn(message) {
    assert parser.parse(message) |> result.is_ok()
  })
}

pub fn resource_parser_will_parse_multiple_messages_test() {
  let resource =
    "
  score :=
    {$points :number}

  notifications :=
    .input {$count :number}
    .match $count
    one {{You have {$count} notification.}}
    *   {{You have {$count} notifications.}}

  character :=
    .input {$char :string}
    .match $char
    | |  {{You entered a space character.}}
    |\\|| {{You entered a pipe character.}}
    *    {{You entered something else.}}
  "
  let assert Ok(entries) = parser.parse_resource_as_dict(resource)

  assert entries |> dict.keys |> list.length == 3
  assert entries |> dict.has_key("score")
  assert entries |> dict.has_key("notifications")
  assert entries |> dict.has_key("character")
}
