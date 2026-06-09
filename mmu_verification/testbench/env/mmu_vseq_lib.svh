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
function automatic bit [63:0] mmu_vseq_va64(input va_t va);
  return {{(64-VA_WIDTH){va[VA_WIDTH-1]}}, va};
endfunction

function automatic bit [27:0] mmu_vseq_va2(input va_t va);
  bit [63:0] va64;
  va64 = mmu_vseq_va64(va);
  return va64[39:12];
endfunction

function automatic bit [27:0] mmu_vseq_vabuf(input va_t va);
  bit [63:0] va64;
  va64 = mmu_vseq_va64(va);
  return va64[38:11];
endfunction

class mmu_vseq_ifu_rr_seq extends ifu_base_seq;
  `uvm_object_utils(mmu_vseq_ifu_rr_seq)
  va_t m_va_table[];
  int  m_table_size;
  bit  m_zero_idle;
  function new(string name = "mmu_vseq_ifu_rr_seq"); super.new(name); m_zero_idle = 1'b0; endfunction
  virtual task body();
    ifu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      automatic int idx = (m_table_size > 0) ? (i % m_table_size) : 0;
      `uvm_create(tr)
      if (m_zero_idle) begin
        assert(tr.randomize() with {
          va[38:0] == m_va_table[idx];
          abort == 1'b0;
          idle_cycles == 0;
        }) else `uvm_fatal(get_full_name(), "randomize failed")
      end else begin
        assert(tr.randomize() with {
          va[38:0] == m_va_table[idx];
          abort == 1'b0;
          idle_cycles inside {[0:3]};
        }) else `uvm_fatal(get_full_name(), "randomize failed")
      end
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
  bit        m_zero_idle;
  function new(string name = "mmu_vseq_lsu_rr_seq"); super.new(name);
    m_kind = LSU_PIPE0; m_st_inst = 1'b0; m_zero_idle = 1'b0; endfunction
  virtual task body();
    lsu_txn tr;
    for (int i = 0; i < int'(num_txn); i++) begin
      automatic int idx = (m_table_size > 0) ? (i % m_table_size) : 0;
      automatic bit [63:0] va64 = mmu_vseq_va64(m_va_table[idx]);
      automatic bit [27:0] va2_local = mmu_vseq_va2(m_va_table[idx]);
      automatic bit [27:0] vabuf_local = mmu_vseq_vabuf(m_va_table[idx]);
      // Phase12 PTW/DTLB pressure tests model a small set of in-flight LSU slots.
      // Leaving iid fully random creates non-architectural alias/noise on the
      // busy/wakeup + expt_CAM ownership path. Keep pipe0/pipe1 on stable,
      // low-collision slot ids while still varying age/order with i.
      automatic bit [6:0] slot_id;
      slot_id = ((i * 2) + ((m_kind == LSU_PIPE1) ? 1 : 0)) % 12;
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      if (m_zero_idle) begin
        assert(tr.randomize() with {
          kind == m_kind;
          va == va64;
          va2 == va2_local;
          id == slot_id;
          abort == 1'b0;
          st_inst == m_st_inst;
          idle_cycles == 0;
          vabuf == vabuf_local;
        }) else `uvm_fatal(get_full_name(), "randomize failed")
      end else begin
        assert(tr.randomize() with {
          kind == m_kind;
          va == va64;
          va2 == va2_local;
          id == slot_id;
          abort == 1'b0;
          st_inst == m_st_inst;
          idle_cycles inside {[0:3]};
          vabuf == vabuf_local;
        }) else `uvm_fatal(get_full_name(), "randomize failed")
      end
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_lsu_fixed_inv_va_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_fixed_inv_va_seq)

  bit [26:0] m_inv_va;
  bit [15:0] m_inv_asid;
  bit        m_allow_busy;
  int unsigned m_idle_cycles;

  function new(string name = "mmu_vseq_lsu_fixed_inv_va_seq");
    super.new(name);
    num_txn = 1;
    m_inv_va = '0;
    m_inv_asid = 16'h0;
    m_allow_busy = 1'b0;
    m_idle_cycles = 0;
  endfunction

  virtual task body();
    lsu_txn tr;
    bit [26:0] va_local;
    bit [15:0] asid_local;
    int unsigned idle_local;

    va_local = m_inv_va;
    asid_local = m_inv_asid;
    idle_local = m_idle_cycles;
    for (int unsigned i = 0; i < num_txn; i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with {
        kind        == LSU_INV;
        inv_kind    == INV_VA_ALL;
        inv_va      == va_local;
        inv_asid    == asid_local;
        idle_cycles == int'(idle_local);
      }) else `uvm_fatal(get_full_name(), "fixed INV_VA randomize failed")
      tr.inv_allow_busy = m_allow_busy;
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_lsu_fixed_inv_asid_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_lsu_fixed_inv_asid_seq)

  bit [15:0] m_inv_asid;
  bit [26:0] m_inv_va;
  bit        m_allow_busy;
  int unsigned m_idle_cycles;

  function new(string name = "mmu_vseq_lsu_fixed_inv_asid_seq");
    super.new(name);
    num_txn = 1;
    m_inv_asid = 16'h1234;
    m_inv_va = '0;
    m_allow_busy = 1'b0;
    m_idle_cycles = 0;
  endfunction

  virtual task body();
    lsu_txn tr;
    bit [15:0] asid_local;
    bit [26:0] va_local;
    int unsigned idle_local;

    asid_local = m_inv_asid;
    va_local = m_inv_va;
    idle_local = m_idle_cycles;
    for (int unsigned i = 0; i < num_txn; i++) begin
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      assert(tr.randomize() with {
        kind        == LSU_INV;
        inv_kind    == INV_ASID_ALL;
        inv_va      == va_local;
        inv_asid    == asid_local;
        idle_cycles == int'(idle_local);
      }) else `uvm_fatal(get_full_name(), "fixed INV_ASID randomize failed")
      tr.inv_allow_busy = m_allow_busy;
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
    bit [63:0] va64;
    bit [27:0] vabuf_local;
    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    va64 = mmu_vseq_va64(m_va);
    vabuf_local = mmu_vseq_vabuf(m_va);
    assert(tr.randomize() with {
      kind == LSU_PIPE0;
      va == va64;
      vabuf == vabuf_local;
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
      bit [6:0]     slot_id;
      bit [63:0]    va64;
      bit [27:0]    va2_local;
      bit [27:0]    vabuf_local;
      slot_id = i % 12;
      `uvm_create(tr)
      tr.c_kind_default.constraint_mode(0);
      va64 = mmu_vseq_va64(m_va_table[idx]);
      va2_local = mmu_vseq_va2(m_va_table[idx]);
      vabuf_local = mmu_vseq_vabuf(m_va_table[idx]);
      assert(tr.randomize() with {
        kind    == knd;
        va      == va64;
        id      == slot_id;
        va2     == va2_local;
        vabuf   == vabuf_local;
        abort   == 1'b0;
        st_inst == (knd == LSU_PIPE1);
        idle_cycles inside {[0:1]};
      }) else `uvm_fatal(get_full_name(), "randomize failed")
      `uvm_send(tr)
    end
  endtask
endclass

class mmu_vseq_l2tlb_fine_lsu_mix_seq extends lsu_base_seq;
  `uvm_object_utils(mmu_vseq_l2tlb_fine_lsu_mix_seq)

  va_t m_va_table[];
  int  m_table_size;
  bit  m_enable_busy_inv;
  int unsigned m_inv_period;
  int unsigned m_inv_limit;

  function new(string name = "mmu_vseq_l2tlb_fine_lsu_mix_seq");
    super.new(name);
    m_enable_busy_inv = 1'b0;
    m_inv_period = 8;
    m_inv_limit = 4;
  endfunction

  protected task send_pipe_req(
    input lsu_kind_e kind_sel,
    input va_t       va,
    input bit        is_store,
    input bit [6:0]  req_id
  );
    lsu_txn tr;
    bit [63:0] va64;
    bit [27:0] va2_local;
    bit [27:0] vabuf_local;

    va64        = mmu_vseq_va64(va);
    va2_local   = mmu_vseq_va2(va);
    vabuf_local = mmu_vseq_vabuf(va);
    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    assert(tr.randomize() with {
      kind        == kind_sel;
      va          == va64;
      va2         == va2_local;
      vabuf       == vabuf_local;
      id          == req_id;
      abort       == 1'b0;
      st_inst     == is_store;
      idle_cycles == 0;
    }) else `uvm_fatal(get_full_name(), "send_pipe_req randomize failed")
    `uvm_send(tr)
  endtask

  protected task send_busy_inv(
    input va_t              va,
    input lsu_inv_kind_e    inv_kind_sel
  );
    lsu_txn tr;
    bit [27:0] va2_local;

    va2_local = mmu_vseq_va2(va);
    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    assert(tr.randomize() with {
      kind        == LSU_INV;
      inv_kind    == inv_kind_sel;
      inv_va      == va2_local[26:0];
      inv_asid    == 16'h0000;
      idle_cycles == 0;
    }) else `uvm_fatal(get_full_name(), "send_busy_inv randomize failed")
    tr.inv_allow_busy = 1'b1;
    `uvm_send(tr)
  endtask

  virtual task body();
    int unsigned nburst;

    nburst = (num_txn < 32) ? 32 : num_txn;
    for (int unsigned i = 0; i < nburst; i++) begin
      int unsigned idx0;
      int unsigned idx1;
      int unsigned idx2;
      int unsigned idx3;
      bit [6:0] load_id;
      bit [6:0] store_id;
      lsu_inv_kind_e inv_kind_sel;

      idx0 = (m_table_size > 0) ? ((i * 4 + 0) % m_table_size) : 0;
      idx1 = (m_table_size > 0) ? ((i * 4 + 1) % m_table_size) : 0;
      idx2 = (m_table_size > 0) ? ((i * 4 + 2) % m_table_size) : 0;
      idx3 = (m_table_size > 0) ? ((i * 4 + 3) % m_table_size) : 0;
      load_id  = i % 12;
      store_id = (i + 6) % 12;
      inv_kind_sel = (i[0]) ? INV_ASID_ALL : INV_VA_ASID;

      send_pipe_req(LSU_PIPE2, m_va_table[idx0], 1'b0, i % 12);
      send_pipe_req(LSU_PIPE0, m_va_table[idx1], 1'b0, load_id);
      send_pipe_req(LSU_PIPE1, m_va_table[idx2], 1'b1, store_id);
      if (m_enable_busy_inv && (i < m_inv_limit)
          && ((m_inv_period == 0) || ((i % m_inv_period) == 0)))
        send_busy_inv(m_va_table[idx3], inv_kind_sel);
    end
  endtask
endclass

class mmu_vseq_l2tlb_cp0_tlbp_burst_seq extends cp0_base_seq;
  `uvm_object_utils(mmu_vseq_l2tlb_cp0_tlbp_burst_seq)

  int unsigned m_num_ops;
  int unsigned m_start_delay_cycles;
  int unsigned m_between_ops_cycles;

  function new(string name = "mmu_vseq_l2tlb_cp0_tlbp_burst_seq");
    super.new(name);
    m_num_ops = 16;
    m_start_delay_cycles = 0;
    m_between_ops_cycles = 0;
  endfunction

  protected task write_cp0_reg(bit [1:0] reg_num, bit [63:0] wdata);
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = CP0_WRITE_REG;
    tr.reg_num = reg_num;
    tr.wdata   = wdata;
    `uvm_send(tr)
  endtask

  protected task set_cskyee(bit enable);
    cp0_txn tr;
    `uvm_create(tr)
    tr.op     = CP0_SET_CSKYEE;
    tr.cskyee = enable;
    `uvm_send(tr)
  endtask

  virtual task body();
    if (m_start_delay_cycles > 0)
      repeat (m_start_delay_cycles) #1ns;
    $display("[L2TLB_CP0_TLBP_BURST] event=start t=%0t ops=%0d delay_1ns_steps=%0d between_1ns_steps=%0d",
             $time, m_num_ops, m_start_delay_cycles, m_between_ops_cycles);
    set_cskyee(1'b1);
    $display("[L2TLB_CP0_TLBP_BURST] event=cskyee_on t=%0t", $time);
    for (int unsigned i = 0; i < m_num_ops; i++) begin
      bit [26:0] vpn;
      bit [63:0] meh;

      vpn = 27'h0c0000 + i[26:0];
      meh = {18'b0, vpn, 3'b001, 16'h0000};
      $display("[L2TLB_CP0_TLBP_BURST] event=op_begin t=%0t op=%0d vpn=0x%07h meh=0x%016h",
               $time, i, vpn, meh);
      write_cp0_reg(2'd2, meh);
      $display("[L2TLB_CP0_TLBP_BURST] event=mcir_issue t=%0t op=%0d", $time, i);
      write_cp0_reg(2'd3, 64'h0000_0000_8000_0000);
      $display("[L2TLB_CP0_TLBP_BURST] event=op_done t=%0t op=%0d", $time, i);
      if (m_between_ops_cycles > 0)
        repeat (m_between_ops_cycles) #1ns;
    end
    $display("[L2TLB_CP0_TLBP_BURST] event=done t=%0t ops=%0d", $time, m_num_ops);
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

class mmu_inv_asid_hit_directed_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_inv_asid_hit_directed_vseq)

  function new(string name = "mmu_inv_asid_hit_directed_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mmu_env env = get_env();
    cp0_l2tlb_inv_asid_directed_probe_seq cp0_probe;
    mmu_vseq_lsu_fixed_inv_asid_seq lsu_inv;

    cp0_probe = cp0_l2tlb_inv_asid_directed_probe_seq::type_id::create("inv_asid_hit_setup");
    cp0_probe.do_write = 1'b1;
    cp0_probe.global_entry = 1'b0;
    cp0_probe.expect_hit = 1'b1;
    cp0_probe.start(p_sequencer.cp0_sqr);

    lsu_inv = mmu_vseq_lsu_fixed_inv_asid_seq::type_id::create("inv_asid_hit_lsu_inv");
    lsu_inv.m_inv_asid = 16'h1234;
    lsu_inv.m_allow_busy = 1'b0;
    lsu_inv.start(p_sequencer.lsu_sqr);
    repeat (4) @(posedge env.m_lsu.vif.clk_i);

    cp0_probe = cp0_l2tlb_inv_asid_directed_probe_seq::type_id::create("inv_asid_hit_post_probe");
    cp0_probe.do_write = 1'b0;
    cp0_probe.global_entry = 1'b0;
    cp0_probe.expect_hit = 1'b0;
    cp0_probe.start(p_sequencer.cp0_sqr);

    #1000ns;
  endtask
endclass

class mmu_inv_asid_global_directed_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_inv_asid_global_directed_vseq)

  function new(string name = "mmu_inv_asid_global_directed_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mmu_env env = get_env();
    cp0_l2tlb_inv_asid_directed_probe_seq cp0_probe;
    mmu_vseq_lsu_fixed_inv_asid_seq lsu_inv;

    cp0_probe = cp0_l2tlb_inv_asid_directed_probe_seq::type_id::create("inv_asid_global_setup");
    cp0_probe.do_write = 1'b1;
    cp0_probe.global_entry = 1'b1;
    cp0_probe.expect_hit = 1'b1;
    cp0_probe.start(p_sequencer.cp0_sqr);

    lsu_inv = mmu_vseq_lsu_fixed_inv_asid_seq::type_id::create("inv_asid_global_lsu_inv");
    lsu_inv.m_inv_asid = 16'h1234;
    lsu_inv.m_allow_busy = 1'b0;
    lsu_inv.start(p_sequencer.lsu_sqr);
    repeat (4) @(posedge env.m_lsu.vif.clk_i);

    cp0_probe = cp0_l2tlb_inv_asid_directed_probe_seq::type_id::create("inv_asid_global_post_probe");
    cp0_probe.do_write = 1'b0;
    cp0_probe.global_entry = 1'b1;
    cp0_probe.expect_hit = 1'b1;
    cp0_probe.start(p_sequencer.cp0_sqr);

    #1000ns;
  endtask
endclass

class mmu_inv_asid_overlap_directed_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_inv_asid_overlap_directed_vseq)

  function new(string name = "mmu_inv_asid_overlap_directed_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mmu_env env = get_env();
    cp0_tlb_allinv_seq cp0_inv;
    mmu_vseq_lsu_fixed_inv_asid_seq lsu_inv;

    fork
      begin
        cp0_inv = cp0_tlb_allinv_seq::type_id::create("overlap_cp0_invall");
        cp0_inv.start(p_sequencer.cp0_sqr);
      end
      begin
        repeat (8) @(posedge env.m_lsu.vif.clk_i);
        lsu_inv = mmu_vseq_lsu_fixed_inv_asid_seq::type_id::create("overlap_lsu_inv_asid");
        lsu_inv.m_inv_asid = 16'h1234;
        lsu_inv.m_allow_busy = 1'b1;
        lsu_inv.start(p_sequencer.lsu_sqr);
      end
    join

    #2000ns;
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
// 8a.1) L2TLB ReqQ/arbiter fine-grain overlap stimulus
// ---------------------------------------------------------------------------
class mmu_l2tlb_reqq_arb_fine_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_l2tlb_reqq_arb_fine_vseq)

  function new(string name = "mmu_l2tlb_reqq_arb_fine_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_ifu_rr_seq ifq;
    mmu_vseq_l2tlb_fine_lsu_mix_seq lsu_mix;
    mmu_vseq_l2tlb_cp0_tlbp_burst_seq cp0_tlbp;
    int unsigned nmap;
    int unsigned n_ifu;
    int unsigned n_lsu;
    va_t va_tbl[$];

    nmap = 256;
    vseq_bringup_sv39_4k(env, 28'h0, 16'h0, nmap, 39'h0_C000_0000, 28'hC000);
    if ((env.m_ptw_mem != null) && (env.m_ptw_mem.m_responder != null)) begin
      env.m_ptw_mem.m_responder.clear_directed_controls();
      env.m_ptw_mem.m_responder.set_delay_range(64, 160);
    end

    for (int unsigned i = 0; i < nmap; i++)
      va_tbl.push_back(va_t'(39'h0_C000_0000) + va_t'(i << 12));

    n_ifu = (num_txn < 64) ? 64 : num_txn;
    n_lsu = (num_txn < 64) ? 64 : num_txn;
    fork
      begin
        ifq = mmu_vseq_ifu_rr_seq::type_id::create("fine_ifq");
        ifq.m_va_table = new[nmap];
        ifq.m_table_size = nmap;
        ifq.m_zero_idle = 1'b1;
        foreach (va_tbl[j]) ifq.m_va_table[j] = va_tbl[j];
        ifq.num_txn = n_ifu;
        ifq.start(p_sequencer.ifu_sqr);
      end
      begin
        lsu_mix = mmu_vseq_l2tlb_fine_lsu_mix_seq::type_id::create("fine_lsu_mix");
        lsu_mix.m_va_table = new[nmap];
        lsu_mix.m_table_size = nmap;
        foreach (va_tbl[j]) lsu_mix.m_va_table[j] = va_tbl[j];
        lsu_mix.num_txn = n_lsu;
        lsu_mix.m_enable_busy_inv = 1'b0;
        lsu_mix.start(p_sequencer.lsu_sqr);
      end
      begin
        cp0_tlbp = mmu_vseq_l2tlb_cp0_tlbp_burst_seq::type_id::create("fine_cp0_tlbp_burst");
        cp0_tlbp.m_num_ops = 64;
        cp0_tlbp.m_start_delay_cycles = 36581;
        cp0_tlbp.m_between_ops_cycles = 0;
        cp0_tlbp.start(p_sequencer.cp0_sqr);
      end
    join

    #80000ns;
    if ((env.m_ptw_mem != null) && (env.m_ptw_mem.m_responder != null))
      env.m_ptw_mem.m_responder.set_delay_range(1, 8);

    fork
      begin
        ifq = mmu_vseq_ifu_rr_seq::type_id::create("fine_tlbop_ifq");
        ifq.m_va_table = new[nmap];
        ifq.m_table_size = nmap;
        ifq.m_zero_idle = 1'b1;
        foreach (va_tbl[j]) ifq.m_va_table[j] = va_tbl[j];
        ifq.num_txn = 16;
        ifq.start(p_sequencer.ifu_sqr);
      end
      begin
        lsu_mix = mmu_vseq_l2tlb_fine_lsu_mix_seq::type_id::create("fine_tlbop_lsu_mix");
        lsu_mix.m_va_table = new[nmap];
        lsu_mix.m_table_size = nmap;
        foreach (va_tbl[j]) lsu_mix.m_va_table[j] = va_tbl[j];
        lsu_mix.num_txn = 16;
        lsu_mix.m_enable_busy_inv = 1'b1;
        lsu_mix.m_inv_period = 4;
        lsu_mix.m_inv_limit = 4;
        lsu_mix.start(p_sequencer.lsu_sqr);
      end
    join

    #120000ns;
    if ((env.m_ptw_mem != null) && (env.m_ptw_mem.m_responder != null))
      env.m_ptw_mem.m_responder.set_delay_range(1, 8);
  endtask
endclass

// ---------------------------------------------------------------------------
// 8b) L2TLB exact hash directed stimulus
// ---------------------------------------------------------------------------
class mmu_l2tlb_hash_directed_vseq extends mmu_base_vseq;
  `uvm_object_utils(mmu_l2tlb_hash_directed_vseq)

  function new(string name = "mmu_l2tlb_hash_directed_vseq");
    super.new(name);
  endfunction

  protected function va_t make_hash_va(
    input logic [1:0] selector,
    input logic [7:0] vpn7_0,
    input logic [7:0] vpn15_8,
    input logic [1:0] vpn17_16,
    input logic [6:0] vpn26_20
  );
    vpn_t vpn;
    vpn = '0;
    vpn[26:20] = vpn26_20;
    vpn[19:18] = selector;
    vpn[17:16] = vpn17_16;
    vpn[15:8] = vpn15_8;
    vpn[7:0] = vpn7_0;
    return va_t'({vpn, 12'h000});
  endfunction

  protected task add_hash_page(
    input mmu_env env,
    input va_t    va,
    input ppn_t   ppn
  );
    vpn_t vpn;
    vpn = vpn_t'(va >> 12);
    env.m_pt_mem.m_builder.map_4k(
      .va(va),
      .pa(pa_t'({ppn, 12'h000})),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)
    );
    `uvm_info(get_type_name(),
      $sformatf("[L2TLB_HASH_DIRECTED] map va=0x%010h vpn=0x%07h selector=0x%0h ppn=0x%07h idx_bus=0x%016h size_bus=0x%06h bank4k=0x%02h",
        va, vpn, vpn[19:18], ppn,
        l2tlb_skew_index_bus(vpn),
        l2tlb_size_bus(vpn),
        l2tlb_page_bank_mask(vpn[19:18], PGS_4K)),
      UVM_NONE)
  endtask

  virtual task body();
    mmu_env env = get_env();
    mmu_vseq_ifu_rr_seq ifq;
    mmu_vseq_lsu_rr_seq ld;
    va_t va_tbl[8];

    cp0_tlb_allinv_seq     cp0_inv;
    pmp_flg_normal_seq     pmp;
    sysmap_region_setup_seq smap;
    cp0_reg_rw_seq         cpr;
    tlb_inv_all_seq        sf;

    cp0_inv = cp0_tlb_allinv_seq::type_id::create("hash_cp0_inv");
    cp0_inv.start(p_sequencer.cp0_sqr);
    pmp = pmp_flg_normal_seq::type_id::create("hash_pmp");
    pmp.start(p_sequencer.pmp_sqr);
    smap = sysmap_region_setup_seq::type_id::create("hash_smap");
    smap.start(p_sequencer.sysmap_sqr);
    cpr = cp0_reg_rw_seq::type_id::create("hash_cpr");
    if (!cpr.randomize() with {
          satp_val  == {4'h8, 16'h0, 44'h0};
          priv_mode == 2'b01;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "hash cp0_reg_rw failed")
    cpr.start(p_sequencer.cp0_sqr);
    sf = tlb_inv_all_seq::type_id::create("hash_sf");
    sf.num_txn = 1;
    sf.start(p_sequencer.lsu_sqr);
    #200ns;

    env.m_pt_mem.m_builder.set_root(28'h0, 16'h0);
    va_tbl[0] = make_hash_va(2'b00, 8'h13, 8'h24, 2'h1, 7'h02);
    va_tbl[1] = make_hash_va(2'b00, 8'h8d, 8'h5a, 2'h3, 7'h15);
    va_tbl[2] = make_hash_va(2'b01, 8'h42, 8'h66, 2'h0, 7'h24);
    va_tbl[3] = make_hash_va(2'b01, 8'he1, 8'h18, 2'h2, 7'h31);
    va_tbl[4] = make_hash_va(2'b10, 8'h57, 8'hc3, 2'h2, 7'h08);
    va_tbl[5] = make_hash_va(2'b10, 8'hb4, 8'h29, 2'h1, 7'h3c);
    va_tbl[6] = make_hash_va(2'b11, 8'h0f, 8'h91, 2'h3, 7'h12);
    va_tbl[7] = make_hash_va(2'b11, 8'hc8, 8'h3e, 2'h1, 7'h28);

    foreach (va_tbl[i])
      add_hash_page(env, va_tbl[i], ppn_t'(28'h12000 + i));
    #500ns;

    ld = mmu_vseq_lsu_rr_seq::type_id::create("hash_ld");
    ld.m_va_table = new[8];
    ld.m_table_size = 8;
    ld.m_kind = LSU_PIPE0;
    ld.m_st_inst = 1'b0;
    ld.m_zero_idle = 1'b1;
    foreach (va_tbl[i]) ld.m_va_table[i] = va_tbl[i];
    ld.num_txn = (num_txn < 32) ? 32 : num_txn;
    ld.start(p_sequencer.lsu_sqr);

    ifq = mmu_vseq_ifu_rr_seq::type_id::create("hash_ifq");
    ifq.m_va_table = new[8];
    ifq.m_table_size = 8;
    ifq.m_zero_idle = 1'b1;
    foreach (va_tbl[i]) ifq.m_va_table[i] = va_tbl[i];
    ifq.num_txn = 16;
    ifq.start(p_sequencer.ifu_sqr);

    #80000ns;
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
      ld = mmu_vseq_lsu_one_ld_seq::type_id::create("ldm");
      ld.m_va = va_t'(39'h0_D000_0000) + va_t'(k << 12);
      ld.start(p_sequencer.lsu_sqr);
      // Allow the pipeline to drain completely before issuing the RTU
      // flush.  Without this gap the flush can race with in-flight
      // scoreboard callbacks and create a zero-delay loop.
      repeat (20) @(posedge env.m_lsu.vif.clk_i);
      fl = misc_rtu_flush_seq::type_id::create("fl");
      fl.start(p_sequencer.misc_sqr);
      repeat (20) @(posedge env.m_lsu.vif.clk_i);
    end
    #1000ns;
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
