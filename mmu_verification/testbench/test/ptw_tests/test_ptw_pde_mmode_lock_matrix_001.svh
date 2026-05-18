// =============================================================================
// PTW-ADD-043: effective M-mode cached-pmpflg lock/bypass matrix
// =============================================================================
`ifndef TEST_PTW_PDE_MMODE_LOCK_MATRIX_001_SVH
`define TEST_PTW_PDE_MMODE_LOCK_MATRIX_001_SVH

class test_ptw_pde_mmode_lock_matrix_001 extends ptw_pde_pmpflg_stage9_base;

  `uvm_component_utils(test_ptw_pde_mmode_lock_matrix_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task run_l1_lock0_bypass_case();
    va_t  prime_va;
    va_t  reuse_va;
    pa_t  prime_pa;
    pa_t  reuse_pa;
    pte_t fst_nonleaf;
    pte_t scd_leaf;
    pa_t  tmp_pte_pa;
    logic [3:0] lock0_deny_bits;

    prime_va = 39'h0_3d20_0000;
    reuse_va = 39'h0_3d40_0000;
    prime_pa = 40'h0_0d20_0000;
    reuse_pa = 40'h0_0d40_0000;
    lock0_deny_bits = ptw_make_pmpflg(.r(0), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_mmode_l1_lock0_bypass");
    ptw_meta_add_req("PTW-ADD-043");
    ptw_meta_add_req("PDE-TP-018");
    ptw_meta_add_req("PTW-FLOW-028");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h10, STAGE9_ROOT_ASID + 16'h10,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage8_map_2m_and_read_fst(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_leaf(scd_leaf),
      .kind("stage9_mmode_l1_lock0_prime_2m"), .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h30));
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(1), .pa(reuse_pa),
          .raw_pte(scd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_mmode_l1_lock0_bypass reuse leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h31, reuse_va, 1, scd_leaf,
      tmp_pte_pa, "stage9_mmode_l1_lock0_reuse_2m_leaf");
    ptw_meta_add_context("effective M data context: MPRV=1 MPP=M; cached l1pmpflg=0 has lock=0 and type bits all zero, so M-mode bypass must allow L1 hit");

    ptw_prime_l1_pde_cache_with_type(PTW_SRC_TYPE_LOAD, prime_va,
      fst_nonleaf, lock0_deny_bits, 6'h30);
    ptw_meta_set_expected("L1 tag match with cached l1pmpflg=0x0 must hit because effective M bypass ignores type bits when lock=0");
    stage9_drive_and_finish("stage9_mmode_l1_lock0_bypass",
      PTW_SRC_TYPE_LOAD, reuse_va, 6'h31);
  endtask

  protected task run_l2_lock0_bypass_case();
    va_t  prime_va;
    va_t  reuse_va;
    pa_t  prime_pa;
    pa_t  reuse_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    pa_t  tmp_pte_pa;
    logic [3:0] lock0_deny_bits;

    prime_va = 39'h0_3d60_0000;
    reuse_va = 39'h0_3d60_1000;
    prime_pa = 40'h0_0d60_0000;
    reuse_pa = 40'h0_0d60_1000;
    lock0_deny_bits = ptw_make_pmpflg(.r(0), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_mmode_l2_lock0_bypass");
    ptw_meta_add_req("PTW-ADD-043");
    ptw_meta_add_req("PDE-TP-018");
    ptw_meta_add_req("PTW-FLOW-028");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h11, STAGE9_ROOT_ASID + 16'h11,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage8_map_4k_and_read_path(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_nonleaf(scd_nonleaf),
      .thd_leaf(thd_leaf), .kind("stage9_mmode_l2_lock0_prime_4k"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h32));
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(0), .pa(reuse_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_mmode_l2_lock0_bypass reuse leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h33, reuse_va, 0, thd_leaf,
      tmp_pte_pa, "stage9_mmode_l2_lock0_reuse_4k_leaf");
    ptw_meta_add_context("effective M data context: cached L2 l1/l2 pmpflg are both 0x0; lock=0 bypass must allow both nibbles despite R/W/X bits being zero");

    ptw_prime_l2_pde_cache_with_type(PTW_SRC_TYPE_LOAD, prime_va,
      fst_nonleaf, scd_nonleaf, lock0_deny_bits, lock0_deny_bits, 6'h32);
    ptw_meta_set_expected("L2 tag match with cached l1/l2 pmpflg=0x0 must hit because effective M bypass applies to both cached page-table PMP flags");
    stage9_drive_and_finish("stage9_mmode_l2_lock0_bypass",
      PTW_SRC_TYPE_LOAD, reuse_va, 6'h33);
  endtask

  protected task run_l1_lock1_deny_case();
    va_t  prime_va;
    va_t  deny_va;
    pa_t  prime_pa;
    pa_t  deny_pa;
    pte_t fst_nonleaf;
    pte_t scd_leaf;
    pa_t  tmp_pte_pa;
    logic [3:0] locked_w_only;

    prime_va = 39'h0_3da0_0000;
    deny_va  = 39'h0_3dc0_0000;
    prime_pa = 40'h0_0da0_0000;
    deny_pa  = 40'h0_0dc0_0000;
    locked_w_only = ptw_make_pmpflg(.r(0), .w(1), .x(0), .lock(1));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_mmode_l1_lock1_type_deny");
    ptw_meta_add_req("PTW-ADD-043");
    ptw_meta_add_req("PDE-TP-018");
    ptw_meta_add_req("PTW-FLOW-028");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h12, STAGE9_ROOT_ASID + 16'h12,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage8_map_2m_and_read_fst(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_leaf(scd_leaf),
      .kind("stage9_mmode_l1_lock1_prime_store_2m"), .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_STORE), .meta_id(6'h34));
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(1), .pa(deny_pa),
          .raw_pte(scd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_mmode_l1_lock1_deny leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h35, deny_va, 1, scd_leaf,
      tmp_pte_pa, "stage9_mmode_l1_lock1_deny_2m_leaf");
    ptw_meta_add_context("effective M data context: cached l1pmpflg is locked W-only; later LOAD cannot bypass because bit3=1 and R bit=0");

    ptw_prime_l1_pde_cache_with_type(PTW_SRC_TYPE_STORE, prime_va,
      fst_nonleaf, locked_w_only, 6'h34);
    ptw_meta_set_expected("L1 raw tag match but cached locked W-only l1pmpflg denies LOAD; effective M must not bypass bit3=1, so L1 behaves as deny miss and realtime TWU PMP denies the FST read");
    stage9_drive_and_finish("stage9_mmode_l1_lock1_type_deny",
      PTW_SRC_TYPE_LOAD, deny_va, 6'h35);
  endtask

  protected task run_l2_lock1_deny_case();
    va_t  prime_va;
    va_t  deny_va;
    pa_t  prime_pa;
    pa_t  deny_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    pa_t  tmp_pte_pa;
    logic [3:0] locked_r_only;

    prime_va = 39'h0_3de0_0000;
    deny_va  = 39'h0_3de0_1000;
    prime_pa = 40'h0_0de0_0000;
    deny_pa  = 40'h0_0de0_1000;
    locked_r_only = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(1));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_mmode_l2_lock1_type_deny");
    ptw_meta_add_req("PTW-ADD-043");
    ptw_meta_add_req("PDE-TP-018");
    ptw_meta_add_req("PTW-FLOW-028");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h13, STAGE9_ROOT_ASID + 16'h13,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage8_map_4k_and_read_path(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_nonleaf(scd_nonleaf),
      .thd_leaf(thd_leaf), .kind("stage9_mmode_l2_lock1_prime_load_4k"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h36));
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(0), .pa(deny_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_mmode_l2_lock1_deny leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_STORE, 6'h37, deny_va, 0, thd_leaf,
      tmp_pte_pa, "stage9_mmode_l2_lock1_deny_4k_leaf");
    ptw_meta_add_context("effective M data context: cached L2 l1/l2 pmpflg are both locked R-only; later STORE cannot bypass bit3=1 and must become L2 direct accerr");

    ptw_prime_l2_pde_cache_with_type(PTW_SRC_TYPE_LOAD, prime_va,
      fst_nonleaf, scd_nonleaf, locked_r_only, locked_r_only, 6'h36);
    ptw_meta_set_expected("STORE tag-matches L2 but cached locked R-only pmpflg denies W for both nibbles; effective M must not bypass lock=1, so PDE direct access fault is expected");
    fork
      begin
        stage9_wait_for_pde_accerr("stage9_mmode_l2_lock1_type_deny",
          PTW_SRC_TYPE_STORE, 6'h37, deny_va[38:12], 128, 1'b1);
      end
      begin
        ptw_drive_source_req_by_type(PTW_SRC_TYPE_STORE, deny_va, 6'h37);
      end
    join
    ptw_meta_set_actual("source_sb_expected_match_required_stage9");
    ptw_meta_set_result("stage9_directed");
    ptw_quiescent_wait("stage9_mmode_l2_lock1_type_deny");
    ptw_meta_print();
  endtask

  virtual task run_test_body();
    run_l1_lock0_bypass_case();
    run_l2_lock0_bypass_case();
    run_l1_lock1_deny_case();
    run_l2_lock1_deny_case();
    stage9_close("PTW-ADD-043,PDE-TP-018,PTW-FLOW-028",
      "stage9_mmode_lock_matrix",
      "directed matrix covers effective-M lock=0 bypass for L1/L2 and lock=1 deny for L1 miss plus L2 direct accerr");
    stage9_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_mmode_lock_matrix_001

`endif // TEST_PTW_PDE_MMODE_LOCK_MATRIX_001_SVH
