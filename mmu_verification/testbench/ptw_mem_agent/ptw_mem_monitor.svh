// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_monitor.svh
// Phase 4: PTW memory channel monitor
//
// Observes both the DUT-initiated request and the TB-driven response:
//   ap_req: fires when DUT asserts mmu_lsu_data_req=1
//   ap_rsp: fires when TB asserts lsu_mmu_data_vld=1 or lsu_mmu_bus_error=1
//
// Downstream consumers (connected in Phase 5 env.connect_phase):
//   ap_req → translation_sb.af_ptw_req, credit_sb.af_ptw_req
//   ap_rsp → translation_sb.af_ptw_rsp, credit_sb.af_ptw_rsp
// =============================================================================
`ifndef PTW_MEM_MONITOR_SVH
`define PTW_MEM_MONITOR_SVH

class ptw_mem_monitor extends uvm_monitor;

  `uvm_component_utils(ptw_mem_monitor)

  virtual ptw_mem_if vif;

  // Analysis ports
  uvm_analysis_port #(ptw_mem_txn) ap_req;   // DUT request (addr)
  uvm_analysis_port #(ptw_mem_txn) ap_rsp;   // TB response (PTE data / bus_error)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ptw_mem_if)::get(this, "", "PTW_MEM_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PTW_MEM_VIF from config_db")
    ap_req = new("ap_req", this);
    ap_rsp = new("ap_rsp", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Wait for reset
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(vif.monitor_cb);

    fork
      collect_req();
      collect_rsp();
    join_none
  endtask

  // ── Sample DUT-side requests ───────────────────────────────────────────────
  protected task collect_req();
    forever begin
      ptw_mem_txn tr;
      // Edge-triggered: only capture on the cycle request is first asserted
      @(vif.monitor_cb iff vif.monitor_cb.mmu_lsu_data_req === 1'b1);
      tr          = ptw_mem_txn::type_id::create("ptw_req");
      tr.addr     = vif.monitor_cb.mmu_lsu_data_req_addr;
      tr.req_size = vif.monitor_cb.mmu_lsu_data_req_size;
      `uvm_info(get_type_name(),
        $sformatf("PTW REQ: addr=0x%010h size=%0b", tr.addr, tr.req_size),
        UVM_HIGH)
      ap_req.write(tr);
      // Skip cycles while request stays high (protocol: held stable until vld)
      @(vif.monitor_cb iff vif.monitor_cb.mmu_lsu_data_req !== 1'b1);
    end
  endtask

  // ── Sample TB-side responses ───────────────────────────────────────────────
  protected task collect_rsp();
    forever begin
      ptw_mem_txn tr;
      @(vif.monitor_cb iff
        (vif.monitor_cb.lsu_mmu_data_vld   === 1'b1 ||
         vif.monitor_cb.lsu_mmu_bus_error  === 1'b1));
      tr           = ptw_mem_txn::type_id::create("ptw_rsp");
      tr.pte_data  = vif.monitor_cb.lsu_mmu_data;
      tr.bus_error = vif.monitor_cb.lsu_mmu_bus_error;
      `uvm_info(get_type_name(),
        $sformatf("PTW RSP: pte=0x%016h bus_err=%0b",
          tr.pte_data, tr.bus_error), UVM_HIGH)
      ap_rsp.write(tr);
    end
  endtask

endclass : ptw_mem_monitor

`endif // PTW_MEM_MONITOR_SVH
