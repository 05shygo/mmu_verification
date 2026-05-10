# L1DTLB 3.11 Reference Model and Scoreboard Traceability

This file tracks implementation status for `l1dtlb_function_description.md`
section 3.11.  It follows the same conservative rule as
`l1dtlb_3_9_3_10_traceability.md`: a row is `implemented` only when there is a
named reference-model structure, scoreboard check, monitor field, SVA, cover
point, or directed scenario that checks the required behavior.  A row is not
`implemented` merely because the requirement is described in the spec.

## Status Legend

| Status | Meaning |
| --- | --- |
| implemented | Implemented with concrete reference-model state, scoreboard check, SVA, cover, monitor field, or directed stimulus. |
| partial | Some support exists, but the row is not fully modeled or proven. |
| planned | Requirement is documented or a wrapper exists, but concrete semantic checking/modeling is still needed. |
| formal-only | Requirement needs equivalence/formal setup or additional controllable probes before simulation can prove it. |

## Key Implementation Files

| Area | File |
| --- | --- |
| Sv39 reference model | `mmu_verification/testbench/env/mmu_ref_model.svh` |
| Translation scoreboard | `mmu_verification/testbench/env/mmu_translation_sb.svh` |
| L1DTLB spec scoreboard | `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh` |
| Credit scoreboard | `mmu_verification/testbench/env/mmu_credit_sb.svh` |
| DUT probe interface | `mmu_verification/testbench/env/mmu_dut_probes_if.sv` |
| LSU monitor/transaction | `mmu_verification/testbench/lsu_agent/lsu_monitor.svh`, `mmu_verification/testbench/lsu_agent/lsu_txn.svh` |
| L1DTLB SVA | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| Whitebox covergroup | `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh` |
| Directed vseq | `mmu_verification/testbench/env/mmu_l1dtlb_vseq_lib.svh` |
| Wrapper suite | `mmu_verification/testbench/test/l1dtlb_tests/l1dtlb_tests_suite.svh` |

## 3.11.1 Overall Partition Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_RM_SB_PARTITION_001 | partial | `mmu_ref_model.svh` models architectural Sv39/PMP/sysmap state, while `mmu_l1dtlb_spec_sb.svh` covers some L1DTLB micro-architecture checks. There is not yet a complete L1DTLB reference sub-model with TLB/MB/expt/credit/T0/T1 state. |
| L1DTLB_RM_SB_PARTITION_002 | partial | `mmu_translation_sb.svh` checks LSU final PA/fault results and contains a DTLB exception CAM shadow, but still uses broad replay/timing waive paths rather than a fully tokenized L1DTLB oracle. |
| L1DTLB_RM_SB_PARTITION_003 | partial | `mmu_l1dtlb_spec_sb.svh` checks reset, busy, MB state-derived signals, refill onehot, expt fault exclusivity, L2 request payload X/range, credit range, and scenario gates. Full semantic MB allocation/install/expt lifecycle prediction remains planned. |
| L1DTLB_RM_SB_PARTITION_004 | partial | `mmu_credit_sb.svh` tracks external outstanding requests and drain status. Exact L1DTLB scheduler credit shadow with return+fire conservation is covered mainly by SVA/spec SB range checks, not one shared model. |
| L1DTLB_RM_SB_PARTITION_005 | implemented | `mmu_dut_probes_if.sv` exposes L1D MB, entry valid, L2 request, hit/miss, refill, exception write, PTW/L2 refill, flush and invalidate probes for debug/whitebox checks. |
| L1DTLB_RM_SB_PARTITION_006 | partial | PLRU exact victim is kept out of main translation pass/fail; PLRU onehot/update checks are SVA/coverage only. Need audit guard to prevent future scoreboard code from reintroducing exact-victim assumptions. |

## 3.11.2 Reference Model Data Structure Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_RM_ENTRY_SHADOW | planned | No complete L1DTLB entry shadow array in the reference model. `mmu_dut_probes_if.sv` exposes entry valid and hit entry VPN/PPN/page size, and translation SB uses final response comparison, but it does not independently maintain valid/VPN/PPN/page-size/flag[13:0] for all entries. |
| L1DTLB_RM_ENTRY_FLAGS | partial | `mmu_ref_model.svh` models PTE permission and attributes at architectural translation level. L1DTLB cached `flag[13:0]` semantics are not represented as a reusable L1 entry object for hit prediction. |
| L1DTLB_RM_ENTRY_ASID_GLOBAL | partial | Ref model tracks SATP/ASID; L1DTLB-specific rule that entry has no ASID/global and L1 invalidates are full-clear is partly checked through invalidate tests/SVA. Needs explicit L1 entry shadow update policy. |
| L1DTLB_RM_MULTI_HIT_POLICY | partial | Multi-hit is treated as diagnostic SVA/coverage; no main scoreboard failure or priority oracle is enabled, which matches current spec boundary. |
| L1DTLB_RM_MB_SHADOW | planned | No full MB shadow model exists in UVM. `mmu_l1dtlb_spec_sb.svh` checks MB state-derived signals through probes, but does not predict allocation, state transitions, payload, or lifecycle independently. |
| L1DTLB_RM_MB_STATE_DERIVED | implemented | `mmu_l1dtlb_spec_sb.svh` checks `entry_vld`, `ready`, `wfc`, and `wfi` against `l1d_mb_state`; SVA also covers MB state-derived invariants. |
| L1DTLB_RM_MB_4K_CAM | partial | SVA/top checks no-alloc on MB CAM hit and same-4K dedup. Reference model does not yet maintain a 4K VPN CAM shadow for all miss requests. |
| L1DTLB_RM_EXPT_SHADOW | partial | `mmu_translation_sb.svh` has `m_dtlb_expt_cam[8]` with IID/VPN/fault/EID and clears on flush/invalidate paths. It is primarily used to waive/diagnose translation compare, not as a complete L1DTLB expt lifecycle oracle. |
| L1DTLB_RM_EXPT_BIND_MB | partial | Expt write EID/IID/VPN/fault probes exist and SVA checks fault class. Exact binding to corresponding MB entry release is only partially checked. |
| L1DTLB_RM_CREDIT_SHADOW | partial | Scheduler credit range/conservation is covered by SVA and `l1d_sched_credit_cnt` probe. UVM does not yet expose one exact reusable L1DTLB credit shadow shared by credit SB and spec SB. |
| L1DTLB_RM_T0_T1_TOKEN | partial | `mmu_l1dtlb_spec_sb.svh` now samples per-pipe T0 tokens and retains the previous-cycle token as T1 ownership for page/access fault overlap checks. It is still a lightweight checker, not a complete predicted-path queue with effective privilege/MXR/SUM state. |

## 3.11.3 Lookup, Permission, PA, and Attribute Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_LOOKUP_PIPE_TOKEN | partial | `mmu_l1dtlb_spec_sb.svh` has a per-pipe T0/T1 token stream carrying VA/VPN/IID/abort/store, response fault bits, hit/miss/MB-hit, and expt-match diagnostics. Effective mode and full predicted path remain planned. |
| L1DTLB_LOOKUP_PAGE_SIZE_MATCH | partial | Page-size covers and hit probes exist for 4K/2M/1G. Exact comparator-bound prediction from a L1 entry shadow is not implemented. |
| L1DTLB_LOOKUP_PA_ASSEMBLY | partial | Translation SB compares final PA using `mmu_ref_model.svh`. It does not yet verify PA was generated from the specific L1DTLB hit entry shadow except through probes/debug. |
| L1DTLB_LOOKUP_ATTR_COMPARE | partial | Translation SB has architectural response checks; full sec/share/bufferable/cacheable/SO comparison against cached flag[13:0] and sysmap direct-map source remains partial. |
| L1DTLB_LOOKUP_PAGE_FAULT_RULES | partial | `mmu_ref_model.svh` models Sv39 permission and page faults; L1DTLB hit-side truth table for load/store/AMO, MXR, SUM, A/D, U/S, VA illegal is covered by directed tests and translation SB but not as a complete flag truth-table scoreboard. |
| L1DTLB_LOOKUP_PF_PA_VLD_PAIR | partial | SVA checks page_fault has pa_vld, and `mmu_l1dtlb_spec_sb.svh` now checks page_fault against the current T0 token and same-cycle `pa_vld`. Full permission/source prediction remains partial. |
| L1DTLB_LOOKUP_T1_ACCESS_FAULT | partial | `mmu_l1dtlb_spec_sb.svh` now checks access_fault against the previous-cycle per-pipe T1 token. Full PMP/PTW/PMP-source prediction remains partial. |
| L1DTLB_LOOKUP_FAULT_OVERLAP | partial | `mmu_l1dtlb_spec_sb.svh` no longer uses raw same-cycle page/access mutual exclusion. It allows same-cycle page_fault/access_fault when they belong to separate T0/T1 tokens, and reports `FAULT_SAME_TOKEN` when the T1 token already reported page_fault at T0. |
| L1DTLB_LOOKUP_DIRECT_MAP | partial | Direct-map terminal response assertions and sysmap tests exist. MPRV non-M split and full sysmap attribute equivalence remain partial. |
| L1DTLB_LOOKUP_STAMO_PIPE1 | partial | STAMO pipe1 bypass and pipe0 negative SVA/cover exist; full PA/attribute source and no-side-effect scoreboard is partial. |

## 3.11.4 Miss Buffer, L2 Request, and Legal No-Response Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_MB_CAM_HIT_NO_RESPONSE | partial | SVA checks no allocation on CAM hit. `mmu_l1dtlb_spec_sb.svh` now records `mb_cam_hit` legal-no-response reason counts and checks no T0 terminal response for the owning token. Full wakeup/replay lifecycle closure remains partial. |
| L1DTLB_MB_DUAL_SAME_4K | implemented | Same-4K dual miss dedup assertions/covers exist. |
| L1DTLB_MB_DUAL_DIFF_TWO_FREE | partial | Dual-diff allocation count/distinct ID checks exist; exact lowest-free selection remains partial. |
| L1DTLB_MB_DUAL_DIFF_ONE_FREE_AGE | planned | One-free cover exists, but IID age comparison with wraparound is not fully modeled or checked. |
| L1DTLB_MB_SINGLE_OR_FULL | partial | MB full no-alloc checks and busy check exist. `mmu_l1dtlb_spec_sb.svh` now records `mb_full` and `busy_sleep` legal-no-response reason counts. Exact replay lifecycle tracking remains partial. |
| L1DTLB_MB_ABORT_SIDE_EFFECT | implemented | Abort blocks miss allocation and exception consumption through SVA/spec checks. Abort+hit response/attr preservation remains a separate partial row in 3.10. |
| L1DTLB_L2_ONE_REQ_PER_CYCLE | implemented | Scheduler SVA checks one request channel and issue/grant behavior. |
| L1DTLB_L2_OLD_MB_PRIORITY | implemented | Scheduler old-MB-over-bypass assertion and cover exist. |
| L1DTLB_L2_BYPASS_ALLOC_ISSUE | implemented | Scheduler bypass payload assertions and MB issue assertions exist. |
| L1DTLB_L2_PAYLOAD | implemented | L2 request valid/VPN/EID/is_load X/range checks exist in spec SB and scheduler/top SVA. |
| L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY | partial | `mmu_l1dtlb_spec_sb.svh` now records reason-coded legal-no-response counters for MB CAM hit, MB full, abort mask, flush kill, busy sleep, and one-free priority drop. Transaction-level lifecycle closure and scoreboard-owned replay termination remain partial. |
| L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT | partial | Abort/CAM/full/flush negative checks exist in SVA. `mmu_l1dtlb_spec_sb.svh` now adds token-local no-T0-terminal guards, next-cycle no-T1-access-fault guards for reason-coded no-response tokens, abort miss/expt side-effect guards, and flush no-refill/no-expt/no-wakeup guards; priority-drop remains reason-counted until an allocation-winner probe/model is available. Full side-effect matrix across all stale/refill/replay cases remains partial. |

## 3.11.5 Refill, Install, and Exception Lifecycle Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_REFILL_VALID_WFC_ONLY | implemented | SVA checks fault/normal refill requires a WFC entry; stale refill cover exists. |
| L1DTLB_REFILL_STALE_NO_SIDE_EFFECT | partial | Stale/ABT refill covers and some side-effect guards exist. Strong no-write/no-expt/no-wakeup checks for all stale states remain partial. |
| L1DTLB_INSTALL_ONE_PER_CYCLE | implemented | Install onehot/refill index assertions exist. |
| L1DTLB_INSTALL_PRIORITY | implemented | WFI > PTW > L2 priority assertions exist. |
| L1DTLB_INSTALL_MULTI_WFI_LOWEST | implemented | Lowest-WFI helper/assertion exists. |
| L1DTLB_INSTALL_WFI_DATA_HOLD | implemented | WFI data stability and final install payload match assertions exist. |
| L1DTLB_INSTALL_VISIBILITY | partial | Install release cover exists; exact same-cycle miss / next-cycle hit boundary needs stronger directed scoreboard. |
| L1DTLB_FAULT_REFILL_NO_TLB_WRITE | partial | Expt write assertions exist; all mixed normal+fault collision no-TLB-write cases remain partial. |
| L1DTLB_FAULT_DUAL_WRITE | implemented | Dual fault write cover and same-EID negative assertion exist. |
| L1DTLB_FAULT_L2_PAGE_ONLY | implemented | `a_l2_fault_is_page_fault_only` and expt class assertions cover L2 access-fault negative. |
| L1DTLB_EXPT_REPLAY_TIMING | partial | Translation SB has expt CAM shadow and timing waive logic; `mmu_l1dtlb_spec_sb.svh` now adds tokenized page-fault T0 / access-fault T1 ownership checks. Broad translation-SB waive paths still remain. |
| L1DTLB_EXPT_REPLAY_RELEASE | partial | Expt consume/wakeup checks exist; exact MB release tie and no-new-allocation on replay are partial. |
| L1DTLB_EXPT_TLB_HIT_VIOLATION | implemented | Hit-rd assertion prevents same request TLB hit and expt hit. |

## 3.11.6 Flush, Invalidate, Reset, and PLRU Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_RESET_STATE | partial | Entry/MB/credit reset checks exist in spec SB and SVA. Exception array reset direct visibility remains partial. |
| L1DTLB_CLR_REGS_TLBOPER | implemented | Top assertions check regs/tlboper clear entries. |
| L1DTLB_CLR_VA8_ALIAS | implemented | Per-entry VPN probe and SVA now prove low-8 VA invalidation exactly; `DTLB_INV_VA8_alias_001` and spec-SB `va8_inv` gate exercise the directed alias case. |
| L1DTLB_INV_HIT_SAME_CYCLE | partial | Directed wrapper/scenario exists; exact same-cycle old-hit boundary is not fully asserted. |
| L1DTLB_INV_INSTALL_SAME_ENTRY | implemented | SVA checks clear-over-install priority for selected entries and C020/spec-SB counters cover invalidate or full-clear overlap with install. |
| L1DTLB_RTU_FLUSH_SCOPE | partial | Flush side-effect guards and MB/expt CAM flush assertions exist. Need model-level distinction that RTU flush clears MB/expt but not necessarily all TLB entries. |
| L1DTLB_MB_FLUSH_RACE | implemented | MB entry WFG/WFC/WFI flush race assertions and covers exist. |
| L1DTLB_ABT_LATE_REFILL | partial | ABT/stale refill cover exists; full no-TLB/no-expt/no-wakeup scoreboard remains partial. |
| L1DTLB_PLRU_BLACKBOX_BOUNDARY | implemented | PLRU onehot/update SVA/cover exists and exact victim is not used for translation pass/fail. |

## 3.11.7 Scoreboard Checklist Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_SB_LSU_T0_T1_QUEUE | partial | `mmu_l1dtlb_spec_sb.svh` maintains current T0 and previous-cycle T1 tokens per LSU pipe for fault ownership. It is not yet a full queue for replay/no-response lifecycle prediction. |
| L1DTLB_SB_PAGE_FAULT_PAIRING | partial | `mmu_l1dtlb_spec_sb.svh` checks page_fault belongs to the current non-aborted T0 token and has same-cycle `pa_vld`; SVA still covers the terminal shape. |
| L1DTLB_SB_ACCESS_FAULT_PAIRING | partial | `mmu_l1dtlb_spec_sb.svh` checks access_fault belongs to the previous-cycle non-aborted T1 token; full PMP/source equivalence remains partial. |
| L1DTLB_SB_FAULT_OVERLAP_GUARD | partial | Raw same-cycle page/access exclusivity was removed from `mmu_l1dtlb_spec_sb.svh`; overlap is now qualified by token ownership and only a T1 token that already reported page_fault at T0 is treated as same-token dual-fault. |
| L1DTLB_SB_ATTR_COMPARE | partial | Final translation checks exist; complete L1DTLB attribute source compare is partial. |
| L1DTLB_SB_L2_REQ_CREDIT | partial | L2 request payload/range, reset credit, credit-zero info diagnostics, and credit range checks exist. Shared exact UVM credit shadow with return+fire conservation remains planned/SVA-owned. |
| L1DTLB_SB_BUSY | implemented | `mmu_lsu_tlb_busy == |l1d_mb_vld` is checked in spec SB and SVA. |
| L1DTLB_SB_WAKEUP | partial | Wakeup all-zero/all-one and known-source assertions exist. Full negative source matrix and event lifecycle closure are partial. |
| L1DTLB_SB_MB_ALLOCATION | partial | Some allocation/dedup/full assertions exist, and `mmu_l1dtlb_spec_sb.svh` now reason-codes MB CAM hit, MB full, busy sleep, and one-free priority-drop no-response observations. Full scoreboard prediction of entry id and IID-age winner remains planned. |
| L1DTLB_SB_INSTALL_EXPT | partial | Install and expt SVA coverage is strong; unified scoreboard lifecycle model remains planned. |
| L1DTLB_SB_INVALIDATE_FLUSH | partial | Clear/flush/race assertions exist; VA8 alias and clear/install overlap counters are implemented. Full reference-shadow invalidate/flush lifecycle remains partial. |
| L1DTLB_SB_SCENARIO_GATE | implemented | `mmu_l1dtlb_spec_sb.svh` consumes `L1DTLB_TC_ID`/`L1DTLB_SCENARIO_ID` and final-phase event counters. |
| L1DTLB_SB_TRACEABILITY_CLOSURE | partial | 3.9/3.10 traceability exists; this 3.11 traceability file adds scoreboard/model closure. Full regression cover closure still requires run results. |

## 3.11.8 Monitor, Probe, and UVM Landing Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_MON_LSU_FIELDS | partial | LSU interface/transaction/monitor capture VA, id, abort, store flag, pa, pa_vld-derived response, page_fault, access_fault, busy, wakeup, STAMO fields, and `dtlb_expt_match`. Effective privilege/MPRV/MXR/SUM are not carried as a per-request token. |
| L1DTLB_MON_T0_T1_EVENTS | partial | `mmu_l1dtlb_spec_sb.svh` builds an internal cycle-event/token stream from `lsu_if` and DUT probes to distinguish current T0 page-fault response from previous T1 access-fault response. Dedicated monitor transactions with effective-mode fields remain planned. |
| L1DTLB_MON_L2_PTW_REFILL | partial | DUT probes expose L1D request, L2 DTLB refill and PTW L1D refill IDs/PPNs plus PTW fault probes. A clean monitor transaction for all L1D refill fields including flag/page size/type is still partial. |
| L1DTLB_MON_CP0_SYSMAP_PMP | partial | `mmu_ref_model.svh` has CSR/PMP/sysmap FIFOs and synchronous shadow update. Per-L1DTLB request effective-mode tokenization remains planned. |
| L1DTLB_PROBE_MB | implemented | `mmu_dut_probes_if.sv` exposes MB valid/state/VPN/IID/store/ready/wfc/wfi. |
| L1DTLB_PROBE_ENTRY | partial | Entry valid, per-entry VPN, and hit entry VPN/PPN/page size are exposed. Full per-entry PPN/flag/page-size arrays are not exposed for independent entry-shadow audit. |
| L1DTLB_PROBE_L2_REQ_CREDIT | implemented | L1D L2 request valid/VPN/EID/is_load and scheduler credit are exposed. |
| L1DTLB_PROBE_HIT_MISS_EXPT | implemented | Per-pipe request VPN, hit/miss, pre_sel, expt_match and PA path probes are exposed. |
| L1DTLB_PROBE_REFILL_INSTALL | partial | Refill valid/source/index/VPN/PPN/page size and entry_upd are exposed, and selected-entry clear/install overlap is checked by SVA/SB. Refill flag payload remains partial. |
| L1DTLB_PROBE_EXPT_WRITE | implemented | Exception write valid/EID/IID/VPN/page/access fault probes are exposed. |
| L1DTLB_UVM_WORK_001_REF_SUBMODEL | partial | `mmu_l1dtlb_spec_sb.svh` now contains a dedicated lightweight per-pipe token shadow and reset/credit/refill/expt checks. Full entry/MB/expt/credit reference sub-model remains planned. |
| L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE | planned | Convert L1DTLB expt replay, T0/T1 overlap, STAMO, and direct-map/PMP cases from broad waive logic to explicit token/expt shadow explanation. |
| L1DTLB_UVM_WORK_003_CREDIT | partial | Spec SB now checks reset/range and records credit-zero request info diagnostics; exact return+fire conservation remains in SVA or future shared credit shadow. |
| L1DTLB_UVM_WORK_004_SPEC_SB | partial | Spec SB now includes T0/T1 fault ownership, stronger refill/expt payload checks, credit reset/range diagnostics, existing invalidate/install counters, and reason-coded legal-no-response counters with selected T0/T1 side-effect guards. Full MB allocation/WFI/expt lifecycle prediction remains planned. |
| L1DTLB_UVM_WORK_005_DIAG | partial | New fault ownership and legal-no-response diagnostics include cycle/pipe/IID/VA/VPN/fault/MB/refill-source style token fields plus reason counters for MB CAM, MB full, abort, flush, busy sleep, priority drop, and no-response T1 terminal violations. Full standardized diagnostics across all new checks remains partial. |
| L1DTLB_UVM_WORK_006_PLRU | implemented | Keep exact PLRU victim whitebox-only unless the spec later defines precise replacement behavior. |

## 3.11.9 Status Summary

| Status | Count | Closure meaning |
| --- | ---: | --- |
| implemented | 28 | Concrete checker, probe, SVA, coverage, or directed scenario exists and is named in this file. |
| partial | 58 | Some checker/stimulus/probe exists, but the behavior is not yet a complete scoreboard/reference-model oracle. |
| planned | 4 | The requirement is captured by the spec/audit, but concrete semantic modeling or checking is still missing. |
| formal-only | 0 | No 3.11 row is currently blocked solely on a formal setup. |

The implemented rows are strongest around reset-visible state, MB derived signals, L2 request payload/scheduling, install arbitration, selected invalidate races, scenario gates, and probe availability.  The remaining risk is not basic observability; it is missing semantic prediction for L1DTLB-local state: entry contents, MB lifecycle, exception replay, exact credit conservation, and legal no-response classification.

## 3.11.10 Open Work Packages

| Work package | Covers | Required closure |
| --- | --- | --- |
| L1 entry shadow | `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_LOOKUP_PAGE_SIZE_MATCH`, `L1DTLB_LOOKUP_PA_ASSEMBLY`, `L1DTLB_LOOKUP_ATTR_COMPARE`, `L1DTLB_SB_ATTR_COMPARE`, `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL` | Add a reusable L1DTLB entry object with valid, VPN, PPN, page size, and `flag[13:0]`; update it on reset, clear, invalidate, refill/install, and flush-scoped events; compare hit PA/fault/attribute results against this object when the entry source is observable. |
| T0/T1 token and waive removal | `L1DTLB_RM_T0_T1_TOKEN`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | Replace broad translation-SB replay/timing waives with per-pipe request tokens that explain T0 PA/page-fault ownership, T1 access-fault ownership, same-cycle overlap, abort masking, STAMO pipe1 bypass, and direct-map/PMP cases. |
| MB lifecycle and no-response taxonomy | `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_MB_CAM_HIT_NO_RESPONSE`, `L1DTLB_MB_DUAL_DIFF_ONE_FREE_AGE`, `L1DTLB_MB_SINGLE_OR_FULL`, `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_SB_MB_ALLOCATION` | Add an MB shadow that predicts allocation, 4K CAM dedup, full/drop behavior, IID-age winner when only one entry is free, WFG/WFC/WFI/ABT/fault transitions, and reason-coded legal no-response events with no illegal side effects. |
| Exception array lifecycle | `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE`, `L1DTLB_SB_INSTALL_EXPT`, `L1DTLB_PROBE_EXPT_WRITE` | Promote the existing exception CAM shadow from waive/diagnostic support to a lifecycle oracle: bind expt write to the source MB entry, check no TLB write on fault refill, predict replay page/access timing, and verify expt consume releases the matching MB entry without allocating a new one. |
| Credit conservation | `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_RM_SB_PARTITION_004`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_UVM_WORK_003_CREDIT` | Use one shared L1DTLB scheduler credit shadow, or equivalent spec-SB logic, to check reset value, min/max range, decrement on request fire, increment on return, and stable value when return and fire happen in the same cycle. |
| Effective-mode and refill monitor fields | `L1DTLB_MON_LSU_FIELDS`, `L1DTLB_MON_T0_T1_EVENTS`, `L1DTLB_MON_L2_PTW_REFILL`, `L1DTLB_MON_CP0_SYSMAP_PMP` | Extend monitor transactions or token snapshots with effective privilege, MPRV, MXR, SUM, request type, refill flag, and refill page-size/type fields so permission, PMP, sysmap, and attribute checks do not depend on reconstructing hidden state after the fact. |
| PLRU audit guard | `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_PLRU_BLACKBOX_BOUNDARY`, `L1DTLB_UVM_WORK_006_PLRU` | Keep exact victim selection out of main translation pass/fail.  Any future exact-victim check must first be added to the spec and then implemented as a dedicated whitebox assertion/coverage item. |

## 3.11.11 Recommended Implementation Order

| Priority | Step | Reason |
| ---: | --- | --- |
| 1 | Complete T0/T1 token ownership and legal no-response reason annotation in `mmu_l1dtlb_spec_sb.svh`. | This removes the largest source of false failures: same-cycle T0/T1 overlap, abort/drop cases, and replay timing that currently require broad waives. |
| 2 | Add the L1 entry shadow and refill/install/invalidate/reset update policy. | This enables independent hit-side PA, page-size, permission, and attribute comparison instead of relying only on final architectural translation. |
| 3 | Add the MB shadow lifecycle and IID-age one-free arbitration check. | MB allocation/drop behavior is the main remaining gap for miss/no-response correctness and replay closure. |
| 4 | Bind exception write/replay to the MB shadow. | Exception replay cannot be closed until fault refill, exception entry lifetime, wakeup, consume, and MB release are checked as one lifecycle. |
| 5 | Unify credit checking between credit SB and L1DTLB spec SB. | Exact credit conservation is small in scope but should be shared so external outstanding-request tracking and internal scheduler checks cannot diverge. |
| 6 | Standardize diagnostics and final-phase scenario gates. | Every directed wrapper should fail clearly when its target event was not observed, and every new checker should print cycle, pipe, IID, VA/VPN, reason, and source state. |

## 3.11.12 Regression and Acceptance Criteria

This traceability item is closed only when the following are true:

| Criterion | Required evidence |
| --- | --- |
| No unowned `planned` rows | Each `planned` row is either implemented, downgraded to a documented spec limitation with owner/reason, or explicitly linked to a future task. |
| All `partial` rows have concrete next evidence | Each `partial` row names the remaining missing checker, monitor field, directed scenario, SVA, or cover closure needed to become `implemented`. |
| Scenario gates prove stimulus actually happened | `L1DTLB_TC_ID`/`L1DTLB_SCENARIO_ID` final-phase counters report the target event for directed wrappers instead of only proving that a generic vseq ran. |
| Broad waives are explained or removed | Translation-SB waives for expt replay, T0/T1 overlap, STAMO, direct-map, and PMP cases are replaced by token/expt/no-response explanations, or remain with an explicit temporary owner. |
| Legal no-response is reason-coded | MB hit, MB full, abort, flush kill, busy sleep, and priority drop are distinguishable in diagnostics, and each class checks no illegal allocation, L2 request, TLB write, exception write, or wakeup side effect. |
| Regression cover closure exists | The related 3.9/3.10 SVA covers, whitebox covergroup bins, and 3.11 scenario gates have run results showing the intended events were observed. |
| PLRU boundary remains enforced | Main translation correctness does not fail on exact PLRU victim mismatch unless the spec is changed to define exact victim behavior. |

Until those criteria are met, this file is complete as a traceability/audit artifact, but the overall 3.11 UVM implementation remains `partial`.
