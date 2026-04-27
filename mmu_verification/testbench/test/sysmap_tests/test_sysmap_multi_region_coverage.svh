// =============================================================================
// Phase 9 generated test wrapper for SYSMAP-PTW-002
// Checker: sysmap_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_SYSMAP_MULTI_REGION_COVERAGE_SVH
`define TEST_SYSMAP_MULTI_REGION_COVERAGE_SVH

class test_sysmap_multi_region_coverage extends phase9_generated_test_base;

  `uvm_component_utils(test_sysmap_multi_region_coverage)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "SYSMAP-PTW-002";
    p9_seq_desc = "sysmap_hit_cross_tlb_seq + mmu_smoke_vseq";
    p9_checker = "sysmap_cg";
    p9_reviewer = "A+B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_sysmap_seq_names.push_back("sysmap_hit_cross_tlb_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_sysmap_multi_region_coverage

`endif // TEST_SYSMAP_MULTI_REGION_COVERAGE_SVH
