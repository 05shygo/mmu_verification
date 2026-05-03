# MMU Phase 14 Issue Tracker

> Project: OpenRiscv2030 MMU UVM Verification
> Phase: 14 - Full regression closure and signoff
> Created: 2026-05-02
> Purpose: internal issue / waiver / tooling tracker for Phase 14 signoff when no formal JIRA system is available.
> Execution owner: Phase14 Closure Owner.
> Closure owner policy: `doc/MMU_Phase14_ClosureOwner.md`

## Usage

This file is the Phase 14 signoff issue tracker. Each item has a stable internal ID that can be referenced by regression summaries, signoff notes, commits, or review comments.

ID format:

```text
MMU-P14-ISSUE-NNN
```

Status values:

| Status | Meaning |
| --- | --- |
| Open | Still under investigation or implementation |
| Accepted | Reviewed and accepted as non-blocking for the current signoff scope |
| Deferred | Not blocking current signoff, but must be revisited later |
| Closed | Resolved and verified |

Blocking values:

| Blocking | Meaning |
| --- | --- |
| Yes | Must be resolved before Phase 14 signoff |
| No | Does not block Phase 14 signoff under the recorded decision |
| Conditional | Blocks only if the stated condition applies |

## Phase 14 Ownership and Review Policy

Phase 14 is a closure phase. Starting in Phase 14, A/B execution roles are
merged into the **Phase14 Closure Owner** role to reduce handoff latency during
regression, failure triage, testcase repair, coverage closure, waiver handling,
and final signoff archive.

Historical A-side / B-side ownership is retained for traceability only. New
Phase 14 issues are classified by module or closure area rather than assigned
through A/B handoff:

- Regression
- Testcase
- Covergroup
- List
- Makefile/Gate
- URG/Tooling
- Waiver/Signoff
- RTL/Design Record

Review policy:

- Small code, testcase, list, covergroup, Makefile, or gate fixes can be closed
  directly by the Phase14 Closure Owner.
- All Phase 14 waiver and signoff decisions require second review.
- Any change to signoff criteria, coverage threshold, waiver policy, or URG
  fallback policy must be recorded in this tracker before gate or matrix changes
  are accepted.

## Issue Summary

| ID | Type | Title | Phase | Severity | Owner | Status | Blocking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MMU-P14-ISSUE-001 | URG/Tooling | URG `No context available` prevents `urgReport` generation | Phase 13/14 | Medium | Phase14 Closure Owner | Deferred | Conditional |
| MMU-P14-ISSUE-002 | RTL/Design Record | DA-003 PMP/SysMap port mapping written record | Phase 13/14 | Medium | Phase14 Closure Owner | Accepted | No |
| MMU-P14-ISSUE-003 | Waiver/Signoff | Coverage report fallback / waiver policy for Phase 14 signoff | Phase 14 | Medium | Phase14 Closure Owner | Open | Conditional |
| MMU-P14-ISSUE-004 | Makefile/Gate | Phase 14 Closure Owner regression and exit gate infrastructure | Phase 14 | Medium | Phase14 Closure Owner | Open | No |
| MMU-P14-ISSUE-005 | Waiver/Signoff | Phase 14 signoff matrix and second-review workflow | Phase 14 | Medium | Phase14 Closure Owner | Open | Conditional |
| MMU-P14-ISSUE-006 | URG/Tooling | VCS coverage dump abort corrupts/invalidates Phase14 run_cov VDB flow | Phase 14 | High | Phase14 Closure Owner | Open | Yes |

---

## MMU-P14-ISSUE-001 - URG `No context available`

| Field | Value |
| --- | --- |
| Type | URG/Tooling |
| Severity | Medium |
| Owner | Phase14 Closure Owner |
| Status | Deferred |
| Blocking | Conditional |
| First observed | 2026-05-02 |
| Evidence | `make phase13_exit_check` log; `output/coverage/urg_report.log` |

### Description

Synopsys URG fails to generate:

```text
output/coverage/urgReport
```

with:

```text
No context available
```

The Phase 13 regression and exit gate are otherwise clean. `make phase13_exit_check` reports `PHASE13_EXIT_CHECK: PASS`.

### Impact

This does not indicate a functional regression failure, SVA failure, or covergroup miss. It prevents generation of the URG HTML/text report only.

### Current Mitigation

Phase 13 uses `phase13_whitebox_cg summary` lines from simulation logs as the covergroup threshold fallback when URG is unavailable.

Final Phase 13 evidence:

```text
PHASE13_EXIT_CHECK: PASS
Phase 13 list: 55 tests x 3 seeds = 165/165 PASS
Criterion 2 SVA covers: PASS
Criterion 5 covergroups: PASS via log-summary fallback
```

### Signoff Decision

Accepted as non-blocking for Phase 13 completion. For Phase 14, this remains conditional:

- If final signoff requires a generated Synopsys URG HTML/text report, this issue must be resolved before signoff.
- If Phase 14 signoff accepts log-summary fallback plus documented coverage waivers, this issue can remain deferred.

### Next Action

During Phase 14, decide whether final signoff requires `output/coverage/urgReport`. If yes, debug URG using:

```bash
less output/coverage/urg_report.log
```

and investigate compile/runtime VDB context compatibility.

---

## MMU-P14-ISSUE-002 - DA-003 PMP/SysMap Port Mapping Record

| Field | Value |
| --- | --- |
| Type | RTL/Design Record |
| Severity | Medium |
| Owner | Phase14 Closure Owner |
| Status | Accepted |
| Blocking | No |
| Record | `doc/DA-003_phase13_port_mapping.md` |

### Description

DA-003 tracks the Phase 13 PMP/SysMap port mapping and fetch-sideband interpretation used by the A-side SVA and regression wiring.

Current Phase 13 mapping:

| PMP port | Phase 13 interpretation |
| --- | --- |
| `pa3/flg3` | PTW `twu_one` |
| `pa5/flg5` | PTW `twu_two` |
| `pa6/flg6` | PTW `twu_three` |
| `pa7/flg7` | PTW `twu_four` |

### Impact

This is a traceability item. It does not block Phase 13 because the written record exists and Phase 13 exit criterion 6 passed.

### Signoff Decision

Accepted for Phase 13 and available for Phase 14 signoff reference. If design ownership requires formal external approval later, this internal issue ID should be linked to the external tracker item.

### Next Action

Reference `MMU-P14-ISSUE-002` and `doc/DA-003_phase13_port_mapping.md` in the Phase 14 signoff matrix.

---

## MMU-P14-ISSUE-003 - Coverage Waiver / Fallback Policy

| Field | Value |
| --- | --- |
| Type | Waiver/Signoff |
| Severity | Medium |
| Owner | Phase14 Closure Owner |
| Status | Open |
| Blocking | Conditional |
| Evidence | Phase 13 exit summary; Phase 12/13 coverage debug records |

### Description

Phase 13 covergroup closure currently accepts `phase13_whitebox_cg summary` fallback when URG report generation is unavailable. Some covergroups were also adjusted so Phase 13 exit criteria do not require illegal or negative bins as signoff denominator, for example PMP multi-grant and invalid SysMap fallback flag combinations.

### Impact

For Phase 13, this is accepted by the implemented exit gate and final run:

```text
criterion 5 - 13 Phase 13 covergroups reach coverage threshold: PASS
```

For Phase 14, the project needs one explicit coverage closure policy:

- Use generated URG reports if URG is fixed.
- Otherwise use simulation log summary fallback plus documented exclusions / waivers.

### Signoff Decision

Open for Phase 14. This becomes blocking only if Phase 14 requires final coverage closure exclusively from URG HTML/text reports.

### Next Action

Before Phase 14 signoff, A/B should decide and record:

1. Whether URG HTML/text report is mandatory.
2. Which coverage groups are signed off by URG.
3. Which coverage groups are signed off by log-summary fallback.
4. Which bins or scenarios are waived as illegal, unreachable, or outside Phase 14 scope.

---

## MMU-P14-ISSUE-004 - Phase 14 Closure Gate Infrastructure

| Field | Value |
| --- | --- |
| Type | Makefile/Gate |
| Severity | Medium |
| Owner | Phase14 Closure Owner |
| Status | Open |
| Blocking | No |
| Artifacts | `simu/mmu_v4_full_regression_list`, `simu/mmu_v4_coverage_merge.sh`, `scripts/phase14_exit_gate.py`, `Makefile` |

### Description

Phase 14 requires one owner-driven closure path instead of A/B handoff. The
closure infrastructure provides:

- a 5-seed full/quasi-full regression list
- `regress_v4_full`
- `phase14_coverage_merge`
- `phase14_exit_check`
- strict artifact checks for summary/logs/coverage/matrix/tracker references

### Signoff Decision

Open until static checks pass and the infrastructure has been exercised in at
least one Phase 14 closure run.

### Review Requirement

Small implementation fixes are Closure Owner direct-close items. Any change to
the signoff criteria enforced by `phase14_exit_gate.py` requires second review
and an update to `doc/MMU_Phase14_SignoffMatrix.md`.

---

## MMU-P14-ISSUE-005 - Signoff Matrix and Second Review Workflow

| Field | Value |
| --- | --- |
| Type | Waiver/Signoff |
| Severity | Medium |
| Owner | Phase14 Closure Owner |
| Status | Open |
| Blocking | Conditional |
| Record | `doc/MMU_Phase14_SignoffMatrix.md` |

### Description

Phase 14 waiver and signoff decisions need a lightweight second-review workflow
without reintroducing A/B execution handoff. The signoff matrix records:

- VerificationPlan §9 S1-S11 status
- evidence path or command
- issue / waiver ID
- reviewer
- review status

### Signoff Decision

Open until all signoff rows are `Pass`, `Waived`, or `Accepted` and every
`Waived` / `Accepted` row cites a tracker ID plus reviewer.

### Review Requirement

All waiver/signoff decisions require second review. The reviewer may use
historical A-side/B-side expertise as context, but Phase 14 execution remains
owned by the Phase14 Closure Owner.

---

## MMU-P14-ISSUE-006 - VCS Coverage Dump Abort / VDB Cascade

| Field | Value |
| --- | --- |
| Type | URG/Tooling |
| Severity | High |
| Owner | Phase14 Closure Owner |
| Status | Open |
| Blocking | Yes |
| First observed | 2026-05-03 |
| Evidence | `test_twu_mask_pmp_wait_all4_97104_cov.log`; Phase14 run_cov console transcript |

### Description

The Phase14 run hit a VCS coverage infrastructure failure after the UVM test
completed cleanly:

```text
UVM_ERROR : 0
UVM_FATAL : 0
terminate called after throwing an instance of 'CovErrorException*'
During dumping of toggle coverage data
An unexpected termination has occurred in ./simv due to a signal: Aborted
```

After that abort, later `run_cov` invocations failed with:

```text
ERROR: clean compile-time coverage baseline VDB is missing: output/simv.compile.vdb
```

This is currently classified as coverage/tooling failure, not a testcase or RTL
functional failure. The original failing testcase was:

```text
test_twu_mask_pmp_wait_all4 seed=97104 mode=run_cov
```

### Impact

The shared aggregate-VDB run is not usable as Phase14 signoff evidence. The
coverage abort can also create cascading failures that obscure the first real
root cause.

### Closure Action

The Phase14 Makefile flow now defaults `phase14_exit_check` to the high-parallel
coverage path:

```bash
make phase14_exit_check
```

This invokes `regress_v4_full_parallel`, creates independent testcase/seed
shards, writes isolated runtime VDBs and logs, enables serial fail-fast inside
each shard, and then runs `phase14_coverage_merge_parallel`. The per-shard
compile baseline is hard-linked when possible and copied only as a fallback.

Follow-up from the first 152-CPU server trial (`PHASE14_PARALLEL_JOBS=120`):

- The expected shard count is 465 for `93 tests x 5 seeds`.
- Parallel logs are under `output/phase14_parallel_logs`; `output/logs` may only
  contain `comp_all.log` in this flow.
- Parallel VDBs now default to `output/phase14_parallel_vdb` instead of the
  `output/` root.
- Each shard now uses a private `run/` directory to avoid VCS/Verdi temporary
  file contention.
- Shared CFGDB trace is disabled in the high-parallel path and
  `PHASE14_PARALLEL_UVM_ERR_ONLY=1` is the default to reduce I/O.
- `make phase14_clean_parallel` removes high-parallel shard/log/VDB artifacts,
  including legacy root `output/phase14_parallel_*` artifacts.

### Signoff Decision

Open and blocking until one of the following is true:

- High-parallel Phase14 closure run completes with 100% regression pass and usable
  coverage artifacts.
- A waiver/fallback decision is recorded in this tracker, linked from
  `doc/MMU_Phase14_SignoffMatrix.md`, and second-reviewed.

---

## Phase 14 Signoff Reference

Phase 14 signoff notes should reference this tracker as:

```text
Issue tracker: doc/MMU_Phase14_IssueTracker.md
Open / accepted issues: MMU-P14-ISSUE-001, MMU-P14-ISSUE-002, MMU-P14-ISSUE-003, MMU-P14-ISSUE-004, MMU-P14-ISSUE-005, MMU-P14-ISSUE-006
```

Before final signoff, update this table:

| ID | Final Phase 14 decision | Evidence |
| --- | --- | --- |
| MMU-P14-ISSUE-001 | TBD | TBD |
| MMU-P14-ISSUE-002 | Accepted | `doc/DA-003_phase13_port_mapping.md`; Phase 13 criterion 6 PASS |
| MMU-P14-ISSUE-003 | TBD | TBD |
| MMU-P14-ISSUE-004 | TBD | `make print-phase14`; `python -m py_compile scripts/phase14_exit_gate.py`; closure run evidence |
| MMU-P14-ISSUE-005 | TBD | `doc/MMU_Phase14_SignoffMatrix.md` |
| MMU-P14-ISSUE-006 | TBD | High-parallel closure rerun evidence or reviewed coverage waiver |
