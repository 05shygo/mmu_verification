# Phase 6 (B) Completion Pack

## Scope

- Owner: Engineer B
- Phase: 6 (`misc_agent` 完善 + TLB 失效 + Invalidate SB)
- Status: Code implementation completed; runtime regression pending EDA environment (`vcs` unavailable locally).

## Delivered Files

- `mmu_verification/testbench/lsu_agent/lsu_driver.svh`
- `mmu_verification/testbench/lsu_agent/lsu_sequences.svh`
- `mmu_verification/testbench/env/mmu_invalidate_sb.svh` (new)
- `mmu_verification/testbench/env/mmu_env_pkg.sv`
- `mmu_verification/testbench/env/mmu_env.svh`
- `mmu_verification/testbench/test/basic_tests/test_mmu_invalidate_sfence_matrix.svh` (new)
- `mmu_verification/testbench/test/basic_tests/test_mmu_phase6_misc_inv_smoke.svh` (new)
- `mmu_verification/testbench/test/test_pkg.sv`
- `mmu_verification/Makefile`
- `doc/phase6_b_stage0_baseline.md` (new)

## How To Run (when `vcs` is available)

From `mmu_verification/`:

- `make phase6_fast`
- `make phase6`
- `make phase6_check`

Matrix defaults:

- Modes: `INV_MODE=0 1 2 3`
- Seeds: `61001 61002 61003`
- Count: `INV_NUM=100`

## Expected Exit Criteria

- 12 logs total (`4 modes x 3 seeds`)
- each log: `UVM_ERROR: 0` and `UVM_FATAL: 0`
- each log contains invalidate summary with:
  - `N_invalidations > 0`
  - `mismatch = 0`

## Stage5 A/B Joint Smoke

- test: `test_mmu_phase6_misc_inv_smoke`
- purpose: verify misc flush/expt path does not conflict with invalidation path.

## Known Blocker

- Local shell does not provide `vcs`; compile/run cannot be executed in this environment.
