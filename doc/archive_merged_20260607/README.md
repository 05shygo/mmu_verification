# Top-Level Markdown Merge Archive - 2026-06-07

This directory preserves top-level Markdown source documents whose effective
content has been fused into the three maintained documents:

- `../MMU_Progress.md`
- `../MMU_UVM_BuildPlan_v3_final.md`
- `../MMU_VerificationPlan_final.md`

Protected directories were not touched:

- `../l1dtlb_uvm_audit/`
- `../l2tlb_uvm_audit/`
- `../plan/`
- `../ptw_uvm_review/`

The signoff template `../IC验证计划_报告_签核清单.md` was also left untouched.

## Progress

| Archived source | Fused destination |
| --- | --- |
| `DA-003_phase13_port_mapping.md` | `../MMU_Progress.md` Phase 13 DA-003 port mapping |
| `MMU_Phase14_ClosureOwner.md` | `../MMU_Progress.md` Phase 14 Closure Owner bootstrap |
| `MMU_Phase14_IssueTracker.md` | `../MMU_Progress.md` Phase 14 issue/signoff status |
| `MMU_Phase14_SignoffMatrix.md` | `../MMU_Progress.md` Phase 14 issue/signoff status |
| `MMU_may_problem.md` | `../MMU_Progress.md` Phase 5 debug records |
| `P7B01_covergroup_vif_audit.md` | `../MMU_Progress.md` Phase 7 covergroup VIF audit |
| `phase11_bug015_doc_review.md` | `../MMU_Progress.md` Phase 11 delivery contract |
| `phase11_bug_hunt_matrix.md` | `../MMU_Progress.md` Phase 11 delivery contract |
| `phase11_exit_checklist.md` | `../MMU_Progress.md` Phase 11 exit criteria |
| `phase11_r19_gate.md` | `../MMU_Progress.md` Phase 11 R19 gate |
| `phase12_a_handoff.md` | `../MMU_Progress.md` Phase 12 handoff |
| `phase12_a_review.md` | `../MMU_Progress.md` Phase 12 handoff/review |
| `phase12_covergroup_matrix.md` | `../MMU_Progress.md` Phase 12 covergroup gate |
| `phase12_exit_checklist.md` | `../MMU_Progress.md` Phase 12 exit criteria |
| `phase12_scene_matrix.md` | `../MMU_Progress.md` Phase 12 scene matrix |
| `phase8_b_preflight.md` | `../MMU_Progress.md` Phase 8 preflight |
| `phase8_m8_a_review.md` | `../MMU_Progress.md` Phase 8 review |
| `phase8_m8_vseq_f_mapping.md` | `../MMU_Progress.md` Phase 8 vseq/F mapping |
| `ptw_rtl_debug.md` | `../MMU_Progress.md` PTW RTL debug summary |

## Build Plan

| Archived source | Fused destination |
| --- | --- |
| `MMU_UVM_Env_Architecture.md` | `../MMU_UVM_BuildPlan_v3_final.md` env/data-flow sections |
| `MMU_UVM_TaskDivision.md` | `../MMU_UVM_BuildPlan_v3_final.md` responsibility and phase boundaries |
| `phase11_b_stage_split.plan.md` | `../MMU_UVM_BuildPlan_v3_final.md` Phase 11 stage/list/gate contract |
| `phase12_b_stage_split.plan.md` | `../MMU_UVM_BuildPlan_v3_final.md` Phase 12 stage/handoff/gate contract |

## Verification Plan

| Archived source | Fused destination |
| --- | --- |
| `MMU_GapAudit_v1.md` | `../MMU_VerificationPlan_final.md` gap TC, risk, traceability summary |
| `MMU_UVM_Spec_QA_Checklist.md` | `../MMU_VerificationPlan_final.md` Spec QA decisions |
| `MMU_VerificationPlan.md` | `../MMU_VerificationPlan_final.md` version evolution |
| `MMU_VerificationPlan_v1.md` | `../MMU_VerificationPlan_final.md` version evolution |
| `MMU_VerificationPlan_v2.md` | `../MMU_VerificationPlan_final.md` version evolution |
| `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | `../MMU_VerificationPlan_final.md` baseline TC import rule |

## CSV

| Archived source | Fused destination |
| --- | --- |
| `csv/phase9_b_stage_catalog_system.csv` | `../MMU_Traceability_Matrix.csv` Phase 9 system wrapper stage/artifact fields |
| `csv/phase11_b_stage_manifest.csv` | `../MMU_Traceability_Matrix.csv` Phase 11 implementation status, seed policy, blocked/xfail/review notes |

`../phase12_b_stage_manifest.csv` was intentionally kept in place because it is
the Phase 12 stage/task manifest consumed by
`../mmu_verification/scripts/phase12_exit_check.sh`, not a one-row-per-testcase
traceability source.
