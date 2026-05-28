import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/string

pub type Value {
  String(String)
  Int(Int)
  Float(Float)
  Bool(Bool)
  List(List(Value))
  Null
}

pub fn to_string(value: Value) -> String {
  case value {
    String(s) -> s
    Int(i) -> int.to_string(i)
    Float(f) -> float.to_string(f)
    Bool(b) -> bool.to_string(b)
    List(vs) -> "[" <> vs |> list.map(to_string) |> string.join(", ") <> "]"
    Null -> ""
  }
}
