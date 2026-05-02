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
| S1 | nightly_full / Phase14 full list 5 seeds 100% pass | Open | `output/regression/phase14_v4_full/summary.txt` | - | - | - |
| S2 | weekly_coverage / latest coverage run has no regression | Open | `output/coverage/phase14_urgReport` or reviewed fallback | MMU-P14-ISSUE-001, MMU-P14-ISSUE-003 | TBD | TBD |
| S3 | Code coverage: line >=99.5%, branch >=99%, toggle >=98%, FSM >=99% | Open | `output/coverage/phase14_urgReport` | MMU-P14-ISSUE-003 if waiver is needed | TBD | TBD |
| S4 | Functional coverage 100% | Open | `output/coverage/phase14_urgReport` and/or reviewed log-summary fallback | MMU-P14-ISSUE-003 if fallback/waiver is used | TBD | TBD |
| S5 | Assertion coverage 100% triggered, 0 fail | Open | `output/coverage/phase14_urgReport`; SVA cover summaries | MMU-P14-ISSUE-003 if fallback/waiver is used | TBD | TBD |
| S6 | P0/P1 open bugs are 0 | Open | `doc/MMU_Phase14_IssueTracker.md`; R19/R20/DA-003 records | MMU-P14-ISSUE-002, MMU-P14-ISSUE-003 | TBD | TBD |
| S7 | P2 bugs reviewed and agreed | Open | Issue tracker review notes | MMU-P14-ISSUE-003 | TBD | TBD |
| S8 | Waivers all co-signed | Open | This matrix plus `simu/exclude_v4.do` | MMU-P14-ISSUE-003 | TBD | TBD |
| S9 | GLS zero-delay critical set 100% pass or formally out of Phase14 scope | Open | GLS logs or scope waiver | MMU-P14-ISSUE-003 if waived | TBD | TBD |
| S10 | Lint/CDC/RDC no unwaived violations or formally out of Phase14 scope | Open | Tool reports or scope waiver | MMU-P14-ISSUE-003 if waived | TBD | TBD |
| S11 | Verification plan/report/signoff checklist approved | Open | `doc/MMU_Progress.md`, this matrix, final sign-off commit | MMU-P14-ISSUE-004, MMU-P14-ISSUE-005 | TBD | TBD |

## Final Archive

Before final signoff, update this section with concrete command results.

| Artifact | Path / command | Final result |
| --- | --- | --- |
| Full regression | `make regress_v4_full` | TBD |
| Coverage merge | `make phase14_coverage_merge` | TBD |
| Exit gate | `make phase14_exit_check` | TBD |
| Full regression summary | `output/regression/phase14_v4_full/summary.txt` | TBD |
| Coverage report | `output/coverage/phase14_urgReport` | TBD |
| Coverage fallback / waiver | `doc/MMU_Phase14_IssueTracker.md` | TBD |
| Final progress record | `doc/MMU_Progress.md` | TBD |
