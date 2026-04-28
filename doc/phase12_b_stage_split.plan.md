---
name: phase12_b_stage_split
overview: 将 Phase 12（MAEE / PTW-ready / TWU bypass 验证，B 主责、A Review SVA）拆成可手动逐个开启的细粒度阶段任务；采用 supervisor + subagents 架构，显式冻结 maee_twu_tests / ptw_tests 扩充 / 9 个 covergroup / mmu_v4_phase12_list / A-side SVA handoff 的范围、文件落点与退出口径。
todos:
  - id: stage0-preflight
    content: Stage0 冻结 Phase 12 边界、责任人与当前仓库现实
    status: pending
  - id: stage1-reuse-audit
    content: Stage1 盘点 repo 现有可复用 base、suite、probe、sequence 与 CG 宿主
    status: pending
  - id: stage2-contract-freeze
    content: Stage2 冻结命名规则、wrapper 基类、列表语法、Phase 12 与 Phase 13 的分界
    status: pending
  - id: stage3-scene-matrix
    content: Stage3 建立 MAEE / PTW-ready / TWU bypass 三大场景矩阵
    status: pending
  - id: stage4-maee0-family
    content: Stage4 处理 MAEE0-CSR 两个专用用例
    status: pending
  - id: stage5-maee1-switch-family
    content: Stage5 处理 MAEE1-direct-refill 与 MAEE dynamic switch 两个专用用例
    status: pending
  - id: stage6-ptw-ready-family
    content: Stage6 处理 PTW-ready 反压三用例
    status: pending
  - id: stage7-idle-mask-family
    content: Stage7 处理 TWU idle vs mask 语义用例
    status: pending
  - id: stage8-pde-hit-family
    content: Stage8 处理 PDE Cache hit-level 三用例
    status: pending
  - id: stage9-except-bypass-family
    content: Stage9 处理异常直通旁路三用例
    status: pending
  - id: stage10-mbuf-ready-family
    content: Stage10 处理 MBUF ready/have/multi 三用例
    status: pending
  - id: stage11-arb-grant-family
    content: Stage11 处理 arb grant/prio/fairness 三用例
    status: pending
  - id: stage12-arb-vpn-pgs-family
    content: Stage12 处理 arb vpn/pgs 两用例
    status: pending
  - id: stage13-phase12-covergroups
    content: Stage13 冻结 9 个 covergroup 的采样落点、probe 扩展与命中责任
    status: pending
  - id: stage14-suite-package-integration
    content: Stage14 规划 maee_twu_tests suite、ptw_tests suite 扩充与 test_pkg 接入
    status: pending
  - id: stage15-regression-list
    content: Stage15 规划 mmu_v4_phase12_list、Phase 12 seed 策略与回归分桶
    status: pending
  - id: stage16-a-handoff
    content: Stage16 固化 A-side SVA/Makefile handoff 契约
    status: pending
  - id: stage17-exit-evidence
    content: Stage17 固化 Phase 12 退出检查表、证据包与遗留项处理
    status: pending
isProject: false
---

# Phase 12（B）临时任务拆分执行方案

## 目标与边界

- **总目标**：
  - 将 `Phase 12` 的 `MAEE / PTW-ready / TWU bypass` 验证工作拆成后续可手动逐个开启的小阶段任务。
  - 让每个阶段都具备独立的：
    - 任务相关文件说明
    - 产出标准
    - 退出准则
  - 保证后续执行者不需要重新决定：
    - `maee_twu_tests/` 与 `ptw_tests/` 的边界
    - `9` 个 Phase 12 covergroup 的落点
    - `A` 侧 `SVA` 与 `B` 侧 `TC/CG` 的联动方式
    - `mmu_v4_phase12_list` 的收录范围和运行语法

- **B 主责交付物**：
  - `mmu_verification/testbench/test/maee_twu_tests/`
  - `mmu_verification/testbench/test/ptw_tests/` 的 `Phase 12` 扩充项
  - `mmu_verification/simu/mmu_v4_phase12_list`
  - `Phase 12` 对应 `9` 个 covergroup
  - `MAEE / PTW-ready / TWU bypass` 场景矩阵

- **A 配合交付物**：
  - `mmu_verification/testbench/top/mmu_maee_twu_sva.sv`
  - `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv` 骨架
  - `mmu_verification/Makefile` 中 `regress_v4_maee_ptw`

- **本计划不纳入**：
  - `Phase 13` 的 `sysmap_tests/` 扩充
  - `Phase 13` 的 `pmp_twu_tests_v6/`
  - `mmu_pmp_twu_sva.sv` 的完整属性实现
  - `TC-BUG-011` 的 `R19` 修复闭环；该项沿用 `Phase 11` blocked 口径
  - 额外重构 `driver/monitor/ref_model` 公共 API

## 当前仓库现实

- `2026-04-28` 的进度表状态：
  - `Phase 11` 已完成
  - `Phase 12` 已解锁但未开始
  - `Phase 13` 等待 `Phase 12`

- 当前已经存在的可复用资产：
  - `mmu_verification/testbench/test/phase9_common/phase9_generated_test_base.svh`
  - `mmu_verification/testbench/test/phase11_common/phase11_generated_test_base.svh`
  - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
  - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
  - `mmu_verification/testbench/top/tb_top.sv`
  - `cp0_maee_enable_seq` / `cp0_maee_disable_seq`
  - 现有 `ptw_tests/` 中与 `TWU/xbar/MBUF/PDE cache` 相关的 wrapper 模板

- 当前还不存在的 `Phase 12` 目标资产：
  - `mmu_verification/testbench/test/maee_twu_tests/`
  - `mmu_verification/testbench/test/maee_twu_tests/maee_twu_tests_suite.svh`
  - `mmu_verification/simu/mmu_v4_phase12_list`
  - `mmu_verification/testbench/top/mmu_maee_twu_sva.sv`
  - `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv`
  - `doc/phase12_scene_matrix.md`
  - `doc/phase12_b_stage_manifest.csv`
  - `doc/phase12_covergroup_matrix.md`
  - `doc/phase12_a_handoff.md`
  - `doc/phase12_exit_checklist.md`

- 当前 `testbench/top/` 与 `env/` 的白盒采样能力：
  - 已有 `mmu_dut_probes_if.sv`，并在 `tb_top.sv` 中绑定：
    - `ptw_xbar_hit_lvl`
    - `ptw_mbuf_twu_lvl`
    - `ptw_fault_any`
  - `Phase 12` 新增 `9` 个 covergroup 默认优先落在：
    - `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
  - 如 `9` 个 covergroup 所需信号未覆盖，先扩展：
    - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
    - `mmu_verification/testbench/top/tb_top.sv`

## 多代理执行架构

- **Supervisor**：`B-Phase12-Orchestrator`
  - 负责范围冻结、阶段编排、A/B 接口、回归分桶、退出门禁和最终 handoff。

- **Subagents**：
  - `Scope-Matrix-Auditor`
    - 负责 `Stage 0-3`。
    - 冻结 `Phase 12` 边界、可复用资产、场景矩阵、命名与列表契约。
  - `MAEE-Worker-A`
    - 负责 `Stage 4`。
    - 处理 `TC-TWU-MAEE0-CSR-001/002`。
  - `MAEE-Worker-B`
    - 负责 `Stage 5`。
    - 处理 `TC-TWU-MAEE1-REFILL-001` 与 `TC-TWU-MAEE-SWITCH-001`。
  - `PTW-Ready-Worker`
    - 负责 `Stage 6`。
    - 处理 `TC-PTW-READY-001/002/003`。
  - `TWU-State-Worker`
    - 负责 `Stage 7`。
    - 处理 `TC-TWU-IDLE-MASK-001`。
  - `PDE-Hit-Worker`
    - 负责 `Stage 8`。
    - 处理 `TC-PDE-CACHE-HIT-L3/L2/MISS-001`。
  - `Except-Bypass-Worker`
    - 负责 `Stage 9`。
    - 处理 `TC-TWU-PGFLT-BYPASS-001`、`TC-TWU-ACCERR-BYPASS-001`、`TC-TWU-EXCEPT-CONFLICT-001`。
  - `MBUF-Gating-Worker`
    - 负责 `Stage 10`。
    - 处理 `TC-MBUF-READY-GATE-001`、`TC-MBUF-HAVE-001`、`TC-MBUF-MULTI-TWU-READY-001`。
  - `Arb-Grant-Worker`
    - 负责 `Stage 11`。
    - 处理 `TC-ARB-GRANT-ONEHOT-001`、`TC-ARB-REFILL-EXCEPT-PRIO-001`、`TC-ARB-MULTI-TWU-FAIRNESS-001`。
  - `Arb-VPN-Worker`
    - 负责 `Stage 12`。
    - 处理 `TC-ARB-VPN-MATCH-001`、`TC-ARB-PGS-MATCH-001`。
  - `Coverage-Regression-Worker`
    - 负责 `Stage 13-15`。
    - 处理 `9` 个 covergroup、suite/package 接入、`mmu_v4_phase12_list`。
  - `A-Handoff-Gatekeeper`
    - 负责 `Stage 16-17`。
    - 固化 `A` 侧 `SVA/Makefile` 接口与最终退出证据包。

| 角色 | 主责阶段 | 主要输入 | 主要输出 | 下一门禁 |
| --- | --- | --- | --- | --- |
| `B-Phase12-Orchestrator` | 0/2/15/16/17 | BuildPlan / TaskDivision / Progress / repo reality | 范围冻结、列表定义、退出检查表 | Gate A/H |
| `Scope-Matrix-Auditor` | 0/1/2/3 | `doc/` 文档、`test_pkg.sv`、`ptw_tests/`、`tb_top.sv` | 复用差异表、场景矩阵、命名 contract | Gate A/B |
| `MAEE-Worker-A/B` | 4/5 | MAEE 功能点、现有 `cp0_maee_* seq` | `4` 个 MAEE wrapper 任务卡 | Gate C |
| `PTW-Ready-Worker` | 6 | `F4.NEW.6`、`ptw_ready` 观测点 | `3` 个 ready wrapper 任务卡 | Gate D |
| `TWU-State-Worker` | 7 | `F4.NEW.7`、`twu_idle/twu_mask` 语义 | `1` 个 idle-mask 任务卡 | Gate D |
| `PDE-Hit-Worker` | 8 | `F4.NEW.8`、`xbar_twu_hit_level` | `3` 个 hit-level 任务卡 | Gate E |
| `Except-Bypass-Worker` | 9 | `F4.NEW.9`、异常直通语义 | `3` 个 except-bypass 任务卡 | Gate E |
| `MBUF-Gating-Worker` | 10 | `F4.NEW.10`、`twu_data_ready/mbuf_twu_have` | `3` 个 mbuf-gating 任务卡 | Gate F |
| `Arb-Grant-Worker` | 11 | `F4.NEW.11`、`mmu_arb` 行为 | `3` 个 arb-grant 任务卡 | Gate F |
| `Arb-VPN-Worker` | 12 | `F5.16`、`ptw_arb_ref_vpn` | `2` 个 arb-vpn 任务卡 | Gate G |
| `Coverage-Regression-Worker` | 13/14/15 | 全部 wrapper 规划、probe reality、list syntax | CG 落点表、suite 接入、`mmu_v4_phase12_list` | Gate H |
| `A-Handoff-Gatekeeper` | 16/17 | `A` 侧 SVA / Makefile 依赖 | handoff 包、exit checklist | Gate I |

## 输入依据文件

- 当前进度：
  - `doc/MMU_Progress.md`
- 任务分工与 `Phase 12` 退出准则：
  - `doc/MMU_UVM_TaskDivision.md`
- 搭建计划与 `Phase 12` 交付范围：
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
- 详细功能点与 wrapper 名称对照：
  - `doc/MMU_Traceability_Matrix.csv`
- 现有测试入口与 suite：
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - `mmu_verification/testbench/test/phase9_common/phase9_generated_test_base.svh`
  - `mmu_verification/testbench/test/phase11_common/phase11_generated_test_base.svh`
- 现有白盒 CG 与 probe 入口：
  - `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
  - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
  - `mmu_verification/testbench/top/tb_top.sv`
- 现有回归列表与执行入口：
  - `mmu_verification/simu/mmu_smoke_list`
  - `mmu_verification/simu/mmu_nightly_list`
  - `mmu_verification/simu/mmu_coverage_list`
  - `mmu_verification/Makefile`

## 命名与交付契约

### 1. 工作根目录与新增资产落点

- `Phase 12` 的真实工作根目录固定为：
  - `D:\mmu_uvm\mmu_verification`
- `B` 侧新增资产默认落点固定为：
  - `maee_twu_tests/`：`mmu_verification/testbench/test/maee_twu_tests/`
  - `ptw_tests/` 扩充：`mmu_verification/testbench/test/ptw_tests/`
  - `suite` 接入：`maee_twu_tests_suite.svh`、`ptw_tests_suite.svh`
  - `test_pkg` 聚合入口：`mmu_verification/testbench/test/test_pkg.sv`
  - `list`：`mmu_verification/simu/mmu_v4_phase12_list`
  - `临时文档`：`doc/phase12_*.md` / `doc/phase12_*.csv`

### 2. wrapper 基类契约

- `Phase 12` 全部 runnable wrapper 默认继承：
  - `phase9_generated_test_base`
- 原因：
  - 已内建 `SV39` bringup
  - 已内建 `cp0_maee_enable_seq` / `cp0_maee_disable_seq`
  - 已支持 `vseq`、`cp0`、`lsu`、`ifu`、`ptw`、`sysmap`、`misc` 组合调度
- `phase11_generated_test_base` 仅在需要 `trace_id/bucket/reviewer/list_membership` 元数据时使用，不作为 `Phase 12` 默认基类

### 3. wrapper 命名契约

- 文档 traceability 名保留：
  - `TC-TWU-MAEE0-CSR-001`
  - `TC-PTW-READY-001`
  - `TC-ARB-GRANT-ONEHOT-001`
  - 等
- 仓库中的 runnable test 文件名冻结为 `Traceability Matrix` 已给出的 `test_*` 风格：
  - `test_mmu_twu_maee0_csr_path.svh`
  - `test_mmu_ptw_ready_all_mask_low.svh`
  - `test_mmu_arb_grant_onehot_check.svh`
- 每个 wrapper 文件头必须保留：
  - `TC-ID`
  - `F-ID`
  - `Priority`
  - `Checker`
  - `Reviewer`
  - `Phase=12`

### 4. covergroup 落点契约

- `Phase 12` 的 `9` 个 covergroup 默认先放入：
  - `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
- 若现有 `mmu_dut_probes_if.sv` 无法提供采样信号，必须先扩展：
  - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
  - `mmu_verification/testbench/top/tb_top.sv`
- 默认不新建第二个独立 `phase12_cg` 宿主类，除非：
  - `mmu_env_cg_whitebox.svh` 已无法保持清晰分区
  - 或信号采样节拍必须与现有 `run_phase` 分离

### 5. list 语法契约

- `mmu_v4_phase12_list` 默认沿用当前 repo 的 machine-consumable 语法：
  - 每行一个 `TEST_NAME`
  - `seed` 集合由外层 `Makefile` 或 `run_test.py` 传入
- 默认允许：
  - `#` 注释行
  - 空行
  - 分类说明注释
- 默认禁止：
  - 在 list 第 2 列写 seed 数字
  - 在 list 中内嵌 `xfail` / `blocked` 标记

### 6. Phase 12 与 Phase 13 分界契约

- `Phase 12` 只覆盖：
  - `MAEE` 双路属性选路
  - `PTW-ready` 反压
  - `TWU bypass` 相关 `PTW/xbar/MBUF/arb` 行为
- `Phase 12` 不提前吸收：
  - `sysmap_tests/` 的 `F6.NEW.2-7`
  - `pmp_twu_tests_v6/` 的 `F4.NEW.13/14`、`F7.NEW.3-9`
- `cg_maee_path` 与 `cg_maee_leaf_level` 允许同时服务 `F4.NEW.12 / F6.NEW.1`，但 `Phase 12` 只验证 `MAEE path semantics`，不提前展开 `sysmap` 区域属性用例

## 阶段总览

| Stage | 负责人 | 核心交付 | 前置 |
| --- | --- | --- | --- |
| 0 | Supervisor + `Scope-Matrix-Auditor` | Phase 12 范围冻结 | 无 |
| 1 | `Scope-Matrix-Auditor` | 复用资产审计表 | 0 |
| 2 | Supervisor | wrapper / list / CG contract | 1 |
| 3 | `Scope-Matrix-Auditor` | `phase12_scene_matrix.md` | 2 |
| 4 | `MAEE-Worker-A` | `MAEE0-CSR` 两用例任务卡 | 3 |
| 5 | `MAEE-Worker-B` | `MAEE1/SWITCH` 两用例任务卡 | 4 |
| 6 | `PTW-Ready-Worker` | ready 三用例任务卡 | 3 |
| 7 | `TWU-State-Worker` | idle-mask 任务卡 | 3 |
| 8 | `PDE-Hit-Worker` | hit-level 三用例任务卡 | 3 |
| 9 | `Except-Bypass-Worker` | except-bypass 三用例任务卡 | 3 |
| 10 | `MBUF-Gating-Worker` | mbuf-gating 三用例任务卡 | 3 |
| 11 | `Arb-Grant-Worker` | arb-grant 三用例任务卡 | 3 |
| 12 | `Arb-VPN-Worker` | arb-vpn 两用例任务卡 | 3 |
| 13 | `Coverage-Regression-Worker` | `9` 个 CG 落点矩阵 | 8/9/10/11/12 |
| 14 | `Coverage-Regression-Worker` | suite / `test_pkg` 接入规划 | 4-13 |
| 15 | Supervisor + `Coverage-Regression-Worker` | `mmu_v4_phase12_list` 规划 | 14 |
| 16 | Supervisor + `A-Handoff-Gatekeeper` | `A` 侧 handoff 包 | 15 |
| 17 | Supervisor + `A-Handoff-Gatekeeper` | `phase12_exit_checklist.md` | 16 |

## 分阶段任务卡

### Stage 0 — 冻结 Phase 12 边界、责任人与当前仓库现实

- **任务相关文件说明**：
  - 输入：
    - `doc/MMU_Progress.md`
    - `doc/MMU_UVM_TaskDivision.md`
    - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - 输出建议：
    - 本文档本节

- **输出标准**：
  - 明确 `B` 负责 `TC/CG/list/scene matrix`
  - 明确 `A` 负责 `mmu_maee_twu_sva.sv`、`mmu_pmp_twu_sva.sv` 骨架、`regress_v4_maee_ptw`
  - 明确 `Phase 12` 不提前吸收 `Phase 13` 的 `sysmap/PMP` 主体验证

- **退出准则**：
  - `Phase 12` 的输入、输出、排除项都能在单页中被复述
  - 后续执行者不再对 `B`/`A` 边界存在解释分歧

### Stage 1 — 盘点 repo 可复用 base、suite、probe、sequence 与 CG 宿主

- **任务相关文件说明**：
  - 输入：
    - `mmu_verification/testbench/test/phase9_common/phase9_generated_test_base.svh`
    - `mmu_verification/testbench/test/phase11_common/phase11_generated_test_base.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
    - `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
    - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
    - `mmu_verification/testbench/top/tb_top.sv`
  - 输出建议：
    - `doc/phase12_b_stage_manifest.csv` 中的 `reused_asset` 字段

- **输出标准**：
  - 对每类资产给出明确结论：
    - `直接复用`
    - `复用但需扩展`
    - `只能参考命名风格`
  - 形成 Phase 12 默认实现基线：
    - wrapper 基类
    - suite 接入点
    - probe/CG 宿主

- **退出准则**：
  - 所有 Phase 12 子主题都能找到默认基类和默认宿主
  - 没有“后续实现时才发现目录/接口不对”的结构性缺口

### Stage 2 — 冻结命名规则、wrapper 基类、列表语法、Phase 12/13 分界

- **任务相关文件说明**：
  - 输入：
    - `doc/MMU_Traceability_Matrix.csv`
    - `mmu_verification/testbench/test/test_pkg.sv`
    - `mmu_verification/simu/mmu_v3_regression_list`
  - 输出建议：
    - `doc/phase12_b_stage_manifest.csv`

- **输出标准**：
  - 冻结 `22` 个 Phase 12 runnable wrapper 的目标命名
  - 冻结 `mmu_v4_phase12_list` 的一列式语法
  - 冻结 `MAEE` 与 `sysmap` 的边界
  - 冻结 `TC-BUG-011` 不进入 Phase 12 runnable scope

- **退出准则**：
  - 后续实现者不需要再决定文件名、suite 名、list 语法
  - `Phase 12` 不会因 `sysmap/PMP` 需求失控膨胀

### Stage 3 — 建立 MAEE / PTW-ready / TWU bypass 三大场景矩阵

- **任务相关文件说明**：
  - 输入：
    - `doc/MMU_UVM_BuildPlan_v3_final.md`
    - `doc/MMU_Traceability_Matrix.csv`
  - 输出建议：
    - `doc/phase12_scene_matrix.md`

- **输出标准**：
  - 至少建立以下矩阵：
    - `MAEE(0/1) x leaf_level(FST/SCD/THD) x path(csr_fsm/direct_refill)`
    - `mask_count(0..4) x ready_state(0/1) x ready_edge(rise/fall)`
    - `idle(0/1) x mask(0/1) x legal/illegal`
    - `hit_level(L3/L2/MISS) x skip_stage x lsu_req_count`
    - `arb_busy x except_type x bypass_result`
    - `stage(FST/SCD/THD) x data_ready x have x multi_inflight`
    - `grant_type x concurrent_req x priority/fairness`
    - `pgs(4K/2M/1G) x vpn_matches_tag x arb_outcome`

- **退出准则**：
  - 每个矩阵都能映射到具体 test family
  - 不存在“CG 想覆盖但 test matrix 没定义”的断层

### Stage 4 — 处理 MAEE0-CSR 两个专用用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/maee_twu_tests/test_mmu_twu_maee0_csr_path.svh`
    - `mmu_verification/testbench/test/maee_twu_tests/test_mmu_twu_maee0_csr_symmetric.svh`
    - `mmu_verification/testbench/test/maee_twu_tests/maee_twu_tests_suite.svh`
  - 复用输入：
    - `phase9_generated_test_base.svh`
    - `cp0_maee_disable_seq`
    - `mmu_ptw_thrash_vseq` 或等效 PTW 压力序列

- **输出标准**：
  - `TC-TWU-MAEE0-CSR-001`
  - `TC-TWU-MAEE0-CSR-002`
  - 两者都明确：
    - `MAEE=0`
    - 叶级触发点
    - 目标 checker / target CG bins

- **退出准则**：
  - 两个 MAEE0 用例都能说明各自打的 `leaf_level` 范围
  - 至少一个用例负责 `FST`，另一个负责 `FST/SCD/THD` 对称覆盖

### Stage 5 — 处理 MAEE1-direct-refill 与 MAEE dynamic switch 两个专用用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/maee_twu_tests/test_mmu_twu_maee1_direct_refill.svh`
    - `mmu_verification/testbench/test/maee_twu_tests/test_mmu_twu_maee_dynamic_switch.svh`
    - `mmu_verification/testbench/test/maee_twu_tests/maee_twu_tests_suite.svh`
  - 复用输入：
    - `phase9_generated_test_base.svh`
    - `cp0_maee_enable_seq`
    - `cp0_reg_rw_seq`

- **输出标准**：
  - `TC-TWU-MAEE1-REFILL-001`
  - `TC-TWU-MAEE-SWITCH-001`
  - 明确：
    - `MAEE=1` 时 `csr_req=0`
    - 动态切换时不出现路径乱序

- **退出准则**：
  - `4` 个 `maee_twu_tests` 专题用例覆盖 `MAEE=0/1/switch`
  - `cg_maee_path` 与 `cg_maee_leaf_level` 都能找到 direct stimulus owner

### Stage 6 — 处理 PTW-ready 反压三用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_ptw_ready_all_mask_low.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_ptw_ready_one_unblock.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_ptw_ready_l2tlb_stall.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - `phase9_generated_test_base.svh`
    - `mmu_ptw_thrash_vseq`
    - `pmp_flg_cross_8port_seq` / `pmp_flg_normal_seq`

- **输出标准**：
  - `TC-PTW-READY-001/002/003` 三个 wrapper 全部分拆为独立 runnable test
  - 明确 `ready fall`、`ready rise`、`ready low 时禁止新请求` 的责任分工

- **退出准则**：
  - `cg_ptw_ready_transition` 的 `rise/fall` 触发责任不重叠、不遗漏
  - `Phase 12` 中关于 `F4.NEW.6` 的路径全部有单独 test owner

### Stage 7 — 处理 TWU idle vs mask 语义用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_twu_idle_implies_no_mask.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - `mmu_ptw_thrash_vseq`
    - `phase9_generated_test_base.svh`

- **输出标准**：
  - `TC-TWU-IDLE-MASK-001` 只做一件事：
    - 固化 `idle=1 -> mask=0`
    - 同时证明 `mask=0` 不蕴含 `idle=1`

- **退出准则**：
  - `cg_twu_idle_vs_mask_state` 的合法/非法组合都有测试归属
  - 该语义不被误塞进 `PTW-ready` 或 `PDE cache` 用例中处理

### Stage 8 — 处理 PDE Cache hit-level 三用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_pde_cache_hit_l3_skip_thd.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_pde_cache_hit_l2_skip_scd.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_pde_cache_full_miss_full_ptw.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - 现有 `test_pde_cache_*`
    - `phase9_generated_test_base.svh`

- **输出标准**：
  - `L3 hit`、`L2 hit`、`full miss` 三个用例一一对应
  - 每个用例明确：
    - 预置 cache 状态
    - 期望 `hit_level`
    - 期望 `skip_stage`
    - 期望 `LSU request count`

- **退出准则**：
  - `cg_xbar_hit_level` 四个编码里至少 `000/010/100` 都有明确 owner
  - 三个用例的观测点不依赖执行者再猜测 `skip_stage` 语义

### Stage 9 — 处理异常直通旁路三用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_twu_pgflt_bypass_arb.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_twu_accerr_bypass_arb.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_twu_except_conflict_pgflt_accflt.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - `mmu_stress_all_ports_vseq`
    - `pmp_flg_deny_rw_seq`

- **输出标准**：
  - `PageFault bypass`
  - `AccessFault bypass`
  - `pgflt/acc_err mutual exclusion`
  - 三者各自独立，不混成一个“大杂烩 except test”

- **退出准则**：
  - `cg_twu_except_while_arb_busy` 中 `arb_busy x except_type` 的关键交叉都有人负责
  - `pgflt` 与 `acc_err` 互斥性由单独 wrapper 承担，而不是隐含假设

### Stage 10 — 处理 MBUF ready/have/multi 三用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_mbuf_ready_gate_no_early_vld.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_mbuf_have_no_resend.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_mbuf_multi_twu_independent_ready.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - `mmu_ptw_thrash_vseq`
    - `mmu_stress_all_ports_vseq`

- **输出标准**：
  - `ready_gate`
  - `have_no_resend`
  - `multi_twu_independent_ready`
  - 三用例分别承担 `F4.NEW.10` 的三个维度

- **退出准则**：
  - `cg_twu_data_ready_per_stage` 的 `stage/data_ready/have` 关键组合都有 test owner
  - 没有将 `MBUF gating` 误简化成“只测一个 ready bit”

### Stage 11 — 处理 arb grant/prio/fairness 三用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_arb_grant_onehot_check.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_arb_refill_except_priority.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_arb_multi_twu_fairness.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - `mmu_stress_all_ports_vseq`
    - 现有 `test_arb_*`

- **输出标准**：
  - `grant onehot`
  - `exception over refill priority`
  - `multi-TWU fairness`
  - 每个用例都明确对应 `mmu_arb` 的一种行为焦点

- **退出准则**：
  - `cg_arb_grant_type` 的 `grant_type x concurrent_req` 关键交叉有覆盖责任
  - `fairness` 不再只停留在说明文字，必须落成独立 wrapper

### Stage 12 — 处理 arb vpn/pgs 两用例

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_arb_vpn_match_tag_din.svh`
    - `mmu_verification/testbench/test/ptw_tests/test_mmu_arb_pgs_bank_select.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
  - 复用输入：
    - `mmu_ptw_thrash_vseq`
    - `ifu_huge_page_fetch_seq`
    - `lsu_huge_page_seq`

- **输出标准**：
  - `TC-ARB-VPN-MATCH-001`
  - `TC-ARB-PGS-MATCH-001`
  - 两个用例分别负责：
    - `vpn field` 一致性
    - `4K/2M/1G` 下 bank/pgs 行为

- **退出准则**：
  - `cg_ptw_arb_pgs_type` 的 `pgs x vpn_matches_tag` 有完整 test owner
  - `F5.16` 不被并入 `arb grant` 测试族

### Stage 13 — 冻结 9 个 covergroup 的采样落点、probe 扩展与命中责任

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
    - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
    - `mmu_verification/testbench/top/tb_top.sv`
    - `doc/phase12_covergroup_matrix.md`
  - 目标 CG：
    - `cg_ptw_ready_transition`
    - `cg_twu_idle_vs_mask_state`
    - `cg_xbar_hit_level`
    - `cg_twu_except_while_arb_busy`
    - `cg_twu_data_ready_per_stage`
    - `cg_arb_grant_type`
    - `cg_ptw_arb_pgs_type`
    - `cg_maee_leaf_level`
    - `cg_maee_path`

- **输出标准**：
  - 每个 CG 都写清：
    - 采样信号来源
    - 建议宿主
    - 触发 test owner
    - 目标 `50%+` bin 口径
  - 如需要新增 probe 信号，必须给出最小扩展清单

- **退出准则**：
  - `9` 个 CG 无一处于“以后看波形再说”的状态
  - `MMU_DUT_PROBES_VIF` 路线能覆盖 `Phase 12` 所需白盒信号，或缺口被显式列出

### Stage 14 — 规划 maee_twu_tests suite、ptw_tests suite 扩充与 test_pkg 接入

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/testbench/test/maee_twu_tests/maee_twu_tests_suite.svh`
    - `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh`
    - `mmu_verification/testbench/test/test_pkg.sv`

- **输出标准**：
  - `maee_twu_tests_suite.svh` 只收纳 `4` 个 MAEE wrapper
  - `ptw_tests_suite.svh` 扩充 `18` 个 `Phase 12` PTW/TWU/arb wrapper
  - `test_pkg.sv` 只新增一行 `maee_twu_tests` suite include，不重排既有 suite 顺序

- **退出准则**：
  - suite 分工清晰：
    - `maee_twu_tests` 承担 `4` 个专用 MAEE wrapper
    - `ptw_tests` 承担 `18` 个 PTW-ready / TWU bypass wrapper
  - `test_pkg.sv` 接入点唯一，不制造重复 include 风险

### Stage 15 — 规划 mmu_v4_phase12_list、Phase 12 seed 策略与回归分桶

- **任务相关文件说明**：
  - 目标文件：
    - `mmu_verification/simu/mmu_v4_phase12_list`
    - `doc/phase12_b_stage_manifest.csv`
  - 复用输入：
    - `mmu_verification/simu/mmu_v3_regression_list`
    - `doc/phase11_b_stage_manifest.csv`

- **输出标准**：
  - `mmu_v4_phase12_list` 至少分 `3` 个注释桶：
    - `MAEE family`
    - `PTW-ready family`
    - `TWU bypass family`
  - `manifest` 中记录每个 test 的：
    - `trace_id`
    - `test_name`
    - `fid`
    - `priority`
    - `checker`
    - `list_membership`
    - `cg_owner`
    - `a_handoff_needed`

- **退出准则**：
  - `Phase 12` runnable scope 有且只有一个主 list
  - 执行者无需再决定哪些 test 进 `mmu_v4_phase12_list`

### Stage 16 — 固化 A 侧 SVA / Makefile handoff 契约

- **任务相关文件说明**：
  - 目标文件：
    - `doc/phase12_a_handoff.md`
  - 需要对位的 A 侧文件：
    - `mmu_verification/testbench/top/mmu_maee_twu_sva.sv`
    - `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv`
    - `mmu_verification/Makefile`

- **输出标准**：
  - 对 `A` 明确给出：
    - `3` 条 `mmu_maee_twu_sva` property 各自需要哪几个 test 触发
    - `mmu_pmp_twu_sva.sv` 在 `Phase 12` 仅需骨架可编译
    - `regress_v4_maee_ptw` 需要消费的 list 文件名
  - 明确 `B` 侧不会提前承担 `A` 侧顶层 SVA 实现

- **退出准则**：
  - 每条 `mmu_maee_twu_sva` property 都有至少一个 B 侧用例 owner
  - `A/B` 双方对 `Phase 12` 的接口边界只有一份解释

### Stage 17 — 固化 Phase 12 退出检查表、证据包与遗留项处理

- **任务相关文件说明**：
  - 目标文件：
    - `doc/phase12_exit_checklist.md`
    - `doc/phase12_b_stage_manifest.csv`
    - `doc/phase12_covergroup_matrix.md`
    - `doc/phase12_scene_matrix.md`

- **输出标准**：
  - 退出检查表必须覆盖：
    - `Phase 12` 列表 `3` 个种子 `100%` 通过
    - `mmu_maee_twu_sva` 每条 property 有 `cover property`
    - 每条 `cover property` 可达并有统计口径
    - `mmu_pmp_twu_sva.sv` 骨架编译通过
    - `9` 个 covergroup 各自 `50%+` 命中
    - 场景矩阵完整留档
  - 遗留项明确分类：
    - `Phase 13` 接手
    - `A-side pending`
    - `blocked by RTL`

- **退出准则**：
  - `Phase 12` 结束时，执行者能提交完整证据包而不是只给仿真 log
  - 所有遗留项都能明确落到 `Phase 13` 或 `A-side`，不留灰区

## Phase 12 默认 runnable scope

### MAEE 专题目录：`maee_twu_tests/`

- `test_mmu_twu_maee0_csr_path`
- `test_mmu_twu_maee0_csr_symmetric`
- `test_mmu_twu_maee1_direct_refill`
- `test_mmu_twu_maee_dynamic_switch`

### `ptw_tests/` Phase 12 扩充项

- `test_mmu_ptw_ready_all_mask_low`
- `test_mmu_ptw_ready_one_unblock`
- `test_mmu_ptw_ready_l2tlb_stall`
- `test_mmu_twu_idle_implies_no_mask`
- `test_mmu_pde_cache_hit_l3_skip_thd`
- `test_mmu_pde_cache_hit_l2_skip_scd`
- `test_mmu_pde_cache_full_miss_full_ptw`
- `test_mmu_twu_pgflt_bypass_arb`
- `test_mmu_twu_accerr_bypass_arb`
- `test_mmu_twu_except_conflict_pgflt_accflt`
- `test_mmu_mbuf_ready_gate_no_early_vld`
- `test_mmu_mbuf_have_no_resend`
- `test_mmu_mbuf_multi_twu_independent_ready`
- `test_mmu_arb_grant_onehot_check`
- `test_mmu_arb_refill_except_priority`
- `test_mmu_arb_multi_twu_fairness`
- `test_mmu_arb_vpn_match_tag_din`
- `test_mmu_arb_pgs_bank_select`

## 最终建议新增文档清单

- `doc/phase12_scene_matrix.md`
- `doc/phase12_b_stage_manifest.csv`
- `doc/phase12_covergroup_matrix.md`
- `doc/phase12_a_handoff.md`
- `doc/phase12_exit_checklist.md`

## 最终说明

- 本文档是 `Phase 12` 的**临时任务拆分计划**，不是正式实现产物。
- 后续真正执行时，按 `Stage 0 -> Stage 17` 顺序逐步开启即可，不需要再做架构决策。
- 若后续 `A` 侧对 `mmu_maee_twu_sva.sv`、`mmu_pmp_twu_sva.sv` 或 `regress_v4_maee_ptw` 有接口调整，必须先回写：
  - `doc/phase12_a_handoff.md`
  - `doc/phase12_exit_checklist.md`
  再开始改 `B` 侧 wrapper / covergroup / list。
