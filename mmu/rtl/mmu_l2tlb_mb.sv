//=============================================================================
// Module: mmu_l2tlb_mb
// Description: L2TLB Miss Buffer (Integrates 1 ITLB Entry + 8 DTLB Entries)
//=============================================================================
module mmu_l2tlb_mb #(
    //-------------------------------------------------------------------------
    // Parameters (Move to Header to fix port width dependency)
    //-------------------------------------------------------------------------
    parameter DTLB_DEPTH     = 8,
    parameter VPN_WIDTH      = 27,
    parameter L1EID_WIDTH    = 3,
    parameter L2EID_WIDTH    = 3,
    parameter PTW_TYPE_WIDTH = 3, // 2 bits for Load/Store/Fetch
    parameter QUE_ID_WIDTH   = 3,
    parameter ACC_TYPE_WIDTH = 3  // Fixed typo: TPYE -> TYPE
)(
    // Global Signals
    input  logic                      cp0_mmu_icg_en,
    input  logic                      cpurst_b,
    input  logic                      reqq_clk,
    input  logic                      pad_yy_icg_scan_en,

    input  logic                      tlboper_ptw_abort,

    //-------------------------------------------------------------------------
    // 1. L2TLB Interface (Input)
    //-------------------------------------------------------------------------
    input  logic                      req_valid,
    input  logic [VPN_WIDTH-1:0]      req_vpn,
    input  logic [L1EID_WIDTH-1:0]    req_l1eid,
    // input logic [QUE_ID_WIDTH-1:0] req_l2_queue_id, // Unused in original code?
    input  logic [ACC_TYPE_WIDTH-1:0] req_acc_type,
    input  logic                      req_is_dtlb,

    output logic                      req_alloc_valid,

    //-------------------------------------------------------------------------
    // 2. Interface to PTW (Output)
    //-------------------------------------------------------------------------
    output logic                      issue_req,       // Request to PTW
    // Localparam Derived Parameters need special handling in ports if used.
    // For simplicity, defining ID_WIDTH locally later, but output needs fixed width.
    // Assuming ID_WIDTH is roughly 4 bits ($clog2(9)). 
    // Recommended: Pass ID_WIDTH as parameter if it changes port size.
    output logic [L1EID_WIDTH+L2EID_WIDTH-1:0]                issue_eid,       // Hardcoded for safety, or use param
    output logic                      issue_is_dtlb,   
    output logic [VPN_WIDTH-1:0]      issue_vpn,
    output logic [PTW_TYPE_WIDTH-1:0] issue_type,      
    
    input  logic                      ptw_ready,      

    //-------------------------------------------------------------------------
    // 3. Feedback Interface (from PTW)
    //-------------------------------------------------------------------------
    input  logic                      fb_valid,        // ptw complete
    input  logic [2:0]                fb_trans_id,     // Matching issue_eid width
    input  logic                      fb_hit           // same as fb_valid
);

    //-------------------------------------------------------------------------
    // Internal Constants (Derived)
    //-------------------------------------------------------------------------
    localparam TOTAL_DEPTH = 1 + DTLB_DEPTH;
    localparam ID_WIDTH    = $clog2(TOTAL_DEPTH); // = 4

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    // Allocation Control
    logic [DTLB_DEPTH-1:0]      dtlb_alloc_oh;    
    logic [TOTAL_DEPTH-1:0]     alloc_en_vec;     
    
    // Entry Status Vectors
    logic [TOTAL_DEPTH-1:0]     entry_vld_vec;
    logic [TOTAL_DEPTH-1:0]     entry_rdy_vec;
    logic [TOTAL_DEPTH-1:0]     entry_dealloc_vec;
    
    // Arbitration Control
    logic [TOTAL_DEPTH-1:0]     ffr_oh;           
    logic [TOTAL_DEPTH-1:0]     entry_grant_vec; 
    logic                       entry_ready;

    // Payload Arrays (Missing in original code)
    logic [VPN_WIDTH-1:0]       entry_out_vpn      [TOTAL_DEPTH-1:0];
    logic [L1EID_WIDTH-1:0]     entry_out_l1eid    [TOTAL_DEPTH-1:0];
    logic [PTW_TYPE_WIDTH-1:0]  entry_out_type     [TOTAL_DEPTH-1:0];
    logic [QUE_ID_WIDTH-1:0]    entry_out_queue_id [TOTAL_DEPTH-1:0];

    // Mux Signals
    logic [VPN_WIDTH-1:0]       entry_rdy_vpn;
    logic [L1EID_WIDTH-1:0]     entry_rdy_eid;
    logic [PTW_TYPE_WIDTH-1:0]  entry_rdy_type;
    logic                       entry_rdy_is_dtlb;

    // Helper Signals (Previously Undeclared)
    logic [DTLB_DEPTH-1:0]      therm_vld;
    logic [ID_WIDTH-1:0]        dtlb_alloc_index; // Fixed spelling
    logic                       mb_dtlb_full;

    //=========================================================================
    // 1. Allocation Logic (Write Control)
    //=========================================================================

    // ITLB Allocation (Always Entry 0)
    assign alloc_en_vec[0] = req_valid & !req_is_dtlb & !entry_vld_vec[0];

    // DTLB Allocation (Entries 1 to 8) - Find First Zero
    generate
        genvar j;
        // Thermometer code for valid entries (Entry 1 is bit 0 of DTLB)
        assign therm_vld[0] = entry_vld_vec[1];
        for(j = 1; j < DTLB_DEPTH; j++) begin : gener_therm
            assign therm_vld[j] = therm_vld[j-1] & entry_vld_vec[j+1];
        end
        
        // One-hot free slot generation
        assign dtlb_alloc_oh[0] = ~therm_vld[0];
        for(j = 1; j < DTLB_DEPTH; j++) begin : gener_onehot
            assign dtlb_alloc_oh[j] = therm_vld[j-1] & ~therm_vld[j];
        end
    endgenerate

    // Encoder: One-Hot to Binary Index (Offset by 1 because 0 is ITLB)
    always_comb begin
        dtlb_alloc_index = {ID_WIDTH{1'b0}};
        for(integer index = 0; index < DTLB_DEPTH; index++)  
            if(dtlb_alloc_oh[index]) begin 
                dtlb_alloc_index = index[ID_WIDTH-1:0] + 1'b1;
            end
    end

    // DTLB Allocation Enable
    assign mb_dtlb_full = &entry_vld_vec[TOTAL_DEPTH-1:1]; // Fixed range index
    assign alloc_en_vec[TOTAL_DEPTH-1:1] = (req_valid & req_is_dtlb & !mb_dtlb_full) ? dtlb_alloc_oh : {DTLB_DEPTH{1'b0}};

    //=========================================================================
    // 2. Entry Instantiation
    //=========================================================================
    generate
        for (genvar i = 0; i < TOTAL_DEPTH; i++) begin : gen_entries
            
            logic [VPN_WIDTH-1:0]      local_alloc_vpn;
            logic [L1EID_WIDTH-1:0]    local_alloc_l1eid;
            logic [PTW_TYPE_WIDTH-1:0] local_alloc_type;
            logic [QUE_ID_WIDTH-1:0]   local_alloc_l2_queue_id; // Added semi-colon

            // Mux Logic for Alloc Data
            if (i == 0) begin : gen_mux_itlb
                assign local_alloc_l1eid = {L1EID_WIDTH{1'b0}}; 
                // Assign other signals for ITLB if needed
                assign local_alloc_vpn   = req_vpn; 
                assign local_alloc_type  = req_acc_type[PTW_TYPE_WIDTH-1:0]; // Assuming mapping
                assign local_alloc_l2_queue_id = {QUE_ID_WIDTH{1'b0}};
            end else begin : gen_mux_dtlb
                assign local_alloc_l1eid = req_l1eid;
                assign local_alloc_vpn   = req_vpn;
                assign local_alloc_type  = req_acc_type[PTW_TYPE_WIDTH-1:0];
                assign local_alloc_l2_queue_id = {QUE_ID_WIDTH{1'b0}}; // Or map input if available
            end

            // Instantiation (Fixed Parameter Names)
            mmu_l2tlb_mb_entry #(
                .VPN_WIDTH      (VPN_WIDTH),
                .L1EID_WIDTH    (L1EID_WIDTH),
                .PTW_TYPE_WIDTH (PTW_TYPE_WIDTH),
                .QUE_ID_WIDTH   (QUE_ID_WIDTH)
            ) x_mb_entry (
                // Global
                .cp0_mmu_icg_en     (cp0_mmu_icg_en),
                .cpurst_b           (cpurst_b),
                .reqq_clk           (reqq_clk),
                .pad_yy_icg_scan_en (pad_yy_icg_scan_en),

                .tlboper_ptw_abort          (tlboper_ptw_abort),

                // Alloc
                .entry_alloc_en     (alloc_en_vec[i]),
                .alloc_vpn          (local_alloc_vpn),
                .alloc_l1eid        (local_alloc_l1eid),
                .alloc_type         (local_alloc_type),
                .alloc_queue_id     (local_alloc_l2_queue_id),

                // Issue
                .issue_grant        (entry_grant_vec[i]),
                .bypass_grant       (ptw_ready & !entry_ready), // Logic: Bypass if Buffer Empty

                // Feedback
                .fb_match_id        (fb_valid && (fb_trans_id == i[ID_WIDTH-1:0])),
                .fb_hit             (fb_hit),

                // Outputs
                .entry_vld          (entry_vld_vec[i]),
                .entry_rdy          (entry_rdy_vec[i]),
                .entry_dealloc      (entry_dealloc_vec[i]),
                
                .entry_out_vpn      (entry_out_vpn[i]),
                .entry_out_l1eid    (entry_out_l1eid[i]),
                .entry_out_type     (entry_out_type[i]),
                .entry_out_queue_id (entry_out_queue_id[i])
            );
        end
    endgenerate

    //=========================================================================
    // 3. Arbitration Logic (Issue Control)
    //=========================================================================
    logic [TOTAL_DEPTH-1:0] ffr_therm; // Declared missing signal

    generate
        genvar k; // Use different loop variable
        assign ffr_therm[0] = entry_rdy_vec[0]; 
        for(k = 1; k < TOTAL_DEPTH; k++) begin : gene_therm
            assign ffr_therm[k] = entry_rdy_vec[k] | ffr_therm[k-1];
        end

        assign ffr_oh[0] = ffr_therm[0];
        for(k = 1; k < TOTAL_DEPTH; k++) begin : gene_onehot
            assign ffr_oh[k] = ffr_therm[k] & ~ffr_therm[k-1];
        end
    endgenerate
     
    assign entry_grant_vec = ffr_oh & {TOTAL_DEPTH{ptw_ready}};
    assign entry_ready     = |entry_rdy_vec; 
    assign issue_req       = entry_ready | req_valid;

    //=========================================================================
    // 4. Output Mux Logic
    //=========================================================================
    logic [L2EID_WIDTH-1:0] entry_rdy_id;
    always_comb begin
        entry_rdy_vpn     = {VPN_WIDTH{1'b0}};
        entry_rdy_eid     = {L1EID_WIDTH{1'b0}};
        entry_rdy_type    = {PTW_TYPE_WIDTH{1'b0}};
        entry_rdy_is_dtlb = 1'b0;
	entry_rdy_id	  = {L2EID_WIDTH{1'b0}};

        for (int i = 0; i < TOTAL_DEPTH; i++) begin
            if (ffr_oh[i]) begin
                entry_rdy_vpn     = entry_out_vpn[i];
                entry_rdy_eid     = entry_out_l1eid[i];
                entry_rdy_type    = entry_out_type[i];
                entry_rdy_id    = i[L2EID_WIDTH-1:0];
                entry_rdy_is_dtlb = (i != 0); 
            end
        end
    end

    // Final Bypass Mux
    assign issue_vpn = entry_ready ? entry_rdy_vpn : 
                       req_valid   ? req_vpn : {VPN_WIDTH{1'b0}};

    assign issue_eid = entry_ready ?  {entry_rdy_id,entry_rdy_eid} : // Note: issue_eid width mismatch fix might be needed
                       (req_valid & req_is_dtlb) ? {dtlb_alloc_index,req_l1eid} : {(L1EID_WIDTH+L2EID_WIDTH){1'b0}};

    assign issue_type = entry_ready ? entry_rdy_type : 
                        req_valid   ? req_acc_type[PTW_TYPE_WIDTH-1:0] : {PTW_TYPE_WIDTH{1'b0}}; // Fixed typo

    assign issue_is_dtlb = entry_ready ? entry_rdy_is_dtlb : 
                           (req_valid & req_is_dtlb) ? 1'b1 : 1'b0;

    assign req_alloc_valid = req_valid & |alloc_en_vec;

// synopsys translate_off
logic mmu_itlb_dbg_en;
int unsigned mmu_itlb_dbg_stuck_cycles;

initial begin
  mmu_itlb_dbg_en = $test$plusargs("MMU_ITLB_DBG");
end

always_ff @(posedge reqq_clk or negedge cpurst_b) begin
  if (!cpurst_b) begin
    mmu_itlb_dbg_stuck_cycles <= 0;
  end else begin
    if (entry_vld_vec != '0) begin
      mmu_itlb_dbg_stuck_cycles <= mmu_itlb_dbg_stuck_cycles + 1;
    end else begin
      mmu_itlb_dbg_stuck_cycles <= 0;
    end

    if (mmu_itlb_dbg_en
        && ((!req_is_dtlb && req_valid)
            || issue_req
            || fb_valid
            || entry_dealloc_vec[0]
            || ((entry_vld_vec != '0) && (mmu_itlb_dbg_stuck_cycles[11:0] == 12'hfff)))) begin
      $display("[MMU_ITLB_DBG][L2MB] t=%0t stuck_cycles=%0d req_valid=%0b req_is_dtlb=%0b req_vpn=0x%07h req_type=0x%0h req_l1eid=0x%0h alloc_valid=%0b issue_req=%0b issue_vpn=0x%07h issue_type=0x%0h issue_eid=0x%02h issue_is_dtlb=%0b ptw_ready=%0b fb_valid=%0b fb_id=0x%0h fb_hit=%0b vld=0x%03h rdy=0x%03h dealloc=0x%03h e0_type=0x%0h e0_vpn=0x%07h e0_l1eid=0x%0h e1_type=0x%0h e1_vpn=0x%07h e1_l1eid=0x%0h",
               $time,
               mmu_itlb_dbg_stuck_cycles,
               req_valid,
               req_is_dtlb,
               req_vpn,
               req_acc_type,
               req_l1eid,
               req_alloc_valid,
               issue_req,
               issue_vpn,
               issue_type,
               issue_eid,
               issue_is_dtlb,
               ptw_ready,
               fb_valid,
               fb_trans_id,
               fb_hit,
               entry_vld_vec,
               entry_rdy_vec,
               entry_dealloc_vec,
               entry_out_type[0],
               entry_out_vpn[0],
               entry_out_l1eid[0],
               entry_out_type[1],
               entry_out_vpn[1],
               entry_out_l1eid[1]);
    end
  end
end
// synopsys translate_on

endmodule


