`ifndef TEST_MMU_L1ITLB_COV_FSM_WFG_FORCE_001_SVH
`define TEST_MMU_L1ITLB_COV_FSM_WFG_FORCE_001_SVH

class test_mmu_l1itlb_cov_fsm_wfg_force_001 extends phase9_generated_test_base;
  `uvm_component_utils(test_mmu_l1itlb_cov_fsm_wfg_force_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "L1ITLB_COV_FSM_WFG_FORCE_001";
    p9_seq_desc = "ifu_sequential_fetch_seq";
    p9_checker = "coherency_sb";
    p9_reviewer = "B";
    num_txn = 2;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ifu_seq_names.push_back("ifu_sequential_fetch_seq");
  endfunction
endclass

`endif
