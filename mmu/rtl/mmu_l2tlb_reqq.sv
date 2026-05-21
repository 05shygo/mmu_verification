//=============================================================================
// Module: mmu_l2tlb_reqq
// Description: L2TLB Request Queue Top Level.
//              - Integrates 1 ITLB Entry + 8 DTLB Entries.
//              - Handles Allocation (FFZ), Arbitration (FFR), and Credits.
//=============================================================================

module mmu_l2tlb_reqq#(
    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    parameter DTLB_DEPTH = 7,
    parameter VPN_W      = 27,
    parameter ASID_W     = 5,
    parameter EID_W      = 3,
    parameter TYPE_W     = 3,


    // Derived Parameters
    // Total = 1 (ITLB) + 8 (DTLB) = 9
    parameter TOTAL_DEPTH = 1 + DTLB_DEPTH,
    // ID Width = ceil(log2(9)) = 4 bits
    parameter ID_W        = 4



)(
    // Global Signals
    input  logic                cp0_mmu_icg_en,
    input  logic                cpurst_b,
    input  logic                reqq_clk,
    input  logic                pad_yy_icg_scan_en,

    //-------------------------------------------------------------------------
    // 1. L1 ITLB Interface (Allocate Entry 0)
    //-------------------------------------------------------------------------
    input  logic                i_req_valid,
    input  logic [VPN_W-1:0]    i_req_vpn,
    //input  logic [ASID_W-1:0]   i_req_asid,
    output logic                i_credit_return,

    //-------------------------------------------------------------------------
    // 2. L1 DTLB Interface (Allocate Entries 1-8)
    //-------------------------------------------------------------------------
    input  logic                d_req_valid,
    input  logic [VPN_W-1:0]    d_req_vpn,
    //input  logic [ASID_W-1:0]   d_req_asid,
    input  logic [EID_W-1:0]    d_req_eid,
    input  logic [TYPE_W-1:0]   d_req_type,
    output logic                d_credit_return,

    //-------------------------------------------------------------------------
    // 3. Issue Interface (to L2TLB Pipeline)
    //-------------------------------------------------------------------------
    output logic                issue_valid,      // Request to Arbiter
    output logic [ID_W-1:0]     issue_queue_id,   // Trans ID (Queue Index)
    //output logic                issue_is_dtlb,    // 0=ITLB, 1=DTLB
    
    // Flattened Output Payload
    output logic [VPN_W-1:0]    issue_vpn,
    //output logic [ASID_W-1:0]   issue_asid,
    output logic [EID_W-1:0]    issue_eid,
    output logic [TYPE_W-1:0]   issue_type,//00 is itlb,01 is load,11 is store
    
    input  logic                issue_grant,      // Grant from Arbiter

    //-------------------------------------------------------------------------
    // 4. Feedback Interface (from L2TLB Pipeline)
    //-------------------------------------------------------------------------
    input  logic                fb_valid,
    input  logic [ID_W-1:0]     fb_trans_id,
    input  logic                fb_hit,
    input  logic                fb_miss_alloc,
    input  logic                fb_miss_retry
);


    // &Wires;
    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    // Allocation Control
    logic [DTLB_DEPTH-1:0]      dtlb_alloc_oh;    // One-hot free slot for DTLB
    logic [TOTAL_DEPTH-1:0]     alloc_en_vec;     // Write enable for all entries
    
    // Entry Status Vectors
    logic [TOTAL_DEPTH-1:0]     entry_vld_vec;
    logic [TOTAL_DEPTH-1:0]     entry_rdy_vec;
    logic [TOTAL_DEPTH-1:0]     entry_dealloc_vec;
    
    // Arbitration Control
    logic [TOTAL_DEPTH-1:0]     ffr_oh;           // Find First Ready One-Hot
    logic [TOTAL_DEPTH-1:0]     entry_grant_vec;  // Grant to specific entry
    logic [TOTAL_DEPTH-1:0]     bypass_grant_vec; // Grant to entry allocated by bypass issue

    // Internal Payload Arrays (to collect data from instances)
    logic [VPN_W-1:0]           entry_out_vpn   [TOTAL_DEPTH-1:0];
    logic [ASID_W-1:0]          entry_out_asid  [TOTAL_DEPTH-1:0];
    logic [EID_W-1:0]           entry_out_eid   [TOTAL_DEPTH-1:0];
    logic [TYPE_W-1:0]          entry_out_type  [TOTAL_DEPTH-1:0];

    // Intermediate Mux Signals
    logic                       entry_ready;
    logic [VPN_W-1:0]           entry_rdy_vpn;
    logic [ASID_W-1:0]          entry_rdy_asid;
    logic [EID_W-1:0]           entry_rdy_eid;
    logic [TYPE_W-1:0]          entry_rdy_type;
    logic [ID_W-1:0]            entry_rdy_id;
    logic                       entry_rdy_is_dtlb;

    // Helper signals for Thermometer coding
    logic [DTLB_DEPTH-1:0]      therm_vld;   // For Allocation
    logic [TOTAL_DEPTH-1:0]     ffr_therm;   // For Issue Arbitration
    logic [ID_W-1:0]            dtlb_alloc_index; // Binary index of free slot


    //=========================================================================
    // 1. Allocation Logic (Write Control)
    //=========================================================================
    
    // 1.1 ITLB Allocation (Always Entry 0)
    // L1 ITLB ensures credits are available, so just write when valid.
    assign alloc_en_vec[0] = i_req_valid;

    // 1.2 DTLB Allocation (Entries 1 to 8)
    // Find First Zero (FFZ) Logic
//
//    always_comb begin
//        dtlb_alloc_oh = {DTLB_DEPTH{1'b0}};
//        // Scan DTLB entries (Indices 1 to TOTAL_DEPTH-1)
//        for (int i = 0; i < DTLB_DEPTH; i++) begin
//            // Check validity of physical entry [i+1]
//            if (!entry_vld_vec[i+1]) begin
//                dtlb_alloc_oh[i] = 1'b1;
//                break; // Found first empty slot
//            end
//        end
//    end

      generate
	  genvar j;
	  assign therm_vld[0] = entry_vld_vec[1];
	  for(j = 1;j < DTLB_DEPTH;j++) begin :gener_therm
	      assign therm_vld[j] = therm_vld[j-1] & entry_vld_vec[j+1];
	  end
  	  
	  assign dtlb_alloc_oh[0] = ~therm_vld[0];
	  for(j = 1;j < DTLB_DEPTH;j++) begin :gener_onehot
	      assign dtlb_alloc_oh[j] = therm_vld[j-1] & ~therm_vld[j];
	  end
      endgenerate


// Encoder: One-Hot to Binary Index (1 to 8),0 is itlb entry
      always_comb begin
	  dtlb_alloc_index = {DTLB_DEPTH{1'b0}};
          for(integer index = 0;index < DTLB_DEPTH; index++)  
	      if(dtlb_alloc_oh[index]) begin 
	          dtlb_alloc_index = index + 4'd1 ;
	  end
      end

    // Map DTLB allocation to global vector
    assign alloc_en_vec[TOTAL_DEPTH-1:1] = d_req_valid ? dtlb_alloc_oh : '0;


    //=========================================================================
    // 2. Entry Instantiation
    //=========================================================================
    // Generates 9 entries. 
    // Entry 0 is wired to ITLB inputs.
    // Entries 1-8 are wired to DTLB inputs.
    
    generate
        for (genvar i = 0; i < TOTAL_DEPTH; i++) begin : gen_entries
            
            // Local mux wires for input data
            logic [VPN_W-1:0]   local_alloc_vpn;
            //logic [ASID_W-1:0]  local_alloc_asid;
            logic [EID_W-1:0]   local_alloc_eid;
            logic [TYPE_W-1:0]  local_alloc_type;

            // Mux Logic: 
            // Index 0 selects ITLB input, Others select DTLB input
            if (i == 0) begin : gen_mux_itlb
                assign local_alloc_vpn  = i_req_vpn;
                //assign local_alloc_asid = i_req_asid;
                assign local_alloc_eid  = {EID_W{1'b0}};  // Unused for ITLB
                assign local_alloc_type = 3'b011; // Unused for ITLB
            end else begin : gen_mux_dtlb
                assign local_alloc_vpn  = d_req_vpn;
                //assign local_alloc_asid = d_req_asid;
                assign local_alloc_eid  = d_req_eid;
                assign local_alloc_type = d_req_type;
            end

            // &Instance("mmu_l2tlb_reqq_entry", "x_reqq_entry");
            mmu_l2tlb_reqq_entry #(
                .VPN_W          (VPN_W),
                .ASID_W         (ASID_W),
                .EID_W          (EID_W),
                .TYPE_W         (TYPE_W)
            ) x_reqq_entry (
                // Global
                .cp0_mmu_icg_en     (cp0_mmu_icg_en),
                .cpurst_b           (cpurst_b),
                .reqq_clk           (reqq_clk),
                .pad_yy_icg_scan_en (pad_yy_icg_scan_en),

                // Alloc (Write)
                .entry_alloc_en     (alloc_en_vec[i]),
                .alloc_vpn          (local_alloc_vpn),
                //.alloc_asid         (local_alloc_asid),
                .alloc_eid          (local_alloc_eid),
                .alloc_type         (local_alloc_type),

                // Issue (Read)
                .issue_grant        (entry_grant_vec[i]),
		.bypass_grant       (bypass_grant_vec[i]),
                // Feedback (Status Update)
                // Note: Each entry checks if fb_trans_id matches its own index 'i'
                .fb_match_id        (fb_valid && (fb_trans_id == i[ID_W-1:0])),
                .fb_hit             (fb_hit),
                .fb_miss_alloc      (fb_miss_alloc),
                .fb_miss_retry      (fb_miss_retry),

                // Outputs
                .entry_vld          (entry_vld_vec[i]),
                .entry_rdy          (entry_rdy_vec[i]),
                .entry_dealloc      (entry_dealloc_vec[i]),
                
                .entry_out_vpn      (entry_out_vpn[i]),
                .entry_out_asid     (entry_out_asid[i]),
                .entry_out_eid      (entry_out_eid[i]),
                .entry_out_type     (entry_out_type[i])
            );
        end
    endgenerate

    //=========================================================================
    // 3. Arbitration Logic (Issue Control)
    //=========================================================================
    // Find First Ready (FFR) - Fixed Priority
    // Entry 0 (ITLB) > Entry 1 (DTLB) > ... > Entry 8
    
//    always_comb begin
//        ffr_oh = {TOTAL_DEPTH{1'b0}};
//        for (int i = 0; i < TOTAL_DEPTH; i++) begin
//            if (entry_rdy_vec[i]) begin
//                ffr_oh[i] = 1'b1;
//                break; // Select highest priority ready entry
//            end
//        end
//    end

//1010
//1110
//0010
      generate
      genvar i;
          assign ffr_therm[0] = entry_rdy_vec[0]; 
	  for(i = 1; i < TOTAL_DEPTH; i++) begin : gene_therm
	      assign ffr_therm[i] = entry_rdy_vec[i] | ffr_therm[i-1];
	  end

	  assign ffr_oh[0] = ffr_therm[0];
	  for(i = 1; i < TOTAL_DEPTH; i++) begin : gene_onehot
	      assign ffr_oh[i] = ffr_therm[i] & ~ffr_therm[i-1];
	  end
      endgenerate
     
  

    // Only issue a grant if the external arbiter allows it
      assign entry_grant_vec = ffr_oh & {TOTAL_DEPTH{issue_grant}};
      assign bypass_grant_vec[0] = issue_grant & !entry_ready & i_req_valid;
      assign bypass_grant_vec[TOTAL_DEPTH-1:1] =
        dtlb_alloc_oh & {DTLB_DEPTH{issue_grant & !entry_ready & !i_req_valid & d_req_valid}};
      
	
      assign entry_ready = |entry_rdy_vec; 
    // Request Valid to L2 Pipeline
      assign issue_valid = entry_ready | i_req_valid | d_req_valid;

    //=========================================================================
    // 4. Output Mux Logic
    //=========================================================================
    // Select payload from the granted entry using One-Hot OR-ing 
    // (Efficient for synthesis)
    
    always_comb begin
        entry_rdy_vpn   = {VPN_W{1'b0}};
        entry_rdy_asid  = {ASID_W{1'b0}};
        entry_rdy_eid   = {EID_W{1'b0}};
        entry_rdy_type  = {TYPE_W{1'b0}};
        entry_rdy_id    = {ID_W{1'b0}};
        entry_rdy_is_dtlb = 1'b0;

        for (int i = 0; i < TOTAL_DEPTH; i++) begin
            if (ffr_oh[i]) begin
                entry_rdy_vpn   = entry_out_vpn[i];
                entry_rdy_asid  = entry_out_asid[i];
                entry_rdy_eid   = entry_out_eid[i];
                entry_rdy_type  = entry_out_type[i];
                entry_rdy_id    = i[ID_W-1:0];
                entry_rdy_is_dtlb = (i != 0); // 0 is ITLB, others DTLB
            end
        end
    end

//final bypass mux      
      assign issue_vpn = entry_ready ? entry_rdy_vpn : 
			 i_req_valid ? i_req_vpn :
		 	 d_req_valid ? d_req_vpn :27'b0;

      assign issue_eid = entry_ready ? entry_rdy_eid :
                         i_req_valid ? {EID_W{1'b0}} :
                         d_req_valid ? d_req_eid : {EID_W{1'b0}};

      assign issue_queue_id = entry_ready ? entry_rdy_id : 
        		 i_req_valid ? {ID_W{1'b0}} :
        	 	 d_req_valid ? dtlb_alloc_index : {ID_W{1'b0}};

      assign issue_type = entry_ready ? entry_rdy_type :
                         i_req_valid ? 3'b011 :
                         d_req_valid ? d_req_type : 3'b011;

      //assign issue_is_dtlb = entry_ready ? entry_rdy_is_dtlb : 
      //		 	 d_req_valid ? 1'b1 :1'b0;


    //=========================================================================
    // 5. Credit Return Logic
    //=========================================================================
    
    // ITLB Credit: Return when Entry 0 deallocates
    assign i_credit_return = entry_dealloc_vec[0];

    // DTLB Credit: Return when any of Entry 1-8 deallocates
    assign d_credit_return = |entry_dealloc_vec[TOTAL_DEPTH-1:1];

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
        && (i_req_valid
            || d_req_valid
            || issue_valid
            || issue_grant
            || fb_valid
            || i_credit_return
            || d_credit_return
            || ((entry_vld_vec != '0) && (mmu_itlb_dbg_stuck_cycles[11:0] == 12'hfff)))) begin
      $display("[MMU_ITLB_DBG][L2REQQ] t=%0t stuck_cycles=%0d i_req=%0b i_vpn=0x%07h d_req=%0b d_vpn=0x%07h d_type=0x%0h issue_valid=%0b issue_grant=%0b issue_qid=0x%0h issue_type=0x%0h issue_vpn=0x%07h fb_valid=%0b fb_id=0x%0h fb_hit=%0b fb_miss_alloc=%0b fb_miss_retry=%0b i_credit=%0b d_credit=%0b vld=0x%03h rdy=0x%03h dealloc=0x%03h e0_type=0x%0h e0_vpn=0x%07h e1_type=0x%0h e1_vpn=0x%07h e1_eid=0x%0h",
               $time,
               mmu_itlb_dbg_stuck_cycles,
               i_req_valid,
               i_req_vpn,
               d_req_valid,
               d_req_vpn,
               d_req_type,
               issue_valid,
               issue_grant,
               issue_queue_id,
               issue_type,
               issue_vpn,
               fb_valid,
               fb_trans_id,
               fb_hit,
               fb_miss_alloc,
               fb_miss_retry,
               i_credit_return,
               d_credit_return,
               entry_vld_vec,
               entry_rdy_vec,
               entry_dealloc_vec,
               entry_out_type[0],
               entry_out_vpn[0],
               entry_out_type[1],
               entry_out_vpn[1],
               entry_out_eid[1]);
    end
  end
end
// synopsys translate_on

endmodule


