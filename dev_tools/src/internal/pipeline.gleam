import gleam/result

import tolke/error.{type Error}

import internal/config.{type Config}
import internal/diagnostics.{type Diagnostics}
import internal/document.{type Document}
import internal/issue.{type Issue}
import internal/mf2_file.{type Mf2File}

pub type Pipeline {
  Pipeline(
    config: Config,
    mf2_files: List(Mf2File),
    documents: List(Document),
    issues: List(Issue),
  )
}

pub fn run_from_config_file(path: String) -> Result(Diagnostics, Error) {
  path
  |> config.from_toml_file
  |> result.try(run)
}

pub fn run_from_config_string(content: String) -> Result(Diagnostics, Error) {
  content
  |> config.from_toml_string
  |> result.try(run)
}

fn run(_config: Config) -> Result(Diagnostics, Error) {
  Ok(diagnostics.Diagnostics)
}
