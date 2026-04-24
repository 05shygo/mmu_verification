// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_txn.svh
// Phase 4: PTW memory channel transaction class
// Protocol: strict serial single-outstanding PTW data bus
//   DUT initiates request (mmu_lsu_data_req), TB responds with PTE data.
// =============================================================================
`ifndef PTW_MEM_TXN_SVH
`define PTW_MEM_TXN_SVH

// Response kind enumeration
typedef enum bit [1:0] {
  PTW_RSP_NORMAL  = 2'd0,  // Normal in-order response (random delay)
  PTW_RSP_SLOW    = 2'd1,  // Artificially slowed response (large delay)
  PTW_RSP_BUS_ERR = 2'd2,  // Bus error injection (lsu_mmu_bus_error=1)
  PTW_RSP_OOO     = 2'd3   // Out-of-order (reserved, OOO not supported by protocol)
} ptw_rsp_kind_e;

class ptw_mem_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(ptw_mem_txn)
    `uvm_field_int (addr,       UVM_ALL_ON)
    `uvm_field_int (req_size,   UVM_ALL_ON)
    `uvm_field_enum(ptw_rsp_kind_e, rsp_kind, UVM_ALL_ON)
    `uvm_field_int (rsp_delay,  UVM_ALL_ON)
    `uvm_field_int (pte_data,   UVM_ALL_ON)
    `uvm_field_int (bus_error,  UVM_ALL_ON)
  `uvm_object_utils_end

  // ── Request fields (filled by monitor from DUT) ──────────────────────────
  bit [39:0] addr;          // PTW request address (PA to read PTE from)
  bit        req_size;      // 0=4B, 1=8B  (always 8B for PTE fetch)

  // ── Response control fields (randomizable; used by responder) ────────────
  rand ptw_rsp_kind_e rsp_kind;
  rand int unsigned   rsp_delay;  // delay in clock cycles before asserting vld

  // ── Response data fields (filled by page_table_builder / monitor) ────────
  bit [63:0] pte_data;      // PTE returned to DUT
  bit        bus_error;     // 1 = bus error injection

  // Default constraints
  constraint c_rsp_kind_normal { rsp_kind == PTW_RSP_NORMAL; }
  constraint c_rsp_delay       { rsp_delay inside {[1:8]}; }

  function new(string name = "ptw_mem_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "addr=0x%010h size=%0b rsp_kind=%-12s delay=%0d pte=0x%016h bus_err=%0b",
      addr, req_size, rsp_kind.name(), rsp_delay, pte_data, bus_error);
  endfunction

endclass : ptw_mem_txn

`endif // PTW_MEM_TXN_SVH
