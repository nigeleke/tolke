pub opaque type Locale {
  Locale(String)
}

pub fn new(value: String) -> Result(Locale, Nil) {
  Ok(Locale(value))
}

pub fn default() -> Locale {
  Locale("en-GB")
}
