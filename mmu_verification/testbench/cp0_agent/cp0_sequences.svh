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
