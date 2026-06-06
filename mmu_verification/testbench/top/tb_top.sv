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
  import l2tlb_negative_pkg::*;

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
  l2tlb_negative_inject_if l2tlb_neg_inject_if_inst (.clk_i(forever_cpuclk), .rst_ni(cpurst_b));
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
    .mmu_cp0_lsu_oper_flop    (cp0_if_inst.mmu_cp0_lsu_oper_flop),
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
    .pmp_regs_update          (1'b0),
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
  assign dut_probes_if.l1d_entry_vld     = u_dut.u_mmu_l1dtlb.entry_vld;
  assign dut_probes_if.l1d_entry_vpn     = u_dut.u_mmu_l1dtlb.l1dtlb_ent_vpn;
  assign dut_probes_if.l1d_entry_ppn     = u_dut.u_mmu_l1dtlb.l1dtlb_ent_ppn;
  assign dut_probes_if.l1d_entry_pgs     = u_dut.u_mmu_l1dtlb.l1dtlb_ent_pgs;
  assign dut_probes_if.l1d_entry_flg     = u_dut.u_mmu_l1dtlb.l1dtlb_ent_flg;
  assign dut_probes_if.l1d_entry_clr     = u_dut.u_mmu_l1dtlb.l1dtlb_entry_clr;
  assign dut_probes_if.l1d_mb_state      = u_dut.u_mmu_l1dtlb.mb_entry_state;
  assign dut_probes_if.l1d_mb_vpn        = u_dut.u_mmu_l1dtlb.mb_entry_vpn;
  assign dut_probes_if.l1d_mb_ppn        = u_dut.u_mmu_l1dtlb.mb_entry_ppn;
  assign dut_probes_if.l1d_mb_pgs        = u_dut.u_mmu_l1dtlb.mb_entry_pgs;
  assign dut_probes_if.l1d_mb_flg        = u_dut.u_mmu_l1dtlb.mb_entry_flg;
  assign dut_probes_if.l1d_mb_iid        = u_dut.u_mmu_l1dtlb.mb_entry_iid;
  assign dut_probes_if.l1d_mb_issued     = u_dut.u_mmu_l1dtlb.mb_entry_issued;
  assign dut_probes_if.l1d_mb_ready      = u_dut.u_mmu_l1dtlb.mb_entry_ready;
  assign dut_probes_if.l1d_mb_wfc        = u_dut.u_mmu_l1dtlb.mb_entry_wfc;
  assign dut_probes_if.l1d_mb_wfi        = u_dut.u_mmu_l1dtlb.mb_entry_wfi;
  assign dut_probes_if.l1d_mb_store      = u_dut.u_mmu_l1dtlb.mb_entry_store;
  assign dut_probes_if.l1d_sched_credit_cnt = u_dut.u_mmu_l1dtlb.x_scheduler.credit_cnt;
  assign dut_probes_if.l1d_l2_credit_ret = u_dut.l2tlb_dutlb_credit_return;
  assign dut_probes_if.l1d_l2_req_vld    = u_dut.u_mmu_l1dtlb.dutlb_l2tlb_req_vld;
  assign dut_probes_if.l1d_l2_req_vpn    = u_dut.u_mmu_l1dtlb.dutlb_l2tlb_req_vpn;
  assign dut_probes_if.l1d_l2_req_eid    = u_dut.u_mmu_l1dtlb.dutlb_l2tlb_req_eid;
  assign dut_probes_if.l1d_l2_req_is_load = u_dut.u_mmu_l1dtlb.dutlb_l2tlb_req_is_load;
  assign dut_probes_if.l1d_p0_req_vpn    = u_dut.u_mmu_l1dtlb.utlb_req_vpn0;
  assign dut_probes_if.l1d_p0_addr_hit   = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_addr_hit;
  assign dut_probes_if.l1d_p0_hit_vld    = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_hit_vld;
  assign dut_probes_if.l1d_p0_miss_vld   = u_dut.u_mmu_l1dtlb.dutlb_miss_vld0;
  assign dut_probes_if.l1d_p0_mb_hit     = u_dut.u_mmu_l1dtlb.mb_hit0;
  assign dut_probes_if.l1d_p0_pre_sel    = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_pre_sel;
  assign dut_probes_if.l1d_p0_expt_match = u_dut.u_mmu_l1dtlb.expt_match0;
  assign dut_probes_if.l1d_p0_entry_pa   = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_entry_pa;
  assign dut_probes_if.l1d_p0_off_pa     = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_off_pa;
  assign dut_probes_if.l1d_p0_fin_pa     = u_dut.u_mmu_l1dtlb.x_hit_rd_port0.dutlb_fin_pa;
  assign dut_probes_if.l1d_p1_req_vpn    = u_dut.u_mmu_l1dtlb.utlb_req_vpn1;
  assign dut_probes_if.l1d_p1_addr_hit   = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_addr_hit;
  assign dut_probes_if.l1d_p1_hit_vld    = u_dut.u_mmu_l1dtlb.x_hit_rd_port1.dutlb_hit_vld;
  assign dut_probes_if.l1d_p1_miss_vld   = u_dut.u_mmu_l1dtlb.dutlb_miss_vld1;
  assign dut_probes_if.l1d_p1_mb_hit     = u_dut.u_mmu_l1dtlb.mb_hit1;
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
  assign dut_probes_if.l1d_refill_flg    = u_dut.u_mmu_l1dtlb.utlb_refill_flg;
  assign dut_probes_if.l1d_entry_upd     = u_dut.u_mmu_l1dtlb.entry_upd;
  assign dut_probes_if.l1d_refill_gnt_bus = u_dut.u_mmu_l1dtlb.refill_gnt_bus;
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
  assign dut_probes_if.l1d_ptw_ref_pavld = u_dut.ptw_l1dtlb_ref_pa_vld;
  assign dut_probes_if.l1d_ptw_ref_cmplt = u_dut.ptw_l1dtlb_cmplt;
  assign dut_probes_if.l1d_ptw_ref_id    = u_dut.ptw_l1dtlb_id[2:0];
  assign dut_probes_if.l1d_ptw_ref_vpn   = u_dut.ptw_l1dtlb_ref_vpn;
  assign dut_probes_if.l1d_ptw_ref_ppn   = u_dut.ptw_l1dtlb_ref_ppn;
  assign dut_probes_if.l1d_ptw_ref_flg   = u_dut.ptw_l1dtlb_ref_flg;
  assign dut_probes_if.l1d_ptw_ref_pgs   = u_dut.ptw_l1dtlb_ref_pgs;
  assign dut_probes_if.l1d_ptw_ref_pgflt = u_dut.ptw_l1dtlb_pgflt;
  assign dut_probes_if.l1d_ptw_ref_acflt = u_dut.ptw_l1dtlb_ref_acc_err;
  assign dut_probes_if.l1d_l2_ref_pavld  = u_dut.l2tlb_l1dtlb_ref_pavld;
  assign dut_probes_if.l1d_l2_ref_cmplt  = u_dut.l2tlb_l1dtlb_ref_cmplt;
  assign dut_probes_if.l1d_l2_ref_eid    = u_dut.l2tlb_l1dtlb_ref_eid;
  assign dut_probes_if.l1d_l2_ref_vpn    = u_dut.l2tlb_l1tlb_ref_vpn;
  assign dut_probes_if.l1d_l2_ref_ppn    = u_dut.l2tlb_l1tlb_ref_ppn;
  assign dut_probes_if.l1d_l2_ref_flg    = u_dut.l2tlb_l1tlb_ref_flg;
  assign dut_probes_if.l1d_l2_ref_pgs    = u_dut.l2tlb_l1tlb_ref_pgs;
  assign dut_probes_if.l1d_l2_ref_pgflt  = u_dut.l2tlb_l1dtlb_pgflt;
  assign dut_probes_if.l1d_install_req_ptw = u_dut.u_mmu_l1dtlb.x_install.req_ptw_vld;
  assign dut_probes_if.l1d_install_req_l2  = u_dut.u_mmu_l1dtlb.x_install.req_jtlb_vld;
  assign dut_probes_if.l1d_install_req_wfi = u_dut.u_mmu_l1dtlb.x_install.req_wfi_vld;
  assign dut_probes_if.l1d_install_sel_ptw = u_dut.u_mmu_l1dtlb.x_install.sel_ptw;
  assign dut_probes_if.l1d_install_sel_l2  = u_dut.u_mmu_l1dtlb.x_install.sel_jtlb;
  assign dut_probes_if.l1d_install_sel_wfi = u_dut.u_mmu_l1dtlb.x_install.sel_wfi;
  assign dut_probes_if.l1d_install_id_ptw  = u_dut.u_mmu_l1dtlb.x_install.id_ptw;
  assign dut_probes_if.l1d_install_id_l2   = u_dut.u_mmu_l1dtlb.x_install.id_jtlb;
  assign dut_probes_if.l1d_install_id_wfi  = u_dut.u_mmu_l1dtlb.x_install.id_wfi;
  assign dut_probes_if.l1d_expt_wr0_vld   = u_dut.u_mmu_l1dtlb.expt_wr0_vld;
  assign dut_probes_if.l1d_expt_wr0_eid   = u_dut.u_mmu_l1dtlb.expt_wr0_eid;
  assign dut_probes_if.l1d_expt_wr0_iid   = u_dut.u_mmu_l1dtlb.expt_wr0_iid;
  assign dut_probes_if.l1d_expt_wr0_vpn   = u_dut.u_mmu_l1dtlb.expt_wr0_vpn;
  assign dut_probes_if.l1d_expt_wr0_pgflt = u_dut.u_mmu_l1dtlb.expt_wr0_pgflt;
  assign dut_probes_if.l1d_expt_wr0_acflt = u_dut.u_mmu_l1dtlb.expt_wr0_acflt;
  assign dut_probes_if.l1d_expt_wr1_vld   = u_dut.u_mmu_l1dtlb.expt_wr1_vld;
  assign dut_probes_if.l1d_expt_wr1_eid   = u_dut.u_mmu_l1dtlb.expt_wr1_eid;
  assign dut_probes_if.l1d_expt_wr1_iid   = u_dut.u_mmu_l1dtlb.expt_wr1_iid;
  assign dut_probes_if.l1d_expt_wr1_vpn   = u_dut.u_mmu_l1dtlb.expt_wr1_vpn;
  assign dut_probes_if.l1d_expt_wr1_pgflt = u_dut.u_mmu_l1dtlb.expt_wr1_pgflt;
  assign dut_probes_if.l1d_expt_wr1_acflt = u_dut.u_mmu_l1dtlb.expt_wr1_acflt;
  assign dut_probes_if.l1d_expt_pgflt0    = u_dut.u_mmu_l1dtlb.expt_pgflt0;
  assign dut_probes_if.l1d_expt_acflt0    = u_dut.u_mmu_l1dtlb.expt_acflt0;
  assign dut_probes_if.l1d_expt_pgflt1    = u_dut.u_mmu_l1dtlb.expt_pgflt1;
  assign dut_probes_if.l1d_expt_acflt1    = u_dut.u_mmu_l1dtlb.expt_acflt1;
  assign dut_probes_if.l1d_expt_hit_vec   = u_dut.u_mmu_l1dtlb.expt_hit_vec;
  assign dut_probes_if.l1d_expt_wakeup    = u_dut.u_mmu_l1dtlb.expt_wakeup;
  assign dut_probes_if.l1d_expt_clear_req = misc_if_inst.rtu_yy_xx_flush
                                          | u_dut.tlboper_utlb_clr
                                          | u_dut.tlboper_utlb_inv_va_req;
  assign dut_probes_if.l1d_cp0_maee       = u_dut.cp0_mmu_maee;
  assign dut_probes_if.l1d_cp0_mpp        = u_dut.cp0_mmu_mpp;
  assign dut_probes_if.l1d_cp0_mprv       = u_dut.cp0_mmu_mprv;
  assign dut_probes_if.l1d_cp0_mxr        = u_dut.cp0_mmu_mxr;
  assign dut_probes_if.l1d_cp0_sum        = u_dut.cp0_mmu_sum;
  assign dut_probes_if.l1d_cp0_priv_mode  = u_dut.cp0_yy_priv_mode;
  assign dut_probes_if.l1d_regs_cur_asid  = u_dut.regs_ptw_cur_asid;
  assign dut_probes_if.l1d_regs_satp_ppn  = u_dut.regs_ptw_satp_ppn;
  assign dut_probes_if.l1d_pmp_flg0       = pmp_if_inst.pmp_mmu_flg0;
  assign dut_probes_if.l1d_pmp_flg1       = pmp_if_inst.pmp_mmu_flg1;
  assign dut_probes_if.l1d_sysmap_flg0    = u_dut.sysmap_mmu_flg0;
  assign dut_probes_if.l1d_sysmap_flg1    = u_dut.sysmap_mmu_flg1;
  assign dut_probes_if.l1d_sysmap_hit0    = u_dut.sysmap_mmu_hit0;
  assign dut_probes_if.l1d_sysmap_hit1    = u_dut.sysmap_mmu_hit1;
  assign dut_probes_if.l1d_sysmap_pa0     = u_dut.mmu_sysmap_pa0;
  assign dut_probes_if.l1d_sysmap_pa1     = u_dut.mmu_sysmap_pa1;
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
  // RRPV exact model observation signals
  assign dut_probes_if.l2_arb_req         = u_dut.x_mmu_l2tlb.arb_l2tlb_req;
  assign dut_probes_if.l2_arb_write       = u_dut.x_mmu_l2tlb.arb_l2tlb_write;
  assign dut_probes_if.l2_arb_acc_type    = u_dut.x_mmu_l2tlb.arb_l2tlb_acc_type;
  assign dut_probes_if.l2_arb_bank_sel    = u_dut.x_mmu_l2tlb.arb_l2tlb_bank_sel;
  assign dut_probes_if.l2_arb_idx_w0      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w0;
  assign dut_probes_if.l2_arb_idx_w1      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w1;
  assign dut_probes_if.l2_arb_idx_w2      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w2;
  assign dut_probes_if.l2_arb_idx_w3      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w3;
  assign dut_probes_if.l2_arb_idx_w4      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w4;
  assign dut_probes_if.l2_arb_idx_w5      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w5;
  assign dut_probes_if.l2_arb_idx_w6      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w6;
  assign dut_probes_if.l2_arb_idx_w7      = u_dut.x_mmu_l2tlb.arb_l2tlb_idx_w7;
  assign dut_probes_if.l2_arb_rrpv_din    = u_dut.x_mmu_l2tlb.arb_l2tlb_rrpv_din;
  assign dut_probes_if.l2_arb_tag_din     = u_dut.x_mmu_l2tlb.arb_l2tlb_tag_din;
  assign dut_probes_if.l2_raw_vld         = u_dut.x_mmu_l2tlb.raw_vld;
  assign dut_probes_if.l2_raw_way_mask    = u_dut.x_mmu_l2tlb.raw_way_mask;
  assign dut_probes_if.l2_raw_way_vld     = u_dut.x_mmu_l2tlb.raw_way_vld;
  assign dut_probes_if.l2_rrpv_dout_bus   = u_dut.x_mmu_l2tlb.l2tlb_rrpv_dout_bus;
  assign dut_probes_if.l2_wbuf_cam_hit    = u_dut.x_mmu_l2tlb.wbuf_cam_hit;
  assign dut_probes_if.l2_bypassed_rrpv_rdata = u_dut.x_mmu_l2tlb.bypassed_rrpv_rdata;
  assign dut_probes_if.l2_final_pa_vld    = u_dut.x_mmu_l2tlb.final_pa_vld;
  assign dut_probes_if.l2_final_way_sel   = u_dut.x_mmu_l2tlb.final_way_sel;
  assign dut_probes_if.l2_final_acc_type  = u_dut.x_mmu_l2tlb.final_acc_type;
  assign dut_probes_if.l2_final_bank_index = u_dut.x_mmu_l2tlb.final_bank_index;
  assign dut_probes_if.l2_final_way_vld   = u_dut.x_mmu_l2tlb.final_way_vld;
  assign dut_probes_if.l2_victim_way      = u_dut.x_mmu_l2tlb.victim_way;
  assign dut_probes_if.l2_rrpv_updata     = u_dut.x_mmu_l2tlb.rrpv_updata;
  assign dut_probes_if.l2_wbuf_push_req   = u_dut.x_mmu_l2tlb.wbuf_push_req;
  assign dut_probes_if.l2_wbuf_pop_grant  = u_dut.x_mmu_l2tlb.wbuf_pop_grant;
  assign dut_probes_if.l2_wbuf_empty      = u_dut.x_mmu_l2tlb.wbuf_empty;
  assign dut_probes_if.l2_reqq_vld_vec  = u_dut.x_mmu_l2tlb.x_l2tlb_reqq.entry_vld_vec;
  assign dut_probes_if.l2_reqq_rdy_vec  = u_dut.x_mmu_l2tlb.x_l2tlb_reqq.entry_rdy_vec;
  assign dut_probes_if.l2_reqq_qid      = u_dut.x_mmu_l2tlb.x_l2tlb_reqq.issue_queue_id;
  assign dut_probes_if.l2_reqq_issue_valid = u_dut.x_mmu_l2tlb.queue_arb_req;
  assign dut_probes_if.l2_reqq_issue_type = u_dut.x_mmu_l2tlb.queue_arb_acc_type;
  assign dut_probes_if.l2mb_vld_vec      = u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_vld_vec;
  assign dut_probes_if.l2mb_rdy_vec      = u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_rdy_vec;
  assign dut_probes_if.l2mb_issue_req    = u_dut.x_mmu_l2tlb.x_l2tlb_mb.issue_req;
  assign dut_probes_if.l2mb_issue_eid    = u_dut.x_mmu_l2tlb.x_l2tlb_mb.issue_eid;
  assign dut_probes_if.l2mb_issue_type   = u_dut.x_mmu_l2tlb.x_l2tlb_mb.issue_type;
  assign dut_probes_if.l2mb_alloc_valid  = u_dut.x_mmu_l2tlb.mb_alloc_valid;
  genvar tb_l2mb_i;
  generate
    for (tb_l2mb_i = 0; tb_l2mb_i < 9; tb_l2mb_i++) begin : gen_l2mb_probe_assign
      assign dut_probes_if.l2mb_entry_vpn[tb_l2mb_i] =
          u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_out_vpn[tb_l2mb_i];
      assign dut_probes_if.l2mb_entry_l1eid[tb_l2mb_i] =
          u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_out_l1eid[tb_l2mb_i];
      assign dut_probes_if.l2mb_entry_type[tb_l2mb_i] =
          u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_out_type[tb_l2mb_i];
      assign dut_probes_if.l2mb_entry_queue_id[tb_l2mb_i] =
          u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_out_queue_id[tb_l2mb_i];
      assign dut_probes_if.l2mb_entry_sent[tb_l2mb_i] =
          u_dut.x_mmu_l2tlb.x_l2tlb_mb.gen_entries[tb_l2mb_i].x_mb_entry.r_sent;
    end
  endgenerate
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
  assign dut_probes_if.l2tlb_ptw_id       = u_dut.l2tlb_ptw_id;
  assign dut_probes_if.l2tlb_ptw_type     = u_dut.l2tlb_ptw_type;
  assign dut_probes_if.l2tlb_ptw_vpn      = u_dut.l2tlb_ptw_vpn;
  assign dut_probes_if.ptw_l2tlb_cmplt    = u_dut.ptw_l2tlb_cmplt;
  assign dut_probes_if.ptw_l2tlb_ref_data_vld = u_dut.ptw_l2tlb_ref_data_vld;
  assign dut_probes_if.ptw_l2tlb_id       = u_dut.ptw_l2tlb_id;
  assign dut_probes_if.ptw_l2tlb_type     = u_dut.ptw_l2tlb_type;
  assign dut_probes_if.ptw_l2tlb_flg      = u_dut.ptw_l2tlb_flg;
  assign dut_probes_if.ptw_l1i_ref_cmplt  = u_dut.ptw_l1itlb_cmplt;
  assign dut_probes_if.ptw_lsu_data_req   = u_dut.mmu_lsu_data_req;
  assign dut_probes_if.ptw_lsu_data_req_addr = u_dut.mmu_lsu_data_req_addr;
  assign dut_probes_if.ptw_lsu_data_req_size = u_dut.mmu_lsu_data_req_size;
  assign dut_probes_if.ptw_lsu_data_req_grant = u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant;
  assign dut_probes_if.ptw_lsu_data_vld   = ptw_mem_if_inst.lsu_mmu_data_vld;
  assign dut_probes_if.ptw_lsu_bus_error  = ptw_mem_if_inst.lsu_mmu_bus_error;
  assign dut_probes_if.ptw_lsu_data       = ptw_mem_if_inst.lsu_mmu_data;
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
  assign dut_probes_if.ptw_arb_ref_data_din = u_dut.ptw_arb_ref_data_din;
  assign dut_probes_if.regs_ptw_cur_asid = u_dut.regs_ptw_cur_asid;
  assign dut_probes_if.regs_ptw_satp_ppn = u_dut.regs_ptw_satp_ppn;
  assign dut_probes_if.ptw_cp0_maee      = u_dut.cp0_mmu_maee;
  assign dut_probes_if.ptw_cp0_mpp       = u_dut.cp0_mmu_mpp;
  assign dut_probes_if.ptw_cp0_mprv      = u_dut.cp0_mmu_mprv;
  assign dut_probes_if.ptw_cp0_mxr       = u_dut.cp0_mmu_mxr;
  assign dut_probes_if.ptw_cp0_sum       = u_dut.cp0_mmu_sum;
  assign dut_probes_if.ptw_cp0_priv_mode = u_dut.cp0_yy_priv_mode;
  assign dut_probes_if.tlboper_ptw_abort = u_dut.tlboper_ptw_abort;
  assign dut_probes_if.ptw_abort_flop    = u_dut.x_ct_mmu_ptw.abort_flop;
  assign dut_probes_if.ptw_mbuf_twu_vpn  = u_dut.x_ct_mmu_ptw.mbuf_twu_vpn;
  assign dut_probes_if.ptw_mbuf_twu_type = u_dut.x_ct_mmu_ptw.mbuf_twu_type;
  assign dut_probes_if.ptw_mbuf_twu_id   = u_dut.x_ct_mmu_ptw.mbuf_twu_id;
  assign dut_probes_if.ptw_mbuf_twu_lvl_vec = u_dut.x_ct_mmu_ptw.mbuf_twu_lvl;
  assign dut_probes_if.ptw_mbuf_twu_data = u_dut.x_ct_mmu_ptw.mbuf_twu_data;
  assign dut_probes_if.ptw_mbuf_twu_data_vld = u_dut.x_ct_mmu_ptw.mbuf_twu_data_vld;
  assign dut_probes_if.ptw_twu_mbuf_req  = u_dut.x_ct_mmu_ptw.twu_mbuf_req;
  assign dut_probes_if.ptw_twu_mbuf_paddr = u_dut.x_ct_mmu_ptw.twu_mbuf_paddr;
  assign dut_probes_if.ptw_twu_mbuf_vpn  = u_dut.x_ct_mmu_ptw.twu_mbuf_vpn;
  assign dut_probes_if.ptw_twu_mbuf_type = u_dut.x_ct_mmu_ptw.twu_mbuf_type;
  assign dut_probes_if.ptw_twu_mbuf_id   = u_dut.x_ct_mmu_ptw.twu_mbuf_id;
  assign dut_probes_if.ptw_twu_mbuf_lvl  = u_dut.x_ct_mmu_ptw.twu_mbuf_lvl;
  assign dut_probes_if.ptw_twu_mbuf_pmpflg = u_dut.x_ct_mmu_ptw.twu_mbuf_pmpflg;
  assign dut_probes_if.ptw_mbuf_twu_pmpflg = u_dut.x_ct_mmu_ptw.mbuf_twu_pmpflg;
  assign dut_probes_if.ptw_mbuf_entry_pmpflg = u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_pmpflg;
  assign dut_probes_if.pde_cache_req     = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_req;
  assign dut_probes_if.pde_cache_ready   = u_dut.x_ct_mmu_ptw.u_PDE_cache.pde_cache_ready;
  assign dut_probes_if.pde_cache_clear   = u_dut.x_ct_mmu_ptw.u_PDE_cache.pde_cache_clear;
  assign dut_probes_if.pde_l1_hit_vld    = u_dut.x_ct_mmu_ptw.u_PDE_cache.L1PDE_xbar_hit_vld;
  assign dut_probes_if.pde_l2_hit_vld    = u_dut.x_ct_mmu_ptw.u_PDE_cache.L2PDE_xbar_hit_vld;
  assign dut_probes_if.pde_xbar_ppn      = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_ppn;
  assign dut_probes_if.pde_xbar_vpn      = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_vpn;
  assign dut_probes_if.pde_xbar_type     = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_type;
  assign dut_probes_if.pde_xbar_id       = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_id;
  assign dut_probes_if.pde_cache_update  = u_dut.x_ct_mmu_ptw.mbuf_cache_upd;
  assign dut_probes_if.pde_cache_update_level = u_dut.x_ct_mmu_ptw.mbuf_cache_upd_lvl;
  assign dut_probes_if.pde_cache_update_ppn = u_dut.x_ct_mmu_ptw.mbuf_cache_upd_ppn;
  assign dut_probes_if.pde_cache_update_vpn = u_dut.x_ct_mmu_ptw.mbuf_cache_upd_vpn;
  assign dut_probes_if.pde_cache_update_l1pmpflg = u_dut.x_ct_mmu_ptw.mbuf_cache_upd_l1pmpflg;
  assign dut_probes_if.pde_cache_update_l2pmpflg = u_dut.x_ct_mmu_ptw.mbuf_cache_upd_l2pmpflg;
  assign dut_probes_if.pde_l1_update_vec = u_dut.x_ct_mmu_ptw.u_PDE_cache.L1PDE_entry_upd;
  assign dut_probes_if.pde_l2_update_vec = u_dut.x_ct_mmu_ptw.u_PDE_cache.L2PDE_entry_upd;
  assign dut_probes_if.pde_cache_acc_err_vld = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_cache_acc_err_vld;
  assign dut_probes_if.pde_cache_acc_err_type = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_cache_acc_err_type;
  assign dut_probes_if.pde_cache_acc_err_id = u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_cache_acc_err_id;
  assign dut_probes_if.pde_cache_acc_err_grant = u_dut.x_ct_mmu_ptw.acc_err_twu_grant[5];
  assign dut_probes_if.pde_l2_entry_acc_err_vec = u_dut.x_ct_mmu_ptw.u_PDE_cache.L2PDE_entry_acc_err;
  assign dut_probes_if.ptw_acc_err_grant_vec = u_dut.x_ct_mmu_ptw.acc_err_twu_grant;
  genvar tb_pde_i;
  generate
    for (tb_pde_i = 0; tb_pde_i < 16; tb_pde_i++) begin : gen_pde_pmp_probe_assign
      assign dut_probes_if.pde_l1_tag_hit_vec[tb_pde_i] =
          u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_ent[tb_pde_i].u_L1PDE_cache.L1PDE_vld
        & (u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_vpn[26:18]
           == u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_ent[tb_pde_i].u_L1PDE_cache.L1PDE_tag);
      assign dut_probes_if.pde_l2_tag_hit_vec[tb_pde_i] =
          u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_ent[tb_pde_i].u_L2PDE_cache.L2PDE_vld
        & (u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_xbar_vpn[26:9]
           == u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_ent[tb_pde_i].u_L2PDE_cache.L2PDE_tag);
      assign dut_probes_if.pde_l1_cached_l1pmpflg_vec[tb_pde_i] =
          u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_ent[tb_pde_i].u_L1PDE_cache.L1PDE_l1pmpflg;
      assign dut_probes_if.pde_l2_cached_l1pmpflg_vec[tb_pde_i] =
          u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_ent[tb_pde_i].u_L2PDE_cache.L2PDE_l1pmpflg;
      assign dut_probes_if.pde_l2_cached_l2pmpflg_vec[tb_pde_i] =
          u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_ent[tb_pde_i].u_L2PDE_cache.L2PDE_l2pmpflg;
    end
  endgenerate
  assign dut_probes_if.pmp_regs_update_probe = 1'b0;
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

  //=========================================================================
  // Phase6G L2TLB negative injector
  //=========================================================================
  logic [63:0] l2tlb_neg_satp_force_value;
  longint unsigned l2tlb_neg_diag_cycle;
  longint unsigned l2tlb_neg_diag_until_cycle = 0;
  logic [7:0]      l2tlb_neg_diag_l1d_mb_vld_q;
  logic [2:0]      l2tlb_neg_diag_l1d_mb_st0_q;
  logic [8:0]      l2tlb_neg_diag_l2_reqq_vld_q;
  logic [8:0]      l2tlb_neg_diag_l2mb_vld_q;

  task automatic l2tlb_neg_diag_print(input string tag);
    $display("[L2TLB_NEG_DIAG] tag=\"%s\" cyc=%0d t=%0t ctrl={satp_sel:%0b regs_clr:%0b tlboper_clr:%0b inv:%0b flush:%0b ptw_en:%0b satp:0x%016h} l1d_mb={vld:0x%02h st0:%0d rdy0:%0b issued0:%0b wfc0:%0b wfi0:%0b iid0:0x%02h vpn0:0x%07h} refs={ptw_cmplt:%0b ptw_pavld:%0b ptw_id:%0d ptw_pg:%0b ptw_ac:%0b l2_cmplt:%0b l2_pavld:%0b l2_id:%0d l2_pg:%0b} install={req_ptw:%0b req_l2:%0b req_wfi:%0b sel_ptw:%0b sel_l2:%0b sel_wfi:%0b id_ptw:%0d id_l2:%0d id_wfi:%0d refill_vld:%0b refill_src:%0d refill_idx:%0d refill_vpn:0x%07h refill_iid:%0d gnt:0x%02h entry_upd:0x%04h wakeup:0x%03h busy:%0b} l2={reqq:0x%03h rdy:0x%03h qid:0x%0h issue:%0b/type:0x%0h mb:0x%03h mb_rdy:0x%03h mb_issue:%0b/eid:0x%02h/type:0x%0h ptw_req:%0b/id:0x%02h/type:0x%0h ptw_ready:%0b}",
      tag,
      l2tlb_neg_diag_cycle,
      $time,
      cp0_if_inst.cp0_mmu_satp_sel,
      u_dut.regs_utlb_clr,
      dut_probes_if.tlboper_utlb_clr,
      dut_probes_if.tlboper_utlb_inv_va_req,
      misc_if_inst.rtu_yy_xx_flush,
      cp0_if_inst.cp0_mmu_ptw_en,
      cp0_if_inst.mmu_cp0_satp_data,
      dut_probes_if.l1d_mb_vld,
      dut_probes_if.l1d_mb_state[0],
      dut_probes_if.l1d_mb_ready[0],
      dut_probes_if.l1d_mb_issued[0],
      dut_probes_if.l1d_mb_wfc[0],
      dut_probes_if.l1d_mb_wfi[0],
      dut_probes_if.l1d_mb_iid[0],
      dut_probes_if.l1d_mb_vpn[0],
      dut_probes_if.l1d_ptw_ref_cmplt,
      dut_probes_if.l1d_ptw_ref_pavld,
      dut_probes_if.l1d_ptw_ref_id,
      dut_probes_if.l1d_ptw_ref_pgflt,
      dut_probes_if.l1d_ptw_ref_acflt,
      dut_probes_if.l1d_l2_ref_cmplt,
      dut_probes_if.l1d_l2_ref_pavld,
      dut_probes_if.l1d_l2_ref_eid,
      dut_probes_if.l1d_l2_ref_pgflt,
      dut_probes_if.l1d_install_req_ptw,
      dut_probes_if.l1d_install_req_l2,
      dut_probes_if.l1d_install_req_wfi,
      dut_probes_if.l1d_install_sel_ptw,
      dut_probes_if.l1d_install_sel_l2,
      dut_probes_if.l1d_install_sel_wfi,
      dut_probes_if.l1d_install_id_ptw,
      dut_probes_if.l1d_install_id_l2,
      dut_probes_if.l1d_install_id_wfi,
      dut_probes_if.l1d_refill_vld,
      dut_probes_if.l1d_refill_src,
      dut_probes_if.l1d_refill_idx,
      dut_probes_if.l1d_refill_vpn,
      dut_probes_if.l1d_refill_iid_sel,
      dut_probes_if.l1d_refill_gnt_bus,
      dut_probes_if.l1d_entry_upd,
      lsu_if_inst.mmu_lsu_tlb_wakeup,
      lsu_if_inst.mmu_lsu_tlb_busy,
      dut_probes_if.l2_reqq_vld_vec,
      dut_probes_if.l2_reqq_rdy_vec,
      dut_probes_if.l2_reqq_qid,
      dut_probes_if.l2_reqq_issue_valid,
      dut_probes_if.l2_reqq_issue_type,
      dut_probes_if.l2mb_vld_vec,
      dut_probes_if.l2mb_rdy_vec,
      dut_probes_if.l2mb_issue_req,
      dut_probes_if.l2mb_issue_eid,
      dut_probes_if.l2mb_issue_type,
      dut_probes_if.l2tlb_ptw_req,
      dut_probes_if.l2tlb_ptw_id,
      dut_probes_if.l2tlb_ptw_type,
      dut_probes_if.ptw_jtlb_ready);
  endtask

  function automatic bit l2tlb_neg_diag_event();
    return cp0_if_inst.cp0_mmu_satp_sel
        || u_dut.regs_utlb_clr
        || dut_probes_if.tlboper_utlb_clr
        || dut_probes_if.tlboper_utlb_inv_va_req
        || misc_if_inst.rtu_yy_xx_flush
        || dut_probes_if.l1d_ptw_ref_cmplt
        || dut_probes_if.l1d_l2_ref_cmplt
        || dut_probes_if.l1d_refill_vld
        || (dut_probes_if.l1d_refill_gnt_bus != 8'h00)
        || (lsu_if_inst.mmu_lsu_tlb_wakeup != 12'h000)
        || dut_probes_if.l1d_install_req_ptw
        || dut_probes_if.l1d_install_req_l2
        || dut_probes_if.l1d_install_req_wfi
        || dut_probes_if.l1d_install_sel_ptw
        || dut_probes_if.l1d_install_sel_l2
        || dut_probes_if.l1d_install_sel_wfi
        || (dut_probes_if.l1d_mb_vld !== l2tlb_neg_diag_l1d_mb_vld_q)
        || (dut_probes_if.l1d_mb_state[0] !== l2tlb_neg_diag_l1d_mb_st0_q)
        || (dut_probes_if.l2_reqq_vld_vec !== l2tlb_neg_diag_l2_reqq_vld_q)
        || (dut_probes_if.l2mb_vld_vec !== l2tlb_neg_diag_l2mb_vld_q);
  endfunction

  always @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l2tlb_neg_diag_cycle <= 0;
      l2tlb_neg_diag_l1d_mb_vld_q <= '0;
      l2tlb_neg_diag_l1d_mb_st0_q <= '0;
      l2tlb_neg_diag_l2_reqq_vld_q <= '0;
      l2tlb_neg_diag_l2mb_vld_q <= '0;
    end else begin
      l2tlb_neg_diag_cycle <= l2tlb_neg_diag_cycle + 1;
      if (l2tlb_neg_diag_cycle < l2tlb_neg_diag_until_cycle) begin
        if (l2tlb_neg_diag_event() || (l2tlb_neg_diag_cycle[4:0] == 5'd0))
          l2tlb_neg_diag_print("watch");
      end
      l2tlb_neg_diag_l1d_mb_vld_q <= dut_probes_if.l1d_mb_vld;
      l2tlb_neg_diag_l1d_mb_st0_q <= dut_probes_if.l1d_mb_state[0];
      l2tlb_neg_diag_l2_reqq_vld_q <= dut_probes_if.l2_reqq_vld_vec;
      l2tlb_neg_diag_l2mb_vld_q <= dut_probes_if.l2mb_vld_vec;
    end
  end

  task automatic l2tlb_neg_finish(
    input bit trigger_seen,
    input bit checker_seen,
    input string msg
  );
    $display("[L2TLB_NEG_EXPECTED_CLASS] test_case=\"%s\" class=\"%s\" related_ids=\"%s\" trigger=%0b checker=%0b msg=\"%s\"",
      l2tlb_neg_inject_if_inst.case_name,
      l2tlb_neg_inject_if_inst.expected_class,
      l2tlb_neg_inject_if_inst.related_ids,
      trigger_seen,
      checker_seen,
      msg);
    repeat (2) @(posedge forever_cpuclk);
    l2tlb_neg_inject_if_inst.complete(trigger_seen, checker_seen, msg);
  endtask

  task automatic l2tlb_neg_force_ptw_completion();
    bit illegal_combo;
    bit no_outstanding;
    bit bad_identity;
    logic [8:0] mb_vld_snapshot;
    logic [2:0] req_type_snapshot;
    logic [6:0] req_id_snapshot;

    @(posedge forever_cpuclk);
    mb_vld_snapshot = u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_vld_vec;
    req_type_snapshot = u_dut.l2tlb_ptw_type;
    req_id_snapshot = u_dut.l2tlb_ptw_id;
    $display("[L2TLB_NEG_INJECTOR] case=\"%s\" kind=%0d enabled_by_test=1 id=0x%02h type=0x%0h data_vld=%0b pgflt=%0b acc_err=%0b hold_cycles=%0d mb_vld_before=0x%03h l2_req=%0b l2_req_id=0x%02h l2_req_type=0x%0h",
      l2tlb_neg_inject_if_inst.case_name,
      l2tlb_neg_inject_if_inst.kind,
      l2tlb_neg_inject_if_inst.ptw_id,
      l2tlb_neg_inject_if_inst.ptw_type,
      l2tlb_neg_inject_if_inst.data_vld,
      l2tlb_neg_inject_if_inst.pgflt,
      l2tlb_neg_inject_if_inst.acc_err,
      l2tlb_neg_inject_if_inst.hold_cycles,
      mb_vld_snapshot,
      u_dut.l2tlb_ptw_req,
      req_id_snapshot,
      req_type_snapshot);

    force u_dut.ptw_l2tlb_cmplt = 1'b1;
    force u_dut.ptw_l2tlb_ref_data_vld = l2tlb_neg_inject_if_inst.data_vld;
    force u_dut.ptw_l2tlb_ref_pgflt = l2tlb_neg_inject_if_inst.pgflt;
    force u_dut.ptw_l2tlb_ref_acc_err = l2tlb_neg_inject_if_inst.acc_err;
    force u_dut.ptw_l2tlb_id = l2tlb_neg_inject_if_inst.ptw_id;
    force u_dut.ptw_l2tlb_type = l2tlb_neg_inject_if_inst.ptw_type;
    force u_dut.ptw_l2tlb_flg = l2tlb_neg_inject_if_inst.flg;

    repeat (int'(l2tlb_neg_inject_if_inst.hold_cycles)) @(posedge forever_cpuclk);

    illegal_combo = (int'(l2tlb_neg_inject_if_inst.data_vld)
                    + int'(l2tlb_neg_inject_if_inst.pgflt)
                    + int'(l2tlb_neg_inject_if_inst.acc_err)) > 1;
    no_outstanding = (l2tlb_neg_inject_if_inst.kind
                      == l2tlb_negative_pkg::L2TLB_NEG_PTW_NO_OUTSTANDING)
                     && (mb_vld_snapshot == '0);
    bad_identity = (l2tlb_neg_inject_if_inst.kind
                    == l2tlb_negative_pkg::L2TLB_NEG_PTW_BAD_ID_TYPE)
                   && ((l2tlb_neg_inject_if_inst.ptw_id != req_id_snapshot)
                       || (l2tlb_neg_inject_if_inst.ptw_type != req_type_snapshot));

    $display("[L2TLB_NEG_TRIGGER] case=\"%s\" kind=%0d class=\"%s\" illegal_combo=%0b no_outstanding=%0b bad_identity=%0b id=0x%02h type=0x%0h mb_vld_before=0x%03h",
      l2tlb_neg_inject_if_inst.case_name,
      l2tlb_neg_inject_if_inst.kind,
      l2tlb_neg_inject_if_inst.expected_class,
      illegal_combo,
      no_outstanding,
      bad_identity,
      l2tlb_neg_inject_if_inst.ptw_id,
      l2tlb_neg_inject_if_inst.ptw_type,
      mb_vld_snapshot);

    release u_dut.ptw_l2tlb_cmplt;
    release u_dut.ptw_l2tlb_ref_data_vld;
    release u_dut.ptw_l2tlb_ref_pgflt;
    release u_dut.ptw_l2tlb_ref_acc_err;
    release u_dut.ptw_l2tlb_id;
    release u_dut.ptw_l2tlb_type;
    release u_dut.ptw_l2tlb_flg;

    l2tlb_neg_finish((illegal_combo || no_outstanding || bad_identity), 1'b1,
      $sformatf("ptw_negative illegal_combo=%0b no_outstanding=%0b bad_identity=%0b",
        illegal_combo, no_outstanding, bad_identity));
  endtask

  task automatic l2tlb_neg_force_control_hazard();
    bit outstanding_seen;
    bit ptw_en_snapshot;
    logic [8:0] mb_vld_snapshot;
    logic [63:0] satp_snapshot;

    repeat (1024) begin
      @(posedge forever_cpuclk);
      mb_vld_snapshot = u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_vld_vec;
      outstanding_seen = (mb_vld_snapshot != '0)
                         || u_dut.l2tlb_ptw_req
                         || u_dut.x_mmu_l2tlb.x_l2tlb_mb.issue_req;
      if (mb_vld_snapshot != '0)
        break;
    end
    mb_vld_snapshot = u_dut.x_mmu_l2tlb.x_l2tlb_mb.entry_vld_vec;
    outstanding_seen = (mb_vld_snapshot != '0)
                       || u_dut.l2tlb_ptw_req
                       || u_dut.x_mmu_l2tlb.x_l2tlb_mb.issue_req;
    ptw_en_snapshot = cp0_if_inst.cp0_mmu_ptw_en;
    satp_snapshot = cp0_if_inst.mmu_cp0_satp_data;
    l2tlb_neg_satp_force_value = satp_snapshot;
    l2tlb_neg_diag_until_cycle = l2tlb_neg_diag_cycle + 2048;
    l2tlb_neg_diag_print("control_before_force");
    $display("[L2TLB_NEG_INJECTOR] case=\"%s\" kind=%0d enabled_by_test=1 control_hazard_window=1 mb_vld_before=0x%03h l2_req=%0b issue_req=%0b ptw_en_before=%0b satp_same_value=1",
      l2tlb_neg_inject_if_inst.case_name,
      l2tlb_neg_inject_if_inst.kind,
      mb_vld_snapshot,
      u_dut.l2tlb_ptw_req,
      u_dut.x_mmu_l2tlb.x_l2tlb_mb.issue_req,
      ptw_en_snapshot);

    force cp0_if_inst.cp0_mmu_satp_sel = 1'b1;
    force cp0_if_inst.cp0_mmu_wdata = l2tlb_neg_satp_force_value;
    l2tlb_neg_diag_print("control_after_force");

    repeat (int'(l2tlb_neg_inject_if_inst.hold_cycles)) @(posedge forever_cpuclk);
    l2tlb_neg_diag_print("control_before_release");

    $display("[L2TLB_NEG_TRIGGER] case=\"%s\" kind=%0d class=\"%s\" outstanding_seen=%0b mb_vld_before=0x%03h forced_ptw_en=%0b forced_satp_sel=%0b satp_same_value=1",
      l2tlb_neg_inject_if_inst.case_name,
      l2tlb_neg_inject_if_inst.kind,
      l2tlb_neg_inject_if_inst.expected_class,
      outstanding_seen,
      mb_vld_snapshot,
      cp0_if_inst.cp0_mmu_ptw_en,
      cp0_if_inst.cp0_mmu_satp_sel);

    force cp0_if_inst.cp0_mmu_satp_sel = 1'b0;
    force cp0_if_inst.cp0_mmu_wdata = 64'h0;
    l2tlb_neg_diag_print("control_force_idle");

    release cp0_if_inst.cp0_mmu_satp_sel;
    release cp0_if_inst.cp0_mmu_wdata;
    l2tlb_neg_diag_print("control_after_release");

    l2tlb_neg_finish(outstanding_seen, 1'b1,
      $sformatf("control_hazard outstanding_seen=%0b mb_vld_before=0x%03h satp_same_value=1 ptw_en_unchanged=%0b",
        outstanding_seen, mb_vld_snapshot, ptw_en_snapshot));
  endtask

  initial begin : l2tlb_negative_injector_thread
    forever begin
      @l2tlb_neg_inject_if_inst.request_ev;
      case (l2tlb_neg_inject_if_inst.kind)
        l2tlb_negative_pkg::L2TLB_NEG_PTW_NO_OUTSTANDING,
        l2tlb_negative_pkg::L2TLB_NEG_PTW_BAD_ID_TYPE,
        l2tlb_negative_pkg::L2TLB_NEG_PTW_ILLEGAL_COMBO:
          l2tlb_neg_force_ptw_completion();
        l2tlb_negative_pkg::L2TLB_NEG_CONTROL_HAZARD:
          l2tlb_neg_force_control_hazard();
        default:
          l2tlb_neg_finish(1'b0, 1'b0, "unsupported negative injection kind");
      endcase
    end
  end
  assign dut_probes_if.p13_sysmap_flg_vec      = {u_dut.x_ct_mmu_ptw.twu_four.sysmap_mmu_flg, u_dut.x_ct_mmu_ptw.twu_three.sysmap_mmu_flg, u_dut.x_ct_mmu_ptw.twu_two.sysmap_mmu_flg, u_dut.x_ct_mmu_ptw.twu_one.sysmap_mmu_flg};
  assign dut_probes_if.p13_sysmap_hit_vec      = {u_dut.x_ct_mmu_ptw.twu_four.sysmap_mmu_hitx2, u_dut.x_ct_mmu_ptw.twu_three.sysmap_mmu_hitx2, u_dut.x_ct_mmu_ptw.twu_two.sysmap_mmu_hitx2, u_dut.x_ct_mmu_ptw.twu_one.sysmap_mmu_hitx2};
  assign dut_probes_if.p13_sysmap_pa_vec       = {u_dut.x_ct_mmu_ptw.twu_four.mmu_sysmap_pax2, u_dut.x_ct_mmu_ptw.twu_three.mmu_sysmap_pax2, u_dut.x_ct_mmu_ptw.twu_two.mmu_sysmap_pax2, u_dut.x_ct_mmu_ptw.twu_one.mmu_sysmap_pax2};
  assign dut_probes_if.p13_twu_sysmap_adder_vec = {u_dut.x_ct_mmu_ptw.twu_four.twu_sysmap_adderx2, u_dut.x_ct_mmu_ptw.twu_three.twu_sysmap_adderx2, u_dut.x_ct_mmu_ptw.twu_two.twu_sysmap_adderx2, u_dut.x_ct_mmu_ptw.twu_one.twu_sysmap_adderx2};
  assign dut_probes_if.p13_twu_csr_cross_vec   = {u_dut.x_ct_mmu_ptw.twu_four.twu_csr_cross, u_dut.x_ct_mmu_ptw.twu_three.twu_csr_cross, u_dut.x_ct_mmu_ptw.twu_two.twu_csr_cross, u_dut.x_ct_mmu_ptw.twu_one.twu_csr_cross};
  assign dut_probes_if.p13_twu_crs2_1g_vec     = {u_dut.x_ct_mmu_ptw.twu_four.twu_crs_1g, u_dut.x_ct_mmu_ptw.twu_three.twu_crs_1g, u_dut.x_ct_mmu_ptw.twu_two.twu_crs_1g, u_dut.x_ct_mmu_ptw.twu_one.twu_crs_1g};
  assign dut_probes_if.p13_twu_crs2_2m_vec     = {u_dut.x_ct_mmu_ptw.twu_four.twu_crs_2m, u_dut.x_ct_mmu_ptw.twu_three.twu_crs_2m, u_dut.x_ct_mmu_ptw.twu_two.twu_crs_2m, u_dut.x_ct_mmu_ptw.twu_one.twu_crs_2m};
  assign dut_probes_if.p13_twu_crs2_chk_vec    = {u_dut.x_ct_mmu_ptw.twu_four.twu_crs_chk, u_dut.x_ct_mmu_ptw.twu_three.twu_crs_chk, u_dut.x_ct_mmu_ptw.twu_two.twu_crs_chk, u_dut.x_ct_mmu_ptw.twu_one.twu_crs_chk};
  assign dut_probes_if.p13_csr_refill_req_vec  = {u_dut.x_ct_mmu_ptw.twu_four.csr_refill_req, u_dut.x_ct_mmu_ptw.twu_three.csr_refill_req, u_dut.x_ct_mmu_ptw.twu_two.csr_refill_req, u_dut.x_ct_mmu_ptw.twu_one.csr_refill_req};
  assign dut_probes_if.p13_csr_refill_pgs_vec  = {u_dut.x_ct_mmu_ptw.twu_four.csr_refill_pgs, u_dut.x_ct_mmu_ptw.twu_three.csr_refill_pgs, u_dut.x_ct_mmu_ptw.twu_two.csr_refill_pgs, u_dut.x_ct_mmu_ptw.twu_one.csr_refill_pgs};
  assign dut_probes_if.p13_csr_refill_data_vec = {u_dut.x_ct_mmu_ptw.twu_four.csr_refill_data, u_dut.x_ct_mmu_ptw.twu_three.csr_refill_data, u_dut.x_ct_mmu_ptw.twu_two.csr_refill_data, u_dut.x_ct_mmu_ptw.twu_one.csr_refill_data};
  assign ptw_mem_if_inst.mmu_lsu_data_req_accept = |u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant;
  assign dut_probes_if.tlbiva_cur_st     = u_dut.x_ct_mmu_tlboper.tlbiva_cur_st;
  assign dut_probes_if.rtu_yy_xx_flush   = misc_if_inst.rtu_yy_xx_flush;
  assign dut_probes_if.tlboper_utlb_clr  = u_dut.tlboper_utlb_clr;
  assign dut_probes_if.tlboper_utlb_inv_va_req = u_dut.tlboper_utlb_inv_va_req;
  assign dut_probes_if.tlboper_utlb_inv_va = lsu_if_inst.lsu_mmu_tlb_va;
  assign dut_probes_if.biu_mmu_smp_disable  = misc_if_inst.biu_mmu_smp_disable;
  // TLBOP exact transaction decode signals
  assign dut_probes_if.tlbop_tlbp_fsm      = u_dut.x_ct_mmu_tlboper.tlbp_cur_st;
  assign dut_probes_if.tlbop_tlbr_fsm      = u_dut.x_ct_mmu_tlboper.tlbr_cur_st;
  assign dut_probes_if.tlbop_tlbwi_fsm     = u_dut.x_ct_mmu_tlboper.tlbwi_cur_st;
  assign dut_probes_if.tlbop_tlbwr_fsm     = u_dut.x_ct_mmu_tlboper.tlbwr_cur_st;
  assign dut_probes_if.tlbop_tlbiasid_fsm  = u_dut.x_ct_mmu_tlboper.tlbiasid_cur_st;
  assign dut_probes_if.tlbop_tlbiall_fsm   = u_dut.x_ct_mmu_tlboper.tlbiall_cur_st;
  assign dut_probes_if.tlbop_arb_req       = u_dut.x_ct_mmu_tlboper.tlboper_arb_req;
  assign dut_probes_if.tlbop_arb_write     = u_dut.x_ct_mmu_tlboper.tlboper_arb_write;
  assign dut_probes_if.tlbop_arb_grant     = u_dut.arb_tlboper_grant;
  assign dut_probes_if.tlbop_regs_cmplt    = u_dut.x_ct_mmu_tlboper.tlboper_regs_cmplt;
  assign dut_probes_if.tlbop_regs_tlbp_cmplt = u_dut.x_ct_mmu_tlboper.tlboper_regs_tlbp_cmplt;
  assign dut_probes_if.tlbop_regs_tlbr_cmplt = u_dut.x_ct_mmu_tlboper.tlboper_regs_tlbr_cmplt;
  assign dut_probes_if.tlbop_regs_req_tlbp = u_dut.x_ct_mmu_regs.regs_tlboper_tlbp;
  assign dut_probes_if.tlbop_regs_req_tlbr = u_dut.x_ct_mmu_regs.regs_tlboper_tlbr;
  assign dut_probes_if.tlbop_regs_req_tlbwi = u_dut.x_ct_mmu_regs.regs_tlboper_tlbwi;
  assign dut_probes_if.tlbop_regs_req_tlbwr = u_dut.x_ct_mmu_regs.regs_tlboper_tlbwr;
  assign dut_probes_if.tlbop_regs_cur_vpn  = u_dut.x_ct_mmu_regs.regs_tlboper_cur_vpn;
  assign dut_probes_if.tlbop_regs_cur_asid = u_dut.x_ct_mmu_regs.regs_tlboper_cur_asid;
  assign dut_probes_if.tlbop_regs_cur_pgs  = u_dut.x_ct_mmu_regs.regs_tlboper_cur_pgs;
  assign dut_probes_if.tlbop_regs_mir     = u_dut.x_ct_mmu_regs.regs_tlboper_mir;
  assign dut_probes_if.tlbop_regs_cur_ppn  = u_dut.x_ct_mmu_regs.regs_jtlb_cur_ppn;
  assign dut_probes_if.tlbop_regs_cur_flg  = u_dut.x_ct_mmu_regs.regs_jtlb_cur_flg;
  assign dut_probes_if.tlbop_regs_cur_g    = u_dut.x_ct_mmu_regs.regs_jtlb_cur_g;
  assign dut_probes_if.tlbop_l2_hit        = u_dut.x_mmu_l2tlb.l2tlb_regs_hit;
  assign dut_probes_if.tlbop_l2_hit_mult   = u_dut.x_mmu_l2tlb.l2tlb_regs_hit_mult;
  assign dut_probes_if.tlbop_l2_tlbp_hit_idx = u_dut.x_mmu_l2tlb.l2tlb_regs_tlbp_hit_index;
  assign dut_probes_if.tlbop_l2_tlbr_vpn   = u_dut.x_mmu_l2tlb.l2tlb_tlbr_vpn;
  assign dut_probes_if.tlbop_l2_tlbr_pgs   = u_dut.x_mmu_l2tlb.l2tlb_tlbr_pgs;
  assign dut_probes_if.tlbop_l2_tlbr_asid  = u_dut.x_mmu_l2tlb.l2tlb_tlbr_asid;
  assign dut_probes_if.tlbop_l2_tlbr_ppn   = u_dut.x_mmu_l2tlb.l2tlb_tlbr_ppn;
  assign dut_probes_if.tlbop_l2_tlbr_flg   = u_dut.x_mmu_l2tlb.l2tlb_tlbr_flg;
  assign dut_probes_if.tlbop_l2_tlbr_g     = u_dut.x_mmu_l2tlb.l2tlb_tlbr_g;
  assign dut_probes_if.tlbop_l2_tlboper_cmplt = u_dut.x_mmu_l2tlb.l2tlb_tlboper_cmplt;
  assign dut_probes_if.tlbop_l2_tlboper_sel  = u_dut.x_mmu_l2tlb.l2tlb_tlboper_sel;
  assign dut_probes_if.tlbop_l2_va_hit     = u_dut.x_mmu_l2tlb.l2tlb_tlboper_va_hit;
  assign dut_probes_if.tlbop_l2_asid_hit   = u_dut.x_mmu_l2tlb.l2tlb_tlboper_asid_hit;
  assign ifu_if_inst.dbg_iutlb_acc_flt   = u_dut.x_mmu_l1itlb.iutlb_acc_flt;
  assign ifu_if_inst.dbg_iutlb_pmp_deny  = u_dut.x_mmu_l1itlb.pmp_flg_vld
                                         && !u_dut.x_mmu_l1itlb.pmp_mmu_flg2[2]
                                         && !(u_dut.x_mmu_l1itlb.cp0_mach_mode
                                           && !u_dut.x_mmu_l1itlb.pmp_mmu_flg2[3]);
  assign ifu_if_inst.dbg_iutlb_ref_pgflt = u_dut.x_mmu_l1itlb.iutlb_ref_pgflt;
  assign ifu_if_inst.dbg_jtlb_acc_fault_flop = u_dut.x_mmu_l1itlb.jtlb_acc_fault_flop;
  assign ifu_if_inst.dbg_iutlb_ref_cur_st = u_dut.x_mmu_l1itlb.ref_cur_st;
  assign ifu_if_inst.dbg_iutlb_credit_cnt = u_dut.x_mmu_l1itlb.credit_cnt;
  assign ifu_if_inst.dbg_iutlb_l2tlb_req = u_dut.x_mmu_l1itlb.iutlb_l2tlb_req;
  assign ifu_if_inst.dbg_iutlb_miss_vld = u_dut.x_mmu_l1itlb.iutlb_miss_vld;
  assign ifu_if_inst.dbg_iutlb_refill_on = u_dut.x_mmu_l1itlb.iutlb_refill_on;
  assign ifu_if_inst.dbg_l1itlb_ref_cmplt = u_dut.x_mmu_l1itlb.l1itlb_ref_cmplt;
  assign ifu_if_inst.dbg_ptw_l1tlb_pgflt = u_dut.x_mmu_l1itlb.ptw_l1tlb_pgflt;
  assign ifu_if_inst.dbg_jtlb_iutlb_pgflt = u_dut.x_mmu_l1itlb.jtlb_iutlb_pgflt;

  // DTLB expt CAM (mmu_l1dtlb_expt_cam): on consume, mmu_l1dtlb_hit_rd muxes
  // PPN=VPN and ORs (expt_match & expt_{pg,ac}flt). Software ref has no CAM.
  assign lsu_if_inst.mmu_lsu_dtlb_expt_match0 = u_dut.u_mmu_l1dtlb.expt_match0;
  assign lsu_if_inst.mmu_lsu_dtlb_expt_match1 = u_dut.u_mmu_l1dtlb.expt_match1;

  // PTW chain diagnostic only: samples internal state without changing DUT behavior.
  always @(posedge forever_cpuclk) begin
    if (cpurst_b) begin
      if ($test$plusargs("PTW_CHAIN_DBG") &&
          (ptw_mem_if_inst.lsu_mmu_data_vld
          || ptw_mem_if_inst.lsu_mmu_bus_error
          || u_dut.tlboper_ptw_abort
          || u_dut.x_ct_mmu_ptw.abort_flop
          || (|u_dut.x_ct_mmu_ptw.u_ptw_mbuf.write_back_req)
          || (|u_dut.x_ct_mmu_ptw.u_ptw_mbuf.write_back_grant)
          || (|u_dut.x_ct_mmu_ptw.mbuf_twu_data_vld)
          || (|u_dut.x_ct_mmu_ptw.twu_mbuf_req)
          || (|u_dut.x_ct_mmu_ptw.twu_arb_ref_req)
          || u_dut.x_ct_mmu_ptw.pgflt_vld
          || u_dut.x_ct_mmu_ptw.acc_err_vld)) begin
        $display({"[PTW_CHAIN_DBG][MBUF] t=%0t abort=%0b abort_flop=%0b ",
                  "lsu_vld=%0b buserr=%0b data=0x%016h req=%0b req_addr=0x%010h grant=0x%03h ",
                  "entry_vld=0x%03h entry_on=0x%03h entry_get=0x%03h wb_req=0x%03h wb_grant=0x%03h ",
                  "data_vld=0x%0h data_ready=%h twu_idx=0x%0h twu_lvl=0x%0h twu_vpn=0x%07h ",
                  "twu_type=0x%0h twu_id=0x%02h twu_data=0x%016h twu_mbuf_req=0x%0h ",
                  "twu_mbuf_paddr={0x%010h,0x%010h,0x%010h,0x%010h} fault{pg=%0b acc=%0b ref=0x%0h}"},
          $time,
          u_dut.tlboper_ptw_abort,
          u_dut.x_ct_mmu_ptw.abort_flop,
          ptw_mem_if_inst.lsu_mmu_data_vld,
          ptw_mem_if_inst.lsu_mmu_bus_error,
          ptw_mem_if_inst.lsu_mmu_data,
          u_dut.x_ct_mmu_ptw.mmu_lsu_data_req,
          u_dut.x_ct_mmu_ptw.mmu_lsu_data_req_addr,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_vld,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_on,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_get,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.write_back_req,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.write_back_grant,
          u_dut.x_ct_mmu_ptw.mbuf_twu_data_vld,
          u_dut.x_ct_mmu_ptw.twu_data_ready,
          u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_twu_idx,
          u_dut.x_ct_mmu_ptw.mbuf_twu_lvl,
          u_dut.x_ct_mmu_ptw.mbuf_twu_vpn,
          u_dut.x_ct_mmu_ptw.mbuf_twu_type,
          u_dut.x_ct_mmu_ptw.mbuf_twu_id,
          u_dut.x_ct_mmu_ptw.mbuf_twu_data,
          u_dut.x_ct_mmu_ptw.twu_mbuf_req,
          u_dut.x_ct_mmu_ptw.twu_mbuf_paddr[3],
          u_dut.x_ct_mmu_ptw.twu_mbuf_paddr[2],
          u_dut.x_ct_mmu_ptw.twu_mbuf_paddr[1],
          u_dut.x_ct_mmu_ptw.twu_mbuf_paddr[0],
          u_dut.x_ct_mmu_ptw.pgflt_vld,
          u_dut.x_ct_mmu_ptw.acc_err_vld,
          u_dut.x_ct_mmu_ptw.twu_arb_ref_req);
        $display({"[PTW_CHAIN_DBG][TWU] t=%0t abort=%0b ",
                  "fst_vld=0x%0h fst_wait=0x%0h fst_leaf=0x%0h fst_pf=0x%0h ",
                  "fst_data={0x%016h,0x%016h,0x%016h,0x%016h} ",
                  "scd_vld=0x%0h scd_wait=0x%0h scd_req=0x%0h scd_deny=0x%0h scd_grant=0x%0h ",
                  "scd_pa={0x%010h,0x%010h,0x%010h,0x%010h}"},
          $time,
          u_dut.tlboper_ptw_abort,
          {u_dut.x_ct_mmu_ptw.twu_four.fst_chk_vld,
           u_dut.x_ct_mmu_ptw.twu_three.fst_chk_vld,
           u_dut.x_ct_mmu_ptw.twu_two.fst_chk_vld,
           u_dut.x_ct_mmu_ptw.twu_one.fst_chk_vld},
          {u_dut.x_ct_mmu_ptw.twu_four.fst_chk_wait,
           u_dut.x_ct_mmu_ptw.twu_three.fst_chk_wait,
           u_dut.x_ct_mmu_ptw.twu_two.fst_chk_wait,
           u_dut.x_ct_mmu_ptw.twu_one.fst_chk_wait},
          {u_dut.x_ct_mmu_ptw.twu_four.fst_chk_leaf_vld,
           u_dut.x_ct_mmu_ptw.twu_three.fst_chk_leaf_vld,
           u_dut.x_ct_mmu_ptw.twu_two.fst_chk_leaf_vld,
           u_dut.x_ct_mmu_ptw.twu_one.fst_chk_leaf_vld},
          {u_dut.x_ct_mmu_ptw.twu_four.fst_chk_page_flt,
           u_dut.x_ct_mmu_ptw.twu_three.fst_chk_page_flt,
           u_dut.x_ct_mmu_ptw.twu_two.fst_chk_page_flt,
           u_dut.x_ct_mmu_ptw.twu_one.fst_chk_page_flt},
          u_dut.x_ct_mmu_ptw.twu_four.fst_chk_data,
          u_dut.x_ct_mmu_ptw.twu_three.fst_chk_data,
          u_dut.x_ct_mmu_ptw.twu_two.fst_chk_data,
          u_dut.x_ct_mmu_ptw.twu_one.fst_chk_data,
          {u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_vld,
           u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_vld,
           u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_vld,
           u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_vld},
          {u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_wait,
           u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_wait,
           u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_wait,
           u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_wait},
          {u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_mbuf_req,
           u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_mbuf_req,
           u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_mbuf_req,
           u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_mbuf_req},
          {u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_deny,
           u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_deny,
           u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_deny,
           u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_deny},
          {u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_grant,
           u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_grant,
           u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_grant,
           u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_grant},
          u_dut.x_ct_mmu_ptw.twu_four.scd_pmp_pa,
          u_dut.x_ct_mmu_ptw.twu_three.scd_pmp_pa,
          u_dut.x_ct_mmu_ptw.twu_two.scd_pmp_pa,
          u_dut.x_ct_mmu_ptw.twu_one.scd_pmp_pa);
      end
    end
  end

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
    uvm_config_db #(virtual l2tlb_negative_inject_if)::set(
      null, "*", "L2TLB_NEG_INJECT_VIF", l2tlb_neg_inject_if_inst);
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
bind mmu_l1dtlb   mmu_l1dtlb_sva      u_l1dtlb_sva (.*);
bind mmu_l1dtlb_scheduler mmu_l1dtlb_scheduler_sva u_l1dtlb_scheduler_sva (.*);
bind mmu_l1dtlb_allocator mmu_l1dtlb_allocator_sva u_l1dtlb_allocator_sva (.*);
bind mmu_l1dtlb_mb_entry mmu_l1dtlb_mb_entry_sva u_l1dtlb_mb_entry_sva (.*);
bind mmu_l1dtlb_install mmu_l1dtlb_install_sva u_l1dtlb_install_sva (.*);
bind mmu_l1dtlb_expt_cam mmu_l1dtlb_expt_cam_sva u_l1dtlb_expt_cam_sva (.*);
bind mmu_l1dtlb_hit_rd mmu_l1dtlb_hit_rd_sva u_l1dtlb_hit_rd_sva (.*);
bind mmu_arb      mmu_arb_sva         u_arb_sva   (.*);
bind mmu_l2tlb    mmu_l2tlb_rrpv_sva  u_l2tlb_sva (.*);
bind ct_mmu_tlboper mmu_tlbop_lifecycle_sva u_tlbop_lifecycle_sva (.*);
bind mmu_l2tlb_rrpv_wbuf mmu_l2tlb_rrpv_wbuf_sva #(
  .WAY_NUM   (WAY_NUM),
  .IDX_WIDTH (IDX_WIDTH),
  .RRPV_WIDTH(RRPV_WIDTH),
  .DEPTH     (DEPTH)
) u_l2tlb_rrpv_wbuf_sva (.*);
bind mmu_l2tlb_mb mmu_l2tlb_mb_sva    u_l2tlb_mb_sva (.*);
bind mmu_l2tlb_reqq credit_sva       u_reqq_sva  (.*);
bind twu          mmu_twu_sva         u_twu_sva   (.*);
bind ptw          mmu_ptw_top_sva     u_ptw_top_sva (.*);
bind PDE_cache    mmu_pde_cache_sva   u_pde_cache_sva (
  .*,
  .L1PDE_tag_hit({
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[15].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[14].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[13].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[12].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[11].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[10].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[9].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[8].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[7].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[6].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[5].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[4].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[3].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[2].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[1].u_L1PDE_cache.L1PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:(2*VPN_PERLEL)] == u_L1PDE_ent[0].u_L1PDE_cache.L1PDE_tag)
  }),
  .L2PDE_tag_hit({
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[15].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[14].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[13].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[12].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[11].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[10].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[9].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[8].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[7].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[6].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[5].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[4].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[3].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[2].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[1].u_L2PDE_cache.L2PDE_tag),
    (ptw_vpn[VPN_WIDTH-1:VPN_PERLEL] == u_L2PDE_ent[0].u_L2PDE_cache.L2PDE_tag)
  }),
  .L1PDE_l1pmpflg({
    u_L1PDE_ent[15].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[14].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[13].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[12].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[11].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[10].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[9].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[8].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[7].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[6].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[5].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[4].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[3].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[2].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[1].u_L1PDE_cache.L1PDE_l1pmpflg,
    u_L1PDE_ent[0].u_L1PDE_cache.L1PDE_l1pmpflg
  }),
  .L2PDE_l1pmpflg({
    u_L2PDE_ent[15].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[14].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[13].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[12].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[11].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[10].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[9].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[8].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[7].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[6].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[5].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[4].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[3].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[2].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[1].u_L2PDE_cache.L2PDE_l1pmpflg,
    u_L2PDE_ent[0].u_L2PDE_cache.L2PDE_l1pmpflg
  }),
  .L2PDE_l2pmpflg({
    u_L2PDE_ent[15].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[14].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[13].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[12].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[11].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[10].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[9].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[8].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[7].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[6].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[5].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[4].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[3].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[2].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[1].u_L2PDE_cache.L2PDE_l2pmpflg,
    u_L2PDE_ent[0].u_L2PDE_cache.L2PDE_l2pmpflg
  })
);
bind one_to_four_xbar mmu_ptw_xbar_sva u_ptw_xbar_sva (.*);
bind twu          mmu_twu_chk_sva     u_twu_chk_sva (.*);
bind twu          mmu_maee_twu_sva    u_maee_twu_sva (.*);
bind twu          mmu_pmp_twu_sva     u_pmp_twu_sva (.*);
bind twu          mmu_sysmap_sva      u_sysmap_sva (.*);
bind ptw_mbuf     mmu_ptw_lsu_protocol_sva u_ptw_lsu_protocol_sva (.*);
bind ct_mmu_iplru mmu_plru_sva        u_iplru_sva (.*);
bind ct_mmu_dplru mmu_dplru_sva       u_dplru_sva (.*);
