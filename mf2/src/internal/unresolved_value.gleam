import gleam/option.{type Option}

pub type UnresolvedValue {
  UnresolvedVariable(String)
  UnresolvedFunction(name: String, operand: Option(UnresolvedOperand))
}

pub type UnresolvedOperand {
  Variable(String)
  Literal(String)
}
