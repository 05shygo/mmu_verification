# Phase 11 R19 Gate

## Scope

- Risk ID: `R19`
- Trace ID: `TC-BUG-011`
- Wrapper: `mmu_verification/testbench/test/bug_hunt_tests/test_bug_011_twu_2m_csr_cross.svh`
- Feature ID: `F4.NEW.4`
- Severity: `P0`

## Current policy

- `TC-BUG-011` is created as a compile-visible wrapper, but it is **commented out**
  from:
  - `mmu_verification/simu/mmu_bug_hunt_list`
  - `mmu_verification/simu/mmu_v3_regression_list`
- Reason:
  - the issue remains `Blocked-Waiting-RTL-Fix`
  - the current B-owned list format has no native `xfail` field
  - A-side regression wrapper support is still needed before it can be promoted
    into the regular machine-consumable lists

## Evidence required to close R19

- JIRA ticket ID and close record
- screenshot or exported close evidence
- RTL fix revision / commit reference
- note that dependent `csr_data_flop`-related 2MB CSR cross scenarios are no
  longer blocked

## Promotion rule

- Keep `TC-BUG-011` commented out until:
  1. JIRA is closed
  2. A-side `xfail` or equivalent gate policy is agreed
  3. the wrapper passes standalone regression or is explicitly reclassified
