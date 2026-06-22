`ifndef TEST_MMU_L2TLB_COV_MB_COND_SVH
`define TEST_MMU_L2TLB_COV_MB_COND_SVH
// TASK L2TLB-T20 — MB entry COND (line 110/135/215/220/227) + MB toggle coverage
class test_mmu_l2tlb_cov_mb_cond extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_mb_cond)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_MB_COND";
    num_txn = 256; timeout_ns = 180_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_mb_cond_vseq");
  endfunction
endclass
`endif
