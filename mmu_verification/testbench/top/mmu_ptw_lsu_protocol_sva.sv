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
    input logic        tlboper_ptw_abort,
    input logic [8:0]  mbuf_entry_on,
    input logic [8:0]  mmu_lsu_data_req_grant,
    input logic [8:0][39:0] mbuf_entry_padder
);

  logic       past_valid;
  logic       pending_req;
  logic       pending_aborted;
  logic [8:0] pending_grant;
  logic [39:0] pending_addr;
  logic       pending_size;
  logic [39:0] accept_addr;
  logic [39:0] pending_entry_addr;
  logic       req_prev;
  logic       response_event;
  logic       accept_event;
  logic       request_abort;

  assign response_event = lsu_mmu_data_vld || lsu_mmu_bus_error;
  assign accept_event   = |mmu_lsu_data_req_grant;
  assign request_abort  = pending_req && !pending_aborted
                         && req_prev && !mmu_lsu_data_req && !response_event;

  always_comb begin
    accept_addr = 40'b0;
    for (int i = 0; i < 9; i++) begin
      if (mmu_lsu_data_req_grant[i])
        accept_addr = mbuf_entry_padder[i];
    end
  end

  always_comb begin
    pending_entry_addr = 40'b0;
    for (int i = 0; i < 9; i++) begin
      if (pending_grant[i])
        pending_entry_addr = mbuf_entry_padder[i];
    end
  end

  always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      past_valid     <= 1'b0;
      pending_req    <= 1'b0;
      pending_aborted <= 1'b0;
      pending_grant  <= 9'b0;
      pending_addr   <= 40'b0;
      pending_size   <= 1'b0;
      req_prev       <= 1'b0;
    end else begin
      past_valid <= 1'b1;
      req_prev <= mmu_lsu_data_req;

      if (pending_req && tlboper_ptw_abort)
        pending_aborted <= 1'b1;

      case ({accept_event, response_event})
        2'b10: begin
          pending_req     <= 1'b1;
          pending_aborted <= 1'b0;
          pending_grant   <= mmu_lsu_data_req_grant;
          pending_addr    <= accept_addr;
          pending_size    <= mmu_lsu_data_req_size;
        end
        2'b01: begin
          pending_req     <= 1'b0;
          pending_aborted <= 1'b0;
          pending_grant   <= 9'b0;
          pending_addr    <= 40'b0;
          pending_size    <= 1'b0;
        end
        2'b11: begin
          pending_req     <= 1'b1;
          pending_aborted <= 1'b0;
          pending_grant   <= mmu_lsu_data_req_grant;
          pending_addr    <= accept_addr;
          pending_size    <= mmu_lsu_data_req_size;
        end
        default: begin
        end
      endcase
    end
  end

  // req_on_ptr/mbuf_ptr is now a live combinational selector and may repoint to
  // newly-arrived TWU work while an older accepted LSU read is still pending.
  // The externally accepted request is the grant pulse into mbuf_entry_on.
  a_lsu_req_stable_until_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b || tlboper_ptw_abort)
    accept_event |-> (mmu_lsu_data_req
                      && $onehot(mmu_lsu_data_req_grant)
                      && (accept_addr == mmu_lsu_data_req_addr)));

  a_lsu_addr_stable_until_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    pending_req && !pending_aborted && !tlboper_ptw_abort && !response_event
      |-> ((pending_entry_addr == pending_addr)
           && (pending_size == mmu_lsu_data_req_size)));

  a_single_outstanding: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    !(accept_event && pending_req && !response_event));

  a_response_inorder: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    response_event |-> pending_req);

  a_vld_only_when_req: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_data_vld |-> (pending_req || (|mbuf_entry_on)));

  a_abort_drop_only_when_outstanding: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    request_abort |-> tlboper_ptw_abort);

  a_mbuf_ptr_only_on_response: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b || !past_valid)
    $changed(mbuf_entry_on) |-> ($past(accept_event) || $past(response_event)));

endmodule
