module L1PDE_cache #(
    parameter VPN_WIDTH  = 39-12,                       // VPN
    parameter PPN_WIDTH  = 40-12,                       // PPN
    parameter FLG_WIDTH  = 14,                          // Flags
    parameter PGS_WIDTH  = 3,                           // Page Size
    parameter PTE_LEVEL  = 3,                           // Page Table Label
    parameter TAG_WIDTH  = 9,
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
    input  logic                 L1PDE_entry_upd,
    input  logic [TAG_WIDTH-1:0] L1PDE_entry_before_upd_vpn,
    output logic                 L1PDE_entry_before_upd_hit,
    input  logic [TAG_WIDTH-1:0] L1PDE_upd_vpn,
    input  logic [PPN_WIDTH-1:0] L1PDE_upd_ppn,
    input  logic [3:0]           L1PDE_upd_l1pmpflg,
    output logic [PPN_WIDTH-1:0] L1PDE_entry_ppn,
    output logic                 L1PDE_entry_vld,
    output logic                 L1PDE_entry_hit,
    output logic [3:0]           L1PDE_entry_l1pmpflg
    //output logic                 L1PDE_miss_because_pmp
);


//logic [FLG_WIDTH-1:0] ptw_flg     ;
//logic [PPN_WIDTH-1:0] ptw_satp_ppn;
//logic [PPN_WIDTH-1:0] ptw_ppn     ;
//logic                 ptw_vld     ;
//logic                 ptw_hit           ;
//logic     [VPN_WIDTH-1:0]  ptw_vpn;
logic                 L1PDE_entry_clk_en;
logic                 L1PDE_entry_clk   ;
logic                 L1PDE_vld         ;
logic [TAG_WIDTH-1:0] L1PDE_tag         ;
logic [PPN_WIDTH-1:0] L1PDE_ppn         ;
logic                 cp0_mach_mode     ;
logic                 l1pmp_ok            ;
//logic                 L1PDE_short_hit   ;
logic                 fetch_type        ;
logic                 load_type         ;
logic                 store_type        ;
logic                 pref_type         ;
logic [3:0]           L1PDE_l1pmpflg      ;



assign L1PDE_entry_clk_en = regs_ptw_clr | L1PDE_entry_upd;

assign cp0_mach_mode = ptw_type[TYPE_WIDTH-1:0] == 3'b011 ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;

// &Instance("gated_clk_cell", "x_iutlb_entry_gateclk"); @55
gated_clk_cell  x_L1PDE_entry_gateclk (
  .clk_in             (forever_cpuclk     ),
  .clk_out            (L1PDE_entry_clk   ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (L1PDE_entry_clk_en),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);


//------------------------------------------------------------
//                  Valid bit generating
//------------------------------------------------------------
always @(posedge L1PDE_entry_clk or negedge cpurst_b)begin
	if(!cpurst_b)
		L1PDE_vld <= 1'b0;
	else if(regs_ptw_clr)
		L1PDE_vld <= 1'b0;
	else if(L1PDE_entry_upd) 
		L1PDE_vld <= 1'b1;
	else
		L1PDE_vld <= L1PDE_vld;
end


//------------------------------------------------------------
//                  VPN ,PFN and Flag information
//------------------------------------------------------------
always @(posedge L1PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
		L1PDE_tag[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
		L1PDE_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
		L1PDE_l1pmpflg[3:0] <= 4'b0;
    end else if(L1PDE_entry_upd)begin
		L1PDE_tag[TAG_WIDTH-1:0] <= L1PDE_upd_vpn[TAG_WIDTH-1:0];
		L1PDE_ppn[PPN_WIDTH-1:0] <= L1PDE_upd_ppn[PPN_WIDTH-1:0];
		L1PDE_l1pmpflg[3:0] <= L1PDE_upd_l1pmpflg[3:0];
	end else begin
		L1PDE_tag[TAG_WIDTH-1:0] <= L1PDE_tag[TAG_WIDTH-1:0];
		L1PDE_ppn[PPN_WIDTH-1:0] <= L1PDE_ppn[PPN_WIDTH-1:0];
		L1PDE_l1pmpflg[3:0] <= L1PDE_l1pmpflg[3:0];
	end
end

assign fetch_type = ptw_type[TYPE_WIDTH-1:0] == 3'b011;
assign load_type  = ptw_type[TYPE_WIDTH-1:0] == 3'b010;
assign store_type = ptw_type[TYPE_WIDTH-1:0] == 3'b110;
assign pref_type  = ptw_type[TYPE_WIDTH-1:0] == 3'b100;

always_comb begin
    case({fetch_type, load_type, store_type, pref_type})
        4'b1000: l1pmp_ok = L1PDE_l1pmpflg[2];
        4'b0100: l1pmp_ok = L1PDE_l1pmpflg[0];
        4'b0010: l1pmp_ok = L1PDE_l1pmpflg[1];
        4'b0001: l1pmp_ok = L1PDE_l1pmpflg[0];
        default: l1pmp_ok = 1'b0;
    endcase
end

//------------------------------------------------------------
//                  Entry Hit
//------------------------------------------------------------
//assign L1PDE_short_hit = (ptw_vpn[TAG_WIDTH-1:0] == L1PDE_tag[TAG_WIDTH-1:0]);
assign L1PDE_hit = (ptw_vpn[TAG_WIDTH-1:0] == L1PDE_tag[TAG_WIDTH-1:0]) & ((l1pmp_ok) | cp0_mach_mode & !L1PDE_l1pmpflg[3]);
//assign L1PDE_miss_because_pmp = L1PDE_short_hit ^ L1PDE_hit;
assign L1PDE_entry_before_upd_hit = L1PDE_vld & (L1PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L1PDE_tag[TAG_WIDTH-1:0]);
//------------------------------------------------------------
//                  Output
//------------------------------------------------------------
assign L1PDE_entry_vld = L1PDE_vld;
assign L1PDE_entry_ppn = L1PDE_ppn;
assign L1PDE_entry_hit = L1PDE_hit;
assign L1PDE_entry_l1pmpflg[3:0] = L1PDE_l1pmpflg[3:0];

endmodule





