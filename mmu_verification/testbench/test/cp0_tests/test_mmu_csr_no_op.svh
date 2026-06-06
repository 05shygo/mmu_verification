// =============================================================================
// Phase 9 generated test wrapper for TC-CSR-011
// Checker: coherency_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_CSR_NO_OP_SVH
`define TEST_MMU_CSR_NO_OP_SVH

class test_mmu_csr_no_op extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_csr_no_op)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // no_op is checked by its dedicated CP0/coherency paths; translation_sb does
  // not model the DUT's no_op gating semantics precisely enough for this case.
  virtual function void build_phase(uvm_phase phase);
    mmu_top_cfg tcfg;
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", tcfg) || tcfg == null) begin
      tcfg = mmu_top_cfg::type_id::create("m_cfg");
      uvm_config_db #(mmu_top_cfg)::set(this, "*", "m_cfg", tcfg);
    end
    tcfg.en_translation_sb = 1'b0;
    super.build_phase(phase);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-CSR-011";
    p9_seq_desc = "cp0_no_op_assert_seq + mmu_smoke_vseq";
    p9_checker = "coherency_sb";
    p9_reviewer = "B";
    num_txn = 8;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_no_op_assert_seq");
    m_cp0_seq_names.push_back("cp0_no_op_clear_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_csr_no_op

`endif // TEST_MMU_CSR_NO_OP_SVH
