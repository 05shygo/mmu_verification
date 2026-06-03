module mmu_l2tlb_replacement_policy#(

    parameter WAY_NUM	 = 8,
    parameter RRPV_WIDTH = 3

)(
    input   logic				clk	  ,
    input   logic				rst_n	  , 
	
   // Control signals 
    input   logic				access_vld, 
    input   logic [WAY_NUM-1:0]			mask_way  ,
    input   logic				hit	  ,
    input   logic				miss	  ,
    input   logic				ptw_req	  ,//ptw_alloc
    input   logic [WAY_NUM-1:0]         hit_index ,

   // Status signals
    input   logic [WAY_NUM-1:0]			entry_vld ,
    input   logic [(WAY_NUM-1-(0)+1)*(RRPV_WIDTH-1-(0)+1)-1:0] entry_rrpv,

   // Outputs
    output  logic				push_req,
    //output  logic
    output  logic [WAY_NUM-1:0]			victim_way_out ,
    output  logic [(WAY_NUM-1-(0)+1)*(RRPV_WIDTH-1-(0)+1)-1:0] rrpv_updata

);
    // =========================================================
    // Parameters and Internal Signals
    // =========================================================
    localparam int RRPV_MAX  = (1 << RRPV_WIDTH) - 1;
    localparam int RRPV_INIT = 3;

    //logic [(WAY_NUM-1-(0)+1)*(RRPV_WIDTH-1-(0)+1)-1:0] mask_rrpv;

    logic [(WAY_NUM-1-(0)+1)*(RRPV_WIDTH-1-(0)+1)-1:0] rrpv_reg;
    logic [WAY_NUM-1:0]                 mask_way_reg;
    logic [(WAY_NUM-1-(0)+1)*(RRPV_WIDTH-1-(0)+1)-1:0] rrpv_aged;

    // First Free Logic Signals
    logic [WAY_NUM-1:0]                 mask_vld;
    logic [WAY_NUM-1:0]                 therm_vld;
    logic [WAY_NUM-1:0]                 victim_oh_free;
    logic                               have_free;

    // SRRIP Logic Signals
    logic [(RRPV_MAX-(0)+1)*(WAY_NUM-1-(0)+1)-1:0] rrpv_sel;   // Bitmap: ways matching specific RRPV
    logic [(RRPV_MAX-(0)+1)*(WAY_NUM-1-(0)+1)-1:0] rrip_repl;  // One-Hot: selected candidate per RRPV level
    logic [RRPV_MAX:0]                  sel_valid;  // Flag: if a candidate exists at this level
    logic [WAY_NUM-1:0]                 rrip_victim_way;
    logic [WAY_NUM-1:0]                 final_victim_oh;

    	

    //=========================================================================
    // 1. Victim Selection Logic (Combinational T1)
    //    Priority: First Free Way > Max RRPV (Search 7->0)
    //=========================================================================
    	
    // 1.1  Find First Free Entry (Using Thermometer Code)
    //0101100111
    //0000000111
    //0000001000
    genvar i;
    generate
    // Construct Mask Valid: 1 if Way is masked OR already valid
	for(i=0;i < WAY_NUM;i++) begin :gen_mask_vld
	    assign mask_vld[i] = ~mask_way[i] | entry_vld[i];
	end

    //find first free entry
    // Generate Thermometer Code
	assign therm_vld[0] = mask_vld[0];
	for(i=1;i < WAY_NUM;i++) begin :gene_therm
	    assign therm_vld[i] = mask_vld[i] & therm_vld[i-1];
	end

    // Edge Detection to generate One-Hot (Find first zero)
	assign victim_oh_free[0] = ~therm_vld[0];
        for(i=1;i < WAY_NUM;i++) begin : gene_one_hot
	    assign victim_oh_free[i] = ~therm_vld[i] & therm_vld[i-1];
	end

    //mask not select way
    //	for(i=0;i < WAY_NUM;i++) begin : mask_rrpv
    //	    assign mask_rrpv[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = {RRPV_WIDTH{mask_way[i] & entry_rrpv[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)]};		
    //	end
    
    endgenerate

    assign have_free = ~(&(entry_vld | mask_way));

    // 1.2 SRRIP Max RRPV Selection
    // If no free way exists, find the first way with the highest RRPV.
    // Search order: RRPV_MAX down to 0.
    generate
    for(i=0;i <= RRPV_MAX;i++) begin:find_max_per_level
	// Step 1: Find all ways that match current RRPV 'i' AND are NOT masked.
        // This logic handles RRPV=0 correctly by ensuring mask_way is 0.	
	always_comb begin
	    rrpv_sel[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)] = 'b0;
	    for(int j=0;j < WAY_NUM;j++) begin
		if((entry_rrpv[(j)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == i) & mask_way[j]) begin
		    rrpv_sel[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)] = 1'b1;
		end
	    end
	end

	// Step 2: Resolve conflicts within the same RRPV level.
        // Convert Bitmap to One-Hot (select the first available way).
	always_comb begin
	    rrip_repl[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)] = 'b0;
	    for(int k=0;k < WAY_NUM;k++) begin
		if(rrpv_sel[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)] && (rrip_repl[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)] == '0)) begin
		    rrip_repl[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)] = 1'b1;
		end
	    end
	end
    end
    
    // Step 3: Flag if this RRPV level has any valid candidates
    for(i=0;i <= RRPV_MAX;i++) begin :generate_sel_logic
	assign sel_valid[i] = |rrpv_sel[(i)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)];
    end
    endgenerate

    // Step 4: Priority Selection (Reverse Priority Encoder)
    // Search from RRPV_MAX down to 0. Select the first level that has candidates.
    always_comb begin
        rrip_victim_way = '0;
        for (int k = RRPV_MAX; k >= 0; k--) begin
            if (sel_valid[k] && (rrip_victim_way == '0)) begin
                rrip_victim_way = rrip_repl[(k)*(WAY_NUM-1-(0)+1)+0 +: (WAY_NUM-1-(0)+1)];
            end
        end
    end

    // 1.3 Final Victim Mux
    assign final_victim_oh = have_free ? victim_oh_free :
				    rrip_victim_way;

    //=========================================================================
    // 2. Speculative RRPV Calculation (Parallel T1)
    //    Optimize Timing: Perform the "+1" aging calculation in parallel 
    //    with the Tag Comparison. The Hit/Miss signal only drives the Mux.
    //=========================================================================
   
    //T1 pre-calculate
    // Pre-calculate "Aged" values for all ways
    always_comb begin
        for (int i = 0; i < WAY_NUM; i++) begin
            // Saturating Counter: Increment unless already MAX
            if (entry_rrpv[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] != RRPV_MAX) 
                rrpv_aged[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = entry_rrpv[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] + 1'b1;
            else
                rrpv_aged[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = entry_rrpv[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)];
        end
    end

    
    //=========================================================================
    // 3. T2 Output Registers (Pipeline Register)
    //    Latch the T1 calculation results to drive the T2 Update phase.
    //=========================================================================
    //T2 calculate new rrpv
    always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
	    rrpv_reg <= '0;
	    mask_way_reg <= '0;
	    victim_way_out <= '0;
	end
	else if(access_vld) begin//ta_vld,for T2 calculate
	    rrpv_reg <= rrpv_aged;
	    mask_way_reg <= mask_way;
	    victim_way_out <= final_victim_oh;//T0:ptw request to l2tlb;T1:access_vld(ta_vld);T2:output victim way to l2tlb
	end
    end

    // Final Selection Mux (Critical Path Endpoint)
    always_comb begin
        rrpv_updata = rrpv_reg;

        // One-Hot Muxing: Assumes hit/miss/ptw_req are mutually exclusive.
        case ({hit,miss,ptw_req})
            
            // CASE 1: Hit (Hit Promotion + Aggressive Aging)
            3'b100: begin
                for (int i = 0; i < WAY_NUM; i++) begin
                    // Logic: Promote the Hit Way to 0, Age (Increment) all other ways
                    rrpv_updata[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = (hit_index[i] == 1) ? //onehot
                                        {RRPV_WIDTH{1'b0}} : rrpv_reg[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)];
                end
            end

            // CASE 2: Miss (Pure Aging)
            // Occurs when a Lookup fails, but Refill hasn't happened yet.
            3'b010: begin
                // Logic: Age all ways (Increment RRPV) to prevent stagnation
                rrpv_updata = rrpv_reg;
            end

            // CASE 3: PTW Refill (Insertion)
            // Occurs when PTW returns data and writes to L2TLB.
            3'b001: begin
                for (int i = 0; i < WAY_NUM; i++) begin
                    if (victim_way_out[i]) 
                        rrpv_updata[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = RRPV_WIDTH'(RRPV_INIT);
                    else if (mask_way_reg[i]) 
                        rrpv_updata[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = rrpv_reg[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)]; // Valid Ways -> Age (+1)
                    else
                        rrpv_updata[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] = rrpv_reg[(i)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)]; // Masked/Invalid Ways -> Hold
                end
            end

            // Default: Hold value (e.g., req_vld=0)
            default: begin
                rrpv_updata = rrpv_reg;
            end
        endcase
    end

    assign push_req = hit | miss;

/*
    //find max rrpv
    always_comb begin
	rrpv_sel_7 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 7) begin
		rrpv_sel_7[k] = 1;
	    end
	end
    end
	
    always_comb begin
	rrpv_sel_6 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 6) begin
		rrpv_sel_6[k] = 1;
	    end
	end
    end

    always_comb begin
	rrpv_sel_5 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 5) begin
		rrpv_sel_5[k] = 1;
	    end
	end
    end

    always_comb begin
	rrpv_sel_4 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 4) begin
		rrpv_sel_4[k] = 1;
	    end
	end
    end
	
    always_comb begin
	rrpv_sel_3 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 3) begin
		rrpv_sel_3[k] = 1;
	    end
	end
    end

    always_comb begin
	rrpv_sel_2 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 2) begin
		rrpv_sel_2[k] = 1;
	    end
	end
    end


    always_comb begin
	rrpv_sel_1 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 1) begin
		rrpv_sel_1[k] = 1;
	    end
	end
    end


    always_comb begin
	rrpv_sel_0 = {WAY_NUM'b0};
	for(int k = 0;k < WAY_NUM;k++) begin
	    if(mask_rrpv[(k)*(RRPV_WIDTH-1-(0)+1)+0 +: (RRPV_WIDTH-1-(0)+1)] == 0) begin
		rrpv_sel_0[k] = 1;
	    end
	end
    end

    //generate onehot
    always_comb begin
	rrip_repl_7 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_7[h] = 1)begin
		rrip_repl_7[h] = 1'b1;
		break;
	    end
	end
    end

    always_comb begin
	rrip_repl_6 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_6[h] = 1)begin
		rrip_repl_6[h] = 1'b1;
		break;
	    end
	end
    end

    always_comb begin
	rrip_repl_5 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_5[h] = 1)begin
		rrip_repl_5[h] = 1'b1;
		break;
	    end
	end
    end

    always_comb begin
	rrip_repl_4 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_4[h] = 1)begin
		rrip_repl_4[h] = 1'b1;
		break;
	    end
	end
    end


    always_comb begin
	rrip_repl_3 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_3[h] = 1)begin
		rrip_repl_3[h] = 1'b1;
		break;
	    end
	end
    end

    always_comb begin
	rrip_repl_2 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_2[h] = 1)begin
		rrip_repl_2[h] = 1'b1;
		break;
	    end
	end
    end

    always_comb begin
	rrip_repl_1 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(rrpv_sel_1[h] = 1)begin
		rrip_repl_1[h] = 1'b1;
		break;
	    end
	end
    end

    always_comb begin
	rrip_repl_0 = WAY_NUM'b0;
	for(int h = 0; h < WAY_NUM;h++) begin
	    if(mask_way[h] = 1)begin
		rrip_repl_0[h] = 1'b1;
		break;
	    end
	end
    end


    assign sel7 = |rrpv_sel_7;
    assign sel6 = |rrpv_sel_6;
    assign sel5 = |rrpv_sel_5;
    assign sel4 = |rrpv_sel_4;
    assign sel3 = |rrpv_sel_3;
    assign sel2 = |rrpv_sel_2;
    assign sel1 = |rrpv_sel_1;
    assign sel0 = |rrpv_sel_0;
    assign sel_value = {sel0,sel1,sel2,sel3,sel4,sel5,sel6,sel7};

    always_comb begin
	casez(sel_value)
	    8'b???????1: rrip_victim_way = rrip_repl_7; 
	    8'b??????10: rrip_victim_way = rrip_repl_6;
	    8'b?????100: rrip_victim_way = rrip_repl_5;
	    8'b????1000: rrip_victim_way = rrip_repl_4;
	    8'b???10000: rrip_victim_way = rrip_repl_3;
	    8'b??100000: rrip_victim_way = rrip_repl_2;		
	    8'b?1000000: rrip_victim_way = rrip_repl_1;
	    8'b10000000: rrip_victim_way = rrip_repl_0;
	    default: rrip_victim_way = rrip_repl_7;
	endcase
    end
*/

endmodule

