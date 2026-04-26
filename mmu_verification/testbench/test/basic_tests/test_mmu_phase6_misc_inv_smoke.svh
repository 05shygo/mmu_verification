// =============================================================================
// MMU UVM Verification — Phase 6 misc + invalidate smoke
//
// Joint smoke for Stage 5 (A/B collaboration boundary):
//   - B path: LSU invalidation traffic + invalidate scoreboard checks
//   - A path: misc flush/expt/hpcp sequence path remains functional
// =============================================================================
`ifndef TEST_MMU_PHASE6_MISC_INV_SMOKE_SVH
`define TEST_MMU_PHASE6_MISC_INV_SMOKE_SVH

class test_mmu_phase6_misc_inv_smoke extends test_base;

  `uvm_component_utils(test_mmu_phase6_misc_inv_smoke)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    cp0_reg_rw_seq      cp0_init;
    tlb_inv_all_seq     inv_seq;
    misc_init_seq       misc_init;
    misc_rtu_flush_seq  flush_seq;
    misc_rtu_expt_seq   expt_seq;

    `uvm_info(get_type_name(), "Phase6 misc+inv smoke start", UVM_LOW)

    cp0_init = cp0_reg_rw_seq::type_id::create("cp0_init");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'h0, 44'h0};
          priv_mode == 2'b01;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "cp0_init randomize failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);

    misc_init = misc_init_seq::type_id::create("misc_init");
    misc_init.start(m_env.m_misc.m_sequencer);

    inv_seq = tlb_inv_all_seq::type_id::create("inv_seq");
    inv_seq.num_txn = 16;
    inv_seq.start(m_env.m_lsu.m_sequencer);

    repeat (10) begin
      flush_seq = misc_rtu_flush_seq::type_id::create($sformatf("flush_seq_%0d", $time));
      flush_seq.start(m_env.m_misc.m_sequencer);
      #(10ns);
    end

    expt_seq = misc_rtu_expt_seq::type_id::create("expt_seq");
    if (!expt_seq.randomize() with { bad_vpn inside {[27'h10:27'h1ff]}; })
      `uvm_fatal(get_type_name(), "expt_seq randomize failed")
    expt_seq.start(m_env.m_misc.m_sequencer);

    #500ns;

    if (m_env.m_invalidate_sb == null)
      `uvm_fatal(get_type_name(), "m_invalidate_sb is null")
    if (m_env.m_invalidate_sb.m_mismatch != 0)
      `uvm_error(get_type_name(),
        $sformatf("Invalidate mismatch=%0d in misc+inv smoke", m_env.m_invalidate_sb.m_mismatch))
    if (m_env.m_invalidate_sb.m_n_invalidations == 0)
      `uvm_error(get_type_name(), "No invalidation observed in misc+inv smoke")

    `uvm_info(get_type_name(),
      $sformatf("Phase6 misc+inv smoke done: n_inv=%0d mismatch=%0d",
        m_env.m_invalidate_sb.m_n_invalidations,
        m_env.m_invalidate_sb.m_mismatch),
      UVM_LOW)
  endtask

endclass : test_mmu_phase6_misc_inv_smoke

`endif // TEST_MMU_PHASE6_MISC_INV_SMOKE_SVH
