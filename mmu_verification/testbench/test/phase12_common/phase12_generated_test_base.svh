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

  protected virtual task phase12_cp0_tlb_allinv();
    start_cp0_seq_by_name("cp0_tlb_allinv_seq");
    #100ns;
  endtask

  protected virtual task phase12_set_pmp_raw(input bit [3:0] raw_flg[8]);
    pmp_flg_raw_seq seq;
    seq = pmp_flg_raw_seq::type_id::create("phase12_pmp_raw_seq");
    foreach (raw_flg[i]) seq.raw_flg[i] = raw_flg[i];
    seq.start(m_env.m_pmp.m_sequencer);
    #50ns;
  endtask

  protected virtual task phase12_set_pmp_allow_all();
    bit [3:0] raw_flg[8];
    foreach (raw_flg[i]) raw_flg[i] = 4'h7;
    phase12_set_pmp_raw(raw_flg);
  endtask

  protected virtual task phase12_set_pmp_deny_ptw_reads(input bit [3:0] deny_twu_mask = 4'b1111);
    bit [3:0] raw_flg[8];
    foreach (raw_flg[i]) raw_flg[i] = 4'h7;
    raw_flg[3] = deny_twu_mask[0] ? 4'h6 : 4'h7;
    raw_flg[5] = deny_twu_mask[1] ? 4'h6 : 4'h7;
    raw_flg[6] = deny_twu_mask[2] ? 4'h6 : 4'h7;
    raw_flg[7] = deny_twu_mask[3] ? 4'h6 : 4'h7;
    phase12_set_pmp_raw(raw_flg);
  endtask

  protected virtual task phase12_drive_ifu_rr(input va_t base_va, input int npage, input int n_txn);
    mmu_vseq_ifu_rr_seq seq;
    seq = mmu_vseq_ifu_rr_seq::type_id::create($sformatf("phase12_ifu_rr_%0t", $time));
    seq.m_va_table   = new[npage];
    seq.m_table_size = npage;
    for (int i = 0; i < npage; i++)
      seq.m_va_table[i] = base_va + va_t'(i << 12);
    seq.num_txn = n_txn;
    seq.start(m_env.m_ifu.m_sequencer);
  endtask

  protected virtual task phase12_drive_lsu_rr(
    input va_t base_va,
    input int npage,
    input int n_txn,
    input lsu_kind_e kind = LSU_PIPE0,
    input bit st_inst = 1'b0
  );
    mmu_vseq_lsu_rr_seq seq;
    seq = mmu_vseq_lsu_rr_seq::type_id::create($sformatf("phase12_lsu_rr_%0t", $time));
    seq.m_va_table   = new[npage];
    seq.m_table_size = npage;
    seq.m_kind       = kind;
    seq.m_st_inst    = st_inst;
    for (int i = 0; i < npage; i++)
      seq.m_va_table[i] = base_va + va_t'(i << 12);
    seq.num_txn = n_txn;
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

  protected virtual task phase12_map_hugepage_fixture();
    // Two 1G regions, two 2M regions, and a dedicated 4K window keep page-size
    // coverage and MAEE/FST/SCD paths disjoint.
    m_env.m_pt_mem.m_builder.map_1g(
      .va(39'h0_4000_0000), .pa(40'h0_4000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_1g(
      .va(39'h0_8000_0000), .pa(40'h0_8000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));

    m_env.m_pt_mem.m_builder.map_2m(
      .va(39'h0_2200_0000), .pa(40'h0_0200_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_2m(
      .va(39'h0_2600_0000), .pa(40'h0_0600_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));

    m_env.m_pt_mem.m_builder.map_4k(
      .va(39'h0_3000_1000), .pa(40'h0_0300_1000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env.m_pt_mem.m_builder.map_4k(
      .va(39'h0_3000_2000), .pa(40'h0_0300_2000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    #200ns;
  endtask

  // Drive repeated PTW-read deny / allow windows so `ptw_jtlb_ready` toggles
  // across consecutive cycles (rise/fall/stay_high/stay_low) for cg_ptw_ready_transition.
  //
  // RTL: xbar_pde_ready = ~(&twu_mask[3:0]); ptw_jtlb_ready = pde_cache_ready & !abort_flop.
  // Thus ready=0 needs (all TWU masks set) and/or tlboper abort_flop. PMP deny alone is
  // not enough unless four TWUs are concurrently in PMP-wait; parallel IFU+LSU interleave
  // under deny plus cp0 TLB invalidate (tlboper_ptw_abort path) increases fall/rise/stay_low.
  protected virtual task phase12_pulse_ptw_ready_for_cov(input int unsigned rounds = 6);
    int unsigned r;
    va_t b_ifu, b_lsu;
    for (r = 0; r < rounds; r++) begin
      b_ifu = 39'h10_6000 + va_t'(r << 13);
      b_lsu = 39'h10_E000 + va_t'(r << 13);

      phase12_set_pmp_deny_ptw_reads(4'b1111);
      #150ns;
      phase12_cp0_tlb_allinv();
      #120ns;
      fork
        phase12_drive_ifu_rr(b_ifu, 12, 72);
        phase12_drive_lsu_interleave3(b_lsu, 12, 96);
      join
      #600ns;
      phase12_set_pmp_allow_all();
      #280ns;

      phase12_set_pmp_deny_ptw_reads(4'b1010);
      fork
        phase12_drive_ifu_rr(b_ifu + 39'h2000, 8, 48);
        phase12_drive_lsu_rr(b_lsu + 39'h2000, 8, 64, LSU_PIPE0, 1'b0);
      join
      #400ns;
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
