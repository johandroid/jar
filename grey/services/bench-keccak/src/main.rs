//! Keccak-256 hashing benchmark.

#![no_std]
#![no_main]

const MSG_LEN: usize = 1024;

#[cfg(not(target_env = "polkavm"))]
core::arch::global_asm!(
    ".global _start",
    "_start:",
    "call keccak_bench",
    "lui t0, 0xffff0",
    "jr t0",
);

#[cfg(target_env = "polkavm")]
core::arch::global_asm!(
    ".global _start",
    "_start:",
    "unimp",
);

/// Theta step through non-inlined function
#[inline(never)]
#[no_mangle]
pub extern "C" fn do_theta(state: &mut [u64; 25]) {
    let mut c = [0u64; 5];
    let mut x: usize = 0;
    while x < 5 {
        c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
        x += 1;
    }
    x = 0;
    while x < 5 {
        let d = c[(x + 4) % 5] ^ c[(x + 1) % 5].rotate_left(1);
        let mut y: usize = 0;
        while y < 25 {
            state[x + y] ^= d;
            y += 5;
        }
        x += 1;
    }
}

#[cfg_attr(target_env = "polkavm", polkavm_derive::polkavm_export)]
#[no_mangle]
pub extern "C" fn keccak_bench() -> u32 {
    let mut state = [0u64; 25];
    state[0] = 0x0000000001636261;
    state[16] = 0x8000000000000000;
    do_theta(&mut state);
    // Expected: 0x01636260
    state[0] as u32
}

#[no_mangle]
pub unsafe extern "C" fn memset(dst: *mut u8, val: i32, n: usize) -> *mut u8 {
    let mut i = 0;
    while i < n { unsafe { *dst.add(i) = val as u8; } i += 1; }
    dst
}

#[no_mangle]
pub unsafe extern "C" fn memcpy(dst: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    let mut i = 0;
    while i < n { unsafe { *dst.add(i) = *src.add(i); } i += 1; }
    dst
}

#[no_mangle]
pub unsafe extern "C" fn memcmp(s1: *const u8, s2: *const u8, n: usize) -> i32 {
    let mut i = 0;
    while i < n {
        let a = unsafe { *s1.add(i) };
        let b = unsafe { *s2.add(i) };
        if a != b { return a as i32 - b as i32; }
        i += 1;
    }
    0
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    unsafe { core::arch::asm!("li a0, 0xDEAD", "unimp", options(noreturn)); }
}
