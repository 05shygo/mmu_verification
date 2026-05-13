// =============================================================================
// PTW source-side reference model skeleton
//
// Stage 1 scope only: declare stable fan-in/FIFO names, an expected-response
// analysis port, and report placeholders. No golden PTW algorithm is modeled.
// =============================================================================
`ifndef PTW_SOURCE_REF_MODEL_SVH
`define PTW_SOURCE_REF_MODEL_SVH

class ptw_source_ref_model extends uvm_component;

  `uvm_component_utils(ptw_source_ref_model)

  mmu_top_cfg m_cfg;

  uvm_tlm_analysis_fifo #(cp0_txn)                af_csr_write;
  uvm_tlm_analysis_fifo #(pmp_txn)                af_pmp_cfg;
  uvm_tlm_analysis_fifo #(sysmap_cfg_txn)         af_sysmap_cfg;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_drop;
  uvm_tlm_analysis_fifo #(ptw_src_req_accept_txn) af_req_accept;
  uvm_tlm_analysis_fifo #(ptw_src_abort_txn)      af_abort;

  uvm_analysis_port #(ptw_src_expected_rsp_txn) ap_expected;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    af_csr_write   = new("af_csr_write",   this);
    af_pmp_cfg     = new("af_pmp_cfg",     this);
    af_sysmap_cfg  = new("af_sysmap_cfg",  this);
    af_ptw_mem_req = new("af_ptw_mem_req", this);
    af_ptw_mem_rsp = new("af_ptw_mem_rsp", this);
    af_ptw_mem_drop = new("af_ptw_mem_drop", this);
    af_req_accept  = new("af_req_accept",  this);
    af_abort       = new("af_abort",       this);
    ap_expected    = new("ap_expected",    this);

    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=ref_model stage=1 status=created expected=0 provisional=1",
      UVM_LOW)
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=ref_model stage=1 expected=0 modeled=0 provisional=1",
      UVM_NONE)
  endfunction

endclass : ptw_source_ref_model

`endif // PTW_SOURCE_REF_MODEL_SVH
