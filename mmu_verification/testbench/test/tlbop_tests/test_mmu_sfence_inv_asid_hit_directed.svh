// =============================================================================
// Directed coverage for LSU SFENCE.VMA x0, rs2 invalidating a matching ASID.
// =============================================================================
`ifndef TEST_MMU_SFENCE_INV_ASID_HIT_DIRECTED_SVH
`define TEST_MMU_SFENCE_INV_ASID_HIT_DIRECTED_SVH

class test_mmu_sfence_inv_asid_hit_directed extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sfence_inv_asid_hit_directed)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SFENCE-005-DIR-HIT";
    p9_seq_desc = "mmu_inv_asid_hit_directed_vseq";
    p9_checker = "invalidation_sb,l2tlb_tlbop_decode,tlbop_lifecycle_sva";
    p9_reviewer = "A+B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 1000ns;
    m_vseq_names.push_back("mmu_inv_asid_hit_directed_vseq");
  endfunction

endclass : test_mmu_sfence_inv_asid_hit_directed

`endif // TEST_MMU_SFENCE_INV_ASID_HIT_DIRECTED_SVH
