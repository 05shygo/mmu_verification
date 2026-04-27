// =============================================================================
// Phase 9 generated test wrapper for PTW-022
// Checker: translation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_PTE_GLOBAL_BIT_ASID_SVH
`define TEST_PTE_GLOBAL_BIT_ASID_SVH

class test_pte_global_bit_asid extends phase9_generated_test_base;

  `uvm_component_utils(test_pte_global_bit_asid)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-022";
    p9_seq_desc = "mmu_asid_context_switch_vseq";
    p9_checker = "translation_sb";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_asid_context_switch_vseq");
  endfunction

endclass : test_pte_global_bit_asid

`endif // TEST_PTE_GLOBAL_BIT_ASID_SVH
