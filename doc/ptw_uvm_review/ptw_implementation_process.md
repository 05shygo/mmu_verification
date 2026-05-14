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
| 5 | P0 SVA and Cover Gate | implemented | pending user run | Stage-5 SVA/bind/filelist/report markers implemented; local SVA-only ModelSim compile passed. |

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
  status=implemented
  exit_criteria=pending_full_regression
  confirmation=not_user_confirmed_yet
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
      result=blocked reason=make_not_found_in_local_powershell
  ]
  source_sb_summary=not_applicable_stage5_no_new_source_model
  sva_summary=local_sva_compile_passed_full_make_pending
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
    full make comp_fast/run_check not executed locally in this record,
    local PowerShell does not provide make; user should run exit-standard commands in the normal regression environment,
    stage5 probe gaps documented in doc/ptw_uvm_review/ptw_stage5_sva_gap_table.md,
    several deep CHK/PDE/MAEE/abort subitems require Stage 6 directed source-SB evidence
  ]
  next_stage_blockers=[
    run full Stage 5 exit commands before marking exit_criteria=passed,
    Stage 6 directed tests should require PTW_SVA_COVER plus source scoreboard match
  ]
```

## Scope Guard

Stage 5 implementation is present, but the full regression exit gate still must
be run before marking Stage 5 passed. No stage-6 directed test closure is
recorded as completed here.
