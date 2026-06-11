// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_txn.svh
// PTW memory channel transaction class
//   DUT initiates request (mmu_lsu_data_req + req_id), LSU/TB grants with
//   lsu_mmu_data_req_grant, and response returns with lsu_mmu_data_id.
// =============================================================================
`ifndef PTW_MEM_TXN_SVH
`define PTW_MEM_TXN_SVH

// Response kind enumeration
typedef enum bit [1:0] {
  PTW_RSP_NORMAL  = 2'd0,  // Normal in-order response (random delay)
  PTW_RSP_SLOW    = 2'd1,  // Artificially slowed response (large delay)
  PTW_RSP_BUS_ERR = 2'd2,  // Bus error injection (lsu_mmu_bus_error=1)
  PTW_RSP_OOO     = 2'd3   // Out-of-order response mode
} ptw_rsp_kind_e;

typedef enum bit [2:0] {
  PTW_RSP_IN_ORDER      = 3'd0,
  PTW_RSP_BY_ID_OOO     = 3'd1,
  PTW_RSP_BUS_ERR_BY_ID = 3'd2,
  PTW_RSP_INVALID_ID    = 3'd3,
  PTW_RSP_DUPLICATE_ID  = 3'd4
} ptw_rsp_order_e;

typedef enum bit [2:0] {
  PTW_GRANT_ALWAYS_READY     = 3'd0,
  PTW_GRANT_DELAY_FIXED      = 3'd1,
  PTW_GRANT_DELAY_RANDOM     = 3'd2,
  PTW_GRANT_HOLD_UNTIL_ABORT = 3'd3
} ptw_grant_mode_e;

class ptw_mem_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(ptw_mem_txn)
    `uvm_field_int (addr,       UVM_ALL_ON)
    `uvm_field_int (id,         UVM_ALL_ON)
    `uvm_field_int (req_size,   UVM_ALL_ON)
    `uvm_field_int (req_id,     UVM_ALL_ON)
    `uvm_field_int (rsp_id,     UVM_ALL_ON)
    `uvm_field_int (req_fire,   UVM_ALL_ON)
    `uvm_field_int (rsp_valid,  UVM_ALL_ON)
    `uvm_field_int (rsp_is_ooo, UVM_ALL_ON)
    `uvm_field_int (rsp_id_invalid, UVM_ALL_ON)
    `uvm_field_int (rsp_without_pending, UVM_ALL_ON)
    `uvm_field_int (duplicate_id_error, UVM_ALL_ON)
    `uvm_field_int (aborted_before_grant, UVM_ALL_ON)
    `uvm_field_int (abort_drain_rsp, UVM_ALL_ON)
    `uvm_field_int (req_cycle,  UVM_ALL_ON)
    `uvm_field_int (grant_wait_cycles, UVM_ALL_ON)
    `uvm_field_int (accept_order, UVM_ALL_ON)
    `uvm_field_int (response_order, UVM_ALL_ON)
    `uvm_field_int (source_type, UVM_ALL_ON)
    `uvm_field_int (source_id,   UVM_ALL_ON)
    `uvm_field_int (source_vpn,  UVM_ALL_ON)
    `uvm_field_enum(ptw_rsp_kind_e, rsp_kind, UVM_ALL_ON)
    `uvm_field_enum(ptw_rsp_order_e, rsp_order, UVM_ALL_ON)
    `uvm_field_enum(ptw_grant_mode_e, grant_mode, UVM_ALL_ON)
    `uvm_field_int (rsp_delay,  UVM_ALL_ON)
    `uvm_field_int (pte_data,   UVM_ALL_ON)
    `uvm_field_int (bus_error,  UVM_ALL_ON)
  `uvm_object_utils_end

  // ── Request fields (filled by monitor from DUT) ──────────────────────────
  bit [39:0] addr;          // PTW request address (PA to read PTE from)
  bit [3:0]  id;            // PTW MBUF entry id returned with the response
  bit        req_size;      // 0=4B, 1=8B  (always 8B for PTE fetch)
  bit [3:0]  req_id;        // Request ID carried on mmu_lsu_data_req_id
  bit        req_fire;      // Request accepted by LSU: req && grant
  int unsigned req_cycle;   // Monitor cycle when request fired
  int unsigned grant_wait_cycles; // Cycles req waited with grant low
  int unsigned accept_order;      // Monotonic request fire order

  // ── Response control fields (randomizable; used by responder) ────────────
  rand ptw_rsp_kind_e rsp_kind;
  rand ptw_rsp_order_e rsp_order;
  rand ptw_grant_mode_e grant_mode;
  rand int unsigned   rsp_delay;  // delay in clock cycles before asserting vld

  // ── Response data fields (filled by page_table_builder / monitor) ────────
  bit [3:0]  rsp_id;        // Response ID carried on lsu_mmu_data_id
  bit        rsp_valid;     // Response beat observed
  bit        rsp_is_ooo;    // Response order differs from accept order
  bit        rsp_id_invalid;// Response ID is outside legal MBUF range 0..8
  bit        rsp_without_pending; // Legal response ID has no matching request
  bit        duplicate_id_error;
  bit        aborted_before_grant;
  bit        abort_drain_rsp;
  int unsigned response_order; // Monotonic response beat order
  bit [63:0] pte_data;      // PTE returned to DUT
  bit        bus_error;     // 1 = bus error injection

  // ── Optional source binding fields, filled by later phases ───────────────
  logic [2:0]  source_type;
  logic [6:0]  source_id;
  logic [26:0] source_vpn;

  // Default constraints
  constraint c_rsp_kind_normal { rsp_kind == PTW_RSP_NORMAL; }
  constraint c_rsp_order_normal { rsp_order == PTW_RSP_IN_ORDER; }
  constraint c_grant_mode_normal { grant_mode == PTW_GRANT_ALWAYS_READY; }
  constraint c_rsp_delay       { rsp_delay inside {[1:8]}; }

  function new(string name = "ptw_mem_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      {"addr=0x%010h size=%0b legacy_id=0x%0h req_id=0x%0h rsp_id=0x%0h ",
       "req_fire=%0b rsp_valid=%0b req_cycle=%0d accept_order=%0d ",
       "response_order=%0d grant_wait=%0d bus_error=%0b ",
       "rsp_kind=%s rsp_order=%s grant_mode=%s ooo=%0b invalid_id=%0b no_pending=%0b ",
       "dup_id=%0b aborted_before_grant=%0b abort_drain=%0b ",
       "source={type:0x%0h,id:0x%02h,vpn:0x%07h} delay=%0d pte=0x%016h"},
      addr, req_size, id, req_id, rsp_id,
      req_fire, rsp_valid, req_cycle, accept_order,
      response_order, grant_wait_cycles, bus_error,
      rsp_kind.name(), rsp_order.name(), grant_mode.name(), rsp_is_ooo,
      rsp_id_invalid, rsp_without_pending, duplicate_id_error,
      aborted_before_grant, abort_drain_rsp, source_type, source_id, source_vpn,
      rsp_delay, pte_data);
  endfunction

endclass : ptw_mem_txn

`endif // PTW_MEM_TXN_SVH
