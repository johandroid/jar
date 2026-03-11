import Jar.Test.SafroleJson

open Jar.Test.SafroleJson

def main (args : List String) : IO UInt32 := do
  let dir := match args with
    | [d] => d
    | _ => "tests/vectors/safrole/tiny"
  IO.println s!"Running safrole JSON tests from: {dir}"
  runJsonTestDir dir
