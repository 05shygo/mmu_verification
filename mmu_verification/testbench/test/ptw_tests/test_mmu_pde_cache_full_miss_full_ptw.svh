// =============================================================================
// Phase 12 generated test wrapper for TC-PDE-CACHE-MISS-001
// F-ID: F4.NEW.8  Priority: P1  Status: Implemented
// Checker: cg_xbar_hit_level  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PDE_CACHE_FULL_MISS_FULL_PTW_SVH
`define TEST_MMU_PDE_CACHE_FULL_MISS_FULL_PTW_SVH

class test_mmu_pde_cache_full_miss_full_ptw extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_pde_cache_full_miss_full_ptw)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pde_hit_level";
    p12_trace_id = "TC-PDE-CACHE-MISS-001";
    p12_fid      = "F4.NEW.8";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "ptw_mem_normal_rsp_seq + mmu_ptw_thrash_vseq";
    p12_checker  = "cg_xbar_hit_level";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 800ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();
    phase12_drive_lsu_rr(39'h0_3000_1000, 1, 1, LSU_PIPE0, 1'b0);
    phase12_cp0_tlb_allinv(1'b1, 1'b1);
    phase12_drive_lsu_rr(39'h0_3000_2000, 1, 1, LSU_PIPE1, 1'b1);

    #(m_post_drain);
  endtask

endclass : test_mmu_pde_cache_full_miss_full_ptw

`endif // TEST_MMU_PDE_CACHE_FULL_MISS_FULL_PTW_SVH
