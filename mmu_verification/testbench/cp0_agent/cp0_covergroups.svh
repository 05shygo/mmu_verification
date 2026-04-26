// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_covergroups.svh
// Phase 7: §10.1 — cg_cp0：cp0_mmu_wreg 或 特权/权限/SATP 相关变化
// =============================================================================
`ifndef CP0_COVERGROUPS_SVH
`define CP0_COVERGROUPS_SVH

class cp0_cg_wrapper extends uvm_component;
  `uvm_component_utils(cp0_cg_wrapper)

  virtual cp0_if vif;

  // sample 前更新（priv/mxr/.../satp_mode 快照）
  logic [1:0]  s_priv;
  bit          s_mxr, s_sum, s_mprv;
  logic [1:0]  s_mpp;
  bit [3:0]    s_satp_mode;
  bit          chg;

  covergroup cg_cp0;
    option.per_instance = 1;
    cp_priv: coverpoint s_priv { bins u = {2'b00}; bins s = {2'b01}; bins m = {2'b11}; }
    cp_mxr: coverpoint s_mxr;
    cp_sum: coverpoint s_sum;
    cp_mprv: coverpoint s_mprv;
    cp_mpp: coverpoint s_mpp;
    cp_satp_mode: coverpoint s_satp_mode { bins bare = {4'b0000};
                                            bins sv39  = {4'b1000};
                                            bins other = default;
                                          }
    cx_prv_perm: cross cp_priv, cp_mxr, cp_sum, cp_mprv;
  endgroup

  logic [1:0]  prev_priv;
  bit          prev_mxr, prev_sum, prev_mprv;
  logic [1:0]  prev_mpp;
  bit [3:0]    prev_satp_mode;
  bit          have_prev;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_cp0 = new();
  endfunction

  virtual function void set_vif(virtual cp0_if v);
    vif = v;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    have_prev = 0;
  endfunction

  virtual function void sample_cp0;
    s_priv      = vif.cp0_yy_priv_mode;
    s_mxr       = vif.cp0_mmu_mxr;
    s_sum       = vif.cp0_mmu_sum;
    s_mprv      = vif.cp0_mmu_mprv;
    s_mpp       = vif.cp0_mmu_mpp;
    s_satp_mode = mmu_cp0_satp_mode(vif);
    cg_cp0.sample();
  endfunction

  // SATP.mode 在 MMU 广播读回/镜像（与 wdata[63:60] 一致口径）
  static function bit [3:0] mmu_cp0_satp_mode(virtual cp0_if x);
    return x.mmu_cp0_satp_data[63:60];
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (vif.rst_ni === 1'b0) begin
        have_prev = 0;
        continue;
      end
      if (!have_prev) begin
        have_prev  = 1;
        prev_priv  = vif.cp0_yy_priv_mode;
        prev_mxr   = vif.cp0_mmu_mxr;
        prev_sum   = vif.cp0_mmu_sum;
        prev_mprv  = vif.cp0_mmu_mprv;
        prev_mpp   = vif.cp0_mmu_mpp;
        prev_satp_mode = mmu_cp0_satp_mode(vif);
        continue;
      end

      chg = (vif.cp0_yy_priv_mode !== prev_priv) || (vif.cp0_mmu_mxr !== prev_mxr)
        || (vif.cp0_mmu_sum !== prev_sum) || (vif.cp0_mmu_mprv !== prev_mprv)
        || (vif.cp0_mmu_mpp !== prev_mpp)
        || (mmu_cp0_satp_mode(vif) !== prev_satp_mode);

      if (vif.cp0_mmu_wreg | vif.cp0_mmu_satp_sel | chg) begin
        sample_cp0();
      end

      prev_priv      = vif.cp0_yy_priv_mode;
      prev_mxr       = vif.cp0_mmu_mxr;
      prev_sum       = vif.cp0_mmu_sum;
      prev_mprv      = vif.cp0_mmu_mprv;
      prev_mpp       = vif.cp0_mmu_mpp;
      prev_satp_mode = mmu_cp0_satp_mode(vif);
    end
  endtask

endclass : cp0_cg_wrapper

`endif // CP0_COVERGROUPS_SVH
