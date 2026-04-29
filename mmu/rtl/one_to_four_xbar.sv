module  one_to_four_xbar(
//!******************************************
//! Clock and Reset
//!******************************************
input  logic 			forever_cpuclk,
input  logic 			cpurst_b,
			
//!******************************************
//! TWU Request
//!******************************************
//input  logic [3:0]		twu_idle,
input  logic [3:0]		twu_mask,
			
//!******************************************
//! PDE Cache Request
//!******************************************
input  logic 			PDE_xbar_req,
input  logic 			L2PDE_xbar_hit_vld,
input  logic 			L1PDE_xbar_hit_vld,
input  logic [27:0]		PDE_xbar_ppn,
input  logic [26:0]		PDE_xbar_vpn,
input  logic [2:0]		PDE_xbar_type,
input  logic [5:0]		PDE_xbar_id,
			
//!******************************************
//! xbar to TWU
//!******************************************
output logic [3:0]		xbar_twu_req,
output logic [1:0]		xbar_twu_hit_level,
output logic [27:0]		xbar_twu_ppn,
output logic [26:0]		xbar_twu_vpn,
output logic [2:0]		xbar_twu_type,
output logic [5:0]		xbar_twu_id,

input  logic			tlboper_ptw_abort,
output logic 			xbar_pde_ready

);

//logic	[3:0]		twu_idle_req;
//logic	[3:0]		twu_req_point_r;
//logic				no_twu_idle;
//logic	[3:0]		xbar_scan_bit_vec;
//logic	[3:0]		xbar_scan_high_table_mask;
//logic	[3:0]		xbar_scan_high_table;
//logic	[3:0]		xbar_priority_enc_high_table_lvl1;
//logic	[3:0]		xbar_priority_enc_high_table_lvl2;
//logic	[3:0]		xbar_priority_enc_low_table_lvl1;
//logic	[3:0]		xbar_priority_enc_low_table_lvl2;
//logic				xbar_in_high_table;
//logic				xbar_in_low_table;
//logic	[3:0]		xbar_ptr_nxt;
logic	[3:0]		twu_req;
//logic				xbar_req;


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


logic twu_xbar_mask;
logic [3:0] twu_req_hash;
//assign twu_ready = ~(&twu_mask[3:0]);	
assign twu_xbar_mask = |({4{PDE_xbar_req}} & twu_req_hash[3:0] & twu_mask[3:0]);
assign xbar_pde_ready = ~twu_xbar_mask;

logic [1:0] twu_hash;
assign twu_hash[1:0] =
    PDE_xbar_vpn[1:0]   ^
    PDE_xbar_vpn[10:9]  ^
    PDE_xbar_vpn[19:18] ^
    PDE_xbar_vpn[26:25];


always_comb begin
    unique case (twu_hash[1:0])
        2'b00: twu_req_hash[3:0] = 4'b0001;
        2'b01: twu_req_hash[3:0] = 4'b0010;
        2'b10: twu_req_hash[3:0] = 4'b0100;
        2'b11: twu_req_hash[3:0] = 4'b1000;
        default: twu_req_hash[3:0] = 4'b0000;
    endcase
end

assign twu_req[3:0] = {4{PDE_xbar_req & (!twu_xbar_mask)}} & twu_req_hash[3:0];
assign xbar_twu_req[3:0] = twu_req[3:0];




assign xbar_twu_hit_level[1:0] = {L1PDE_xbar_hit_vld,L2PDE_xbar_hit_vld};
assign xbar_twu_ppn[PPN_WIDTH-1:0] = PDE_xbar_ppn[PPN_WIDTH-1:0];
assign xbar_twu_vpn[VPN_WIDTH-1:0] = PDE_xbar_vpn[VPN_WIDTH-1:0];
assign xbar_twu_type[2:0] = PDE_xbar_type[2:0];
assign xbar_twu_id[ID_WIDTH-1:0] = PDE_xbar_id[ID_WIDTH-1:0];


//!******************************************
//! Find idle TWU
//!******************************************
//always_comb begin
//	casez(twu_idle[3:0])
//		4'b???1:twu_idle_req[3:0] = 4'b0001;
//		4'b??10:twu_idle_req[3:0] = 4'b0010;
//		4'b?100:twu_idle_req[3:0] = 4'b0100;
//		4'b1000:twu_idle_req[3:0] = 4'b1000;
//		default:twu_idle_req[3:0] = 4'b0000;
//    endcase
//end
//!******************************************
//! scane TWU
//!******************************************
//always_ff @(posedge forever_cpuclk or negedge cpurst_b)begin
//	if(!cpurst_b)
//		twu_req_point_r[3:0] <= 4'b0001;
//	else if(PDE_xbar_req & twu_ready)
//		twu_req_point_r[3:0] <= {twu_req[2:0],twu_req[3]};
//end

//assign no_twu_idle  = ~(|twu_idle[3:0]);

//assign xbar_scan_bit_vec[3:0] = twu_mask[3:0];
//
//generate
//    genvar i;
//    assign xbar_scan_high_table_mask[0] = ~twu_req_point_r[0];
//    for (i=1; i < 4; i=i+1) begin
//        assign xbar_scan_high_table_mask[i] = xbar_scan_high_table_mask[i-1] & ~twu_req_point_r[i];  
//    end
//
//    for (i=0; i < 4; i=i+1) begin 
//        assign xbar_scan_high_table[i] =  xbar_scan_bit_vec[i] | xbar_scan_high_table_mask[i];  
//    end
//
//    assign xbar_priority_enc_high_table_lvl1[0] = xbar_scan_high_table[0];
//    assign xbar_priority_enc_low_table_lvl1[0] = xbar_scan_bit_vec[0];
//    for (i=1; i < 4; i=i+1) begin : priority_enc_tables_lvl1
//        //! Thermometer encode
//        assign xbar_priority_enc_high_table_lvl1[i] =   xbar_priority_enc_high_table_lvl1[i-1] 
//                                                            & xbar_scan_high_table[i];
//        //! Thermometer encode
//        assign xbar_priority_enc_low_table_lvl1[i] =   xbar_priority_enc_low_table_lvl1[i-1] 
//                                                           & xbar_scan_bit_vec[i];
//    end
//
//    assign xbar_priority_enc_high_table_lvl2[0] = ~xbar_priority_enc_high_table_lvl1[0];
//    assign xbar_priority_enc_low_table_lvl2[0]  = ~xbar_priority_enc_low_table_lvl1[0]; 
//
//    for (i=1; i < 4; i=i+1) begin : priority_enc_tables_lvl2
//        assign xbar_priority_enc_high_table_lvl2[i] =   ~xbar_priority_enc_high_table_lvl1[i] 
//                                                            & xbar_priority_enc_high_table_lvl1[i-1];
//        assign xbar_priority_enc_low_table_lvl2[i] =   ~xbar_priority_enc_low_table_lvl1[i] 
//                                                           & xbar_priority_enc_low_table_lvl1[i-1];
//    end
//endgenerate
//
//assign xbar_in_high_table = ~(&xbar_scan_high_table[3:0]);
//assign xbar_in_low_table  = ~xbar_in_high_table & (~(&xbar_priority_enc_low_table_lvl1[3:0]));
//
//always_comb begin
//    xbar_ptr_nxt[3:0] = twu_req_point_r[3:0];
//    if(PDE_xbar_req & twu_ready) begin
//        case({xbar_in_high_table, xbar_in_low_table})
//            2'b00: xbar_ptr_nxt[3:0] = twu_req_point_r[3:0];
//            2'b01: xbar_ptr_nxt[3:0] = xbar_priority_enc_low_table_lvl2[3:0];
//            2'b1?: xbar_ptr_nxt[3:0] = xbar_priority_enc_high_table_lvl2[3:0];
//            default: xbar_ptr_nxt[3:0] = twu_req_point_r[3:0];    
//        endcase
//    end
//end
//
//assign twu_req[3:0] = no_twu_idle ? xbar_ptr_nxt[3:0] : twu_idle_req[3:0];
//
//
//always_comb begin
//	if(tlboper_ptw_abort)
//		xbar_twu_req[3:0] = 4'b0000;
//    else if(PDE_xbar_req & twu_ready)
//		xbar_twu_req[3:0] = twu_req[3:0];
//	else 
//		xbar_twu_req[3:0] = 4'b0000;
//end	
//


endmodule


