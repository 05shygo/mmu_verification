// ----------------------------------------------------------------------------
// Copyright 2024 CEA*
// *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// [END OF HEADER]
// ----------------------------------------------------------------------------

`include "uvm_macros.svh"

module hpdcache_plru_sva
  import hpdcache_pkg::*;
  import hpdcache_common_pkg::*;
  import uvm_pkg::*;
#(
    parameter hpdcache_cfg_t hpdcacheCfg = '0,

    // -------------------------------------------------------------------------
    // Safe defaults for standalone compilation:
    // - Keep types legal even before bind overrides them.
    // - Bind from top.sv should override these with real package types.
    // -------------------------------------------------------------------------
    parameter type hpdcache_nline_t       = logic,
    parameter type hpdcache_tag_t         = logic,
    parameter type hpdcache_set_t         = logic,
    parameter type hpdcache_word_t        = logic,
    parameter type hpdcache_way_vector_t  = logic [0:0],
    parameter type hpdcache_dir_entry_t   = logic,

    parameter type hpdcache_data_word_t   = logic,
    parameter type hpdcache_data_be_t     = logic,

    parameter type hpdcache_req_data_t    = logic,
    parameter type hpdcache_req_be_t      = logic,

    parameter type hpdcache_refill_data_t = logic,
    parameter type hpdcache_refill_be_t   = logic
)
(
    // Global clock and reset
    input  logic                                clk_i,
    input  logic                                rst_ni,

    // Global control
    input  logic                                ready_o,

    // DIR array access interface
    input  logic                                dir_match_i,
    input  hpdcache_set_t                       dir_match_set_i,
    input  hpdcache_tag_t                       dir_match_tag_i,
    input  logic                                dir_update_lru_i,
    input  hpdcache_way_vector_t                dir_hit_way_o,

    input  logic                                dir_amo_match_i,
    input  hpdcache_set_t                       dir_amo_match_set_i,
    input  hpdcache_tag_t                       dir_amo_match_tag_i,
    input  logic                                dir_amo_update_plru_i,
    input  hpdcache_way_vector_t                dir_amo_hit_way_o,

    input  logic                                dir_refill_sel_victim_i,
    input  logic                                dir_refill_i,
    input  hpdcache_set_t                       dir_refill_set_i,
    input  hpdcache_dir_entry_t                 dir_refill_entry_i,
    input  logic                                dir_refill_updt_plru_i,
    input  hpdcache_way_vector_t                dir_victim_way_o,

    input  logic                                dir_inval_check_i,
    input  hpdcache_nline_t                     dir_inval_nline_i,
    input  logic                                dir_inval_write_i,
    input  logic                                dir_inval_hit_o,

    input  logic                                dir_cmo_check_i,
    input  hpdcache_set_t                       dir_cmo_check_set_i,
    input  hpdcache_tag_t                       dir_cmo_check_tag_i,
    input  hpdcache_way_vector_t                dir_cmo_check_hit_way_o,

    input  logic                                dir_cmo_inval_i,
    input  hpdcache_set_t                       dir_cmo_inval_set_i,
    input  hpdcache_way_vector_t                dir_cmo_inval_way_i,

    // DATA array access interface
    input  logic                                data_req_read_i,
    input  hpdcache_set_t                       data_req_read_set_i,
    input  hpdcache_req_size_t                  data_req_read_size_i,
    input  hpdcache_word_t                      data_req_read_word_i,
    input  hpdcache_req_data_t                  data_req_read_data_o,

    input  logic                                data_req_write_i,
    input  logic                                data_req_write_enable_i,
    input  hpdcache_set_t                       data_req_write_set_i,
    input  hpdcache_req_size_t                  data_req_write_size_i,
    input  hpdcache_word_t                      data_req_write_word_i,
    input  hpdcache_req_data_t                  data_req_write_data_i,
    input  hpdcache_req_be_t                    data_req_write_be_i,

    input  logic                                data_amo_write_i,
    input  logic                                data_amo_write_enable_i,
    input  hpdcache_set_t                       data_amo_write_set_i,
    input  hpdcache_req_size_t                  data_amo_write_size_i,
    input  hpdcache_word_t                      data_amo_write_word_i,
    input  hpdcache_req_data_t                  data_amo_write_data_i,
    input  hpdcache_req_be_t                    data_amo_write_be_i,

    input  logic                                data_refill_i,
    input  hpdcache_way_vector_t                data_refill_way_i,
    input  hpdcache_set_t                       data_refill_set_i,
    input  hpdcache_word_t                      data_refill_word_i,
    input  hpdcache_refill_data_t               data_refill_data_i
);

  // ---------------------------------------------------------------------------
  // Protect standalone compilation from hpdcacheCfg='0 (sets/ways == 0)
  // ---------------------------------------------------------------------------
  localparam int unsigned SVA_WAYS = ((hpdcacheCfg.u.ways > 0) ? hpdcacheCfg.u.ways : 1);
  localparam int unsigned SVA_SETS = ((hpdcacheCfg.u.sets > 0) ? hpdcacheCfg.u.sets : 1);

  // ---------------------------------------------------------------------------
  // Local directory-entry struct used for safe casting of dir_refill_entry_i
  // ---------------------------------------------------------------------------
  typedef struct packed {
    bit            status;
    hpdcache_tag_t tag;
  } hpdcache_tag_dir_t;

  hpdcache_tag_dir_t dir_refill_entry_casted;
  assign dir_refill_entry_casted = dir_refill_entry_i;

  // ---------------------------------------------------------------------------
  // Internal state mirrors
  // ---------------------------------------------------------------------------
  bit               [SVA_WAYS-1:0] m_bPLRU_table [SVA_SETS];
  hpdcache_tag_dir_t               m_tag_dir     [SVA_SETS][SVA_WAYS];

  hpdcache_set_t dir_match_set_q;
  hpdcache_set_t dir_amo_match_set_q;
  hpdcache_set_t dir_refill_set_q;
  hpdcache_tag_t dir_match_tag_q;

  // Derived indices
  int way, idx;
  int idx0, idx1, way1, idx2;

  // ---------------------------------------------------------------------------
  // Queue selected set/tag values
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dir_match_set_q     <= '0;
      dir_amo_match_set_q <= '0;
      dir_refill_set_q    <= '0;
      dir_match_tag_q     <= '0;
    end
    else begin
      dir_match_set_q     <= dir_match_set_i;
      dir_amo_match_set_q <= dir_amo_match_set_i;
      dir_refill_set_q    <= dir_refill_set_i;
      dir_match_tag_q     <= dir_match_tag_i;
    end
  end

  // ---------------------------------------------------------------------------
  // Combinational helpers for refill/hit bookkeeping
  // ---------------------------------------------------------------------------
  always_comb begin
    way  = -1;
    idx  = -1;
    idx0 = -1;
    idx1 = -1;
    way1 = -1;
    idx2 = -1;

    if (dir_refill_i) begin
      way = get_index_from_tag_dir(dir_refill_set_i, dir_refill_entry_casted.tag);
      idx = get_index_from_plru(dir_refill_set_i, way);
    end

    if (dir_update_lru_i) begin
      idx0 = get_index_from_tag_dir_hit(dir_match_set_q, dir_match_tag_i);
    end

    if (dir_amo_update_plru_i) begin
      idx1 = get_index_from_tag_dir_hit(dir_amo_match_set_q, dir_amo_match_tag_i);
    end

    if (dir_refill_updt_plru_i) begin
      way1 = get_index_from_tag_dir(dir_refill_set_i, dir_refill_entry_casted.tag);
      idx2 = get_index_from_plru(dir_refill_set_i, way1);
    end
  end

  // ---------------------------------------------------------------------------
  // Tag directory shadow model
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int s = 0; s < SVA_SETS; s++) begin
        for (int w = 0; w < SVA_WAYS; w++) begin
          m_tag_dir[s][w].status <= 1'b0;
          m_tag_dir[s][w].tag    <= '0;
        end
      end
    end
    else if (dir_cmo_inval_i) begin
      for (int w = 0; w < SVA_WAYS; w++) begin
        if (dir_cmo_inval_way_i[w] == 1'b1) begin
          m_tag_dir[dir_cmo_inval_set_i][w].status <= 1'b0;
        end
      end
    end
    else if (dir_refill_i) begin
      // Hit in tag dir or empty slot found
      if (way >= 0 && way < SVA_WAYS) begin
        m_tag_dir[dir_refill_set_i][way].status <= 1'b1;
        m_tag_dir[dir_refill_set_i][way].tag    <= dir_refill_entry_casted.tag;
      end
      // Fallback to PLRU-selected way
      else if (idx >= 0 && idx < SVA_WAYS) begin
        m_tag_dir[dir_refill_set_i][idx].status <= 1'b1;
        m_tag_dir[dir_refill_set_i][idx].tag    <= dir_refill_entry_casted.tag;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // PLRU shadow model
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int s = 0; s < SVA_SETS; s++) begin
        m_bPLRU_table[s] <= '0;
      end
    end
    else if (dir_update_lru_i) begin
      if (idx0 >= 0 && idx0 < SVA_WAYS) begin
        if (($countones(m_bPLRU_table[dir_match_set_q]) == (SVA_WAYS - 1)) &&
            (m_bPLRU_table[dir_match_set_q][idx0] == 1'b0)) begin
          m_bPLRU_table[dir_match_set_q] <= '0;
        end
        m_bPLRU_table[dir_match_set_q][idx0] <= 1'b1;
      end
    end
    else if (dir_amo_update_plru_i) begin
      if (idx1 >= 0 && idx1 < SVA_WAYS) begin
        if (($countones(m_bPLRU_table[dir_amo_match_set_q]) == (SVA_WAYS - 1)) &&
            (m_bPLRU_table[dir_amo_match_set_q][idx1] == 1'b0)) begin
          m_bPLRU_table[dir_amo_match_set_q] <= '0;
        end
        m_bPLRU_table[dir_amo_match_set_q][idx1] <= 1'b1;
      end
    end
    else if (dir_refill_updt_plru_i) begin
      if (idx2 >= 0 && idx2 < SVA_WAYS) begin
        if ((m_bPLRU_table[dir_refill_set_i][idx2] == 1'b0) &&
            ($countones(m_bPLRU_table[dir_refill_set_i]) == (SVA_WAYS - 1))) begin
          m_bPLRU_table[dir_refill_set_i] <= '0;
        end
        m_bPLRU_table[dir_refill_set_i][idx2] <= 1'b1;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Helper functions
  // ---------------------------------------------------------------------------
  function automatic void cache_hit_update_bPLRU(hpdcache_set_t set, int index);
    if (($countones(m_bPLRU_table[set]) == (SVA_WAYS - 1)) &&
        (m_bPLRU_table[set][index] == 1'b0)) begin
      m_bPLRU_table[set] = '0;
    end
    m_bPLRU_table[set][index] = 1'b1;
  endfunction

  function automatic int cache_miss_get_way(hpdcache_set_t set);
    int index;
    index = -1;
    for (int w = 0; w < SVA_WAYS; w++) begin
      if (m_bPLRU_table[set][w] == 1'b0) begin
        index = w;
        break;
      end
    end
    `uvm_info("SB PLRU UPDATE", $sformatf("PLRU index %0d(d)", index), UVM_HIGH);
    return index;
  endfunction

  function automatic int get_index_from_plru(hpdcache_set_t set, int idx_in);
    int index;
    index = -1;

    if (idx_in < 0) begin
      for (int w = 0; w < SVA_WAYS; w++) begin
        if (m_bPLRU_table[set][w] == 1'b0) begin
          index = w;
          break;
        end
      end
    end
    else begin
      index = idx_in;
    end
    return index;
  endfunction

  function automatic int get_index_from_tag_dir_hit(hpdcache_set_t set, hpdcache_tag_t tag);
    int index;
    index = -1;

    for (int w = 0; w < SVA_WAYS; w++) begin
      if ((m_tag_dir[set][w].status == 1'b1) && (m_tag_dir[set][w].tag == tag)) begin
        index = w;
        `uvm_info("SB CACHE HIT PLRU SEARCH",
                  $sformatf("status %0d(d) set %0d(d) tag %0x(x) index %0d(d)",
                            m_tag_dir[set][index].status, set, m_tag_dir[set][index].tag, index),
                  UVM_DEBUG);
        break;
      end
    end
    return index;
  endfunction

  function automatic int get_index_from_tag_dir(hpdcache_set_t set, hpdcache_tag_t tag);
    int index;
    index = -1;

    // 1) exact match
    for (int w = 0; w < SVA_WAYS; w++) begin
      if ((m_tag_dir[set][w].status == 1'b1) && (m_tag_dir[set][w].tag == tag)) begin
        index = w;
        break;
      end
    end

    // 2) empty slot
    if (index < 0) begin
      for (int w = 0; w < SVA_WAYS; w++) begin
        if (m_tag_dir[set][w].status == 1'b0) begin
          index = w;
          break;
        end
      end
    end

    return index;
  endfunction

endmodule
