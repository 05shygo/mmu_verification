`ifndef TEST_MMU_L2TLB_COV_COND_1234B_SVH
`define TEST_MMU_L2TLB_COV_COND_1234B_SVH
class test_mmu_l2tlb_cov_cond_1234b extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_cond_1234b)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void setup_plan();
    super.setup_plan(); phase6e_scenario_id = "L2TLB_COND_1234B";
    num_txn = 64; timeout_ns = 60_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_cond_1234b_vseq");
  endfunction
endclass
`endif
