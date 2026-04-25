// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_sequences.svh
// Phase 3 (Engineer B): LSU sequence library (skeleton)
// Sequences targeting a single sub-channel are runnable in Phase 3.
// Multi-channel and complex sequences are stubbed for Phase 5+.
// =============================================================================
`ifndef LSU_SEQUENCES_SVH
`define LSU_SEQUENCES_SVH

// ── Base sequence ────────────────────────────────────────────────────────────
class lsu_base_seq extends uvm_sequence #(lsu_txn);
  `uvm_object_utils(lsu_base_seq)

  rand int unsigned num_txn;
  constraint c_num_txn { num_txn inside {[1:256]}; }

  function new(string name = "lsu_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // Derived classes provide concrete body
  endtask

endclass : lsu_base_seq

// ── Pipe 0 only: random LD/ST requests ───────────────────────────────────────
class lsu_pipe0_only_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_pipe0_only_seq)

  function new(string name = "lsu_pipe0_only_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      assert(tr.randomize() with { kind == LSU_PIPE0; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_pipe0_only_seq

// ── Pipe 1 only ───────────────────────────────────────────────────────────────
class lsu_pipe1_only_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_pipe1_only_seq)

  function new(string name = "lsu_pipe1_only_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_PIPE1; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_pipe1_only_seq

// ── Pipe 0+1 concurrent ───────────────────────────────────────────────────────
// TODO (Phase 5): Interleave pipe0 and pipe1 with random ordering.
class lsu_01_concurrent_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_01_concurrent_seq)

  function new(string name = "lsu_01_concurrent_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): drive pipe0 and pipe1 back-to-back concurrently
  endtask

endclass : lsu_01_concurrent_seq

// ── Prefetch pipe 2 only ──────────────────────────────────────────────────────
class lsu_prefetch_pipe2_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_prefetch_pipe2_seq)

  function new(string name = "lsu_prefetch_pipe2_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_PIPE2; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_prefetch_pipe2_seq

// ── STAMO PA check ────────────────────────────────────────────────────────────
class lsu_stamo_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_stamo_seq)

  function new(string name = "lsu_stamo_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_STAMO; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_stamo_seq

// ── Back-to-back pipe0 requests (zero idle) ───────────────────────────────────
class lsu_back2back_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_back2back_seq)

  function new(string name = "lsu_back2back_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      assert(tr.randomize() with { kind == LSU_PIPE0; idle_cycles == 0; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_back2back_seq

// ── Same cache line hit/miss mix ─────────────────────────────────────────────
// TODO (Phase 5): Requires page_table_builder; VA aliased to same page.
class lsu_same_line_hit_miss_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_same_line_hit_miss_seq)

  function new(string name = "lsu_same_line_hit_miss_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): send same VA repeatedly to exercise hit path
  endtask

endclass : lsu_same_line_hit_miss_seq

// ── Abort injection ───────────────────────────────────────────────────────────
class lsu_abort_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_abort_seq)

  function new(string name = "lsu_abort_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      tr.c_no_abort.constraint_mode(0);
      assert(tr.randomize() with { kind inside {LSU_PIPE0, LSU_PIPE1}; abort == 1'b1; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_abort_seq

// ── Huge page (2M / 1G) ───────────────────────────────────────────────────────
// TODO (Phase 5): Use page_table_builder.map_2m() / map_1g().
class lsu_huge_page_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_huge_page_seq)

  function new(string name = "lsu_huge_page_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): send VAs in 2M-aligned regions
  endtask

endclass : lsu_huge_page_seq

// ── Cross-ASID accesses ───────────────────────────────────────────────────────
// TODO (Phase 5): Configure SATP.ASID changes and validate TLB flush.
class lsu_cross_asid_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_cross_asid_seq)

  function new(string name = "lsu_cross_asid_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): alternate ASID via cp0_agent and drive pipe0
  endtask

endclass : lsu_cross_asid_seq

// ── ST/LD mix ─────────────────────────────────────────────────────────────────
class lsu_st_ld_mix_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_st_ld_mix_seq)

  function new(string name = "lsu_st_ld_mix_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      assert(tr.randomize() with { kind == LSU_PIPE0; });
      `uvm_send(tr)
    end
  endtask

endclass : lsu_st_ld_mix_seq

// ── Unaligned accesses ────────────────────────────────────────────────────────
// TODO (Phase 5): Drive VAs crossing page boundaries.
class lsu_unaligned_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_unaligned_seq)

  function new(string name = "lsu_unaligned_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): VAs with low-bit offset crossing 4K boundary
  endtask

endclass : lsu_unaligned_seq

// ============================================================================
// TLB Invalidation sequences (LSU INV sub-channel)
// ============================================================================

// ── SFENCE.VMA x0, x0 — invalidate all ───────────────────────────────────────
class tlb_inv_all_seq extends lsu_base_seq;
  `uvm_object_utils(tlb_inv_all_seq)

  function new(string name = "tlb_inv_all_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_INV; inv_kind == INV_ALL; });
      `uvm_send(tr)
    end
  endtask

endclass : tlb_inv_all_seq

// ── SFENCE.VMA rs1, x0 — invalidate by VA ────────────────────────────────────
class tlb_inv_va_seq extends lsu_base_seq;
  `uvm_object_utils(tlb_inv_va_seq)

  function new(string name = "tlb_inv_va_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_INV; inv_kind == INV_VA_ALL; });
      `uvm_send(tr)
    end
  endtask

endclass : tlb_inv_va_seq

// ── SFENCE.VMA x0, rs2 — invalidate by ASID ──────────────────────────────────
class tlb_inv_asid_seq extends lsu_base_seq;
  `uvm_object_utils(tlb_inv_asid_seq)

  function new(string name = "tlb_inv_asid_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_INV; inv_kind == INV_ASID_ALL; });
      `uvm_send(tr)
    end
  endtask

endclass : tlb_inv_asid_seq

// ── SFENCE.VMA rs1, rs2 — invalidate by VA + ASID ────────────────────────────
class tlb_inv_va_asid_seq extends lsu_base_seq;
  `uvm_object_utils(tlb_inv_va_asid_seq)

  function new(string name = "tlb_inv_va_asid_seq");
    super.new(name);
  endfunction

  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_INV; inv_kind == INV_VA_ASID; });
      `uvm_send(tr)
    end
  endtask

endclass : tlb_inv_va_asid_seq

// ── Stress: rapid back-to-back SFENCE.VMA ─────────────────────────────────────
// TODO (Phase 5): Interleave all 4 invalidation modes.
class sfence_vma_stress_seq extends lsu_base_seq;
  `uvm_object_utils(sfence_vma_stress_seq)

  function new(string name = "sfence_vma_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO (Phase 5): rotate through INV_ALL / INV_VA_ALL / INV_ASID_ALL / INV_VA_ASID
  endtask

endclass : sfence_vma_stress_seq

`endif // LSU_SEQUENCES_SVH
