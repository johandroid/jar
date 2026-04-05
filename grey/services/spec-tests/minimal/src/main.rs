//! Minimal no-op JAM service for spec accumulate test vectors.
//!
//! - **Refine**: returns immediately (identity)
//! - **Accumulate**: returns immediately (no host calls, no state changes)

#![cfg_attr(target_env = "javm", no_std)]
#![cfg_attr(target_env = "javm", no_main)]

#[cfg(target_env = "javm")]
mod service {
    use core::arch::global_asm;

    global_asm!(
        ".global _start",
        ".type _start, @function",
        "_start:",
        "j refine",
        ".global refine",
        ".type refine, @function",
        "refine:",
        "li t0, 255",     // ecalli(0xFF) = REPLY
        "ecall",
        "unimp",
        ".global accumulate",
        ".type accumulate, @function",
        "accumulate:",
        "li t0, 255",     // ecalli(0xFF) = REPLY
        "ecall",
        "unimp",
    );

    #[panic_handler]
    fn panic(_: &core::panic::PanicInfo) -> ! {
        loop {}
    }
}

#[cfg(not(target_env = "javm"))]
fn main() {}
