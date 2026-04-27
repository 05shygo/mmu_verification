// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_sequences.svh
// Phase 3 (Engineer B): IFU sequence library
// Method bodies for Phase 5+ sequences are stubbed with TODO comments.
// =============================================================================
`ifndef IFU_SEQUENCES_SVH
`define IFU_SEQUENCES_SVH

// ── Base sequence ────────────────────────────────────────────────────────────
class ifu_base_seq extends uvm_sequence #(ifu_txn);
  `uvm_object_utils(ifu_base_seq)

  rand int unsigned num_txn;
  constraint c_num_txn { num_txn inside {[1:256]}; }

  function new(string name = "ifu_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // Derived classes provide concrete body
  endtask

endclass : ifu_base_seq

// ── Random VA fetch ──────────────────────────────────────────────────────────
// Generates num_txn random Sv39 canonical VAs.
// Functional in Phase 3 (canonical constraint enforced by ifu_txn).
// TODO (Phase 5): Use page_table_builder to ensure mapped VAs.
class ifu_random_vaddr_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_random_vaddr_seq)

  function new(string name = "ifu_random_vaddr_seq");
    super.new(name);
  endfunction

  virtual task body();
    ifu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      assert(tr.randomize());
      `uvm_send(tr)
    end
  endtask

endclass : ifu_random_vaddr_seq

// ── Sequential page-aligned fetch (simulates PC advance) ─────────────────────
// Drives a deterministic 4-byte PC stream inside the default Phase-9 mapped
// window. Start near the end of a 4K page so short runs still cross a page
// boundary and exercise the sequential-hit path on both sides of the boundary.
class ifu_sequential_fetch_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_sequential_fetch_seq)

  localparam bit [62:0] P9_IFU_MAPPED_BASE_VA = 63'h10_0000;
  localparam bit [62:0] P9_IFU_MAPPED_LAST_VA = 63'h11_ffff;

  rand bit [62:0] start_va;
  // Sv39 canonical start address
  constraint c_sv39_start { start_va[62:39] == {24{start_va[38]}}; }
  constraint c_p9_mapped_start {
    start_va inside {[P9_IFU_MAPPED_BASE_VA:P9_IFU_MAPPED_LAST_VA]};
    start_va[11:0] inside {[12'hff0:12'hffc]};
  }

  function new(string name = "ifu_sequential_fetch_seq");
    super.new(name);
    start_va = 63'h10_0ff0;
  endfunction

  virtual task body();
    ifu_txn    tr;
    bit [62:0] curr_va;

    curr_va = start_va;
    if ((curr_va < P9_IFU_MAPPED_BASE_VA) || (curr_va > P9_IFU_MAPPED_LAST_VA))
      `uvm_fatal(get_type_name(),
        $sformatf("ifu_sequential_fetch_seq start_va out of mapped window: 0x%010h",
          {1'b0, curr_va[38:0]}))

    for (int i = 0; i < int'(num_txn); i++) begin
      if (curr_va > P9_IFU_MAPPED_LAST_VA)
        `uvm_fatal(get_type_name(),
          $sformatf("ifu_sequential_fetch_seq exceeded mapped window at txn=%0d va=0x%010h",
            i, {1'b0, curr_va[38:0]}))
      `uvm_create(tr)
      if (!tr.randomize() with {
            abort == 1'b0;
            idle_cycles == 0;
            va == curr_va;
          })
        `uvm_fatal(get_type_name(), "ifu_sequential_fetch_seq randomize failed")
      `uvm_send(tr)
      curr_va = curr_va + 63'd4;
    end
  endtask

endclass : ifu_sequential_fetch_seq

// ── Abort injection ──────────────────────────────────────────────────────────
// Sends requests with abort=1 to exercise pipeline cancel path.
class ifu_abort_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_abort_seq)

  // Match the default Phase-9 bringup window in phase9_generated_test_base.
  // Warm one mapped ITLB entry first, then issue aborts on the same VA so the
  // "abort no stall / no pollution" scenario does not devolve into random PTW
  // miss traffic.
  localparam bit [62:0] P9_IFU_MAPPED_BASE_VA = 63'h10_0000;
  localparam bit [62:0] P9_IFU_MAPPED_LAST_VA = 63'h11_ffff;

  function new(string name = "ifu_abort_seq");
    super.new(name);
  endfunction

  virtual task body();
    ifu_txn tr, warmup_tr;
    bit [62:0] abort_va;

    `uvm_create(warmup_tr)
    if (!warmup_tr.randomize() with {
          abort == 1'b0;
          idle_cycles == 0;
          va inside {[P9_IFU_MAPPED_BASE_VA:P9_IFU_MAPPED_LAST_VA]};
        })
      `uvm_fatal(get_type_name(), "ifu_abort_seq warmup randomize failed")
    abort_va = warmup_tr.va;
    `uvm_send(warmup_tr)

    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_no_abort.constraint_mode(0);
      if (!tr.randomize() with {
            abort == 1'b1;
            idle_cycles == 0;
            va == abort_va;
          })
        `uvm_fatal(get_type_name(), "ifu_abort_seq randomize failed")
      `uvm_send(tr)
    end
  endtask

endclass : ifu_abort_seq

// ── Branch/flush: normal fetch followed by abort then re-fetch ───────────────
// TODO (Phase 5): Implement branch-redirect scenario.
class ifu_branch_flush_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_branch_flush_seq)

  function new(string name = "ifu_branch_flush_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): send fetch → abort → new fetch from branch target
  endtask

endclass : ifu_branch_flush_seq

// ── Page fault trigger ───────────────────────────────────────────────────────
// Sends VAs that should cause page fault (unmapped / invalid PTE).
// TODO (Phase 5): Coordinate with page_table_builder to select unmapped VA.
class ifu_pagefault_trigger_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_pagefault_trigger_seq)

  function new(string name = "ifu_pagefault_trigger_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): drive unmapped VA range
  endtask

endclass : ifu_pagefault_trigger_seq

// ── Execute permission mix ────────────────────────────────────────────────────
// Tests fetch to X-only pages, non-X pages, and MXR-overridden pages.
// TODO (Phase 5): Requires cp0_mmu_mxr configuration coordination.
class ifu_exec_perm_mix_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_exec_perm_mix_seq)

  function new(string name = "ifu_exec_perm_mix_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): drive X-only and non-X VAs with mxr=0/1
  endtask

endclass : ifu_exec_perm_mix_seq

// ── Huge page fetch (2M / 1G TLB hit) ───────────────────────────────────────
// Sends VAs that map to huge TLB entries (VPN[0] ignored for 2M, etc.).
// TODO (Phase 5): Requires page_table_builder.map_2m() / map_1g().
class ifu_huge_page_fetch_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_huge_page_fetch_seq)

  function new(string name = "ifu_huge_page_fetch_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): use huge page mapping to populate TLB
  endtask

endclass : ifu_huge_page_fetch_seq

`endif // IFU_SEQUENCES_SVH
