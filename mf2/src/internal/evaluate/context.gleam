import gleam/bool
import gleam/dict.{type Dict}
import gleam/int

import value.{type Value}

import internal/evaluate/model.{type EvaluatedValue}
import internal/unresolved_value

pub type Context {
  Context(variables: Dict(String, EvaluatedValue))
}

pub fn from_dict(dict: Dict(String, Value)) -> Context {
  let dict =
    dict
    |> dict.map_values(fn(_key, value) {
      let value = case value {
        value.String(s) -> model.VString(s)
        value.Int(i) -> model.VNumber(int.to_float(i))
        value.Float(n) -> model.VNumber(n)
        value.Bool(b) -> model.VString(bool.to_string(b))
        value.List(_) ->
          model.Unresolved(unresolved_value.UnresolvedVariable(
            "list supplied by client",
          ))
        value.Null ->
          model.Unresolved(unresolved_value.UnresolvedVariable(
            "null supplied by client",
          ))
      }

      value
    })

  Context(dict)
}

pub fn get(self: Context, key: String) -> Result(model.EvaluatedValue, Nil) {
  let Context(variables) = self
  variables |> dict.get(key)
}

pub fn insert(self: Context, key: String, value: EvaluatedValue) -> Context {
  let Context(variables) = self
  let variables = variables |> dict.insert(key, value)
  Context(variables:)
}
