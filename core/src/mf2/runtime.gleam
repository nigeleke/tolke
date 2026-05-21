import gleam/dict.{type Dict}
import gleam/option.{type Option as GleamOption}

import mf2/annotated_value.{type AnnotatedValue}
import mf2/binder/model.{type BoundOptions, type BoundValue}

pub type RuntimeFunction =
  fn(GleamOption(BoundValue), BoundOptions) -> AnnotatedValue(String)

pub type RuntimeContext {
  RuntimeContext(
    locale: String,
    inputs: Dict(String, String),
    functions: Dict(String, RuntimeFunction),
  )
}
