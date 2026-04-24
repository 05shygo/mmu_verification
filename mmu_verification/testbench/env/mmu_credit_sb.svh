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
//   m_credit_l1d   — outstanding LSU translation requests
//     lsu p0/p1 ap_req → +1
//     lsu p0/p1 ap_rsp → -1
//     Upper bound  : L1_DTLB_ENTRIES (16)
//
//   m_l2_reqq_cnt  — L2 TLB request queue occupancy
//     lsu p0/p1 ap_req → +1 (enters request queue)
//     lsu p0/p1 ap_rsp → -1 (leaves request queue on hit/miss completion)
//     Upper bound  : L2_REQQ_DEPTH (9)
//
//   m_ptw_mbuf_cnt — PTW miss buffer occupancy
//     ptw_mem ap_req → +1 (new PTW memory read issued)
//     ptw_mem ap_rsp → -1 (PTW memory read completed)
//     Upper bound  : PTW_MBUF_DEPTH (4)
//
// All counters must equal 0 at report_phase (no "leaked" transactions).
//
// Eight TLM analysis FIFOs (one per AP stream):
//   af_ifu_req, af_ifu_rsp,
//   af_lsu_p0_req, af_lsu_p0_rsp, af_lsu_p1_req, af_lsu_p1_rsp,
//   af_ptw_req, af_ptw_rsp
//
// Connected in mmu_env::connect_phase (fan-out from monitors).
// =============================================================================
`ifndef MMU_CREDIT_SB_SVH
`define MMU_CREDIT_SB_SVH

class mmu_credit_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_credit_sb)

  // ── TLM Analysis FIFOs (8 streams) ────────────────────────────────────────
  // IFU
  uvm_tlm_analysis_fifo #(ifu_txn)      af_ifu_req;
  uvm_tlm_analysis_fifo #(ifu_txn)      af_ifu_rsp;
  // LSU pipe 0
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p0_req;
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p0_rsp;
  // LSU pipe 1
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p1_req;
  uvm_tlm_analysis_fifo #(lsu_txn)      af_lsu_p1_rsp;
  // PTW memory channel
  uvm_tlm_analysis_fifo #(ptw_mem_txn)  af_ptw_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)  af_ptw_rsp;

  // ── Credit / occupancy counters (all start at 0) ──────────────────────────
  // Protected; updated only from run_phase consumer threads.
  protected int m_credit_l1i;    // outstanding IFU translation requests
  protected int m_credit_l1d;    // outstanding LSU translation requests
  protected int m_l2_reqq_cnt;   // L2 TLB request queue occupancy
  protected int m_ptw_mbuf_cnt;  // PTW miss buffer occupancy

  // ── Peak observations (for debug) ─────────────────────────────────────────
  protected int m_peak_l1i;
  protected int m_peak_l1d;
  protected int m_peak_l2_reqq;
  protected int m_peak_ptw_mbuf;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_credit_l1i   = 0;
    m_credit_l1d   = 0;
    m_l2_reqq_cnt  = 0;
    m_ptw_mbuf_cnt = 0;
    m_peak_l1i     = 0;
    m_peak_l1d     = 0;
    m_peak_l2_reqq = 0;
    m_peak_ptw_mbuf= 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_ifu_req    = new("af_ifu_req",    this);
    af_ifu_rsp    = new("af_ifu_rsp",    this);
    af_lsu_p0_req = new("af_lsu_p0_req", this);
    af_lsu_p0_rsp = new("af_lsu_p0_rsp", this);
    af_lsu_p1_req = new("af_lsu_p1_req", this);
    af_lsu_p1_rsp = new("af_lsu_p1_rsp", this);
    af_ptw_req    = new("af_ptw_req",    this);
    af_ptw_rsp    = new("af_ptw_rsp",    this);
  endfunction

  // ── run_phase: fork 8 consumer threads ────────────────────────────────────
  virtual task run_phase(uvm_phase phase);
    fork
      _consume_ifu_req();
      _consume_ifu_rsp();
      _consume_lsu_p0_req();
      _consume_lsu_p0_rsp();
      _consume_lsu_p1_req();
      _consume_lsu_p1_rsp();
      _consume_ptw_req();
      _consume_ptw_rsp();
    join_none
  endtask

  // ── IFU request: credit_l1i +1 ───────────────────────────────────────────
  protected task _consume_ifu_req();
    ifu_txn tr;
    forever begin
      af_ifu_req.get(tr);
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
      m_credit_l1i--;
      if (m_credit_l1i < 0)
        `uvm_error(get_type_name(),
          $sformatf("credit_l1i underflow: %0d (spurious IFU response?)",
            m_credit_l1i))
      `uvm_info(get_type_name(),
        $sformatf("IFU_RSP: credit_l1i=%0d", m_credit_l1i), UVM_HIGH)
    end
  endtask

  // ── LSU pipe0 request: credit_l1d +1, l2_reqq +1 ────────────────────────
  protected task _consume_lsu_p0_req();
    lsu_txn tr;
    forever begin
      af_lsu_p0_req.get(tr);
      m_credit_l1d++;
      m_l2_reqq_cnt++;
      _check_l1d_bound();
      _check_l2_reqq_bound();
      if (m_credit_l1d  > m_peak_l1d)    m_peak_l1d    = m_credit_l1d;
      if (m_l2_reqq_cnt > m_peak_l2_reqq) m_peak_l2_reqq = m_l2_reqq_cnt;
      `uvm_info(get_type_name(),
        $sformatf("LSU_P0_REQ: credit_l1d=%0d l2_reqq=%0d",
          m_credit_l1d, m_l2_reqq_cnt), UVM_HIGH)
    end
  endtask

  // ── LSU pipe0 response: credit_l1d -1, l2_reqq -1 ────────────────────────
  protected task _consume_lsu_p0_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p0_rsp.get(tr);
      m_credit_l1d--;
      m_l2_reqq_cnt--;
      _check_l1d_underflow();
      _check_l2_reqq_underflow();
      `uvm_info(get_type_name(),
        $sformatf("LSU_P0_RSP: credit_l1d=%0d l2_reqq=%0d",
          m_credit_l1d, m_l2_reqq_cnt), UVM_HIGH)
    end
  endtask

  // ── LSU pipe1 request: credit_l1d +1, l2_reqq +1 ────────────────────────
  protected task _consume_lsu_p1_req();
    lsu_txn tr;
    forever begin
      af_lsu_p1_req.get(tr);
      m_credit_l1d++;
      m_l2_reqq_cnt++;
      _check_l1d_bound();
      _check_l2_reqq_bound();
      if (m_credit_l1d  > m_peak_l1d)    m_peak_l1d    = m_credit_l1d;
      if (m_l2_reqq_cnt > m_peak_l2_reqq) m_peak_l2_reqq = m_l2_reqq_cnt;
      `uvm_info(get_type_name(),
        $sformatf("LSU_P1_REQ: credit_l1d=%0d l2_reqq=%0d",
          m_credit_l1d, m_l2_reqq_cnt), UVM_HIGH)
    end
  endtask

  // ── LSU pipe1 response: credit_l1d -1, l2_reqq -1 ────────────────────────
  protected task _consume_lsu_p1_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p1_rsp.get(tr);
      m_credit_l1d--;
      m_l2_reqq_cnt--;
      _check_l1d_underflow();
      _check_l2_reqq_underflow();
      `uvm_info(get_type_name(),
        $sformatf("LSU_P1_RSP: credit_l1d=%0d l2_reqq=%0d",
          m_credit_l1d, m_l2_reqq_cnt), UVM_HIGH)
    end
  endtask

  // ── PTW request: ptw_mbuf_cnt +1 ─────────────────────────────────────────
  protected task _consume_ptw_req();
    ptw_mem_txn tr;
    forever begin
      af_ptw_req.get(tr);
      m_ptw_mbuf_cnt++;
      if (m_ptw_mbuf_cnt > int'(PTW_MBUF_DEPTH))
        `uvm_error(get_type_name(),
          $sformatf("ptw_mbuf_cnt overflow: %0d > PTW_MBUF_DEPTH=%0d",
            m_ptw_mbuf_cnt, PTW_MBUF_DEPTH))
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

  // ── Inline bound checks ───────────────────────────────────────────────────
  protected function void _check_l1d_bound();
    if (m_credit_l1d > int'(L1_DTLB_ENTRIES))
      `uvm_error(get_type_name(),
        $sformatf("credit_l1d overflow: %0d > L1_DTLB_ENTRIES=%0d",
          m_credit_l1d, L1_DTLB_ENTRIES))
  endfunction

  protected function void _check_l2_reqq_bound();
    if (m_l2_reqq_cnt > int'(L2_REQQ_DEPTH))
      `uvm_error(get_type_name(),
        $sformatf("l2_reqq_cnt overflow: %0d > L2_REQQ_DEPTH=%0d",
          m_l2_reqq_cnt, L2_REQQ_DEPTH))
  endfunction

  protected function void _check_l1d_underflow();
    if (m_credit_l1d < 0)
      `uvm_error(get_type_name(),
        $sformatf("credit_l1d underflow: %0d (spurious LSU response?)",
          m_credit_l1d))
  endfunction

  protected function void _check_l2_reqq_underflow();
    if (m_l2_reqq_cnt < 0)
      `uvm_error(get_type_name(),
        $sformatf("l2_reqq_cnt underflow: %0d (spurious LSU response?)",
          m_l2_reqq_cnt))
  endfunction

  // ── report_phase: assert all counters == 0 ────────────────────────────────
  // A non-zero counter at end-of-sim means a transaction was "leaked"
  // (request without matching response, or response without request).
  virtual function void report_phase(uvm_phase phase);
    // Summary banner
    `uvm_info(get_type_name(),
      $sformatf({"[CreditSB] Summary:\n",
        "  credit_l1i   = %0d  (peak=%0d, limit=%0d)\n",
        "  credit_l1d   = %0d  (peak=%0d, limit=%0d)\n",
        "  l2_reqq_cnt  = %0d  (peak=%0d, limit=%0d)\n",
        "  ptw_mbuf_cnt = %0d  (peak=%0d, limit=%0d)"},
        m_credit_l1i,   m_peak_l1i,      L1_ITLB_ENTRIES,
        m_credit_l1d,   m_peak_l1d,      L1_DTLB_ENTRIES,
        m_l2_reqq_cnt,  m_peak_l2_reqq,  L2_REQQ_DEPTH,
        m_ptw_mbuf_cnt, m_peak_ptw_mbuf, PTW_MBUF_DEPTH),
      UVM_MEDIUM)

    // Conservation checks
    if (m_credit_l1i != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] credit_l1i != 0 at end-of-sim (%0d): leaked IFU txns",
          m_credit_l1i))

    if (m_credit_l1d != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] credit_l1d != 0 at end-of-sim (%0d): leaked LSU txns",
          m_credit_l1d))

    if (m_l2_reqq_cnt != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] l2_reqq_cnt != 0 at end-of-sim (%0d): L2 reqQ not drained",
          m_l2_reqq_cnt))

    if (m_ptw_mbuf_cnt != 0)
      `uvm_error(get_type_name(),
        $sformatf("[CreditSB] ptw_mbuf_cnt != 0 at end-of-sim (%0d): PTW mbuf not drained",
          m_ptw_mbuf_cnt))

    if (m_credit_l1i   == 0 && m_credit_l1d  == 0 &&
        m_l2_reqq_cnt  == 0 && m_ptw_mbuf_cnt == 0)
      `uvm_info(get_type_name(),
        "[CreditSB] PASS — all credit counters == 0 (conservation verified)",
        UVM_MEDIUM)
  endfunction

endclass : mmu_credit_sb

`endif // MMU_CREDIT_SB_SVH
