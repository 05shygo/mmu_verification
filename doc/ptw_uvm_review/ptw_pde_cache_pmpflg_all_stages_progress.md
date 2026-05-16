# PTW PDE Cache PMP Flag All Stages Progress

更新时间：2026-05-16

本文档汇总 `ptw_pde_cache_pmpflg_staged_implementation_plan.md` 中各阶段的执行进度。阶段 0 到阶段 4 已完成；阶段 5 及之后尚未开始。原阶段独立进度文件已合并到本文档，后续以本文档作为统一进度记录。

## 总体状态

| 阶段 | 名称 | 状态 | 当前产出 |
| --- | --- | --- | --- |
| 0 | semantic freeze and probe audit | done | `ptw_pde_cache_pmpflg_stage0_probe_map.md` |
| 1 | common types and transaction schema | done | `ptw_source_types.svh` |
| 2 | probe wiring and monitor sampling | done | probe if、`tb_top.sv`、`ptw_source_monitor.svh` |
| 3 | pde cache abstract model refactor | done | `ptw_pde_cache_model.svh` |
| 4 | reference model integration | done | `ptw_source_ref_model.svh` |
| 5 | scoreboard and coverage enhancement | not started | 未开始 |
| 6 | SVA and cover | not started | 未开始 |
| 7 | directed helper and legacy PDE tests update | not started | 未开始 |
| 8 | new P0 directed tests A | not started | 未开始 |
| 9 | new P0/P1 directed tests B | not started | 未开始 |
| 10 | regression and signoff freeze | not started | 未开始 |

阶段完成标记：

```text
PMPFLG_STAGE_DONE stage=0 name=semantic_freeze_and_probe_audit
PMPFLG_STAGE_DONE stage=1 name=common_types_and_transaction_schema
PMPFLG_STAGE_DONE stage=2 name=probe_wiring_and_monitor_sampling
PMPFLG_STAGE_DONE stage=3 name=pde_cache_abstract_model_refactor
PMPFLG_STAGE_DONE stage=4 name=source_reference_model_integration
```

## 阶段 0 进度

状态：done

本阶段只完成语义冻结和信号审计，没有修改 RTL/UVM SystemVerilog 源码，没有新增 tests，没有修改 regression list。

完成内容：

| 类别 | 内容 |
| --- | --- |
| 输入文档审阅 | `ptw_pde_cache_pmpflg_design_change.md`、`ptw_pde_cache_pmpflg_uvm_implementation_plan.md`、`ptw_pde_cache_pmpflg_staged_implementation_plan.md`、`ptwspec.md` |
| RTL 审计 | `L1PDE_cache.sv`、`L2PDE_cache.sv`、`PDE_cache.sv`、`mbuf_entry.sv`、`ptw_mbuf.sv`、`twu.sv`、`ptw.sv` |
| UVM/SVA 审计 | `mmu_dut_probes_if.sv`、`tb_top.sv`、`ptw_source_types.svh`、`ptw_source_monitor.svh`、`ptw_pde_cache_model.svh`、`mmu_pde_cache_sva.sv`、`mmu_ptw_top_sva.sv` |
| 新增审计文档 | `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` |

主要结论：

| 结论 | 说明 |
| --- | --- |
| RTL 已有 cached pmpflg 语义 | L1/L2 PDE cache entry 已保存 pmpflg，并存在 permission-qualified hit 逻辑。 |
| RTL 已有 L2 direct accerr path | L2 tag-hit cached PMP deny 会产生 `PDE_cache_acc_err_vld/type/id/grant` 并接入 PTW access fault arbitration。 |
| MBUF/TWU payload 链路已存在 | `twu_mbuf_pmpflg` -> `mbuf_entry_pmpflg` -> `mbuf_twu_pmpflg` -> `mbuf_cache_upd_l1pmpflg/l2pmpflg`。 |
| UVM probe 原先不足 | 旧 probe 只覆盖 PDE hit/update/clear/update_vec，缺少 pmpflg payload、raw tag hit、cached entry pmpflg、direct accerr vld/type/id/grant。 |
| PMP config update 存在 gap | `pmp_regs_update` 在 `tb_top.sv` DUT instance 中 tie 为 `1'b0`，后续 clear/repopulate 相关阶段需要处理。 |

阶段 0 保留产物：

| 文件 | 状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | 保留，作为后续 probe/SVA/ref/SB 接入依据。 |

## 阶段 1 进度

状态：done

本阶段只完成公共类型、helper 和 transaction schema 扩展；未接 probe，未修改 monitor 采样逻辑，未修改 ref model/SB 行为，未新增 test，未修改 regression list。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 新增 PDE reason/access source enum；新增 cached pmpflg allow helper；扩展 expected/level/PDE transaction 字段；更新 `convert2string()`。 |

未修改文件边界：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | include 顺序已满足要求，无需修改。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 阶段 1 禁止修改 monitor 采样逻辑。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 阶段 1 禁止修改 ref model 行为。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 阶段 1 禁止修改 scoreboard compare 行为。 |

新增类型与 helper：

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

Transaction schema delta：

| Transaction | 新增字段 |
| --- | --- |
| `ptw_src_pde_evt_txn` | `l1_tag_hit`、`l2_tag_hit`、permission allow fields、cached/update pmpflg、`mbuf_pmpflg`、`direct_accerr`、`reason`、`access_src`、accerr type/id/grant、raw tag/accerr vectors。 |
| `ptw_src_level_evt_txn` | `twu_mbuf_pmpflg`、`mbuf_pmpflg`、`selected_pmpflg`。 |
| `ptw_src_expected_rsp_txn` | `access_src`、`pde_reason`、`pde_l1pmpflg`、`pde_l2pmpflg`、`pde_direct_accerr`。 |

新增字段在 constructor 中使用 safe default，避免旧 smoke 在未采样新 probe 时打印随机值。

## 阶段 2 进度

状态：done

本阶段只完成 probe 接入与 monitor actual event 采样；未修改 ref model expected，未修改 scoreboard compare，未新增 SVA，未新增 directed tests。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | 新增 pmpflg payload、PDE update pmpflg、raw tag hit、cached pmpflg、direct accerr、accerr grant probes 和 clocking input。 |
| `mmu_verification/testbench/top/tb_top.sv` | 将 RTL `mbuf_cache_upd_*pmpflg`、`twu_mbuf_pmpflg`、`mbuf_twu_pmpflg`、`mbuf_entry_pmpflg`、`PDE_cache_acc_err_*`、`L2PDE_entry_acc_err`、cached pmpflg/raw tag hit vectors 连接到 probe interface。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 采样 level/PDE event 的 pmpflg、raw tag hit、permission allow、direct accerr root cause，并增加 summary counters。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | 更新阶段 2 对阶段 0 gap 的关闭/部分关闭状态。 |

Monitor event delta：

| Event | 新增采样 |
| --- | --- |
| `PTW_LEVEL_EVT` | `twu_mbuf_pmpflg`、`mbuf_pmpflg`、`selected_pmpflg`。 |
| `PTW_PDE_EVT` hit/miss | `l1_tag_hit/l2_tag_hit`、permission allow、cached pmpflg、L2 direct accerr vector、`reason/access_src`。 |
| `PTW_PDE_EVT` update | `update_l1pmpflg/update_l2pmpflg`、`mbuf_pmpflg`、update vectors。 |
| `PTW_PDE_EVT` direct accerr | `direct_accerr=1`、`accerr_type/id/grant`、`PDE_CACHE_PMP_DENY` source。 |

Monitor summary counters：

| Counter | 含义 |
| --- | --- |
| `pde_pmpflg_update` | PDE cache update event 数量。 |
| `pde_l1_deny_miss` | L1 tag hit 但 cached PMP deny，表现为 miss 的 event 数量。 |
| `pde_direct_accerr` | PDE cache direct access fault event 数量。 |

## 阶段 3 进度

状态：done

本阶段只完成 PDE cache abstract model 的 permission-qualified 重构；未修改 monitor，未生成 expected completion，未修改 scoreboard，未新增 tests。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | `pde_entry_s` 保存 `l1pmpflg/l2pmpflg`；新增 `pde_lookup_result_s`；新增 permission-qualified `lookup_detail()`；update API 支持 pmpflg；保留旧 lookup/update 兼容；新增 debug dump/helper。 |

Lookup 语义：

| 场景 | model 行为 |
| --- | --- |
| L2 tag hit 且 L1/L2 cached PMP allow | `lookup_hit=1`、`l2_hit=1`、`hit_level=THD`，更新 L2 age。 |
| L2 tag hit 但任一级 cached PMP deny | `l2_direct_accerr=1`，返回 `L2_L1PMP_DENY`、`L2_L2PMP_DENY` 或 `L2_BOTH_PMP_DENY`，不 fallback 到 L1，不更新 age。 |
| L1 tag hit 且 cached PMP allow | `lookup_hit=1`、`l1_hit=1`、`hit_level=SCD`，更新 L1 age。 |
| L1 tag hit 但 cached PMP deny | `l1_deny_miss=1`、`reason=L1_PMP_DENY`，不更新 age。 |
| all-allow pmpflg 默认 | 旧 `lookup(vpn, ...)`、旧 `queue_update(level,vpn,ppn)`、旧 `commit_update(level,vpn,ppn)` 行为保持 tag-only 兼容。 |

API delta：

| API | 状态 |
| --- | --- |
| `lookup(vpn, hit_level, hit_ppn, l1_hit, l2_hit)` | 保留，内部用 all-allow/default LOAD 兼容旧调用。 |
| `lookup_detail(vpn, req_type, effective_m, update_plru)` | 新增，返回 raw tag hit、qualified hit、deny/direct accerr reason。 |
| `queue_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim)` | 扩展，pmpflg 默认 all-allow。 |
| `commit_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim)` | 扩展，pmpflg 默认 all-allow。 |
| `queue_update_with_pmpflg()` / `commit_update_with_pmpflg()` | 新增显式别名，便于阶段 4 接入。 |
| `lookup_result2string()` / `dump_string()` | 新增 debug helper。 |

## 阶段 4 进度

状态：done

本阶段只完成 source reference model 对 PDE pmpflg golden 语义的集成；未修改 scoreboard compare 规则，未新增 no-extra-LSU checker，未新增 SVA，未新增 directed tests。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 扩展 pending request PDE pmpflg 状态；引入 predicted/observed PDE update window；用 observed PDE update pmpflg commit PDE model；lookup event 调用 `lookup_detail()`；生成 L2 PDE cached PMP deny direct access fault expected；summary 打印新增 pde pmpflg counters。 |

Reference model 行为：

| 场景 | ref model 行为 |
| --- | --- |
| FST non-leaf data return | 记录 predicted L1 PDE update，payload 为 `l1pmpflg=mbuf_pmpflg[3:0]`、`l2pmpflg=0`。 |
| SCD non-leaf data return | 记录 predicted L2 PDE update，payload 为 `l1pmpflg=mbuf_pmpflg[3:0]`、`l2pmpflg=mbuf_pmpflg[7:4]`。 |
| Observed PDE update | 与 predicted update 小窗口匹配，并用 `commit_update_with_pmpflg()` 更新 `m_pde_model`。 |
| PDE lookup actual event | 等 pending context ready 后调用 `lookup_detail(vpn, req_type, effective_machine(pending))`。 |
| L1 tag-hit cached PMP deny | 记录 `pde_l1_tag_hit_deny_seen` 和 `pde_l1_pmp_deny_miss`，不直接生成 access fault expected。 |
| L2 tag-hit cached PMP deny | 生成 `PTW_SRC_EXP_ACCESS_FAULT`，设置 `access_src=PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY`、`pde_reason`、`pde_l1pmpflg/pde_l2pmpflg`、`pde_direct_accerr=1`。 |
| SATP/TLB invalidate/PMP cfg update/abort | clear PDE model，并清空 pmpflg predicted/observed/deferred shadow queue。 |

新增或更新 summary counters：

| Counter | 含义 |
| --- | --- |
| `pde_l1_pmp_deny_miss` | L1 tag hit 但 cached PMP deny，被建模为 miss。 |
| `pde_l2_l1pmp_deny_accerr` | L2 tag hit 且 cached L1 PMP deny direct accerr。 |
| `pde_l2_l2pmp_deny_accerr` | L2 tag hit 且 cached L2 PMP deny direct accerr。 |
| `pde_pmpflg_update_l1` | observed L1 PDE update commit 数量。 |
| `pde_pmpflg_update_l2` | observed L2 PDE update commit 数量。 |
| `pde_mmode_bypass` | effective M-mode cached pmpflg bypass evidence。 |
| `pde_mmode_lock_deny` | effective M-mode lock-deny evidence。 |
| `pde_update_match` | predicted/observed PDE update payload match 数量。 |
| `pde_update_mismatch` | unmatched or mismatched PDE update payload 数量。 |
| `pde_duplicate_direct_accerr` | lookup/direct-accerr 双 event 去重数量。 |

## 当前未关闭项

| Item | 后续阶段 |
| --- | --- |
| Scoreboard 尚未比较 `access_src/pde_reason/direct_accerr` | 阶段 5 |
| Permission-qualified hit、direct accerr pending/type-id/priority/valid gate SVA/cover 尚未实现 | 阶段 6 |
| Directed helper 和旧 PDE directed tests 尚未按 cached pmpflg 语义修正 | 阶段 7 |
| `PDE-TP-013..016`、`PTW-FLOW-024..027`、`PTW-ADD-037..041` directed closure 尚未开始 | 阶段 8 |
| `PDE-TP-017..019`、`PTW-FLOW-028`、`PTW-ADD-042..045` directed closure 尚未开始 | 阶段 9 |
| `pmp_regs_update` testbench tie-off 未处理 | 后续涉及 PMP config clear/repopulate 的阶段 |
| Regression/signoff list、CSV、gate、报告尚未冻结 | 阶段 10 |

## 已执行检查汇总

| 检查 | 结果 |
| --- | --- |
| 阶段 0 RTL/UVM probe 审计 `rg` | pass |
| 阶段 1 enum/helper/transaction 字段 `rg` | pass |
| 阶段 1 SV/SVH 修改边界 | pass，仅 `ptw_source_types.svh` |
| 阶段 2 probe/monitor 字段 `rg` | pass |
| 阶段 2 RTL 被观测层级信号存在性 `rg` | pass |
| 阶段 2 ref/SB/SVA/test 边界 | pass，无相关文件修改 |
| 阶段 3 model 字段/API/reason `rg` | pass |
| 阶段 3 旧 ref model 调用点兼容性检查 | pass，仍为旧 `lookup()` 和 3 参数 update 调用 |
| 阶段 3 ref/SB/monitor/SVA/test 边界 | pass，无相关文件修改 |
| 阶段 4 ref model pmpflg/direct-accerr 关键词 `rg` | pass |
| 阶段 4 SV/SVH 修改边界 | pass，仅 `ptw_source_ref_model.svh` |
| 阶段 4 scoreboard/SVA/test 边界 | pass，无相关文件修改 |
| `git diff --check` | pass，仅有 Git line-ending warning |
| `make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke` | blocked，当前 PowerShell 环境找不到 `make` |
| `make -C mmu_verification run_check ...` | blocked，当前 PowerShell 环境找不到 `make` |

## 退出标准检测命令

```powershell
# 文档合并和阶段进度文件删除检查
Get-ChildItem -Path doc\ptw_uvm_review -Filter "*progress*.md" | Select-Object -ExpandProperty Name
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_all_stages_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage0_probe_map.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage0_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage1_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage2_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage3_progress.md

# 阶段 0 到 3 关键内容可追溯检查
rg -n "PMPFLG_STAGE_DONE|stage=0|stage=1|stage=2|stage=3|stage=4|blocked|make" doc\ptw_uvm_review\ptw_pde_cache_pmpflg_all_stages_progress.md
rg -n "ptw_src_pde_reason_e|ptw_src_access_src_e|ptw_src_pde_pmp_allow|pde_direct_accerr|cached_l1pmpflg" mmu_verification\testbench\env\ptw_source_types.svh
rg -n "pde_cache_update_l1pmpflg|pde_cache_update_l2pmpflg|pde_cache_acc_err|ptw_mbuf_twu_pmpflg|ptw_twu_mbuf_pmpflg" mmu_verification\testbench\env\mmu_dut_probes_if.sv mmu_verification\testbench\top\tb_top.sv mmu_verification\testbench\env\ptw_source_monitor.svh
rg -n "l1pmpflg|l2pmpflg|lookup_detail|pde_lookup_result|direct_accerr|L2_L.*DENY" mmu_verification\testbench\env\ptw_pde_cache_model.svh
rg -n "pde_direct_accerr|PDE_CACHE_PMP_DENY|pde_l1_pmp|pde_l2|lookup_detail|effective_machine|commit_update_with_pmpflg|record_predicted_pde_update|pde_update_match|pde_mmode" mmu_verification\testbench\env\ptw_source_ref_model.svh

# 工作区和格式检查
git status --short
git diff --check

# 环境具备 make 后再执行编译/运行检查
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

预期文档检查结果：

| 命令 | 预期 |
| --- | --- |
| `Get-ChildItem ... "*progress*.md"` | 只显示 `ptw_pde_cache_pmpflg_all_stages_progress.md`。 |
| `Test-Path ... all_stages_progress.md` | `True` |
| `Test-Path ... stage0_probe_map.md` | `True` |
| `Test-Path ... stage0_progress.md` | `False` |
| `Test-Path ... stage1_progress.md` | `False` |
| `Test-Path ... stage2_progress.md` | `False` |
| `Test-Path ... stage3_progress.md` | `False` |

## 已合并并删除的阶段进度文件

以下阶段独立进度文件内容已合并到本文档，并按用户要求删除：

| 文件 | 合并状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_progress.md` | merged and removed |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage1_progress.md` | merged and removed |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage2_progress.md` | merged and removed |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage3_progress.md` | merged and removed |
