// =============================================================================
// PTW source-side scoreboard skeleton
//
// Stage 1 scope only: declare stable fan-in names and report placeholder
// counters. Matching and mismatch classification are later-stage work.
// =============================================================================
`ifndef PTW_SOURCE_SB_SVH
`define PTW_SOURCE_SB_SVH

class ptw_source_sb extends uvm_scoreboard;

  `uvm_component_utils(ptw_source_sb)

  mmu_top_cfg m_cfg;

  uvm_tlm_analysis_fifo #(ptw_src_expected_rsp_txn) af_expected;
  uvm_tlm_analysis_fifo #(ptw_src_actual_rsp_txn)   af_actual;
  uvm_tlm_analysis_fifo #(ptw_src_req_accept_txn)   af_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)              af_mem_drop;

  int unsigned n_accepted;
  int unsigned n_matched;
  int unsigned n_mismatch;
  int unsigned n_pending;
  int unsigned n_illegal;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    n_accepted = 0;
    n_matched  = 0;
    n_mismatch = 0;
    n_pending  = 0;
    n_illegal  = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    af_expected = new("af_expected", this);
    af_actual   = new("af_actual",   this);
    af_req      = new("af_req",      this);
    af_mem_req  = new("af_mem_req",  this);
    af_mem_rsp  = new("af_mem_rsp",  this);
    af_mem_drop = new("af_mem_drop", this);

    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=source_sb stage=1 status=created provisional=1",
      UVM_LOW)
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("PTW_SOURCE_SB_SUMMARY accepted=%0d matched=%0d mismatch=%0d pending=%0d illegal=%0d provisional=1",
        n_accepted, n_matched, n_mismatch, n_pending, n_illegal),
      UVM_NONE)

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=source_sb stage=1 status=provisional expected=0 actual=0",
      UVM_NONE)
  endfunction

endclass : ptw_source_sb

`endif // PTW_SOURCE_SB_SVH
