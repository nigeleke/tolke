import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/string

/// `Parsed` contains a successfully parsed `a`, together with any remaining
/// non-parsed input.
pub type Parsed(a) {
  Parsed(value: a, rest: String)
}

pub type ParseError {
  UnconsumedInput(String)
  NoMatch
}

/// The `Parser` is a function that takes an input String and, if a match
/// is found, returns the `Parsed(out)`.
/// If no match is found then a Error(Nil) is returned.
pub type Parser(out) =
  fn(String) -> Result(Parsed(out), ParseError)

pub fn exact(value: String) -> Parser(String) {
  fn(in: String) {
    case in |> string.starts_with(value) {
      True -> Ok(Parsed(value, in |> string.drop_start(string.length(value))))
      False -> Error(NoMatch)
    }
  }
}

pub fn zero_or_more(parser: Parser(a)) -> Parser(List(a)) {
  fn(in: String) { zero_or_more_impl(parser, in, []) }
}

fn zero_or_more_impl(parser: Parser(a), in: String, acc: List(a)) {
  case parser(in) {
    Ok(Parsed(value, rest)) ->
      case rest == in {
        True -> Error(NoMatch)
        False -> zero_or_more_impl(parser, rest, [value, ..acc])
      }
    Error(_) -> Ok(Parsed(list.reverse(acc), in))
  }
}

pub fn one_or_more(parser: Parser(a)) -> Parser(List(a)) {
  fn(in: String) {
    case parser(in) {
      Ok(Parsed(value, rest)) ->
        case rest == in {
          True -> Error(NoMatch)
          False ->
            case zero_or_more(parser)(rest) {
              Ok(Parsed(values, final_rest)) ->
                Ok(Parsed([value, ..values], final_rest))
              Error(err) -> Error(err)
            }
        }
      Error(err) -> Error(err)
    }
  }
}

pub fn between(min: Int, max: Int, parser: Parser(a)) -> Parser(List(a)) {
  fn(input) { between_impl(parser, input, [], 0, min, max) }
}

fn between_impl(
  parser: Parser(a),
  input: String,
  acc: List(a),
  count: Int,
  min: Int,
  max: Int,
) -> Result(Parsed(List(a)), ParseError) {
  case count >= max {
    True -> Ok(Parsed(list.reverse(acc), input))

    False ->
      case parser(input) {
        Ok(Parsed(value, rest)) ->
          case rest == input {
            True -> Error(NoMatch)
            False ->
              between_impl(parser, rest, [value, ..acc], count + 1, min, max)
          }

        Error(_) ->
          case count >= min {
            True -> Ok(Parsed(list.reverse(acc), input))
            False -> Error(NoMatch)
          }
      }
  }
}

pub fn exactly(n: Int, parser: Parser(a)) -> Parser(List(a)) {
  between(n, n, parser)
}

pub fn choice(parsers: List(Parser(out))) -> Parser(out) {
  fn(in: String) {
    case parsers {
      [] -> Error(NoMatch)

      [p, ..rest] ->
        case p(in) {
          Ok(result) -> Ok(result)
          Error(_) -> choice(rest)(in)
        }
    }
  }
}

pub fn optional(parser: Parser(in)) -> Parser(Option(in)) {
  choice([
    parser |> map(option.Some),
    succeed(option.None),
  ])
}

pub fn pair(first: Parser(in1), second: Parser(in2)) -> Parser(#(in1, in2)) {
  fn(in: String) {
    use parsed1 <- bind(first, in)
    use parsed2 <- bind(second, parsed1.rest)

    let parsed = Parsed(#(parsed1.value, parsed2.value), parsed2.rest)
    Ok(parsed)
  }
}

pub fn left(first: Parser(in1), second: Parser(in2)) -> Parser(in1) {
  pair(first, second)
  |> map(fn(pair) {
    let #(left, _) = pair
    left
  })
}

pub fn right(first: Parser(in1), second: Parser(in2)) -> Parser(in2) {
  pair(first, second)
  |> map(fn(pair) {
    let #(_, right) = pair
    right
  })
}

pub fn triple(
  first: Parser(in1),
  second: Parser(in2),
  third: Parser(in3),
) -> Parser(#(in1, in2, in3)) {
  fn(in: String) {
    use parsed1 <- bind(first, in)
    use parsed2 <- bind(second, parsed1.rest)
    use parsed3 <- bind(third, parsed2.rest)

    let parsed =
      Parsed(#(parsed1.value, parsed2.value, parsed3.value), parsed3.rest)
    Ok(parsed)
  }
}

pub fn grapheme_from(graphemes: String) -> Parser(String) {
  fn(in: String) {
    case string.pop_grapheme(in) {
      Ok(#(first, rest)) -> {
        let grapheme_codepoints = string.to_utf_codepoints(graphemes)
        let first_codepoints = string.to_utf_codepoints(first)

        let contains =
          first_codepoints
          |> list.all(fn(cp) { grapheme_codepoints |> list.contains(cp) })

        case contains {
          True -> Ok(Parsed(first, rest))
          False -> Error(NoMatch)
        }
      }
      Error(_) -> Error(NoMatch)
    }
  }
}

pub fn grapheme_in_range(from: String, to: String) -> Parser(String) {
  fn(in: String) {
    case string.pop_grapheme(in) {
      Ok(#(first, rest)) -> {
        let from_compare = string.compare(from, first)
        let to_compare = string.compare(first, to)
        case from_compare, to_compare {
          order.Lt, order.Lt
          | order.Lt, order.Eq
          | order.Eq, order.Lt
          | order.Eq, order.Eq
          -> Ok(Parsed(first, rest))
          _, _ -> Error(NoMatch)
        }
      }
      Error(_) -> Error(NoMatch)
    }
  }
}

pub fn alpha() -> Parser(String) {
  grapheme_from("ABCDEFGHIJKLMNOPQRSTUVWYXZabcdefghijklmnopqrstuvwxyz")
}

pub fn digit() -> Parser(String) {
  grapheme_from("0123456789")
}

pub fn alphanumeric() -> Parser(String) {
  choice([alpha(), digit()])
}

pub fn joined(strings: List(String)) -> String {
  strings |> string.join("")
}

pub fn map(parser: Parser(in), f: fn(in) -> out) -> Parser(out) {
  parser
  |> and_then(fn(value) { succeed(f(value)) })
}

pub fn and_then(
  parser: Parser(in),
  next: fn(in) -> Parser(out),
) -> Parser(out) {
  fn(in: String) {
    use parsed <- bind(parser, in)
    next(parsed.value)(parsed.rest)
  }
}

pub fn bind(
  parser: Parser(in),
  in: String,
  next: fn(Parsed(in)) -> Result(out, ParseError),
) -> Result(out, ParseError) {
  case parser(in) {
    Ok(parsed) -> next(parsed)
    Error(error) -> Error(error)
  }
}

pub fn succeed(value: a) -> Parser(a) {
  fn(in: String) { Ok(Parsed(value, in)) }
}

pub fn fail() -> Parser(a) {
  fn(_in: String) { Error(NoMatch) }
}

pub fn empty() -> Parser(Nil) {
  fn(in: String) {
    case string.is_empty(in) {
      True -> Ok(Parsed(Nil, in))
      False -> Error(NoMatch)
    }
  }
}

pub fn lookahead(parser: Parser(a)) -> Parser(a) {
  fn(input: String) {
    case parser(input) {
      Ok(parsed) -> Ok(Parsed(parsed.value, input))
      Error(error) -> Error(error)
    }
  }
}

pub fn take_until(stop: Parser(a)) -> Parser(String) {
  fn(input: String) { take_until_loop(stop, input, []) }
}

fn take_until_loop(
  stop: Parser(a),
  input: String,
  acc: List(String),
) -> Result(Parsed(String), ParseError) {
  case stop(input) {
    Ok(_) -> Ok(Parsed(joined(list.reverse(acc)), input))

    Error(_) ->
      case string.pop_grapheme(input) {
        Ok(#(grapheme, rest)) -> take_until_loop(stop, rest, [grapheme, ..acc])
        Error(_) -> Ok(Parsed(joined(list.reverse(acc)), ""))
      }
  }
}

// ------------------------------------
import gleam/io

const trace_enabled = False

pub fn trace(parser: Parser(a), name: String) -> Parser(a) {
  case trace_enabled {
    True -> parser |> do_trace(name)
    False -> parser
  }
}

fn do_trace(parser: Parser(a), name: String) -> Parser(a) {
  fn(input) {
    io.println(">> " <> name)
    let result = parser(input)

    case result {
      Ok(value) -> {
        io.println("<< " <> name <> " ... ")
        io.println(" ... '" <> value.rest <> "'")
        Ok(value)
      }

      Error(error) -> {
        io.println("<! " <> name)
        io.println(" ... '" <> input <> "'")
        Error(error)
      }
    }
  }
}
// ------------------------------------
