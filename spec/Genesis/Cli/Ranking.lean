/-
  genesis_ranking CLI

  Computes the global quality ranking from weighted pairwise review evidence.

  Input:  {"signedCommits": [...], "indices": [...]}
  Output: {"ranking": ["hash1", "hash2", ...]}  (best to worst)

  Reviewer weights are reconstructed from indices at each step.
-/

import Genesis.Cli.Common

open Lean (Json ToJson toJson fromJson? FromJson)
open Genesis.Cli

def main : IO UInt32 := runJsonPipe fun j => do
  let signedCommits ← IO.ofExcept (j.getObjValAs? (List SignedCommit) "signedCommits")
  let indices ← IO.ofExcept (j.getObjValAs? (List CommitIndex) "indices")
  -- Build per-commit weight functions by reconstructing state incrementally
  let weightFns := signedCommits.zip indices |>.foldl
    (fun (fns, pastIndices) (commit, idx) =>
      let state := reconstructState pastIndices
      letI := activeVariant commit.prCreatedAt
      let fn := (state.reviewerWeight ·)
      (fns ++ [fn], pastIndices ++ [idx])
    ) (([] : List (ContributorId → Nat)), ([] : List CommitIndex))
  letI := GenesisVariant.v1
  let ranking := computeRanking signedCommits weightFns.1
  return Json.mkObj [("ranking", toJson ranking)]
