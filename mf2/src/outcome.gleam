import gleam/list
import gleam/option.{type Option}

import diagnostic.{type Diagnostic}

pub type Outcome(a) {
  Ok(value: a, diagnostics: List(Diagnostic))
}

pub fn annotate(value: a) -> Outcome(a) {
  Ok(value, [])
}

pub fn annotate_with_diagnostics(
  value: a,
  diagnostics: List(Diagnostic),
) -> Outcome(a) {
  Ok(value, diagnostics)
}

pub fn map(in: Outcome(a), f: fn(a) -> b) -> Outcome(b) {
  Ok(value: f(in.value), diagnostics: in.diagnostics)
}

pub fn and_then(value: Outcome(a), f: fn(a) -> Outcome(b)) -> Outcome(b) {
  let next = f(value.value)

  Ok(
    value: next.value,
    diagnostics: list.append(value.diagnostics, next.diagnostics),
  )
}

pub fn map2(
  in1: Outcome(a),
  in2: Outcome(b),
  with f: fn(a, b) -> c,
) -> Outcome(c) {
  Ok(
    f(in1.value, in2.value),
    in1.diagnostics
      |> list.append(in2.diagnostics),
  )
}

pub fn map3(
  in1: Outcome(a),
  in2: Outcome(b),
  in3: Outcome(c),
  with f: fn(a, b, c) -> d,
) -> Outcome(d) {
  Ok(
    f(in1.value, in2.value, in3.value),
    in1.diagnostics
      |> list.append(in2.diagnostics)
      |> list.append(in3.diagnostics),
  )
}

pub fn pair(in1: Outcome(a), in2: Outcome(b)) -> Outcome(#(a, b)) {
  map2(in1, in2, with: fn(a, b) { #(a, b) })
}

pub fn map_with_diagnostics(
  in: Outcome(a),
  f: fn(a) -> b,
  diagnostics: List(Diagnostic),
) -> Outcome(b) {
  Ok(
    value: f(in.value),
    diagnostics: in.diagnostics |> list.append(diagnostics),
  )
}

pub fn prepend(next: Outcome(a), acc: Outcome(List(a))) -> Outcome(List(a)) {
  Ok([next.value, ..acc.value], list.append(next.diagnostics, acc.diagnostics))
}

pub fn append(
  list0: Outcome(List(a)),
  list1: Outcome(List(a)),
) -> Outcome(List(a)) {
  Ok(
    list.append(list0.value, list1.value),
    list.append(list0.diagnostics, list1.diagnostics),
  )
}

pub fn reverse(acc: Outcome(List(a))) -> Outcome(List(a)) {
  Ok(list.reverse(acc.value), list.reverse(acc.diagnostics))
}

pub fn collect(elements: List(a), f: fn(a) -> Outcome(b)) -> Outcome(List(b)) {
  elements
  |> list.fold(annotate([]), fn(acc, element) { f(element) |> prepend(acc) })
  |> reverse
}

pub fn transpose_list(elements: List(Outcome(a))) -> Outcome(List(a)) {
  let #(values, diagnostics) =
    elements
    |> list.map(fn(a) { #(a.value, a.diagnostics) })
    |> list.unzip()
  Ok(values, diagnostics |> list.flatten)
}

pub fn transpose_option(value: Option(Outcome(a))) -> Outcome(Option(a)) {
  case value {
    option.Some(a) -> Ok(option.Some(a.value), a.diagnostics)
    option.None -> Ok(option.None, list.new())
  }
}
