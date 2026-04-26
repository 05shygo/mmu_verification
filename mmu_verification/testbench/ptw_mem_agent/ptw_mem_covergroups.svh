// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_covergroups.svh
// Phase 7: cg_ptw_rsp_kind + cg_rsp_delay_range（从 mmu_lsu_data_req=1 到 rsp 的拍数差）
// =============================================================================
`ifndef PTW_MEM_COVERGROUPS_SVH
`define PTW_MEM_COVERGROUPS_SVH

class ptw_mem_cg_wrapper extends uvm_component;

  `uvm_component_utils(ptw_mem_cg_wrapper)

  virtual ptw_mem_if vif;

  bit          req_latched;
  int unsigned cyc;
  int unsigned rsp_start_cyc;

  covergroup cg_ptw_rsp_kind;
    option.per_instance = 1;
    cp_kind: coverpoint vif.lsu_mmu_bus_error { bins normal = {1'b0}; bins bus_err = {1'b1}; }
  endgroup

  int unsigned s_delay;
  covergroup cg_rsp_delay_range;
    option.per_instance = 1;
    cp_delay: coverpoint s_delay {
      bins d1   = {1};
      bins d2_3 = {[2:3]};
      bins d4_8 = {[4:8]};
      bins d9p  = {[9:64]};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_ptw_rsp_kind    = new();
    cg_rsp_delay_range = new();
  endfunction

  virtual function void set_vif(virtual ptw_mem_if v);
    vif = v;
  endfunction

  virtual task run_phase(uvm_phase phase);
    cyc         = 0;
    req_latched = 0;
    forever begin
      @(posedge vif.clk_i);
      cyc++;
      if (vif.rst_ni === 1'b0) begin
        req_latched = 0;
        continue;
      end
      if (vif.mmu_lsu_data_req && !req_latched) begin
        req_latched    = 1;
        rsp_start_cyc  = cyc;
      end
      if (req_latched && (vif.lsu_mmu_data_vld || vif.lsu_mmu_bus_error)) begin
        cg_ptw_rsp_kind.sample();
        s_delay = cyc - rsp_start_cyc;  // 完成拍相对 req 建立拍的周期差（≥1）
        cg_rsp_delay_range.sample();
        req_latched = 0;
      end
    end
  endtask

endclass : ptw_mem_cg_wrapper

`endif // PTW_MEM_COVERGROUPS_SVH
