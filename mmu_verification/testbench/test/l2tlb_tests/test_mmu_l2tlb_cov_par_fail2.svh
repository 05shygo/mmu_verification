`ifndef TEST_MMU_L2TLB_COV_PAR_FAIL2_SVH
`define TEST_MMU_L2TLB_COV_PAR_FAIL2_SVH
// TASK L2TLB-T17 — COND 869/870/872/1167 parity fail sweep
class test_mmu_l2tlb_cov_par_fail2 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_par_fail2)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_PAR_FAIL2";
    num_txn = 256; timeout_ns = 120_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_par_fail2_vseq");
  endfunction
endclass
`endif
