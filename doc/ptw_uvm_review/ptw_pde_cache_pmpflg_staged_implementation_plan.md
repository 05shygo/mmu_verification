# PTW PDE Cache PMP Flag UVM 分阶段任务拆分计划

本文档是 `ptw_pde_cache_pmpflg_uvm_implementation_plan.md` 的阶段化执行版本。它把针对 PDE cache `pmpflg` RTL 修改的 UVM 工作拆成多个可独立开启、独立验收的阶段任务。后续执行时应严格按阶段推进；当用户指定某一阶段时，只允许完成该阶段列出的任务，不得提前实现后续阶段内容。

## 1. 输入和优先级

| 输入 | 用途 | 优先级 |
| --- | --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_design_change.md` | RTL 修改语义冻结：PDE cache entry 保存 page-table memory PMP evidence，lookup 按当前 type 重新解释。 | 最高 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_uvm_implementation_plan.md` | UVM 修改总计划，包含 probe/model/ref/SB/SVA/test/gate 的完整任务库。 | 高 |
| `doc/ptw_uvm_review/ptwspec.md` | PTW 全功能规格和既有测试点归属。 | 高 |
| 现有 UVM 源码和 regression list | 当前实现状态；若与上述文档冲突，按上述文档修改。 | 中 |

若本文与 `ptw_pde_cache_pmpflg_design_change.md` 冲突，以设计变更文档为准。若本文与总计划冲突，优先检查是否为阶段边界不同；功能语义仍以总计划和设计变更文档为准。

## 2. 全局执行规则

1. 每次只执行用户指定的阶段任务。
2. 不得提前实现后续阶段的测试、gate 或 checker，即使当前阶段改动使后续实现更方便。
3. 每个阶段完成时必须给出退出标准检查命令。
4. 若某阶段预计新增文件超过 15 个，必须先创建临时子阶段拆分计划；完成当前子阶段后删除临时拆分计划。
5. 对已有 dirty worktree 不做回退，不删除用户修改。
6. probe 不足时先登记 gap，不允许用 consumer-side pass 替代 source-side closure。
7. `mmu_translation_sb`、L1DTLB/L2TLB consumer evidence 只能作为补充，不能关闭本次 PDE cache pmpflg source-side requirement。
8. 新增 Python 脚本或修改现有 gate 时必须兼容旧 Python3，不使用 `from __future__ import annotations`。
9. 新增 SystemVerilog identifier 避免使用 `context` 等关键字。
10. 每阶段完成后，若涉及 debug 结论或 closure 状态，应在阶段报告或后续进度文档中记录。

## 3. 全局目标

本轮 UVM 修改完成后，应能严格验证以下 RTL 行为：

1. L1 PDE entry 保存 `l1pmpflg`。
2. L2 PDE entry 保存 `l1pmpflg` 和 `l2pmpflg`。
3. L1 PDE lookup 需要 tag match 且当前 request type 被 cached `l1pmpflg` 允许；deny 时表现为 L1 miss，进入 `fst_pmp`。
4. L2 PDE lookup 需要 tag match 且当前 request type 同时被 cached `l1pmpflg/l2pmpflg` 允许；deny 时产生 PDE cache direct access fault。
5. L2 tag-hit deny 不允许 fallback 到 L1 hit，不允许重新发 LSU page-table read。
6. FST non-leaf update L1 时保存 `{4'b0,l1pmpflg}` 的低 4 bit。
7. SCD non-leaf update L2 时保存 `{l2pmpflg,l1pmpflg}`。
8. THD 不更新 PDE cache，THD payload 不参与 PDE cache evidence。
9. effective M-mode 下 `pmpflg[3]=0` 可 bypass type bit，`pmpflg[3]=1` 不可 bypass。
10. PDE direct access fault 返回原始 `type/id`，并按设计优先级参与 PTW access fault arbitration。

## 4. 新增 Requirement 范围

本拆分计划覆盖以下新增或修改 requirement：

| Requirement | 含义 | 关闭阶段 |
| --- | --- | --- |
| `PDE-TP-013` | L1 tag hit but cached PMP deny -> L1 miss/FST path。 | 阶段 8 |
| `PDE-TP-014` | L2 tag hit but cached L1 PMP deny -> PDE direct access fault。 | 阶段 8 |
| `PDE-TP-015` | L2 tag hit but cached L2 PMP deny -> PDE direct access fault。 | 阶段 8 |
| `PDE-TP-016` | FST/SCD/THD pmpflg propagation 和 PDE update payload。 | 阶段 8 |
| `PDE-TP-017` | PDE direct accerr type/id、pending、priority。 | 阶段 9 |
| `PDE-TP-018` | effective M-mode pmpflg bit3 lock/bypass matrix。 | 阶段 9 |
| `PDE-TP-019` | L2 direct accerr 必须由 valid entry 和 ptw request gate。 | 阶段 9 |
| `PTW-FLOW-024` | L1 tag-hit deny 完整流程。 | 阶段 8 |
| `PTW-FLOW-025` | L2 tag-hit cached L1 deny 完整流程。 | 阶段 8 |
| `PTW-FLOW-026` | L2 tag-hit cached L2 deny 完整流程。 | 阶段 8 |
| `PTW-FLOW-027` | cached pmpflg allow 跨 type 复用。 | 阶段 8 |
| `PTW-FLOW-028` | effective M-mode cached pmpflg lock/bypass。 | 阶段 9 |
| `PTW-ADD-037` | `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001`。 | 阶段 8 |
| `PTW-ADD-038` | `test_ptw_pde_l1_pmp_tag_allow_reuse_001`。 | 阶段 8 |
| `PTW-ADD-039` | `test_ptw_pde_l2_pmp_l1_deny_accerr_001`。 | 阶段 8 |
| `PTW-ADD-040` | `test_ptw_pde_l2_pmp_l2_deny_accerr_001`。 | 阶段 8 |
| `PTW-ADD-041` | `test_ptw_pde_pmpflg_propagation_update_001`。 | 阶段 8 |
| `PTW-ADD-042` | `test_ptw_pde_accerr_priority_type_id_001`。 | 阶段 9 |
| `PTW-ADD-043` | `test_ptw_pde_mmode_lock_matrix_001`。 | 阶段 9 |
| `PTW-ADD-044` | `test_ptw_pde_l2_accerr_valid_gate_001`。 | 阶段 9 |
| `PTW-ADD-045` | `test_ptw_pde_pmp_clear_repopulate_001`。 | 阶段 9 |

## 5. 阶段总览

| 阶段 | 名称 | 核心目标 | 主要产出 | 硬退出门槛 |
| --- | --- | --- | --- | --- |
| 阶段 0 | 语义冻结与信号审计 | 冻结 pmpflg 语义，形成 RTL/UVM probe map 和 gap 表。 | 阶段审计文档、probe gap 表。 | 所有必需信号有观测方案或 gap 记录。 |
| 阶段 1 | 公共类型与 transaction schema | 扩展 source-side 类型、helper、transaction 字段。 | `ptw_source_types.svh` 更新。 | 编译通过，旧 smoke 不回归。 |
| 阶段 2 | Probe 接入与 monitor 采样 | 接入 pmpflg/direct-accerr probe，并让 monitor 输出事件。 | probe if、`tb_top`、monitor 更新。 | monitor 可打印 pmpflg update/direct accerr event。 |
| 阶段 3 | PDE cache model 重构 | tag-only PDE model 升级为 permission-qualified model。 | `ptw_pde_cache_model.svh` 更新。 | all-allow 场景旧行为不变，deny 结果可由 model 区分。 |
| 阶段 4 | Reference model 集成 | ref model 使用 PDE pmpflg model，生成 L2 direct accerr expected。 | `ptw_source_ref_model.svh` 更新。 | source smoke clean，L1/L2 deny 语义可预期。 |
| 阶段 5 | Scoreboard 与覆盖增强 | 比较 access source/reason，增加 no-extra-LSU checker 和 coverage。 | `ptw_source_sb.svh` 更新。 | 新 coverage banner 打印，旧 source tests clean。 |
| 阶段 6 | SVA 与 cover | 增加 permission-qualified hit、direct accerr、priority SVA。 | `mmu_pde_cache_sva.sv`、arb/top SVA 更新。 | 编译通过，cover banner 可解析。 |
| 阶段 7 | Directed helper 与旧 PDE tests 修正 | 扩展 directed base，修正旧 tag-only expected。 | base helper、旧 PDE tests patch。 | 旧 PDE tests 在新语义下通过。 |
| 阶段 8 | 新增 P0 directed tests A | 覆盖 L1/L2 基础 pmpflg hit/deny/update。 | `PTW-ADD-037..041` tests 和 list。 | 5 个 P0 tests source clean + cover hit。 |
| 阶段 9 | 新增 P0/P1 directed tests B | 覆盖 priority、M-mode、valid gate、clear/repopulate。 | `PTW-ADD-042..045` tests 和 list。 | 4 个 tests source clean + 对应 SVA/coverage。 |
| 阶段 10 | Regression/signoff 冻结 | closure matrix、signoff gate、report 完整接入。 | list、CSV、gate、signoff report。 | P0/P1/list/gate 全部通过。 |

## 6. 阶段 0：语义冻结与信号审计

### 6.1 目标

本阶段只做审计和文档化，不实现 UVM 功能逻辑。目标是把 RTL 修改后的真实信号名、层级路径、观测方式、缺口全部冻结，避免后续阶段基于猜测实现 monitor/ref model。

### 6.2 允许任务

1. 阅读 RTL 修改相关文件，确认真实信号名和层级路径。
2. 阅读现有 UVM probe、monitor、SVA bind 文件，确认哪些信号已经可观测。
3. 创建或更新阶段 0 probe gap/信号映射文档。
4. 明确每个必需信号由 monitor probe 观测、SVA bind 观测，还是暂时 gap。
5. 给出后续阶段需要修改的文件清单。

### 6.3 禁止任务

1. 不修改 SystemVerilog UVM 源码。
2. 不新增 tests。
3. 不修改 regression list。
4. 不实现 source ref model 或 scoreboard 逻辑。
5. 不修改 RTL functional path。

### 6.4 任务产出

建议新增文档：

```text
doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md
```

文档至少包含：

1. 设计语义摘要。
2. 必需观测信号表。
3. RTL 实际信号名和层级路径。
4. UVM probe 映射方案。
5. SVA bind 直连方案。
6. 当前不可观测 gap。
7. 每个 gap 对应的影响 requirement。
8. 后续阶段文件修改清单。

### 6.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_design_change.md` | 读取，提取设计语义。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_uvm_implementation_plan.md` | 读取，提取 UVM 任务。 |
| `mmu/rtl/L1PDE_cache.sv` | 审计 L1 entry pmpflg、tag hit、qualified hit。 |
| `mmu/rtl/L2PDE_cache.sv` | 审计 L2 entry pmpflg、tag hit、direct accerr。 |
| `mmu/rtl/PDE_cache.sv` | 审计 top update pmpflg、direct accerr pending/type/id/grant。 |
| `mmu/rtl/ptw_mbuf.sv`、`mbuf_entry.sv` | 审计 8-bit pmpflg payload。 |
| `mmu/rtl/twu.sv` | 审计 FST/SCD/THD payload 生成和继承。 |
| `mmu/rtl/ptw.sv` | 审计 access fault priority 接入。 |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | 审计已有 probe。 |
| `mmu_verification/testbench/top/tb_top.sv` | 审计 probe assign 和 bind。 |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | 审计 bind 可见信号。 |

### 6.6 退出标准

1. `ptw_pde_cache_pmpflg_stage0_probe_map.md` 已创建或更新。
2. 每个必需信号都被归类为 `monitor-probe`、`sva-bind` 或 `gap`。
3. 每个 gap 都列出影响的 `PDE-TP/PTW-ADD/PTW-FLOW`。
4. 阶段 1 到阶段 6 的文件边界没有未知项。
5. 本阶段没有修改 UVM 源码。

### 6.7 检查命令

```bash
rg -n "L1PDE.*pmp|L2PDE.*pmp|PDE_cache_acc_err|mbuf.*pmpflg|twu_mbuf_pmpflg" mmu/rtl
rg -n "pde_cache|pmpflg|acc_err|L1PDE|L2PDE" mmu_verification/testbench/env mmu_verification/testbench/top
test -f doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md
```

## 7. 阶段 1：公共类型与 Transaction Schema

### 7.1 目标

扩展 PTW source-side 公共类型，使后续 monitor/ref model/scoreboard 能表达 cached pmpflg、tag hit、permission-qualified hit、L1 deny miss、L2 direct accerr 和 access fault root cause。

### 7.2 允许任务

1. 修改 `ptw_source_types.svh`。
2. 新增 PDE pmpflg allow helper。
3. 新增 PDE reason/access source enum。
4. 扩展 `ptw_src_pde_evt_txn`、`ptw_src_level_evt_txn`、`ptw_src_expected_rsp_txn`。
5. 更新 `convert2string()`，确保 debug 字段完整。
6. 如 include 顺序需要，轻微修改 `mmu_env_pkg.sv`。

### 7.3 禁止任务

1. 不接 probe。
2. 不改 monitor 采样逻辑。
3. 不改 ref model 行为。
4. 不改 scoreboard compare 行为。
5. 不新增测试。

### 7.4 任务产出

| 产出 | 内容 |
| --- | --- |
| 新增 enum | `ptw_src_pde_reason_e`、`ptw_src_access_src_e`。 |
| 新增 helper | `ptw_src_pde_pmp_type_bit_allow()`、`ptw_src_pde_pmp_allow()`、reason/access source name helper。 |
| 扩展 PDE event txn | tag hit、qualified allow、cached pmpflg、update pmpflg、direct accerr fields。 |
| 扩展 level event txn | `twu_mbuf_pmpflg`、`mbuf_pmpflg`、`selected_pmpflg`。 |
| 扩展 expected txn | `access_src`、`pde_reason`、`pde_l1pmpflg/l2pmpflg`、`pde_direct_accerr`。 |

### 7.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 主要修改。 |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | 仅当 include/import 顺序需要时修改。 |

### 7.6 退出标准

1. 编译通过。
2. 旧 PTW source smoke 在新增字段默认值下不回归。
3. `convert2string()` 打印的新增字段不会显示未初始化 `x` 并误导 debug。
4. helper 对 load/store/fetch/PFU 和 effective M-mode bit3 的语义与设计文档一致。

### 7.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "ptw_src_pde_reason_e|ptw_src_access_src_e|ptw_src_pde_pmp_allow|pde_direct_accerr|cached_l1pmpflg" mmu_verification/testbench/env/ptw_source_types.svh
```

## 8. 阶段 2：Probe 接入与 Monitor 采样

### 8.1 目标

把阶段 0 确认的 pmpflg 和 PDE direct accerr 信号接入 UVM probe，并让 `ptw_source_monitor` 能产生包含 pmpflg 的 level/PDE event。此阶段只产生 actual/probe transaction，不修改 golden 行为。

### 8.2 允许任务

1. 修改 `mmu_dut_probes_if.sv`，新增 pmpflg/direct accerr/raw tag hit probe。
2. 修改 `tb_top.sv`，连接新增 probe。
3. 修改 `ptw_source_monitor.svh`：
   - 采样 `twu_mbuf_pmpflg`。
   - 采样 `mbuf_twu_pmpflg`。
   - 采样 PDE update `l1pmpflg/l2pmpflg`。
   - 采样 L1/L2 tag hit、qualified hit、direct accerr。
4. 更新 monitor summary counters。
5. 若部分信号暂不可接入，更新阶段 0 gap 表。

### 8.3 禁止任务

1. 不改 ref model expected。
2. 不改 scoreboard compare。
3. 不新增 SVA。
4. 不新增 directed tests。

### 8.4 任务产出

| 产出 | 内容 |
| --- | --- |
| probe interface 更新 | 新增 pmpflg/direct accerr/raw hit/cached pmpflg wire 和 clocking input。 |
| `tb_top` assign 更新 | 将 RTL 信号连接到 probe interface。 |
| monitor event 更新 | `PTW_PDE_EVT` 和 `PTW_LEVEL_EVT` 打印 pmpflg/direct accerr 信息。 |
| monitor counters | pmpflg update、L1 deny miss event、L2 direct accerr event 的计数。 |

### 8.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | 新增 probe。 |
| `mmu_verification/testbench/top/tb_top.sv` | 新增 assign。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 新增采样字段和 event 分类。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | 如有 gap，更新。 |

### 8.6 退出标准

1. 编译通过。
2. smoke test 中 monitor 可打印 PDE update pmpflg 字段。
3. 如果测试没有触发 direct accerr，也应能证明 direct accerr probe 编译和采样路径存在。
4. monitor summary 不出现新增字段全 `x` 或非法 cast warning。
5. 未接入的 probe 已写入 gap 表。

### 8.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "pde_cache_update_l1pmpflg|pde_cache_update_l2pmpflg|pde_cache_acc_err|ptw_mbuf_twu_pmpflg|ptw_twu_mbuf_pmpflg" mmu_verification/testbench/env/mmu_dut_probes_if.sv mmu_verification/testbench/top/tb_top.sv mmu_verification/testbench/env/ptw_source_monitor.svh
```

## 9. 阶段 3：PDE Cache Abstract Model 重构

### 9.1 目标

把 `ptw_pde_cache_model` 从 tag-only model 升级为 permission-qualified model。此阶段只修改抽象模型，不把新模型接入 completion expected。

### 9.2 允许任务

1. 扩展 PDE entry，保存 `l1pmpflg/l2pmpflg`。
2. 新增 lookup result struct，区分：
   - raw L1 tag hit
   - raw L2 tag hit
   - L1 permission-qualified hit
   - L2 permission-qualified hit
   - L1 tag-hit deny miss
   - L2 tag-hit deny direct accerr
3. 修改 update API，支持保存 pmpflg。
4. 保留旧 lookup wrapper，降低 ref model 接入风险。
5. 更新 age/PLRU abstract 行为：只有 qualified hit 更新 age。
6. 添加 debug dump/helper，便于后续阶段定位 entry 状态。

### 9.3 禁止任务

1. 不修改 monitor。
2. 不生成 expected completion。
3. 不修改 scoreboard。
4. 不新增 tests。

### 9.4 任务产出

| 产出 | 内容 |
| --- | --- |
| `pde_entry_s` 扩展 | `l1pmpflg/l2pmpflg`。 |
| `pde_lookup_result_s` | 完整 lookup 细分结果。 |
| `lookup_detail()` | 基于 `vpn/type/effective_m` 的 permission-qualified lookup。 |
| update API | `queue_update/commit_update` 支持 pmpflg。 |
| compatibility wrapper | 旧调用可继续编译。 |

### 9.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | 主要修改。 |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 仅当 helper 需要微调时修改。 |

### 9.6 退出标准

1. 编译通过。
2. all-allow pmpflg 下旧 L1/L2 hit 行为不变。
3. model 能返回 L1 deny miss 和 L2 deny direct accerr 的不同 reason。
4. L2 raw tag hit deny 时不会 fallback 到 L1 hit。
5. tag hit deny 不更新 entry age。

### 9.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
rg -n "l1pmpflg|l2pmpflg|lookup_detail|pde_lookup_result|direct_accerr|L2_L.*DENY" mmu_verification/testbench/env/ptw_pde_cache_model.svh
```

## 10. 阶段 4：Source Reference Model 集成

### 10.1 目标

将阶段 3 的 PDE pmpflg model 接入 `ptw_source_ref_model`，让 ref model 能根据 observed PDE event 和 level/MBUF payload 生成正确 expected，包括 L2 direct access fault。

### 10.2 允许任务

1. 扩展 `pending_req_s`，记录 PDE pmpflg lookup/update/direct accerr 状态。
2. `collect_level()` 记录 predicted PDE update payload：
   - FST non-leaf -> L1 update `{0,l1}`。
   - SCD non-leaf -> L2 update `{l2,l1}`。
3. `collect_pde()` 比较 observed update 与 predicted update，并 commit PDE model。
4. `collect_pde()` 对 lookup event 调用 `lookup_detail()`。
5. L1 tag-hit deny：
   - 不发 expected access fault。
   - 标记后续应进入 FST path。
6. L2 tag-hit deny：
   - 生成 `PTW_SRC_EXP_ACCESS_FAULT`。
   - `access_src=PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY`。
   - `pde_direct_accerr=1`。
   - `type/id/target` 来自当前 request。
7. 复用统一 effective-mode helper，确保 fetch real privilege 与 data/PFU MPRV/MPP 语义一致；top-level source 中 data/PFU effective-M 请求必须视为 illegal/unreachable，不可作为 cached pmpflg closure。
8. 更新 ref model summary counters。

### 10.3 禁止任务

1. 不改 scoreboard compare 规则。
2. 不新增 no-extra-LSU checker。
3. 不新增 tests。
4. 不新增 SVA。

### 10.4 任务产出

| 产出 | 内容 |
| --- | --- |
| ref model PDE pmpflg pending state | 记录 lookup/update/direct accerr 信息。 |
| predicted update queue/window | level event 和 PDE update event 的 payload 匹配。 |
| L2 direct accerr expected | source expected 可表达 PDE direct access fault。 |
| ref summary counters | `pde_l1_pmp_deny_miss`、`pde_l2_*_deny_accerr`、`pde_update_l1/l2_pmpflg`。 |

### 10.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 主要修改。 |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | 仅当 API 需要微调。 |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 仅当 expected 字段/helper 需要微调。 |

### 10.6 退出标准

1. 编译通过。
2. 旧 source smoke clean。
3. all-allow PDE cache hit/refill 旧场景不回归。
4. ref model summary 打印新增 PDE pmpflg counters。
5. L1 deny miss 和 L2 direct accerr 在代码路径上可区分。

### 10.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "pde_direct_accerr|PDE_CACHE_PMP_DENY|pde_l1_pmp|pde_l2|lookup_detail|effective_machine" mmu_verification/testbench/env/ptw_source_ref_model.svh
```

## 11. 阶段 5：Scoreboard、Coverage 和 No-extra-LSU Checker

### 11.1 目标

让 source scoreboard 能比较和统计 PDE pmpflg root cause，并对 L2 direct accerr 场景证明没有额外 LSU page-table read。

### 11.2 允许任务

1. 扩展 `compare_completion()`，比较 `access_src/pde_reason/pde_direct_accerr`。
2. 新增 PDE pmpflg coverage counters。
3. 新增 `PTW_SOURCE_SB_PDE_PMP_COVERAGE` summary banner。
4. 新增 no-extra-LSU checker：
   - L2 direct accerr window 打开后，到 completion/drop 前不得出现归属该请求的新 PTW memory request。
   - 单 outstanding directed 场景严格检查。
   - 多 pending ambiguous 场景记为 probe gap，不关闭 requirement。
5. 保持 active key retire 规则：visible completion/drop 后即可释放 `{type,id}`。
6. 更新 mismatch debug，使 PDE pmpflg root cause 可读。

### 11.3 禁止任务

1. 不新增 tests。
2. 不新增 SVA。
3. 不修改 directed base。
4. 不修改 regression list。

### 11.4 任务产出

| 产出 | 内容 |
| --- | --- |
| completion compare 扩展 | 比较 `access_src/pde_reason/pde_direct_accerr`。 |
| coverage banner | `PTW_SOURCE_SB_PDE_PMP_COVERAGE`。 |
| no-extra-LSU checker | 关闭 L2 direct accerr 性能语义。 |
| debug 分类 | mismatch 能指出 L1 deny miss、L2 L1 deny、L2 L2 deny、both deny。 |

### 11.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 主要修改。 |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 仅当 compare/debug helper 需要微调。 |
| `mmu_verification/testbench/env/mmu_env.svh` | 仅当 mem req fanout 连接不足时修改。 |

### 11.6 退出标准

1. 编译通过。
2. 旧 source smoke clean：`mismatch=0 pending=0 illegal=0`。
3. 日志中出现 `PTW_SOURCE_SB_PDE_PMP_COVERAGE` banner。
4. no-extra-LSU checker 默认不误报旧 tests。
5. direct accerr completion 后 active key 能 retire。

### 11.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "PTW_SOURCE_SB_PDE_PMP_COVERAGE|no_extra_lsu|access_src|pde_reason|pde_direct_accerr" mmu_verification/testbench/env/ptw_source_sb.svh
```

## 12. 阶段 6：SVA 与 Cover

### 12.1 目标

增加 source-side SVA，直接约束 PDE cache pmpflg hit/deny、update payload、direct accerr gate、pending type/id 和 priority。

### 12.2 允许任务

1. 修改 `mmu_pde_cache_sva.sv`：
   - 新增 ports。
   - 新增 pmp allow helper。
   - 修改旧 PDE hit/update SVA。
   - 新增 `PTW-SVA-PDE-011..017`。
2. 修改 `mmu_arb_sva.sv` 或 `mmu_ptw_top_sva.sv`：
   - 新增 PDE direct accerr priority SVA。
   - 新增 completion class/type-id SVA。
3. 修改 bind 连接或 probe 连接，仅限 SVA 编译所需。
4. 新增 cover banner，保持 `PTW_SVA_COVER` 格式。

### 12.3 禁止任务

1. 不新增 directed tests。
2. 不修改 ref model/SB 行为，除非 SVA 字段名变化导致编译需要。
3. 不修改 regression list。

### 12.4 任务产出

| 产出 | 内容 |
| --- | --- |
| `PTW-SVA-PDE-011` | L1 hit iff valid/tag/allow，tag hit deny 不 hit。 |
| `PTW-SVA-PDE-012` | L2 hit iff valid/tag/L1 allow/L2 allow。 |
| `PTW-SVA-PDE-013` | L2 tag hit deny -> direct accerr, no xbar hit。 |
| `PTW-SVA-PDE-014` | direct accerr gated by valid and ptw_req。 |
| `PTW-SVA-PDE-015` | FST/SCD/THD pmpflg payload/update 检查。 |
| `PTW-SVA-PDE-016` | tag hit deny 不更新 PLRU/read-hit。 |
| `PTW-SVA-PDE-017` | direct accerr pending type/id stable and clear on grant。 |
| `PTW-SVA-ARB-010..012` | direct accerr priority、completion class、no duplicate grant。 |

### 12.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | 主要修改。 |
| `mmu_verification/testbench/top/mmu_arb_sva.sv` | direct accerr priority。 |
| `mmu_verification/testbench/top/mmu_ptw_top_sva.sv` | 如 top completion 字段更适合在此检查。 |
| `mmu_verification/testbench/top/tb_top.sv` | 仅当 bind/port 连接需要修改。 |

### 12.6 退出标准

1. 编译通过。
2. 旧 smoke 没有新增 assertion fail。
3. 日志中可解析新增 `PTW_SVA_COVER` banner。
4. 若 directed tests 尚未实现，新增 cover 可以为 0，但必须打印。
5. 新增 SVA 不依赖 consumer-side scoreboard。

### 12.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
rg -n "PTW-SVA-PDE-011|PTW-SVA-PDE-012|PTW-SVA-PDE-013|PTW-SVA-PDE-014|PTW-SVA-PDE-015|PTW-SVA-PDE-017|PTW-SVA-ARB-010" mmu_verification/testbench/top
```

## 13. 阶段 7：Directed Helper 与旧 PDE Tests 修正

### 13.1 目标

扩展 directed base，使 tests 可以稳定构造 pmpflg 场景；同时修正已有 PDE tests 的 tag-only expected，避免旧测试与新 RTL 语义冲突。

### 13.2 允许任务

1. 修改 `ptw_source_directed_base.svh`，新增 pmpflg helper：
   - `ptw_make_pmpflg()`
   - `ptw_config_page_table_pmp_region()`
   - `ptw_prime_l1_pde_cache_with_type()`
   - `ptw_prime_l2_pde_cache_with_type()`
   - `ptw_drive_source_req_by_type()`
   - `ptw_expect_no_ptw_mem_req_window()`
2. 修改旧 PDE tests，使 positive hit 显式配置 allow pmpflg。
3. 修改旧 PDE miss tests，区分 tag miss 和 permission-qualified miss。
4. 修改旧 replacement tests，tag hit deny 不更新 PLRU。
5. 修改旧 clear/reset tests，清空后旧 pmpflg 不可产生 hit/direct accerr。
6. 只修正已有 tests，不新增 `PTW-ADD-037..045` 文件。

### 13.3 禁止任务

1. 不新增新 directed test 文件。
2. 不修改 signoff gate。
3. 不新增 regression list。
4. 不关闭新增 `PTW-ADD-037..045`。

### 13.4 任务产出

| 产出 | 内容 |
| --- | --- |
| directed pmpflg helper | 后续新 tests 可复用。 |
| 旧 L1/L2 PDE hit tests 修正 | all-allow positive hit 明确。 |
| 旧 L1/L2 PDE miss tests 修正 | L1 permission miss 与 tag miss 区分，L2 deny 不再当普通 miss。 |
| replacement/clear tests 修正 | PLRU、clear、abort 与 pmpflg 语义一致。 |

### 13.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh` | 新增 helper。 |
| `test_ptw_l1_pde_hit.svh` | 修正 allow 前提。 |
| `test_ptw_l2_pde_hit_direct.svh` | 修正 allow 前提。 |
| `test_ptw_l1_pde_miss_walk.svh` | 区分 tag miss/permission miss。 |
| `test_ptw_l2_pde_miss_walk.svh` | L2 tag deny 不作为普通 miss。 |
| `test_pde_cache_l1_single_entry.svh` | 补 L1 pmpflg expected。 |
| `test_pde_cache_l2_single_entry.svh` | 补 L2 pmpflg expected。 |
| `test_mmu_pde_cache_hit_l2_skip_scd.svh` | permission-qualified hit 才 skip。 |
| `test_mmu_pde_cache_hit_l3_skip_thd.svh` | 如为 L2 PDE hit，补 allow 前提。 |
| `test_mmu_pde_cache_full_miss_full_ptw.svh` | full miss update pmpflg evidence。 |
| `test_ptw_l1_pde_cache_replace.svh` | tag hit deny 不更新 PLRU。 |
| `test_ptw_l2_pde_cache_replace.svh` | direct accerr 不更新 PLRU/victim。 |
| `test_pde_cache_clear_on_ptw_reset.svh` | clear 后旧 pmpflg 不可见。 |
| `test_bug_001_twu_fst_fetch_type.svh` | fetch/data/PFU cached pmpflg reuse。 |

本阶段触达文件较多，但主要是修改已有 tests，不新增大量文件。若实际修改范围超过 15 个文件，应先创建临时子阶段拆分计划。

### 13.6 退出标准

1. 编译通过。
2. 所有被修改的旧 PDE tests 单跑通过。
3. 旧 tests 不再包含 tag-only hit expected。
4. directed helper 可被后续新 tests 直接调用。
5. source SB clean，SVA 无新增 fail。

### 13.7 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_l1_pde_hit
make -C mmu_verification run_check TEST_NAME=test_ptw_l1_pde_hit SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_l2_pde_hit_direct SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_pde_cache_l1_single_entry SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_pde_cache_l2_single_entry SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_mmu_pde_cache_hit_l2_skip_scd SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

## 14. 阶段 8：新增 P0 Directed Tests A

### 14.1 目标

新增第一组 P0 directed tests，覆盖基础 pmpflg reuse、L1 deny miss、L2 direct accerr 和 pmpflg propagation。该阶段新增文件数量控制在 5 个测试文件，加 suite/list 修改，低于 15 个新增文件。

### 14.2 允许任务

1. 新增 `PTW-ADD-037..041` 对应 test 文件。
2. 修改 `ptw_tests_suite.svh` include 新 tests。
3. 新增或修改 `simu/ptw_pde_pmpflg_list`，加入本阶段 5 个 tests。
4. 可将两个代表 tests 加入 `ptw_p0_smoke_list`，但不做最终 signoff gate。
5. 每个 test 使用阶段 7 helper，不重复手写复杂 stimulus。
6. 每个 test 写入 scenario metadata 和 requirement id。

### 14.3 禁止任务

1. 不新增 `PTW-ADD-042..045` tests。
2. 不修改 signoff gate。
3. 不修改 closure matrix 到最终 closed 状态，只可标本阶段 partial evidence。
4. 不做随机 regression closure。

### 14.4 新增测试

| Requirement | 文件 | 场景 | 预期 |
| --- | --- | --- | --- |
| `PTW-ADD-037` | `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001.svh` | 先建立 L1 PDE，后续同 L1 tag 但 current type 被 cached `l1pmpflg` deny。 | L1 不 hit；进入 FST path；若实时 PMP deny，普通 TWU access fault；无 PDE direct accerr。 |
| `PTW-ADD-038` | `test_ptw_pde_l1_pmp_tag_allow_reuse_001.svh` | load/PFU 共用 R，fetch 用 X，store 用 W 的 allow reuse。 | L1 permission-qualified hit，跳过 FST。 |
| `PTW-ADD-039` | `test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh` | L2 tag match，cached L2 allow，cached L1 deny。 | PDE direct access fault；不发 LSU；type/id 正确。 |
| `PTW-ADD-040` | `test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh` | L2 tag match，cached L1 allow，cached L2 deny。 | PDE direct access fault；不回退 SCD；不发 LSU。旧 `MPRV=1/MPP=M` data construction 不合法，top-level source test 只能 open，需 alternate legal/lower-level evidence。 |
| `PTW-ADD-041` | `test_ptw_pde_pmpflg_propagation_update_001.svh` | FST/SCD/THD payload 全覆盖。 | FST `{0,l1}`，SCD `{l2,l1}`，THD `0` 且不更新 PDE。 |

### 14.5 任务产出

| 产出 | 内容 |
| --- | --- |
| 5 个新增 test 文件 | 覆盖 `PTW-ADD-037..041`。 |
| suite include | `ptw_tests_suite.svh` include 新文件。 |
| pmpflg list | `simu/ptw_pde_pmpflg_list` 包含本阶段 tests。 |
| P0 smoke list 可选更新 | 加入 1-2 个代表场景。 |
| 阶段 run log | 每个 test source SB clean + PDE/SVA cover 命中。 |

### 14.6 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l1_pmp_tag_deny_fst_fault_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l1_pmp_tag_allow_reuse_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_pmpflg_propagation_update_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh` | include 新 tests。 |
| `mmu_verification/simu/ptw_pde_pmpflg_list` | 新增或更新。 |
| `mmu_verification/simu/ptw_p0_smoke_list` | 可选添加代表 tests。 |

### 14.7 退出标准

1. 5 个新 tests 编译通过。
2. 5 个新 tests 单跑通过。
3. `PTW-ADD-037` 日志证明 L1 tag hit deny 不是 PDE direct accerr。
4. `PTW-ADD-039` 日志证明 direct accerr 且 no-extra-LSU；`PTW-ADD-040` 若仍使用旧 `MPRV=1/MPP=M` construction，只能记录 open/unreachable，不能作为 pass/closed 标准。
5. `PTW-ADD-041` 日志证明 FST/SCD/THD pmpflg payload 正确。
6. `PTW_SOURCE_SB_PDE_PMP_COVERAGE` 对应 bin 命中。
7. 对应 `PTW_SVA_COVER` 有命中或明确说明 cover 尚未接到。

### 14.8 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_pde_l1_pmp_tag_deny_fst_fault_001
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l1_pmp_tag_deny_fst_fault_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l1_pmp_tag_allow_reuse_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_pmp_l1_deny_accerr_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_pmp_l2_deny_accerr_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_pmpflg_propagation_update_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make regress LIST=simu/ptw_pde_pmpflg_list REGRESS_MODE=run_check REGRESS_NAME=ptw_pde_pmpflg_stage8 REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
```

## 15. 阶段 9：新增 P0/P1 Directed Tests B

### 15.1 目标

新增第二组 directed tests，覆盖 direct accerr priority、effective M-mode lock/bypass、valid/request gate、PMP clear 后 repopulate。该阶段新增 4 个测试文件，并完善 list。

### 15.2 允许任务

1. 新增 `PTW-ADD-042..045` 对应 test 文件。
2. 修改 `ptw_tests_suite.svh` include 新 tests。
3. 更新 `simu/ptw_pde_pmpflg_list`。
4. 将 priority/clear 类 tests 加入 `ptw_p1_list`。
5. 根据测试需要微调 helper，但不得改变阶段 8 已通过测试语义。
6. 更新阶段证据，但不做最终 signoff gate。

### 15.3 禁止任务

1. 不修改 `ptw_stage8_signoff_gate.py`。
2. 不把 closure matrix 全部标 closed。
3. 不做最终 P0/P1 全量签核。

### 15.4 新增测试

| Requirement | 文件 | 场景 | 预期 |
| --- | --- | --- | --- |
| `PTW-ADD-042` | `test_ptw_pde_accerr_priority_type_id_001.svh` | PDE direct accerr 与 MBUF bus error/TWU accerr 同周期候选。 | PDE direct accerr priority，type/id stable，pending grant 后清。 |
| `PTW-ADD-043` | `test_ptw_pde_mmode_lock_matrix_001.svh` | effective M-mode 下 `pmpflg[3]` 0/1 与 type bit allow/deny 交叉。 | top-level data/PFU `MPRV=1/MPP=M` source path 不存在；本 test 记录 open/unreachable，关闭需 lower-level PDE-cache stimulus 或 RTL unit evidence。 |
| `PTW-ADD-044` | `test_ptw_pde_l2_accerr_valid_gate_001.svh` | invalid entry tag 旧值匹配或 `ptw_req=0`。 | 不产生 direct accerr。 |
| `PTW-ADD-045` | `test_ptw_pde_pmp_clear_repopulate_001.svh` | PMP config update clear 后旧 entry 不可复用，后续 walk 可重新 update。 | old entry invalid；new update 使用返回请求 MBUF pmpflg。 |

### 15.5 任务产出

| 产出 | 内容 |
| --- | --- |
| 4 个新增 test 文件 | 覆盖 `PTW-ADD-042..045`。 |
| suite/list 更新 | 新 tests 接入 include 和专项 list。 |
| P1 list 更新 | priority/clear-repopulate 接入 P1。 |
| 阶段 run log | 每个 test source clean + 对应 coverage/SVA。 |

### 15.6 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_accerr_priority_type_id_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_mmode_lock_matrix_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_accerr_valid_gate_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_pmp_clear_repopulate_001.svh` | 新增。 |
| `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh` | include 新 tests。 |
| `mmu_verification/simu/ptw_pde_pmpflg_list` | 更新。 |
| `mmu_verification/simu/ptw_p1_list` | 加入 P1 tests。 |

### 15.7 退出标准

1. 4 个新 tests 编译通过。
2. 4 个新 tests 单跑通过。
3. `PTW-ADD-042` 命中 priority/type-id/pending clear evidence。
4. `PTW-ADD-043` 在 top-level source test 中必须打印 open/unreachable marker；effective M bypass/lock deny coverage 需另由 lower-level evidence 关闭。
5. `PTW-ADD-044` 证明 invalid/idle 不误报 direct accerr。
6. `PTW-ADD-045` 证明 clear 后旧 pmpflg 不可复用，新 update payload 正确。
7. `ptw_pde_pmpflg_list` 至少 seed 606 通过。

### 15.8 检查命令

```bash
make -C mmu_verification build TEST_NAME=test_ptw_pde_accerr_priority_type_id_001
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_accerr_priority_type_id_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_mmode_lock_matrix_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_accerr_valid_gate_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_pmp_clear_repopulate_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make regress LIST=simu/ptw_pde_pmpflg_list REGRESS_MODE=run_check REGRESS_NAME=ptw_pde_pmpflg_stage9 REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
```

## 16. 阶段 10：Regression、Closure Matrix 与 Signoff Gate

### 16.1 目标

把所有新增测试点、覆盖、SVA 和 source checker evidence 接入最终 regression/signoff。该阶段不再实现功能逻辑，只做 list、closure matrix、脚本和报告冻结。

### 16.2 允许任务

1. 更新 `simu/ptw_p0_smoke_list`、`ptw_p0_list`、`ptw_p1_list`、`ptw_pde_pmpflg_list`。
2. 更新 `simu/ptw_source_closure_matrix.csv`。
3. 更新 `doc/ptw_uvm_review/ptw_source_closure_matrix.md` 或对应人工 closure 文档。
4. 修改 `scripts/ptw_stage8_signoff_gate.py`：
   - `PTW-ADD` required id 扩展到 45。
   - `PDE-TP` required id 扩展到 19。
   - 新增 `PTW-FLOW-024..028`。
   - 检查 `PTW_SOURCE_SB_PDE_PMP_COVERAGE`。
   - 检查 `no_extra_lsu`。
   - 检查新增 `PTW-SVA-PDE/ARB` cover。
   - 保持旧 Python 兼容。
5. 更新 `ptw_source_signoff_report.md`。
6. 更新 `ptw_implementation_process.md`，记录本轮 pmpflg UVM 修改完成状态。

### 16.3 禁止任务

1. 不新增功能测试。
2. 不修改 ref model/SB/SVA 行为，除非 gate 暴露出明显日志字段拼写错误。
3. 不修改 RTL。

### 16.4 任务产出

| 产出 | 内容 |
| --- | --- |
| final regression lists | P0/P1/smoke/pmpflg list 全部接入。 |
| closure matrix | 新增 `PTW-ADD-037..045`、`PDE-TP-013..019`、`PTW-FLOW-024..028`。 |
| signoff gate | 脚本严格检查 source clean、coverage、SVA、no-extra-LSU。 |
| signoff report | 最终证据、命令、日志摘要、open/waiver。 |
| process update | 当前进度文档记录完成。 |

### 16.5 相关文件

| 文件 | 本阶段动作 |
| --- | --- |
| `mmu_verification/simu/ptw_pde_pmpflg_list` | 最终冻结。 |
| `mmu_verification/simu/ptw_p0_smoke_list` | 加代表 tests。 |
| `mmu_verification/simu/ptw_p0_list` | 加 P0 tests。 |
| `mmu_verification/simu/ptw_p1_list` | 加 P1 tests。 |
| `mmu_verification/simu/ptw_source_closure_matrix.csv` | 新增 closure rows。 |
| `mmu_verification/scripts/ptw_stage8_signoff_gate.py` | gate 更新。 |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | 更新报告。 |
| `doc/ptw_uvm_review/ptw_implementation_process.md` | 更新进度。 |

### 16.6 退出标准

1. `ptw_pde_pmpflg_list` seed `606 707` 全通过。
2. `ptw_p0_smoke_list` seed 606 通过。
3. `ptw_p0_list` seed 606 通过。
4. `ptw_p1_list` seed 606 通过或 P1 open/waiver 明确。
5. `ptw_stage8_signoff_gate.py` 通过。
6. closure matrix 中新增 requirement 没有未解释 open。
7. signoff report 能追溯每个新增 requirement 的 test、source checker、SVA/cover evidence。
8. `ptw_implementation_process.md` 记录最终状态和 debug 结论。

### 16.7 检查命令

```bash
make regress LIST=simu/ptw_pde_pmpflg_list REGRESS_MODE=run_check REGRESS_NAME=ptw_pde_pmpflg_signoff REGRESS_SEEDS="606 707" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=0
make regress LIST=simu/ptw_p0_smoke_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_smoke_pmpflg_signoff REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=0
make regress LIST=simu/ptw_p0_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_pmpflg_signoff REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=0
make regress LIST=simu/ptw_p1_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p1_pmpflg_signoff REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=0
python3 scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list simu/ptw_p0_smoke_list \
  --p0-list simu/ptw_p0_list \
  --p1-list simu/ptw_p1_list \
  --pde-pmpflg-list simu/ptw_pde_pmpflg_list \
  --p2-list simu/ptw_p2_illegal_list \
  --random-list simu/ptw_random_list \
  --consumer-list simu/ptw_consumer_evidence_list \
  --log-dir output/logs \
  --p0-seed 606 \
  --p1-seed 606 \
  --stage7-seed 707 \
  --pde-pmpflg-seed 606 \
  --pde-pmpflg-seed 707 \
  --consumer-seed 707 \
  --csv simu/ptw_source_closure_matrix.csv \
  --report ../doc/ptw_uvm_review/ptw_source_signoff_report.md \
  --legacy ../doc/ptw_uvm_review/ptw_legacy_test_action_list.md
```

## 17. 阶段依赖关系

| 阶段 | 依赖 | 原因 |
| --- | --- | --- |
| 阶段 1 | 阶段 0 | transaction 字段必须基于真实信号和语义。 |
| 阶段 2 | 阶段 1 | monitor 需要新增 transaction fields。 |
| 阶段 3 | 阶段 1 | PDE model 需要 common helper 和 enum。 |
| 阶段 4 | 阶段 2、3 | ref model 同时依赖 monitor event 和 PDE model。 |
| 阶段 5 | 阶段 4 | scoreboard coverage/no-extra-LSU 依赖 expected root cause。 |
| 阶段 6 | 阶段 0、2 | SVA 端口依赖真实信号和 bind/probe。 |
| 阶段 7 | 阶段 1 到 6 | 旧 tests 修正需要 checker/SVA 具备基本能力。 |
| 阶段 8 | 阶段 7 | 新 P0 tests 复用 helper，并依赖 checker/SVA。 |
| 阶段 9 | 阶段 8 | priority/M-mode/clear tests 复用 P0 基础能力。 |
| 阶段 10 | 阶段 8、9 | final gate 需要所有 tests 和 coverage 已存在。 |

## 18. 每阶段完成记录模板

每个阶段完成后建议在最终进度文档中记录：

```text
PMPFLG_STAGE_DONE stage=<N> name=<stage_name>
  status=<done|partial|blocked>
  changed_files=[...]
  created_files=[...]
  tests_run=[...]
  source_sb_summary=<mismatch/pending/illegal/provisional>
  sva_summary=<assert_fail/cover_missing>
  coverage_delta=[...]
  closure_delta=[PDE-TP-..., PTW-ADD-..., PTW-FLOW-...]
  open_items=[...]
  next_stage_blockers=[...]
```

## 19. 最终全局退出标准

完成阶段 10 后，整个 pmpflg UVM 修改计划才算关闭。全局退出标准：

1. 编译通过，无新增 VCS error。
2. `PTW-ADD-037..045` 对应 tests 全部通过。
3. 修改过的旧 PDE tests 全部通过。
4. `ptw_pde_pmpflg_list` seed `606 707` 通过。
5. `ptw_p0_smoke_list`、`ptw_p0_list`、`ptw_p1_list` 不回归，或 P1 open/waiver 明确。
6. `PTW_SOURCE_SB_SUMMARY` clean：`mismatch=0 pending=0 illegal=0`。
7. `PTW_SOURCE_SB_PDE_PMP_COVERAGE` 关键 bin 命中：
   - L1 tag hit allow
   - L1 tag hit deny miss
   - L2 tag hit allow
   - L2 cached L1 deny direct accerr
   - L2 cached L2 deny direct accerr
   - pmpflg update L1/L2
   - effective M bypass
   - effective M lock deny
   - no-extra-LSU
8. `PTW_SVA_COVER` 命中：
   - `PTW-SVA-PDE-011`
   - `PTW-SVA-PDE-012`
   - `PTW-SVA-PDE-013`
   - `PTW-SVA-PDE-014`
   - `PTW-SVA-PDE-015`
   - `PTW-SVA-PDE-017`
   - `PTW-SVA-ARB-010`
9. signoff gate 通过。
10. closure matrix 和 signoff report 可追溯每个新增 requirement。

## 20. 不允许的阶段关闭方式

以下情况不能作为任一阶段的完成依据：

1. 只看到最终 L1DTLB/L2TLB access fault。
2. 只看到 `mmu_translation_sb` pass。
3. L2 direct accerr 场景没有证明 no-extra-LSU。
4. 没有 cached pmpflg evidence，却用 PMP port 瞬时 flag 推断 update payload。
5. 把 L1 tag hit deny 和 L2 tag hit deny 都建模成普通 miss。
6. SVA assert 通过但 cover 未命中，却声称关闭 requirement。
7. 新增 tests 没有 scenario metadata。
8. signoff gate 没有检查新增 `PTW-ADD/PDE-TP/PTW-FLOW`。

## 21. 建议优先调试路径

若后续阶段实现中遇到大量失败，建议按以下顺序定位：

1. 先看 `PTW_PDE_EVT` 的 raw tag hit、qualified hit、cached pmpflg、reason。
2. 再看 `PTW_LEVEL_EVT` 的 `twu_mbuf_pmpflg/mbuf_pmpflg`。
3. 再看 `PTW_EXPECTED` 的 `access_src/pde_reason/pde_direct_accerr`。
4. 再看 `PTW_SOURCE_SB_PDE_PMP_COVERAGE` 是否命中目标 bin。
5. 最后看 consumer-side translation mismatch。consumer-side mismatch 不能直接判断 source-side 对错。
