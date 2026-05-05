//!****************************************************
//! L1 DTLB Hit Read Module (Parameterized)
//!    - Parameterized Entry Count
//!    - Removed special Huge Page logic (Uniform Entries)
//!****************************************************
module mmu_l1dtlb_hit_rd #(
    parameter VPN_WIDTH = 27,
    parameter PPN_WIDTH = 28,
    parameter FLG_WIDTH = 14,
    parameter PGS_WIDTH = 3,
    parameter NUM_ENTRY = 16  // Configurable Entry Count
)(
    //! Clock and Reset
    input  logic         cpurst_b,
    input  logic         forever_cpuclk,
    input  logic         dplru_clk,
    input  logic         dutlb_clk,

    //! SysReg
    input  logic         cp0_mach_mode,
    input  logic         cp0_mmu_icg_en,
    input  logic         cp0_mmu_mxr,
    input  logic         cp0_mmu_sum,
    input  logic         cp0_supv_mode,
    input  logic         cp0_user_mode,

    //! Parameterized L1DTLB Entry Interface
    // Flattened arrays for easier port connection
    input  logic [NUM_ENTRY-1:0]                entry_vld_vec,
    input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec, 
    input  logic [NUM_ENTRY-1:0]                entry_hit_vec,
    input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,

    // Miscellaneous
    input  logic         pad_yy_icg_scan_en,
    input  logic [6 :0]  refill_id_flop,

    // DUTLB Control
    input  logic         biu_mmu_smp_disable,
    input  logic         dutlb_expt_for_taken,
    input  logic         expt_match_x,
    input  logic         expt_pgflt_x,
    input  logic         expt_acflt_x,
    input  logic         dutlb_off_hit,
    input  logic         dutlb_ori_read_x,
    input  logic         dutlb_read_type_x,
    input  logic         dutlb_ref_pgflt,
    input  logic	 dutlb_ref_accflt,
    input  logic         dutlb_refill_on_x,
    //input  logic         dutlb_stall_override_x,

    // DUTLB Status/Miss Outputs
    output logic         dutlb_acc_flt_x,
    output logic         dutlb_inst_id_match_x,
    output logic         dutlb_inst_id_older_x,
    output logic         dutlb_miss_vld_short_x,
    output logic         dutlb_miss_vld_x,
    output logic         dutlb_plru_read_hit_vld_x,
    output logic [NUM_ENTRY-1:0] dutlb_plru_read_hit_x, // Adjusted width
    output logic         dutlb_va_chg_x,

    // LSU Interface inputs
    input  logic         lsu_mmu_va_vld_x,
    input  logic [6 :0]  lsu_mmu_id_x,
    input  logic [63:0]  lsu_mmu_va_x,
    input  logic [27:0]  lsu_mmu_vabuf_x,
    input  logic         lsu_mmu_abort_x,
    input  logic         lsu_mmu_stamo_vld_x,
    input  logic [27:0]  lsu_mmu_stamo_pa_x,

    // Output to LSU
    output logic         mmu_lsu_pa_vld_x,
    output logic [27:0]  mmu_lsu_pa_x,
    output logic         mmu_lsu_buf_x,
    output logic         mmu_lsu_ca_x,
    output logic         mmu_lsu_sh_x,
    output logic         mmu_lsu_so_x,
    output logic         mmu_lsu_stall_x,
    output logic         mmu_lsu_sec_x,
    output logic         mmu_lsu_access_fault_x,
    output logic         mmu_lsu_page_fault_x,

    // PMP & SysMap & UTLB Req
    input  logic [3 :0]  pmp_mmu_flg_x,
    output logic [27:0]  mmu_pmp_pa_x,
    input  logic [4 :0]  sysmap_mmu_flg_x,
    output logic [27:0]  mmu_sysmap_pa_x,
    output logic [26:0]  utlb_req_vpn_x
);

parameter VPN_PERLEL = 9;

// Internal Signals
logic [13:0]  dutlb_entry_flg;
logic [27:0]  dutlb_entry_pa;
logic [27:0]  dutlb_pa_buf;
logic         jtlb_acc_fault_flop;
logic         pmp_flg_vld;
logic         pmp_read_type;

logic         dutlb_addr_hit;
logic         dutlb_disable_vld;
logic [NUM_ENTRY-1:0] dutlb_entry_hit;
logic         dutlb_entry_hit_vld;
logic         dutlb_expt_match;
logic [13:0]  dutlb_fin_flg;
logic [27:0]  dutlb_fin_pa;
logic [2 :0]  dutlb_fin_pgs;
logic         dutlb_hit_vld;
logic         dutlb_inst_id_hit;
logic [13:0]  dutlb_off_flg;
logic [27:0]  dutlb_off_pa;
logic [2 :0]  dutlb_off_pgs;
logic         dutlb_page_fault;
logic         dutlb_pmp_chk_vld;
logic [13:0]  dutlb_pre_flg;
logic [27:0]  dutlb_pre_pa;
logic [2 :0]  dutlb_pre_pgs;
logic         dutlb_pre_sel;
logic         dutlb_req_id_older;
logic         dutlb_va_illegal;
logic         lsu_va_chg;
logic [2 :0]  mmu_lsu_page_size_x;
logic         pabuf_clk;
logic         pabuf_clk_en;
logic [NUM_ENTRY-1:0] vpn_hit;
logic [NUM_ENTRY-1:0] vpn_vld;

//==========================================================
//                  Internal Unpacking & Logic
//==========================================================
// Reconstruct 2D arrays for easier MUXing inside this module if needed,
// or just index the vector directly.
// Here we use the vectors directly passed from top.

assign vpn_vld = entry_vld_vec;
assign vpn_hit = entry_hit_vec;

assign dutlb_entry_hit = vpn_vld & vpn_hit;
assign dutlb_entry_hit_vld = |dutlb_entry_hit;
assign dutlb_addr_hit = dutlb_entry_hit_vld;

//----------------------------------------------------------
//                  Translation Related Signal
//----------------------------------------------------------
assign dutlb_hit_vld = lsu_mmu_va_vld_x && dutlb_addr_hit;
assign dutlb_disable_vld = lsu_mmu_va_vld_x && dutlb_off_hit;

assign mmu_lsu_pa_vld_x = dutlb_hit_vld
                        | dutlb_disable_vld
			| dutlb_va_illegal
                        | dutlb_expt_match;

assign mmu_lsu_stall_x  = 1'b0;
assign mmu_lsu_pa_x[PPN_WIDTH-1:0] = dutlb_fin_pa[PPN_WIDTH-1:0];
assign mmu_lsu_page_size_x[PGS_WIDTH-1:0] = dutlb_fin_pgs[PGS_WIDTH-1:0];

// Flags judgement
assign mmu_lsu_sh_x  = dutlb_fin_flg[10] && !biu_mmu_smp_disable;
assign mmu_lsu_buf_x = dutlb_fin_flg[11] || !dutlb_fin_flg[13];
assign mmu_lsu_so_x  = dutlb_fin_flg[13];
assign mmu_lsu_sec_x = dutlb_fin_flg[9];
assign mmu_lsu_ca_x  = dutlb_fin_flg[12] && !dutlb_fin_flg[13];

//----------------------------------------------------------
//                  Exception Checking
//----------------------------------------------------------
assign dutlb_va_illegal = ( lsu_mmu_va_x[VPN_WIDTH+11] && !(&lsu_mmu_va_x[63:VPN_WIDTH+12])
                         || !lsu_mmu_va_x[VPN_WIDTH+11] &&  (|lsu_mmu_va_x[63:VPN_WIDTH+12])
                          )
                          && !dutlb_off_hit && lsu_mmu_va_vld_x;

assign dutlb_page_fault = ( !dutlb_fin_flg[0]
                         || !dutlb_fin_flg[1] && dutlb_fin_flg[2]
                         || !dutlb_fin_flg[1] && dutlb_read_type_x && !(cp0_mmu_mxr && dutlb_fin_flg[3])
                         || !dutlb_fin_flg[2] && !dutlb_read_type_x
                         ||  dutlb_fin_flg[4] && cp0_supv_mode && !cp0_mmu_sum
                         || !dutlb_fin_flg[4] && cp0_user_mode
                         || !dutlb_fin_flg[5]
                         || !dutlb_fin_flg[6] && !dutlb_read_type_x
                          )
                          && dutlb_addr_hit
                          || expt_match_x && expt_pgflt_x
                          || dutlb_va_illegal;

assign mmu_lsu_page_fault_x = dutlb_page_fault && !dutlb_off_hit;

assign mmu_lsu_access_fault_x = jtlb_acc_fault_flop
                            || !pmp_mmu_flg_x[0] && (pmp_read_type || dutlb_ori_read_x)
                               && !(cp0_mach_mode && !pmp_mmu_flg_x[3])
                               && pmp_flg_vld
                            || !pmp_mmu_flg_x[1] && !pmp_read_type
                               && !(cp0_mach_mode && !pmp_mmu_flg_x[3])
                               && pmp_flg_vld;

assign dutlb_acc_flt_x = jtlb_acc_fault_flop;

// PLRU Update
always @(posedge dplru_clk or negedge cpurst_b) begin
  if (!cpurst_b)
    dutlb_plru_read_hit_x <= {NUM_ENTRY{1'b0}};
  else if(lsu_mmu_va_vld_x)
    dutlb_plru_read_hit_x <= dutlb_entry_hit;
end

assign dutlb_plru_read_hit_vld_x = |dutlb_plru_read_hit_x;

// L1TLB Miss Determination
// An exception CAM replay consumes an existing miss-buffer fault entry.  It is
// not a new DTLB miss and must not allocate another miss-buffer entry.
assign dutlb_miss_vld_x = lsu_mmu_va_vld_x
                        & !dutlb_entry_hit_vld
                        & !dutlb_va_illegal
                        & !lsu_mmu_abort_x
                        & !dutlb_off_hit
                        & !dutlb_expt_match;

assign dutlb_miss_vld_short_x = lsu_mmu_va_vld_x
                              & !dutlb_entry_hit_vld
                              & !dutlb_va_illegal
                              & !dutlb_off_hit
                              & !dutlb_expt_match;

assign dutlb_inst_id_hit = (refill_id_flop[6:0] == lsu_mmu_id_x[6:0])
                         & lsu_mmu_va_vld_x;

assign dutlb_inst_id_match_x = dutlb_inst_id_hit & !lsu_mmu_abort_x;

ct_rtu_compare_iid  x_mmu_dutlb_read_compare_req_iid (
  .x_iid0               (lsu_mmu_id_x[6:0]  ),
  .x_iid0_older         (dutlb_req_id_older ),
  .x_iid1               (refill_id_flop[6:0])
);

assign dutlb_inst_id_older_x = dutlb_req_id_older && lsu_mmu_va_vld_x && !lsu_mmu_abort_x;
assign dutlb_expt_match = expt_match_x;

//==========================================================
//                  Data Muxing (Parameterized)
//==========================================================
// Mux out the hit PPN & FLG using a loop
always_comb begin
    dutlb_entry_pa  = {PPN_WIDTH{1'b0}};
    dutlb_entry_flg = {FLG_WIDTH{1'bx}};
    
    for (int i = 0; i < NUM_ENTRY; i++) begin
        if (dutlb_entry_hit[i]) begin
            dutlb_entry_pa  = entry_ppn_vec[i*PPN_WIDTH +: PPN_WIDTH];
            dutlb_entry_flg = entry_flg_vec[i*FLG_WIDTH +: FLG_WIDTH];
        end
    end
end

//----------------------------------------------------------
//                  Output Selection (MMU Off vs Hit)
//----------------------------------------------------------
assign dutlb_off_pa[PPN_WIDTH-1:0] = lsu_mmu_va_x[VPN_WIDTH+12:12];
assign dutlb_off_flg[FLG_WIDTH-1:0] = {sysmap_mmu_flg_x[4:0], 5'b00110, 3'b111, 1'b1};
assign dutlb_off_pgs[PGS_WIDTH-1:0] = 3'b0; // 4K default

// Pre-select logic: MMU is off OR VA not valid OR STAMO
// Removed specific checks for Entry 16 or Huge pages.
assign dutlb_pre_sel = dutlb_off_hit
                     | !lsu_mmu_va_vld_x
                     | dutlb_va_illegal
                     | dutlb_expt_match
                     | lsu_mmu_stamo_vld_x;

assign dutlb_pre_pa[PPN_WIDTH-1:0] = lsu_mmu_stamo_vld_x ? lsu_mmu_stamo_pa_x[PPN_WIDTH-1:0]
                                                         : dutlb_off_pa[PPN_WIDTH-1:0];

assign dutlb_pre_flg[FLG_WIDTH-1:0] = dutlb_off_flg[FLG_WIDTH-1:0];
assign dutlb_pre_pgs[PGS_WIDTH-1:0] = dutlb_off_pgs[PGS_WIDTH-1:0];

//! Hit Final PA
assign dutlb_fin_pa[PPN_WIDTH-1:0] = dutlb_pre_sel ? dutlb_pre_pa[PPN_WIDTH-1:0]
                                                   : dutlb_entry_pa[PPN_WIDTH-1:0];

//! Hit Final Flags
assign dutlb_fin_flg[FLG_WIDTH-1:0] = dutlb_pre_sel ? dutlb_pre_flg[FLG_WIDTH-1:0]
                                                    : dutlb_entry_flg[FLG_WIDTH-1:0];
//! Hit Page Size
// Default to 4K (3'b001) for Hits, or Off-size for Pre-select
assign dutlb_fin_pgs[PGS_WIDTH-1:0] = dutlb_pre_sel ? dutlb_pre_pgs[PGS_WIDTH-1:0]
                                                    : 3'b001; 

//----------------------------------------------------------
//                  JTLB Access Fault Latch
//----------------------------------------------------------
always @(posedge dutlb_clk or negedge cpurst_b) begin
  if(!cpurst_b)
    jtlb_acc_fault_flop <= 1'b0;
  else
    jtlb_acc_fault_flop <= expt_match_x & expt_acflt_x & !lsu_mmu_abort_x;
end

//----------------------------------------------------------
//                  PMP & Buffer Clock
//----------------------------------------------------------
assign lsu_va_chg = lsu_mmu_va_vld_x;
assign pabuf_clk_en = lsu_va_chg
                  || lsu_mmu_va_vld_x
                  || pmp_flg_vld ^ lsu_mmu_va_vld_x;

gated_clk_cell  x_dutlb_pabuf_gateclk (
  .clk_in             (forever_cpuclk     ),
  .clk_out            (pabuf_clk          ),
  .external_en        (1'b0               ),
  .global_en          (1'b1               ),
  .local_en           (pabuf_clk_en       ),
  .module_en          (cp0_mmu_icg_en     ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

assign dutlb_pmp_chk_vld = (dutlb_hit_vld | dutlb_disable_vld) & !dutlb_page_fault;

always @(posedge pabuf_clk or negedge cpurst_b) begin
  if(!cpurst_b) pmp_flg_vld <= 1'b0;
  else if(dutlb_pmp_chk_vld) pmp_flg_vld <= 1'b1;
  else pmp_flg_vld <= 1'b0;
end

always @(posedge pabuf_clk or negedge cpurst_b) begin
  if(!cpurst_b) pmp_read_type <= 1'b0;
  else if(dutlb_pmp_chk_vld) pmp_read_type <= dutlb_read_type_x;
end

always @(posedge pabuf_clk) begin
  if(dutlb_pmp_chk_vld)
    dutlb_pa_buf[PPN_WIDTH-1:0] <= dutlb_fin_pa[PPN_WIDTH-1:0];
end

assign dutlb_va_chg_x = lsu_va_chg;
assign mmu_pmp_pa_x[PPN_WIDTH-1:0] = dutlb_pa_buf[PPN_WIDTH-1:0];
assign utlb_req_vpn_x[VPN_WIDTH-1:0] = lsu_mmu_va_x[VPN_WIDTH+11:12];
assign mmu_sysmap_pa_x[PPN_WIDTH-1:0] = lsu_mmu_va_x[VPN_WIDTH+12:12];

`ifndef SYNTHESIS
`ifdef MMU_EXPT_TRACE_ONCE_EN
// One-shot replay correlation trace:
//   replay_hit(iid,vpn) after CAM lookup/consume path
always @(posedge dutlb_clk) begin
  static bit seen_replay[string];
  string key;
  if (lsu_mmu_va_vld_x && dutlb_expt_match && !lsu_mmu_abort_x) begin
    key = $sformatf("RH_iid%0d_vpn%0h", lsu_mmu_id_x, lsu_mmu_va_x[VPN_WIDTH+11:12]);
    if (!seen_replay.exists(key)) begin
      seen_replay[key] = 1'b1;
      $display("[MMU_EXPT_TRACE_ONCE][REPLAY_HIT] t=%0t iid=%0d vpn=0x%0h pa_vld=%0b pgflt=%0b acflt=%0b miss=%0b",
        $time, lsu_mmu_id_x, lsu_mmu_va_x[VPN_WIDTH+11:12], mmu_lsu_pa_vld_x,
        mmu_lsu_page_fault_x, mmu_lsu_access_fault_x, dutlb_miss_vld_x);
    end
  end
end

`endif
`ifdef MMU_DTLB_DBG_EN
// Debug: trace why PA path selects bypass (VA[38:12]) vs TLB hit PPN.
always @(posedge dutlb_clk) begin
  if (lsu_mmu_va_vld_x) begin
    $display("[MMU_DTLB_HIT_RD_DBG] t=%0t va=0x%016h id=%0d pre_sel=%0b off_hit=%0b !va_vld=%0b va_illegal=%0b expt_match=%0b stamo_vld=%0b hit_vld=%0b miss=%0b fin_pa=0x%07h off_pa=0x%07h entry_pa=0x%07h",
      $time, lsu_mmu_va_x, lsu_mmu_id_x,
      dutlb_pre_sel, dutlb_off_hit, !lsu_mmu_va_vld_x, dutlb_va_illegal, dutlb_expt_match, lsu_mmu_stamo_vld_x,
      mmu_lsu_pa_vld_x, dutlb_miss_vld_x,
      dutlb_fin_pa, dutlb_off_pa, dutlb_entry_pa);
  end
end

// Debug: full local exception/id-match chain for this port.
always @(posedge dutlb_clk) begin
  if (lsu_mmu_va_vld_x || dutlb_expt_for_taken || dutlb_expt_match) begin
    $display("[MMU_DTLB_HIT_RD_EXPT_DBG] t=%0t id=%0d refill_id=%0d inst_id_hit=%0b inst_id_match=%0b inst_id_older=%0b expt_for_taken=%0b expt_match=%0b | ref_pgflt=%0b ref_acflt=%0b refill_on=%0b | addr_hit=%0b hit_vld=%0b miss=%0b page_fault=%0b access_fault=%0b",
      $time, lsu_mmu_id_x, refill_id_flop,
      dutlb_inst_id_hit, dutlb_inst_id_match_x, dutlb_inst_id_older_x,
      dutlb_expt_for_taken, dutlb_expt_match,
      dutlb_ref_pgflt, dutlb_ref_accflt, dutlb_refill_on_x,
      dutlb_addr_hit, mmu_lsu_pa_vld_x, dutlb_miss_vld_x,
      mmu_lsu_page_fault_x, mmu_lsu_access_fault_x);
  end
end
`endif
`endif

endmodule
