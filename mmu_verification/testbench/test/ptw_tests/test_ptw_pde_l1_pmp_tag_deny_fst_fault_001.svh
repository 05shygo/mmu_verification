// =============================================================================
// PTW PDE cache pmpflg stage-8 directed base and PTW-ADD-037 test
//
// Stage 8 scope only:
//   - Exercise first-batch pmpflg directed scenarios using stage-7 helpers.
//   - Emit explicit metadata/closure markers for PTW-ADD-037..041.
//   - Do not add stage-9 effective-M/valid-gate/priority closure here.
// =============================================================================
`ifndef TEST_PTW_PDE_L1_PMP_TAG_DENY_FST_FAULT_001_SVH
`define TEST_PTW_PDE_L1_PMP_TAG_DENY_FST_FAULT_001_SVH

class ptw_pde_pmpflg_stage8_base extends ptw_source_directed_base;

  localparam ppn_t  STAGE8_ROOT_PPN  = 28'h380;
  localparam asid_t STAGE8_ROOT_ASID = 16'h0808;

  int unsigned m_stage8_closed;
  int unsigned m_stage8_partial;
  int unsigned m_stage8_open;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 48;
    timeout_ns = 4_000_000;
    m_stage8_closed  = 0;
    m_stage8_partial = 0;
    m_stage8_open    = 0;
  endfunction

  protected function void stage8_close(
    input string req_ids,
    input string scenario_id,
    input string evidence
  );
    m_stage8_closed++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE8_CLOSURE status=closed test=%s scenario=%s req=%s evidence={%s}",
        get_type_name(), scenario_id, req_ids, evidence),
      UVM_NONE)
  endfunction

  protected function void stage8_partial(
    input string req_ids,
    input string scenario_id,
    input string evidence,
    input string limitation
  );
    m_stage8_partial++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE8_CLOSURE status=partial test=%s scenario=%s req=%s evidence={%s} limitation={%s}",
        get_type_name(), scenario_id, req_ids, evidence, limitation),
      UVM_NONE)
  endfunction

  protected function void stage8_open(
    input string req_ids,
    input string scenario_id,
    input string reason
  );
    m_stage8_open++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE8_CLOSURE status=open test=%s scenario=%s req=%s owner_stage=9 reason={%s}",
        get_type_name(), scenario_id, req_ids, reason),
      UVM_NONE)
  endfunction

  protected function void stage8_summary(input bit source_sb_required = 1'b1);
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE8_TEST_SUMMARY test=%s closed_markers=%0d partial_markers=%0d open_markers=%0d source_sb_required=%0b",
        get_type_name(), m_stage8_closed, m_stage8_partial, m_stage8_open,
        source_sb_required),
      UVM_NONE)
  endfunction

  protected task stage8_map_4k_and_read_path(
    input va_t         va,
    input pa_t         pa,
    output pte_t       fst_nonleaf,
    output pte_t       scd_nonleaf,
    output pte_t       thd_leaf,
    input string       kind,
    input bit          r = 1'b1,
    input bit          w = 1'b1,
    input bit          x = 1'b1,
    input ptw_src_req_type_e meta_req_type = PTW_SRC_TYPE_LOAD,
    input int unsigned meta_id = 0
  );
    pa_t fst_pte_pa;
    pa_t scd_pte_pa;
    pa_t thd_pte_pa;

    if (!ptw_map_raw_leaf_pa(.va(va), .level(0), .pa(pa),
          .raw_pte(thd_leaf), .pte_pa(thd_pte_pa),
          .r(r), .w(w), .x(x), .u(0), .g(0), .a(1), .d(1),
          .rsw(2'b00), .high_reserved(21'h0), .ext_attr(5'h0)))
      `uvm_fatal(get_type_name(), $sformatf("%s: map 4K leaf failed va=0x%010h", kind, va))

    if (!m_env.m_pt_mem.m_builder.read_pte_for_level(va, 2, fst_nonleaf, fst_pte_pa))
      `uvm_fatal(get_type_name(), $sformatf("%s: read fst nonleaf failed va=0x%010h", kind, va))
    if (!m_env.m_pt_mem.m_builder.read_pte_for_level(va, 1, scd_nonleaf, scd_pte_pa))
      `uvm_fatal(get_type_name(), $sformatf("%s: read scd nonleaf failed va=0x%010h", kind, va))

    ptw_meta_add_level(meta_req_type, meta_id, va, 2, fst_nonleaf, fst_pte_pa,
      {kind, "_fst_nonleaf_template"});
    ptw_meta_add_level(meta_req_type, meta_id, va, 1, scd_nonleaf, scd_pte_pa,
      {kind, "_scd_nonleaf_template"});
    ptw_meta_add_level(meta_req_type, meta_id, va, 0, thd_leaf, thd_pte_pa,
      {kind, "_thd_leaf_template"});
  endtask

  protected task stage8_map_2m_and_read_fst(
    input va_t         va,
    input pa_t         pa,
    output pte_t       fst_nonleaf,
    output pte_t       scd_leaf,
    input string       kind,
    input bit          r = 1'b1,
    input bit          w = 1'b1,
    input bit          x = 1'b1,
    input ptw_src_req_type_e meta_req_type = PTW_SRC_TYPE_LOAD,
    input int unsigned meta_id = 0
  );
    pa_t fst_pte_pa;
    pa_t scd_pte_pa;

    if (!ptw_map_raw_leaf_pa(.va(va), .level(1), .pa(pa),
          .raw_pte(scd_leaf), .pte_pa(scd_pte_pa),
          .r(r), .w(w), .x(x), .u(0), .g(0), .a(1), .d(1),
          .rsw(2'b00), .high_reserved(21'h0), .ext_attr(5'h0)))
      `uvm_fatal(get_type_name(), $sformatf("%s: map 2M leaf failed va=0x%010h", kind, va))

    if (!m_env.m_pt_mem.m_builder.read_pte_for_level(va, 2, fst_nonleaf, fst_pte_pa))
      `uvm_fatal(get_type_name(), $sformatf("%s: read fst nonleaf failed va=0x%010h", kind, va))

    ptw_meta_add_level(meta_req_type, meta_id, va, 2, fst_nonleaf, fst_pte_pa,
      {kind, "_fst_nonleaf_template"});
    ptw_meta_add_level(meta_req_type, meta_id, va, 1, scd_leaf, scd_pte_pa,
      {kind, "_2m_leaf_template"});
  endtask

  protected task stage8_drive_and_finish(
    input string             scenario_id,
    input ptw_src_req_type_e req_type,
    input va_t               va,
    input int unsigned       id
  );
    ptw_drive_source_req_by_type(req_type, va, id);
    ptw_meta_set_actual("source_sb_expected_match_required_stage8");
    ptw_meta_set_result("stage8_directed");
    ptw_quiescent_wait(scenario_id);
    ptw_meta_print();
  endtask

  protected task stage8_wait_cycles(input int unsigned cycles);
    repeat (cycles) begin
      if (ptw_probe_vif != null)
        @(ptw_probe_vif.mon_cb);
      else
        #1ns;
    end
  endtask

endclass : ptw_pde_pmpflg_stage8_base

class test_ptw_pde_l1_pmp_tag_deny_fst_fault_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_l1_pmp_tag_deny_fst_fault_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t  prime_va;
    va_t  deny_va;
    pa_t  prime_pa;
    pa_t  deny_pa;
    pte_t fst_nonleaf;
    pte_t scd_leaf;
    logic [3:0] x_only_pmpflg;
    pa_t tmp_pte_pa;

    prime_va = 39'h0_3820_0000;
    deny_va  = 39'h0_3840_0000;
    prime_pa = 40'h0_0820_0000;
    deny_pa  = 40'h0_0840_0000;
    x_only_pmpflg = ptw_make_pmpflg(.r(0), .w(0), .x(1), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", "stage8_l1_tag_hit_cached_x_deny_load");
    ptw_meta_add_req("PTW-ADD-037");
    ptw_meta_add_req("PDE-TP-013");
    ptw_meta_add_req("PTW-FLOW-024");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h01, STAGE8_ROOT_ASID + 16'h01,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_2m_and_read_fst(prime_va, prime_pa, fst_nonleaf, scd_leaf,
      "stage8_l1_deny_prime_fetch_2m", .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_FETCH), .meta_id(0));
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(1), .pa(deny_pa),
          .raw_pte(scd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage8_l1_deny load leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h11, deny_va, 1, scd_leaf,
      tmp_pte_pa, "stage8_l1_deny_reuse_2m_leaf");
    ptw_meta_add_context("stable_pmpflg=0x4 means cached X-only: fetch can prime L1 with a 2M leaf and no L2 PDE update; later different-vpn1 load is denied by cached L1 pmpflg; no PMP cfg change after prime");
    ptw_prime_l1_pde_cache_with_type(PTW_SRC_TYPE_FETCH, prime_va, fst_nonleaf,
      x_only_pmpflg, 0);

    ptw_meta_set_expected("L1 valid tag match but cached l1pmpflg denies LOAD R bit; L1 PDE must not hit and must not create PDE direct accerr; request falls back to FST where stable realtime PMP also denies as normal TWU access fault");
    stage8_drive_and_finish("stage8_l1_tag_hit_cached_x_deny_load",
      PTW_SRC_TYPE_LOAD, deny_va, 6'h11);
    stage8_close("PTW-ADD-037,PDE-TP-013,PTW-FLOW-024",
      "stage8_l1_tag_hit_cached_x_deny_load",
      "fetch primes L1 PDE under cached X-only pmpflg; later load with same vpn[2] is L1 tag-hit deny miss, FST/TWU access fault path, and no PDE direct-accerr expectation");
    stage8_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_l1_pmp_tag_deny_fst_fault_001

`endif // TEST_PTW_PDE_L1_PMP_TAG_DENY_FST_FAULT_001_SVH
