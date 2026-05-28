import gleam/dict.{type Dict}

import value.{type Value}

pub type Context {
  Context(variables: Dict(String, Value))
}

pub fn from_dict(dict: Dict(String, Value)) -> Context {
  Context(dict)
}
