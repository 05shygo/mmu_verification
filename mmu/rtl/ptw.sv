module ptw #(
    parameter VADDR_WIDTH = 39,                         // VADDR
    parameter PADDR_WIDTH = 40,                         // PADDR
    parameter VPN_WIDTH   = VADDR_WIDTH-12,             // VPN
    parameter PPN_WIDTH   = PADDR_WIDTH-12,             // PPN
    parameter FLG_WIDTH   = 14,                         // PPN
    parameter ASID_WIDTH  = 16,                         // PPN
    parameter PGS_WIDTH   = 3,                          // Page Size
    parameter PTE_LEVEL   = 3,                          // Page Table Label
    parameter ID_WIDTH    = 7,
    parameter TYPE_WIDTH  = 3,
    parameter L1PDE_ENTRY_NUM = 16,
    parameter L2PDE_ENTRY_NUM = 16,
    parameter MBUF_ID_WIDTH = 4,

// VPN width per level
    parameter VPN_PERLEL  = VPN_WIDTH/PTE_LEVEL,

// Valid + VPN + ASID + PageSize + Global
    parameter TAG_WIDTH   = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,
    parameter DATA_WIDTH  = PPN_WIDTH+FLG_WIDTH
) (
//!******************************************
//! Clock and Reset
//!******************************************
    input  logic                   forever_cpuclk,
    input  logic                   cpurst_b,

//!******************************************
//! System Regs
//!******************************************
    input  logic                   cp0_mmu_icg_en,
    input  logic                   cp0_mmu_maee,
    input  logic [1:0]             cp0_mmu_mpp,
    input  logic                   cp0_mmu_mprv,
    input  logic                   cp0_mmu_mxr,
    input  logic                   cp0_mmu_sum,
    input  logic [1:0]             cp0_yy_priv_mode,
    input  logic                   pad_yy_icg_scan_en,
    input  logic                   hpcp_mmu_cnt_en,
	
    input  logic [ASID_WIDTH-1:0]  regs_ptw_cur_asid,
    input  logic [PPN_WIDTH-1:0]   regs_ptw_satp_ppn,
    input  logic                   regs_ptw_clr,

//!******************************************
//! Systemmap <=> ptw
//!******************************************
    input  logic [4:0]             sysmap_mmu_flg3,
//input  logic [4 :0]	 	sysmap_mmu_flg4,
    input  logic [4:0]             sysmap_mmu_flg5,
    input  logic [4:0]             sysmap_mmu_flg6,

    input  logic [7:0]             sysmap_mmu_hit3,
//input  logic [7 :0]	 	sysmap_mmu_hit4,
    input  logic [7:0]             sysmap_mmu_hit5,
    input  logic [7:0]             sysmap_mmu_hit6,

    output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa3,
//output logic [27:0]	 	mmu_sysmap_pa4,
    output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa5,
    output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa6,

//!******************************************
//! PMP <=> ptw
//!******************************************
    input  logic [3:0]             pmp_mmu_flg3,
//input  logic [3 :0]	 	pmp_mmu_flg4,
	
    output logic [PPN_WIDTH-1:0]   mmu_pmp_pa3,
//output logic [27:0]	 	mmu_pmp_pa4,
    output logic                   mmu_pmp_fetch3,
    input  logic                   pmp_regs_update,
//!******************************************
//! L2TLB Request
//!******************************************
    input  logic                   l2tlb_ptw_req,
    input  logic [TYPE_WIDTH-1:0]  l2tlb_ptw_type,
    input  logic [VPN_WIDTH-1:0]   l2tlb_ptw_vpn,
    input  logic [ID_WIDTH-1:0]    l2tlb_ptw_id,

//!******************************************
//! LSU <=> PTW
//!******************************************
    input  logic                   lsu_mmu_bus_error,
    input  logic [63:0]            lsu_mmu_data,
    input  logic                   lsu_mmu_data_vld,
    // LSU 返回 PTW load response 时带回的 MBUF entry id。
    // PTW/MBUF 依靠该 id 把 data 或 bus error 路由回发起请求的 entry。
    input  logic [MBUF_ID_WIDTH-1:0] lsu_mmu_data_id,
    // LSU 对 PTW load request 的接收确认。只有 req/grant 同拍有效时，
    // MBUF entry 才会置 on，并把该请求计入 outstanding。
    input  logic                   lsu_mmu_data_req_grant,
	
	
    output logic                   mmu_lsu_data_req,
    output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,
    // PTW 发给 LSU 的 request id，取自当前发起请求的 MBUF entry index。
    // LSU 必须在 response 上带回同一个 id。
    output logic [MBUF_ID_WIDTH-1:0] mmu_lsu_data_req_id,
    output logic                   mmu_lsu_data_req_size,

//!******************************************
//! Refill
//!******************************************
    input  logic                   arb_ptw_grant,
    input  logic                   arb_ptw_mask,

    output logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
    output logic                   ptw_arb_req,
    output logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
    output logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
    output logic [PGS_WIDTH-1:0]   ptw_arb_ref_pgs,

// to l1tlb
    output logic                   ptw_l1dtlb_ref_pa_vld,
    output logic [VPN_WIDTH-1:0]   ptw_l1dtlb_ref_vpn,
    output logic [PGS_WIDTH-1:0]   ptw_l1dtlb_ref_pgs,
    output logic [PPN_WIDTH-1:0]   ptw_l1dtlb_ref_ppn,
    output logic [FLG_WIDTH-1:0]   ptw_l1dtlb_ref_flg,
    output logic [ID_WIDTH-1:0]    ptw_l1tlb_id,
    output logic                   ptw_l1dtlb_cmplt,
    output logic                   ptw_l1dtlb_pgflt,
    output logic                   ptw_l1dtlb_ref_acc_err,

    output logic                   ptw_l1itlb_ref_pa_vld,
    output logic [VPN_WIDTH-1:0]   ptw_l1itlb_ref_vpn,
    output logic [PGS_WIDTH-1:0]   ptw_l1itlb_ref_pgs,
    output logic [PPN_WIDTH-1:0]   ptw_l1itlb_ref_ppn,
    output logic [FLG_WIDTH-1:0]   ptw_l1itlb_ref_flg,
    output logic                   ptw_l1itlb_cmplt,
    output logic                   ptw_l1itlb_pgflt,
    output logic                   ptw_l1itlb_ref_acc_err,
//!******************************************
//! Fault to L2TLB
//!******************************************
    output logic                   ptw_l2tlb_ref_acc_err,
    output logic                   ptw_l2tlb_ref_pgflt,
    output logic                   ptw_l2tlb_ref_data_vld,
    output logic                   ptw_l2tlb_cmplt,
    output logic [TYPE_WIDTH-1:0]  ptw_l2tlb_type,
    output logic [ID_WIDTH-1:0]    ptw_l2tlb_id,
    output logic [FLG_WIDTH-1:0]   ptw_l2tlb_flg,
    output logic [VPN_WIDTH-1:0]   ptw_l2tlb_ref_vpn,
    output logic [PGS_WIDTH-1:0]   ptw_l2tlb_ref_pgs,
    output logic [PPN_WIDTH-1:0]   ptw_l2tlb_ref_ppn,

    output logic                   ptw_jtlb_ready,
    input  logic                   tlboper_ptw_abort,
//output logic            ptw_top_imiss,
    output logic                   mmu_hpcp_jtlb_miss

);


logic                  pde_cache_ready   ;
logic                  mbuf_cache_upd    ;
logic [PTE_LEVEL-2:0]  mbuf_cache_upd_lvl;
logic [PPN_WIDTH-1:0]  mbuf_cache_upd_ppn;
logic [VPN_WIDTH-1:0]  mbuf_cache_upd_vpn;
logic [3:0]            mbuf_cache_upd_l1pmpflg;
logic [3:0]            mbuf_cache_upd_l2pmpflg;
logic [7:0]            mbuf_twu_pmpflg;
logic                  L2PDE_xbar_hit_vld;
logic                  L1PDE_xbar_hit_vld;
logic [PPN_WIDTH-1:0]  PDE_xbar_ppn      ;
logic [VPN_WIDTH-1:0]  PDE_xbar_vpn      ;
logic [TYPE_WIDTH-1:0] PDE_xbar_type     ;
logic [ID_WIDTH-1:0]   PDE_xbar_id       ;
logic                  PDE_xbar_req      ;
logic                  twu_cache_stop    ;
//logic	[3:0]			twu_idle				    ;
logic                        xbar_twu_req              ;
logic [PTE_LEVEL-2:0]        xbar_twu_hit_level        ;
logic [PPN_WIDTH-1:0]        xbar_twu_ppn              ;
logic [VPN_WIDTH-1:0]        xbar_twu_vpn              ;
logic [TYPE_WIDTH-1:0]       xbar_twu_type             ;
logic [ID_WIDTH-1:0]         xbar_twu_id               ;
logic                        refill_arb_twu_grant      ;
logic [VPN_WIDTH-1:0]        mbuf_twu_vpn              ;
logic [TYPE_WIDTH-1:0]       mbuf_twu_type             ;
logic [ID_WIDTH-1:0]         mbuf_twu_id               ;
logic [PTE_LEVEL-1:0]        mbuf_twu_lvl              ;
logic [63:0]                 mbuf_twu_data             ;
logic                        mbuf_twu_data_vld         ;
logic                        mbuf_grant                ;
logic                        twu_mbuf_req              ;
logic [PADDR_WIDTH-1:0]      twu_mbuf_paddr            ;
logic [VPN_WIDTH-1:0]        twu_mbuf_vpn              ;
logic [TYPE_WIDTH-1:0]       twu_mbuf_type             ;
logic [ID_WIDTH-1:0]         twu_mbuf_id               ;
logic [PTE_LEVEL-1:0]        twu_mbuf_lvl              ;
logic [7:0]                  twu_mbuf_pmpflg           ;
logic                        twu_arb_ref_req           ;
logic [DATA_WIDTH-1:0]       twu_arb_ref_data_din      ;
logic [TAG_WIDTH-1:0]        twu_arb_ref_tag_din       ;
logic [PGS_WIDTH-1:0]        twu_arb_ref_pgs           ;
logic [TYPE_WIDTH-1:0]       twu_arb_ref_type          ;
logic [ID_WIDTH-1:0]         twu_arb_ref_id            ;
logic                        twu_l2tlb_ref_pgflt       ;
logic [ID_WIDTH-1:0]         twu_l2tlb_ref_pgflt_id    ;
logic [TYPE_WIDTH-1:0]       twu_l2tlb_ref_pgflt_type  ;
logic                        twu_l2tlb_ref_acc_err     ;
logic [TYPE_WIDTH-1:0]       twu_l2tlb_ref_acc_err_type;
logic [ID_WIDTH-1:0]         twu_l2tlb_ref_acc_err_id  ;
//logic	[3:0]			mbuf_twu_have           	;
logic [2:0]                acc_err_grant_sel  ;
logic                      pgflt_twu_grant    ;
logic                      mbuf_entry_on_vld  ;
logic                      abort_flop         ;
logic                      twu_mask           ;
logic                      mbuf_bus_error     ;
logic [TYPE_WIDTH-1:0]     mbuf_bus_error_type;
logic [ID_WIDTH-1:0]       mbuf_bus_error_id  ;
logic                      PDE_cache_acc_err_vld;
logic [TYPE_WIDTH-1:0]     PDE_cache_acc_err_type;
logic [ID_WIDTH-1:0]       PDE_cache_acc_err_id;
logic [PTE_LEVEL-1:0]      twu_data_ready     ;
logic                      pgflt_vld          ;
logic                      acc_err_vld        ;
logic                      ref_vld            ;
logic                      pgflt_grant        ;
logic                      acc_err_rant       ;
logic                      ref_rant           ;
logic                      l2tlb_miss         ;
logic                      l2tlb_miss_cnt     ;



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

assign ptw_jtlb_ready = pde_cache_ready & (!abort_flop);

always_ff @(posedge ptw_clk or negedge cpurst_b)begin
    if(!cpurst_b)
		abort_flop <= 1'b0;
    // PTW top 的 ready 需要在 abort drain 期间保持关闭。这里不能再用
    // “看到一笔 LSU response 就清 abort_flop”的旧串行语义，因为 MBUF 现在
    // 允许多笔 outstanding；必须等所有 entry.on 都被 response ID 清掉。
    else if(mbuf_entry_on_vld & tlboper_ptw_abort)
		abort_flop <= 1'b1;
    else if(abort_flop & (!mbuf_entry_on_vld))
		abort_flop <= 1'b0;
end

	// synopsys translate_off
	logic mmu_abort_dbg_en;
	initial mmu_abort_dbg_en = $test$plusargs("MMU_ABORT_DBG");

	always_ff @(posedge ptw_clk or negedge cpurst_b) begin
	  if (!cpurst_b) begin
	  end else if (mmu_abort_dbg_en && ($past(abort_flop) !== abort_flop || tlboper_ptw_abort)) begin
	    $display("[MMU_ABORT_DBG][PTW] t=%0t abort_flop=%0b->%0b mbuf_on_vld=%0b tlbop_abort=%0b lsu_data=%0b lsu_bus_err=%0b ptw_ready=%0b",
	             $time, $past(abort_flop), abort_flop, mbuf_entry_on_vld, tlboper_ptw_abort,
	             lsu_mmu_data_vld, lsu_mmu_bus_error, ptw_jtlb_ready);
	  end
	end
	// synopsys translate_on



PDE_cache #(
.VADDR_WIDTH                         (VADDR_WIDTH        ),
.PADDR_WIDTH                         (PADDR_WIDTH        ),
.VPN_WIDTH                           (VPN_WIDTH          ),
.PPN_WIDTH                           (PPN_WIDTH          ),
.FLG_WIDTH                           (FLG_WIDTH          ),
.ASID_WIDTH                          (ASID_WIDTH         ),
.PGS_WIDTH                           (PGS_WIDTH          ),
.PTE_LEVEL                           (PTE_LEVEL          ),
.ID_WIDTH                            (ID_WIDTH           ),
.TYPE_WIDTH                          (TYPE_WIDTH         ),
.L1PDE_ENTRY_NUM                     (L1PDE_ENTRY_NUM    ),
.L2PDE_ENTRY_NUM                     (L2PDE_ENTRY_NUM    ),
.VPN_PERLEL                          (VPN_PERLEL         ),
.TAG_WIDTH                           (TAG_WIDTH          ),
.DATA_WIDTH                          (DATA_WIDTH         )
) u_PDE_cache(
.forever_cpuclk						(forever_cpuclk		),
.cpurst_b							(cpurst_b			),
.cp0_mmu_icg_en                     (cp0_mmu_icg_en     ),
.pad_yy_icg_scan_en                 (pad_yy_icg_scan_en ),
.ptw_jtlb_ready                     (ptw_jtlb_ready     ),
.cp0_yy_priv_mode					(cp0_yy_priv_mode	),
.cp0_mmu_mprv						(cp0_mmu_mprv		),
.cp0_mmu_mpp						(cp0_mmu_mpp		),
				
.l2tlb_ptw_vpn						(l2tlb_ptw_vpn		),
.l2tlb_ptw_type						(l2tlb_ptw_type		),
.l2tlb_ptw_id						(l2tlb_ptw_id		),
.l2tlb_ptw_req						(l2tlb_ptw_req		),
						
.mbuf_cache_upd						(mbuf_cache_upd		),
.mbuf_cache_upd_lvl					(mbuf_cache_upd_lvl	),
.mbuf_cache_upd_ppn					(mbuf_cache_upd_ppn	),
.mbuf_cache_upd_vpn					(mbuf_cache_upd_vpn	),
.mbuf_cache_upd_l1pmpflg				(mbuf_cache_upd_l1pmpflg),
.mbuf_cache_upd_l2pmpflg				(mbuf_cache_upd_l2pmpflg),
							
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
.pmp_regs_update					(pmp_regs_update	),
.xbar_pde_ready						(xbar_pde_ready		),
.pde_cache_ready                    (pde_cache_ready    ),
.PDE_cache_acc_err_vld              (PDE_cache_acc_err_vld	),
.PDE_cache_acc_err_type             (PDE_cache_acc_err_type	),
.PDE_cache_acc_err_id               (PDE_cache_acc_err_id	),
.PDE_cache_acc_err_grant            (acc_err_grant_sel[2])
);

one_to_four_xbar #(
.VADDR_WIDTH                         (VADDR_WIDTH        ),
.PADDR_WIDTH                         (PADDR_WIDTH        ),
.VPN_WIDTH                           (VPN_WIDTH          ),
.PPN_WIDTH                           (PPN_WIDTH          ),
.FLG_WIDTH                           (FLG_WIDTH          ),
.ASID_WIDTH                          (ASID_WIDTH         ),
.PGS_WIDTH                           (PGS_WIDTH          ),
.PTE_LEVEL                           (PTE_LEVEL          ),
.ID_WIDTH                            (ID_WIDTH           ),
.TYPE_WIDTH                          (TYPE_WIDTH         ),
.VPN_PERLEL                          (VPN_PERLEL         ),
.TAG_WIDTH                           (TAG_WIDTH          ),
.DATA_WIDTH                          (DATA_WIDTH         )
) u_one_to_four_xbar(
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
									
.xbar_twu_req						(xbar_twu_req		),
.xbar_twu_hit_level					(xbar_twu_hit_level	),
.xbar_twu_ppn						(xbar_twu_ppn		),
.xbar_twu_vpn						(xbar_twu_vpn		),
.xbar_twu_type						(xbar_twu_type		),
.xbar_twu_id						(xbar_twu_id		),
.tlboper_ptw_abort					(tlboper_ptw_abort	),
.xbar_pde_ready						(xbar_pde_ready		)

);


twu #(
.VADDR_WIDTH                         (VADDR_WIDTH        ),
.PADDR_WIDTH                         (PADDR_WIDTH        ),
.VPN_WIDTH                           (VPN_WIDTH          ),
.PPN_WIDTH                           (PPN_WIDTH          ),
.FLG_WIDTH                           (FLG_WIDTH          ),
.ASID_WIDTH                          (ASID_WIDTH         ),
.PGS_WIDTH                           (PGS_WIDTH          ),
.PTE_LEVEL                           (PTE_LEVEL          ),
.ID_WIDTH                            (ID_WIDTH           ),
.TYPE_WIDTH                          (TYPE_WIDTH         ),
.VPN_PERLEL                          (VPN_PERLEL         ),
.TAG_WIDTH                           (TAG_WIDTH          ),
.RDATA_WIDTH                         (DATA_WIDTH         )
) twu_one(
.forever_cpuclk						(forever_cpuclk					),
.cpurst_b							(cpurst_b						),
.refill_arb_twu_grant				(refill_arb_twu_grant			),
										
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
										
.xbar_twu_req						(xbar_twu_req					),
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
.mbuf_twu_pmpflg					(mbuf_twu_pmpflg				),
.mbuf_twu_data_vld					(mbuf_twu_data_vld				),
.mbuf_grant							(mbuf_grant						),
										
.sysmap_mmu_flgx1					(sysmap_mmu_flg3				),
.sysmap_mmu_flgx2					(sysmap_mmu_flg5				),
.sysmap_mmu_flgx3					(sysmap_mmu_flg6				),
.sysmap_mmu_hitx1					(sysmap_mmu_hit3				),
.sysmap_mmu_hitx2					(sysmap_mmu_hit5				),
.sysmap_mmu_hitx3					(sysmap_mmu_hit6				),
.pmp_mmu_flg						(pmp_mmu_flg3					),
										
.tlboper_ptw_abort					(tlboper_ptw_abort				),
										
.twu_mbuf_req						(twu_mbuf_req					),
.twu_mbuf_paddr						(twu_mbuf_paddr					),
.twu_mbuf_vpn						(twu_mbuf_vpn					),
.twu_mbuf_type						(twu_mbuf_type					),
.twu_mbuf_id						(twu_mbuf_id					),
.twu_mbuf_lvl						(twu_mbuf_lvl					),
.twu_mbuf_pmpflg					(twu_mbuf_pmpflg				),
										
.mmu_pmp_pa							(mmu_pmp_pa3					),
.mmu_pmp_fecth						(mmu_pmp_fetch3					),
.mmu_sysmap_pax1					(mmu_sysmap_pa3					),
.mmu_sysmap_pax2					(mmu_sysmap_pa5					),
.mmu_sysmap_pax3					(mmu_sysmap_pa6					),
										
.twu_arb_ref_req					(twu_arb_ref_req				),
.twu_arb_ref_data_din				(twu_arb_ref_data_din			),
.twu_arb_ref_tag_din				(twu_arb_ref_tag_din			),
.twu_arb_ref_pgs					(twu_arb_ref_pgs				),
.twu_arb_ref_type					(twu_arb_ref_type				),
.twu_arb_ref_id						(twu_arb_ref_id					),
                                     
.twu_l2tlb_ref_pgflt				(twu_l2tlb_ref_pgflt			),
.twu_l2tlb_ref_pgflt_id				(twu_l2tlb_ref_pgflt_id			),
.twu_l2tlb_ref_pgflt_type			(twu_l2tlb_ref_pgflt_type		),
.twu_l2tlb_ref_acc_err				(twu_l2tlb_ref_acc_err			),
.twu_l2tlb_ref_acc_err_type			(twu_l2tlb_ref_acc_err_type		),
.twu_l2tlb_ref_acc_err_id			(twu_l2tlb_ref_acc_err_id		),
                                     
.twu_mask							(twu_mask						),
//.twu_idle							(twu_idle[0]					),
.twu_data_ready                     (twu_data_ready[PTE_LEVEL-1:0]     	),
//.mbuf_twu_have                      (mbuf_twu_have[0]           	),
.acc_err_twu_grant                  (acc_err_grant_sel[0]			),
.pgflt_twu_grant                    (pgflt_twu_grant  			)
);


ptw_mbuf #(
.VADDR_WIDTH                         (VADDR_WIDTH        ),
.PADDR_WIDTH                         (PADDR_WIDTH        ),
.VPN_WIDTH                           (VPN_WIDTH          ),
.PPN_WIDTH                           (PPN_WIDTH          ),
.FLG_WIDTH                           (FLG_WIDTH          ),
.ASID_WIDTH                          (ASID_WIDTH         ),
.PGS_WIDTH                           (PGS_WIDTH          ),
.PTE_LEVEL                           (PTE_LEVEL          ),
.ID_WIDTH                            (ID_WIDTH           ),
.TYPE_WIDTH                          (TYPE_WIDTH         ),
.VPN_PERLEL                          (VPN_PERLEL         ),
.TAG_WIDTH                           (TAG_WIDTH          ),
.RDATA_WIDTH                         (DATA_WIDTH         ),
.MBUF_ID_WIDTH                       (MBUF_ID_WIDTH      )
) u_ptw_mbuf(
.forever_cpuclk						(forever_cpuclk				),
.cpurst_b							(cpurst_b					),
.cp0_mmu_icg_en                     (cp0_mmu_icg_en             ),
.pad_yy_icg_scan_en                 (pad_yy_icg_scan_en         ),
			
.twu_mbuf_req						(twu_mbuf_req				),
.twu_mbuf_paddr						(twu_mbuf_paddr				),
.twu_mbuf_vpn						(twu_mbuf_vpn				),
.twu_mbuf_type						(twu_mbuf_type				),
.twu_mbuf_id						(twu_mbuf_id				),
.twu_mbuf_lvl						(twu_mbuf_lvl				),
.twu_mbuf_pmpflg					(twu_mbuf_pmpflg			),
		
.lsu_mmu_data_vld					(lsu_mmu_data_vld			),     
.lsu_mmu_data						(lsu_mmu_data				),         
.lsu_mmu_data_id                     (lsu_mmu_data_id            ),
.lsu_mmu_data_req_grant              (lsu_mmu_data_req_grant     ),
.lsu_mmu_bus_error					(lsu_mmu_bus_error			), 
			
.mmu_lsu_data_req					(mmu_lsu_data_req			),     
.mmu_lsu_data_req_addr				(mmu_lsu_data_req_addr		), 
.mmu_lsu_data_req_id                 (mmu_lsu_data_req_id        ),
.mmu_lsu_data_req_size				(mmu_lsu_data_req_size		),
			
.mbuf_twu_vpn						(mbuf_twu_vpn				),
.mbuf_twu_type						(mbuf_twu_type				),
.mbuf_twu_id						(mbuf_twu_id				),
.mbuf_twu_lvl						(mbuf_twu_lvl				),
.mbuf_twu_data						(mbuf_twu_data				),
.mbuf_twu_pmpflg					(mbuf_twu_pmpflg				),
.mbuf_twu_data_vld					(mbuf_twu_data_vld			),
			
.mbuf_grant							(mbuf_grant					),
//.mbuf_twu_have              		(mbuf_twu_have[3:0]         ),
                                                                 
.mbuf_cache_upd		                (mbuf_cache_upd				),
.mbuf_cache_upd_ppn                 (mbuf_cache_upd_ppn			),
.mbuf_cache_upd_lvl                 (mbuf_cache_upd_lvl			),
.mbuf_cache_upd_vpn                 (mbuf_cache_upd_vpn			),
.mbuf_cache_upd_l1pmpflg            (mbuf_cache_upd_l1pmpflg		),
.mbuf_cache_upd_l2pmpflg            (mbuf_cache_upd_l2pmpflg		),
                                                                 
.tlboper_ptw_abort	                (tlboper_ptw_abort			),
.twu_data_ready                     (twu_data_ready             ),
.mbuf_entry_on_vld                  (mbuf_entry_on_vld 			),
.mbuf_bus_error			        	(mbuf_bus_error             ),
.mbuf_bus_error_type			    (mbuf_bus_error_type        ),
.mbuf_bus_error_id                  (mbuf_bus_error_id          ),
.acc_err_mbuf_grant                 (acc_err_grant_sel[1]       )


);


assign pgflt_vld = twu_l2tlb_ref_pgflt;
assign acc_err_vld = twu_l2tlb_ref_acc_err | mbuf_bus_error | PDE_cache_acc_err_vld;
assign ref_vld = twu_arb_ref_req;

assign acc_err_grant = acc_err_vld;
assign pgflt_grant = pgflt_vld & (!acc_err_vld);
assign ref_grant = ref_vld & (!acc_err_vld) & (!pgflt_vld);


//==============================================================================
//                page fault arbiter
//==============================================================================
assign pgflt_twu_grant = twu_l2tlb_ref_pgflt & pgflt_grant;

logic [ID_WIDTH-1:0]   ptw_l2tlb_pgflt_id  ;
logic [TYPE_WIDTH-1:0] ptw_l2tlb_pgflt_type;

/*
always_comb begin
	case(pgflt_twu_grant)
		1'b1	: begin
			ptw_l2tlb_pgflt_type[TYPE_WIDTH-1:0] = twu_l2tlb_ref_pgflt_type[TYPE_WIDTH-1:0];
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = twu_l2tlb_ref_pgflt_id[ID_WIDTH-1:0];
		end
		default 	: begin
			ptw_l2tlb_pgflt_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
			ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
		end
	endcase
end
*/
assign ptw_l2tlb_pgflt_type[TYPE_WIDTH-1:0] = twu_l2tlb_ref_pgflt_type[TYPE_WIDTH-1:0];
assign ptw_l2tlb_pgflt_id[ID_WIDTH-1:0] = twu_l2tlb_ref_pgflt_id[ID_WIDTH-1:0];


//==============================================================================
//                access fault arbiter
//==============================================================================
assign acc_err_grant_sel[0] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & twu_l2tlb_ref_acc_err & acc_err_grant;
assign acc_err_grant_sel[1] = (!PDE_cache_acc_err_vld) & mbuf_bus_error & acc_err_grant;
assign acc_err_grant_sel[2] = PDE_cache_acc_err_vld & acc_err_grant;

logic [ID_WIDTH-1:0]   ptw_l2tlb_acc_err_id  ;
logic [TYPE_WIDTH-1:0] ptw_l2tlb_acc_err_type;

always_comb begin
	case(acc_err_grant_sel[2:0])
		3'b001	: begin
			ptw_l2tlb_acc_err_type[TYPE_WIDTH-1:0] = twu_l2tlb_ref_acc_err_type[TYPE_WIDTH-1:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = twu_l2tlb_ref_acc_err_id[ID_WIDTH-1:0];
		end
		3'b010	: begin
			ptw_l2tlb_acc_err_type[TYPE_WIDTH-1:0] = mbuf_bus_error_type[TYPE_WIDTH-1:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = mbuf_bus_error_id[ID_WIDTH-1:0];
		end	
        3'b100	: begin
			ptw_l2tlb_acc_err_type[TYPE_WIDTH-1:0] = PDE_cache_acc_err_type[TYPE_WIDTH-1:0];
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = PDE_cache_acc_err_id[ID_WIDTH-1:0];
		end
		default 	: begin
			ptw_l2tlb_acc_err_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
			ptw_l2tlb_acc_err_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
		end
	endcase
end




//==============================================================================
//                  Refill arbiter
//==============================================================================
assign ptw_arb_req = twu_arb_ref_req & (!arb_ptw_mask) & (!tlboper_ptw_abort) & ref_grant;
assign refill_arb_twu_grant = ptw_arb_req & arb_ptw_grant;

logic [TYPE_WIDTH-1:0] ptw_arb_ref_type;
logic [ID_WIDTH-1:0]   ptw_arb_ref_id  ;
/*
always_comb begin
	case(refill_arb_twu_grant)
		1'b1	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = twu_arb_ref_data_din[DATA_WIDTH-1:0];
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_arb_ref_tag_din[TAG_WIDTH-1:0];
			ptw_arb_ref_pgs[PGS_WIDTH-1:0] = twu_arb_ref_pgs[PGS_WIDTH-1:0];
			ptw_arb_ref_type[TYPE_WIDTH-1:0] = twu_arb_ref_type[TYPE_WIDTH-1:0];
			ptw_arb_ref_id[ID_WIDTH-1:0] = twu_arb_ref_id[ID_WIDTH-1:0];
		end
		default	: begin
			ptw_arb_ref_data_din[DATA_WIDTH-1:0] = {DATA_WIDTH{1'b0}};
			ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = {TAG_WIDTH{1'b0}};
			ptw_arb_ref_pgs[PGS_WIDTH-1:0] = {PGS_WIDTH{1'b0}};
			ptw_arb_ref_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
			ptw_arb_ref_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
		end
	endcase
end
*/
assign ptw_arb_ref_data_din[DATA_WIDTH-1:0] = twu_arb_ref_data_din[DATA_WIDTH-1:0];
assign ptw_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_arb_ref_tag_din[TAG_WIDTH-1:0];
assign ptw_arb_ref_pgs[PGS_WIDTH-1:0] = twu_arb_ref_pgs[PGS_WIDTH-1:0];
assign ptw_arb_ref_type[TYPE_WIDTH-1:0] = twu_arb_ref_type[TYPE_WIDTH-1:0];
assign ptw_arb_ref_id[ID_WIDTH-1:0] = twu_arb_ref_id[ID_WIDTH-1:0];



logic [TYPE_WIDTH-1:0] ptw_l2tlb_ref_type;
logic [ID_WIDTH-1:0]   ptw_l2tlb_ref_id  ;

assign ptw_l2tlb_ref_type[TYPE_WIDTH-1:0] = ptw_arb_ref_type[TYPE_WIDTH-1:0];
assign ptw_l2tlb_ref_id[ID_WIDTH-1:0] = ptw_arb_ref_id[ID_WIDTH-1:0];
		
always_comb begin
	case({pgflt_grant,acc_err_grant,ref_grant})
		3'b100 :begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = ptw_l2tlb_pgflt_id[ID_WIDTH-1:0];
				ptw_l2tlb_type[TYPE_WIDTH-1:0] = ptw_l2tlb_pgflt_type[TYPE_WIDTH-1:0];
				end
		3'b010 :begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = ptw_l2tlb_acc_err_id[ID_WIDTH-1:0];
				ptw_l2tlb_type[TYPE_WIDTH-1:0] = ptw_l2tlb_acc_err_type[TYPE_WIDTH-1:0];
				end
		3'b001 :begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = ptw_l2tlb_ref_id[ID_WIDTH-1:0];
				ptw_l2tlb_type[TYPE_WIDTH-1:0] = ptw_l2tlb_ref_type[TYPE_WIDTH-1:0];
				end
		default:begin
				ptw_l2tlb_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
				ptw_l2tlb_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
				end
	endcase
end

assign ptw_l2tlb_flg = ptw_arb_ref_data_din[FLG_WIDTH-1:0];
assign ptw_l1tlb_id = ptw_l2tlb_id;

assign ptw_l2tlb_ref_data_vld = refill_arb_twu_grant;
assign ptw_l2tlb_ref_pgflt = pgflt_grant;
assign ptw_l2tlb_ref_acc_err = acc_err_grant;

assign ptw_l2tlb_cmplt = ptw_l2tlb_ref_data_vld | ptw_l2tlb_ref_pgflt | ptw_l2tlb_ref_acc_err;

logic ptw_ref_dtlb_sel;
logic ptw_ref_itlb_sel;

assign ptw_ref_dtlb_sel = ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b010 | ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b110;
assign ptw_ref_itlb_sel = ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b011;

//to l1tlb
assign ptw_l1dtlb_ref_pa_vld = ptw_l2tlb_ref_data_vld & ptw_ref_dtlb_sel;
assign ptw_l1dtlb_cmplt = ptw_l2tlb_cmplt & ptw_ref_dtlb_sel;
assign ptw_l1dtlb_ref_vpn = ptw_arb_ref_tag_din[46:20];
assign ptw_l1dtlb_ref_pgs = ptw_arb_ref_pgs[2:0];
assign ptw_l1dtlb_ref_ppn = ptw_arb_ref_data_din[41:14];
assign ptw_l1dtlb_ref_flg = ptw_arb_ref_data_din[FLG_WIDTH-1:0];
assign ptw_l1dtlb_ref_acc_err = ptw_l2tlb_ref_acc_err & ptw_ref_dtlb_sel;
assign ptw_l1dtlb_pgflt  = ptw_l2tlb_ref_pgflt & ptw_ref_dtlb_sel;

assign ptw_l1itlb_ref_pa_vld = ptw_l2tlb_ref_data_vld & ptw_ref_itlb_sel;
assign ptw_l1itlb_cmplt = ptw_l2tlb_cmplt & ptw_ref_itlb_sel;
assign ptw_l1itlb_ref_vpn = ptw_arb_ref_tag_din[46:20];
assign ptw_l1itlb_ref_pgs = ptw_arb_ref_pgs[2:0];
assign ptw_l1itlb_ref_ppn = ptw_arb_ref_data_din[41:14];
assign ptw_l1itlb_ref_flg = ptw_arb_ref_data_din[FLG_WIDTH-1:0];
assign ptw_l1itlb_ref_acc_err = ptw_l2tlb_ref_acc_err & ptw_ref_itlb_sel;
assign ptw_l1itlb_pgflt  = ptw_l2tlb_ref_pgflt & ptw_ref_itlb_sel;

// to l2tlb
assign ptw_l2tlb_ref_vpn = ptw_arb_ref_tag_din[46:20];
assign ptw_l2tlb_ref_pgs = ptw_arb_ref_pgs[2:0];
assign ptw_l2tlb_ref_ppn = ptw_arb_ref_data_din[41:14];

assign ptw_arb_vpn[VPN_WIDTH-1:0] = ptw_arb_ref_tag_din[46:20];

assign l2tlb_miss_cnt = ptw_l2tlb_ref_data_vld & (ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b010 | ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b110 | ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b011 ) & hpcp_mmu_cnt_en;

always_ff@(posedge ptw_clk or negedge cpurst_b) begin
	if(!cpurst_b)
        l2tlb_miss <= 1'b0;
    else if(l2tlb_miss_cnt)
        l2tlb_miss <= 1'b1;
    else if(l2tlb_miss & (!l2tlb_miss_cnt))
        l2tlb_miss <= 1'b0;
end
        
assign mmu_hpcp_jtlb_miss = l2tlb_miss;


`ifndef SYNTHESIS
logic                   ptw_lsu_req_dbg_q ;
logic [PADDR_WIDTH-1:0] ptw_lsu_addr_dbg_q;
logic [MBUF_ID_WIDTH-1:0] ptw_lsu_id_dbg_q;
logic                   ptw_lsu_req_trace_en;

initial begin
	ptw_lsu_req_trace_en = $test$plusargs("PTW_LSU_REQ_TRACE");
end

// PTW->LSU request trace for targeted log parsing.
// Runtime-gated and synthesis-excluded; includes id/grant so request stability
// can be checked while req waits for grant.
always_ff @(posedge ptw_clk or negedge cpurst_b) begin
	if(!cpurst_b) begin
		ptw_lsu_req_dbg_q  <= 1'b0;
		ptw_lsu_addr_dbg_q <= {PADDR_WIDTH{1'b0}};
        ptw_lsu_id_dbg_q   <= {MBUF_ID_WIDTH{1'b0}};
	end else begin
		if(ptw_lsu_req_trace_en
		   && mmu_lsu_data_req
		   && (!ptw_lsu_req_dbg_q
               || (mmu_lsu_data_req_addr != ptw_lsu_addr_dbg_q)
               || (mmu_lsu_data_req_id != ptw_lsu_id_dbg_q))) begin
			$display("[%0t][PTW LSU REQ] addr=0x%010h id=0x%0h size=%0b grant=%0b satp_base=0x%07h",
			         $time, mmu_lsu_data_req_addr, mmu_lsu_data_req_id, mmu_lsu_data_req_size,
                     lsu_mmu_data_req_grant, regs_ptw_satp_ppn);
		end
		ptw_lsu_req_dbg_q <= mmu_lsu_data_req;
		if(mmu_lsu_data_req) begin
			ptw_lsu_addr_dbg_q <= mmu_lsu_data_req_addr;
            ptw_lsu_id_dbg_q   <= mmu_lsu_data_req_id;
        end
	end
end
`endif

// synopsys translate_off
logic mmu_itlb_dbg_en;

initial begin
  mmu_itlb_dbg_en = $test$plusargs("MMU_ITLB_DBG");
end

always_ff @(posedge ptw_clk or negedge cpurst_b) begin
  if (!cpurst_b) begin
  end else if (mmu_itlb_dbg_en
               && (l2tlb_ptw_req
                   || ptw_l2tlb_cmplt
                   || ptw_l1itlb_cmplt
                   || ptw_l1itlb_ref_pa_vld
                   || ptw_l1itlb_pgflt
                   || ptw_l1itlb_ref_acc_err
                   || arb_ptw_grant
                   || ptw_arb_req
                   || pgflt_grant
                   || acc_err_grant
                   || ref_grant
                   || refill_arb_twu_grant
                   || twu_arb_ref_req
                   || twu_mbuf_req)) begin
    $display("[MMU_ITLB_DBG][PTW] t=%0t l2_req=%0b l2_type=0x%0h l2_id=0x%02h l2_vpn=0x%07h ready=%0b arb_req=%0b arb_grant=%0b arb_mask=%0b ref_vld=%0b ref_grant=%0b pgflt_vld=%0b pgflt_grant=%0b acc_vld=%0b acc_grant=%0b twu_ref_req=0x%0h refill_grant=0x%0h arb_ref_type=0x%0h arb_ref_id=0x%02h cmplt=%0b cmplt_type=0x%0h cmplt_id=0x%02h data=%0b pgflt=%0b acc=%0b l1i_cmplt=%0b l1i_pavld=%0b l1i_pgflt=%0b l1i_acc=%0b",
             $time,
             l2tlb_ptw_req,
             l2tlb_ptw_type,
             l2tlb_ptw_id,
             l2tlb_ptw_vpn,
             ptw_jtlb_ready,
             ptw_arb_req,
             arb_ptw_grant,
             arb_ptw_mask,
             ref_vld,
             ref_grant,
             pgflt_vld,
             pgflt_grant,
             acc_err_vld,
             acc_err_grant,
             twu_arb_ref_req,
             refill_arb_twu_grant,
             ptw_arb_ref_type,
             ptw_arb_ref_id,
             ptw_l2tlb_cmplt,
             ptw_l2tlb_type,
             ptw_l2tlb_id,
             ptw_l2tlb_ref_data_vld,
             ptw_l2tlb_ref_pgflt,
             ptw_l2tlb_ref_acc_err,
             ptw_l1itlb_cmplt,
             ptw_l1itlb_ref_pa_vld,
             ptw_l1itlb_pgflt,
             ptw_l1itlb_ref_acc_err);
  end
end
// synopsys translate_on

//assign ptw_l2tlb_id = ptw_rsp_id_q;
//assign ptw_l2tlb_type[TYPE_WIDTH-1:0] = ptw_rsp_type_q[TYPE_WIDTH-1:0];
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
//                            & (ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b010 | ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b110);
//assign ptw_l1dtlb_cmplt = ptw_rsp_cmplt_q
//                       & (ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b010 | ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b110);
//assign ptw_l1dtlb_ref_vpn = ptw_rsp_tag_q[46:20];
//assign ptw_l1dtlb_ref_pgs = ptw_rsp_pgs_q[2:0];
//assign ptw_l1dtlb_ref_ppn = ptw_rsp_data_q[41:14];
//assign ptw_l1dtlb_ref_flg = ptw_rsp_data_q[13:0];
//assign ptw_l1dtlb_ref_acc_err = ptw_rsp_acc_err_q
//                             & (ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b010 | ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b110);
//assign ptw_l1dtlb_pgflt  = ptw_rsp_pgflt_q
//                        & (ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b010 | ptw_rsp_type_q[TYPE_WIDTH-1:0] == 3'b110);
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
//assign l2tlb_miss_cnt = ptw_l2tlb_ref_data_vld & (ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b010 | ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b110 | ptw_l2tlb_type[TYPE_WIDTH-1:0] == 3'b011 ) & hpcp_mmu_cnt_en;
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
