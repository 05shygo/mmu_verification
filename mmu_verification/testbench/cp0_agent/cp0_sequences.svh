// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_sequences.svh
// Phase 3: CP0 sequence library
// =============================================================================
`ifndef CP0_SEQUENCES_SVH
`define CP0_SEQUENCES_SVH

// ── Base sequence ────────────────────────────────────────────────────────────
class cp0_base_seq extends uvm_sequence #(cp0_txn);
  `uvm_object_utils(cp0_base_seq)

  function new(string name = "cp0_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // Derived classes provide concrete body
  endtask

endclass : cp0_base_seq

// ── Write SATP (activates MMU → mmu_xx_mmu_en=1 when MODE=8) ─────────────────
// Used by Phase 3 sanity test to bring the MMU online.
class cp0_satp_switch_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_satp_switch_seq)

  rand bit        satp_sel;   // 0 = satp0, 1 = satp1
  rand bit [63:0] satp_val;   // {MODE[63:60], ASID[59:44], PPN[43:0]}

  // Default: Sv39 enabled (MODE=8), ASID=0, PPN=0
  constraint c_sv39_mode { satp_val[63:60] inside {4'h8, 4'h0}; }

  function new(string name = "cp0_satp_switch_seq");
    super.new(name);
    satp_sel = 1'b0;
    satp_val = {4'h8, 16'h0, 44'h0};  // Sv39, ASID=0, PPN=0
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op       = CP0_WRITE_SATP;
    tr.satp_sel = satp_sel;
    tr.wdata    = satp_val;
    `uvm_send(tr)
  endtask

endclass : cp0_satp_switch_seq

// ── Toggle satp_sel between satp0 and satp1 ─────────────────────────────────
class cp0_satp_sel_toggle_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_satp_sel_toggle_seq)

  rand int unsigned n_toggles;
  constraint c_toggles { n_toggles inside {[2:8]}; }

  function new(string name = "cp0_satp_sel_toggle_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    for (int i = 0; i < int'(n_toggles); i++) begin
      `uvm_create(tr)
      tr.op       = CP0_WRITE_SATP;
      tr.satp_sel = i[0];
      tr.wdata    = {4'h8, 16'h0, 44'h0};
      `uvm_send(tr)
    end
  endtask

endclass : cp0_satp_sel_toggle_seq

// ── Set privilege mode ────────────────────────────────────────────────────────
class cp0_priv_switch_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_priv_switch_seq)

  rand bit [1:0] priv_mode;  // 00=U, 01=S, 11=M

  function new(string name = "cp0_priv_switch_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op        = CP0_SET_PRIV;
    tr.priv_mode = priv_mode;
    `uvm_send(tr)
  endtask

endclass : cp0_priv_switch_seq

// ── Set MXR and SUM ───────────────────────────────────────────────────────────
class cp0_mxr_sum_cross_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_mxr_sum_cross_seq)

  rand bit mxr_val;
  rand bit sum_val;

  function new(string name = "cp0_mxr_sum_cross_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op  = CP0_SET_MXR;
    tr.mxr = mxr_val;
    `uvm_send(tr)
    `uvm_create(tr)
    tr.op  = CP0_SET_SUM;
    tr.sum = sum_val;
    `uvm_send(tr)
  endtask

endclass : cp0_mxr_sum_cross_seq

// ── Set MPRV + MPP ────────────────────────────────────────────────────────────
class cp0_mprv_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_mprv_seq)

  rand bit       mprv_val;
  rand bit [1:0] mpp_val;

  function new(string name = "cp0_mprv_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op   = CP0_SET_MPRV_MPP;
    tr.mprv = mprv_val;
    tr.mpp  = mpp_val;
    `uvm_send(tr)
  endtask

endclass : cp0_mprv_seq

// ── Disable PTW ───────────────────────────────────────────────────────────────
class cp0_ptw_disable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_ptw_disable_seq)

  function new(string name = "cp0_ptw_disable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op     = CP0_SET_PTW_EN;
    tr.ptw_en = 1'b0;
    `uvm_send(tr)
  endtask

endclass : cp0_ptw_disable_seq

// ── CP0-path TLB all-invalidate ───────────────────────────────────────────────
class cp0_tlb_allinv_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_tlb_allinv_seq)

  function new(string name = "cp0_tlb_allinv_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op = CP0_TLB_ALL_INV;
    `uvm_send(tr)
  endtask

endclass : cp0_tlb_allinv_seq

// ── Assert / de-assert no_op_req ─────────────────────────────────────────────
class cp0_no_op_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_no_op_seq)

  rand bit no_op_val;

  function new(string name = "cp0_no_op_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op        = CP0_SET_NO_OP;
    tr.no_op_req = no_op_val;
    `uvm_send(tr)
  endtask

endclass : cp0_no_op_seq

class cp0_no_op_assert_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_no_op_assert_seq)

  function new(string name = "cp0_no_op_assert_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op        = CP0_SET_NO_OP;
    tr.no_op_req = 1'b1;
    `uvm_send(tr)
  endtask

endclass : cp0_no_op_assert_seq

class cp0_no_op_clear_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_no_op_clear_seq)

  function new(string name = "cp0_no_op_clear_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op        = CP0_SET_NO_OP;
    tr.no_op_req = 1'b0;
    `uvm_send(tr)
  endtask

endclass : cp0_no_op_clear_seq

class cp0_maee_enable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_maee_enable_seq)

  function new(string name = "cp0_maee_enable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op   = CP0_SET_MAEE;
    tr.maee = 1'b1;
    `uvm_send(tr)
  endtask

endclass : cp0_maee_enable_seq

class cp0_maee_disable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_maee_disable_seq)

  function new(string name = "cp0_maee_disable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op   = CP0_SET_MAEE;
    tr.maee = 1'b0;
    `uvm_send(tr)
  endtask

endclass : cp0_maee_disable_seq

class cp0_icg_enable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_icg_enable_seq)

  function new(string name = "cp0_icg_enable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op     = CP0_SET_ICG_EN;
    tr.icg_en = 1'b1;
    `uvm_send(tr)
  endtask

endclass : cp0_icg_enable_seq

class cp0_icg_disable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_icg_disable_seq)

  function new(string name = "cp0_icg_disable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op     = CP0_SET_ICG_EN;
    tr.icg_en = 1'b0;
    `uvm_send(tr)
  endtask

endclass : cp0_icg_disable_seq

class cp0_cskyee_enable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_cskyee_enable_seq)

  function new(string name = "cp0_cskyee_enable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = CP0_SET_CSKYEE;
    tr.cskyee  = 1'b1;
    `uvm_send(tr)
  endtask

endclass : cp0_cskyee_enable_seq

class cp0_cskyee_disable_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_cskyee_disable_seq)

  function new(string name = "cp0_cskyee_disable_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = CP0_SET_CSKYEE;
    tr.cskyee  = 1'b0;
    `uvm_send(tr)
  endtask

endclass : cp0_cskyee_disable_seq

class cp0_satp_read_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_satp_read_seq)

  rand bit satp_sel;

  function new(string name = "cp0_satp_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op       = CP0_READ_SATP;
    tr.satp_sel = satp_sel;
    `uvm_send(tr)
  endtask

endclass : cp0_satp_read_seq

class cp0_satp_read_both_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_satp_read_both_seq)

  function new(string name = "cp0_satp_read_both_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    for (int i = 0; i < 2; i++) begin
      `uvm_create(tr)
      tr.op       = CP0_READ_SATP;
      tr.satp_sel = i[0];
      `uvm_send(tr)
    end
  endtask

endclass : cp0_satp_read_both_seq

class cp0_satp_mode_sv39_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_satp_mode_sv39_seq)

  function new(string name = "cp0_satp_mode_sv39_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op       = CP0_WRITE_SATP;
    tr.satp_sel = 1'b0;
    tr.wdata    = {4'h8, 16'h0, 44'h0};
    `uvm_send(tr)
  endtask

endclass : cp0_satp_mode_sv39_seq

class cp0_satp_mode_bare_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_satp_mode_bare_seq)

  function new(string name = "cp0_satp_mode_bare_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op       = CP0_WRITE_SATP;
    tr.satp_sel = 1'b0;
    tr.wdata    = {4'h0, 16'h0, 44'h0};
    `uvm_send(tr)
  endtask

endclass : cp0_satp_mode_bare_seq

class cp0_reg_access_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_reg_access_seq)

  rand bit       is_write;
  rand bit [1:0] reg_num;
  rand bit [63:0] wdata;

  function new(string name = "cp0_reg_access_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = is_write ? CP0_WRITE_REG : CP0_READ_REG;
    tr.reg_num = reg_num;
    tr.wdata   = wdata;
    `uvm_send(tr)
  endtask

endclass : cp0_reg_access_seq

class cp0_l2tlb_tlbop_exact_base_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbop_exact_base_seq)

  typedef struct {
    bit [26:0] vpn;
    bit [15:0] asid;
    bit [2:0]  pgs;
    bit [27:0] ppn;
    bit [13:0] flags;
    bit        global_bit;
    bit [2:0]  way;
    bit [7:0]  set_idx;
    bit [10:0] index;
  } tlbop_entry_t;

  function new(string name = "cp0_l2tlb_tlbop_exact_base_seq");
    super.new(name);
  endfunction

  protected function bit [63:0] mcir_tlbp();
    return 64'h0000_0000_8000_0000;
  endfunction

  protected function bit [63:0] mcir_tlbr();
    return 64'h0000_0000_4000_0000;
  endfunction

  protected function bit [63:0] mcir_tlbwi();
    return 64'h0000_0000_2000_0000;
  endfunction

  protected function bit [63:0] mcir_tlbwr();
    return 64'h0000_0000_1000_0000;
  endfunction

  protected function bit [2:0] pgs_4k();
    return PGS_4K;
  endfunction

  protected function bit [2:0] pgs_2m();
    return PGS_2M;
  endfunction

  protected function bit [2:0] pgs_1g();
    return PGS_1G;
  endfunction

  protected function bit [13:0] make_flags(
    bit v = 1'b1,
    bit r = 1'b1,
    bit w = 1'b1,
    bit x = 1'b1,
    bit u = 1'b0,
    bit a = 1'b1,
    bit d = 1'b1,
    bit [1:0] rsw = 2'b00,
    bit so = 1'b0,
    bit c = 1'b1,
    bit b = 1'b0,
    bit sh = 1'b1,
    bit sec = 1'b0
  );
    return {so, c, b, sh, sec, rsw, d, a, u, x, w, r, v};
  endfunction

  protected function bit [7:0] reverse8(bit [7:0] in);
    for (int i = 0; i < 8; i++)
      reverse8[i] = in[7-i];
  endfunction

  protected function bit [2:0] size_pred(bit [1:0] selector, bit [2:0] way);
    return l2tlb_size_pred(selector, way);
  endfunction

  protected function bit [7:0] skew_index(bit [26:0] vpn, bit [2:0] way);
    return l2tlb_skew_index(vpn_t'(vpn), way);
  endfunction

  protected function tlbop_entry_t make_entry(
    bit [26:0] vpn,
    bit [15:0] asid,
    bit [27:0] ppn,
    bit [2:0]  pgs,
    bit [2:0]  way,
    bit        global_bit,
    bit [13:0] flags
  );
    make_entry.vpn = vpn;
    make_entry.asid = asid;
    make_entry.pgs = pgs;
    make_entry.ppn = ppn;
    make_entry.flags = flags;
    make_entry.global_bit = global_bit;
    make_entry.way = way;
    make_entry.set_idx = skew_index(vpn, way);
    make_entry.index = {way, make_entry.set_idx};
  endfunction

  protected function bit page_size_matches_way(tlbop_entry_t ent, bit [2:0] way);
    return (size_pred(ent.vpn[19:18], way) == ent.pgs);
  endfunction

  protected function bit [63:0] pack_mel(tlbop_entry_t ent);
    bit [63:0] mel;
    mel = '0;
    mel[63:59] = ent.flags[13:9];
    mel[37:10] = ent.ppn;
    mel[9:6] = ent.flags[8:5];
    mel[5] = ent.global_bit;
    mel[4:0] = ent.flags[4:0];
    return mel;
  endfunction

  protected function bit [63:0] pack_meh(tlbop_entry_t ent);
    return {18'b0, ent.vpn, ent.pgs, ent.asid};
  endfunction

  protected function bit [13:0] flags_from_mel(bit [63:0] mel);
    return {mel[63:59], mel[9:6], mel[4:0]};
  endfunction

  protected function string op_from_mcir(bit [63:0] mcir);
    if (mcir[31]) return "TLBP";
    if (mcir[30]) return "TLBR";
    if (mcir[29]) return "TLBWI";
    if (mcir[28]) return "TLBWR";
    if (mcir[27]) return "INVASID";
    if (mcir[26]) return "INVALL";
    return "MCIR_NOOP_OR_UNKNOWN";
  endfunction

  protected task cp0_write_reg(bit [1:0] reg_num, bit [63:0] wdata, string ctx = "");
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = CP0_WRITE_REG;
    tr.reg_num = reg_num;
    tr.wdata   = wdata;
    `uvm_send(tr)
    if (reg_num == 2'd3) begin
      $display("[L2TLB_TLBOP_DECODE] seq=%s ctx=%s op=%s reg_num=MCIR wdata=0x%016h cmplt=%0b rdata=0x%016h",
        get_name(), ctx, op_from_mcir(wdata), wdata, tr.cmplt, tr.rdata);
    end
  endtask

  protected task cp0_read_reg(
    input bit [1:0] reg_num,
    output bit [63:0] rdata,
    input string ctx = ""
  );
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = CP0_READ_REG;
    tr.reg_num = reg_num;
    `uvm_send(tr)
    rdata = tr.rdata;
    $display("[L2TLB_TLBOP_READBACK] seq=%s ctx=%s reg_num=%0d rdata=0x%016h",
      get_name(), ctx, reg_num, rdata);
  endtask

  protected task set_cskyee(bit enable);
    cp0_txn tr;
    `uvm_create(tr)
    tr.op     = CP0_SET_CSKYEE;
    tr.cskyee = enable;
    `uvm_send(tr)
  endtask

  protected task write_mir(bit [10:0] index, string ctx);
    cp0_write_reg(2'd0, {52'b0, 1'b0, index}, ctx);
  endtask

  protected task write_mel(tlbop_entry_t ent, string ctx);
    cp0_write_reg(2'd1, pack_mel(ent), ctx);
  endtask

  protected task write_meh(tlbop_entry_t ent, string ctx);
    cp0_write_reg(2'd2, pack_meh(ent), ctx);
  endtask

  protected task issue_mcir(bit [63:0] mcir, string ctx);
    cp0_write_reg(2'd3, mcir, ctx);
  endtask

  protected task tlbwi_entry(tlbop_entry_t ent, string ctx);
    set_cskyee(1'b1);
    write_mir(ent.index, {ctx, ".mir"});
    write_mel(ent, {ctx, ".mel"});
    write_meh(ent, {ctx, ".meh"});
    issue_mcir(mcir_tlbwi(), {ctx, ".tlbwi"});
    $display("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBWI index=0x%03h way=%0d set=0x%02h vpn=0x%07h selector=0x%0h pgs=0x%0h pred_pgs=0x%0h pgs_match=%0b asid=0x%04h ppn=0x%07h flags=0x%04h g=%0b status=ISSUED",
      get_name(), ctx, ent.index, ent.way, ent.set_idx, ent.vpn,
      ent.vpn[19:18], ent.pgs, size_pred(ent.vpn[19:18], ent.way),
      page_size_matches_way(ent, ent.way), ent.asid, ent.ppn, ent.flags,
      ent.global_bit);
  endtask

  protected task tlbwr_entry(tlbop_entry_t ent, string ctx);
    set_cskyee(1'b1);
    write_mel(ent, {ctx, ".mel"});
    write_meh(ent, {ctx, ".meh"});
    issue_mcir(mcir_tlbwr(), {ctx, ".tlbwr"});
    $display("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBWR vpn=0x%07h selector=0x%0h pgs=0x%0h asid=0x%04h ppn=0x%07h flags=0x%04h g=%0b status=ISSUED exact_victim=not_checked",
      get_name(), ctx, ent.vpn, ent.vpn[19:18], ent.pgs, ent.asid, ent.ppn,
      ent.flags, ent.global_bit);
  endtask

  protected task tlbp_probe(
    tlbop_entry_t ent,
    bit expect_hit,
    bit check_index,
    bit [10:0] expect_index,
    output bit [10:0] observed_index,
    input string ctx
  );
    bit [63:0] mir;
    bit hit;
    bit mult;

    set_cskyee(1'b1);
    write_meh(ent, {ctx, ".meh"});
    issue_mcir(mcir_tlbp(), {ctx, ".tlbp"});
    cp0_read_reg(2'd0, mir, {ctx, ".mir_read"});

    hit = !mir[31];
    mult = mir[30];
    observed_index = mir[10:0];
    if (hit !== expect_hit) begin
      `uvm_error(get_type_name(),
        $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBP expected_hit=%0b observed_hit=%0b mir=0x%016h vpn=0x%07h asid=0x%04h",
          get_name(), ctx, expect_hit, hit, mir, ent.vpn, ent.asid))
    end else if (expect_hit && mult) begin
      `uvm_error(get_type_name(),
        $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBP unexpected_multi_hit mir=0x%016h vpn=0x%07h asid=0x%04h",
          get_name(), ctx, mir, ent.vpn, ent.asid))
    end else if (expect_hit && check_index && (observed_index !== expect_index)) begin
      `uvm_error(get_type_name(),
        $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBP expected_index=0x%03h observed_index=0x%03h mir=0x%016h vpn=0x%07h",
          get_name(), ctx, expect_index, observed_index, mir, ent.vpn))
    end else begin
      $display("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBP expected_hit=%0b observed_hit=%0b multi=%0b observed_index=0x%03h expected_index=0x%03h status=PASS",
        get_name(), ctx, expect_hit, hit, mult, observed_index, expect_index);
    end
  endtask

  protected task tlbr_read_sample(
    input bit [10:0] index,
    output bit [26:0] got_vpn,
    output bit [15:0] got_asid,
    output bit [2:0] got_pgs,
    output bit [27:0] got_ppn,
    output bit [13:0] got_flags,
    output bit got_g,
    input string ctx
  );
    bit [63:0] mel;
    bit [63:0] meh;

    set_cskyee(1'b1);
    write_mir(index, {ctx, ".mir"});
    issue_mcir(mcir_tlbr(), {ctx, ".tlbr"});
    cp0_read_reg(2'd1, mel, {ctx, ".mel_read"});
    cp0_read_reg(2'd2, meh, {ctx, ".meh_read"});

    got_vpn = meh[45:19];
    got_pgs = meh[18:16];
    got_asid = meh[15:0];
    got_ppn = mel[37:10];
    got_flags = flags_from_mel(mel);
    got_g = mel[5];
  endtask

  protected function bit tlbr_fields_match(
    tlbop_entry_t ent,
    bit [26:0] got_vpn,
    bit [15:0] got_asid,
    bit [2:0] got_pgs,
    bit [27:0] got_ppn,
    bit [13:0] got_flags,
    bit got_g
  );
    return (got_vpn === ent.vpn)
        && (got_pgs === ent.pgs)
        && (got_asid === ent.asid)
        && (got_ppn === ent.ppn)
        && (got_flags === ent.flags)
        && (got_g === ent.global_bit);
  endfunction

  protected task tlbr_read_check(
    tlbop_entry_t ent,
    bit [10:0] index,
    bit check_payload,
    string ctx
  );
    bit pass;
    bit [26:0] got_vpn;
    bit [15:0] got_asid;
    bit [2:0]  got_pgs;
    bit [27:0] got_ppn;
    bit [13:0] got_flags;
    bit        got_g;

    tlbr_read_sample(index, got_vpn, got_asid, got_pgs, got_ppn, got_flags,
                     got_g, ctx);

    pass = 1'b1;
    if (check_payload) begin
      pass = tlbr_fields_match(ent, got_vpn, got_asid, got_pgs, got_ppn,
                               got_flags, got_g);
    end

    if (!pass) begin
      `uvm_error(get_type_name(),
        $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBR index=0x%03h expected={vpn=0x%07h pgs=0x%0h asid=0x%04h ppn=0x%07h flags=0x%04h g=%0b} observed={vpn=0x%07h pgs=0x%0h asid=0x%04h ppn=0x%07h flags=0x%04h g=%0b}",
          get_name(), ctx, index, ent.vpn, ent.pgs, ent.asid, ent.ppn,
          ent.flags, ent.global_bit, got_vpn, got_pgs, got_asid, got_ppn,
          got_flags, got_g))
    end else begin
      $display("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBR index=0x%03h vpn=0x%07h pgs=0x%0h asid=0x%04h ppn=0x%07h flags=0x%04h g=%0b payload_checked=%0b status=PASS",
        get_name(), ctx, index, got_vpn, got_pgs, got_asid, got_ppn,
        got_flags, got_g, check_payload);
    end
  endtask

  protected task tlbr_find_entry(
    input tlbop_entry_t ent,
    output bit found,
    output bit [10:0] found_index,
    output bit [2:0] found_way,
    input string ctx
  );
    bit [26:0] got_vpn;
    bit [15:0] got_asid;
    bit [2:0]  got_pgs;
    bit [27:0] got_ppn;
    bit [13:0] got_flags;
    bit        got_g;
    bit [2:0]  way;
    bit [10:0] candidate_index;

    found = 1'b0;
    found_index = '0;
    found_way = '0;

    for (int unsigned way_i = 0; way_i < 8; way_i++) begin
      way = way_i[2:0];
      candidate_index = {way, skew_index(ent.vpn, way)};
      tlbr_read_sample(candidate_index, got_vpn, got_asid, got_pgs, got_ppn,
                       got_flags, got_g,
                       $sformatf("%s.scan_way%0d", ctx, way_i));
      if (tlbr_fields_match(ent, got_vpn, got_asid, got_pgs, got_ppn,
                            got_flags, got_g)) begin
        if (!found) begin
          found = 1'b1;
          found_index = candidate_index;
          found_way = way;
        end else begin
          `uvm_error(get_type_name(),
            $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBR_SCAN classification=RTL_bug_or_UVM_duplicate expected_single_payload_duplicate old_index=0x%03h new_index=0x%03h vpn=0x%07h asid=0x%04h",
              get_name(), ctx, found_index, candidate_index, ent.vpn, ent.asid))
        end
      end
    end

    if (!found) begin
      `uvm_error(get_type_name(),
        $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBR_SCAN classification=RTL_bug_or_UVM_bug expected_payload_not_found vpn=0x%07h pgs=0x%0h asid=0x%04h ppn=0x%07h flags=0x%04h g=%0b",
          get_name(), ctx, ent.vpn, ent.pgs, ent.asid, ent.ppn, ent.flags,
          ent.global_bit))
    end else begin
      $display("[L2TLB_TLBOP_CHECK] seq=%s ctx=%s op=TLBR_SCAN found_index=0x%03h found_way=%0d vpn=0x%07h pgs=0x%0h pred_pgs=0x%0h pgs_match=%0b status=PASS",
        get_name(), ctx, found_index, found_way, ent.vpn, ent.pgs,
        size_pred(ent.vpn[19:18], found_way),
        page_size_matches_way(ent, found_way));
    end
  endtask

endclass : cp0_l2tlb_tlbop_exact_base_seq

class cp0_l2tlb_tlbp_hit_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbp_hit_exact_seq)

  function new(string name = "cp0_l2tlb_tlbp_hit_exact_seq");
    super.new(name);
  endfunction

  virtual task body();
    tlbop_entry_t ent;
    bit [10:0] observed_index;

    ent = make_entry(27'h000123, 16'h0034, 28'h00456, pgs_4k(), 3'd0, 1'b0,
                     make_flags());
    tlbwi_entry(ent, "tlbp_hit_setup");
    tlbp_probe(ent, 1'b1, 1'b1, ent.index, observed_index, "tlbp_hit");
  endtask

endclass : cp0_l2tlb_tlbp_hit_exact_seq

class cp0_l2tlb_tlbp_miss_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbp_miss_exact_seq)

  function new(string name = "cp0_l2tlb_tlbp_miss_exact_seq");
    super.new(name);
  endfunction

  virtual task body();
    tlbop_entry_t ent_hit;
    tlbop_entry_t ent_miss;
    bit [10:0] observed_index;

    ent_hit = make_entry(27'h000124, 16'h0034, 28'h00457, pgs_4k(), 3'd0, 1'b0,
                         make_flags());
    ent_miss = make_entry(27'h0001a5, 16'h0034, 28'h00458, pgs_4k(), 3'd0, 1'b0,
                          make_flags());
    tlbwi_entry(ent_hit, "tlbp_miss_setup_other_entry");
    tlbp_probe(ent_miss, 1'b0, 1'b0, '0, observed_index, "tlbp_miss");
  endtask

endclass : cp0_l2tlb_tlbp_miss_exact_seq

class cp0_l2tlb_tlbr_read_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbr_read_exact_seq)

  function new(string name = "cp0_l2tlb_tlbr_read_exact_seq");
    super.new(name);
  endfunction

  virtual task body();
    tlbop_entry_t ent;

    ent = make_entry(27'h000223, 16'h0101, 28'h00567, pgs_4k(), 3'd1, 1'b0,
                     make_flags(.w(1'b0), .u(1'b1), .rsw(2'b01)));
    tlbwi_entry(ent, "tlbr_setup");
    tlbr_read_check(ent, ent.index, 1'b1, "tlbr_readback");
  endtask

endclass : cp0_l2tlb_tlbr_read_exact_seq

class cp0_l2tlb_tlbr_all_fields_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbr_all_fields_exact_seq)

  function new(string name = "cp0_l2tlb_tlbr_all_fields_exact_seq");
    super.new(name);
  endfunction

  virtual task body();
    tlbop_entry_t ent;

    ent = make_entry(27'h0040323, 16'hbeef, 28'h00678, pgs_4k(), 3'd2, 1'b1,
                     make_flags(.w(1'b0), .u(1'b1), .d(1'b0), .rsw(2'b10),
                                .so(1'b1), .c(1'b0), .b(1'b1),
                                .sh(1'b1), .sec(1'b1)));
    tlbwi_entry(ent, "tlbr_all_fields_setup");
    tlbr_read_check(ent, ent.index, 1'b1, "tlbr_all_fields_readback");
  endtask

endclass : cp0_l2tlb_tlbr_all_fields_exact_seq

class cp0_l2tlb_tlbwi_write_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbwi_write_exact_seq)

  function new(string name = "cp0_l2tlb_tlbwi_write_exact_seq");
    super.new(name);
  endfunction

  virtual task body();
    tlbop_entry_t ent;
    bit [10:0] observed_index;

    ent = make_entry(27'h000423, 16'h0044, 28'h00789, pgs_4k(), 3'd5, 1'b0,
                     make_flags());
    tlbwi_entry(ent, "tlbwi_write");
    tlbr_read_check(ent, ent.index, 1'b1, "tlbwi_tlbr_verify");
    tlbp_probe(ent, 1'b1, 1'b1, ent.index, observed_index, "tlbwi_tlbp_verify");
  endtask

endclass : cp0_l2tlb_tlbwi_write_exact_seq

class cp0_l2tlb_inv_asid_directed_probe_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_inv_asid_directed_probe_seq)

  bit do_write;
  bit expect_hit;
  bit global_entry;

  function new(string name = "cp0_l2tlb_inv_asid_directed_probe_seq");
    super.new(name);
    do_write = 1'b1;
    expect_hit = 1'b1;
    global_entry = 1'b0;
  endfunction

  virtual task body();
    tlbop_entry_t ent;
    bit [10:0] observed_index;
    string ctx_prefix;

    ent = make_entry(27'h000423, 16'h1234, 28'h00abc, pgs_4k(), 3'd5,
                     global_entry, make_flags(.u(1'b1), .rsw(2'b01)));
    ctx_prefix = global_entry ? "inv_asid_global" : "inv_asid_nonglobal";

    if (do_write) begin
      tlbwi_entry(ent, {ctx_prefix, "_setup"});
      tlbr_read_check(ent, ent.index, 1'b1, {ctx_prefix, "_setup_tlbr"});
      tlbp_probe(ent, 1'b1, 1'b1, ent.index, observed_index,
                 {ctx_prefix, "_pre_inv_tlbp"});
    end else begin
      tlbp_probe(ent, expect_hit, expect_hit, ent.index, observed_index,
                 {ctx_prefix, "_post_inv_tlbp"});
      if (expect_hit) begin
        tlbr_read_check(ent, observed_index, 1'b1,
                        {ctx_prefix, "_post_inv_tlbr"});
      end
    end
  endtask

endclass : cp0_l2tlb_inv_asid_directed_probe_seq

class cp0_l2tlb_tlbwi_overwrite_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbwi_overwrite_exact_seq)

  function new(string name = "cp0_l2tlb_tlbwi_overwrite_exact_seq");
    super.new(name);
  endfunction

  virtual task body();
    tlbop_entry_t old_ent;
    tlbop_entry_t new_ent;
    bit [10:0] observed_index;

    old_ent = make_entry(27'h000523, 16'h0055, 28'h0089a, pgs_4k(), 3'd4, 1'b0,
                         make_flags());
    new_ent = old_ent;
    new_ent.ppn = 28'h008bc;
    new_ent.flags = make_flags(.r(1'b1), .w(1'b0), .x(1'b1), .u(1'b1),
                               .rsw(2'b11), .c(1'b0), .sec(1'b1));

    tlbwi_entry(old_ent, "tlbwi_overwrite_old");
    tlbr_read_check(old_ent, old_ent.index, 1'b1, "tlbwi_overwrite_old_readback");
    tlbwi_entry(new_ent, "tlbwi_overwrite_new");
    tlbr_read_check(new_ent, new_ent.index, 1'b1, "tlbwi_overwrite_new_readback");
    tlbp_probe(new_ent, 1'b1, 1'b1, new_ent.index, observed_index, "tlbwi_overwrite_new_hit");
  endtask

endclass : cp0_l2tlb_tlbwi_overwrite_exact_seq

class cp0_l2tlb_tlbwr_visible_exact_seq extends cp0_l2tlb_tlbop_exact_base_seq;
  `uvm_object_utils(cp0_l2tlb_tlbwr_visible_exact_seq)

  int unsigned num_writes;

  function new(string name = "cp0_l2tlb_tlbwr_visible_exact_seq");
    super.new(name);
    num_writes = 1;
  endfunction

  protected function tlbop_entry_t make_visible_entry(int unsigned i);
    case (i % 3)
      0: return make_entry(27'h000623, 16'h0066, 28'h009ab, pgs_4k(), 3'd0, 1'b0,
                           make_flags(.w(1'b0), .u(1'b0), .rsw(2'b00)));
      1: return make_entry(27'h000724, 16'h0066, 28'h009bc, pgs_4k(), 3'd1, 1'b0,
                           make_flags(.w(1'b1), .u(1'b1), .rsw(2'b01)));
      default: return make_entry(27'h000825, 16'h0066, 28'h009cd, pgs_4k(), 3'd2, 1'b0,
                                 make_flags(.w(1'b0), .u(1'b1), .rsw(2'b10),
                                            .c(1'b0), .sec(1'b1)));
    endcase
  endfunction

  virtual task body();
    tlbop_entry_t ent;
    bit [10:0] observed_index;
    bit [10:0] tlbp_index;
    bit [2:0] observed_way;
    bit found;

    for (int unsigned i = 0; i < num_writes; i++) begin
      ent = make_visible_entry(i);
      tlbwr_entry(ent, $sformatf("tlbwr_visible_%0d", i));
      tlbr_find_entry(ent, found, observed_index, observed_way,
                      $sformatf("tlbwr_visible_%0d_tlbr_scan", i));
      if (found) begin
        if (!page_size_matches_way(ent, observed_way)) begin
          `uvm_error(get_type_name(),
            $sformatf("[L2TLB_TLBOP_CHECK] seq=%s ctx=tlbwr_visible_%0d op=TLBWR classification=RTL_bug_or_spec_gap payload_written_to_tlbp_invisible_way index=0x%03h way=%0d vpn=0x%07h pgs=0x%0h pred_pgs=0x%0h",
              get_name(), i, observed_index, observed_way, ent.vpn, ent.pgs,
              size_pred(ent.vpn[19:18], observed_way)))
        end else begin
          tlbp_probe(ent, 1'b1, 1'b1, observed_index, tlbp_index,
                     $sformatf("tlbwr_visible_%0d_tlbp", i));
        end
      end
    end
  endtask

endclass : cp0_l2tlb_tlbwr_visible_exact_seq

class cp0_tlbp_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_tlbp_seq)

  function new(string name = "cp0_tlbp_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    `uvm_create(tr)
    tr.op      = CP0_READ_REG;
    tr.reg_num = 2'd2;
    `uvm_send(tr)
  endtask

endclass : cp0_tlbp_seq

class cp0_tlbr_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_tlbr_seq)

  function new(string name = "cp0_tlbr_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    for (int i = 0; i < 3; i++) begin
      `uvm_create(tr)
      tr.op      = CP0_READ_REG;
      tr.reg_num = i[1:0];
      `uvm_send(tr)
    end
  endtask

endclass : cp0_tlbr_seq

class cp0_tlbwi_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_tlbwi_seq)

  function new(string name = "cp0_tlbwi_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    for (int i = 0; i < 3; i++) begin
      `uvm_create(tr)
      tr.op      = CP0_WRITE_REG;
      tr.reg_num = i[1:0];
      tr.wdata   = 64'h1000 + i;
      `uvm_send(tr)
    end
  endtask

endclass : cp0_tlbwi_seq

class cp0_tlbwr_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_tlbwr_seq)

  function new(string name = "cp0_tlbwr_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;
    for (int i = 0; i < 3; i++) begin
      `uvm_create(tr)
      tr.op      = CP0_WRITE_REG;
      tr.reg_num = i[1:0];
      tr.wdata   = 64'h2000 + (i * 64'h10);
      `uvm_send(tr)
    end
  endtask

endclass : cp0_tlbwr_seq

// ── Composite init sequence: ICG_EN → PRIV → SATP(Sv39) → PTW_EN ─────────────
// Phase 3+ sanity tests use this to bring the MMU online.
// PRIV is set BEFORE SATP so mmu_en=1 the instant satp_mode is latched.
class cp0_reg_rw_seq extends cp0_base_seq;
  `uvm_object_utils(cp0_reg_rw_seq)

  rand bit [63:0] satp_val;
  rand bit [1:0]  priv_mode;
  rand bit        ptw_en;
  rand bit        icg_en;

  constraint c_defaults {
    satp_val[63:60] == 4'h8;  // Sv39 MODE
    ptw_en          == 1'b1;
    icg_en          == 1'b1;
  }

  function new(string name = "cp0_reg_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    cp0_txn tr;

    // 1. Enable clock-gate
    `uvm_create(tr)
    tr.op     = CP0_SET_ICG_EN;
    tr.icg_en = icg_en;
    `uvm_send(tr)

    // 2. Set privilege mode BEFORE SATP write.
    //    RTL: mmu_xx_mmu_en = (satp_mode==4'h8) && (priv_mode != 2'b11).
    //    Setting S-mode first ensures mmu_en becomes 1 the instant SATP.mode
    //    is latched, avoiding any transient window where satp_mode=8 but
    //    mmu_en=0 (which can leave internal DUT state in bare-mode paths).
    `uvm_create(tr)
    tr.op        = CP0_SET_PRIV;
    tr.priv_mode = priv_mode;
    `uvm_send(tr)

    // 3. Write SATP → mmu_en immediately becomes 1 (priv already S-mode)
    `uvm_create(tr)
    tr.op       = CP0_WRITE_SATP;
    tr.satp_sel = 1'b0;
    tr.wdata    = satp_val;
    `uvm_send(tr)

    // 4. Enable PTW
    `uvm_create(tr)
    tr.op     = CP0_SET_PTW_EN;
    tr.ptw_en = ptw_en;
    `uvm_send(tr)
  endtask

endclass : cp0_reg_rw_seq

`endif // CP0_SEQUENCES_SVH
