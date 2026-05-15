module PDE_cache #(
    parameter VADDR_WIDTH = 39,                         // VADDR
    parameter PADDR_WIDTH = 40,                         // PADDR
    parameter VPN_WIDTH   = VADDR_WIDTH-12,             // VPN
    parameter PPN_WIDTH   = PADDR_WIDTH-12,             // PPN
    parameter FLG_WIDTH   = 14,                         // PPN
    parameter ASID_WIDTH  = 16,                         // PPN
    parameter PGS_WIDTH   = 3,                          // Page Size
    parameter PTE_LEVEL   = 3,                          // Page Table Label
    parameter ID_WIDTH    = 6,
    parameter TYPE_WIDTH  = 3,
    parameter L1PDE_ENTRY_NUM = 16,
    parameter L2PDE_ENTRY_NUM = 16,

// VPN width per level
    parameter VPN_PERLEL  = VPN_WIDTH/PTE_LEVEL,

// Valid + VPN + ASID + PageSize + Global
    parameter TAG_WIDTH   = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,
    parameter DATA_WIDTH  = PPN_WIDTH+FLG_WIDTH
) (
//!******************************************
//! Clock and Reset
//!******************************************
    input  logic                  forever_cpuclk,
    input  logic                  cpurst_b,
    input  logic                  cp0_mmu_icg_en,
    input  logic                  pad_yy_icg_scan_en,
	input  logic                  cp0_mmu_mprv,
	input  logic [1:0]            cp0_yy_priv_mode,
	input  logic [1:0]            cp0_mmu_mpp,

//!******************************************
//! L2TLB Request
//!******************************************
    input  logic [VPN_WIDTH-1:0]  l2tlb_ptw_vpn,
    input  logic [TYPE_WIDTH-1:0] l2tlb_ptw_type,
    input  logic [ID_WIDTH-1:0]   l2tlb_ptw_id,
    input  logic                  l2tlb_ptw_req,

//!******************************************
//! PTW MBUF Request
//!******************************************
    input  logic                  mbuf_cache_upd,
    input  logic [PTE_LEVEL-2:0]  mbuf_cache_upd_lvl,
    input  logic [PPN_WIDTH-1:0]  mbuf_cache_upd_ppn,
    input  logic [VPN_WIDTH-1:0]  mbuf_cache_upd_vpn,
    input  logic [3:0]            mbuf_cache_upd_pmpflg,

//!******************************************
//! Regs Request
//!******************************************
    input  logic                  regs_ptw_clr,

//!******************************************
//! PDE Cache to xbar
//!******************************************
    output logic                  L2PDE_xbar_hit_vld,
    output logic                  L1PDE_xbar_hit_vld,
    output logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
    output logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
    output logic [TYPE_WIDTH-1:0] PDE_xbar_type,
    output logic [ID_WIDTH-1:0]   PDE_xbar_id,
    output logic                  PDE_xbar_req,
			
//input  logic 			twu_cache_stop,
    input  logic                  tlboper_ptw_abort,
    input  logic                  pmp_regs_update,
    input  logic                  xbar_pde_ready,
    output logic                  pde_cache_ready
);

//localparam L1PDE_INDEX_WIDTH = (L1PDE_ENTRY_NUM <= 1) ? 1 : $clog2(L1PDE_ENTRY_NUM);
//localparam L2PDE_INDEX_WIDTH = (L2PDE_ENTRY_NUM <= 1) ? 1 : $clog2(L2PDE_ENTRY_NUM);

logic [VPN_WIDTH-1:0]                      ptw_vpn                ;
logic [TYPE_WIDTH-1:0]                     ptw_type               ;
logic [ID_WIDTH-1:0]                       ptw_id                 ;
logic                                      ptw_req                ;
logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd        ;
logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd        ;
logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn        ;
logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld        ;
logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit        ;
logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn        ;
logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld        ;
logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit        ;
logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn    ;
logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn    ;
logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn      ;
logic                                      L1PDE_entry_hit_vld    ;
logic                                      L2PDE_entry_hit_vld    ;
logic                                      L1PDE_plru_read_hit_vld;
logic                                      L2PDE_plru_read_hit_vld;
logic                                      L1PDE_plru_refill_vld  ;
logic                                      L2PDE_plru_refill_vld  ;
logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit_idx    ;
logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit_idx    ;
//logic [L1PDE_INDEX_WIDTH-1:0]              L1PDE_hit_idx_num      ;
//logic [L2PDE_INDEX_WIDTH-1:0]              L2PDE_hit_idx_num      ;
logic [L1PDE_ENTRY_NUM-1:0]                plru_L1PDE_ref_num     ;
logic [L2PDE_ENTRY_NUM-1:0]                plru_L2PDE_ref_num     ;
logic                                      pde_cache_clk_en       ;
logic                                      pde_cache_clk          ;
logic                                      L1PDE_miss_because_pmp_vld;
logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_miss_because_pmp;
logic [1:0]                                cp0_priv_mode          ;


//assign pde_cache_clk_en = l2tlb_ptw_req | tlboper_ptw_abort | (!xbar_pde_ready);
assign pde_cache_clk_en = 1'b1;

assign cp0_priv_mode[1:0] = cp0_mmu_mprv ? cp0_mmu_mpp[1:0]
                                         : cp0_yy_priv_mode[1:0];


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
		ptw_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		ptw_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};		
	end else if(l2tlb_ptw_req)begin
		ptw_vpn[VPN_WIDTH-1:0] <= l2tlb_ptw_vpn[VPN_WIDTH-1:0];
		ptw_type[TYPE_WIDTH-1:0] <= l2tlb_ptw_type[TYPE_WIDTH-1:0];
		ptw_id[ID_WIDTH-1:0] <= l2tlb_ptw_id[ID_WIDTH-1:0];
	end else begin
		ptw_vpn[VPN_WIDTH-1:0] <= ptw_vpn[VPN_WIDTH-1:0];
		ptw_type[TYPE_WIDTH-1:0] <= ptw_type[TYPE_WIDTH-1:0];
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
//logic [26:0] L1PDE_entry_before_upd_vpn;
logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_before_upd_hit;
//logic [26:0] L2PDE_entry_before_upd_vpn;
logic [L2PDE_ENTRY_NUM-1:0] L2PDE_entry_before_upd_hit;
logic        pde_cache_clear           ;
assign pde_cache_clear = regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update;

generate
	for(genvar L1PDE_ent = 0;L1PDE_ent < L1PDE_ENTRY_NUM;L1PDE_ent = L1PDE_ent + 1)begin:u_L1PDE_ent

		L1PDE_cache #(
		.VPN_WIDTH                      (VPN_WIDTH                  ),
		.PPN_WIDTH                      (PPN_WIDTH                  ),
		.FLG_WIDTH                      (FLG_WIDTH                  ),
		.PGS_WIDTH                      (PGS_WIDTH                  ),
		.PTE_LEVEL                      (PTE_LEVEL                  ),
		.TAG_WIDTH                      (VPN_PERLEL                 ),
		.DATA_WIDTH                     (64                         )
		) u_L1PDE_cache(
		.forever_cpuclk					(forever_cpuclk				),
		.cpurst_b						(cpurst_b					),
        .pad_yy_icg_scan_en             (pad_yy_icg_scan_en         ),
        .cp0_mmu_icg_en                 (cp0_mmu_icg_en             ),
		.regs_ptw_clr					(pde_cache_clear			),
		.cp0_yy_priv_mode				(cp0_yy_priv_mode			),
		.cp0_priv_mode					(cp0_priv_mode				),
	
		.ptw_vpn						(ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)]	),
		.ptw_type						(ptw_type[TYPE_WIDTH-1:0]		),
		.L1PDE_entry_upd				(L1PDE_entry_upd[L1PDE_ent]	),
		.L1PDE_entry_before_upd_vpn	    (mbuf_cache_upd_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)]	),
		.L1PDE_upd_vpn					(mbuf_cache_upd_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)]	),
		.L1PDE_upd_ppn					(mbuf_cache_upd_ppn[PPN_WIDTH-1:0]   ),
		.L1PDE_upd_pmpflg				(mbuf_cache_upd_pmpflg[3:0]   ),
		.L1PDE_entry_before_upd_hit	    (L1PDE_entry_before_upd_hit[L1PDE_ent]	),

		.L1PDE_entry_ppn				(L1PDE_entry_ppn[L1PDE_ent] ),
		.L1PDE_entry_vld				(L1PDE_entry_vld[L1PDE_ent]	),
		.L1PDE_entry_hit                (L1PDE_entry_hit[L1PDE_ent]	),
		.L1PDE_miss_because_pmp         (L1PDE_miss_because_pmp[L1PDE_ent]	)
		);
	end
endgenerate

//L2PDE_cache
generate
	for(genvar L2PDE_ent = 0;L2PDE_ent < L2PDE_ENTRY_NUM;L2PDE_ent = L2PDE_ent + 1)begin:u_L2PDE_ent

		L2PDE_cache #(
		.VPN_WIDTH                      (VPN_WIDTH                  ),
		.PPN_WIDTH                      (PPN_WIDTH                  ),
		.FLG_WIDTH                      (FLG_WIDTH                  ),
		.PGS_WIDTH                      (PGS_WIDTH                  ),
		.PTE_LEVEL                      (PTE_LEVEL                  ),
		.TAG_WIDTH                      (2*VPN_PERLEL               ),
		.DATA_WIDTH                     (64                         )
		) u_L2PDE_cache(
		.forever_cpuclk					(forever_cpuclk				),
		.cpurst_b						(cpurst_b					),
        .pad_yy_icg_scan_en             (pad_yy_icg_scan_en         ),
        .cp0_mmu_icg_en                 (cp0_mmu_icg_en             ),
		.regs_ptw_clr					(pde_cache_clear			),
		.cp0_yy_priv_mode				(cp0_yy_priv_mode			),
		.cp0_priv_mode					(cp0_priv_mode				),
                                                                    
		.ptw_vpn						(ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] 	),
		.ptw_type						(ptw_type[TYPE_WIDTH-1:0]		),
		.L2PDE_entry_upd				(L2PDE_entry_upd[L2PDE_ent] ),
		.L2PDE_entry_before_upd_vpn	    (mbuf_cache_upd_vpn[VPN_WIDTH-1:VPN_PERLEL]	),
		.L2PDE_upd_vpn					(mbuf_cache_upd_vpn[VPN_WIDTH-1:VPN_PERLEL]	),
		.L2PDE_upd_ppn					(mbuf_cache_upd_ppn[PPN_WIDTH-1:0]   ),
		.L2PDE_upd_pmpflg				(mbuf_cache_upd_pmpflg[3:0]   ),
		.L2PDE_entry_before_upd_hit	    (L2PDE_entry_before_upd_hit[L2PDE_ent]	),

		.L2PDE_entry_ppn				(L2PDE_entry_ppn[L2PDE_ent] ),
		.L2PDE_entry_vld				(L2PDE_entry_vld[L2PDE_ent]	),
		.L2PDE_entry_hit                (L2PDE_entry_hit[L2PDE_ent]	)
		);
	end
endgenerate

//==============================================================================
//                   HIT OUTPUT
//==============================================================================
assign L1PDE_entry_hit_idx[L1PDE_ENTRY_NUM-1:0] = (L1PDE_entry_vld[L1PDE_ENTRY_NUM-1:0] & L1PDE_entry_hit[L1PDE_ENTRY_NUM-1:0]);
assign L1PDE_entry_hit_vld = (|L1PDE_entry_hit_idx[L1PDE_ENTRY_NUM-1:0]) ;
assign L1PDE_miss_because_pmp_vld = (|L1PDE_miss_because_pmp[L1PDE_ENTRY_NUM-1:0]);

assign L2PDE_entry_hit_idx[L2PDE_ENTRY_NUM-1:0] = (L2PDE_entry_vld[L2PDE_ENTRY_NUM-1:0] & L2PDE_entry_hit[L2PDE_ENTRY_NUM-1:0]);
assign L2PDE_entry_hit_vld = (|L2PDE_entry_hit_idx[L2PDE_ENTRY_NUM-1:0]) & (~L1PDE_miss_because_pmp_vld);


always_comb begin
	L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
	for(int i = 0; i < L1PDE_ENTRY_NUM; i = i + 1) begin
		if(L1PDE_entry_hit_idx[i])
			L1PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L1PDE_entry_ppn[i][PPN_WIDTH-1:0];
	end
end

always_comb begin
	L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
	for(int i = 0; i < L2PDE_ENTRY_NUM; i = i + 1) begin
		if(L2PDE_entry_hit_idx[i])
			L2PDE_cache_hit_ppn[PPN_WIDTH-1:0] = L2PDE_entry_ppn[i][PPN_WIDTH-1:0];
	end
end

always_comb begin
	casez({L2PDE_entry_hit_vld,L1PDE_entry_hit_vld})
		2'b01 : PDE_cache_fin_ppn[PPN_WIDTH-1:0] = L1PDE_cache_hit_ppn[PPN_WIDTH-1:0];
		2'b1? : PDE_cache_fin_ppn[PPN_WIDTH-1:0] = L2PDE_cache_hit_ppn[PPN_WIDTH-1:0];
		default: PDE_cache_fin_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
	endcase
end

//always_comb begin
//	L1PDE_hit_idx_num[L1PDE_INDEX_WIDTH-1:0] = {L1PDE_INDEX_WIDTH{1'b0}};
//	for(int i = 0; i < L1PDE_ENTRY_NUM; i = i + 1) begin
//		if(L1PDE_entry_h//it_idx[i])
//			L1PDE_hit_idx_num[L1PDE_INDEX_WIDTH-1:0] = i;
//	end
//end

//always_comb begin
//	L2PDE_hit_idx_num[L2PDE_INDEX_WIDTH-1:0] = {L2PDE_INDEX_WIDTH{1'b0}};
//	for(int i = 0; i < L2PDE_ENTRY_NUM; i = i + 1) begin
//		if(L2PDE_entry_hit_idx[i])
//			L2PDE_hit_idx_num[L2PDE_INDEX_WIDTH-1:0] = i;
//	end
//end

//==============================================================================
//                  refill  LRU
//==============================================================================
assign L1PDE_plru_read_hit_vld = L1PDE_entry_hit_vld;
assign L2PDE_plru_read_hit_vld = L2PDE_entry_hit_vld;

assign L1PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[1] & (!(|L1PDE_entry_before_upd_hit[L1PDE_ENTRY_NUM-1:0])));
assign L2PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[0] & (!(|L2PDE_entry_before_upd_hit[L2PDE_ENTRY_NUM-1:0])));

pplru #(
.PDE_ENTRY_NUM                     (L1PDE_ENTRY_NUM    )
) u_L1PDE_cache_pplru(
.forever_cpuclk					(forever_cpuclk			),               
.cpurst_b						(cpurst_b				),
.pad_yy_icg_scan_en             (pad_yy_icg_scan_en     ),
.cp0_mmu_icg_en                 (cp0_mmu_icg_en         ),
.PDE_plru_read_vld				(L1PDE_entry_vld        ),
.PDE_plru_read_hit				(L1PDE_entry_hit        ),
.PDE_plru_read_hit_vld			(L1PDE_plru_read_hit_vld),   
.PDE_plru_refill_vld			(L1PDE_plru_refill_vld	),  

.plru_PDE_ref_num  				(plru_L1PDE_ref_num		)
);

pplru #(
.PDE_ENTRY_NUM                     (L2PDE_ENTRY_NUM    )
) u_L2PDE_cache_pplru(
.forever_cpuclk					(forever_cpuclk			),                 
.cpurst_b						(cpurst_b				),
.pad_yy_icg_scan_en             (pad_yy_icg_scan_en     ),
.cp0_mmu_icg_en                 (cp0_mmu_icg_en         ),
.PDE_plru_read_vld				(L2PDE_entry_vld        ),
.PDE_plru_read_hit				(L2PDE_entry_hit        ),
.PDE_plru_read_hit_vld			(L2PDE_plru_read_hit_vld),    
.PDE_plru_refill_vld			(L2PDE_plru_refill_vld	),  

.plru_PDE_ref_num  				(plru_L2PDE_ref_num		)
);

assign L1PDE_entry_upd[L1PDE_ENTRY_NUM-1:0] = plru_L1PDE_ref_num[L1PDE_ENTRY_NUM-1:0] & {L1PDE_ENTRY_NUM{L1PDE_plru_refill_vld}};
assign L2PDE_entry_upd[L2PDE_ENTRY_NUM-1:0] = plru_L2PDE_ref_num[L2PDE_ENTRY_NUM-1:0] & {L2PDE_ENTRY_NUM{L2PDE_plru_refill_vld}};




//==============================================================================
//                   OUTPUT
//==============================================================================

assign L2PDE_xbar_hit_vld = L2PDE_entry_hit_vld;
assign L1PDE_xbar_hit_vld = L1PDE_entry_hit_vld & (~L2PDE_entry_hit_vld);
assign PDE_xbar_ppn[PPN_WIDTH-1:0] = PDE_cache_fin_ppn[PPN_WIDTH-1:0];
assign PDE_xbar_vpn[VPN_WIDTH-1:0] = ptw_vpn[VPN_WIDTH-1:0];
assign PDE_xbar_type[TYPE_WIDTH-1:0] = ptw_type[TYPE_WIDTH-1:0];
assign PDE_xbar_id[ID_WIDTH-1:0] = ptw_id[ID_WIDTH-1:0];
// Keep PDE_xbar_req as the registered pending valid.  xbar_pde_ready is the
// handshake response from one_to_four_xbar; gating valid by ready creates a
// combinational loop because the xbar computes ready from this valid plus
// twu_mask.  ptw_req is held while !xbar_pde_ready above, so the request stays
// stable until accepted.
assign PDE_xbar_req = ptw_req;

// Trace PDE cache hit details for run_check post-log analysis.
//always_ff @(posedge pde_cache_clk or negedge cpurst_b) begin
//	if(!cpurst_b) begin
//		// no-op
//	end else if(PDE_xbar_req && xbar_pde_ready && L2PDE_xbar_hit_vld) begin
//		$display("[%0t][PDE CACHE HIT] lvl=L2 req_vpn=0x%07h tag=0x%05h hit_idx=%0d hit_vec=0x%04h out_ppn=0x%07h",
//		         $time, PDE_xbar_vpn, PDE_xbar_vpn[VPN_WIDTH-1:VPN_PERLEL], L2PDE_hit_idx_num, L2PDE_entry_hit_idx, PDE_xbar_ppn);
//	end else if(PDE_xbar_req && xbar_pde_ready && L1PDE_xbar_hit_vld) begin
//		$display("[%0t][PDE CACHE HIT] lvl=L1 req_vpn=0x%07h tag=0x%03h hit_idx=%0d hit_vec=0x%04h out_ppn=0x%07h",
//		         $time, PDE_xbar_vpn, PDE_xbar_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)], L1PDE_hit_idx_num, L1PDE_entry_hit_idx, PDE_xbar_ppn);
//	end
//end


endmodule


