fn main() {
    // When cross-compiling for RISC-V (as the guest), don't recurse.
    let target = std::env::var("TARGET").unwrap_or_default();
    if target.contains("riscv") {
        return;
    }

    // Use opt-level=1 to prevent LLVM from generating switch jump tables.
    // The PVM transpiler doesn't fully support computed indirect branches
    // from data tables yet (issue: R_RISCV_ADD32/SUB32 relative jump tables).
    let blob = build_javm::build_with_opt(".", "javm-guest-tests", "3");
    let out_dir = std::env::var("OUT_DIR").unwrap();
    std::fs::write(
        format!("{out_dir}/guest_blob.rs"),
        format!(
            "const GUEST_TESTS_BLOB: &[u8] = include_bytes!(\"{}\");\n",
            blob.display(),
        ),
    )
    .unwrap();
}
