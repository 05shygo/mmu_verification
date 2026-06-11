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

class ptw_mem_cfg_base_seq extends uvm_sequence #(ptw_mem_txn);
  `uvm_object_utils(ptw_mem_cfg_base_seq)
  `uvm_declare_p_sequencer(ptw_mem_sequencer)

  function new(string name = "ptw_mem_cfg_base_seq");
    super.new(name);
  endfunction

  protected function ptw_mem_responder get_responder();
    uvm_component parent_comp;
    uvm_component responder_comp;
    ptw_mem_responder rsp_h;

    parent_comp = p_sequencer.get_parent();
    if (parent_comp == null)
      `uvm_fatal(get_type_name(), "ptw_mem sequencer parent is null")

    // Avoid a hard compile-time dependency on ptw_mem_agent. This sequence file
    // is included before ptw_mem_agent.svh in the package, so resolve the
    // responder through the sequencer parent's child hierarchy instead.
    responder_comp = parent_comp.get_child("m_responder");
    if (responder_comp == null)
      `uvm_fatal(get_type_name(), "Cannot find child component 'm_responder' under ptw_mem sequencer parent")
    if (!$cast(rsp_h, responder_comp))
      `uvm_fatal(get_type_name(), "Child component 'm_responder' is not a ptw_mem_responder")
    return rsp_h;
  endfunction
endclass

// -----------------------------------------------------------------------------
// 1. Normal in-order response (default)
// -----------------------------------------------------------------------------
class ptw_mem_normal_rsp_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_normal_rsp_seq)
  function new(string name = "ptw_mem_normal_rsp_seq");
    super.new(name);
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.clear_directed_controls();
    rsp_h.set_delay_range(1, 4);
  endtask
endclass : ptw_mem_normal_rsp_seq

class ptw_mem_directed_clear_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_directed_clear_seq)
  function new(string name = "ptw_mem_directed_clear_seq");
    super.new(name);
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.clear_directed_controls();
  endtask
endclass : ptw_mem_directed_clear_seq

class ptw_mem_delay_range_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_delay_range_seq)
  rand int unsigned delay_min;
  rand int unsigned delay_max;
  constraint c_range { delay_min inside {[0:512]}; delay_max inside {[0:512]}; delay_min <= delay_max; }
  function new(string name = "ptw_mem_delay_range_seq");
    super.new(name);
    delay_min = 1;
    delay_max = 8;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_delay_range(delay_min, delay_max);
  endtask
endclass : ptw_mem_delay_range_seq

class ptw_mem_delay_by_addr_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_delay_by_addr_seq)
  rand bit [39:0] addr;
  rand int unsigned delay;
  constraint c_delay { delay inside {[0:512]}; }
  function new(string name = "ptw_mem_delay_by_addr_seq");
    super.new(name);
    addr = 40'h0;
    delay = 0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_delay_for_addr(addr, delay);
  endtask
endclass : ptw_mem_delay_by_addr_seq

class ptw_mem_delay_by_count_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_delay_by_count_seq)
  rand int unsigned accept_count;
  rand int unsigned delay;
  constraint c_count { accept_count inside {[1:1024]}; }
  constraint c_delay { delay inside {[0:512]}; }
  function new(string name = "ptw_mem_delay_by_count_seq");
    super.new(name);
    accept_count = 1;
    delay = 0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_delay_for_count(accept_count, delay);
  endtask
endclass : ptw_mem_delay_by_count_seq

class ptw_mem_delay_by_id_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_delay_by_id_seq)
  rand bit [3:0] id;
  rand int unsigned delay;
  constraint c_id { id inside {[0:8]}; }
  constraint c_delay { delay inside {[0:512]}; }
  function new(string name = "ptw_mem_delay_by_id_seq");
    super.new(name);
    id = 4'h0;
    delay = 0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_delay_for_id(id, delay);
  endtask
endclass : ptw_mem_delay_by_id_seq

class ptw_mem_response_delay_by_id_seq extends ptw_mem_delay_by_id_seq;
  `uvm_object_utils(ptw_mem_response_delay_by_id_seq)
  function new(string name = "ptw_mem_response_delay_by_id_seq");
    super.new(name);
  endfunction
endclass : ptw_mem_response_delay_by_id_seq

class ptw_mem_grant_delay_by_count_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_grant_delay_by_count_seq)
  rand int unsigned accept_count;
  rand int unsigned cycles;
  constraint c_count { accept_count inside {[1:1024]}; }
  constraint c_cycles { cycles inside {[0:512]}; }
  function new(string name = "ptw_mem_grant_delay_by_count_seq");
    super.new(name);
    accept_count = 1;
    cycles = 0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_grant_delay_for_count(accept_count, cycles);
  endtask
endclass : ptw_mem_grant_delay_by_count_seq

class ptw_mem_grant_delay_by_id_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_grant_delay_by_id_seq)
  rand bit [3:0] id;
  rand int unsigned cycles;
  constraint c_id { id inside {[0:8]}; }
  constraint c_cycles { cycles inside {[0:512]}; }
  function new(string name = "ptw_mem_grant_delay_by_id_seq");
    super.new(name);
    id = 4'h0;
    cycles = 0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_grant_delay_for_id(id, cycles);
  endtask
endclass : ptw_mem_grant_delay_by_id_seq

class ptw_mem_bus_error_by_addr_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_bus_error_by_addr_seq)
  rand bit [39:0] addr;
  bit enable;
  function new(string name = "ptw_mem_bus_error_by_addr_seq");
    super.new(name);
    addr = 40'h0;
    enable = 1'b1;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_bus_error_for_addr(addr, enable);
  endtask
endclass : ptw_mem_bus_error_by_addr_seq

class ptw_mem_bus_error_by_count_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_bus_error_by_count_seq)
  rand int unsigned accept_count;
  bit enable;
  constraint c_count { accept_count inside {[1:1024]}; }
  function new(string name = "ptw_mem_bus_error_by_count_seq");
    super.new(name);
    accept_count = 1;
    enable = 1'b1;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_bus_error_for_count(accept_count, enable);
  endtask
endclass : ptw_mem_bus_error_by_count_seq

class ptw_mem_bus_error_by_id_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_bus_error_by_id_seq)
  rand bit [3:0] id;
  bit enable;
  constraint c_id { id inside {[0:8]}; }
  function new(string name = "ptw_mem_bus_error_by_id_seq");
    super.new(name);
    id = 4'h0;
    enable = 1'b1;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_bus_error_for_id(id, enable);
  endtask
endclass : ptw_mem_bus_error_by_id_seq

class ptw_mem_same_cycle_abort_data_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_same_cycle_abort_data_seq)
  rand int unsigned accept_count;
  constraint c_count { accept_count inside {[1:1024]}; }
  function new(string name = "ptw_mem_same_cycle_abort_data_seq");
    super.new(name);
    accept_count = 1;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_same_cycle_abort_data_for_count(accept_count);
  endtask
endclass : ptw_mem_same_cycle_abort_data_seq

class ptw_mem_same_cycle_abort_bus_error_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_same_cycle_abort_bus_error_seq)
  rand int unsigned accept_count;
  constraint c_count { accept_count inside {[1:1024]}; }
  function new(string name = "ptw_mem_same_cycle_abort_bus_error_seq");
    super.new(name);
    accept_count = 1;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_same_cycle_abort_bus_error_for_count(accept_count);
  endtask
endclass : ptw_mem_same_cycle_abort_bus_error_seq

class ptw_mem_chk_not_ready_slow_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_chk_not_ready_slow_seq)
  rand int unsigned slow_cycles;
  constraint c_slow { slow_cycles inside {[16:512]}; }
  function new(string name = "ptw_mem_chk_not_ready_slow_seq");
    super.new(name);
    slow_cycles = 96;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_chk_not_ready_slow_response(slow_cycles);
  endtask
endclass : ptw_mem_chk_not_ready_slow_seq

// -----------------------------------------------------------------------------
// 2. ID-directed response controls
// -----------------------------------------------------------------------------
class ptw_mem_ooo_rsp_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_ooo_rsp_seq)
  function new(string name = "ptw_mem_ooo_rsp_seq"); super.new(name); endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_response_order_mode(PTW_RSP_BY_ID_OOO);
  endtask
endclass : ptw_mem_ooo_rsp_seq

class ptw_mem_force_next_response_id_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_force_next_response_id_seq)
  rand bit [3:0] id;
  constraint c_id { id inside {[0:8]}; }
  function new(string name = "ptw_mem_force_next_response_id_seq");
    super.new(name);
    id = 4'h0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.force_next_response_id(id);
  endtask
endclass : ptw_mem_force_next_response_id_seq

class ptw_mem_force_invalid_response_id_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_force_invalid_response_id_seq)
  rand bit [3:0] id;
  constraint c_id { id inside {[9:15]}; }
  function new(string name = "ptw_mem_force_invalid_response_id_seq");
    super.new(name);
    id = 4'h9;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.force_invalid_response_id(id);
  endtask
endclass : ptw_mem_force_invalid_response_id_seq

class ptw_mem_max_outstanding_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_max_outstanding_seq)
  rand int unsigned depth;
  constraint c_depth { depth inside {[0:9]}; }
  function new(string name = "ptw_mem_max_outstanding_seq");
    super.new(name);
    depth = 9;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.set_max_outstanding(depth);
  endtask
endclass : ptw_mem_max_outstanding_seq

class ptw_mem_grant_backpressure_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_grant_backpressure_seq)
  rand int unsigned accept_count;
  rand bit [3:0] id;
  rand int unsigned cycles;
  bit use_id;
  constraint c_count { accept_count inside {[1:1024]}; }
  constraint c_id { id inside {[0:8]}; }
  constraint c_cycles { cycles inside {[1:512]}; }
  function new(string name = "ptw_mem_grant_backpressure_seq");
    super.new(name);
    accept_count = 1;
    id = 4'h0;
    cycles = 8;
    use_id = 1'b0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    if (use_id)
      rsp_h.set_grant_delay_for_id(id, cycles);
    else
      rsp_h.set_grant_delay_for_count(accept_count, cycles);
  endtask
endclass : ptw_mem_grant_backpressure_seq

class ptw_mem_abort_drain_rsp_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_abort_drain_rsp_seq)
  rand int unsigned accept_count;
  bit bus_error;
  constraint c_count { accept_count inside {[1:1024]}; }
  function new(string name = "ptw_mem_abort_drain_rsp_seq");
    super.new(name);
    accept_count = 1;
    bus_error = 1'b0;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    if (bus_error)
      rsp_h.set_same_cycle_abort_bus_error_for_count(accept_count);
    else
      rsp_h.set_same_cycle_abort_data_for_count(accept_count);
  endtask
endclass : ptw_mem_abort_drain_rsp_seq

class ptw_mem_invalid_rsp_id_negative_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_invalid_rsp_id_negative_seq)
  rand bit [3:0] id;
  constraint c_id { id inside {[9:15]}; }
  function new(string name = "ptw_mem_invalid_rsp_id_negative_seq");
    super.new(name);
    id = 4'h9;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.force_invalid_response_id(id);
  endtask
endclass : ptw_mem_invalid_rsp_id_negative_seq

// -----------------------------------------------------------------------------
// 3. Slow response (high delay to stress PTW latency sensitivity)
// -----------------------------------------------------------------------------
class ptw_mem_slow_rsp_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_slow_rsp_seq)
  rand int unsigned slow_min;
  rand int unsigned slow_max;
  constraint c_slow { slow_min inside {[24:64]}; slow_max inside {[64:160]}; slow_min < slow_max; }
  function new(string name = "ptw_mem_slow_rsp_seq");
    super.new(name);
    slow_min = 32;
    slow_max = 96;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.clear_directed_controls();
    rsp_h.set_delay_range(slow_min, slow_max);
  endtask
endclass : ptw_mem_slow_rsp_seq

// -----------------------------------------------------------------------------
// 4. Bus error injection sequence
// -----------------------------------------------------------------------------
class ptw_mem_bus_error_inject_seq extends ptw_mem_cfg_base_seq;
  `uvm_object_utils(ptw_mem_bus_error_inject_seq)
  rand int unsigned error_rate_permille;  // e.g. 100 = 10%
  constraint c_rate { error_rate_permille inside {[100:400]}; }
  function new(string name = "ptw_mem_bus_error_inject_seq");
    super.new(name);
    error_rate_permille = 250;
  endfunction
  virtual task body();
    ptw_mem_responder rsp_h;
    rsp_h = get_responder();
    rsp_h.clear_directed_controls();
    rsp_h.set_delay_range(1, 8);
    rsp_h.m_bus_error_rate_permille = error_rate_permille;
  endtask
endclass : ptw_mem_bus_error_inject_seq

// -----------------------------------------------------------------------------
// 5. Illegal PTE injection (manually write fault PTE via builder)
// -----------------------------------------------------------------------------
class ptw_mem_illegal_pte_seq extends uvm_sequence #(ptw_mem_txn);
  `uvm_object_utils(ptw_mem_illegal_pte_seq)
  page_table_builder m_builder;
  rand va_t target_va;
  string fault_kind;  // "V_OFF" / "RW_RESERVED" / etc.
  function new(string name = "ptw_mem_illegal_pte_seq");
    super.new(name);
    target_va   = 39'h0_4000_0000;
    fault_kind  = "V_OFF";
  endfunction
  virtual task body();
    if (m_builder == null)
      `uvm_fatal(get_type_name(), "m_builder not set; call set_builder() before start()")
    m_builder.inject_fault(target_va, fault_kind);
  endtask
  function void set_builder(page_table_builder b);
    m_builder = b;
  endfunction
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
class ptw_page_table_build_2m_seq extends uvm_sequence #(ptw_mem_txn);
  `uvm_object_utils(ptw_page_table_build_2m_seq)
  page_table_builder m_builder;
  rand va_t va;
  rand pa_t pa;
  rand bit  r, w, x, u;
  constraint c_va_align    { va[20:0] == 21'b0; }
  constraint c_pa_align    { pa[20:0] == 21'b0; }
  constraint c_va_canonical { va[38] == 1'b0; va[38:30] != 9'h1ff; }
  constraint c_perm_valid  { r | x; }
  function new(string name = "ptw_page_table_build_2m_seq");
    super.new(name);
    va = 39'h0_2000_0000;
    pa = 40'h0_0200_0000;
    r  = 1'b1;
    w  = 1'b1;
    x  = 1'b1;
    u  = 1'b0;
  endfunction
  virtual task body();
    if (m_builder == null)
      `uvm_fatal(get_type_name(), "m_builder not set; call set_builder() before start()")
    m_builder.map_2m(.va(va), .pa(pa), .r(r), .w(w), .x(x), .u(u));
  endtask
  function void set_builder(page_table_builder b);
    m_builder = b;
  endfunction
endclass : ptw_page_table_build_2m_seq

// -----------------------------------------------------------------------------
// 8. Build 1G page table (stub)
// -----------------------------------------------------------------------------
class ptw_page_table_build_1g_seq extends uvm_sequence #(ptw_mem_txn);
  `uvm_object_utils(ptw_page_table_build_1g_seq)
  page_table_builder m_builder;
  rand va_t va;
  rand pa_t pa;
  rand bit  r, w, x, u;
  constraint c_va_align    { va[29:0] == 30'b0; }
  constraint c_pa_align    { pa[29:0] == 30'b0; }
  constraint c_va_canonical { va[38] == 1'b0; va[38:30] != 9'h1ff; }
  constraint c_perm_valid  { r | x; }
  function new(string name = "ptw_page_table_build_1g_seq");
    super.new(name);
    va = 39'h0_4000_0000;
    pa = 40'h0_4000_0000;
    r  = 1'b1;
    w  = 1'b1;
    x  = 1'b1;
    u  = 1'b0;
  endfunction
  virtual task body();
    if (m_builder == null)
      `uvm_fatal(get_type_name(), "m_builder not set; call set_builder() before start()")
    m_builder.map_1g(.va(va), .pa(pa), .r(r), .w(w), .x(x), .u(u));
  endtask
  function void set_builder(page_table_builder b);
    m_builder = b;
  endfunction
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
