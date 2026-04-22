//=============================================================================
// Module: mmu_l2tlb_reqq_entry
// Description: Single entry for L2TLB Request Queue.
//              Stores request payload and manages Valid/Sent lifecycle.
//=============================================================================

module mmu_l2tlb_reqq_entry#(
	
    parameter VPN_W  = 27,
    parameter ASID_W = 5,
    parameter EID_W  = 2,    // Width for Miss Buffer ID
    parameter TYPE_W = 2     // Width for Request Type
)(
    // Global Signals
    input  logic                cp0_mmu_icg_en,         // Clock Gating Enable from CP0
    input  logic                cpurst_b,               // Active Low Async Reset
    input  logic                reqq_clk,               // Global Clock
    input  logic                pad_yy_icg_scan_en,     // Scan Test Enable

    // Allocation Interface (Write)
    input  logic                entry_alloc_en,         // Write Enable (Allocate)
    input  logic [VPN_W-1:0]    alloc_vpn,
    //input  logic [ASID_W-1:0]   alloc_asid,
    input  logic [EID_W-1:0]    alloc_eid,
    input  logic [TYPE_W-1:0]   alloc_type,

    // Issue Interface (Read/Status)
    input  logic                issue_grant,            // Arbiter grants this entry (Normal Issue)
    
    // [NEW] Bypass Interface
    input  logic                bypass_grant,           // Arbiter granted the bypass request during allocation
   
    // Feedback Interface (State Update)
    input  logic                fb_match_id,            // Feedback ID matches this entry
    input  logic                fb_hit,                 // L2TLB Hit
    input  logic                fb_miss_alloc,          // L2TLB Miss & Buffer Allocated
    input  logic                fb_miss_retry,          // L2TLB Miss & Buffer Full (Retry)

    // Output Status & Payload
    output logic                entry_vld,              // Entry is Valid
    output logic                entry_rdy,              // Entry is Ready (Valid & !Sent)
    output logic                entry_dealloc,          // Pulse for Credit Return
    
    // Flattened Payload Output
    output logic [VPN_W-1:0]    entry_out_vpn,
    output logic [ASID_W-1:0]   entry_out_asid,
    output logic [EID_W-1:0]    entry_out_eid,
    output logic [TYPE_W-1:0]   entry_out_type
);

    // &Regs; 
    //-------------------------------------------------------------------------
    // Register Definitions
    //-------------------------------------------------------------------------
    logic [VPN_W-1:0]   entry_vpn;
    logic [ASID_W-1:0]  entry_asid;
    logic [EID_W-1:0]   entry_eid;
    logic [TYPE_W-1:0]  entry_type;

    logic               r_vld;
    logic               r_sent;

    // &Wires;
    //-------------------------------------------------------------------------
    // Wire Definitions
    //-------------------------------------------------------------------------
    logic               entry_clk_en;       // Gating condition
    logic               entry_clk;          // Gated Clock
    logic               entry_clr;          // Clear Valid condition
    logic               sent_set;           // Set Sent condition
    logic               sent_clr;           // Clear Sent condition (Retry)

    //=========================================================================
    // 1. Clock Gating Logic
    //=========================================================================
    // Clock enables when:
    // - Allocating new data (write)
    // - Issuing to pipeline (update Sent bit)
    // - Receiving feedback (update Valid/Sent bit)
    assign entry_clk_en = entry_alloc_en 
                        | issue_grant 
                        | fb_match_id;

    // &Instance("gated_clk_cell", "x_reqq_entry_gateclk");
    gated_clk_cell x_reqq_entry_gateclk (
        .clk_in             (reqq_clk           ),
        .clk_out            (entry_clk          ),
        .external_en        (1'b0               ),
        .global_en          (1'b1               ),
        .local_en           (entry_clk_en       ),
        .module_en          (cp0_mmu_icg_en     ),
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en )
    );

    //=========================================================================
    // 2. Valid Bit Logic
    //=========================================================================
    // Deallocate when feedback returns Success (Hit or Alloc Miss Buffer)
    assign entry_clr = fb_match_id && (fb_hit || fb_miss_alloc);

    always @(posedge entry_clk or negedge cpurst_b) begin
        if (!cpurst_b)
            r_vld <= 1'b0;
        else if (entry_clr)
            r_vld <= 1'b0;
        else if (entry_alloc_en)
            r_vld <= 1'b1;
    end

    //=========================================================================
    // 3. Sent Bit Logic [CRITICAL UPDATE]
    //=========================================================================
    // Sent=1: Request is in L2 pipeline.
    // Sent=0: Request is waiting in Queue (Ready).
    
    // Set when granted by Arbiter (Normal Queue Issue)
    assign sent_set = issue_grant;
    
    // Clear ONLY when Retry Feedback occurs. 
    // [CHANGE]: Removed 'entry_alloc_en' from here, handled in priority logic below.
    assign sent_clr = entry_dealloc | (fb_match_id && fb_miss_retry);

    always @(posedge entry_clk or negedge cpurst_b) begin
        if (!cpurst_b)
            r_sent <= 1'b0;
        // Priority 1: New Allocation (Highest Priority for initialization)
        else if (entry_alloc_en) 
            // If Bypass was granted during allocation, init as Sent=1.
            // Otherwise, init as Sent=0 (Ready to issue later).
            r_sent <= bypass_grant; 
        // Priority 2: Retry Feedback (Reset to 0 to re-issue)
        else if (sent_clr)
            r_sent <= 1'b0;
        // Priority 3: Normal Issue Grant (Set to 1)
        else if (sent_set)
            r_sent <= 1'b1;
    end

    //=========================================================================
    // 4. Payload Storage (Gated Clock)
    //=========================================================================
    always @(posedge entry_clk or negedge cpurst_b) begin
        if (!cpurst_b) begin
            entry_vpn  <= {VPN_W{1'b0}};
            entry_asid <= {ASID_W{1'b0}};
            entry_eid  <= {EID_W{1'b0}};
            entry_type <= {TYPE_W{1'b0}};
        end
        else if (entry_alloc_en) begin
            entry_vpn  <= alloc_vpn;
            //entry_asid <= alloc_asid;
            entry_eid  <= alloc_eid;
            entry_type <= alloc_type;
        end
    end

    //=========================================================================
    // 5. Output Generation
    //=========================================================================
    assign entry_vld      = r_vld;
    
    // Ready condition: Valid AND Not Sent yet
    assign entry_rdy      = r_vld && !r_sent;
    
    assign entry_dealloc  = r_vld && entry_clr;

    // Payload output
    assign entry_out_vpn  = entry_vpn;
    assign entry_out_asid = entry_asid;
    assign entry_out_eid  = entry_eid;
    assign entry_out_type = entry_type;

endmodule


