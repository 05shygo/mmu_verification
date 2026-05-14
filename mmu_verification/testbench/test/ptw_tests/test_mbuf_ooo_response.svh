// =============================================================================
// Phase 9 legacy wrapper for PTW-014.
//
// Stage 6 PTW source-side update:
//   PTW PTE memory is single-outstanding; out-of-order response stimulus is
//   illegal for normal source closure.  This wrapper is retained only as
//   obsolete/illegal-stress metadata and must not run as P0 source closure.
// =============================================================================
`ifndef TEST_MBUF_OOO_RESPONSE_SVH
`define TEST_MBUF_OOO_RESPONSE_SVH

class test_mbuf_ooo_response extends phase9_generated_test_base;

  `uvm_component_utils(test_mbuf_ooo_response)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-014-OBSOLETE-OOO";
    p9_seq_desc = "obsolete-by-spec illegal-stress: PTW PTE memory channel is single-outstanding; OOO response expected removed";
    p9_checker = "not_source_closure; use test_ptw_p0_pde_mbuf_pmp_matrix for MBUF/LSU source closure";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    // Do not inject OOO into normal P0 regression. ptw_mem_ooo_rsp_seq remains
    // a warning-only illegal-stress hook for later constrained negative tests.
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mbuf_ooo_response

`endif // TEST_MBUF_OOO_RESPONSE_SVH
