// =============================================================================
// MMU UVM Verification — testbench/env/mmu_invalidate_sb.svh
// Phase 6 (Engineer B): Invalidation scoreboard
//
// Tracks two invalidation sources:
//   1) LSU SFENCE.VMA path  (lsu_monitor.ap_inv)
//   2) CP0 TLB-all-inv path (cp0_monitor.ap, tlb_done event)
//
// Goal for Phase 6:
//   - Provide stable counters for sign-off:
//       N_invalidations, N_cp0_all_inv, N_inv_done_seen, mismatch
//   - Catch obvious protocol/data issues on invalidate event stream.
// =============================================================================
`ifndef MMU_INVALIDATE_SB_SVH
`define MMU_INVALIDATE_SB_SVH

class mmu_invalidate_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_invalidate_sb)

  // Inputs
  uvm_tlm_analysis_fifo #(lsu_txn) af_inv;
  uvm_tlm_analysis_fifo #(cp0_txn) af_cp0;

  // Stats for Phase 6 sign-off
  int unsigned m_n_invalidations;
  int unsigned m_n_inv_kind [4];
  int unsigned m_n_inv_done_seen;
  int unsigned m_n_cp0_all_inv;
  int unsigned m_mismatch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_n_invalidations = 0;
    m_n_inv_done_seen = 0;
    m_n_cp0_all_inv   = 0;
    m_mismatch        = 0;
    foreach (m_n_inv_kind[i]) m_n_inv_kind[i] = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_inv = new("af_inv", this);
    af_cp0 = new("af_cp0", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      _consume_lsu_inv();
      _consume_cp0_inv();
    join_none
  endtask

  protected task _consume_lsu_inv();
    lsu_txn tr;
    forever begin
      af_inv.get(tr);

      if (tr.kind != LSU_INV) begin
        m_mismatch++;
        `uvm_error(get_type_name(),
          $sformatf("Invalid transaction on af_inv: kind=%s (expected LSU_INV)", tr.kind.name()))
        continue;
      end

      m_n_invalidations++;
      m_n_inv_kind[int'(tr.inv_kind)]++;
      if (tr.inv_done) m_n_inv_done_seen++;

      `uvm_info(get_type_name(),
        $sformatf("[INV_SB] LSU inv: kind=%s va=0x%07h asid=0x%04h done=%0b",
          tr.inv_kind.name(), tr.inv_va, tr.inv_asid, tr.inv_done),
        UVM_HIGH)
    end
  endtask

  protected task _consume_cp0_inv();
    cp0_txn tr;
    forever begin
      af_cp0.get(tr);
      if ((tr.op == CP0_TLB_ALL_INV) && tr.tlb_done) begin
        m_n_cp0_all_inv++;
        `uvm_info(get_type_name(),
          $sformatf("[INV_SB] CP0 tlb_all_inv done observed (count=%0d)", m_n_cp0_all_inv),
          UVM_HIGH)
      end
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf({"Invalidate SB summary: N_invalidations=%0d ",
                 "(all=%0d va=%0d asid=%0d va_asid=%0d), ",
                 "N_inv_done_seen=%0d, N_cp0_all_inv=%0d, mismatch=%0d"},
        m_n_invalidations,
        m_n_inv_kind[int'(INV_ALL)],
        m_n_inv_kind[int'(INV_VA_ALL)],
        m_n_inv_kind[int'(INV_ASID_ALL)],
        m_n_inv_kind[int'(INV_VA_ASID)],
        m_n_inv_done_seen,
        m_n_cp0_all_inv,
        m_mismatch),
      UVM_NONE)

    if (m_mismatch > 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Invalidate SB FAILED: mismatch=%0d", m_mismatch))
    end
  endfunction

endclass : mmu_invalidate_sb

`endif // MMU_INVALIDATE_SB_SVH
