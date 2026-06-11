// =============================================================================
// Phase 11 compatibility wrapper retained for test_pmbuf_no_tag_001.
// Rescoped target: TC-PMBUF-REQ-RESP-ID-BASIC-001
// Checker: request ID legality + response ID route
// =============================================================================
`ifndef TEST_PMBUF_NO_TAG_001_SVH
`define TEST_PMBUF_NO_TAG_001_SVH

class test_pmbuf_no_tag_001 extends phase11_generated_test_base;

  `uvm_component_utils(test_pmbuf_no_tag_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "ptw_lsu_protocol";
    p11_trace_id = "TC-PMBUF-REQ-RESP-ID-BASIC-001";
    p11_fid      = "F4.42b";
    p11_priority = "P0";
    p11_status   = "Rescoped-Compat";
    p11_seq_desc = "ptw_mem_normal_rsp_seq + lsu_mapped_pipe0_rr_seq";
    p11_checker  = "a_lsu_req_id_legal_on_fire + cp_lsu_rsp_id_match + PTW_SOURCE_SB_LSU_ID_COVERAGE.req_rsp_id_match";
    p11_reviewer = "A+B";
    ptw_meta_add_req("PTW-LSU-ID-001");
    ptw_meta_add_req("PTW-LSU-ID-002");
    ptw_meta_add_req("LSUID-TP-001");
    ptw_meta_add_req("LSUID-TP-002");
    num_txn      = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    // Use the mapped SV39 4K bringup window for this PTW->LSU protocol test.
    // A random pipe0 VA can repeatedly page-fault and never refill L1DTLB,
    // which turns the ID route check into an exception-drain scenario.
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_rr_seq");
  endfunction

endclass : test_pmbuf_no_tag_001

`endif // TEST_PMBUF_NO_TAG_001_SVH
