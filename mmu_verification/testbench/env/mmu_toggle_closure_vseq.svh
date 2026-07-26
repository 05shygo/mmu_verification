// =============================================================================
// MMU UVM — mmu_toggle_closure_vseq.svh
// Toggle-coverage closure vseqs per doc/toggle_closure_plan.md (v2).
//
// Tasks implemented here:
//   T-A  mmu_l1itlb_toggle_entry_sweep_vseq   (iUTLB full sweep, Phases 1..5b)
//   T-B  mmu_l1dtlb_toggle_highpa_1g_vseq     (dTLB 1G + high-PA, two rounds)
//   T-C  mmu_l1dtlb_toggle_tail_vseq          (dTLB surviving tail signals)
//   T-D  mmu_l1dtlb_toggle_expt_cam_vseq      (expt_cam VPN/iid/same_hit)
//   T-F  mmu_l2tlb_toggle_sram_vseq           (L2 tag/data array, Steps 1..5)
//   T-G  mmu_l2tlb_toggle_highaddr_vseq       (L2 ASID/VPN/G/TLBOP)
//   T-H  mmu_l2tlb_toggle_small_modules_vseq  (reqq/mb depth/type/ASID/EID)
//   T-I  assert_mid_test_reset() hooks at the end of T-A / T-B
//        (effective only with +MMU_TLBOP_RESET_MODE=...; graceful no-op else)
//
// Key methodology (per plan v2):
//   * All fill phases use >=2 complementary pattern rounds (0->1 AND 1->0),
//     with a final low-value round so both directions close on every bit.
//   * ASID rounds use 0xFFFF <-> 0x0000 (0xA5A5 has bit14=0 — plan v1 bug).
//   * Upper-half VA (VA[38]=1) requires sign-extended canonical drive:
//     - LSU: local raw_pipe0_hi() ({{25{va[38]}},va} — canon_va() zero-extends)
//     - IFU: local raw_ifu_fetch() (agent driver `tr.va >> 1` zeroes bit62)
//   * Dead/stub RTL signals are NOT targeted (see plan §二-A(b) waivers).
// =============================================================================
`ifndef MMU_TOGGLE_CLOSURE_VSEQ_SVH
`define MMU_TOGGLE_CLOSURE_VSEQ_SVH

// ---------------------------------------------------------------------------
// Shared L1-side base: raw canonical drivers + pattern helpers
// ---------------------------------------------------------------------------
class mmu_toggle_l1_base_vseq extends mmu_l1_tlb_common_vseq;

  `uvm_object_utils(mmu_toggle_l1_base_vseq)

  function new(string name = "mmu_toggle_l1_base_vseq");
    super.new(name);
  endfunction

  // Complementary PPN pattern rounds: r0=0xAAA_AAAA^i, r1=~r0, r2=low
  protected function ppn_t pat_ppn(int unsigned round, int unsigned i);
    ppn_t base;
    base = ppn_t'(28'hAAA_AAA0) ^ ppn_t'(i);
    case (round % 3)
      0: return base;
      1: return ~base & 28'hFFF_FFFF;
      default: return ppn_t'(28'h000_0100) + ppn_t'(i);
    endcase
  endfunction

  // ── Sign-extended (canonical) LSU pipe0 drive for VA[38]=1 addresses.
  //    raw_pipe0() uses canon_va() = {25'b0, va} which is NON-canonical for
  //    upper-half VAs and trips dutlb_va_illegal (hit_rd.sv:165). This variant
  //    drives the full 64-bit sign-extended VA so upper-half misses/refills
  //    are legal (closes vpn[26]-class toggles).
  protected task raw_pipe0_hi(va_t va, bit [6:0] iid, bit st_inst = 1'b0);
    bit [63:0] va64;
    va64 = mmu_vseq_va64(va);
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= va64;
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= st_inst;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= va64[38:11];
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
  endtask

  // ── Raw IFU fetch with proper canonical mapping and pavld wait.
  //    ifu_driver drives `tr.va >> 1` (bit62 always 0) so upper-half fetches
  //    through the agent are non-canonical; this raw task drives
  //    ifu_mmu_va = va64[63:1] (interface carries VA[63:1]) which keeps
  //    upper-half fetches canonical AND toggles ifu_mmu_va[62]=va64[63].
  protected task raw_ifu_fetch(va_t va, int unsigned timeout_cycles = 8192);
    virtual ifu_if ivif;
    bit [63:0] va64;
    int unsigned n;
    ivif = m_env_h.m_ifu.vif;
    if (ivif == null) begin
      `uvm_error(get_type_name(), "IFU vif null — raw_ifu_fetch skipped")
      return;
    end
    va64 = mmu_vseq_va64(va);
    ivif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    ivif.driver_cb.ifu_mmu_abort  <= 1'b0;
    @(ivif.driver_cb);
    ivif.driver_cb.ifu_mmu_va_vld <= 1'b1;
    ivif.driver_cb.ifu_mmu_va     <= va64[63:1];
    @(ivif.driver_cb);
    n = 0;
    while ((ivif.driver_cb.mmu_ifu_pavld !== 1'b1) && (n < timeout_cycles)) begin
      @(ivif.driver_cb);
      n++;
    end
    if (n >= timeout_cycles)
      `uvm_warning(get_type_name(),
        $sformatf("raw_ifu_fetch timeout va=0x%010h", {1'b0, va}))
    // Drop the request in the SAME cycle pavld is observed -- see the identical
    // comment on mmu_toggle_l2_base_vseq::raw_ifu_fetch.  Holding va_vld one
    // extra cycle lets the MMU answer the (now L1I-resident) VA a second time
    // and ifu_monitor reports "IFU rsp observed without pending req".
    ivif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    ivif.driver_cb.ifu_mmu_va     <= 63'h0;
    @(ivif.driver_cb);
    @(ivif.driver_cb);
  endtask

  // ── Retire a faulting L1D miss-buffer entry set.  A page/access-fault MB
  //    entry parks in state=3 until the LSU pipeline flushes it; without this
  //    the end-of-test quiescence check trips with l1d_mb != 0.
  protected task flush_and_drain(string ctx);
    bit mb_empty;
    wait_lsu_cycles(32);
    raw_rtu_flush();
    wait_l1d_mb_empty(ctx, mb_empty, 8192);
    wait_lsu_cycles(32);
  endtask

  // ── Full TLB invalidate (L1I + L1D + L2) + settle time.
  protected task tlb_inv_all_and_wait(int unsigned settle = 700);
    cp0_tlb_all_inv("toggle_inv_all");
    wait_lsu_cycles(settle);
  endtask

  // ── SATP re-write with a new ASID (root unchanged) — closes cur_asid arcs.
  //    The root PPN MUST be preserved: it comes from the ref-model CSR mirror
  //    so this also works when the bringup was done by the test base (which
  //    leaves the vseq-local m_root_ppn at 0).
  protected task satp_write_asid(asid_t asid);
    cp0_satp_switch_seq s;
    ppn_t root;
    root = m_root_ppn;
    if ((m_env_h != null) && (m_env_h.m_ref != null) && (m_env_h.m_ref.m_satp0_ppn != 0))
      root = m_env_h.m_ref.m_satp0_ppn;
    m_root_ppn = root;
    m_asid = asid;
    s = cp0_satp_switch_seq::type_id::create("toggle_satp_asid");
    if (!s.randomize() with {
          satp_val == {4'h8, asid, 44'(root)};
          satp_sel == 1'b0;
        })
      `uvm_fatal(get_type_name(), "satp_write_asid randomize failed")
    s.start(p_sequencer.cp0_sqr);
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(8);
  endtask

  // ── SysMap region-1 window over a PPN window with explicit 5-bit flags.
  //    (fields assigned directly — seq is NOT randomized so the
  //     translation-safe constraint does not pin hit_flg)
  protected task sysmap_window(bit [27:0] base, bit [27:0] mask, bit [4:0] flg);
    sysmap_hit_cross_tlb_seq s;
    s = sysmap_hit_cross_tlb_seq::type_id::create("toggle_sysmap_win");
    s.region_idx = 3'd1;
    s.hit_base   = base;
    s.hit_mask   = mask;
    s.hit_flg    = flg;
    s.start(p_sequencer.sysmap_sqr);
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(8);
  endtask

  // ── PMP: same flags on all 8 check ports (4'hF = Lock+X+W+R → pmp flg[3]).
  protected task pmp_all_ports(bit [3:0] flgv);
    pmp_txn tr;
    tr = pmp_txn::type_id::create("toggle_pmp_all");
    foreach (tr.flg[i]) tr.flg[i] = flgv;
    start_item(tr, -1, p_sequencer.pmp_sqr);
    finish_item(tr);
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(4);
  endtask

  // ── T-I hook: arm the tb_top reset injector while driving a TLBWR so the
  //    TLBOP-FSM-state-based injector has an arc to fire on. Graceful no-op
  //    without +MMU_TLBOP_RESET_MODE (assert_mid_test_reset warns and returns).
  protected task mid_test_reset_with_tlbop();
    fork
      assert_mid_test_reset();
      begin
        wait_lsu_cycles(8);
        cp0_tlbwr_entry(va_page(900), ppn_t'(28'h123_4560), 0, 1'b1, 1'b0);
        cp0_tlbwr_entry(va_page(901), ppn_t'(28'h0ED_CBA0), 1, 1'b1, 1'b0);
      end
    join
    wait_lsu_cycles(64);
  endtask

endclass : mmu_toggle_l1_base_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-A — iUTLB entry full sweep (mmu_l1itlb / iutlb_entry / iutlb_fst_entry)
//
// Phase 1 : 4K, three complementary PPN/VPN rounds over 32 entries
//           (covers entryN_ppn both dirs, entryN_vpn[26,25,21],
//            plru_iutlb_ref_num one-hot, ifu_mmu_va[62] via VA[38]=1 —
//            raw canonical drive, evaluated & accepted in plan v2 §五#11)
// Phase 2 : 2M pages (pgs[1]) — two rounds + 4K rewrite (pgs[1] 1->0)
// Phase 2b: 1G pages (pgs[2]) — round + 2M/4K rewrite (pgs[2] 1->0)
// Phase 3 : U-bit both directions (user-mode U=1 fetches, then S-mode U=0)
// Phase 4 : sysmap attribute flags flg[13:9] rounds (0x1F <-> 0x00)
// Phase 4b: low-flag diversity rewrite rounds (flg[6:5]/[2:1] 1->0)
// Phase 5 : disable/off path (M-mode fetches incl. high VA) + sysmap flg2
// Tail    : T-I mid-test reset hook
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l1itlb_toggle_entry_sweep_vseq extends mmu_toggle_l1_base_vseq;

  `uvm_object_utils(mmu_l1itlb_toggle_entry_sweep_vseq)

  function new(string name = "mmu_l1itlb_toggle_entry_sweep_vseq");
    super.new(name);
  endfunction

  // 32-VA plan: 8 upper VAs walk VA[38:31] one-hot (incl. VA[38]=1 →
  // ifu_mmu_va[62] + entryN_vpn[26]); rest sit in a private low window.
  protected function va_t itlb_va(int unsigned i);
    if (i == 0) return va_t'(39'h7F_FFFF_F000);         // VPN all-ones
    if (i < 8)  return va_t'(39'h1) << (31 + i);        // VA[32+i-1... ] one-hot
    return va_t'(39'h30_0000) + va_t'((i - 8) << 12);   // low window
  endfunction

  protected task map_round(int unsigned round, bit u, bit g, bit r, bit w, bit d);
    for (int unsigned i = 0; i < 32; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(itlb_va(i)),
        .pa(pa_t'({pat_ppn(round, i), 12'h000})),
        .v(1), .r(r), .w(w), .x(1), .u(u), .g(g), .a(1), .d(d));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task fetch_all_32(int unsigned tmo = 8192);
    for (int unsigned i = 0; i < 32; i++) begin
      raw_ifu_fetch(itlb_va(i), tmo);
      wait_lsu_cycles(8);
    end
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-A iUTLB toggle entry sweep START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(1, 2);

    // ── Phase 1: three complementary 4K rounds over all 32 entries ──
    for (int unsigned round = 0; round < 3; round++) begin
      map_round(round, 1'b0, round[0], 1'b1, round[0], 1'b1);
      tlb_inv_all_and_wait();
      fetch_all_32();
      // hit read-back (PA output buses high→low both directions)
      raw_ifu_fetch(itlb_va(0));
      raw_ifu_fetch(itlb_va(8));
      wait_lsu_cycles(32);
    end

    // ── Phase 2: 2M pages (pgs[1]) two rounds, then 4K rewrite ──
    for (int unsigned round = 0; round < 2; round++) begin
      for (int unsigned i = 0; i < 16; i++) begin
        m_env_h.m_pt_mem.m_builder.map_2m(
          .va(va_t'(39'h0_4000_0000) + va_t'(i << 21)),
          .pa(pa_t'({(round == 0) ? (28'hFFF_0000 | ppn_t'(i << 9))
                                  : ppn_t'(i << 9), 12'h000})),
          .v(1), .r(1), .w(round[0]), .x(1), .u(0), .g(0), .a(1), .d(1));
      end
      if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
      tlb_inv_all_and_wait();
      for (int unsigned i = 0; i < 16; i++) begin
        raw_ifu_fetch(va_t'(39'h0_4000_0000) + va_t'(i << 21));
        wait_lsu_cycles(8);
      end
    end
    // 4K rewrite closes pgs[1] 1->0 on rotated entries
    tlb_inv_all_and_wait();
    fetch_all_32();

    // ── Phase 2b: 1G pages (pgs[2]) round, then 2M + 4K rewrites ──
    // 1G window at (i+17)<<30 (L1 slots 17..24). It must avoid BOTH
    //  * the 2M window's L1 slot 1 (VA 0x4000_0000), and
    //  * every itlb_va() L1 slot {0,4,8,16,32,64,128,256,511} — a 1G leaf
    //    planted on top of itlb_va(3) (=1<<34 → slot 16) destroys that VA's
    //    4K subtree and the entry then never tracks later map_round() values.
    for (int unsigned i = 0; i < 8; i++) begin
      m_env_h.m_pt_mem.m_builder.map_1g(
        .va(va_t'(i + 17) << 30),
        .pa(pa_t'({ppn_t'((i + 1) << 18), 12'h000})),
        .v(1), .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 8; i++) begin
      raw_ifu_fetch(va_t'(i + 17) << 30);
      wait_lsu_cycles(8);
    end
    // rewrite with 2M then 4K → pgs[2] 1->0 (and pgs[1] up/down again)
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 8; i++) begin
      raw_ifu_fetch(va_t'(39'h0_4000_0000) + va_t'(i << 21));
      wait_lsu_cycles(8);
    end
    tlb_inv_all_and_wait();
    fetch_all_32();

    // ── Phase 3: U-bit both directions ──
    map_round(0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1);   // U=1 pages
    tlb_inv_all_and_wait();
    set_priv(2'b00);                               // user mode
    fetch_all_32();
    // S-mode fetch of a still-U=1 page → pgflt path.
    // The fault MUST come from a fresh walk: mmu_l1itlb applies the U-vs-S
    // check on iutlb_flg_aft_bypass[4] (mmu_l1itlb.sv:554), but an entry that
    // was installed by a user-mode fetch and is then re-hit in S-mode was
    // observed NOT to raise mmu_ifu_pgflt (dut.pa returned, pgflt=0), while
    // mmu_twu_chk does perform the check on the walk path
    // (mmu_twu_chk_sva.sv:195).  Invalidate first so the fault is generated by
    // the TWU (iutlb_ref_pgflt); the hit-path behaviour is recorded as an RTL
    // question in doc/toggle_closure_plan.md §六 rather than silently ignored.
    set_priv(2'b01);
    tlb_inv_all_and_wait();
    raw_ifu_fetch(itlb_va(9), 4096);
    // U=0 rewrite in S-mode → flg[4] 1->0 across entries
    map_round(1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
    tlb_inv_all_and_wait();
    fetch_all_32();

    // ── Phase 4: sysmap attribute window rounds (entry flg[13:9]) ──
    // Round A: PPN window 0x055_xxxx with sysmap flg=5'b11111
    for (int unsigned i = 0; i < 16; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(itlb_va(8 + i)),
        .pa(pa_t'({ppn_t'(28'h055_0000) + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    sysmap_window(28'h055_0000, 28'hFFF_0000, 5'b11111);
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 16; i++) begin
      raw_ifu_fetch(itlb_va(8 + i));
      wait_lsu_cycles(8);
    end
    // Round B: flags back to 0 and rewrite
    sysmap_window(28'h055_0000, 28'hFFF_0000, 5'b00000);
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 16; i++) begin
      raw_ifu_fetch(itlb_va(8 + i));
      wait_lsu_cycles(8);
    end
    // Restore a match-all window with the translation-safe flags (mask=0 means
    // "hit every PA", so leaving flg=0 here would silently apply flg=0 to the
    // rest of the test instead of releasing anything).
    sysmap_window(28'h000_0000, 28'h000_0000, 5'b01111);

    // ── Phase 4b: low-flag diversity rewrite rounds (flg 1->0 family) ──
    // execute-only (r=0,w=0), then g=1/d=0, then full-perm restore
    map_round(0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);   // X-only, D=0
    tlb_inv_all_and_wait();
    fetch_all_32();
    map_round(1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1);   // G=1
    tlb_inv_all_and_wait();
    fetch_all_32();
    map_round(2, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);   // restore low/normal
    tlb_inv_all_and_wait();
    fetch_all_32();

    // ── Phase 5: disable/off path (iutlb_disable_vld, off_flg[13:9], off PA) ──
    // NOTE: off-path VAs are deliberately kept in the LOWER half (VA[38]=0).
    //   On the bare/M-mode path the RTL forwards pa[27:0] = va64[39:12], so a
    //   canonical upper-half VA sets pa[27] from the sign-extension bit
    //   va64[39]. mmu_ref_model::translate() only receives va_t (VA[38:0]) and
    //   zero-extends (mmu_ref_model.svh:555), so it would report pa[27]=0 and
    //   the translation SB flags a false mismatch. Off-path pa[27:26] therefore
    //   stays uncovered until the ref model carries the full 64-bit VA — logged
    //   as a follow-up rather than papered over with a scoreboard exception.
    set_priv(2'b11);                               // M-mode → iutlb_off_hit
    raw_ifu_fetch(va_t'(39'h10_0000), 512);
    raw_ifu_fetch(va_t'(39'h3F_FFFF_F000), 512);   // off PA[25:0] all ones
    raw_ifu_fetch(va_t'(39'h20_0000_0000), 512);   // VA[37] high off PA bit
    raw_ifu_fetch(va_t'(39'h10_1000), 512);
    set_priv(2'b01);
    wait_lsu_cycles(64);

    // ── Tail: T-I mid-test reset (plusarg-gated) ──
    mid_test_reset_with_tlbop();
    m_env_h.wait_for_quiescent_midtest("l1itlb_toggle_sweep_done", 524288, 16);
    `uvm_info(get_type_name(), "===== T-A iUTLB toggle entry sweep DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1itlb_toggle_entry_sweep_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-B — dTLB 1G + high-PA fill (mmu_l1dtlb / _sva / hit_rd / hit_rd_sva)
//
// Phase 1: high-PA 4K/2M/1G rounds + complementary rewrite (ppn/pgs both dirs)
// Phase 2: high-VPN rounds (VPN[26] via sign-extended raw_pipe0_hi;
//          VPN[25]=39'h20_0000_0000, VPN[23]=39'h08_0000_0000) + low rewrite
// Phase 3: U-bit both directions incl. U-mode fault access
// Phase 4: dual-port hits on high/low PPN pages (hit_rd datapath)
// Phase 5: low-flag rewrite rounds (entry_flg[1:0]-class 1->0)
// Tail   : T-I mid-test reset hook
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l1dtlb_toggle_highpa_1g_vseq extends mmu_toggle_l1_base_vseq;

  `uvm_object_utils(mmu_l1dtlb_toggle_highpa_1g_vseq)

  function new(string name = "mmu_l1dtlb_toggle_highpa_1g_vseq");
    super.new(name);
  endfunction

  localparam va_t DW = va_t'(39'h34_0000);  // private 4K window (T-B)

  protected task dmap16(int unsigned round, bit u, bit r, bit w, bit d);
    for (int unsigned i = 0; i < 16; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(DW + va_t'(i << 12)),
        .pa(pa_t'({pat_ppn(round, i), 12'h000})),
        .v(1), .r(r), .w(w), .x(0), .u(u), .g(0), .a(1), .d(d));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task dtouch16(bit [6:0] iid_base);
    for (int unsigned i = 0; i < 16; i++) begin
      raw_pipe0(DW + va_t'(i << 12), 7'(iid_base + i[6:0]));
      wait_lsu_cycles(24);
    end
    wait_lsu_cycles(64);
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-B dTLB high-PA/1G toggle START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(1, 2);

    // ── Phase 1: 4K high/complement/low rounds ──
    for (int unsigned round = 0; round < 3; round++) begin
      dmap16(round, 1'b0, 1'b1, round[0], 1'b1);
      tlb_inv_all_and_wait();
      dtouch16(7'(round * 20 + 1));
    end

    // 2M + 1G high-PA installs
    for (int unsigned i = 0; i < 4; i++) begin
      m_env_h.m_pt_mem.m_builder.map_2m(
        .va(va_t'(39'h0_5000_0000) + va_t'(i << 21)),
        .pa(pa_t'({28'hFF0_0000 | ppn_t'(i << 9), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
      // 1G window at (i+16)<<30 — must not overlap the 2M window's L1 slot
      // (VA 0x5000_0000 shares L1 index 1 with a 1G page at 0x4000_0000)
      m_env_h.m_pt_mem.m_builder.map_1g(
        .va(va_t'(i + 16) << 30),
        .pa(pa_t'({ppn_t'((8 + i) << 18), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 4; i++) begin
      raw_pipe0(va_t'(39'h0_5000_0000) + va_t'(i << 21), 7'(7'd60 + i[6:0]));
      wait_lsu_cycles(24);
      raw_pipe0(va_t'(i + 16) << 30, 7'(7'd70 + i[6:0]));
      wait_lsu_cycles(24);
    end
    // rewrite every entry with 4K low pages → pgs[2]/pgs[1] 1->0
    tlb_inv_all_and_wait();
    dmap16(2, 1'b0, 1'b1, 1'b1, 1'b1);
    tlb_inv_all_and_wait();
    dtouch16(7'd80);

    // ── Phase 2: high-VPN rounds (corrected values, plan §五#12) ──
    begin
      va_t hv[4];
      hv[0] = va_t'(39'h50_0000_0000);  // VPN[26]=VPN[24]=1 (upper half)
      hv[1] = va_t'(39'h20_0000_0000);  // VPN[25]
      hv[2] = va_t'(39'h08_0000_0000);  // VPN[23]=VA[35]
      hv[3] = va_t'(39'h7F_FFFF_F000);  // VPN all-ones (upper half)
      foreach (hv[k]) begin
        m_env_h.m_pt_mem.m_builder.map_4k(
          .va(hv[k]), .pa(pa_t'({ppn_t'(28'h010_0000) + ppn_t'(k), 12'h000})),
          .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
      end
      if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
      tlb_inv_all_and_wait();
      foreach (hv[k]) begin
        if (hv[k][38])
          raw_pipe0_hi(hv[k], 7'(7'd90 + k[6:0]));      // canonical upper half
        else
          raw_pipe0(hv[k], 7'(7'd90 + k[6:0]));
        wait_lsu_cycles(48);
      end
      // low-VPN rewrite closes vpn high-bit 1->0
      tlb_inv_all_and_wait();
      dtouch16(7'd100);
    end

    // ── Phase 3: U-bit both directions ──
    dmap16(0, 1'b1, 1'b1, 1'b0, 1'b1);      // U=1 pages
    tlb_inv_all_and_wait();
    set_priv(2'b00);
    dtouch16(7'd10);                         // U-mode loads → flg[4] 0->1
    set_priv(2'b01);
    raw_pipe0(DW, 7'd29);                    // S-mode access of U=1 → fault path
    flush_and_drain("tb_u1_fault");
    dmap16(1, 1'b0, 1'b1, 1'b1, 1'b1);       // U=0 rewrite
    tlb_inv_all_and_wait();
    dtouch16(7'd40);                         // flg[4] 1->0
    set_priv(2'b00);
    raw_pipe0(DW, 7'd59);                    // U-mode access of U=0 → pgflt
    flush_and_drain("tb_u0_fault");
    set_priv(2'b01);

    // ── Phase 4: dual-port hits (hit_rd/_sva datapath both dirs) ──
    for (int unsigned i = 0; i < 8; i++) begin
      raw_pipe01(DW + va_t'(i << 12), DW + va_t'((15 - i) << 12),
                 7'(7'd101 + i[6:0]), 7'(7'd110 + i[6:0]), 1'b0, 1'b1);
      wait_lsu_cycles(8);
    end
    wait_lsu_cycles(64);

    // ── Phase 5: low-flag rewrite rounds (W/D-class flg 1->0) ──
    // R stays 1: a PTE with V=1,R=0,W=0,X=0 is a *non-leaf* encoding, so at the
    // last level every load page-faults and parks an MB entry — 16 of those
    // would leave l1d_mb=0xff at end of test.  R=1/W=0/D=0 still drives the
    // W and D flag bits 1->0, which is what this phase is for.
    dmap16(0, 1'b0, 1'b1, 1'b0, 1'b0);        // R=1, W=0, D=0 (X=0) pages
    tlb_inv_all_and_wait();
    dtouch16(7'd21);
    dmap16(2, 1'b0, 1'b1, 1'b1, 1'b1);        // restore normal
    tlb_inv_all_and_wait();
    dtouch16(7'd41);
    flush_and_drain("tb_phase5");

    // ── Tail: T-I mid-test reset (plusarg-gated) ──
    mid_test_reset_with_tlbop();
    m_env_h.wait_for_quiescent_midtest("l1dtlb_highpa_1g_done", 524288, 16);
    `uvm_info(get_type_name(), "===== T-B dTLB high-PA/1G toggle DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1dtlb_toggle_highpa_1g_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-C — dTLB surviving tail signals (dead/stub signals waived, plan §二-A(b))
//   dutlb_fin_flg[0], fin/off_flg[13:9] (sysmap), dutlb_pa_buf[27],
//   ctc_inv_va_hit_clr[15:9], sysmap_mmu_flg0/1[0], pmp_mmu_flg1[3],
//   mb_hit1_vec[4], cp0_mmu_mpp[0], icg/gateclk enables
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l1dtlb_toggle_tail_vseq extends mmu_toggle_l1_base_vseq;

  `uvm_object_utils(mmu_l1dtlb_toggle_tail_vseq)

  function new(string name = "mmu_l1dtlb_toggle_tail_vseq");
    super.new(name);
  endfunction

  localparam va_t TW = va_t'(39'h38_0000);  // private window (T-C)

  virtual task body();
    bit mb_empty;
    `uvm_info(get_type_name(), "===== T-C dTLB tail toggle START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(1, 2);

    // ── dutlb_pa_buf[27] + fin_flg[0]: high-PPN hit, low-PPN hit, then miss ──
    m_env_h.m_pt_mem.m_builder.map_4k(
      .va(TW), .pa(pa_t'({28'hFFF_FFF0, 12'h000})),
      .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    m_env_h.m_pt_mem.m_builder.map_4k(
      .va(TW + va_t'(39'h1000)), .pa(pa_t'({28'h000_0010, 12'h000})),
      .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    raw_pipe0(TW, 7'd1);              wait_lsu_cycles(48);
    raw_pipe0(TW, 7'd2);              wait_lsu_cycles(8);   // hit (fin_flg=1)
    raw_pipe0(TW + va_t'(39'h1000), 7'd3); wait_lsu_cycles(48);
    raw_pipe0(TW + va_t'(39'h1000), 7'd4); wait_lsu_cycles(8); // pa_buf 1->0
    raw_pipe0(va_t'(39'h3C_0000), 7'd5);   wait_lsu_cycles(48); // unmapped miss

    // ── sysmap_mmu_flg0/1[0] + fin/off_flg[13:9]: SO window rounds ──
    sysmap_window(28'h000_0010, 28'hFFF_FFF0, 5'b00001);
    raw_pipe0(TW + va_t'(39'h1000), 7'd6); wait_lsu_cycles(16);  // port0 in-SO
    raw_pipe1(TW + va_t'(39'h1000), 7'd7); wait_lsu_cycles(16);  // port1 in-SO
    sysmap_window(28'h000_0010, 28'hFFF_FFF0, 5'b11110);
    raw_pipe01(TW + va_t'(39'h1000), TW + va_t'(39'h1000), 7'd8, 7'd9);
    wait_lsu_cycles(16);
    sysmap_window(28'h000_0000, 28'h000_0000, 5'b01111);  // restore match-all

    // ── pmp_mmu_flg1[3]: lock+allow rounds on all check ports ──
    pmp_all_ports(4'hF);
    raw_pipe1(TW, 7'd10); wait_lsu_cycles(16);
    pmp_all_ports(4'h7);
    raw_pipe1(TW, 7'd11); wait_lsu_cycles(16);

    // ── ctc_inv_va_hit_clr[15:9]: fill 16 entries then VA-invalidate 9..15 ──
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 16; i++) begin
      raw_pipe0(va_t'(39'h10_0000) + va_t'(i << 12), 7'(7'd20 + i[6:0]));
      wait_lsu_cycles(24);
    end
    wait_lsu_cycles(64);
    for (int unsigned e = 9; e < 16; e++) begin
      raw_inv_pulse(INV_VA_ALL, va_t'(39'h10_0000) + va_t'(e << 12), 16'h0);
      wait_lsu_cycles(32);
    end

    // ── mb_hit1_vec[4]: 5 pending misses then port1 re-touch of the 5th ──
    configure_ptw_delay(200, 200);
    for (int unsigned i = 0; i < 5; i++) begin
      raw_pipe0(TW + va_t'((4 + i) << 12), 7'(7'd40 + i[6:0]));
      wait_lsu_cycles(2);
    end
    raw_pipe1(TW + va_t'(8 << 12), 7'd50);    // hits MB entry4 VPN
    wait_lsu_cycles(64);
    configure_ptw_delay(1, 2);
    raw_rtu_flush();
    wait_l1d_mb_empty("tc_mb_drain", mb_empty, 4096);

    // ── cp0_mmu_mpp[0] + mprv rounds ──
    set_mprv_mpp(1'b1, 2'b01);  wait_lsu_cycles(8);
    raw_pipe0(TW, 7'd60);       wait_lsu_cycles(16);
    set_mprv_mpp(1'b1, 2'b00);  wait_lsu_cycles(8);
    set_mprv_mpp(1'b0, 2'b11);  wait_lsu_cycles(8);

    // ── icg enable rounds (gateclk enables; complements gateclk_001) ──
    begin
      cp0_txn tr;
      tr = cp0_txn::type_id::create("toggle_icg_off");
      tr.op = CP0_SET_ICG_EN; tr.icg_en = 1'b0;
      start_item(tr, -1, p_sequencer.cp0_sqr); finish_item(tr);
      wait_lsu_cycles(8);
      raw_pipe0(TW, 7'd61); wait_lsu_cycles(32);
      tr = cp0_txn::type_id::create("toggle_icg_on");
      tr.op = CP0_SET_ICG_EN; tr.icg_en = 1'b1;
      start_item(tr, -1, p_sequencer.cp0_sqr); finish_item(tr);
      wait_lsu_cycles(8);
      raw_pipe0(TW, 7'd62); wait_lsu_cycles(32);
    end

    m_env_h.wait_for_quiescent_midtest("l1dtlb_tail_done", 524288, 16);
    `uvm_info(get_type_name(), "===== T-C dTLB tail toggle DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1dtlb_toggle_tail_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-D — expt_cam VPN/iid/same_hit sweep (mmu_l1dtlb_expt_cam, 56 bits)
//
// Phase 1 : PTW access-fault writes into ent[0..3] with high-VPN/iid patterns,
//           then complementary low-VPN rewrite (both directions)
//           (ent[2].vpn[26] needs upper-half VA → raw_pipe0_hi)
// Phase 2 : JTLB page-fault (wr1) writes — unmapped VAs (expt_wr1_vld path;
//           expt_wr1_acflt is RTL-tied 0 → waived, plan §二-A(b))
// Phase 3 : dual-port same-entry hit (same_hit_entry)
// Phase 4 : port1 hits on ent[3..6] (hit1_vec[3+]/hit1_use_vec[6:3])
// same_wr_eid: structurally unreachable same-cycle same-eid PTW+JTLB write —
//           documented for waiver (no stimulus here).
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l1dtlb_toggle_expt_cam_vseq extends mmu_toggle_l1_base_vseq;

  `uvm_object_utils(mmu_l1dtlb_toggle_expt_cam_vseq)

  function new(string name = "mmu_l1dtlb_toggle_expt_cam_vseq");
    super.new(name);
  endfunction

  // Pre-fill MB[0..n-1] so the next fault lands in ent[n] (eid = MB slot).
  // Uses the proven DTLB_EXPT_ENTRY_PRECISE_001 pattern: JTLB-install the
  // page first (cp0_tlbwr_entry) so the prefill misses stay off the PTW —
  // the subsequent forced PTW bus error then hits ONLY the target miss.
  // m_pf_idx is monotonic so every prefill uses a FRESH VA (a reused VA
  // would hit L1 and not allocate an MB slot).
  protected int unsigned m_pf_idx = 0;

  protected task prefill_mb(int unsigned n, bit [6:0] iid_base);
    for (int unsigned i = 0; i < n; i++) begin
      int unsigned v = 120 + m_pf_idx;
      m_pf_idx++;
      cp0_tlbwr_entry(va_page(v), ppn_t'(m_leaf_ppn0 + ppn_t'(v)),
        ((va_page(v) >> 12) & 'hff), 1'b1, 1'b0);
      raw_pipe0(va_page(v), 7'(iid_base + i[6:0]));
      wait_lsu_cycles(8);
    end
    wait_lsu_cycles(8);
  endtask

  protected task drain_all(string ctx);
    bit mb_empty;
    configure_ptw_delay(4, 4);
    wait_lsu_cycles(400);
    raw_rtu_flush();
    wait_l1d_mb_empty(ctx, mb_empty, 8192);
    wait_lsu_cycles(64);
  endtask

  // One access-fault write into ent[slot] at `va` (bus error on next walk)
  protected task acflt_at(int unsigned slot, va_t va, bit [6:0] iid, bit hi);
    bit got;
    if (slot > 0) prefill_mb(slot, 7'(iid + 7'd32));
    force_ptw_bus_error_by_count(1, 1'b1);
    if (hi) raw_pipe0_hi(va, iid);
    else    raw_pipe0(va, iid);
    wait_l1d_access_expt_write($sformatf("td_ac_%0d", slot), got);
    force_ptw_bus_error_by_count(1, 1'b0);
    drain_all($sformatf("td_acd_%0d", slot));
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-D expt_cam toggle START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(4, 4);   // precise-001-proven pacing

    // ── Phase 1: acflt writes, high-VPN then complementary low-VPN ──
    // Round A (high patterns): ent0..3
    acflt_at(0, va_t'(39'h2A_AAAA_A000), 7'd8,  1'b0); // VPN 0x555_5555? (VA[37:12] alt bits)
    acflt_at(1, va_t'(39'h20_0000_0000), 7'd6,  1'b0); // ent1 vpn[25]
    acflt_at(2, va_t'(39'h55_5555_5000), 7'd4,  1'b1); // upper half: vpn[26]+alt
    acflt_at(3, va_t'(39'h0F_FFFF_F000), 7'd7,  1'b0); // ent3 vpn[19:15]/[11:10]
    // Round B (complement/low): same slots, low VPN + low iid
    acflt_at(0, va_t'(39'h00_0000_1000), 7'd1, 1'b0);
    acflt_at(1, va_t'(39'h00_0000_2000), 7'd2, 1'b0);
    acflt_at(2, va_t'(39'h00_0000_3000), 7'd1, 1'b0);
    acflt_at(3, va_t'(39'h00_0000_4000), 7'd2, 1'b0);

    // ── Phase 2: JTLB page-fault (wr1) writes — unmapped VAs ──
    for (int unsigned k = 0; k < 4; k++) begin
      if (k > 0) prefill_mb(k, 7'd90);
      raw_pipe0(va_t'(39'h3E_0000) + va_t'(k << 12), 7'(7'd70 + k[6:0])); // unmapped
      wait_l1d_expt_write($sformatf("td_pg_%0d", k));
      drain_all($sformatf("td_pgd_%0d", k));
    end

    // ── Phase 3: same_hit_entry — dual-port hit of one expt entry ──
    map_special_page(200, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0);   // R=0 page
    raw_pipe0(va_page(200), 7'd50, 1'b0);
    wait_l1d_expt_write("td_sh");
    wait_lsu_cycles(16);
    raw_pipe01(va_page(200), va_page(200), 7'd50, 7'd50, 1'b0, 1'b1);
    wait_lsu_cycles(64);
    drain_all("td_shd");

    // ── Phase 4: port1 hits on ent[3..6] ──
    for (int unsigned k = 3; k <= 6; k++) begin
      prefill_mb(k, 7'd100);
      raw_pipe0(va_t'(39'h3F_0000) + va_t'(k << 12), 7'(7'd110 + k[6:0])); // unmapped → ent[k]
      wait_l1d_expt_write($sformatf("td_p4_%0d", k));
      wait_lsu_cycles(16);
      raw_pipe1(va_t'(39'h3F_0000) + va_t'(k << 12), 7'(7'd110 + k[6:0]));  // port1 hit
      wait_lsu_cycles(32);
      drain_all($sformatf("td_p4d_%0d", k));
    end

    `uvm_info(get_type_name(),
      "same_wr_eid: PTW-acflt and JTLB-pgflt cannot complete same-cycle with same eid — waiver candidate (plan T-D)", UVM_LOW)
    m_env_h.wait_for_quiescent_midtest("expt_cam_toggle_done", 524288, 16);
    `uvm_info(get_type_name(), "===== T-D expt_cam toggle DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1dtlb_toggle_expt_cam_vseq

// ---------------------------------------------------------------------------
// Shared L2-side base
// ---------------------------------------------------------------------------
class mmu_toggle_l2_base_vseq extends mmu_l2tlb_common_vseq;

  `uvm_object_utils(mmu_toggle_l2_base_vseq)

  function new(string name = "mmu_toggle_l2_base_vseq");
    super.new(name);
  endfunction

  protected task raw_pipe0_hi(va_t va, bit [6:0] iid, bit st_inst = 1'b0);
    bit [63:0] va64;
    va64 = mmu_vseq_va64(va);
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= va64;
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= st_inst;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= va64[38:11];
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
  endtask

  protected task raw_ifu_fetch(va_t va, int unsigned timeout_cycles = 8192);
    virtual ifu_if ivif;
    bit [63:0] va64;
    int unsigned n;
    ivif = m_env_h.m_ifu.vif;
    if (ivif == null) begin
      `uvm_error(get_type_name(), "IFU vif null — raw_ifu_fetch skipped")
      return;
    end
    va64 = mmu_vseq_va64(va);
    ivif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    @(ivif.driver_cb);
    ivif.driver_cb.ifu_mmu_va_vld <= 1'b1;
    ivif.driver_cb.ifu_mmu_va     <= va64[63:1];
    @(ivif.driver_cb);
    n = 0;
    while ((ivif.driver_cb.mmu_ifu_pavld !== 1'b1) && (n < timeout_cycles)) begin
      @(ivif.driver_cb);
      n++;
    end
    if (n >= timeout_cycles)
      `uvm_warning(get_type_name(),
        $sformatf("raw_ifu_fetch timeout va=0x%010h", {1'b0, va}))
    // Drop the request in the SAME cycle pavld is observed.  Holding va_vld for
    // one extra cycle (the old "@(driver_cb);" that used to sit here) lets the
    // MMU see a still-valid request for a VA that the completing walk has just
    // installed in the L1 ITLB, so it answers a second time.  ifu_monitor keeps
    // m_rsp_tail_hold asserted for that same va/abort signature and refuses to
    // reopen a pending request, so the extra response is reported as
    // "IFU rsp observed without pending req: pa=0x...".  Only miss->walk fetches
    // are long enough to expose it, which is why it showed up exactly twice in
    // T-H2 phase 3 (the two post-INVALL ITLB misses at ppn 0x015_0000/1).
    ivif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    ivif.driver_cb.ifu_mmu_va     <= 63'h0;
    @(ivif.driver_cb);
    @(ivif.driver_cb);
  endtask

  // Preserve the live root PPN (bringup is performed by the test base, which
  // leaves the vseq-local m_root_ppn at 0 — writing 44'h0 would point satp at
  // PA 0 and break every subsequent walk).
  protected task satp_write_asid(asid_t asid);
    cp0_satp_switch_seq s;
    ppn_t root;
    root = m_root_ppn;
    if ((m_env_h != null) && (m_env_h.m_ref != null) && (m_env_h.m_ref.m_satp0_ppn != 0))
      root = m_env_h.m_ref.m_satp0_ppn;
    m_root_ppn = root;
    m_asid = asid;
    s = cp0_satp_switch_seq::type_id::create("l2toggle_satp_asid");
    if (!s.randomize() with {
          satp_val == {4'h8, asid, 44'(root)};
          satp_sel == 1'b0;
        })
      `uvm_fatal(get_type_name(), "satp_write_asid randomize failed")
    s.start(p_sequencer.cp0_sqr);
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(8);
  endtask

  protected task tlb_inv_all_and_wait(int unsigned settle = 900);
    cp0_tlb_all_inv("l2toggle_inv_all");
    wait_lsu_cycles(settle);
  endtask

endclass : mmu_toggle_l2_base_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-F — L2 tag/data SRAM bit toggles (Steps 1..5, two-round)
//   tag = {VLD, VPN[26:0], ASID[15:0], PGS[2:0], G}; data = {PPN, FLG[13:0]}
//   tag bit0 = G (Step 3); tag_din[18] = ASID[14] (Step 1, must be 1);
//   data way-relative bit4 = FLG[4] (Step 3); data_din[37:35] = PPN[23:21].
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_sram_vseq extends mmu_toggle_l2_base_vseq;

  `uvm_object_utils(mmu_l2tlb_toggle_sram_vseq)

  function new(string name = "mmu_l2tlb_toggle_sram_vseq");
    super.new(name);
    m_va_base = 39'h10_0000;
  endfunction

  // install `cnt` 4K pages at va_base window, then look them up (fill+read)
  protected task fill_and_read(va_t base, ppn_t ppn0, int unsigned cnt,
                               bit g, bit u, bit [6:0] iid0);
    for (int unsigned i = 0; i < cnt; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(base + va_t'(i << 12)),
        .pa(pa_t'({ppn0 + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(|i[0]), .x(1), .u(u), .g(g), .a(1), .d(|i[1]));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    for (int unsigned i = 0; i < cnt; i++) begin
      raw_pipe0(base + va_t'(i << 12), 7'(iid0 + i[6:0]));
      wait_lsu_cycles(24);
    end
    // read-back round (dout buses)
    for (int unsigned i = 0; i < cnt; i++) begin
      raw_pipe0(base + va_t'(i << 12), 7'(iid0 + 7'd16 + i[6:0]));
      wait_lsu_cycles(6);
    end
    wait_lsu_cycles(64);
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-F L2 SRAM toggle START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Step 1: ASID rounds 0xFFFF -> 0x0000 (tag ASID both dirs incl [14]) ──
    satp_write_asid(16'hFFFF);
    fill_and_read(va_t'(39'h0_A800_0000), ppn_t'(28'h00A_0000), 16, 1'b0, 1'b0, 7'd1);
    tlb_inv_all_and_wait();
    satp_write_asid(16'h0000);
    fill_and_read(va_t'(39'h0_A800_0000), ppn_t'(28'h005_0000), 16, 1'b0, 1'b0, 7'd20);

    // ── Step 2: VPN rounds — high (incl upper-half) vs low ──
    begin
      va_t hv[3];
      hv[0] = va_t'(39'h7F_FFFF_F000);   // VPN all ones
      hv[1] = va_t'(39'h50_0000_0000);   // VPN[26,24]
      hv[2] = va_t'(39'h2A_AAAA_A000);   // alternating (VA[37:13])
      foreach (hv[k]) begin
        m_env_h.m_pt_mem.m_builder.map_4k(
          .va(hv[k]), .pa(pa_t'({ppn_t'(28'h003_0000) + ppn_t'(k), 12'h000})),
          .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
      end
      if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
      foreach (hv[k]) begin
        if (hv[k][38]) raw_pipe0_hi(hv[k], 7'(7'd40 + k[6:0]));
        else           raw_pipe0(hv[k], 7'(7'd40 + k[6:0]));
        wait_lsu_cycles(32);
        if (hv[k][38]) raw_pipe0_hi(hv[k], 7'(7'd44 + k[6:0]));
        else           raw_pipe0(hv[k], 7'(7'd44 + k[6:0]));
        wait_lsu_cycles(8);
      end
      tlb_inv_all_and_wait();
      fill_and_read(va_t'(39'h0_0100_0000), ppn_t'(28'h001_0000), 8, 1'b0, 1'b0, 7'd48);
    end

    // ── Step 3: G=1 global pages (tag bit0 x ways) + FLG[4]-class data bits ──
    fill_and_read(va_t'(39'h0_B000_0000), ppn_t'(28'h007_0000), 16, 1'b1, 1'b1, 7'd60);
    tlb_inv_all_and_wait();
    fill_and_read(va_t'(39'h0_B000_0000), ppn_t'(28'h002_0000), 16, 1'b0, 1'b0, 7'd80);

    // ── Step 4: PPN rounds — high (incl data_din[37:35]=PPN[23:21]) vs low ──
    fill_and_read(va_t'(39'h0_B800_0000), ppn_t'(28'hFFF_FF00), 16, 1'b0, 1'b0, 7'd100);
    tlb_inv_all_and_wait();
    fill_and_read(va_t'(39'h0_B800_0000), ppn_t'(28'h000_0F00), 16, 1'b0, 1'b0, 7'd120);

    // ── Step 5: 2M/1G pages (tag PGS field) two rounds ──
    for (int unsigned round = 0; round < 2; round++) begin
      for (int unsigned i = 0; i < 4; i++) begin
        m_env_h.m_pt_mem.m_builder.map_2m(
          .va(va_t'(39'h0_6000_0000) + va_t'(i << 21)),
          .pa(pa_t'({(round == 0) ? (28'hF00_0000 | ppn_t'(i << 9))
                                  : ppn_t'((i + 1) << 9), 12'h000})),
          .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
        m_env_h.m_pt_mem.m_builder.map_1g(
          .va(va_t'(i + 9) << 30),
          .pa(pa_t'({ppn_t'((i + 1) << 18), 12'h000})),
          .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
      end
      if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
      for (int unsigned i = 0; i < 4; i++) begin
        raw_pipe0(va_t'(39'h0_6000_0000) + va_t'(i << 21), 7'(7'd30 + i[6:0]));
        wait_lsu_cycles(24);
        raw_pipe0(va_t'(i + 9) << 30, 7'(7'd35 + i[6:0]));
        wait_lsu_cycles(24);
      end
      if (round == 0) tlb_inv_all_and_wait();
    end

    wait_lsu_cycles(2048);
    `uvm_info(get_type_name(), "===== T-F L2 SRAM toggle DONE =====", UVM_NONE)
  endtask

endclass : mmu_l2tlb_toggle_sram_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-G — L2 functional signals: ASID FFFF<->0000 (cur_asid/tlbr_asid/final_idx),
//   TLBWI/TLBR/TLBP with high-ASID entries, high VA (incl upper half), G pages,
//   ITLB-type L2 requests (ifu fetch misses), PFU pipe2 high addresses,
//   back-to-back same-VPN lookups (fb hit/miss timing).
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_highaddr_vseq extends mmu_toggle_l2_base_vseq;

  `uvm_object_utils(mmu_l2tlb_toggle_highaddr_vseq)

  function new(string name = "mmu_l2tlb_toggle_highaddr_vseq");
    super.new(name);
    m_va_base = 39'h10_0000;
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== T-G L2 high-addr toggle START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── High-ASID TLBOP round: TLBWI entries @ASID=FFFF then TLBR/TLBP ──
    satp_write_asid(16'hFFFF);
    for (int unsigned i = 0; i < 4; i++) begin
      cp0_tlbwr_entry(va_t'(39'h0_C000_0000) + va_t'(i << 12),
                      ppn_t'(28'hAAA_AA00) + ppn_t'(i),
                      i, 1'b1, 1'b1);            // TLBWI @ index i
    end
    for (int unsigned i = 0; i < 4; i++) begin   // TLBR readback (tlbr_asid[14])
      cp0_write_reg(2'd0, 64'(i));
      cp0_write_reg(2'd3, 64'h0000_0000_4000_0000);
      wait_lsu_cycles(16);
    end
    begin                                        // TLBP probe (final_idx path)
      bit [26:0] p_vpn;
      p_vpn = 27'((39'h0_C000_0000) >> 12);
      cp0_write_reg(2'd2, {18'b0, p_vpn, 3'b001, 16'hFFFF});
      cp0_write_reg(2'd3, 64'h0000_0000_8000_0000);
      wait_lsu_cycles(16);
    end
    // lookups under ASID=FFFF (arb tag din ASID segment)
    for (int unsigned i = 0; i < 4; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(va_t'(39'h0_C800_0000) + va_t'(i << 12)),
        .pa(pa_t'({ppn_t'(28'h009_0000) + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    for (int unsigned i = 0; i < 4; i++) begin
      raw_pipe0(va_t'(39'h0_C800_0000) + va_t'(i << 12), 7'(7'd10 + i[6:0]));
      wait_lsu_cycles(24);
    end
    // ── Low-ASID round (1->0 on cur_asid/tag ASID) ──
    tlb_inv_all_and_wait();
    satp_write_asid(16'h0000);
    for (int unsigned i = 0; i < 4; i++) begin
      raw_pipe0(va_t'(39'h0_C800_0000) + va_t'(i << 12), 7'(7'd30 + i[6:0]));
      wait_lsu_cycles(24);
    end

    // ── ITLB-type L2 requests (ifu fetch misses; req type[1]) ──
    for (int unsigned i = 0; i < 4; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(va_t'(39'h0_D000_0000) + va_t'(i << 12)),
        .pa(pa_t'({ppn_t'(28'h00B_0000) + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    for (int unsigned i = 0; i < 4; i++) begin
      raw_ifu_fetch(va_t'(39'h0_D000_0000) + va_t'(i << 12));
      wait_lsu_cycles(16);
    end

    // ── Upper-half + all-ones VPN lookups (canonical raw drive) ──
    m_env_h.m_pt_mem.m_builder.map_4k(
      .va(va_t'(39'h7F_FFFF_F000)), .pa(pa_t'({28'h00C_0000, 12'h000})),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env_h.m_pt_mem.m_builder.map_4k(
      .va(va_t'(39'h50_0000_0000)), .pa(pa_t'({28'h00C_0010, 12'h000})),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    raw_pipe0_hi(va_t'(39'h7F_FFFF_F000), 7'd40); wait_lsu_cycles(32);
    raw_pipe0_hi(va_t'(39'h50_0000_0000), 7'd41); wait_lsu_cycles(32);
    // back-to-back same-VPN (fill-buffer hit/miss timing)
    raw_pipe0_hi(va_t'(39'h7F_FFFF_F000), 7'd42); 
    raw_pipe0_hi(va_t'(39'h7F_FFFF_F000), 7'd43);
    wait_lsu_cycles(32);

    // ── PFU pipe2 high addresses (PA2/PMP/SYSMAP datapath) ──
    raw_pipe2(va_t'(39'h7F_FFFF_F000));
    wait_lsu_cycles(48);
    raw_pipe2(va_t'(39'h0_C800_0000));
    wait_lsu_cycles(48);

    // ── TLBWR installs under both ASIDs (tag ASID field written from m_asid;
    //    cp0_tlbwr_entry has no G-bit control, so G comes from the fixed MEL
    //    encoding — the G toggle itself is covered by T-F Step 3) ──
    satp_write_asid(16'hFFFF);
    cp0_tlbwr_entry(va_t'(39'h0_E000_0000), ppn_t'(28'h00D_0000), 0, 1'b1, 1'b0);
    satp_write_asid(16'h0000);
    cp0_tlbwr_entry(va_t'(39'h0_E000_1000), ppn_t'(28'h00D_0010), 0, 1'b1, 1'b0);

    wait_lsu_cycles(2048);
    `uvm_info(get_type_name(), "===== T-G L2 high-addr toggle DONE =====", UVM_NONE)
  endtask

endclass : mmu_l2tlb_toggle_highaddr_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-H — L2 reqq/mb small modules: 8 concurrent dTLB misses + 2 ITLB misses
//   (entry_rdy/ffr_oh/grant/bypass[8:4], queue_id/eid high, d_req_type,
//    entry ASID under FFFF<->0000 rounds).
//   NOTE: rrpv_wbuf full (count[3]/fifo_full) deliberately NOT attempted here —
//   plan H-2 requires a reachability analysis first (natural fill is blocked by
//   wbuf_pop_grant=~arb_l2tlb_req; force trips a_idle_keeps_count).
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_small_modules_vseq extends mmu_toggle_l2_base_vseq;

  `uvm_object_utils(mmu_l2tlb_toggle_small_modules_vseq)

  function new(string name = "mmu_l2tlb_toggle_small_modules_vseq");
    super.new(name);
    m_va_base = 39'h10_0000;
  endfunction

  protected task burst_round(va_t dw, va_t iw, ppn_t ppn0, bit [6:0] iid0);
    // map 8 dtlb + 2 itlb pages
    for (int unsigned i = 0; i < 8; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(dw + va_t'(i << 12)), .pa(pa_t'({ppn0 + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    for (int unsigned i = 0; i < 2; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(iw + va_t'(i << 12)), .pa(pa_t'({ppn0 + ppn_t'(16 + i), 12'h000})),
        .v(1), .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    // slow PTW so 8 dtlb misses stack up (eid 0..7, reqq/mb entries 0..8)
    configure_ptw_delay(150, 200);
    fork
      begin
        for (int unsigned p = 0; p < 4; p++) begin
          raw_pipe01(dw + va_t'((2 * p) << 12), dw + va_t'((2 * p + 1) << 12),
                     7'(iid0 + 7'(2 * p)), 7'(iid0 + 7'(2 * p + 1)),
                     p[0], 1'b1);   // mix load/store types
          wait_lsu_cycles(2);
        end
      end
      begin
        wait_lsu_cycles(6);
        raw_ifu_fetch(iw, 16384);            // ITLB miss #1 (type[1])
        raw_ifu_fetch(iw + va_t'(39'h1000), 16384); // ITLB miss #2
      end
    join
    wait_lsu_cycles(600);
    configure_ptw_delay(1, 2);
    raw_rtu_flush();
    wait_lsu_cycles(400);
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-H L2 small-modules toggle START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    satp_write_asid(16'hFFFF);
    burst_round(va_t'(39'h0_1000_0000), va_t'(39'h0_1100_0000),
                ppn_t'(28'h011_0000), 7'd1);
    tlb_inv_all_and_wait();
    satp_write_asid(16'h0000);
    burst_round(va_t'(39'h0_1200_0000), va_t'(39'h0_1300_0000),
                ppn_t'(28'h012_0000), 7'd40);
    // second stacking round with different type mix (all-store heavy)
    burst_round(va_t'(39'h0_1400_0000), va_t'(39'h0_1500_0000),
                ppn_t'(28'h013_0000), 7'd80);

    wait_lsu_cycles(2048);
    `uvm_info(get_type_name(), "===== T-H L2 small-modules toggle DONE =====", UVM_NONE)
  endtask

endclass : mmu_l2tlb_toggle_small_modules_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-B2 — dTLB full entry sweep (wave 2, mirrors T-A for DTLB)
//
// Targets: entry_flg_vec[16*14-1:0], entry_ppn_vec[16*28-1:0],
//          mb_entry_vpn/ppn/flg[8*27/28/14-1:0], entry_pgs[15:0]
// Phase 1: 3 complementary PPN rounds × 16 entries (ppn_vec all bits both dirs)
// Phase 2: flag-diversity rounds (W/D 1→0, X=1/R=0 exec-only, U both dirs)
// Phase 3: sysmap window rounds (flg[13:9] 0x1F ↔ 0x00)
// Phase 4: 2M + 1G superpages (entry_pgs[1]/[2] both dirs)
// Phase 5: MB slot sweep — 8 concurrent misses, high PPN → complement (low)
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l1dtlb_toggle_entry_sweep_vseq extends mmu_toggle_l1_base_vseq;

  `uvm_object_utils(mmu_l1dtlb_toggle_entry_sweep_vseq)

  function new(string name = "mmu_l1dtlb_toggle_entry_sweep_vseq");
    super.new(name);
  endfunction

  // Private VA window for T-B2 (distinct from T-B's 0x34_0000)
  localparam va_t TB2W = va_t'(39'h44_0000);
  // MB sweep window base (8 pages)
  localparam va_t MB2W = va_t'(39'h0_4800_0000);

  protected task dtlb_map16(int unsigned round, bit u, bit r, bit w, bit x, bit g, bit d);
    for (int unsigned i = 0; i < 16; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(TB2W + va_t'(i << 12)),
        .pa(pa_t'({pat_ppn(round, i), 12'h000})),
        .v(1), .r(r), .w(w), .x(x), .u(u), .g(g), .a(1), .d(d));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task dtlb_load16(bit [6:0] iid_base);
    for (int unsigned i = 0; i < 16; i++) begin
      raw_pipe0(TB2W + va_t'(i << 12), 7'(iid_base + i[6:0]));
      wait_lsu_cycles(24);
    end
    wait_lsu_cycles(64);
  endtask

  // Map + flood 8 DTLB miss-buffer slots then drain (mb_entry_ppn/vpn/flg sweep).
  // Slow PTW ensures all 8 misses park in MB simultaneously.
  protected task mb_sweep(ppn_t ppn0, bit [6:0] iid_base, bit d_bit);
    for (int unsigned i = 0; i < 8; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(MB2W + va_t'(i << 12)),
        .pa(pa_t'({ppn0 + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(d_bit));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    configure_ptw_delay(150, 200);
    for (int unsigned p = 0; p < 4; p++) begin
      raw_pipe01(MB2W + va_t'((2*p)   << 12), MB2W + va_t'((2*p+1) << 12),
                 7'(iid_base + 7'(2*p)), 7'(iid_base + 7'(2*p+1)),
                 p[0], 1'b1);
      wait_lsu_cycles(2);
    end
    wait_lsu_cycles(600);
    configure_ptw_delay(1, 2);
    raw_rtu_flush();
    wait_lsu_cycles(400);
  endtask

  virtual task body();
    bit mb_empty;
    `uvm_info(get_type_name(), "===== T-B2 dTLB entry sweep START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(1, 2);

    // ── Phase 1: 3 complementary PPN rounds over all 16 entries ──
    for (int unsigned round = 0; round < 3; round++) begin
      dtlb_map16(round, 1'b0, 1'b1, round[0], 1'b0, 1'b0, 1'b1);
      tlb_inv_all_and_wait();
      dtlb_load16(7'(round * 20 + 1));
      // hit read-back to exercise PA output datapath both dirs
      raw_pipe01(TB2W, TB2W + va_t'(15 << 12), 7'd90, 7'd91, 1'b0, 1'b1);
      wait_lsu_cycles(16);
    end

    // ── Phase 2: flag diversity rounds (W/D 1→0; X=1; U both dirs) ──
    // Sub-phase 2a: R=1,W=0,D=0 — closes W and D 1→0
    dtlb_map16(0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    tlb_inv_all_and_wait();
    dtlb_load16(7'd61);
    // Sub-phase 2b: R=1,W=1,X=1,D=1 — sets W/D back to 1 (0→1)
    dtlb_map16(1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1);
    tlb_inv_all_and_wait();
    dtlb_load16(7'd81);
    // Sub-phase 2c: U=1 user pages then U=0 rewrite (U both dirs)
    dtlb_map16(2, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);  // U=1
    tlb_inv_all_and_wait();
    set_priv(2'b00);
    dtlb_load16(7'd10);   // U-mode loads → flg[4] 0→1
    set_priv(2'b01);
    dtlb_map16(0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1);  // U=0
    tlb_inv_all_and_wait();
    dtlb_load16(7'd30);   // flg[4] 1→0
    // Sub-phase 2d: flush faulting U-mode entries from MB
    flush_and_drain("tb2_phase2");

    // ── Phase 3: sysmap attribute window rounds (entry flg[13:9]) ──
    // Map 16 pages into a fixed PPN window, then toggle sysmap region
    for (int unsigned i = 0; i < 16; i++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(TB2W + va_t'(i << 12)),
        .pa(pa_t'({ppn_t'(28'h066_0000) + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    // Round A: sysmap flg = 5'b11111 over the PPN window
    sysmap_window(28'h066_0000, 28'hFFF_0000, 5'b11111);
    tlb_inv_all_and_wait();
    dtlb_load16(7'd50);   // entries loaded with flg[13:9]=11111
    // Round B: sysmap flg = 5'b00000 → flg[13:9] 1→0
    sysmap_window(28'h066_0000, 28'hFFF_0000, 5'b00000);
    tlb_inv_all_and_wait();
    dtlb_load16(7'd70);
    // Restore match-all window
    sysmap_window(28'h000_0000, 28'h000_0000, 5'b01111);

    // ── Phase 4: 2M and 1G superpages (entry_pgs[1]/[2] both dirs) ──
    // 2M: 8 pages at distinct L2 slots
    for (int unsigned i = 0; i < 8; i++) begin
      m_env_h.m_pt_mem.m_builder.map_2m(
        .va(va_t'(39'h0_5800_0000) + va_t'(i << 21)),
        .pa(pa_t'({ppn_t'(28'hFF0_0000) | ppn_t'(i << 9), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 8; i++) begin
      raw_pipe0(va_t'(39'h0_5800_0000) + va_t'(i << 21), 7'(7'd20 + i[6:0]));
      wait_lsu_cycles(24);
    end
    // 1G: 4 pages
    for (int unsigned i = 0; i < 4; i++) begin
      m_env_h.m_pt_mem.m_builder.map_1g(
        .va(va_t'(i + 20) << 30),
        .pa(pa_t'({ppn_t'((i + 4) << 18), 12'h000})),
        .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    tlb_inv_all_and_wait();
    for (int unsigned i = 0; i < 4; i++) begin
      raw_pipe0(va_t'(i + 20) << 30, 7'(7'd50 + i[6:0]));
      wait_lsu_cycles(24);
    end
    // Rewrite with 4K → pgs[2]/[1] 1→0
    tlb_inv_all_and_wait();
    dtlb_map16(0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1);
    tlb_inv_all_and_wait();
    dtlb_load16(7'd100);

    // ── Phase 5: MB slot sweep — 3 PPN rounds, all 8 slots, high→complement ──
    // Round 0: high PPN (fills mb_entry_ppn with 0xFFF_xxx)
    mb_sweep(ppn_t'(28'hFFF_F000), 7'd1, 1'b1);
    tlb_inv_all_and_wait();
    // Round 1: complement PPN (mb_entry_ppn 1→0)
    mb_sweep(ppn_t'(28'h000_0F00), 7'd20, 1'b0);
    tlb_inv_all_and_wait();
    // Round 2: alternating PPN (closes remaining bit patterns)
    mb_sweep(ppn_t'(28'hAAA_A000), 7'd40, 1'b1);
    tlb_inv_all_and_wait();

    wait_l1d_mb_empty("tb2_final", mb_empty, 8192);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_entry_sweep_v2_done", 524288, 16);
    `uvm_info(get_type_name(), "===== T-B2 dTLB entry sweep DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1dtlb_toggle_entry_sweep_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-D2 — expt_cam full sweep (ent[4..7], wave 2)
//
// T-D covered ent[0..3] + port1 hits on ent[3..6].  T-D2 fills ent[4..7]
// with complementary high/low VPN patterns so every CAM entry's vpn[26:0]
// and iid[6:0] fields see both toggle directions.
//
// Phase 1: acflt writes into ent[4..7] — high-VPN diversity
// Phase 2: complementary low-VPN rewrite of ent[4..7]
// Phase 3: JTLB pgflt (wr1) writes into ent[4..7] (unmapped VAs)
// Phase 4: dual-port same-entry hit on ent[5] (extends same_hit coverage)
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l1dtlb_toggle_expt_cam_full_vseq extends mmu_l1dtlb_toggle_expt_cam_vseq;

  `uvm_object_utils(mmu_l1dtlb_toggle_expt_cam_full_vseq)

  function new(string name = "mmu_l1dtlb_toggle_expt_cam_full_vseq");
    super.new(name);
  endfunction

  // One JTLB page-fault write into ent[slot] at an UNMAPPED `va`.
  //
  // Why the pgflt path (and not acflt_at) for the high slots:
  //   expt_wr0_eid == ptw_l1dtlb_ref_id, i.e. the CAM entry index IS the MB
  //   slot that owns the faulting walk (mmu_l1dtlb.sv:309).  Reaching ent[4..7]
  //   therefore requires 4..7 MB slots to be occupied at the moment the fault
  //   retires.  acflt_at() adds a second constraint on top of that: it arms
  //   force_ptw_bus_error_by_count(1) and needs the *next* PTW memory request
  //   to be the target's.  With 4..7 JTLB-prefilled misses in flight that race
  //   is lost often enough to matter — measured 6/8 acflt_at(4..7) calls timing
  //   out ("timed out waiting for L1DTLB access exception write").
  //   The pgflt path needs only the MB-occupancy condition, and T-D Phase 4
  //   already proves it lands correctly on ent[3..6].  Since the CAM field
  //   under test here is vpn[26:0]/iid[6:0] — written identically by wr0(acflt)
  //   and wr1(pgflt) — the pgflt path gives the same toggle coverage without
  //   the flaky bus-error dependency.  The acflt write path itself stays
  //   covered by T-D Phase 1 on ent[0..3].
  protected task pgflt_at(int unsigned slot, va_t va, bit [6:0] iid, bit hi);
    if (slot > 0) prefill_mb(slot, 7'(iid + 7'd32));
    if (hi) raw_pipe0_hi(va, iid);
    else    raw_pipe0(va, iid);
    wait_l1d_expt_write($sformatf("td2_pf_%0d", slot));
    drain_all($sformatf("td2_pfd_%0d", slot));
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-D2 expt_cam full sweep START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(4, 4);

    // ── Phase 1: pgflt writes into ent[4..7], high-VPN patterns ──
    // All VAs are UNMAPPED (no map_4k) so the walk ends in a page fault whose
    // wr1 write lands in ent[eid==MB slot]. Patterns chosen so that between
    // Phase 1 and Phase 2 every vpn[26:0] bit sees BOTH directions.
    // ent[4]: alternating-bit VPN (lower half)
    pgflt_at(4, va_t'(39'h15_5555_5000), 7'd12, 1'b0);
    // ent[5]: complementary alternating pattern
    pgflt_at(5, va_t'(39'h0A_AAAA_A000), 7'd10, 1'b0);
    // ent[6]: upper-half VA (vpn[26]=1) — canonical raw_pipe0_hi
    pgflt_at(6, va_t'(39'h60_0000_0000), 7'd5,  1'b1);
    // ent[7]: VPN all-ones (closes every vpn bit 0->1)
    pgflt_at(7, va_t'(39'h7F_FFFF_F000), 7'd9,  1'b1);

    // ── Phase 2: complementary low-VPN rewrite of ent[4..7] (vpn 1->0) ──
    pgflt_at(4, va_t'(39'h00_0001_0000), 7'd1, 1'b0);
    pgflt_at(5, va_t'(39'h00_0002_0000), 7'd2, 1'b0);
    pgflt_at(6, va_t'(39'h00_0003_0000), 7'd3, 1'b0);
    pgflt_at(7, va_t'(39'h00_0004_0000), 7'd4, 1'b0);

    // ── Phase 3: iid[6:0] extremes on ent[2..3] (pgflt path) ──
    // Deliberately NOT acflt_at() here.  acflt_at() arms
    // force_ptw_bus_error_by_count(1) and needs the *next* PTW memory request to
    // belong to the target walk.  That holds right after bringup (parent T-D
    // Phase 1 relies on it and passes), but not after Phases 1/2 above have run
    // eight prefill_mb()+page-fault sequences: the residual JTLB/MB traffic wins
    // the race and the forced error lands on a foreign walk -- measured as
    // "td_ac_0/td_ac_1: timed out waiting for L1DTLB access exception write".
    // The wr0(acflt) port into ent[0..3] is already fully covered by parent
    // T-D Phase 1, so nothing is lost by dropping it; instead spend the cycles
    // on the one CAM field Phases 1/2 leave open -- iid[6:0] at its extremes.
    // iid=127 closes every iid bit 0->1, iid=0 closes every bit 1->0.
    pgflt_at(2, va_t'(39'h00_0006_0000), 7'd127, 1'b0);
    pgflt_at(3, va_t'(39'h00_0007_0000), 7'd0,   1'b0);

    // ── Phase 4: dual-port same-entry hit on ent[5] ──
    // Execute-only leaf (R=0,W=0,X=1): a legal Sv39 leaf that page-faults on a
    // load.  Do NOT use R=0/W=1 here -- that is the reserved encoding, the
    // walker treats it as a pointer, descends past level 0 and the ref model
    // reports "translate PAGE_FAULT (3-level exhausted)" as a UVM_WARNING.
    map_special_page(210, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0);
    raw_pipe0(va_page(210), 7'd55, 1'b0);
    wait_l1d_expt_write("td2_sh5");
    wait_lsu_cycles(16);
    raw_pipe01(va_page(210), va_page(210), 7'd55, 7'd56, 1'b0, 1'b1);
    wait_lsu_cycles(64);
    drain_all("td2_shd5");

    m_env_h.wait_for_quiescent_midtest("expt_cam_full_done", 524288, 16);
    `uvm_info(get_type_name(), "===== T-D2 expt_cam full sweep DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1dtlb_toggle_expt_cam_full_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-F2 — L2 SRAM tag_dout readback sweep (wave 2)
//
// T-F fills the SRAM arrays and reads them via LSU pipe.  T-F2 specifically
// exercises l2tlb_tag_dout (134 bits = TAG_WIDTH×8 ways - 2 parity) by
// writing all 256 sets × 8 ways via TLBWI (cp0_tlbwr_entry) with two
// complementary PPN/ASID/VPN rounds, then issuing TLBR readback for each.
// Also covers final_way_sel_vec[7:0] (one-hot hit on each of the 8 ways).
//
// Phase 1: TLBWI 8 ways of set 0 — high PPN/ASID (both dirs via TLBR)
// Phase 2: complementary TLBWI of same 8 ways — low PPN/ASID
// Phase 3: fill_and_read across 8 distinct sets (exercises per-set tag_dout)
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_sram_v2_vseq extends mmu_toggle_l2_base_vseq;

  `uvm_object_utils(mmu_l2tlb_toggle_sram_v2_vseq)

  function new(string name = "mmu_l2tlb_toggle_sram_v2_vseq");
    super.new(name);
    m_va_base = 39'h10_0000;
  endfunction

  // TLBWI `way` entries in set `set_idx`, then TLBR each back
  // L2TLB physical index = set_idx[7:0] (IDX_WIDTH=8, 256 sets × 8 ways)
  // cp0_tlbwr_entry(va, ppn, index, g, valid)
  protected task write_8ways(int unsigned set_idx, ppn_t ppn0, bit [15:0] asid,
                              bit [26:0] vpn0);
    satp_write_asid(asid);
    for (int unsigned w = 0; w < 8; w++) begin
      // Distribute over 8 distinct VA pages so each maps to different way
      // (the replacement policy fills ways sequentially on cold miss)
      cp0_tlbwr_entry(
        va_t'({vpn0 + 27'(w), 12'h0}),
        ppn0 + ppn_t'(w),
        int'(set_idx * 8 + w), 1'b0, 1'b1);
    end
    wait_lsu_cycles(32);
    // TLBR readback for each entry (drives tag_dout[way*48 +: 48])
    for (int unsigned w = 0; w < 8; w++) begin
      cp0_write_reg(2'd0, 64'(set_idx * 8 + w));  // write INDEX CSR
      cp0_write_reg(2'd3, 64'h0000_0000_4000_0000); // TLBR opcode
      wait_lsu_cycles(16);
    end
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-F2 L2 SRAM tag_dout sweep START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Phase 1: high PPN/ASID/VPN — tag_dout all-ones pattern ──
    write_8ways(0,   ppn_t'(28'hFFF_FF00), 16'hFFFF, 27'h7FF_FFF8);
    write_8ways(1,   ppn_t'(28'hAAA_AA00), 16'hAAAA, 27'h555_5550);
    write_8ways(127, ppn_t'(28'hF0F_0F00), 16'hF0F0, 27'h0F0_F0F0);
    write_8ways(255, ppn_t'(28'h0FF_F000), 16'hFF00, 27'h3FF_F000);

    // ── Phase 2: complementary low PPN/ASID/VPN — tag_dout 1→0 ──
    write_8ways(0,   ppn_t'(28'h000_0000), 16'h0000, 27'h000_0000);
    write_8ways(1,   ppn_t'(28'h555_5500), 16'h5555, 27'h2AA_AAA0);
    write_8ways(127, ppn_t'(28'h0F0_F000), 16'h0F0F, 27'h707_0700);
    write_8ways(255, ppn_t'(28'hF00_0F00), 16'h00FF, 27'h000_0FF0);

    // ── Phase 3: miss-fill across 8 sets, read-back via pipe hits ──
    // Re-uses fill_and_read from T-F parent; new VAs in untouched sets
    // (set index driven by VA[19:12], so stride 8*4096 = 0x8000 per set)
    for (int unsigned s = 0; s < 8; s++) begin
      va_t base_va;
      ppn_t base_ppn;
      base_va  = va_t'(39'h0_F000_0000) + va_t'(s << 15);
      base_ppn = ppn_t'(28'h0E0_0000)   + ppn_t'(s << 4);
      for (int unsigned i = 0; i < 8; i++) begin
        m_env_h.m_pt_mem.m_builder.map_4k(
          .va(base_va + va_t'(i << 12)),
          .pa(pa_t'({base_ppn + ppn_t'(i), 12'h000})),
          .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(i[0]));
      end
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    satp_write_asid(16'hFFFF);
    tlb_inv_all_and_wait();
    for (int unsigned s = 0; s < 8; s++) begin
      va_t base_va;
      base_va = va_t'(39'h0_F000_0000) + va_t'(s << 15);
      for (int unsigned i = 0; i < 8; i++) begin
        raw_pipe0(base_va + va_t'(i << 12), 7'(7'd10 + i[6:0]));
        wait_lsu_cycles(24);
      end
      // read-back hits (tag_dout driven for set s, all 8 ways)
      for (int unsigned i = 0; i < 8; i++) begin
        raw_pipe0(base_va + va_t'(i << 12), 7'(7'd20 + i[6:0]));
        wait_lsu_cycles(8);
      end
      wait_lsu_cycles(32);
    end

    wait_lsu_cycles(2048);
    `uvm_info(get_type_name(), "===== T-F2 L2 SRAM tag_dout sweep DONE =====", UVM_NONE)
  endtask

endclass : mmu_l2tlb_toggle_sram_v2_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-G2 — L2 all-8-ways hit sweep (wave 2)
//
// T-G covered 4 TLBWI entries and IFU/upper-half lookups.  T-G2 fills all
// 8 ways of the same L2 set with distinct VPN/ASID combos, then issues a
// hit lookup for each way so final_way_sel_vec[7:0] becomes fully one-hot
// exercised (each bit sees 0→1 and 1→0 across consecutive hits).
//
// Phase 1: seed 8 distinct pages into the same L2 set (VA stride = 256×4K)
//          under ASID=FFFF (high ASID bits both dirs)
// Phase 2: hit each of the 8 entries in order (final_way/raw_way toggles)
// Phase 3: ASID=0000 refill of same set (ASID 1→0 on tag)
// Phase 4: complementary PPN rewrite (data_dout PPN[27:0] both dirs)
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_highaddr_v2_vseq extends mmu_toggle_l2_base_vseq;

  `uvm_object_utils(mmu_l2tlb_toggle_highaddr_v2_vseq)

  function new(string name = "mmu_l2tlb_toggle_highaddr_v2_vseq");
    super.new(name);
    m_va_base = 39'h10_0000;
  endfunction

  virtual task body();
    // VA stride to land in the same L2 set: IDX_WIDTH=8 → set = VA[19:12]
    // Fix set = 0x5A. VA = (vpn2 << 30) | (vpn1 << 21) | (0x5A << 12)
    // 8 ways → 8 different VPN2/VPN1 combos, all with page-offset 0x5A000
    localparam va_t SET_PAGE = va_t'(39'h0_0000_0000) | va_t'(39'h5A << 12);
    // Way k uses VA at (k * (1<<21)) | SET_PAGE  — distinct VPN1 per way
    `uvm_info(get_type_name(), "===== T-G2 L2 all-8-ways hit sweep START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Phase 1: fill 8 ways under ASID=FFFF ──
    satp_write_asid(16'hFFFF);
    for (int unsigned w = 0; w < 8; w++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(SET_PAGE | va_t'(w << 21)),
        .pa(pa_t'({ppn_t'(28'hFF0_0000) + ppn_t'(w), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(w[0]));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    tlb_inv_all_and_wait();
    for (int unsigned w = 0; w < 8; w++) begin
      raw_pipe0(SET_PAGE | va_t'(w << 21), 7'(7'd10 + w[6:0]));
      wait_lsu_cycles(24);
    end

    // ── Phase 2: hit each way in order (final_way_sel_vec one-hot sweep) ──
    for (int unsigned w = 0; w < 8; w++) begin
      raw_pipe0(SET_PAGE | va_t'(w << 21), 7'(7'd20 + w[6:0]));
      wait_lsu_cycles(8);
    end
    wait_lsu_cycles(32);

    // ── Phase 3: ASID=0000 refill (tag ASID 1→0) ──
    tlb_inv_all_and_wait();
    satp_write_asid(16'h0000);
    for (int unsigned w = 0; w < 8; w++) begin
      raw_pipe0(SET_PAGE | va_t'(w << 21), 7'(7'd30 + w[6:0]));
      wait_lsu_cycles(24);
    end

    // ── Phase 4: complementary PPN rewrite (data_dout PPN 1→0) ──
    for (int unsigned w = 0; w < 8; w++) begin
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(SET_PAGE | va_t'(w << 21)),
        .pa(pa_t'({ppn_t'(28'h000_0000) + ppn_t'(w), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
    tlb_inv_all_and_wait();
    for (int unsigned w = 0; w < 8; w++) begin
      raw_pipe0(SET_PAGE | va_t'(w << 21), 7'(7'd40 + w[6:0]));
      wait_lsu_cycles(24);
    end
    // hit read-back (data_dout low PPN driven, both dirs closed)
    for (int unsigned w = 0; w < 8; w++) begin
      raw_pipe0(SET_PAGE | va_t'(w << 21), 7'(7'd50 + w[6:0]));
      wait_lsu_cycles(8);
    end

    wait_lsu_cycles(2048);
    `uvm_info(get_type_name(), "===== T-G2 L2 all-8-ways hit sweep DONE =====", UVM_NONE)
  endtask

endclass : mmu_l2tlb_toggle_highaddr_v2_vseq

// ═══════════════════════════════════════════════════════════════════════════
// T-H2 — L2 small-modules wave 2: invall_cnt sweep + TLBWI complementary
//
// T-H covers 8-concurrent-miss stacking.  T-H2 specifically targets:
//   invall_cnt[7:0] — walk counter 0→255 (all 8 bits both dirs)
//   req_entry_asid / eid / type bits under ASID 0xFFFF ↔ 0x0000
//   TLBWI complementary VPN/ASID to close remaining invall-path signals
//
// Phase 1: TLBWI 256 entries (ASID=FFFF, VPN all-ones) then INVALL →
//          invall_cnt walks 0..255, all bits toggle
// Phase 2: TLBWI 256 entries (ASID=0000, VPN=0) — complementary rewrite
//          → invall_cnt[7:0] walks again in opposite direction
// Phase 3: burst_round under ASID=A5A5 (covers entry_asid[7:0] mid bits)
//          followed by INVALL for invall-path ASID check
// ═══════════════════════════════════════════════════════════════════════════
class mmu_l2tlb_toggle_small_modules_v2_vseq extends mmu_toggle_l2_base_vseq;

  `uvm_object_utils(mmu_l2tlb_toggle_small_modules_v2_vseq)

  function new(string name = "mmu_l2tlb_toggle_small_modules_v2_vseq");
    super.new(name);
    m_va_base = 39'h10_0000;
  endfunction

  // Write `n` TLBWI entries starting at L2 index `idx0`, then issue INVALL
  protected task tlbwi_n_then_invall(int unsigned n, int unsigned idx0,
                                      ppn_t ppn0, bit [26:0] vpn0,
                                      bit [15:0] asid);
    satp_write_asid(asid);
    for (int unsigned i = 0; i < n; i++) begin
      cp0_tlbwr_entry(
        va_t'({vpn0 + 27'(i), 12'h0}),
        ppn0 + ppn_t'(i),
        int'(idx0 + i), 1'b0, 1'b1);
    end
    wait_lsu_cycles(16);
    cp0_tlb_all_inv("th2_invall");
    // Allow invall_cnt to walk 0→n (invall pulses n times, one per entry)
    wait_lsu_cycles(int'(n) * 2 + 200);
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-H2 L2 small-modules v2 START =====", UVM_NONE)
    init_common_handles();
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // ── Phase 1: INVALL walk over 256 entries — invall_cnt all-bits high ──
    // Write 256 entries @ ASID=FFFF with VPN all-F, PPN all-F
    tlbwi_n_then_invall(256, 0,
      ppn_t'(28'hFFF_FF00), 27'h7FF_FFF0, 16'hFFFF);

    // ── Phase 2: complementary 256 entries — invall_cnt 1→0 sweep ──
    tlbwi_n_then_invall(256, 0,
      ppn_t'(28'h000_0000), 27'h000_0000, 16'h0000);

    // ── Phase 3: mid-ASID burst (A5A5 exercises entry_asid[7:0] bits) ──
    // Map 8 dTLB + 2 iTLB pages, slow PTW, stack misses
    begin
      va_t dw, iw;
      dw = va_t'(39'h0_1600_0000);
      iw = va_t'(39'h0_1700_0000);
      satp_write_asid(16'hA5A5);
      for (int unsigned i = 0; i < 8; i++) begin
        m_env_h.m_pt_mem.m_builder.map_4k(
          .va(dw + va_t'(i << 12)),
          .pa(pa_t'({ppn_t'(28'h014_0000) + ppn_t'(i), 12'h000})),
          .v(1), .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(i[0]));
      end
      for (int unsigned i = 0; i < 2; i++) begin
        m_env_h.m_pt_mem.m_builder.map_4k(
          .va(iw + va_t'(i << 12)),
          .pa(pa_t'({ppn_t'(28'h015_0000) + ppn_t'(i), 12'h000})),
          .v(1), .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(0));
      end
      if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
      // ITLB-type L2 requests under ASID=A5A5, done FIRST with fast PTW.
      // Rationale: running these inside a fork with the slow-PTW dTLB storm
      // races — the ITLB walk queues behind 8 slow misses, raw_ifu_fetch
      // abandons the request (deasserting va_vld cancels the monitor's pending
      // req), and the late response then trips ifu_monitor "rsp without
      // pending req".  The concurrent ITLB+dTLB-storm case is already covered
      // by T-H under ASID FFFF/0000; what T-H2 adds is the A5A5 ASID value,
      // which a sequential fetch exercises just as well.
      raw_ifu_fetch(iw, 65536);
      wait_lsu_cycles(32);
      raw_ifu_fetch(iw + va_t'(39'h1000), 65536);
      wait_lsu_cycles(32);
      // Now the 8-deep dTLB miss storm (reqq/mb entry_asid under A5A5)
      configure_ptw_delay(150, 200);
      for (int unsigned p = 0; p < 4; p++) begin
        raw_pipe01(dw + va_t'((2*p)   << 12), dw + va_t'((2*p+1) << 12),
                   7'(7'd1 + 7'(2*p)), 7'(7'd2 + 7'(2*p+1)),
                   p[0], 1'b1);
        wait_lsu_cycles(2);
      end
      wait_lsu_cycles(600);
      configure_ptw_delay(1, 2);
      raw_rtu_flush();
      wait_lsu_cycles(400);
      // INVALL to flush A5A5 entries (entry_asid A5A5 → 0→1 on mid bits)
      cp0_tlb_all_inv("th2_a5a5_inv");
      wait_lsu_cycles(600);
    end

    wait_lsu_cycles(2048);
    `uvm_info(get_type_name(), "===== T-H2 L2 small-modules v2 DONE =====", UVM_NONE)
  endtask

endclass : mmu_l2tlb_toggle_small_modules_v2_vseq

// =============================================================================
// T-I — mmu_l1itlb entryN_flg[3]/[2]/[6] 1->0
//
// The gap: after T-A, `ct_mmu_iutlb_entry.utlb_flg[13:0]` still misses 1->0 on
// several bits for all 32 entries (~300 direction bits).  The register only has
// three writers (ct_mmu_iutlb_entry.v:150-173):
//
//   reset          -> 14'h0            (no mid-sim reset in this environment)
//   utlb_entry_upd -> utlb_upd_flg     (mmu_l1itlb.sv:1936)
//   utlb_entry_swp -> utlb_swp_flg     (another L1I entry's flg -- same values)
//
// and utlb_upd_flg = ptw_l1tlb_ref_flg | jtlb_utlb_ref_flg, i.e. whatever a
// completed walk or an L2 hit hands over.  So flg[k] 1->0 requires a *refill
// that carries flg[k]=0*.  Decoding the stored layout from the TWU refill
// packing (twu.sv:1157 `{data[37:10], high_flg[4:0], data[9:6], data[4:0]}`
// and twu.sv:1114 `chk_unit_flg[8:0] = {data[9:6], data[4:0]}`):
//
//   flg[4:0] = PTE[4:0] = {U, X, W, R, V}      flg[3]=X  flg[2]=W  flg[1]=R
//   flg[8:5] = PTE[9:6] = {RSW1, RSW0, D, A}   flg[5]=A  flg[6]=D
//   flg[13:9]= sysmap_mmu_flg[4:0] / PTE[63:59]
//
// Per-bit reachability of a refill carrying 0, given
// `chk_unit_refill_req = ... & !chk_unit_page_flt` (twu.sv:1152):
//
//   flg[0] V : `!flg[0]` faults unconditionally  -> 1->0 UNREACHABLE
//   flg[5] A : `!flg[5]` faults unconditionally  -> 1->0 UNREACHABLE by any
//              page-table stimulus.  (Reachable only by writing A=0 straight
//              into the L2 data array with TLBWI, since the software write path
//              performs no permission check -- see plan section 8.3.)
//   flg[3] X : `!flg[3] && fetch_type` faults, so a *fetch* walk can never
//              install X=0 -- but `l2tlb_l1itlb_ref_pavld = final_pa_vld &
//              (acc_type==3'b011)` with `final_pa_vld = final_tlb_hit &
//              final_vld` (mmu_l2tlb.sv:1013/1178) has NO permission term.
//              => an L2 entry installed by a *load* to an X=0 page is handed to
//              the L1 ITLB verbatim on the next fetch miss.  1->0 REACHABLE.
//   flg[2] W : only `!flg[2] && store_type` faults -> a load/fetch walk happily
//              installs W=0.  1->0 REACHABLE.
//   flg[6] D : only `!flg[6] && store_type` faults -> same.  1->0 REACHABLE.
//   flg[1] R : `!flg[1] && !flg[3] && thd` faults, but R=0/X=1 is a legal
//              execute-only leaf.  1->0 REACHABLE (T-A already sweeps it).
//
// This sequence exploits the unchecked L2->L1I refill path: fill all 32 entries
// with X=W=D=1, then re-fill all 32 from L2 entries whose PTE has X=W=D=0.  The
// second-round fetches legitimately page-fault on the L1I permission check, but
// the entry write has already happened, so the toggle is banked.  The ref model
// sees the same X=0 PTE in the page table and predicts the same fault, so the
// translation scoreboard stays quiet (cf. test_mmu_l1itlb_itlb_perm_001).
// =============================================================================
class mmu_l1itlb_toggle_flg_clear_vseq extends mmu_toggle_l1_base_vseq;

  `uvm_object_utils(mmu_l1itlb_toggle_flg_clear_vseq)

  function new(string name = "mmu_l1itlb_toggle_flg_clear_vseq");
    super.new(name);
  endfunction

  // Two private windows, disjoint from T-A (0x30_0000) and T-B2 (0x44_0000):
  //   TIX 32 pages -> 0x68_0000 .. 0x69_FFFF
  //   TIN 64 pages -> 0x6C_0000 .. 0x6F_FFFF
  localparam va_t TIX = va_t'(39'h68_0000);   // X=W=D=1 round (32 pages)
  localparam va_t TIN = va_t'(39'h6C_0000);   // X=W=D=0 round (64 pages)

  protected function va_t vx(int unsigned i); return TIX + va_t'(i << 12); endfunction
  protected function va_t vn(int unsigned i); return TIN + va_t'(i << 12); endfunction

  // Round A mapping: full permissions, so a fetch walk installs flg[3]=X=1,
  // flg[2]=W=1, flg[6]=D=1, flg[1]=R=1.
  protected task map_perm_round();
    for (int unsigned i = 0; i < 32; i++)
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(vx(i)), .pa(pa_t'({28'h0AA_0000 + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
  endtask

  // Round B mapping: read-only, non-executable, dirty-clear.  A *load* walk
  // succeeds (R=1, A=1, not a store so D=0 is fine) and installs the entry in
  // the L2 with flg[3]=flg[2]=flg[6]=0.
  // 64 pages, i.e. 2x the 32-entry L1 ITLB, so phase 3 keeps cycling the PLRU
  // long after every slot has been visited once.  Measured on the 32-page
  // version: only 16 of the 30 open entries picked up the X=0 refill, because
  // the iUTLB replacement is not a clean round robin (entries 0/8/16/24 are
  // `fst` slots that are additionally fed by the scd->fst swap path).
  protected task map_noexec_round();
    for (int unsigned i = 0; i < 64; i++)
      m_env_h.m_pt_mem.m_builder.map_4k(
        .va(vn(i)), .pa(pa_t'({28'h055_0000 + ppn_t'(i), 12'h000})),
        .v(1), .r(1), .w(0), .x(0), .u(0), .g(0), .a(1), .d(0));
    if (m_env_h.m_ref != null) m_env_h.m_ref.sync_shadow_state();
  endtask

  virtual task body();
    `uvm_info(get_type_name(), "===== T-I iUTLB flg clear START =====", UVM_NONE)
    init_common_handles();
    do_bringup(16, 39'h10_0000);
    configure_ptw_delay(1, 2);
    map_perm_round();
    map_noexec_round();

    // Two passes so that every entry sees 1->0 *and* 0->1 regardless of which
    // slot the PLRU happens to pick on a given pass.
    for (int unsigned pass = 0; pass < 4; pass++) begin

      // ── Phase 1: 32 fetches of the fully-permitted window ──
      // Fills all 32 L1I entries with flg[3]=flg[2]=flg[6]=1.
      tlb_inv_all_and_wait();
      for (int unsigned i = 0; i < 32; i++) begin
        raw_ifu_fetch(vx(i));
        wait_lsu_cycles(8);
      end
      wait_lsu_cycles(64);

      // ── Phase 2: seed the L2 with 32 X=0/W=0/D=0 entries ──
      // Loads, not fetches: a fetch walk on an X=0 PTE page-faults in the TWU
      // and never reaches the refill port, so the L2 would stay empty.
      for (int unsigned i = 0; i < 64; i++) begin
        raw_pipe0(vn(i), 7'(i[6:0]), 1'b0);
        wait_lsu_cycles(24);
      end
      flush_and_drain($sformatf("ti_p2_%0d", pass));

      // ── Phase 3: 32 fetch misses that hit those L2 entries ──
      // l2tlb_l1itlb_ref_pavld carries no permission term, so each L1I entry is
      // overwritten with flg[3]=flg[2]=flg[6]=0 -> the 1->0 transitions.  The
      // fetch itself then takes an instruction page fault, which is the
      // architecturally correct result and is what the ref model predicts.
      // Rotate the start index per pass so a given VA does not always land on
      // the same PLRU victim.
      for (int unsigned k = 0; k < 64; k++) begin
        raw_ifu_fetch(vn((k + pass * 13) % 64));
        wait_lsu_cycles(8);
      end
      wait_lsu_cycles(64);

      // ── Phase 4: re-fetch two of the permitted pages ──
      // Restores 0->1 on the same bits and proves the entries still work after
      // having been poisoned with a non-executable translation.
      raw_ifu_fetch(vx(0));
      raw_ifu_fetch(vx(31));
      wait_lsu_cycles(32);
    end

    flush_and_drain("ti_end");
    `uvm_info(get_type_name(), "===== T-I iUTLB flg clear DONE =====", UVM_NONE)
  endtask

endclass : mmu_l1itlb_toggle_flg_clear_vseq

`endif // MMU_TOGGLE_CLOSURE_VSEQ_SVH
