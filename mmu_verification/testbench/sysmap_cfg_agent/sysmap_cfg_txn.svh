// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_txn.svh
// Phase 3: SysMap configuration transaction
// ct_mmu_sysmap.v has no top-level ports and is macro-configured in the
// current build.  This transaction is a UVM mirror item only until the
// sysmap_cfg_driver whitebox force paths are implemented.
// =============================================================================
`ifndef SYSMAP_CFG_TXN_SVH
`define SYSMAP_CFG_TXN_SVH

class sysmap_cfg_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(sysmap_cfg_txn)
    `uvm_field_sarray_int(base,   UVM_ALL_ON)
    `uvm_field_sarray_int(mask,   UVM_ALL_ON)
    `uvm_field_sarray_int(flg,    UVM_ALL_ON)
    `uvm_field_sarray_int(enable, UVM_ALL_ON)
  `uvm_object_utils_end

  // 8 SysMap regions (UVM mirror; not currently forced into ct_mmu_sysmap.v)
  rand bit [27:0] base   [8];   // Region base physical address  (28-bit PPN)
  rand bit [27:0] mask   [8];   // Region address mask
  rand bit [4:0]  flg    [8];   // 5-bit attribute flags
  rand bit        enable [8];   // Region enable

  // Default: all regions disabled, full-mask (bypass everything)
  constraint c_default_disabled {
    foreach (enable[i]) enable[i] == 1'b0;
  }

  function new(string name = "sysmap_cfg_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s;
    s = "SysMap[";
    foreach (enable[i])
      s = {s, $sformatf("R%0d:%0b", i, enable[i]), (i<7) ? "," : "]"};
    return s;
  endfunction

endclass : sysmap_cfg_txn

`endif // SYSMAP_CFG_TXN_SVH
