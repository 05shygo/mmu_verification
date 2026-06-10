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
//     · mmu_lsu_data_req stable until lsu_mmu_data_vld or bus_error, except
//       abort may withdraw req after the read was accepted; the late response
//       still returns to retire PTW abort cleanup
//     · lsu_mmu_data_req_grant is the TB memory-side accept.
//     · mmu_lsu_data_req_accept is the derived req/grant fire event.
//     · At most 1 outstanding request at any cycle.
//     · The request ID is returned on the response for PTW MBUF routing.
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
  logic [3:0]  mmu_lsu_data_req_id;
  logic        mmu_lsu_data_req_size; // 0=4B, 1=8B (PTE fetch is always 8B)
  logic        lsu_mmu_data_req_grant;
  wire         mmu_lsu_data_req_accept = mmu_lsu_data_req & lsu_mmu_data_req_grant;

  // =========================================================================
  // PTW Response (driven by ptw_mem_responder)
  // =========================================================================
  logic        lsu_mmu_data_vld;
  logic [63:0] lsu_mmu_data;
  logic [3:0]  lsu_mmu_data_id;
  logic        lsu_mmu_bus_error;

  // =========================================================================
  // Clocking Block — Responder Driver
  // =========================================================================
  clocking driver_cb @(posedge clk_i);
    default input #1step output #1step;
    input  mmu_lsu_data_req;
    input  mmu_lsu_data_req_addr;
    input  mmu_lsu_data_req_id;
    input  mmu_lsu_data_req_size;
    input  mmu_lsu_data_req_accept;
    output lsu_mmu_data_req_grant;
    output lsu_mmu_data_vld;
    output lsu_mmu_data;
    output lsu_mmu_data_id;
    output lsu_mmu_bus_error;
  endclocking

  // =========================================================================
  // Clocking Block — Monitor
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input mmu_lsu_data_req;
    input mmu_lsu_data_req_addr;
    input mmu_lsu_data_req_id;
    input mmu_lsu_data_req_size;
    input lsu_mmu_data_req_grant;
    input mmu_lsu_data_req_accept;
    input lsu_mmu_data_vld;
    input lsu_mmu_data;
    input lsu_mmu_data_id;
    input lsu_mmu_bus_error;
  endclocking

endinterface : ptw_mem_if

`endif // PTW_MEM_IF_SV
