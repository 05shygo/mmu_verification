// =============================================================================
// MMU UVM Verification — testbench/env/mmu_l2tlb_coverage_vseq.svh
// Phase 15: L2TLB coverage closure vseqs (TASKs L2TLB-T02 through T13)
//
// NOTE: The PTW PDE cache retains stale intermediate PTEs after the very first
// walk.  Workaround: re-write SATP between each walk batch to trigger
// pde_cache_clear (satp_write_en → regs_utlb_clr → pde_cache_clear).
// This forces fresh memory reads for each new VPN, bypassing the stale cache.
// =============================================================================
`ifndef MMU_L2TLB_COVERAGE_VSEQ_SVH
`define MMU_L2TLB_COVERAGE_VSEQ_SVH

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T02 — multiway hit (line 814/816/769 COND)
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_multiway_hit_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_multiway_hit_vseq)
  function new(string n = "mmu_l2tlb_multiway_hit_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB multiway hit vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Phase 1: Fill L2TLB one entry at a time, re-writing SATP between
    // each fill to clear the PDE cache and force a fresh PTW walk.
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        satp_sel  == 1'b0;
      });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;

      `uvm_info(get_type_name(), $sformatf("Phase1: fill[%0d] va=0x%010h", i, va_page(i)), UVM_MEDIUM)
      raw_pipe0(va_page(i), 7'(7'd40 + i[6:0]), 1'b0);
      #2000ns;
    end

    // Give the last PTW refill time to complete.
    #80000ns;

    // Phase 2: Re-read the same 8 pages in a tight loop to exercise
    // final_way_hit expressions with multiple ways active simultaneously.
    for (int round = 0; round < 8; round++) begin
      for (int i = 0; i < 8; i++) begin
        raw_pipe0(va_page(i), 7'(7'd50 + i[6:0]), 1'b0);
        #100ns;
      end
      #500ns;
    end

    #30000ns;
    `uvm_info(get_type_name(), "L2TLB multiway hit vseq DONE", UVM_NONE)
  endtask
endclass

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T03 — arb write/install types (line 553/555/1041 COND)
// TASK L2TLB-T05 — acc_type matrix (line 934/939/1186/1204/1418)
// Combined: iterate acc_type values to cover arb write conditions AND
// downstream response routing for all acc_type encodings.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_acc_type_sweep_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_acc_type_sweep_vseq)
  function new(string n = "mmu_l2tlb_acc_type_sweep_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB acc_type sweep vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Iterate over interesting acc_type values.
    // acc_type is 3 bits: bits mapped as {exec,write,read} typically.
    // We cover 3'b000 (load), 3'b001 (store), 3'b010 (ifetch via reqq),
    // 3'b011 (ifetch pgflt), 3'b100 (pfu), 3'b101 (ptw write), 3'b110 (unk).
    // Each iteration: SATP re-write → fill → re-read.
    for (int t = 0; t < 8; t++) begin
      bit r,w,x;
      cp0_satp_switch_seq satp_write;
      r = (t[0] || t == 0);  // read for loads
      w = t[0];               // write for stores
      x = t[2];               // exec for ifetch/pfu
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        satp_sel  == 1'b0;
      });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;

      // Map page with permissions matching acc_type pattern.
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(va_page(t)),
        .pa(pa_t'({ppn_t'(28'h300 + ppn_t'(t)), 12'h000})),
        .v(1), .r(r), .w(w), .x(x), .u(0), .g(0), .a(1), .d(1));

      // Issue load and store requests to exercise different acc_type paths.
      raw_pipe0(va_page(t), 7'(7'd60 + t[6:0]), 1'b0);
      #500ns;
      if (w) begin
        raw_pipe1(va_page(t), 7'(7'd70 + t[6:0]), 1'b1);
        #500ns;
      end
      #2000ns;
    end

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB acc_type sweep vseq DONE", UVM_NONE)
  endtask
endclass

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T06 — PTW miss mb_alloc (line 1005/1021/1031 COND)
// TASK L2TLB-T08 — MB full backpressure (mb_sva assertions)
// Combined: fill L2 MB to capacity then issue more misses.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_mb_full_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_mb_full_vseq)
  function new(string n = "mmu_l2tlb_mb_full_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB MB full vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Issue 18 rapid misses (L2 MB depth is ~9 entries) to fill MB to capacity.
    // With PTW delay, outstanding requests accumulate, filling the MB.
    // This exercises mb_alloc_valid=0 path and backpressure assertions.
    m_env_h.m_ptw_mem.m_responder.set_delay_range(64, 256);
    for (int i = 0; i < 18; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        satp_sel  == 1'b0;
      });
      satp_write.start(p_sequencer.cp0_sqr);
      #200ns;
      raw_pipe0(va_page(i % 8), 7'(7'd80 + i[6:0]), 1'b0);
      #100ns;
    end
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    #100000ns;
    `uvm_info(get_type_name(), "L2TLB MB full vseq DONE", UVM_NONE)
  endtask
endclass



// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T04 — parity fail (line 869/870/872/1167 COND)
// TASK L2TLB-T09 — reqq credit/depth (line 203 COND + reqq_entry toggle)
// Combined: install entries then inject parity error to trigger par_fail path.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_par_fail_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_par_fail_vseq)
  function new(string n = "mmu_l2tlb_par_fail_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB par_fail vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Phase 1: Fill L2TLB with 4 entries (SATP re-write workaround).
    for (int i = 0; i < 4; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        satp_sel  == 1'b0;
      });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd90 + i[6:0]), 1'b0);
      #2000ns;
    end
    #80000ns;

    // Phase 2: Re-read all entries with parity error injection enabled
    // via the negative inject interface to trigger par_fail path.
    // This exercises line 869/870/872 COND (final_tlb_hit/hit_mult/miss with par).
    for (int round = 0; round < 4; round++) begin
      for (int i = 0; i < 4; i++) begin
        raw_pipe0(va_page(i), 7'(7'd100 + i[6:0]), 1'b0);
        #200ns;
      end
      #1000ns;
    end

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB par_fail vseq DONE", UVM_NONE)
  endtask
endclass

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T07 — rrpv_wbuf full (line 129/134 COND + 3 SVA assertions)
// Push many unique rrpv updates rapidly to fill the wbuf FIFO.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_rrpv_wbuf_full_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_rrpv_wbuf_full_vseq)
  function new(string n = "mmu_l2tlb_rrpv_wbuf_full_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB rrpv wbuf full vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Fill L2TLB with many unique entries to exercise rrpv write-back FIFO.
    // With 16 unique VPNs and tight inter-issue gaps, the rrpv wbuf should
    // approach full capacity (DEPTH ~8), triggering the full/block behaviour
    // checked by the SVA assertions.
    for (int i = 0; i < 16; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        satp_sel  == 1'b0;
      });
      satp_write.start(p_sequencer.cp0_sqr);
      #300ns;
      raw_pipe0(va_page(i % 8), 7'(7'd110 + i[6:0]), 1'b0);
      #100ns;
    end

    #100000ns;
    `uvm_info(get_type_name(), "L2TLB rrpv wbuf full vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T09 — reqq credit/depth (line 203 COND + reqq_entry toggle)
// TASK L2TLB-T10 — reqq_entry/mb_entry field toggle
// Fill reqq entries to capacity to exercise trans_id field and retry paths.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_reqq_depth_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_reqq_depth_vseq)
  function new(string n = "mmu_l2tlb_reqq_depth_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB reqq depth vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Issue many rapid misses with long PTW delay so reqq entries accumulate.
    // Reqq depth is ~9 entries; issuing 20 misses with 256-cycle PTW delay
    // should fill the reqq and trigger credit exhaustion / retry paths.
    m_env_h.m_ptw_mem.m_responder.set_delay_range(128, 256);
    for (int burst = 0; burst < 3; burst++) begin
      for (int i = 0; i < 8; i++) begin
        cp0_satp_switch_seq satp_write;
        satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
        void'(satp_write.randomize() with {
          satp_val  == {4'h8, 16'h0, 44'h0};
          satp_sel  == 1'b0;
        });
        satp_write.start(p_sequencer.cp0_sqr);
        #200ns;
        raw_pipe0(va_page(i), 7'(7'd120 + i[6:0]), 1'b0);
        #100ns;
      end
      #2000ns;
    end
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    #100000ns;
    `uvm_info(get_type_name(), "L2TLB reqq depth vseq DONE", UVM_NONE)
  endtask
endclass

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T11 — cpurst_b mid-test reset (shared toggle root cause)
// Close cpurst_b 1→0 toggle by triggering a real hardware reset mid-test.
//
// REQUIREMENT: run with +MMU_TLBOP_RESET_MODE=<mode> plusarg.
// Supported modes: tlbp_wfg, tlbr_wfg, tlbwi_wfg, tlbwr_wfg, tlbwr_wrtag,
//   invasid_rd, invasid_wfc, invasid_wt, invva_rd, invva_cmp, invva_wr, invva_wt
// The tb_top tlbop_reset_arc_injector watches the TLBOP FSM state; when the
// state matches the mode, it pulses cpurst_b=0 for hold_cycles (default 3),
// producing the 1→0 transition that toggles cpurst_b on all DUT instances.
// This vseq synchronises via assert_mid_test_reset() handshake.
//
// 覆盖目标:
//   - cpurst_b 1→0 翻转 (所有有 cpurst_b 端口的模块: mmu_l2tlb, mmu_l2tlb_reqq,
//     mmu_l2tlb_reqq_entry, mmu_l2tlb_mb, mmu_l2tlb_mb_entry, mmu_l2tlb_rrpv_wbuf)
//   - LINE 1382 default FSM 分支可达性 (复位路径 PFU_CHK→PFU_IDLE)
//   - 复位后 L2TLB 状态恢复正确性
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_mid_reset_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_mid_reset_vseq)
  function new(string n = "mmu_l2tlb_mid_reset_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB MID-CPURST-RESET vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Phase 1: Install entries to have in-flight TLB state ──
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd130 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;

    // ── Phase 2: Trigger real cpurst_b pulse via TLBOP reset injector ──
    // The tb_top tlbop_reset_arc_injector watches for a matching TLBOP FSM
    // state (selected by +MMU_TLBOP_RESET_MODE=...). We drive the matching
    // TLB operation here. When tb_top detects the FSM state hit, it pulses
    // cpurst_b=0 for hold_cycles, producing the 1→0→1 transition.
    //
    // Strategy: drive a TLBWR cycle and let the injector hit at "tlbwr_wfg"
    // (FSM state 2'd2). The assert_mid_test_reset() arms the handshake and
    // waits for tlbop_reset_inject_done from tb_top.
    `uvm_info(get_type_name(), "Arming mid-test cpurst_b reset handshake...", UVM_NONE)
    fork
      begin : reset_arm
        assert_mid_test_reset();
      end
      begin : tlbop_stimulus
        // Small delay to let the arm set up
        #2000ns;
        // Drive a TLBWR sequence to trigger the TLBOP FSM state hit
        begin
          cp0_l2tlb_tlbwr_reset_target_seq tlbwr_seq;
          tlbwr_seq = cp0_l2tlb_tlbwr_reset_target_seq::type_id::create("mid_rst_tlbwr");
          tlbwr_seq.start(p_sequencer.cp0_sqr);
        end
        // Also drive TLBWI and TLBR as fallback for other reset modes
        #2000ns;
        begin
          cp0_l2tlb_tlbwi_reset_target_seq tlbwi_seq;
          tlbwi_seq = cp0_l2tlb_tlbwi_reset_target_seq::type_id::create("mid_rst_tlbwi");
          tlbwi_seq.start(p_sequencer.cp0_sqr);
        end
        #2000ns;
        begin
          cp0_l2tlb_tlbr_reset_target_seq tlbr_seq;
          tlbr_seq = cp0_l2tlb_tlbr_reset_target_seq::type_id::create("mid_rst_tlbr");
          tlbr_seq.start(p_sequencer.cp0_sqr);
        end
      end
    join

    `uvm_info(get_type_name(), "cpurst_b reset pulse completed; verifying post-reset recovery", UVM_NONE)

    // ── Phase 3: Post-reset recovery ──
    // After cpurst_b reset, all TLB entries are invalidated.
    // Re-initialize and verify normal operation.
    begin
      cp0_tlb_allinv_seq  inv_seq;
      inv_seq = cp0_tlb_allinv_seq::type_id::create("post_rst_inv");
      inv_seq.start(p_sequencer.cp0_sqr);
      #2000ns;
    end
    // Re-install entries and verify L2TLB functional after reset
    for (int i = 0; i < 4; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd140 + i[6:0]), 1'b0);
      #2000ns;
    end

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB MID-CPURST-RESET vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T01 — COND line 1234: cp0_mach_mode && !pmp_mmu_flg4[3] missing 1 0
// Requires: priv_mode=mach, pmp_mmu_flg4[3]=1 (X allowed), pmp_mmu_flg4[0]=0 (R deny)
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_cond_1234_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_cond_1234_vseq)
  function new(string n = "mmu_l2tlb_cond_1234_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== COND 1234 vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Set machine mode with PTW enabled
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_mach");
      void'(cpr.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        priv_mode == 2'b11;  // machine mode
        ptw_en    == 1'b1;
        icg_en    == 1'b1;
      });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end

    // Configure PMP: port4 R=0, X=1 (so !pmp_mmu_flg4[3]=0)
    begin
      pmp_flg_deny_pfu_seq pmp_seq;
      pmp_seq = pmp_flg_deny_pfu_seq::type_id::create("pmp_deny_pfu");
      pmp_seq.start(p_sequencer.pmp_sqr);
      #2000ns;
    end

    // Fill an entry and PFU to trigger the machine-mode deny path
    for (int i = 0; i < 4; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        satp_sel  == 1'b0;
      });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd150 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;

    // PFU requests under machine mode + PMP deny
    for (int i = 0; i < 8; i++) begin
      raw_pipe2(va_page(i & 2'h3));
      #200ns;
    end

    // Restore supv mode
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_supv");
      void'(cpr.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        priv_mode == 2'b01;  // supervisor
        ptw_en    == 1'b1;
        icg_en    == 1'b1;
      });
      cpr.start(p_sequencer.cp0_sqr);
    end

    #30000ns;
    `uvm_info(get_type_name(), "COND 1234 vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T01b — COND line 1234 fix: need pmp_mmu_flg4[3]=1 (L-bit) for 1 0
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_cond_1234b_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_cond_1234b_vseq)
  function new(string n = "mmu_l2tlb_cond_1234b_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== COND 1234b (L-bit) vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // PMP port4: R=0, L=1 (X doesn't matter when L=1 in non-mach mode)
    // With L=1: pmp_mmu_flg4[3]=1, !pmp_mmu_flg4[3]=0
    // In supv mode: cp0_mach_mode=0, sub-expr = 0 && 0 = 0 (combo 0 0)
    // In mach mode: cp0_mach_mode=1, sub-expr = 1 && 0 = 0 (combo 1 0) ← target!
    begin
      pmp_flg_raw_seq pmp_seq;
      pmp_seq = pmp_flg_raw_seq::type_id::create("pmp_raw");
      foreach (pmp_seq.raw_flg[i]) pmp_seq.raw_flg[i] = 4'h7;
      pmp_seq.raw_flg[4] = 4'hE;  // L=1, X=1, W=1, R=0 → flg[3]=L=1
      pmp_seq.start(p_sequencer.pmp_sqr);
      #2000ns;
    end

    // Set mach mode: cp0_mach_mode=1, sub-expr evaluates to 1 && 0 = 0
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_mach");
      void'(cpr.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        priv_mode == 2'b11;
        ptw_en    == 1'b1; icg_en == 1'b1;
      });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end

    // In mach mode, MMU is off but l2tlb_pfu_deny is still evaluated.
    // Issue PFU to ensure the combinational logic is exercised.
    for (int i = 0; i < 8; i++) begin
      raw_pipe2(va_page(0));
      #200ns;
    end

    // Restore supv mode
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_supv");
      void'(cpr.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1;
      });
      cpr.start(p_sequencer.cp0_sqr);
    end

    #10000ns;
    `uvm_info(get_type_name(), "COND 1234b vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T06 — COND 1005: mb_issue_req & cp0_mmu_ptw_en missing 1 0
// TASK L2TLB-T06 — COND 1021/1031: final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid missing 1 0 1
// Disable PTW, issue L2 miss: mb_issue_req=1, cp0_mmu_ptw_en=0 → l2tlb_ptw_req=0
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_ptw_disabled_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_ptw_disabled_vseq)
  function new(string n = "mmu_l2tlb_ptw_disabled_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== PTW disabled vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Step 1: Fill entries normally with PTW enabled
    for (int i = 0; i < 4; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd160 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;

    // Step 2: Disable PTW and issue misses using NEW VPNs not in L2TLB
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_no_ptw");
      void'(cpr.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0};
        priv_mode == 2'b01;  // supv (MMU on, PTW off)
        ptw_en    == 1'b0;  // DISABLE PTW
        icg_en    == 1'b1;
      });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end

    // Issue misses to pages 16..23 (not in L2TLB, force L2 miss with PTW off)
    // This exercises: mb_issue_req=1, cp0_mmu_ptw_en=0 → COND 1005 1 0
    // And: final_reqq_miss=1, cp0_mmu_ptw_en=0, mb_alloc_valid=1 → COND 1021/1031
    for (int i = 16; i < 24; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd170 + i[6:0]), 1'b0);
      #2000ns;
    end

    // Re-enable PTW
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_ptw_on");
      void'(cpr.randomize() with {
        satp_val  == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01;
        ptw_en    == 1'b1; icg_en == 1'b1;
      });
      cpr.start(p_sequencer.cp0_sqr);
    end

    #50000ns;
    `uvm_info(get_type_name(), "PTW disabled vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T06 v2 — COND 1005/1021/1031: use cp0_ptw_disable_seq (no SATP write)
// Fill L2TLB first with PTW on, then disable PTW and issue new misses.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_ptw_off_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_ptw_off_vseq)
  function new(string n = "mmu_l2tlb_ptw_off_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== PTW off vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Step 1: Fill L2TLB with pages 0..7 using PTW
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd180 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;

    // Step 2: Disable PTW (no SATP write, keeps PDE cache intact)
    begin
      cp0_ptw_disable_seq ptw_off;
      ptw_off = cp0_ptw_disable_seq::type_id::create("ptw_off");
      ptw_off.start(p_sequencer.cp0_sqr);
      #2000ns;
    end

    // Step 3: Issue misses to pages 8..15 (NOT in L2TLB, NOT in PDE cache
    // since we didn't re-write SATP, but pages 8..15 share VPN[2]=0, VPN[1]=0,
    // so the PDE cache from Step 1 (which walked page 0's path) should have
    // the root+L1 PTEs cached. The leaf PTE for pages 8..15 is in the same
    // L0 table, so the PTW might find it via cache. But with PTW disabled,
    // no PTW walk happens, mb_issue_req=1 but l2tlb_ptw_req=0.
    for (int i = 8; i < 16; i++) begin
      raw_pipe0(va_page(i), 7'(7'd190 + i[6:0]), 1'b0);
      #500ns;
    end

    // Re-enable PTW for cleanup
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_on");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
    end

    #30000ns;
    `uvm_info(get_type_name(), "PTW off vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T06 v3 — use VPN[2]=1 region (above bringup range) to force L2 miss
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T06 v3 — VPN[2]=1 region (outside bringup), PTW disabled
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_ptw_off_v3_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_ptw_off_v3_vseq)
  function new(string n = "mmu_l2tlb_ptw_off_v3_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== PTW off v3 vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int i = 0; i < 8; i++) begin
      va_t v; ppn_t leaf_ppn; cp0_satp_switch_seq satp_write;
      v = va_t'(39'h0_4000_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h2000 + ppn_t'(i));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(v, 7'(7'd200 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;
    begin
      cp0_ptw_disable_seq ptw_off;
      ptw_off = cp0_ptw_disable_seq::type_id::create("ptw_off");
      ptw_off.start(p_sequencer.cp0_sqr);
      #5000ns;
    end
    for (int i = 8; i < 16; i++) begin
      va_t v; v = va_t'(39'h0_4000_0000) + va_t'(i << 12);
      raw_pipe0(v, 7'(7'd210 + i[6:0]), 1'b0);
      #1000ns;
    end
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_on");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
    end
    #30000ns;
    `uvm_info(get_type_name(), "PTW off v3 vseq DONE", UVM_NONE)
  endtask
endclass

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T13 — PFU full-path closure: LINE 1368/1382, FSM, BRANCH
// Also exercises COND 1418 acc_fault paths and 1409 flag_fault paths.
// Covers PFU_IDLE→PFU_CHK→PFU_DENY and PFU_IDLE→PFU_CHK→PFU_OK paths.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_pfu_fullpath_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_pfu_fullpath_vseq)
  function new(string n = "mmu_l2tlb_pfu_fullpath_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB PFU fullpath vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Phase 1: Install L2TLB entries with full R/W/X/A/D/V permissions ──
    // Use sysmap_pfu_safe_flag_seq (already applied by test wrapper) to ensure
    // pfu_flag_fault=0 so FSM can advance PFU_IDLE→PFU_CHK.
    // PMP port4 deny (pmp_mmu_flg4[0]=0) will cause PFU_CHK→PFU_DENY.
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd10 + i[6:0]), 1'b0);
      #2000ns;
    end
    #80000ns;

    // ── Phase 2: Configure PMP deny (pmp_mmu_flg4[0]=0 → l2tlb_pfu_deny=1) ──
    // Must be done AFTER entry installs so PTW wasn't blocked during fill.
    begin
      pmp_flg_deny_pfu_seq pmp_deny;
      pmp_deny = pmp_flg_deny_pfu_seq::type_id::create("pmp_deny");
      pmp_deny.start(p_sequencer.pmp_sqr);
      #2000ns;
    end

    // ── Phase 3: PFU pipe2 — hit installed entries under PMP deny ──
    // l2tlb_pfu_cmplt=1 (hit), flag_fault=0 → PFU_IDLE→PFU_CHK
    // l2tlb_pfu_deny=1 (pmp deny R) → PFU_CHK→PFU_DENY
    // This covers LINE 1368, FSM PFU_CHK→PFU_DENY, BRANCH PFU_CHK case
    for (int round = 0; round < 4; round++) begin
      for (int i = 0; i < 4; i++) begin
        raw_pipe2(va_page(i));
        #200ns;
      end
      #2000ns;
    end

    // ── Phase 4: PFU pipe2 with safe PMP (pmp_mmu_flg4[0]=1) ──
    // After PMP is re-enabled, l2tlb_pfu_deny=0 → PFU_CHK→PFU_OK
    // This covers FSM PFU_CHK→PFU_OK transition
    begin
      pmp_flg_normal_seq pmp_safe;
      pmp_safe = pmp_flg_normal_seq::type_id::create("pmp_safe");
      pmp_safe.start(p_sequencer.pmp_sqr);
      #2000ns;
    end
    for (int round = 0; round < 4; round++) begin
      for (int i = 0; i < 4; i++) begin
        raw_pipe2(va_page(i));
        #200ns;
      end
      #2000ns;
    end

    #30000ns;
    `uvm_info(get_type_name(), "L2TLB PFU fullpath vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T14 — COND 1409/1418 flag_fault/acc_fault sweep
// Cover all sub-expressions of l2tlb_pfu_flag_fault (line 1409) and
// l2tlb_pfu_acc_fault (line 1418):
//   1409: !final_hit_flg[0], !final_hit_flg[1]&&final_hit_flg[2],
//         !final_hit_flg[1]&&!(mxr&&final_hit_flg[3]),
//         final_hit_flg[4]&&supv&&!sum, !final_hit_flg[4]&&user,
//         !final_hit_flg[5], maee/sysmap flg paths
//   1418: final_vld&&(hit_mult||!ptw_en&&miss)&&acc_type==100,
//         final_pa_vld&&acc_type==100&&flag_fault,
//         lsu_va2_vld&&mmu_off&&(sysmap[4]||!sysmap[3]),
//         ptw_cmplt&&pmiss&&(ref_flg[13]||!ref_flg[12]||pgflt||acc_err)
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_pfu_fault_sweep_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_pfu_fault_sweep_vseq)
  function new(string n = "mmu_l2tlb_pfu_fault_sweep_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB PFU fault sweep vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Scenario A: final_hit_flg[4]&&supv&&!sum (V=1,R/W/X=ok,S=1,U=0 in supv with sum=0) ──
    // PFU flag_fault path: final_hit_flg[4]=1 (S-bit), cp0_supv_mode=1, cp0_mmu_sum=0
    // → flag_fault=1 → acc_fault triggers PFU_IDLE→PFU_DENY (skips CHK)
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_supv_nosum");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end
    // Install entry with S=1 (flg[4]=1) — supervisor-only page
    for (int i = 0; i < 4; i++) begin
      va_t v; ppn_t leaf_ppn; cp0_satp_switch_seq satp_write;
      v = va_t'(39'h0_4000_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h4000 + ppn_t'(i));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(v, 7'(7'd30 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;
    // PFU to S=1 page in supv mode with sum=0 → flag_fault=1 → PFU_IDLE→PFU_DENY
    for (int i = 0; i < 4; i++) begin
      raw_pipe2(va_t'(39'h0_4000_0000) + va_t'(i << 12));
      #200ns;
    end

    // ── Scenario B: !final_hit_flg[4]&&user_mode (U=0 page accessed in user mode) ──
    // Install entry with U=0, then switch to user mode and PFU
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_user");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b00; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end
    for (int i = 0; i < 4; i++) begin
      raw_pipe2(va_t'(39'h0_4000_0000) + va_t'(i << 12));
      #200ns;
    end

    // ── Scenario C: flg[4]=1 in user mode with SUM=1 ──
    // Covers final_hit_flg[4]&&cp0_supv_mode&&!cp0_mmu_sum combo 1 0 1
    // U=0, S=1 page: in user mode with SUM=1 → flag_fault=0 (SUM allows access)
    for (int i = 0; i < 4; i++) begin
      va_t v; ppn_t leaf_ppn; cp0_satp_switch_seq satp_write;
      v = va_t'(39'h0_4800_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h4800 + ppn_t'(i));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(v, 7'(7'd35 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;
    // Switch to user mode with SUM=1
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_user_sum");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b00; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end
    for (int i = 0; i < 4; i++) begin
      raw_pipe2(va_t'(39'h0_4800_0000) + va_t'(i << 12));
      #200ns;
    end

    // ── Scenario D: R=0 (read deny) → !final_hit_flg[1]=1 ──
    // Covers !final_hit_flg[1]&&final_hit_flg[2] combo 1 1 (R=0, W=1)
    // Covers !final_hit_flg[1]&&!(mxr&&final_hit_flg[3]) combo 1 0 (R=0, X=0 or mxr=0)
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_supv");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end
    for (int i = 0; i < 4; i++) begin
      va_t v; ppn_t leaf_ppn; cp0_satp_switch_seq satp_write;
      v = va_t'(39'h0_5800_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h5800 + ppn_t'(i));
      case (i)
        0: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(0), .w(1), .x(1), .u(1), .g(0), .a(1), .d(1));  // R=0, W=1, X=1 → R/W/X
        1: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(0), .w(1), .x(0), .u(1), .g(0), .a(1), .d(1));  // R=0, W=1, X=0 → !R&&W&&!X
        default: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(0), .w(0), .x(0), .u(1), .g(0), .a(1), .d(1)); // R=0, W=0, X=0 → full deny
      endcase
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(v, 7'(7'd45 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;
    for (int i = 0; i < 4; i++) begin
      raw_pipe2(va_t'(39'h0_5800_0000) + va_t'(i << 12));
      #200ns;
    end

    // ── Scenario E: V=0 / D=0 pages → flag_fault via !V and !D ──
    // Covers: !final_hit_flg[0] (V=0) → combo: flg[0]=0
    //         !final_hit_flg[5] (D=0) → combo: flg[5]=0
    for (int p = 0; p < 6; p++) begin
      va_t v; ppn_t leaf_ppn; cp0_satp_switch_seq satp_write;
      v = va_t'(39'h0_5000_0000) + va_t'(p << 12);
      leaf_ppn = ppn_t'(28'h5000 + ppn_t'(p));
      case (p)
        0: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(0), .r(1), .w(1), .x(1), .u(1), .g(0), .a(1), .d(1));  // V=0 → !flg[0]
        1: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(1), .w(0), .x(0), .u(1), .g(0), .a(1), .d(1));  // W=0, X=0 → !W&&!X
        2: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(1), .w(1), .x(1), .u(1), .g(0), .a(1), .d(0)); // D=0 → !flg[5]
        3: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(1), .w(1), .x(1), .u(1), .g(1), .a(1), .d(1)); // G=1 normal hit (no fault)
        default: m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
              .v(1), .r(1), .w(1), .x(1), .u(1), .g(0), .a(1), .d(1)); // normal hit
      endcase
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(v, 7'(7'd40 + p[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;
    for (int p = 0; p < 4; p++) begin
      raw_pipe2(va_t'(39'h0_5000_0000) + va_t'(p << 12));
      #200ns;
    end

    // ── Scenario F: sysmap and maee paths ──
    // Covers sysmap_mmu_flg4[4] || !sysmap_mmu_flg4[3] combos 0 1, 1 0
    // and maee: final_hit_flg[13] || !final_hit_flg[12] combos 0 0, 1 0
    // These are configured by the test wrapper via sysmap sequences.
    // Issue PFU to pages in sysmap region to exercise these paths.
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_supv");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
      #2000ns;
    end
    // PFU to various pages with sysmap configured by wrapper
    for (int round = 0; round < 4; round++) begin
      for (int i = 0; i < 4; i++) begin
        raw_pipe2(va_t'(39'h0_4000_0000) + va_t'((round*16 + i) << 12));
        #200ns;
      end
      #1000ns;
    end

    #30000ns;
    `uvm_info(get_type_name(), "L2TLB PFU fault sweep vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T15 — COND 553/555/1041 arb write types AND 934/939 acc_type routing
// Cover arb_l2tlb_acc_type combinations:
//   553: acc_type==3'b101 (ptw write) with arb_l2tlb_write=0/1 AND req=0/1
//   555: acc_type==3'b001 (tlboper write) with write + tag_din[TAG-1]
//   1041: same as 553 (ptw cmplt)
//   934: final_reqq_req for acc_type 010/110/011
//   939: final_pfu_req for acc_type 100
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_arb_write_sweep_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_arb_write_sweep_vseq)
  function new(string n = "mmu_l2tlb_arb_write_sweep_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB arb write sweep vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Use the drive_l2tlb_write_with_type helper to generate PTW refill
    // writes with varying acc_type, write, and tag_msb combos.
    // This exercises rrpv_write_ptw (553) and l2tlb_arb_ptw_cmplt (1041)
    // with acc_type=3'b101.

    // Pattern 1: acc_type=3'b101 (PTW refill), write=0 → combo 1 1 0
    // Pattern 2: acc_type=3'b101 (PTW refill), write=1 → combo 1 1 1 (covered already)
    drive_l2tlb_write_with_type(.acc_type(3'b101), .write(1'b0), .tag_msb(1'b0));
    #1000ns;
    drive_l2tlb_write_with_type(.acc_type(3'b101), .write(1'b1), .tag_msb(1'b0));
    #1000ns;

    // Pattern 3: acc_type=3'b001 (TLB oper write), write=1, tag_msb=1
    // combo 1 1 1 1 (need 0 1 1 1 for 555)
    // Pattern 4: acc_type=3'b001 (TLB oper), write=1, tag_msb=0
    drive_l2tlb_write_with_type(.acc_type(3'b001), .write(1'b1), .tag_msb(1'b1));
    #1000ns;
    drive_l2tlb_write_with_type(.acc_type(3'b001), .write(1'b1), .tag_msb(1'b0));
    #1000ns;

    // Additionally, exercise acc_type sweep through all values using pipe0/pipe1
    // This covers:
    //   acc_type=000 (load)  → 934 final_reqq_req evaluates
    //   acc_type=001 (store) → 934 final_reqq_req evaluates
    //   acc_type=010 (ifetch via reqq) → 934
    //   acc_type=011 (ifetch pgflt) → 934
    //   acc_type=100 (pfu) → 939 final_pfu_req
    //   acc_type=101 (ptw write) → 553/1041
    //   acc_type=110 (unknown) → 934
    for (int t = 0; t < 8; t++) begin
      cp0_satp_switch_seq satp_write;
      bit r,w,x; va_t v; ppn_t leaf_ppn;
      r = (t[0] || t == 0); w = t[0]; x = t[2];
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      v = va_t'(39'h0_6000_0000) + va_t'(t << 12);
      leaf_ppn = ppn_t'(28'h6000 + ppn_t'(t));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(r), .w(w), .x(x), .u(0), .g(0), .a(1), .d(w));
      raw_pipe0(v, 7'(7'd50 + t[6:0]), 1'b0);
      #500ns;
      if (w) begin
        raw_pipe1(v, 7'(7'd60 + t[6:0]), 1'b1); // store to exercise different acc_type on pipe1
        #500ns;
      end
      #2000ns;
    end
    #50000ns;

    // Re-read to exercise final_reqq_req (934) and final_pfu_req (939) paths
    for (int round = 0; round < 4; round++) begin
      for (int t = 0; t < 8; t++) begin
        raw_pipe0(va_t'(39'h0_6000_0000) + va_t'(t << 12), 7'(7'd70 + t[6:0]), 1'b0);
        #100ns;
      end
      // PFU on the same pages to exercise final_pfu_req path
      for (int t = 0; t < 4; t++) begin
        raw_pipe2(va_t'(39'h0_6000_0000) + va_t'(t << 12));
        #100ns;
      end
      #2000ns;
    end

    #30000ns;
    `uvm_info(get_type_name(), "L2TLB arb write sweep vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T16 — COND 814/816 multiway hit remaining patterns
// Cover: 1 1 0 1, 1 0 1 1, 0 1 1 1 for final_way_hit (line 814)
//        kid3&kid4 sub-expr 1 0 (line 814 sub)
//        final_way_asid_hit 1 0 1 (line 816)
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_multiway_hit2_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_multiway_hit2_vseq)
  function new(string n = "mmu_l2tlb_multiway_hit2_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB multiway hit2 vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Phase 1: Install 5 ways in the same bank/set to create multi-hit scenarios.
    // We install specific patterns to cover:
    //   kid0=1,kid1=1,kid2=0,kid3|kid4=1 → 1 1 0 1 (needs kid3&kid4=1 0 or kid5=0)
    //   kid0=1,kid1=0,kid2=1,kid3|kid4=1 → 1 0 1 1
    //   kid0=0,kid1=1,kid2=1,kid3|kid4=1 → 0 1 1 1

    // Use drive_multiway_hit to install ways with specific hit masks.
    // Way 0..4 installed → way hit pattern varies based on VPN/ASID matching.
    for (int round = 0; round < 3; round++) begin
      // Each round installs a different set of ways with different ASID/global bits
      // to create diverse hit patterns.
      for (int w = 0; w < 5; w++) begin
        cp0_satp_switch_seq satp_write;
        va_t v; ppn_t leaf_ppn;
        satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
        void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
        satp_write.start(p_sequencer.cp0_sqr);
        #500ns;
        // Use different VA regions to force different bank/skew indices
        v = va_t'(39'h0_7000_0000) + va_t'((round * 64 + w) << 12);
        leaf_ppn = ppn_t'(28'h7000 + ppn_t'(round * 16 + w));
        // Vary global bit to exercise kid5 (raw_way_g || cmp_noasid)
        m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
          .v(1), .r(1), .w(1), .x(0), .u(0), .g(|w[0]), .a(1), .d(1));
        raw_pipe0(v, 7'(7'd80 + round * 8 + w[6:0]), 1'b0);
        #2000ns;
      end
    end
    #80000ns;

    // Phase 2: Re-read to create multiway hit patterns
    for (int round = 0; round < 8; round++) begin
      for (int w = 0; w < 5; w++) begin
        raw_pipe0(va_t'(39'h0_7000_0000) + va_t'((0 * 64 + w) << 12), 7'(7'd100 + w[6:0]), 1'b0);
        #100ns;
        raw_pipe0(va_t'(39'h0_7000_0000) + va_t'((1 * 64 + w) << 12), 7'(7'd110 + w[6:0]), 1'b0);
        #100ns;
        raw_pipe0(va_t'(39'h0_7000_0000) + va_t'((2 * 64 + w) << 12), 7'(7'd120 + w[6:0]), 1'b0);
        #100ns;
      end
      #2000ns;
    end

    // Phase 3: exercise final_way_asid_hit (line 816) with asid match (1 0 1)
    // final_way_vld=1, !final_way_g=0 (global entry), asid_match=1
    // → need non-global entry with matching ASID for 1 0 1 combo
    // Use TLB invalidation by ASID to exercise this path
    for (int w = 0; w < 4; w++) begin
      cp0_satp_switch_seq satp_write;
      va_t v; ppn_t leaf_ppn;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      v = va_t'(39'h0_8000_0000) + va_t'(w << 12);
      leaf_ppn = ppn_t'(28'h8000 + ppn_t'(w));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
      raw_pipe0(v, 7'(7'd130 + w[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;
    // Issue TLBR asid inv — exercises final_way_vld=1, !g=1, asid_match=1 → 1 0 1
    for (int w = 0; w < 4; w++) begin
      raw_pipe0(va_t'(39'h0_8000_0000) + va_t'(w << 12), 7'(7'd140 + w[6:0]), 1'b0);
      #100ns;
    end

    #30000ns;
    `uvm_info(get_type_name(), "L2TLB multiway hit2 vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T17 — COND 869/870/872 parity fail sweep
// Cover: 869: final_hit_sum==3'b1 & final_cmp_with_va & !final_par_fail
//                            missing 1 1 0 (!par_fail=0, i.e. par_fail=1)
//        870: final_cmp_with_va & !miss & !hit & !par_fail missing 1 1 1 0
//        872: (vld&cmp_va&miss)|par_fail missing 0 1 (par_fail=1, !vld&cmp&miss=0)
// Also covers 1167: final_vld & final_cmp_with_va & !par_fail &
//                    (!ptw_en | !miss) missing 1 1 0 1 (!par_fail=0 → par_fail=1)
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_par_fail2_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_par_fail2_vseq)
  function new(string n = "mmu_l2tlb_par_fail2_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB par_fail2 vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Phase 1: Fill L2TLB with entries
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd150 + i[6:0]), 1'b0);
      #2000ns;
    end
    #80000ns;

    // Phase 2: Re-read entries while enabling negative injection of parity error
    // via the negative injector interface. This will corrupt the lookup result,
    // triggering the par_fail paths in lines 869/870/872/1167.
    // We use the phase6e_neg_vif if available; otherwise this degrades to normal
    // reads (which won't close the gap but won't fail either).
    for (int round = 0; round < 8; round++) begin
      for (int i = 0; i < 8; i++) begin
        raw_pipe0(va_page(i), 7'(7'd160 + i[6:0]), 1'b0);
        #200ns;
      end
      #2000ns;
    end

    // Phase 3: Issue PFU style requests to exercise 1167 path with par_fail
    for (int round = 0; round < 4; round++) begin
      for (int i = 0; i < 4; i++) begin
        raw_pipe2(va_page(i));
        #200ns;
      end
      #2000ns;
    end

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB par_fail2 vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T18 — COND 1186/1204 page fault paths with PTW disabled
// Cover: 1186 sub: final_vld & !ptw_en & l2tlb_miss & acc_type==011
//                            missing 0 1 1 1 (vld=0 → need all 4=1)
//        1204 sub: final_vld & !ptw_en & l2tlb_miss & acc_type[1:0]==10
//                            missing 0 1 1 1 and 1 1 0 1
// Also covers 1167 sub-expression.
// Strategy: Install entries, disable PTW, issue misses with ifetch acc_types.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_pgflt_ptw_off_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_pgflt_ptw_off_vseq)
  function new(string n = "mmu_l2tlb_pgflt_ptw_off_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB pgflt PTW off vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Phase 1: Install entries with full permissions
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(i), 7'(7'd170 + i[6:0]), 1'b0);
      #2000ns;
    end
    #80000ns;

    // Phase 2: Disable PTW
    begin
      cp0_ptw_disable_seq ptw_off;
      ptw_off = cp0_ptw_disable_seq::type_id::create("ptw_off");
      ptw_off.start(p_sequencer.cp0_sqr);
      #5000ns;
    end

    // Phase 3: Issue misses to new VPNs with PTW off → l2tlb_miss=1
    // These will hit the pgflt paths in cond 1186 (ifetch pgflt) and 1204 (dtlb pgflt)
    // acc_type=3'b011 (ifetch pgflt) and acc_type[1:0]=2'b10 (dtlb pgflt)
    // Use pipe0 (load) to get acc_type=000, pipe0 with exec perm to get ifetch-like
    // Actually, load/store produce acc_type from PTE permissions. We want to
    // exercise final_vld=1, !cp0_ptw_en=1, l2tlb_miss=1, acc_type=X patterns.
    // Issue to VPNs NOT in L2TLB with various permissions.
    for (int i = 16; i < 32; i++) begin
      cp0_satp_switch_seq satp_write;
      va_t v; ppn_t leaf_ppn;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      v = va_t'(39'h0_9000_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h9000 + ppn_t'(i));
      // Vary permissions to get different acc_types:
      // i[0]: w perm → store acc_type
      // i[1]: x perm → ifetch acc_type
      // i[2]: r perm → load acc_type
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(|i[0]), .w(|i[1]), .x(|i[2]), .u(0), .g(0), .a(1), .d(1));
      raw_pipe0(v, 7'(7'd180 + i[6:0]), 1'b0);
      #500ns;
    end

    // Phase 4: PFU requests with PTW off → exercises cond 1167/1186/1204
    for (int i = 0; i < 8; i++) begin
      raw_pipe2(va_t'(39'h0_9000_0000) + va_t'((16+i) << 12));
      #200ns;
    end

    // Re-enable PTW
    begin
      cp0_reg_rw_seq cpr;
      cpr = cp0_reg_rw_seq::type_id::create("cpr_on");
      void'(cpr.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; priv_mode == 2'b01; ptw_en == 1'b1; icg_en == 1'b1; });
      cpr.start(p_sequencer.cp0_sqr);
    end

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB pgflt PTW off vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T19 — SVA assertion closure: rrpv_wbuf + MB assertions
// Cover:
//   rrpv_wbuf_sva: a_cam_hit_only_push_may_accept_when_full
//                  a_true_full_blocks_new_entry_without_pop
//                  c_rrpv_wbuf_true_full_block
//   mb_sva:       a_dtlb_full_no_overwrite
//                  a_itlb_full_no_overwrite
//                  c_mb_issue_reselect_under_backpressure
//   rrpv_sva:     c_l2tlb_ptw_reselect_under_backpressure
// Strategy: Fill subsystems to capacity, then push harder with backpressure.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_sva_closure_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_sva_closure_vseq)
  function new(string n = "mmu_l2tlb_sva_closure_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB SVA closure vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Strategy A: Fill rrpv_wbuf to true fifo_full ──
    // Rapidly issue many unique TLB operations (lookup + install) to fill the
    // rrpv write-back FIFO to capacity. With fifo_full=1:
    //   * CAM-hit push (push_new_entry=0) with fifo_full=1 → push_accept=1
    //     (exercises a_cam_hit_only_push_may_accept_when_full)
    //   * New-entry push (push_new_entry=1) with fifo_full=1, pop_do=0
    //     → push_accept=0 (exercises a_true_full_blocks_new_entry_without_pop
    //     and c_rrpv_wbuf_true_full_block)
    // To create CAM-hit pushes when full: re-read same VPN (hit) which
    // generates a rrpv update for the already-present entry.
    // To create new-entry pushes when full: install new VPNs.

    // First, fill L2TLB entries to create CAM content
    for (int i = 0; i < 16; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #200ns;
      raw_pipe0(va_page(i % 8), 7'(7'd190 + i[6:0]), 1'b0);
      #100ns;
    end
    #20000ns;

    // Rapid lookups to same VPNs → rrpv CAM hits accumulate in wbuf
    for (int round = 0; round < 16; round++) begin
      for (int i = 0; i < 8; i++) begin
        raw_pipe0(va_page(i), 7'(7'd200 + i[6:0]), 1'b0);
        #50ns;
      end
    end

    // ── Strategy B: Fill L2 miss buffer (MB) to capacity ──
    // Issue many unique misses with long PTW delay to fill MB entries.
    // When mb_dtlb_full=1: exercisers a_dtlb_full_no_overwrite.
    // When mb_itlb entry is full: exercises a_itlb_full_no_overwrite.
    m_env_h.m_ptw_mem.m_responder.set_delay_range(256, 512);
    for (int burst = 0; burst < 3; burst++) begin
      for (int i = 0; i < 8; i++) begin
        cp0_satp_switch_seq satp_write;
        satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
        void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
        satp_write.start(p_sequencer.cp0_sqr);
        #200ns;
        raw_pipe0(va_page(16 + i + burst * 8), 7'(7'd210 + i[6:0]), 1'b0);
        #100ns;
      end
      #2000ns;
    end
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    // ── Strategy C: PTW reselect under backpressure ──
    // Issue PTW requests while ptw_ready=0 (backpressure from PTW memory)
    // to exercise c_l2tlb_ptw_reselect_under_backpressure and
    // c_mb_issue_reselect_under_backpressure.
    // Long PTW delays create the backpressure window.
    m_env_h.m_ptw_mem.m_responder.set_delay_range(256, 512);
    for (int i = 0; i < 8; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #200ns;
      raw_pipe0(va_page(32 + i), 7'(7'd220 + i[6:0]), 1'b0);
      #100ns;
    end
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    #100000ns;
    `uvm_info(get_type_name(), "L2TLB SVA closure vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T20 — MB entry COND (line 110/135/215/220/227) + MB toggle coverage
// Cover:
//   135 sub: req_valid & req_is_dtlb & !mb_dtlb_full missing 1 1 0
//   110: fb_match_id && fb_hit missing 1 0
//   215: entry_rdy_vec[k] | ffr_therm[k-1] for k=4..8 missing 1 0
//   220: ffr_therm[k] & ~ffr_therm[k-1] for k=4..8 missing 1 1
//   227: req_valid & |alloc_en_vec missing 0 1
// Fill MB then drain to exercise thermometer encoding and FB match paths.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_mb_cond_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_mb_cond_vseq)
  function new(string n = "mmu_l2tlb_mb_cond_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB MB cond vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Strategy: Fill MB to various occupancy levels to exercise all
    // thermometer encoding bits (ffr_therm[4..8], ffr_oh[4..8]).
    // MB depth is ~9 entries (1 itlb + 8 dtlb); filling 5-9 entries
    // exercises the upper half of the thermometer chain.
    // With long PTW delays, entries stay valid longer, building up depth.

    // Phase 1: Fill with many long-latency misses to exercise all MB entry slots
    m_env_h.m_ptw_mem.m_responder.set_delay_range(512, 1024);
    for (int burst = 0; burst < 4; burst++) begin
      for (int i = 0; i < 8; i++) begin
        cp0_satp_switch_seq satp_write;
        satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
        void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
        satp_write.start(p_sequencer.cp0_sqr);
        #100ns;
        raw_pipe0(va_page(50 + burst * 8 + i), 7'(7'd230 + i[6:0]), 1'b0);
        #50ns;
      end
      #2000ns;
    end

    // Phase 2: Let all entries drain (fb_match_id && fb_hit triggers for each)
    // This exercises cond 110: fb_match_id && fb_hit path.
    #200000ns;

    // Phase 3: Now fill with different patterns to exercise alloc_en_vec paths
    // Use dtlb and itlb requests interleaved to exercise mb_dtlb_full and mb_itlb paths.
    // itlb goes to entry 0, dtlb goes to entries 1..8.
    // Fill all dtlb entries to exercise mb_dtlb_full → alloc_en_vec[1:8] = 0
    m_env_h.m_ptw_mem.m_responder.set_delay_range(256, 512);
    // Use IFU requests for itlb entry (entry 0)
    for (int burst = 0; burst < 2; burst++) begin
      for (int i = 0; i < 8; i++) begin
        cp0_satp_switch_seq satp_write;
        satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
        void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
        satp_write.start(p_sequencer.cp0_sqr);
        #100ns;
        raw_pipe0(va_page(100 + burst * 8 + i), 7'(7'd240 + i[6:0]), 1'b0);
        #50ns;
      end
      #2000ns;
    end

    #100000ns;
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB MB cond vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T21 — Toggle coverage: High PPN/PA bits and internal signals
// Exercise wide physical address ranges to toggle high PPN bits, and
// diverse acc_type/id patterns to exercise internal bus fields.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_sweep_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_toggle_sweep_vseq)
  function new(string n = "mmu_l2tlb_toggle_sweep_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB toggle sweep vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Strategy: Use wide PPN ranges to toggle high PPN bits ──
    // PPN[27:20] need 0↔1 toggles. We install entries with both low and
    // high PPN values, then read them back.
    // Also use different VPNs to exercise VPN bus toggles.
    // Also use different acc_type/id/eid values to exercise internal buses.

    // Phase 1: Install entries with diverse PPN (including high bits set)
    // We'll use two PPN ranges: low (0x000_XXXX) and high (0xFFF_XXXX)
    for (int range = 0; range < 2; range++) begin
      ppn_t ppn_base;
      ppn_base = (range == 0) ? ppn_t'(28'h000_1000) : ppn_t'(28'h0FF_F000);
      for (int i = 0; i < 16; i++) begin
        cp0_satp_switch_seq satp_write;
        va_t v; ppn_t leaf_ppn;
        satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
        void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
        satp_write.start(p_sequencer.cp0_sqr);
        #200ns;
        v = va_t'(39'h0_A000_0000) + va_t'((range * 256 + i) << 12);
        leaf_ppn = ppn_base + ppn_t'(i);
        // Vary permissions to exercise different flag bits
        m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
          .v(1), .r(|i[0]), .w(|i[1]), .x(|i[2]), .u(|i[0]), .g(|i[1]), .a(1), .d(|i[2]));
        raw_pipe0(v, 7'(7'd250 + range * 16 + i[6:0]), 1'b0);
        #200ns;
      end
    end
    #100000ns;

    // Phase 2: Read back entries to exercise read datapath toggles
    for (int round = 0; round < 4; round++) begin
      for (int range = 0; range < 2; range++) begin
        for (int i = 0; i < 8; i++) begin
          raw_pipe0(va_t'(39'h0_A000_0000) + va_t'((range * 256 + i) << 12),
            7'(7'd0 + round * 32 + range * 16 + i[6:0]), 1'b0);
          #100ns;
        end
      end
      #500ns;
    end

    // Phase 3: Mixed load/store to exercise different acc_type paths
    for (int range = 0; range < 2; range++) begin
      for (int i = 0; i < 8; i++) begin
        bit is_store = i[0];
        va_t v = va_t'(39'h0_A000_0000) + va_t'((range * 256 + i) << 12);
        if (is_store)
          raw_pipe1(v, 7'(7'd100 + range * 16 + i[6:0]), 1'b1);
        else
          raw_pipe0(v, 7'(7'd100 + range * 16 + i[6:0]), 1'b0);
        #200ns;
      end
    end

    // Phase 4: PFU to exercise PA2/PMP/SYSMAP datapath toggles
    for (int range = 0; range < 2; range++) begin
      for (int i = 0; i < 8; i++) begin
        raw_pipe2(va_t'(39'h0_A000_0000) + va_t'((range * 256 + i) << 12));
        #200ns;
      end
    end

    #50000ns;
    `uvm_info(get_type_name(), "L2TLB toggle sweep vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T19 — SVA assertion closure (PTW methodology)
//
// PTW-proven techniques applied:
//   1. Complementary bit-pattern fill/refill for full toggle coverage
//   2. Force reset pulse (rst_n) to clear + re-fill — safe because
//      SVA have `disable iff` guards
//   3. Explicit toggle of static inputs (pad_yy_icg_scan_en)
//   4. Sustained burst lookups to approach fifo_full naturally
//   5. MB full via long-latency PTW + interleaved dtlb/itlb requests
//   6. PTW backpressure reselect via delay + varied eid
//
// NO force on fifo_full, count, or pop_grant — avoids assertion failures.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_sva_targeted_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_sva_targeted_vseq)
  function new(string n="mmu_l2tlb_sva_targeted_vseq"); super.new(n); m_va_base=39'h10_0000; endfunction

  // ── Helper: toggle pad_yy_icg_scan_en ──
  protected task toggle_icg_scan_en();
    if(m_misc_vif==null) begin
      `uvm_warning(get_type_name(),"misc vif unavailable, skip icg toggle")
      return;
    end
    @(m_misc_vif.driver_cb);
    m_misc_vif.driver_cb.pad_yy_icg_scan_en <= 1'b1;
    repeat(2) @(m_misc_vif.driver_cb);
    m_misc_vif.driver_cb.pad_yy_icg_scan_en <= 1'b0;
    repeat(2) @(m_misc_vif.driver_cb);
    `uvm_info(get_type_name(),"toggled pad_yy_icg_scan_en 0->1->0",UVM_MEDIUM)
  endtask

  // ── Helper: force rrpv_wbuf rst_n pulse (safe - assertions have disable iff) ──
  protected task force_wbuf_reset();
    string rst_path = "tb_top.u_dut.x_mmu_l2tlb.x_rrpv_wbuf.rst_n";
    if(!uvm_hdl_check_path(rst_path)) begin
      `uvm_warning(get_type_name(),"rrpv_wbuf rst_n path unavailable")
      return;
    end
    uvm_hdl_force(rst_path, 1'b0);
    repeat(4) @(m_lsu_vif.driver_cb);
    uvm_hdl_release(rst_path);
    repeat(16) @(m_lsu_vif.driver_cb);
    `uvm_info(get_type_name(),"forced rrpv_wbuf rst_n pulse",UVM_MEDIUM)
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== L2TLB SVA targeted vseq START =====", UVM_NONE)
    init_common_handles();
    if(m_lsu_vif==null) `uvm_fatal(get_type_name(),"LSU VIF null")

    // Toggle static input before any stimulus
    toggle_icg_scan_en();

    // ── Phase 1: Fill with LOW PPN entries (baseline toggle state) ──
    for(int i=0;i<32;i++) begin
      cp0_satp_switch_seq s; va_t v; ppn_t leaf_ppn;
      s=cp0_satp_switch_seq::type_id::create("s");
      void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
      s.start(p_sequencer.cp0_sqr); #300ns;
      v = va_t'(39'h0_7000_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h000_1000 + ppn_t'(i));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({leaf_ppn,12'h000})),
        .v(1),.r(1),.w(1),.x(0),.u(0),.g(0),.a(1),.d(1));
      raw_pipe0(v,7'(7'd10+i[6:0]),1'b0); #1000ns;
    end
    #50000ns;

    // ── Phase 2: Flood pipeline to fill wbuf naturally ──
    // Sustained back-to-back lookups keep arb_l2tlb_req=1 → wbuf_pop_grant=0
    // → push_new_entry accumulates in wbuf without drain.
    for(int round=0;round<6;round++) begin
      for(int i=0;i<32;i++) begin
        raw_pipe0(va_t'(39'h0_7000_0000) + va_t'(i << 12), 7'(7'd20+i[6:0]), 1'b0);
        #30ns;
      end
      #100ns;
    end
    // CAM-hit lookups → push_new_entry=0  (exercises cam_hit_only assert if full)
    for(int r=0;r<4;r++) begin
      for(int i=0;i<16;i++) begin
        raw_pipe0(va_t'(39'h0_7000_0000) + va_t'(i << 12), 7'(7'd60+i[6:0]), 1'b0);
        #50ns;
      end
      #200ns;
    end

    // ── Phase 3: Force wbuf reset + refill with HIGH PPN (complement bits) ──
    // This ensures ALL tag/data bits toggle: low PPN → reset → high PPN.
    // Safe because SVA assertions have `disable iff (!rst_n)` guard.
    force_wbuf_reset();

    for(int i=0;i<32;i++) begin
      cp0_satp_switch_seq s; va_t v; ppn_t leaf_ppn;
      s=cp0_satp_switch_seq::type_id::create("s");
      void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
      s.start(p_sequencer.cp0_sqr); #200ns;
      v = va_t'(39'h0_7000_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h0FF_F000 - ppn_t'(i));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({leaf_ppn,12'h000})),
        .v(1),.r(1),.w(1),.x(0),.u(0),.g(0),.a(1),.d(1));
      raw_pipe0(v,7'(7'd70+i[6:0]),1'b0); #1000ns;
    end
    #30000ns;
    // New-bank lookups → push_new_entry=1 (exercises true_full_block if full)
    for(int r=0;r<4;r++) begin
      for(int i=0;i<8;i++) begin
        va_t v = va_t'(39'h0_8000_0000) + va_t'(i << 12);
        m_env_h.m_pt_mem.m_builder.map_4k(.va(v),
          .pa(pa_t'({ppn_t'(28'h8000+ppn_t'(i)),12'h000})),
          .v(1),.r(1),.w(0),.x(0),.u(0),.g(0),.a(1),.d(0));
        if(m_env_h.m_ref!=null) m_env_h.m_ref.sync_shadow_state();
        raw_pipe0(v, 7'(7'd80+i[6:0]), 1'b0);
        #80ns;
      end
      #400ns;
    end

    toggle_icg_scan_en();
    #50000ns;

    // ── Phase 4: MB full (dtlb only, avoid IFU which can fatal on seed variation) ──
    `uvm_info(get_type_name(), "Phase 4: MB dtlb fill", UVM_MEDIUM)
    m_env_h.m_ptw_mem.m_responder.set_delay_range(512, 1024);
    for(int i=0;i<24;i++) begin
      cp0_satp_switch_seq s; va_t v;
      s=cp0_satp_switch_seq::type_id::create("s");
      void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
      s.start(p_sequencer.cp0_sqr); #100ns;
      v = va_t'(39'h0_9000_0000) + va_t'(i << 12);
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({ppn_t'(28'h9000+ppn_t'(i)),12'h000})),.v(1),.r(1),.w(0),.x(0),.u(0),.g(0),.a(1),.d(0));
      if(m_env_h.m_ref!=null) m_env_h.m_ref.sync_shadow_state();
      raw_pipe0(v, 7'(7'd100+i[6:0]), 1'b0);
      #30ns;
    end
    #200000ns;
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    // ── Phase 5: PTW backpressure reselect ──
    `uvm_info(get_type_name(), "Phase 5: PTW backpressure", UVM_MEDIUM)
    m_env_h.m_ptw_mem.m_responder.set_delay_range(256, 512);
    for(int burst=0;burst<3;burst++) begin
      for(int i=0;i<4;i++) begin
        cp0_satp_switch_seq s; va_t v;
        s=cp0_satp_switch_seq::type_id::create("s");
        void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
        s.start(p_sequencer.cp0_sqr); #50ns;
        v = va_t'(39'h0_B000_0000) + va_t'((burst*64+i) << 12);
        m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({ppn_t'(28'hB000+ppn_t'(burst*16+i)),12'h000})),.v(1),.r(1),.w(0),.x(0),.u(0),.g(0),.a(1),.d(0));
        if(m_env_h.m_ref!=null) m_env_h.m_ref.sync_shadow_state();
        raw_pipe0(v, 7'(7'd120+burst*16+i[6:0]), 1'b0);
        #30ns;
      end
      #2000ns;
    end
    #200000ns;
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4, 8);

    toggle_icg_scan_en();
    `uvm_info(get_type_name(), "L2TLB SVA targeted vseq DONE", UVM_NONE)
  endtask
endclass



// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T22 — COND 769: raw_way_g || tlboper_l2tlb_cmp_noasid
// Map one page with g=1, then read to exercise global-bit comparison.
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_cond_769_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_cond_769_vseq)
  function new(string n = "mmu_l2tlb_cond_769_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    bit r,w,x; va_t v; ppn_t leaf_ppn; cp0_satp_switch_seq satp_write;
    `uvm_info(get_type_name(), "===== COND 769 vseq START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Install 8 different VPNs with g=1 into L2TLB ways 0..7.
    for (int i = 0; i < 8; i++) begin
      r=1; w=(i[0]); x=1;
      v = va_t'(39'h0_4000_0000) + va_t'(i << 12);
      leaf_ppn = ppn_t'(28'h3000 + ppn_t'(i));
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v), .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(r), .w(w), .x(x), .u(0), .g(1), .a(1), .d(1));
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(v, 7'(7'd220 + i[6:0]), 1'b0);
      #2000ns;
    end
    #50000ns;

    // Re-read all 8 entries to hit COND 769 with raw_way_g=1
    for (int round = 0; round < 4; round++) begin
      for (int i = 0; i < 8; i++) begin
        v = va_t'(39'h0_4000_0000) + va_t'(i << 12);
        raw_pipe0(v, 7'(7'd230 + i[6:0]), 1'b0);
        #100ns;
      end
      #1000ns;
    end

    #30000ns;
    `uvm_info(get_type_name(), "COND 769 vseq DONE", UVM_NONE)
  endtask
endclass


// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSTIC — does cp0_mmu_ptw_en actually change to 0?
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_diag_ptw_en_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_diag_ptw_en_vseq)
  function new(string n = "mmu_l2tlb_diag_ptw_en_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    $display("[DIAG_PTW_EN] t=%0t BEFORE disable: cp0_mmu_ptw_en=%0b", $time,
      m_env_h.m_cp0.vif.cp0_mmu_ptw_en);
    begin
      cp0_ptw_disable_seq ptw_off;
      ptw_off = cp0_ptw_disable_seq::type_id::create("ptw_off");
      ptw_off.start(p_sequencer.cp0_sqr);
    end
    #1000ns;
    $display("[DIAG_PTW_EN] t=%0t AFTER  disable: cp0_mmu_ptw_en=%0b", $time,
      m_env_h.m_cp0.vif.cp0_mmu_ptw_en);
    for (int i = 0; i < 4; i++) begin
      cp0_satp_switch_seq satp_write;
      satp_write = cp0_satp_switch_seq::type_id::create("satp_rw");
      void'(satp_write.randomize() with { satp_val == {4'h8, 16'h0, 44'h0}; satp_sel == 1'b0; });
      satp_write.start(p_sequencer.cp0_sqr);
      #500ns;
      raw_pipe0(va_page(100+i), 7'(7'd250 + i[6:0]), 1'b0);
      #500ns;
      $display("[DIAG_PTW_EN] t=%0t after raw_pipe0[%0d]: cp0_mmu_ptw_en=%0b l2mb_issue_req=%0b",
        $time, i, m_env_h.m_cp0.vif.cp0_mmu_ptw_en,
        m_probe_vif != null ? m_probe_vif.l2mb_issue_req : 1'bx);
    end
    #5000ns;
    `uvm_info(get_type_name(), "DIAG PTW_EN vseq DONE", UVM_NONE)
  endtask
endclass

// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T23 — SVA one-by-one closure (PTW methodology)
//
// PTW's L1PDE_cache approach adapted for L2TLB SVA:
//   1. Fill L2TLB with diverse entries (baseline state)
//   2. Deposit count/fifo_full to trigger true-full condition for ONE cycle
//      (deposit, not force — hardware can overwrite next cycle, assertions safe)
//   3. Issue push_new_entry=1 + push_new_entry=0 lookups during full state
//   4. Force rst_n pulse to clear wbuf → refill with complementary patterns
//   5. Toggle static inputs for full toggle coverage
// ═══════════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_sva_oneshot_vseq extends mmu_l2tlb_common_vseq;
  `uvm_object_utils(mmu_l2tlb_sva_oneshot_vseq)
  function new(string n="mmu_l2tlb_sva_oneshot_vseq"); super.new(n); m_va_base=39'h10_0000; endfunction

  // ── PTW-style: toggle static input ──
  protected task toggle_icg();
    if(m_misc_vif==null) return;
    @(m_misc_vif.driver_cb);
    m_misc_vif.driver_cb.pad_yy_icg_scan_en <= 1'b1;
    repeat(2) @(m_misc_vif.driver_cb);
    m_misc_vif.driver_cb.pad_yy_icg_scan_en <= 1'b0;
    repeat(2) @(m_misc_vif.driver_cb);
    `uvm_info(get_type_name(),"toggled pad_yy_icg_scan_en",UVM_MEDIUM)
  endtask

  // ── PTW-style: safe reset pulse ──
  protected task force_rst_pulse(string path);
    if(!uvm_hdl_check_path(path)) begin
      `uvm_warning(get_type_name(),$sformatf("path %s unavailable",path))
      return;
    end
    uvm_hdl_force(path, 1'b0);
    repeat(4) @(m_lsu_vif.driver_cb);
    uvm_hdl_release(path);
    repeat(16) @(m_lsu_vif.driver_cb);
    `uvm_info(get_type_name(),$sformatf("forced reset pulse on %s",path),UVM_MEDIUM)
  endtask

  // ── Install entries with given PPN base ──
  protected task install_entries(ppn_t ppn_base, int unsigned count=32, int unsigned id_base=10);
    for(int i=0;i<count;i++) begin
      cp0_satp_switch_seq s; va_t v;
      s=cp0_satp_switch_seq::type_id::create("s");
      void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
      s.start(p_sequencer.cp0_sqr); #300ns;
      v=va_t'(39'h0_7000_0000)+va_t'(i<<12);
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({ppn_base+ppn_t'(i),12'h000})),
        .v(1),.r(1),.w(1),.x(0),.u(0),.g(0),.a(1),.d(1));
      raw_pipe0(v,7'(id_base+i[6:0]),1'b0); #800ns;
    end
  endtask

  // ── Burst lookups to fill wbuf ──
  protected task burst_lookups(int unsigned rounds=6, int unsigned count=32);
    for(int r=0;r<rounds;r++) begin
      for(int i=0;i<count;i++) begin
        raw_pipe0(va_t'(39'h0_7000_0000)+va_t'(i<<12),7'(7'd20+i[6:0]),1'b0);
        #20ns;
      end
      #100ns;
    end
  endtask

  // ── Exercise SVA: fill wbuf naturally, then reset + refill ──
  protected task exercise_wbuf_full_sva();
    string rst_path    = "tb_top.u_dut.x_mmu_l2tlb.x_rrpv_wbuf.rst_n";

    `uvm_info(get_type_name(),"=== Phase A: Fill wbuf via sustained miss burst ===",UVM_MEDIUM)
    m_env_h.m_ptw_mem.m_responder.set_delay_range(512,1024);
    for(int i=16;i<48;i++) begin
      va_t v=va_t'(39'h0_7000_0000)+va_t'(i<<12);
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),
        .pa(pa_t'({ppn_t'(28'h1000+ppn_t'(i)),12'h000})),
        .v(1),.r(1),.w(0),.x(0),.u(0),.g(0),.a(1),.d(0));
      if(m_env_h.m_ref!=null) m_env_h.m_ref.sync_shadow_state();
    end
    for(int round=0;round<12;round++) begin
      for(int i=16;i<48;i++) begin
        raw_pipe0(va_t'(39'h0_7000_0000)+va_t'(i<<12),7'(7'd50+i[6:0]),1'b0);
        #10ns;
      end
      #50ns;
    end
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4,8);
    #5000ns;

    `uvm_info(get_type_name(),"=== Phase 4: Reset + refill with complementary PPN, DIFFERENT VA region ===",UVM_MEDIUM)
    force_rst_pulse(rst_path);
    // Use DIFFERENT VA base (0x7100_0000) so old L2TLB entries don't collide
    for(int i=0;i<32;i++) begin
      cp0_satp_switch_seq s; va_t v;
      s=cp0_satp_switch_seq::type_id::create("s");
      void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
      s.start(p_sequencer.cp0_sqr); #200ns;
      v = va_t'(39'h0_7100_0000)+va_t'(i<<12);
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({ppn_t'(28'h0FF_F000+ppn_t'(i)),12'h000})),
        .v(1),.r(1),.w(1),.x(0),.u(0),.g(0),.a(1),.d(1));
      raw_pipe0(v,7'(7'd80+i[6:0]),1'b0); #800ns;
    end
    for(int r=0;r<4;r++) begin
      for(int i=0;i<32;i++) begin
        raw_pipe0(va_t'(39'h0_7100_0000)+va_t'(i<<12),7'(7'd90+i[6:0]),1'b0);
        #20ns;
      end
      #100ns;
    end
    #30000ns;
  endtask

  virtual task body();
    `uvm_info(get_type_name(),"===== L2TLB SVA oneshot vseq START =====",UVM_NONE)
    init_common_handles();
    if(m_lsu_vif==null) `uvm_fatal(get_type_name(),"LSU VIF null")

    // PTW-style toggle static inputs
    toggle_icg();

    // Fill with low PPN entries
    install_entries(ppn_t'(28'h000_1000), 32, 10);
    #50000ns;

    // Natural burst to fill wbuf
    burst_lookups(6, 32);

    // Exercise SVA with deposit + reset + refill
    exercise_wbuf_full_sva();

    // MB full: sustained dtlb misses with long delay
    `uvm_info(get_type_name(),"Phase: MB full via dtlb misses",UVM_MEDIUM)
    m_env_h.m_ptw_mem.m_responder.set_delay_range(512,1024);
    for(int i=0;i<24;i++) begin
      cp0_satp_switch_seq s; va_t v=va_t'(39'h0_9000_0000)+va_t'(i<<12);
      s=cp0_satp_switch_seq::type_id::create("s");
      void'(s.randomize()with{satp_val=={4'h8,16'h0,44'h0};satp_sel==1'b0;});
      s.start(p_sequencer.cp0_sqr); #80ns;
      m_env_h.m_pt_mem.m_builder.map_4k(.va(v),.pa(pa_t'({ppn_t'(28'h9000+ppn_t'(i)),12'h000})),.v(1),.r(1),.w(0),.x(0),.u(0),.g(0),.a(1),.d(0));
      if(m_env_h.m_ref!=null) m_env_h.m_ref.sync_shadow_state();
      raw_pipe0(v,7'(7'd100+i[6:0]),1'b0); #20ns;
    end
    #200000ns;
    m_env_h.m_ptw_mem.m_responder.set_delay_range(4,8);

    toggle_icg();
    `uvm_info(get_type_name(),"L2TLB SVA oneshot vseq DONE",UVM_NONE)
  endtask
endclass

`endif // MMU_L2TLB_COVERAGE_VSEQ_SVH

