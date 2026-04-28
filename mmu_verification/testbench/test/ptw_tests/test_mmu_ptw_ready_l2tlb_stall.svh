// =============================================================================
// Phase 12 generated test wrapper for TC-PTW-READY-003
// F-ID: F4.NEW.6  Priority: P0  Status: Implemented
// Checker: sva_ptw_l2tlb_ready_when_all_mask + cg_ptw_ready_transition
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PTW_READY_L2TLB_STALL_SVH
`define TEST_MMU_PTW_READY_L2TLB_STALL_SVH

class test_mmu_ptw_ready_l2tlb_stall extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_ptw_ready_l2tlb_stall)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "ptw_ready";
    p12_trace_id = "TC-PTW-READY-003";
    p12_fid      = "F4.NEW.6";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "ptw_mem_slow_rsp_seq + mmu_ptw_thrash_vseq";
    p12_checker  = "sva_ptw_l2tlb_ready_when_all_mask + cg_ptw_ready_transition";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_ptw_ready_l2tlb_stall

`endif // TEST_MMU_PTW_READY_L2TLB_STALL_SVH
