// =============================================================================
// Phase 11 generated test wrapper for TC-PMBUF-SERIAL-OUTSTANDING-001
// F-ID: F4.42a  Priority: P0  Status: Planned
// Checker: sva_single_outstanding + sva_lsu_req_stable_until_vld  Reviewer: A+B
// =============================================================================
`ifndef TEST_PMBUF_SERIAL_OUTSTANDING_001_SVH
`define TEST_PMBUF_SERIAL_OUTSTANDING_001_SVH

class test_pmbuf_serial_outstanding_001 extends phase11_generated_test_base;

  `uvm_component_utils(test_pmbuf_serial_outstanding_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "ptw_lsu_protocol";
    p11_trace_id = "TC-PMBUF-SERIAL-OUTSTANDING-001";
    p11_fid      = "F4.42a";
    p11_priority = "P0";
    p11_status   = "Planned";
    p11_seq_desc = "ptw_mem_slow_rsp_seq + lsu_back2back_seq";
    p11_checker  = "sva_single_outstanding + sva_lsu_req_stable_until_vld";
    p11_reviewer = "A+B";
    num_txn      = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_lsu_seq_names.push_back("lsu_back2back_seq");
  endfunction

endclass : test_pmbuf_serial_outstanding_001

`endif // TEST_PMBUF_SERIAL_OUTSTANDING_001_SVH
