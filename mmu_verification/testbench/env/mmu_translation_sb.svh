// =============================================================================
// MMU UVM Verification — testbench/env/mmu_translation_sb.svh
// Phase 5 (Engineer B): Translation Scoreboard
//
// Receives merged req+rsp transactions from IFU/LSU monitors and compares
// DUT MMU translation output against the Sv39 software reference model.
//
// Subscribed analysis ports (connected in mmu_env::connect_phase):
//   af_ifu_rsp    ← m_ifu.m_monitor.ap_rsp      (ifu_txn with VA+PA)
//   af_lsu_p0_rsp ← m_lsu.m_monitor.ap_pipe0_rsp (lsu_txn with VA+PA)
//   af_lsu_p1_rsp ← m_lsu.m_monitor.ap_pipe1_rsp (lsu_txn with VA+PA)
//   af_lsu_p2_rsp ← m_lsu.m_monitor.ap_pipe2_rsp (lsu_txn; VA limited until Ph6)
//
// Comparison logic (per channel):
//   1. If tr.abort==1 (IFU/LSU): skip — aborted transaction has no valid PA.
//   2. Call m_ref.translate(va, acc_type) to get golden result.
//   3. Exception check: ref.exc!=EXC_NONE  vs  DUT fault signals (pgflt/deny).
//   4. PA check (only when no fault on either side): ref.ppn vs tr.pa.
//      Exception (LSU_P1 only): tr.stamo_vld_at_rsp → st_ag can mux dut.pa1 from
//      STAMO (lm), not DTLB; SB checks dut.pa==stamo_pa and skips ref PPN.
//      LSU_P0: lsu_mmu_stamo_vld may be global; pa0 is still the DTLB PPN for
//      this pipe — do not equate mmu_lsu_pa0 to lsu_mmu_stamo_pa.
//   5. Mismatch → uvm_error; match → uvm_info (UVM_HIGH).
//
// LSU: mmu_l1dtlb_hit_rd pre_sel path muxes dutlb_off_pa = VA[38:12] (PPN looks
//   like VPN) for expt CAM consume, VA-illegal, MMU-off, etc. The Sv39 ref has
//   no expt CAM — waive ref-vs-DUT fault compare when:
//   (a) tr.dtlb_expt_match from u_mmu_l1dtlb.expt_match{0,1}, OR
//   (b) architectural signature: mmu_en && !stall && fault && dut_pa==req_vpn
//       (not STAMO skip path) — covers probe wiring / hierarchy mismatch.
//
// Pipe2 note: monitor does not yet merge VA into pipe2 rsp txn (Phase 6).
//   If va2==0, the transaction is counted but PA comparison is skipped.
// =============================================================================
`ifndef MMU_TRANSLATION_SB_SVH
`define MMU_TRANSLATION_SB_SVH

// ── Analysis import suffix declarations ───────────────────────────────────
// Must be declared outside the class scope (package level when `include'd).
`uvm_analysis_imp_decl(_ifu)
`uvm_analysis_imp_decl(_lsu_p0)
`uvm_analysis_imp_decl(_lsu_p1)
`uvm_analysis_imp_decl(_lsu_p2)

class mmu_translation_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_translation_sb)

  // ── Analysis import ports ─────────────────────────────────────────────────
  uvm_analysis_imp_ifu    #(ifu_txn, mmu_translation_sb) af_ifu_rsp;
  uvm_analysis_imp_lsu_p0 #(lsu_txn, mmu_translation_sb) af_lsu_p0_rsp;
  uvm_analysis_imp_lsu_p1 #(lsu_txn, mmu_translation_sb) af_lsu_p1_rsp;
  uvm_analysis_imp_lsu_p2 #(lsu_txn, mmu_translation_sb) af_lsu_p2_rsp;

  // ── Reference model (injected from mmu_env.build_phase) ──────────────────
  mmu_ref_model m_ref;

  // ── Statistics ────────────────────────────────────────────────────────────
  int unsigned m_total_checked;
  int unsigned m_mismatch;
  int unsigned m_lsu_fault_replay_rsp;
  int unsigned m_lsu_replay_mismatch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_total_checked = 0;
    m_mismatch      = 0;
    m_lsu_fault_replay_rsp = 0;
    m_lsu_replay_mismatch = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_ifu_rsp    = new("af_ifu_rsp",    this);
    af_lsu_p0_rsp = new("af_lsu_p0_rsp", this);
    af_lsu_p1_rsp = new("af_lsu_p1_rsp", this);
    af_lsu_p2_rsp = new("af_lsu_p2_rsp", this);
  endfunction

  // =========================================================================
  // write_ifu — IFU fetch translation check
  //   Access type: ACC_FETCH
  //   Fault signals: tr.pgflt (page fault) | tr.deny (PMP/sysmap deny)
  //   Skip when tr.abort==1 (pipeline abort, no valid translation)
  // =========================================================================
  virtual function void write_ifu(ifu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    bit           dut_fault;

    if (tr.abort) begin
      `uvm_info(get_type_name(),
        $sformatf("write_ifu: abort=1, VA=0x%010h — skipping check", {1'b0, tr.va}),
        UVM_HIGH)
      return;
    end

    m_total_checked++;
    va        = va_t'(tr.va[38:0]);
    ref_rsp   = m_ref.translate(va, ACC_FETCH, 0);
    dut_fault = tr.pgflt | tr.deny;

    _compare(.channel("IFU"), .va(va), .ref_rsp(ref_rsp),
             .dut_pa(tr.pa),  .dut_fault(dut_fault));
  endfunction

  // =========================================================================
  // write_lsu_p0 — LSU Pipe 0 load/store translation check
  //   Access type: ACC_STORE if tr.st_inst==1, else ACC_LOAD
  //   Fault signals: tr.pgflt | tr.access_fault
  //   Skip when tr.abort==1
  // =========================================================================
  virtual function void write_lsu_p0(lsu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    acc_type_e    acc;
    bit           dut_fault;

    if (tr.abort) begin
      `uvm_info(get_type_name(),
        $sformatf("write_lsu_p0: abort=1, VA=0x%016h — skipping check", tr.va),
        UVM_HIGH)
      return;
    end

    m_total_checked++;
    va        = va_t'(tr.va[38:0]);
    acc       = tr.st_inst ? ACC_STORE : ACC_LOAD;
    ref_rsp   = m_ref.translate(va, acc, 1);
    dut_fault = tr.pgflt | tr.access_fault;

    _compare(.channel("LSU_P0"), .va(va), .ref_rsp(ref_rsp),
             .dut_pa(tr.pa),     .dut_fault(dut_fault),
             .req_vpn(va[38:12]), .dbg_valid(1'b1),
             .tr_stall(tr.stall), .tr_pgflt(tr.pgflt),
             .tr_access_fault(tr.access_fault), .tr_mmu_en(tr.mmu_en),
             .dtlb_expt_match(tr.dtlb_expt_match));
  endfunction

  // =========================================================================
  // write_lsu_p1 — LSU Pipe 1 load/store translation check (same as pipe0)
  //   Access type: ACC_STORE if tr.st_inst==1, else ACC_LOAD
  // =========================================================================
  virtual function void write_lsu_p1(lsu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    acc_type_e    acc;
    bit           dut_fault;

    if (tr.abort) begin
      `uvm_info(get_type_name(),
        $sformatf("write_lsu_p1: abort=1, VA=0x%016h — skipping check", tr.va),
        UVM_HIGH)
      return;
    end

    m_total_checked++;
    va        = va_t'(tr.va[38:0]);
    acc       = tr.st_inst ? ACC_STORE : ACC_LOAD;
    ref_rsp   = m_ref.translate(va, acc, 2);
    dut_fault = tr.pgflt | tr.access_fault;

    if (tr.stamo_vld_at_rsp && (tr.pa !== tr.stamo_pa_at_rsp)) begin
      `uvm_error(get_type_name(),
        $sformatf("[LSU_P1] STAMO vld: expected dut.pa=lsu_mmu_stamo_pa, got pa=0x%07h stamo=0x%07h (VA=0x%010h)",
          tr.pa, tr.stamo_pa_at_rsp, {1'b0, va}))
    end

    _compare(.channel("LSU_P1"), .va(va), .ref_rsp(ref_rsp),
             .dut_pa(tr.pa),     .dut_fault(dut_fault),
             .req_vpn(va[38:12]), .dbg_valid(1'b1),
             .tr_stall(tr.stall), .tr_pgflt(tr.pgflt),
             .tr_access_fault(tr.access_fault), .tr_mmu_en(tr.mmu_en),
             .skip_ref_ppn_check(tr.stamo_vld_at_rsp),
             .dtlb_expt_match(tr.dtlb_expt_match));
  endfunction

  // =========================================================================
  // write_lsu_p2 — LSU Pipe 2 prefetch translation check
  //   Access type: ACC_PFU (always prefetch)
  //   VA source: tr.va2[26:0] reconstructed as VA[38:12] (27-bit VPN << 12).
  //
  //   Limitation: pipe2 monitor does not yet correlate req VA into rsp txn
  //   (m_pending_p2 queue not yet added — Phase 6 enhancement).
  //   If tr.va2==0, transaction is counted but comparison is skipped.
  // =========================================================================
  virtual function void write_lsu_p2(lsu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;

    m_total_checked++;

    if (tr.va2 == '0) begin
      `uvm_info(get_type_name(),
        "write_lsu_p2: va2==0 (no req/rsp VA correlation yet) — count only",
        UVM_DEBUG)
      return;
    end

    // Reconstruct 39-bit VA: take lower 27 bits of va2 as VPN (VA[38:12]),
    // append 12-bit zero page offset.
    va      = va_t'({tr.va2[26:0], 12'b0});
    ref_rsp = m_ref.translate(va, ACC_PFU, 1);

    // Pipe2 rsp txn currently carries pa and sec only; no fault signals.
    // Restrict comparison to PA only when ref predicts no fault.
    if (ref_rsp.exc != EXC_NONE) begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h ref.exc=%s — fault check deferred (Phase 6)",
          {1'b0, va}, ref_rsp.exc.name()),
        UVM_MEDIUM)
      return;
    end

    if (ref_rsp.ppn !== tr.pa) begin
      `uvm_error(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h: PA mismatch — ref.ppn=0x%07h  dut.pa=0x%07h",
          {1'b0, va}, ref_rsp.ppn, tr.pa))
      m_mismatch++;
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h  ref.ppn=0x%07h  dut.pa=0x%07h  PASS",
          {1'b0, va}, ref_rsp.ppn, tr.pa),
        UVM_HIGH)
    end
  endfunction

  // =========================================================================
  // report_phase — print summary and trigger final error if mismatches found
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Translation SB summary: total_checked=%0d mismatch=%0d lsu_fault_replay_rsp=%0d lsu_replay_mismatch=%0d",
        m_total_checked, m_mismatch, m_lsu_fault_replay_rsp, m_lsu_replay_mismatch),
      UVM_NONE)
    if (m_mismatch > 0)
      `uvm_error(get_type_name(),
        $sformatf("Translation SB FAILED: %0d mismatch(es) detected!", m_mismatch))
  endfunction

  // =========================================================================
  // _compare — internal comparison helper (channels IFU / LSU_P0 / LSU_P1)
  //
  //   ref_rsp.exc != EXC_NONE → expect dut_fault == 1
  //   ref_rsp.exc == EXC_NONE → expect dut_fault == 0 AND ref.ppn == dut_pa
  //   skip_ref_ppn_check: DUT muxes PPN from STAMO (lsu_mmu_stamo_*) at rsp —
  //   not comparable to mmu_ref_model.translate() (see mmu_l1dtlb dutlb_pre_pa).
  // =========================================================================
  protected function void _compare(
    string        channel,
    va_t          va,
    xlation_rsp_t ref_rsp,
    bit [27:0]    dut_pa,
    bit           dut_fault,
    bit [27:0]    req_vpn = '0,
    bit           dbg_valid = 1'b0,
    bit           tr_stall = 1'b0,
    bit           tr_pgflt = 1'b0,
    bit           tr_access_fault = 1'b0,
    bit           tr_mmu_en = 1'b0,
    bit           skip_ref_ppn_check = 1'b0,
    bit           dtlb_expt_match = 1'b0
  );
    // Treat deny as a fault-class outcome as well (for PMP/SysMap modeled paths).
    bit exp_fault = (ref_rsp.exc != EXC_NONE) || ref_rsp.deny;
    bit local_mismatch = 0;
    bit fault_replay_rsp = 0;
    // Ref does not model DTLB pre_sel/expt CAM; see file header.
    bit skip_lsu_dtlb_ref_fault_compare;

    // LSU: stats for fault responses under MMU (legacy visibility)
    fault_replay_rsp = dbg_valid
                    && tr_mmu_en
                    && dut_fault;
    if (fault_replay_rsp)
      m_lsu_fault_replay_rsp++;

    skip_lsu_dtlb_ref_fault_compare = dbg_valid
      && (ref_rsp.exc == EXC_NONE)
      && dut_fault
      && (
           dtlb_expt_match
        || (tr_mmu_en && !tr_stall
            && (dut_pa == req_vpn) && !skip_ref_ppn_check)
      );

    // ── Exception / fault check ───────────────────────────────────────────
    if (exp_fault !== dut_fault) begin
      if (!skip_lsu_dtlb_ref_fault_compare) begin
        if (fault_replay_rsp) begin
          `uvm_error(get_type_name(),
            $sformatf("[%s][EXPT_REPLAY] VA=0x%010h: fault mismatch on replay response — ref.exc=%s ref.deny=%0b (exp_fault=%0b) dut_fault=%0b dut.pa=0x%07h req_vpn=0x%07h",
              channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, exp_fault, dut_fault, dut_pa, req_vpn))
          m_lsu_replay_mismatch++;
        end else begin
          `uvm_error(get_type_name(),
            $sformatf("[%s] VA=0x%010h: fault mismatch — ref.exc=%s ref.deny=%0b (exp_fault=%0b)  dut_fault=%0b",
              channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, exp_fault, dut_fault))
        end
        local_mismatch = 1;
      end
    end

    // ── PA check — only when both ref and DUT predict no fault ────────────
    if (!exp_fault && !dut_fault) begin
      if (!skip_ref_ppn_check && (ref_rsp.ppn !== dut_pa)) begin
        `uvm_error(get_type_name(),
          $sformatf("[%s] VA=0x%010h: PA mismatch — ref.ppn=0x%07h  dut.pa=0x%07h",
            channel, {1'b0, va}, ref_rsp.ppn, dut_pa))
        local_mismatch = 1;
      end
    end

    if (local_mismatch) begin
      if (dbg_valid) begin
        `uvm_error(get_type_name(),
          $sformatf("[%s][DBG] VA=0x%010h dut.pa=0x%07h req_vpn(va[38:12])=0x%07h | stall=%0b pgflt=%0b access_fault=%0b mmu_lsu_mmu_en=%0b",
            channel, {1'b0, va}, dut_pa, req_vpn,
            tr_stall, tr_pgflt, tr_access_fault, tr_mmu_en))
      end
      m_mismatch++;
    end else begin
      if (skip_lsu_dtlb_ref_fault_compare) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  DTLB pre_sel/expt path: not vs ref  exc=%s  expt_match=%0b  dut_fault=%0b  dut.pa=0x%07h  PASS (SB waive)",
            channel, {1'b0, va}, ref_rsp.exc.name(), dtlb_expt_match, dut_fault, dut_pa),
          UVM_HIGH)
      end else if (skip_ref_ppn_check) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  STAMO mux: fault check PASS (dut.pa=0x%07h; ref not compared)  exc=%s",
            channel, {1'b0, va}, dut_pa, ref_rsp.exc.name()),
          UVM_MEDIUM)
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  ref.ppn=0x%07h  dut.pa=0x%07h  exc=%s  PASS",
            channel, {1'b0, va}, ref_rsp.ppn, dut_pa, ref_rsp.exc.name()),
          UVM_HIGH)
      end
    end
  endfunction

endclass : mmu_translation_sb

`endif // MMU_TRANSLATION_SB_SVH
