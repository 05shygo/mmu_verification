# §6.3 baseline TC extract

筛选口径：
- 来源仅限 `doc/MMU_VerificationPlan_final.md` 的 §6.3 TC 表。
- 仅保留未来落入 `l1dtlb_tests` / `l2tlb_tests` / `tlbop_tests` 的 baseline TC。
- 已按唯一 `TC-ID` 去重。
- 默认 reviewer=`B`；涉及明显参考模型精确比对/精确失效语义的条目标为 `A+B`。
- 已排除：ITLB-only、PTW/ARB、SysMap/PMP/CSR、`bug_hunt`、`ptw_lsu_protocol`、`pmp_v7`、`v4` 扩展、stress/top-level/gap 项。

| tc_id | tc_name | seq | target_dir | reviewer |
| --- | --- | --- | --- | --- |
| DTLB_HIT_001 | sanity | `lsu_base_seq` Pipe0 + 4K page table | `l1dtlb_tests` | B |
| DTLB_HIT_002 | sanity | `lsu_base_seq` Pipe1 + 4K page table | `l1dtlb_tests` | B |
| DTLB_CONCURRENT_001 | directed | Pipe0/1 same-cycle hit (same VPN / different VPN) | `l1dtlb_tests` | B |
| DTLB_CONCURRENT_002 | random | `lsu_pipe01_concurrent_seq` x 100 seed | `l1dtlb_tests` | B |
| DTLB_ALLOC_001 | directed | 16 VPN miss -> MB allocate -> refill | `l1dtlb_tests` | B |
| DTLB_PLRU_001 | directed | MB_DEPTH=8 LRU replace | `l1dtlb_tests` | B |
| DTLB_MB_001 | directed | 8 concurrent miss requests | `l1dtlb_tests` | B |
| DTLB_MB_002 | random | `mmu_ptw_thrash_vseq` (8 MB full) x 50 seed | `l1dtlb_tests` | B |
| DTLB_CREDIT_001 | directed | credit=0 delayed new miss | `l1dtlb_tests` | B |
| DTLB_CREDIT_002 | random | Pipe0/1 credit fairness | `l1dtlb_tests` | B |
| DTLB_PERM_LD_001 | directed | load to R=0 page | `l1dtlb_tests` | B |
| DTLB_PERM_LD_002 | directed | load + MXR=1 to X=1/R=0 page | `l1dtlb_tests` | B |
| DTLB_PERM_ST_001 | directed | store to W=0 page | `l1dtlb_tests` | B |
| DTLB_PERM_ST_002 | directed | store triggers D-bit update | `l1dtlb_tests` | B |
| DTLB_SCHED_001 | directed | Pipe0/1 credit scheduling | `l1dtlb_tests` | B |
| DTLB_ABORT_001 | directed | LSU abort -> no TLB pollution | `l1dtlb_tests` | B |
| DTLB_REFILL_001 | directed | invalid -> L2 miss -> refill | `l1dtlb_tests` | B |
| DTLB_REFILL_002 | random | `mmu_concurrent_3pipe_vseq` x 50 seed | `l1dtlb_tests` | B |
| DTLB_INV_001 | directed | SFENCE.VMA INV_ALL | `l1dtlb_tests` | A+B |
| DTLB_INV_002 | directed | SFENCE.VMA INV_VA | `l1dtlb_tests` | A+B |
| DTLB_INV_003 | directed | SFENCE.VMA INV_ASID | `l1dtlb_tests` | A+B |
| DTLB_INV_004 | random | `mmu_sfence_during_walk_vseq` x 50 seed | `l1dtlb_tests` | A+B |
| DTLB_STAMO_001 | directed | STAMO PA notify -> MB non-blocking | `l1dtlb_tests` | B |
| TC-L2TLB-002 | test_mmu_dir_l2tlb_reqq_dtlb_alloc_0 | `lsu_pipe01_concurrent_seq` | `l2tlb_tests` | B |
| TC-L2TLB-003 | test_mmu_dir_l2tlb_reqq_dtlb_alloc_full | `lsu_back2back_seq` x50 cyc | `l2tlb_tests` | B |
| TC-L2TLB-004 | test_mmu_dir_l2tlb_reqq_arbitration_itlb_prior | `ifu_random_vaddr_seq` + `lsu_base_seq` | `l2tlb_tests` | B |
| TC-L2TLB-005 | test_mmu_dir_l2tlb_reqq_arbitration_fifo | `lsu_pipe01_concurrent_seq` x multi-seed | `l2tlb_tests` | B |
| TC-L2TLB-006 | test_mmu_rand_l2tlb_reqq_queue_depth_varied | `mmu_concurrent_3pipe_vseq` | `l2tlb_tests` | B |
| TC-L2TLB-007 | test_mmu_dir_l2tlb_reqq_credit_return_hit | constructed L2 hit sequence | `l2tlb_tests` | B |
| TC-L2TLB-008 | test_mmu_dir_l2tlb_reqq_credit_return_refill | `mmu_ptw_thrash_vseq` | `l2tlb_tests` | B |
| TC-L2TLB-009 | test_mmu_dir_l2tlb_reqq_credit_full_no_return | high-frequency miss, all 9 depths full | `l2tlb_tests` | B |
| TC-L2TLB-010 | test_mmu_dir_l2tlb_tag_match_4k_hit | targeted VA hit construction | `l2tlb_tests` | A+B |
| TC-L2TLB-011 | test_mmu_dir_l2tlb_tag_match_2m_1g_huge | `ifu_huge_page_fetch_seq` + `lsu_huge_page_seq` | `l2tlb_tests` | A+B |
| TC-L2TLB-012 | test_mmu_rand_l2tlb_tag_match_cross_asid | `lsu_cross_asid_seq` + VA conflict construction | `l2tlb_tests` | A+B |
| TC-L2TLB-013 | test_mmu_dir_l2tlb_data_read_flags | specific PTE permission combinations | `l2tlb_tests` | A+B |
| TC-L2TLB-014 | test_mmu_rand_l2tlb_data_bank_parallel_read | `mmu_concurrent_3pipe_vseq` + balanced bank hash | `l2tlb_tests` | B |
| TC-RRPV-001 | test_mmu_dir_rrpv_init_value | trigger refill, sample RRPV array | `l2tlb_tests` | B |
| TC-RRPV-002 | test_mmu_dir_rrpv_init_max_value_boundary | age to MAX then miss | `l2tlb_tests` | B |
| TC-RRPV-003 | test_mmu_rand_rrpv_init_all_ways_varied | quick bank fill-up | `l2tlb_tests` | B |
| TC-RRPV-004 | test_mmu_dir_rrpv_hit_promote_to_zero | targeted way hit via VPN construction | `l2tlb_tests` | B |
| TC-RRPV-005 | test_mmu_dir_rrpv_multiple_hits_same_vpn | `lsu_pipe01_concurrent_seq` same VPN | `l2tlb_tests` | B |
| TC-RRPV-006 | test_mmu_rand_rrpv_hit_promote_coverage | `mmu_rrpv_aging_vseq` | `l2tlb_tests` | B |
| TC-RRPV-007 | test_mmu_dir_rrpv_aging_miss_increment_all | construct miss, sample RRPV | `l2tlb_tests` | B |
| TC-RRPV-008 | test_mmu_dir_rrpv_aging_saturation_at_max | age to MAX then miss | `l2tlb_tests` | B |
| TC-RRPV-009 | test_mmu_dir_rrpv_aging_mixed_hit_miss | `mmu_rrpv_aging_vseq` | `l2tlb_tests` | B |
| TC-RRPV-010 | test_mmu_dir_rrpv_victim_selection_first_free | refill with all different VPNs | `l2tlb_tests` | B |
| TC-RRPV-011 | test_mmu_dir_rrpv_victim_selection_max_rrpv | bank full (8 ways), then miss | `l2tlb_tests` | B |
| TC-RRPV-012 | test_mmu_rand_rrpv_victim_all_scenarios | `mmu_l2tlb_bank_conflict_vseq` | `l2tlb_tests` | B |
| TC-RRPV-013 | test_mmu_dir_rrpv_wbuf_latency | sample wbuf valid/data | `l2tlb_tests` | B |
| TC-RRPV-014 | test_mmu_rand_rrpv_wbuf_no_overflow | high-frequency same-bank access | `l2tlb_tests` | B |
| TC-BANK-001 | test_mmu_dir_l2tlb_bank_skew_distribution | targeted VPN set, observe 8 indices | `l2tlb_tests` | B |
| TC-BANK-002 | test_mmu_rand_l2tlb_bank_load_balance | `mmu_concurrent_3pipe_vseq` x many cyc | `l2tlb_tests` | B |
| TC-BANK-003 | test_mmu_rand_l2tlb_bank_collision_avoidance | `mmu_ptw_thrash_vseq` + stats | `l2tlb_tests` | B |
| TC-BANK-004 | test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior | PTW refill + ReqQ lookup | `l2tlb_tests` | B |
| TC-BANK-005 | test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior | SFENCE + pending ReqQ | `l2tlb_tests` | B |
| TC-BANK-006 | test_mmu_rand_l2tlb_bank_conflict_multi_source | `mmu_l2tlb_bank_conflict_vseq` | `l2tlb_tests` | B |
| TC-MB-001 | test_mmu_dir_l2tlb_mb_alloc_on_miss | trigger refill | `l2tlb_tests` | B |
| TC-MB-002 | test_mmu_dir_l2tlb_mb_dealloc_on_complete | wait for PTW completion | `l2tlb_tests` | B |
| TC-MB-003 | test_mmu_dir_l2tlb_mb_dup_alloc_prevention | repeated same-VA burst | `l2tlb_tests` | B |
| TC-MB-004 | test_mmu_dir_l2tlb_mb_full_stall | 8 different VAs pending together | `l2tlb_tests` | B |
| TC-MB-005 | test_mmu_rand_l2tlb_mb_issue_order | `mmu_ptw_thrash_vseq` | `l2tlb_tests` | B |
| TC-INV-001 | test_mmu_dir_l2tlb_inv_all | SFENCE.VMA with INV_ALL semantics | `l2tlb_tests` | A+B |
| TC-INV-002 | test_mmu_dir_l2tlb_inv_va | SFENCE.VMA with VA, no ASID | `l2tlb_tests` | A+B |
| TC-INV-003 | test_mmu_dir_l2tlb_inv_asid | SFENCE.VMA with ASID, no VA | `l2tlb_tests` | A+B |
| TC-INV-004 | test_mmu_dir_l2tlb_inv_va_asid | SFENCE.VMA with both VA+ASID | `l2tlb_tests` | A+B |
| TC-SFENCE-001 | test_mmu_sfence_inv_all | `tlb_inv_all_seq` | `tlbop_tests` | B |
| TC-SFENCE-002 | test_mmu_sfence_inv_all_lsu | `tlb_inv_all_seq` | `tlbop_tests` | B |
| TC-SFENCE-003 | test_mmu_sfence_inv_va | `tlb_inv_va_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-004 | test_mmu_sfence_inv_va_precise | `tlb_inv_va_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-005 | test_mmu_sfence_inv_asid | `tlb_inv_asid_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-006 | test_mmu_sfence_inv_asid_global_skip | `tlb_inv_asid_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-007 | test_mmu_sfence_inv_va_asid | `tlb_inv_va_asid_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-008 | test_mmu_sfence_inv_va_asid_multi_asid | `tlb_inv_va_asid_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-009 | test_mmu_sfence_global_persist_invall | `tlb_inv_all_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-010 | test_mmu_sfence_global_va_affected | `tlb_inv_va_seq` | `tlbop_tests` | A+B |
| TC-SFENCE-011 | test_mmu_sfence_lsu_trigger | `tlb_inv_all_seq` + `tlb_inv_va_seq` | `tlbop_tests` | B |
| TC-SFENCE-012 | test_mmu_sfence_lsu_done_handshake | `tlb_inv_all_seq` | `tlbop_tests` | B |
| TC-SFENCE-013 | test_mmu_sfence_cp0_trigger | cp0_agent initiated | `tlbop_tests` | B |
| TC-SFENCE-014 | test_mmu_sfence_concurrent_access_stall | `sfence_vma_stress_seq` | `tlbop_tests` | B |
| TC-SFENCE-015 | test_mmu_sfence_back2back | `sfence_vma_stress_seq` | `tlbop_tests` | B |
| TC-SFENCE-016 | test_mmu_sfence_during_walk | `tlb_inv_during_walk_seq` | `tlbop_tests` | B |
| TC-SFENCE-017 | test_mmu_sfence_refill_conflict | `tlb_inv_all_seq` + `ptw_mem_normal_rsp_seq` mixed | `tlbop_tests` | A+B |
| TC-TLBP-001 | test_mmu_tlbp_query_hit | cp0_agent initiated TLBP request | `tlbop_tests` | A+B |
| TC-TLBP-002 | test_mmu_tlbp_query_miss | cp0_agent initiated TLBP request | `tlbop_tests` | A+B |
| TC-TLBR-001 | test_mmu_tlbr_read_entry | cp0_agent initiated TLBR request | `tlbop_tests` | A+B |
| TC-TLBR-002 | test_mmu_tlbr_all_fields | cp0_agent initiated TLBR request | `tlbop_tests` | A+B |
| TC-TLBWI-001 | test_mmu_tlbwi_write_entry | cp0_agent initiated TLBWI request | `tlbop_tests` | A+B |
| TC-TLBWI-002 | test_mmu_tlbwi_overwrite | cp0_agent initiated multi-write TLBWI | `tlbop_tests` | A+B |
| TC-TLBWR-001 | test_mmu_tlbwr_random_replace | cp0_agent initiated TLBWR request | `tlbop_tests` | A+B |
| TC-TLBWR-002 | test_mmu_tlbwr_rrpv_policy | `cp0_agent` + `ptw_mem_agent` coordinated | `tlbop_tests` | A+B |
