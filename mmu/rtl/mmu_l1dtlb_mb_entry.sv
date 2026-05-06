//!********************************************************************
//!  OpenRiscv2030
//!
//!    L1DTLB Miss Buffer Entry with FSM (Non-blocking Refill Support)
//!    Features:
//!    - WFI state for refill collision handling
//!    - Load/Store attribute storage for L2TLB requests
//!********************************************************************

module mmu_l1dtlb_mb_entry #(
    parameter VPN_WIDTH  = 27,
    parameter PPN_WIDTH  = 28,
    parameter FLG_WIDTH  = 14,
    parameter IID_WIDTH  = 7,
    parameter PORT_WIDTH = 1
)(
    //! Clock and Reset
    input  logic                     cpurst_b,
    input  logic                     forever_cpuclk,
    input  logic                     mb_clk,
    input  logic                     cp0_mmu_icg_en,
    input  logic                     pad_yy_icg_scan_en,

    //! Allocate Interface (from Allocator/Mux)
    input  logic                     alloc_vld,
    input  logic [VPN_WIDTH-1:0]     alloc_vpn,
    input  logic [IID_WIDTH-1:0]     alloc_iid,
//    input  logic [PORT_WIDTH-1:0]    alloc_port_id,
    input  logic                     alloc_store,       // New: Store attribute input

    //! Issue Interface (from Scheduler)
    input  logic                     issue_sel,
    input  logic                     issue_grant,
    
    //! Refill/Response Interface
    input  logic                     refill_vld,        // Data valid from L2/PTW
    input  logic                     refill_gnt,        // Permission to write to L1TLB RAM
    input  logic                     refill_pgflt,
    input  logic                     refill_acflt,
    input  logic [PPN_WIDTH-1:0]     refill_ppn,        // Data payload
    input  logic [FLG_WIDTH-1:0]     refill_flg,        // Data payload
    input  logic [2:0]		     refill_pgs,
    input  logic                     expt_hit,

    //! Flush/Invalidation
    input  logic                     rtu_yy_xx_flush,
    input  logic                     tlboper_utlb_clr,
    input  logic                     tlboper_utlb_inv_va_req,
    input  logic [VPN_WIDTH-1:0]     lsu_mmu_tlb_va,

    //! Entry Status Outputs
    output logic                     entry_vld,
    output logic [2:0]               entry_state,
    output logic [VPN_WIDTH-1:0]     entry_vpn,
    output logic [PPN_WIDTH-1:0]     entry_ppn,         // Output latched PPN
    output logic [FLG_WIDTH-1:0]     entry_flg,         // Output latched Flags
    output logic [IID_WIDTH-1:0]     entry_iid,
    output logic [2:0]		     entry_pgs,
    //output logic [PORT_WIDTH-1:0]    entry_port_id,
    output logic                     entry_store,       // New: Store attribute output
    output logic                     entry_issued,
    output logic                     entry_ready,
    output logic                     entry_wfc,
    output logic                     entry_wfi          // Requesting Install
);

//!************************************************
//! State Encoding
//!************************************************
localparam STATE_IDLE  = 3'b000;
localparam STATE_WFG   = 3'b001;  // Wait For Grant (Ready to issue)
localparam STATE_WFC   = 3'b010;  // Wait For Complete
localparam STATE_PGFLT = 3'b011;  // Page Fault
localparam STATE_ACFLT = 3'b100;  // Access Fault
localparam STATE_ABT   = 3'b101;  // Aborted
localparam STATE_WFI   = 3'b110;  // Wait For Install (Collision handling)

//!************************************************
//! Entry Storage Registers
//!************************************************
logic [2:0]             state_r;
logic [VPN_WIDTH-1:0]   vpn_r;
logic [PPN_WIDTH-1:0]   ppn_r;
logic [FLG_WIDTH-1:0]   flg_r;
logic [IID_WIDTH-1:0]   iid_r;
logic [2:0]		pgs_r;
//logic [PORT_WIDTH-1:0]  port_id_r;
logic                   store_r;    // New: Register to hold store attribute
logic                   issued_r;
logic                   abort_hold_r;
logic                   fault_hold_r;

//!************************************************
//! Control Signals
//!************************************************
logic entry_clk_en;
logic inv_hit;
logic abort_this_cyc;

//!************************************************
//! Clock Gating
//!************************************************
gated_clk_cell x_mb_entry_gateclk (
    .clk_in             (forever_cpuclk),
    .clk_out            (/* unused */),
    .external_en        (1'b0),
    .global_en          (1'b1),
    .local_en           (entry_clk_en),
    .module_en          (cp0_mmu_icg_en),
    .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//!************************************************
//! Invalidation / Abort Logic
//!************************************************
// Abort if flush/global clear occurs OR if a TLB invalidation targets this VPN
// while active.
assign inv_hit = tlboper_utlb_inv_va_req && (lsu_mmu_tlb_va == vpn_r) && (state_r != STATE_IDLE);
assign abort_this_cyc = rtu_yy_xx_flush || tlboper_utlb_clr || inv_hit;

//!************************************************
//! State Machine
//!************************************************
logic [2:0] state_nxt;

always_comb begin
    state_nxt = state_r;
    
    case (state_r)
	STATE_IDLE: begin
            if (alloc_vld) begin
                // [FIX 2]: Check for immediate Bypass Grant
                if (issue_sel && issue_grant) begin
                    state_nxt = STATE_WFC; // Bypass: Skip WFG, go directly to Wait Complete
                end else begin
                    state_nxt = STATE_WFG; // Normal: Go to Wait Grant
                end
            end
        end	
        
        STATE_WFG: begin
            if (abort_this_cyc) begin
                if (issue_sel && issue_grant) begin
                    // Race condition: Granted and Aborted same cycle -> go to ABT
                    state_nxt = STATE_ABT;
                end else begin
                    state_nxt = STATE_IDLE;
                end
            end else if (issue_sel && issue_grant) begin
                // Successfully issued to L2TLB
                state_nxt = STATE_WFC;
            end
        end
        
        STATE_WFC: begin
            if (abort_this_cyc && refill_vld) begin
                state_nxt = STATE_IDLE;
            end else if (refill_vld) begin
                // [Priority 1]: Aborted previously
                if (abort_hold_r) begin
                    state_nxt = STATE_IDLE;
                end 
                // [Priority 2]: Faults (No install needed, go to exception handling)
                else if (refill_pgflt) begin
                    state_nxt = STATE_PGFLT;
                end else if (refill_acflt) begin
                    state_nxt = STATE_ACFLT;
                end 
                // [Priority 3]: Successful Refill
                else begin
                    if (refill_gnt) begin
                        // Collision Winner: Write to L1TLB RAM immediately
                        state_nxt = STATE_IDLE; 
                    end else begin
                        // Collision Loser: Latch data and wait for install arbitration
                        state_nxt = STATE_WFI; 
                    end
                end
            end else if (abort_this_cyc) begin
                state_nxt = STATE_ABT;
            end
        end

        STATE_WFI: begin
            if (abort_this_cyc) begin
                // Flush occurred while waiting to install
                state_nxt = STATE_IDLE;
            end else if (refill_gnt) begin
                // Finally granted permission to write to L1TLB
                state_nxt = STATE_IDLE;
            end
        end
        
        STATE_PGFLT: begin
            if (abort_this_cyc)
                state_nxt = STATE_IDLE;
            else if (expt_hit)
                state_nxt = STATE_IDLE;
        end

        STATE_ACFLT: begin
            if (abort_this_cyc)
                state_nxt = STATE_IDLE;
            else if (expt_hit)
                state_nxt = STATE_IDLE;
        end
        
        STATE_ABT: begin
            if (refill_vld) begin
                // Late arrival for aborted request -> Clear entry
                state_nxt = STATE_IDLE;
            end
        end
        
        default: state_nxt = STATE_IDLE;
    endcase
end

//!************************************************
//! State Register Update
//!************************************************
always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        state_r <= STATE_IDLE;
    end else begin
        state_r <= state_nxt;
    end
end

//!************************************************
//! Data Storage (VPN, PPN, Flags, IID, Store)
//!************************************************
always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        vpn_r     <= '0;
        iid_r     <= '0;
//        port_id_r <= '0;
        store_r   <= 1'b0;
        ppn_r     <= '0;
        flg_r     <= '0;
	pgs_r	  <= '0;
    end else begin
        // Allocation Phase: Capture Request Info
        if (alloc_vld && state_r == STATE_IDLE) begin
            vpn_r     <= alloc_vpn;
            iid_r     <= alloc_iid;
//            port_id_r <= alloc_port_id;
            store_r   <= alloc_store;   // Capture Store Attribute
        end
        
        // Refill Phase: Capture Response Info
        // When transitioning to WFI, we must save the transient L2/PTW data
        // because the input bus will change in the next cycle.
        if ((state_r == STATE_WFC) && refill_vld && !refill_gnt) begin
            ppn_r <= refill_ppn;
            flg_r <= refill_flg;
	    pgs_r <= refill_pgs;
        end
    end
end

//!************************************************
//! Control Flags (Issued, Abort Hold)
//!************************************************
always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        issued_r <= 1'b0;
    end else if (state_r == STATE_IDLE) begin
        // [FIX]: Set issued flag if bypassed immediately
        if (alloc_vld && issue_sel && issue_grant) begin
            issued_r <= 1'b1;
        end else begin
            issued_r <= 1'b0;
        end
    end else if (state_r == STATE_WFG && issue_sel && issue_grant) begin
        // Set issued flag if issued from WFG
        issued_r <= 1'b1;
    end
end

always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        abort_hold_r <= 1'b0;
    end else if (state_r == STATE_WFC && abort_this_cyc) begin
        abort_hold_r <= 1'b1;
    end else if (state_r == STATE_IDLE || state_nxt == STATE_IDLE) begin
        abort_hold_r <= 1'b0;
    end
end

always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        fault_hold_r <= 1'b0;
    end else if (state_r == STATE_WFC && refill_vld && (refill_pgflt || refill_acflt)) begin
        fault_hold_r <= 1'b1;
    end else if (((state_r == STATE_PGFLT) || (state_r == STATE_ACFLT)) && expt_hit) begin
        fault_hold_r <= 1'b0;
    end else if (state_r == STATE_IDLE || state_nxt == STATE_IDLE) begin
        fault_hold_r <= 1'b0;
    end
end

//!************************************************
//! Output Assignments
//!************************************************
assign entry_vld     = (state_r != STATE_IDLE);
assign entry_state   = state_r;

// Request Info
assign entry_vpn     = vpn_r;
assign entry_iid     = iid_r;
//assign entry_port_id = port_id_r;
assign entry_store   = store_r;      // Output Store Attribute
assign entry_issued  = issued_r;

// Response Info (Latched data for Install logic)
assign entry_ppn     = ppn_r; 
assign entry_flg     = flg_r;
assign entry_pgs     = pgs_r;

// Ready to issue: in WFG state and not aborted this cycle
assign entry_ready   = (state_r == STATE_WFG) && !abort_this_cyc && !fault_hold_r;

// Wait for complete (Top logic uses this to track busy status)
assign entry_wfc     = (state_r == STATE_WFC) || (state_r == STATE_ABT);

// Requesting Install (Collision handling)
assign entry_wfi     = (state_r == STATE_WFI);

// Clock enable: Active if valid or allocating or refilling
assign entry_clk_en  = alloc_vld || (state_r != STATE_IDLE) || refill_vld;

endmodule
