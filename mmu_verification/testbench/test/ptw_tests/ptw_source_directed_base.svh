// =============================================================================
// PTW source directed base
//
// Stage 2 scope:
//   - Provide stable helpers for Sv39 context setup, raw PTE construction,
//     PMP/SysMap/PTW-memory controls, source request driving, quiescent waits,
//     illegal-stimulus guards, and scenario metadata.
//   - This base intentionally records provisional scenario evidence only.
//     Source monitor/ref-model/scoreboard matching is a later-stage task.
// =============================================================================
`ifndef PTW_SOURCE_DIRECTED_BASE_SVH
`define PTW_SOURCE_DIRECTED_BASE_SVH

class ptw_directed_lsu_one_seq extends lsu_base_seq;
  `uvm_object_utils(ptw_directed_lsu_one_seq)

  lsu_kind_e   req_kind;
  va_t         req_va;
  bit [6:0]    req_id;
  bit          req_store;
  bit          req_abort;
  int unsigned req_idle;

  function new(string name = "ptw_directed_lsu_one_seq");
    super.new(name);
    num_txn   = 1;
    req_kind  = LSU_PIPE0;
    req_va    = '0;
    req_id    = 7'h0;
    req_store = 1'b0;
    req_abort = 1'b0;
    req_idle  = 0;
  endfunction

  virtual task body();
    lsu_txn tr;

    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    tr.c_no_abort.constraint_mode(0);
    if (!tr.randomize() with {
          kind        == req_kind;
          va          == {25'b0, req_va};
          va2         == 28'(({25'b0, req_va}) >> PAGE_OFFSET);
          id          == req_id;
          st_inst     == req_store;
          abort       == req_abort;
          idle_cycles == int'(req_idle);
          vabuf       == 28'(({25'b0, req_va}) >> 11);
        })
      `uvm_fatal(get_type_name(), "ptw_directed_lsu_one_seq randomize failed")
    `uvm_send(tr)
  endtask
endclass : ptw_directed_lsu_one_seq

class ptw_directed_lsu_inv_seq extends lsu_base_seq;
  `uvm_object_utils(ptw_directed_lsu_inv_seq)

  lsu_inv_kind_e req_inv_kind;
  bit [26:0]     req_inv_va;
  bit [15:0]     req_inv_asid;
  bit            req_allow_busy;
  int unsigned   req_idle;

  function new(string name = "ptw_directed_lsu_inv_seq");
    super.new(name);
    num_txn = 1;
    req_inv_kind = INV_ASID_ALL;
    req_inv_va = '0;
    req_inv_asid = '0;
    req_allow_busy = 1'b0;
    req_idle = 0;
  endfunction

  virtual task body();
    lsu_txn tr;

    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    if (!tr.randomize() with {
          kind        == LSU_INV;
          inv_kind    == req_inv_kind;
          inv_va      == req_inv_va;
          inv_asid    == req_inv_asid;
          idle_cycles == int'(req_idle);
        })
      `uvm_fatal(get_type_name(), "ptw_directed_lsu_inv_seq randomize failed")
    tr.inv_allow_busy = req_allow_busy;
    `uvm_send(tr)
  endtask
endclass : ptw_directed_lsu_inv_seq

class ptw_directed_ifu_one_seq extends ifu_base_seq;
  `uvm_object_utils(ptw_directed_ifu_one_seq)

  va_t         req_va;
  bit          req_abort;
  int unsigned req_idle;

  function new(string name = "ptw_directed_ifu_one_seq");
    super.new(name);
    num_txn   = 1;
    req_va    = '0;
    req_abort = 1'b0;
    req_idle  = 0;
  endfunction

  virtual task body();
    ifu_txn tr;

    `uvm_create(tr)
    tr.c_no_abort.constraint_mode(0);
    if (!tr.randomize() with {
          va[38:0]    == req_va;
          abort       == req_abort;
          idle_cycles == int'(req_idle);
        })
      `uvm_fatal(get_type_name(), "ptw_directed_ifu_one_seq randomize failed")
    `uvm_send(tr)
  endtask
endclass : ptw_directed_ifu_one_seq

class ptw_source_directed_base extends test_base;

  `uvm_component_utils(ptw_source_directed_base)

  string       ptw_tc_id;
  string       ptw_scenario_id;
  string       ptw_requirement_ids[$];
  string       ptw_context_samples[$];
  string       ptw_level_samples[$];
  string       ptw_expected;
  string       ptw_actual;
  string       ptw_result;
  bit          ptw_current_scenario_open;
  bit          ptw_allow_bare_m_no_request;
  bit          ptw_allow_sysmap_malformed;
  bit          ptw_allow_ptw_mem_ooo;
  bit          ptw_allow_key_reuse;
  bit          ptw_active_keys[string];
  ppn_t        ptw_root_ppn;
  asid_t       ptw_root_asid;
  virtual mmu_dut_probes_if ptw_probe_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 32;
    timeout_ns = 2_000_000;
    ptw_allow_bare_m_no_request = 1'b0;
    ptw_allow_sysmap_malformed  = 1'b0;
    ptw_allow_ptw_mem_ooo       = 1'b0;
    ptw_allow_key_reuse         = 1'b0;
    ptw_root_ppn  = 28'h10;
    ptw_root_asid = 16'h0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(virtual mmu_dut_probes_if)::get(
      this, "", "MMU_DUT_PROBES_VIF", ptw_probe_vif));
  endfunction

  protected function string ptw_req_key(ptw_src_req_type_e req_type, int unsigned id);
    return $sformatf("%0d:%0d", int'(req_type), id);
  endfunction

  protected function string ptw_level_name(int unsigned level);
    case (level)
      2: return "fst";
      1: return "scd";
      0: return "thd";
      default: return "unknown";
    endcase
  endfunction

  protected function string ptw_context_string(
    input ppn_t root_ppn,
    input asid_t asid,
    input bit [1:0] priv,
    input bit mxr,
    input bit sum,
    input bit maee,
    input bit mprv,
    input bit [1:0] mpp
  );
    return $sformatf("satp_mode=sv39 root_ppn=0x%07h asid=0x%04h priv=0x%0h mxr=%0b sum=%0b maee=%0b mprv=%0b mpp=0x%0h",
      root_ppn, asid, priv, mxr, sum, maee, mprv, mpp);
  endfunction

  virtual function void ptw_meta_begin(string tc_id, string scenario_id);
    if (ptw_current_scenario_open)
      ptw_meta_print();
    ptw_tc_id = tc_id;
    ptw_scenario_id = scenario_id;
    ptw_requirement_ids.delete();
    ptw_context_samples.delete();
    ptw_level_samples.delete();
    ptw_expected = "unset";
    ptw_actual   = "not_checked_stage2";
    ptw_result   = "provisional";
    ptw_current_scenario_open = 1'b1;
    if ((m_env != null) && (m_env.m_cfg != null)
        && (m_env.m_ptw_scenario_db != null)
        && m_env.m_cfg.en_ptw_source_monitor)
      m_env.m_ptw_scenario_db.register_scenario(scenario_id);
  endfunction

  virtual function void ptw_meta_add_req(string req_id);
    ptw_requirement_ids.push_back(req_id);
    if ((m_env != null) && (m_env.m_cfg != null)
        && (m_env.m_ptw_scenario_db != null)
        && m_env.m_cfg.en_ptw_source_monitor)
      m_env.m_ptw_scenario_db.register_scenario(ptw_scenario_id, req_id);
  endfunction

  virtual function void ptw_meta_add_context(string context);
    ptw_context_samples.push_back(context);
  endfunction

  virtual function void ptw_meta_add_level(
    input ptw_src_req_type_e req_type,
    input int unsigned id,
    input va_t va,
    input int unsigned level,
    input pte_t raw_pte,
    input pa_t pte_pa,
    input string kind = "pte"
  );
    vpn_t vpn;
    vpn = va[38:12];
    ptw_level_samples.push_back(
      $sformatf("kind=%s type=%s id=%0d vpn=0x%07h level=%s raw_pte=0x%016h pte_pa=0x%010h",
        kind, ptw_src_type_name(req_type), id, vpn, ptw_level_name(level),
        raw_pte, pte_pa));
  endfunction

  virtual function void ptw_meta_set_expected(string expected);
    ptw_expected = expected;
  endfunction

  virtual function void ptw_meta_set_actual(string actual);
    ptw_actual = actual;
  endfunction

  virtual function void ptw_meta_set_result(string result);
    ptw_result = result;
  endfunction

  virtual function void ptw_meta_print();
    string reqs;
    string contexts;
    string levels;

    reqs = "";
    foreach (ptw_requirement_ids[i])
      reqs = {reqs, (i == 0) ? "" : "|", ptw_requirement_ids[i]};
    contexts = "";
    foreach (ptw_context_samples[i])
      contexts = {contexts, (i == 0) ? "" : " ; ", ptw_context_samples[i]};
    levels = "";
    foreach (ptw_level_samples[i])
      levels = {levels, (i == 0) ? "" : " ; ", ptw_level_samples[i]};

    `uvm_info(get_type_name(),
      $sformatf("PTW_SCENARIO_META tc_id=%s scenario_id=%s requirement_ids=%s context={%s} levels={%s} expected={%s} actual={%s} result=%s provisional=1",
        ptw_tc_id, ptw_scenario_id, reqs, contexts, levels,
        ptw_expected, ptw_actual, ptw_result),
      UVM_NONE)
    ptw_current_scenario_open = 1'b0;
  endfunction

  virtual function void ptw_guard_start_key(ptw_src_req_type_e req_type, int unsigned id);
    string key;
    key = ptw_req_key(req_type, id);
    if (!ptw_src_is_legal_req_type(req_type))
      `uvm_fatal(get_type_name(), $sformatf("Illegal PTW source request type=0x%0h", req_type))
    if (!ptw_allow_key_reuse && ptw_active_keys.exists(key))
      `uvm_fatal(get_type_name(), $sformatf("PTW source {type,id} reuse blocked: key=%s", key))
    ptw_active_keys[key] = 1'b1;
  endfunction

  virtual function void ptw_guard_done_key(ptw_src_req_type_e req_type, int unsigned id);
    string key;
    key = ptw_req_key(req_type, id);
    if (ptw_active_keys.exists(key))
      ptw_active_keys.delete(key);
  endfunction

  virtual task ptw_set_maee(bit enable);
    if (enable) begin
      cp0_maee_enable_seq seq = cp0_maee_enable_seq::type_id::create("ptw_maee_enable_seq");
      seq.start(m_env.m_cp0.m_sequencer);
    end else begin
      cp0_maee_disable_seq seq = cp0_maee_disable_seq::type_id::create("ptw_maee_disable_seq");
      seq.start(m_env.m_cp0.m_sequencer);
    end
  endtask

  virtual task ptw_set_mxr_sum(bit mxr, bit sum);
    cp0_mxr_sum_cross_seq seq;
    seq = cp0_mxr_sum_cross_seq::type_id::create("ptw_mxr_sum_seq");
    seq.mxr_val = mxr;
    seq.sum_val = sum;
    seq.start(m_env.m_cp0.m_sequencer);
  endtask

  virtual task ptw_set_priv(bit [1:0] priv);
    cp0_priv_switch_seq seq;
    seq = cp0_priv_switch_seq::type_id::create("ptw_priv_seq");
    seq.priv_mode = priv;
    seq.start(m_env.m_cp0.m_sequencer);
  endtask

  virtual task ptw_set_mprv_mpp(bit mprv, bit [1:0] mpp);
    cp0_mprv_seq seq;
    seq = cp0_mprv_seq::type_id::create("ptw_mprv_seq");
    seq.mprv_val = mprv;
    seq.mpp_val  = mpp;
    seq.start(m_env.m_cp0.m_sequencer);
  endtask

  virtual task ptw_setup_sv39(
    input ppn_t root_ppn = 28'h10,
    input asid_t asid = 16'h0,
    input bit [1:0] priv = PRIV_S,
    input bit mxr = 1'b0,
    input bit sum = 1'b0,
    input bit maee = 1'b1,
    input bit mprv = 1'b0,
    input bit [1:0] mpp = PRIV_M
  );
    cp0_tlb_allinv_seq cp0_inv;
    cp0_reg_rw_seq     cp0_init;
    ptw_mem_directed_clear_seq ptw_mem_clear;

    if (!ptw_allow_bare_m_no_request && (priv == PRIV_M) && !mprv)
      `uvm_fatal(get_type_name(), "Bare/M no-request guard: pure M-mode PTW source scenario is disabled by default")

    ptw_root_ppn  = root_ppn;
    ptw_root_asid = asid;

    cp0_inv = cp0_tlb_allinv_seq::type_id::create("ptw_cp0_tlb_allinv_seq");
    cp0_inv.start(m_env.m_cp0.m_sequencer);

    ptw_pmp_allow_all();
    ptw_sysmap_disable_all();

    cp0_init = cp0_reg_rw_seq::type_id::create("ptw_cp0_reg_rw_seq");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'(asid), 44'(root_ppn)};
          priv_mode == priv;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "ptw_setup_sv39 cp0_init randomize failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);

    ptw_set_mxr_sum(mxr, sum);
    ptw_set_maee(maee);
    ptw_set_mprv_mpp(mprv, mpp);

    ptw_mem_clear = ptw_mem_directed_clear_seq::type_id::create("ptw_mem_clear_seq");
    ptw_mem_clear.start(m_env.m_ptw_mem.m_sequencer);

    m_env.m_pt_mem.m_builder.set_root(root_ppn, asid);
    if (m_env.m_ref != null)
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context(ptw_context_string(root_ppn, asid, priv, mxr, sum, maee, mprv, mpp));
    #100ns;
  endtask

  virtual task ptw_pmp_allow_all();
    pmp_flg_normal_seq seq;
    seq = pmp_flg_normal_seq::type_id::create("ptw_pmp_allow_all_seq");
    seq.start(m_env.m_pmp.m_sequencer);
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context("pmp=allow_all");
  endtask

  virtual task ptw_pmp_deny_ptw_reads(bit [3:0] deny_twu_mask = 4'b1111);
    pmp_flg_deny_ptw_rd_seq seq;
    seq = pmp_flg_deny_ptw_rd_seq::type_id::create("ptw_pmp_deny_ptw_rd_seq");
    seq.deny_twu_mask = deny_twu_mask;
    seq.start(m_env.m_pmp.m_sequencer);
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context($sformatf("pmp=deny_ptw_read deny_twu_mask=0x%0h", deny_twu_mask));
  endtask

  virtual task ptw_sysmap_disable_all();
    sysmap_region_setup_seq seq;
    seq = sysmap_region_setup_seq::type_id::create("ptw_sysmap_disable_all_seq");
    seq.enable_r0 = 1'b0;
    seq.start(m_env.m_sysmap_cfg.m_sequencer);
    ptw_meta_add_context("sysmap=disabled_all");
  endtask

  virtual task ptw_sysmap_one_region(
    input bit [2:0] region_idx = 3'd0,
    input ppn_t base_ppn = 28'h0,
    input ppn_t mask = 28'hFFF_FFFF,
    input bit [4:0] flg = 5'b01111
  );
    sysmap_hit_cross_tlb_seq seq;
    seq = sysmap_hit_cross_tlb_seq::type_id::create("ptw_sysmap_one_region_seq");
    seq.region_idx = region_idx;
    seq.hit_base   = base_ppn;
    seq.hit_mask   = mask;
    seq.hit_flg    = flg;
    seq.start(m_env.m_sysmap_cfg.m_sequencer);
    ptw_meta_add_context($sformatf("sysmap=one_region idx=%0d base=0x%07h mask=0x%07h flg=0x%02h",
      region_idx, base_ppn, mask, flg));
  endtask

  virtual function bit ptw_write_raw_pte_level(
    input va_t va,
    input int unsigned level,
    input pte_t raw_pte,
    output pa_t pte_pa,
    input bit create_path = 1'b1
  );
    return m_env.m_pt_mem.m_builder.write_raw_pte_for_level(
      .va(va), .level(level), .raw_pte(raw_pte),
      .pte_addr(pte_pa), .create_path(create_path));
  endfunction

  virtual function bit ptw_map_raw_leaf_pa(
    input va_t va,
    input int unsigned level,
    input pa_t pa,
    output pte_t raw_pte,
    output pa_t pte_pa,
    input bit v = 1,
    input bit r = 1,
    input bit w = 1,
    input bit x = 1,
    input bit u = 0,
    input bit g = 0,
    input bit a = 1,
    input bit d = 1,
    input bit [1:0] rsw = 2'b00,
    input bit [20:0] high_reserved = 21'h0,
    input bit [4:0] ext_attr = 5'h0,
    input bit allow_misaligned = 1'b0
  );
    return m_env.m_pt_mem.m_builder.map_raw_leaf_pa(
      .va(va), .level(level), .pa(pa),
      .v(v), .r(r), .w(w), .x(x), .u(u), .g(g), .a(a), .d(d),
      .rsw(rsw), .high_reserved(high_reserved), .ext_attr(ext_attr),
      .allow_misaligned(allow_misaligned),
      .raw_pte(raw_pte), .pte_addr(pte_pa));
  endfunction

  virtual function bit ptw_write_nonleaf(
    input va_t va,
    input int unsigned level,
    input ppn_t next_ppn,
    output pte_t raw_pte,
    output pa_t pte_pa,
    input bit legal = 1'b1,
    input bit create_path = 1'b1,
    input bit r = 0,
    input bit w = 0,
    input bit x = 0
  );
    pte_t tmp_pte;
    pa_t  tmp_pa;
    bit   ok;

    ok = m_env.m_pt_mem.m_builder.write_nonleaf_for_level(
      .va(va), .level(level), .next_ppn(next_ppn),
      .raw_pte(tmp_pte), .pte_addr(tmp_pa), .legal(legal),
      .create_path(create_path), .r(r), .w(w), .x(x));
    raw_pte = tmp_pte;
    pte_pa  = tmp_pa;
    return ok;
  endfunction

  virtual function bit ptw_get_pte_addr_for_level(
    input va_t va,
    input int unsigned level,
    output pa_t pte_pa
  );
    return m_env.m_pt_mem.m_builder.get_pte_addr_for_level(va, level, pte_pa);
  endfunction

  virtual task ptw_mem_delay_by_addr(pa_t pte_pa, int unsigned delay);
    ptw_mem_delay_by_addr_seq seq;
    seq = ptw_mem_delay_by_addr_seq::type_id::create("ptw_mem_delay_by_addr_seq");
    seq.addr = pte_pa;
    seq.delay = delay;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_delay_by_addr addr=0x%010h delay=%0d", pte_pa, delay));
  endtask

  virtual task ptw_mem_delay_by_count(int unsigned accept_count, int unsigned delay);
    ptw_mem_delay_by_count_seq seq;
    seq = ptw_mem_delay_by_count_seq::type_id::create("ptw_mem_delay_by_count_seq");
    seq.accept_count = accept_count;
    seq.delay = delay;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_delay_by_count count=%0d delay=%0d", accept_count, delay));
  endtask

  virtual task ptw_mem_bus_error_by_addr(pa_t pte_pa);
    ptw_mem_bus_error_by_addr_seq seq;
    seq = ptw_mem_bus_error_by_addr_seq::type_id::create("ptw_mem_bus_error_by_addr_seq");
    seq.addr = pte_pa;
    seq.enable = 1'b1;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_bus_error_by_addr addr=0x%010h", pte_pa));
  endtask

  virtual task ptw_mem_bus_error_by_count(int unsigned accept_count);
    ptw_mem_bus_error_by_count_seq seq;
    seq = ptw_mem_bus_error_by_count_seq::type_id::create("ptw_mem_bus_error_by_count_seq");
    seq.accept_count = accept_count;
    seq.enable = 1'b1;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_bus_error_by_count count=%0d", accept_count));
  endtask

  virtual task ptw_mem_same_cycle_abort_data(int unsigned accept_count);
    ptw_mem_same_cycle_abort_data_seq seq;
    seq = ptw_mem_same_cycle_abort_data_seq::type_id::create("ptw_mem_same_cycle_abort_data_seq");
    seq.accept_count = accept_count;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_same_cycle_abort_data count=%0d", accept_count));
  endtask

  virtual task ptw_mem_same_cycle_abort_bus_error(int unsigned accept_count);
    ptw_mem_same_cycle_abort_bus_error_seq seq;
    seq = ptw_mem_same_cycle_abort_bus_error_seq::type_id::create("ptw_mem_same_cycle_abort_bus_error_seq");
    seq.accept_count = accept_count;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_same_cycle_abort_bus_error count=%0d", accept_count));
  endtask

  virtual task ptw_mem_chk_not_ready_slow(int unsigned slow_cycles = 96);
    ptw_mem_chk_not_ready_slow_seq seq;
    seq = ptw_mem_chk_not_ready_slow_seq::type_id::create("ptw_mem_chk_not_ready_slow_seq");
    seq.slow_cycles = slow_cycles;
    seq.start(m_env.m_ptw_mem.m_sequencer);
    ptw_meta_add_context($sformatf("ptw_mem_chk_not_ready_slow cycles=%0d", slow_cycles));
  endtask

  virtual task ptw_attempt_ptw_mem_ooo();
    if (!ptw_allow_ptw_mem_ooo)
      `uvm_fatal(get_type_name(), "PTW memory OOO stimulus is blocked by default")
    begin
      ptw_mem_ooo_rsp_seq seq;
      seq = ptw_mem_ooo_rsp_seq::type_id::create("ptw_mem_ooo_rsp_seq");
      seq.start(m_env.m_ptw_mem.m_sequencer);
    end
  endtask

  virtual task ptw_wait_for_tlboper_ptw_abort(
    input string ctx = "ptw_wait_for_tlboper_ptw_abort",
    input int unsigned max_cycles = 2048
  );
    bit seen;

    seen = 1'b0;
    if (ptw_probe_vif == null) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: MMU_DUT_PROBES_VIF unavailable; SATP process-switch constraint cannot prove tlboper_ptw_abort", ctx))
      ptw_meta_add_context({ctx, ": probe_unavailable_abort_wait_skipped"});
      return;
    end

    repeat (max_cycles) begin
      @(ptw_probe_vif.mon_cb);
      if (ptw_probe_vif.mon_cb.tlboper_ptw_abort === 1'b1) begin
        seen = 1'b1;
        break;
      end
    end

    if (!seen) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: did not observe tlboper_ptw_abort within %0d cycles after LSU ASID invalidate",
          ctx, max_cycles))
    end else begin
      ptw_meta_add_context({ctx, ": observed_lsu_asid_inv_tlboper_ptw_abort"});
    end
  endtask

  virtual task ptw_drive_satp_change_asid_tlboper_abort(
    input asid_t asid,
    input string ctx = "ptw_satp_change_asid_tlboper_abort",
    input int unsigned max_abort_wait_cycles = 2048
  );
    ptw_directed_lsu_inv_seq seq;

    if ((m_env == null) || (m_env.m_lsu == null) || (m_env.m_lsu.m_sequencer == null))
      `uvm_fatal(get_type_name(),
        $sformatf("%s: LSU sequencer unavailable; cannot drive process-switch INV_ASID_ALL", ctx))

    seq = ptw_directed_lsu_inv_seq::type_id::create("ptw_satp_change_asid_inv_seq");
    seq.req_inv_kind = INV_ASID_ALL;
    seq.req_inv_va = '0;
    seq.req_inv_asid = asid;
    seq.req_allow_busy = 1'b1;
    seq.req_idle = 0;

    fork
      begin
        ptw_wait_for_tlboper_ptw_abort(ctx, max_abort_wait_cycles);
      end
      begin
        #0;
        seq.start(m_env.m_lsu.m_sequencer);
      end
    join

    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context($sformatf("satp_change_lsu_tlboper kind=INV_ASID_ALL asid=0x%04h allow_busy=1", asid));
  endtask

  virtual task ptw_drive_lsu(
    input va_t va,
    input int unsigned id = 0,
    input bit is_store = 1'b0,
    input bit abort = 1'b0,
    input lsu_kind_e kind = LSU_PIPE0
  );
    ptw_directed_lsu_one_seq seq;
    ptw_src_req_type_e req_type;
    bit [6:0] req_id;

    req_id = id[6:0];
    req_type = (kind == LSU_PIPE2) ? PTW_SRC_TYPE_PFU :
               (is_store ? PTW_SRC_TYPE_STORE : PTW_SRC_TYPE_LOAD);
    ptw_guard_start_key(req_type, req_id);
    seq = ptw_directed_lsu_one_seq::type_id::create("ptw_directed_lsu_one_seq");
    seq.req_kind  = kind;
    seq.req_va    = va;
    seq.req_id    = req_id;
    seq.req_store = is_store;
    seq.req_abort = abort;
    seq.req_idle  = 0;
    seq.start(m_env.m_lsu.m_sequencer);
  endtask

  virtual task ptw_drive_lsu_load(input va_t va, input int unsigned id = 0, input bit abort = 1'b0);
    ptw_drive_lsu(.va(va), .id(id), .is_store(1'b0), .abort(abort), .kind(LSU_PIPE0));
  endtask

  virtual task ptw_drive_lsu_store(input va_t va, input int unsigned id = 0, input bit abort = 1'b0);
    ptw_drive_lsu(.va(va), .id(id), .is_store(1'b1), .abort(abort), .kind(LSU_PIPE0));
  endtask

  virtual task ptw_drive_pfu(input va_t va, input int unsigned id = 0);
    ptw_drive_lsu(.va(va), .id(id), .is_store(1'b0), .abort(1'b0), .kind(LSU_PIPE2));
  endtask

  virtual task ptw_drive_fetch(input va_t va, input bit abort = 1'b0);
    ptw_directed_ifu_one_seq seq;
    ptw_guard_start_key(PTW_SRC_TYPE_FETCH, 0);
    seq = ptw_directed_ifu_one_seq::type_id::create("ptw_directed_ifu_one_seq");
    seq.req_va = va;
    seq.req_abort = abort;
    seq.req_idle = 0;
    seq.start(m_env.m_ifu.m_sequencer);
  endtask

  virtual task ptw_quiescent_wait(
    input string ctx = "ptw_source_directed",
    input int unsigned max_cycles = 262144,
    input int unsigned stable_cycles = 16
  );
    m_env.wait_for_quiescent_midtest(ctx, max_cycles, stable_cycles);
    ptw_active_keys.delete();
  endtask

  virtual function void ptw_enable_illegal_sysmap(bit enable = 1'b1);
    ptw_allow_sysmap_malformed = enable;
  endfunction

  virtual function void ptw_enable_ptw_mem_ooo(bit enable = 1'b1);
    ptw_allow_ptw_mem_ooo = enable;
    if (enable)
      `uvm_warning(get_type_name(), "PTW memory OOO is illegal for normal PTW source directed tests")
  endfunction

  virtual function void ptw_enable_bare_m_no_request(bit enable = 1'b1);
    ptw_allow_bare_m_no_request = enable;
  endfunction

  virtual function void ptw_enable_key_reuse(bit enable = 1'b1);
    ptw_allow_key_reuse = enable;
    if (enable)
      `uvm_warning(get_type_name(), "PTW source {type,id} reuse is illegal for normal source directed tests")
  endfunction

endclass : ptw_source_directed_base

`endif // PTW_SOURCE_DIRECTED_BASE_SVH
