// =============================================================================
// mmu_arb 仲裁 SVA (bind mmu_arb) — Phase 7
// 验证意图: 5 路 grant 多 hot 中至多一路；有全局请求时 five-hot 中恰一路；PTW 写两拍流水在复位下清零 (F5.NEW.2 伪代码 sva_ptw_write_pipe_reset_safe)
// =============================================================================
`timescale 1ns/1ps

module mmu_arb_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic arb_l2tlb_req,
    input logic ptw_write_req1,
    input logic ptw_write_req2,
    input logic arb_ptw_write_grant,
    input logic arb_ptw_grant,
    input logic arb_tlboper_grant,
    input logic arb_reqq_grant,
    input logic arb_pfu_grant
);

  // 验证意图: 5 个 grant 在任意周期至多 1 个为 1（固定优先级 + ptw 写时序的互斥结构）
  a_grant_onehot0: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    $onehot0({arb_pfu_grant, arb_reqq_grant, arb_tlboper_grant, arb_ptw_grant, arb_ptw_write_grant}));

  // 验证意图: 有 arb_l2tlb_req 时，上述五路中恰有一路置位（与 OR 合路一致）
  a_grant_onehot_when_req: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_l2tlb_req |-> $onehot({arb_pfu_grant, arb_reqq_grant, arb_tlboper_grant, arb_ptw_grant, arb_ptw_write_grant}));

  // 验证意图: 同步复位低有效期间/释放后的采样边沿，PTW 两拍写请求寄存器被清零
  a_ptw_write_pipe_reset_safe: assert property (@(posedge forever_cpuclk)
    !cpurst_b |-> (!ptw_write_req1 && !ptw_write_req2));

endmodule
