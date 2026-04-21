module ct_mmu_l2tlb_data_array #(
  parameter WAY_NUM    = 4,
  parameter ADDR_WIDTH = 8,
  parameter PPN_WIDTH  = 28, 
  parameter FLG_WIDTH  = 14
)(
  input                             cp0_mmu_icg_en,
  input                             forever_cpuclk,
  input   [WAY_NUM-1:0]             l2tlb_data_cen,  // Chip enable per way
  input   [WAY_NUM-1:0]             l2tlb_data_wen,  // Write enable per way
  input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_data_idx,  // Flattened skewed index
  input   [PPN_WIDTH+FLG_WIDTH-1:0] l2tlb_data_din,
  output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,
  input                             pad_yy_icg_scan_en
);

// Width: PPN(28) + Flags(14) = 42 bits
localparam DATA_WIDTH = PPN_WIDTH + FLG_WIDTH;

// Internal clock signals
wire    l2tlb_data_clk_en;
wire    l2tlb_data_clk;

//==========================================================
//                  Clock Gating Cell
//==========================================================
assign l2tlb_data_clk_en = |l2tlb_data_cen;

gated_clk_cell x_l2tlb_data_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (l2tlb_data_clk     ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (l2tlb_data_clk_en  ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//==========================================================
//                Generate Banks for each Way
//==========================================================
genvar j;
generate
  for (j = 0; j < WAY_NUM; j = j + 1) begin: DATA_WAY_BANK
    wire                   cen_b  = !l2tlb_data_cen[j];
    wire                   gwen_b = !l2tlb_data_wen[j];
    wire [DATA_WIDTH-1:0]  bwen_b = {DATA_WIDTH{!l2tlb_data_wen[j]}};
    wire [ADDR_WIDTH-1:0]  way_idx = l2tlb_data_idx[j*ADDR_WIDTH +: ADDR_WIDTH];

    ct_spsram_wrapper #(DATA_WIDTH, ADDR_WIDTH) x_data_sram (
      .A    (way_idx),
      .CEN  (cen_b),
      .CLK  (l2tlb_data_clk),
      .D    (l2tlb_data_din),
      .GWEN (gwen_b),
      .WEN  (bwen_b),
      .Q    (l2tlb_data_dout[j*DATA_WIDTH +: DATA_WIDTH])
    );
  end
endgenerate

endmodule
