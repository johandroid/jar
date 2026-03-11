import Jar.Test.StatisticsJson
open Jar.Test.StatisticsJson
def main (args : List String) : IO UInt32 := do
  let dir := match args with | [d] => d | _ => "tests/vectors/statistics/tiny"
  IO.println s!"Running statistics JSON tests from: {dir}"
  runJsonTestDir dir
