// =============================================================================
// Phase 11 compatibility wrapper for PTW-014.
//
// Legacy class name is retained for existing regression lists. The expected
// behavior is now legal response-ID based OOO; dedicated closure remains with
// the Phase 12 test_pmbuf_ooo_response_by_id_001 test.
// =============================================================================
`ifndef TEST_MBUF_OOO_RESPONSE_SVH
`define TEST_MBUF_OOO_RESPONSE_SVH

class test_mbuf_ooo_response extends phase11_generated_test_base;

  `uvm_component_utils(test_mbuf_ooo_response)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket = "ptw_lsu_protocol";
    p11_trace_id = "TC-PMBUF-OOO-RESPONSE-BY-ID-COMPAT-001";
    p11_fid = "PTW-014";
    p11_priority = "P0";
    p11_status = "Rescoped-Compat";
    p11_seq_desc = "ptw_mem_ooo_rsp_seq + mmu_ptw_thrash_vseq";
    p11_checker = "cp_lsu_ooo_response + a_lsu_response_matches_outstanding_id";
    p11_reviewer = "A+B";
    ptw_meta_add_req("PTW-LSU-MULTI-002");
    ptw_meta_add_req("LSUOOO-TP-001");
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_ooo_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mbuf_ooo_response

`endif // TEST_MBUF_OOO_RESPONSE_SVH
