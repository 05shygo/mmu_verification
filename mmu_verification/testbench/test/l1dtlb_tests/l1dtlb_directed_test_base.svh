// =============================================================================
// Shared base for Chapter-3 L1DTLB directed test wrappers.
// Each leaf wrapper supplies one TC_ID; phase9_generated_test_base dispatches it
// to l1dtlb_directed_vseq.
// =============================================================================
`ifndef L1DTLB_DIRECTED_TEST_BASE_SVH
`define L1DTLB_DIRECTED_TEST_BASE_SVH

class l1dtlb_directed_test_base extends phase9_generated_test_base;

  `uvm_component_utils(l1dtlb_directed_test_base)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function string get_l1dtlb_tc_id();
    return "UNSPECIFIED_L1DTLB_TC";
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = get_l1dtlb_tc_id();
    p9_seq_desc = "l1dtlb_directed_vseq";
    p9_checker = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    p9_reviewer = "B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
  endfunction

endclass : l1dtlb_directed_test_base

`endif // L1DTLB_DIRECTED_TEST_BASE_SVH
