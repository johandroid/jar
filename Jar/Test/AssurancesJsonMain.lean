import Jar.Test.AssurancesJson

open Jar.Test.AssurancesJson

def main (args : List String) : IO UInt32 := do
  let dir := match args with
    | [d] => d
    | _ => "tests/vectors/assurances/tiny"
  IO.println s!"Running assurances JSON tests from: {dir}"
  runJsonTestDir dir
