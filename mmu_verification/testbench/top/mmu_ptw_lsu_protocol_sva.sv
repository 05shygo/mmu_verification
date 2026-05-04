// =============================================================================
// PTW <-> LSU protocol SVA (bind ptw_mbuf) - Phase 11
// Focus: strict single-outstanding PTE fetch protocol checks from the v3 gap plan.
// =============================================================================
`timescale 1ns/1ps

module mmu_ptw_lsu_protocol_sva (
    input logic        mbuf_clk,
    input logic        cpurst_b,
    input logic        mmu_lsu_data_req,
    input logic [39:0] mmu_lsu_data_req_addr,
    input logic        mmu_lsu_data_req_size,
    input logic        lsu_mmu_data_vld,
    input logic        lsu_mmu_bus_error,
    input logic        lsu_mmu_data_vld_reg,
    input logic        mbuf_entry_empty_reg,
    input logic        tlboper_ptw_abort,
    input logic [8:0]  mbuf_ptr,
    input logic [8:0]  mbuf_entry_vld,
    input logic [8:0]  mbuf_entry_on
);

  logic       req_prev;
  logic       response_prev;
  logic [1:0] outstanding_cnt;
  logic       response_event;
  logic       request_start;
  logic       request_abort;
  logic       legal_response_slot;

  assign response_event = lsu_mmu_data_vld || lsu_mmu_bus_error;
  assign request_start = mmu_lsu_data_req && (!req_prev || response_prev);
  assign request_abort = outstanding_cnt != 2'b0 && req_prev && !mmu_lsu_data_req && !response_event;
  assign legal_response_slot = (|(mbuf_entry_vld & mbuf_ptr)) || (|mbuf_entry_on);

  always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      req_prev <= 1'b0;
      response_prev <= 1'b0;
      outstanding_cnt <= 2'b0;
    end else begin
      req_prev <= mmu_lsu_data_req;
      response_prev <= response_event;
      case ({request_start, response_event})
        2'b10: outstanding_cnt <= outstanding_cnt + 2'd1;
        2'b01: outstanding_cnt <= 2'b00;
        2'b11: outstanding_cnt <= 2'd1;
        default: outstanding_cnt <= outstanding_cnt;
      endcase
    end
  end

  a_lsu_req_stable_until_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b || tlboper_ptw_abort)
    $rose(mmu_lsu_data_req) |-> (mmu_lsu_data_req throughout ##[1:$] response_event));

  a_lsu_addr_stable_until_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    mmu_lsu_data_req && !response_event && !tlboper_ptw_abort
      |=> (tlboper_ptw_abort || response_event
           || ($stable(mmu_lsu_data_req_addr) && $stable(mmu_lsu_data_req_size))));

  a_single_outstanding: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    outstanding_cnt <= 2'd1);

  a_response_inorder: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    response_event |-> legal_response_slot);

  a_vld_only_when_req: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_data_vld |-> (mmu_lsu_data_req || (|mbuf_entry_on)));

  a_abort_drop_only_when_outstanding: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    request_abort |-> tlboper_ptw_abort);

  a_mbuf_ptr_only_on_response: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    $changed(mbuf_ptr) |-> ($past(response_event)
                            || $past(lsu_mmu_data_vld_reg && mmu_lsu_data_req)
                            || $past(mbuf_entry_empty_reg && mmu_lsu_data_req)
                            || $past(tlboper_ptw_abort)));

endmodule
