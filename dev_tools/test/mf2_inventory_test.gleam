import gleam/list
import tolke/config

import internal/mf2_inventory

pub fn will_find_mf2_files_in_path_test() {
  let assert Ok(mf2_inventory.Mf2Inventory(files)) =
    config.default()
    |> config.with_source("./test/fixtures/inventory_test/")
    |> mf2_inventory.build()

  assert list.length(files) == 6
}

pub fn will_ignore_non_mf2_files_in_path_test() {
  let assert Ok(mf2_inventory.Mf2Inventory(files)) =
    config.default()
    |> config.with_source("./test/fixtures/inventory_test/de/")
    |> mf2_inventory.build()

  assert list.length(files) == 1
}

pub fn will_allow_path_to_be_a_file_test() {
  let assert Ok(mf2_inventory.Mf2Inventory(files)) =
    config.default()
    |> config.with_source("./test/fixtures/inventory_test/en/en-GB/errors.mf2")
    |> config.with_source("./test/fixtures/inventory_test/it/it-IT/errors.mf2")
    |> mf2_inventory.build()

  assert list.length(files) == 2
}
