`ifndef TEST_MMU_L2TLB_COV_TOGGLE_SWEEP_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_SWEEP_SVH
// TASK L2TLB-T21 — Toggle coverage: High PPN/PA bits and internal signals
class test_mmu_l2tlb_cov_toggle_sweep extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_sweep)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_SWEEP";
    num_txn = 256; timeout_ns = 180_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_sweep_vseq");
  endfunction
endclass
`endif
