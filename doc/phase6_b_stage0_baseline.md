# Phase 6 (B) Stage0 Baseline

## Scope Lock (B-only)

- Implement and validate `lsu_driver` invalidate sub-thread (`LSU_INV` path).
- Finalize invalidate stimulus library in `lsu_sequences`.
- Implement `mmu_invalidate_sb` and wire it in `mmu_env`.
- Keep Phase 7 items out of scope (no new SVA/CG implementation here).

## Current Code Baseline

- `lsu_driver._drive_inv` exists and drives 4 invalidation strobes.
- `lsu_monitor.ap_inv` exists and publishes invalidate transactions.
- `cp0_monitor.ap` already publishes `CP0_TLB_ALL_INV` done events.
- `mmu_env` has only a placeholder comment for invalidate scoreboard wiring.
- `mmu_invalidate_sb.svh` does not exist yet.

## Dataflow Readiness Check

- `lsu_monitor.ap_inv -> invalidate_sb.af_inv`: **missing**
- `cp0_monitor.ap -> invalidate_sb.af_cp0`: **missing**
- `lsu_monitor.ap_inv -> m_ref.af_tlb_inv`: **missing** in current env connect
- `cp0_monitor.ap -> m_ref.af_csr_write`: **already connected**

## A-side Dependency Gate

- `misc_driver` already supports `MISC_RTU_FLUSH` and `MISC_RTU_EXPT`.
- `misc_monitor` already samples `hpcp_mmu_cnt_en` with HPCP miss observations.
- Stage 3+ regression can proceed; Stage 5 will add explicit misc+inv joint smoke.

## Open Items Before Regression Matrix

- Add `mmu_invalidate_sb` implementation and package include.
- Add env build/connect logic for invalidate scoreboard and ref-model invalidation feed.
- Add Phase 6 dedicated test entry with mode-selectable SFENCE matrix execution.
