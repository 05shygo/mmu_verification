// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_covergroups.svh
// Phase 4: PTW memory channel coverage (skeleton)
//
// Full covergroup bodies are completed in Phase 7 (coverage-closure skill).
// Embedding follows Phase 3 pattern: cg instantiated in new(), vif set later.
// =============================================================================
`ifndef PTW_MEM_COVERGROUPS_SVH
`define PTW_MEM_COVERGROUPS_SVH

class ptw_mem_cg_wrapper extends uvm_component;

  `uvm_component_utils(ptw_mem_cg_wrapper)

  virtual ptw_mem_if vif;

  // ── Covergroup: response kind distribution ────────────────────────────────
  // Verifies that all response types are exercised (normal / slow / bus_error)
  covergroup cg_ptw_rsp_kind;
    cp_kind: coverpoint vif.lsu_mmu_bus_error {
      bins normal = {1'b0};
      bins bus_err = {1'b1};
    }
  endgroup

  // ── Covergroup: response delay range ─────────────────────────────────────
  // (Phase 7: add proper delay sampling via explicit trigger)
  covergroup cg_rsp_delay_range;
    // TODO (Phase 7): sample responder delay distribution
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    // Instantiate covergroups in constructor per SV LRM §19.2
    cg_ptw_rsp_kind  = new();
    cg_rsp_delay_range = new();
  endfunction

  // Called by ptw_mem_agent.connect_phase
  virtual function void set_vif(virtual ptw_mem_if v);
    vif = v;
  endfunction

endclass : ptw_mem_cg_wrapper

`endif // PTW_MEM_COVERGROUPS_SVH
