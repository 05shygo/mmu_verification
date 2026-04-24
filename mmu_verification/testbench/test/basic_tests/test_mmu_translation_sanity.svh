// =============================================================================
// MMU UVM Verification — testbench/test/basic_tests/test_mmu_translation_sanity.svh
// Phase 5 (Engineer B): End-to-end IFU + LSU MMU Translation Sanity Test
//
// PURPOSE:
//   First DUT-facing translation test.  Builds a 100-page 4K Sv39 page table,
//   then drives IFU fetches and LSU pipe0/1 loads/stores to those mapped VAs.
//   mmu_translation_sb compares every DUT translation result against the Sv39
//   software reference model (mmu_ref_model.translate()).
//
// TEST FLOW:
//   1. PMP allow-all  (pmp_flg_normal_seq)
//   2. SysMap disable-all  (sysmap_region_setup_seq)
//   3. Write SATP0 (Sv39, PPN=0, ASID=0) + S-mode + ICG_EN=1 + PTW_EN=1
//   4. Build 100 4K page mappings:
//        VA base = 0x0010_0000,  step = 4K
//        PA PPN base = 0x200,    r=w=x=1, u=0, a=d=1
//   5. IFU fetch sequence: 100 fetches → mapped VAs  (ifu_mapped_va_seq)
//   6. LSU pipe0 load sequence: 100 loads → mapped VAs  (lsu_mapped_va_seq)
//   7. LSU pipe1 store sequence: 20 stores → mapped VAs  (lsu_mapped_va_seq)
//   8. LSU pipe2 prefetch sequence: 20 txns (random VA2; count-only in SB)
//   9. LSU STAMO PA-check sequence: 20 txns (not checked by translation_sb)
//  10. Wait 5000 ns for PTW miss paths to settle
//
// EXIT CRITERIA (Phase 5):
//   · UVM_ERROR=0, UVM_FATAL=0
//   · mmu_translation_sb.m_mismatch = 0
//   · mmu_translation_sb.m_total_checked ≥ 200
//
// DESIGN DECISIONS:
//   · ROOT_PPN=0 to match task spec; auto-alloc starts at PPN 16 (L1) and 17 (L0).
//   · Leaf PPNs start at 0x200 (512) — safely above auto-alloc range.
//   · All mapped VAs have bit38=0 → satisfy Sv39 canonical constraint automatically.
//   · c_kind_default (LSU_PIPE0) is disabled inline for pipe1/pipe2/stamo to avoid
//     over-constraint (LRM §18.7.2: with-clause appends, not overrides, class constraints).
//   · Pipe2 rsp txn carries no merged VA yet (Phase 6 enhancement), so
//     write_lsu_p2() counts but does not compare — no scoreboard mismatch expected.
// =============================================================================
`ifndef TEST_MMU_TRANSLATION_SANITY_SVH
`define TEST_MMU_TRANSLATION_SANITY_SVH

// =============================================================================
// ── Helper: IFU mapped-VA sequence ───────────────────────────────────────────
// Sends `num_txn` IFU fetch requests.  VA is selected round-robin from the
// m_va_table[] array injected by the test before calling start().
// =============================================================================
class ifu_mapped_va_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_mapped_va_seq)

  // Injected by test before start() — must have m_table_size valid entries.
  va_t m_va_table[];
  int  m_table_size;

  function new(string name = "ifu_mapped_va_seq");
    super.new(name);
    m_table_size = 0;
  endfunction

  virtual task body();
    ifu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      automatic int idx = i % m_table_size;
      `uvm_create(tr)
      // va[38:0] picks the mapped VA; bit38=0 → c_sv39_canonical (va[62:39]=0) satisfied.
      assert(tr.randomize() with {
        va[38:0]    == m_va_table[idx];  // mapped VA (bit38=0 canonical OK)
        abort        == 1'b0;
        idle_cycles  inside {[0:3]};
      }) else `uvm_fatal(get_full_name(), "ifu_mapped_va_seq: randomize() failed")
      `uvm_send(tr)
    end
  endtask

endclass : ifu_mapped_va_seq

// =============================================================================
// ── Helper: LSU mapped-VA sequence (pipe0 / pipe1) ───────────────────────────
// Sends `num_txn` LSU requests to the channel specified by m_kind.
// m_st_inst controls st/ld flag.
// Note: c_kind_default (LSU_PIPE0) is disabled inline to prevent conflict when
// driving LSU_PIPE1.  This follows the SV LRM §18.7.2 mandate that with-clause
// constraints are APPENDED (not overriding) to class constraints.
// =============================================================================
class lsu_mapped_va_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_mapped_va_seq)

  // Injected by test before start()
  va_t       m_va_table[];
  int        m_table_size;
  lsu_kind_e m_kind;     // LSU_PIPE0 or LSU_PIPE1
  bit        m_st_inst;  // 0=load, 1=store

  function new(string name = "lsu_mapped_va_seq");
    super.new(name);
    m_table_size = 0;
    m_kind       = LSU_PIPE0;
    m_st_inst    = 1'b0;
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      automatic int idx = i % m_table_size;
      `uvm_create(tr)
      // Disable c_kind_default to avoid conflict when targeting non-PIPE0 channels.
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with {
        kind        == m_kind;
        va          == {25'b0, m_va_table[idx]};  // 64-bit: zero-extend 39-bit mapped VA
        abort       == 1'b0;
        st_inst     == m_st_inst;
        idle_cycles  inside {[0:3]};
      }) else `uvm_fatal(get_full_name(), "lsu_mapped_va_seq: randomize() failed")
      `uvm_send(tr)
    end
  endtask

endclass : lsu_mapped_va_seq

// =============================================================================
// ── Helper: LSU pipe2 prefetch sequence ──────────────────────────────────────
// Sends `num_txn` LSU_PIPE2 prefetch requests with random VA2 (28-bit VPN).
// c_kind_default (LSU_PIPE0) must be disabled to avoid over-constraint.
// Pipe2 rsp txn carries no merged VA (Phase 6 enhancement), so the scoreboard
// write_lsu_p2() counts but does not compare PA — no mismatch expected.
// =============================================================================
class lsu_p2_sanity_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_p2_sanity_seq)

  function new(string name = "lsu_p2_sanity_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with {
        kind        == LSU_PIPE2;
        idle_cycles  inside {[0:3]};
      }) else `uvm_fatal(get_full_name(), "lsu_p2_sanity_seq: randomize() failed")
      `uvm_send(tr)
    end
  endtask

endclass : lsu_p2_sanity_seq

// =============================================================================
// ── Helper: LSU STAMO PA-check sequence ──────────────────────────────────────
// Sends `num_txn` LSU_STAMO requests with random physical addresses.
// STAMO is not connected to translation_sb (ap_stamo not wired to SB).
// c_kind_default (LSU_PIPE0) is disabled to avoid over-constraint.
// =============================================================================
class lsu_stamo_sanity_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_stamo_sanity_seq)

  function new(string name = "lsu_stamo_sanity_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with {
        kind == LSU_STAMO;
      }) else `uvm_fatal(get_full_name(), "lsu_stamo_sanity_seq: randomize() failed")
      `uvm_send(tr)
    end
  endtask

endclass : lsu_stamo_sanity_seq

// =============================================================================
// ── Phase 5 Sanity Test ───────────────────────────────────────────────────────
// =============================================================================
class test_mmu_translation_sanity extends test_base;

  `uvm_component_utils(test_mmu_translation_sanity)

  // ── Page table parameters ─────────────────────────────────────────────────
  // ROOT_PPN=0: root page table at PA=0x0.  Auto-alloc starts at PPN 16 (L1)
  // and 17 (L0); leaf PPNs start at 0x200 (512) — safely above auto-alloc.
  localparam bit [27:0] ROOT_PPN     = 28'h0;
  localparam bit [15:0] ROOT_ASID    = 16'h0;
  localparam bit [38:0] VA_BASE      = 39'h10_0000;  // 0x0010_0000 = 2^20
  localparam bit [27:0] PA_PPN_BASE  = 28'h200;      // leaf PPN base (512)

  // ── Transaction counts ────────────────────────────────────────────────────
  localparam int NUM_MAP    = 100;  // 4K pages to map (→ VA table size)
  localparam int NUM_IFU    = 100;  // IFU fetch transactions
  localparam int NUM_LSU_P0 = 100;  // LSU pipe0 load transactions
  localparam int NUM_LSU_P1 =  20;  // LSU pipe1 store transactions
  localparam int NUM_LSU_P2 =  20;  // LSU pipe2 prefetch transactions
  localparam int NUM_STAMO  =  20;  // LSU STAMO PA-check transactions

  // ── Mapped VA table ───────────────────────────────────────────────────────
  va_t m_mapped_va [NUM_MAP];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  virtual task run_test_body();

    cp0_reg_rw_seq          cp0_init;
    cp0_tlb_allinv_seq      tlb_inv;
    pmp_flg_normal_seq      pmp_seq;
    sysmap_region_setup_seq sysmap_seq;
    ifu_mapped_va_seq       ifu_seq;
    lsu_mapped_va_seq       lsu_p0_seq;
    lsu_mapped_va_seq       lsu_p1_seq;
    lsu_p2_sanity_seq       lsu_p2_seq;
    lsu_stamo_sanity_seq    stamo_seq;

    `uvm_info(get_type_name(),
      "=== Phase 5 Sanity Test: MMU Translation STARTED ===", UVM_LOW)

    // ── Step 0: TLB all-invalidate — flush stale entries from previous tests
    `uvm_info(get_type_name(),
      "Step 0: TLB all-invalidate (flush stale L1+L2 TLB entries)", UVM_MEDIUM)
    tlb_inv = cp0_tlb_allinv_seq::type_id::create("tlb_inv");
    tlb_inv.start(m_env.m_cp0.m_sequencer);
    `uvm_info(get_type_name(), "Step 0 done: TLBs flushed", UVM_MEDIUM)

    // ── Step 1: PMP — allow all accesses ──────────────────────────────────
    `uvm_info(get_type_name(), "Step 1a: PMP allow-all (pmp_flg_normal_seq)", UVM_MEDIUM)
    pmp_seq = pmp_flg_normal_seq::type_id::create("pmp_seq");
    pmp_seq.start(m_env.m_pmp.m_sequencer);

    // ── Step 1: SysMap — disable all regions (pure page-table mode) ────────
    `uvm_info(get_type_name(), "Step 1b: SysMap disable-all (sysmap_region_setup_seq)", UVM_MEDIUM)
    sysmap_seq = sysmap_region_setup_seq::type_id::create("sysmap_seq");
    sysmap_seq.start(m_env.m_sysmap_cfg.m_sequencer);

    // ── Step 2: Write SATP0 (Sv39, PPN=0, ASID=0) + ICG_EN=1 + PTW_EN=1 ──
    //           + Set privilege to S-mode (mmu_en requires priv != M-mode)
    `uvm_info(get_type_name(),
      $sformatf("Step 2: SATP0 (Sv39, PPN=0x%07h, ASID=0x%04h) + S-mode + PTW_EN",
        ROOT_PPN, ROOT_ASID), UVM_MEDIUM)
    cp0_init = cp0_reg_rw_seq::type_id::create("cp0_init");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'(ROOT_ASID), 44'(ROOT_PPN)};  // Sv39+PPN+ASID
          priv_mode == 2'b01;   // S-mode: mmu_en = 1 when satp_mode==8
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "cp0_reg_rw_seq randomize() failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);
    `uvm_info(get_type_name(), "Step 2: SATP + CSR init complete", UVM_HIGH)

    // ── Step 3: Build 100 4K page mappings ──────────────────────────────────
    // The shared page_table_builder is used by both the PTW responder (DUT
    // memory interface) and mmu_ref_model.translate() → consistent view.
    `uvm_info(get_type_name(),
      $sformatf("Step 3: Building %0d 4K pages from VA=0x%010h (step=4K), leaf PPN base=0x%07h",
        NUM_MAP, {1'b0, VA_BASE}, PA_PPN_BASE), UVM_MEDIUM)
    begin
      m_env.m_pt_mem.m_builder.set_root(ppn_t'(ROOT_PPN), asid_t'(ROOT_ASID));
      for (int i = 0; i < NUM_MAP; i++) begin
        m_mapped_va[i] = va_t'(VA_BASE) + va_t'(i << 12);  // 4K stride (i*0x1000)
        m_env.m_pt_mem.m_builder.map_4k(
          .va (m_mapped_va[i]),
          .pa (pa_t'({ppn_t'(PA_PPN_BASE + ppn_t'(i)), 12'h000})),
          .v  (1), .r(1), .w(1), .x(1),   // RWX all set (S-mode fetch + load + store OK)
          .u  (0),                          // Supervisor page (U=0)
          .g  (0), .a(1), .d(1)            // A=D=1: avoid "accessed/dirty" warnings
        );
      end
      `uvm_info(get_type_name(),
        $sformatf("Page table built: %0d entries, VA[0]=0x%010h → PPN=0x%07h, VA[99]=0x%010h → PPN=0x%07h",
          NUM_MAP,
          {1'b0, m_mapped_va[0]},      ppn_t'(PA_PPN_BASE),
          {1'b0, m_mapped_va[99]},     ppn_t'(PA_PPN_BASE + 28'd99)),
        UVM_LOW)
    end

    // Brief settle: allow DUT clocks to stabilise after CSR writes.
    #100ns;

    // ── Step 4: IFU fetch sequence (100 txns to mapped VAs) ─────────────────
    // Each fetch VA is drawn round-robin from m_mapped_va[].
    // The DUT IFU→MMU path handles 1-outstanding; driver/monitor FIFO correlated.
    `uvm_info(get_type_name(),
      $sformatf("Step 4: IFU fetch sequence (%0d txns to mapped VAs)", NUM_IFU), UVM_LOW)
    ifu_seq              = ifu_mapped_va_seq::type_id::create("ifu_seq");
    ifu_seq.m_va_table   = new[NUM_MAP];
    ifu_seq.m_table_size = NUM_MAP;
    foreach (m_mapped_va[i]) ifu_seq.m_va_table[i] = m_mapped_va[i];
    ifu_seq.num_txn = NUM_IFU;
    ifu_seq.start(m_env.m_ifu.m_sequencer);
    `uvm_info(get_type_name(),
      $sformatf("Step 4 done: %0d IFU transactions issued", NUM_IFU), UVM_LOW)

    // ── Step 5: LSU pipe0 load sequence (100 txns) ──────────────────────────
    `uvm_info(get_type_name(),
      $sformatf("Step 5: LSU pipe0 load sequence (%0d txns)", NUM_LSU_P0), UVM_LOW)
    lsu_p0_seq              = lsu_mapped_va_seq::type_id::create("lsu_p0_seq");
    lsu_p0_seq.m_va_table   = new[NUM_MAP];
    lsu_p0_seq.m_table_size = NUM_MAP;
    lsu_p0_seq.m_kind       = LSU_PIPE0;
    lsu_p0_seq.m_st_inst    = 1'b0;   // loads (ACC_LOAD)
    foreach (m_mapped_va[i]) lsu_p0_seq.m_va_table[i] = m_mapped_va[i];
    lsu_p0_seq.num_txn = NUM_LSU_P0;
    lsu_p0_seq.start(m_env.m_lsu.m_sequencer);
    `uvm_info(get_type_name(),
      $sformatf("Step 5 done: %0d LSU pipe0 transactions issued", NUM_LSU_P0), UVM_LOW)

    // ── Step 6: LSU pipe1 store sequence (20 txns) ──────────────────────────
    `uvm_info(get_type_name(),
      $sformatf("Step 6: LSU pipe1 store sequence (%0d txns)", NUM_LSU_P1), UVM_LOW)
    lsu_p1_seq              = lsu_mapped_va_seq::type_id::create("lsu_p1_seq");
    lsu_p1_seq.m_va_table   = new[NUM_MAP];
    lsu_p1_seq.m_table_size = NUM_MAP;
    lsu_p1_seq.m_kind       = LSU_PIPE1;
    lsu_p1_seq.m_st_inst    = 1'b1;   // stores (ACC_STORE)
    foreach (m_mapped_va[i]) lsu_p1_seq.m_va_table[i] = m_mapped_va[i];
    lsu_p1_seq.num_txn = NUM_LSU_P1;
    lsu_p1_seq.start(m_env.m_lsu.m_sequencer);
    `uvm_info(get_type_name(),
      $sformatf("Step 6 done: %0d LSU pipe1 transactions issued", NUM_LSU_P1), UVM_LOW)

    // ── Step 7: LSU pipe2 prefetch sequence (20 txns) ───────────────────────
    // Pipe2 rsp txn does not yet carry a merged VA (Phase 6 enhancement).
    // write_lsu_p2() in the SB checks va2==0 and counts-only — no mismatch.
    `uvm_info(get_type_name(),
      $sformatf("Step 7: LSU pipe2 prefetch (%0d txns, count-only in SB)", NUM_LSU_P2), UVM_LOW)
    lsu_p2_seq = lsu_p2_sanity_seq::type_id::create("lsu_p2_seq");
    lsu_p2_seq.num_txn = NUM_LSU_P2;
    lsu_p2_seq.start(m_env.m_lsu.m_sequencer);
    `uvm_info(get_type_name(),
      $sformatf("Step 7 done: %0d pipe2 prefetch transactions issued", NUM_LSU_P2), UVM_LOW)

    // ── Step 8: LSU STAMO PA-check sequence (20 txns) ───────────────────────
    // STAMO drives a physical PA to the MMU secure-attribute check unit.
    // ap_stamo is not wired to translation_sb → no scoreboard contribution.
    `uvm_info(get_type_name(),
      $sformatf("Step 8: LSU STAMO PA-check (%0d txns)", NUM_STAMO), UVM_LOW)
    stamo_seq = lsu_stamo_sanity_seq::type_id::create("stamo_seq");
    stamo_seq.num_txn = NUM_STAMO;
    stamo_seq.start(m_env.m_lsu.m_sequencer);
    `uvm_info(get_type_name(),
      $sformatf("Step 8 done: %0d STAMO transactions issued", NUM_STAMO), UVM_LOW)

    // ── Step 9: Settle — allow outstanding PTW misses to complete ────────────
    `uvm_info(get_type_name(),
      "Step 9: Waiting 10000 ns for PTW miss paths to settle...", UVM_MEDIUM)
    #10000ns;

    // ── Final status report ──────────────────────────────────────────────────
    `uvm_info(get_type_name(),
      $sformatf(
        "=== Phase 5 Sanity Test COMPLETE ===  SB total_checked=%0d  mismatch=%0d",
        m_env.m_translation_sb.m_total_checked,
        m_env.m_translation_sb.m_mismatch),
      UVM_LOW)

    if (m_env.m_translation_sb.m_total_checked < 200)
      `uvm_error(get_type_name(),
        $sformatf("Translation SB checked only %0d transactions (expected ≥200)",
          m_env.m_translation_sb.m_total_checked))

  endtask

endclass : test_mmu_translation_sanity

`endif // TEST_MMU_TRANSLATION_SANITY_SVH
