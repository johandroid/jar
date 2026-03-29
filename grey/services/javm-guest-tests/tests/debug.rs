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
    let mut pvm = javm::program::initialize_program(GUEST_TESTS_BLOB, &[], gas).unwrap();
    let sp = pvm.registers[1] as usize;
    pvm.flat_mem[sp..sp + input.len()].copy_from_slice(&input);
    pvm.registers[7] = sp as u64;
    pvm.registers[8] = input.len() as u64;

    let mut steps = 0u64;
    loop {
        let prev_pc = pvm.pc;
        let prev_regs = pvm.registers;
        match pvm.step() {
            None => {
                steps += 1;
                // Log EVERY register change
                for r in 0..13 {
                    if pvm.registers[r] != prev_regs[r] {
                        let op = pvm.code[prev_pc as usize];
                        eprintln!("[{steps}] PC={prev_pc} op={op}: φ[{r}] = 0x{:X} → 0x{:X}", prev_regs[r], pvm.registers[r]);
                    }
                }
                if steps > 100000 { break; }
            }
            Some(javm::ExitReason::Halt) => { eprintln!("HALT a0=0x{:X}", pvm.registers[7]); break; }
            Some(javm::ExitReason::Panic) => {
                eprintln!("PANIC at PC={prev_pc}");
                for r in 0..13 { if pvm.registers[r] != 0 { eprintln!("  φ[{r}]=0x{:X}", pvm.registers[r]); } }
                break;
            }
            Some(_) => { steps += 1; }
        }
    }
}
