`ifndef TEST_MMU_L1ITLB_ITLB_STATE_MIX_001_SVH
`define TEST_MMU_L1ITLB_ITLB_STATE_MIX_001_SVH

class test_mmu_l1itlb_itlb_state_mix_001 extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_l1itlb_itlb_state_mix_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "ITLB_STATE_MIX_001";
    p9_seq_desc = "mmu_l1itlb_state_mix_vseq";
    p9_checker = "translation_sb,whitebox_cg";
    p9_reviewer = "B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_l1itlb_state_mix_vseq");
  endfunction

endclass : test_mmu_l1itlb_itlb_state_mix_001

`endif // TEST_MMU_L1ITLB_ITLB_STATE_MIX_001_SVH
