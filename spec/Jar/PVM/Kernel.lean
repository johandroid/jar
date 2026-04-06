import Jar.PVM
import Jar.PVM.Capability
import Jar.PVM.Interpreter

/-!
# PVM Capability Kernel

Execution engine for the jar1 capability model. Manages a pool of VMs,
dispatches ecalli/ecall through capability resolution, and handles
multi-VM CALL/REPLY/RESUME.

This replaces the flat `handleHostCall` path for jar1. gp072 continues
using the flat path unchanged.
-/

namespace Jar.PVM.Kernel

open Jar.PVM.Cap

-- ============================================================================
-- Core Types
-- ============================================================================

/-- Compiled code data associated with a CODE cap. -/
structure CodeCapData where
  /-- Unique identifier within invocation. -/
  id : Nat
  /-- PVM program blob (code bytes). -/
  program : PVM.ProgramBlob
  /-- Jump table for dynamic jumps. -/
  jumpTable : Array Nat
  /-- Basic block start bitmask. -/
  bitmask : ByteArray
  deriving Inhabited

/-- Backing store: flat byte array representing all physical pages. -/
structure BackingStore where
  /-- All pages concatenated. Page P starts at offset P * 4096. -/
  data : ByteArray
  /-- Total pages available. -/
  totalPages : Nat
  deriving Inhabited

/-- Kernel state: VM pool + call stack + backing store. -/
structure KernelState where
  /-- VM pool (max 65535). -/
  vms : Array VmInstance
  /-- Call stack for CALL/REPLY routing. -/
  callStack : Array CallFrame
  /-- Compiled CODE caps. -/
  codeCaps : Array CodeCapData
  /-- Currently executing VM index. -/
  activeVm : Nat
  /-- Shared UNTYPED cap (bump allocator). -/
  untyped : UntypedCap
  /-- Backing store for all physical pages. -/
  backing : BackingStore
  /-- Memory tier (gas cost per load/store cycle). -/
  memCycles : Nat
  deriving Inhabited

/-- Result of running the kernel. -/
inductive KernelResult where
  /-- Root VM halted normally. Contains φ\[7\] value. -/
  | halt (value : Nat) : KernelResult
  /-- Root VM panicked. -/
  | panic : KernelResult
  /-- Root VM ran out of gas. -/
  | outOfGas : KernelResult
  /-- Root VM page-faulted. -/
  | pageFault (addr : Nat) : KernelResult
  /-- Protocol cap invoked — host should handle and call resumeProtocolCall. -/
  | protocolCall (slot : Nat) : KernelResult

/-- Internal dispatch result. -/
inductive DispatchResult where
  /-- Continue executing active VM. -/
  | continue_ : DispatchResult
  /-- Protocol cap — exit to host. -/
  | protocolCall (slot : Nat) : DispatchResult
  /-- Root VM halted. -/
  | rootHalt (value : Nat) : DispatchResult
  /-- Root VM panicked. -/
  | rootPanic : DispatchResult
  /-- Root VM out of gas. -/
  | rootOutOfGas : DispatchResult
  /-- Root VM page fault. -/
  | rootPageFault (addr : Nat) : DispatchResult
  /-- Non-root VM fault (already handled, continue). -/
  | faultHandled : DispatchResult

-- ============================================================================
-- Constants
-- ============================================================================

/-- WHAT error code (2^64 - 2). -/
def RESULT_WHAT : UInt64 := UInt64.ofNat (2^64 - 2)

/-- Gas cost per ecalli/ecall. -/
def ecalliGas : Nat := 10

/-- Gas cost per page for RETYPE. -/
def gasPerPage : Nat := 1500

/-- CALL overhead gas. -/
def callOverhead : Nat := 10

/-- Page size in bytes. -/
def pageSize : Nat := 4096

-- ============================================================================
-- Backing Store Operations
-- ============================================================================

/-- Read bytes from backing store. -/
def BackingStore.read (bs : BackingStore) (pageOff : Nat) (byteOff : Nat) (len : Nat) : ByteArray :=
  let start := pageOff * pageSize + byteOff
  if start + len ≤ bs.data.size then
    bs.data.extract start (start + len)
  else
    ByteArray.mkEmpty 0

/-- Write bytes to backing store. -/
def BackingStore.write (bs : BackingStore) (pageOff : Nat) (byteOff : Nat) (data : ByteArray) : BackingStore :=
  let start := pageOff * pageSize + byteOff
  if start + data.size ≤ bs.data.size then
    let mut result := bs.data
    for i in [:data.size] do
      result := result.set! (start + i) data[i]!
    { bs with data := result }
  else bs

-- ============================================================================
-- Helper: Register Access
-- ============================================================================

def getReg (regs : PVM.Registers) (i : Nat) : UInt64 :=
  if i < regs.size then regs[i]! else 0

def setReg (regs : PVM.Registers) (i : Nat) (v : UInt64) : PVM.Registers :=
  if i < regs.size then regs.set! i v else regs

-- ============================================================================
-- Capability Indirection Resolution
-- ============================================================================

/-- Resolve a u32 cap reference with HANDLE-chain indirection.
    byte 0 = target slot, bytes 1-3 = HANDLE chain (0x00 = end).
    Returns (vm_index, cap_slot) or none if resolution fails. -/
def resolveCapRef (state : KernelState) (capRef : UInt32) : Option (Nat × Nat) :=
  let targetSlot := (capRef &&& 0xFF).toNat
  let ind0 := ((capRef >>> 8) &&& 0xFF).toNat
  let ind1 := ((capRef >>> 16) &&& 0xFF).toNat
  let ind2 := ((capRef >>> 24) &&& 0xFF).toNat
  let mut vmIdx := state.activeVm
  -- Walk chain: ind2, ind1, ind0 (high to low)
  for handleSlot in [ind2, ind1, ind0] do
    if handleSlot == 0 then
      continue
    if vmIdx >= state.vms.size then return none
    match state.vms[vmIdx]!.capTable.get handleSlot.toUInt8 with
    | some (.handle h) =>
      let targetVm := h.vmId
      if targetVm >= state.vms.size then return none
      let targetState := state.vms[targetVm]!.state
      if targetState == .running || targetState == .waitingForReply then return none
      vmIdx := targetVm
    | _ => return none
  some (vmIdx, targetSlot)
  where
    toUInt8 (n : Nat) : UInt8 := UInt8.ofNat n

-- ============================================================================
-- VM State Helpers
-- ============================================================================

/-- Update a VM in the pool. -/
def KernelState.updateVm (state : KernelState) (idx : Nat) (f : VmInstance → VmInstance) : KernelState :=
  if idx < state.vms.size then
    { state with vms := state.vms.set! idx (f state.vms[idx]!) }
  else state

/-- Get the active VM. -/
def KernelState.activeVmInst (state : KernelState) : VmInstance :=
  state.vms[state.activeVm]!

/-- Set active VM registers. -/
def KernelState.setActiveReg (state : KernelState) (i : Nat) (v : UInt64) : KernelState :=
  state.updateVm state.activeVm fun vm =>
    { vm with registers := setReg vm.registers i v }

/-- Get active VM register. -/
def KernelState.getActiveReg (state : KernelState) (i : Nat) : UInt64 :=
  getReg state.activeVmInst.registers i

-- ============================================================================
-- CALL VM (HANDLE/CALLABLE → run target VM)
-- ============================================================================

/-- CALL a VM: suspend caller, start target. -/
def handleCallVm (state : KernelState) (targetVmId : Nat) (maxGas : Option Nat) : KernelState × DispatchResult :=
  if targetVmId >= state.vms.size then
    (state.setActiveReg 7 RESULT_WHAT, .continue_)
  else if state.vms[targetVmId]!.state != .idle then
    -- Target not IDLE — reentrancy prevention
    (state.setActiveReg 7 RESULT_WHAT, .continue_)
  else
    let callerIdx := state.activeVm
    let callerVm := state.vms[callerIdx]!

    -- Gas transfer
    let callerGas := callerVm.gas
    if callerGas < callOverhead then
      (state, .rootOutOfGas)
    else
      let afterOverhead := callerGas - callOverhead
      let calleeGas := match maxGas with
        | some limit => min afterOverhead limit
        | none => afterOverhead
      let callerGasAfter := afterOverhead - calleeGas

      -- IPC cap: φ[12]. 0 = no cap.
      let ipcRef := (getReg callerVm.registers 12).toNat
      let ipcCapIdx := if ipcRef != 0 then some (UInt8.ofNat (ipcRef &&& 0xFF)) else none

      -- Caller → WaitingForReply
      let state := state.updateVm callerIdx fun vm =>
        { vm with state := .waitingForReply, gas := callerGasAfter }

      -- Handle IPC cap transfer
      let (state, ipcSlotSaved, ipcWasMapped) := match ipcCapIdx with
        | none => (state, none, none)
        | some slot =>
          let callerTable := state.vms[callerIdx]!.capTable
          let (newTable, cap) := callerTable.take slot.toNat.toUInt8
          let state := state.updateVm callerIdx fun vm => { vm with capTable := newTable }
          match cap with
          | some c =>
            -- Place in callee's IPC slot [0]
            let state := state.updateVm targetVmId fun vm =>
              { vm with capTable := vm.capTable.set 0 c }
            (state, some slot, none) -- TODO: track DATA mapping state for auto-remap
          | none => (state, none, none)
        where toUInt8 (n : Nat) : UInt8 := UInt8.ofNat n

      -- Push call frame
      let frame : CallFrame := {
        callerVmId := callerIdx
        ipcCapIdx := ipcSlotSaved.map UInt8.toNat
        ipcWasMapped := ipcWasMapped
      }
      let state := { state with callStack := state.callStack.push frame }

      -- Pass args: caller φ[7..10] → callee φ[7..10]
      let callerRegs := state.vms[callerIdx]!.registers
      let state := state.updateVm targetVmId fun vm =>
        { vm with
          gas := calleeGas
          caller := some callerIdx
          state := .running
          registers := setReg (setReg (setReg (setReg vm.registers
            7 (getReg callerRegs 7))
            8 (getReg callerRegs 8))
            9 (getReg callerRegs 9))
            10 (getReg callerRegs 10))
        }
      let state := { state with activeVm := targetVmId }
      (state, .continue_)

-- ============================================================================
-- REPLY (ecalli(0) = CALL on IPC slot)
-- ============================================================================

/-- REPLY: return to caller. -/
def handleReply (state : KernelState) : KernelState × DispatchResult :=
  match state.callStack.back? with
  | none =>
    -- No caller — root VM replying = halt
    let result := state.getActiveReg 7
    (state, .rootHalt result.toNat)
  | some frame =>
    let calleeIdx := state.activeVm
    let callerIdx := frame.callerVmId
    let state := { state with callStack := state.callStack.pop }

    -- Callee → Idle
    let state := state.updateVm calleeIdx fun vm =>
      { vm with state := .idle }

    -- Return unused gas to caller
    let unusedGas := state.vms[calleeIdx]!.gas
    let state := state.updateVm callerIdx fun vm =>
      { vm with gas := vm.gas + unusedGas }
    let state := state.updateVm calleeIdx fun vm =>
      { vm with gas := 0 }

    -- Return IPC cap
    if let some callerSlot := frame.ipcCapIdx then
      let (calleeTable, cap) := state.vms[calleeIdx]!.capTable.take 0
      let state := state.updateVm calleeIdx fun vm => { vm with capTable := calleeTable }
      match cap with
      | some c =>
        let state := state.updateVm callerIdx fun vm =>
          { vm with capTable := vm.capTable.set (UInt8.ofNat callerSlot) c }
        -- Pass results: callee φ[7..8] → caller φ[7..8]
        let calleeRegs := state.vms[calleeIdx]!.registers
        let state := state.updateVm callerIdx fun vm =>
          { vm with
            state := .running
            registers := setReg (setReg vm.registers
              7 (getReg calleeRegs 7))
              8 (getReg calleeRegs 8))
          }
        ({ state with activeVm := callerIdx }, .continue_)
      | none =>
        -- No cap to return
        let calleeRegs := state.vms[calleeIdx]!.registers
        let state := state.updateVm callerIdx fun vm =>
          { vm with
            state := .running
            registers := setReg (setReg vm.registers
              7 (getReg calleeRegs 7))
              8 (getReg calleeRegs 8))
          }
        ({ state with activeVm := callerIdx }, .continue_)
    else
      -- No IPC cap was passed
      let calleeRegs := state.vms[calleeIdx]!.registers
      let state := state.updateVm callerIdx fun vm =>
        { vm with
          state := .running
          registers := setReg (setReg vm.registers
            7 (getReg calleeRegs 7))
            8 (getReg calleeRegs 8))
        }
      ({ state with activeVm := callerIdx }, .continue_)

-- ============================================================================
-- ecalli Dispatch (CALL a cap)
-- ============================================================================

/-- Dispatch an ecalli instruction. Resolves the cap and dispatches by type. -/
def dispatchEcalli (state : KernelState) (imm : UInt32) : KernelState × DispatchResult :=
  -- Charge ecalli gas
  let currentGas := state.activeVmInst.gas
  if currentGas < ecalliGas then
    (state, .rootOutOfGas)
  else
    let state := state.updateVm state.activeVm fun vm =>
      { vm with gas := vm.gas - ecalliGas }

    -- IPC slot (0) = REPLY
    if imm.toNat == ipcSlot then
      handleReply state
    else
      -- Resolve cap reference with indirection
      match resolveCapRef state imm with
      | none =>
        (state.setActiveReg 7 RESULT_WHAT, .continue_)
      | some (vmIdx, slot) =>
        match state.vms[vmIdx]!.capTable.get (UInt8.ofNat slot) with
        | some (.protocol p) =>
          (state, .protocolCall p.id)
        | some (.handle h) =>
          handleCallVm state h.vmId h.maxGas
        | some (.callable c) =>
          handleCallVm state c.vmId c.maxGas
        | some (.untyped _) =>
          -- RETYPE: TODO (PR B)
          (state.setActiveReg 7 RESULT_WHAT, .continue_)
        | some (.code _) =>
          -- CREATE: TODO (PR B)
          (state.setActiveReg 7 RESULT_WHAT, .continue_)
        | some (.data _) =>
          -- CALL(DATA) = memcpy: TODO (PR C)
          (state.setActiveReg 7 RESULT_WHAT, .continue_)
        | none =>
          (state.setActiveReg 7 RESULT_WHAT, .continue_)

-- ============================================================================
-- VM Halt/Fault Handling
-- ============================================================================

/-- Handle a non-root VM halt: pop call frame, resume caller with result. -/
def handleVmHalt (state : KernelState) (exitValue : Nat) : KernelState × DispatchResult :=
  match state.callStack.back? with
  | none => (state, .rootHalt exitValue)
  | some frame =>
    let calleeIdx := state.activeVm
    let callerIdx := frame.callerVmId
    let state := { state with callStack := state.callStack.pop }
    -- Callee → Halted (terminal)
    let state := state.updateVm calleeIdx fun vm =>
      { vm with state := .halted }
    -- Return unused gas
    let unusedGas := state.vms[calleeIdx]!.gas
    let state := state.updateVm callerIdx fun vm =>
      { vm with gas := vm.gas + unusedGas }
    -- Resume caller with result
    let state := state.updateVm callerIdx fun vm =>
      { vm with
        state := .running
        registers := setReg vm.registers 7 (UInt64.ofNat exitValue) }
    ({ state with activeVm := callerIdx }, .continue_)

/-- Handle a non-root VM fault: pop call frame, resume caller, report error. -/
def handleVmFault (state : KernelState) : KernelState × DispatchResult :=
  match state.callStack.back? with
  | none => (state, .rootPanic)
  | some frame =>
    let calleeIdx := state.activeVm
    let callerIdx := frame.callerVmId
    let state := { state with callStack := state.callStack.pop }
    -- Callee → Faulted (non-terminal, can be RESUMEd)
    let state := state.updateVm calleeIdx fun vm =>
      { vm with state := .faulted }
    -- Return unused gas
    let unusedGas := state.vms[calleeIdx]!.gas
    let state := state.updateVm callerIdx fun vm =>
      { vm with gas := vm.gas + unusedGas }
    -- Resume caller with WHAT
    let state := state.updateVm callerIdx fun vm =>
      { vm with
        state := .running
        registers := setReg vm.registers 7 RESULT_WHAT }
    ({ state with activeVm := callerIdx }, .continue_)

-- ============================================================================
-- Main Kernel Loop
-- ============================================================================

/-- Run the kernel until it needs host interaction or terminates. -/
partial def runKernel (state : KernelState) : KernelState × KernelResult :=
  let vm := state.activeVmInst
  if vm.gas == 0 then
    (state, .outOfGas)
  else
    let codeCapId := vm.codeCapId
    if codeCapId >= state.codeCaps.size then
      (state, .panic)
    else
      let codeCap : CodeCapData := state.codeCaps[codeCapId]!
      -- Run one PVM segment
      let result := PVM.run codeCap.program vm.pc vm.registers vm.memory
        (Int64.ofUInt64 (UInt64.ofNat vm.gas))
      -- Sync VM state from PVM result
      let state := state.updateVm state.activeVm fun v =>
        { v with
          registers := result.registers
          gas := result.gas.toUInt64.toNat
          pc := result.nextPC }
      match result.exitReason with
      | .hostCall imm =>
        let (state', dr) := dispatchEcalli state imm.toUInt32
        match dr with
        | .continue_ => runKernel state'
        | .protocolCall slot => (state', .protocolCall slot)
        | .rootHalt v => (state', .halt v)
        | .rootPanic => (state', .panic)
        | .rootOutOfGas => (state', .outOfGas)
        | .rootPageFault a => (state', .pageFault a)
        | .faultHandled => runKernel state'
      | .halt =>
        let exitValue := (getReg result.registers 7).toNat
        let (state', dr) := handleVmHalt state exitValue
        match dr with
        | .rootHalt v => (state', .halt v)
        | .continue_ => runKernel state'
        | _ => (state', .panic)
      | .panic =>
        let (state', dr) := handleVmFault state
        match dr with
        | .rootPanic => (state', .panic)
        | .continue_ => runKernel state'
        | _ => (state', .panic)
      | .outOfGas =>
        let (state', dr) := handleVmFault state
        match dr with
        | .rootPanic => (state', .outOfGas) -- root OOG
        | .continue_ => runKernel state'
        | _ => (state', .outOfGas)
      | .pageFault addr =>
        let (state', dr) := handleVmFault state
        match dr with
        | .rootPanic => (state', .pageFault addr)
        | .continue_ => runKernel state'
        | _ => (state', .pageFault addr)
      | _ => (state, .panic)

-- ============================================================================
-- Protocol Call Resume
-- ============================================================================

/-- Resume kernel after host handled a protocol call. -/
def resumeProtocolCall (state : KernelState) (result0 : UInt64) (result1 : UInt64) : KernelState :=
  state.updateVm state.activeVm fun vm =>
    { vm with registers := setReg (setReg vm.registers 7 result0) 8 result1 }

end Jar.PVM.Kernel
