// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_driver.svh
// Phase 5 (Engineer B): LSU driver — full handshake for pipe0/pipe1
//
// Architecture: one shared seq_item_port feeds all 5 sub-threads;
//   each thread filters by lsu_txn.kind (see _get_kind()).
//
// Protocol per sub-channel:
//   pipe0/1: model core LSIQ retry behavior. Assert va_vld for one issue
//            attempt; if pa*_vld does not return, deassert and retry.  When
//            mmu_lsu_tlb_busy is high, wait for tlb_wakeup (or busy clear)
//            before retrying the same transaction.
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
  // miss-buffer saturation (问题 3c).  This semaphore serialises the
  // assert-va_vld → wait-pa_vld window so only one pipe drives at a time.
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

  // Model the core LSIQ retry contract at the MMU boundary.
  // When tlb_busy is high, a new LSU miss would be parked in IDU/LSIQ until a
  // wakeup release.  The standalone agent waits for that retry window instead
  // of requiring busy to become 0, because busy may remain high while another
  // MB entry is still in flight.
  protected task _wait_tlb_retry_window(string pipe_name, lsu_txn tr);
    if (vif.driver_cb.mmu_lsu_tlb_busy !== 1'b1)
      return;

    `uvm_info(get_type_name(),
      $sformatf("%s sees tlb_busy=1 before issue: va=0x%016h id=%0d; waiting for wakeup/retry window",
        pipe_name, tr.va, tr.id),
      UVM_MEDIUM)

    fork
      begin : wait_tlb_release
        @(vif.driver_cb iff ((vif.driver_cb.mmu_lsu_tlb_wakeup != 12'h000) ||
                             (vif.driver_cb.mmu_lsu_tlb_busy === 1'b0)));
      end
      begin : wait_tlb_release_timeout
        repeat (4096) @(vif.driver_cb);
        `uvm_warning(get_type_name(),
          $sformatf("%s tlb_busy retry wait timeout: va=0x%016h id=%0d busy=%0b wakeup=0x%03h",
            pipe_name, tr.va, tr.id,
            vif.driver_cb.mmu_lsu_tlb_busy, vif.driver_cb.mmu_lsu_tlb_wakeup))
      end
    join_any
    disable fork;
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

  // ── Pipe 0 sub-thread ─────────────────────────────────────────────────────
  protected task _drive_pipe0();
    lsu_txn tr;
    bit done;
    int attempts;
    forever begin
      _get_kind(LSU_PIPE0, tr);
      `uvm_info(get_type_name(), {"Pipe0: ", tr.convert2string()}, UVM_HIGH)
      repeat (tr.idle_cycles) @(vif.driver_cb);

      vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
      @(vif.driver_cb);

      m_dtlb_mutex.get(1);
      done = 1'b0;
      attempts = 0;

      do begin
        attempts++;
        _wait_tlb_retry_window("Pipe0", tr);

        vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
        vif.driver_cb.lsu_mmu_va0      <= tr.va;
        vif.driver_cb.lsu_mmu_id0      <= tr.id;
        vif.driver_cb.lsu_mmu_st_inst0 <= tr.st_inst;
        vif.driver_cb.lsu_mmu_abort0   <= tr.abort;
        vif.driver_cb.lsu_mmu_vabuf0   <= tr.vabuf;
        @(vif.driver_cb);

        if (tr.abort == 1'b1) begin
          done = 1'b1;
        end else if (vif.driver_cb.mmu_lsu_pa0_vld === 1'b1) begin
            tr.pa           = vif.driver_cb.mmu_lsu_pa0;
            tr.pgflt        = vif.driver_cb.mmu_lsu_page_fault0;
            tr.access_fault = vif.driver_cb.mmu_lsu_access_fault0;
            tr.sec          = vif.driver_cb.mmu_lsu_sec0;
            done = 1'b1;
        end

        @(vif.driver_cb);
        vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
        vif.driver_cb.lsu_mmu_abort0  <= 1'b0;

        if (!done) begin
          if ((attempts % 64) == 0) begin
            `uvm_info(get_type_name(),
              $sformatf("Pipe0 retrying after miss/busy wait: va=0x%016h id=%0d attempts=%0d busy=%0b wakeup=0x%03h",
                tr.va, tr.id, attempts,
                vif.driver_cb.mmu_lsu_tlb_busy, vif.driver_cb.mmu_lsu_tlb_wakeup),
              UVM_MEDIUM)
          end
          if (attempts >= 4096) begin
            `uvm_warning(get_type_name(),
              $sformatf("Pipe0 retry timeout: va=0x%016h id=%0d attempts=%0d",
                tr.va, tr.id, attempts))
            done = 1'b1;
          end
        end
      end while (!done);

      m_dtlb_mutex.put(1);
    end
  endtask

  // ── Pipe 1 sub-thread ─────────────────────────────────────────────────────
  protected task _drive_pipe1();
    lsu_txn tr;
    bit done;
    int attempts;
    forever begin
      _get_kind(LSU_PIPE1, tr);
      `uvm_info(get_type_name(), {"Pipe1: ", tr.convert2string()}, UVM_HIGH)
      repeat (tr.idle_cycles) @(vif.driver_cb);

      vif.driver_cb.lsu_mmu_va1_vld <= 1'b0;
      @(vif.driver_cb);

      m_dtlb_mutex.get(1);
      done = 1'b0;
      attempts = 0;

      do begin
        attempts++;
        _wait_tlb_retry_window("Pipe1", tr);

        vif.driver_cb.lsu_mmu_va1_vld  <= 1'b1;
        vif.driver_cb.lsu_mmu_va1      <= tr.va;
        vif.driver_cb.lsu_mmu_id1      <= tr.id;
        vif.driver_cb.lsu_mmu_st_inst1 <= tr.st_inst;
        vif.driver_cb.lsu_mmu_abort1   <= tr.abort;
        vif.driver_cb.lsu_mmu_vabuf1   <= tr.vabuf;
        @(vif.driver_cb);

        if (tr.abort == 1'b1) begin
          done = 1'b1;
        end else if (vif.driver_cb.mmu_lsu_pa1_vld === 1'b1) begin
            tr.pa           = vif.driver_cb.mmu_lsu_pa1;
            tr.pgflt        = vif.driver_cb.mmu_lsu_page_fault1;
            tr.access_fault = vif.driver_cb.mmu_lsu_access_fault1;
            tr.sec          = vif.driver_cb.mmu_lsu_sec1;
            done = 1'b1;
        end

        @(vif.driver_cb);
        vif.driver_cb.lsu_mmu_va1_vld <= 1'b0;
        vif.driver_cb.lsu_mmu_abort1  <= 1'b0;

        if (!done) begin
          if ((attempts % 64) == 0) begin
            `uvm_info(get_type_name(),
              $sformatf("Pipe1 retrying after miss/busy wait: va=0x%016h id=%0d attempts=%0d busy=%0b wakeup=0x%03h",
                tr.va, tr.id, attempts,
                vif.driver_cb.mmu_lsu_tlb_busy, vif.driver_cb.mmu_lsu_tlb_wakeup),
              UVM_MEDIUM)
          end
          if (attempts >= 4096) begin
            `uvm_warning(get_type_name(),
              $sformatf("Pipe1 retry timeout: va=0x%016h id=%0d attempts=%0d",
                tr.va, tr.id, attempts))
            done = 1'b1;
          end
        end
      end while (!done);

      m_dtlb_mutex.put(1);
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
