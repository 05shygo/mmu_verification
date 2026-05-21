# L1DTLB UVM Phase 6 Progress

> Project: OpenRiscv2030 MMU UVM Verification
> Scope: L1DTLB UVM follow-up implementation progress and gate tracking
> Build plan: `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_BuildPlan.md`
> Golden source: `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md`
> Date: 2026-05-22

## 1. Documentation-Phase Status

Phase 6 creates the follow-up implementation blueprint and progress tracker only.  It does not mark any UVM implementation row complete by itself.

| Item | Path | Status | Notes |
| --- | --- | --- | --- |
| Phase 6 BuildPlan | `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_BuildPlan.md` | Complete | Future implementation blueprint with 6A-6G strict exit gates. |
| Phase 6 Progress | `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_Progress.md` | Complete | Tracker for future implementation, evidence, issues, and waivers. |
| UVM/RTL/Makefile/testbench code | N/A | Not modified | This documentation phase does not implement checker/testbench behavior. |
| Future implementation approval | N/A | Not started | A later approved phase must open the exact write scope. |

## 2. Subphase Progress Matrix

Status values: `Not started`, `Planned`, `In progress`, `Blocked`, `Review`, `Complete`, `Waived`, `Future`.

| Subphase | Title | Status | Owner | Planned deliverables | Strict exit summary | Regression/evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 6A | Observability and monitor closure | Planned | TBD | Probe/monitor inventory; missing-signal decision table; consumer list | Stable source, derived field, waiver, or future row for every required input | TBD |
| 6B | T0/T1 token and translation-SB waive removal | Planned | TBD | Reusable token queue; waive taxonomy; token diagnostics | Broad waives replaced by token/expt/no-response explanations or approved waiver | TBD |
| 6C | L1 entry shadow and hit-side compare | Planned | TBD | Entry shadow; hit PA/page-size/flag/attr compare; invalidate update policy | Hit-side result can be predicted from shadow when source is observable | TBD |
| 6D | MB lifecycle and legal no-response | Planned | TBD | MB shadow; allocation oracle; IID-age winner; no-response side-effect checks | Every legal no-response class has reason and no illegal side effects | TBD |
| 6E | Refill, install, and exception lifecycle | Planned | TBD | Refill/install oracle; exception lifecycle; stale/ABT matrix | Fault refill never writes TLB; expt replay consumes/releases matching state | TBD |
| 6F | Credit, wakeup, flush, invalidate, and race closure | Planned | TBD | Shared credit shadow; wakeup matrix; flush/invalidate/reset race checklist | Credit and shared-control behavior have one owner model or waiver | TBD |
| 6G | Directed scenario, coverage, and regression closure | Planned | TBD | ID-to-evidence matrix; regression tiers; coverage checklist; waiver list | No unfinished item is closed without trigger/checker evidence or waiver | TBD |

## 3. Open Work Package Tracker

| Work package | Status | Target phase | Primary unfinished IDs | Required closure evidence |
| --- | --- | --- | --- | --- |
| Stable observability | Planned | 6A | `L1DTLB_MON_*`, `L1DTLB_PROBE_*`, `L1DTLB_RESET_STATE`, `L1DTLB_SVA_A001` | Probe/monitor inventory and compile evidence. |
| T0/T1 token ownership | Planned | 6B | `L1DTLB_RM_T0_T1_TOKEN`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | Tokenized ownership checks and reduced translation-SB waives. |
| Page/access fault pairing | Planned | 6B | `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_FAULT_OVERLAP_GUARD` | PF current-T0, AF previous-T1, and same-cycle overlap evidence. |
| L1 entry shadow | Planned | 6C | `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_RM_ENTRY_ASID_GLOBAL`, `L1DTLB_SB_ATTR_COMPARE` | Independent entry state and hit-side PA/attr/permission compare. |
| Permission and direct-map semantics | Planned | 6C | `L1DTLB_LOOKUP_PAGE_FAULT_RULES`, `L1DTLB_LOOKUP_DIRECT_MAP`, `L1DTLB_LOOKUP_STAMO_PIPE1` | Full flag truth table, sysmap/direct-map attribute, STAMO source evidence. |
| MB lifecycle | Planned | 6D | `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_SB_MB_ALLOCATION` | MB allocation/state/lifecycle oracle and directed trigger logs. |
| Legal no-response taxonomy | Planned | 6D | `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_TS_OBS_LEGAL_NO_RESPONSE` | Reason-coded transaction-level no-response plus side-effect checks. |
| Refill/install lifecycle | Planned | 6E | `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_INSTALL_VISIBILITY`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE` | Normal/stale/fault refill and install boundary evidence. |
| Exception array lifecycle | Planned | 6E | `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE` | Expt write, replay, consume, wakeup, and MB release oracle evidence. |
| Scheduler credit | Planned | 6F | `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_UVM_WORK_003_CREDIT` | Exact credit conservation and zero-credit no-fire evidence. |
| Flush/invalidate/reset races | Planned | 6F | `L1DTLB_RTU_FLUSH_SCOPE`, `L1DTLB_INV_HIT_SAME_CYCLE`, `L1DTLB_ABT_LATE_REFILL`, `L1DTLB_SB_INVALIDATE_FLUSH` | Model-level race policy and targeted logs. |
| PLRU and `vabuf` guard | Planned | 6F | `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_SVA_A003`, `L1DTLB_TS_CTRL_VABUF_NO_EFFECT` | Whitebox/future/formal rows; no functional pass/fail dependency. |
| Scenario and regression closure | Planned | 6G | `L1DTLB_SB_TRACEABILITY_CLOSURE`, `L1DTLB_TS_OBS_SVA_COVER_CLOSURE`, `L1DTLB_UVM_WORK_005_DIAG` | Final ID-to-evidence matrix and archived logs/reports. |

## 4. Incomplete Traceability Backlog by Phase

This section mirrors the BuildPlan controlling backlog.  Future work must update status and evidence here before marking an item closed.

| Phase | Status | Backlog IDs |
| --- | --- | --- |
| 6A | Planned | `L1DTLB_SVA_A001`, `L1DTLB_SVA_A042`, `L1DTLB_TS_CTRL_RESET_STATE`, `L1DTLB_MON_LSU_FIELDS`, `L1DTLB_MON_T0_T1_EVENTS`, `L1DTLB_MON_L2_PTW_REFILL`, `L1DTLB_MON_CP0_SYSMAP_PMP`, `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_RESET_STATE` |
| 6B | Planned | `L1DTLB_SVA_A011`, `L1DTLB_SVA_A012`, `L1DTLB_SVA_A013`, `L1DTLB_SVA_A014`, `L1DTLB_SVA_A015`, `L1DTLB_SVA_A019`, `L1DTLB_SVA_A026`, `L1DTLB_SVA_A035`, `L1DTLB_SVA_A057`, `L1DTLB_SVA_A069`, `L1DTLB_TS_FAULT_RESPONSE_TIMING`, `L1DTLB_TS_FAULT_PF_BLOCKS_PMP`, `L1DTLB_TS_FAULT_OVERLAP_PIPE`, `L1DTLB_TS_FAULT_PMP_ACCESS`, `L1DTLB_LOOKUP_PIPE_TOKEN`, `L1DTLB_LOOKUP_PF_PA_VLD_PAIR`, `L1DTLB_LOOKUP_T1_ACCESS_FAULT`, `L1DTLB_LOOKUP_FAULT_OVERLAP`, `L1DTLB_SB_LSU_T0_T1_QUEUE`, `L1DTLB_SB_PAGE_FAULT_PAIRING`, `L1DTLB_SB_ACCESS_FAULT_PAIRING`, `L1DTLB_SB_FAULT_OVERLAP_GUARD`, `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` |
| 6C | Planned | `L1DTLB_SVA_A004`, `L1DTLB_SVA_A005`, `L1DTLB_SVA_A006`, `L1DTLB_SVA_A007`, `L1DTLB_SVA_A028`, `L1DTLB_SVA_A029`, `L1DTLB_SVA_A030`, `L1DTLB_SVA_A031`, `L1DTLB_SVA_A032`, `L1DTLB_SVA_A034`, `L1DTLB_SVA_C010`, `L1DTLB_SVA_C011`, `L1DTLB_TS_BASIC_PAGE_SIZE_4K_2M_1G`, `L1DTLB_TS_BASIC_MULTI_HIT_DIAG`, `L1DTLB_TS_BASIC_ENTRY_FIELD_MODEL`, `L1DTLB_TS_FAULT_LOAD_R0`, `L1DTLB_TS_FAULT_LOAD_MXR`, `L1DTLB_TS_FAULT_STORE_W_D`, `L1DTLB_TS_FAULT_AD_US_SUM`, `L1DTLB_TS_MODE_DIRECT_MAP`, `L1DTLB_TS_MODE_STAMO_PIPE1`, `L1DTLB_RM_ENTRY_SHADOW`, `L1DTLB_RM_ENTRY_FLAGS`, `L1DTLB_RM_ENTRY_ASID_GLOBAL`, `L1DTLB_RM_MULTI_HIT_POLICY`, `L1DTLB_LOOKUP_PAGE_SIZE_MATCH`, `L1DTLB_LOOKUP_PA_ASSEMBLY`, `L1DTLB_LOOKUP_ATTR_COMPARE`, `L1DTLB_LOOKUP_PAGE_FAULT_RULES`, `L1DTLB_LOOKUP_DIRECT_MAP`, `L1DTLB_LOOKUP_STAMO_PIPE1`, `L1DTLB_SB_ATTR_COMPARE` |
| 6D | Planned | `L1DTLB_SVA_A020`, `L1DTLB_SVA_A022`, `L1DTLB_SVA_A024`, `L1DTLB_SVA_A025`, `L1DTLB_SVA_A038`, `L1DTLB_SVA_A070`, `L1DTLB_SVA_C006`, `L1DTLB_SVA_C008`, `L1DTLB_SVA_C009`, `L1DTLB_SVA_C013`, `L1DTLB_SVA_C025`, `L1DTLB_TS_MB_DUAL_DIFF_4K_TWO_FREE`, `L1DTLB_TS_MB_DUAL_DIFF_4K_ONE_FREE_AGE`, `L1DTLB_TS_MB_4K_DEDUP_FOR_HUGE_FINAL`, `L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY`, `L1DTLB_TS_OBS_LEGAL_NO_RESPONSE`, `L1DTLB_RM_MB_SHADOW`, `L1DTLB_RM_MB_4K_CAM`, `L1DTLB_MB_CAM_HIT_NO_RESPONSE`, `L1DTLB_MB_DUAL_DIFF_TWO_FREE`, `L1DTLB_MB_DUAL_DIFF_ONE_FREE_AGE`, `L1DTLB_MB_SINGLE_OR_FULL`, `L1DTLB_LEGAL_NO_RESPONSE_TAXONOMY`, `L1DTLB_NO_RESPONSE_NO_SIDE_EFFECT`, `L1DTLB_SB_MB_ALLOCATION` |
| 6E | Planned | `L1DTLB_SVA_A017`, `L1DTLB_SVA_A049`, `L1DTLB_SVA_A052`, `L1DTLB_SVA_A054`, `L1DTLB_SVA_A055`, `L1DTLB_SVA_A056`, `L1DTLB_SVA_A058`, `L1DTLB_SVA_C018`, `L1DTLB_TS_MB_FAULT_HOLD`, `L1DTLB_TS_MB_STALE_REFILL_ID`, `L1DTLB_TS_MB_ABT_LATE_REFILL`, `L1DTLB_TS_INSTALL_VISIBILITY_RELEASE`, `L1DTLB_TS_EXPT_FAULT_REFILL_WRITE`, `L1DTLB_TS_EXPT_REPLAY_CONSUME`, `L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY`, `L1DTLB_RM_EXPT_SHADOW`, `L1DTLB_RM_EXPT_BIND_MB`, `L1DTLB_REFILL_STALE_NO_SIDE_EFFECT`, `L1DTLB_INSTALL_VISIBILITY`, `L1DTLB_FAULT_REFILL_NO_TLB_WRITE`, `L1DTLB_EXPT_REPLAY_TIMING`, `L1DTLB_EXPT_REPLAY_RELEASE`, `L1DTLB_SB_WAKEUP`, `L1DTLB_SB_INSTALL_EXPT` |
| 6F | Planned | `L1DTLB_SVA_A003`, `L1DTLB_SVA_A010`, `L1DTLB_SVA_A033`, `L1DTLB_SVA_A060`, `L1DTLB_SVA_A063`, `L1DTLB_SVA_C001`, `L1DTLB_SVA_C020`, `L1DTLB_SVA_C026`, `L1DTLB_TS_CTRL_VABUF_NO_EFFECT`, `L1DTLB_TS_SCHED_STORE_TYPE_PROP`, `L1DTLB_TS_INV_HIT_SAME_CYCLE`, `L1DTLB_TS_FLUSH_RTU_CLEAR_SCOPE`, `L1DTLB_RM_SB_PARTITION_004`, `L1DTLB_RM_SB_PARTITION_006`, `L1DTLB_RM_CREDIT_SHADOW`, `L1DTLB_SB_L2_REQ_CREDIT`, `L1DTLB_RTU_FLUSH_SCOPE`, `L1DTLB_INV_HIT_SAME_CYCLE`, `L1DTLB_ABT_LATE_REFILL`, `L1DTLB_SB_INVALIDATE_FLUSH`, `L1DTLB_UVM_WORK_003_CREDIT` |
| 6G | Planned | `L1DTLB_SVA_A067`, `L1DTLB_TS_OBS_SVA_COVER_CLOSURE`, `L1DTLB_RM_SB_PARTITION_001`, `L1DTLB_RM_SB_PARTITION_002`, `L1DTLB_RM_SB_PARTITION_003`, `L1DTLB_SB_TRACEABILITY_CLOSURE`, `L1DTLB_UVM_WORK_001_REF_SUBMODEL`, `L1DTLB_UVM_WORK_004_SPEC_SB`, `L1DTLB_UVM_WORK_005_DIAG` |

## 5. Evidence Log

Future phases must record every compile, directed run, negative/formal run, targeted regression, coverage report, and SVA report.

| Date | Subphase | Command / run | Result | Log / report path | Summary | Follow-up |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-22 | Phase 6 docs | Documentation creation | Complete | This file and BuildPlan | Created future implementation tracker only; no simulation or code implementation run. | Later approved code phase must record baseline compile/regression. |

## 6. Issue Log

Issue type values: `RTL bug`, `UVM bug`, `Spec gap`, `Tooling issue`, `Probe gap`, `Regression gap`, `Formal gap`, `Approved waiver`.

| ID | Date | Type | Severity | Related IDs | Description | Owner | Status | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L1DTLB-P6-ISSUE-001 | 2026-05-22 | Regression gap | Low | Phase 6 | Phase 6 is documentation-only; no compile or regression baseline was run. | TBD | Open | Close in the first approved implementation phase after recording baseline compile/regression. |
| L1DTLB-P6-ISSUE-002 | 2026-05-22 | Probe gap | Medium | `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_MON_*` | Full entry flags, refill flags, and per-request effective-mode token fields are not yet available as stable checker inputs. | TBD | Open | Resolve in Phase 6A or add approved waivers. |
| L1DTLB-P6-ISSUE-003 | 2026-05-22 | UVM bug | Medium | `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | Translation scoreboard still contains broad L1DTLB replay/timing/STAMO/PMP/direct-map waives. | TBD | Open | Resolve in Phase 6B with token/expt/no-response classification. |

## 7. Waiver Log

Phase 6 does not approve implementation waivers.  Later phases must fill this table before treating a missing checker, probe, cover, or scenario as non-blocking.

| Waiver ID | Related IDs | Missing gate | Reason | Replacement check / evidence | Risk | Approver | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | Not approved |

Waiver rules:

- Every waiver must name exact traceability IDs.
- A waiver must explain whether the missing item is covered by another checker, debug-only evidence, formal proof, or future work.
- Tooling failures require log fallback evidence before waiver.
- Missing stable probes must first be evaluated in Phase 6A.
- Coverage holes and untriggered scenarios must be recorded individually; overall regression pass is not sufficient.

## 8. Phase 6 Exit Record

| Check | Status | Notes |
| --- | --- | --- |
| `L1DTLB_UVM_Phase6_BuildPlan.md` exists | Complete | Created as future implementation blueprint. |
| `L1DTLB_UVM_Phase6_Progress.md` exists | Complete | Created as future implementation tracker. |
| Subphase matrix initialized | Complete | 6A through 6G listed as Planned. |
| Evidence, issue, and waiver templates initialized | Complete | Future phases must fill per run and per exception. |
| All known unfinished traceability rows assigned to future phases | Complete | See BuildPlan section 4 and this file section 4. |
| Documentation phase modifies no UVM/DUT/RTL/Makefile/testbench behavior | Complete | Only md files are intended to change. |
| Future implementation approval | Not started | Must be opened by a later approved phase. |
