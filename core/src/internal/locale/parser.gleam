import parsley.{type Parser} as p

import internal/generated/iana_definitions
import internal/locale/model.{
  type Language, type Locale, type Region, type Script,
}

// From https://datatracker.ietf.org/doc/html/rfc5646

// Language-Tag  = langtag             ; normal language tags
//               / privateuse          ; private use tag
//               / grandfathered       ; grandfathered tags
//
// Note:
// privateuse is deemed invalid
// grandfathered are deemed invalid
pub fn language_tag() -> Parser(Locale) {
  langtag()
  |> p.trace("language-tag")
}

// langtag       = language
//                  ["-" script]
//                  ["-" region]
//                  *("-" variant)
//                  *("-" extension)
//                  ["-" privateuse]
//
// Note:
// variants are recognised in the locale naming but dumped
// extensions are recognised in the locale naming but dumped
// privateuse is deemed invalid
fn langtag() -> Parser(Locale) {
  fn(in: String) {
    use language <- p.bind(language(), in)

    use script <- p.bind(
      p.optional(p.right(p.exact("-"), script())),
      language.rest,
    )

    use region <- p.bind(
      p.optional(p.right(p.exact("-"), region())),
      script.rest,
    )

    use variants <- p.bind(
      p.zero_or_more(p.right(p.exact("-"), variant())),
      region.rest,
    )

    use extensions <- p.bind(
      p.zero_or_more(p.right(p.exact("-"), extension())),
      variants.rest,
    )

    let locale = model.Locale(language.value, script.value, region.value)
    Ok(p.Parsed(locale, extensions.rest))
  }
  |> p.trace("langtag")
}

// language      = 2*3ALPHA             ; shortest ISO 639 code
//                  ["-" extlang]       ; sometimes followed by
//                                      ; extended language subtags
//                / 4ALPHA              ; or reserved for future use
//                / 5*8ALPHA            ; or registered language subtag
//
// Note:
// extlang is deemed invalid
// reserved is deemed invalid
// registered is deemed invalid
fn language() -> Parser(Language) {
  p.between(2, 3, p.alpha())
  |> p.map(p.joined)
  |> p.and_then(fn(value) {
    case iana_definitions.is_valid_language(value) {
      True -> p.succeed(model.Language(value))
      False -> p.fail()
    }
  })
  |> p.trace("language")
}

// extlang       = 3ALPHA              ; selected ISO 639 codes
//                 *2("-" 3ALPHA)      ; permanently reserved

// script        = 4ALPHA              ; ISO 15924 code
fn script() -> Parser(Script) {
  p.exactly(4, p.alpha())
  |> p.map(p.joined)
  |> p.and_then(fn(value) {
    case iana_definitions.is_valid_script(value) {
      True -> p.succeed(model.Script(value))
      False -> p.fail()
    }
  })
  |> p.trace("script")
}

// region        = 2ALPHA              ; ISO 3166-1 code
//               / 3DIGIT              ; UN M.49 code
fn region() -> Parser(Region) {
  p.choice([p.exactly(2, p.alpha()), p.exactly(3, p.digit())])
  |> p.map(p.joined)
  |> p.and_then(fn(value) {
    case iana_definitions.is_valid_region(value) {
      True -> p.succeed(model.Region(value))
      False -> p.fail()
    }
  })
  |> p.trace("region")
}

// variant       = 5*8alphanum         ; registered variants
//               / (DIGIT 3alphanum)
fn variant() -> Parser(String) {
  p.choice([
    p.between(5, 8, p.alphanumeric()) |> p.map(p.joined),
    p.pair(p.digit(), p.exactly(3, p.alphanumeric()))
      |> p.map(fn(result) {
        let #(head, tail) = result
        head <> tail |> p.joined
      }),
  ])
  |> p.trace("variant")
}

// extension     = singleton 1*("-" (2*8alphanum))
pub fn extension() -> Parser(String) {
  p.pair(
    singleton(),
    p.one_or_more(p.right(
      p.exact("-"),
      p.between(2, 8, p.alphanumeric()) |> p.map(p.joined),
    )),
  )
  |> p.map(fn(result) {
    let #(head, tail) = result
    head <> tail |> p.joined
  })
  |> p.trace("extension")
}

//                                      ; Single alphanumerics
//                                      ; "x" reserved for private use
//  singleton     = DIGIT               ; 0 - 9
//                / %x41-57             ; A - W
//                / %x59-5A             ; Y - Z
//                / %x61-77             ; a - w
//                / %x79-7A             ; y - z
fn singleton() -> Parser(String) {
  p.choice([
    p.digit(),
    p.grapheme_from("ABCDEFGHIJKLMNOPQRSTUVWYZ"),
    p.grapheme_from("abcdefghijklmnopqrstuvwyz"),
  ])
  |> p.trace("singleton")
}
// privateuse    = "x" 1*("-" (1*8alphanum))

// grandfathered = irregular           ; non-redundant tags registered
//               / regular             ; during the RFC 3066 era

// irregular     = "en-GB-oed"         ; irregular tags do not match
//               / "i-ami"             ; the 'langtag' production and
//               / "i-bnn"             ; would not otherwise be
//               / "i-default"         ; considered 'well-formed'
//               / "i-enochian"        ; These tags are all valid,
//               / "i-hak"             ; but most are deprecated
//               / "i-klingon"         ; in favor of more modern
//               / "i-lux"             ; subtags or subtag
//               / "i-mingo"           ; combination
//               / "i-navajo"
//               / "i-pwn"
//               / "i-tao"
//               / "i-tay"
//               / "i-tsu"
//               / "sgn-BE-FR"
//               / "sgn-BE-NL"
//               / "sgn-CH-DE"

// regular       = "art-lojban"        ; these tags match the 'langtag'
//               / "cel-gaulish"       ; production, but their subtags
//               / "no-bok"            ; are not extended language
//               / "no-nyn"            ; or variant subtags: their meaning
//               / "zh-guoyu"          ; is defined by their registration
//               / "zh-hakka"          ; and all of these are deprecated
//               / "zh-min"            ; in favor of a more modern
//               / "zh-min-nan"        ; subtag or sequence of subtags
//               / "zh-xiang"

// alphanum      = (ALPHA / DIGIT)     ; letters and numbers
