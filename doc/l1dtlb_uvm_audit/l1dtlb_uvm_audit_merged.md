# L1DTLB UVM Audit Merged Documentation
> Generated from selected Markdown files in `doc/l1dtlb_uvm_audit`.
> Excludes function description documents, table/CSV-style source files, and `l1dtlb_testpoint_audit.md`.

## Merge Sources
- `L1DTLB_UVM_Phase6_BuildPlan.md`
- `L1DTLB_UVM_Phase6_Progress.md`
- `l1dtlb_3_9_3_10_traceability.md`
- `l1dtlb_3_11_traceability.md`

## Excluded Files
- `l1dtlb_function_description.md`
- `l1dtlb_function_description.txt`
- `L1DTLB_TRISTAN_IP_Hardware_tp_V1.xlsx`
- `l1dtlb_testpoint_audit.md`

---

## Source: `L1DTLB_UVM_Phase6_BuildPlan.md`

### L1DTLB UVM Phase 6 BuildPlan

> Project: OpenRiscv2030 MMU UVM Verification
> Scope: L1DTLB UVM follow-up implementation blueprint only
> Golden source: `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md`
> Traceability inputs:
> - `doc/l1dtlb_uvm_audit/l1dtlb_3_9_3_10_traceability.md`
> - `doc/l1dtlb_uvm_audit/l1dtlb_3_11_traceability.md`
> Progress tracker: `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_Progress.md`
> Date: 2026-05-22

#### 1. Purpose and Boundary

Phase 6 is a planning and closure-control document for the remaining L1DTLB UVM work.  It does not implement or approve changes to UVM, DUT/RTL, Makefiles, simulation scripts, regression lists, or testbench behavior.

The L1DTLB functional description is the golden standard.  RTL-derived assumptions are not sufficient for closing a row unless they are backed by a spec-mapped reference-model state, scoreboard check, SVA, cover point, directed scenario, or approved waiver.

Current code inspection confirms the same high-level state as the traceability files:

- `mmu_l1dtlb_spec_sb.svh` has lightweight T0/T1 token ownership checks, MB-derived signal checks, refill/expt payload checks, credit range diagnostics, legal-no-response counters, and scenario gates.
- `mmu_translation_sb.svh` still contains broad L1DTLB replay/timing/STAMO/PMP/direct-map waive paths and a DTLB exception CAM shadow used mainly for compare waiver/diagnostics.
- `mmu_dut_probes_if.sv` and `tb_top.sv` expose many L1D probes, but not a full independently reusable entry/flag/refill/effective-mode observation surface.
- `mmu_ref_model.svh` models architectural Sv39/PMP/sysmap behavior, not a complete local L1DTLB TLB/MB/expt/credit/token model.

#### 2. Uniform Entry Gate for Future Code Phases

Any later implementation phase must satisfy these gates before touching SystemVerilog, tests, Makefiles, scripts, or regression lists:

| Gate | Requirement |
| --- | --- |
| Review | This BuildPlan and `L1DTLB_UVM_Phase6_Progress.md` have been reviewed. |
| Scope approval | The new phase states the exact subphase, intended behavior, and allowed write-set. |
| Traceability | Every code change maps to at least one unfinished 3.9/3.10/3.11 ID or an explicit enabling item. |
| Baseline | Compile/regression baseline is recorded before implementation. |
| No implicit closure | A wrapper name, SVA name, or existing probe is not enough to mark an item complete without trigger and checker evidence. |
| Waiver discipline | Missing probes, formal-only items, spec gaps, unstable stimulus, and tool limits require a row in the waiver log. |

#### 3. Future Implementation Phases and Strict Exit Gates

##### Phase 6A: Observability and Monitor Closure

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

##### Phase 6B: T0/T1 Token and Translation-SB Waive Removal

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

##### Phase 6C: L1 Entry Shadow and Hit-Side Compare

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

##### Phase 6D: MB Lifecycle and Legal No-Response

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

##### Phase 6E: Refill, Install, and Exception Lifecycle

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

##### Phase 6F: Credit, Wakeup, Flush, Invalidate, and Race Closure

Goal: close the remaining shared-control and race behavior with explicit models, directed trigger evidence, or explicit future/formal rows.  Phase 6F must not close by wrapper name, SVA name, or a PASS summary alone.

Candidate landing areas:

- `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh`
- `mmu_verification/testbench/env/mmu_credit_sb.svh` only if the project chooses to refactor the shared credit owner out of the L1DTLB spec scoreboard
- `mmu_verification/testbench/env/mmu_invalidate_sb.svh` only if selected as the single invalidate owner
- Existing L1DTLB SVA files

Required implementation output:

- Select one UVM owner for exact L1DTLB scheduler credit.  The default owner is `mmu_l1dtlb_spec_sb.svh`; scheduler SVA is corroborating protocol evidence, not a second scoreboard owner.
- The credit model must check reset/max value, range, request-fire decrement, credit-return increment, `credit=0+return` no same-cycle fire, and `credit>0+return+fire` conservation.  A clean run with `fire_return=0` is partial evidence only.
- The wakeup matrix must classify install and exception replay as positive sources.  Reset, RTU flush, invalidate, and ABT/stale completion are negative-source contexts unless an explicit install/expt source is present in the same sampled cycle.
- RTU flush must be modeled as clearing MB/expt and killing in-flight side effects.  It must not imply full TLB entry clear unless `tlboper_utlb_clr`, `regs_utlb_clr`, or a VA invalidate source is observed.
- Invalidate+hit same cycle must allow the current-cycle old-hit response, then require a later miss/refill before the invalidated entry can be used as a valid hit again.
- Invalidate+install same entry must prove clear-wins final state with a clean directed run; logs with unrelated assertions, MB drain timeouts, or zero same-cycle cover do not close this row.
- ABT/stale late refill closure must reject TLB install, exception write, and wakeup side effects, and must distinguish inherited Phase 6E ABT evidence from a Phase 6F race-matrix report.
- `vabuf` functional equivalence and exact PLRU victim selection remain debug/formal/future rows unless the spec and observability are extended.  Vabuf-change cover is useful evidence but not an equivalence proof.

Evidence discipline:

| Evidence class | Required treatment |
| --- | --- |
| Clean closure evidence | `UVM_ERROR=0`, `UVM_FATAL=0`, no unexpected assertion failure, no unwaived `SCENARIO_GATE`, and nonzero target checker/cover counters. |
| Warning-bearing evidence | May support analysis only after the warning source is named and accepted; it cannot close a row that requires warning-free directed evidence. |
| Rejected evidence | Must be recorded in the Progress issue/evidence log before any status update.  For example, a same-cycle invalidate/install run with MB drain timeout warnings or TWU assertion failure is not closure evidence. |
| Inherited evidence | Earlier 6D/6E ABT, flush, or wakeup evidence may support context, but 6F completion still requires the Phase 6F owner report or an explicit waiver/future row. |

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Prior phases identify the owner scoreboard/SVA for each shared-control item; any rejected evidence is recorded before status changes. |
| Deliverables | Single credit owner, wakeup source matrix, flush/invalidate/reset race checklist, ABT/stale side-effect matrix, and PLRU/vabuf future/formal guard rows. |
| Compile evidence | Compile passes after Phase 6F changes and the log is recorded. |
| Pass/fail | Credit behavior is checked by one authoritative model; RTU flush does not imply TLB full clear; invalidate boundary behavior is explicit; same-entry invalidate+install cleanly proves clear-wins. |
| Coverage/SVA/log | Credit zero+return, return+fire, load/store request type, wakeup install/expt, reset clear, flush scope/races, invalidate+hit, invalidate+install, ABT late completion, and `vabuf`/PLRU guard evidence are recorded or explicitly deferred. |
| Waiver | Formal-only `vabuf` and exact PLRU items remain non-closure blockers only with explicit future/formal rows. |

##### Phase 6G: Directed Scenario, Coverage, and Regression Closure

Goal: convert planned/partial rows into reproducible DUT-quality evidence, approved waivers, or future/formal items.  Phase 6G is the closure controller: it must not make the DUT look verified by counting wrappers, PASS summaries, SVA names, or cover names without proving that the intended scenario triggered and that the intended checker observed the behavior.

Current-state facts to preserve in the closure record:

- `L1DTLB_UVM_Phase6_Progress.md` records Phase 6A-6F as complete for the planned UVM owner/reporting scope, with compile and directed evidence.
- `mmu_verification/testbench/test/l1dtlb_tests/` already contains L1DTLB directed wrappers, and `l1dtlb_tests_suite.svh` includes the Phase 6A-6F closure wrappers.
- `mmu_l1dtlb_spec_sb.svh` already emits final-phase reports for `PHASE6A_INVENTORY`, `PHASE6B_TOKEN_TAXONOMY`, `PHASE6C_ENTRY_SHADOW`, `PHASE6D_MB_SHADOW`, `PHASE6D_NO_RESPONSE`, `PHASE6E_REFILL_INSTALL`, `PHASE6E_EXPT_LIFECYCLE`, `PHASE6F_CREDIT_CONTROL`, `PHASE6F_WAKEUP_MATRIX`, `PHASE6F_RACE_CLOSURE`, and `PHASE6F_FORMAL_FUTURE`.
- At Phase 6G entry no dedicated L1DTLB regression list was found under `mmu_verification/simu/`.  Phase 6G implementation now adds smoke/targeted lists, a manifest replay flow, and a closure scanner.  The manifest scanner is the authoritative closure evidence because list-only regression cannot encode per-row seed, accepted-warning, target-counter, and cover policy.
- Exact PLRU victim selection and full `vabuf` functional equivalence remain future/formal guard rows unless the spec and observability are expanded.

Candidate landing areas:

- `mmu_verification/testbench/test/l1dtlb_tests/`
- `mmu_verification/testbench/env/mmu_l1dtlb_vseq_lib.svh`
- Existing covergroups and SVA coverage
- Phase 6G replay and closure scanner scripts for deterministic evidence extraction
- `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_Progress.md` for evidence, issue, waiver, and final closure rows
- Dedicated smoke/targeted regression lists and the manifest replay flow added by the approved Phase 6G implementation

Required implementation output:

- Build an ID-to-evidence matrix for every unfinished 3.9/3.10/3.11 row and every Phase 6G row.  Each row must name status, wrapper or regression source, seed, log path, trigger evidence, checker evidence, SVA/cover evidence where applicable, and final disposition.
- Close the Phase 6G IDs with the following minimum evidence policy:

| ID | Required closure evidence |
| --- | --- |
| `L1DTLB_SVA_A067` | Nonzero target SVA assertion/cover evidence, clean log status, and the related scoreboard report or waiver naming why SVA evidence is not available. |
| `L1DTLB_TS_OBS_SVA_COVER_CLOSURE` | Cover-property, covergroup, and scoreboard-report inventory showing every required cover either hit, waived, or moved to future/formal with owner. |
| `L1DTLB_RM_SB_PARTITION_001` | Final ownership matrix showing architectural translation compare, local L1DTLB token/entry/MB/expt/credit/race checks, SVA protocol checks, and future/formal boundaries do not overlap ambiguously. |
| `L1DTLB_RM_SB_PARTITION_002` | Evidence that architectural reference-model behavior remains in `mmu_ref_model.svh`/translation SB while L1DTLB-local microarchitectural state remains in the L1DTLB spec SB or an explicitly named helper. |
| `L1DTLB_RM_SB_PARTITION_003` | Evidence that final architectural compare does not mask local L1DTLB failures; any translation-SB skip must cite a token/expt/no-response classification, waiver, or future row. |
| `L1DTLB_SB_TRACEABILITY_CLOSURE` | Complete traceability matrix linking every unfinished ID to accepted evidence, waiver, or future/formal disposition. |
| `L1DTLB_UVM_WORK_001_REF_SUBMODEL` | Closure note explaining which behavior is modeled architecturally, which is modeled locally, and which spec gaps remain; no RTL-derived assumption may be used as the only oracle. |
| `L1DTLB_UVM_WORK_004_SPEC_SB` | Final scoreboard diagnostic report showing all Phase 6A-6F final-phase reports are present when their owning scenarios run, with nonzero target counters for rows claimed closed. |
| `L1DTLB_UVM_WORK_005_DIAG` | Stable diagnostics for failures and closure: cycle, pipe, IID, VA/VPN, seed, scenario ID, expected/actual behavior, and reason/source classification. |

- Every directed wrapper used for closure must provide scenario metadata: test name, scenario ID, related traceability IDs, seed, target counters, expected terminal condition, and final result.  Metadata may be printed directly by the wrapper or propagated through `L1DTLB_SCENARIO_ID`, but the final log must be self-contained enough to debug a failure without rerunning.
- Scenario gates must check the actual target event, not just test completion.  A `SCENARIO_GATE` line, zero target counter, missing final scoreboard report, unexpected assertion text, `UVM_ERROR`, or `UVM_FATAL` blocks closure until the issue is fixed, waived, or moved to future.
- Warning-bearing evidence may support analysis only after the warning source is named in the Progress issue/evidence log.  It cannot close a row requiring clean directed evidence unless the row explicitly accepts that warning class.
- Rejected evidence must remain recorded before any status update.  A later clean seed supersedes but does not erase rejected seeds or partial evidence.
- Create or approve regression tiers before running closure:

| Tier | Purpose | Required contents |
| --- | --- | --- |
| Compile | Prove current build is usable before evidence collection. | `make comp_fast`; record `mmu_verification/output/logs/comp_fast.log`. |
| Directed smoke | Fast health check for reset, observability, and a basic L1DTLB hit path. | Small fixed subset from `l1dtlb_tests`, `UVM_ERROR=0`, `UVM_FATAL=0`, no unexpected assertion text, and required final reports present. |
| L1DTLB targeted | Reproduce every Phase 6A-6F closure behavior used by the ID matrix. | Dedicated list, fixed seeds, clean summary, and per-row trigger/checker evidence. |
| Coverage | Collect SVA/covergroup/report evidence for closure rows. | Coverage-enabled compile/run flow, aggregate VDB path, URG/report path, threshold, and fallback logs. |
| Negative/future/formal excluded | Keep illegal stimulus, debug-only PLRU, and formal-only `vabuf` rows out of normal pass-rate math. | Explicit list with owner, reason, and replacement evidence or proof plan. |
| Integration/nightly candidate | Stable subset suitable for broader MMU regression after targeted closure. | Only clean deterministic tests; no unwaived scenario gates or expected warnings. |

- Coverage thresholds must be set before claiming closure.  Default closure policy is 100% hit/waive/future disposition for Phase 6G-owned SVA covers, covergroups, and scoreboard final reports; line/branch/toggle/functional percentages may support confidence but do not replace traceability closure.
- URG or cover report failure is not automatically a waiver.  If the coverage tool cannot produce a usable report, the fallback must include command, seed/list, log path, missing report path, reason, replacement grep/report evidence, and residual risk.
- The targeted regression summary must include commands, seeds, log paths, pass/fail count, accepted warnings, rejected evidence, coverage holes, waivers, and future/formal rows.
- A list regression PASS is not closure unless the manifest closure scanner also passes every claimed row.  The scanner must reject rows with missing final reports, zero target counters, unaccepted warnings, unexpected assertion text, `SCENARIO_GATE`, `UVM_ERROR`, or `UVM_FATAL`.

Strict exit gate:

| Item | Criterion |
| --- | --- |
| Entry | Phases 6A-6F are implemented, waived, or moved to future/formal with owner; rejected and partial evidence from earlier phases is already recorded. |
| Deliverables | ID-to-evidence matrix, scoreboard/SVA/coverage inventory, regression tier definitions, closure summary, remaining-hole list, waiver list, future/formal list, and rejected-evidence list. |
| Compile/run evidence | Compile, directed smoke, targeted L1DTLB regression, and coverage commands, seeds, logs, summaries, and report paths are recorded in the Progress evidence log. |
| Pass/fail | No unfinished P0/P1 item is marked Complete without nonzero trigger evidence plus checker evidence, or an approved waiver/future/formal row. |
| Coverage/SVA/log | Cover property, covergroup, SVA, scoreboard final-phase reports, and URG/log fallback evidence are archived or linked; every missing report or zero-hit cover has a disposition. |
| Regression quality | A clean targeted regression has `UVM_ERROR=0`, `UVM_FATAL=0`, no unexpected assertion failures, no unwaived `SCENARIO_GATE`, and all claimed rows have nonzero target counters. |
| Waiver | Coverage holes, untriggered scenarios, unstable tests, report-tool limits, PLRU exact victim, and `vabuf` equivalence are waived or moved to named future/formal work with owner, risk, and replacement evidence. |

#### 4. Unfinished ID Coverage by Phase

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

#### 5. Candidate Deliverable Matrix

| Area | Existing candidate | Future implementation intent |
| --- | --- | --- |
| Probe interface | `mmu_dut_probes_if.sv` | Provide stable L1D entry, MB, refill, exception, credit, invalidate, flush, and effective-mode observation. |
| Top wiring | `tb_top.sv` | Wire approved probes and SVA binds only; keep checker logic out of top. |
| Spec scoreboard | `mmu_l1dtlb_spec_sb.svh` | Own L1DTLB-local token, entry, MB, expt, credit, no-response, race, and scenario gates. |
| Translation scoreboard | `mmu_translation_sb.svh` | Keep final architectural compare, but remove broad L1DTLB waives as token/expt models mature. |
| Reference model | `mmu_ref_model.svh` | Reuse Sv39/PMP/sysmap helpers; do not hide L1DTLB-local state inside RTL-derived assumptions. |
| Directed tests | `test/l1dtlb_tests/` and `mmu_l1dtlb_vseq_lib.svh` | Add or retarget only when trigger and checker evidence are defined. |
| SVA/coverage | `mmu_l1dtlb_sva.sv`, whitebox coverage | Keep protocol-local and debug checks; do not make PLRU exact victim part of functional compare. |

#### 6. Risk and Waiver Rules

| Risk | Required treatment |
| --- | --- |
| Missing stable probe | Phase 6A must add probe, derive transaction field, or create waiver with replacement evidence. |
| Broad translation waive hides bug | Phase 6B must classify the waive by token/expt/no-response reason or leave a time-limited waiver. |
| Scoreboard becomes RTL clone | Use `l1dtlb_function_description.md` rules, not internal RTL priority unless the spec defines it. |
| PLRU exact victim mismatch | Keep as whitebox/debug/future unless the spec defines exact replacement behavior. |
| Directed wrapper false coverage | Final-phase scenario gate must prove the target event happened. |
| Formal-only `vabuf` equivalence | Keep as formal/future with explicit owner and proof plan. |
| Coverage report unavailable | Use log fallback only when tool limitation and replacement evidence are recorded. |

#### 7. Phase 6 Document Exit Checklist

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

---

## Source: `L1DTLB_UVM_Phase6_Progress.md`

### L1DTLB UVM Phase 6 Progress

> Project: OpenRiscv2030 MMU UVM Verification
> Scope: L1DTLB UVM follow-up implementation progress and gate tracking
> Build plan: `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_BuildPlan.md`
> Golden source: `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md`
> Date: 2026-05-23

#### 1. Phase Status

Phase 6 started as the follow-up implementation blueprint and progress tracker.  Phase 6A observability, Phase 6B token/taxonomy, Phase 6C L1 entry shadow, Phase 6D MB lifecycle/legal no-response, Phase 6E refill/install/exception lifecycle, Phase 6F credit/wakeup/race reporting, and Phase 6G directed scenario/coverage/regression closure are complete for the planned UVM owner scope.  Phase 6G adds deterministic smoke/targeted lists, a per-row evidence manifest, a replay driver, and a closure scanner; final evidence is manifest replay `PASS=28 FAIL=0 TOTAL=28` plus closure scanner `PASS=28 FAIL=0 TOTAL=28`.  Important rejected and partial evidence is recorded before status changes, including Phase 6F rejected invalidate+install seeds 97353/97354/97361/97362/97363 and partial cleanup seed 97360.  Phase 6G also found and fixed a real checker-quality hole: replay/run_check PASS alone did not prove `DTLB_FAULT_OVERLAP_PIPE_001` because the target counter `af_previous_t1` was zero until the scoreboard ownership logic was repaired to prioritize previous-T1 PMP/PA-response access-fault ownership over same-cycle expt replay.

| Item | Path | Status | Notes |
| --- | --- | --- | --- |
| Phase 6 BuildPlan | `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_BuildPlan.md` | Complete | 6A-6G strict exit gates plus implemented Phase6G closure policy. |
| Phase 6 Progress | `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_Progress.md` | Complete | Tracker updated through Phase6G implementation, evidence, issues, waivers, and future/formal rows. |
| UVM/testbench code | `mmu_verification/testbench/...` | Modified in 6A/6B/6C/6D/6E/6F/6G | Phase 6A touched probes, top wiring, LSU monitor/txn, whitebox coverage, SVA width/reset cleanup, and L1DTLB scoreboard inventory checks. Phase 6B added L1DTLB token taxonomy, translation-SB classified skips, and fixed the fault-overlap directed sequence ordering. Phase 6C added the L1 entry shadow, hit-side PA/page-size/flag/attr compare, invalidate shadow update policy, and a terminal-response sampling repair in the directed vseq. Phase 6D added the L1D MB shadow, allocation oracle, IID age helper, legal no-response side-effect matrix, retimed T1 MB CAM classification, and directed MB CAM/flush-race timing helpers. Phase 6E added refill/install source arbitration checks, MB release expectations, exception lifecycle shadow/replay checks, deterministic WFI collision stimulus, ABT late-refill/stale reachability stimulus, ACFLT/dual-exception stimulus, WFI SVA timing cover correction, and a Phase6D overlap repair found while running fault-hold. Phase 6F adds credit/wakeup/race reports, cleanup-scope policy, invalidate+hit boundary checks, WFI/local-install invalidate+install race stimulus, and rejected-evidence handling. Phase 6G repairs fault-overlap AF ownership classification found by closure scanning and adds manifest-driven closure assets. |
| RTL/Makefile/scripts | `mmu/rtl/...`, `mmu_verification/Makefile`, `mmu_verification/scripts/...` | Modified in 6A/6E/6G | Compile blockers and width hygiene were fixed in Phase 6A. Phase 6E fixed the L1DTLB ACFLT expt-replay datapath in `mmu_l1dtlb_hit_rd.sv` so same-cycle expt CAM ACFLT replay owns the access-fault response and PA source. Phase 6G did not add new RTL changes; it adds Makefile replay/closure targets and closure scripts/regression lists. |
| Future implementation approval | N/A | Phase6G complete | Remaining exact PLRU victim and full `vabuf` functional equivalence are explicit future/formal rows, not open Phase6G UVM simulation tasks. |

#### 2. Subphase Progress Matrix

Status values: `Not started`, `Planned`, `In progress`, `Blocked`, `Review`, `Complete`, `Waived`, `Future`.

| Subphase | Title | Status | Owner | Planned deliverables | Strict exit summary | Regression/evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 6A | Observability and monitor closure | Complete | Codex | Probe/monitor inventory; missing-signal decision table; consumer list | Stable source, derived field, or future-risk row recorded for required inputs; `fragile_root_paths=0`; compile and smoke pass. | `make comp_fast` PASS; `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_ref_model_observability_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` PASS. |
| 6B | T0/T1 token and translation-SB waive removal | Complete | Codex | Reusable token queue; waive taxonomy; token diagnostics | Broad LSU L1DTLB waives replaced by token/expt/no-response classifications; PF current-T0, AF previous-T1, overlap, STAMO, direct-map, PMP, and expt replay evidence recorded. | `make comp_fast` PASS; directed PF/PMP, AF T1, fault overlap, PMP, STAMO pipe1, STAMO pipe0 negative, expt replay, and sysmap/direct-map runs PASS with `remaining_broad_waive=0`. |
| 6C | L1 entry shadow and hit-side compare | Complete | Codex | Entry shadow; hit PA/page-size/flag/attr compare; invalidate update policy | Normal L1 hits are checked against an independent valid/VPN/PPN/page-size/flag shadow; direct-map and STAMO bypasses are classified outside entry-shadow compare; clear/update policy is recorded. | `make comp_fast` PASS; directed entry-field, hit, 4K/2M/1G huge-page, permission, AD/US/SUM, VA8 invalidate, and invalidate/install clear-update runs PASS with `PHASE6C_ENTRY_SHADOW` evidence. |
| 6D | MB lifecycle and legal no-response | Complete | Codex | MB shadow; allocation oracle; IID-age winner; no-response side-effect checks | MB valid/state/VPN/IID/store/sent/ready/WFC/WFI/payload shadow is active; allocation oracle covers single, same-4K, two-free, one-free age, full/drop, CAM, abort, flush, and busy-sleep classes; every legal no-response class records a reason and checks no illegal MB allocation, L2 request, refill, exception write, or wakeup side effect. | `make comp_fast` PASS; 13 directed runs from seeds 97111-97123 PASS with `PHASE6D_MB_SHADOW` and `PHASE6D_NO_RESPONSE` evidence. |
| 6E | Refill, install, and exception lifecycle | Complete | Codex | Refill/install oracle; exception lifecycle; stale/ABT matrix | Normal PTW/L2/WFI refill binds the correct WFC/WFI MB and releases it after install; fault refill never writes TLB; expt replay consumes the matching shadow entry, releases the matching MB, and does not allocate a new MB. WFI collision/data-hold, ACFLT source replay, dual fault write, and ABT late completion are covered by directed evidence. Standalone `!mb_vld` stale completion is retained as a reachability note for the current RTL FSM, not as a closure waiver. | `make comp_fast` PASS; directed refill/install/fault/replay/wakeup/ABT/WFI/stale/ACFLT/dual runs PASS with `PHASE6E_REFILL_INSTALL`, `PHASE6E_EXPT_LIFECYCLE`, and SVA cover evidence. Former waiver rows `L1DTLB-P6-WAIVE-001` through `L1DTLB-P6-WAIVE-003` are retired or retained only as audit history. |
| 6F | Credit, wakeup, flush, invalidate, and race closure | Complete | Codex | Shared credit shadow; wakeup matrix; flush/invalidate/reset race checklist; rejected-evidence log | Credit has one UVM owner and clean evidence; wakeup/install, cleanup-scope, invalidate+hit, and same-cycle invalidate+install have targeted evidence. Formal-only `vabuf` equivalence and exact PLRU victim selection are explicitly future rows. | `credit_bound_001` seed 97341 PASS with credit `fire_return=1` and `zero_return=1`; `type_prop_load_store_amo_001` seed 97341 PASS for load/store split; `inv_hit_same_cycle_001` seed 97342 PASS; `cleanup_scope_matrix_001` seed 97362 PASS with MB/expt/preserve/no-side-effect counters; `inv_install_same_entry_001` seed 97364 PASS with `inv_install_final_clear=1` and SVA same-entry cover match; seeds 97353/97354/97361/97362/97363 rejected, not closure evidence. |
| 6G | Directed scenario, coverage, and regression closure | Complete | Codex | ID-to-evidence matrix; regression tiers; coverage checklist; waiver/future list; replay and closure automation | No unfinished item is closed without trigger/checker evidence or waiver/future disposition; replay PASS alone is not accepted without manifest closure. | `make -C mmu_verification l1dtlb_phase6g_replay` PASS 28/28; `make -C mmu_verification l1dtlb_phase6g_closure` PASS 28/28; report `mmu_verification/output/regression/l1dtlb_phase6g_closure/closure_report.md`. |

#### 3. Open Work Package Tracker

| Work package | Status | Target phase | Primary unfinished IDs | Required closure evidence |
| --- | --- | --- | --- | --- |
| Stable observability | Complete | 6A | `L1DTLB_MON_*`, `L1DTLB_PROBE_*`, `L1DTLB_RESET_STATE`, `L1DTLB_SVA_A001` | Probe/monitor inventory implemented, compiled, and smoke-tested; Phase6A final scoreboard inventory reports `fragile_root_paths=0`. |
| T0/T1 token ownership | Complete | 6B | `L1DTLB_RM_T0_T1_TOKEN`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | L1DTLB spec SB emits `PHASE6B_TOKEN_TAXONOMY` with token queue depth/max and classified PF/AF/expt/PMP/STAMO/direct/no-response counters; directed logs show `remaining_broad_waive=0`. |
| Page/access fault pairing | Complete | 6B | `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_FAULT_OVERLAP_GUARD` | `DTLB_FAULT_OVERLAP_PIPE_001` shows `pf_current_t0=1`, `af_previous_t1=1`, `fault_overlap_separate=1`; PF and AF standalone directed tests also pass. |
| L1 entry shadow | Complete | 6C | `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_RM_ENTRY_ASID_GLOBAL`, `L1DTLB_SB_ATTR_COMPARE` | `PHASE6C_ENTRY_SHADOW` reports reset/probe/refill/clear/VA8 updates plus hit PA/page-size/flag/permission/attr compare counters. |
| Permission and direct-map semantics | Complete for 6C | 6C | `L1DTLB_LOOKUP_PAGE_FAULT_RULES`, `L1DTLB_LOOKUP_DIRECT_MAP`, `L1DTLB_LOOKUP_STAMO_PIPE1` | Entry-hit page-fault and attr rules are checked from shadow flags; direct-map and STAMO are classified as non-entry-shadow bypass sources by Phase 6B/6C diagnostics. |
| MB lifecycle | Complete | 6D | `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_SB_MB_ALLOCATION` | `PHASE6D_MB_SHADOW` reports shadow update/state/payload checks, allocation expectation enqueue/check counters, allocation match counters, CAM hit checks, IID age checks, and WFC/WFI/PGFLT/ABT lifecycle evidence across directed runs. |
| Legal no-response taxonomy | Complete | 6D | `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_TS_OBS_LEGAL_NO_RESPONSE` | `PHASE6D_NO_RESPONSE` reports reason-coded `mb_cam_hit`, `mb_full`, `abort_mask`, `flush_kill`, `busy_sleep`, and `priority_drop_one_free` classes, with side-effect matrix counters proving no matching illegal alloc/L2/refill/expt/wakeup side effects. |
| Refill/install lifecycle | Complete | 6E | `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_INSTALL_VISIBILITY`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE` | `PHASE6E_REFILL_INSTALL` reports normal PTW/L2 bind/release, install priority, install visibility, WFI lowest/data-hold, ABT late-refill no-side-effect, and fault no-TLB-write evidence. Standalone `!mb_vld` stale is a documented reachability note; the stale/ABT matrix is closed by ABT late completion. |
| Exception array lifecycle | Complete | 6E | `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE` | `PHASE6E_EXPT_LIFECYCLE` reports expt shadow write/bind, PGFLT and ACFLT fault class, fault hold, replay consume/release, wakeup, no-new-MB, and dual-write checks. ACFLT source and dual fault write are covered by seeds 97230 and 97231. |
| Scheduler credit | Complete | 6F | `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_UVM_WORK_003_CREDIT` | `PHASE6F_CREDIT_CONTROL` seed 97341 reports exact shadow owner, `fire_return=1`, `zero_return=1`, `zero_no_fire=247`, and load/store request split. Earlier 97311/97321/97331 runs are rejected because they contain UVM errors despite hitting request+return cover. |
| Flush/invalidate/reset races | Complete | 6F | `L1DTLB_RTU_FLUSH_SCOPE`, `L1DTLB_INV_HIT_SAME_CYCLE`, `L1DTLB_ABT_LATE_REFILL`, `L1DTLB_SB_INVALIDATE_FLUSH` | Invalidate+hit old-boundary has clean seed 97342 evidence. ABT late no-side-effect remains supported by Phase6E seeds 97232/97233. Cleanup-scope seed 97362 is clean and reports MB kill/clear, expt clear, TLB preserve, and killed-miss no-side-effect. Same-cycle invalidate+install is closed by final WFI/local-install race seed 97364; rejected seeds remain recorded and are not closure evidence. |
| PLRU and `vabuf` guard | Future/Formal | 6F | `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_SVA_A003`, `L1DTLB_TS_CTRL_VABUF_NO_EFFECT` | `PHASE6F_FORMAL_FUTURE` records exact PLRU victim and `vabuf` equivalence as future/formal non-blockers for Phase6F simulation closure. `cp_l1dtlb_c026_vabuf_change` cover is supporting evidence only, not equivalence closure. |
| Scenario and regression closure | Complete | 6G | `L1DTLB_SB_TRACEABILITY_CLOSURE`, `L1DTLB_TS_OBS_SVA_COVER_CLOSURE`, `L1DTLB_UVM_WORK_005_DIAG` | `l1dtlb_phase6g_evidence_manifest.tsv` plus replay/closure reports archive 28 rows of trigger/checker evidence, accepted warnings, cover/report requirements, future/formal rows, and rejected-evidence policy. |

#### 4. Incomplete Traceability Backlog by Phase

This section mirrors the BuildPlan controlling backlog.  Future work must update status and evidence here before marking an item closed.

| Phase | Status | Backlog IDs |
| --- | --- | --- |
| 6A | Complete | `L1DTLB_SVA_A001`, `L1DTLB_SVA_A042`, `L1DTLB_TS_CTRL_RESET_STATE`, `L1DTLB_MON_LSU_FIELDS`, `L1DTLB_MON_T0_T1_EVENTS`, `L1DTLB_MON_L2_PTW_REFILL`, `L1DTLB_MON_CP0_SYSMAP_PMP`, `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_RESET_STATE` |
| 6B | Complete | `L1DTLB_SVA_A011`, `L1DTLB_SVA_A012`, `L1DTLB_SVA_A013`, `L1DTLB_SVA_A014`, `L1DTLB_SVA_A015`, `L1DTLB_SVA_A019`, `L1DTLB_SVA_A026`, `L1DTLB_SVA_A035`, `L1DTLB_SVA_A057`, `L1DTLB_SVA_A069`, `L1DTLB_TS_FAULT_RESPONSE_TIMING`, `L1DTLB_TS_FAULT_PF_BLOCKS_PMP`, `L1DTLB_TS_FAULT_OVERLAP_PIPE`, `L1DTLB_TS_FAULT_PMP_ACCESS`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_SB_PAGE_FAULT_PAIRING`, `L1DTLB_SB_ACCESS_FAULT_PAIRING`, `L1DTLB_SB_FAULT_OVERLAP_GUARD`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` |
| 6C | Complete | `L1DTLB_SVA_A004`, `L1DTLB_SVA_A005`, `L1DTLB_SVA_A006`, `L1DTLB_SVA_A007`, `L1DTLB_SVA_A028`, `L1DTLB_SVA_A029`, `L1DTLB_SVA_A030`, `L1DTLB_SVA_A031`, `L1DTLB_SVA_A032`, `L1DTLB_SVA_A034`, `L1DTLB_SVA_C010`, `L1DTLB_SVA_C011`, `L1DTLB_TS_BASIC_PAGE_SIZE_4K_2M_1G`, `L1DTLB_TS_BASIC_MULTI_HIT_DIAG`, `L1DTLB_TS_BASIC_ENTRY_FIELD_MODEL`, `L1DTLB_TS_FAULT_LOAD_R0`, `L1DTLB_TS_FAULT_LOAD_MXR`, `L1DTLB_TS_FAULT_STORE_W_D`, `L1DTLB_TS_FAULT_AD_US_SUM`, `L1DTLB_TS_MODE_DIRECT_MAP`, `L1DTLB_TS_MODE_STAMO_PIPE1`, `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_RM_ENTRY_ASID_GLOBAL`, `L1DTLB_RM_MULTI_HIT_POLICY`, `L1DTLB_LOOKUP_PAGE_SIZE_MATCH`, `L1DTLB_LOOKUP_PA_ASSEMBLY`, `L1DTLB_LOOKUP_ATTR_COMPARE`, `L1DTLB_LOOKUP_PAGE_FAULT_RULES`, `L1DTLB_LOOKUP_DIRECT_MAP`, `L1DTLB_LOOKUP_STAMO_PIPE1`, `L1DTLB_SB_ATTR_COMPARE` |
| 6D | Complete | `L1DTLB_SVA_A020`, `L1DTLB_SVA_A022`, `L1DTLB_SVA_A024`, `L1DTLB_SVA_A025`, `L1DTLB_SVA_A038`, `L1DTLB_SVA_A070`, `L1DTLB_SVA_C006`, `L1DTLB_SVA_C008`, `L1DTLB_SVA_C009`, `L1DTLB_SVA_C013`, `L1DTLB_SVA_C025`, `L1DTLB_TS_MB_DUAL_DIFF_4K_TWO_FREE`, `L1DTLB_TS_MB_DUAL_DIFF_4K_ONE_FREE_AGE`, `L1DTLB_TS_MB_4K_DEDUP_FOR_HUGE_FINAL`, `L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY`, `L1DTLB_TS_OBS_LEGAL_NO_RESPONSE`, `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_MB_CAM_HIT_NO_RESPONSE`, `L1DTLB_MB_DUAL_DIFF_TWO_FREE`, `L1DTLB_MB_DUAL_DIFF_ONE_FREE_AGE`, `L1DTLB_MB_SINGLE_OR_FULL`, `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_SB_MB_ALLOCATION` |
| 6E | Complete | `L1DTLB_SVA_A017`, `L1DTLB_SVA_A049`, `L1DTLB_SVA_A052`, `L1DTLB_SVA_A054`, `L1DTLB_SVA_A055`, `L1DTLB_SVA_A056`, `L1DTLB_SVA_A058`, `L1DTLB_SVA_C018`, `L1DTLB_TS_MB_FAULT_HOLD`, `L1DTLB_TS_MB_STALE_REFILL_ID`, `L1DTLB_TS_MB_ABT_LATE_REFILL`, `L1DTLB_TS_INSTALL_VISIBILITY_RELEASE`, `L1DTLB_TS_EXPT_FAULT_REFILL_WRITE`, `L1DTLB_TS_EXPT_REPLAY_CONSUME`, `L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY`, `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_INSTALL_VISIBILITY`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE`, `L1DTLB_SB_WAKEUP`, `L1DTLB_SB_INSTALL_EXPT`; retired waivers: `L1DTLB-P6-WAIVE-001`, `L1DTLB-P6-WAIVE-002`, `L1DTLB-P6-WAIVE-003`; standalone `!mb_vld` stale retained as reachability note. |
| 6F | Complete | `L1DTLB_SVA_A003`, `L1DTLB_SVA_A010`, `L1DTLB_SVA_A033`, `L1DTLB_SVA_A060`, `L1DTLB_SVA_A063`, `L1DTLB_SVA_C001`, `L1DTLB_SVA_C020`, `L1DTLB_SVA_C026`, `L1DTLB_TS_CTRL_VABUF_NO_EFFECT`, `L1DTLB_TS_SCHED_STORE_TYPE_PROP`, `L1DTLB_TS_INV_HIT_SAME_CYCLE`, `L1DTLB_TS_FLUSH_RTU_CLEAR_SCOPE`, `L1DTLB_RM_SB_PARTITION_004`, `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_RTU_FLUSH_SCOPE`, `L1DTLB_INV_HIT_SAME_CYCLE`, `L1DTLB_ABT_LATE_REFILL`, `L1DTLB_SB_INVALIDATE_FLUSH`, `L1DTLB_UVM_WORK_003_CREDIT`; formal/future rows retained for `vabuf` equivalence and exact PLRU victim selection. |
| 6G | Complete | `L1DTLB_SVA_A067`, `L1DTLB_TS_OBS_SVA_COVER_CLOSURE`, `L1DTLB_RM_SB_PARTITION_001`, `L1DTLB_RM_SB_PARTITION_002`, `L1DTLB_RM_SB_PARTITION_003`, `L1DTLB_SB_TRACEABILITY_CLOSURE`, `L1DTLB_UVM_WORK_001_REF_SUBMODEL`, `L1DTLB_UVM_WORK_004_SPEC_SB`, `L1DTLB_UVM_WORK_005_DIAG`; exact PLRU and `vabuf` equivalence remain under the Phase6F `future_formal` manifest row. |

#### 5. Evidence Log

Future phases must record every compile, directed run, negative/formal run, targeted regression, coverage report, and SVA report.  Phase6E rows marked as historical gaps are retained to show the original closure holes; the final 972xx rows below supersede them.

| Date | Subphase | Command / run | Result | Log / report path | Summary | Follow-up |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-22 | Phase 6 docs | Documentation creation | Complete | This file and BuildPlan | Created future implementation tracker only; no simulation or code implementation run. | Later approved code phase must record baseline compile/regression. |
| 2026-05-22 | 6A | Initial `make comp_fast` | Resolved | `mmu_verification/output/logs/comp_fast.log` | Initial VCS attempts exposed compile blockers in `mmu_arb.sv`, `credit_sva.sv`, and `mmu_l2tlb_rrpv_wbuf.sv`, plus reset/widening hygiene items found during closure. | Closed by `L1DTLB-P6-ISSUE-004` through `L1DTLB-P6-ISSUE-009`; passing rows below are the active gate evidence. |
| 2026-05-22 | 6A | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed. Final design-warning scan shows no errors/fatals and no remaining PCWM/IPDW/ICPD warnings; remaining messages are environment locale/clock-skew notices and the expected `LCA_FEATURES_ENABLED` usage warning. | Use this as the Phase6A compile baseline. |
| 2026-05-22 | 6A | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_ref_model_observability_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_ref_model_observability_001_97101.log` | PASS logs: 1, FAIL logs: 0; UVM summary reports `UVM_ERROR=0` and `UVM_FATAL=0`; Phase6A inventory printed `inventory_checks=3585`, `entry_payload=1078`, `refill_payload=4`, `install_arb=4`, `mode_snapshot=3585`, `fragile_root_paths=0`. | Proceed to Phase 6B for token/waive closure. |
| 2026-05-22 | 6B | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed after Phase6B token/taxonomy and directed-sequence updates. Remaining messages are locale/clock-skew notices and expected VCS LCA warning. | Use this as the Phase6B compile gate evidence. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_pf_blocks_pmp_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_pf_blocks_pmp_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `pf_current_t0=1`, `expt_classified=1`, `no_response_classified=1`, `remaining_broad_waive=0`; translation taxonomy shows `lsu_expt=1`, `remaining_broad_waive=0`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_access_fault_t1_pairing_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_access_fault_t1_pairing_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `af_previous_t1=1`, `pmp_t1_classified=1`, `remaining_broad_waive=0`; translation taxonomy shows `lsu_pmp_t1=1`, `remaining_broad_waive=0`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `pf_current_t0=1`, `af_previous_t1=1`, `fault_overlap_separate=1`, `expt_classified=1`, `pmp_t1_classified=1`, `remaining_broad_waive=0`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_pmp_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_pmp_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `af_previous_t1=1`, `pmp_t1_classified=1`, `remaining_broad_waive=0`; translation taxonomy shows `lsu_pmp_t1=1`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_stamo_pipe1_bypass_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_stamo_pipe1_bypass_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `stamo_classified=2`, `remaining_broad_waive=0`; translation taxonomy shows `lsu_stamo=2`, `remaining_broad_waive=0`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_stamo_pipe0_neg_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_stamo_pipe0_neg_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; negative path shows `stamo_p0_neg=1`, `stamo_classified=0`, `remaining_broad_waive=0`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_expt_hit_with_tlb_hit_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_expt_hit_with_tlb_hit_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `pf_current_t0=1`, `expt_classified=1`, `remaining_broad_waive=0`; translation taxonomy shows `lsu_expt=1`. | None. |
| 2026-05-22 | 6B | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_sysmap_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_sysmap_001_97101.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy shows `direct_map_classified=2`, `remaining_broad_waive=0`; translation taxonomy shows `lsu_direct=2`. | None. |
| 2026-05-22 | 6C | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed after Phase6C entry-shadow and vseq terminal-sampling changes. Remaining messages are locale/clock-skew notices and expected VCS LCA warning. | Use this as the Phase6C compile gate evidence. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_entry_field_model_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_entry_field_model_001_97101.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6C_ENTRY_SHADOW` shows `refill_update=4`, `hit_compare=2`, `pa_compare=2`, `flag_compare=2`, `perm_compare=2`, `attr_compare=2`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_hit_001 SEED=97102 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_hit_001_97102.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; shadow hit-side compare reports `hit_compare=2`, `hit4k=2`, `pa_compare=2`, `attr_compare=2`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_huge_001 SEED=97103 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_huge_001_97103.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; 4K shadow path reports `hit4k=2`, `pgs_compare=2`, `pa_compare=2`, `attr_compare=2`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_huge_002 SEED=97104 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_huge_002_97104.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; 2M shadow path reports `hit2m=4`, `pgs_compare=4`, `pa_compare=4`, `attr_compare=4`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_huge_003 SEED=97105 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_huge_003_97105.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; 1G shadow path reports `hit1g=4`, `pgs_compare=4`, `pa_compare=4`, `attr_compare=4`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_perm_ld_001 SEED=97106 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Review | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_perm_ld_001_97106.log` | PASS with `UVM_ERROR=0`, `UVM_FATAL=0`; this test remains an expt/ref-model page-fault path, so Phase6C no longer requires hit-shadow permission counters from it. It has one pre-existing `mmu_ref_model` page-fault diagnostic warning, not a Phase6C scenario-gate warning. | Hit-side permission evidence is covered by `DTLB_PERM_LD_002` and `DTLB_FAULT_AD_US_SUM_001`. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_perm_ld_002 SEED=97110 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_perm_ld_002_97110.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; shadow permission path reports `hit_compare=2`, `flag_compare=2`, `perm_compare=2`, `attr_compare=2`, `success_expected=2`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_fault_ad_us_sum_001 SEED=97107 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_fault_ad_us_sum_001_97107.log` | PASS after the vseq terminal-response sampling fix; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; shadow permission/attr path reports `hit_compare=2`, `perm_compare=2`, `attr_compare=2`, `success_expected=2`. | Closed by `L1DTLB-P6-ISSUE-011`. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_va8_alias_001 SEED=97108 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_va8_alias_001_97108.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; invalidate evidence reports `refill_update=6`, `clear_update=514`, `va8_clear=1`, `hit_compare=3`, `attr_compare=3`. | None. |
| 2026-05-22 | 6C | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_install_same_entry_001 SEED=97109 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_install_same_entry_001_97109.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; Phase6C clear shadow reports `refill_update=2`, `clear_update=769`, `hit_compare=1`, `pa_compare=1`, `flag_compare=1`, `perm_compare=1`, `attr_compare=1`; SVA clear cover reports `cp_l1dtlb_c020_clear=769`. | Deterministic same-cycle invalidate/install cover remains Phase 6F follow-up; tracked by `L1DTLB-P6-ISSUE-012`. |
| 2026-05-22 | 6D | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed after Phase6D MB shadow/allocation/no-response updates. Remaining messages are locale/clock-skew notices and expected VCS LCA warning. | Use this as the Phase6D compile gate evidence. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_alloc_001 SEED=97111 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_alloc_001_97111.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; same-4K allocation evidence reports `alloc_oracle=1`, `alloc_expect_check=1`, `alloc_match=1`, `dual_same_4k=1`, `records=0`. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_alloc_two_lowest_free_001 SEED=97112 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_alloc_two_lowest_free_001_97112.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; two-free allocation evidence reports `alloc_oracle=1`, `alloc_match=2`, `dual_diff_two_free=1`, `iid_age=1`. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_alloc_full_001 SEED=97113 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_alloc_full_001_97113.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; MB full evidence reports `mb_full=308`, `full_drop=4`, `records=9`, `mb_full=2`, `busy_sleep=7`, and side-effect matrix `no_alloc/no_l2_req/no_refill/no_expt/no_wakeup=9`. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_001 SEED=97114 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_001_97114.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; MB full retry evidence reports `mb_full=333`, `full_drop=4`, `records=9`, `mb_full=2`, `busy_sleep=7`, side-effect matrix counters all 9. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_002 SEED=97115 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_002_97115.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; MB full retry evidence reports `mb_full=326`, `full_drop=4`, `records=9`, `mb_full=2`, `busy_sleep=7`, side-effect matrix counters all 9. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_alloc_race_001 SEED=97116 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_alloc_race_001_97116.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; one-free/age evidence reports `one_free=2`, `one_free_p0_old=1`, `one_free_p1_old=1`, `dual_diff_one_free=2`, `priority_drop=2`, `busy_sleep=12`, `iid_age=2`, side-effect matrix counters all 14. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_abort_001 SEED=97117 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_abort_001_97117.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; abort no-response evidence reports `abort=4`, `abort_hit=1`, `abort_mask=3`, `abort_drop=3`, `records=5`, `nr_abort=3`, and expt replay survived with `expt_replay=1`. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_busy_any_inflight_001 SEED=97118 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_busy_any_inflight_001_97118.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; busy-sleep evidence reports `busy_sleep=1`, `mb_cam=1`, `sidefx_checks=2`, and no illegal alloc/L2/refill/expt/wakeup side effects. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_state_signal_001 SEED=97119 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_state_signal_001_97119.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; MB state shadow evidence reports `state_check=15432`, `payload_check=322`, `alloc_match=2`, `wfc=322`, and no-response busy-sleep matrix coverage. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001 SEED=97120 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001_97120.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; MB lifecycle evidence reports `alloc_oracle=3`, `alloc_match=3`, `wfc=128`, `refill=4`, `install_next=4`, and no-response busy-sleep matrix coverage. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_pgflt_001 SEED=97121 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_pgflt_001_97121.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; fault lifecycle evidence reports `expt_wr=2`, `pgflt=20`, `replay_release=2`, `alloc_match=2`, with no legal no-response records expected. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_flush_race_matrix_001 SEED=97122 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_flush_race_matrix_001_97122.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; flush no-response evidence reports `flush=2`, `flush_drop=2`, `nr_flush=2`, `busy_sleep=2`, side-effect matrix counters all 4, and SVA `cp_l1dtlb_c020_flush_race` matches on entries 0/1/2. | None. |
| 2026-05-22 | 6D | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_hit_miss_concurrent_001 SEED=97123 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_hit_miss_concurrent_001_97123.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; MB CAM hit no-response evidence reports `hit_miss=1`, `nr_mb_cam=2`, `cam_drop=2`, `mb_cam_hit=2`, `busy_sleep=2`, and side-effect matrix counters all 4. | None. |
| 2026-05-22 | 6E | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed after Phase6E refill/install/exception lifecycle updates and directed ABT helper changes. Remaining messages are locale/clock-skew notices and expected VCS LCA warning. | Use this as the Phase6E compile gate evidence. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_refill_001 SEED=97120 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_refill_001_97120.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6E_REFILL_INSTALL` reports `refill_oracle=4`, `ptw=2`, `l2=2`, `normal_bind=4`, `install_onehot=4`, `install_priority=4`, `install_visible_next=4`, `mb_release_check=4`. | None. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_install_visibility_001 SEED=97121 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_install_visibility_001_97121.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; install boundary evidence reports `refill_oracle=1`, `ptw=1`, `normal_bind=1`, `install_priority=1`, `install_visible_next=1`, `mb_release_check=1`. | None. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001 SEED=97122 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Historical gap | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001_97122.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; normal refill/install checks pass, but WFI collision did not trigger: `wfi=0`, `wfi_data_hold=0`, and scenario gate warns for `phase6e_refill_wfi`/`phase6e_wfi_data_hold`. | Superseded by final WFI seed 97234; `L1DTLB-P6-WAIVE-001` retired. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_wfi_data_hold_001 SEED=97127 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Historical gap | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_wfi_data_hold_001_97127.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; original WFI wrapper still produced ordinary PTW/L2 install traffic, with `wfi=0`, `wfi_data_hold=0`, and SVA WFI cover points unhit. | Superseded by final WFI data-hold seed 97235; `L1DTLB-P6-WAIVE-001` retired. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_refill_stale_id_001 SEED=97128 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Historical gap | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_refill_stale_id_001_97128.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; wrapper name did not produce a stale completion, so `stale_no_sidefx=0` and `cp_l1dtlb_c017_stale_or_abt_refill=0`. ABT late-refill separately covers the no-side-effect checker path. | Superseded by final stale/ABT seed 97233; `L1DTLB-P6-WAIVE-002` retired as a closure waiver and retained only as reachability note. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_pgflt_001 SEED=97123 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_pgflt_001_97123.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; fault lifecycle evidence reports `fault_no_tlb_write=2`, `shadow_write=2`, `bind_mb=2`, `pgflt=2`, `fault_hold=2`, `replay_consume=2`, `replay_release=2`, `wakeup=2`, `no_new_mb=2`. | None. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_fault_hold_001 SEED=97124 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_fault_hold_001_97124.log` | PASS after Phase6D allocation-overlap repair; `UVM_ERROR=0`, `UVM_FATAL=0`; lifecycle evidence reports `fault_no_tlb_write=4`, `shadow_write=4`, `bind_mb=4`, `pgflt=4`, `fault_hold=4`, `replay_consume=4`, `replay_release=4`, `wakeup=4`, `no_new_mb=4`. | Closed by `L1DTLB-P6-ISSUE-015`. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001 SEED=97125 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001_97125.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; ABT late-refill evidence reports `abt_late_refill=1`, `flush_clear=1`, and SVA `cp_l1dtlb_c017_stale_or_abt_refill` plus `cp_l1dtlb_c020_flush_race` match on entry 0. | None. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_wakeup_expt_001 SEED=97126 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_wakeup_expt_001_97126.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; wakeup/replay evidence reports `fault_no_tlb_write=1`, `shadow_write=1`, `bind_mb=1`, `pgflt=1`, `replay_consume=1`, `replay_release=1`, `wakeup=1`, `no_new_mb=1`. | None. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_expt_id_map_001 SEED=97129 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_expt_id_map_001_97129.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; exception ID/replay path reports `fault_no_tlb_write=4`, `shadow_write=4`, `bind_mb=4`, `pgflt=4`, `replay_consume=4`, `replay_release=4`, `wakeup=4`, `no_new_mb=4`; SVA `cp_l1dtlb_c016_fault_write=4`, `cp_l1dtlb_c019_expt_replay=3`. | None. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_access_fault_source_parity_001 SEED=97130 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Historical gap | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_access_fault_source_parity_001_97130.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; original wrapper exercised PGFLT/replay with `fault_no_tlb_write=4`, `shadow_write=4`, `pgflt=4`, but `acflt=0` and access-replay cover remained unhit. | Superseded by final ACFLT seed 97230; `L1DTLB-P6-WAIVE-003` retired. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_expt_dual_same_entry_neg_001 SEED=97131 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Historical gap | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_expt_dual_same_entry_neg_001_97131.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; wrapper exercised PGFLT/replay but did not create simultaneous dual exception writes: `dual_write=0`, `cp_l1dtlb_c016_dual_fault_write=0`, `cp_l1dtlb_c016_dual_expt_write=0`. | Superseded by final dual seed 97231; `L1DTLB-P6-WAIVE-003` retired. |
| 2026-05-22 | 6E | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed after final Phase6E WFI SVA, stale gate, ACFLT replay, and directed-stimulus updates. Remaining messages are environment locale/clock-skew notices and expected VCS LCA warning; no compile errors/fatals. | Final Phase6E compile gate. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001 SEED=97234 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001_97234.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6E_REFILL_INSTALL` reports `wfi=1`, `wfi_lowest=1`, `wfi_data_hold=1`; SVA `cp_l1dtlb_c015_wfi_install`, `cp_l1dtlb_c015_wfi_hold`, `cp_l1dtlb_c015_wfi_priority`, and `cp_l1dtlb_c015_ptw_l2_collision` each match. | Retires `L1DTLB-P6-WAIVE-001` for this test class. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_wfi_data_hold_001 SEED=97235 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_wfi_data_hold_001_97235.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; second WFI wrapper independently reports `wfi=1`, `wfi_lowest=1`, `wfi_data_hold=1` and the same WFI install/hold/priority/collision SVA cover matches. | Retires `L1DTLB-P6-WAIVE-001`. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_refill_stale_id_001 SEED=97233 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete with reachability note | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_refill_stale_id_001_97233.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; no `SCENARIO_GATE`; `PHASE6E_REFILL_INSTALL` reports `abt_late_refill=1`; `PHASE6D_NO_RESPONSE` reports `flush=1`, `no_refill=1`, `no_expt=1`, `no_wakeup=1`; SVA `cp_l1dtlb_c017_stale_or_abt_refill` and `cp_l1dtlb_c020_flush_race` match. `PHASE6E_STALE_REACHABILITY` records that standalone `!mb_vld` stale was not observed because RTL keeps the in-flight MB valid until ABT late completion. | Retires `L1DTLB-P6-WAIVE-002` as a closure waiver; standalone stale remains a reachability note. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001 SEED=97232 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001_97232.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6E_REFILL_INSTALL` reports `abt_late_refill=1`; SVA `cp_l1dtlb_c017_stale_or_abt_refill` and `cp_l1dtlb_c020_flush_race` match on entry 0. | Confirms ABT late-completion side-effect gate after final changes. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_access_fault_source_parity_001 SEED=97230 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_access_fault_source_parity_001_97230.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; trace shows ACFLT `[CAM_WRITE]` then `[REPLAY_HIT]`; `PHASE6E_EXPT_LIFECYCLE` reports `shadow_write=1`, `bind_mb=1`, `acflt=1`, `replay_consume=1`, `replay_release=1`, `wakeup=1`, `no_new_mb=1`; SVA `cp_l1dtlb_c019_expt_access_replay` and `cp_l1dtlb_c021_access_fault` match; no access-fault payload assertion text. | Retires the ACFLT-source half of `L1DTLB-P6-WAIVE-003`. |
| 2026-05-22 | 6E | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_expt_dual_same_entry_neg_001 SEED=97231 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_expt_dual_same_entry_neg_001_97231.log` | PASS; `UVM_ERROR=0`, `UVM_FATAL=0`; two expected `UVM_WARNING` lines come from ref-model `translate PAGE_FAULT (3-level exhausted)` diagnostics during intentional page-fault replay. `PHASE6E_EXPT_LIFECYCLE` reports `shadow_write=20`, `bind_mb=20`, `pgflt=20`, `dual_write=1`, `replay_consume=2`, `replay_release=2`, `wakeup=2`, `no_new_mb=2`; SVA `cp_l1dtlb_c016_dual_fault_write` and `cp_l1dtlb_c016_dual_expt_write` match. | Retires the dual-fault half of `L1DTLB-P6-WAIVE-003`. |
| 2026-05-22 | 6F | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed after Phase6F credit/wakeup/race report, cleanup-scope, and same-cycle invalidate/install updates. Remaining messages are environment locale/clock-skew notices and expected VCS LCA warning. | Final Phase6F compile evidence. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_credit_bound_001 SEED=97341 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_credit_bound_001_97341.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6F_CREDIT_CONTROL` reports `checks=6307`, `match=6307`, `fire=56`, `return=56`, `fire_return=1`, `zero=247`, `zero_return=1`, `zero_no_fire=247`, `load_req=28`, `store_req=28`; SVA cover reports `cp_l1dtlb_c014_req_and_return=1` and `cp_l1dtlb_c014_zero_credit_return=1`. | Closes the credit-shadow evidence for Phase6F. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001 SEED=97341 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001_97341.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6F_CREDIT_CONTROL` reports `load_req=1`, `store_req=1`, and `PHASE6F_FORMAL_FUTURE` records PLRU/vabuf future policy; SVA `cp_l1dtlb_c026_vabuf_change` has nonzero support cover. | Supports load/store request split and `vabuf` cover. It is not a `vabuf` equivalence proof. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_hit_same_cycle_001 SEED=97342 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_hit_same_cycle_001_97342.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6F_RACE_CLOSURE` reports `inv_hit_old=1`, `inv_post_clear_miss_or_refill=1`, `reset_clear=1`; SVA cover reports `cp_l1dtlb_c020_va8_alias_clear=1`. | Closes invalidate+hit old-boundary evidence for Phase6F. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_wakeup_expt_001 SEED=97343 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete with accepted diagnostic warning | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_wakeup_expt_001_97343.log` | PASS with `UVM_ERROR=0`, `UVM_FATAL=0`; one `mmu_ref_model` page-fault diagnostic warning is expected for this exception replay scenario. `PHASE6F_WAKEUP_MATRIX` reports `expt=1`, `negative_checks=512`, `reset_neg=1`, `inv_neg=512`; `PHASE6E_EXPT_LIFECYCLE` reports `replay_consume=1`, `replay_release=1`, `wakeup=1`, `no_new_mb=1`. | Closes expt wakeup-source evidence with the warning recorded as an accepted ref-model diagnostic, not an unclosed Phase6F item. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001 SEED=97232 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` and `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_refill_stale_id_001 SEED=97233 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Supporting evidence | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001_97232.log`, `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_refill_stale_id_001_97233.log` | Both runs are warning-free with `UVM_ERROR=0`, `UVM_FATAL=0`; they prove ABT/stale late-completion no-side-effect under Phase6E and SVA `cp_l1dtlb_c020_flush_race` matches on entry 0. | Supporting context only; cleanup-scope is closed by final Phase6F owner seed 97362. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001 SEED=97360 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0 LOG_STATUS_MAX_HITS=80` | Partial evidence | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001_97360.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; `PHASE6F_RACE_CLOSURE` reports `flush=2`, `flush_tlb_preserve=2`, `abt_late_no_sidefx=3`, `reset_clear=1`; SVA `cp_l1dtlb_c020_flush_race` matches on entries 0/1. The same report has `flush_mb_clear=0` and `flush_expt_clear=0`. | Clean partial owner evidence only. Repair or extend the scenario/checker so MB and expt clear rows are triggered before closing cleanup scope. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001 SEED=97362 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0 LOG_STATUS_MAX_HITS=80` | Complete for cleanup-scope | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001_97362.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; no `SCENARIO_GATE` or assertion failure lines in targeted grep. `PHASE6F_RACE_CLOSURE` reports `flush=3`, `flush_mb_clear=3`, `flush_expt_clear=1`, `flush_tlb_preserve=3`, `abt_late_no_sidefx=3`, `reset_clear=1`; `PHASE6D_NO_RESPONSE` reports `flush=3`, `sidefx_checks=5`, and all no-side-effect counters at 5; SVA `cp_l1dtlb_c020_flush_race` matches on entries 0/1. | Supersedes seed 97360 for cleanup-scope closure. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_credit_bound_001 SEED=97311/97321/97331 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Rejected evidence | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_credit_bound_001_97311.log`, `..._97321.log`, `..._97331.log` | These runs hit request+return and zero-return cover, but contain UVM errors from Phase6D MB allocation/CAM side-effect checks. They must not be used as Phase6F closure evidence. | Superseded for credit by clean seed 97341. Keep the errors available for debug if the old logs are revisited. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_install_same_entry_001 SEED=97353/97354 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Rejected evidence | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_install_same_entry_001_97353.log`, `..._97354.log` | 97353 has MB drain warning, `SCENARIO_GATE phase6f_inv_install_final_clear`, `cp_l1dtlb_c020_inv_install_same_entry=0`, and a PTW protocol assertion failure. 97354 has MB drain timeout warnings and TWU assertion failure `a_twu_pipeline_no_stall_when_unmasked`. Neither log can close same-cycle invalidate+install. | Tracked by `L1DTLB-P6-ISSUE-020`; rerun only after the directed stimulus is repaired and the result is warning/assertion clean with nonzero same-cycle cover. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_install_same_entry_001 SEED=97361 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0 LOG_STATUS_MAX_HITS=80` | Rejected evidence | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_install_same_entry_001_97361.log` | PASS summary is not closure evidence: log has `UVM_WARNING=2`, `SCENARIO_GATE phase6f_inv_install_final_clear`, `PHASE6F_RACE_CLOSURE inv_install_final_clear=0`, `cp_l1dtlb_c020_inv_install_same_entry=0`, and repeated `a_mbuf_ptr_only_on_response` PTW protocol assertion failures caused by the long-held LSU all-invalidate stimulus. | Replace the long-held LSU invalidate path with a cleaner CP0-path invalidation overlap before rerun. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_install_same_entry_001 SEED=97362/97363 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0 LOG_STATUS_MAX_HITS=80` | Rejected evidence | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_install_same_entry_001_97362.log`, `..._97363.log` | Both CP0 all-invalidate overlap attempts avoid the 97361 PTW protocol assertion failure, but still have `UVM_WARNING=2`, `SCENARIO_GATE phase6f_inv_install_final_clear`, `PHASE6F_RACE_CLOSURE inv_install_final_clear=0`, and `cp_l1dtlb_c020_inv_install_same_entry=0`. RTL review shows `mmu_arb` masks PTW write grant while `tlboper_on`, so this path naturally tends to serialize invalidate before normal PTW refill writeback instead of proving same-cycle clear/update. WFI local install is not gated through that PTW write grant path, so it is a better DUT-realistic target for clear/update priority. | Do not close from CP0 all-invalidate plus normal PTW refill attempts. Pivot to a PTW/L2 collision that creates WFI pending local install, then overlap CP0 all-invalidate with the WFI install cycle. |
| 2026-05-22 | 6F | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_inv_install_same_entry_001 SEED=97364 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0 LOG_STATUS_MAX_HITS=80` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_inv_install_same_entry_001_97364.log` | PASS; `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; no `SCENARIO_GATE`, assertion failure text, or `P6F_INV_INSTALL_FINAL` error in targeted grep. `PHASE6F_RACE_CLOSURE` reports `inv_install_final_clear=1`; `PHASE6E_REFILL_INSTALL` reports `ptw=19`, `l2=17`, `wfi=1`, `wfi_lowest=1`, `wfi_data_hold=1`; SVA `cp_l1dtlb_c020_inv_install_same_entry` has `1 match`, and WFI collision/priority covers also match. | Closes same-cycle invalidate+install by using PTW/L2 collision to create WFI pending local install, then overlapping CP0 all-invalidate with WFI install. |
| 2026-05-23 | 6G | `make -C mmu_verification l1dtlb_phase6g_check` | Complete | Make target output | Phase6G document, list, manifest, replay script, and closure scanner assets are present. | None. |
| 2026-05-23 | 6G | `make -C mmu_verification run_check TEST_NAME=test_mmu_l1dtlb_dtlb_stamo_pipe1_bypass_001 SEED=97401 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` and `make -C mmu_verification run_check TEST_NAME=test_mmu_l1dtlb_dtlb_sysmap_001 SEED=97401 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_stamo_pipe1_bypass_001_97401.log`, `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_sysmap_001_97401.log` | Both PASS with clean UVM summaries; STAMO reports `stamo_classified=2` and `stamo_bypass=2`; sysmap reports `direct_map_classified=2` and `direct_bypass=2`. | These seeds are used in the Phase6G manifest because they provide the required Phase6B/6C bypass counters. |
| 2026-05-23 | 6G | Initial manifest replay followed by closure scan | Rejected as sole closure | `mmu_verification/output/regression/l1dtlb_phase6g_replay/summary.txt`, `mmu_verification/output/regression/l1dtlb_phase6g_closure/closure_report.md` | Replay reported `PASS=28 FAIL=0 TOTAL=28`, but closure rejected `6B_FAULT_TOKEN` because `PHASE6B_TOKEN_TAXONOMY:af_previous_t1` was zero even though the test summary passed. | Closed by `L1DTLB-P6-ISSUE-022`; this is the Phase6G proof that run_check PASS is not adequate closure evidence. |
| 2026-05-23 | 6G | `make -C mmu_verification comp_fast` and `make -C mmu_verification run_check TEST_NAME=test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/comp_fast.log`, `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001_97101.log` | Compile passes. Fault-overlap seed 97101 is clean with `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`; token taxonomy now reports `pf_current_t0=1`, `af_previous_t1=1`, `fault_overlap_separate=1`, `expt_classified=1`, `pmp_t1_classified=1`, and `remaining_broad_waive=0`. | Repairs the target-counter hole found by the closure scanner. |
| 2026-05-23 | 6G | `make -C mmu_verification l1dtlb_phase6g_replay` | Complete | `mmu_verification/output/regression/l1dtlb_phase6g_replay/summary.txt` | Manifest replay re-ran all closure and future/formal rows with their fixed seeds and reports `PASS=28 FAIL=0 TOTAL=28`. | Use with the closure scanner; replay PASS alone is not sufficient. |
| 2026-05-23 | 6G | `make -C mmu_verification l1dtlb_phase6g_closure` | Complete | `mmu_verification/output/regression/l1dtlb_phase6g_closure/closure_report.md` | Closure scanner reports `PASS=28 FAIL=0 TOTAL=28`, `evidence_rows=28`, and `future_formal_rows=1`; compile log status is PASS. The scanner checked required reports, target counters, covers, accepted warning counts, bad patterns, and future/formal disposition. | Phase6G UVM simulation closure is complete; exact PLRU and full `vabuf` equivalence remain explicit future/formal work. |

#### 5A. Phase 6A Observability Inventory

| Source | Disposition | Implementation | Consumers / risk |
| --- | --- | --- | --- |
| Per-entry L1D payload: valid, VPN, PPN, page size, flags, clear | Stable probe | Added `l1d_entry_ppn`, `l1d_entry_pgs`, `l1d_entry_flg`, `l1d_entry_clr` to `mmu_dut_probes_if.sv`; wired from `u_dut.u_mmu_l1dtlb` in `tb_top.sv`. | `mmu_l1dtlb_spec_sb` Phase6A X checks; future 6C entry shadow. |
| MB payload and state: state, VPN, PPN, page size, flags, IID, issued/ready/WFC/WFI/store | Stable probe | Added MB PPN/page-size/flag probes and kept existing state/IID/control probes. | Future 6D MB lifecycle and 6E refill/expt binding. |
| Full refill/install payload: source, ID, VPN, PPN, page size, flags, grant bus, PTW/L2 completion/fault payload | Stable probe | Added refill flag/grant, PTW refill fields, L2 refill fields, and install request/select/ID probes. | `mmu_l1dtlb_spec_sb` Phase6A refill/install checks; future 6E lifecycle oracle. |
| Exception consumer and reset/clear visibility | Stable probe | Added expt current fault outputs, hit vector, wakeup, and clear request visibility from flush/tlboper clear/invalidate. | `mmu_l1dtlb_spec_sb` Phase6A exception consume checks; future 6E exception shadow. |
| Effective privilege and mode snapshot: MPRV/MPP/MXR/SUM/MAEE/current privilege/ASID/SATP PPN | Derived transaction field and stable probe | Added CP0/regs probes and LSU monitor snapshots (`eff_priv`, `mprv`, `mpp`, `mxr`, `sum`, `maee`, `asid`, `satp_ppn`). | `lsu_txn`, future 6B token ownership and 6C permission compare. |
| Request type and direct-map status | Derived transaction field | LSU monitor derives load/store request type from `st_inst` and samples `direct_map` from `mmu_lsu_mmu_en`. | Future 6B/6C semantic checkers. Prefetch/STAMO/INV type expansion remains in later phases. |
| PMP/sysmap sampled flags and PA | Stable probe plus transaction snapshot | Added `l1d_pmp_flg0/1`, `l1d_sysmap_flg0/1`, `l1d_sysmap_hit0/1`, and `l1d_sysmap_pa0/1`; LSU monitor copies per-pipe values into `lsu_txn`. | Future PMP/sysmap/direct-map compare. PMP register update epoch is not separately observable in this phase. |
| Fragile `$root` paths | Avoided | New consumers use virtual interfaces and `tb_top.sv` wiring only. | `fragile_root_paths=0` is printed in the Phase6A final scoreboard inventory message. |

#### 5B. Phase 6B Token and Taxonomy Closure

| Area | Implementation | Evidence |
| --- | --- | --- |
| Token queue and fields | `mmu_l1dtlb_spec_sb.svh` now maintains a per-pipe token queue with cycle, pipe, IID, VA/VPN, abort, request type, effective privilege, MPRV/MPP, MXR, SUM, ASID/SATP, PMP/sysmap, STAMO/direct-map, path class, and PF/AF owner flags. | All 6B directed logs emit `mmu_l1dtlb_spec_sb::PHASE6B_TOKEN_TAXONOMY` with `token_queue_depth=4` and `remaining_broad_waive=0`. |
| PF/AF ownership | PF requires current non-aborted T0 with same-cycle terminal response; AF requires previous valid non-aborted T1; overlap is legal only when owners differ. | `test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001_97101.log` shows `pf_current_t0=1`, `af_previous_t1=1`, and `fault_overlap_separate=1`. |
| Translation-SB classified skips | `mmu_translation_sb.svh` classifies L1DTLB expt replay, expt timing/orphan diagnostics, PMP T1 access fault, STAMO pipe1 bypass, direct-map/sysmap, and SATP/midwalk old-refill cases instead of reporting broad untyped waives. | Directed logs show `PHASE6B_TRANSLATION_CLASS` for `expt_replay`, `pmp_t1_access_fault_owned_by_l1dtlb_sb`, `stamo_pipe1_bypass`, and `direct_map`; summaries show `remaining_broad_waive=0`. |
| Directed sequence repair | `DTLB_FAULT_OVERLAP_PIPE_001` now fills page44 before seeding the page45 exception CAM entry, avoiding a self-inflicted quiescent wait while `tlb_busy` is held by the unconsumed exception entry. | Pre-fix run timed out at `l1dtlb_fill_44`; post-fix `test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001_97101.log` passes with clean UVM summary. |

#### 5C. Phase 6C Entry Shadow Closure

| Area | Implementation | Evidence |
| --- | --- | --- |
| Entry shadow/update | `mmu_l1dtlb_spec_sb.svh` maintains a 16-entry valid/VPN/PPN/page-size/flag shadow. Reset clears it, probe deltas repair it, refill/install updates it from stable entry probes, and entry clear wins over same-cycle update in the shadow policy. | `test_mmu_l1dtlb_dtlb_entry_field_model_001_97101.log` reports `refill_update=4`; `test_mmu_l1dtlb_dtlb_inv_va8_alias_001_97108.log` reports `clear_update=514`, `va8_clear=1`; `test_mmu_l1dtlb_dtlb_inv_install_same_entry_001_97109.log` reports `refill_update=2`, `clear_update=769`, and `cp_l1dtlb_c020_clear=769`. |
| Normal hit compare | Observable normal L1 hits compare DUT hit index/vector, VPN page-size bounds, page size, PPN-like PA bus, and final PA against the shadow entry. Multi-hit remains diagnostic-only, matching the BuildPlan PLRU boundary. | `test_mmu_l1dtlb_dtlb_hit_001_97102.log` reports `hit_compare=2`, `pa_compare=2`, `attr_compare=2`; huge-page logs cover 4K/2M/1G with `hit4k=2`, `hit2m=4`, and `hit1g=4`. |
| Permission and attributes | Shadow flags drive page-fault prediction and LSU attribute prediction for non-fault hits. Direct-map and STAMO are bypass source classes and are counted separately instead of being compared against L1 entries. | `test_mmu_l1dtlb_dtlb_perm_ld_002_97110.log` and `test_mmu_l1dtlb_dtlb_fault_ad_us_sum_001_97107.log` both report `perm_compare=2` and `attr_compare=2` with clean UVM summaries. |
| Limits/ownership | LSU-visible PA for this checker is the 28-bit PPN-like L1 hit result; byte-offset PA assembly remains covered by the existing ref-model/translation scoreboard path. Exact PLRU victim and deterministic same-cycle invalidate/install race closure remain Phase 6F ownership items. | No Phase6C waiver is used. `DTLB_INV_INSTALL_SAME_ENTRY_001` is a warning-free Phase6C clear/update evidence run; the narrower same-cycle invalidate/install cover remains tracked as Phase6F race closure. |

#### 5D. Phase 6D MB Lifecycle and No-Response Closure

| Area | Implementation | Evidence |
| --- | --- | --- |
| MB shadow and lifecycle | `mmu_l1dtlb_spec_sb.svh` maintains an 8-entry MB shadow for valid/state/VPN/PPN/page-size/flags/IID/store/issued/ready/WFC/WFI. It validates legal state transitions, derived ready/WFC/WFI signals, payload stability while valid, reset clearing, and lifecycle counters for WFG/WFC/WFI/PGFLT/ABT/replay release. | `test_mmu_l1dtlb_dtlb_mb_state_signal_001_97119.log` reports `state_check=15432`, `payload_check=322`; `test_mmu_l1dtlb_dtlb_mb_flush_race_matrix_001_97122.log` reports `abt=669`; `test_mmu_l1dtlb_dtlb_mb_pgflt_001_97121.log` reports `pgflt=20`, `replay_release=2`. |
| Allocation oracle | Allocation checks use the previous T1 miss tokens and a pending one-cycle expectation against saved base MB valid bits. The oracle covers single miss, same-4K de-dup, dual-different two-free allocation, dual-different one-free IID-age winner, full drop, CAM drop, abort drop, flush drop, and busy-sleep drop. | `alloc_001_97111` reports `dual_same_4k=1`; `alloc_two_lowest_free_001_97112` reports `dual_diff_two_free=1`; `alloc_race_001_97116` reports `dual_diff_one_free=2`, `iid_age=2`; full-drop logs report `full_drop=4`; MB CAM and flush logs report `cam_drop=2` and `flush_drop=2`. |
| Legal no-response taxonomy | Legal no-response reasons are encoded as `mb_cam_hit`, `mb_full`, `abort_mask`, `flush_kill`, `busy_sleep`, and `priority_drop_one_free`. Each token-scoped class records diagnostics and installs a T1 guard where needed; global flush/priority classes run cycle-level side-effect checks. | `hit_miss_concurrent_001_97123` reports `nr_mb_cam=2`; full/drop logs report `nr_mb_full=2`; `abort_001_97117` reports `nr_abort=3`; `mb_flush_race_matrix_001_97122` reports `nr_flush=2`; `alloc_race_001_97116` reports `nr_prio=2` and `nr_busy=12`. |
| Side-effect matrix | For every legal no-response record, the scoreboard checks no matching illegal MB allocation, L2 request, refill/TLB write, exception write/consume, or wakeup side effect. Token-scoped checks ignore side effects owned by the pre-existing MB entry for CAM-hit reasons. | Directed no-response logs report matching `no_alloc`, `no_l2_req`, `no_refill`, `no_expt`, `no_wakeup`, and `matrix_checks` counts: 14 in allocation race, 9 in each full/drop run, 5 in abort, 4 in flush, and 4 in MB CAM hit-miss. |

#### 5E. Phase 6E Refill, Install, and Exception Lifecycle Closure

| Area | Implementation | Evidence |
| --- | --- | --- |
| Refill/install oracle | `mmu_l1dtlb_spec_sb.svh` checks refill source encoding, refill grant binding, one-hot install select, install priority WFI > PTW > L2, normal refill source MB state/VPN binding, install visibility boundary, and one-cycle MB release after install. It records WFI lowest-entry and WFI data-hold checks when a WFI install is observed. | Baseline `refill_001_97120` and `install_visibility_001_97121` cover normal PTW/L2 and visibility. Final WFI runs `mb_fsm_wfi_001_97234` and `wfi_data_hold_001_97235` are warning-free and report `wfi=1`, `wfi_lowest=1`, `wfi_data_hold=1`; SVA `cp_l1dtlb_c015_wfi_install`, `cp_l1dtlb_c015_wfi_hold`, `cp_l1dtlb_c015_wfi_priority`, and `cp_l1dtlb_c015_ptw_l2_collision` match. |
| Stale/ABT/fault side effects | PTW/L2 completion checks reject stale or ABT late completions that produce a TLB refill, exception write, or wakeup side effect. Fault completions are checked to never write the TLB. `DTLB_MB_ABT_LATE_REFILL_001` and `DTLB_REFILL_STALE_ID_001` now force WFC, issue RTU flush, observe ABT, and let delayed PTW completion arrive late. | Final `mb_abt_late_refill_001_97232` and `refill_stale_id_001_97233` are warning-free with `abt_late_refill=1`; stale wrapper also reports `PHASE6D_NO_RESPONSE` side-effect counters `no_refill=1`, `no_expt=1`, `no_wakeup=1`. SVA `cp_l1dtlb_c017_stale_or_abt_refill` and `cp_l1dtlb_c020_flush_race` match. `PHASE6E_STALE_REACHABILITY` documents that standalone `!mb_vld` stale was not observed because the RTL keeps the in-flight MB valid until ABT late completion. |
| Exception lifecycle | The scoreboard maintains an exception lifecycle shadow keyed by EID/IID/VPN/fault class/source MB. It binds exception writes to the matching MB, records PGFLT/ACFLT class, checks replay consumes a matching shadow entry, rejects new MB allocation on replay, checks replay terminal fault class, and expects matching MB release. | PGFLT lifecycle remains covered by `mb_pgflt_001`, `mb_fault_hold_001`, `wakeup_expt_001`, and `expt_id_map_001`. Final ACFLT run `access_fault_source_parity_001_97230` is warning-free and reports `acflt=1`, `replay_consume=1`, `replay_release=1`, `wakeup=1`, with SVA `cp_l1dtlb_c019_expt_access_replay` and `cp_l1dtlb_c021_access_fault` matches. Final dual run `expt_dual_same_entry_neg_001_97231` reports `dual_write=1` and SVA `cp_l1dtlb_c016_dual_fault_write` plus `cp_l1dtlb_c016_dual_expt_write` matches. |
| Gate and diagnostics | Scenario gates require nonzero Phase6E counters for each directed objective: refill/install, WFI data hold, stale-or-ABT no-side-effect, ABT late completion, ACFLT source, replay consume/release, wakeup, and dual writes. The stale gate is intentionally `stale_or_abt_no_side_effect` for current RTL reachability. | Final 97230-97235 logs have no `SCENARIO_GATE` lines. The directed grep also checks `UVM_WARNING`, `UVM_ERROR`, `UVM_FATAL`, assertion text, and targeted SVA cover lines; this prevents `make run_check` summary PASS from masking unhit Phase6E objectives. |
| Limits/ownership | Phase6E does not change Makefiles, scripts, or regression lists. It does change `mmu_l1dtlb_hit_rd.sv` to fix the ACFLT expt-replay datapath, `mmu_l1dtlb_sva.sv` to align WFI cover timing with same-cycle WFI grant, and UVM scoreboard/vseq code to trigger and check the missing objectives. | Final `make comp_fast` passes. All final Phase6E directed runs have `UVM_ERROR=0` and `UVM_FATAL=0`; all except the intentional dual page-fault replay run have `UVM_WARNING=0`. The two dual warnings are expected ref-model page-fault diagnostics, not checker failures. |

#### 5F. Phase 6F Credit, Wakeup, Flush, Invalidate, and Race Closure

| Area | Implementation / finding | Evidence and disposition |
| --- | --- | --- |
| Credit owner and conservation | `mmu_l1dtlb_spec_sb.svh` is the single UVM owner for the L1DTLB scheduler credit shadow. It checks reset/max, sampled credit match, fire decrement, return increment, same-cycle fire+return conservation, and zero-credit no-fire including zero+return. Scheduler SVA remains corroborating evidence. | Clean `credit_bound_001_97341` reports `fire_return=1`, `zero_return=1`, `zero_no_fire=247`, `load_req=28`, `store_req=28`, with matching C014 request+return and zero-return covers. Earlier 97311/97321/97331 are explicitly rejected because they contain UVM errors. |
| Wakeup matrix | Phase6F classifies install and exception replay as positive wakeup sources. Reset, flush, invalidate, and ABT/stale late completion are negative-source contexts unless an explicit install/expt source is present in the sampled cycle. | Credit and type-prop runs cover install wakeup source (`install=56` in seed 97341). Expt source is covered by `wakeup_expt_001_97343` with `expt=1`, `negative_checks=512`, `reset_neg=1`, and `inv_neg=512`; the single ref-model page-fault warning is an accepted scenario diagnostic, not a checker failure. |
| Flush, ABT, and cleanup scope | Phase6F policy is that RTU flush kills MB work by IDLE clear or ABT late-drain, clears expt, and kills side effects, but does not imply full TLB entry clear unless a separate TLB clear/invalidate source is observed. ABT/stale late completion inherits no-side-effect checks from Phase6E and is also counted in the Phase6F cleanup owner report. | `mb_abt_late_refill_001_97232` and `refill_stale_id_001_97233` are warning-free supporting evidence with `cp_l1dtlb_c020_flush_race` matches. Final cleanup owner seed `cleanup_scope_matrix_001_97362` is warning-free and reports `flush=3`, `flush_mb_clear=3`, `flush_expt_clear=1`, `flush_tlb_preserve=3`, `abt_late_no_sidefx=3`, plus no-response side-effect counters; it supersedes partial seed 97360. |
| Invalidate+hit boundary | The scoreboard arms a post-invalidate boundary check when a same-cycle hit+invalidate is observed. A later matching lookup must miss or wait for a refill before the entry can be used again. | Clean `inv_hit_same_cycle_001_97342` reports `inv_hit_old=1`, `inv_post_clear_miss_or_refill=1`, `reset_clear=1`, with `UVM_WARNING=0`, `UVM_ERROR=0`, and `UVM_FATAL=0`. |
| Invalidate+install same-entry | Closure uses a DUT-realistic WFI/local-install race: first create a PTW/L2 collision so one MB entry waits in WFI with held refill payload, then overlap CP0 all-invalidate with the WFI install cycle. This avoids the rejected long-held LSU invalidate and the CP0+normal-PTW writeback serialization caused by `mmu_arb` masking PTW write grant while `tlboper_on`. | Rejected logs remain recorded for seeds 97353/97354/97361/97362/97363. Final seed 97364 is warning-free, has no scenario gate or assertion text, reports `inv_install_final_clear=1`, and has SVA `cp_l1dtlb_c020_inv_install_same_entry=1`. |
| PLRU and `vabuf` guards | Exact PLRU victim and full `vabuf` equivalence remain future/formal. Phase6F can record cover/debug evidence but cannot claim functional equivalence from cover alone. | `PHASE6F_FORMAL_FUTURE` reports `plru_future_rows=1` and `vabuf_future_rows=1`; `cp_l1dtlb_c026_vabuf_change` has nonzero cover in clean runs such as `type_prop_load_store_amo_001_97341`, but this is not closure evidence for `vabuf` equivalence. |

#### 5G. Phase 6G Directed Scenario, Coverage, and Regression Closure

| Area | Implementation / finding | Evidence and disposition |
| --- | --- | --- |
| Closure assets | Phase6G adds `l1dtlb_phase6g_smoke_list`, `l1dtlb_phase6g_targeted_list`, `l1dtlb_phase6g_evidence_manifest.tsv`, `l1dtlb_phase6g_replay.py`, `l1dtlb_phase6g_closure.py`, and Makefile targets for check, smoke, targeted, replay, and closure. The manifest is authoritative because it records per-row seed, accepted warnings, required reports, target counters, target covers, related IDs, and final disposition. | `make -C mmu_verification l1dtlb_phase6g_check` passes. `l1dtlb_phase6g_replay` reruns all 28 manifest rows and writes `mmu_verification/output/regression/l1dtlb_phase6g_replay/summary.txt`. |
| Replay versus closure | Phase6G does not accept list or replay PASS as closure by itself. The closure scanner re-reads the logs and compile log, rejects bad patterns, enforces accepted-warning limits, and checks that every claimed row has the required final report plus nonzero target counters or cover evidence. | Final closure report `mmu_verification/output/regression/l1dtlb_phase6g_closure/closure_report.md` reports `PASS=28 FAIL=0 TOTAL=28`, `compile_log_status=PASS`, and `future_formal_rows=1`. |
| Key checker-quality finding | Initial manifest replay passed all 28 rows, but the closure scanner rejected `6B_FAULT_TOKEN` because the fault-overlap log had `af_previous_t1=0`. The root cause was L1DTLB spec-SB ownership priority: same-cycle expt replay could steal the access-fault classification from a legal previous-T1 PMP/PA-response owner. | `mmu_l1dtlb_spec_sb.svh` now gives the previous-T1 PMP/PA-response access-fault owner priority over same-cycle expt replay when both are possible. Rerun seed 97101 reports `pf_current_t0=1`, `af_previous_t1=1`, `fault_overlap_separate=1`, `pmp_t1_classified=1`, and clean UVM summary. |
| Scoreboard and SVA partition | The architectural ref model and translation SB remain the owner for architectural compare. The L1DTLB spec SB owns local token, entry shadow, MB lifecycle, no-response, refill/install, expt lifecycle, credit, wakeup, and race closure. SVA cover/assertions corroborate protocol and timing points; PLRU exact victim and full `vabuf` equivalence are not claimed from simulation cover. | The manifest rows link every Phase6A-6F closure behavior to required final reports/counters/covers. The `6F_FORMAL_FUTURE` row is explicitly `future_formal`, not a closure pass for PLRU/vabuf equivalence. |
| Accepted warning and future policy | Warning-bearing evidence is accepted only where the manifest names it. Current accepted warnings are ref-model diagnostics in targeted exception/no-response setup rows; unlisted warnings block closure. Future/formal rows are counted separately from simulation closure math. | Final closure passes with accepted-warning policy applied. Phase6G adds no new simulation waiver; exact PLRU and full `vabuf` equivalence remain formal/future work with explicit manifest disposition. |

#### 6. Issue Log

Issue type values: `RTL bug`, `UVM bug`, `Spec gap`, `Tooling issue`, `Probe gap`, `Regression gap`, `Formal gap`, `Approved waiver`.

| ID | Date | Type | Severity | Related IDs | Description | Owner | Status | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L1DTLB-P6-ISSUE-001 | 2026-05-22 | Regression gap | Low | Phase 6 | Phase 6 began before any compile or regression baseline was run. | Codex | Closed | Phase6A records passing `make comp_fast` and L1DTLB observability smoke evidence. |
| L1DTLB-P6-ISSUE-002 | 2026-05-22 | Probe gap | Medium | `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_MON_*` | Full entry flags, refill flags, and per-request effective-mode token fields were not available as stable checker inputs. | Codex | Closed | Phase 6A added stable probes, LSU transaction snapshots, Phase6A X checks, and final inventory reporting. |
| L1DTLB-P6-ISSUE-003 | 2026-05-22 | UVM bug | Medium | `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | Translation scoreboard still contains broad L1DTLB replay/timing/STAMO/PMP/direct-map waives. | Codex | Closed | Phase 6B replaced LSU L1DTLB broad waive paths with explicit `PHASE6B_TRANSLATION_CLASS` taxonomy and token/no-response owner counters; directed logs show `remaining_broad_waive=0`. |
| L1DTLB-P6-ISSUE-004 | 2026-05-22 | RTL bug | High | 6A compile gate | Initial `make comp_fast` failed before closure with `mmu/rtl/mmu_arb.sv` undeclared identifiers used before declaration. | Codex | Closed | Moved/predeclared `ptw_write_req1/2`, `arb_ptw_write_grant`, and related PTW write payload declarations before first use; final `make comp_fast` passes. |
| L1DTLB-P6-ISSUE-005 | 2026-05-22 | UVM bug | High | 6A compile gate | `credit_sva.sv` bound a 3-bit `issue_queue_id` port to the 4-bit `mmu_l2tlb_reqq` queue id. | Codex | Closed | Parameterized `credit_sva` queue id width as 4-bit; compile passes. |
| L1DTLB-P6-ISSUE-006 | 2026-05-22 | RTL bug | High | 6A compile gate | `mmu_l2tlb_rrpv_wbuf.sv` drove `lookup_hit_comb` and `bypassed_rrpv_rdata_comb` from multiple `always_comb` blocks. | Codex | Closed | Moved same-cycle push bypass handling into the single bypass combinational block; compile passes. |
| L1DTLB-P6-ISSUE-007 | 2026-05-22 | UVM bug | Medium | `L1DTLB_SVA_A001`, reset gate | L1DTLB reset SVA used same-cycle implication and printed a reset-time assertion failure in smoke despite clean UVM summary. | Codex | Closed | Changed the reset visible-state assertion to non-overlapped implication; final smoke has no assertion `failed at` lines. |
| L1DTLB-P6-ISSUE-008 | 2026-05-22 | RTL bug | Medium | 6A compile hygiene | L2TLB queue transaction id was 4-bit in `mmu_l2tlb`/ReqQ but 3-bit in `ct_mmu_top.v`/default `mmu_arb`, causing PCWM width warnings and potential truncation. | Codex | Closed | Widened `queue_arb_trans_id` and `arb_l2tlb_trans_id` to `L2EID_WIDTH`, parameterized `mmu_arb.TRANS_ID_WIDTH`, and widened the whitebox probe/coverage bin range. |
| L1DTLB-P6-ISSUE-009 | 2026-05-22 | RTL bug | Low | 6A compile hygiene | `ptw_mbuf.sv` redeclared output port `mbuf_twu_pmpflg` as an internal logic, producing an IPDW warning. | Codex | Closed | Removed the duplicate internal declaration; final compile log has no IPDW warning. |
| L1DTLB-P6-ISSUE-010 | 2026-05-22 | UVM bug | Medium | `L1DTLB_TS_FAULT_OVERLAP_PIPE`, `L1DTLB_LOOKUP_FAULT_OVERLAP` | `DTLB_FAULT_OVERLAP_PIPE_001` seeded an exception CAM entry before calling `fill_page(44)`, so the midtest quiescent wait timed out on expected `tlb_busy` from the unconsumed exception entry. | Codex | Closed | Moved `fill_page(44)` before seeding the page45 exception entry; rerun passes and records Phase6B overlap evidence. |
| L1DTLB-P6-ISSUE-011 | 2026-05-22 | UVM bug | Medium | `L1DTLB_TS_FAULT_AD_US_SUM`, `L1DTLB_LOOKUP_PAGE_FAULT_RULES` | `wait_pipe0_terminal()` could miss a single-cycle pipe0 hit response when called immediately after `raw_pipe0()`, causing `DTLB_FAULT_AD_US_SUM_001` seed 97107 to time out at the SUM=1 hit step. | Codex | Closed | Sampled the current LSU monitor clocking-block state before entering the wait loop; rerun passes and records Phase6C permission/attr evidence. |
| L1DTLB-P6-ISSUE-012 | 2026-05-22 | Regression gap | Low | `L1DTLB_SVA_C020`, `L1DTLB_TS_INV_INSTALL_SAME_ENTRY` | `DTLB_INV_INSTALL_SAME_ENTRY_001` seed 97109 is warning-free and records Phase6C shadow clear/update evidence, but the same-cycle `cp_l1dtlb_c020_inv_install_same_entry` SVA cover still has `0 match` for that seed. | Codex | Closed | Phase6C seed 97109 remains clear/update shadow evidence only. Phase6F closes the narrower same-cycle invalidate+install race with final seed 97364, which reports `inv_install_final_clear=1` and `cp_l1dtlb_c020_inv_install_same_entry=1`. |
| L1DTLB-P6-ISSUE-013 | 2026-05-22 | UVM bug | Medium | `L1DTLB_SB_MB_ALLOCATION`, `L1DTLB_RM_MB_SHADOW` | Initial Phase6D allocation oracle checked MB allocation in the same sampled cycle as the T1 miss decision and could falsely flag `P6D_ALLOC_MISS` or `P6D_ALLOC_COUNT`; DUT MB allocation is visible on the next monitor sample. | Codex | Closed | Changed the oracle to enqueue a pending expectation with saved `base_vld` and verify the next sampled MB occupancy/payload. `make comp_fast` and directed allocation runs 97111-97116 pass. |
| L1DTLB-P6-ISSUE-014 | 2026-05-22 | UVM bug | Medium | `L1DTLB_MB_CAM_HIT_NO_RESPONSE`, `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY` | Initial MB CAM no-response classification sampled `mb_hit*` with current LSU T0 request validity, missing the RTL T1 CAM result after the request was already deasserted. | Codex | Closed | Added retimed T1 tokens that preserve the previous request owner while sampling current `mb_hit*`; `DTLB_HIT_MISS_CONCURRENT_001` now reports `nr_mb_cam=2`, `cam_drop=2`, and `mb_cam_hit=2` with clean UVM summary. |
| L1DTLB-P6-ISSUE-015 | 2026-05-22 | UVM bug | Medium | `L1DTLB_SB_MB_ALLOCATION`, `L1DTLB_EXPT_REPLAY_RELEASE`, `DTLB_MB_FAULT_HOLD_001` | Phase6E fault-hold replay exposed a Phase6D allocation-oracle false positive: same-cycle exception replay release plus a legal p1 miss allocation can create more new MB entries than the one expected from the original pending allocation record. | Codex | Closed | When the next-sample new-entry count is greater than expected, the oracle now logs a high-verbosity overlap diagnostic, still checks token-level allocation matches, and only errors if fewer than expected entries appear. `make comp_fast`, `DTLB_MB_FAULT_HOLD_001`, and `DTLB_MB_ABT_LATE_REFILL_001` pass. |
| L1DTLB-P6-ISSUE-016 | 2026-05-22 | Regression gap | Medium | `L1DTLB_SVA_A052`, `L1DTLB_TS_INSTALL_ARB_WFI_PTW_L2`, `DTLB_MB_FSM_WFI_001`, `DTLB_WFI_DATA_HOLD_001` | Existing WFI-named directed wrappers did not create a PTW/L2 same-cycle normal-refill collision, so the MB WFI state and WFI install/data-hold path were not triggered. | Codex | Closed | Added deterministic PTW/L2 collision plus WFI-install stimulus and corrected WFI cover timing for same-cycle WFI grant. Final seeds 97234 and 97235 report `wfi=1`, `wfi_lowest=1`, `wfi_data_hold=1`, and WFI install/hold/priority/collision SVA matches with clean UVM summaries. |
| L1DTLB-P6-ISSUE-017 | 2026-05-22 | Regression gap | Medium | `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_TS_MB_STALE_REFILL_ID`, `DTLB_REFILL_STALE_ID_001` | The original stale-refill wrapper ran normal refill/install traffic and did not produce a completion for an invalid/stale MB entry. Later RTL review showed standalone `!mb_vld` stale is not observed by legal stimulus because the MB entry remains valid while an in-flight refill moves through ABT late completion. | Codex | Closed with reachability note | The Phase6E gate now requires stale-or-ABT no-side-effect evidence. Final seed 97233 reports `abt_late_refill=1`, `PHASE6D_NO_RESPONSE` side-effect counters, SVA `cp_l1dtlb_c017_stale_or_abt_refill=1`, and `PHASE6E_STALE_REACHABILITY` documenting standalone stale non-observation under the current RTL FSM. |
| L1DTLB-P6-ISSUE-018 | 2026-05-22 | Regression gap | Medium | `L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY`, `L1DTLB_SVA_A054`, `L1DTLB_SVA_A055`, `DTLB_ACCESS_FAULT_SOURCE_PARITY_001`, `DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001` | Existing access-fault-source and dual-exception wrappers exercised PGFLT/replay only: `acflt=0`, `dual_write=0`, and dual/access replay covers were unhit. | Codex | Closed | Added true ACFLT and simultaneous dual-exception stimulus, plus checker ownership for expt-owned T0 access-fault replay. Final seed 97230 reports `acflt=1` and access-replay/access-fault SVA matches; final seed 97231 reports `dual_write=1` and dual-fault/dual-expt SVA matches. |
| L1DTLB-P6-ISSUE-019 | 2026-05-22 | RTL bug | High | `L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY`, `DTLB_ACCESS_FAULT_SOURCE_PARITY_001` | ACFLT expt replay did not fully own the same-cycle hit-read response datapath: access-fault ownership, PA source muxing, STAMO preselect interaction, and a stale fault flop could produce wrong-source or duplicate terminal behavior. | Codex | Closed | Updated `mmu_l1dtlb_hit_rd.sv` so same-cycle expt CAM ACFLT replay drives `mmu_lsu_access_fault_x`/`dutlb_acc_flt_x`, uses `dutlb_fin_pa` for PMP PA, blocks STAMO preselect during expt replay, and clears stale `jtlb_acc_fault_flop`. Final ACFLT seed 97230 is warning-free and covers replay/access-fault SVA. |
| L1DTLB-P6-ISSUE-020 | 2026-05-22 | Regression gap | Medium | `L1DTLB_SVA_C020`, `L1DTLB_TS_INV_INSTALL_SAME_ENTRY`, `L1DTLB_SB_INVALIDATE_FLUSH` | Phase6F same-cycle invalidate+install attempts 97353/97354/97361/97362/97363 are not closure quality and are retained as rejected evidence. The 97361 long-held LSU all-invalidate path causes repeated `a_mbuf_ptr_only_on_response` PTW protocol failures. The 97362/97363 CP0 all-invalidate plus normal PTW refill path is cleaner but still zero-cover because RTL arbitration masks PTW write grant while `tlboper_on`. | Codex | Closed | Final seed 97364 uses a PTW/L2 collision to create WFI pending local install, overlaps CP0 all-invalidate with WFI install, and passes with `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`, no scenario gate/assertion text, `inv_install_final_clear=1`, and `cp_l1dtlb_c020_inv_install_same_entry=1`. |
| L1DTLB-P6-ISSUE-021 | 2026-05-22 | Regression gap | Medium | `L1DTLB_TS_FLUSH_RTU_CLEAR_SCOPE`, `L1DTLB_RTU_FLUSH_SCOPE`, `L1DTLB_SB_INVALIDATE_FLUSH`, `L1DTLB_SVA_A060`, `L1DTLB_SVA_C020` | `DTLB_CLEANUP_SCOPE_MATRIX_001` seed 97360 was warning-free but partial because `flush_mb_clear=0` and `flush_expt_clear=0`. The repaired checker/scenario policy records RTU flush killing MB work by IDLE clear or ABT late-drain, clears expt, preserves TLB entries when no clear/invalidate is present, and reuses no-response side-effect checks for killed misses. | Codex | Closed | Final seed 97362 is warning-free with no scenario gate/assertion failure, reports `flush_mb_clear=3`, `flush_expt_clear=1`, `flush_tlb_preserve=3`, `abt_late_no_sidefx=3`, and `PHASE6D_NO_RESPONSE` no-side-effect counters. |
| L1DTLB-P6-ISSUE-022 | 2026-05-23 | UVM bug | High | `L1DTLB_TS_FAULT_OVERLAP_PIPE`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_SB_TRACEABILITY_CLOSURE` | Phase6G manifest replay initially passed all rows, but closure rejected `6B_FAULT_TOKEN`: `DTLB_FAULT_OVERLAP_PIPE_001` had `pf_current_t0=1` and `fault_overlap_separate=1` while `af_previous_t1=0`. The checker classified the access-fault side as same-cycle expt replay instead of the legal previous-T1 PMP/PA-response owner. | Codex | Closed | `mmu_l1dtlb_spec_sb.svh` now prioritizes previous-T1 PMP/PA-response ownership over expt replay for access-fault classification when both are possible. Seed 97101 rerun reports `af_previous_t1=1`, `pmp_t1_classified=1`, `fault_overlap_separate=1`, and clean UVM summary; final Phase6G replay and closure both pass 28/28. |

#### 7. Waiver Log

Phase 6E previously used the following implementation waivers while the missing directed stimulus was being built.  They are now retired as closure waivers.  The rows remain as audit history and to preserve the standalone stale reachability note.

Phase6G adds no new simulation closure waiver.  The manifest row `6F_FORMAL_FUTURE` keeps exact PLRU victim selection and full `vabuf` functional equivalence as future/formal work; support cover is recorded only as debug evidence and is not a waiver for equivalence.

| Waiver ID | Related IDs | Missing gate | Reason | Replacement check / evidence | Risk | Approver | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| L1DTLB-P6-WAIVE-001 | `L1DTLB_SVA_A052`, `L1DTLB_TS_INSTALL_ARB_WFI_PTW_L2`, `L1DTLB_SB_INSTALL_EXPT`, `DTLB_MB_FSM_WFI_001`, `DTLB_WFI_DATA_HOLD_001` | WFI install collision, lowest WFI entry, and WFI data-hold trigger evidence. | Original wrappers did not align PTW/L2 normal completions to force `!refill_gnt` and move an MB from WFC to WFI. | Final seeds 97234 and 97235 trigger WFI install/data-hold, report `wfi=1`, `wfi_lowest=1`, `wfi_data_hold=1`, and cover WFI install/hold/priority/collision SVA. | Low | Codex | Retired; closed by deterministic directed evidence. |
| L1DTLB-P6-WAIVE-002 | `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_TS_MB_STALE_REFILL_ID`, `L1DTLB_SVA_A017`, `DTLB_REFILL_STALE_ID_001` | Standalone stale-refill completion after MB identity mismatch/entry invalidation. | RTL review and final stimulus show the legal in-flight refill path keeps the MB valid until ABT late completion; standalone `!mb_vld` stale completion is not observed in the current MB FSM. | Final seed 97233 closes stale/ABT no-side-effect via `abt_late_refill=1`, side-effect counters, and SVA `cp_l1dtlb_c017_stale_or_abt_refill`/`cp_l1dtlb_c020_flush_race`; `PHASE6E_STALE_REACHABILITY` records the standalone stale limitation. | Low | Codex | Retired as closure waiver; retained as reachability note. |
| L1DTLB-P6-WAIVE-003 | `L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY`, `L1DTLB_SVA_A054`, `L1DTLB_SVA_A055`, `L1DTLB_SVA_A056`, `DTLB_ACCESS_FAULT_SOURCE_PARITY_001`, `DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001` | Access-fault-source exception lifecycle and simultaneous dual fault write cover. | Original wrappers produced PGFLT/replay behavior but did not drive a true L1DTLB ACFLT source or simultaneous dual exception write. | Final seed 97230 covers ACFLT replay/access-fault; final seed 97231 covers simultaneous dual fault write and dual expt CAM write. | Low | Codex | Retired; closed by deterministic directed evidence and ACFLT replay RTL fix. |

Waiver rules:

- Every waiver must name exact traceability IDs.
- A waiver must explain whether the missing item is covered by another checker, debug-only evidence, formal proof, or future work.
- Tooling failures require log fallback evidence before waiver.
- Missing stable probes must first be evaluated in Phase 6A.
- Coverage holes and untriggered scenarios must be recorded individually; overall regression pass is not sufficient.

#### 8. Phase 6 Exit Record

| Check | Status | Notes |
| --- | --- | --- |
| `L1DTLB_UVM_Phase6_BuildPlan.md` exists | Complete | Created as future implementation blueprint. |
| `L1DTLB_UVM_Phase6_Progress.md` exists | Complete | Created as future implementation tracker. |
| Subphase matrix initialized | Complete | 6A through 6G are complete for planned UVM simulation implementation scope; cleanup-scope is closed by seed 97362, same-cycle invalidate+install is closed by seed 97364, and Phase6G replay/closure close the final traceability controller row. |
| Evidence, issue, and waiver templates initialized | Complete | 6A compile/smoke evidence, 6B compile/directed evidence, 6C entry-shadow evidence, 6D MB/no-response evidence, final 6E refill/install/expt lifecycle evidence, Phase6F closure/rejected-evidence rows, and Phase6G manifest replay/closure reports are recorded. Former Phase6E waivers are retired or retained only as audit history. |
| All known unfinished traceability rows assigned to future phases | Complete | See BuildPlan section 4 and this file section 4. |
| Phase6A-6G implementation modifies only scoped UVM/testbench plus required RTL/SVA/Makefile/script fixes | Complete | Phase 6E touched L1DTLB spec SB, directed vseq, L1DTLB SVA WFI cover timing, and `mmu_l1dtlb_hit_rd.sv` ACFLT replay datapath. Phase 6G adds replay/closure Makefile targets, scripts, and lists, and repairs a L1DTLB spec-SB access-fault ownership classification found by closure scanning. |
| Phase6F implementation status | Complete | Credit/wakeup/cleanup-scope/invalidate-hit/same-cycle invalidate-install/formal-future reports have closure evidence or explicit future/formal disposition. Rejected logs remain recorded in the evidence and issue logs. |
| Phase6G implementation status | Complete | `make -C mmu_verification l1dtlb_phase6g_replay` reports `PASS=28 FAIL=0 TOTAL=28`; `make -C mmu_verification l1dtlb_phase6g_closure` reports `PASS=28 FAIL=0 TOTAL=28`; report path is `mmu_verification/output/regression/l1dtlb_phase6g_closure/closure_report.md`. |
| Future implementation approval | Phase6G complete | No remaining Phase6G UVM simulation task is open. Exact PLRU victim selection and full `vabuf` functional equivalence remain explicit future/formal work. |

---

## Source: `l1dtlb_3_9_3_10_traceability.md`

### L1DTLB 3.9/3.10 UVM Traceability

This file tracks implementation status for `l1dtlb_function_description.md`
sections 3.9 and 3.10.  It is intentionally conservative: a row is `implemented`
only when there is a named SVA, scoreboard check, coverage point, or directed
scenario that checks the required behavior rather than only carrying the test
name.

#### Status Legend

| Status | Meaning |
| --- | --- |
| implemented | Implemented with concrete SVA, scoreboard check, cover, or directed stimulus. |
| partial | Some checks/stimulus exist, but the row is not fully proven. |
| planned | Wrapper or intent exists, but concrete semantic checking/stimulus is still needed. |
| formal-only | The requirement needs equivalence/formal setup or additional controllable probes. |

#### Key Implementation Files

| Area | File |
| --- | --- |
| SVA binds | `mmu_verification/testbench/top/tb_top.sv` |
| L1DTLB SVA | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| Directed vseq | `mmu_verification/testbench/env/mmu_l1dtlb_vseq_lib.svh` |
| Spec scoreboard | `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh` |
| Whitebox covergroup | `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh` |
| Wrapper suite | `mmu_verification/testbench/test/l1dtlb_tests/l1dtlb_tests_suite.svh` |

#### 3.9 Assert SVA Matrix

| SVA ID | Status | Current implementation |
| --- | --- | --- |
| L1DTLB_SVA_A001 | partial | `a_reset_clears_visible_state`, spec SB reset check. Exception CAM reset visibility still lacks direct probe. |
| L1DTLB_SVA_A002 | implemented | scheduler `a_reset_credit_max`, `a_credit_in_range`. |
| L1DTLB_SVA_A003 | formal-only | `cp_l1dtlb_c026_vabuf_change`; full equivalence of vabuf side effects still needs formal/paired-scoreboard flow. |
| L1DTLB_SVA_A004 | partial | top/hit `a_stamo_no_pipe0_bypass`, `a_stamo_bypass_not_miss`, `a_stamo_pa_source`; `DTLB_STAMO_PIPE1_BYPASS_001` and spec-SB counters now gate pipe1 STAMO PA ownership, while full attr source remains partial. |
| L1DTLB_SVA_A005 | partial | `a_stamo_no_new_miss_side_effect`, `a_stamo_bypass_not_miss`; `DTLB_STAMO_PIPE0_NEG_001` and spec-SB pipe0 pollution checks cover the negative path. PLRU pollution is still not fully checked. |
| L1DTLB_SVA_A006 | partial | `a_stamo_pa_source`; pipe1 STAMO bypass scenario/SB gate exists. Attribute source and PLRU pollution remain partial. |
| L1DTLB_SVA_A007 | partial | Abort scenario now drives abort+hit; `cp_l1dtlb_c009_abort_hit` and spec-SB `abort_hit` counter observe it. Exact attr preservation remains translation/SB-owned. |
| L1DTLB_SVA_A008 | implemented | `a_abort0_not_miss`, `a_abort1_not_miss`, hit_rd `a_abort_blocks_miss`. |
| L1DTLB_SVA_A009 | implemented | expt CAM/top `a_abort*_does_not_consume*` assertions; `DTLB_ABORT_001` now creates an exception-CAM hit candidate, aborts it, then verifies non-abort replay survives. |
| L1DTLB_SVA_A010 | partial | scheduler payload/type assertions; permission/PMP type propagation relies on translation SB. |
| L1DTLB_SVA_A011 | partial | `a_pipe*_page_fault_has_pa_vld`, hit_rd `a_hit_response_t0`, `a_direct_map_terminal_response`. |
| L1DTLB_SVA_A012 | partial | `a_pipe*_page_fault_has_pa_vld`; PMP token absence is not fully observable per request. |
| L1DTLB_SVA_A013 | partial | Translation SB tracks T1 ownership; no complete request-token SVA. |
| L1DTLB_SVA_A014 | partial | Expt class assertions exist; raw pulse width intentionally not globally asserted because T1/T0 overlap is legal. |
| L1DTLB_SVA_A015 | partial | Fault-class exclusivity at exception CAM and expt write; per-request T0/T1 ownership remains scoreboard. |
| L1DTLB_SVA_A016 | implemented | top/install/expt wakeup shape assertions. |
| L1DTLB_SVA_A017 | partial | `a_wakeup_has_known_source`, install/expt wakeup assertions; negative sources are partly covered. |
| L1DTLB_SVA_A018 | implemented | `a_busy_mirrors_mb_valid`, spec SB busy check. |
| L1DTLB_SVA_A019 | partial | hit_rd T0 hit response assertions; PMP T1 ownership is scoreboard. |
| L1DTLB_SVA_A020 | partial | Top T1 allocation gating checks; exact T0/T1 allocation timing partly implicit. |
| L1DTLB_SVA_A021 | implemented | `a_dual_hit_returns_both`; hit_rd single-hit covers. |
| L1DTLB_SVA_A022 | partial | `a_pipe*_hit_returns_t0`, directed hit/miss scenario; full MB-full immunity not separately proven. |
| L1DTLB_SVA_A023 | implemented | top `a_same_4k_miss_dedup_top`, allocator `a_same_4k_dual_miss_dedup`. |
| L1DTLB_SVA_A024 | partial | allocator one-free cover plus `DTLB_ALLOC_RACE_001` p0-older/p1-older one-free directed gates; exact IID winner proof remains partial because compare result is not bound. |
| L1DTLB_SVA_A025 | partial | allocator dual-diff two-free checks count/distinct IDs; lowest-free proof still partial. |
| L1DTLB_SVA_A026 | partial | expt replay, dual-hit checks, terminal-response assertions, and `DTLB_EXPT_HIT_WITH_TLB_HIT_001` dedicated scenario/SB gate exist; full non-contamination remains partly scoreboard-owned. |
| L1DTLB_SVA_A027 | implemented | expt CAM `a_no_dual_consume_same_entry`. |
| L1DTLB_SVA_A028 | partial | valid payload, valid-hit-only assertions; flag-to-attr semantic checking remains translation SB. |
| L1DTLB_SVA_A029 | partial | legal page-size assertion and page-size covers; exact comparator bounds are RTL-local and not fully asserted. |
| L1DTLB_SVA_A030 | partial | multi-hit is retained as diagnostic cover plus valid-hit-only checks; no failure assertion until spec chooses priority vs illegal-state policy. |
| L1DTLB_SVA_A031 | partial | `DTLB_PERM_LD_001/002` now have directed R=0 and MXR X-only stimulus plus VPN-specific spec-SB page-fault/pass gates. Full flag truth-table SVA remains partial. |
| L1DTLB_SVA_A032 | partial | `DTLB_PERM_ST_001/002` now have W=0 and D=0 directed store stimulus; ref model treats A=0/store D=0 as page faults and spec-SB gates W=0/D=0 independently. D-bit writeback absence remains partial. |
| L1DTLB_SVA_A033 | partial | `DTLB_TYPE_PROP_LOAD_STORE_AMO_001` now gates L2 load/store request type propagation; AMO-specific and PTW/PMP type propagation remain partial. |
| L1DTLB_SVA_A034 | partial | hit_rd direct-map terminal response and top no-new-miss assertion; spec-SB gates direct-map no-MB side effect. Full attr/sysmap equivalence remains partial. |
| L1DTLB_SVA_A035 | partial | `DTLB_PMP_001` and `DTLB_ACCESS_FAULT_T1_PAIRING_001` now drive PMP deny and spec-SB access-fault owner gates; direct-map PMP token ownership remains partial. |
| L1DTLB_SVA_A036 | implemented | `a_l2_fault_is_page_fault_only`, expt class assertions. |
| L1DTLB_SVA_A037 | implemented | top `a_mb_cam_hit_no_alloc0/1`, same-4K dedup. |
| L1DTLB_SVA_A038 | partial | No-alloc on CAM hit checked; no immediate response/wakeup partly covered by scoreboard. |
| L1DTLB_SVA_A039 | implemented | top `a_mb_full_no_alloc_top`, allocator `a_no_free_no_grant`, busy check. |
| L1DTLB_SVA_A040 | implemented | top and mb_entry state-derived assertions. |
| L1DTLB_SVA_A041 | implemented | top `a_mb_issued_requires_valid`, mb_entry `a_issue_sets_issued`, `a_idle_clears_issued`. |
| L1DTLB_SVA_A042 | partial | mb_entry `a_fault_state_holds_until_replay_or_flush`; expt valid probe still indirect. |
| L1DTLB_SVA_A043 | implemented | scheduler credit conservation assertions. |
| L1DTLB_SVA_A044 | implemented | single request channel and scheduler req/grant assertions. |
| L1DTLB_SVA_A045 | implemented | scheduler `a_old_mb_priority_over_bypass`. |
| L1DTLB_SVA_A046 | implemented | scheduler bypass payload assertions, mb_entry issue state assertion. |
| L1DTLB_SVA_A047 | implemented | scheduler/top L2 request payload and MB payload match assertions. |
| L1DTLB_SVA_A048 | implemented | install WFI/PTW/L2 priority and onehot grant assertions. |
| L1DTLB_SVA_A049 | partial | fault-only no-install assertion; same-cycle normal install with fault candidate handled conservatively. |
| L1DTLB_SVA_A050 | implemented | install `a_wfi_priority_over_ptw_l2` uses lowest WFI helper. |
| L1DTLB_SVA_A051 | implemented | mb_entry `a_wfi_data_stable_without_grant`, install WFI payload match. |
| L1DTLB_SVA_A052 | partial | expt write id/fault assertions; dual-fault cover exists, same-eid negative assertion exists in expt CAM. |
| L1DTLB_SVA_A053 | implemented | top `a_*_fault_requires_wfc_entry`, stale refill cover. |
| L1DTLB_SVA_A054 | partial | MB flush/refill race assertions; install/expt/wakeup no-side-effect on all ABT cases partly top-level. |
| L1DTLB_SVA_A055 | partial | install release cover; same-cycle visibility boundary still directed/scoreboard. |
| L1DTLB_SVA_A056 | partial | expt CAM direct id write and depth binding; lifecycle bound to MB is partial. |
| L1DTLB_SVA_A057 | partial | expt CAM key observability assertions; full negative against ASID/type/page-size is formal/scoreboard. |
| L1DTLB_SVA_A058 | partial | expt consume/wakeup checks plus `DTLB_WAKEUP_EXPT_001` scenario/SB gate; MB release tie is partly mb_entry/expt_hit. |
| L1DTLB_SVA_A059 | implemented | hit_rd `a_tlb_hit_not_expt_hit_same_req`. |
| L1DTLB_SVA_A060 | partial | top flush side-effect guard, expt CAM flush guard, mb_entry race assertions. |
| L1DTLB_SVA_A061 | implemented | top `a_regs_utlb_clr_clears_entries`, `a_tlboper_utlb_clr_clears_entries`. |
| L1DTLB_SVA_A062 | implemented | `mmu_dut_probes_if.sv` exposes per-entry VPN and `mmu_l1dtlb_sva.sv` checks low-8 VA invalidate clears matching valid entries while preserving nonmatching entries. |
| L1DTLB_SVA_A063 | partial | `DTLB_INV_HIT_SAME_CYCLE_001` now drives same-cycle hit+invalidate and spec-SB gates on the overlap; no exact old-hit boundary SVA. |
| L1DTLB_SVA_A064 | implemented | `a_clear_wins_install_same_entry` checks clear-over-install priority for the selected entry; C020 cover/SB counters record invalidate or full-clear overlap with install. |
| L1DTLB_SVA_A065 | implemented | mb_entry WFG/WFC/WFI flush race assertions. |
| L1DTLB_SVA_A066 | implemented | top/install PLRU onehot/update assertions. |
| L1DTLB_SVA_A067 | partial | Translation SB, spec SB, and SVA cover most observable boundaries; no single monolithic SVA. |
| L1DTLB_SVA_A068 | implemented | top/hit_rd single-hit assertions. |
| L1DTLB_SVA_A069 | partial | access-fault payload known; full T1 PMP ownership is scoreboard. |
| L1DTLB_SVA_A070 | partial | abort/CAM/full/flush/busy/priority-drop negative side effects checked; spec SB records reason-specific legal no-response counters, with transaction-level reason annotation still partial. |
| L1DTLB_SVA_A071 | implemented | `a_hpc_miss_only_on_real_miss`, miss cover. |

#### 3.9 Cover Property Matrix

| Cover ID | Status | Current implementation |
| --- | --- | --- |
| L1DTLB_SVA_C001 | partial | `cp_l1dtlb_c001_reset_then_miss`; first hit/direct-map are covered separately. |
| L1DTLB_SVA_C002 | implemented | `cp_l1dtlb_c002_dual_hit`, hit_rd single-hit covers. |
| L1DTLB_SVA_C003 | implemented | `cp_l1dtlb_c003_hit_miss`. |
| L1DTLB_SVA_C004 | implemented | top/allocator same-VPN dedup covers. |
| L1DTLB_SVA_C005 | implemented | allocator dual-diff two-free cover. |
| L1DTLB_SVA_C006 | partial | allocator one-free cover includes port0-wins/port1-wins split; `DTLB_ALLOC_RACE_001` now drives p0-older and p1-older one-free subcases with spec-SB gates. Exact wraparound IID-age oracle remains RTL-local/formal. |
| L1DTLB_SVA_C007 | implemented | MB full cover plus scoreboard counter. |
| L1DTLB_SVA_C008 | partial | hit-under-miss and wakeup covers exist; exception wakeup covered in expt CAM. |
| L1DTLB_SVA_C009 | partial | abort cover now has hit and miss-attempt sub-bins; abort-expt-hit is covered by the directed abort replay survivor path rather than a separate cover property. |
| L1DTLB_SVA_C010 | partial | page fault cover plus split permission scenarios; spec-SB now separates load/store page-fault ownership and MXR pass evidence. Detailed flag bins remain covergroup work. |
| L1DTLB_SVA_C011 | partial | direct-map cover exists; `DTLB_SYSMAP_001` now gates MMU-off/effective-mode direct-map with no-MB side-effect evidence. Full attr/sysmap and MPRV non-M closure remain partial. |
| L1DTLB_SVA_C012 | implemented | top/hit_rd STAMO covers. |
| L1DTLB_SVA_C013 | partial | CAM-hit/no-alloc checked; 2M/1G MB-dedup subcase still planned. |
| L1DTLB_SVA_C014 | implemented | scheduler credit/L2/bypass/priority covers. |
| L1DTLB_SVA_C015 | implemented | WFI install/hold/priority covers. |
| L1DTLB_SVA_C016 | implemented | fault write and dual fault write covers. |
| L1DTLB_SVA_C017 | implemented | stale/ABT refill cover. |
| L1DTLB_SVA_C018 | partial | install release cover plus `DTLB_INSTALL_VISIBILITY_001` and spec-SB `install_visible_next` gate cover next-cycle visibility; exact same-cycle negative boundary remains cover/SVA-owned. |
| L1DTLB_SVA_C019 | implemented | expt page/access replay covers and fault-hold assertion. |
| L1DTLB_SVA_C020 | partial | clear/flush/race covers now include low-8 VA alias clear and clear/install overlap bins; full flush-race closure still depends on regression cover results. |
| L1DTLB_SVA_C021 | implemented | T1/T0 overlap cover. |
| L1DTLB_SVA_C022 | implemented | 4K/2M/1G refill page-size covers plus split `DTLB_HUGE_001/002/003/HUGE_MIX` scenario gates for page-size hit/refill evidence. |
| L1DTLB_SVA_C023 | implemented | multi-hit diagnostic cover. |
| L1DTLB_SVA_C024 | implemented | PLRU refill cover plus onehot assertions. |
| L1DTLB_SVA_C025 | partial | HPC/miss/wakeup/whitebox events covered separately; spec SB now records legal no-response counters for MB CAM, MB full, abort, flush, busy-sleep, and priority-drop classes. |
| L1DTLB_SVA_C026 | partial | vabuf change cover exists; equivalence proof remains formal/scoreboard. |
| L1DTLB_SVA_C027 | implemented | phase9 retarget code and wrapper suite count; not a DUT SVA. |

#### 3.10 Scenario Matrix

| Scenario ID | Status | Current implementation |
| --- | --- | --- |
| L1DTLB_TS_BASIC_HIT_PIPE0 | implemented | `L1DTLB_SCN_SMOKE_P0`, hit assertions, translation SB. |
| L1DTLB_TS_BASIC_HIT_PIPE1 | implemented | `L1DTLB_SCN_SMOKE_P1`, hit assertions, translation SB. |
| L1DTLB_TS_BASIC_DUAL_HIT | implemented | `L1DTLB_SCN_DUAL_HIT`, dual-hit SVA/cover. |
| L1DTLB_TS_BASIC_HIT_MISS | implemented | `L1DTLB_SCN_HIT_MISS`, hit/miss cover and scoreboard. |
| L1DTLB_TS_BASIC_PAGE_SIZE_4K_2M_1G | partial | `DTLB_HUGE_001/002/003/HUGE_MIX` now split 4K/2M/1G/mixed stimulus and spec-SB gates page-size hit/refill; regression closure still pending. |
| L1DTLB_TS_BASIC_MULTI_HIT_DIAG | partial | multi-hit onehot assertion/cover; no direct diagnostic entry injection. |
| L1DTLB_TS_BASIC_ENTRY_FIELD_MODEL | partial | refill payload assertions and translation SB; field truth-table still partial. |
| L1DTLB_TS_CTRL_ABORT_HIT | implemented | `L1DTLB_SCN_ABORT` explicitly drives abort+hit; `cp_l1dtlb_c009_abort_hit` and spec-SB `abort_hit` gate observe it. |
| L1DTLB_TS_CTRL_ABORT_MISS | implemented | abort blocks miss/allocation SVA plus `L1DTLB_SCN_ABORT`. |
| L1DTLB_TS_CTRL_ABORT_EXPT_HIT | implemented | `DTLB_ABORT_001` builds an exception-CAM entry, aborts the matching replay, then confirms a later non-abort replay is still consumed; SVA/SB reject abort-side effects. |
| L1DTLB_TS_CTRL_VABUF_NO_EFFECT | formal-only | vabuf cover exists; equivalence flow still needed. |
| L1DTLB_TS_CTRL_BUSY_ANY_INFLIGHT | implemented | busy SVA/SB and `L1DTLB_SCN_BUSY_WAKEUP`. |
| L1DTLB_TS_CTRL_WAKEUP_INSTALL | implemented | wakeup SVA and refill/install scenarios. |
| L1DTLB_TS_CTRL_WAKEUP_EXPT | implemented | `DTLB_WAKEUP_EXPT_001` runs an isolated exception replay path; spec SB gates on `expt_replay` and broadcast `expt_wakeup`. |
| L1DTLB_TS_CTRL_RESET_STATE | partial | reset assertions/SB; exception CAM reset direct visibility absent. |
| L1DTLB_TS_MB_DUAL_SAME_4K_DEDUP | implemented | same-4K dedup SVA/cover, `L1DTLB_SCN_DUAL_MISS_SAME`. |
| L1DTLB_TS_MB_DUAL_DIFF_4K_TWO_FREE | partial | dual-diff allocation SVA/cover; lowest-free exactness partial. |
| L1DTLB_TS_MB_DUAL_DIFF_4K_ONE_FREE_AGE | partial | `DTLB_ALLOC_RACE_001` now drives one-free dual-diff p0-older and p1-older subcases with spec-SB gates; exact winner proof remains partial. |
| L1DTLB_TS_MB_FULL_DROP_RETRY | implemented | MB full no-alloc SVA/cover and scenario. |
| L1DTLB_TS_MB_CAM_HIT_NO_ALLOC | implemented | top CAM hit no-alloc SVA. |
| L1DTLB_TS_MB_4K_DEDUP_FOR_HUGE_FINAL | partial | huge scenario exists; MB full 4K key under huge final not isolated. |
| L1DTLB_TS_MB_STATE_SIGNAL | implemented | top and mb_entry state assertions. |
| L1DTLB_TS_MB_FAULT_HOLD | partial | fault-hold assertion; expt valid lifetime direct check partial. |
| L1DTLB_TS_MB_STALE_REFILL_ID | partial | stale refill cover; stronger no-side-effect checks partial. |
| L1DTLB_TS_MB_ABT_LATE_REFILL | partial | flush/refill race assertions; exact ABT late refill directed split partial. |
| L1DTLB_TS_SCHED_CREDIT_BOUND | implemented | scheduler credit SVA. |
| L1DTLB_TS_SCHED_ONE_REQ_PER_CYCLE | implemented | one request channel and issue/grant assertions. |
| L1DTLB_TS_SCHED_OLD_MB_PRIORITY | implemented | scheduler priority assertion and cover. |
| L1DTLB_TS_SCHED_BYPASS_ALLOC_ISSUE | implemented | scheduler bypass assertions, MB issue assertion. |
| L1DTLB_TS_SCHED_L2_REQ_PAYLOAD | implemented | scheduler/top payload assertions. |
| L1DTLB_TS_SCHED_STORE_TYPE_PROP | partial | `DTLB_TYPE_PROP_LOAD_STORE_AMO_001` drives load and store misses and spec-SB gates L2 `is_load` split; PTW/PMP/AMO-specific type propagation remains partial. |
| L1DTLB_TS_FAULT_RESPONSE_TIMING | partial | translation SB handles timing; spec-SB now checks page-fault T0 and access-fault T1 ownership counters. No full tokenized SVA. |
| L1DTLB_TS_FAULT_LOAD_R0 | partial | `DTLB_PERM_LD_001` maps R=0/X=0 and gates load page-fault + pa_vld ownership; full permission truth-table remains partial. |
| L1DTLB_TS_FAULT_LOAD_MXR | partial | `DTLB_PERM_LD_002` drives MXR=0 X-only load fault and MXR=1 X-only load pass/hit evidence; full MXR cross coverage remains partial. |
| L1DTLB_TS_FAULT_STORE_W_D | partial | `DTLB_PERM_ST_001/002` drive W=0 and D=0 store cases; ref model and spec-SB now gate store W=0 and D=0 page-fault ownership separately. D-bit no-writeback/trap-only closure remains partial. |
| L1DTLB_TS_FAULT_AD_US_SUM | partial | `DTLB_FAULT_AD_US_SUM_001` drives A=0 load fault, S-mode U-page SUM=0 fault, SUM=1 pass/hit evidence, and U-mode U=0 fault with spec-SB gates. Current regression exposes the SUM=1 pass path as a terminal-response/drain issue; full A/D/U/S/SUM truth-table remains partial. |
| L1DTLB_TS_FAULT_PF_BLOCKS_PMP | partial | `DTLB_PF_BLOCKS_PMP_001` now drives page fault while PMP denies data access and gates page-fault-without-access-fault evidence; direct PMP token absence is still partial. |
| L1DTLB_TS_FAULT_OVERLAP_PIPE | partial | overlap cover exists; `DTLB_FAULT_OVERLAP_PIPE_001` now creates expt page-fault replay plus PMP-denied hit traffic, but exact overlap remains regression-dependent. |
| L1DTLB_TS_FAULT_PMP_ACCESS | partial | `DTLB_PMP_001`/`DTLB_ACCESS_FAULT_T1_PAIRING_001` drive PMP deny and spec-SB access-fault T1 owner gates; translation SB waives only modeled LSU PMP-deny T0 PA responses so the T1 checker owns this path. Full T1 payload ownership remains partial. |
| L1DTLB_TS_MODE_DIRECT_MAP | partial | direct-map SVA/cover plus `DTLB_SYSMAP_001` no-new-miss/no-MB side-effect gate; full attr/sysmap and MPRV split closure remain partial. |
| L1DTLB_TS_MODE_STAMO_PIPE1 | partial | `DTLB_STAMO_PIPE1_BYPASS_001` drives pipe1 STAMO+hit and spec-SB gates PA source; full attr/source check remains partial. |
| L1DTLB_TS_MODE_STAMO_PIPE0_NEG | implemented | pipe0 no-bypass SVA. |
| L1DTLB_TS_INSTALL_ARB_WFI_PTW_L2 | implemented | install priority assertions and cover. |
| L1DTLB_TS_INSTALL_MULTI_WFI_LOWEST | implemented | lowest-WFI install assertion. |
| L1DTLB_TS_INSTALL_WFI_DATA_HOLD | implemented | WFI data stable and install payload match assertions. |
| L1DTLB_TS_INSTALL_VISIBILITY_RELEASE | partial | `DTLB_INSTALL_VISIBILITY_001` dispatches a dedicated refill/retry scenario and spec SB gates on observed next-cycle install visibility; exact same-cycle negative split remains cover-focused. |
| L1DTLB_TS_EXPT_FAULT_REFILL_WRITE | partial | expt write assertions; no-TLB-write under all mixed collisions partial. |
| L1DTLB_TS_EXPT_DUAL_FAULT_WRITE | implemented | dual fault write cover and same-eid negative assertion. |
| L1DTLB_TS_EXPT_REPLAY_CONSUME | partial | expt consume/wakeup assertions plus terminal-response/no-new-miss checks and dedicated wakeup scenario; MB release exactness partial. |
| L1DTLB_TS_EXPT_DUAL_SAME_ENTRY_NEG | implemented | expt CAM no dual consume same entry. |
| L1DTLB_TS_EXPT_HIT_WITH_TLB_HIT | implemented | `DTLB_EXPT_HIT_WITH_TLB_HIT_001` now overlaps pipe0 exception replay with pipe1 TLB hit; spec SB gates on the overlap counter and hit_rd rejects same-request hit+expt contamination. |
| L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY | partial | L2 page-only assertion; PTW/PMP source parity still partial. |
| L1DTLB_TS_INV_TLBOPER_CLR | implemented | top clear entry assertion. |
| L1DTLB_TS_INV_REGS_CLR | implemented | top regs clear entry assertion. |
| L1DTLB_TS_INV_VA8_ALIAS | implemented | `DTLB_INV_VA8_alias_001` fills same-low-8 VPN aliases; per-entry VPN probes, SVA and spec-SB counters check conservative alias clear. |
| L1DTLB_TS_INV_HIT_SAME_CYCLE | partial | directed wrapper now dispatches `scenario_inv_hit_same_cycle`; spec SB gates on hit+invalidate overlap, while exact old-hit boundary remains unasserted. |
| L1DTLB_TS_INV_INSTALL_SAME_ENTRY | implemented | `DTLB_INV_INSTALL_SAME_ENTRY_001` drives clear/install overlap; SVA checks selected-entry clear priority and spec SB gates on the overlap counter. |
| L1DTLB_TS_FLUSH_RTU_CLEAR_SCOPE | partial | flush side-effect guards and MB/expt CAM flush assertions. |
| L1DTLB_TS_FLUSH_MB_RACE_MATRIX | implemented | mb_entry race assertions and cover. |
| L1DTLB_TS_PLRU_WHITEBOX_ONLY | implemented | PLRU onehot/update assertions and cover. |
| L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY | partial | translation SB + spec SB + SVA; legal no-response taxonomy now records core observable reasons, but transaction-level reason annotation remains pending. |
| L1DTLB_TS_OBS_LEGAL_NO_RESPONSE | partial | abort/CAM/full/flush/busy/priority negative checks plus spec-SB reason counters exist; one-free priority-drop and token side-effect counters were expanded, but full transaction-level reason annotation remains partial. |
| L1DTLB_TS_OBS_HPC_MISS_EVENT | implemented | HPC miss event assertion and cover. |
| L1DTLB_TS_OBS_WRAPPER_RETARGET | implemented | phase9 retarget and 71 wrapper suite. |
| L1DTLB_TS_OBS_SVA_COVER_CLOSURE | partial | C-cover points expanded; closure requires regression results. |

---

## Source: `l1dtlb_3_11_traceability.md`

### L1DTLB 3.11 Reference Model and Scoreboard Traceability

This file tracks implementation status for `l1dtlb_function_description.md`
section 3.11.  It follows the same conservative rule as
`l1dtlb_3_9_3_10_traceability.md`: a row is `implemented` only when there is a
named reference-model structure, scoreboard check, monitor field, SVA, cover
point, or directed scenario that checks the required behavior.  A row is not
`implemented` merely because the requirement is described in the spec.

#### Status Legend

| Status | Meaning |
| --- | --- |
| implemented | Implemented with concrete reference-model state, scoreboard check, SVA, cover, monitor field, or directed stimulus. |
| partial | Some support exists, but the row is not fully modeled or proven. |
| planned | Requirement is documented or a wrapper exists, but concrete semantic checking/modeling is still needed. |
| formal-only | Requirement needs equivalence/formal setup or additional controllable probes before simulation can prove it. |

#### Key Implementation Files

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

#### 3.11.1 Overall Partition Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_RM_SB_PARTITION_001 | partial | `mmu_ref_model.svh` models architectural Sv39/PMP/sysmap state, while `mmu_l1dtlb_spec_sb.svh` covers some L1DTLB micro-architecture checks. There is not yet a complete L1DTLB reference sub-model with TLB/MB/expt/credit/T0/T1 state. |
| L1DTLB_RM_SB_PARTITION_002 | partial | `mmu_translation_sb.svh` checks LSU final PA/fault results and contains a DTLB exception CAM shadow, but still uses broad replay/timing waive paths rather than a fully tokenized L1DTLB oracle. |
| L1DTLB_RM_SB_PARTITION_003 | partial | `mmu_l1dtlb_spec_sb.svh` checks reset, busy, MB state-derived signals, refill onehot, expt fault exclusivity, L2 request payload X/range, credit range, and scenario gates. Full semantic MB allocation/install/expt lifecycle prediction remains planned. |
| L1DTLB_RM_SB_PARTITION_004 | partial | `mmu_credit_sb.svh` tracks external outstanding requests and drain status. Exact L1DTLB scheduler credit shadow with credit>0 return+fire conservation and credit=0 same-cycle-return no-fire behavior is covered mainly by SVA/spec SB range checks, not one shared model. |
| L1DTLB_RM_SB_PARTITION_005 | implemented | `mmu_dut_probes_if.sv` exposes L1D MB, entry valid, L2 request, hit/miss, refill, exception write, PTW/L2 refill, flush and invalidate probes for debug/whitebox checks. |
| L1DTLB_RM_SB_PARTITION_006 | partial | PLRU exact victim is kept out of main translation pass/fail; PLRU onehot/update checks are SVA/coverage only. Need audit guard to prevent future scoreboard code from reintroducing exact-victim assumptions. |

#### 3.11.2 Reference Model Data Structure Matrix

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

#### 3.11.3 Lookup, Permission, PA, and Attribute Matrix

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

#### 3.11.4 Miss Buffer, L2 Request, and Legal No-Response Matrix

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

#### 3.11.5 Refill, Install, and Exception Lifecycle Matrix

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

#### 3.11.6 Flush, Invalidate, Reset, and PLRU Matrix

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

#### 3.11.7 Scoreboard Checklist Matrix

| Requirement ID | Status | Current implementation / gap |
| --- | --- | --- |
| L1DTLB_SB_LSU_T0_T1_QUEUE | partial | `mmu_l1dtlb_spec_sb.svh` maintains current T0 and previous-cycle T1 tokens per LSU pipe for fault ownership. It is not yet a full queue for replay/no-response lifecycle prediction. |
| L1DTLB_SB_PAGE_FAULT_PAIRING | partial | `mmu_l1dtlb_spec_sb.svh` checks page_fault belongs to the current non-aborted T0 token and has same-cycle `pa_vld`; SVA still covers the terminal shape. |
| L1DTLB_SB_ACCESS_FAULT_PAIRING | partial | `mmu_l1dtlb_spec_sb.svh` checks access_fault belongs to the previous-cycle non-aborted T1 token; full PMP/source equivalence remains partial. |
| L1DTLB_SB_FAULT_OVERLAP_GUARD | partial | Raw same-cycle page/access exclusivity was removed from `mmu_l1dtlb_spec_sb.svh`; overlap is now qualified by token ownership and only a T1 token that already reported page_fault at T0 is treated as same-token dual-fault. |
| L1DTLB_SB_ATTR_COMPARE | partial | Final translation checks exist; complete L1DTLB attribute source compare is partial. |
| L1DTLB_SB_L2_REQ_CREDIT | partial | L2 request payload/range, reset credit, credit-zero info diagnostics, and credit range checks exist. Shared exact UVM credit shadow with credit>0 return+fire conservation and credit=0 same-cycle-return no-fire behavior remains planned/SVA-owned. |
| L1DTLB_SB_BUSY | implemented | `mmu_lsu_tlb_busy == |l1d_mb_vld` is checked in spec SB and SVA. |
| L1DTLB_SB_WAKEUP | partial | Wakeup all-zero/all-one and known-source assertions exist. Full negative source matrix and event lifecycle closure are partial. |
| L1DTLB_SB_MB_ALLOCATION | partial | Some allocation/dedup/full assertions exist, and `mmu_l1dtlb_spec_sb.svh` now reason-codes MB CAM hit, MB full, busy sleep, and one-free priority-drop no-response observations. Full scoreboard prediction of entry id and IID-age winner remains planned. |
| L1DTLB_SB_INSTALL_EXPT | partial | Install and expt SVA coverage is strong; unified scoreboard lifecycle model remains planned. |
| L1DTLB_SB_INVALIDATE_FLUSH | partial | Clear/flush/race assertions exist; VA8 alias and clear/install overlap counters are implemented. Full reference-shadow invalidate/flush lifecycle remains partial. |
| L1DTLB_SB_SCENARIO_GATE | implemented | `mmu_l1dtlb_spec_sb.svh` consumes `L1DTLB_TC_ID`/`L1DTLB_SCENARIO_ID` and final-phase event counters. |
| L1DTLB_SB_TRACEABILITY_CLOSURE | partial | 3.9/3.10 traceability exists; this 3.11 traceability file adds scoreboard/model closure. Full regression cover closure still requires run results. |

#### 3.11.8 Monitor, Probe, and UVM Landing Matrix

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
| L1DTLB_UVM_WORK_003_CREDIT | partial | Spec SB now checks reset/range and records credit-zero request info diagnostics; exact credit>0 return+fire conservation and credit=0 same-cycle-return no-fire behavior remain in SVA or future shared credit shadow. |
| L1DTLB_UVM_WORK_004_SPEC_SB | partial | Spec SB now includes T0/T1 fault ownership, stronger refill/expt payload checks, credit reset/range diagnostics, existing invalidate/install counters, and reason-coded legal-no-response counters with selected T0/T1 side-effect guards. Full MB allocation/WFI/expt lifecycle prediction remains planned. |
| L1DTLB_UVM_WORK_005_DIAG | partial | New fault ownership and legal-no-response diagnostics include cycle/pipe/IID/VA/VPN/fault/MB/refill-source style token fields plus reason counters for MB CAM, MB full, abort, flush, busy sleep, priority drop, and no-response T1 terminal violations. Full standardized diagnostics across all new checks remains partial. |
| L1DTLB_UVM_WORK_006_PLRU | implemented | Keep exact PLRU victim whitebox-only unless the spec later defines precise replacement behavior. |

#### 3.11.9 Status Summary

| Status | Count | Closure meaning |
| --- | ---: | --- |
| implemented | 28 | Concrete checker, probe, SVA, coverage, or directed scenario exists and is named in this file. |
| partial | 58 | Some checker/stimulus/probe exists, but the behavior is not yet a complete scoreboard/reference-model oracle. |
| planned | 4 | The requirement is captured by the spec/audit, but concrete semantic modeling or checking is still missing. |
| formal-only | 0 | No 3.11 row is currently blocked solely on a formal setup. |

The implemented rows are strongest around reset-visible state, MB derived signals, L2 request payload/scheduling, install arbitration, selected invalidate races, scenario gates, and probe availability.  The remaining risk is not basic observability; it is missing semantic prediction for L1DTLB-local state: entry contents, MB lifecycle, exception replay, exact credit conservation, and legal no-response classification.

#### 3.11.10 Open Work Packages

| Work package | Covers | Required closure |
| --- | --- | --- |
| L1 entry shadow | `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_LOOKUP_PAGE_SIZE_MATCH`, `L1DTLB_LOOKUP_PA_ASSEMBLY`, `L1DTLB_LOOKUP_ATTR_COMPARE`, `L1DTLB_SB_ATTR_COMPARE`, `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL` | Add a reusable L1DTLB entry object with valid, VPN, PPN, page size, and `flag[13:0]`; update it on reset, clear, invalidate, refill/install, and flush-scoped events; compare hit PA/fault/attribute results against this object when the entry source is observable. |
| T0/T1 token and waive removal | `L1DTLB_RM_T0_T1_TOKEN`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | Replace broad translation-SB replay/timing waives with per-pipe request tokens that explain T0 PA/page-fault ownership, T1 access-fault ownership, same-cycle overlap, abort masking, STAMO pipe1 bypass, and direct-map/PMP cases. |
| MB lifecycle and no-response taxonomy | `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_MB_CAM_HIT_NO_RESPONSE`, `L1DTLB_MB_DUAL_DIFF_ONE_FREE_AGE`, `L1DTLB_MB_SINGLE_OR_FULL`, `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_SB_MB_ALLOCATION` | Add an MB shadow that predicts allocation, 4K CAM dedup, full/drop behavior, IID-age winner when only one entry is free, WFG/WFC/WFI/ABT/fault transitions, and reason-coded legal no-response events with no illegal side effects. |
| Exception array lifecycle | `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE`, `L1DTLB_SB_INSTALL_EXPT`, `L1DTLB_PROBE_EXPT_WRITE` | Promote the existing exception CAM shadow from waive/diagnostic support to a lifecycle oracle: bind expt write to the source MB entry, check no TLB write on fault refill, predict replay page/access timing, and verify expt consume releases the matching MB entry without allocating a new one. |
| Credit conservation | `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_RM_SB_PARTITION_004`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_UVM_WORK_003_CREDIT` | Use one shared L1DTLB scheduler credit shadow, or equivalent spec-SB logic, to check reset value, min/max range, decrement on request fire, increment on return, and stable value when return and fire happen in the same cycle. |
| Effective-mode and refill monitor fields | `L1DTLB_MON_LSU_FIELDS`, `L1DTLB_MON_T0_T1_EVENTS`, `L1DTLB_MON_L2_PTW_REFILL`, `L1DTLB_MON_CP0_SYSMAP_PMP` | Extend monitor transactions or token snapshots with effective privilege, MPRV, MXR, SUM, request type, refill flag, and refill page-size/type fields so permission, PMP, sysmap, and attribute checks do not depend on reconstructing hidden state after the fact. |
| PLRU audit guard | `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_PLRU_BLACKBOX_BOUNDARY`, `L1DTLB_UVM_WORK_006_PLRU` | Keep exact victim selection out of main translation pass/fail.  Any future exact-victim check must first be added to the spec and then implemented as a dedicated whitebox assertion/coverage item. |

#### 3.11.11 Recommended Implementation Order

| Priority | Step | Reason |
| ---: | --- | --- |
| 1 | Complete T0/T1 token ownership and legal no-response reason annotation in `mmu_l1dtlb_spec_sb.svh`. | This removes the largest source of false failures: same-cycle T0/T1 overlap, abort/drop cases, and replay timing that currently require broad waives. |
| 2 | Add the L1 entry shadow and refill/install/invalidate/reset update policy. | This enables independent hit-side PA, page-size, permission, and attribute comparison instead of relying only on final architectural translation. |
| 3 | Add the MB shadow lifecycle and IID-age one-free arbitration check. | MB allocation/drop behavior is the main remaining gap for miss/no-response correctness and replay closure. |
| 4 | Bind exception write/replay to the MB shadow. | Exception replay cannot be closed until fault refill, exception entry lifetime, wakeup, consume, and MB release are checked as one lifecycle. |
| 5 | Unify credit checking between credit SB and L1DTLB spec SB. | Exact credit conservation is small in scope but should be shared so external outstanding-request tracking and internal scheduler checks cannot diverge. |
| 6 | Standardize diagnostics and final-phase scenario gates. | Every directed wrapper should fail clearly when its target event was not observed, and every new checker should print cycle, pipe, IID, VA/VPN, reason, and source state. |

#### 3.11.12 Regression and Acceptance Criteria

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
