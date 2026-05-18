// =============================================================================
// PTW-ADD-040: L2 tag hit, cached L2 PMP deny direct access fault
//
// Corrected spec note:
//   The old construction used MPRV=1/MPP=M data access to bypass cached L1
//   pmpflg while denying cached L2 pmpflg. That data access no longer enters
//   PTW by spec, so this top-level source test records the exact L2-only deny
//   isolation as open instead of driving illegal/unreachable traffic.
// =============================================================================
`ifndef TEST_PTW_PDE_L2_PMP_L2_DENY_ACCERR_001_SVH
`define TEST_PTW_PDE_L2_PMP_L2_DENY_ACCERR_001_SVH

class test_ptw_pde_l2_pmp_l2_deny_accerr_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_l2_pmp_l2_deny_accerr_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP",
      "stage8_l2_cached_l2pmp_deny_accerr_unreachable_top_source");
    ptw_meta_add_req("PTW-ADD-040");
    ptw_meta_add_req("PDE-TP-015");
    ptw_meta_add_req("PTW-FLOW-026");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h30, STAGE8_ROOT_ASID + 16'h30,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    ptw_meta_add_context(
      "old_construction_used_data_mprv1_mppm_to_bypass_cached_l1pmpflg");
    ptw_meta_add_context(
      "corrected_spec_data_pfu_mprv1_mppm_direct_map_va_eq_pa_no_ptw_source");
    ptw_meta_set_expected({"Exact L2-only cached-pmpflg deny cannot be isolated ",
      "with top-level data MPRV=1 MPP=M source traffic; use legal S/U request ",
      "stimulus with independently controllable L1/L2 cached pmpflg or lower-level ",
      "PDE-cache unit stimulus."});
    ptw_meta_set_actual("no_source_request_driven_unreachable_by_spec");
    ptw_meta_set_result("stage8_open_unreachable_top_source");
    ptw_meta_print();

    stage8_open("PTW-ADD-040,PDE-TP-015,PTW-FLOW-026",
      "stage8_l2_cached_l2pmp_deny_accerr",
      {"corrected spec removes MPRV=1/MPP=M data PTW source path used by the ",
       "old construction; keep L1-deny and same-flag L2 direct-accerr evidence, ",
       "but exact L2-only isolation needs a different legal stimulus or lower-level ",
       "PDE-cache injection."});
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_pde_l2_pmp_l2_deny_accerr_001

`endif // TEST_PTW_PDE_L2_PMP_L2_DENY_ACCERR_001_SVH
