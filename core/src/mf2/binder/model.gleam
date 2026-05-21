import gleam/dict.{type Dict}
import gleam/option.{type Option as GleamOption}

pub type BoundMessage {
  Simple(BoundPattern)
  Complex(List(BoundDeclaration), List(BoundElement))
}

pub type BoundDeclaration {
  BoundDeclaration(BoundValueRef, BoundExpression)
}

pub type BoundComplexBody {
  Pattern(BoundPattern)
  Matcher(BoundMatcher)
}

pub type BoundPattern =
  List(BoundElement)

pub type BoundMatcher {
  Selector(String)
  // TODO..
  OtherMatcher(String)
}

pub type BoundElement {
  Text(String)
  Expression(BoundExpression)
  Markup(BoundMarkup)
  Fallback(String)
}

pub type BoundExpression {
  BoundExpression(
    function: GleamOption(BoundFunction),
    operand: BoundOperand,
    attributes: List(BoundAttribute),
  )
  BoundMatcher(selectors: List(BoundVariable), variants: List(BoundVariant))
}

pub type BoundValueRef {
  Literal(BoundValue)
  Variable(BoundVariable)
}

pub type BoundOperand {
  BoundValueRef(BoundValueRef)
  NoOperand
}

pub type BoundOption =
  BoundValueRef

pub type BoundFunction {
  BoundFunction(name: BoundIdentifier, options: BoundOptions)
}

pub type BoundOptions =
  Dict(BoundIdentifier, BoundOption)

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

pub type BoundVariant {
  BoundVariant(keys: List(BoundKey), body: List(BoundElement))
}

pub type BoundKey {
  Key(BoundValue)
  Wildcard
}

pub type BoundIdentifier {
  BoundIdentifier(String)
}

pub type BoundVariable {
  BoundVariable(String)
}
