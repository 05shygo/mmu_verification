// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_txn.svh
// Phase 3 (Engineer B): LSU transaction class
// Covers all 5 sub-channels: pipe0 / pipe1 / pipe2(prefetch) / stamo / inv
// =============================================================================
`ifndef LSU_TXN_SVH
`define LSU_TXN_SVH

// Which LSU sub-channel this transaction targets
typedef enum bit [2:0] {
  LSU_PIPE0 = 3'd0,  // Load/Store pipe 0
  LSU_PIPE1 = 3'd1,  // Load/Store pipe 1
  LSU_PIPE2 = 3'd2,  // Prefetch pipe 2
  LSU_STAMO = 3'd3,  // Store-Atomic physical address check
  LSU_INV   = 3'd4   // TLB Invalidation (SFENCE.VMA)
} lsu_kind_e;

// SFENCE.VMA invalidation mode
typedef enum bit [1:0] {
  INV_ALL        = 2'd0,  // SFENCE.VMA x0, x0  (all VA, all ASID)
  INV_VA_ALL     = 2'd1,  // SFENCE.VMA rs1, x0 (specific VA, all ASID)
  INV_ASID_ALL   = 2'd2,  // SFENCE.VMA x0, rs2 (all VA, specific ASID)
  INV_VA_ASID    = 2'd3   // SFENCE.VMA rs1, rs2 (specific VA, specific ASID)
} lsu_inv_kind_e;

class lsu_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(lsu_txn)
    `uvm_field_enum(lsu_kind_e,     kind,       UVM_ALL_ON)
    `uvm_field_int(va,               UVM_ALL_ON)
    `uvm_field_int(id,               UVM_ALL_ON)
    `uvm_field_int(st_inst,          UVM_ALL_ON)
    `uvm_field_int(abort,            UVM_ALL_ON)
    `uvm_field_int(vabuf,            UVM_ALL_ON)
    `uvm_field_int(va2,              UVM_ALL_ON)
    `uvm_field_int(stamo_pa,         UVM_ALL_ON)
    `uvm_field_enum(lsu_inv_kind_e, inv_kind,   UVM_ALL_ON)
    `uvm_field_int(inv_va,           UVM_ALL_ON)
    `uvm_field_int(inv_asid,         UVM_ALL_ON)
    `uvm_field_int(idle_cycles,      UVM_ALL_ON)
    `uvm_field_int(pa,               UVM_ALL_ON)
    `uvm_field_int(pgflt,            UVM_ALL_ON)
    `uvm_field_int(access_fault,     UVM_ALL_ON)
    `uvm_field_int(stall,            UVM_ALL_ON)
    `uvm_field_int(sec,              UVM_ALL_ON)
    `uvm_field_int(inv_done,         UVM_ALL_ON)
  `uvm_object_utils_end

  // ── Sub-channel selector ─────────────────────────────────────────────────
  rand lsu_kind_e kind;

  // ── Pipe 0 / Pipe 1 stimulus fields ─────────────────────────────────────
  rand bit [63:0] va;       // 64-bit virtual address (Sv39 canonical)
  rand bit [6:0]  id;       // LSIQ entry ID (7-bit)
  rand bit        st_inst;  // 1=store, 0=load
  rand bit        abort;    // Pipeline abort
  rand bit [27:0] vabuf;    // VA buffer for stall-replay

  // ── Pipe 2 (Prefetch) stimulus ───────────────────────────────────────────
  rand bit [27:0] va2;      // Prefetch VA (28-bit, bits[39:12] of full VA)

  // ── STAMO stimulus ────────────────────────────────────────────────────────
  rand bit [27:0] stamo_pa; // Physical address to check (PPN, 28-bit)

  // ── TLB Invalidation stimulus ─────────────────────────────────────────────
  rand lsu_inv_kind_e inv_kind;
  rand bit [26:0] inv_va;   // SFENCE.VMA VA operand (bits[38:12])
  rand bit [15:0] inv_asid; // SFENCE.VMA ASID operand

  // ── Timing ────────────────────────────────────────────────────────────────
  rand int idle_cycles;

  // ── Response fields (monitor fill-back) ─────────────────────────────────
  bit [27:0] pa;          // Translated PPN
  bit        pgflt;       // Page fault
  bit        access_fault;// Access fault (PMP deny)
  bit        stall;       // MMU stall (TLB miss)
  bit        sec;         // Secure attribute
  bit        inv_done;    // TLB invalidation done (inv sub-channel)

  // ── Constraints ──────────────────────────────────────────────────────────
  // Sv39 canonical VA (pipe0/1): bits[63:39] == {25{va[38]}}
  constraint c_sv39_canonical {
    va[63:39] == {25{va[38]}};
  }
  constraint c_no_abort { abort == 1'b0; }
  constraint c_idle     { idle_cycles inside {[0:8]}; }
  // Default kind: pipe0
  constraint c_kind_default { kind == LSU_PIPE0; }

  function new(string name = "lsu_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    case (kind)
      LSU_PIPE0, LSU_PIPE1:
        return $sformatf(
          "kind=%s va=0x%016h id=%0d st=%0b abort=%0b | pa=0x%07h pgflt=%0b stall=%0b",
          kind.name(), va, id, st_inst, abort, pa, pgflt, stall);
      LSU_PIPE2:
        return $sformatf("kind=PIPE2 va2=0x%07h", va2);
      LSU_STAMO:
        return $sformatf("kind=STAMO stamo_pa=0x%07h", stamo_pa);
      LSU_INV:
        return $sformatf(
          "kind=INV inv_kind=%s va=0x%07h asid=0x%04h | inv_done=%0b",
          inv_kind.name(), inv_va, inv_asid, inv_done);
      default:
        return $sformatf("kind=%s (unknown)", kind.name());
    endcase
  endfunction

endclass : lsu_txn

`endif // LSU_TXN_SVH
