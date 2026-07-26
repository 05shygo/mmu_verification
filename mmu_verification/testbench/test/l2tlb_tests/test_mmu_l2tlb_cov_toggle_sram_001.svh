// =============================================================================
// T-F (toggle_closure_plan v2) — L2 tag/data SRAM bit toggles, Steps 1..5.
// Closes: ct_mmu_l2tlb_tag_array way G bits (tag bit0 ×25) + ASID[15:14]/VPN
// high bits, ct_mmu_l2tlb_data_array FLG[4]-class (way bit130 ×10) + PPN high
// bits, mmu_l2tlb tag/data dout buses. Two complementary rounds per step
// (ASID FFFF<->0000; PPN high<->low; G=1<->0; PGS 2M/1G<->4K).
// =============================================================================
`ifndef TEST_MMU_L2TLB_COV_TOGGLE_SRAM_001_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_SRAM_001_SVH

class test_mmu_l2tlb_cov_toggle_sram_001 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_sram_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id            = "L2TLB_COV_TOGGLE_SRAM_001";
    p9_seq_desc         = "mmu_l2tlb_toggle_sram_vseq";
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_SRAM_001";
    num_txn = 256; timeout_ns = 180_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_sram_vseq");
  endfunction
endclass

`endif // TEST_MMU_L2TLB_COV_TOGGLE_SRAM_001_SVH
