import gleam/result
import tolke/error.{type Error}

import internal/pipeline

pub fn main() -> Result(Nil, Error) {
  use _ <- result.try(pipeline.run_from_config_file("./gleam.toml"))
  Ok(Nil)
}
