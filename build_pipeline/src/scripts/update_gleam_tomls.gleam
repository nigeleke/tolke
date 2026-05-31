import gleam/io
import gleam/list
import gleam/string
import simplifile
import tom

pub fn update_gleam_tomls(version: String) {
  walk_for_gleam_tomls("..", version)
}

fn walk_for_gleam_tomls(path: String, version: String) {
  let assert Ok(files) = simplifile.get_files(path)

  files
  |> list.each(fn(path) {
    let assert Ok(is_file) = simplifile.is_file(path)
    let is_gleam_toml = path |> string.ends_with("gleam.toml")
    let is_not_build_target_path = !{ path |> string.contains("/build/") }

    case is_file && is_gleam_toml && is_not_build_target_path {
      True -> update_toml(path, version)
      False -> Nil
    }
  })
}

fn update_toml(path: String, required_version: String) {
  io.println("checking version: " <> path)

  let assert Ok(contents) = simplifile.read(path)
  let assert Ok(toml) = tom.parse(contents)

  let assert Ok(current_version) = toml |> tom.get_string(["version"])

  case required_version != current_version {
    True -> {
      io.println("changing " <> current_version <> " -> " <> required_version)

      let contents =
        contents
        |> string.split("\n")
        |> list.fold("", fn(acc, line) {
          let specifies_version = line |> string.starts_with("version")
          let is_current =
            line |> string.ends_with("\"" <> current_version <> "\"")
          case specifies_version && is_current {
            True -> acc <> "version = \"" <> required_version <> "\"\n"
            False -> acc <> line <> "\n"
          }
        })

      let assert Ok(_) = simplifile.write(to: path, contents:)
      Nil
    }

    False -> Nil
  }
}
