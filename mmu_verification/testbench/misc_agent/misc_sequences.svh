// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_sequences.svh
// Phase 5 (Engineer A): Misc sequence library
//
// Sequences provided:
//   misc_base_seq          — base class
//   misc_rtu_flush_seq     — issue a single-cycle RTU flush pulse
//   misc_rtu_expt_seq      — inject a single RTU exception (expt_vld + bad_vpn)
//   misc_smp_disable_seq   — configure biu_mmu_smp_disable (static level)
//   misc_hpcp_enable_seq   — enable/disable HPCP performance counters
//   misc_init_seq          — compound: set up safe defaults at start of test
// =============================================================================
`ifndef MISC_SEQUENCES_SVH
`define MISC_SEQUENCES_SVH

// ── Base sequence ─────────────────────────────────────────────────────────────
class misc_base_seq extends uvm_sequence #(misc_txn);
  `uvm_object_utils(misc_base_seq)

  function new(string name = "misc_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // Derived classes provide concrete body
  endtask

endclass : misc_base_seq

// ── Single RTU pipeline flush pulse ──────────────────────────────────────────
// Issues MISC_RTU_FLUSH: asserts rtu_yy_xx_flush for one cycle.
// Use to simulate pipeline flush events (e.g., branch misprediction).
class misc_rtu_flush_seq extends misc_base_seq;
  `uvm_object_utils(misc_rtu_flush_seq)

  function new(string name = "misc_rtu_flush_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op = MISC_RTU_FLUSH;
    `uvm_send(tr)
  endtask

endclass : misc_rtu_flush_seq

// ── RTU exception injection ────────────────────────────────────────────────
// Issues MISC_RTU_EXPT: asserts rtu_mmu_expt_vld + rtu_mmu_bad_vpn for one cycle.
class misc_rtu_expt_seq extends misc_base_seq;
  `uvm_object_utils(misc_rtu_expt_seq)

  rand bit [26:0] bad_vpn;  // bad VPN to inject

  function new(string name = "misc_rtu_expt_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op      = MISC_RTU_EXPT;
    tr.expt_vld = 1'b1;
    tr.bad_vpn  = bad_vpn;
    `uvm_send(tr)
  endtask

endclass : misc_rtu_expt_seq

// ── SMP disable configuration ────────────────────────────────────────────────
// Issues MISC_SMP_DISABLE: sets biu_mmu_smp_disable to the given level.
// Phase 5: can be used to test non-coherent bus attribute path.
class misc_smp_disable_seq extends misc_base_seq;
  `uvm_object_utils(misc_smp_disable_seq)

  rand bit smp_disable;  // 1 = disable SMP coherence, 0 = normal

  function new(string name = "misc_smp_disable_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op          = MISC_SMP_DISABLE;
    tr.smp_disable = smp_disable;
    `uvm_send(tr)
  endtask

endclass : misc_smp_disable_seq

class misc_smp_disable_on_seq extends misc_base_seq;
  `uvm_object_utils(misc_smp_disable_on_seq)

  function new(string name = "misc_smp_disable_on_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op          = MISC_SMP_DISABLE;
    tr.smp_disable = 1'b1;
    `uvm_send(tr)
  endtask

endclass : misc_smp_disable_on_seq

class misc_smp_disable_off_seq extends misc_base_seq;
  `uvm_object_utils(misc_smp_disable_off_seq)

  function new(string name = "misc_smp_disable_off_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op          = MISC_SMP_DISABLE;
    tr.smp_disable = 1'b0;
    `uvm_send(tr)
  endtask

endclass : misc_smp_disable_off_seq

// ── HPCP counter enable / disable ─────────────────────────────────────────────
// Issues MISC_HPCP_CNT_EN: sets hpcp_mmu_cnt_en to the given level.
class misc_hpcp_enable_seq extends misc_base_seq;
  `uvm_object_utils(misc_hpcp_enable_seq)

  rand bit hpcp_cnt_en;  // 1 = enable (default), 0 = disable

  // Default: keep enabled
  constraint c_en_default { hpcp_cnt_en == 1'b1; }

  function new(string name = "misc_hpcp_enable_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op          = MISC_HPCP_CNT_EN;
    tr.hpcp_cnt_en = hpcp_cnt_en;
    `uvm_send(tr)
  endtask

endclass : misc_hpcp_enable_seq

class misc_hpcp_enable_on_seq extends misc_base_seq;
  `uvm_object_utils(misc_hpcp_enable_on_seq)

  function new(string name = "misc_hpcp_enable_on_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op          = MISC_HPCP_CNT_EN;
    tr.hpcp_cnt_en = 1'b1;
    `uvm_send(tr)
  endtask

endclass : misc_hpcp_enable_on_seq

class misc_hpcp_enable_off_seq extends misc_base_seq;
  `uvm_object_utils(misc_hpcp_enable_off_seq)

  function new(string name = "misc_hpcp_enable_off_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    `uvm_create(tr)
    tr.op          = MISC_HPCP_CNT_EN;
    tr.hpcp_cnt_en = 1'b0;
    `uvm_send(tr)
  endtask

endclass : misc_hpcp_enable_off_seq

// ── Compound initialisation sequence ─────────────────────────────────────────
// Sets up safe defaults at the start of every test that uses misc_agent:
//   1. SMP coherent (smp_disable = 0)
//   2. HPCP counters enabled (hpcp_cnt_en = 1)
// This sequence is intended to be called from test_base.run_test_body()
// before the main stimulus.
class misc_init_seq extends misc_base_seq;
  `uvm_object_utils(misc_init_seq)

  function new(string name = "misc_init_seq");
    super.new(name);
  endfunction

  virtual task body();
    misc_txn tr;
    // Ensure SMP coherent
    `uvm_create(tr)
    tr.op          = MISC_SMP_DISABLE;
    tr.smp_disable = 1'b0;
    `uvm_send(tr)
    // Ensure performance counters enabled
    `uvm_create(tr)
    tr.op          = MISC_HPCP_CNT_EN;
    tr.hpcp_cnt_en = 1'b1;
    `uvm_send(tr)
  endtask

endclass : misc_init_seq

`endif // MISC_SEQUENCES_SVH
