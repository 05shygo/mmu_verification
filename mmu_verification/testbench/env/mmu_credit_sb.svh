// =============================================================================
// MMU UVM Verification — testbench/env/mmu_credit_sb.svh
// Phase 5 (Engineer A): MMU Credit / Capacity Scoreboard
//
// Monitors four hardware resource counters for capacity conservation:
//
//   m_credit_l1i   — outstanding IFU translation requests
//     ifu ap_req   → +1 (request in-flight)
//     ifu ap_rsp   → -1 (request completed)
//     Upper bound  : L1_ITLB_ENTRIES (16)
//
//   m_credit_l1d   — outstanding LSU translation requests (external view)
//     lsu p0/p1 ap_req → +1
//     lsu p0/p1 ap_rsp → -1
//     NOTE: under heavy backpressure / timeout, LSU-side sleeping requests
//     can make this externally-visible count exceed L1_DTLB_ENTRIES.
//     It is therefore a conservation trend signal, not a strict capacity cap.
//
//   m_lsu_ext_outstanding — LSU externally-visible uncompleted requests (approx)
//     lsu p0/p1 ap_req → +1
//     lsu p0/p1 ap_rsp → -1
//     NOTE: this is NOT the true MMU-internal miss-buffer occupancy.
//     Three categories exist:
//       (1) L1 DTLB hit → rsp returns same cycle, never enters MB
//       (2) L1 miss + MB has slot → enters MB, serviced by PTW
//       (3) L1 miss while MMU reports tlb_busy → request sleeps at LSU/LSIQ
//           side, awaiting mmu_lsu_tlb_wakeup before re-issuing to MMU
//     This counter includes ALL three categories.  The true MB occupancy
//     (category 2 only) is always ≤ this count.  Overflow beyond
//     L1_DTLB_MB_DEPTH is therefore a WARNING (expected under backpressure),
//     not a hard error.
//
//   m_ptw_mbuf_cnt — PTW->LSU serialized external request outstanding proxy
//     ptw_mem ap_req  → +1 (new PTW memory read issued)
//     ptw_mem ap_rsp  → -1 (PTW memory read completed)
//     ptw_mem ap_drop → -1 (request cancelled before any response)
//     PTW external LSU request channel is single-outstanding by protocol.
//     A pending request may still be cancelled by invalidate/abort, so the
//     externally-visible lifetime is req → rsp OR req → drop.
//     Therefore this counter must stay within {0,1}; it is NOT the DUT's
//     internal 9-entry PTW mbuf occupancy.
//
// Conservation: m_credit_l1i/l1d/ptw_mbuf_cnt must == 0 at report_phase.
// m_lsu_ext_outstanding may be non-zero at end-of-sim if LSU-side sleeping
// requests were never re-issued (expected under timeout/backpressure).
//
// Eight TLM analysis FIFOs (one per AP stream):
//   af_ifu_req, af_ifu_rsp, af_ifu_drop,
//   af_lsu_p0_req, af_lsu_p0_rsp, af_lsu_p0_drop,
//   af_lsu_p1_req, af_lsu_p1_rsp, af_lsu_p1_drop,
//   af_ptw_req, af_ptw_rsp, af_ptw_drop
//
// Connected in mmu_env::connect_phase (fan-out from monitors).
// =============================================================================
`ifndef MMU_CREDIT_SB_SVH
`define MMU_CREDIT_SB_SVH

class mmu_credit_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_credit_sb)

  virtual mmu_dut_probes_if v_probe;

  // ── TLM Analysis FIFOs (8 streams) ────────────────────────────────────────
  // IFU
  uvm_tlm_analysis_fifo #(ifu_txn)      af_ifu_req;
  uvm_tlm_analysis_fifo #(ifu_txn)      af_ifu_rsp;
  uvm_tlm_analysis_fifo #(ifu_txn)      af_ifu_drop;
  // LSU pipe 0
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p0_req;
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p0_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p0_drop;
  // LSU pipe 1
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p1_req;
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p1_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p1_drop;
  // PTW memory channel
  uvm_tlm_analysis_fifo #(ptw_mem_txn)  af_ptw_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)  af_ptw_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)  af_ptw_drop;

  // ── Credit / occupancy counters (all start at 0) ──────────────────────────
  protected int m_credit_l1i;          // outstanding IFU translation requests
  protected int m_credit_l1d;          // outstanding LSU translation requests (external)
  protected int m_lsu_ext_outstanding; // LSU externally-visible uncompleted (approx, includes sleeping)
  protected int m_ptw_mbuf_cnt;        // PTW serialized external outstanding proxy
  protected bit m_end_drain_active;    // run-phase end settle window in progress
  protected bit m_end_drain_attempted; // prevent repeated ready_to_end loops

  // ── Peak observations (for debug) ─────────────────────────────────────────
  protected int m_peak_l1i;
  protected int m_peak_l1d;
  protected int m_peak_lsu_ext;
  protected int m_peak_ptw_mbuf;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_credit_l1i          = 0;
    m_credit_l1d          = 0;
    m_lsu_ext_outstanding = 0;
    m_ptw_mbuf_cnt        = 0;
    m_end_drain_active    = 1'b0;
    m_end_drain_attempted = 1'b0;
    m_peak_l1i            = 0;
    m_peak_l1d            = 0;
    m_peak_lsu_ext        = 0;
    m_peak_ptw_mbuf       = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_ifu_req    = new("af_ifu_req",    this);
    af_ifu_rsp    = new("af_ifu_rsp",    this);
    af_ifu_drop   = new("af_ifu_drop",   this);
    af_lsu_p0_req = new("af_lsu_p0_req", this);
    af_lsu_p0_rsp = new("af_lsu_p0_rsp", this);
    af_lsu_p0_drop = new("af_lsu_p0_drop", this);
    af_lsu_p1_req = new("af_lsu_p1_req", this);
    af_lsu_p1_rsp = new("af_lsu_p1_rsp", this);
    af_lsu_p1_drop = new("af_lsu_p1_drop", this);
    af_ptw_req    = new("af_ptw_req",    this);
    af_ptw_rsp    = new("af_ptw_rsp",    this);
    af_ptw_drop   = new("af_ptw_drop",   this);
    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe))
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF not in config_db — PTW end-drain will use #1ns fallback",
        UVM_LOW)
  endfunction

  // ── run_phase: fork all analysis-fifo consumer threads ───────────────────
  virtual task run_phase(uvm_phase phase);
    fork
      _consume_ifu_req();
      _consume_ifu_rsp();
      _consume_ifu_drop();
      _consume_lsu_p0_req();
      _consume_lsu_p0_rsp();
      _consume_lsu_p0_drop();
      _consume_lsu_p1_req();
      _consume_lsu_p1_rsp();
      _consume_lsu_p1_drop();
      _consume_ptw_req();
      _consume_ptw_rsp();
      _consume_ptw_drop();
    join_none
  endtask

  // ── IFU request: credit_l1i +1 ───────────────────────────────────────────
  protected task _consume_ifu_req();
    ifu_txn tr;
    forever begin
      af_ifu_req.get(tr);
      // IFU abort has no translation response by definition; do not count it
      // into conservation credit, otherwise credit_l1i will leak/overflow.
      if (tr.abort) begin
        `uvm_info(get_type_name(),
          "IFU_REQ abort observed: skip credit_l1i accounting", UVM_HIGH)
        continue;
      end
      m_credit_l1i++;
      if (m_credit_l1i > int'(L1_ITLB_ENTRIES))
        `uvm_error(get_type_name(),
          $sformatf("credit_l1i overflow: %0d > L1_ITLB_ENTRIES=%0d",
            m_credit_l1i, L1_ITLB_ENTRIES))
      if (m_credit_l1i > m_peak_l1i) m_peak_l1i = m_credit_l1i;
      `uvm_info(get_type_name(),
        $sformatf("IFU_REQ: credit_l1i=%0d", m_credit_l1i), UVM_HIGH)
    end
  endtask

  // ── IFU response: credit_l1i -1 ──────────────────────────────────────────
  protected task _consume_ifu_rsp();
    ifu_txn tr;
    forever begin
      af_ifu_rsp.get(tr);
      // Defensive symmetry: if an abort-tagged rsp appears, ignore in credit.
      if (tr.abort) begin
        `uvm_info(get_type_name(),
          "IFU_RSP abort-tagged txn observed: skip credit_l1i accounting", UVM_HIGH)
        continue;
      end
      m_credit_l1i--;
      if (m_credit_l1i < 0)
        `uvm_error(get_type_name(),
          $sformatf("credit_l1i underflow: %0d (spurious IFU response?)",
            m_credit_l1i))
      `uvm_info(get_type_name(),
        $sformatf("IFU_RSP: credit_l1i=%0d", m_credit_l1i), UVM_HIGH)
    end
  endtask

  // ── IFU dropped pending request: credit_l1i -1 (compensation path) ───────
  // For IFU hold protocol, a monitor-side dropped pending req means a request
  // was previously counted at ap_req but finished without a visible ap_rsp.
  // Compensate credit to keep req/rsp conservation aligned with observed flow.
  protected task _consume_ifu_drop();
    ifu_txn tr;
    forever begin
      af_ifu_drop.get(tr);
      if (tr.abort) begin
        `uvm_info(get_type_name(),
          "IFU_DROP abort-tagged txn observed: skip credit_l1i accounting", UVM_HIGH)
        continue;
      end
      m_credit_l1i--;
      if (m_credit_l1i < 0) begin
        `uvm_warning(get_type_name(),
          $sformatf("credit_l1i drop-comp underflow: %0d (drop without matching req?)",
            m_credit_l1i))
        m_credit_l1i = 0;
      end
      `uvm_info(get_type_name(),
        $sformatf("IFU_DROP: credit_l1i=%0d", m_credit_l1i), UVM_HIGH)
    end
  endtask

  // ── LSU pipe0 request: credit_l1d +1, lsu_ext_outstanding +1 ────────────
  protected task _consume_lsu_p0_req();
    lsu_txn tr;
    forever begin
      af_lsu_p0_req.get(tr);
      m_credit_l1d++;
      m_lsu_ext_outstanding++;
      _check_l1d_bound();
      _check_lsu_ext_bound();
      if (m_credit_l1d          > m_peak_l1d)    m_peak_l1d    = m_credit_l1d;
      if (m_lsu_ext_outstanding > m_peak_lsu_ext) m_peak_lsu_ext = m_lsu_ext_outstanding;
      `uvm_info(get_type_name(),
        $sformatf("LSU_P0_REQ: credit_l1d=%0d lsu_ext=%0d",
          m_credit_l1d, m_lsu_ext_outstanding), UVM_HIGH)
    end
  endtask

  // ── LSU pipe0 response: credit_l1d -1, lsu_ext_outstanding -1 ────────────
  protected task _consume_lsu_p0_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p0_rsp.get(tr);
      m_credit_l1d--;
      m_lsu_ext_outstanding--;
      _check_l1d_underflow();
      _check_lsu_ext_underflow();
      `uvm_info(get_type_name(),
        $sformatf("LSU_P0_RSP: credit_l1d=%0d lsu_ext=%0d",
          m_credit_l1d, m_lsu_ext_outstanding), UVM_HIGH)
    end
  endtask

  // ── LSU pipe0 retry/drop compensation ───────────────────────────────────
  protected task _consume_lsu_p0_drop();
    lsu_txn tr;
    forever begin
      af_lsu_p0_drop.get(tr);
      m_credit_l1d--;
      m_lsu_ext_outstanding--;
      _check_l1d_underflow();
      _check_lsu_ext_underflow();
      `uvm_info(get_type_name(),
        $sformatf("LSU_P0_DROP: credit_l1d=%0d lsu_ext=%0d",
          m_credit_l1d, m_lsu_ext_outstanding), UVM_HIGH)
    end
  endtask

  // ── LSU pipe1 request: credit_l1d +1, lsu_ext_outstanding +1 ────────────
  protected task _consume_lsu_p1_req();
    lsu_txn tr;
    forever begin
      af_lsu_p1_req.get(tr);
      m_credit_l1d++;
      m_lsu_ext_outstanding++;
      _check_l1d_bound();
      _check_lsu_ext_bound();
      if (m_credit_l1d          > m_peak_l1d)    m_peak_l1d    = m_credit_l1d;
      if (m_lsu_ext_outstanding > m_peak_lsu_ext) m_peak_lsu_ext = m_lsu_ext_outstanding;
      `uvm_info(get_type_name(),
        $sformatf("LSU_P1_REQ: credit_l1d=%0d lsu_ext=%0d",
          m_credit_l1d, m_lsu_ext_outstanding), UVM_HIGH)
    end
  endtask

  // ── LSU pipe1 response: credit_l1d -1, lsu_ext_outstanding -1 ────────────
  protected task _consume_lsu_p1_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p1_rsp.get(tr);
      m_credit_l1d--;
      m_lsu_ext_outstanding--;
      _check_l1d_underflow();
      _check_lsu_ext_underflow();
      `uvm_info(get_type_name(),
        $sformatf("LSU_P1_RSP: credit_l1d=%0d lsu_ext=%0d",
          m_credit_l1d, m_lsu_ext_outstanding), UVM_HIGH)
    end
  endtask

  // ── LSU pipe1 retry/drop compensation ───────────────────────────────────
  protected task _consume_lsu_p1_drop();
    lsu_txn tr;
    forever begin
      af_lsu_p1_drop.get(tr);
      m_credit_l1d--;
      m_lsu_ext_outstanding--;
      _check_l1d_underflow();
      _check_lsu_ext_underflow();
      `uvm_info(get_type_name(),
        $sformatf("LSU_P1_DROP: credit_l1d=%0d lsu_ext=%0d",
          m_credit_l1d, m_lsu_ext_outstanding), UVM_HIGH)
    end
  endtask

  // ── PTW request: ptw_mbuf_cnt +1 ─────────────────────────────────────────
  protected task _consume_ptw_req();
    ptw_mem_txn tr;
    forever begin
      af_ptw_req.get(tr);
      m_ptw_mbuf_cnt++;
      if (m_ptw_mbuf_cnt > 1)
        `uvm_error(get_type_name(),
          $sformatf(
            "ptw_mbuf_cnt(serialized PTW ext outstanding) overflow: %0d > 1 for addr=0x%010h",
            m_ptw_mbuf_cnt, tr.addr))
      if (m_ptw_mbuf_cnt > m_peak_ptw_mbuf) m_peak_ptw_mbuf = m_ptw_mbuf_cnt;
      `uvm_info(get_type_name(),
        $sformatf("PTW_REQ: ptw_mbuf_cnt=%0d", m_ptw_mbuf_cnt), UVM_HIGH)
    end
  endtask

  // ── PTW response: ptw_mbuf_cnt -1 ────────────────────────────────────────
  protected task _consume_ptw_rsp();
    ptw_mem_txn tr;
    forever begin
      af_ptw_rsp.get(tr);
      m_ptw_mbuf_cnt--;
      if (m_ptw_mbuf_cnt < 0)
        `uvm_error(get_type_name(),
          $sformatf("ptw_mbuf_cnt underflow: %0d (spurious PTW response?)",
            m_ptw_mbuf_cnt))
      `uvm_info(get_type_name(),
        $sformatf("PTW_RSP: ptw_mbuf_cnt=%0d", m_ptw_mbuf_cnt), UVM_HIGH)
    end
  endtask

  // ── PTW request cancelled before response: ptw_mbuf_cnt -1 ────────────────
  protected task _consume_ptw_drop();
    ptw_mem_txn tr;
    forever begin
      af_ptw_drop.get(tr);
      m_ptw_mbuf_cnt--;
      if (m_ptw_mbuf_cnt < 0)
        `uvm_error(get_type_name(),
          $sformatf("ptw_mbuf_cnt underflow on drop: %0d (spurious PTW drop?)",
            m_ptw_mbuf_cnt))
      `uvm_info(get_type_name(),
        $sformatf("PTW_DROP: ptw_mbuf_cnt=%0d addr=0x%010h", m_ptw_mbuf_cnt, tr.addr),
        UVM_HIGH)
    end
  endtask

  // ── phase_ready_to_end: allow late PTW completion / abort settle ─────────
  // The PTW->LSU channel is single-outstanding and responder latency is small
  // (normally 1..8 cycles). Give it one bounded settle window before
  // report_phase so a final in-flight memory response can retire cleanly.
  virtual function void phase_ready_to_end(uvm_phase phase);
    if (phase.get_name() != "run")
      return;

    if (m_end_drain_active)
      return;

    if (m_end_drain_attempted)
      return;

    if (m_ptw_mbuf_cnt != 0) begin
      m_end_drain_active = 1'b1;
      m_end_drain_attempted = 1'b1;
      phase.raise_objection(this,
        $sformatf("Settling PTW counter before end: ptw_mbuf_cnt=%0d",
          m_ptw_mbuf_cnt));
      fork
        begin
          _drain_ptw_before_end(phase);
        end
      join_none
    end
  endfunction

  protected task _drain_ptw_before_end(uvm_phase phase);
    int unsigned wait_cycles;
    int unsigned max_wait_cycles;

    wait_cycles     = 0;
    max_wait_cycles = 64;

    while ((m_ptw_mbuf_cnt != 0) &&
           (wait_cycles < max_wait_cycles)) begin
      if (v_probe != null)
        @(v_probe.mon_cb);
      else
        #1ns;
      wait_cycles++;
    end

    if (m_ptw_mbuf_cnt != 0) begin
      `uvm_warning(get_type_name(),
        $sformatf(
          "PTW end-drain timeout after %0d cycles: ptw_mbuf_cnt=%0d",
          wait_cycles, m_ptw_mbuf_cnt))
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("PTW end-drain settled after %0d cycles", wait_cycles),
        UVM_MEDIUM)
    end

    m_end_drain_active = 1'b0;
    phase.drop_objection(this, "PTW counters settled (or timeout reached)");
  endtask

  // ── Inline bound checks ───────────────────────────────────────────────────
  protected function void _check_l1d_bound();
    if (m_credit_l1d > int'(L1_DTLB_ENTRIES))
      `uvm_warning(get_type_name(),
        $sformatf("credit_l1d approx overflow: %0d > L1_DTLB_ENTRIES=%0d (external outstanding may include LSU-side sleeping requests)",
          m_credit_l1d, L1_DTLB_ENTRIES))
  endfunction

  // lsu_ext_outstanding includes LSU-side sleeping requests that have NOT
  // entered the MMU miss buffer.  Exceeding L1_DTLB_MB_DEPTH is expected
  // under backpressure (category-3 requests per LSU sleep-request semantics).
  protected function void _check_lsu_ext_bound();
    if (m_lsu_ext_outstanding > int'(L1_DTLB_MB_DEPTH))
      `uvm_warning(get_type_name(),
        $sformatf("lsu_ext_outstanding approx overflow: %0d > L1_DTLB_MB_DEPTH=%0d (includes LSU-side sleeping requests)",
          m_lsu_ext_outstanding, L1_DTLB_MB_DEPTH))
  endfunction

  protected function void _check_l1d_underflow();
    if (m_credit_l1d < 0)
      `uvm_error(get_type_name(),
        $sformatf("credit_l1d underflow: %0d (spurious LSU response?)",
          m_credit_l1d))
  endfunction

  protected function void _check_lsu_ext_underflow();
    if (m_lsu_ext_outstanding < 0)
      `uvm_error(get_type_name(),
        $sformatf("lsu_ext_outstanding underflow: %0d (spurious LSU response?)",
          m_lsu_ext_outstanding))
  endfunction

  // ── report_phase: assert all counters == 0 ────────────────────────────────
  // A non-zero counter at end-of-sim means a transaction was "leaked"
  // (request without matching response, or response without request).
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf({"[CreditSB] Summary:\n",
        "  credit_l1i          = %0d  (peak=%0d, limit=%0d)\n",
        "  credit_l1d          = %0d  (peak=%0d, limit=%0d)\n",
        "  lsu_ext_outstanding = %0d  (peak=%0d, MB_depth=%0d)  [approx, includes sleeping]\n",
        "  ptw_mbuf_cnt        = %0d  (peak=%0d, serialized ext limit=1)"},
        m_credit_l1i,          m_peak_l1i,      L1_ITLB_ENTRIES,
        m_credit_l1d,          m_peak_l1d,      L1_DTLB_ENTRIES,
        m_lsu_ext_outstanding, m_peak_lsu_ext,  L1_DTLB_MB_DEPTH,
        m_ptw_mbuf_cnt,        m_peak_ptw_mbuf),
      UVM_MEDIUM)

    if (m_credit_l1i != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] credit_l1i != 0 at end-of-sim (%0d): leaked IFU txns",
          m_credit_l1i))

    if (m_credit_l1d != 0)
      `uvm_warning(get_type_name(),
        $sformatf("[CreditSB] credit_l1d != 0 at end-of-sim (%0d): includes timed-out/sleeping LSU requests in external view",
          m_credit_l1d))

    // lsu_ext_outstanding may be non-zero if driver timeouts caused requests to
    // be abandoned without a DUT response.  This is expected under backpressure
    // or when sleeping LSU requests never received a wakeup re-issue.
    if (m_lsu_ext_outstanding != 0)
      `uvm_warning(get_type_name(),
        $sformatf("[CreditSB] lsu_ext_outstanding != 0 at end-of-sim (%0d): includes timed-out/sleeping LSU requests",
          m_lsu_ext_outstanding))

    if (m_ptw_mbuf_cnt != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] ptw_mbuf_cnt != 0 at end-of-sim (%0d): PTW serialized external request not drained",
          m_ptw_mbuf_cnt))

    if (m_credit_l1i == 0 && m_credit_l1d == 0 && m_ptw_mbuf_cnt == 0)
      `uvm_info(get_type_name(),
        "[CreditSB] PASS — credit conservation verified (l1i/l1d/ptw all == 0)",
        UVM_MEDIUM)
  endfunction

endclass : mmu_credit_sb

`endif // MMU_CREDIT_SB_SVH
