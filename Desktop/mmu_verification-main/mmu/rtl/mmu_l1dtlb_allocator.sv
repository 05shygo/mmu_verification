//!********************************************************************
//!  OpenRiscv2030
//!
//!    L1DTLB Miss Buffer Allocator
//!    Dual-port arbitration with oldest-first priority
//!********************************************************************

module mmu_l1dtlb_allocator #(
    parameter MB_DEPTH   = 8,
    parameter VPN_WIDTH  = 27,
    parameter IID_WIDTH  = 7,
    parameter PORT_WIDTH = 1
)(
    //! Clock and Reset
    input  logic                    cpurst_b,
    input  logic                    forever_cpuclk,
    
    //! Port 0 Request
    input  logic                    req0_vld,
    input  logic [VPN_WIDTH-1:0]    req0_vpn,
    input  logic [IID_WIDTH-1:0]    req0_iid,
    input  logic [PORT_WIDTH-1:0]   req0_port_id,
    
    //! Port 1 Request
    input  logic                    req1_vld,
    input  logic [VPN_WIDTH-1:0]    req1_vpn,
    input  logic [IID_WIDTH-1:0]    req1_iid,
    input  logic [PORT_WIDTH-1:0]   req1_port_id,
    
    //! Miss Buffer Valid Status
    input  logic [MB_DEPTH-1:0]     mb_vld,
    
    //! Allocation Grants
    output logic                    gnt0,
    output logic                    gnt1,
    output logic [$clog2(MB_DEPTH)-1:0] sel0,  // Which entry for port0
    output logic [$clog2(MB_DEPTH)-1:0] sel1,  // Which entry for port1
    //output logic		    port0_id,
    //output logic		    port1_id,
    
    //! Write Enable to MB Entries (one-hot)
    output logic [MB_DEPTH-1:0]     alloc_we
);

localparam EID_WIDTH = $clog2(MB_DEPTH);

//!************************************************
//! Free Slot Detection
//!************************************************
logic [MB_DEPTH-1:0] free_oh;
logic                have_a, have_b;
logic [EID_WIDTH-1:0] idx_a, idx_b;

// Free slots (inverted valid)
assign free_oh = ~mb_vld;

// Find first two free slots
always_comb begin
    have_a = 1'b0;
    have_b = 1'b0;
    idx_a  = '0;
    idx_b  = '0;
    
    // Find first free slot (idx_a)
    for (int i = 0; i < MB_DEPTH; i++) begin
        if (free_oh[i] && !have_a) begin
            have_a = 1'b1;
            idx_a  = i[EID_WIDTH-1:0];
        end
    end
    
    // Find second free slot (idx_b)
    for (int i = 0; i < MB_DEPTH; i++) begin
        if (free_oh[i] && have_a && (i[EID_WIDTH-1:0] != idx_a) && !have_b) begin
            have_b = 1'b1;
            idx_b  = i[EID_WIDTH-1:0];
        end
    end
end

//!************************************************
//! Age Comparison
//!************************************************
logic older0;  // Port0 is older than Port1

ct_rtu_compare_iid x_mmu_allocator_age_cmp (
    .x_iid0       (req0_iid),
    .x_iid0_older (older0),
    .x_iid1       (req1_iid)
);

//!************************************************
//! Allocation Arbitration Logic
//!************************************************
//!************************************************
//! Allocation Arbitration Logic (Optimized)
//!************************************************
// 1. Grant Generation (Parallel Boolean Logic)
//    - Port 0 grants if: Requesting AND Space Avail AND (No Contentions OR 2 slots OR Priority)
always_comb begin
    gnt0 = req0_vld && have_a && (!req1_vld || have_b ||  older0);
    gnt1 = req1_vld && have_a && (!req0_vld || have_b || !older0);
end

// 2. Index Selection Logic (Muxing)
//    - Default to first free slot (idx_a).
//    - Only take second slot (idx_b) if the OTHER port is valid AND OLDER (stealing the first slot).
always_comb begin
    // If Port 1 is valid and older, it takes idx_a, so Port 0 must take idx_b
    sel0 = (req1_vld && !older0) ? idx_b : idx_a; 
    
    // If Port 0 is valid and older, it takes idx_a, so Port 1 must take idx_b
    sel1 = (req0_vld &&  older0) ? idx_b : idx_a;
end

//!************************************************
//! Generate Write Enable (One-Hot)
//!************************************************
// This part remains standard, mapping the grants to the physical write lines
always_comb begin
    alloc_we = {MB_DEPTH{1'b0}}; // Default 0

    if (gnt0) alloc_we[sel0] = 1'b1;
    if (gnt1) alloc_we[sel1] = 1'b1;
end

//always_comb begin
//    // Default: no grant
//    gnt0 = 1'b0;
//    gnt1 = 1'b0;
//    sel0 = '0;
//    sel1 = '0;
//    
//    // Case 1: No request
//    if (!req0_vld && !req1_vld) begin
//        gnt0 = 1'b0;
//        gnt1 = 1'b0;
//    end
//    
//    // Case 2: No free slot available
//    else if (!have_a) begin
//        gnt0 = 1'b0;
//        gnt1 = 1'b0;
//    end
//    
//    // Case 3: Only port0 requests
//    else if (req0_vld && !req1_vld) begin
//        gnt0 = 1'b1;
//        sel0 = idx_a;
//    end
//    
//    // Case 4: Only port1 requests
//    else if (!req0_vld && req1_vld) begin
//        gnt1 = 1'b1;
//        sel1 = idx_a;
//    end
//    
//    // Case 5: Both ports request
//    else if (req0_vld && req1_vld) begin
//        if (have_b) begin
//            // Two free slots: allocate both based on age
//            if (older0) begin
//                // Port0 is older: give idx_a to port0, idx_b to port1
//                gnt0 = 1'b1;
//                gnt1 = 1'b1;
//                sel0 = idx_a;
//                sel1 = idx_b;
//            end else begin
//                // Port1 is older: give idx_a to port1, idx_b to port0
//                gnt0 = 1'b1;
//                gnt1 = 1'b1;
//                sel0 = idx_b;
//                sel1 = idx_a;
//            end
//        end else begin
//            // Only one free slot: give to older port
//            if (older0) begin
//                gnt0 = 1'b1;
//                gnt1 = 1'b0;
//                sel0 = idx_a;
//            end else begin
//                gnt0 = 1'b0;
//                gnt1 = 1'b1;
//                sel1 = idx_a;
//            end
//        end
//    end
//end
//
////!************************************************
////! Generate Write Enable (One-Hot)
////!************************************************
//always_comb begin
//    alloc_we = '0;
//    
//    if (gnt0) begin
//        alloc_we[sel0] = 1'b1;
//    end
//    
//    if (gnt1) begin
//        alloc_we[sel1] = 1'b1;
//    end
//end
//
endmodule


