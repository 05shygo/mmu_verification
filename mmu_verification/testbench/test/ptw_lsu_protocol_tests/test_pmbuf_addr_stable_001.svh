// =============================================================================
// Phase 11 compatibility wrapper retained for test_pmbuf_addr_stable_001.
// Rescoped target: grant hold keeps addr/id/size stable until request fire.
// Checker: grant-hold SVA and grant-wait SVA cover.
// =============================================================================
`ifndef TEST_PMBUF_ADDR_STABLE_001_SVH
`define TEST_PMBUF_ADDR_STABLE_001_SVH

class test_pmbuf_addr_stable_001 extends phase11_generated_test_base;

  `uvm_component_utils(test_pmbuf_addr_stable_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "ptw_lsu_protocol";
    p11_trace_id = "TC-PMBUF-GRANT-HOLD-ADDR-ID-001";
    p11_fid      = "F4.42a";
    p11_priority = "P0";
    p11_status   = "Rescoped-Compat";
    p11_seq_desc = "ptw_mem_slow_rsp_seq + ptw_mem_grant_backpressure_seq + lsu_mapped_pipe0_rr_seq";
    p11_checker  = "a_lsu_req_hold_stable_until_grant + a_lsu_req_hold_matches_recorded_values + cp_lsu_grant_wait";
    p11_reviewer = "A+B";
    ptw_meta_add_req("PTW-LSU-GRANT-001");
    ptw_meta_add_req("PTW-LSU-GRANT-002");
    ptw_meta_add_req("LSUGRANT-TP-001");
    num_txn      = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_grant_backpressure_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_rr_seq");
  endfunction

endclass : test_pmbuf_addr_stable_001

`endif // TEST_PMBUF_ADDR_STABLE_001_SVH
