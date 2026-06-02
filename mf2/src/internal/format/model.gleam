pub type FormattedMessage {
  FormattedMessage(value: String, parts: List(FormattedMessagePart))
}

pub type FormattedMessagePart {
  Text(String)
  MarkupOpen(String, List(FormattedAttribute))
  MarkupClose(String)
}

pub type FormattedAttribute {
  Flag(String)
  KeyValue(String, FormattedMessagePart)
}
