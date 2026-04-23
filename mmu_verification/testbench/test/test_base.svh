// =============================================================================
// MMU UVM Verification — testbench/test/test_base.svh
// Phase 3 (Batch 2): Base test class — instantiates mmu_env and mmu_top_cfg.
// All Phase 3+ tests extend this class and override run_test_body().
//
// Usage in derived tests:
//   class test_mmu_xxx extends test_base;
//     virtual task run_test_body(); ... endtask
//   endclass
// =============================================================================
`ifndef TEST_BASE_SVH
`define TEST_BASE_SVH

class test_base extends uvm_test;

  `uvm_component_utils(test_base)

  // ── Handles ───────────────────────────────────────────────────────────────
  mmu_env     m_env;
  mmu_top_cfg m_cfg;

  // ── Plusarg knobs (overridable via +NB_TXNS=<n> and +TIMEOUT=<ns>) ────────
  int unsigned num_txn    = 5000;
  int unsigned timeout_ns = 10_000_000;

  // ── Constructor ───────────────────────────────────────────────────────────
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ── Build phase ───────────────────────────────────────────────────────────
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Parse plusargs (override defaults if provided on command line)
    void'($value$plusargs("NB_TXNS=%0d",  num_txn));
    void'($value$plusargs("TIMEOUT=%0d",  timeout_ns));

    // Obtain or create the top-level configuration object
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg)) begin
      `uvm_info(get_type_name(),
                "mmu_top_cfg not in config_db — creating default instance",
                UVM_MEDIUM)
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");
    end

    // Propagate configuration down to env and all child components
    uvm_config_db #(mmu_top_cfg)::set(this, "*", "m_cfg", m_cfg);

    // Create the UVM environment
    m_env = mmu_env::type_id::create("m_env", this);
  endfunction

  // ── Connect phase ─────────────────────────────────────────────────────────
  virtual function void connect_phase(uvm_phase phase);
    // Phase 5: TLM connections (scoreboard → ref model) will be added here
  endfunction

  // ── End-of-elaboration phase ──────────────────────────────────────────────
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  // ── Run phase ─────────────────────────────────────────────────────────────
  // Raises objection, delegates work to the virtual run_test_body() hook,
  // then drops objection.  Derived classes override run_test_body() only.
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, {get_type_name(), ": run_phase started"});
    run_test_body();
    phase.drop_objection(this, {get_type_name(), ": run_test_body done"});
  endtask

  // ── Test body hook ────────────────────────────────────────────────────────
  // Derived classes override this task to launch sequences.
  // Base implementation is a 100 ns safety drain (allows empty-body run).
  virtual task run_test_body();
    `uvm_info(get_type_name(),
              "test_base: empty body — derived class should override run_test_body()",
              UVM_MEDIUM)
    #100ns;
  endtask

endclass : test_base

`endif // TEST_BASE_SVH
