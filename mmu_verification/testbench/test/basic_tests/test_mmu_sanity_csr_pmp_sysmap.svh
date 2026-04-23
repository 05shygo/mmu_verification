// =============================================================================
// MMU UVM Verification — testbench/test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh
// Phase 3 (Batch 2): Sanity test — verifies that writing SATP(Sv39) raises
// mmu_xx_mmu_en, with PMP fully permissive and SysMap all-disabled.
//
// Execution order:
//   1. cp0_reg_rw_seq  : ICG_EN=1 → SATP(MODE=8/Sv39) → PTW_EN=1 → PRIV=M
//   2. pmp_flg_normal_seq      : all 8 PMP flag entries = 0 (allow all)
//   3. sysmap_region_setup_seq : all 8 regions disabled (pure page-table mode)
//
// Pass criteria (Phase 3):
//   mmu_xx_mmu_en sampled HIGH 5 clock cycles after the last sequence completes.
//   UVM_ERROR count = 0, UVM_FATAL count = 0.
// =============================================================================
`ifndef TEST_MMU_SANITY_CSR_PMP_SYSMAP_SVH
`define TEST_MMU_SANITY_CSR_PMP_SYSMAP_SVH

class test_mmu_sanity_csr_pmp_sysmap extends test_base;

  `uvm_component_utils(test_mmu_sanity_csr_pmp_sysmap)

  // CP0 virtual interface — used only to observe mmu_xx_mmu_en and wait clocks
  virtual cp0_if m_cp0_vif;

  // ── Constructor ───────────────────────────────────────────────────────────
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ── Build phase ───────────────────────────────────────────────────────────
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Retrieve the CP0 virtual interface set by tb_top.sv
    if (!uvm_config_db #(virtual cp0_if)::get(this, "", "CP0_VIF", m_cp0_vif))
      `uvm_fatal(get_type_name(),
                 "CP0_VIF not found in config_db — check uvm_config_db::set() in tb_top.sv")
  endfunction

  // ── Test body ─────────────────────────────────────────────────────────────
  virtual task run_test_body();
    cp0_reg_rw_seq          cp0_seq;
    pmp_flg_normal_seq      pmp_seq;
    sysmap_region_setup_seq sysmap_seq;

    `uvm_info(get_type_name(),
              "=== Phase 3 Sanity Test: CSR/PMP/SysMap STARTED ===", UVM_LOW)

    // ── Step 1: CP0 init — SATP(Sv39), ICG_EN, PTW_EN, PRIV=M ──────────────
    cp0_seq = cp0_reg_rw_seq::type_id::create("cp0_seq");
    if (!cp0_seq.randomize() with {
          satp_val[63:60] == 4'h8;  // Sv39 MODE — drives mmu_xx_mmu_en=1
          ptw_en          == 1'b1;
          icg_en          == 1'b1;
          priv_mode       == 2'b11; // M-mode
        })
      `uvm_fatal(get_type_name(), "cp0_reg_rw_seq randomize() failed")

    `uvm_info(get_type_name(),
              $sformatf("Step 1: cp0_reg_rw_seq — SATP=0x%016h, ptw_en=%0b, icg_en=%0b, priv=%2b",
                        cp0_seq.satp_val, cp0_seq.ptw_en, cp0_seq.icg_en, cp0_seq.priv_mode),
              UVM_MEDIUM)
    cp0_seq.start(m_env.m_cp0.m_sequencer);
    `uvm_info(get_type_name(), "Step 1: cp0_reg_rw_seq DONE", UVM_HIGH)

    // ── Step 2: PMP — set all 8 entries flag=0 (permit all accesses) ────────
    pmp_seq = pmp_flg_normal_seq::type_id::create("pmp_seq");
    `uvm_info(get_type_name(), "Step 2: pmp_flg_normal_seq — all flags=0 (allow-all)", UVM_MEDIUM)
    pmp_seq.start(m_env.m_pmp.m_sequencer);
    `uvm_info(get_type_name(), "Step 2: pmp_flg_normal_seq DONE", UVM_HIGH)

    // ── Step 3: SysMap — disable all 8 regions (bypass to page-table walk) ──
    sysmap_seq = sysmap_region_setup_seq::type_id::create("sysmap_seq");
    `uvm_info(get_type_name(), "Step 3: sysmap_region_setup_seq — all regions disabled", UVM_MEDIUM)
    sysmap_seq.start(m_env.m_sysmap_cfg.m_sequencer);
    `uvm_info(get_type_name(), "Step 3: sysmap_region_setup_seq DONE", UVM_HIGH)

    // ── Observation: wait 5 clock cycles for SATP write to propagate ────────
    repeat(5) @(posedge m_cp0_vif.clk_i);

    // ── Check: mmu_xx_mmu_en should be HIGH after Sv39 SATP write ───────────
    if (m_cp0_vif.mmu_xx_mmu_en === 1'b1) begin
      `uvm_info(get_type_name(),
                "PASS: mmu_xx_mmu_en=1 — MMU is active (Sv39 mode engaged)",
                UVM_LOW)
    end else begin
      `uvm_error(get_type_name(),
                 $sformatf("FAIL: mmu_xx_mmu_en=%0b — expected 1'b1 after SATP Sv39 write",
                           m_cp0_vif.mmu_xx_mmu_en))
    end

    `uvm_info(get_type_name(),
              "=== Phase 3 Sanity Test: CSR/PMP/SysMap COMPLETE ===", UVM_LOW)

    // Brief drain to let any in-flight monitor writes settle
    #50ns;
  endtask

endclass : test_mmu_sanity_csr_pmp_sysmap

`endif // TEST_MMU_SANITY_CSR_PMP_SYSMAP_SVH
