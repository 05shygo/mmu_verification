`ifndef TEST_MMU_L1DTLB_COV_WFG_IDLE_SWEEP_SVH
`define TEST_MMU_L1DTLB_COV_WFG_IDLE_SWEEP_SVH
// TARGET: mmu_l1dtlb_mb_entry state_r transition STATE_WFG->STATE_IDLE
// RTL condition: abort_this_cyc && !(issue_sel && issue_grant) (line 148)
// Tracker: MMU-P14-ISSUE-022 (FSM functional gap closure)
// Strategy: sweep flush timing across many cycle offsets with long PTW delay
// so that WFG entries see flush without simultaneous L2TLB grant.
class test_mmu_l1dtlb_cov_wfg_idle_sweep extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_wfg_idle_sweep)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_WFG_IDLE_SWEEP_001"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "l1dtlb_directed_vseq";
    num_txn = 64; timeout_ns = 300_000_000;
  endfunction
endclass
`endif
