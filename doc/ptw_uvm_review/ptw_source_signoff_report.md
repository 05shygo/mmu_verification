# PTW Source Signoff Report

PTW_STAGE8_SIGNOFF_REPORT version=1 frozen=1 date=2026-05-15
PTW_STAGE10_SIGNOFF_REPORT version=2 frozen=1 date=2026-05-18

This is the Stage 10 frozen regression/signoff package for PTW source-side
verification, including the PDE-cache pmpflg Stage 8/9 tests. `ptwspec.md`
remains the functional truth; this report freezes the runnable lists,
parser/gate, closure matrix, consumer-only separation, and open/waiver
register.

## Regression Lists

PTW_SIGNOFF_REGRESSION_LIST role=p0_smoke path=mmu_verification/simu/ptw_p0_smoke_list seed=606 source_closure=1
PTW_SIGNOFF_REGRESSION_LIST role=p0_full path=mmu_verification/simu/ptw_p0_list seed=606 source_closure=1
PTW_SIGNOFF_REGRESSION_LIST role=p1_directed path=mmu_verification/simu/ptw_p1_list seed=707 source_closure=1
PTW_SIGNOFF_REGRESSION_LIST role=pde_pmpflg path=mmu_verification/simu/ptw_pde_pmpflg_list seed=606,707 source_closure=1
PTW_SIGNOFF_REGRESSION_LIST role=p2_illegal path=mmu_verification/simu/ptw_p2_illegal_list seed=707 source_closure=0 illegal_constraint=1
PTW_SIGNOFF_REGRESSION_LIST role=random_stress path=mmu_verification/simu/ptw_random_list seed=707 source_closure=1
PTW_SIGNOFF_REGRESSION_LIST role=consumer_only path=mmu_verification/simu/ptw_consumer_evidence_list seed=707 source_closure=0

| Role | List | Closure use |
| --- | --- | --- |
| P0 smoke | `mmu_verification/simu/ptw_p0_smoke_list` | Fast source-side sanity; not a replacement for P0 full. |
| P0 full | `mmu_verification/simu/ptw_p0_list` | Required P0 source closure gate. |
| P1 directed | `mmu_verification/simu/ptw_p1_list` | Stage 7 precision/context evidence. |
| PDE pmpflg | `mmu_verification/simu/ptw_pde_pmpflg_list` | Stage 8/9 PDE cached-pmpflg signoff list; explicit open/unreachable tests are allowed only with marker records. |
| P2/illegal | `mmu_verification/simu/ptw_p2_illegal_list` | Constraint evidence only; illegal stimulus must be blocked/classified. |
| Random/stress | `mmu_verification/simu/ptw_random_list` | Stage 7 randomized field/context stress. |
| Consumer-only | `mmu_verification/simu/ptw_consumer_evidence_list` | Downstream L1/L2 consumption evidence only. |

## Gate

PTW_SIGNOFF_GATE path=mmu_verification/scripts/ptw_stage8_signoff_gate.py
PTW_SIGNOFF_CLOSURE_MATRIX frozen=1 path=mmu_verification/simu/ptw_source_closure_matrix.csv
PTW_SIGNOFF_NO_GLOBAL_WAIVER critical_fields=flg,page_size,ppn,fault_kind,target
PTW_SIGNOFF_CONSUMER_ONLY source_closure=0 evidence=auxiliary
PTW_SIGNOFF_OBSOLETE_FREEZE tests=test_xbar_twu_round_robin;test_pte_reserved_bits;test_mbuf_ooo_response action=not_counted_as_ptw_closure status=obsolete-by-spec
PTW_SIGNOFF_PDE_PMPFLG ids=PTW-ADD-037..045,PDE-TP-013..019,PTW-FLOW-024..028 list=mmu_verification/simu/ptw_pde_pmpflg_list gate=stage10

The Stage 10 gate validates clean P0 source scoreboard summaries, P0 SVA cover
hits, Stage 8/9 PDE pmpflg coverage banners, `no_extra_lsu`, required
`PTW-SVA-PDE/ARB` cover hits, P1/P2/random status markers, closure CSV
integrity, report markers, and per-item open records. No waiver in this report
covers source `flg`, `page_size`, `ppn`, `fault_kind`, or `target` mismatches.

## Closure Summary

| Family | Total | Closed/implemented | Open/partial | Consumer-only |
| --- | ---: | ---: | ---: | ---: |
| PTW-AUD | 23 | 0 | 22 | 1 |
| PTW-ADD | 45 | 29 | 15 | 1 |
| PTW-FLOW | 28 | 17 | 11 | 0 |
| PTW-INFRA | 9 | 4 | 5 | 0 |
| PDE-TP | 19 | 4 | 15 | 0 |
| MBUF-TP | 12 | 0 | 12 | 0 |
| MAEE-TP | 13 | 2 | 11 | 0 |

The `PTW-AUD-*` rows remain traceability rollups in the frozen CSV; leaf-level
closure is recorded by `PTW-ADD-*`, `PTW-FLOW-*`, `PDE-TP-*`, `MBUF-TP-*`,
`MAEE-TP-*`, and `PTW-INFRA-*`.  Audit rows with `stage0 mapping only` are not
waivers and do not hide source failures.

## Flow Status

| Flow | Status |
| --- | --- |
| PTW-FLOW-001 | closed: 1G success source refill match. |
| PTW-FLOW-002 | closed: 2M success source refill match. |
| PTW-FLOW-003 | closed: 4K success source refill match. |
| PTW-FLOW-004 | open: MAEE=0 1G->2M dedicated directed evidence missing. |
| PTW-FLOW-005 | open: MAEE=0 1G->4K dedicated directed evidence missing. |
| PTW-FLOW-006 | open: MAEE=0 2M->4K dedicated directed evidence missing. |
| PTW-FLOW-007 | partial: random no-cross evidence exists; dedicated no-cross matrix recommended. |
| PTW-FLOW-008 | closed: MAEE=0 4K sysmap refill source match. |
| PTW-FLOW-009 | closed: first-level PMP access fault source match. |
| PTW-FLOW-010 | open: isolated second-level PMP deny vector missing. |
| PTW-FLOW-011 | open: isolated third-level PMP deny vector missing. |
| PTW-FLOW-012 | closed: first-level CHK page fault representative. |
| PTW-FLOW-013 | closed: second-level CHK page fault representative. |
| PTW-FLOW-014 | closed: third-level CHK/PFU page fault representative. |
| PTW-FLOW-015 | closed: L1 PDE hit final 2M representative. |
| PTW-FLOW-016 | closed: L1 PDE hit final 4K representative. |
| PTW-FLOW-017 | closed: L2 PDE hit final 4K representative. |
| PTW-FLOW-018 | closed: LSU bus error visible access fault. |
| PTW-FLOW-019 | open: full abort outstanding data/bus-error/drop matrix missing. |
| PTW-FLOW-020 | closed: PFU success L2-only source target. |
| PTW-FLOW-021 | closed: PFU exception source target. |
| PTW-FLOW-022 | partial: SATP old-walk covered; PMP update clear remains top/probe gap. |
| PTW-FLOW-023 | closed-consumer-only: load/store/PFU MPRV=1 MPP=M direct-map/no PTW source; fetch remains real-privilege. |
| PTW-FLOW-024 | closed: L1 cached pmpflg tag-deny miss falls back to FST/TWU path. |
| PTW-FLOW-025 | partial: L2 cached L1 deny direct-accerr and no-extra-LSU evidence exists; exact independent FST/SCD PMP assignment remains limited by flag-only PMP agent. |
| PTW-FLOW-026 | open-unreachable: old `MPRV=1/MPP=M` data construction is no longer legal PTW source traffic; exact L2-only deny needs lower-level evidence. |
| PTW-FLOW-027 | closed: cached pmpflg allow reuse covers load/PFU R, fetch X, and store W. |
| PTW-FLOW-028 | open-unreachable: data/PFU effective-M bypass/lock matrix is not top-source reachable; fetch ignores MPRV/MPP. |

## Waiver Register

PTW_SIGNOFF_WAIVER count=0 scope=none fields=none

There are no functional source-side waivers in this Stage 8 package.  Open and
partial items are tracked below instead of being waived.  Consumer-side timing
or replay alignment can be waived only in consumer scoreboards and must not
cover PTW source `flg/page_size/ppn/fault_kind/target` mismatches.

## Open Register

PTW_SIGNOFF_OPEN id=PTW-ADD-007 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=raw_pde_double_hit_vector_missing next=add_raw_L1_L2_double_hit_directed_test_and_cover
PTW_SIGNOFF_OPEN id=PTW-ADD-008 owner=mmu_verification/testbench/env/ptw_pde_cache_model.svh reason=lookup_update_old_state_directed_proof_missing next=add_same_cycle_lookup_update_whitebox_scenario
PTW_SIGNOFF_OPEN id=PTW-ADD-010 owner=mmu_verification/testbench/top/tb_top.sv reason=pmp_regs_update_probe_tied_off next=connect_real_pmp_update_or_add_whitebox_probe_and_directed_test
PTW_SIGNOFF_OPEN id=PTW-ADD-011 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=reset_abort_flush_matrix_partial next=add_reset_abort_pde_clear_flush_directed_matrix
PTW_SIGNOFF_OPEN id=PTW-ADD-013 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=scd_thd_pmp_deny_vectors_missing next=add_level_specific_pmp_deny_no_side_effect_tests
PTW_SIGNOFF_OPEN id=PTW-ADD-016 owner=mmu_verification/testbench/env/ptw_source_ref_model.svh reason=malformed_nonleaf_matrix_not_dedicated next=add_nonleaf_level_matrix_directed_test
PTW_SIGNOFF_OPEN id=PTW-ADD-024 owner=mmu_verification/testbench/env/ptw_source_sb.svh reason=full_abort_data_bus_error_drop_matrix_missing next=add_abort_outstanding_data_bus_error_preexisting_exception_matrix
PTW_SIGNOFF_OPEN id=PTW-ADD-027 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=dedicated_1g_cross_degrade_evidence_missing next=add_1g_no_cross_to_2m_to_4k_directed_matrix
PTW_SIGNOFF_OPEN id=PTW-ADD-028 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=dedicated_2m_cross_degrade_evidence_missing next=add_2m_no_cross_to_4k_directed_matrix
PTW_SIGNOFF_OPEN id=PTW-ADD-029 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=sysmap_flag_order_default_partial next=add_valid_region_flag_order_and_malformed_constraint_report
PTW_SIGNOFF_OPEN id=PTW-ADD-030 owner=mmu_verification/testbench/env/ptw_source_ref_model.svh reason=mxr_sum_same_cycle_sampling_best_effort next=add_same_cycle_context_ordering_sva_or_directed_constraint
PTW_SIGNOFF_OPEN id=PTW-ADD-039 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh reason=flag_only_pmp_agent_cannot_independently_assign_fst_scd_pmpflg next=add_lower_level_or_agent_support_for_independent_l1_l2_cached_pmpflg
PTW_SIGNOFF_OPEN id=PTW-ADD-040 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh reason=mprv1_mppm_data_no_longer_enters_ptw_source next=add_legal_lower_level_l2_only_cached_pmpflg_deny_evidence
PTW_SIGNOFF_OPEN id=PTW-ADD-043 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_mmode_lock_matrix_001.svh reason=data_pfu_effective_m_top_source_unreachable_fetch_ignores_mprv_mpp next=add_lower_level_pde_cache_or_rtl_unit_lock_bypass_matrix
PTW_SIGNOFF_OPEN id=PTW-ADD-045 owner=mmu_verification/testbench/top/tb_top.sv reason=pmp_regs_update_tied_off_so_exact_pmp_update_clear_not_proven next=connect_pmp_regs_update_or_add_equivalent_whitebox_drive
PTW_SIGNOFF_OPEN id=PTW-FLOW-004 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=1g_to_2m_degrade_directed_evidence_missing next=add_maee0_1g_to_2m_cross_directed
PTW_SIGNOFF_OPEN id=PTW-FLOW-005 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=1g_to_4k_degrade_directed_evidence_missing next=add_maee0_1g_to_4k_cross_directed
PTW_SIGNOFF_OPEN id=PTW-FLOW-006 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=2m_to_4k_degrade_directed_evidence_missing next=add_maee0_2m_to_4k_cross_directed
PTW_SIGNOFF_OPEN id=PTW-FLOW-007 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=huge_no_cross_dedicated_matrix_missing next=add_1g_2m_no_cross_directed_matrix
PTW_SIGNOFF_OPEN id=PTW-FLOW-010 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=scd_pmp_deny_vector_missing next=add_second_level_pte_pa_pmp_deny_test
PTW_SIGNOFF_OPEN id=PTW-FLOW-011 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=thd_pmp_deny_vector_missing next=add_third_level_pte_pa_pmp_deny_test
PTW_SIGNOFF_OPEN id=PTW-FLOW-019 owner=mmu_verification/testbench/env/ptw_source_sb.svh reason=abort_outstanding_full_matrix_missing next=add_late_data_abort_bus_error_old_exception_drop_matrix
PTW_SIGNOFF_OPEN id=PTW-FLOW-022 owner=mmu_verification/testbench/top/tb_top.sv reason=pmp_update_clear_probe_gap next=connect_pmp_regs_update_and_run_clear_only_no_flush_test
PTW_SIGNOFF_OPEN id=PTW-FLOW-025 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh reason=flag_only_pmp_agent_limits_exact_l1_l2_independent_pmpflg_evidence next=add_independent_l1_l2_page_table_pmpflg_stimulus
PTW_SIGNOFF_OPEN id=PTW-FLOW-026 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh reason=top_source_l2_only_deny_unreachable_under_corrected_mprv_rule next=add_lower_level_l2_only_direct_accerr_evidence
PTW_SIGNOFF_OPEN id=PTW-FLOW-028 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_mmode_lock_matrix_001.svh reason=effective_m_data_pfu_top_source_unreachable_under_corrected_mprv_rule next=add_lower_level_pde_cache_effective_m_lock_bypass_evidence
PTW_SIGNOFF_OPEN id=PTW-INFRA-004 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=pde_subitems_remain_open next=bind_missing_pde_hit_update_clear_victim_covers
PTW_SIGNOFF_OPEN id=PTW-INFRA-005 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=mbuf_subitems_remain_open next=bind_missing_mbuf_single_outstanding_abort_bus_error_covers
PTW_SIGNOFF_OPEN id=PTW-INFRA-006 owner=mmu_verification/testbench/top/mmu_pmp_twu_sva.sv reason=pmp_twu_chk_subitems_remain_open next=bind_level_type_no_side_effect_covers
PTW_SIGNOFF_OPEN id=PTW-INFRA-007 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=maee_degrade_directed_coverage_open next=bind_full_degrade_and_no_lower_walk_covers
PTW_SIGNOFF_OPEN id=PTW-INFRA-008 owner=mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv reason=xbar_arb_subitems_need_final_cover_binding next=bind_remaining_hash_ready_priority_covers
PTW_SIGNOFF_OPEN id=PDE-TP-001 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=fst_nonleaf_update_cover_open next=add_pde_update_condition_cover
PTW_SIGNOFF_OPEN id=PDE-TP-002 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=l1_hit_skip_fst_cover_open next=add_l1_hit_skip_fst_cover
PTW_SIGNOFF_OPEN id=PDE-TP-003 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=l2_hit_skip_fst_scd_cover_open next=add_l2_hit_skip_cover
PTW_SIGNOFF_OPEN id=PDE-TP-004 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=double_hit_l2_wins_cover_open next=add_double_hit_l2_priority_directed_cover
PTW_SIGNOFF_OPEN id=PDE-TP-005 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=leaf_no_update_cover_open next=add_no_update_on_leaf_cover
PTW_SIGNOFF_OPEN id=PDE-TP-006 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=nonleaf_fault_no_update_cover_open next=add_no_update_on_fault_cover
PTW_SIGNOFF_OPEN id=PDE-TP-007 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=bus_error_no_update_cover_open next=add_no_update_on_bus_error_cover
PTW_SIGNOFF_OPEN id=PDE-TP-008 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=abort_returned_nonleaf_no_update_open next=add_abort_no_update_cover
PTW_SIGNOFF_OPEN id=PDE-TP-009 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=lookup_old_state_race_open next=add_lookup_update_race_cover
PTW_SIGNOFF_OPEN id=PDE-TP-010 owner=mmu_verification/testbench/top/tb_top.sv reason=pmp_update_clear_probe_gap next=connect_pmp_regs_update_probe
PTW_SIGNOFF_OPEN id=PDE-TP-011 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=reset_abort_flush_cover_open next=add_reset_abort_flush_cover
PTW_SIGNOFF_OPEN id=PDE-TP-012 owner=mmu_verification/testbench/top/mmu_pde_cache_sva.sv reason=plru_victim_directed_test_open next=add_pde_plru_victim_test
PTW_SIGNOFF_OPEN id=PDE-TP-014 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh reason=flag_only_pmp_agent_limits_exact_l1_deny_construction next=add_independent_l1_l2_cached_pmpflg_stimulus
PTW_SIGNOFF_OPEN id=PDE-TP-015 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh reason=top_source_l2_only_deny_unreachable_under_corrected_mprv_rule next=add_lower_level_l2_only_cached_pmpflg_deny_test
PTW_SIGNOFF_OPEN id=PDE-TP-018 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_pde_mmode_lock_matrix_001.svh reason=effective_m_bit3_matrix_not_top_source_reachable next=add_lower_level_pde_cache_or_rtl_unit_evidence
PTW_SIGNOFF_OPEN id=MBUF-TP-001 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=iutlb_entry8_allocation_cover_open next=add_entry8_alloc_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-002 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=dtlb_pfu_entry0_7_allocation_cover_open next=add_entry0_7_alloc_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-003 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=req_valid_pa_stable_cover_open next=add_req_pa_stable_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-004 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=single_outstanding_no_ooo_cover_open next=add_single_outstanding_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-005 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=normal_data_chk_ready_cover_open next=add_chk_ready_data_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-006 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=chk_not_ready_hold_cover_open next=add_chk_hold_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-007 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=bus_error_no_chk_refill_pde_cover_open next=add_bus_error_no_side_effect_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-008 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=bus_error_priority_cover_open next=add_bus_error_priority_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-009 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=abort_no_outstanding_cover_open next=add_abort_no_outstanding_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-010 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=abort_late_data_drop_cover_open next=add_late_data_drop_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-011 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=abort_bus_error_drop_cover_open next=add_abort_bus_error_drop_cover
PTW_SIGNOFF_OPEN id=MBUF-TP-012 owner=mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv reason=pre_existing_exception_grant_cover_open next=add_preexisting_exception_grant_cover
PTW_SIGNOFF_OPEN id=MAEE-TP-001 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=maee1_1g_raw_attr_cover_open next=add_maee1_1g_cover
PTW_SIGNOFF_OPEN id=MAEE-TP-002 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=maee1_2m_raw_attr_cover_open next=add_maee1_2m_cover
PTW_SIGNOFF_OPEN id=MAEE-TP-003 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=maee1_4k_raw_attr_cover_open next=add_maee1_4k_cover
PTW_SIGNOFF_OPEN id=MAEE-TP-004 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=1g_no_cross_dedicated_test_missing next=add_1g_no_cross_directed
PTW_SIGNOFF_OPEN id=MAEE-TP-005 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=1g_to_2m_directed_test_missing next=add_1g_to_2m_directed
PTW_SIGNOFF_OPEN id=MAEE-TP-006 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=1g_to_4k_directed_test_missing next=add_1g_to_4k_directed
PTW_SIGNOFF_OPEN id=MAEE-TP-007 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=2m_no_cross_dedicated_test_missing next=add_2m_no_cross_directed
PTW_SIGNOFF_OPEN id=MAEE-TP-008 owner=mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh reason=2m_to_4k_directed_test_missing next=add_2m_to_4k_directed
PTW_SIGNOFF_OPEN id=MAEE-TP-010 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=degrade_no_lower_walk_directed_negative_evidence_missing next=add_no_lower_walk_sva_and_directed
PTW_SIGNOFF_OPEN id=MAEE-TP-011 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=misalign_before_degrade_cover_open next=add_huge_align_priority_cover
PTW_SIGNOFF_OPEN id=MAEE-TP-013 owner=mmu_verification/testbench/top/mmu_maee_twu_sva.sv reason=sysmap_flag_order_cover_open next=add_sysmap_flag_order_cover

## Consumer-Only Register

`test_mmu_l1dtlb_dtlb_refill_001`, `test_mmu_l1dtlb_dtlb_mb_pgflt_001`,
`test_mmu_l1dtlb_dtlb_access_fault_source_parity_001`,
`test_mmu_l1dtlb_dtlb_refill_stale_id_001`,
`test_mmu_l1dtlb_dtlb_sysmap_001`, `test_mmu_l1itlb_itlb_pgflt_001`, and
`test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior` are downstream evidence
only.  They can demonstrate L1D/L1I/L2 consumption of PTW-facing refill/fault
effects, but cannot close PTW source-side PTE/PMP/PDE/MAEE/MBUF/abort rules.

## Debug Semantics Frozen

| Item | Frozen Stage 8 interpretation |
| --- | --- |
| LSU bus error | Bus error is reported as visible access fault; legal responder drives `lsu_mmu_data_vld` and bus-error together for bus-error response beats. |
| SysMap mirror | PTW source model uses RTL compile-time SysMap macros/fallback constants unless a real whitebox force path is connected. |
| PFU MPRV/MPP=M | Corrected spec requires PFU direct-map and no PTW source; such cases are consumer-only, and observing a PTW source accept is illegal/unexpected. |
| Data MPRV/MPP=M | Corrected spec requires load/store direct-map VA=PA and no PTW source; this makes old top-level `PTW-ADD-040/043` data constructions unreachable. |
| SATP switch | Process switch must be followed by ASID tlboper invalidation/abort; pre-switch PTW accept is optional debug evidence. |
| TWU vs L1TLB permission | TWU MXR relaxes source refill eligibility for R=0,W=1,X=1,MXR=1; L1TLB hit permission remains stricter and can fault. |
| MAEE=0 degrade | Source model distinguishes installed huge-page entry PPN from final translated PPN expansion and records dedicated degrade tests still open. |

## Exit Gate Command

```bash
python3 mmu_verification/scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list mmu_verification/simu/ptw_p0_smoke_list \
  --p0-list mmu_verification/simu/ptw_p0_list \
  --p1-list mmu_verification/simu/ptw_p1_list \
  --pde-pmpflg-list mmu_verification/simu/ptw_pde_pmpflg_list \
  --p2-list mmu_verification/simu/ptw_p2_illegal_list \
  --random-list mmu_verification/simu/ptw_random_list \
  --consumer-list mmu_verification/simu/ptw_consumer_evidence_list \
  --log-dir mmu_verification/output/logs \
  --p0-seed 606 \
  --p1-seed 606 \
  --stage7-seed 707 \
  --pde-pmpflg-seed 606 \
  --pde-pmpflg-seed 707 \
  --consumer-seed 707 \
  --csv mmu_verification/simu/ptw_source_closure_matrix.csv \
  --report doc/ptw_uvm_review/ptw_source_signoff_report.md \
  --legacy doc/ptw_uvm_review/ptw_legacy_test_action_list.md
```
