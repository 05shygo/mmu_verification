// =============================================================================
// Phase 12 generated test wrapper for TC-PDE-CACHE-HIT-L2-001
// F-ID: F4.NEW.8  Priority: P1  Status: Implemented
// Checker: sva_twu_skip_stage_on_hit + cg_xbar_hit_level  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PDE_CACHE_HIT_L2_SKIP_SCD_SVH
`define TEST_MMU_PDE_CACHE_HIT_L2_SKIP_SCD_SVH

class test_mmu_pde_cache_hit_l2_skip_scd extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_pde_cache_hit_l2_skip_scd)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pde_hit_level";
    p12_trace_id = "TC-PDE-CACHE-HIT-L2-001";
    p12_fid      = "F4.NEW.8";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "ptw_page_table_build_2m_seq + mmu_huge_page_mix_vseq";
    p12_checker  = "sva_twu_skip_stage_on_hit + cg_xbar_hit_level";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 800ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();
    phase12_drive_lsu_rr(39'h0_2200_0000, 1, 1, LSU_PIPE0, 1'b0);
    phase12_cp0_tlb_allinv();
    repeat (3)
      phase12_drive_lsu_rr(39'h0_2200_0000, 1, 1, LSU_PIPE0, 1'b0);

    #(m_post_drain);
  endtask

endclass : test_mmu_pde_cache_hit_l2_skip_scd

`endif // TEST_MMU_PDE_CACHE_HIT_L2_SKIP_SCD_SVH
