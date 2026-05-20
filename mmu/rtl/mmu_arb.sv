//=============================================================================
// Module: ct_mmu_arb //
// Description: L2TLB Arbiter for Skew Associative Architecture.
//              - Arbitrates between PTW, TLB Oper, L2TLB ReqQ, and Prefetch.
//              - Generates 8 skewed indices for the 8 SRAM banks.
//              - Supports single-cycle non-blocking lookup.
//=============================================================================

module mmu_arb#(
    parameter EID_W = 3,
    parameter WAY_NUM = 8,
    parameter RRPV_WIDTH = 3,
    parameter VPN_WIDTH  = 27,        // SV39: 39-bit VA -> 27-bit VPN
    parameter PA_WIDTH   = 28,        // SV39: 56-bit PA -> 28-bit PPN (approx)
    parameter ASID_WIDTH = 16,        // From old code
    // Skew TLB Parameters
    parameter IDX_WIDTH  = 8,         // 256 Sets -> 8-bit Index
    parameter BANK_NUM   = 8,          // 8 Ways/Banks
    parameter TRANS_ID_WIDTH = 3,
    parameter TYPE_WIDTH = 3

)(
    //-------------------------------------------------------------------------
    // Clock and Reset
    //-------------------------------------------------------------------------
    input  logic                    forever_cpuclk,
    input  logic                    cpurst_b,
    input  logic                    pad_yy_icg_scan_en,
    input  logic                    cp0_mmu_icg_en,
    input  logic                    cp0_mmu_no_op_req,

    //-------------------------------------------------------------------------
    // 1. Interface with L2TLB Request Queue (New Source)
    //-------------------------------------------------------------------------
    input  logic                    issue_valid,      // From Reqq
    input  logic [VPN_WIDTH-1:0]    issue_vpn,
    //input  logic [ASID_WIDTH-1:0]   issue_asid,
    //input  logic                    issue_is_dtlb,
    input  logic [EID_W-1:0]        issue_eid,
    input  logic [TYPE_WIDTH-1:0]       issue_type,
    input  logic [TRANS_ID_WIDTH-1:0]         issue_queue_id,
    output logic                    arb_reqq_grant,   // To Reqq (issue_grant)

    input  logic		    ptw_xx_cmplt,
    //-------------------------------------------------------------------------
    // 2. Interface with PTW (Highest Priority)
    //-------------------------------------------------------------------------
    input  logic [WAY_NUM-1:0]	    victim_way,//from replancement module
    input  logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] rrpv_updata,
	
	
    input  logic                    ptw_arb_req,
    input  logic [VPN_WIDTH-1:0]    ptw_arb_vpn,
    input  logic [2:0]              ptw_arb_pgs,      // Page size for refill
    //input  logic                    ptw_arb_write,    // Assuming PTW indicates write
    // Pass-through data signals (simplified for arbiter logic)
    input  logic [47:0]             ptw_arb_tag_din,
    input  logic [41:0]             ptw_arb_data_din,
    
    //new
    //input  logic [TRANS_ID_WIDTH-1:0] ptw_arb_trans_id,
    //input  logic [TRANS_ID_WIDTH-1:0] ptw_arb_eid,	


    output logic                    arb_ptw_grant,
    output logic                    arb_ptw_mask,     // Mask PTW if blocked by Oper

    //-------------------------------------------------------------------------
    // 3. Interface with TLB Operation (High Priority)
    //-------------------------------------------------------------------------
    input   [WAY_NUM-1 :0]  tlboper_arb_bank_sel,  
    input           tlboper_arb_cmp_va,       
    //input   [3 :0]  tlboper_arb_fifo_din;  
    //input           tlboper_arb_fifo_write; 
    input   [10:0]  tlboper_arb_idx,
    input           tlboper_arb_idx_not_va,      
    //input   [2 :0]  tlboper_xx_pgs;        
    //input           tlboper_xx_pgs_en;  


	
    input  logic                    tlboper_arb_req,
    input  logic [VPN_WIDTH-1:0]    tlboper_arb_vpn,
    input  logic                    tlboper_arb_write,
    input  logic [47:0]             tlboper_arb_tag_din,
    input  logic [41:0]             tlboper_arb_data_din,
    input  logic                    tlboper_xx_cmplt, // Oper complete
    
    output logic                    arb_tlboper_grant,

    //-------------------------------------------------------------------------
    // 4. Interface with Prefetch (Lowest Priority)
    //-------------------------------------------------------------------------
    input  logic                    mmu_lsu_pa2_err,
    input  logic                    mmu_lsu_pa2_vld,
    input  logic                    lsu_mmu_va2_vld,  // PFU valid
    input  logic [VPN_WIDTH-1:0]    l2tlb_arb_pfu_vpn,
    input  logic                    l2tlb_arb_pfu_miss_mb_full,
    input  logic                    dutlb_xx_mmu_off, // MMU enable status
    
    output logic                    arb_pfu_grant,

    //-------------------------------------------------------------------------
    // 5. Output to L2TLB SRAM Wrapper (Skewed Indices)
    //-------------------------------------------------------------------------
    output logic                        arb_l2tlb_req,          // Global Request Valid
    output logic [VPN_WIDTH-1:0]        arb_l2tlb_vpn,          // Selected VPN
    output logic                        arb_l2tlb_write,        // Write Enable
    output logic [47:0]                 arb_l2tlb_tag_din,      // Write Data
    output logic [41:0]                 arb_l2tlb_data_din,     // Write Data
    output logic [TRANS_ID_WIDTH-1:0]   arb_l2tlb_trans_id,     //l2tlb request queue entry index 
    output logic [EID_W-1:0]		arb_l2tlb_eid,		//l1dtlb miss buffer entry index 
    output logic [TYPE_WIDTH-1:0]	arb_l2tlb_acc_type, 
    output logic [WAY_NUM-1:0]		arb_l2tlb_bank_sel,
    output logic			arb_l2tlb_cmp_with_va, 

    output logic [WAY_NUM*RRPV_WIDTH-1:0] arb_l2tlb_rrpv_din,
    
    // The 8 Skewed Indices for the 8 Banks
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w0,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w1,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w2,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w3,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w4,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w5,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w6,
    output logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w7,

    output logic [WAY_NUM*3-1:0]    arb_l2tlb_size_bus,



    // Misc Status
    output logic                    mmu_yy_xx_no_op,
    output logic                    arb_top_tlboper_on
);

    //-------------------------------------------------------------------------
    // Internal Signals
    //-------------------------------------------------------------------------
    logic       arb_clk;
    logic       arb_clk_en;
    logic       tlboper_on;
    logic       prefetch_mask;

    // Selected Request Signals
    logic [VPN_WIDTH-1:0] sel_vpn;
    
    // Skew Index Generation Signals
    logic [1:0] selector;       // VA[31:30]
    logic [2:0] size_pred [7:0];// Page Size Prediction for each Way (Encoding: 0=4K, 1=2M, 2=1G)
    logic [IDX_WIDTH-1:0] raw_idx [7:0]; // Raw Index extracted from VPN
    logic [IDX_WIDTH-1:0] skew_idx[7:0]; // Final Hashed Index

    // Constants for Page Size Encoding (Matches PDF)
    localparam SZ_4K = 3'b001; // Actually bit 0
    localparam SZ_2M = 3'b010; // Actually bit 1
    localparam SZ_1G = 3'b100; // Actually bit 2

    //=========================================================================
    // 1. Clock Gating (Keep from old design)
    //=========================================================================
    assign arb_clk_en = issue_valid | ptw_arb_req | tlboper_arb_req | lsu_mmu_va2_vld | tlboper_on
                      | mmu_lsu_pa2_err | mmu_lsu_pa2_vld | l2tlb_arb_pfu_miss_mb_full;

    gated_clk_cell x_l2tlb_arb_gateclk (
        .clk_in             (forever_cpuclk),
        .clk_out            (arb_clk),
        .external_en        (1'b0),
        .global_en          (1'b1),
        .local_en           (arb_clk_en),
        .module_en          (cp0_mmu_icg_en),
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
    );

    //=========================================================================
    // 2. Arbitration Logic (Fixed Priority)
    //    Priority: PTW > TlbOper > Request Queue > Prefetch
    //=========================================================================
    
    // TLB Operation Status (Stalls others when running)
    always @(posedge arb_clk or negedge cpurst_b) begin
        if (!cpurst_b)
            tlboper_on <= 1'b0;
        else if (tlboper_on && tlboper_xx_cmplt)
            tlboper_on <= 1'b0;
        else if (arb_tlboper_grant)
            tlboper_on <= 1'b1;
    end
    
    logic ptw_on;
    logic ptw_write_req1;
    logic [VPN_WIDTH-1:0]  ptw_write_vpn1;

    logic ptw_write_req2;
    logic [VPN_WIDTH-1:0] ptw_write_vpn2;

    logic [47:0] ptw_l2tlb_tag_in1;
    logic [41:0] ptw_l2tlb_data_in1;

    logic [47:0] ptw_l2tlb_tag_in2;
    logic [41:0] ptw_l2tlb_data_in2;

    always @(posedge arb_clk or negedge cpurst_b) begin
        if (!cpurst_b)
            ptw_on <= 1'b0;
        else if (ptw_on && ptw_xx_cmplt)
            ptw_on <= 1'b0;
        else if (arb_ptw_grant)
            ptw_on <= 1'b1;
    end

    assign arb_top_tlboper_on = tlboper_on;
    assign arb_ptw_mask       = tlboper_on;
    assign mmu_yy_xx_no_op    = cp0_mmu_no_op_req && !ptw_arb_req; // Simplified refill check


    always_ff@(posedge arb_clk or negedge cpurst_b) begin
	if (!cpurst_b) begin
	    ptw_write_req1 <= 1'b0;
	end else if(arb_ptw_grant) begin
	    ptw_write_req1 <= 1'b1;
	end else begin
	    ptw_write_req1 <= 1'b0;
	end
    end

    always_ff@(posedge arb_clk or negedge cpurst_b) begin
	if (!cpurst_b) begin
	    ptw_write_req2 <= 1'b0;
	end else if(ptw_write_req1) begin
	    ptw_write_req2 <= 1'b1;
	end else begin
	    ptw_write_req2 <= 1'b0;
	end
    end

    always_ff@(posedge arb_clk or negedge cpurst_b) begin
	if (!cpurst_b) begin
	    //ptw_write_req1    <= 1'b0;
	    ptw_write_vpn1    <= {VPN_WIDTH{1'b0}};
	    ptw_l2tlb_tag_in1  <= {48'b0};
	    ptw_l2tlb_data_in1 <= {42'b0};
	end else if(arb_ptw_grant) begin
	    //ptw_write_req1    <= arb_ptw_grant;
	    ptw_write_vpn1    <= ptw_arb_vpn;
	    ptw_l2tlb_tag_in1  <= ptw_arb_tag_din;
	    ptw_l2tlb_data_in1 <= ptw_arb_data_din;
	end
    end
	

    always_ff@(posedge arb_clk or negedge cpurst_b) begin
	if (!cpurst_b) begin
	    //ptw_write_req2 <= 1'b0;
	    ptw_write_vpn2    <= {VPN_WIDTH{1'b0}};
	    ptw_l2tlb_tag_in2 <= {48'b0};
	    ptw_l2tlb_data_in2 <={42'b0};
	end else if(ptw_write_req1) begin
	    //ptw_write_req2    <= 1'b1;
	    ptw_write_vpn2    <= ptw_write_vpn1;
	    ptw_l2tlb_tag_in2 <= ptw_l2tlb_tag_in1;
	    ptw_l2tlb_data_in2 <= ptw_l2tlb_data_in1;
	end
    end

    always_ff@(posedge arb_clk or negedge cpurst_b) begin
        if (!cpurst_b) begin
            prefetch_mask <= 1'b0;
        end else if(mmu_lsu_pa2_err | mmu_lsu_pa2_vld | l2tlb_arb_pfu_miss_mb_full) begin
            prefetch_mask <= 1'b0;
        end else if(arb_tlboper_grant) begin
            prefetch_mask <= 1'b1;

        end
    end

    // Grant Logic
    assign arb_ptw_write_grant   = ptw_write_req2 & !tlboper_on & ptw_on;

    assign arb_ptw_grant     = ptw_arb_req && !tlboper_on &&!ptw_on;
    
    assign arb_tlboper_grant = tlboper_arb_req 
                             && !ptw_arb_req
                             //&& !tlboper_on
			                 && !ptw_on;

    assign arb_reqq_grant    = issue_valid
                             && !ptw_arb_req
                             && !tlboper_arb_req
                             && !tlboper_on
			                 && !ptw_on;

    assign arb_pfu_grant     = lsu_mmu_va2_vld
                             && !dutlb_xx_mmu_off
                             && !ptw_arb_req
                             && !tlboper_arb_req
                             && !issue_valid
                             && !tlboper_on
			                 && !ptw_on
                             && !prefetch_mask;

    // Global Request Valid
    assign arb_l2tlb_req =arb_ptw_write_grant | arb_ptw_grant | arb_tlboper_grant | arb_reqq_grant | arb_pfu_grant;

    //=========================================================================
    // 3. Signal Muxing (Data Path)
    //=========================================================================

    // VPN Selection
    assign sel_vpn = ({VPN_WIDTH{arb_ptw_grant}}      & ptw_arb_vpn)
		   | ({VPN_WIDTH{arb_ptw_write_grant}}& ptw_write_vpn2)
                   | ({VPN_WIDTH{arb_tlboper_grant}}  & tlboper_arb_vpn)
                   | ({VPN_WIDTH{arb_reqq_grant}}     & issue_vpn)
                   | ({VPN_WIDTH{arb_pfu_grant}}      & l2tlb_arb_pfu_vpn);

    assign arb_l2tlb_vpn = sel_vpn;

    // Write Control & Data
    assign arb_l2tlb_write    = (arb_ptw_write_grant ) || (arb_tlboper_grant && tlboper_arb_write);//access type is ptw write or tlb operation

    assign tlboper_wen = arb_tlboper_grant && tlboper_arb_write;    

    assign arb_l2tlb_tag_din  = ({48{arb_ptw_write_grant}}     & ptw_l2tlb_tag_in2) //tag 2 cycle
                              | ({48{tlboper_wen}} & tlboper_arb_tag_din);
    assign arb_l2tlb_rrpv_din = {rrpv_updata[7],rrpv_updata[6],rrpv_updata[5],rrpv_updata[4],rrpv_updata[3],rrpv_updata[2],rrpv_updata[1],rrpv_updata[0]};
                              
    assign arb_l2tlb_data_din = ({42{arb_ptw_write_grant}}     & ptw_l2tlb_data_in2)
                              | ({42{arb_tlboper_grant}} & tlboper_arb_data_din);

    //=========================================================================
    // 4. Skew Associative Index Generation
    //    Selector -> Raw Extraction -> Hash
    //=========================================================================
    
    //-------------------------------------------------------------------------
    // 4.1. Selector Extraction
    // Selector = VA[31:30]. 
    // Since VPN = VA >> 12:
    // VA[31] = VPN[19], VA[30] = VPN[18]
    //-------------------------------------------------------------------------
    assign selector = sel_vpn[19:18];

    //-------------------------------------------------------------------------
    // 4.2. S-Function (Size Prediction per Way)
    // Based on Source 48: Selector Table
    //-------------------------------------------------------------------------
    always_comb begin
        case (selector)
            2'b00: begin
                size_pred[0] = SZ_4K; size_pred[1] = SZ_4K; size_pred[2] = SZ_2M; size_pred[3] = SZ_1G;
                size_pred[4] = SZ_4K; size_pred[5] = SZ_4K; size_pred[6] = SZ_2M; size_pred[7] = SZ_1G;
            end
            2'b01: begin
                size_pred[0] = SZ_2M; size_pred[1] = SZ_1G; size_pred[2] = SZ_4K; size_pred[3] = SZ_4K;
                size_pred[4] = SZ_2M; size_pred[5] = SZ_1G; size_pred[6] = SZ_4K; size_pred[7] = SZ_4K;
            end
            2'b10: begin
                size_pred[0] = SZ_4K; size_pred[1] = SZ_4K; size_pred[2] = SZ_1G; size_pred[3] = SZ_2M;
                size_pred[4] = SZ_4K; size_pred[5] = SZ_4K; size_pred[6] = SZ_1G; size_pred[7] = SZ_2M;
            end
            2'b11: begin
                size_pred[0] = SZ_1G; size_pred[1] = SZ_2M; size_pred[2] = SZ_4K; size_pred[3] = SZ_4K;
                size_pred[4] = SZ_1G; size_pred[5] = SZ_2M; size_pred[6] = SZ_4K; size_pred[7] = SZ_4K;
            end
            default: begin
               // Default safety
               size_pred[0] = SZ_4K; size_pred[1] = SZ_4K; size_pred[2] = SZ_4K; size_pred[3] = SZ_4K;
               size_pred[4] = SZ_4K; size_pred[5] = SZ_4K; size_pred[6] = SZ_4K; size_pred[7] = SZ_4K;
            end
        endcase
    end

    logic [WAY_NUM-1:0] mask_bank_sel;

    always_comb begin
	case(selector)
            2'b00: begin
		case(ptw_arb_pgs)
		    3'b001: begin 
			mask_bank_sel = 00110011;
		    end
		    3'b010:begin
			mask_bank_sel = 01000100;
		    end
		    3'b100:begin
			mask_bank_sel = 10001000;
		    end
		    default: begin
			mask_bank_sel =00000000 ;
		    end
		endcase
            end
            2'b01: begin
		case(ptw_arb_pgs)
		    3'b001: begin 
			mask_bank_sel = 11001100;
		    end
		    3'b010:begin
			mask_bank_sel = 00010001;
		    end
		    3'b100:begin
			mask_bank_sel = 00100010;
		    end
		    default: begin
			mask_bank_sel = 00000000;
		    end
		endcase
            end
            2'b10: begin
		case(ptw_arb_pgs)
		    3'b001: begin 
			mask_bank_sel = 00110011;
		    end
		    3'b010:begin
			mask_bank_sel = 10001000;
		    end
		    3'b100:begin
			mask_bank_sel = 01000100;
		    end
		    default: begin
			mask_bank_sel = 00000000;
		    end
		endcase
            end
            2'b11: begin
		case(ptw_arb_pgs)
		    3'b001: begin 
			mask_bank_sel = 11001100;
		    end
		    3'b010:begin
			mask_bank_sel = 00100010;
		    end
		    3'b100:begin
			mask_bank_sel = 00010001;
		    end
		    default: begin
			mask_bank_sel = 00000000;
		    end
		endcase
            end
            default: begin
               // Default safety
            end
        endcase
    end

    //-------------------------------------------------------------------------
    // 4.3. Raw Index Extraction
    // PDF Source 65-67:
    // 4K: VA[19:12] -> VPN[7:0]
    // 2M: VA[28:21] -> VPN[16:9]
    // 1G: VA[37:30] -> VPN[25:18]
    //-------------------------------------------------------------------------
    logic [IDX_WIDTH-1:0] idx_4k;
    logic [IDX_WIDTH-1:0] idx_2m;
    logic [IDX_WIDTH-1:0] idx_1g;

    assign idx_4k = sel_vpn[7:0];
    assign idx_2m = sel_vpn[16:9];
    assign idx_1g = sel_vpn[25:18];

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_raw_idx
            assign raw_idx[i] = ({IDX_WIDTH{size_pred[i] == SZ_1G}} & idx_1g) |
                                ({IDX_WIDTH{size_pred[i] == SZ_2M}} & idx_2m) |
				({IDX_WIDTH{size_pred[i] == SZ_4K}} & idx_4k) ;
        end
    endgenerate

    //-------------------------------------------------------------------------
    // 4.4. Hashing / Skewing Logic
    // PDF Source 70-76
    // Note: VA bit positions are shifted by 12 to map to VPN
    //-------------------------------------------------------------------------
    
    // Helper function for bit reversal
    function [IDX_WIDTH-1:0] bit_reverse(input [IDX_WIDTH-1:0] in);
        integer k;
        begin
            for (k=0; k<IDX_WIDTH; k=k+1)
                bit_reverse[k] = in[IDX_WIDTH-1-k];
        end
    endfunction

    always_comb begin
        // Way 0: Direct (Source 70)
        skew_idx[0] = raw_idx[0];

        // Way 1: Raw ^ VA[27:20] -> Raw ^ VPN[15:8] (Source 71)
        skew_idx[1] = raw_idx[1] ^ sel_vpn[15:8];

        // Way 2: Raw ^ VA[35:28] -> Raw ^ VPN[23:16] (Source 72)
        skew_idx[2] = raw_idx[2] ^ sel_vpn[23:16];

        // Way 3: Raw ^ {VA[15:12], VA[23:20]} -> Raw ^ {VPN[3:0], VPN[11:8]} (Source 73)
        // Note: Assuming concatenation order matches visual representation (High, Low)
        skew_idx[3] = raw_idx[3] ^ {sel_vpn[3:0], sel_vpn[11:8]};

        // Way 4: Rotate Left 1 (Source 74) -> {raw[6:0], raw[7]}
        skew_idx[4] = raw_idx[4] ^ {raw_idx[4][IDX_WIDTH-2:0], raw_idx[4][IDX_WIDTH-1]};

        // Way 5: Rotate Right 2 (Source 75) -> {raw[1:0], raw[7:2]}
        skew_idx[5] = raw_idx[5] ^ {raw_idx[5][1:0], raw_idx[5][IDX_WIDTH-1:2]};

        // Way 6: Bit Reverse (Source 76)
        skew_idx[6] = raw_idx[6] ^ bit_reverse(raw_idx[6]);

        // Way 7: Raw ^ VA[38:31] -> Raw ^ VPN[26:19] (Source 77)
        skew_idx[7] = raw_idx[7] ^ sel_vpn[26:19];
    end

    //=========================================================================
    // 5. Output Assignments
    //=========================================================================
    assign arb_l2tlb_trans_id = {TRANS_ID_WIDTH{arb_reqq_grant}} & issue_queue_id;
				//({TRANS_ID_WIDTH{arb_ptw_grant}}    & ptw_arb_trans_id)
				//| ({TRANS_ID_WIDTH{arb_reqq_grant}} & issue_queue_id);
        
    
    assign arb_l2tlb_eid      = ({EID_W{arb_reqq_grant}}    & issue_eid);

    logic arb_load_grant;
    logic arb_store_grant;
    logic arb_itlb_grant;

    assign arb_load_grant   = (issue_type == 3'b010) & arb_reqq_grant;
    assign arb_store_grant  = (issue_type == 3'b110) & arb_reqq_grant;
    assign arb_itlb_grant   = (issue_type == 3'b011) & arb_reqq_grant;

    assign arb_l2tlb_acc_type[2:0] = {3{arb_pfu_grant}}     & 3'b100
				  | {3{arb_ptw_write_grant}} &3'b101
                                  | {3{arb_itlb_grant}}   & 3'b011
                                  //| {3{arb_read_huge}}     & jtlb_arb_type[2:0]
                                  | {3{arb_load_grant}}    & 3'b010
                                  | {3{arb_store_grant}}   & 3'b110
                                  | {3{arb_tlboper_grant}} & 3'b001
                                  //| {3{arb_par_clr}}       & 3'b000
                                  | {3{arb_ptw_grant}}     & 3'b000;
    

    assign arb_l2tlb_cmp_with_va = arb_pfu_grant
                                | arb_reqq_grant
                                //| arb_dutlb_grant
                                //| arb_read_huge && jtlb_arb_cmp_va
                                //|| arb_par_clr && jtlb_arb_cmp_va
                                | (arb_tlboper_grant && tlboper_arb_cmp_va);  
    //assign arb_l2tlb_cmp_va   =	;//for l2tlb hit/miss signal generate

    assign arb_l2tlb_bank_sel[WAY_NUM-1:0] = {WAY_NUM{arb_pfu_grant}}     & {WAY_NUM{1'b1}}
                              | {WAY_NUM{arb_reqq_grant}}   & {WAY_NUM{1'b1}}
                              //| {4{arb_read_huge}}     & 4'b1111
                              //| {WAY_NUM{arb_par_clr}}       & 4'b1111
                              | {WAY_NUM{arb_ptw_write_grant}}   & victim_way[WAY_NUM-1:0]
                              | {WAY_NUM{arb_tlboper_grant}} & tlboper_arb_bank_sel[WAY_NUM-1:0]
                              | {WAY_NUM{arb_ptw_grant}}     & mask_bank_sel[WAY_NUM-1:0];

    //assign arb_l2tlb_bank_sel =		;//ptw read:mask_bank_sel; ptw write: victim way; reqq or prefetch:all; tlb operation : tlb_bank_sel

    assign tlboper_idx_not_va_sel = arb_tlboper_grant && tlboper_arb_idx_not_va;





    // Assign calculated skew indices to output ports
    assign arb_l2tlb_idx_w0 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[0];
    assign arb_l2tlb_idx_w1 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[1];
    assign arb_l2tlb_idx_w2 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[2];
    assign arb_l2tlb_idx_w3 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[3];
    assign arb_l2tlb_idx_w4 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[4];
    assign arb_l2tlb_idx_w5 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[5];
    assign arb_l2tlb_idx_w6 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[6];
    assign arb_l2tlb_idx_w7 = tlboper_idx_not_va_sel ? tlboper_arb_idx[7:0] : skew_idx[7];
    
    //assign arb_l2tlb_size_w0 = size_pred[0];
    //assign arb_l2tlb_size_w1 = size_pred[1];
    //assign arb_l2tlb_size_w2 = size_pred[2];
    //assign arb_l2tlb_size_w3 = size_pred[3];
    //assign arb_l2tlb_size_w4 = size_pred[4];
    //assign arb_l2tlb_size_w5 = size_pred[5];
    //assign arb_l2tlb_size_w6 = size_pred[6];
    //assign arb_l2tlb_size_w7 = size_pred[7]; 
    assign arb_l2tlb_size_bus = {size_pred[7], size_pred[6], size_pred[5], size_pred[4], size_pred[3], size_pred[2], size_pred[1], size_pred[0]};

endmodule
