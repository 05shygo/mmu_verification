//=============================================================================
// Module: mmu_l2tlb_rrpv_wbuf
// Description: Specialized Write Buffer for Separate RRPV Array.
//              - Designed for Skewed TLB (stores 8 separate indices per entry).
//              - Resolves Read-After-Write (RAW) hazards using CAM-style bypass.
//              - Updates from Hit/Aging affect all ways, so no way_mask is stored.
//=============================================================================

//T0:arb request to l2tlb read sram ,and request to write buffer cam index
//T1:sel new rrpv to replancement module(if any index hit in write buffer,sel write buffer rrpv,otherwrise sel l2tlb sram rrpv)
//T2:if arb req source is l1tlb,write rrpv into write buffer;if arb req source is ptw,replancement module output rrpv to arb,and arb request to l2tlb(ptw write)

module mmu_l2tlb_rrpv_wbuf#(

    parameter WAY_NUM     = 8,	
    parameter IDX_WIDTH   = 8,  // 256 sets -> 8 bits
    parameter RRPV_WIDTH  = 2,
    parameter DEPTH       = 4  // Depth of Write Buffer
	)(
    input  logic                     clk,
    input  logic                     rst_n,

    //-------------------------------------------------------------------------
    // 1. Push Interface (From SRRIP Update Logic)
    //-------------------------------------------------------------------------
    // Valid request to store a new RRPV update (Hit or Aging)
    input  logic                     push_req,
    // 8 Independent indices for the 8 skewed banks
    input  logic [WAY_NUM-1:0][IDX_WIDTH-1:0] push_idx, 
    // Entry valid bits read from the L2TLB tag banks with the lookup.
    input  logic [WAY_NUM-1:0] push_vld,
    // New RRPV values for all 8 ways
    input  logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] push_data,

    // Stall signal for arb. Keep room for granted lookups already in pipe.
    output logic                     full,      

    //-------------------------------------------------------------------------
    // 2. Pop Interface (To SRAM Arbiter)
    //-------------------------------------------------------------------------
    // Arbiter grants permission to write to SRAM (Buffer Drain)
    input  logic                     pop_grant, 
    
    // Indicates buffer has data pending
    output logic                     empty,     
    // Data at the Head of the buffer (to be written to SRAM)
    output logic [WAY_NUM-1:0] sram_vld,
    output logic [WAY_NUM-1:0][IDX_WIDTH-1:0] sram_idx,
    output logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] sram_data,

    //-------------------------------------------------------------------------
    // 3. Bypass Interface (Lookup Stage)
    //-------------------------------------------------------------------------
    // Current Lookup Indices from Hash Logic
    input  logic [WAY_NUM-1:0][IDX_WIDTH-1:0] lookup_idx,
    input  logic			      lookup_req,
    
    // Stale Data read from SRAM (potentially outdated)
    //input  logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] rrpv_sram_rdata,
    
    // Final RRPV Data (Merged: SRAM Read + Pending Buffer Updates)
    output logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] bypassed_rrpv_rdata,
    output logic [WAY_NUM-1:0]		       lookup_hit
);


    //=========================================================================
    // Internal Structures
    //=========================================================================
    typedef struct packed {
        logic [WAY_NUM-1:0] vld;
        logic [WAY_NUM-1:0][IDX_WIDTH-1:0] idx;
        logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] data;
    } entry_t;

    entry_t buffer [DEPTH-1:0];

    // FIFO Pointers
    logic [$clog2(DEPTH)-1:0] wr_ptr;
    logic [$clog2(DEPTH)-1:0] rd_ptr;
    logic [$clog2(DEPTH):0]   count;

    // Bypass logic signals
    logic [WAY_NUM-1:0] lookup_hit_comb;
    logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] bypassed_rrpv_rdata_comb;
    logic [WAY_NUM-1:0] push_hit_comb;
    logic [WAY_NUM-1:0][$clog2(DEPTH)-1:0] push_hit_ptr;
    logic [WAY_NUM-1:0] push_new_bank;
    logic               push_new_entry;
    logic               push_accept;
    logic               pop_do;
    logic               fifo_full;

    localparam int ARB_STALL_LEVEL = (DEPTH > 3) ? (DEPTH - 3) : DEPTH;

    //=========================================================================
    // 1. Push CAM Logic
    //=========================================================================
    always_comb begin
        push_hit_comb = '0;
        push_hit_ptr  = '{default:'0};

        for (int k = 0; k < DEPTH; k++) begin
            logic [$clog2(DEPTH)-1:0] ptr;
            logic valid_entry;

            if (rd_ptr + k >= DEPTH)
                ptr = rd_ptr + k - DEPTH;
            else
                ptr = rd_ptr + k;

            valid_entry = (k < count) && !(pop_do && (ptr == rd_ptr));

            if (valid_entry) begin
                for (int w = 0; w < WAY_NUM; w++) begin
                    if (buffer[ptr].vld[w] && (buffer[ptr].idx[w] == push_idx[w])) begin
                        push_hit_comb[w] = 1'b1;
                        push_hit_ptr[w]  = ptr;
                    end
                end
            end
        end

    end

    assign push_new_bank  = push_vld & ~push_hit_comb;
    assign push_new_entry = |push_new_bank;
    assign pop_do         = pop_grant && !empty;
    assign push_accept    = push_req && (!push_new_entry || !fifo_full || pop_do);

    //=========================================================================
    // 2. FIFO Logic (Circular Buffer)
    //=========================================================================
    assign fifo_full = (count == DEPTH);
    assign full      = (count >= ARB_STALL_LEVEL);
    assign empty     = (count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            for (int i = 0; i < DEPTH; i++) begin
                buffer[i].vld <= '0;
            end
        end
        else begin
            // Pop Logic
            if (pop_do) begin
                buffer[rd_ptr].vld <= '0;
                // Wrap around logic
                if (rd_ptr == DEPTH-1) rd_ptr <= '0;
                else                   rd_ptr <= rd_ptr + 1'b1;
            end

            // CAM-hit banks update in place; the latest RRPV wins.
            if (push_accept) begin
                for (int w = 0; w < WAY_NUM; w++) begin
                    if (push_hit_comb[w]) begin
                        buffer[push_hit_ptr[w]].vld[w]  <= push_vld[w];
                        buffer[push_hit_ptr[w]].idx[w]  <= push_idx[w];
                        buffer[push_hit_ptr[w]].data[w] <= push_data[w];
                    end
                end
            end

            // Banks with no CAM hit allocate the current tail slot together.
            if (push_accept && push_new_entry) begin
                for (int w = 0; w < WAY_NUM; w++) begin
                    if (push_new_bank[w]) begin
                        buffer[wr_ptr].vld[w]  <= push_vld[w];
                        buffer[wr_ptr].idx[w]  <= push_idx[w];
                        buffer[wr_ptr].data[w] <= push_data[w];
                    end
                    else begin
                        buffer[wr_ptr].vld[w] <= 1'b0;
                    end
                end

                if (wr_ptr == DEPTH-1) wr_ptr <= '0;
                else                   wr_ptr <= wr_ptr + 1'b1;
            end

            // Count Logic
            case ({push_accept && push_new_entry, pop_do})
                2'b10: count <= count + 1'b1; // Push only
                2'b01: count <= count - 1'b1; // Pop only
                default: count <= count;      // Both or None
            endcase
        end
    end

    //=========================================================================
    // 3. Output to SRAM (Peek at Head)
    //=========================================================================
    // The data at the Read Pointer is always presented to the Arbiter
    assign sram_vld  = buffer[rd_ptr].vld;
    assign sram_idx  = buffer[rd_ptr].idx;
    assign sram_data = buffer[rd_ptr].data;

    //=========================================================================
    // 4. Bypass Logic (The Critical Path)
    //=========================================================================
    // Logic: Iterate through all valid entries in the buffer.
    // If a buffered write targets the same index as the current lookup,
    // forward the buffered data instead of the SRAM data.
    // Policy: Youngest Entry Wins (Latest write overwrites older writes).
    
    always_comb begin
        //
        bypassed_rrpv_rdata_comb = '{default :0};
	lookup_hit_comb          = {WAY_NUM{1'b0}};

        // Iterate through physical slots to synthesize a priority encoder structure.
        // We calculate the logical position relative to Read Pointer to determine "Age".
        
        for (int k = 0; k < DEPTH; k++) begin
            logic [$clog2(DEPTH)-1:0] ptr;
            logic valid_entry;

            // Calculate circular pointer based on logical offset 'k'
            // k=0 is Head (Oldest), k=Count-1 is Tail (Youngest)
            if (rd_ptr + k >= DEPTH) 
		ptr = rd_ptr + k - DEPTH; // Wrap around adjustment
	    else ptr = rd_ptr + k;

            // Only check entries that are currently valid in the FIFO
            valid_entry = (k < count);

            if (valid_entry) begin
                // Check each skewed bank independently
                for (int w = 0; w < WAY_NUM; w++) begin
                    // Compare Buffer Index vs Lookup Index
                    // If match, override the result with buffered data.
                    // Since k iterates from Oldest to Youngest, later matches
                    // will overwrite earlier ones, preserving data coherency.
                    if (buffer[ptr].vld[w] && (buffer[ptr].idx[w] == lookup_idx[w])) begin
                        bypassed_rrpv_rdata_comb[w] = buffer[ptr].data[w];
			lookup_hit_comb[w]   =  1'b1;
                    end
                end
            end
        end

        // Include the same-cycle push so a lookup granted while an older lookup
        // updates RRPV still sees the newest value.
        if (push_req) begin
            for (int w = 0; w < WAY_NUM; w++) begin
                if (push_vld[w] && (push_idx[w] == lookup_idx[w])) begin
                    bypassed_rrpv_rdata_comb[w] = push_data[w];
                    lookup_hit_comb[w] = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
	    lookup_hit <= {WAY_NUM{1'b0}};
	    bypassed_rrpv_rdata <= '{default:0};
	end else if(lookup_req) begin
	    lookup_hit <= lookup_hit_comb;
	    bypassed_rrpv_rdata <= bypassed_rrpv_rdata_comb;
	end
    end

endmodule
