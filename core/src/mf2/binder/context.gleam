import gleam/dict.{type Dict}

import mf2/binder/model.{type BoundValue}

pub type BindContext {
  BindContext(variables: Dict(String, BoundValue))
}
