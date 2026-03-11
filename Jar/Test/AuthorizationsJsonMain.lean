import Jar.Test.AuthorizationsJson
open Jar.Test.AuthorizationsJson
def main (args : List String) : IO UInt32 := do
  let dir := match args with | [d] => d | _ => "tests/vectors/authorizations/tiny"
  IO.println s!"Running authorizations JSON tests from: {dir}"
  runJsonTestDir dir
