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

`endif
