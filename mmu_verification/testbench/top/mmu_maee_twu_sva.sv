// =============================================================================
// MAEE / TWU path select SVA (bind twu) - Phase 12
// Focus: protect the implemented MAEE mux points in twu.sv.
// Note: current RTL exposes MAEE CSR-vs-refill selection on FST/SCD only.
// THD has no thd_chk_csr_req signal, so Phase 12 assertions stay on FST/SCD.
// =============================================================================
`timescale 1ns/1ps

module mmu_maee_twu_sva (
    input logic twu_clk,
    input logic cpurst_b,
    input logic cp0_mmu_maee,
    input logic fst_chk_vld,
    input logic fst_chk_leaf_vld,
    input logic fst_chk_page_flt,
    input logic fst_chk_refill_req,
    input logic fst_chk_csr_req,
    input logic thd_chk_vld,
    input logic thd_chk_page_flt,
    input logic thd_chk_refill_req,
    input logic thd_chk_refill_no_maee_sel,
    input logic scd_chk_vld,
    input logic scd_chk_leaf_vld,
    input logic scd_chk_page_flt,
    input logic scd_chk_refill_req,
    input logic scd_chk_csr_req
);

  logic fst_leaf_nonfault;
  logic scd_leaf_nonfault;
  integer cov_hits_paths_mutex;
  integer cov_hits_maee0_csr;
  integer cov_hits_maee1_refill;
  integer cov_hits_thd_maee0_sysmap;

  assign fst_leaf_nonfault = fst_chk_vld && fst_chk_leaf_vld && !fst_chk_page_flt;
  assign scd_leaf_nonfault = scd_chk_vld && scd_chk_leaf_vld && !scd_chk_page_flt;

  always @(posedge twu_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      cov_hits_paths_mutex <= 0;
      cov_hits_maee0_csr   <= 0;
      cov_hits_maee1_refill <= 0;
      cov_hits_thd_maee0_sysmap <= 0;
    end else begin
      if ((fst_chk_csr_req ^ fst_chk_refill_req) || (scd_chk_csr_req ^ scd_chk_refill_req))
        cov_hits_paths_mutex <= cov_hits_paths_mutex + 1;

      if (!cp0_mmu_maee
          && ((fst_leaf_nonfault && fst_chk_csr_req && !fst_chk_refill_req)
              || (scd_leaf_nonfault && scd_chk_csr_req && !scd_chk_refill_req)))
        cov_hits_maee0_csr <= cov_hits_maee0_csr + 1;

      if (cp0_mmu_maee
          && ((fst_leaf_nonfault && fst_chk_refill_req && !fst_chk_csr_req)
              || (scd_leaf_nonfault && scd_chk_refill_req && !scd_chk_csr_req)))
        cov_hits_maee1_refill <= cov_hits_maee1_refill + 1;

      if (!cp0_mmu_maee && thd_chk_vld && !thd_chk_page_flt
          && thd_chk_refill_req && thd_chk_refill_no_maee_sel)
        cov_hits_thd_maee0_sysmap <= cov_hits_thd_maee0_sysmap + 1;
    end
  end

  // Verification intent: the same stage must not drive both MAEE paths together.
  sva_twu_maee_paths_mutex: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    !(fst_chk_csr_req && fst_chk_refill_req)
    && !(scd_chk_csr_req && scd_chk_refill_req));

  cp_twu_maee_paths_mutex: cover property (@(posedge twu_clk) disable iff (!cpurst_b)
    (fst_chk_csr_req ^ fst_chk_refill_req) || (scd_chk_csr_req ^ scd_chk_refill_req));

  // Verification intent: with MAEE=0, a legal leaf result must enter the CSR path.
  sva_maee0_triggers_csr_req: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    !cp0_mmu_maee |-> (
      (!fst_leaf_nonfault || (fst_chk_csr_req && !fst_chk_refill_req))
      && (!scd_leaf_nonfault || (scd_chk_csr_req && !scd_chk_refill_req))));

  cp_maee0_triggers_csr_req: cover property (@(posedge twu_clk) disable iff (!cpurst_b)
    !cp0_mmu_maee
    && ((fst_leaf_nonfault && fst_chk_csr_req && !fst_chk_refill_req)
        || (scd_leaf_nonfault && scd_chk_csr_req && !scd_chk_refill_req)));

  // Verification intent: with MAEE=1, a legal leaf result must bypass the CSR FSM.
  sva_maee1_skips_csr_fsm: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    cp0_mmu_maee |-> (
      (!fst_leaf_nonfault || (fst_chk_refill_req && !fst_chk_csr_req))
      && (!scd_leaf_nonfault || (scd_chk_refill_req && !scd_chk_csr_req))));

  cp_maee1_skips_csr_fsm: cover property (@(posedge twu_clk) disable iff (!cpurst_b)
    cp0_mmu_maee
    && ((fst_leaf_nonfault && fst_chk_refill_req && !fst_chk_csr_req)
        || (scd_leaf_nonfault && scd_chk_refill_req && !scd_chk_csr_req)));

  // Verification intent: MAEE=0 4K leaf also substitutes SysMap attributes.
  cp_maee0_thd_sysmap_refill: cover property (@(posedge twu_clk) disable iff (!cpurst_b)
    !cp0_mmu_maee && thd_chk_vld && !thd_chk_page_flt
    && thd_chk_refill_req && thd_chk_refill_no_maee_sel);

  final begin
    $display("PHASE12_MAEE_COVER instance=%m prop=cp_twu_maee_paths_mutex hits=%0d", cov_hits_paths_mutex);
    $display("PHASE12_MAEE_COVER instance=%m prop=cp_maee0_triggers_csr_req hits=%0d", cov_hits_maee0_csr);
    $display("PHASE12_MAEE_COVER instance=%m prop=cp_maee1_skips_csr_fsm hits=%0d", cov_hits_maee1_refill);
    $display("PHASE12_MAEE_COVER instance=%m prop=cp_maee0_thd_sysmap_refill hits=%0d", cov_hits_thd_maee0_sysmap);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_twu_maee_paths_mutex req=PTW-SVA-MAEE-003 hits=%0d", cov_hits_paths_mutex);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee0_triggers_csr_req req=PTW-SVA-MAEE-002 hits=%0d", cov_hits_maee0_csr);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee1_skips_csr_fsm req=PTW-SVA-MAEE-001 hits=%0d", cov_hits_maee1_refill);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee0_thd_sysmap_refill req=PTW-SVA-MAEE-002 hits=%0d", cov_hits_thd_maee0_sysmap);
  end

endmodule
