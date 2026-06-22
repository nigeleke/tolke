import gleeunit/should

import internal/config
import internal/pipeline

pub fn pipeline_will_read_config_test() {
  let content =
    "
[tools.tolke]
mf2sources = [\"./i18n/\"]
canonical = \"en-GB\"
primaries = []
target = \"./generated/\"
"

  pipeline.run_from_config_string(content)
  |> should.be_ok()
}

pub fn pipeline_will_determine_source_mf2_files_test() {
  todo
}

pub fn pipeline_will_report_mf2_file_parsing_problems_test() {
  todo
}

pub fn pipeline_will_build_locale_bundles_test() {
  todo
}

pub fn pipeline_will_report_missing_canonical_test() {
  todo
}

pub fn pipeline_will_report_missing_primaries_test() {
  todo
}

pub fn pipeline_will_report_orphaned_locales_test() {
  todo
}

pub fn pipeline_will_report_all_locales_duplicate_message_keys_test() {
  todo
}

pub fn pipeline_will_report_canonical_message_keys_missing_in_primary_test() {
  todo
}

pub fn pipeline_will_report_primary_mismatched_signature_against_canonical_test() {
  todo
}

pub fn pipeline_will_report_variant_mismatched_signature_against_canonical_test() {
  todo
}

pub fn pipeline_will_report_variant_mismatched_signature_against_primary_test() {
  todo
}
