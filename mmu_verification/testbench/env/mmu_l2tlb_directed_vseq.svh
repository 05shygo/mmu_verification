`ifndef MMU_L2TLB_DIRECTED_VSEQ_SVH
`define MMU_L2TLB_DIRECTED_VSEQ_SVH

// Directed vseq for L2TLB corner-case coverage (PFU_CHK->DENY, etc.)
class mmu_l2tlb_pfu_chk_deny_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l2tlb_pfu_chk_deny_vseq)

  function new(string name = "mmu_l2tlb_pfu_chk_deny_vseq");
    super.new(name);
    m_va_base  = 39'h10_0000;
  endfunction

  // Drive a PFU (pipe2) request — lsu_mmu_va2 = VA[27:0] (28-bit)
  protected task raw_pipe2(va_t va);
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va2      <= va[27:0];  // VA low 28 bits
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld <= 1'b0;
  endtask

  virtual task body();
    m_env_h   = get_env();
    m_lsu_vif = m_env_h.m_lsu.vif;
    m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null)
      `uvm_fatal(get_type_name(), "LSU VIF is null")
    `uvm_info(get_type_name(), "Starting PFU_CHK->DENY directed vseq", UVM_LOW)

    // Phase 1: Issue DTLB loads to fill L2TLB with bringup pages
    for (int i = 0; i < 4; i++) begin
      raw_pipe0(va_page(i), 7'(7'd10 + i[6:0]), 1'b0);
      #100ns;
    end
    // Wait for PTW refill -> L2TLB entries installed
    #50000ns;

    // Phase 2: Issue PFU to same pages. PMP port4 deny + sysmap safe flags
    // should cause TLB hit -> PFU_IDLE -> PFU_CHK -> PFU_DENY
    for (int i = 0; i < 8; i++) begin
      raw_pipe2(va_page(i & 2'h3));
      #200ns;
    end

    #5000ns;
    `uvm_info(get_type_name(), "PFU_CHK->DENY directed vseq complete", UVM_LOW)
  endtask
endclass


// =============================================================================
// TASK L2TLB-T01 — PFU_DENY via PFU_CHK path (clean R/W/X L2TLB entry + PMP deny)
//
// Root cause for the existing gap: the existing mmu_l2tlb_pfu_chk_deny_vseq
// covers PFU_IDLE→PFU_DENY (line 1359, triggered by l2tlb_pfu_acc_fault=1)
// but does NOT cover PFU_IDLE→PFU_CHK (line 1361) or PFU_CHK→PFU_DENY
// (line 1368).  To hit those, the PFU must complete WITHOUT acc_fault,
// then the PMP deny (l2tlb_pfu_deny=1) must fire in the CHK state.
//
// Conditions:
//   * L2TLB entry must have R/W/X/A/D/V all set so l2tlb_pfu_flag_fault=0.
//   * pmp_mmu_flg4[0]=0 (R deny on port 4) and cp0 not in mach mode, so
//     l2tlb_pfu_deny=1.
//   * Issue PFU (pipe2) to a page that's already installed in L2TLB.
//
// This vseq is registered under its own name and selected by a new test
// wrapper test_mmu_l2tlb_cov_pfu_chk_deny.  It reuses the same PMP and
// sysmap sequences as the existing PFU deny test (pmp_flg_deny_pfu_seq
// + sysmap_pfu_safe_flag_seq).
// =============================================================================
class mmu_l2tlb_pfu_chk_via_clean_entry_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l2tlb_pfu_chk_via_clean_entry_vseq)

  function new(string name = "mmu_l2tlb_pfu_chk_via_clean_entry_vseq");
    super.new(name);
    m_va_base  = 39'h10_0000;
  endfunction

  protected task raw_pipe2(va_t va);
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va2      <= va[27:0];
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld <= 1'b0;
  endtask

  virtual task body();
    m_env_h   = get_env();
    m_lsu_vif = m_env_h.m_lsu.vif;
    m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null)
      `uvm_fatal(get_type_name(), "LSU VIF is null")
    `uvm_info(get_type_name(), "Starting PFU_CHK via clean entry vseq", UVM_LOW)

    // Phase 1: Issue DTLB loads to install fresh L2TLB entries whose PTE
    // has full R/W/X/A/D/V permissions — so that PFU's l2tlb_pfu_flag_fault
    // evaluates to 0 (no acc_fault from flag path) and the FSM can advance
    // PFU_IDLE→PFU_CHK.  The PMP agent's pmp_flg_deny_pfu_seq sets
    // pmp_mmu_flg4[0]=0, so once in PFU_CHK the l2tlb_pfu_deny=1 and the
    // FSM transitions PFU_CHK→PFU_DENY.
    for (int i = 0; i < 8; i++) begin
      raw_pipe0(va_page(i), 7'(7'd20 + i[6:0]), 1'b0);
      #100ns;
    end
    // Wait for PTW refill + L2TLB install to settle.
    #80000ns;

    // Phase 2: PFU pipe2 lookups against the installed L2TLB entries.
    // Reuse the first 4 VPNs to ensure L2TLB hits.
    for (int i = 0; i < 16; i++) begin
      raw_pipe2(va_page(i & 2'h3));
      #200ns;
    end

    #10000ns;
    `uvm_info(get_type_name(), "PFU_CHK via clean entry vseq complete", UVM_LOW)
  endtask
endclass

`endif
