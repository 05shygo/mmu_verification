---
name: phase10_b_stage_split
overview: 将 Phase 10（A 主回归脚本与覆盖率收敛，B 负责三份 regression list 与 exclude.do）拆成可独立启动的多阶段任务；采用 supervisor + subagents 架构，主文档定义目录口径冻结、列表语法冻结、资产对账、smoke/nightly/coverage 分层、waiver 基线与 A/B handoff 门禁。
todos:
  - id: stage0-preflight
    content: Stage0 冻结 Phase 10 的 B-only 范围、simu 目录口径与旧脚本路径冲突
    status: pending
  - id: stage1-contract-freeze
    content: Stage1 冻结 machine-consumable list 语法、TEST_NAME 主键规则与 sidecar manifest 字段
    status: pending
  - id: stage2-asset-census
    content: Stage2 完成 Phase8/9 资产对账，清出 smoke/nightly/coverage 候选池
    status: pending
  - id: stage3-smoke-candidates
    content: Stage3 生成 smoke 候选矩阵与首轮精简清单
    status: pending
  - id: stage4-smoke-freeze
    content: Stage4 冻结 mmu_smoke_list 的条目、顺序、种子数与理由
    status: pending
  - id: stage5-nightly-candidates
    content: Stage5 生成 nightly 候选矩阵并完成 Phase9 基线 test 全覆盖映射
    status: pending
  - id: stage6-nightly-freeze
    content: Stage6 冻结 mmu_nightly_list、holdback 清单与 smoke/nightly 关系
    status: pending
  - id: stage7-coverage-candidates
    content: Stage7 生成 coverage 候选矩阵，拆分 plusargs-free 与 vseq 依赖项
    status: pending
  - id: stage8-coverage-freeze
    content: Stage8 冻结 mmu_coverage_list、seed 口径与覆盖率数据库冲突说明
    status: pending
  - id: stage9-waiver-census
    content: Stage9 汇总覆盖率 waiver 候选、来源依据、关闭条件与 owner
    status: pending
  - id: stage10-exclude-freeze
    content: Stage10 冻结 exclude.do 条目模板、注释规范与 hpdcache 语法复用边界
    status: pending
  - id: stage11-handoff-gate
    content: Stage11 完成 A handoff 包、Phase10 B 退出检查表与 Phase11 接口说明
    status: pending
isProject: false
---

# Phase 10（B）临时任务拆分执行方案

## 目标与边界

- **总目标**：
  - 为 Phase 10 的 **B 侧交付物**建立一份可直接执行的临时拆分计划。
  - B 的最终公开交付物只包含：
    - `mmu_verification/simu/mmu_smoke_list`
    - `mmu_verification/simu/mmu_nightly_list`
    - `mmu_verification/simu/mmu_coverage_list`
    - `mmu_verification/simu/exclude.do`
  - 三份 list 负责把 Phase 8 / Phase 9 已完成资产组织成 smoke / nightly / coverage 三层回归入口；`exclude.do` 负责建立可审计的覆盖率豁免基线。

- **B 主责**：
  - 按 `doc/MMU_VerificationPlan.md` §6.4 / §8 / §9 整理三份回归列表。
  - 以当前仓库真实 test 资产为输入，完成条目级对账、分层与 holdback 说明。
  - 编写 `exclude.do` 的 waiver 条目，保证每条都带注释与关闭条件。

- **A 主责**：
  - `Makefile` 增加 `regress` / `regress_smoke` / `regress_nightly` / `regress_cov` 类入口。
  - 修改 `scripts/cov_hier.cfg`、`scripts/run_test.py`、`scripts/run_vcs_verdi.py`。
  - 接管 list 消费、回归执行、覆盖率合并与报告生成。

- **本计划不纳入**：
  - 新 test / 新 vseq / 新 covergroup / 新 SVA 开发。
  - `Makefile regress` 实现。
  - `scripts/run_test.py` / `scripts/run_vcs_verdi.py` / `scripts/sim/run_reg.py` 功能改造。
  - `cov_hier.cfg` 的 DUT 层次修正。
  - Phase 11 的 `mmu_bug_hunt_list`、`mmu_ptw_lsu_protocol_list`、`mmu_v3_regression_list`。

- **当前仓库现实与文档口径冲突**：
  - `BuildPlan` 与 `TaskDivision` 规定 Phase 10 交付物路径为 `mmu_verification/simu/`。
  - 当前仓库 **不存在** `mmu_verification/simu/` 目录。
  - legacy `scripts/sim/run.py` 仍硬编码 `testbench/simu/run.do` / `run_no_log.do`，但当前仓库也 **不存在** `testbench/simu/`。
  - legacy `scripts/sim/run_reg.py` 是当前唯一按文件读取回归列表的脚本，但它只稳定支持两列格式：`TEST_NAME SEED_COUNT`。
  - 当前 `Makefile` 支持精确 `TEST_NAME` 与目录 alias 两种跑法；但 legacy Python 脚本不理解目录 alias。

- **B-only 决策默认值**：
  - Phase 10 B 侧所有公开 list 以 **精确 UVM test class 名** 为主键，不用目录 alias。
  - machine-consumable list 的默认行格式固定为：`TEST_NAME SEED_COUNT`。
  - list 文件不携带 `PLUS_ARGS`、固定 seed、输出路径、目录 alias、`.svh` 路径。
  - `PLUS_ARGS` 依赖项只进入 sidecar manifest，不直接写入三份公开 list，直到 A 侧 parser/Makefile 接口完成支持。

## 多代理执行架构

- **Supervisor**：`B-Phase10-Orchestrator`
  - 负责范围冻结、路径与语法口径冻结、矩阵合并、最终 handoff 与退出门禁。

- **子代理**：
  - `PathSyntax-Auditor`
    - 审核 `simu/` vs `testbench/simu/` 路径冲突。
    - 冻结 list 文件语法与解析约束。
  - `Asset-Census`
    - 盘点 Phase 8 / 9 已有 test / vseq / suite 资产。
    - 做 repo 实际数量与 Progress 合同数对账。
  - `Smoke-Curator`
    - 抽取 smoke 候选条目，压到 `< 30 min` 的目标范围。
  - `Nightly-Curator`
    - 做 Phase 9 基线全覆盖映射，给出 nightly 主清单与 holdback。
  - `Coverage-Curator`
    - 识别高价值 coverage 源，拆分 plusargs-free 与 `test_mmu_vseq_runner` 依赖项。
  - `Waiver-Curator`
    - 汇总 coverage waiver 候选，按 unreachable / reserved / tool-limit / known-gap 分类。
  - `A-Handoff-Gatekeeper`
    - 打包给 A 的 list 契约、未决依赖、review 点与 Phase 11 接口。

| 角色 | 主责 stage | 主要输入 | 主要输出 | 进入下一阶段 gate |
| --- | --- | --- | --- | --- |
| `B-Phase10-Orchestrator` | Stage 0 / 1 / 11 | 全部文档与脚本 | 范围冻结、格式冻结、最终 handoff | Gate A / B / F |
| `PathSyntax-Auditor` | Stage 0 / 1 | `BuildPlan`、`TaskDivision`、`scripts/sim/run.py`、`run_reg.py` | 路径冲突表、list 语法 contract | Gate A |
| `Asset-Census` | Stage 2 | `testbench/test/`、Phase 8/9 文档、`Makefile` | 候选池矩阵、对账清单 | Gate B |
| `Smoke-Curator` | Stage 3 / 4 | `basic/l1*/tlbop/ptw/pmp/sysmap/cp0/cross/err` | smoke 候选矩阵、`mmu_smoke_list` | Gate C |
| `Nightly-Curator` | Stage 5 / 6 | Phase 9 基线目录全集 | nightly 候选矩阵、`mmu_nightly_list`、holdback 清单 | Gate D |
| `Coverage-Curator` | Stage 7 / 8 | Phase 8 vseq、随机/压力类 test | coverage 候选矩阵、`mmu_coverage_list`、blocked vseq 附录 | Gate E |
| `Waiver-Curator` | Stage 9 / 10 | `VerificationPlan`、`cov_hier.cfg`、hpdcache `exclude.do` | waiver 矩阵、`exclude.do` 条目模板 | Gate E |
| `A-Handoff-Gatekeeper` | Stage 11 | 三份 list、`exclude.do`、未决项 | Phase10 B 退出检查表、A review 包 | Gate F |

## 输入依据文件

- 当前进度：
  - `D:/mmu_uvm/doc/MMU_Progress.md`
- 任务分工与 Phase 10 退出准则：
  - `D:/mmu_uvm/doc/MMU_UVM_TaskDivision.md`
- 搭建计划与目录口径：
  - `D:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md`
- 回归分层与签核标准：
  - `D:/mmu_uvm/doc/MMU_VerificationPlan.md`
- 既有阶段文档：
  - `D:/mmu_uvm/doc/phase7_b_stage_split.plan.md`
  - `D:/mmu_uvm/doc/phase8_m8_vseq_f_mapping.md`
  - `D:/mmu_uvm/doc/phase8_m8_a_review.md`
  - `D:/mmu_uvm/doc/phase9_b_stage_split.plan.md`
- 当前回归/覆盖率入口与脚本：
  - `D:/mmu_uvm/mmu_verification/Makefile`
  - `D:/mmu_uvm/mmu_verification/scripts/run_test.py`
  - `D:/mmu_uvm/mmu_verification/scripts/run_vcs_verdi.py`
  - `D:/mmu_uvm/mmu_verification/scripts/sim/run.py`
  - `D:/mmu_uvm/mmu_verification/scripts/sim/run_reg.py`
  - `D:/mmu_uvm/mmu_verification/scripts/cov_hier.cfg`
  - `D:/mmu_uvm/mmu_verification/scripts/scan_logs.pl`
- 覆盖率豁免语法参考：
  - `D:/mmu_uvm/hpdcache_verification/testbench/simu/exclude.do`

**路径约定**：

- 工程根：`D:/mmu_uvm`
- 回归与脚本工作目录：`D:/mmu_uvm/mmu_verification`
- Phase 10 目标 list / waiver 目录：`D:/mmu_uvm/mmu_verification/simu/`
- test 资产根目录：`D:/mmu_uvm/mmu_verification/testbench/test/`

## 候选资产快照

- 当前仓库按 `uvm_component_utils(...)` 扫描得到的注册 test class 总数为 **266**。
- 这个数字 **不等于** `MMU_Progress.md` 中 Phase 9 的 “259 wrapper + 3 baseline = 262” 合同数；Stage 2 必须完成对账，解释差异来源。

| 目录 | 当前扫描到的注册 test class 数 | 在 Phase 10 的默认角色 |
| --- | --- | --- |
| `basic_tests` | 6 | smoke-first / sanity 基线 |
| `l1itlb_tests` | 20 | smoke / nightly |
| `l1dtlb_tests` | 23 | smoke / nightly |
| `l2tlb_tests` | 42 | nightly / coverage |
| `ptw_tests` | 44 | smoke / nightly / coverage |
| `tlbop_tests` | 25 | smoke / nightly / coverage |
| `pmp_tests` | 15 | smoke / nightly |
| `sysmap_tests` | 17 | smoke / nightly |
| `cp0_tests` | 16 | smoke / nightly |
| `flush_tests` | 9 | nightly / coverage |
| `cross_tests` | 8 | smoke / nightly |
| `perf_tests` | 22 | nightly / coverage |
| `err_tests` | 18 | smoke / nightly / coverage |
| `phase8_tests` | 1 | coverage 候选；默认 blocked，因依赖 `+VSEQ_NAME` |

## 命名与模板

### 1. 公开 list 文件 contract

- 三份公开 list 的默认 contract 完全一致：
  - 每行格式：`TEST_NAME SEED_COUNT`
  - `TEST_NAME` 必须是 **精确 UVM test class 名**
  - `SEED_COUNT` 必须是十进制整数
- 公开 list **禁止**出现：
  - 空行
  - 注释行
  - tab
  - 多个连续空格
  - 目录 alias（如 `basic_tests`）
  - `.svh` 文件路径
  - 固定 seed
  - `PLUS_ARGS`
  - 输出目录 / 线程数 / 事务数等脚本参数

### 2. sidecar manifest contract

- 为了表达 smoke/nightly/coverage 的选型理由，需要维护一份 sidecar manifest。
- sidecar manifest 不是给脚本直接消费，而是给 B 自己与 A review 使用；列建议固定为：
  - `bucket`
  - `test_name`
  - `seed_count`
  - `source_dir`
  - `phase_origin`
  - `feature_or_fid`
  - `requires_plusargs`
  - `plus_args`
  - `reason`
  - `reviewer`
  - `status`

### 3. `exclude.do` 条目模板

- Phase 10 默认复用 hpdcache 的 `coverage exclude ... -comment "..."` 语法风格。
- 每个 waiver block 必须满足：
  - 明确 `scope`
  - 明确排除对象类型（如 `-togglenode`）
  - 明确 `-comment`
  - comment 里写明原因、来源依据、关闭条件
- `exclude.do` 内允许做分节注释，但最终 tool command 行本身不得省略 comment。

## 分阶段执行

### Stage 0 - 基线冻结与路径冲突清零

- **任务相关文件**：
  - `doc/MMU_Progress.md`
  - `doc/MMU_UVM_TaskDivision.md`
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - `mmu_verification/scripts/sim/run.py`
  - `mmu_verification/scripts/sim/run_reg.py`
  - `mmu_verification/Makefile`

- **产出标准**：
  - 书面冻结 Phase 10 B-only 范围：只做三份 list 与 `exclude.do`。
  - 书面冻结 Phase 10 公开交付目录为 `mmu_verification/simu/`。
  - 输出一份路径冲突表，至少列出：
    - 文档口径 `simu/`
    - stale 脚本口径 `testbench/simu/`
    - 仓库当前不存在这两个目录的现实
  - 书面冻结“不使用目录 alias”的默认规则。

- **退出准则**：
  - 不再存在“list 最后该放哪一层目录”的歧义。
  - B 与 A 的职责边界在本文档里写死，不保留口头约定。

### Stage 1 - list 语法与 sidecar manifest 冻结

- **任务相关文件**：
  - `mmu_verification/scripts/sim/run_reg.py`
  - `mmu_verification/scripts/run_test.py`
  - `mmu_verification/Makefile`
  - `doc/phase8_m8_vseq_f_mapping.md`
  - 本文档 “命名与模板” 章节

- **产出标准**：
  - 冻结三份公开 list 的 machine-consumable 语法：`TEST_NAME SEED_COUNT`。
  - 冻结 `TEST_NAME` 必须是精确 UVM test class 名，不允许目录 alias。
  - 冻结 sidecar manifest 字段定义。
  - 把所有依赖 `+VSEQ_NAME` 的 coverage 条目标记为 `requires_plusargs=1`。

- **退出准则**：
  - 后续所有 stage 都只在同一语法 contract 下工作。
  - 不再允许在 Stage 3+ 临时引入第 3 列或注释行。

### Stage 2 - Phase 8 / 9 资产对账

- **任务相关文件**：
  - `mmu_verification/testbench/test/`
  - `doc/MMU_Progress.md`
  - `doc/phase8_m8_vseq_f_mapping.md`
  - `doc/phase9_b_stage_split.plan.md`
  - `mmu_verification/Makefile`

- **产出标准**：
  - 形成一份候选池矩阵，覆盖所有参与 Phase 10 分层的 test 目录。
  - 对账以下三组数字：
    - repo 当前扫描出来的注册 test class 数 `266`
    - Phase 9 进度合同数 `262`
    - `phase8_tests` 中 `test_mmu_vseq_runner` 的单 harness 事实
  - 给每个候选条目标记：
    - `smoke_candidate`
    - `nightly_candidate`
    - `coverage_candidate`
    - `blocked`
  - 明确 `blocked` 的原因类型：`plusargs-gap` / `phase11-owned` / `known-unstable` / `utility-only`

- **退出准则**：
  - 不存在“来源不明”的测试条目。
  - 所有不进入三份 list 的候选项都有书面原因。

### Stage 3 - smoke 候选矩阵

- **任务相关文件**：
  - `mmu_verification/testbench/test/basic_tests/`
  - `mmu_verification/testbench/test/l1itlb_tests/`
  - `mmu_verification/testbench/test/l1dtlb_tests/`
  - `mmu_verification/testbench/test/tlbop_tests/`
  - `mmu_verification/testbench/test/ptw_tests/`
  - `mmu_verification/testbench/test/pmp_tests/`
  - `mmu_verification/testbench/test/sysmap_tests/`
  - `mmu_verification/testbench/test/cp0_tests/`
  - `mmu_verification/testbench/test/cross_tests/`
  - `mmu_verification/testbench/test/err_tests/`

- **产出标准**：
  - 形成 smoke 候选矩阵，目标对应 `VerificationPlan` 的：
    - P0 sanity
    - 主 directed
    - `< 30 min` 目标
    - 100% pass 预期
  - smoke 的首轮目标规模固定为 **18-22 条**；若最后低于 18 条或高于 22 条，必须给出书面原因。
  - 候选池优先覆盖以下能力面：
    - 基本翻译
    - PTW map/fault
    - invalidate / sfence
    - PMP
    - SysMap
    - CSR / privilege
    - exception / error 基线
  - `perf_tests` 默认 **不进入** smoke，除非条目已被证明是短路径 directed 而非长压测。
  - 每一项都必须给出纳入 smoke 的理由。

- **退出准则**：
  - smoke 候选矩阵中的每一项都能映射到精确 `TEST_NAME`。
  - 没有 plusargs 依赖项混进 smoke 候选。

### Stage 4 - `mmu_smoke_list` 冻结

- **任务相关文件**：
  - Stage 3 smoke 候选矩阵
  - `doc/MMU_VerificationPlan.md` §6.4 / §8
  - 目标文件：`mmu_verification/simu/mmu_smoke_list`

- **产出标准**：
  - 生成 `mmu_smoke_list` 的最终条目顺序。
  - 默认每行 `SEED_COUNT=1`；若个别条目需要更高 seed 数，必须给出理由。
  - 输出 smoke 覆盖摘要，解释每个功能面由哪些 test 兜底。
  - 保持 smoke 仅包含“应当 100% 通过”的稳态条目。

- **退出准则**：
  - `mmu_smoke_list` 不包含 blocked 项。
  - 每条记录都能追溯到 Stage 3 的纳入理由。
  - A review 时不需要再猜每条 smoke 的存在意义。

### Stage 5 - nightly 候选矩阵

- **任务相关文件**：
  - `mmu_verification/testbench/test/basic_tests/`
  - `mmu_verification/testbench/test/l1itlb_tests/`
  - `mmu_verification/testbench/test/l1dtlb_tests/`
  - `mmu_verification/testbench/test/l2tlb_tests/`
  - `mmu_verification/testbench/test/ptw_tests/`
  - `mmu_verification/testbench/test/tlbop_tests/`
  - `mmu_verification/testbench/test/pmp_tests/`
  - `mmu_verification/testbench/test/sysmap_tests/`
  - `mmu_verification/testbench/test/cp0_tests/`
  - `mmu_verification/testbench/test/flush_tests/`
  - `mmu_verification/testbench/test/cross_tests/`
  - `mmu_verification/testbench/test/perf_tests/`
  - `mmu_verification/testbench/test/err_tests/`

- **产出标准**：
  - 建立 nightly 候选矩阵，目标是覆盖 Phase 9 基线 test 的全集。
  - 默认 `SEED_COUNT=5`，与 `VerificationPlan` `nightly_full` 口径对齐。
  - nightly 主合同默认对齐 `MMU_Progress.md` 的 **259 个 wrapper + 3 个书面 baseline basic 入口 = 262**；若 repo 扫描结果多于或少于该数字，必须逐条解释。
  - 单独列出 holdback 条目，不允许“静默漏掉”任何基线 test。
  - `phase8_tests/test_mmu_vseq_runner` 默认不直接并入 nightly 主清单，除非已经有 plusargs-free 的稳定运行语义。

- **退出准则**：
  - 所有 Phase 9 基线 test 都被归类为 `included` 或 `holdback`。
  - nightly 候选矩阵中不存在重复来源不明的条目。

### Stage 6 - `mmu_nightly_list` 冻结

- **任务相关文件**：
  - Stage 5 nightly 候选矩阵
  - `doc/MMU_VerificationPlan.md` §6.4 / §8 / §9
  - 目标文件：`mmu_verification/simu/mmu_nightly_list`

- **产出标准**：
  - 生成 `mmu_nightly_list` 的最终条目。
  - 形成配套 holdback 清单，逐条写明：
    - 未纳入原因
    - owner
    - 预计回收 phase
  - 书面说明 smoke 与 nightly 的关系：
    - smoke 条目是否完整并入 nightly
    - 若未并入，原因是什么

- **退出准则**：
  - `mmu_nightly_list` 对 Phase 9 基线条目无漏项。
  - holdback 清单不是口头约定，而是可 review 的书面附录。

### Stage 7 - coverage 候选矩阵

- **任务相关文件**：
  - `doc/phase8_m8_vseq_f_mapping.md`
  - `mmu_verification/Makefile` 中 `PHASE8_VSEQS`
  - `mmu_verification/testbench/test/phase8_tests/`
  - `mmu_verification/testbench/test/l2tlb_tests/`
  - `mmu_verification/testbench/test/ptw_tests/`
  - `mmu_verification/testbench/test/tlbop_tests/`
  - `mmu_verification/testbench/test/perf_tests/`
  - `mmu_verification/testbench/test/err_tests/`
  - `doc/MMU_VerificationPlan.md` §7 / §8 / §9

- **产出标准**：
  - 建立 coverage 候选矩阵，按以下两类拆分：
    - `plusargs-free`：可直接写入 `mmu_coverage_list`
    - `requires_plusargs`：依赖 `test_mmu_vseq_runner +VSEQ_NAME=<class>`
  - coverage 的优先承载目录默认优先级为：
    - `ptw_tests`
    - `l2tlb_tests`
    - `l1dtlb_tests`
    - `perf_tests`
    - 其它仅在确有覆盖收益时补入
  - 对 `requires_plusargs` 条目，至少覆盖以下 14 个 vseq 名称：
    - `mmu_smoke_vseq`
    - `mmu_concurrent_3pipe_vseq`
    - `mmu_ptw_thrash_vseq`
    - `mmu_sfence_during_walk_vseq`
    - `mmu_asid_context_switch_vseq`
    - `mmu_huge_page_mix_vseq`
    - `mmu_rrpv_aging_vseq`
    - `mmu_l2tlb_bank_conflict_vseq`
    - `mmu_satp_hotswap_vseq`
    - `mmu_stress_all_ports_vseq`
    - `mmu_power_gating_vseq`
    - `mmu_reset_midtransaction_vseq`
    - `mmu_error_rain_vseq`
    - `mmu_perf_bench_vseq`
  - 每个 coverage 候选条目都要写明覆盖目标、特征点或 F-ID 来源。
  - `mmu_huge_page_mix_vseq` 与 `mmu_power_gating_vseq` 默认只进入 **watchlist**，不在没有稳定 wrapper 或 plusargs 入口前承诺为 Phase 10 的签核闭合项。

- **退出准则**：
  - coverage 候选矩阵中不存在“只因为随机就纳入”的无目标条目。
  - plusargs 依赖项与 plusargs-free 条目分界清楚。
  - watchlist 条目与真正 Phase 10 承诺条目分界清楚。

### Stage 8 - `mmu_coverage_list` 冻结

- **任务相关文件**：
  - Stage 7 coverage 候选矩阵
  - `mmu_verification/Makefile` 的 `run_cov` / `cov` / `merge_cov`
  - `doc/MMU_VerificationPlan.md` §7 / §8 / §9
  - 目标文件：`mmu_verification/simu/mmu_coverage_list`

- **产出标准**：
  - 生成 `mmu_coverage_list` 的最终条目与 `SEED_COUNT`。
  - 对依赖 plusargs 的 coverage 条目，形成 blocked 附录交给 A。
  - 书面指出当前覆盖率数据库命名风险：
    - `output/logs/<TEST_NAME>_cov.log`
    - `output/coverage/<TEST_NAME>.vdb`
    - 同一 `TEST_NAME` 多 seed 时存在覆盖/冲突风险
  - 书面区分：
    - B 侧“条目与种子数定义完成”
    - A 侧“日志/vdb 命名与 merge 机制待接通”

- **退出准则**：
  - `mmu_coverage_list` 中每条记录都有目标覆盖价值。
  - 多 seed / plusargs 造成的执行级风险被显式移交给 A，而不是隐藏在 list 中。

### Stage 9 - waiver 候选矩阵

- **任务相关文件**：
  - `doc/MMU_VerificationPlan.md` §7 / §9
  - `doc/MMU_Progress.md`
  - `mmu_verification/scripts/cov_hier.cfg`
  - `hpdcache_verification/testbench/simu/exclude.do`

- **产出标准**：
  - 形成 waiver 候选矩阵，至少包含：
    - `scope`
    - `object_type`
    - `reason_class`
    - `reason_detail`
    - `source_doc_or_bug`
    - `owner`
    - `close_condition`
  - `reason_class` 至少分为：
    - `reserved`
    - `unreachable-by-architecture`
    - `known-rtl-gap`
    - `tool-limitation`
    - `integration-not-ready`
  - 不允许因为“目前没打到”就直接升为 waiver。

- **退出准则**：
  - 每个拟豁免项都能回答“为什么不可达 / 为什么暂时接受 / 什么时候关闭”。
  - waiver 候选矩阵与三份 list 分离维护，不混写。

### Stage 10 - `exclude.do` 冻结

- **任务相关文件**：
  - Stage 9 waiver 候选矩阵
  - `hpdcache_verification/testbench/simu/exclude.do`
  - 目标文件：`mmu_verification/simu/exclude.do`

- **产出标准**：
  - 生成 `exclude.do` 的条目模板与分节结构。
  - 每条工具命令必须带 `-comment`。
  - comment 必须写清：
    - 豁免理由
    - 依据文档 / bug / 设计约束
    - 关闭条件
  - 明确“允许复用 hpdcache 语法风格，不允许照搬 hpdcache 的 scope/path”。

- **退出准则**：
  - `exclude.do` 不存在无注释条目。
  - 所有条目都能回指 Stage 9 的 waiver 候选矩阵。

### Stage 11 - A handoff 与 Phase 10 B 退出门禁

- **任务相关文件**：
  - `mmu_verification/simu/mmu_smoke_list`
  - `mmu_verification/simu/mmu_nightly_list`
  - `mmu_verification/simu/mmu_coverage_list`
  - `mmu_verification/simu/exclude.do`
  - `doc/MMU_Progress.md`
  - `doc/MMU_UVM_TaskDivision.md`

- **产出标准**：
  - 形成给 A 的 handoff 包，至少包含：
    - 三份公开 list
    - `exclude.do`
    - sidecar manifest
    - holdback 清单
    - blocked plusargs coverage 附录
    - 执行级未决依赖（parser、命名冲突、merge 机制）
  - 形成 Phase 10 B 退出检查表，对齐 `TaskDivision`：
    - 三份 list 已提交
    - `exclude.do` 全部条目有注释
    - A review 点明确
  - 形成 Phase 11 接口摘要，至少说明：
    - 哪些 nightly / coverage 主干条目要作为 `mmu_v3_regression_list` 的正向保护集
    - 哪些 blocked 项会影响 Phase 11 的 gap 回归扩展

- **退出准则**：
  - B 侧交付物可以直接交给 A 消费，不需要 A 先猜格式。
  - Phase 11 的 list 扩展不需要回头再重新定义 smoke/nightly/coverage 主干。

## 阶段间门禁与阻断策略

- **Gate A（Stage0→1）**：
  - `simu/` 目标目录与 `testbench/simu/` stale 口径已区分清楚。
  - Phase 10 B-only 边界写入文档。

- **Gate B（Stage1→2）**：
  - `TEST_NAME SEED_COUNT` 语法冻结。
  - `TEST_NAME` = 精确 UVM test class 名规则冻结。

- **Gate C（Stage2→4）**：
  - smoke 候选池中不再含 blocked / plusargs 依赖项。
  - `mmu_smoke_list` 每条都可追溯到明确功能面。

- **Gate D（Stage2→6）**：
  - nightly 基线全集已完成 included / holdback 对账。
  - Phase 9 基线条目无静默漏项。

- **Gate E（Stage7→10）**：
  - coverage 候选矩阵与 waiver 候选矩阵都已闭环。
  - plusargs 与 coverage DB 命名冲突已单独成文，不埋在备注里。

- **最终 Gate F（Phase10-B Exit）**：
  - 三份公开 list + `exclude.do` 已形成可交付文件。
  - A review 需要的信息完整。
  - Phase 11 可直接基于本阶段主干扩展，而不需要返工 list 基线。

## 风险与缓解

- **目录口径冲突**：
  - 风险：文档写 `simu/`，legacy 脚本写 `testbench/simu/`，仓库现实两个都不存在。
  - 缓解：Stage 0 明确冻结 `mmu_verification/simu/` 为唯一公开路径。

- **公开 list 语法过早绑定到脚本实现**：
  - 风险：A 还没完成 `regress` 入口，B 如果直接设计复杂多列表头格式，后续容易返工。
  - 缓解：Stage 1 固定最小公约数 `TEST_NAME SEED_COUNT`，高级字段放 sidecar manifest。

- **目录 alias 与精确 test 名混用**：
  - 风险：Makefile 能跑，legacy Python 跑不了，最终 list 失去通用性。
  - 缓解：三份公开 list 全部禁用 alias。

- **Phase 8 vseq 覆盖条目依赖 `+VSEQ_NAME`**：
  - 风险：当前 B 的公开 list contract 无法表达 plusargs。
  - 缓解：Stage 7/8 分离 `requires_plusargs` 条目，blocked 附录单独交给 A。

- **coverage 多 seed 的日志 / vdb 冲突**：
  - 风险：当前 `run_cov` 命名按 `TEST_NAME` 收敛，重复 seed 可能互相覆盖。
  - 缓解：Stage 8 把该风险单列为 A-side execution dependency。

- **`huge_page_mix` / `power_gating` 过早承诺闭合**：
  - 风险：这些条目当前更接近 Phase 8 vseq 主题，而不是 B 在 Phase 10 已经拥有稳定 wrapper 的常规回归资产。
  - 缓解：Stage 7 明确将其放入 watchlist；只有 A 的 plusargs/regress 接口 ready 后才允许升级为正式 coverage 承诺。

- **repo 当前 test 数与 Progress 合同数不一致**：
  - 风险：nightly 清单漏项或误纳入 utility class。
  - 缓解：Stage 2 做 `266 vs 262` 的硬对账。

- **waiver 失控**：
  - 风险：为追 coverage 数字，把暂时没打到的点都写进 `exclude.do`。
  - 缓解：Stage 9 要求每个 waiver 都写 owner 与 close condition。

## Skill 使用判断

- 本任务本质是 **验证计划拆分 + 回归资产编排**，主要依赖本地文档、脚本与目录审计，不依赖额外 skill。
- 若后续要把 sidecar manifest 维护成结构化表格，可选用 spreadsheet 类能力；本临时计划本身不要求。

## 与前序计划体例的对照

| 体例项 | `phase7_b_stage_split.plan.md` | `phase9_b_stage_split.plan.md` | 本 Phase10 文档 |
| --- | --- | --- | --- |
| frontmatter + todos | 有 | 有 | 有 |
| 目标与边界 | covergroup / SVA | test stage catalog | regression list / waiver |
| 多代理架构 | 较轻 | 明确 supervisor + 子代理 | 明确 supervisor + 子代理 |
| 阶段粒度 | Stage0-8 | Stage0-15 | Stage0-11 |
| 每阶段文件/产出/退出 | 有 | 有 | 有 |
| 门禁 / 风险 / skill | 有 | 有 | 有 |

**说明**：本文件是 B 在 Phase 10 的临时执行级拆分计划；项目内权威副本路径固定为 `doc/phase10_b_stage_split.plan.md`。
