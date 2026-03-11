import Jar.Test.HistoryJson
open Jar.Test.HistoryJson
def main (args : List String) : IO UInt32 := do
  let dir := match args with | [d] => d | _ => "tests/vectors/history/tiny"
  IO.println s!"Running history JSON tests from: {dir}"
  runJsonTestDir dir
