module ct_mmu_l2tlb_tag_array #(
  parameter WAY_NUM    = 4,
  parameter ADDR_WIDTH = 8,  // Default 256 entries
  parameter VPN_WIDTH  = 27, 
  parameter ASID_WIDTH = 16,
  parameter PGS_WIDTH  = 3
)(
  input                             cp0_mmu_icg_en,
  input                             forever_cpuclk,
  input   [WAY_NUM-1:0]             l2tlb_tag_cen,   // Chip enable per way
  input   [WAY_NUM-1:0]             l2tlb_tag_wen,   // Write enable per way
  input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_tag_idx,   // Flattened skewed index
  input   [1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1-1:0] l2tlb_tag_din,
  output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,
  input                             pad_yy_icg_scan_en
);

// Width: VLD(1) + VPN(27) + ASID(16) + PGS(3) + Global(1) = 48 bits
localparam TAG_WIDTH = 1 + VPN_WIDTH + ASID_WIDTH + PGS_WIDTH + 1;

// Internal clock signals
wire    l2tlb_tag_clk_en;
wire    l2tlb_tag_clk;

//==========================================================
//                  Clock Gating Cell
//==========================================================
// Global gate: Enable clock if any bank is active
assign l2tlb_tag_clk_en = |l2tlb_tag_cen;

gated_clk_cell x_l2tlb_tag_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (l2tlb_tag_clk     ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (l2tlb_tag_clk_en   ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//==========================================================
//                Generate Banks for each Way
//==========================================================
genvar i;
generate
  for (i = 0; i < WAY_NUM; i = i + 1) begin: TAG_WAY_BANK
    // Local signals within the generate scope
    wire                   cen_b  = !l2tlb_tag_cen[i];
    wire                   gwen_b = !l2tlb_tag_wen[i];
    wire [TAG_WIDTH-1:0]   bwen_b = {TAG_WIDTH{!l2tlb_tag_wen[i]}};
    wire [ADDR_WIDTH-1:0]  way_idx = l2tlb_tag_idx[i*ADDR_WIDTH +: ADDR_WIDTH];

    ct_spsram_wrapper #(TAG_WIDTH, ADDR_WIDTH) x_tag_sram (
      .A    (way_idx),
      .CEN  (cen_b),
      .CLK  (l2tlb_tag_clk),
      .D    (l2tlb_tag_din),
      .GWEN (gwen_b),
      .WEN  (bwen_b),
      .Q    (l2tlb_tag_dout[i*TAG_WIDTH +: TAG_WIDTH])
    );
  end
endgenerate

endmodule
