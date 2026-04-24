// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_agent.svh
// Phase 3 (Engineer B): IFU agent — builds and connects sequencer/driver/monitor/cg
// =============================================================================
`ifndef IFU_AGENT_SVH
`define IFU_AGENT_SVH

class ifu_agent extends uvm_agent;

  `uvm_component_utils_begin(ifu_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  ifu_sequencer  m_sequencer;
  ifu_driver     m_driver;
  ifu_monitor    m_monitor;
  ifu_cg_wrapper m_cg;

  virtual ifu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ifu_if)::get(this, "", "IFU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get IFU_VIF from config_db")
    // Always create monitor and coverage wrapper
    m_monitor = ifu_monitor::type_id::create("m_monitor", this);
    m_cg      = ifu_cg_wrapper::type_id::create("m_cg",   this);
    // Only create driver + sequencer when active
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = ifu_sequencer::type_id::create("m_sequencer", this);
      m_driver    = ifu_driver::type_id::create("m_driver",    this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    // Initialise covergroup wrapper with virtual interface
    m_cg.set_vif(vif);
  endfunction

endclass : ifu_agent

`endif // IFU_AGENT_SVH
