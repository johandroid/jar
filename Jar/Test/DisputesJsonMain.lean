import Jar.Test.DisputesJson

open Jar.Test.DisputesJson

def main (args : List String) : IO UInt32 := do
  let dir := match args with
    | [d] => d
    | _ => "tests/vectors/disputes/tiny"
  IO.println s!"Running disputes JSON tests from: {dir}"
  runJsonTestDir dir
