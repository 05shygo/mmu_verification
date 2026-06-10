// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_txn.svh
// Phase 3 (Engineer B): IFU transaction class
// Represents one IFU→MMU virtual address translation request + response.
// =============================================================================
`ifndef IFU_TXN_SVH
`define IFU_TXN_SVH

class ifu_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(ifu_txn)
    `uvm_field_int(va,          UVM_ALL_ON)
    `uvm_field_int(abort,       UVM_ALL_ON)
    `uvm_field_int(idle_cycles, UVM_ALL_ON)
    `uvm_field_int(pa,          UVM_ALL_ON)
    `uvm_field_int(pavld,       UVM_ALL_ON)
    `uvm_field_int(pgflt,       UVM_ALL_ON)
    `uvm_field_int(deny,        UVM_ALL_ON)
    `uvm_field_int(sec,         UVM_ALL_ON)
    `uvm_field_int(ca,          UVM_ALL_ON)
    `uvm_field_int(buf_bit,     UVM_ALL_ON)
    `uvm_field_int(dbg_iutlb_acc_flt, UVM_ALL_ON)
    `uvm_field_int(dbg_iutlb_pmp_deny, UVM_ALL_ON)
    `uvm_field_int(dbg_iutlb_ref_pgflt, UVM_ALL_ON)
    `uvm_field_int(dbg_jtlb_acc_fault_flop, UVM_ALL_ON)
    `uvm_field_int(credit_counted, UVM_ALL_ON)
  `uvm_object_utils_end

  // ── Stimulus fields (driven by ifu_driver) ──────────────────────────────
  rand bit [62:0] va;           // Virtual address (Sv39 canonical, bit63 implied)
  rand bit        abort;        // Pipeline abort signal
  rand int        idle_cycles;  // Idle cycles before asserting request

  // ── Response fields (monitor fill-back) ─────────────────────────────────
  bit [27:0] pa;      // Physical address PPN (28-bit, PA=40 → PPN=PA-12)
  bit        pavld;   // PA valid (translation done)
  bit        pgflt;   // Page fault
  bit        deny;    // Access denied (PMP / sysmap)
  bit        sec;     // Secure attribute
  bit        ca;      // Cacheable attribute
  bit        buf_bit; // Bufferable attribute
  bit        dbg_iutlb_acc_flt; // Whitebox: IFU response completed on PTW acc_err
  bit        dbg_iutlb_pmp_deny; // Whitebox: IFU deny came from PMP check term
  bit        dbg_iutlb_ref_pgflt; // Whitebox: IFU pgflt came from refill-state PGFLT completion
  bit        dbg_jtlb_acc_fault_flop; // Whitebox: IFU deny came from jtlb_acc_fault_flop
  bit        credit_counted; // Monitor-side conservation bookkeeping marker

  // ── Constraints ──────────────────────────────────────────────────────────
  // Sv39 canonical VA: bits[62:39] must all equal bit[38] (sign extension)
  constraint c_sv39_canonical {
    va[62:39] == {24{va[38]}};
  }
  // Default: no abort (abort scenario covered by ifu_abort_seq)
  constraint c_no_abort { abort == 1'b0; }
  // Reasonable inter-request gap
  constraint c_idle { idle_cycles inside {[0:10]}; }

  function new(string name = "ifu_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "va=0x%016h abort=%0b idle=%0d credit_counted=%0b | pa=0x%07h pavld=%0b pgflt=%0b deny=%0b sec=%0b ca=%0b dbg_accerr=%0b dbg_pmp_deny=%0b dbg_ref_pgflt=%0b dbg_jtlb_acc_fault_flop=%0b",
      {1'b0, va}, abort, idle_cycles, pa, pavld, pgflt, deny, sec, ca,
      credit_counted, dbg_iutlb_acc_flt, dbg_iutlb_pmp_deny,
      dbg_iutlb_ref_pgflt, dbg_jtlb_acc_fault_flop);
  endfunction

endclass : ifu_txn

`endif // IFU_TXN_SVH
