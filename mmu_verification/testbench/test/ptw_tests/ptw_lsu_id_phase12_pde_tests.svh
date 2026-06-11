// =============================================================================
// PTW LSU-ID Phase 12 PDE consecutive update directed tests
// =============================================================================
`ifndef PTW_LSU_ID_PHASE12_PDE_TESTS_SVH
`define PTW_LSU_ID_PHASE12_PDE_TESTS_SVH

class test_pde_consecutive_l1_update_plru_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pde_consecutive_l1_update_plru_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PDE-CONSECUTIVE-L1-UPDATE-PLRU-001", "P0",
      "cold 4K LSU pipe0 burst with 0/1-cycle PTW response",
      "cp_pde_consecutive_refill + cp_pde_l1_consecutive_advance + same-cycle PLRU way SVA",
      "Implemented", "F4.43a", "A+B", "ptw_lsu_id_phase12_pde");
    p12_lsu_responder_mode = "fast_rsp_l1_consecutive_update";
    phase12_lsu_id_add_req("PDE-UPD-020");
    phase12_lsu_id_add_tp("PDEUPD-TP-001");
    phase12_lsu_id_add_tp("PDEUPD-TP-009");
    num_txn = 96;
    m_post_drain = 1800ns;
  endfunction
  virtual task run_test_body();
    setup_plan();
    void'($value$plusargs("NB_TXNS=%0d", num_txn));
    phase12_lsu_id_print_meta();
    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();
    phase12_lsu_id_drive_pde_burst(
      39'h0_6400_0000, 40'h0_6400_0000, 64, 96,
      1'b0, 1'b1, 1'b0, 1'b0, 3, 0, 1);
    #(m_post_drain);
  endtask
endclass : test_pde_consecutive_l1_update_plru_001

class test_pde_consecutive_l2_update_plru_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pde_consecutive_l2_update_plru_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PDE-CONSECUTIVE-L2-UPDATE-PLRU-001", "P0",
      "cold 4K IFU+LSU burst across a separate root VPN window",
      "cp_pde_consecutive_refill + cp_pde_l2_consecutive_advance + same-cycle PLRU way SVA",
      "Implemented", "F4.43b", "A+B", "ptw_lsu_id_phase12_pde");
    p12_lsu_responder_mode = "fast_rsp_l2_consecutive_update";
    phase12_lsu_id_add_req("PDE-UPD-021");
    phase12_lsu_id_add_tp("PDEUPD-TP-002");
    phase12_lsu_id_add_tp("PDEUPD-TP-009");
    num_txn = 96;
    m_post_drain = 1800ns;
  endfunction
  virtual task run_test_body();
    setup_plan();
    void'($value$plusargs("NB_TXNS=%0d", num_txn));
    phase12_lsu_id_print_meta();
    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();
    phase12_lsu_id_drive_pde_burst(
      39'h0_7000_0000, 40'h0_7000_0000, 96, 96,
      1'b1, 1'b1, 1'b0, 1'b0, 3, 0, 1);
    #(m_post_drain);
  endtask
endclass : test_pde_consecutive_l2_update_plru_001

class test_pde_consecutive_mixed_update_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pde_consecutive_mixed_update_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PDE-CONSECUTIVE-MIXED-UPDATE-001", "P1",
      "two cold 4K windows with IFU/LSU pipe mix and fast PTW response",
      "mixed L1/L2 back-to-back updates keep update vectors mutually exclusive",
      "Implemented", "F4.43c", "A+B", "ptw_lsu_id_phase12_pde");
    p12_lsu_responder_mode = "fast_rsp_mixed_l1_l2_update";
    phase12_lsu_id_add_req("PDE-UPD-020");
    phase12_lsu_id_add_req("PDE-UPD-021");
    phase12_lsu_id_add_tp("PDEUPD-TP-003");
    num_txn = 128;
    m_post_drain = 2200ns;
  endfunction
  virtual task run_test_body();
    setup_plan();
    void'($value$plusargs("NB_TXNS=%0d", num_txn));
    phase12_lsu_id_print_meta();
    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();
    phase12_lsu_id_drive_pde_burst(
      39'h0_7800_0000, 40'h0_7800_0000, 64, 80,
      1'b1, 1'b1, 1'b0, 1'b0, 2, 0, 1);
    phase12_lsu_id_drive_pde_burst(
      39'h0_7c00_0000, 40'h0_7c00_0000, 64, 80,
      1'b0, 1'b0, 1'b1, 1'b1, 2, 0, 1);
    #(m_post_drain);
  endtask
endclass : test_pde_consecutive_mixed_update_001

class test_pde_abort_drain_no_update_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pde_abort_drain_no_update_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PDE-ABORT-DRAIN-NO-UPDATE-001", "P0",
      "ptw_mem_slow_rsp_seq + mmu_sfence_during_walk_vseq",
      "ptw_abort_drain response carries ID but does not update PDE cache",
      "Implemented", "F4.43d", "A+B", "ptw_lsu_id_phase12_pde");
    p12_lsu_responder_mode = "slow_rsp_sfence_abort_no_pde_update";
    phase12_lsu_id_add_req("PTW-LSU-ABORT-002");
    phase12_lsu_id_add_req("PDE-UPD-022");
    phase12_lsu_id_add_tp("ABDRN-TP-004");
    phase12_lsu_id_add_tp("PDEUPD-TP-005");
    num_txn = 64;
    m_post_drain = 2200ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction
endclass : test_pde_abort_drain_no_update_001

`endif // PTW_LSU_ID_PHASE12_PDE_TESTS_SVH
