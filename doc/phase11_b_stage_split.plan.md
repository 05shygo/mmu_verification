---
name: phase11_b_stage_split
overview: 将 Phase 11（v3.0 Gap-driven 回归，B 主责、A 配合）拆成可手动逐个开启的细粒度阶段任务；采用 supervisor + subagents 架构，显式冻结 bug_hunt / PTW->LSU protocol / v3 regression / R19/R20 gate 的范围、列表契约、blocked/xfail 规则与 A handoff。
todos:
  - id: stage0-preflight
    content: Stage0 冻结 Phase 11 边界、责任人与当前仓库现实
    status: pending
  - id: stage1-repo-gap-audit
    content: Stage1 盘点 repo 缺口、目录现状与 A 侧外部依赖
    status: pending
  - id: stage2-contract-freeze
    content: Stage2 冻结命名规则、列表语法、blocked和doc-review处理口径
    status: pending
  - id: stage3-bug-hunt-matrix
    content: Stage3 建立 bug_hunt 总矩阵与 case-owner 对位
    status: pending
  - id: stage4-bug005-006
    content: Stage4 拆分 TC-BUG-005和006 两个 L2 真缺陷任务
    status: pending
  - id: stage5-bug007-008
    content: Stage5 拆分 TC-BUG-007和008 两个失效与PLRU真缺陷任务
    status: pending
  - id: stage6-r19-bug011
    content: Stage6 单独处理 R19 / TC-BUG-011 的 blocked和xfail门禁
    status: pending
  - id: stage7-bug012
    content: Stage7 处理 TC-BUG-012 csr_grant onehot 盲点
    status: pending
  - id: stage8-bug013
    content: Stage8 处理 TC-BUG-013 ptw write pipe reset 盲点
    status: pending
  - id: stage9-bug014
    content: Stage9 处理 TC-BUG-014 xbar cold start 盲点
    status: pending
  - id: stage10-bug015
    content: Stage10 单独处理 TC-BUG-015 的文档审查闭环
    status: pending
  - id: stage11-protocol-f442a
    content: Stage11 处理 F4.42a 的 serial outstanding 和 addr stable 两个协议用例
    status: pending
  - id: stage12-protocol-f442b
    content: Stage12 处理 F4.42b 的 no_tag 和 inorder_resp 两个协议用例
    status: pending
  - id: stage13-protocol-f442c
    content: Stage13 处理 F4.42c 的 ptr_hold 协议用例
    status: pending
  - id: stage14-regression-lists
    content: Stage14 冻结 bug_hunt和protocol列表，并构建 v3 union 回归列表
    status: pending
  - id: stage15-r20-handoff
    content: Stage15 完成 R20 风险门禁、A handoff 包和 Phase 11 退出检查表
    status: pending
isProject: false
---

# Phase 11（B）临时任务拆分执行方案

## 目标与边界

- **总目标**：
  - 将 `Phase 11` 的 `v3.0 Gap-driven 回归` 拆成后续可手动逐个开启的小阶段任务。
  - 让每个阶段都具备独立的：
    - 任务相关文件说明
    - 产出标准
    - 退出准则
  - 保证后续执行者不需要重新决定：
    - `Phase 11` 的范围
    - `bug_hunt` 与 `PTW->LSU protocol` 的归属
    - `R19/R20` 的处理口径
    - 三份回归列表的语法和包含关系

- **B 主责交付物**：
  - `mmu_verification/testbench/test/bug_hunt_tests/`
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/`
  - `mmu_verification/simu/mmu_bug_hunt_list`
  - `mmu_verification/simu/mmu_ptw_lsu_protocol_list`
  - `mmu_verification/simu/mmu_v3_regression_list`

- **A 配合交付物**：
  - `mmu_verification/Makefile` 中新增 `regress_v3_gap`
  - `R19 / tc_bug_011` 的 `xfail` 或等效 blocked 处理
  - `R20` 相关 SVA 保护确认
  - `scan_logs.pl` 自动检查接入 `regress_v3_gap`

- **本计划不纳入**：
  - Phase 12 的 `maee_twu_tests/`
  - Phase 13 的 `pmp_twu_tests_v6/`
  - B 不负责的新 SVA 文件实现本体
  - 与 Phase 11 无关的 Phase 10 回归框架重构

## 当前仓库现实

- `2026-04-27` 的进度表状态：
  - `Phase 10` 已完成
  - `Phase 11` 已解锁但未开始
  - `Phase 12` 等待 `Phase 11`
- 当前已经存在的 Phase 10 基线资产：
  - `mmu_verification/simu/mmu_smoke_list`
  - `mmu_verification/simu/mmu_nightly_list`
  - `mmu_verification/simu/mmu_coverage_list`
  - `mmu_verification/simu/exclude.do`
- 当前还不存在的 Phase 11 目标资产：
  - `mmu_verification/testbench/test/bug_hunt_tests/`
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/`
  - `mmu_verification/simu/mmu_bug_hunt_list`
  - `mmu_verification/simu/mmu_ptw_lsu_protocol_list`
  - `mmu_verification/simu/mmu_v3_regression_list`
- 当前 `Makefile` 已具备：
  - `regress_smoke`
  - `regress_nightly`
- 当前 `Makefile` 尚未具备：
  - `regress_v3_gap`
- 当前 `testbench/top/` 中已存在：
  - `mmu_arb_sva.sv`
  - `mmu_sva.sv`
  - `mmu_l2tlb_rrpv_sva.sv`
  - `mmu_plru_sva.sv`
  - `credit_sva.sv`
- 当前 `testbench/top/` 中未发现：
  - `mmu_twu_sva.sv`
  - `mmu_ptw_lsu_protocol_sva.sv`
  - `one_to_four_xbar_sva.sv`

## 多代理执行架构

- **Supervisor**：`B-Phase11-Orchestrator`
  - 负责范围冻结、阶段编排、风险门禁、A/B 依赖同步、最终 handoff。

- **Subagents**：
  - `Scope-Auditor`
    - 负责 Stage 0-2。
    - 冻结 Phase 11 边界、列表语法、命名规则、blocked 和 doc-review 规则。
  - `Bug-Hunt-Curator`
    - 负责 Stage 3。
    - 建立 `bug_hunt` 总矩阵与 case-owner 对位表。
  - `L2-Bug-Worker`
    - 负责 Stage 4。
    - 处理 `tc_bug_005/006`。
  - `Invalidate-PLRU-Worker`
    - 负责 Stage 5。
    - 处理 `tc_bug_007/008`。
  - `R19-Gatekeeper`
    - 负责 Stage 6。
    - 单独处理 `tc_bug_011`、`xfail`、JIRA 与 blocked 规则。
  - `Blindspot-Worker-A`
    - 负责 Stage 7。
    - 处理 `tc_bug_012`。
  - `Blindspot-Worker-B`
    - 负责 Stage 8。
    - 处理 `tc_bug_013`。
  - `Blindspot-Worker-C`
    - 负责 Stage 9。
    - 处理 `tc_bug_014`。
  - `Doc-Review-Worker`
    - 负责 Stage 10。
    - 处理 `tc_bug_015` 的非仿真闭环。
  - `Protocol-Worker-A`
    - 负责 Stage 11。
    - 处理 `F4.42a` 两个 protocol 用例。
  - `Protocol-Worker-B`
    - 负责 Stage 12。
    - 处理 `F4.42b` 两个 protocol 用例。
  - `Protocol-Worker-C`
    - 负责 Stage 13。
    - 处理 `F4.42c` 一个 protocol 用例。
  - `Regression-List-Builder`
    - 负责 Stage 14。
    - 构建 3 份 Phase 11 列表。
  - `Risk-Gatekeeper-and-Handoff`
    - 负责 Stage 15。
    - 处理 `R20`、`regress_v3_gap` 依赖与 A handoff。

| 角色 | 主责阶段 | 主要输入 | 主要输出 | 下一门禁 |
| --- | --- | --- | --- | --- |
| `B-Phase11-Orchestrator` | 0/2/14/15 | 全部文档与现有 repo 资产 | 范围冻结、列表定义、最终检查表 | Gate A/F |
| `Scope-Auditor` | 0/1/2 | Progress/TaskDivision/BuildPlan/Makefile | 现实差异表、命名与语法 contract | Gate A |
| `Bug-Hunt-Curator` | 3 | BuildPlan bug 表、JIRA 风险项 | bug_hunt 矩阵、owner 对位 | Gate B |
| `L2-Bug-Worker` | 4 | `tc_bug_005/006` 规格 | 两个 P0 L2 缺陷任务卡 | Gate C |
| `Invalidate-PLRU-Worker` | 5 | `tc_bug_007/008` 规格 | 两个 P0 invalidate/PLRU 任务卡 | Gate C |
| `R19-Gatekeeper` | 6 | `tc_bug_011`、JIRA、A 配合项 | R19 专项 gate | Gate D |
| `Blindspot-Worker-A/B/C` | 7/8/9 | `tc_bug_012/013/014` | 三个 P1 盲点任务卡 | Gate E |
| `Doc-Review-Worker` | 10 | `tc_bug_015` | doc-review 闭环记录定义 | Gate E |
| `Protocol-Worker-A/B/C` | 11/12/13 | 5 个 `tc_pmbuf_*` 用例、相关 SVA/CG | 3 组 protocol 任务卡 | Gate F |
| `Regression-List-Builder` | 14 | 全部 bug/protocol/positive-protection 结果 | 3 份 regression list | Gate G |
| `Risk-Gatekeeper-and-Handoff` | 15 | `R20`、Makefile、scan_logs、lists | A handoff 包、Phase 11 退出检查表 | Gate H |

## 输入依据文件

- 当前进度：
  - `doc/MMU_Progress.md`
- 任务分工与 Phase 11 退出准则：
  - `doc/MMU_UVM_TaskDivision.md`
- 搭建计划与 Phase 11 交付范围：
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
- 回归与签核主计划：
  - `doc/MMU_VerificationPlan.md`
- 现有回归入口与列表格式：
  - `mmu_verification/Makefile`
  - `mmu_verification/scripts/sim/run_reg.py`
  - `mmu_verification/simu/mmu_smoke_list`
  - `mmu_verification/simu/mmu_nightly_list`
- 现有 test / env / SVA 资产：
  - `mmu_verification/testbench/test/`
  - `mmu_verification/testbench/top/`
  - `mmu_verification/testbench/env/`

## 命名与交付契约

### 1. 运行时列表契约

- Phase 11 的 3 份 machine-consumable list 默认沿用 Phase 10 语法：
  - 每行格式：`TEST_NAME`
  - 如确有需要，可扩展为：`TEST_NAME <PLUS_ARGS...>`
- 原因：
  - 当前 `mmu_verification/scripts/run_test.py` 的 regression 模式将列表解析为：
    - 第 1 列：`TEST_NAME`
    - 后续列：局部 `PLUS_ARGS`
  - seed 集合由 `Makefile` / `run_test.py --seeds` 外层传入，不由列表第 2 列承载
- 默认禁止：
  - 将 `xfail` 状态直接编码进 runnable 条目
  - 将 `DOC_REVIEW` 项直接编码进 runnable 条目

- 默认允许：
  - `#` 注释行
  - 空行
  - 被注释掉的 blocked 项，用于保留 traceability 说明

### 2. 文件与 test 命名契约

- BuildPlan 中的 traceability 名保留为：
  - `tc_bug_005`~`tc_bug_015`
  - `tc_pmbuf_*`
- 仓库内实际 runnable test 文件默认采用当前 repo 风格：
  - `test_*.svh`
- 默认命名规则冻结为：
  - `tc_bug_005_l2_raw_vld_and_gate` -> `test_bug_005_l2_raw_vld_and_gate.svh`
  - `tc_bug_011_twu_2m_csr_cross` -> `test_bug_011_twu_2m_csr_cross.svh`
  - `tc_pmbuf_serial_outstanding_001` -> `test_pmbuf_serial_outstanding_001.svh`
- 头注释中必须保留：
  - `TC-ID`
  - `F-ID`
  - `Priority`
  - `Checker`
  - `Reviewer`
  - `Phase=11`

### 3. blocked / xfail / DOC_REVIEW 契约

- `Blocked-Waiting-RTL-Fix`
  - 不直接写入 machine-consumable list。
  - 统一进入 sidecar manifest。
- `xfail`
  - 由 A 侧 `regress_v3_gap` 或其等效 wrapper 消费。
  - B 侧列表保持纯净，不自行发明第 3 列语法。
- `DOC_REVIEW`
  - 不进入 machine-consumable list。
  - 只进入文档审查清单与 Phase 11 退出检查表。

### 4. sidecar manifest 契约

- Phase 11 建议新增一份 sidecar 记录文件，默认路径冻结为：
  - `doc/phase11_b_stage_manifest.csv`
- 推荐字段：
  - `bucket`
  - `trace_id`
  - `test_name`
  - `status`
  - `seed_count`
  - `fid`
  - `priority`
  - `owner`
  - `blocked_reason`
  - `xfail_required`
  - `review_mode`
  - `list_membership`

## 分阶段执行

### Stage 0 - 基线冻结与 Phase 11 开工门禁

- **任务相关文件**：
  - `doc/MMU_Progress.md`
  - `doc/MMU_UVM_TaskDivision.md`
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - `mmu_verification/Makefile`
  - 本文档

- **产出标准**：
  - 书面冻结 `Phase 11 = v3.0 Gap-driven 回归`。
  - 书面冻结 B 和 A 的职责边界。
  - 书面冻结 Phase 11 只包含：
    - `bug_hunt_tests`
    - `ptw_lsu_protocol_tests`
    - 3 份 Phase 11 list
    - `R19/R20` 风险 gate
  - 明确 `Phase 10` 已完成，可作为 Phase 11 前置资产直接复用。

- **退出准则**：
  - 任何执行者都不需要再问“Phase 11 到底包含什么”。
  - A/B 边界已写死在文档里，不依赖口头同步。

### Stage 1 - repo 缺口盘点与外部依赖登记

- **任务相关文件**：
  - `mmu_verification/testbench/test/`
  - `mmu_verification/testbench/top/`
  - `mmu_verification/simu/`
  - `mmu_verification/Makefile`

- **产出标准**：
  - 形成一份现实差异表，至少列出：
    - `bug_hunt_tests/` 目录不存在
    - `ptw_lsu_protocol_tests/` 目录不存在
    - 3 份 Phase 11 list 不存在
    - `regress_v3_gap` 不存在
    - `mmu_twu_sva.sv` 不存在
    - `mmu_ptw_lsu_protocol_sva.sv` 不存在
  - 将上述差异分类为：
    - `B-own`
    - `A-own`
    - `shared`

- **退出准则**：
  - 不存在未登记的外部依赖。
  - 后续 stage 不会假设某个目录或 SVA “已经有了”。

### Stage 2 - 命名、列表语法与审查口径冻结

- **任务相关文件**：
  - `mmu_verification/scripts/run_test.py`
  - `mmu_verification/simu/mmu_smoke_list`
  - `mmu_verification/simu/mmu_nightly_list`
  - 本文档 “命名与交付契约” 章节

- **产出标准**：
  - 冻结 3 份 Phase 11 list 的语法为 `TEST_NAME` 或 `TEST_NAME <PLUS_ARGS...>`。
  - 冻结 test 文件命名从 `tc_*` traceability 名映射到 `test_*.svh`。
  - 冻结 `Blocked / xfail / DOC_REVIEW` 不直接写进 machine-consumable list。
  - 冻结 sidecar manifest 为 Phase 11 的唯一非运行时状态记录。

- **退出准则**：
  - 后续所有 stage 都在同一命名和列表 contract 下工作。
  - 不允许中途重新引入“第 2 列 = seed_count”的旧口径。

### Stage 3 - bug_hunt 总矩阵与 case-owner 冻结

- **任务相关文件**：
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - `doc/MMU_UVM_TaskDivision.md`
  - 建议输出：`doc/phase11_bug_hunt_matrix.md`

- **产出标准**：
  - 建立 `tc_bug_005~008, 011~015` 的总矩阵。
  - 每条记录至少包含：
    - `trace_id`
    - `fid`
    - `priority`
    - `status`
    - `owner`
    - `target_sva_or_cg`
    - `needs_a_review`
    - `runnable`
  - 将 8 条记录分派到后续 Stage 4-10。

- **退出准则**：
  - 每个 bug case 都有唯一 owner 和唯一后续 stage。
  - 不存在“先做哪个 bug 再说”的开放性决策。

### Stage 4 - TC-BUG-005 / 006：L2 真缺陷组

- **任务相关文件**：
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_005_l2_raw_vld_and_gate.svh`
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_006_l2_is_dtlb_store.svh`
  - `mmu_verification/testbench/top/mmu_arb_sva.sv`
  - `mmu_verification/testbench/test/l2tlb_tests/`
  - `mmu_verification/testbench/env/`

- **产出标准**：
  - 为 `tc_bug_005`、`tc_bug_006` 各形成一张独立任务卡。
  - 每张任务卡写清：
    - 缺陷描述
    - 目标激励路径
    - 预期观测点
    - 对应 SVA/CG
    - 修复前是 `blocked` 还是可直接验证
  - 默认单独运行，不与其它 bug 合并用例。

- **退出准则**：
  - 两个 L2 缺陷已被拆成两个可独立启动的小任务。
  - 每个任务都能独立追踪 `pass/fail/blocked`。

### Stage 5 - TC-BUG-007 / 008：失效与 PLRU 真缺陷组

- **任务相关文件**：
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_007_rrpv_post_inv.svh`
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_008_pplru_entry0_first_hit.svh`
  - `mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`
  - `mmu_verification/testbench/top/mmu_plru_sva.sv`

- **产出标准**：
  - 为 `tc_bug_007`、`tc_bug_008` 各形成一张独立任务卡。
  - 明确：
    - invalidate 前置激励
    - 复位后首次命中激励
    - 相关 SVA
    - 相关 CG
    - 是否要求特定 seed 数

- **退出准则**：
  - 两个缺陷不再作为“RRPV/PLRU 大类”混合处理。
  - 每个任务均具备独立运行和独立签核口径。

### Stage 6 - R19 / TC-BUG-011 专项 gate

- **任务相关文件**：
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_011_twu_2m_csr_cross.svh`
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - JIRA 关闭记录
  - 建议输出：`doc/phase11_r19_gate.md`

- **产出标准**：
  - 单独定义 `R19` 任务，不与其它 bug 合并。
  - 书面冻结：
    - `tc_bug_011` 为 P0 高危
    - 修复前状态默认 `Blocked-Waiting-RTL-Fix`
    - A 侧需要提供 `xfail` 或等效 gate
    - 与 `csr_data_flop` 相关的 2MB CSR 跨界场景默认一并 blocked
  - 输出一份 R19 证据清单模板：
    - JIRA ID
    - 关闭截图
    - RTL fix 版本
    - 解除 blocked 的时间点

- **退出准则**：
  - `R19` 已从普通 bug_hunt 流中剥离为单独门禁。
  - 未关闭前不会误入普通回归通过率统计。

### Stage 7 - TC-BUG-012：csr_grant onehot 盲点

- **任务相关文件**：
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_012_csr_grant_onehot.svh`
  - `mmu_verification/testbench/top/mmu_twu_sva.sv` 或 A 侧等效 SVA 承载文件

- **产出标准**：
  - 定义 `tc_bug_012` 的独立任务卡。
  - 明确：
    - `F4.NEW.5`
    - 主保护机制是 `sva_csr_grant_onehot`
    - 是否需要专门 CG 证据
    - 最低 seed 要求

- **退出准则**：
  - `tc_bug_012` 已拥有独立的实现、验证、签核口径。

### Stage 8 - TC-BUG-013：ptw write pipe reset 盲点

- **任务相关文件**：
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_013_ptw_write_pipe_reset.svh`
  - `mmu_verification/testbench/top/mmu_arb_sva.sv` 或 A 侧等效 SVA 承载文件

- **产出标准**：
  - 定义 `tc_bug_013` 的独立任务卡。
  - 明确：
    - reset 竞争窗口
    - `sva_ptw_write_pipe_reset_safe`
    - 与 `R20` 的关联

- **退出准则**：
  - `tc_bug_013` 不再作为普通 P1 bug 散落处理。
  - 后续可直接被 Stage 15 的 `R20` gate 消费。

### Stage 9 - TC-BUG-014：xbar cold start 盲点

- **任务相关文件**：
  - `mmu_verification/testbench/test/bug_hunt_tests/test_bug_014_xbar_cold_start.svh`
  - `mmu_verification/testbench/top/one_to_four_xbar_sva.sv` 或 A 侧等效 SVA 承载文件
  - 相关 CG 定义文件

- **产出标准**：
  - 定义 `tc_bug_014` 的独立任务卡。
  - 明确：
    - cold-start 触发场景
    - `cg_xbar_cold_start`
    - 是否与 `tc_bug_013` 合并到 `R20` 保护组

- **退出准则**：
  - `tc_bug_014` 拥有可独立开启的任务定义。
  - 与 `R20` 的连接关系已固定。

### Stage 10 - TC-BUG-015：DOC_REVIEW 闭环

- **任务相关文件**：
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - 相关 RTL 注释或设计说明
  - 建议输出：`doc/phase11_bug015_doc_review.md`

- **产出标准**：
  - 为 `tc_bug_015` 建立一张非仿真任务卡。
  - 明确输出不是 log，而是：
    - 审查结论
    - 残留注释问题
    - 是否需要后续 RTL 注释修订
    - 是否需要新增 waiver/JIRA

- **退出准则**：
  - `tc_bug_015` 的闭环口径与 runnable test 完全分离。
  - 不再尝试把 `DOC_REVIEW` 项强塞进 regression list。

### Stage 11 - F4.42a：serial outstanding / addr stable

- **任务相关文件**：
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/test_pmbuf_serial_outstanding_001.svh`
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/test_pmbuf_addr_stable_001.svh`
  - `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` 或 A 侧等效 protocol SVA 承载文件
  - 相关 protocol CG 定义文件

- **产出标准**：
  - 为 2 个 `F4.42a` 用例分别形成任务卡。
  - 明确：
    - outstanding 约束
    - req/address stable 约束
    - 目标 SVA
    - 3-seed 通过口径

- **退出准则**：
  - `F4.42a` 不再是目录级描述，而是 2 个独立 protocol 任务。

### Stage 12 - F4.42b：no_tag / inorder_resp

- **任务相关文件**：
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/test_pmbuf_no_tag_001.svh`
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/test_pmbuf_inorder_resp_001.svh`
  - `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` 或 A 侧等效 protocol SVA 承载文件

- **产出标准**：
  - 为 2 个 `F4.42b` 用例分别形成任务卡。
  - 明确：
    - 何时允许 `vld`
    - 响应顺序的观测点
    - 单测口径
    - 3-seed 口径

- **退出准则**：
  - 两个 protocol 用例可被独立启动与独立验收。

### Stage 13 - F4.42c：ptr_hold

- **任务相关文件**：
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/test_pmbuf_ptr_hold_001.svh`
  - `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` 或 A 侧等效 protocol SVA 承载文件
  - 相关 `cg_mbuf_ptr_hold` 定义文件

- **产出标准**：
  - 为 `tc_pmbuf_ptr_hold_001` 形成独立任务卡。
  - 明确：
    - `ptr_hold` 触发条件
    - `sva_mbuf_ptr_only_on_response`
    - `cg_mbuf_ptr_hold`
    - 单测与 3-seed 要求

- **退出准则**：
  - `F4.42c` 单独成任务，不和 `F4.42a/b` 混签核。

### Stage 14 - 3 份 Phase 11 回归列表冻结

- **任务相关文件**：
  - `mmu_verification/simu/mmu_bug_hunt_list`
  - `mmu_verification/simu/mmu_ptw_lsu_protocol_list`
  - `mmu_verification/simu/mmu_v3_regression_list`
  - `doc/phase11_b_stage_manifest.csv`

- **产出标准**：
  - 生成 `mmu_bug_hunt_list`：
    - 仅包含 runnable bug-hunt test
    - 不含 `DOC_REVIEW`
    - 默认不含 blocked 的 `tc_bug_011`
  - 生成 `mmu_ptw_lsu_protocol_list`：
    - 包含 5 个 runnable `tc_pmbuf_*`
  - 生成 `mmu_v3_regression_list`：
    - `mmu_bug_hunt_list`
    - `mmu_ptw_lsu_protocol_list`
    - 正向保护 `tc_bug_001~004` 对应 runnable test
  - 在 sidecar manifest 中显式标记：
    - `tc_bug_011` 被 blocked/xfail 托管
    - `tc_bug_015` 为 `DOC_REVIEW`

- **退出准则**：
  - 3 份 list 的运行含义、包含关系和排除项全部固定。
  - A 在不阅读 BuildPlan 原文的情况下也能直接消费这些 list。

### Stage 15 - R20 门禁、A handoff 与 Phase 11 退出检查表

- **任务相关文件**：
  - `mmu_verification/Makefile`
  - `mmu_verification/scripts/scan_logs.pl`
  - `mmu_verification/simu/mmu_bug_hunt_list`
  - `mmu_verification/simu/mmu_ptw_lsu_protocol_list`
  - `mmu_verification/simu/mmu_v3_regression_list`
  - `doc/phase11_r19_gate.md`
  - `doc/phase11_b_stage_manifest.csv`
  - 建议输出：`doc/phase11_exit_checklist.md`

- **产出标准**：
  - 单独定义 `R20` gate：
    - `tc_bug_013`
    - `tc_bug_014`
    - `sva_ptw_write_pipe_reset_safe`
    - `cg_xbar_cold_start`
    - 10 seeds
    - 无 fire
    - 分布平衡
  - 形成给 A 的 handoff 包，至少包含：
    - 3 份 list
    - sidecar manifest
    - `R19` 状态
    - `R20` 状态
    - `regress_v3_gap` 接口要求
    - `scan_logs.pl` 集成要求
  - 形成 Phase 11 退出检查表：
    - bug-hunt 单测状态
    - protocol 单测状态
    - `R19` 状态
    - `R20` 状态
    - `mmu_v3_regression_list` 通过率

- **退出准则**：
  - A 可以直接接手 `regress_v3_gap` 联调。
  - `Phase 11` 的所有 blocked、xfail、doc-review 项都已书面化，不会污染通过率统计。

## 阶段间门禁

- **Gate A（Stage0->1/2）**：
  - Phase 11 范围和 A/B 边界已冻结。

- **Gate B（Stage2->3）**：
  - 命名、列表语法、blocked/doc-review 规则已冻结。

- **Gate C（Stage3->4/5）**：
  - `tc_bug_005~008` 已有唯一 owner 和唯一目标文件命名。

- **Gate D（Stage3->6）**：
  - `R19 / tc_bug_011` 已单独抽离为专项 gate。

- **Gate E（Stage3->7/8/9/10）**：
  - `tc_bug_012~015` 的 runnable / non-runnable 边界已清楚。

- **Gate F（Stage2->11/12/13）**：
  - 5 个 `tc_pmbuf_*` 的文件命名与 SVA/CG 对位已冻结。

- **Gate G（Stage4-14 汇总）**：
  - bug-hunt、protocol、positive protection 的列表归属已全部清楚。

- **Gate H（Phase11 Exit）**：
  - 3 份 list、`R19/R20` 记录、A handoff 包、退出检查表全部齐备。

## 风险与缓解

- **风险 1：BuildPlan 的 traceability 名与 repo 的 runnable test 命名不一致**
  - 缓解：Stage 2 冻结 `tc_* -> test_*.svh` 映射，不在执行期临时起名。

- **风险 2：当前回归脚本不支持注释、xfail 或 DOC_REVIEW**
  - 缓解：Stage 2 冻结 machine-consumable list 只保留 `TEST_NAME SEED_COUNT`，状态信息放 sidecar manifest。

- **风险 3：`tc_bug_011` 既要求进 Phase 11 范围，又在修复前应 blocked**
  - 缓解：Stage 6 单独做 `R19` 专项 gate；未闭环前不计入普通回归通过率。

- **风险 4：`tc_bug_015` 是 DOC_REVIEW，无法进入当前回归脚本**
  - 缓解：Stage 10 单独定义文档闭环，不挤进 machine-consumable list。

- **风险 5：当前 repo 缺少 `mmu_twu_sva.sv` 与 `mmu_ptw_lsu_protocol_sva.sv`**
  - 缓解：Stage 1 先登记为外部依赖；Stage 15 通过 A handoff 明确接入责任。

- **风险 6：`regress_v3_gap` 当前不存在**
  - 缓解：Stage 15 将 Makefile 接口需求和 `scan_logs.pl` 集成要求一次性交给 A。

## Skill 使用判断

- 本轮不调用额外 skill。
- 原因：
  - 任务本质是本地文档和仓库现状驱动的验证拆分规划。
  - 当前可用 skill 中没有比直接基于 `Progress / TaskDivision / BuildPlan / Makefile / simu` 事实落文档更贴合的数字 IC 验证专用能力。

## 说明

- 本文件是 `Phase 11` 的临时执行级拆分计划。
- 项目内权威副本路径冻结为：
  - `doc/phase11_b_stage_split.plan.md`
