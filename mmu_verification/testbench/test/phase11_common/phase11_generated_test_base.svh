// =============================================================================
// MMU UVM Verification — Phase 11 generated test base
//
// Purpose:
//   Provide a Phase 11-specific thin-wrapper base on top of the existing
//   phase9_generated_test_base execution helpers. Phase 11 wrappers only need
//   to describe traceability metadata plus the direct sequences / vseqs that
//   should be composed for bug-hunt or PTW->LSU protocol regression.
//
// Notes:
//   - This base intentionally reuses the stable bringup and sequence dispatch
//     logic from phase9_generated_test_base.
//   - Metadata is re-labeled for Phase 11 so logs and sidecar docs stay
//     aligned with bug-hunt / protocol trace IDs instead of Phase 9 wrapper
//     numbering.
// =============================================================================
`ifndef PHASE11_GENERATED_TEST_BASE_SVH
`define PHASE11_GENERATED_TEST_BASE_SVH

class phase11_generated_test_base extends phase9_generated_test_base;

  `uvm_component_utils(phase11_generated_test_base)

  string p11_bucket;
  string p11_trace_id;
  string p11_fid;
  string p11_priority;
  string p11_status;
  string p11_seq_desc;
  string p11_checker;
  string p11_reviewer;
  string p11_req_ids[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
  endfunction

  virtual function void ptw_meta_add_req(string req_id);
    p11_req_ids.push_back(req_id);
  endfunction

  protected function string p11_req_ids_string();
    string reqs;
    reqs = "";
    foreach (p11_req_ids[i])
      reqs = {reqs, (i == 0) ? "" : "|", p11_req_ids[i]};
    return reqs;
  endfunction

  virtual function void setup_plan();
    super.setup_plan();

    p11_bucket   = "phase11";
    p11_trace_id = "UNSPECIFIED";
    p11_fid      = "";
    p11_priority = "P1";
    p11_status   = "Planned";
    p11_seq_desc = "";
    p11_checker  = "";
    p11_reviewer = "B";
    p11_req_ids.delete();

    setup_phase11_plan();

    // Keep the inherited Phase 9 fields synchronized so shared helper logic
    // and summaries continue to work without touching the lower-level flow.
    p9_tc_id    = p11_trace_id;
    p9_seq_desc = p11_seq_desc;
    p9_checker  = p11_checker;
    p9_reviewer = p11_reviewer;
  endfunction

  virtual task run_test_body();
    setup_plan();
    void'($value$plusargs("NB_TXNS=%0d", num_txn));

    `uvm_info(get_type_name(),
      $sformatf("Phase11 generated test start: bucket=%s trace_id=%s fid=%s priority=%s status=%s reqs=%s checker=%s reviewer=%s seq=%s",
        p11_bucket, p11_trace_id, p11_fid, p11_priority, p11_status,
        p11_req_ids_string(), p11_checker, p11_reviewer, p11_seq_desc),
      UVM_LOW)

    `uvm_info(get_type_name(),
      $sformatf("PTW_SCENARIO_META tc_id=%s scenario_id=%s requirement_ids=%s context={phase11_bucket=%s ; legacy_wrapper=%s ; seq=%s ; checker=%s} levels={} expected={%s} actual={phase11_compat_wrapper} result=%s provisional=1",
        p11_trace_id, p11_trace_id, p11_req_ids_string(), p11_bucket,
        get_type_name(), p11_seq_desc, p11_checker, p11_checker, p11_status),
      UVM_NONE)

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

endclass : phase11_generated_test_base

`endif // PHASE11_GENERATED_TEST_BASE_SVH
