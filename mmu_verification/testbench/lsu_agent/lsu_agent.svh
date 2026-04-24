// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_agent.svh
// Phase 3 (Engineer B): LSU agent — builds and connects sequencer/driver/monitor/cg
// =============================================================================
`ifndef LSU_AGENT_SVH
`define LSU_AGENT_SVH

class lsu_agent extends uvm_agent;

  `uvm_component_utils_begin(lsu_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  lsu_sequencer  m_sequencer;
  lsu_driver     m_driver;
  lsu_monitor    m_monitor;
  lsu_cg_wrapper m_cg;

  virtual lsu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual lsu_if)::get(this, "", "LSU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get LSU_VIF from config_db")
    // Always create monitor and coverage wrapper
    m_monitor = lsu_monitor::type_id::create("m_monitor", this);
    m_cg      = lsu_cg_wrapper::type_id::create("m_cg",   this);
    // Only create driver + sequencer when active
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = lsu_sequencer::type_id::create("m_sequencer", this);
      m_driver    = lsu_driver::type_id::create("m_driver",    this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    // Initialise covergroup wrapper with virtual interface
    m_cg.set_vif(vif);
  endfunction

endclass : lsu_agent

`endif // LSU_AGENT_SVH
