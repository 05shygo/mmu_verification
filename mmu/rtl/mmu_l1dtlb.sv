//!********************************************************************
//!  OpenRiscv2030  
//!
//!    L1DTLB Top Module with Miss Buffer
//!    Integrates all sub-modules: Hit Path, MB, Allocator, Scheduler
//!********************************************************************

module mmu_l1dtlb #(
    parameter MB_DEPTH   = 8,
    parameter VPN_WIDTH  = 27,
    parameter PPN_WIDTH  = 28,
    parameter IID_WIDTH  = 7,
    parameter FLG_WIDTH  = 14,
    parameter CREDIT_WIDTH = 3,
    parameter CREDIT_MAX =8,
    parameter ACC_TYPE_WIDTH = 3,
    parameter NUM_ENTRY  = 16
)(
    // Clock and Reset
    input  logic         cpurst_b,
    input  logic         forever_cpuclk,
    input  logic         utlb_clk,
    input  logic         pad_yy_icg_scan_en,
    
    // SysReg
    input  logic         cp0_mmu_icg_en,
    input  logic [1:0]   cp0_mmu_mpp,
    input  logic         cp0_mmu_mprv,
    input  logic         cp0_mmu_mxr,
    input  logic         cp0_mmu_sum,
    input  logic [1:0]   cp0_yy_priv_mode,
    input  logic         regs_mmu_en,
    input  logic         regs_utlb_clr,
    input  logic         hpcp_mmu_cnt_en,
    
    // LSU Interface - Port 0
    input  logic         lsu_mmu_va0_vld,
    input  logic [63:0]  lsu_mmu_va0,
    input  logic [6:0]   lsu_mmu_id0,
    input  logic         lsu_mmu_st_inst0,
    input  logic [27:0]  lsu_mmu_vabuf0,
    input  logic         lsu_mmu_abort0,
    
    output logic         mmu_lsu_pa0_vld,
    output logic [27:0]  mmu_lsu_pa0,
    output logic         mmu_lsu_buf0,
    output logic         mmu_lsu_ca0,
    output logic         mmu_lsu_sh0,
    output logic         mmu_lsu_so0,
    output logic         mmu_lsu_access_fault0,
    output logic         mmu_lsu_page_fault0,
    output logic         mmu_lsu_sec0,
    output logic         mmu_lsu_stall0,
    
    // LSU Interface - Port 1
    input  logic         lsu_mmu_va1_vld,
    input  logic [63:0]  lsu_mmu_va1,
    input  logic [6:0]   lsu_mmu_id1,
    input  logic         lsu_mmu_st_inst1,
    input  logic [27:0]  lsu_mmu_vabuf1,
    input  logic         lsu_mmu_abort1,
    
    output logic         mmu_lsu_pa1_vld,
    output logic [27:0]  mmu_lsu_pa1,
    output logic         mmu_lsu_buf1,
    output logic         mmu_lsu_ca1,
    output logic         mmu_lsu_sh1,
    output logic         mmu_lsu_so1,
    output logic         mmu_lsu_access_fault1,
    output logic         mmu_lsu_page_fault1,
    output logic         mmu_lsu_sec1,
    output logic         mmu_lsu_stall1,
    
    // STAMO
    input  logic         lsu_mmu_stamo_vld,
    input  logic [27:0]  lsu_mmu_stamo_pa,
    
    output logic         mmu_hpcp_dutlb_miss,
    output logic         mmu_lsu_tlb_busy,
    output logic [11:0]  mmu_lsu_tlb_wakeup,
    
    // PMP
    output logic [27:0]  mmu_pmp_pa0,
    output logic [27:0]  mmu_pmp_pa1,
    input  logic [3:0]   pmp_mmu_flg0,
    input  logic [3:0]   pmp_mmu_flg1,
    
    // SystemMap
    input  logic [4:0]   sysmap_mmu_flg0,
    input  logic [4:0]   sysmap_mmu_flg1,
    output logic [27:0]  mmu_sysmap_pa0,
    output logic [27:0]  mmu_sysmap_pa1,
    
    // Flush/Invalidation
    input  logic         rtu_yy_xx_flush,
    input  logic         tlboper_utlb_clr,
    input  logic         tlboper_utlb_inv_va_req,
    input  logic [26:0]  lsu_mmu_tlb_va,

    //ptw refill to l1dtlb
    //input  logic [ACC_TYPE_WIDTH-1:0]	 ptw_refill_acc_type,

    input  logic         ptw_l1dtlb_ref_pavld,
    input  logic         ptw_l1dtlb_ref_cmplt,
    input  logic [2:0]   ptw_l1dtlb_ref_id,
    input  logic [26:0]  ptw_l1tlb_ref_vpn,
    input  logic [27:0]  ptw_l1tlb_ref_ppn,
    input  logic         ptw_l1tlb_acc_err,
    input  logic         ptw_l1tlb_pgflt,
    input  logic [13:0]  ptw_l1tlb_ref_flg,
    input  logic [2:0]   ptw_l1tlb_ref_pgs,
    
    // L2TLB (JTLB) Interface
    input  logic 	 credit_return,
    
    // L2TLB  Request Interface (Credit-Based Flow Control)
    // Replaces the old ARB interface
    output logic         dutlb_l2tlb_req_vld,    // Request Valid to L2TLB ReqQ
    output logic [26:0]  dutlb_l2tlb_req_vpn,    // VPN to be translated
    output logic [2:0]   dutlb_l2tlb_req_eid,    // L1TLB Miss Buffer Entry ID (Transaction ID)    
    output logic	 dutlb_l2tlb_req_is_load,

    //output logic         dutlb_arb_req,
    //output logic [26:0]  dutlb_arb_vpn,
    //output logic         dutlb_arb_load,
    //output logic [2:0]   dutlb_arb_id,
    //output logic         dutlb_arb_cmplt,
    
    //input  logic         arb_dutlb_grant,
    input  logic         biu_mmu_smp_disable,
    
    output logic         dutlb_ptw_wfc,
    output logic [2:0]   dutlb_top_ref_cur_st,
    output logic         dutlb_top_ref_type,
    output logic         dutlb_top_scd_updt,
    output logic         dutlb_xx_mmu_off,
    
    input  logic         jtlb_dutlb_ref_pavld,
    input  logic         jtlb_dutlb_ref_cmplt,
    input  logic [2:0]   jtlb_dutlb_ref_id,
    input  logic [26:0]  jtlb_utlb_ref_vpn,
    input  logic [27:0]  jtlb_utlb_ref_ppn,
    //input  logic         jtlb_dutlb_acc_err,
    input  logic         jtlb_dutlb_pgflt,
    input  logic [13:0]  jtlb_utlb_ref_flg,
    input  logic [2:0]   jtlb_utlb_ref_pgs
);

localparam EID_WIDTH = $clog2(MB_DEPTH);
localparam PGS_WIDTH = 3;
localparam LVL_WIDTH = 9;
localparam MB_STATE_WFC = 3'b010;
//!************************************************
//! Clock Generation
//!************************************************
logic mb_clk, mb_clk_en;
logic sched_clk, sched_clk_en;
logic dplru_clk, dplru_clk_en;
logic dutlb_clk, dutlb_clk_en;

logic cp0_mach_mode, cp0_supv_mode, cp0_user_mode;
logic [1:0] cp0_priv_mode;

// Privilege mode decode
assign cp0_priv_mode = cp0_mmu_mprv ? cp0_mmu_mpp : cp0_yy_priv_mode;
assign cp0_mach_mode = (cp0_priv_mode == 2'b11);
assign cp0_supv_mode = (cp0_priv_mode == 2'b01);
assign cp0_user_mode = (cp0_priv_mode == 2'b00);

assign dutlb_xx_mmu_off = !regs_mmu_en || cp0_mach_mode;

// Clock gating
assign mb_clk_en = 1'b1;  // TODO: optimize
assign sched_clk_en = 1'b1;
assign dplru_clk_en = 1'b1;
assign dutlb_clk_en = 1'b1;

gated_clk_cell x_mb_gateclk (
    .clk_in(forever_cpuclk), .clk_out(mb_clk),
    .external_en(1'b0), .global_en(1'b1),
    .local_en(mb_clk_en), .module_en(cp0_mmu_icg_en),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en)
);

gated_clk_cell x_sched_gateclk (
    .clk_in(forever_cpuclk), .clk_out(sched_clk),
    .external_en(1'b0), .global_en(1'b1),
    .local_en(sched_clk_en), .module_en(cp0_mmu_icg_en),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en)
);

gated_clk_cell x_dplru_gateclk (
    .clk_in(forever_cpuclk), .clk_out(dplru_clk),
    .external_en(1'b0), .global_en(1'b1),
    .local_en(dplru_clk_en), .module_en(cp0_mmu_icg_en),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en)
);

gated_clk_cell x_dutlb_gateclk (
    .clk_in(forever_cpuclk), .clk_out(dutlb_clk),
    .external_en(1'b0), .global_en(1'b1),
    .local_en(dutlb_clk_en), .module_en(cp0_mmu_icg_en),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en)
);

//!************************************************
//! TLB Entry Signals (16+1 entries)
//!************************************************
logic [NUM_ENTRY-1:0]               entry_vld;
logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;
logic [NUM_ENTRY-1:0]               entry_hit0, entry_hit1;
logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;
logic [NUM_ENTRY-1:0][PGS_WIDTH-1:0] l1dtlb_ent_pgs;
//! TLB Refill/Install Signals
logic                    utlb_refill_vld;
logic [3:0]              utlb_refill_idx;
logic [VPN_WIDTH-1:0]    utlb_refill_vpn;
logic [PPN_WIDTH-1:0]    utlb_refill_ppn;
logic [FLG_WIDTH-1:0]    utlb_refill_flg;
logic [2:0]		 utlb_refill_pgs;

//! PLRU Signals (placeholder for now)
logic [15:0]             plru_bank0_refill_way;
logic [15:0]             plru_bank1_refill_way;
logic                    plru_refill_updt;
logic [15:0]             plru_refill_way;

//assign plru_bank0_refill_way = 16'h0001;  // Simple replacement: always use entry 0
//assign plru_bank1_refill_way = 16'h0001;


//!************************************************
//! Miss Buffer Entry Array
//!************************************************
logic [MB_DEPTH-1:0]                   mb_entry_vld;
logic [MB_DEPTH-1:0][2:0]              mb_entry_state;
logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;
logic [MB_DEPTH-1:0][IID_WIDTH-1:0]    mb_entry_iid;
logic [MB_DEPTH-1:0][PGS_WIDTH-1:0]    mb_entry_pgs;
//logic [MB_DEPTH-1:0]                   mb_entry_port_id;
logic [MB_DEPTH-1:0]                   mb_entry_issued;
logic [MB_DEPTH-1:0]                   mb_entry_ready;
logic [MB_DEPTH-1:0]                   mb_entry_wfc;
logic [MB_DEPTH-1:0]                   mb_entry_fault;

logic [MB_DEPTH-1:0]                   mb_alloc_we;
logic [MB_DEPTH-1:0]                   mb_issue_sel;
logic                                  mb_issue_grant;

// Allocator outputs
logic alloc_gnt0, alloc_gnt1;
logic [EID_WIDTH-1:0] alloc_sel0, alloc_sel1;

// Scheduler outputs
logic                  issue_req;
logic [VPN_WIDTH-1:0]  issue_vpn;
logic [EID_WIDTH-1:0]  issue_eid;
logic                  dutlb_l2tlb_req_store;



//!************************************************
//! T0->T1 Miss Staging Registers
//!************************************************
logic miss0_vld_q, miss1_vld_q;
logic [VPN_WIDTH-1:0] miss0_vpn_q, miss1_vpn_q;
logic [IID_WIDTH-1:0] miss0_iid_q, miss1_iid_q;
logic miss0_abort_q, miss1_abort_q;

logic dutlb_miss_vld0, dutlb_miss_vld1;
logic dutlb_inst_id_match0, dutlb_inst_id_match1;
logic dutlb_inst_id_older0, dutlb_inst_id_older1;
logic dutlb_miss_vld_short0, dutlb_miss_vld_short1;
logic [15:0] dutlb_plru_read_hit0, dutlb_plru_read_hit1;
logic dutlb_plru_read_hit_vld0, dutlb_plru_read_hit_vld1;
logic dutlb_va_chg0, dutlb_va_chg1;
logic dutlb_acc_flt0, dutlb_acc_flt1;

logic [VPN_WIDTH-1:0] utlb_req_vpn0, utlb_req_vpn1;

logic dutlb_off_hit;
assign dutlb_off_hit = dutlb_xx_mmu_off;

logic dutlb_ori_read0, dutlb_ori_read1;
logic dutlb_read_type0, dutlb_read_type1;
logic expt_match0, expt_match1;
logic expt_pgflt0, expt_pgflt1;
logic expt_acflt0, expt_acflt1;
logic [MB_DEPTH-1:0] expt_hit_vec;
logic [11:0] expt_wakeup;
logic [11:0] install_wakeup;
logic expt_wr0_vld, expt_wr1_vld;
logic [EID_WIDTH-1:0] expt_wr0_eid, expt_wr1_eid;
logic [IID_WIDTH-1:0] expt_wr0_iid, expt_wr1_iid;
logic [VPN_WIDTH-1:0] expt_wr0_vpn, expt_wr1_vpn;
logic expt_wr0_pgflt, expt_wr1_pgflt;
logic expt_wr0_acflt, expt_wr1_acflt;
logic miss0_is_store;
logic miss1_is_store;
assign dutlb_ori_read0 = !lsu_mmu_st_inst0;
assign dutlb_ori_read1 = !lsu_mmu_st_inst1;
assign dutlb_read_type0 = dutlb_ori_read0;
assign dutlb_read_type1 = dutlb_ori_read1;

assign expt_wr0_vld   = ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err)
                      && mb_entry_vld[ptw_l1dtlb_ref_id]
                      && (mb_entry_state[ptw_l1dtlb_ref_id] == MB_STATE_WFC)
                      && !rtu_yy_xx_flush;
assign expt_wr0_eid   = ptw_l1dtlb_ref_id[EID_WIDTH-1:0];
assign expt_wr0_iid   = mb_entry_iid[ptw_l1dtlb_ref_id];
assign expt_wr0_vpn   = mb_entry_vpn[ptw_l1dtlb_ref_id];
assign expt_wr0_pgflt = ptw_l1tlb_pgflt;
assign expt_wr0_acflt = ptw_l1tlb_acc_err;

assign expt_wr1_vld   = jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt
                      && mb_entry_vld[jtlb_dutlb_ref_id]
                      && (mb_entry_state[jtlb_dutlb_ref_id] == MB_STATE_WFC)
                      && !rtu_yy_xx_flush;
assign expt_wr1_eid   = jtlb_dutlb_ref_id[EID_WIDTH-1:0];
assign expt_wr1_iid   = mb_entry_iid[jtlb_dutlb_ref_id];
assign expt_wr1_vpn   = mb_entry_vpn[jtlb_dutlb_ref_id];
assign expt_wr1_pgflt = jtlb_dutlb_pgflt;
assign expt_wr1_acflt = 1'b0;

`ifndef SYNTHESIS
`ifdef MMU_EXPT_TRACE_ONCE_EN
// One-shot correlation trace:
//   miss -> ptw/jtlb ref_id -> CAM write
always @(posedge mb_clk) begin
  static bit seen_miss[string];
  static bit seen_ref[string];
  static bit seen_cam[string];
  string key;

  if (miss0_vld_q && !miss0_abort_q) begin
    key = $sformatf("M0_iid%0d_vpn%0h", miss0_iid_q, miss0_vpn_q);
    if (!seen_miss.exists(key)) begin
      seen_miss[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][MISS] t=%0t src=p0 iid=%0d vpn=0x%0h store=%0b mb_busy=%0b",
        $time, miss0_iid_q, miss0_vpn_q, miss0_is_store, (|mb_entry_vld));
    end
  end

  if (miss1_vld_q && !miss1_abort_q) begin
    key = $sformatf("M1_iid%0d_vpn%0h", miss1_iid_q, miss1_vpn_q);
    if (!seen_miss.exists(key)) begin
      seen_miss[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][MISS] t=%0t src=p1 iid=%0d vpn=0x%0h store=%0b mb_busy=%0b",
        $time, miss1_iid_q, miss1_vpn_q, miss1_is_store, (|mb_entry_vld));
    end
  end

  if (ptw_l1dtlb_ref_cmplt) begin
    key = $sformatf("R_PTW_ref%0d_iid%0d_vpn%0h", ptw_l1dtlb_ref_id,
                    mb_entry_iid[ptw_l1dtlb_ref_id], mb_entry_vpn[ptw_l1dtlb_ref_id]);
    if (!seen_ref.exists(key)) begin
      seen_ref[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][REF] t=%0t src=ptw ref_id=%0d iid=%0d vpn=0x%0h pgflt=%0b acerr=%0b mb_vld=%0b",
        $time, ptw_l1dtlb_ref_id, mb_entry_iid[ptw_l1dtlb_ref_id], mb_entry_vpn[ptw_l1dtlb_ref_id],
        ptw_l1tlb_pgflt, ptw_l1tlb_acc_err, mb_entry_vld[ptw_l1dtlb_ref_id]);
    end
  end

  if (jtlb_dutlb_ref_cmplt) begin
    key = $sformatf("R_JTLB_ref%0d_iid%0d_vpn%0h", jtlb_dutlb_ref_id,
                    mb_entry_iid[jtlb_dutlb_ref_id], mb_entry_vpn[jtlb_dutlb_ref_id]);
    if (!seen_ref.exists(key)) begin
      seen_ref[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][REF] t=%0t src=jtlb ref_id=%0d iid=%0d vpn=0x%0h pgflt=%0b mb_vld=%0b",
        $time, jtlb_dutlb_ref_id, mb_entry_iid[jtlb_dutlb_ref_id], mb_entry_vpn[jtlb_dutlb_ref_id],
        jtlb_dutlb_pgflt, mb_entry_vld[jtlb_dutlb_ref_id]);
    end
  end

  if (expt_wr0_vld) begin
    key = $sformatf("C0_iid%0d_vpn%0h_pg%0b_ac%0b", expt_wr0_iid, expt_wr0_vpn, expt_wr0_pgflt, expt_wr0_acflt);
    if (!seen_cam.exists(key)) begin
      seen_cam[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][CAM_WRITE] t=%0t src=ptw iid=%0d vpn=0x%0h pgflt=%0b acflt=%0b",
        $time, expt_wr0_iid, expt_wr0_vpn, expt_wr0_pgflt, expt_wr0_acflt);
    end
  end

  if (expt_wr1_vld) begin
    key = $sformatf("C1_iid%0d_vpn%0h_pg%0b_ac%0b", expt_wr1_iid, expt_wr1_vpn, expt_wr1_pgflt, expt_wr1_acflt);
    if (!seen_cam.exists(key)) begin
      seen_cam[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][CAM_WRITE] t=%0t src=jtlb iid=%0d vpn=0x%0h pgflt=%0b acflt=%0b",
        $time, expt_wr1_iid, expt_wr1_vpn, expt_wr1_pgflt, expt_wr1_acflt);
    end
  end
end

`endif
`ifdef MMU_DTLB_DBG_EN
// Debug: trace MMU-off decision chain seen by LSU DTLB path.
always @(posedge dutlb_clk) begin
  if (lsu_mmu_va0_vld || lsu_mmu_va1_vld) begin
    $display("[MMU_DTLB_TOP_DBG] t=%0t va0_vld=%0b va1_vld=%0b regs_mmu_en=%0b cp0_mprv=%0b cp0_mpp=%02b cp0_priv=%02b cp0_mach_mode=%0b cp0_supv_mode=%0b cp0_user_mode=%0b dutlb_xx_mmu_off=%0b",
      $time, lsu_mmu_va0_vld, lsu_mmu_va1_vld,
      regs_mmu_en, cp0_mmu_mprv, cp0_mmu_mpp, cp0_priv_mode,
      cp0_mach_mode, cp0_supv_mode, cp0_user_mode, dutlb_xx_mmu_off);
  end
end
`endif
`endif

mmu_l1dtlb_expt_cam #(
    .CAM_DEPTH (MB_DEPTH),
    .IID_WIDTH (IID_WIDTH),
    .VPN_WIDTH (VPN_WIDTH)
) x_l1dtlb_expt_cam (
    .clk                    (mb_clk),
    .rst_b                  (cpurst_b),
    .rtu_yy_xx_flush        (rtu_yy_xx_flush),
    .tlboper_utlb_clr       (tlboper_utlb_clr),
    .tlboper_utlb_inv_va_req(tlboper_utlb_inv_va_req),

    .expt_wr0_vld           (expt_wr0_vld),
    .expt_wr0_eid           (expt_wr0_eid),
    .expt_wr0_iid           (expt_wr0_iid),
    .expt_wr0_vpn           (expt_wr0_vpn),
    .expt_wr0_pgflt         (expt_wr0_pgflt),
    .expt_wr0_acflt         (expt_wr0_acflt),
    .expt_wr1_vld           (expt_wr1_vld),
    .expt_wr1_eid           (expt_wr1_eid),
    .expt_wr1_iid           (expt_wr1_iid),
    .expt_wr1_vpn           (expt_wr1_vpn),
    .expt_wr1_pgflt         (expt_wr1_pgflt),
    .expt_wr1_acflt         (expt_wr1_acflt),

    .lsu_mmu_va0_vld        (lsu_mmu_va0_vld),
    .lsu_mmu_abort0         (lsu_mmu_abort0),
    .lsu_mmu_id0            (lsu_mmu_id0),
    .lsu_mmu_vpn0           (lsu_mmu_va0[VPN_WIDTH+11:12]),
    .lsu_mmu_va1_vld        (lsu_mmu_va1_vld),
    .lsu_mmu_abort1         (lsu_mmu_abort1),
    .lsu_mmu_id1            (lsu_mmu_id1),
    .lsu_mmu_vpn1           (lsu_mmu_va1[VPN_WIDTH+11:12]),

    .expt_match0            (expt_match0),
    .expt_pgflt0            (expt_pgflt0),
    .expt_acflt0            (expt_acflt0),
    .expt_match1            (expt_match1),
    .expt_pgflt1            (expt_pgflt1),
    .expt_acflt1            (expt_acflt1),
    .expt_hit_vec           (expt_hit_vec)
    //.expt_wakeup            (expt_wakeup)
);

//!************************************************
//! PLRU Instance
//!************************************************

// PLRU determines the victim entry for replacement
ct_mmu_dplru x_dplru (
    .cpurst_b                    (cpurst_b),
    .forever_cpuclk              (forever_cpuclk),
    .cp0_mmu_icg_en              (cp0_mmu_icg_en),
    .pad_yy_icg_scan_en          (pad_yy_icg_scan_en),

    // Entry Valid Bits (Unpacked for legacy PLRU module)
    .entry0_vld                  (entry_vld[0]),
    .entry1_vld                  (entry_vld[1]),
    .entry2_vld                  (entry_vld[2]),
    .entry3_vld                  (entry_vld[3]),
    .entry4_vld                  (entry_vld[4]),
    .entry5_vld                  (entry_vld[5]),
    .entry6_vld                  (entry_vld[6]),
    .entry7_vld                  (entry_vld[7]),
    .entry8_vld                  (entry_vld[8]),
    .entry9_vld                  (entry_vld[9]),
    .entry10_vld                 (entry_vld[10]),
    .entry11_vld                 (entry_vld[11]),
    .entry12_vld                 (entry_vld[12]),
    .entry13_vld                 (entry_vld[13]),
    .entry14_vld                 (entry_vld[14]),
    .entry15_vld                 (entry_vld[15]),

    // Read Hit Updates (Port 0)
    // Update PLRU tree when an entry is hit by LSU lookup
    .utlb_plru_read_hit0         (dutlb_plru_read_hit0), 
    .utlb_plru_read_hit_vld0     (dutlb_plru_read_hit_vld0),  // Valid lookup request

    // Read Hit Updates (Port 1)
    .utlb_plru_read_hit1         (dutlb_plru_read_hit1),
    .utlb_plru_read_hit_vld1     (dutlb_plru_read_hit_vld1),  // Valid lookup request

    // Refill Updates (From Install Module)
    // Update PLRU tree when a new entry is installed (Mark as MRU)
    .utlb_plru_refill_on         (utlb_refill_vld),  // Update enable
    .utlb_plru_refill_vld        (utlb_refill_vld),  // Valid signal

    // Replacement Way Output (To Install Module)
    // Returns One-Hot vector indicating the victim entry
    .plru_dutlb_ref_num          (plru_bank0_refill_way) 
);

// Note: plru_bank1_refill_way is currently unused in 
// this configuration or tied to bank0 if dual-bank is not enabled.
assign plru_bank1_refill_way = plru_bank0_refill_way;

//!************************************************
//! Hit Read Path Instances (Port 0 and Port 1)
//!************************************************

//==============================================================================
//                  Signal Packing for Hit Read Modules
//==============================================================================
// The Hit Read module uses flattened vectors for parameterized ports.
// We need to pack the 2D arrays (entry_flg, entry_ppn) into 1D vectors.

logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;
logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;

genvar k;
generate
    for (k = 0; k < NUM_ENTRY; k++) begin : gen_pack_signals
        assign entry_flg_vec[k*FLG_WIDTH +: FLG_WIDTH] = entry_flg[k];
        assign entry_ppn_vec[k*PPN_WIDTH +: PPN_WIDTH] = entry_ppn[k];
    end
endgenerate

//==============================================================================
//                  Hit Read Instance - Port 0
//==============================================================================

logic l1dtlb_refill_on ;
logic dutlb_req_id0_older;
logic refill_type;
logic dutlb_refill_upd0;
logic dutlb_refill_upd1;
logic dutlb_ref_pgflt;
logic dutlb_ref_acflt;
logic dutlb_expt_for_taken;
logic [IID_WIDTH-1:0] refill_id_flop0;
logic [IID_WIDTH-1:0] refill_id_flop1;
logic [IID_WIDTH-1:0] refill_id_flop;


// Legacy exception-chain signal is kept only for compatibility/debug visibility.
// Exception ownership/replay is now handled by mmu_l1dtlb_expt_cam.
assign dutlb_expt_for_taken = expt_wr0_vld | expt_wr1_vld;

assign l1dtlb_refill_on = |mb_entry_vld;

// &Instance("ct_rtu_compare_iid","x_mmu_dutlb_compare_req_iid"); @243
ct_rtu_compare_iid  x_mmu_dutlb_compare_req_iid (
  .x_iid0              (lsu_mmu_id0[6:0]   ),
  .x_iid0_older        (dutlb_req_id0_older),
  .x_iid1              (lsu_mmu_id1[6:0]   )
);

// &Connect( .x_iid0         (lsu_mmu_id0[6:0]), @244
//           .x_iid1         (lsu_mmu_id1[6:0]), @245
//           .x_iid0_older   (dutlb_req_id0_older)); @246

always @(posedge dutlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    refill_type <= 1'b0;
  else if(dutlb_miss_vld0 && dutlb_refill_upd0 && (dutlb_req_id0_older || !dutlb_miss_vld1))
    refill_type <= 1'b1;
  else if(dutlb_miss_vld1 && dutlb_refill_upd1)
    refill_type <= 1'b0;
end

// ---------------------------------------------------------------------------
// Legacy (pre-CAM) exception handling path intentionally disabled:
//   dutlb_ref_pgflt/ref_acflt global OR + refill_id_flop based ownership
//   is not safe with outstanding misses.
// CAM now owns exception attribution, replay, and consume.
// ---------------------------------------------------------------------------
assign dutlb_ref_pgflt = 1'b0;
assign dutlb_ref_acflt = 1'b0;

// Keep refill_id_flop update as a compatibility/debug-only path.
assign dutlb_refill_upd0  = ~l1dtlb_refill_on;
assign dutlb_refill_upd1  = ~l1dtlb_refill_on;

always @(posedge dutlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    refill_id_flop0[IID_WIDTH-1:0] <= {IID_WIDTH{1'b0}};
  else if(dutlb_miss_vld_short0 && dutlb_refill_upd0)
    refill_id_flop0[IID_WIDTH-1:0] <= lsu_mmu_id0[IID_WIDTH-1:0];
end
always @(posedge dutlb_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    refill_id_flop1[IID_WIDTH-1:0] <= {IID_WIDTH{1'b0}};
  else if(dutlb_miss_vld_short1 && dutlb_refill_upd1)
    refill_id_flop1[IID_WIDTH-1:0] <= lsu_mmu_id1[IID_WIDTH-1:0];
end 
assign refill_id_flop[IID_WIDTH-1:0] = refill_type ? refill_id_flop0[IID_WIDTH-1:0]
                                                   : refill_id_flop1[IID_WIDTH-1:0];

`ifndef SYNTHESIS
`ifdef MMU_DTLB_DBG_EN
// Debug: trace exception chain source and refill-id correlation basis.
always @(posedge dutlb_clk) begin
  if (lsu_mmu_va0_vld || lsu_mmu_va1_vld || dutlb_expt_for_taken
      || ptw_l1dtlb_ref_cmplt || jtlb_dutlb_ref_cmplt) begin
    $display("[MMU_DTLB_EXPT_CHAIN_DBG] t=%0t ptw_cmplt=%0b ptw_id=%0d ptw_pgflt=%0b ptw_accerr=%0b | jtlb_cmplt=%0b jtlb_id=%0d jtlb_pgflt=%0b | ref_pgflt=%0b ref_acflt=%0b expt_for_taken=%0b refill_on=%0b refill_type=%0b refill_id0=%0d refill_id1=%0d refill_id_sel=%0d | miss0=%0b miss1=%0b upd0=%0b upd1=%0b older0=%0b older1=%0b",
      $time,
      ptw_l1dtlb_ref_cmplt, ptw_l1dtlb_ref_id, ptw_l1tlb_pgflt, ptw_l1tlb_acc_err,
      jtlb_dutlb_ref_cmplt, jtlb_dutlb_ref_id, jtlb_dutlb_pgflt,
      dutlb_ref_pgflt, dutlb_ref_acflt, dutlb_expt_for_taken, l1dtlb_refill_on,
      refill_type, refill_id_flop0, refill_id_flop1, refill_id_flop,
      dutlb_miss_vld0, dutlb_miss_vld1, dutlb_refill_upd0, dutlb_refill_upd1,
      dutlb_inst_id_older0, dutlb_inst_id_older1);
  end
end
`endif
`endif
logic lsu_mmu_stamo_vld0;
logic [PPN_WIDTH-1:0] lsu_mmu_stamo_pa0;

assign lsu_mmu_stamo_vld0 = 1'b0;
assign lsu_mmu_stamo_pa0[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};

mmu_l1dtlb_hit_rd #(
    .VPN_WIDTH                  (VPN_WIDTH),
    .PPN_WIDTH                  (PPN_WIDTH),
    .FLG_WIDTH                  (FLG_WIDTH),
    .NUM_ENTRY                  (NUM_ENTRY)
) x_hit_rd_port0 (
    // Clock & Reset
    .cpurst_b                   (cpurst_b),
    .forever_cpuclk             (forever_cpuclk),
    .dplru_clk                  (dplru_clk),
    .dutlb_clk                  (dutlb_clk),

    // System Config
    .cp0_mach_mode              (cp0_mach_mode),
    .cp0_mmu_icg_en             (cp0_mmu_icg_en),
    .cp0_mmu_mxr                (cp0_mmu_mxr),
    .cp0_mmu_sum                (cp0_mmu_sum),
    .cp0_supv_mode              (cp0_supv_mode),
    .cp0_user_mode              (cp0_user_mode),

    // Entry Interface (Packed Vectors)
    .entry_vld_vec              (entry_vld),          // [NUM_ENTRY-1:0]
    .entry_flg_vec              (entry_flg_vec),      // [NUM_ENTRY*FLG_WIDTH-1:0]
    .entry_hit_vec              (entry_hit0),         // Input: Port 0 CAM Hit Results
    .entry_ppn_vec              (entry_ppn_vec),      // [NUM_ENTRY*PPN_WIDTH-1:0]

    // Control & Misc
    .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
    .refill_id_flop             (refill_id_flop),               // Tie-off if not using Refill ID checking in Hit path

    // DUTLB Specifics
    .biu_mmu_smp_disable        (biu_mmu_smp_disable),
    .dutlb_expt_for_taken       (dutlb_expt_for_taken),
    .expt_match_x               (expt_match0),
    .expt_pgflt_x               (expt_pgflt0),
    .expt_acflt_x               (expt_acflt0),
    .dutlb_off_hit              (dutlb_off_hit),
    .dutlb_ori_read_x           (dutlb_ori_read0),
    .dutlb_read_type_x          (dutlb_read_type0),
    .dutlb_ref_pgflt            (dutlb_ref_pgflt),               //l2tlb page fault or ptw refill page fault 
    .dutlb_ref_accflt		(dutlb_ref_acflt),
    .dutlb_refill_on_x          (l1dtlb_refill_on),
    //.dutlb_stall_override_x     (1'b0),

    // Status/Miss Outputs (Connect to Port 0 logic)
    .dutlb_acc_flt_x            (dutlb_acc_flt0),
    .dutlb_inst_id_match_x      (dutlb_inst_id_match0),
    .dutlb_inst_id_older_x      (dutlb_inst_id_older0),
    .dutlb_miss_vld_short_x     (dutlb_miss_vld_short0),
    .dutlb_miss_vld_x           (dutlb_miss_vld0),        // To T1 Stage
    .dutlb_plru_read_hit_vld_x  (dutlb_plru_read_hit_vld0),
    .dutlb_plru_read_hit_x      (dutlb_plru_read_hit0),   // To PLRU Update
    .dutlb_va_chg_x             (dutlb_va_chg0),

    // LSU Interface Inputs (Port 0)
    .lsu_mmu_va_vld_x           (lsu_mmu_va0_vld),
    .lsu_mmu_id_x               (lsu_mmu_id0),
    .lsu_mmu_va_x               (lsu_mmu_va0),
    .lsu_mmu_vabuf_x            (lsu_mmu_vabuf0),
    .lsu_mmu_abort_x            (lsu_mmu_abort0),
    .lsu_mmu_stamo_vld_x        (lsu_mmu_stamo_vld0),
    .lsu_mmu_stamo_pa_x         (lsu_mmu_stamo_pa0),

    // LSU Interface Outputs (Port 0)
    .mmu_lsu_pa_vld_x           (mmu_lsu_pa0_vld),
    .mmu_lsu_pa_x               (mmu_lsu_pa0),
    .mmu_lsu_buf_x              (mmu_lsu_buf0),
    .mmu_lsu_ca_x               (mmu_lsu_ca0),
    .mmu_lsu_sh_x               (mmu_lsu_sh0),
    .mmu_lsu_so_x               (mmu_lsu_so0),
    .mmu_lsu_stall_x            (mmu_lsu_stall0),
    .mmu_lsu_sec_x              (mmu_lsu_sec0),
    .mmu_lsu_access_fault_x     (mmu_lsu_access_fault0),
    .mmu_lsu_page_fault_x       (mmu_lsu_page_fault0),

    // PMP & SysMap & UTLB Req
    .pmp_mmu_flg_x              (pmp_mmu_flg0),
    .mmu_pmp_pa_x               (mmu_pmp_pa0),
    .sysmap_mmu_flg_x           (sysmap_mmu_flg0),
    .mmu_sysmap_pa_x            (mmu_sysmap_pa0),
    .utlb_req_vpn_x             (utlb_req_vpn0)       // To Entry CAM match
);

logic lsu_mmu_stamo_vld1;
logic [PPN_WIDTH-1:0] lsu_mmu_stamo_pa1;

assign lsu_mmu_stamo_vld1 = lsu_mmu_stamo_vld;
assign lsu_mmu_stamo_pa1[PPN_WIDTH-1:0] = lsu_mmu_stamo_pa[PPN_WIDTH-1:0];
//==============================================================================
//                  Hit Read Instance - Port 1
//==============================================================================
mmu_l1dtlb_hit_rd #(
    .VPN_WIDTH                  (VPN_WIDTH),
    .PPN_WIDTH                  (PPN_WIDTH),
    .FLG_WIDTH                  (FLG_WIDTH),
    .NUM_ENTRY                  (NUM_ENTRY)
) x_hit_rd_port1 (
    // Clock & Reset
    .cpurst_b                   (cpurst_b),
    .forever_cpuclk             (forever_cpuclk),
    .dplru_clk                  (dplru_clk),
    .dutlb_clk                  (dutlb_clk),

    // System Config
    .cp0_mach_mode              (cp0_mach_mode),
    .cp0_mmu_icg_en             (cp0_mmu_icg_en),
    .cp0_mmu_mxr                (cp0_mmu_mxr),
    .cp0_mmu_sum                (cp0_mmu_sum),
    .cp0_supv_mode              (cp0_supv_mode),
    .cp0_user_mode              (cp0_user_mode),

    // Entry Interface (Packed Vectors)
    .entry_vld_vec              (entry_vld),
    .entry_flg_vec              (entry_flg_vec),
    .entry_hit_vec              (entry_hit1),         // Input: Port 1 CAM Hit Results
    .entry_ppn_vec              (entry_ppn_vec),

    // Control & Misc
    .pad_yy_icg_scan_en         (pad_yy_icg_scan_en),
    .refill_id_flop             (refill_id_flop),

    // DUTLB Specifics
    .biu_mmu_smp_disable        (biu_mmu_smp_disable),
    .dutlb_expt_for_taken       (dutlb_expt_for_taken),
    .expt_match_x               (expt_match1),
    .expt_pgflt_x               (expt_pgflt1),
    .expt_acflt_x               (expt_acflt1),
    .dutlb_off_hit              (dutlb_off_hit),
    .dutlb_ori_read_x           (dutlb_ori_read1),    // Port 1 Read Logic
    .dutlb_read_type_x          (dutlb_read_type1),   // Port 1 Read Type
    .dutlb_ref_pgflt            (dutlb_ref_pgflt),
    .dutlb_ref_accflt		(dutlb_ref_acflt),
    .dutlb_refill_on_x          (l1dtlb_refill_on),
    //.dutlb_stall_override_x     (1'b0),

    // Status/Miss Outputs (Connect to Port 1 logic)
    .dutlb_acc_flt_x            (dutlb_acc_flt1),
    .dutlb_inst_id_match_x      (dutlb_inst_id_match1),
    .dutlb_inst_id_older_x      (dutlb_inst_id_older1),
    .dutlb_miss_vld_short_x     (dutlb_miss_vld_short1),
    .dutlb_miss_vld_x           (dutlb_miss_vld1),        // To T1 Stage
    .dutlb_plru_read_hit_vld_x  (dutlb_plru_read_hit_vld1),
    .dutlb_plru_read_hit_x      (dutlb_plru_read_hit1),   // To PLRU Update
    .dutlb_va_chg_x             (dutlb_va_chg1),

    // LSU Interface Inputs (Port 1)
    .lsu_mmu_va_vld_x           (lsu_mmu_va1_vld),
    .lsu_mmu_id_x               (lsu_mmu_id1),
    .lsu_mmu_va_x               (lsu_mmu_va1),
    .lsu_mmu_vabuf_x            (lsu_mmu_vabuf1),
    .lsu_mmu_abort_x            (lsu_mmu_abort1),
    .lsu_mmu_stamo_vld_x        (lsu_mmu_stamo_vld1),               // Tie-off: STAMO usually Port 0 only
    .lsu_mmu_stamo_pa_x         (lsu_mmu_stamo_pa1),

    // LSU Interface Outputs (Port 1)
    .mmu_lsu_pa_vld_x           (mmu_lsu_pa1_vld),
    .mmu_lsu_pa_x               (mmu_lsu_pa1),
    .mmu_lsu_buf_x              (mmu_lsu_buf1),
    .mmu_lsu_ca_x               (mmu_lsu_ca1),
    .mmu_lsu_sh_x               (mmu_lsu_sh1),
    .mmu_lsu_so_x               (mmu_lsu_so1),
    .mmu_lsu_stall_x            (mmu_lsu_stall1),
    .mmu_lsu_sec_x              (mmu_lsu_sec1),
    .mmu_lsu_access_fault_x     (mmu_lsu_access_fault1),
    .mmu_lsu_page_fault_x       (mmu_lsu_page_fault1),

    // PMP & SysMap & UTLB Req
    .pmp_mmu_flg_x              (pmp_mmu_flg1),
    .mmu_pmp_pa_x               (mmu_pmp_pa1),
    .sysmap_mmu_flg_x           (sysmap_mmu_flg1),
    .mmu_sysmap_pa_x            (mmu_sysmap_pa1),
    .utlb_req_vpn_x             (utlb_req_vpn1)       // To Entry CAM match
);



//!************************************************
//! T1: Miss Staging (T0->T1 registers)
//!************************************************
always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        miss0_vld_q   <= 1'b0;
        miss0_vpn_q   <= '0;
        miss0_iid_q   <= '0;
        miss0_abort_q <= 1'b0;
	miss0_is_store<= 1'b0; 
    end else begin
        miss0_vld_q   <= dutlb_miss_vld0;
        miss0_vpn_q   <= utlb_req_vpn0;
        miss0_iid_q   <= lsu_mmu_id0;
        miss0_abort_q <= lsu_mmu_abort0;
	miss0_is_store<= lsu_mmu_st_inst0;
    end
end

always_ff @(posedge mb_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
        miss1_vld_q   <= 1'b0;
        miss1_vpn_q   <= '0;
        miss1_iid_q   <= '0;
        miss1_abort_q <= 1'b0;
	miss1_is_store<= 1'b0; 
    end else begin
        miss1_vld_q   <= dutlb_miss_vld1;
        miss1_vpn_q   <= utlb_req_vpn1;
        miss1_iid_q   <= lsu_mmu_id1;
        miss1_abort_q <= lsu_mmu_abort1;
	miss1_is_store<= lsu_mmu_st_inst1;
    end
end

//!************************************************
//! Miss Buffer CAM Logic (Hit-Under-Miss Detection)
//!************************************************
// T1 Stage Hit signals
logic mb_hit0;
logic mb_hit1;
logic same_4k_miss01;
logic [MB_DEPTH-1:0] mb_hit0_vec;
logic [MB_DEPTH-1:0] mb_hit1_vec;

// ------------------------------------------------------------
// Check if T1 requests match any existing valid MB entry
// ------------------------------------------------------------
always_comb begin
    // Port 0 Hit Detection
    for (int k = 0; k < MB_DEPTH; k++) begin
        // Hit condition: Entry is Valid AND VPN matches
        mb_hit0_vec[k] = miss0_vld_q && mb_entry_vld[k] && (mb_entry_vpn[k] == miss0_vpn_q);
    end
    mb_hit0 = |mb_hit0_vec; // OR reduction to get single hit signal

    // Port 1 Hit Detection
    for (int k = 0; k < MB_DEPTH; k++) begin
        mb_hit1_vec[k] = miss1_vld_q && mb_entry_vld[k] && (mb_entry_vpn[k] == miss1_vpn_q);
    end
    mb_hit1 = |mb_hit1_vec;
end

assign same_4k_miss01 = miss0_vld_q && !miss0_abort_q
                      && miss1_vld_q && !miss1_abort_q
                      && (miss0_vpn_q == miss1_vpn_q);


//!************************************************
//! Allocator Instance (Modified)
//!************************************************
// Modify the req*_vld logic to gate allocation on MB Hit.
// If both LSU ports miss the same 4K page in T1, allocate only port 0.
mmu_l1dtlb_allocator #(
    .MB_DEPTH(MB_DEPTH),
    .VPN_WIDTH(VPN_WIDTH),
    .IID_WIDTH(IID_WIDTH),
    .PORT_WIDTH(1)
) x_allocator (
    .cpurst_b(cpurst_b),
    .forever_cpuclk(forever_cpuclk),
    
    // Port 0: Add !mb_hit0
    // If it's a hit in MB, we treat it as "Merged" and DO NOT allocate a new entry.
    .req0_vld(miss0_vld_q && !miss0_abort_q && !mb_hit0), 
    .req0_vpn(miss0_vpn_q),
    .req0_iid(miss0_iid_q),
    .req0_port_id(1'b0),
    
    // Port 1: Add !mb_hit1
    .req1_vld(miss1_vld_q && !miss1_abort_q && !mb_hit1 && !same_4k_miss01),
    .req1_vpn(miss1_vpn_q),
    .req1_iid(miss1_iid_q),
    .req1_port_id(1'b1),
    
    .mb_vld(mb_entry_vld),
    
    .gnt0(alloc_gnt0),
    .gnt1(alloc_gnt1),
    .sel0(alloc_sel0),
    .sel1(alloc_sel1),
    .alloc_we(mb_alloc_we)
);

//!************************************************
//! Scheduler Instance
//!************************************************
logic [MB_DEPTH-1:0] mb_entry_store;
mmu_l1dtlb_scheduler #(
    .MB_DEPTH   (MB_DEPTH),
    .VPN_WIDTH  (VPN_WIDTH),
    .IID_WIDTH  (IID_WIDTH),
    .CREDIT_MAX (8)               // Parameter: Max entries in L2TLB ReqQ
) x_scheduler (
    .cpurst_b         (cpurst_b),
    .sched_clk        (sched_clk),
    
    // Miss Buffer Status Inputs
    .mb_entry_vld     (mb_entry_vld),
    .mb_entry_ready   (mb_entry_ready),
    .mb_entry_vpn     (mb_entry_vpn),
    .mb_entry_iid     (mb_entry_iid),
    .mb_entry_store   (mb_entry_store),     // NEW: Connected to MB array
    
    // Bypass Inputs (From T1 Stage / Allocator)
    .alloc_gnt0       (alloc_gnt0),
    .alloc_sel0       (alloc_sel0),
    .alloc_vpn0       (miss0_vpn_q), 
    .alloc_iid0       (miss0_iid_q),
    .alloc_store0     (miss0_is_store),     // NEW: Connected to T1 Port 0
    
    .alloc_gnt1       (alloc_gnt1),
    .alloc_sel1       (alloc_sel1),
    .alloc_vpn1       (miss1_vpn_q),
    .alloc_iid1       (miss1_iid_q),
    .alloc_store1     (miss1_is_store),     // NEW: Connected to T1 Port 1
    
    // L2TLB Interface (Credit-Based)
    .l2tlb_credit_ret (credit_return), 
    .dutlb_arb_req    (dutlb_l2tlb_req_vld),      
    .dutlb_arb_vpn    (dutlb_l2tlb_req_vpn),       
    .dutlb_arb_id     (dutlb_l2tlb_req_eid),       
    .dutlb_arb_store  (dutlb_l2tlb_req_store),  // NEW: Connected to Top Output
    
    // To Miss Buffer (Feedback)
    .issue_sel        (mb_issue_sel),
    .issue_grant_out  (mb_issue_grant)
);

assign dutlb_l2tlb_req_is_load = ~dutlb_l2tlb_req_store;

//!************************************************
//! Miss Buffer Entry Instances
//!************************************************

//!************************************************
//! New Signals for WFI/Install Logic
//!************************************************
logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;
logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;
logic [MB_DEPTH-1:0]                mb_entry_wfi;
logic [MB_DEPTH-1:0]                refill_gnt_bus; // From Install

//!************************************************
//! Miss Buffer Entry Instances (Modified)
//!************************************************
genvar i;
generate
    for (i = 0; i < MB_DEPTH; i++) begin : gen_mb_entries
        
        // ============================================================
        // 1. Allocation Logic & Data Muxing
        // ============================================================
        logic alloc_this_entry;
        // alloc_we is one-hot from Allocator
        assign alloc_this_entry = mb_alloc_we[i];
        
        // Local signals for the entry's allocation inputs
        logic [VPN_WIDTH-1:0] alloc_vpn_i;
        logic [IID_WIDTH-1:0] alloc_iid_i;
        //logic                 alloc_port_id_i;
        logic                 alloc_store_i; // NEW: Local signal for store attribute
        
        // Mux logic to route Global T1 signals to this specific Entry based on Allocator grant
        always_comb begin
            // Default values to prevent latches
            alloc_vpn_i     = '0;
            alloc_iid_i     = '0;
            //alloc_port_id_i = 1'b0;
            alloc_store_i   = 1'b0;

            // If Allocator granted Port 0 to this Entry Index
            if (alloc_gnt0 && (alloc_sel0 == i[EID_WIDTH-1:0])) begin
                alloc_vpn_i     = miss0_vpn_q;
                alloc_iid_i     = miss0_iid_q;
                //alloc_port_id_i = 1'b0;
                alloc_store_i   = miss0_is_store; // Route Port 0 Store bit
            end 
            // If Allocator granted Port 1 to this Entry Index
            else if (alloc_gnt1 && (alloc_sel1 == i[EID_WIDTH-1:0])) begin
                alloc_vpn_i     = miss1_vpn_q;
                alloc_iid_i     = miss1_iid_q;
                //alloc_port_id_i = 1'b1;
                alloc_store_i   = miss1_is_store; // Route Port 1 Store bit
            end
        end

        // ============================================================
        // 2. Refill Source Identification & Data Muxing
        // ============================================================
        logic is_jtlb_refill;
        logic is_ptw_refill;
        
        // Check ID match for both sources
        assign is_jtlb_refill = jtlb_dutlb_ref_cmplt && (jtlb_dutlb_ref_id == i[EID_WIDTH-1:0]);
        assign is_ptw_refill  = ptw_l1dtlb_ref_cmplt && (ptw_l1dtlb_ref_id == i[EID_WIDTH-1:0]);

	logic [PGS_WIDTH-1:0]   entry_ref_pgs;
        logic                   entry_ref_vld;
        logic [PPN_WIDTH-1:0]   entry_ref_ppn;
        logic [FLG_WIDTH-1:0]   entry_ref_flg;
        logic                   entry_ref_pgflt;
        logic                   entry_ref_acflt;

        // Combine Valid (collision possible logic handled by ID check, 
        // usually ID collision implies logic error elsewhere, but OR is safe)
        assign entry_ref_vld = is_jtlb_refill || is_ptw_refill;

        // Data Mux: Select data source based on who is refilling
        always_comb begin
            // Default to JTLB to prevent latch (though logic covers all valid cases)
            entry_ref_ppn   = jtlb_utlb_ref_ppn;
            entry_ref_flg   = jtlb_utlb_ref_flg;
            entry_ref_pgflt = 1'b0;
            entry_ref_acflt = 1'b0;
	          entry_ref_pgs   = jtlb_utlb_ref_pgs;

            if (is_ptw_refill) begin
                entry_ref_ppn   = ptw_l1tlb_ref_ppn;
                entry_ref_flg   = ptw_l1tlb_ref_flg;
                entry_ref_pgflt = ptw_l1tlb_pgflt;
                entry_ref_acflt = ptw_l1tlb_acc_err;
		            entry_ref_pgs   = ptw_l1tlb_ref_pgs;
            end else if (is_jtlb_refill) begin
                entry_ref_ppn   = jtlb_utlb_ref_ppn;
                entry_ref_flg   = jtlb_utlb_ref_flg;
                entry_ref_pgflt = jtlb_dutlb_pgflt;
                entry_ref_acflt = 1'b0;
		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
                //entry_ref_acflt = jtlb_dutlb_acc_err;
            end
        end

        // ============================================================
        // 3. Instance
        // ============================================================
        mmu_l1dtlb_mb_entry #(
            .VPN_WIDTH(VPN_WIDTH),
            .PPN_WIDTH(PPN_WIDTH),
            .FLG_WIDTH(FLG_WIDTH),
            .IID_WIDTH(IID_WIDTH),
            .PORT_WIDTH(1)
        ) x_mb_entry (
            .cpurst_b(cpurst_b),
            .forever_cpuclk(forever_cpuclk),
            .mb_clk(mb_clk),
            .cp0_mmu_icg_en(cp0_mmu_icg_en),
            .pad_yy_icg_scan_en(pad_yy_icg_scan_en),
            
            // Alloc Interface (Data from local Mux)
            .alloc_vld     (alloc_this_entry),
            .alloc_vpn     (alloc_vpn_i),
            .alloc_iid     (alloc_iid_i),
            //.alloc_port_id (alloc_port_id_i),
            .alloc_store   (alloc_store_i),     // NEW: Connected
            
            // Issue Interface
            .issue_sel     (mb_issue_sel[i]),
            .issue_grant   (mb_issue_grant),
            
            // Refill Interface (Data from local Mux)
            .refill_vld    (entry_ref_vld),
            .refill_gnt    (refill_gnt_bus[i]), // Global Arbiter Grant from Install module
            .refill_pgflt  (entry_ref_pgflt),
            .refill_acflt  (entry_ref_acflt),
            .refill_ppn    (entry_ref_ppn),
            .refill_flg    (entry_ref_flg),
	    .refill_pgs	   (entry_ref_pgs),
            .expt_hit      (expt_hit_vec[i]),
            
            // Flush Interface
            .rtu_yy_xx_flush(rtu_yy_xx_flush),
            .tlboper_utlb_clr(tlboper_utlb_clr),
            .tlboper_utlb_inv_va_req(tlboper_utlb_inv_va_req),
            .lsu_mmu_tlb_va(lsu_mmu_tlb_va),
            
            // Status Outputs
            .entry_vld     (mb_entry_vld[i]),
            .entry_state   (mb_entry_state[i]),
            .entry_vpn     (mb_entry_vpn[i]),
            .entry_ppn     (mb_entry_ppn[i]),
            .entry_flg     (mb_entry_flg[i]),
            .entry_iid     (mb_entry_iid[i]),
	    .entry_pgs	   (mb_entry_pgs[i]),
            //.entry_port_id (mb_entry_port_id[i]),
            .entry_store   (mb_entry_store[i]), // NEW: Connected to array
            .entry_issued  (mb_entry_issued[i]),
            .entry_ready   (mb_entry_ready[i]),
            .entry_wfc     (mb_entry_wfc[i]),
            .entry_fault_state (mb_entry_fault[i]),
            .entry_wfi     (mb_entry_wfi[i])
        );
    end
endgenerate



//!************************************************
//! ARB Interface
//!************************************************
//assign dutlb_arb_req  = issue_req;
//assign dutlb_arb_vpn  = issue_vpn;
//assign dutlb_arb_load = 1'b1;  // TODO: determine from entry
//assign dutlb_arb_id   = issue_eid;

//!************************************************
//! TLB Entry Array Instance
//!************************************************
// 1. Decode Refill Index (from Install Module) to One-Hot Update Signal
logic [15:0] entry_upd;
always_comb begin
    entry_upd = 16'b0;
    if (utlb_refill_vld) begin
        entry_upd[utlb_refill_idx] = 1'b1;
    end
end

// 2. Global Update Signals (Shared Bus from Install Module)
// These are wire aliases for readability, matching the Install module outputs
logic [VPN_WIDTH-1:0] utlb_upd_vpn;
logic [PPN_WIDTH-1:0] utlb_upd_ppn;
logic [FLG_WIDTH-1:0] utlb_upd_flg;

assign utlb_upd_vpn = utlb_refill_vpn;
assign utlb_upd_ppn = utlb_refill_ppn;
assign utlb_upd_flg = utlb_refill_flg;

// 3. Entry Generation Loop
logic [15:0] ctc_inv_va_hit_clr;
logic [15:0]  l1dtlb_entry_clr;
logic [15:0]  l1dtlb_ent_clk_en;
logic [15:0]  l1dtlb_entry_clk;
logic [15:0]  l1dtlb_ent_vld;
logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;
logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;
logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;
logic [15:0]  l1dtlb_vpn_match0;
logic [15:0]  l1dtlb_vpn_match1;

generate
    // Common Gating Logic for Invalidation/Flush
    assign l1dtlb_entry_gating_clr = regs_utlb_clr 
                                   | tlboper_utlb_clr 
                                   | tlboper_utlb_inv_va_req;

    // Loop for all 16 entries (0 to NUM_ENTRY-1)
    // No special case for entry 16. All entries are identical.
    for (genvar l1dtlb_ent = 0; l1dtlb_ent < NUM_ENTRY; l1dtlb_ent = l1dtlb_ent + 1) begin: u_l1dtlb_ent
        
        //----------------------------------------------------------
        // Invalidation Logic (VA Match)
        //----------------------------------------------------------
        // Clear entry if invalidation request matches the partial VPN (bits [7:0])
        assign ctc_inv_va_hit_clr[l1dtlb_ent] = tlboper_utlb_inv_va_req
                                              && l1dtlb_ent_vld[l1dtlb_ent]
                                              && (lsu_mmu_tlb_va[7:0] == l1dtlb_ent_vpn[l1dtlb_ent][7:0]); 

        assign l1dtlb_entry_clr[l1dtlb_ent] = regs_utlb_clr 
                                            | tlboper_utlb_clr 
                                            | ctc_inv_va_hit_clr[l1dtlb_ent];
        
        //----------------------------------------------------------
        // Clock Gating
        //----------------------------------------------------------
        assign l1dtlb_ent_clk_en[l1dtlb_ent] = l1dtlb_entry_gating_clr
                                             | entry_upd[l1dtlb_ent];
        
        gated_clk_cell x_dutlb_entry_gateclk (
          .clk_in             (utlb_clk                     ),
          .clk_out            (l1dtlb_entry_clk[l1dtlb_ent] ),
          .external_en        (1'b0                         ),
          .global_en          (1'b1                         ),
          .local_en           (l1dtlb_ent_clk_en[l1dtlb_ent]),
          .module_en          (cp0_mmu_icg_en               ),
          .pad_yy_icg_scan_en (pad_yy_icg_scan_en           )
        );

        //!************************************************************** //! L1DTLB Entry Storage
        //!************************************************************** // 1. Valid Bit
        always @(posedge l1dtlb_entry_clk[l1dtlb_ent] or negedge cpurst_b) begin
          if(!cpurst_b)
            l1dtlb_ent_vld[l1dtlb_ent] <= 1'b0;
          else if(l1dtlb_entry_clr[l1dtlb_ent])
            l1dtlb_ent_vld[l1dtlb_ent] <= 1'b0;
          else if(entry_upd[l1dtlb_ent])
            l1dtlb_ent_vld[l1dtlb_ent] <= 1'b1;
        end
        
        // 2. Payload (VPN, PPN, Flags, PageSize)
        always @(posedge l1dtlb_entry_clk[l1dtlb_ent] or negedge cpurst_b) begin
            if(!cpurst_b) begin
                l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
                l1dtlb_ent_ppn[l1dtlb_ent][PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
                l1dtlb_ent_flg[l1dtlb_ent][FLG_WIDTH-1:0] <= {FLG_WIDTH{1'b0}};
                l1dtlb_ent_pgs[l1dtlb_ent][PGS_WIDTH-1:0] <= {PGS_WIDTH{1'b0}};
            end
            else if(entry_upd[l1dtlb_ent]) begin
                l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:0] <= utlb_upd_vpn[VPN_WIDTH-1:0];
                l1dtlb_ent_ppn[l1dtlb_ent][PPN_WIDTH-1:0] <= utlb_upd_ppn[PPN_WIDTH-1:0];
                l1dtlb_ent_flg[l1dtlb_ent][FLG_WIDTH-1:0] <= utlb_upd_flg[FLG_WIDTH-1:0];
                // Store the Page Size info (Critical for hybrid support)
                l1dtlb_ent_pgs[l1dtlb_ent][PGS_WIDTH-1:0] <= utlb_refill_pgs[PGS_WIDTH-1:0]; 
            end
        end

        //!************************************************************** //! L1DTLB Unified Hit Logic (4K / 2M / 1G)
        //!************************************************************** // Define match signals for different page sizes
        logic hit0_4k, hit0_2m, hit0_1g;
        logic hit1_4k, hit1_2m, hit1_1g;

        // --- Port 0 Comparators ---
        // 4KB: Compare all bits [26:0]
        assign hit0_4k = (utlb_req_vpn0[VPN_WIDTH-1:0] == l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:0]);
        // 2MB: Compare [26:9] (Ignore lower 9 bits)
        assign hit0_2m = (utlb_req_vpn0[VPN_WIDTH-1:LVL_WIDTH] == l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:LVL_WIDTH]);
        // 1GB: Compare [26:18] (Ignore lower 18 bits)
        assign hit0_1g = (utlb_req_vpn0[VPN_WIDTH-1:2*LVL_WIDTH] == l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:2*LVL_WIDTH]);

        // --- Port 1 Comparators ---
        assign hit1_4k = (utlb_req_vpn1[VPN_WIDTH-1:0] == l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:0]);
        assign hit1_2m = (utlb_req_vpn1[VPN_WIDTH-1:LVL_WIDTH] == l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:LVL_WIDTH]);
        assign hit1_1g = (utlb_req_vpn1[VPN_WIDTH-1:2*LVL_WIDTH] == l1dtlb_ent_vpn[l1dtlb_ent][VPN_WIDTH-1:2*LVL_WIDTH]);

        // --- Final Match Logic ---
        // Select the correct comparator result based on the stored Page Size (pgs)
        // Assuming encoding: pgs[0]=4K, pgs[1]=2M, pgs[2]=1G
        
        assign l1dtlb_vpn_match0[l1dtlb_ent] = (l1dtlb_ent_pgs[l1dtlb_ent][0] & hit0_4k) 
                                             | (l1dtlb_ent_pgs[l1dtlb_ent][1] & hit0_2m)
                                             | (l1dtlb_ent_pgs[l1dtlb_ent][2] & hit0_1g);

        assign l1dtlb_vpn_match1[l1dtlb_ent] = (l1dtlb_ent_pgs[l1dtlb_ent][0] & hit1_4k) 
                                             | (l1dtlb_ent_pgs[l1dtlb_ent][1] & hit1_2m)
                                             | (l1dtlb_ent_pgs[l1dtlb_ent][2] & hit1_1g);

        // Final Hit Output (Valid && Match)
        assign entry_hit0[l1dtlb_ent] = l1dtlb_ent_vld[l1dtlb_ent] && l1dtlb_vpn_match0[l1dtlb_ent];
        assign entry_hit1[l1dtlb_ent] = l1dtlb_ent_vld[l1dtlb_ent] && l1dtlb_vpn_match1[l1dtlb_ent];
        
        // Read Port Outputs
        assign entry_vld[l1dtlb_ent] = l1dtlb_ent_vld[l1dtlb_ent];
        assign entry_ppn[l1dtlb_ent] = l1dtlb_ent_ppn[l1dtlb_ent][PPN_WIDTH-1:0];
        assign entry_flg[l1dtlb_ent] = l1dtlb_ent_flg[l1dtlb_ent][FLG_WIDTH-1:0];

    end
endgenerate





//!************************************************
//! Install and Wakeup Logic
//!************************************************
logic install_clk, install_clk_en;
assign install_clk_en = jtlb_dutlb_ref_cmplt
                      || ptw_l1dtlb_ref_cmplt
                      || |mb_entry_wfc
                      || |mb_entry_wfi;

gated_clk_cell x_install_gateclk (
    .clk_in(forever_cpuclk), .clk_out(install_clk),
    .external_en(1'b0), .global_en(1'b1),
    .local_en(install_clk_en), .module_en(cp0_mmu_icg_en),
    .pad_yy_icg_scan_en(pad_yy_icg_scan_en)
);

mmu_l1dtlb_install #(
    .MB_DEPTH(MB_DEPTH),
    .VPN_WIDTH(VPN_WIDTH),
    .PPN_WIDTH(PPN_WIDTH),
    .FLG_WIDTH(FLG_WIDTH),
    .IID_WIDTH(IID_WIDTH)
) x_install (
    .cpurst_b(cpurst_b),
    .install_clk(install_clk),
    
    // MB Status Inputs
    .mb_entry_vld(mb_entry_vld),
    .mb_entry_state(mb_entry_state),
    .mb_entry_vpn(mb_entry_vpn),
    .mb_entry_iid(mb_entry_iid),
    .mb_entry_pgs(mb_entry_pgs),
    //.mb_entry_port_id(mb_entry_port_id),
    
    // WFI Inputs
    .mb_entry_ppn(mb_entry_ppn),
    .mb_entry_flg(mb_entry_flg),
    .mb_entry_wfi(mb_entry_wfi),
    
    // Grant Output
    .mb_refill_gnt_bus(refill_gnt_bus),
    
    // JTLB Refill Inputs
    .jtlb_dutlb_ref_pavld(jtlb_dutlb_ref_pavld),
    .jtlb_dutlb_ref_cmplt(jtlb_dutlb_ref_cmplt),
    .jtlb_dutlb_ref_id(jtlb_dutlb_ref_id),
    .jtlb_utlb_ref_vpn(jtlb_utlb_ref_vpn),
    .jtlb_utlb_ref_ppn(jtlb_utlb_ref_ppn),
    .jtlb_utlb_ref_flg(jtlb_utlb_ref_flg),
    .jtlb_dutlb_pgflt(jtlb_dutlb_pgflt),
    .l2tlb_l1dtlb_ref_pgs(jtlb_utlb_ref_pgs),
    //.jtlb_dutlb_acc_err(jtlb_dutlb_acc_err),

    // PTW Refill Inputs (NEW)
    .ptw_l1dtlb_ref_pavld(ptw_l1dtlb_ref_pavld),
    .ptw_l1dtlb_ref_cmplt(ptw_l1dtlb_ref_cmplt),
    .ptw_l1dtlb_ref_id(ptw_l1dtlb_ref_id),
    .ptw_l1tlb_ref_vpn(ptw_l1tlb_ref_vpn),
    .ptw_l1tlb_ref_ppn(ptw_l1tlb_ref_ppn),
    .ptw_l1tlb_ref_flg(ptw_l1tlb_ref_flg),
    .ptw_l1tlb_pgflt(ptw_l1tlb_pgflt),
    .ptw_l1tlb_acc_err(ptw_l1tlb_acc_err),
    .ptw_l1dtlb_ref_pgs(ptw_l1tlb_ref_pgs),
    
    // UTLB Update Outputs
    .utlb_refill_vld(utlb_refill_vld),
    .utlb_refill_idx(utlb_refill_idx),
    .utlb_refill_vpn(utlb_refill_vpn),
    .utlb_refill_ppn(utlb_refill_ppn),
    .utlb_refill_flg(utlb_refill_flg),
    .utlb_refill_pgs(utlb_refill_pgs),
    
    // PLRU & Wakeup
    .plru_bank0_refill_way(plru_bank0_refill_way),
    .plru_bank1_refill_way(plru_bank1_refill_way),
    .plru_refill_updt(plru_refill_updt),
    .plru_refill_way(plru_refill_way),
    .mmu_lsu_tlb_wakeup(install_wakeup)
);

assign mmu_lsu_tlb_wakeup = install_wakeup | expt_wakeup;
assign mmu_lsu_tlb_busy = |mb_entry_vld;

assign expt_wakeup = {12{|mb_entry_fault}};

//!************************************************
//! Status Outputs
//!************************************************
assign mmu_hpcp_dutlb_miss = dutlb_miss_vld0 || dutlb_miss_vld1;
assign dutlb_ptw_wfc = |mb_entry_wfc;
assign dutlb_top_ref_cur_st = 3'b0;  // TODO
assign dutlb_top_ref_type = 1'b0;    // TODO
assign dutlb_top_scd_updt = 1'b0;    // TODO
//assign dutlb_arb_cmplt = 1'b0;       // TODO

endmodule
