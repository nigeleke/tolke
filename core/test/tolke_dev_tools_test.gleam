import gleam/list
import gleeunit

import tolke/config
import tolke/locale

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn tolke_will_use_gleam_toml_entries_test() {
  let content =
    "
  [tools.tolke]
  mf2sources = [\"./path1\", \"./path2\"]
  canonical = \"de-DE\"
  primaries = [\"fr-FR\", \"it-IT\"]
  target = \"project/src/tolke\"
  "

  let assert Ok(config) = config.from_toml_string(content)

  assert config
    |> config.sources()
    == ["./path1", "./path2"]

  assert Ok(config |> config.canonical()) == locale.new("de-DE")

  assert Ok(config |> config.primaries())
    == ["fr-FR", "it-IT"] |> list.try_map(locale.new)

  assert config |> config.target() == "project/src/tolke"
}

pub fn tolke_will_default_gleam_toml_entries_test() {
  let assert Ok(config) = config.from_toml_string("")

  assert config |> config.sources() == ["./i18n"]

  assert Ok(config |> config.canonical()) == locale.new("en-GB")

  assert Ok(config |> config.primaries()) == [] |> list.try_map(locale.new)

  assert config |> config.target() == "./src/generated/tolke"
}
