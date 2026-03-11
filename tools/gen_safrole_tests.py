#!/usr/bin/env python3
"""
Generate Lean test files from safrole JSON test vectors.

Usage:
  python3 tools/gen_safrole_tests.py <test_vectors_dir> <output_lean_file>

Example:
  python3 tools/gen_safrole_tests.py \
    ../grey/res/testvectors/stf/safrole/full/ \
    Jar/Test/SafroleVectors.lean
"""

import json
import os
import sys
from pathlib import Path


def hex_to_lean_bytes(hex_str: str) -> str:
    """Convert '0xaabb...' to Lean ByteArray literal '#[0xaa, 0xbb, ...]'."""
    h = hex_str.removeprefix("0x")
    if len(h) == 0:
        return "ByteArray.mk #[]"
    bytes_ = [f"0x{h[i:i+2]}" for i in range(0, len(h), 2)]
    # For large arrays, use a compact representation
    if len(bytes_) > 16:
        return f"hexToBytes \"{h}\""
    return f"ByteArray.mk #[{', '.join(bytes_)}]"


def gen_hash(hex_str: str) -> str:
    """Generate OctetSeq 32 from hex string."""
    return f"⟨{hex_to_lean_bytes(hex_str)}, by native_decide⟩"


def gen_octet_seq(hex_str: str, size: int) -> str:
    """Generate OctetSeq n from hex string."""
    return f"⟨{hex_to_lean_bytes(hex_str)}, by native_decide⟩"


def gen_validator_key(vk: dict) -> str:
    """Generate ValidatorKey literal."""
    return (
        f"{{ bandersnatch := {gen_octet_seq(vk['bandersnatch'], 32)},\n"
        f"         ed25519 := {gen_octet_seq(vk['ed25519'], 32)},\n"
        f"         bls := {gen_octet_seq(vk['bls'], 144)},\n"
        f"         metadata := {gen_octet_seq(vk['metadata'], 128)} }}"
    )


def gen_ticket(t: dict) -> str:
    """Generate Ticket literal."""
    return (
        f"{{ id := {gen_hash(t['id'])},\n"
        f"         attempt := ⟨{t['attempt']}, by omega⟩ }}"
    )


def gen_ticket_proof(tp: dict) -> str:
    """Generate TicketProof literal."""
    return (
        f"{{ attempt := ⟨{tp['attempt']}, by omega⟩,\n"
        f"         proof := {gen_octet_seq(tp['signature'], 784)} }}"
    )


def gen_seal_keys(gs: dict) -> str:
    """Generate SealKeySeries literal."""
    if "tickets" in gs:
        tickets = gs["tickets"]
        items = ",\n      ".join(gen_ticket(t) for t in tickets)
        return f".tickets #[\n      {items}]"
    elif "keys" in gs:
        keys = gs["keys"]
        items = ",\n      ".join(gen_octet_seq(k, 32) for k in keys)
        return f".fallback #[\n      {items}]"
    else:
        raise ValueError(f"Unknown gamma_s shape: {gs.keys()}")


def gen_state(s: dict, name: str) -> str:
    """Generate FlatSafroleState definition."""
    lines = []
    lines.append(f"def {name} : FlatSafroleState := {{")
    lines.append(f"  tau := {s['tau']},")

    # eta: 4 hashes
    eta_items = ", ".join(gen_hash(e) for e in s["eta"])
    lines.append(f"  eta := #[{eta_items}],")

    # validator arrays - reference shared defs
    lines.append(f"  lambda := {name}_lambda,")
    lines.append(f"  kappa := {name}_kappa,")
    lines.append(f"  gamma_k := {name}_gamma_k,")
    lines.append(f"  iota := {name}_iota,")

    # gamma_a
    if len(s["gamma_a"]) == 0:
        lines.append(f"  gamma_a := #[],")
    else:
        ga_items = ",\n    ".join(gen_ticket(t) for t in s["gamma_a"])
        lines.append(f"  gamma_a := #[\n    {ga_items}],")

    # gamma_s
    lines.append(f"  gamma_s := {gen_seal_keys(s['gamma_s'])},")

    # gamma_z
    lines.append(f"  gamma_z := {gen_octet_seq(s['gamma_z'], 144)},")

    # post_offenders
    if len(s["post_offenders"]) == 0:
        lines.append(f"  post_offenders := #[]")
    else:
        off_items = ", ".join(gen_octet_seq(o, 32) for o in s["post_offenders"])
        lines.append(f"  post_offenders := #[{off_items}]")

    lines.append("}")
    return "\n".join(lines)


def gen_validator_array(keys: list, name: str) -> str:
    """Generate a validator key array definition."""
    items = ",\n    ".join(gen_validator_key(vk) for vk in keys)
    return f"def {name} : Array ValidatorKey := #[\n    {items}]"


def gen_input(inp: dict, name: str) -> str:
    """Generate SafroleInput definition."""
    lines = []
    lines.append(f"def {name} : SafroleInput := {{")
    lines.append(f"  slot := {inp['slot']},")
    lines.append(f"  entropy := {gen_hash(inp['entropy'])},")

    if len(inp["extrinsic"]) == 0:
        lines.append(f"  extrinsic := #[]")
    else:
        tp_items = ",\n    ".join(gen_ticket_proof(tp) for tp in inp["extrinsic"])
        lines.append(f"  extrinsic := #[\n    {tp_items}]")

    lines.append("}")
    return "\n".join(lines)


def gen_result(output: dict, name: str) -> str:
    """Generate SafroleResult definition."""
    if output is None:
        return f"def {name} : SafroleResult := .ok {{ epoch_mark := none, tickets_mark := none }}"

    if "ok" in output:
        ok = output["ok"]
        em = ok.get("epoch_mark")
        tm = ok.get("tickets_mark")

        em_str = "none"
        if em is not None:
            em_vals = ", ".join(
                f"({gen_octet_seq(v[0], 32)}, {gen_octet_seq(v[1], 32)})"
                for v in em["validators"]
            )
            em_str = (
                f"some {{\n"
                f"    entropy := {gen_hash(em['entropy'])},\n"
                f"    entropyPrev := {gen_hash(em['tickets_entropy'])},\n"
                f"    validators := #[{em_vals}] }}"
            )

        tm_str = "none"
        if tm is not None:
            tm_items = ",\n    ".join(gen_ticket(t) for t in tm)
            tm_str = f"some #[\n    {tm_items}]"

        return f"def {name} : SafroleResult := .ok {{ epoch_mark := {em_str}, tickets_mark := {tm_str} }}"

    elif "err" in output:
        return f'def {name} : SafroleResult := .err "{output["err"]}"'

    return f"def {name} : SafroleResult := .ok {{ epoch_mark := none, tickets_mark := none }}"


def sanitize_name(filename: str) -> str:
    """Convert filename to a valid Lean identifier."""
    name = Path(filename).stem
    # Replace hyphens with underscores
    name = name.replace("-", "_")
    return name


def check_validator_arrays_equal(a: list, b: list) -> bool:
    """Check if two validator arrays are identical."""
    if len(a) != len(b):
        return False
    for va, vb in zip(a, b):
        if va != vb:
            return False
    return True


def generate_test_file(test_dir: str, output_file: str):
    """Generate the complete Lean test file."""
    json_files = sorted(f for f in os.listdir(test_dir) if f.endswith(".json"))

    if not json_files:
        print(f"No JSON files found in {test_dir}")
        sys.exit(1)

    print(f"Generating tests for {len(json_files)} test vectors...")

    # We'll use a simpler approach: since validator arrays are huge (1023 entries),
    # use native_decide proofs and hexToBytes helper.
    # But first, check if pre/post states share validator arrays across tests.

    lines = []
    lines.append("import Jar.Test.Safrole")
    lines.append("")
    lines.append("/-! Auto-generated safrole test vectors. Do not edit. -/")
    lines.append("")
    lines.append("namespace Jar.Test.SafroleVectors")
    lines.append("")
    lines.append("open Jar Jar.Test.Safrole")
    lines.append("")

    # Helper for hex→bytes
    lines.append("/-- Convert hex string to ByteArray. -/")
    lines.append("def hexToBytes (s : String) : ByteArray :=")
    lines.append("  let chars := s.data")
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

    # OctetSeq from hex — use sorry for proof (test data only)
    lines.append("/-- Create OctetSeq n from hex string. For test data only. -/")
    lines.append("def hexSeq (s : String) : OctetSeq n :=")
    lines.append("  ⟨hexToBytes s, sorry⟩")
    lines.append("")

    # Helper for ValidatorKey from hex strings
    lines.append("def mkVK (bs ed bl mt : String) : ValidatorKey := {")
    lines.append("  bandersnatch := hexSeq bs,")
    lines.append("  ed25519 := hexSeq ed,")
    lines.append("  bls := hexSeq bl,")
    lines.append("  metadata := hexSeq mt }")
    lines.append("")

    # Helper for Ticket
    lines.append("def mkTicket (idHex : String) (attempt : Nat) : Ticket :=")
    lines.append("  { id := hexSeq idHex,")
    lines.append("    attempt := ⟨attempt, sorry⟩ }")
    lines.append("")

    # Helper for TicketProof
    lines.append("def mkTicketProof (attempt : Nat) (sig : String) : TicketProof :=")
    lines.append("  { attempt := ⟨attempt, sorry⟩,")
    lines.append("    proof := hexSeq sig }")
    lines.append("")

    # Now generate each test
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

        # Generate validator arrays for pre_state
        for field in ["lambda", "kappa", "gamma_k", "iota"]:
            vks = pre[field]
            lines.append(f"def {test_name}_pre_{field} : Array ValidatorKey := #[")
            for i, vk in enumerate(vks):
                comma = "," if i < len(vks) - 1 else ""
                bs = vk["bandersnatch"].removeprefix("0x")
                ed = vk["ed25519"].removeprefix("0x")
                bls_hex = vk["bls"].removeprefix("0x")
                meta = vk["metadata"].removeprefix("0x")
                lines.append(f"  mkVK \"{bs}\" \"{ed}\" \"{bls_hex}\" \"{meta}\"{comma}")
            lines.append("]")
            lines.append("")

        # Generate pre_state
        lines.append(f"def {test_name}_pre : FlatSafroleState := {{")
        lines.append(f"  tau := {pre['tau']},")
        eta_items = ", ".join(f"hexSeq \"{e.removeprefix('0x')}\"" for e in pre["eta"])
        lines.append(f"  eta := #[{eta_items}],")
        lines.append(f"  lambda := {test_name}_pre_lambda,")
        lines.append(f"  kappa := {test_name}_pre_kappa,")
        lines.append(f"  gamma_k := {test_name}_pre_gamma_k,")
        lines.append(f"  iota := {test_name}_pre_iota,")

        # gamma_a
        if len(pre["gamma_a"]) == 0:
            lines.append(f"  gamma_a := #[],")
        else:
            lines.append(f"  gamma_a := #[")
            for i, t in enumerate(pre["gamma_a"]):
                comma = "," if i < len(pre["gamma_a"]) - 1 else ""
                tid = t["id"].removeprefix("0x")
                lines.append(f"    mkTicket \"{tid}\" {t['attempt']}{comma}")
            lines.append(f"  ],")

        # gamma_s
        gs = pre["gamma_s"]
        if "tickets" in gs:
            lines.append(f"  gamma_s := .tickets #[")
            for i, t in enumerate(gs["tickets"]):
                comma = "," if i < len(gs["tickets"]) - 1 else ""
                tid = t["id"].removeprefix("0x")
                lines.append(f"    mkTicket \"{tid}\" {t['attempt']}{comma}")
            lines.append(f"  ],")
        else:
            lines.append(f"  gamma_s := .fallback #[")
            for i, k in enumerate(gs["keys"]):
                comma = "," if i < len(gs["keys"]) - 1 else ""
                lines.append(f"    hexSeq \"{k.removeprefix('0x')}\"{comma}")
            lines.append(f"  ],")

        lines.append(f"  gamma_z := hexSeq \"{pre['gamma_z'].removeprefix('0x')}\",")

        if len(pre["post_offenders"]) == 0:
            lines.append(f"  post_offenders := #[]")
        else:
            off_items = ", ".join(f"hexSeq \"{o.removeprefix('0x')}\"" for o in pre["post_offenders"])
            lines.append(f"  post_offenders := #[{off_items}]")
        lines.append("}")
        lines.append("")

        # Generate post_state validator arrays
        for field in ["lambda", "kappa", "gamma_k", "iota"]:
            # Check if same as pre
            if check_validator_arrays_equal(pre[field], post[field]):
                lines.append(f"def {test_name}_post_{field} : Array ValidatorKey := {test_name}_pre_{field}")
            else:
                vks = post[field]
                lines.append(f"def {test_name}_post_{field} : Array ValidatorKey := #[")
                for i, vk in enumerate(vks):
                    comma = "," if i < len(vks) - 1 else ""
                    bs = vk["bandersnatch"].removeprefix("0x")
                    ed = vk["ed25519"].removeprefix("0x")
                    bls_hex = vk["bls"].removeprefix("0x")
                    meta = vk["metadata"].removeprefix("0x")
                    lines.append(f"  mkVK \"{bs}\" \"{ed}\" \"{bls_hex}\" \"{meta}\"{comma}")
                lines.append("]")
            lines.append("")

        # Generate post_state
        lines.append(f"def {test_name}_post : FlatSafroleState := {{")
        lines.append(f"  tau := {post['tau']},")
        eta_items = ", ".join(f"hexSeq \"{e.removeprefix('0x')}\"" for e in post["eta"])
        lines.append(f"  eta := #[{eta_items}],")
        lines.append(f"  lambda := {test_name}_post_lambda,")
        lines.append(f"  kappa := {test_name}_post_kappa,")
        lines.append(f"  gamma_k := {test_name}_post_gamma_k,")
        lines.append(f"  iota := {test_name}_post_iota,")

        # gamma_a
        if len(post["gamma_a"]) == 0:
            lines.append(f"  gamma_a := #[],")
        else:
            lines.append(f"  gamma_a := #[")
            for i, t in enumerate(post["gamma_a"]):
                comma = "," if i < len(post["gamma_a"]) - 1 else ""
                tid = t["id"].removeprefix("0x")
                lines.append(f"    mkTicket \"{tid}\" {t['attempt']}{comma}")
            lines.append(f"  ],")

        # gamma_s
        gs2 = post["gamma_s"]
        if "tickets" in gs2:
            lines.append(f"  gamma_s := .tickets #[")
            for i, t in enumerate(gs2["tickets"]):
                comma = "," if i < len(gs2["tickets"]) - 1 else ""
                tid = t["id"].removeprefix("0x")
                lines.append(f"    mkTicket \"{tid}\" {t['attempt']}{comma}")
            lines.append(f"  ],")
        else:
            lines.append(f"  gamma_s := .fallback #[")
            for i, k in enumerate(gs2["keys"]):
                comma = "," if i < len(gs2["keys"]) - 1 else ""
                lines.append(f"    hexSeq \"{k.removeprefix('0x')}\"{comma}")
            lines.append(f"  ],")

        lines.append(f"  gamma_z := hexSeq \"{post['gamma_z'].removeprefix('0x')}\",")

        if len(post["post_offenders"]) == 0:
            lines.append(f"  post_offenders := #[]")
        else:
            off_items = ", ".join(f"hexSeq \"{o.removeprefix('0x')}\"" for o in post["post_offenders"])
            lines.append(f"  post_offenders := #[{off_items}]")
        lines.append("}")
        lines.append("")

        # Generate input
        lines.append(f"def {test_name}_input : SafroleInput := {{")
        lines.append(f"  slot := {inp['slot']},")
        lines.append(f"  entropy := hexSeq \"{inp['entropy'].removeprefix('0x')}\",")
        if len(inp["extrinsic"]) == 0:
            lines.append(f"  extrinsic := #[]")
        else:
            lines.append(f"  extrinsic := #[")
            for i, tp in enumerate(inp["extrinsic"]):
                comma = "," if i < len(inp["extrinsic"]) - 1 else ""
                sig = tp["signature"].removeprefix("0x")
                lines.append(f"    mkTicketProof {tp['attempt']} \"{sig}\"{comma}")
            lines.append(f"  ]")
        lines.append("}")
        lines.append("")

        # Generate expected result
        if output is None:
            lines.append(f"def {test_name}_result : SafroleResult := .ok {{ epoch_mark := none, tickets_mark := none }}")
        elif "ok" in output:
            ok = output["ok"]
            em = ok.get("epoch_mark")
            tm = ok.get("tickets_mark")

            lines.append(f"def {test_name}_result : SafroleResult := .ok {{")
            if em is None:
                lines.append(f"  epoch_mark := none,")
            else:
                lines.append(f"  epoch_mark := some {{")
                lines.append(f"    entropy := hexSeq \"{em['entropy'].removeprefix('0x')}\",")
                lines.append(f"    entropyPrev := hexSeq \"{em['tickets_entropy'].removeprefix('0x')}\",")
                lines.append(f"    validators := #[")
                for i, v in enumerate(em["validators"]):
                    comma = "," if i < len(em["validators"]) - 1 else ""
                    bs = v["bandersnatch"].removeprefix("0x")
                    ed = v["ed25519"].removeprefix("0x")
                    lines.append(f"      (hexSeq \"{bs}\", hexSeq \"{ed}\"){comma}")
                lines.append(f"    ] }},")

            if tm is None:
                lines.append(f"  tickets_mark := none")
            else:
                lines.append(f"  tickets_mark := some #[")
                for i, t in enumerate(tm):
                    comma = "," if i < len(tm) - 1 else ""
                    tid = t["id"].removeprefix("0x")
                    lines.append(f"    mkTicket \"{tid}\" {t['attempt']}{comma}")
                lines.append(f"  ]")
            lines.append("}")
        elif "err" in output:
            lines.append(f'def {test_name}_result : SafroleResult := .err "{output["err"]}"')
        lines.append("")

    # Generate main runner
    lines.append("-- ============================================================================")
    lines.append("-- Test Runner")
    lines.append("-- ============================================================================")
    lines.append("")
    lines.append("end Jar.Test.SafroleVectors")
    lines.append("")
    lines.append("open Jar.Test.Safrole Jar.Test.SafroleVectors in")
    lines.append("def main : IO Unit := do")
    lines.append("  IO.println \"Running safrole test vectors...\"")
    lines.append("  let mut passed := (0 : Nat)")
    lines.append("  let mut failed := (0 : Nat)")

    for name in test_names:
        lines.append(f"  if (← runTest \"{name}\" {name}_pre {name}_input {name}_result {name}_post)")
        lines.append(f"  then passed := passed + 1")
        lines.append(f"  else failed := failed + 1")

    lines.append(f"  IO.println s!\"Safrole: {{passed}} passed, {{failed}} failed out of {len(test_names)}\"")
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
