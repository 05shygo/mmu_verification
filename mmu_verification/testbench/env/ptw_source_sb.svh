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
  uvm_tlm_analysis_fifo #(ptw_src_drop_txn)         af_drop;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_drop;

  ptw_src_expected_rsp_txn m_expected_q[string][$];
  ptw_src_actual_rsp_txn   m_actual_q[string][$];
  ptw_src_expected_rsp_txn m_drop_expected_q[$];
  ptw_src_drop_txn         m_drop_actual_q[$];
  bit                      m_active_keys[string];
  ptw_src_req_accept_txn   m_active_req[string];

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
  int unsigned n_pending_oldest_age;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    af_expected = new("af_expected", this);
    af_actual   = new("af_actual",   this);
    af_req      = new("af_req",      this);
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
      collect_drop();
      collect_mem_req();
      collect_mem_rsp();
      collect_mem_drop();
    join_none
  endtask

  protected function string key_string(input logic [2:0] req_type, input logic [5:0] id);
    return $sformatf("%0h:%0h", req_type, id);
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

  protected function void sample_actual_coverage(input ptw_src_actual_rsp_txn actual);
    sample_req_type(actual.req_type);
  endfunction

  protected function void retire_active_key(input logic [2:0] req_type, input logic [5:0] id);
    string key;
    key = key_string(req_type, id);
    if (m_active_keys.exists(key)) begin
      m_active_keys.delete(key);
      m_active_req.delete(key);
    end
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
        retire_active_key(actual.key.req_type, actual.key.id);
    end
  endtask

  protected task collect_expected();
    forever begin
      ptw_src_expected_rsp_txn tr;
      string key;

      af_expected.get(tr);
      n_expected++;
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

  protected task collect_drop();
    forever begin
      ptw_src_drop_txn tr;
      af_drop.get(tr);
      if (tr.pre_existing_exception_grant) begin
        n_cov_pre_existing_exception_grant++;
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_AUXILIARY_DROP class=pre_existing_exception_grant ignored_for_drop_match act={%s}",
            tr.convert2string()),
          UVM_MEDIUM)
        continue;
      end
      n_drop_actual++;
      m_drop_actual_q.push_back(tr);
      try_match_drops();
    end
  endtask

  protected task collect_mem_req();
    forever begin
      ptw_mem_txn tr;
      af_mem_req.get(tr);
      n_mem_req++;
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
    n_pending_expected = count_pending_expected();
    n_pending_actual = count_pending_actual();
    n_pending = n_pending_expected + n_pending_actual + m_active_keys.num();
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
