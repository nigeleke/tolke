import gleam/list
import gleam/option.{type Option}

import mf2/diagnostic.{type Diagnostic}

pub type AnnotatedValue(a) {
  AnnotatedValue(value: a, diagnostics: List(Diagnostic))
}

pub fn annotate(value: a) -> AnnotatedValue(a) {
  AnnotatedValue(value, [])
}

pub fn annotate_with_diagnostics(
  value: a,
  diagnostics: List(Diagnostic),
) -> AnnotatedValue(a) {
  AnnotatedValue(value, diagnostics)
}

pub fn map(in: AnnotatedValue(a), f: fn(a) -> b) -> AnnotatedValue(b) {
  AnnotatedValue(value: f(in.value), diagnostics: in.diagnostics)
}

pub fn and_then(
  value: AnnotatedValue(a),
  f: fn(a) -> AnnotatedValue(b),
) -> AnnotatedValue(b) {
  let next = f(value.value)

  AnnotatedValue(
    value: next.value,
    diagnostics: list.append(value.diagnostics, next.diagnostics),
  )
}

pub fn map2(
  in1: AnnotatedValue(a),
  in2: AnnotatedValue(b),
  with f: fn(a, b) -> c,
) -> AnnotatedValue(c) {
  AnnotatedValue(
    f(in1.value, in2.value),
    in1.diagnostics
      |> list.append(in2.diagnostics),
  )
}

pub fn map3(
  in1: AnnotatedValue(a),
  in2: AnnotatedValue(b),
  in3: AnnotatedValue(c),
  with f: fn(a, b, c) -> d,
) -> AnnotatedValue(d) {
  AnnotatedValue(
    f(in1.value, in2.value, in3.value),
    in1.diagnostics
      |> list.append(in2.diagnostics)
      |> list.append(in3.diagnostics),
  )
}

pub fn pair(
  in1: AnnotatedValue(a),
  in2: AnnotatedValue(b),
) -> AnnotatedValue(#(a, b)) {
  map2(in1, in2, with: fn(a, b) { #(a, b) })
}

pub fn map_with_diagnostics(
  in: AnnotatedValue(a),
  f: fn(a) -> b,
  diagnostics: List(Diagnostic),
) -> AnnotatedValue(b) {
  AnnotatedValue(
    value: f(in.value),
    diagnostics: in.diagnostics |> list.append(diagnostics),
  )
}

pub fn prepend(
  next: AnnotatedValue(a),
  acc: AnnotatedValue(List(a)),
) -> AnnotatedValue(List(a)) {
  AnnotatedValue(
    [next.value, ..acc.value],
    list.append(next.diagnostics, acc.diagnostics),
  )
}

pub fn append(
  list0: AnnotatedValue(List(a)),
  list1: AnnotatedValue(List(a)),
) -> AnnotatedValue(List(a)) {
  AnnotatedValue(
    list.append(list0.value, list1.value),
    list.append(list0.diagnostics, list1.diagnostics),
  )
}

pub fn reverse(acc: AnnotatedValue(List(a))) -> AnnotatedValue(List(a)) {
  AnnotatedValue(list.reverse(acc.value), list.reverse(acc.diagnostics))
}

pub fn collect(
  elements: List(a),
  f: fn(a) -> AnnotatedValue(b),
) -> AnnotatedValue(List(b)) {
  elements
  |> list.fold(annotate([]), fn(acc, element) { f(element) |> prepend(acc) })
  |> reverse
}

pub fn transpose_list(
  elements: List(AnnotatedValue(a)),
) -> AnnotatedValue(List(a)) {
  let #(values, diagnostics) =
    elements
    |> list.map(fn(a) { #(a.value, a.diagnostics) })
    |> list.unzip()
  AnnotatedValue(values, diagnostics |> list.flatten)
}

pub fn transpose_option(
  value: Option(AnnotatedValue(a)),
) -> AnnotatedValue(Option(a)) {
  case value {
    option.Some(a) -> AnnotatedValue(option.Some(a.value), a.diagnostics)
    option.None -> AnnotatedValue(option.None, list.new())
  }
}
