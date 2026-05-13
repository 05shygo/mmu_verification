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
                 "mem_req=%0d mem_rsp=%0d mem_bus_error=%0d mem_drop=%0d provisional=1"},
        m_registered_scenarios, m_req_accept_count, m_actual_rsp_count,
        m_refill_count, m_page_fault_count, m_access_fault_count,
        m_abort_count, m_ctx_count, m_level_count, m_pde_count, m_drop_count,
        m_mem_req_count, m_mem_rsp_count, m_mem_bus_error_count,
        m_mem_drop_count),
      UVM_NONE)
  endfunction

endclass : ptw_scenario_db

`endif // PTW_SCENARIO_DB_SVH
