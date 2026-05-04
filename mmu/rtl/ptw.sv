module ptw(
//!******************************************
//! Clock and Reset
//!******************************************
input logic 			forever_cpuclk,
input logic 			cpurst_b,

//!******************************************
//! System Regs
//!******************************************
input  logic         	cp0_mmu_icg_en,       
input  logic         	cp0_mmu_maee,         
input  logic [1 :0]  	cp0_mmu_mpp,          
input  logic         	cp0_mmu_mprv,         
input  logic         	cp0_mmu_mxr,          
input  logic         	cp0_mmu_sum,          
input  logic [1 :0]  	cp0_yy_priv_mode,     
input  logic         	pad_yy_icg_scan_en,
input  logic            hpcp_mmu_cnt_en,
	
input  logic [15:0]  	regs_ptw_cur_asid,
input  logic [27:0]  	regs_ptw_satp_ppn,
input  logic  	     	regs_ptw_clr,

//!******************************************
//! Systemmap <=> ptw
//!******************************************
input  logic [4 :0]	 	sysmap_mmu_flg3,
//input  logic [4 :0]	 	sysmap_mmu_flg4,
input  logic [4 :0]	 	sysmap_mmu_flg5,
input  logic [4 :0]	 	sysmap_mmu_flg6,
input  logic [4 :0]	 	sysmap_mmu_flg7,

input  logic [7 :0]	 	sysmap_mmu_hit3,
//input  logic [7 :0]	 	sysmap_mmu_hit4,
input  logic [7 :0]	 	sysmap_mmu_hit5,
input  logic [7 :0]	 	sysmap_mmu_hit6,	
input  logic [7 :0]	 	sysmap_mmu_hit7,

output logic [27:0]	 	mmu_sysmap_pa3,
//output logic [27:0]	 	mmu_sysmap_pa4,
output logic [27:0]	 	mmu_sysmap_pa5,
output logic [27:0]	 	mmu_sysmap_pa6,
output logic [27:0]	 	mmu_sysmap_pa7,

//!******************************************
//! PMP <=> ptw
//!******************************************
input  logic [3 :0]	 	pmp_mmu_flg3,
//input  logic [3 :0]	 	pmp_mmu_flg4,
input  logic [3 :0]	 	pmp_mmu_flg7,
input  logic [3 :0]	 	pmp_mmu_flg5,
input  logic [3 :0]	 	pmp_mmu_flg6,
	
output logic [27:0]	 	mmu_pmp_pa3,
//output logic [27:0]	 	mmu_pmp_pa4,
output logic [27:0]	 	mmu_pmp_pa7,
output logic [27:0]	 	mmu_pmp_pa5,
output logic [27:0]	 	mmu_pmp_pa6,
output logic  		 	mmu_pmp_fetch3,
//output logic  		 	mmu_pmp_fetch4,
output logic  		 	mmu_pmp_fetch7,
output logic  		 	mmu_pmp_fetch5,
output logic  		 	mmu_pmp_fetch6,

//!******************************************
//! L2TLB Request
//!******************************************
input  logic 		 	l2tlb_ptw_req,
input  logic [2:0]	 	l2tlb_ptw_type,
input  logic [26:0]	 	l2tlb_ptw_vpn,
input  logic [5:0]	 	l2tlb_ptw_id,

//!******************************************
//! LSU <=> PTW
//!******************************************
input  logic		 	lsu_mmu_bus_error,
input  logic [63:0]	 	lsu_mmu_data,
input  logic		 	lsu_mmu_data_vld,
	
	
output logic 		 	mmu_lsu_data_req,
output logic [39:0]	 	mmu_lsu_data_req_addr,
output logic 		 	mmu_lsu_data_req_size,

//!******************************************
//! Refill
//!******************************************
input  logic 		 	arb_ptw_grant,
input  logic 		 	arb_ptw_mask,

output logic [26:0]		ptw_arb_vpn,	
output logic 		 	ptw_arb_req,
output logic [41:0]	 	ptw_arb_ref_data_din,
output logic [47:0]	 	ptw_arb_ref_tag_din,
output logic [2:0]	 	ptw_arb_ref_pgs,

// to l1tlb
output logic 			ptw_l1dtlb_ref_pa_vld,
output logic [26:0]		ptw_l1dtlb_ref_vpn,  
output logic [2:0]		ptw_l1dtlb_ref_pgs,  
output logic [27:0]		ptw_l1dtlb_ref_ppn,  
output logic [13:0]		ptw_l1dtlb_ref_flg,
output logic [5:0]  	ptw_l1tlb_id,
output logic            ptw_l1dtlb_cmplt,
output logic            ptw_l1dtlb_pgflt,
output logic 			ptw_l1dtlb_ref_acc_err,  

output logic 			ptw_l1itlb_ref_pa_vld,
output logic [26:0]		ptw_l1itlb_ref_vpn,  
output logic [2:0]		ptw_l1itlb_ref_pgs,  
output logic [27:0]		ptw_l1itlb_ref_ppn,  
output logic [13:0]		ptw_l1itlb_ref_flg,
output logic            ptw_l1itlb_cmplt,
output logic            ptw_l1itlb_pgflt,
output logic 			ptw_l1itlb_ref_acc_err,
//!******************************************
//! Fault to L2TLB
//!******************************************
output logic 			ptw_l2tlb_ref_acc_err,
output logic 			ptw_l2tlb_ref_pgflt,
output logic        	ptw_l2tlb_ref_data_vld,
output logic        	ptw_l2tlb_cmplt,
output logic [2:0]  	ptw_l2tlb_type,    
output logic [5:0]  	ptw_l2tlb_id,
output logic [13:0]     ptw_l2tlb_flg,
        
output logic 			ptw_jtlb_ready,
input  logic  	     	tlboper_ptw_abort,
//output logic            ptw_top_imiss,
output logic            mmu_hpcp_jtlb_miss

);


logic                   pde_cache_ready             ;
logic					mbuf_cache_upd			    ;
logic	[1:0]			mbuf_cache_upd_lvl	        ;
logic	[27:0]			mbuf_cache_upd_ppn	        ;
logic	[26:0]			mbuf_cache_upd_vpn	        ;
logic					L2PDE_xbar_hit_vld		    ;
logic					L1PDE_xbar_hit_vld		    ;
logic	[27:0]			PDE_xbar_ppn			    ;
logic	[26:0]			PDE_xbar_vpn			    ;
logic	[2:0]			PDE_xbar_type			    ;
logic	[5:0]			PDE_xbar_id			        ;
logic					PDE_xbar_req			    ;
logic					twu_cache_stop			    ;
//logic	[3:0]			twu_idle				    ;
logic	[3:0]			xbar_twu_req		        ;
logic	[1:0]			xbar_twu_hit_level		    ;
logic	[27:0]			xbar_twu_ppn			    ;
logic	[26:0]			xbar_twu_vpn			    ;
logic	[2:0]			xbar_twu_type			    ;
logic	[5:0]			xbar_twu_id			        ;
logic	[3:0]			refill_arb_twu_grant		;
logic	[26:0]			mbuf_twu_vpn			    ;
logic	[2:0]			mbuf_twu_type			    ;
logic	[5:0]			mbuf_twu_id			        ;
logic   [2:0]			mbuf_twu_lvl				;
logic	[63:0]			mbuf_twu_data			    ;
logic	[3:0]			mbuf_twu_data_vld	     	;
logic	[3:0]			mbuf_grant			     	;
logic	[3:0]			twu_mbuf_req			    ;
logic	[3:0][39:0]		twu_mbuf_paddr			 	;
logic	[3:0][26:0]		twu_mbuf_vpn			    ;
logic	[3:0][2:0]		twu_mbuf_type			 	;
logic	[3:0][5:0]		twu_mbuf_id				 	;
logic	[3:0][2:0]		twu_mbuf_lvl			    ;
logic	[3:0][3:0]		twu_mbuf_twu_idx		    ;
logic	[3:0]			twu_mbuf_mask				;
logic	[3:0]			twu_arb_ref_req			 	;
logic	[3:0][41:0]		twu_arb_ref_data_din	    ;
logic	[3:0][47:0]		twu_arb_ref_tag_din			;
logic	[3:0][2:0]		twu_arb_ref_pgs			 	;
logic	[3:0][2:0]		twu_arb_ref_type		 	;
logic	[3:0][5:0]		twu_arb_ref_id			 	;
logic	[3:0]			twu_l2tlb_ref_pgflt		 	;
logic	[3:0][5:0]		twu_l2tlb_ref_pgflt_id	 	;
logic	[3:0][2:0]		twu_l2tlb_ref_pgflt_type 	;
logic	[3:0]			twu_l2tlb_ref_acc_err	 	;
logic	[3:0][2:0]		twu_l2tlb_ref_acc_err_type	;
logic	[3:0][5:0]		twu_l2tlb_ref_acc_err_id	;
//logic	[3:0]			mbuf_twu_have           	;
logic	[4:0]			acc_err_twu_grant			;
logic	[3:0]			pgflt_twu_grant				;
logic					mbuf_entry_on_vld			;
logic					fst_twu_itlb_sel			;
logic					scd_twu_itlb_sel			;
logic					thd_twu_itlb_sel			;
logic					fth_twu_itlb_sel			;
logic					ref_itlb_sel				;
logic	[3:0]			refill_arb_grant			;	
logic					abort_flop					;
logic   [3:0]			twu_mask					;
logic   				mbuf_bus_error				;
logic   [2:0]			mbuf_bus_error_type			;
logic	[5:0]			mbuf_bus_error_id			;
logic   [3:0]           twu_pgflt_sel               ;
logic   [4:0]           twu_acc_err_sel             ;
logic   [3:0]           twu_ref_sel                 ;
logic   [3:0][2:0]      twu_data_ready              ;
logic					pgflt_vld					;
logic					acc_err_vld					;
logic					ref_vld						;
logic					pgflt_grant					;
logic					acc_err_rant				;
logic					ref_rant					;
logic                   l2tlb_miss                  ;
logic                   l2tlb_miss_cnt              ;


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

assign ptw_clk_en = 1'b1; 
// &Instance("gated_clk_cell", "x_ptw_gateclk"); @59
gated_clk_cell  x_ptw_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (ptw_clk           ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (ptw_clk_en        ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//assign ptw_stop = &twu_mask[3:0];
assign ptw_jtlb_ready = pde_cache_ready & (!abort_flop);

always_ff @(posedge ptw_clk or negedge cpurst_b)begin
    if(!cpurst_b)
		abort_flop <= 1'b0;
    else if(mbuf_entry_on_vld & tlboper_ptw_abort & !(lsu_mmu_bus_error | lsu_mmu_data_vld))
		abort_flop <= 1'b1;
    else if(abort_flop & (lsu_mmu_bus_error | lsu_mmu_data_vld))
		abort_flop <= 1'b0;
end



PDE_cache	u_PDE_cache(
.forever_cpuclk						(forever_cpuclk		),
.cpurst_b							(cpurst_b			),
.cp0_mmu_icg_en                     (cp0_mmu_icg_en     ),
.pad_yy_icg_scan_en                 (pad_yy_icg_scan_en ),
				
.l2tlb_ptw_vpn						(l2tlb_ptw_vpn		),
.l2tlb_ptw_type						(l2tlb_ptw_type		),
.l2tlb_ptw_id						(l2tlb_ptw_id		),
.l2tlb_ptw_req						(l2tlb_ptw_req		),
						
.mbuf_cache_upd						(mbuf_cache_upd		),
.mbuf_cache_upd_lvl					(mbuf_cache_upd_lvl	),
.mbuf_cache_upd_ppn					(mbuf_cache_upd_ppn	),
.mbuf_cache_upd_vpn					(mbuf_cache_upd_vpn	),
							
.regs_ptw_clr						(regs_ptw_clr		),
						
.L2PDE_xbar_hit_vld					(L2PDE_xbar_hit_vld	),
.L1PDE_xbar_hit_vld					(L1PDE_xbar_hit_vld	),
.PDE_xbar_ppn						(PDE_xbar_ppn		),
.PDE_xbar_vpn						(PDE_xbar_vpn		),
.PDE_xbar_type						(PDE_xbar_type		),
.PDE_xbar_id						(PDE_xbar_id		),
.PDE_xbar_req						(PDE_xbar_req		),
			
//.twu_cache_stop						(twu_cache_stop		),
.tlboper_ptw_abort					(tlboper_ptw_abort	),
.xbar_pde_ready						(xbar_pde_ready		),
.pde_cache_ready                    (pde_cache_ready    )
);

one_to_four_xbar  u_one_to_four_xbar(
.forever_cpuclk						(forever_cpuclk		),
.cpurst_b							(cpurst_b			),
									
//.twu_idle							(twu_idle			),
.twu_mask							(twu_mask			),
									
.PDE_xbar_req						(PDE_xbar_req		),
.L2PDE_xbar_hit_vld					(L2PDE_xbar_hit_vld	),
.L1PDE_xbar_hit_vld					(L1PDE_xbar_hit_vld	),
.PDE_xbar_ppn						(PDE_xbar_ppn		),
.PDE_xbar_vpn						(PDE_xbar_vpn		),
.PDE_xbar_type						(PDE_xbar_type		),
.PDE_xbar_id						(PDE_xbar_id		),
									
.xbar_twu_req						(xbar_twu_req[3:0]	),
.xbar_twu_hit_level					(xbar_twu_hit_level	),
.xbar_twu_ppn						(xbar_twu_ppn		),
.xbar_twu_vpn						(xbar_twu_vpn		),
.xbar_twu_type						(xbar_twu_type		),
.xbar_twu_id						(xbar_twu_id		),
.tlboper_ptw_abort					(tlboper_ptw_abort	),
.xbar_pde_ready						(xbar_pde_ready		)

);


twu twu_one(
.forever_cpuclk						(forever_cpuclk					),
.cpurst_b							(cpurst_b						),
.twu_idx							(4'b0001						),
.refill_arb_twu_grant				(refill_arb_twu_grant[0]		),
										
.cp0_mmu_icg_en						(cp0_mmu_icg_en					),       
.cp0_mmu_maee						(cp0_mmu_maee					),         
.cp0_mmu_mpp						(cp0_mmu_mpp					),          
.cp0_mmu_mprv						(cp0_mmu_mprv					),         
.cp0_mmu_mxr						(cp0_mmu_mxr					),          
.cp0_mmu_sum						(cp0_mmu_sum					),          
.cp0_yy_priv_mode					(cp0_yy_priv_mode				),     
.pad_yy_icg_scan_en					(pad_yy_icg_scan_en				),
                                     
.regs_ptw_cur_asid					(regs_ptw_cur_asid				),
.regs_ptw_satp_ppn					(regs_ptw_satp_ppn				),
										
.xbar_twu_req						(xbar_twu_req[0]				),
.xbar_twu_hit_level					(xbar_twu_hit_level				),
.xbar_twu_ppn						(xbar_twu_ppn					),
.xbar_twu_vpn						(xbar_twu_vpn					),
.xbar_twu_type						(xbar_twu_type					),
.xbar_twu_id						(xbar_twu_id					),
										
.mbuf_twu_vpn						(mbuf_twu_vpn					),
.mbuf_twu_type						(mbuf_twu_type					),
	
.mbuf_twu_id						(mbuf_twu_id					),
.mbuf_twu_lvl						(mbuf_twu_lvl					),
.mbuf_twu_data						(mbuf_twu_data					),
.mbuf_twu_data_vld					(mbuf_twu_data_vld[0]			),
.mbuf_grant							(mbuf_grant[0]					),
										
.sysmap_mmu_flg						(sysmap_mmu_flg3				),
.sysmap_mmu_hit						(sysmap_mmu_hit3				),
.pmp_mmu_flg						(pmp_mmu_flg3					),
										
.tlboper_ptw_abort					(tlboper_ptw_abort				),
										
.twu_mbuf_req						(twu_mbuf_req[0]				),
.twu_mbuf_paddr						(twu_mbuf_paddr[0]				),
.twu_mbuf_vpn						(twu_mbuf_vpn[0]				),
.twu_mbuf_type						(twu_mbuf_type[0]				),
.twu_mbuf_id						(twu_mbuf_id[0]					),
.twu_mbuf_lvl						(twu_mbuf_lvl[0]				),
.twu_mbuf_twu_idx					(twu_mbuf_twu_idx[0]			),
//.twu_mbuf_mask						(twu_mbuf_mask[0]				),
										
.mmu_pmp_pa							(mmu_pmp_pa3					),
.mmu_pmp_fecth						(mmu_pmp_fecth3					),
.mmu_sysmap_pa						(mmu_sysmap_pa3					),
										
.twu_arb_ref_req					(twu_arb_ref_req[0]				),
.twu_arb_ref_data_din				(twu_arb_ref_data_din[0]		),
.twu_arb_ref_tag_din				(twu_arb_ref_tag_din[0]			),
.twu_arb_ref_pgs					(twu_arb_ref_pgs[0]				),
.twu_arb_ref_type					(twu_arb_ref_type[0]			),
.twu_arb_ref_id						(twu_arb_ref_id[0]				),
                                     
.twu_l2tlb_ref_pgflt				(twu_l2tlb_ref_pgflt[0]			),
.twu_l2tlb_ref_pgflt_id				(twu_l2tlb_ref_pgflt_id[0]		),
.twu_l2tlb_ref_pgflt_type			(twu_l2tlb_ref_pgflt_type[0]	),
.twu_l2tlb_ref_acc_err				(twu_l2tlb_ref_acc_err[0]		),
.twu_l2tlb_ref_acc_err_type			(twu_l2tlb_ref_acc_err_type[0]	),
.twu_l2tlb_ref_acc_err_id			(twu_l2tlb_ref_acc_err_id[0]	),
                                     
.twu_mask							(twu_mask[0]					),
//.twu_idle							(twu_idle[0]					),
.twu_data_ready                     (twu_data_ready[0][2:0]     	),
//.mbuf_twu_have                      (mbuf_twu_have[0]           	),
.acc_err_twu_grant                  (acc_err_twu_grant[0]			),
.pgflt_twu_grant                    (pgflt_twu_grant[0]  			)
);


twu twu_two(
.forever_cpuclk						(forever_cpuclk					),
.cpurst_b							(cpurst_b						),
.twu_idx							(4'b0010						),
.refill_arb_twu_grant				(refill_arb_twu_grant[1]		),
										
.cp0_mmu_icg_en						(cp0_mmu_icg_en					),       
.cp0_mmu_maee						(cp0_mmu_maee					),         
.cp0_mmu_mpp						(cp0_mmu_mpp					),          
.cp0_mmu_mprv						(cp0_mmu_mprv					),         
.cp0_mmu_mxr						(cp0_mmu_mxr					),          
.cp0_mmu_sum						(cp0_mmu_sum					),          
.cp0_yy_priv_mode					(cp0_yy_priv_mode				),     
.pad_yy_icg_scan_en					(pad_yy_icg_scan_en				),
										
.regs_ptw_cur_asid					(regs_ptw_cur_asid				),
.regs_ptw_satp_ppn					(regs_ptw_satp_ppn				),
										
.xbar_twu_req						(xbar_twu_req[1]				),
.xbar_twu_hit_level					(xbar_twu_hit_level				),
.xbar_twu_ppn						(xbar_twu_ppn					),
.xbar_twu_vpn						(xbar_twu_vpn					),
.xbar_twu_type						(xbar_twu_type					),
.xbar_twu_id						(xbar_twu_id					),
										
.mbuf_twu_vpn						(mbuf_twu_vpn					),
.mbuf_twu_type						(mbuf_twu_type					),
.mbuf_twu_id						(mbuf_twu_id					),
.mbuf_twu_lvl						(mbuf_twu_lvl					),
.mbuf_twu_data						(mbuf_twu_data					),
.mbuf_twu_data_vld					(mbuf_twu_data_vld[1]			),
.mbuf_grant							(mbuf_grant[1]					),
										
.sysmap_mmu_flg						(sysmap_mmu_flg5				),
.sysmap_mmu_hit						(sysmap_mmu_hit5				),
.pmp_mmu_flg						(pmp_mmu_flg5					),
										
.tlboper_ptw_abort					(tlboper_ptw_abort				),
										
.twu_mbuf_req						(twu_mbuf_req[1]				),
.twu_mbuf_paddr						(twu_mbuf_paddr[1]				),
.twu_mbuf_vpn						(twu_mbuf_vpn[1]				),
.twu_mbuf_type						(twu_mbuf_type[1]				),
.twu_mbuf_id						(twu_mbuf_id[1]					),
.twu_mbuf_lvl						(twu_mbuf_lvl[1]				),
.twu_mbuf_twu_idx					(twu_mbuf_twu_idx[1]			),
//.twu_mbuf_mask						(twu_mbuf_mask[1]				),
										
.mmu_pmp_pa							(mmu_pmp_pa5					),
.mmu_pmp_fecth						(mmu_pmp_fecth5					),
.mmu_sysmap_pa						(mmu_sysmap_pa5					),
										
.twu_arb_ref_req					(twu_arb_ref_req[1]				),
.twu_arb_ref_data_din				(twu_arb_ref_data_din[1]		),
.twu_arb_ref_tag_din				(twu_arb_ref_tag_din[1]			),
.twu_arb_ref_pgs					(twu_arb_ref_pgs[1]				),
.twu_arb_ref_type					(twu_arb_ref_type[1]			),
.twu_arb_ref_id						(twu_arb_ref_id[1]				),
                                     
.twu_l2tlb_ref_pgflt				(twu_l2tlb_ref_pgflt[1]			),
.twu_l2tlb_ref_pgflt_id				(twu_l2tlb_ref_pgflt_id[1]		),
.twu_l2tlb_ref_pgflt_type			(twu_l2tlb_ref_pgflt_type[1]	),
.twu_l2tlb_ref_acc_err				(twu_l2tlb_ref_acc_err[1]		),
.twu_l2tlb_ref_acc_err_type			(twu_l2tlb_ref_acc_err_type[1]	),
.twu_l2tlb_ref_acc_err_id			(twu_l2tlb_ref_acc_err_id[1]	),
                                     
.twu_mask							(twu_mask[1]					),
//.twu_idle							(twu_idle[1]					),
.twu_data_ready                     (twu_data_ready[1][2:0]     	),
//.mbuf_twu_have                      (mbuf_twu_have[1]           	),
.acc_err_twu_grant                  (acc_err_twu_grant[1]       	),
.pgflt_twu_grant                    (pgflt_twu_grant[1]         	)


);


twu twu_three(
.forever_cpuclk						(forever_cpuclk					),
.cpurst_b							(cpurst_b						),
.twu_idx							(4'b0100						),
.refill_arb_twu_grant				(refill_arb_twu_grant[2]		),
										
.cp0_mmu_icg_en						(cp0_mmu_icg_en					),       
.cp0_mmu_maee						(cp0_mmu_maee					),         
.cp0_mmu_mpp						(cp0_mmu_mpp					),          
.cp0_mmu_mprv						(cp0_mmu_mprv					),         
.cp0_mmu_mxr						(cp0_mmu_mxr					),          
.cp0_mmu_sum						(cp0_mmu_sum					),          
.cp0_yy_priv_mode					(cp0_yy_priv_mode				),     
.pad_yy_icg_scan_en					(pad_yy_icg_scan_en				),
										
.regs_ptw_cur_asid					(regs_ptw_cur_asid				),
.regs_ptw_satp_ppn					(regs_ptw_satp_ppn				),
										
.xbar_twu_req						(xbar_twu_req[2]				),
.xbar_twu_hit_level					(xbar_twu_hit_level				),
.xbar_twu_ppn						(xbar_twu_ppn					),
.xbar_twu_vpn						(xbar_twu_vpn					),
.xbar_twu_type						(xbar_twu_type					),
.xbar_twu_id						(xbar_twu_id					),
										
.mbuf_twu_vpn						(mbuf_twu_vpn					),
.mbuf_twu_type						(mbuf_twu_type					),
.mbuf_twu_id						(mbuf_twu_id					),
.mbuf_twu_lvl						(mbuf_twu_lvl					),
.mbuf_twu_data						(mbuf_twu_data					),
.mbuf_twu_data_vld					(mbuf_twu_data_vld[2]			),
.mbuf_grant							(mbuf_grant[2]					),
										
.sysmap_mmu_flg						(sysmap_mmu_flg6				),
.sysmap_mmu_hit						(sysmap_mmu_hit6				),
.pmp_mmu_flg						(pmp_mmu_flg6					),
										
.tlboper_ptw_abort					(tlboper_ptw_abort				),
										
.twu_mbuf_req						(twu_mbuf_req[2]				),
.twu_mbuf_paddr						(twu_mbuf_paddr[2]				),
.twu_mbuf_vpn						(twu_mbuf_vpn[2]				),
.twu_mbuf_type						(twu_mbuf_type[2]				),
.twu_mbuf_id						(twu_mbuf_id[2]					),
.twu_mbuf_lvl						(twu_mbuf_lvl[2]				),
.twu_mbuf_twu_idx					(twu_mbuf_twu_idx[2]			),
//.twu_mbuf_mask						(twu_mbuf_mask[2]				),
										
.mmu_pmp_pa							(mmu_pmp_pa6					),
.mmu_pmp_fecth						(mmu_pmp_fecth6					),
.mmu_sysmap_pa						(mmu_sysmap_pa6					),
										
.twu_arb_ref_req					(twu_arb_ref_req[2]				),
.twu_arb_ref_data_din				(twu_arb_ref_data_din[2]		),
.twu_arb_ref_tag_din				(twu_arb_ref_tag_din[2]			),
.twu_arb_ref_pgs					(twu_arb_ref_pgs[2]				),
.twu_arb_ref_type					(twu_arb_ref_type[2]			),
.twu_arb_ref_id						(twu_arb_ref_id[2]				),
										
.twu_l2tlb_ref_pgflt				(twu_l2tlb_ref_pgflt[2]			),
.twu_l2tlb_ref_pgflt_id				(twu_l2tlb_ref_pgflt_id[2]		),
.twu_l2tlb_ref_pgflt_type			(twu_l2tlb_ref_pgflt_type[2]	),
.twu_l2tlb_ref_acc_err				(twu_l2tlb_ref_acc_err[2]		),
.twu_l2tlb_ref_acc_err_type			(twu_l2tlb_ref_acc_err_type[2]	),
.twu_l2tlb_ref_acc_err_id			(twu_l2tlb_ref_acc_err_id[2]	),
                                     
.twu_mask							(twu_mask[2]					),
//.twu_idle							(twu_idle[2]					),
.twu_data_ready                     (twu_data_ready[2][2:0]     	),
//.mbuf_twu_have                      (mbuf_twu_have[2]           	),

.acc_err_twu_grant                  (acc_err_twu_grant[2]           ),
.pgflt_twu_grant                    (pgflt_twu_grant[2]             )
);


twu twu_four(
.forever_cpuclk						(forever_cpuclk					),
.cpurst_b							(cpurst_b						),
.twu_idx							(4'b1000						),
.refill_arb_twu_grant				(refill_arb_twu_grant[3]		),
                                     
.cp0_mmu_icg_en						(cp0_mmu_icg_en					),       
.cp0_mmu_maee						(cp0_mmu_maee					),         
.cp0_mmu_mpp						(cp0_mmu_mpp					),          
.cp0_mmu_mprv						(cp0_mmu_mprv					),         
.cp0_mmu_mxr						(cp0_mmu_mxr					),          
.cp0_mmu_sum						(cp0_mmu_sum					),          
.cp0_yy_priv_mode					(cp0_yy_priv_mode				),     
.pad_yy_icg_scan_en					(pad_yy_icg_scan_en				),
										
.regs_ptw_cur_asid					(regs_ptw_cur_asid				),
.regs_ptw_satp_ppn					(regs_ptw_satp_ppn				),
										
.xbar_twu_req						(xbar_twu_req[3]				),
.xbar_twu_hit_level					(xbar_twu_hit_level				),
.xbar_twu_ppn						(xbar_twu_ppn					),
.xbar_twu_vpn						(xbar_twu_vpn					),
.xbar_twu_type						(xbar_twu_type					),
.xbar_twu_id						(xbar_twu_id					),
										
.mbuf_twu_vpn						(mbuf_twu_vpn					),
.mbuf_twu_type						(mbuf_twu_type					),
.mbuf_twu_id						(mbuf_twu_id					),
.mbuf_twu_lvl						(mbuf_twu_lvl					),
.mbuf_twu_data						(mbuf_twu_data					),
.mbuf_twu_data_vld					(mbuf_twu_data_vld[3]			),
.mbuf_grant							(mbuf_grant[3]					),
										
.sysmap_mmu_flg						(sysmap_mmu_flg7				),
.sysmap_mmu_hit						(sysmap_mmu_hit7				),
.pmp_mmu_flg						(pmp_mmu_flg7					),
										
.tlboper_ptw_abort					(tlboper_ptw_abort				),
										
.twu_mbuf_req						(twu_mbuf_req[3]				),
.twu_mbuf_paddr						(twu_mbuf_paddr[3]				),
.twu_mbuf_vpn						(twu_mbuf_vpn[3]				),
.twu_mbuf_type						(twu_mbuf_type[3]				),
.twu_mbuf_id						(twu_mbuf_id[3]					),
.twu_mbuf_lvl						(twu_mbuf_lvl[3]				),
.twu_mbuf_twu_idx					(twu_mbuf_twu_idx[3]			),
//.twu_mbuf_mask						(twu_mbuf_mask[3]				),
										
.mmu_pmp_pa							(mmu_pmp_pa7					),
.mmu_pmp_fecth						(mmu_pmp_fecth7					),
.mmu_sysmap_pa						(mmu_sysmap_pa7					),
										
.twu_arb_ref_req					(twu_arb_ref_req[3]				),
.twu_arb_ref_data_din				(twu_arb_ref_data_din[3]		),
.twu_arb_ref_tag_din				(twu_arb_ref_tag_din[3]			),
.twu_arb_ref_pgs					(twu_arb_ref_pgs[3]				),
.twu_arb_ref_type					(twu_arb_ref_type[3]			),
.twu_arb_ref_id						(twu_arb_ref_id[3]				),
										
.twu_l2tlb_ref_pgflt				(twu_l2tlb_ref_pgflt[3]			),
.twu_l2tlb_ref_pgflt_id				(twu_l2tlb_ref_pgflt_id[3]		),
.twu_l2tlb_ref_pgflt_type			(twu_l2tlb_ref_pgflt_type[3]	),
.twu_l2tlb_ref_acc_err				(twu_l2tlb_ref_acc_err[3]		),
.twu_l2tlb_ref_acc_err_type			(twu_l2tlb_ref_acc_err_type[3]	),
.twu_l2tlb_ref_acc_err_id			(twu_l2tlb_ref_acc_err_id[3]	),
                                     
.twu_mask							(twu_mask[3]					),
//.twu_idle							(twu_idle[3]					),
.twu_data_ready                     (twu_data_ready[3][2:0]     	),
//.mbuf_twu_have                      (mbuf_twu_have[3]           	),

.acc_err_twu_grant                  (acc_err_twu_grant[3]           ),
.pgflt_twu_grant                    (pgflt_twu_grant[3]             )

);


ptw_mbuf u_ptw_mbuf(
.forever_cpuclk						(forever_cpuclk				),
.cpurst_b							(cpurst_b					),
.cp0_mmu_icg_en                     (cp0_mmu_icg_en             ),
.pad_yy_icg_scan_en                 (pad_yy_icg_scan_en         ),
			
.twu_mbuf_req						(twu_mbuf_req[3:0]			),
.twu_mbuf_paddr						(twu_mbuf_paddr	[3:0]		),
.twu_mbuf_vpn						(twu_mbuf_vpn[3:0]			),
.twu_mbuf_type						(twu_mbuf_type[3:0]			),
.twu_mbuf_id						(twu_mbuf_id[3:0]			),
.twu_mbuf_lvl						(twu_mbuf_lvl[3:0]			),
.twu_mbuf_twu_idx					(twu_mbuf_twu_idx[3:0]		),
//.twu_mbuf_mask						(twu_mbuf_mask[3:0]			),
		
.lsu_mmu_data_vld					(lsu_mmu_data_vld			),     
.lsu_mmu_data						(lsu_mmu_data				),         
.lsu_mmu_bus_error					(lsu_mmu_bus_error			), 
			
.mmu_lsu_data_req					(mmu_lsu_data_req			),     
.mmu_lsu_data_req_addr				(mmu_lsu_data_req_addr		), 
.mmu_lsu_data_req_size				(mmu_lsu_data_req_size		),
			
.mbuf_twu_vpn						(mbuf_twu_vpn				),
.mbuf_twu_type						(mbuf_twu_type				),
.mbuf_twu_id						(mbuf_twu_id				),
.mbuf_twu_lvl						(mbuf_twu_lvl				),
.mbuf_twu_data						(mbuf_twu_data				),
.mbuf_twu_data_vld					(mbuf_twu_data_vld[3:0]		),
			
.mbuf_grant							(mbuf_grant[3:0]			),
//.mbuf_twu_have              		(mbuf_twu_have[3:0]         ),
                                                                 
.mbuf_cache_upd		                (mbuf_cache_upd				),
.mbuf_cache_upd_ppn                 (mbuf_cache_upd_ppn			),
.mbuf_cache_upd_lvl                 (mbuf_cache_upd_lvl			),
.mbuf_cache_upd_vpn                 (mbuf_cache_upd_vpn			),
                                                                 
.tlboper_ptw_abort	                (tlboper_ptw_abort			),
.twu_data_ready                     (twu_data_ready             ),
.mbuf_entry_on_vld                  (mbuf_entry_on_vld 			),
.mbuf_bus_error			        	(mbuf_bus_error             ),
.mbuf_bus_error_type			    (mbuf_bus_error_type        ),
.mbuf_bus_error_id                  (mbuf_bus_error_id          ),
.acc_err_mbuf_grant                 (acc_err_twu_grant[4]       )


);


assign pgflt_vld = |twu_l2tlb_ref_pgflt[3:0];
assign acc_err_vld = (|twu_l2tlb_ref_acc_err[3:0]) | mbuf_bus_error;
assign ref_vld = |twu_arb_ref_req[3:0];

assign acc_err_grant = acc_err_vld;
assign pgflt_grant = pgflt_vld & (!acc_err_vld);
assign ref_grant = ref_vld & (!acc_err_vld) & (!pgflt_vld);


//==============================================================================
//                page fault arbiter
//==============================================================================
assign twu_pgflt_sel[3] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & (!twu_l2tlb_ref_pgflt[2]) & (twu_l2tlb_ref_pgflt[3]) & pgflt_grant;
assign twu_pgflt_sel[2] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & twu_l2tlb_ref_pgflt[2] & pgflt_grant;
assign twu_pgflt_sel[1] = (!twu_l2tlb_ref_pgflt[0]) & twu_l2tlb_ref_pgflt[1] & pgflt_grant;
assign twu_pgflt_sel[0] = twu_l2tlb_ref_pgflt[0] & pgflt_grant;

assign pgflt_twu_grant[3:0] = twu_pgflt_sel[3:0];

logic [ID_WIDTH-1:0]  ptw_l2tlb_pgflt_id;
logic [2:0]	      ptw_l2tlb_pgflt_type;

always_comb begin
	case(pgflt_twu_grant[3:0])
		4'b0001	: begin		
			//ptw_l2tlb_ref_pgflt = 1'b1;
			ptw_l2tlb_pgflt_type[2:0] = twu_l2tlb_ref_pgflt_type[0][2:0];
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = twu_l2tlb_ref_pgflt_id[0][ID_WIDTH-1:0];
		end
		4'b0010	: begin		
			//ptw_l2tlb_ref_pgflt = 1'b1;
			ptw_l2tlb_pgflt_type[2:0] = twu_l2tlb_ref_pgflt_type[1][2:0];
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = twu_l2tlb_ref_pgflt_id[1][ID_WIDTH-1:0];
		end
		4'b0100	: begin		
			//ptw_l2tlb_ref_pgflt = 1'b1;
			ptw_l2tlb_pgflt_type[2:0] = twu_l2tlb_ref_pgflt_type[2][2:0];
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = twu_l2tlb_ref_pgflt_id[2][ID_WIDTH-1:0];
		end
		4'b1000	: begin		
			//ptw_l2tlb_ref_pgflt = 1'b1;
			ptw_l2tlb_pgflt_type[2:0] = twu_l2tlb_ref_pgflt_type[3][2:0];
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = twu_l2tlb_ref_pgflt_id[3][ID_WIDTH-1:0];
		end
		default 	: begin
			//ptw_l2tlb_ref_pgflt = 1'b0;
			ptw_l2tlb_pgflt_type[2:0] = 3'b0;
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
		end
	endcase
end




//==============================================================================
//                access fault arbiter
//==============================================================================
assign twu_acc_err_sel[3] = (!twu_l2tlb_ref_acc_err[0]) & (!twu_l2tlb_ref_acc_err[1]) & (!twu_l2tlb_ref_acc_err[2]) & (twu_l2tlb_ref_acc_err[3]) & acc_err_grant;
assign twu_acc_err_sel[2] = (!twu_l2tlb_ref_acc_err[0]) & (!twu_l2tlb_ref_acc_err[1]) & twu_l2tlb_ref_acc_err[2] & acc_err_grant;
assign twu_acc_err_sel[1] = (!twu_l2tlb_ref_acc_err[0]) & twu_l2tlb_ref_acc_err[1] & acc_err_grant;
assign twu_acc_err_sel[0] = (!mbuf_bus_error) & twu_l2tlb_ref_acc_err[0] & acc_err_grant;
assign twu_acc_err_sel[4] = mbuf_bus_error & acc_err_grant;

assign acc_err_twu_grant[4:0] = twu_acc_err_sel[4:0];

logic [ID_WIDTH-1:0]  ptw_l2tlb_acc_err_id;
logic [2:0]	      ptw_l2tlb_acc_err_type;

always_comb begin
	case(acc_err_twu_grant[4:0])
		5'b00001	: begin		
			//ptw_l2tlb_ref_acc_err = 1'b1;
			ptw_l2tlb_acc_err_type[2:0] = twu_l2tlb_ref_acc_err_type[0][2:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = twu_l2tlb_ref_acc_err_id[0][ID_WIDTH-1:0];
		end
		5'b00010	: begin		
			//ptw_l2tlb_ref_acc_err = 1'b1;
			ptw_l2tlb_acc_err_type[2:0] = twu_l2tlb_ref_acc_err_type[1][2:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = twu_l2tlb_ref_acc_err_id[1][ID_WIDTH-1:0];
		end
		5'b00100	: begin		
			//ptw_l2tlb_ref_acc_err = 1'b1;
			ptw_l2tlb_acc_err_type[2:0] = twu_l2tlb_ref_acc_err_type[2][2:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = twu_l2tlb_ref_acc_err_id[2][ID_WIDTH-1:0];
		end
		5'b01000	: begin		
			//ptw_l2tlb_ref_acc_err = 1'b1;
			ptw_l2tlb_acc_err_type[2:0] = twu_l2tlb_ref_acc_err_type[3][2:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = twu_l2tlb_ref_acc_err_id[3][ID_WIDTH-1:0];
		end
		5'b10000	: begin		
			//ptw_l2tlb_ref_acc_err = 1'b1;
			ptw_l2tlb_acc_err_type[2:0] = mbuf_bus_error_type[2:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = mbuf_bus_error_id[ID_WIDTH-1:0];
		end		
		default 	: begin
			//ptw_l2tlb_ref_acc_err = 1'b0;
			ptw_l2tlb_acc_err_type[2:0] = 3'b0;
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
		end
	endcase
end




//==============================================================================
//                  Refill arbiter
//==============================================================================
assign ptw_arb_req = (|twu_arb_ref_req[3:0]) & (!arb_ptw_mask) & ref_grant;

assign fst_twu_itlb_sel = twu_arb_ref_req[0] & twu_arb_ref_type[0][2:0] == 3'b011;
assign scd_twu_itlb_sel = twu_arb_ref_req[1] & twu_arb_ref_type[1][2:0] == 3'b011;
assign thd_twu_itlb_sel = twu_arb_ref_req[2] & twu_arb_ref_type[2][2:0] == 3'b011;
assign fth_twu_itlb_sel = twu_arb_ref_req[3] & twu_arb_ref_type[3][2:0] == 3'b011;

assign ref_itlb_sel = (fst_twu_itlb_sel | scd_twu_itlb_sel | thd_twu_itlb_sel | fth_twu_itlb_sel) & ref_grant;


assign twu_ref_sel[3] = (!ref_itlb_sel) & (!twu_arb_ref_req[0]) & (!twu_arb_ref_req[1]) & (!twu_arb_ref_req[2]) & twu_arb_ref_req[3] & ref_grant;
assign twu_ref_sel[2] = (!ref_itlb_sel) & (!twu_arb_ref_req[0]) & (!twu_arb_ref_req[1]) & twu_arb_ref_req[2] & ref_grant;
assign twu_ref_sel[1] = (!ref_itlb_sel) & (!twu_arb_ref_req[0]) & twu_arb_ref_req[1] & ref_grant;
assign twu_ref_sel[0] = (!ref_itlb_sel) & twu_arb_ref_req[0] & ref_grant;

always_comb begin
    case({ref_itlb_sel,twu_ref_sel[3:0]})
        5'b10000    : refill_arb_grant[3:0] = {fth_twu_itlb_sel,thd_twu_itlb_sel,scd_twu_itlb_sel,fst_twu_itlb_sel};
        5'b01000    : refill_arb_grant[3:0] = 4'b1000;
        5'b00100    : refill_arb_grant[3:0] = 4'b0100;
        5'b00010    : refill_arb_grant[3:0] = 4'b0010;
        5'b00001    : refill_arb_grant[3:0] = 4'b0001;
        default     : refill_arb_grant[3:0] = 4'b0000;
    endcase
end

assign refill_arb_twu_grant[3:0] = refill_arb_grant[3:0] & {4{arb_ptw_grant}};

logic [2:0] ptw_arb_ref_type;
logic [ID_WIDTH-1:0] ptw_arb_ref_id;

always_comb begin
	case(refill_arb_twu_grant[3:0])
		4'b0001	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = twu_arb_ref_data_din[0][DATA_WIDTH-1:0];
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_arb_ref_tag_din[0][TAG_WIDTH-1:0];
			ptw_arb_ref_pgs[2:0] = twu_arb_ref_pgs[0][2:0];
			ptw_arb_ref_type[2:0] = twu_arb_ref_type[0][2:0];
			ptw_arb_ref_id[ID_WIDTH-1:0] = twu_arb_ref_id[0][ID_WIDTH-1:0];
		end
		4'b0010	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = twu_arb_ref_data_din[1][DATA_WIDTH-1:0];
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_arb_ref_tag_din[1][TAG_WIDTH-1:0];
			ptw_arb_ref_pgs[2:0] = twu_arb_ref_pgs[1][2:0];
			ptw_arb_ref_type[2:0] = twu_arb_ref_type[1][2:0];
			ptw_arb_ref_id[ID_WIDTH-1:0] = twu_arb_ref_id[1][ID_WIDTH-1:0];
		end	
		4'b0100	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = twu_arb_ref_data_din[2][DATA_WIDTH-1:0];
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_arb_ref_tag_din[2][TAG_WIDTH-1:0];
			ptw_arb_ref_pgs[2:0] = twu_arb_ref_pgs[2][2:0];
			ptw_arb_ref_type[2:0] = twu_arb_ref_type[2][2:0];
			ptw_arb_ref_id[ID_WIDTH-1:0] = twu_arb_ref_id[2][ID_WIDTH-1:0];
		end
		4'b1000	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = twu_arb_ref_data_din[3][DATA_WIDTH-1:0];
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_arb_ref_tag_din[3][TAG_WIDTH-1:0];
			ptw_arb_ref_pgs[2:0] = twu_arb_ref_pgs[3][2:0];
			ptw_arb_ref_type[2:0] = twu_arb_ref_type[3][2:0];
			ptw_arb_ref_id[ID_WIDTH-1:0] = twu_arb_ref_id[3][ID_WIDTH-1:0];
		end
		default	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = {DATA_WIDTH{1'b0}};
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = {TAG_WIDTH{1'b0}};
			ptw_arb_ref_pgs[2:0] = 3'b0;
			ptw_arb_ref_type[2:0] = 3'b0;
			ptw_arb_ref_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
		end
	endcase
end

//logic [2:0] ptw_l2tlb_ref_type;
//logic [ID_WIDTH-1:0] ptw_l2tlb_ref_id;
//logic                  ptw_rsp_cmplt_q;
//logic                  ptw_rsp_data_vld_q;
//logic                  ptw_rsp_pgflt_q;
//logic                  ptw_rsp_acc_err_q;
//logic [2:0]            ptw_rsp_type_q;
//logic [ID_WIDTH-1:0]   ptw_rsp_id_q;
//logic [41:0]           ptw_rsp_data_q;
//logic [47:0]           ptw_rsp_tag_q;
//logic [2:0]            ptw_rsp_pgs_q;
//logic                  ptw_lsu_req_dbg_q;
//logic [39:0]           ptw_lsu_addr_dbg_q;
//
//assign ptw_l2tlb_ref_type[2:0] = ptw_arb_ref_type[2:0];
//assign ptw_l2tlb_ref_id[ID_WIDTH-1:0] = ptw_arb_ref_id[ID_WIDTH-1:0];
//
//// Publish a registered PTW response bundle so type/id/tag/data stay aligned
//// when the refill source changes under arb pressure.
//always_ff @(posedge ptw_clk or negedge cpurst_b) begin
//	if(!cpurst_b) begin
//		ptw_rsp_cmplt_q    <= 1'b0;
//		ptw_rsp_data_vld_q <= 1'b0;
//		ptw_rsp_pgflt_q    <= 1'b0;
//		ptw_rsp_acc_err_q  <= 1'b0;
//		ptw_rsp_type_q     <= 3'b0;
//		ptw_rsp_id_q       <= {ID_WIDTH{1'b0}};
//		ptw_rsp_data_q     <= 42'b0;
//		ptw_rsp_tag_q      <= 48'b0;
//		ptw_rsp_pgs_q      <= 3'b0;
//	end else begin
//		ptw_rsp_cmplt_q    <= 1'b0;
//		ptw_rsp_data_vld_q <= 1'b0;
//		ptw_rsp_pgflt_q    <= 1'b0;
//		ptw_rsp_acc_err_q  <= 1'b0;
//
//		if(acc_err_grant) begin
//			ptw_rsp_cmplt_q   <= 1'b1;
//			ptw_rsp_acc_err_q <= 1'b1;
//			ptw_rsp_type_q    <= ptw_l2tlb_acc_err_type[2:0];
//			ptw_rsp_id_q      <= ptw_l2tlb_acc_err_id[ID_WIDTH-1:0];
//			ptw_rsp_data_q    <= 42'b0;
//			ptw_rsp_tag_q     <= 48'b0;
//			ptw_rsp_pgs_q     <= 3'b0;
//		end else if(pgflt_grant) begin
//			ptw_rsp_cmplt_q <= 1'b1;
//			ptw_rsp_pgflt_q <= 1'b1;
//			ptw_rsp_type_q  <= ptw_l2tlb_pgflt_type[2:0];
//			ptw_rsp_id_q    <= ptw_l2tlb_pgflt_id[ID_WIDTH-1:0];
//			ptw_rsp_data_q  <= 42'b0;
//			ptw_rsp_tag_q   <= 48'b0;
//			ptw_rsp_pgs_q   <= 3'b0;
//		end else if(arb_ptw_grant & (|refill_arb_grant[3:0]) & ref_grant) begin
//			ptw_rsp_cmplt_q    <= 1'b1;
//			ptw_rsp_data_vld_q <= 1'b1;
//			ptw_rsp_type_q     <= ptw_l2tlb_ref_type[2:0];
//			ptw_rsp_id_q       <= ptw_l2tlb_ref_id[ID_WIDTH-1:0];
//			ptw_rsp_data_q     <= ptw_arb_ref_data_din[DATA_WIDTH-1:0];
//			ptw_rsp_tag_q      <= ptw_arb_ref_tag_din[TAG_WIDTH-1:0];
//			ptw_rsp_pgs_q      <= ptw_arb_ref_pgs[2:0];
//		end
//	end
//end
//

logic [2:0] ptw_l2tlb_ref_type;
logic [ID_WIDTH-1:0] ptw_l2tlb_ref_id;

assign ptw_l2tlb_ref_type[2:0] = ptw_arb_ref_type[2:0];
assign ptw_l2tlb_ref_id[ID_WIDTH-1:0] = ptw_arb_ref_id[ID_WIDTH-1:0];
		
always_comb begin
	case({pgflt_grant,acc_err_grant,ref_grant})
		3'b100 :begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = ptw_l2tlb_pgflt_id[ID_WIDTH-1:0];
				ptw_l2tlb_type[2:0] = ptw_l2tlb_pgflt_type[2:0];
				end
		3'b010 :begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = ptw_l2tlb_acc_err_id[ID_WIDTH-1:0];
				ptw_l2tlb_type[2:0] = ptw_l2tlb_acc_err_type[2:0];
				end
		3'b001 :begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = ptw_l2tlb_ref_id[ID_WIDTH-1:0];
				ptw_l2tlb_type[2:0] = ptw_l2tlb_ref_type[2:0];
				end
		default:begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
				ptw_l2tlb_type[2:0] = 3'b0;
				end
	endcase
end

assign ptw_l2tlb_flg = ptw_arb_ref_data_din[13:0];
assign ptw_l1tlb_id = ptw_l2tlb_id;

assign ptw_l2tlb_ref_data_vld = arb_ptw_grant;
assign ptw_l2tlb_ref_pgflt = pgflt_grant;
assign ptw_l2tlb_ref_acc_err = acc_err_grant;

assign ptw_l2tlb_cmplt = ptw_l2tlb_ref_data_vld | ptw_l2tlb_ref_pgflt | ptw_l2tlb_ref_acc_err;

//to l1tlb
assign ptw_l1dtlb_ref_pa_vld = arb_ptw_grant & (ptw_arb_ref_type[2:0] == 3'b010 | ptw_arb_ref_type[2:0] == 3'b110);
assign ptw_l1dtlb_cmplt = ptw_l2tlb_cmplt & (ptw_l2tlb_type[2:0] == 3'b010 | ptw_l2tlb_type[2:0] == 3'b110);
assign ptw_l1dtlb_ref_vpn = ptw_arb_ref_tag_din[46:20];
assign ptw_l1dtlb_ref_pgs = ptw_arb_ref_pgs[2:0];
assign ptw_l1dtlb_ref_ppn = ptw_arb_ref_data_din[41:14];
assign ptw_l1dtlb_ref_flg = ptw_arb_ref_data_din[13:0];
assign ptw_l1dtlb_ref_acc_err = ptw_l2tlb_ref_acc_err & (ptw_l2tlb_type[2:0] == 3'b010 | ptw_l2tlb_type[2:0] == 3'b110);
assign ptw_l1dtlb_pgflt  = ptw_l2tlb_ref_pgflt & (ptw_l2tlb_type[2:0] == 3'b010 | ptw_l2tlb_type[2:0] == 3'b110);

assign ptw_l1itlb_ref_pa_vld = arb_ptw_grant & (ptw_l2tlb_type[2:0] == 3'b011);
assign ptw_l1itlb_cmplt = ptw_l2tlb_cmplt & (ptw_l2tlb_type[2:0] == 3'b011);
assign ptw_l1itlb_ref_vpn = ptw_arb_ref_tag_din[46:20];
assign ptw_l1itlb_ref_pgs = ptw_arb_ref_pgs[2:0];
assign ptw_l1itlb_ref_ppn = ptw_arb_ref_data_din[41:14];
assign ptw_l1itlb_ref_flg = ptw_arb_ref_data_din[13:0];
assign ptw_l1itlb_ref_acc_err = ptw_l2tlb_ref_acc_err & (ptw_l2tlb_type[2:0] == 3'b011);
assign ptw_l1itlb_pgflt  = ptw_l2tlb_ref_pgflt & (ptw_l2tlb_type[2:0] == 3'b011);
;

assign ptw_arb_vpn[VPN_WIDTH-1:0] = ptw_arb_ref_tag_din[46:20];

assign l2tlb_miss_cnt = ptw_l2tlb_ref_data_vld & (ptw_l2tlb_type[2:0] == 3'b010 | ptw_l2tlb_type[2:0] == 3'b110 | ptw_l2tlb_type[2:0] == 3'b011 ) & hpcp_mmu_cnt_en;

always_ff@(posedge ptw_clk or negedge cpurst_b) begin
	if(!cpurst_b)
        l2tlb_miss <= 1'b0;
    else if(l2tlb_miss_cnt)
        l2tlb_miss <= 1'b1;
    else if(l2tlb_miss & (!l2tlb_miss_cnt))
        l2tlb_miss <= 1'b0;
end
        
assign mmu_hpcp_jtlb_miss = l2tlb_miss;


logic ptw_lsu_req_dbg_q;
logic [39:0] ptw_lsu_addr_dbg_q;

// PTW->LSU request trace for run_check log parsing.
// Emit once per new request (req rising edge or address change while req high).
always_ff @(posedge ptw_clk or negedge cpurst_b) begin
	if(!cpurst_b) begin
		ptw_lsu_req_dbg_q  <= 1'b0;
		ptw_lsu_addr_dbg_q <= 40'b0;
	end else begin
		if(mmu_lsu_data_req
		   && (!ptw_lsu_req_dbg_q || (mmu_lsu_data_req_addr != ptw_lsu_addr_dbg_q))) begin
			$display("[%0t][PTW LSU REQ] addr=0x%010h size=%0b satp_base=0x%07h",
			         $time, mmu_lsu_data_req_addr, mmu_lsu_data_req_size, regs_ptw_satp_ppn);
		end
		ptw_lsu_req_dbg_q <= mmu_lsu_data_req;
		if(mmu_lsu_data_req)
			ptw_lsu_addr_dbg_q <= mmu_lsu_data_req_addr;
	end
end

//assign ptw_l2tlb_id = ptw_rsp_id_q;
//assign ptw_l2tlb_type[2:0] = ptw_rsp_type_q[2:0];
//assign ptw_l2tlb_flg = ptw_rsp_data_q[13:0];
//assign ptw_l1tlb_id = ptw_rsp_id_q;

//assign ptw_l2tlb_ref_data_vld = ptw_rsp_data_vld_q;
//assign ptw_l2tlb_ref_pgflt = ptw_rsp_pgflt_q;
//assign ptw_l2tlb_ref_acc_err = ptw_rsp_acc_err_q;
//
//assign ptw_l2tlb_cmplt = ptw_rsp_cmplt_q;
//
////to l1tlb
//assign ptw_l1dtlb_ref_pa_vld = ptw_rsp_data_vld_q
//                            & (ptw_rsp_type_q[2:0] == 3'b010 | ptw_rsp_type_q[2:0] == 3'b110);
//assign ptw_l1dtlb_cmplt = ptw_rsp_cmplt_q
//                       & (ptw_rsp_type_q[2:0] == 3'b010 | ptw_rsp_type_q[2:0] == 3'b110);
//assign ptw_l1dtlb_ref_vpn = ptw_rsp_tag_q[46:20];
//assign ptw_l1dtlb_ref_pgs = ptw_rsp_pgs_q[2:0];
//assign ptw_l1dtlb_ref_ppn = ptw_rsp_data_q[41:14];
//assign ptw_l1dtlb_ref_flg = ptw_rsp_data_q[13:0];
//assign ptw_l1dtlb_ref_acc_err = ptw_rsp_acc_err_q
//                             & (ptw_rsp_type_q[2:0] == 3'b010 | ptw_rsp_type_q[2:0] == 3'b110);
//assign ptw_l1dtlb_pgflt  = ptw_rsp_pgflt_q
//                        & (ptw_rsp_type_q[2:0] == 3'b010 | ptw_rsp_type_q[2:0] == 3'b110);
//
//assign ptw_l1itlb_ref_pa_vld = ptw_rsp_data_vld_q & (ptw_rsp_type_q[2:0] == 3'b011);
//assign ptw_l1itlb_cmplt = ptw_rsp_cmplt_q & (ptw_rsp_type_q[2:0] == 3'b011);
//assign ptw_l1itlb_ref_vpn = ptw_rsp_tag_q[46:20];
//assign ptw_l1itlb_ref_pgs = ptw_rsp_pgs_q[2:0];
//assign ptw_l1itlb_ref_ppn = ptw_rsp_data_q[41:14];
//assign ptw_l1itlb_ref_flg = ptw_rsp_data_q[13:0];
//assign ptw_l1itlb_ref_acc_err = ptw_rsp_acc_err_q & (ptw_rsp_type_q[2:0] == 3'b011);
//assign ptw_l1itlb_pgflt  = ptw_rsp_pgflt_q & (ptw_rsp_type_q[2:0] == 3'b011);
//;
//
//assign ptw_arb_vpn[VPN_WIDTH-1:0] = ptw_arb_ref_tag_din[46:20];
//
//assign l2tlb_miss_cnt = ptw_l2tlb_ref_data_vld & (ptw_l2tlb_type[2:0] == 3'b010 | ptw_l2tlb_type[2:0] == 3'b110 | ptw_l2tlb_type[2:0] == 3'b011 ) & hpcp_mmu_cnt_en;
//
//always_ff@(posedge ptw_clk or negedge cpurst_b) begin
//	if(!cpurst_b)
//        l2tlb_miss <= 1'b0;
//    else if(l2tlb_miss_cnt)
//        l2tlb_miss <= 1'b1;
//    else if(l2tlb_miss & (!l2tlb_miss_cnt))
//        l2tlb_miss <= 1'b0;
//end
//        
//assign mmu_hpcp_jtlb_miss = l2tlb_miss;
//
////always_ff@(posedge ptw_clk or negedge cpurst_b) begin
////	if(!cpurst_b)
////       ptw_top_imiss <= 1'b0;
////   else if(l2tlb_ptw_req & (l2tlb_ptw_type == 3'b011))
////        ptw_top_imiss <= 1'b1
////    else if(ptw_l1itlb_cmplt)
////        ptw_top_imiss <= 1'b0;
////end
//

endmodule


