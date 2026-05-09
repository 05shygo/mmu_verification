// =============================================================================
// L1DTLB spec scoreboard
//
// Lightweight whitebox-assisted protocol checks for the Chapter-3 L1DTLB audit
// rows. This checker keeps pass/fail on externally visible semantics and uses
// DUT probes only for ownership, MB state, and scheduler diagnostics.
// =============================================================================
`ifndef MMU_L1DTLB_SPEC_SB_SVH
`define MMU_L1DTLB_SPEC_SB_SVH

class mmu_l1dtlb_spec_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_l1dtlb_spec_sb)

  localparam logic [2:0] MB_STATE_IDLE  = 3'b000;
  localparam logic [2:0] MB_STATE_WFG   = 3'b001;
  localparam logic [2:0] MB_STATE_WFC   = 3'b010;
  localparam logic [2:0] MB_STATE_PGFLT = 3'b011;
  localparam logic [2:0] MB_STATE_ACFLT = 3'b100;
  localparam logic [2:0] MB_STATE_ABT   = 3'b101;
  localparam logic [2:0] MB_STATE_WFI   = 3'b110;

  virtual mmu_dut_probes_if v_probe;
  virtual lsu_if            lsu_vif;

  int unsigned m_cycles;
  int unsigned m_errors;
  int unsigned m_busy_checks;
  int unsigned m_wakeup_pulses;
  int unsigned m_dual_req_cycles;
  int unsigned m_hit_cycles;
  int unsigned m_dual_hit_cycles;
  int unsigned m_hit_miss_cycles;
  int unsigned m_dual_miss_cycles;
  int unsigned m_mb_full_cycles;
  int unsigned m_l2_req_cycles;
  int unsigned m_refill_cycles;
  int unsigned m_expt_write_cycles;
  int unsigned m_reset_state_checks;
  int unsigned m_direct_map_cycles;
  int unsigned m_stamo_cycles;
  int unsigned m_abort_req_cycles;
  int unsigned m_inv_cycles;
  int unsigned m_flush_cycles;
  int unsigned m_hpc_miss_cycles;
  int unsigned m_page_fault_cycles;
  int unsigned m_access_fault_cycles;

  bit m_seen_post_reset;
  string m_l1dtlb_tc_id;
  string m_l1dtlb_scenario_id;
  bit    m_l1dtlb_gate_en;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe))
      `uvm_info(get_type_name(), "MMU_DUT_PROBES_VIF not found - L1DTLB spec SB idle", UVM_LOW)
    if (!uvm_config_db#(virtual lsu_if)::get(this, "", "LSU_VIF", lsu_vif))
      `uvm_info(get_type_name(), "LSU_VIF not found - L1DTLB spec SB idle", UVM_LOW)
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_TC_ID", m_l1dtlb_tc_id));
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_SCENARIO_ID", m_l1dtlb_scenario_id));
    m_l1dtlb_gate_en = (m_l1dtlb_tc_id.len() != 0);
  endfunction

  protected function void sb_error(string tag, string msg);
    m_errors++;
    `uvm_error({get_type_name(), "::", tag}, msg)
  endfunction

  protected function int unsigned count8(input logic [7:0] v);
    return int'($countones(v));
  endfunction

  protected function int unsigned count16(input logic [15:0] v);
    return int'($countones(v));
  endfunction

  protected function logic [15:0] onehot16(input logic [3:0] idx);
    logic [15:0] v;
    v = '0;
    v[idx] = 1'b1;
    return v;
  endfunction

  protected function bit req0_seen();
    return lsu_vif.monitor_cb.lsu_mmu_va0_vld && !lsu_vif.monitor_cb.lsu_mmu_abort0;
  endfunction

  protected function bit req1_seen();
    return lsu_vif.monitor_cb.lsu_mmu_va1_vld && !lsu_vif.monitor_cb.lsu_mmu_abort1;
  endfunction

  protected virtual function void check_reset_initial_state();
    if (m_seen_post_reset)
      return;
    m_seen_post_reset = 1'b1;
    m_reset_state_checks++;
    if (!$isunknown(v_probe.mon_cb.l1d_entry_vld)
        && (v_probe.mon_cb.l1d_entry_vld !== 16'h0000))
      sb_error("RESET_ENTRY",
        $sformatf("L1DTLB entry_vld not clear after reset: 0x%04h",
          v_probe.mon_cb.l1d_entry_vld));
    if (!$isunknown(v_probe.mon_cb.l1d_mb_vld)
        && (v_probe.mon_cb.l1d_mb_vld !== 8'h00))
      sb_error("RESET_MB",
        $sformatf("L1DTLB MB not clear after reset: 0x%02h",
          v_probe.mon_cb.l1d_mb_vld));
  endfunction

  protected virtual function void check_busy_and_wakeup();
    bit exp_busy;

    if (!$isunknown({lsu_vif.monitor_cb.mmu_lsu_tlb_busy, v_probe.mon_cb.l1d_mb_vld})) begin
      exp_busy = |v_probe.mon_cb.l1d_mb_vld;
      m_busy_checks++;
      if (lsu_vif.monitor_cb.mmu_lsu_tlb_busy !== exp_busy)
        sb_error("BUSY",
          $sformatf("mmu_lsu_tlb_busy=%0b but |mb_vld=%0b mb_vld=0x%02h",
            lsu_vif.monitor_cb.mmu_lsu_tlb_busy, exp_busy,
            v_probe.mon_cb.l1d_mb_vld));
    end

    if (!$isunknown(lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup)
        && (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup != 12'h000)) begin
      m_wakeup_pulses++;
      if (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup !== 12'hfff)
        sb_error("WAKEUP_BCAST",
          $sformatf("L1DTLB wakeup must be all-zero or broadcast all-ones, got 0x%03h",
            lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup));
    end
  endfunction

  protected virtual function void check_mb_state_derived_signals();
    for (int i = 0; i < 8; i++) begin
      logic [2:0] st;
      bit exp_vld;
      bit exp_ready;
      bit exp_wfc;
      bit exp_wfi;

      st = v_probe.mon_cb.l1d_mb_state[i];
      if ($isunknown({st, v_probe.mon_cb.l1d_mb_vld[i],
                      v_probe.mon_cb.l1d_mb_ready[i],
                      v_probe.mon_cb.l1d_mb_wfc[i],
                      v_probe.mon_cb.l1d_mb_wfi[i]}))
        continue;

      exp_vld   = (st != MB_STATE_IDLE);
      exp_ready = (st == MB_STATE_WFG);
      exp_wfc   = (st == MB_STATE_WFC) || (st == MB_STATE_ABT);
      exp_wfi   = (st == MB_STATE_WFI);

      if (v_probe.mon_cb.l1d_mb_vld[i] !== exp_vld)
        sb_error("MB_VLD_STATE",
          $sformatf("MB%0d vld=%0b inconsistent with state=%0b",
            i, v_probe.mon_cb.l1d_mb_vld[i], st));
      if (v_probe.mon_cb.l1d_mb_ready[i] && !exp_ready)
        sb_error("MB_READY_STATE",
          $sformatf("MB%0d ready asserted outside WFG, state=%0b", i, st));
      if (v_probe.mon_cb.l1d_mb_wfc[i] !== exp_wfc)
        sb_error("MB_WFC_STATE",
          $sformatf("MB%0d wfc=%0b inconsistent with state=%0b",
            i, v_probe.mon_cb.l1d_mb_wfc[i], st));
      if (v_probe.mon_cb.l1d_mb_wfi[i] !== exp_wfi)
        sb_error("MB_WFI_STATE",
          $sformatf("MB%0d wfi=%0b inconsistent with state=%0b",
            i, v_probe.mon_cb.l1d_mb_wfi[i], st));
    end
  endfunction

  protected virtual function void check_refill_and_expt();
    if (v_probe.mon_cb.l1d_refill_vld) begin
      m_refill_cycles++;
      if ($isunknown({v_probe.mon_cb.l1d_entry_upd, v_probe.mon_cb.l1d_refill_idx}))
        sb_error("REFILL_X", "refill_vld asserted with X entry_upd/refill_idx");
      else if (count16(v_probe.mon_cb.l1d_entry_upd) != 1)
        sb_error("REFILL_ONEHOT",
          $sformatf("refill_vld requires one-hot entry_upd, got 0x%04h",
            v_probe.mon_cb.l1d_entry_upd));
      else if (v_probe.mon_cb.l1d_entry_upd !== onehot16(v_probe.mon_cb.l1d_refill_idx))
        sb_error("REFILL_INDEX",
          $sformatf("entry_upd=0x%04h does not match refill_idx=%0d",
            v_probe.mon_cb.l1d_entry_upd, v_probe.mon_cb.l1d_refill_idx));
    end

    if (v_probe.mon_cb.l1d_expt_wr0_vld) begin
      m_expt_write_cycles++;
      if (v_probe.mon_cb.l1d_expt_wr0_pgflt && v_probe.mon_cb.l1d_expt_wr0_acflt)
        sb_error("EXPT_WR0_FAULT_EXCL",
          $sformatf("expt_wr0 has both page/access fault set: eid=%0d iid=%0d vpn=0x%07h",
            v_probe.mon_cb.l1d_expt_wr0_eid,
            v_probe.mon_cb.l1d_expt_wr0_iid,
            v_probe.mon_cb.l1d_expt_wr0_vpn));
    end
    if (v_probe.mon_cb.l1d_expt_wr1_vld) begin
      m_expt_write_cycles++;
      if (v_probe.mon_cb.l1d_expt_wr1_pgflt && v_probe.mon_cb.l1d_expt_wr1_acflt)
        sb_error("EXPT_WR1_FAULT_EXCL",
          $sformatf("expt_wr1 has both page/access fault set: eid=%0d iid=%0d vpn=0x%07h",
            v_probe.mon_cb.l1d_expt_wr1_eid,
            v_probe.mon_cb.l1d_expt_wr1_iid,
            v_probe.mon_cb.l1d_expt_wr1_vpn));
    end
  endfunction

  protected virtual function void check_l2_req_and_credit();
    if (v_probe.mon_cb.l1d_l2_req_vld) begin
      m_l2_req_cycles++;
      if ($isunknown({v_probe.mon_cb.l1d_l2_req_vpn,
                      v_probe.mon_cb.l1d_l2_req_eid,
                      v_probe.mon_cb.l1d_l2_req_is_load}))
        sb_error("L2_REQ_X", "L1DTLB L2 request asserted with X payload");
      if (v_probe.mon_cb.l1d_l2_req_eid > 3'd7)
        sb_error("L2_REQ_EID",
          $sformatf("L1DTLB L2 request EID out of MB range: %0d",
            v_probe.mon_cb.l1d_l2_req_eid));
    end
    if (!$isunknown(v_probe.mon_cb.l1d_sched_credit_cnt)
        && (v_probe.mon_cb.l1d_sched_credit_cnt > 5'd8))
      sb_error("CREDIT_RANGE",
        $sformatf("L1DTLB scheduler credit_cnt out of range: %0d",
          v_probe.mon_cb.l1d_sched_credit_cnt));
  endfunction

  protected virtual function void check_pipe_response_fault_pulses();
    logic p0_pgflt;
    logic p0_acflt;
    logic p1_pgflt;
    logic p1_acflt;

    p0_pgflt = lsu_vif.monitor_cb.mmu_lsu_page_fault0;
    p0_acflt = lsu_vif.monitor_cb.mmu_lsu_access_fault0;
    p1_pgflt = lsu_vif.monitor_cb.mmu_lsu_page_fault1;
    p1_acflt = lsu_vif.monitor_cb.mmu_lsu_access_fault1;

    if (!$isunknown({p0_pgflt, p0_acflt}) && p0_pgflt && p0_acflt)
      sb_error("P0_FAULT_EXCL", "Pipe0 page_fault and access_fault asserted in same cycle");
    if (!$isunknown({p1_pgflt, p1_acflt}) && p1_pgflt && p1_acflt)
      sb_error("P1_FAULT_EXCL", "Pipe1 page_fault and access_fault asserted in same cycle");

  endfunction

  protected virtual function void sample_scenario_counters();
    bit p0_req;
    bit p1_req;
    bit p0_hit;
    bit p1_hit;
    bit p0_miss;
    bit p1_miss;

    p0_req  = req0_seen();
    p1_req  = req1_seen();
    p0_hit  = v_probe.mon_cb.l1d_p0_hit_vld;
    p1_hit  = v_probe.mon_cb.l1d_p1_hit_vld;
    p0_miss = v_probe.mon_cb.l1d_p0_miss_vld;
    p1_miss = v_probe.mon_cb.l1d_p1_miss_vld;

    if (p0_req && p1_req) begin
      m_dual_req_cycles++;
      if (p0_hit && p1_hit)
        m_dual_hit_cycles++;
      if ((p0_hit && p1_miss) || (p1_hit && p0_miss))
        m_hit_miss_cycles++;
      if (p0_miss && p1_miss)
        m_dual_miss_cycles++;
    end

    if ((p0_req && p0_hit) || (p1_req && p1_hit))
      m_hit_cycles++;

    if (count8(v_probe.mon_cb.l1d_mb_vld) == 8)
      m_mb_full_cycles++;

    if (lsu_vif.monitor_cb.mmu_lsu_mmu_en === 1'b0)
      m_direct_map_cycles++;
    if (lsu_vif.monitor_cb.lsu_mmu_stamo_vld)
      m_stamo_cycles++;
    if ((lsu_vif.monitor_cb.lsu_mmu_va0_vld && lsu_vif.monitor_cb.lsu_mmu_abort0)
     || (lsu_vif.monitor_cb.lsu_mmu_va1_vld && lsu_vif.monitor_cb.lsu_mmu_abort1))
      m_abort_req_cycles++;
    if (lsu_vif.monitor_cb.mmu_lsu_tlb_inv_done
     || v_probe.mon_cb.tlboper_utlb_clr
     || v_probe.mon_cb.tlboper_utlb_inv_va_req)
      m_inv_cycles++;
    if (v_probe.mon_cb.rtu_yy_xx_flush)
      m_flush_cycles++;
    if (v_probe.mon_cb.l1d_p0_miss_vld || v_probe.mon_cb.l1d_p1_miss_vld)
      m_hpc_miss_cycles++;
    if (lsu_vif.monitor_cb.mmu_lsu_page_fault0 || lsu_vif.monitor_cb.mmu_lsu_page_fault1)
      m_page_fault_cycles++;
    if (lsu_vif.monitor_cb.mmu_lsu_access_fault0 || lsu_vif.monitor_cb.mmu_lsu_access_fault1)
      m_access_fault_cycles++;
  endfunction

  protected function void gate_expect_nonzero(string tag, int unsigned value);
    if (value == 0)
      `uvm_warning({get_type_name(), "::SCENARIO_GATE"},
        $sformatf("%s did not observe required event for tc_id=%s scenario_id=%s",
          tag, m_l1dtlb_tc_id, m_l1dtlb_scenario_id))
  endfunction

  protected virtual function void check_scenario_gate();
    if (!m_l1dtlb_gate_en)
      return;

    if ((m_l1dtlb_tc_id == "DTLB_HIT_001") || (m_l1dtlb_tc_id == "DTLB_HIT_002")
     || (m_l1dtlb_tc_id == "DTLB_CONCURRENT_001") || (m_l1dtlb_tc_id == "DTLB_DUAL_HIT_MUX_001"))
      gate_expect_nonzero("hit_cycle", m_hit_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_HIT_MISS_CONCURRENT_001") || (m_l1dtlb_tc_id == "DTLB_CONCURRENT_002"))
      gate_expect_nonzero("hit_miss_cycle", m_hit_miss_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_ALLOC_001") || (m_l1dtlb_tc_id == "DTLB_ALLOC_TWO_LOWEST_FREE_001"))
      gate_expect_nonzero("dual_miss_cycle", m_dual_miss_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_ALLOC_FULL_001") || (m_l1dtlb_tc_id == "DTLB_MB_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_002"))
      gate_expect_nonzero("mb_full", m_mb_full_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_CREDIT_001") || (m_l1dtlb_tc_id == "DTLB_CREDIT_002")
     || (m_l1dtlb_tc_id == "DTLB_CREDIT_BOUND_001") || (m_l1dtlb_tc_id == "DTLB_SCHED_001")
     || (m_l1dtlb_tc_id == "DTLB_ALLOC_RACE_001"))
      gate_expect_nonzero("l2_req", m_l2_req_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_REFILL_001") || (m_l1dtlb_tc_id == "DTLB_REFILL_002")
     || (m_l1dtlb_tc_id == "DTLB_INSTALL_ARB_001") || (m_l1dtlb_tc_id == "DTLB_INSTALL_ID_CHK_001")
     || (m_l1dtlb_tc_id == "DTLB_INSTALL_VISIBILITY_001") || (m_l1dtlb_tc_id == "DTLB_WFI_DATA_HOLD_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FSM_WFI_001") || (m_l1dtlb_tc_id == "DTLB_ENTRY_FIELD_MODEL_001"))
      gate_expect_nonzero("refill_install", m_refill_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_MB_PGFLT_001") || (m_l1dtlb_tc_id == "DTLB_EXPT_ID_MAP_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FAULT_HOLD_001") || (m_l1dtlb_tc_id == "DTLB_EXPT_HIT_WITH_TLB_HIT_001")
     || (m_l1dtlb_tc_id == "DTLB_ACCESS_FAULT_SOURCE_PARITY_001") || (m_l1dtlb_tc_id == "DTLB_WAKEUP_EXPT_001"))
      gate_expect_nonzero("exception_write_or_fault", m_expt_write_cycles + m_page_fault_cycles + m_access_fault_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_INV_001") || (m_l1dtlb_tc_id == "DTLB_INV_002")
     || (m_l1dtlb_tc_id == "DTLB_INV_003") || (m_l1dtlb_tc_id == "DTLB_INV_004")
     || (m_l1dtlb_tc_id == "DTLB_INV_VA8_alias_001") || (m_l1dtlb_tc_id == "DTLB_INV_HIT_SAME_CYCLE_001")
     || (m_l1dtlb_tc_id == "DTLB_INV_INSTALL_SAME_ENTRY_001"))
      gate_expect_nonzero("invalidate", m_inv_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_MB_FLUSH_RACE_MATRIX_001") || (m_l1dtlb_tc_id == "DTLB_CLEANUP_SCOPE_MATRIX_001"))
      gate_expect_nonzero("flush", m_flush_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_STAMO_001") || (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE1_BYPASS_001")
     || (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE0_NEG_001"))
      gate_expect_nonzero("stamo", m_stamo_cycles);

    if (m_l1dtlb_tc_id == "DTLB_SYSMAP_001")
      gate_expect_nonzero("direct_map", m_direct_map_cycles);

    if (m_l1dtlb_tc_id == "DTLB_ABORT_001")
      gate_expect_nonzero("abort_req", m_abort_req_cycles);
  endfunction

  virtual task run_phase(uvm_phase phase);
    if ((v_probe == null) || (lsu_vif == null))
      return;

    forever begin
      @(v_probe.mon_cb);
      if (v_probe.rst_ni !== 1'b1) begin
        m_seen_post_reset = 1'b0;
        continue;
      end

      m_cycles++;
      check_reset_initial_state();
      check_busy_and_wakeup();
      check_mb_state_derived_signals();
      check_refill_and_expt();
      check_l2_req_and_credit();
      check_pipe_response_fault_pulses();
      sample_scenario_counters();
    end
  endtask

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_TC_ID", m_l1dtlb_tc_id));
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_SCENARIO_ID", m_l1dtlb_scenario_id));
    m_l1dtlb_gate_en = (m_l1dtlb_tc_id.len() != 0);
    check_scenario_gate();
    `uvm_info(get_type_name(),
      $sformatf("summary tc_id=%s scenario_id=%s cycles=%0d errors=%0d busy_checks=%0d wakeup=%0d hit=%0d dual_req=%0d dual_hit=%0d hit_miss=%0d dual_miss=%0d mb_full=%0d l2_req=%0d refill=%0d expt_wr=%0d reset_checks=%0d direct_map=%0d stamo=%0d abort=%0d inv=%0d flush=%0d pf=%0d af=%0d",
        m_l1dtlb_tc_id, m_l1dtlb_scenario_id,
        m_cycles, m_errors, m_busy_checks, m_wakeup_pulses,
        m_hit_cycles, m_dual_req_cycles, m_dual_hit_cycles, m_hit_miss_cycles,
        m_dual_miss_cycles, m_mb_full_cycles, m_l2_req_cycles,
        m_refill_cycles, m_expt_write_cycles, m_reset_state_checks,
        m_direct_map_cycles, m_stamo_cycles, m_abort_req_cycles,
        m_inv_cycles, m_flush_cycles, m_page_fault_cycles,
        m_access_fault_cycles),
      UVM_LOW)
  endfunction

endclass : mmu_l1dtlb_spec_sb

`endif // MMU_L1DTLB_SPEC_SB_SVH
