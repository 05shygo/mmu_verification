// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_txn.svh
// Phase 5 (Engineer A): Miscellaneous signal transaction class
//
// Covers four subgroups of the misc_if:
//   RTU   — rtu_yy_xx_flush (single-cycle pipeline flush)
//           rtu_mmu_expt_vld + rtu_mmu_bad_vpn (exception injection)
//   HPCP  — hpcp_mmu_cnt_en (performance counter enable, level signal)
//   DFT   — pad_yy_icg_scan_en (scan enable, default 0 in sim)
//           biu_mmu_smp_disable (SMP disable, static configuration)
//   MON   — read-back of mmu_hpcp_*_miss, mmu_had_debug_info (monitor only)
// =============================================================================
`ifndef MISC_TXN_SVH
`define MISC_TXN_SVH

// Misc operation enumeration
typedef enum bit [2:0] {
  MISC_RTU_FLUSH    = 3'd0,  // Assert rtu_yy_xx_flush for one cycle (single pulse)
  MISC_RTU_EXPT     = 3'd1,  // Assert rtu_mmu_expt_vld + bad_vpn for one cycle
  MISC_SMP_DISABLE  = 3'd2,  // Set biu_mmu_smp_disable level (static config)
  MISC_HPCP_CNT_EN  = 3'd3,  // Set hpcp_mmu_cnt_en level
  MISC_DFT_SCAN_EN  = 3'd4,  // Set pad_yy_icg_scan_en (normally 0 in sim)
  MISC_IDLE         = 3'd5   // No-op: advance one cycle without any drive change
} misc_op_e;

class misc_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(misc_txn)
    `uvm_field_enum(misc_op_e, op,           UVM_ALL_ON)
    `uvm_field_int(flush_pulse,              UVM_ALL_ON)
    `uvm_field_int(expt_vld,                 UVM_ALL_ON)
    `uvm_field_int(bad_vpn,                  UVM_ALL_ON)
    `uvm_field_int(smp_disable,              UVM_ALL_ON)
    `uvm_field_int(hpcp_cnt_en,              UVM_ALL_ON)
    `uvm_field_int(dft_scan_en,              UVM_ALL_ON)
    `uvm_field_int(dutlb_miss,               UVM_ALL_ON)
    `uvm_field_int(iutlb_miss,               UVM_ALL_ON)
    `uvm_field_int(jtlb_miss,               UVM_ALL_ON)
    `uvm_field_int(had_debug_info,           UVM_ALL_ON)
  `uvm_object_utils_end

  // ── Stimulus fields (driven by misc_driver) ─────────────────────────────
  rand misc_op_e  op;

  // MISC_RTU_FLUSH: drives rtu_yy_xx_flush for one clock cycle
  rand bit        flush_pulse;  // always 1 for MISC_RTU_FLUSH (constrainted)

  // MISC_RTU_EXPT: exception injection
  rand bit        expt_vld;
  rand bit [26:0] bad_vpn;

  // MISC_SMP_DISABLE: static level
  rand bit        smp_disable;

  // MISC_HPCP_CNT_EN: performance counter enable level
  rand bit        hpcp_cnt_en;

  // MISC_DFT_SCAN_EN: DFT scan enable (tie 0 in normal simulation)
  rand bit        dft_scan_en;

  // ── Response / monitor fields (sampled by misc_monitor) ─────────────────
  // Filled by monitor when publishing ap_hpcp transactions
  bit             dutlb_miss;   // mmu_hpcp_dutlb_miss sampled value
  bit             iutlb_miss;   // mmu_hpcp_iutlb_miss sampled value
  bit             jtlb_miss;    // mmu_hpcp_jtlb_miss sampled value

  // Filled by monitor when publishing ap_debug transactions
  bit [33:0]      had_debug_info;

  // ── Default constraints ──────────────────────────────────────────────────
  // DFT scan enable must be 0 in normal simulation
  constraint c_dft_off     { dft_scan_en == 1'b0; }
  // SMP disable defaults to 0 (no bus attribute override)
  constraint c_smp_default { smp_disable == 1'b0; }
  // HPCP counter enable defaults to 1 (enable performance counting)
  constraint c_hpcp_en     { hpcp_cnt_en == 1'b1; }
  // Flush pulse is always asserted for MISC_RTU_FLUSH
  constraint c_flush_pulse { flush_pulse == 1'b1; }

  function new(string name = "misc_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "op=%-16s flush=%0b expt_vld=%0b bad_vpn=0x%07h smp_dis=%0b hpcp_en=%0b | dutlb=%0b iutlb=%0b jtlb=%0b",
      op.name(), flush_pulse, expt_vld, bad_vpn, smp_disable, hpcp_cnt_en,
      dutlb_miss, iutlb_miss, jtlb_miss);
  endfunction

endclass : misc_txn

`endif // MISC_TXN_SVH
