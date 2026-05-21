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
//     NOTE: under heavy backpressure, LSU-side sleeping requests
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
//     ptw_mem ap_drop → -1 (request cancelled by reset before response)
//     PTW external LSU request channel is single-outstanding by protocol.
//     Invalidate/abort may drop the visible req signal, but the accepted memory
//     read still returns a late response to retire RTL abort cleanup.
//     Therefore the externally-visible lifetime is normally req → rsp; reset
//     is the only modeled req → drop path.
//     Therefore this counter must stay within {0,1}; it is NOT the DUT's
//     internal 9-entry PTW mbuf occupancy.
//
// Conservation: m_credit_l1i/l1d/lsu_ext_outstanding/ptw_mbuf_cnt must be 0
// at report_phase.  LSU-side sleeping requests must be re-issued by the driver
// until a real DUT response is observed before the test is allowed to finish.
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
  protected bit m_pre_drop_drain_done;  // test_base already performed final drain
  protected bit m_last_drain_timed_out;
  protected int unsigned m_end_drain_attempts; // bounded ready_to_end retries
  protected int unsigned m_end_drain_max_cycles;
  protected int unsigned m_end_drain_stable_cycles;
  localparam int PTW_ID_WIDTH = 7;
  protected bit m_ptw_snap_valid;
  protected logic       m_snap_rst_ni;
  protected logic [8:0] m_snap_l2_reqq_vld_vec;
  protected logic [8:0] m_snap_l2_reqq_rdy_vec;
  protected logic       m_snap_l2_reqq_issue_valid;
  protected logic [2:0] m_snap_l2_reqq_issue_type;
  protected logic [8:0] m_snap_l2mb_vld_vec;
  protected logic [8:0] m_snap_l2mb_rdy_vec;
  protected logic       m_snap_l2mb_issue_req;
  protected logic [PTW_ID_WIDTH-1:0] m_snap_l2mb_issue_eid;
  protected logic [2:0] m_snap_l2mb_issue_type;
  protected logic       m_snap_l2mb_alloc_valid;
  protected logic [8:0][26:0] m_snap_l2mb_entry_vpn;
  protected logic [8:0][2:0]  m_snap_l2mb_entry_l1eid;
  protected logic [8:0][2:0]  m_snap_l2mb_entry_type;
  protected logic [8:0][2:0]  m_snap_l2mb_entry_queue_id;
  protected logic [8:0]       m_snap_l2mb_entry_sent;
  protected logic [7:0] m_snap_l1d_mb_vld;
  protected logic [7:0][2:0]  m_snap_l1d_mb_state;
  protected logic [7:0][26:0] m_snap_l1d_mb_vpn;
  protected logic [7:0][6:0]  m_snap_l1d_mb_iid;
  protected logic [7:0]       m_snap_l1d_mb_issued;
  protected logic [7:0]       m_snap_l1d_mb_ready;
  protected logic [7:0]       m_snap_l1d_mb_wfc;
  protected logic [7:0]       m_snap_l1d_mb_wfi;
  protected logic [7:0]       m_snap_l1d_mb_store;
  protected logic       m_snap_l2_final_vld;
  protected logic       m_snap_l2_miss;
  protected logic       m_snap_l2_dtlb_ref_pavld;
  protected logic       m_snap_l2_dtlb_ref_cmplt;
  protected logic       m_snap_l2tlb_ptw_req;
  protected logic [PTW_ID_WIDTH-1:0] m_snap_l2tlb_ptw_id;
  protected logic [2:0] m_snap_l2tlb_ptw_type;
  protected logic       m_snap_ptw_l2tlb_cmplt;
  protected logic [PTW_ID_WIDTH-1:0] m_snap_ptw_l2tlb_id;
  protected logic [2:0] m_snap_ptw_l2tlb_type;
  protected logic       m_snap_ptw_l1i_ref_cmplt;
  protected logic [8:0] m_snap_ptw_mbuf_entry_vld;
  protected logic [3:0] m_snap_ptw_mbuf_twu_have;
  protected logic [3:0] m_snap_ptw_twu_idle;
  protected logic [3:0] m_snap_ptw_twu_mask;
  protected logic [3:0] m_snap_ptw_twu_ref_req;
  protected logic [3:0] m_snap_ptw_twu_pgflt_vec;
  protected logic [3:0] m_snap_ptw_twu_acc_err_vec;
  protected logic       m_snap_ptw_fault_any;
  protected logic       m_snap_ptw_pgflt_vld;
  protected logic       m_snap_ptw_acc_err_vld;
  protected logic       m_snap_ptw_l2tlb_ref_pgflt;
  protected logic       m_snap_ptw_l2tlb_ref_acc_err;
  protected logic       m_snap_ptw_lsu_data_req;
  protected logic [8:0] m_snap_ptw_lsu_data_req_grant;
  protected logic       m_snap_ptw_arb_req;
  protected logic       m_snap_arb_ptw_grant;
  protected logic       m_snap_arb_l2tlb_req;
  protected logic       m_snap_ptw_l1d_ref_cmplt;

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
    m_pre_drop_drain_done = 1'b0;
    m_last_drain_timed_out = 1'b0;
    m_end_drain_attempts  = 0;
    m_end_drain_max_cycles    = 262144;
    m_end_drain_stable_cycles = 64;
    m_ptw_snap_valid     = 1'b0;
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
    void'($value$plusargs("CREDIT_SB_DRAIN_MAX_CYCLES=%0d", m_end_drain_max_cycles));
    void'($value$plusargs("CREDIT_SB_DRAIN_STABLE_CYCLES=%0d", m_end_drain_stable_cycles));
    if (m_end_drain_max_cycles == 0)
      m_end_drain_max_cycles = 1;
    if (m_end_drain_stable_cycles == 0)
      m_end_drain_stable_cycles = 1;
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

  // ── PTW request cancelled by reset before response: ptw_mbuf_cnt -1 ───────
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

  // ── End-of-test drain: allow late PTW/L2 completion / abort settle ────────
  // The PTW->LSU channel is single-outstanding externally, but a final L2TLB
  // miss can already be accepted into the PTW/TWU/mbuf pipeline while the
  // scoreboard counter is still zero or while the responder has not returned
  // data yet.  End-of-test must therefore wait for both the external credit
  // counter and the whitebox DUT pending state to be idle before report_phase.
  virtual function void phase_ready_to_end(uvm_phase phase);
    if (phase.get_name() != "run")
      return;

    if (m_end_drain_active)
      return;

    if (m_pre_drop_drain_done)
      return;

    if (m_end_drain_attempts >= 4)
      return;

    if (_needs_end_drain()) begin
      m_end_drain_active = 1'b1;
      m_end_drain_attempts++;
      phase.raise_objection(this,
        $sformatf("Settling PTW/L2 pending state before end: attempt=%0d %s",
          m_end_drain_attempts, _ptw_pending_snapshot()));
      fork
        begin
          _drain_ptw_before_end(phase);
        end
      join_none
    end
  endfunction

  // Called by test_base while its run_phase objection is still raised. This is
  // more reliable than relying only on phase_ready_to_end, because it always
  // requires a stable idle window before the test drops its final objection.
  virtual task drain_before_test_done();
    m_end_drain_active = 1'b1;
    _wait_for_ptw_end_idle("pre-drop");
    m_pre_drop_drain_done = 1'b1;
    m_end_drain_active = 1'b0;
  endtask

  virtual task wait_for_internal_idle(string ctx = "mid-test");
    _wait_for_ptw_end_idle(ctx);
  endtask

  virtual function bit last_drain_timed_out();
    return m_last_drain_timed_out;
  endfunction

  virtual function string pending_snapshot();
    if (v_probe != null)
      m_ptw_snap_valid = 1'b0;
    return _ptw_pending_snapshot();
  endfunction

  virtual function void print_timeout_debug(string ctx = "timeout");
    if (v_probe != null)
      m_ptw_snap_valid = 1'b0;
    $display({"[MMU_TIMEOUT_DBG] CreditSB ctx=%s ",
              "credit_l1i=%0d peak_l1i=%0d credit_l1d=%0d peak_l1d=%0d ",
              "lsu_ext=%0d peak_lsu_ext=%0d ptw_mbuf_cnt=%0d peak_ptw_mbuf=%0d ",
              "end_drain_active=%0b pre_drop_done=%0b attempts=%0d last_drain_timeout=%0b ",
              "%s"},
      ctx,
      m_credit_l1i,
      m_peak_l1i,
      m_credit_l1d,
      m_peak_l1d,
      m_lsu_ext_outstanding,
      m_peak_lsu_ext,
      m_ptw_mbuf_cnt,
      m_peak_ptw_mbuf,
      m_end_drain_active,
      m_pre_drop_drain_done,
      m_end_drain_attempts,
      m_last_drain_timed_out,
      _ptw_pending_snapshot());
    if (v_probe != null)
      $display({"[MMU_TIMEOUT_DBG] CreditSB_P13 ctx=%s ",
                "pmp_vld=0x%03h pmp_grant=0x%03h pmp_deny=0x%03h pmp_wait=0x%03h ",
                "pmp_mbuf_req=0x%03h pmp_fetch=0x%0h pfu_flg4=0x%0h pfu_deny=%0b pfu_acc_fault=%0b"},
        ctx,
        v_probe.p13_pmp_vld_vec,
        v_probe.p13_pmp_grant_vec,
        v_probe.p13_pmp_deny_vec,
        v_probe.p13_pmp_wait_vec,
        v_probe.p13_pmp_mbuf_req_vec,
        v_probe.p13_pmp_fetch_vec,
        v_probe.pfu_pmp_flg4,
        v_probe.pfu_l2tlb_deny,
        v_probe.pfu_l2tlb_acc_fault);
  endfunction

  protected task _drain_ptw_before_end(uvm_phase phase);
    _wait_for_ptw_end_idle("phase-ready");
    m_end_drain_active = 1'b0;
    phase.drop_objection(this, "PTW/L2 pending state stable (or timeout reached)");
  endtask

  protected task _wait_for_ptw_end_idle(string ctx);
    int unsigned wait_cycles;
    int unsigned stable_zero_cycles;

    wait_cycles        = 0;
    stable_zero_cycles = 0;
    m_last_drain_timed_out = 1'b0;
    m_ptw_snap_valid = 1'b0;

    while ((stable_zero_cycles < m_end_drain_stable_cycles) &&
           (wait_cycles < m_end_drain_max_cycles)) begin
      if (v_probe != null) begin
        @(v_probe.mon_cb);
        _sample_ptw_snapshot_after_clk();
      end else begin
        #1ns;
        m_ptw_snap_valid = 1'b0;
      end
      wait_cycles++;

      if (_ptw_end_idle())
        stable_zero_cycles++;
      else
        stable_zero_cycles = 0;
    end

    if (!_ptw_end_idle()) begin
      m_last_drain_timed_out = 1'b1;
      `uvm_warning(get_type_name(),
        $sformatf(
          "PTW/L2 end-drain timeout (%s) after %0d cycles: stable_zero_cycles=%0d/%0d %s",
          ctx, wait_cycles, stable_zero_cycles, m_end_drain_stable_cycles,
          _ptw_pending_snapshot()))
    end else begin
      `uvm_info(get_type_name(),
        $sformatf(
          "PTW/L2 end-drain stable (%s) after %0d cycles (stable_zero_cycles=%0d)",
          ctx, wait_cycles, stable_zero_cycles),
        UVM_MEDIUM)
    end
  endtask

  protected task _sample_ptw_snapshot_after_clk();
    if (v_probe == null) begin
      m_ptw_snap_valid = 1'b0;
      return;
    end

    // Sample after same-edge NBA/combinational settling.  The end-of-sim idle
    // check must match the waveform value after the DUT flops have updated,
    // not a raw whitebox value read in an earlier simulator region.
    #1ps;
    m_snap_rst_ni                 = v_probe.rst_ni;
    m_snap_l2_reqq_vld_vec        = v_probe.l2_reqq_vld_vec;
    m_snap_l2_reqq_rdy_vec        = v_probe.l2_reqq_rdy_vec;
    m_snap_l2_reqq_issue_valid    = v_probe.l2_reqq_issue_valid;
    m_snap_l2_reqq_issue_type     = v_probe.l2_reqq_issue_type;
    m_snap_l2mb_vld_vec           = v_probe.l2mb_vld_vec;
    m_snap_l2mb_rdy_vec           = v_probe.l2mb_rdy_vec;
    m_snap_l2mb_issue_req         = v_probe.l2mb_issue_req;
    m_snap_l2mb_issue_eid         = v_probe.l2mb_issue_eid;
    m_snap_l2mb_issue_type        = v_probe.l2mb_issue_type;
    m_snap_l2mb_alloc_valid       = v_probe.l2mb_alloc_valid;
    m_snap_l2mb_entry_vpn         = v_probe.l2mb_entry_vpn;
    m_snap_l2mb_entry_l1eid       = v_probe.l2mb_entry_l1eid;
    m_snap_l2mb_entry_type        = v_probe.l2mb_entry_type;
    m_snap_l2mb_entry_queue_id    = v_probe.l2mb_entry_queue_id;
    m_snap_l2mb_entry_sent        = v_probe.l2mb_entry_sent;
    m_snap_l1d_mb_vld             = v_probe.l1d_mb_vld;
    m_snap_l1d_mb_state           = v_probe.l1d_mb_state;
    m_snap_l1d_mb_vpn             = v_probe.l1d_mb_vpn;
    m_snap_l1d_mb_iid             = v_probe.l1d_mb_iid;
    m_snap_l1d_mb_issued          = v_probe.l1d_mb_issued;
    m_snap_l1d_mb_ready           = v_probe.l1d_mb_ready;
    m_snap_l1d_mb_wfc             = v_probe.l1d_mb_wfc;
    m_snap_l1d_mb_wfi             = v_probe.l1d_mb_wfi;
    m_snap_l1d_mb_store           = v_probe.l1d_mb_store;
    m_snap_l2_final_vld           = v_probe.l2_final_vld;
    m_snap_l2_miss                = v_probe.l2_miss;
    m_snap_l2_dtlb_ref_pavld      = v_probe.l2_dtlb_ref_pavld;
    m_snap_l2_dtlb_ref_cmplt      = v_probe.l2_dtlb_ref_cmplt;
    m_snap_l2tlb_ptw_req          = v_probe.l2tlb_ptw_req;
    m_snap_l2tlb_ptw_id           = v_probe.l2tlb_ptw_id;
    m_snap_l2tlb_ptw_type         = v_probe.l2tlb_ptw_type;
    m_snap_ptw_l2tlb_cmplt        = v_probe.ptw_l2tlb_cmplt;
    m_snap_ptw_l2tlb_id           = v_probe.ptw_l2tlb_id;
    m_snap_ptw_l2tlb_type         = v_probe.ptw_l2tlb_type;
    m_snap_ptw_l1i_ref_cmplt      = v_probe.ptw_l1i_ref_cmplt;
    m_snap_ptw_mbuf_entry_vld     = v_probe.ptw_mbuf_entry_vld;
    m_snap_ptw_mbuf_twu_have      = v_probe.ptw_mbuf_twu_have;
    m_snap_ptw_twu_idle           = v_probe.ptw_twu_idle;
    m_snap_ptw_twu_mask           = v_probe.ptw_twu_mask;
    m_snap_ptw_twu_ref_req        = v_probe.ptw_twu_ref_req;
    m_snap_ptw_twu_pgflt_vec      = v_probe.ptw_twu_pgflt_vec;
    m_snap_ptw_twu_acc_err_vec    = v_probe.ptw_twu_acc_err_vec;
    m_snap_ptw_fault_any          = v_probe.ptw_fault_any;
    m_snap_ptw_pgflt_vld          = v_probe.ptw_pgflt_vld;
    m_snap_ptw_acc_err_vld        = v_probe.ptw_acc_err_vld;
    m_snap_ptw_l2tlb_ref_pgflt    = v_probe.ptw_l2tlb_ref_pgflt;
    m_snap_ptw_l2tlb_ref_acc_err  = v_probe.ptw_l2tlb_ref_acc_err;
    m_snap_ptw_lsu_data_req       = v_probe.ptw_lsu_data_req;
    m_snap_ptw_lsu_data_req_grant = v_probe.ptw_lsu_data_req_grant;
    m_snap_ptw_arb_req            = v_probe.ptw_arb_req;
    m_snap_arb_ptw_grant          = v_probe.arb_ptw_grant;
    m_snap_arb_l2tlb_req          = v_probe.arb_l2tlb_req;
    m_snap_ptw_l1d_ref_cmplt      = v_probe.ptw_l1d_ref_cmplt;
    m_ptw_snap_valid              = 1'b1;
  endtask

  protected function bit _needs_end_drain();
    if (m_ptw_mbuf_cnt != 0)
      return 1'b1;
    return _ptw_drain_pending_raw();
  endfunction

  protected function bit _ptw_end_idle();
    if (m_ptw_mbuf_cnt != 0)
      return 1'b0;
    return !_ptw_drain_pending();
  endfunction

  protected function bit _ptw_drain_pending();
    if (m_ptw_snap_valid) begin
      if (m_snap_rst_ni !== 1'b1)
        return 1'b0;

      return (m_snap_l2_reqq_vld_vec        !== 9'b0)
          || (m_snap_l1d_mb_vld             !== 8'b0)
          || (m_snap_l2mb_vld_vec           !== 9'b0)
          || (m_snap_l2_final_vld           === 1'b1)
          || (m_snap_l2_miss                === 1'b1)
          || (m_snap_l2_dtlb_ref_pavld      === 1'b1)
          || (m_snap_l2_dtlb_ref_cmplt      === 1'b1)
          || (m_snap_l2tlb_ptw_req          === 1'b1)
          || (m_snap_ptw_mbuf_entry_vld     !== 9'b0)
          || (m_snap_ptw_mbuf_twu_have      !== 4'b0)
          || (m_snap_ptw_twu_idle           !== 4'hf)
          || (m_snap_ptw_twu_mask           !== 4'b0)
          || (m_snap_ptw_twu_ref_req        !== 4'b0)
          || (m_snap_ptw_twu_pgflt_vec      !== 4'b0)
          || (m_snap_ptw_twu_acc_err_vec    !== 4'b0)
          || (m_snap_ptw_fault_any          === 1'b1)
          || (m_snap_ptw_pgflt_vld          === 1'b1)
          || (m_snap_ptw_acc_err_vld        === 1'b1)
          || (m_snap_ptw_l2tlb_ref_pgflt    === 1'b1)
          || (m_snap_ptw_l2tlb_ref_acc_err  === 1'b1)
          || (m_snap_ptw_lsu_data_req       === 1'b1)
          || (m_snap_ptw_lsu_data_req_grant !== 9'b0)
          || (m_snap_ptw_arb_req            === 1'b1)
          || (m_snap_arb_ptw_grant          === 1'b1)
          || (m_snap_arb_l2tlb_req          === 1'b1)
          || (m_snap_ptw_l1d_ref_cmplt      === 1'b1);
    end

    return _ptw_drain_pending_raw();
  endfunction

  protected function bit _ptw_drain_pending_raw();
    if (v_probe == null)
      return 1'b0;
    if (v_probe.rst_ni !== 1'b1)
      return 1'b0;

    return (v_probe.l2_reqq_vld_vec     !== 9'b0)
        || (v_probe.l1d_mb_vld          !== 8'b0)
        || (v_probe.l2mb_vld_vec        !== 9'b0)
        || (v_probe.l2_final_vld        === 1'b1)
        || (v_probe.l2_miss             === 1'b1)
        || (v_probe.l2_dtlb_ref_pavld   === 1'b1)
        || (v_probe.l2_dtlb_ref_cmplt   === 1'b1)
        || (v_probe.l2tlb_ptw_req       === 1'b1)
        || (v_probe.ptw_mbuf_entry_vld  !== 9'b0)
        || (v_probe.ptw_mbuf_twu_have   !== 4'b0)
        || (v_probe.ptw_twu_idle        !== 4'hf)
        || (v_probe.ptw_twu_mask        !== 4'b0)
        || (v_probe.ptw_twu_ref_req     !== 4'b0)
        || (v_probe.ptw_twu_pgflt_vec   !== 4'b0)
        || (v_probe.ptw_twu_acc_err_vec !== 4'b0)
        || (v_probe.ptw_fault_any       === 1'b1)
        || (v_probe.ptw_pgflt_vld       === 1'b1)
        || (v_probe.ptw_acc_err_vld     === 1'b1)
        || (v_probe.ptw_l2tlb_ref_pgflt === 1'b1)
        || (v_probe.ptw_l2tlb_ref_acc_err === 1'b1)
        || (v_probe.ptw_lsu_data_req    === 1'b1)
        || (v_probe.ptw_lsu_data_req_grant !== 9'b0)
        || (v_probe.ptw_arb_req         === 1'b1)
        || (v_probe.arb_ptw_grant       === 1'b1)
        || (v_probe.arb_l2tlb_req       === 1'b1)
        || (v_probe.ptw_l1d_ref_cmplt   === 1'b1);
  endfunction

  protected function bit _ptw_hw_pending();
    return _ptw_drain_pending();
  endfunction

  protected function string _l1d_mb_detail_snapshot();
    string s;
    s = "";
    for (int i = 0; i < 8; i++) begin
      if (m_snap_l1d_mb_vld[i]) begin
        s = {s, $sformatf(
          " e%0d{state=%0d ready=%0b sent=%0b wfc=%0b wfi=%0b store=%0b iid=0x%02h vpn=0x%07h}",
          i,
          m_snap_l1d_mb_state[i],
          m_snap_l1d_mb_ready[i],
          m_snap_l1d_mb_issued[i],
          m_snap_l1d_mb_wfc[i],
          m_snap_l1d_mb_wfi[i],
          m_snap_l1d_mb_store[i],
          m_snap_l1d_mb_iid[i],
          m_snap_l1d_mb_vpn[i])};
      end
    end
    if (s == "")
      s = " none";
    return {"l1d_detail={", s, " }"};
  endfunction

  protected function string _l1d_mb_detail_raw();
    string s;
    if (v_probe == null)
      return "l1d_detail={ v_probe=null }";
    s = "";
    for (int i = 0; i < 8; i++) begin
      if (v_probe.l1d_mb_vld[i]) begin
        s = {s, $sformatf(
          " e%0d{state=%0d ready=%0b sent=%0b wfc=%0b wfi=%0b store=%0b iid=0x%02h vpn=0x%07h}",
          i,
          v_probe.l1d_mb_state[i],
          v_probe.l1d_mb_ready[i],
          v_probe.l1d_mb_issued[i],
          v_probe.l1d_mb_wfc[i],
          v_probe.l1d_mb_wfi[i],
          v_probe.l1d_mb_store[i],
          v_probe.l1d_mb_iid[i],
          v_probe.l1d_mb_vpn[i])};
      end
    end
    if (s == "")
      s = " none";
    return {"l1d_detail={", s, " }"};
  endfunction

  protected function string _l2mb_detail_snapshot();
    string s;
    string state;
    s = "";
    for (int i = 0; i < 9; i++) begin
      if (m_snap_l2mb_vld_vec[i]) begin
        state = m_snap_l2mb_entry_sent[i] ? "SENT" :
                m_snap_l2mb_rdy_vec[i]   ? "READY" : "HELD";
        s = {s, $sformatf(
          " e%0d{state=%s ready=%0b sent=%0b type=0x%0h l1eid=0x%0h qid=0x%0h vpn=0x%07h}",
          i,
          state,
          m_snap_l2mb_rdy_vec[i],
          m_snap_l2mb_entry_sent[i],
          m_snap_l2mb_entry_type[i],
          m_snap_l2mb_entry_l1eid[i],
          m_snap_l2mb_entry_queue_id[i],
          m_snap_l2mb_entry_vpn[i])};
      end
    end
    if (s == "")
      s = " none";
    return {"l2mb_detail={", s, " }"};
  endfunction

  protected function string _l2mb_detail_raw();
    string s;
    string state;
    if (v_probe == null)
      return "l2mb_detail={ v_probe=null }";
    s = "";
    for (int i = 0; i < 9; i++) begin
      if (v_probe.l2mb_vld_vec[i]) begin
        state = v_probe.l2mb_entry_sent[i] ? "SENT" :
                v_probe.l2mb_rdy_vec[i]   ? "READY" : "HELD";
        s = {s, $sformatf(
          " e%0d{state=%s ready=%0b sent=%0b type=0x%0h l1eid=0x%0h qid=0x%0h vpn=0x%07h}",
          i,
          state,
          v_probe.l2mb_rdy_vec[i],
          v_probe.l2mb_entry_sent[i],
          v_probe.l2mb_entry_type[i],
          v_probe.l2mb_entry_l1eid[i],
          v_probe.l2mb_entry_queue_id[i],
          v_probe.l2mb_entry_vpn[i])};
      end
    end
    if (s == "")
      s = " none";
    return {"l2mb_detail={", s, " }"};
  endfunction

  protected function string _ptw_pending_snapshot();
    if (m_ptw_snap_valid) begin
      return $sformatf(
        "ptw_mbuf_cnt=%0d l1d_mb=0x%02h l2_reqq=0x%03h l2_reqq_rdy=0x%03h l2_reqq_issue=%0b/type=0x%0h l2mb=0x%03h l2mb_rdy=0x%03h l2mb_issue=%0b/eid=0x%02h/type=0x%0h l2mb_alloc=%0b l2_final=%0b l2_miss=%0b l2_ptw_req=%0b/id=0x%02h/type=0x%0h ptw_cmplt=%0b/id=0x%02h/type=0x%0h ptw_l1i_cmplt=%0b ptw_lsu_req=%0b ptw_lsu_grant=0x%03h ptw_mbuf=0x%03h twu_idle=0x%0h twu_mask=0x%0h twu_ref=0x%0h ptw_arb_req=%0b arb_ptw_grant=%0b arb_l2tlb_req=%0b %s %s sample=settled",
        m_ptw_mbuf_cnt,
        m_snap_l1d_mb_vld,
        m_snap_l2_reqq_vld_vec,
        m_snap_l2_reqq_rdy_vec,
        m_snap_l2_reqq_issue_valid,
        m_snap_l2_reqq_issue_type,
        m_snap_l2mb_vld_vec,
        m_snap_l2mb_rdy_vec,
        m_snap_l2mb_issue_req,
        m_snap_l2mb_issue_eid,
        m_snap_l2mb_issue_type,
        m_snap_l2mb_alloc_valid,
        m_snap_l2_final_vld,
        m_snap_l2_miss,
        m_snap_l2tlb_ptw_req,
        m_snap_l2tlb_ptw_id,
        m_snap_l2tlb_ptw_type,
        m_snap_ptw_l2tlb_cmplt,
        m_snap_ptw_l2tlb_id,
        m_snap_ptw_l2tlb_type,
        m_snap_ptw_l1i_ref_cmplt,
        m_snap_ptw_lsu_data_req,
        m_snap_ptw_lsu_data_req_grant,
        m_snap_ptw_mbuf_entry_vld,
        m_snap_ptw_twu_idle,
        m_snap_ptw_twu_mask,
        m_snap_ptw_twu_ref_req,
        m_snap_ptw_arb_req,
        m_snap_arb_ptw_grant,
        m_snap_arb_l2tlb_req,
        _l1d_mb_detail_snapshot(),
        _l2mb_detail_snapshot());
    end

    if (v_probe == null)
      return $sformatf("ptw_mbuf_cnt=%0d v_probe=null", m_ptw_mbuf_cnt);
    return $sformatf(
      "ptw_mbuf_cnt=%0d l1d_mb=0x%02h l2_reqq=0x%03h l2_reqq_rdy=0x%03h l2_reqq_issue=%0b/type=0x%0h l2mb=0x%03h l2mb_rdy=0x%03h l2mb_issue=%0b/eid=0x%02h/type=0x%0h l2mb_alloc=%0b l2_final=%0b l2_miss=%0b l2_ptw_req=%0b/id=0x%02h/type=0x%0h ptw_cmplt=%0b/id=0x%02h/type=0x%0h ptw_l1i_cmplt=%0b ptw_lsu_req=%0b ptw_lsu_grant=0x%03h ptw_mbuf=0x%03h twu_idle=0x%0h twu_mask=0x%0h twu_ref=0x%0h ptw_arb_req=%0b arb_ptw_grant=%0b arb_l2tlb_req=%0b %s %s sample=raw",
      m_ptw_mbuf_cnt,
      v_probe.l1d_mb_vld,
      v_probe.l2_reqq_vld_vec,
      v_probe.l2_reqq_rdy_vec,
      v_probe.l2_reqq_issue_valid,
      v_probe.l2_reqq_issue_type,
      v_probe.l2mb_vld_vec,
      v_probe.l2mb_rdy_vec,
      v_probe.l2mb_issue_req,
      v_probe.l2mb_issue_eid,
      v_probe.l2mb_issue_type,
      v_probe.l2mb_alloc_valid,
      v_probe.l2_final_vld,
      v_probe.l2_miss,
      v_probe.l2tlb_ptw_req,
      v_probe.l2tlb_ptw_id,
      v_probe.l2tlb_ptw_type,
      v_probe.ptw_l2tlb_cmplt,
      v_probe.ptw_l2tlb_id,
      v_probe.ptw_l2tlb_type,
      v_probe.ptw_l1i_ref_cmplt,
      v_probe.ptw_lsu_data_req,
      v_probe.ptw_lsu_data_req_grant,
      v_probe.ptw_mbuf_entry_vld,
      v_probe.ptw_twu_idle,
      v_probe.ptw_twu_mask,
      v_probe.ptw_twu_ref_req,
      v_probe.ptw_arb_req,
      v_probe.arb_ptw_grant,
      v_probe.arb_l2tlb_req,
      _l1d_mb_detail_raw(),
      _l2mb_detail_raw());
  endfunction

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
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] credit_l1d != 0 at end-of-sim (%0d): LSU requests did not fully complete",
          m_credit_l1d))

    // With the LSU driver retrying until real pa*_vld, a non-zero external
    // count at report_phase means the final stimulus/request drain failed.
    if (m_lsu_ext_outstanding != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] lsu_ext_outstanding != 0 at end-of-sim (%0d): LSU external requests did not fully complete",
          m_lsu_ext_outstanding))

    if (m_ptw_mbuf_cnt != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] ptw_mbuf_cnt != 0 at end-of-sim (%0d): PTW serialized external request not drained",
          m_ptw_mbuf_cnt))

    if (_ptw_hw_pending())
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] PTW/L2 internal state not idle at end-of-sim: %s",
          _ptw_pending_snapshot()))

    if (m_credit_l1i == 0 && m_credit_l1d == 0 && m_lsu_ext_outstanding == 0 && m_ptw_mbuf_cnt == 0 && !_ptw_hw_pending())
      `uvm_info(get_type_name(),
        "[CreditSB] PASS — credit conservation verified (l1i/l1d/lsu_ext/ptw all == 0 and PTW/L2 idle)",
        UVM_MEDIUM)
  endfunction

endclass : mmu_credit_sb

`endif // MMU_CREDIT_SB_SVH
