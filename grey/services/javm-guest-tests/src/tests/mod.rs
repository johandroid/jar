pub mod arithmetic;
pub mod bitwise;
pub mod crypto;
pub mod memory;

/// Dispatch to a test function by ID.
#[inline(never)]
pub fn dispatch_by_id(test_id: u32, args: &[u8], output: &mut [u8]) -> usize {
    if test_id == 0 { return arithmetic::add_u64(args, output); }
    if test_id == 1 { return arithmetic::sub_u64(args, output); }
    if test_id == 2 { return arithmetic::mul_u64(args, output); }
    if test_id == 3 { return arithmetic::mul_upper_uu(args, output); }
    if test_id == 4 { return arithmetic::mul_upper_ss(args, output); }
    if test_id == 5 { return arithmetic::div_u64(args, output); }
    if test_id == 6 { return arithmetic::rem_u64(args, output); }
    if test_id == 7 { return arithmetic::div_s64(args, output); }
    if test_id == 8 { return arithmetic::rem_s64(args, output); }
    if test_id == 10 { return bitwise::shift_left(args, output); }
    if test_id == 11 { return bitwise::shift_right_logical(args, output); }
    if test_id == 12 { return bitwise::shift_right_arithmetic(args, output); }
    if test_id == 13 { return bitwise::rotate_right(args, output); }
    if test_id == 14 { return bitwise::and(args, output); }
    if test_id == 15 { return bitwise::or(args, output); }
    if test_id == 16 { return bitwise::xor(args, output); }
    if test_id == 17 { return bitwise::clz(args, output); }
    if test_id == 18 { return bitwise::ctz(args, output); }
    if test_id == 19 { return bitwise::set_lt_u(args, output); }
    if test_id == 20 { return bitwise::set_lt_s(args, output); }
    if test_id == 30 { return memory::memcpy_test(args, output); }
    if test_id == 31 { return memory::sort_u32(args, output); }
    if test_id == 32 { return memory::fib(args, output); }
    if test_id == 40 { return crypto::blake2b_256(args, output); }
    if test_id == 41 { return crypto::keccak_256(args, output); }
    0
}
