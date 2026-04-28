// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_driver.svh
// Phase 5/6 (Engineer B): LSU driver — single-pulse retry protocol for pipe0/1
//
// Architecture: one shared seq_item_port feeds all 5 sub-threads;
//   each thread filters by lsu_txn.kind (see _get_kind()).
//
// Protocol per sub-channel:
//   pipe0/1: standalone approximation of LSU/LSIQ retry behavior:
//            issue one-cycle pulse first, if no response then wait for
//            wakeup-or-busy-clear, leave one reopen-gap cycle for monitor
//            drop/reopen barrier, then retry the same txn with one-cycle pulses.
//   pipe2:   single-cycle prefetch pulse (no response wait)
//   stamo:   single-cycle PA check assertion (no response wait)
//   inv:     Phase 6 implement
// =============================================================================
`ifndef LSU_DRIVER_SVH
`define LSU_DRIVER_SVH

class lsu_driver extends uvm_driver #(lsu_txn);

  `uvm_component_utils(lsu_driver)

  virtual lsu_if vif;

  // Pending transaction queues per sub-channel (Phase 3: simple single-entry)
  lsu_txn m_pending[$];  // shared FIFO; threads pop by kind

  // Mutual exclusion between pipe0 and pipe1: the DUT's L1 DTLB lookup logic
  // shares resources between the two pipes.  Asserting va0_vld and va1_vld on
  // the same cycle can cause hit-logic interference (问题 2d) and accelerate
  // miss-buffer saturation (问题 3c).  This semaphore serialises each retry
  // pulse so only one LSU pipe asserts va*_vld on a given request beat.
  semaphore m_dtlb_mutex;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_dtlb_mutex = new(1);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual lsu_if)::get(this, "", "LSU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get LSU_VIF from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    _drive_idle();
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(posedge vif.clk_i);
    // Feed incoming items into shared FIFO
    fork
      _fetch_items();
      _drive_pipe0();
      _drive_pipe1();
      _drive_pipe2();
      _drive_stamo();
      _drive_inv();
    join_none
  endtask

  // ── Feed seq_item_port into shared pending queue ─────────────────────────
  protected task _fetch_items();
    lsu_txn tr;
    forever begin
      seq_item_port.get_next_item(tr);
      m_pending.push_back(tr);
      seq_item_port.item_done();
    end
  endtask

  // ── Helper: blocking wait for a transaction of the specified kind ─────────
  protected task _get_kind(lsu_kind_e k, output lsu_txn tr);
    forever begin
      foreach (m_pending[i]) begin
        if (m_pending[i].kind == k) begin
          tr = m_pending[i];
          m_pending.delete(i);
          return;
        end
      end
      @(posedge vif.clk_i);
    end
  endtask

  // ── Drive all outputs to safe idle state ─────────────────────────────────
  protected task _drive_idle();
    // Pipe 0
    vif.driver_cb.lsu_mmu_va0_vld  <= 1'b0;
    vif.driver_cb.lsu_mmu_id0      <= 7'h0;
    vif.driver_cb.lsu_mmu_va0      <= 64'h0;
    vif.driver_cb.lsu_mmu_st_inst0 <= 1'b0;
    vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
    vif.driver_cb.lsu_mmu_vabuf0   <= 28'h0;
    // Pipe 1
    vif.driver_cb.lsu_mmu_va1_vld  <= 1'b0;
    vif.driver_cb.lsu_mmu_id1      <= 7'h0;
    vif.driver_cb.lsu_mmu_va1      <= 64'h0;
    vif.driver_cb.lsu_mmu_st_inst1 <= 1'b0;
    vif.driver_cb.lsu_mmu_abort1   <= 1'b0;
    vif.driver_cb.lsu_mmu_vabuf1   <= 28'h0;
    // Pipe 2
    vif.driver_cb.lsu_mmu_va2_vld  <= 1'b0;
    vif.driver_cb.lsu_mmu_va2      <= 28'h0;
    // STAMO
    vif.driver_cb.lsu_mmu_stamo_vld <= 1'b0;
    vif.driver_cb.lsu_mmu_stamo_pa  <= 28'h0;
    // TLB Inv
    vif.driver_cb.lsu_mmu_tlb_va_all_inv   <= 1'b0;
    vif.driver_cb.lsu_mmu_tlb_all_inv      <= 1'b0;
    vif.driver_cb.lsu_mmu_tlb_va_asid_inv  <= 1'b0;
    vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b0;
    vif.driver_cb.lsu_mmu_tlb_va           <= 27'h0;
    vif.driver_cb.lsu_mmu_tlb_asid         <= 16'h0;
  endtask

  protected function bit _has_wakeup_edge(bit [11:0] prev_wakeup, bit [11:0] cur_wakeup);
    return (cur_wakeup != 12'h000) && (cur_wakeup != prev_wakeup);
  endfunction

  protected task _pulse_pipe0_req(lsu_txn tr);
    m_dtlb_mutex.get(1);
    vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    vif.driver_cb.lsu_mmu_va0      <= tr.va;
    vif.driver_cb.lsu_mmu_id0      <= tr.id;
    vif.driver_cb.lsu_mmu_st_inst0 <= tr.st_inst;
    vif.driver_cb.lsu_mmu_abort0   <= tr.abort;
    vif.driver_cb.lsu_mmu_vabuf0   <= tr.vabuf;
    @(vif.driver_cb);
    vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
    vif.driver_cb.lsu_mmu_abort0  <= 1'b0;
    m_dtlb_mutex.put(1);
  endtask

  protected task _pulse_pipe1_req(lsu_txn tr);
    m_dtlb_mutex.get(1);
    vif.driver_cb.lsu_mmu_va1_vld  <= 1'b1;
    vif.driver_cb.lsu_mmu_va1      <= tr.va;
    vif.driver_cb.lsu_mmu_id1      <= tr.id;
    vif.driver_cb.lsu_mmu_st_inst1 <= tr.st_inst;
    vif.driver_cb.lsu_mmu_abort1   <= tr.abort;
    vif.driver_cb.lsu_mmu_vabuf1   <= tr.vabuf;
    @(vif.driver_cb);
    vif.driver_cb.lsu_mmu_va1_vld <= 1'b0;
    vif.driver_cb.lsu_mmu_abort1  <= 1'b0;
    m_dtlb_mutex.put(1);
  endtask

  // ── Pipe 0 sub-thread ─────────────────────────────────────────────────────
  protected task _drive_pipe0();
    lsu_txn tr;
    forever begin
      bit got_rsp;
      bit retry_gate;
      bit timeout_hit;
      bit [11:0] prev_wakeup;
      _get_kind(LSU_PIPE0, tr);
      `uvm_info(get_type_name(), {"Pipe0: ", tr.convert2string()}, UVM_DEBUG)
      repeat (tr.idle_cycles) @(vif.driver_cb);

      vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
      @(vif.driver_cb);

      _pulse_pipe0_req(tr);
      if (tr.abort == 1'b1) begin
        @(vif.driver_cb);
        continue;
      end

      got_rsp     = 1'b0;
      retry_gate  = 1'b0;
      timeout_hit = 1'b0;
      prev_wakeup = vif.driver_cb.mmu_lsu_tlb_wakeup;

      while (!got_rsp && !timeout_hit) begin
        fork
          begin : wait_rsp_p0
            if (vif.driver_cb.mmu_lsu_pa0_vld !== 1'b1)
              @(vif.driver_cb iff vif.driver_cb.mmu_lsu_pa0_vld === 1'b1);
            got_rsp         = 1'b1;
            tr.pa           = vif.driver_cb.mmu_lsu_pa0;
            tr.pgflt        = vif.driver_cb.mmu_lsu_page_fault0;
            tr.access_fault = vif.driver_cb.mmu_lsu_access_fault0;
            tr.sec          = vif.driver_cb.mmu_lsu_sec0;
          end
          begin : wait_retry_p0
            bit [11:0] cur_wakeup;
            forever begin
              @(vif.driver_cb);
              cur_wakeup = vif.driver_cb.mmu_lsu_tlb_wakeup;
              if ((vif.driver_cb.mmu_lsu_pa0_vld !== 1'b1)
                  && ((vif.driver_cb.mmu_lsu_tlb_busy === 1'b0)
                      || _has_wakeup_edge(prev_wakeup, cur_wakeup))) begin
                retry_gate  = 1'b1;
                prev_wakeup = cur_wakeup;
                break;
              end
              prev_wakeup = cur_wakeup;
            end
          end
          begin : wait_timeout_p0
            repeat (200000) @(vif.driver_cb);
            timeout_hit = 1'b1;
            `uvm_warning(get_type_name(),
              $sformatf("Pipe0 response timeout: va=0x%016h id=%0d busy=%0b wakeup=0x%03h",
                tr.va, tr.id, vif.driver_cb.mmu_lsu_tlb_busy,
                vif.driver_cb.mmu_lsu_tlb_wakeup))
          end
        join_any
        disable fork;

        if (got_rsp) begin
          @(vif.driver_cb);
        end else if (!timeout_hit && retry_gate) begin
          // Align retry timing with lsu_monitor drop_reopen_block.  Retrying on
          // the same sampled cycle as busy-clear/wakeup lets the next one-cycle
          // pulse fall entirely inside the reopen barrier and the monitor misses
          // the request, recreating req/rsp association drift.
          @(vif.driver_cb);
          retry_gate = 1'b0;
          _pulse_pipe0_req(tr);
        end
      end

      @(vif.driver_cb);
    end
  endtask

  // ── Pipe 1 sub-thread ─────────────────────────────────────────────────────
  protected task _drive_pipe1();
    lsu_txn tr;
    forever begin
      bit got_rsp;
      bit retry_gate;
      bit timeout_hit;
      bit [11:0] prev_wakeup;
      _get_kind(LSU_PIPE1, tr);
      `uvm_info(get_type_name(), {"Pipe1: ", tr.convert2string()}, UVM_DEBUG)
      repeat (tr.idle_cycles) @(vif.driver_cb);

      vif.driver_cb.lsu_mmu_va1_vld <= 1'b0;
      @(vif.driver_cb);

      _pulse_pipe1_req(tr);
      if (tr.abort == 1'b1) begin
        @(vif.driver_cb);
        continue;
      end

      got_rsp     = 1'b0;
      retry_gate  = 1'b0;
      timeout_hit = 1'b0;
      prev_wakeup = vif.driver_cb.mmu_lsu_tlb_wakeup;

      while (!got_rsp && !timeout_hit) begin
        fork
          begin : wait_rsp_p1
            if (vif.driver_cb.mmu_lsu_pa1_vld !== 1'b1)
              @(vif.driver_cb iff vif.driver_cb.mmu_lsu_pa1_vld === 1'b1);
            got_rsp         = 1'b1;
            tr.pa           = vif.driver_cb.mmu_lsu_pa1;
            tr.pgflt        = vif.driver_cb.mmu_lsu_page_fault1;
            tr.access_fault = vif.driver_cb.mmu_lsu_access_fault1;
            tr.sec          = vif.driver_cb.mmu_lsu_sec1;
          end
          begin : wait_retry_p1
            bit [11:0] cur_wakeup;
            forever begin
              @(vif.driver_cb);
              cur_wakeup = vif.driver_cb.mmu_lsu_tlb_wakeup;
              if ((vif.driver_cb.mmu_lsu_pa1_vld !== 1'b1)
                  && ((vif.driver_cb.mmu_lsu_tlb_busy === 1'b0)
                      || _has_wakeup_edge(prev_wakeup, cur_wakeup))) begin
                retry_gate  = 1'b1;
                prev_wakeup = cur_wakeup;
                break;
              end
              prev_wakeup = cur_wakeup;
            end
          end
          begin : wait_timeout_p1
            repeat (200000) @(vif.driver_cb);
            timeout_hit = 1'b1;
            `uvm_warning(get_type_name(),
              $sformatf("Pipe1 response timeout: va=0x%016h id=%0d busy=%0b wakeup=0x%03h",
                tr.va, tr.id, vif.driver_cb.mmu_lsu_tlb_busy,
                vif.driver_cb.mmu_lsu_tlb_wakeup))
          end
        join_any
        disable fork;

        if (got_rsp) begin
          @(vif.driver_cb);
        end else if (!timeout_hit && retry_gate) begin
          // Same reopen-gap rule as pipe0; see note above.
          @(vif.driver_cb);
          retry_gate = 1'b0;
          _pulse_pipe1_req(tr);
        end
      end

      @(vif.driver_cb);
    end
  endtask

  // ── Pipe 2 (Prefetch) sub-thread ─────────────────────────────────────────
  protected task _drive_pipe2();
    lsu_txn tr;
    forever begin
      _get_kind(LSU_PIPE2, tr);
      `uvm_info(get_type_name(), {"Pipe2: ", tr.convert2string()}, UVM_HIGH)
      repeat (tr.idle_cycles) @(vif.driver_cb);
      @(vif.driver_cb);
      vif.driver_cb.lsu_mmu_va2_vld <= 1'b1;
      vif.driver_cb.lsu_mmu_va2     <= tr.va2;
      @(vif.driver_cb);
      vif.driver_cb.lsu_mmu_va2_vld <= 1'b0;
    end
  endtask

  // ── STAMO sub-thread ──────────────────────────────────────────────────────
  // Note: STAMO presents a physical address (post-LSU-TLB) for PMP/sysmap check.
  // RTL: Pipe1 STAMO is hardwired 1'b0 internally (F2.14), only this port used.
  protected task _drive_stamo();
    lsu_txn tr;
    forever begin
      _get_kind(LSU_STAMO, tr);
      `uvm_info(get_type_name(), {"STAMO: ", tr.convert2string()}, UVM_HIGH)
      repeat (tr.idle_cycles) @(vif.driver_cb);
      @(vif.driver_cb);
      vif.driver_cb.lsu_mmu_stamo_vld <= 1'b1;
      vif.driver_cb.lsu_mmu_stamo_pa  <= tr.stamo_pa;
      @(vif.driver_cb);
      vif.driver_cb.lsu_mmu_stamo_vld <= 1'b0;
    end
  endtask

  // ── TLB Invalidation sub-thread ───────────────────────────────────────────
  protected task _drive_inv();
    lsu_txn tr;
    forever begin
      _get_kind(LSU_INV, tr);
      `uvm_info(get_type_name(), {"INV: ", tr.convert2string()}, UVM_HIGH)
      repeat (tr.idle_cycles) @(vif.driver_cb);
      // Avoid issuing a new invalidate when DTLB is still busy.  In that case
      // the request can be delayed or merged by DUT side state machines.
      if (vif.driver_cb.mmu_lsu_tlb_busy === 1'b1)
        @(vif.driver_cb iff vif.driver_cb.mmu_lsu_tlb_busy === 1'b0);
      @(vif.driver_cb);
      vif.driver_cb.lsu_mmu_tlb_va   <= tr.inv_va;
      vif.driver_cb.lsu_mmu_tlb_asid <= tr.inv_asid;
      case (tr.inv_kind)
        INV_ALL:      vif.driver_cb.lsu_mmu_tlb_all_inv      <= 1'b1;
        INV_VA_ALL:   vif.driver_cb.lsu_mmu_tlb_va_all_inv   <= 1'b1;
        INV_ASID_ALL: vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b1;
        INV_VA_ASID:  vif.driver_cb.lsu_mmu_tlb_va_asid_inv  <= 1'b1;
      endcase
      @(vif.driver_cb);
      vif.driver_cb.lsu_mmu_tlb_all_inv      <= 1'b0;
      vif.driver_cb.lsu_mmu_tlb_va_all_inv   <= 1'b0;
      vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b0;
      vif.driver_cb.lsu_mmu_tlb_va_asid_inv  <= 1'b0;
      // Wait for DUT to acknowledge invalidation completion (with timeout)
      fork
        begin : wait_inv_done
          @(vif.driver_cb iff vif.driver_cb.mmu_lsu_tlb_inv_done === 1'b1);
          tr.inv_done = 1'b1;
          `uvm_info(get_type_name(),
            $sformatf("TLB INV done observed: kind=%s va=0x%07h asid=0x%04h",
              tr.inv_kind.name(), tr.inv_va, tr.inv_asid),
            UVM_HIGH)
        end
        begin : wait_inv_timeout
          repeat (1024) @(vif.driver_cb);
          `uvm_warning(get_type_name(),
            $sformatf("TLB INV response timeout (inv_kind=%s) — DUT may not have completed invalidation",
              tr.inv_kind.name()))
        end
      join_any
      disable fork;
    end
  endtask

endclass : lsu_driver

`endif // LSU_DRIVER_SVH
