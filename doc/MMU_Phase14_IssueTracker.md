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
| MMU-P14-ISSUE-007 | Testbench/Protocol | Phase14 PTW mbuf abort/late-response accounting and SVA failures | Phase 14 | High | Phase14 Closure Owner | Open | Yes |

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
runtime VDB is restored from a shared clean compile baseline by `run_cov`; shard
VDB files must not hard-link back to the compile baseline.

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

Follow-up from the `PHASE14_PARALLEL_JOBS=120` rerun that reported 364 failing
shards:

- The common signature was `run_cov simulation failed ... rc=255` with per-test
  simulation logs containing only the VCS `Command:` line and no UVM/VCS
  completion marker.
- This is classified as simulator startup/resource pressure, not 364 independent
  testcase failures.
- The high-parallel runner now leaves the compile baseline VDB as a shared,
  read-only source and lets each shard restore its own runtime VDB through
  `run_cov`; it no longer hard-links baseline VDB files into shard VDBs.
- `regress_v4_full_parallel` defaults `PHASE14_PARALLEL_FORCE_COV_REBUILD=1` so
  the Phase14 parallel run starts from a fresh compile coverage baseline after
  any previous high-parallel artifact corruption.
- Startup-only `rc=255` attempts with missing/command-only logs are retried by
  default via `PHASE14_PARALLEL_STARTUP_RETRIES=2`. Real UVM/SVA/coverage-abort
  failures are not retried by this filter.
- Initial shard launch is lightly staggered by default
  (`PHASE14_PARALLEL_LAUNCH_STAGGER=0.05`) to avoid a single burst of VCS
  startup and license/NFS traffic.

### Signoff Decision

Open and blocking until one of the following is true:

- High-parallel Phase14 closure run completes with 100% regression pass and usable
  coverage artifacts.
- A waiver/fallback decision is recorded in this tracker, linked from
  `doc/MMU_Phase14_SignoffMatrix.md`, and second-reviewed.

---

## MMU-P14-ISSUE-007 - PTW mbuf Abort / Late-Response Protocol Triage

| Field | Value |
| --- | --- |
| Type | Testbench/Protocol |
| Severity | High |
| Owner | Phase14 Closure Owner |
| Status | Open |
| Blocking | Yes |
| First observed | 2026-05-03 |
| Evidence | `make phase14_show_parallel_failures PHASE14_PARALLEL_FAILURE_LIMIT=7`; logs under `output/phase14_parallel_logs` |

### Failure Signature

The first high-parallel Phase14 functional rerun reported 7 failing shards:

```text
test_pmbuf_addr_stable_001 seeds=97101,97103,97104,97105
test_pmbuf_serial_outstanding_001 seeds=97103,97105
test_mmu_arb_grant_onehot_check seed=97101
```

The pmbuf tests fail at end of simulation with:

```text
UVM_ERROR testbench/env/mmu_credit_sb.svh(498)
[CreditSB] ptw_mbuf_cnt != 0 at end-of-sim (1):
PTW serialized external request not drained
```

The arb/grant testcase fails repeatedly in:

```text
testbench/top/mmu_ptw_lsu_protocol_sva.sv:52
a_response_inorder
```

around the first observed response-order failure at `1799500ps`.

### Current Triage

This is not currently classified as a Phase14 parallel-runner issue. The
failures converge on the PTW-to-LSU external memory channel and its abort /
late-response modeling.

The credit scoreboard increments `m_ptw_mbuf_cnt` on PTW memory request monitor
events and decrements on response/drop events. A residual count of 1 after the
scoreboard drain window indicates one monitored PTW request did not receive a
matching response or drop according to the testbench model.

The `a_response_inorder` checker currently requires every PTW LSU response
event:

```systemverilog
lsu_mmu_data_vld || lsu_mmu_bus_error
```

to coincide with:

```systemverilog
|(mbuf_entry_vld & mbuf_ptr)
```

This assumption is suspicious around `tlboper_ptw_abort`. In the RTL, mbuf entry
valid can be cleared by abort while `mbuf_entry_on` / PTW abort cleanup state may
still be waiting for a later `lsu_mmu_data_vld` or `lsu_mmu_bus_error` to retire
the outstanding external transaction. A late response after abort can therefore
be legal for cleanup but fail the checker if the checker keys off
`mbuf_entry_vld` instead of the in-flight/on state.

The PTW memory responder is also suspicious: it cancels a pending response when
`mmu_lsu_data_req` drops or the request address/size changes. The responder and
monitor do not observe `tlboper_ptw_abort`, so they cannot distinguish normal
request cancellation/replacement from an abort boundary where the DUT may still
need a late response or bus error to clear internal abort state.

Additional RTL item to review: `ptw.sv` sets `abort_flop` with a condition that
contains:

```systemverilog
(!lsu_mmu_bus_error | !lsu_mmu_data_vld)
```

This expression is true unless both response indicators are asserted in the same
cycle. If the intended condition is "abort and no response this cycle", the
expression should be reviewed with the design owner before any RTL change is
made.

### Possible Contributing Testcase Issue

The Phase11 pmbuf wrappers used by the failing pmbuf tests run generic direct
LSU sequences such as `lsu_pipe0_only_seq` and `lsu_back2back_seq`. Those
sequences are not constrained to the mapped SV39 window prepared by the base
test. This makes the pmbuf tests less directed than their names imply and can
increase seed sensitivity by generating many unmapped/page-fault/abort cases.

This does not by itself prove the root cause, but it should be reviewed after
the abort/late-response protocol question is confirmed.

### Minimal Failure Capture Procedure

Do not start with the full 465-shard run. Reproduce one failing shard with a
single testcase/seed first:

```bash
make run_cov TEST_NAME=test_mmu_arb_grant_onehot_check SEED=97101 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR=output/debug_phase14_min/arb_97101 \
  LOG_DIR=output/debug_phase14_min/logs \
  COV_DB_DIR=output/debug_phase14_min/arb_97101.vdb \
  COV_TAG=test_mmu_arb_grant_onehot_check_97101_min
```

Then check whether the same SVA failure appears near the first known failure
time:

```bash
make check_log \
  LOG=output/debug_phase14_min/logs/test_mmu_arb_grant_onehot_check_97101_min_cov.log

grep -nE 'a_response_inorder|PTW_REQ_CANCEL|PTW_REQ_REPLACE|PTW LSU REQ|PTW RSP|ptw_mbuf_cnt|end-drain' \
  output/debug_phase14_min/logs/test_mmu_arb_grant_onehot_check_97101_min_cov.log
```

For the credit leak signature, use one of the shortest pmbuf failures:

```bash
make run_cov TEST_NAME=test_pmbuf_addr_stable_001 SEED=97105 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR=output/debug_phase14_min/pmbuf_addr_97105 \
  LOG_DIR=output/debug_phase14_min/logs \
  COV_DB_DIR=output/debug_phase14_min/pmbuf_addr_97105.vdb \
  COV_TAG=test_pmbuf_addr_stable_001_97105_min
```

Then scan the pmbuf log:

```bash
make check_log \
  LOG=output/debug_phase14_min/logs/test_pmbuf_addr_stable_001_97105_min_cov.log

grep -nE 'PTW_REQ_CANCEL|PTW_REQ_REPLACE|PTW LSU REQ|PTW RSP|ptw_mbuf_cnt|end-drain|UVM_ERROR' \
  output/debug_phase14_min/logs/test_pmbuf_addr_stable_001_97105_min_cov.log
```

If log reproduction confirms the same failure, rerun the arb/grant seed with
wave dumping enabled by using the non-coverage `run` target:

```bash
make run TEST_NAME=test_mmu_arb_grant_onehot_check SEED=97101 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR=output/debug_phase14_min/arb_97101_wave \
  LOG_DIR=output/debug_phase14_min/logs \
  WAVE_DIR=output/debug_phase14_min/waves

make check_log \
  LOG=output/debug_phase14_min/logs/test_mmu_arb_grant_onehot_check_97101.log
```

The expected FSDB is:

```text
output/debug_phase14_min/waves/test_mmu_arb_grant_onehot_check.fsdb
```

The key waveform/debug window is the first `a_response_inorder` failure around
`1799500ps`. Capture at least +/-200ns around that point and inspect:

```text
tlboper_ptw_abort
abort_flop
mmu_lsu_data_req
mmu_lsu_data_req_addr
lsu_mmu_data_vld
lsu_mmu_bus_error
mbuf_entry_vld
mbuf_entry_on
mbuf_entry_get
mbuf_ptr
mbuf_ptr_nxt
```

The hypothesis is confirmed if a response arrives after or during PTW abort while
`mbuf_entry_vld & mbuf_ptr` is zero but an in-flight/on or abort-cleanup state is
still active.

### Closure Requirement

Blocking until all are true:

- Minimal single-test reproduction is captured and archived.
- Abort/late-response behavior is classified as either DUT protocol bug,
  testbench responder/monitor modeling bug, or SVA assumption bug.
- The selected fix is reviewed against the RTL PTW abort semantics.
- The failing Phase14 shards rerun cleanly before final signoff.

---

## Phase 14 Signoff Reference

Phase 14 signoff notes should reference this tracker as:

```text
Issue tracker: doc/MMU_Phase14_IssueTracker.md
Open / accepted issues: MMU-P14-ISSUE-001, MMU-P14-ISSUE-002, MMU-P14-ISSUE-003, MMU-P14-ISSUE-004, MMU-P14-ISSUE-005, MMU-P14-ISSUE-006, MMU-P14-ISSUE-007
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
| MMU-P14-ISSUE-007 | TBD | Minimal PTW mbuf abort/late-response reproduction and Phase14 shard rerun evidence |
