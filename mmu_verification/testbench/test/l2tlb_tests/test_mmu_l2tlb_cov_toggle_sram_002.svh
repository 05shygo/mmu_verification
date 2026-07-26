// =============================================================================
// T-F2 (toggle_closure_plan v2, wave 2) — L2 SRAM tag_dout readback sweep.
// Closes: l2tlb_tag_dout[134-1:0] (TAG_WIDTH=48 × 8 ways, parity-masked) via
//         TLBWI complementary PPN/ASID/VPN + TLBR readback;
//         final_way_sel_vec[7:0] one-hot per-way hit sweep.
// Extends T-F (test_mmu_l2tlb_cov_toggle_sram_001).
// =============================================================================
`ifndef TEST_MMU_L2TLB_COV_TOGGLE_SRAM_002_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_SRAM_002_SVH

class test_mmu_l2tlb_cov_toggle_sram_002 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_sram_002)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id            = "L2TLB_COV_TOGGLE_SRAM_002";
    p9_seq_desc         = "mmu_l2tlb_toggle_sram_v2_vseq";
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_SRAM_002";
    num_txn = 512; timeout_ns = 240_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_sram_v2_vseq");
  endfunction
endclass

`endif // TEST_MMU_L2TLB_COV_TOGGLE_SRAM_002_SVH
