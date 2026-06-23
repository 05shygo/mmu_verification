module mbuf_entry #(
    parameter VADDR_WIDTH = 39,                         // VADDR
    parameter PADDR_WIDTH = 40,                         // PADDR
    parameter VPN_WIDTH   = VADDR_WIDTH-12,             // VPN
    parameter PPN_WIDTH   = PADDR_WIDTH-12,             // PPN
    parameter FLG_WIDTH   = 14,                         // PPN
    parameter ASID_WIDTH  = 16,                         // PPN
    parameter PGS_WIDTH   = 3,                          // Page Size
    parameter PTE_LEVEL   = 3,                          // Page Table Label
    parameter ID_WIDTH    = 7,
    parameter TYPE_WIDTH  = 3
) (
//!******************************************
//! Clock and Reset
//!******************************************
    input  logic                      forever_cpuclk,
    input  logic                      cpurst_b,
    input  logic                      cp0_mmu_icg_en,
    input  logic                      pad_yy_icg_scan_en,

	
    input  logic                      mbuf_all_clr,
    input  logic                      lsu_mmu_data_vld,
    input  logic [63:0]               lsu_mmu_data,
    input  logic                      mmu_lsu_data_req_grant,
    input  logic                      lsu_mmu_bus_error,
    input  logic                      mbuf_entry_upd,
    input  logic [PADDR_WIDTH-1:0]    mbuf_upd_padder,
    input  logic [VPN_WIDTH-1:0]      mbuf_upd_vpn,
    input  logic [TYPE_WIDTH-1:0]     mbuf_upd_type,
    input  logic [ID_WIDTH-1:0]       mbuf_upd_id,
    input  logic [PTE_LEVEL-1:0]      mbuf_upd_lvl,
    input  logic [7:0]                mbuf_upd_pmpflg,
    input  logic                      twu_data_ready,
    input  logic                      write_back_grant,
    input  logic                      mbuf_entry_bus_err_req_mask,
    input  logic                      mbuf_bus_error_grant,

    output logic                      write_back_req,
    output logic                      bus_err_write_back_req,
    output logic [PADDR_WIDTH-1:0]    mbuf_entry_padder,
    output logic                      mbuf_entry_vld,
    output logic                      mbuf_entry_on,
    output logic [VPN_WIDTH-1:0]      mbuf_entry_vpn,
    output logic [TYPE_WIDTH-1:0]     mbuf_entry_type,
    output logic [ID_WIDTH-1:0]       mbuf_entry_id,
    output logic [PTE_LEVEL-1:0]      mbuf_entry_lvl,
    output logic [7:0]                mbuf_entry_pmpflg,
    output logic [63:0]               mbuf_entry_data,
    output logic                      mbuf_entry_get,
    output logic                      mbuf_entry_bus_err_flop
);

//logic ptw_entry_clk;  // 
logic                   mbuf_vld         ;                      //
logic                   mbuf_on          ;                      //
logic [PADDR_WIDTH-1:0] mbuf_padder      ;                      //
logic [VPN_WIDTH-1:0]   mbuf_vpn         ;                      //
logic [TYPE_WIDTH-1:0]  mbuf_type        ;
logic [ID_WIDTH-1:0]    mbuf_id          ;                      //
logic [PTE_LEVEL-1:0]   mbuf_lvl         ;                      //
logic [63:0]            mbuf_lsu_data    ;
logic                   mbuf_get         ;
logic                   mbuf_bus_err_flop;
logic                   mbuf_entry_clk_en;
logic                   mbuf_entry_clk   ;
logic [7:0]             mbuf_pmpflg      ;
logic                   lsu_mmu_resp_vld ;
logic                   lsu_mmu_data_routed;
logic                   lsu_mmu_err_routed ;

//------------------------------------------------------------------------------
// LSU response 已经由 ptw_mbuf 按 ID 解码
//------------------------------------------------------------------------------
// LSU 返回的 response id 在 ptw_mbuf 中已经被直接解码成 onehot：
//   lsu_mmu_data_id == i  ->  只拉高 entry[i] 的 lsu_mmu_data_vld/bus_error。
//
// 因此 mbuf_entry 内部不再保存 entry id，也不再做 resp_id == entry_id 的 hit
// 比较；当前 entry 看到的 lsu_mmu_data_vld 或 lsu_mmu_bus_error 已经表示
// “这个 response 就是给我的”。这样 response 路由只有一处，逻辑更直接，也
// 避免每个 entry 重复生成比较器。
assign lsu_mmu_resp_vld               = lsu_mmu_data_vld | lsu_mmu_bus_error;
assign lsu_mmu_data_routed            = lsu_mmu_data_vld & (!lsu_mmu_bus_error);
assign lsu_mmu_err_routed             = lsu_mmu_bus_error;

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
    // mbuf_on 表示“本 entry 已经有一笔请求被 LSU grant 接收，但 response 还
    // 没有回来”。abort 不能直接清 mbuf_on，否则 MMU 会丢失这笔已发出请求
    // 的 outstanding 记录；必须等 ptw_mbuf 按 LSU response id 解码后，把
    // response valid/error 直接送到本 entry，再由本 entry 清 on。
	else if(mbuf_on & lsu_mmu_resp_vld)
		mbuf_on <= 1'b0;
    // 只有 PTW/MBUF 侧的 req 和 LSU 的 grant 同时成立时，才认为请求真正发
    // 出。未 grant 的请求即使 mmu_lsu_data_req 曾经拉高，也不能置 mbuf_on。
	else if((!mbuf_all_clr) & mmu_lsu_data_req_grant) 
		mbuf_on <= 1'b1;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_get <= 1'b0;
    else if(mbuf_all_clr | mbuf_entry_upd)
        mbuf_get <= 1'b0;
    // 正常 data response 被 ptw_mbuf 路由到当前 entry，但 TWU 暂时没有接受时，
    // 先把 data 缓存在 entry 内。abort 当拍 mbuf_all_clr 会清 vld/get，因此
    // abort 后这个 entry 不会再向 TWU 返回，也不会经由 write_back 路径更新
    // PDE cache。
    else if(mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
        mbuf_get <= 1'b1;
    else if(write_back_grant)
        mbuf_get <= 1'b0;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_bus_err_flop <= 1'b0;
    else if(mbuf_all_clr | mbuf_entry_upd)
        mbuf_bus_err_flop <= 1'b0;
    // bus error 与 normal data 使用同一套 ID 路由。只有属于当前 entry 的错误
    // 返回才会被记录；abort 清 vld 后，即使后续 drain 期间错误返回，也不会
    // 再通过 bus_err_write_back_req 报给 TWU。
    else if(mbuf_on & lsu_mmu_err_routed & (!mbuf_bus_error_grant))
        mbuf_bus_err_flop <= 1'b1;
    else if(mbuf_bus_error_grant)
        mbuf_bus_err_flop <= 1'b0;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_pmpflg[7:0] <= 8'b0;
    else if(mbuf_entry_upd)
        mbuf_pmpflg[7:0] <= mbuf_upd_pmpflg[7:0];
end
//------------------------------------------------------------
//                  VPN ,PFN and Flag information
//------------------------------------------------------------
always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
		mbuf_padder[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
		mbuf_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
		mbuf_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
		mbuf_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
		mbuf_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
    end else if(mbuf_entry_upd)begin
		mbuf_padder[PADDR_WIDTH-1:0] <= mbuf_upd_padder[PADDR_WIDTH-1:0];
		mbuf_vpn[VPN_WIDTH-1:0] <= mbuf_upd_vpn[VPN_WIDTH-1:0];
		mbuf_type[TYPE_WIDTH-1:0] <= mbuf_upd_type[TYPE_WIDTH-1:0];
		mbuf_id[ID_WIDTH-1:0] <= mbuf_upd_id[ID_WIDTH-1:0];
		mbuf_lvl[PTE_LEVEL-1:0] <= mbuf_upd_lvl[PTE_LEVEL-1:0];
	end
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_lsu_data[63:0] <= 64'b0;
    else if((!mbuf_all_clr) & mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
        mbuf_lsu_data[63:0] <= lsu_mmu_data[63:0];
end

assign write_back_req = mbuf_vld
                      & (!mbuf_all_clr)
                      & twu_data_ready
                      & ((mbuf_on & lsu_mmu_data_routed) | mbuf_get);
assign bus_err_write_back_req = mbuf_vld
                              & (!mbuf_all_clr)
                              & ((mbuf_on & lsu_mmu_err_routed) | mbuf_bus_err_flop)
                              & (!mbuf_entry_bus_err_req_mask);
//------------------------------------------------------------
//                  Output
//------------------------------------------------------------
assign mbuf_entry_padder = mbuf_padder[PADDR_WIDTH-1:0];
assign mbuf_entry_vld = mbuf_vld;
assign mbuf_entry_on = mbuf_on;
assign mbuf_entry_vpn = mbuf_vpn[VPN_WIDTH-1:0];
assign mbuf_entry_type = mbuf_type[TYPE_WIDTH-1:0];
assign mbuf_entry_id = mbuf_id[ID_WIDTH-1:0];
assign mbuf_entry_lvl = mbuf_lvl[PTE_LEVEL-1:0];
assign mbuf_entry_pmpflg = mbuf_pmpflg[7:0];
assign mbuf_entry_data = mbuf_get ? mbuf_lsu_data[63:0] : lsu_mmu_data[63:0];
assign mbuf_entry_get = mbuf_get;
assign mbuf_entry_bus_err_flop = mbuf_bus_err_flop;

endmodule
