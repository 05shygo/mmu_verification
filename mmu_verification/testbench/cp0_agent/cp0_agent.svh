// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_agent.svh
// Phase 3: CP0 agent — builds and connects sequencer/driver/monitor/cg
// =============================================================================
`ifndef CP0_AGENT_SVH
`define CP0_AGENT_SVH

class cp0_agent extends uvm_agent;

  `uvm_component_utils_begin(cp0_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  // Inherited from uvm_agent: uvm_active_passive_enum is_active = UVM_ACTIVE
  cp0_sequencer  m_sequencer;
  cp0_driver     m_driver;
  cp0_monitor    m_monitor;
  cp0_cg_wrapper m_cg;

  virtual cp0_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Retrieve virtual interface (set globally by tb_top with null, "*")
    if (!uvm_config_db #(virtual cp0_if)::get(this, "", "CP0_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get CP0_VIF from config_db")
    // Always create monitor and coverage wrapper
    m_monitor = cp0_monitor::type_id::create("m_monitor", this);
    m_cg      = cp0_cg_wrapper::type_id::create("m_cg",      this);
    // Only create driver + sequencer when active
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = cp0_sequencer::type_id::create("m_sequencer", this);
      m_driver    = cp0_driver::type_id::create("m_driver",    this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    // Initialise covergroup wrapper with virtual interface
    m_cg.set_vif(vif);
  endfunction

endclass : cp0_agent

`endif // CP0_AGENT_SVH
