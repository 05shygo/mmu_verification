//!********************************************************************
//!  OpenRiscv2030
//!
//!    L1ITLB (Level 1 Instruction Translation Lookaside Buffer)
//!********************************************************************


module mmu_l1itlb(

//!**********************************************
//! Clock and Reset
//!**********************************************
input  logic         cpurst_b,               
input  logic         forever_cpuclk,         
input  logic         utlb_clk,               

//!**********************************************
//! SysReg
//!**********************************************
input  logic         cp0_mmu_icg_en,         
input  logic         cp0_mmu_no_op_req,      
input  logic         cp0_mmu_sum,            
input  logic [1 :0]  cp0_yy_priv_mode,       
input  logic         regs_mmu_en,            
input  logic         regs_utlb_clr,          

input  logic         pad_yy_icg_scan_en,     

//!**************************************************
//! IFU <=> MMU Interface
//!**************************************************
input  logic         ifu_mmu_va_vld,         
input  logic [62:0]  ifu_mmu_va,             
input  logic         ifu_mmu_abort,          

output logic         mmu_ifu_pavld,          
output logic [27:0]  mmu_ifu_pa,             
output logic         mmu_ifu_buf,            
output logic         mmu_ifu_ca,             
output logic         mmu_ifu_deny,           
output logic         mmu_ifu_pgflt,          
output logic         mmu_ifu_sec,            

//!**************************************************
//! PMP
//!**************************************************
output logic [27:0]  mmu_pmp_pa2,            
input  logic [3 :0]  pmp_mmu_flg2,           

//!**************************************************
//! System Map
//!**************************************************
output logic [27:0]  mmu_sysmap_pa2,
input  logic [4 :0]  sysmap_mmu_flg2,        

//!**************************************************
//! HPCP ??
//!**************************************************
input  logic         hpcp_mmu_cnt_en,        
output logic         mmu_hpcp_iutlb_miss,    

//!**************************************************
//! L1ITLB Invalidation
//!**************************************************
input  logic         tlboper_utlb_clr,       
input  logic         tlboper_utlb_inv_va_req, 
input  logic [26:0]  lsu_mmu_tlb_va,         


//!**************************************************
//! L1ITLB <=> L2TLB
//!**************************************************
//output logic         iutlb_arb_req,          
//output logic [26:0]  iutlb_arb_vpn,          
//output logic         iutlb_arb_cmplt,        

output logic         iutlb_l2tlb_req,          
output logic [26:0]  iutlb_l2tlb_vpn,

input  logic	     credit_return,
	          
//input  logic         arb_iutlb_grant,        

output logic         iutlb_ptw_wfc,          
output logic [1 :0]  iutlb_top_ref_cur_st,   
output logic         iutlb_top_scd_updt,     

    input  logic         ptw_l1itlb_ref_pavld,
    input  logic         ptw_l1itlb_ref_cmplt,
    input  logic [26:0]  ptw_l1tlb_ref_vpn,
    input  logic [27:0]  ptw_l1tlb_ref_ppn,
    input  logic         ptw_l1tlb_acc_err,
    input  logic         ptw_l1tlb_pgflt,
    input  logic [13:0]  ptw_l1tlb_ref_flg,
    input  logic [2:0]   ptw_l1tlb_ref_pgs,

input  logic         jtlb_iutlb_ref_pavld,   //! L2TLB Refill Valid
input  logic         jtlb_iutlb_ref_cmplt,   
input  logic [26:0]  jtlb_utlb_ref_vpn,      
input  logic [27:0]  jtlb_utlb_ref_ppn,      
input  logic [13:0]  jtlb_utlb_ref_flg,      
input  logic [2 :0]  jtlb_utlb_ref_pgs,      
//input  logic         jtlb_iutlb_acc_err,     
input  logic         jtlb_iutlb_pgflt

  );

logic     [3 :0]  iutlb_fst_wen;          
logic             iutlb_miss;             
logic     [27:0]  iutlb_pa_buf;           
logic     [31:0]  iutlb_plru_read_hit;    
logic             jtlb_acc_fault_flop;    
logic             pmp_flg_vld;            
logic     [2 :0]  ref_cur_st;             
logic     [2 :0]  ref_nxt_st;             

logic            cp0_mach_mode;          
logic            cp0_supv_mode;          
logic            cp0_user_mode;          
logic    [13:0]  entry0_flg;             
logic            entry0_hit;             
logic    [2 :0]  entry0_pgs;             
logic    [27:0]  entry0_ppn;             
logic            entry0_swp;             
logic            entry0_swp_on;          
logic            entry0_upd;             
logic            entry0_vld;             
logic    [26:0]  entry0_vpn;             
logic    [13:0]  entry10_flg;            
logic            entry10_hit;            
logic    [2 :0]  entry10_pgs;            
logic    [27:0]  entry10_ppn;            
logic            entry10_swp;            
logic            entry10_swp_on;         
logic            entry10_upd;            
logic            entry10_vld;            
logic    [13:0]  entry11_flg;            
logic            entry11_hit;            
logic    [2 :0]  entry11_pgs;            
logic    [27:0]  entry11_ppn;            
logic            entry11_swp;            
logic            entry11_swp_on;         
logic            entry11_upd;            
logic            entry11_vld;            
logic    [13:0]  entry12_flg;            
logic            entry12_hit;            
logic    [2 :0]  entry12_pgs;            
logic    [27:0]  entry12_ppn;            
logic            entry12_swp;            
logic            entry12_swp_on;         
logic            entry12_upd;            
logic            entry12_vld;            
logic    [13:0]  entry13_flg;            
logic            entry13_hit;            
logic    [2 :0]  entry13_pgs;            
logic    [27:0]  entry13_ppn;            
logic            entry13_swp;            
logic            entry13_swp_on;         
logic            entry13_upd;            
logic            entry13_vld;            
logic    [13:0]  entry14_flg;            
logic            entry14_hit;            
logic    [2 :0]  entry14_pgs;            
logic    [27:0]  entry14_ppn;            
logic            entry14_swp;            
logic            entry14_swp_on;         
logic            entry14_upd;            
logic            entry14_vld;            
logic    [13:0]  entry15_flg;            
logic            entry15_hit;            
logic    [2 :0]  entry15_pgs;            
logic    [27:0]  entry15_ppn;            
logic            entry15_swp;            
logic            entry15_swp_on;         
logic            entry15_upd;            
logic            entry15_vld;            
logic    [13:0]  entry16_flg;            
logic            entry16_hit;            
logic    [2 :0]  entry16_pgs;            
logic    [27:0]  entry16_ppn;            
logic            entry16_swp;            
logic            entry16_swp_on;         
logic            entry16_upd;            
logic            entry16_vld;            
logic    [26:0]  entry16_vpn;            
logic    [13:0]  entry17_flg;            
logic            entry17_hit;            
logic    [2 :0]  entry17_pgs;            
logic    [27:0]  entry17_ppn;            
logic            entry17_swp;            
logic            entry17_swp_on;         
logic            entry17_upd;            
logic            entry17_vld;            
logic    [13:0]  entry18_flg;            
logic            entry18_hit;            
logic    [2 :0]  entry18_pgs;            
logic    [27:0]  entry18_ppn;            
logic            entry18_swp;            
logic            entry18_swp_on;         
logic            entry18_upd;            
logic            entry18_vld;            
logic    [13:0]  entry19_flg;            
logic            entry19_hit;            
logic    [2 :0]  entry19_pgs;            
logic    [27:0]  entry19_ppn;            
logic            entry19_swp;            
logic            entry19_swp_on;         
logic            entry19_upd;            
logic            entry19_vld;            
logic    [13:0]  entry1_flg;             
logic            entry1_hit;             
logic    [2 :0]  entry1_pgs;             
logic    [27:0]  entry1_ppn;             
logic            entry1_swp;             
logic            entry1_swp_on;          
logic            entry1_upd;             
logic            entry1_vld;             
logic    [13:0]  entry20_flg;            
logic            entry20_hit;            
logic    [2 :0]  entry20_pgs;            
logic    [27:0]  entry20_ppn;            
logic            entry20_swp;            
logic            entry20_swp_on;         
logic            entry20_upd;            
logic            entry20_vld;            
logic    [13:0]  entry21_flg;            
logic            entry21_hit;            
logic    [2 :0]  entry21_pgs;            
logic    [27:0]  entry21_ppn;            
logic            entry21_swp;            
logic            entry21_swp_on;         
logic            entry21_upd;            
logic            entry21_vld;            
logic    [13:0]  entry22_flg;            
logic            entry22_hit;            
logic    [2 :0]  entry22_pgs;            
logic    [27:0]  entry22_ppn;            
logic            entry22_swp;            
logic            entry22_swp_on;         
logic            entry22_upd;            
logic            entry22_vld;            
logic    [13:0]  entry23_flg;            
logic            entry23_hit;            
logic    [2 :0]  entry23_pgs;            
logic    [27:0]  entry23_ppn;            
logic            entry23_swp;            
logic            entry23_swp_on;         
logic            entry23_upd;            
logic            entry23_vld;            
logic    [13:0]  entry24_flg;            
logic            entry24_hit;            
logic    [2 :0]  entry24_pgs;            
logic    [27:0]  entry24_ppn;            
logic            entry24_swp;            
logic            entry24_swp_on;         
logic            entry24_upd;            
logic            entry24_vld;            
logic    [26:0]  entry24_vpn;            
logic    [13:0]  entry25_flg;            
logic            entry25_hit;            
logic    [2 :0]  entry25_pgs;            
logic    [27:0]  entry25_ppn;            
logic            entry25_swp;            
logic            entry25_swp_on;         
logic            entry25_upd;            
logic            entry25_vld;            
logic    [13:0]  entry26_flg;            
logic            entry26_hit;            
logic    [2 :0]  entry26_pgs;            
logic    [27:0]  entry26_ppn;            
logic            entry26_swp;            
logic            entry26_swp_on;         
logic            entry26_upd;            
logic            entry26_vld;            
logic    [13:0]  entry27_flg;            
logic            entry27_hit;            
logic    [2 :0]  entry27_pgs;            
logic    [27:0]  entry27_ppn;            
logic            entry27_swp;            
logic            entry27_swp_on;         
logic            entry27_upd;            
logic            entry27_vld;            
logic    [13:0]  entry28_flg;            
logic            entry28_hit;            
logic    [2 :0]  entry28_pgs;            
logic    [27:0]  entry28_ppn;            
logic            entry28_swp;            
logic            entry28_swp_on;         
logic            entry28_upd;            
logic            entry28_vld;            
logic    [13:0]  entry29_flg;            
logic            entry29_hit;            
logic    [2 :0]  entry29_pgs;            
logic    [27:0]  entry29_ppn;            
logic            entry29_swp;            
logic            entry29_swp_on;         
logic            entry29_upd;            
logic            entry29_vld;            
logic    [13:0]  entry2_flg;             
logic            entry2_hit;             
logic    [2 :0]  entry2_pgs;             
logic    [27:0]  entry2_ppn;             
logic            entry2_swp;             
logic            entry2_swp_on;          
logic            entry2_upd;             
logic            entry2_vld;             
logic    [13:0]  entry30_flg;            
logic            entry30_hit;            
logic    [2 :0]  entry30_pgs;            
logic    [27:0]  entry30_ppn;            
logic            entry30_swp;            
logic            entry30_swp_on;         
logic            entry30_upd;            
logic            entry30_vld;            
logic    [13:0]  entry31_flg;            
logic            entry31_hit;            
logic    [2 :0]  entry31_pgs;            
logic    [27:0]  entry31_ppn;            
logic            entry31_swp;            
logic            entry31_swp_on;         
logic            entry31_upd;            
logic            entry31_vld;            
logic    [13:0]  entry3_flg;             
logic            entry3_hit;             
logic    [2 :0]  entry3_pgs;             
logic    [27:0]  entry3_ppn;             
logic            entry3_swp;             
logic            entry3_swp_on;          
logic            entry3_upd;             
logic            entry3_vld;             
logic    [13:0]  entry4_flg;             
logic            entry4_hit;             
logic    [2 :0]  entry4_pgs;             
logic    [27:0]  entry4_ppn;             
logic            entry4_swp;             
logic            entry4_swp_on;          
logic            entry4_upd;             
logic            entry4_vld;             
logic    [13:0]  entry5_flg;             
logic            entry5_hit;             
logic    [2 :0]  entry5_pgs;             
logic    [27:0]  entry5_ppn;             
logic            entry5_swp;             
logic            entry5_swp_on;          
logic            entry5_upd;             
logic            entry5_vld;             
logic    [13:0]  entry6_flg;             
logic            entry6_hit;             
logic    [2 :0]  entry6_pgs;             
logic    [27:0]  entry6_ppn;             
logic            entry6_swp;             
logic            entry6_swp_on;          
logic            entry6_upd;             
logic            entry6_vld;             
logic    [13:0]  entry7_flg;             
logic            entry7_hit;             
logic    [2 :0]  entry7_pgs;             
logic    [27:0]  entry7_ppn;             
logic            entry7_swp;             
logic            entry7_swp_on;          
logic            entry7_upd;             
logic            entry7_vld;             
logic    [13:0]  entry8_flg;             
logic            entry8_hit;             
logic    [2 :0]  entry8_pgs;             
logic    [27:0]  entry8_ppn;             
logic            entry8_swp;             
logic            entry8_swp_on;          
logic            entry8_upd;             
logic            entry8_vld;             
logic    [26:0]  entry8_vpn;             
logic    [13:0]  entry9_flg;             
logic            entry9_hit;             
logic    [2 :0]  entry9_pgs;             
logic    [27:0]  entry9_ppn;             
logic            entry9_swp;             
logic            entry9_swp_on;          
logic            entry9_upd;             
logic            entry9_vld;             
logic    [31:0]  entry_hit;              
logic    [31:0]  entry_vld;              
logic    [13:0]  flg_fin;                
logic            iplru_clk;              
logic            iplru_clk_en;           
logic            iplru_upd_en;           
logic            iutlb_acc_flt;          
logic            iutlb_addr_hit;         
logic            iutlb_addr_hit_vld;     
logic            iutlb_bypass_vld;       
logic            iutlb_clk;              
logic            iutlb_clk_en;           
logic            iutlb_disable_vld;      
logic    [31:0]  iutlb_entry_hit;        
logic    [13:0]  iutlb_flg_aft_bypass;   
logic    [13:0]  iutlb_hit_flg_fst;      
logic    [13:0]  iutlb_hit_flg_scd;      
logic    [27:0]  iutlb_hit_pa_fst;       
logic    [27:0]  iutlb_hit_pa_scd;       
logic    [2 :0]  iutlb_hit_pgs_fst;      
logic    [2 :0]  iutlb_hit_pgs_scd;      
logic            iutlb_hit_vld;          
logic            iutlb_miss_cnt;         
logic            iutlb_miss_vld;         
logic    [13:0]  iutlb_off_flg;          
logic            iutlb_off_hit;          
logic    [27:0]  iutlb_off_pa;           
logic    [2 :0]  iutlb_off_pgs;          
logic    [27:0]  iutlb_pa_aft_bypass;    
logic            iutlb_pa_vld;           
logic            iutlb_page_fault;       
logic            iutlb_plru_read_hit_vld; 
logic            iutlb_plru_refill_on;   
logic            iutlb_plru_refill_vld;  
logic            iutlb_pmp_chk_vld;      
logic            iutlb_ref_pgflt;        
logic            iutlb_refill_on;        
logic            iutlb_refill_vld;       
logic            iutlb_swp_en;           
logic            iutlb_va_illegal;       
logic            iutlb_wfc;              
logic            jtlb_acc_fault;         
logic    [27:0]  pa_fin;                 
logic    [26:0]  pa_offset;              
logic            pabuf_clk;              
logic            pabuf_clk_en;           
logic    [2 :0]  pgs_fin;                
logic    [31:0]  plru_iutlb_ref_num;     
logic    [13:0]  utlb_fst_swp_flg;       
logic    [2 :0]  utlb_fst_swp_pgs;       
logic    [27:0]  utlb_fst_swp_ppn;       
logic    [26:0]  utlb_fst_swp_vpn;       
logic    [26:0]  utlb_req_vpn;           
logic    [13:0]  utlb_swp_flg;           
logic            utlb_swp_on;            
logic    [2 :0]  utlb_swp_pgs;           
logic    [27:0]  utlb_swp_ppn;           
logic    [26:0]  utlb_swp_vpn;           
logic    [13:0]  utlb_upd_flg;           
logic    [2 :0]  utlb_upd_pgs;           
logic    [27:0]  utlb_upd_ppn;           
logic    [26:0]  utlb_upd_vpn;           

logic credit_cnt;

logic l1itlb_ref_cmplt;

//==========================================================
// parameters for value width
//==========================================================
parameter VPN_WIDTH = 39-12;  // VPN
parameter PPN_WIDTH = 40-12;  // PPN
parameter FLG_WIDTH = 14;     // Flags
parameter PGS_WIDTH = 3;      // Page Size
parameter VPN_PERLEL = 9;

//==========================================================
//                  Gate Cell
//==========================================================
assign iutlb_clk_en = ifu_mmu_va_vld && !iutlb_addr_hit && !iutlb_off_hit
                   || iutlb_refill_on
                   || jtlb_acc_fault
                   || jtlb_acc_fault_flop
                   || iutlb_miss;
// &Instance("gated_clk_cell", "x_iutlb_gateclk"); @49
gated_clk_cell  x_iutlb_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (iutlb_clk         ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (iutlb_clk_en      ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

// &Connect( .clk_in     (forever_cpuclk), @50
//           .external_en(1'b0          ), @51
//           .global_en  (1'b1          ), @52
//           .module_en  (cp0_mmu_icg_en), @53
//           .local_en   (iutlb_clk_en  ), @54
//           .clk_out    (iutlb_clk     ) @55
//          ); @56

//==============================================================================
//                  Control Path
//==============================================================================

// current privlidged mode
assign cp0_user_mode = cp0_yy_priv_mode[1:0] == 2'b00;
assign cp0_supv_mode = cp0_yy_priv_mode[1:0] == 2'b01;
assign cp0_mach_mode = cp0_yy_priv_mode[1:0] == 2'b11;

//==========================================================
//                  Tranlation Related Signal
//==========================================================
//----------------------------------------------------------
//                  Addr Translation Cmplt
//----------------------------------------------------------
// 1. when utlb hit, return pvald to IFU
// 2. when change flow, later ultlb hit can bypass the pre-
//    vious utlb miss, but later utlb miss must be blocking
assign iutlb_hit_vld  =  ifu_mmu_va_vld
                      && iutlb_addr_hit;

// I-uTLB trans cmplt without addr match in utlb:
// 1. when mmu is not enabled or CPU at M-Mode
// 2. when utlb refill cmplt, and no abort happend
//assign iutlb_bypass_vld  = iutlb_refill_cmplt;
assign iutlb_bypass_vld  = 1'b0;
assign iutlb_off_hit     = !regs_mmu_en || cp0_mach_mode;
assign iutlb_disable_vld = ifu_mmu_va_vld && iutlb_off_hit;

//----------------------------------------------------------
//                  Interface to IFU
//----------------------------------------------------------
// Paddr is valid when:
// 1. utlb hit 
// 2. utlb refill cmplt, no matter exception or not
// 3. mmu is disabled
// &Force("output", "mmu_ifu_pavld"); @94
assign mmu_ifu_pavld = iutlb_bypass_vld
                    || (iutlb_hit_vld
                         || iutlb_disable_vld
                         || iutlb_acc_flt
                         || iutlb_ref_pgflt
                         || iutlb_va_illegal
                       ) ; //&& !iutlb_refill_on; // support hit under miss

assign mmu_ifu_pa[PPN_WIDTH-1:0] = iutlb_pa_aft_bypass[PPN_WIDTH-1:0]; 


// flags judgement
// pmas to ifu: bufferable, security, cacheable
assign mmu_ifu_buf      = iutlb_flg_aft_bypass[11]
                      || !iutlb_flg_aft_bypass[13]; //when !so, always buf

assign mmu_ifu_sec      = iutlb_flg_aft_bypass[9];
assign mmu_ifu_ca       = iutlb_flg_aft_bypass[12];

// R W X judgement, R and W are not used in I-uTLB
// page fault when not valid
// page fault when writeable but not readable
// page fault when not executable
// page fault when supv access user region and vise versa
// page fault when A/D bit violation
// page fault when ifu meets strong order
// page fault when tfatal and tmiss from jTLB
// page fault when ifu high va not legal
assign iutlb_va_illegal = (ifu_mmu_va[VPN_WIDTH+10] && !(&ifu_mmu_va[62:VPN_WIDTH+11])
                      ||  !ifu_mmu_va[VPN_WIDTH+10] &&  (|ifu_mmu_va[62:VPN_WIDTH+11]))
                          && !iutlb_off_hit && ifu_mmu_va_vld;
assign iutlb_page_fault = (!iutlb_flg_aft_bypass[0]
                        || !iutlb_flg_aft_bypass[1] && iutlb_flg_aft_bypass[2]
                        || !iutlb_flg_aft_bypass[3]
                        ||  iutlb_flg_aft_bypass[4] && cp0_supv_mode && !cp0_mmu_sum 
                        || !iutlb_flg_aft_bypass[4] && cp0_user_mode && regs_mmu_en
                        || !iutlb_flg_aft_bypass[5]
                        ||  iutlb_flg_aft_bypass[13]
                        ||  iutlb_ref_pgflt
                        ||  iutlb_va_illegal) 
                        && !jtlb_acc_fault;

assign mmu_ifu_pgflt    = iutlb_page_fault;

// access deny when pmp check fail
// &Force("bus", "pmp_mmu_flg2", 3, 0); @140
assign mmu_ifu_deny = jtlb_acc_fault_flop
                   // L-bit for M-Mode
                   || !pmp_mmu_flg2[2] && !(cp0_mach_mode && !pmp_mmu_flg2[3])
                       && pmp_flg_vld; 

//==========================================================
//                  uTLB Replacement Logic
//==========================================================
//----------------------------------------------------------
//                  uTLB Replacement Algorithm
//----------------------------------------------------------
// 1. when there is empty entry avaleble, use empty entry
// 2. when there is no empry entry, use PLRU
// &ConnRule(s/^utlb/iutlb/); @154
// &Instance("ct_mmu_iplru","x_ct_mmu_iplru"); @155
ct_mmu_iplru  x_ct_mmu_iplru (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .entry0_vld              (entry0_vld             ),
  .entry10_vld             (entry10_vld            ),
  .entry11_vld             (entry11_vld            ),
  .entry12_vld             (entry12_vld            ),
  .entry13_vld             (entry13_vld            ),
  .entry14_vld             (entry14_vld            ),
  .entry15_vld             (entry15_vld            ),
  .entry16_vld             (entry16_vld            ),
  .entry17_vld             (entry17_vld            ),
  .entry18_vld             (entry18_vld            ),
  .entry19_vld             (entry19_vld            ),
  .entry1_vld              (entry1_vld             ),
  .entry20_vld             (entry20_vld            ),
  .entry21_vld             (entry21_vld            ),
  .entry22_vld             (entry22_vld            ),
  .entry23_vld             (entry23_vld            ),
  .entry24_vld             (entry24_vld            ),
  .entry25_vld             (entry25_vld            ),
  .entry26_vld             (entry26_vld            ),
  .entry27_vld             (entry27_vld            ),
  .entry28_vld             (entry28_vld            ),
  .entry29_vld             (entry29_vld            ),
  .entry2_vld              (entry2_vld             ),
  .entry30_vld             (entry30_vld            ),
  .entry31_vld             (entry31_vld            ),
  .entry3_vld              (entry3_vld             ),
  .entry4_vld              (entry4_vld             ),
  .entry5_vld              (entry5_vld             ),
  .entry6_vld              (entry6_vld             ),
  .entry7_vld              (entry7_vld             ),
  .entry8_vld              (entry8_vld             ),
  .entry9_vld              (entry9_vld             ),
  .forever_cpuclk          (forever_cpuclk         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .plru_iutlb_ref_num      (plru_iutlb_ref_num     ),
  .utlb_plru_read_hit      (iutlb_plru_read_hit    ),
  .utlb_plru_read_hit_vld  (iutlb_plru_read_hit_vld),
  .utlb_plru_refill_on     (iutlb_plru_refill_on   ),
  .utlb_plru_refill_vld    (iutlb_plru_refill_vld  )
);


assign iutlb_plru_refill_on  = iutlb_wfc;
assign iutlb_plru_refill_vld = iutlb_refill_vld;

assign iplru_upd_en = ifu_mmu_va_vld && (iutlb_plru_read_hit[31:0] != iutlb_entry_hit[31:0]);
assign iplru_clk_en = iplru_upd_en;
// &Instance("gated_clk_cell", "x_iutlb_plru_gateclk"); @162
gated_clk_cell  x_iutlb_plru_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (iplru_clk         ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (iplru_clk_en      ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

// &Connect( .clk_in     (forever_cpuclk), @163
//           .external_en(1'b0          ), @164
//           .global_en  (1'b1          ), @165
//           .module_en  (cp0_mmu_icg_en), @166
//           .local_en   (iplru_clk_en  ), @167
//           .clk_out    (iplru_clk     ) @168
//          ); @169

always @(posedge iplru_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    iutlb_plru_read_hit[31:0] <= 32'b0;
  else if(iplru_upd_en)
    iutlb_plru_read_hit[31:0] <= iutlb_entry_hit[31:0];
end

assign iutlb_plru_read_hit_vld = |iutlb_plru_read_hit[31:0];

//==========================================================
//                  uTLB Refill SM
//==========================================================
//----------------------------------------------------------
//                  L0 uTLB(0-3) SM State
//----------------------------------------------------------
// 1. FST_CMP: compare with iutlb 0-3 (for timing)
// 2. SCD_CMP: compare with iutlb 4-15
//             exchange 4-15 with 0-3 using fifo
//parameter FST_CMP = 1'b0,
//          SCD_CMP = 1'b1;
//
//assign iutlb_miss_vld_fst = ifu_mmu_va_vld && !iutlb_addr_hit_fst
//                                           //&& !iutlb_page_fault
//                                           && regs_mmu_en
//                                           && !cp0_mmu_no_op_req;
//
//always @(posedge iutlb_clk or negedge cpurst_b)
//begin
//  if (!cpurst_b)
//    cmp_cur_st <= FST_CMP;
//  else
//    cmp_cur_st <= cmp_nxt_st;
//end
//
//&CombBeg;
//case (cmp_cur_st)
//FST_CMP:
//begin
//  if(iutlb_miss_vld_fst && iutlb_entry_hit_vld_scd && !ifu_mmu_abort)
//    cmp_nxt_st = SCD_CMP;
//  else
//    cmp_nxt_st = FST_CMP;
//end
//SCD_CMP:
//begin
//  cmp_nxt_st = FST_CMP;
//end
//default:
//begin
//  cmp_nxt_st = FST_CMP;
//end
//endcase
//&CombEnd;
//
//assign iutlb_fst = (cmp_cur_st == FST_CMP);
//assign iutlb_scd = (cmp_cur_st == SCD_CMP);

assign iutlb_top_scd_updt = iutlb_swp_en;

assign l1itlb_ref_cmplt = ptw_l1itlb_ref_cmplt | jtlb_iutlb_ref_cmplt;

//----------------------------------------------------------
//                  SM State
//----------------------------------------------------------
// 1. IDLE: default state; wait grant when utlb miss
// 2. WFC : wait utlb refill cmplt to refill utlb
// 3. ABT : wait utlb refill cmplt when abort happened
parameter IDLE  = 3'b000,
          WFG   = 3'b001,
          WFC   = 3'b010,
          PGFLT = 3'b100,
          ACFLT = 3'b110,
          ABT   = 3'b011;

//  When utlb miss and mmu is enabled, utlb refill SM will
//  be started
assign iutlb_miss_vld = ifu_mmu_va_vld && !iutlb_addr_hit_vld
                                       //&& !iutlb_page_fault
                                       && !iutlb_off_hit
                                       && !cp0_mmu_no_op_req;

always @(posedge iutlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    ref_cur_st[2:0] <= 3'b0;
  else
    ref_cur_st[2:0] <= ref_nxt_st[2:0];
end

// &CombBeg; @259
always_comb begin
    case (ref_cur_st)
        IDLE: begin
          if(ifu_mmu_abort)
            ref_nxt_st[2:0] = IDLE;
          else if(iutlb_miss_vld)
            ref_nxt_st[2:0] = WFG;
          else
            ref_nxt_st[2:0] = IDLE;
        end
        WFG: begin
          if(ifu_mmu_abort && credit_cnt != 1'b0)
            ref_nxt_st[2:0] = ABT;
          else if(ifu_mmu_abort)
            ref_nxt_st[2:0] = IDLE;
          else if(credit_cnt != 1'b0)
            ref_nxt_st[2:0] = WFC;
          else
            ref_nxt_st[2:0] = WFG;
        end
        WFC: begin
          if(ifu_mmu_abort && l1itlb_ref_cmplt)
            ref_nxt_st[2:0] = IDLE;
          else if(ifu_mmu_abort)
            ref_nxt_st[2:0] = ABT;
          else if(l1itlb_ref_cmplt && ptw_l1tlb_pgflt)
            ref_nxt_st[2:0] = PGFLT;
          else if(l1itlb_ref_cmplt)
            ref_nxt_st[2:0] = IDLE;
          else
            ref_nxt_st[2:0] = WFC;
        end
        PGFLT: begin
          ref_nxt_st[2:0] = IDLE;
        end
        ABT: begin
          if(l1itlb_ref_cmplt)
            ref_nxt_st[2:0] = IDLE;
          else
            ref_nxt_st[2:0] = ABT;
        end
        default: begin
           ref_nxt_st[2:0] = IDLE;
        end
    endcase
// &CombEnd; @310
end


//----------------------------------------------------------
//                  SM Control Signal
//----------------------------------------------------------

always @(posedge iutlb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
	credit_cnt <= 1'b1;
    end else if(credit_return) begin
	credit_cnt <= 1'b1;
    end else if(iutlb_l2tlb_req) begin
	credit_cnt <= 1'b0;
    end else credit_cnt <= credit_cnt;
end



// Req jtlb when utlb miss
// 1. req only in IDLE, so utlb refill is blocking
// &Force("bus", "ifu_mmu_va", 62, 0); @318
assign iutlb_l2tlb_req       = (ref_cur_st[2:0] == WFG);
assign iutlb_l2tlb_vpn[VPN_WIDTH-1:0] = ifu_mmu_va[VPN_WIDTH+10:11];

assign iutlb_refill_on     = (ref_cur_st[2:0] != IDLE);

// uTLB refill cmplt
// 1. jtlb hit
// 2. ptw cmplt, either data vld or acc err
// 3. refill utlb only when ptw cmplt with data vld
assign iutlb_wfc = (ref_cur_st[2:0] == WFC);
//assign iutlb_refill_cmplt = iutlb_wfc && ptw_l1itlb_ref_cmplt;
assign iutlb_refill_vld   = iutlb_wfc && (jtlb_iutlb_ref_pavld | ptw_l1itlb_ref_pavld);

assign iutlb_ref_pgflt    = (ref_cur_st[2:0] == PGFLT);

//assign iutlb_arb_cmplt    = (ref_cur_st[2:0] != IDLE) && (ref_nxt_st[2:0] == IDLE);
//assign iutlb_arb_cmplt    = (ref_cur_st[2:0] == WFC) && l1itlb_ref_cmplt
//                         || (ref_cur_st[2:0] == ABT) && l1itlb_ref_cmplt;

// for hpcp
assign iutlb_miss_cnt = iutlb_refill_vld && hpcp_mmu_cnt_en;

always @(posedge iutlb_clk or negedge cpurst_b) begin
  if (!cpurst_b)
    iutlb_miss <= 1'b0;
  else if(iutlb_miss_cnt)
    iutlb_miss <= 1'b1;
  else if(iutlb_miss)
    iutlb_miss <= 1'b0;
end

assign mmu_hpcp_iutlb_miss = iutlb_miss;

//==============================================================================
//                  Data Path
//==============================================================================
//==========================================================
//                  uTLB Entry
//==========================================================
assign utlb_req_vpn[VPN_WIDTH-1:0] = ifu_mmu_va[VPN_WIDTH+10:11];

// &ConnRule(s/utlb_entry/entry0/); @365
// &Instance("ct_mmu_iutlb_fst_entry","x_ct_mmu_iutlb_entry0"); @366
ct_mmu_iutlb_fst_entry  x_ct_mmu_iutlb_entry0 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry0_flg             ),
  .utlb_entry_hit          (entry0_hit             ),
  .utlb_entry_pgs          (entry0_pgs             ),
  .utlb_entry_ppn          (entry0_ppn             ),
  .utlb_entry_swp          (entry0_swp             ),
  .utlb_entry_swp_on       (entry0_swp_on          ),
  .utlb_entry_upd          (entry0_upd             ),
  .utlb_entry_vld          (entry0_vld             ),
  .utlb_entry_vpn          (entry0_vpn             ),
  .utlb_fst_swp_flg        (utlb_fst_swp_flg       ),
  .utlb_fst_swp_pgs        (utlb_fst_swp_pgs       ),
  .utlb_fst_swp_ppn        (utlb_fst_swp_ppn       ),
  .utlb_fst_swp_vpn        (utlb_fst_swp_vpn       ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry1/); @368
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry1"); @369
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry1 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry1_flg             ),
  .utlb_entry_hit          (entry1_hit             ),
  .utlb_entry_pgs          (entry1_pgs             ),
  .utlb_entry_ppn          (entry1_ppn             ),
  .utlb_entry_swp          (entry1_swp             ),
  .utlb_entry_swp_on       (entry1_swp_on          ),
  .utlb_entry_upd          (entry1_upd             ),
  .utlb_entry_vld          (entry1_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry2/); @371
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry2"); @372
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry2 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry2_flg             ),
  .utlb_entry_hit          (entry2_hit             ),
  .utlb_entry_pgs          (entry2_pgs             ),
  .utlb_entry_ppn          (entry2_ppn             ),
  .utlb_entry_swp          (entry2_swp             ),
  .utlb_entry_swp_on       (entry2_swp_on          ),
  .utlb_entry_upd          (entry2_upd             ),
  .utlb_entry_vld          (entry2_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry3/); @374
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry3"); @375
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry3 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry3_flg             ),
  .utlb_entry_hit          (entry3_hit             ),
  .utlb_entry_pgs          (entry3_pgs             ),
  .utlb_entry_ppn          (entry3_ppn             ),
  .utlb_entry_swp          (entry3_swp             ),
  .utlb_entry_swp_on       (entry3_swp_on          ),
  .utlb_entry_upd          (entry3_upd             ),
  .utlb_entry_vld          (entry3_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry4/); @377
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry4"); @378
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry4 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry4_flg             ),
  .utlb_entry_hit          (entry4_hit             ),
  .utlb_entry_pgs          (entry4_pgs             ),
  .utlb_entry_ppn          (entry4_ppn             ),
  .utlb_entry_swp          (entry4_swp             ),
  .utlb_entry_swp_on       (entry4_swp_on          ),
  .utlb_entry_upd          (entry4_upd             ),
  .utlb_entry_vld          (entry4_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry5/); @380
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry5"); @381
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry5 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry5_flg             ),
  .utlb_entry_hit          (entry5_hit             ),
  .utlb_entry_pgs          (entry5_pgs             ),
  .utlb_entry_ppn          (entry5_ppn             ),
  .utlb_entry_swp          (entry5_swp             ),
  .utlb_entry_swp_on       (entry5_swp_on          ),
  .utlb_entry_upd          (entry5_upd             ),
  .utlb_entry_vld          (entry5_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry6/); @383
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry6"); @384
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry6 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry6_flg             ),
  .utlb_entry_hit          (entry6_hit             ),
  .utlb_entry_pgs          (entry6_pgs             ),
  .utlb_entry_ppn          (entry6_ppn             ),
  .utlb_entry_swp          (entry6_swp             ),
  .utlb_entry_swp_on       (entry6_swp_on          ),
  .utlb_entry_upd          (entry6_upd             ),
  .utlb_entry_vld          (entry6_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry7/); @386
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry7"); @387
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry7 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry7_flg             ),
  .utlb_entry_hit          (entry7_hit             ),
  .utlb_entry_pgs          (entry7_pgs             ),
  .utlb_entry_ppn          (entry7_ppn             ),
  .utlb_entry_swp          (entry7_swp             ),
  .utlb_entry_swp_on       (entry7_swp_on          ),
  .utlb_entry_upd          (entry7_upd             ),
  .utlb_entry_vld          (entry7_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry8/); @389
// &Instance("ct_mmu_iutlb_fst_entry","x_ct_mmu_iutlb_entry8"); @390
ct_mmu_iutlb_fst_entry  x_ct_mmu_iutlb_entry8 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry8_flg             ),
  .utlb_entry_hit          (entry8_hit             ),
  .utlb_entry_pgs          (entry8_pgs             ),
  .utlb_entry_ppn          (entry8_ppn             ),
  .utlb_entry_swp          (entry8_swp             ),
  .utlb_entry_swp_on       (entry8_swp_on          ),
  .utlb_entry_upd          (entry8_upd             ),
  .utlb_entry_vld          (entry8_vld             ),
  .utlb_entry_vpn          (entry8_vpn             ),
  .utlb_fst_swp_flg        (utlb_fst_swp_flg       ),
  .utlb_fst_swp_pgs        (utlb_fst_swp_pgs       ),
  .utlb_fst_swp_ppn        (utlb_fst_swp_ppn       ),
  .utlb_fst_swp_vpn        (utlb_fst_swp_vpn       ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry9/); @392
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry9"); @393
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry9 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry9_flg             ),
  .utlb_entry_hit          (entry9_hit             ),
  .utlb_entry_pgs          (entry9_pgs             ),
  .utlb_entry_ppn          (entry9_ppn             ),
  .utlb_entry_swp          (entry9_swp             ),
  .utlb_entry_swp_on       (entry9_swp_on          ),
  .utlb_entry_upd          (entry9_upd             ),
  .utlb_entry_vld          (entry9_vld             ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry10/); @395
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry10"); @396
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry10 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry10_flg            ),
  .utlb_entry_hit          (entry10_hit            ),
  .utlb_entry_pgs          (entry10_pgs            ),
  .utlb_entry_ppn          (entry10_ppn            ),
  .utlb_entry_swp          (entry10_swp            ),
  .utlb_entry_swp_on       (entry10_swp_on         ),
  .utlb_entry_upd          (entry10_upd            ),
  .utlb_entry_vld          (entry10_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry11/); @398
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry11"); @399
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry11 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry11_flg            ),
  .utlb_entry_hit          (entry11_hit            ),
  .utlb_entry_pgs          (entry11_pgs            ),
  .utlb_entry_ppn          (entry11_ppn            ),
  .utlb_entry_swp          (entry11_swp            ),
  .utlb_entry_swp_on       (entry11_swp_on         ),
  .utlb_entry_upd          (entry11_upd            ),
  .utlb_entry_vld          (entry11_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry12/); @401
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry12"); @402
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry12 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry12_flg            ),
  .utlb_entry_hit          (entry12_hit            ),
  .utlb_entry_pgs          (entry12_pgs            ),
  .utlb_entry_ppn          (entry12_ppn            ),
  .utlb_entry_swp          (entry12_swp            ),
  .utlb_entry_swp_on       (entry12_swp_on         ),
  .utlb_entry_upd          (entry12_upd            ),
  .utlb_entry_vld          (entry12_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry13/); @404
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry13"); @405
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry13 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry13_flg            ),
  .utlb_entry_hit          (entry13_hit            ),
  .utlb_entry_pgs          (entry13_pgs            ),
  .utlb_entry_ppn          (entry13_ppn            ),
  .utlb_entry_swp          (entry13_swp            ),
  .utlb_entry_swp_on       (entry13_swp_on         ),
  .utlb_entry_upd          (entry13_upd            ),
  .utlb_entry_vld          (entry13_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry14/); @407
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry14"); @408
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry14 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry14_flg            ),
  .utlb_entry_hit          (entry14_hit            ),
  .utlb_entry_pgs          (entry14_pgs            ),
  .utlb_entry_ppn          (entry14_ppn            ),
  .utlb_entry_swp          (entry14_swp            ),
  .utlb_entry_swp_on       (entry14_swp_on         ),
  .utlb_entry_upd          (entry14_upd            ),
  .utlb_entry_vld          (entry14_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry15/); @410
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry15"); @411
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry15 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry15_flg            ),
  .utlb_entry_hit          (entry15_hit            ),
  .utlb_entry_pgs          (entry15_pgs            ),
  .utlb_entry_ppn          (entry15_ppn            ),
  .utlb_entry_swp          (entry15_swp            ),
  .utlb_entry_swp_on       (entry15_swp_on         ),
  .utlb_entry_upd          (entry15_upd            ),
  .utlb_entry_vld          (entry15_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry16/); @413
// &Instance("ct_mmu_iutlb_fst_entry","x_ct_mmu_iutlb_entry16"); @414
ct_mmu_iutlb_fst_entry  x_ct_mmu_iutlb_entry16 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry16_flg            ),
  .utlb_entry_hit          (entry16_hit            ),
  .utlb_entry_pgs          (entry16_pgs            ),
  .utlb_entry_ppn          (entry16_ppn            ),
  .utlb_entry_swp          (entry16_swp            ),
  .utlb_entry_swp_on       (entry16_swp_on         ),
  .utlb_entry_upd          (entry16_upd            ),
  .utlb_entry_vld          (entry16_vld            ),
  .utlb_entry_vpn          (entry16_vpn            ),
  .utlb_fst_swp_flg        (utlb_fst_swp_flg       ),
  .utlb_fst_swp_pgs        (utlb_fst_swp_pgs       ),
  .utlb_fst_swp_ppn        (utlb_fst_swp_ppn       ),
  .utlb_fst_swp_vpn        (utlb_fst_swp_vpn       ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry17/); @416
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry17"); @417
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry17 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry17_flg            ),
  .utlb_entry_hit          (entry17_hit            ),
  .utlb_entry_pgs          (entry17_pgs            ),
  .utlb_entry_ppn          (entry17_ppn            ),
  .utlb_entry_swp          (entry17_swp            ),
  .utlb_entry_swp_on       (entry17_swp_on         ),
  .utlb_entry_upd          (entry17_upd            ),
  .utlb_entry_vld          (entry17_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry18/); @419
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry18"); @420
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry18 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry18_flg            ),
  .utlb_entry_hit          (entry18_hit            ),
  .utlb_entry_pgs          (entry18_pgs            ),
  .utlb_entry_ppn          (entry18_ppn            ),
  .utlb_entry_swp          (entry18_swp            ),
  .utlb_entry_swp_on       (entry18_swp_on         ),
  .utlb_entry_upd          (entry18_upd            ),
  .utlb_entry_vld          (entry18_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry19/); @422
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry19"); @423
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry19 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry19_flg            ),
  .utlb_entry_hit          (entry19_hit            ),
  .utlb_entry_pgs          (entry19_pgs            ),
  .utlb_entry_ppn          (entry19_ppn            ),
  .utlb_entry_swp          (entry19_swp            ),
  .utlb_entry_swp_on       (entry19_swp_on         ),
  .utlb_entry_upd          (entry19_upd            ),
  .utlb_entry_vld          (entry19_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry20/); @425
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry20"); @426
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry20 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry20_flg            ),
  .utlb_entry_hit          (entry20_hit            ),
  .utlb_entry_pgs          (entry20_pgs            ),
  .utlb_entry_ppn          (entry20_ppn            ),
  .utlb_entry_swp          (entry20_swp            ),
  .utlb_entry_swp_on       (entry20_swp_on         ),
  .utlb_entry_upd          (entry20_upd            ),
  .utlb_entry_vld          (entry20_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry21/); @428
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry21"); @429
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry21 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry21_flg            ),
  .utlb_entry_hit          (entry21_hit            ),
  .utlb_entry_pgs          (entry21_pgs            ),
  .utlb_entry_ppn          (entry21_ppn            ),
  .utlb_entry_swp          (entry21_swp            ),
  .utlb_entry_swp_on       (entry21_swp_on         ),
  .utlb_entry_upd          (entry21_upd            ),
  .utlb_entry_vld          (entry21_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry22/); @431
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry22"); @432
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry22 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry22_flg            ),
  .utlb_entry_hit          (entry22_hit            ),
  .utlb_entry_pgs          (entry22_pgs            ),
  .utlb_entry_ppn          (entry22_ppn            ),
  .utlb_entry_swp          (entry22_swp            ),
  .utlb_entry_swp_on       (entry22_swp_on         ),
  .utlb_entry_upd          (entry22_upd            ),
  .utlb_entry_vld          (entry22_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry23/); @434
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry23"); @435
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry23 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry23_flg            ),
  .utlb_entry_hit          (entry23_hit            ),
  .utlb_entry_pgs          (entry23_pgs            ),
  .utlb_entry_ppn          (entry23_ppn            ),
  .utlb_entry_swp          (entry23_swp            ),
  .utlb_entry_swp_on       (entry23_swp_on         ),
  .utlb_entry_upd          (entry23_upd            ),
  .utlb_entry_vld          (entry23_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry24/); @437
// &Instance("ct_mmu_iutlb_fst_entry","x_ct_mmu_iutlb_entry24"); @438
ct_mmu_iutlb_fst_entry  x_ct_mmu_iutlb_entry24 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry24_flg            ),
  .utlb_entry_hit          (entry24_hit            ),
  .utlb_entry_pgs          (entry24_pgs            ),
  .utlb_entry_ppn          (entry24_ppn            ),
  .utlb_entry_swp          (entry24_swp            ),
  .utlb_entry_swp_on       (entry24_swp_on         ),
  .utlb_entry_upd          (entry24_upd            ),
  .utlb_entry_vld          (entry24_vld            ),
  .utlb_entry_vpn          (entry24_vpn            ),
  .utlb_fst_swp_flg        (utlb_fst_swp_flg       ),
  .utlb_fst_swp_pgs        (utlb_fst_swp_pgs       ),
  .utlb_fst_swp_ppn        (utlb_fst_swp_ppn       ),
  .utlb_fst_swp_vpn        (utlb_fst_swp_vpn       ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry25/); @440
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry25"); @441
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry25 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry25_flg            ),
  .utlb_entry_hit          (entry25_hit            ),
  .utlb_entry_pgs          (entry25_pgs            ),
  .utlb_entry_ppn          (entry25_ppn            ),
  .utlb_entry_swp          (entry25_swp            ),
  .utlb_entry_swp_on       (entry25_swp_on         ),
  .utlb_entry_upd          (entry25_upd            ),
  .utlb_entry_vld          (entry25_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry26/); @443
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry26"); @444
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry26 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry26_flg            ),
  .utlb_entry_hit          (entry26_hit            ),
  .utlb_entry_pgs          (entry26_pgs            ),
  .utlb_entry_ppn          (entry26_ppn            ),
  .utlb_entry_swp          (entry26_swp            ),
  .utlb_entry_swp_on       (entry26_swp_on         ),
  .utlb_entry_upd          (entry26_upd            ),
  .utlb_entry_vld          (entry26_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry27/); @446
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry27"); @447
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry27 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry27_flg            ),
  .utlb_entry_hit          (entry27_hit            ),
  .utlb_entry_pgs          (entry27_pgs            ),
  .utlb_entry_ppn          (entry27_ppn            ),
  .utlb_entry_swp          (entry27_swp            ),
  .utlb_entry_swp_on       (entry27_swp_on         ),
  .utlb_entry_upd          (entry27_upd            ),
  .utlb_entry_vld          (entry27_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry28/); @449
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry28"); @450
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry28 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry28_flg            ),
  .utlb_entry_hit          (entry28_hit            ),
  .utlb_entry_pgs          (entry28_pgs            ),
  .utlb_entry_ppn          (entry28_ppn            ),
  .utlb_entry_swp          (entry28_swp            ),
  .utlb_entry_swp_on       (entry28_swp_on         ),
  .utlb_entry_upd          (entry28_upd            ),
  .utlb_entry_vld          (entry28_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry29/); @452
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry29"); @453
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry29 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry29_flg            ),
  .utlb_entry_hit          (entry29_hit            ),
  .utlb_entry_pgs          (entry29_pgs            ),
  .utlb_entry_ppn          (entry29_ppn            ),
  .utlb_entry_swp          (entry29_swp            ),
  .utlb_entry_swp_on       (entry29_swp_on         ),
  .utlb_entry_upd          (entry29_upd            ),
  .utlb_entry_vld          (entry29_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry30/); @455
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry30"); @456
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry30 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry30_flg            ),
  .utlb_entry_hit          (entry30_hit            ),
  .utlb_entry_pgs          (entry30_pgs            ),
  .utlb_entry_ppn          (entry30_ppn            ),
  .utlb_entry_swp          (entry30_swp            ),
  .utlb_entry_swp_on       (entry30_swp_on         ),
  .utlb_entry_upd          (entry30_upd            ),
  .utlb_entry_vld          (entry30_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


// &ConnRule(s/utlb_entry/entry31/); @458
// &Instance("ct_mmu_iutlb_entry","x_ct_mmu_iutlb_entry31"); @459
ct_mmu_iutlb_entry  x_ct_mmu_iutlb_entry31 (
  .cp0_mmu_icg_en          (cp0_mmu_icg_en         ),
  .cpurst_b                (cpurst_b               ),
  .lsu_mmu_tlb_va          (lsu_mmu_tlb_va         ),
  .pad_yy_icg_scan_en      (pad_yy_icg_scan_en     ),
  .regs_utlb_clr           (regs_utlb_clr          ),
  .tlboper_utlb_clr        (tlboper_utlb_clr       ),
  .tlboper_utlb_inv_va_req (tlboper_utlb_inv_va_req),
  .utlb_clk                (utlb_clk               ),
  .utlb_entry_flg          (entry31_flg            ),
  .utlb_entry_hit          (entry31_hit            ),
  .utlb_entry_pgs          (entry31_pgs            ),
  .utlb_entry_ppn          (entry31_ppn            ),
  .utlb_entry_swp          (entry31_swp            ),
  .utlb_entry_swp_on       (entry31_swp_on         ),
  .utlb_entry_upd          (entry31_upd            ),
  .utlb_entry_vld          (entry31_vld            ),
  .utlb_req_vpn            (utlb_req_vpn           ),
  .utlb_swp_flg            (utlb_swp_flg           ),
  .utlb_swp_pgs            (utlb_swp_pgs           ),
  .utlb_swp_ppn            (utlb_swp_ppn           ),
  .utlb_swp_vpn            (utlb_swp_vpn           ),
  .utlb_upd_flg            (utlb_upd_flg           ),
  .utlb_upd_pgs            (utlb_upd_pgs           ),
  .utlb_upd_ppn            (utlb_upd_ppn           ),
  .utlb_upd_vpn            (utlb_upd_vpn           )
);


//----------------------------------------------------------
//                  Update Info to Entry
//----------------------------------------------------------
// refill utlb entry when refill cmplt with no expt
assign {entry31_upd, entry30_upd, entry29_upd, entry28_upd,
        entry27_upd, entry26_upd, entry25_upd, entry24_upd,
        entry23_upd, entry22_upd, entry21_upd, entry20_upd,
        entry19_upd, entry18_upd, entry17_upd, entry16_upd,
        entry15_upd, entry14_upd, entry13_upd, entry12_upd,
        entry11_upd, entry10_upd, entry9_upd,  entry8_upd,
        entry7_upd,  entry6_upd,  entry5_upd,  entry4_upd,
        entry3_upd,  entry2_upd,  entry1_upd,  entry0_upd}
                           = plru_iutlb_ref_num[31:0] & {32{iutlb_refill_vld}};

// entry updt info
// 1. from jtlb if hit
// 2. from memory through dcache if hit in jtlb

assign utlb_upd_vpn[VPN_WIDTH-1:0] = ({VPN_WIDTH{ptw_l1itlb_ref_pavld}} & ptw_l1tlb_ref_vpn[VPN_WIDTH-1:0]
				     |{VPN_WIDTH{jtlb_iutlb_ref_pavld}} & jtlb_utlb_ref_vpn[VPN_WIDTH-1:0]);

assign utlb_upd_pgs[PGS_WIDTH-1:0] = ({PGS_WIDTH{ptw_l1itlb_ref_pavld}} & ptw_l1tlb_ref_pgs[PGS_WIDTH-1:0]
				     |{PGS_WIDTH{jtlb_iutlb_ref_pavld}} & jtlb_utlb_ref_pgs[PGS_WIDTH-1:0]);

assign utlb_upd_ppn[PPN_WIDTH-1:0] = ({PPN_WIDTH{ptw_l1itlb_ref_pavld}} & ptw_l1tlb_ref_ppn[PPN_WIDTH-1:0]
				     |{PPN_WIDTH{jtlb_iutlb_ref_pavld}} & jtlb_utlb_ref_ppn[PPN_WIDTH-1:0]);

assign utlb_upd_flg[FLG_WIDTH-1:0] = ({FLG_WIDTH{ptw_l1itlb_ref_pavld}} & ptw_l1tlb_ref_flg[FLG_WIDTH-1:0]
				     |{FLG_WIDTH{jtlb_iutlb_ref_pavld}} & jtlb_utlb_ref_flg[FLG_WIDTH-1:0]);


//----------------------------------------------------------
//                  I-uTLB SCD Switch to Entry
//----------------------------------------------------------
// from utlb scd entries to first entries
assign {entry24_swp_on, entry16_swp_on, entry8_swp_on, entry0_swp_on}
                           = {4{iutlb_swp_en}};

assign {entry24_swp,  entry16_swp,  entry8_swp,  entry0_swp}
                           = {4{iutlb_swp_en}} & iutlb_fst_wen[3:0];

//assign utlb_fst_swp_vpn[VPN_WIDTH-1:0] = 
//                {VPN_WIDTH{iutlb_entry_hit[1]}}  & entry1_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[2]}}  & entry2_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[3]}}  & entry3_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[4]}}  & entry4_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[5]}}  & entry5_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[6]}}  & entry6_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[7]}}  & entry7_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[9]}}  & entry9_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[10]}} & entry10_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[11]}} & entry11_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[12]}} & entry12_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[13]}} & entry13_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[14]}} & entry14_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[15]}} & entry15_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[17]}} & entry17_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[18]}} & entry18_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[19]}} & entry19_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[20]}} & entry20_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[21]}} & entry21_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[22]}} & entry22_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[23]}} & entry23_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[25]}} & entry25_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[26]}} & entry26_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[27]}} & entry27_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[28]}} & entry28_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[29]}} & entry29_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[30]}} & entry30_vpn[VPN_WIDTH-1:0]
//              | {VPN_WIDTH{iutlb_entry_hit[31]}} & entry31_vpn[VPN_WIDTH-1:0];

// To do: Page Mask?
assign utlb_fst_swp_vpn[VPN_WIDTH-1:0] = ifu_mmu_va[VPN_WIDTH+10:11];
assign utlb_fst_swp_pgs[PGS_WIDTH-1:0] = iutlb_hit_pgs_scd[PGS_WIDTH-1:0];
assign utlb_fst_swp_ppn[PPN_WIDTH-1:0] = iutlb_hit_pa_scd[PPN_WIDTH-1:0];
assign utlb_fst_swp_flg[FLG_WIDTH-1:0] = iutlb_hit_flg_scd[FLG_WIDTH-1:0];

// from utlb fst entries to scd entries
assign {entry31_swp, entry30_swp, entry29_swp, entry28_swp,
        entry27_swp, entry26_swp, entry25_swp, entry23_swp,
        entry22_swp, entry21_swp, entry20_swp, entry19_swp,
        entry18_swp, entry17_swp, entry15_swp, entry14_swp,
        entry13_swp, entry12_swp, entry11_swp, entry10_swp,
        entry9_swp,  entry7_swp,  entry6_swp,  entry5_swp,
        entry4_swp,  entry3_swp,  entry2_swp,  entry1_swp}
         = {28{iutlb_swp_en}} & {iutlb_entry_hit[31:25], iutlb_entry_hit[23:17],
                                 iutlb_entry_hit[15:9],  iutlb_entry_hit[7:1]};

assign utlb_swp_vpn[VPN_WIDTH-1:0] = 
                    {VPN_WIDTH{iutlb_fst_wen[0]}} & entry0_vpn[VPN_WIDTH-1:0]
                  | {VPN_WIDTH{iutlb_fst_wen[1]}} & entry8_vpn[VPN_WIDTH-1:0]
                  | {VPN_WIDTH{iutlb_fst_wen[2]}} & entry16_vpn[VPN_WIDTH-1:0]
                  | {VPN_WIDTH{iutlb_fst_wen[3]}} & entry24_vpn[VPN_WIDTH-1:0];

assign utlb_swp_pgs[PGS_WIDTH-1:0] = 
                    {PGS_WIDTH{iutlb_fst_wen[0]}} & entry0_pgs[PGS_WIDTH-1:0]
                  | {PGS_WIDTH{iutlb_fst_wen[1]}} & entry8_pgs[PGS_WIDTH-1:0]
                  | {PGS_WIDTH{iutlb_fst_wen[2]}} & entry16_pgs[PGS_WIDTH-1:0]
                  | {PGS_WIDTH{iutlb_fst_wen[3]}} & entry24_pgs[PGS_WIDTH-1:0];

assign utlb_swp_ppn[PPN_WIDTH-1:0] = 
                    {PPN_WIDTH{iutlb_fst_wen[0]}} & entry0_ppn[PPN_WIDTH-1:0]
                  | {PPN_WIDTH{iutlb_fst_wen[1]}} & entry8_ppn[PPN_WIDTH-1:0]
                  | {PPN_WIDTH{iutlb_fst_wen[2]}} & entry16_ppn[PPN_WIDTH-1:0]
                  | {PPN_WIDTH{iutlb_fst_wen[3]}} & entry24_ppn[PPN_WIDTH-1:0];

assign utlb_swp_flg[FLG_WIDTH-1:0] = 
                    {FLG_WIDTH{iutlb_fst_wen[0]}} & entry0_flg[FLG_WIDTH-1:0]
                  | {FLG_WIDTH{iutlb_fst_wen[1]}} & entry8_flg[FLG_WIDTH-1:0]
                  | {FLG_WIDTH{iutlb_fst_wen[2]}} & entry16_flg[FLG_WIDTH-1:0]
                  | {FLG_WIDTH{iutlb_fst_wen[3]}} & entry24_flg[FLG_WIDTH-1:0];

assign utlb_swp_on = iutlb_fst_wen[0] & entry0_vld
                   | iutlb_fst_wen[1] & entry8_vld
                   | iutlb_fst_wen[2] & entry16_vld
                   | iutlb_fst_wen[3] & entry24_vld;
assign {entry31_swp_on, entry30_swp_on, entry29_swp_on, entry28_swp_on,
        entry27_swp_on, entry26_swp_on, entry25_swp_on, entry23_swp_on,
        entry22_swp_on, entry21_swp_on, entry20_swp_on, entry19_swp_on,
        entry18_swp_on, entry17_swp_on, entry15_swp_on, entry14_swp_on,
        entry13_swp_on, entry12_swp_on, entry11_swp_on, entry10_swp_on,
        entry9_swp_on,  entry7_swp_on,  entry6_swp_on,  entry5_swp_on,
        entry4_swp_on,  entry3_swp_on,  entry2_swp_on,  entry1_swp_on} = 
        {28{utlb_swp_on}};

//==========================================================
//                  VA Matching
//==========================================================

//----------------------------------------------------------
//                  uTLB Entry Matching
//----------------------------------------------------------

assign entry_hit[31:0] = {entry31_hit,entry30_hit,entry29_hit,entry28_hit,
                          entry27_hit,entry26_hit,entry25_hit,entry24_hit,
                          entry23_hit,entry22_hit,entry21_hit,entry20_hit,
                          entry19_hit,entry18_hit,entry17_hit,entry16_hit,
                          entry15_hit,entry14_hit,entry13_hit,entry12_hit,
                          entry11_hit,entry10_hit,entry9_hit, entry8_hit,
                          entry7_hit, entry6_hit, entry5_hit, entry4_hit,
                          entry3_hit, entry2_hit, entry1_hit, entry0_hit};

assign entry_vld[31:0] = {entry31_vld,entry30_vld,entry29_vld,entry28_vld,
                          entry27_vld,entry26_vld,entry25_vld,entry24_vld,
                          entry23_vld,entry22_vld,entry21_vld,entry20_vld,
                          entry19_vld,entry18_vld,entry17_vld,entry16_vld,
                          entry15_vld,entry14_vld,entry13_vld,entry12_vld,
                          entry11_vld,entry10_vld,entry9_vld, entry8_vld,
                          entry7_vld, entry6_vld, entry5_vld, entry4_vld,
                          entry3_vld, entry2_vld, entry1_vld, entry0_vld};

assign iutlb_entry_hit[31:0] = entry_hit[31:0] & entry_vld[31:0];

assign iutlb_addr_hit_vld = |iutlb_entry_hit[31:0];

assign iutlb_addr_hit     = iutlb_entry_hit[0]  || iutlb_entry_hit[8]
                         || iutlb_entry_hit[16] || iutlb_entry_hit[24]; 

assign iutlb_swp_en       = ifu_mmu_va_vld && iutlb_addr_hit_vld && !iutlb_addr_hit
                         && !iutlb_off_hit;

//==========================================================
//                  VA Matching
//==========================================================
//----------------------------------------------------------
//                  Selecting Info from uTLB
//----------------------------------------------------------
assign iutlb_hit_pa_fst[PPN_WIDTH-1:0] = 
                  {PPN_WIDTH{iutlb_entry_hit[0]}}  & entry0_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[8]}}  & entry8_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[16]}} & entry16_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[24]}} & entry24_ppn[PPN_WIDTH-1:0];

assign iutlb_hit_pgs_fst[PGS_WIDTH-1:0] = 
                  {PGS_WIDTH{iutlb_entry_hit[0]}}  & entry0_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[8]}}  & entry8_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[16]}} & entry16_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[24]}} & entry24_pgs[PGS_WIDTH-1:0];

assign iutlb_hit_flg_fst[FLG_WIDTH-1:0] = 
                  {FLG_WIDTH{iutlb_entry_hit[0]}}  & entry0_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[8]}}  & entry8_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[16]}} & entry16_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[24]}} & entry24_flg[FLG_WIDTH-1:0];

assign iutlb_hit_pa_scd[PPN_WIDTH-1:0] = 
                  {PPN_WIDTH{iutlb_entry_hit[1]}}  & entry1_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[2]}}  & entry2_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[3]}}  & entry3_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[4]}}  & entry4_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[5]}}  & entry5_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[6]}}  & entry6_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[7]}}  & entry7_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[9]}}  & entry9_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[10]}} & entry10_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[11]}} & entry11_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[12]}} & entry12_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[13]}} & entry13_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[14]}} & entry14_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[15]}} & entry15_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[17]}} & entry17_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[18]}} & entry18_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[19]}} & entry19_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[20]}} & entry20_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[21]}} & entry21_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[22]}} & entry22_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[23]}} & entry23_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[25]}} & entry25_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[26]}} & entry26_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[27]}} & entry27_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[28]}} & entry28_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[29]}} & entry29_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[30]}} & entry30_ppn[PPN_WIDTH-1:0]
                | {PPN_WIDTH{iutlb_entry_hit[31]}} & entry31_ppn[PPN_WIDTH-1:0];

assign iutlb_hit_pgs_scd[PGS_WIDTH-1:0] =  
                  {PGS_WIDTH{iutlb_entry_hit[1]}}  & entry1_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[2]}}  & entry2_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[3]}}  & entry3_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[4]}}  & entry4_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[5]}}  & entry5_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[6]}}  & entry6_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[7]}}  & entry7_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[9]}}  & entry9_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[10]}} & entry10_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[11]}} & entry11_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[12]}} & entry12_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[13]}} & entry13_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[14]}} & entry14_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[15]}} & entry15_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[17]}} & entry17_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[18]}} & entry18_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[19]}} & entry19_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[20]}} & entry20_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[21]}} & entry21_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[22]}} & entry22_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[23]}} & entry23_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[25]}} & entry25_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[26]}} & entry26_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[27]}} & entry27_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[28]}} & entry28_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[29]}} & entry29_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[30]}} & entry30_pgs[PGS_WIDTH-1:0]
                | {PGS_WIDTH{iutlb_entry_hit[31]}} & entry31_pgs[PGS_WIDTH-1:0];

assign iutlb_hit_flg_scd[FLG_WIDTH-1:0] =  
                  {FLG_WIDTH{iutlb_entry_hit[1]}}  & entry1_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[2]}}  & entry2_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[3]}}  & entry3_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[4]}}  & entry4_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[5]}}  & entry5_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[6]}}  & entry6_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[7]}}  & entry7_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[9]}}  & entry9_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[10]}} & entry10_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[11]}} & entry11_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[12]}} & entry12_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[13]}} & entry13_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[14]}} & entry14_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[15]}} & entry15_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[17]}} & entry17_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[18]}} & entry18_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[19]}} & entry19_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[20]}} & entry20_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[21]}} & entry21_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[22]}} & entry22_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[23]}} & entry23_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[25]}} & entry25_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[26]}} & entry26_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[27]}} & entry27_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[28]}} & entry28_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[29]}} & entry29_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[30]}} & entry30_flg[FLG_WIDTH-1:0]
                | {FLG_WIDTH{iutlb_entry_hit[31]}} & entry31_flg[FLG_WIDTH-1:0];

//----------------------------------------------------------
//                  Flop utlb second result for timing
//----------------------------------------------------------
//always @(posedge iutlb_clk or negedge cpurst_b)
//begin
//  if (!cpurst_b)
//    iutlb_hit_pa_scd_flop[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
//  else if(iutlb_entry_hit_vld_scd)
//    iutlb_hit_pa_scd_flop[PPN_WIDTH-1:0] <= iutlb_hit_pa_scd[PPN_WIDTH-1:0];
//end
//
//always @(posedge iutlb_clk or negedge cpurst_b)
//begin
//  if (!cpurst_b)
//    iutlb_hit_pgs_scd_flop[PGS_WIDTH-1:0] <= {PGS_WIDTH{1'b0}};
//  else if(iutlb_entry_hit_vld_scd)
//    iutlb_hit_pgs_scd_flop[PGS_WIDTH-1:0] <= iutlb_hit_pgs_scd[PGS_WIDTH-1:0];
//end
//
//always @(posedge iutlb_clk or negedge cpurst_b)
//begin
//  if (!cpurst_b)
//    iutlb_hit_flg_scd_flop[FLG_WIDTH-1:0] <= {FLG_WIDTH{1'b0}};
//  else if(iutlb_entry_hit_vld_scd)
//    iutlb_hit_flg_scd_flop[FLG_WIDTH-1:0] <= iutlb_hit_flg_scd[FLG_WIDTH-1:0];
//end

always @(posedge iutlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    iutlb_fst_wen[3:0] <= 4'b0001;
  else if(iutlb_swp_en)
    iutlb_fst_wen[3:0] <= {iutlb_fst_wen[2:0], iutlb_fst_wen[3]};
end

//----------------------------------------------------------
//                  MUX the pa except utlb first entries
//----------------------------------------------------------
//assign iutlb_bypass_pa[PPN_WIDTH-1:0]  = jtlb_utlb_ref_ppn[PPN_WIDTH-1:0];
//assign iutlb_bypass_pgs[PGS_WIDTH-1:0] = jtlb_utlb_ref_pgs[PGS_WIDTH-1:0];
//assign iutlb_bypass_flg[FLG_WIDTH-1:0] = jtlb_utlb_ref_flg[FLG_WIDTH-1:0];

// address attribute is checked by PMP when M-Mode or MMU not enabled
// pa and flag when mmu is off
assign iutlb_off_pa[PPN_WIDTH-1:0]  = ifu_mmu_va[VPN_WIDTH+11:11];
// off page size is 4K
assign iutlb_off_pgs[PGS_WIDTH-1:0] = 3'b1;
// Sysmap PMA Flags, RSW-zero, Non-Dirty, Access, Non-User, X, W, R, Valid
assign iutlb_off_flg[FLG_WIDTH-1:0] = {sysmap_mmu_flg2[4:0], 5'b00010, 3'b111, 1'b1};

//assign iutlb_bypass_hit = iutlb_wfc;
//assign iutlb_hit_pa_drct[PPN_WIDTH-1:0] =  
//          {PPN_WIDTH{iutlb_bypass_hit}} & iutlb_bypass_pa[PPN_WIDTH-1:0]
//        | {PPN_WIDTH{iutlb_off_hit}}    & iutlb_off_pa[PPN_WIDTH-1:0]
//        | {PPN_WIDTH{iutlb_scd}}        & iutlb_hit_pa_scd_flop[PPN_WIDTH-1:0];
//
//assign iutlb_hit_pgs_drct[PGS_WIDTH-1:0] =  
//          {PGS_WIDTH{iutlb_bypass_hit}} & iutlb_bypass_pgs[PGS_WIDTH-1:0]
//        | {PGS_WIDTH{iutlb_off_hit}}    & iutlb_off_pgs[PGS_WIDTH-1:0]
//        | {PGS_WIDTH{iutlb_scd}}        & iutlb_hit_pgs_scd_flop[PGS_WIDTH-1:0];
//
//assign iutlb_hit_flg_drct[FLG_WIDTH-1:0] =  
//          {FLG_WIDTH{iutlb_bypass_hit}} & iutlb_bypass_flg[FLG_WIDTH-1:0]
//        | {FLG_WIDTH{iutlb_off_hit}}    & iutlb_off_flg[FLG_WIDTH-1:0]
//        | {FLG_WIDTH{iutlb_scd}}        & iutlb_hit_flg_scd_flop[FLG_WIDTH-1:0];

//----------------------------------------------------------
//                  JTLB Access Fault
//----------------------------------------------------------
// to cut off the timing from dutlb abort to access fault
assign iutlb_acc_flt  = ptw_l1tlb_acc_err && iutlb_refill_on;
assign jtlb_acc_fault = iutlb_acc_flt
                    || (iutlb_hit_vld || iutlb_disable_vld) && iutlb_flg_aft_bypass[13];

always @(posedge iutlb_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    jtlb_acc_fault_flop <= 1'b0;
  else if(jtlb_acc_fault)
    jtlb_acc_fault_flop <= 1'b1;
  else
    jtlb_acc_fault_flop <= 1'b0;
end

//----------------------------------------------------------
//                  PMP Check
//----------------------------------------------------------
// to cut off the timing from final-pa to pmp check
// pa buffer clock
assign iutlb_pa_vld = iutlb_hit_vld || iutlb_disable_vld;
//assign pabuf_clk_en = iutlb_pa_vld ^ pmp_flg_vld
//                    || iutlb_hit_vld && (iutlb_hit_pa_fst[PPN_WIDTH-1:0] !=
//                             iutlb_pa_buf[PPN_WIDTH-1:0])
//                    || iutlb_disable_vld && (iutlb_off_pa[PPN_WIDTH-1:0] !=
//                             iutlb_pa_buf[PPN_WIDTH-1:0]);
assign pabuf_clk_en = iutlb_pa_vld || pmp_flg_vld;
// &Instance("gated_clk_cell", "x_iutlb_pabuf_gateclk"); @823
gated_clk_cell  x_iutlb_pabuf_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (pabuf_clk         ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (pabuf_clk_en      ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

// &Connect( .clk_in     (forever_cpuclk), @824
//           .external_en(1'b0          ), @825
//           .global_en  (1'b1          ), @826
//           .module_en  (cp0_mmu_icg_en), @827
//           .local_en   (pabuf_clk_en  ), @828
//           .clk_out    (pabuf_clk     ) @829
//          ); @830

assign iutlb_pmp_chk_vld = iutlb_pa_vld && !iutlb_page_fault;

always @(posedge pabuf_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    pmp_flg_vld <= 1'b0;
  else if(iutlb_pmp_chk_vld)
    pmp_flg_vld <= 1'b1;
  else
    pmp_flg_vld <= 1'b0;
end

always @(posedge pabuf_clk)
begin
  if(iutlb_pmp_chk_vld)
    iutlb_pa_buf[PPN_WIDTH-1:0] <= iutlb_pa_aft_bypass[PPN_WIDTH-1:0];
end

assign mmu_pmp_pa2[PPN_WIDTH-1:0] = iutlb_pa_buf[PPN_WIDTH-1:0];


//----------------------------------------------------------
//                  MUX the final pa 
//----------------------------------------------------------
//assign pa_drct_sel = iutlb_bypass_hit || iutlb_off_hit || iutlb_scd;

assign pa_offset[VPN_WIDTH-1:0] = ifu_mmu_va[VPN_WIDTH+10:11];

assign pa_fin[PPN_WIDTH-1:0] =  
          {PPN_WIDTH{iutlb_off_hit}}  & iutlb_off_pa[PPN_WIDTH-1:0]
        | {PPN_WIDTH{iutlb_addr_hit}} & iutlb_hit_pa_fst[PPN_WIDTH-1:0];

assign pgs_fin[PGS_WIDTH-1:0] =  
          {PGS_WIDTH{iutlb_off_hit}}  & iutlb_off_pgs[PGS_WIDTH-1:0]
        | {PGS_WIDTH{iutlb_addr_hit}} & iutlb_hit_pgs_fst[PGS_WIDTH-1:0];

assign flg_fin[FLG_WIDTH-1:0] =  
          {FLG_WIDTH{iutlb_off_hit}}  & iutlb_off_flg[FLG_WIDTH-1:0]
        | {FLG_WIDTH{iutlb_addr_hit}} & iutlb_hit_flg_fst[FLG_WIDTH-1:0];

//assign pa_fin[PPN_WIDTH-1:0]  = pa_drct_sel 
//                              ? iutlb_hit_pa_drct[PPN_WIDTH-1:0]
//                              : iutlb_hit_pa_fst[PPN_WIDTH-1:0];
//
//assign pgs_fin[PGS_WIDTH-1:0] = pa_drct_sel 
//                              ? iutlb_hit_pgs_drct[PGS_WIDTH-1:0]
//                              : iutlb_hit_pgs_fst[PGS_WIDTH-1:0];
//
//assign flg_fin[FLG_WIDTH-1:0] = pa_drct_sel 
//                              ? iutlb_hit_flg_drct[FLG_WIDTH-1:0]
//                              : iutlb_hit_flg_fst[FLG_WIDTH-1:0];

assign iutlb_pa_aft_bypass[PPN_WIDTH-1:0] =  
     {PPN_WIDTH{pgs_fin[2]}} & {pa_fin[PPN_WIDTH-1:VPN_PERLEL*2], pa_offset[VPN_PERLEL*2-1:0]}
   | {PPN_WIDTH{pgs_fin[1]}} & {pa_fin[PPN_WIDTH-1:VPN_PERLEL*1], pa_offset[VPN_PERLEL*1-1:0]}
   | {PPN_WIDTH{pgs_fin[0]}} &  pa_fin[PPN_WIDTH-1:0];

assign iutlb_flg_aft_bypass[FLG_WIDTH-1:0] = flg_fin[FLG_WIDTH-1:0];

// for off pma flags
assign mmu_sysmap_pa2[PPN_WIDTH-1:0] = iutlb_off_pa[PPN_WIDTH-1:0];

// for dbg
assign iutlb_top_ref_cur_st[1:0] = ref_cur_st[1:0];
assign iutlb_ptw_wfc             = iutlb_wfc;


// &ModuleEnd; @899
endmodule




