//!********************************************************************
//!  OpenRiscv2030
//!
//!    L1DTLB Scheduler
//!    Selects requests for L2TLB (Bypass vs Buffered) with Credit Flow Control
//!    Updated: Supports 'store' attribute propagation
//!********************************************************************

module mmu_l1dtlb_scheduler #(
    parameter MB_DEPTH   = 8,
    parameter VPN_WIDTH  = 27,
    parameter IID_WIDTH  = 7,
    parameter CREDIT_MAX = 8      // Default credit matching L2 reqq depth
)(
    //! Clock and Reset
    input  logic                     cpurst_b,
    input  logic                     sched_clk,

    //! Miss Buffer Status
    input  logic [MB_DEPTH-1:0]                mb_entry_vld,
    input  logic [MB_DEPTH-1:0]                mb_entry_ready, // State == WFG
    input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
    input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
    input  logic [MB_DEPTH-1:0]                mb_entry_store, // NEW: Store attribute array
    
    //! Bypass Inputs (From Allocator/T1 Stage)
    input  logic                     alloc_gnt0,
    input  logic [$clog2(MB_DEPTH)-1:0] alloc_sel0,
    input  logic [VPN_WIDTH-1:0]     alloc_vpn0,
    input  logic [IID_WIDTH-1:0]     alloc_iid0,
    input  logic                     alloc_store0, // NEW: Bypass Port 0 Store
    
    input  logic                     alloc_gnt1,
    input  logic [$clog2(MB_DEPTH)-1:0] alloc_sel1,
    input  logic [VPN_WIDTH-1:0]     alloc_vpn1,
    input  logic [IID_WIDTH-1:0]     alloc_iid1,
    input  logic                     alloc_store1, // NEW: Bypass Port 1 Store
    
    //! L2TLB Interface
    input  logic                     l2tlb_credit_ret,  // Credit return from L2
    output logic                     dutlb_arb_req,
    output logic [VPN_WIDTH-1:0]     dutlb_arb_vpn,
    output logic [$clog2(MB_DEPTH)-1:0] dutlb_arb_id,
    output logic                     dutlb_arb_store,   // NEW: Request type to L2
    
    //! Scheduler Feedback to Miss Buffer
    output logic [MB_DEPTH-1:0]      issue_sel,     // One-hot select
    output logic                     issue_grant_out
);

localparam EID_WIDTH = $clog2(MB_DEPTH);

//!************************************************
//! Credit Counter Management
//!************************************************
logic [$clog2(CREDIT_MAX+1):0] credit_cnt;
logic                          credit_avail;
logic                          req_fire;

assign credit_avail = (credit_cnt > 0);
assign req_fire     = dutlb_arb_req; // Assuming ready/valid (no wait on req channel)

always_ff @(posedge sched_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        credit_cnt <= CREDIT_MAX;
    end else begin
        case ({req_fire, l2tlb_credit_ret})
            2'b10: credit_cnt <= credit_cnt - 1'b1; // Send only
            2'b01: credit_cnt <= credit_cnt + 1'b1; // Return only
            default: credit_cnt <= credit_cnt;      // Both or neither
        endcase
    end
end

//!************************************************
//! 1. Miss Buffer Selection (Path A)
//!************************************************
logic       mb_req_vld;
logic [EID_WIDTH-1:0] mb_req_id;
logic [MB_DEPTH-1:0]  mb_req_sel_oh;

// Find First Ready (Priority Encoder)
always_comb begin
    mb_req_vld    = 1'b0;
    mb_req_id     = '0;
    mb_req_sel_oh = '0;
    
    for (int i = 0; i < MB_DEPTH; i++) begin
        if (mb_entry_ready[i]) begin
            mb_req_vld    = 1'b1;
            mb_req_id     = i[EID_WIDTH-1:0];
            mb_req_sel_oh[i] = 1'b1;
            break; // Priority: Index 0 > Index N
        end
    end
end

//!************************************************
//! 2. Bypass Selection (Path B)
//!************************************************
logic       bypass_en;
logic       bypass_req_vld;
logic [EID_WIDTH-1:0] bypass_id;
logic [VPN_WIDTH-1:0] bypass_vpn;
logic       bypass_store; // NEW: Intermediate signal

// Condition: MB is Empty (No ready Entries)
// Note: We check `mb_entry_ready` (all entries).
assign bypass_en = ~(|mb_entry_ready);

always_comb begin
    bypass_req_vld = 1'b0;
    bypass_id      = '0;
    bypass_vpn     = '0;
    bypass_store   = 1'b0;

    if (bypass_en) begin
        if (alloc_gnt0) begin
            // Priority to Port 0 (or strictly older if allocator handled it)
            bypass_req_vld = 1'b1;
            bypass_id      = alloc_sel0;
            bypass_vpn     = alloc_vpn0;
            bypass_store   = alloc_store0; // Pass through Port 0 Store bit
        end else if (alloc_gnt1) begin
            bypass_req_vld = 1'b1;
            bypass_id      = alloc_sel1;
            bypass_vpn     = alloc_vpn1;
            bypass_store   = alloc_store1; // Pass through Port 1 Store bit
        end
    end
end

//!************************************************
//! 3. Final Arbitration & Output Mux
//!************************************************
// Priority: MB Request > Bypass Request
logic sel_mb;
logic sel_bypass;

assign sel_mb     = mb_req_vld && credit_avail;
assign sel_bypass = bypass_req_vld && credit_avail && !mb_req_vld; 

// Output Mux
always_comb begin
    if (sel_mb) begin
        dutlb_arb_req   = 1'b1;
        dutlb_arb_vpn   = mb_entry_vpn[mb_req_id];
        dutlb_arb_id    = mb_req_id;
        dutlb_arb_store = mb_entry_store[mb_req_id]; // Select from MB Array
    end else if (sel_bypass) begin
        dutlb_arb_req   = 1'b1;
        dutlb_arb_vpn   = bypass_vpn;
        dutlb_arb_id    = bypass_id; 
        dutlb_arb_store = bypass_store;              // Select from Bypass Logic
    end else begin
        dutlb_arb_req   = 1'b0;
        dutlb_arb_vpn   = '0;
        dutlb_arb_id    = '0;
        dutlb_arb_store = 1'b0;
    end
end

// Feedback to Miss Buffer
assign issue_sel       = sel_mb ? mb_req_sel_oh : 
                         sel_bypass ? (alloc_gnt0 ? (1 << alloc_sel0) : (1 << alloc_sel1)) : 
                         '0;
                         
assign issue_grant_out = sel_mb || sel_bypass;

endmodule


