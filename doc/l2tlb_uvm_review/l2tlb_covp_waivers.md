# L2TLB Coverage Waivers

Date: 2026-06-22
Author: IC1

This document records all structurally unreachable or non-functional coverage items
identified during L2TLB coverage closure. Each waiver explains why the item cannot
be hit and recommends the waiver tier.

## Summary

| Category | Count | Reason |
|----------|-------|--------|
| Structurally unreachable (par_fail stub) | 5 | `final_par_fail = 1'b0` hardcoded in RTL |
| Structurally unreachable (req=0 with write=1) | 2 | Cannot have TLB writes without request |
| Structurally unreachable (2-bit FSM) | 2 | 4-state FSM exhausts 2-bit encoding |
| False combinational path | 1 | vld=0 with miss=1 impossible |
| DFT/scan static signals | 5 | `pad_yy_icg_scan_en` static during functional sim |
| Mid-test reset required | 5 | `cpurst_b` 1→0 needs reset injector |
| **Total** | **20** | |

---

## 1. COND 869: final_tlb_hit combo 1 1 0 [WAIVER]

**Expression**: `(hit_sum==3'b1) & cmp_va & !par_fail`
**Missing**: `par_fail=1` → term 3 = 0
**Reason**: `mmu_l2tlb.sv:865` — `assign final_par_fail = 1'b0;` hardcoded stub.
**Recommendation**: Waiver. Remove when RTL parity logic is implemented.

## 2. COND 870: final_tlb_hit_mult combo 1 1 1 0 [WAIVER]

**Expression**: `cmp_va & !miss & !hit & !par_fail`
**Missing**: `par_fail=1` → term 4 = 0
**Reason**: Same as item 1.

## 3. COND 872: l2tlb_miss combo 0 1 [WAIVER]

**Expression**: `(vld&cmp&miss) | par_fail`
**Missing**: sub=0, par_fail=1
**Reason**: Same as item 1.

## 4. COND 1167: final_l1tlb_cmplt combo 1 1 0 1 [WAIVER]

**Expression**: `vld & cmp_va & !par_fail & (!ptw_en | !miss)`
**Missing**: par_fail=1 → term 3 = 0
**Reason**: Same as item 1.

## 5. COND 1186 sub: l2tlb_l1itlb_pgflt combo 0 1 1 1 [WAIVER]

**Expression**: `vld & !ptw_en & l2tlb_miss & (acc_type==3'b011)`
**Missing**: vld=0 while miss=1 (contradiction)
**Reason**: l2tlb_miss requires final_vld=1. vld=0 with miss=1 is a false combinational path.
**Recommendation**: Waiver. Functional combo 1 1 1 1 covered by pgflt_ptw_off_vseq.

## 6. COND 553: rrpv_write_ptw combo 0 1 1 [WAIVER]

**Expression**: `req & (acc_type==3'b101) & write`
**Missing**: req=0, acc_type=PTW write, write=1
**Reason**: PTW write cannot occur without an active arbiter request. Protocol constraint.

## 7. COND 555: rrpv_write_tlboper combo 0 1 1 1 [WAIVER]

**Expression**: `req & (acc_type==3'b001) & write & tag_msb`
**Missing**: req=0, acc_type=TLBop, write=1, tag_msb=1
**Reason**: Same as item 6 — TLBop write requires active req.

## 8. LINE 1382 default FSM branch [WAIVER]

**Code**: `pfu_nxt_st = PFU_IDLE`
**Reason**: 2-bit FSM with 4 states (IDLE/CHK/DENY/OK). All encodings enumerated. Default unreachable.
**Recommendation**: Waiver (good defensive coding, never executes).

## 9. BRANCH 1354 default case [WAIVER]

Same as item 8 — default branch of `case(pfu_cur_st)`.

## 10-14. Toggle: pad_yy_icg_scan_en [WAIVER]

**Affected**: mmu_l2tlb, mmu_l2tlb_reqq, mmu_l2tlb_reqq_entry (×5 entries)
**Reason**: Static DFT signal, tied low during functional simulation.

## 15-19. Toggle: cpurst_b 1→0 [NEEDS RESET INJECTOR]

**Affected**: mmu_l2tlb, mmu_l2tlb_reqq, mmu_l2tlb_reqq_entry, mmu_l2tlb_mb, mmu_l2tlb_mb_entry
**Solution**: Run with `+MMU_TLBOP_RESET_MODE=tlbwr_wfg`

## 20. FSM PFU_CHK→PFU_IDLE [NEEDS RESET INJECTOR]

**Solution**: Same as items 15-19 — mid-test reset.

---

## Verified Coverage Status

All other 243 items (263 - 20 waived) have corresponding vseqs and test wrappers
as documented in `l2tlb_covp_closure_implementation_log.md`.

### Key vseq-to-coverage mapping:

| vseq | Items covered | Test wrapper |
|------|--------------|--------------|
| pfu_fullpath_vseq | LINE 1368, FSM CHK→DENY, BRANCH CHK | test_mmu_l2tlb_cov_pfu_chk_deny |
| pfu_fault_sweep_vseq | COND 1409/1418 all sub-expr | test_mmu_l2tlb_cov_pfu_fault_sweep |
| arb_write_sweep_vseq | COND 553/555/1041/934/939 | test_mmu_l2tlb_cov_arb_write_sweep |
| multiway_hit2_vseq | COND 814/816 remaining patterns | test_mmu_l2tlb_cov_multiway_hit2 |
| pgflt_ptw_off_vseq | COND 1186/1204/1167 | test_mmu_l2tlb_cov_pgflt_ptw_off |
| sva_targeted_vseq | SVA rrpv_wbuf×3 + mb×3 + rrpv×1 | test_mmu_l2tlb_cov_sva_targeted |
| sva_closure_vseq | SVA all 7 | test_mmu_l2tlb_cov_sva_closure |
| mb_cond_vseq | MB COND + MB entry toggle | test_mmu_l2tlb_cov_mb_cond |
| toggle_sweep_vseq | High PPN/PA toggle | test_mmu_l2tlb_cov_toggle_sweep |
| ptw_disabled_vseq etc. | COND 1005/1021/1031 | test_mmu_l2tlb_cov_ptw_disabled |
| cond_769_vseq | COND 769 | test_mmu_l2tlb_cond_769 |

### Run all coverage closure tests:

```bash
make covp TEST=test_mmu_l2tlb_cov_pfu_chk_deny
make covp TEST=test_mmu_l2tlb_cov_pfu_fault_sweep
make covp TEST=test_mmu_l2tlb_cov_arb_write_sweep
make covp TEST=test_mmu_l2tlb_cov_multiway_hit2
make covp TEST=test_mmu_l2tlb_cov_pgflt_ptw_off
make covp TEST=test_mmu_l2tlb_cov_sva_targeted
make covp TEST=test_mmu_l2tlb_cov_sva_closure
make covp TEST=test_mmu_l2tlb_cov_mb_cond
make covp TEST=test_mmu_l2tlb_cov_toggle_sweep
make covp TEST=test_mmu_l2tlb_cov_mid_reset PLUSARGS="+MMU_TLBOP_RESET_MODE=tlbwr_wfg"
```
