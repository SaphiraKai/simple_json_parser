import gleam/dict
import gleam/float
import gleam/io
import gleam/list
import gleam/string
import json_parser/parse
import simplifile

pub fn to_string(json: parse.Value) {
  case json {
    parse.Null -> "null"
    parse.Bool(True) -> "true"
    parse.Bool(False) -> "false"
    parse.Number(f) -> float.to_string(f)
    parse.String(s) -> "\"" <> s <> "\""
    parse.Array(l) -> "[" <> list.map(l, to_string) |> string.join(",") <> "]"
    parse.Object(d) ->
      "{"
      <> dict.to_list(d)
      |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
      |> list.map(fn(t) {
        let #(key, value) = t
        "\"" <> key <> "\":" <> to_string(value)
      })
      |> string.join(",")
      <> "}"
  }
}

pub fn to_string_pretty(json: parse.Value) {
  do_to_string_pretty(json, 0)
}

fn do_to_string_pretty(json: parse.Value, depth: Int) {
  case json {
    parse.Null -> "null"
    parse.Bool(True) -> "true"
    parse.Bool(False) -> "false"
    parse.Number(f) -> float.to_string(f)
    parse.String(s) -> "\"" <> s <> "\""
    parse.Array(l) ->
      "["
      <> list.map(l, do_to_string_pretty(_, depth + 1)) |> string.join(", ")
      <> "]"
    parse.Object(d) -> {
      let indent = string.repeat("  ", depth)

      "{\n"
      <> dict.to_list(d)
      |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
      |> list.map(fn(t) {
        let #(key, value) = t
        indent
        <> "  \""
        <> key
        <> "\": "
        <> do_to_string_pretty(value, depth + 1)
      })
      |> string.join(",\n")
      <> "\n"
      <> indent
      <> "}"
    }
  }
}

pub fn main() -> Nil {
  let assert Ok(json_string) = simplifile.read("/dev/stdin")
  let assert Ok(json) = json_string |> parse.from_string

  echo json

  io.println("\nformatted:")
  json |> to_string_pretty |> io.println

  Nil
}
