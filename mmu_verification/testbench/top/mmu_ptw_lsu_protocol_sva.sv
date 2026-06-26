// =============================================================================
// PTW <-> LSU protocol SVA (bind ptw_mbuf)
// ID/grant-aware PTW MBUF checks plus bus-error/abort coverage.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_ptw_lsu_protocol_sva (
    input logic        mbuf_clk,
    input logic        cpurst_b,
    input logic        mmu_lsu_data_req,
    input logic [39:0] mmu_lsu_data_req_addr,
    input logic [3:0]  mmu_lsu_data_req_id,
    input logic        mmu_lsu_data_req_size,
    input logic        lsu_mmu_data_req_grant,
    input logic        lsu_req_fire,
    input logic        lsu_mmu_data_vld,
    input logic        lsu_mmu_bus_error,
    input logic [3:0]  lsu_mmu_data_id,
    input logic        tlboper_ptw_abort,
    input logic        tlboper_ptw_abort_reg,
    input logic        ptw_abort_drain,
    input logic        req_hold_vld,
    input logic [8:0]  req_hold_ptr,
    input logic [8:0]  req_sel_ptr,
    input logic [8:0]  mmu_lsu_data_req_ptr,
    input logic [8:0]  mbuf_req_pending,
    input logic [8:0]  lsu_mmu_resp_entry_dec,
    input logic [8:0]  lsu_mmu_data_vld_entry,
    input logic [8:0]  lsu_mmu_bus_error_entry,
    input logic [3:0]  mbuf_grant,
    input logic [8:0]  mbuf_entry_vld,
    input logic [8:0]  mbuf_entry_on,
    input logic [8:0]  mbuf_entry_get,
    input logic [8:0]  mbuf_entry_bus_err_flop,
    input logic [8:0]  mbuf_entry_upd,
    input logic [8:0]  mbuf_entry_req_grant,
    input logic [3:0]  mbuf_twu_data_vld,
    input logic        mbuf_cache_upd,
    input logic        mbuf_bus_error,
    input logic [8:0]  write_back_grant,
    input logic [8:0]  write_back_req,
    input logic [8:0]  mbuf_bus_error_grant,
    input logic [8:0]  bus_err_write_back_req
);

  logic        past_valid;
  logic        response_event;
  logic [15:0] outstanding_by_id;
  logic [8:0]  seen_req_id_mask;
  logic [8:0]  seen_rsp_id_mask;
  logic [39:0] hold_addr_q;
  logic [3:0]  hold_id_q;
  logic        hold_size_q;
  logic        hold_seen_q;
  logic        ptw_abort_drain_q;
  logic        abort_multi_seen_q;
  logic        write_back_grant_any_q;

  int unsigned accept_order_by_id [0:15];
  int unsigned next_accept_order;
  int unsigned next_response_order;
  int unsigned grant_wait_len;

  logic        ooo_response_pulse;
  logic        grant_wait_2plus_pulse;
  logic        abort_drain_multi_pulse;
  logic        abort_before_grant_pulse;
  logic        buserr_by_id_pulse;
  logic        invalid_id_ignored_pulse;

  int unsigned cp_mbuf_grant_onehot_hits;
  int unsigned cp_lsu_req_fire_hits;
  int unsigned cp_lsu_req_id_all_hits;
  int unsigned cp_lsu_rsp_id_match_hits;
  int unsigned cp_lsu_two_outstanding_hits;
  int unsigned cp_lsu_max_pressure_hits;
  int unsigned cp_lsu_ooo_response_hits;
  int unsigned cp_lsu_grant_wait_hits;
  int unsigned cp_lsu_normal_data_hits;
  int unsigned cp_lsu_bus_error_data_vld_hits;
  int unsigned cp_lsu_bus_error_pending_hits;
  int unsigned cp_lsu_bus_error_no_chk_hits;
  int unsigned cp_lsu_abort_no_create_hits;
  int unsigned cp_lsu_abort_drain_multi_hits;
  int unsigned cp_lsu_abort_before_grant_hits;
  int unsigned cp_lsu_abort_drain_no_req_hits;
  int unsigned cp_lsu_abort_drain_no_cache_upd_hits;
  int unsigned cp_lsu_buserr_by_id_hits;
  int unsigned cp_lsu_invalid_id_ignored_hits;
  int unsigned cp_pde_abort_drain_no_cache_upd_hits;
  int unsigned cp_pde_bus_error_no_cache_upd_idle_hits;

  assign response_event = lsu_mmu_data_vld || lsu_mmu_bus_error;

  function automatic logic legal_mbuf_id(input logic [3:0] id);
    return (id < 4'd9);
  endfunction

  function automatic logic [8:0] id_to_mbuf_vec(input logic [3:0] id);
    logic [8:0] vec;
    vec = 9'b0;
    if (legal_mbuf_id(id))
      vec[id] = 1'b1;
    return vec;
  endfunction

  function automatic int unsigned count_ones9(input logic [8:0] vec);
    int unsigned count;
    count = 0;
    for (int i = 0; i < 9; i++) begin
      if (vec[i])
        count++;
    end
    return count;
  endfunction

  always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      past_valid <= 1'b0;
      outstanding_by_id <= 16'b0;
      seen_req_id_mask <= 9'b0;
      seen_rsp_id_mask <= 9'b0;
      hold_seen_q <= 1'b0;
      hold_addr_q <= 40'b0;
      hold_id_q <= 4'b0;
      hold_size_q <= 1'b0;
      ptw_abort_drain_q <= 1'b0;
      abort_multi_seen_q <= 1'b0;
      write_back_grant_any_q <= 1'b0;
      next_accept_order <= 0;
      next_response_order <= 0;
      grant_wait_len <= 0;
      ooo_response_pulse <= 1'b0;
      grant_wait_2plus_pulse <= 1'b0;
      abort_drain_multi_pulse <= 1'b0;
      abort_before_grant_pulse <= 1'b0;
      buserr_by_id_pulse <= 1'b0;
      invalid_id_ignored_pulse <= 1'b0;
      for (int i = 0; i < 16; i++) begin
        accept_order_by_id[i] <= 0;
      end
    end else begin
      past_valid <= 1'b1;
      ptw_abort_drain_q <= ptw_abort_drain;
      write_back_grant_any_q <= |write_back_grant;
      ooo_response_pulse <= 1'b0;
      grant_wait_2plus_pulse <= 1'b0;
      abort_drain_multi_pulse <= 1'b0;
      abort_before_grant_pulse <= 1'b0;
      buserr_by_id_pulse <= 1'b0;
      invalid_id_ignored_pulse <= 1'b0;

      if (response_event && legal_mbuf_id(lsu_mmu_data_id)) begin
        outstanding_by_id[lsu_mmu_data_id] <= 1'b0;
        seen_rsp_id_mask[lsu_mmu_data_id] <= 1'b1;

        if (outstanding_by_id[lsu_mmu_data_id]) begin
          cp_lsu_rsp_id_match_hits++;
          if (accept_order_by_id[lsu_mmu_data_id] != next_response_order) begin
            ooo_response_pulse <= 1'b1;
            cp_lsu_ooo_response_hits++;
          end
          if (lsu_mmu_bus_error
              && (accept_order_by_id[lsu_mmu_data_id] != next_response_order)) begin
            buserr_by_id_pulse <= 1'b1;
            cp_lsu_buserr_by_id_hits++;
          end
          next_response_order <= next_response_order + 1;
        end
      end else if (response_event) begin
        invalid_id_ignored_pulse <= 1'b1;
        cp_lsu_invalid_id_ignored_hits++;
      end

      if (lsu_req_fire && legal_mbuf_id(mmu_lsu_data_req_id)) begin
        if (outstanding_by_id[mmu_lsu_data_req_id]) begin
          $error("PTW-LSU duplicate outstanding ID: id=%0d addr=0x%010h",
                 mmu_lsu_data_req_id, mmu_lsu_data_req_addr);
        end
        outstanding_by_id[mmu_lsu_data_req_id] <= 1'b1;
        accept_order_by_id[mmu_lsu_data_req_id] <= next_accept_order;
        next_accept_order <= next_accept_order + 1;
        seen_req_id_mask[mmu_lsu_data_req_id] <= 1'b1;
        cp_lsu_req_fire_hits++;
      end

      if (count_ones9(mbuf_entry_on) >= 2)
        cp_lsu_two_outstanding_hits++;

      if (count_ones9(mbuf_entry_on) >= 4)
        cp_lsu_max_pressure_hits++;

      if (seen_req_id_mask == 9'h1ff)
        cp_lsu_req_id_all_hits++;

      if (mmu_lsu_data_req && !lsu_mmu_data_req_grant && !ptw_abort_drain) begin
        grant_wait_len <= grant_wait_len + 1;
        hold_seen_q <= 1'b1;
        hold_addr_q <= mmu_lsu_data_req_addr;
        hold_id_q <= mmu_lsu_data_req_id;
        hold_size_q <= mmu_lsu_data_req_size;
      end else begin
        if (lsu_req_fire && (grant_wait_len >= 2)) begin
          grant_wait_2plus_pulse <= 1'b1;
          cp_lsu_grant_wait_hits++;
        end
        if (ptw_abort_drain
            && (hold_seen_q || req_hold_vld || (grant_wait_len != 0))
            && !lsu_req_fire) begin
          abort_before_grant_pulse <= 1'b1;
          cp_lsu_abort_before_grant_hits++;
        end
        grant_wait_len <= 0;
        if (lsu_req_fire || ptw_abort_drain || !mmu_lsu_data_req)
          hold_seen_q <= 1'b0;
      end

      if (lsu_mmu_data_vld && lsu_mmu_bus_error)
        cp_lsu_bus_error_data_vld_hits++;

      if (ptw_abort_drain && !mmu_lsu_data_req)
        cp_lsu_abort_drain_no_req_hits++;

      if (ptw_abort_drain && !mbuf_cache_upd)
        cp_lsu_abort_drain_no_cache_upd_hits++;

      if (ptw_abort_drain && !mbuf_cache_upd)
        cp_pde_abort_drain_no_cache_upd_hits++;

      if (lsu_mmu_bus_error
          && !(|write_back_req)
          && !(|write_back_grant)
          && !write_back_grant_any_q
          && !mbuf_cache_upd)
        cp_pde_bus_error_no_cache_upd_idle_hits++;

      if (abort_multi_seen_q
          && ptw_abort_drain_q
          && !ptw_abort_drain
          && !(|mbuf_entry_on)) begin
        abort_drain_multi_pulse <= 1'b1;
        cp_lsu_abort_drain_multi_hits++;
        abort_multi_seen_q <= 1'b0;
      end else if ((tlboper_ptw_abort || ptw_abort_drain)
                   && (count_ones9(mbuf_entry_on) >= 2)) begin
        abort_multi_seen_q <= 1'b1;
      end else if (!ptw_abort_drain
                   && !tlboper_ptw_abort_reg
                   && !(|mbuf_entry_on)) begin
        abort_multi_seen_q <= 1'b0;
      end
    end
  end

  a_lsu_req_fire_definition: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_req_fire == (mmu_lsu_data_req && lsu_mmu_data_req_grant));

  a_lsu_req_id_legal_on_fire: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_req_fire |-> legal_mbuf_id(mmu_lsu_data_req_id));

  a_lsu_req_no_duplicate_id_on_fire: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_req_fire |-> !outstanding_by_id[mmu_lsu_data_req_id]);

  a_lsu_req_fire_sets_entry_on: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (lsu_req_fire && legal_mbuf_id(mmu_lsu_data_req_id))
      |=> mbuf_entry_on[$past(mmu_lsu_data_req_id)]);

  a_lsu_req_ptr_onehot: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    mmu_lsu_data_req |-> $onehot(mmu_lsu_data_req_ptr));

  a_lsu_req_ptr_matches_id: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    mmu_lsu_data_req |-> (mmu_lsu_data_req_ptr == id_to_mbuf_vec(mmu_lsu_data_req_id)));

  a_lsu_req_id_matches_selected_entry: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    mmu_lsu_data_req |-> (legal_mbuf_id(mmu_lsu_data_req_id)
                          && ((req_hold_vld ? req_hold_ptr : req_sel_ptr)
                              == id_to_mbuf_vec(mmu_lsu_data_req_id))));

  a_lsu_req_fire_grants_selected_entry: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_req_fire |-> (mbuf_entry_req_grant == id_to_mbuf_vec(mmu_lsu_data_req_id)));

  a_lsu_req_hold_stable_until_grant: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (mmu_lsu_data_req && !lsu_mmu_data_req_grant && !ptw_abort_drain)
      |=> (ptw_abort_drain
           || (mmu_lsu_data_req
               && (mmu_lsu_data_req_addr == $past(mmu_lsu_data_req_addr))
               && (mmu_lsu_data_req_id   == $past(mmu_lsu_data_req_id))
               && (mmu_lsu_data_req_size == $past(mmu_lsu_data_req_size)))));

  a_lsu_req_hold_matches_recorded_values: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    hold_seen_q && mmu_lsu_data_req && !lsu_mmu_data_req_grant && !ptw_abort_drain
      |-> ((mmu_lsu_data_req_addr == hold_addr_q)
           && (mmu_lsu_data_req_id == hold_id_q)
           && (mmu_lsu_data_req_size == hold_size_q)));

  a_lsu_ungranted_req_does_not_set_entry_on: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (mmu_lsu_data_req && !lsu_mmu_data_req_grant && !ptw_abort_drain && !response_event)
      |=> ((mbuf_entry_on & ~$past(mbuf_entry_on)) == 9'b0));

  a_lsu_response_matches_outstanding_id: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (response_event && legal_mbuf_id(lsu_mmu_data_id))
      |-> outstanding_by_id[lsu_mmu_data_id]);

  a_lsu_response_clears_only_rsp_entry: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (response_event
     && legal_mbuf_id(lsu_mmu_data_id)
     && outstanding_by_id[lsu_mmu_data_id]
     && !lsu_req_fire)
      |=> ((((mbuf_entry_on ^ $past(mbuf_entry_on))
             & ~id_to_mbuf_vec($past(lsu_mmu_data_id))) == 9'b0)
           && !mbuf_entry_on[$past(lsu_mmu_data_id)]));

  a_lsu_invalid_response_has_no_entry_decode: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (response_event && !legal_mbuf_id(lsu_mmu_data_id))
      |-> ((lsu_mmu_resp_entry_dec == 9'b0)
           && (lsu_mmu_data_vld_entry == 9'b0)
           && (lsu_mmu_bus_error_entry == 9'b0)));

  a_lsu_invalid_response_no_visible_writeback_when_idle: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (response_event
     && !legal_mbuf_id(lsu_mmu_data_id)
     && !(|write_back_req)
     && !(|bus_err_write_back_req))
      |-> ((write_back_grant == 9'b0)
           && (mbuf_bus_error_grant == 9'b0)
           && (mbuf_twu_data_vld == 4'b0000)
           && !mbuf_cache_upd));

  a_lsu_invalid_response_preserves_entry_state_when_idle: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (response_event
     && !legal_mbuf_id(lsu_mmu_data_id)
     && !lsu_req_fire
     && !(|write_back_req)
     && !(|bus_err_write_back_req)
     && (mbuf_entry_upd == 9'b0)
     && !tlboper_ptw_abort
     && !ptw_abort_drain)
      |=> ((mbuf_entry_on == $past(mbuf_entry_on))
           && (mbuf_entry_get == $past(mbuf_entry_get))
           && (mbuf_entry_bus_err_flop == $past(mbuf_entry_bus_err_flop))));

  a_lsu_response_decode: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    response_event |-> (lsu_mmu_resp_entry_dec == id_to_mbuf_vec(lsu_mmu_data_id)));

  a_lsu_data_decode: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_data_vld |-> (lsu_mmu_data_vld_entry == id_to_mbuf_vec(lsu_mmu_data_id)));

  a_lsu_bus_error_decode: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_bus_error |-> (lsu_mmu_bus_error_entry == id_to_mbuf_vec(lsu_mmu_data_id)));

  a_lsu_bus_error_has_data_vld: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_bus_error |-> lsu_mmu_data_vld);

  a_lsu_bus_error_no_normal_writeback_for_rsp_id: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (lsu_mmu_bus_error && legal_mbuf_id(lsu_mmu_data_id))
      |-> (((write_back_req & id_to_mbuf_vec(lsu_mmu_data_id)) == 9'b0)
           && ((write_back_grant & id_to_mbuf_vec(lsu_mmu_data_id)) == 9'b0)));

  a_lsu_bus_error_no_normal_writeback_when_idle: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (lsu_mmu_bus_error && !(|write_back_req)) |-> ((mbuf_twu_data_vld == 4'b0000)
                                                 && (write_back_grant == 9'b0)));

  a_lsu_bus_error_sets_pending: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (lsu_mmu_bus_error && !ptw_abort_drain) |=> mbuf_bus_error);

  a_mbuf_grant_onehot0: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    $onehot0(mbuf_grant));

  a_abort_no_mbuf_create: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_ptw_abort |-> (mbuf_entry_upd == 9'b0));

  a_abort_does_not_directly_clear_entry_on: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (tlboper_ptw_abort && !response_event && !lsu_req_fire)
      |=> (response_event
           || lsu_req_fire
           || (mbuf_entry_on == $past(mbuf_entry_on))));

  a_abort_drain_blocks_new_req: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain |-> !mmu_lsu_data_req);

  a_abort_drain_no_fire: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain |-> !lsu_req_fire);

  a_abort_drain_clears_hold: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain |=> !req_hold_vld);

  a_abort_drain_blocks_new_entry: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain |-> (mbuf_entry_upd == 9'b0));

  a_abort_drain_blocks_cache_update: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain |-> !mbuf_cache_upd);

  a_pde_abort_drain_blocks_cache_update: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain |-> !mbuf_cache_upd);

  a_pde_bus_error_no_cache_update_when_idle: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (lsu_mmu_bus_error
     && !(|write_back_req)
     && !(|write_back_grant)
     && !write_back_grant_any_q) |-> !mbuf_cache_upd);

  a_abort_reg_waits_for_on_clear: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (tlboper_ptw_abort_reg && (|mbuf_entry_on)) |=> tlboper_ptw_abort_reg);

  a_abort_reg_clears_after_on_empty: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (tlboper_ptw_abort_reg && !(|mbuf_entry_on) && !tlboper_ptw_abort)
      |=> !tlboper_ptw_abort_reg);

  a_mbuf_on_changes_only_on_lsu_fire_or_response: assert property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE || !past_valid)
    $changed(mbuf_entry_on) |-> ($past(lsu_req_fire) || $past(response_event)));

  cp_mbuf_grant_onehot: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    $onehot(mbuf_grant)) begin
    cp_mbuf_grant_onehot_hits++;
  end

  cp_lsu_req_fire: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_req_fire);

  cp_lsu_req_id_all: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    seen_req_id_mask == 9'h1ff);

  cp_lsu_two_outstanding: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    count_ones9(mbuf_entry_on) >= 2);

  cp_lsu_max_pressure: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    count_ones9(mbuf_entry_on) >= 4);

  cp_lsu_ooo_response: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ooo_response_pulse);

  cp_lsu_grant_wait: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    grant_wait_2plus_pulse);

  cp_lsu_normal_data: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_data_vld && !lsu_mmu_bus_error) begin
    cp_lsu_normal_data_hits++;
  end

  cp_lsu_bus_error_data_vld: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_data_vld && lsu_mmu_bus_error);

  cp_lsu_bus_error_no_chk: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_bus_error && !(|write_back_req)
    && (mbuf_twu_data_vld == 4'b0000) && (write_back_grant == 9'b0)) begin
    cp_lsu_bus_error_no_chk_hits++;
  end

  cp_pde_bus_error_no_cache_upd_idle: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    lsu_mmu_bus_error
    && !(|write_back_req)
    && !(|write_back_grant)
    && !write_back_grant_any_q
    && !mbuf_cache_upd);

  cp_lsu_bus_error_pending: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    (|mbuf_bus_error_grant) || (|bus_err_write_back_req) || mbuf_bus_error) begin
    cp_lsu_bus_error_pending_hits++;
  end

  cp_lsu_abort_no_create: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_ptw_abort && (mbuf_entry_upd == 9'b0) && (mbuf_entry_vld != 9'b0)) begin
    cp_lsu_abort_no_create_hits++;
  end

  cp_lsu_abort_drain_multi: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    abort_drain_multi_pulse);

  cp_lsu_abort_before_grant: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    abort_before_grant_pulse);

  cp_lsu_abort_drain_no_req: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain && !mmu_lsu_data_req && !mbuf_cache_upd);

  cp_pde_abort_drain_no_cache_upd: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_abort_drain && !mbuf_cache_upd);

  cp_lsu_buserr_by_id: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    buserr_by_id_pulse);

  cp_lsu_invalid_id_ignored: cover property (@(posedge mbuf_clk) disable iff (`L2TLB_NEG_DISABLE)
    invalid_id_ignored_pulse);

  final begin
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_mbuf_grant_onehot req=PTW-SVA-MBUF-001 hits=%0d",
      cp_mbuf_grant_onehot_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_req_fire req=PTW-SVA-LSUID-001 hits=%0d mask=0x%03h",
      cp_lsu_req_fire_hits, seen_req_id_mask);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_req_id_all req=PTW-SVA-LSUID-001 hits=%0d mask=0x%03h",
      cp_lsu_req_id_all_hits, seen_req_id_mask);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_rsp_id_match req=PTW-SVA-LSUID-004 hits=%0d mask=0x%03h",
      cp_lsu_rsp_id_match_hits, seen_rsp_id_mask);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_two_outstanding req=PTW-SVA-LSUID-002 hits=%0d",
      cp_lsu_two_outstanding_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_max_pressure req=PTW-SVA-LSUID-002 hits=%0d",
      cp_lsu_max_pressure_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_ooo_response req=PTW-SVA-LSUID-004 hits=%0d",
      cp_lsu_ooo_response_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_grant_wait req=PTW-SVA-GRANT-001 hits=%0d",
      cp_lsu_grant_wait_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_normal_data req=PTW-SVA-MBUF-006 hits=%0d",
      cp_lsu_normal_data_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_bus_error_data_vld req=PTW-SVA-BUSERR-001 hits=%0d",
      cp_lsu_bus_error_data_vld_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_bus_error_pending req=PTW-SVA-BUSERR-001 hits=%0d",
      cp_lsu_bus_error_pending_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_bus_error_no_chk req=PTW-SVA-BUSERR-001 hits=%0d",
      cp_lsu_bus_error_no_chk_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_buserr_by_id req=PTW-SVA-BUSERR-001 hits=%0d",
      cp_lsu_buserr_by_id_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_invalid_id_ignored req=PTW-SVA-LSUID-006 hits=%0d",
      cp_lsu_invalid_id_ignored_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_no_create req=PTW-SVA-ABDRN-002 hits=%0d",
      cp_lsu_abort_no_create_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_drain_multi req=PTW-SVA-ABDRN-005 hits=%0d",
      cp_lsu_abort_drain_multi_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_before_grant req=PTW-SVA-GRANT-003 hits=%0d",
      cp_lsu_abort_before_grant_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_drain_no_req req=PTW-SVA-ABDRN-003 hits=%0d",
      cp_lsu_abort_drain_no_req_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_lsu_abort_drain_no_cache_upd req=PTW-SVA-ABDRN-004 hits=%0d",
      cp_lsu_abort_drain_no_cache_upd_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_pde_abort_drain_no_cache_upd req=PTW-SVA-PDE-UPD-025 hits=%0d",
      cp_pde_abort_drain_no_cache_upd_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva name=cp_pde_bus_error_no_cache_upd_idle req=PTW-SVA-PDE-UPD-026 hits=%0d",
      cp_pde_bus_error_no_cache_upd_idle_hits);
  end

endmodule
