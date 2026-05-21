import framework/runner

pub fn syntax_test() {
  let assert Ok(_) = runner.run_tests("test/fixtures/tests/syntax.json")
}

pub fn syntax_errors_test_ignore() {
  let assert Ok(_) = runner.run_tests("test/fixtures/tests/syntax-errors.json")
}
