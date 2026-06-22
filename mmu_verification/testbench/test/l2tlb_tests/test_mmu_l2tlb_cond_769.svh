`ifndef TEST_MMU_L2TLB_COND_769_SVH
`define TEST_MMU_L2TLB_COND_769_SVH
class test_mmu_l2tlb_cond_769 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cond_769)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void setup_plan();
    super.setup_plan(); phase6e_scenario_id = "L2TLB_COND_769";
    num_txn = 256; timeout_ns = 120_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_cond_769_vseq");
  endfunction
endclass
`endif
