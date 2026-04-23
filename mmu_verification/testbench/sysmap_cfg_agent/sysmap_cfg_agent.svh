// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_agent.svh
// Phase 3: SysMap configuration agent (Active)
// =============================================================================
`ifndef SYSMAP_CFG_AGENT_SVH
`define SYSMAP_CFG_AGENT_SVH

class sysmap_cfg_agent extends uvm_agent;

  `uvm_component_utils_begin(sysmap_cfg_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  sysmap_cfg_sequencer    m_sequencer;
  sysmap_cfg_driver       m_driver;
  sysmap_cfg_monitor      m_monitor;
  sysmap_cfg_cg_wrapper   m_cg;

  virtual sysmap_cfg_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual sysmap_cfg_if)::get(this, "", "SYSMAP_CFG_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get SYSMAP_CFG_VIF from config_db")
    m_monitor = sysmap_cfg_monitor::type_id::create("m_monitor", this);
    m_cg      = sysmap_cfg_cg_wrapper::type_id::create("m_cg",   this);
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = sysmap_cfg_sequencer::type_id::create("m_sequencer", this);
      m_driver    = sysmap_cfg_driver::type_id::create("m_driver",       this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    m_cg.set_vif(vif);
  endfunction

endclass : sysmap_cfg_agent

`endif // SYSMAP_CFG_AGENT_SVH
