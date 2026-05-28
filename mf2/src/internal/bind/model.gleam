import gleam/dict.{type Dict}
import gleam/option.{type Option as GleamOption}

pub type BoundMessage {
  Simple(List(BoundElement))
  Complex(List(BoundDeclaration), BoundComplexBody)
}

pub type BoundDeclaration {
  BoundDeclaration(BoundVariable, BoundExpression)
}

pub type BoundComplexBody {
  Pattern(List(BoundElement))
  Matcher(BoundMatcher)
}

pub type BoundMatcher {
  BoundMatcher(selectors: List(BoundVariable), variants: List(BoundVariant))
}

pub type BoundVariant {
  BoundVariant(keys: List(BoundKey), body: BoundComplexBody)
}

pub type BoundKey {
  Key(BoundValue)
  Wildcard
}

pub type BoundElement {
  Text(String)
  Expression(BoundExpression)
  Markup(BoundMarkup)
}

pub type BoundExpression {
  ApplyFunction(BoundApplyFunction)
  IdentityFunction(BoundIdentityFunction)
}

pub type BoundApplyFunction {
  BoundApplyFunction(
    function: BoundFunction,
    operand: GleamOption(BoundValueRef),
    attributes: List(BoundAttribute),
  )
}

pub type BoundIdentityFunction {
  BoundIdentityFunction(
    operand: BoundValueRef,
    attributes: List(BoundAttribute),
  )
}

pub type BoundValueRef {
  Literal(BoundValue)
  Variable(BoundVariable)
}

pub type BoundFunction {
  BoundFunction(name: BoundIdentifier, options: BoundOptions)
}

pub type BoundOptions =
  Dict(BoundIdentifier, BoundValueRef)

pub type BoundAttribute {
  FlagAttribute(BoundIdentifier)
  ValueAttribute(BoundIdentifier, BoundValue)
}

pub type BoundValue {
  VString(String)
  VNumber(Float)
}

pub type BoundMarkup {
  Standalone(BoundIdentifier, BoundOptions, List(BoundAttribute))
  Open(BoundIdentifier, BoundOptions, List(BoundAttribute))
  Close(BoundIdentifier, BoundOptions, List(BoundAttribute))
}

pub type BoundIdentifier {
  BoundIdentifier(String)
}

pub type BoundVariable {
  BoundVariable(String)
}
