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

  protected virtual function void setup_phase12_plan();
  endfunction

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
