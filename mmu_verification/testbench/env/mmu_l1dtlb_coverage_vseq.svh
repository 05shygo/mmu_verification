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
// TASK L1DTLB-T01 — entry 0..15 sweep + va8 invalidate (FIXED)
//
// Root cause (confirmed): The PLRU casez always selects the lowest invalid
// entry.  The previous vseq invalidated the just-installed entry after each
// iteration, making it the first invalid entry, so the PLRU always re-picked
// entry[0].  The fix REMOVES the per-iteration invalidate so entries naturally
// accumulate 0→1→2→...→15.  Invalidations are batched after all entries are
// filled, covering the inv_va SVA assertions for all 16 entries.
//
// Coverage targets:
//   - DTLB entries 8..15: l1dtlb_ent_vld[8..15], l1dtlb_ent_ppn[8..15][*],
//     l1dtlb_ent_vpn[8..15][*], l1dtlb_ent_flg[8..15][*], l1dtlb_ent_pgs[8..15][*]
//   - Lines 1116/1120/1190/1194 on entry indices 2..7
//   - a_va8_inv_clears_matching_entry[0..15] — all 16 SVA instances
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

    // ── Phase 1: Fill all 16 DTLB entries via PTW refill ─────────────────
    // Relies on test-base bringup (do_sv39_4k_bringup) which already mapped
    // pages at m_va_base=0x10_0000.  raw_pipe0 on each VPN triggers a miss,
    // PTW walk, and refill into the L1 DTLB.  NO per-entry invalidate so
    // the PLRU naturally fills entries 0→1→2→...→15.
    configure_ptw_delay(4, 8);
    for (int unsigned page_idx = 0; page_idx < 16; page_idx++) begin
      va_t va;
      va = va_page(page_idx);
      `uvm_info(get_type_name(),
        $sformatf("Phase1: fill[%0d] va=0x%010h vpn_lsb=0x%02h",
          page_idx, va, va[19:12]), UVM_MEDIUM)
      raw_pipe0(va, 7'(8'd80 + page_idx[6:0]), 1'b0);
      // Generous wait for PTW walk + L2TLB fill + DTLB install.
      wait_lsu_cycles(256);
      if (m_probe_vif != null) begin
        int unsigned probe_count;
        probe_count = 0;
        while (probe_count < 32) begin
          if (m_probe_vif.l1d_entry_vld[page_idx]) break;
          #1000ns;
          probe_count++;
        end
        if (!m_probe_vif.l1d_entry_vld[page_idx])
          `uvm_warning(get_type_name(),
            $sformatf("Entry[%0d] invalid (vld=0x%04h)",
              page_idx, m_probe_vif.l1d_entry_vld))
        else
          `uvm_info(get_type_name(),
            $sformatf("Entry[%0d] valid (vld=0x%04h vpn=0x%07h)",
              page_idx, m_probe_vif.l1d_entry_vld,
              m_probe_vif.l1d_entry_vpn[page_idx]), UVM_MEDIUM)
      end
    end

    if (m_probe_vif != null)
      `uvm_info(get_type_name(),
        $sformatf("Phase1 done: entry_vld=0x%04h (exp 0xFFFF)",
          m_probe_vif.l1d_entry_vld), UVM_NONE)

    // ── Phase 2: Hit + inv each entry (va8_inv SVA coverage) ─────────────
    for (int unsigned page_idx = 0; page_idx < 16; page_idx++) begin
      va_t va;
      va = va_page(page_idx);
      raw_pipe0(va, 7'(8'd81 + page_idx[6:0]), 1'b0);
      #500ns;
      raw_inv(INV_VA_ALL, va, m_asid);
      #1000ns;
    end

    // ── Phase 3: Re-fill entries for toggle coverage ──────────────────────
    for (int unsigned page_idx = 0; page_idx < 8; page_idx++) begin
      raw_pipe0(va_page(page_idx), 7'(8'd82 + page_idx[6:0]), 1'b0);
      #2000ns;
    end

    #50000ns;
    `uvm_info(get_type_name(), "mmu_l1dtlb_entry_sweep_vseq DONE", UVM_NONE)
  endtask
endclass

`endif
