#!/usr/bin/env python3
"""
Generate Lean test files from preimages JSON test vectors.

Usage:
  python3 tools/gen_preimages_tests.py <test_vectors_dir> <output_lean_file>
"""

import json
import os
import sys
from pathlib import Path


def hex_to_lean(hex_str: str) -> str:
    h = hex_str.removeprefix("0x")
    return f'hexSeq "{h}"'


def hex_to_bytes(hex_str: str) -> str:
    h = hex_str.removeprefix("0x")
    return f'hexToBytes "{h}"'


def gen_request(r: dict) -> str:
    ts = ", ".join(str(t) for t in r["value"])
    return (
        f'{{ hash := {hex_to_lean(r["key"]["hash"])}, '
        f'length := {r["key"]["length"]}, '
        f'timeslots := #[{ts}] }}'
    )


def gen_service_account(acct: dict, name: str) -> str:
    lines = []
    sid = acct["id"]
    data = acct["data"]

    # Blob hashes (sorted)
    blob_hashes = [hex_to_lean(b["hash"]) for b in data["preimage_blobs"]]
    blobs_str = ", ".join(blob_hashes) if blob_hashes else ""

    # Requests
    req_strs = [gen_request(r) for r in data["preimage_requests"]]
    reqs_str = ",\n      ".join(req_strs) if req_strs else ""

    lines.append(f"def {name} : TPServiceAccount := {{")
    lines.append(f"  serviceId := {sid},")
    if blob_hashes:
        lines.append(f"  blobHashes := #[{blobs_str}],")
    else:
        lines.append(f"  blobHashes := #[],")
    if req_strs:
        lines.append(f"  requests := #[\n      {reqs_str}]")
    else:
        lines.append(f"  requests := #[]")
    lines.append("}")
    return "\n".join(lines)


def gen_state(accounts: list, name: str) -> str:
    lines = []
    acct_refs = []
    for i, acct in enumerate(accounts):
        ref = f"{name}_acct_{i}"
        lines.append(gen_service_account(acct, ref))
        lines.append("")
        acct_refs.append(ref)

    accts_str = "#[" + ", ".join(acct_refs) + "]" if acct_refs else "#[]"
    lines.append(f"def {name} : TPState := {{")
    lines.append(f"  accounts := {accts_str}")
    lines.append("}")
    return "\n".join(lines)


def gen_preimage(p: dict, name_prefix: str, idx: int) -> (str, str):
    ref = f"{name_prefix}_preimage_{idx}"
    defn = (
        f"def {ref} : TPPreimage := {{\n"
        f"  requester := {p['requester']},\n"
        f"  blob := {hex_to_bytes(p['blob'])} }}"
    )
    return defn, ref


def gen_result(output: dict, name: str) -> str:
    if "err" in output:
        return f'def {name} : TPResult := .err "{output["err"]}"'
    return f"def {name} : TPResult := .ok"


def sanitize_name(filename: str) -> str:
    name = Path(filename).stem
    return name.replace("-", "_")


def generate_test_file(test_dir: str, output_file: str):
    json_files = sorted(f for f in os.listdir(test_dir) if f.endswith(".json"))

    if not json_files:
        print(f"No JSON files found in {test_dir}")
        sys.exit(1)

    print(f"Generating tests for {len(json_files)} test vectors...")

    lines = []
    lines.append("import Jar.Test.Preimages")
    lines.append("")
    lines.append("/-! Auto-generated preimages test vectors. Do not edit. -/")
    lines.append("")
    lines.append("namespace Jar.Test.PreimagesVectors")
    lines.append("")
    lines.append("open Jar.Test.Preimages")
    lines.append("")

    # Helpers
    lines.append("def hexToBytes (s : String) : ByteArray :=")
    lines.append("  let chars := s.toList")
    lines.append("  let nibble (c : Char) : UInt8 :=")
    lines.append("    if c.toNat >= 48 && c.toNat <= 57 then (c.toNat - 48).toUInt8")
    lines.append("    else if c.toNat >= 97 && c.toNat <= 102 then (c.toNat - 87).toUInt8")
    lines.append("    else if c.toNat >= 65 && c.toNat <= 70 then (c.toNat - 55).toUInt8")
    lines.append("    else 0")
    lines.append("  let rec go (cs : List Char) (acc : ByteArray) : ByteArray :=")
    lines.append("    match cs with")
    lines.append("    | hi :: lo :: rest => go rest (acc.push ((nibble hi <<< 4) ||| nibble lo))")
    lines.append("    | _ => acc")
    lines.append("  go chars ByteArray.empty")
    lines.append("")
    lines.append("def hexSeq (s : String) : OctetSeq n := ⟨hexToBytes s, sorry⟩")
    lines.append("")

    test_names = []
    for json_file in json_files:
        with open(os.path.join(test_dir, json_file)) as f:
            data = json.load(f)

        test_name = sanitize_name(json_file)
        test_names.append(test_name)

        lines.append(f"-- ============================================================================")
        lines.append(f"-- {json_file}")
        lines.append(f"-- ============================================================================")
        lines.append("")

        pre = data["pre_state"]
        post = data["post_state"]
        inp = data["input"]
        output = data["output"]

        # Pre state
        lines.append(gen_state(pre["accounts"], f"{test_name}_pre"))
        lines.append("")

        # Post state
        lines.append(gen_state(post["accounts"], f"{test_name}_post"))
        lines.append("")

        # Input preimages
        preimage_refs = []
        for i, p in enumerate(inp["preimages"]):
            defn, ref = gen_preimage(p, f"{test_name}_input", i)
            lines.append(defn)
            lines.append("")
            preimage_refs.append(ref)

        preimages_str = "#[" + ", ".join(preimage_refs) + "]" if preimage_refs else "#[]"
        lines.append(f"def {test_name}_input : TPInput := {{")
        lines.append(f"  preimages := {preimages_str},")
        lines.append(f"  slot := {inp['slot']}")
        lines.append("}")
        lines.append("")

        # Expected result
        lines.append(gen_result(output, f"{test_name}_result"))
        lines.append("")

    # Test runner
    lines.append("-- ============================================================================")
    lines.append("-- Test Runner")
    lines.append("-- ============================================================================")
    lines.append("")
    lines.append("end Jar.Test.PreimagesVectors")
    lines.append("")
    lines.append("open Jar.Test.Preimages Jar.Test.PreimagesVectors in")
    lines.append("def main : IO Unit := do")
    lines.append('  IO.println "Running preimages test vectors..."')
    lines.append("  let mut passed := (0 : Nat)")
    lines.append("  let mut failed := (0 : Nat)")

    for name in test_names:
        lines.append(
            f'  if (← runTest "{name}" {name}_pre {name}_input {name}_result {name}_post)'
        )
        lines.append(f"  then passed := passed + 1")
        lines.append(f"  else failed := failed + 1")

    lines.append(
        f'  IO.println s!"Preimages: {{passed}} passed, {{failed}} failed out of {len(test_names)}"'
    )
    lines.append("  if failed > 0 then")
    lines.append("    IO.Process.exit 1")

    with open(output_file, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Generated {output_file} with {len(test_names)} test cases")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <test_vectors_dir> <output_lean_file>")
        sys.exit(1)
    generate_test_file(sys.argv[1], sys.argv[2])
