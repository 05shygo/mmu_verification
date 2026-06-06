# PTW Code Coverage CI Rules

PTW_CODE_COVERAGE_CI_RULES version=1 stage=6

## Entry

Run from `mmu_verification/`:

```bash
make ptw_code_cov PTW_COV_PROFILE=<quick|default|full|signoff>
```

`PTW_COV_EXTRA_ARGS` is reserved for debug jobs only. A job using
`PTW_COV_EXTRA_ARGS`, `--dry-run`, `--skip-functional-gate`, or
`functional_gate.status=SKIPPED` must not be treated as final signoff.

## Profiles

| Profile | CI Use | Accepted Top-Level Status | Signoff Evidence |
| --- | --- | --- | --- |
| `quick` | Flow smoke | `PASS` or `CONDITIONAL_PASS` | No |
| `default` | Daily PTW coverage monitor | `PASS` or `CONDITIONAL_PASS` | No |
| `full` | Hole-closure monitor | `PASS` or `CONDITIONAL_PASS` | No |
| `signoff` | Final PTW code coverage signoff | `PASS` only | Yes |

## Required Artifacts

- `output/ptw_cov/run_ptw_code_coverage.log`
- `output/ptw_cov/ptw_cov_manifest.json`
- `output/ptw_cov/ptw_code_coverage_summary.json`
- `output/ptw_cov/ptw_code_coverage_summary.md`
- `output/ptw_cov/urgReport/`
- `output/ptw_cov/simv_ptw.vdb`

## Signoff Rules

A signoff job passes only if all of the following are true:

- command return code is 0;
- stdout contains `PTW_CODE_COVERAGE_RESULT status=PASS`;
- summary JSON has `profile=signoff`;
- summary JSON has `scope=ptw_core`;
- summary JSON has `confidence=high`;
- summary JSON has `ptw_code_coverage >= 99.0`;
- each required metric meets its threshold or has an explicit N/A/waiver record;
- `functional_gate.status` is `PASS` or evidence-complete `REUSED`;
- `functional_gate.status` is not `SKIPPED`;
- URG report and VDB paths recorded in JSON exist.

Quick/default/full jobs may publish `CONDITIONAL_PASS` as monitor output, but
that status must not be promoted to final signoff.
