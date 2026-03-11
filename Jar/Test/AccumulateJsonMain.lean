import Jar.Test.AccumulateJson

open Jar.Test.AccumulateJson

def main (args : List String) : IO UInt32 := do
  let dir := match args with
    | [d] => d
    | _ => "tests/vectors/accumulate/tiny"
  IO.println s!"Running accumulate JSON tests from: {dir}"
  runJsonTestDir dir
