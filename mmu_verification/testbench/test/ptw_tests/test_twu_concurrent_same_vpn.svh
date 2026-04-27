// =============================================================================
// Phase 9 generated test wrapper for PTW-012
// Checker: ptw_walk_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_TWU_CONCURRENT_SAME_VPN_SVH
`define TEST_TWU_CONCURRENT_SAME_VPN_SVH

class test_twu_concurrent_same_vpn extends phase9_generated_test_base;

  `uvm_component_utils(test_twu_concurrent_same_vpn)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-012";
    p9_seq_desc = "ptw_mem_normal_rsp_seq + mmu_ptw_thrash_vseq";
    p9_checker = "ptw_walk_cg";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_twu_concurrent_same_vpn

`endif // TEST_TWU_CONCURRENT_SAME_VPN_SVH
