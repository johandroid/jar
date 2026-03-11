import Jar.Test.ReportsJson
open Jar.Test.ReportsJson
def main (args : List String) : IO UInt32 := do
  let dir := match args with | [d] => d | _ => "tests/vectors/reports/tiny"
  IO.println s!"Running reports JSON tests from: {dir}"
  runJsonTestDir dir
