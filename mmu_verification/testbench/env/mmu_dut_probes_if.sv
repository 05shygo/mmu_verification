// =============================================================================
// mmu_dut_probes_if.sv
// Whitebox 观测：DUT 内部 net 在 tb_top 中用 assign 驱动本 interface 的 net；
// mmu_env_pkg 内 mmu_env_cg_whitebox 只持有 virtual mmu_dut_probes_if（禁止 $root）。
// =============================================================================
`ifndef MMU_DUT_PROBES_IF_SV
`define MMU_DUT_PROBES_IF_SV

interface mmu_dut_probes_if (
  input logic clk_i,
  input logic rst_ni
);

  // mmu_l1itlb
  wire [31:0]  l1i_entry_vld;
  wire [1:0]   l1i_ref_fsm;
  wire         l1i_credit_cnt;

  // mmu_l1dtlb
  wire [7:0]   l1d_mb_vld;       // MB_DEPTH=8
  wire [2:0]   l1d_mb_st0;       // mb_entry_state[0]

  // mmu_l2tlb
  wire [2:0]   l2_bank0;   // way_index[0][2:0]
  wire [7:0]   l2_final_way_hit;
  wire [2:0]   l2_raw_pre_pgs0;

  // mmu_l2tlb / x_l2tlb_reqq
  wire [8:0]   l2_reqq_vld_vec;  // TOTAL_DEPTH=9
  wire [2:0]   l2_reqq_qid;

  // ptw
  wire [1:0]   ptw_xbar_hit_lvl;
  wire [2:0]   ptw_mbuf_twu_lvl;
  wire         ptw_fault_any;    // pgflt_vld | acc_err_vld

  // ct_mmu_tlboper
  wire [3:0]   tlbiva_cur_st;

  // Monitor clocking
  clocking mon_cb @(posedge clk_i);
    default input #1step;
    input l1i_entry_vld, l1i_ref_fsm, l1i_credit_cnt;
    input l1d_mb_vld, l1d_mb_st0;
    input l2_bank0, l2_final_way_hit, l2_raw_pre_pgs0;
    input l2_reqq_vld_vec, l2_reqq_qid;
    input ptw_xbar_hit_lvl, ptw_mbuf_twu_lvl, ptw_fault_any;
    input tlbiva_cur_st;
  endclocking

endinterface : mmu_dut_probes_if

`endif // MMU_DUT_PROBES_IF_SV
