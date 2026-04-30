// =============================================================================
// Phase 12 generated test wrapper for TC-MBUF-READY-GATE-001
// F-ID: F4.NEW.10  Priority: P1  Status: Implemented
// Checker: sva_mbuf_waits_twu_ready + cg_twu_data_ready_per_stage
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_MBUF_READY_GATE_NO_EARLY_VLD_SVH
`define TEST_MMU_MBUF_READY_GATE_NO_EARLY_VLD_SVH

class test_mmu_mbuf_ready_gate_no_early_vld extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_mbuf_ready_gate_no_early_vld)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "mbuf_gating";
    p12_trace_id = "TC-MBUF-READY-GATE-001";
    p12_fid      = "F4.NEW.10";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 slow 1G/2M/4K walks for stage-ready gating";
    p12_checker  = "sva_mbuf_waits_twu_ready + cg_twu_data_ready_per_stage";
    p12_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();
    phase12_config_ptw_responder(32, 64, 0);

    repeat (2) begin
      phase12_drive_ifu_rr(39'h0_4000_0000, 1, 1);
      phase12_drive_lsu_rr(39'h0_2200_0000, 1, 1, LSU_PIPE0, 1'b0);
      phase12_drive_lsu_rr(39'h0_3000_1000, 1, 1, LSU_PIPE1, 1'b1);
      phase12_cp0_tlb_allinv();

      phase12_drive_ifu_rr(39'h0_8000_0000, 1, 1);
      phase12_drive_lsu_rr(39'h0_2600_0000, 1, 1, LSU_PIPE0, 1'b0);
      phase12_drive_lsu_rr(39'h0_3000_2000, 1, 1, LSU_PIPE1, 1'b1);
      phase12_cp0_tlb_allinv();
    end

    phase12_config_ptw_responder(1, 4, 0);

    #(m_post_drain);
  endtask

endclass : test_mmu_mbuf_ready_gate_no_early_vld

`endif // TEST_MMU_MBUF_READY_GATE_NO_EARLY_VLD_SVH
