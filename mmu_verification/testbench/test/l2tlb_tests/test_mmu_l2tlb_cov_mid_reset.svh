`ifndef TEST_MMU_L2TLB_COV_MID_RESET_SVH
`define TEST_MMU_L2TLB_COV_MID_RESET_SVH
// ═══════════════════════════════════════════════════════════════════════════════
// TASK L2TLB-T11 — cpurst_b mid-test reset toggle coverage
//
// PURPOSE: Close cpurst_b 1→0 toggle gap (31 module instances).
// The L2TLB DUT's cpurst_b goes 0→1 at time 0 (initial reset release) but
// 1→0 never occurs without a mid-test reset pulse. This test uses tb_top's
// TLBOP reset arc injector to produce a real cpurst_b=0 pulse mid-operation.
//
// RUN INSTRUCTION:
//   make covp TEST=test_mmu_l2tlb_cov_mid_reset \
//        PLUSARGS="+MMU_TLBOP_RESET_MODE=tlbwr_wfg +MMU_TLBOP_RESET_HOLD_CYCLES=5"
//
// Supported reset modes (choose one):
//   tlbp_wfg, tlbr_wfg, tlbwi_wfg, tlbwr_wfg, tlbwr_wrtag,
//   invasid_rd, invasid_wfc, invasid_wt, invva_rd, invva_cmp, invva_wr, invva_wt
//
// MECHANISM:
//   tb_top.sv:130-186 tlbop_reset_arc_injector watches TLBOP FSM states.
//   When the FSM state matches the configured mode, tb_top drives:
//     1. cpurst_b = 1'b0  (producing 1→0 transition on ALL DUT instances)
//     2. wait hold_cycles
//     3. cpurst_b = 1'b1  (producing 0→1 transition)
//   The vseq drives matching TLB operations (TLBWR/TLBWI/TLBR) and
//   synchronises via assert_mid_test_reset() handshake.
//
// COVERAGE TARGETS:
//   - cpurst_b 1→0 toggle: mmu_l2tlb, mmu_l2tlb_reqq, mmu_l2tlb_reqq_entry,
//                           mmu_l2tlb_mb, mmu_l2tlb_mb_entry, mmu_l2tlb_rrpv_wbuf
//   - FSM PFU_CHK→PFU_IDLE (reset path at line 1347)
// ═══════════════════════════════════════════════════════════════════════════════
class test_mmu_l2tlb_cov_mid_reset extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_mid_reset)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_MID_RESET";
    num_txn = 256; timeout_ns = 300_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    // Include TLBOP sequences so the vseq can drive TLBWR/TLBWI/TLBR
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbwr_reset_target_seq");
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbwi_reset_target_seq");
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbr_reset_target_seq");
    m_vseq_names.push_back("mmu_l2tlb_mid_reset_vseq");
  endfunction
endclass
`endif
