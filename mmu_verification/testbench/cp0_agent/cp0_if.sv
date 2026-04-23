// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_if.sv
// Phase 2: CP0/CSR <=> MMU interface
// DUT port group: cp0_mmu_* / mmu_cp0_* / cp0_yy_priv_mode
//                 + Group 13 (global enable / TLBOper done)
//                 + Group 14 (CSR sub-field controls)
// (ct_mmu_top.v lines ~18-50)
// =============================================================================
`ifndef CP0_IF_SV
`define CP0_IF_SV

interface cp0_if (
  input bit clk_i,
  input bit rst_ni
);

  // =========================================================================
  // CSR Write Controls (DUT Inputs — driven by cp0_driver)
  // =========================================================================
  logic        cp0_mmu_wreg;
  logic [1:0]  cp0_mmu_reg_num;
  logic        cp0_mmu_satp_sel;
  logic [63:0] cp0_mmu_wdata;

  // =========================================================================
  // Mode / Permission CSR Bits (DUT Inputs)
  // =========================================================================
  logic        cp0_mmu_cskyee;      // Group 14: T-Head extension enable
  logic        cp0_mmu_icg_en;      // Clock-gate enable
  logic        cp0_mmu_maee;        // M-mode address extension enable
  logic [1:0]  cp0_mmu_mpp;         // Previous privilege (for MPRV)
  logic        cp0_mmu_mprv;        // Modify PRiVilege
  logic        cp0_mmu_mxr;         // Make eXecutable Readable
  logic        cp0_mmu_no_op_req;   // Halt MMU
  logic        cp0_mmu_ptw_en;      // PTW enable (disable → L2 miss → pgflt)
  logic        cp0_mmu_sum;         // Supervisor User Memory
  logic        cp0_mmu_tlb_all_inv; // CP0-path global TLB invalidation
  logic [1:0]  cp0_yy_priv_mode;    // Current privilege: 00=U, 01=S, 11=M

  // =========================================================================
  // DUT Feedback Outputs (sampled by cp0_monitor)
  // =========================================================================
  logic        mmu_cp0_cmplt;       // CSR R/W complete
  logic [63:0] mmu_cp0_data;        // CSR read data
  logic [63:0] mmu_cp0_satp_data;   // SATP read-back
  logic        mmu_cp0_tlb_done;    // TLBOper FSM completion (Group 13)

  // =========================================================================
  // Global Broadcast (Group 13)
  // =========================================================================
  logic        mmu_xx_mmu_en;       // MMU enabled global broadcast
  logic        mmu_yy_xx_no_op;     // MMU no-op status broadcast

  // =========================================================================
  // Clocking Block — Active Driver
  // =========================================================================
  clocking driver_cb @(posedge clk_i);
    default input #1step output #1;
    output cp0_mmu_wreg, cp0_mmu_reg_num, cp0_mmu_satp_sel, cp0_mmu_wdata;
    output cp0_mmu_cskyee, cp0_mmu_icg_en, cp0_mmu_maee;
    output cp0_mmu_mpp, cp0_mmu_mprv, cp0_mmu_mxr;
    output cp0_mmu_no_op_req, cp0_mmu_ptw_en, cp0_mmu_sum;
    output cp0_mmu_tlb_all_inv;
    output cp0_yy_priv_mode;
    input  mmu_cp0_cmplt, mmu_cp0_data, mmu_cp0_satp_data, mmu_cp0_tlb_done;
    input  mmu_xx_mmu_en, mmu_yy_xx_no_op;
  endclocking

  // =========================================================================
  // Clocking Block — Monitor
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input cp0_mmu_wreg, cp0_mmu_reg_num, cp0_mmu_satp_sel, cp0_mmu_wdata;
    input cp0_mmu_cskyee, cp0_mmu_icg_en, cp0_mmu_maee;
    input cp0_mmu_mpp, cp0_mmu_mprv, cp0_mmu_mxr;
    input cp0_mmu_no_op_req, cp0_mmu_ptw_en, cp0_mmu_sum;
    input cp0_mmu_tlb_all_inv;
    input cp0_yy_priv_mode;
    input mmu_cp0_cmplt, mmu_cp0_data, mmu_cp0_satp_data, mmu_cp0_tlb_done;
    input mmu_xx_mmu_en, mmu_yy_xx_no_op;
  endclocking

endinterface : cp0_if

`endif // CP0_IF_SV
