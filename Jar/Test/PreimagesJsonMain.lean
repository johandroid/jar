import Jar.Test.PreimagesJson

open Jar.Test.PreimagesJson

def main (args : List String) : IO UInt32 := do
  let dir := match args with
    | [d] => d
    | _ => "tests/vectors/preimages/tiny"
  IO.println s!"Running preimages JSON tests from: {dir}"
  runJsonTestDir dir
