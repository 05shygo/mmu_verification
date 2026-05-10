# L1DTLB 3.9/3.10 UVM Traceability

This file tracks implementation status for `l1dtlb_function_description.md`
sections 3.9 and 3.10.  It is intentionally conservative: a row is `implemented`
only when there is a named SVA, scoreboard check, coverage point, or directed
scenario that checks the required behavior rather than only carrying the test
name.

## Status Legend

| Status | Meaning |
| --- | --- |
| implemented | Implemented with concrete SVA, scoreboard check, cover, or directed stimulus. |
| partial | Some checks/stimulus exist, but the row is not fully proven. |
| planned | Wrapper or intent exists, but concrete semantic checking/stimulus is still needed. |
| formal-only | The requirement needs equivalence/formal setup or additional controllable probes. |

## Key Implementation Files

| Area | File |
| --- | --- |
| SVA binds | `mmu_verification/testbench/top/tb_top.sv` |
| L1DTLB SVA | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| Directed vseq | `mmu_verification/testbench/env/mmu_l1dtlb_vseq_lib.svh` |
| Spec scoreboard | `mmu_verification/testbench/env/mmu_l1dtlb_spec_sb.svh` |
| Whitebox covergroup | `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh` |
| Wrapper suite | `mmu_verification/testbench/test/l1dtlb_tests/l1dtlb_tests_suite.svh` |

## 3.9 Assert SVA Matrix

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

## 3.9 Cover Property Matrix

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

## 3.10 Scenario Matrix

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
