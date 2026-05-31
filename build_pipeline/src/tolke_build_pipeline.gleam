import gleam/io
import scripts/generate_version
import scripts/update_gleam_tomls

pub fn main() {
  io.println("tolke pre-build tasks")
  let version = generate_version.generate_version()
  update_gleam_tomls.update_gleam_tomls(version)
}
