// =============================================================================
// MMU UVM — mmu_vseq_lib.svh (Phase 8)
// 14 virtual sequences per BuildPlan §8.7 + shared helpers.
// F ↔ VerificationPlan §6.3 row map: doc/phase8_m8_vseq_f_mapping.md
//
// Limitation: map_2m/map_1g remain stubs in page_table_builder — huge vseq is 4K-only.
// =============================================================================
`ifndef MMU_VSEQ_LIB_SVH
`define MMU_VSEQ_LIB_SVH

// ---------------------------------------------------------------------------
// Helper sequences (names distinct from test file local classes)
// ---------------------------------------------------------------------------
class mmu_vseq_ifu_rr_seq extends ifu_base_seq;
  `uvm_object_utils(mmu_vseq_ifu_rr_seq)
  va_t m_va_table[];
  int  m_table_size;
  function new(string name = "mmu_vseq_ifu_rr_seq"); super.new(name); endfunction
  virtual task body();
    ifu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      automatic int idx = (m_table_size > 0) ? (i % m_table_size) : 0;
      `uvm_create(tr)
      assert(tr.randomize() with {
        va[38:0] == m_va_table[idx];
        abort == 1'b0;
        idle_cycles inside {[0:3]};
      }) else `uvm_fatal(get_full_name(), "randomize failed")
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_lsu_rr_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_rr_seq)
  va_t       m_va_table[];
  int        m_table_size;
  lsu_kind_e m_kind;
  bit        m_st_inst;
  function new(string name = "mmu_vseq_lsu_rr_seq"); super.new(name);
    m_kind = LSU_PIPE0; m_st_inst = 1'b0; endfunction
  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      automatic int idx = (m_table_size > 0) ? (i % m_table_size) : 0;
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with {
        kind == m_kind;
        va == {25'b0, m_va_table[idx]};
        abort == 1'b0;
        st_inst == m_st_inst;
        idle_cycles inside {[0:3]};
        vabuf == 28'(({25'b0, m_va_table[idx]}) >> 11);
      }) else `uvm_fatal(get_full_name(), "randomize failed")
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_lsu_p2_short_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_p2_short_seq)
  function new(string name = "mmu_vseq_lsu_p2_short_seq"); super.new(name); endfunction
  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_PIPE2; idle_cycles inside {[0:3]}; })
        else `uvm_fatal(get_full_name(), "randomize failed")
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_lsu_stamo_short_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_stamo_short_seq)
  function new(string name = "mmu_vseq_lsu_stamo_short_seq"); super.new(name); endfunction
  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with { kind == LSU_STAMO; })
        else `uvm_fatal(get_full_name(), "randomize failed")
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_lsu_one_ld_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_one_ld_seq)
  va_t m_va;
  function new(string name = "mmu_vseq_lsu_one_ld_seq"); super.new(name); num_txn = 1; endfunction
  virtual task body();
    lsu_txn tr;
    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    assert(tr.randomize() with {
      kind == LSU_PIPE0;
      va == {25'b0, m_va};
      vabuf == 28'(({25'b0, m_va}) >> 11);
      abort == 1'b0;
      st_inst == 1'b0;
      idle_cycles inside {[0:2]};
    }) else `uvm_fatal(get_full_name(), "randomize failed")
    `uvm_send(tr)
  endtask
endclass

// One LSU sequence, round-robin pipe0/1/2 (UVM: single sequencer = one item stream).
class mmu_vseq_lsu_interleave3_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_interleave3_seq)
  va_t m_va_table[];
  int  m_table_size;
  function new(string name = "mmu_vseq_lsu_interleave3_seq"); super.new(name); endfunction
  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      int           idx  = (m_table_size > 0) ? (i % m_table_size) : 0;
      int           ph   = (i % 3);
      lsu_kind_e    knd  = (ph == 0) ? LSU_PIPE0 : (ph == 1) ? LSU_PIPE1 : LSU_PIPE2;
      bit [27:0]    va2_local;
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      va2_local = 28'(({25'b0, m_va_table[idx]}) >> 12);
      assert(tr.randomize() with {
        kind    == knd;
        va      == {25'b0, m_va_table[idx]};
        va2     == va2_local;
        vabuf   == 28'(({25'b0, m_va_table[idx]}) >> 11);
        abort   == 1'b0;
        st_inst == (knd == LSU_PIPE1);
        idle_cycles inside {[0:1]};
      }) else `uvm_fatal(get_full_name(), "randomize failed")
      `uvm_send(tr)
    end
  endtask
endclass

// ---------------------------------------------------------------------------
// mmu_base_vseq
// ---------------------------------------------------------------------------
class mmu_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(mmu_base_vseq)
  `uvm_declare_p_sequencer(mmu_virtual_sequencer)

  rand int unsigned num_txn;
  constraint c_num_txn_default { num_txn inside {[32:50000]}; }

  function new(string name = "mmu_base_vseq");
    super.new(name);
    // Allow test/plusarg override before randomize; keep finite default
    num_txn = 500;
  endfunction

  virtual function mmu_env get_env();
    uvm_component p;
    mmu_env e;
    p = p_sequencer.get_parent();
    if (p == null) `uvm_fatal(get_type_name(), "p_sequencer has null parent")
    if (!$cast(e, p))
      `uvm_fatal(get_type_name(), "p_sequencer parent is not mmu_env")
    return e;
  endfunction

  protected virtual function int unsigned _scale(int unsigned base, int unsigned pct);
    longint t = (longint'(base) * longint'(pct)) / longint'(100);
    if (t < 1) return 1;
    return int'(t);
  endfunction

  // CSR + PMP + SysMap + SATP + SFENCE + 4K table (canonical VA stride)
  protected virtual task vseq_bringup_sv39_4k(
    mmu_env      env,
    ppn_t        root_ppn,
    asid_t       root_asid,
    int          nmap,
    va_t         va_base,
    ppn_t        leaf_ppn0
  );
    cp0_tlb_allinv_seq     cp0_inv;
    pmp_flg_normal_seq     pmp;
    sysmap_region_setup_seq smap;
    cp0_reg_rw_seq         cpr;
    tlb_inv_all_seq        sf;
    int i;
    cp0_inv = cp0_tlb_allinv_seq::type_id::create("cp0_inv");
    cp0_inv.start(p_sequencer.cp0_sqr);
    pmp = pmp_flg_normal_seq::type_id::create("pmp");
    pmp.start(p_sequencer.pmp_sqr);
    smap = sysmap_region_setup_seq::type_id::create("smap");
    smap.start(p_sequencer.sysmap_sqr);
    cpr = cp0_reg_rw_seq::type_id::create("cpr");
    if (!cpr.randomize() with {
          satp_val  == {4'h8, 16'(root_asid), 44'(root_ppn)};
          priv_mode == 2'b01;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "cp0_reg_rw failed")
    cpr.start(p_sequencer.cp0_sqr);
    sf = tlb_inv_all_seq::type_id::create("sf");
    sf.num_txn = 1;
    sf.start(p_sequencer.lsu_sqr);
    #200ns;
    env.m_pt_mem.m_builder.set_root(root_ppn, root_asid);
    for (i = 0; i < nmap; i++) begin
      va_t v = va_t'(va_base) + va_t'(i << 12);
      env.m_pt_mem.m_builder.map_4k(
        .va(v), .pa(pa_t'({ppn_t'(leaf_ppn0 + ppn_t'(i)), 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    end
    #500ns;
  endtask

  // [MMU_VSEQ_TASKDIVISION#3] one-line summary (grep-friendly)
  virtual function void print_vseq_taskdiv3_summary(mmu_env env, string vseq_name);
    int unsigned txn_tot, n_miss, n_ptw;
    string mmu_sec;
    mmu_sec = (env.m_translation_sb != null)
              ? $sformatf(" trans_sb tot=%0d mis=%0d",
                env.m_translation_sb.m_total_checked, env.m_translation_sb.m_mismatch)
              : " trans_sb OFF";
    txn_tot = env.m_perf.n_ifu_req + env.m_perf.n_lsu_req[0] +
              env.m_perf.n_lsu_req[1] + env.m_perf.n_lsu_req[2];
    n_miss = env.m_perf.n_hpcp_dutlb_miss + env.m_perf.n_hpcp_iutlb_miss +
             env.m_perf.n_hpcp_jtlb_miss;
    n_ptw  = env.m_perf.n_ptw_mem_req;
    `uvm_info("MMU_VSEQ_STATS",
      $sformatf("[MMU_VSEQ_TASKDIVISION#3] vseq=%s  n_txn_total=%0d  n_miss_hpc=%0d  n_ptw_mem_req=%0d%s  (HPCP: du=%0d iu=%0d jt=%0d)",
        vseq_name, txn_tot, n_miss, n_ptw, mmu_sec,
        env.m_perf.n_hpcp_dutlb_miss, env.m_perf.n_hpcp_iutlb_miss,
        env.m_perf.n_hpcp_jtlb_miss),
      UVM_NONE)
    if (txn_tot == 0)
      `uvm_info("MMU_VSEQ_STATS", "[MMU_VSEQ_TASKDIVISION#3] note: n_txn_total=0 (check agent activity / TIMEOUT)", UVM_NONE)
  endfunction

  virtual task pre_body();
    int unsigned ncfg;
    if ($value$plusargs("VSEQ_NUM_TXN=%0d", ncfg) && ncfg > 0)
      num_txn = ncfg;
  endtask

  virtual task post_body();
    print_vseq_taskdiv3_summary(get_env(), get_type_name());
  endtask

  virtual task body();
  endtask
endclass

// ---------------------------------------------------------------------------
// 1) smoke
// ---------------------------------------------------------------------------
class mmu_smoke_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_smoke_vseq)
  function new(string name = "mmu_smoke_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    int nmap;
    mmu_vseq_ifu_rr_seq      ifs;
    mmu_vseq_lsu_rr_seq      p0, p1;
    va_t va_tbl[$];
    int i;
    nmap = (num_txn > 2000) ? 200 : (num_txn / 2);
    if (nmap < 8) nmap = 8;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h10_0000, 28'h200);
    va_tbl.delete();
    for (i = 0; i < nmap; i++) va_tbl.push_back(va_t'(39'h10_0000) + va_t'(i << 12));
    ifs = mmu_vseq_ifu_rr_seq::type_id::create("ifs");
    ifs.m_va_table = new[nmap];
    ifs.m_table_size = nmap;
    foreach (va_tbl[j]) ifs.m_va_table[j] = va_tbl[j];
    ifs.num_txn    = _scale(num_txn, 20);
    ifs.start(p_sequencer.ifu_sqr);
    p0 = mmu_vseq_lsu_rr_seq::type_id::create("p0");
    p0.m_va_table = new[nmap];
    p0.m_table_size = nmap;
    p0.m_kind = LSU_PIPE0; p0.m_st_inst = 1'b0;
    foreach (va_tbl[j]) p0.m_va_table[j] = va_tbl[j];
    p0.num_txn     = _scale(num_txn, 20);
    p0.start(p_sequencer.lsu_sqr);
    p1 = mmu_vseq_lsu_rr_seq::type_id::create("p1");
    p1.m_va_table = new[nmap];
    p1.m_table_size = nmap;
    p1.m_kind = LSU_PIPE1; p1.m_st_inst = 1'b1;
    foreach (va_tbl[j]) p1.m_va_table[j] = va_tbl[j];
    p1.num_txn     = _scale(num_txn, 5);
    p1.start(p_sequencer.lsu_sqr);
    #100000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 2) concurrent 3-pipe
// ---------------------------------------------------------------------------
class mmu_concurrent_3pipe_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_concurrent_3pipe_vseq)
  function new(string name = "mmu_concurrent_3pipe_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    int nmap, i;
    mmu_vseq_lsu_interleave3_seq seq_itr3;
    va_t va_tbl[$];
    nmap = (num_txn > 1000) ? 128 : 32;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h20_0000, 28'h300);
    for (i = 0; i < nmap; i++) va_tbl.push_back(va_t'(39'h20_0000) + va_t'(i << 12));
    seq_itr3 = mmu_vseq_lsu_interleave3_seq::type_id::create("seq_itr3");
    seq_itr3.m_va_table = new[nmap];
    seq_itr3.m_table_size = nmap;
    foreach (va_tbl[j]) seq_itr3.m_va_table[j] = va_tbl[j];
    seq_itr3.num_txn = int'(num_txn) / 2;
    if (seq_itr3.num_txn < 6) seq_itr3.num_txn = 6;
    seq_itr3.start(p_sequencer.lsu_sqr);
    #80000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 3) ptw thrash
// ---------------------------------------------------------------------------
class mmu_ptw_thrash_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_ptw_thrash_vseq)
  function new(string name = "mmu_ptw_thrash_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    int nmap;
    mmu_vseq_ifu_rr_seq      ifq;
    mmu_vseq_lsu_interleave3_seq seq_itr3;
    va_t va_tbl[$];
    nmap = (num_txn > 5000) ? 2000 : (num_txn * 2);
    if (nmap > 5000) nmap = 5000;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h0_4000_0000, 28'h2000);
    for (int i = 0; i < nmap; i++)
      va_tbl.push_back(va_t'(39'h0_4000_0000) + va_t'(i << 12));

    fork
      begin
        ifq = mmu_vseq_ifu_rr_seq::type_id::create("ptw_ifq");
        ifq.m_va_table   = new[nmap];
        ifq.m_table_size = nmap;
        foreach (va_tbl[j]) ifq.m_va_table[j] = va_tbl[j];
        ifq.num_txn = _scale(num_txn, 35);
        ifq.start(p_sequencer.ifu_sqr);
      end
      begin
        seq_itr3 = mmu_vseq_lsu_interleave3_seq::type_id::create("ptw_seq_itr3");
        seq_itr3.m_va_table   = new[nmap];
        seq_itr3.m_table_size = nmap;
        foreach (va_tbl[j]) seq_itr3.m_va_table[j] = va_tbl[j];
        seq_itr3.num_txn = _scale(num_txn, 100);
        if (seq_itr3.num_txn < 18) seq_itr3.num_txn = 18;
        seq_itr3.start(p_sequencer.lsu_sqr);
      end
    join
    #200000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 4) sfence during walk (parallel cold LD + delayed SFENCE mix)
// ---------------------------------------------------------------------------
class mmu_sfence_during_walk_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_sfence_during_walk_vseq)
  function new(string name = "mmu_sfence_during_walk_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    int npage = 32, it;
    mmu_vseq_lsu_one_ld_seq ld;
    sfence_vma_stress_seq     sfq;
    va_t m_va[];
    m_va = new[npage];
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, npage, 39'h0_5000_0000, 28'h5000);
    for (int j = 0; j < npage; j++) m_va[j] = va_t'(39'h0_5000_0000) + va_t'(j << 12);
    for (it = 0; it < 12; it++) begin
      int idx = it % npage;
      int unsigned d = $urandom_range(0, 20);
      fork
        begin
          ld = mmu_vseq_lsu_one_ld_seq::type_id::create($sformatf("sw_ld_%0d", it));
          ld.m_va = m_va[idx];
          ld.start(p_sequencer.lsu_sqr);
        end
        begin
          repeat (d) @(posedge env.m_lsu.vif.clk_i);
          sfq = sfence_vma_stress_seq::type_id::create($sformatf("sfq_%0d", it));
          sfq.num_txn = 3;
          sfq.start(p_sequencer.lsu_sqr);
        end
      join
      #2000ns;
    end
    #200000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 5) ASID context
// ---------------------------------------------------------------------------
class mmu_asid_context_switch_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_asid_context_switch_vseq)
  function new(string name = "mmu_asid_context_switch_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    cp0_satp_switch_seq sw1, sw0;
    mmu_vseq_lsu_one_ld_seq ld1;
    int aix;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, 16, 39'h0_6000_0000, 28'h6000);
    for (aix = 0; aix < 4; aix++) begin
      sw1 = cp0_satp_switch_seq::type_id::create("sw1");
      sw1.satp_sel = 0;
      sw1.satp_val = {4'h8, 16'((aix & 1) ? 16'h1 : 16'h0), 44'h0};
      sw1.start(p_sequencer.cp0_sqr);
      #100ns;
      ld1 = mmu_vseq_lsu_one_ld_seq::type_id::create("ld1");
      ld1.m_va = 39'h0_6000_0000;
      ld1.start(p_sequencer.lsu_sqr);
    end
    sw0 = cp0_satp_switch_seq::type_id::create("sw0");
    sw0.satp_val = {4'h8, 16'h0, 44'h0};
    sw0.start(p_sequencer.cp0_sqr);
    #50000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 6) huge page mix (4K-only; map_2m/1g stub)
// ---------------------------------------------------------------------------
class mmu_huge_page_mix_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_huge_page_mix_vseq)
  function new(string name = "mmu_huge_page_mix_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_ifu_rr_seq  ifq;
    mmu_vseq_lsu_rr_seq  p0, p1;
    va_t va_tbl[$];
    int nmap, j;
    `uvm_info(get_type_name(),
      "F-ID F6.x huge: 2M/1G not in builder — 4K IFU+LSU mix only (see page_table_builder map_2m/1g stub)", UVM_NONE)
    nmap = 32;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h0_7000_0000, 28'h7000);
    for (j = 0; j < nmap; j++) va_tbl.push_back(va_t'(39'h0_7000_0000) + va_t'(j << 12));
    ifq = mmu_vseq_ifu_rr_seq::type_id::create("ifq");
    ifq.m_va_table = new[nmap];
    ifq.m_table_size = nmap;
    foreach (va_tbl[jj]) ifq.m_va_table[jj] = va_tbl[jj];
    ifq.num_txn    = 40;
    ifq.start(p_sequencer.ifu_sqr);
    p0 = mmu_vseq_lsu_rr_seq::type_id::create("p0h");
    p0.m_va_table = new[nmap];
    p0.m_table_size = nmap; p0.m_kind = LSU_PIPE0; p0.m_st_inst = 0;
    foreach (va_tbl[jj]) p0.m_va_table[jj] = va_tbl[jj];
    p0.num_txn     = 40; p0.start(p_sequencer.lsu_sqr);
    p1 = mmu_vseq_lsu_rr_seq::type_id::create("p1h");
    p1.m_va_table = new[nmap];
    p1.m_table_size = nmap; p1.m_kind = LSU_PIPE1; p1.m_st_inst = 1;
    foreach (va_tbl[jj]) p1.m_va_table[jj] = va_tbl[jj];
    p1.num_txn     = 20; p1.start(p_sequencer.lsu_sqr);
    #80000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 7) RRPV aging (long random mix)
// ---------------------------------------------------------------------------
class mmu_rrpv_aging_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_rrpv_aging_vseq)
  function new(string name = "mmu_rrpv_aging_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_ifu_rr_seq  ifq;
    mmu_vseq_lsu_rr_seq  p0;
    va_t va_tbl[$];
    int nmap, j;
    nmap = 256;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h0_8000_0000, 28'h8000);
    for (j = 0; j < nmap; j++) va_tbl.push_back(va_t'(39'h0_8000_0000) + va_t'(j << 12));
    ifq = mmu_vseq_ifu_rr_seq::type_id::create("ifq");
    ifq.m_va_table = new[nmap];
    ifq.m_table_size = nmap;
    foreach (va_tbl[jj]) ifq.m_va_table[jj] = va_tbl[jj];
    ifq.num_txn     = _scale(num_txn, 50);
    ifq.start(p_sequencer.ifu_sqr);
    p0 = mmu_vseq_lsu_rr_seq::type_id::create("p0");
    p0.m_va_table = new[nmap];
    p0.m_table_size = nmap; p0.m_kind = LSU_PIPE0; p0.m_st_inst = 0;
    foreach (va_tbl[jj]) p0.m_va_table[jj] = va_tbl[jj];
    p0.num_txn     = _scale(num_txn, 50);
    p0.start(p_sequencer.lsu_sqr);
    #300000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 8) L2 TLB bank conflict (scatter VPN[20:12])
// ---------------------------------------------------------------------------
class mmu_l2tlb_bank_conflict_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_l2tlb_bank_conflict_vseq)
  function new(string name = "mmu_l2tlb_bank_conflict_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_lsu_one_ld_seq one;
    int b, c;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, 256, 39'h0_9000_0000, 28'h9000);
    for (c = 0; c < 200; c++) begin
      b = c % 256;
      one = mmu_vseq_lsu_one_ld_seq::type_id::create($sformatf("bk_%0d", c));
      one.m_va = va_t'(39'h0_9000_0000) + va_t'(b << 12);
      one.start(p_sequencer.lsu_sqr);
    end
    #150000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 9) SATP hotswap
// ---------------------------------------------------------------------------
class mmu_satp_hotswap_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_satp_hotswap_vseq)
  function new(string name = "mmu_satp_hotswap_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    cp0_satp_switch_seq  swa;
    cp0_satp_sel_toggle_seq tgl;
    mmu_vseq_lsu_one_ld_seq  ld1;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, 8, 39'h0_A000_0000, 28'hA000);
    swa = cp0_satp_switch_seq::type_id::create("swa");
    swa.satp_val = {4'h8, 16'h0, 44'h0};
    swa.satp_sel = 0;
    swa.start(p_sequencer.cp0_sqr);
    #50ns;
    tgl = cp0_satp_sel_toggle_seq::type_id::create("tgl");
    tgl.n_toggles = 4;
    tgl.start(p_sequencer.cp0_sqr);
    ld1 = mmu_vseq_lsu_one_ld_seq::type_id::create("ld1");
    ld1.m_va = 39'h0_A000_0000;
    ld1.start(p_sequencer.lsu_sqr);
    #80000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 10) all ports
// ---------------------------------------------------------------------------
class mmu_stress_all_ports_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_stress_all_ports_vseq)
  function new(string name = "mmu_stress_all_ports_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_ifu_rr_seq  ifq;
    mmu_vseq_lsu_interleave3_seq seq_itr3;
    mmu_vseq_lsu_stamo_short_seq st;
    misc_init_seq        mi;
    va_t va_tbl[$];
    int nmap, j;
    nmap = 16;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h0_B000_0000, 28'hB000);
    for (j = 0; j < nmap; j++) va_tbl.push_back(va_t'(39'h0_B000_0000) + va_t'(j << 12));
    mi = misc_init_seq::type_id::create("mi");
    mi.start(p_sequencer.misc_sqr);
    fork
      begin
        ifq = mmu_vseq_ifu_rr_seq::type_id::create("ifq");
        ifq.m_va_table = new[nmap];
        ifq.m_table_size = nmap;
        foreach (va_tbl[jj]) ifq.m_va_table[jj] = va_tbl[jj];
        ifq.num_txn    = 40;
        ifq.start(p_sequencer.ifu_sqr);
      end
      begin
        seq_itr3 = mmu_vseq_lsu_interleave3_seq::type_id::create("seq_itr3");
        seq_itr3.m_va_table = new[nmap];
        seq_itr3.m_table_size = nmap;
        foreach (va_tbl[jj]) seq_itr3.m_va_table[jj] = va_tbl[jj];
        seq_itr3.num_txn     = 60;
        seq_itr3.start(p_sequencer.lsu_sqr);
      end
    join
    st = mmu_vseq_lsu_stamo_short_seq::type_id::create("st");
    st.num_txn     = 10;
    st.start(p_sequencer.lsu_sqr);
    #120000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 11) power gating (reachable misc — no DUT power gate in TB)
// ---------------------------------------------------------------------------
class mmu_power_gating_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_power_gating_vseq)
  function new(string name = "mmu_power_gating_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    misc_init_seq  mi;
    misc_hpcp_enable_seq hpc;
    mmu_vseq_lsu_one_ld_seq  ld1;
    `uvm_info(get_type_name(), "F11 power: DUT has no true TB power-gate; misc_init+HPCP+short LD (reachability).", UVM_NONE)
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, 4, 39'h0_C000_0000, 28'hC000);
    mi  = misc_init_seq::type_id::create("mi");
    hpc = misc_hpcp_enable_seq::type_id::create("hpc");
    mi.start(p_sequencer.misc_sqr);
    hpc.start(p_sequencer.misc_sqr);
    ld1 = mmu_vseq_lsu_one_ld_seq::type_id::create("ld1");
    ld1.m_va = 39'h0_C000_0000;
    ld1.start(p_sequencer.lsu_sqr);
    #50000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 12) reset mid-txn — RTU flush (not full cpurst_b)
// ---------------------------------------------------------------------------
class mmu_reset_midtransaction_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_reset_midtransaction_vseq)
  function new(string name = "mmu_reset_midtransaction_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_lsu_one_ld_seq ld;
    misc_rtu_flush_seq fl;
    int k;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, 8, 39'h0_D000_0000, 28'hD000);
    for (k = 0; k < 8; k++) begin
      `uvm_info(get_type_name(), "F12: soft reset path = RTU flush + cold LD (not full TB reset).", UVM_NONE)
      fork
        begin
          ld = mmu_vseq_lsu_one_ld_seq::type_id::create("ldm");
          ld.m_va = va_t'(39'h0_D000_0000) + va_t'(k << 12);
          ld.start(p_sequencer.lsu_sqr);
        end
        begin
          repeat (k) @(posedge env.m_lsu.vif.clk_i);
          fl = misc_rtu_flush_seq::type_id::create("fl");
          fl.start(p_sequencer.misc_sqr);
        end
      join
    end
    #100000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 13) error rain: PTE faults + recovery remap (bus_error knob optional)
// ---------------------------------------------------------------------------
class mmu_error_rain_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_error_rain_vseq)
  function new(string name = "mmu_error_rain_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_lsu_one_ld_seq  ld1;
    mmu_vseq_ifu_rr_seq     ifc;
    mmu_vseq_lsu_rr_seq     p0;
    va_t v_bad;
    va_t va_g[2];
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, 8, 39'h0_E000_0000, 28'hE000);
    v_bad = 39'h0_E000_2000;
    // PTE inject + immediate remap = recoverable fault path in shadow PT (no SB check on the transient bad PTE).
    env.m_pt_mem.m_builder.inject_fault(v_bad, "A_OFF");
    env.m_pt_mem.m_builder.map_4k(
      .va(v_bad), .pa(pa_t'({ppn_t'(28'hE002), 12'h000})),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    va_g[0] = 39'h0_E000_0000;
    va_g[1] = 39'h0_E000_1000;
    for (int t = 0; t < 2; t++) begin
      ifc = mmu_vseq_ifu_rr_seq::type_id::create($sformatf("ifc_%0d", t));
      ifc.m_va_table   = new[1];
      ifc.m_va_table[0] = va_g[t];
      ifc.m_table_size = 1;
      ifc.num_txn        = 6;
      ifc.start(p_sequencer.ifu_sqr);
      p0 = mmu_vseq_lsu_rr_seq::type_id::create($sformatf("p0_%0d", t));
      p0.m_va_table   = new[1];
      p0.m_va_table[0] = va_g[t];
      p0.m_table_size  = 1; p0.m_kind = LSU_PIPE0; p0.m_st_inst = 0;
      p0.num_txn        = 5;
      p0.start(p_sequencer.lsu_sqr);
    end
    ld1 = mmu_vseq_lsu_one_ld_seq::type_id::create("ld1");
    ld1.m_va = v_bad;
    ld1.start(p_sequencer.lsu_sqr);
    `uvm_info(get_type_name(),
      "F13: bus_error rate left at 0 (ref/PTW sync); A_OFF inject+remap + mapped IFU/LSU mix.", UVM_NONE)
    #100000ns;
  endtask
endclass

// ---------------------------------------------------------------------------
// 14) perf bench
// ---------------------------------------------------------------------------
class mmu_perf_bench_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_perf_bench_vseq)
  function new(string name = "mmu_perf_bench_vseq"); super.new(name); endfunction
  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_ifu_rr_seq  ifq;
    mmu_vseq_lsu_rr_seq  p0;
    va_t va_tbl[$];
    int nmap, j;
    nmap = 200;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h0_F000_0000, 28'hF000);
    for (j = 0; j < nmap; j++) va_tbl.push_back(va_t'(39'h0_F000_0000) + va_t'(j << 12));
    ifq = mmu_vseq_ifu_rr_seq::type_id::create("ifq");
    ifq.m_va_table = new[nmap];
    ifq.m_table_size = nmap;
    foreach (va_tbl[jj]) ifq.m_va_table[jj] = va_tbl[jj];
    ifq.num_txn    = _scale(num_txn, 100);
    ifq.start(p_sequencer.ifu_sqr);
    p0 = mmu_vseq_lsu_rr_seq::type_id::create("p0");
    p0.m_va_table = new[nmap];
    p0.m_table_size = nmap; p0.m_kind = LSU_PIPE0; p0.m_st_inst = 0;
    foreach (va_tbl[jj]) p0.m_va_table[jj] = va_tbl[jj];
    p0.num_txn     = _scale(num_txn, 100);
    p0.start(p_sequencer.lsu_sqr);
    #500000ns;
  endtask
endclass

`endif // MMU_VSEQ_LIB_SVH
