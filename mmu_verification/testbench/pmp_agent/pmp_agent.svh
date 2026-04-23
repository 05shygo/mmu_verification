// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_agent.svh
// Phase 3: PMP agent (Responder) — builds and connects components
// =============================================================================
`ifndef PMP_AGENT_SVH
`define PMP_AGENT_SVH

class pmp_agent extends uvm_agent;

  `uvm_component_utils_begin(pmp_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  pmp_sequencer  m_sequencer;
  pmp_driver     m_driver;
  pmp_monitor    m_monitor;
  pmp_cg_wrapper m_cg;

  virtual pmp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual pmp_if)::get(this, "", "PMP_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PMP_VIF from config_db")
    m_monitor = pmp_monitor::type_id::create("m_monitor", this);
    m_cg      = pmp_cg_wrapper::type_id::create("m_cg",      this);
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = pmp_sequencer::type_id::create("m_sequencer", this);
      m_driver    = pmp_driver::type_id::create("m_driver",    this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    m_cg.set_vif(vif);
  endfunction

endclass : pmp_agent

`endif // PMP_AGENT_SVH
