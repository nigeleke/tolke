pub type FormattedMessage {
  FormattedMessage(value: String, parts: List(FormattedMessagePart))
}

pub type FormattedMessagePart {
  Text(String)
  MarkupOpen(String)
  MarkupClose(String)
}
