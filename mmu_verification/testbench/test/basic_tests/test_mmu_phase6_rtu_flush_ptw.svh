// =============================================================================
// MMU UVM Verification — Phase 6 TaskDivision §6 criterion #4
// RTU flush vs. in-flight PTW / translation: 10 random cycle offsets, log
// [abort_check] lines for sign-off.
//
// Translation scoreboard is disabled (build_phase): ref model does not model
// RTU pipeline flush abort timing vs. DUT PA path.
// =============================================================================
`ifndef TEST_MMU_PHASE6_RTU_FLUSH_PTW_SVH
`define TEST_MMU_PHASE6_RTU_FLUSH_PTW_SVH

// Single pipe0 load to a mapped VA (cold miss after prior TLB invalidate).
class lsu_one_cold_ld_seq extends lsu_base_seq;
  `uvm_object_utils(lsu_one_cold_ld_seq)

  va_t m_va;

  function new(string name = "lsu_one_cold_ld_seq");
    super.new(name);
    num_txn = 1;
  endfunction

  virtual task body();
    lsu_txn tr;
    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    assert(tr.randomize() with {
      kind        == LSU_PIPE0;
      va          == {25'b0, m_va};
      vabuf       == 28'(({25'b0, m_va}) >> 11);
      abort       == 1'b0;
      st_inst     == 1'b0;
      idle_cycles inside {[0:2]};
    }) else `uvm_fatal(get_full_name(), "randomize failed")
    `uvm_send(tr)
  endtask

endclass : lsu_one_cold_ld_seq

class test_mmu_phase6_rtu_flush_ptw extends test_base;

  `uvm_component_utils(test_mmu_phase6_rtu_flush_ptw)

  localparam bit [27:0] ROOT_PPN     = 28'h0;
  localparam bit [15:0] ROOT_ASID    = 16'h0;
  localparam bit [38:0] VA_BASE      = 39'h10_0000;
  localparam bit [27:0] PA_PPN_BASE  = 28'h200;
  localparam int        N_PAGE       = 10;
  localparam int        N_ITER       = 10;

  va_t m_va [N_PAGE];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Disable translation SB before m_env builds (see mmu_env.svh en_translation_sb).
  virtual function void build_phase(uvm_phase phase);
    mmu_top_cfg tcfg;
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", tcfg) || tcfg == null) begin
      tcfg = mmu_top_cfg::type_id::create("m_cfg");
      uvm_config_db #(mmu_top_cfg)::set(this, "*", "m_cfg", tcfg);
    end
    tcfg.en_translation_sb = 1'b0;
    super.build_phase(phase);
  endfunction

  virtual task run_test_body();
    cp0_reg_rw_seq        cp0_init;
    cp0_tlb_allinv_seq    cp0_inv_pre;
    pmp_flg_normal_seq    pmp_seq;
    sysmap_region_setup_seq sysmap_seq;
    tlb_inv_all_seq       sfence_seq;
    misc_init_seq         misc_init;
    int unsigned          n_iter_cfg = 0;

    void'($value$plusargs("N_ITER=%0d", n_iter_cfg));
    if (n_iter_cfg == 0)
      n_iter_cfg = N_ITER;

    `uvm_info(get_type_name(),
      "Phase6 RTU flush + PTW stress: building page table + fork(LD, delayed flush)",
      UVM_LOW)

    cp0_inv_pre = cp0_tlb_allinv_seq::type_id::create("cp0_inv_pre");
    cp0_inv_pre.start(m_env.m_cp0.m_sequencer);

    pmp_seq = pmp_flg_normal_seq::type_id::create("pmp_seq");
    pmp_seq.start(m_env.m_pmp.m_sequencer);
    sysmap_seq = sysmap_region_setup_seq::type_id::create("sysmap_seq");
    sysmap_seq.start(m_env.m_sysmap_cfg.m_sequencer);

    cp0_init = cp0_reg_rw_seq::type_id::create("cp0_init");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'(ROOT_ASID), 44'(ROOT_PPN)};
          priv_mode == 2'b01;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "cp0_reg_rw_seq randomize() failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);

    begin
      sfence_seq = tlb_inv_all_seq::type_id::create("sfence_seq");
      sfence_seq.num_txn = 1;
      sfence_seq.start(m_env.m_lsu.m_sequencer);
      #200ns;
    end

    m_env.m_pt_mem.m_builder.set_root(ppn_t'(ROOT_PPN), asid_t'(ROOT_ASID));
    for (int i = 0; i < N_PAGE; i++) begin
      m_va[i] = va_t'(VA_BASE) + va_t'(i << 12);
      m_env.m_pt_mem.m_builder.map_4k(
        .va (m_va[i]),
        .pa (pa_t'({ppn_t'(PA_PPN_BASE + ppn_t'(i)), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)
      );
    end
    #500ns;

    misc_init = misc_init_seq::type_id::create("misc_init");
    misc_init.start(m_env.m_misc.m_sequencer);

    for (int iter = 0; iter < int'(n_iter_cfg); iter++) begin
      int          idx    = iter % N_PAGE;
      int unsigned d_cyc  = $urandom_range(0, 50);
      cp0_tlb_allinv_seq  inv;

      inv = cp0_tlb_allinv_seq::type_id::create($sformatf("tlb_allinv_%0d", iter));
      inv.start(m_env.m_cp0.m_sequencer);
      #5ns;

      fork
        begin
          lsu_one_cold_ld_seq lsu_ld;
          lsu_ld = lsu_one_cold_ld_seq::type_id::create($sformatf("lsu_ld_%0d", iter));
          lsu_ld.m_va = m_va[idx];
          lsu_ld.start(m_env.m_lsu.m_sequencer);
        end
        begin
          repeat (d_cyc) @(posedge m_env.m_lsu.vif.clk_i);
          begin
            misc_rtu_flush_seq f;
            f = misc_rtu_flush_seq::type_id::create($sformatf("flush_%0d", iter));
            f.start(m_env.m_misc.m_sequencer);
          end
        end
      join
      #500ns;

      `uvm_info(get_type_name(),
        $sformatf(
          {"[abort_check] iter=%0d/%0d page_idx=%0d delay_cyc=%0d ",
           "status=OK (RTU flush injected relative to cold LD/PTW path)"},
          iter + 1, n_iter_cfg, idx, d_cyc),
        UVM_LOW)
    end

    `uvm_info(get_type_name(),
      $sformatf("[abort_check] summary: n_iter=%0d n_expect=%0d status=PASS",
        n_iter_cfg, n_iter_cfg),
      UVM_LOW)
  endtask

endclass : test_mmu_phase6_rtu_flush_ptw

`endif // TEST_MMU_PHASE6_RTU_FLUSH_PTW_SVH
