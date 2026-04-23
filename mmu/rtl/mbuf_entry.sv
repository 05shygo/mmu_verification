module mbuf_entry(
//!******************************************
//! Clock and Reset
//!******************************************
input logic 			forever_cpuclk,
input logic 			cpurst_b,
input logic             cp0_mmu_icg_en,
input logic             pad_yy_icg_scan_en,

	
input logic  			mbuf_all_clr,
input logic				lsu_mmu_data_vld,
input logic  [63:0]     lsu_mmu_data,
input logic				mmu_lsu_data_req_grant,
input logic			    lsu_mmu_bus_error,
input logic  			mbuf_entry_upd,
input logic  [39:0]		mbuf_upd_padder,
input logic  [26:0]		mbuf_upd_vpn,
input logic  [2:0]		mbuf_upd_type,
input logic  [5:0]		mbuf_upd_id,
input logic  [3:0]		mbuf_upd_twu_idx,
input logic  [2:0]		mbuf_upd_lvl,
input logic  [3:0][2:0] twu_data_ready,
input logic             write_back_grant,
input logic             mbuf_entry_bus_err_req_mask,
input logic             mbuf_bus_error_grant,

output logic            write_back_req,
output logic            bus_err_write_back_req,
output logic [39:0]		mbuf_entry_padder,
output logic			mbuf_entry_vld,
output logic			mbuf_entry_on,
output logic [26:0]		mbuf_entry_vpn,
output logic [2:0]		mbuf_entry_type,
output logic [5:0]		mbuf_entry_id,
output logic [3:0]		mbuf_entry_twu_idx,
output logic [2:0]		mbuf_entry_lvl,
output logic [63:0]     mbuf_entry_data,
output logic            mbuf_entry_get,
output logic            mbuf_entry_bus_err_flop
);

parameter VADDR_WIDTH = 39;              // VADDR
parameter PADDR_WIDTH = 40;              // PADDR
parameter VPN_WIDTH   = VADDR_WIDTH-12;  // VPN
parameter PPN_WIDTH   = PADDR_WIDTH-12;  // PPN
parameter FLG_WIDTH   = 14;              // PPN
parameter ASID_WIDTH  = 16;              // PPN
parameter PGS_WIDTH   = 3;               // Page Size
parameter PTE_LEVEL   = 3;               // Page Table Label




//logic ptw_entry_clk;  // 
logic mbuf_vld;                       //
logic mbuf_on;                        //
logic [PADDR_WIDTH-1:0] mbuf_padder;  // 
logic [VPN_WIDTH-1:0]   mbuf_vpn;     // 
logic [2:0]             mbuf_type;    
logic [5:0]             mbuf_id;      // 
logic [3:0]             mbuf_twu_idx; // 
logic [2:0]             mbuf_lvl;     //
logic [63:0]            mbuf_lsu_data;
logic [1:0]             idx;
logic                   mbuf_get;
logic                   mbuf_bus_err_flop;
logic                   mbuf_entry_clk_en;
logic                   mbuf_entry_clk;


assign mbuf_entry_clk_en = 1'b1; 
// &Instance("gated_clk_cell", "x_ptw_gateclk"); @59
gated_clk_cell  x_mbuf_entry_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (mbuf_entry_clk    ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (mbuf_entry_clk_en ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//assign ptw_entry_clk = forever_cpuclk;
//-------------------------------------------------------------
//                  Valid bit generating
//------------------------------------------------------------
always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
	if(!cpurst_b)
		mbuf_vld <= 1'b0;
	else if(mbuf_all_clr)
		mbuf_vld <= 1'b0;
	else if(mbuf_entry_upd) 
		mbuf_vld <= 1'b1;
    else if(write_back_grant | mbuf_bus_error_grant)
		mbuf_vld <= 1'b0;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
	if(!cpurst_b)
		mbuf_on <= 1'b0;
	else if(lsu_mmu_data_vld | lsu_mmu_bus_error)
		mbuf_on <= 1'b0;
	else if(mmu_lsu_data_req_grant) 
		mbuf_on <= 1'b1;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_get <= 1'b0;
    else if(mbuf_on & lsu_mmu_data_vld & (!lsu_mmu_bus_error) & (!write_back_grant))
        mbuf_get <= 1'b1;
    else if(write_back_grant)
        mbuf_get <= 1'b0;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_bus_err_flop <= 1'b0;
    else if(mbuf_on & lsu_mmu_bus_error & (!mbuf_bus_error_grant))
        mbuf_bus_err_flop <= 1'b1;
    else if(mbuf_bus_error_grant)
        mbuf_bus_err_flop <= 1'b0;
end

        

//------------------------------------------------------------
//                  VPN ,PFN and Flag information
//------------------------------------------------------------
always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
		mbuf_padder[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
		mbuf_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		mbuf_type[2:0] <= 3'b0;
		mbuf_id[5:0] <= 6'b0;
		mbuf_twu_idx[3:0] <= 4'b0;
		mbuf_lvl[2:0] <= 3'b0;
    end else if(mbuf_entry_upd)begin
		mbuf_padder[PADDR_WIDTH-1:0] <= mbuf_upd_padder[PADDR_WIDTH-1:0];
		mbuf_vpn[VPN_WIDTH-1:0] <= mbuf_upd_vpn[VPN_WIDTH-1:0];
		mbuf_type[2:0] <= mbuf_upd_type[2:0];
		mbuf_id[5:0] <= mbuf_upd_id[5:0];
		mbuf_twu_idx[3:0] <= mbuf_upd_twu_idx[3:0];
		mbuf_lvl[2:0] <= mbuf_upd_lvl[2:0];
	end
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_lsu_data[63:0] <= 64'b0;
    else if(mbuf_on & lsu_mmu_data_vld & (!write_back_grant))
        mbuf_lsu_data[63:0] <= lsu_mmu_data[63:0];
end

always_comb begin
    case(mbuf_twu_idx[3:0])
        4'b0001 : idx = 2'b00;
        4'b0010 : idx = 2'b01;
        4'b0100 : idx = 2'b10;
        4'b1000 : idx = 2'b11;
        default : idx = 2'b00;
    endcase
end
assign write_back_req = mbuf_vld & (|(twu_data_ready[idx][2:0] & mbuf_lvl[2:0])) & (mbuf_on & lsu_mmu_data_vld & (!lsu_mmu_bus_error)  | mbuf_get);
assign bus_err_write_back_req = mbuf_vld & (mbuf_on & lsu_mmu_bus_error | mbuf_bus_err_flop) & (!mbuf_entry_bus_err_req_mask);
//------------------------------------------------------------
//                  Output
//------------------------------------------------------------
assign mbuf_entry_padder = mbuf_padder[PADDR_WIDTH-1:0];
assign mbuf_entry_vld = mbuf_vld;
assign mbuf_entry_on = mbuf_on;
assign mbuf_entry_vpn = mbuf_vpn[VPN_WIDTH-1:0];
assign mbuf_entry_type = mbuf_type[2:0];
assign mbuf_entry_id = mbuf_id[5:0];
assign mbuf_entry_twu_idx = mbuf_twu_idx[3:0];
assign mbuf_entry_lvl = mbuf_lvl[2:0];
assign mbuf_entry_data = mbuf_get ? mbuf_lsu_data[63:0] : lsu_mmu_data[63:0];
assign mbuf_entry_get = mbuf_get;
assign mbuf_entry_bus_err_flop = mbuf_bus_err_flop;

endmodule


