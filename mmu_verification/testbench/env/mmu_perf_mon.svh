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
  uvm_tlm_analysis_fifo #(ptw_mem_txn) af_ptw_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn) af_ptw_rsp;

  // ── Statistics counters ───────────────────────────────────────────────────
  // IFU
  int unsigned n_ifu_req;       // total IFU translation requests observed
  int unsigned n_ifu_miss;      // IFU: responses with IUTLB HPCP miss (Phase 8)

  // LSU (per-pipe)
  int unsigned n_lsu_req[3];    // [0]=pipe0 [1]=pipe1 [2]=pipe2
  int unsigned n_lsu_miss[3];   // miss count per pipe (TODO Ph7)

  // PTW memory channel (Phase 8)
  int unsigned     n_ptw_mem_req;     // PTW bus read requests (proxy for walk activity)
  int unsigned     n_ptw_mem_rsp;
  // PTW / walk latency (TODO: precise cycle measure)
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
    n_ptw_mem_req     = 0;
    n_ptw_mem_rsp     = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_ifu_rsp    = new("af_ifu_rsp",    this);
    af_lsu_p0_rsp = new("af_lsu_p0_rsp", this);
    af_lsu_p1_rsp = new("af_lsu_p1_rsp", this);
    af_lsu_p2_rsp = new("af_lsu_p2_rsp", this);
    af_hpcp       = new("af_hpcp",       this);
    af_ptw_req    = new("af_ptw_req",    this);
    af_ptw_rsp    = new("af_ptw_rsp",    this);
  endfunction

  // ── run_phase: fork 5 consumer threads ────────────────────────────────────
  virtual task run_phase(uvm_phase phase);
    fork
      _consume_ifu_rsp();
      _consume_lsu_p0_rsp();
      _consume_lsu_p1_rsp();
      _consume_lsu_p2_rsp();
      _consume_hpcp();
      _consume_ptw_req();
      _consume_ptw_rsp();
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
  protected task _consume_ptw_req();
    ptw_mem_txn tr;
    forever begin
      af_ptw_req.get(tr);
      n_ptw_mem_req++;
      `uvm_info(get_type_name(), $sformatf("[PerfMon] PTW req #%0d", n_ptw_mem_req), UVM_HIGH)
    end
  endtask

  protected task _consume_ptw_rsp();
    ptw_mem_txn tr;
    forever begin
      af_ptw_rsp.get(tr);
      n_ptw_mem_rsp++;
      `uvm_info(get_type_name(), $sformatf("[PerfMon] PTW rsp #%0d", n_ptw_mem_rsp), UVM_HIGH)
    end
  endtask

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
    int unsigned n_txn_total, n_miss_hpc;
    n_txn_total = n_ifu_req + n_lsu_req[0] + n_lsu_req[1] + n_lsu_req[2];
    n_miss_hpc  = n_hpcp_dutlb_miss + n_hpcp_iutlb_miss + n_hpcp_jtlb_miss;
    `uvm_info(get_type_name(),
      $sformatf({"[PerfMon] Performance Summary (TaskDivision #3 fields):\n",
        "  n_txn_total (ifu+lsu0+1+2 rsp)     = %0d\n",
        "  n_miss_hpc (dutlb+iutlb+jtlb HPCP)  = %0d\n",
        "  n_ptw_mem_req / n_ptw_mem_rsp        = %0d / %0d\n",
        "  per-channel: IFU req=%0d; LSU0/1/2=%0d/%0d/%0d\n",
        "  HPCP detail: dutlb=%0d iutlb=%0d jtlb=%0d  walk_latency_sum=%0d\n"},
        n_txn_total,
        n_miss_hpc,
        n_ptw_mem_req, n_ptw_mem_rsp,
        n_ifu_req, n_lsu_req[0], n_lsu_req[1], n_lsu_req[2],
        n_hpcp_dutlb_miss, n_hpcp_iutlb_miss, n_hpcp_jtlb_miss, walk_latency_sum),
      UVM_MEDIUM)
  endfunction

endclass : mmu_perf_mon

`endif // MMU_PERF_MON_SVH
