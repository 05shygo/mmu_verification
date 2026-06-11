// =============================================================================
// MMU UVM Verification -- PTW LSU-ID Phase 12 directed test base
//
// Purpose:
//   Host the directed tests from doc/ptw_uvm_review/ptw_lsu_id phase 12 without
//   reusing the older MAEE/TWU Phase12 metadata meaning as closure evidence.
//   The execution helpers still come from phase12_generated_test_base and
//   phase9_generated_test_base.
// =============================================================================
`ifndef PHASE12_LSU_ID_TEST_BASE_SVH
`define PHASE12_LSU_ID_TEST_BASE_SVH

class phase12_lsu_id_test_base extends phase12_generated_test_base;

  `uvm_component_utils(phase12_lsu_id_test_base)

  string p12_lsu_req_ids[$];
  string p12_lsu_testpoint_ids[$];
  string p12_lsu_responder_mode;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_lsu_id_plan();
  endfunction

  protected function void phase12_lsu_id_set_meta(
    input string trace_id,
    input string priority_str,
    input string seq_desc,
    input string checker,
    input string status = "Implemented",
    input string fid = "",
    input string reviewer = "A+B",
    input string bucket = "ptw_lsu_id_phase12"
  );
    p12_bucket   = bucket;
    p12_trace_id = trace_id;
    p12_fid      = fid;
    p12_priority = priority_str;
    p12_status   = status;
    p12_seq_desc = seq_desc;
    p12_checker  = checker;
    p12_reviewer = reviewer;
  endfunction

  protected function void phase12_lsu_id_add_req(input string req_id);
    p12_lsu_req_ids.push_back(req_id);
  endfunction

  protected function void phase12_lsu_id_add_tp(input string tp_id);
    p12_lsu_testpoint_ids.push_back(tp_id);
  endfunction

  protected function string phase12_lsu_id_req_string();
    string s;
    s = "";
    foreach (p12_lsu_req_ids[i])
      s = {s, (i == 0) ? "" : "|", p12_lsu_req_ids[i]};
    return s;
  endfunction

  protected function string phase12_lsu_id_tp_string();
    string s;
    s = "";
    foreach (p12_lsu_testpoint_ids[i])
      s = {s, (i == 0) ? "" : "|", p12_lsu_testpoint_ids[i]};
    return s;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "ptw_lsu_id_phase12";
    p12_trace_id = "UNSPECIFIED";
    p12_fid      = "";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "";
    p12_checker  = "";
    p12_reviewer = "A+B";
    p12_lsu_responder_mode = "";
    p12_lsu_req_ids.delete();
    p12_lsu_testpoint_ids.delete();

    setup_phase12_lsu_id_plan();

    p9_tc_id    = p12_trace_id;
    p9_seq_desc = p12_seq_desc;
    p9_checker  = p12_checker;
    p9_reviewer = p12_reviewer;
  endfunction

  protected virtual task phase12_lsu_id_print_meta();
    `uvm_info(get_type_name(),
      $sformatf({"Phase12 PTW-LSU-ID directed test start: bucket=%s trace_id=%s ",
                 "fid=%s priority=%s status=%s reqs=%s testpoints=%s checker=%s ",
                 "reviewer=%s seq=%s responder=%s"},
        p12_bucket, p12_trace_id, p12_fid, p12_priority, p12_status,
        phase12_lsu_id_req_string(), phase12_lsu_id_tp_string(),
        p12_checker, p12_reviewer, p12_seq_desc, p12_lsu_responder_mode),
      UVM_LOW)

    `uvm_info(get_type_name(),
      $sformatf({"PTW_META phase=12 bucket=%s tc_id=%s priority=%s ",
                 "requirement_ids=%s testpoint_ids=%s responder_mode=%s ",
                 "seq=%s checker=%s status=%s"},
        p12_bucket, p12_trace_id, p12_priority, phase12_lsu_id_req_string(),
        phase12_lsu_id_tp_string(), p12_lsu_responder_mode, p12_seq_desc,
        p12_checker, p12_status),
      UVM_NONE)

    `uvm_info(get_type_name(),
      $sformatf({"PTW_SCENARIO_META tc_id=%s scenario_id=%s requirement_ids=%s ",
                 "context={phase12_bucket=%s ; testpoints=%s ; responder=%s ; ",
                 "seq=%s ; checker=%s} levels={} expected={%s} ",
                 "actual={phase12_lsu_id_directed_test} result=%s provisional=1"},
        p12_trace_id, p12_trace_id, phase12_lsu_id_req_string(),
        p12_bucket, phase12_lsu_id_tp_string(), p12_lsu_responder_mode,
        p12_seq_desc, p12_checker, p12_checker, p12_status),
      UVM_NONE)
  endtask

  protected virtual task phase12_lsu_id_execute_sequence_lists();
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

  protected virtual task phase12_lsu_id_drive_pde_burst(
    input va_t base_va,
    input pa_t base_pa,
    input int unsigned npage,
    input int unsigned n_txn,
    input bit drive_ifu,
    input bit drive_pipe0,
    input bit drive_pipe1,
    input bit drive_pipe2,
    input int unsigned bursts = 2,
    input int unsigned rsp_min = 0,
    input int unsigned rsp_max = 1
  );
    phase12_map_4k_window(base_va, npage, base_pa);
    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(rsp_min, rsp_max, 0);

    for (int unsigned b = 0; b < bursts; b++) begin
      phase12_cp0_tlb_allinv();
      fork
        if (drive_ifu)
          phase12_drive_ifu_rr(base_va, npage, n_txn, 1'b1);
        if (drive_pipe0)
          phase12_drive_lsu_rr(base_va, npage, n_txn, LSU_PIPE0, 1'b0, 1'b1);
        if (drive_pipe1)
          phase12_drive_lsu_rr(base_va, npage, n_txn, LSU_PIPE1, 1'b1, 1'b1);
        if (drive_pipe2)
          phase12_drive_lsu_rr(base_va, npage, n_txn, LSU_PIPE2, 1'b0, 1'b1);
      join
      #400ns;
    end

    phase12_config_ptw_responder(1, 4, 0);
  endtask

  virtual task run_test_body();
    setup_plan();
    void'($value$plusargs("NB_TXNS=%0d", num_txn));
    phase12_lsu_id_print_meta();
    phase12_lsu_id_execute_sequence_lists();
  endtask

endclass : phase12_lsu_id_test_base

`endif // PHASE12_LSU_ID_TEST_BASE_SVH
