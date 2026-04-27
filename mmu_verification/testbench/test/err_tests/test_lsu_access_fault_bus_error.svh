// =============================================================================
// Phase 9 generated test wrapper for EXC-007
// Checker: access_fault_sb  Reviewer: B
// =============================================================================
`ifndef TEST_LSU_ACCESS_FAULT_BUS_ERROR_SVH
`define TEST_LSU_ACCESS_FAULT_BUS_ERROR_SVH

class test_lsu_access_fault_bus_error extends phase9_generated_test_base;

  `uvm_component_utils(test_lsu_access_fault_bus_error)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-007";
    p9_seq_desc = "ptw_mem_bus_error_inject_seq + mmu_ptw_thrash_vseq";
    p9_checker = "access_fault_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_bus_error_inject_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_lsu_access_fault_bus_error

`endif // TEST_LSU_ACCESS_FAULT_BUS_ERROR_SVH
