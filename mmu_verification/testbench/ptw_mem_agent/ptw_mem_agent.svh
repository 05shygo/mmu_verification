// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_agent.svh
// Phase 4: PTW memory channel agent
//
// When UVM_ACTIVE (responder mode):
//   - Creates ptw_mem_responder + ptw_mem_sequencer
//   - Responder watches DUT requests and drives PTE responses via ptw_mem_if
// Always:
//   - Creates ptw_mem_monitor (observe req + rsp)
//   - Creates ptw_mem_cg_wrapper (coverage sampling)
//
// page_table_builder is injected from env.build_phase via
//   m_responder.set_page_table(builder)
// after the agent is created.
// =============================================================================
`ifndef PTW_MEM_AGENT_SVH
`define PTW_MEM_AGENT_SVH

class ptw_mem_agent extends uvm_agent;

  `uvm_component_utils_begin(ptw_mem_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end

  ptw_mem_sequencer  m_sequencer;
  ptw_mem_responder  m_responder;
  ptw_mem_monitor    m_monitor;
  ptw_mem_cg_wrapper m_cg;

  virtual ptw_mem_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ptw_mem_if)::get(this, "", "PTW_MEM_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PTW_MEM_VIF from config_db")

    // Monitor and coverage always created
    m_monitor = ptw_mem_monitor::type_id::create("m_monitor", this);
    m_cg      = ptw_mem_cg_wrapper::type_id::create("m_cg",   this);

    // Responder + sequencer only in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      m_sequencer = ptw_mem_sequencer::type_id::create("m_sequencer", this);
      m_responder = ptw_mem_responder::type_id::create("m_responder", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    // Propagate VIF to coverage wrapper
    m_cg.set_vif(vif);
    // Note: ptw_mem_responder and ptw_mem_monitor each call
    //       uvm_config_db::get in their own build_phase — no extra connect needed.
  endfunction

endclass : ptw_mem_agent

`endif // PTW_MEM_AGENT_SVH
