`ifndef TEST_MMU_L2TLB_COV_REQQ_DEPTH_SVH
`define TEST_MMU_L2TLB_COV_REQQ_DEPTH_SVH
class test_mmu_l2tlb_cov_reqq_depth extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_reqq_depth)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_REQQ_DEPTH";
    num_txn = 256; timeout_ns = 150_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_reqq_depth_vseq");
  endfunction
endclass
`endif
