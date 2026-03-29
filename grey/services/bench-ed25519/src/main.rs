//! Ed25519 signature verification benchmark.

#![no_std]
#![no_main]

use ed25519_compact::{PublicKey, Signature};

// RFC 8032 Test Vector 3 (2-byte message)
const PUBLIC_KEY_BYTES: [u8; 32] = [
    0xfc, 0x51, 0xcd, 0x8e, 0x62, 0x18, 0xa1, 0xa3,
    0x8d, 0xa4, 0x7e, 0xd0, 0x02, 0x30, 0xf0, 0x58,
    0x08, 0x16, 0xed, 0x13, 0xba, 0x33, 0x03, 0xac,
    0x5d, 0xeb, 0x91, 0x15, 0x48, 0x90, 0x80, 0x25,
];

const MESSAGE: [u8; 2] = [0xaf, 0x82];

const SIGNATURE_BYTES: [u8; 64] = [
    0x62, 0x91, 0xd6, 0x57, 0xde, 0xec, 0x24, 0x02,
    0x48, 0x27, 0xe6, 0x9c, 0x3a, 0xbe, 0x01, 0xa3,
    0x0c, 0xe5, 0x48, 0xa2, 0x84, 0x74, 0x3a, 0x44,
    0x5e, 0x36, 0x80, 0xd7, 0xdb, 0x5a, 0xc3, 0xac,
    0x18, 0xff, 0x9b, 0x53, 0x8d, 0x16, 0xf2, 0x90,
    0xae, 0x67, 0xf7, 0x60, 0x98, 0x4d, 0xc6, 0x59,
    0x4a, 0x7c, 0x15, 0xe9, 0x71, 0x6e, 0xd2, 0x8d,
    0xc0, 0x27, 0xbe, 0xce, 0xea, 0x1e, 0xc4, 0x0a,
];

#[cfg(not(target_env = "polkavm"))]
core::arch::global_asm!(
    ".global _start",
    "_start:",
    "call ed25519_verify_bench",
    "lui t0, 0xffff0",
    "jr t0",
);

#[cfg(target_env = "polkavm")]
core::arch::global_asm!(
    ".global _start",
    "_start:",
    "unimp",
);

/// Verify an Ed25519 signature. Returns 1 on success, 0 on failure.
#[cfg_attr(target_env = "polkavm", polkavm_derive::polkavm_export)]
#[no_mangle]
pub extern "C" fn ed25519_verify_bench() -> u32 {
    let pk = match PublicKey::from_slice(&PUBLIC_KEY_BYTES) {
        Ok(pk) => pk,
        Err(_) => return 0,
    };
    let sig = match Signature::from_slice(&SIGNATURE_BYTES) {
        Ok(sig) => sig,
        Err(_) => return 0,
    };
    match pk.verify(&MESSAGE, &sig) {
        Ok(_) => 1,
        Err(_) => 0,
    }
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
