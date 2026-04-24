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

    // Default simulation timeout (overridable by test)
    uvm_config_db #(int)::set(null, "*", "timeout", 100_000);

    run_test();
  end

endmodule : tb_top
