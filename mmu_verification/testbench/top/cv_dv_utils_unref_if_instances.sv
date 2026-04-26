//=============================================================================
// cv_dv_utils library interfaces are compiled via Files.f but are not wired
// into the MMU DUT. VCS then reports UII-L (interface never instantiated).
// This module only elaborates those interfaces under tb_top so the warnings
// are resolved; nothing in the UVM env is required to drive them.
//
// xrtl_reset_vif: hvl_obj is now constructed inside the interface (see
// xrtl_reset_vif.sv) so stub instances do not require TB-side allocation.
//=============================================================================
`timescale 1ns/1ps

module cv_dv_utils_unref_if_instances (
    input bit clk_i,
    input bit rst_ni
);

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
