import internal/unresolved_value.{type UnresolvedValue}

pub type EvaluatedMessage {
  EvaluatedMessage(List(EvaluatedElement))
}

pub type EvaluatedElement {
  Text(String)
  Value(EvaluatedValue)
  Markup(EvaluatedMarkup)
}

pub type EvaluatedValue {
  VString(String)
  VNumber(Float)
  Unresolved(UnresolvedValue)
}

pub type EvaluatedMarkup {
  Standalone(String, List(EvaluatedAttribute))
  Open(String, List(EvaluatedAttribute))
  Close(String)
}

pub type EvaluatedAttribute {
  Flag(String)
  KeyValue(String, EvaluatedValue)
}
