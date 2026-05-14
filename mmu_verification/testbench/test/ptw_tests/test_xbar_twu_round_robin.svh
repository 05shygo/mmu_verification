// =============================================================================
// Phase 9 legacy wrapper for XBAR-002.
//
// Stage 6 PTW source-side update:
//   The old round-robin expectation is obsolete-by-spec.  PTW xbar dispatch is
//   hash/ready/mask based; this wrapper is retained only as legacy stress and
//   must not be counted as PTW source-side closure.
// =============================================================================
`ifndef TEST_XBAR_TWU_ROUND_ROBIN_SVH
`define TEST_XBAR_TWU_ROUND_ROBIN_SVH

class test_xbar_twu_round_robin extends phase9_generated_test_base;

  `uvm_component_utils(test_xbar_twu_round_robin)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "XBAR-002-OBSOLETE-RR";
    p9_seq_desc = "obsolete-by-spec: old round-robin expectation removed; mmu_stress_all_ports_vseq retained as hash/ready stress";
    p9_checker = "not_source_closure; use test_ptw_p0_pde_mbuf_pmp_matrix and PTW-SVA-XBAR cover";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_xbar_twu_round_robin

`endif // TEST_XBAR_TWU_ROUND_ROBIN_SVH
