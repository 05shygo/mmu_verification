module ct_mmu_l2tlb_rrpv_array #(
  parameter WAY_NUM    = 8,
  parameter ADDR_WIDTH = 8,   // Default 256 entries
  parameter RRPV_WIDTH = 3
)(
  input                             cp0_mmu_icg_en,
  input                             forever_cpuclk,
  input                             pad_yy_icg_scan_en,

  input   [WAY_NUM-1:0]             l2tlb_rrpv_cen,   // Chip enable per way
  input   [WAY_NUM-1:0]             l2tlb_rrpv_wen,   // Write enable per way
  
  // Flattened Index: [WAY7_IDX, WAY6_IDX, ... , WAY0_IDX]
  input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_rrpv_idx,   
  
  // [MODIFIED] Flattened Data In: [WAY7_DIN, ... , WAY0_DIN]
  // Allows writing specific data to specific banks
  input   [WAY_NUM*RRPV_WIDTH-1:0]  l2tlb_rrpv_din,   
  
  // Flattened Data Out
  output  [WAY_NUM*RRPV_WIDTH-1:0]  l2tlb_rrpv_dout
);

// &Regs; @25

// &Wires; @26
wire    l2tlb_rrpv_clk_en;
wire    l2tlb_rrpv_clk;

//==========================================================
//                  Clock Gating Cell
//==========================================================
// Enable clock if any RRPV bank is being accessed (Read or Write)
assign l2tlb_rrpv_clk_en = |l2tlb_rrpv_cen;

// &Instance("gated_clk_cell", "x_l2tlb_rrpv_gateclk"); @33
gated_clk_cell x_l2tlb_rrpv_gateclk (
  .clk_in             (forever_cpuclk     ),
  .clk_out            (l2tlb_rrpv_clk      ),
  .external_en        (1'b0               ),
  .global_en          (1'b1               ),
  .local_en           (l2tlb_rrpv_clk_en   ),
  .module_en          (cp0_mmu_icg_en     ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en )
);

//==========================================================
//                Generate Banks for each Way
//==========================================================
genvar k;
generate
  for (k = 0; k < WAY_NUM; k = k + 1) begin: RRPV_WAY_BANK
    
    // 1. Local Control Signals (Active Low for Memory Wrappers usually)
    wire                    cen_b   = !l2tlb_rrpv_cen[k];
    wire                    gwen_b  = !l2tlb_rrpv_wen[k];
    // Bit-wise Write Enable (Active Low)
    wire [RRPV_WIDTH-1:0]   bwen_b  = {RRPV_WIDTH{!l2tlb_rrpv_wen[k]}};
    
    // 2. Signal Slicing
    // Get the index for this specific way
    wire [ADDR_WIDTH-1:0]   way_idx = l2tlb_rrpv_idx[k*ADDR_WIDTH +: ADDR_WIDTH];
    // Get the data input for this specific way (Matches WBUF output width)
    wire [RRPV_WIDTH-1:0]   way_din = l2tlb_rrpv_din[k*RRPV_WIDTH +: RRPV_WIDTH];

    // 3. Instance
    // Reuse the same SRAM wrapper used for Tag/Data
    ct_spsram_wrapper #(
        .DATA_WIDTH (RRPV_WIDTH), 
        .ADDR_WIDTH (ADDR_WIDTH)
    ) x_rrpv_sram (
      .A    (way_idx),
      .CEN  (cen_b),
      .CLK  (l2tlb_rrpv_clk),
      .D    (way_din),
      .GWEN (gwen_b),
      .WEN  (bwen_b),
      .Q    (l2tlb_rrpv_dout[k*RRPV_WIDTH +: RRPV_WIDTH])
    );
  end
endgenerate

// &ModuleEnd; @180
endmodule
