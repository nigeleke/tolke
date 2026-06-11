import tolke/error.{type Error}
import tolke/locale.{type Locale}

pub opaque type Mf2File {
  Mf2File(path: String, locale: Locale)
}

pub fn new(path: String) -> Result(Mf2File, Error) {
  Ok(Mf2File(path, locale.default()))
}
