// =============================================================================
// PTW source-side scoreboard
//
// Stage 4 scope:
//   - Match source ref-model expected transactions to source monitor actuals by
//     {type,id}; compare final class and fields without fixed latency checks.
//   - Detect duplicate {type,id} request reuse before completion/drop.
//   - Match drop/no-output expectations.
//   - Classify mismatches for field/class/drop/pending/illegal/probe-gap.
//
// Stage 7 scope:
//   - Add field/function coverage-style counters to the summary so P1/P2/random
//     logs can prove more than a global pass/fail.
//   - Print pending age/debug taxonomy, illegal-stimulus classification, and
//     consumer-only/auxiliary rules in machine-parseable banners.
// =============================================================================
`ifndef PTW_SOURCE_SB_SVH
`define PTW_SOURCE_SB_SVH

class ptw_source_sb extends uvm_scoreboard;

  `uvm_component_utils(ptw_source_sb)

  mmu_top_cfg m_cfg;

  uvm_tlm_analysis_fifo #(ptw_src_expected_rsp_txn) af_expected;
  uvm_tlm_analysis_fifo #(ptw_src_actual_rsp_txn)   af_actual;
  uvm_tlm_analysis_fifo #(ptw_src_req_accept_txn)   af_req;
  uvm_tlm_analysis_fifo #(ptw_src_ctx_sample_txn)   af_ctx;
  uvm_tlm_analysis_fifo #(ptw_src_pde_evt_txn)      af_pde;
  uvm_tlm_analysis_fifo #(ptw_src_drop_txn)         af_drop;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_drop;

  typedef struct {
    bit                    valid;
    ptw_src_req_type_e     req_type;
    logic [5:0]            id;
    vpn_t                  vpn;
    ptw_src_access_src_e   access_src;
    ptw_src_pde_reason_e   pde_reason;
    logic [3:0]            pde_l1pmpflg;
    logic [3:0]            pde_l2pmpflg;
    bit                    pde_direct_accerr;
    int unsigned           cycle;
  } pde_root_expected_s;

  typedef struct {
    bit                    active;
    ptw_src_req_type_e     req_type;
    logic [5:0]            id;
    vpn_t                  vpn;
    int unsigned           start_cycle;
    int unsigned           mem_req_seen_after_accerr;
    bit                    violation_seen;
    bit                    ambiguous_seen;
  } pde_direct_accerr_window_s;

  ptw_src_expected_rsp_txn m_expected_q[string][$];
  ptw_src_actual_rsp_txn   m_actual_q[string][$];
  ptw_src_expected_rsp_txn m_drop_expected_q[$];
  ptw_src_drop_txn         m_drop_actual_q[$];
  bit                      m_active_keys[string];
  ptw_src_req_accept_txn   m_active_req[string];
  ptw_src_ctx_sample_txn   m_ctx_by_key[string];
  ptw_src_pde_evt_txn      m_pde_direct_accerr_q[string][$];
  pde_root_expected_s      m_pde_root_pending_q[string][$];
  pde_direct_accerr_window_s m_pde_no_extra_lsu_window[string];
  int unsigned             m_last_visible_cycle[string];
  bit                      m_pde_direct_accerr_cov_seen[string];
  bit                      m_pde_root_seen[string];
  bit                      m_no_extra_lsu_credit_key[string];

  int unsigned n_accepted;
  int unsigned n_expected;
  int unsigned n_actual;
  int unsigned n_drop_expected;
  int unsigned n_drop_actual;
  int unsigned n_matched;
  int unsigned n_mismatch;
  int unsigned n_pending;
  int unsigned n_illegal;
  int unsigned n_class_mismatch;
  int unsigned n_field_mismatch;
  int unsigned n_drop_mismatch;
  int unsigned n_pending_expected;
  int unsigned n_pending_actual;
  int unsigned n_probe_gap;
  int unsigned n_mem_req;
  int unsigned n_mem_rsp;
  int unsigned n_mem_drop;
  int unsigned n_cov_refill;
  int unsigned n_cov_page_fault;
  int unsigned n_cov_access_fault;
  int unsigned n_cov_drop;
  int unsigned n_cov_type_fetch;
  int unsigned n_cov_type_load;
  int unsigned n_cov_type_store;
  int unsigned n_cov_type_pfu;
  int unsigned n_cov_pgs_1g;
  int unsigned n_cov_pgs_2m;
  int unsigned n_cov_pgs_4k;
  int unsigned n_cov_global;
  int unsigned n_cov_fault_page;
  int unsigned n_cov_fault_access;
  int unsigned n_cov_fault_bus_error;
  int unsigned n_cov_drop_reset;
  int unsigned n_cov_drop_abort;
  int unsigned n_cov_drop_late;
  int unsigned n_cov_drop_abort_bus_error;
  int unsigned n_cov_pre_existing_exception_grant;
  int unsigned n_cov_target_l1i;
  int unsigned n_cov_target_l1d;
  int unsigned n_cov_target_pfu;
  int unsigned n_cov_target_l2;
  int unsigned n_cov_pde_l1_tag_hit_allow;
  int unsigned n_cov_pde_l1_tag_hit_deny_miss;
  int unsigned n_cov_pde_l2_tag_hit_allow;
  int unsigned n_cov_pde_l2_l1pmp_deny_accerr;
  int unsigned n_cov_pde_l2_l2pmp_deny_accerr;
  int unsigned n_cov_pde_l2_both_pmp_deny_accerr;
  int unsigned n_cov_pde_update_l1_pmpflg;
  int unsigned n_cov_pde_update_l2_pmpflg;
  int unsigned n_cov_pde_direct_accerr_type_load;
  int unsigned n_cov_pde_direct_accerr_type_store;
  int unsigned n_cov_pde_direct_accerr_type_fetch;
  int unsigned n_cov_pde_direct_accerr_type_pfu;
  int unsigned n_cov_pde_mmode_bypass;
  int unsigned n_cov_pde_mmode_lock_deny;
  int unsigned n_cov_pde_no_extra_lsu;
  int unsigned n_no_extra_lsu_window_opened;
  int unsigned n_no_extra_lsu_violation;
  int unsigned n_probe_gap_no_extra_lsu_ambiguous;
  int unsigned n_probe_gap_pde_root_missing;
  int unsigned n_pde_root_matched;
  int unsigned n_pending_oldest_age;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    af_expected = new("af_expected", this);
    af_actual   = new("af_actual",   this);
    af_req      = new("af_req",      this);
    af_ctx      = new("af_ctx",      this);
    af_pde      = new("af_pde",      this);
    af_drop     = new("af_drop",     this);
    af_mem_req  = new("af_mem_req",  this);
    af_mem_rsp  = new("af_mem_rsp",  this);
    af_mem_drop = new("af_mem_drop", this);

    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=source_sb stage=7 status=created provisional=0",
      UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      collect_expected();
      collect_actual();
      collect_req();
      collect_ctx();
      collect_pde();
      collect_drop();
      collect_mem_req();
      collect_mem_rsp();
      collect_mem_drop();
    join_none
  endtask

  protected function string key_string(input logic [2:0] req_type, input logic [5:0] id);
    return $sformatf("%0h:%0h", req_type, id);
  endfunction

  protected function string cycle_key_string(
    input logic [2:0]  req_type,
    input logic [5:0]  id,
    input int unsigned cycle
  );
    return $sformatf("%s:%0d", key_string(req_type, id), cycle);
  endfunction

  protected function bit pde_reason_is_l2_direct_accerr(
    input ptw_src_pde_reason_e reason
  );
    return (reason == PTW_SRC_PDE_REASON_L2_L1PMP_DENY)
        || (reason == PTW_SRC_PDE_REASON_L2_L2PMP_DENY)
        || (reason == PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY);
  endfunction

  protected function bit expected_has_pde_root(
    input ptw_src_expected_rsp_txn exp
  );
    return exp.pde_direct_accerr
        || (exp.access_src == PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY);
  endfunction

  protected function bit effective_machine_from_ctx(
    input ptw_src_ctx_sample_txn ctx
  );
    if (ctx.req_type == PTW_SRC_TYPE_FETCH)
      return (ctx.priv_mode == PRIV_M);
    if (ctx.priv_mode == PRIV_M)
      return 1'b1;
    if (ptw_src_is_data_type(ctx.req_type) && ctx.mprv && (ctx.mpp == PRIV_M))
      return 1'b1;
    return 1'b0;
  endfunction

  protected function void sample_pde_direct_accerr_type(
    input ptw_src_req_type_e req_type
  );
    case (req_type)
      PTW_SRC_TYPE_LOAD:  n_cov_pde_direct_accerr_type_load++;
      PTW_SRC_TYPE_STORE: n_cov_pde_direct_accerr_type_store++;
      PTW_SRC_TYPE_FETCH: n_cov_pde_direct_accerr_type_fetch++;
      PTW_SRC_TYPE_PFU:   n_cov_pde_direct_accerr_type_pfu++;
      default: ;
    endcase
  endfunction

  protected function bit expected_has_key(input ptw_src_expected_rsp_txn exp);
    return (exp.kind != PTW_SRC_EXP_DROP) || exp.has_drop_key;
  endfunction

  protected function bit fault_kind_matches(
    input ptw_src_expected_rsp_txn exp,
    input ptw_src_actual_rsp_txn actual
  );
    if (exp.fault_kind == actual.fault_kind)
      return 1'b1;

    // LSU bus error is a root cause in the source ref model, but the visible
    // PTW/L1TLB completion is the same access-fault class as PMP deny.
    if ((exp.kind == PTW_SRC_EXP_ACCESS_FAULT)
        && (actual.kind == PTW_SRC_EXP_ACCESS_FAULT)
        && (exp.fault_kind == PTW_SRC_FAULT_BUS_ERROR)
        && (actual.fault_kind == PTW_SRC_FAULT_ACCESS))
      return 1'b1;

    return 1'b0;
  endfunction

  protected function string compare_completion(
    input ptw_src_expected_rsp_txn exp,
    input ptw_src_actual_rsp_txn actual
  );
    string msg;

    msg = "";
    if (exp.kind != actual.kind)
      msg = {msg, $sformatf(" class exp=%s act=%s;", exp.kind.name(), actual.kind.name())};
    if (exp.req_type != actual.req_type)
      msg = {msg, $sformatf(" type exp=%s act=%s;", exp.req_type.name(), actual.req_type.name())};
    if (exp.id != actual.id)
      msg = {msg, $sformatf(" id exp=0x%02h act=0x%02h;", exp.id, actual.id)};
    if (exp.kind == PTW_SRC_EXP_REFILL) begin
      if (exp.vpn != actual.vpn)
        msg = {msg, $sformatf(" vpn exp=0x%07h act=0x%07h;", exp.vpn, actual.vpn)};
      if (exp.asid != actual.asid)
        msg = {msg, $sformatf(" asid exp=0x%04h act=0x%04h;", exp.asid, actual.asid)};
      if (exp.page_size != actual.page_size)
        msg = {msg, $sformatf(" page_size exp=%s act=%s;", exp.page_size.name(), actual.page_size.name())};
      if (exp.ppn != actual.ppn)
        msg = {msg, $sformatf(" ppn exp=0x%07h act=0x%07h;", exp.ppn, actual.ppn)};
      if (exp.global_bit != actual.global_bit)
        msg = {msg, $sformatf(" global exp=%0b act=%0b;", exp.global_bit, actual.global_bit)};
      if (exp.flg != actual.flg)
        msg = {msg, $sformatf(" flg exp=0x%04h act=0x%04h;", exp.flg, actual.flg)};
    end
    if (exp.target != actual.target)
      msg = {msg, $sformatf(" target exp=%s act=%s;", exp.target.name(), actual.target.name())};
    if (!fault_kind_matches(exp, actual))
      msg = {msg, $sformatf(" fault exp=%s act=%s;", exp.fault_kind.name(), actual.fault_kind.name())};
    if (exp.target_l2tlb != actual.target_l2tlb)
      msg = {msg, $sformatf(" target_l2 exp=%0b act=%0b;", exp.target_l2tlb, actual.target_l2tlb)};
    if (exp.target_l1i != actual.target_l1i)
      msg = {msg, $sformatf(" target_l1i exp=%0b act=%0b;", exp.target_l1i, actual.target_l1i)};
    if (exp.target_l1d != actual.target_l1d)
      msg = {msg, $sformatf(" target_l1d exp=%0b act=%0b;", exp.target_l1d, actual.target_l1d)};
    if (exp.target_pfu != actual.target_pfu)
      msg = {msg, $sformatf(" target_pfu exp=%0b act=%0b;", exp.target_pfu, actual.target_pfu)};
    msg = {msg, compare_expected_pde_root(exp)};
    return msg;
  endfunction

  protected function string compare_drop(
    input ptw_src_expected_rsp_txn exp,
    input ptw_src_drop_txn actual
  );
    string msg;

    msg = "";
    if (exp.drop_reason != actual.drop_reason)
      msg = {msg, $sformatf(" reason exp=%s act=%s;", exp.drop_reason.name(), actual.drop_reason.name())};
    if (exp.has_drop_key != actual.has_key)
      msg = {msg, $sformatf(" has_key exp=%0b act=%0b;", exp.has_drop_key, actual.has_key)};
    if (exp.has_drop_key && actual.has_key) begin
      if (exp.req_type != actual.key.req_type)
        msg = {msg, $sformatf(" type exp=%s act=%s;", exp.req_type.name(), actual.key.req_type.name())};
      if (exp.id != actual.key.id)
        msg = {msg, $sformatf(" id exp=0x%02h act=0x%02h;", exp.id, actual.key.id)};
      if (exp.vpn != actual.vpn)
        msg = {msg, $sformatf(" vpn exp=0x%07h act=0x%07h;", exp.vpn, actual.vpn)};
    end
    if (exp.reset_drop != actual.reset_drop)
      msg = {msg, $sformatf(" reset exp=%0b act=%0b;", exp.reset_drop, actual.reset_drop)};
    if (exp.abort_drop != actual.abort_drop)
      msg = {msg, $sformatf(" abort exp=%0b act=%0b;", exp.abort_drop, actual.abort_drop)};
    if (exp.late_data != actual.late_data)
      msg = {msg, $sformatf(" late_data exp=%0b act=%0b;", exp.late_data, actual.late_data)};
    if (exp.abort_bus_error != actual.abort_bus_error)
      msg = {msg, $sformatf(" abort_bus_error exp=%0b act=%0b;", exp.abort_bus_error, actual.abort_bus_error)};
    if (exp.pre_existing_exception_grant != actual.pre_existing_exception_grant)
      msg = {msg, $sformatf(" pre_existing exp=%0b act=%0b;", exp.pre_existing_exception_grant, actual.pre_existing_exception_grant)};
    return msg;
  endfunction

  protected function void sample_req_type(input ptw_src_req_type_e req_type);
    case (req_type)
      PTW_SRC_TYPE_FETCH: n_cov_type_fetch++;
      PTW_SRC_TYPE_LOAD:  n_cov_type_load++;
      PTW_SRC_TYPE_STORE: n_cov_type_store++;
      PTW_SRC_TYPE_PFU:   n_cov_type_pfu++;
      default: ;
    endcase
  endfunction

  protected function void sample_expected_coverage(input ptw_src_expected_rsp_txn exp);
    sample_req_type(exp.req_type);
    case (exp.kind)
      PTW_SRC_EXP_REFILL: begin
        n_cov_refill++;
        case (exp.page_size)
          PTW_SRC_PGS_1G: n_cov_pgs_1g++;
          PTW_SRC_PGS_2M: n_cov_pgs_2m++;
          PTW_SRC_PGS_4K: n_cov_pgs_4k++;
          default: ;
        endcase
        if (exp.global_bit)
          n_cov_global++;
      end
      PTW_SRC_EXP_PAGE_FAULT: n_cov_page_fault++;
      PTW_SRC_EXP_ACCESS_FAULT: n_cov_access_fault++;
      PTW_SRC_EXP_DROP: n_cov_drop++;
      default: ;
    endcase
    case (exp.fault_kind)
      PTW_SRC_FAULT_PAGE: n_cov_fault_page++;
      PTW_SRC_FAULT_ACCESS: n_cov_fault_access++;
      PTW_SRC_FAULT_BUS_ERROR: n_cov_fault_bus_error++;
      default: ;
    endcase
    case (exp.drop_reason)
      PTW_SRC_DROP_RESET: n_cov_drop_reset++;
      PTW_SRC_DROP_ABORT: n_cov_drop_abort++;
      PTW_SRC_DROP_LATE_DATA: n_cov_drop_late++;
      PTW_SRC_DROP_ABORT_BUS_ERROR: n_cov_drop_abort_bus_error++;
      PTW_SRC_DROP_PRE_EXISTING_EXCEPTION_GRANT: n_cov_pre_existing_exception_grant++;
      default: ;
    endcase
    if (exp.target_l1i)
      n_cov_target_l1i++;
    if (exp.target_l1d)
      n_cov_target_l1d++;
    if (exp.target_pfu)
      n_cov_target_pfu++;
    if (exp.target_l2tlb)
      n_cov_target_l2++;

  endfunction

  protected function void sample_expected_pde_root_coverage_once(
    input ptw_src_expected_rsp_txn exp
  );
    string key;
    string cov_key;

    if (!expected_has_pde_root(exp))
      return;

    key = key_string(exp.req_type, exp.id);
    cov_key = cycle_key_string(exp.req_type, exp.id, exp.cycle);
    if (m_pde_root_seen.exists(cov_key))
      return;
    if (m_pde_direct_accerr_cov_seen.exists(cov_key))
      return;

    m_pde_root_seen[cov_key] = 1'b1;
    m_pde_direct_accerr_cov_seen[cov_key] = 1'b1;
    sample_pde_direct_accerr_type(exp.req_type);
    case (exp.pde_reason)
      PTW_SRC_PDE_REASON_L2_L1PMP_DENY:
        n_cov_pde_l2_l1pmp_deny_accerr++;
      PTW_SRC_PDE_REASON_L2_L2PMP_DENY:
        n_cov_pde_l2_l2pmp_deny_accerr++;
      PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY: begin
        n_cov_pde_l2_l1pmp_deny_accerr++;
        n_cov_pde_l2_l2pmp_deny_accerr++;
        n_cov_pde_l2_both_pmp_deny_accerr++;
      end
      default: ;
    endcase
  endfunction

  protected function void sample_actual_coverage(input ptw_src_actual_rsp_txn actual);
    sample_req_type(actual.req_type);
  endfunction

  protected function string compare_expected_pde_root(
    input ptw_src_expected_rsp_txn exp
  );
    string msg;
    string key;
    bit have_actual_root;
    ptw_src_pde_evt_txn pde;

    msg = "";
    if (!expected_has_pde_root(exp))
      return msg;

    key = key_string(exp.req_type, exp.id);

    if (exp.kind != PTW_SRC_EXP_ACCESS_FAULT)
      msg = {msg, " pde_direct_accerr_expected_non_access_fault;"};
    if (exp.fault_kind == PTW_SRC_FAULT_BUS_ERROR)
      msg = {msg, " pde_direct_accerr_misclassified_as_bus_error;"};
    if (exp.access_src != PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY)
      msg = {msg, $sformatf(" access_src exp=%s expected=PDE_CACHE_PMP_DENY;",
        ptw_src_access_src_name(exp.access_src))};
    if (!exp.pde_direct_accerr)
      msg = {msg, " pde_direct_accerr exp=0 expected=1;"};
    if (!pde_reason_is_l2_direct_accerr(exp.pde_reason))
      msg = {msg, $sformatf(" pde_reason exp=%s expected=L2_PMP_DENY;",
        ptw_src_pde_reason_name(exp.pde_reason))};

    have_actual_root = 1'b0;
    if (m_pde_direct_accerr_q.exists(key)) begin
      for (int i = 0; i < m_pde_direct_accerr_q[key].size(); i++) begin
        if (m_pde_direct_accerr_q[key][i].direct_accerr
            && (m_pde_direct_accerr_q[key][i].cycle == exp.cycle)) begin
          pde = m_pde_direct_accerr_q[key][i];
          have_actual_root = 1'b1;
          m_pde_direct_accerr_q[key].delete(i);
          break;
        end
      end
    end

    if (have_actual_root) begin
      if (pde.access_src != exp.access_src)
        msg = {msg, $sformatf(" access_src exp=%s act_pde=%s;",
          ptw_src_access_src_name(exp.access_src),
          ptw_src_access_src_name(pde.access_src))};
      if (pde.reason != exp.pde_reason)
        msg = {msg, $sformatf(" pde_reason exp=%s act_pde=%s;",
          ptw_src_pde_reason_name(exp.pde_reason),
          ptw_src_pde_reason_name(pde.reason))};
      if (pde.direct_accerr != exp.pde_direct_accerr)
        msg = {msg, $sformatf(" pde_direct_accerr exp=%0b act_pde=%0b;",
          exp.pde_direct_accerr, pde.direct_accerr)};
      if (pde.cached_l1pmpflg != exp.pde_l1pmpflg)
        msg = {msg, $sformatf(" pde_l1pmpflg exp=0x%0h act_pde=0x%0h;",
          exp.pde_l1pmpflg, pde.cached_l1pmpflg)};
      if (pde.cached_l2pmpflg != exp.pde_l2pmpflg)
        msg = {msg, $sformatf(" pde_l2pmpflg exp=0x%0h act_pde=0x%0h;",
          exp.pde_l2pmpflg, pde.cached_l2pmpflg)};
      if (msg == "")
        n_pde_root_matched++;
    end else begin
      pde_root_expected_s root;

      root.valid = 1'b1;
      root.req_type = exp.req_type;
      root.id = exp.id;
      root.vpn = exp.vpn;
      root.access_src = exp.access_src;
      root.pde_reason = exp.pde_reason;
      root.pde_l1pmpflg = exp.pde_l1pmpflg;
      root.pde_l2pmpflg = exp.pde_l2pmpflg;
      root.pde_direct_accerr = exp.pde_direct_accerr;
      root.cycle = exp.cycle;
      m_pde_root_pending_q[key].push_back(root);
    end

    return msg;
  endfunction

  protected function void note_pde_direct_accerr_event(
    input ptw_src_pde_evt_txn tr
  );
    string key;
    bit matched_pending_root;

    key = key_string(tr.req_type, tr.id);
    matched_pending_root = 1'b0;

    if (m_pde_root_pending_q.exists(key)) begin
      for (int i = 0; i < m_pde_root_pending_q[key].size(); i++) begin
        pde_root_expected_s root;
        string diff;

        root = m_pde_root_pending_q[key][i];
        if (root.cycle != tr.cycle)
          continue;

        diff = "";
        if (tr.access_src != root.access_src)
          diff = {diff, $sformatf(" access_src exp=%s act_pde=%s;",
            ptw_src_access_src_name(root.access_src),
            ptw_src_access_src_name(tr.access_src))};
        if (tr.reason != root.pde_reason)
          diff = {diff, $sformatf(" pde_reason exp=%s act_pde=%s;",
            ptw_src_pde_reason_name(root.pde_reason),
            ptw_src_pde_reason_name(tr.reason))};
        if (tr.direct_accerr != root.pde_direct_accerr)
          diff = {diff, $sformatf(" pde_direct_accerr exp=%0b act_pde=%0b;",
            root.pde_direct_accerr, tr.direct_accerr)};
        if (tr.cached_l1pmpflg != root.pde_l1pmpflg)
          diff = {diff, $sformatf(" pde_l1pmpflg exp=0x%0h act_pde=0x%0h;",
            root.pde_l1pmpflg, tr.cached_l1pmpflg)};
        if (tr.cached_l2pmpflg != root.pde_l2pmpflg)
          diff = {diff, $sformatf(" pde_l2pmpflg exp=0x%0h act_pde=0x%0h;",
            root.pde_l2pmpflg, tr.cached_l2pmpflg)};

        m_pde_root_pending_q[key].delete(i);
        matched_pending_root = 1'b1;
        if (diff == "") begin
          n_pde_root_matched++;
        end else begin
          n_mismatch++;
          n_field_mismatch++;
          `uvm_error(get_type_name(),
            $sformatf("PTW_SOURCE_MISMATCH key=%s diff={%s} exp_pde_root={access_src=%s pde_reason=%s direct=%0b l1pmp=0x%0h l2pmp=0x%0h} act_pde={%s}",
              key, diff, ptw_src_access_src_name(root.access_src),
              ptw_src_pde_reason_name(root.pde_reason), root.pde_direct_accerr,
              root.pde_l1pmpflg, root.pde_l2pmpflg, tr.convert2string()))
        end
        break;
      end
    end

    if (!matched_pending_root)
      m_pde_direct_accerr_q[key].push_back(tr);
  endfunction

  protected function void sample_pde_event_coverage(
    input ptw_src_pde_evt_txn tr
  );
    bit effective_m;
    string key;
    string cov_key;

    key = key_string(tr.req_type, tr.id);
    cov_key = cycle_key_string(tr.req_type, tr.id, tr.cycle);
    effective_m = 1'b0;
    if (m_ctx_by_key.exists(key)
        && (m_ctx_by_key[key].cycle <= tr.cycle)
        && (!m_last_visible_cycle.exists(key)
        || (m_ctx_by_key[key].cycle > m_last_visible_cycle[key]))
        && (!m_active_req.exists(key)
        || (m_ctx_by_key[key].cycle >= m_active_req[key].cycle)))
      effective_m = effective_machine_from_ctx(m_ctx_by_key[key]);

    if (tr.kind == PTW_SRC_PDE_EVT_UPDATE) begin
      if (tr.update_level == 2'b10)
        n_cov_pde_update_l1_pmpflg++;
      else if (tr.update_level == 2'b01)
        n_cov_pde_update_l2_pmpflg++;
      return;
    end

    if (!((tr.kind == PTW_SRC_PDE_EVT_HIT) || (tr.kind == PTW_SRC_PDE_EVT_MISS)))
      return;

    if (tr.l1_tag_hit && !tr.l2_tag_hit && tr.l1_perm_allow)
      n_cov_pde_l1_tag_hit_allow++;
    if (tr.reason == PTW_SRC_PDE_REASON_L1_PMP_DENY)
      n_cov_pde_l1_tag_hit_deny_miss++;
    if (tr.l2_tag_hit && tr.l2_perm_allow)
      n_cov_pde_l2_tag_hit_allow++;

    if (tr.direct_accerr
        && !m_pde_direct_accerr_cov_seen.exists(cov_key)) begin
      m_pde_direct_accerr_cov_seen[cov_key] = 1'b1;
      sample_pde_direct_accerr_type(tr.req_type);
      case (tr.reason)
        PTW_SRC_PDE_REASON_L2_L1PMP_DENY:
          n_cov_pde_l2_l1pmp_deny_accerr++;
        PTW_SRC_PDE_REASON_L2_L2PMP_DENY:
          n_cov_pde_l2_l2pmp_deny_accerr++;
        PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY: begin
          n_cov_pde_l2_l1pmp_deny_accerr++;
          n_cov_pde_l2_l2pmp_deny_accerr++;
          n_cov_pde_l2_both_pmp_deny_accerr++;
        end
        default: ;
      endcase
    end

    if (effective_m && ((tr.cached_l1pmpflg[3] === 1'b0)
        || (tr.cached_l2pmpflg[3] === 1'b0))
        && (tr.l1_tag_hit || tr.l2_tag_hit)
        && ((tr.l1_hit || tr.l2_hit) || tr.l1_perm_allow || tr.l2_perm_allow))
      n_cov_pde_mmode_bypass++;
    if (effective_m && ((tr.reason == PTW_SRC_PDE_REASON_L1_PMP_DENY)
        || pde_reason_is_l2_direct_accerr(tr.reason)))
      n_cov_pde_mmode_lock_deny++;
  endfunction

  protected function void open_no_extra_lsu_window(
    input ptw_src_req_type_e req_type,
    input logic [5:0]        id,
    input vpn_t              vpn,
    input int unsigned       start_cycle
  );
    string key;
    string credit_key;
    pde_direct_accerr_window_s win;

    key = key_string(req_type, id);
    credit_key = cycle_key_string(req_type, id, start_cycle);
    if (m_last_visible_cycle.exists(key)
        && (m_last_visible_cycle[key] >= start_cycle)) begin
      if (!m_no_extra_lsu_credit_key.exists(credit_key)) begin
        n_cov_pde_no_extra_lsu++;
        m_no_extra_lsu_credit_key[credit_key] = 1'b1;
      end
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_SB_NO_EXTRA_LSU key=%s closed_by_prior_visible_completion start_cycle=%0d visible_cycle=%0d",
          key, start_cycle, m_last_visible_cycle[key]),
        UVM_MEDIUM)
      return;
    end

    if (m_pde_no_extra_lsu_window.exists(key)
        && m_pde_no_extra_lsu_window[key].active)
      return;

    win.active = 1'b1;
    win.req_type = req_type;
    win.id = id;
    win.vpn = vpn;
    win.start_cycle = start_cycle;
    win.mem_req_seen_after_accerr = 0;
    win.violation_seen = 1'b0;
    win.ambiguous_seen = 1'b0;
    m_pde_no_extra_lsu_window[key] = win;
    n_no_extra_lsu_window_opened++;
  endfunction

  protected function void close_no_extra_lsu_window(
    input logic [2:0]  req_type,
    input logic [5:0]  id,
    input string       reason,
    input int unsigned visible_cycle
  );
    string key;
    string credit_key;
    pde_direct_accerr_window_s win;

    key = key_string(req_type, id);
    m_last_visible_cycle[key] = visible_cycle;

    if (!m_pde_no_extra_lsu_window.exists(key)
        || !m_pde_no_extra_lsu_window[key].active)
      return;

    win = m_pde_no_extra_lsu_window[key];
    credit_key = cycle_key_string(req_type, id, win.start_cycle);
    win.active = 1'b0;
    m_pde_no_extra_lsu_window[key] = win;

    if (win.violation_seen) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW_SOURCE_SB_NO_EXTRA_LSU_FAIL key=%s reason=%s mem_req_after_accerr=%0d start_cycle=%0d",
          key, reason, win.mem_req_seen_after_accerr, win.start_cycle))
    end else if (win.ambiguous_seen) begin
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_PROBE_GAP class=no_extra_lsu_ambiguous_close key=%s reason=%s mem_req_after_accerr=%0d start_cycle=%0d",
          key, reason, win.mem_req_seen_after_accerr, win.start_cycle))
    end else begin
      if (!m_no_extra_lsu_credit_key.exists(credit_key)) begin
        n_cov_pde_no_extra_lsu++;
        m_no_extra_lsu_credit_key[credit_key] = 1'b1;
      end
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_SB_NO_EXTRA_LSU key=%s status=pass reason=%s start_cycle=%0d",
          key, reason, win.start_cycle),
        UVM_MEDIUM)
    end
  endfunction

  protected function int unsigned count_active_no_extra_lsu_windows();
    int unsigned count;

    count = 0;
    foreach (m_pde_no_extra_lsu_window[key]) begin
      if (m_pde_no_extra_lsu_window[key].active)
        count++;
    end
    return count;
  endfunction

  protected function void check_mem_req_against_no_extra_lsu(
    input ptw_mem_txn tr
  );
    int unsigned active_windows;
    int unsigned active_reqs;

    active_windows = count_active_no_extra_lsu_windows();
    if (active_windows == 0)
      return;

    active_reqs = m_active_keys.num();
    foreach (m_pde_no_extra_lsu_window[key]) begin
      pde_direct_accerr_window_s win;

      if (!m_pde_no_extra_lsu_window[key].active)
        continue;

      win = m_pde_no_extra_lsu_window[key];
      win.mem_req_seen_after_accerr++;

      if ((active_windows == 1) && (active_reqs <= 1)) begin
        if (!win.violation_seen) begin
          n_no_extra_lsu_violation++;
          n_mismatch++;
          n_field_mismatch++;
        end
        win.violation_seen = 1'b1;
        `uvm_error(get_type_name(),
          $sformatf("PTW_SOURCE_SB_NO_EXTRA_LSU_FAIL key=%s class=strict_single_outstanding mem_req={%s} start_cycle=%0d active_reqs=%0d",
            key, tr.convert2string(), win.start_cycle, active_reqs))
      end else begin
        win.ambiguous_seen = 1'b1;
        n_probe_gap++;
        n_probe_gap_no_extra_lsu_ambiguous++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_SOURCE_PROBE_GAP class=no_extra_lsu_ambiguous key=%s mem_req={%s} active_windows=%0d active_reqs=%0d",
            key, tr.convert2string(), active_windows, active_reqs))
      end

      m_pde_no_extra_lsu_window[key] = win;
    end
  endfunction

  protected function void retire_active_key(input logic [2:0] req_type, input logic [5:0] id);
    string key;
    key = key_string(req_type, id);
    if (m_active_keys.exists(key)) begin
      m_active_keys.delete(key);
      m_active_req.delete(key);
    end
  endfunction

  protected function void note_visible_completion(
    input ptw_src_req_type_e req_type,
    input logic [5:0]        id,
    input int unsigned       cycle,
    input string             reason
  );
    string key;

    key = key_string(req_type, id);
    m_last_visible_cycle[key] = cycle;
    close_no_extra_lsu_window(req_type, id, reason, cycle);
    retire_active_key(req_type, id);
  endfunction

  protected task try_match_key(input string key);
    while ((m_expected_q.exists(key) && (m_expected_q[key].size() != 0))
           && (m_actual_q.exists(key) && (m_actual_q[key].size() != 0))) begin
      ptw_src_expected_rsp_txn exp;
      ptw_src_actual_rsp_txn actual;
      string diff;

      exp = m_expected_q[key].pop_front();
      actual = m_actual_q[key].pop_front();
      sample_expected_coverage(exp);
      sample_actual_coverage(actual);
      diff = compare_completion(exp, actual);
      if (diff == "") begin
        n_matched++;
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_MATCH key=%s %s", key, actual.convert2string()),
          UVM_MEDIUM)
      end else begin
        n_mismatch++;
        if (exp.kind != actual.kind)
          n_class_mismatch++;
        else
          n_field_mismatch++;
        `uvm_error(get_type_name(),
          $sformatf("PTW_SOURCE_MISMATCH key=%s diff={%s} exp={%s} act={%s}",
            key, diff, exp.convert2string(), actual.convert2string()))
      end
      retire_active_key(exp.req_type, exp.id);
    end
  endtask

  protected task try_match_drops();
    while ((m_drop_expected_q.size() != 0) && (m_drop_actual_q.size() != 0)) begin
      ptw_src_expected_rsp_txn exp;
      ptw_src_drop_txn actual;
      string diff;

      exp = m_drop_expected_q.pop_front();
      actual = m_drop_actual_q.pop_front();
      sample_expected_coverage(exp);
      diff = compare_drop(exp, actual);
      if (diff == "") begin
        n_matched++;
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_DROP_MATCH exp={%s} act={%s}",
            exp.convert2string(), actual.convert2string()),
          UVM_MEDIUM)
      end else begin
        n_mismatch++;
        n_drop_mismatch++;
        `uvm_error(get_type_name(),
          $sformatf("PTW_SOURCE_DROP_MISMATCH diff={%s} exp={%s} act={%s}",
            diff, exp.convert2string(), actual.convert2string()))
      end
      if (actual.has_key)
        note_visible_completion(actual.key.req_type, actual.key.id,
          actual.cycle, "actual_drop");
    end
  endtask

  protected task collect_expected();
    forever begin
      ptw_src_expected_rsp_txn tr;
      string key;

      af_expected.get(tr);
      n_expected++;
      if (expected_has_pde_root(tr)) begin
        sample_expected_pde_root_coverage_once(tr);
        open_no_extra_lsu_window(tr.req_type, tr.id, tr.vpn, tr.cycle);
      end
      if (tr.kind == PTW_SRC_EXP_DROP) begin
        n_drop_expected++;
        m_drop_expected_q.push_back(tr);
        try_match_drops();
      end else if (expected_has_key(tr)) begin
        key = key_string(tr.req_type, tr.id);
        m_expected_q[key].push_back(tr);
        try_match_key(key);
      end else begin
        n_probe_gap++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_SOURCE_PROBE_GAP expected_without_key %s", tr.convert2string()))
      end
    end
  endtask

  protected task collect_actual();
    forever begin
      ptw_src_actual_rsp_txn tr;
      string key;

      af_actual.get(tr);
      n_actual++;
      key = key_string(tr.req_type, tr.id);
      m_actual_q[key].push_back(tr);
      // The legal reuse window is closed by a visible DUT completion/drop, not
      // by the later scoreboard expected/actual match.  Retire here so a
      // ref-model/FIFO ordering lag after a page/access fault does not turn a
      // legal next request with the same {type,id} into illegal stimulus.
      note_visible_completion(tr.req_type, tr.id, tr.cycle, "actual_completion");
      try_match_key(key);
    end
  endtask

  protected task collect_req();
    forever begin
      ptw_src_req_accept_txn tr;
      string key;

      af_req.get(tr);
      n_accepted++;
      key = key_string(tr.req_type, tr.id);
      if (m_active_keys.exists(key)) begin
        n_illegal++;
        `uvm_error(get_type_name(),
          $sformatf("PTW_SOURCE_ILLEGAL_STIMULUS class=same_type_id_reuse key=%s old={%s} new={%s}",
            key, m_active_req[key].convert2string(), tr.convert2string()))
      end else begin
        m_active_keys[key] = 1'b1;
        m_active_req[key] = tr;
      end
    end
  endtask

  protected task collect_ctx();
    forever begin
      ptw_src_ctx_sample_txn tr;
      string key;

      af_ctx.get(tr);
      key = key_string(tr.req_type, tr.id);
      m_ctx_by_key[key] = tr;
    end
  endtask

  protected task collect_pde();
    forever begin
      ptw_src_pde_evt_txn tr;

      af_pde.get(tr);
      sample_pde_event_coverage(tr);
      if ((tr.kind == PTW_SRC_PDE_EVT_CLEAR) && (m_pde_no_extra_lsu_window.num() != 0)) begin
        foreach (m_pde_no_extra_lsu_window[key]) begin
          if (m_pde_no_extra_lsu_window[key].active) begin
            pde_direct_accerr_window_s win;
            win = m_pde_no_extra_lsu_window[key];
            win.active = 1'b0;
            win.ambiguous_seen = 1'b1;
            m_pde_no_extra_lsu_window[key] = win;
            n_probe_gap++;
            n_probe_gap_no_extra_lsu_ambiguous++;
            `uvm_warning(get_type_name(),
              $sformatf("PTW_SOURCE_PROBE_GAP class=no_extra_lsu_clear_before_completion key=%s start_cycle=%0d",
                key, win.start_cycle))
          end
        end
      end

      if (tr.direct_accerr) begin
        note_pde_direct_accerr_event(tr);
        open_no_extra_lsu_window(tr.req_type, tr.id, tr.vpn, tr.cycle);
      end
    end
  endtask

  protected task collect_drop();
    forever begin
      ptw_src_drop_txn tr;
      af_drop.get(tr);
      if (tr.pre_existing_exception_grant) begin
        n_cov_pre_existing_exception_grant++;
        if (tr.has_key)
          note_visible_completion(tr.key.req_type, tr.key.id,
            tr.cycle, "pre_existing_exception_grant");
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_AUXILIARY_DROP class=pre_existing_exception_grant ignored_for_drop_match act={%s}",
            tr.convert2string()),
          UVM_MEDIUM)
        continue;
      end
      n_drop_actual++;
      if (tr.has_key)
        note_visible_completion(tr.key.req_type, tr.key.id,
          tr.cycle, "actual_drop_seen");
      m_drop_actual_q.push_back(tr);
      try_match_drops();
    end
  endtask

  protected task collect_mem_req();
    forever begin
      ptw_mem_txn tr;
      af_mem_req.get(tr);
      n_mem_req++;
      check_mem_req_against_no_extra_lsu(tr);
    end
  endtask

  protected task collect_mem_rsp();
    forever begin
      ptw_mem_txn tr;
      af_mem_rsp.get(tr);
      n_mem_rsp++;
    end
  endtask

  protected task collect_mem_drop();
    forever begin
      ptw_mem_txn tr;
      af_mem_drop.get(tr);
      n_mem_drop++;
    end
  endtask

  protected function int unsigned count_pending_expected();
    int unsigned count;
    count = 0;
    foreach (m_expected_q[key])
      count += m_expected_q[key].size();
    count += m_drop_expected_q.size();
    return count;
  endfunction

  protected function int unsigned count_pending_actual();
    int unsigned count;
    count = 0;
    foreach (m_actual_q[key])
      count += m_actual_q[key].size();
    count += m_drop_actual_q.size();
    return count;
  endfunction

  protected function int unsigned count_pending_pde_root();
    int unsigned count;

    count = 0;
    foreach (m_pde_root_pending_q[key])
      count += m_pde_root_pending_q[key].size();
    return count;
  endfunction

  protected function int unsigned oldest_pending_age();
    int unsigned oldest_age;
    int unsigned age;
    int unsigned now_cycle;
    bit found;

    oldest_age = 0;
    now_cycle = 0;
    found = 1'b0;
    foreach (m_expected_q[key]) begin
      for (int i = 0; i < m_expected_q[key].size(); i++) begin
        if (m_expected_q[key][i].cycle > now_cycle)
          now_cycle = m_expected_q[key][i].cycle;
      end
    end
    foreach (m_actual_q[key]) begin
      for (int i = 0; i < m_actual_q[key].size(); i++) begin
        if (m_actual_q[key][i].cycle > now_cycle)
          now_cycle = m_actual_q[key][i].cycle;
      end
    end
    foreach (m_active_keys[key]) begin
      if (m_active_req[key].cycle > now_cycle)
        now_cycle = m_active_req[key].cycle;
    end

    foreach (m_expected_q[key]) begin
      for (int i = 0; i < m_expected_q[key].size(); i++) begin
        age = (now_cycle >= m_expected_q[key][i].cycle)
            ? (now_cycle - m_expected_q[key][i].cycle) : 0;
        if (!found || (age > oldest_age)) begin
          oldest_age = age;
          found = 1'b1;
        end
      end
    end
    foreach (m_actual_q[key]) begin
      for (int i = 0; i < m_actual_q[key].size(); i++) begin
        age = (now_cycle >= m_actual_q[key][i].cycle)
            ? (now_cycle - m_actual_q[key][i].cycle) : 0;
        if (!found || (age > oldest_age)) begin
          oldest_age = age;
          found = 1'b1;
        end
      end
    end
    foreach (m_active_keys[key]) begin
      age = (now_cycle >= m_active_req[key].cycle)
          ? (now_cycle - m_active_req[key].cycle) : 0;
      if (!found || (age > oldest_age)) begin
        oldest_age = age;
        found = 1'b1;
      end
    end
    return oldest_age;
  endfunction

  virtual function void report_phase(uvm_phase phase);
    n_pending = 0;

    foreach (m_pde_root_pending_q[key]) begin
      for (int i = 0; i < m_pde_root_pending_q[key].size(); i++) begin
        n_probe_gap++;
        n_probe_gap_pde_root_missing++;
        `uvm_warning(get_type_name(),
          $sformatf({"PTW_SOURCE_PROBE_GAP class=pde_root_event_missing key=%s ",
                     "access_src=%s pde_reason=%s pde_direct_accerr=%0b cycle=%0d"},
            key, ptw_src_access_src_name(m_pde_root_pending_q[key][i].access_src),
            ptw_src_pde_reason_name(m_pde_root_pending_q[key][i].pde_reason),
            m_pde_root_pending_q[key][i].pde_direct_accerr,
            m_pde_root_pending_q[key][i].cycle))
      end
    end

    foreach (m_pde_no_extra_lsu_window[key]) begin
      if (m_pde_no_extra_lsu_window[key].active) begin
        n_pending++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_SOURCE_PENDING_NO_EXTRA_LSU key=%s start_cycle=%0d mem_req_after_accerr=%0d violation=%0b ambiguous=%0b",
            key, m_pde_no_extra_lsu_window[key].start_cycle,
            m_pde_no_extra_lsu_window[key].mem_req_seen_after_accerr,
            m_pde_no_extra_lsu_window[key].violation_seen,
            m_pde_no_extra_lsu_window[key].ambiguous_seen))
      end
    end

    n_pending_expected = count_pending_expected();
    n_pending_actual = count_pending_actual();
    n_pending = n_pending + n_pending_expected + n_pending_actual
              + m_active_keys.num() + count_pending_pde_root();
    n_pending_oldest_age = oldest_pending_age();

    foreach (m_expected_q[key]) begin
      for (int i = 0; i < m_expected_q[key].size(); i++) begin
        `uvm_warning(get_type_name(),
          $sformatf("PTW_SOURCE_PENDING_EXPECTED key=%s %s",
            key, m_expected_q[key][i].convert2string()))
      end
    end
    foreach (m_actual_q[key]) begin
      for (int i = 0; i < m_actual_q[key].size(); i++) begin
        `uvm_warning(get_type_name(),
          $sformatf("PTW_SOURCE_PENDING_ACTUAL key=%s %s",
            key, m_actual_q[key][i].convert2string()))
      end
    end
    foreach (m_active_keys[key]) begin
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_PENDING_ACTIVE key=%s %s",
          key, m_active_req[key].convert2string()))
    end

    `uvm_info(get_type_name(),
      $sformatf({"PTW_SOURCE_SB_SUMMARY stage=7 accepted=%0d expected=%0d actual=%0d ",
                 "drop_expected=%0d drop_actual=%0d matched=%0d mismatch=%0d ",
                 "pending=%0d pending_expected=%0d pending_actual=%0d active=%0d ",
                 "illegal=%0d class_mismatch=%0d field_mismatch=%0d ",
                 "drop_mismatch=%0d probe_gap=%0d mem_req=%0d mem_rsp=%0d ",
                 "mem_drop=%0d pending_oldest_age=%0d provisional=0"},
        n_accepted, n_expected, n_actual, n_drop_expected, n_drop_actual,
        n_matched, n_mismatch, n_pending, n_pending_expected,
        n_pending_actual, m_active_keys.num(), n_illegal,
        n_class_mismatch, n_field_mismatch, n_drop_mismatch, n_probe_gap,
        n_mem_req, n_mem_rsp, n_mem_drop, n_pending_oldest_age),
      UVM_NONE)

    `uvm_info(get_type_name(),
      $sformatf({"PTW_SOURCE_SB_FIELD_COVERAGE stage=7 refill=%0d page_fault=%0d ",
                 "access_fault=%0d drop=%0d type_fetch=%0d type_load=%0d ",
                 "type_store=%0d type_pfu=%0d pgs_1g=%0d pgs_2m=%0d pgs_4k=%0d ",
                 "global=%0d fault_page=%0d fault_access=%0d fault_bus_error=%0d ",
                 "drop_reset=%0d drop_abort=%0d drop_late=%0d drop_abort_bus_error=%0d ",
                 "pre_existing_exception_grant=%0d ",
                 "target_l2=%0d target_l1i=%0d target_l1d=%0d target_pfu=%0d"},
        n_cov_refill, n_cov_page_fault, n_cov_access_fault, n_cov_drop,
        n_cov_type_fetch, n_cov_type_load, n_cov_type_store, n_cov_type_pfu,
        n_cov_pgs_1g, n_cov_pgs_2m, n_cov_pgs_4k, n_cov_global,
        n_cov_fault_page, n_cov_fault_access, n_cov_fault_bus_error,
        n_cov_drop_reset, n_cov_drop_abort, n_cov_drop_late,
        n_cov_drop_abort_bus_error, n_cov_pre_existing_exception_grant,
        n_cov_target_l2, n_cov_target_l1i, n_cov_target_l1d,
        n_cov_target_pfu),
      UVM_NONE)

    `uvm_info(get_type_name(),
      $sformatf({"PTW_SOURCE_SB_PDE_PMP_COVERAGE stage=pde_pmpflg ",
                 "l1_allow=%0d l1_deny_miss=%0d l2_allow=%0d ",
                 "l2_l1deny=%0d l2_l2deny=%0d l2_bothdeny=%0d ",
                 "update_l1=%0d update_l2=%0d ",
                 "direct_accerr_load=%0d direct_accerr_store=%0d ",
                 "direct_accerr_fetch=%0d direct_accerr_pfu=%0d ",
                 "mmode_bypass=%0d mmode_lock_deny=%0d no_extra_lsu=%0d ",
                 "no_extra_lsu_window=%0d no_extra_lsu_violation=%0d ",
                 "probe_gap_no_extra_lsu_ambiguous=%0d ",
                 "pde_root_matched=%0d probe_gap_pde_root_missing=%0d"},
        n_cov_pde_l1_tag_hit_allow,
        n_cov_pde_l1_tag_hit_deny_miss,
        n_cov_pde_l2_tag_hit_allow,
        n_cov_pde_l2_l1pmp_deny_accerr,
        n_cov_pde_l2_l2pmp_deny_accerr,
        n_cov_pde_l2_both_pmp_deny_accerr,
        n_cov_pde_update_l1_pmpflg,
        n_cov_pde_update_l2_pmpflg,
        n_cov_pde_direct_accerr_type_load,
        n_cov_pde_direct_accerr_type_store,
        n_cov_pde_direct_accerr_type_fetch,
        n_cov_pde_direct_accerr_type_pfu,
        n_cov_pde_mmode_bypass,
        n_cov_pde_mmode_lock_deny,
        n_cov_pde_no_extra_lsu,
        n_no_extra_lsu_window_opened,
        n_no_extra_lsu_violation,
        n_probe_gap_no_extra_lsu_ambiguous,
        n_pde_root_matched,
        n_probe_gap_pde_root_missing),
      UVM_NONE)

    `uvm_info(get_type_name(),
      "PTW_SOURCE_REQ_SUMMARY stage=7 requirement=field_function_coverage status=reported consumer_only_does_not_close_source=1 partial_evidence_must_be_tagged=1 provisional=0",
      UVM_NONE)

    if ((n_mismatch == 0) && (n_pending == 0) && (n_illegal == 0)) begin
      `uvm_info(get_type_name(),
        "PTW_SOURCE_CLOSURE component=source_sb stage=7 status=closed mismatch=0 pending=0 illegal=0 provisional=0",
        UVM_NONE)
    end else begin
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_CLOSURE component=source_sb stage=7 status=open mismatch=%0d pending=%0d illegal=%0d probe_gap=%0d pending_oldest_age=%0d provisional=0",
          n_mismatch, n_pending, n_illegal, n_probe_gap, n_pending_oldest_age))
    end
  endfunction

endclass : ptw_source_sb

`endif // PTW_SOURCE_SB_SVH
