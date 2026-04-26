// =============================================================================
// L2 Reqq 信用/队列窗口 SVA (bind mmu_l2tlb_reqq) — Phase 7
// 验证意图: 发到 arb 的 issue 在 valid 时队列索引与类型/VA 不 X; 信用回送为单比特已知电平
// 注: ITLB(entry0) 与 DTLB(entry1..) 在 Reqq 上独立分配/回收，可并发有请求，互不排斥 — 不要断言
//     “同一周期仅一类 L1 TLB 可分配”。
// =============================================================================
`timescale 1ns/1ps

module credit_sva #(parameter int VPN_W = 27) (
    input logic reqq_clk,
    input logic cpurst_b,
    input logic issue_valid,
    input logic [2:0] issue_queue_id,
    input logic [2:0] issue_type,
    input logic [VPN_W-1:0] issue_vpn,
    input logic i_credit_return,
    input logic d_credit_return
);

  a_issue_fields_known: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    issue_valid
      |-> (! $isunknown(issue_queue_id) && ! $isunknown(issue_type) && ! $isunknown(issue_vpn)));

  a_credit_retn_bits_known: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (! $isunknown(i_credit_return) && ! $isunknown(d_credit_return)));

endmodule
