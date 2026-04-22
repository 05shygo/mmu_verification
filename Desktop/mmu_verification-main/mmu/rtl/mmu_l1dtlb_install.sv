//!********************************************************************
//!  OpenRiscv2030
//!
//!    L1DTLB Install and Wakeup Logic (3-Way Arbitration)
//!    Handles collision between PTW, JTLB, and WFI entries
//!********************************************************************

module mmu_l1dtlb_install #(
    parameter MB_DEPTH   = 8,
    parameter VPN_WIDTH  = 27,
    parameter PPN_WIDTH  = 28,
    parameter FLG_WIDTH  = 14,
    parameter IID_WIDTH  = 7
)(
    // Clock and Reset
    input  logic                     cpurst_b,
    input  logic                     install_clk,
    
    // Miss Buffer Entry Status
    input  logic [MB_DEPTH-1:0]                mb_entry_vld,
    input  logic [MB_DEPTH-1:0][2:0]           mb_entry_state,
    input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
    input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
    input  logic [MB_DEPTH-1:0][2:0]	       mb_entry_pgs,
    //input  logic [MB_DEPTH-1:0]                mb_entry_port_id,
    
    // WFI Data
    input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
    input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
    input  logic [MB_DEPTH-1:0]                mb_entry_wfi,
    
    // Grant Output
    output logic [MB_DEPTH-1:0]                mb_refill_gnt_bus,
    
    // JTLB Refill Interface (Fresh L2)
    input  logic                     jtlb_dutlb_ref_pavld,
    input  logic                     jtlb_dutlb_ref_cmplt,
    input  logic [2:0]               jtlb_dutlb_ref_id,
    input  logic [VPN_WIDTH-1:0]     jtlb_utlb_ref_vpn,
    input  logic [PPN_WIDTH-1:0]     jtlb_utlb_ref_ppn,
    input  logic [FLG_WIDTH-1:0]     jtlb_utlb_ref_flg,
    input  logic                     jtlb_dutlb_pgflt,
    input  logic [2:0]		     l2tlb_l1dtlb_ref_pgs,
    //input  logic                     jtlb_dutlb_acc_err,

    // PTW Refill Interface (Fresh PTW)
    input  logic                     ptw_l1dtlb_ref_pavld,
    input  logic                     ptw_l1dtlb_ref_cmplt,
    input  logic [2:0]               ptw_l1dtlb_ref_id,
    input  logic [26:0]              ptw_l1tlb_ref_vpn, // 27 bits matches VPN_WIDTH
    input  logic [27:0]              ptw_l1tlb_ref_ppn, // 28 bits matches PPN_WIDTH
    input  logic                     ptw_l1tlb_acc_err,
    input  logic                     ptw_l1tlb_pgflt,
    input  logic [13:0]              ptw_l1tlb_ref_flg, // 14 bits matches FLG_WIDTH
    input  logic [2:0]		     ptw_l1dtlb_ref_pgs,

    // TLB Entry Array Update Interface
    output logic                     utlb_refill_vld,
    output logic [3:0]               utlb_refill_idx,
    output logic [VPN_WIDTH-1:0]     utlb_refill_vpn,
    output logic [PPN_WIDTH-1:0]     utlb_refill_ppn,
    output logic [FLG_WIDTH-1:0]     utlb_refill_flg,
    output logic [2:0]		     utlb_refill_pgs,
    
    // PLRU & Wakeup
    input  logic [15:0]              plru_bank0_refill_way,
    input  logic [15:0]              plru_bank1_refill_way,
    output logic                     plru_refill_updt,
    output logic [15:0]              plru_refill_way,
    
    // Wakeup to LSIQ
    output logic [11:0]              mmu_lsu_tlb_wakeup
);

localparam EID_WIDTH = $clog2(MB_DEPTH);
localparam STATE_ABT = 3'b101;

//!************************************************
//! 1. Identify Fresh Requests (PTW & JTLB)
//!************************************************
logic       req_ptw_vld;
logic       req_jtlb_vld;
logic       req_ptw_expt;
logic       req_jtlb_expt;
logic       req_ptw_aborted;
logic       req_jtlb_aborted;
logic [EID_WIDTH-1:0] id_ptw;
logic [EID_WIDTH-1:0] id_jtlb;

assign id_ptw  = ptw_l1dtlb_ref_id;
assign id_jtlb = jtlb_dutlb_ref_id;

assign req_ptw_expt  = ptw_l1tlb_pgflt || ptw_l1tlb_acc_err;
assign req_jtlb_expt = jtlb_dutlb_pgflt; //|| jtlb_dutlb_acc_err;

assign req_ptw_aborted  = (mb_entry_state[id_ptw] == STATE_ABT);
assign req_jtlb_aborted = (mb_entry_state[id_jtlb] == STATE_ABT);

// Validity Check: Complete + Valid MB + Not Exception + Not Aborted
assign req_ptw_vld = ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt && 
                     mb_entry_vld[id_ptw] && !req_ptw_expt && !req_ptw_aborted;

assign req_jtlb_vld = jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt && 
                      mb_entry_vld[id_jtlb] && !req_jtlb_expt && !req_jtlb_aborted;

//!************************************************
//! 2. Identify WFI Request
//!************************************************
logic       req_wfi_vld;
logic [EID_WIDTH-1:0] id_wfi;

// Priority Encoder for WFI (Find First Set)
always_comb begin
    req_wfi_vld = 1'b0;
    id_wfi      = '0;
    for (int i = 0; i < MB_DEPTH; i++) begin
        if (mb_entry_wfi[i]) begin
            req_wfi_vld = 1'b1;
            id_wfi      = i[EID_WIDTH-1:0];
            break;
        end
    end
end

//!************************************************
//! 3. Arbitration (Priority: PTW > JTLB > WFI)
//!************************************************
logic sel_ptw;
logic sel_jtlb;
logic sel_wfi;

// Strict Priority Logic
assign sel_ptw  = req_ptw_vld;
assign sel_jtlb = req_jtlb_vld && !req_ptw_vld;
assign sel_wfi  = req_wfi_vld  && !req_ptw_vld && !req_jtlb_vld;

assign utlb_refill_vld = sel_ptw || sel_jtlb || sel_wfi;

//!************************************************
//! 4. Data Routing (MUX)
//!************************************************
always_comb begin
    if (sel_ptw) begin
        utlb_refill_vpn = ptw_l1tlb_ref_vpn;
        utlb_refill_ppn = ptw_l1tlb_ref_ppn;
        utlb_refill_flg = ptw_l1tlb_ref_flg;
	utlb_refill_pgs = ptw_l1dtlb_ref_pgs;
    end else if (sel_jtlb) begin
        utlb_refill_vpn = jtlb_utlb_ref_vpn;
        utlb_refill_ppn = jtlb_utlb_ref_ppn;
        utlb_refill_flg = jtlb_utlb_ref_flg;
	utlb_refill_pgs = l2tlb_l1dtlb_ref_pgs;
    end else if (sel_wfi) begin
        utlb_refill_vpn = mb_entry_vpn[id_wfi];
        utlb_refill_ppn = mb_entry_ppn[id_wfi];
        utlb_refill_flg = mb_entry_flg[id_wfi];
	utlb_refill_pgs = mb_entry_pgs[id_wfi];
    end else begin
        utlb_refill_vpn = '0;
        utlb_refill_ppn = '0;
        utlb_refill_flg = '0;
	utlb_refill_pgs = '0;
    end
end

//!************************************************
//! 5. Grant Generation (To MB)
//!************************************************
always_comb begin
    mb_refill_gnt_bus = '0;
    
    if (sel_ptw) begin
        mb_refill_gnt_bus[id_ptw] = 1'b1;
    end
    
    if (sel_jtlb) begin
        mb_refill_gnt_bus[id_jtlb] = 1'b1;
    end
    
    if (sel_wfi) begin
        mb_refill_gnt_bus[id_wfi] = 1'b1;
    end
    
    // Collision behavior:
    // If PTW wins (sel_ptw=1), JTLB loses (sel_jtlb=0).
    // The JTLB ID will NOT get a Grant. 
    // The MB Entry logic (state machine) sees (Refill Valid && !Grant) -> goes to WFI state.
end

//!************************************************
//! 6. PLRU Replacement (Round Robin/PLRU)
//!************************************************
logic [3:0] replace_idx;
logic [3:0] plru_selected_way;

always_comb begin
    plru_selected_way = 4'b0;
    for (int i = 0; i < 16; i++) begin
        if (plru_bank0_refill_way[i]) begin
            plru_selected_way = i[3:0];
            break;
        end
    end
end

assign replace_idx      = plru_selected_way;
assign utlb_refill_idx  = replace_idx;
assign plru_refill_updt = utlb_refill_vld;
assign plru_refill_way  = (16'b1 << replace_idx);

//!************************************************
//! 7. Wakeup Logic
//!************************************************
// We need to generate a wakeup pulse for the LSU IID when a translation completes.
// Completion occurs when:
// 1. Fresh Refill Wins Arbitration (PTW or JTLB)
// 2. Fresh Refill has Exception (PTW or JTLB) - doesn't write RAM but finishes flow
// 3. WFI Entry Wins Arbitration

logic [11:0] wakeup_vec_next;
logic	     mb_have_free;
logic	     ptw_ref_fualt;
logic	     l2tlb_ref_fault;
logic	     l1dtlb_expt_for_taken;

assign ptw_ref_fault = (ptw_l1dtlb_ref_cmplt && req_ptw_expt && !req_ptw_aborted);
assign l2tlb_ref_fault = (jtlb_dutlb_ref_cmplt && req_jtlb_expt && !req_jtlb_aborted);

assign l1dtlb_expt_for_taken = ptw_ref_fault | l2tlb_ref_fault;

assign mb_have_free  =  |(~mb_entry_vld);

assign wakeup_vec_next = {12{mb_have_free}}    & {12{1'b1}}
		       | {12{l1dtlb_expt_for_taken}} & {12{1'b1}};



//always_comb begin
//    wakeup_vec_next = '0;
//    
//    // --- 1. Fresh PTW ---
//    // If it wins OR if it faulted (but wasn't aborted)
//    if ((sel_ptw) || (ptw_l1dtlb_ref_cmplt && req_ptw_expt && !req_ptw_aborted)) begin
//        wakeup_vec_next[mb_entry_iid[id_ptw] % 12] = 1'b1;
//    end
//    
//    // --- 2. Fresh JTLB ---
//    // If it wins OR if it faulted (but wasn't aborted)
//    if ((sel_jtlb) || (jtlb_dutlb_ref_cmplt && req_jtlb_expt && !req_jtlb_aborted)) begin
//        wakeup_vec_next[mb_entry_iid[id_jtlb] % 12] = 1'b1;
//    end
//    
//    // --- 3. WFI ---
//    // Only if it wins (WFI entries don't carry exceptions, exceptions are handled immediately upon arrival)
//    if (sel_wfi) begin
//        wakeup_vec_next[mb_entry_iid[id_wfi] % 12] = 1'b1;
//    end
//end

always_ff @(posedge install_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        mmu_lsu_tlb_wakeup <= 12'b0;
    end else begin
        mmu_lsu_tlb_wakeup <= wakeup_vec_next;
    end
end

endmodule


