// =============================================================================
// MMU UVM Verification — testbench/env/mmu_perf_mon.svh
// Phase 5 (Engineer A): MMU Performance Monitor (skeleton)
//
// Collects translation and miss statistics from IFU/LSU/HPCP streams.
// Phase 5 goal: establish the FIFO connections and declare counters.
// Actual statistics computation is expanded in Phase 7 / Phase 10.
//
// TLM FIFO connections (made in mmu_env::connect_phase):
//   af_ifu_rsp    ← m_ifu.m_monitor.ap_rsp         (IFU translation response)
//   af_lsu_p0_rsp ← m_lsu.m_monitor.ap_pipe0_rsp   (LSU pipe0 response)
//   af_lsu_p1_rsp ← m_lsu.m_monitor.ap_pipe1_rsp   (LSU pipe1 response)
//   af_lsu_p2_rsp ← m_lsu.m_monitor.ap_pipe2_rsp   (LSU prefetch response)
//   af_hpcp       ← m_misc.m_monitor.ap_hpcp        (HPCP miss events)
//
// report_phase: prints simple summary table.
// =============================================================================
`ifndef MMU_PERF_MON_SVH
`define MMU_PERF_MON_SVH

class mmu_perf_mon extends uvm_component;

  `uvm_component_utils(mmu_perf_mon)

  // ── TLM Analysis FIFOs ────────────────────────────────────────────────────
  uvm_tlm_analysis_fifo #(ifu_txn)     af_ifu_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn)     af_lsu_p0_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn)     af_lsu_p1_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn)     af_lsu_p2_rsp;
  uvm_tlm_analysis_fifo #(misc_txn)    af_hpcp;

  // ── Statistics counters ───────────────────────────────────────────────────
  // IFU
  int unsigned n_ifu_req;       // total IFU translation requests observed
  int unsigned n_ifu_miss;      // IFU requests that caused TLB miss (TODO Ph7)

  // LSU (per-pipe)
  int unsigned n_lsu_req[3];    // [0]=pipe0 [1]=pipe1 [2]=pipe2
  int unsigned n_lsu_miss[3];   // miss count per pipe (TODO Ph7)

  // PTW / walk latency (TODO Phase 7)
  longint unsigned walk_latency_sum;  // sum of PTW walk latency in cycles

  // HPCP hardware counters
  int unsigned n_hpcp_dutlb_miss;  // DUTLB miss events from HPCP signals
  int unsigned n_hpcp_iutlb_miss;  // IUTLB miss events
  int unsigned n_hpcp_jtlb_miss;   // JTLB (L2 TLB) miss events

  function new(string name, uvm_component parent);
    super.new(name, parent);
    // Initialise all counters to 0
    n_ifu_req         = 0;
    n_ifu_miss        = 0;
    foreach (n_lsu_req[i])  n_lsu_req[i]  = 0;
    foreach (n_lsu_miss[i]) n_lsu_miss[i] = 0;
    walk_latency_sum  = 0;
    n_hpcp_dutlb_miss = 0;
    n_hpcp_iutlb_miss = 0;
    n_hpcp_jtlb_miss  = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_ifu_rsp    = new("af_ifu_rsp",    this);
    af_lsu_p0_rsp = new("af_lsu_p0_rsp", this);
    af_lsu_p1_rsp = new("af_lsu_p1_rsp", this);
    af_lsu_p2_rsp = new("af_lsu_p2_rsp", this);
    af_hpcp       = new("af_hpcp",       this);
  endfunction

  // ── run_phase: fork 5 consumer threads ────────────────────────────────────
  virtual task run_phase(uvm_phase phase);
    fork
      _consume_ifu_rsp();
      _consume_lsu_p0_rsp();
      _consume_lsu_p1_rsp();
      _consume_lsu_p2_rsp();
      _consume_hpcp();
    join_none
  endtask

  // ── IFU response consumer ─────────────────────────────────────────────────
  protected task _consume_ifu_rsp();
    ifu_txn tr;
    forever begin
      af_ifu_rsp.get(tr);
      n_ifu_req++;
      // TODO Phase 7: detect TLB miss from stall/latency and increment n_ifu_miss
      `uvm_info(get_type_name(),
        $sformatf("[PerfMon] IFU rsp #%0d: pa=0x%07h pgflt=%0b deny=%0b",
          n_ifu_req, tr.pa, tr.pgflt, tr.deny),
        UVM_HIGH)
    end
  endtask

  // ── LSU pipe0 response consumer ───────────────────────────────────────────
  protected task _consume_lsu_p0_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p0_rsp.get(tr);
      n_lsu_req[0]++;
      // TODO Phase 7: detect miss (stall=1) and increment n_lsu_miss[0]
      `uvm_info(get_type_name(),
        $sformatf("[PerfMon] LSU_P0 rsp #%0d: pa=0x%07h pgflt=%0b stall=%0b",
          n_lsu_req[0], tr.pa, tr.pgflt, tr.stall),
        UVM_HIGH)
    end
  endtask

  // ── LSU pipe1 response consumer ───────────────────────────────────────────
  protected task _consume_lsu_p1_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p1_rsp.get(tr);
      n_lsu_req[1]++;
      // TODO Phase 7: detect miss and increment n_lsu_miss[1]
      `uvm_info(get_type_name(),
        $sformatf("[PerfMon] LSU_P1 rsp #%0d: pa=0x%07h pgflt=%0b stall=%0b",
          n_lsu_req[1], tr.pa, tr.pgflt, tr.stall),
        UVM_HIGH)
    end
  endtask

  // ── LSU pipe2 (prefetch) response consumer ────────────────────────────────
  protected task _consume_lsu_p2_rsp();
    lsu_txn tr;
    forever begin
      af_lsu_p2_rsp.get(tr);
      n_lsu_req[2]++;
      `uvm_info(get_type_name(),
        $sformatf("[PerfMon] LSU_P2 rsp #%0d: va2=0x%07h",
          n_lsu_req[2], tr.va2),
        UVM_HIGH)
    end
  endtask

  // ── HPCP miss event consumer ──────────────────────────────────────────────
  // Increments hardware miss counters mirroring DUT hpcp signals.
  protected task _consume_hpcp();
    misc_txn tr;
    forever begin
      af_hpcp.get(tr);
      if (tr.dutlb_miss) n_hpcp_dutlb_miss++;
      if (tr.iutlb_miss) n_hpcp_iutlb_miss++;
      if (tr.jtlb_miss)  n_hpcp_jtlb_miss++;
      `uvm_info(get_type_name(),
        $sformatf("[PerfMon] HPCP miss: dutlb=%0b iutlb=%0b jtlb=%0b (totals: du=%0d iu=%0d jt=%0d)",
          tr.dutlb_miss, tr.iutlb_miss, tr.jtlb_miss,
          n_hpcp_dutlb_miss, n_hpcp_iutlb_miss, n_hpcp_jtlb_miss),
        UVM_HIGH)
    end
  endtask

  // ── report_phase: print performance summary ───────────────────────────────
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf({"[PerfMon] Performance Summary:\n",
        "  IFU:  req=%0d  miss=%0d (TODO)\n",
        "  LSU0: req=%0d  miss=%0d (TODO)\n",
        "  LSU1: req=%0d  miss=%0d (TODO)\n",
        "  LSU2: req=%0d  (prefetch)\n",
        "  PTW:  walk_latency_sum=%0d (TODO)\n",
        "  HPCP: dutlb_miss=%0d  iutlb_miss=%0d  jtlb_miss=%0d"},
        n_ifu_req,  n_ifu_miss,
        n_lsu_req[0], n_lsu_miss[0],
        n_lsu_req[1], n_lsu_miss[1],
        n_lsu_req[2],
        walk_latency_sum,
        n_hpcp_dutlb_miss, n_hpcp_iutlb_miss, n_hpcp_jtlb_miss),
      UVM_MEDIUM)
  endfunction

endclass : mmu_perf_mon

`endif // MMU_PERF_MON_SVH
