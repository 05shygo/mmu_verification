# DA-003 Phase 13 Port Mapping Record

Date: 2026-05-01
Owner: Engineer A
Phase: 13

## Status

DA-003 remains a written tracking item for PMP/SysMap port mapping. Phase 13 A-side SVA and regression wiring use the current RTL-observed mapping below and do not claim design closure beyond this record.

## PMP PTW Port Mapping Used By Phase 13

The current top-level PMP interface and `ptw.sv` wiring are treated as:

| PMP port | Phase 13 interpretation |
| --- | --- |
| `pa3/flg3` | PTW `twu_one` |
| `pa5/flg5` | PTW `twu_two` |
| `pa6/flg6` | PTW `twu_three` |
| `pa7/flg7` | PTW `twu_four` |

`pa0/flg0`, `pa1/flg1`, and `pa2/flg2` remain LSU0, LSU1, and IFU respectively per `testbench/pmp_agent/pmp_if.sv`. `pa4/flg4` remains LSU Pipe2 / prefetch per existing interface comments.

## Fetch Signal Spelling

`testbench/pmp_agent/pmp_if.sv` intentionally uses the top-level RTL port spelling `mmu_pmp_fetch7`. Older plan text mentions `mmu_pmp_fecth7`; that typo is not used at the top-level interface. The bound TWU SVA observes the internal `twu` signal `mmu_pmp_fecth`, matching the internal RTL name in `mmu/rtl/twu.sv`.

## PTW PMP Fetch Semantics

`mmu_pmp_fetch{3,5,6,7}` / internal `mmu_pmp_fecth` is the original miss fetch sideband for the walk. It is not the PTW PTE bus-read command type. Current Phase 13 checks therefore verify that the selected TWU PMP stage propagates this sideband consistently and that PMP permission selection follows the original access type:

| Original walk type | PMP permission bit used |
| --- | --- |
| fetch | X (`flg[2]`) |
| load | R (`flg[0]`) |
| prefetch | R (`flg[0]`) |
| store | W (`flg[1]`) |

The legacy `test_ptw_pmp_fetch_zero` test name is kept only for regression-list compatibility; its metadata/checker now refer to original-fetch propagation, not a zero-only requirement.

## Phase 13 A-Side Action

Engineer A added SVA coverage/guards for PMP/TWU and SysMap/TWU behavior and wired `regress_v4_sysmap_pmp`. B-side test list, tests, and covergroups remain outside this record.
