module L2PDE_cache #(
    parameter VPN_WIDTH  = 39-12,                       // VPN
    parameter PPN_WIDTH  = 40-12,                       // PPN
    parameter FLG_WIDTH  = 14,                          // Flags
    parameter PGS_WIDTH  = 3,                           // Page Size
    parameter PTE_LEVEL  = 3,                           // Page Table Label
    parameter TAG_WIDTH  = 18,
    parameter DATA_WIDTH = 64,
    parameter TYPE_WIDTH = 3
) (
    input  logic                 forever_cpuclk,
    input  logic                 cpurst_b,
    input  logic                 pad_yy_icg_scan_en,
    input  logic                 cp0_mmu_icg_en,
    input  logic                 regs_ptw_clr,
    input  logic [1:0]           cp0_yy_priv_mode,
    input  logic [1:0]           cp0_priv_mode,

    input  logic [TAG_WIDTH-1:0] ptw_vpn,
    input  logic [TYPE_WIDTH-1:0] ptw_type,
//input  logic [PPN_WIDTH-1:0] regs_ptw_satp_ppn,
    input  logic                 L2PDE_entry_upd,
    input  logic [TAG_WIDTH-1:0] L2PDE_entry_before_upd_vpn,
    output logic                 L2PDE_entry_before_upd_hit,
    input  logic [TAG_WIDTH-1:0] L2PDE_upd_vpn,
    input  logic [PPN_WIDTH-1:0] L2PDE_upd_ppn,
    input  logic [4:0]           L2PDE_upd_pmpflg,

    output logic [PPN_WIDTH-1:0] L2PDE_entry_ppn,
    output logic                 L2PDE_entry_vld,
    output logic                 L2PDE_entry_hit
);


logic [FLG_WIDTH-1:0] ptw_flg           ;
logic [PPN_WIDTH-1:0] ptw_satp_ppn      ;
logic [PPN_WIDTH-1:0] ptw_ppn           ;
logic                 ptw_vld           ;
logic                 L2PDE_entry_clk_en;
logic                 L2PDE_entry_clk   ;
logic                 ptw_hit           ;
logic                 L2PDE_vld         ;
logic [TAG_WIDTH-1:0] L2PDE_tag         ;
logic [PPN_WIDTH-1:0] L2PDE_ppn         ;
logic                 cp0_mach_mode     ;
logic                 pmp_ok            ;
logic                 fetch_type        ;
logic                 load_type         ;
logic                 store_type        ;
logic                 pref_type         ;
logic [4:0]           L2PDE_pmpflg      ;


assign L2PDE_entry_clk_en = regs_ptw_clr | L2PDE_entry_upd;

assign cp0_mach_mode = ptw_type[TYPE_WIDTH-1:0] == 3'b011 ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;

// &Instance("gated_clk_cell", "x_iutlb_entry_gateclk"); @55
gated_clk_cell  x_L2PDE_entry_gateclk (
  .clk_in             (forever_cpuclk     ),
  .clk_out            (L2PDE_entry_clk   ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (L2PDE_entry_clk_en),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);




//------------------------------------------------------------
//                  Valid bit generating
//------------------------------------------------------------
always @(posedge L2PDE_entry_clk or negedge cpurst_b)begin
	if(!cpurst_b)
		L2PDE_vld <= 1'b0;
	else if(regs_ptw_clr)
		L2PDE_vld <= 1'b0;
	else if(L2PDE_entry_upd) 
		L2PDE_vld <= 1'b1;
end


//------------------------------------------------------------
//                  VPN ,PFN and Flag information
//------------------------------------------------------------
always @(posedge L2PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
		L2PDE_tag[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
		L2PDE_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
		L2PDE_pmpflg[4:0] <= 5'b0;
    end else if(L2PDE_entry_upd)begin
		L2PDE_tag[TAG_WIDTH-1:0] <= L2PDE_upd_vpn[TAG_WIDTH-1:0];
		L2PDE_ppn[PPN_WIDTH-1:0] <= L2PDE_upd_ppn[PPN_WIDTH-1:0];
		L2PDE_pmpflg[4:0] <= L2PDE_upd_pmpflg[4:0];
	end
end

assign fetch_type = ptw_type[TYPE_WIDTH-1:0] == 3'b011;
assign load_type  = ptw_type[TYPE_WIDTH-1:0] == 3'b010;
assign store_type = ptw_type[TYPE_WIDTH-1:0] == 3'b110;
assign pref_type  = ptw_type[TYPE_WIDTH-1:0] == 3'b100;

always_comb begin
    case({fetch_type, load_type, store_type, pref_type})
        4'b1000: pmp_ok = L2PDE_pmpflg[2];
        4'b0100: pmp_ok = L2PDE_pmpflg[0];
        4'b0010: pmp_ok = L2PDE_pmpflg[1];
        4'b0001: pmp_ok = L2PDE_pmpflg[0];
        default: pmp_ok = 1'b0;
    endcase
end

//------------------------------------------------------------
//                  Entry Hit
//------------------------------------------------------------
assign L2PDE_hit = (ptw_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]) & (pmp_ok | cp0_mach_mode & L2PDE_pmpflg[3]);
assign L2PDE_entry_before_upd_hit = (L2PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]);
//------------------------------------------------------------
//                  Output
//------------------------------------------------------------
assign L2PDE_entry_vld = L2PDE_vld;
assign L2PDE_entry_ppn = L2PDE_ppn;
assign L2PDE_entry_hit = L2PDE_hit;

endmodule






