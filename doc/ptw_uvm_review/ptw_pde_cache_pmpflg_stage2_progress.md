# PTW PDE Cache PMP Flag Stage 2 Progress

## 当前状态

`PMPFLG_STAGE_DONE stage=1 name=common_types_and_transaction_schema`

状态：done

`PMPFLG_STAGE_DONE stage=2 name=probe_wiring_and_monitor_sampling`

状态：done

阶段 2 只完成 probe 接入与 monitor actual event 采样；未修改 ref model expected，未修改 scoreboard compare，未新增 SVA，未新增 directed tests。

## Stage 1 完成确认

Stage 1 已完全完成，当前可追溯文档为：

| 文件 | 状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage1_progress.md` | done |
| `mmu_verification/testbench/env/ptw_source_types.svh` | done |

## Stage 2 完成内容

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | 新增 pmpflg payload、PDE update pmpflg、raw tag hit、cached pmpflg、direct accerr、accerr grant probes 和 clocking input。 |
| `mmu_verification/testbench/top/tb_top.sv` | 将 RTL `mbuf_cache_upd_*pmpflg`、`twu_mbuf_pmpflg`、`mbuf_twu_pmpflg`、`mbuf_entry_pmpflg`、`PDE_cache_acc_err_*`、`L2PDE_entry_acc_err`、cached pmpflg/raw tag hit vectors 连接到 probe interface。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 采样 level/PDE event 的 pmpflg、raw tag hit、permission allow、direct accerr root cause，并增加 summary counters。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | 更新 Stage 2 对 Stage 0 gap 的关闭/部分关闭状态。 |

## Monitor Event Delta

| Event | 新增采样 |
| --- | --- |
| `PTW_LEVEL_EVT` | `twu_mbuf_pmpflg`、`mbuf_pmpflg`、`selected_pmpflg`。 |
| `PTW_PDE_EVT` hit/miss | `l1_tag_hit/l2_tag_hit`、permission allow、cached pmpflg、L2 direct accerr vector、`reason/access_src`。 |
| `PTW_PDE_EVT` update | `update_l1pmpflg/update_l2pmpflg`、`mbuf_pmpflg`、update vectors。 |
| `PTW_PDE_EVT` direct accerr | `direct_accerr=1`、`accerr_type/id/grant`、`PDE_CACHE_PMP_DENY` source。 |

## Monitor Summary Counters

| Counter | 含义 |
| --- | --- |
| `pde_pmpflg_update` | PDE cache update event 数量。 |
| `pde_l1_deny_miss` | L1 tag hit 但 cached PMP deny，表现为 miss 的 event 数量。 |
| `pde_direct_accerr` | PDE cache direct access fault event 数量。 |

## 本阶段未关闭项

| Item | 后续阶段 |
| --- | --- |
| probe/monitor 已有 actual event，但 ref model 尚未消费 | Stage 4 |
| scoreboard 尚未比较 `reason/access_src/direct_accerr` | Stage 5 |
| pending/type-id/priority/valid gate assertion 尚未实现 | Stage 6 |
| `pmp_regs_update` testbench tie-off 未处理 | 后续涉及 PMP config clear/repopulate 的阶段 |

## 已执行检查

| 检查 | 结果 |
| --- | --- |
| `rg` 检查新增 probe/monitor 字段 | pass |
| `rg` 检查 RTL 被观测层级信号存在 | pass |
| `git diff --name-only -- "mmu_verification/testbench/**/*.sv" "mmu_verification/testbench/**/*.svh"` | pass，仅阶段 2 允许的 3 个 SV/SVH 文件 |
| `git diff --name-only` 检查 ref/SB/SVA/test 边界 | pass，无相关文件修改 |
| `git diff --check` | pass，仅有 Git 换行格式提示 |
| `make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke` | blocked，当前 PowerShell 环境找不到 `make` |
| `make -C mmu_verification run_check ...` | blocked，当前 PowerShell 环境找不到 `make` |

## Exit Check Commands

```powershell
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "pde_cache_update_l1pmpflg|pde_cache_update_l2pmpflg|pde_cache_acc_err|ptw_mbuf_twu_pmpflg|ptw_twu_mbuf_pmpflg" mmu_verification/testbench/env/mmu_dut_probes_if.sv mmu_verification/testbench/top/tb_top.sv mmu_verification/testbench/env/ptw_source_monitor.svh
rg -n "pde_pmpflg_update|pde_l1_deny_miss|pde_direct_accerr|l1_tag_hit_vec|l2_accerr_vec" mmu_verification/testbench/env/ptw_source_monitor.svh
git diff --name-only -- "mmu_verification/testbench/**/*.sv" "mmu_verification/testbench/**/*.svh"
git diff --check
```
