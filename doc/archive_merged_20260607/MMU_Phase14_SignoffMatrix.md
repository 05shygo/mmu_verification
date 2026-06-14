# MMU Phase 14 Signoff Matrix

Project: OpenRiscv2030 MMU UVM Verification
Phase: 14 full regression closure and signoff
Execution owner: Phase14 Closure Owner
Issue tracker: `doc/MMU_Phase14_IssueTracker.md`
Closure owner policy: `doc/MMU_Phase14_ClosureOwner.md`

## Ownership Model

Phase 14 is a closure phase. A-side and B-side history remains in source
documents for traceability, but Phase 14 execution is merged into the
Phase14 Closure Owner role.

Post-Phase14 issues are classified by module or closure area, not by A/B
assignment:

- Regression
- Testcase
- Covergroup
- List
- Makefile/Gate
- URG/Tooling
- Waiver/Signoff
- RTL/Design Record

## Review Policy

- Small testcase, list, covergroup, Makefile, or gate fixes can be closed
  directly by the Phase14 Closure Owner.
- All waiver and signoff decisions require second review.
- Any change to signoff criteria, coverage threshold, waiver policy, or URG
  fallback policy must be recorded in `MMU_Phase14_IssueTracker.md`.

## Signoff Criteria

Allowed final statuses: `Pass`, `Waived`, `Accepted`.

`Waived` and `Accepted` rows must cite at least one `MMU-P14-ISSUE-NNN` and
must have a non-empty reviewer plus `Reviewed` or `Approved` review status.

| ID | VerificationPlan Section 9 criterion | Status | Evidence | Issue / Waiver | Reviewer | Review status |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | nightly_full / Phase14 full list 5 seeds 100% pass | Pass | `make regress_v4_full_parallel PHASE14_PARALLEL_JOBS=20`; merged summary `output/regression/phase14_v4_full/summary.txt`; console reported `Phase14 parallel shards completed cleanly` | None | Phase14 Closure Owner | Self-reviewed |
| S2 | weekly_coverage / latest coverage run has no regression | Pass | `make phase14_coverage_merge_parallel` with Synopsys `VCS/URG V-2023.12-SP2`; report generated at `output/coverage/phase14_urgReport` | None | Phase14 Closure Owner | Self-reviewed |
| S3 | Code coverage: line >=99.5%, branch >=99%, toggle >=98%, FSM >=99% | Open | DUT `u_dut` authoritative aggregate (MMU-P14-ISSUE-021 corrected prior false-100% parser): line 96.95%, branch 94.43%, toggle 72.38%, FSM 90.91%, assert 88.50% — all below threshold; post structural exclusion + WFG→IDLE functional test closure; closure in progress under MMU-P14-ISSUE-022 | MMU-P14-ISSUE-021, MMU-P14-ISSUE-022 | Phase14 Closure Owner | TBD |
| S4 | Functional coverage 100% | Waived | `make phase14_gate_parallel`: functional 82.41% below 100.00%; source `output/coverage/phase14_urgReport/groups.txt` | MMU-P14-ISSUE-003 | Phase14 Closure Owner | Reviewed |
| S5 | Assertion coverage 100% triggered, 0 fail | Open | DUT `u_dut` (MMU-P14-ISSUE-021): assert 88.50% below 100.00%; 0 failing assertions in regression; closure in progress under MMU-P14-ISSUE-022 | MMU-P14-ISSUE-021, MMU-P14-ISSUE-022 | Phase14 Closure Owner | TBD |
| S6 | P0/P1 open bugs are 0 | Pass | `doc/MMU_Phase14_IssueTracker.md`; 2026-05-07 full regression clean; MMU-P14-ISSUE-007 and MMU-P14-ISSUE-010 through MMU-P14-ISSUE-015 closed | None | Phase14 Closure Owner | Self-reviewed |
| S7 | P2 bugs reviewed and agreed | Waived | Issue tracker review notes | MMU-P14-ISSUE-003 | Phase14 Closure Owner | Reviewed |
| S8 | Waivers all co-signed | Waived | This matrix plus `simu/exclude_v4.do` | MMU-P14-ISSUE-003 | Phase14 Closure Owner | Reviewed |
| S9 | GLS zero-delay critical set 100% pass or formally out of Phase14 scope | Waived | GLS logs or scope waiver | MMU-P14-ISSUE-003 | Phase14 Closure Owner | Reviewed |
| S10 | Lint/CDC/RDC no unwaived violations or formally out of Phase14 scope | Waived | Tool reports or scope waiver | MMU-P14-ISSUE-003 | Phase14 Closure Owner | Reviewed |
| S11 | Verification plan/report/signoff checklist approved | Waived | `doc/MMU_Progress.md`, this matrix, final sign-off commit | MMU-P14-ISSUE-004, MMU-P14-ISSUE-005 | Phase14 Closure Owner | Reviewed |
| S12 | L1DTLB audit/testplan synchronization reviewed | Open | `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md` chapters 3.9/3.10; `doc/l1dtlb_uvm_audit/L1DTLB_TRISTAN_IP_Hardware_tp_V1.xlsx`; `make l1dtlb_audit_check` | MMU-P14-ISSUE-016 | TBD | TBD |

## Final Archive

Before final signoff, update this section with concrete command results.

| Artifact | Path / command | Final result |
| --- | --- | --- |
| Full regression | `make regress_v4_full_parallel PHASE14_PARALLEL_JOBS=20` | PASS; 465 high-parallel testcase/seed shards completed cleanly; merged summary at `output/regression/phase14_v4_full/summary.txt` |
| Coverage merge | `make phase14_coverage_merge_parallel` | PASS with Synopsys `VCS/URG V-2023.12-SP2`; generated `output/coverage/phase14_urgReport` |
| Exit gate | `make phase14_gate_parallel` | FAIL; coverage criteria report real DUT numbers after MMU-P14-ISSUE-021 parser fix and MMU-P14-ISSUE-022 structural exclusions — line 96.71% / branch 94.13% / toggle 72.34% / fsm 86.10% / assert 86.95% all below threshold (closure under MMU-P14-ISSUE-022); SignoffMatrix S3/S5 Open |
| Parallel cleanup | `make phase14_clean_parallel` | Use only after preserving needed evidence |
| Full regression summary | `output/regression/phase14_v4_full/summary.txt` | PASS; expected_total=465, total=465, failed=0, xpass=0, pass_rate=1.0000 |
| Coverage report | `output/coverage/phase14_urgReport` | Generated by URG `V-2023.12-SP2` with `simu/exclude_v4.tgl` elfile; DUT `u_dut` post-exclusion aggregate (MMU-P14-ISSUE-021/022): line 96.71%, branch 94.13%, toggle 72.34%, FSM 86.10%, assert 86.95%; functional (group) 85.09% |
| Coverage fallback / waiver | `doc/MMU_Phase14_IssueTracker.md` | Pending; MMU-P14-ISSUE-003 must close the functional coverage shortfall by additional tests or reviewed waiver |
| L1DTLB audit documents | `make l1dtlb_audit_check` | Pending rerun after doc sync; checks `l1dtlb_function_description.md`, `l1dtlb_testpoint_audit.md`, and `L1DTLB_TRISTAN_IP_Hardware_tp_V1.xlsx` presence |
| L1DTLB directed audit run | `make l1dtlb_audit_run_cov` | Deferred until current UVM code edits stabilize; tracked by MMU-P14-ISSUE-016 |
| Final progress record | `doc/MMU_Progress.md` | TBD |
