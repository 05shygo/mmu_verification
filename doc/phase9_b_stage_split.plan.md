---
name: phase9_b_stage_split
overview: 将 Phase 9（B 主责测试用例填充，A 对 PTW/PMP/SysMap 精度类用例做 review）拆成可独立启动的多阶段任务；采用 supervisor + subagents 架构，主文档只定义公共模板、门禁、目录级阶段与 stage catalog 的解释规则，每一行 catalog 记录都视为 1 个独立 test-stage。
todos:
  - id: stage0-preflight
    content: Stage0 冻结 Phase 9 基线范围、Phase 8 依赖与排除项
    status: pending
  - id: stage1-catalog-freeze
    content: Stage1 冻结 3 份 stage catalog、命名规则与 test_pkg 接入策略
    status: pending
  - id: stage2-basic
    content: Stage2 纳管 basic_tests 现有 3 个 smoke/sanity 用例
    status: pending
  - id: stage3-l1itlb
    content: Stage3 完成 l1itlb_tests 全量 stage catalog 对位
    status: pending
  - id: stage4-l1dtlb
    content: Stage4 完成 l1dtlb_tests 全量 stage catalog 对位
    status: pending
  - id: stage5-l2tlb
    content: Stage5 完成 l2tlb_tests 全量 stage catalog 对位
    status: pending
  - id: stage6-ptw
    content: Stage6 完成 ptw_tests 全量 stage catalog 对位
    status: pending
  - id: stage7-tlbop
    content: Stage7 完成 tlbop_tests 全量 stage catalog 对位
    status: pending
  - id: stage8-pmp
    content: Stage8 完成 pmp_tests 全量 stage catalog 对位并触发 A review
    status: pending
  - id: stage9-sysmap
    content: Stage9 完成 sysmap_tests 全量 stage catalog 对位并触发 A review
    status: pending
  - id: stage10-cp0
    content: Stage10 完成 cp0_tests 全量 stage catalog 对位
    status: pending
  - id: stage11-flush
    content: Stage11 完成 flush_tests 全量 stage catalog 对位
    status: pending
  - id: stage12-cross
    content: Stage12 完成 cross_tests 全量 stage catalog 对位
    status: pending
  - id: stage13-perf
    content: Stage13 完成 perf_tests 全量 stage catalog 对位
    status: pending
  - id: stage14-err
    content: Stage14 完成 err_tests 全量 stage catalog 对位
    status: pending
  - id: stage15-gate
    content: Stage15 统一 compile、seed=1 单跑、smoke 3 seed、scan_logs 与 A review 收口
    status: pending
isProject: false
---

# Phase 9（B）临时任务拆分执行方案

## 目标与边界

- **总目标**：
  - 以 `doc/MMU_VerificationPlan.md` §6.3 为主索引，给 Phase 9 基线 test class 建立可执行的临时拆分计划。
  - 每一个 test case 至少对应一个独立 `stage`；主文档不再用“每个 stage 一长段”的写法，而是改成“每一行 stage catalog = 1 个独立 stage”。
  - 保持与 `doc/phase7_b_stage_split.plan.md` 同体例：有边界、输入依据、阶段门禁、公共模板、退出准则。

- **B 主责**：
  - `testbench/test/` 下 13 个基线目录的 test class 落盘规划、命名规则、`test_pkg.sv` 接入、单测与 smoke 收口。
  - 本文档中所有 stage catalog 的主维护与执行排序。

- **A 主责**：
  - 对 `ptw_tests` / `pmp_tests` / `sysmap_tests` 以及任何明确标记 `reviewer=A+B` 的 stage 做 review。
  - Phase 9 结束门禁中保留 `TaskDivision` 要求的 review 记录。

- **本计划不纳入**：
  - `bug_hunt_tests/`
  - `ptw_lsu_protocol_tests/`
  - `ifu_hold_tests/`
  - `lsu_expt_lifecycle_tests/`
  - `maee_twu_tests/`
  - `pmp_twu_tests_v6/`
  - 其它明确属于 Phase 11+ 的扩展目录

- **当前阻断**：
  - `doc/MMU_Progress.md` 显示 `Phase 8` 仍为“代码已合入，待 VCS 跑 make phase8 与 A 签 Review”。
  - 因此本文件先完成 **执行级拆分**；真正关闭 Phase 9 前，必须先清掉 Phase 8 阻断。

## 多代理执行架构

- **Supervisor**：`B-Phase9-Orchestrator`
  - 负责范围冻结、目录映射、catalog 合并、阶段门禁和最终验收口径。

- **Catalog 子代理**：
  - `Catalog-IFU`：抽取 `l1itlb_tests`。
  - `Catalog-LSU-L2-TLBOP`：抽取 `l1dtlb_tests` / `l2tlb_tests` / `tlbop_tests` 的基线候选。
  - `Catalog-System`：抽取 `ptw/pmp/sysmap/cp0/flush/cross/perf/err`。

- **执行子代理**：
  - `Worker-Basic`
  - `Worker-L1`
  - `Worker-L2`
  - `Worker-PTW`
  - `Worker-TLBOP`
  - `Worker-PMP-SYSMAP`
  - `Worker-CP0`
  - `Worker-Top`

- **联调子代理**：
  - `Gatekeeper-Compile`
  - `Gatekeeper-Smoke`
  - `Gatekeeper-Review`

| 角色 | 主责 stage | 覆盖目录 / catalog | 主要输出 | 进入下一阶段的 gate |
| --- | --- | --- | --- | --- |
| `B-Phase9-Orchestrator` | Stage 0 / 1 / 15 | 全部目录、全部 catalog | 范围冻结、行级 contract、收口清单 | Gate A / B / E |
| `Catalog-IFU` | Stage 1 / 3 | `phase9_b_stage_catalog_l1itlb.csv` | IFU catalog schema 冻结、命名冻结 | Gate B |
| `Catalog-LSU-L2-TLBOP` | Stage 1 / 4 / 5 / 7 | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | `l1dtlb/l2tlb/tlbop` 的 stage_id / target_file / checker 补齐规则 | Gate B |
| `Catalog-System` | Stage 1 / 6 / 8 / 9 / 10 / 11 / 12 / 13 / 14 | `phase9_b_stage_catalog_system.csv` | system 目录 catalog 对账、缺口清零 | Gate B |
| `Worker-Basic` | Stage 2 | `basic_tests` | 3 个既有 smoke test 纳管 | Gate C |
| `Worker-L1` | Stage 3 / 4 | `l1itlb_tests` / `l1dtlb_tests` | L1 IFU/LSU test files + `test_pkg.sv` include | Gate C |
| `Worker-L2` | Stage 5 | `l2tlb_tests` | L2TLB / RRPV / MB / BANK test files | Gate C |
| `Worker-PTW` | Stage 6 | `ptw_tests` | PTW / TWU / ARB / XBAR / PDE test files | Gate D |
| `Worker-TLBOP` | Stage 7 | `tlbop_tests` | `SFENCE/TLBP/TLBR/TLBWI/TLBWR` test files | Gate C |
| `Worker-PMP-SYSMAP` | Stage 8 / 9 | `pmp_tests` / `sysmap_tests` | 参考模型精确比对类 test files | Gate D |
| `Worker-CP0` | Stage 10 / 11 / 12 | `cp0_tests` / `flush_tests` / `cross_tests` | CSR / reset-flush / privilege-cross test files | Gate C |
| `Worker-Top` | Stage 13 / 14 | `perf_tests` / `err_tests` | perf / exception / power test files | Gate C |
| `Gatekeeper-Compile` | Stage 15 | `Makefile` / `test_pkg.sv` / 全部 test files | compile 清单、undefined class 清零 | Gate E |
| `Gatekeeper-Smoke` | Stage 15 | `simu/mmu_phase9_smoke_list` | seed=1 单跑 + 3-seed smoke 收口 | Gate E |
| `Gatekeeper-Review` | Stage 15 | `ptw/pmp/sysmap` review record | A review 留痕、scan_logs 摘要 | Gate E |

## 输入依据文件

- 当前进度：
  - `doc/MMU_Progress.md`
- 任务分工与 Phase 9 退出准则：
  - `doc/MMU_UVM_TaskDivision.md`
- 搭建计划与目录口径：
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
- baseline TC 主索引：
  - `doc/MMU_VerificationPlan.md` §6.3
- 已抽出的阶段清单：
  - `doc/phase9_b_stage_catalog_l1itlb.csv`
  - `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md`（source catalog，Stage 1 冻结后补齐行级派生字段）
  - `doc/phase9_b_stage_catalog_system.csv`

**路径约定**：

- 工程根：`D:/mmu_uvm`
- 编译与仿真目录：`D:/mmu_uvm/mmu_verification`
- 目标测试目录：`D:/mmu_uvm/mmu_verification/testbench/test/<target_dir>/`

## 阶段规模快照

| stage | target_dir | source catalog | 独立 test-stage 数 |
| --- | --- | --- | --- |
| Stage 2 | `basic_tests` | 主文档内置 3 行 | 3 |
| Stage 3 | `l1itlb_tests` | `phase9_b_stage_catalog_l1itlb.csv` | 20 |
| Stage 4 | `l1dtlb_tests` | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | 23 |
| Stage 5 | `l2tlb_tests` | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | 42 |
| Stage 6 | `ptw_tests` | `phase9_b_stage_catalog_system.csv` | 44 |
| Stage 7 | `tlbop_tests` | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | 25 |
| Stage 8 | `pmp_tests` | `phase9_b_stage_catalog_system.csv` | 15 |
| Stage 9 | `sysmap_tests` | `phase9_b_stage_catalog_system.csv` | 17 |
| Stage 10 | `cp0_tests` | `phase9_b_stage_catalog_system.csv` | 16 |
| Stage 11 | `flush_tests` | `phase9_b_stage_catalog_system.csv` | 9 |
| Stage 12 | `cross_tests` | `phase9_b_stage_catalog_system.csv` | 8 |
| Stage 13 | `perf_tests` | `phase9_b_stage_catalog_system.csv` | 22 |
| Stage 14 | `err_tests` | `phase9_b_stage_catalog_system.csv` | 18 |
| 合计 | 13 个目录 | 3 份临时 catalog | 262 |

## 命名与模板

### 1. stage catalog 解释规则

- 每一行 catalog 记录都视为 **一个独立 stage**。
- 对于 CSV catalog：
  - `stage_id`：唯一 stage 标识。
  - `target_dir`：目标测试子目录。
  - `tc_id`：对应的 Test Case ID。
  - `test_name`：建议的 test class / file basename。
  - `tc_name`：若某份临时 catalog 仍保留该列，则它只作为 display name；真正可运行的 `TEST_NAME` 以 `target_file` basename 为准。
  - `target_file`：目标 test 文件路径。
  - `seq`：该 stage 的主序列输入。
  - `checker`：该 stage 的主要 SB / checker / SVA 落点。
  - `reviewer`：该 stage 的默认评审责任人。
- 对于 `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md`：
  - 每一行表格记录同样视为一个独立 stage。
  - `stage_id` 按 `p9-<target_dir简写>-<tc_id小写归一化>` 派生。
  - 若该表未显式给出 `target_file`，按下列规则派生：
    - 若 `tc_name` 已是 `test_...`，目标文件为 `mmu_verification/testbench/test/<target_dir>/<tc_name>.svh`
    - 否则目标文件为 `mmu_verification/testbench/test/<target_dir>/test_mmu_<target_dir去掉_tests后缀>_<tc_id小写归一化>.svh`
  - `checker` 不是原表固有列；Stage 1 必须为 `l1dtlb/l2tlb/tlbop` 补一版行级 checker 映射附录，然后 Stage 4/5/7 才能启动。

### 2. 行级 contract 选择规则

- 每个 test-stage 都必须拥有：
  - 1 个 `target_file`
  - 1 组目录级任务相关文件
  - 1 份产出模板
  - 1 份退出模板
- 行级模板选择规则：
  - `reviewer=B`：默认走 `O-Basic + E-Basic`
  - `reviewer=A+B`：默认走 `O-Ref + E-Ref`
- 目录路由冻结规则：
  - `tlbop_tests`：只承接 `SFENCE/TLBP/TLBR/TLBWI/TLBWR` 语义与无效化精度。
  - `cp0_tests`：只承接 CSR/寄存器类控制（`SATP/no_op/ptw_disable/maee/cskyee/icg/cmplt`）。
  - `flush_tests`：只承接 reset / RTU flush / pending clear / output no-X；不重复承接 `TC-SFENCE-*`。
  - `cross_tests`：只承接 `TC-PRIV-*` 等 privilege-cross 条目；当前唯一 source 为 `phase9_b_stage_catalog_system.csv`。
  - `PTW-030` 在 `MMU_VerificationPlan.md` 中已明确迁并入 DTLB wakeup 广播条目，不再单独在 `ptw_tests` 建 stage。

### 3. 所有 test-stage 的公共文件

- `mmu_verification/testbench/test/test_pkg.sv`
- `mmu_verification/testbench/test/test_base.svh`
- `mmu_verification/testbench/env/mmu_env.svh`
- `mmu_verification/testbench/env/mmu_top_cfg.svh`
- 对应 agent / vseq / responder 的 sequence 文件

### 4. 产出模板

- **O-Basic**：
  - 新建或补齐单个 test file。
  - test class 继承 `test_base`，重写 `run_test_body()`。
  - 文件头声明 `TC-ID / F-ID / Sequence / Checker / Reviewer`。
  - 单 test 只承载 1 个主 TC 意图；允许 1-N 个 helper sequence，但不允许混入其它 TC 退出语义。
  - test 体量目标 `< 50` 行；统一使用 `num_txn` / `+NB_TXNS` / `+TIMEOUT`，禁止硬编码 `#XXXXXX` 超时。

- **O-Ref**：
  - 在 `O-Basic` 基础上，必须写明与 `translation_sb` / `invalidation_sb` / `pmp` / `sysmap` / `ptw_walk_cg` 的对位关系。
  - 若 `reviewer=A+B`，头注释里增加 `A_REVIEW_REQUIRED=1`。

### 5. 退出模板

- **E-Basic**：
  - `make compile` 通过；新增 test 无 `undefined class/include`。
  - `make run TEST_NAME=<test_name> SEED=1`：`UVM_ERROR=0`，`UVM_FATAL=0`，`SVA fail=0`。
  - 该行 `checker` 对应的 SB / checker / coverage 摘要无阻断错误。

- **E-Ref**：
  - 在 `E-Basic` 基础上，保留 A review 记录。
  - 对精确比对类 test，`translation_sb / invalidation_sb / pmp / sysmap / ptw_walk_cg` 必须给出可复查摘要。

## 分阶段执行

### Stage 0 - 基线冻结与阻断登记

- **任务相关文件**：
  - `doc/MMU_Progress.md`
  - `doc/MMU_UVM_TaskDivision.md`
  - `doc/MMU_UVM_BuildPlan_v3_final.md`
  - 本文档

- **产出标准**：
  - 书面冻结 Phase 9 只覆盖 13 个基线目录。
  - 书面登记 Phase 8 未关闭这一前置阻断。
  - 书面登记后移项（bug_hunt / ptw_lsu_protocol / ifu_hold / lsu_expt_lifecycle / maee / pmp_twu_v6）。

- **退出准则**：
  - 上述冻结点写入本文档，不留口头约定。

### Stage 1 - catalog 冻结与命名规则冻结

- **任务相关文件**：
  - `doc/phase9_b_stage_catalog_l1itlb.csv`
  - `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md`
  - `doc/phase9_b_stage_catalog_system.csv`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/test/test_base.svh`

- **产出标准**：
  - 冻结 3 份 stage catalog。
  - 将 `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` 补成可执行的行级派生视图：至少补齐 `stage_id / target_file / checker`。
  - 统一 `test_name` 与 `tc_name` 兼容规则；`target_file` basename 成为唯一运行名。
  - 冻结“每行 catalog = 一个独立 stage”的解释规则。
  - 冻结 `tlbop/cp0/flush/cross` 的目录路由边界。
  - 冻结目标文件命名规则与 `test_pkg.sv` 接入方式。
  - 对账 `VerificationPlan §6.3` 中的缺口项；当前必须显式清零 `TC-CSR-012`，并显式记录 `PTW-030` 为“已迁并入 DTLB、非缺项”。

- **退出准则**：
  - 执行者不需要再为“某个 TC 放哪个目录、叫什么文件、找谁 review”做二次决策。

### Stage 2 - basic_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/basic_tests/test_mmu_translation_sanity.svh`
  - `mmu_verification/testbench/test/basic_tests/test_mmu_invalidate_sfence_matrix.svh`
  - `mmu_verification/testbench/test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`

- **产出标准**：
  - 复用现有 3 个 basic/smoke test 作为 Phase 9 基线入口。
  - 若与新的 TC 拆分重叠，仅做“纳管/重命名/头注释补全”，不重写行为语义。

- **退出准则**：
  - 3 个 basic test 均完成 Phase 9 头注释纳管。
  - 3 个 basic test 均保持单跑可用。
  - `p9-basic-003` 因 `reviewer=A+B`，额外保留 A review 记录。

| stage_id | target_file | 主 sequence / checker | reviewer |
| --- | --- | --- | --- |
| p9-basic-001 | `mmu_verification/testbench/test/basic_tests/test_mmu_translation_sanity.svh` | existing sanity wrapper / `translation_sb` | B |
| p9-basic-002 | `mmu_verification/testbench/test/basic_tests/test_mmu_invalidate_sfence_matrix.svh` | existing invalidate matrix wrapper / `invalidation_sb` | B |
| p9-basic-003 | `mmu_verification/testbench/test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh` | existing csr/pmp/sysmap smoke / `translation_sb + csr/pmp/sysmap smoke` | A+B |

### Stage 3 - l1itlb_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/l1itlb_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/ifu_agent/*sequences*.svh`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_l1itlb.csv` 每一行各自产出 1 个 test-stage。
  - 每个 stage 继承 `O-Basic`；`ITLB_*` 的文件名和 reviewer 以 CSV 为准。

- **退出准则**：
  - CSV 中全部 `l1itlb_tests` 行满足 `E-Basic`。

- **stage catalog**：
  - `doc/phase9_b_stage_catalog_l1itlb.csv`

### Stage 4 - l1dtlb_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/l1dtlb_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/lsu_agent/*sequences*.svh`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` 中 `target_dir=l1dtlb_tests` 的每一行各自产出 1 个 test-stage。
  - `reviewer=B` 的行继承 `O-Basic`；`reviewer=A+B` 的行继承 `O-Ref`。

- **退出准则**：
  - 该 markdown 表中所有 `l1dtlb_tests` 行满足各自行级 exit contract。

### Stage 5 - l2tlb_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/l2tlb_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`
  - `mmu_verification/testbench/top/mmu_arb_sva.sv`

- **产出标准**：
  - `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` 中 `target_dir=l2tlb_tests` 的每一行各自产出 1 个 test-stage。
  - `TC-L2TLB-* / TC-RRPV-* / TC-BANK-* / TC-MB-*` 不混写。

- **退出准则**：
  - 该 markdown 表中所有 `l2tlb_tests` 行满足各自行级 exit contract。

### Stage 6 - ptw_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/ptw_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/ptw_mem_agent/*sequences*.svh`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=ptw_tests` 的每一行各自产出 1 个 test-stage。
  - 所有 `ptw_tests` 行继承 `O-Ref`。

- **退出准则**：
  - 所有 `ptw_tests` 行满足 `E-Ref`。
  - A review 记录齐全。

### Stage 7 - tlbop_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/tlbop_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/lsu_agent/*sequences*.svh`
  - `mmu_verification/testbench/cp0_agent/*sequences*.svh`

- **产出标准**：
  - `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` 中 `target_dir=tlbop_tests` 的每一行各自产出 1 个 test-stage。
  - 所有 stage 必须明确 `SFENCE/TLBP/TLBR/TLBWI/TLBWR` 的 checker 对位。

- **退出准则**：
  - 所有 `tlbop_tests` 行满足各自行级 exit contract。

### Stage 8 - pmp_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/pmp_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/pmp_agent/*sequences*.svh`
  - `mmu_verification/testbench/ptw_mem_agent/*sequences*.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=pmp_tests` 的每一行各自产出 1 个 test-stage。
  - 所有 `pmp_tests` 行继承 `O-Ref`。

- **退出准则**：
  - 所有 `pmp_tests` 行满足 `E-Ref`。
  - A review 必须完成。

### Stage 9 - sysmap_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/sysmap_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/sysmap_cfg_agent/*sequences*.svh`
  - `mmu_verification/testbench/ptw_mem_agent/*sequences*.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=sysmap_tests` 的每一行各自产出 1 个 test-stage。
  - 所有 `sysmap_tests` 行继承 `O-Ref`。

- **退出准则**：
  - 所有 `sysmap_tests` 行满足 `E-Ref`。
  - A review 必须完成。

### Stage 10 - cp0_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/cp0_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/cp0_agent/*sequences*.svh`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=cp0_tests` 的每一行各自产出 1 个 test-stage。
  - `SATP/CSR` 与 `no_op/ptw_disable/maee/cskyee/icg/cmplt` 控制类条目在同目录内分文件实现，不把多个 TC 合并进一个 test。

- **退出准则**：
  - 所有 `cp0_tests` 行满足 `E-Basic`。

### Stage 11 - flush_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/flush_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/misc_agent/*sequences*.svh`
  - `mmu_verification/testbench/lsu_agent/*sequences*.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=flush_tests` 的每一行各自产出 1 个 test-stage。
  - `ITLB_FLUSH_001` 作为 `l1itlb` catalog 内的配套 flush 场景一并纳管。

- **退出准则**：
  - 所有 `flush_tests` 行满足 `E-Basic`。

### Stage 12 - cross_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/cross_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=cross_tests` 的每一行各自产出 1 个 test-stage。
  - 跨目录用例必须在头注释中写清“涉及 agent / scoreboard”。

- **退出准则**：
  - 所有 `cross_tests` 行满足 `E-Basic`。

### Stage 13 - perf_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/perf_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/env/mmu_perf_mon.svh`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=perf_tests` 的每一行各自产出 1 个 test-stage。
  - 所有性能类 stage 都要保留 `NB_TXNS` / seed / 统计窗口参数。

- **退出准则**：
  - 所有 `perf_tests` 行满足 `E-Basic`。

### Stage 14 - err_tests

- **任务相关文件**：
  - `mmu_verification/testbench/test/err_tests/*.svh`
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/testbench/env/*fault*sb*`
  - `mmu_verification/testbench/env/mmu_vseq_lib.svh`

- **产出标准**：
  - `doc/phase9_b_stage_catalog_system.csv` 中 `target_dir=err_tests` 的每一行各自产出 1 个 test-stage。
  - 错误注入类 test 必须在头注释中写清 fault 源、期望信号和禁止误报路径。

- **退出准则**：
  - 所有 `err_tests` 行满足 `E-Basic`。

### Stage 15 - 统一门禁与收口

- **任务相关文件**：
  - `mmu_verification/testbench/test/test_pkg.sv`
  - `mmu_verification/Makefile`
  - `simu/mmu_phase9_smoke_list`
  - `scripts/scan_logs.pl`
  - 全部 stage catalog
  - `doc/MMU_Progress.md`

- **产出标准**：
  - 对齐 `TaskDivision Phase 9` 的 6 条退出准则。
  - 给 smoke / compile / scan_logs / A review 建立统一收口清单。
  - 产出临时 `simu/mmu_phase9_smoke_list`；Phase 10 再合并进正式 smoke/nightly/coverage 列表。

- **退出准则**：
  1. `make compile` 0 errors，所有 test class 编译通过。
  2. 所有 stage catalog 对应 test 至少完成 `seed=1` 单跑。
  3. smoke 列表 3 个 seed 100% 通过。
  4. 不存在硬编码 `#XXXXXX` 超时。
  5. `scan_logs.pl` 无 unknown error pattern。
  6. `ptw_tests` / `pmp_tests` / `sysmap_tests` 的 A review 注释留存。

## 阶段间门禁与阻断策略

- **Gate A（Stage0->1）**：13 个目录边界、Phase 8 阻断、后移目录清单、262 行 stage 总量全部书面冻结。
- **Gate B（Stage1->2/3/4/5/6/7/8/9/10/11/12/13/14）**：3 份临时 catalog 的行级 contract 冻结；`TC-CSR-012` 缺口清零；`PTW-030` 非缺项说明留档；`tlbop/cp0/flush/cross` 路由边界不再漂移。
- **Gate C（Stage2/3/4/5/7/10/11/12/13/14->后续目录 stage）**：B-only 目录完成 compile + seed=1 单跑后才能进入下一批目录，避免 `test_pkg.sv` include 链持续漂移。
- **Gate D（Stage6/8/9->15）**：`ptw/pmp/sysmap` 的 `reviewer=A+B` 行全部拿到 A review 记录后，才允许进入最终收口。
- **Gate E（Stage15 Exit）**：Phase 8 先关闭；随后 compile / seed=1 / 3-seed smoke / `scan_logs.pl` / A review 五项同时满足，才允许更新 `MMU_Progress.md` 的 Phase 9 状态。

## 风险与缓解

- **风险 1**：当前 `§6.3` 的基线粒度已经大于 BuildPlan 早期“≈120”粗估。
  - **缓解**：本计划以“每行 catalog = 一个 stage”为准，不再强行回退到历史 rough count。

- **风险 2**：`Phase 8` 未正式关闭，Phase 9 只能先做计划与文件级拆分，不能宣称执行收口。
  - **缓解**：Stage 0 明确阻断，Stage 15 之前不得关闭 Phase 9。

- **风险 3**：`ptw/pmp/sysmap` 目录评审负担高。
  - **缓解**：所有相关行统一标 `reviewer=A+B`，并在 `O-Ref / E-Ref` 中强制加 review 记录。

- **风险 4**：已有 `basic_tests` 可能与新建 test 命名或语义重叠。
  - **缓解**：Stage 2 先做纳管，不先做重写；若功能重复，优先复用现有文件并补注释。

- **风险 5**：`l1dtlb/l2tlb/tlbop` 当前只有 source markdown，不是最终执行 CSV。
  - **缓解**：Stage 1 把它冻结为行级派生视图；Gate B 前不允许 Stage 4/5/7 开工。

## 假设

- 主索引使用 `doc/MMU_VerificationPlan.md`，不是 `final` 版的后续扩展全集。
- `doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` 虽由 `final` 版提取，但已经按 baseline 口径裁剪，可直接作为 Phase 9 临时 stage catalog 使用。
- 目录中尚不存在的大部分 `*.svh` 文件由 Phase 9 新增。
- `test_base.svh` 的当前执行钩子为 `run_test_body()`，因此本计划所有 test class 统一按这个钩子落地，不再回退到旧文档的 `main_phase()` 口径。
