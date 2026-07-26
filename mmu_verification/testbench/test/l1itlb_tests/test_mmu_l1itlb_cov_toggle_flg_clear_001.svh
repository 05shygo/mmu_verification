// =============================================================================
// T-I (toggle_closure_plan §7.4 #8) — iUTLB entryN_flg 1->0 closure.
//
// Target: ct_mmu_iutlb_entry / _fst_entry `utlb_flg[13:0]` 1->0 on flg[3] (X),
// flg[2] (W) and flg[6] (D) for all 32 L1 ITLB entries (~300 direction bits
// that T-A cannot reach because T-A always maps .x(1)/.w(1)/.d(1)).
//
// Mechanism (see the block comment above mmu_l1itlb_toggle_flg_clear_vseq):
// `l2tlb_l1itlb_ref_pavld` is gated only by `final_tlb_hit & final_vld`
// (mmu_l2tlb.sv:1013/1178) — there is NO permission term on the L2->L1I refill
// path.  So an L2 entry that a *load* installed from an X=0/W=0/D=0 PTE is
// handed to the L1 ITLB verbatim on the next instruction-fetch miss, clearing
// those flag bits.  The fetch then takes an instruction page fault, which is
// the architecturally correct outcome and is exactly what the ref model
// predicts, so translation_sb stays quiet (same shape as
// test_mmu_l1itlb_itlb_perm_001).
//
// flg[0] (V) and flg[5] (A) are NOT targeted here: `!flg[0]` and `!flg[5]` both
// page-fault unconditionally in the TWU (twu.sv:1131-1145), so no walk can ever
// refill them as 0.  See doc/toggle_closure_plan.md §8.3 for the waiver.
// =============================================================================
`ifndef TEST_MMU_L1ITLB_COV_TOGGLE_FLG_CLEAR_001_SVH
`define TEST_MMU_L1ITLB_COV_TOGGLE_FLG_CLEAR_001_SVH

class test_mmu_l1itlb_cov_toggle_flg_clear_001 extends phase9_generated_test_base;
  `uvm_component_utils(test_mmu_l1itlb_cov_toggle_flg_clear_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id    = "L1ITLB_COV_TOGGLE_FLG_CLEAR_001";
    p9_seq_desc = "mmu_l1itlb_toggle_flg_clear_vseq";
    p9_checker  = "translation_sb,whitebox_cg";
    p9_reviewer = "B";
    num_txn     = 64;
    timeout_ns  = 240_000_000;
    m_enable_sv39_4k_bringup = 1'b0;  // vseq runs its own do_bringup()
    m_run_misc_init          = 1'b1;
    m_post_drain             = 500ns;
    m_vseq_names.push_back("mmu_l1itlb_toggle_flg_clear_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1ITLB_COV_TOGGLE_FLG_CLEAR_001_SVH
