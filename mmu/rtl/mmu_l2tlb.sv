module mmu_l2tlb#(

    // Moving derived parameters AFTER base parameters to fix compilation dependency error
    parameter VPN_WIDTH      = 27,         // SV39
    parameter PPN_WIDTH      = 28,         // SV39
    parameter FLG_WIDTH      = 14,
    parameter PGS_WIDTH      = 3,
    parameter ASID_WIDTH     = 16,
    parameter IDX_WIDTH      = 8,          // 256 Sets
    parameter WAY_NUM        = 8,          // 8 Skewed Ways
    parameter TRANS_ID_WIDTH = 3,          // Mafinalhes Reqq ID Width
    parameter L1EID_WIDTH    = 3,
    parameter L2EID_WIDTH    = 3,
    parameter TYPE_WIDTH     = 3,          // 2 bits for req type
    parameter DTLB_DEPTH     = 8,
    parameter RRPV_WIDTH     = 3,
    
    // Derived Parameters
    parameter TAG_WIDTH  = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,
    parameter DATA_WIDTH = PPN_WIDTH+FLG_WIDTH,
    parameter EID_WIDTH  = L1EID_WIDTH, // Added missing localparam definition
    parameter VPN_PERLEL = 9            // Added missing localparam definition

)(

    //!************************************************
    //! Clock and Reset
    //!************************************************
    input  logic                    cpurst_b,
    input  logic                    forever_cpuclk,
    input  logic                    pad_yy_icg_scan_en,

    //!************************************************
    //! SysReg Interface
    //!************************************************
    input  logic                    cp0_mmu_icg_en,
    input  logic                    cp0_mmu_maee,
    input  logic [1  :0]            cp0_mmu_mpp,
    input  logic                    cp0_mmu_mprv,
    input  logic                    cp0_mmu_mxr,
    input  logic                    cp0_mmu_ptw_en,
    input  logic                    cp0_mmu_sum,
    input  logic [1  :0]            cp0_yy_priv_mode,
    input  logic [15 :0]            regs_l2tlb_cur_asid,

    //!*****************************************************
    //! Arbiter <=> L2TLB Interface (Modified)
    //!*****************************************************
    //pfu <=> arb
    output logic [VPN_WIDTH-1:0]    l2tlb_arb_pfu_vpn,
    

    //l2tlb request queue request to arb
    output logic                    queue_arb_req,
    output logic [VPN_WIDTH-1:0]    queue_arb_vpn,
    output logic [L1EID_WIDTH-1:0]  queue_arb_eid,//l1dtlb miss buffer entry id
    output logic [TRANS_ID_WIDTH-1:0] queue_arb_trans_id,//l2tlb request queue entry id
    output logic [TYPE_WIDTH-1:0]   queue_arb_acc_type,
    //output logic                    queue_arb_is_dtlb,

    //for ptw write req
    output logic [WAY_NUM-1:0]      victim_way,
    output logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] rrpv_updata,

    output logic                    l2tlb_arb_ptw_cmplt,

    //arb response to l2tlb request queue
    input logic                     arb__l2tlb_queue_grant,

    // Requests & Data
    input  logic [WAY_NUM-1:0]      arb_l2tlb_bank_sel,
    input  logic [TYPE_WIDTH-1:0]   arb_l2tlb_acc_type,

    input  logic                    arb_l2tlb_req,          // Valid Request
    input  logic [VPN_WIDTH-1:0]    arb_l2tlb_vpn,          // Virtual Page Number
    input  logic [TRANS_ID_WIDTH-1:0] arb_l2tlb_trans_id,   // [NEW] Transaction ID from Queue
    input  logic [EID_WIDTH-1:0]    arb_l2tlb_eid,          //l1dtlb miss buffer entry index
    
    input  logic                    arb_l2tlb_write,        // Global Write Enable
    //input  logic [WAY_NUM-1:0]      arb_l2tlb_way_sel,      // [MOD] 8-bit Way Select (for TLBWI/Refill)
    
    input  logic [47 :0]            arb_l2tlb_tag_din,      // Tag Write Data
    input  logic [41 :0]            arb_l2tlb_data_din,     // Data Write Data
    input  logic                    arb_l2tlb_cmp_with_va,
    
    // Skew Indices (8 Independent Hashed Indices)
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w0,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w1,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w2,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w3,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w4,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w5,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w6,
    input  logic [IDX_WIDTH-1:0]    arb_l2tlb_idx_w7,
    
    input  logic [WAY_NUM*PGS_WIDTH-1:0]    arb_l2tlb_size_bus,
    input  logic [WAY_NUM*RRPV_WIDTH-1:0]   arb_l2tlb_rrpv_din,

    // Status / Handshake (Simplified)
    //output logic                    l2tlb_arb_hit,          // Hit signal for Arbiter/PTW use
    //output logic                    l2tlb_arb_miss,         // Miss signal
    
    //!*****************************************************
    //! Request Queue Feedback Interface (NEW)
    //!*****************************************************
    //output logic                    l2tlb_reqq_fb_vld,        // Feedback Valid
    //output logic [TRANS_ID_WIDTH-1:0] l2tlb_reqq_fb_id,       // Transaction ID
    //output logic                    l2tlb_reqq_fb_hit,        // Hit
    //output logic                    l2tlb_reqq_fb_miss_alloc, // Miss & Buffer Allocated
    //output logic                    l2tlb_reqq_fb_miss_retry, // Miss & Retry needed (Buffer Full)

    //!*****************************************************
    //! PTW (Page Table Walker) <=> JTLB Interface
    //!*****************************************************
    //input  logic [26 :0]            ptw_arb_vpn,
    input  logic [TYPE_WIDTH-1:0]   ptw_l2tlb_ref_type,
    //input  logic                    ptw_l2tlb_dmiss,
    //input  logic                    ptw_l2tlb_imiss,
    //input  logic                    ptw_l2tlb_pmiss,
    input  logic                    ptw_l2tlb_ref_acc_err,
    input  logic                    ptw_l2tlb_ref_cmplt,
    input  logic                    ptw_l2tlb_ref_data_vld,
    input  logic [13 :0]            ptw_l2tlb_ref_flg,
    input  logic                    ptw_l2tlb_ref_pgflt,
    //input  logic [2  :0]            ptw_l2tlb_ref_pgs,
    //input  logic [27 :0]            ptw_l2tlb_ref_ppn,
    input  logic [L1EID_WIDTH+L2EID_WIDTH-1:0] ptw_l2tlb_ref_id,

    // PTW Ready (Needed for Miss Buffer)
    input  logic                     ptw_ready,

    output logic [L1EID_WIDTH+L2EID_WIDTH-1:0]l2tlb_ptw_id,      // Needed for PTW to track transaction,l2tlb miss buffer entry id


    output logic                    l2tlb_ptw_req,
    output logic [2  :0]            l2tlb_ptw_type,
    output logic [26 :0]            l2tlb_ptw_vpn,

    //!*****************************************************
    //! JTLB => uTLB (L1DTLB/L1ITLB) Interface
    //!*****************************************************
    //output logic                    l2tlb_l1dtlb_acc_err,
    output logic                    l2tlb_l1dtlb_pgflt,
    output logic                    l2tlb_l1dtlb_ref_cmplt,
    output logic                    l2tlb_l1dtlb_ref_pavld,
    output logic [L1EID_WIDTH-1:0]  l2tlb_l1dtlb_ref_eid, // Output to L1 DTLB





   // output logic                    l2tlb_l1itlb_acc_err,
    output logic                    l2tlb_l1itlb_pgflt,
    output logic                    l2tlb_l1itlb_ref_cmplt,
    output logic                    l2tlb_l1itlb_ref_pavld,

    output logic [13 :0]            l2tlb_l1tlb_ref_flg,
    output logic [2  :0]            l2tlb_l1tlb_ref_pgs,
    output logic [27 :0]            l2tlb_l1tlb_ref_ppn,
    output logic [26 :0]            l2tlb_l1tlb_ref_vpn,
    output logic                    l2tlb_top_utlb_pavld, //for ct_mmu_top generate clk_en
    


    // L1 ITLB Interface
    input  logic                     i_req_valid,
    input  logic [VPN_WIDTH-1:0]     i_req_vpn,
    //input  logic [ASID_WIDTH-1:0]    i_req_asid,
    output logic                     i_credit_return,

    // L1 DTLB Interface
    input  logic                     d_req_valid,
    input  logic [VPN_WIDTH-1:0]     d_req_vpn,
    //input  logic [ASID_WIDTH-1:0]    d_req_asid,
    input  logic [L1EID_WIDTH-1:0]   d_req_eid,
    //input  logic [TYPE_WIDTH-1:0]    d_req_type,
    input  logic		     d_req_is_load,
    output logic                     d_credit_return,

    //!*****************************************************
    //! LSU (Load/Store Unit) PFU Path <=> JTLB Interface
    //!*****************************************************
    input  logic                    l1dtlb_xx_mmu_off,
    input  logic [27 :0]            lsu_mmu_va2,
    input  logic                    lsu_mmu_va2_vld,
    output logic [27 :0]            mmu_lsu_pa2,
    output logic                    mmu_lsu_pa2_err,
    output logic                    mmu_lsu_pa2_vld,
    output logic                    mmu_lsu_sec2,
    output logic                    mmu_lsu_share2,

    //!*****************************************************
    //! TLB Operation Interface
    //!*****************************************************
    input  logic [15 :0]            tlboper_l2tlb_asid,
    input  logic                    tlboper_l2tlb_asid_sel,
    input  logic                    tlboper_l2tlb_cmp_noasid,
    input  logic [15 :0]            tlboper_l2tlb_inv_asid,
    input  logic                    tlboper_l2tlb_tlbwr_on,
    input  logic                    tlboper_l2tlb_invasid_on,
    input  logic [2  :0]            tlboper_xx_pgs,
    input  logic                    tlboper_ptw_abort,
    //input  logic                    tlboper_xx_pgs_en,

    output logic                    l2tlb_regs_hit,
    output logic                    l2tlb_regs_hit_mult,
    output logic [10 :0]            l2tlb_regs_tlbp_hit_index, // Note: Index meaning changes in Skew TLB
    output logic                    l2tlb_tlboper_asid_hit,
    output logic                    l2tlb_tlboper_cmplt,
    output logic [WAY_NUM-1:0]      l2tlb_tlboper_sel,         // [MOD] 8-bit Way Select Feedback
    output logic                    l2tlb_tlboper_va_hit,

    output logic [15 :0]            l2tlb_tlbr_asid,
    output logic [13 :0]            l2tlb_tlbr_flg,
    output logic                    l2tlb_tlbr_g,
    output logic [2  :0]            l2tlb_tlbr_pgs,
    output logic [27 :0]            l2tlb_tlbr_ppn,
    output logic [26 :0]            l2tlb_tlbr_vpn,

    //!*****************************************************
    //! PMP (Physical Memory Protection) Interface
    //!*****************************************************
    input  logic [3  :0]            pmp_mmu_flg4,
    output logic [27 :0]            mmu_pmp_pa4,

    //!*****************************************************
    //! System Map Interface
    //!*****************************************************
    input  logic [4  :0]            sysmap_mmu_flg4,
    output logic [27 :0]            mmu_sysmap_pa4
);


    //==========================================================
    //                  Internal Wires Definition
    //==========================================================
    logic                       push_req;
    logic [WAY_NUM-1:0] [IDX_WIDTH-1:0] raw_bank_index;
    logic [WAY_NUM-1:0] [IDX_WIDTH-1:0] final_bank_index;
    logic                       wbuf_full;
    logic                       wbuf_pop_grant;
    logic                       wbuf_empty;
    logic [WAY_NUM-1:0]         wbuf_cam_hit;
    logic [WAY_NUM-1:0] [IDX_WIDTH-1:0] rrpv_sram_idx;
    logic [WAY_NUM-1:0] [RRPV_WIDTH-1:0]rrpv_sram_wdata;
    logic [WAY_NUM*RRPV_WIDTH-1:0] rrpv_lookup_updata;
    logic [WAY_NUM*RRPV_WIDTH-1:0] l2tlb_rrpv_din;
    logic [WAY_NUM-1:0] [RRPV_WIDTH-1:0]bypassed_rrpv_rdata;

    // Internal Feedback Wires (Hidden from Top Level Ports)
    logic                       l2tlb_reqq_fb_vld;
    logic [TRANS_ID_WIDTH-1:0]  l2tlb_reqq_fb_id;
    logic                       l2tlb_reqq_fb_hit;
    logic                       l2tlb_reqq_fb_miss_alloc;
    logic                       l2tlb_reqq_fb_miss_retry;

    // 1. Wires: Reqq -> Pipeline (Simulating the old Arbiter inputs)
    logic                       arb_l2tlb_req_internal; // Rename to avoid conflict if input
    logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;
    logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;
    logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;
    logic [TYPE_WIDTH-1:0]      arb_l2tlb_type;    // Derived from reqq
    logic                       arb_l2tlb_is_dtlb;
    
    // Pipeline Grant Logic
    logic                       l2tlb_pipe_grant;
    
    // 2. Wires: Miss Buffer -> PTW
    logic                       mb_issue_req;
    logic [L1EID_WIDTH+L2EID_WIDTH-1:0]  mb_issue_eid;      // This is the Reqq ID
    logic                       mb_issue_is_dtlb;
    logic [VPN_WIDTH-1:0]       mb_issue_vpn;
    logic [TYPE_WIDTH-1:0]      mb_issue_type;     // Note: PTW usually needs 3 bits
    
    // 3. Wires: Pipeline -> Miss Buffer (Miss Allocation)
    logic                       l2tlb_miss;        // From hit logic
    logic                       mb_alloc_en;       // Enable MB allocation on miss
    
    // 4. Feedback Wires
    logic                       fb_hit;
    logic                       fb_miss_alloc;
    logic                       fb_miss_retry;

    // Tag Array Read Data
    logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;
    logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus; 
    logic [WAY_NUM*RRPV_WIDTH-1:0] l2tlb_rrpv_dout_bus; 

    logic                       mb_alloc_valid;
    logic                       req_alloc_valid;
    //logic [47:0]     l2tlb_tag_dout_w0;
    //logic [47:0]     l2tlb_tag_dout_w1;
    //logic [47:0]     l2tlb_tag_dout_w2;
    //logic [47:0]     l2tlb_tag_dout_w3;
    //logic [47:0]     l2tlb_tag_dout_w4;
    //logic [47:0]     l2tlb_tag_dout_w5;
    //logic [47:0]     l2tlb_tag_dout_w6;
    //logic [47:0]     l2tlb_tag_dout_w7;

    // Data Array Read Data
    //logic [41:0]     l2tlb_data_dout_w0;
    //logic [41:0]     l2tlb_data_dout_w1;
    //logic [41:0]     l2tlb_data_dout_w2;
    //logic [41:0]     l2tlb_data_dout_w3;
    //logic [41:0]     l2tlb_data_dout_w4;
    //logic [41:0]     l2tlb_data_dout_w5;
    //logic [41:0]     l2tlb_data_dout_w6;
    //logic [41:0]     l2tlb_data_dout_w7;

    // Write Enables
    logic [WAY_NUM-1:0]      l2tlb_tag_wen;
    logic [WAY_NUM-1:0]      l2tlb_data_wen;

    logic [WAY_NUM-1:0][IDX_WIDTH-1:0]  way_index;

    logic [TAG_WIDTH-1:0] raw_way_tag [WAY_NUM-1:0];
    logic [DATA_WIDTH-1:0] raw_way_data [WAY_NUM-1:0];
    logic [2:0]            raw_pre_pgs [WAY_NUM-1:0];

    logic [WAY_NUM-1:0]                 raw_way_vld;
    logic [WAY_NUM-1:0][PGS_WIDTH-1:0]            raw_way_pgs; 
    logic [WAY_NUM-1:0][ASID_WIDTH-1:0] raw_way_asid; 
    logic [WAY_NUM-1:0]                 raw_way_g;
    
    logic [WAY_NUM-1:0][VPN_WIDTH-1:0]  raw_vpn_masked;
    logic [WAY_NUM-1:0][VPN_WIDTH-1:0]  raw_way_vpn;
    
    
    logic [WAY_NUM-1:0] raw_way_hit_kid0, raw_way_hit_kid1, raw_way_hit_kid2;
    logic [WAY_NUM-1:0] raw_way_hit_kid3, raw_way_hit_kid4, raw_way_hit_kid5;
    
    logic [WAY_NUM-1:0] final_way_hit_kid0, final_way_hit_kid1, final_way_hit_kid2;
    logic [WAY_NUM-1:0] final_way_hit_kid3, final_way_hit_kid4, final_way_hit_kid5;
    logic [WAY_NUM-1:0] final_way_hit;
    logic [WAY_NUM-1:0] final_way_asid_hit;
    logic [WAY_NUM-1:0] final_way_sel; 
    
    // Register definitions
    logic                       raw_vld;
    logic [VPN_WIDTH-1:0]       raw_vpn;
    logic [TRANS_ID_WIDTH-1:0]  raw_trans_id;
    logic [TAG_WIDTH-1:0]       raw_tag;
    logic [EID_WIDTH-1:0]       raw_eid;
    logic [TRANS_ID_WIDTH-1:0]  raw_queue_id;
    logic [WAY_NUM-1:0]         raw_way_mask;
    logic                       raw_cmp_with_va;
    logic [WAY_NUM*3-1:0]       raw_arb_pre_pgs;
    logic [TYPE_WIDTH-1:0]	raw_acc_type;
    logic			raw_is_dtlb;

    logic [WAY_NUM-1:0]         raw_tlbop_idx_sel;

    logic                       final_vld;
    logic [VPN_WIDTH-1:0]       final_vpn;
    logic [TRANS_ID_WIDTH-1:0]  final_trans_id;
    logic [TAG_WIDTH-1:0]       final_tag;
    logic [EID_WIDTH-1:0]       final_eid;
    logic [TRANS_ID_WIDTH-1:0]  final_queue_id;
    logic                       final_cmp_with_va;
    logic [WAY_NUM-1:0]         tlboper_way_sel;

    logic [WAY_NUM-1:0]         final_way_vld;
    logic [WAY_NUM-1:0][VPN_WIDTH-1:0] final_way_vpn;
    logic [WAY_NUM-1:0][PGS_WIDTH-1:0] final_way_pgs;
    logic [WAY_NUM-1:0][ASID_WIDTH-1:0] final_way_asid;
    logic [WAY_NUM-1:0]         final_way_g;
    logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;
    logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;

    logic [2:0]                 l2tlb_cur_pgs [WAY_NUM-1:0];
    logic [2:0]                 final_hit_sum;
    logic                       final_par_fail;
    logic                       final_tlb_miss;
    logic                       final_tlb_hit;
    logic                       final_tlb_hit_mult;
    logic                       final_cmp_va;
    
    logic                       l2tlb_mb_req;
    
    logic [TYPE_WIDTH-1:0]      final_acc_type; // Inferred
    logic                       final_is_dtlb;  // Inferred
    logic                       ptw_req;
    logic                       final_pa_vld;

    logic [VPN_WIDTH-1:0]       raw_vpn_4k;
    logic [VPN_WIDTH-1:0]       raw_vpn_2m;
    logic [VPN_WIDTH-1:0]       raw_vpn_1g;

    logic [ASID_WIDTH-1:0]      asid_for_va_hit;

    logic                       l2tlb_clk_en;
    logic                       l2tlb_clk;
    
    // Missing wires inferred from usage
    logic                       ta_vld; 
    logic                       pfu_idle_st;
    
    logic [VPN_WIDTH-1:0]       final_vpn_4k;
    logic [VPN_WIDTH-1:0]       final_vpn_2m;
    logic [VPN_WIDTH-1:0]       final_vpn_1g;
    logic [VPN_WIDTH-1:0]       final_vpn_masked;

    //==========================================================
    //              Missing Logic Definitions (Patch)
    //==========================================================
    
    // 1. RRPV Control Signals
    logic                       rrpv_write_ptw;
    logic                       rrpv_write_lookup;
    logic                       rrpv_write_tlboper;
    localparam [RRPV_WIDTH-1:0] RRPV_VALID_INIT = 3;

    // 2. Completion & Result Signals
    logic                       final_l1tlb_cmplt;
    
    // 3. Refill / Bypass Signals (Refill Result Mux)
    logic [VPN_WIDTH-1:0]       ref_vpn;
    logic [PGS_WIDTH-1:0]       ref_pgs;
    logic [PPN_WIDTH-1:0]       ref_ppn;
    logic [FLG_WIDTH-1:0]       ref_flg;

    // 4. Privilege Mode Decode
    logic [1:0]                 cp0_priv_mode;
    logic                       cp0_user_mode;
    logic                       cp0_supv_mode;
    logic                       cp0_mach_mode;

    // 5. Prefetch Unit (PFU) FSM States
    logic [1:0]                 pfu_cur_st;
    logic [1:0]                 pfu_nxt_st;

    // 6. PFU Check Logic & Status
    logic                       pfu_off_chk;
    logic                       l2tlb_pfu_cmplt;
    logic                       l2tlb_pfu_flag_fault;
    logic                       l2tlb_pfu_acc_fault;
    logic                       l2tlb_pfu_deny; 
    // 7. PFU Physical Address Calculation
    logic [VPN_WIDTH-1:0]       pa_offset;
    logic [PPN_WIDTH-1:0]       ptw_pa2;
    logic [PPN_WIDTH-1:0]       l2tlb_pfu_pa;
    logic                       l2tlb_pfu_sec;
    logic                       l2tlb_pfu_share;

    // 8. PFU Buffers (Flops)
    logic [PPN_WIDTH-1:0]       pfu_pa_buf;
    logic                       pfu_sec_buf;
    logic                       pfu_share_buf;
    logic			pfu_ok_st;
    logic			pfu_deny_st;

    //==========================================================
    //               1. Instantiate Request Queue
    //==========================================================    
    // The pipeline grant logic: 
    // Usually logic 1 unless there is a structural hazard (stall) in L2TLB pipeline.
    // Assuming L2TLB is fully pipelined and 1-cycle throughput for now.
    assign l2tlb_pipe_grant = arb__l2tlb_queue_grant; 

    logic [TYPE_WIDTH-1:0] d_req_type;
    assign d_req_type = d_req_is_load ? 3'b010 :3'b110;

    mmu_l2tlb_reqq#(
        .DTLB_DEPTH (DTLB_DEPTH),
        .VPN_W      (VPN_WIDTH),
        .ASID_W     (ASID_WIDTH),
        .EID_W      (L1EID_WIDTH),
        .TYPE_W     (TYPE_WIDTH)
    ) x_l2tlb_reqq (
        // Global
        .cp0_mmu_icg_en     (cp0_mmu_icg_en),
        .cpurst_b           (cpurst_b),
        .reqq_clk           (forever_cpuclk), // Using forever clock, gated internally if needed
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en),

        // L1 ITLB Interface
        .i_req_valid        (i_req_valid),
        .i_req_vpn          (i_req_vpn),
        //.i_req_asid         (i_req_asid),
        .i_credit_return    (i_credit_return),

        // L1 DTLB Interface
        .d_req_valid        (d_req_valid),
        .d_req_vpn          (d_req_vpn),
        //.d_req_asid         (d_req_asid),
        .d_req_eid          (d_req_eid),
        .d_req_type         (d_req_type),
        .d_credit_return    (d_credit_return),

        // Issue to Pipeline (Internal "Arbiter" signals)
        .issue_valid        (queue_arb_req),
        .issue_queue_id     (queue_arb_trans_id),
        //.issue_is_dtlb      (queue_arb_is_dtlb),
        .issue_vpn          (queue_arb_vpn),
        //.issue_asid         (/* Not used in Arb interface currently, logic uses regs_asid */), 
        .issue_eid          (queue_arb_eid),
        .issue_type         (queue_arb_acc_type),
        
        .issue_grant        (l2tlb_pipe_grant),

        // Feedback from PTW/Pipeline Completion
        .fb_valid           (l2tlb_reqq_fb_vld),
        .fb_trans_id        (l2tlb_reqq_fb_id),
        .fb_hit             (l2tlb_reqq_fb_hit),
        .fb_miss_alloc      (l2tlb_reqq_fb_miss_alloc),
        .fb_miss_retry      (l2tlb_reqq_fb_miss_retry)
    );

    //==========================================================
    //                  Logic
    //==========================================================

    // Generate Write Enable signals for each way
    // Write only when arbiter indicates write (arb_l2tlb_write) AND way is selected
    assign l2tlb_tag_wen  = {WAY_NUM{arb_l2tlb_write}} & arb_l2tlb_bank_sel;
    assign l2tlb_data_wen = {WAY_NUM{arb_l2tlb_write}} & arb_l2tlb_bank_sel;


    //==========================================================
    //                  SRAM Array Instantiation
    //==========================================================
    // 1. Aggregated Index Bus for Skewed Arrays
    logic [WAY_NUM*IDX_WIDTH-1:0] arb_l2tlb_idx_bus;
    assign arb_l2tlb_idx_bus = {arb_l2tlb_idx_w7, arb_l2tlb_idx_w6, arb_l2tlb_idx_w5, arb_l2tlb_idx_w4, 
                                arb_l2tlb_idx_w3, arb_l2tlb_idx_w2, arb_l2tlb_idx_w1, arb_l2tlb_idx_w0};

    // 2. RRPV Arbitration Logic
    logic rrpv_write_en;
    logic [WAY_NUM-1:0] l2tlb_rrpv_cen;
    logic [WAY_NUM-1:0] l2tlb_rrpv_wen;
    logic [WAY_NUM*IDX_WIDTH-1:0] l2tlb_rrpv_idx_mux;
    
    // Write when WBUF has data and is granted
    assign rrpv_write_en = rrpv_write_ptw | rrpv_write_lookup | rrpv_write_tlboper;
    assign rrpv_write_ptw = arb_l2tlb_req & arb_l2tlb_acc_type == 3'b101 & arb_l2tlb_write;
    assign rrpv_write_lookup = !wbuf_empty && wbuf_pop_grant;
    assign rrpv_write_tlboper = arb_l2tlb_req
                              & (arb_l2tlb_acc_type == 3'b001)
                              & arb_l2tlb_write
                              & arb_l2tlb_tag_din[TAG_WIDTH-1];
    
    // Enable RAM if Lookup (arb_req) OR Write (rrpv_write_en)
    assign l2tlb_rrpv_cen = {WAY_NUM{arb_l2tlb_req}} | {WAY_NUM{rrpv_write_en}};
    
    // Write Enable Mask
    assign l2tlb_rrpv_wen = ({WAY_NUM{rrpv_write_lookup | rrpv_write_ptw}} & {WAY_NUM{1'b1}})
                           | ({WAY_NUM{rrpv_write_tlboper}} & arb_l2tlb_bank_sel);
    
    // Address Mux: Write Index vs Lookup Index
    assign l2tlb_rrpv_idx_mux = (rrpv_write_lookup | rrpv_write_ptw) ? rrpv_sram_idx : arb_l2tlb_idx_bus;

    assign rrpv_lookup_updata = {rrpv_sram_wdata[7],rrpv_sram_wdata[6],rrpv_sram_wdata[5],rrpv_sram_wdata[4],rrpv_sram_wdata[3],rrpv_sram_wdata[2],rrpv_sram_wdata[1],rrpv_sram_wdata[0]};
    assign l2tlb_rrpv_din = ({WAY_NUM*RRPV_WIDTH{rrpv_write_lookup}} & rrpv_lookup_updata
                            | {WAY_NUM*RRPV_WIDTH{rrpv_write_ptw}} & arb_l2tlb_rrpv_din
                            | {WAY_NUM*RRPV_WIDTH{rrpv_write_tlboper}} & {WAY_NUM{RRPV_VALID_INIT}});
                            
    //----------------------------------------------------------
    // 1. Tag Array Instance (8 Banks)
    //----------------------------------------------------------
    ct_mmu_l2tlb_tag_array #(
        .WAY_NUM(WAY_NUM),
        .ADDR_WIDTH(IDX_WIDTH),
        .VPN_WIDTH(VPN_WIDTH),
        .ASID_WIDTH(ASID_WIDTH),
        .PGS_WIDTH(PGS_WIDTH)
    ) x_l2tlb_tag_array (
        .cp0_mmu_icg_en     (cp0_mmu_icg_en),
        .forever_cpuclk     (forever_cpuclk),
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en),
        .l2tlb_tag_cen      ({WAY_NUM{arb_l2tlb_req}}),
        .l2tlb_tag_wen      (l2tlb_tag_wen),
        .l2tlb_tag_idx      (arb_l2tlb_idx_bus),
        .l2tlb_tag_din      (arb_l2tlb_tag_din),
        .l2tlb_tag_dout     (l2tlb_tag_dout_bus)
    );

    //----------------------------------------------------------
    // 2. Data Array Instance (8 Banks)
    //----------------------------------------------------------
    ct_mmu_l2tlb_data_array #(
        .WAY_NUM(WAY_NUM),
        .ADDR_WIDTH(IDX_WIDTH),
        .PPN_WIDTH(PPN_WIDTH),
        .FLG_WIDTH(FLG_WIDTH)
    ) x_l2tlb_data_array (
        .cp0_mmu_icg_en     (cp0_mmu_icg_en),
        .forever_cpuclk     (forever_cpuclk),
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en),
        .l2tlb_data_cen     ({WAY_NUM{arb_l2tlb_req}}),
        .l2tlb_data_wen     (l2tlb_data_wen),
        .l2tlb_data_idx     (arb_l2tlb_idx_bus),
        .l2tlb_data_din     (arb_l2tlb_data_din),
        .l2tlb_data_dout    (l2tlb_data_dout_bus)
    );
    
    //----------------------------------------------------------
    // 3. RRPV Array Instance (8 Banks)
    //----------------------------------------------------------
    ct_mmu_l2tlb_rrpv_array #(
        .WAY_NUM(WAY_NUM),
        .ADDR_WIDTH(IDX_WIDTH),
        .RRPV_WIDTH(RRPV_WIDTH)
    ) x_l2tlb_rrpv_array (
        .cp0_mmu_icg_en     (cp0_mmu_icg_en),
        .forever_cpuclk     (forever_cpuclk),
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en),
        .l2tlb_rrpv_cen     (l2tlb_rrpv_cen),
        .l2tlb_rrpv_wen     (l2tlb_rrpv_wen),
        .l2tlb_rrpv_idx     (l2tlb_rrpv_idx_mux),
        .l2tlb_rrpv_din     (l2tlb_rrpv_din), 
        .l2tlb_rrpv_dout    (l2tlb_rrpv_dout_bus)
    );

    assign l2tlb_clk_en = arb_l2tlb_req || raw_vld || final_vld //|| !read_cur_idle
                      || !pfu_idle_st || ptw_l2tlb_ref_cmplt
                      || lsu_mmu_va2_vld && l1dtlb_xx_mmu_off; 
    // &Instance("gated_clk_cell", "x_l2tlb_gateclk"); @53
    gated_clk_cell  x_l2tlb_gateclk (
      .clk_in             (forever_cpuclk    ),
      .clk_out            (l2tlb_clk          ),
      .external_en        (1'b0              ),
      .global_en          (1'b1              ),
      .local_en           (l2tlb_clk_en       ),
      .module_en          (cp0_mmu_icg_en    ),
      .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
    );

    assign way_index[0] = arb_l2tlb_idx_w0;
    assign way_index[1] = arb_l2tlb_idx_w1;
    assign way_index[2] = arb_l2tlb_idx_w2;
    assign way_index[3] = arb_l2tlb_idx_w3;
    assign way_index[4] = arb_l2tlb_idx_w4;
    assign way_index[5] = arb_l2tlb_idx_w5;
    assign way_index[6] = arb_l2tlb_idx_w6;
    assign way_index[7] = arb_l2tlb_idx_w7;


    always_ff@(posedge l2tlb_clk or negedge cpurst_b) begin
        if(!cpurst_b) begin
            raw_vld      <=     1'b0;
	end else if(arb_l2tlb_req & (arb_l2tlb_acc_type != 3'b101 && arb_l2tlb_acc_type != 3'b000)) begin
		raw_vld	 <=	1'b1;
	end else raw_vld <= 1'b0;
    end	    

    assign arb_l2tlb_is_dtlb = (arb_l2tlb_acc_type == 3'b010) | (arb_l2tlb_acc_type == 3'b110) | (arb_l2tlb_acc_type == 3'b100);

    always_ff@(posedge l2tlb_clk or negedge cpurst_b) begin
        if(!cpurst_b) begin
            //raw_vld      <=     1'b0;
            raw_vpn      <=     {VPN_WIDTH{1'b0}};
            //raw_trans_id <=     {TRANS_ID_WIDTH'b0};
            raw_tag      <=     {TAG_WIDTH{1'b0}};
            raw_eid      <=     {EID_WIDTH{1'b0}};
            raw_queue_id <=     {TRANS_ID_WIDTH{1'b0}};
            raw_bank_index<=     '{default:0};
            raw_way_mask <=     {WAY_NUM{1'b0}};
            raw_cmp_with_va <=  1'b0;
            raw_arb_pre_pgs <=  '{default:0};
            raw_acc_type[2:0] <= 3'b0;
            raw_is_dtlb  <= 1'b0;
        end
        else if(arb_l2tlb_req) begin
            //raw_vld      <=     arb_l2tlb_req;
            raw_vpn      <=     arb_l2tlb_vpn;
            //raw_trans_id <=     arb_l2tlb_trans_id;
            raw_tag      <=     arb_l2tlb_tag_din;
            raw_eid      <=     arb_l2tlb_eid;
            raw_queue_id <=     arb_l2tlb_trans_id;
            raw_bank_index<=     way_index;
            raw_way_mask <=     arb_l2tlb_bank_sel;
            raw_cmp_with_va <=  arb_l2tlb_cmp_with_va;
            raw_arb_pre_pgs <=  arb_l2tlb_size_bus;
            raw_acc_type <=     arb_l2tlb_acc_type;
            raw_is_dtlb  <=     arb_l2tlb_is_dtlb;
        end        
    end

    always_comb begin
        for(integer i = 0; i < WAY_NUM; i++) begin
            raw_way_tag[i]  = l2tlb_tag_dout_bus[(i+1)*TAG_WIDTH-1 -: TAG_WIDTH];
            raw_way_data[i] = l2tlb_data_dout_bus[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            raw_pre_pgs[i]  = raw_arb_pre_pgs[i*3 +:3];
        end
    end

      assign raw_tlbop_idx_sel[WAY_NUM-1:0]  = raw_way_mask[WAY_NUM-1:0] & {WAY_NUM{!raw_cmp_with_va}};
    //assign raw_vpn_4k =  raw_vpn[VPN_WIDTH-1:0];
    //assign raw_vpn_2m = {raw_vpn[VPN_WIDTH-1:VPN_PERLEL*1], {VPN_PERLEL*1{1'b0}}};
    //assign raw_vpn_1g = {raw_vpn[VPN_WIDTH-1:VPN_PERLEL*2], {VPN_PERLEL*2{1'b0}}};
    //assign raw_vpn_masked[VPN_WIDTH-1:0] = {VPN_WIDTH{l2tlb_cur_pgs[0]}} & raw_vpn_4k[VPN_WIDTH-1:0]
    //                                     | {VPN_WIDTH{l2tlb_cur_pgs[1]}} &  raw_vpn_2m[VPN_WIDTH-1:0]
    //                                     | {VPN_WIDTH{l2tlb_cur_pgs[2]}} &  raw_vpn_1g[VPN_WIDTH-1:0];
    //
    //assign l2tlb_cur_pgs[PGS_WIDTH-1:0] = tlboper_xx_pgs_en ? tlboper_xx_pgs[2:0]
     //                                                       : raw_pre_pgs;
    //
    //assign asid_for_va_hit[ASID_WIDTH-1:0] = tlboper_l2tlb_asid_sel   
    //                                       ? tlboper_l2tlb_asid[ASID_WIDTH-1:0]
    //                                       : regs_l2tlb_cur_asid[ASID_WIDTH-1:0];

    assign raw_vpn_4k =  raw_vpn[VPN_WIDTH-1:0];
    assign raw_vpn_2m = {raw_vpn[VPN_WIDTH-1:VPN_PERLEL*1], {VPN_PERLEL*1{1'b0}}};
    assign raw_vpn_1g = {raw_vpn[VPN_WIDTH-1:VPN_PERLEL*2], {VPN_PERLEL*2{1'b0}}};


    assign asid_for_va_hit[ASID_WIDTH-1:0] = tlboper_l2tlb_asid_sel   
                                           ? tlboper_l2tlb_asid[ASID_WIDTH-1:0]
                                           : regs_l2tlb_cur_asid[ASID_WIDTH-1:0];

    //!*****************************************************
    //!L2TLB hit logic 
    //!*****************************************************
    genvar i;
    generate
        for(i = 0;i < WAY_NUM;i++) begin: hit_determination            
            assign l2tlb_cur_pgs[i][PGS_WIDTH-1:0] =  raw_pre_pgs[i][PGS_WIDTH-1:0];

            //TAG_WIDTH  = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1
            assign raw_way_vld[i]  = raw_way_tag[i][TAG_WIDTH-1];                
            assign raw_way_vpn[i]  = raw_way_tag[i][TAG_WIDTH-2:TAG_WIDTH-1-VPN_WIDTH]; 
            assign raw_way_pgs[i]  = raw_way_tag[i][TAG_WIDTH-2-VPN_WIDTH-ASID_WIDTH:1];
            assign raw_way_asid[i] = raw_way_tag[i][TAG_WIDTH-2-VPN_WIDTH:TAG_WIDTH-1-VPN_WIDTH-ASID_WIDTH];
            assign raw_way_g[i]    = raw_way_tag[i][0];

            assign raw_vpn_masked[i] = {VPN_WIDTH{l2tlb_cur_pgs[i][0]}} & raw_vpn_4k[VPN_WIDTH-1:0]
                                       | {VPN_WIDTH{l2tlb_cur_pgs[i][1]}} &  raw_vpn_2m[VPN_WIDTH-1:0]
                                       | {VPN_WIDTH{l2tlb_cur_pgs[i][2]}} &  raw_vpn_1g[VPN_WIDTH-1:0];

           //way raw hit logic
            assign raw_way_hit_kid0[i] = (raw_way_vpn[i][VPN_PERLEL*1-1:0]   == raw_vpn_masked[i][VPN_PERLEL*1-1:0]);
            assign raw_way_hit_kid1[i] = (raw_way_vpn[i][VPN_PERLEL*2-1:VPN_PERLEL*1]  == raw_vpn_masked[i][VPN_PERLEL*2-1:VPN_PERLEL*1])
                                           && l2tlb_cur_pgs[i][PGS_WIDTH-1:0] == raw_way_pgs[i][PGS_WIDTH-1:0];
            assign raw_way_hit_kid2[i] = (raw_way_vpn[i][VPN_WIDTH-1:VPN_PERLEL*2] == raw_vpn_masked[i][VPN_WIDTH-1:VPN_PERLEL*2])
                                         && raw_way_vld[i];// && ta_cmp_va;
            assign raw_way_hit_kid3[i] = (raw_way_asid[i][VPN_PERLEL*1-1:0]   == asid_for_va_hit[VPN_PERLEL*1-1:0]);
            assign raw_way_hit_kid4[i] = (raw_way_asid[i][ASID_WIDTH-1:VPN_PERLEL*1]  == asid_for_va_hit[ASID_WIDTH-1:VPN_PERLEL*1]);
            assign raw_way_hit_kid5[i] =  raw_way_g[i] || tlboper_l2tlb_cmp_noasid;


           //way final hit logic
            always_ff@(posedge l2tlb_clk or negedge cpurst_b) begin
                if(!cpurst_b) begin
                    final_way_hit_kid0[i]  <=   1'b0; 
                    final_way_hit_kid1[i]  <=   1'b0; 
                    final_way_hit_kid2[i]  <=   1'b0; 
                    final_way_hit_kid3[i]  <=   1'b0; 
                    final_way_hit_kid4[i]  <=   1'b0; 
                    final_way_hit_kid5[i]  <=   1'b0; 
                end
                else if(raw_vld) begin
                    final_way_hit_kid0[i]  <=    raw_way_hit_kid0[i]; 
                    final_way_hit_kid1[i]  <=    raw_way_hit_kid1[i]; 
                    final_way_hit_kid2[i]  <=    raw_way_hit_kid2[i]; 
                    final_way_hit_kid3[i]  <=    raw_way_hit_kid3[i];
                    final_way_hit_kid4[i]  <=    raw_way_hit_kid4[i];
                    final_way_hit_kid5[i]  <=    raw_way_hit_kid5[i];
                end
            end

            always_ff@(posedge l2tlb_clk or negedge cpurst_b) begin
                if(!cpurst_b) begin
                    final_way_vld[i]    <= 1'b0;
                    final_way_vpn[i]    <= '{default:0};
                    final_way_pgs[i]    <= '{default:0};
                    final_way_asid[i]   <= '{default:0};
                    final_way_g[i]      <= 1'b0;
                    final_way_ppn[i]    <= '{default:0};
                    final_way_flg[i]    <= '{default:0};
                end
                else if(raw_vld) begin
                    final_way_vld [i]                 <= raw_way_vld[i];
                    final_way_vpn[i][VPN_WIDTH-1:0]   <= raw_way_vpn[i];
                    final_way_pgs[i][PGS_WIDTH-1:0]   <= raw_way_pgs[i];
                    final_way_asid[i][ASID_WIDTH-1:0] <= raw_way_asid[i];
                    final_way_g[i]                    <= raw_way_g[i];
                    //DATA_WIDTH = PPN_WIDTH+FLG_WIDTH
                    final_way_ppn[i][PPN_WIDTH-1:0]   <= raw_way_data[i][DATA_WIDTH-1:FLG_WIDTH];
                    final_way_flg[i][FLG_WIDTH-1:0]   <= raw_way_data[i][FLG_WIDTH-1:0];
                end
            end

            assign final_way_hit[i] = final_way_hit_kid0[i] & final_way_hit_kid1[i] & final_way_hit_kid2[i] 
                             & (final_way_hit_kid3[i] & final_way_hit_kid4[i] | final_way_hit_kid5[i]);
            assign final_way_asid_hit[i] = final_way_vld[i]
                                         & !final_way_g[i]
                                         & (final_way_asid[i][ASID_WIDTH-1:0] == tlboper_l2tlb_inv_asid[ASID_WIDTH-1:0]);
            assign final_way_sel[i] = final_way_hit[i] | tlboper_way_sel[i]   ;// | tlb operation
	end
    endgenerate  


    always_ff@(posedge l2tlb_clk or negedge cpurst_b) begin
        if(!cpurst_b) begin
            final_vld      <=     1'b0;
	end else if(raw_vld) begin
		final_vld	 <=	1'b1;
	end else final_vld <= 1'b0;
    end	    
    always_ff@(posedge l2tlb_clk or negedge cpurst_b) begin
        if(!cpurst_b) begin
            //final_vld      <=     1'b0;
            final_vpn      <=     {VPN_WIDTH{1'b0}};
            //final_trans_id <=     {TRANS_ID_WIDTH'b0};
            final_tag      <=     {TAG_WIDTH{1'b0}};
            final_eid      <=     {EID_WIDTH{1'b0}};
            final_queue_id <=     {TRANS_ID_WIDTH{1'b0}};
            final_bank_index<=    '{default:0};
            final_cmp_with_va <=  1'b0;
            tlboper_way_sel  <=    '{default:0};
            final_acc_type[2:0] <= 3'b0;
            final_is_dtlb   <= 1'b0;
            //final_pgs       <=    '{default:0};
        end
        else if(raw_vld) begin
            //final_vld       <=     raw_vld;     
            final_vpn       <=     raw_vpn;     
            //final_trans_id  <=     raw_trans_id;
            final_tag       <=     raw_tag;
            final_eid       <=     raw_eid;
            final_queue_id  <=     raw_queue_id;
            final_bank_index<=     raw_bank_index;
            final_cmp_with_va <=   raw_cmp_with_va;
            tlboper_way_sel <= raw_tlbop_idx_sel;
            final_acc_type[2:0] <= raw_acc_type;
            final_is_dtlb   <=     raw_is_dtlb;
            //final_pgs       <= 
        end
    end

    assign final_hit_sum[2:0] = {2'b0,final_way_hit[0]} + {2'b0,final_way_hit[1]} + {2'b0,final_way_hit[2]} + {2'b0,final_way_hit[3]}
                                + {2'b0,final_way_hit[4]} + {2'b0,final_way_hit[5]} + {2'b0,final_way_hit[6]} + {2'b0,final_way_hit[7]};

    assign final_par_fail     = 1'b0; 
    assign l2tlb_arb_par_clr  = final_par_fail;

    assign final_tlb_miss     = (final_hit_sum[2:0] == 3'b000);
    assign final_tlb_hit      = (final_hit_sum[2:0] == 3'b001) & final_cmp_with_va & !final_par_fail;
    assign final_tlb_hit_mult = !final_tlb_miss & !final_tlb_hit & !final_par_fail;

    assign l2tlb_miss = (final_vld & final_cmp_with_va & final_tlb_miss | final_par_fail); //|| final_vld && final_cmp_va && !final_tlb_miss && final_par_fail;

    assign l2tlb_mb_req = l2tlb_miss;

    //==========================================================
    // Variable Definition for Select Logic
    //==========================================================
    logic [VPN_WIDTH-1:0]  final_idx_vpn;
    logic [PGS_WIDTH-1:0]  final_idx_pgs;
    logic [ASID_WIDTH-1:0] final_idx_asid;
    logic                  final_idx_g;

    logic [PPN_WIDTH-1:0]  final_hit_ppn;
    logic [FLG_WIDTH-1:0]  final_hit_flg;
    logic [PGS_WIDTH-1:0]  final_hit_pgs;

    //==========================================================
    // Select Logic for TLB Read (Index) and Hit (Probe/Access)
    //==========================================================
    always_comb begin
        // 1. Initialize all outputs to 0
        final_idx_vpn  = {VPN_WIDTH{1'b0}};
        final_idx_pgs  = {PGS_WIDTH{1'b0}};
        final_idx_asid = {ASID_WIDTH{1'b0}};
        final_idx_g    = 1'b0;
        final_hit_ppn  = {PPN_WIDTH{1'b0}};
        final_hit_flg  = {FLG_WIDTH{1'b0}};
        final_hit_pgs  = {PGS_WIDTH{1'b0}};

        // 2. Iterate through all ways to select data
        for(int i = 0; i < WAY_NUM; i++) begin
            
            //------------------------------------------------------
            // Group A: TLB Read Index Selection (for tlbr instruction)
            // Data Source: final_way_* (Read data from SRAM)
            // Selection Source: l2tlb_tlboper_sel (Way select signal from CSR)
            //------------------------------------------------------
            if(tlboper_way_sel[i]) begin
                final_idx_vpn  |= final_way_vpn[i];
                final_idx_pgs  |= final_way_pgs[i];
                final_idx_asid |= final_way_asid[i];
                final_idx_g    |= final_way_g[i];
            end

            //------------------------------------------------------
            // Group B: Hit Data Selection (for normal access or tlbp)
            // Data Source: final_way_*
            // Selection Source: final_way_sel (One-Hot signal from Hit Logic)
            //------------------------------------------------------
            if(final_way_sel[i]) begin
                final_hit_ppn  |= final_way_ppn[i];
                final_hit_flg  |= final_way_flg[i];
                final_hit_pgs  |= final_way_pgs[i];
            end
        end
    end

    //==========================================================
    //               3. Instantiate Miss Buffer
    //==========================================================
    logic [L2EID_WIDTH-1:0] l2mb_feedback_eid;

    assign mb_alloc_en = l2tlb_miss; 

    assign l2mb_feedback_eid = ptw_l2tlb_ref_id[L2EID_WIDTH+L1EID_WIDTH-1:L1EID_WIDTH];

    mmu_l2tlb_mb#(
        .DTLB_DEPTH     (DTLB_DEPTH),
        .VPN_WIDTH      (VPN_WIDTH),
        .L1EID_WIDTH    (L1EID_WIDTH),
        .PTW_TYPE_WIDTH (3), // PTW usually needs 3 bits (Load/Store/Fetch)
        .QUE_ID_WIDTH   (TRANS_ID_WIDTH),
        .ACC_TYPE_WIDTH (TYPE_WIDTH) // Note: Fixed Typo in parameter name if possible
    ) x_l2tlb_mb (
        // Global
        .cp0_mmu_icg_en     (cp0_mmu_icg_en),
        .cpurst_b           (cpurst_b),
        .reqq_clk           (forever_cpuclk),
        .pad_yy_icg_scan_en (pad_yy_icg_scan_en),

        .tlboper_ptw_abort          (tlboper_ptw_abort),

        // 1. Interface from L2TLB Pipeline (Allocation)
        .req_valid          (mb_alloc_en),     // Valid Miss
        .req_vpn            (final_vpn),       // VPN from pipeline stage
        .req_l1eid          (final_eid),
        //.req_l2_queue_id    (final_trans_id),  // Track ID for Reqq
        .req_acc_type       (final_acc_type),  // Access type
        .req_is_dtlb        (final_is_dtlb),   // DTLB vs ITLB

        .req_alloc_valid    (mb_alloc_valid),

        // 2. Interface to PTW (Issue)
        .issue_req          (mb_issue_req),
        .issue_eid          (mb_issue_eid),    // This carries the TRANS_ID
        .issue_is_dtlb      (mb_issue_is_dtlb),
        .issue_vpn          (mb_issue_vpn),
        .issue_type         (mb_issue_type),
        
        .ptw_ready          (ptw_ready),       // From PTW

        // 3. Feedback from PTW (Refill)
        // When PTW finishes (ptw_l2tlb_ref_cmplt), we match the ID
        // Note: PTW interface in original code doesn't explicitly return ID.
        // Assuming PTW is blocking or we need to match via VPN/Type, 
        // BUT ideally PTW returns the ID we sent it.
        // Let's assume ptw_l2tlb_ref_cmplt implies the current outstanding req is done
        // or we need to add ID tracking to PTW interface.
        
        // *CRITICAL*: For Miss Buffer to clear, it needs to know WHICH ID finished.
        // If PTW doesn't return ID, we must assume In-Order or blocking.
        // Here assuming simple feedback:
        .fb_valid           (ptw_l2tlb_ref_cmplt),
        .fb_trans_id        (l2mb_feedback_eid),    // Loopback or from PTW if supported
        .fb_hit             (ptw_l2tlb_ref_cmplt)             // same as ptw complete
    );


    // Connect MB Outputs to Top-Level PTW Interface
    assign l2tlb_ptw_req  = mb_issue_req & cp0_mmu_ptw_en;
    assign l2tlb_ptw_vpn  = mb_issue_vpn;
    // Pad 2-bit type to 3-bit if necessary (e.g. {1'b0, type}) or direct map
    // Assuming mb_issue_type is already 3 bits based on MB param logic inside MB,
    // but here wire is TYPE_WIDTH (2). Let's pad it to be safe for 3-bit output.
    assign l2tlb_ptw_type = mb_issue_type;//////////////////////////////// 
    assign l2tlb_ptw_id   = mb_issue_eid;

    assign final_pa_vld  = final_tlb_hit & final_vld;

    assign l2tlb_reqq_fb_vld        = final_pa_vld | l2tlb_miss;
    assign l2tlb_reqq_fb_id         = final_queue_id;
    assign l2tlb_reqq_fb_hit        = final_pa_vld;
    
    // A miss that cannot allocate an L2 miss-buffer entry must retry.  Without
    // this feedback, the reqq entry stays valid+sent forever.
    assign l2tlb_reqq_fb_miss_alloc = l2tlb_miss & mb_alloc_valid;////////////////////////////////////add logic mb response to reqq
    assign l2tlb_reqq_fb_miss_retry = l2tlb_miss & !mb_alloc_valid;

  
    assign ptw_req = (final_acc_type == 3'b000) & final_vld;
    assign l2tlb_arb_ptw_cmplt = arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b101) & arb_l2tlb_write;

    mmu_l2tlb_replacement_policy#(
    .WAY_NUM      (WAY_NUM),
    .RRPV_WIDTH   (RRPV_WIDTH)
    ) x_replacement_policy(
    .clk	  (forever_cpuclk),
    .rst_n	  (cpurst_b), 
	
   // Control signals 
    .access_vld         (raw_vld), 
    .mask_way           (raw_way_mask),
    .hit	            (final_pa_vld),
    .miss	            (l2tlb_miss),
    .ptw_req	        (ptw_req),//ptw_alloc
    .hit_index          (final_way_sel),//final way hit(one hot),waiting modify internal logic

   // Status signals 	
    .entry_vld              (raw_way_vld),
    .entry_rrpv             (l2tlb_rrpv_dout_bus),////need modify port in replacement policy module 

   // Outputs
    .push_req               (push_req), 	
    .victim_way_out         (victim_way),
    .rrpv_updata            (rrpv_updata)
);



    assign wbuf_pop_grant = ~arb_l2tlb_req;

    mmu_l2tlb_rrpv_wbuf#(
    .WAY_NUM     (WAY_NUM),
    .IDX_WIDTH   (IDX_WIDTH),   // 256 sets -> 8 bits
    .RRPV_WIDTH  (RRPV_WIDTH),
    .DEPTH       (8)    // Depth of Write Buffer
    ) x_rrpv_wbuf(
            .clk        (forever_cpuclk),
            .rst_n      (cpurst_b),

         .push_req(push_req),
         .push_idx(final_bank_index), //cam write buffer entry,merge same index data
         .push_data(rrpv_updata),

         .full(wbuf_full),      

    //-------------------------------------------------------------------------
    // 2. Pop Interface (To SRAM Arbiter)
    //-------------------------------------------------------------------------
    // Arbiter grants permission to write to SRAM (Buffer Drain)
         .pop_grant(wbuf_pop_grant), 
    
    // Indicates buffer has data pending
         .empty(wbuf_empty),     
    // Data at the Head of the buffer (to be written to SRAM)
         .sram_idx(rrpv_sram_idx),
         .sram_data(rrpv_sram_wdata),

    //-------------------------------------------------------------------------
    // 3. Bypass Interface (Lookup Stage)
    //-------------------------------------------------------------------------
    // Current Lookup Indices from Hash Logic
        .lookup_idx(way_index),/////???????????????wait modify port in module wbuf
        .lookup_req(arb_l2tlb_req),
    
    // Stale Data read from SRAM (potentially outdated)
    //.rrpv_sram_rdata,
    
    // Final RRPV Data (Merged: SRAM Read + Pending Buffer Updates)
    .bypassed_rrpv_rdata(bypassed_rrpv_rdata),
    .lookup_hit(wbuf_cam_hit)
);

    //assign final_hit_ppn[PPN_WIDTH-1:0] = {PPN_WIDTH{final_way_sel[0]}} & final_way_ppn[0][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[1]}} & final_way_ppn[1][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[2]}} & final_way_ppn[2][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[3]}} & final_way_ppn[3][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[4]}} & final_way_ppn[4][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[5]}} & final_way_ppn[5][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[6]}} & final_way_ppn[6][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[7]}} & final_way_ppn[7][PPN_WIDTH-1:0];
    //                                      
    //                                  
    //assign final_hit_flg[FLG_WIDTH-1:0] = {PPN_WIDTH{final_way_sel[0]}} & final_way_flg[0][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[1]}} & final_way_flg[1][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[2]}} & final_way_flg[2][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[3]}} & final_way_flg[3][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[4]}} & final_way_flg[4][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[5]}} & final_way_flg[5][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[6]}} & final_way_flg[6][PPN_WIDTH-1:0]
    //                                    | {PPN_WIDTH{final_way_sel[7]}} & final_way_flg[7][PPN_WIDTH-1:0];
    //                                  
//----------------------------------------------------------
//                  Response to l2tlb request queue 
//----------------------------------------------------------
                                      
    //assign l2tlb_reqq_fb_vld  = final_pa_vld | l2tlb_reqq_fb_miss_alloc;
    //assign l2tlb_reqq_fb_id   = final_queue_id;////////////////////////////////////////
    //assign l2tlb_reqq_fb_hit  = final_pa_vld;
    //assign l2tlb_reqq_fb_miss_alloc =  ;


//----------------------------------------------------------
//                  Req to PTW 
//----------------------------------------------------------
    //assign l2tlb_ptw_req = final_vld & cp0_mmu_ptw_en & l2tlb_miss 
    //                   & {final_acc_type[1] || final_acc_type[2]};
    //assign l2tlb_ptw_vpn[VPN_WIDTH-1:0] = final_vpn[VPN_WIDTH-1:0];
    //assign l2tlb_ptw_type[2:0] = final_acc_type[2:0];
                                          
    
//----------------------------------------------------------
//                  Result to uTLB
//----------------------------------------------------------
    assign ptw_l2tlb_dmiss  = (ptw_l2tlb_ref_type[2:0] == 3'b010 | ptw_l2tlb_ref_type[2:0] == 3'b110);
    assign ptw_l2tlb_imiss  = ptw_l2tlb_ref_type[2:0] == 3'b011;
    assign ptw_l2tlb_pmiss  = ptw_l2tlb_ref_type[2:0] == 3'b100;




    assign final_l1tlb_cmplt        = final_vld & !final_par_fail
                                    & (!cp0_mmu_ptw_en //&& read_cur_1g
                                    | !final_tlb_miss);

    assign l2tlb_l1dtlb_ref_eid     = final_eid;

    assign l2tlb_l1itlb_ref_cmplt    = final_l1tlb_cmplt     
				     & (final_acc_type[2:0] == 3'b011);//wait add
                                    //| ptw_l2tlb_ref_cmplt  
                                    //      &   ptw_l2tlb_imiss; 
    
    assign l2tlb_l1itlb_ref_pavld = final_pa_vld
				    & (final_acc_type[2:0] == 3'b011);
                                 //| ptw_l2tlb_ref_data_vld
                                  //    & ptw_l2tlb_imiss;
    
    //assign l2tlb_l1itlb_acc_err   = ptw_l2tlb_ref_acc_err
    //                                   & ptw_l2tlb_imiss;
    
    assign l2tlb_l1itlb_pgflt     = //ptw_l2tlb_ref_pgflt
                                    //   & ptw_l2tlb_imiss
                                    final_vld & final_tlb_hit_mult
                                       & (final_acc_type[2:0] == 3'b011)
                                  | final_vld & !cp0_mmu_ptw_en & l2tlb_miss
                                       & (final_acc_type[2:0] == 3'b011);
    
    
    assign l2tlb_l1dtlb_ref_cmplt = final_l1tlb_cmplt 
				    & (final_acc_type[1:0] == 2'b10);
                                  //| ptw_l2tlb_ref_cmplt
                                  //     & ptw_l2tlb_dmiss;
    
    assign l2tlb_l1dtlb_ref_pavld = final_pa_vld
				    & (final_acc_type[1:0] == 2'b10);
                                  //| ptw_l2tlb_ref_data_vld
                                  //     & ptw_l2tlb_dmiss;
    
    assign l2tlb_l1dtlb_pgflt     = //ptw_l2tlb_ref_pgflt
                                    //   & ptw_l2tlb_dmiss
                                    final_vld & final_tlb_hit_mult 
                                       & (final_acc_type[1:0] == 2'b10)
                                  | final_vld & !cp0_mmu_ptw_en & l2tlb_miss
                                       & (final_acc_type[1:0] == 2'b10);
    
    //assign l2tlb_l1dtlb_acc_err   = ptw_l2tlb_ref_acc_err
    //                             & ptw_l2tlb_dmiss;



    // result to arb
    //assign l2tlb_arb_pfu_cmplt = (pfu_ok_st || pfu_deny_st) && !pfu_off_chk;
    assign l2tlb_arb_pfu_vpn[VPN_WIDTH-1:0] = lsu_mmu_va2[VPN_WIDTH-1:0];
    
    // addr to pmp
    assign mmu_pmp_pa4[PPN_WIDTH-1:0] = pfu_pa_buf[PPN_WIDTH-1:0];
    
    // addr to sysmap
    assign mmu_sysmap_pa4[PPN_WIDTH-1:0] = lsu_mmu_va2[PPN_WIDTH-1:0];
    
    // pmp result
    assign cp0_priv_mode[1:0] = cp0_mmu_mprv ? cp0_mmu_mpp[1:0]
                                             : cp0_yy_priv_mode[1:0];
    assign cp0_user_mode = cp0_priv_mode[1:0] == 2'b00;
    assign cp0_supv_mode = cp0_priv_mode[1:0] == 2'b01;
    assign cp0_mach_mode = cp0_priv_mode[1:0] == 2'b11;
    
    // &Force("bus", "pmp_mmu_flg4", 3, 0); @1040
    assign l2tlb_pfu_deny = !pmp_mmu_flg4[0]
                         && !(cp0_mach_mode && !pmp_mmu_flg4[3]);  // L-bit for M-Mode
    
    // result to lsu pfu
    assign mmu_lsu_pa2_vld    = pfu_ok_st || pfu_deny_st;
    assign mmu_lsu_pa2_err    = pfu_deny_st;
    assign mmu_lsu_pa2[PPN_WIDTH-1:0] = pfu_pa_buf[PPN_WIDTH-1:0];
    assign mmu_lsu_sec2   = pfu_sec_buf;
    assign mmu_lsu_share2 = pfu_share_buf;
    
    //vpn & ppn & flag
    
    assign ref_vpn[VPN_WIDTH-1:0] = final_vpn[VPN_WIDTH-1:0];

    assign ref_pgs[PGS_WIDTH-1:0] = final_hit_pgs[PGS_WIDTH-1:0];

    assign ref_ppn[PPN_WIDTH-1:0] = final_hit_ppn[PPN_WIDTH-1:0];

    assign ref_flg[FLG_WIDTH-1:0] = final_hit_flg[FLG_WIDTH-1:0];



    //assign ref_vpn[VPN_WIDTH-1:0] = ptw_l2tlb_ref_cmplt ? ptw_arb_vpn[VPN_WIDTH-1:0]
    //                                          : final_vpn[VPN_WIDTH-1:0];
    //assign ref_pgs[PGS_WIDTH-1:0] = ptw_l2tlb_ref_cmplt ? ptw_l2tlb_ref_pgs[PGS_WIDTH-1:0]
    //                                          : l2tlb_cur_pgs[PGS_WIDTH-1:0];
    //assign ref_ppn[PPN_WIDTH-1:0] = ptw_l2tlb_ref_cmplt ? ptw_l2tlb_ref_ppn[PPN_WIDTH-1:0]
    //                                          : final_hit_ppn[PPN_WIDTH-1:0];
    //assign ref_flg[FLG_WIDTH-1:0] = ptw_l2tlb_ref_cmplt ? ptw_l2tlb_ref_flg[FLG_WIDTH-1:0]
    //                                               : final_hit_flg[FLG_WIDTH-1:0];
    
    assign l2tlb_l1tlb_ref_vpn[VPN_WIDTH-1:0] = ref_vpn[VPN_WIDTH-1:0]; 
    assign l2tlb_l1tlb_ref_pgs[PGS_WIDTH-1:0] = ref_pgs[PGS_WIDTH-1:0]; 
    
    assign l2tlb_l1tlb_ref_ppn[PPN_WIDTH-1:0] = ref_ppn[PPN_WIDTH-1:0];
    assign l2tlb_l1tlb_ref_flg[FLG_WIDTH-1:0] = ref_flg[FLG_WIDTH-1:0];
    
    //assign l2tlb_top_cur_st[1:0] = read_cur_st[1:0];
    
    assign l2tlb_top_utlb_pavld = final_pa_vld || ptw_l2tlb_ref_data_vld;


//----------------------------------------------------------
//                  Result to TLB oper
//----------------------------------------------------------
    //==========================================================
    // Variable Definition for Hit Index
    //==========================================================
    // Calculate required bits: e.g., 4 ways -> 2 bits, 8 ways -> 3 bits
    localparam HIT_IDX_WIDTH = $clog2(WAY_NUM); 
    logic [HIT_IDX_WIDTH-1:0] final_hit_idx;
    logic [IDX_WIDTH-1:0]     final_hit_set_idx;

    //==========================================================
    // Hit Index Encoding Logic
    //==========================================================
    always_comb begin
        // 1. Initialize to 0
        final_hit_idx = {HIT_IDX_WIDTH{1'b0}};
        final_hit_set_idx = {IDX_WIDTH{1'b0}};

        // 2. Iterate to find which way hit
        for(int i = 0; i < WAY_NUM; i++) begin
            // If this way is selected/hit (final_way_sel is one-hot)
            if(final_way_hit[i]) begin 
                // OR the current index 'i' into the result
                final_hit_idx |= i[HIT_IDX_WIDTH-1:0];
                final_hit_set_idx |= final_bank_index[i];
            end
        end
    end


// cmplt
assign l2tlb_tlboper_cmplt = final_vld && (final_acc_type[2:0] == 3'b001);

// tlb read idle
//assign l2tlb_tlboper_read_idle = read_cur_idle;

// for tlbp
assign l2tlb_regs_hit                 = final_tlb_hit; 
assign l2tlb_regs_hit_mult            = final_tlb_hit_mult;

assign final_vpn_4k[VPN_WIDTH-1:0] =  final_vpn[VPN_WIDTH-1:0];
assign final_vpn_2m[VPN_WIDTH-1:0] = {{VPN_PERLEL*1{1'b0}}, final_vpn[VPN_WIDTH-1:VPN_PERLEL*1]};
assign final_vpn_1g[VPN_WIDTH-1:0] = {{VPN_PERLEL*2{1'b0}}, final_vpn[VPN_WIDTH-1:VPN_PERLEL*2]};
assign final_vpn_masked[VPN_WIDTH-1:0] = {VPN_WIDTH{tlboper_xx_pgs[0]}} & final_vpn_4k[VPN_WIDTH-1:0]
                                    | {VPN_WIDTH{tlboper_xx_pgs[1]}} & final_vpn_2m[VPN_WIDTH-1:0]
                                    | {VPN_WIDTH{tlboper_xx_pgs[2]}} & final_vpn_1g[VPN_WIDTH-1:0];
assign l2tlb_regs_tlbp_hit_index[10:0] = {final_hit_idx[2:0], final_hit_set_idx[7:0]};

// for tlbr
assign l2tlb_tlbr_vpn[VPN_WIDTH-1:0]   = final_idx_vpn[VPN_WIDTH-1:0];
assign l2tlb_tlbr_pgs[PGS_WIDTH-1:0]   = final_idx_pgs[PGS_WIDTH-1:0];
assign l2tlb_tlbr_asid[ASID_WIDTH-1:0] = final_idx_asid[ASID_WIDTH-1:0];
assign l2tlb_tlbr_ppn[PPN_WIDTH-1:0]   = final_hit_ppn[PPN_WIDTH-1:0];
assign l2tlb_tlbr_flg[FLG_WIDTH-1:0]   = final_hit_flg[FLG_WIDTH-1:0];
assign l2tlb_tlbr_g                    = final_idx_g;

//for inv asid
assign l2tlb_tlboper_asid_hit = |final_way_asid_hit[WAY_NUM-1:0];
// wen sel for tlbwr and invva
//assign l2tlb_tlboper_fifo[3:0] = tc_l2tlb_fifo[3:0]; //rrip ,not fifo
assign l2tlb_tlboper_sel[WAY_NUM-1:0] = tlboper_l2tlb_tlbwr_on ? victim_way
                                      : tlboper_l2tlb_invasid_on ? final_way_asid_hit
                                                                 : final_way_hit;
assign l2tlb_tlboper_va_hit = |final_way_hit;


//==========================================================
//                  Read FSM
//==========================================================
parameter PFU_IDLE = 2'b00,
          PFU_CHK  = 2'b01,
          PFU_DENY = 2'b10,
          PFU_OK   = 2'b11;

always_ff@(posedge l2tlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    pfu_cur_st[1:0] <= PFU_IDLE;
  else
    pfu_cur_st[1:0] <= pfu_nxt_st[1:0];
end 

// &CombBeg; @918
always_comb
begin
case (pfu_cur_st[1:0])
  PFU_IDLE:
  begin
    if(l2tlb_pfu_cmplt)
      if(l2tlb_pfu_acc_fault)
        pfu_nxt_st[1:0] = PFU_DENY;
      else
        pfu_nxt_st[1:0] = PFU_CHK;
    else
      pfu_nxt_st[1:0] = PFU_IDLE;
  end
  PFU_CHK:
  begin
    if(l2tlb_pfu_deny)
      pfu_nxt_st[1:0] = PFU_DENY;
    else
      pfu_nxt_st[1:0] = PFU_OK;
  end
  PFU_DENY:
  begin
    pfu_nxt_st[1:0] = PFU_IDLE;
  end
  PFU_OK:
  begin
    pfu_nxt_st[1:0] = PFU_IDLE;
  end
  default:
  begin
    pfu_nxt_st[1:0] = PFU_IDLE;
  end
endcase
// &CombEnd; @950
end

always_ff@(posedge l2tlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    pfu_off_chk <= 1'b0;
  else if(lsu_mmu_va2_vld && l1dtlb_xx_mmu_off && pfu_idle_st)//(arb_top_cur_st[1:0] == 2'b0) && pfu_idle_st)
    pfu_off_chk <= 1'b1;
  else if(pfu_ok_st || pfu_deny_st)
    pfu_off_chk <= 1'b0;
end 

assign pfu_idle_st = pfu_cur_st[1:0] == PFU_IDLE;
assign pfu_deny_st = pfu_cur_st[1:0] == PFU_DENY;
assign pfu_ok_st   = pfu_cur_st[1:0] == PFU_OK;

assign l2tlb_pfu_cmplt     = final_vld && (final_tlb_hit
                                    || final_tlb_hit_mult 
                                    || !cp0_mmu_ptw_en && l2tlb_miss)
                                 && (final_acc_type[2:0] == 3'b100)
                           || ptw_l2tlb_ref_cmplt && ptw_l2tlb_pmiss
                           || lsu_mmu_va2_vld && l1dtlb_xx_mmu_off ;//&& (arb_top_cur_st[1:0] == 2'b0);

assign l2tlb_pfu_flag_fault =  !final_hit_flg[0]
                           || !final_hit_flg[1] && final_hit_flg[2]
                           || !final_hit_flg[1] && !(cp0_mmu_mxr && final_hit_flg[3])
                           ||  final_hit_flg[4] && cp0_supv_mode && !cp0_mmu_sum
                           || !final_hit_flg[4] && cp0_user_mode
                           || !final_hit_flg[5]
                           || (cp0_mmu_maee ? (final_hit_flg[13] || !final_hit_flg[12])
                                            : (sysmap_mmu_flg4[4] || !sysmap_mmu_flg4[3]));

assign l2tlb_pfu_acc_fault = final_vld && (final_tlb_hit_mult 
                                       || !cp0_mmu_ptw_en && l2tlb_miss)
                                 && (final_acc_type[2:0] == 3'b100)
                           || final_pa_vld && (final_acc_type[2:0] == 3'b100)
                              && l2tlb_pfu_flag_fault
                           || lsu_mmu_va2_vld && l1dtlb_xx_mmu_off //&& (arb_top_cur_st[1:0] == 2'b0)
                              && (sysmap_mmu_flg4[4] || !sysmap_mmu_flg4[3])
                           || ptw_l2tlb_ref_cmplt && ptw_l2tlb_pmiss
                              && (ptw_l2tlb_ref_flg[13] || !ptw_l2tlb_ref_flg[12] 
                                 || ptw_l2tlb_ref_pgflt || ptw_l2tlb_ref_acc_err);


// &Force("bus", "sysmap_mmu_flg4", 4, 0); @994
assign pa_offset[VPN_WIDTH-1:0]   = lsu_mmu_va2[VPN_WIDTH-1:0];
assign ptw_pa2[PPN_WIDTH-1:0]     = 
     {PPN_WIDTH{ref_pgs[2]}} & {ref_ppn[PPN_WIDTH-1:VPN_PERLEL*2], pa_offset[VPN_PERLEL*2-1:0]}
   | {PPN_WIDTH{ref_pgs[1]}} & {ref_ppn[PPN_WIDTH-1:VPN_PERLEL*1], pa_offset[VPN_PERLEL*1-1:0]}
   | {PPN_WIDTH{ref_pgs[0]}} &  ref_ppn[PPN_WIDTH-1:0];

assign l2tlb_pfu_pa[PPN_WIDTH-1:0] = l1dtlb_xx_mmu_off ? lsu_mmu_va2[PPN_WIDTH-1:0] 
                                                      : ptw_pa2[PPN_WIDTH-1:0];
assign l2tlb_pfu_sec               = (l1dtlb_xx_mmu_off || !cp0_mmu_maee) ? sysmap_mmu_flg4[0] : ref_flg[9];
assign l2tlb_pfu_share             = (l1dtlb_xx_mmu_off || !cp0_mmu_maee) ? sysmap_mmu_flg4[1] : ref_flg[10];

// synopsys translate_off
logic mmu_itlb_dbg_en;

initial begin
  mmu_itlb_dbg_en = $test$plusargs("MMU_ITLB_DBG");
end

always_ff @(posedge l2tlb_clk or negedge cpurst_b) begin
  if (!cpurst_b) begin
  end else if (mmu_itlb_dbg_en
               && (queue_arb_req
                   || arb_l2tlb_req
                   || final_vld
                   || l2tlb_miss
                   || mb_alloc_valid
                   || l2tlb_reqq_fb_vld
                   || l2tlb_ptw_req
                   || ptw_l2tlb_ref_cmplt
                   || l2tlb_l1itlb_ref_cmplt
                   || l2tlb_l1itlb_ref_pavld
                   || l2tlb_l1itlb_pgflt)) begin
    $display("[MMU_ITLB_DBG][L2TLB] t=%0t queue_req=%0b q_vpn=0x%07h q_type=0x%0h q_id=0x%0h arb_req=%0b arb_type=0x%0h arb_tid=0x%0h final_vld=%0b final_type=0x%0h final_qid=0x%0h final_vpn=0x%07h hit=%0b hit_mult=%0b miss=%0b mb_alloc=%0b fb_vld=%0b fb_id=0x%0h fb_hit=%0b fb_alloc=%0b fb_retry=%0b ptw_req=%0b ptw_type=0x%0h ptw_id=0x%02h ptw_vpn=0x%07h ptw_cmplt=%0b ptw_ref_type=0x%0h ptw_ref_id=0x%02h ptw_data=%0b ptw_pgflt=%0b ptw_acc=%0b l1i_cmplt=%0b l1i_pavld=%0b l1i_pgflt=%0b",
             $time,
             queue_arb_req,
             queue_arb_vpn,
             queue_arb_acc_type,
             queue_arb_trans_id,
             arb_l2tlb_req,
             arb_l2tlb_acc_type,
             arb_l2tlb_trans_id,
             final_vld,
             final_acc_type,
             final_queue_id,
             final_vpn,
             final_pa_vld,
             final_tlb_hit_mult,
             l2tlb_miss,
             mb_alloc_valid,
             l2tlb_reqq_fb_vld,
             l2tlb_reqq_fb_id,
             l2tlb_reqq_fb_hit,
             l2tlb_reqq_fb_miss_alloc,
             l2tlb_reqq_fb_miss_retry,
             l2tlb_ptw_req,
             l2tlb_ptw_type,
             l2tlb_ptw_id,
             l2tlb_ptw_vpn,
             ptw_l2tlb_ref_cmplt,
             ptw_l2tlb_ref_type,
             ptw_l2tlb_ref_id,
             ptw_l2tlb_ref_data_vld,
             ptw_l2tlb_ref_pgflt,
             ptw_l2tlb_ref_acc_err,
             l2tlb_l1itlb_ref_cmplt,
             l2tlb_l1itlb_ref_pavld,
             l2tlb_l1itlb_pgflt);
  end
end
// synopsys translate_on

// flop pa for pmp check
always @(posedge l2tlb_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
  begin
    pfu_pa_buf[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
    pfu_sec_buf               <= 1'b0;
    pfu_share_buf             <= 1'b0;
  end
  else if(pfu_idle_st && l2tlb_pfu_cmplt)
  begin
    pfu_pa_buf[PPN_WIDTH-1:0] <= l2tlb_pfu_pa[PPN_WIDTH-1:0];
    pfu_sec_buf               <= l2tlb_pfu_sec;
    pfu_share_buf             <= l2tlb_pfu_share;
  end
end




















endmodule
