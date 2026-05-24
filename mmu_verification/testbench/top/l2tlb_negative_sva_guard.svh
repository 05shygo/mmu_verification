`ifndef L2TLB_NEGATIVE_SVA_GUARD_SVH
`define L2TLB_NEGATIVE_SVA_GUARD_SVH

`define L2TLB_NEG_DISABLE (!cpurst_b || l2tlb_negative_pkg::l2tlb_neg_sva_disable)

`endif // L2TLB_NEGATIVE_SVA_GUARD_SVH
