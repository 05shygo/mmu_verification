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
// TODO (Phase 5): Implement sequential VA increment with configurable stride.
class ifu_sequential_fetch_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_sequential_fetch_seq)

  rand bit [62:0] start_va;
  // Sv39 canonical start address
  constraint c_sv39_start { start_va[62:39] == {24{start_va[38]}}; }

  function new(string name = "ifu_sequential_fetch_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): increment VA by 4 (instruction width) each cycle
  endtask

endclass : ifu_sequential_fetch_seq

// ── Abort injection ──────────────────────────────────────────────────────────
// Sends requests with abort=1 to exercise pipeline cancel path.
class ifu_abort_seq extends ifu_base_seq;
  `uvm_object_utils(ifu_abort_seq)

  function new(string name = "ifu_abort_seq");
    super.new(name);
  endfunction

  virtual task body();
    ifu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      assert(tr.randomize() with { abort == 1'b1; idle_cycles == 0; });
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
