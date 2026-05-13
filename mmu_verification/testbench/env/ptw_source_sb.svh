// =============================================================================
// PTW source-side scoreboard
//
// Stage 4 scope:
//   - Match source ref-model expected transactions to source monitor actuals by
//     {type,id}; compare final class and fields without fixed latency checks.
//   - Detect duplicate {type,id} request reuse before completion/drop.
//   - Match drop/no-output expectations.
//   - Classify mismatches for field/class/drop/pending/illegal/probe-gap.
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
      "PTW_SOURCE_CLOSURE component=source_sb stage=4 status=created provisional=0",
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
    if (exp.fault_kind != actual.fault_kind)
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
          $sformatf("PTW_SOURCE_ILLEGAL_REUSE key=%s old={%s} new={%s}",
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

  virtual function void report_phase(uvm_phase phase);
    n_pending_expected = count_pending_expected();
    n_pending_actual = count_pending_actual();
    n_pending = n_pending_expected + n_pending_actual + m_active_keys.num();

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
      $sformatf({"PTW_SOURCE_SB_SUMMARY stage=4 accepted=%0d expected=%0d actual=%0d ",
                 "drop_expected=%0d drop_actual=%0d matched=%0d mismatch=%0d ",
                 "pending=%0d pending_expected=%0d pending_actual=%0d active=%0d ",
                 "illegal=%0d class_mismatch=%0d field_mismatch=%0d ",
                 "drop_mismatch=%0d probe_gap=%0d mem_req=%0d mem_rsp=%0d ",
                 "mem_drop=%0d provisional=0"},
        n_accepted, n_expected, n_actual, n_drop_expected, n_drop_actual,
        n_matched, n_mismatch, n_pending, n_pending_expected,
        n_pending_actual, m_active_keys.num(), n_illegal,
        n_class_mismatch, n_field_mismatch, n_drop_mismatch, n_probe_gap,
        n_mem_req, n_mem_rsp, n_mem_drop),
      UVM_NONE)

    if ((n_mismatch == 0) && (n_pending == 0) && (n_illegal == 0)) begin
      `uvm_info(get_type_name(),
        "PTW_SOURCE_CLOSURE component=source_sb stage=4 status=closed mismatch=0 pending=0 illegal=0 provisional=0",
        UVM_NONE)
    end else begin
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_CLOSURE component=source_sb stage=4 status=open mismatch=%0d pending=%0d illegal=%0d probe_gap=%0d provisional=0",
          n_mismatch, n_pending, n_illegal, n_probe_gap))
    end
  endfunction

endclass : ptw_source_sb

`endif // PTW_SOURCE_SB_SVH
