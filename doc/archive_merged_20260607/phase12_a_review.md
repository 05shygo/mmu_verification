# Phase 12 A Review Note

## Scope

- Reviewed Phase 12 A-side integration files:
  - `mmu_verification/testbench/top/mmu_maee_twu_sva.sv`
  - `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv`
  - `mmu_verification/testbench/top/tb_top.sv`
  - `mmu_verification/testbench/Files.f`
  - `mmu_verification/Makefile`
- Reviewed reused bound SVA families that remain active during the Phase 12 union:
  - `mmu_twu_sva`
  - `mmu_arb_sva`
  - `mmu_ptw_lsu_protocol_sva`

## MAEE SVA Final Naming

| BuildPlan / legacy wording | Final implemented name | Cover property |
| --- | --- | --- |
| MAEE path mutex | `sva_twu_maee_paths_mutex` | `cp_twu_maee_paths_mutex` |
| MAEE=0 leaf uses CSR path | `sva_maee0_triggers_csr_req` | `cp_maee0_triggers_csr_req` |
| MAEE=1 leaf skips CSR FSM | `sva_maee1_skips_csr_fsm` | `cp_maee1_skips_csr_fsm` |

## Probe And Sampling Conclusion

- Phase 12 MAEE SVA samples the `twu` bind points that are already exposed in RTL.
- The implemented MAEE leaf-path checks are intentionally limited to `FST/SCD`.
- `THD` is not included in the MAEE CSR-path assertion pair in this batch because the current RTL does not expose a matching `thd_chk_csr_req` signal.
- `mmu_maee_twu_sva.sv` now prints deterministic `PHASE12_MAEE_COVER ... hits=<N>` lines at end-of-run so the Phase 12 exit gate can aggregate hit counts across the 3-seed union.

## Existing SVA Reuse Conclusion

- `tb_top.sv` keeps `mmu_twu_sva`, `mmu_arb_sva`, and `mmu_ptw_lsu_protocol_sva` bound during Phase 12 runs.
- No new dedicated Phase 12 bind point is required for those legacy SVA families.
- Final closure for reused `ptw/twu/xbar/arb` assertions remains log-based:
  - Phase 12 union regression must finish with clean `UVM_ERROR/UVM_FATAL`
  - integrated log scan must report no new assertion / SVA error patterns

## PMP Skeleton Conclusion

- `mmu_pmp_twu_sva.sv` remains a compile-clean skeleton in Phase 12.
- Functional PMP/TWU assertion semantics stay in Phase 13 scope and are not part of Phase 12 closure.

## Closure Record

- A-side static deliverables are in place for the final Phase 12 gate.
- Final Phase 12 sign-off still depends on runtime evidence from:
  - compile log
  - `mmu_v4_phase12_list` 3-seed summary
  - MAEE cover hit aggregation
  - URG covergroup report
