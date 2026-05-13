// =============================================================================
// PTW source-side SVA placeholder
//
// Stage 1 scope only: compile a named source-side SVA unit and define the
// machine-readable cover summary format. No assertions or default bind are
// enabled in this stage.
// =============================================================================
`timescale 1ns/1ps

module mmu_ptw_source_sva;

  initial begin
    if ($test$plusargs("PTW_SOURCE_SVA_BANNER")) begin
      $display("PTW_SVA_COVER module=mmu_ptw_source_sva name=stage1_placeholder hits=0 provisional=1");
    end
  end

endmodule

`ifdef PTW_SOURCE_SVA_BIND_STAGE1
bind ct_mmu_top mmu_ptw_source_sva u_mmu_ptw_source_sva();
`endif
