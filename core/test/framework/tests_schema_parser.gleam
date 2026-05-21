import gleam/dict
import gleam/dynamic/decode.{type Decoder}
import gleam/option

import framework/tests_schema_ast.{
  type BidiIsolation, type BidiIsolationValue, type DefaultTestProperties,
  type ExpError, type ExpPart, type ExpressionSubPart, type MarkupKind,
  type RawTest, type RawTestFile, type Tag, type Var,
} as ast

pub fn raw_test_file_decoder() -> Decoder(RawTestFile) {
  use schema <- decode.optional_field(
    "$schema",
    option.None,
    decode.optional(decode.string),
  )

  use scenario <- decode.optional_field(
    "scenario",
    option.None,
    decode.optional(decode.string),
  )

  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use default_test_properties <- decode.optional_field(
    "defaultTestProperties",
    option.None,
    decode.optional(default_test_properties_decoder()),
  )

  use tests <- decode.field("tests", decode.list(raw_test_decoder()))

  decode.success(ast.RawTestFile(
    schema:,
    scenario:,
    description:,
    default_test_properties:,
    tests:,
  ))
  |> trace("raw-test-file")
}

fn default_test_properties_decoder() -> Decoder(DefaultTestProperties) {
  use locale <- decode.optional_field(
    "locale",
    option.None,
    decode.optional(decode.string),
  )

  use src <- decode.optional_field(
    "src",
    option.None,
    decode.optional(decode.string),
  )

  use bidi_isolation <- decode.optional_field(
    "bidiIsolation",
    option.None,
    decode.optional(bidi_isolation_decoder()),
  )

  use params <- decode.optional_field(
    "params",
    option.None,
    decode.optional(decode.list(var_decoder())),
  )

  use tags <- decode.optional_field(
    "tags",
    option.None,
    decode.optional(decode.list(tag_decoder())),
  )

  use exp <- decode.optional_field(
    "exp",
    option.None,
    decode.optional(decode.string),
  )

  use exp_parts <- decode.optional_field(
    "expParts",
    option.None,
    decode.optional(decode.list(exp_part_decoder())),
  )

  use exp_errors <- decode.optional_field(
    "expErrors",
    option.None,
    decode.optional(decode.list(exp_error_decoder())),
  )

  decode.success(ast.DefaultTestProperties(
    locale:,
    src:,
    bidi_isolation:,
    params:,
    tags:,
    exp:,
    exp_parts:,
    exp_errors:,
  ))
  |> trace("default-test-properties-decoder")
}

fn bidi_isolation_decoder() -> Decoder(BidiIsolation) {
  decode.then(decode.string, fn(value) {
    case value {
      "default" -> decode.success(ast.BidiIsolationDefault)
      "none" -> decode.success(ast.BidiIsolationNone)
      _ -> decode.failure(ast.BidiIsolationDefault, "invalid bidiIsolation")
    }
  })
  |> trace("bidi-isolation-decoder")
}

fn tag_decoder() -> decode.Decoder(Tag) {
  decode.then(decode.string, fn(value) {
    case value {
      ":currency" -> decode.success(ast.CurrencyTag)
      ":percent" -> decode.success(ast.PercentTag)
      "u:dir" -> decode.success(ast.DirTag)
      "u:id" -> decode.success(ast.IdTag)
      _ -> decode.failure(ast.CurrencyTag, "invalid tag")
    }
  })
  |> trace("tag-decoder")
}

fn var_decoder() -> decode.Decoder(Var) {
  let generic_decoder = {
    use name <- decode.field("name", decode.string)
    use value <- decode.field("value", decode.dynamic)
    decode.success(ast.GenericVar(name:, value:))
  }

  let datetime_decoder = {
    use name <- decode.field("name", decode.string)
    use type_ <- decode.field("type", decode.string)
    use value <- decode.field("value", decode.string)

    case type_ {
      "datetime" -> decode.success(ast.DatetimeVar(name:, value:))
      _ -> decode.failure(ast.DatetimeVar("", ""), "expected type=datetime")
    }
  }

  decode.one_of(datetime_decoder, [generic_decoder])
  |> trace("var-decoder")
}

fn exp_part_decoder() -> decode.Decoder(ExpPart) {
  let text_part_decoder = {
    use value <- decode.field("value", decode.string)
    decode.success(ast.TextPart(value))
  }

  let bidi_isolation_part_decoder = {
    use value <- decode.field("value", bidi_isolation_value_decoder())
    decode.success(ast.BidiIsolationPart(value))
  }

  let markup_part_decoder = {
    use kind <- decode.field("kind", markup_kind_decoder())
    use name <- decode.field("name", decode.string)
    use id <- decode.optional_field(
      "id",
      option.None,
      decode.optional(decode.string),
    )
    use options <- decode.optional_field(
      "options",
      option.None,
      decode.optional(decode.dynamic),
    )
    decode.success(ast.MarkupPart(kind:, name:, id:, options:))
    |> trace("markup-part-decoder")
  }

  let expression_part_decoder = fn(type_: String) {
    let assert Ok(expression_type) = case type_ {
      "datetime" -> Ok(ast.DatetimeExpression)
      "number" -> Ok(ast.NumberExpression)
      "string" -> Ok(ast.StringExpression)
      "test" -> Ok(ast.TestExpression)
      _ -> Error(Nil)
    }

    use locale <- decode.optional_field(
      "locale",
      option.None,
      decode.optional(decode.string),
    )
    use id <- decode.optional_field(
      "id",
      option.None,
      decode.optional(decode.string),
    )
    use parts <- decode.optional_field(
      "parts",
      option.None,
      decode.optional(decode.list(expression_sub_part_decoder())),
    )
    use value <- decode.optional_field(
      "value",
      option.None,
      decode.optional(decode.dynamic),
    )

    decode.success(ast.ExpressionPart(
      expression_type:,
      locale: locale,
      id: id,
      parts: parts,
      value: value,
    ))
    |> trace("expression-part-decoder")
  }

  let fallback_part_decoder = {
    use source <- decode.field("source", decode.string)
    decode.success(ast.FallbackPart(source))
    |> trace("fallback-part-decoder")
  }

  let exp_part_registry = {
    dict.from_list([
      #("text", fn(_) { text_part_decoder }),
      #("bidiIsolation", fn(_) { bidi_isolation_part_decoder }),
      #("markup", fn(_) { markup_part_decoder }),
      #("fallback", fn(_) { fallback_part_decoder }),
      #("datetime", expression_part_decoder),
      #("number", expression_part_decoder),
      #("string", expression_part_decoder),
      #("test", expression_part_decoder),
    ])
  }

  decode.field(decode.string, decode.string, fn(type_) {
    case dict.get(exp_part_registry, type_) {
      Ok(decoder_fn) -> decoder_fn(type_)
      Error(_) -> decode.failure(ast.TextPart(""), "unknown expPart: " <> type_)
    }
  })
  |> trace("exp-part-decoder")
}

fn bidi_isolation_value_decoder() -> Decoder(BidiIsolationValue) {
  decode.then(decode.string, fn(value) {
    case value {
      "\u{2066}" -> decode.success(ast.Lri)
      "\u{2067}" -> decode.success(ast.Rli)
      "\u{2068}" -> decode.success(ast.Fsi)
      "\u{2069}" -> decode.success(ast.Pdi)
      _ -> decode.failure(ast.Lri, "invalid bidi-isolation-value")
    }
  })
}

fn markup_kind_decoder() -> Decoder(MarkupKind) {
  use value <- decode.field("value", decode.string)
  case value {
    "open" -> decode.success(ast.MarkupOpen)
    "standalone" -> decode.success(ast.MarkupStandalone)
    "close" -> decode.success(ast.MarkupClose)
    _ -> decode.failure(ast.MarkupStandalone, "invalid markup-kind")
  }
}

fn expression_sub_part_decoder() -> Decoder(ExpressionSubPart) {
  use type_ <- decode.field("type", decode.string)
  decode.success(ast.ExpressionSubPart(type_))
}

fn exp_error_decoder() -> Decoder(ExpError) {
  use type_ <- decode.field("type", decode.string)
  case type_ {
    "syntax-error" -> decode.success(ast.SyntaxError)
    "variant-key-mismatch" -> decode.success(ast.VariantKeyMismatch)
    "missing-fallback-variant" -> decode.success(ast.MissingFallbackVariantS)
    "missing-selector-annotation" ->
      decode.success(ast.MissingSelectorAnnotation)
    "duplicate-declaration" -> decode.success(ast.DuplicateDeclaration)
    "duplicate-option-name" -> decode.success(ast.DuplicateOptionName)
    "duplicate-variant" -> decode.success(ast.DuplicateVariant)
    "unresolved-variable" -> decode.success(ast.UnresolvedVariable)
    "unknown-function" -> decode.success(ast.UnknownFunction)
    "bad-selector" -> decode.success(ast.BadSelector)
    "bad-operand" -> decode.success(ast.BadOperand)
    "bad-option" -> decode.success(ast.BadOption)
    "bad-variant-key" -> decode.success(ast.BadVariantKey)
    _ -> decode.failure(ast.SyntaxError, "unknown exp-error")
  }
  |> trace("exp_error_decoder")
}

fn raw_test_decoder() -> Decoder(RawTest) {
  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )
  use locale <- decode.optional_field(
    "locale",
    option.None,
    decode.optional(decode.string),
  )
  use src <- decode.optional_field(
    "src",
    option.None,
    decode.optional(decode.string),
  )
  use bidi_isolation <- decode.optional_field(
    "bidiIsolation",
    option.None,
    decode.optional(bidi_isolation_decoder()),
  )
  use params <- decode.optional_field(
    "params",
    option.None,
    decode.optional(decode.list(var_decoder())),
  )

  use tags <- decode.optional_field(
    "tags",
    option.None,
    decode.optional(decode.list(tag_decoder())),
  )

  use exp <- decode.optional_field(
    "exp",
    option.None,
    decode.optional(decode.string),
  )

  use exp_parts <- decode.optional_field(
    "expParts",
    option.None,
    decode.optional(decode.list(exp_part_decoder())),
  )

  use exp_errors <- decode.optional_field(
    "expErrors",
    option.None,
    decode.optional(decode.list(exp_error_decoder())),
  )

  use only <- decode.optional_field(
    "only",
    option.None,
    decode.optional(decode.bool),
  )

  decode.success(ast.RawTest(
    description:,
    locale:,
    src:,
    bidi_isolation:,
    params:,
    tags:,
    exp:,
    exp_parts:,
    exp_errors:,
    only:,
  ))
}

// ------------------------------------
// Choose tracer
// ------------------------------------
// fn trace(decoder: Decoder(a), _name: String) -> Decoder(a) {
//   decoder
// }
// ------------------------------------
import gleam/io

fn trace(decoder: decode.Decoder(a), name: String) -> decode.Decoder(a) {
  io.println(">> " <> name)
  decoder
  |> decode.map(fn(value) {
    io.println("<< " <> name)
    value
  })
  |> decode.map_errors(fn(errors) {
    io.println("<! " <> name)
    errors
  })
}
// ------------------------------------
