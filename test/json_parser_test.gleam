import gleam/io
import gleam/list
import gleam/string
import gleeunit
import simplifile

import json_parser/parse

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn suite_test() {
  let assert Ok(files) = simplifile.get_files("./test_suite/")

  files
  |> list.each(fn(f) {
    let assert Ok(string) = simplifile.read(f)

    case parse.from_string(string), string.contains(f, "pass") {
      Ok(_), True | Error(_), False -> io.println_error("PASS: " <> f)
      _, _ -> io.println_error("FAIL: " <> f)
    }
  })
}
