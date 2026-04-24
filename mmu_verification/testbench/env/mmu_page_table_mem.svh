// =============================================================================
// MMU UVM Verification — testbench/env/mmu_page_table_mem.svh
// Phase 4: Shared shadow page-table memory
//
// This object is the single source of truth for the TB-maintained page table.
// Both the ptw_mem_responder and the mmu_ref_model hold a reference to
// m_builder.  Any page table modification (map_4k, invalidate, inject_fault)
// is performed on this object and is immediately visible to both consumers.
//
// Lifetime: created in mmu_env.build_phase; never destroyed until end of sim.
// =============================================================================
`ifndef MMU_PAGE_TABLE_MEM_SVH
`define MMU_PAGE_TABLE_MEM_SVH

class mmu_page_table_mem extends uvm_object;

  `uvm_object_utils(mmu_page_table_mem)

  // ── Core builder (shared with responder + ref_model) ─────────────────────
  page_table_builder m_builder;

  function new(string name = "mmu_page_table_mem");
    super.new(name);
  endfunction

  // Call once from env.build_phase after construction
  virtual function void init();
    m_builder = page_table_builder::type_id::create("m_builder");
    `uvm_info(get_type_name(), "mmu_page_table_mem initialised", UVM_MEDIUM)
  endfunction

  // ── Proxy helpers (delegates to m_builder) ────────────────────────────────

  virtual function pte_t read_pte(pa_t pte_addr);
    return m_builder.read_pte_at(pte_addr);
  endfunction

  virtual function void write_pte(pa_t pte_addr, pte_t pte);
    m_builder.write_pte_at(pte_addr, pte);
  endfunction

  virtual function void reset();
    m_builder.clear();
    `uvm_info(get_type_name(), "Page table memory reset", UVM_MEDIUM)
  endfunction

endclass : mmu_page_table_mem

`endif // MMU_PAGE_TABLE_MEM_SVH
