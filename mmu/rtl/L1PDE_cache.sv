module L1PDE_cache(
input  logic 		forever_cpuclk,
input  logic 		cpurst_b,
input  logic 		pad_yy_icg_scan_en,
input  logic 		cp0_mmu_icg_en,
input  logic 		regs_ptw_clr,

input  logic [8:0]  ptw_vpn,
input  logic 		L1PDE_entry_upd,
input  logic [8:0]  L1PDE_upd_vpn,
input  logic [27:0] L1PDE_upd_ppn,

output logic [27:0] L1PDE_entry_ppn,
output logic 		L1PDE_entry_vld,
output logic 		L1PDE_entry_hit
);


logic     [13:0]  ptw_flg; 
logic     [27:0]  ptw_satp_ppn;                          
logic     [27:0]  ptw_ppn;               
logic             ptw_vld;               
//logic     [26:0]  ptw_vpn;               
logic             L1PDE_entry_clk_en;           
logic             L1PDE_entry_clk;         
logic             ptw_hit;
logic		  L1PDE_vld;
logic	[8:0]	  L1PDE_tag;
logic	[27:0]	  L1PDE_ppn;


assign L1PDE_entry_clk_en = regs_ptw_clr | L1PDE_entry_upd;

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


parameter VPN_WIDTH = 39-12;  // VPN
parameter PPN_WIDTH = 40-12;  // PPN
parameter FLG_WIDTH = 14;     // Flags
parameter PGS_WIDTH = 3;      // Page Size
parameter PTE_LEVEL = 3;      // Page Table Label
parameter TAG_WIDTH = 9;
parameter DATA_WIDTH = 64;



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
end


//------------------------------------------------------------
//                  VPN ,PFN and Flag information
//------------------------------------------------------------
always @(posedge L1PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
		L1PDE_tag[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
		L1PDE_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
    end else if(L1PDE_entry_upd)begin
		L1PDE_tag[TAG_WIDTH-1:0] <= L1PDE_upd_vpn[8:0];
		L1PDE_ppn[PPN_WIDTH-1:0] <= L1PDE_upd_ppn[PPN_WIDTH-1:0];
	end
end

//------------------------------------------------------------
//                  Entry Hit
//------------------------------------------------------------
assign L1PDE_hit = (ptw_vpn[8:0] == L1PDE_tag[TAG_WIDTH-1:0]);

//------------------------------------------------------------
//                  Output
//------------------------------------------------------------
assign L1PDE_entry_vld = L1PDE_vld;
assign L1PDE_entry_ppn = L1PDE_ppn;
assign L1PDE_entry_hit = L1PDE_hit;

endmodule






