// =============================================================================
// Phase 12 generated test wrapper for TC-PDE-CACHE-HIT-L3-001
// F-ID: F4.NEW.8  Priority: P1  Status: Implemented
// Checker: sva_twu_skip_stage_on_hit + cg_xbar_hit_level  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PDE_CACHE_HIT_L3_SKIP_THD_SVH
`define TEST_MMU_PDE_CACHE_HIT_L3_SKIP_THD_SVH

class test_mmu_pde_cache_hit_l3_skip_thd extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_pde_cache_hit_l3_skip_thd)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pde_hit_level";
    p12_trace_id = "TC-PDE-CACHE-HIT-L3-001";
    p12_fid      = "F4.NEW.8";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "ptw_page_table_build_1g_seq + mmu_huge_page_mix_vseq";
    p12_checker  = "sva_twu_skip_stage_on_hit + cg_xbar_hit_level";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_page_table_build_1g_seq");
    m_vseq_names.push_back("mmu_huge_page_mix_vseq");
  endfunction

endclass : test_mmu_pde_cache_hit_l3_skip_thd

`endif // TEST_MMU_PDE_CACHE_HIT_L3_SKIP_THD_SVH
