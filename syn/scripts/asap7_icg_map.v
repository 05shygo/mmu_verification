//===========================================================================
// Yosys techmap file: Replace gated_clk_cell with ASAP7 ICG primitives
//
// Port mapping:
//   gated_clk_cell      ->  ICGx1_ASAP7_75t_R
//   .clk_in             ->  .CLK
//   .clk_out            ->  .GCLK
//   .pad_yy_icg_scan_en ->  .SE
//   enable logic        ->  .ENA   (combinational: (global_en && (module_en || local_en)) || external_en)
//
// The ASAP7 ICG has a built-in latch (latch_posedge_precontrol):
// ENA is latched internally on the negative edge of CLK.
//===========================================================================

(* techmap_celltype = "gated_clk_cell" *)
module _gated_clk_cell_asap7_icg_techmap (
    input  clk_in,
    input  global_en,
    input  module_en,
    input  local_en,
    input  external_en,
    input  pad_yy_icg_scan_en,
    output clk_out
);
    wire clk_en;
    assign clk_en = (global_en && (module_en || local_en)) || external_en;

    ICGx1_ASAP7_75t_R _icg_ (
        .GCLK (clk_out),
        .ENA  (clk_en),
        .SE   (pad_yy_icg_scan_en),
        .CLK  (clk_in)
    );
endmodule
