# MMU Phase 14 Closure Owner Policy

Date: 2026-05-02
Scope: Phase 14 full regression closure and signoff

## Role Change

Phase 14 is a closure phase, not a large parallel development phase. Starting
with Phase 14, A/B execution roles are merged into **Phase14 Closure Owner**.

Historical A-side / B-side ownership remains valid for traceability and review
context. New Phase 14 work is classified by module or closure area, not assigned
through A/B handoff.

## Closure Owner Responsibilities

- Run full / quasi-full regression.
- Analyze fail logs.
- Fix testcase / covergroup / list issues.
- Fix Makefile / gate / URG fallback issues.
- Maintain `doc/MMU_Phase14_IssueTracker.md` and waiver records.
- Update `doc/MMU_Phase14_SignoffMatrix.md`.
- Archive final Phase 14 results.

## Classification

Phase 14 issues use closure-area labels:

- Regression
- Testcase
- Covergroup
- List
- Makefile/Gate
- URG/Tooling
- Waiver/Signoff
- RTL/Design Record

## Review Policy

- All Phase 14 waiver / signoff decisions require second review.
- Small code, testcase, list, covergroup, Makefile, or gate fixes can be closed
  directly by the Phase14 Closure Owner.
- Any change that affects signoff criteria, coverage thresholds, waiver policy,
  or URG fallback policy must be recorded in `doc/MMU_Phase14_IssueTracker.md`.

## Phase 14 Artifacts

- `mmu_verification/simu/mmu_v4_full_regression_list`
- `mmu_verification/simu/mmu_v4_coverage_merge.sh`
- `mmu_verification/simu/exclude_v4.do`
- `mmu_verification/scripts/phase14_exit_gate.py`
- Makefile targets: `print-phase14`, `regress_v4_full`,
  `regress_v4_full_sharded`, `phase14_coverage_merge`,
  `phase14_coverage_merge_sharded`, `phase14_exit_check`
- `doc/MMU_Phase14_IssueTracker.md`
- `doc/MMU_Phase14_SignoffMatrix.md`

## Current Closure Run Policy

After `MMU-P14-ISSUE-006`, the default closure entry is:

```bash
make phase14_exit_check
```

This target uses the high-parallel test/seed shard VDB flow by default. The
runner creates one shard per testcase/seed by default, uses isolated runtime
VDBs and logs, and treats the compile baseline VDB as a shared clean source only;
each shard restores its private runtime VDB through `run_cov`. Runtime VDBs are written under
`output/phase14_parallel_vdb`, logs are written under
`output/phase14_parallel_logs`, and each shard runs in its own `run/` directory
under `output/regression/phase14_v4_full_parallel`.

The high-parallel path disables shared `+UVM_CONFIG_DB_TRACE` and defaults to
`PHASE14_PARALLEL_UVM_ERR_ONLY=1` to reduce log and filesystem I/O at high
process counts. It also defaults `PHASE14_PARALLEL_FORCE_COV_REBUILD=1` and
`PHASE14_PARALLEL_STARTUP_RETRIES=2`, with
`PHASE14_PARALLEL_LAUNCH_STAGGER=0.05`, after the startup-only `rc=255` rerun
signature observed on 2026-05-04.

Recommended server command for a 152-CPU host:

```bash
make phase14_exit_check PHASE14_PARALLEL_JOBS=120
```

After preserving any needed evidence, stale high-parallel artifacts can be
removed with:

```bash
make phase14_clean_parallel
```

The legacy serial aggregate-VDB target `regress_v4_full` and the 5-way
per-seed target `regress_v4_full_sharded` remain available for debug, but final
Phase14 evidence should come from the high-parallel flow unless a
second-reviewed waiver records a different signoff decision.
