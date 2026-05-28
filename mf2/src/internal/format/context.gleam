import gleam/dict.{type Dict}

import value.{type Value}

pub type Context {
  Context(variables: Dict(String, Value))
}

pub fn from_dict(dict: Dict(String, Value)) -> Context {
  Context(dict)
}

pub fn get(self: Context, key: String) -> Result(Value, Nil) {
  let Context(variables) = self
  variables |> dict.get(key)
}

pub fn insert(self: Context, key: String, value: Value) -> Context {
  let Context(variables) = self
  let variables = variables |> dict.insert(key, value)
  Context(variables:)
}
