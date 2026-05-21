# L1DTLB UVM Phase 6 BuildPlan

> Project: OpenRiscv2030 MMU UVM Verification
> Scope: L1DTLB UVM follow-up implementation blueprint only
> Golden source: `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md`
> Traceability inputs:
> - `doc/l1dtlb_uvm_audit/l1dtlb_3_9_3_10_traceability.md`
> - `doc/l1dtlb_uvm_audit/l1dtlb_3_11_traceability.md`
> Progress tracker: `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_Progress.md`
> Date: 2026-05-22

## 1. Purpose and Boundary

Phase 6 is a planning and closure-control document for the remaining L1DTLB UVM work.  It does not implement or approve changes to UVM, DUT/RTL, Makefiles, simulation scripts, regression lists, or testbench behavior.

The L1DTLB functional description is the golden standard.  RTL-derived assumptions are not sufficient for closing a row unless they are backed by a spec-mapped reference-model state, scoreboard check, SVA, cover point, directed scenario, or approved waiver.

Current code inspection confirms the same high-level state as the traceability files:

- `mmu_l1dtlb_spec_sb.svh` has lightweight T0/T1 token ownership checks, MB-derived signal checks, refill/expt payload checks, credit range diagnostics, legal-no-response counters, and scenario gates.
- `mmu_translation_sb.svh` still contains broad L1DTLB replay/timing/STAMO/PMP/direct-map waive paths and a DTLB exception CAM shadow used mainly for compare waiver/diagnostics.
- `mmu_dut_probes_if.sv` and `tb_top.sv` expose many L1D probes, but not a full independently reusable entry/flag/refill/effective-mode observation surface.
- `mmu_ref_model.svh` models architectural Sv39/PMP/sysmap behavior, not a complete local L1DTLB TLB/MB/expt/credit/token model.

## 2. Uniform Entry Gate for Future Code Phases

Any later implementation phase must satisfy these gates before touching SystemVerilog, tests, Makefiles, scripts, or regression lists:

| Gate | Requirement |
| --- | --- |
| Review | This BuildPlan and `L1DTLB_UVM_Phase6_Progress.md` have been reviewed. |
| Scope approval | The new phase states the exact subphase, intended behavior, and allowed write-set. |
| Traceability | Every code change maps to at least one unfinished 3.9/3.10/3.11 ID or an explicit enabling item. |
| Baseline | Compile/regression baseline is recorded before implementation. |
| No implicit closure | A wrapper name, SVA name, or existing probe is not enough to mark an item complete without trigger and checker evidence. |
| Waiver discipline | Missing probes, formal-only items, spec gaps, unstable stimulus, and tool limits require a row in the waiver log. |

## 3. Future Implementation Phases and Strict Exit Gates

### Phase 6A: Observability and Monitor Closure

Goal: provide stable monitor/probe inputs for later semantic checkers.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
- `mmu_verification/testbench/top/tb_top.sv`
- `mmu_verification/testbench/lsu_agent/lsu_txn.svh`
- `mmu_verification/testbench/lsu_agent/lsu_monitor.svh`
- Optional local helper transactions near the L1DTLB scoreboard

Required implementation output:

- Inventory every currently missing or partial observation source: per-entry PPN/page-size/flag arrays, refill flag/type, effective privilege, MPRV/MPP, MXR, SUM, request type, PMP/sysmap epoch, exception-array reset visibility, and full refill payload.
- For each missing source choose one disposition: add stable probe, derive from existing monitor state, add scoreboard-side token snapshot, waive with risk, or mark future/formal-only.
- Keep internal probes as checker/debug inputs only.  Do not turn internal L1DTLB whitebox signals into normal sequence drive interfaces.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Allowed write-set and compile baseline recorded. |
| Deliverables | Probe/monitor inventory, missing-signal decision table, consumer list, and progress rows updated. |
| Compile evidence | Assertion-enabled compile passes, or each compile blocker has an issue row. |
| Pass/fail | No new checker uses an unapproved fragile `$root` path; every new probe has a named consumer and top/probe wiring. |
| Coverage/SVA/log | Functional coverage closure is not required in this phase, but compile log and inventory review evidence are required. |
| Waiver | A missing stable probe cannot close a checker row unless the waiver names replacement evidence and risk. |

### Phase 6B: T0/T1 Token and Translation-SB Waive Removal

Goal: replace broad translation scoreboard waives with explicit token/expt/no-response explanations.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh`
- `mmu_verification/testbench/env/mmu_translation_sb.svh`
- LSU monitor/transaction files if Phase 6A chooses transaction fields over local sampling

Required implementation output:

- Promote the existing lightweight per-pipe T0/T1 token stream into a reusable ownership queue.
- Token fields must include at least pipe, cycle, VA/VPN, IID, abort, access type, STAMO/direct-map status, effective privilege, MXR, SUM, MPRV/MPP where applicable, predicted path, expected PA/attr source, page-fault ownership, and PMP/access-fault ownership.
- Convert L1DTLB expt replay, T0/T1 overlap, STAMO pipe1 bypass, direct-map/sysmap, PMP T1 access-fault, and SATP/midwalk special cases from broad waives to explicit token/expt-shadow classifications.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Phase 6A provides required token fields or approved waivers. |
| Deliverables | Token object/queue, translated waive taxonomy, diagnostics with cycle/pipe/IID/VA/VPN/reason/source. |
| Compile evidence | Compile passes with translation SB and L1DTLB spec SB enabled. |
| Pass/fail | `page_fault` belongs to current non-aborted T0 and same-cycle `pa_vld`; `access_fault` belongs to the previous valid non-aborted T1; same-cycle PF/AF is legal only when tokens differ. |
| Coverage/SVA/log | Directed replay, T0/T1 overlap, PMP T1, STAMO, and direct-map logs show trigger and checker evidence. |
| Waiver | Any remaining broad waive has owner, reason, affected IDs, and expiration phase. |

### Phase 6C: L1 Entry Shadow and Hit-Side Compare

Goal: build an independent L1DTLB entry model rather than relying only on final architectural translation.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh`
- Optional helper class/package near the L1DTLB scoreboard
- `mmu_verification/testbench/env/mmu_ref_model.svh` only for shared permission/attribute helpers

Required implementation output:

- Add an L1 entry shadow object with valid, VPN, PPN, page size, and `flag[13:0]`.
- Update the shadow on reset, `regs_utlb_clr`, `tlboper_utlb_clr`, VA8 invalidate, install/refill, selected-entry clear-over-install, and any approved flush-scoped event.
- Use the shadow to predict page-size comparator bounds, PA assembly, permission/page-fault behavior, and output attributes when the hit source is observable.
- Keep exact PLRU victim outside normal functional pass/fail.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Phase 6A exposes or waives full entry/refill fields. |
| Deliverables | Entry shadow update policy, hit-source compare, attr/permission compare, invalidate/clear update tests. |
| Compile evidence | Compile passes and at least one directed hit/refill/invalidate run has log evidence. |
| Pass/fail | A valid L1 hit can be checked against shadow PA/page-size/flags; a cleared entry cannot be used by the shadow as a later valid hit. |
| Coverage/SVA/log | 4K/2M/1G hit/refill evidence, VA8 alias evidence, clear-over-install evidence, and attr compare evidence are recorded. |
| Waiver | Missing flag or attr observability is recorded per affected ID; final architectural compare alone is not enough to close entry-shadow rows. |

### Phase 6D: MB Lifecycle and Legal No-Response

Goal: make miss/no-response behavior scoreboard-owned rather than only reason-counted.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh`
- Optional L1DTLB MB helper class/package
- Existing L1DTLB SVA only for protocol-local assertions

Required implementation output:

- Add an MB shadow for valid/state/VPN/IID/store/sent/ready/WFC/WFI/payload.
- Predict allocation for single miss, dual same-4K dedup, dual different 4K with two free entries, dual different 4K with one free entry using IID age, and full/drop cases.
- Model MB 4K CAM hit, WFG/WFC/WFI/PGFLT/ACFLT/ABT transitions, bypass issue, old-MB priority, and replay/wakeup termination.
- Convert legal no-response from counters into transaction-level reasons: MB CAM hit, MB full, abort mask, flush kill, busy sleep, and one-free priority drop.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Phase 6A/6B provide enough request and MB state fields, or waivers name uncheckable subcases. |
| Deliverables | MB shadow, allocation oracle, IID-age helper including wraparound, no-response reason annotations, side-effect matrix. |
| Compile evidence | Compile passes and directed allocation/no-response tests run or are waived. |
| Pass/fail | Each legal no-response class checks no illegal MB allocation, L2 request, exception consume/write, TLB write, fault, or wakeup side effect. |
| Coverage/SVA/log | Same-4K, two-free, one-free p0-old/p1-old, MB full, MB CAM hit, abort, flush, and busy-sleep trigger evidence recorded. |
| Waiver | Priority-drop cannot close until allocation-winner evidence or an approved model limitation is recorded. |

### Phase 6E: Refill, Install, and Exception Lifecycle

Goal: bind refill/install/fault/expt replay into one lifecycle oracle.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh`
- `mmu_verification/testbench/env/mmu_translation_sb.svh` for removing replay compare waives
- Existing SVA files for protocol-local invariant checks

Required implementation output:

- Promote the existing DTLB exception CAM shadow into a lifecycle oracle with EID/IID/VPN/fault class and source MB binding.
- Check normal refill requires matching WFC MB state and stale/ABT refill has no TLB/expt/wakeup side effect.
- Check install priority WFI > PTW > L2, one install per cycle, WFI lowest entry, WFI data hold, same-cycle install visibility boundary, and MB release.
- Check fault refill never writes TLB, writes the correct exception entry, holds MB in PGFLT/ACFLT until replay or flush, and consumes/releases on replay.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Phase 6C/6D shadow objects are available or explicitly stubbed with waivers. |
| Deliverables | Refill/install oracle, exception lifecycle oracle, expt replay consume/release checks, stale/ABT matrix. |
| Compile evidence | Compile passes; directed refill, WFI, stale, fault, dual fault, replay, and wakeup tests run or are waived. |
| Pass/fail | Fault refill cannot update TLB; expt replay cannot allocate a new MB; consume releases the matching MB/expt entry and produces only the spec-defined terminal response. |
| Coverage/SVA/log | PTW/L2/WFI install, dual fault write, stale refill, ABT late refill, expt replay page/access timing, and wakeup evidence recorded. |
| Waiver | Mixed normal+fault collision, source parity, or missing expt-valid visibility must be recorded per ID. |

### Phase 6F: Credit, Wakeup, Flush, Invalidate, and Race Closure

Goal: close the remaining shared-control and race behavior with explicit models or waivers.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh`
- `mmu_verification/testbench/env/mmu_credit_sb.svh`
- `mmu_verification/testbench/env/mmu_invalidate_sb.svh` if selected as invalidate owner
- Existing L1DTLB SVA files

Required implementation output:

- Add or share an exact L1DTLB scheduler credit shadow: reset value, range, request-fire decrement, credit-return increment, `credit=0+return` no same-cycle fire, and `credit>0+return+fire` conservation.
- Close wakeup source and negative-source matrix.
- Model RTU flush as clearing MB/expt only, unless a separate TLB clear/invalidate signal is observed.
- Close invalidate+hit same-cycle old-hit boundary, invalidate+install same-entry final state, reset exception visibility, and ABT/stale late refill race side effects.
- Keep `vabuf` and exact PLRU victim as formal/debug/future unless the spec and observability are extended.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Prior phases identify the owner scoreboard/SVA for each shared-control item. |
| Deliverables | Shared credit shadow or single owner, wakeup source matrix, flush/invalidate/reset race checklist, PLRU/vabuf guard rows. |
| Compile evidence | Compile passes and credit/flush/invalidate/reset directed evidence is recorded. |
| Pass/fail | Credit behavior is checked by one authoritative model; RTU flush does not imply TLB full clear; invalidate boundary behavior is explicit. |
| Coverage/SVA/log | Credit zero+return, return+fire, wakeup install/expt, reset, flush races, invalidate+hit, and invalidate+install evidence recorded. |
| Waiver | Formal-only `vabuf` and exact PLRU items remain non-closure blockers only with explicit future/formal rows. |

### Phase 6G: Directed Scenario, Coverage, and Regression Closure

Goal: convert planned/partial rows into reproducible evidence, approved waivers, or future items.

Candidate landing areas:

- `mmu_verification/testbench/test/l1dtlb_tests/`
- `mmu_verification/testbench/env/mmu_l1dtlb_vseq_lib.svh`
- Existing covergroups and SVA coverage
- Regression list only in an approved later implementation phase

Required implementation output:

- Map every unfinished 3.9/3.10/3.11 ID to wrapper, checker, cover, SVA, scoreboard, waiver, or future/formal item.
- Every directed wrapper must provide scenario metadata and final-phase trigger evidence.
- Record regression tiers: compile, directed smoke, L1DTLB targeted, negative/formal-only excluded, integration/nightly candidate.
- Define coverage threshold and log/report fallback rules before claiming closure.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Phases 6A-6F are implemented, waived, or moved to future with owner. |
| Deliverables | ID-to-evidence matrix, regression tiers, coverage checklist, remaining-hole list, waiver list. |
| Compile/run evidence | Compile, directed smoke, and targeted L1DTLB regression commands, seeds, logs, and results are recorded. |
| Pass/fail | No unfinished P0/P1 item is marked Complete without trigger and checker evidence or approved waiver. |
| Coverage/SVA/log | Cover property, covergroup, SVA, and scoreboard final-phase reports are archived or have log fallback evidence. |
| Waiver | Coverage holes, untriggered scenarios, and formal-only items are waived or moved to a named future phase. |

## 4. Unfinished ID Coverage by Phase

This table is the controlling backlog for the future phases.  A row listed here must remain Planned/In progress/Blocked/Review until the Progress document records implementation evidence, waiver, or future disposition.

| Phase | Unfinished IDs owned by the phase |
| --- | --- |
| 6A Observability | `L1DTLB_SVA_A001`, `L1DTLB_SVA_A042`, `L1DTLB_TS_CTRL_RESET_STATE`, `L1DTLB_MON_LSU_FIELDS`, `L1DTLB_MON_T0_T1_EVENTS`, `L1DTLB_MON_L2_PTW_REFILL`, `L1DTLB_MON_CP0_SYSMAP_PMP`, `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_RESET_STATE` |
| 6B T0/T1 and waive removal | `L1DTLB_SVA_A011`, `L1DTLB_SVA_A012`, `L1DTLB_SVA_A013`, `L1DTLB_SVA_A014`, `L1DTLB_SVA_A015`, `L1DTLB_SVA_A019`, `L1DTLB_SVA_A026`, `L1DTLB_SVA_A035`, `L1DTLB_SVA_A057`, `L1DTLB_SVA_A069`, `L1DTLB_TS_FAULT_RESPONSE_TIMING`, `L1DTLB_TS_FAULT_PF_BLOCKS_PMP`, `L1DTLB_TS_FAULT_OVERLAP_PIPE`, `L1DTLB_TS_FAULT_PMP_ACCESS`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_SB_PAGE_FAULT_PAIRING`, `L1DTLB_SB_ACCESS_FAULT_PAIRING`, `L1DTLB_SB_FAULT_OVERLAP_GUARD`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` |
| 6C Entry shadow and hit compare | `L1DTLB_SVA_A004`, `L1DTLB_SVA_A005`, `L1DTLB_SVA_A006`, `L1DTLB_SVA_A007`, `L1DTLB_SVA_A028`, `L1DTLB_SVA_A029`, `L1DTLB_SVA_A030`, `L1DTLB_SVA_A031`, `L1DTLB_SVA_A032`, `L1DTLB_SVA_A034`, `L1DTLB_SVA_C010`, `L1DTLB_SVA_C011`, `L1DTLB_TS_BASIC_PAGE_SIZE_4K_2M_1G`, `L1DTLB_TS_BASIC_MULTI_HIT_DIAG`, `L1DTLB_TS_BASIC_ENTRY_FIELD_MODEL`, `L1DTLB_TS_FAULT_LOAD_R0`, `L1DTLB_TS_FAULT_LOAD_MXR`, `L1DTLB_TS_FAULT_STORE_W_D`, `L1DTLB_TS_FAULT_AD_US_SUM`, `L1DTLB_TS_MODE_DIRECT_MAP`, `L1DTLB_TS_MODE_STAMO_PIPE1`, `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_RM_ENTRY_ASID_GLOBAL`, `L1DTLB_RM_MULTI_HIT_POLICY`, `L1DTLB_LOOKUP_PAGE_SIZE_MATCH`, `L1DTLB_LOOKUP_PA_ASSEMBLY`, `L1DTLB_LOOKUP_ATTR_COMPARE`, `L1DTLB_LOOKUP_PAGE_FAULT_RULES`, `L1DTLB_LOOKUP_DIRECT_MAP`, `L1DTLB_LOOKUP_STAMO_PIPE1`, `L1DTLB_SB_ATTR_COMPARE` |
| 6D MB lifecycle and legal no-response | `L1DTLB_SVA_A020`, `L1DTLB_SVA_A022`, `L1DTLB_SVA_A024`, `L1DTLB_SVA_A025`, `L1DTLB_SVA_A038`, `L1DTLB_SVA_A070`, `L1DTLB_SVA_C006`, `L1DTLB_SVA_C008`, `L1DTLB_SVA_C009`, `L1DTLB_SVA_C013`, `L1DTLB_SVA_C025`, `L1DTLB_TS_MB_DUAL_DIFF_4K_TWO_FREE`, `L1DTLB_TS_MB_DUAL_DIFF_4K_ONE_FREE_AGE`, `L1DTLB_TS_MB_4K_DEDUP_FOR_HUGE_FINAL`, `L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY`, `L1DTLB_TS_OBS_LEGAL_NO_RESPONSE`, `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_MB_CAM_HIT_NO_RESPONSE`, `L1DTLB_MB_DUAL_DIFF_TWO_FREE`, `L1DTLB_MB_DUAL_DIFF_ONE_FREE_AGE`, `L1DTLB_MB_SINGLE_OR_FULL`, `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_SB_MB_ALLOCATION` |
| 6E Refill/install/expt lifecycle | `L1DTLB_SVA_A017`, `L1DTLB_SVA_A049`, `L1DTLB_SVA_A052`, `L1DTLB_SVA_A054`, `L1DTLB_SVA_A055`, `L1DTLB_SVA_A056`, `L1DTLB_SVA_A058`, `L1DTLB_SVA_C018`, `L1DTLB_TS_MB_FAULT_HOLD`, `L1DTLB_TS_MB_STALE_REFILL_ID`, `L1DTLB_TS_MB_ABT_LATE_REFILL`, `L1DTLB_TS_INSTALL_VISIBILITY_RELEASE`, `L1DTLB_TS_EXPT_FAULT_REFILL_WRITE`, `L1DTLB_TS_EXPT_REPLAY_CONSUME`, `L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY`, `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_INSTALL_VISIBILITY`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE`, `L1DTLB_SB_WAKEUP`, `L1DTLB_SB_INSTALL_EXPT` |
| 6F Credit/control/race/formal guards | `L1DTLB_SVA_A003`, `L1DTLB_SVA_A010`, `L1DTLB_SVA_A033`, `L1DTLB_SVA_A060`, `L1DTLB_SVA_A063`, `L1DTLB_SVA_C001`, `L1DTLB_SVA_C020`, `L1DTLB_SVA_C026`, `L1DTLB_TS_CTRL_VABUF_NO_EFFECT`, `L1DTLB_TS_SCHED_STORE_TYPE_PROP`, `L1DTLB_TS_INV_HIT_SAME_CYCLE`, `L1DTLB_TS_FLUSH_RTU_CLEAR_SCOPE`, `L1DTLB_RM_SB_PARTITION_004`, `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_RTU_FLUSH_SCOPE`, `L1DTLB_INV_HIT_SAME_CYCLE`, `L1DTLB_ABT_LATE_REFILL`, `L1DTLB_SB_INVALIDATE_FLUSH`, `L1DTLB_UVM_WORK_003_CREDIT` |
| 6G Closure and regression | `L1DTLB_SVA_A067`, `L1DTLB_TS_OBS_SVA_COVER_CLOSURE`, `L1DTLB_RM_SB_PARTITION_001`, `L1DTLB_RM_SB_PARTITION_002`, `L1DTLB_RM_SB_PARTITION_003`, `L1DTLB_SB_TRACEABILITY_CLOSURE`, `L1DTLB_UVM_WORK_001_REF_SUBMODEL`, `L1DTLB_UVM_WORK_004_SPEC_SB`, `L1DTLB_UVM_WORK_005_DIAG` |

## 5. Candidate Deliverable Matrix

| Area | Existing candidate | Future implementation intent |
| --- | --- | --- |
| Probe interface | `mmu_dut_probes_if.sv` | Provide stable L1D entry, MB, refill, exception, credit, invalidate, flush, and effective-mode observation. |
| Top wiring | `tb_top.sv` | Wire approved probes and SVA binds only; keep checker logic out of top. |
| Spec scoreboard | `mmu_l1dtlb_spec_sb.svh` | Own L1DTLB-local token, entry, MB, expt, credit, no-response, race, and scenario gates. |
| Translation scoreboard | `mmu_translation_sb.svh` | Keep final architectural compare, but remove broad L1DTLB waives as token/expt models mature. |
| Reference model | `mmu_ref_model.svh` | Reuse Sv39/PMP/sysmap helpers; do not hide L1DTLB-local state inside RTL-derived assumptions. |
| Directed tests | `test/l1dtlb_tests/` and `mmu_l1dtlb_vseq_lib.svh` | Add or retarget only when trigger and checker evidence are defined. |
| SVA/coverage | `mmu_l1dtlb_sva.sv`, whitebox coverage | Keep protocol-local and debug checks; do not make PLRU exact victim part of functional compare. |

## 6. Risk and Waiver Rules

| Risk | Required treatment |
| --- | --- |
| Missing stable probe | Phase 6A must add probe, derive transaction field, or create waiver with replacement evidence. |
| Broad translation waive hides bug | Phase 6B must classify the waive by token/expt/no-response reason or leave a time-limited waiver. |
| Scoreboard becomes RTL clone | Use `l1dtlb_function_description.md` rules, not internal RTL priority unless the spec defines it. |
| PLRU exact victim mismatch | Keep as whitebox/debug/future unless the spec defines exact replacement behavior. |
| Directed wrapper false coverage | Final-phase scenario gate must prove the target event happened. |
| Formal-only `vabuf` equivalence | Keep as formal/future with explicit owner and proof plan. |
| Coverage report unavailable | Use log fallback only when tool limitation and replacement evidence are recorded. |

## 7. Phase 6 Document Exit Checklist

| Check | Status |
| --- | --- |
| BuildPlan created | Complete |
| Progress tracker created | Complete |
| No UVM/DUT/RTL/Makefile/testbench behavior modification in this documentation phase | Complete |
| Future implementation split into independent phases | Complete |
| Strict exit gate defined for every phase | Complete |
| All current `partial`, `planned`, and `formal-only` traceability rows mapped to a phase | Complete |
| PLRU and `vabuf` non-simulation closure boundaries recorded | Complete |
| Later implementation approval required before code changes | Complete |
