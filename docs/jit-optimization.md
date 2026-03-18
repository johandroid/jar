# JIT Optimization Roadmap

## Current state (March 2026)

The JAVM recompiler is a **single-pass, 1:1 instruction translator**. Each PVM
instruction maps directly to 1-5 x86-64 instructions with no cross-instruction
optimization. The JIT compiles PVM bytecode to native code as part of each
program execution — compilation + execution time both matter.

### Current benchmark results (vs polkavm generic-sandbox)

| Benchmark | grey recompiler | polkavm compiler | Ratio |
|-----------|----------------|-----------------|-------|
| fib (compute, no memory) | 418 µs | 423 µs | **0.99x** |
| hostcall (100K ecalli) | 618 µs | 3,233 µs | **5.2x faster** |
| sort (compute + memory) | 585 µs | 454 µs | **1.29x slower** |

The sort gap is entirely from the software bounds check (2 instructions per
memory access: `cmp + jae`). polkavm uses mprotect + SIGSEGV (0 instructions).
See `plans/sigsegv-safety.md` for why we chose software bounds checks.

## Optimizations (one-pass, no IR)

All optimizations below can be done in a single forward pass over the PVM
instruction stream, with zero or near-zero compile-time overhead.

### O1. Scaled-index addressing (sort: ~10-15% improvement)

**Pattern:** Array element access `arr[i]` generates:
```
PVM:  add t0,i,i / add t0,t0,t0 / add t0,base,t0 / load [t0]
x86:  add rdx,rdx / add rdx,rdx / add rdx,rsi / cmp+jae+mov [r15+rdx]
```

**Optimization:** Detect the shift-by-N + base-add + load pattern and emit
x86 scaled-index addressing:
```
x86:  lea edx,[esi+idx*4] / cmp+jae+mov [r15+rdx]
```

Saves 2 instructions per array access. The detection is a small window buffer
(check if the last 2-3 emitted instructions are `add r,r` pairs targeting the
same register).

**Applies to sort bench:** Yes — the inner loop computes `&arr[j]` via
`add+add+add+load` on every iteration. This is the highest-impact single
optimization for the sort benchmark.

### O2. Fused compare-and-branch

**Pattern:** PVM branches compare two registers directly (`blt ra, rb, target`).
Our codegen emits `cmp ra, rb; jcc target` which x86 CPUs already macro-fuse
into a single µop. **No change needed — already optimal.**

### O3. Immediate-address load/store folding

**Pattern:** `LoadU32 ra, imm` loads from a compile-time constant address:
```
Current:  mov edx, imm32 / cmp+jae / mov dst, [r15+rdx]
Better:   cmp edx_with_imm / jae / mov dst, [r15+imm32]
```

If `imm` fits in a 32-bit displacement (it always does — addresses are 32-bit),
use `[r15 + imm32]` directly without loading the address into SCRATCH first.
Saves 1 instruction per immediate-address load/store.

**Applies to sort bench:** No — sort uses register-indirect addressing (LoadInd),
not immediate addresses.

### O4. Multiply-accumulate fusion (crypto: ~20-30% improvement)

**Pattern:** Big-integer field multiplication generates sequences of:
```
PVM:  mul64 lo, a, b / mul_upper hi, a, b / add64 acc, acc, lo / ...
```

**Optimization:** Detect multiply-add chains and emit x86 `mulq` (which
produces 128-bit result in RDX:RAX) followed by `add + adc` for accumulation.
Eliminates separate mul_upper and reduces the instruction count for each
multiply-accumulate from ~6 to ~3.

For newer x86 (BMI2), use `mulx` + `adox`/`adcx` for carry-chain parallelism.

**Applies to sort bench:** No. Applies to crypto workloads (field arithmetic,
hash functions).

### O5. Constant address bounds check elimination

**Pattern:** When a load/store uses an immediate address AND the address is
provably within `[0, heap_top)` at compile time (e.g., accessing the stack at
a known offset), the bounds check can be eliminated entirely.

This requires knowing `heap_top` at compile time, which is true for programs
that never call `grow_heap`. The compiler can track a "minimum guaranteed
heap_top" (initialized from the program header's stack + data sizes) and skip
bounds checks for addresses below it.

**Applies to sort bench:** Partially — the initial array setup uses known
stack offsets, but the inner loop uses dynamic indices.

### O6. Basic-block-level address range check

**Pattern:** Instead of checking bounds per load/store, check once at the
start of a basic block that all addresses in the block are in range. If a
block accesses `arr[j]` through `arr[j+3]`, emit one bounds check for the
entire range `[min_addr, max_addr+width)`.

This requires scanning the block for memory accesses during the first pass
(which we already do for gas cost computation). For a block with N memory
accesses, reduces bounds checks from N to 1.

**Applies to sort bench:** Yes — the inner loop has 2 memory accesses
(load arr[j], store arr[j+1]) that could share one bounds check.

### O7. Dead move elimination

**Pattern:** `mov_rr(dst, src)` where `dst == src` is a no-op. Also,
`mov_rr(dst, src)` followed immediately by `mov_rr(dst, other)` — the first
move is dead.

We already handle the `dst == src` case in several instruction handlers. A
universal check in the assembler's `mov_rr` would catch the remaining cases.

**Applies to sort bench:** Minimally.

### O8. Permission table removal

**Status: ready to implement.**

The 1MB permission table and its sync logic are no longer needed with linear
memory + bounds check. Removing them saves 1MB virtual per PVM instance and
eliminates the permission table mmap/copy on initialization.

This is not a JIT codegen optimization but reduces compilation + initialization
overhead.

**Applies to sort bench:** Yes — reduces per-execution initialization cost
(relevant for the "compile + execute" benchmark).

## Priority order

| # | Optimization | Impact | Effort | Workloads helped |
|---|-------------|--------|--------|-----------------|
| O8 | Permission table removal | Low | Low | All (init time) |
| O1 | Scaled-index addressing | Medium | Medium | sort, any array code |
| O3 | Immediate-address folding | Low | Low | Stack-heavy code |
| O6 | Block-level bounds check | Medium | Medium | Memory-heavy loops |
| O4 | Multiply-accumulate fusion | High | High | Crypto primitives |
| O5 | Constant address elision | Low | Medium | Fixed-layout programs |
| O7 | Dead move elimination | Low | Low | All |

## What requires multi-pass (NOT recommended for now)

These optimizations require building an IR or doing backward analysis, which
adds significant compile time. Only worth it for very long-running programs
where execution time >> compile time.

- Cross-block register allocation
- Loop-invariant code motion
- Common subexpression elimination
- Instruction scheduling across basic blocks
- Full strength reduction (e.g., multiply by constant → shifts + adds)

For reference, Cranelift (used by Wasmtime) adds ~10x compile-time overhead
for ~2x execution improvement. This tradeoff only pays off for programs that
execute billions of instructions.
