import value.{type Value}

pub type FormattedMessage {
  FormattedMessage(value: String, parts: List(FormattedMessagePart))
}

pub type FormattedMessagePart {
  Text(String)
  Value(Value)
  MarkupOpen(String)
  MarkupClose(String)
}
