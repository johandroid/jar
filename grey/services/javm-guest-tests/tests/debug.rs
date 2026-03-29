include!(concat!(env!("OUT_DIR"), "/guest_blob.rs"));

#[test]
fn debug_blob() {
    let input = {
        let mut v = 0u32.to_le_bytes().to_vec();
        v.extend_from_slice(&3u64.to_le_bytes());
        v.extend_from_slice(&7u64.to_le_bytes());
        v
    };

    let gas = 100_000_000_000u64;
    let mut pvm = javm::program::initialize_program(GUEST_TESTS_BLOB, &input, gas).unwrap();
    eprintln!("code len = {}", pvm.code.len());

    // Run with gas-block stepping to find where it panics
    let refuel = 50000u64;
    for block in 0..100_000 {
        pvm.gas = refuel;
        match pvm.run().0 {
            javm::ExitReason::Halt => {
                let packed = pvm.registers[7];
                let ptr = (packed >> 32) as usize;
                let len = (packed & 0xFFFFFFFF) as usize;
                eprintln!("HALT at block {block}: ptr=0x{ptr:X} len={len}");
                break;
            }
            javm::ExitReason::Panic => {
                eprintln!("PANIC at block {block}, PC={}", pvm.pc);
                for i in 0..13 {
                    if pvm.registers[i] != 0 {
                        eprintln!("  φ[{i}] = 0x{:X}", pvm.registers[i]);
                    }
                }
                // Dump nearby code
                let pc = pvm.pc as usize;
                if pc > 0 && pc < pvm.code.len() {
                    let start = pc.saturating_sub(3);
                    let end = (pc + 5).min(pvm.code.len());
                    eprintln!("  code[{start}..{end}] = {:?}", &pvm.code[start..end]);
                    eprintln!("  op at panic PC = {}", pvm.code[pc]);
                }
                break;
            }
            javm::ExitReason::OutOfGas => continue,
            javm::ExitReason::HostCall(_) => continue,
            other => {
                eprintln!("EXIT {other:?} at block {block}");
                break;
            }
        }
    }
}
