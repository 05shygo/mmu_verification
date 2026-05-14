// =============================================================================
// Phase 9 legacy wrapper for PTW-017.
//
// Stage 6 PTW source-side update:
//   The old reserved/RSW fault expectation is obsolete-by-spec.  PTE[58:38]
//   and RSW do not cause PTW page fault; RSW enters refill flg.  This wrapper
//   is retained only as legacy metadata and must not count as source closure.
// =============================================================================
`ifndef TEST_PTE_RESERVED_BITS_SVH
`define TEST_PTE_RESERVED_BITS_SVH

class test_pte_reserved_bits extends phase9_generated_test_base;

  `uvm_component_utils(test_pte_reserved_bits)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-017-OBSOLETE-RESERVED-FAULT";
    p9_seq_desc = "obsolete-by-spec: reserved/RSW fault expected removed; use stage6 PTE layout source tests";
    p9_checker = "not_source_closure; use test_ptw_p0_pte_layout_matrix";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    // Do not inject the old illegal-PTE sequence for normal P0 closure; it
    // encoded the retired reserved-bit fault assumption.
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_pte_reserved_bits

`endif // TEST_PTE_RESERVED_BITS_SVH
