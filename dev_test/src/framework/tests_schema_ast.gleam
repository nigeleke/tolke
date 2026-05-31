import gleam/dynamic
import gleam/option.{type Option}

pub type RawTestFile {
  RawTestFile(
    schema: Option(String),
    scenario: Option(String),
    description: Option(String),
    default_test_properties: Option(DefaultTestProperties),
    tests: List(RawTest),
  )
}

pub type TestFile {
  TestFile(scenario: String, description: String, tests: List(Test))
}

pub type DefaultTestProperties {
  DefaultTestProperties(
    locale: Option(String),
    src: Option(String),
    bidi_isolation: Option(BidiIsolation),
    params: Option(List(Var)),
    tags: Option(List(Tag)),
    exp: Option(String),
    exp_parts: Option(List(ExpPart)),
    exp_errors: Option(List(ExpError)),
  )
}

pub type RawTest {
  RawTest(
    description: Option(String),
    locale: Option(String),
    src: Option(String),
    bidi_isolation: Option(BidiIsolation),
    params: Option(List(Var)),
    tags: Option(List(Tag)),
    exp: Option(String),
    exp_parts: Option(List(ExpPart)),
    exp_errors: Option(List(ExpError)),
    only: Option(Bool),
  )
}

pub type Assertion {
  Exact(String)
  Parts(List(ExpPart))
  Errors(List(ExpError))
}

pub type Test {
  Test(
    description: String,
    locale: String,
    src: String,
    params: List(Var),
    tags: List(Tag),
    assertions: List(Assertion),
    only: Bool,
  )
}

pub type BidiIsolation {
  BidiIsolationDefault
  BidiIsolationNone
}

pub type Tag {
  CurrencyTag
  PercentTag
  DirTag
  IdTag
}

pub type Var {
  GenericVar(name: String, value: dynamic.Dynamic)
  DatetimeVar(name: String, value: String)
}

pub type ExpPart {
  TextPart(value: String)

  BidiIsolationPart(value: BidiIsolationValue)

  MarkupPart(
    kind: MarkupKind,
    name: String,
    id: Option(String),
    options: Option(dynamic.Dynamic),
  )

  ExpressionPart(
    expression_type: ExpressionType,
    locale: Option(String),
    id: Option(String),
    parts: Option(List(ExpressionSubPart)),
    value: Option(dynamic.Dynamic),
  )

  FallbackPart(source: String)
}

pub type BidiIsolationValue {
  Lri
  Rli
  Fsi
  Pdi
}

pub type MarkupKind {
  MarkupOpen
  MarkupStandalone
  MarkupClose
}

pub type ExpressionType {
  DatetimeExpression
  NumberExpression
  StringExpression
  TestExpression
}

pub type ExpressionSubPart {
  ExpressionSubPart(type_: String)
}

pub type ExpError {
  SyntaxError
  VariantKeyMismatch
  MissingFallbackVariant
  MissingSelectorAnnotation
  DuplicateDeclaration
  DuplicateOptionName
  DuplicateVariant
  UnresolvedVariable
  UnknownFunction
  BadSelector
  BadOperand
  BadOption
  BadVariantKey
}
