//!*********************************************************************************
//! OpenRiscv2030: 2024~2025
//! 
//! MMU (Memory Management Unit) Top Level - Updated Architecture
//!   1. L1 ITLB (Credit-based)
//!   2. L1 DTLB (Credit-based)
//!   3. L2 TLB (Skew-Associative, 8 Banks)
//!   4. PTW (Page Table Walk, 6 Ports)
//!   5. PMP (Physical Memory Protection)
//!*********************************************************************************

module ct_mmu_top(

    //! Clock & Reset
    input logic           forever_cpuclk,              
    input logic           cpurst_b,                    

    //!*************************************************************************
    //! CP0 <=> MMU Interface: SysRegs
    //!*************************************************************************
    input logic           cp0_mmu_cskyee,              
    input logic           cp0_mmu_icg_en,              
    input logic           cp0_mmu_maee,                
    input logic   [1 :0]  cp0_mmu_mpp,                  
    input logic           cp0_mmu_mprv,                
    input logic           cp0_mmu_mxr,                  
    input logic           cp0_mmu_no_op_req,            
    input logic           cp0_mmu_ptw_en,              
    input logic   [1 :0]  cp0_mmu_reg_num,              
    input logic           cp0_mmu_satp_sel,            
    input logic           cp0_mmu_sum,                  
    input logic           cp0_mmu_tlb_all_inv,          
    input logic   [63:0]  cp0_mmu_wdata,              

    input logic           cp0_mmu_wreg,                
    input logic   [1 :0]  cp0_yy_priv_mode,            

    output logic          mmu_cp0_cmplt,                
    output logic   [63:0] mmu_cp0_data,                
    output logic   [63:0] mmu_cp0_satp_data,           
    output logic          mmu_cp0_tlb_done,            

    input logic           hpcp_mmu_cnt_en,              
    output logic          mmu_hpcp_dutlb_miss,          
    output logic          mmu_hpcp_iutlb_miss,          
    output logic          mmu_hpcp_jtlb_miss,          

    input logic           biu_mmu_smp_disable,          
    output logic   [33:0] mmu_had_debug_info,          
    output logic          mmu_xx_mmu_en,                
    output logic          mmu_yy_xx_no_op,              

    //!*************************************************************************
    //! IFU (Instruction Fetch Unit) <=> MMU Interface
    //!*************************************************************************
    input logic           ifu_mmu_va_vld,              
    input logic   [62:0]  ifu_mmu_va,                  
    input logic           ifu_mmu_abort,               

    output logic           mmu_ifu_buf,                  
    output logic           mmu_ifu_ca,                  
    output logic           mmu_ifu_deny,                
    output logic   [27:0]  mmu_ifu_pa,                  
    output logic           mmu_ifu_pavld,               
    output logic           mmu_ifu_pgflt,               
    output logic           mmu_ifu_sec,                 

    //!*************************************************************************
    //! LSU (Load/Store Unit) <=> MMU Interface
    //!*************************************************************************
    //! Pipe 0
    input logic           lsu_mmu_va0_vld,              
    input logic   [6 :0]  lsu_mmu_id0,                  
    input logic   [63:0]  lsu_mmu_va0,                  
    input logic           lsu_mmu_st_inst0,            
    input logic           lsu_mmu_abort0,              
    input logic   [27:0]  lsu_mmu_vabuf0,      

    output logic           mmu_lsu_pa0_vld,              
    output logic   [27:0]  mmu_lsu_pa0,                  
    output logic           mmu_lsu_page_fault0,          
    output logic           mmu_lsu_sec0,                
    output logic           mmu_lsu_sh0,                  
    output logic           mmu_lsu_so0,                  
    output logic           mmu_lsu_stall0,              
    output logic           mmu_lsu_buf0,                
    output logic           mmu_lsu_ca0,                  
    output logic           mmu_lsu_access_fault0,        

    //! Pipe 1
    input logic           lsu_mmu_va1_vld,              
    input logic   [6 :0]  lsu_mmu_id1,                  
    input logic   [63:0]  lsu_mmu_va1,                  
    input logic           lsu_mmu_st_inst1,            
    input logic           lsu_mmu_abort1,              
    input logic   [27:0]  lsu_mmu_vabuf1,              

    output logic           mmu_lsu_pa1_vld,              
    output logic   [27:0]  mmu_lsu_pa1,                  
    output logic           mmu_lsu_page_fault1,          
    output logic           mmu_lsu_sec1,                
    output logic           mmu_lsu_sh1,                  
    output logic           mmu_lsu_so1,                  
    output logic           mmu_lsu_stall1,              
    output logic           mmu_lsu_buf1,                
    output logic           mmu_lsu_ca1,                  
    output logic           mmu_lsu_access_fault1,        

    //! Prefetch / Pipe 2
    input logic           lsu_mmu_va2_vld,              
    input logic   [27:0]  lsu_mmu_va2,       

    output logic           mmu_lsu_pa2_vld,              
    output logic   [27:0]  mmu_lsu_pa2,                  
    output logic           mmu_lsu_sec2,                
    output logic           mmu_lsu_pa2_err,              
    output logic           mmu_lsu_share2,              

    //! STAMO
    input logic           lsu_mmu_stamo_vld,            
    input logic   [27:0]  lsu_mmu_stamo_pa,            

    //! TLB Invalidation (LSU request)
    input logic           lsu_mmu_tlb_va_all_inv,       
    input logic   [26:0]  lsu_mmu_tlb_va,              
    input logic           lsu_mmu_tlb_all_inv,          
    input logic           lsu_mmu_tlb_va_asid_inv,      
    input logic   [15:0]  lsu_mmu_tlb_asid,            
    input logic           lsu_mmu_tlb_asid_all_inv,    

    output logic           mmu_lsu_tlb_inv_done,        

    //! PTW/LSU Interface
    output logic           mmu_lsu_mmu_en,              
    output logic           mmu_lsu_data_req,            
    output logic   [39:0]  mmu_lsu_data_req_addr,        
    output logic           mmu_lsu_data_req_size,        

    input logic           lsu_mmu_bus_error,            
    input logic           lsu_mmu_data_vld,            
    input logic   [63:0]  lsu_mmu_data,                

    output logic           mmu_lsu_tlb_busy,            
    output logic   [11:0]  mmu_lsu_tlb_wakeup,       

    input logic           pad_yy_icg_scan_en,       
    
    //!*************************************************************************
    //! PMP (Physical Memory Protection) <=> MMU Interface
    //!*************************************************************************
    input logic   [3 :0]  pmp_mmu_flg0,                
    input logic   [3 :0]  pmp_mmu_flg1,                
    input logic   [3 :0]  pmp_mmu_flg2,                
    input logic   [3 :0]  pmp_mmu_flg3,                
    input logic   [3 :0]  pmp_mmu_flg4,    
    // [NEW] Added for PTW extended ports
    input logic   [3 :0]  pmp_mmu_flg5,
    input logic   [3 :0]  pmp_mmu_flg6, 

    input logic   [3 :0]  pmp_mmu_flg7,//!!!!!!!!!!!

    output logic           mmu_pmp_fetch3,              
    //output logic           mmu_pmp_fetch4,              
    output logic           mmu_pmp_fetch5,              
    output logic           mmu_pmp_fetch6,              

    output logic           mmu_pmp_fetch7,  //!!!!!!!!!!!! 

    output logic   [27:0]  mmu_pmp_pa0,                  
    output logic   [27:0]  mmu_pmp_pa1,                  
    output logic   [27:0]  mmu_pmp_pa2,                  
    output logic   [27:0]  mmu_pmp_pa3,                  
    output logic   [27:0]  mmu_pmp_pa4,                  
    output logic   [27:0]  mmu_pmp_pa5,                  
    output logic   [27:0]  mmu_pmp_pa6,
    output logic   [27:0]  mmu_pmp_pa7,//!!!!!!!!!!!!!!!!!!!!!!!

    input  logic           pmp_regs_update,
    //!*************************************************************************
    //! RTU (Retire Unit) <=> MMU Interface
    //!*************************************************************************
    input logic   [26:0]  rtu_mmu_bad_vpn,              
    input logic           rtu_mmu_expt_vld,            
    input logic           rtu_yy_xx_flush

);
    logic [4 :0]  sysmap_mmu_flg0;
    logic [4 :0]  sysmap_mmu_flg1;
    logic [4 :0]  sysmap_mmu_flg2;
    logic [4 :0]  sysmap_mmu_flg3;
    logic [4 :0]  sysmap_mmu_flg4;
    logic [4 :0]  sysmap_mmu_flg5;
    logic [4 :0]  sysmap_mmu_flg6;
    logic [4 :0]  sysmap_mmu_flg7;



    logic [7 :0]  sysmap_mmu_hit0;
    logic [7 :0]  sysmap_mmu_hit1;
    logic [7 :0]  sysmap_mmu_hit2;
    logic [7 :0]  sysmap_mmu_hit3;
    logic [7 :0]  sysmap_mmu_hit4;
    logic [7 :0]  sysmap_mmu_hit5;
    logic [7 :0]  sysmap_mmu_hit6;

    logic [7 :0]  sysmap_mmu_hit7;
    // &Regs; @30
    // &Wires; @31
    //==========================================================
    // Local Signals for Interconnect
    //==========================================================
    logic        utlb_clk;
    logic        utlb_clk_en;

    // L1 DTLB <-> L2TLB
    logic        dutlb_l2tlb_req_vld;
    logic [26:0] dutlb_l2tlb_req_vpn;
    logic [2:0]  dutlb_l2tlb_req_eid;
    logic        dutlb_l2tlb_req_is_load;
    logic        l2tlb_dutlb_credit_return;

    // L1 ITLB <-> L2TLB
    logic        iutlb_l2tlb_req;
    logic [26:0] iutlb_l2tlb_vpn;
    logic        l2tlb_iutlb_credit_return;

    // PTW Refill to L1
    logic        ptw_l1dtlb_ref_pa_vld;
    logic [26:0] ptw_l1dtlb_ref_vpn;
    logic [2:0]  ptw_l1dtlb_ref_pgs;
    logic [27:0] ptw_l1dtlb_ref_ppn;
    logic [13:0] ptw_l1dtlb_ref_flg;
    logic [5:0]  ptw_l1dtlb_id;
    logic        ptw_l1dtlb_cmplt;
    logic        ptw_l1dtlb_pgflt;
    logic        ptw_l1dtlb_ref_acc_err;

    logic        ptw_l1itlb_ref_pa_vld;
    logic [26:0] ptw_l1itlb_ref_vpn;
    logic [2:0]  ptw_l1itlb_ref_pgs;
    logic [27:0] ptw_l1itlb_ref_ppn;
    logic [13:0] ptw_l1itlb_ref_flg;
    logic        ptw_l1itlb_cmplt;
    logic        ptw_l1itlb_pgflt;
    logic        ptw_l1itlb_ref_acc_err;


    // L2TLB Hit Refill to L1 (Direct)
    logic        l2tlb_l1dtlb_ref_pavld;
    logic        l2tlb_l1dtlb_ref_cmplt;
    logic [2:0]  l2tlb_l1dtlb_ref_eid;
    logic        l2tlb_l1dtlb_pgflt;

    logic        l2tlb_l1itlb_ref_pavld;
    logic        l2tlb_l1itlb_ref_cmplt;
    logic        l2tlb_l1itlb_pgflt;

    logic [13:0] l2tlb_l1tlb_ref_flg;
    logic [2:0]  l2tlb_l1tlb_ref_pgs;
    logic [27:0] l2tlb_l1tlb_ref_ppn;
    logic [26:0] l2tlb_l1tlb_ref_vpn;
    logic        l2tlb_top_utlb_pavld;

    // L2TLB ReqQ <-> Arbiter
    logic        queue_arb_req;
    logic [26:0] queue_arb_vpn;
    logic [2:0]  queue_arb_eid;
    logic [2:0]  queue_arb_trans_id;
    logic [2:0]  queue_arb_acc_type;
    logic        arb__l2tlb_queue_grant;
    logic	 l2tlb_arb_ptw_cmplt;

    // Arbiter <-> L2TLB SRAM/Ctrl
    logic        arb_l2tlb_req;
    logic [26:0] arb_l2tlb_vpn;
    logic        arb_l2tlb_write;
    logic [47:0] arb_l2tlb_tag_din;
    logic [41:0] arb_l2tlb_data_din;
    logic [2:0]  arb_l2tlb_trans_id;
    logic [2:0]  arb_l2tlb_eid;
    logic [2:0]  arb_l2tlb_acc_type;
    logic [7:0]  arb_l2tlb_bank_sel;
    logic        arb_l2tlb_cmp_with_va;
    logic [23:0] arb_l2tlb_rrpv_din;
    logic [23:0] arb_l2tlb_size_bus;

    // Arbiter Skew Indices
    logic [7:0]  arb_l2tlb_idx_w0;
    logic [7:0]  arb_l2tlb_idx_w1;
    logic [7:0]  arb_l2tlb_idx_w2;
    logic [7:0]  arb_l2tlb_idx_w3;
    logic [7:0]  arb_l2tlb_idx_w4;
    logic [7:0]  arb_l2tlb_idx_w5;
    logic [7:0]  arb_l2tlb_idx_w6;
    logic [7:0]  arb_l2tlb_idx_w7;

    // PTW <-> L2TLB
    logic        l2tlb_ptw_req;
    logic [2:0]  l2tlb_ptw_type;
    logic [26:0] l2tlb_ptw_vpn;
    logic [5:0]  l2tlb_ptw_id;
    
    logic        ptw_l2tlb_ref_acc_err;
    logic        ptw_l2tlb_ref_pgflt;
    logic        ptw_l2tlb_ref_data_vld;
    logic        ptw_l2tlb_cmplt;
    logic [2:0]  ptw_l2tlb_type;
    logic [5:0]  ptw_l2tlb_id;
    logic [13:0] ptw_l2tlb_flg;
    logic        ptw_jtlb_ready;

    // PTW <-> Arbiter
    logic        ptw_arb_req;
    logic [26:0] ptw_arb_vpn;
    logic [2:0]  ptw_arb_pgs;
    logic [47:0] ptw_arb_ref_tag_din;
    logic [41:0] ptw_arb_ref_data_din;
    logic        arb_ptw_grant;
    logic        arb_ptw_mask;
    logic [7:0]  victim_way;
    logic [23:0] rrpv_updata;

    // TLB Oper Signals
    logic        tlboper_arb_req;
    logic        tlboper_arb_write;
    logic [47:0] tlboper_arb_tag_din;
    logic [26:0] tlboper_arb_vpn;
    logic [7:0]  tlboper_arb_bank_sel;
    logic        tlboper_arb_cmp_va;
    logic [41:0] tlboper_arb_data_din;
    logic [8:0]  tlboper_arb_idx;
    logic        tlboper_arb_idx_not_va;
    logic        arb_tlboper_grant;
    logic        arb_top_tlboper_on;

    logic [15:0] tlboper_l2tlb_asid;
    logic        tlboper_l2tlb_asid_sel;
    logic        tlboper_l2tlb_cmp_noasid;
    logic [15:0] tlboper_l2tlb_inv_asid;
    logic        tlboper_l2tlb_tlbwr_on;
    logic        l2tlb_tlboper_asid_hit;
    logic        l2tlb_tlboper_cmplt;
    logic [7:0]  l2tlb_tlboper_sel;
    logic        l2tlb_tlboper_va_hit;

    // Regs Signals
    logic        l2tlb_regs_hit;
    logic        l2tlb_regs_hit_mult;
    logic [10:0] l2tlb_regs_tlbp_hit_index;
    logic [15:0] l2tlb_tlbr_asid;
    logic [13:0] l2tlb_tlbr_flg;
    logic        l2tlb_tlbr_g;
    logic [2:0]  l2tlb_tlbr_pgs;
    logic [27:0] l2tlb_tlbr_ppn;
    logic [26:0] l2tlb_tlbr_vpn;
    logic [15:0] regs_jtlb_cur_asid;
    logic [13:0] regs_jtlb_cur_flg;
    logic        regs_jtlb_cur_g;
    logic [27:0] regs_jtlb_cur_ppn;

    logic        regs_utlb_clr;
    logic        regs_ptw_clr;
    assign regs_ptw_clr = regs_utlb_clr;

    // PFU
    logic [26:0] l2tlb_arb_pfu_vpn;
    logic        arb_pfu_grant;
    logic        dutlb_xx_mmu_off;

    // Sysmap Internal Wires
    logic [27:0] mmu_sysmap_pa0, mmu_sysmap_pa1, mmu_sysmap_pa2, mmu_sysmap_pa3, mmu_sysmap_pa4, mmu_sysmap_pa5, mmu_sysmap_pa6,mmu_sysmap_pa7;
    
    // Debug & Ctrl
    logic [1:0]  iutlb_top_ref_cur_st;
    logic [2:0]  dutlb_top_ref_cur_st;
    logic        dutlb_top_ref_type;
    logic        iutlb_top_scd_updt;
    logic        dutlb_top_scd_updt;
    logic        dutlb_ptw_wfc;
    logic        iutlb_ptw_wfc;
    logic        tlboper_utlb_inv_va_req;
    logic        tlboper_utlb_clr;
    logic        tlboper_ptw_abort;
    
    logic        tlboper_top_lsu_cmplt;
    logic        tlboper_top_lsu_oper;
    logic        tlboper_top_tlbiall_cur_st;
    logic [2:0]  tlboper_top_tlbiasid_cur_st;
    logic [3:0]  tlboper_top_tlbiva_cur_st;
    logic [1:0]  tlboper_top_tlbp_cur_st;
    logic [1:0]  tlboper_top_tlbr_cur_st;
    logic [1:0]  tlboper_top_tlbwi_cur_st;
    logic [1:0]  tlboper_top_tlbwr_cur_st;
    logic [2:0]  tlboper_xx_pgs;
    
    logic        regs_tlboper_invall;
    logic        regs_tlboper_invasid;
    logic        regs_tlboper_tlbp;
    logic        regs_tlboper_tlbr;
    logic        regs_tlboper_tlbwi;
    logic        regs_tlboper_tlbwr;
    logic [15:0] regs_tlboper_inv_asid;
    logic [15:0] regs_tlboper_cur_asid;
    logic [2:0]  regs_tlboper_cur_pgs;
    logic [26:0] regs_tlboper_cur_vpn;
    logic [11:0] regs_tlboper_mir;
    logic        tlboper_regs_cmplt;
    logic        tlboper_regs_tlbp_cmplt;
    logic        tlboper_regs_tlbr_cmplt;
    logic [15:0] regs_ptw_cur_asid;
    logic [27:0] regs_ptw_satp_ppn;
    logic        regs_mmu_en;
    logic        tlboper_xx_cmplt;


    //==========================================================
    // Clock Gating
    //==========================================================
    assign utlb_clk_en = regs_utlb_clr
                       || tlboper_utlb_clr
                       || tlboper_utlb_inv_va_req
                       || !regs_mmu_en
                       || l2tlb_top_utlb_pavld
                       || dutlb_top_scd_updt
                       || iutlb_top_scd_updt;

    // &Instance("gated_clk_cell", "x_utlb_gateclk");
    gated_clk_cell  x_utlb_gateclk (
      .clk_in             (forever_cpuclk    ),
      .clk_out            (utlb_clk          ),
      .external_en        (1'b0              ),
      .global_en          (1'b1              ),
      .local_en           (utlb_clk_en       ),
      .module_en          (cp0_mmu_icg_en    ),
      .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
    );

    //==========================================================
    // Instance uTLBs
    //==========================================================
    // &Instance("mmu_l1itlb","x_mmu_l1itlb");
    mmu_l1itlb  x_mmu_l1itlb (
        .cpurst_b                   (cpurst_b),
        .forever_cpuclk             (forever_cpuclk),
        .utlb_clk                   (utlb_clk),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        .cp0_mmu_no_op_req          (cp0_mmu_no_op_req),
        .cp0_mmu_sum                (cp0_mmu_sum),
        .cp0_yy_priv_mode           (cp0_yy_priv_mode),
        .regs_mmu_en                (regs_mmu_en),
        .regs_utlb_clr              (regs_utlb_clr),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        .ifu_mmu_va_vld             (ifu_mmu_va_vld),
        .ifu_mmu_va                 (ifu_mmu_va),
        .ifu_mmu_abort              (ifu_mmu_abort),
        .mmu_ifu_pavld              (mmu_ifu_pavld),
        .mmu_ifu_pa                 (mmu_ifu_pa),
        .mmu_ifu_buf                (mmu_ifu_buf),
        .mmu_ifu_ca                 (mmu_ifu_ca),
        .mmu_ifu_deny               (mmu_ifu_deny),
        .mmu_ifu_pgflt              (mmu_ifu_pgflt),
        .mmu_ifu_sec                (mmu_ifu_sec),
        .mmu_pmp_pa2                (mmu_pmp_pa2),
        .pmp_mmu_flg2               (pmp_mmu_flg2),
        .mmu_sysmap_pa2             (mmu_sysmap_pa2),
        .sysmap_mmu_flg2            (sysmap_mmu_flg2),
        .hpcp_mmu_cnt_en            (hpcp_mmu_cnt_en),
        .mmu_hpcp_iutlb_miss        (mmu_hpcp_iutlb_miss),
        .tlboper_utlb_clr           (tlboper_utlb_clr),
        .tlboper_utlb_inv_va_req    (tlboper_utlb_inv_va_req),
        .lsu_mmu_tlb_va             (lsu_mmu_tlb_va),
        
        // Connect to L2TLB Request Interface
        .iutlb_l2tlb_req            (iutlb_l2tlb_req),
        .iutlb_l2tlb_vpn            (iutlb_l2tlb_vpn),
        .credit_return              (l2tlb_iutlb_credit_return),
        
        .iutlb_ptw_wfc              (iutlb_ptw_wfc),
        .iutlb_top_ref_cur_st       (iutlb_top_ref_cur_st),
        .iutlb_top_scd_updt         (iutlb_top_scd_updt),
        
        // Connect to PTW Refill
        .ptw_l1itlb_ref_pavld       (ptw_l1itlb_ref_pa_vld),
        .ptw_l1itlb_ref_cmplt       (ptw_l1itlb_cmplt),
        .ptw_l1tlb_ref_vpn          (ptw_l1itlb_ref_vpn),
        .ptw_l1tlb_ref_ppn          (ptw_l1itlb_ref_ppn),
        .ptw_l1tlb_acc_err          (ptw_l1itlb_ref_acc_err),
        .ptw_l1tlb_pgflt            (ptw_l1itlb_pgflt),
        .ptw_l1tlb_ref_flg          (ptw_l1itlb_ref_flg),
        .ptw_l1tlb_ref_pgs          (ptw_l1itlb_ref_pgs),

	.jtlb_iutlb_ref_pavld	    (l2tlb_l1itlb_ref_pavld),   //! L2TLB Refill Valid
	.jtlb_iutlb_ref_cmplt	    (l2tlb_l1itlb_ref_cmplt),   
	.jtlb_utlb_ref_vpn	    (l2tlb_l1tlb_ref_vpn),      
	.jtlb_utlb_ref_ppn	    (l2tlb_l1tlb_ref_ppn),      
	.jtlb_utlb_ref_flg	    (l2tlb_l1tlb_ref_flg),      
	.jtlb_utlb_ref_pgs	    (l2tlb_l1tlb_ref_pgs),      
	.jtlb_iutlb_pgflt	    (l2tlb_l1itlb_pgflt)

    );

    // &Instance("mmu_l1dtlb","u_mmu_l1dtlb");
    mmu_l1dtlb u_mmu_l1dtlb (
        .cpurst_b                   (cpurst_b),
        .forever_cpuclk             (forever_cpuclk),
        .utlb_clk                   (utlb_clk),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        .cp0_mmu_mpp                (cp0_mmu_mpp),
        .cp0_mmu_mprv               (cp0_mmu_mprv),
        .cp0_mmu_mxr                (cp0_mmu_mxr),
        .cp0_mmu_sum                (cp0_mmu_sum),
        .cp0_yy_priv_mode           (cp0_yy_priv_mode),
        .regs_mmu_en                (regs_mmu_en),
        .regs_utlb_clr              (regs_utlb_clr),
        .hpcp_mmu_cnt_en            (hpcp_mmu_cnt_en),
        
        // LSU Ports 0/1/STAMO
        .lsu_mmu_va0_vld            (lsu_mmu_va0_vld),
        .lsu_mmu_va0                (lsu_mmu_va0),
        .lsu_mmu_id0                (lsu_mmu_id0),
        .lsu_mmu_st_inst0           (lsu_mmu_st_inst0),
        .lsu_mmu_vabuf0             (lsu_mmu_vabuf0),
        .lsu_mmu_abort0             (lsu_mmu_abort0),
        .mmu_lsu_pa0_vld            (mmu_lsu_pa0_vld),
        .mmu_lsu_pa0                (mmu_lsu_pa0),
        .mmu_lsu_buf0               (mmu_lsu_buf0),
        .mmu_lsu_ca0                (mmu_lsu_ca0),
        .mmu_lsu_sh0                (mmu_lsu_sh0),
        .mmu_lsu_so0                (mmu_lsu_so0),
        .mmu_lsu_access_fault0      (mmu_lsu_access_fault0),
        .mmu_lsu_page_fault0        (mmu_lsu_page_fault0),
        .mmu_lsu_sec0               (mmu_lsu_sec0),
        .mmu_lsu_stall0             (mmu_lsu_stall0),
        
        .lsu_mmu_va1_vld            (lsu_mmu_va1_vld),
        .lsu_mmu_va1                (lsu_mmu_va1),
        .lsu_mmu_id1                (lsu_mmu_id1),
        .lsu_mmu_st_inst1           (lsu_mmu_st_inst1),
        .lsu_mmu_vabuf1             (lsu_mmu_vabuf1),
        .lsu_mmu_abort1             (lsu_mmu_abort1),
        .mmu_lsu_pa1_vld            (mmu_lsu_pa1_vld),
        .mmu_lsu_pa1                (mmu_lsu_pa1),
        .mmu_lsu_buf1               (mmu_lsu_buf1),
        .mmu_lsu_ca1                (mmu_lsu_ca1),
        .mmu_lsu_sh1                (mmu_lsu_sh1),
        .mmu_lsu_so1                (mmu_lsu_so1),
        .mmu_lsu_access_fault1      (mmu_lsu_access_fault1),
        .mmu_lsu_page_fault1        (mmu_lsu_page_fault1),
        .mmu_lsu_sec1               (mmu_lsu_sec1),
        .mmu_lsu_stall1             (mmu_lsu_stall1),
        
        .lsu_mmu_stamo_vld          (lsu_mmu_stamo_vld),
        .lsu_mmu_stamo_pa           (lsu_mmu_stamo_pa),
        .mmu_hpcp_dutlb_miss        (mmu_hpcp_dutlb_miss),
        .mmu_lsu_tlb_busy           (mmu_lsu_tlb_busy),
        .mmu_lsu_tlb_wakeup         (mmu_lsu_tlb_wakeup),
        
        .mmu_pmp_pa0                (mmu_pmp_pa0),
        .mmu_pmp_pa1                (mmu_pmp_pa1),
        .pmp_mmu_flg0               (pmp_mmu_flg0),
        .pmp_mmu_flg1               (pmp_mmu_flg1),
        .sysmap_mmu_flg0            (sysmap_mmu_flg0),
        .sysmap_mmu_flg1            (sysmap_mmu_flg1),
        .mmu_sysmap_pa0             (mmu_sysmap_pa0),
        .mmu_sysmap_pa1             (mmu_sysmap_pa1),
        
        .rtu_yy_xx_flush            (rtu_yy_xx_flush),
        .tlboper_utlb_clr           (tlboper_utlb_clr),
        .tlboper_utlb_inv_va_req    (tlboper_utlb_inv_va_req),
        .lsu_mmu_tlb_va             (lsu_mmu_tlb_va),
        
        // PTW Refill
        .ptw_l1dtlb_ref_pavld       (ptw_l1dtlb_ref_pa_vld),
        .ptw_l1dtlb_ref_cmplt       (ptw_l1dtlb_cmplt),
        .ptw_l1dtlb_ref_id          (ptw_l1dtlb_id[2:0]), 
        .ptw_l1tlb_ref_vpn          (ptw_l1dtlb_ref_vpn),
        .ptw_l1tlb_ref_ppn          (ptw_l1dtlb_ref_ppn),
        .ptw_l1tlb_acc_err          (ptw_l1dtlb_ref_acc_err),
        .ptw_l1tlb_pgflt            (ptw_l1dtlb_pgflt),
        .ptw_l1tlb_ref_flg          (ptw_l1dtlb_ref_flg),
        .ptw_l1tlb_ref_pgs          (ptw_l1dtlb_ref_pgs),
        
        // L2TLB Request
        .credit_return              (l2tlb_dutlb_credit_return),
        .dutlb_l2tlb_req_vld        (dutlb_l2tlb_req_vld),
        .dutlb_l2tlb_req_vpn        (dutlb_l2tlb_req_vpn),
        .dutlb_l2tlb_req_eid        (dutlb_l2tlb_req_eid),
        .dutlb_l2tlb_req_is_load    (dutlb_l2tlb_req_is_load),
        
        .biu_mmu_smp_disable        (biu_mmu_smp_disable),
        .dutlb_ptw_wfc              (dutlb_ptw_wfc),
        .dutlb_top_ref_cur_st       (dutlb_top_ref_cur_st),
        .dutlb_top_ref_type         (dutlb_top_ref_type),
        .dutlb_top_scd_updt         (dutlb_top_scd_updt),
        .dutlb_xx_mmu_off           (dutlb_xx_mmu_off),
        
        // Refill from L2TLB Hit (Direct)
        .jtlb_dutlb_ref_pavld       (l2tlb_l1dtlb_ref_pavld),
        .jtlb_dutlb_ref_cmplt       (l2tlb_l1dtlb_ref_cmplt),
        .jtlb_dutlb_ref_id          (l2tlb_l1dtlb_ref_eid),
        .jtlb_utlb_ref_vpn          (l2tlb_l1tlb_ref_vpn),
        .jtlb_utlb_ref_ppn          (l2tlb_l1tlb_ref_ppn),
        .jtlb_dutlb_pgflt           (l2tlb_l1dtlb_pgflt),
        .jtlb_utlb_ref_flg          (l2tlb_l1tlb_ref_flg),
        .jtlb_utlb_ref_pgs          (l2tlb_l1tlb_ref_pgs)
    );

    //==========================================================
    // Instance L2TLB (JTLB)
    //==========================================================
    // &Instance("mmu_l2tlb", "x_mmu_l2tlb");
    mmu_l2tlb x_mmu_l2tlb (
        .cpurst_b                   (cpurst_b),
        .forever_cpuclk             (forever_cpuclk),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        .cp0_mmu_maee               (cp0_mmu_maee),
        .cp0_mmu_mpp                (cp0_mmu_mpp),
        .cp0_mmu_mprv               (cp0_mmu_mprv),
        .cp0_mmu_mxr                (cp0_mmu_mxr),
        .cp0_mmu_ptw_en             (cp0_mmu_ptw_en),
        .cp0_mmu_sum                (cp0_mmu_sum),
        .cp0_yy_priv_mode           (cp0_yy_priv_mode),
        .regs_l2tlb_cur_asid        (regs_jtlb_cur_asid),
        
        // PFU <=> Arb
        .l2tlb_arb_pfu_vpn          (l2tlb_arb_pfu_vpn),
        
        // Request Queue <=> Arb
        .queue_arb_req              (queue_arb_req),
        .queue_arb_vpn              (queue_arb_vpn),
        .queue_arb_eid              (queue_arb_eid),
        .queue_arb_trans_id         (queue_arb_trans_id),
        .queue_arb_acc_type         (queue_arb_acc_type),
        
        // PTW Write Req info
        .victim_way                 (victim_way),
        .rrpv_updata                (rrpv_updata),
        .l2tlb_arb_ptw_cmplt        (l2tlb_arb_ptw_cmplt), 
        
        .arb__l2tlb_queue_grant     (arb__l2tlb_queue_grant),
        
        // Arbiter Control & SRAM Access
        .arb_l2tlb_bank_sel         (arb_l2tlb_bank_sel),
        .arb_l2tlb_acc_type         (arb_l2tlb_acc_type),
        .arb_l2tlb_req              (arb_l2tlb_req),
        .arb_l2tlb_vpn              (arb_l2tlb_vpn),
        .arb_l2tlb_trans_id         (arb_l2tlb_trans_id),
        .arb_l2tlb_eid              (arb_l2tlb_eid),
        .arb_l2tlb_write            (arb_l2tlb_write),
        .arb_l2tlb_tag_din          (arb_l2tlb_tag_din),
        .arb_l2tlb_data_din         (arb_l2tlb_data_din),
        .arb_l2tlb_cmp_with_va      (arb_l2tlb_cmp_with_va),
        
        // Skew Indices from Arbiter
        .arb_l2tlb_idx_w0           (arb_l2tlb_idx_w0),
        .arb_l2tlb_idx_w1           (arb_l2tlb_idx_w1),
        .arb_l2tlb_idx_w2           (arb_l2tlb_idx_w2),
        .arb_l2tlb_idx_w3           (arb_l2tlb_idx_w3),
        .arb_l2tlb_idx_w4           (arb_l2tlb_idx_w4),
        .arb_l2tlb_idx_w5           (arb_l2tlb_idx_w5),
        .arb_l2tlb_idx_w6           (arb_l2tlb_idx_w6),
        .arb_l2tlb_idx_w7           (arb_l2tlb_idx_w7),
        
        .arb_l2tlb_size_bus         (arb_l2tlb_size_bus),
        .arb_l2tlb_rrpv_din         (arb_l2tlb_rrpv_din),
        
        // PTW <=> JTLB
        .ptw_l2tlb_ref_type         (ptw_l2tlb_type),
        .ptw_l2tlb_ref_acc_err      (ptw_l2tlb_ref_acc_err),
        .ptw_l2tlb_ref_cmplt        (ptw_l2tlb_cmplt),
        .ptw_l2tlb_ref_data_vld     (ptw_l2tlb_ref_data_vld),
        .ptw_l2tlb_ref_pgflt        (ptw_l2tlb_ref_pgflt),
        .ptw_l2tlb_ref_id           (ptw_l2tlb_id),
        .ptw_l2tlb_ref_flg          (ptw_l2tlb_flg),
        .ptw_ready                  (ptw_jtlb_ready),
        
        .l2tlb_ptw_id               (l2tlb_ptw_id),
        .l2tlb_ptw_req              (l2tlb_ptw_req),
        .l2tlb_ptw_type             (l2tlb_ptw_type),
        .l2tlb_ptw_vpn              (l2tlb_ptw_vpn),
        
        // JTLB => uTLB
        .l2tlb_l1dtlb_pgflt         (l2tlb_l1dtlb_pgflt),
        .l2tlb_l1dtlb_ref_cmplt     (l2tlb_l1dtlb_ref_cmplt),
        .l2tlb_l1dtlb_ref_pavld     (l2tlb_l1dtlb_ref_pavld),
        .l2tlb_l1dtlb_ref_eid       (l2tlb_l1dtlb_ref_eid),
        
        .l2tlb_l1itlb_pgflt         (l2tlb_l1itlb_pgflt),
        .l2tlb_l1itlb_ref_cmplt     (l2tlb_l1itlb_ref_cmplt),
        .l2tlb_l1itlb_ref_pavld     (l2tlb_l1itlb_ref_pavld),
        
        .l2tlb_l1tlb_ref_flg        (l2tlb_l1tlb_ref_flg),
        .l2tlb_l1tlb_ref_pgs        (l2tlb_l1tlb_ref_pgs),
        .l2tlb_l1tlb_ref_ppn        (l2tlb_l1tlb_ref_ppn),
        .l2tlb_l1tlb_ref_vpn        (l2tlb_l1tlb_ref_vpn),
        .l2tlb_top_utlb_pavld       (l2tlb_top_utlb_pavld),
        
        // L1 ITLB Interface
        .i_req_valid                (iutlb_l2tlb_req),
        .i_req_vpn                  (iutlb_l2tlb_vpn),
        .i_credit_return            (l2tlb_iutlb_credit_return),
        
        // L1 DTLB Interface
        .d_req_valid                (dutlb_l2tlb_req_vld),
        .d_req_vpn                  (dutlb_l2tlb_req_vpn),
        .d_req_eid                  (dutlb_l2tlb_req_eid),
        .d_req_is_load              (dutlb_l2tlb_req_is_load),
        .d_credit_return            (l2tlb_dutlb_credit_return),
        
        // PFU
        .l1dtlb_xx_mmu_off          (dutlb_xx_mmu_off),
        .lsu_mmu_va2                (lsu_mmu_va2),
        .lsu_mmu_va2_vld            (lsu_mmu_va2_vld),
        .mmu_lsu_pa2                (mmu_lsu_pa2),
        .mmu_lsu_pa2_err            (mmu_lsu_pa2_err),
        .mmu_lsu_pa2_vld            (mmu_lsu_pa2_vld),
        .mmu_lsu_sec2               (mmu_lsu_sec2),
        .mmu_lsu_share2             (mmu_lsu_share2),
        
        // TLB Oper
        .tlboper_l2tlb_asid         (tlboper_l2tlb_asid),
        .tlboper_l2tlb_asid_sel     (tlboper_l2tlb_asid_sel),
        .tlboper_l2tlb_cmp_noasid   (tlboper_l2tlb_cmp_noasid),
        .tlboper_l2tlb_inv_asid     (tlboper_l2tlb_inv_asid),
        .tlboper_l2tlb_tlbwr_on     (tlboper_l2tlb_tlbwr_on),
        .tlboper_xx_pgs             (tlboper_xx_pgs),
        .tlboper_ptw_abort          (tlboper_ptw_abort),
        
        .l2tlb_regs_hit             (l2tlb_regs_hit),
        .l2tlb_regs_hit_mult        (l2tlb_regs_hit_mult),
        .l2tlb_regs_tlbp_hit_index  (l2tlb_regs_tlbp_hit_index),
        .l2tlb_tlboper_asid_hit     (l2tlb_tlboper_asid_hit),
        .l2tlb_tlboper_cmplt        (l2tlb_tlboper_cmplt),
        .l2tlb_tlboper_sel          (l2tlb_tlboper_sel),
        .l2tlb_tlboper_va_hit       (l2tlb_tlboper_va_hit),
        
        .l2tlb_tlbr_asid            (l2tlb_tlbr_asid),
        .l2tlb_tlbr_flg             (l2tlb_tlbr_flg),
        .l2tlb_tlbr_g               (l2tlb_tlbr_g),
        .l2tlb_tlbr_pgs             (l2tlb_tlbr_pgs),
        .l2tlb_tlbr_ppn             (l2tlb_tlbr_ppn),
        .l2tlb_tlbr_vpn             (l2tlb_tlbr_vpn),
        
        // PMP/Sysmap
        .pmp_mmu_flg4               (pmp_mmu_flg4),
        .mmu_pmp_pa4                (mmu_pmp_pa4),
        .sysmap_mmu_flg4            (sysmap_mmu_flg4),
        .mmu_sysmap_pa4             (mmu_sysmap_pa4)
    );

    //==========================================================
    // Instance Arbiter
    //==========================================================
    // &Instance("mmu_arb", "x_mmu_arb");
    mmu_arb x_mmu_arb (
        .forever_cpuclk             (forever_cpuclk),
        .cpurst_b                   (cpurst_b),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        .cp0_mmu_no_op_req          (cp0_mmu_no_op_req),
        
        // ReqQ Interface
        .issue_valid                (queue_arb_req),
        .issue_vpn                  (queue_arb_vpn),
        .issue_eid                  (queue_arb_eid),
        .issue_type                 (queue_arb_acc_type),
        .issue_queue_id             (queue_arb_trans_id),
        .arb_reqq_grant             (arb__l2tlb_queue_grant),
        
        .ptw_xx_cmplt               (l2tlb_arb_ptw_cmplt), 
        .victim_way                 (victim_way),
        .rrpv_updata                (rrpv_updata),
        
        // PTW Interface
        .ptw_arb_req                (ptw_arb_req),
        .ptw_arb_vpn                (ptw_arb_vpn),
        .ptw_arb_pgs                (ptw_arb_pgs),
        .ptw_arb_tag_din            (ptw_arb_ref_tag_din),
        .ptw_arb_data_din           (ptw_arb_ref_data_din),
        .arb_ptw_grant              (arb_ptw_grant),
        .arb_ptw_mask               (arb_ptw_mask),
        
        // TLB Oper
        .tlboper_arb_bank_sel       (tlboper_arb_bank_sel),
        .tlboper_arb_cmp_va         (tlboper_arb_cmp_va),
        .tlboper_arb_idx            (tlboper_arb_idx),
        .tlboper_arb_idx_not_va     (tlboper_arb_idx_not_va),
        .tlboper_arb_req            (tlboper_arb_req),
        .tlboper_arb_vpn            (tlboper_arb_vpn),
        .tlboper_arb_write          (tlboper_arb_write),
        .tlboper_arb_tag_din        (tlboper_arb_tag_din),
        .tlboper_arb_data_din       (tlboper_arb_data_din),
        .tlboper_xx_cmplt           (tlboper_xx_cmplt),
        .arb_tlboper_grant          (arb_tlboper_grant),
        
        // PFU
        .mmu_lsu_pa2_err            (mmu_lsu_pa2_err),
        .mmu_lsu_pa2_vld            (mmu_lsu_pa2_vld),
        .lsu_mmu_va2_vld            (lsu_mmu_va2_vld),
        .l2tlb_arb_pfu_vpn          (l2tlb_arb_pfu_vpn),
        .dutlb_xx_mmu_off           (dutlb_xx_mmu_off),
        .arb_pfu_grant              (arb_pfu_grant),
        
        // Output to L2TLB
        .arb_l2tlb_req              (arb_l2tlb_req),
        .arb_l2tlb_vpn              (arb_l2tlb_vpn),
        .arb_l2tlb_write            (arb_l2tlb_write),
        .arb_l2tlb_tag_din          (arb_l2tlb_tag_din),
        .arb_l2tlb_data_din         (arb_l2tlb_data_din),
        .arb_l2tlb_trans_id         (arb_l2tlb_trans_id),
        .arb_l2tlb_eid              (arb_l2tlb_eid),
        .arb_l2tlb_acc_type         (arb_l2tlb_acc_type),
        .arb_l2tlb_bank_sel         (arb_l2tlb_bank_sel),
        .arb_l2tlb_cmp_with_va      (arb_l2tlb_cmp_with_va),
        .arb_l2tlb_rrpv_din         (arb_l2tlb_rrpv_din),
        
        .arb_l2tlb_idx_w0           (arb_l2tlb_idx_w0),
        .arb_l2tlb_idx_w1           (arb_l2tlb_idx_w1),
        .arb_l2tlb_idx_w2           (arb_l2tlb_idx_w2),
        .arb_l2tlb_idx_w3           (arb_l2tlb_idx_w3),
        .arb_l2tlb_idx_w4           (arb_l2tlb_idx_w4),
        .arb_l2tlb_idx_w5           (arb_l2tlb_idx_w5),
        .arb_l2tlb_idx_w6           (arb_l2tlb_idx_w6),
        .arb_l2tlb_idx_w7           (arb_l2tlb_idx_w7),
        
        .arb_l2tlb_size_bus         (arb_l2tlb_size_bus),
        .mmu_yy_xx_no_op            (mmu_yy_xx_no_op),
        .arb_top_tlboper_on         (arb_top_tlboper_on)
    );

    //==========================================================
    // Instance PTW
    //==========================================================
    // &Instance("ptw", "x_ct_mmu_ptw");
    ptw x_ct_mmu_ptw (
        .forever_cpuclk             (forever_cpuclk),
        .cpurst_b                   (cpurst_b),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        .cp0_mmu_maee               (cp0_mmu_maee),
        .cp0_mmu_mpp                (cp0_mmu_mpp),
        .cp0_mmu_mprv               (cp0_mmu_mprv),
        .cp0_mmu_mxr                (cp0_mmu_mxr),
        .cp0_mmu_sum                (cp0_mmu_sum),
        .cp0_yy_priv_mode           (cp0_yy_priv_mode),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        .hpcp_mmu_cnt_en            (hpcp_mmu_cnt_en),
        .regs_ptw_cur_asid          (regs_ptw_cur_asid),
        .regs_ptw_satp_ppn          (regs_ptw_satp_ppn),
        .regs_ptw_clr               (regs_ptw_clr),
        
        // Sysmap Ports 3-6
        .sysmap_mmu_flg3            (sysmap_mmu_flg3),
        .sysmap_mmu_flg5            (sysmap_mmu_flg5), 
        .sysmap_mmu_flg6            (sysmap_mmu_flg6), 
        .sysmap_mmu_flg7            (sysmap_mmu_flg7),
        .sysmap_mmu_flg8            (sysmap_mmu_flg8),
        .sysmap_mmu_flg9            (sysmap_mmu_flg9),
        .sysmap_mmu_flg10           (sysmap_mmu_flg10),
        .sysmap_mmu_flg11           (sysmap_mmu_flg11),
        .sysmap_mmu_flg12           (sysmap_mmu_flg12),
        .sysmap_mmu_flg13           (sysmap_mmu_flg13),
        .sysmap_mmu_flg14           (sysmap_mmu_flg14),
        .sysmap_mmu_flg15           (sysmap_mmu_flg15),
        .sysmap_mmu_hit3            (sysmap_mmu_hit3),
        .sysmap_mmu_hit5            (sysmap_mmu_hit5), 
        .sysmap_mmu_hit6            (sysmap_mmu_hit6), 
        .sysmap_mmu_hit7            (sysmap_mmu_hit7),
        .sysmap_mmu_hit8            (sysmap_mmu_hit8),
        .sysmap_mmu_hit9            (sysmap_mmu_hit9),
        .sysmap_mmu_hit10           (sysmap_mmu_hit10),
        .sysmap_mmu_hit11           (sysmap_mmu_hit11),
        .sysmap_mmu_hit12           (sysmap_mmu_hit12),
        .sysmap_mmu_hit13           (sysmap_mmu_hit13),
        .sysmap_mmu_hit14           (sysmap_mmu_hit14),
        .sysmap_mmu_hit15           (sysmap_mmu_hit15),
        .mmu_sysmap_pa3             (mmu_sysmap_pa3),
        .mmu_sysmap_pa5             (mmu_sysmap_pa5),
        .mmu_sysmap_pa6             (mmu_sysmap_pa6),
        .mmu_sysmap_pa7             (mmu_sysmap_pa7),
        .mmu_sysmap_pa8             (mmu_sysmap_pa8),
        .mmu_sysmap_pa9             (mmu_sysmap_pa9),
        .mmu_sysmap_pa10            (mmu_sysmap_pa10),
        .mmu_sysmap_pa11            (mmu_sysmap_pa11),
        .mmu_sysmap_pa12            (mmu_sysmap_pa12),
        .mmu_sysmap_pa13            (mmu_sysmap_pa13),
        .mmu_sysmap_pa14            (mmu_sysmap_pa14),
        .mmu_sysmap_pa15            (mmu_sysmap_pa15),
        
        // PMP Ports 3-6
        .pmp_mmu_flg3               (pmp_mmu_flg3),
        .pmp_mmu_flg7               (pmp_mmu_flg7),
        .pmp_mmu_flg5               (pmp_mmu_flg5), 
        .pmp_mmu_flg6               (pmp_mmu_flg6), 
        .mmu_pmp_pa3                (mmu_pmp_pa3),
        .mmu_pmp_pa7                (mmu_pmp_pa7),
        .mmu_pmp_pa5                (mmu_pmp_pa5),
        .mmu_pmp_pa6                (mmu_pmp_pa6),
        .mmu_pmp_fetch3             (mmu_pmp_fetch3),
        .mmu_pmp_fetch7             (mmu_pmp_fetch7),
        .mmu_pmp_fetch5             (mmu_pmp_fetch5),
        .mmu_pmp_fetch6             (mmu_pmp_fetch6),
        .pmp_regs_update            (pmp_regs_update),
        // From L2TLB
        .l2tlb_ptw_req              (l2tlb_ptw_req),
        .l2tlb_ptw_type             (l2tlb_ptw_type),
        .l2tlb_ptw_vpn              (l2tlb_ptw_vpn),
        .l2tlb_ptw_id               (l2tlb_ptw_id),
        
        // LSU
        .lsu_mmu_bus_error          (lsu_mmu_bus_error),
        .lsu_mmu_data               (lsu_mmu_data),
        .lsu_mmu_data_vld           (lsu_mmu_data_vld),
        .mmu_lsu_data_req           (mmu_lsu_data_req),
        .mmu_lsu_data_req_addr      (mmu_lsu_data_req_addr),
        .mmu_lsu_data_req_size      (mmu_lsu_data_req_size),
        
        // To Arbiter
        .arb_ptw_grant              (arb_ptw_grant),
        .arb_ptw_mask               (arb_ptw_mask),
        .ptw_arb_vpn                (ptw_arb_vpn),
        .ptw_arb_req                (ptw_arb_req),
        .ptw_arb_ref_data_din       (ptw_arb_ref_data_din),
        .ptw_arb_ref_tag_din        (ptw_arb_ref_tag_din),
        .ptw_arb_ref_pgs            (ptw_arb_pgs),
        
        // To L1 DTLB
        .ptw_l1dtlb_ref_pa_vld      (ptw_l1dtlb_ref_pa_vld),
        .ptw_l1dtlb_ref_vpn         (ptw_l1dtlb_ref_vpn),
        .ptw_l1dtlb_ref_pgs         (ptw_l1dtlb_ref_pgs),
        .ptw_l1dtlb_ref_ppn         (ptw_l1dtlb_ref_ppn),
        .ptw_l1dtlb_ref_flg         (ptw_l1dtlb_ref_flg),
        .ptw_l1tlb_id               (ptw_l1dtlb_id), 
        .ptw_l1dtlb_cmplt           (ptw_l1dtlb_cmplt),
        .ptw_l1dtlb_pgflt          (ptw_l1dtlb_pgflt),
        .ptw_l1dtlb_ref_acc_err     (ptw_l1dtlb_ref_acc_err),
        
        // To L1 ITLB
        .ptw_l1itlb_ref_pa_vld      (ptw_l1itlb_ref_pa_vld),
        .ptw_l1itlb_ref_vpn         (ptw_l1itlb_ref_vpn),
        .ptw_l1itlb_ref_pgs         (ptw_l1itlb_ref_pgs),
        .ptw_l1itlb_ref_ppn         (ptw_l1itlb_ref_ppn),
        .ptw_l1itlb_ref_flg         (ptw_l1itlb_ref_flg),
        .ptw_l1itlb_cmplt           (ptw_l1itlb_cmplt),
        .ptw_l1itlb_pgflt          (ptw_l1itlb_pgflt),
        .ptw_l1itlb_ref_acc_err     (ptw_l1itlb_ref_acc_err),
        
        // To L2TLB (Fault/Complete)
        .ptw_l2tlb_ref_acc_err      (ptw_l2tlb_ref_acc_err),
        .ptw_l2tlb_ref_pgflt        (ptw_l2tlb_ref_pgflt),
        .ptw_l2tlb_ref_data_vld     (ptw_l2tlb_ref_data_vld),
        .ptw_l2tlb_cmplt            (ptw_l2tlb_cmplt),
        .ptw_l2tlb_type             (ptw_l2tlb_type),
        .ptw_l2tlb_id               (ptw_l2tlb_id),
        .ptw_l2tlb_flg              (ptw_l2tlb_flg),
        .ptw_jtlb_ready             (ptw_jtlb_ready),
        
        .tlboper_ptw_abort          (tlboper_ptw_abort),
        //.ptw_top_imiss              (ptw_top_imiss),
        .mmu_hpcp_jtlb_miss         (mmu_hpcp_jtlb_miss)
    );

    //==========================================================
    // Instance Regs
    //==========================================================
    // &Instance("ct_mmu_regs", "x_ct_mmu_regs");
    ct_mmu_regs x_ct_mmu_regs (
        .cp0_mmu_cskyee             (cp0_mmu_cskyee),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        .cp0_mmu_mpp                (cp0_mmu_mpp),
        .cp0_mmu_mprv               (cp0_mmu_mprv),
        .cp0_mmu_reg_num            (cp0_mmu_reg_num),
        .cp0_mmu_satp_sel           (cp0_mmu_satp_sel),
        .cp0_mmu_wdata              (cp0_mmu_wdata),
        .cp0_mmu_wreg               (cp0_mmu_wreg),
        .cp0_yy_priv_mode           (cp0_yy_priv_mode),
        .mmu_cp0_cmplt              (mmu_cp0_cmplt),
        .mmu_cp0_data               (mmu_cp0_data),
        .mmu_cp0_satp_data          (mmu_cp0_satp_data),
        .cpurst_b                   (cpurst_b),
        .forever_cpuclk             (forever_cpuclk),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        
        .jtlb_regs_hit              (l2tlb_regs_hit),
        .jtlb_regs_hit_mult         (l2tlb_regs_hit_mult),
        .jtlb_regs_tlbp_hit_index   (l2tlb_regs_tlbp_hit_index),
        
        .jtlb_tlbr_asid             (l2tlb_tlbr_asid),
        .jtlb_tlbr_flg              (l2tlb_tlbr_flg),
        .jtlb_tlbr_g                (l2tlb_tlbr_g),
        .jtlb_tlbr_pgs              (l2tlb_tlbr_pgs),
        .jtlb_tlbr_ppn              (l2tlb_tlbr_ppn),
        .jtlb_tlbr_vpn              (l2tlb_tlbr_vpn),
        
        .regs_jtlb_cur_asid         (regs_jtlb_cur_asid),
        .regs_jtlb_cur_flg          (regs_jtlb_cur_flg),
        .regs_jtlb_cur_g            (regs_jtlb_cur_g),
        .regs_jtlb_cur_ppn          (regs_jtlb_cur_ppn),
        
        .rtu_mmu_bad_vpn            (rtu_mmu_bad_vpn),
        .rtu_mmu_expt_vld           (rtu_mmu_expt_vld),
        
        .tlboper_regs_cmplt         (tlboper_regs_cmplt),
        .tlboper_regs_tlbp_cmplt    (tlboper_regs_tlbp_cmplt),
        .tlboper_regs_tlbr_cmplt    (tlboper_regs_tlbr_cmplt),
        
        .regs_tlboper_cur_asid      (regs_tlboper_cur_asid),
        .regs_tlboper_cur_pgs       (regs_tlboper_cur_pgs),
        .regs_tlboper_cur_vpn       (regs_tlboper_cur_vpn),
        .regs_tlboper_inv_asid      (regs_tlboper_inv_asid),
        .regs_tlboper_invall        (regs_tlboper_invall),
        .regs_tlboper_invasid       (regs_tlboper_invasid),
        .regs_tlboper_mir           (regs_tlboper_mir),
        .regs_tlboper_tlbp          (regs_tlboper_tlbp),
        .regs_tlboper_tlbr          (regs_tlboper_tlbr),
        .regs_tlboper_tlbwi         (regs_tlboper_tlbwi),
        .regs_tlboper_tlbwr         (regs_tlboper_tlbwr),
        
        .regs_ptw_cur_asid          (regs_ptw_cur_asid),
        .regs_ptw_satp_ppn          (regs_ptw_satp_ppn),
        .regs_utlb_clr              (regs_utlb_clr),
        
        .mmu_lsu_mmu_en             (mmu_lsu_mmu_en),
        .mmu_xx_mmu_en              (mmu_xx_mmu_en),
        .regs_mmu_en                (regs_mmu_en)
    );

    //==========================================================
    // Instance TLB Oper
    //==========================================================
    // &Instance("ct_mmu_tlboper", "x_ct_mmu_tlboper");
    ct_mmu_tlboper x_ct_mmu_tlboper (
        .cpurst_b                   (cpurst_b),
        .forever_cpuclk             (forever_cpuclk),
        .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
        .cp0_mmu_icg_en             (cp0_mmu_icg_en),
        
        .lsu_mmu_tlb_all_inv        (lsu_mmu_tlb_all_inv),
        .lsu_mmu_tlb_asid_all_inv   (lsu_mmu_tlb_asid_all_inv),
        .lsu_mmu_tlb_va_all_inv     (lsu_mmu_tlb_va_all_inv),
        .lsu_mmu_tlb_va_asid_inv    (lsu_mmu_tlb_va_asid_inv),
        .lsu_mmu_tlb_asid           (lsu_mmu_tlb_asid),
        .lsu_mmu_tlb_va             (lsu_mmu_tlb_va),
        .mmu_lsu_tlb_inv_done       (mmu_lsu_tlb_inv_done),
        
        .regs_tlboper_invall        (regs_tlboper_invall),
        .regs_tlboper_invasid       (regs_tlboper_invasid),
        .regs_tlboper_tlbp          (regs_tlboper_tlbp),
        .regs_tlboper_tlbr          (regs_tlboper_tlbr),
        .regs_tlboper_tlbwi         (regs_tlboper_tlbwi),
        .regs_tlboper_tlbwr         (regs_tlboper_tlbwr),
        .regs_tlboper_inv_asid      (regs_tlboper_inv_asid),
        
        .regs_jtlb_cur_flg          (regs_jtlb_cur_flg),
        .regs_jtlb_cur_g            (regs_jtlb_cur_g),
        .regs_jtlb_cur_ppn          (regs_jtlb_cur_ppn),
        
        .regs_tlboper_cur_asid      (regs_tlboper_cur_asid),
        .regs_tlboper_cur_pgs       (regs_tlboper_cur_pgs),
        .regs_tlboper_cur_vpn       (regs_tlboper_cur_vpn),
        .regs_tlboper_mir           (regs_tlboper_mir),
        
        .tlboper_regs_cmplt         (tlboper_regs_cmplt),
        .tlboper_regs_tlbp_cmplt    (tlboper_regs_tlbp_cmplt),
        .tlboper_regs_tlbr_cmplt    (tlboper_regs_tlbr_cmplt),
        
        .cp0_mmu_tlb_all_inv        (cp0_mmu_tlb_all_inv),
        .mmu_cp0_tlb_done           (mmu_cp0_tlb_done),
        
        // L2TLB Control
        .tlboper_jtlb_asid          (tlboper_l2tlb_asid),
        .tlboper_jtlb_asid_sel      (tlboper_l2tlb_asid_sel),
        .tlboper_jtlb_cmp_noasid    (tlboper_l2tlb_cmp_noasid),
        .tlboper_jtlb_inv_asid      (tlboper_l2tlb_inv_asid),
        .tlboper_jtlb_tlbwr_on      (tlboper_l2tlb_tlbwr_on),
        
        .jtlb_tlboper_asid_hit      (l2tlb_tlboper_asid_hit),
        .jtlb_tlboper_cmplt         (l2tlb_tlboper_cmplt),
        .jtlb_tlboper_sel           (l2tlb_tlboper_sel),
        .jtlb_tlboper_va_hit        (l2tlb_tlboper_va_hit),
        
        // Arbiter
        .tlboper_arb_req            (tlboper_arb_req),
        .tlboper_arb_write          (tlboper_arb_write),
        .tlboper_arb_tag_din        (tlboper_arb_tag_din),
        .tlboper_arb_vpn            (tlboper_arb_vpn),
        .tlboper_arb_bank_sel       (tlboper_arb_bank_sel),
        .tlboper_arb_cmp_va         (tlboper_arb_cmp_va),
        .tlboper_arb_data_din       (tlboper_arb_data_din),
        .tlboper_arb_idx            (tlboper_arb_idx),
        .tlboper_arb_idx_not_va     (tlboper_arb_idx_not_va),
        .arb_tlboper_grant          (arb_tlboper_grant),
        
        .tlboper_utlb_inv_va_req    (tlboper_utlb_inv_va_req),
        .tlboper_utlb_clr           (tlboper_utlb_clr),
        .tlboper_ptw_abort          (tlboper_ptw_abort),
        
        .tlboper_top_lsu_cmplt      (tlboper_top_lsu_cmplt),
        .tlboper_top_lsu_oper       (tlboper_top_lsu_oper),
        .tlboper_top_tlbiall_cur_st (tlboper_top_tlbiall_cur_st),
        .tlboper_top_tlbiasid_cur_st(tlboper_top_tlbiasid_cur_st),
        .tlboper_top_tlbiva_cur_st  (tlboper_top_tlbiva_cur_st),
        .tlboper_top_tlbp_cur_st    (tlboper_top_tlbp_cur_st),
        .tlboper_top_tlbr_cur_st    (tlboper_top_tlbr_cur_st),
        .tlboper_top_tlbwi_cur_st   (tlboper_top_tlbwi_cur_st),
        .tlboper_top_tlbwr_cur_st   (tlboper_top_tlbwr_cur_st),
        .tlboper_xx_cmplt           (tlboper_xx_cmplt),
        .tlboper_xx_pgs             (tlboper_xx_pgs)
    );

    //==========================================================
    // Instance System Map
    //==========================================================
    // &ConnRule(s/_y/0/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_0");
    ct_mmu_sysmap x_ct_mmu_sysmap_0 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa0),
        .sysmap_mmu_flg_y(sysmap_mmu_flg0),
        .sysmap_mmu_hit_y(sysmap_mmu_hit0)
    );

    // &ConnRule(s/_y/1/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_1");
    ct_mmu_sysmap x_ct_mmu_sysmap_1 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa1),
        .sysmap_mmu_flg_y(sysmap_mmu_flg1),
        .sysmap_mmu_hit_y(sysmap_mmu_hit1)
    );

    // &ConnRule(s/_y/2/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_2");
    ct_mmu_sysmap x_ct_mmu_sysmap_2 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa2),
        .sysmap_mmu_flg_y(sysmap_mmu_flg2),
        .sysmap_mmu_hit_y(sysmap_mmu_hit2)
    );

    // &ConnRule(s/_y/3/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_3");
    ct_mmu_sysmap x_ct_mmu_sysmap_3 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa3),
        .sysmap_mmu_flg_y(sysmap_mmu_flg3),
        .sysmap_mmu_hit_y(sysmap_mmu_hit3)
    );

    // &ConnRule(s/_y/4/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_4");
    ct_mmu_sysmap x_ct_mmu_sysmap_4 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa4),
        .sysmap_mmu_flg_y(sysmap_mmu_flg4),
        .sysmap_mmu_hit_y(sysmap_mmu_hit4)
    );
    
    // [NEW] Sysmap Instances for PTW Ports 5 & 6
    // &ConnRule(s/_y/5/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_5");
    ct_mmu_sysmap x_ct_mmu_sysmap_5 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa5),
        .sysmap_mmu_flg_y(sysmap_mmu_flg5),
        .sysmap_mmu_hit_y(sysmap_mmu_hit5)
    );

    // &ConnRule(s/_y/6/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_6");
    ct_mmu_sysmap x_ct_mmu_sysmap_6 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa6),
        .sysmap_mmu_flg_y(sysmap_mmu_flg6),
        .sysmap_mmu_hit_y(sysmap_mmu_hit6)
    );

    // &ConnRule(s/_y/6/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_6");
    ct_mmu_sysmap x_ct_mmu_sysmap_7 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa7),
        .sysmap_mmu_flg_y(sysmap_mmu_flg7),
        .sysmap_mmu_hit_y(sysmap_mmu_hit7)
    );


    // &ConnRule(s/_y/8/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_8");
    ct_mmu_sysmap x_ct_mmu_sysmap_8 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa8),
        .sysmap_mmu_flg_y(sysmap_mmu_flg8),
        .sysmap_mmu_hit_y(sysmap_mmu_hit8)
    );


    // &ConnRule(s/_y/9/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_9");
    ct_mmu_sysmap x_ct_mmu_sysmap_9 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa9),
        .sysmap_mmu_flg_y(sysmap_mmu_flg9),
        .sysmap_mmu_hit_y(sysmap_mmu_hit9)
    );

    // &ConnRule(s/_y/10/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_10");
    ct_mmu_sysmap x_ct_mmu_sysmap_10 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa10),
        .sysmap_mmu_flg_y(sysmap_mmu_flg10),
        .sysmap_mmu_hit_y(sysmap_mmu_hit10)
    );

    // &ConnRule(s/_y/11/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_11");
    ct_mmu_sysmap x_ct_mmu_sysmap_11 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa11),
        .sysmap_mmu_flg_y(sysmap_mmu_flg11),
        .sysmap_mmu_hit_y(sysmap_mmu_hit11)
    );

    // &ConnRule(s/_y/12/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_12");
    ct_mmu_sysmap x_ct_mmu_sysmap_12 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa12),
        .sysmap_mmu_flg_y(sysmap_mmu_flg12),
        .sysmap_mmu_hit_y(sysmap_mmu_hit12)
    );

    // &ConnRule(s/_y/13/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_13");
    ct_mmu_sysmap x_ct_mmu_sysmap_13 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa13),
        .sysmap_mmu_flg_y(sysmap_mmu_flg13),
        .sysmap_mmu_hit_y(sysmap_mmu_hit13)
    );

    // &ConnRule(s/_y/14/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_14");
    ct_mmu_sysmap x_ct_mmu_sysmap_14 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa14),
        .sysmap_mmu_flg_y(sysmap_mmu_flg14),
        .sysmap_mmu_hit_y(sysmap_mmu_hit14)
    );
    
    // &ConnRule(s/_y/15/);
    // &Instance("ct_mmu_sysmap", "x_ct_mmu_sysmap_15");
    ct_mmu_sysmap x_ct_mmu_sysmap_15 (
        .mmu_sysmap_pa_y (mmu_sysmap_pa15),
        .sysmap_mmu_flg_y(sysmap_mmu_flg15),
        .sysmap_mmu_hit_y(sysmap_mmu_hit15)
    );

    // for dbg
    assign mmu_had_debug_info[33:0] = {
        iutlb_top_ref_cur_st[1:0],
        dutlb_top_ref_cur_st[2:0], 
        dutlb_top_ref_type,
        tlboper_top_tlbp_cur_st[1:0], 
        tlboper_top_tlbr_cur_st[1:0],
        tlboper_top_tlbwi_cur_st[1:0], 
        tlboper_top_tlbwr_cur_st[1:0],
        tlboper_top_tlbiasid_cur_st[2:0], 
        tlboper_top_tlbiall_cur_st,
        tlboper_top_tlbiva_cur_st[3:0], 
        tlboper_top_lsu_oper, 
        tlboper_top_lsu_cmplt,
        2'b00, 
        arb_top_tlboper_on, 
        2'b00,
        4'b0000, 
        1'b0
    };

    // &ModuleEnd; @200
endmodule

