// =============================================================================
// MMU UVM Verification — testbench/env/mmu_l1_l2_tlb_common_vseq.svh
// Phase 15 (TASK A0): Shared atomic-task base classes for L1/L2 TLB coverage
// closure.  Provides reusable, scoreboard-checked primitives that later
// coverage TASKs (B/C/D/E) build on.  No URG closure target of its own.
//
// Two base classes:
//   * mmu_l1_tlb_common_vseq — extends l1dtlb_directed_vseq to reuse raw_pipe*,
//     va_page, do_bringup, raw_rtu_flush, configure_ptw_delay helpers.
//   * mmu_l2tlb_common_vseq   — same parent (mirrors mmu_l2tlb_pfu_chk_deny_vseq).
//
// All atomic tasks are observation-only with respect to internal DUT state:
// probes are read via m_probe_vif (read-only) to time stimulus; no force / no
// hierarchical writes are used.  Every stimulus path goes through the standard
// LSU/IFU/MISC/CP0/PMP/SYSMAP/PTW agent interfaces.
// =============================================================================
`ifndef MMU_L1_L2_TLB_COMMON_VSEQ_SVH
`define MMU_L1_L2_TLB_COMMON_VSEQ_SVH

// ---------------------------------------------------------------------------
// L1 TLB (DTLB + ITLB) common atomic-task base
// ---------------------------------------------------------------------------
class mmu_l1_tlb_common_vseq extends l1dtlb_directed_vseq;

  `uvm_object_utils(mmu_l1_tlb_common_vseq)

  function new(string name = "mmu_l1_tlb_common_vseq");
    super.new(name);
  endfunction

  // -----------------------------------------------------------------------
  // init_common_handles: cache env/lsu/misc/probe handles.  Subclasses that
  // override body() must invoke this before any atomic task is called.
  // -----------------------------------------------------------------------
  protected task init_common_handles();
    m_env_h   = get_env();
    m_lsu_vif = m_env_h.m_lsu.vif;
    m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null)
      `uvm_fatal(get_type_name(), "LSU VIF is null")
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(null, "*", "MMU_DUT_PROBES_VIF", m_probe_vif))
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF not set — probe-assisted tasks will degrade to fixed waits",
        UVM_LOW)
  endtask

  // -----------------------------------------------------------------------
  // drive_lsu_miss_to_entry: install + hit one DTLB entry slot.
  //   entry_idx: 0..15  DTLB entry index to exercise
  //   store:     0/1     load (raw_pipe0) or store (raw_pipe1) miss
  //   iid:       instruction id driven on lsu_mmu_id0/1
  // Maps the 4 KB page through the legitimate builder so the PTW refill
  // path stays legal & scoreboard-checked.  Uses va[15:12]=entry_idx for
  // the 16-entry DTLB set-indexing.
  // -----------------------------------------------------------------------
  protected task drive_lsu_miss_to_entry(int unsigned entry_idx, bit store, bit [6:0] iid);
    va_t va;
    if (entry_idx > 15) begin
      `uvm_error(get_type_name(), $sformatf("entry_idx %0d out of range 0..15", entry_idx))
      return;
    end
    va = va_t'(m_va_base) + va_t'(entry_idx << 12) + va_t'((entry_idx / 4) << 16);
    if (m_env_h.m_pt_mem != null)
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(va),
        .pa(pa_t'({ppn_t'(m_leaf_ppn0 + ppn_t'(entry_idx + 64)), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    if (store)
      raw_pipe1(va, iid, 1'b1);
    else
      raw_pipe0(va, iid, 1'b0);
    wait_lsu_cycles(64);
  endtask

  // -----------------------------------------------------------------------
  // drive_ifu_fetch_to_itlb_entry: fetch one 4 KB page so the iutlb entry
  // selected by va[15:12] is installed via the legitimate IFU -> PTW path.
  // -----------------------------------------------------------------------
  protected task drive_ifu_fetch_to_itlb_entry(int unsigned idx);
    ifu_sequential_fetch_seq seq;
    va_t va;
    if (idx > 15) begin
      `uvm_error(get_type_name(), $sformatf("ifu entry idx %0d out of range 0..15", idx))
      return;
    end
    va = va_t'(39'h10_0000) + va_t'(idx << 12);
    if (m_env_h.m_pt_mem != null)
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(va),
        .pa(pa_t'({ppn_t'(28'h400 + ppn_t'(idx)), 12'h000})),
        .v(1), .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    seq = ifu_sequential_fetch_seq::type_id::create("l1itlb_fetch_entry");
    seq.num_txn = 2;
    void'(seq.randomize());
    seq.start(m_env_h.m_ifu.m_sequencer);
    wait_lsu_cycles(32);
  endtask

  // -----------------------------------------------------------------------
  // assert_rtu_flush_at_vpn: send a single-cycle rtu_yy_xx_flush pulse
  // while a miss for `va` is in-flight.  Caller times the in-flight miss;
  // this task just emits the pulse.
  // -----------------------------------------------------------------------
  protected task assert_rtu_flush_at_vpn(va_t va);
    `uvm_info(get_type_name(),
      $sformatf("rtu_flush pulse while VPN=%08h pending", va[38:12]), UVM_HIGH)
    raw_rtu_flush();
  endtask

  // -----------------------------------------------------------------------
  // assert_mid_test_reset: signal the tb_top reset injector that a real
  // cpurst_b 1->0->1 pulse is desired mid-test.  tb_top.sv watches the
  // probe_if.tlbop_reset_inject_active flag (under +MMU_TLBOP_RESET_MODE)
  // and performs the actual reset; this task synchronises the handshake.
  // If no +MMU_TLBOP_RESET_MODE plusarg was supplied the task falls back
  // to a no-op + warning so the test still runs to completion.
  // -----------------------------------------------------------------------
  protected task assert_mid_test_reset();
    if (m_probe_vif == null) begin
      `uvm_warning(get_type_name(),
        "m_probe_vif null; assert_mid_test_reset cannot arm handshake — skipping")
      return;
    end
    m_probe_vif.tlbop_reset_inject_active = 1'b1;
    `uvm_info(get_type_name(),
      "mid-test reset request armed; waiting for tb_top handshake (or timeout)", UVM_LOW)
    fork
      begin
        wait (m_probe_vif.tlbop_reset_inject_done == 1'b1);
        wait_lsu_cycles(4);
      end
      begin : reset_to_timeout
        repeat (8192) @(m_probe_vif.mon_cb);
        `uvm_warning(get_type_name(),
          "mid-test reset did not complete within window; ensure +MMU_TLBOP_RESET_MODE is set on the test")
      end
    join_any
    disable fork;
    m_probe_vif.tlbop_reset_inject_active = 1'b0;
  endtask

endclass : mmu_l1_tlb_common_vseq


// ---------------------------------------------------------------------------
// L2 TLB common atomic-task base
// ---------------------------------------------------------------------------
class mmu_l2tlb_common_vseq extends l1dtlb_directed_vseq;

  `uvm_object_utils(mmu_l2tlb_common_vseq)

  function new(string name = "mmu_l2tlb_common_vseq");
    super.new(name);
  endfunction

  // Same handle cache as the L1 sibling.
  protected task init_common_handles();
    m_env_h   = get_env();
    m_lsu_vif = m_env_h.m_lsu.vif;
    m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null)
      `uvm_fatal(get_type_name(), "LSU VIF is null")
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(null, "*", "MMU_DUT_PROBES_VIF", m_probe_vif))
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF not set — probe-assisted tasks will degrade to fixed waits",
        UVM_LOW)
  endtask

  // -----------------------------------------------------------------------
  // raw_pipe2: prefetch-unit (pipe2) VA pulse — same as
  // mmu_l2tlb_pfu_chk_deny_vseq.raw_pipe2.  Duplicated here so this base
  // class is self-contained (PFU deny test uses it directly).
  // -----------------------------------------------------------------------
  protected task raw_pipe2(va_t va);
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va2     <= va[27:0];
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld <= 1'b0;
  endtask

  // -----------------------------------------------------------------------
  // drive_l2tlb_write_with_type: drive an LSU miss whose PTW refill yields
  // a write cycle of the requested acc_type / write / tag_msb combination.
  // The L2TLB arb slave port is not exposed as a standalone agent; we
  // produce the requested write cycle by varying the PTE permission bits
  // (which set acc_type on the refill) and PA high bit (which sets
  // tag_msb).  Scoreboard verifies the resulting tag/data SRAM writes.
  // -----------------------------------------------------------------------
  protected task drive_l2tlb_write_with_type(bit [2:0] acc_type, bit write, bit tag_msb);
    int unsigned vpn_idx;
    va_t va;
    ppn_t leaf_ppn;
    vpn_idx = {tag_msb, acc_type[1:0]} + 8;
    va      = va_t'(m_va_base) + va_t'(vpn_idx << 12);
    // Encode tag_msb into PPN high bit so ref_ppn[TAG_WIDTH-1] toggles.
    leaf_ppn = ppn_t'(m_leaf_ppn0 + ppn_t'(vpn_idx + 128)) | (tag_msb ? ppn_t'(28'h100_0000) : 28'h0);
    if (m_env_h.m_pt_mem != null)
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(va),
        .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1),
        .r(acc_type[1] | ~write),
        .w(write),
        .x(acc_type[2]),
        .u(0), .g(0), .a(1), .d(write));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    if (write)
      raw_pipe1(va, 7'(acc_type + 8'd32), 1'b1);
    else
      raw_pipe0(va, 7'(acc_type + 8'd32), 1'b0);
    wait_lsu_cycles(96);
  endtask

  // -----------------------------------------------------------------------
  // drive_multiway_hit: install multiple L2TLB ways of the same set with
  // different ASID/global bits so several final_way_hit_kidN fire in the
  // same cycle on subsequent lookups.  ways_hit_mask bit N => way N is
  // populated (bits 0..4 honoured; bits 5..7 ignored — L2TLB has 5 ways
  // for kid0..4 per TASK L2TLB-T02).
  // -----------------------------------------------------------------------
  protected task drive_multiway_hit(bit [7:0] ways_hit_mask);
    int unsigned base_vpn_idx;
    base_vpn_idx = 200;
    for (int unsigned w = 0; w < 5; w++) begin
      va_t va;
      if (!ways_hit_mask[w]) continue;
      va = va_t'(m_va_base) + va_t'((base_vpn_idx + w * 16) << 12);
      if (m_env_h.m_pt_mem != null)
        m_env_h.m_pt_mem.m_builder.map_4k(
          .va(va),
          .pa(pa_t'({ppn_t'(28'h300 + ppn_t'(w)), 12'h000})),
          .v(1), .r(1), .w(1), .x(0),
          .u(0), .g(w[0]), .a(1), .d(1));
      if (m_env_h.m_ref != null)
        m_env_h.m_ref.sync_shadow_state();
      raw_pipe0(va, 7'(8'd40 + w[6:0]), 1'b0);
      wait_lsu_cycles(64);
    end
  endtask

  // -----------------------------------------------------------------------
  // drive_pfu_pipe2_with_pmp_deny: drive a PFU (pipe2 prefetch) request
  // while PMP port4 deny is configured by the caller.  Reuses raw_pipe2
  // defined above.
  // -----------------------------------------------------------------------
  protected task drive_pfu_pipe2_with_pmp_deny();
    `uvm_info(get_type_name(), "PFU pipe2 request under PMP deny", UVM_HIGH)
    raw_pipe2(va_page(0));
    wait_lsu_cycles(8);
  endtask

endclass : mmu_l2tlb_common_vseq

`endif // MMU_L1_L2_TLB_COMMON_VSEQ_SVH
