`ifndef MMU_L1DTLB_COVERAGE_VSEQ_SVH
`define MMU_L1DTLB_COVERAGE_VSEQ_SVH

class mmu_l1dtlb_entry0_wfg_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_entry0_wfg_vseq)
  function new(string n = "mmu_l1dtlb_entry0_wfg_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== entry0_wfg_vseq body START =====", UVM_NONE)
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    do_bringup(512, 39'h10_0000);

    `uvm_info(get_type_name(), "阶段1: 持续双端口miss压力", UVM_LOW)
    configure_ptw_delay(64, 128);

    for (int round = 0; round < 64; round++) begin
      raw_pipe01(va_page(round*2), va_page(round*2+1),
                 7'(round[6:0]*2), 7'(round[6:0]*2+1),
                 round[0], ~round[0]);
      wait_lsu_cycles(1);

      if (round % 8 == 7) begin
        raw_rtu_flush();
        wait_lsu_cycles(4);
      end
    end
    #30000ns;

    `uvm_info(get_type_name(), "阶段2: 长PTW + 持续双端口", UVM_LOW)
    configure_ptw_delay(512, 1024);

    for (int round = 0; round < 32; round++) begin
      raw_pipe01(va_page(128 + round*2), va_page(129 + round*2),
                 7'(round[6:0]*2+1), 7'(round[6:0]*2+2),
                 round[0], ~round[0]);
      wait_lsu_cycles(1);

      if (round % 6 == 5) begin
        raw_rtu_flush();
        wait_lsu_cycles(3);
      end
    end
    #50000ns;

    `uvm_info(get_type_name(), "阶段3: 短PTW + 高频flush", UVM_LOW)
    configure_ptw_delay(16, 32);

    for (int round = 0; round < 48; round++) begin
      raw_pipe01(va_page(256 + round*2), va_page(257 + round*2),
                 7'(round[6:0]+10), 7'(round[6:0]+20),
                 1'b0, round[0]);
      wait_lsu_cycles(1);

      if (round % 4 == 3) begin
        raw_rtu_flush();
        wait_lsu_cycles(2);
      end
    end
    #20000ns;

    `uvm_info(get_type_name(), "阶段4: store类型miss", UVM_LOW)
    configure_ptw_delay(128, 256);

    for (int round = 0; round < 24; round++) begin
      raw_pipe01(va_page(384 + round*2), va_page(385 + round*2),
                 7'(round[6:0]+30), 7'(round[6:0]+40),
                 1'b1, round[0]);
      wait_lsu_cycles(1);

      if (round % 3 == 2) begin
        raw_rtu_flush();
        wait_lsu_cycles(2);
      end
    end
    #30000ns;

    configure_ptw_delay(1, 4);
    #100000ns;

    `uvm_info(get_type_name(), "entry[0] WFG覆盖率序列完成", UVM_LOW)
  endtask
endclass


class mmu_l1dtlb_coverage_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_coverage_vseq)
  function new(string n = "mmu_l1dtlb_coverage_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int i = 0; i < 72; i++) begin raw_pipe0(va_page(i), 7'(i[6:0]), 1'b0); #50ns; end
    #30000ns;
    for (int i = 0; i < 32; i++) begin raw_pipe01(va_page(i*2), va_page(i*2+1), 7'(i[6:0]), 7'(i[6:0]+32), 1'b0, 1'b0); #100ns; end
    #30000ns;
    for (int cycle = 0; cycle < 4; cycle++) begin
      for (int i = 0; i < 8; i++) begin raw_pipe0(va_page(cycle*8+i+80), 7'd10, 1'b0); #50ns; end
      #5000ns; raw_rtu_flush(); #2000ns;
      for (int i = 0; i < 8; i++) begin raw_pipe0(va_page(cycle*8+i+80), 7'd20, 1'b0); #50ns; end
      #5000ns;
    end
  endtask
endclass

class mmu_l1dtlb_mb_expt_coverage_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_mb_expt_coverage_vseq)
  function new(string n = "mmu_l1dtlb_mb_expt_coverage_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int cycle = 0; cycle < 4; cycle++) begin
      for (int i = 0; i < 8; i++) begin raw_pipe0(va_page(cycle*8+i+256), 7'(i[6:0]), 1'b0); wait_lsu_cycles(1); end
      #40000ns;
    end
    for (int cycle = 0; cycle < 4; cycle++) begin
      for (int i = 0; i < 4; i++) begin raw_pipe0(va_page(cycle*4+i+300), 7'(i[6:0]), 1'b0); wait_lsu_cycles(1); end
      #2000ns; raw_rtu_flush(); #5000ns;
    end
    for (int cycle = 0; cycle < 4; cycle++) begin
      raw_pipe01(va_page(cycle*2+320), va_page(cycle*2+321), 7'd30, 7'd31, 1'b0, 1'b0);
      #3000ns; raw_rtu_flush(); #2000ns;
      raw_pipe0(va_page(cycle*2+320), 7'd40, 1'b0); #5000ns;
    end
  endtask
endclass

class mmu_l1_reset_mid_op_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1_reset_mid_op_vseq)
  function new(string n = "mmu_l1_reset_mid_op_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int cycle = 0; cycle < 3; cycle++) begin
      configure_ptw_delay(512, 512);
      for (int i = 0; i < 4; i++) begin raw_pipe0(va_page(cycle*4+i+500), 7'(i[6:0]), 1'b0); wait_lsu_cycles(1); end
      #3000ns; raw_rtu_flush(); #1000ns;
      for (int i = 0; i < 4; i++) begin raw_pipe0(va_page(cycle*4+i+500), 7'(7'd50+i[6:0]), 1'b0); #100ns; end
      #10000ns;
    end
  endtask
endclass

// =============================================================================
// TASK L1DTLB-T01 — entry 0..15 sweep + va8 invalidate (STUB — needs rework)
//
// Status: NOT YET COVERED.  Repeated attempts showed that bulk-installing 16
// unique VPNs into the DTLB only lands 1–2 entries (probe shows entry[0]
// holding the most-recent refill's VPN, with all other entries invalid).
// The DUT's PLRU + MB + L2TLB set pressure combination appears to prevent
// 16 simultaneous DTLB entries from accumulating under any cadence tested
// (raw_pipe0 with 1/4/8/48 cycle gaps; send_lsu_item via fill_page; mixed).
// The existing baseline tests similarly only cover entry[0] (5–40 hits)
// and entry[1] (20 hits in phase14_merged) via single-fill+inv patterns;
// entries 2..15 remain at 0 hits in baseline.
//
// Root cause hypothesis (needs design team confirmation):
//   The install path (mmu_l1dtlb_install.sv) seems to allow a fresh refill
//   to overwrite an already-valid entry when the PLRU tree hasn't yet
//   settled from the previous refill.  Each new raw_pipe0 miss may be
//   re-targeting entry[0] because the PLRU victim pointer only advances
//   after utlb_refill_vld asserts, and under back-to-back pressure the
//   pointer doesn't advance fast enough.
//
// This vseq is left as a structural placeholder so the test wrapper and
// vseq-name registration remain in place; the body is a no-op sweep that
// at least exercises the PTW path and may contribute to entry[0] coverage
// redundant with baseline.  A proper fix requires either:
//   (a) Inserting explicit probe-triggered wait BETWEEN installs that
//       confirms the previously-installed entry is still valid before
//       issuing the next miss, AND issuing the inv_va BEFORE the next
//       install (so the slot is freed deterministically), or
//   (b) Using the L2TLB invalidate path which may have different
//       accumulation semantics, or
//   (c) Design-team sign-off on the unreachable entries (exclude path).
// =============================================================================
class mmu_l1dtlb_entry_sweep_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_entry_sweep_vseq)
  function new(string n = "mmu_l1dtlb_entry_sweep_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== mmu_l1dtlb_entry_sweep_vseq START =====", UVM_NONE)
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(null, "*", "MMU_DUT_PROBES_VIF", m_probe_vif))
      `uvm_info(get_type_name(), "MMU_DUT_PROBES_VIF not set", UVM_LOW)

    do_bringup(1024, 39'h10_0000);
    configure_ptw_delay(4, 8);

    // Single-entry install + inv pattern (proven to cover entry[0]).
    // TODO: extend to entries 1..15 once the accumulation issue above
    // is resolved.
    for (int unsigned iter = 0; iter < 16; iter++) begin
      va_t va;
      int unsigned page_idx;
      page_idx = iter;
      va = va_page(page_idx);
      raw_pipe0(va, 7'(8'd80 + iter[6:0]), 1'b0);
      wait_lsu_cycles(32);
      raw_inv(INV_VA_ALL, va, m_asid);
      wait_lsu_cycles(16);
    end
    m_env_h.wait_for_quiescent_midtest("entry_sweep_done", 262144, 8);
    configure_ptw_delay(1, 4);
    `uvm_info(get_type_name(), "mmu_l1dtlb_entry_sweep_vseq DONE", UVM_LOW)
  endtask
endclass

`endif
