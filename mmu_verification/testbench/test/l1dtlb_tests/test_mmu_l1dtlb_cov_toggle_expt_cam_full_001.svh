// =============================================================================
// T-D2 (toggle_closure_plan v2, wave 2) — expt_cam full sweep, ent[4..7].
// Closes: expt_cam ent[4..7] vpn[26:0] / iid[6:0] both dirs via acflt writes;
//         wr1_vld path for ent[4..7]; same_hit_entry on ent[5].
// Extends T-D (test_mmu_l1dtlb_cov_toggle_expt_cam_001).
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_TOGGLE_EXPT_CAM_FULL_001_SVH
`define TEST_MMU_L1DTLB_COV_TOGGLE_EXPT_CAM_FULL_001_SVH

class test_mmu_l1dtlb_cov_toggle_expt_cam_full_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_toggle_expt_cam_full_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TOGGLE_EXPT_CAM_FULL_001"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_toggle_expt_cam_full_vseq";
    p9_checker  = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    num_txn     = 64;
    timeout_ns  = 300_000_000;
    m_vseq_names.push_back("mmu_l1dtlb_toggle_expt_cam_full_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1DTLB_COV_TOGGLE_EXPT_CAM_FULL_001_SVH
