import gleam/function
import gleam/list
import gleam/result
import gleam/string
import simplifile

import tolke/config.{type Config}
import tolke/error.{type Error}

import internal/mf2_file.{type Mf2File}

pub type Mf2Inventory {
  Mf2Inventory(List(Mf2File))
}

pub fn build(config: Config) -> Result(Mf2Inventory, Error) {
  config
  |> config.sources()
  |> list.map(walk)
  |> list.try_map(function.identity)
  |> result.map(list.flatten)
  |> result.map(Mf2Inventory)
}

fn walk(path: String) -> Result(List(Mf2File), Error) {
  case simplifile.is_file(path) {
    Ok(True) ->
      mf2_file.new(path)
      |> result.map(list.wrap)

    Ok(False) ->
      path
      |> simplifile.get_files()
      |> result.map_error(fn(_) { error.InvalidPath(path) })
      |> result.map(fn(files) {
        files
        |> list.filter(string.ends_with(_, ".mf2"))
        |> list.try_map(mf2_file.new)
      })
      |> result.flatten

    Error(_) -> Error(error.InvalidPath(path))
  }
}
