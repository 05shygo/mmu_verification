module	PDE_cache(
//!******************************************
//! Clock and Reset
//!******************************************
input logic 			forever_cpuclk,
input logic 			cpurst_b,
input logic             cp0_mmu_icg_en,
input logic             pad_yy_icg_scan_en,

//!******************************************
//! L2TLB Request
//!******************************************
input logic [26:0]		l2tlb_ptw_vpn,
input logic [2:0]		l2tlb_ptw_type,
input logic [5:0]		l2tlb_ptw_id,
input logic 			l2tlb_ptw_req,

//!******************************************
//! PTW MBUF Request
//!******************************************
input logic 			mbuf_cache_upd,
input logic	[1:0]		mbuf_cache_upd_lvl,
input logic [27:0]		mbuf_cache_upd_ppn,
input logic [26:0]		mbuf_cache_upd_vpn,

//!******************************************
//! Regs Request
//!******************************************
input logic 			regs_ptw_clr,

//!******************************************
//! PDE Cache to xbar
//!******************************************
output logic 			L2PDE_xbar_hit_vld,
output logic 			L1PDE_xbar_hit_vld,
output logic [27:0]		PDE_xbar_ppn,
output logic [26:0]		PDE_xbar_vpn,
output logic [2:0]		PDE_xbar_type,
output logic [5:0]		PDE_xbar_id,
output logic 			PDE_xbar_req,
			
//input  logic 			twu_cache_stop,
input  logic 			tlboper_ptw_abort,
input  logic			xbar_pde_ready,
output logic            pde_cache_ready
);

logic	[26:0]			ptw_vpn;
logic	[2:0]			ptw_type;
logic	[5:0]			ptw_id;
logic				ptw_req;
logic	[15:0]			L1PDE_entry_upd;
logic	[15:0]			L2PDE_entry_upd;
logic	[15:0][27:0]	L1PDE_entry_ppn;
logic	[15:0]			L1PDE_entry_vld;
logic	[15:0]			L1PDE_entry_hit;
logic	[15:0][27:0]	L2PDE_entry_ppn;
logic	[15:0]			L2PDE_entry_vld;
logic	[15:0]			L2PDE_entry_hit;
logic	[27:0]			L1PDE_cache_hit_ppn;
logic	[27:0]			L2PDE_cache_hit_ppn;
logic	[27:0]			PDE_cache_fin_ppn;
logic					L1PDE_entry_hit_vld;
logic					L2PDE_entry_hit_vld;
logic					L1PDE_plru_read_hit_vld;
logic					L2PDE_plru_read_hit_vld;
logic					L1PDE_plru_refill_vld;
logic					L2PDE_plru_refill_vld;
logic	[15:0]			L1PDE_entry_hit_idx;
logic	[15:0]			L2PDE_entry_hit_idx;
logic   [3:0]           L1PDE_hit_idx_num;
logic   [3:0]           L2PDE_hit_idx_num;
logic	[15:0]			plru_L1PDE_ref_num;
logic	[15:0]			plru_L2PDE_ref_num;
logic                   pde_cache_clk_en;
logic                   pde_cache_clk;


parameter VADDR_WIDTH = 39;              // VADDR
parameter PADDR_WIDTH = 40;              // PADDR
parameter VPN_WIDTH   = VADDR_WIDTH-12;  // VPN
parameter PPN_WIDTH   = PADDR_WIDTH-12;  // PPN
parameter FLG_WIDTH   = 14;              // PPN
parameter ASID_WIDTH  = 16;              // PPN
parameter PGS_WIDTH   = 3;               // Page Size
parameter PTE_LEVEL   = 3;               // Page Table Label
parameter ID_WIDTH    = 6;


// VPN width per level
parameter VPN_PERLEL = VPN_WIDTH/PTE_LEVEL;

// Valid + VPN + ASID + PageSize + Global
parameter TAG_WIDTH  = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1;  
parameter DATA_WIDTH = PPN_WIDTH+FLG_WIDTH;	

//assign pde_cache_clk_en = l2tlb_ptw_req | tlboper_ptw_abort | (!xbar_pde_ready);
assign pde_cache_clk_en = 1'b1;

gated_clk_cell  x_pde_cache_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (pde_cache_clk     ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (pde_cache_clk_en  ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

assign pde_cache_ready = xbar_pde_ready;
		

always_ff@(posedge pde_cache_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		ptw_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		ptw_type[2:0] <= 3'b0;
		ptw_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};		
	end else if(l2tlb_ptw_req)begin
		ptw_vpn[VPN_WIDTH-1:0] <= l2tlb_ptw_vpn[VPN_WIDTH-1:0];
		ptw_type[2:0] <= l2tlb_ptw_type[2:0];
		ptw_id[ID_WIDTH-1:0] <= l2tlb_ptw_id[ID_WIDTH-1:0];
	end else begin
		ptw_vpn[VPN_WIDTH-1:0] <= ptw_vpn[VPN_WIDTH-1:0];
		ptw_type[2:0] <= ptw_type[2:0];
		ptw_id[ID_WIDTH-1:0] <= ptw_id[ID_WIDTH-1:0];
	end
end 

always_ff@(posedge pde_cache_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		ptw_req <= 1'b0;
	else if(tlboper_ptw_abort)	
		ptw_req <= 1'b0;
	else if(l2tlb_ptw_req)
		ptw_req <= 1'b1;
	else if(!xbar_pde_ready)
		ptw_req <= ptw_req;
	else
		ptw_req <= 1'b0;
end


//==============================================================================
//                  DFF
//==============================================================================
//L1PDE_cache
generate
	for(genvar L1PDE_ent = 0;L1PDE_ent <= 15;L1PDE_ent = L1PDE_ent + 1)begin:u_L1PDE_ent_0_15

		L1PDE_cache u_L1PDE_cache(
		.forever_cpuclk					(forever_cpuclk				),
		.cpurst_b						(cpurst_b					),
        .pad_yy_icg_scan_en             (pad_yy_icg_scan_en         ),
        .cp0_mmu_icg_en                 (cp0_mmu_icg_en             ),
		.regs_ptw_clr					(regs_ptw_clr				),
	
		.ptw_vpn						(ptw_vpn[VPN_WIDTH-1:18]	),
		.L1PDE_entry_upd				(L1PDE_entry_upd[L1PDE_ent]	),	
		.L1PDE_upd_vpn					(mbuf_cache_upd_vpn[26:18]	),
		.L1PDE_upd_ppn					(mbuf_cache_upd_ppn[27:0]   ),

		.L1PDE_entry_ppn				(L1PDE_entry_ppn[L1PDE_ent] ),
		.L1PDE_entry_vld				(L1PDE_entry_vld[L1PDE_ent]	),
		.L1PDE_entry_hit                (L1PDE_entry_hit[L1PDE_ent]	)
		);
	end
endgenerate

//L2PDE_cache
generate
	for(genvar L2PDE_ent = 0;L2PDE_ent <= 15;L2PDE_ent = L2PDE_ent + 1)begin:u_L2PDE_ent_0_15

		L2PDE_cache u_L2PDE_cache(
		.forever_cpuclk					(forever_cpuclk				),
		.cpurst_b						(cpurst_b					),
        .pad_yy_icg_scan_en             (pad_yy_icg_scan_en         ),
        .cp0_mmu_icg_en                 (cp0_mmu_icg_en             ),
		.regs_ptw_clr					(regs_ptw_clr				),
                                                                    
		.ptw_vpn						(ptw_vpn[VPN_WIDTH-1:9] 	),
		.L2PDE_entry_upd				(L2PDE_entry_upd[L2PDE_ent] ),
		.L2PDE_upd_vpn					(mbuf_cache_upd_vpn[26:9]	),
		.L2PDE_upd_ppn					(mbuf_cache_upd_ppn[27:0]   ),

		.L2PDE_entry_ppn				(L2PDE_entry_ppn[L2PDE_ent] ),
		.L2PDE_entry_vld				(L2PDE_entry_vld[L2PDE_ent]	),
		.L2PDE_entry_hit                (L2PDE_entry_hit[L2PDE_ent]	)
		);
	end
endgenerate

//==============================================================================
//                   HIT OUTPUT
//==============================================================================
assign L1PDE_entry_hit_idx[15:0] = (L1PDE_entry_vld[15:0] & L1PDE_entry_hit[15:0]);
assign L1PDE_entry_hit_vld = (|L1PDE_entry_hit_idx[15:0]) ;

assign L2PDE_entry_hit_idx[15:0] = (L2PDE_entry_vld[15:0] & L2PDE_entry_hit[15:0]);
assign L2PDE_entry_hit_vld = (|L2PDE_entry_hit_idx[15:0]);


always_comb begin 
	case(L1PDE_entry_hit_idx[15:0])
	    16'b0000000000000001 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[0][PPN_WIDTH-1:0];
	    16'b0000000000000010 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[1][PPN_WIDTH-1:0];
	    16'b0000000000000100 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[2][PPN_WIDTH-1:0];
        16'b0000000000001000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[3][PPN_WIDTH-1:0];
	    16'b0000000000010000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[4][PPN_WIDTH-1:0];
	    16'b0000000000100000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[5][PPN_WIDTH-1:0];
	    16'b0000000001000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[6][PPN_WIDTH-1:0];
	    16'b0000000010000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[7][PPN_WIDTH-1:0];
	    16'b0000000100000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[8][PPN_WIDTH-1:0];
	    16'b0000001000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[9][PPN_WIDTH-1:0];
	    16'b0000010000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[10][PPN_WIDTH-1:0];
	    16'b0000100000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[11][PPN_WIDTH-1:0];
	    16'b0001000000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[12][PPN_WIDTH-1:0];
	    16'b0010000000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[13][PPN_WIDTH-1:0];
	    16'b0100000000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[14][PPN_WIDTH-1:0];
	    16'b1000000000000000 : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[15][PPN_WIDTH-1:0];
	    default     : L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
	endcase
end

always_comb begin 	 
	case(L2PDE_entry_hit_idx[15:0])
	    16'b0000000000000001 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[0][PPN_WIDTH-1:0];
	    16'b0000000000000010 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[1][PPN_WIDTH-1:0];
	    16'b0000000000000100 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[2][PPN_WIDTH-1:0];
	    16'b0000000000001000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[3][PPN_WIDTH-1:0];
	    16'b0000000000010000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[4][PPN_WIDTH-1:0];
	    16'b0000000000100000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[5][PPN_WIDTH-1:0];
	    16'b0000000001000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[6][PPN_WIDTH-1:0];
	    16'b0000000010000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[7][PPN_WIDTH-1:0];
	    16'b0000000100000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[8][PPN_WIDTH-1:0];
	    16'b0000001000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[9][PPN_WIDTH-1:0];
	    16'b0000010000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[10][PPN_WIDTH-1:0];
	    16'b0000100000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[11][PPN_WIDTH-1:0];
	    16'b0001000000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[12][PPN_WIDTH-1:0];
	    16'b0010000000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[13][PPN_WIDTH-1:0];
	    16'b0100000000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[14][PPN_WIDTH-1:0];
	    16'b1000000000000000 : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[15][PPN_WIDTH-1:0];
		default     : L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
	endcase
end

always_comb begin
	casez({L2PDE_entry_hit_vld,L1PDE_entry_hit_vld})
		2'b01 : PDE_cache_fin_ppn[PPN_WIDTH-1:0] = L1PDE_cache_hit_ppn[PPN_WIDTH-1:0];
		2'b1? : PDE_cache_fin_ppn[PPN_WIDTH-1:0] = L2PDE_cache_hit_ppn[PPN_WIDTH-1:0];
		default: PDE_cache_fin_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
	endcase
end

always_comb begin
	case(L1PDE_entry_hit_idx[15:0])
		16'h0001: L1PDE_hit_idx_num = 4'd0;
		16'h0002: L1PDE_hit_idx_num = 4'd1;
		16'h0004: L1PDE_hit_idx_num = 4'd2;
		16'h0008: L1PDE_hit_idx_num = 4'd3;
		16'h0010: L1PDE_hit_idx_num = 4'd4;
		16'h0020: L1PDE_hit_idx_num = 4'd5;
		16'h0040: L1PDE_hit_idx_num = 4'd6;
		16'h0080: L1PDE_hit_idx_num = 4'd7;
		16'h0100: L1PDE_hit_idx_num = 4'd8;
		16'h0200: L1PDE_hit_idx_num = 4'd9;
		16'h0400: L1PDE_hit_idx_num = 4'd10;
		16'h0800: L1PDE_hit_idx_num = 4'd11;
		16'h1000: L1PDE_hit_idx_num = 4'd12;
		16'h2000: L1PDE_hit_idx_num = 4'd13;
		16'h4000: L1PDE_hit_idx_num = 4'd14;
		16'h8000: L1PDE_hit_idx_num = 4'd15;
		default : L1PDE_hit_idx_num = 4'd0;
	endcase
end

always_comb begin
	case(L2PDE_entry_hit_idx[15:0])
		16'h0001: L2PDE_hit_idx_num = 4'd0;
		16'h0002: L2PDE_hit_idx_num = 4'd1;
		16'h0004: L2PDE_hit_idx_num = 4'd2;
		16'h0008: L2PDE_hit_idx_num = 4'd3;
		16'h0010: L2PDE_hit_idx_num = 4'd4;
		16'h0020: L2PDE_hit_idx_num = 4'd5;
		16'h0040: L2PDE_hit_idx_num = 4'd6;
		16'h0080: L2PDE_hit_idx_num = 4'd7;
		16'h0100: L2PDE_hit_idx_num = 4'd8;
		16'h0200: L2PDE_hit_idx_num = 4'd9;
		16'h0400: L2PDE_hit_idx_num = 4'd10;
		16'h0800: L2PDE_hit_idx_num = 4'd11;
		16'h1000: L2PDE_hit_idx_num = 4'd12;
		16'h2000: L2PDE_hit_idx_num = 4'd13;
		16'h4000: L2PDE_hit_idx_num = 4'd14;
		16'h8000: L2PDE_hit_idx_num = 4'd15;
		default : L2PDE_hit_idx_num = 4'd0;
	endcase
end

//==============================================================================
//                  refill  LRU
//==============================================================================
assign L1PDE_plru_read_hit_vld = L1PDE_entry_hit_vld;
assign L2PDE_plru_read_hit_vld = L2PDE_entry_hit_vld;

assign L1PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[1]);
assign L2PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[0]);

pplru u_L1PDE_cache_pplru(
.forever_cpuclk					(forever_cpuclk			),               
.cpurst_b						(cpurst_b				),
.pad_yy_icg_scan_en             (pad_yy_icg_scan_en     ),
.cp0_mmu_icg_en                 (cp0_mmu_icg_en         ),
.PDE_plru_read_vld				(L1PDE_entry_vld[15:0]	),               
.PDE_plru_read_hit				(L1PDE_entry_hit[15:0]	),       
.PDE_plru_read_hit_vld			(L1PDE_plru_read_hit_vld),   
.PDE_plru_refill_vld			(L1PDE_plru_refill_vld	),  

.plru_PDE_ref_num  				(plru_L1PDE_ref_num		)
);

pplru u_L2PDE_cache_pplru(
.forever_cpuclk					(forever_cpuclk			),                 
.cpurst_b						(cpurst_b				),
.pad_yy_icg_scan_en             (pad_yy_icg_scan_en     ),
.cp0_mmu_icg_en                 (cp0_mmu_icg_en         ),
.PDE_plru_read_vld				(L2PDE_entry_vld[15:0]	),               
.PDE_plru_read_hit				(L2PDE_entry_hit[15:0]	),       
.PDE_plru_read_hit_vld			(L2PDE_plru_read_hit_vld),    
.PDE_plru_refill_vld			(L2PDE_plru_refill_vld	),  

.plru_PDE_ref_num  				(plru_L2PDE_ref_num		)
);

assign L1PDE_entry_upd[15:0] = plru_L1PDE_ref_num[15:0] & {16{L1PDE_plru_refill_vld}};
assign L2PDE_entry_upd[15:0] = plru_L2PDE_ref_num[15:0] & {16{L2PDE_plru_refill_vld}};




//==============================================================================
//                   OUTPUT
//==============================================================================

assign L2PDE_xbar_hit_vld = L2PDE_entry_hit_vld;
assign L1PDE_xbar_hit_vld = L1PDE_entry_hit_vld & (~L2PDE_entry_hit_vld);
assign PDE_xbar_ppn[PPN_WIDTH-1:0] = PDE_cache_fin_ppn[PPN_WIDTH-1:0];
assign PDE_xbar_vpn[VPN_WIDTH-1:0] = ptw_vpn[VPN_WIDTH-1:0];
assign PDE_xbar_type[2:0] = ptw_type[2:0];
assign PDE_xbar_id[ID_WIDTH-1:0] = ptw_id[ID_WIDTH-1:0];
assign PDE_xbar_req = ptw_req & xbar_pde_ready;

// Trace PDE cache hit details for run_check post-log analysis.
always_ff @(posedge pde_cache_clk or negedge cpurst_b) begin
	if(!cpurst_b) begin
		// no-op
	end else if(PDE_xbar_req && L2PDE_xbar_hit_vld) begin
		$display("[%0t][PDE CACHE HIT] lvl=L2 req_vpn=0x%07h tag=0x%05h hit_idx=%0d hit_vec=0x%04h out_ppn=0x%07h",
		         $time, PDE_xbar_vpn, PDE_xbar_vpn[26:9], L2PDE_hit_idx_num, L2PDE_entry_hit_idx, PDE_xbar_ppn);
	end else if(PDE_xbar_req && L1PDE_xbar_hit_vld) begin
		$display("[%0t][PDE CACHE HIT] lvl=L1 req_vpn=0x%07h tag=0x%03h hit_idx=%0d hit_vec=0x%04h out_ppn=0x%07h",
		         $time, PDE_xbar_vpn, PDE_xbar_vpn[26:18], L1PDE_hit_idx_num, L1PDE_entry_hit_idx, PDE_xbar_ppn);
	end
end


endmodule


