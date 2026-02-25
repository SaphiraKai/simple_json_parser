import gleam/dict.{type Dict}
import gleam/float
import gleam/list
import gleam/string

pub type State(input, output) {
  Empty(input: input)
  Parsed(input: input, parsed: output)
  Failed(input: input)
}

pub type Value {
  Null
  Bool(Bool)
  Number(Float)
  String(String)
  Array(List(Value))
  Object(Dict(String, Value))
}

fn replace_input(state: State(a, b), with input: a) -> State(a, b) {
  case state {
    Empty(..) -> Empty(input:)
    Parsed(parsed:, ..) -> Parsed(input:, parsed:)
    Failed(..) -> Failed(input:)
  }
}

fn map_input(state: State(a, b), with fun: fn(a) -> a) -> State(a, b) {
  state |> replace_input(fun(state.input))
}

fn any(
  state: State(a, b),
  of parsers: List(fn(State(a, b)) -> State(a, c)),
) -> State(a, c) {
  case parsers {
    [] -> Failed(state.input)
    [parse, ..rest] ->
      case parse(state) {
        Failed(..) -> any(state, rest)
        parsed -> parsed
      }
  }
}

fn sep1(
  state: State(a, b),
  of parser: fn(State(a, b)) -> State(a, c),
  by separator: fn(a) -> Result(a, Nil),
) -> State(a, List(c)) {
  do_sep1(state, parser, separator, [])
}

fn do_sep1(
  state: State(a, b),
  parser: fn(State(a, b)) -> State(a, c),
  separator: fn(a) -> Result(a, Nil),
  acc: List(c),
) -> State(a, List(c)) {
  case parser(state) {
    Parsed(input:, parsed:) ->
      case separator(input) {
        Ok(rest) -> {
          let state = replace_input(state, rest)

          do_sep1(state, parser, separator, [parsed, ..acc])
        }
        Error(_) -> Parsed(input:, parsed: list.reverse([parsed, ..acc]))
      }
    Empty(input:) -> Empty(input:)
    Failed(input:) -> Failed(input:)
  }
}

fn comma_ws(input: String) -> Result(String, Nil) {
  case string.trim_start(input) {
    "," <> rest -> Ok(string.trim_start(rest))
    _ -> Error(Nil)
  }
}

pub fn null(state: State(String, _)) -> State(String, Value) {
  case state.input {
    "null" <> rest -> Parsed(input: rest, parsed: Null)
    _ -> Failed(input: state.input)
  }
}

pub fn bool(state: State(String, _)) -> State(String, Value) {
  case state.input {
    "true" <> rest -> Parsed(input: rest, parsed: Bool(True))
    "false" <> rest -> Parsed(input: rest, parsed: Bool(False))
    _ -> Failed(state.input)
  }
}

pub fn number(state: State(String, _)) -> State(String, Value) {
  do_number(state.input, "", False)
}

pub fn do_number(
  input: String,
  acc: String,
  has_decimal: Bool,
) -> State(String, Value) {
  case input {
    "0" as digit <> rest
    | "1" as digit <> rest
    | "2" as digit <> rest
    | "3" as digit <> rest
    | "4" as digit <> rest
    | "5" as digit <> rest
    | "6" as digit <> rest
    | "7" as digit <> rest
    | "8" as digit <> rest
    | "9" as digit <> rest -> do_number(rest, acc <> digit, has_decimal)

    "." -> do_number("", acc <> ".0", True)
    "." <> rest -> do_number(rest, acc <> ".", True)

    _ -> {
      let dot_zero = case has_decimal {
        True -> ""
        False -> ".0"
      }

      case acc {
        "" -> Failed(input:)
        _ -> {
          let assert Ok(parsed) = float.parse(acc <> dot_zero)
          let parsed = Number(parsed)

          Parsed(input:, parsed:)
        }
      }
    }
  }
}

fn string(state: State(String, _)) -> State(String, Value) {
  case state.input {
    "\"" <> rest -> do_string(rest, "")
    _ -> Failed(state.input)
  }
}

fn do_string(input: String, acc: String) -> State(String, Value) {
  case input {
    "" -> Failed(input:)
    "\"" <> rest -> Parsed(input: rest, parsed: String(acc))
    _ -> {
      let assert Ok(#(char, rest)) = string.pop_grapheme(input)

      do_string(rest, acc <> char)
    }
  }
}

pub fn array(state: State(String, _)) -> State(String, Value) {
  case state.input {
    "[]" <> rest -> Parsed(rest, Array([]))
    "[" <> rest ->
      case
        sep1(Empty(string.trim_start(rest)), of: value, by: comma_ws)
        |> map_input(string.trim_start)
      {
        Parsed(input: "]" <> rest, parsed:) ->
          Parsed(input: rest, parsed: Array(parsed))
        Parsed(..) -> Failed(rest)
        Empty(input:) -> Empty(input:)
        Failed(input:) -> Failed(input:)
      }
    _ -> Failed(state.input)
  }
}

pub fn object(state: State(String, _)) {
  let field = fn(state) {
    case string(state) |> map_input(string.trim_start) {
      Parsed(input: ":" <> rest, parsed: key) ->
        case value(Empty(rest)) {
          Parsed(input: rest, parsed: val) -> {
            let assert String(key) = key
            Parsed(input: rest, parsed: #(key, val))
          }
          Empty(input:) -> Empty(input:)
          Failed(input:) -> Failed(input:)
        }
      Parsed(..) -> Failed(state.input)
      Empty(input:) -> Empty(input:)
      Failed(input:) -> Failed(input:)
    }
  }
  case state.input {
    "{" <> rest ->
      case
        sep1(Empty(string.trim_start(rest)), of: field, by: comma_ws)
        |> map_input(string.trim_start)
      {
        Parsed(input: "}" <> rest, parsed:) ->
          Parsed(input: rest, parsed: Object(dict.from_list(parsed)))
        Parsed(..) -> Failed(rest)
        Empty(input:) -> Empty(input:)
        Failed(input:) -> Failed(input:)
      }
    _ -> Failed(state.input)
  }
}

pub fn value(state: State(String, _)) -> State(String, Value) {
  let state = state |> map_input(string.trim_start)

  state |> any([null, bool, number, string, array, object])
}

pub fn from_string(input: String) -> Result(Value, State(String, Value)) {
  case Empty(string.trim_start(input)) |> value {
    Parsed(parsed:, ..) -> Ok(parsed)
    reason -> Error(reason)
  }
}
