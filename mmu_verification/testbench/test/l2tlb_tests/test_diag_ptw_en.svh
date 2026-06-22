`ifndef TEST_DIAG_PTW_EN_SVH
`define TEST_DIAG_PTW_EN_SVH
class test_diag_ptw_en extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_diag_ptw_en)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void setup_plan();
    super.setup_plan(); phase6e_scenario_id = "DIAG_PTW_EN";
    num_txn = 128; timeout_ns = 60_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_diag_ptw_en_vseq");
  endfunction
endclass
`endif
