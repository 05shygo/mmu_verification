// =============================================================================
// Phase 9 generated test wrapper for SYSMAP-PTW-003
// Checker: sysmap_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_SYSMAP_NO_WALK_REQUIRED_SVH
`define TEST_SYSMAP_NO_WALK_REQUIRED_SVH

class test_sysmap_no_walk_required extends phase9_generated_test_base;

  `uvm_component_utils(test_sysmap_no_walk_required)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "SYSMAP-PTW-003";
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

endclass : test_sysmap_no_walk_required

`endif // TEST_SYSMAP_NO_WALK_REQUIRED_SVH
