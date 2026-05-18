// =============================================================================
// PTW PDE cache pmpflg stage-9 directed base and PTW-ADD-042 test
//
// Stage 9 scope only:
//   - Exercise second-batch pmpflg directed scenarios using stage-8 helpers.
//   - Emit explicit metadata/closure markers for PTW-ADD-042..045.
//   - Do not update signoff gate or final closure matrix here.
// =============================================================================
`ifndef TEST_PTW_PDE_ACCERR_PRIORITY_TYPE_ID_001_SVH
`define TEST_PTW_PDE_ACCERR_PRIORITY_TYPE_ID_001_SVH

class ptw_pde_pmpflg_stage9_base extends ptw_pde_pmpflg_stage8_base;

  localparam ppn_t  STAGE9_ROOT_PPN  = 28'h3c0;
  localparam asid_t STAGE9_ROOT_ASID = 16'h0909;

  int unsigned m_stage9_closed;
  int unsigned m_stage9_partial;
  int unsigned m_stage9_open;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 80;
    timeout_ns = 6_000_000;
    m_stage9_closed  = 0;
    m_stage9_partial = 0;
    m_stage9_open    = 0;
  endfunction

  protected function void stage9_close(
    input string req_ids,
    input string scenario_id,
    input string evidence
  );
    m_stage9_closed++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE9_CLOSURE status=closed test=%s scenario=%s req=%s evidence={%s}",
        get_type_name(), scenario_id, req_ids, evidence),
      UVM_NONE)
  endfunction

  protected function void stage9_partial(
    input string req_ids,
    input string scenario_id,
    input string evidence,
    input string limitation
  );
    m_stage9_partial++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE9_CLOSURE status=partial test=%s scenario=%s req=%s evidence={%s} limitation={%s}",
        get_type_name(), scenario_id, req_ids, evidence, limitation),
      UVM_NONE)
  endfunction

  protected function void stage9_open(
    input string req_ids,
    input string scenario_id,
    input string reason
  );
    m_stage9_open++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE9_CLOSURE status=open test=%s scenario=%s req=%s reason={%s}",
        get_type_name(), scenario_id, req_ids, reason),
      UVM_NONE)
  endfunction

  protected function void stage9_summary(input bit source_sb_required = 1'b1);
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE9_TEST_SUMMARY test=%s closed_markers=%0d partial_markers=%0d open_markers=%0d source_sb_required=%0b",
        get_type_name(), m_stage9_closed, m_stage9_partial, m_stage9_open,
        source_sb_required),
      UVM_NONE)
  endfunction

  protected task stage9_drive_and_finish(
    input string             scenario_id,
    input ptw_src_req_type_e req_type,
    input va_t               va,
    input int unsigned       id
  );
    ptw_drive_source_req_by_type(req_type, va, id);
    ptw_meta_set_actual("source_sb_expected_match_required_stage9");
    ptw_meta_set_result("stage9_directed");
    ptw_quiescent_wait(scenario_id);
    ptw_meta_print();
  endtask

  protected task stage9_cp0_tlb_allinv(input string scenario_id);
    cp0_tlb_allinv_seq cp0_inv;

    cp0_inv = cp0_tlb_allinv_seq::type_id::create({scenario_id, "_cp0_tlb_allinv"});
    cp0_inv.start(m_env.m_cp0.m_sequencer);
    ptw_meta_add_context({scenario_id, ": cp0_tlb_allinv issued; PDE clear expected through regs_ptw_clr/tlboper path"});
    stage8_wait_cycles(8);
  endtask

  protected task stage9_wait_for_pde_accerr(
    input string             scenario_id,
    input ptw_src_req_type_e exp_type,
    input int unsigned       exp_id,
    input int unsigned       max_cycles = 128
  );
    bit          target_accepted;
    bit          pde_seen;
    bit          grant_seen;
    bit          mismatch_seen;
    int unsigned accept_cycles;
    int unsigned cycles_after_accept;
    int unsigned total_cycles;
    logic [2:0]  first_type;
    logic [2:0]  exp_type_bits;
    logic [5:0]  first_id;
    logic [5:0]  exp_id_bits;

    if (ptw_probe_vif == null) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: MMU_DUT_PROBES_VIF unavailable; cannot check PDE direct accerr type/id", scenario_id))
      ptw_meta_add_context({scenario_id, ": pde_accerr_probe_unavailable"});
      return;
    end

    target_accepted = 1'b0;
    pde_seen = 1'b0;
    grant_seen = 1'b0;
    mismatch_seen = 1'b0;
    accept_cycles = (max_cycles < 512) ? 512 : max_cycles;
    cycles_after_accept = 0;
    total_cycles = accept_cycles + max_cycles;
    first_type = '0;
    exp_type_bits = exp_type;
    first_id = '0;
    exp_id_bits = exp_id[5:0];

    for (int unsigned cycle = 0; cycle < total_cycles; cycle++) begin
      @(ptw_probe_vif.mon_cb);

      if (!target_accepted
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_req === 1'b1)
          && (ptw_probe_vif.mon_cb.ptw_jtlb_ready === 1'b1)
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_type == exp_type_bits)
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_id == exp_id_bits)) begin
        target_accepted = 1'b1;
        cycles_after_accept = 0;
        ptw_meta_add_context($sformatf("%s: target_req_accepted cycle_offset=%0d type=%s id=0x%02h",
          scenario_id, cycle, ptw_src_type_name(exp_type), exp_id_bits));
      end

      if (ptw_probe_vif.mon_cb.pde_cache_acc_err_vld === 1'b1) begin
        if (!pde_seen) begin
          pde_seen = 1'b1;
          first_type = ptw_probe_vif.mon_cb.pde_cache_acc_err_type;
          first_id = ptw_probe_vif.mon_cb.pde_cache_acc_err_id;
          if ((ptw_probe_vif.mon_cb.pde_cache_acc_err_type !== exp_type_bits)
              || (ptw_probe_vif.mon_cb.pde_cache_acc_err_id !== exp_id_bits)) begin
            mismatch_seen = 1'b1;
            `uvm_error(get_type_name(),
              $sformatf("%s: PDE accerr type/id mismatch exp_type=%s exp_id=0x%02h act_type=0x%0h act_id=0x%02h",
                scenario_id, ptw_src_type_name(exp_type), exp_id_bits,
                ptw_probe_vif.mon_cb.pde_cache_acc_err_type,
                ptw_probe_vif.mon_cb.pde_cache_acc_err_id))
            break;
          end
          if (!target_accepted) begin
            target_accepted = 1'b1;
            cycles_after_accept = 0;
            ptw_meta_add_context($sformatf("%s: target_req_accept_inferred_from_pde_accerr cycle_offset=%0d type=%s id=0x%02h",
              scenario_id, cycle, ptw_src_type_name(exp_type), exp_id_bits));
          end
        end else if ((ptw_probe_vif.mon_cb.pde_cache_acc_err_type !== first_type)
            || (ptw_probe_vif.mon_cb.pde_cache_acc_err_id !== first_id)) begin
          mismatch_seen = 1'b1;
          `uvm_error(get_type_name(),
            $sformatf("%s: PDE accerr type/id changed while pending first={type=0x%0h id=0x%02h} now={type=0x%0h id=0x%02h}",
              scenario_id, first_type, first_id,
              ptw_probe_vif.mon_cb.pde_cache_acc_err_type,
              ptw_probe_vif.mon_cb.pde_cache_acc_err_id))
          break;
        end

        if ((ptw_probe_vif.mon_cb.pde_cache_acc_err_grant === 1'b1)
            && (ptw_probe_vif.mon_cb.pde_cache_acc_err_type == exp_type_bits)
            && (ptw_probe_vif.mon_cb.pde_cache_acc_err_id == exp_id_bits)) begin
          grant_seen = 1'b1;
          ptw_meta_add_context($sformatf("%s: pde_accerr_observed cycle_offset=%0d type=0x%0h id=0x%02h grant=1",
            scenario_id, cycle,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_type,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_id));
          break;
        end
      end

      if ((ptw_probe_vif.mon_cb.ptw_acc_err_grant_vec[5] === 1'b1)
          && (ptw_probe_vif.mon_cb.ptw_l2tlb_ref_acc_err === 1'b1)) begin
        if ((ptw_probe_vif.mon_cb.ptw_l2tlb_type !== exp_type_bits)
            || (ptw_probe_vif.mon_cb.ptw_l2tlb_id !== exp_id_bits)) begin
          mismatch_seen = 1'b1;
          `uvm_error(get_type_name(),
            $sformatf("%s: PDE accerr visible completion type/id mismatch exp_type=%s exp_id=0x%02h act_type=0x%0h act_id=0x%02h",
              scenario_id, ptw_src_type_name(exp_type), exp_id_bits,
              ptw_probe_vif.mon_cb.ptw_l2tlb_type,
              ptw_probe_vif.mon_cb.ptw_l2tlb_id))
          break;
        end
        if (!target_accepted) begin
          target_accepted = 1'b1;
          cycles_after_accept = 0;
          ptw_meta_add_context($sformatf("%s: target_req_accept_inferred_from_visible_accerr cycle_offset=%0d type=%s id=0x%02h",
            scenario_id, cycle, ptw_src_type_name(exp_type), exp_id_bits));
        end
        if (!pde_seen) begin
          pde_seen = 1'b1;
          first_type = exp_type_bits;
          first_id = exp_id_bits;
        end
        grant_seen = 1'b1;
        ptw_meta_add_context($sformatf("%s: pde_accerr_visible_completion cycle_offset=%0d type=0x%0h id=0x%02h grant_vec=0x%0h pde_vld=%0b pde_grant=%0b",
          scenario_id, cycle,
          ptw_probe_vif.mon_cb.ptw_l2tlb_type,
          ptw_probe_vif.mon_cb.ptw_l2tlb_id,
          ptw_probe_vif.mon_cb.ptw_acc_err_grant_vec,
          ptw_probe_vif.mon_cb.pde_cache_acc_err_vld,
          ptw_probe_vif.mon_cb.pde_cache_acc_err_grant));
        break;
      end

      if (target_accepted) begin
        cycles_after_accept++;
        if (cycles_after_accept >= max_cycles)
          break;
      end else if ((cycle + 1) >= accept_cycles) begin
        break;
      end
    end

    if (mismatch_seen) begin
      return;
    end

    if (!target_accepted) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: target req was not accepted within %0d cycles type=%s id=0x%02h",
          scenario_id, accept_cycles, ptw_src_type_name(exp_type), exp_id_bits))
    end else if (!pde_seen) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: expected PDE direct accerr not observed within %0d cycles after target accept",
          scenario_id, max_cycles))
    end else if (!grant_seen) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: PDE direct accerr observed but grant did not arrive within %0d cycles",
          scenario_id, max_cycles))
    end
  endtask

  protected task stage9_expect_no_pde_accerr_window(
    input string       scenario_id,
    input int unsigned cycles
  );
    bit seen;

    if (ptw_probe_vif == null) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: MMU_DUT_PROBES_VIF unavailable; cannot check no PDE direct accerr window", scenario_id))
      ptw_meta_add_context({scenario_id, ": no_pde_accerr_probe_unavailable"});
      return;
    end

    seen = 1'b0;
    for (int unsigned cycle = 0; cycle < cycles; cycle++) begin
      @(ptw_probe_vif.mon_cb);
      if ((ptw_probe_vif.mon_cb.pde_cache_acc_err_vld === 1'b1)
          || (|ptw_probe_vif.mon_cb.pde_l2_entry_acc_err_vec)) begin
        seen = 1'b1;
        `uvm_error(get_type_name(),
          $sformatf("%s: unexpected PDE direct accerr activity at cycle=%0d vld=%0b vec=0x%0h type=0x%0h id=0x%02h",
            scenario_id, cycle,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_vld,
            ptw_probe_vif.mon_cb.pde_l2_entry_acc_err_vec,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_type,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_id))
        break;
      end
    end

    if (!seen) begin
      ptw_meta_add_context($sformatf("%s: no_pde_direct_accerr_window cycles=%0d observed=0",
        scenario_id, cycles));
      `uvm_info(get_type_name(),
        $sformatf("PTW_STAGE9_HELPER no_pde_direct_accerr_window scenario=%s cycles=%0d observed=0",
          scenario_id, cycles),
        UVM_LOW)
    end
  endtask

  protected task stage9_expect_no_pde_accerr_for_req(
    input string             scenario_id,
    input ptw_src_req_type_e req_type,
    input int unsigned       id,
    input vpn_t              vpn,
    input int unsigned       max_cycles = 256
  );
    bit accepted;
    bit completed;
    logic [2:0] req_type_bits;

    if (ptw_probe_vif == null) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: MMU_DUT_PROBES_VIF unavailable; cannot check request-scoped no PDE direct accerr", scenario_id))
      ptw_meta_add_context({scenario_id, ": req_scoped_no_pde_accerr_probe_unavailable"});
      return;
    end

    accepted = 1'b0;
    completed = 1'b0;
    req_type_bits = req_type;

    for (int unsigned cycle = 0; cycle < max_cycles; cycle++) begin
      @(ptw_probe_vif.mon_cb);

      if ((ptw_probe_vif.mon_cb.pde_cache_acc_err_vld === 1'b1)
          || (|ptw_probe_vif.mon_cb.pde_l2_entry_acc_err_vec)) begin
        `uvm_error(get_type_name(),
          $sformatf("%s: unexpected PDE direct accerr while checking req type=%s id=0x%02h vpn=0x%07h at cycle=%0d accepted=%0b vld=%0b vec=0x%0h acc_type=0x%0h acc_id=0x%02h",
            scenario_id, ptw_src_type_name(req_type), id[5:0], vpn, cycle,
            accepted, ptw_probe_vif.mon_cb.pde_cache_acc_err_vld,
            ptw_probe_vif.mon_cb.pde_l2_entry_acc_err_vec,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_type,
            ptw_probe_vif.mon_cb.pde_cache_acc_err_id))
        return;
      end

      if (!accepted
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_req === 1'b1)
          && (ptw_probe_vif.mon_cb.ptw_jtlb_ready === 1'b1)
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_type == req_type_bits)
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_id == id[5:0])
          && (ptw_probe_vif.mon_cb.l2tlb_ptw_vpn == vpn)) begin
        accepted = 1'b1;
        ptw_meta_add_context($sformatf("%s: target_req_accepted cycle_offset=%0d type=%s id=0x%02h vpn=0x%07h",
          scenario_id, cycle, ptw_src_type_name(req_type), id[5:0], vpn));
      end

      if (accepted
          && (ptw_probe_vif.mon_cb.ptw_l2tlb_cmplt === 1'b1)
          && (ptw_probe_vif.mon_cb.ptw_l2tlb_type == req_type_bits)
          && (ptw_probe_vif.mon_cb.ptw_l2tlb_id == id[5:0])) begin
        completed = 1'b1;
        ptw_meta_add_context($sformatf("%s: target_req_completed cycle_offset=%0d no_pde_direct_accerr=1",
          scenario_id, cycle));
        break;
      end
    end

    if (!accepted) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: target req was not accepted within %0d cycles type=%s id=0x%02h vpn=0x%07h",
          scenario_id, max_cycles, ptw_src_type_name(req_type), id[5:0], vpn))
    end else if (!completed) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: target req accepted but did not complete within %0d cycles type=%s id=0x%02h vpn=0x%07h",
          scenario_id, max_cycles, ptw_src_type_name(req_type), id[5:0], vpn))
    end
  endtask

  protected task stage9_wait_for_ptw_mem_accept(
    input string       scenario_id,
    input int unsigned max_cycles = 128
  );
    bit seen;

    if (ptw_probe_vif == null) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: MMU_DUT_PROBES_VIF unavailable; cannot wait for PTW memory accept", scenario_id))
      ptw_meta_add_context({scenario_id, ": ptw_mem_accept_probe_unavailable"});
      return;
    end

    seen = 1'b0;
    for (int unsigned cycle = 0; cycle < max_cycles; cycle++) begin
      @(ptw_probe_vif.mon_cb);
      if ((ptw_probe_vif.mon_cb.ptw_lsu_data_req === 1'b1)
          && (|ptw_probe_vif.mon_cb.ptw_lsu_data_req_grant)) begin
        seen = 1'b1;
        ptw_meta_add_context($sformatf("%s: ptw_mem_accept cycle_offset=%0d addr=0x%010h grant=0x%0h",
          scenario_id, cycle,
          ptw_probe_vif.mon_cb.ptw_lsu_data_req_addr,
          ptw_probe_vif.mon_cb.ptw_lsu_data_req_grant));
        break;
      end
    end

    if (!seen) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: PTW memory accept not observed within %0d cycles",
          scenario_id, max_cycles))
    end
  endtask

endclass : ptw_pde_pmpflg_stage9_base

class test_ptw_pde_accerr_priority_type_id_001 extends ptw_pde_pmpflg_stage9_base;

  `uvm_component_utils(test_ptw_pde_accerr_priority_type_id_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t  prime_va;
    va_t  deny_va;
    va_t  bus_va;
    pa_t  prime_pa;
    pa_t  deny_pa;
    pa_t  bus_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    pte_t bus_fst_nonleaf;
    pte_t bus_scd_nonleaf;
    pte_t bus_thd_leaf;
    pa_t  tmp_pte_pa;
    pa_t  bus_fst_pte_pa;
    logic [3:0] locked_r_pmpflg;

    prime_va = 39'h0_3c20_0000;
    deny_va  = 39'h0_3c20_1000;
    bus_va   = 39'h0_6c60_0000;
    prime_pa = 40'h0_0c20_0000;
    deny_pa  = 40'h0_0c20_1000;
    bus_pa   = 40'h0_0c60_0000;
    locked_r_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(1));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_pde_accerr_priority_type_id");
    ptw_meta_add_req("PTW-ADD-042");
    ptw_meta_add_req("PDE-TP-017");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h01, STAGE9_ROOT_ASID + 16'h01,
      PRIV_S, 1'b0, 1'b0, 1'b1);

    stage8_map_4k_and_read_path(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_nonleaf(scd_nonleaf),
      .thd_leaf(thd_leaf), .kind("stage9_accerr_priority_prime_l2"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h2a));
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(0), .pa(deny_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_accerr_priority deny leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_STORE, 6'h2c, deny_va, 0, thd_leaf,
      tmp_pte_pa, "stage9_accerr_priority_store_leaf_template");

    stage8_map_4k_and_read_path(.va(bus_va), .pa(bus_pa),
      .fst_nonleaf(bus_fst_nonleaf), .scd_nonleaf(bus_scd_nonleaf),
      .thd_leaf(bus_thd_leaf), .kind("stage9_accerr_priority_buserr_pressure"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_FETCH), .meta_id(6'h00));
    if (!ptw_get_pte_addr_for_level(bus_va, 2, bus_fst_pte_pa))
      `uvm_fatal(get_type_name(), "stage9_accerr_priority bus pressure FST pte addr lookup failed")

    ptw_meta_add_context("locked R-only L2 entry is primed by LOAD; later STORE must return PDE direct access fault with original type/id even while independent FETCH PTW memory bus-error pressure is active");
    ptw_prime_l2_pde_cache_with_type(PTW_SRC_TYPE_LOAD, prime_va, fst_nonleaf,
      scd_nonleaf, locked_r_pmpflg, locked_r_pmpflg, 6'h2a);

    ptw_mem_delay_by_addr(bus_fst_pte_pa, 24);
    ptw_mem_bus_error_by_addr(bus_fst_pte_pa);
    ptw_meta_set_expected("STORE tag-matches the locked R-only L2 PDE entry and must produce PDE_CACHE_PMP_DENY access fault with type=STORE id=0x2c; concurrent delayed FETCH bus-error pressure is present for PTW-SVA-ARB-010 priority cover");

    fork
      begin
        ptw_drive_source_req_by_type(PTW_SRC_TYPE_FETCH, bus_va, 6'h00);
      end
      begin
        stage9_wait_for_ptw_mem_accept("stage9_pde_accerr_priority_buserr_accept", 128);
        stage8_wait_cycles(20);
        fork
          begin
            stage9_wait_for_pde_accerr("stage9_pde_accerr_priority_type_id",
              PTW_SRC_TYPE_STORE, 6'h2c, 192);
          end
          begin
            ptw_drive_source_req_by_type(PTW_SRC_TYPE_STORE, deny_va, 6'h2c);
          end
        join
      end
    join

    ptw_meta_set_actual("source_sb_expected_match_required_stage9; PTW-SVA-ARB-010 cover is required to prove same-cycle priority candidate");
    ptw_meta_set_result("stage9_directed");
    ptw_quiescent_wait("stage9_pde_accerr_priority_type_id");
    ptw_meta_print();
    stage9_close("PTW-ADD-042,PDE-TP-017",
      "stage9_pde_accerr_priority_type_id",
      "directed STORE L2 cached-pmpflg deny checks PDE direct-accerr type/id stability and grant; independent PTW bus-error pressure is driven for priority SVA cover");
    stage9_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_accerr_priority_type_id_001

`endif // TEST_PTW_PDE_ACCERR_PRIORITY_TYPE_ID_001_SVH
