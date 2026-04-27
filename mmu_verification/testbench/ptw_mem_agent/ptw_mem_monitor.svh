// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_monitor.svh
// Phase 4: PTW memory channel monitor
//
// Observes both the DUT-initiated request and the TB-driven response:
//   ap_req:  fires when a new serial PTW request becomes outstanding
//   ap_rsp:  fires when TB asserts lsu_mmu_data_vld=1 or lsu_mmu_bus_error=1
//   ap_drop: fires when a pending PTW request is cancelled before any response
//
// Downstream consumers (connected in Phase 5 env.connect_phase):
//   ap_req  → credit_sb.af_ptw_req, perf.af_ptw_req
//   ap_rsp  → credit_sb.af_ptw_rsp, perf.af_ptw_rsp
//   ap_drop → credit_sb.af_ptw_drop
// =============================================================================
`ifndef PTW_MEM_MONITOR_SVH
`define PTW_MEM_MONITOR_SVH

class ptw_mem_monitor extends uvm_monitor;

  `uvm_component_utils(ptw_mem_monitor)

  virtual ptw_mem_if vif;

  // Analysis ports
  uvm_analysis_port #(ptw_mem_txn) ap_req;   // DUT request (addr)
  uvm_analysis_port #(ptw_mem_txn) ap_rsp;   // TB response (PTE data / bus_error)
  uvm_analysis_port #(ptw_mem_txn) ap_drop;  // Pending req cancelled before rsp

  // PTW LSU protocol is strict serial single-outstanding. req may remain high
  // across back-to-back requests, but there is still only one externally
  // outstanding request at a time. After a rsp cycle completes, any req that
  // is still high on a later cycle is a new request, even if addr/size repeat.
  protected bit [39:0]  m_pending_addr;
  protected bit         m_pending_size;
  protected bit         m_has_pending;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_has_pending = 1'b0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ptw_mem_if)::get(this, "", "PTW_MEM_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PTW_MEM_VIF from config_db")
    ap_req = new("ap_req", this);
    ap_rsp = new("ap_rsp", this);
    ap_drop = new("ap_drop", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Wait for reset
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    collect_channel();
  endtask

  // ── Cycle-accurate collector for strict serial PTW protocol ───────────────
  // Open a request when req is high and no request is pending. Keep the
  // pending request until data_vld/bus_error returns. If the DUT withdraws or
  // replaces the request before a response, treat it as a cancelled walk slot,
  // publish ap_drop for downstream credit compensation, and only reopen on a
  // later sampled cycle (avoid same-cycle drop+req double counting).
  protected task collect_channel();
    forever begin
      bit         req_seen;
      bit         rsp_seen;
      bit [39:0]  cur_addr;
      bit         cur_size;
      ptw_mem_txn tr;
      ptw_mem_txn drop_tr;

      @(vif.monitor_cb);

      if (vif.rst_ni !== 1'b1) begin
        m_has_pending = 1'b0;
        continue;
      end

      req_seen = (vif.monitor_cb.mmu_lsu_data_req  === 1'b1);
      rsp_seen = (vif.monitor_cb.lsu_mmu_data_vld  === 1'b1) ||
                 (vif.monitor_cb.lsu_mmu_bus_error === 1'b1);
      cur_addr = vif.monitor_cb.mmu_lsu_data_req_addr;
      cur_size = vif.monitor_cb.mmu_lsu_data_req_size;

      if (rsp_seen) begin
        tr           = ptw_mem_txn::type_id::create("ptw_rsp");
        tr.pte_data  = vif.monitor_cb.lsu_mmu_data;
        tr.bus_error = vif.monitor_cb.lsu_mmu_bus_error;
        if (m_has_pending) begin
          tr.addr     = m_pending_addr;
          tr.req_size = m_pending_size;
          m_has_pending = 1'b0;
        end else begin
          `uvm_warning(get_type_name(),
            $sformatf("PTW rsp observed without pending req: pte=0x%016h bus_err=%0b req=%0b addr=0x%010h",
              tr.pte_data, tr.bus_error, req_seen, cur_addr))
        end
        `uvm_info(get_type_name(),
          $sformatf("PTW RSP: pte=0x%016h bus_err=%0b", tr.pte_data, tr.bus_error),
          UVM_HIGH)
        ap_rsp.write(tr);
      end

      if (!rsp_seen && m_has_pending) begin
        if (!req_seen) begin
          drop_tr          = ptw_mem_txn::type_id::create("ptw_drop");
          drop_tr.addr     = m_pending_addr;
          drop_tr.req_size = m_pending_size;
          `uvm_info(get_type_name(),
            $sformatf(
              "[PTW_REQ_CANCEL] pending req dropped before rsp: addr=0x%010h size=%0b",
              m_pending_addr, m_pending_size),
            UVM_MEDIUM)
          m_has_pending = 1'b0;
          ap_drop.write(drop_tr);
          continue;
        end

        if ((cur_addr !== m_pending_addr) || (cur_size !== m_pending_size)) begin
          drop_tr          = ptw_mem_txn::type_id::create("ptw_drop");
          drop_tr.addr     = m_pending_addr;
          drop_tr.req_size = m_pending_size;
          `uvm_info(get_type_name(),
            $sformatf(
              "[PTW_REQ_REPLACE] pending req replaced before rsp: old_addr=0x%010h new_addr=0x%010h old_size=%0b new_size=%0b",
              m_pending_addr, cur_addr, m_pending_size, cur_size),
            UVM_MEDIUM)
          m_has_pending = 1'b0;
          ap_drop.write(drop_tr);
          continue;
        end
      end

      // Never reopen on the same sampled cycle as rsp_seen. In this protocol
      // req high on the rsp cycle is still the retiring transaction's tail.
      if (!rsp_seen) begin
        if (!m_has_pending && req_seen) begin
          tr          = ptw_mem_txn::type_id::create("ptw_req");
          tr.addr     = cur_addr;
          tr.req_size = cur_size;
          m_pending_addr = cur_addr;
          m_pending_size = cur_size;
          m_has_pending = 1'b1;
          `uvm_info(get_type_name(),
            $sformatf("PTW REQ: addr=0x%010h size=%0b", tr.addr, tr.req_size),
            UVM_HIGH)
          ap_req.write(tr);
        end

      end
    end
  endtask

endclass : ptw_mem_monitor

`endif // PTW_MEM_MONITOR_SVH
