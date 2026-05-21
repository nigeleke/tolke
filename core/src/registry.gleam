import gleam/dict

import mf2/parser/ast.{type Message}

pub type Registry {
  Registry(messages: dict.Dict(String, Message))
}
