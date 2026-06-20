// =============================================================================
// PTW source stage-2 smoke test
//
// Verifies that the directed base can construct the raw PTE/PMP/bus-error
// stimulus classes required by stage 2 and can print scenario metadata.  The
// results remain provisional until the stage-3/4 source monitor/ref/sb exist.
// =============================================================================
`ifndef TEST_PTW_SOURCE_STAGE2_SMOKE_SVH
`define TEST_PTW_SOURCE_STAGE2_SMOKE_SVH

class test_ptw_source_stage2_smoke extends ptw_source_directed_base;

  `uvm_component_utils(test_ptw_source_stage2_smoke)

  localparam ppn_t  STAGE2_ROOT_PPN  = 28'h120;
  localparam asid_t STAGE2_ROOT_ASID = 16'h0202;

  int unsigned m_stage2_scenarios;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 16;
    timeout_ns = 2_000_000;
  endfunction

  protected task smoke_success_1g();
    va_t  va;
    pa_t  pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_4000_0000;
    pa = 40'h0_4000_0000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_success_1g_raw");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-FLOW-001");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b0, 1'b0, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(2), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(1), .a(1), .d(1),
          .rsw(2'b10), .high_reserved(21'h15555), .ext_attr(5'h12)))
      `uvm_fatal(get_type_name(), "stage2_success_1g_raw map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 1, va, 2, raw_pte, pte_pa, "1g_leaf");
    ptw_meta_set_expected("1g_success_refill");
    ptw_drive_lsu_load(va, 1);
    ptw_quiescent_wait("stage2_success_1g_raw");
    ptw_meta_print();
    m_stage2_scenarios++;
  endtask

  protected task smoke_success_2m();
    va_t  va;
    pa_t  pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_2200_0000;
    pa = 40'h0_0220_0000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_success_2m_raw");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-FLOW-002");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b1, 1'b0, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(1), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1),
          .rsw(2'b01), .high_reserved(21'h00021), .ext_attr(5'h08)))
      `uvm_fatal(get_type_name(), "stage2_success_2m_raw map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_STORE, 2, va, 1, raw_pte, pte_pa, "2m_leaf");
    ptw_meta_set_expected("2m_success_refill");
    ptw_drive_lsu_store(va, 2);
    ptw_quiescent_wait("stage2_success_2m_raw");
    ptw_meta_print();
    m_stage2_scenarios++;
  endtask

  protected task smoke_success_4k();
    va_t  va;
    pa_t  pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_3000_1000;
    pa = 40'h0_0300_1000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_success_4k_raw");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-FLOW-003");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b0, 1'b1, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(0), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1),
          .rsw(2'b11), .high_reserved(21'h1ffff), .ext_attr(5'h1a)))
      `uvm_fatal(get_type_name(), "stage2_success_4k_raw map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_FETCH, 0, va, 0, raw_pte, pte_pa, "4k_leaf");
    ptw_meta_set_expected("4k_success_refill");
    ptw_drive_fetch(va);
    ptw_quiescent_wait("stage2_success_4k_raw");
    ptw_meta_print();
    m_stage2_scenarios++;
  endtask

  protected task smoke_page_fault();
    va_t  va;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_3000_2000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_page_fault_thd_v0");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-FLOW-014");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b0, 1'b0, 1'b1);
    raw_pte = m_env.m_pt_mem.m_builder.make_raw_pte(
      .ppn(28'h0030_020), .v(0), .r(1), .w(1), .x(0), .u(0),
      .g(0), .a(1), .d(1), .rsw(2'b01),
      .high_reserved(21'h10000), .ext_attr(5'h04));
    if (!ptw_write_raw_pte_level(va, 0, raw_pte, pte_pa))
      `uvm_fatal(get_type_name(), "stage2_page_fault_thd_v0 write failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 3, va, 0, raw_pte, pte_pa, "v0_page_fault");
    ptw_meta_set_expected("page_fault_thd_v0");
    ptw_drive_lsu_load(va, 3);
    ptw_quiescent_wait("stage2_page_fault_thd_v0");
    ptw_meta_print();
    m_stage2_scenarios++;
  endtask

  protected task smoke_access_fault();
    va_t  va;
    pa_t  pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_3000_3000;
    pa = 40'h0_0300_3000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_access_fault_fst_pmp_deny");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-FLOW-009");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b0, 1'b0, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(0), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage2_access_fault map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 4, va, 0, raw_pte, pte_pa, "4k_leaf_before_pmp_deny");
    ptw_pmp_deny_ptw_reads(1'b1);
    ptw_meta_set_expected("access_fault_fst_pmp_deny");
    ptw_drive_lsu_load(va, 4);
    ptw_quiescent_wait("stage2_access_fault_fst_pmp_deny");
    ptw_meta_print();
    ptw_pmp_allow_all();
    m_stage2_scenarios++;
  endtask

  protected task smoke_bus_error();
    va_t  va;
    pa_t  pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_3000_4000;
    pa = 40'h0_0300_4000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_bus_error_by_count");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-FLOW-018");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b0, 1'b0, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(0), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage2_bus_error map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 5, va, 0, raw_pte, pte_pa, "4k_leaf_before_bus_error");
    ptw_mem_bus_error_by_count(1);
    ptw_mem_delay_by_count(1, 0);
    ptw_meta_set_expected("bus_error_access_fault");
    ptw_drive_lsu_load(va, 5);
    ptw_quiescent_wait("stage2_bus_error_by_count");
    ptw_meta_print();
    m_stage2_scenarios++;
  endtask

  protected task smoke_same_cycle_abort_controls();
    va_t  va;
    pa_t  pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_3000_5000;
    pa = 40'h0_0300_5000;
    ptw_meta_begin("TC-PTW-STAGE2-SMOKE", "stage2_same_cycle_abort_controls");
    ptw_meta_add_req("PTW-INFRA-002");
    ptw_meta_add_req("PTW-ADD-024");
    ptw_setup_sv39(STAGE2_ROOT_PPN, STAGE2_ROOT_ASID, PRIV_S, 1'b0, 1'b0, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(0), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage2_same_cycle_abort_controls map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6, va, 0, raw_pte, pte_pa, "4k_leaf_before_abort_window");
    ptw_mem_same_cycle_abort_data(1);
    ptw_mem_same_cycle_abort_bus_error(2);
    ptw_mem_chk_not_ready_slow(32);
    ptw_meta_set_expected("same_cycle_abort_data_and_bus_error_controls_configured");
    ptw_meta_set_actual("memory_responder_controls_only_stage2");
    ptw_meta_print();
    m_stage2_scenarios++;
  endtask

  virtual task run_test_body();
    m_stage2_scenarios = 0;

    smoke_success_1g();
    smoke_success_2m();
    smoke_success_4k();
    smoke_page_fault();
    smoke_access_fault();
    smoke_bus_error();
    smoke_same_cycle_abort_controls();

    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE2_SMOKE_SUMMARY scenarios=%0d result=provisional mismatch=not_checked_stage2",
        m_stage2_scenarios),
      UVM_NONE)
    #200ns;
  endtask

endclass : test_ptw_source_stage2_smoke

`endif // TEST_PTW_SOURCE_STAGE2_SMOKE_SVH
