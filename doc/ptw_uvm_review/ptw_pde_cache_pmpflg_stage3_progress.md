# PTW PDE Cache PMP Flag Stage 3 Progress

## 当前状态

`PMPFLG_STAGE_DONE stage=2 name=probe_wiring_and_monitor_sampling`

状态：done

`PMPFLG_STAGE_DONE stage=3 name=pde_cache_abstract_model_refactor`

状态：done

阶段 3 只完成 PDE cache abstract model 的 permission-qualified 重构；未修改 monitor，未生成 expected completion，未修改 scoreboard，未新增 tests。

## Stage 2 完成确认

Stage 2 已完全完成，当前可追溯文档为：

| 文件 | 状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage2_progress.md` | done |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | done |
| `mmu_verification/testbench/top/tb_top.sv` | done |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | done |

## Stage 3 完成内容

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | `pde_entry_s` 保存 `l1pmpflg/l2pmpflg`；新增 `pde_lookup_result_s`；新增 permission-qualified `lookup_detail()`；update API 支持 pmpflg；保留旧 lookup/update 兼容；新增 debug dump/helper。 |

## Lookup 语义

| 场景 | model 行为 |
| --- | --- |
| L2 tag hit 且 L1/L2 cached PMP allow | `lookup_hit=1`、`l2_hit=1`、`hit_level=THD`，更新 L2 age。 |
| L2 tag hit 但任一级 cached PMP deny | `l2_direct_accerr=1`，返回 `L2_L1PMP_DENY`、`L2_L2PMP_DENY` 或 `L2_BOTH_PMP_DENY`，不 fallback 到 L1，不更新 age。 |
| L1 tag hit 且 cached PMP allow | `lookup_hit=1`、`l1_hit=1`、`hit_level=SCD`，更新 L1 age。 |
| L1 tag hit 但 cached PMP deny | `l1_deny_miss=1`、`reason=L1_PMP_DENY`，不更新 age。 |
| all-allow pmpflg 默认 | 旧 `lookup(vpn, ...)`、旧 `queue_update(level,vpn,ppn)`、旧 `commit_update(level,vpn,ppn)` 行为保持 tag-only 兼容。 |

## API Delta

| API | 状态 |
| --- | --- |
| `lookup(vpn, hit_level, hit_ppn, l1_hit, l2_hit)` | 保留，内部用 all-allow/default LOAD 兼容旧调用。 |
| `lookup_detail(vpn, req_type, effective_m, update_plru)` | 新增，返回 raw tag hit、qualified hit、deny/direct accerr reason。 |
| `queue_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim)` | 扩展，pmpflg 默认 all-allow。 |
| `commit_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim)` | 扩展，pmpflg 默认 all-allow。 |
| `queue_update_with_pmpflg()` / `commit_update_with_pmpflg()` | 新增显式别名，便于 Stage 4 接入。 |
| `lookup_result2string()` / `dump_string()` | 新增 debug helper。 |

## 本阶段未关闭项

| Item | 后续阶段 |
| --- | --- |
| ref model 尚未调用 `lookup_detail()` 消费 deny/direct accerr 结果 | Stage 4 |
| scoreboard 尚未比较 `reason/access_src/direct_accerr` | Stage 5 |
| SVA/cover 尚未证明 permission-qualified hit 与 direct accerr gate | Stage 6 |

## 已执行检查

| 检查 | 结果 |
| --- | --- |
| `rg` 检查 model 新增字段/API/reason | pass |
| 旧 ref model 调用点兼容性检查 | pass，仍为旧 `lookup()` 和 3 参数 update 调用 |
| `git diff --name-only -- "mmu_verification/testbench/env/*.svh" "mmu_verification/testbench/env/*.sv"` | pass，仅 `ptw_pde_cache_model.svh` |
| ref/SB/monitor/SVA/test 边界检查 | pass，无相关文件修改 |
| `git diff --check` | pass，仅有 Git 换行格式提示 |
| `make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke` | blocked，当前 PowerShell 环境找不到 `make` |

## Exit Check Commands

```powershell
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
rg -n "l1pmpflg|l2pmpflg|lookup_detail|pde_lookup_result|direct_accerr|L2_L.*DENY" mmu_verification/testbench/env/ptw_pde_cache_model.svh
rg -n "queue_update_with_pmpflg|commit_update_with_pmpflg|lookup_result2string|dump_string" mmu_verification/testbench/env/ptw_pde_cache_model.svh
git diff --name-only -- "mmu_verification/testbench/env/*.svh" "mmu_verification/testbench/env/*.sv"
git diff --check
```
