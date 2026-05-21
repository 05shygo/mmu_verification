# L1DTLB UVM Phase 6 Progress

> Project: OpenRiscv2030 MMU UVM Verification
> Scope: L1DTLB UVM follow-up implementation progress and gate tracking
> Build plan: `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_BuildPlan.md`
> Golden source: `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md`
> Date: 2026-05-22

## 1. Phase Status

Phase 6 started as the follow-up implementation blueprint and progress tracker.  Phase 6A observability implementation is complete; later subphases must keep this tracker updated before marking rows complete.

| Item | Path | Status | Notes |
| --- | --- | --- | --- |
| Phase 6 BuildPlan | `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_BuildPlan.md` | Complete | Future implementation blueprint with 6A-6G strict exit gates. |
| Phase 6 Progress | `doc/l1dtlb_uvm_audit/L1DTLB_UVM_Phase6_Progress.md` | Complete | Tracker for future implementation, evidence, issues, and waivers. |
| UVM/testbench code | `mmu_verification/testbench/...` | Modified in 6A | Phase 6A touched probes, top wiring, LSU monitor/txn, whitebox coverage, SVA width/reset cleanup, and L1DTLB scoreboard inventory checks. |
| RTL/Makefile code | `mmu/rtl/...` | Modified in 6A | Compile blockers and width hygiene were fixed in RTL; Makefiles and regression configuration were not changed. |
| Future implementation approval | N/A | 6A complete | Remaining 6B-6G phases still require explicit implementation work. |

## 2. Subphase Progress Matrix

Status values: `Not started`, `Planned`, `In progress`, `Blocked`, `Review`, `Complete`, `Waived`, `Future`.

| Subphase | Title | Status | Owner | Planned deliverables | Strict exit summary | Regression/evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 6A | Observability and monitor closure | Complete | Codex | Probe/monitor inventory; missing-signal decision table; consumer list | Stable source, derived field, or future-risk row recorded for required inputs; `fragile_root_paths=0`; compile and smoke pass. | `make comp_fast` PASS; `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_ref_model_observability_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` PASS. |
| 6B | T0/T1 token and translation-SB waive removal | Planned | TBD | Reusable token queue; waive taxonomy; token diagnostics | Broad waives replaced by token/expt/no-response explanations or approved waiver | TBD |
| 6C | L1 entry shadow and hit-side compare | Planned | TBD | Entry shadow; hit PA/page-size/flag/attr compare; invalidate update policy | Hit-side result can be predicted from shadow when source is observable | TBD |
| 6D | MB lifecycle and legal no-response | Planned | TBD | MB shadow; allocation oracle; IID-age winner; no-response side-effect checks | Every legal no-response class has reason and no illegal side effects | TBD |
| 6E | Refill, install, and exception lifecycle | Planned | TBD | Refill/install oracle; exception lifecycle; stale/ABT matrix | Fault refill never writes TLB; expt replay consumes/releases matching state | TBD |
| 6F | Credit, wakeup, flush, invalidate, and race closure | Planned | TBD | Shared credit shadow; wakeup matrix; flush/invalidate/reset race checklist | Credit and shared-control behavior have one owner model or waiver | TBD |
| 6G | Directed scenario, coverage, and regression closure | Planned | TBD | ID-to-evidence matrix; regression tiers; coverage checklist; waiver list | No unfinished item is closed without trigger/checker evidence or waiver | TBD |

## 3. Open Work Package Tracker

| Work package | Status | Target phase | Primary unfinished IDs | Required closure evidence |
| --- | --- | --- | --- | --- |
| Stable observability | Complete | 6A | `L1DTLB_MON_*`, `L1DTLB_PROBE_*`, `L1DTLB_RESET_STATE`, `L1DTLB_SVA_A001` | Probe/monitor inventory implemented, compiled, and smoke-tested; Phase6A final scoreboard inventory reports `fragile_root_paths=0`. |
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
| 6A | Complete | `L1DTLB_SVA_A001`, `L1DTLB_SVA_A042`, `L1DTLB_TS_CTRL_RESET_STATE`, `L1DTLB_MON_LSU_FIELDS`, `L1DTLB_MON_T0_T1_EVENTS`, `L1DTLB_MON_L2_PTW_REFILL`, `L1DTLB_MON_CP0_SYSMAP_PMP`, `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_RESET_STATE` |
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
| 2026-05-22 | 6A | Initial `make comp_fast` | Resolved | `mmu_verification/output/logs/comp_fast.log` | Initial VCS attempts exposed compile blockers in `mmu_arb.sv`, `credit_sva.sv`, and `mmu_l2tlb_rrpv_wbuf.sv`, plus reset/widening hygiene items found during closure. | Closed by `L1DTLB-P6-ISSUE-004` through `L1DTLB-P6-ISSUE-009`; passing rows below are the active gate evidence. |
| 2026-05-22 | 6A | `make comp_fast` | Complete | `mmu_verification/output/logs/comp_fast.log` | VCS compile, elaboration, and link completed. Final design-warning scan shows no errors/fatals and no remaining PCWM/IPDW/ICPD warnings; remaining messages are environment locale/clock-skew notices and the expected `LCA_FEATURES_ENABLED` usage warning. | Use this as the Phase6A compile baseline. |
| 2026-05-22 | 6A | `make run_check TEST_NAME=test_mmu_l1dtlb_dtlb_ref_model_observability_001 SEED=97101 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0` | Complete | `mmu_verification/output/logs/test_mmu_l1dtlb_dtlb_ref_model_observability_001_97101.log` | PASS logs: 1, FAIL logs: 0; UVM summary reports `UVM_ERROR=0` and `UVM_FATAL=0`; Phase6A inventory printed `inventory_checks=3585`, `entry_payload=1078`, `refill_payload=4`, `install_arb=4`, `mode_snapshot=3585`, `fragile_root_paths=0`. | Proceed to Phase 6B for token/waive closure. |

## 5A. Phase 6A Observability Inventory

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

## 6. Issue Log

Issue type values: `RTL bug`, `UVM bug`, `Spec gap`, `Tooling issue`, `Probe gap`, `Regression gap`, `Formal gap`, `Approved waiver`.

| ID | Date | Type | Severity | Related IDs | Description | Owner | Status | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L1DTLB-P6-ISSUE-001 | 2026-05-22 | Regression gap | Low | Phase 6 | Phase 6 began before any compile or regression baseline was run. | Codex | Closed | Phase6A records passing `make comp_fast` and L1DTLB observability smoke evidence. |
| L1DTLB-P6-ISSUE-002 | 2026-05-22 | Probe gap | Medium | `L1DTLB_PROBE_ENTRY`, `L1DTLB_PROBE_REFILL_INSTALL`, `L1DTLB_MON_*` | Full entry flags, refill flags, and per-request effective-mode token fields were not available as stable checker inputs. | Codex | Closed | Phase 6A added stable probes, LSU transaction snapshots, Phase6A X checks, and final inventory reporting. |
| L1DTLB-P6-ISSUE-003 | 2026-05-22 | UVM bug | Medium | `L1DTLB_UVM_WORK_002_REMOVE_BROAD_WAIVE` | Translation scoreboard still contains broad L1DTLB replay/timing/STAMO/PMP/direct-map waives. | TBD | Open | Resolve in Phase 6B with token/expt/no-response classification. |
| L1DTLB-P6-ISSUE-004 | 2026-05-22 | RTL bug | High | 6A compile gate | Initial `make comp_fast` failed before closure with `mmu/rtl/mmu_arb.sv` undeclared identifiers used before declaration. | Codex | Closed | Moved/predeclared `ptw_write_req1/2`, `arb_ptw_write_grant`, and related PTW write payload declarations before first use; final `make comp_fast` passes. |
| L1DTLB-P6-ISSUE-005 | 2026-05-22 | UVM bug | High | 6A compile gate | `credit_sva.sv` bound a 3-bit `issue_queue_id` port to the 4-bit `mmu_l2tlb_reqq` queue id. | Codex | Closed | Parameterized `credit_sva` queue id width as 4-bit; compile passes. |
| L1DTLB-P6-ISSUE-006 | 2026-05-22 | RTL bug | High | 6A compile gate | `mmu_l2tlb_rrpv_wbuf.sv` drove `lookup_hit_comb` and `bypassed_rrpv_rdata_comb` from multiple `always_comb` blocks. | Codex | Closed | Moved same-cycle push bypass handling into the single bypass combinational block; compile passes. |
| L1DTLB-P6-ISSUE-007 | 2026-05-22 | UVM bug | Medium | `L1DTLB_SVA_A001`, reset gate | L1DTLB reset SVA used same-cycle implication and printed a reset-time assertion failure in smoke despite clean UVM summary. | Codex | Closed | Changed the reset visible-state assertion to non-overlapped implication; final smoke has no assertion `failed at` lines. |
| L1DTLB-P6-ISSUE-008 | 2026-05-22 | RTL bug | Medium | 6A compile hygiene | L2TLB queue transaction id was 4-bit in `mmu_l2tlb`/ReqQ but 3-bit in `ct_mmu_top.v`/default `mmu_arb`, causing PCWM width warnings and potential truncation. | Codex | Closed | Widened `queue_arb_trans_id` and `arb_l2tlb_trans_id` to `L2EID_WIDTH`, parameterized `mmu_arb.TRANS_ID_WIDTH`, and widened the whitebox probe/coverage bin range. |
| L1DTLB-P6-ISSUE-009 | 2026-05-22 | RTL bug | Low | 6A compile hygiene | `ptw_mbuf.sv` redeclared output port `mbuf_twu_pmpflg` as an internal logic, producing an IPDW warning. | Codex | Closed | Removed the duplicate internal declaration; final compile log has no IPDW warning. |

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
| Subphase matrix initialized | Complete | 6A is complete; 6B through 6G remain planned. |
| Evidence, issue, and waiver templates initialized | Complete | 6A compile/smoke evidence and closure issues are recorded; future phases must fill per run and per exception. |
| All known unfinished traceability rows assigned to future phases | Complete | See BuildPlan section 4 and this file section 4. |
| Phase6A implementation modifies only scoped UVM/testbench plus compile-fix RTL/SVA behavior | Complete | Makefiles and regression configuration were not changed. |
| Future implementation approval | 6A complete | Remaining 6B-6G phases must be opened by later approved implementation work. |
