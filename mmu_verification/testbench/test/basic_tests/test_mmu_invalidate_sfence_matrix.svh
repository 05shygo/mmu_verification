// =============================================================================
// MMU UVM Verification — Phase 6 invalidate matrix test
//
// Runs LSU SFENCE.VMA invalidate traffic and checks mmu_invalidate_sb counters.
// Mode select (plusarg INV_MODE):
//   0: INV_ALL
//   1: INV_VA_ALL
//   2: INV_ASID_ALL
//   3: INV_VA_ASID
//   4: stress (rotate all 4 kinds)
//
// Count select (plusarg INV_NUM): number of transactions, default 100.
// =============================================================================
`ifndef TEST_MMU_INVALIDATE_SFENCE_MATRIX_SVH
`define TEST_MMU_INVALIDATE_SFENCE_MATRIX_SVH

class test_mmu_invalidate_sfence_matrix extends test_base;

  `uvm_component_utils(test_mmu_invalidate_sfence_matrix)

  int unsigned m_inv_mode = 0;
  int unsigned m_inv_num  = 100;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    cp0_reg_rw_seq      cp0_init;
    cp0_tlb_allinv_seq  cp0_all_inv;

    tlb_inv_all_seq      seq_all;
    tlb_inv_va_seq       seq_va;
    tlb_inv_asid_seq     seq_asid;
    tlb_inv_va_asid_seq  seq_va_asid;
    sfence_vma_stress_seq seq_stress;

    void'($value$plusargs("INV_MODE=%0d", m_inv_mode));
    void'($value$plusargs("INV_NUM=%0d",  m_inv_num));
    if (m_inv_num == 0) m_inv_num = 1;

    `uvm_info(get_type_name(),
      $sformatf("Phase6 invalidate matrix start: INV_MODE=%0d INV_NUM=%0d",
        m_inv_mode, m_inv_num),
      UVM_LOW)

    // Bring MMU to active S-mode Sv39 context.
    cp0_init = cp0_reg_rw_seq::type_id::create("cp0_init");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'h0, 44'h0};
          priv_mode == 2'b01;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "cp0_init randomize failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);

    // Dispatch selected invalidate mode.
    case (m_inv_mode)
      0: begin
        seq_all = tlb_inv_all_seq::type_id::create("seq_all");
        seq_all.num_txn = m_inv_num;
        seq_all.start(m_env.m_lsu.m_sequencer);
      end
      1: begin
        seq_va = tlb_inv_va_seq::type_id::create("seq_va");
        seq_va.num_txn = m_inv_num;
        seq_va.start(m_env.m_lsu.m_sequencer);
      end
      2: begin
        seq_asid = tlb_inv_asid_seq::type_id::create("seq_asid");
        seq_asid.num_txn = m_inv_num;
        seq_asid.start(m_env.m_lsu.m_sequencer);
      end
      3: begin
        seq_va_asid = tlb_inv_va_asid_seq::type_id::create("seq_va_asid");
        seq_va_asid.num_txn = m_inv_num;
        seq_va_asid.start(m_env.m_lsu.m_sequencer);
      end
      default: begin
        seq_stress = sfence_vma_stress_seq::type_id::create("seq_stress");
        seq_stress.num_txn = m_inv_num;
        seq_stress.start(m_env.m_lsu.m_sequencer);
      end
    endcase

    // Also cover CP0 path once in this test.
    cp0_all_inv = cp0_tlb_allinv_seq::type_id::create("cp0_all_inv");
    cp0_all_inv.start(m_env.m_cp0.m_sequencer);

    #500ns;

    if (m_env.m_invalidate_sb == null)
      `uvm_fatal(get_type_name(), "m_invalidate_sb is null (check en_invalidate_sb)")

    if (m_env.m_invalidate_sb.m_mismatch != 0)
      `uvm_error(get_type_name(),
        $sformatf("Invalidate SB mismatch=%0d", m_env.m_invalidate_sb.m_mismatch))

    if (m_env.m_invalidate_sb.m_n_invalidations == 0)
      `uvm_error(get_type_name(), "Invalidate SB saw zero LSU invalidations")

    `uvm_info(get_type_name(),
      $sformatf("Phase6 invalidate matrix done: n_inv=%0d n_cp0=%0d mismatch=%0d",
        m_env.m_invalidate_sb.m_n_invalidations,
        m_env.m_invalidate_sb.m_n_cp0_all_inv,
        m_env.m_invalidate_sb.m_mismatch),
      UVM_LOW)
  endtask

endclass : test_mmu_invalidate_sfence_matrix

`endif // TEST_MMU_INVALIDATE_SFENCE_MATRIX_SVH
