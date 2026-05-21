//=============================================================================
// Module: mmu_l2tlb_mb_entry
// Description: Single entry for L2TLB Miss Buffer.
//              Stores request payload and manages Valid/Sent lifecycle.
//=============================================================================

module mmu_l2tlb_mb_entry#(

    parameter VPN_WIDTH  = 27,
    //parameter ASID_WIDTH = 5,
    parameter L1EID_WIDTH  = 3,    // Width for Miss Buffer ID
    parameter QUE_ID_WIDTH = 4,
    parameter PTW_TYPE_WIDTH = 3     // Width for Request Type


)(
    // Global Signals
    input  logic                cp0_mmu_icg_en,         // Clock Gating Enable from CP0
    input  logic                cpurst_b,               // Active Low Async Reset
    input  logic                reqq_clk,               // Global Clock
    input  logic                pad_yy_icg_scan_en,     // Scan Test Enable
    input  logic                tlboper_ptw_abort,       // PTW Abort

    // Allocation Interface (Write)
    input  logic                entry_alloc_en,         // Write Enable (Allocate)
    input  logic [VPN_WIDTH-1:0]    alloc_vpn,
    //input  logic [ASID_W-1:0]   alloc_asid,
    input  logic [L1EID_WIDTH-1:0]    alloc_l1eid,
    input  logic [PTW_TYPE_WIDTH-1:0]   alloc_type,
    input  logic [QUE_ID_WIDTH-1:0] alloc_queue_id,

    // Issue Interface (Read/Status)
    input  logic                issue_grant,            // Arbiter grants this entry (Normal Issue)
    
    // [NEW] Bypass Interface
    input  logic                bypass_grant,           // Arbiter granted the bypass request during allocation
    
    // Feedback Interface (State Update)
    input  logic                fb_match_id,            // Feedback ID matches this entry
    input  logic                fb_hit,                 // 
    //input  logic                fb_miss_alloc,          // 
    //input  logic                fb_miss_retry,          // 

    // Output Status & Payload
    output logic                entry_vld,              // Entry is Valid
    output logic                entry_rdy,              // Entry is Ready (Valid & !Sent)
    output logic                entry_dealloc,          // 
    
    // Flattened Payload Output
    output logic [VPN_WIDTH-1:0]    entry_out_vpn,
    //output logic [ASID_W-1:0]   entry_out_asid,
    output logic [L1EID_WIDTH-1:0]    entry_out_l1eid,
    output logic [QUE_ID_WIDTH-1:0] entry_out_queue_id,
    output logic [PTW_TYPE_WIDTH-1:0]   entry_out_type
);

    // &Regs; 
    //-------------------------------------------------------------------------
    // Register Definitions
    //-------------------------------------------------------------------------
    logic [VPN_WIDTH-1:0]   entry_vpn;
    //logic [ASID_W-1:0]  entry_asid;
    logic [L1EID_WIDTH-1:0]   entry_eid;
    logic [PTW_TYPE_WIDTH-1:0]  entry_type;

    logic               r_vld;
    logic               r_sent;

    logic [L1EID_WIDTH-1:0] entry_l1eid;
    logic [QUE_ID_WIDTH-1:0] entry_queue_id;
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
    // - Aborting PTW pipeline (clear Sent bit for retry)
    assign entry_clk_en = entry_alloc_en 
                        | issue_grant 
                        | fb_match_id
                        | tlboper_ptw_abort;

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
    assign entry_clr = fb_match_id && fb_hit;

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
    // Sent=1: Request is in PTW pipeline.
    // Sent=0: Request is waiting in miss buffer (Ready).
    
    // Set when granted by Arbiter (Normal Queue Issue)
    assign sent_set = issue_grant;
    
    // Clear ONLY when Retry Feedback occurs. 
    // [CHANGE]: Removed 'entry_alloc_en' from here, handled in priority logic below.
    assign sent_clr = entry_dealloc |  tlboper_ptw_abort;//| fb_match_id 

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
            entry_vpn  <= {VPN_WIDTH{1'b0}};
            //entry_asid <= {ASID_W{1'b0}};
            entry_l1eid  <= {L1EID_WIDTH{1'b0}};
            entry_type <= {PTW_TYPE_WIDTH{1'b0}};
	    entry_queue_id <= {QUE_ID_WIDTH{1'b0}};
        end
        else if (entry_alloc_en) begin
            entry_vpn      <= alloc_vpn;
            //entry_asid     <= alloc_asid;
            entry_l1eid    <= alloc_l1eid;
            entry_type     <= alloc_type;
	    entry_queue_id <= alloc_queue_id;
        end
    end

    //=========================================================================
    // 5. Output Generation
    //=========================================================================
    assign entry_vld      = r_vld;
    
    // Ready condition: Valid AND Not Sent yet
    assign entry_rdy      = r_vld && !r_sent;
    
    assign entry_dealloc  = r_vld && entry_clr;//when ptw complete and 

    // Payload output
    assign entry_out_vpn      =   entry_vpn;
    //assign entry_out_asid     =   entry_asid;
    assign entry_out_l1eid    =   entry_l1eid;
    assign entry_out_type     =   entry_type;
    assign entry_out_queue_id =   entry_queue_id;

endmodule

