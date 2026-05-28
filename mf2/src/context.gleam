import gleam/dict.{type Dict}

import value.{type Value}

pub type Context {
  Context(params: Dict(String, Value))
}
