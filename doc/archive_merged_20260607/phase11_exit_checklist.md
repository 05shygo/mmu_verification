# Phase 11 Exit Checklist

## B-owned deliverables created

- `mmu_verification/testbench/test/bug_hunt_tests/` wrappers and suite
- `mmu_verification/testbench/test/ptw_lsu_protocol_tests/` wrappers and suite
- `mmu_verification/simu/mmu_bug_hunt_list`
- `mmu_verification/simu/mmu_ptw_lsu_protocol_list`
- `mmu_verification/simu/mmu_v3_regression_list`
- `doc/phase11_b_stage_manifest.csv`
- `doc/phase11_bug_hunt_matrix.md`
- `doc/phase11_r19_gate.md`
- `doc/phase11_bug015_doc_review.md`

## Recommended execution commands

- bug-hunt list:
  - `make regress LIST=simu/mmu_bug_hunt_list REGRESS_MODE=run_check REGRESS_SEEDS="94001"`
- protocol list:
  - `make regress LIST=simu/mmu_ptw_lsu_protocol_list REGRESS_MODE=run_check REGRESS_SEEDS="94101 94102 94103"`
- v3 union:
  - `make regress LIST=simu/mmu_v3_regression_list REGRESS_MODE=run_cov REGRESS_SEEDS="94201 94202 94203"`
- R20 focused seeds:
  - `make run_cov TEST_NAME=test_bug_013_ptw_write_pipe_reset SEED=<94301..94310>`
  - `make run_cov TEST_NAME=test_bug_014_xbar_cold_start SEED=<94301..94310>`

## Remaining A-side integration items

- add `regress_v3_gap` target or equivalent wrapper
- add xfail / blocked policy support for `TC-BUG-005~008` and `TC-BUG-011`
- confirm `R20` SVA / covergroup evidence collection path
- integrate `scan_logs.pl` into the final gap-regression entrypoint

## Exit gates

- `TC-BUG-005~008` classified as pass or formally covered by xfail policy
- `R19` closed or `TC-BUG-011` explicitly reclassified
- `TC-BUG-012~014` standalone runs collected
- all 5 `tc_pmbuf_*` protocol tests run with the agreed 3-seed set
- `mmu_v3_regression_list` executed with the agreed seed set
- `TC-BUG-015` document review closed in writing
