import Jar.PVM
import Jar.PVM.Decode

/-!
# PVM Per-Basic-Block Gas Cost Model — GP v0.8.0

Simulates a CPU pipeline to compute gas cost for a basic block.
The cost is `max(simulation_result.cycles - 3, 1)`.

Pipeline model:
- Reorder buffer: max 32 entries
- 4 decode slots per cycle
- 5 dispatch slots per cycle
- Execution units per cycle: ALU:4, LOAD:4, STORE:4, MUL:1, DIV:1
-/

namespace Jar.PVM

-- ============================================================================
-- Data Structures
-- ============================================================================

/-- Execution unit requirements for an instruction. -/
structure ExecUnits where
  alu  : Nat := 0
  load : Nat := 0
  store : Nat := 0
  mul  : Nat := 0
  div  : Nat := 0
  deriving Inhabited, BEq

/-- ROB entry state. -/
inductive RobState where
  | dec   -- decoded, waiting for dependencies
  | wait  -- dependencies resolved, waiting for dispatch
  | exe   -- executing
  | fin   -- finished
  deriving BEq, Inhabited

/-- Reorder buffer entry. -/
structure RobEntry where
  state     : RobState
  cyclesLeft : Nat
  deps      : Array Nat       -- ROB indices this depends on
  destRegs  : Array Nat       -- registers written
  execUnits : ExecUnits       -- units required to start execution
  deriving Inhabited

/-- Pipeline simulation state. -/
structure GasSimState where
  ι                    : Option Nat       -- current instruction counter (none = done decoding)
  cycles               : Nat              -- cycle counter
  remainingDecodeSlots : Nat              -- reset to 4 each cycle
  remainingStartSlots  : Nat              -- reset to 5 each cycle
  remainingExecUnits   : ExecUnits        -- reset to (4,4,4,1,1) each cycle
  rob                  : Array RobEntry   -- reorder buffer
  deriving Inhabited

-- ============================================================================
-- Execution unit helpers
-- ============================================================================

/-- Check whether `avail` has enough units to satisfy `req`. -/
def ExecUnits.canSatisfy (avail req : ExecUnits) : Bool :=
  avail.alu >= req.alu && avail.load >= req.load && avail.store >= req.store &&
  avail.mul >= req.mul && avail.div >= req.div

/-- Subtract requirements from available units. -/
def ExecUnits.sub (avail req : ExecUnits) : ExecUnits :=
  { alu  := avail.alu - req.alu
    load := avail.load - req.load
    store := avail.store - req.store
    mul  := avail.mul - req.mul
    div  := avail.div - req.div }

-- ============================================================================
-- Branch cost
-- ============================================================================

/-- Branch cost 𝔟: 1 if target is unlikely(2) or trap(0), else 20. -/
def branchCost (code bitmask : ByteArray) (targetPC : Nat) : Nat :=
  -- Check if targetPC is a valid instruction start and read its opcode
  if targetPC < code.size && bitmaskGet bitmask targetPC then
    let opcode := code.get! targetPC |>.toNat
    if opcode == 0 || opcode == 2 then 1 else 20
  else 20

-- ============================================================================
-- Per-instruction cost
-- ============================================================================

/-- Result of instruction cost analysis. -/
structure InstrCost where
  cycles     : Nat
  decodeSlots : Nat
  execUnits  : ExecUnits
  destRegs   : Array Nat
  srcRegs    : Array Nat
  isTerminator : Bool   -- if true, sets ι := none after adding to ROB
  isMoveReg  : Bool     -- if true, handled in frontend only (no ROB entry)

/-- Check if destination overlaps any source register (for ifdstoverlap). -/
private def dstOverlapsSrc (dst : Nat) (srcs : Array Nat) : Bool :=
  srcs.any (· == dst)

/-- Instruction cost lookup.
    Returns cost info based on opcode. Uses code/bitmask for branch target lookup. -/
def instructionCost (code bitmask : ByteArray) (pc : Nat) : InstrCost :=
  let opcode := if pc < code.size then code.get! pc |>.toNat else 0
  let skip := skipDistance bitmask pc
  -- Helper: extract register indices
  let rA := (regA code pc).val
  let rB := (regB code pc).val
  let rD := (regD code pc).val
  -- Default: non-terminator, not move_reg
  let mkCost (cy dc : Nat) (eu : ExecUnits) (dst src : Array Nat) (term : Bool := false) : InstrCost :=
    { cycles := cy, decodeSlots := dc, execUnits := eu,
      destRegs := dst, srcRegs := src, isTerminator := term, isMoveReg := false }
  let aluUnit : ExecUnits := { alu := 1 }
  let loadUnit : ExecUnits := { alu := 1, load := 1 }
  let storeUnit : ExecUnits := { alu := 1, store := 1 }
  let mulUnit : ExecUnits := { alu := 1, mul := 1 }
  let divUnit : ExecUnits := { alu := 1, div := 1 }
  match opcode with
  -- No-arg instructions
  | 0 => mkCost 2 1 {} #[] #[] true           -- trap
  | 1 => mkCost 2 1 {} #[] #[] true           -- fallthrough
  | 2 => mkCost 40 1 {} #[] #[] true          -- unlikely
  | 10 => mkCost 100 4 aluUnit #[] #[] true   -- ecalli

  -- Control flow
  | 40 => mkCost 15 1 aluUnit #[] #[] true    -- jump
  | 80 =>                                      -- load_imm_jump
    let (r, _, _) := extractRegImmOffset code pc skip
    mkCost 15 1 aluUnit #[r.val] #[] true
  | 50 => mkCost 22 1 aluUnit #[] #[] true    -- jump_ind
  | 180 =>                                     -- load_imm_jump_ind
    let rA' := rA; let rB' := rB
    mkCost 22 1 aluUnit #[rA'] #[rB'] true

  -- Loads
  | 52 | 53 | 54 | 55 | 56 | 57 | 58 =>
    mkCost 25 1 loadUnit #[rA] #[rB]
  | 124 | 125 | 126 | 127 | 128 | 129 | 130 =>
    mkCost 25 1 loadUnit #[rA] #[rB]

  -- Stores
  | 59 | 60 | 61 | 62 =>
    mkCost 25 1 storeUnit #[] #[rA, rB]
  | 120 | 121 | 122 | 123 =>
    mkCost 25 1 storeUnit #[] #[rA, rB]
  | 30 | 31 | 32 | 33 =>
    mkCost 25 1 storeUnit #[] #[]
  | 70 | 71 | 72 | 73 =>
    mkCost 25 1 storeUnit #[] #[rA]

  -- Load immediates
  | 51 => mkCost 1 1 {} #[rA] #[]             -- load_imm
  | 20 => mkCost 1 2 {} #[rA] #[]             -- load_imm_64

  -- move_reg: decoded in frontend, does NOT enter ROB
  | 100 =>
    { cycles := 0, decodeSlots := 1, execUnits := {},
      destRegs := #[rA], srcRegs := #[rB],
      isTerminator := false, isMoveReg := true }

  -- Branches (reg + imm + offset)
  | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 89 | 90 =>
    let (_, _, target) := extractRegImmOffset code pc skip
    let bc := branchCost code bitmask target.toNat
    mkCost bc 1 aluUnit #[] #[rA] true

  -- Branches (two-reg + offset)
  | 170 | 171 | 172 | 173 | 174 | 175 =>
    let (_, _, target) := extractTwoRegOffset code pc skip
    let bc := branchCost code bitmask target.toNat
    mkCost bc 1 aluUnit #[] #[rA, rB] true

  -- ALU 64-bit 3-reg: add_64, sub_64, and, xor, or
  | 200 | 201 | 210 | 211 | 212 =>
    let dc := if dstOverlapsSrc rA #[rB, rD] then 1 else 2
    mkCost 1 dc aluUnit #[rA] #[rB, rD]

  -- ALU 32-bit 3-reg: add_32, sub_32
  | 190 | 191 =>
    let dc := if dstOverlapsSrc rA #[rB, rD] then 2 else 3
    mkCost 2 dc aluUnit #[rA] #[rB, rD]

  -- ALU 2-op imm 64-bit
  | 132 | 133 | 134 | 149 | 151 | 152 | 153 | 158 | 110 =>
    let dc := if dstOverlapsSrc rA #[rB] then 1 else 2
    mkCost 1 dc aluUnit #[rA] #[rB]

  -- ALU 2-op imm 32-bit
  | 131 | 138 | 139 | 140 | 160 =>
    let dc := if dstOverlapsSrc rA #[rB] then 2 else 3
    mkCost 2 dc aluUnit #[rA] #[rB]

  -- Trivial 2-op 1-cycle: popcount64, popcount32, clz64, clz32, sign_extend_8, sign_extend_16, zero_extend_16
  | 102 | 103 | 104 | 105 | 108 | 109 =>
    mkCost 1 1 aluUnit #[rA] #[rB]

  -- Trivial 2-op 2-cycle: ctz64, ctz32
  | 106 | 107 =>
    mkCost 2 1 aluUnit #[rA] #[rB]

  -- Shifts 64-bit 3-reg
  | 207 | 208 | 209 | 220 | 222 =>
    let dc := if rB == rA then 2 else 3
    mkCost 1 dc aluUnit #[rA] #[rB, rD]

  -- Shifts 32-bit 3-reg
  | 197 | 198 | 199 | 221 | 223 =>
    let dc := if rB == rA then 3 else 4
    mkCost 2 dc aluUnit #[rA] #[rB, rD]

  -- Shift alt 64-bit
  | 155 | 156 | 157 | 159 =>
    mkCost 1 3 aluUnit #[rA] #[rB]

  -- Shift alt 32-bit
  | 144 | 145 | 146 | 161 =>
    mkCost 2 4 aluUnit #[rA] #[rB]

  -- Comparisons
  | 216 | 217 =>
    mkCost 3 3 aluUnit #[rA] #[rB, rD]
  | 136 | 137 | 142 | 143 =>
    mkCost 3 3 aluUnit #[rA] #[rB]

  -- Conditional moves (3-reg)
  | 218 | 219 =>
    mkCost 2 2 aluUnit #[rA] #[rB, rD]

  -- Conditional moves imm
  | 147 | 148 =>
    mkCost 2 3 aluUnit #[rA] #[rB]

  -- Min/Max
  | 227 | 228 | 229 | 230 =>
    let dc := if dstOverlapsSrc rA #[rB, rD] then 2 else 3
    mkCost 3 dc aluUnit #[rA] #[rB, rD]

  -- and_inv, or_inv
  | 224 | 225 =>
    mkCost 2 3 aluUnit #[rA] #[rB, rD]

  -- xnor
  | 226 =>
    let dc := if dstOverlapsSrc rA #[rB, rD] then 2 else 3
    mkCost 2 dc aluUnit #[rA] #[rB, rD]

  -- neg_add_imm_64
  | 154 =>
    mkCost 2 3 aluUnit #[rA] #[rB]

  -- neg_add_imm_32
  | 141 =>
    mkCost 3 4 aluUnit #[rA] #[rB]

  -- Multiply 64-bit (3-reg)
  | 202 =>
    let dc := if dstOverlapsSrc rA #[rB, rD] then 1 else 2
    mkCost 3 dc mulUnit #[rA] #[rB, rD]
  -- mul_imm_64
  | 150 =>
    let dc := if dstOverlapsSrc rA #[rB] then 1 else 2
    mkCost 3 dc mulUnit #[rA] #[rB]

  -- Multiply 32-bit (3-reg)
  | 192 =>
    let dc := if dstOverlapsSrc rA #[rB, rD] then 2 else 3
    mkCost 4 dc mulUnit #[rA] #[rB, rD]
  -- mul_imm_32
  | 135 =>
    let dc := if dstOverlapsSrc rA #[rB] then 2 else 3
    mkCost 4 dc mulUnit #[rA] #[rB]

  -- Multiply upper
  | 213 | 214 =>
    mkCost 4 4 mulUnit #[rA] #[rB, rD]
  | 215 =>
    mkCost 6 4 mulUnit #[rA] #[rB, rD]

  -- Divide (all)
  | 193 | 194 | 195 | 196 | 203 | 204 | 205 | 206 =>
    mkCost 60 4 divUnit #[rA] #[rB, rD]

  -- Unknown/invalid opcode: default cost
  | _ => mkCost 1 1 {} #[] #[]

-- ============================================================================
-- Simulation helpers
-- ============================================================================

/-- Find the next instruction PC by scanning the bitmask. -/
def nextInstrPC (bitmask : ByteArray) (pc : Nat) : Option Nat :=
  let skip := skipDistance bitmask pc
  let npc := pc + 1 + skip
  if npc < bitmask.size then some npc else none

/-- Check if all dependencies of a ROB entry are finished. -/
def allDepsFinished (rob : Array RobEntry) (entry : RobEntry) : Bool :=
  entry.deps.all fun idx =>
    if h : idx < rob.size then rob[idx].state == .fin else true

/-- Can we decode the next instruction? -/
def canDecode (s : GasSimState) : Bool :=
  s.ι.isSome && s.remainingDecodeSlots > 0 && s.rob.size < 32

/-- Decode the next instruction and update state. -/
def decodeInstr (code bitmask : ByteArray) (s : GasSimState) : GasSimState :=
  match s.ι with
  | none => s
  | some pc =>
    let cost := instructionCost code bitmask pc
    -- Compute dependencies: ROB entries whose destRegs overlap with our srcRegs
    let deps := Id.run do
      let mut result : Array Nat := #[]
      for i in [:s.rob.size] do
        let entry := s.rob[i]!
        if entry.state != .fin && entry.destRegs.any (fun dr => cost.srcRegs.any (· == dr)) then
          result := result.push i
      return result
    let remainDec := s.remainingDecodeSlots - cost.decodeSlots
    let nextι := if cost.isTerminator then none
                 else nextInstrPC bitmask pc
    if cost.isMoveReg then
      -- move_reg: handled in frontend, no ROB entry
      { s with ι := nextι, remainingDecodeSlots := remainDec }
    else
      let entry : RobEntry := {
        state := .wait
        cyclesLeft := cost.cycles
        deps := deps
        destRegs := cost.destRegs
        execUnits := cost.execUnits
      }
      { s with
        ι := nextι
        remainingDecodeSlots := remainDec
        rob := s.rob.push entry }

/-- Find index of oldest WAIT entry that is ready to dispatch. -/
def findReadyEntry (s : GasSimState) : Option Nat :=
  let rec go (i : Nat) (fuel : Nat) : Option Nat :=
    match fuel with
    | 0 => none
    | fuel' + 1 =>
      if i >= s.rob.size then none
      else
        let entry := s.rob[i]!
        if entry.state == .wait &&
           allDepsFinished s.rob entry &&
           s.remainingExecUnits.canSatisfy entry.execUnits
        then some i
        else go (i + 1) fuel'
  go 0 s.rob.size

/-- Can we dispatch an instruction? -/
def canDispatch (s : GasSimState) : Bool :=
  s.remainingStartSlots > 0 && (findReadyEntry s).isSome

/-- Dispatch the oldest ready instruction. -/
def dispatch (s : GasSimState) : GasSimState :=
  match findReadyEntry s with
  | none => s
  | some idx =>
    let entry := s.rob[idx]!
    let entry' := { entry with state := .exe }
    { s with
      rob := s.rob.set! idx entry'
      remainingStartSlots := s.remainingStartSlots - 1
      remainingExecUnits := s.remainingExecUnits.sub entry.execUnits }

/-- Check if ROB is all finished (or empty). -/
def robAllFinished (s : GasSimState) : Bool :=
  s.rob.all (·.state == .fin)

/-- Advance one cycle: increment counter, reset slots, tick EXE entries. -/
def advanceCycle (s : GasSimState) : GasSimState :=
  let rob' := s.rob.map fun entry =>
    match entry.state with
    | .exe =>
      if entry.cyclesLeft <= 1 then { entry with state := .fin, cyclesLeft := 0 }
      else { entry with cyclesLeft := entry.cyclesLeft - 1 }
    | _ => entry
  { s with
    cycles := s.cycles + 1
    remainingDecodeSlots := 4
    remainingStartSlots := 5
    remainingExecUnits := { alu := 4, load := 4, store := 4, mul := 1, div := 1 }
    rob := rob' }

-- ============================================================================
-- Main simulation loop
-- ============================================================================

/-- Pipeline simulation with fuel to ensure termination. -/
partial def gasSim (code bitmask : ByteArray) (s : GasSimState) (fuel : Nat := 100000) : GasSimState :=
  match fuel with
  | 0 => s
  | fuel' + 1 =>
    -- Priority 1: Decode next instruction
    if canDecode s then
      gasSim code bitmask (decodeInstr code bitmask s) fuel'
    -- Priority 2: Dispatch oldest ready instruction
    else if canDispatch s then
      gasSim code bitmask (dispatch s) fuel'
    -- Priority 3: Done (no more instructions, ROB all finished)
    else if s.ι.isNone && robAllFinished s then
      s
    -- Priority 4: Advance cycle
    else
      gasSim code bitmask (advanceCycle s) fuel'

-- ============================================================================
-- Top-level gas cost function
-- ============================================================================

/-- Compute gas cost for a basic block starting at `startPC`.
    Returns `max(cycles - 3, 1)`. -/
def gasCostForBlock (code bitmask : ByteArray) (startPC : Nat) : Nat :=
  let initState : GasSimState := {
    ι := some startPC
    cycles := 0
    remainingDecodeSlots := 4
    remainingStartSlots := 5
    remainingExecUnits := { alu := 4, load := 4, store := 4, mul := 1, div := 1 }
    rob := #[]
  }
  let finalState := gasSim code bitmask initState
  if finalState.cycles > 3 then finalState.cycles - 3 else 1

end Jar.PVM
