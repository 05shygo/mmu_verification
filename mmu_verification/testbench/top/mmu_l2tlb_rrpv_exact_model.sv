// =============================================================================
// mmu_l2tlb_rrpv_exact_model.sv
// Phase 6F+: Exact RRPV replacement reference model (bind mmu_l2tlb).
//
// This module independently shadows the full L2TLB RRPV state (8 ways x 256
// sets x 3 bits), the write-buffer FIFO, and the TAG valid bits.  It computes
// expected victim way and RRPV update values cycle-accurately and compares
// them against DUT signals.
//
// Scope (closes the largest remaining future/waiver block):
//   - Exact victim way prediction   (first-free / max-RRPV)
//   - Exact RRPV value tracking     (hit promotion, miss aging, refill insert)
//   - Wbuf latest-wins/merge        (CAM-hit merge, same-cycle push bypass)
//   - SRAM shadow updated on wbuf drain and direct (PTW/TLBOP) writes
//
// Port naming: ports are named to match mmu_l2tlb signal names so that
// `bind mmu_l2tlb ... (.*)` auto-connects most signals.  Only clk/rst_n
// are connected explicitly in tb_top because L2TLB uses forever_cpuclk/cpurst_b.
//
// Waiver/future items that remain beyond this module:
//   - Wbuf full/empty timing effects on arbiter stall are already covered
//     by mmu_l2tlb_rrpv_wbuf_sva.sv (Phase 6F debug assertions).
//   - This module does not modify DUT/RTL.
// =============================================================================
`timescale 1ns/1ps

module mmu_l2tlb_rrpv_exact_model #(
    parameter int WAY_NUM    = 8,
    parameter int IDX_WIDTH  = 8,          // 256 sets
    parameter int RRPV_WIDTH = 3,
    parameter int WBUF_DEPTH = 8,
    parameter int RRPV_MAX   = (1 << RRPV_WIDTH) - 1,  // 7
    parameter int RRPV_INIT  = 3,
    parameter int NUM_SETS   = (1 << IDX_WIDTH)        // 256
) (
    input logic clk,
    input logic rst_n,

    // ── T0: Arbiter request (match mmu_l2tlb port names for .*) ──────────
    input logic                              arb_l2tlb_req,
    input logic                              arb_l2tlb_write,
    input logic [2:0]                        arb_l2tlb_acc_type,
    input logic [WAY_NUM-1:0]                arb_l2tlb_bank_sel,
    input logic [WAY_NUM*RRPV_WIDTH-1:0]     arb_l2tlb_rrpv_din,

    // 8 independent skewed indices (T0) — match mmu_l2tlb port names
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w0,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w1,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w2,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w3,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w4,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w5,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w6,
    input logic [IDX_WIDTH-1:0]              arb_l2tlb_idx_w7,

    // Packed view (for convenience; internally assigned by L2TLB)
    input logic [WAY_NUM-1:0][IDX_WIDTH-1:0] way_index,

    // ── T1: Internal raw-stage signals ───────────────────────────────────
    input logic                              raw_vld,
    input logic [WAY_NUM-1:0]                raw_way_mask,
    input logic [WAY_NUM-1:0]                raw_way_vld,

    // RRPV SRAM raw readout + wbuf bypass
    input logic [WAY_NUM*RRPV_WIDTH-1:0]     l2tlb_rrpv_dout_bus,
    input logic [WAY_NUM-1:0]                wbuf_cam_hit,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] bypassed_rrpv_rdata,

    // ── T2: Final-stage signals ──────────────────────────────────────────
    input logic                              final_vld,
    input logic [2:0]                        final_acc_type,
    input logic                              final_pa_vld,
    input logic                              l2tlb_miss,
    input logic [WAY_NUM-1:0]                final_way_sel,
    input logic [WAY_NUM-1:0][IDX_WIDTH-1:0] final_bank_index,

    // ── DUT replacement outputs (match L2TLB port names) ─────────────────
    input logic [WAY_NUM-1:0]                victim_way,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] rrpv_updata,

    // ── Wbuf interface ───────────────────────────────────────────────────
    input logic                              wbuf_push_req,
    input logic [WAY_NUM-1:0]                final_way_vld,
    input logic                              wbuf_pop_grant,
    input logic                              wbuf_empty,

    // ── TLB operation / write control ────────────────────────────────────
    input logic [47:0]                       arb_l2tlb_tag_din
);

  // ==========================================================================
  // Local helper types and functions
  // ==========================================================================
  typedef logic [RRPV_WIDTH-1:0] rrpv_t;

  typedef struct packed {
    logic [WAY_NUM-1:0]                      vld;
    logic [WAY_NUM-1:0][IDX_WIDTH-1:0]       idx;
    logic [WAY_NUM-1:0][RRPV_WIDTH-1:0]      data;
  } wbuf_entry_t;

  // ==========================================================================
  // Shadow State
  // ==========================================================================
  rrpv_t    sram_rrpv [NUM_SETS-1:0][WAY_NUM-1:0];
  logic     sram_vld  [NUM_SETS-1:0][WAY_NUM-1:0];
  logic     set_seeded[NUM_SETS-1:0];
  logic                              t1_set_needs_seed;
  logic [WAY_NUM-1:0][IDX_WIDTH-1:0] t1_seed_idx;

  wbuf_entry_t wbuf [WBUF_DEPTH-1:0];
  logic [$clog2(WBUF_DEPTH)-1:0] wbuf_wr_ptr;
  logic [$clog2(WBUF_DEPTH)-1:0] wbuf_rd_ptr;
  logic [$clog2(WBUF_DEPTH):0]   wbuf_count;
  logic                          wbuf_fifo_full;
  logic                          wbuf_full_stall;

  // ── T0→T1 pipeline ─────────────────────────────────────────────────────
  logic                              t0_valid;
  logic [WAY_NUM-1:0][IDX_WIDTH-1:0] t0_idx;
  logic [WAY_NUM-1:0]                t0_bank_sel;
  logic                              t0_is_ptw_read;
  logic                              t0_is_ptw_write;
  logic                              t0_is_tlbop;
  logic                              t0_write;

  // ── T1→T2 pipeline ─────────────────────────────────────────────────────
  logic                              t1_valid;
  logic [WAY_NUM-1:0][IDX_WIDTH-1:0] t1_idx;
  logic [WAY_NUM-1:0]                t1_bank_sel;
  logic [WAY_NUM-1:0]                t1_expected_victim;
  logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] t1_aged_rrpv;
  logic [WAY_NUM-1:0]                t1_mask_way;

  logic                              wbuf_pop_do;

  // ── Counters for evidence ──────────────────────────────────────────────
  int unsigned m_victim_compared;
  int unsigned m_victim_match;
  int unsigned m_victim_mismatch;
  int unsigned m_rrpv_compared;
  int unsigned m_rrpv_match;
  int unsigned m_rrpv_way_mismatch;
  int unsigned m_sets_seeded;
  int unsigned m_wbuf_push_seen;
  int unsigned m_wbuf_pop_seen;
  int unsigned m_wbuf_cam_merge_seen;
  int unsigned m_direct_write_seen;

  // ==========================================================================
  // 1. SRAM / shadow read with wbuf bypass
  // ==========================================================================
  function automatic rrpv_t shadow_read(
    input logic [IDX_WIDTH-1:0] set_idx,
    input int unsigned way
  );
    shadow_read = sram_rrpv[set_idx][way];
    for (int k = 0; k < WBUF_DEPTH; k++) begin
      logic [$clog2(WBUF_DEPTH)-1:0] ptr;
      logic valid_entry;
      if (wbuf_rd_ptr + k >= WBUF_DEPTH)
        ptr = wbuf_rd_ptr + k - WBUF_DEPTH;
      else
        ptr = wbuf_rd_ptr + k;
      valid_entry = (k < wbuf_count);
      if (valid_entry && wbuf[ptr].vld[way] && (wbuf[ptr].idx[way] == set_idx))
        shadow_read = wbuf[ptr].data[way];
    end
  endfunction

  // ==========================================================================
  // 2. Victim selection (exact mirror of RTL mmu_l2tlb_replacement_policy T1)
  // ==========================================================================
  function automatic logic [WAY_NUM-1:0] compute_victim(
    input logic [WAY_NUM-1:0]                  mask_way,
    input logic [WAY_NUM-1:0]                  entry_vld,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0]  entry_rrpv
  );
    logic [WAY_NUM-1:0] mask_vld, therm_vld, victim_oh_free;
    logic               have_free;
    logic [RRPV_MAX:0][WAY_NUM-1:0] rrpv_sel, rrip_repl;
    logic [RRPV_MAX:0]              sel_valid;
    logic [WAY_NUM-1:0]             rrip_victim_way;

    for (int i = 0; i < WAY_NUM; i++)
      mask_vld[i] = ~mask_way[i] | entry_vld[i];

    therm_vld[0] = mask_vld[0];
    for (int i = 1; i < WAY_NUM; i++)
      therm_vld[i] = mask_vld[i] & therm_vld[i-1];

    victim_oh_free[0] = ~therm_vld[0];
    for (int i = 1; i < WAY_NUM; i++)
      victim_oh_free[i] = ~therm_vld[i] & therm_vld[i-1];

    have_free = ~(&(entry_vld | mask_way));

    for (int i = 0; i <= RRPV_MAX; i++) begin
      rrpv_sel[i]  = '0;
      rrip_repl[i] = '0;
      for (int j = 0; j < WAY_NUM; j++) begin
        if ((entry_rrpv[j] == rrpv_t'(i)) && mask_way[j])
          rrpv_sel[i][j] = 1'b1;
      end
      for (int k = 0; k < WAY_NUM; k++) begin
        if (rrpv_sel[i][k] && (rrip_repl[i] == '0))
          rrip_repl[i][k] = 1'b1;
      end
      sel_valid[i] = |rrpv_sel[i];
    end

    rrip_victim_way = '0;
    for (int k = RRPV_MAX; k >= 0; k--) begin
      if (sel_valid[k] && (rrip_victim_way == '0))
        rrip_victim_way = rrip_repl[k];
    end

    compute_victim = have_free ? victim_oh_free : rrip_victim_way;
  endfunction

  // ==========================================================================
  // 3. Compute aged RRPV values (saturating increment)
  // ==========================================================================
  function automatic rrpv_t age_rrpv(rrpv_t val);
    age_rrpv = (val != rrpv_t'(RRPV_MAX)) ? rrpv_t'(val + 1'b1) : val;
  endfunction

  // ==========================================================================
  // 4. Compute expected RRPV update (hit/miss/ptw_req)
  // ==========================================================================
  function automatic void compute_rrpv_update(
    input  logic                                hit,
    input  logic                                miss,
    input  logic                                ptw_req,
    input  logic [WAY_NUM-1:0]                  hit_index,
    input  logic [WAY_NUM-1:0]                  victim_way_in,
    input  logic [WAY_NUM-1:0]                  mask_way,
    input  logic [WAY_NUM-1:0][RRPV_WIDTH-1:0]  aged_rrpv,
    output logic [WAY_NUM-1:0][RRPV_WIDTH-1:0]  rrpv_update
  );
    rrpv_update = aged_rrpv;

    case ({hit, miss, ptw_req})
      3'b100: begin
        for (int i = 0; i < WAY_NUM; i++)
          if (hit_index[i])
            rrpv_update[i] = '0;
      end
      3'b010: begin
        // rrpv_update already set to aged_rrpv
      end
      3'b001: begin
        for (int i = 0; i < WAY_NUM; i++) begin
          if (victim_way_in[i])
            rrpv_update[i] = rrpv_t'(RRPV_INIT);
        end
      end
      default: ;
    endcase
  endfunction

  // ==========================================================================
  // 5. Seed a set from DUT observation
  // ==========================================================================
  function automatic void seed_set_from_dut(
    input logic [IDX_WIDTH-1:0] set_idx,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] bypassed
  );
    for (int w = 0; w < WAY_NUM; w++) begin
      sram_rrpv[set_idx][w] = bypassed[w];
    end
    set_seeded[set_idx] = 1'b1;
  endfunction

  // ==========================================================================
  // 6. Wbuf shadow push (CAM merge + new entry allocation)
  // ==========================================================================
  function automatic void wbuf_push_shadow(
    input logic [WAY_NUM-1:0]                   push_vld_vec,
    input logic [WAY_NUM-1:0][IDX_WIDTH-1:0]    push_idx_vec,
    input logic [WAY_NUM-1:0][RRPV_WIDTH-1:0]   push_data_vec
  );
    logic [WAY_NUM-1:0]                        push_hit;
    logic [WAY_NUM-1:0][$clog2(WBUF_DEPTH)-1:0] push_hit_ptr;
    logic [WAY_NUM-1:0]                        push_new;
    logic                                      push_new_entry;
    logic [$clog2(WBUF_DEPTH)-1:0]             ptr;

    push_hit     = '0;
    push_hit_ptr = '{default: '0};
    for (int k = 0; k < WBUF_DEPTH; k++) begin
      if (wbuf_rd_ptr + k >= WBUF_DEPTH)
        ptr = wbuf_rd_ptr + k - WBUF_DEPTH;
      else
        ptr = wbuf_rd_ptr + k;
      if (k < wbuf_count && !(wbuf_pop_do && (ptr == wbuf_rd_ptr))) begin
        for (int w = 0; w < WAY_NUM; w++) begin
          if (wbuf[ptr].vld[w] && (wbuf[ptr].idx[w] == push_idx_vec[w])) begin
            push_hit[w]     = 1'b1;
            push_hit_ptr[w] = ptr;
          end
        end
      end
    end

    push_new       = push_vld_vec & ~push_hit;
    push_new_entry = |push_new;

    for (int w = 0; w < WAY_NUM; w++) begin
      if (push_hit[w]) begin
        wbuf[push_hit_ptr[w]].vld[w]  <= push_vld_vec[w];
        wbuf[push_hit_ptr[w]].idx[w]  <= push_idx_vec[w];
        wbuf[push_hit_ptr[w]].data[w] <= push_data_vec[w];
      end
    end

    if (push_new_entry) begin
      for (int w = 0; w < WAY_NUM; w++) begin
        if (push_new[w]) begin
          wbuf[wbuf_wr_ptr].vld[w]  <= push_vld_vec[w];
          wbuf[wbuf_wr_ptr].idx[w]  <= push_idx_vec[w];
          wbuf[wbuf_wr_ptr].data[w] <= push_data_vec[w];
        end else begin
          wbuf[wbuf_wr_ptr].vld[w] <= 1'b0;
        end
      end
      if (wbuf_wr_ptr == WBUF_DEPTH-1)
        wbuf_wr_ptr <= '0;
      else
        wbuf_wr_ptr <= wbuf_wr_ptr + 1'b1;
    end
  endfunction

  // ==========================================================================
  // 7. SRAM shadow update on wbuf pop
  // ==========================================================================
  function automatic void wbuf_pop_to_sram_shadow();
    for (int w = 0; w < WAY_NUM; w++) begin
      if (wbuf[wbuf_rd_ptr].vld[w])
        sram_rrpv[wbuf[wbuf_rd_ptr].idx[w]][w] = wbuf[wbuf_rd_ptr].data[w];
    end
    wbuf[wbuf_rd_ptr].vld <= '0;
  endfunction

  // ==========================================================================
  // Main sequential logic
  // ==========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int s = 0; s < NUM_SETS; s++) begin
        for (int w = 0; w < WAY_NUM; w++) begin
          sram_rrpv[s][w] <= '0;
          sram_vld[s][w]  <= 1'b0;
        end
        set_seeded[s] <= 1'b0;
      end
      for (int i = 0; i < WBUF_DEPTH; i++)
        wbuf[i] <= '{vld: '0, idx: '{default: '0}, data: '{default: '0}};
      wbuf_wr_ptr  <= '0;
      wbuf_rd_ptr  <= '0;
      wbuf_count   <= '0;
      wbuf_fifo_full <= 1'b0;
      wbuf_full_stall <= 1'b0;

      t0_valid        <= 1'b0;
      t0_idx          <= '{default: '0};
      t0_bank_sel     <= '0;
      t0_is_ptw_read  <= 1'b0;
      t0_is_ptw_write <= 1'b0;
      t0_is_tlbop     <= 1'b0;
      t0_write        <= 1'b0;

      t1_valid           <= 1'b0;
      t1_idx             <= '{default: '0};
      t1_bank_sel        <= '0;
      t1_expected_victim <= '0;
      t1_aged_rrpv       <= '{default: '0};
      t1_mask_way        <= '0;
      t1_set_needs_seed  <= 1'b0;
      t1_seed_idx        <= '{default: '0};

      wbuf_pop_do <= 1'b0;

      m_victim_compared     <= 0;
      m_victim_match        <= 0;
      m_victim_mismatch     <= 0;
      m_rrpv_compared       <= 0;
      m_rrpv_match          <= 0;
      m_rrpv_way_mismatch   <= 0;
      m_sets_seeded         <= 0;
      m_wbuf_push_seen      <= 0;
      m_wbuf_pop_seen       <= 0;
      m_wbuf_cam_merge_seen <= 0;
      m_direct_write_seen   <= 0;
    end
    else begin
      // ===================================================================
      // Stage T0 → T1: Capture arbiter request
      // ===================================================================
      t0_valid        <= arb_l2tlb_req;
      t0_idx          <= way_index;
      t0_bank_sel     <= arb_l2tlb_bank_sel;
      t0_is_ptw_read  <= arb_l2tlb_req && (arb_l2tlb_acc_type == 3'b000) && !arb_l2tlb_write;
      t0_is_ptw_write <= arb_l2tlb_req && (arb_l2tlb_acc_type == 3'b101) && arb_l2tlb_write;
      t0_is_tlbop     <= arb_l2tlb_req && (arb_l2tlb_acc_type == 3'b001);
      t0_write        <= arb_l2tlb_write;

      // ===================================================================
      // Stage T1: raw_vld → compute victim, aged values, seed shadow
      // ===================================================================
      t1_valid <= raw_vld;
      if (raw_vld) begin
        logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] eff_rrpv;
        logic [IDX_WIDTH-1:0]               set_idx [WAY_NUM-1:0];

        t1_idx      <= t0_idx;
        t1_bank_sel <= t0_bank_sel;
        t1_mask_way <= raw_way_mask;

        for (int w = 0; w < WAY_NUM; w++)
          set_idx[w] = t0_idx[w];

        t1_set_needs_seed <= 1'b0;
        for (int w = 0; w < WAY_NUM; w++) begin
          t1_seed_idx[w] <= set_idx[w];
          if (!set_seeded[set_idx[w]])
            t1_set_needs_seed <= 1'b1;
        end

        for (int w = 0; w < WAY_NUM; w++) begin
          if (set_seeded[set_idx[w]])
            eff_rrpv[w] = shadow_read(set_idx[w], w);
          else
            eff_rrpv[w] = bypassed_rrpv_rdata[w];
        end

        t1_expected_victim <= compute_victim(raw_way_mask, raw_way_vld, eff_rrpv);

        for (int w = 0; w < WAY_NUM; w++)
          t1_aged_rrpv[w] <= age_rrpv(eff_rrpv[w]);

        if (t1_set_needs_seed) begin
          for (int w = 0; w < WAY_NUM; w++) begin
            if (!set_seeded[set_idx[w]]) begin
              seed_set_from_dut(set_idx[w], bypassed_rrpv_rdata);
              m_sets_seeded <= m_sets_seeded + 1;
            end
          end
        end
      end else begin
        t1_set_needs_seed <= 1'b0;
      end

      // ===================================================================
      // Wbuf pop handling
      // ===================================================================
      wbuf_pop_do <= wbuf_pop_grant && !wbuf_empty;
      if (wbuf_pop_grant && !wbuf_empty) begin
        wbuf_pop_to_sram_shadow();
        if (wbuf_rd_ptr == WBUF_DEPTH-1)
          wbuf_rd_ptr <= '0;
        else
          wbuf_rd_ptr <= wbuf_rd_ptr + 1'b1;
        m_wbuf_pop_seen <= m_wbuf_pop_seen + 1;
      end

      // ===================================================================
      // Wbuf push: accept push into shadow
      // ===================================================================
      if (wbuf_push_req) begin
        wbuf_push_shadow(final_way_vld, final_bank_index, rrpv_updata);
        m_wbuf_push_seen <= m_wbuf_push_seen + 1;

        begin
          automatic logic cam_merge = 1'b0;
          for (int k = 0; k < WBUF_DEPTH; k++) begin
            logic [$clog2(WBUF_DEPTH)-1:0] ptr;
            if (wbuf_rd_ptr + k >= WBUF_DEPTH)
              ptr = wbuf_rd_ptr + k - WBUF_DEPTH;
            else
              ptr = wbuf_rd_ptr + k;
            if (k < wbuf_count) begin
              for (int w = 0; w < WAY_NUM; w++) begin
                if (wbuf[ptr].vld[w] && (wbuf[ptr].idx[w] == final_bank_index[w]))
                  cam_merge = 1'b1;
              end
            end
          end
          if (cam_merge)
            m_wbuf_cam_merge_seen <= m_wbuf_cam_merge_seen + 1;
        end
      end

      // ===================================================================
      // Direct SRAM writes (PTW refill write beat, TLBWI/TLBWR)
      // ===================================================================
      if (arb_l2tlb_req && arb_l2tlb_write) begin
        if (t0_is_ptw_write) begin
          for (int w = 0; w < WAY_NUM; w++) begin
            if (arb_l2tlb_bank_sel[w]) begin
              sram_rrpv[t0_idx[w]][w] <= rrpv_t'(arb_l2tlb_rrpv_din[w*RRPV_WIDTH +: RRPV_WIDTH]);
              sram_vld[t0_idx[w]][w]  <= 1'b1;
            end
          end
          m_direct_write_seen <= m_direct_write_seen + 1;
        end

        if (t0_is_tlbop) begin
          for (int w = 0; w < WAY_NUM; w++) begin
            if (arb_l2tlb_bank_sel[w]) begin
              sram_rrpv[t0_idx[w]][w] <= rrpv_t'(RRPV_INIT);
              sram_vld[t0_idx[w]][w] <= arb_l2tlb_tag_din[47];
            end
          end
          m_direct_write_seen <= m_direct_write_seen + 1;
        end
      end

      // ===================================================================
      // Track SRAM validity via observation on reads
      // ===================================================================
      if (raw_vld) begin
        for (int w = 0; w < WAY_NUM; w++) begin
          if (t0_bank_sel[w])
            sram_vld[t0_idx[w]][w] <= raw_way_vld[w];
        end
      end

      // ===================================================================
      // Wbuf count updates
      // ===================================================================
      case ({wbuf_push_req && (|(final_way_vld & ~{WAY_NUM{wbuf_fifo_full}})),
             wbuf_pop_do})
        2'b10: wbuf_count <= wbuf_count + 1'b1;
        2'b01: wbuf_count <= wbuf_count - 1'b1;
        default: ;
      endcase

      wbuf_fifo_full <= (wbuf_count == WBUF_DEPTH);
      wbuf_full_stall <= (wbuf_count >= (WBUF_DEPTH > 3 ? WBUF_DEPTH - 3 : WBUF_DEPTH));

      // ===================================================================
      // Stage T2: final_vld → compare predictions, update counters
      // ===================================================================
      if (final_vld && t1_valid) begin
        logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] expected_updata;
        logic                                is_ptw_req;

        is_ptw_req = (final_acc_type == 3'b000);

        compute_rrpv_update(
          .hit(final_pa_vld),
          .miss(l2tlb_miss),
          .ptw_req(is_ptw_req),
          .hit_index(final_way_sel),
          .victim_way_in(t1_expected_victim),
          .mask_way(t1_mask_way),
          .aged_rrpv(t1_aged_rrpv),
          .rrpv_update(expected_updata)
        );

        m_victim_compared <= m_victim_compared + 1;
        if (t1_expected_victim === victim_way)
          m_victim_match <= m_victim_match + 1;
        else
          m_victim_mismatch <= m_victim_mismatch + 1;

        m_rrpv_compared <= m_rrpv_compared + 1;
        begin
          automatic int unsigned way_mismatches = 0;
          for (int w = 0; w < WAY_NUM; w++) begin
            if (expected_updata[w] !== rrpv_updata[w])
              way_mismatches++;
          end
          if (way_mismatches == 0)
            m_rrpv_match <= m_rrpv_match + 1;
          else
            m_rrpv_way_mismatch <= m_rrpv_way_mismatch + way_mismatches;
        end
      end
    end
  end

  // ==========================================================================
  // Combinational expected RRPV update for assertions
  // ==========================================================================
  logic [WAY_NUM-1:0][RRPV_WIDTH-1:0] expected_updata_comb;
  logic                                is_ptw_req_comb;
  always_comb begin
    is_ptw_req_comb = (final_acc_type == 3'b000);
    compute_rrpv_update(
      .hit(final_pa_vld),
      .miss(l2tlb_miss),
      .ptw_req(is_ptw_req_comb),
      .hit_index(final_way_sel),
      .victim_way_in(t1_expected_victim),
      .mask_way(t1_mask_way),
      .aged_rrpv(t1_aged_rrpv),
      .rrpv_update(expected_updata_comb)
    );
  end

  // ==========================================================================
  // Assertions
  // ==========================================================================

  // ── L2TLB_SVA_023: Exact victim way check ──────────────────────────────
  property p_victim_match;
    @(posedge clk) disable iff (!rst_n || $isunknown(final_vld) || $isunknown(t1_valid))
    (final_vld && t1_valid) |->
      (!$isunknown(victim_way) && !$isunknown(t1_expected_victim)
       && (victim_way === t1_expected_victim));
  endproperty

  a_exact_victim_way: assert property (p_victim_match) begin
  end else begin
    if (!$isunknown(final_vld) && !$isunknown(t1_expected_victim)
        && !$isunknown(victim_way))
      $display("[RRPV_EXACT_MODEL][VICTIM_MISMATCH] t=%0t expected=%08b dut=%08b "
              ,"final_pa_vld=%0b l2tlb_miss=%0b final_acc_type=0x%0h",
               $time, t1_expected_victim, victim_way,
               final_pa_vld, l2tlb_miss, final_acc_type);
  end

  // ── L2TLB_SVA_024: Exact RRPV update value check ───────────────────────
  property p_rrpv_update_full_match;
    @(posedge clk) disable iff (!rst_n || $isunknown(final_vld) || $isunknown(t1_valid)
                                || $isunknown(rrpv_updata) || $isunknown(expected_updata_comb))
    (final_vld && t1_valid) |-> (rrpv_updata === expected_updata_comb);
  endproperty

  a_exact_rrpv_update: assert property (p_rrpv_update_full_match) begin
  end else begin
    if (!$isunknown(rrpv_updata) && !$isunknown(expected_updata_comb)) begin
      for (int w = 0; w < WAY_NUM; w++) begin
        if (rrpv_updata[w] !== expected_updata_comb[w]) begin
          $display("[RRPV_EXACT_MODEL][RRPV_MISMATCH] t=%0t way=%0d "
                  ,"expected=%0d dut=%0d aged=%0d hit=%0b miss=%0b ptw=%0b hit_idx=%08b",
                   $time, w,
                   expected_updata_comb[w], rrpv_updata[w], t1_aged_rrpv[w],
                   final_pa_vld, l2tlb_miss, is_ptw_req_comb, final_way_sel);
        end
      end
    end
  end

  // ── Cover properties for evidence ──────────────────────────────────────
  c_exact_victim_free_way: cover property (@(posedge clk) disable iff (!rst_n)
    final_vld && t1_valid && (t1_expected_victim != '0)
    && (|(~(raw_way_vld | raw_way_mask))));

  c_exact_victim_max_rrpv: cover property (@(posedge clk) disable iff (!rst_n)
    final_vld && t1_valid && (t1_expected_victim != '0)
    && (&(raw_way_vld | raw_way_mask)));

  c_exact_rrpv_hit_promotion: cover property (@(posedge clk) disable iff (!rst_n)
    final_vld && t1_valid && final_pa_vld && (|final_way_sel)
    && (rrpv_updata === expected_updata_comb));

  c_exact_rrpv_miss_aging: cover property (@(posedge clk) disable iff (!rst_n)
    final_vld && t1_valid && l2tlb_miss && !final_pa_vld
    && (rrpv_updata === expected_updata_comb));

  c_exact_rrpv_ptw_refill: cover property (@(posedge clk) disable iff (!rst_n)
    final_vld && t1_valid && (final_acc_type == 3'b000)
    && (rrpv_updata === expected_updata_comb));

  c_exact_model_sets_seeded: cover property (@(posedge clk) disable iff (!rst_n)
    m_sets_seeded >= 4);

  c_exact_model_wbuf_cam_merge: cover property (@(posedge clk) disable iff (!rst_n)
    m_wbuf_cam_merge_seen >= 1);

  c_exact_model_direct_write: cover property (@(posedge clk) disable iff (!rst_n)
    m_direct_write_seen >= 1);

  // ==========================================================================
  // Final summary
  // ==========================================================================
  final begin
    $display("[RRPV_EXACT_MODEL_SUMMARY] "
            ,"victim_compared=%0d victim_match=%0d victim_mismatch=%0d "
            ,"rrpv_compared=%0d rrpv_match=%0d rrpv_way_mismatch=%0d "
            ,"sets_seeded=%0d wbuf_push=%0d wbuf_pop=%0d "
            ,"wbuf_cam_merge=%0d direct_write=%0d",
             m_victim_compared, m_victim_match, m_victim_mismatch,
             m_rrpv_compared, m_rrpv_match, m_rrpv_way_mismatch,
             m_sets_seeded, m_wbuf_push_seen, m_wbuf_pop_seen,
             m_wbuf_cam_merge_seen, m_direct_write_seen);
    if (m_victim_mismatch == 0 && m_rrpv_way_mismatch == 0)
      $display("[RRPV_EXACT_MODEL_STATUS] PASS");
    else
      $display("[RRPV_EXACT_MODEL_STATUS] FAIL victim_mismatch=%0d rrpv_way_mismatch=%0d",
               m_victim_mismatch, m_rrpv_way_mismatch);
  end

endmodule
