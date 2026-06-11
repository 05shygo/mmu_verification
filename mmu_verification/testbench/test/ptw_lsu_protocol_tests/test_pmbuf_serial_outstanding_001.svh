// =============================================================================
// Phase 11 compatibility wrapper retained for test_pmbuf_serial_outstanding_001.
// Rescoped target: TC-PMBUF-MULTI-OUTSTANDING-ID-001
// Checker: cp_lsu_two_outstanding + PTW_SOURCE_SB_LSU_ID_COVERAGE
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
    p11_trace_id = "TC-PMBUF-MULTI-OUTSTANDING-ID-001";
    p11_fid      = "F4.42a";
    p11_priority = "P0";
    p11_status   = "Rescoped-Compat";
    p11_seq_desc = "ptw_mem_slow_rsp_seq + lsu_mapped_pipe0_back2back_seq";
    p11_checker  = "cp_lsu_two_outstanding + PTW_SOURCE_SB_LSU_ID_COVERAGE.two_outstanding";
    p11_reviewer = "A+B";
    ptw_meta_add_req("PTW-LSU-MULTI-001");
    ptw_meta_add_req("LSUMULTI-TP-001");
    ptw_meta_add_req("CREDIT-TP-001");
    num_txn      = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    // Keep the zero-idle pressure, but use the SV39 4K window mapped by
    // do_sv39_4k_bringup().  Random/unmapped LSU VAs can page-fault, skip
    // L1DTLB refill, and leave this protocol test measuring exception-drain
    // behavior instead of PTW->LSU multi-ID outstanding behavior.
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_back2back_seq");
  endfunction

endclass : test_pmbuf_serial_outstanding_001

`endif // TEST_PMBUF_SERIAL_OUTSTANDING_001_SVH
