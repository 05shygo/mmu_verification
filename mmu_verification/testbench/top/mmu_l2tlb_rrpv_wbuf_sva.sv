// =============================================================================
// L2TLB RRPV write-buffer SVA (bind mmu_l2tlb_rrpv_wbuf).
//
// Phase6F scope:
// - Check debug-visible no-overflow / no-underflow / accept accounting.
// - Do not check exact RRPV values, victim selection, latest-wins, or
//   same-cycle bypass data. Those remain future exact-model items.
// =============================================================================
`timescale 1ns/1ps

module mmu_l2tlb_rrpv_wbuf_sva #(
    parameter int WAY_NUM     = 8,
    parameter int IDX_WIDTH   = 8,
    parameter int RRPV_WIDTH  = 3,
    parameter int DEPTH       = 8,
    parameter int PTR_WIDTH   = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    parameter int COUNT_WIDTH = $clog2(DEPTH) + 1,
    parameter int STALL_LEVEL = (DEPTH > 3) ? (DEPTH - 3) : DEPTH
) (
    input logic clk,
    input logic rst_n,

    input logic push_req,
    input logic [WAY_NUM-1:0][IDX_WIDTH-1:0] push_idx,
    input logic [WAY_NUM-1:0] push_vld,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] push_data,
    input logic full,

    input logic pop_grant,
    input logic empty,
    input logic [WAY_NUM-1:0] sram_vld,
    input logic [WAY_NUM-1:0][IDX_WIDTH-1:0] sram_idx,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] sram_data,

    input logic [WAY_NUM-1:0][IDX_WIDTH-1:0] lookup_idx,
    input logic lookup_req,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] bypassed_rrpv_rdata,
    input logic [WAY_NUM-1:0] lookup_hit,

    // Internal debug/accounting state from the bind target.
    input logic [PTR_WIDTH-1:0] wr_ptr,
    input logic [PTR_WIDTH-1:0] rd_ptr,
    input logic [COUNT_WIDTH-1:0] count,
    input logic [WAY_NUM-1:0] push_hit_comb,
    input logic [WAY_NUM-1:0] push_new_bank,
    input logic push_new_entry,
    input logic push_accept,
    input logic pop_do,
    input logic fifo_full
);

  function automatic logic [COUNT_WIDTH-1:0] depth_count();
    depth_count = COUNT_WIDTH'(DEPTH);
  endfunction

  function automatic logic [COUNT_WIDTH-1:0] stall_count();
    stall_count = COUNT_WIDTH'(STALL_LEVEL);
  endfunction

  function automatic logic push_payload_known();
    push_payload_known = !$isunknown(push_vld);
    for (int w = 0; w < WAY_NUM; w++) begin
      if (push_vld[w]) begin
        push_payload_known &= !$isunknown(push_idx[w]);
        push_payload_known &= !$isunknown(push_data[w]);
      end
    end
  endfunction

  function automatic logic head_payload_known();
    head_payload_known = !$isunknown(sram_vld);
    for (int w = 0; w < WAY_NUM; w++) begin
      if (sram_vld[w]) begin
        head_payload_known &= !$isunknown(sram_idx[w]);
        head_payload_known &= !$isunknown(sram_data[w]);
      end
    end
  endfunction

  // L2TLB_SVA_022: reset must clear the write-buffer accounting state.
  a_reset_clears_wbuf: assert property (@(posedge clk)
    !rst_n |-> (count == '0 && empty && !full && !fifo_full));

  // L2TLB_SVA_022: no overflow, no underflow, and exposed status flags match
  // the internal accounting state. Note: full is an early arbiter-stall level,
  // not necessarily count==DEPTH.
  a_count_known_and_in_range: assert property (@(posedge clk) disable iff (!rst_n)
    !$isunknown(count) && (count <= depth_count()));

  a_empty_matches_count: assert property (@(posedge clk) disable iff (!rst_n)
    empty == (count == '0));

  a_fifo_full_matches_count: assert property (@(posedge clk) disable iff (!rst_n)
    fifo_full == (count == depth_count()));

  a_full_matches_stall_level: assert property (@(posedge clk) disable iff (!rst_n)
    full == (count >= stall_count()));

  a_pop_do_only_when_not_empty: assert property (@(posedge clk) disable iff (!rst_n)
    pop_do |-> (pop_grant && !empty));

  a_empty_pop_does_not_decrement: assert property (@(posedge clk) disable iff (!rst_n)
    (pop_grant && empty) |-> !pop_do);

  // A new FIFO slot may not be accepted when the FIFO is truly full unless a
  // pop happens in the same cycle. CAM-hit-only updates are allowed because
  // they do not increase occupancy.
  a_true_full_blocks_new_entry_without_pop: assert property (@(posedge clk) disable iff (!rst_n)
    (push_req && push_new_entry && fifo_full && !pop_do) |-> !push_accept);

  a_cam_hit_only_push_may_accept_when_full: assert property (@(posedge clk) disable iff (!rst_n)
    (push_req && !push_new_entry && fifo_full) |-> push_accept);

  a_push_accept_implies_request: assert property (@(posedge clk) disable iff (!rst_n)
    push_accept |-> push_req);

  a_push_new_bank_consistent: assert property (@(posedge clk) disable iff (!rst_n)
    push_new_bank == (push_vld & ~push_hit_comb));

  a_push_new_entry_consistent: assert property (@(posedge clk) disable iff (!rst_n)
    push_new_entry == (|push_new_bank));

  // Accounting update checks. These intentionally check occupancy only; exact
  // RRPV data content and latest-wins ordering are future exact-model scope.
  a_push_only_increments_count: assert property (@(posedge clk) disable iff (!rst_n)
    (push_accept && push_new_entry && !pop_do)
      |=> count == ($past(count) + COUNT_WIDTH'(1)));

  a_pop_only_decrements_count: assert property (@(posedge clk) disable iff (!rst_n)
    (!(push_accept && push_new_entry) && pop_do)
      |=> count == ($past(count) - COUNT_WIDTH'(1)));

  a_push_pop_keeps_count: assert property (@(posedge clk) disable iff (!rst_n)
    (push_accept && push_new_entry && pop_do)
      |=> count == $past(count));

  a_cam_update_only_keeps_count: assert property (@(posedge clk) disable iff (!rst_n)
    (push_accept && !push_new_entry && !pop_do)
      |=> count == $past(count));

  a_idle_keeps_count: assert property (@(posedge clk) disable iff (!rst_n)
    (!(push_accept && push_new_entry) && !pop_do)
      |=> count == $past(count));

  a_push_payload_known: assert property (@(posedge clk) disable iff (!rst_n)
    push_req |-> push_payload_known());

  a_head_payload_known_when_nonempty: assert property (@(posedge clk) disable iff (!rst_n)
    !empty |-> head_payload_known());

  a_lookup_payload_known: assert property (@(posedge clk) disable iff (!rst_n)
    lookup_req |-> !$isunknown(lookup_idx));

  a_lookup_result_known_after_sample: assert property (@(posedge clk) disable iff (!rst_n)
    lookup_req |=> (!$isunknown(lookup_hit) && !$isunknown(bypassed_rrpv_rdata)));

  // Trigger evidence for Phase6F/6G closure extraction.
  c_rrpv_wbuf_push_new_entry: cover property (@(posedge clk) disable iff (!rst_n)
    push_accept && push_new_entry);

  c_rrpv_wbuf_cam_hit_update: cover property (@(posedge clk) disable iff (!rst_n)
    push_accept && !push_new_entry && (|push_hit_comb));

  c_rrpv_wbuf_pop: cover property (@(posedge clk) disable iff (!rst_n)
    pop_do);

  c_rrpv_wbuf_full_seen: cover property (@(posedge clk) disable iff (!rst_n)
    full);

  c_rrpv_wbuf_true_full_block: cover property (@(posedge clk) disable iff (!rst_n)
    push_req && push_new_entry && fifo_full && !pop_do && !push_accept);

  c_rrpv_wbuf_full_release: cover property (@(posedge clk) disable iff (!rst_n)
    full && pop_do);

  c_rrpv_wbuf_push_pop_same_cycle: cover property (@(posedge clk) disable iff (!rst_n)
    push_accept && push_new_entry && pop_do);

  c_rrpv_wbuf_lookup_bypass_hit: cover property (@(posedge clk) disable iff (!rst_n)
    lookup_req ##1 (|lookup_hit));

endmodule
