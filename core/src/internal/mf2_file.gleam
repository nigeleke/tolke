import filepath
import gleam/list

import tolke/error.{type Error}
import tolke/locale.{type Language, type Locale}

pub opaque type Mf2File {
  Mf2File(path: String, locale: Locale)
}

pub fn new(path: String) -> Result(Mf2File, Error) {
  let parts =
    case path |> filepath.expand() {
      Ok(value) -> value
      Error(_) -> path
    }
    |> filepath.strip_extension
    |> filepath.split

  let locale =
    parts
    |> list.reverse
    |> list.filter_map(locale.new)
    |> list.first

  case locale {
    Ok(locale) -> Ok(Mf2File(path:, locale:))
    Error(_) -> Error(error.InvalidLocale(path))
  }
}

pub fn locale(self: Mf2File) -> Locale {
  self.locale
}

pub fn language(self: Mf2File) -> Language {
  locale.language(self.locale)
}
