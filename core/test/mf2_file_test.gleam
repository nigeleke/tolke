import tolke/error
import tolke/locale

import internal/mf2_file

pub fn filename_locale_is_detected_test() {
  let assert Ok(expected_locale) = locale.new("ja-JP")
  let assert Ok(file) = mf2_file.new("/path/to/file/ja-JP.mf2")

  assert file |> mf2_file.locale() == expected_locale
  assert file |> mf2_file.language() == expected_locale |> locale.language()
}

pub fn filepath_locale_is_detected_test() {
  let assert Ok(expected_locale) = locale.new("de-DE")
  let assert Ok(file) = mf2_file.new("/path/de-DE/errors.mf2")

  assert file |> mf2_file.locale() == expected_locale
  assert file |> mf2_file.language() == expected_locale |> locale.language()
}

pub fn invalid_locale_returns_error_test() {
  let assert Error(error) = mf2_file.new("/path/wibble/wobble.mf2")
  assert error == error.InvalidLocale("/path/wibble/wobble.mf2")
}
