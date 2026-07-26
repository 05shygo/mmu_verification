// =============================================================================
// T-D (toggle_closure_plan v2) — expt_cam ent[N].vpn/iid + same_hit sweep.
// Closes: mmu_l1dtlb_expt_cam 56 uncovered bits — high/low VPN+iid write
// rounds into ent[0..3] (PTW acflt via prefill_mb slot steering, proven
// DTLB_EXPT_ENTRY_PRECISE_001 pattern), JTLB pgflt wr1 path, same_hit_entry,
// port1 hits on ent[3..6]. same_wr_eid documented as waiver candidate.
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_TOGGLE_EXPT_CAM_001_SVH
`define TEST_MMU_L1DTLB_COV_TOGGLE_EXPT_CAM_001_SVH

class test_mmu_l1dtlb_cov_toggle_expt_cam_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_toggle_expt_cam_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TOGGLE_EXPT_CAM_001"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_toggle_expt_cam_vseq";
    p9_checker  = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    num_txn     = 64;
    timeout_ns  = 240_000_000;
    m_vseq_names.push_back("mmu_l1dtlb_toggle_expt_cam_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1DTLB_COV_TOGGLE_EXPT_CAM_001_SVH
