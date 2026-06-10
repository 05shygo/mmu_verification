// =============================================================================
// MMU UVM Verification — Phase 12 generated test base
//
// Purpose:
//   Provide a Phase 12-specific thin-wrapper base on top of the existing
//   phase9_generated_test_base execution helpers. Phase 12 wrappers only need
//   to describe traceability metadata plus the direct sequences / vseqs that
//   should be composed for MAEE / PTW-ready / TWU bypass verification.
//
// Notes:
//   - This base intentionally reuses the stable bringup and sequence dispatch
//     logic from phase9_generated_test_base.
//   - Metadata is re-labeled for Phase 12 so logs and sidecar docs stay
//     aligned with the v4 feature buckets instead of the Phase 9 wrapper IDs.
// =============================================================================
`ifndef PHASE12_GENERATED_TEST_BASE_SVH
`define PHASE12_GENERATED_TEST_BASE_SVH

class phase12_generated_test_base extends phase9_generated_test_base;

  `uvm_component_utils(phase12_generated_test_base)

  string p12_bucket;
  string p12_trace_id;
  string p12_fid;
  string p12_priority;
  string p12_status;
  string p12_seq_desc;
  string p12_checker;
  string p12_reviewer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Phase12 whitebox covergroup gate depends on m_cg_whitebox; keep it enabled
  // even if inherited/global config was modified by unrelated tests.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (m_cfg != null)
      m_cfg.en_whitebox_cg = 1'b1;
  endfunction

  protected virtual function void setup_phase12_plan();
  endfunction

  protected virtual task phase12_config_ptw_responder(
    input int unsigned rsp_min = 1,
    input int unsigned rsp_max = 8,
    input int unsigned bus_error_rate_permille = 0
  );
    if ((m_env == null) || (m_env.m_ptw_mem == null) || (m_env.m_ptw_mem.m_responder == null))
      `uvm_fatal(get_type_name(), "PTW responder handle is null")

    m_env.m_ptw_mem.m_responder.m_rsp_delay_min           = rsp_min;
    m_env.m_ptw_mem.m_responder.m_rsp_delay_max           = rsp_max;
    m_env.m_ptw_mem.m_responder.m_bus_error_rate_permille = bus_error_rate_permille;
  endtask

  protected virtual task phase12_wait_for_quiescent(
    input string ctx = "phase12_quiescent",
    input int unsigned max_cycles = 262144,
    input int unsigned stable_cycles = 16
  );
    if (m_env == null)
      `uvm_fatal(get_type_name(), "phase12_wait_for_quiescent: m_env is null")
    m_env.wait_for_quiescent_midtest(ctx, max_cycles, stable_cycles);
    if ((m_env.m_credit_sb != null) && m_env.m_credit_sb.last_drain_timed_out())
      `uvm_error(get_type_name(),
        $sformatf("phase12_wait_for_quiescent timed out while waiting for MMU internal idle: %s",
          ctx))
  endtask

  protected virtual task phase12_cp0_tlb_allinv(
    input bit wait_before = 1'b0,
    input bit wait_after  = 1'b0
  );
    if (wait_before)
      phase12_wait_for_quiescent("phase12_pre_cp0_tlb_allinv");
    start_cp0_seq_by_name("cp0_tlb_allinv_seq");
    if (wait_after)
      phase12_wait_for_quiescent("phase12_post_cp0_tlb_allinv");
    else
      #100ns;
  endtask

  protected virtual task phase12_set_pmp_raw(input bit [3:0] raw_flg[8]);
    pmp_flg_raw_seq seq;
    seq = pmp_flg_raw_seq::type_id::create("phase12_pmp_raw_seq");
    foreach (raw_flg[i]) seq.raw_flg[i] = raw_flg[i];
    seq.start(m_env.m_pmp.m_sequencer);
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    #50ns;
  endtask

  protected virtual task phase12_set_pmp_allow_all();
    bit [3:0] raw_flg[8];
    foreach (raw_flg[i]) raw_flg[i] = 4'h7;
    phase12_set_pmp_raw(raw_flg);
  endtask

  protected virtual task phase12_recover_after_pmp_deny(
    input int unsigned drain_cycles = 1600
  );
    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(1, 4, 0);
    repeat (drain_cycles) @(m_env.m_ptw_mem.vif.monitor_cb);
    phase12_cp0_tlb_allinv();
    repeat (drain_cycles / 2) @(m_env.m_ptw_mem.vif.monitor_cb);
  endtask

  protected virtual task phase12_set_pmp_deny_ptw_reads(
    input bit [3:0] deny_twu_mask = 4'b1111,
    input bit       deny_read_perm = 1'b0
  );
    bit [3:0] raw_flg[8];
    bit [3:0] deny_flg;
    foreach (raw_flg[i]) raw_flg[i] = 4'h7;
    // TWU PMP checks select permission from the original miss type, not from
    // the PTW memory-read operation: fetch->X, load/PFU->R, store->W.
    // Ready/mask pressure tests must not accidentally turn PFU/load walkers
    // into access faults, so the default keeps R allowed and denies W/X only.
    // Tests whose intent is PTW access-error injection pass deny_read_perm.
    deny_flg = deny_read_perm ? 4'h6 : 4'h1;
    raw_flg[3] = deny_twu_mask[0] ? deny_flg : 4'h7;
    raw_flg[5] = deny_twu_mask[1] ? deny_flg : 4'h7;
    raw_flg[6] = deny_twu_mask[2] ? deny_flg : 4'h7;
    raw_flg[7] = deny_twu_mask[3] ? deny_flg : 4'h7;
    phase12_set_pmp_raw(raw_flg);
  endtask

  protected virtual task phase12_drive_ifu_rr(
    input va_t base_va,
    input int npage,
    input int n_txn,
    input bit zero_idle = 1'b0
  );
    mmu_vseq_ifu_rr_seq seq;
    seq = mmu_vseq_ifu_rr_seq::type_id::create($sformatf("phase12_ifu_rr_%0t", $time));
    seq.m_va_table   = new[npage];
    seq.m_table_size = npage;
    for (int i = 0; i < npage; i++)
      seq.m_va_table[i] = base_va + va_t'(i << 12);
    seq.num_txn     = n_txn;
    seq.m_zero_idle = zero_idle;
    seq.start(m_env.m_ifu.m_sequencer);
  endtask

  protected virtual task phase12_drive_lsu_rr(
    input va_t base_va,
    input int npage,
    input int n_txn,
    input lsu_kind_e kind = LSU_PIPE0,
    input bit st_inst = 1'b0,
    input bit zero_idle = 1'b0
  );
    mmu_vseq_lsu_rr_seq seq;
    seq = mmu_vseq_lsu_rr_seq::type_id::create($sformatf("phase12_lsu_rr_%0t", $time));
    seq.m_va_table   = new[npage];
    seq.m_table_size = npage;
    seq.m_kind       = kind;
    seq.m_st_inst    = st_inst;
    for (int i = 0; i < npage; i++)
      seq.m_va_table[i] = base_va + va_t'(i << 12);
    seq.num_txn     = n_txn;
    seq.m_zero_idle = zero_idle;
    seq.start(m_env.m_lsu.m_sequencer);
  endtask

  protected virtual task phase12_drive_lsu_interleave3(
    input va_t base_va,
    input int npage,
    input int n_txn
  );
    mmu_vseq_lsu_interleave3_seq seq;
    seq = mmu_vseq_lsu_interleave3_seq::type_id::create($sformatf("phase12_lsu_itr3_%0t", $time));
    seq.m_va_table   = new[npage];
    seq.m_table_size = npage;
    for (int i = 0; i < npage; i++)
      seq.m_va_table[i] = base_va + va_t'(i << 12);
    seq.num_txn = n_txn;
    seq.start(m_env.m_lsu.m_sequencer);
  endtask

  protected virtual task phase12_map_4k_window(
    input va_t base_va,
    input int unsigned npage,
    input pa_t base_pa = 40'h0_2010_0000
  );
    for (int unsigned i = 0; i < npage; i++) begin
      m_env.m_pt_mem.m_builder.map_4k(
        .va(base_va + va_t'(i << 12)),
        .pa(base_pa + pa_t'(i << 12)),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    #100ns;
  endtask

  protected virtual task phase12_map_hugepage_fixture();
    // Two 1G regions, two 2M regions, and a dedicated 4K window keep page-size
    // coverage and MAEE/FST/SCD paths disjoint.
    m_env.m_pt_mem.m_builder.map_1g(
      .va(39'h0_4000_0000), .pa(40'h0_4000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_1g(
      .va(39'h0_8000_0000), .pa(40'h0_8000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_1g(
      .va(39'h0_C000_0000), .pa(40'h0_C000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));

    m_env.m_pt_mem.m_builder.map_2m(
      .va(39'h0_2200_0000), .pa(40'h0_0200_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_2m(
      .va(39'h0_2600_0000), .pa(40'h0_0600_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_2m(
      .va(39'h0_1200_0000), .pa(40'h0_1200_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));

    m_env.m_pt_mem.m_builder.map_4k(
      .va(39'h0_3000_1000), .pa(40'h0_0300_1000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_4k(
      .va(39'h0_3000_2000), .pa(40'h0_0300_2000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    #200ns;
  endtask

  // twu.sv twu_mask |= fst_pmp_wait|scd_pmp_wait|thd_pmp_wait|... ; fst_pmp_wait is
  // fst_pmp_vld & !fst_pmp_grant when PTW table walk waits on PMP for that TWU.
  // one_to_four_xbar: xbar_pde_ready = ~(&twu_mask[3:0]); PTW ptw_jtlb_ready follows that.
  // To pull ptw_jtlb_ready low we need all four TWUs with twu_mask==1 concurrently — drive
  // four independent miss sources (IFU + LSU_PIPE0/1/2) in parallel under full PTW-read PMP deny.
  protected virtual task phase12_concurrent_four_twus_under_full_pmp_deny(
    input va_t region_base,
    input int npage = 22,
    input int n_txn = 100
  );
    phase12_cp0_tlb_allinv();
    #150ns;
    phase12_set_pmp_deny_ptw_reads(4'b1111);
    #120ns;
    fork
      phase12_drive_ifu_rr(region_base,                  npage, n_txn);
      phase12_drive_lsu_rr(region_base + 39'h0200_0000, npage, n_txn, LSU_PIPE0, 1'b0);
      phase12_drive_lsu_rr(region_base + 39'h0400_0000, npage, n_txn, LSU_PIPE1, 1'b1);
      phase12_drive_lsu_rr(region_base + 39'h0600_0000, npage, n_txn, LSU_PIPE2, 1'b0);
    join
    phase12_recover_after_pmp_deny(1600);
  endtask

  protected virtual task phase12_map_four_twu_pressure_window(
    input va_t region_base,
    input int unsigned npage,
    input pa_t pa_base
  );
    phase12_map_4k_window(region_base,                 npage, pa_base + 40'h0000_0000);
    phase12_map_4k_window(region_base + 39'h0200_0000, npage, pa_base + 40'h0200_0000);
    phase12_map_4k_window(region_base + 39'h0400_0000, npage, pa_base + 40'h0400_0000);
    phase12_map_4k_window(region_base + 39'h0600_0000, npage, pa_base + 40'h0600_0000);
  endtask

  // Create real four-TWU backpressure with cold L1/L2 misses.
  //
  // PTW ready is only pulled low when all four TWUs are masked.  Read-permission
  // deny windows tend to complete as access faults and can miss the multi-stage
  // walk overlap.  This pressure burst keeps PMP allow-all, slows PTW memory,
  // invalidates TLBs before every burst, and drives IFU + LSU0/1/2 to widely
  // separated 4K windows so the accesses are cold L1/L2 misses instead of PDE
  // cache or TLB hits.
  protected virtual task phase12_concurrent_four_twus_slow_miss_pressure(
    input va_t region_base,
    input int unsigned npage = 128,
    input int unsigned n_txn = 256,
    input int unsigned bursts = 4,
    input pa_t region_pa_base = 40'h0_0100_0000
  );
    for (int unsigned b = 0; b < bursts; b++) begin
      va_t burst_base;
      pa_t pa_base;
      burst_base = region_base + va_t'(b << 28);
      pa_base    = region_pa_base + pa_t'(b << 28);

      phase12_map_four_twu_pressure_window(burst_base, npage, pa_base);
      phase12_set_pmp_allow_all();
      phase12_config_ptw_responder(96, 192, 0);
      phase12_cp0_tlb_allinv();
      #120ns;

      fork
        phase12_drive_ifu_rr(burst_base,                 npage, n_txn, 1'b1);
        phase12_drive_lsu_rr(burst_base + 39'h0200_0000, npage, n_txn, LSU_PIPE0, 1'b0, 1'b1);
        phase12_drive_lsu_rr(burst_base + 39'h0400_0000, npage, n_txn, LSU_PIPE1, 1'b1, 1'b1);
        phase12_drive_lsu_rr(burst_base + 39'h0600_0000, npage, n_txn, LSU_PIPE2, 1'b0, 1'b1);
      join

      // Keep sampling after the request streams finish; late PTW stages often
      // hold the all-mask condition for the ready stay_low/fall/rise bins.
      #1200ns;
      phase12_config_ptw_responder(1, 4, 0);
      phase12_set_pmp_allow_all();
      #400ns;
    end
  endtask

  // Drive repeated PTW-read deny / allow windows so `ptw_jtlb_ready` toggles
  // across consecutive cycles (rise/fall/stay_high/stay_low) for cg_ptw_ready_transition.
  //
  // RTL: xbar_pde_ready = ~(&twu_mask[3:0]); ptw_jtlb_ready = pde_cache_ready & !abort_flop.
  protected virtual task phase12_pulse_ptw_ready_for_cov(input int unsigned rounds = 6);
    int unsigned r, effective_rounds;
    va_t b_ifu, b_lsu, four_base;
    pa_t pa_base;
    effective_rounds = (rounds > 3) ? 3 : rounds;
    for (r = 0; r < effective_rounds; r++) begin
      // Keep recovery and pulse-pressure traffic away from standalone pressure
      // windows. Reusing a VA can leave a valid DUT TLB/PDE-cache translation
      // from the first map while a later remap creates a different PTW result.
      b_ifu    = 39'h0_5000_0000 + va_t'(r << 25);
      b_lsu    = 39'h0_5800_0000 + va_t'(r << 25);
      // Each pressure call spans two 256MB bursts plus four per-TWU windows.
      // Keep outer rounds 512MB apart so late PTW/TLB completions can never be
      // compared against a freshly remapped copy of the same VA.
      four_base = 39'h1_9000_0000 + (va_t'(r) << 29);
      pa_base  = 40'h0_3000_0000 + pa_t'(r << 24);

      phase12_concurrent_four_twus_slow_miss_pressure(
        four_base, 128, 256, 2, 40'h0_0100_0000 + (pa_t'(r) << 29));

      // Recovery / partial-mask phase to create ready rise and additional
      // non-all-mask samples after the low window.
      phase12_map_4k_window(b_ifu + 39'h2000, 32, pa_base + 40'h0010_0000);
      phase12_map_4k_window(b_lsu + 39'h2000, 32, pa_base + 40'h0020_0000);
      phase12_config_ptw_responder(48, 96, 0);
      phase12_cp0_tlb_allinv();
      phase12_set_pmp_allow_all();
      #80ns;
      fork
        phase12_drive_ifu_rr(b_ifu + 39'h2000, 32, 128, 1'b1);
        phase12_drive_lsu_rr(b_lsu + 39'h2000, 32, 160, LSU_PIPE0, 1'b0, 1'b1);
      join
      #450ns;
      phase12_config_ptw_responder(1, 4, 0);
      phase12_set_pmp_allow_all();
      #220ns;
    end
    phase12_set_pmp_allow_all();
  endtask

  virtual function void setup_plan();
    super.setup_plan();

    p12_bucket   = "phase12";
    p12_trace_id = "UNSPECIFIED";
    p12_fid      = "";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "";
    p12_checker  = "";
    p12_reviewer = "B";

    setup_phase12_plan();

    p9_tc_id    = p12_trace_id;
    p9_seq_desc = p12_seq_desc;
    p9_checker  = p12_checker;
    p9_reviewer = p12_reviewer;
  endfunction

  virtual task run_test_body();
    setup_plan();

    `uvm_info(get_type_name(),
      $sformatf("Phase12 generated test start: bucket=%s trace_id=%s fid=%s priority=%s status=%s checker=%s reviewer=%s seq=%s",
        p12_bucket, p12_trace_id, p12_fid, p12_priority, p12_status, p12_checker, p12_reviewer, p12_seq_desc),
      UVM_LOW)

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");

    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    foreach (m_cp0_seq_names[i])    start_cp0_seq_by_name(m_cp0_seq_names[i]);
    foreach (m_pmp_seq_names[i])    start_pmp_seq_by_name(m_pmp_seq_names[i]);
    foreach (m_sysmap_seq_names[i]) start_sysmap_seq_by_name(m_sysmap_seq_names[i]);
    foreach (m_misc_seq_names[i])   start_misc_seq_by_name(m_misc_seq_names[i]);
    foreach (m_ptw_seq_names[i])    start_ptw_seq_by_name(m_ptw_seq_names[i]);
    foreach (m_ifu_seq_names[i])    start_ifu_seq_by_name(m_ifu_seq_names[i]);
    foreach (m_lsu_seq_names[i])    start_lsu_seq_by_name(m_lsu_seq_names[i]);
    foreach (m_vseq_names[i])       start_vseq_by_name(m_vseq_names[i]);

    #(m_post_drain);
  endtask

endclass : phase12_generated_test_base

`endif // PHASE12_GENERATED_TEST_BASE_SVH
