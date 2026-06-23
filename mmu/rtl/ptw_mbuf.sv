module ptw_mbuf #(
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
    parameter RDATA_WIDTH = PPN_WIDTH+FLG_WIDTH,
    parameter MBUF_ENTRY_NUM = 9,
    parameter MBUF_ID_WIDTH = 4
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
    input  logic                        twu_mbuf_req,
    input  logic [PADDR_WIDTH-1:0]      twu_mbuf_paddr,
    input  logic [VPN_WIDTH-1:0]        twu_mbuf_vpn,
    input  logic [TYPE_WIDTH-1:0]       twu_mbuf_type,
    input  logic [ID_WIDTH-1:0]         twu_mbuf_id,
    input  logic [PTE_LEVEL-1:0]        twu_mbuf_lvl,
    input  logic [7:0]                  twu_mbuf_pmpflg,
//input logic	 [3:0]      twu_mbuf_mask,

//!******************************************
//! PTW <=> LSU
//!******************************************
    input  logic                        lsu_mmu_data_vld,
    input  logic [DATA_WIDTH-1:0]       lsu_mmu_data,
    input  logic [MBUF_ID_WIDTH-1:0]    lsu_mmu_data_id,
    // LSU 对 PTW load 请求的接收确认。
    // 只有 mmu_lsu_data_req 和 lsu_mmu_data_req_grant 同拍为 1 时，
    // 这笔页表项读取请求才算真正进入 LSU outstanding 队列。
    input  logic                        lsu_mmu_data_req_grant,
    input  logic                        lsu_mmu_bus_error,
		
    output logic                        mmu_lsu_data_req,
    output logic [PADDR_WIDTH-1:0]      mmu_lsu_data_req_addr,
    output logic [MBUF_ID_WIDTH-1:0]    mmu_lsu_data_req_id,
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
    output logic [7:0]                  mbuf_twu_pmpflg,
    output logic                        mbuf_twu_data_vld,

    output logic                        mbuf_grant,
//output logic [3:0]		mbuf_twu_have,
//!******************************************
//! Refill to PDE Cache
//!******************************************
    output logic                        mbuf_cache_upd,
    output logic [PPN_WIDTH-1:0]        mbuf_cache_upd_ppn,
    output logic [PTE_LEVEL-2:0]        mbuf_cache_upd_lvl,
    output logic [VPN_WIDTH-1:0]        mbuf_cache_upd_vpn,
    output logic [3:0]                  mbuf_cache_upd_l1pmpflg,
    output logic [3:0]                  mbuf_cache_upd_l2pmpflg,

    input  logic                        tlboper_ptw_abort,
    input  logic                        twu_data_ready,
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
logic                       ptw_abort_drain;
logic                       create_en;
logic                       twu_itlb_sel;
logic [PADDR_WIDTH-1:0]    mbuf_upd_padder;
logic [VPN_WIDTH-1:0]      mbuf_upd_vpn;
logic [TYPE_WIDTH-1:0]     mbuf_upd_type;
logic [ID_WIDTH-1:0]       mbuf_upd_id;
logic [PTE_LEVEL-1:0]      mbuf_upd_lvl;

//==============================================================================
// Internal — MBUF entry index / LSU cursor (width scales with MBUF_ENTRY_NUM)
//==============================================================================
logic [MBUF_ENTRY_NUM-2:0]  create_ptr;
logic [MBUF_ENTRY_NUM-1:0]  req_sel_ptr;
logic [MBUF_ENTRY_NUM-1:0]  req_on_ptr;
logic [MBUF_ENTRY_NUM-1:0]  req_hold_ptr;
logic                       req_hold_vld;
logic                       lsu_req_fire;
// mbuf_ptr: alias for bind mmu_ptw_lsu_protocol_sva (.*).
logic [MBUF_ENTRY_NUM-1:0]  mbuf_ptr;
logic [MBUF_ENTRY_NUM-1:0]  mbuf_entry_upd;
logic [MBUF_ENTRY_NUM-1:0]  mbuf_req_pending;

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
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_req_grant;
logic [MBUF_ENTRY_NUM-1:0]                  lsu_mmu_resp_entry_dec;
logic [MBUF_ENTRY_NUM-1:0]                  lsu_mmu_data_vld_entry;
logic [MBUF_ENTRY_NUM-1:0]                  lsu_mmu_bus_error_entry;
logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_vld;
logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_on;
logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0]   mbuf_entry_vpn;
logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0]  mbuf_entry_type;
logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0]    mbuf_entry_id;
logic [MBUF_ENTRY_NUM-1:0][PTE_LEVEL-1:0]   mbuf_entry_lvl;
logic [MBUF_ENTRY_NUM-1:0]                  write_back_grant;
logic [MBUF_ENTRY_NUM-1:0]                  write_back_req;
logic [MBUF_ENTRY_NUM-1:0][DATA_WIDTH-1:0]  mbuf_entry_data;
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
logic                       tlboper_ptw_abort_reg;
//logic   [TYPE_WIDTH-1:0]	    mbuf_bus_error_type                 ;
logic [7:0]                 mbuf_upd_pmpflg;
logic [MBUF_ENTRY_NUM-1:0][7:0]                 mbuf_entry_pmpflg;
logic [3:0]                 pde_updata_l1pmpflg;
logic [3:0]                 pde_updata_l2pmpflg;

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

//------------------------------------------------------------------------------
// Abort / drain split
//------------------------------------------------------------------------------
// mbuf_all_clr 只保持 tlboper_ptw_abort 当拍，用来同步清掉所有 entry 的 vld。
// 清 vld 的目的有两个：
//   1. 这些 entry 后续即使收到 LSU response，也不能再回 TWU；
//   2. 这些 response 也不能再触发 PDE cache refill。
//
// 注意：mbuf_all_clr 不能拉成长脉冲，也不能直接清 entry.on。entry.on 记录的
// 是“已经被 LSU grant 接收”的请求，abort 之后仍必须保留，直到 LSU 带 ID 的
// response 返回并按 entry id 精确清除。
assign mbuf_all_clr = tlboper_ptw_abort;

// ptw_abort_drain 是内部 drain 状态：包含 abort 当拍和 abort 后等待 outstanding
// response 的周期。drain 期间禁止创建新 entry、禁止发新 LSU 请求、禁止 PDE
// cache 更新；但允许已发出的请求继续通过 response ID 清掉对应 entry.on。
assign ptw_abort_drain = tlboper_ptw_abort | tlboper_ptw_abort_reg;

assign mbuf_entry_on_vld = |mbuf_entry_on;

//------------------------------------------------------------------------------
// LSU response id 直接解码到对应 MBUF entry
//------------------------------------------------------------------------------
// LSU 返回的 lsu_mmu_data_id 就是当初 PTW 发请求时携带的 MBUF entry index。
// 因此 response 回来后不需要让每个 entry 再各自比较 resp_id 是否命中自己；
// ptw_mbuf 在这里直接把 id 解码成 per-entry onehot valid/error：
//   id == 0 -> entry[0].lsu_mmu_data_vld / bus_error
//   id == 1 -> entry[1].lsu_mmu_data_vld / bus_error
//   ...
//
// 这里用 onehot shift 直接完成 id->entry 的解码，不在各 entry 内做 hit 比较。
// 如果 LSU 错误地返回了 9..15 这类非法 id，左移结果自然移出 9-bit 向量，
// 所有 entry valid/error 都为 0，不会误写任何 entry。
assign lsu_mmu_resp_entry_dec[MBUF_ENTRY_NUM-1:0] = {{(MBUF_ENTRY_NUM-1){1'b0}}, 1'b1}
                                                  << lsu_mmu_data_id[MBUF_ID_WIDTH-1:0];
assign lsu_mmu_data_vld_entry[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{lsu_mmu_data_vld}}
                                                  & lsu_mmu_resp_entry_dec[MBUF_ENTRY_NUM-1:0];
assign lsu_mmu_bus_error_entry[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{lsu_mmu_bus_error}}
                                                   & lsu_mmu_resp_entry_dec[MBUF_ENTRY_NUM-1:0];

//==============================================================================
//                  MBUF Upd Arbiter
//==============================================================================
assign twu_itlb_sel = twu_mbuf_req & (twu_mbuf_type[TYPE_WIDTH-1:0] == 3'b011);
assign mbuf_grant = twu_mbuf_req & (!ptw_abort_drain);
/*
always_comb begin
	case(mbuf_grant)
		1'b1 : begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = twu_mbuf_paddr[PADDR_WIDTH-1:0];
            mbuf_upd_vpn[VPN_WIDTH-1:0] = twu_mbuf_vpn[VPN_WIDTH-1:0];
            mbuf_upd_type[TYPE_WIDTH-1:0] = twu_mbuf_type[TYPE_WIDTH-1:0];
            mbuf_upd_id[ID_WIDTH-1:0] = twu_mbuf_id[ID_WIDTH-1:0];
            mbuf_upd_lvl[PTE_LEVEL-1:0] = twu_mbuf_lvl[PTE_LEVEL-1:0];
            mbuf_upd_pmpflg[7:0] = twu_mbuf_pmpflg[7:0];
		end
		default : begin
			mbuf_upd_padder[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
            mbuf_upd_vpn[VPN_WIDTH-1:0] = {VPN_WIDTH{1'b0}};
            mbuf_upd_type[TYPE_WIDTH-1:0] = {TYPE_WIDTH{1'b0}};
            mbuf_upd_id[ID_WIDTH-1:0] = {ID_WIDTH{1'b0}};
            mbuf_upd_lvl[PTE_LEVEL-1:0] = {PTE_LEVEL{1'b0}};
            mbuf_upd_pmpflg[7:0] = 8'b0;
		end
	endcase
end
*/
assign mbuf_upd_padder[PADDR_WIDTH-1:0] = twu_mbuf_paddr[PADDR_WIDTH-1:0];
assign mbuf_upd_vpn[VPN_WIDTH-1:0] = twu_mbuf_vpn[VPN_WIDTH-1:0];
assign mbuf_upd_type[TYPE_WIDTH-1:0] = twu_mbuf_type[TYPE_WIDTH-1:0];
assign mbuf_upd_id[ID_WIDTH-1:0] = twu_mbuf_id[ID_WIDTH-1:0];
assign mbuf_upd_lvl[PTE_LEVEL-1:0] = twu_mbuf_lvl[PTE_LEVEL-1:0];
assign mbuf_upd_pmpflg[7:0] = twu_mbuf_pmpflg[7:0];

assign create_en = mbuf_grant & (!twu_itlb_sel);

// Combinational find-first-zero on mbuf_entry_vld[7:0] to pick a free DTLB entry.
// Entries still being processed (vld=1) are skipped.
always_comb begin
    casez(mbuf_entry_vld[7:0])
      8'b???????0 : create_ptr[7:0] = 8'b0000_0001;
      8'b??????01 : create_ptr[7:0] = 8'b0000_0010;
      8'b?????011 : create_ptr[7:0] = 8'b0000_0100;
      8'b????0111 : create_ptr[7:0] = 8'b0000_1000;
      8'b???01111 : create_ptr[7:0] = 8'b0001_0000;
      8'b??011111 : create_ptr[7:0] = 8'b0010_0000;
      8'b?0111111 : create_ptr[7:0] = 8'b0100_0000;
      8'b01111111 : create_ptr[7:0] = 8'b1000_0000;
      default     : create_ptr[7:0] = 8'b0000_0000;
    endcase
end
assign mbuf_entry_upd[MBUF_ENTRY_NUM-2:0] = {MBUF_ENTRY_NUM-1{create_en}} & create_ptr[MBUF_ENTRY_NUM-2:0];

assign mbuf_entry_upd[MBUF_ENTRY_NUM-1] = twu_itlb_sel & (!ptw_abort_drain);


//==============================================================================
//                  Req to LSU
//==============================================================================

// 一个 entry 只有在满足下面条件时才允许参与新的 LSU request 选择：
//   - vld=1：该 entry 保存着 TWU 发来的有效页表项读取任务；
//   - on=0：该 entry 当前没有已经被 LSU grant 接收但还没返回的请求；
//   - get=0 / bus_err_flop=0：该 entry 没有待回 TWU 的 data 或 bus error。
//
// 这里显式排除 on，是 outstanding 改造的关键点。否则同一个 entry 在 response
// 回来前可能被重复发给 LSU，导致同一个 4-bit id 对应多笔未完成请求，response
// 无法再唯一回到 entry。
assign mbuf_req_pending[MBUF_ENTRY_NUM-1:0] = mbuf_entry_vld[MBUF_ENTRY_NUM-1:0]
                                            & (~mbuf_entry_on[MBUF_ENTRY_NUM-1:0])
                                            & (~mbuf_entry_get[MBUF_ENTRY_NUM-1:0])
                                            & (~mbuf_entry_bus_err_flop[MBUF_ENTRY_NUM-1:0]);

// 从 pending entry 中选出下一笔候选请求。
// entry[MBUF_ENTRY_NUM-1] 是 legacy ITLB 优先 entry，保持最高优先级；
// 其它 entry 使用低 index 优先的固定优先级。真正送到 LSU 的请求还会经过
// req_hold_ptr 保持，保证 grant 前地址和 ID 不会变化。
always_comb begin
    req_sel_ptr[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{1'b0}};
    if(mbuf_req_pending[MBUF_ENTRY_NUM-1]) begin
        req_sel_ptr[MBUF_ENTRY_NUM-1] = 1'b1;
    end else begin
        for(int req_i = 0; req_i < MBUF_ENTRY_NUM-1; req_i = req_i + 1) begin
            if(mbuf_req_pending[req_i] && !(|req_sel_ptr[MBUF_ENTRY_NUM-2:0]))
                req_sel_ptr[req_i] = 1'b1;
        end
    end
end

// req_hold_ptr 用于实现标准 req/grant 稳定性：
//   - 当 MMU 拉高 mmu_lsu_data_req 但 LSU 尚未 grant 时，锁存本次选择的 entry；
//   - grant 返回前持续使用锁存的 entry 驱动 addr/id；
//   - grant 后清 hold，下一拍可以选择其它 pending entry；
//   - abort/drain 时清 hold，表示未被 LSU grant 的请求被取消，不进入 outstanding。
//
// 这样可以避免“grant 前有更高优先级 entry 变 pending，导致同一笔 req 的
// addr/id 跳变”的握手错误。
assign req_on_ptr[MBUF_ENTRY_NUM-1:0] = req_hold_vld
                                      ? req_hold_ptr[MBUF_ENTRY_NUM-1:0]
                                      : req_sel_ptr[MBUF_ENTRY_NUM-1:0];
assign mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0] = req_on_ptr[MBUF_ENTRY_NUM-1:0]
                                                & {MBUF_ENTRY_NUM{!ptw_abort_drain}};
assign mbuf_ptr[MBUF_ENTRY_NUM-1:0] = mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];
assign mmu_lsu_data_req = |mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];

// lsu_req_fire 是唯一的“请求已经发出/被接受”事件。
// 后续 entry.on 置位、outstanding 统计，都必须使用 lsu_req_fire，而不是单独
// 使用 mmu_lsu_data_req。没有 grant 的 req 只是等待中的 valid，不算 outstanding。
assign lsu_req_fire = mmu_lsu_data_req & lsu_mmu_data_req_grant;

always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b) begin
        req_hold_vld <= 1'b0;
        req_hold_ptr[MBUF_ENTRY_NUM-1:0] <= {MBUF_ENTRY_NUM{1'b0}};
    end else if(ptw_abort_drain | lsu_req_fire) begin
        req_hold_vld <= 1'b0;
        req_hold_ptr[MBUF_ENTRY_NUM-1:0] <= {MBUF_ENTRY_NUM{1'b0}};
    end else if(mmu_lsu_data_req & (!req_hold_vld)) begin
        req_hold_vld <= 1'b1;
        req_hold_ptr[MBUF_ENTRY_NUM-1:0] <= mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];
    end
end

always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    tlboper_ptw_abort_reg <= 1'b0;
  // abort 当拍如果已经存在 outstanding entry.on，则进入 drain 状态。
  // 未 grant 的 hold/request 会在上面的 req_hold 逻辑里被取消，不会置 on。
  else if(tlboper_ptw_abort & mbuf_entry_on_vld)
    tlboper_ptw_abort_reg <= 1'b1;
  // drain 状态必须等所有 entry.on 都被 LSU response 按 ID 清掉后才能退出。
  // 不能因为看到第一笔 lsu_mmu_data_vld 就清 abort_reg，否则多 outstanding
  // 请求场景会丢失后续 response 的跟踪。
  else if(tlboper_ptw_abort_reg & (!mbuf_entry_on_vld))
    tlboper_ptw_abort_reg <= 1'b0;
end

always_comb begin
    mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
    mmu_lsu_data_req_id[MBUF_ID_WIDTH-1:0] = {MBUF_ID_WIDTH{1'b0}};
	for(int i = 0; i < MBUF_ENTRY_NUM; i = i + 1) begin
		if(mmu_lsu_data_req_ptr[i])begin
		    mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[i];
            // request id 直接使用 entry index。LSU 返回时必须带回同一个 id。
            // response 路由不在 entry 内做比较，而是在本模块上方直接把 id
            // 解码成 per-entry valid/error。
            mmu_lsu_data_req_id[MBUF_ID_WIDTH-1:0] = MBUF_ID_WIDTH'(i);
	    end
    end
end

// entry 看到的 grant 是 per-entry onehot 脉冲，只在全局 req/grant fire 且该
// entry 正是当前请求源时置 1。entry 由这个脉冲置 on，开始等待对应 ID 的
// LSU response。
assign mbuf_entry_req_grant[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{lsu_req_fire}}
                                                & mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];

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
			.ID_WIDTH                   (ID_WIDTH                                ),
			.TYPE_WIDTH                 (TYPE_WIDTH                              )
		) mbuf_entry_x(
			.forever_cpuclk				(forever_cpuclk					 			 ),
			.cpurst_b					(cpurst_b						 			 ),
            .cp0_mmu_icg_en             (cp0_mmu_icg_en                              ),
            .pad_yy_icg_scan_en         (pad_yy_icg_scan_en                          ),
																					 
			.mbuf_all_clr				(mbuf_all_clr					 			 ),
			.lsu_mmu_data_vld			(lsu_mmu_data_vld_entry[MBUF_ent]			 ),
			.lsu_mmu_data               (lsu_mmu_data[DATA_WIDTH-1:0]                ),
            .mmu_lsu_data_req_grant		(mbuf_entry_req_grant[MBUF_ent]			     ),
			.lsu_mmu_bus_error			(lsu_mmu_bus_error_entry[MBUF_ent]			 ),
			.mbuf_entry_upd				(mbuf_entry_upd[MBUF_ent]		 			 ),
			.mbuf_upd_padder			(mbuf_upd_padder[PADDR_WIDTH-1:0]			 ),
			.mbuf_upd_vpn				(mbuf_upd_vpn[VPN_WIDTH-1:0]				 ),
			.mbuf_upd_type				(mbuf_upd_type[TYPE_WIDTH-1:0]			 	 ),
			.mbuf_upd_id				(mbuf_upd_id[ID_WIDTH-1:0]					 ),
			.mbuf_upd_lvl				(mbuf_upd_lvl[PTE_LEVEL-1:0]				 ),
			.mbuf_upd_pmpflg			(mbuf_upd_pmpflg[7:0]					 	 ),
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

assign mbuf_twu_data_vld = |write_back_grant[MBUF_ENTRY_NUM-1:0];

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
	mbuf_twu_lvl[PTE_LEVEL-1:0] = {PTE_LEVEL{1'b0}};
    mbuf_twu_data[DATA_WIDTH-1:0] = {DATA_WIDTH{1'b0}};
    mbuf_twu_pmpflg[7:0] = 8'b0;
    for (int i = 0; i < MBUF_ENTRY_NUM; i++) begin
        if(write_back_grant[i])begin
			mbuf_twu_vpn[VPN_WIDTH-1:0] = mbuf_entry_vpn[i];
			mbuf_twu_type[TYPE_WIDTH-1:0] = mbuf_entry_type[i];
			mbuf_twu_id[ID_WIDTH-1:0] = mbuf_entry_id[i];
			mbuf_twu_lvl[PTE_LEVEL-1:0] = mbuf_entry_lvl[i];
			mbuf_twu_pmpflg[7:0] = mbuf_entry_pmpflg[i];
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
    // 只有非 abort/drain 状态下、且 entry 正常 write back 给 TWU 的 data，才
    // 允许进入 PDE cache refill 判断。abort 当拍 entry.vld 已经被清掉，drain
    // 期间后续 LSU response 只用于清 entry.on，不能污染 PDE cache。
    else if(|write_back_grant[MBUF_ENTRY_NUM-1:0] & (!ptw_abort_drain))
        pde_updata_data_vld <= 1'b1;
    else 
        pde_updata_data_vld <= 1'b0;
end

always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b) begin
        pde_updata_data_flop[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
        pde_updata_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
        pde_updata_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
        pde_updata_l1pmpflg[3:0] <= 4'b0;
        pde_updata_l2pmpflg[3:0] <= 4'b0;
    end else if(|write_back_grant[MBUF_ENTRY_NUM-1:0]) begin
        pde_updata_data_flop[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
        pde_updata_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
        pde_updata_lvl[PTE_LEVEL-1:0] <= mbuf_twu_lvl[PTE_LEVEL-1:0];
        pde_updata_l1pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
        pde_updata_l2pmpflg[3:0] <= mbuf_twu_pmpflg[7:4];
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
assign mbuf_cache_upd_l1pmpflg[3:0] = pde_updata_l1pmpflg[3:0];
assign mbuf_cache_upd_l2pmpflg[3:0] = pde_updata_l2pmpflg[3:0];








endmodule


