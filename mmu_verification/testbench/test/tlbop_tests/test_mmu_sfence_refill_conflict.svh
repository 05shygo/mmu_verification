// =============================================================================
// Phase 9 generated test wrapper for TC-SFENCE-017
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_SFENCE_REFILL_CONFLICT_SVH
`define TEST_MMU_SFENCE_REFILL_CONFLICT_SVH

class test_mmu_sfence_refill_conflict extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sfence_refill_conflict)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SFENCE-017";
    p9_seq_desc = "ptw_mem_normal_rsp_seq + tlb_inv_all_seq + mmu_ptw_thrash_vseq";
    p9_checker = "invalidation_sb";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_lsu_seq_names.push_back("tlb_inv_all_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

  // Drain all in-flight TLB invalidations before starting the PTW thrash
  // traffic.  Without this barrier, INV_ALL completions can overlap with
  // active PTW walks and trigger a DUT-level zero-delay loop (observed on
  // seed 5 where bringup latency shifts the INV_ALL window into the fork).
  virtual task run_test_body();
    setup_plan();

    if (l1dtlb_directed_vseq::is_l1dtlb_tc(p9_tc_id)) begin
      if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
      start_l1dtlb_directed_by_tc_id(p9_tc_id);
      #(m_post_drain);
      return;
    end

    if (m_run_misc_init)  start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();

    foreach (m_cp0_seq_names[i])    start_cp0_seq_by_name(m_cp0_seq_names[i]);
    foreach (m_pmp_seq_names[i])    start_pmp_seq_by_name(m_pmp_seq_names[i]);
    foreach (m_sysmap_seq_names[i]) start_sysmap_seq_by_name(m_sysmap_seq_names[i]);
    foreach (m_misc_seq_names[i])   start_misc_seq_by_name(m_misc_seq_names[i]);
    foreach (m_ptw_seq_names[i])    start_ptw_seq_by_name(m_ptw_seq_names[i]);
    foreach (m_ifu_seq_names[i])    start_ifu_seq_by_name(m_ifu_seq_names[i]);
    foreach (m_lsu_seq_names[i])    start_lsu_seq_by_name(m_lsu_seq_names[i]);

    // Wait for all LSU INV_ALL operations to drain before starting PTW thrash.
    m_env.wait_for_quiescent_midtest("sfence_pre_thrash_drain", 262144, 16);

    foreach (m_vseq_names[i])       start_vseq_by_name(m_vseq_names[i]);

    #(m_post_drain);
  endtask

endclass : test_mmu_sfence_refill_conflict

`endif // TEST_MMU_SFENCE_REFILL_CONFLICT_SVH
