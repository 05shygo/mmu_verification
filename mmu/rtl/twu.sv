module twu #(
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
    parameter DATA_WIDTH  = 64,

// VPN width per level
    parameter VPN_PERLEL  = VPN_WIDTH/PTE_LEVEL,

// Valid + VPN + ASID + PageSize + Global
    parameter TAG_WIDTH   = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,
    parameter RDATA_WIDTH = PPN_WIDTH+FLG_WIDTH

) (
//!******************************************
//! Clock and Reset
//!******************************************
    input  logic                   forever_cpuclk,
    input  logic                   cpurst_b,
    input  logic                   refill_arb_twu_grant,

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

    input  logic [ASID_WIDTH-1:0]  regs_ptw_cur_asid,
    input  logic [PPN_WIDTH-1:0]   regs_ptw_satp_ppn,

//!******************************************
//! xbar Request
//!******************************************
    input  logic                   xbar_twu_req,
    input  logic [PTE_LEVEL-2:0]   xbar_twu_hit_level,
    input  logic [PPN_WIDTH-1:0]   xbar_twu_ppn,
    input  logic [3:0]             xbar_twu_l1pmpflg,
    input  logic [VPN_WIDTH-1:0]   xbar_twu_vpn,
    input  logic [TYPE_WIDTH-1:0]  xbar_twu_type,
    input  logic [ID_WIDTH-1:0]    xbar_twu_id,

//!******************************************
//! mbuf Request
//!******************************************
//input logic 		mbuf_twu_bus_error,
    input  logic [VPN_WIDTH-1:0]   mbuf_twu_vpn,
    input  logic [TYPE_WIDTH-1:0]  mbuf_twu_type,
    input  logic [ID_WIDTH-1:0]    mbuf_twu_id,
    input  logic [DATA_WIDTH-1:0]  mbuf_twu_data,
	input  logic [7:0]             mbuf_twu_pmpflg,
    input  logic                   mbuf_twu_data_vld,
    input  logic                   mbuf_grant,
    input  logic [PTE_LEVEL-1:0]   mbuf_twu_lvl,

//!******************************************
//! sysmap and pmp
//!******************************************
    input  logic [4:0]             sysmap_mmu_flgx1,
    input  logic [4:0]             sysmap_mmu_flgx2,
    input  logic [4:0]             sysmap_mmu_flgx3,
    input  logic [7:0]             sysmap_mmu_hitx1,
    input  logic [7:0]             sysmap_mmu_hitx2,
    input  logic [7:0]             sysmap_mmu_hitx3,
    input  logic [3:0]             pmp_mmu_flg,

//!******************************************
//! TWU to MBUF
//!******************************************
    output logic                   twu_mbuf_req,
    output logic [PADDR_WIDTH-1:0] twu_mbuf_paddr,
    output logic [VPN_WIDTH-1:0]   twu_mbuf_vpn,
    output logic [TYPE_WIDTH-1:0]  twu_mbuf_type,
    output logic [ID_WIDTH-1:0]    twu_mbuf_id,
    output logic [PTE_LEVEL-1:0]   twu_mbuf_lvl,
    output logic [7:0]             twu_mbuf_pmpflg,
//output logic		twu_mbuf_mask,

//!******************************************
//! TWU to sysmap and pmp
//!******************************************
    output logic [PPN_WIDTH-1:0]   mmu_pmp_pa,
    output logic                   mmu_pmp_fecth,
    output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax1,
    output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax2,
    output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax3,

//!******************************************
//! TWU to arbiter
//!******************************************
    output logic                   twu_arb_ref_req,
    output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,
    output logic [TAG_WIDTH-1:0]   twu_arb_ref_tag_din,
    output logic [PGS_WIDTH-1:0]   twu_arb_ref_pgs,
    output logic [TYPE_WIDTH-1:0]  twu_arb_ref_type,
    output logic [ID_WIDTH-1:0]    twu_arb_ref_id,

//!******************************************
//! TWU to L2TLB
//!******************************************
    output logic                   twu_l2tlb_ref_pgflt,
    output logic [ID_WIDTH-1:0]    twu_l2tlb_ref_pgflt_id,
    output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_pgflt_type,
    output logic                   twu_l2tlb_ref_acc_err,
    output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_acc_err_type,
    output logic [ID_WIDTH-1:0]    twu_l2tlb_ref_acc_err_id,
//!******************************************
//! TWU to xbar
//!******************************************
    output logic                   twu_mask,
//output logic 		twu_idle,
    output logic 				   twu_data_ready,

    input  logic                   acc_err_twu_grant,
    input  logic                   pgflt_twu_grant,
    input  logic                   tlboper_ptw_abort
);

logic [1:0]            cp0_priv_mode;
logic                  abort;
logic                  twu_clk_en;
logic                  twu_clk;
logic                  pmp_unit_vld;
logic                  pmp_unit_wait;
logic [VPN_WIDTH-1:0]  pmp_unit_vpn;
logic [TYPE_WIDTH-1:0] pmp_unit_type;
logic [ID_WIDTH-1:0]   pmp_unit_id;
logic [PPN_WIDTH-1:0]  pmp_unit_ppn;
logic [PTE_LEVEL-1:0]  pmp_unit_lvl;
logic [3:0]            pmp_unit_pmpflg;
logic [3:0]            pmp_unit_l1pmpflg;
logic                  pmp_unit_fst_sel;
logic                  pmp_fetch_type;
logic                  pmp_load_type;
logic                  pmp_store_type;
logic                  pmp_pref_type;
logic                  pmp_cp0_mach_mode;
logic                  pmp_unit_deny;
logic                  pmp_mbuf_req;
logic                  acc_err_pmp_unit_grant;
logic [PADDR_WIDTH-1:0] ptw_fst_addr;
logic [PADDR_WIDTH-1:0] ptw_scd_addr;
logic [PADDR_WIDTH-1:0] ptw_thd_addr;
logic                  ptw_addr_fst;
logic                  ptw_addr_scd;
logic                  ptw_addr_thd;
logic [PADDR_WIDTH-1:0] pmp_unit_pa;
logic                  chk_unit_vld;
logic                  chk_unit_wait;
logic [VPN_WIDTH-1:0]  chk_unit_vpn;
logic [TYPE_WIDTH-1:0] chk_unit_type;
logic [ID_WIDTH-1:0]   chk_unit_id;
logic [PTE_LEVEL-1:0]  chk_unit_lvl;
logic [DATA_WIDTH-1:0] chk_unit_data;
logic [3:0]            chk_unit_pmpflg;
logic [8:0]            chk_unit_flg;
logic                  chk_unit_fetch_type;
logic                  chk_unit_load_type;
logic                  chk_unit_store_type;
logic                  chk_unit_cp0_user_mode;
logic                  chk_unit_cp0_supv_mode;
logic                  chk_unit_fst;
logic                  chk_unit_scd;
logic                  chk_unit_thd;
logic                  chk_unit_hit_1g;
logic                  chk_unit_hit_2m;
logic                  chk_unit_leaf_vld;
logic                  chk_unit_page_flt;
logic [PPN_WIDTH-1:0]  chk_unit_ppn;
logic [4:0]            chk_unit_refill_high_flg;
logic                  chk_unit_refill_req;
logic [RDATA_WIDTH-1:0] chk_unit_refill_data;
logic [PTE_LEVEL-1:0]  chk_unit_refill_pgs;
logic [TAG_WIDTH-1:0]  chk_unit_refill_tag;
logic [TYPE_WIDTH-1:0] chk_unit_refill_type;
logic [ID_WIDTH-1:0]   chk_unit_refill_id;
logic                  chk_unit_csr_req;
logic [VPN_WIDTH-1:0]  chk_unit_csr_vpn;
logic [TYPE_WIDTH-1:0] chk_unit_csr_type;
logic [ID_WIDTH-1:0]   chk_unit_csr_id;
logic [DATA_WIDTH-1:0] chk_unit_csr_data;
logic [PTE_LEVEL-1:0]  chk_unit_csr_pgs;
logic                  chk_unit_csr_grant;
logic                  pgflt_chk_unit_grant;
logic                  twu_pgflt_vld;
logic [TYPE_WIDTH-1:0] twu_pgflt_type;
logic [ID_WIDTH-1:0]   twu_pgflt_id;
logic                  twu_acc_err_vld;
logic [TYPE_WIDTH-1:0] twu_acc_err_type;
logic [ID_WIDTH-1:0]   twu_acc_err_id;
logic [VPN_WIDTH-1:0]  csr_vpn;
logic [TYPE_WIDTH-1:0] csr_type;
logic [ID_WIDTH-1:0]   csr_id;
logic [DATA_WIDTH-1:0] csr_data;
logic                  csr_fst;
logic                  csr_scd;
logic [2:0]            ptw_cur_st;
logic [2:0]            ptw_nxt_st;
logic                  csr_idle;
logic [VPN_WIDTH-1:0]  csr_vpn_flop;
logic [TYPE_WIDTH-1:0] csr_type_flop;
logic [ID_WIDTH-1:0]   csr_id_flop;
logic [DATA_WIDTH-1:0] csr_data_flop;
logic [PGS_WIDTH-1:0]  csr_refill_pgs;
logic                  twu_csr_cross;
logic                  twu_crs_1g;
logic                  twu_crs_2m;
logic                  twu_crs_chk;
logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;
logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
logic [4:0]            sysmap_mmu_flg;
logic                  csr_fetch_type;
logic                  csr_refill_req;
logic [RDATA_WIDTH-1:0] csr_refill_data;
logic [TAG_WIDTH-1:0]  csr_refill_tag;
logic [TYPE_WIDTH-1:0] csr_refill_type;
logic [ID_WIDTH-1:0]   csr_refill_id;
logic                  chk_unit_itlb_sel;
logic                  csr_ref_itlb_sel;
logic                  refill_itlb_sel;
logic                  chk_unit_sel;
logic                  csr_ref_sel;
logic [1:0]            refill_grant;
logic                  refill_req;
logic                  refill_csr_grant;
logic                  refill_chk_unit_grant;
logic                  twu_refill_vld;
logic                  twu_refill_idle;
logic [RDATA_WIDTH-1:0] twu_ref_data_din;
logic [TAG_WIDTH-1:0]  twu_ref_tag_din;
logic [PGS_WIDTH-1:0]  twu_ref_pgs;
logic [TYPE_WIDTH-1:0] twu_ref_type;
logic [ID_WIDTH-1:0]   twu_ref_id;

/*
 * Legacy fst/scd/thd pipeline declarations.  The related implementation has
 * been commented out below, so these declarations are also kept commented.
 *
logic [1:0] cp0_priv_mode        ;
logic       fst_chk_cp0_user_mode;
logic       fst_chk_cp0_supv_mode;
logic       fst_pmp_cp0_mach_mode;
logic       scd_chk_cp0_user_mode;
logic       scd_chk_cp0_supv_mode;
logic       scd_pmp_cp0_mach_mode;
logic       thd_chk_cp0_user_mode;
logic       thd_chk_cp0_supv_mode;
logic       thd_pmp_cp0_mach_mode;
//logic				twu_busy             ;
logic                   fst_pmp_vld        ;
logic                   fst_chk_vld        ;
logic                   scd_pmp_vld        ;
logic                   scd_chk_vld        ;
logic                   thd_pmp_vld        ;
logic                   thd_chk_vld        ;
logic                   fst_pmp_wait       ;
logic                   fst_chk_wait       ;
logic                   scd_pmp_wait       ;
logic                   scd_chk_wait       ;
logic                   thd_pmp_wait       ;
logic                   thd_chk_wait       ;
logic [VPN_WIDTH-1:0]   fst_pmp_vpn        ;
logic [TYPE_WIDTH-1:0]  fst_pmp_type       ;
logic [ID_WIDTH-1:0]    fst_pmp_id         ;
logic [VPN_WIDTH-1:0]   scd_pmp_vpn        ;
logic [TYPE_WIDTH-1:0]  scd_pmp_type       ;
logic [ID_WIDTH-1:0]    scd_pmp_id         ;
logic [VPN_WIDTH-1:0]   thd_pmp_vpn        ;
logic [TYPE_WIDTH-1:0]  thd_pmp_type       ;
logic [ID_WIDTH-1:0]    thd_pmp_id         ;
logic [VPN_WIDTH-1:0]   fst_chk_vpn        ;
logic [TYPE_WIDTH-1:0]  fst_chk_type       ;
logic [ID_WIDTH-1:0]    fst_chk_id         ;
logic [DATA_WIDTH-1:0]  fst_chk_data       ;
logic [VPN_WIDTH-1:0]   scd_chk_vpn        ;
logic [TYPE_WIDTH-1:0]  scd_chk_type       ;
logic [ID_WIDTH-1:0]    scd_chk_id         ;
logic [DATA_WIDTH-1:0]  scd_chk_data       ;
logic [VPN_WIDTH-1:0]   thd_chk_vpn        ;
logic [TYPE_WIDTH-1:0]  thd_chk_type       ;
logic [ID_WIDTH-1:0]    thd_chk_id         ;
logic [DATA_WIDTH-1:0]  thd_chk_data       ;
logic                   fst_pmp_fetch_type ;
logic                   fst_pmp_load_type  ;
logic                   fst_pmp_store_type ;
logic                   fst_pmp_pref_type  ;
logic                   scd_pmp_fetch_type ;
logic                   scd_pmp_load_type  ;
logic                   scd_pmp_store_type ;
logic                   scd_pmp_pref_type  ;
logic                   thd_pmp_fetch_type ;
logic                   thd_pmp_load_type  ;
logic                   thd_pmp_store_type ;
logic                   thd_pmp_pref_type  ;
logic                   fst_chk_fetch_type ;
logic                   fst_chk_load_type  ;
logic                   fst_chk_store_type ;
logic                   scd_chk_fetch_type ;
logic                   scd_chk_load_type  ;
logic                   scd_chk_store_type ;
logic                   thd_chk_fetch_type ;
logic                   thd_chk_load_type  ;
logic                   thd_chk_store_type ;
logic                   fst_pmp_deny       ;
logic                   scd_pmp_deny       ;
logic                   thd_pmp_deny       ;
logic                   fst_pmp_mbuf_req   ;
logic [PADDR_WIDTH-1:0] fst_pmp_pa         ;
logic                   scd_pmp_mbuf_req   ;
logic [PADDR_WIDTH-1:0] scd_pmp_pa         ;
logic                   thd_pmp_mbuf_req   ;
logic [PADDR_WIDTH-1:0] thd_pmp_pa         ;
logic [8:0]             fst_chk_flg        ;
logic [8:0]             scd_chk_flg        ;
logic [8:0]             thd_chk_flg        ;
logic                   fst_chk_page_flt   ;
logic                   scd_chk_page_flt   ;
logic                   thd_chk_page_flt   ;
logic                   fst_chk_leaf_vld   ;
logic                   scd_chk_leaf_vld   ;
logic                   thd_chk_leaf_vld   ;
logic                   fst_chk_refill_req ;
logic [RDATA_WIDTH-1:0] fst_chk_refill_date;
logic [TAG_WIDTH-1:0]   fst_chk_refill_tag ;
logic [TYPE_WIDTH-1:0]  fst_chk_refill_type;
logic [ID_WIDTH-1:0]    fst_chk_refill_id  ;
logic                   scd_chk_refill_req ;
logic [RDATA_WIDTH-1:0] scd_chk_refill_date;
logic [TAG_WIDTH-1:0]   scd_chk_refill_tag ;
logic [TYPE_WIDTH-1:0]  scd_chk_refill_type;
logic [ID_WIDTH-1:0]    scd_chk_refill_id  ;
logic                   thd_chk_refill_req ;
logic [RDATA_WIDTH-1:0] thd_chk_refill_date;
logic [TAG_WIDTH-1:0]   thd_chk_refill_tag ;
logic [TYPE_WIDTH-1:0]  thd_chk_refill_type;
logic [ID_WIDTH-1:0]    thd_chk_refill_id  ;
logic                   fst_chk_csr_req    ;
logic [VPN_WIDTH-1:0]   fst_chk_csr_vpn    ;
logic [TYPE_WIDTH-1:0]  fst_chk_csr_type   ;
logic [ID_WIDTH-1:0]    fst_chk_csr_id     ;
logic [DATA_WIDTH-1:0]  fst_chk_csr_data   ;
logic                   scd_chk_csr_req    ;
logic [VPN_WIDTH-1:0]   scd_chk_csr_vpn    ;
logic [TYPE_WIDTH-1:0]  scd_chk_csr_type   ;
logic [ID_WIDTH-1:0]    scd_chk_csr_id     ;
logic [DATA_WIDTH-1:0]  scd_chk_csr_data   ;
//logic				thd_chk_csr_req      ;
//logic	[26:0]		thd_chk_csr_vpn      ;
//logic	[TYPE_WIDTH-1:0]		thd_chk_csr_type     ;
//logic	[5:0]		thd_chk_csr_id       ;
//logic	[63:0]		thd_chk_csr_data     ;
//logic				mbuf_twu_data_vld_reg;
//logic	[26:0]		mbuf_twu_vpn_reg     ;
//logic	[TYPE_WIDTH-1:0]		mbuf_twu_type_reg    ;
//logic	[6:0]		mbuf_twu_id_reg      ;
//logic	[63:0]		mbuf_twu_data_reg    ;
//logic	[2:0]		mbuf_twu_lvl_reg     ;
//logic				data_reg_cmplt       ;
logic                  twu_pgflt_vld        ;
logic [TYPE_WIDTH-1:0] twu_pgflt_type       ;
logic [ID_WIDTH-1:0]   twu_pgflt_id         ;
logic                  twu_acc_err_vld      ;
logic [TYPE_WIDTH-1:0] twu_acc_err_type     ;
logic [ID_WIDTH-1:0]   twu_acc_err_id       ;
logic                  pgflt_thd_chk_grant  ;
logic                  pgflt_scd_chk_grant  ;
logic                  pgflt_fst_chk_grant  ;
logic                  acc_err_thd_pmp_grant;
logic                  acc_err_scd_pmp_grant;
logic                  acc_err_fst_pmp_grant;
logic                  fst_pmp_itlb_sel     ;
logic                  scd_pmp_itlb_sel     ;
logic                  thd_pmp_itlb_sel     ;
logic                  pmp_itlb_sel         ;
logic [2:0]            pmp_grant            ;
logic                  fst_pmp_grant        ;
logic                  scd_pmp_grant        ;
logic                  thd_pmp_grant        ;
logic                  csr_req              ;
logic                  fst_csr_itlb_sel     ;
logic                  scd_csr_itlb_sel     ;
logic                  csr_itlb_sel         ;
logic [1:0]            csr_grant            ;
logic                  scd_csr_grant        ;
logic                  fst_csr_grant        ;
logic [VPN_WIDTH-1:0]  csr_vpn              ;
logic [TYPE_WIDTH-1:0] csr_type             ;
logic [ID_WIDTH-1:0]   csr_id               ;
logic [DATA_WIDTH-1:0] csr_data             ;
logic [2:0]            ptw_cur_st           ;
logic [2:0]            ptw_nxt_st           ;
logic                  csr_idle             ;
//logic				csr_busy  	         ;
logic                   twu_crs1_1g     ;
logic                   twu_crs2_1g     ;
logic                   twu_crs1_2m     ;
logic                   twu_crs2_2m     ;
logic                   twu_crs2_chk    ;
logic [VPN_WIDTH-1:0]   csr_vpn_flop    ;
logic [TYPE_WIDTH-1:0]  csr_type_flop   ;
logic [ID_WIDTH-1:0]    csr_id_flop     ;
logic [PADDR_WIDTH-1:0] twu_sysmap_adder;
logic [DATA_WIDTH-1:0]  csr_data_flop   ;
logic [PGS_WIDTH-1:0]   csr_refill_pgs  ;
logic [7:0]             twu_hit_num     ;
logic                   twu_csr_cross   ;
logic                   csr_fetch_type  ;
logic                   csr_refill_req  ;
logic [RDATA_WIDTH-1:0] csr_refill_data ;
logic [TAG_WIDTH-1:0]   csr_refill_tag  ;
logic [TYPE_WIDTH-1:0]  csr_refill_type ;
logic [ID_WIDTH-1:0]    csr_refill_id   ;
//logic				twu_arb_ref_req      ;
logic fst_chk_itlb_sel;
logic scd_chk_itlb_sel;
logic thd_chk_itlb_sel;
//logic				csr_itlb_sel         ;
logic                   refill_itlb_sel     ;
logic [3:0]             refill_grant        ;
logic                   refill_csr_grant    ;
logic                   refill_fst_chk_grant;
logic                   refill_scd_chk_grant;
logic                   refill_thd_chk_grant;
logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;
logic [PPN_WIDTH-1:0]   scd_pmp_ppn         ;
logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;
logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;
logic [PPN_WIDTH-1:0]   thd_pmp_ppn         ;
//logic	[TYPE_WIDTH-1:0]			twu_l2tlb_ref_pgflt_type;
//logic	[6:0]			twu_l2tlb_ref_pgflt_id;


//logic   [TYPE_WIDTH-1:0]                   twu_l2tlb_ref_acc_err_type;
//logic   [6:0]                   twu_l2tlb_ref_acc_err_id;
//logic	[5:0]			csr_id			;
logic ptw_chk_cross   ;
logic ptw_crs2_1g     ;
logic ptw_crs2_2m     ;
logic twu_crs_1g      ;
logic twu_crs_2m      ;
logic twu_crs_chk     ;
logic csr_ref_itlb_sel;
logic fst_ref_sel     ;
logic scd_ref_sel     ;
logic thd_ref_sel     ;
logic csr_ref_sel     ;
logic fst_csr_sel     ;
logic scd_csr_sel     ;
logic fst_pmp_sel     ;
logic scd_pmp_sel     ;
logic thd_pmp_sel     ;
logic fst_chk_ready   ;
logic scd_chk_ready   ;
logic thd_chk_ready   ;
//logic   [2:0]       twu_data_ready;
logic twu_clk_en    ;
logic twu_clk       ;
logic twu_refill_vld;
logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;
logic  			        thd_chk_refill_no_maee_sel;
logic [RDATA_WIDTH-1:0] twu_ref_data_din;
logic [TAG_WIDTH-1:0]   twu_ref_tag_din;
logic [PGS_WIDTH-1:0]   twu_ref_pgs;
logic [TYPE_WIDTH-1:0]  twu_ref_type;
logic [ID_WIDTH-1:0]    twu_ref_id;
logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;
logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
logic [4:0] 			sysmap_mmu_flg;
logic [3:0]             fst_chk_l1pmpflg;
logic [3:0]             scd_pmp_l1pmpflg;
*/

assign twu_clk_en = 1'b1;
// &Instance("gated_clk_cell", "x_ptw_gateclk"); @59
gated_clk_cell  x_twu_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (twu_clk           ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (twu_clk_en        ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);


assign cp0_priv_mode[1:0] = cp0_mmu_mprv ? cp0_mmu_mpp[1:0]
                                         : cp0_yy_priv_mode[1:0];


assign twu_mask = pmp_unit_wait
                | chk_unit_vld & (!chk_unit_leaf_vld) & (!chk_unit_page_flt);

//assign twu_busy = mbuf_twu_have
//				| fst_pmp_vld
//				| fst_chk_vld
//				| scd_pmp_vld
//				| scd_chk_vld
//				| thd_pmp_vld
//				| thd_chk_vld
//				| csr_busy;

//assign twu_idle = ~ twu_busy;

assign abort = tlboper_ptw_abort;
/*
//==============================================================================
//                  FST PMP
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		fst_pmp_vld <= 1'b0;
	else if(abort)
		fst_pmp_vld <= 1'b0;
	else if(fst_pmp_wait)
		fst_pmp_vld <= fst_pmp_vld;
	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b00)& (!fst_pmp_wait))
		fst_pmp_vld <= 1'b1;
	else
		fst_pmp_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		fst_pmp_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		fst_pmp_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		fst_pmp_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
	end else if(xbar_twu_req & (xbar_twu_hit_level == 3'b000) & (!fst_pmp_wait))begin
		fst_pmp_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
		fst_pmp_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
		fst_pmp_id[ID_WIDTH-1:0] <= xbar_twu_id[ID_WIDTH-1:0];
	end
end

//!******************************************
//! PMP chek
//!******************************************
assign fst_pmp_fetch_type = fst_pmp_type[TYPE_WIDTH-1:0] == 3'b011;
assign fst_pmp_load_type  = fst_pmp_type[TYPE_WIDTH-1:0] == 3'b010;
assign fst_pmp_store_type = fst_pmp_type[TYPE_WIDTH-1:0] == 3'b110;
assign fst_pmp_pref_type  = fst_pmp_type[TYPE_WIDTH-1:0] == 3'b100;

assign fst_pmp_cp0_mach_mode = fst_pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;

assign fst_pmp_deny = (fst_pmp_fetch_type && !pmp_mmu_flg[2]
                    || fst_pmp_load_type  && !pmp_mmu_flg[0]
                    || fst_pmp_store_type && !pmp_mmu_flg[1]
                    || fst_pmp_pref_type  && !pmp_mmu_flg[0])
                    // L-bit for M-Mode
                       && !(fst_pmp_cp0_mach_mode && !pmp_mmu_flg[3]);
//!******************************************
//! write MBUF
//!******************************************
assign fst_pmp_mbuf_req = fst_pmp_vld & (~fst_pmp_deny) & fst_pmp_grant;
assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};

//!******************************************
//! wait
//!******************************************
assign fst_pmp_wait =    fst_pmp_vld & (!fst_pmp_grant)
					   | fst_pmp_mbuf_req & (!mbuf_grant)
					   | fst_pmp_vld & fst_pmp_grant & fst_pmp_deny & (!acc_err_fst_pmp_grant);




//==============================================================================
//                  FST CHK
//==============================================================================

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		fst_chk_vld <= 1'b0;
	else if(abort)
		fst_chk_vld <= 1'b0;
	else if(fst_chk_wait)
		fst_chk_vld <= fst_chk_vld;
	else if(mbuf_twu_data_vld & mbuf_twu_lvl[2]& (!fst_chk_wait))
		fst_chk_vld <= 1'b1;
//	else if(mbuf_twu_data_vld_reg & mbuf_twu_lvl_reg[2]& (!fst_chk_wait))
//		fst_chk_vld <= 1'b1;
	else
		fst_chk_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		fst_chk_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		fst_chk_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		fst_chk_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		fst_chk_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
		fst_chk_l1pmpflg[3:0] <= {4'b0};
	end else if(mbuf_twu_data_vld & mbuf_twu_lvl[2] & (!fst_chk_wait))begin
		fst_chk_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
		fst_chk_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
		fst_chk_id[ID_WIDTH-1:0] <= mbuf_twu_id[ID_WIDTH-1:0];
		fst_chk_data[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
		fst_chk_l1pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
	end
end

//!******************************************
//! Page fault
//!******************************************
assign fst_chk_flg[8:0] = {fst_chk_data[9:6], fst_chk_data[4:0]};
assign fst_chk_fetch_type = fst_chk_type[TYPE_WIDTH-1:0] == 3'b011;
assign fst_chk_load_type  = fst_chk_type[TYPE_WIDTH-1:0] == 3'b010;
assign fst_chk_store_type = fst_chk_type[TYPE_WIDTH-1:0] == 3'b110;

assign fst_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
                                      : cp0_priv_mode[1:0] == 2'b00;
assign fst_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
                                      : cp0_priv_mode[1:0] == 2'b01;

assign fst_chk_page_flt =  (!fst_chk_flg[0]                       // not valid
						||  !(fst_chk_flg[1] || cp0_mmu_mxr && fst_chk_flg[3])
								&& fst_chk_flg[2]         // write only
						||  (!fst_chk_flg[1] && fst_chk_load_type     // match R
							&& !(cp0_mmu_mxr && fst_chk_flg[3])
						|| !fst_chk_flg[2] && fst_chk_store_type     // match W
						|| !fst_chk_flg[3] && fst_chk_fetch_type     // match X
						||  fst_chk_flg[4] && fst_chk_cp0_supv_mode && !cp0_mmu_sum // S->U
						|| !fst_chk_flg[4] && fst_chk_cp0_user_mode      // U->S
						|| !fst_chk_flg[5]                       // A bit volation
						|| !fst_chk_flg[6] && fst_chk_store_type     // D bit volation
						|| fst_chk_data[27:10] != 18'b0 // 1g align
							) && fst_chk_leaf_vld);

assign fst_chk_leaf_vld = fst_chk_flg[0] && (fst_chk_flg[1] || fst_chk_flg[3]);

//!******************************************
//! refill
//!******************************************
assign fst_chk_refill_req = fst_chk_vld & fst_chk_leaf_vld & cp0_mmu_maee & (!fst_chk_page_flt);
assign fst_chk_refill_data[RDATA_WIDTH-1:0] = {fst_chk_data[37:10],fst_chk_data[63:59],fst_chk_data[9:6],fst_chk_data[4:0]};
assign fst_chk_refill_tag[TAG_WIDTH-1:0] = {1'b1,fst_chk_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],3'b100,fst_chk_data[5]};
assign fst_chk_refill_type[TYPE_WIDTH-1:0] = fst_chk_type[TYPE_WIDTH-1:0];
assign fst_chk_refill_id[ID_WIDTH-1:0] = fst_chk_id[ID_WIDTH-1:0];

//!******************************************
//! CSR
//!******************************************
assign fst_chk_csr_req = fst_chk_vld &  fst_chk_leaf_vld & (!cp0_mmu_maee) & (!fst_chk_page_flt);
assign fst_chk_csr_vpn[VPN_WIDTH-1:0] = fst_chk_vpn[VPN_WIDTH-1:0];
assign fst_chk_csr_type[TYPE_WIDTH-1:0] = fst_chk_type[TYPE_WIDTH-1:0];
assign fst_chk_csr_id[ID_WIDTH-1:0] = fst_chk_id[ID_WIDTH-1:0];
assign fst_chk_csr_data[DATA_WIDTH-1:0] = fst_chk_data[DATA_WIDTH-1:0];

//!******************************************
//! wait
//!******************************************
assign fst_chk_wait =    fst_chk_vld & scd_pmp_wait & (!fst_chk_leaf_vld) & (!fst_chk_page_flt)
					  |  fst_chk_vld & fst_chk_leaf_vld & (!fst_chk_page_flt) & cp0_mmu_maee & (!refill_fst_chk_grant)
					  |  fst_chk_vld & fst_chk_page_flt & (!pgflt_fst_chk_grant)
					  |	 fst_chk_vld & fst_chk_leaf_vld & (!fst_chk_page_flt) & (!cp0_mmu_maee) & (!fst_csr_grant);


//==============================================================================
//                  SCD PMP
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		scd_pmp_vld <= 1'b0;
	else if(abort)
		scd_pmp_vld <= 1'b0;
	else if(scd_pmp_wait)
		scd_pmp_vld <= scd_pmp_vld;
	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b10) & (!scd_pmp_wait))
		scd_pmp_vld <= 1'b1;
	else if(fst_chk_vld & (!fst_chk_leaf_vld) & (!fst_chk_page_flt) & (!scd_pmp_wait))
		scd_pmp_vld <= 1'b1;
	else
		scd_pmp_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		scd_pmp_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		scd_pmp_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		scd_pmp_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		scd_pmp_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
		scd_pmp_l1pmpflg[3:0] <= {4'b0};
	end	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b10) & (!scd_pmp_wait))begin
		scd_pmp_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
		scd_pmp_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
		scd_pmp_id[ID_WIDTH-1:0] <= xbar_twu_id[ID_WIDTH-1:0];
		scd_pmp_ppn[PPN_WIDTH-1:0] <= xbar_twu_ppn[PPN_WIDTH-1:0];
		scd_pmp_l1pmpflg[3:0] <= {4'b0};
	end else if(fst_chk_vld & (!fst_chk_leaf_vld) & (!fst_chk_page_flt) & (!scd_pmp_wait))begin
		scd_pmp_vpn[VPN_WIDTH-1:0] <= fst_chk_vpn[VPN_WIDTH-1:0];
		scd_pmp_type[TYPE_WIDTH-1:0] <= fst_chk_type[TYPE_WIDTH-1:0];
		scd_pmp_id[ID_WIDTH-1:0] <= fst_chk_id[ID_WIDTH-1:0];
		scd_pmp_ppn[PPN_WIDTH-1:0] <= fst_chk_data[37:10];
		scd_pmp_l1pmpflg[3:0] <= fst_chk_l1pmpflg[3:0];
	end
end

//!******************************************
//! PMP chek
//!******************************************
assign scd_pmp_fetch_type = scd_pmp_type[TYPE_WIDTH-1:0] == 3'b011;
assign scd_pmp_load_type  = scd_pmp_type[TYPE_WIDTH-1:0] == 3'b010;
assign scd_pmp_store_type = scd_pmp_type[TYPE_WIDTH-1:0] == 3'b110;
assign scd_pmp_pref_type  = scd_pmp_type[TYPE_WIDTH-1:0] == 3'b100;

assign scd_pmp_cp0_mach_mode = scd_pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;


assign scd_pmp_deny = (scd_pmp_fetch_type && !pmp_mmu_flg[2]
                    || scd_pmp_load_type  && !pmp_mmu_flg[0]
                    || scd_pmp_store_type && !pmp_mmu_flg[1]
                    || scd_pmp_pref_type  && !pmp_mmu_flg[0])
                    // L-bit for M-Mode
                       && !(scd_pmp_cp0_mach_mode && !pmp_mmu_flg[3]);
//!******************************************
//! write MBUF
//!******************************************
assign scd_pmp_mbuf_req = scd_pmp_vld & (!scd_pmp_deny) & scd_pmp_grant;
assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};

//!******************************************
//! wait
//!******************************************
assign scd_pmp_wait =    scd_pmp_vld & (!scd_pmp_grant)
					   | scd_pmp_mbuf_req & (!mbuf_grant)
					   | scd_pmp_vld & scd_pmp_grant & scd_pmp_deny & (!acc_err_scd_pmp_grant);




//==============================================================================
//                  SCD CHK
//==============================================================================

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		scd_chk_vld <= 1'b0;
	else if(abort)
		scd_chk_vld <= 1'b0;
	else if(scd_chk_wait)
		scd_chk_vld <= scd_chk_vld;
	else if(mbuf_twu_data_vld & mbuf_twu_lvl[1] & (!scd_chk_wait))
		scd_chk_vld <= 1'b1;
	else
		scd_chk_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		scd_chk_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		scd_chk_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		scd_chk_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		scd_chk_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
	end else if(mbuf_twu_data_vld & mbuf_twu_lvl[1] & (!scd_chk_wait))begin
		scd_chk_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
		scd_chk_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
		scd_chk_id[ID_WIDTH-1:0] <= mbuf_twu_id[ID_WIDTH-1:0];
		scd_chk_data[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
	end
end

//!******************************************
//! Page fault
//!******************************************
assign scd_chk_flg[8:0] = {scd_chk_data[9:6], scd_chk_data[4:0]};
assign scd_chk_fetch_type = scd_chk_type[TYPE_WIDTH-1:0] == 3'b011;
assign scd_chk_load_type  = scd_chk_type[TYPE_WIDTH-1:0] == 3'b010;
assign scd_chk_store_type = scd_chk_type[TYPE_WIDTH-1:0] == 3'b110;

assign scd_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
                                   : cp0_priv_mode[1:0] == 2'b00;
assign scd_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
                                      : cp0_priv_mode[1:0] == 2'b01;

assign scd_chk_page_flt =  (!scd_chk_flg[0]                       // not valid
						||  !(scd_chk_flg[1] || cp0_mmu_mxr && scd_chk_flg[3])
								&& scd_chk_flg[2]         // write only
						||  (!scd_chk_flg[1] && scd_chk_load_type     // match R
							&& !(cp0_mmu_mxr && scd_chk_flg[3])
						|| !scd_chk_flg[2] && scd_chk_store_type     // match W
						|| !scd_chk_flg[3] && scd_chk_fetch_type     // match X
						||  scd_chk_flg[4] && scd_chk_cp0_supv_mode && !cp0_mmu_sum // S->U
						|| !scd_chk_flg[4] && scd_chk_cp0_user_mode      // U->S
						|| !scd_chk_flg[5]                       // A bit volation
						|| !scd_chk_flg[6] && scd_chk_store_type     // D bit volation
						|| scd_chk_data[18:10] != 9'b0 // 2m align
							) && scd_chk_leaf_vld);

assign scd_chk_leaf_vld = scd_chk_flg[0] && (scd_chk_flg[1] || scd_chk_flg[3]);

//!******************************************
//! refill
//!******************************************
assign scd_chk_refill_req = scd_chk_vld & scd_chk_leaf_vld & cp0_mmu_maee & (!scd_chk_page_flt);
assign scd_chk_refill_data[RDATA_WIDTH-1:0] = {scd_chk_data[37:10],scd_chk_data[63:59],scd_chk_data[9:6],scd_chk_data[4:0]};
assign scd_chk_refill_tag[TAG_WIDTH-1:0] = {1'b1,scd_chk_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],3'b010,scd_chk_data[5]};
assign scd_chk_refill_type[TYPE_WIDTH-1:0] = scd_chk_type[TYPE_WIDTH-1:0];
assign scd_chk_refill_id[ID_WIDTH-1:0] = scd_chk_id[ID_WIDTH-1:0];

//!******************************************
//! CSR
//!******************************************
assign scd_chk_csr_req = scd_chk_vld & scd_chk_leaf_vld & (!cp0_mmu_maee) & (!scd_chk_page_flt);
assign scd_chk_csr_vpn[VPN_WIDTH-1:0] = scd_chk_vpn[VPN_WIDTH-1:0];
assign scd_chk_csr_type[TYPE_WIDTH-1:0] = scd_chk_type[TYPE_WIDTH-1:0];
assign scd_chk_csr_id[ID_WIDTH-1:0] = scd_chk_id[ID_WIDTH-1:0];
assign scd_chk_csr_data[DATA_WIDTH-1:0] = scd_chk_data[DATA_WIDTH-1:0];

//!******************************************
//! wait
//!******************************************
assign scd_chk_wait =    scd_chk_vld & thd_pmp_wait & (!scd_chk_leaf_vld) & (!scd_chk_page_flt)
					  |  scd_chk_vld & scd_chk_leaf_vld & (!scd_chk_page_flt) & cp0_mmu_maee & (!refill_scd_chk_grant)
					  |  scd_chk_vld & scd_chk_page_flt & (!pgflt_scd_chk_grant)
					  |	 scd_chk_vld & scd_chk_leaf_vld & (!scd_chk_page_flt) & (!cp0_mmu_maee) & (!scd_csr_grant);


//==============================================================================
//                  THD PMP
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		thd_pmp_vld <= 1'b0;
	else if(abort)
		thd_pmp_vld <= 1'b0;
	else if(thd_pmp_wait)
		thd_pmp_vld <= thd_pmp_vld;
	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b01) & (!thd_pmp_wait))
		thd_pmp_vld <= 1'b1;
	else if(scd_chk_vld & (!scd_chk_leaf_vld) & (!scd_chk_page_flt) & (!thd_pmp_wait))
		thd_pmp_vld <= 1'b1;
	else
		thd_pmp_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		thd_pmp_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		thd_pmp_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		thd_pmp_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		thd_pmp_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
	end	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b01) & (!thd_pmp_wait))begin
		thd_pmp_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
		thd_pmp_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
		thd_pmp_id[ID_WIDTH-1:0] <= xbar_twu_id[ID_WIDTH-1:0];
		thd_pmp_ppn[PPN_WIDTH-1:0] <= xbar_twu_ppn[PPN_WIDTH-1:0];
	end else if(scd_chk_vld & (!scd_chk_leaf_vld) & (!scd_chk_page_flt) & (!thd_pmp_wait))begin
		thd_pmp_vpn[VPN_WIDTH-1:0] <= scd_chk_vpn[VPN_WIDTH-1:0];
		thd_pmp_type[TYPE_WIDTH-1:0] <= scd_chk_type[TYPE_WIDTH-1:0];
		thd_pmp_id[ID_WIDTH-1:0] <= scd_chk_id[ID_WIDTH-1:0];
		thd_pmp_ppn[PPN_WIDTH-1:0] <= scd_chk_data[37:10];
	end
end

//!******************************************
//! PMP chek
//!******************************************
assign thd_pmp_fetch_type = thd_pmp_type[TYPE_WIDTH-1:0] == 3'b011;
assign thd_pmp_load_type  = thd_pmp_type[TYPE_WIDTH-1:0] == 3'b010;
assign thd_pmp_store_type = thd_pmp_type[TYPE_WIDTH-1:0] == 3'b110;
assign thd_pmp_pref_type  = thd_pmp_type[TYPE_WIDTH-1:0] == 3'b100;

assign thd_pmp_cp0_mach_mode = thd_pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;


assign thd_pmp_deny = (thd_pmp_fetch_type && !pmp_mmu_flg[2]
                    || thd_pmp_load_type  && !pmp_mmu_flg[0]
                    || thd_pmp_store_type && !pmp_mmu_flg[1]
                    || thd_pmp_pref_type  && !pmp_mmu_flg[0])
                    // L-bit for M-Mode
                       && !(thd_pmp_cp0_mach_mode && !pmp_mmu_flg[3]);
//!******************************************
//! write MBUF
//!******************************************
assign thd_pmp_mbuf_req = thd_pmp_vld & (~thd_pmp_deny) & thd_pmp_grant;
assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8:0],3'b0};

//!******************************************
//! wait
//!******************************************
assign thd_pmp_wait =    thd_pmp_vld & (!thd_pmp_grant)
					   | thd_pmp_mbuf_req & (!mbuf_grant)
					   | thd_pmp_vld & thd_pmp_grant & thd_pmp_deny & (!acc_err_thd_pmp_grant);



//==============================================================================
//                  THD CHK
//==============================================================================

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		thd_chk_vld <= 1'b0;
	else if(abort)
		thd_chk_vld <= 1'b0;
	else if(thd_chk_wait)
		thd_chk_vld <= thd_chk_vld;
	else if(mbuf_twu_data_vld & mbuf_twu_lvl[0] & (!thd_chk_wait))
		thd_chk_vld <= 1'b1;
	else
		thd_chk_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		thd_chk_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		thd_chk_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		thd_chk_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		thd_chk_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
	end else if(mbuf_twu_data_vld & mbuf_twu_lvl[0] & (!thd_chk_wait))begin
		thd_chk_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
		thd_chk_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
		thd_chk_id[ID_WIDTH-1:0] <= mbuf_twu_id[ID_WIDTH-1:0];
		thd_chk_data[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
	end
end

//!******************************************
//! Page fault
//!******************************************
assign thd_chk_flg[8:0] = {thd_chk_data[9:6], thd_chk_data[4:0]};
assign thd_chk_fetch_type = thd_chk_type[TYPE_WIDTH-1:0] == 3'b011;
assign thd_chk_load_type  = thd_chk_type[TYPE_WIDTH-1:0] == 3'b010;
assign thd_chk_store_type = thd_chk_type[TYPE_WIDTH-1:0] == 3'b110;

assign thd_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
                                : cp0_priv_mode[1:0] == 2'b00;
assign thd_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
                                      : cp0_priv_mode[1:0] == 2'b01;

assign thd_chk_page_flt =  (!thd_chk_flg[0]                       // not valid
						||  !(thd_chk_flg[1] || cp0_mmu_mxr && thd_chk_flg[3])
								&& thd_chk_flg[2]         // write only
						||  (!thd_chk_flg[1] && thd_chk_load_type     // match R
							&& !(cp0_mmu_mxr && thd_chk_flg[3])
						|| !thd_chk_flg[2] && thd_chk_store_type     // match W
						|| !thd_chk_flg[3] && thd_chk_fetch_type     // match X
						||  thd_chk_flg[4] && thd_chk_cp0_supv_mode && !cp0_mmu_sum // S->U
						|| !thd_chk_flg[4] && thd_chk_cp0_user_mode      // U->S
						|| !thd_chk_flg[5]                       // A bit volation
						|| !thd_chk_flg[6] && thd_chk_store_type)     // D bit volat
						|| !thd_chk_flg[1] && !thd_chk_flg[3]);


//!******************************************
//! refill
//!******************************************
assign thd_chk_refill_req = thd_chk_vld & (!thd_chk_page_flt);
assign thd_chk_refill_data[RDATA_WIDTH-1:0] = {thd_chk_data[37:10],thd_chk_data[63:59],thd_chk_data[9:6],thd_chk_data[4:0]};
assign thd_chk_refill_tag[TAG_WIDTH-1:0] = {1'b1,thd_chk_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],3'b001,thd_chk_data[5]};
assign thd_chk_refill_type[TYPE_WIDTH-1:0] = thd_chk_type[TYPE_WIDTH-1:0];
assign thd_chk_refill_id[ID_WIDTH-1:0] = thd_chk_id[ID_WIDTH-1:0];

//!******************************************
//! wait
//!******************************************
assign thd_chk_wait =    thd_chk_vld & (~thd_chk_page_flt) & (!refill_thd_chk_grant)
					  |  thd_chk_vld & thd_chk_page_flt & (!pgflt_thd_chk_grant);
*/
//==============================================================================
//                   PMP UNIT
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		pmp_unit_vld <= 1'b0;
	else if(abort)
		pmp_unit_vld <= 1'b0;
	else if(pmp_unit_wait)
		pmp_unit_vld <= pmp_unit_vld;
    else if(chk_unit_vld & (!chk_unit_leaf_vld) & (!chk_unit_page_flt) & (!pmp_unit_wait))
		pmp_unit_vld <= 1'b1;
	else if(xbar_twu_req & (!pmp_unit_wait))
		pmp_unit_vld <= 1'b1;
	else
		pmp_unit_vld <= 1'b0;
end

assign pmp_unit_fst_sel = xbar_twu_hit_level == 2'b00;

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		pmp_unit_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		pmp_unit_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		pmp_unit_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		pmp_unit_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
		pmp_unit_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
		pmp_unit_pmpflg[3:0] <= 4'b0;
	end else if(chk_unit_vld & (!chk_unit_leaf_vld) & (!chk_unit_page_flt) & (!pmp_unit_wait))begin
		pmp_unit_vpn[VPN_WIDTH-1:0] <= chk_unit_vpn[VPN_WIDTH-1:0];
		pmp_unit_type[TYPE_WIDTH-1:0] <= chk_unit_type[TYPE_WIDTH-1:0];
		pmp_unit_id[ID_WIDTH-1:0] <= chk_unit_id[ID_WIDTH-1:0];
		pmp_unit_ppn[PPN_WIDTH-1:0] <= chk_unit_ppn[PPN_WIDTH-1:0];
		pmp_unit_lvl[PTE_LEVEL-1:0] <= {chk_unit_lvl[0],chk_unit_lvl[2:1]};
		pmp_unit_pmpflg[3:0] <= chk_unit_pmpflg[3:0];
	end else if(xbar_twu_req & (!pmp_unit_wait))begin
		pmp_unit_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
		pmp_unit_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
		pmp_unit_id[ID_WIDTH-1:0] <= xbar_twu_id[ID_WIDTH-1:0];
		pmp_unit_ppn[PPN_WIDTH-1:0] <= xbar_twu_ppn[PPN_WIDTH-1:0];
		pmp_unit_lvl[PTE_LEVEL-1:0] <= {pmp_unit_fst_sel,xbar_twu_hit_level[1:0]};
		pmp_unit_pmpflg[3:0] <= xbar_twu_l1pmpflg[3:0];
	end
end

//!******************************************
//! PMP chek
//!******************************************
assign pmp_fetch_type = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b011;
assign pmp_load_type  = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b010;
assign pmp_store_type = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b110;
assign pmp_pref_type  = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b100;

assign pmp_cp0_mach_mode = pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;

assign pmp_unit_deny = (pmp_fetch_type && !pmp_mmu_flg[2]
                    || pmp_load_type  && !pmp_mmu_flg[0]
                    || pmp_store_type && !pmp_mmu_flg[1]
                    || pmp_pref_type  && !pmp_mmu_flg[0])
                    // L-bit for M-Mode
                       && !(pmp_cp0_mach_mode && !pmp_mmu_flg[3]);

//!******************************************
//! write MBUF
//!******************************************
assign pmp_mbuf_req = pmp_unit_vld & (~pmp_unit_deny);

assign ptw_fst_addr[PADDR_WIDTH-1:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],
                                 pmp_unit_vpn[VPN_WIDTH-1:VPN_PERLEL*2], 3'b0};
assign ptw_scd_addr[PADDR_WIDTH-1:0] = {pmp_unit_ppn[PPN_WIDTH-1:0],
                                 pmp_unit_vpn[VPN_PERLEL*2-1:VPN_PERLEL*1], 3'b0};
assign ptw_thd_addr[PADDR_WIDTH-1:0] = {pmp_unit_ppn[PPN_WIDTH-1:0],
                                 pmp_unit_vpn[VPN_PERLEL*1-1:VPN_PERLEL*0], 3'b0};

assign ptw_addr_fst = pmp_unit_lvl[2];
assign ptw_addr_scd = pmp_unit_lvl[1];
assign ptw_addr_thd = pmp_unit_lvl[0];
assign pmp_unit_pa[PADDR_WIDTH-1:0] =
                {PADDR_WIDTH{ptw_addr_fst}} & ptw_fst_addr[PADDR_WIDTH-1:0]
              | {PADDR_WIDTH{ptw_addr_scd}} & ptw_scd_addr[PADDR_WIDTH-1:0]
              | {PADDR_WIDTH{ptw_addr_thd}} & ptw_thd_addr[PADDR_WIDTH-1:0];
assign pmp_unit_l1pmpflg[3:0] = ptw_addr_fst ? pmp_mmu_flg[3:0] : pmp_unit_pmpflg[3:0];

assign twu_mbuf_req = pmp_mbuf_req;
assign twu_mbuf_paddr[PADDR_WIDTH-1:0] = pmp_unit_pa[PADDR_WIDTH-1:0];
assign twu_mbuf_vpn[VPN_WIDTH-1:0] = pmp_unit_vpn[VPN_WIDTH-1:0];
assign twu_mbuf_type[TYPE_WIDTH-1:0] = pmp_unit_type[TYPE_WIDTH-1:0];
assign twu_mbuf_id[ID_WIDTH-1:0] = pmp_unit_id[ID_WIDTH-1:0];
assign twu_mbuf_lvl[PTE_LEVEL-1:0] = pmp_unit_lvl[PTE_LEVEL-1:0];
assign twu_mbuf_pmpflg[7:0] = {pmp_mmu_flg[3:0],pmp_unit_l1pmpflg[3:0]};
//!******************************************
//! PMP
//!******************************************
assign mmu_pmp_pa[PPN_WIDTH-1:0] = pmp_unit_pa[PPN_WIDTH+11:12];
assign mmu_pmp_fecth = pmp_fetch_type;
//!******************************************
//! wait
//!******************************************
assign acc_err_pmp_unit_grant = pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant);
assign pmp_unit_wait =  pmp_mbuf_req & (!mbuf_grant)
					| pmp_unit_vld & pmp_unit_deny & (!acc_err_pmp_unit_grant);

//==============================================================================
//                  CHK UNIT
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)
		chk_unit_vld <= 1'b0;
	else if(abort)
		chk_unit_vld <= 1'b0;
	else if(chk_unit_wait)
		chk_unit_vld <= chk_unit_vld;
	else if(mbuf_twu_data_vld & (!chk_unit_wait))
		chk_unit_vld <= 1'b1;
	else
		chk_unit_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		chk_unit_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		chk_unit_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		chk_unit_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		chk_unit_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
		chk_unit_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
		chk_unit_pmpflg[3:0] <= 4'b0;
	end else if(mbuf_twu_data_vld & (!chk_unit_wait))begin
		chk_unit_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
		chk_unit_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
		chk_unit_id[ID_WIDTH-1:0] <= mbuf_twu_id[ID_WIDTH-1:0];
		chk_unit_lvl[PTE_LEVEL-1:0] <= mbuf_twu_lvl[PTE_LEVEL-1:0];
		chk_unit_data[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
		chk_unit_pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
	end
end

//!******************************************
//! Page fault
//!******************************************
assign chk_unit_flg[8:0] = {chk_unit_data[9:6], chk_unit_data[4:0]};
assign chk_unit_fetch_type = chk_unit_type[TYPE_WIDTH-1:0] == 3'b011;
assign chk_unit_load_type  = chk_unit_type[TYPE_WIDTH-1:0] == 3'b010;
assign chk_unit_store_type = chk_unit_type[TYPE_WIDTH-1:0] == 3'b110;

assign chk_unit_cp0_user_mode = chk_unit_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
                                : cp0_priv_mode[1:0] == 2'b00;
assign chk_unit_cp0_supv_mode = chk_unit_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
                                      : cp0_priv_mode[1:0] == 2'b01;
assign chk_unit_fst = chk_unit_lvl[PTE_LEVEL-1:0] == 3'b100;
assign chk_unit_scd = chk_unit_lvl[PTE_LEVEL-1:0] == 3'b010;
assign chk_unit_thd = chk_unit_lvl[PTE_LEVEL-1:0] == 3'b001;

assign chk_unit_hit_1g = chk_unit_fst && chk_unit_flg[0] && (chk_unit_flg[1] || chk_unit_flg[3]);
assign chk_unit_hit_2m = chk_unit_scd && chk_unit_flg[0] && (chk_unit_flg[1] || chk_unit_flg[3]);
assign chk_unit_leaf_vld = chk_unit_hit_1g | chk_unit_hit_2m | chk_unit_thd;

assign chk_unit_page_flt = ((!chk_unit_flg[0]                       // not valid
                   ||  !(chk_unit_flg[1] || cp0_mmu_mxr && chk_unit_flg[3])
                        && chk_unit_flg[2]         // write only
                   ||  (!chk_unit_flg[1] && chk_unit_load_type     // match R
                       && !(cp0_mmu_mxr && chk_unit_flg[3])
                   || !chk_unit_flg[2] && chk_unit_store_type     // match W
                   || !chk_unit_flg[3] && chk_unit_fetch_type     // match X
                   ||  chk_unit_flg[4] && chk_unit_cp0_supv_mode && !cp0_mmu_sum // S->U
                   || !chk_unit_flg[4] && chk_unit_cp0_user_mode      // U->S
                   || !chk_unit_flg[5]                       // A bit volation
                   || !chk_unit_flg[6] && chk_unit_store_type     // D bit volation
//                   ||  chk_unit_flg[13] && chk_unit_fetch_type    // fetch so
                   ||  chk_unit_hit_1g && chk_unit_data[27:10] != 18'b0 // 1g align
                   ||  chk_unit_hit_2m && chk_unit_data[18:10] != 9'b0  // 2m align
                     ) && chk_unit_leaf_vld)
                   || !chk_unit_flg[1] && !chk_unit_flg[3]        // thd req no R/X
                       && chk_unit_thd);

assign chk_unit_ppn[PPN_WIDTH-1:0] = chk_unit_data[37:10];
//!******************************************
//! refill
//!******************************************
assign mmu_sysmap_pax3[PPN_WIDTH-1:0] = chk_unit_ppn[PPN_WIDTH-1:0];
assign chk_unit_refill_high_flg[4:0] = cp0_mmu_maee ? chk_unit_data[63:59] : sysmap_mmu_flgx3[4:0];

assign chk_unit_refill_req = chk_unit_vld
                           & (((chk_unit_hit_1g | chk_unit_hit_2m) & cp0_mmu_maee) | chk_unit_thd)
                           & (!chk_unit_page_flt);
assign chk_unit_refill_data[RDATA_WIDTH-1:0] = {chk_unit_data[37:10],chk_unit_refill_high_flg[4:0],chk_unit_data[9:6],chk_unit_data[4:0]};
assign chk_unit_refill_pgs[PTE_LEVEL-1:0] = chk_unit_lvl[PTE_LEVEL-1:0];
assign chk_unit_refill_tag[TAG_WIDTH-1:0] = {1'b1,chk_unit_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],chk_unit_refill_pgs[PTE_LEVEL-1:0],chk_unit_data[5]};
assign chk_unit_refill_type[TYPE_WIDTH-1:0] = chk_unit_type[TYPE_WIDTH-1:0];
assign chk_unit_refill_id[ID_WIDTH-1:0] = chk_unit_id[ID_WIDTH-1:0];

//!******************************************
//! CSR
//!******************************************
assign chk_unit_csr_req = chk_unit_vld & (chk_unit_hit_1g | chk_unit_hit_2m) & (!cp0_mmu_maee) & (!chk_unit_page_flt);
assign chk_unit_csr_vpn[VPN_WIDTH-1:0] = chk_unit_vpn[VPN_WIDTH-1:0];
assign chk_unit_csr_type[TYPE_WIDTH-1:0] = chk_unit_type[TYPE_WIDTH-1:0];
assign chk_unit_csr_id[ID_WIDTH-1:0] = chk_unit_id[ID_WIDTH-1:0];
assign chk_unit_csr_data[DATA_WIDTH-1:0] = chk_unit_data[DATA_WIDTH-1:0];
assign chk_unit_csr_pgs[PTE_LEVEL-1:0] = chk_unit_lvl[PTE_LEVEL-1:0];

//!******************************************
//! wait
//!******************************************
assign chk_unit_wait =    chk_unit_vld & pmp_unit_wait & (!chk_unit_leaf_vld) & (!chk_unit_page_flt)
					  |  chk_unit_vld & chk_unit_refill_req & (!refill_chk_unit_grant)
					  |  chk_unit_vld & chk_unit_page_flt & (!pgflt_chk_unit_grant)
					  |	 chk_unit_vld & chk_unit_csr_req & (!chk_unit_csr_grant);
assign pgflt_chk_unit_grant = chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant);
//==============================================================================
//                  DATA READY
//==============================================================================
assign twu_data_ready = !(chk_unit_vld & chk_unit_wait);

//==============================================================================
//                  Page fault reg
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        twu_pgflt_vld <= 1'b0;
    else if(abort)
        twu_pgflt_vld <= 1'b0;
    else if(chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
        twu_pgflt_vld <= 1'b1;
    else if(pgflt_twu_grant)
        twu_pgflt_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		twu_pgflt_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		twu_pgflt_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
	end else if(chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))begin
		twu_pgflt_type[TYPE_WIDTH-1:0] <= chk_unit_type[TYPE_WIDTH-1:0];
		twu_pgflt_id[ID_WIDTH-1:0] <= chk_unit_id[ID_WIDTH-1:0];
	end
end
assign
assign twu_l2tlb_ref_pgflt = twu_pgflt_vld;
assign twu_l2tlb_ref_pgflt_type[TYPE_WIDTH-1:0] = twu_pgflt_type[TYPE_WIDTH-1:0];
assign twu_l2tlb_ref_pgflt_id[ID_WIDTH-1:0] = twu_pgflt_id[ID_WIDTH-1:0];
//==============================================================================
//                  Access fault reg
//==============================================================================
always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        twu_acc_err_vld <= 1'b0;
    else if(abort)
        twu_acc_err_vld <= 1'b0;
    else if(pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant))
        twu_acc_err_vld <= 1'b1;
    else if(acc_err_twu_grant)
        twu_acc_err_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		twu_acc_err_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		twu_acc_err_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
	end else if(pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant))begin
		twu_acc_err_type[TYPE_WIDTH-1:0] <= pmp_unit_type[TYPE_WIDTH-1:0];
		twu_acc_err_id[ID_WIDTH-1:0] <= pmp_unit_id[ID_WIDTH-1:0];
	end
end

assign twu_l2tlb_ref_acc_err = twu_acc_err_vld;
assign twu_l2tlb_ref_acc_err_type[TYPE_WIDTH-1:0] = twu_acc_err_type[TYPE_WIDTH-1:0];
assign twu_l2tlb_ref_acc_err_id[ID_WIDTH-1:0] = twu_acc_err_id[ID_WIDTH-1:0];
/*
//==============================================================================
//                  CSR Arbiter
//==============================================================================
assign csr_req = |csr_grant[1:0];

assign fst_csr_itlb_sel = fst_chk_csr_req & fst_chk_fetch_type;
assign scd_csr_itlb_sel = scd_chk_csr_req & scd_chk_fetch_type;

assign csr_itlb_sel = fst_csr_itlb_sel | scd_csr_itlb_sel;

assign fst_csr_sel = (!csr_itlb_sel) & (!scd_chk_csr_req) & fst_chk_csr_req;
assign scd_csr_sel = (!csr_itlb_sel) & scd_chk_csr_req;

always_comb begin
    case({csr_itlb_sel,fst_csr_sel,scd_csr_sel})
        3'b100  : csr_grant[1:0] = {fst_csr_itlb_sel,scd_csr_itlb_sel};
        3'b010  : csr_grant[1:0] = 2'b10;
        3'b001  : csr_grant[1:0] = 2'b01;
        default : csr_grant[1:0] = 2'b00;
    endcase
end


assign scd_csr_grant = csr_grant[0] & csr_idle;
assign fst_csr_grant = csr_grant[1] & csr_idle;

always_comb begin
	case(csr_grant[1:0])
		2'b01	: begin
			csr_vpn[VPN_WIDTH-1:0] = scd_chk_csr_vpn[VPN_WIDTH-1:0];
			csr_type[TYPE_WIDTH-1:0] = scd_chk_csr_type[TYPE_WIDTH-1:0];
			csr_id[ID_WIDTH-1:0] = scd_chk_csr_id[ID_WIDTH-1:0];
			csr_data[DATA_WIDTH-1:0] = scd_chk_csr_data[DATA_WIDTH-1:0];
		end
		2'b10	: begin
			csr_vpn[VPN_WIDTH-1:0] = fst_chk_csr_vpn[VPN_WIDTH-1:0];
			csr_type[TYPE_WIDTH-1:0] = fst_chk_csr_type[TYPE_WIDTH-1:0];
			csr_id[ID_WIDTH-1:0] = fst_chk_csr_id[ID_WIDTH-1:0];
			csr_data[DATA_WIDTH-1:0] = fst_chk_csr_data[DATA_WIDTH-1:0];
		end
		default : begin
			csr_vpn[VPN_WIDTH-1:0] = {VPN_WIDTH{1'b0}};
			csr_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
			csr_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
			csr_data[DATA_WIDTH-1:0] = {DATA_WIDTH{1'b0}};
		end
	endcase
end
*/

//==============================================================================
//                  CSR FSM  (legacy 1036-1164 in block comment — refactor)
//==============================================================================
assign csr_vpn[VPN_WIDTH-1:0] = chk_unit_csr_vpn[VPN_WIDTH-1:0];
assign csr_type[TYPE_WIDTH-1:0] = chk_unit_csr_type[TYPE_WIDTH-1:0];
assign csr_id[ID_WIDTH-1:0] = chk_unit_csr_id[ID_WIDTH-1:0];
assign csr_data[DATA_WIDTH-1:0] = chk_unit_csr_data[DATA_WIDTH-1:0];
assign csr_fst = chk_unit_csr_pgs[PTE_LEVEL-1:0] == 3'b100;
assign csr_scd = chk_unit_csr_pgs[PTE_LEVEL-1:0] == 3'b010;

parameter TWU_IDLE        = 3'b000,  //waiting for a translation request
          TWU_1G_CRS      = 3'b001,  //1GB page crossing check - phase 1 (fetch sysmap hit info)
//          TWU_1G_CRS2      = 3'b010,  //1GB page crossing check - phase 2 (validate boundary)
          TWU_2M_CRS      = 3'b010,  //2MB page crossing check - phase 1 (fetch sysmap hit info)
//          TWU_2M_CRS2      = 3'b100,  //2MB page crossing check - phase 1 (validate boundary)
          CSR_DATA_VLD    = 3'b011;

always_ff @(posedge twu_clk or negedge cpurst_b)begin
	if (!cpurst_b)
		ptw_cur_st[2:0] <= TWU_IDLE;
	else if(abort)
		ptw_cur_st[2:0] <= TWU_IDLE;
	else
		ptw_cur_st[2:0] <= ptw_nxt_st[2:0];
end

always_comb begin
	case (ptw_cur_st)
		TWU_IDLE:begin
		if(chk_unit_csr_req & csr_fst)
			ptw_nxt_st[2:0] = TWU_1G_CRS;
		else if(chk_unit_csr_req & csr_scd)
			ptw_nxt_st[2:0] = TWU_2M_CRS;
		else
			ptw_nxt_st[2:0] = TWU_IDLE;
		end
		TWU_1G_CRS:begin
		if(twu_csr_cross)
			ptw_nxt_st[2:0] = TWU_2M_CRS;
		else
			ptw_nxt_st[2:0] = CSR_DATA_VLD;
		end
		TWU_2M_CRS:begin
			ptw_nxt_st[2:0] = CSR_DATA_VLD;
		end
		CSR_DATA_VLD:begin
		if(refill_csr_grant)
			ptw_nxt_st[2:0] = TWU_IDLE;
		else
			ptw_nxt_st[2:0] = CSR_DATA_VLD;
		end
		default:begin
			ptw_nxt_st[2:0] = TWU_IDLE;
		end
	endcase
end

assign csr_idle = ptw_cur_st[2:0] == TWU_IDLE;
assign twu_crs_1g = ptw_cur_st[2:0] == TWU_1G_CRS;
assign twu_crs_2m = ptw_cur_st[2:0] == TWU_2M_CRS;
assign twu_crs_chk = twu_crs_1g || twu_crs_2m;
assign chk_unit_csr_grant = chk_unit_csr_req & csr_idle;

always_ff @(posedge twu_clk or negedge cpurst_b)begin
	if (!cpurst_b)begin
		csr_vpn_flop[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		csr_type_flop[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		csr_id_flop[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
	end	else if(chk_unit_csr_req & csr_idle)begin
		csr_vpn_flop[VPN_WIDTH-1:0] <= csr_vpn[VPN_WIDTH-1:0];
		csr_type_flop[TYPE_WIDTH-1:0] <= csr_type[TYPE_WIDTH-1:0];
		csr_id_flop[ID_WIDTH-1:0] <= csr_id[ID_WIDTH-1:0] ;
	end
end

always_ff @(posedge twu_clk or negedge cpurst_b)begin
	if (!cpurst_b)begin
		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
	end else if(chk_unit_csr_grant & csr_fst)begin
		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH], 18'h3ffff, 12'b0};
	end else if(chk_unit_csr_grant & csr_scd)begin
		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH-9], 9'h1ff, 12'b0};
	end else if(twu_crs_1g & twu_csr_cross)begin
		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 21'b0};
		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 9'h1ff, 12'b0};
	end else if(twu_crs_2m & twu_csr_cross)begin
		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= twu_sysmap_adderx1[PADDR_WIDTH-1:0];
		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH-9], csr_vpn_flop[8:0], 12'b0};
	end
end

always_ff @(posedge twu_clk or negedge cpurst_b)begin
	if (!cpurst_b)
		csr_data_flop[DATA_WIDTH-6:0] <= {DATA_WIDTH-6{1'b0}};
	else if(chk_unit_csr_req & csr_idle)
		csr_data_flop[DATA_WIDTH-6:0] <= csr_data[DATA_WIDTH-6:0];
	else if(twu_crs_1g && twu_csr_cross)
		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH], csr_vpn_flop[17:9], csr_data_flop[18:0]};
	else if(twu_crs_2m && twu_csr_cross)
		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH-9], csr_vpn_flop[8:0], csr_data_flop[9:0]};
end

always @(posedge twu_clk or negedge cpurst_b)begin
	if (!cpurst_b)
		csr_refill_pgs[PGS_WIDTH-1:0] <= {PGS_WIDTH{1'b0}};
	else if(chk_unit_csr_req & csr_idle)
		csr_refill_pgs[PGS_WIDTH-1:0] <= chk_unit_csr_pgs[PTE_LEVEL-1:0];
	else if(twu_crs_1g && twu_csr_cross)
		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b010;
	else if(twu_crs_2m && twu_csr_cross)
		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b001;
end


assign twu_csr_cross = twu_crs_chk & (sysmap_mmu_hitx1[7:0] != sysmap_mmu_hitx2[7:0]);
assign sysmap_mmu_flg[4:0] = sysmap_mmu_flgx2[4:0];

assign csr_fetch_type = csr_type_flop[TYPE_WIDTH-1:0] == 3'b011;
assign csr_refill_req = ptw_cur_st[2:0] == CSR_DATA_VLD;
assign csr_refill_data[RDATA_WIDTH-1:0] = {csr_data_flop[PPN_WIDTH+9:10],sysmap_mmu_flg[4:0],csr_data_flop[9:6],csr_data_flop[4:0]};
assign csr_refill_tag[TAG_WIDTH-1:0] = {1'b1,csr_vpn_flop[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],csr_refill_pgs[PGS_WIDTH-1:0],csr_data_flop[5]};
assign csr_refill_type[TYPE_WIDTH-1:0] = csr_type_flop[TYPE_WIDTH-1:0];
assign csr_refill_id[ID_WIDTH-1:0] = csr_id_flop[ID_WIDTH-1:0];

//==========================================================
//                  Interface to SysMap
//==========================================================
assign mmu_sysmap_pax1[PPN_WIDTH-1:0] = twu_sysmap_adderx1[PPN_WIDTH+11:12];
assign mmu_sysmap_pax2[PPN_WIDTH-1:0] = twu_sysmap_adderx2[PPN_WIDTH+11:12];

//==============================================================================
//                  write MBUF Arbiter
//==============================================================================
/*
assign twu_mbuf_lvl[PTE_LEVEL-1:0] = {fst_pmp_mbuf_req,scd_pmp_mbuf_req,thd_pmp_mbuf_req};
assign twu_mbuf_req = |twu_mbuf_lvl[PTE_LEVEL-1:0];
always_comb begin
	case(twu_mbuf_lvl[PTE_LEVEL-1:0])
		3'b001	: begin
			twu_mbuf_paddr[PADDR_WIDTH-1:0] = thd_pmp_pa[PADDR_WIDTH-1:0];
			twu_mbuf_vpn[VPN_WIDTH-1:0] = thd_pmp_vpn[VPN_WIDTH-1:0];
			twu_mbuf_type[TYPE_WIDTH-1:0] = thd_pmp_type[TYPE_WIDTH-1:0];
			twu_mbuf_id[ID_WIDTH-1:0] = thd_pmp_id[ID_WIDTH-1:0];
			twu_mbuf_pmpflg[7:0] = 8'b0;
		end
		3'b010	: begin
			twu_mbuf_paddr[PADDR_WIDTH-1:0] = scd_pmp_pa[PADDR_WIDTH-1:0];
			twu_mbuf_vpn[VPN_WIDTH-1:0] = scd_pmp_vpn[VPN_WIDTH-1:0];
			twu_mbuf_type[TYPE_WIDTH-1:0] = scd_pmp_type[TYPE_WIDTH-1:0];
			twu_mbuf_id[ID_WIDTH-1:0] = scd_pmp_id[ID_WIDTH-1:0];
			twu_mbuf_pmpflg[7:0] = {pmp_mmu_flg[3:0],scd_pmp_l1pmpflg[3:0]};
		end
		3'b100	: begin
			twu_mbuf_paddr[PADDR_WIDTH-1:0] = fst_pmp_pa[PADDR_WIDTH-1:0];
			twu_mbuf_vpn[VPN_WIDTH-1:0] = fst_pmp_vpn[VPN_WIDTH-1:0];
			twu_mbuf_type[TYPE_WIDTH-1:0] = fst_pmp_type[TYPE_WIDTH-1:0];
			twu_mbuf_id[ID_WIDTH-1:0] = fst_pmp_id[ID_WIDTH-1:0];
			twu_mbuf_pmpflg[7:0] = {4'b0,pmp_mmu_flg[3:0]};
		end
		default : begin
			twu_mbuf_paddr[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
			twu_mbuf_vpn[VPN_WIDTH-1:0] = {VPN_WIDTH{1'b0}};
			twu_mbuf_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
			twu_mbuf_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
			twu_mbuf_pmpflg[7:0] = 8'b0;
		end
	endcase
end
*/

//==============================================================================
//                  refill Arbiter
//==============================================================================
//assign twu_arb_ref_req = |refill_grant[3:0];
assign twu_arb_ref_req = twu_refill_vld;

assign chk_unit_itlb_sel = chk_unit_refill_req & chk_unit_fetch_type;
assign csr_ref_itlb_sel = csr_refill_req & csr_fetch_type;

assign refill_itlb_sel = chk_unit_itlb_sel | csr_ref_itlb_sel;

assign chk_unit_sel = (!refill_itlb_sel) & (!csr_refill_req) & chk_unit_refill_req;
assign csr_ref_sel = (!refill_itlb_sel) & csr_refill_req;

always_comb begin
    case({refill_itlb_sel,chk_unit_sel,csr_ref_sel})
        3'b100   : refill_grant[1:0] = {chk_unit_itlb_sel,csr_ref_itlb_sel};
        3'b010   : refill_grant[1:0] = 2'b10;
		3'b001   : refill_grant[1:0] = 2'b01;
		default  : refill_grant[1:0] = 2'b00;
    endcase
end

assign twu_refill_idle = ~twu_refill_vld | refill_arb_twu_grant;
assign refill_req = |refill_grant[1:0];
always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        twu_refill_vld <= 1'b0;
    else if(abort)
        twu_refill_vld <= 1'b0;
    else if(refill_req & twu_refill_idle)
        twu_refill_vld <= 1'b1;
    else if(refill_arb_twu_grant)
        twu_refill_vld <= 1'b0;
end
/*
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		thd_chk_refill_no_maee_sel <= 1'b0;
	end else if(refill_grant[0] & twu_refill_idle & ~cp0_mmu_maee)begin
		thd_chk_refill_no_maee_sel <= 1'b1;
	end else if(refill_arb_twu_grant)begin
		thd_chk_refill_no_maee_sel <= 1'b0;
	end
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		mmu_sysmap_pax3[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
	end else if(refill_grant[0] & twu_refill_idle & ~cp0_mmu_maee)begin
		mmu_sysmap_pax3[PPN_WIDTH-1:0] <= thd_chk_refill_data[RDATA_WIDTH-1:14];
	end
end

//assign mmu_sysmap_pax3[PPN_WIDTH-1:0] = thd_chk_refill_data[PPN_WIDTH+9:10];
assign thd_chk_refill_data_no_maee[RDATA_WIDTH-1:0] = {twu_ref_data_din[RDATA_WIDTH-1:14], sysmap_mmu_flgx3[4:0],twu_ref_data_din[8:0]};
*/
always_ff@(posedge twu_clk or negedge cpurst_b) begin
	if(!cpurst_b)begin
		twu_ref_data_din[RDATA_WIDTH-1:0] <= {RDATA_WIDTH{1'b0}};
		twu_ref_tag_din[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
		twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b0;
		twu_ref_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		twu_ref_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
	end else if(refill_grant[1] & twu_refill_idle)begin
		twu_ref_data_din[RDATA_WIDTH-1:0] <= chk_unit_refill_data[RDATA_WIDTH-1:0];
		twu_ref_tag_din[TAG_WIDTH-1:0] <= chk_unit_refill_tag[TAG_WIDTH-1:0];
		twu_ref_pgs[PGS_WIDTH-1:0] <= chk_unit_refill_pgs[PGS_WIDTH-1:0];
		twu_ref_type[TYPE_WIDTH-1:0] <= chk_unit_refill_type[TYPE_WIDTH-1:0];
		twu_ref_id[ID_WIDTH-1:0] <= chk_unit_refill_id[ID_WIDTH-1:0];
	end else if(refill_grant[0] & twu_refill_idle)begin
		twu_ref_data_din[RDATA_WIDTH-1:0] <= csr_refill_data[RDATA_WIDTH-1:0];
		twu_ref_tag_din[TAG_WIDTH-1:0] <= csr_refill_tag[TAG_WIDTH-1:0];
		twu_ref_pgs[PGS_WIDTH-1:0] <= csr_refill_pgs[PGS_WIDTH-1:0];
		twu_ref_type[TYPE_WIDTH-1:0] <= csr_refill_type[TYPE_WIDTH-1:0];
		twu_ref_id[ID_WIDTH-1:0] <= csr_refill_id[ID_WIDTH-1:0];
	end
end

assign twu_arb_ref_data_din[RDATA_WIDTH-1:0] = twu_ref_data_din[RDATA_WIDTH-1:0];
assign twu_arb_ref_tag_din[TAG_WIDTH-1:0] = twu_ref_tag_din[TAG_WIDTH-1:0];
assign twu_arb_ref_pgs[PGS_WIDTH-1:0] = twu_ref_pgs[PGS_WIDTH-1:0];
assign twu_arb_ref_type[TYPE_WIDTH-1:0] = twu_ref_type[TYPE_WIDTH-1:0];
assign twu_arb_ref_id[ID_WIDTH-1:0] = twu_ref_id[ID_WIDTH-1:0];

assign refill_csr_grant = refill_grant[0] & twu_refill_idle;
assign refill_chk_unit_grant = refill_grant[1] & twu_refill_idle;




endmodule
