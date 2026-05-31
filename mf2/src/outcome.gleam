import gleam/list
import gleam/option.{type Option}

import issue.{type Issue}

pub type Outcome(a) {
  Ok(value: a, issues: List(Issue))
}

pub fn pure(value: a) -> Outcome(a) {
  Ok(value, [])
}

pub fn pure_with_issue(value: a, issue: Issue) -> Outcome(a) {
  Ok(value, [issue])
}

pub fn pure_with_issues(value: a, issues: List(Issue)) -> Outcome(a) {
  Ok(value, issues)
}

pub fn map(in: Outcome(a), f: fn(a) -> b) -> Outcome(b) {
  Ok(value: f(in.value), issues: in.issues)
}

pub fn flat_map(value: Outcome(a), f: fn(a) -> Outcome(b)) -> Outcome(b) {
  let next = f(value.value)
  Ok(value: next.value, issues: list.append(value.issues, next.issues))
}

pub fn map2(
  in1: Outcome(a),
  in2: Outcome(b),
  with f: fn(a, b) -> c,
) -> Outcome(c) {
  Ok(
    f(in1.value, in2.value),
    in1.issues
      |> list.append(in2.issues),
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
    in1.issues
      |> list.append(in2.issues)
      |> list.append(in3.issues),
  )
}

pub fn pair(in1: Outcome(a), in2: Outcome(b)) -> Outcome(#(a, b)) {
  map2(in1, in2, with: fn(a, b) { #(a, b) })
}

pub fn map_with_issue(
  in: Outcome(a),
  f: fn(a) -> b,
  issue: Issue,
) -> Outcome(b) {
  Ok(value: f(in.value), issues: in.issues |> list.append([issue]))
}

pub fn map_with_issues(
  in: Outcome(a),
  f: fn(a) -> b,
  issues: List(Issue),
) -> Outcome(b) {
  Ok(value: f(in.value), issues: in.issues |> list.append(issues))
}

pub fn prepend(next: Outcome(a), acc: Outcome(List(a))) -> Outcome(List(a)) {
  Ok([next.value, ..acc.value], list.append(next.issues, acc.issues))
}

pub fn append(
  list0: Outcome(List(a)),
  list1: Outcome(List(a)),
) -> Outcome(List(a)) {
  Ok(
    list.append(list0.value, list1.value),
    list.append(list0.issues, list1.issues),
  )
}

pub fn reverse(acc: Outcome(List(a))) -> Outcome(List(a)) {
  Ok(list.reverse(acc.value), list.reverse(acc.issues))
}

pub fn collect(elements: List(a), f: fn(a) -> Outcome(b)) -> Outcome(List(b)) {
  elements
  |> list.fold(pure([]), fn(acc, element) { f(element) |> prepend(acc) })
  |> reverse
}

pub fn transpose_list(elements: List(Outcome(a))) -> Outcome(List(a)) {
  let #(values, issues) =
    elements
    |> list.map(fn(a) { #(a.value, a.issues) })
    |> list.unzip()
  Ok(values, issues |> list.flatten)
}

pub fn transpose_option(value: Option(Outcome(a))) -> Outcome(Option(a)) {
  case value {
    option.Some(a) -> Ok(option.Some(a.value), a.issues)
    option.None -> Ok(option.None, list.new())
  }
}
