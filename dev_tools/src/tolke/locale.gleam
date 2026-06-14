import gleam/option
import gleam/result
import gleam/string

import internal/locale/model.{
  type Language as LanguageModel, type Locale as LocaleModel,
}
import internal/locale/parser

pub type Language =
  LanguageModel

pub type Locale =
  LocaleModel

pub fn new(value: String) -> Result(Locale, Nil) {
  parser.language_tag()(value)
  |> result.map(fn(result) {
    case string.is_empty(result.rest) {
      True -> Ok(result.value)
      False -> Error(Nil)
    }
  })
  |> result.map_error(fn(_) { Nil })
  |> result.flatten
}

pub fn default() -> Locale {
  model.Locale(
    model.Language("en"),
    option.None,
    option.Some(model.Region("GB")),
  )
}

pub fn language(self: Locale) -> Language {
  self.language
}
