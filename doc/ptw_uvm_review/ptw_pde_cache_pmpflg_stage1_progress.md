# PTW PDE Cache PMP Flag Stage 1 Progress

## 当前状态

`PMPFLG_STAGE_DONE stage=0 name=semantic_freeze_and_probe_audit`

状态：done

`PMPFLG_STAGE_DONE stage=1 name=common_types_and_transaction_schema`

状态：done

阶段 1 只完成公共类型、helper 和 transaction schema 扩展；未接 probe，未修改 monitor 采样逻辑，未修改 ref model/SB 行为，未新增 test，未修改 regression list。

## Stage 0 完成确认

Stage 0 已完全完成，当前可追溯文档为：

| 文件 | 状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | done |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_progress.md` | done |

Stage 0 open gap 仍按 probe map 保留，作为 Stage 2/6 的输入；这些 gap 不阻塞 Stage 1 schema 扩展。

## Stage 1 完成内容

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 新增 PDE reason/access source enum；新增 cached pmpflg allow helper；扩展 expected/level/PDE transaction 字段；更新 `convert2string()`。 |

未修改文件：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | include 顺序已满足要求，无需修改。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 阶段 1 禁止修改 monitor 采样逻辑。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 阶段 1 禁止修改 ref model 行为。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 阶段 1 禁止修改 scoreboard compare 行为。 |

## 新增类型与 helper

| 类别 | 名称 |
| --- | --- |
| enum | `ptw_src_pde_reason_e` |
| enum | `ptw_src_access_src_e` |
| helper | `ptw_src_pde_pmp_type_bit_allow()` |
| helper | `ptw_src_pde_pmp_allow()` |
| helper | `ptw_src_pde_reason_name()` |
| helper | `ptw_src_access_src_name()` |
| helper | `ptw_src_is_data_type()` |

Helper 语义：

| Request type | cached PMP bit |
| --- | --- |
| `PTW_SRC_TYPE_LOAD` | `pmpflg[0]` |
| `PTW_SRC_TYPE_PFU` | `pmpflg[0]` |
| `PTW_SRC_TYPE_STORE` | `pmpflg[1]` |
| `PTW_SRC_TYPE_FETCH` | `pmpflg[2]` |
| effective M-mode bypass | `effective_m && pmpflg[3] == 0` |

## Transaction Schema Delta

| Transaction | 新增字段 |
| --- | --- |
| `ptw_src_pde_evt_txn` | `l1_tag_hit`, `l2_tag_hit`, permission allow fields, cached/update pmpflg, `mbuf_pmpflg`, `direct_accerr`, `reason`, `access_src`, accerr type/id/grant, raw tag/accerr vectors。 |
| `ptw_src_level_evt_txn` | `twu_mbuf_pmpflg`, `mbuf_pmpflg`, `selected_pmpflg`。 |
| `ptw_src_expected_rsp_txn` | `access_src`, `pde_reason`, `pde_l1pmpflg`, `pde_l2pmpflg`, `pde_direct_accerr`。 |

新增字段在 constructor 中使用 safe default，避免旧 smoke 在未采样新 probe 时打印随机值。

## 本阶段未关闭项

| Item | 后续阶段 |
| --- | --- |
| 新字段尚未由 monitor 赋值 | Stage 2 |
| PDE cache model 尚未使用 helper | Stage 3 |
| ref model 尚未生成 PDE direct accerr expected | Stage 4 |
| scoreboard 尚未比较 `access_src/pde_reason` | Stage 5 |
| SVA/cover 尚未消费新语义 | Stage 6 |

## 已执行检查

| 检查 | 结果 |
| --- | --- |
| `rg` 检查新增 enum/helper/字段 | pass |
| `git diff --name-only -- "mmu_verification/testbench/env/*.svh" "mmu_verification/testbench/env/*.sv"` | pass，仅 `ptw_source_types.svh` 有 SV/SVH 修改 |
| `git diff --check` | pass，仅有 Git 换行格式提示 |
| `make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke` | blocked，当前 PowerShell 环境找不到 `make` |
| `make -C mmu_verification run_check ...` | blocked，当前 PowerShell 环境找不到 `make` |

## Exit Check Commands

```powershell
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "ptw_src_pde_reason_e|ptw_src_access_src_e|ptw_src_pde_pmp_allow|pde_direct_accerr|cached_l1pmpflg" mmu_verification/testbench/env/ptw_source_types.svh
git diff --name-only -- "mmu_verification/testbench/env/*.svh" "mmu_verification/testbench/env/*.sv"
```
