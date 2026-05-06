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
| MMU-P14-ISSUE-008 | RTL/Design Record | L1DTLB fault replay consumed entry could reissue/stick instead of release | Phase 14 | High | Phase14 Closure Owner | Closed | No |
| MMU-P14-ISSUE-009 | RTL/Design Record | L2TLB reqq sent entry did not retry when L2 miss-buffer allocation failed | Phase 14 | High | Phase14 Closure Owner | Closed | No |
| MMU-P14-ISSUE-010 | RTL/Design Record | L1ITLB missed L2TLB/JTLB page-fault completion in WFC transition | Phase 14 | High | Phase14 Closure Owner | Open | Yes |

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

Design intent clarification from triage: if a PTW request has already been sent
to LSU and `tlboper_ptw_abort` arrives before LSU returns data, PTW cancels all
current walk requests but still waits for the LSU response of the in-flight
external transaction before it can accept new L2TLB requests. The TB responder,
monitor, and SVA must therefore model a legal abort / late-response cleanup
window instead of treating every req-low or addr-change window as a fully
retired external transaction.

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

### Minimal Reproduction Update - 2026-05-03

Single-test reproduction:

```bash
make run_cov TEST_NAME=test_mmu_arb_grant_onehot_check SEED=97101 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR="${DBG_DIR}/arb_97101" \
  LOG_DIR="${DBG_DIR}/logs" \
  COV_DB_DIR="${DBG_DIR}/arb_97101.vdb" \
  COV_TAG=test_mmu_arb_grant_onehot_check_97101_min
```

Result:

```text
UVM_ERROR : 3
Translation SB FAILED: 1 mismatch(es) detected
```

Key observations from the reproduced log:

```text
1771000ps PTW LSU REQ addr=0x0000012010
1799000ps PTW RSP     addr=0x0000012010 pte_ppn=0x0003002
1799500ps a_response_inorder fails
1826000ps PTW RSP     addr=0x0000012010 pte_ppn=0x0003002
1826500ps a_response_inorder fails
... repeated PTW RSP addr=0x0000012010 with repeated SVA failures ...
2394000ps PTW LSU REQ addr=0x0000012008
2394000ps PTW_REQ_REPLACE old_addr=0x0000012010 new_addr=0x0000012008
2400000ps LSU_P0 VA=0x0030001000 mismatch ref.ppn=0x0003001 dut.pa=0x0003002
```

The translation whitebox line confirms the incorrect PPN came from a PTW refill:

```text
LAST_L1_REFILL: t=2396000 src=PTW vpn=0x0030001 ppn=0x0003002
LAST_PTW:       t=2396000 mb_vpn=0x0030001 ppn=0x0003002
```

Expected reference PPN for `VA=0x0030001000` is `0x0003001`, but the refill used
the PTE for `addr=0x0000012010`, whose PPN is `0x0003002`.

This strengthens the current diagnosis:

- `a_response_inorder` is not only a checker nuisance; it marks a window where
  the TB and DUT no longer agree on which PTW memory transaction is live.
- The responder can repeatedly generate responses for the same level-held
  `mmu_lsu_data_req` address because it treats any req-high sample after a
  response as a new external transaction, even when the DUT is still in an
  abort/cleanup or not-yet-advanced state.
- The monitor can classify an address change as `PTW_REQ_REPLACE` and credit it
  as a drop even though the design intent requires the in-flight LSU response to
  be consumed before new L2TLB work is accepted.
- The SVA uses `mbuf_entry_vld & mbuf_ptr` on the response cycle, which is too
  strong for the legal abort/late-response cleanup window.

### Minimal Failure Capture Procedure

Do not start with the full 465-shard run. Reproduce one failing shard with a
single testcase/seed first:

```bash
DBG_DIR="$(pwd)/output/debug_phase14_min"
mkdir -p "${DBG_DIR}/logs"

make run_cov TEST_NAME=test_mmu_arb_grant_onehot_check SEED=97101 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR="${DBG_DIR}/arb_97101" \
  LOG_DIR="${DBG_DIR}/logs" \
  COV_DB_DIR="${DBG_DIR}/arb_97101.vdb" \
  COV_TAG=test_mmu_arb_grant_onehot_check_97101_min
```

Then check whether the same SVA failure appears near the first known failure
time:

```bash
make check_log \
  LOG="${DBG_DIR}/logs/test_mmu_arb_grant_onehot_check_97101_min_cov.log"

grep -nE 'a_response_inorder|PTW_REQ_CANCEL|PTW_REQ_REPLACE|PTW LSU REQ|PTW RSP|ptw_mbuf_cnt|end-drain' \
  "${DBG_DIR}/logs/test_mmu_arb_grant_onehot_check_97101_min_cov.log"
```

For the credit leak signature, use one of the shortest pmbuf failures:

```bash
make run_cov TEST_NAME=test_pmbuf_addr_stable_001 SEED=97105 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR="${DBG_DIR}/pmbuf_addr_97105" \
  LOG_DIR="${DBG_DIR}/logs" \
  COV_DB_DIR="${DBG_DIR}/pmbuf_addr_97105.vdb" \
  COV_TAG=test_pmbuf_addr_stable_001_97105_min
```

Then scan the pmbuf log:

```bash
make check_log \
  LOG="${DBG_DIR}/logs/test_pmbuf_addr_stable_001_97105_min_cov.log"

grep -nE 'PTW_REQ_CANCEL|PTW_REQ_REPLACE|PTW LSU REQ|PTW RSP|ptw_mbuf_cnt|end-drain|UVM_ERROR' \
  "${DBG_DIR}/logs/test_pmbuf_addr_stable_001_97105_min_cov.log"
```

If log reproduction confirms the same failure, rerun the arb/grant seed with
wave dumping enabled by using the non-coverage `run` target:

```bash
make run TEST_NAME=test_mmu_arb_grant_onehot_check SEED=97101 \
  VERBOSITY=UVM_MEDIUM TIMEOUT=30000000 UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=0 \
  RUN_DIR="${DBG_DIR}/arb_97101_wave" \
  LOG_DIR="${DBG_DIR}/logs" \
  WAVE_DIR="${DBG_DIR}/waves"

make check_log \
  LOG="${DBG_DIR}/logs/test_mmu_arb_grant_onehot_check_97101.log"
```

The expected FSDB is:

```text
${DBG_DIR}/waves/test_mmu_arb_grant_onehot_check.fsdb
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

## MMU-P14-ISSUE-008 - L1DTLB Fault Replay Consumed Entry Release

| Field | Value |
| --- | --- |
| Type | RTL/Design Record |
| Severity | High |
| Owner | Phase14 Closure Owner |
| Status | Closed |
| Blocking | No after fix; Yes before fix for Phase14 regression |
| First observed | 2026-05-05 |
| Primary files | `mmu/rtl/mmu_l1dtlb_mb_entry.sv`, `mmu/rtl/mmu_l1dtlb_hit_rd.sv` |
| Fix commits | `17177f1`, `e6c31ea`; related LSU fault response commits `4410055`, `e464199`, `8756b69` |
| Evidence | `test_twu_mask_pmp_wait_all4 SEED=97102`; logs under `output/logs` and `output/phase14_parallel_logs` |

### Failure Signature

`test_twu_mask_pmp_wait_all4 SEED=97102` initially failed during end-of-test
drain:

```text
LSU stimulus did not drain before test_end_quiesce after 262144 cycles
pending=431 busy={p0:1 p1:1 p2:0 stamo:0 inv:0} tlb_busy=1 wakeup=0x000
```

The credit scoreboard snapshot showed all L1DTLB miss-buffer entries still
valid while PTW/L2 were otherwise idle:

```text
ptw_mbuf_cnt=0 l1d_mb=0xff l2_reqq=0x000 l2_final=0 l2_miss=0
ptw_lsu_req=0 ptw_lsu_grant=0x000 ptw_mbuf=0x000
```

This matched a local L1DTLB miss-buffer drain problem rather than an outstanding
PTW memory transaction.

### Root Cause

When an LSU request missed L1DTLB and refill later reported page fault or access
fault, the L1DTLB miss-buffer entry moved from `WFC` into `PGFLT` or `ACFLT` and
the exception CAM recorded the fault.

The consumed replay path was wrong in two ways:

- On exception CAM hit, the fault-state miss-buffer entry could return to
  `WFG`. In this RTL, `WFG` means the entry is ready to issue again
  (`entry_ready = state_r == STATE_WFG && !fault_hold_r`), so the consumed
  fault entry was not released.
- Exception CAM hits could still be classified as new DTLB misses, creating a
  replay / reallocation loop instead of completing the fault response.

The `fault_hold_r` state also had to be cleared when the exception CAM hit
consumed the fault, otherwise an entry returning through `WFG` could remain
blocked.

### Fix

The L1DTLB miss-buffer fault-state transition now releases the entry when the
exception CAM hit is consumed:

```systemverilog
STATE_PGFLT: if (expt_hit) state_nxt = STATE_IDLE;
STATE_ACFLT: if (expt_hit) state_nxt = STATE_IDLE;
```

`fault_hold_r` is cleared on consumed exception hits. The L1DTLB hit path also
prevents exception CAM hits from being reported as new misses:

```systemverilog
dutlb_miss_vld_x       ... & !dutlb_expt_match;
dutlb_miss_vld_short_x ... & !dutlb_expt_match;
```

### Verification Notes

After the L1DTLB fix, the same seed no longer showed the previous full L1DTLB
miss-buffer hang. The later timeout snapshot moved to the IFU/L2 path and showed
L1DTLB drained:

```text
LSU pending=0 busy={p0:0 p1:0 p2:0 stamo:0 inv:0} tlb_busy=0 wakeup=0x000
l1d_mb=0x00
```

That post-fix signature exposed the independent L2TLB request-queue retry issue
tracked as `MMU-P14-ISSUE-009`.

Recommended closure rerun:

```bash
make comp
make run_cov TEST_NAME=test_twu_mask_pmp_wait_all4 SEED=97102
make check_log LOG=output/logs/test_twu_mask_pmp_wait_all4_97102_cov.log
```

---

## MMU-P14-ISSUE-009 - L2TLB Reqq Retry Feedback on Miss-Buffer Full

| Field | Value |
| --- | --- |
| Type | RTL/Design Record |
| Severity | High |
| Owner | Phase14 Closure Owner |
| Status | Closed |
| Blocking | No after fix; Yes before fix for Phase14 regression |
| First observed | 2026-05-06 |
| Primary file | `mmu/rtl/mmu_l2tlb.sv` |
| Fix commit | `5fea263` |
| Evidence | `test_twu_mask_pmp_wait_all4 SEED=97102` timeout debug; `MMU_TIMEOUT_DBG` CreditSB snapshot |

### Failure Signature

After the L1DTLB fault replay fix, the same test/seed timed out with LSU fully
idle but IFU still waiting:

```text
IFU busy=1 va_vld=1 pavld=0 pgflt=1 l1i_st=0x2 credit=1
req=0 miss=1 refill_on=1 cmplt=0
```

The L2TLB/credit snapshot was:

```text
l1d_mb=0x00 l2_reqq=0x002 l2_reqq_rdy=0x000
l2_reqq_issue=0/type=0x3 l2mb=0x000 l2mb_rdy=0x000
l2_final=0 l2_miss=0 l2_ptw_req=0 ptw_mbuf=0x000
```

`l2_reqq=0x002` with `l2_reqq_rdy=0x000` means request-queue entry 1 remained
valid but had already been marked sent. With `l2mb=0x000`, there was no L2 miss
buffer entry left to make progress. The request had neither allocated a miss
buffer nor received retry feedback.

### Root Cause

The L2TLB request queue previously received feedback only on final hit or on
miss-buffer allocation:

```systemverilog
l2tlb_reqq_fb_vld = final_pa_vld | l2tlb_reqq_fb_miss_alloc;
l2tlb_reqq_fb_miss_alloc = l2tlb_miss & mb_alloc_valid;
l2tlb_reqq_fb_miss_retry = 1'b0;
```

If an L2 lookup missed while the L2 miss buffer could not allocate
(`l2tlb_miss && !mb_alloc_valid`), no feedback was sent to the request queue.
The entry stayed valid+sent forever and could no longer be retried.

### Fix

The request queue now receives feedback for every L2 miss. A miss with a
successful miss-buffer allocation remains an allocation feedback; a miss without
allocation becomes retry feedback:

```systemverilog
assign l2tlb_reqq_fb_vld        = final_pa_vld | l2tlb_miss;
assign l2tlb_reqq_fb_miss_alloc = l2tlb_miss & mb_alloc_valid;
assign l2tlb_reqq_fb_miss_retry = l2tlb_miss & !mb_alloc_valid;
```

This clears the sent state and allows the queued request to retry instead of
parking in `l2_reqq`.

### Verification Notes

The pre-fix timeout signature to guard against is:

```text
l2_reqq=0x002 l2_reqq_rdy=0x000 l2mb=0x000 l2_final=0 l2_miss=0 l2_ptw_req=0
```

Recommended closure rerun:

```bash
make comp
make run_cov TEST_NAME=test_twu_mask_pmp_wait_all4 SEED=97102
make check_log LOG=output/logs/test_twu_mask_pmp_wait_all4_97102_cov.log
```

If this single seed passes, rerun the Phase14 parallel list to confirm no other
request-queue starvation signature remains:

```bash
make regress_v4_full_parallel PHASE14_PARALLEL_JOBS=20
```

---

## MMU-P14-ISSUE-010 - L1ITLB Refill FSM WFC Did Not Release

| Field | Value |
| --- | --- |
| Type | RTL/Design Record |
| Severity | High |
| Owner | Phase14 Closure Owner |
| Status | Open |
| Blocking | Yes until rerun passes |
| First observed | 2026-05-06 |
| Primary file | `mmu/rtl/mmu_l1itlb.sv` |
| Related file | `mmu/rtl/mmu_l2tlb.sv` |
| Fix commit | Pending; working-tree RTL fix present |
| Evidence | `test_twu_mask_pmp_wait_all4 SEED=97102` timeout debug; L1ITLB debug fields added to `MMU_TIMEOUT_DBG` |

### Failure Signature

The post-L1DTLB-fix timeout showed the IFU side repeatedly stuck in the L1ITLB
refill path:

```text
IFU busy=1 end_quiesce=0 va_vld=1 abort=0 pavld=0
pgflt=1 deny=0 pmp_deny=0
l1i_st=0x2 credit=1 req=0 miss=1 refill_on=1
```

In `mmu_l1itlb.sv`, `l1i_st=0x2` is `WFC`. The key failing completion cycle is
the L2TLB/JTLB page-fault completion:

```text
l1i_st=0x2 refill_on=1 l1itlb_ref_cmplt=1
ptw_l1tlb_pgflt=0 jtlb_iutlb_pgflt=1
```

On that cycle, L1ITLB should enter `PGFLT` for one cycle so
`iutlb_ref_pgflt` contributes to `mmu_ifu_pavld` and `mmu_ifu_pgflt`. Instead,
the fault was not recognized as a fault-state transition, so IFU never consumed
the translation as a completed page fault and kept holding/retrying the same VA.

### Root Cause

The L1ITLB FSM release condition in `WFC` is completion-driven:

```systemverilog
assign l1itlb_ref_cmplt = ptw_l1itlb_ref_cmplt | jtlb_iutlb_ref_cmplt;
```

`l1itlb_ref_cmplt` correctly merges both completion sources. However, the
fault-state branch only checked the PTW page-fault signal:

```systemverilog
if (l1itlb_ref_cmplt && ptw_l1tlb_pgflt)
  ref_nxt_st = PGFLT;
else if (l1itlb_ref_cmplt)
  ref_nxt_st = IDLE;
```

When the completion came from L2TLB/JTLB with `jtlb_iutlb_pgflt=1`, the FSM did
not treat it as a page-fault completion. The `else if (l1itlb_ref_cmplt)` branch
could release the FSM to `IDLE` without ever asserting the one-cycle `PGFLT`
state. Because `mmu_ifu_pavld` is driven by `iutlb_ref_pgflt` for refill page
faults, IFU did not see a completed fault response and the same VA could reenter
the refill path. This made the ITLB refill/fault replay path inconsistent with
L1DTLB, where both PTW refill faults and L2TLB refill faults are part of the
fault completion path.

### Fix

The `WFC` page-fault transition now includes both page-fault sources:

```systemverilog
else if (l1itlb_ref_cmplt && (ptw_l1tlb_pgflt || jtlb_iutlb_pgflt))
  ref_nxt_st = PGFLT;
```

This makes L1ITLB recognize page-fault completions from either PTW or L2TLB/JTLB
before releasing the refill FSM.

### Verification Notes

Keep the L1ITLB timeout debug fields in any failing rerun until Phase14 closure:

```text
ref_cur_st, credit_cnt, iutlb_l2tlb_req, iutlb_refill_on,
l1itlb_ref_cmplt, ptw_l1tlb_pgflt, jtlb_iutlb_pgflt
```

The fixed signature to guard against is a L2TLB/JTLB page-fault completion that
does not drive the L1ITLB fault path:

```text
l1i_st=0x2 refill_on=1 l1itlb_ref_cmplt=1 ptw_pgflt=0 jtlb_pgflt=1
```

Expected post-fix behavior is `WFC -> PGFLT -> IDLE`, with a completed IFU page
fault response during the `PGFLT` cycle.

Recommended closure rerun:

```bash
make comp
make run_cov TEST_NAME=test_twu_mask_pmp_wait_all4 SEED=97102
make check_log LOG=output/logs/test_twu_mask_pmp_wait_all4_97102_cov.log
```

---

## Phase 14 Signoff Reference

Phase 14 signoff notes should reference this tracker as:

```text
Issue tracker: doc/MMU_Phase14_IssueTracker.md
Open / accepted issues: MMU-P14-ISSUE-001, MMU-P14-ISSUE-002, MMU-P14-ISSUE-003, MMU-P14-ISSUE-004, MMU-P14-ISSUE-005, MMU-P14-ISSUE-006, MMU-P14-ISSUE-007, MMU-P14-ISSUE-008, MMU-P14-ISSUE-009, MMU-P14-ISSUE-010
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
| MMU-P14-ISSUE-008 | Closed | Commits `17177f1`, `e6c31ea`; `test_twu_mask_pmp_wait_all4 SEED=97102` no longer shows `l1d_mb=0xff` L1DTLB hang |
| MMU-P14-ISSUE-009 | Closed | Commit `5fea263`; guard against `l2_reqq=0x002 l2_reqq_rdy=0x000 l2mb=0x000` retry starvation signature |
| MMU-P14-ISSUE-010 | TBD | Working-tree fix in `mmu/rtl/mmu_l1itlb.sv`; rerun must show L2TLB/JTLB page-fault completion drives `WFC -> PGFLT -> IDLE` |
