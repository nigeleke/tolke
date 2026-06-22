import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import simplifile
import tom.{type Toml}

import tolke/error.{type Error}
import tolke/locale.{type Locale}

pub opaque type Config {
  Config(
    sources: List(String),
    canonical: Locale,
    primaries: List(Locale),
    target: String,
  )
}

pub fn from_toml_file(path: String) -> Result(Config, Error) {
  path
  |> simplifile.read()
  |> result.map_error(fn(_) { error.InvalidPath(path) })
  |> result.map(from_toml_string)
  |> result.flatten
}

pub fn from_toml_string(value: String) -> Result(Config, Error) {
  tom.parse(value)
  |> result.map_error(fn(_) { error.InvalidToml })
  |> result.try(fn(toml) {
    use sources <- result.try(get_strings(toml, "mf2sources"))
    use canonical <- result.try(get_locale(toml, "canonical"))
    use primaries <- result.try(get_locales(toml, "primaries"))
    use target <- result.try(get_string(toml, "target", "./src/generated/tolke"))

    Ok(Config(
      sources: sources,
      canonical: canonical,
      primaries: primaries,
      target: target,
    ))
  })
}

pub fn default() -> Config {
  Config([], locale.default(), [], "")
}

pub fn with_source(self: Config, source: String) -> Config {
  let Config(sources, _, _, _) = self
  Config(..self, sources: [source, ..sources])
}

type TomlEntries =
  Dict(String, Toml)

fn get_strings(toml: TomlEntries, key: String) -> Result(List(String), Error) {
  toml
  |> tom.get_array(key_parts(key))
  |> result.unwrap([])
  |> list.try_map(tom.as_string)
  |> result.map_error(fn(_) { error.InvalidToml })
}

fn key_parts(key: String) -> List(String) {
  ["tools", "tolke", key]
}

fn get_locale(toml: TomlEntries, key: String) -> Result(Locale, Error) {
  case
    toml
    |> tom.get_string(key_parts(key))
  {
    Ok(value) -> string_to_locale(value)
    Error(_) -> Ok(locale.default())
  }
}

fn string_to_locale(value: String) -> Result(Locale, Error) {
  locale.new(value)
  |> result.map_error(fn(_) { error.InvalidLocale(value) })
}

fn get_locales(toml: TomlEntries, key: String) -> Result(List(Locale), Error) {
  toml
  |> get_strings(key)
  |> result.map_error(fn(_) { error.InvalidToml })
  |> result.map(list.try_map(_, string_to_locale))
  |> result.flatten
}

fn get_string(
  toml: TomlEntries,
  key: String,
  default: String,
) -> Result(String, Error) {
  case toml |> tom.get_string(key_parts(key)) {
    Ok(value) -> Ok(value)
    Error(error) ->
      case error {
        tom.NotFound(_) -> Ok(default)
        tom.WrongType(_, _, _) -> Error(error.InvalidToml)
      }
  }
}

pub fn sources(self: Config) -> List(String) {
  case self.sources {
    [] -> ["./i18n"]
    rest -> rest
  }
}

pub fn canonical(self: Config) -> Locale {
  self.canonical
}

pub fn primaries(self: Config) -> List(Locale) {
  self.primaries
}

pub fn target(self: Config) -> String {
  case self.target {
    "" -> "./src/generated/tolke"
    other -> other
  }
}
