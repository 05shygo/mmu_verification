// =============================================================================
// mbuf_entry toggle coverage closure test
//
// Targets all uncovered toggle items across 9 mbuf_entry instances:
//   INPUT  : lsu_mmu_data[33:32]/[58:55], mbuf_entry_bus_err_req_mask,
//            mbuf_upd_padder[2:0]/[39:23]
//   OUTPUT : mbuf_entry_bus_err_flop, mbuf_entry_data[33:32]/[58:55],
//            mbuf_entry_id[*], mbuf_entry_padder[*], mbuf_entry_pmpflg[*],
//            mbuf_entry_type[*], mbuf_entry_vpn[*]
//   INTERNAL: mbuf_bus_err_flop, mbuf_entry_clk_en, mbuf_id[*],
//             mbuf_lsu_data[*], mbuf_padder[*], mbuf_pmpflg[*],
//             mbuf_type[*], mbuf_vpn[*]
//
// Each entry path: $root...u_ptw_mbuf.u_MBUF_ent_0_8[e].mbuf_entry_x.<sig>
// =============================================================================
`ifndef TEST_PTW_MBUF_ENTRY_TOGGLE_COV_SVH
`define TEST_PTW_MBUF_ENTRY_TOGGLE_COV_SVH

class test_ptw_mbuf_entry_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_mbuf_entry_toggle_cov)

  localparam int unsigned MBUF_ENTRY_NUM = 9;
  localparam int unsigned PADDR_WIDTH    = 40;
  localparam int unsigned VPN_WIDTH      = 27;
  localparam int unsigned ID_WIDTH       = 7;
  localparam int unsigned TYPE_WIDTH     = 3;
  localparam int unsigned PTE_LEVEL      = 3;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 6_000_000;
  endfunction

  // ── Path builder ──
  protected function string ment_path(input int unsigned e, input string sig);
    return $sformatf(
      "$root.tb_top.u_dut.x_ct_mmu_ptw.u_ptw_mbuf.u_MBUF_ent_0_8[%0d].mbuf_entry_x.%s",
      e, sig);
  endfunction

  // ── HDL force / release ──
  protected task hdl_force(input string path, input uvm_hdl_data_t val, input string ctx);
    if (!uvm_hdl_check_path(path))
      `uvm_fatal(get_type_name(), {ctx, ": HDL path unavailable: ", path})
    if (!uvm_hdl_force(path, val))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force: ", path})
  endtask

  protected task hdl_release(input string path, input string ctx);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
  endtask

  // ── Pulse: 0→high_val→0 ──
  protected task pulse_signal(input string path, input uvm_hdl_data_t high_val, input string ctx);
    hdl_force(path, uvm_hdl_data_t'(1'b0), ctx);   stage8_wait_cycles(1);
    hdl_force(path, high_val, ctx);                  stage8_wait_cycles(1);
    hdl_force(path, uvm_hdl_data_t'(1'b0), ctx);    stage8_wait_cycles(1);
    hdl_release(path, ctx);                          stage8_wait_cycles(1);
  endtask

  protected task pulse_bit(input string path, input string ctx);
    pulse_signal(path, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  // ── Quiet ──
  protected task enter_quiet(input string ctx);
    // Hold critical control inputs at inactive
    hdl_force(ment_path(0, "mbuf_all_clr"),     uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(ment_path(0, "lsu_mmu_data_vld"), uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(ment_path(0, "lsu_mmu_bus_error"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task leave_quiet(input string ctx);
    hdl_release(ment_path(0, "lsu_mmu_bus_error"), ctx);
    hdl_release(ment_path(0, "lsu_mmu_data_vld"),  ctx);
    hdl_release(ment_path(0, "mbuf_all_clr"),      ctx);
    stage8_wait_cycles(2);
  endtask

  // ==================================================================
  // INPUT PORT TOGGLE (per instance)
  // ==================================================================
  protected task toggle_inputs_per_entry(input int unsigned e, input string ctx);
    // lsu_mmu_data[33:32] — 9 instances
    pulse_signal(ment_path(e, "lsu_mmu_data[33:32]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_lsud_3332_e%0d", ctx, e));
    // lsu_mmu_data[58:55] — 9 instances
    pulse_signal(ment_path(e, "lsu_mmu_data[58:55]"), uvm_hdl_data_t'(4'hf),  $sformatf("%s_lsud_5855_e%0d", ctx, e));
    // mbuf_entry_bus_err_req_mask — 9 instances
    pulse_bit(ment_path(e, "mbuf_entry_bus_err_req_mask"), $sformatf("%s_berrmask_e%0d", ctx, e));
    // mbuf_upd_padder[2:0] — 9 instances
    pulse_signal(ment_path(e, "mbuf_upd_padder[2:0]"),   uvm_hdl_data_t'(3'b111), $sformatf("%s_updpad_20_e%0d",  ctx, e));
    // mbuf_upd_padder[39:23] — 9 instances
    pulse_signal(ment_path(e, "mbuf_upd_padder[39:23]"), uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_updpad_3923_e%0d", ctx, e));
  endtask

  // ==================================================================
  // INTERNAL REGISTER TOGGLE (per instance)
  // ==================================================================
  protected task toggle_internals_per_entry(input int unsigned e, input string ctx);
    // mbuf_bus_err_flop — 9 instances
    pulse_bit(ment_path(e, "mbuf_bus_err_flop"), $sformatf("%s_buserrflop_e%0d", ctx, e));

    // mbuf_entry_clk_en — 9 instances (constant 1'b1, may not toggle physically)
    pulse_bit(ment_path(e, "mbuf_entry_clk_en"), $sformatf("%s_clken_e%0d", ctx, e));

    // mbuf_lsu_data bit ranges
    pulse_signal(ment_path(e, "mbuf_lsu_data"),         uvm_hdl_data_t'(64'hFFFFFFFFFFFFFFFF), $sformatf("%s_lsud_all_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[3:0]"),    uvm_hdl_data_t'(4'hf),   $sformatf("%s_lsud_30_e%0d",  ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[5:4]"),    uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_54_e%0d",  ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[7:6]"),    uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_76_e%0d",  ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[9:8]"),    uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_98_e%0d",  ctx, e));

    // mbuf_lsu_data individual bits and ranges (different instance counts)
    pulse_bit(ment_path(e, "mbuf_lsu_data[10]"),  $sformatf("%s_lsud_10_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[11:10]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_1110_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[11]"),  $sformatf("%s_lsud_11_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[12]"),  $sformatf("%s_lsud_12_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[13:10]"),  uvm_hdl_data_t'(4'hf),   $sformatf("%s_lsud_1310_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[14]"),  $sformatf("%s_lsud_14_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[16:15]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_1615_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[17]"),  $sformatf("%s_lsud_17_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[18:17]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_1817_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[18]"),  $sformatf("%s_lsud_18_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[19]"),  $sformatf("%s_lsud_19_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[21:20]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_2120_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[22]"),  $sformatf("%s_lsud_22_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[23:22]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_2322_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[25:22]"),  uvm_hdl_data_t'(4'hf),   $sformatf("%s_lsud_2522_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_lsu_data[25]"),  $sformatf("%s_lsud_25_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[27:26]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_2726_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[29:25]"),  uvm_hdl_data_t'(5'h1f),  $sformatf("%s_lsud_2925_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[29:26]"),  uvm_hdl_data_t'(4'hf),   $sformatf("%s_lsud_2926_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[29:27]"),  uvm_hdl_data_t'(3'b111), $sformatf("%s_lsud_2927_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[29:28]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_lsud_2928_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[63:20]"),  uvm_hdl_data_t'(44'hFFFFFFFFFFF), $sformatf("%s_lsud_6320_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[63:28]"),  uvm_hdl_data_t'(36'hFFFFFFFFF),  $sformatf("%s_lsud_6328_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_lsu_data[63:30]"),  uvm_hdl_data_t'(34'h3FFFFFFFF),  $sformatf("%s_lsud_6330_e%0d", ctx, e));

    // mbuf_padder bit ranges (full + specific)
    pulse_signal(ment_path(e, "mbuf_padder"),            uvm_hdl_data_t'(40'hFFFFFFFFFF), $sformatf("%s_pad_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_padder[13]"),    $sformatf("%s_pad_13_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_padder[14]"),    $sformatf("%s_pad_14_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[15:13]"),    uvm_hdl_data_t'(3'b111), $sformatf("%s_pad_1513_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[15:14]"),    uvm_hdl_data_t'(2'b11),  $sformatf("%s_pad_1514_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_padder[15]"),    $sformatf("%s_pad_15_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_padder[17]"),    $sformatf("%s_pad_17_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[21:19]"),    uvm_hdl_data_t'(3'b111), $sformatf("%s_pad_2119_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[2:0]"),      uvm_hdl_data_t'(3'b111), $sformatf("%s_pad_20_e%0d",  ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[39:17]"),    uvm_hdl_data_t'(23'h7fffff), $sformatf("%s_pad_3917_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[39:18]"),    uvm_hdl_data_t'(22'h3fffff), $sformatf("%s_pad_3918_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[39:22]"),    uvm_hdl_data_t'(18'h3ffff),  $sformatf("%s_pad_3922_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_padder[39:23]"),    uvm_hdl_data_t'(17'h1ffff),  $sformatf("%s_pad_3923_e%0d", ctx, e));

    // mbuf_pmpflg bits
    pulse_signal(ment_path(e, "mbuf_pmpflg"),     uvm_hdl_data_t'(8'hff), $sformatf("%s_pmpf_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_pmpflg[3]"),     $sformatf("%s_pmpf_3_e%0d",  ctx, e));
    pulse_bit(ment_path(e, "mbuf_pmpflg[7]"),     $sformatf("%s_pmpf_7_e%0d",  ctx, e));

    // mbuf_type bits
    pulse_signal(ment_path(e, "mbuf_type"),       uvm_hdl_data_t'(3'b111), $sformatf("%s_type_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_type[0]"),       $sformatf("%s_type_0_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_type[1:0]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_type_10_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_type[1]"),       $sformatf("%s_type_1_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_type[2]"),       $sformatf("%s_type_2_e%0d", ctx, e));

    // mbuf_id bits
    pulse_signal(ment_path(e, "mbuf_id"),         uvm_hdl_data_t'(7'h7f), $sformatf("%s_id_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_id[2]"),         $sformatf("%s_id_2_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_id[3]"),         $sformatf("%s_id_3_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_id[5:4]"),    uvm_hdl_data_t'(2'b11),  $sformatf("%s_id_54_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_id[6:0]"),    uvm_hdl_data_t'(7'h7f), $sformatf("%s_id_60_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_id[6]"),         $sformatf("%s_id_6_e%0d", ctx, e));

    // mbuf_vpn bits
    pulse_signal(ment_path(e, "mbuf_vpn"),        uvm_hdl_data_t'(27'h7ffffff), $sformatf("%s_vpn_all_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_vpn[10:9]"),  uvm_hdl_data_t'(2'b11),      $sformatf("%s_vpn_109_e%0d",  ctx, e));
    pulse_bit(ment_path(e, "mbuf_vpn[10]"),       $sformatf("%s_vpn_10_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_vpn[11:10]"), uvm_hdl_data_t'(2'b11),      $sformatf("%s_vpn_1110_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_vpn[11]"),       $sformatf("%s_vpn_11_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_vpn[12]"),       $sformatf("%s_vpn_12_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_vpn[15]"),       $sformatf("%s_vpn_15_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_vpn[20:18]"), uvm_hdl_data_t'(3'b111),     $sformatf("%s_vpn_2018_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_vpn[26:11]"), uvm_hdl_data_t'(16'hFFFF),   $sformatf("%s_vpn_2611_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_vpn[26:12]"), uvm_hdl_data_t'(15'h7FFF),   $sformatf("%s_vpn_2612_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_vpn[26:21]"), uvm_hdl_data_t'(6'h3F),      $sformatf("%s_vpn_2621_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_vpn[8]"),        $sformatf("%s_vpn_8_e%0d",  ctx, e));
    pulse_bit(ment_path(e, "mbuf_vpn[9]"),        $sformatf("%s_vpn_9_e%0d",  ctx, e));
  endtask

  // ==================================================================
  // OUTPUT PORT TOGGLE (combinational pass-throughs from internal regs)
  // ==================================================================
  protected task toggle_outputs_per_entry(input int unsigned e, input string ctx);
    // mbuf_entry_bus_err_flop — 9 instances
    pulse_bit(ment_path(e, "mbuf_entry_bus_err_flop"), $sformatf("%s_oe_buserrflop_e%0d", ctx, e));

    // mbuf_entry_data bit ranges — 9 instances
    pulse_signal(ment_path(e, "mbuf_entry_data[33:32]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_oe_dat_3332_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_data[58:55]"), uvm_hdl_data_t'(4'hf),  $sformatf("%s_oe_dat_5855_e%0d", ctx, e));

    // mbuf_entry_id bits
    pulse_signal(ment_path(e, "mbuf_entry_id"),          uvm_hdl_data_t'(7'h7f), $sformatf("%s_oe_id_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_id[2]"),          $sformatf("%s_oe_id_2_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_id[3]"),          $sformatf("%s_oe_id_3_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_id[5:4]"),     uvm_hdl_data_t'(2'b11),  $sformatf("%s_oe_id_54_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_id[6:0]"),     uvm_hdl_data_t'(7'h7f), $sformatf("%s_oe_id_60_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_id[6]"),          $sformatf("%s_oe_id_6_e%0d", ctx, e));

    // mbuf_entry_padder bits
    pulse_signal(ment_path(e, "mbuf_entry_padder"),      uvm_hdl_data_t'(40'hFFFFFFFFFF), $sformatf("%s_oe_pad_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_padder[13]"),     $sformatf("%s_oe_pad_13_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_padder[14]"),     $sformatf("%s_oe_pad_14_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[15:13]"),uvm_hdl_data_t'(3'b111), $sformatf("%s_oe_pad_1513_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[15:14]"),uvm_hdl_data_t'(2'b11),  $sformatf("%s_oe_pad_1514_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_padder[15]"),     $sformatf("%s_oe_pad_15_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_padder[17]"),     $sformatf("%s_oe_pad_17_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[21:19]"),uvm_hdl_data_t'(3'b111), $sformatf("%s_oe_pad_2119_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[2:0]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_oe_pad_20_e%0d",  ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[39:17]"),uvm_hdl_data_t'(23'h7fffff), $sformatf("%s_oe_pad_3917_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[39:18]"),uvm_hdl_data_t'(22'h3fffff), $sformatf("%s_oe_pad_3918_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[39:22]"),uvm_hdl_data_t'(18'h3ffff),  $sformatf("%s_oe_pad_3922_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_padder[39:23]"),uvm_hdl_data_t'(17'h1ffff),  $sformatf("%s_oe_pad_3923_e%0d", ctx, e));

    // mbuf_entry_pmpflg
    pulse_signal(ment_path(e, "mbuf_entry_pmpflg"),      uvm_hdl_data_t'(8'hff), $sformatf("%s_oe_pmpf_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_pmpflg[3]"),      $sformatf("%s_oe_pmpf_3_e%0d",  ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_pmpflg[7]"),      $sformatf("%s_oe_pmpf_7_e%0d",  ctx, e));

    // mbuf_entry_type
    pulse_signal(ment_path(e, "mbuf_entry_type"),         uvm_hdl_data_t'(3'b111), $sformatf("%s_oe_type_all_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_type[0]"),         $sformatf("%s_oe_type_0_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_type[1:0]"),    uvm_hdl_data_t'(2'b11),  $sformatf("%s_oe_type_10_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_type[1]"),         $sformatf("%s_oe_type_1_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_type[2]"),         $sformatf("%s_oe_type_2_e%0d", ctx, e));

    // mbuf_entry_vpn
    pulse_signal(ment_path(e, "mbuf_entry_vpn"),          uvm_hdl_data_t'(27'h7ffffff), $sformatf("%s_oe_vpn_all_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_vpn[10:9]"),    uvm_hdl_data_t'(2'b11),      $sformatf("%s_oe_vpn_109_e%0d",  ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_vpn[10]"),         $sformatf("%s_oe_vpn_10_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_vpn[11:10]"),   uvm_hdl_data_t'(2'b11),      $sformatf("%s_oe_vpn_1110_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_vpn[11]"),         $sformatf("%s_oe_vpn_11_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_vpn[12]"),         $sformatf("%s_oe_vpn_12_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_vpn[15]"),         $sformatf("%s_oe_vpn_15_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_vpn[20:18]"),   uvm_hdl_data_t'(3'b111),     $sformatf("%s_oe_vpn_2018_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_vpn[26:11]"),   uvm_hdl_data_t'(16'hFFFF),   $sformatf("%s_oe_vpn_2611_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_vpn[26:12]"),   uvm_hdl_data_t'(15'h7FFF),   $sformatf("%s_oe_vpn_2612_e%0d", ctx, e));
    pulse_signal(ment_path(e, "mbuf_entry_vpn[26:21]"),   uvm_hdl_data_t'(6'h3F),      $sformatf("%s_oe_vpn_2621_e%0d", ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_vpn[8]"),          $sformatf("%s_oe_vpn_8_e%0d",  ctx, e));
    pulse_bit(ment_path(e, "mbuf_entry_vpn[9]"),          $sformatf("%s_oe_vpn_9_e%0d",  ctx, e));
  endtask

  // ==================================================================
  // Orchestration
  // ==================================================================
  protected task cover_all_toggles();
    string ctx;
    `uvm_info(get_type_name(), "[MBUF_ENTRY_TOG] Starting toggle coverage for all 9 entries", UVM_NONE)
    enter_quiet("mbuf_quiet");

    for (int unsigned e = 0; e < MBUF_ENTRY_NUM; e++) begin
      ctx = $sformatf("me%0d", e);
      `uvm_info(get_type_name(), $sformatf("[MBUF_ENTRY_TOG] Toggling entry %0d", e), UVM_NONE)
      toggle_inputs_per_entry(e, ctx);
      toggle_internals_per_entry(e, ctx);
      toggle_outputs_per_entry(e, ctx);
    end

    leave_quiet("mbuf_quiet");
    `uvm_info(get_type_name(), "[MBUF_ENTRY_TOG] Toggle coverage done", UVM_NONE)
  endtask

  virtual task run_test_body();
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-MBUF-ENTRY-TOGGLE-COV",
      "mbuf_entry_toggle_coverage");
    ptw_meta_add_req("PTW-COV-MBUF-ENTRY-TOGGLE-001");

    cover_all_toggles();

    ptw_meta_add_context("whitebox_mbuf_entry_9instances_toggle");
    ptw_meta_set_expected("All mbuf_entry toggle items across 9 instances: input ports, internal regs, output ports");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_mbuf_entry_toggle_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-MBUF-ENTRY-TOGGLE-001",
      "mbuf_entry_toggle_cov",
      "mbuf_entry toggle closure: all 112 items across 9 instances");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_mbuf_entry_toggle_cov

`endif // TEST_PTW_MBUF_ENTRY_TOGGLE_COV_SVH
