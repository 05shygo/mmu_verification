// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_if.sv
// Phase 2: PMP <=> MMU interface
// DUT port group: pmp_mmu_flg{0..7} (inputs) / mmu_pmp_pa{0..7} (outputs)
//                 / mmu_pmp_fetch{3,5,6,7} (outputs)
// (ct_mmu_top.v lines ~158-185)
//
// Port Allocation (BuildPlan §6.5 / F7.NEW.9):
//   pa0/flg0: IFU (L1 ITLB → PMP port 0)
//   pa1/flg1: LSU Pipe0 (L1 DTLB → PMP port 1)
//   pa2/flg2: LSU Pipe1 (L1 DTLB → PMP port 2)
//   pa3/flg3: PTW twu_one  (ptw.sv:L291/300)
//   pa4/flg4: LSU Pipe2 / prefetch
//   pa5/flg5: PTW twu_two  (ptw.sv:L344/353)
//   pa6/flg6: PTW twu_three (ptw.sv:L397/406)
//   pa7/flg7: PTW twu_four  (ptw.sv:L450/459)
//
// ⚠ DA-003 OPEN: pa3 attribution (PTW twu_one vs IFU) pending design confirm.
// ⚠ RTL NOTE: ct_mmu_top.v:L167 uses mmu_pmp_fetch7 (correct spelling).
//             BuildPlan §6.5 mentions typo in ptw.sv:L62 (mmu_pmp_fecth7)
//             but top-level port is mmu_pmp_fetch7 — this interface uses
//             the CORRECT spelling matching ct_mmu_top.v.
// =============================================================================
`ifndef PMP_IF_SV
`define PMP_IF_SV

interface pmp_if (
  input bit clk_i,
  input bit rst_ni
);

  // =========================================================================
  // PA Outputs — MMU → PMP (8 ports, sampled by pmp_monitor)
  // =========================================================================
  logic [27:0] mmu_pmp_pa0;
  logic [27:0] mmu_pmp_pa1;
  logic [27:0] mmu_pmp_pa2;
  logic [27:0] mmu_pmp_pa3;
  logic [27:0] mmu_pmp_pa4;
  logic [27:0] mmu_pmp_pa5;
  logic [27:0] mmu_pmp_pa6;
  logic [27:0] mmu_pmp_pa7;

  // =========================================================================
  // Fetch Enable Outputs — MMU → PMP
  // (PTW PTE reads are Data-Load type → fetch_en always 0 per F7.NEW.7)
  // =========================================================================
  logic        mmu_pmp_fetch3;
  logic        mmu_pmp_fetch5;
  logic        mmu_pmp_fetch6;
  logic        mmu_pmp_fetch7;  // Note: correct spelling (top-level port name)

  // =========================================================================
  // Flag Inputs — PMP → MMU (8 × 4-bit, driven by pmp_driver)
  // flg[3:0]: {execute, write, read, valid} (or similar encoding per PMP spec)
  // =========================================================================
  logic [3:0]  pmp_mmu_flg0;
  logic [3:0]  pmp_mmu_flg1;
  logic [3:0]  pmp_mmu_flg2;
  logic [3:0]  pmp_mmu_flg3;
  logic [3:0]  pmp_mmu_flg4;
  logic [3:0]  pmp_mmu_flg5;
  logic [3:0]  pmp_mmu_flg6;
  logic [3:0]  pmp_mmu_flg7;

  // =========================================================================
  // Clocking Block — Responder Driver (pmp_driver drives flags)
  // =========================================================================
  clocking driver_cb @(posedge clk_i);
    default input #1step output #1;
    input  mmu_pmp_pa0, mmu_pmp_pa1, mmu_pmp_pa2, mmu_pmp_pa3;
    input  mmu_pmp_pa4, mmu_pmp_pa5, mmu_pmp_pa6, mmu_pmp_pa7;
    input  mmu_pmp_fetch3, mmu_pmp_fetch5, mmu_pmp_fetch6, mmu_pmp_fetch7;
    output pmp_mmu_flg0, pmp_mmu_flg1, pmp_mmu_flg2, pmp_mmu_flg3;
    output pmp_mmu_flg4, pmp_mmu_flg5, pmp_mmu_flg6, pmp_mmu_flg7;
  endclocking

  // =========================================================================
  // Clocking Block — Monitor
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input mmu_pmp_pa0, mmu_pmp_pa1, mmu_pmp_pa2, mmu_pmp_pa3;
    input mmu_pmp_pa4, mmu_pmp_pa5, mmu_pmp_pa6, mmu_pmp_pa7;
    input mmu_pmp_fetch3, mmu_pmp_fetch5, mmu_pmp_fetch6, mmu_pmp_fetch7;
    input pmp_mmu_flg0, pmp_mmu_flg1, pmp_mmu_flg2, pmp_mmu_flg3;
    input pmp_mmu_flg4, pmp_mmu_flg5, pmp_mmu_flg6, pmp_mmu_flg7;
  endclocking

endinterface : pmp_if

`endif // PMP_IF_SV
