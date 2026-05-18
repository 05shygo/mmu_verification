# PTW Implementation Process

This document records the execution progress of `ptw_staged_implementation_plan.md`.
It is a process/status log only; the staged plan remains the source of task
boundaries and exit criteria.

## Current Status

| Stage | Name | Status | Exit Criteria | Notes |
| --- | --- | --- | --- | --- |
| 0 | Spec Baseline, Traceability, Legacy Freeze | done | passed | User confirmed stage-0 task and exit-standard checks passed. |
| 1 | Common Types, Config Knobs, Compile Skeleton | done | passed | User confirmed stage-1 task and exit-standard checks passed. |
| 2 | Directed Test Base, Page Table Builder, PTW Memory Responder | done | passed | User confirmed stage-2 task and exit-standard checks passed. |
| 3 | Probe, Monitor, Scenario Logger | done | passed | User confirmed stage-3 task and exit-standard checks passed; monitor evidence remains provisional. |
| 4 | Source Reference Model and Scoreboard MVP | done | passed | User confirmed stage-4 task and exit-standard checks passed after bus-error/access-fault debug updates. |
| 5 | P0 SVA and Cover Gate | done | passed | User confirmed stage-5 task and exit-standard checks passed. |
| 6 | P0 Directed Tests and Legacy Conflict Fixes | done | passed | User confirmed stage-6 task and exit-standard checks passed after PFU direct-map and MAEE=0 SysMap refill debug updates. |
| 7 | Reference/Scoreboard Complete P1/P2 Random Stress | done | passed | User confirmed stage-7 task and exit-standard checks passed after SATP old-walk, TWU/L1TLB permission, and MAEE=0 huge-page cross debug updates. |
| 8 | Regression, Report, Signoff Freeze | done | passed | User confirmed stage-8 task and exit-standard checks passed after source active-key, L1DTLB PGFLT replay, and signoff-gate Python compatibility debug updates. |
| 10 | PDE pmpflg Regression, Closure Matrix and Signoff Gate Freeze | done | pending-user-run | Stage10 list/CSV/gate/report/process files updated; pde-pmpflg signoff regressions must be run in the normal make/VCS environment. |

## Stage 0 Completion Record

```text
PTW_STAGE_DONE stage=0 name=Spec Baseline Traceability Legacy Freeze
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    doc/ptw_uvm_review/ptw_source_closure_matrix.md,
    mmu_verification/simu/ptw_source_closure_matrix.csv,
    doc/ptw_uvm_review/ptw_legacy_test_action_list.md,
    doc/ptw_uvm_review/ptw_id_coverage_audit.md
  ]
  source_sb_summary=not_applicable_stage0
  sva_summary=not_applicable_stage0
  closure_delta=[
    PTW-AUD-001..023,
    PTW-ADD-001..036,
    PTW-FLOW-001..023,
    PTW-INFRA-001..009,
    PDE-TP-*,
    MBUF-TP-*,
    MAEE-TP-*
  ]
  open_items=[
    source-side evidence remains open by design until later checker/SVA/test stages
  ]
  next_stage_blockers=[]
```

## Stage 1 Completion Record

```text
PTW_STAGE_DONE stage=1 name=Common Types Config Knobs Compile Skeleton
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/env/ptw_source_types.svh,
    mmu_verification/testbench/env/ptw_source_monitor.svh,
    mmu_verification/testbench/env/ptw_source_ref_model.svh,
    mmu_verification/testbench/env/ptw_source_sb.svh,
    mmu_verification/testbench/top/mmu_ptw_source_sva.sv,
    mmu_verification/testbench/env/mmu_top_cfg.svh,
    mmu_verification/testbench/env/mmu_env_pkg.sv,
    mmu_verification/testbench/env/mmu_env.svh,
    mmu_verification/testbench/Files.f
  ]
  source_sb_summary=PTW_SOURCE_SB_SUMMARY accepted=0 matched=0 mismatch=0 pending=0 illegal=0 provisional=1
  sva_summary=PTW_SVA_COVER stage1_placeholder hits=0 provisional=1
  closure_delta=[
    PTW-INFRA common type definitions,
    PTW source checker cfg knobs,
    PTW source monitor/ref_model/sb compile skeleton,
    PTW source SVA placeholder,
    PTW_SOURCE_CLOSURE report placeholders
  ]
  open_items=[
    monitor probe sampling is not implemented in stage 1,
    source ref model algorithm is not implemented in stage 1,
    source scoreboard matching is not implemented in stage 1,
    source SVA assertions and cover properties are not implemented in stage 1
  ]
  next_stage_blockers=[]
```

## Stage 2 Completion Record

```text
PTW_STAGE_DONE stage=2 name=Directed Test Base Page Table Builder PTW Memory Responder
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/ptw_mem_agent/page_table_builder.svh,
    mmu_verification/testbench/ptw_mem_agent/ptw_mem_responder.svh,
    mmu_verification/testbench/ptw_mem_agent/ptw_mem_sequences.svh,
    mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh,
    mmu_verification/testbench/test/ptw_tests/test_ptw_source_stage2_smoke.svh,
    mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh
  ]
  tests_run=[
    git diff --check -- stage2_touched_files,
    rg marker/API checks for PTW_SCENARIO_META, PTW_STAGE2_SMOKE_SUMMARY,
    rg marker/API checks for raw PTE and directed responder controls,
    make -C mmu_verification comp_fast,
    make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=202 PLUS_ARGS="+EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
  ]
  environment_notes=[
    stage-2 exit-standard checks were completed and confirmed by user after implementation
  ]
  source_sb_summary=not_applicable_stage2_provisional_only
  sva_summary=not_applicable_stage2_no_new_sva
  closure_delta=[
    PTW-INFRA-002 raw PTE/page-table builder stimulus support,
    deterministic PTW memory delay and bus-error controls,
    same-cycle abort/data and abort/bus-error control hooks,
    PTW source directed base context/PMP/SysMap/request/quiescent helpers,
    stage2 smoke scenario metadata for 1G/2M/4K success, page fault, access fault, bus error, and abort-window controls
  ]
  open_items=[
    source monitor/probe evidence remains open until stage 3,
    source reference model/scoreboard matching remains open until stage 4,
    stage2 smoke results are provisional and must not be used as P0/P1 closure
  ]
  next_stage_blockers=[]
```

## Stage 3 Completion Record

```text
PTW_STAGE_DONE stage=3 name=Probe Monitor Scenario Logger Observability
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/env/ptw_source_types.svh,
    mmu_verification/testbench/env/mmu_dut_probes_if.sv,
    mmu_verification/testbench/top/tb_top.sv,
    mmu_verification/testbench/env/ptw_source_monitor.svh,
    mmu_verification/testbench/env/ptw_scenario_db.svh,
    mmu_verification/testbench/env/mmu_env_pkg.sv,
    mmu_verification/testbench/env/mmu_env.svh,
    mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh,
    doc/ptw_uvm_review/ptw_stage3_probe_gap_table.md
  ]
  tests_run=[
    git diff --check -- stage3_touched_files,
    rg marker/API checks for PTW_SOURCE_MONITOR_SUMMARY and PTW_SCENARIO_DB_SUMMARY,
    rg probe checks for l2tlb_ptw_vpn, ptw_arb_ref_data_din, tlboper_ptw_abort, PDE/drop ports,
    vlog -sv -work ./ptw_stage3_probe_work mmu_verification/testbench/env/mmu_dut_probes_if.sv
      result=passed errors=0 warnings=0,
    make -C mmu_verification comp_fast,
    make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=303 PLUS_ARGS="+EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
  ]
  environment_notes=[
    local PowerShell did not provide make during implementation, so full comp_fast/run_check was completed and confirmed by user after implementation,
    D:/tmp was not writable by this process, so the temporary ModelSim work library was created under the workspace and removed after the probe-interface compile
  ]
  source_sb_summary=not_applicable_stage3_monitor_only_provisional
  sva_summary=not_applicable_stage3_no_new_sva
  closure_delta=[
    PTW-INFRA-003 source monitor actual/probe transaction producer,
    PTW-INFRA-004 PDE hit/update/clear observability hooks and open-gap table,
    PTW-INFRA-006 PMP/TWU level-event observability hooks,
    PTW source request accept capture by {type,id},
    PTW refill/page-fault/access-fault actual completion capture,
    PTW abort/reset/late-data/drop provisional event capture,
    PTW memory monitor fanout to scenario DB
  ]
  open_items=[
    monitor-only evidence is provisional and cannot close P0/P1 requirements,
    source reference model/scoreboard matching remains open until stage 4,
    source-side SVA implementation remains open until stage 5,
    pmp_regs_update is still tied off in tb_top and is recorded in the probe gap table,
    PDE raw double-hit vectors and exact clear reason remain partial/open in the probe gap table,
    abort pre-existing exception timing and abort bus-error classification remain partial/open in the probe gap table
  ]
  next_stage_blockers=[
    stage 4 must consume these actual/probe transactions in source ref model and scoreboard before source-side closure
  ]
```

## Stage 4 Completion Record

```text
PTW_STAGE_DONE stage=4 name=Source Reference Model and Scoreboard MVP
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/env/ptw_pde_cache_model.svh,
    mmu_verification/testbench/env/ptw_source_types.svh,
    mmu_verification/testbench/env/ptw_source_monitor.svh,
    mmu_verification/testbench/env/ptw_source_ref_model.svh,
    mmu_verification/testbench/env/ptw_source_sb.svh,
    mmu_verification/testbench/env/mmu_env_pkg.sv,
    mmu_verification/testbench/env/mmu_env.svh,
    mmu_verification/testbench/ptw_mem_agent/ptw_mem_responder.svh,
    doc/ptw_uvm_review/ptw_implementation_process.md
  ]
  tests_run=[
    git diff --check -- stage4_touched_files,
    rg marker/API checks for PTW_SOURCE_REF_SUMMARY stage=4 and PTW_SOURCE_SB_SUMMARY stage=4,
    rg checks for PTW_SOURCE_ILLEGAL_REUSE, PTW_SOURCE_MISMATCH, PTW_SOURCE_DROP_MATCH, PTW_STAGE4_OPEN_GAP,
    attempted local ModelSim env package compile; blocked by existing package/UVM macro dependency issues before stage-4-only compilation could be isolated,
    make -C mmu_verification comp_fast,
    make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
  ]
  environment_notes=[
    local PowerShell did not provide make during implementation, so full comp_fast/run_check was completed and confirmed by user after implementation,
    source ref model explicitly does not call mmu_ref_model.translate(),
    stage-4 source SB plusarg enables source ref model and monitor automatically,
    LSU bus error is modeled as an access-fault output with bus-error root-cause evidence, matching ptwspec.md Q26/Q104/Q121
  ]
  debug_record=[
    initial_stage4_run_check_reported PTW_SOURCE_MISMATCH key=2:8 with exp.fault=PTW_SRC_FAULT_BUS_ERROR and act.fault=PTW_SRC_FAULT_ACCESS,
    waveform/debug conclusion: LSU bus error is expected to be reported to L1DTLB as the same visible access-fault class as PMP deny; bus-error root cause must not be treated as a distinct visible fault code,
    scoreboard fix: ptw_source_sb.fault_kind_matches allows ref-model PTW_SRC_FAULT_BUS_ERROR root cause to match actual PTW_SRC_FAULT_ACCESS when kind is PTW_SRC_EXP_ACCESS_FAULT,
    monitor fix: ptw_source_monitor actual access-fault completion records PTW_SRC_FAULT_ACCESS as the final visible class,
    responder/protocol fix: ptw_mem_responder now drives lsu_mmu_data_vld and lsu_mmu_bus_error high on the same response beat for bus-error injection; data_vld high without bus_error remains normal data,
    post-debug result: user confirmed stage-4 task and exit-standard checks all passed
  ]
  source_sb_summary=PTW_SOURCE_SB_SUMMARY stage=4 mismatch=0 pending=0 illegal=0 provisional=0
  sva_summary=not_applicable_stage4_no_new_sva
  closure_delta=[
    PTW-INFRA-003 source monitor actual/probe transactions consumed by source ref model/SB,
    PTW-INFRA-004 abstract PDE cache model with L1/L2 lookup, double-hit L2 priority, queued update, clear, and abort flush,
    PTW source expected generation for refill/page fault/access fault/drop,
    PTW source scoreboard matching by {type,id} without fixed latency assumptions,
    duplicate {type,id} request reuse classified as illegal,
    mismatch taxonomy for class_mismatch, field_mismatch, drop_mismatch, pending, illegal, and probe_gap
  ]
  open_items=[
    MAEE=0 1G/2M sysmap degrade remains a later-stage modeling/test closure item,
    PMP deny and LSU bus-error expected generation use visible monitor/probe evidence and unique-pending fallback when exact key probes are insufficient,
    source-side SVA implementation remains open until stage 5,
    P0 directed closure remains open until stage 6
  ]
  next_stage_blockers=[
    stage 5 may add SVA using the stage-3 probes and stage-4 mismatch taxonomy,
    stage 6 directed tests should require PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0
  ]
```

## Stage 5 Implementation Record

```text
PTW_STAGE_DONE stage=5 name=P0 SVA and Cover Gate
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/top/mmu_ptw_top_sva.sv,
    mmu_verification/testbench/top/mmu_pde_cache_sva.sv,
    mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv,
    mmu_verification/testbench/top/mmu_twu_chk_sva.sv,
    mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv,
    mmu_verification/testbench/top/mmu_pmp_twu_sva.sv,
    mmu_verification/testbench/top/mmu_maee_twu_sva.sv,
    mmu_verification/testbench/top/mmu_sysmap_sva.sv,
    mmu_verification/testbench/top/mmu_l1dtlb_sva.sv,
    mmu_verification/testbench/top/tb_top.sv,
    mmu_verification/testbench/Files.f,
    doc/ptw_uvm_review/ptw_stage5_sva_gap_table.md,
    doc/ptw_uvm_review/ptw_implementation_process.md
  ]
  tests_run=[
    vlog -sv -work ./ptw_stage5_sva_work stage5_sva_files
      result=passed errors=0 warnings=0,
    vlog -sv -work ./ptw_stage5_sva_work mmu_l1dtlb_sva.sv
      result=passed errors=0 warnings=0,
    temporary bind-check compile of ptw/PDE_cache/one_to_four_xbar/twu/ptw_mbuf/mmu_l1dtlb
      plus Stage-5 SVA and bind statements
      result=passed errors=0 warnings=25,
    bind-check warnings were pre-existing ModelSim always_comb/vopt warnings in mmu_l1dtlb.sv
      plus compilation-unit bind elaboration guidance,
    attempted make -C mmu_verification comp_fast
      result=blocked_in_local_powershell reason=make_not_found,
    make -C mmu_verification comp_fast
      result=passed user_confirmed,
    make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=505 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
      result=passed user_confirmed
  ]
  environment_notes=[
    local PowerShell did not provide make during implementation, so full comp_fast/run_check exit-standard checks were completed and confirmed by user after implementation
  ]
  source_sb_summary=not_applicable_stage5_no_new_source_model
  sva_summary=stage5_exit_passed_user_confirmed
  closure_delta=[
    PTW-SVA-REQ-001..004 top request ready/hold/type cover,
    PTW-SVA-ARB-001..008 visible class priority/completion/target/layout cover,
    PTW-SVA-PDE-001..006 and PTW-SVA-PDE-008 clear/double-hit/hit-level/update/old-state cover,
    PTW-SVA-XBAR-001..006 hash/mask/abort/payload/hold cover,
    PTW-SVA-CHK-001..011 and PTW-SVA-WAIT-001..005 CHK/permission/wait cover,
    PTW-SVA-PMP-008..010 PTE PA/original permission/MBUF pass/deny cover,
    PTW-SVA-MBUF-001/002/006/008/009/010/011 LSU protocol, bus-error, abort cover,
    PTW-SVA-MAEE-001..006/010 MAEE/SysMap cover markers,
    L1D-SVA-PTW-001/003 consumer-only cover markers
  ]
  open_items=[
    stage5 probe gaps documented in doc/ptw_uvm_review/ptw_stage5_sva_gap_table.md,
    several deep CHK/PDE/MAEE/abort subitems require Stage 6 directed source-SB evidence
  ]
  next_stage_blockers=[
    Stage 6 directed tests should require PTW_SVA_COVER plus source scoreboard match
  ]
```

## Scope Guard

Stage 5 implementation and exit-standard checks are recorded as passed by user
confirmation. Stage 6 implementation and exit-standard checks are also recorded
as passed by user confirmation.

## Stage 6 Implementation Record

```text
PTW_STAGE_DONE stage=6 name=P0 Directed Tests and Legacy Conflict Fixes
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/env/mmu_ref_model.svh,
    mmu_verification/testbench/test/ptw_tests/test_ptw_stage6_p0_suite.svh,
    mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh,
    mmu_verification/testbench/test/ptw_tests/test_xbar_twu_round_robin.svh,
    mmu_verification/testbench/test/ptw_tests/test_pte_reserved_bits.svh,
    mmu_verification/testbench/test/ptw_tests/test_mbuf_ooo_response.svh,
    mmu_verification/simu/ptw_p0_list,
    mmu_verification/simu/ptw_source_closure_matrix.csv,
    mmu_verification/scripts/ptw_stage6_exit_gate.py,
    doc/ptw_uvm_review/ptw_stage6_p0_closure_report.md,
    doc/ptw_uvm_review/ptw_implementation_process.md
  ]
  tests_run=[
    python mmu_verification/scripts/ptw_stage6_exit_gate.py --help
      result=blocked_in_local_powershell reason=python_windowsapps_logon_session_error,
    python syntax parse for mmu_verification/scripts/ptw_stage6_exit_gate.py
      result=blocked_in_local_powershell reason=python_windowsapps_logon_session_error,
    rg marker/API checks for test_ptw_p0_*, PTW_STAGE6_CLOSURE, PTW_FLOW_BIND,
      obsolete-by-spec, and stage6 statuses
      result=passed,
    git diff --check -- stage6_touched_files
      result=passed,
    make -C mmu_verification comp_fast
      result=blocked_in_local_powershell reason=make_not_found,
    make -C mmu_verification comp_fast
      result=passed user_confirmed,
    make -C mmu_verification regress LIST=simu/ptw_p0_list REGRESS_MODE=run_check REGRESS_NAME=ptw_stage6_p0 REGRESS_SEEDS="606" REGRESS_JOBS=1 REGRESS_FAIL_FAST=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
      result=passed user_confirmed,
    python3 mmu_verification/scripts/ptw_stage6_exit_gate.py --list mmu_verification/simu/ptw_p0_list --log-dir mmu_verification/output/logs --seed 606 --closure doc/ptw_uvm_review/ptw_stage6_p0_closure_report.md --csv mmu_verification/simu/ptw_source_closure_matrix.csv
      result=passed user_confirmed
  ]
  environment_notes=[
    local PowerShell did not provide make and the WindowsApps python/python3 launchers failed with a logon-session error during implementation; full compile/regression/exit-gate checks were later completed and confirmed by user in the normal regression environment,
    Stage 6 intentionally uses 6 grouped P0 test classes rather than creating one file per requirement,
    no temporary stage task split plan was needed because created file count stayed below the requested threshold
  ]
  debug_record=[
    test_ptw_p0_pde_mbuf_pmp_matrix SEED=606 reported LSU_P2 fault mismatch in the old stage6_mprv_mpp_m_pfu_success consumer sanity,
    waveform/debug conclusion: MPRV=1 and MPP=M are valid MMU-wide effective-mode inputs, so PFU takes effective M-mode direct-map and does not walk the page table,
    root_cause: VA=0x0030704000 has PPN=0x0030704, which hits RTL default SysMap region1 from mmu_verification/testbench/common/mmu_rtl_defines.v and gets SYSMAP_FLG1=5'b10011,
    RTL behavior: PFU direct-map treats sysmap_flg4[4] || !sysmap_flg4[3] as access fault, so flg=0x13 correctly drives pfu_acc_fault/pa2_err/access_fault,
    scoreboard fix: mmu_ref_model.translate passthrough path now models PFU direct-map SysMap access fault from the compiled RTL default SysMap table,
    stimulus fix: stage6_mprv_mpp_m_pfu_direct_map_no_ptw now uses VA=0x0010704000, whose PPN=0x0010704 falls below SYSMAP_BASE_ADDR0 and receives SYSMAP_FLG0=5'b01111 for the intended VA=PA direct-map consumer case,
    closure fix: stage6_mprv_mpp_m_pfu_direct_map_no_ptw and matching LOAD direct-map case are recorded as consumer-only sanity because corrected spec requires MPRV=1/MPP=M data/PFU to avoid PTW; fetch remains real-privilege source behavior,
    test_ptw_p0_maee_sysmap_matrix SEED=606 later reported PTW_SOURCE_MISMATCH in stage6_maee0_4k_sysmap_refill with flg exp=0x2ee7 act=0x26e7,
    mismatch bit delta was 0x0800, i.e. refill attr bit[11]; expected attr[13:9]=0x17 came from UVM sysmap_cfg_agent mirror while actual attr[13:9]=0x13 came from compiled RTL SysMap behavior before the RTL THD query fix,
    debug conclusion: sysmap_cfg_agent currently mirrors configuration to sysmap_cfg_if only; its force path is disabled, so PTW source ref model must not expect ptw_sysmap_one_region flg values unless whitebox RTL force is implemented,
    RTL-side THD MAEE=0 SysMap query bit-slice issue was fixed separately by user; UVM-side fix changed ptw_source_ref_model sysmap_attr and mmu_ref_model rtl_default_sysmap_flg to use RTL compile-time SysMap macros with fallback constants,
    stimulus/ref-model fix: stage6_maee0_4k_sysmap_refill no longer injects the unforced 0x17 mirror configuration and now records expectation against RTL default SysMap region0 flg=0x0f for PA=0x03801000,
    documentation fix: sysmap_cfg_agent comments now state that configuration is a UVM mirror only until DA-003 whitebox force paths are implemented,
    post-debug result: user confirmed stage-6 task and exit-standard checks all passed
  ]
  source_sb_summary=stage6_exit_passed_user_confirmed PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0
  sva_summary=stage6_exit_passed_user_confirmed PTW_SVA_COVER hits>0 and assert_fail=0
  closure_delta=[
    PTW-ADD-001..034 mapped to stage6 directed evidence or explicit open reason,
    PTW-FLOW-001..023 bound by test_ptw_p0_flow_trace_umbrella to directed scenarios or explicit open reason,
    P0 list added at mmu_verification/simu/ptw_p0_list,
    P0 closure report added at doc/ptw_uvm_review/ptw_stage6_p0_closure_report.md,
    stage6 exit gate added at mmu_verification/scripts/ptw_stage6_exit_gate.py,
    legacy round-robin xbar, reserved/RSW fault, and PTW memory OOO wrappers marked not_source_closure/obsolete-by-spec
  ]
  open_items=[
    PTW-ADD-007 raw PDE double-hit L2-wins vector remains Stage 7 precision work,
    PTW-ADD-008 PDE lookup/update same-cycle old-state precision remains Stage 7,
    PTW-ADD-010 and PTW-FLOW-022 satp/PMP clear-only re-update remain Stage 7/TB gap,
    PTW-ADD-011/024 and PTW-FLOW-019 full abort/drop matrix remains Stage 7 ref/SB precision,
    PTW-ADD-013 and PTW-FLOW-010/011 isolated scd/thd PMP deny vectors remain Stage 7 vector work,
    PTW-ADD-027/028 and PTW-FLOW-004..007 MAEE=0 1G/2M degrade/no-lower-walk remain Stage 7 source-model precision,
    PTW-ADD-029 malformed/no-hit/multi-hit sysmap constraints remain Stage 7/8 signoff,
    PTW-ADD-030 context usage-point sampling remains Stage 7,
    PTW-ADD-032 remains consumer-only and cannot replace source-side closure
  ]
  next_stage_blockers=[
    none for Stage 6; Stage 7 can start from the remaining open precision/modeling items
  ]
```

## Stage 6 Exit Commands

```bash
make -C mmu_verification comp_fast

make -C mmu_verification regress \
  LIST=simu/ptw_p0_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage6_p0 \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

python3 mmu_verification/scripts/ptw_stage6_exit_gate.py \
  --list mmu_verification/simu/ptw_p0_list \
  --log-dir mmu_verification/output/logs \
  --seed 606 \
  --closure doc/ptw_uvm_review/ptw_stage6_p0_closure_report.md \
  --csv mmu_verification/simu/ptw_source_closure_matrix.csv

git diff --check -- \
  mmu_verification/testbench/env/mmu_ref_model.svh \
  mmu_verification/testbench/test/ptw_tests/test_ptw_stage6_p0_suite.svh \
  mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh \
  mmu_verification/testbench/test/ptw_tests/test_xbar_twu_round_robin.svh \
  mmu_verification/testbench/test/ptw_tests/test_pte_reserved_bits.svh \
  mmu_verification/testbench/test/ptw_tests/test_mbuf_ooo_response.svh \
  mmu_verification/simu/ptw_p0_list \
  mmu_verification/simu/ptw_source_closure_matrix.csv \
  mmu_verification/scripts/ptw_stage6_exit_gate.py \
  doc/ptw_uvm_review/ptw_stage6_p0_closure_report.md \
  doc/ptw_uvm_review/ptw_implementation_process.md
```

## Stage 7 Implementation Record

```text
PTW_STAGE_DONE stage=7 name=Reference/Scoreboard Complete P1/P2 Random Stress
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/testbench/env/mmu_ref_model.svh,
    mmu_verification/testbench/env/ptw_source_ref_model.svh,
    mmu_verification/testbench/env/ptw_source_sb.svh,
    mmu_verification/testbench/env/mmu_translation_sb.svh,
    mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh,
    mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh,
    mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh,
    mmu_verification/simu/ptw_p1_list,
    mmu_verification/simu/ptw_random_list,
    mmu_verification/simu/ptw_source_closure_matrix.csv,
    mmu_verification/scripts/ptw_stage7_exit_gate.py,
    doc/ptw_uvm_review/ptw_implementation_process.md
  ]
  tests_run=[
    rg marker checks for Stage7 tests, source-SB field coverage, ref summary,
      auxiliary drop handling, and consumer-only separation marker
      result=passed,
    Import-Csv structural check for mmu_verification/simu/ptw_source_closure_matrix.csv
      result=passed rows=128 cols=15,
    git diff --check -- stage7_touched_files
      result=passed,
    make -C mmu_verification comp_fast
      result=blocked_in_local_powershell reason=make_not_found,
    python3 mmu_verification/scripts/ptw_stage7_exit_gate.py --help
      result=blocked_in_local_powershell reason=python3_not_found_in_path,
    python mmu_verification/scripts/ptw_stage7_exit_gate.py --help
      result=blocked_in_local_powershell reason=python_not_found_in_path,
    make -C mmu_verification comp_fast
      result=passed user_confirmed,
    make -C mmu_verification regress LIST=simu/ptw_p1_list REGRESS_MODE=run_check REGRESS_NAME=ptw_stage7_p1 REGRESS_SEEDS="707" REGRESS_JOBS=1 REGRESS_FAIL_FAST=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
      result=passed user_confirmed,
    make -C mmu_verification regress LIST=simu/ptw_random_list REGRESS_MODE=run_check REGRESS_NAME=ptw_stage7_random REGRESS_SEEDS="707" REGRESS_JOBS=1 REGRESS_FAIL_FAST=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
      result=passed user_confirmed,
    python3 mmu_verification/scripts/ptw_stage7_exit_gate.py --list mmu_verification/simu/ptw_p1_list --list mmu_verification/simu/ptw_random_list --log-dir mmu_verification/output/logs --seed 707 --csv mmu_verification/simu/ptw_source_closure_matrix.csv
      result=passed user_confirmed
  ]
  implementation_notes=[
    completed Stage7 source ref model precision for current context mirror,
      refill-time ASID sampling, RTL-macro SysMap attributes, MAEE=0 1G/2M
      no-cross/degrade final page_size/PPN/flg modeling, satp/PMP clear-only
      PDE model clear/re-update behavior, and pre-existing exception grant
      auxiliary handling,
    completed Stage7 source scoreboard reporting for pending age debug,
      illegal-stimulus taxonomy, source field/function coverage summary,
      consumer-only separation marker, and auxiliary pre-existing exception
      drop ignore path,
    added P1 directed tests for satp old-walk re-update, PMP cfg clear no
      flush, ASID refill current sample, MAEE mid-sysmap change, and random
      PTE permission cross,
    added P2/constraint tests for same type/id no-reuse, Bare/M no-request,
      malformed SysMap constraint classification, and PTW memory OOO illegal
      classification without issuing illegal DUT source stimulus,
    added ptw_p1_list and ptw_random_list plus ptw_stage7_exit_gate.py for
      Stage7-only exit checks,
    no temporary phase split plan was needed because created file count stayed
      below the requested threshold
  ]
  debug_record=[
    Stage7 ASID refill current-sample: ref model now emits refill tag/data
      using current satp ASID at refill time rather than accept-time ASID,
      matching ptwspec usage-point sampling,
    Stage7 SysMap/MAEE: ref model continues to use RTL compile-time SysMap
      macros/fallback constants rather than the unforced UVM sysmap mirror;
      this preserves the Stage6 debug conclusion,
    Stage7 MAEE=0 degrade: ref model computes 1G no-cross, 1G->2M,
      1G->4K, 2M no-cross, and 2M->4K final PPN/page_size/flg, but closure
      matrix keeps dedicated cross/degrade directed coverage open or partial
      where no dedicated directed test was added in this stage,
    Stage7 MAEE mid-sysmap directed test waits for the whitebox SysMap/MAEE
      path marker before flipping MAEE when MMU_DUT_PROBES_VIF is available;
      it falls back to a timed switch only if the probe VIF is unavailable,
    Stage7 PMP cfg/no-flush directed test drives TWU PMP flags to 4'h5 rather
      than the default 4'h7 so pmp_monitor publishes a real cfg_update while
      keeping read permission enabled; the RTL pmp_regs_update clear proof
      remains an explicit top/probe tie-off gap,
    Stage7 abort/drop: pre-existing exception grant during abort is logged as
      auxiliary visible completion evidence and ignored for drop matching in
      both ref model and source scoreboard,
    Stage7 P2 constraints: illegal same type/id reuse, Bare/M no-request,
      malformed/no-hit/multi-hit SysMap setup, and PTW memory OOO are reported
      with PTW_STAGE7_ILLEGAL blocked_by_constraint markers and must not be
      treated as DUT source functional failures,
    Stage7 random permission cross: 2M/1G random leaf PA is explicitly aligned
      before mapping so the random profile stresses permission/context/source
      coverage rather than accidental huge-page misalignment,
    test_ptw_pde_satp_old_walk_reupdate_001 SEED=707 first reported a
      translation scoreboard page-fault mismatch on VA=0x0030a00000,
    debug conclusion: the original UVM expectation applied generic Sv39
      invalid/reserved PTE checks too early; RTL TWU gates FST/SCD page-fault
      terms with leaf_vld and only THD non-leaf/invalid encodings become the
      terminal page fault,
    UVM fix: mmu_translation_sb old-context shadow entries were corrected to
      use typed zero initialization, and mmu_ref_model/translation context
      handling was aligned to TWU leaf-gated page-fault behavior,
    Stage7 SATP/process-switch constraint was added: when satp changes for a
      process switch, LSU must issue an ASID-based tlboper invalidation that
      triggers PTW abort,
    the directed SATP old-walk test no longer requires a matching PTW accept
      before SATP switch as a hard failure; that observation is optional debug
      evidence because the scenario is still valid when no request reaches PTW
      before the process switch,
    compile cleanup fixed ptw_source_directed_base.svh use of SystemVerilog
      keyword context as an identifier and repaired an incomplete uvm_info macro
      call in test_ptw_stage7_suite.svh,
    test_ptw_random_pte_perm_cross_001 SEED=707 first reported LSU_P0 fault
      and PA mismatches on VA=0x0031004000/0x0031006000/0x0031007000,
    permission debug conclusion: for R=0,W=1,X=1,MXR=1, TWU may legally allow
      the refill because X is readable through MXR, but L1TLB hit permission
      logic still treats W=1,R=0 as a page fault; the UVM model must not use
      the TWU relaxed rule for L1TLB hit responses,
    huge-page cross debug conclusion: with MAEE=0, TWU may degrade 1G/2M
      refills at SysMap region boundaries by replacing lower PPN fields with
      VPN fields; LSU_P0/P1 mmu_l1dtlb_hit_rd exposes the installed L1DTLB
      entry PPN, while IFU/PFU paths expand the entry PPN according to pgs,
    UVM fix: mmu_ref_model now separates TWU walk fault semantics from L1TLB
      hit permission semantics, models MAEE=0 1G/2M SysMap cross/degrade PPN
      and page-size effects, keeps default translate() as final-output PPN,
      and lets LSU translation scoreboard request L1DTLB entry-PPN semantics
  ]
  source_sb_summary=stage7_exit_passed_user_confirmed PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 unexpected_illegal=0
  translation_sb_summary=stage7_exit_passed_user_confirmed Translation SB mismatch=0
  sva_summary=stage7_exit_passed_user_confirmed assert_fail=0 required_cover_gate_passed
  closure_delta=[
    PTW-ADD-010 and PTW-FLOW-022 now have Stage7 satp old-walk re-update
      evidence; PMP cfg clear no-flush remains partial because pmp_regs_update
      is still tied off at the top/probe path,
    PTW-ADD-016..019 and PTW-ADD-033 are strengthened by the Stage7 random PTE
      permission cross and source-SB field coverage,
    PTW-ADD-026/030 and MAEE-TP-012 are strengthened/closed by ASID current
      refill and MAEE mid-sysmap no-rollback directed tests,
    PTW-ADD-027/028 and PTW-FLOW-004..007 gain Stage7 ref-model support and
      selected no-cross random evidence, while dedicated 1G/2M cross/degrade
      directed closure remains open/partial,
    PTW-ADD-029/035/036 gain P2 illegal constraint classification evidence,
      with consumer-only evidence still prevented from source-side closure,
    PTW-INFRA-001/003 are Stage7 implemented; PTW-INFRA-007 is model-ready
      with full directed degrade closure still open; PTW-INFRA-009 has a
      Stage7 gate but final signoff parser remains Stage8
  ]
  open_items=[
    PTW-ADD-007 raw PDE double-hit L2-wins vector remains open,
    PTW-ADD-008 and PDE-TP-009 lookup/update old-state precision still need
      dedicated directed proof beyond current abstract model support,
    PDE-TP-012 PLRU/victim directed test remains open,
    PTW-ADD-011/024 and PTW-FLOW-019 full abort data/bus-error/drop matrix
      remains open beyond the auxiliary pre-existing exception grant fix,
    PTW-ADD-013 and PTW-FLOW-010/011 isolated scd/thd PMP deny vectors remain
      open,
    PTW-ADD-027/028 and MAEE-TP-005/006/008/010 need dedicated cross/degrade
      directed evidence to close fully,
    Stage8 final report/parser/signoff and consumer evidence list remain out
      of Stage7 scope
  ]
  next_stage_blockers=[
    none for Stage 7 exit; Stage 8 can start from report/parser/signoff and
      remaining accepted open/waiver cleanup
  ]
```

## Stage 7 Exit Commands

```bash
make -C mmu_verification comp_fast

make -C mmu_verification regress \
  LIST=simu/ptw_p1_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage7_p1 \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

make -C mmu_verification regress \
  LIST=simu/ptw_random_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage7_random \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

python3 mmu_verification/scripts/ptw_stage7_exit_gate.py \
  --list mmu_verification/simu/ptw_p1_list \
  --list mmu_verification/simu/ptw_random_list \
  --log-dir mmu_verification/output/logs \
  --seed 707 \
  --csv mmu_verification/simu/ptw_source_closure_matrix.csv

git diff --check -- \
  mmu_verification/testbench/env/ptw_source_ref_model.svh \
  mmu_verification/testbench/env/ptw_source_sb.svh \
  mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh \
  mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh \
  mmu_verification/testbench/test/ptw_tests/test_ptw_stage7_suite.svh \
  mmu_verification/simu/ptw_p1_list \
  mmu_verification/simu/ptw_random_list \
  mmu_verification/simu/ptw_source_closure_matrix.csv \
  mmu_verification/scripts/ptw_stage7_exit_gate.py \
  doc/ptw_uvm_review/ptw_implementation_process.md
```

## Stage 8 Implementation Record

```text
PTW_STAGE_DONE stage=8 name=Regression Report Signoff Freeze
  status=done
  exit_criteria=passed
  confirmation=user-confirmed
  changed_files=[
    mmu_verification/simu/ptw_p0_smoke_list,
    mmu_verification/simu/ptw_p2_illegal_list,
    mmu_verification/simu/ptw_random_list,
    mmu_verification/simu/ptw_consumer_evidence_list,
    mmu_verification/simu/ptw_source_closure_matrix.csv,
    mmu_verification/scripts/ptw_stage8_signoff_gate.py,
    mmu_verification/testbench/env/ptw_source_sb.svh,
    mmu_verification/testbench/env/mmu_l1dtlb_vseq_lib.svh,
    doc/ptw_uvm_review/ptw_source_signoff_report.md,
    doc/ptw_uvm_review/ptw_implementation_process.md
  ]
  tests_run=[
    CSV_FIELD_CHECK for mmu_verification/simu/ptw_source_closure_matrix.csv
      result=passed rows=129 fields=15,
    REPORT_OPEN_CHECK for doc/ptw_uvm_review/ptw_source_signoff_report.md
      result=passed open_records=59,
    rg marker checks for PTW_STAGE8_SIGNOFF_REPORT, PTW_SIGNOFF_OPEN,
      PTW_SIGNOFF_NO_GLOBAL_WAIVER, PTW_SIGNOFF_CLOSURE_MATRIX,
      obsolete-by-spec legacy freeze tokens, and gate script entry points
      result=passed,
    git diff --check -- stage8_touched_files
      result=passed,
    Stage8 full exit-standard checks
      result=passed source=user-confirmed,
    python/python3 --version
      result=blocked_in_local_powershell reason=WindowsApps logon-session error,
    make -C mmu_verification comp_fast and Stage8 regressions
      result=passed_in_normal_linux_vcs_env source=user-confirmed
  ]
  implementation_notes=[
    no temporary phase split plan was needed because Stage8 created fewer than 15 files,
    no digital IC verification skill was available in the current skill list, so implementation used the staged plan and existing scripts as the source of process,
    added ptw_p0_smoke_list as a fast P0 source sanity subset while retaining ptw_p0_list as the full P0 gate,
    separated P2/illegal constraints into ptw_p2_illegal_list so ptw_random_list is random/stress only,
    added ptw_consumer_evidence_list for downstream L1D/L1I/L2 evidence that cannot close PTW source-side requirements,
    added ptw_stage8_signoff_gate.py to validate P0 source scoreboard summaries, P0 SVA cover hits, P1/P2/random status, closure CSV integrity, final signoff report markers, open records, legacy freeze, and waiver rules,
    added ptw_source_signoff_report.md with regression package, flow status, no-waiver statement, consumer-only register, debug semantic freeze, and machine-readable PTW_SIGNOFF_OPEN records,
    fixed PTW-INFRA rows in ptw_source_closure_matrix.csv to have exactly the frozen 15 CSV fields and Stage8-readable status/action/reason columns,
    fixed source scoreboard active-key retirement to use visible DUT completion/drop as the legal same type/id reuse boundary,
    fixed DTLB_MB_PGFLT_001 directed raw stimulus so each faulting LSU request is paired: first request writes the PTW page fault into L1DTLB MB, second request consumes the MB exception and no further retry request is generated,
    made ptw_stage8_signoff_gate.py compatible with older Python3 by removing future annotations and PEP585/PEP604 type syntax
  ]
  debug_record=[
    permission_matrix debug conclusion: same_type_id_reuse in test_ptw_p0_permission_matrix_606 was a UVM scoreboard lifecycle issue, not RTL; a request that has produced a visible DUT completion/drop must release its active type/id key even if expected/actual queue matching completes later,
    scoreboard fix: collect_actual now retires the active key after queuing the actual completion and before try_match_key, preserving mismatch/pending checking while preventing false illegal-stimulus reports after page/access fault completion,
    auxiliary drop fix: keyed pre_existing_exception_grant drops retire the active key because they are visible completion/drop-like endpoints for reuse legality,
    L1DTLB consumer debug conclusion: TLB busy timeout in test_mmu_l1dtlb_dtlb_mb_pgflt_001_707 was caused by UVM directed stimulus leaving PGFLT miss-buffer entries unconsumed; RTL was holding state as expected until a matching LSU replay consumed the exception CAM,
    directed-stimulus fix: DTLB_MB_PGFLT_001 now uses raw-only paired requests per pipe/VA/IID, with no automatic retrying LSU driver in that scenario, so the first request walks and writes PGFLT and the second request reports it to LSU and clears the MB,
    signoff-gate debug conclusion: the Linux regression environment used an older Python3 that rejects from __future__ import annotations and newer generic type syntax; the gate script was downgraded to typing.Dict/List/Optional/Set/Tuple annotations,
    command-line note: stage8 signoff gate should be invoked with shell continuation backslash at line end, not as backslash-space before the next option,
    post-debug result: user confirmed stage-8 task and exit-standard checks all passed
  ]
  source_sb_summary=stage8_gate_requires P0 PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0
  sva_summary=stage8_gate_requires P0 PTW_SVA_COVER hits>0 and assert_fail=0
  closure_delta=[
    PTW-INFRA-009 implemented by mmu_verification/scripts/ptw_stage8_signoff_gate.py,
    final regression lists frozen for p0_smoke, p0_full, p1_directed, p2_illegal, random_stress, and consumer_only roles,
    PTW-FLOW-001..023 status is reviewable in the signoff report and every open/partial flow has an explicit PTW_SIGNOFF_OPEN owner and next action,
    waiver register frozen with count=0 and explicit prohibition on global waiver for flg/page_size/ppn/fault_kind/target mismatches,
    obsolete-by-spec legacy tests are frozen as not counted for PTW source closure,
    consumer-only evidence is separated from source-side closure in list/report/gate
  ]
  open_items=[
    all open/partial items listed in doc/ptw_uvm_review/ptw_source_signoff_report.md remain open by design and are not waived,
    no global source waiver exists; any future waiver must be narrow and must not cover flg/page_size/ppn/fault_kind/target mismatches
  ]
  next_stage_blockers=[
    none within Stage8 scope; remaining open items are explicitly tracked as post-Stage8 closure work
  ]
```

## Stage 8 Exit Commands

```bash
make -C mmu_verification comp_fast

make -C mmu_verification regress \
  LIST=simu/ptw_p0_smoke_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage8_p0_smoke \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

make -C mmu_verification regress \
  LIST=simu/ptw_p0_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage8_p0_full \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

make -C mmu_verification regress \
  LIST=simu/ptw_p1_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage8_p1 \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

make -C mmu_verification regress \
  LIST=simu/ptw_p2_illegal_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage8_p2_illegal \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

make -C mmu_verification regress \
  LIST=simu/ptw_random_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage8_random \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

make -C mmu_verification regress \
  LIST=simu/ptw_consumer_evidence_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_stage8_consumer \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  REGRESS_FAIL_FAST=1 \
  UVM_CONFIG_DB_TRACE=0 \
  UVM_ERR_ONLY=1

python3 mmu_verification/scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list mmu_verification/simu/ptw_p0_smoke_list \
  --p0-list mmu_verification/simu/ptw_p0_list \
  --p1-list mmu_verification/simu/ptw_p1_list \
  --p2-list mmu_verification/simu/ptw_p2_illegal_list \
  --random-list mmu_verification/simu/ptw_random_list \
  --consumer-list mmu_verification/simu/ptw_consumer_evidence_list \
  --log-dir mmu_verification/output/logs \
  --p0-seed 606 \
  --stage7-seed 707 \
  --consumer-seed 707 \
  --csv mmu_verification/simu/ptw_source_closure_matrix.csv \
  --report doc/ptw_uvm_review/ptw_source_signoff_report.md \
  --legacy doc/ptw_uvm_review/ptw_legacy_test_action_list.md

git diff --check -- \
  mmu_verification/simu/ptw_p0_smoke_list \
  mmu_verification/simu/ptw_p0_list \
  mmu_verification/simu/ptw_p1_list \
  mmu_verification/simu/ptw_p2_illegal_list \
  mmu_verification/simu/ptw_random_list \
  mmu_verification/simu/ptw_consumer_evidence_list \
  mmu_verification/simu/ptw_source_closure_matrix.csv \
  mmu_verification/scripts/ptw_stage8_signoff_gate.py \
  doc/ptw_uvm_review/ptw_source_signoff_report.md \
  doc/ptw_uvm_review/ptw_implementation_process.md
```

## Stage 10 Implementation Record

```text
PTW_STAGE_DONE stage=10 name=PDE PMPFLG Regression Closure Matrix Signoff Gate Freeze
  status=done
  exit_criteria=pending_user_regression
  changed_files=[
    mmu_verification/simu/ptw_p0_smoke_list,
    mmu_verification/simu/ptw_p0_list,
    mmu_verification/simu/ptw_source_closure_matrix.csv,
    mmu_verification/scripts/ptw_stage8_signoff_gate.py,
    doc/ptw_uvm_review/ptw_source_closure_matrix.md,
    doc/ptw_uvm_review/ptw_source_signoff_report.md,
    doc/ptw_uvm_review/ptw_implementation_process.md,
    doc/ptw_uvm_review/ptw_pde_cache_pmpflg_all_stages_progress.md
  ]
  implementation_notes=[
    final pde-pmpflg directed list was already complete from Stage8/9 and is now gate-checked as a dedicated role,
    p0_smoke_list now includes representative pde-pmpflg L1 deny and valid-gate tests,
    p0_list now includes Stage8 P0 pde-pmpflg tests plus explicit open/unreachable marker tests,
    p1_list already includes priority and clear/repopulate Stage9 tests,
    closure CSV now requires PTW-ADD-037..045, PDE-TP-013..019, and PTW-FLOW-024..028,
    signoff gate now checks PTW_SOURCE_SB_PDE_PMP_COVERAGE, required PTW-SVA-PDE/ARB cover hits, no_extra_lsu, and explicit open/partial markers,
    no new functional tests, ref model, scoreboard, SVA behavior, or RTL were changed in Stage10
  ]
  open_items=[
    PTW-ADD-040/PDE-TP-015/PTW-FLOW-026 remain open-unreachable from top-level source traffic because data/PFU MPRV=1 MPP=M direct-map and do not enter PTW,
    PTW-ADD-043/PDE-TP-018/PTW-FLOW-028 remain open-unreachable from top-level source traffic because fetch ignores MPRV/MPP and data/PFU do not enter PTW,
    PTW-ADD-039/PDE-TP-014/PTW-FLOW-025 remain partial because the current flag-only PMP agent cannot independently assign FST and SCD page-table pmpflg in a normal full walk,
    PTW-ADD-045 remains partial for exact PMP-config-update clear because pmp_regs_update is tied off in tb_top
  ]
  local_checks=[
    CSV structural and required-id check passed in PowerShell,
    python/python3 local execution blocked by WindowsApps logon-session issue,
    make not run locally; run exit regressions in normal VCS environment
  ]
  environment_notes=[
    local PowerShell may not have make; run the listed Stage10 exit commands in the normal regression environment
  ]
```

## Stage 10 Exit Commands

```bash
make regress LIST=simu/ptw_pde_pmpflg_list REGRESS_MODE=run_check REGRESS_NAME=ptw_pde_pmpflg_signoff REGRESS_SEEDS="606 707" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
make regress LIST=simu/ptw_p0_smoke_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_smoke_pmpflg_signoff REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
make regress LIST=simu/ptw_p0_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_pmpflg_signoff REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
make regress LIST=simu/ptw_p1_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p1_pmpflg_signoff REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1

python3 mmu_verification/scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list mmu_verification/simu/ptw_p0_smoke_list \
  --p0-list mmu_verification/simu/ptw_p0_list \
  --p1-list mmu_verification/simu/ptw_p1_list \
  --pde-pmpflg-list mmu_verification/simu/ptw_pde_pmpflg_list \
  --p2-list mmu_verification/simu/ptw_p2_illegal_list \
  --random-list mmu_verification/simu/ptw_random_list \
  --consumer-list mmu_verification/simu/ptw_consumer_evidence_list \
  --log-dir mmu_verification/output/logs \
  --p0-seed 606 \
  --p1-seed 606 \
  --stage7-seed 707 \
  --pde-pmpflg-seed 606 \
  --pde-pmpflg-seed 707 \
  --consumer-seed 707 \
  --csv mmu_verification/simu/ptw_source_closure_matrix.csv \
  --report doc/ptw_uvm_review/ptw_source_signoff_report.md \
  --legacy doc/ptw_uvm_review/ptw_legacy_test_action_list.md

git diff --check -- \
  mmu_verification/simu/ptw_p0_smoke_list \
  mmu_verification/simu/ptw_p0_list \
  mmu_verification/simu/ptw_p1_list \
  mmu_verification/simu/ptw_pde_pmpflg_list \
  mmu_verification/simu/ptw_source_closure_matrix.csv \
  mmu_verification/scripts/ptw_stage8_signoff_gate.py \
  doc/ptw_uvm_review/ptw_source_closure_matrix.md \
  doc/ptw_uvm_review/ptw_source_signoff_report.md \
  doc/ptw_uvm_review/ptw_implementation_process.md \
  doc/ptw_uvm_review/ptw_pde_cache_pmpflg_all_stages_progress.md
```
