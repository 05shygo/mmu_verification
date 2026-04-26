//=============================================================================
// cv_dv_utils library interfaces are compiled via Files.f but are not wired
// into the MMU DUT. VCS then reports UII-L (interface never instantiated).
// This module only elaborates those interfaces under tb_top so the warnings
// are resolved. For memory_response_if, tie off the bus to a quiescent known
// state (see code below) so the interface’s translate_off SVA do not see X
// on valid/ID; other sub-instances are unchanged.
//
// xrtl_reset_vif: hvl_obj is now constructed inside the interface (see
// xrtl_reset_vif.sv) so stub instances do not require TB-side allocation.
//=============================================================================
`timescale 1ns/1ps

module cv_dv_utils_unref_if_instances (
    input bit clk_i,
    input bit rst_ni
);
  import memory_rsp_model_pkg::*;

  wire reset_w;
  wire reset_n_w;
  wire post_shutdown_phase_w;

  xrtl_reset_vif u_xrtl_reset_vif (
      .clk(clk_i),
      .reset(reset_w),
      .reset_n(reset_n_w),
      .post_shutdown_phase(post_shutdown_phase_w)
  );

  generic_if u_generic_if (
      .clk_i(clk_i),
      .rst_ni(rst_ni)
  );

  memory_response_if u_memory_response_if (
      .clk(clk_i),
      .rstn(rst_ni)
  );

  // This instance only satisfies VCS "interface not instantiated" (UII-L). No
  // memory_response_model drives it; all interface logics would otherwise be
  // unassigned (X) while memory_response_if asserts known IDs/data when *valid is
  // high. Drive a permanent idle, protocol-legal quiescent state (no request,
  // no read/write response), matching how memory_response_model holds the bus
  // when idle (see memory_response_model.svh reset/wr/rd response paths).

  initial u_memory_response_if.req_ready_bp_cfg = NEVER;

  assign u_memory_response_if.req_valid    = 1'b0;
  assign u_memory_response_if.req_ready      = 1'b1;
  assign u_memory_response_if.req_wrn        = 1'b0;
  assign u_memory_response_if.req_amo        = 1'b0;
  assign u_memory_response_if.req_addr       = '0;
  assign u_memory_response_if.req_id         = '0;
  assign u_memory_response_if.req_data       = '0;
  assign u_memory_response_if.req_strb       = '0;
  assign u_memory_response_if.amo_op         = MEM_ATOMIC_ADD;
  assign u_memory_response_if.src_id         = '0;
  assign u_memory_response_if.wr_res_valid   = 1'b0;
  assign u_memory_response_if.wr_res_id        = '0;
  assign u_memory_response_if.wr_res_err       = 1'b0;
  assign u_memory_response_if.wr_res_addr     = '0;
  assign u_memory_response_if.wr_res_ex_fail  = 1'b0;
  assign u_memory_response_if.wr_res_ready     = 1'b1;
  assign u_memory_response_if.rd_res_valid     = 1'b0;
  assign u_memory_response_if.rd_res_id        = '0;
  assign u_memory_response_if.rd_res_data      = '0;
  assign u_memory_response_if.rd_res_err       = 1'b0;
  assign u_memory_response_if.rd_res_addr      = '0;
  assign u_memory_response_if.rd_res_ex_fail   = 1'b0;
  assign u_memory_response_if.rd_res_ready     = 1'b1;

  axi_if #(
      .wd_addr(64),
      .wd_data(512),
      .wd_id(16),
      .wd_user(1)
  ) u_axi_if (
      .clk(clk_i),
      .rstn(rst_ni)
  );

endmodule : cv_dv_utils_unref_if_instances
