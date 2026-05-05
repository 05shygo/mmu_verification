// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_if.sv
// Phase 2: IFU <=> MMU interface
// DUT port group: ifu_mmu_* / mmu_ifu_* (ct_mmu_top.v lines ~54-65)
// =============================================================================
`ifndef IFU_IF_SV
`define IFU_IF_SV

interface ifu_if (
  input bit clk_i,
  input bit rst_ni
);

  // -------------------------------------------------------------------------
  // DUT Inputs (driven by TB / ifu_driver)
  // -------------------------------------------------------------------------
  logic        ifu_mmu_va_vld;
  logic [62:0] ifu_mmu_va;
  logic        ifu_mmu_abort;

  // -------------------------------------------------------------------------
  // DUT Outputs (sampled by TB / ifu_monitor)
  // -------------------------------------------------------------------------
  logic        mmu_ifu_pavld;
  logic [27:0] mmu_ifu_pa;
  logic        mmu_ifu_buf;
  logic        mmu_ifu_ca;
  logic        mmu_ifu_deny;
  logic        mmu_ifu_pgflt;
  logic        mmu_ifu_sec;
  logic        dbg_iutlb_acc_flt;
  logic        dbg_iutlb_pmp_deny;
  logic        dbg_iutlb_ref_pgflt;
  logic        dbg_jtlb_acc_fault_flop;
  logic [2:0]  dbg_iutlb_ref_cur_st;
  logic        dbg_iutlb_credit_cnt;
  logic        dbg_iutlb_l2tlb_req;
  logic        dbg_iutlb_miss_vld;
  logic        dbg_iutlb_refill_on;
  logic        dbg_l1itlb_ref_cmplt;
  logic        dbg_ptw_l1tlb_pgflt;
  logic        dbg_jtlb_iutlb_pgflt;

  // -------------------------------------------------------------------------
  // Clocking Block — Active Driver (ifu_driver uses this)
  // -------------------------------------------------------------------------
  clocking driver_cb @(posedge clk_i);
    default input  #1step output #1step;
    output ifu_mmu_va_vld;
    output ifu_mmu_va;
    output ifu_mmu_abort;
    input  mmu_ifu_pavld;
    input  mmu_ifu_pa;
    input  mmu_ifu_buf;
    input  mmu_ifu_ca;
    input  mmu_ifu_deny;
    input  mmu_ifu_pgflt;
    input  mmu_ifu_sec;
    input  dbg_iutlb_pmp_deny;
    input  dbg_iutlb_ref_cur_st;
    input  dbg_iutlb_credit_cnt;
    input  dbg_iutlb_l2tlb_req;
    input  dbg_iutlb_miss_vld;
    input  dbg_iutlb_refill_on;
    input  dbg_l1itlb_ref_cmplt;
    input  dbg_ptw_l1tlb_pgflt;
    input  dbg_jtlb_iutlb_pgflt;
  endclocking

  // -------------------------------------------------------------------------
  // Clocking Block — Monitor
  // -------------------------------------------------------------------------
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input ifu_mmu_va_vld;
    input ifu_mmu_va;
    input ifu_mmu_abort;
    input mmu_ifu_pavld;
    input mmu_ifu_pa;
    input mmu_ifu_buf;
    input mmu_ifu_ca;
    input mmu_ifu_deny;
    input mmu_ifu_pgflt;
    input mmu_ifu_sec;
    input dbg_iutlb_acc_flt;
    input dbg_iutlb_pmp_deny;
    input dbg_iutlb_ref_pgflt;
    input dbg_jtlb_acc_fault_flop;
    input dbg_iutlb_ref_cur_st;
    input dbg_iutlb_credit_cnt;
    input dbg_iutlb_l2tlb_req;
    input dbg_iutlb_miss_vld;
    input dbg_iutlb_refill_on;
    input dbg_l1itlb_ref_cmplt;
    input dbg_ptw_l1tlb_pgflt;
    input dbg_jtlb_iutlb_pgflt;
  endclocking

  // -------------------------------------------------------------------------
  // X-Check Assertions (placeholder — full implementation in mmu_sva.sv)
  // -------------------------------------------------------------------------
  // synthesis translate_off
  // X-check: PA valid should not be X when asserted
  // Full assertions deferred to top/mmu_sva.sv
  // synthesis translate_on

endinterface : ifu_if

`endif // IFU_IF_SV
