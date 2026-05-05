//=============================================================================
// MMU UVM Verification — testbench/top/tb_top.sv
// Phase 2: DUT instantiation + interface connections + vif config_db
// DUT: ct_mmu_top.v (Sv39 MMU, OpenRISCV2030)
// Clock: forever_cpuclk 1 GHz  Reset: cpurst_b active-low
//=============================================================================
`timescale 1ns/1ps

module tb_top;

  timeunit 1ns;
  timeprecision 1ps;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  //=========================================================================
  // Clock & Reset Generation
  //=========================================================================
  bit forever_cpuclk;
  bit cpurst_b;

  // 1 GHz: 0.5 ns half-period
  initial forever_cpuclk = 1'b0;
  always #0.5 forever_cpuclk = ~forever_cpuclk;

  // Active-low reset: hold low for 20 cycles then release
  initial begin
    cpurst_b = 1'b0;
    repeat (20) @(posedge forever_cpuclk);
    @(negedge forever_cpuclk);
    cpurst_b = 1'b1;
  end

  //=========================================================================
  // Interface Instantiation
  //=========================================================================
  ifu_if        ifu_if_inst        (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  lsu_if        lsu_if_inst        (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  cp0_if        cp0_if_inst        (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  ptw_mem_if    ptw_mem_if_inst    (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  pmp_if        pmp_if_inst        (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  sysmap_cfg_if sysmap_cfg_if_inst (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  misc_if       misc_if_inst       (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
  mmu_dut_probes_if dut_probes_if   (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));

  // cv_dv_utils shared library: elaborate xrtl_reset_vif, generic_if,
  // memory_response_if, axi_if (avoids UII-L when those sources are compiled)
  cv_dv_utils_unref_if_instances u_cv_dv_utils_unref_if (
      .clk_i(forever_cpuclk),
      .rst_ni(cpurst_b)
  );

  //=========================================================================
  // DUT Instantiation — ct_mmu_top
  //=========================================================================
  ct_mmu_top u_dut (
    //------------------------------------------------------------------
    // Clock & Reset
    //------------------------------------------------------------------
    .forever_cpuclk           (forever_cpuclk),
    .cpurst_b                 (cpurst_b),

    //------------------------------------------------------------------
    // CP0 Interface
    //------------------------------------------------------------------
    .cp0_mmu_cskyee           (cp0_if_inst.cp0_mmu_cskyee),
    .cp0_mmu_icg_en           (cp0_if_inst.cp0_mmu_icg_en),
    .cp0_mmu_maee             (cp0_if_inst.cp0_mmu_maee),
    .cp0_mmu_mpp              (cp0_if_inst.cp0_mmu_mpp),
    .cp0_mmu_mprv             (cp0_if_inst.cp0_mmu_mprv),
    .cp0_mmu_mxr              (cp0_if_inst.cp0_mmu_mxr),
    .cp0_mmu_no_op_req        (cp0_if_inst.cp0_mmu_no_op_req),
    .cp0_mmu_ptw_en           (cp0_if_inst.cp0_mmu_ptw_en),
    .cp0_mmu_reg_num          (cp0_if_inst.cp0_mmu_reg_num),
    .cp0_mmu_satp_sel         (cp0_if_inst.cp0_mmu_satp_sel),
    .cp0_mmu_sum              (cp0_if_inst.cp0_mmu_sum),
    .cp0_mmu_tlb_all_inv      (cp0_if_inst.cp0_mmu_tlb_all_inv),
    .cp0_mmu_wdata            (cp0_if_inst.cp0_mmu_wdata),
    .cp0_mmu_wreg             (cp0_if_inst.cp0_mmu_wreg),
    .cp0_yy_priv_mode         (cp0_if_inst.cp0_yy_priv_mode),
    .mmu_cp0_cmplt            (cp0_if_inst.mmu_cp0_cmplt),
    .mmu_cp0_data             (cp0_if_inst.mmu_cp0_data),
    .mmu_cp0_satp_data        (cp0_if_inst.mmu_cp0_satp_data),
    .mmu_cp0_tlb_done         (cp0_if_inst.mmu_cp0_tlb_done),
    .mmu_xx_mmu_en            (cp0_if_inst.mmu_xx_mmu_en),
    .mmu_yy_xx_no_op          (cp0_if_inst.mmu_yy_xx_no_op),

    //------------------------------------------------------------------
    // HPCP (via misc_if)
    //------------------------------------------------------------------
    .hpcp_mmu_cnt_en          (misc_if_inst.hpcp_mmu_cnt_en),
    .mmu_hpcp_dutlb_miss      (misc_if_inst.mmu_hpcp_dutlb_miss),
    .mmu_hpcp_iutlb_miss      (misc_if_inst.mmu_hpcp_iutlb_miss),
    .mmu_hpcp_jtlb_miss       (misc_if_inst.mmu_hpcp_jtlb_miss),

    //------------------------------------------------------------------
    // BIU / Debug (via misc_if)
    //------------------------------------------------------------------
    .biu_mmu_smp_disable      (misc_if_inst.biu_mmu_smp_disable),
    .mmu_had_debug_info       (misc_if_inst.mmu_had_debug_info),

    //------------------------------------------------------------------
    // IFU Interface
    //------------------------------------------------------------------
    .ifu_mmu_va_vld           (ifu_if_inst.ifu_mmu_va_vld),
    .ifu_mmu_va               (ifu_if_inst.ifu_mmu_va),
    .ifu_mmu_abort            (ifu_if_inst.ifu_mmu_abort),
    .mmu_ifu_buf              (ifu_if_inst.mmu_ifu_buf),
    .mmu_ifu_ca               (ifu_if_inst.mmu_ifu_ca),
    .mmu_ifu_deny             (ifu_if_inst.mmu_ifu_deny),
    .mmu_ifu_pa               (ifu_if_inst.mmu_ifu_pa),
    .mmu_ifu_pavld            (ifu_if_inst.mmu_ifu_pavld),
    .mmu_ifu_pgflt            (ifu_if_inst.mmu_ifu_pgflt),
    .mmu_ifu_sec              (ifu_if_inst.mmu_ifu_sec),

    //------------------------------------------------------------------
    // LSU Interface — Pipe 0
    //------------------------------------------------------------------
    .lsu_mmu_va0_vld          (lsu_if_inst.lsu_mmu_va0_vld),
    .lsu_mmu_id0              (lsu_if_inst.lsu_mmu_id0),
    .lsu_mmu_va0              (lsu_if_inst.lsu_mmu_va0),
    .lsu_mmu_st_inst0         (lsu_if_inst.lsu_mmu_st_inst0),
    .lsu_mmu_abort0           (lsu_if_inst.lsu_mmu_abort0),
    .lsu_mmu_vabuf0           (lsu_if_inst.lsu_mmu_vabuf0),
    .mmu_lsu_pa0_vld          (lsu_if_inst.mmu_lsu_pa0_vld),
    .mmu_lsu_pa0              (lsu_if_inst.mmu_lsu_pa0),
    .mmu_lsu_page_fault0      (lsu_if_inst.mmu_lsu_page_fault0),
    .mmu_lsu_sec0             (lsu_if_inst.mmu_lsu_sec0),
    .mmu_lsu_sh0              (lsu_if_inst.mmu_lsu_sh0),
    .mmu_lsu_so0              (lsu_if_inst.mmu_lsu_so0),
    .mmu_lsu_stall0           (lsu_if_inst.mmu_lsu_stall0),
    .mmu_lsu_buf0             (lsu_if_inst.mmu_lsu_buf0),
    .mmu_lsu_ca0              (lsu_if_inst.mmu_lsu_ca0),
    .mmu_lsu_access_fault0    (lsu_if_inst.mmu_lsu_access_fault0),

    //------------------------------------------------------------------
    // LSU Interface — Pipe 1
    //------------------------------------------------------------------
    .lsu_mmu_va1_vld          (lsu_if_inst.lsu_mmu_va1_vld),
    .lsu_mmu_id1              (lsu_if_inst.lsu_mmu_id1),
    .lsu_mmu_va1              (lsu_if_inst.lsu_mmu_va1),
    .lsu_mmu_st_inst1         (lsu_if_inst.lsu_mmu_st_inst1),
    .lsu_mmu_abort1           (lsu_if_inst.lsu_mmu_abort1),
    .lsu_mmu_vabuf1           (lsu_if_inst.lsu_mmu_vabuf1),
    .mmu_lsu_pa1_vld          (lsu_if_inst.mmu_lsu_pa1_vld),
    .mmu_lsu_pa1              (lsu_if_inst.mmu_lsu_pa1),
    .mmu_lsu_page_fault1      (lsu_if_inst.mmu_lsu_page_fault1),
    .mmu_lsu_sec1             (lsu_if_inst.mmu_lsu_sec1),
    .mmu_lsu_sh1              (lsu_if_inst.mmu_lsu_sh1),
    .mmu_lsu_so1              (lsu_if_inst.mmu_lsu_so1),
    .mmu_lsu_stall1           (lsu_if_inst.mmu_lsu_stall1),
    .mmu_lsu_buf1             (lsu_if_inst.mmu_lsu_buf1),
    .mmu_lsu_ca1              (lsu_if_inst.mmu_lsu_ca1),
    .mmu_lsu_access_fault1    (lsu_if_inst.mmu_lsu_access_fault1),

    //------------------------------------------------------------------
    // LSU Interface — Pipe 2 / Prefetch
    //------------------------------------------------------------------
    .lsu_mmu_va2_vld          (lsu_if_inst.lsu_mmu_va2_vld),
    .lsu_mmu_va2              (lsu_if_inst.lsu_mmu_va2),
    .mmu_lsu_pa2_vld          (lsu_if_inst.mmu_lsu_pa2_vld),
    .mmu_lsu_pa2              (lsu_if_inst.mmu_lsu_pa2),
    .mmu_lsu_sec2             (lsu_if_inst.mmu_lsu_sec2),
    .mmu_lsu_pa2_err          (lsu_if_inst.mmu_lsu_pa2_err),
    .mmu_lsu_share2           (lsu_if_inst.mmu_lsu_share2),

    //------------------------------------------------------------------
    // LSU Interface — STAMO
    //------------------------------------------------------------------
    .lsu_mmu_stamo_vld        (lsu_if_inst.lsu_mmu_stamo_vld),
    .lsu_mmu_stamo_pa         (lsu_if_inst.lsu_mmu_stamo_pa),

    //------------------------------------------------------------------
    // LSU Interface — TLB Invalidation
    //------------------------------------------------------------------
    .lsu_mmu_tlb_va_all_inv   (lsu_if_inst.lsu_mmu_tlb_va_all_inv),
    .lsu_mmu_tlb_va           (lsu_if_inst.lsu_mmu_tlb_va),
    .lsu_mmu_tlb_all_inv      (lsu_if_inst.lsu_mmu_tlb_all_inv),
    .lsu_mmu_tlb_va_asid_inv  (lsu_if_inst.lsu_mmu_tlb_va_asid_inv),
    .lsu_mmu_tlb_asid         (lsu_if_inst.lsu_mmu_tlb_asid),
    .lsu_mmu_tlb_asid_all_inv (lsu_if_inst.lsu_mmu_tlb_asid_all_inv),
    .mmu_lsu_tlb_inv_done     (lsu_if_inst.mmu_lsu_tlb_inv_done),

    //------------------------------------------------------------------
    // PTW/LSU Data Channel (v7.3: mmu_en/busy/wakeup stay in lsu_if)
    //------------------------------------------------------------------
    .mmu_lsu_mmu_en           (lsu_if_inst.mmu_lsu_mmu_en),
    .mmu_lsu_data_req         (ptw_mem_if_inst.mmu_lsu_data_req),
    .mmu_lsu_data_req_addr    (ptw_mem_if_inst.mmu_lsu_data_req_addr),
    .mmu_lsu_data_req_size    (ptw_mem_if_inst.mmu_lsu_data_req_size),
    .lsu_mmu_bus_error        (ptw_mem_if_inst.lsu_mmu_bus_error),
    .lsu_mmu_data_vld         (ptw_mem_if_inst.lsu_mmu_data_vld),
    .lsu_mmu_data             (ptw_mem_if_inst.lsu_mmu_data),
    .mmu_lsu_tlb_busy         (lsu_if_inst.mmu_lsu_tlb_busy),
    .mmu_lsu_tlb_wakeup       (lsu_if_inst.mmu_lsu_tlb_wakeup),

    //------------------------------------------------------------------
    // DFT
    //------------------------------------------------------------------
    .pad_yy_icg_scan_en       (misc_if_inst.pad_yy_icg_scan_en),

    //------------------------------------------------------------------
    // PMP Interface
    //------------------------------------------------------------------
    .pmp_mmu_flg0             (pmp_if_inst.pmp_mmu_flg0),
    .pmp_mmu_flg1             (pmp_if_inst.pmp_mmu_flg1),
    .pmp_mmu_flg2             (pmp_if_inst.pmp_mmu_flg2),
    .pmp_mmu_flg3             (pmp_if_inst.pmp_mmu_flg3),
    .pmp_mmu_flg4             (pmp_if_inst.pmp_mmu_flg4),
    .pmp_mmu_flg5             (pmp_if_inst.pmp_mmu_flg5),
    .pmp_mmu_flg6             (pmp_if_inst.pmp_mmu_flg6),
    .pmp_mmu_flg7             (pmp_if_inst.pmp_mmu_flg7),
    .mmu_pmp_fetch3           (pmp_if_inst.mmu_pmp_fetch3),
    .mmu_pmp_fetch5           (pmp_if_inst.mmu_pmp_fetch5),
    .mmu_pmp_fetch6           (pmp_if_inst.mmu_pmp_fetch6),
    .mmu_pmp_fetch7           (pmp_if_inst.mmu_pmp_fetch7),
    .mmu_pmp_pa0              (pmp_if_inst.mmu_pmp_pa0),
    .mmu_pmp_pa1              (pmp_if_inst.mmu_pmp_pa1),
    .mmu_pmp_pa2              (pmp_if_inst.mmu_pmp_pa2),
    .mmu_pmp_pa3              (pmp_if_inst.mmu_pmp_pa3),
    .mmu_pmp_pa4              (pmp_if_inst.mmu_pmp_pa4),
    .mmu_pmp_pa5              (pmp_if_inst.mmu_pmp_pa5),
    .mmu_pmp_pa6              (pmp_if_inst.mmu_pmp_pa6),
    .mmu_pmp_pa7              (pmp_if_inst.mmu_pmp_pa7),

    //------------------------------------------------------------------
    // RTU Interface (via misc_if)
    //------------------------------------------------------------------
    .rtu_mmu_bad_vpn          (misc_if_inst.rtu_mmu_bad_vpn),
    .rtu_mmu_expt_vld         (misc_if_inst.rtu_mmu_expt_vld),
    .rtu_yy_xx_flush          (misc_if_inst.rtu_yy_xx_flush)
  );

  logic [1:0]  tb_l1d_refill_src;
  logic [3:0]  tb_l1d_p0_hit_idx;
  logic [26:0] tb_l1d_p0_hit_vpn;
  logic [27:0] tb_l1d_p0_hit_ppn;
  logic [2:0]  tb_l1d_p0_hit_pgs;
  logic [3:0]  tb_l1d_p1_hit_idx;
  logic [26:0] tb_l1d_p1_hit_vpn;
  logic [27:0] tb_l1d_p1_hit_ppn;
  logic [2:0]  tb_l1d_p1_hit_pgs;

  always_comb begin
    tb_l1d_refill_src = 2'b00;
    if (u_dut.u_mmu_l1dtlb.x_install.sel_ptw)
      tb_l1d_refill_src = 2'b01;
    else if (u_dut.u_mmu_l1dtlb.x_install.sel_jtlb)
      tb_l1d_refill_src = 2'b10;
    else if (u_dut.u_mmu_l1dtlb.x_install.sel_wfi)
      tb_l1d_refill_src = 2'b11;
  end

  always_comb begin
    tb_l1d_p0_hit_idx = '0;
    tb_l1d_p0_hit_vpn = '0;
    tb_l1d_p0_hit_ppn = '0;
    tb_l1d_p0_hit_pgs = '0;
    for (int i = 0; i < 16; i++) begin
      if (u_dut.u_mmu_l1dtlb.entry_hit0[i]) begin
        tb_l1d_p0_hit_idx = i[3:0];
        tb_l1d_p0_hit_vpn = u_dut.u_mmu_l1dtlb.l1dtlb_ent_vpn[i];
        tb_l1d_p0_hit_ppn = u_dut.u_mmu_l1dtlb.l1dtlb_ent_ppn[i];
        tb_l1d_p0_hit_pgs = u_dut.u_mmu_l1dtlb.l1dtlb_ent_pgs[i];
      end
    end
  end

  always_comb begin
    tb_l1d_p1_hit_idx = '0;
    tb_l1d_p1_hit_vpn = '0;
    tb_l1d_p1_hit_ppn = '0;
    tb_l1d_p1_hit_pgs = '0;
    for (int i = 0; i < 16; i++) begin
      if (u_dut.u_mmu_l1dtlb.entry_hit1[i]) begin
        tb_l1d_p1_hit_idx = i[3:0];
        tb_l1d_p1_hit_vpn = u_dut.u_mmu_l1dtlb.l1dtlb_ent_vpn[i];
        tb_l1d_p1_hit_ppn = u_dut.u_mmu_l1dtlb.l1dtlb_ent_ppn[i];
        tb_l1d_p1_hit_pgs = u_dut.u_mmu_l1dtlb.l1dtlb_ent_pgs[i];
      end
    end
  end

  // Phase 7 whitebox: hierarchical refs only in module (not in mmu_env_pkg)
  assign dut_probes_if.l1i_entry_vld    = u_dut.x_mmu_l1itlb.entry_vld;
  assign dut_probes_if.l1i_ref_fsm      = u_dut.x_mmu_l1itlb.iutlb_top_ref_cur_st;
  assign dut_probes_if.l1i_credit_cnt   = u_dut.x_mmu_l1itlb.credit_cnt;
  assign dut_probes_if.l1d_mb_vld        = u_dut.u_mmu_l1dtlb.mb_entry_vld;
  assign dut_probes_if.l1d_mb_st0        = u_dut.u_mmu_l1dtlb.mb_entry_state[0];
  assign dut_probes_if.l1d_p0_req_vpn    = u_dut.u_mmu_l1dtlb.utlb_req_vpn0;
  assign dut_probes_if.l1d_p0_addr_hit   = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_addr_hit;
  assign dut_probes_if.l1d_p0_hit_vld    = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_hit_vld;
  assign dut_probes_if.l1d_p0_miss_vld   = u_dut.u_mmu_l1dtlb.dutlb_miss_vld0;
  assign dut_probes_if.l1d_p0_pre_sel    = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_pre_sel;
  assign dut_probes_if.l1d_p0_expt_match = u_dut.u_mmu_l1dtlb.expt_match0;
  assign dut_probes_if.l1d_p0_entry_pa   = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_entry_pa;
  assign dut_probes_if.l1d_p0_off_pa     = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_off_pa;
  assign dut_probes_if.l1d_p0_fin_pa     = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_fin_pa;
  assign dut_probes_if.l1d_p1_req_vpn    = u_dut.u_mmu_l1dtlb.utlb_req_vpn1;
  assign dut_probes_if.l1d_p1_addr_hit   = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_addr_hit;
  assign dut_probes_if.l1d_p1_hit_vld    = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_hit_vld;
  assign dut_probes_if.l1d_p1_miss_vld   = u_dut.u_mmu_l1dtlb.dutlb_miss_vld1;
  assign dut_probes_if.l1d_p1_pre_sel    = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_pre_sel;
  assign dut_probes_if.l1d_p1_expt_match = u_dut.u_mmu_l1dtlb.expt_match1;
  assign dut_probes_if.l1d_p1_entry_pa   = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_entry_pa;
  assign dut_probes_if.l1d_p1_off_pa     = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_off_pa;
  assign dut_probes_if.l1d_p1_fin_pa     = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_fin_pa;
  assign dut_probes_if.l1d_refill_vld    = u_dut.u_mmu_l1dtlb.utlb_refill_vld;
  assign dut_probes_if.l1d_refill_src    = tb_l1d_refill_src;
  assign dut_probes_if.l1d_refill_idx    = u_dut.u_mmu_l1dtlb.utlb_refill_idx;
  assign dut_probes_if.l1d_refill_vpn    = u_dut.u_mmu_l1dtlb.utlb_refill_vpn;
  assign dut_probes_if.l1d_refill_ppn    = u_dut.u_mmu_l1dtlb.utlb_refill_ppn;
  assign dut_probes_if.l1d_refill_pgs    = u_dut.u_mmu_l1dtlb.utlb_refill_pgs;
  assign dut_probes_if.l1d_entry_upd     = u_dut.u_mmu_l1dtlb.entry_upd;
  assign dut_probes_if.l1d_refill_iid0   = u_dut.u_mmu_l1dtlb.refill_id_flop0;
  assign dut_probes_if.l1d_refill_iid1   = u_dut.u_mmu_l1dtlb.refill_id_flop1;
  assign dut_probes_if.l1d_refill_iid_sel = u_dut.u_mmu_l1dtlb.refill_id_flop;
  assign dut_probes_if.l1d_p0_hit_vec    = u_dut.u_mmu_l1dtlb.entry_hit0;
  assign dut_probes_if.l1d_p0_hit_idx    = tb_l1d_p0_hit_idx;
  assign dut_probes_if.l1d_p0_hit_vpn    = tb_l1d_p0_hit_vpn;
  assign dut_probes_if.l1d_p0_hit_ppn    = tb_l1d_p0_hit_ppn;
  assign dut_probes_if.l1d_p0_hit_pgs    = tb_l1d_p0_hit_pgs;
  assign dut_probes_if.l1d_p1_hit_vec    = u_dut.u_mmu_l1dtlb.entry_hit1;
  assign dut_probes_if.l1d_p1_hit_idx    = tb_l1d_p1_hit_idx;
  assign dut_probes_if.l1d_p1_hit_vpn    = tb_l1d_p1_hit_vpn;
  assign dut_probes_if.l1d_p1_hit_ppn    = tb_l1d_p1_hit_ppn;
  assign dut_probes_if.l1d_p1_hit_pgs    = tb_l1d_p1_hit_pgs;
  assign dut_probes_if.l1d_ptw_ref_mb_vld = u_dut.u_mmu_l1dtlb.mb_entry_vld[u_dut.ptw_l1dtlb_id[2:0]];
  assign dut_probes_if.l1d_ptw_ref_mb_iid = u_dut.u_mmu_l1dtlb.mb_entry_iid[u_dut.ptw_l1dtlb_id[2:0]];
  assign dut_probes_if.l1d_ptw_ref_mb_vpn = u_dut.u_mmu_l1dtlb.mb_entry_vpn[u_dut.ptw_l1dtlb_id[2:0]];
  assign dut_probes_if.l2_bank0          = u_dut.x_mmu_l2tlb.way_index[0][2:0];
  assign dut_probes_if.l2_final_way_hit  = u_dut.x_mmu_l2tlb.final_way_hit;
  assign dut_probes_if.l2_raw_pre_pgs0  = u_dut.x_mmu_l2tlb.raw_pre_pgs[0];
  assign dut_probes_if.l2_final_vld      = u_dut.x_mmu_l2tlb.final_vld;
  assign dut_probes_if.l2_final_tlb_hit  = u_dut.x_mmu_l2tlb.final_tlb_hit;
  assign dut_probes_if.l2_miss           = u_dut.x_mmu_l2tlb.l2tlb_miss;
  assign dut_probes_if.l2_final_is_dtlb  = u_dut.x_mmu_l2tlb.final_is_dtlb;
  assign dut_probes_if.l2_final_vpn      = u_dut.x_mmu_l2tlb.final_vpn;
  assign dut_probes_if.l2_final_hit_ppn  = u_dut.x_mmu_l2tlb.final_hit_ppn;
  assign dut_probes_if.l2_dtlb_ref_pavld = u_dut.l2tlb_l1dtlb_ref_pavld;
  assign dut_probes_if.l2_dtlb_ref_cmplt = u_dut.l2tlb_l1dtlb_ref_cmplt;
  assign dut_probes_if.l2_dtlb_ref_vpn   = u_dut.l2tlb_l1tlb_ref_vpn;
  assign dut_probes_if.l2_dtlb_ref_ppn   = u_dut.l2tlb_l1tlb_ref_ppn;
  assign dut_probes_if.l2_reqq_vld_vec  = u_dut.x_mmu_l2tlb.x_l2tlb_reqq.entry_vld_vec;
  assign dut_probes_if.l2_reqq_qid      = u_dut.x_mmu_l2tlb.x_l2tlb_reqq.issue_queue_id;
  assign dut_probes_if.ptw_xbar_hit_lvl = u_dut.x_ct_mmu_ptw.xbar_twu_hit_level;
  assign dut_probes_if.ptw_mbuf_twu_lvl  = u_dut.x_ct_mmu_ptw.mbuf_twu_lvl;
  assign dut_probes_if.ptw_fault_any     = u_dut.x_ct_mmu_ptw.pgflt_vld
                                         | u_dut.x_ct_mmu_ptw.acc_err_vld;
  wire [3:0] tb_ptw_twu_idle;
  wire [3:0] tb_ptw_mbuf_twu_have;

  assign dut_probes_if.ptw_jtlb_ready    = u_dut.x_ct_mmu_ptw.ptw_jtlb_ready;
  // Reconstruct legacy TWU idle probe from per-TWU internal pipeline/CSR state.
  // Original RTL twu_idle output was removed from ptw, but coverage/scoreboard still samples it.
  assign tb_ptw_twu_idle[0] =
      ~(u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_one.fst_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_one.scd_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_one.thd_chk_vld
      | (~u_dut.x_ct_mmu_ptw.twu_one.csr_idle));
  assign tb_ptw_twu_idle[1] =
      ~(u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_two.fst_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_two.scd_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_two.thd_chk_vld
      | (~u_dut.x_ct_mmu_ptw.twu_two.csr_idle));
  assign tb_ptw_twu_idle[2] =
      ~(u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_three.fst_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_three.scd_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_three.thd_chk_vld
      | (~u_dut.x_ct_mmu_ptw.twu_three.csr_idle));
  assign tb_ptw_twu_idle[3] =
      ~(u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_four.fst_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_four.scd_chk_vld
      | u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_vld
      | u_dut.x_ct_mmu_ptw.twu_four.thd_chk_vld
      | (~u_dut.x_ct_mmu_ptw.twu_four.csr_idle));
  assign dut_probes_if.ptw_twu_idle      = tb_ptw_twu_idle;
  assign dut_probes_if.ptw_twu_mask      = u_dut.x_ct_mmu_ptw.twu_mask;
  assign dut_probes_if.ptw_twu_data_ready = u_dut.x_ct_mmu_ptw.twu_data_ready;
  // Reconstruct legacy mbuf_twu_have from mbuf entry ownership.
  assign tb_ptw_mbuf_twu_have[0] =
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[0] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[0]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[1] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[1]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[2] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[2]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[3] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[3]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[4] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[4]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[5] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[5]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[6] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[6]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[7] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[7]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[8] == 4'b0001) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[8]);
  assign tb_ptw_mbuf_twu_have[1] =
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[0] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[0]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[1] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[1]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[2] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[2]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[3] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[3]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[4] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[4]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[5] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[5]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[6] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[6]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[7] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[7]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[8] == 4'b0010) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[8]);
  assign tb_ptw_mbuf_twu_have[2] =
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[0] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[0]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[1] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[1]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[2] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[2]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[3] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[3]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[4] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[4]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[5] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[5]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[6] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[6]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[7] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[7]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[8] == 4'b0100) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[8]);
  assign tb_ptw_mbuf_twu_have[3] =
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[0] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[0]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[1] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[1]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[2] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[2]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[3] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[3]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[4] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[4]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[5] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[5]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[6] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[6]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[7] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[7]) |
      ((u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_twu_idx[8] == 4'b1000) & u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld[8]);
  assign dut_probes_if.ptw_mbuf_twu_have = tb_ptw_mbuf_twu_have;
  assign dut_probes_if.ptw_mbuf_entry_vld = u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld;
  assign dut_probes_if.ptw_twu_ref_req   = u_dut.x_ct_mmu_ptw.twu_arb_ref_req;
  assign dut_probes_if.ptw_twu_pgflt_vec = u_dut.x_ct_mmu_ptw.twu_l2tlb_ref_pgflt;
  assign dut_probes_if.ptw_twu_acc_err_vec = u_dut.x_ct_mmu_ptw.twu_l2tlb_ref_acc_err;
  assign dut_probes_if.ptw_pgflt_vld     = u_dut.x_ct_mmu_ptw.pgflt_vld;
  assign dut_probes_if.ptw_acc_err_vld   = u_dut.x_ct_mmu_ptw.acc_err_vld;
  assign dut_probes_if.ptw_l2tlb_ref_pgflt = u_dut.ptw_l2tlb_ref_pgflt;
  assign dut_probes_if.ptw_l2tlb_ref_acc_err = u_dut.ptw_l2tlb_ref_acc_err;
  assign dut_probes_if.l2tlb_ptw_req      = u_dut.l2tlb_ptw_req;
  assign dut_probes_if.ptw_lsu_data_req   = u_dut.mmu_lsu_data_req;
  assign dut_probes_if.ptw_lsu_data_req_grant = u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant;
  assign dut_probes_if.ptw_arb_req        = u_dut.ptw_arb_req;
  assign dut_probes_if.arb_ptw_grant     = u_dut.arb_ptw_grant;
  assign dut_probes_if.arb_pfu_grant     = u_dut.arb_pfu_grant;
  assign dut_probes_if.arb_l2tlb_req     = u_dut.arb_l2tlb_req;
  assign dut_probes_if.ptw_arb_pgs       = u_dut.ptw_arb_pgs;
  assign dut_probes_if.ptw_arb_vpn       = u_dut.ptw_arb_vpn;
  assign dut_probes_if.ptw_l1d_ref_cmplt = u_dut.ptw_l1dtlb_cmplt;
  assign dut_probes_if.ptw_l1d_ref_id    = u_dut.ptw_l1dtlb_id[2:0];
  assign dut_probes_if.ptw_l1d_ref_ppn   = u_dut.ptw_l1dtlb_ref_ppn;
  assign dut_probes_if.ptw_arb_ref_tag_din = u_dut.ptw_arb_ref_tag_din;
  assign dut_probes_if.ptw_cp0_maee      = u_dut.cp0_mmu_maee;
  // MAEE path/leaf is inferred from per-TWU leaf request outputs because
  // the RTL does not expose a single encoded MAEE-path/leaf signal.
  assign dut_probes_if.maee_leaf_lvl1_hit = u_dut.x_ct_mmu_ptw.twu_one.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_one.fst_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.fst_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.fst_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.fst_chk_refill_req;
  assign dut_probes_if.maee_leaf_lvl2_hit = u_dut.x_ct_mmu_ptw.twu_one.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_one.scd_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.scd_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.scd_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.scd_chk_refill_req;
  assign dut_probes_if.maee_leaf_lvl3_hit = u_dut.x_ct_mmu_ptw.twu_one.thd_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.thd_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.thd_chk_refill_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.thd_chk_refill_req;
  assign dut_probes_if.maee_csr_path_hit  = u_dut.x_ct_mmu_ptw.twu_one.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_one.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_two.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_three.scd_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.fst_chk_csr_req
                                          | u_dut.x_ct_mmu_ptw.twu_four.scd_chk_csr_req;
  assign dut_probes_if.maee_refill_path_hit = u_dut.x_ct_mmu_ptw.twu_one.fst_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_one.scd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_one.thd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_two.fst_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_two.scd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_two.thd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_three.fst_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_three.scd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_three.thd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_four.fst_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_four.scd_chk_refill_req
                                            | u_dut.x_ct_mmu_ptw.twu_four.thd_chk_refill_req;
  // Phase 13 whitebox probes: DA-003 maps PTW PMP ports 3/5/6/7 to TWU one/two/three/four.
  assign dut_probes_if.p13_pmp_vld_vec[0]      = {u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_vld,   u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_vld,   u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_vld};
  assign dut_probes_if.p13_pmp_vld_vec[1]      = {u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_vld,   u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_vld,   u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_vld};
  assign dut_probes_if.p13_pmp_vld_vec[2]      = {u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_vld, u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_vld, u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_vld};
  assign dut_probes_if.p13_pmp_vld_vec[3]      = {u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_vld,  u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_vld,  u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_vld};
  assign dut_probes_if.p13_pmp_grant_vec[0]    = {u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_grant,   u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_grant,   u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_grant};
  assign dut_probes_if.p13_pmp_grant_vec[1]    = {u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_grant,   u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_grant,   u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_grant};
  assign dut_probes_if.p13_pmp_grant_vec[2]    = {u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_grant, u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_grant, u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_grant};
  assign dut_probes_if.p13_pmp_grant_vec[3]    = {u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_grant,  u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_grant,  u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_grant};
  assign dut_probes_if.p13_pmp_deny_vec[0]     = {u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_deny,   u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_deny,   u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_deny};
  assign dut_probes_if.p13_pmp_deny_vec[1]     = {u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_deny,   u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_deny,   u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_deny};
  assign dut_probes_if.p13_pmp_deny_vec[2]     = {u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_deny, u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_deny, u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_deny};
  assign dut_probes_if.p13_pmp_deny_vec[3]     = {u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_deny,  u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_deny,  u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_deny};
  assign dut_probes_if.p13_pmp_wait_vec[0]     = {u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_wait,   u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_wait,   u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_wait};
  assign dut_probes_if.p13_pmp_wait_vec[1]     = {u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_wait,   u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_wait,   u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_wait};
  assign dut_probes_if.p13_pmp_wait_vec[2]     = {u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_wait, u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_wait, u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_wait};
  assign dut_probes_if.p13_pmp_wait_vec[3]     = {u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_wait,  u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_wait,  u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_wait};
  assign dut_probes_if.p13_pmp_mbuf_req_vec[0] = {u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_mbuf_req,   u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_mbuf_req,   u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_mbuf_req};
  assign dut_probes_if.p13_pmp_mbuf_req_vec[1] = {u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_mbuf_req,   u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_mbuf_req,   u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_mbuf_req};
  assign dut_probes_if.p13_pmp_mbuf_req_vec[2] = {u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_mbuf_req, u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_mbuf_req, u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_mbuf_req};
  assign dut_probes_if.p13_pmp_mbuf_req_vec[3] = {u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_mbuf_req,  u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_mbuf_req,  u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_mbuf_req};
  assign dut_probes_if.p13_pmp_type_vec[0]     = {u_dut.x_ct_mmu_ptw.twu_one.fst_pmp_type,   u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_type,   u_dut.x_ct_mmu_ptw.twu_one.thd_pmp_type};
  assign dut_probes_if.p13_pmp_type_vec[1]     = {u_dut.x_ct_mmu_ptw.twu_two.fst_pmp_type,   u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_type,   u_dut.x_ct_mmu_ptw.twu_two.thd_pmp_type};
  assign dut_probes_if.p13_pmp_type_vec[2]     = {u_dut.x_ct_mmu_ptw.twu_three.fst_pmp_type, u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_type, u_dut.x_ct_mmu_ptw.twu_three.thd_pmp_type};
  assign dut_probes_if.p13_pmp_type_vec[3]     = {u_dut.x_ct_mmu_ptw.twu_four.fst_pmp_type,  u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_type,  u_dut.x_ct_mmu_ptw.twu_four.thd_pmp_type};
  assign dut_probes_if.p13_pmp_flg_vec         = {pmp_if_inst.pmp_mmu_flg7, pmp_if_inst.pmp_mmu_flg6, pmp_if_inst.pmp_mmu_flg5, pmp_if_inst.pmp_mmu_flg3};
  assign dut_probes_if.p13_pmp_pa_vec          = {pmp_if_inst.mmu_pmp_pa7, pmp_if_inst.mmu_pmp_pa6, pmp_if_inst.mmu_pmp_pa5, pmp_if_inst.mmu_pmp_pa3};
  assign dut_probes_if.p13_pmp_fetch_vec       = {pmp_if_inst.mmu_pmp_fetch7, pmp_if_inst.mmu_pmp_fetch6, pmp_if_inst.mmu_pmp_fetch5, pmp_if_inst.mmu_pmp_fetch3};
  assign dut_probes_if.pfu_pmp_flg4            = pmp_if_inst.pmp_mmu_flg4;
  assign dut_probes_if.pfu_sysmap_flg4         = u_dut.x_mmu_l2tlb.sysmap_mmu_flg4;
  assign dut_probes_if.pfu_l2tlb_deny          = u_dut.x_mmu_l2tlb.l2tlb_pfu_deny;
  assign dut_probes_if.pfu_l2tlb_acc_fault     = u_dut.x_mmu_l2tlb.l2tlb_pfu_acc_fault;
  assign dut_probes_if.pfu_l2tlb_flag_fault    = u_dut.x_mmu_l2tlb.l2tlb_pfu_flag_fault;
  assign dut_probes_if.p13_sysmap_flg_vec      = {u_dut.x_ct_mmu_ptw.twu_four.sysmap_mmu_flg, u_dut.x_ct_mmu_ptw.twu_three.sysmap_mmu_flg, u_dut.x_ct_mmu_ptw.twu_two.sysmap_mmu_flg, u_dut.x_ct_mmu_ptw.twu_one.sysmap_mmu_flg};
  assign dut_probes_if.p13_sysmap_hit_vec      = {u_dut.x_ct_mmu_ptw.twu_four.sysmap_mmu_hit, u_dut.x_ct_mmu_ptw.twu_three.sysmap_mmu_hit, u_dut.x_ct_mmu_ptw.twu_two.sysmap_mmu_hit, u_dut.x_ct_mmu_ptw.twu_one.sysmap_mmu_hit};
  assign dut_probes_if.p13_sysmap_pa_vec       = {u_dut.x_ct_mmu_ptw.twu_four.mmu_sysmap_pa, u_dut.x_ct_mmu_ptw.twu_three.mmu_sysmap_pa, u_dut.x_ct_mmu_ptw.twu_two.mmu_sysmap_pa, u_dut.x_ct_mmu_ptw.twu_one.mmu_sysmap_pa};
  assign dut_probes_if.p13_twu_sysmap_adder_vec = {u_dut.x_ct_mmu_ptw.twu_four.twu_sysmap_adder, u_dut.x_ct_mmu_ptw.twu_three.twu_sysmap_adder, u_dut.x_ct_mmu_ptw.twu_two.twu_sysmap_adder, u_dut.x_ct_mmu_ptw.twu_one.twu_sysmap_adder};
  assign dut_probes_if.p13_twu_csr_cross_vec   = {u_dut.x_ct_mmu_ptw.twu_four.twu_csr_cross, u_dut.x_ct_mmu_ptw.twu_three.twu_csr_cross, u_dut.x_ct_mmu_ptw.twu_two.twu_csr_cross, u_dut.x_ct_mmu_ptw.twu_one.twu_csr_cross};
  assign dut_probes_if.p13_twu_crs2_1g_vec     = {u_dut.x_ct_mmu_ptw.twu_four.twu_crs2_1g, u_dut.x_ct_mmu_ptw.twu_three.twu_crs2_1g, u_dut.x_ct_mmu_ptw.twu_two.twu_crs2_1g, u_dut.x_ct_mmu_ptw.twu_one.twu_crs2_1g};
  assign dut_probes_if.p13_twu_crs2_2m_vec     = {u_dut.x_ct_mmu_ptw.twu_four.twu_crs2_2m, u_dut.x_ct_mmu_ptw.twu_three.twu_crs2_2m, u_dut.x_ct_mmu_ptw.twu_two.twu_crs2_2m, u_dut.x_ct_mmu_ptw.twu_one.twu_crs2_2m};
  assign dut_probes_if.p13_twu_crs2_chk_vec    = {u_dut.x_ct_mmu_ptw.twu_four.twu_crs2_chk, u_dut.x_ct_mmu_ptw.twu_three.twu_crs2_chk, u_dut.x_ct_mmu_ptw.twu_two.twu_crs2_chk, u_dut.x_ct_mmu_ptw.twu_one.twu_crs2_chk};
  assign dut_probes_if.p13_csr_refill_req_vec  = {u_dut.x_ct_mmu_ptw.twu_four.csr_refill_req, u_dut.x_ct_mmu_ptw.twu_three.csr_refill_req, u_dut.x_ct_mmu_ptw.twu_two.csr_refill_req, u_dut.x_ct_mmu_ptw.twu_one.csr_refill_req};
  assign dut_probes_if.p13_csr_refill_pgs_vec  = {u_dut.x_ct_mmu_ptw.twu_four.csr_refill_pgs, u_dut.x_ct_mmu_ptw.twu_three.csr_refill_pgs, u_dut.x_ct_mmu_ptw.twu_two.csr_refill_pgs, u_dut.x_ct_mmu_ptw.twu_one.csr_refill_pgs};
  assign dut_probes_if.p13_csr_refill_data_vec = {u_dut.x_ct_mmu_ptw.twu_four.csr_refill_data, u_dut.x_ct_mmu_ptw.twu_three.csr_refill_data, u_dut.x_ct_mmu_ptw.twu_two.csr_refill_data, u_dut.x_ct_mmu_ptw.twu_one.csr_refill_data};
  assign ptw_mem_if_inst.mmu_lsu_data_req_accept = |u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant;
  assign dut_probes_if.tlbiva_cur_st     = u_dut.x_ct_mmu_tlboper.tlbiva_cur_st;
  assign ifu_if_inst.dbg_iutlb_acc_flt   = u_dut.x_mmu_l1itlb.iutlb_acc_flt;
  assign ifu_if_inst.dbg_iutlb_pmp_deny  = u_dut.x_mmu_l1itlb.pmp_flg_vld
                                         && !u_dut.x_mmu_l1itlb.pmp_mmu_flg2[2]
                                         && !(u_dut.x_mmu_l1itlb.cp0_mach_mode
                                           && !u_dut.x_mmu_l1itlb.pmp_mmu_flg2[3]);
  assign ifu_if_inst.dbg_iutlb_ref_pgflt = u_dut.x_mmu_l1itlb.iutlb_ref_pgflt;
  assign ifu_if_inst.dbg_jtlb_acc_fault_flop = u_dut.x_mmu_l1itlb.jtlb_acc_fault_flop;

  // DTLB expt CAM (mmu_l1dtlb_expt_cam): on consume, mmu_l1dtlb_hit_rd muxes
  // PPN=VPN and ORs (expt_match & expt_{pg,ac}flt). Software ref has no CAM.
  assign lsu_if_inst.mmu_lsu_dtlb_expt_match0 = u_dut.u_mmu_l1dtlb.expt_match0;
  assign lsu_if_inst.mmu_lsu_dtlb_expt_match1 = u_dut.u_mmu_l1dtlb.expt_match1;

  //=========================================================================
  // UVM Config DB — Publish Virtual Interfaces
  //=========================================================================
  initial begin
    // 7 virtual interfaces
    uvm_config_db #(virtual ifu_if)::set(
      null, "*", "IFU_VIF", ifu_if_inst);
    uvm_config_db #(virtual lsu_if)::set(
      null, "*", "LSU_VIF", lsu_if_inst);
    uvm_config_db #(virtual cp0_if)::set(
      null, "*", "CP0_VIF", cp0_if_inst);
    uvm_config_db #(virtual ptw_mem_if)::set(
      null, "*", "PTW_MEM_VIF", ptw_mem_if_inst);
    uvm_config_db #(virtual pmp_if)::set(
      null, "*", "PMP_VIF", pmp_if_inst);
    uvm_config_db #(virtual sysmap_cfg_if)::set(
      null, "*", "SYSMAP_CFG_VIF", sysmap_cfg_if_inst);
    uvm_config_db #(virtual misc_if)::set(
      null, "*", "MISC_VIF", misc_if_inst);
    uvm_config_db #(virtual mmu_dut_probes_if)::set(
      null, "*", "MMU_DUT_PROBES_VIF", dut_probes_if);

    // Default simulation timeout (overridable by test)
    uvm_config_db #(int)::set(null, "*", "timeout", 100_000);

    run_test();
  end

endmodule : tb_top

// Phase 7: SVA bind — 工程师 A 完整实现（iplru/dplru 子模块，非 mmu_l1itlb 口直连）
// 参考: MMU_UVM_BuildPlan_v3 §9.2, TaskDivision Phase 7
bind ct_mmu_top   mmu_sva             u_mmu_sva   (.*);
bind mmu_arb      mmu_arb_sva         u_arb_sva   (.*);
bind mmu_l2tlb    mmu_l2tlb_rrpv_sva  u_l2tlb_sva (.*);
bind mmu_l2tlb_reqq credit_sva       u_reqq_sva  (.*);
bind twu          mmu_twu_sva         u_twu_sva   (.*);
bind twu          mmu_maee_twu_sva    u_maee_twu_sva (.*);
bind twu          mmu_pmp_twu_sva     u_pmp_twu_sva (.*);
bind twu          mmu_sysmap_sva      u_sysmap_sva (.*);
bind ptw_mbuf     mmu_ptw_lsu_protocol_sva u_ptw_lsu_protocol_sva (.*);
bind ct_mmu_iplru mmu_plru_sva        u_iplru_sva (.*);
bind ct_mmu_dplru mmu_dplru_sva       u_dplru_sva (.*);
