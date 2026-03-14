import Jar.Test.StfServer
import Jar.Variant

open Jar

def main (args : List String) : IO UInt32 := do
  letI := JamVariant.gp072_tiny.toJamConfig
  Jar.Test.StfServer.main args
