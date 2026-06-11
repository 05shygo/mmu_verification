// =============================================================================
// PTW LSU-ID Phase 12 directed tests
// =============================================================================
`ifndef PTW_LSU_ID_PHASE12_TESTS_SVH
`define PTW_LSU_ID_PHASE12_TESTS_SVH

class test_pmbuf_req_resp_id_basic_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_req_resp_id_basic_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-REQ-RESP-ID-BASIC-001", "P0",
      "ptw_mem_normal_rsp_seq + lsu_mapped_pipe0_rr_seq",
      "a_lsu_req_id_legal_on_fire + cp_lsu_rsp_id_match + req/rsp ID source coverage",
      "Implemented", "F4.42b");
    p12_lsu_responder_mode = "in_order_id_echo";
    phase12_lsu_id_add_req("PTW-LSU-ID-001");
    phase12_lsu_id_add_req("PTW-LSU-ID-002");
    phase12_lsu_id_add_tp("LSUID-TP-001");
    phase12_lsu_id_add_tp("LSUID-TP-002");
    num_txn = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_rr_seq");
  endfunction
endclass : test_pmbuf_req_resp_id_basic_001

class test_pmbuf_multi_outstanding_id_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_multi_outstanding_id_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-MULTI-OUTSTANDING-ID-001", "P0",
      "ptw_mem_slow_rsp_seq + ptw_mem_max_outstanding_seq + lsu_mapped_pipe0_back2back_seq",
      "cp_lsu_two_outstanding + PTW_SOURCE_SB_LSU_ID_COVERAGE.max_outstanding",
      "Implemented", "F4.42a");
    p12_lsu_responder_mode = "slow_rsp_multi_outstanding";
    phase12_lsu_id_add_req("PTW-LSU-MULTI-001");
    phase12_lsu_id_add_tp("LSUMULTI-TP-001");
    phase12_lsu_id_add_tp("CREDIT-TP-001");
    num_txn = 96;
    m_post_drain = 1200ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_max_outstanding_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_back2back_seq");
  endfunction
endclass : test_pmbuf_multi_outstanding_id_001

class test_pmbuf_ooo_response_by_id_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_ooo_response_by_id_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-OOO-RESPONSE-BY-ID-001", "P0",
      "ptw_mem_slow_rsp_seq + ptw_mem_ooo_rsp_seq + lsu_mapped_pipe0_back2back_seq",
      "cp_lsu_ooo_response + a_lsu_response_matches_outstanding_id + source-key completion match",
      "Implemented", "PTW-014");
    p12_lsu_responder_mode = "ooo_by_id";
    phase12_lsu_id_add_req("PTW-LSU-MULTI-002");
    phase12_lsu_id_add_tp("LSUOOO-TP-001");
    phase12_lsu_id_add_tp("SRCID-TP-002");
    num_txn = 96;
    m_post_drain = 1400ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_ooo_rsp_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_back2back_seq");
  endfunction
endclass : test_pmbuf_ooo_response_by_id_001

class test_pmbuf_grant_hold_addr_id_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_grant_hold_addr_id_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-GRANT-HOLD-ADDR-ID-001", "P0",
      "ptw_mem_slow_rsp_seq + ptw_mem_grant_backpressure_seq + lsu_mapped_pipe0_rr_seq",
      "a_lsu_req_hold_stable_until_grant + a_lsu_req_no_ungranted_entry_on + cp_lsu_grant_wait",
      "Implemented", "F4.42a");
    p12_lsu_responder_mode = "grant_backpressure_count1_8cy";
    phase12_lsu_id_add_req("PTW-LSU-GRANT-001");
    phase12_lsu_id_add_req("PTW-LSU-GRANT-002");
    phase12_lsu_id_add_tp("LSUGRANT-TP-001");
    phase12_lsu_id_add_tp("LSUGRANT-TP-002");
    num_txn = 48;
    m_post_drain = 900ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_grant_backpressure_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_rr_seq");
  endfunction
endclass : test_pmbuf_grant_hold_addr_id_001

class test_pmbuf_abort_before_grant_cancel_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_abort_before_grant_cancel_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-ABORT-BEFORE-GRANT-CANCEL-001", "P0",
      "ptw_mem_slow_rsp_seq + ptw_mem_grant_long_backpressure_seq + mmu_sfence_during_walk_vseq",
      "a_lsu_req_cancel_before_grant_no_outstanding + cp_lsu_abort_before_grant",
      "Implemented", "F4.42d");
    p12_lsu_responder_mode = "grant_backpressure_before_sfence_abort";
    phase12_lsu_id_add_req("PTW-LSU-ABORT-003");
    phase12_lsu_id_add_tp("LSUGRANT-TP-003");
    num_txn = 48;
    m_post_drain = 1600ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_grant_long_backpressure_seq");
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction
endclass : test_pmbuf_abort_before_grant_cancel_001

class test_pmbuf_bus_error_route_by_id_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_bus_error_route_by_id_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-BUS-ERROR-ROUTE-BY-ID-001", "P0",
      "ptw_mem_normal_rsp_seq + ptw_mem_bus_error_by_count1_seq + lsu_mapped_pipe0_rr_seq",
      "bus error completion uses response ID source-key map; no PDE update on bus error",
      "Implemented", "F4.42e");
    p12_lsu_responder_mode = "bus_error_by_first_accept_id";
    phase12_lsu_id_add_req("PTW-LSU-ID-003");
    phase12_lsu_id_add_tp("BUSERR-TP-001");
    phase12_lsu_id_add_tp("SRCID-TP-001");
    phase12_lsu_id_add_tp("PDEUPD-TP-006");
    num_txn = 48;
    m_post_drain = 900ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_bus_error_by_count1_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_rr_seq");
  endfunction
endclass : test_pmbuf_bus_error_route_by_id_001

class test_pmbuf_abort_drain_single_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_abort_drain_single_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-ABORT-DRAIN-SINGLE-001", "P0",
      "ptw_mem_slow_rsp_seq + mmu_sfence_during_walk_vseq",
      "abort keeps entry_on until response ID drains; no visible completion/PDE update",
      "Implemented", "F4.42f");
    p12_lsu_responder_mode = "slow_rsp_sfence_abort_single";
    phase12_lsu_id_add_req("PTW-LSU-ABORT-001");
    phase12_lsu_id_add_tp("ABDRN-TP-001");
    num_txn = 48;
    m_post_drain = 1800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction
endclass : test_pmbuf_abort_drain_single_001

class test_pmbuf_abort_drain_multi_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_abort_drain_multi_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-ABORT-DRAIN-MULTI-001", "P0",
      "ptw_mem_slow_rsp_seq + ptw_mem_ooo_rsp_seq + mmu_sfence_during_walk_vseq",
      "cp_lsu_abort_drain_multi + response-ID drain clears every entry_on",
      "Implemented", "F4.42f");
    p12_lsu_responder_mode = "slow_ooo_rsp_sfence_abort_multi";
    phase12_lsu_id_add_req("PTW-LSU-ABORT-001");
    phase12_lsu_id_add_tp("ABDRN-TP-002");
    phase12_lsu_id_add_tp("COV-ABDRN-001");
    num_txn = 96;
    m_post_drain = 2200ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_ooo_rsp_seq");
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction
endclass : test_pmbuf_abort_drain_multi_001

class test_pmbuf_no_new_req_during_drain_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_no_new_req_during_drain_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-NO-NEW-REQ-DURING-DRAIN-001", "P0",
      "ptw_mem_slow_rsp_seq + mmu_sfence_during_walk_vseq",
      "ptw_abort_drain blocks MBUF create, LSU req and PDE update",
      "Implemented", "F4.42g");
    p12_lsu_responder_mode = "slow_rsp_abort_drain_no_new_req";
    phase12_lsu_id_add_req("PTW-LSU-ABORT-002");
    phase12_lsu_id_add_tp("ABDRN-TP-003");
    phase12_lsu_id_add_tp("LOG-TP-001");
    num_txn = 64;
    m_post_drain = 2200ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction
endclass : test_pmbuf_no_new_req_during_drain_001

class test_pmbuf_duplicate_id_blocked_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_duplicate_id_blocked_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-DUPLICATE-ID-BLOCKED-001", "P1",
      "same-VA replay under slow PTW response",
      "same entry on prevents duplicate request ID fire; mbuf_have/no-resend coverage",
      "Implemented", "F4.42h");
    p12_lsu_responder_mode = "same_va_replay_slow_rsp";
    phase12_lsu_id_add_req("PTW-LSU-MULTI-001");
    phase12_lsu_id_add_tp("LSUMULTI-TP-003");
    num_txn = 96;
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
    phase12_config_ptw_responder(64, 128, 0);
    repeat (3) begin
      phase12_cp0_tlb_allinv();
      fork
        phase12_drive_ifu_rr(39'h10_0000, 1, 16);
        phase12_drive_lsu_rr(39'h10_0000, 1, 16, LSU_PIPE0, 1'b0);
        phase12_drive_lsu_rr(39'h10_0000, 1, 16, LSU_PIPE1, 1'b1);
      join
    end
    phase12_config_ptw_responder(1, 4, 0);
    #(m_post_drain);
  endtask
endclass : test_pmbuf_duplicate_id_blocked_001

class test_pmbuf_invalid_rsp_id_ignored_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_invalid_rsp_id_ignored_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-INVALID-RSP-ID-IGNORED-001", "P2-negative",
      "ptw_mem_normal_rsp_seq + ptw_mem_invalid_rsp_id_negative_seq + lsu_mapped_pipe0_rr_seq",
      "invalid response ID 9..15 has no entry side effect",
      "Implemented", "F4.42n");
    p12_lsu_responder_mode = "negative_invalid_rsp_id_9";
    phase12_lsu_id_add_req("PTW-LSU-ID-004");
    phase12_lsu_id_add_tp("LSUID-TP-004");
    num_txn = 32;
    m_post_drain = 1000ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_invalid_rsp_id_negative_seq");
    m_lsu_seq_names.push_back("lsu_mapped_pipe0_rr_seq");
  endfunction
endclass : test_pmbuf_invalid_rsp_id_ignored_001

class test_pmbuf_random_id_ooo_stress_001 extends phase12_lsu_id_test_base;
  `uvm_component_utils(test_pmbuf_random_id_ooo_stress_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  protected virtual function void setup_phase12_lsu_id_plan();
    phase12_lsu_id_set_meta(
      "TC-PMBUF-RANDOM-ID-OOO-STRESS-001", "P1",
      "ptw_mem_slow_rsp_seq + ptw_mem_ooo_rsp_seq + ptw_mem_max_outstanding_seq + ptw_mem_grant_backpressure_seq + mmu_ptw_thrash_vseq",
      "ID/OOO/multi-outstanding/grant stress with source-side matching; bus-error stays in directed P0 coverage",
      "Implemented", "F4.42p");
    p12_lsu_responder_mode = "random_slow_ooo_grant";
    phase12_lsu_id_add_req("PTW-LSU-ID-001");
    phase12_lsu_id_add_req("PTW-LSU-ID-002");
    phase12_lsu_id_add_req("PTW-LSU-MULTI-002");
    phase12_lsu_id_add_tp("LSUMULTI-TP-002");
    phase12_lsu_id_add_tp("LSUOOO-TP-001");
    phase12_lsu_id_add_tp("LSUGRANT-TP-004");
    phase12_lsu_id_add_tp("PERF-TP-001");
    num_txn = 128;
    m_post_drain = 2400ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_ooo_rsp_seq");
    m_ptw_seq_names.push_back("ptw_mem_max_outstanding_seq");
    m_ptw_seq_names.push_back("ptw_mem_grant_backpressure_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction
endclass : test_pmbuf_random_id_ooo_stress_001

`endif // PTW_LSU_ID_PHASE12_TESTS_SVH
