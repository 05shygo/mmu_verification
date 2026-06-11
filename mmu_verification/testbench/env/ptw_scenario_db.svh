// =============================================================================
// PTW scenario database / event logger
//
// Stage 3 scope:
//   - Collect source monitor events and PTW memory monitor transactions.
//   - Provide a lightweight scenario registration hook for directed tests.
//   - Print a provisional event summary. This is not a scoreboard and does not
//     close P0/P1 requirements.
// =============================================================================
`ifndef PTW_SCENARIO_DB_SVH
`define PTW_SCENARIO_DB_SVH

class ptw_scenario_db extends uvm_component;

  `uvm_component_utils(ptw_scenario_db)

  uvm_tlm_analysis_fifo #(ptw_src_req_accept_txn) af_req_accept;
  uvm_tlm_analysis_fifo #(ptw_src_actual_rsp_txn) af_actual_rsp;
  uvm_tlm_analysis_fifo #(ptw_src_abort_txn)      af_abort;
  uvm_tlm_analysis_fifo #(ptw_src_ctx_sample_txn) af_ctx;
  uvm_tlm_analysis_fifo #(ptw_src_level_evt_txn)  af_level;
  uvm_tlm_analysis_fifo #(ptw_src_pde_evt_txn)    af_pde;
  uvm_tlm_analysis_fifo #(ptw_src_drop_txn)       af_drop;
  uvm_tlm_analysis_fifo #(ptw_src_mem_evt_txn)    af_mem_evt;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_drop;

  string       m_active_scenario_id;
  string       m_active_requirement_ids[$];
  int unsigned m_registered_scenarios;
  int unsigned m_req_accept_count;
  int unsigned m_actual_rsp_count;
  int unsigned m_refill_count;
  int unsigned m_page_fault_count;
  int unsigned m_access_fault_count;
  int unsigned m_abort_count;
  int unsigned m_ctx_count;
  int unsigned m_level_count;
  int unsigned m_pde_count;
  int unsigned m_drop_count;
  int unsigned m_mem_req_count;
  int unsigned m_mem_rsp_count;
  int unsigned m_mem_bus_error_count;
  int unsigned m_mem_drop_count;
  int unsigned m_src_mem_evt_count;
  int unsigned m_src_mem_key_valid_count;
  int unsigned m_src_mem_key_gap_count;
  int unsigned m_src_mem_req_count;
  int unsigned m_src_mem_rsp_count;
  int unsigned m_src_mem_drop_count;
  int unsigned m_src_mem_ooo_rsp_count;
  int unsigned m_src_mem_grant_wait_count;
  int unsigned m_src_mem_max_grant_wait;
  int unsigned m_src_mem_abort_drain_rsp_count;
  int unsigned m_src_mem_invalid_rsp_id_count;
  int unsigned m_src_mem_rsp_without_pending_count;
  int unsigned m_src_mem_duplicate_id_count;
  bit [8:0]    m_src_mem_req_id_mask;
  bit [8:0]    m_src_mem_rsp_id_mask;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_active_scenario_id = "unregistered";
    m_registered_scenarios = 0;
    m_req_accept_count = 0;
    m_actual_rsp_count = 0;
    m_refill_count = 0;
    m_page_fault_count = 0;
    m_access_fault_count = 0;
    m_abort_count = 0;
    m_ctx_count = 0;
    m_level_count = 0;
    m_pde_count = 0;
    m_drop_count = 0;
    m_mem_req_count = 0;
    m_mem_rsp_count = 0;
    m_mem_bus_error_count = 0;
    m_mem_drop_count = 0;
    m_src_mem_evt_count = 0;
    m_src_mem_key_valid_count = 0;
    m_src_mem_key_gap_count = 0;
    m_src_mem_req_count = 0;
    m_src_mem_rsp_count = 0;
    m_src_mem_drop_count = 0;
    m_src_mem_ooo_rsp_count = 0;
    m_src_mem_grant_wait_count = 0;
    m_src_mem_max_grant_wait = 0;
    m_src_mem_abort_drain_rsp_count = 0;
    m_src_mem_invalid_rsp_id_count = 0;
    m_src_mem_rsp_without_pending_count = 0;
    m_src_mem_duplicate_id_count = 0;
    m_src_mem_req_id_mask = '0;
    m_src_mem_rsp_id_mask = '0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    af_req_accept  = new("af_req_accept",  this);
    af_actual_rsp  = new("af_actual_rsp",  this);
    af_abort       = new("af_abort",       this);
    af_ctx         = new("af_ctx",         this);
    af_level       = new("af_level",       this);
    af_pde         = new("af_pde",         this);
    af_drop        = new("af_drop",        this);
    af_mem_evt     = new("af_mem_evt",     this);
    af_ptw_mem_req = new("af_ptw_mem_req", this);
    af_ptw_mem_rsp = new("af_ptw_mem_rsp", this);
    af_ptw_mem_drop = new("af_ptw_mem_drop", this);

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=scenario_db stage=3 status=created provisional=1",
      UVM_LOW)
  endfunction

  virtual function void register_scenario(
    string scenario_id,
    string requirement_ids = ""
  );
    m_active_scenario_id = scenario_id;
    m_active_requirement_ids.delete();
    if (requirement_ids != "")
      m_active_requirement_ids.push_back(requirement_ids);
    m_registered_scenarios++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_SCENARIO_REGISTER scenario_id=%s requirement_ids=\"%s\"",
        scenario_id, requirement_ids),
      UVM_MEDIUM)
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      collect_req_accept();
      collect_actual_rsp();
      collect_abort();
      collect_ctx();
      collect_level();
      collect_pde();
      collect_drop();
      collect_src_mem_evt();
      collect_mem_req();
      collect_mem_rsp();
      collect_mem_drop();
    join_none
  endtask

  protected task collect_req_accept();
    forever begin
      ptw_src_req_accept_txn tr;
      af_req_accept.get(tr);
      m_req_accept_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=req_accept %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_actual_rsp();
    forever begin
      ptw_src_actual_rsp_txn tr;
      af_actual_rsp.get(tr);
      m_actual_rsp_count++;
      if (tr.kind == PTW_SRC_EXP_REFILL)
        m_refill_count++;
      else if (tr.kind == PTW_SRC_EXP_PAGE_FAULT)
        m_page_fault_count++;
      else if (tr.kind == PTW_SRC_EXP_ACCESS_FAULT)
        m_access_fault_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=actual_rsp %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_abort();
    forever begin
      ptw_src_abort_txn tr;
      af_abort.get(tr);
      m_abort_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=abort %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_ctx();
    forever begin
      ptw_src_ctx_sample_txn tr;
      af_ctx.get(tr);
      m_ctx_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=ctx %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_level();
    forever begin
      ptw_src_level_evt_txn tr;
      af_level.get(tr);
      m_level_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=level %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_pde();
    forever begin
      ptw_src_pde_evt_txn tr;
      af_pde.get(tr);
      m_pde_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=pde %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_drop();
    forever begin
      ptw_src_drop_txn tr;
      af_drop.get(tr);
      m_drop_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=drop %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_mem_req();
    forever begin
      ptw_mem_txn tr;
      af_ptw_mem_req.get(tr);
      m_mem_req_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=mem_req %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_src_mem_evt();
    forever begin
      ptw_src_mem_evt_txn tr;
      af_mem_evt.get(tr);
      m_src_mem_evt_count++;
      if (tr.source_key_valid)
        m_src_mem_key_valid_count++;
      else if (tr.req_fire || (tr.rsp_fire && !tr.invalid_rsp_id))
        m_src_mem_key_gap_count++;
      if (tr.req_fire) begin
        m_src_mem_req_count++;
        if (tr.req_id <= 4'd8)
          m_src_mem_req_id_mask[tr.req_id] = 1'b1;
        if (tr.grant_wait_cycles != 0) begin
          m_src_mem_grant_wait_count++;
          if (tr.grant_wait_cycles > m_src_mem_max_grant_wait)
            m_src_mem_max_grant_wait = tr.grant_wait_cycles;
        end
        if (tr.duplicate_id_error)
          m_src_mem_duplicate_id_count++;
      end
      if (tr.rsp_fire) begin
        m_src_mem_rsp_count++;
        if (!tr.invalid_rsp_id && (tr.rsp_id <= 4'd8))
          m_src_mem_rsp_id_mask[tr.rsp_id] = 1'b1;
        if (tr.ooo)
          m_src_mem_ooo_rsp_count++;
        if (tr.abort_drain)
          m_src_mem_abort_drain_rsp_count++;
        if (tr.invalid_rsp_id)
          m_src_mem_invalid_rsp_id_count++;
        if (tr.rsp_without_pending)
          m_src_mem_rsp_without_pending_count++;
      end
      if (tr.drop_fire)
        m_src_mem_drop_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=src_mem_evt %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_mem_rsp();
    forever begin
      ptw_mem_txn tr;
      af_ptw_mem_rsp.get(tr);
      m_mem_rsp_count++;
      if (tr.bus_error)
        m_mem_bus_error_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=mem_rsp %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  protected task collect_mem_drop();
    forever begin
      ptw_mem_txn tr;
      af_ptw_mem_drop.get(tr);
      m_mem_drop_count++;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SCENARIO_EVENT scenario_id=%s kind=mem_drop %s",
          m_active_scenario_id, tr.convert2string()),
        UVM_HIGH)
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf({"PTW_SCENARIO_DB_SUMMARY stage=3 registered=%0d req_accept=%0d ",
                 "actual_rsp=%0d refill=%0d page_fault=%0d access_fault=%0d ",
                 "abort=%0d ctx=%0d level=%0d pde=%0d drop=%0d ",
                 "mem_req=%0d mem_rsp=%0d mem_bus_error=%0d mem_drop=%0d ",
                 "src_mem_evt=%0d src_mem_key_valid=%0d src_mem_key_gap=%0d provisional=1"},
        m_registered_scenarios, m_req_accept_count, m_actual_rsp_count,
        m_refill_count, m_page_fault_count, m_access_fault_count,
        m_abort_count, m_ctx_count, m_level_count, m_pde_count, m_drop_count,
        m_mem_req_count, m_mem_rsp_count, m_mem_bus_error_count,
        m_mem_drop_count, m_src_mem_evt_count, m_src_mem_key_valid_count,
        m_src_mem_key_gap_count),
      UVM_NONE)
    `uvm_info(get_type_name(),
      $sformatf({"PTW_SCENARIO_DB_LSU_ID_SUMMARY stage=7 scenario_id=%s ",
                 "src_mem_req=%0d src_mem_rsp=%0d src_mem_drop=%0d ",
                 "req_id_mask=0x%03h rsp_id_mask=0x%03h ooo_rsp=%0d ",
                 "grant_wait=%0d max_grant_wait=%0d abort_drain_rsp=%0d ",
                 "invalid_rsp_id=%0d rsp_without_pending=%0d duplicate_id=%0d provisional=1"},
        m_active_scenario_id, m_src_mem_req_count, m_src_mem_rsp_count,
        m_src_mem_drop_count, m_src_mem_req_id_mask, m_src_mem_rsp_id_mask,
        m_src_mem_ooo_rsp_count, m_src_mem_grant_wait_count,
        m_src_mem_max_grant_wait, m_src_mem_abort_drain_rsp_count,
        m_src_mem_invalid_rsp_id_count, m_src_mem_rsp_without_pending_count,
        m_src_mem_duplicate_id_count),
      UVM_NONE)
  endfunction

endclass : ptw_scenario_db

`endif // PTW_SCENARIO_DB_SVH
