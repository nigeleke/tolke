import gleam/list
import gleeunit/should

import tolke/locale

pub fn valid_locales_test() {
  let locales = [
    "en",
    "it",
    "fr",
    "de",
    "zh",
    "en-GB",
    "en-US",
    "it-IT",
    "fr-CA",
    "pt-BR",
    "zh-Hans",
    "zh-Hant",
    "sr-Latn",
    "sr-Cyrl",
    "zh-Hans-CN",
    "zh-Hant-TW",
    "sr-Latn-RS",
    "sr-Cyrl-RS",
  ]

  locales
  |> list.each(fn(locale) {
    let result = locale.new(locale)
    result |> should.be_ok
  })
}

pub fn invalid_locales_ignore() {
  let locales = [
    "-GB",
    "-US",
    "en-GB-Latn",
    "zh-CN-Hans",
    "en--",
    "en-GB-",
    "-en",
    "en-LATIN",
    "en-La",
    "en-Lat",
    "en-G",
    "en-GBR",
    "en-UnitedKingdom",
    "en_GB",
    "en.GB",
    "en GB",
    "en--GB",
    "zh---Hans",
  ]

  locales
  |> list.each(fn(locale) {
    let result = locale.new(locale)
    result |> should.be_error
  })
}
