// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_agent.svh
// Phase 5 (Engineer A): Misc agent — builds and connects
//   sequencer / driver / monitor / coverage wrapper
//
// Active mode (UVM_ACTIVE, default):
//   m_sequencer + m_driver created; drives rtu_flush / smp_disable / hpcp_cnt_en
//
// Passive mode (UVM_PASSIVE):
//   only m_monitor + m_cg created; used when misc signals are driven externally
// =============================================================================
`ifndef MISC_AGENT_SVH
`define MISC_AGENT_SVH

class misc_agent extends uvm_agent;

  `uvm_component_utils_begin(misc_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  misc_sequencer  m_sequencer;
  misc_driver     m_driver;
  misc_monitor    m_monitor;
  misc_cg_wrapper m_cg;

  virtual misc_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual misc_if)::get(this, "", "MISC_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get MISC_VIF from config_db")
    // Monitor and coverage always created (ACTIVE or PASSIVE)
    m_monitor = misc_monitor::type_id::create("m_monitor", this);
    m_cg      = misc_cg_wrapper::type_id::create("m_cg",   this);
    // Driver and sequencer only in ACTIVE mode
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = misc_sequencer::type_id::create("m_sequencer", this);
      m_driver    = misc_driver::type_id::create("m_driver",    this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    // Initialise covergroup virtual interface wrapper
    m_cg.set_vif(vif);
  endfunction

endclass : misc_agent

`endif // MISC_AGENT_SVH
