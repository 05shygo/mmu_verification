// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_monitor.svh
// Phase 3 (Engineer B): LSU monitor skeleton — 8 analysis ports
//   ap_pipe0_req / ap_pipe0_rsp
//   ap_pipe1_req / ap_pipe1_rsp
//   ap_pipe2_req / ap_pipe2_rsp
//   ap_inv   (TLB invalidation events)
//   ap_stamo (STAMO PA check)
//
// Phase 5 (Engineer B): Added m_pending_p0/p1 queues for req/rsp correlation.
//   pipe0/pipe1 are each 1-outstanding per stall protocol; FIFO order holds.
//   ap_pipe0_rsp / ap_pipe1_rsp txns carry VA+id+st_inst merged from the req
//   so that downstream mmu_translation_sb can call ref_model.translate().
//
// Phase 5 downstream connections:
//   ap_pipe0_rsp → mmu_translation_sb.af_lsu_pipe0_rsp
//   ap_pipe1_rsp → mmu_translation_sb.af_lsu_pipe1_rsp
//   ap_inv       → mmu_invalidate_sb.af_lsu_inv  (Phase 6)
// =============================================================================
`ifndef LSU_MONITOR_SVH
`define LSU_MONITOR_SVH

class lsu_monitor extends uvm_monitor;

  `uvm_component_utils(lsu_monitor)

  virtual lsu_if vif;

  // Pipe 0
  uvm_analysis_port #(lsu_txn) ap_pipe0_req;
  uvm_analysis_port #(lsu_txn) ap_pipe0_rsp;
  // Pipe 1
  uvm_analysis_port #(lsu_txn) ap_pipe1_req;
  uvm_analysis_port #(lsu_txn) ap_pipe1_rsp;
  // Pipe 2 (prefetch)
  uvm_analysis_port #(lsu_txn) ap_pipe2_req;
  uvm_analysis_port #(lsu_txn) ap_pipe2_rsp;
  // TLB Invalidation
  uvm_analysis_port #(lsu_txn) ap_inv;
  // STAMO PA check
  uvm_analysis_port #(lsu_txn) ap_stamo;

  // Phase 5: Outstanding request queues for pipe0/pipe1 req/rsp correlation.
  // Each pipe is 1-outstanding (stall until pa_vld), FIFO pop is safe.
  protected lsu_txn m_pending_p0[$];
  protected lsu_txn m_pending_p1[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual lsu_if)::get(this, "", "LSU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get LSU_VIF from config_db")
    ap_pipe0_req = new("ap_pipe0_req", this);
    ap_pipe0_rsp = new("ap_pipe0_rsp", this);
    ap_pipe1_req = new("ap_pipe1_req", this);
    ap_pipe1_rsp = new("ap_pipe1_rsp", this);
    ap_pipe2_req = new("ap_pipe2_req", this);
    ap_pipe2_rsp = new("ap_pipe2_rsp", this);
    ap_inv       = new("ap_inv",       this);
    ap_stamo     = new("ap_stamo",     this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      _collect_pipe0_req();
      _collect_pipe0_rsp();
      _collect_pipe1_req();
      _collect_pipe1_rsp();
      _collect_pipe2_req();
      _collect_pipe2_rsp();
      _collect_inv();
      _collect_stamo();
    join_none
  endtask

  // ── Pipe 0 request ────────────────────────────────────────────────────────
  // Phase 5: push to m_pending_p0 so _collect_pipe0_rsp can merge VA fields.
  // Edge detection: wait for va0_vld HIGH, sample once, then wait for LOW
  // before looping. This prevents duplicate publications when the driver holds
  // va0_vld asserted across multiple cycles (stall-until-pa_vld protocol).
  protected task _collect_pipe0_req();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_va0_vld);
      tr          = lsu_txn::type_id::create("lsu_p0_req");
      tr.kind     = LSU_PIPE0;
      tr.va       = vif.monitor_cb.lsu_mmu_va0;
      tr.id       = vif.monitor_cb.lsu_mmu_id0;
      tr.st_inst  = vif.monitor_cb.lsu_mmu_st_inst0;
      tr.abort    = vif.monitor_cb.lsu_mmu_abort0;
      tr.vabuf    = vif.monitor_cb.lsu_mmu_vabuf0;
      `uvm_info(get_type_name(), {"P0 REQ: ", tr.convert2string()}, UVM_HIGH)
      m_pending_p0.push_back(tr); // Enqueue for req/rsp correlation
      ap_pipe0_req.write(tr);
      // Wait for va0_vld to deassert (rising-edge semantics)
      @(vif.monitor_cb iff !vif.monitor_cb.lsu_mmu_va0_vld);
    end
  endtask

  // ── Pipe 0 response ───────────────────────────────────────────────────────
  // Phase 5: Pop oldest pending p0 req (FIFO), merge VA/id/st_inst into rsp_tr.
  protected task _collect_pipe0_rsp();
    lsu_txn tr, req_tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.mmu_lsu_pa0_vld);
      tr              = lsu_txn::type_id::create("lsu_p0_rsp");
      tr.kind         = LSU_PIPE0;
      tr.pa           = vif.monitor_cb.mmu_lsu_pa0;
      tr.pgflt        = vif.monitor_cb.mmu_lsu_page_fault0;
      tr.access_fault = vif.monitor_cb.mmu_lsu_access_fault0;
      tr.stall        = vif.monitor_cb.mmu_lsu_stall0;
      tr.sec          = vif.monitor_cb.mmu_lsu_sec0;
      // --- Req/rsp correlation (FIFO, 1-outstanding per pipe) ---
      wait(m_pending_p0.size() > 0);
      req_tr      = m_pending_p0.pop_front();
      tr.va       = req_tr.va;      // Carry VA for ref_model.translate()
      tr.id       = req_tr.id;      // Carry LSIQ id for ordering context
      tr.st_inst  = req_tr.st_inst; // Carry st/ld flag for ACC_STORE/ACC_LOAD
      `uvm_info(get_type_name(), {"P0 RSP: ", tr.convert2string()}, UVM_HIGH)
      ap_pipe0_rsp.write(tr);
    end
  endtask

  // ── Pipe 1 request ────────────────────────────────────────────────────────
  // Phase 5: push to m_pending_p1 so _collect_pipe1_rsp can merge VA fields.
  // Edge detection: same rising-edge approach as pipe0.
  protected task _collect_pipe1_req();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_va1_vld);
      tr         = lsu_txn::type_id::create("lsu_p1_req");
      tr.kind    = LSU_PIPE1;
      tr.va      = vif.monitor_cb.lsu_mmu_va1;
      tr.id      = vif.monitor_cb.lsu_mmu_id1;
      tr.st_inst = vif.monitor_cb.lsu_mmu_st_inst1;
      tr.abort   = vif.monitor_cb.lsu_mmu_abort1;
      tr.vabuf   = vif.monitor_cb.lsu_mmu_vabuf1;
      m_pending_p1.push_back(tr); // Enqueue for req/rsp correlation
      ap_pipe1_req.write(tr);
      // Wait for va1_vld to deassert (rising-edge semantics)
      @(vif.monitor_cb iff !vif.monitor_cb.lsu_mmu_va1_vld);
    end
  endtask

  // ── Pipe 1 response ───────────────────────────────────────────────────────
  // Phase 5: Pop oldest pending p1 req (FIFO), merge VA/id/st_inst into rsp_tr.
  protected task _collect_pipe1_rsp();
    lsu_txn tr, req_tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.mmu_lsu_pa1_vld);
      tr              = lsu_txn::type_id::create("lsu_p1_rsp");
      tr.kind         = LSU_PIPE1;
      tr.pa           = vif.monitor_cb.mmu_lsu_pa1;
      tr.pgflt        = vif.monitor_cb.mmu_lsu_page_fault1;
      tr.access_fault = vif.monitor_cb.mmu_lsu_access_fault1;
      tr.stall        = vif.monitor_cb.mmu_lsu_stall1;
      tr.sec          = vif.monitor_cb.mmu_lsu_sec1;
      // --- Req/rsp correlation (FIFO, 1-outstanding per pipe) ---
      wait(m_pending_p1.size() > 0);
      req_tr      = m_pending_p1.pop_front();
      tr.va       = req_tr.va;      // Carry VA for ref_model.translate()
      tr.id       = req_tr.id;      // Carry LSIQ id for ordering context
      tr.st_inst  = req_tr.st_inst; // Carry st/ld flag for ACC_STORE/ACC_LOAD
      ap_pipe1_rsp.write(tr);
    end
  endtask

  // ── Pipe 2 (prefetch) request ─────────────────────────────────────────────
  protected task _collect_pipe2_req();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_va2_vld);
      tr      = lsu_txn::type_id::create("lsu_p2_req");
      tr.kind = LSU_PIPE2;
      tr.va2  = vif.monitor_cb.lsu_mmu_va2;
      ap_pipe2_req.write(tr);
    end
  endtask

  // ── Pipe 2 (prefetch) response ────────────────────────────────────────────
  protected task _collect_pipe2_rsp();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.mmu_lsu_pa2_vld);
      tr      = lsu_txn::type_id::create("lsu_p2_rsp");
      tr.kind = LSU_PIPE2;
      tr.pa   = vif.monitor_cb.mmu_lsu_pa2;
      tr.sec  = vif.monitor_cb.mmu_lsu_sec2;
      ap_pipe2_rsp.write(tr);
    end
  endtask

  // ── TLB Invalidation event ────────────────────────────────────────────────
  protected task _collect_inv();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff (vif.monitor_cb.lsu_mmu_tlb_va_all_inv   |
                             vif.monitor_cb.lsu_mmu_tlb_all_inv      |
                             vif.monitor_cb.lsu_mmu_tlb_va_asid_inv  |
                             vif.monitor_cb.lsu_mmu_tlb_asid_all_inv));
      tr          = lsu_txn::type_id::create("lsu_inv");
      tr.kind     = LSU_INV;
      tr.inv_va   = vif.monitor_cb.lsu_mmu_tlb_va;
      tr.inv_asid = vif.monitor_cb.lsu_mmu_tlb_asid;
      tr.inv_done = vif.monitor_cb.mmu_lsu_tlb_inv_done;
      // Decode inv_kind from which strobe is high
      if      (vif.monitor_cb.lsu_mmu_tlb_all_inv)      tr.inv_kind = INV_ALL;
      else if (vif.monitor_cb.lsu_mmu_tlb_va_all_inv)   tr.inv_kind = INV_VA_ALL;
      else if (vif.monitor_cb.lsu_mmu_tlb_asid_all_inv) tr.inv_kind = INV_ASID_ALL;
      else                                               tr.inv_kind = INV_VA_ASID;
      `uvm_info(get_type_name(), {"INV: ", tr.convert2string()}, UVM_HIGH)
      ap_inv.write(tr);
    end
  endtask

  // ── STAMO physical address check ─────────────────────────────────────────
  protected task _collect_stamo();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_stamo_vld);
      tr          = lsu_txn::type_id::create("lsu_stamo");
      tr.kind     = LSU_STAMO;
      tr.stamo_pa = vif.monitor_cb.lsu_mmu_stamo_pa;
      ap_stamo.write(tr);
    end
  endtask

endclass : lsu_monitor

`endif // LSU_MONITOR_SVH
