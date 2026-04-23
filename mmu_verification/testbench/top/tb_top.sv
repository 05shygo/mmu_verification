//=============================================================================
// MMU UVM Verification — testbench/top/tb_top.sv
// Phase 1: Minimum skeleton — compile + 0-cycle run only
// Phase 2: DUT instantiation + interface connections
//=============================================================================
`timescale 1ns/1ps

module tb_top;

  timeunit 1ns;
  timeprecision 1ps;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  //-------------------------------------------------------------------------
  // Clock & Reset (Phase 1 placeholder — replaced by dv_utils clock_gen in Phase 2)
  //-------------------------------------------------------------------------
  bit clk;
  bit rst_n;

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
    forever #0.5 clk = ~clk;   // 1 GHz placeholder
  end

  //-------------------------------------------------------------------------
  // UVM Start
  //-------------------------------------------------------------------------
  initial begin
    uvm_config_db #(int)::set(null, "*", "timeout", 100);
    run_test();
  end

endmodule : tb_top
