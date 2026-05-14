// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_if.sv
// Phase 2: SysMap configuration interface (UVM mirror)
//
// NOTE: ct_mmu_sysmap.v has NO top-level ports — its base/mask/flg/enable
//       values are compile-time macros in the current RTL build.  The
//       sysmap_cfg_driver currently mirrors configuration to this interface
//       only; the planned whitebox force paths remain disabled:
//         tb_top.u_dut.u_sysmap.region_base[N]
//         tb_top.u_dut.u_sysmap.region_mask[N]
//         tb_top.u_dut.u_sysmap.region_flg[N]
//         tb_top.u_dut.u_sysmap.region_en[N]
//       See sysmap_cfg_driver.svh DA-003 before treating this as DUT config.
//
// This interface carries only the configuration data arrays used for
// handshake between sequencer/driver; no DUT signal bindings here.
// =============================================================================
`ifndef SYSMAP_CFG_IF_SV
`define SYSMAP_CFG_IF_SV

interface sysmap_cfg_if (
  input bit clk_i,
  input bit rst_ni
);

  // =========================================================================
  // Configuration Data (8 SysMap regions)
  // Written by sysmap_cfg_driver.svh as a UVM mirror.
  // Observed by sysmap_cfg_monitor.svh (snapshot on enable-bit change).
  // =========================================================================
  bit [27:0] cfg_base   [8];   // Region base physical address
  bit [27:0] cfg_mask   [8];   // Region address mask
  bit [4:0]  cfg_flg    [8];   // Region attribute flags (5-bit SysMap encoding)
  bit        cfg_enable [8];   // Region enable

  // =========================================================================
  // Clocking Block — Monitor (observes cfg_enable changes)
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    // cfg_* are bit arrays driven by driver directly, sampled combinatorially
    // No RTL signals here — driver and monitor access cfg_* directly via vif
  endclocking

endinterface : sysmap_cfg_if

`endif // SYSMAP_CFG_IF_SV
