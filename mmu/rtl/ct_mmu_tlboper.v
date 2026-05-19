//!**********************************************************************
//! TMO: TLB Management Operation
//!
//!  1. TMO Sources:
//!     1.1 LSU (SFENCE.VMA) ?
//!     1.2 Register (C910)
//!     1.3 CP0
//!
//!  2. TLBOp
//!     2.1 TLBOp <=> L1ITLB
//!     2.2 TLBOp <=> L1DTLB
//!     2.3 TLBOp <=> L2TLB
//!     2.4 TLBOp <=> PTW
//!**********************************************************************

module ct_mmu_tlboper#(

parameter WAY_NUM    = 8,
parameter VPN_WIDTH  = 39-12,  // VPN
parameter PPN_WIDTH  = 40-12,  // PPN
parameter ASID_WIDTH = 16,     // Flags
parameter FLG_WIDTH  = 14,     // Flags
parameter PGS_WIDTH  = 3,      // Page Size

// Valid + VPN + ASID + PageSize + Global
parameter TAG_WIDTH  = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,  
parameter DATA_WIDTH = PPN_WIDTH+FLG_WIDTH  



)(

//!********************************************
//!              clk and rst
//!******************************************** 
input  logic         cpurst_b,                   
input  logic         forever_cpuclk,
input  logic         pad_yy_icg_scan_en,
input  logic         cp0_mmu_icg_en,

//!********************************************
//!              LSU <=> TLBOp
//!******************************************** 
//! LSU request to TLBOp
//! TMO: TLB Management Operations
//!   1. invalid all TLB entries
//!   2. invalid the asid matched TLB entries
//!   3. invalid the va matched TLB entries
//!   4. 
input  logic         lsu_mmu_tlb_all_inv,        
input  logic         lsu_mmu_tlb_asid_all_inv,   
input  logic         lsu_mmu_tlb_va_all_inv,     
input  logic         lsu_mmu_tlb_va_asid_inv,   //! ?
input  logic [15:0]  lsu_mmu_tlb_asid,    
input  logic [26:0]  lsu_mmu_tlb_va,

//! TLBOp response to LSU
output logic         mmu_lsu_tlb_inv_done,
             
//!********************************************
//!              Regs <=> TLBOp
//!******************************************** 
//! Regs request to TLBOp
input  logic         regs_tlboper_invall,        
input  logic         regs_tlboper_invasid,       
input  logic         regs_tlboper_tlbp,          
input  logic         regs_tlboper_tlbr,          
input  logic         regs_tlboper_tlbwi,         
input  logic         regs_tlboper_tlbwr,
input  logic [15:0]  regs_tlboper_inv_asid,

input  logic [13:0]  regs_jtlb_cur_flg,          
input  logic         regs_jtlb_cur_g,            
input  logic [27:0]  regs_jtlb_cur_ppn,          

input  logic [15:0]  regs_tlboper_cur_asid,    //! Current ASID
input  logic [2 :0]  regs_tlboper_cur_pgs,     //! Current PageSize
input  logic [26:0]  regs_tlboper_cur_vpn,     //! Current VPN
input  logic [11:0]  regs_tlboper_mir,         //! ??

//! TLBOp response to Regs
output logic         tlboper_regs_cmplt,         
output logic         tlboper_regs_tlbp_cmplt,    
output logic         tlboper_regs_tlbr_cmplt,

//!******************************************** 
//! cp0 <=> mmu         
//!******************************************** 
input  logic         cp0_mmu_tlb_all_inv,
output logic         mmu_cp0_tlb_done,           

//!********************************************
//!              L2TLB <=> TLBOp
//!******************************************** 
//! TLBOp request to L2TLB
output logic [15:0]  tlboper_jtlb_asid,          
output logic         tlboper_jtlb_asid_sel,      
output logic         tlboper_jtlb_cmp_noasid,    
output logic [15:0]  tlboper_jtlb_inv_asid,      
output logic         tlboper_jtlb_tlbwr_on, 
output logic         tlboper_jtlb_invasid_on,

//! L2TLB response to TLBOp            
input  logic         jtlb_tlboper_asid_hit,      
input  logic         jtlb_tlboper_cmplt,         
//input  logic [3 :0]  jtlb_tlboper_fifo,   //////////       
//input  logic         jtlb_tlboper_read_idle,     
input  logic [WAY_NUM-1 :0]  jtlb_tlboper_sel,           
input  logic         jtlb_tlboper_va_hit,        
//input  logic         jtlb_xx_tc_read,
            
//!********************************************
//!             TLBOp  <=> Arbiter
//!********************************************
output logic         tlboper_arb_req,            
output logic         tlboper_arb_write,
output logic [47:0]  tlboper_arb_tag_din,        
output logic [26:0]  tlboper_arb_vpn,            
output logic [WAY_NUM-1 :0]  tlboper_arb_bank_sel,       
output logic         tlboper_arb_cmp_va,         
output logic [41:0]  tlboper_arb_data_din,       
//output logic         tlboper_arb_fifo_write,     
//output logic [3 :0]  tlboper_arb_fifo_din,       
output logic [10:0]  tlboper_arb_idx,
output logic         tlboper_arb_idx_not_va,     

input  logic         arb_tlboper_grant,      

//!********************************************
//!              tlboper=>utlb
//!******************************************** 
output logic         tlboper_utlb_inv_va_req,    
output logic         tlboper_utlb_clr, 

//!********************************************
//!              tlboper=>ptw
//!********************************************          
output logic         tlboper_ptw_abort,

//!********************************************
//!              tlboper => top ???
//!********************************************    
output logic         tlboper_top_lsu_cmplt,      
output logic         tlboper_top_lsu_oper,       
output logic         tlboper_top_tlbiall_cur_st, 
output logic [2 :0]  tlboper_top_tlbiasid_cur_st, 
output logic [3 :0]  tlboper_top_tlbiva_cur_st,  
output logic [1 :0]  tlboper_top_tlbp_cur_st,    
output logic [1 :0]  tlboper_top_tlbr_cur_st,    
output logic [1 :0]  tlboper_top_tlbwi_cur_st,   
output logic [1 :0]  tlboper_top_tlbwr_cur_st,   
output logic         tlboper_xx_cmplt,           
output logic [2 :0]  tlboper_xx_pgs             
//output logic         tlboper_xx_pgs_en

);


// &Regs; @26
logic             lsu_oper_cmplt;             
logic     [10:0]  tlb_inv_cnt;                
logic             tlb_lsu_oper_flop;          
logic             tlbiall_cur_st;             
logic             tlbiall_nxt_st;             
logic     [2 :0]  tlbiasid_cur_st;            
logic     [2 :0]  tlbiasid_nxt_st;            
logic     [3 :0]  tlbiva_cur_st;              
logic     [3 :0]  tlbiva_nxt_st;              
logic     [1 :0]  tlbp_cur_st;                
logic     [1 :0]  tlbp_nxt_st;                
logic     [1 :0]  tlbr_cur_st;                
logic     [1 :0]  tlbr_nxt_st;                
logic     [1 :0]  tlbwi_cur_st;               
logic     [1 :0]  tlbwi_nxt_st;               
logic     [1 :0]  tlbwr_cur_st;               
logic     [1 :0]  tlbwr_nxt_st;               

// &Wires; @27
logic            bank_sel_all;               
logic            bank_sel_idx;               
logic            bank_sel_wr;                
logic    [WAY_NUM-1:0]  idx_sel;
logic    [10:0]  invall_cnt;                 
logic    [10:0]  invasid_cnt;                
logic    [10:0]  jtlb_cnt;                   
logic            lsu_va_sel;                 
logic            tlb_cnt_inv_on;             
logic            tlb_inv_all;                
logic            tlb_inv_asid;               
logic            tlb_inv_cnt_dec;            
logic            tlb_inv_cnt_init;           
logic            tlb_inv_done;               
logic            tlb_inv_va;                 
logic            tlb_invall_cmplt;           
logic            tlb_invall_cnt_dec;         
logic            tlb_invall_cnt_init;        
logic            tlb_invall_req;             
logic            tlb_invasid_cmplt;          
logic            tlb_invasid_cnt_dec;        
logic            tlb_invasid_cnt_init;       
logic            tlb_invasid_rd_req;         
logic            tlb_invasid_req;            
logic            tlb_invasid_wt_req;         
logic            tlb_invva_1g;               
logic            tlb_invva_2m;               
logic            tlb_invva_4k;               
logic            tlb_invva_cmplt;            
logic            tlb_invva_rd_req;           
logic            tlb_invva_req;              
logic            tlb_invva_wt_req;           
logic            tlb_lsu_oper;               
logic            tlb_lsu_oper_cmplt;         
logic    [27:0]  tlb_ppn_aft_mask;           
logic            tlb_sm_idle;                
logic            tlb_tag_vld_in;             
logic            tlb_tlbp_cmplt;             
logic            tlb_tlbp_req;               
logic            tlb_tlbr_cmplt;             
logic            tlb_tlbr_req;               
logic            tlb_tlbwi_cmplt;            
logic            tlb_tlbwi_req;              
logic            tlb_tlbwr_cmplt;            
logic            tlb_tlbwr_rd_req;           
logic            tlb_tlbwr_req;              
logic            tlbwr_wt_grant;
logic            tlb_tlbwr_wt_req;           
logic    [26:0]  tlb_vpn_aft_mask;           
logic            tlboper_clk;                
logic            tlboper_clk_en;             
logic            tlboper_cmplt;              
logic    [41:0]  tlboper_data_din;           
logic    [10:0]  tlboper_idx_not_va;         
logic    [47:0]  tlboper_tag_din;            



//==========================================================
//                  Gate Cell
//==========================================================
assign tlboper_clk_en = regs_tlboper_tlbp
                     || regs_tlboper_tlbr
                     || regs_tlboper_tlbwi
                     || regs_tlboper_tlbwr
                     || tlb_inv_asid
                     || tlb_inv_all
                     || tlb_inv_va
                     || lsu_oper_cmplt
                     || !tlb_sm_idle;
// &Instance("gated_clk_cell", "x_tlboper_gateclk"); @51
gated_clk_cell  x_tlboper_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (tlboper_clk       ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (tlboper_clk_en    ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

// &Connect( .clk_in     (forever_cpuclk  ), @52
//           .external_en(1'b0            ), @53
//           .global_en  (1'b1            ), @54
//           .module_en  (cp0_mmu_icg_en  ), @55
//           .local_en   (tlboper_clk_en  ), @56
//           .clk_out    (tlboper_clk     ) @57
//          ); @58



//==============================================================================
//                  TLB oper FSM
//==============================================================================
//==========================================================
// FSM for TLBP
// a. read request to TLB
// b. compare if the ASID matched ASID in MEH and write result
//==========================================================
parameter PIDLE = 2'b00,
          PWFG  = 2'b01,
          PWFC  = 2'b11;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbp_cur_st[1:0] <= PIDLE;
  else
    tlbp_cur_st[1:0] <= tlbp_nxt_st[1:0];
end

// &CombBeg; @82
always @( tlb_lsu_oper_flop
       or tlbp_cur_st[1:0]
       or arb_tlboper_grant
       or regs_tlboper_tlbp
       or jtlb_tlboper_cmplt)
begin
case(tlbp_cur_st[1:0])
PIDLE:
begin
  if(regs_tlboper_tlbp && !tlb_lsu_oper_flop)
    tlbp_nxt_st[1:0] = PWFG;
  else
    tlbp_nxt_st[1:0] = PIDLE;
end
PWFG:
begin
  if(arb_tlboper_grant)
    tlbp_nxt_st[1:0] = PWFC;
  else
    tlbp_nxt_st[1:0] = PWFG;
end
PWFC:
begin
  if(jtlb_tlboper_cmplt) 
    tlbp_nxt_st[1:0] = PIDLE;
  else
    tlbp_nxt_st[1:0] = PWFC;
end
default:
begin
  tlbp_nxt_st[1:0] = PIDLE;
end
endcase
// &CombEnd; @110
end

assign tlb_tlbp_req   = (tlbp_cur_st[1:0] == PWFG);

assign tlb_tlbp_cmplt = (tlbp_cur_st[1:0] == PWFC)
                           && jtlb_tlboper_cmplt;


//==========================================================
// FSM for TLBR
// 1. read request to TLB
// 2. write result to regs
//==========================================================
parameter RIDLE = 2'b00,
          RWFG  = 2'b01,
          RWFC  = 2'b11;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbr_cur_st[1:0] <= RIDLE;
  else
    tlbr_cur_st[1:0] <= tlbr_nxt_st[1:0];
end

// &CombBeg; @135
always @( arb_tlboper_grant
       or tlbr_cur_st[1:0]
       or jtlb_tlboper_cmplt
       or regs_tlboper_tlbr
       or tlb_lsu_oper)
begin
case(tlbr_cur_st[1:0])
RIDLE:
begin
  if(regs_tlboper_tlbr && !tlb_lsu_oper)
    tlbr_nxt_st[1:0] = RWFG;
  else
    tlbr_nxt_st[1:0] = RIDLE;
end
RWFG:
begin
  if(arb_tlboper_grant)
    tlbr_nxt_st[1:0] = RWFC;
  else
    tlbr_nxt_st[1:0] = RWFG;
end
RWFC:
begin
  if(jtlb_tlboper_cmplt)
    tlbr_nxt_st[1:0] = RIDLE;
  else
    tlbr_nxt_st[1:0] = RWFC;
end
default:
begin
  tlbr_nxt_st[1:0] = RIDLE;
end
endcase
// &CombEnd; @163
end

assign tlb_tlbr_req   = (tlbr_cur_st[1:0] == RWFG);

assign tlb_tlbr_cmplt = (tlbr_cur_st[1:0] == RWFC)
                           && jtlb_tlboper_cmplt;


//==========================================================
// FSM for TLBWI
// 1. write request to TLB
// 2. complete
//==========================================================
parameter WIIDLE = 2'b00,
          WIWFG  = 2'b01,
          WIWFC  = 2'b11;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbwi_cur_st[1:0] <= WIIDLE;
  else
    tlbwi_cur_st[1:0] <= tlbwi_nxt_st[1:0];
end

// &CombBeg; @188
always @( regs_tlboper_tlbwi
       or arb_tlboper_grant
       or jtlb_tlboper_cmplt
       or tlbwi_cur_st[1:0]
       or tlb_lsu_oper)
begin
case(tlbwi_cur_st[1:0])
WIIDLE:
begin
  if(regs_tlboper_tlbwi && !tlb_lsu_oper)
    tlbwi_nxt_st[1:0] = WIWFG;
  else
    tlbwi_nxt_st[1:0] = WIIDLE;
end
WIWFG:
begin
  if(arb_tlboper_grant)
    tlbwi_nxt_st[1:0] = WIWFC;
  else
    tlbwi_nxt_st[1:0] = WIWFG;
end
WIWFC:
begin
  if(jtlb_tlboper_cmplt)
    tlbwi_nxt_st[1:0] = WIIDLE;
  else
    tlbwi_nxt_st[1:0] = WIWFC;
end
default:
begin
  tlbwi_nxt_st[1:0] = WIIDLE;
end
endcase
// &CombEnd; @216
end

assign tlb_tlbwi_req   = (tlbwi_cur_st[1:0] == WIWFG);

assign tlb_tlbwi_cmplt = (tlbwi_cur_st[1:0] == WIWFC)
                            && jtlb_tlboper_cmplt;


//==========================================================
// FSM for TLBWR
// 1. read fifo bit from JTLB tag entry
// 2. write request to TLB
// 3. complete
//==========================================================
parameter WRIDLE = 2'b00,
          WRWFG  = 2'b10,
          WRTAG  = 2'b01,
          WRWFC  = 2'b11;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbwr_cur_st[1:0] <= WRIDLE;
  else
    tlbwr_cur_st[1:0] <= tlbwr_nxt_st[1:0];
end

// &CombBeg; @243
always @( regs_tlboper_tlbwr
       or tlbwr_cur_st
       or tlbwr_wt_grant
       or arb_tlboper_grant
       or jtlb_tlboper_cmplt
       or tlb_lsu_oper)
begin
case(tlbwr_cur_st)
WRIDLE:
begin
  if(regs_tlboper_tlbwr && !tlb_lsu_oper)
    tlbwr_nxt_st[1:0] = WRWFG;
  else
    tlbwr_nxt_st[1:0] = WRIDLE;
end
WRWFG:
begin
  if(arb_tlboper_grant)
    tlbwr_nxt_st[1:0] = WRTAG;
  else
    tlbwr_nxt_st[1:0] = WRWFG;
end
WRTAG:
begin
  if(jtlb_tlboper_cmplt)
    tlbwr_nxt_st[1:0] = WRWFC;
  else
    tlbwr_nxt_st[1:0] = WRTAG;
end
WRWFC:
begin
  if(tlbwr_wt_grant && jtlb_tlboper_cmplt)
    tlbwr_nxt_st[1:0] = WRIDLE;
  else
    tlbwr_nxt_st[1:0] = WRWFC;
end
default:
begin
  tlbwr_nxt_st[1:0] = WRIDLE;
end
endcase
// &CombEnd; @278
end

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbwr_wt_grant <= 1'b0;
  else if(tlbwr_cur_st[1:0] == WRIDLE)
    tlbwr_wt_grant <= 1'b0;
  else if(tlb_tlbwr_wt_req && arb_tlboper_grant)
    tlbwr_wt_grant <= 1'b1;
  else if(tlb_tlbwr_cmplt)
    tlbwr_wt_grant <= 1'b0;
end

assign tlb_tlbwr_rd_req = (tlbwr_cur_st[1:0] == WRWFG);
assign tlb_tlbwr_wt_req = (tlbwr_cur_st[1:0] == WRTAG)
                             && jtlb_tlboper_cmplt
                        || (tlbwr_cur_st[1:0] == WRWFC)
                             && !tlbwr_wt_grant;
assign tlb_tlbwr_req    = tlb_tlbwr_rd_req || tlb_tlbwr_wt_req;

assign tlb_tlbwr_cmplt  = (tlbwr_cur_st[1:0] == WRWFC)
                             && tlbwr_wt_grant
                             && jtlb_tlboper_cmplt;


//==========================================================
// FSM for TLBINVIDX
// 1. write request to TLB 
// 2. complete
//==========================================================





//==========================================================
// FSM for INVASID
// 1. read every entry and compare 
// 2. write request to TLB if hit
// 3. complete
//==========================================================
parameter IASID_IDLE = 3'b000,
          IASID_RD   = 3'b001,
          IASID_WFC  = 3'b010,
          IASID_WT   = 3'b011,
          IASID_NWT  = 3'b100;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbiasid_cur_st[2:0] <= IASID_IDLE;
  else
    tlbiasid_cur_st[2:0] <= tlbiasid_nxt_st[2:0];
end

assign tlb_inv_asid = lsu_mmu_tlb_asid_all_inv && !lsu_oper_cmplt && tlb_sm_idle || regs_tlboper_invasid && !tlb_lsu_oper;

// &CombBeg; @321
always_comb begin
case(tlbiasid_cur_st)
IASID_IDLE:
begin
  if(tlb_inv_asid)
    tlbiasid_nxt_st[2:0] = IASID_RD;
  else
    tlbiasid_nxt_st[2:0] = IASID_IDLE;
end
IASID_RD:
begin
  if(arb_tlboper_grant)
    tlbiasid_nxt_st[2:0] = IASID_WFC;
  else
    tlbiasid_nxt_st[2:0] = IASID_RD;
end
IASID_WFC:
begin
  if(jtlb_tlboper_cmplt && /*jtlb_xx_tc_read &&*/ jtlb_tlboper_asid_hit)
    tlbiasid_nxt_st[2:0] = IASID_WT;
  else if(jtlb_tlboper_cmplt /*&& jtlb_xx_tc_read*/)
    tlbiasid_nxt_st[2:0] = IASID_NWT;
  else
    tlbiasid_nxt_st[2:0] = IASID_WFC;
end
IASID_WT:
begin
  if(arb_tlboper_grant)
    if(tlb_inv_done)
      tlbiasid_nxt_st[2:0] = IASID_IDLE;
    else
      tlbiasid_nxt_st[2:0] = IASID_RD;
  else
    tlbiasid_nxt_st[2:0] = IASID_WT;
end
IASID_NWT:
begin
  if(tlb_inv_done)
    tlbiasid_nxt_st[2:0] = IASID_IDLE;
   else
    tlbiasid_nxt_st[2:0] = IASID_RD;
end
default:
begin
  tlbiasid_nxt_st[2:0] = IASID_IDLE;
end
endcase
// &CombEnd; @365
end

assign tlb_invasid_rd_req = (tlbiasid_cur_st[2:0] == IASID_RD);
assign tlb_invasid_wt_req = (tlbiasid_cur_st[2:0] == IASID_WT);
assign tlb_invasid_req    = tlb_invasid_rd_req || tlb_invasid_wt_req;

assign tlb_invasid_cmplt = ((tlbiasid_cur_st[2:0] == IASID_WT) && arb_tlboper_grant
                                || (tlbiasid_cur_st[2:0] == IASID_NWT)
                           ) && tlb_inv_done;

assign tlb_invasid_cnt_init = (tlbiasid_cur_st[2:0] == IASID_IDLE)
                                 && tlb_inv_asid;
assign tlb_invasid_cnt_dec  = ((tlbiasid_cur_st[2:0] ==  IASID_WT) && arb_tlboper_grant
                                || (tlbiasid_cur_st[2:0] == IASID_NWT)
                              ) && !tlb_inv_done;          


//==========================================================
// FSM for TLBINVALL
// 1. write request to TLB
// 2. check if counter is zero 
// 3. complete
//==========================================================
parameter IALL_IDLE = 1'b0,
          IALL_WFC  = 1'b1;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbiall_cur_st <= IALL_IDLE;
  else
    tlbiall_cur_st <= tlbiall_nxt_st;
end

assign tlb_inv_all = lsu_mmu_tlb_all_inv && !lsu_oper_cmplt && tlb_sm_idle
                  || regs_tlboper_invall && !tlb_lsu_oper && !cp0_mmu_tlb_all_inv
                  || cp0_mmu_tlb_all_inv && !lsu_oper_cmplt && tlb_sm_idle;

// &CombBeg; @403
always @( tlb_inv_done
       or tlb_inv_all
       or tlbiall_cur_st
       or arb_tlboper_grant)
begin
case(tlbiall_cur_st)
IALL_IDLE:
begin
  if(tlb_inv_all)
    tlbiall_nxt_st = IALL_WFC;
  else
    tlbiall_nxt_st = IALL_IDLE;
end
IALL_WFC:
begin
  if(arb_tlboper_grant && tlb_inv_done)
    tlbiall_nxt_st = IALL_IDLE;
  else
    tlbiall_nxt_st = IALL_WFC;
end
default:
begin
  tlbiall_nxt_st = IALL_IDLE;
end
endcase
// &CombEnd; @424
end

assign tlb_invall_req = (tlbiall_cur_st == IALL_WFC);

assign tlb_invall_cmplt = (tlbiall_cur_st ==  IALL_WFC)
                                   && arb_tlboper_grant
                                   && tlb_inv_done;
assign tlb_invall_cnt_init = (tlbiall_cur_st == IALL_IDLE)
                                && tlb_inv_all;
assign tlb_invall_cnt_dec  = (tlbiall_cur_st ==  IALL_WFC)
                                && arb_tlboper_grant
                                && !tlb_inv_done;
 
//==========================================================
// FSM for TLBINVVA
// 1. write request to TLB
// 2. check if VA hit 
// 3. complete
//==========================================================
//parameter IVA_IDLE   = 4'b0000,
//          IVA_4K_RD  = 4'b0010,
//          IVA_4K_CMP = 4'b0011,
//          IVA_4K_WR  = 4'b0100,
//          IVA_4K_WT  = 4'b0101,
//          IVA_2M_RD  = 4'b0110,
//          IVA_2M_CMP = 4'b0111,
//          IVA_2M_WR  = 4'b1000,
//          IVA_2M_WT  = 4'b1001,
//          IVA_1G_RD  = 4'b1010,
//          IVA_1G_CMP = 4'b1011,
//          IVA_1G_WR  = 4'b1100,
//          IVA_1G_WT  = 4'b1101,
//          IVA_CMPLT  = 4'b1110;
//
//always @(posedge tlboper_clk or negedge cpurst_b)
//begin
//  if(!cpurst_b)
//    tlbiva_cur_st[3:0] <= IVA_IDLE;
//  else
//    tlbiva_cur_st[3:0] <= tlbiva_nxt_st[3:0];
//end
//
//assign tlb_inv_va = (lsu_mmu_tlb_va_all_inv || lsu_mmu_tlb_va_asid_inv)
//                    && !lsu_oper_cmplt && tlb_sm_idle;

//// &CombBeg; @469
//always @( tlbiva_cur_st
//       or jtlb_tlboper_va_hit
//       or tlb_inv_va
//       or arb_tlboper_grant
//       or jtlb_tlboper_cmplt)
//begin
//case(tlbiva_cur_st)
//IVA_IDLE:
//begin
//  if(tlb_inv_va)
//    tlbiva_nxt_st[3:0] = IVA_4K_RD;
//  else
//    tlbiva_nxt_st[3:0] = IVA_IDLE;
//end
//IVA_4K_RD:
//begin
//  if(arb_tlboper_grant)
//    tlbiva_nxt_st[3:0] = IVA_4K_CMP;
//  else
//    tlbiva_nxt_st[3:0] = IVA_4K_RD;
//end
//IVA_4K_CMP:
//begin
//  if(jtlb_tlboper_cmplt)
//    if(jtlb_tlboper_va_hit)
//      tlbiva_nxt_st[3:0] = IVA_4K_WR;
//    else
//      tlbiva_nxt_st[3:0] = IVA_2M_RD;
//  else
//    tlbiva_nxt_st[3:0] = IVA_4K_CMP;
//end
//IVA_4K_WR:
//begin
//  if(arb_tlboper_grant)
//    tlbiva_nxt_st[3:0] = IVA_4K_WT;
//  else
//    tlbiva_nxt_st[3:0] = IVA_4K_WR;
//end
//IVA_4K_WT:
//begin
//  if(jtlb_tlboper_cmplt)
//    tlbiva_nxt_st[3:0] = IVA_2M_RD;
//  else
//    tlbiva_nxt_st[3:0] = IVA_4K_WT;
//end
//IVA_2M_RD:
//begin
//  if(arb_tlboper_grant)
//    tlbiva_nxt_st[3:0] = IVA_2M_CMP;
//  else
//    tlbiva_nxt_st[3:0] = IVA_2M_RD;
//end
//IVA_2M_CMP:
//begin
//  if(jtlb_tlboper_cmplt)
//    if(jtlb_tlboper_va_hit)
//      tlbiva_nxt_st[3:0] = IVA_2M_WR;
//    else
//      tlbiva_nxt_st[3:0] = IVA_1G_RD;
//  else
//    tlbiva_nxt_st[3:0] = IVA_2M_CMP;
//end
//IVA_2M_WR:
//begin
//  if(arb_tlboper_grant)
//    tlbiva_nxt_st[3:0] = IVA_2M_WT;
//  else
//    tlbiva_nxt_st[3:0] = IVA_2M_WR;
//end
//IVA_2M_WT:
//begin
//  if(jtlb_tlboper_cmplt)
//    tlbiva_nxt_st[3:0] = IVA_1G_RD;
//  else
//    tlbiva_nxt_st[3:0] = IVA_2M_WT;
//end
//IVA_1G_RD:
//begin
//  if(arb_tlboper_grant)
//    tlbiva_nxt_st[3:0] = IVA_1G_CMP;
//  else
//    tlbiva_nxt_st[3:0] = IVA_1G_RD;
//end
//IVA_1G_CMP:
//begin
//  if(jtlb_tlboper_cmplt)
//    if(jtlb_tlboper_va_hit)
//      tlbiva_nxt_st[3:0] = IVA_1G_WR;
//    else
//      tlbiva_nxt_st[3:0] = IVA_CMPLT;
//  else
//    tlbiva_nxt_st[3:0] = IVA_1G_CMP;
//end
//IVA_1G_WR:
//begin
//  if(arb_tlboper_grant)
//    tlbiva_nxt_st[3:0] = IVA_1G_WT;
//  else
//    tlbiva_nxt_st[3:0] = IVA_1G_WR;
//end
//IVA_1G_WT:
//begin
//  if(jtlb_tlboper_cmplt)
//    tlbiva_nxt_st[3:0] = IVA_CMPLT;
//  else
//    tlbiva_nxt_st[3:0] = IVA_1G_WT;
//end
//IVA_CMPLT:
//begin
//  tlbiva_nxt_st[3:0] = IVA_IDLE;
//end
//default:
//begin
//  tlbiva_nxt_st[3:0] = IVA_IDLE;
//end
//endcase
//// &CombEnd; @580
//end

parameter IVA_IDLE   = 4'b0000,
          IVA_RD  = 4'b0010,
          IVA_CMP = 4'b0011,
          IVA_WR  = 4'b0100,
          IVA_WT  = 4'b0101,
          //IVA_2M_RD  = 4'b0110,
          //IVA_2M_CMP = 4'b0111,
          //IVA_2M_WR  = 4'b1000,
          //IVA_2M_WT  = 4'b1001,
          //IVA_1G_RD  = 4'b1010,
          //IVA_1G_CMP = 4'b1011,
          //IVA_1G_WR  = 4'b1100,
          //IVA_1G_WT  = 4'b1101,
          IVA_CMPLT  = 4'b1110;

always @(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlbiva_cur_st[3:0] <= IVA_IDLE;
  else
    tlbiva_cur_st[3:0] <= tlbiva_nxt_st[3:0];
end

assign tlb_inv_va = (lsu_mmu_tlb_va_all_inv || lsu_mmu_tlb_va_asid_inv)
                    && !lsu_oper_cmplt && tlb_sm_idle;

always_comb begin
case(tlbiva_cur_st)
IVA_IDLE:
begin
  if(tlb_inv_va)
    tlbiva_nxt_st[3:0] = IVA_RD;
  else
    tlbiva_nxt_st[3:0] = IVA_IDLE;
end
IVA_RD:
begin
  if(arb_tlboper_grant)
    tlbiva_nxt_st[3:0] = IVA_CMP;
  else
    tlbiva_nxt_st[3:0] = IVA_RD;
end
IVA_CMP:
begin
  if(jtlb_tlboper_cmplt)
    if(jtlb_tlboper_va_hit)
      tlbiva_nxt_st[3:0] = IVA_WR;
    else
      tlbiva_nxt_st[3:0] = IVA_CMPLT;
  else
    tlbiva_nxt_st[3:0] = IVA_CMP;
end
IVA_WR:
begin
  if(arb_tlboper_grant)
    tlbiva_nxt_st[3:0] = IVA_WT;
  else
    tlbiva_nxt_st[3:0] = IVA_WR;
end
IVA_WT:
begin
  if(jtlb_tlboper_cmplt)
    tlbiva_nxt_st[3:0] = IVA_CMPLT;
  else
    tlbiva_nxt_st[3:0] = IVA_WT;
end

IVA_CMPLT:
begin
  tlbiva_nxt_st[3:0] = IVA_IDLE;
end
default:
begin
  tlbiva_nxt_st[3:0] = IVA_IDLE;
end
endcase
// &CombEnd; @580
end

assign tlb_invva_rd_req = (tlbiva_cur_st[3:0] == IVA_RD);
assign tlb_invva_wt_req = (tlbiva_cur_st[3:0] == IVA_WR);

assign tlb_invva_req    = tlb_invva_rd_req || tlb_invva_wt_req; 

assign tlb_invva_cmplt  = (tlbiva_cur_st[3:0] == IVA_CMPLT);


//assign tlb_invva_rd_req = (tlbiva_cur_st[3:0] == IVA_4K_RD)
//                       || (tlbiva_cur_st[3:0] == IVA_2M_RD) 
//                       || (tlbiva_cur_st[3:0] == IVA_1G_RD);
//assign tlb_invva_wt_req = (tlbiva_cur_st[3:0] == IVA_4K_WR)
//                       || (tlbiva_cur_st[3:0] == IVA_2M_WR)
//                       || (tlbiva_cur_st[3:0] == IVA_1G_WR);
//assign tlb_invva_4k     = (tlbiva_cur_st[3:0] == IVA_4K_RD)
//                       || (tlbiva_cur_st[3:0] == IVA_4K_CMP)
//                       || (tlbiva_cur_st[3:0] == IVA_4K_WR);
//assign tlb_invva_2m     = (tlbiva_cur_st[3:0] == IVA_2M_RD) 
//                       || (tlbiva_cur_st[3:0] == IVA_2M_CMP)
//                       || (tlbiva_cur_st[3:0] == IVA_2M_WR);
//assign tlb_invva_1g     = (tlbiva_cur_st[3:0] == IVA_1G_RD) 
//                       || (tlbiva_cur_st[3:0] == IVA_1G_CMP)
//                       || (tlbiva_cur_st[3:0] == IVA_1G_WR); 

//assign tlb_invva_req    = tlb_invva_rd_req || tlb_invva_wt_req; 

//assign tlb_invva_cmplt  = (tlbiva_cur_st[3:0] == IVA_CMPLT);


//==============================================================================
//                  TLB oper Datapath
//==============================================================================
//==========================================================
//                  Inv Counter 
//==========================================================
assign tlb_inv_cnt_init = tlb_invasid_cnt_init|| tlb_invall_cnt_init ;
assign tlb_inv_cnt_dec  = tlb_invasid_cnt_dec || tlb_invall_cnt_dec;  
assign invall_cnt[10:0]  = 11'd255;
assign invasid_cnt[10:0] = 11'd255;

assign jtlb_cnt[10:0] = tlb_inv_all ? invall_cnt[10:0] : invasid_cnt[10:0]; 

always@(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlb_inv_cnt[10:0] <= 11'b0;
  else if(tlb_inv_cnt_init)
    tlb_inv_cnt[10:0] <= 11'b0;
  else if(tlb_inv_cnt_dec)
    tlb_inv_cnt[10:0] <= tlb_inv_cnt[10:0] + 1'b1;
  else
    tlb_inv_cnt[10:0] <= tlb_inv_cnt[10:0];
end

assign tlb_inv_done = (tlb_inv_cnt[10:0] == jtlb_cnt[10:0]);

//LSU CTC oper record
assign tlb_lsu_oper = lsu_mmu_tlb_asid_all_inv || lsu_mmu_tlb_all_inv
                   || lsu_mmu_tlb_va_all_inv   || lsu_mmu_tlb_va_asid_inv;
                       
assign tlb_sm_idle  = (tlbp_cur_st[1:0] == PIDLE)          && (tlbr_cur_st[1:0] == RIDLE)
                   && (tlbwi_cur_st[1:0] == WIIDLE)        && (tlbwr_cur_st[1:0] == WRIDLE)
                   && (tlbiasid_cur_st[2:0] == IASID_IDLE) && (tlbiall_cur_st == IALL_IDLE)
                   && (tlbiva_cur_st[3:0] == IVA_IDLE);

assign tlb_lsu_oper_cmplt = tlb_invasid_cmplt || tlb_invall_cmplt || tlb_invva_cmplt; 
always@(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    tlb_lsu_oper_flop <= 1'b0;
  else if(tlb_lsu_oper && tlb_sm_idle && !lsu_oper_cmplt)
    tlb_lsu_oper_flop <= 1'b1;
  else if(tlb_lsu_oper_flop && tlb_lsu_oper_cmplt)
    tlb_lsu_oper_flop <= 1'b0;
end

always@(posedge tlboper_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    lsu_oper_cmplt <= 1'b0;
  else if(tlb_lsu_oper_flop && tlb_lsu_oper_cmplt)
    lsu_oper_cmplt <= 1'b1;
  else if(lsu_oper_cmplt)
    lsu_oper_cmplt <= 1'b0;
end

//==========================================================
//                  jTLB Index & VPN(tag)
//==========================================================
assign tlboper_arb_req = tlb_tlbp_req    || tlb_tlbr_req
                      || tlb_tlbwi_req   || tlb_tlbwr_req
                      || tlb_invasid_req || tlb_invall_req || tlb_invva_req;

assign tlb_cnt_inv_on = (tlbiasid_cur_st[2:0] != IASID_IDLE)
                     || (tlbiall_cur_st  != IALL_IDLE);

//vpn
assign lsu_va_sel                     = (tlbiva_cur_st[3:0] != IVA_IDLE);
assign tlboper_arb_vpn[VPN_WIDTH-1:0] = lsu_va_sel ? lsu_mmu_tlb_va[VPN_WIDTH-1:0] 
                                                   : regs_tlboper_cur_vpn[VPN_WIDTH-1:0];

//index
// &Force("bus", "regs_tlboper_mir", 11, 0); @682
assign tlboper_idx_not_va[10:0] = tlb_cnt_inv_on ? tlb_inv_cnt[10:0]
                                                : regs_tlboper_mir[10:0];
assign tlboper_arb_idx[10:0]   = tlboper_idx_not_va[10:0];
assign tlboper_arb_idx_not_va  = tlb_tlbr_req    || tlb_tlbwi_req
                              || tlb_invasid_req || tlb_invall_req;
assign tlboper_arb_cmp_va      = tlb_tlbp_req
                              || tlb_invva_rd_req;

//pgs
//assign tlboper_xx_pgs_en      = (tlb_tlbp_req || tlbp_cur_st[1:0] != PIDLE
//                              || tlb_tlbwr_rd_req || tlbwr_cur_st[1:0] != WRIDLE);
                              //|| lsu_va_sel) && jtlb_tlboper_read_idle;
//assign tlboper_xx_pgs[2:0]    = lsu_va_sel ? {tlb_invva_1g, tlb_invva_2m, tlb_invva_4k}
//                                            : regs_tlboper_cur_pgs[2:0];

assign tlboper_xx_pgs[2:0]    = regs_tlboper_cur_pgs[2:0];
//bank sel for jtlb
assign idx_sel[WAY_NUM-1:0] = {{(WAY_NUM-1){1'b0}}, 1'b1} << tlboper_idx_not_va[10:8];


assign bank_sel_all = tlb_tlbp_req     || tlb_invall_req
                   || tlb_invva_rd_req || tlb_invasid_rd_req
                   || tlb_tlbwr_rd_req;

assign bank_sel_idx = tlb_tlbr_req     || tlb_tlbwi_req;

assign bank_sel_wr  = tlb_tlbwr_wt_req || tlb_invva_wt_req
                   || tlb_invasid_wt_req;

assign tlboper_arb_bank_sel[WAY_NUM-1:0] =
                                   ({WAY_NUM{bank_sel_all}} & {WAY_NUM{1'b1}})
                                 | ({WAY_NUM{bank_sel_idx}} & idx_sel[WAY_NUM-1:0])
                                 | ({WAY_NUM{bank_sel_wr }} & jtlb_tlboper_sel[WAY_NUM-1:0]);

//read or write
assign tlboper_arb_write      = tlb_tlbwi_req      || tlb_tlbwr_wt_req
                             || tlb_invasid_wt_req || tlb_invall_req 
                             || tlb_invva_wt_req;

//assign tlboper_arb_fifo_write = tlb_tlbwr_wt_req || tlb_invall_req;

//data into jtlb
// fifo bit
//assign tlboper_arb_fifo_din[3:0]  = tlb_invall_req ? 4'b0001 
//                                                   : {jtlb_tlboper_fifo[2:0], jtlb_tlboper_fifo[3]};

// when tlb inv, tag din and data din mask to zero
// tag din
assign tlb_tag_vld_in = tlb_tlbwi_req || tlb_tlbwr_wt_req;
assign tlb_vpn_aft_mask[VPN_WIDTH-1:0] = regs_tlboper_cur_vpn[VPN_WIDTH-1:0];

assign tlboper_tag_din[TAG_WIDTH-1:0]  = {tlb_tag_vld_in, tlb_vpn_aft_mask[VPN_WIDTH-1:0],
                                          regs_tlboper_cur_asid[ASID_WIDTH-1:0], 
                                          regs_tlboper_cur_pgs[PGS_WIDTH-1:0],
                                          regs_jtlb_cur_g}; 

assign tlboper_arb_tag_din[TAG_WIDTH-1:0] = {TAG_WIDTH{tlb_tag_vld_in}} & tlboper_tag_din[TAG_WIDTH-1:0];  

// data din
assign tlb_ppn_aft_mask[PPN_WIDTH-1:0] = regs_jtlb_cur_ppn[PPN_WIDTH-1:0];

assign tlboper_data_din[DATA_WIDTH-1:0] = {tlb_ppn_aft_mask[PPN_WIDTH-1:0], regs_jtlb_cur_flg[FLG_WIDTH-1:0]};

assign tlboper_arb_data_din[DATA_WIDTH-1:0] = {DATA_WIDTH{tlb_tag_vld_in}} & tlboper_data_din[DATA_WIDTH-1:0]; 

//control to jtbl directly
//for invva all by ctc oper
assign tlboper_jtlb_cmp_noasid   = lsu_mmu_tlb_va_all_inv  && tlb_lsu_oper_flop && (tlbiva_cur_st[3:0] != IVA_IDLE); //&& jtlb_tlboper_read_idle;
assign tlboper_jtlb_tlbwr_on     = (tlbwr_cur_st[1:0] != WRIDLE); //&& jtlb_tlboper_read_idle; skew associative tlb,1 cycle determine hit or miss,no fsm to lookup
assign tlboper_jtlb_invasid_on   = (tlbiasid_cur_st[2:0] != IASID_IDLE);
assign tlboper_jtlb_inv_asid[ASID_WIDTH-1:0] = regs_tlboper_invasid ? regs_tlboper_inv_asid[ASID_WIDTH-1:0]
                                                          : lsu_mmu_tlb_asid[ASID_WIDTH-1:0];
assign tlboper_jtlb_asid_sel             = ((tlbiva_cur_st[3:0] != IVA_IDLE)
					   || (tlbp_cur_st[1:0] != PIDLE));
                                        //&& jtlb_tlboper_read_idle;
assign tlboper_jtlb_asid[ASID_WIDTH-1:0] = (tlbiva_cur_st[3:0] != IVA_IDLE) ? 
                                        lsu_mmu_tlb_asid[ASID_WIDTH-1:0]:
                                   regs_tlboper_cur_asid[ASID_WIDTH-1:0];



//interface to regs
assign tlboper_regs_tlbr_cmplt = tlb_tlbr_cmplt;
assign tlboper_regs_tlbp_cmplt = tlb_tlbp_cmplt;
assign tlboper_cmplt           = tlb_tlbp_cmplt    || tlb_tlbr_cmplt
                              || tlb_tlbwi_cmplt   || tlb_tlbwr_cmplt
                              || tlb_invasid_cmplt || tlb_invall_cmplt
                              || tlb_invva_cmplt;
assign tlboper_xx_cmplt        = tlboper_cmplt;
assign tlboper_regs_cmplt      = tlboper_cmplt && !tlb_lsu_oper_flop; 


//when inv va jtlb, utlb will be inv if va hit
assign tlboper_utlb_inv_va_req  = tlb_invva_req;
//assign tlboper_utlb_inv_va[7:0] = lsu_mmu_tlb_va[7:0];
assign tlboper_utlb_clr         = tlb_tlbwi_req   || tlb_tlbwr_req
                               || tlb_invasid_req || tlb_invall_req;

assign tlboper_ptw_abort       = tlb_lsu_oper && !tlb_lsu_oper_flop;
//interface to LSU
assign mmu_lsu_tlb_inv_done = lsu_oper_cmplt;
assign mmu_cp0_tlb_done     = tlb_invall_cmplt;


// for dbg
assign tlboper_top_tlbp_cur_st[1:0]     = tlbp_cur_st[1:0];
assign tlboper_top_tlbr_cur_st[1:0]     = tlbr_cur_st[1:0];
assign tlboper_top_tlbwi_cur_st[1:0]    = tlbwi_cur_st[1:0];
assign tlboper_top_tlbwr_cur_st[1:0]    = tlbwr_cur_st[1:0];
assign tlboper_top_tlbiasid_cur_st[2:0] = tlbiasid_cur_st[2:0];
assign tlboper_top_tlbiall_cur_st       = tlbiall_cur_st;
assign tlboper_top_tlbiva_cur_st[3:0]   = tlbiva_cur_st[3:0];
assign tlboper_top_lsu_oper             = tlb_lsu_oper_flop;
assign tlboper_top_lsu_cmplt            = lsu_oper_cmplt;


// &ModuleEnd; @806
endmodule
