// =============================================================================
// PTW source-side monitor skeleton
//
// Stage 1 scope only: declare stable analysis port names and print creation /
// closure placeholders. Functional probe sampling starts in a later stage.
// =============================================================================
`ifndef PTW_SOURCE_MONITOR_SVH
`define PTW_SOURCE_MONITOR_SVH

class ptw_source_monitor extends uvm_monitor;

  `uvm_component_utils(ptw_source_monitor)

  mmu_top_cfg m_cfg;
  virtual mmu_dut_probes_if v_probe;

  uvm_analysis_port #(ptw_src_req_accept_txn) ap_req_accept;
  uvm_analysis_port #(ptw_src_actual_rsp_txn) ap_actual_rsp;
  uvm_analysis_port #(ptw_src_abort_txn)      ap_abort;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    ap_req_accept = new("ap_req_accept", this);
    ap_actual_rsp = new("ap_actual_rsp", this);
    ap_abort      = new("ap_abort",      this);

    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(
          this, "", "MMU_DUT_PROBES_VIF", v_probe)) begin
      `uvm_info(get_type_name(),
        "PTW_SOURCE_CLOSURE component=monitor stage=1 status=created probe=missing provisional=1",
        UVM_LOW)
    end else begin
      `uvm_info(get_type_name(),
        "PTW_SOURCE_CLOSURE component=monitor stage=1 status=created probe=available provisional=1",
        UVM_LOW)
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=monitor stage=1 req_accept=0 actual_rsp=0 abort=0 provisional=1",
      UVM_NONE)
  endfunction

endclass : ptw_source_monitor

`endif // PTW_SOURCE_MONITOR_SVH
