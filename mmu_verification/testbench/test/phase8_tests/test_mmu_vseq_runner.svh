// =============================================================================
// Phase 8 — single harness: +VSEQ_NAME=<class> selects one of 14 vseq classes.
// Default: mmu_smoke_vseq.  Optional: +VSEQ_NUM_TXN=<n> (see mmu_base_vseq).
// =============================================================================
`ifndef TEST_MMU_VSEQ_RUNNER_SVH
`define TEST_MMU_VSEQ_RUNNER_SVH

class test_mmu_vseq_runner extends test_base;
  `uvm_component_utils(test_mmu_vseq_runner)

  string vseq_name;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    vseq_name = "mmu_smoke_vseq";
  endfunction

  virtual function void build_phase(uvm_phase phase);
    if (!($value$plusargs("VSEQ_NAME=%s", vseq_name)))
      vseq_name = "mmu_smoke_vseq";
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Phase8 vseq harness: VSEQ_NAME=%s (plusarg override)", vseq_name), UVM_LOW)
  endfunction

  virtual task run_test_body();
    mmu_base_vseq bseq;
    uvm_object      o;
    case (vseq_name)
      "mmu_smoke_vseq":                o = mmu_smoke_vseq::type_id::create("vseq");
      "mmu_concurrent_3pipe_vseq":     o = mmu_concurrent_3pipe_vseq::type_id::create("vseq");
      "mmu_ptw_thrash_vseq":           o = mmu_ptw_thrash_vseq::type_id::create("vseq");
      "mmu_sfence_during_walk_vseq":   o = mmu_sfence_during_walk_vseq::type_id::create("vseq");
      "mmu_asid_context_switch_vseq":  o = mmu_asid_context_switch_vseq::type_id::create("vseq");
      "mmu_huge_page_mix_vseq":        o = mmu_huge_page_mix_vseq::type_id::create("vseq");
      "mmu_rrpv_aging_vseq":           o = mmu_rrpv_aging_vseq::type_id::create("vseq");
      "mmu_l2tlb_bank_conflict_vseq":   o = mmu_l2tlb_bank_conflict_vseq::type_id::create("vseq");
      "mmu_satp_hotswap_vseq":         o = mmu_satp_hotswap_vseq::type_id::create("vseq");
      "mmu_stress_all_ports_vseq":     o = mmu_stress_all_ports_vseq::type_id::create("vseq");
      "mmu_power_gating_vseq":         o = mmu_power_gating_vseq::type_id::create("vseq");
      "mmu_reset_midtransaction_vseq":  o = mmu_reset_midtransaction_vseq::type_id::create("vseq");
      "mmu_error_rain_vseq":           o = mmu_error_rain_vseq::type_id::create("vseq");
      "mmu_perf_bench_vseq":           o = mmu_perf_bench_vseq::type_id::create("vseq");
      default: begin
        `uvm_fatal(get_type_name(), $sformatf("Unknown VSEQ_NAME=%s (see test_mmu_vseq_runner.svh list)", vseq_name))
      end
    endcase
    if (!$cast(bseq, o))
      `uvm_fatal(get_type_name(), "Internal: vseq cast failed")
    if (!bseq.randomize())
      `uvm_fatal(get_type_name(), "VSEQ randomize() failed (check mmu_base_vseq constraints / num_txn)");
    bseq.start(m_env.m_vseqr);
  endtask

endclass : test_mmu_vseq_runner

`endif // TEST_MMU_VSEQ_RUNNER_SVH
