// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_if.sv
// Phase 2: PTW data channel interface (PTW → LSU memory bus)
// DUT port group: mmu_lsu_data_* / lsu_mmu_data* / lsu_mmu_bus_error
// (ct_mmu_top.v lines ~140-155)
//
// v7.3 NOTE:
//   mmu_lsu_mmu_en / mmu_lsu_tlb_busy / mmu_lsu_tlb_wakeup[11:0]
//   have been moved to lsu_if (L1DTLB→LSU broadcast subgroup).
//   This interface covers ONLY the strict serial single-outstanding
//   PTE data channel. Protocol constraints (BuildPlan §2.4 Group 7):
//     · mmu_lsu_data_req stable until lsu_mmu_data_vld or bus_error
//     · At most 1 outstanding request at any cycle
//     · No tag/ID field; responses in-order
// =============================================================================
`ifndef PTW_MEM_IF_SV
`define PTW_MEM_IF_SV

interface ptw_mem_if (
  input bit clk_i,
  input bit rst_ni
);

  // =========================================================================
  // PTW Request (driven by DUT, sampled by ptw_mem_monitor / responder)
  // =========================================================================
  logic        mmu_lsu_data_req;
  logic [39:0] mmu_lsu_data_req_addr;
  logic        mmu_lsu_data_req_size; // 0=4B, 1=8B (PTE fetch is always 8B)

  // =========================================================================
  // PTW Response (driven by ptw_mem_responder)
  // =========================================================================
  logic        lsu_mmu_data_vld;
  logic [63:0] lsu_mmu_data;
  logic        lsu_mmu_bus_error;

  // =========================================================================
  // Clocking Block — Responder Driver
  // =========================================================================
  clocking driver_cb @(posedge clk_i);
    default input #1step output #1;
    input  mmu_lsu_data_req;
    input  mmu_lsu_data_req_addr;
    input  mmu_lsu_data_req_size;
    output lsu_mmu_data_vld;
    output lsu_mmu_data;
    output lsu_mmu_bus_error;
  endclocking

  // =========================================================================
  // Clocking Block — Monitor
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input mmu_lsu_data_req;
    input mmu_lsu_data_req_addr;
    input mmu_lsu_data_req_size;
    input lsu_mmu_data_vld;
    input lsu_mmu_data;
    input lsu_mmu_bus_error;
  endclocking

endinterface : ptw_mem_if

`endif // PTW_MEM_IF_SV
