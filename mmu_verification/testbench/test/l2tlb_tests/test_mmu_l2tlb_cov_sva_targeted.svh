`ifndef TEST_MMU_L2TLB_COV_SVA_TARGETED_SVH
`define TEST_MMU_L2TLB_COV_SVA_TARGETED_SVH
class test_mmu_l2tlb_cov_sva_targeted extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_sva_targeted)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_SVA_TARGETED";
    num_txn = 256; timeout_ns = 600_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_sva_targeted_vseq");
  endfunction
endclass
`endif
