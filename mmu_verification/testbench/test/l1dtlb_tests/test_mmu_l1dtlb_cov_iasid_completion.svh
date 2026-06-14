`ifndef TEST_MMU_L1DTLB_COV_IASID_COMPLETION_SVH
`define TEST_MMU_L1DTLB_COV_IASID_COMPLETION_SVH
// TARGET: ct_mmu_tlboper tlbiasid_cur_st transition IASID_WT->IASID_IDLE
// RTL condition: arb_tlboper_grant && tlb_inv_done during IASID_WT (line 603)
// Requires: jtlb_tlboper_asid_hit=1 (JTLB has matching ASID, non-global entries)
// Strategy: pre-populate JTLB via page walks, then ASID invalidate immediately
// Tracker: MMU-P14-ISSUE-022 (FSM functional gap closure)
class test_mmu_l1dtlb_cov_iasid_completion extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_iasid_completion)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_IASID_COMPLETION_001"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "l1dtlb_directed_vseq";
    num_txn = 64; timeout_ns = 300_000_000;
  endfunction
endclass
`endif
