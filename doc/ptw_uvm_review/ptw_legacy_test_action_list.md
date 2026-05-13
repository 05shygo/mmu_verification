# PTW Legacy Test Action List - Stage 0

This file freezes how existing verification plan rows and UVM tests may be used after `ptwspec.md` became the PTW source of truth. No test code is changed in stage 0.

Action meanings:

| Action | Meaning |
| --- | --- |
| keep | Existing intent is compatible, but later stages may still add source evidence. |
| modify | Keep the test or plan row but change expected behavior, checks, naming, metadata, or binding later. |
| split | Existing test mixes multiple source requirements and must be split later. |
| reassign | Keep as non-PTW-source evidence, usually system, L1DTLB, L2TLB, or consumer-only. |
| obsolete-by-spec | Do not use the old expected result as PTW closure. |
| illegal-stimulus-only | Legal only in a negative/stress list and not normal DUT fail closure. |

## Blocking Conflicts

These items are frozen as not usable for PTW source closure until corrected.

| Legacy item | Current location | Action | Reason | Replacement / future binding |
| --- | --- | --- | --- | --- |
| `test_xbar_twu_round_robin` / `XBAR-002` round-robin expectation | `mmu_verification/testbench/test/ptw_tests`, `doc/MMU_Traceability_Matrix.csv` | obsolete-by-spec | PTW xbar closure is hash/target-mask/ready-hold based, not round-robin or idle fairness. | `PTW-ADD-012`, `PTW-SVA-REQ-001..003`, `PTW-SVA-XBAR-001..006`. |
| `test_xbar_1to4_distribution` if judged by idle scan / distribution fairness | `ptw_tests` | modify | Distribution coverage is auxiliary only unless it proves hash target and mask behavior. | Reframe as hash target and backpressure cover. |
| `TC-XBAR-IDLE-FIRST-*`, `TC-XBAR-POINTER-FALLBACK-*`, fairness-only xbar rows | `doc/MMU_Traceability_Matrix.csv` | obsolete-by-spec for PTW source closure | These are implementation/fairness expectations and conflict with or distract from hash closure. | Keep only as implementation debug if desired; not PTW-AUD closure. |
| `test_pte_reserved_bits` expecting reserved/RSW/high-bit fault | `ptw_tests` | obsolete-by-spec for old expected; modify test | `PTE[58:38]` high reserved and RSW do not cause PTW page fault; RSW enters `flg[8:7]`. | `PTW-ADD-001/002/034`, `PTW-SVA-CHK-009`, `PTW-SVA-ARB-008`. |
| Any strong-order / PTE extension reserved fault expected | legacy plan rows and future tests | obsolete-by-spec | PTW does not add strong-order or high reserved PTE checks beyond `ptwspec.md` rules. | Use MAEE/sysmap attribute checks instead. |
| PFU checked as load for PTE permissions | PTW/PTE/PMP legacy plans where PFU follows load rule | obsolete-by-spec for old expected; modify | PFU does not require R, MXR&&X, X, or D, but still requires V, A, U/S, write-only legality, and huge alignment. | `PTW-ADD-033`, `PTW-SVA-CHK-006`. |
| PTW memory out-of-order response tests as legal functional tests | `test_mbuf_ooo_response`, `PTW-012` sequence text, wakeup/OOO rows | illegal-stimulus-only / obsolete-by-spec | PTW->LSU is single outstanding and legal UVM does not produce OOO PTW memory response. | Keep only negative stimulus with `illegal_stimulus=1`; normal closure uses `MBUF-TP-003/004`. |
| sysmap no-hit/default flag as normal PTW MAEE expected | `test_sysmap_phase13_default_flag`, `TC-SYSMAP-NO-HIT-*` | reassign or illegal-stimulus-only | `ptwspec.md` constrains malformed/no-hit/multi-hit sysmap out of normal PTW source tests unless explicitly negative/waived. | Normal MAEE closure uses valid one-hit sysmap; default flag remains system/sysmap implementation evidence. |
| system direct-map sysmap bypass used as PTW source evidence | `test_mmu_l1dtlb_dtlb_sysmap_001`, `DTLB_SYSMAP_001`, sysmap priority/direct-map tests | reassign | Direct-map/MMU-off/M-mode sysmap behavior belongs to L1DTLB/system direct-map, not PTW source walk. | Mark `consumer-only` or L1DTLB/system evidence; not `PTW-AUD-018..020` closure. |
| satp/PMP change assumed to abort in-flight PTW | old satp/PMP hazard rows | obsolete-by-spec for old expected; split | satp/PMP update clears PDE cache only; it does not flush in-flight walk. | `PTW-ADD-010/030`, `PTW-FLOW-022`; abort is separate `PTW-ADD-024`. |
| abort same-cycle new LSU bus error expected as visible access fault | abort/bus-error legacy rows | obsolete-by-spec for old expected | A new bus error formed in abort cycle is not reported; pre-existing granted exception may be visible. | `PTW-ADD-024`, `MBUF-TP-011/012`. |

## Existing PTW Tests

| Test / row | Action | Bound IDs | Stage-0 notes |
| --- | --- | --- | --- |
| `test_ptw_satp_load_basic` / `PTW-001` | modify | `PTW-AUD-021`, `PTW-ADD-030` | SATP must be checked at usage/refill points; simple SATP root smoke is provisional until source context sampling exists. |
| `test_ptw_satp_load_dual_switch` / `PTW-002` | split + modify | `PTW-AUD-007/021`, `PTW-ADD-010/030` | Separate satp clear-only behavior from context sampling and from illegal mid-walk no-abort cases. |
| `test_ptw_l2_pde_hit_direct` / `PTW-003` | modify | `PTW-AUD-005`, `PDE-TP-003/004` | Must prove skipped fst/scd memory reads and L2-priority behavior, not only faster completion. |
| `test_ptw_l2_pde_miss_walk` / `PTW-004` | modify | `PTW-FLOW-002/003`, `PDE-TP-001` | Need source level trace and PDE update evidence. |
| `test_ptw_l1_pde_hit` / `PTW-006` | modify | `PTW-FLOW-015/016`, `PDE-TP-002` | Need skip-fst proof and final 2M/4K distinction. |
| `test_ptw_l1_pde_miss_walk` | modify | `PTW-FLOW-002/003`, `PDE-TP-001/002` | Keep as smoke until source monitor/SB added. |
| `test_ptw_l0_pte_read_basic` / `PTW-009` | modify | `PTW-FLOW-003`, `PTW-ADD-034` | Must compare raw PTE to refill tag/data/flg, not only walk completion. |
| `test_ptw_l0_pte_permission_check` / `PTW-010` | split | `PTW-ADD-017/018/019/033` | Split by fetch/load/store/PFU and A/D/U/S/SUM/MXR/write-only. |
| `test_twu_concurrent_4way` / `PTW-011` | keep as stress + modify | `PTW-AUD-008/015`, `PTW-INFRA-008` | Useful stress, but closure requires type/id, hash target, mbuf ownership, and source matching. |
| `test_twu_concurrent_same_vpn` / `PTW-012` | modify | `PTW-AUD-015`, `MBUF-TP-*` | Remove OOO response assumptions. Same-VPN behavior must not rely on illegal PTW memory response order. |
| `test_mbuf_credit_management` / `PTW-013` | modify | `PTW-AUD-015`, `MBUF-TP-001..004` | Bind to entry allocation and single outstanding semantics. |
| `test_mbuf_full_backpressure` | modify | `PTW-AUD-015`, `PTW-ADD-021` | Backpressure is useful but not enough without source allocation/ready evidence. |
| `test_pte_v_bit_zero` / `PTW-015` | keep + modify | `PTW-AUD-012/013`, `PTW-FLOW-012..014` | Keep page fault intent; add level/type and no-side-effect checks. |
| `test_pte_rw_both_zero` / `PTW-016` | modify | `PTW-AUD-012/013`, `PTW-ADD-016/017` | Expected must use design write-only/nonleaf rules, not generic reserved-rule shorthand. |
| `test_pte_x_bit_mxr_mix` | modify | `PTW-ADD-017/018` | Keep MXR matrix but distinguish load and write-only rule. |
| `test_pte_u_bit_sum_interaction` / `PTW-020` | split | `PTW-ADD-019/030` | Split U/S/SUM from effective M/MPRV usage-point sampling. |
| `test_pte_global_bit_asid` / `PTW-022` | split | `PTW-ADD-003/034` | Split leaf global, non-leaf G no-OR, and G-not-in-flg. |
| `test_huge_page_1g_direct`, `test_huge_page_2m_direct`, `test_huge_page_4k_full_walk`, `test_huge_page_mixed` | keep + modify | `PTW-FLOW-001..003`, `PTW-ADD-004/025/034` | Keep as success smokes; add source match for page size, PPN, flg, global, target. |
| `test_pte_misaligned_ppn_1g`, `test_pte_misaligned_ppn_2m` | modify | `PTW-AUD-014`, `PTW-ADD-020`, `MAEE-TP-011` | Must prove no sysmap/degrade/refill/lower walk after align fault. |
| `test_sfence_abort_walk` / `PTW-028` | split | `PTW-AUD-007/017`, `PTW-ADD-011/024`, `MBUF-TP-009..012` | Use `tlboper_ptw_abort`; split no-outstanding, outstanding, same-cycle data, bus-error, pre-existing exception grant. |
| `test_bus_error_terminate` / `PTW-029` | modify | `PTW-AUD-016`, `PTW-ADD-023`, `PTW-FLOW-018`, `MBUF-TP-007/008` | Bus error is access fault and must not enter CHK/page-fault/PDE/refill. |
| `test_wakeup_vector_dispatch` / `PTW-030` | reassign/auxiliary | `PTW-AUD-003/023` | Wakeup/vector behavior may support consumer routing but not PTW source PTE/PMP/MAEE closure. |
| `test_tlb_busy_stall` / `PTW-031` | modify | `PTW-AUD-008/015` | Need ready/mask and mbuf ownership source evidence. |
| `test_ptw_random_walk_10k_seed` / `RANDOM-PTW-001` | keep as random only | all source families after instrumentation | Random pass alone closes nothing until source scoreboard and cover bins are active. |
| `test_ptw_walk_latency` / `PERF-PTW-001` | keep as perf only | auxiliary | Performance threshold is not functional PTW source closure. |

## Existing Arb/Bank/L2 Consumer Rows

| Test / row | Action | Bound IDs | Stage-0 notes |
| --- | --- | --- | --- |
| `test_arb_ptw_priority_highest`, `test_arb_no_double_grant`, `test_mmu_arb_refill_except_priority` | keep + modify | `PTW-ADD-006`, `PTW-INFRA-008` | Useful for arbitration evidence; must distinguish refill/page/access class and type/id payload. |
| `test_arb_reqq_preempt_lower`, `test_arb_tlboper_above_prefetch`, bank conflict rows | reassign | L2TLB/ARB auxiliary | Not PTW source closure unless directly checking PTW visible class/target fields. |
| `test_mmu_arb_vpn_match_tag_din`, `test_mmu_arb_pgs_bank_select` | modify | `PTW-ADD-004/034` | Can support refill tag/data/layout if tied to source expected. |
| L2TLB ReqQ/RRPV/Bank/MB rows that mention `mmu_ptw_thrash_vseq` | reassign | L2TLB consumer/auxiliary | These are L2TLB or performance/regression stress unless source PTW transaction evidence is added. |

## Existing PTW LSU Protocol Tests

| Test / row | Action | Bound IDs | Stage-0 notes |
| --- | --- | --- | --- |
| `test_pmbuf_serial_outstanding_001` | keep + modify | `MBUF-TP-003/004` | Compatible with single outstanding; add source request/response evidence later. |
| `test_pmbuf_addr_stable_001` | keep + modify | `MBUF-TP-003/010` | Must account for abort outstanding hold. |
| `test_pmbuf_no_tag_001` | keep | `MBUF-TP-004` | Confirms no external tag; normal response must remain in-order. |
| `test_pmbuf_inorder_resp_001` | keep + modify | `MBUF-TP-004` | Legal UVM must be in-order because PTW single outstanding; do not pair with OOO expected. |
| `test_pmbuf_ptr_hold_001` | keep + modify | `MBUF-TP-003/010` | Useful for PA/entry grant hold, especially abort outstanding. |
| `TC-MBUF-BUS-ERR-*` rows | modify | `PTW-ADD-023/024`, `MBUF-TP-007/008/011/012` | Distinguish no-abort bus error from abort same-cycle bus error. |

## Existing Sysmap / MAEE Tests

| Test / row | Action | Bound IDs | Stage-0 notes |
| --- | --- | --- | --- |
| `test_sysmap_phase13_flg_refill_region0`, `test_sysmap_phase13_flg_refill_region7` | modify | `PTW-ADD-026/029`, `MAEE-TP-009/013` | Must be tied to PTW leaf MAEE=0 source refill, not only sysmap module output. |
| `test_sysmap_phase13_cross_1g_degrade`, `test_sysmap_phase13_cross_2m_degrade` | modify | `PTW-ADD-027/028`, `MAEE-TP-005/006/008/010` | Add no-lower-walk and final PPN/page_size/flg source checks. |
| `test_sysmap_phase13_no_cross_no_degrade` | modify | `PTW-ADD-027/028`, `MAEE-TP-004/007` | Must prove no degradation and sysmap attribute substitution. |
| `test_sysmap_phase13_pa_align_1g`, `test_sysmap_phase13_pa_align_2m_4k` | modify | `PTW-ADD-020`, `MAEE-TP-011` | Alignment errors are page faults before sysmap/degrade; 4K has no huge alignment fault. |
| `test_sysmap_phase13_default_flag` | reassign or illegal-stimulus-only | none for normal PTW closure | Normal PTW sysmap malformed/no-hit is constrained away. |
| `test_mmu_sysmap_*`, `test_sysmap_hit_bypass_walk`, `test_sysmap_no_walk_required`, `test_sysmap_vs_ptw_priority` | reassign | system/sysmap or consumer-only | Do not use system direct-map/sysmap bypass behavior to close PTW MAEE source requirements. |

## Existing PMP/TWU Tests

| Test / row | Action | Bound IDs | Stage-0 notes |
| --- | --- | --- | --- |
| `TC-PTW-PMP-DENY-ACCFLT-001`, `TC-PTW-PMP-DENY-NO-REFILL-001` | modify | `PTW-ADD-013/014`, `PTW-FLOW-009..011` | Add fst/scd/thd level coverage and no mbuf/LSU/CHK/PDE side effects. |
| `TC-PTW-PMP-MMODE-L0-001`, `TC-PTW-PMP-MMODE-L1-001` | split + modify | `PTW-ADD-014/015` | Separate PMP L-bit behavior from `MPRV=1 && MPP=M` effective privilege. |
| `TC-PTW-PMP-PA-1G/2M/4K`, `TC-PTW-PMP-PA-ZERO-001` | keep + modify | `PTW-AUD-009`, `PTW-SVA-PMP-008` | Bind to PTE PA formulas per level. |
| `TC-PTW-PMP-FETCH-ZERO-001`, `TC-PTW-PMP-R-CHECK-001` | modify | `PTW-ADD-014` | Ensure fetch/load/store/PFU original type permissions match `ptwspec.md`; avoid blanket load expected. |
| `TC-PTW-PMP-PORT-MAP-001`, `TC-PTW-PMP-PORT-CONCURRENT-001` | keep as auxiliary + modify | `PTW-INFRA-006` | Port mapping helps debug but does not alone close deny/no-side-effect behavior. |

## Consumer-Only Evidence

The following may be referenced from closure reports only as `consumer-only` or `auxiliary`.

| Evidence | Allowed use | Not allowed |
| --- | --- | --- |
| `mmu_translation_sb` pass | End-to-end VA->PA/fault consumed result. | Closing PTE/PMP/PDE/MAEE/abort source correctness. |
| `mmu_l1dtlb_spec_sb` pass | L1DTLB install/fault behavior after PTW output. | Replacing PTW source target/type/id/refill/fault checks. |
| L1DTLB `test_mmu_l1dtlb_dtlb_sysmap_001` | Direct-map/sysmap consumer/system evidence. | Closing PTW MAEE leaf refill or degrade. |
| L2TLB ReqQ/RRPV/Bank tests | L2TLB consumer or storage behavior. | Closing PTW PTE/PMP/PDE/source flow. |
| Performance/random stress pass | Regression health. | Requirement closure without source scoreboard match and SVA/cover evidence. |

## Stage-0 Freeze Summary

1. `obsolete-by-spec` expected results are not deleted in this stage, but must not be cited as PTW closure.
2. Existing tests marked `modify` can still be useful smoke tests, but their closure state is `provisional` until source-side checks exist.
3. Illegal/stress tests must be isolated from normal PTW regression gate and report `illegal_stimulus=1`.
4. Future code changes to these tests belong to stage 6 or stage 7 unless the staged plan explicitly assigns them earlier.
