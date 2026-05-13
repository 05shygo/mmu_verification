# PTW Stage 3 Probe Gap Table

This table records probe coverage after stage 3. Stage 3 evidence is
monitor-only and provisional; P0/P1 closure still requires later source
reference model, scoreboard, and SVA stages.

| Gap ID | Probe / Window | Stage 3 Status | Impact | Temporary Evidence | Close Condition |
| --- | --- | --- | --- | --- | --- |
| PTW-PROBE-GAP-001 | `pmp_regs_update` to PTW/PDE clear | Open. `tb_top.sv` still ties DUT `pmp_regs_update` to `1'b0`; `pmp_regs_update_probe` records that limitation. | Cannot sign off PMP-config-change PDE clear behavior from this environment. | `regs_ptw_clr`, `tlboper_ptw_abort`, and reset clear are visible through `pde_cache_clear`; PMP update reason is not. | Make `pmp_regs_update` testbench-drivable/observable or add a bind/probe that reflects the real PMP update pulse. |
| PTW-PROBE-GAP-002 | PDE double-hit vector and per-entry hit index | Partial. Stage 3 exposes L1/L2 hit valid, request key, output VPN/PPN, update vectors, and clear. | Double-hit priority can be inferred only as L2-selected output, not proven with both raw hit vectors. | `pde_l1_hit_vld`, `pde_l2_hit_vld`, `pde_xbar_*`, `pde_l1_update_vec`, `pde_l2_update_vec`. | Expose raw `L1PDE_entry_hit_idx` and `L2PDE_entry_hit_idx` or bind a PDE cache monitor/SVA in stage 5. |
| PTW-PROBE-GAP-003 | PDE clear reason | Partial. Reset/abort/regs clear are visible indirectly; PMP update is not. | Cannot distinguish all clear causes in monitor transaction. | `pde_cache_clear`, reset state, `tlboper_ptw_abort`, `tlboper_utlb_clr`, `rtu_yy_xx_flush`, `pmp_regs_update_probe=0`. | Add explicit clear reason fields: reset, regs/satp, PMP update, abort. |
| PTW-PROBE-GAP-004 | Abort same-cycle pre-existing exception grant | Partial. Monitor emits `PTW_SRC_DROP_PRE_EXISTING_EXCEPTION_GRANT` when abort coincides with visible page/access fault grant. | It does not prove whether the exception was already registered before abort. | `tlboper_ptw_abort` plus `ptw_l2tlb_ref_pgflt/acc_err` and `{type,id}`. | Expose exception register valid/grant timing from PTW/L2TLB exception path. |
| PTW-PROBE-GAP-005 | Abort bus-error vs late data classification | Partial. Monitor sees `ptw_abort_flop`, PTW LSU data/bus-error, and MBUF key fields. | Same-cycle abort/bus-error and late-response drops are reported, but source cause may still need memory responder metadata to disambiguate. | `ptw_lsu_data_vld`, `ptw_lsu_bus_error`, `ptw_abort_flop`, `ptw_mem_monitor.ap_rsp`, `ptw_mem_monitor.ap_drop`. | Add explicit responder/monitor drop reason to `ptw_mem_txn` or bind PTW MBUF abort bus-error state. |
| PTW-PROBE-GAP-006 | Raw PTE per TWU level before CHK | Partial. MBUF distributed data and memory response data are visible; per-level TWU CHK internal latched data is not fully exposed. | Debug has raw returned PTE and level, but exact CHK stage latch may need waveform/probe for race failures. | `ptw_mbuf_twu_data`, `ptw_mbuf_twu_data_vld`, `ptw_twu_mbuf_lvl`, `ptw_mem_monitor.ap_rsp`. | Expose per-TWU `fst/scd/thd_chk_data` and CHK valid/wait in a structured level event or stage-5 SVA bind. |
| PTW-PROBE-GAP-007 | Sysmap malformed no-hit/multi-hit negative cases | Partial. Stage 3 logs sysmap hit vectors/flg per TWU. | Normal regression should not treat malformed sysmap as DUT fail; monitor does not classify illegal stimulus. | `p13_sysmap_hit_vec`, `p13_sysmap_flg_vec`, stage-0 illegal-stimulus matrix. | Stage 7 illegal/stress constraints and report parser classify malformed sysmap explicitly. |
| PTW-PROBE-GAP-008 | Scenario metadata to monitor event association | Partial. `ptw_scenario_db` keeps active scenario/requirement strings and logs events. | It is a logger, not a transactional database keyed by scenario timestamps; concurrent scenarios are not yet separated. | `PTW_SCENARIO_REGISTER`, `PTW_SCENARIO_EVENT`, `PTW_SCENARIO_DB_SUMMARY`. | Stage 4/7 source checker should carry scenario IDs in expected/actual transactions or add a timestamped scenario interval table. |

## Stage 3 Covered Signals

The following stage-3 probes are wired read-only through `mmu_dut_probes_if` and
`tb_top.sv`: request `{vpn,type,id}`, ready, completion class bits, refill
tag/data/flg, L1I/L1D/L2/PFU target indicators, context ASID/SATP/MAEE/MPRV/MPP,
PTW LSU data/bus-error, MBUF/TWU level data, abort/abort-flop, PDE hit/update
proxy fields, PMP vectors, and sysmap vectors.

## Exit-Criteria Note

`ptw_l2tlb_cmplt` is deliberately treated as a completion OR in
`ptw_source_monitor.svh`. The monitor emits refill/page/access-fault actual
transactions only from class-specific signals.
