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

  // +UVM_ERR_ONLY or +UVM_ERR_ONLY=1 : hide UVM_INFO / UVM_WARNING under this
  // test (only UVM_ERROR / UVM_FATAL print; final UVM report summary still runs).

  protected static function void m_apply_error_only_r(uvm_component c);
    uvm_component ch[$];
    if (c == null) return;
    c.set_report_severity_action(UVM_INFO, UVM_NO_ACTION);
    c.set_report_severity_action(UVM_WARNING, UVM_NO_ACTION);
    c.get_children(ch);
    foreach (ch[i]) m_apply_error_only_r(ch[i]);
  endfunction

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
    if (!$test$plusargs("UVM_ERR_ONLY"))
      uvm_top.print_topology();
  endfunction

  // ── Before run: optional “errors only” on terminal ───────────────────────
  virtual function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    if ($test$plusargs("UVM_ERR_ONLY")) begin
      m_apply_error_only_r(this);
    end
  endfunction

  // ── Run phase ─────────────────────────────────────────────────────────────
  // Raises objection, delegates work to the virtual run_test_body() hook,
  // then drops objection.  Derived classes override run_test_body() only.
  virtual task run_phase(uvm_phase phase);
    time timeout_delay;
    int unsigned end_stim_drain_max_cycles;
    int unsigned end_stim_drain_stable_cycles;

    phase.raise_objection(this, {get_type_name(), ": run_phase started"});
    if (timeout_ns == 0) begin
      run_test_body();
    end else begin
      timeout_delay = time'(timeout_ns) * 1ns;
      fork
        begin : test_body_thread
          run_test_body();
        end
        begin : timeout_thread
          #(timeout_delay);
          if (m_env != null)
            m_env.print_timeout_debug(get_type_name(), timeout_ns, num_txn);
          else
            $display("[MMU_TIMEOUT_DBG] owner=%s timeout_ns=%0d num_txn=%0d env=null",
              get_type_name(), timeout_ns, num_txn);
          `uvm_fatal(get_type_name(),
            $sformatf("Global test timeout after %0d ns (+TIMEOUT); run_test_body did not complete",
              timeout_ns))
        end
      join_any
      disable fork;
    end
    end_stim_drain_max_cycles = 262144;
    end_stim_drain_stable_cycles = 32;
    void'($value$plusargs("TEST_END_STIM_DRAIN_MAX_CYCLES=%0d", end_stim_drain_max_cycles));
    void'($value$plusargs("TEST_END_STIM_DRAIN_STABLE_CYCLES=%0d", end_stim_drain_stable_cycles));
    if (m_env != null)
      m_env.quiesce_request_stimulus_before_end(
        end_stim_drain_max_cycles,
        end_stim_drain_stable_cycles);
    if ((m_env != null) && (m_env.m_credit_sb != null))
      m_env.m_credit_sb.drain_before_test_done();
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
