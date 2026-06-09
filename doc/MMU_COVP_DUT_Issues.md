# MMU COVP DUT Issue Log

> Project: OpenRiscv2030 MMU UVM verification
> Scope: `make covp` failure triage. Confirmed DUT issues remain in this log;
> issues proven to be verification/testbench problems are reclassified with the
> closure evidence.
> Policy: DUT RTL is not modified in this flow. UVM/testbench issues are fixed
> directly; confirmed DUT issues require independent evidence and reruns.

## Issue Summary

| ID | Type | Title | Severity | Status | Blocking |
| --- | --- | --- | --- | --- | --- |
| COVP-DUT-001 | Verification/Testbench Reclassification | LSU invalidate watchdog and sequencing model did not cover legal TLBOper latency/overlap | Medium | Closed/Reclassified | No |
| COVP-DUT-002 | Verification/Testbench Reclassification | L1DTLB WFG flush/grant same-cycle L2 request is legal; checker needed contract and sample-phase alignment | Medium | Closed/Reclassified | No |

## COVP-DUT-001 - Closed/Reclassified

| Field | Value |
| --- | --- |
| First observed | 2026-06-09 02:38 CST |
| Original command | `make -j90 covp COV_PARALLEL_JOBS=90` |
| Primary historical tests | `test_l2tlb_p6e_tlbop_inv_abort_lifecycle seed=1`, `test_mmu_dir_l2tlb_inv_asid seed=1` |
| Related requirements | F8.1 / F8.6 / TC-SFENCE-002 / TC-SFENCE-012 |
| Final status | Closed as verification/testbench issue; no current evidence of a DUT missing-done liveness bug |
| Blocking | No |
| DUT files reviewed | `mmu/rtl/ct_mmu_tlboper.v`, `mmu/rtl/ct_mmu_top.v`, `mmu/rtl/lsu/rtl/ct_lsu_snoop_ctcq.v` |
| DUT files modified | None |
| Final evidence logs | `mmu_verification/output/logs_asid_closure/` |

### Historical Failure Signature

The original Phase14 parallel run failed fast on LSU TLB invalidate completion
timeouts. Later `rc=130` entries were fail-fast cancellations, not independent
root causes.

```text
output/phase14_parallel_logs/test_l2tlb_p6e_tlbop_inv_abort_lifecycle_1_cov.log:
UVM_ERROR ... LSU INV monitor did not observe mmu_lsu_tlb_inv_done within 1024 cycles: kind=INV_ALL ...
UVM_FATAL ... TLB INV response timeout after 1024 cycles: inv_kind=INV_ALL ...

output/phase14_parallel_logs/test_mmu_dir_l2tlb_inv_asid_1_cov.log:
UVM_ERROR ... LSU INV monitor did not observe mmu_lsu_tlb_inv_done within 1024 cycles: kind=INV_ASID_ALL ...
UVM_FATAL ... TLB INV response timeout after 1024 cycles: inv_kind=INV_ASID_ALL ...
```

### Final Root Cause

Focused reruns with opt-in `MMU_INVDBG` traces showed that the LSU
`INV_ASID_ALL` request is accepted after the preceding CP0 `INVALL` completes,
then scans the 256 L2TLB sets and reaches the normal completion boundary. The
1024/1200-cycle watchdog was shorter than the legal latency for this overlapped
scenario, so the timeout was not proof that the DUT never asserted
`mmu_lsu_tlb_inv_done`.

The final classification has three verification-side parts:

1. The LSU driver must model real OpenC910 LSU CTCQ behavior by holding
   `lsu_mmu_tlb_*_inv` level-high until `mmu_lsu_tlb_inv_done`.
2. The LSU invalidate done watchdog must be long enough for legal CP0/TLBOper
   overlap plus the 256-set ASID scan. The current default is 8192 cycles.
3. Generated tests that run direct LSU sequences followed by vseqs must not
   accidentally start the vseq while queued LSU invalidates are still draining,
   unless the test is explicitly intended to cover overlap.

There was also an abort-contract mismatch in the assertion model:
`tlboper_ptw_abort` is level-high while the raw LSU CTCQ request waits for
TLBOper acceptance. Both current RTL and upstream OpenC910 implement it as
`tlb_lsu_oper && !tlb_lsu_oper_flop`. The SVA was updated to match this behavior
instead of enforcing a one-cycle pulse that conflicts with the source design.

### Fixes Applied

| Area | Files |
| --- | --- |
| LSU level-held invalidate model and longer watchdog | `testbench/lsu_agent/lsu_driver.svh`, `testbench/lsu_agent/lsu_monitor.svh` |
| Hard scoreboard check for missing invalidate done | `testbench/env/mmu_invalidate_sb.svh` |
| OpenC910-compatible abort lifecycle SVA | `testbench/top/mmu_tlbop_lifecycle_sva.sv` |
| Opt-in MMU invalidate debug trace | `testbench/top/tb_top.sv` |
| Preserve `+NB_TXNS` override and add opt-in LSU drain before vseq | `testbench/test/phase9_common/phase9_generated_test_base.svh` |
| Directed ASID probe and closure vseqs | `testbench/cp0_agent/cp0_sequences.svh`, `testbench/env/mmu_vseq_lib.svh` |
| Directed closure wrappers | `testbench/test/tlbop_tests/test_mmu_sfence_inv_asid_hit_directed.svh`, `testbench/test/tlbop_tests/test_mmu_sfence_inv_asid_global_directed.svh`, `testbench/test/tlbop_tests/test_mmu_sfence_inv_asid_overlap_directed.svh` |

The original `test_mmu_dir_l2tlb_inv_asid` wrapper now waits for LSU idle before
starting its smoke vseq. This removes accidental queued-overlap from that test.
The overlap behavior is still covered explicitly by
`test_mmu_sfence_inv_asid_overlap_directed`.

### Closure Coverage

The ASID invalidate issue is covered by both randomized/original tests and new
directed tests:

| Test | Coverage intent | Result |
| --- | --- | --- |
| `test_l2tlb_p6e_tlbop_inv_abort_lifecycle SEED=1` | Historical `INV_ALL` timeout / abort lifecycle fail-fast entry | PASS, 0 warning / 0 error / 0 fatal |
| `test_mmu_sfence_inv_asid_hit_directed SEED=1` | Non-global L2TLB entry is hit before `INV_ASID_ALL` and missed after invalidate | PASS, 0 warning / 0 error / 0 fatal |
| `test_mmu_sfence_inv_asid_global_directed SEED=1` | Global L2TLB entry survives `INV_ASID_ALL`; post-invalidate TLBP/TLBR still match | PASS, 0 / 0 / 0 |
| `test_mmu_sfence_inv_asid_overlap_directed SEED=1` | Explicit CP0 `INVALL` plus LSU `INV_ASID_ALL` overlap | PASS, 0 / 0 / 0 |
| `test_mmu_sfence_inv_asid SEED=1` | Original SFENCE ASID invalidate test | PASS, 0 / 0 / 0 |
| `test_mmu_sfence_inv_asid_global_skip SEED=1` | Original global-skip ASID invalidate test | PASS, 0 / 0 / 0 |
| `test_mmu_dir_l2tlb_inv_asid SEED=1` | Original directed L2TLB ASID invalidate test, default 64 transactions | PASS, 0 / 0 / 0 |
| `test_mmu_dir_l2tlb_inv_asid SEED=4` | Historical seed-4 ASID fail-fast reproduction | PASS, 0 / 0 / 0 |

`make comp_fast UVM_CONFIG_DB_TRACE=0` also passes with the closure changes.

### Residual Risk

This closure does not claim that every possible MMU invalidation combination has
been exhausted. It closes the original LSU ASID invalidate timeout by covering:

- non-global entry invalidated by ASID;
- global entry preserved by ASID invalidate;
- CP0 `INVALL` and LSU `INV_ASID_ALL` overlap;
- original seed-1 failure tests with the corrected testbench model.

Future regressions should keep the hard driver/monitor/scoreboard checks enabled
so any true missing `mmu_lsu_tlb_inv_done` after the 8192-cycle bound still fails.

## COVP-DUT-002 - Closed/Reclassified

| Field | Value |
| --- | --- |
| First observed | 2026-06-09 CST |
| Historical failing probe | `test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101` with `+L1DTLB_WFG_RACE_PROBE` |
| Primary historical errors | `P6D_NR_L2_SIDE_EFFECT`, later `P6D_ALLOC_FLUSH_SIDE_EFFECT` / `P6D_NR_ALLOC_SIDE_EFFECT` |
| Primary checker | `testbench/env/mmu_l1dtlb_spec_sb.svh` |
| Verification files updated | `testbench/env/mmu_l1dtlb_spec_sb.svh`, `testbench/env/mmu_dut_probes_if.sv`, `testbench/top/mmu_l1dtlb_sva.sv`, `testbench/top/tb_top.sv` |
| DUT files modified by this verification continuation | None |
| Final status | Closed as verification/testbench contract and sample-phase issue after DUT-owner clarification and user RTL update |
| Blocking | No |

### Final Contract

The DUT owner clarified the intended L1DTLB miss-buffer behavior:

- A flush/abort arriving in the same cycle that a WFG entry is granted does not
  need to block the downstream L2 request.
- If `abort_this_cyc` and the grant occur in the same cycle, the entry
  transitions through the ABT handling path.
- The same-cycle request is legal only when it is the already-existing WFG
  entry that was granted; unrelated new allocation or bypass side effects under
  flush must still fail the checker.

This supersedes the earlier no-RTL diagnostic classification that treated every
flush-cycle L2 request as illegal.

### Verification Root Cause

Two checker/modeling gaps produced the earlier failure signatures:

1. `mmu_l1dtlb_spec_sb` did not distinguish a legal existing-WFG
   flush/grant L2 issue from a true new side effect, so it flagged legal
   `flush_kill` cycles as `P6D_NR_L2_SIDE_EFFECT`.
2. The flush allocation diagnostic compared the sampled `cur_vld` transition
   against the current flush cycle without checking whether the DUT allocation
   write-enable was active in that same sampled cycle. The added probes showed
   the first suspicious cycle had `req0=0`, `req1=0`,
   `gnt_safe=00`, and `we_safe=0x00`, so the observed `cur_vld` change was a
   prior-cycle visible allocation, not a new flush-cycle allocation.

The checker now treats an existing WFG entry's flush/grant request as legal only
when the L2 request `eid`, `vpn`, ready/state, and load/store polarity match the
current MB entry. It still reports true allocation or non-WFG L2 side effects
under `flush_kill`.

### Fixes Applied

| Area | Files |
| --- | --- |
| Allow legal existing-WFG flush/grant L2 issue while preserving side-effect checks | `testbench/env/mmu_l1dtlb_spec_sb.svh` |
| Track flush-cycle allocation transitions that are prior-cycle visible at the monitor sample point | `testbench/env/mmu_l1dtlb_spec_sb.svh` |
| Add read-only L1D allocation/miss queue probes for future root-cause diagnostics | `testbench/env/mmu_dut_probes_if.sv`, `testbench/top/tb_top.sv` |
| Align L1DTLB MB-entry SVA ready decode with the clarified WFG contract | `testbench/top/mmu_l1dtlb_sva.sv` |
| Remove obsolete bind references to deleted DUT refill-IID match signals | `testbench/top/mmu_l1dtlb_sva.sv`, `testbench/top/tb_top.sv` |

### Closure Evidence

Compile:

```text
make comp COV_FORCE_REBUILD=1 UVM_CONFIG_DB_TRACE=0
```

Result: PASS. The compiled coverage design VDB contains
`assert+branch+cond+fsm+line+tgl`.

Focused L1DTLB WFG race run:

```text
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 \
  PLUS_ARGS="+L1DTLB_WFG_RACE_ONLY +L1DTLB_WFG_RACE_PROBE +L1DTLB_HIGH_MATRIX_FAST_RECOVER +L1DTLB_FAST_FINAL_QUIESCE +L1DTLB_FLUSH_ALLOC_DIAG +L1DTLB_FLUSH_ALLOC_DIAG_LIMIT=16" \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l1d_wfg_race_after_alloc_checker_align \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l1d_wfg_race_after_alloc_checker_align.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=8000000
```

Result: PASS with `UVM_ERROR=0`, `UVM_FATAL=0`, `hard_failures=0`; runtime VDB
updated at
`output/coverage/probe_l1d_wfg_race_after_alloc_checker_align.vdb`.

Structural/SVA evidence from the passing log:

- `cp_l1dtlb_wfg_flush_with_grant` matched on entries `[1..7]`.
- `cp_l1dtlb_wfg_flush_no_grant` matched on entries `[3..7]`.
- `cp_l1dtlb_c020_flush_race` matched on all entries `[0..7]`.

Focused L2TLB REQQ/arb run, kept here because it was part of the same L1/L2
coverage continuation:

```text
make run_cov TEST_NAME=test_l2tlb_p6e_reqq_arb_fine_overlap SEED=64001 \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l2tlb_reqq_arb_fine_overlap_after_l1_checker_align \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l2tlb_reqq_arb_fine_overlap_after_l1_checker_align.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000
```

Result: PASS with `UVM_ERROR=0`, `UVM_FATAL=0`, `hard_failures=0`; Phase6E
`TRIGGER`, `CHECKER`, and `CLOSE` each reported count `1` with waiver count `0`.
The key REQQ/arb counters included `i_alloc=104`, `d_load_alloc=162`,
`d_store_alloc=190`, `reqq_grant=456`, `multi_req=668`,
`reqq_pfu_conflict=423`, `ptw_reqq_conflict=2`, and
`tlbop_reqq_conflict=9`.

Focused L2TLB REQQ depth run:

```text
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_l2_reqq_depth_001 SEED=97101 \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l2_reqq_depth_focused_invasid \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l2_reqq_depth_focused_invasid.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
```

Result: PASS with `UVM_ERROR=0`, `UVM_FATAL=0`, `hard_failures=0`. The scenario
uses a legal raw LSU `INV_ASID_ALL` TLBOP window plus 8 DTLB misses; it does not
force internal DUT state. Key counters: `L2TLB_REQQ_FINE max_occ=8`,
`d_load_alloc=4`, `d_store_alloc=4`, `d_entry_grant=8`, and
`L2TLB_ARB_FINE tlbop_reqq_conflict=255`. The updated trend report
`output/coverage/phase14_l1_l2_current_trend_report_invasid/coverage_hotspots.md`
no longer lists `cg_l2_reqq` in functional explicit uncovered bins.

### Residual Risk

This closure relies on the current DUT contract that same-cycle
WFG flush/grant request issue is legal and handled by the ABT path. The checker
now encodes that specific legality rule. Any future case that allocates a new MB
entry under the active flush write-enable, or issues a non-matching/non-WFG L2
request under `flush_kill`, remains a hard checker failure.

### Current Coverage Status Update

On 2026-06-09, the remaining current L1/L2 coverage task continued without
modifying DUT RTL. No new confirmed DUT issue was opened.

Additional verification-side closure added:

- `test_sysmap_cfg_coverage_sweep`: SysMap configuration mirror covergroup
  closure only; this does not sign off `ct_mmu_sysmap` DUT behavior.
- `test_mmu_pmp_cfg_coverage_sweep`: PMP flag interface covergroup closure.
- `test_ptw_rsp_delay1_coverage_001` and
  `test_ptw_rsp_delay0_coverage_001`: PTW responder delay coverage, with
  delay0 closing the diagnostic `cg_rsp_delay_range.d1` bin.
- `scripts/phase14_merge_parallel_coverage.py`: XML fallback now ignores
  `illegal="1"` bins when reconstructing functional coverage.

Verification evidence:

- `make comp COV_FORCE_REBUILD=1 UVM_CONFIG_DB_TRACE=0`: PASS.
- The four additional focused runs all PASS with `UVM_ERROR=0`,
  `UVM_FATAL=0`, and `hard_failures=0`.
- Final diagnostic trend report:
  `output/coverage/phase14_l1_l2_current_trend_report_final/coverage_hotspots.md`.
- Final diagnostic functional coverage: 85.10% (394/463), meeting the current
  85% target in `phase14_dut_quality_coverage_closure.md`.

Official Synopsys URG signoff is still required; the XML hotspot report remains
a diagnostic trend artifact.
