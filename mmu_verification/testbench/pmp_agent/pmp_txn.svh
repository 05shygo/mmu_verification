// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_txn.svh
// Phase 3: PMP responder transaction class
// Models the 8-port flag configuration driven into the DUT, and the 8 PA
// outputs / 4 fetch-enable outputs sampled from the DUT.
// =============================================================================
`ifndef PMP_TXN_SVH
`define PMP_TXN_SVH

class pmp_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(pmp_txn)
    `uvm_field_sarray_int(flg,      UVM_ALL_ON)
    `uvm_field_sarray_int(pa,       UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_sarray_int(fetch_en, UVM_ALL_ON | UVM_NOCOMPARE)
  `uvm_object_utils_end

  // ── Stimulus fields (driven by pmp_driver) ───────────────────────────────
  // flg[3:0] per port: {execute_deny, write_deny, read_deny, valid}
  // (exact encoding TBD per PMP implementation; drive all-allow by default)
  rand bit [3:0] flg [8];   // 8 ports × 4-bit flag

  // ── Response / observe fields (sampled by pmp_monitor) ───────────────────
  bit [27:0] pa       [8];  // mmu_pmp_pa{0..7}
  bit        fetch_en [4];  // mmu_pmp_fetch{3,5,6,7} → index 0..3

  // Default: all-allow (flag=0 = no deny)
  constraint c_all_allow { foreach (flg[i]) flg[i] == 4'h0; }

  function new(string name = "pmp_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s;
    s = "PMP flg=[";
    foreach (flg[i]) s = {s, $sformatf("%0h", flg[i]), (i<7) ? "," : "]"};
    return s;
  endfunction

endclass : pmp_txn

`endif // PMP_TXN_SVH
