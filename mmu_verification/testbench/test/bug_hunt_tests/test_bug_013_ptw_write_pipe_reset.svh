// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-013
// F-ID: F5.NEW.2  Priority: P1  Status: Planned
// Checker: sva_ptw_write_pipe_reset_safe  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_013_PTW_WRITE_PIPE_RESET_SVH
`define TEST_BUG_013_PTW_WRITE_PIPE_RESET_SVH

class test_bug_013_ptw_write_pipe_reset extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_013_ptw_write_pipe_reset)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-013";
    p11_fid      = "F5.NEW.2";
    p11_priority = "P1";
    p11_status   = "Planned";
    p11_seq_desc = "mmu_reset_midtransaction_vseq";
    p11_checker  = "sva_ptw_write_pipe_reset_safe";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 800ns;
    m_vseq_names.push_back("mmu_reset_midtransaction_vseq");
  endfunction

endclass : test_bug_013_ptw_write_pipe_reset

`endif // TEST_BUG_013_PTW_WRITE_PIPE_RESET_SVH
