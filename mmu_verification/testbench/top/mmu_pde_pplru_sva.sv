// =============================================================================
// PTW PDE PPLRU SVA - Phase 9
// Bind target: pplru
// =============================================================================
`timescale 1ns/1ps

module mmu_pde_pplru_sva #(
    parameter int PDE_ENTRY_NUM = 16,
    parameter int PDE_INDEX_WIDTH = (PDE_ENTRY_NUM <= 1) ? 1 : $clog2(PDE_ENTRY_NUM)
) (
    input logic                         forever_cpuclk,
    input logic                         cpurst_b,
    input logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_vld,
    input logic                         PDE_plru_refill_vld,
    input logic [PDE_ENTRY_NUM-1:0]     plru_PDE_ref_num,
    input logic                         plru_write_updt,
    input logic [PDE_INDEX_WIDTH-1:0]   write_num,
    input logic [PDE_INDEX_WIDTH-1:0]   plru_num
);

  int unsigned cp_pplru_write_num_match_hits;
  int unsigned cp_pplru_all_invalid_way0_hits;
  int unsigned cp_pplru_way0_valid_way1_hits;
  int unsigned cp_pplru_way01_valid_way2_hits;
  int unsigned cp_pplru_full_valid_plru_hits;

  function automatic logic [PDE_ENTRY_NUM-1:0] pde_idx_onehot(
    input logic [PDE_INDEX_WIDTH-1:0] idx
  );
    pde_idx_onehot = '0;
    if (!$isunknown(idx)) begin
      for (int i = 0; i < PDE_ENTRY_NUM; i++) begin
        if (idx == i)
          pde_idx_onehot[i] = 1'b1;
      end
    end
  endfunction

  a_pplru_write_updt_matches_refill_vld: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt == PDE_plru_refill_vld);

  a_pplru_refill_onehot_matches_write_num: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt |-> (!$isunknown(write_num)
                      && !$isunknown(plru_PDE_ref_num)
                      && $onehot(plru_PDE_ref_num)
                      && (plru_PDE_ref_num == pde_idx_onehot(write_num))));

  a_pplru_all_invalid_selects_way0: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt && (PDE_plru_read_vld == '0)
    |-> (plru_PDE_ref_num == pde_idx_onehot('0)));

  generate
    if (PDE_ENTRY_NUM > 1) begin : gen_way1_sva
      a_pplru_way0_valid_selects_way1: assert property (@(posedge forever_cpuclk)
        disable iff (!cpurst_b)
        plru_write_updt && (PDE_plru_read_vld == pde_idx_onehot('0))
        |-> (plru_PDE_ref_num == pde_idx_onehot(1)));

      cp_pplru_way0_valid_way1: cover property (@(posedge forever_cpuclk)
        disable iff (!cpurst_b)
        plru_write_updt && (PDE_plru_read_vld == pde_idx_onehot('0))
        && (plru_PDE_ref_num == pde_idx_onehot(1))) begin
        cp_pplru_way0_valid_way1_hits++;
      end
    end

    if (PDE_ENTRY_NUM > 2) begin : gen_way2_sva
      a_pplru_way01_valid_selects_way2: assert property (@(posedge forever_cpuclk)
        disable iff (!cpurst_b)
        plru_write_updt && (PDE_plru_read_vld == (pde_idx_onehot('0) | pde_idx_onehot(1)))
        |-> (plru_PDE_ref_num == pde_idx_onehot(2)));

      cp_pplru_way01_valid_way2: cover property (@(posedge forever_cpuclk)
        disable iff (!cpurst_b)
        plru_write_updt && (PDE_plru_read_vld == (pde_idx_onehot('0) | pde_idx_onehot(1)))
        && (plru_PDE_ref_num == pde_idx_onehot(2))) begin
        cp_pplru_way01_valid_way2_hits++;
      end
    end
  endgenerate

  a_pplru_full_valid_selects_plru_way: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt && (&PDE_plru_read_vld)
    |-> (plru_PDE_ref_num == pde_idx_onehot(plru_num)));

  cp_pplru_write_num_match: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt && (plru_PDE_ref_num == pde_idx_onehot(write_num))) begin
    cp_pplru_write_num_match_hits++;
  end

  cp_pplru_all_invalid_way0: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt && (PDE_plru_read_vld == '0)
    && (plru_PDE_ref_num == pde_idx_onehot('0))) begin
    cp_pplru_all_invalid_way0_hits++;
  end

  cp_pplru_full_valid_plru: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    plru_write_updt && (&PDE_plru_read_vld)
    && (plru_PDE_ref_num == pde_idx_onehot(plru_num))) begin
    cp_pplru_full_valid_plru_hits++;
  end

  final begin
    $display("PTW_SVA_COVER module=mmu_pde_pplru_sva name=cp_pplru_write_num_match req=PTW-SVA-PDE-UPD-020 hits=%0d", cp_pplru_write_num_match_hits);
    $display("PTW_SVA_COVER module=mmu_pde_pplru_sva name=cp_pplru_all_invalid_way0 req=PTW-SVA-PDE-UPD-021 hits=%0d", cp_pplru_all_invalid_way0_hits);
    $display("PTW_SVA_COVER module=mmu_pde_pplru_sva name=cp_pplru_way0_valid_way1 req=PTW-SVA-PDE-UPD-021 hits=%0d", cp_pplru_way0_valid_way1_hits);
    $display("PTW_SVA_COVER module=mmu_pde_pplru_sva name=cp_pplru_way01_valid_way2 req=PTW-SVA-PDE-UPD-021 hits=%0d", cp_pplru_way01_valid_way2_hits);
    $display("PTW_SVA_COVER module=mmu_pde_pplru_sva name=cp_pplru_full_valid_plru req=PTW-SVA-PDE-UPD-021 hits=%0d", cp_pplru_full_valid_plru_hits);
  end

endmodule
