# PTW Source Closure Matrix - Stage 10 Frozen Baseline

This file began as the stage-0 closure baseline for the PTW source-side work.
Stage 10 now freezes the additional PDE-cache pmpflg mapping from
`ptw_pde_cache_pmpflg_design_change.md`. The machine-readable source remains
`mmu_verification/simu/ptw_source_closure_matrix.csv`; this file records the
manual review summary and the rules that must not be lost during signoff.

Authoritative inputs:

| Input | Usage |
| --- | --- |
| `doc/ptw_uvm_review/ptwspec.md` | Functional truth. If any old test or plan conflicts with this file, the old expected result is obsolete. |
| `doc/ptw_uvm_review/ptw_phase1_test_sva_implementation_plan.md` | Detailed task library for tests, SVA, source model, monitor, and scoreboard. |
| `doc/ptw_uvm_review/ptw_staged_implementation_plan.md` | Stage boundary and exit criteria. This file only implements stage 0. |
| `doc/MMU_Traceability_Matrix.csv` and current UVM tests | Legacy mapping input only. They do not override `ptwspec.md`. |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_design_change.md` | Frozen PDE-cache pmpflg behavior and corrected MPRV/source reachability. |

## Stage-0 Terms

| Term | Frozen meaning |
| --- | --- |
| PTW source-side | Evidence produced from PTW request, walk, PTE/PMP/PDE/MBUF/MAEE/refill/fault/drop source transactions, source SVA, or `ptw_source_ref_model + ptw_source_sb`. |
| consumer-only | Evidence from L1DTLB/L1ITLB/L2TLB/translation scoreboard after PTW output is consumed. It can support closure but cannot replace PTW source-side evidence. |
| auxiliary | Useful debug or end-to-end evidence that is not sufficient for source-side signoff. |
| provisional | Monitor-only or smoke evidence before source scoreboard and SVA cover are available. It cannot close P0/P1 requirements. |
| illegal stimulus | Stimulus outside the constrained legal PTW input space. It must not be counted as normal DUT fail or normal requirement closure. |
| open | A requirement mapped to planned checks but not yet closed by source-side evidence. This is the normal stage-0 state. |
| waived | A requirement intentionally not closed, with an explicit waiver or open reason. No waiver is created in stage 0. |
| obsolete-by-spec | A legacy expected result conflicts with `ptwspec.md`; it must not be used as PTW closure. |

## Default Illegal Or Constrained Inputs

The following inputs are frozen as illegal or constrained for normal PTW regression. A negative/stress test may inject them only when the scenario metadata and report explicitly mark `illegal_stimulus=1`.

| Input | Stage-0 rule |
| --- | --- |
| Bare mode request enters PTW | Constrained away for normal tests; if observed, do not use as PTW functional closure. |
| Pure M-mode or data/PFU `MPRV=1 && MPP=M` no-translation request enters PTW | Constrained away for normal tests. `MPRV=1 && MPP=M` data/PFU requests direct-map VA=PA and are not legal PTW source traffic. |
| sysmap no-hit or multi-hit | Not a normal PTW source expected; default/no-hit implementation-only tests must not close MAEE/degrade requirements unless explicitly waived. |
| Same `{type,id}` reused before completion/drop | Illegal for normal PTW source matching. |
| PTW memory out-of-order response or no-pending response | Illegal for normal PTW memory responder. PTW LSU channel is single outstanding. |
| satp.asid/satp.ppn mid-walk change without abort | Constrained away by default unless a dedicated context sampling test declares the ordering model. |

## Audit Closure Matrix

Stage-0 status is intentionally `open` for source evidence. The closure point is frozen here so later stages cannot close a row with the wrong checker.

| Audit ID | Source rule | Bound requirement IDs | Planned source checker / SVA evidence | Legacy/current evidence and action | Stage-0 state |
| --- | --- | --- | --- | --- | --- |
| `PTW-AUD-001` | RSW, high reserved, and strong-order-like bits do not create PTW page fault; RSW enters refill `flg[8:7]`. | `PTW-ADD-001/002/034` | `ptw_source_sb` no-fault and flg compare; `PTW-SVA-CHK-009`, `PTW-SVA-ARB-008`. | `test_pte_reserved_bits` must be modified from fault expected to no-fault/layout expected. | open |
| `PTW-AUD-002` | Raw G bit only produces tag/global; G never enters data flg and non-leaf G is not ORed downward. | `PTW-ADD-003/034` | Refill tag/data bit-exact compare; `PTW-SVA-CHK-010`, `PTW-SVA-ARB-008`. | `test_pte_global_bit_asid` must be split into leaf global, non-leaf no-OR, and G-not-in-flg checks. | open |
| `PTW-AUD-003` | Request type controls success target: fetch to L1ITLB+L2TLB, load/store to L1DTLB+L2TLB, PFU to L2TLB only. | `PTW-ADD-004`, `PTW-FLOW-020` | Source completion target compare; `PTW-SVA-ARB-004/005/007`, `L1D-SVA-PTW-001` as consumer auxiliary. | Current success smokes are consumer-heavy and need source target compare. | open |
| `PTW-AUD-004` | Fault completion preserves original type/id; PFU and IUTLB fault routing follow spec. | `PTW-ADD-005/006`, `PTW-FLOW-021` | Source fault key/class compare; `PTW-SVA-ARB-004/006`, source monitor must not use `ptw_l2tlb_cmplt` alone. | L1DTLB fault tests are consumer-only; add source fault target evidence. | open |
| `PTW-AUD-005` | PDE cache miss/L1 hit/L2 hit/double-hit behavior; double hit chooses L2. | `PTW-ADD-007`, `PTW-FLOW-015/016/017`, `PDE-TP-001..004` | PDE event monitor plus `PTW-SVA-PDE-003/004/005`; source memory request absence for skipped levels. | Existing PDE hit tests are smoke and must add skip-level proof. | open |
| `PTW-AUD-006` | PDE update condition and lookup/update timing. | `PTW-ADD-008/009`, `PDE-TP-005..009/012` | PDE update/drop event compare; `PTW-SVA-PDE-006/007/008/009`. | Existing PDE timing items map here but remain weak until probe/SVA. | open |
| `PTW-AUD-007` | reset, satp change, PMP update, and abort have different clear/flush semantics. | `PTW-ADD-010/011/024`, `PTW-FLOW-022`, `PDE-TP-010/011`, `MBUF-TP-009..012` | Drop/clear monitor, PDE clear source, abort/refill SVA: `PTW-SVA-PDE-001/002/010`, `PTW-SVA-CTX-003..005`. | `test_satp_switch_during_walk` and `test_sfence_abort_walk` must be split by clear-only versus abort flush. | open |
| `PTW-AUD-008` | Xbar uses VPN hash/target mask/ready hold rules, not old round-robin closure. | `PTW-ADD-012` | Request accept monitor; `PTW-SVA-REQ-001..003`, `PTW-SVA-XBAR-001..006`. | `test_xbar_twu_round_robin` and round-robin plan rows are obsolete-by-spec for PTW closure. | open |
| `PTW-AUD-009` | PMP checks the physical address of the PTE read and deny terminates without side effects. | `PTW-ADD-013`, `PTW-FLOW-009/010/011` | PTE PA/PMP deny source trace; no mbuf/LSU/CHK/refill/PDE side-effect checks; `PTW-SVA-PMP-001..004/008/009`. | Existing PMP/TWU tests need level/type and no-side-effect binding. | open |
| `PTW-AUD-010` | PMP permission uses original request type: fetch X, load/PFU R, store W. | `PTW-ADD-014` | PMP type permission compare; `PTW-SVA-PMP-005/006`. | Tests that model all PTW PTE reads as load-only must be modified. | open |
| `PTW-AUD-011` | MPRV/MPP affects data effective privilege; `MPRV=1 && MPP=M` data/PFU direct-map and do not enter PTW; fetch ignores MPRV. | `PTW-ADD-015/030/036`, `PTW-FLOW-023` | Source monitor illegal-accept guard for data/PFU MPRV=1 MPP=M; consumer direct-map sanity; fetch source checks use real privilege. | M-mode/direct-map L1DTLB tests are consumer/system tests, not PTW source closure. | open |
| `PTW-AUD-012` | Non-leaf PTE page fault rules by level. | `PTW-ADD-016`, `PTW-FLOW-012/013/014` | Raw PTE level trace plus source page-fault compare; `PTW-SVA-CHK-001/002/011`. | `test_pte_rw_both_zero` needs expected corrected to design write-only/non-leaf rules. | open |
| `PTW-AUD-013` | Leaf PTE permission matrix, including PFU special rules. | `PTW-ADD-017/018/019/033`, `PTW-FLOW-020/021` | Source page-fault/refill expected formulas; `PTW-SVA-CHK-003..007`. | Current PTE permission tests must be split by fetch/load/store/PFU and A/D/U/S/SUM. | open |
| `PTW-AUD-014` | Huge page PPN alignment fault has priority over MAEE/sysmap/degrade. | `PTW-ADD-020`, `MAEE-TP-011` | Page fault with no sysmap/degrade/refill/lower-walk; `PTW-SVA-CHK-008`, `PTW-SVA-MAEE-008`. | Existing misaligned and sysmap align tests need priority check, not only final fault. | open |
| `PTW-AUD-015` | MBUF entry allocation and PTW-to-LSU single outstanding behavior. | `PTW-ADD-021`, `MBUF-TP-001..004` | MBUF monitor/SVA for entry8 versus entry0-7, req/PA stable, no OOO; `PTW-SVA-MBUF-001..005`. | `test_mbuf_ooo_response` is illegal/obsolete for normal PTW closure. | open |
| `PTW-AUD-016` | CHK not-ready hold and LSU bus error behavior. | `PTW-ADD-022/023`, `PTW-FLOW-018`, `MBUF-TP-005..008` | MBUF data/get/bus-error source trace; `PTW-SVA-MBUF-006..009`, `PTW-SVA-ARB-001/002`. | `test_bus_error_terminate` keeps stimulus but expected must be access fault/no CHK/no PDE update. | open |
| `PTW-AUD-017` | Abort LSU outstanding boundary. | `PTW-ADD-024`, `PTW-FLOW-019`, `MBUF-TP-009..012` | Drop/no-stale-output source sb; `PTW-SVA-MBUF-010..012`, `PTW-SVA-ARB-003`, `PTW-SVA-CTX-004/005`. | `test_sfence_abort_walk` and TLBOp abort tests must be split by req/data/bus-error/old-exception windows. | open |
| `PTW-AUD-018` | MAEE=1 uses raw PTE extension attributes for 1G/2M/4K. | `PTW-ADD-025`, `MAEE-TP-001..003` | Refill flg compare; `PTW-SVA-MAEE-001/003`. | MAEE direct refill tests must cover all page sizes. | open |
| `PTW-AUD-019` | MAEE=0 4K leaf also uses sysmap attributes. | `PTW-ADD-026`, `PTW-FLOW-008`, `MAEE-TP-009/013` | THD/4K source trace and refill flg compare; `PTW-SVA-MAEE-002/004`. | Existing MAEE SVA/tests were FST/SCD heavy; add THD/4K binding later. | open |
| `PTW-AUD-020` | MAEE=0 1G/2M no-cross and degrade rules, with no lower page-table access. | `PTW-ADD-027/028/029`, `PTW-FLOW-004..007`, `MAEE-TP-004..010/012/013` | Final page_size/PPN/flg compare and no-lower-walk proof; `PTW-SVA-MAEE-004..007/009/010`. | Phase13 sysmap degrade tests are retained only after source-side MAEE/degrade checks are added. | open |
| `PTW-AUD-021` | Context sampling points for ASID, MXR, SUM, privilege, MPRV/MPP, and MAEE. | `PTW-ADD-030`, `PTW-FLOW-023`, `MAEE-TP-012` | Context sample transaction with cycle ordering; `PTW-SVA-ARB-009`, `PTW-SVA-CTX-006`. | Hot-switch tests are provisional until ordering is represented in source ref/sb. | open |
| `PTW-AUD-022` | The 23 full PTW flows in `ptwspec.md` chapter 12. | `PTW-ADD-031`, `PTW-FLOW-001..023` | Each flow needs source sb match/drop and at least one source SVA/cover hit. | No legacy full-flow row closes this alone; build dedicated flow closure in later stages. | open |
| `PTW-AUD-023` | L1DTLB consumer-side evidence for PTW outputs. | `PTW-ADD-032` | Source target compare remains required; L1DTLB/L1ITLB/L2TLB checks are auxiliary. | L1DTLB tests may be referenced as `consumer-only`, never as PTE/PMP/PDE/MAEE source closure. | consumer-only auxiliary |

## Stage-10 PDE PMPFLG Closure Addendum

The following rows are frozen in
`mmu_verification/simu/ptw_source_closure_matrix.csv` and are checked by
`mmu_verification/scripts/ptw_stage8_signoff_gate.py`.

| ID | Test | Source/SVA evidence | Stage-10 status |
| --- | --- | --- | --- |
| `PTW-ADD-037` / `PDE-TP-013` / `PTW-FLOW-024` | `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001` | `PTW_SOURCE_SB_PDE_PMP_COVERAGE.l1_deny_miss`, `PTW-SVA-PDE-011` | closed after pde-pmpflg list pass |
| `PTW-ADD-038` / `PTW-FLOW-027` | `test_ptw_pde_l1_pmp_tag_allow_reuse_001` | `l1_allow`, `PTW-SVA-PDE-011` | closed after pde-pmpflg list pass |
| `PTW-ADD-039` / `PDE-TP-014` / `PTW-FLOW-025` | `test_ptw_pde_l2_pmp_l1_deny_accerr_001` | direct accerr, `no_extra_lsu`, `PTW-SVA-PDE-012/013/016` | partial; flag-only PMP agent limits independent FST/SCD pmpflg construction |
| `PTW-ADD-040` / `PDE-TP-015` / `PTW-FLOW-026` | `test_ptw_pde_l2_pmp_l2_deny_accerr_001` | explicit open/unreachable marker only | open; corrected `MPRV=1 && MPP=M` data source does not enter PTW |
| `PTW-ADD-041` / `PDE-TP-016` | `test_ptw_pde_pmpflg_propagation_update_001` | `update_l1/update_l2`, `PTW-SVA-PDE-015` | closed after pde-pmpflg list pass |
| `PTW-ADD-042` / `PDE-TP-017` | `test_ptw_pde_accerr_priority_type_id_001` | direct accerr type/id, `PTW-SVA-PDE-017`, `PTW-SVA-ARB-010` | closed after pde-pmpflg list pass |
| `PTW-ADD-043` / `PDE-TP-018` / `PTW-FLOW-028` | `test_ptw_pde_mmode_lock_matrix_001` | explicit open/unreachable marker only | open; data/PFU effective-M source is direct-map and fetch ignores MPRV/MPP |
| `PTW-ADD-044` / `PDE-TP-019` | `test_ptw_pde_l2_accerr_valid_gate_001` | request-scoped no false direct accerr, `PTW-SVA-PDE-014` | closed after pde-pmpflg list pass |
| `PTW-ADD-045` / `PDE-TP-010/016` | `test_ptw_pde_pmp_clear_repopulate_001` | clear/repopulate source evidence, `PTW-SVA-PDE-001/015` | partial; exact PMP-config-update clear remains blocked by `pmp_regs_update` tie-off |

No Stage-10 waiver is created for these open/partial rows. They are explicit
reachability or testbench-observability limits and must remain visible in the
signoff report.

## Stage-0 Completion Record

```text
PTW_STAGE_DONE stage=0 name=Spec Baseline Traceability Freeze
  status=done
  commit_or_patch=working-tree
  changed_files=[
    doc/ptw_uvm_review/ptw_source_closure_matrix.md,
    mmu_verification/simu/ptw_source_closure_matrix.csv,
    doc/ptw_uvm_review/ptw_legacy_test_action_list.md,
    doc/ptw_uvm_review/ptw_id_coverage_audit.md
  ]
  tests_run=[document/CSV consistency checks only]
  source_sb_summary=not-applicable-stage0
  sva_summary=not-applicable-stage0
  closure_delta=[
    PTW-AUD-001..023,
    PTW-ADD-001..036,
    PTW-INFRA-001..009,
    PTW-FLOW-001..023,
    PDE-TP-001..012,
    MBUF-TP-001..012,
    MAEE-TP-001..013
  ]
  open_items=[
    source monitor/ref/sb/SVA implementation starts in later stages,
    legacy tests listed in ptw_legacy_test_action_list.md still need code patches in later stages
  ]
  next_stage_blockers=[]
```
