import gleam/option.{type Option}

pub type Locale {
  Locale(language: Language, script: Option(Script), region: Option(Region))
}

pub type Language {
  Language(String)
}

pub type Region {
  Region(String)
}

pub type Script {
  Script(String)
}
