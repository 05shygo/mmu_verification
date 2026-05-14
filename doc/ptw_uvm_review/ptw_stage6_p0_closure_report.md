# PTW Stage 6 P0 Closure Report

This report records the Stage 6 directed-test closure plan and the explicit
open reasons that remain outside Stage 6. The source of functional truth remains
`ptwspec.md`; the phase boundary remains `ptw_staged_implementation_plan.md`.

## Scope

Stage 6 adds grouped P0 directed tests instead of one file per requirement.
Every normal directed test is expected to run with:

```text
+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
```

The P0 regression list is:

```text
mmu_verification/simu/ptw_p0_list
```

## Test Groups

| Test | Primary closure |
| --- | --- |
| `test_ptw_p0_pte_layout_matrix` | RSW/high reserved no-fault, G leaf-only, refill flg/tag/data layout, 1G/4K success flows. |
| `test_ptw_p0_type_pfu_fault_matrix` | fetch/load/store/PFU success target, exception target, PFU L2-only, PFU permission exception, original PMP type permission representative. |
| `test_ptw_p0_permission_matrix` | write-only/MXR, fetch/load/store/PFU permission representatives, A/D/U/S/SUM, scd/thd page fault representatives, huge align before degrade. |
| `test_ptw_p0_pde_mbuf_pmp_matrix` | PDE hit/update representative paths, fst PMP deny, CHK slow/hold, LSU bus error priority, MPRV/MPP=M load PTW walk plus PFU direct-map consumer sanity. |
| `test_ptw_p0_maee_sysmap_matrix` | MAEE=1 raw ext attr for 1G/2M/4K and MAEE=0 4K sysmap flag refill. |
| `test_ptw_p0_flow_trace_umbrella` | `PTW-FLOW-001..023` binding markers with closed/open status and source evidence owner. |

## PTW-ADD Status

| ID | Stage 6 status | Evidence |
| --- | --- | --- |
| PTW-ADD-001 | closed-by-directed | `stage6_pte_rsw_high_reserved_4k`; source SB flg compare; `PTW-SVA-CHK-009`, `PTW-SVA-ARB-008`. |
| PTW-ADD-002 | closed-by-directed | `stage6_pte_rsw_high_reserved_4k`; source SB no-fault compare; old reserved-fault wrapper obsolete. |
| PTW-ADD-003 | closed-by-directed | `stage6_pte_leaf_global_1g`, `stage6_pte_nonleaf_global_not_or`; source SB global/tag/data compare. |
| PTW-ADD-004 | closed-by-directed | `stage6_type_fetch_success`, `stage6_type_load_success`, `stage6_type_store_success`, `stage6_type_pfu_success_l2_only`. |
| PTW-ADD-005 | closed-by-directed | `stage6_fault_fetch_no_x`, `stage6_fault_load_no_r`, `stage6_fault_store_no_w`, `stage6_fault_pfu_a_zero`, `stage6_pmp_original_fetch_x_deny`. |
| PTW-ADD-006 | closed-by-directed | `stage6_lsu_bus_error_priority_access_fault`; source SB class/key priority and bus-error visible access-fault match. |
| PTW-ADD-007 | partial-open | PDE L1/L2 hit paths closed; raw double-hit L2-wins requires Stage 7 whitebox/vector support. |
| PTW-ADD-008 | open-stage7 | Lookup/update same-cycle old-state precision is assigned to Stage 7. |
| PTW-ADD-009 | closed-by-directed | `stage6_pde_l1_hit_final_2m`, `stage6_pde_l2_hit_final_4k`; nonleaf update representative with PDE SVA cover. |
| PTW-ADD-010 | open-stage7-tb-gap | satp/PMP clear-only re-update needs `pmp_regs_update`/old-walk precision. |
| PTW-ADD-011 | partial-open | reset/abort flush SVA exists; full abort/drop matrix remains Stage 7. |
| PTW-ADD-012 | closed-by-sva-directed | P0 requests in grouped tests exercise xbar/ready cover; old round-robin expectation obsolete. |
| PTW-ADD-013 | partial-open | `stage6_pmp_fst_deny_access_fault` closes fst deny; scd/thd isolated deny remains Stage 7 vector work. |
| PTW-ADD-014 | closed-by-directed | `stage6_pmp_original_fetch_x_deny`, `stage6_pmp_original_load_r_allow`. |
| PTW-ADD-015 | closed-by-directed | `stage6_mprv_mpp_m_load_success`; `stage6_mprv_mpp_m_pfu_success` is consumer-only when effective M-mode direct-maps before PTW. |
| PTW-ADD-016 | partial-open | `stage6_scd_page_fault_v0` and `stage6_thd_nonleaf_page_fault` close representative nonleaf/level page faults; malformed nonleaf expansion remains Stage 7 precision work. |
| PTW-ADD-017 | closed-by-directed | `stage6_write_only_mxr0_fault`, `stage6_write_only_mxr1_success`. |
| PTW-ADD-018 | closed-by-directed | fetch/load/store/PFU representatives in type and permission matrices. |
| PTW-ADD-019 | closed-by-directed | `stage6_store_d_zero_fault`, `stage6_supervisor_u_sum0_fault`, `stage6_user_supervisor_leaf_fault`. |
| PTW-ADD-020 | closed-by-directed | `stage6_huge_1g_align_before_degrade`; page fault before sysmap/degrade. |
| PTW-ADD-021 | closed-by-sva-directed | `stage6_mbuf_chk_not_ready_hold`; MBUF allocation evidence from Stage-5 SVA cover plus source SB refill. |
| PTW-ADD-022 | closed-by-directed | `stage6_mbuf_chk_not_ready_hold`; CHK slow/hold path. |
| PTW-ADD-023 | closed-by-directed | `stage6_lsu_bus_error_priority_access_fault`; data_vld+bus_error visible access fault. |
| PTW-ADD-024 | open-stage7 | Full abort data/bus-error/pre-existing exception matrix remains Stage 7 ref/SB precision. |
| PTW-ADD-025 | closed-by-directed | `stage6_maee1_1g_ext_attr`, `stage6_maee1_2m_ext_attr`, `stage6_maee1_4k_ext_attr`. |
| PTW-ADD-026 | closed-by-directed | `stage6_maee0_4k_sysmap_refill`. |
| PTW-ADD-027 | open-stage7-model-gap | MAEE=0 1G degrade final page_size/PPN/no-lower-walk not modeled in Stage 4. |
| PTW-ADD-028 | open-stage7-model-gap | MAEE=0 2M degrade final page_size/PPN/no-thd-walk not modeled in Stage 4. |
| PTW-ADD-029 | partial-open | 4K sysmap flag order closed; malformed/default constraints remain later signoff. |
| PTW-ADD-030 | open-stage7 | Same-cycle ASID/MXR/SUM/MAEE usage-point sampling is Stage 7. |
| PTW-ADD-031 | closed-by-binding | `test_ptw_p0_flow_trace_umbrella` binds all `PTW-FLOW-001..023` to directed evidence or open reason. |
| PTW-ADD-032 | consumer-only | L1DTLB evidence remains auxiliary and cannot replace PTW source closure. |
| PTW-ADD-033 | closed-by-directed | `stage6_type_pfu_success_l2_only`, `stage6_fault_pfu_a_zero`. |
| PTW-ADD-034 | closed-by-directed | PTE layout and MAEE tests compare bit-exact refill tag/data/flg. |

## PTW-FLOW Status

| Flow | Stage 6 status | Evidence |
| --- | --- | --- |
| PTW-FLOW-001 | closed | 1G success via PTE/MAEE tests; source SB refill match. |
| PTW-FLOW-002 | closed | 2M success via `stage6_maee1_2m_ext_attr`; source SB refill match. |
| PTW-FLOW-003 | closed | 4K success via PTE/type matrices; source SB refill match. |
| PTW-FLOW-004 | open-stage7-model-gap | MAEE=0 1G->2M degrade needs Stage 7 source model. |
| PTW-FLOW-005 | open-stage7-model-gap | MAEE=0 1G->4K degrade needs Stage 7 source model. |
| PTW-FLOW-006 | open-stage7-model-gap | MAEE=0 2M->4K degrade needs Stage 7 source model. |
| PTW-FLOW-007 | open-stage7-model-gap | MAEE=0 huge no-cross needs Stage 7 source model. |
| PTW-FLOW-008 | closed | `stage6_maee0_4k_sysmap_refill`; source SB sysmap flag match. |
| PTW-FLOW-009 | closed | `stage6_pmp_fst_deny_access_fault`; source SB access fault. |
| PTW-FLOW-010 | open-stage7-vector-gap | isolated scd PMP deny vector pending. |
| PTW-FLOW-011 | open-stage7-vector-gap | isolated thd PMP deny vector pending. |
| PTW-FLOW-012 | closed | huge-align/first-level page-fault representative. |
| PTW-FLOW-013 | closed | `stage6_scd_page_fault_v0`; second-level page-fault representative. |
| PTW-FLOW-014 | closed | `stage6_thd_nonleaf_page_fault` plus PFU page-fault representative. |
| PTW-FLOW-015 | closed | L1 PDE hit final 2M representative. |
| PTW-FLOW-016 | closed | PDE hit final 4K representative. |
| PTW-FLOW-017 | closed | L2 PDE hit final 4K representative. |
| PTW-FLOW-018 | closed | LSU bus error access-fault representative. |
| PTW-FLOW-019 | open-stage7-model-gap | abort LSU outstanding/drop matrix precision pending. |
| PTW-FLOW-020 | closed | PFU success L2-only. |
| PTW-FLOW-021 | closed | PFU exception target. |
| PTW-FLOW-022 | open-stage7-tb-gap | satp/PMP PDE clear-only re-update pending. |
| PTW-FLOW-023 | closed | load MPRV=1 MPP=M PTW-walk representative; PFU MPP=M direct-map is recorded as consumer-only sanity. |

## Legacy Conflict Handling

| Legacy test | Stage 6 action |
| --- | --- |
| `test_xbar_twu_round_robin` | Re-labeled as obsolete round-robin expectation; retained only as legacy stress, not source closure. |
| `test_pte_reserved_bits` | Re-labeled as obsolete reserved/RSW fault expectation; source closure moved to `test_ptw_p0_pte_layout_matrix`. |
| `test_mbuf_ooo_response` | Re-labeled as illegal-stress for old OOO response assumption; PTW PTE channel remains single-outstanding. |

## Exit Gate

The Stage 6 exit gate command is:

```bash
python3 mmu_verification/scripts/ptw_stage6_exit_gate.py \
  --list mmu_verification/simu/ptw_p0_list \
  --log-dir mmu_verification/output/logs \
  --seed 606 \
  --closure doc/ptw_uvm_review/ptw_stage6_p0_closure_report.md \
  --csv mmu_verification/simu/ptw_source_closure_matrix.csv
```
