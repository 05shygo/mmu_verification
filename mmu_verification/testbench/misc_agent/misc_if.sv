// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_if.sv
// Phase 2: Miscellaneous signals interface
// Subgroups: rtu (flush/expt injection) / hpcp (performance counters)
//            / dft (scan_en, smp_disable) / debug (had_debug_info)
// DUT port group: rtu_mmu_* / hpcp_mmu_cnt_en / mmu_hpcp_* /
//                 biu_mmu_smp_disable / pad_yy_icg_scan_en / mmu_had_debug_info
// (ct_mmu_top.v lines ~40-47, ~188-195)
// =============================================================================
`ifndef MISC_IF_SV
`define MISC_IF_SV

interface misc_if (
  input bit clk_i,
  input bit rst_ni
);

  // =========================================================================
  // RTU Subgroup (driven by misc_driver)
  // rtu_yy_xx_flush : pipeline flush (single-cycle pulse)
  // rtu_mmu_expt_vld: exception valid (accompanies bad_vpn)
  // rtu_mmu_bad_vpn : bad VPN carried with exception
  // =========================================================================
  logic [26:0] rtu_mmu_bad_vpn;
  logic        rtu_mmu_expt_vld;
  logic        rtu_yy_xx_flush;

  // =========================================================================
  // HPCP Subgroup
  // hpcp_mmu_cnt_en    : performance counter enable (driven by misc_driver)
  // mmu_hpcp_dutlb_miss: L1 DTLB miss event (sampled by misc_monitor)
  // mmu_hpcp_iutlb_miss: L1 ITLB miss event
  // mmu_hpcp_jtlb_miss : L2 TLB miss event
  // =========================================================================
  logic        hpcp_mmu_cnt_en;
  logic        mmu_hpcp_dutlb_miss;
  logic        mmu_hpcp_iutlb_miss;
  logic        mmu_hpcp_jtlb_miss;

  // =========================================================================
  // DFT / Low-Power Subgroup (driven by misc_driver)
  // =========================================================================
  logic        pad_yy_icg_scan_en;   // DFT scan enable (tie 0 in normal sim)
  logic        biu_mmu_smp_disable;  // SMP disable (bus attribute override)

  // =========================================================================
  // Debug Subgroup (sampled by misc_monitor)
  // =========================================================================
  logic [33:0] mmu_had_debug_info;

  // =========================================================================
  // Clocking Block — Active Driver
  // =========================================================================
  clocking driver_cb @(posedge clk_i);
    default input #1step output #1;
    output rtu_mmu_bad_vpn, rtu_mmu_expt_vld, rtu_yy_xx_flush;
    output hpcp_mmu_cnt_en;
    output pad_yy_icg_scan_en, biu_mmu_smp_disable;
    input  mmu_hpcp_dutlb_miss, mmu_hpcp_iutlb_miss, mmu_hpcp_jtlb_miss;
    input  mmu_had_debug_info;
  endclocking

  // =========================================================================
  // Clocking Block — Monitor
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input rtu_mmu_bad_vpn, rtu_mmu_expt_vld, rtu_yy_xx_flush;
    input hpcp_mmu_cnt_en;
    input pad_yy_icg_scan_en, biu_mmu_smp_disable;
    input mmu_hpcp_dutlb_miss, mmu_hpcp_iutlb_miss, mmu_hpcp_jtlb_miss;
    input mmu_had_debug_info;
  endclocking

endinterface : misc_if

`endif // MISC_IF_SV
