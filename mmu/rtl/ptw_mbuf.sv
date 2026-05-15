module ptw_mbuf #(
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
    parameter DATA_WIDTH  = 64,

// VPN width per level
    parameter VPN_PERLEL  = VPN_WIDTH/PTE_LEVEL,

// Valid + VPN + ASID + PageSize + Global
    parameter TAG_WIDTH   = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,
    parameter RDATA_WIDTH = PPN_WIDTH+FLG_WIDTH,
    parameter MBUF_ENTRY_NUM = 9
) (
//!******************************************
//! Clock and Reset
//!******************************************
    input  logic                        forever_cpuclk,
    input  logic                        cpurst_b,
    input  logic                        cp0_mmu_icg_en,
    input  logic                        pad_yy_icg_scan_en,

//!******************************************
//! TWU Request
//!******************************************
    input  logic [3:0]                  twu_mbuf_req,
    input  logic [3:0][PADDR_WIDTH-1:0] twu_mbuf_paddr,
    input  logic [3:0][VPN_WIDTH-1:0]   twu_mbuf_vpn,
    input  logic [3:0][TYPE_WIDTH-1:0]  twu_mbuf_type,
    input  logic [3:0][ID_WIDTH-1:0]    twu_mbuf_id,
    input  logic [3:0][PTE_LEVEL-1:0]   twu_mbuf_lvl,
    input  logic [3:0][3:0]             twu_mbuf_twu_idx,
    input  logic [3:0][4:0]             twu_mbuf_pmpflg,
//input logic	 [3:0]      twu_mbuf_mask,

//!******************************************
//! PTW <=> LSU
//!******************************************
    input  logic                        lsu_mmu_data_vld,
    input  logic [DATA_WIDTH-1:0]       lsu_mmu_data,
    input  logic                        lsu_mmu_bus_error,
		
    output logic                        mmu_lsu_data_req,
    output logic [PADDR_WIDTH-1:0]      mmu_lsu_data_req_addr,
    output logic                        mmu_lsu_data_req_size,
//!******************************************
//! Responce to TWU
//!******************************************
//output logic [3:0]		mbuf_twu_bus_error,
    output logic [VPN_WIDTH-1:0]        mbuf_twu_vpn,
    output logic [TYPE_WIDTH-1:0]       mbuf_twu_type,
    output logic [ID_WIDTH-1:0]         mbuf_twu_id,
    output logic [PTE_LEVEL-1:0]        mbuf_twu_lvl,
    output logic [DATA_WIDTH-1:0]       mbuf_twu_data,
    output logic [3:0]                  mbuf_twu_data_vld,

    output logic [3:0]                  mbuf_grant,
//output logic [3:0]		mbuf_twu_have,
//!******************************************
//! Refill to PDE Cache
//!******************************************
    output logic                        mbuf_cache_upd,
    output logic [PPN_WIDTH-1:0]        mbuf_cache_upd_ppn,
    output logic [PTE_LEVEL-2:0]        mbuf_cache_upd_lvl,
    output logic [VPN_WIDTH-1:0]        mbuf_cache_upd_vpn,
    output logic [4:0]                  mbuf_cache_upd_pmpflg,

    input  logic                        tlboper_ptw_abort,
    input  logic [3:0][PTE_LEVEL-1:0]   twu_data_ready,
    output logic                        mbuf_entry_on_vld,
    output logic                        mbuf_bus_error,
    output logic [TYPE_WIDTH-1:0]       mbuf_bus_error_type,
    output logic [ID_WIDTH-1:0]         mbuf_bus_error_id,
    input  logic                        acc_err_mbuf_grant

);

//==============================================================================
// Internal — control & TWU / MBUF update
//==============================================================================
logic                       mbuf_all_clr;
logic                       fst_twu_sel;
logic                       scd_twu_sel;
logic                       thd_twu_sel;
logic                       fth_twu_sel;
logic                       create_en;
logic                       fst_twu_itlb_sel;
logic                       scd_twu_itlb_sel;
logic                       thd_twu_itlb_sel;
logic                       fth_twu_itlb_sel;
logic                       twu_itlb_sel;
logic [3:0]                 mbuf_twu_idx;
logic [PADDR_WIDTH-1:0]    mbuf_upd_padder;
logic [VPN_WIDTH-1:0]      mbuf_upd_vpn;
logic [TYPE_WIDTH-1:0]     mbuf_upd_type;
logic [ID_WIDTH-1:0]       mbuf_upd_id;
logic [3:0]                mbuf_upd_twu_idx;
logic [PTE_LEVEL-1:0]      mbuf_upd_lvl;

//==============================================================================
// Internal — MBUF entry index / LSU cursor (width scales with MBUF_ENTRY_NUM)
//==============================================================================
logic [MBUF_ENTRY_NUM-2:0]  create_ptr;
logic [MBUF_ENTRY_NUM-1:0]  req_on_ptr;
logic [MBUF_ENTRY_NUM-2:0]  req_ptr;
// mbuf_ptr: alias for bind mmu_ptw_lsu_protocol_sva (.*); flops live in req_* / mbuf_ptr_one path
logic [MBUF_ENTRY_NUM-1:0]  mbuf_ptr;
logic [MBUF_ENTRY_NUM-1:0]  mbuf_entry_upd;
logic                       mbuf_entry_empty;
logic                       mbuf_entry_empty_reg;
logic                       lsu_mmu_data_vld_reg;

//logic	[8:0]		mask                                ;
//logic	[8:0]		point                               ;
//logic	[8:0]		mbuf_scan_high_table_mask           ;
//logic	[8:0]		mbuf_scan_bit_vec                   ;
//logic	[8:0]		mbuf_scan_high_table                ;
//logic	[8:0]		mbuf_priority_enc_high_table_lvl1   ;
//logic	[8:0]		mbuf_priority_enc_low_table_lvl1    ;
//logic	[8:0]		mbuf_priority_enc_high_table_lvl2   ;
//logic	[8:0]		mbuf_priority_enc_low_table_lvl2    ;
//logic		    	mbuf_in_high_table                  ;
//logic	      		mbuf_in_low_table                   ;
//logic	[8:0]		mbuf_ptr_nxt                        ;

//==============================================================================
// Internal — per-entry mbuf_entry bundle & write-back / bus-error arbiters
//==============================================================================
logic [MBUF_ENTRY_NUM-1:0]                  mmu_lsu_data_req_grant;
logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_vld;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_on;
logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0]   mbuf_entry_vpn;
logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0]  mbuf_entry_type;
logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0]    mbuf_entry_id;
logic [MBUF_ENTRY_NUM-1:0][3:0]             mbuf_entry_twu_idx;
logic [MBUF_ENTRY_NUM-1:0][PTE_LEVEL-1:0]   mbuf_entry_lvl;
//logic	[3:0]		 twu_have			;
//logic	[3:0]		mbuf_twu_idx			;
//logic	[6:0]		mbuf_twu_id			;
//logic   		mbuf_bus_error			;
//logic	[TYPE_WIDTH-1:0]		mbuf_bus_error_type		;
//logic	[5:0]		mbuf_bus_error_id		;
//logic	[8:0]		mask				;
logic [MBUF_ENTRY_NUM-1:0]                  write_back_grant;
logic [MBUF_ENTRY_NUM-1:0]                  write_back_req;
logic [MBUF_ENTRY_NUM-1:0][DATA_WIDTH-1:0]  mbuf_entry_data;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_ptr_one;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_bus_error_grant;
logic [MBUF_ENTRY_NUM-1:0]                  bus_err_write_back_req;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_get;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_bus_err_flop;

//==============================================================================
// Internal — TWU response merge / clock / PDE refill / LSU req sequencing
//==============================================================================
logic                       mbuf_entry_bus_err_req_mask;
logic [TYPE_WIDTH-1:0]      entry_bus_err_type;
logic [ID_WIDTH-1:0]        entry_bus_err_id;
logic                       mbuf_clk;
logic                       mbuf_clk_en;
logic                       pde_updata_data_vld;
logic [DATA_WIDTH-1:0]      pde_updata_data_flop;
logic [VPN_WIDTH-1:0]       pde_updata_vpn;
logic [PTE_LEVEL-1:0]       pde_updata_lvl;
logic [MBUF_ENTRY_NUM-1:0]  mmu_lsu_data_req_ptr;
logic [MBUF_ENTRY_NUM-1:0]  mbuf_ptr_one_reg;
logic                       mmu_lsu_data_req_fst_time;
logic                       tlboper_ptw_abort_reg;
//logic   [TYPE_WIDTH-1:0]	    mbuf_bus_error_type                 ;
logic [4:0]                 mbuf_upd_pmpflg;
logic [MBUF_ENTRY_NUM-1:0][4:0]                 mbuf_entry_pmpflg;
logic [4:0]                 pde_updata_pmpflg;
logic [4:0]                 mbuf_twu_pmpflg;

assign mbuf_clk_en = 1'b1; 
// &Instance("gated_clk_cell", "x_ptw_gateclk"); @59
gated_clk_cell  x_mbuf_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (mbuf_clk          ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (mbuf_clk_en       ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);


assign mmu_lsu_data_req_size =1'b1;

assign mbuf_all_clr = tlboper_ptw_abort;

assign mbuf_entry_on_vld = |mbuf_entry_on;



//always_comb begin
    // 
//    twu_have[0] = 1'b0;
//    twu_have[1] = 1'b0;
//    twu_have[2] = 1'b0;
//    twu_have[3] = 1'b0;
    
    // 
//    for(integer i = 0; i <= 8; i = i + 1) begin
//        if(mbuf_entry_twu_idx[i][3:0] == 4'b0001 && mbuf_entry_vld[i]) begin
//            twu_have[0] = 1'b1;
//        end
//        if(mbuf_entry_twu_idx[i][3:0] == 4'b0010 && mbuf_entry_vld[i]) begin
//            twu_have[1] = 1'b1;
//        end
//        if(mbuf_entry_twu_idx[i][3:0] == 4'b0100 && mbuf_entry_vld[i]) begin
//            twu_have[2] = 1'b1;
//        end
//        if(mbuf_entry_twu_idx[i][3:0] == 4'b1000 && mbuf_entry_vld[i]) begin
//            twu_have[3] = 1'b1;
//        end
 //   end
//end


//assign mbuf_twu_have[3:0] = twu_have[3:0];

//==============================================================================
//                  MBUF Upd Arbiter
//==============================================================================
assign fst_twu_itlb_sel = twu_mbuf_req[0] & (twu_mbuf_type[0][TYPE_WIDTH-1:0] == 3'b011);
assign scd_twu_itlb_sel = twu_mbuf_req[1] & (twu_mbuf_type[1][TYPE_WIDTH-1:0] == 3'b011);
assign thd_twu_itlb_sel = twu_mbuf_req[2] & (twu_mbuf_type[2][TYPE_WIDTH-1:0] == 3'b011);
assign fth_twu_itlb_sel = twu_mbuf_req[3] & (twu_mbuf_type[3][TYPE_WIDTH-1:0] == 3'b011);


assign twu_itlb_sel = fst_twu_itlb_sel | scd_twu_itlb_sel | thd_twu_itlb_sel | fth_twu_itlb_sel;
assign fth_twu_sel = (!twu_itlb_sel) & twu_mbuf_req[3];
assign thd_twu_sel = (!twu_itlb_sel) & (!twu_mbuf_req[3]) & twu_mbuf_req[2];
assign scd_twu_sel = (!twu_itlb_sel) & (!twu_mbuf_req[3]) & (!twu_mbuf_req[2]) & twu_mbuf_req[1];
assign fst_twu_sel = (!twu_itlb_sel) & (!twu_mbuf_req[3]) & (!twu_mbuf_req[2]) & (!twu_mbuf_req[1]) & twu_mbuf_req[0];

always_comb begin
    case({twu_itlb_sel,fth_twu_sel,thd_twu_sel,scd_twu_sel,fst_twu_sel})
        5'b1_0000 : mbuf_grant[3:0] = {fth_twu_itlb_sel,thd_twu_itlb_sel,scd_twu_itlb_sel,fst_twu_itlb_sel};
        5'b0_1000 : mbuf_grant[3:0] = 4'b1000;
        5'b0_0100 : mbuf_grant[3:0] = 4'b0100;
        5'b0_0010 : mbuf_grant[3:0] = 4'b0010;
        5'b0_0001 : mbuf_grant[3:0] = 4'b0001;
        default   : mbuf_grant[3:0] = 4'b0000;
    endcase
end


always_comb begin
	case(mbuf_grant[3:0])
		4'b1000	: begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = twu_mbuf_paddr[3][PADDR_WIDTH-1:0];
            mbuf_upd_vpn[VPN_WIDTH-1:0] = twu_mbuf_vpn[3][VPN_WIDTH-1:0];
            mbuf_upd_type[TYPE_WIDTH-1:0] = twu_mbuf_type[3][TYPE_WIDTH-1:0];
            mbuf_upd_id[ID_WIDTH-1:0] = twu_mbuf_id[3][ID_WIDTH-1:0];
            mbuf_upd_twu_idx[3:0] = twu_mbuf_twu_idx[3][3:0];
            mbuf_upd_lvl[PTE_LEVEL-1:0] = twu_mbuf_lvl[3][PTE_LEVEL-1:0];
            mbuf_upd_pmpflg[4:0] = twu_mbuf_pmpflg[3][4:0];
		end
		4'b0100 : begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = twu_mbuf_paddr[2][PADDR_WIDTH-1:0];
            mbuf_upd_vpn[VPN_WIDTH-1:0] = twu_mbuf_vpn[2][VPN_WIDTH-1:0];
            mbuf_upd_type[TYPE_WIDTH-1:0] = twu_mbuf_type[2][TYPE_WIDTH-1:0];
            mbuf_upd_id[ID_WIDTH-1:0] = twu_mbuf_id[2][ID_WIDTH-1:0];
            mbuf_upd_twu_idx[3:0] = twu_mbuf_twu_idx[2][3:0];
            mbuf_upd_lvl[PTE_LEVEL-1:0] = twu_mbuf_lvl[2][PTE_LEVEL-1:0];
            mbuf_upd_pmpflg[4:0] = twu_mbuf_pmpflg[2][4:0];
		end
		4'b0010 : begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = twu_mbuf_paddr[1][PADDR_WIDTH-1:0];
            mbuf_upd_vpn[VPN_WIDTH-1:0] = twu_mbuf_vpn[1][VPN_WIDTH-1:0];
            mbuf_upd_type[TYPE_WIDTH-1:0] = twu_mbuf_type[1][TYPE_WIDTH-1:0];
            mbuf_upd_id[ID_WIDTH-1:0] = twu_mbuf_id[1][ID_WIDTH-1:0];
            mbuf_upd_twu_idx[3:0] = twu_mbuf_twu_idx[1][3:0];
            mbuf_upd_lvl[PTE_LEVEL-1:0] = twu_mbuf_lvl[1][PTE_LEVEL-1:0];
            mbuf_upd_pmpflg[4:0] = twu_mbuf_pmpflg[1][4:0];
		end
		4'b0001 : begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = twu_mbuf_paddr[0][PADDR_WIDTH-1:0];
            mbuf_upd_vpn[VPN_WIDTH-1:0] = twu_mbuf_vpn[0][VPN_WIDTH-1:0];
            mbuf_upd_type[TYPE_WIDTH-1:0] = twu_mbuf_type[0][TYPE_WIDTH-1:0];
            mbuf_upd_id[ID_WIDTH-1:0] = twu_mbuf_id[0][ID_WIDTH-1:0];
            mbuf_upd_twu_idx[3:0] = twu_mbuf_twu_idx[0][3:0];
            mbuf_upd_lvl[PTE_LEVEL-1:0] = twu_mbuf_lvl[0][PTE_LEVEL-1:0];
            mbuf_upd_pmpflg[4:0] = twu_mbuf_pmpflg[0][4:0];
		end
		default : begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
            mbuf_upd_vpn[VPN_WIDTH-1:0] = {VPN_WIDTH{1'b0}};
            mbuf_upd_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
            mbuf_upd_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
            mbuf_upd_twu_idx[3:0] = 4'b0;
            mbuf_upd_lvl[PTE_LEVEL-1:0] = {PTE_LEVEL{1'b0}};
            mbuf_upd_pmpflg[4:0] = 5'b0;
		end
	endcase
end


//always_comb begin
//	mbuf_entry_upd[8:0] = 9'b0000_0000;
//	if(twu_itlb_sel)begin
//		mbuf_entry_upd[8:0] = 9'b1_0000_0000;
//	end else if(|twu_mbuf_req[3:0])begin
//		casez(mbuf_entry_vld[7:0])
//			8'b???????0	:	mbuf_entry_upd[8:0] = 9'b0_0000_0001;
//			8'b??????01	:	mbuf_entry_upd[8:0] = 9'b0_0000_0010;
//			8'b?????011	:	mbuf_entry_upd[8:0] = 9'b0_0000_0100;
//			8'b????0111	:	mbuf_entry_upd[8:0] = 9'b0_0000_1000;
//			8'b???01111	:	mbuf_entry_upd[8:0] = 9'b0_0001_0000;
//			8'b??011111	:	mbuf_entry_upd[8:0] = 9'b0_0010_0000;
//			8'b?0111111	:	mbuf_entry_upd[8:0] = 9'b0_0100_0000;
//			8'b01111111	:	mbuf_entry_upd[8:0] = 9'b0_1000_0000;
//			default		:	mbuf_entry_upd[8:0] = 9'b0_0000_0000;
//		endcase 
//	end
//end

assign create_en = |twu_mbuf_req[3:0] & (!twu_itlb_sel) & (!tlboper_ptw_abort);

always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    create_ptr[MBUF_ENTRY_NUM-2:0] <= {{(MBUF_ENTRY_NUM-2){1'b0}}, 1'b1};
  else if (create_en)
    create_ptr[MBUF_ENTRY_NUM-2:0] <= {create_ptr[MBUF_ENTRY_NUM-3:0],create_ptr[MBUF_ENTRY_NUM-2]};
end
assign mbuf_entry_upd[MBUF_ENTRY_NUM-2:0] = {MBUF_ENTRY_NUM-1{create_en}} & create_ptr[MBUF_ENTRY_NUM-2:0];

assign mbuf_entry_upd[MBUF_ENTRY_NUM-1] = twu_itlb_sel & (!tlboper_ptw_abort);


//==============================================================================
//                  Req to LSU
//==============================================================================

assign mmu_lsu_data_req = (|(mbuf_entry_vld[MBUF_ENTRY_NUM-1:0] & (~mbuf_entry_get[MBUF_ENTRY_NUM-1:0]) & (~mbuf_entry_bus_err_flop[MBUF_ENTRY_NUM-1:0]))) & !(mmu_lsu_data_req_fst_time & tlboper_ptw_abort) | tlboper_ptw_abort_reg ;



always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    tlboper_ptw_abort_reg <= 1'b0;
  else if(tlboper_ptw_abort & (!mmu_lsu_data_req_fst_time) & (!lsu_mmu_data_vld))
    tlboper_ptw_abort_reg <= 1'b1;
  else if(lsu_mmu_data_vld)
    tlboper_ptw_abort_reg <= 1'b0;
end


assign req_on_ptr[MBUF_ENTRY_NUM-1] = mbuf_entry_vld[MBUF_ENTRY_NUM-1] & (~mbuf_entry_get[MBUF_ENTRY_NUM-1]) & (~mbuf_entry_bus_err_flop[MBUF_ENTRY_NUM-1]);

always@(posedge mbuf_clk or negedge cpurst_b)
begin
     if (!cpurst_b)
        req_ptr[MBUF_ENTRY_NUM-2:0] <= {{(MBUF_ENTRY_NUM-2){1'b0}}, 1'b1};
    else if((mmu_lsu_data_req_fst_time | lsu_mmu_data_vld) & tlboper_ptw_abort | tlboper_ptw_abort_reg & lsu_mmu_data_vld)
        req_ptr[MBUF_ENTRY_NUM-2:0] <= create_ptr[MBUF_ENTRY_NUM-2:0];
    else if (lsu_mmu_data_vld & (~req_on_ptr[MBUF_ENTRY_NUM-1]))
        req_ptr[MBUF_ENTRY_NUM-2:0] <= {req_ptr[MBUF_ENTRY_NUM-3:0], req_ptr[MBUF_ENTRY_NUM-2]};
end

assign req_on_ptr[MBUF_ENTRY_NUM-2:0] = {MBUF_ENTRY_NUM-1{~req_on_ptr[MBUF_ENTRY_NUM-1]}} & req_ptr[MBUF_ENTRY_NUM-2:0];

assign mbuf_ptr = req_on_ptr;


assign mmu_lsu_data_req_fst_time = (lsu_mmu_data_vld_reg & mmu_lsu_data_req) | (mbuf_entry_empty_reg & mmu_lsu_data_req);

always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    mbuf_ptr_one_reg[MBUF_ENTRY_NUM-1:0] <= {MBUF_ENTRY_NUM{1'b0}};
  else if (mmu_lsu_data_req_fst_time)
    mbuf_ptr_one_reg[MBUF_ENTRY_NUM-1:0] <= req_on_ptr[MBUF_ENTRY_NUM-1:0];
end

assign mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0] = mmu_lsu_data_req_fst_time ? req_on_ptr[MBUF_ENTRY_NUM-1:0] : mbuf_ptr_one_reg[MBUF_ENTRY_NUM-1:0];


always_comb begin
    mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
	for(int i = 0; i < MBUF_ENTRY_NUM; i = i + 1) begin
		if(mmu_lsu_data_req_ptr[i])begin
		mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[i];
	    end
    end
end

assign mbuf_entry_empty = ~mmu_lsu_data_req;

always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
	if(!cpurst_b)
		mbuf_entry_empty_reg <= 1'b0;
	else 
		mbuf_entry_empty_reg <= mbuf_entry_empty;
end

always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
	if(!cpurst_b)
		lsu_mmu_data_vld_reg <= 1'b0;
	else
		lsu_mmu_data_vld_reg <= lsu_mmu_data_vld;
end
always_comb begin
    if(mmu_lsu_data_req_fst_time) begin
        mbuf_ptr_one[MBUF_ENTRY_NUM-1:0] = req_on_ptr[MBUF_ENTRY_NUM-1:0];
    end else begin
        mbuf_ptr_one[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{1'b0}};
    end
end

assign mmu_lsu_data_req_grant[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{mmu_lsu_data_req & (!tlboper_ptw_abort)}} & mbuf_ptr_one[MBUF_ENTRY_NUM-1:0];

////generate
////	genvar i;
////	for(genvar i=0; i <= 8; i=i+1)begin:mask0_8
////		assign mask[i] = (|(twu_mbuf_mask[3:0] & mbuf_entry_twu_idx[i][3:0])) & mbuf_entry_vld[i];
////	end
////endgenerate
//
//
//
//always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
//	if(!cpurst_b)
//		point[7:0] <= 8'b0000_0001;
//	else if(lsu_mmu_data_vld & (!mbuf_entry_on[8]))
//		point[7:0] <= {mbuf_ptr[6:0],mbuf_ptr[7]};
//end
//
//assign mbuf_scan_bit_vec[7:0] = mbuf_entry_vld[7:0] & (~mbuf_entry_get[8:0]) & (~mbuf_entry_bus_err_flop[8:0]);
//
//generate
//    genvar i;
//    assign mbuf_scan_high_table_mask[0] = ~point[0];
//    for (i=1; i < 8; i=i+1) begin
//        assign mbuf_scan_high_table_mask[i] = mbuf_scan_high_table_mask[i-1] & ~point[i];  
//    end
//
//    for (i=0; i < 8; i=i+1) begin 
//        assign mbuf_scan_high_table[i] =  ~mbuf_scan_bit_vec[i] | mbuf_scan_high_table_mask[i];  
//    end
//
//    assign mbuf_priority_enc_high_table_lvl1[0] = mbuf_scan_high_table[0];
//    assign mbuf_priority_enc_low_table_lvl1[0] = ~mbuf_scan_bit_vec[0];
//    for (i=1; i < 8; i=i+1) begin : priority_enc_tables_lvl1
//        //! Thermometer encode
//        assign mbuf_priority_enc_high_table_lvl1[i] =   mbuf_priority_enc_high_table_lvl1[i-1] 
//                                                            & mbuf_scan_high_table[i];
//        //! Thermometer encode
//        assign mbuf_priority_enc_low_table_lvl1[i] =   mbuf_priority_enc_low_table_lvl1[i-1] 
//                                                           & mbuf_scan_bit_vec[i];
//    end
//
//    assign mbuf_priority_enc_high_table_lvl2[0] = ~mbuf_priority_enc_high_table_lvl1[0];
//    assign mbuf_priority_enc_low_table_lvl2[0]  = ~mbuf_priority_enc_low_table_lvl1[0]; 
//
//    for (i=1; i < 8; i=i+1) begin : priority_enc_tables_lvl2
//        assign mbuf_priority_enc_high_table_lvl2[i] =   ~mbuf_priority_enc_high_table_lvl1[i] 
//                                                            & mbuf_priority_enc_high_table_lvl1[i-1];
//        assign mbuf_priority_enc_low_table_lvl2[i] =   ~mbuf_priority_enc_low_table_lvl1[i] 
//                                                           & mbuf_priority_enc_low_table_lvl1[i-1];
//    end
//endgenerate
//
//assign mbuf_in_high_table = ~(&mbuf_scan_high_table[7:0]);
//assign mbuf_in_low_table  = ~mbuf_in_high_table & (~(&mbuf_priority_enc_low_table_lvl1[7:0]));
//
//
//assign mbuf_entry_itlb_sel_vld = mbuf_entry_vld[8];
//
////assign mbuf_entry_itlb_sel_vld = |mbuf_entry0_itlb_sel[7:0];
//
//always_comb begin
//    if((lsu_mmu_data_vld_reg & mmu_lsu_data_req) |
//       (mbuf_entry_empty_reg & mmu_lsu_data_req)) begin
//		if(mbuf_entry_itlb_sel_vld)begin
//			mbuf_ptr_nxt[8:0] = 9'b1_0000_0000;
//		end else begin
//			case({mbuf_in_high_table, mbuf_in_low_table})
//				2'b00: mbuf_ptr_nxt[8:0] = {1'b0,point[7:0]};
//				2'b01: mbuf_ptr_nxt[8:0] = {1'b0,mbuf_priority_enc_low_table_lvl2[7:0]};
//				2'b1?: mbuf_ptr_nxt[8:0] = {1'b0,mbuf_priority_enc_high_table_lvl2[7:0]};
//				default: mbuf_ptr_nxt[8:0] = {1'b0,point[7:0]};    
//			endcase
//		end
//    end else begin
//        mbuf_ptr_nxt[8:0] = mbuf_ptr[8:0];
//    end
//end
//
//always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
//    if(!cpurst_b)
//        mbuf_ptr[8:0] <= 9'b0;
//    else
//        mbuf_ptr[8:0] <= mbuf_ptr_nxt[8:0];
//end
//
//always_comb begin
//    if((lsu_mmu_data_vld_reg & mmu_lsu_data_req) |
//       (mbuf_entry_empty_reg & mmu_lsu_data_req)) begin
//        mbuf_ptr_one[8:0] = mbuf_ptr_nxt[8:0];
//    end else begin
//        mbuf_ptr_one[8:0] = 9'b0_0000_0000;
//    end
//end
//
//always_comb begin
//	case(mbuf_ptr_nxt[8:0])
//		9'b0_0000_0001	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[0][PADDR_WIDTH-1:0];
//		9'b0_0000_0010	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[1][PADDR_WIDTH-1:0];
//		9'b0_0000_0100	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[2][PADDR_WIDTH-1:0];
//		9'b0_0000_1000	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[3][PADDR_WIDTH-1:0];
//		9'b0_0001_0000	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[4][PADDR_WIDTH-1:0];
//		9'b0_0010_0000	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[5][PADDR_WIDTH-1:0];
//		9'b0_0100_0000	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[6][PADDR_WIDTH-1:0];
//		9'b0_1000_0000	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[7][PADDR_WIDTH-1:0];
//		9'b1_0000_0000	:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[8][PADDR_WIDTH-1:0];
//		default			:	mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
//	endcase 
//end



//assign mmu_lsu_data_req_grant[8:0] = {9{mmu_lsu_data_req}} & mbuf_ptr_one[8:0];


//==============================================================================
//                  DFF
//==============================================================================
//MBUF
generate
	for(genvar MBUF_ent = 0;MBUF_ent < MBUF_ENTRY_NUM;MBUF_ent = MBUF_ent + 1)begin:u_MBUF_ent_0_8
		mbuf_entry #(
			.VADDR_WIDTH                (VADDR_WIDTH                             ),
			.PADDR_WIDTH                (PADDR_WIDTH                             ),
			.VPN_WIDTH                  (VPN_WIDTH                               ),
			.PPN_WIDTH                  (PPN_WIDTH                               ),
			.FLG_WIDTH                  (FLG_WIDTH                               ),
			.ASID_WIDTH                 (ASID_WIDTH                              ),
			.PGS_WIDTH                  (PGS_WIDTH                               ),
			.PTE_LEVEL                  (PTE_LEVEL                               ),
			.TYPE_WIDTH                 (TYPE_WIDTH                              )
		) mbuf_entry_x(
			.forever_cpuclk				(forever_cpuclk					 			 ),
			.cpurst_b					(cpurst_b						 			 ),
            .cp0_mmu_icg_en             (cp0_mmu_icg_en                              ),
            .pad_yy_icg_scan_en         (pad_yy_icg_scan_en                          ),
																					 
			.mbuf_all_clr				(mbuf_all_clr					 			 ),
			.lsu_mmu_data_vld			(lsu_mmu_data_vld				 			 ),
			.lsu_mmu_data               (lsu_mmu_data[DATA_WIDTH-1:0]                ),
            .mmu_lsu_data_req_grant		(mmu_lsu_data_req_grant[MBUF_ent]			 ),
			.lsu_mmu_bus_error			(lsu_mmu_bus_error							 ),
			.mbuf_entry_upd				(mbuf_entry_upd[MBUF_ent]		 			 ),
			.mbuf_upd_padder			(mbuf_upd_padder[PADDR_WIDTH-1:0]			 ),
			.mbuf_upd_vpn				(mbuf_upd_vpn[VPN_WIDTH-1:0]				 ),
			.mbuf_upd_type				(mbuf_upd_type[TYPE_WIDTH-1:0]			 	 ),
			.mbuf_upd_id				(mbuf_upd_id[ID_WIDTH-1:0]					 ),
			.mbuf_upd_twu_idx			(mbuf_upd_twu_idx[3:0]				 		 ),
			.mbuf_upd_lvl				(mbuf_upd_lvl[PTE_LEVEL-1:0]				 ),
			.mbuf_upd_pmpflg			(mbuf_upd_pmpflg[4:0]					 	 ),
			.twu_data_ready             (twu_data_ready                              ),
            .write_back_grant           (write_back_grant[MBUF_ent]                  ),
            .mbuf_entry_bus_err_req_mask(mbuf_entry_bus_err_req_mask                 ),
            .mbuf_bus_error_grant       (mbuf_bus_error_grant[MBUF_ent]              ),

            .write_back_req             (write_back_req[MBUF_ent]                    ),
            .bus_err_write_back_req     (bus_err_write_back_req[MBUF_ent]            ),
			.mbuf_entry_padder			(mbuf_entry_padder[MBUF_ent]                 ),
			.mbuf_entry_vld				(mbuf_entry_vld[MBUF_ent]                    ),
			.mbuf_entry_on				(mbuf_entry_on[MBUF_ent]                     ),
			.mbuf_entry_vpn				(mbuf_entry_vpn[MBUF_ent]                    ),
			.mbuf_entry_type			(mbuf_entry_type[MBUF_ent]                   ),
			.mbuf_entry_id				(mbuf_entry_id[MBUF_ent]                     ),
			.mbuf_entry_twu_idx			(mbuf_entry_twu_idx[MBUF_ent]                ),
			.mbuf_entry_lvl             (mbuf_entry_lvl[MBUF_ent]                    ),
			.mbuf_entry_pmpflg			(mbuf_entry_pmpflg[MBUF_ent]				 ),
            .mbuf_entry_data            (mbuf_entry_data[MBUF_ent]                   ),
            .mbuf_entry_get             (mbuf_entry_get[MBUF_ent]                    ),
            .mbuf_entry_bus_err_flop     (mbuf_entry_bus_err_flop[MBUF_ent]          )
		);

	end
endgenerate

//==============================================================================
//                 Responce to TWU
//==============================================================================



// Fixed-priority onehot grant: highest index (MBUF_ENTRY_NUM-1) wins first (same as legacy casez).
// While |grant| is still zero, only the first hit from high index downward can set a bit.
always_comb begin
    write_back_grant = {MBUF_ENTRY_NUM{1'b0}};
    for (int wb_i = MBUF_ENTRY_NUM - 1; wb_i >= 0; wb_i--) begin
        if (write_back_req[wb_i] && !(|write_back_grant[MBUF_ENTRY_NUM-1:0]))
            write_back_grant[wb_i] = 1'b1;
    end
end

assign mbuf_twu_data_vld[3:0] = {4{|write_back_grant[MBUF_ENTRY_NUM-1:0]}} & mbuf_twu_idx[3:0];
//assign mbuf_twu_bus_error[3:0] = {4{lsu_mmu_bus_error}} & mbuf_twu_idx[3:0];

always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
	if(!cpurst_b)begin
	    mbuf_bus_error_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
	    mbuf_bus_error_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
	end else if(|mbuf_bus_error_grant[MBUF_ENTRY_NUM-1:0])begin
	    mbuf_bus_error_type[TYPE_WIDTH-1:0] <= entry_bus_err_type[TYPE_WIDTH-1:0];
	    mbuf_bus_error_id[ID_WIDTH-1:0] <= entry_bus_err_id[ID_WIDTH-1:0];  
    end
end
	
always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
	if(!cpurst_b)begin
	    mbuf_bus_error <= 1'b0;
	end else if(tlboper_ptw_abort)
        mbuf_bus_error <= 1'b0;
    else if(|mbuf_bus_error_grant[MBUF_ENTRY_NUM-1:0])begin
        mbuf_bus_error <= 1'b1;
    end else if(acc_err_mbuf_grant)begin
        mbuf_bus_error <= 1'b0;
    end
end

// Same priority order as write_back_grant (highest entry index first); uses !(|grant) gating only.
always_comb begin
    mbuf_bus_error_grant = {MBUF_ENTRY_NUM{1'b0}};
    for (int be_i = MBUF_ENTRY_NUM - 1; be_i >= 0; be_i--) begin
        if (bus_err_write_back_req[be_i] && !(|mbuf_bus_error_grant[MBUF_ENTRY_NUM-1:0]))
            mbuf_bus_error_grant[be_i] = 1'b1;
    end
end


assign mbuf_entry_bus_err_req_mask = mbuf_bus_error & (!acc_err_mbuf_grant);

always_comb begin
	entry_bus_err_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
	entry_bus_err_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
    for (int i = 0; i < MBUF_ENTRY_NUM; i++) begin
        if(mbuf_bus_error_grant[i])begin
			entry_bus_err_type[TYPE_WIDTH-1:0] = mbuf_entry_type[i];
			entry_bus_err_id[ID_WIDTH-1:0] = mbuf_entry_id[i];
        end
    end
end


always_comb begin
	mbuf_twu_vpn[VPN_WIDTH-1:0] = {VPN_WIDTH{1'b0}};
	mbuf_twu_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
	mbuf_twu_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
	mbuf_twu_idx[3:0] = 4'b0;
	mbuf_twu_lvl[PTE_LEVEL-1:0] = {PTE_LEVEL{1'b0}};
    mbuf_twu_data[DATA_WIDTH-1:0] = {DATA_WIDTH{1'b0}};
    for (int i = 0; i < MBUF_ENTRY_NUM; i++) begin
        if(write_back_grant[i])begin
			mbuf_twu_vpn[VPN_WIDTH-1:0] = mbuf_entry_vpn[i];
			mbuf_twu_type[TYPE_WIDTH-1:0] = mbuf_entry_type[i];
			mbuf_twu_id[ID_WIDTH-1:0] = mbuf_entry_id[i];
			mbuf_twu_idx[3:0] = mbuf_entry_twu_idx[i];
			mbuf_twu_lvl[PTE_LEVEL-1:0] = mbuf_entry_lvl[i];
			mbuf_twu_pmpflg[4:0] = mbuf_entry_pmpflg[i];
            mbuf_twu_data[DATA_WIDTH-1:0] = mbuf_entry_data[i];
        end
    end
end


//==============================================================================
//                  Refill to PDE Cache
//==============================================================================
always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        pde_updata_data_vld <= 1'b0;
    else if(|write_back_grant[MBUF_ENTRY_NUM-1:0] & (tlboper_ptw_abort))
        pde_updata_data_vld <= 1'b1;
    else 
        pde_updata_data_vld <= 1'b0;
end

always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b) begin
        pde_updata_data_flop[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
        pde_updata_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
        pde_updata_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
    end else if(|write_back_grant[MBUF_ENTRY_NUM-1:0]) begin
        pde_updata_data_flop[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
        pde_updata_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
        pde_updata_lvl[PTE_LEVEL-1:0] <= mbuf_twu_lvl[PTE_LEVEL-1:0];
        pde_updata_pmpflg[4:0] <= mbuf_twu_pmpflg[4:0];
    end
end

// 只有同时满足下列条件的 PTE 才能回填 PDE Cache:
//   - pde_updata_data_vld      : 本拍 PTE 数据有效
//   - pde_updata_data_flop[0] = V=1 : 表项有效
//   - pde_updata_data_flop[1] = R=0 且 pde_updata_data_flop[3] = X=0  -> 非叶子 (中间级 PDE)
//   - pde_updata_data_flop[2] = W=0                          -> 非只读/非 write-only 保留编码
//   - pde_updata_lvl[0]     = 0                            -> 当前不是第 3 级 PTW 检查
//                                                       (最后一级不应再作为 PDE 缓存)
assign mbuf_cache_upd = pde_updata_data_vld
                      & pde_updata_data_flop[0]                    // V = 1
                      & (!(pde_updata_data_flop[1] | pde_updata_data_flop[3]      // R=0 且 X=0 -> 非叶子
                           | pde_updata_data_flop[2] | pde_updata_lvl[0]));       // W=0 且 非第 3 级 PTW 检查

assign mbuf_cache_upd_ppn[PPN_WIDTH-1:0] = pde_updata_data_flop[PPN_WIDTH+9:10];
assign mbuf_cache_upd_lvl[PTE_LEVEL-2:0] = pde_updata_lvl[PTE_LEVEL-1:1];
assign mbuf_cache_upd_vpn[VPN_WIDTH-1:0] = pde_updata_vpn[VPN_WIDTH-1:0];
assign mbuf_cache_upd_pmpflg[4:0] = pde_updata_pmpflg[4:0];








endmodule



