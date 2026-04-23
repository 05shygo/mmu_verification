// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_txn.svh
// Phase 3: CP0/CSR transaction class
// =============================================================================
`ifndef CP0_TXN_SVH
`define CP0_TXN_SVH

// CP0 operation enumeration
typedef enum bit [3:0] {
  CP0_WRITE_SATP   = 4'd0,  // Write SATP0 or SATP1 (Sv39 base+asid)
  CP0_READ_SATP    = 4'd1,  // Read SATP read-back
  CP0_WRITE_REG    = 4'd2,  // Write mir/mel/meh via reg_num[1:0]
  CP0_READ_REG     = 4'd3,  // Read via reg_num[1:0]
  CP0_SET_PRIV     = 4'd4,  // Change privilege mode (cp0_yy_priv_mode)
  CP0_SET_MXR      = 4'd5,  // Set MXR bit
  CP0_SET_SUM      = 4'd6,  // Set SUM bit
  CP0_SET_MPRV_MPP = 4'd7,  // Set MPRV + MPP
  CP0_SET_PTW_EN   = 4'd8,  // Set PTW enable
  CP0_SET_NO_OP    = 4'd9,  // Set no_op_req (halt MMU)
  CP0_SET_MAEE     = 4'd10, // Set MAEE (M-mode address extension)
  CP0_SET_ICG_EN   = 4'd11, // Set clock-gate enable
  CP0_SET_CSKYEE   = 4'd12, // Set T-Head extension enable
  CP0_TLB_ALL_INV  = 4'd13  // CP0-path global TLB invalidation
} cp0_op_e;

class cp0_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(cp0_txn)
    `uvm_field_enum(cp0_op_e, op,         UVM_ALL_ON)
    `uvm_field_int(reg_num,               UVM_ALL_ON)
    `uvm_field_int(satp_sel,              UVM_ALL_ON)
    `uvm_field_int(wdata,                 UVM_ALL_ON)
    `uvm_field_int(priv_mode,             UVM_ALL_ON)
    `uvm_field_int(mxr,                   UVM_ALL_ON)
    `uvm_field_int(sum,                   UVM_ALL_ON)
    `uvm_field_int(mprv,                  UVM_ALL_ON)
    `uvm_field_int(mpp,                   UVM_ALL_ON)
    `uvm_field_int(ptw_en,                UVM_ALL_ON)
    `uvm_field_int(no_op_req,             UVM_ALL_ON)
    `uvm_field_int(maee,                  UVM_ALL_ON)
    `uvm_field_int(icg_en,                UVM_ALL_ON)
    `uvm_field_int(cskyee,                UVM_ALL_ON)
    `uvm_field_int(rdata,                 UVM_ALL_ON)
    `uvm_field_int(cmplt,                 UVM_ALL_ON)
    `uvm_field_int(tlb_done,              UVM_ALL_ON)
  `uvm_object_utils_end

  // ── Stimulus fields (driven by cp0_driver) ──────────────────────────────
  rand cp0_op_e   op;
  rand bit [1:0]  reg_num;       // mir=00 / mel=01 / meh=10 (per ct_mmu_regs.v)
  rand bit        satp_sel;      // 0=satp0, 1=satp1
  rand bit [63:0] wdata;         // Write data (for SATP/REG write ops)
  rand bit [1:0]  priv_mode;     // Target privilege: 00=U, 01=S, 11=M
  rand bit        mxr;
  rand bit        sum;
  rand bit        mprv;
  rand bit [1:0]  mpp;
  rand bit        ptw_en;
  rand bit        no_op_req;
  rand bit        maee;
  rand bit        icg_en;
  rand bit        cskyee;

  // ── Response fields (monitor fill-back) ─────────────────────────────────
  bit [63:0] rdata;
  bit        cmplt;
  bit        tlb_done;

  // Default constraints
  constraint c_ptw_en_default { ptw_en == 1'b1; }
  constraint c_icg_en_default { icg_en == 1'b1; }

  function new(string name = "cp0_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "op=%-16s reg_num=%0d satp_sel=%0b wdata=0x%016h priv=%02b mxr=%0b sum=%0b ptw_en=%0b",
      op.name(), reg_num, satp_sel, wdata, priv_mode, mxr, sum, ptw_en);
  endfunction

endclass : cp0_txn

`endif // CP0_TXN_SVH
