// =============================================================================
// PTW-ADD-043: effective-M cached-pmpflg lock/bypass matrix
//
// Corrected spec note:
//   - load/store/PFU with real priv S/U, MPRV=1, MPP=M direct-map VA=PA and
//     cannot generate a PTW source request.
//   - fetch ignores MPRV/MPP and uses real pipeline privilege.
//   - Therefore this top-level PTW source test records the original stage-9
//     matrix as unreachable from legal data/PFU source stimulus.
// =============================================================================
`ifndef TEST_PTW_PDE_MMODE_LOCK_MATRIX_001_SVH
`define TEST_PTW_PDE_MMODE_LOCK_MATRIX_001_SVH

class test_ptw_pde_mmode_lock_matrix_001 extends ptw_pde_pmpflg_stage9_base;

  `uvm_component_utils(test_ptw_pde_mmode_lock_matrix_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP",
      "stage9_mmode_lock_matrix_top_source_unreachable");
    ptw_meta_add_req("PTW-ADD-043");
    ptw_meta_add_req("PDE-TP-018");
    ptw_meta_add_req("PTW-FLOW-028");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h13, STAGE9_ROOT_ASID + 16'h13,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    ptw_meta_add_context(
      "corrected_spec_data_pfu_mprv1_mppm_direct_map_va_eq_pa_no_ptw_source");
    ptw_meta_add_context(
      "fetch_ignores_mprv_mpp_and_uses_real_pipeline_privilege");
    ptw_meta_set_expected({"No load/store/PFU l2tlb_ptw_req is legal when ",
      "real priv=S/U and MPRV=1 MPP=M; effective-M cached-pmpflg lock/bypass ",
      "matrix is not top-level PTW-source reachable under the corrected spec."});
    ptw_meta_set_actual("no_source_request_driven_unreachable_by_spec");
    ptw_meta_set_result("stage9_open_unreachable_top_source");
    ptw_meta_print();

    stage9_open("PTW-ADD-043,PDE-TP-018,PTW-FLOW-028",
      "stage9_mmode_lock_matrix",
      {"corrected spec makes data/PFU MPRV=1 MPP=M direct-map with no PTW ",
       "source request; fetch cannot represent data effective-M because it ",
       "uses real pipeline privilege. Close this matrix only with lower-level ",
       "PDE-cache stimulus or RTL unit evidence, not top-level source traffic."});
    stage9_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_pde_mmode_lock_matrix_001

`endif // TEST_PTW_PDE_MMODE_LOCK_MATRIX_001_SVH
