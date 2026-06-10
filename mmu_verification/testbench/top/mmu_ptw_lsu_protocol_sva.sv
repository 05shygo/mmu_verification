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
    input logic [3:0]  mbuf_grant,
    input logic [8:0]  mbuf_entry_on,
    input logic [8:0]  mbuf_entry_upd,
    input logic [8:0]  mmu_lsu_data_req_grant,
    input logic [8:0][39:0] mbuf_entry_padder,
    input logic [3:0]  mbuf_twu_data_vld,
    input logic        mbuf_cache_upd,
    input logic        mbuf_bus_error,
    input logic [8:0]  write_back_grant,
    input logic [8:0]  write_back_req,
    input logic [8:0]  mbuf_bus_error_grant,
    input logic [8:0]  bus_err_write_back_req
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
  logic       req_drop_event;
  logic       unaccepted_req_drop_event;
  logic       request_abort;
  logic       abort_prev;
  logic       abort_qualifier;

  int unsigned cp_mbuf_grant_onehot_hits;
  int unsigned cp_lsu_req_accept_hits;
  int unsigned cp_lsu_single_outstanding_hits;
  int unsigned cp_lsu_response_inorder_hits;
  int unsigned cp_lsu_normal_data_hits;
  int unsigned cp_lsu_bus_error_data_vld_hits;
  int unsigned cp_lsu_bus_error_pending_hits;
  int unsigned cp_lsu_bus_error_no_chk_hits;
  int unsigned cp_lsu_abort_no_create_hits;
  int unsigned cp_lsu_abort_drop_hits;
  int unsigned cp_lsu_abort_entry_clear_hits;

  assign response_event = lsu_mmu_data_vld || lsu_mmu_bus_error;
  assign accept_event   = |mmu_lsu_data_req_grant;
  assign req_drop_event = pending_req && req_prev && !mmu_lsu_data_req && !response_event;
  assign unaccepted_req_drop_event = !pending_req && req_prev && !mmu_lsu_data_req && !response_event;
  assign abort_qualifier = tlboper_ptw_abort || abort_prev || pending_aborted;
  assign request_abort  = req_drop_event && abort_qualifier;

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
      abort_prev     <= 1'b0;
    end else begin
      past_valid <= 1'b1;
      req_prev <= mmu_lsu_data_req;
      abort_prev <= tlboper_ptw_abort;

      if (pending_req && tlboper_ptw_abort)
        pending_aborted <= 1'b1;

      case ({accept_event, response_event})
        2'b10: begin
          pending_req     <= 1'b1;
          pending_aborted <= tlboper_ptw_abort;
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
          pending_aborted <= tlboper_ptw_abort;
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
  a_mbuf_grant_onehot0: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    $onehot0(mbuf_grant));

  cp_mbuf_grant_onehot: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    $onehot(mbuf_grant)) begin
    cp_mbuf_grant_onehot_hits++;
  end

  a_lsu_req_stable_until_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b || tlboper_ptw_abort)
    accept_event |-> (mmu_lsu_data_req
                      && $onehot(mmu_lsu_data_req_grant)
                      && (accept_addr == mmu_lsu_data_req_addr)));

  cp_lsu_req_accept: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b || tlboper_ptw_abort)
    accept_event && mmu_lsu_data_req && $onehot(mmu_lsu_data_req_grant)) begin
    cp_lsu_req_accept_hits++;
  end

  a_lsu_addr_stable_until_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    pending_req && !pending_aborted && !tlboper_ptw_abort && !response_event
      |-> ((pending_entry_addr == pending_addr)
           && (pending_size == mmu_lsu_data_req_size)));

  a_single_outstanding: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    !(accept_event && pending_req && !response_event));

  cp_lsu_single_outstanding: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    accept_event && !pending_req) begin
    cp_lsu_single_outstanding_hits++;
  end

  a_response_inorder: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    response_event |-> pending_req);

  cp_lsu_response_inorder: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    response_event && pending_req) begin
    cp_lsu_response_inorder_hits++;
  end

  a_vld_only_when_req: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_data_vld |-> (pending_req || (|mbuf_entry_on)));

  // PTW-SVA-MBUF-008/009: bus-error responses are valid LSU response beats.
  a_lsu_bus_error_has_data_vld: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_bus_error |-> lsu_mmu_data_vld);

  cp_lsu_normal_data: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_data_vld && !lsu_mmu_bus_error) begin
    cp_lsu_normal_data_hits++;
  end

  cp_lsu_bus_error_data_vld: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_data_vld && lsu_mmu_bus_error) begin
    cp_lsu_bus_error_data_vld_hits++;
  end

  a_lsu_bus_error_no_normal_writeback: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    (lsu_mmu_bus_error && !(|write_back_req)) |-> ((mbuf_twu_data_vld == 4'b0000)
                                                 && (write_back_grant == 9'b0)
                                                 && !mbuf_cache_upd));

  cp_lsu_bus_error_no_chk: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    lsu_mmu_bus_error && !(|write_back_req)
    && (mbuf_twu_data_vld == 4'b0000) && (write_back_grant == 9'b0)) begin
    cp_lsu_bus_error_no_chk_hits++;
  end

  a_lsu_bus_error_sets_pending: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    (lsu_mmu_bus_error && !tlboper_ptw_abort) |=> mbuf_bus_error);

  cp_lsu_bus_error_pending: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    (|mbuf_bus_error_grant) || (|bus_err_write_back_req) || mbuf_bus_error) begin
    cp_lsu_bus_error_pending_hits++;
  end

  // PTW-SVA-MBUF-002: abort does not allocate a fresh MBUF entry.
  a_abort_no_mbuf_create: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    tlboper_ptw_abort |-> (mbuf_entry_upd == 9'b0));

  cp_lsu_abort_no_create: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    tlboper_ptw_abort && (mbuf_entry_upd == 9'b0)) begin
    cp_lsu_abort_no_create_hits++;
  end

  // After req/grant fire, the visible request may drop or repoint while the
  // accepted read is tracked by mbuf_entry_on and response ID.  A request that
  // has not fired yet may only disappear because it was accepted or aborted in
  // the same handshake window.
  a_unaccepted_req_drop_only_on_accept_or_abort: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    unaccepted_req_drop_event |-> (accept_event || abort_qualifier));

  cp_lsu_abort_drop: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b)
    request_abort && tlboper_ptw_abort) begin
    cp_lsu_abort_drop_hits++;
  end

  // mbuf_entry_on is the per-entry LSU outstanding marker. It is set by an
  // accepted request, cleared by an LSU response, and synchronously cleared by
  // TLBOP abort through mbuf_all_clr.
  a_mbuf_entry_on_changes_on_lifecycle_event: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b || !past_valid)
    $changed(mbuf_entry_on) |-> ($past(accept_event)
                                 || $past(response_event)
                                 || $past(tlboper_ptw_abort)));

  cp_lsu_abort_entry_clear: cover property (@(posedge mbuf_clk) disable iff (!cpurst_b || !past_valid)
    $past(tlboper_ptw_abort && (|mbuf_entry_on)) && (mbuf_entry_on == 9'b0)) begin
    cp_lsu_abort_entry_clear_hits++;
  end

  final begin
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_mbuf_grant_onehot req=PTW-SVA-MBUF-001 hits=%0d", cp_mbuf_grant_onehot_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_req_accept req=PTW-SVA-MBUF-006 hits=%0d", cp_lsu_req_accept_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_single_outstanding req=PTW-SVA-MBUF-001 hits=%0d", cp_lsu_single_outstanding_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_response_inorder req=PTW-SVA-MBUF-006 hits=%0d", cp_lsu_response_inorder_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_normal_data req=PTW-SVA-MBUF-006 hits=%0d", cp_lsu_normal_data_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_bus_error_data_vld req=PTW-SVA-MBUF-008 hits=%0d", cp_lsu_bus_error_data_vld_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_bus_error_pending req=PTW-SVA-MBUF-009 hits=%0d", cp_lsu_bus_error_pending_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_bus_error_no_chk req=PTW-SVA-MBUF-008 hits=%0d", cp_lsu_bus_error_no_chk_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_no_create req=PTW-SVA-MBUF-002 hits=%0d", cp_lsu_abort_no_create_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_drop req=PTW-SVA-MBUF-010,PTW-SVA-MBUF-011 hits=%0d", cp_lsu_abort_drop_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_entry_clear req=PTW-SVA-MBUF-010,PTW-SVA-MBUF-011 hits=%0d", cp_lsu_abort_entry_clear_hits);
  end

endmodule
