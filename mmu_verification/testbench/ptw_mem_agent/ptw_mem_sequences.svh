// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_sequences.svh
// Phase 4: PTW memory channel sequences
//
// Page-table build sequences use page_table_builder directly.
// Responder control sequences configure m_responder knobs before running.
// Method bodies are stubs in Phase 4; fully implemented in Phase 5 as needed.
// =============================================================================
`ifndef PTW_MEM_SEQUENCES_SVH
`define PTW_MEM_SEQUENCES_SVH

// -----------------------------------------------------------------------------
// 1. Normal in-order response (default)
// -----------------------------------------------------------------------------
class ptw_mem_normal_rsp_seq extends uvm_sequence;
  `uvm_object_utils(ptw_mem_normal_rsp_seq)
  function new(string name = "ptw_mem_normal_rsp_seq");
    super.new(name);
  endfunction
  // Body: configure responder delay range, then let responder run naturally
  virtual task body();
    // TODO (Phase 5): set responder m_rsp_delay_min/max via config handle
  endtask
endclass : ptw_mem_normal_rsp_seq

// -----------------------------------------------------------------------------
// 2. Out-of-order response (protocol does not support OOO; reserved for future)
// -----------------------------------------------------------------------------
class ptw_mem_ooo_rsp_seq extends uvm_sequence;
  `uvm_object_utils(ptw_mem_ooo_rsp_seq)
  function new(string name = "ptw_mem_ooo_rsp_seq"); super.new(name); endfunction
  virtual task body();
    // Protocol constraint: single-outstanding, OOO not applicable
    `uvm_warning(get_type_name(),
      "ptw_mem_ooo_rsp_seq: OOO not supported by single-outstanding protocol")
  endtask
endclass : ptw_mem_ooo_rsp_seq

// -----------------------------------------------------------------------------
// 3. Slow response (high delay to stress PTW latency sensitivity)
// -----------------------------------------------------------------------------
class ptw_mem_slow_rsp_seq extends uvm_sequence;
  `uvm_object_utils(ptw_mem_slow_rsp_seq)
  rand int unsigned slow_min;
  rand int unsigned slow_max;
  constraint c_slow { slow_min inside {[20:50]}; slow_max inside {[50:200]}; slow_min < slow_max; }
  function new(string name = "ptw_mem_slow_rsp_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): update responder delay range to slow_min/max
  endtask
endclass : ptw_mem_slow_rsp_seq

// -----------------------------------------------------------------------------
// 4. Bus error injection sequence
// -----------------------------------------------------------------------------
class ptw_mem_bus_error_inject_seq extends uvm_sequence;
  `uvm_object_utils(ptw_mem_bus_error_inject_seq)
  rand int unsigned error_rate_permille;  // e.g. 100 = 10%
  constraint c_rate { error_rate_permille inside {[10:200]}; }
  function new(string name = "ptw_mem_bus_error_inject_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): set m_responder.m_bus_error_rate_permille
  endtask
endclass : ptw_mem_bus_error_inject_seq

// -----------------------------------------------------------------------------
// 5. Illegal PTE injection (manually write fault PTE via builder)
// -----------------------------------------------------------------------------
class ptw_mem_illegal_pte_seq extends uvm_sequence;
  `uvm_object_utils(ptw_mem_illegal_pte_seq)
  rand va_t target_va;
  string fault_kind;  // "V_OFF" / "RW_RESERVED" / etc.
  function new(string name = "ptw_mem_illegal_pte_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): call builder.inject_fault(target_va, fault_kind)
  endtask
endclass : ptw_mem_illegal_pte_seq

// -----------------------------------------------------------------------------
// 6. Build 4K page table (implemented in Phase 4 — used by directed test)
// -----------------------------------------------------------------------------
class ptw_page_table_build_4k_seq extends uvm_sequence;
  `uvm_object_utils(ptw_page_table_build_4k_seq)

  // Injected by test before start()
  page_table_builder m_builder;

  // Test-configurable mapping parameters
  rand va_t va;
  rand pa_t pa;
  rand bit  r, w, x, u;
  constraint c_va_canonical { va[38] == 1'b0; va[38:30] != 9'h1ff; }
  constraint c_pa_aligned   { pa[11:0] == 12'b0; }
  constraint c_perm_valid   { r | x; }  // at least one permission

  function new(string name = "ptw_page_table_build_4k_seq"); super.new(name); endfunction

  virtual task body();
    if (m_builder == null) begin
      `uvm_fatal(get_type_name(), "m_builder not set; call set_builder() before start()")
    end
    m_builder.map_4k(.va(va), .pa(pa), .r(r), .w(w), .x(x), .u(u));
    `uvm_info(get_type_name(),
      $sformatf("map_4k: va=0x%010h pa=0x%010h r=%0b w=%0b x=%0b u=%0b",
        va, pa, r, w, x, u), UVM_MEDIUM)
  endtask

  function void set_builder(page_table_builder b);
    m_builder = b;
  endfunction

endclass : ptw_page_table_build_4k_seq

// -----------------------------------------------------------------------------
// 7. Build 2M page table (stub)
// -----------------------------------------------------------------------------
class ptw_page_table_build_2m_seq extends uvm_sequence;
  `uvm_object_utils(ptw_page_table_build_2m_seq)
  function new(string name = "ptw_page_table_build_2m_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): call builder.map_2m()
  endtask
endclass : ptw_page_table_build_2m_seq

// -----------------------------------------------------------------------------
// 8. Build 1G page table (stub)
// -----------------------------------------------------------------------------
class ptw_page_table_build_1g_seq extends uvm_sequence;
  `uvm_object_utils(ptw_page_table_build_1g_seq)
  function new(string name = "ptw_page_table_build_1g_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): call builder.map_1g()
  endtask
endclass : ptw_page_table_build_1g_seq

// -----------------------------------------------------------------------------
// 9. PTE A/D bit update (simulate hardware A/D update by DUT)
// -----------------------------------------------------------------------------
class ptw_pte_ad_update_seq extends uvm_sequence;
  `uvm_object_utils(ptw_pte_ad_update_seq)
  rand va_t target_va;
  function new(string name = "ptw_pte_ad_update_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): toggle A/D bits on the leaf PTE
  endtask
endclass : ptw_pte_ad_update_seq

// -----------------------------------------------------------------------------
// 10. Deep random tree (stress multi-level allocation)
// -----------------------------------------------------------------------------
class ptw_deep_tree_random_seq extends uvm_sequence;
  `uvm_object_utils(ptw_deep_tree_random_seq)
  rand int unsigned n_mappings;
  constraint c_n { n_mappings inside {[32:128]}; }
  function new(string name = "ptw_deep_tree_random_seq"); super.new(name); endfunction
  virtual task body();
    // TODO (Phase 5): loop n_mappings times, call builder.map_4k() with random VA/PA
  endtask
endclass : ptw_deep_tree_random_seq

`endif // PTW_MEM_SEQUENCES_SVH
