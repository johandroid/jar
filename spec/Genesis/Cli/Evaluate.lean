/-
  genesis_evaluate CLI

  Input:  {"commit": {...}, "pastIndices": [...], "ranking": [...] (optional)}
  Output: CommitIndex JSON

  For v2 (useRankedTargets), the "ranking" field is required for target validation.
-/

import Genesis.Cli.Common

open Lean (Json ToJson toJson fromJson? FromJson)
open Genesis.Cli

def main : IO UInt32 := runJsonPipe fun j => do
  let commit ← IO.ofExcept (j.getObjValAs? SignedCommit "commit")
  let pastIndices ← IO.ofExcept (j.getObjValAs? (List CommitIndex) "pastIndices")
  let ranking := (j.getObjValAs? (List CommitId) "ranking").toOption
  let idx := evaluate pastIndices commit ranking
  return toJson idx
