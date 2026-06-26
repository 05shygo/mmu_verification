`ifndef TEST_MMU_L2TLB_COV_PTW_OFF_V2_SVH
`define TEST_MMU_L2TLB_COV_PTW_OFF_V2_SVH
class test_mmu_l2tlb_cov_ptw_off_v2 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_ptw_off_v2)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void setup_plan();
    super.setup_plan(); phase6e_scenario_id = "L2TLB_PTW_OFF_V2";
    num_txn = 128; timeout_ns = 120_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    // Disable PTW BEFORE vseq runs
    m_cp0_seq_names.push_back("cp0_ptw_disable_seq");
    m_vseq_names.push_back("mmu_l2tlb_ptw_off_vseq");
  endfunction
endclass
`endif
