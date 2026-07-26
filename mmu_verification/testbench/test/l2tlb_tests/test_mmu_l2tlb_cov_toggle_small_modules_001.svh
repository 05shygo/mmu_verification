// =============================================================================
// T-H (toggle_closure_plan v2) — L2 reqq/mb small-module concurrency sweep.
// Closes: mmu_l2tlb_reqq d_req_type/bypass_grant_vec[8:4]/entry ASID,
// mmu_l2tlb_mb entry_rdy/ffr_oh/grant[8:4]/queue_id, mb_entry queue_id/eid/
// type, reqq_entry asid/type — via 8 stacked dTLB misses + 2 ITLB misses per
// round under ASID FFFF<->0000. rrpv_wbuf full (H-2) deliberately excluded
// pending reachability analysis (plan §T-H).
// =============================================================================
`ifndef TEST_MMU_L2TLB_COV_TOGGLE_SMALL_MODULES_001_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_SMALL_MODULES_001_SVH

class test_mmu_l2tlb_cov_toggle_small_modules_001 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_small_modules_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id            = "L2TLB_COV_TOGGLE_SMALL_MODULES_001";
    p9_seq_desc         = "mmu_l2tlb_toggle_small_modules_vseq";
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_SMALL_MODULES_001";
    num_txn = 256; timeout_ns = 180_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_small_modules_vseq");
  endfunction
endclass

`endif // TEST_MMU_L2TLB_COV_TOGGLE_SMALL_MODULES_001_SVH
