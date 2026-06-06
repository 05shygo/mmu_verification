# PTW Code Coverage Staged Task Plan

## 1. 目标和范围

本文档把 `ptw_code_coverage_detection_plan.md` 中的 PTW 代码覆盖率检测计划拆分为可执行的阶段任务。每个阶段都包含：

- 任务内容；
- 任务产出内容；
- 相关文件说明；
- 退出标准检查。

本阶段计划的最终目标是建立一个可复现的一键入口，运行后输出真实 PTW-only 代码覆盖率数值：

```text
PTW_CODE_COVERAGE_RESULT status=<PASS|FAIL|CONDITIONAL_PASS> scope=ptw_core profile=<profile> functional_gate=<PASS|REUSED|SKIPPED|FAIL> confidence=<high|medium|low> headline=<actual> line=<actual> condition=<actual> branch=<actual> fsm=<actual|N/A> toggle=<actual> assertion=<actual|N/A> reason=<reason> report=<path> cov_db=<path>
```

本计划只覆盖 PTW RTL code coverage flow 的建立、执行、解析和签核，不改变 PTW 功能闭合口径。PTW source-side 功能 signoff gate 必须作为 code coverage 解释前置条件。

## 2. 全局执行原则

所有阶段必须遵守以下原则：

1. 覆盖率 headline 只能来自 PTW-only URG report，不能使用全 MMU coverage、testbench coverage 或 SVA coverage 替代。
2. `run_cov` 写同一个 aggregate VDB，必须串行执行，`REGRESS_JOBS=1`。
3. functional gate 使用 `REGRESS_MODE=run_check` 日志，不能使用 `_cov.log` 作为功能闭合证据。
4. `quick/default/full` 是中间 profile；最终 `PASS` 只允许来自 `signoff` 或 owner 批准的 signoff 等价 profile。
5. runner 必须按 `(test_name, seed)` 检查重复 coverage run，除非已经实现唯一 `COV_TAG` 传递。
6. 所有失败都必须保留 log、VDB、URG report、manifest 等证据，不允许失败后自动清理证据。
7. 每个阶段退出前必须完成本阶段退出标准检查；未通过时不得进入依赖该阶段结果的后续阶段。

## 3. 阶段总览

| 阶段 | 名称 | 关键任务产出 | 是否运行仿真 | 是否产出覆盖率数值 |
| --- | --- | --- | --- | --- |
| Stage 0 | 基线确认和计划冻结 | 阶段计划、路径约定、基线能力确认记录 | 否 | 否 |
| Stage 1 | PTW-only coverage scope 建立 | PTW hierarchy cfg、compile scope 验证记录、scope fallback 记录 | 需要 coverage compile 验证 | 否 |
| Stage 2 | 覆盖率测试集和 profile 建立 | coverage list、profile JSON、test registry/duplicate 检查记录 | 否，最多 dry-run/list check | 否 |
| Stage 3 | functional gate 集成规则建立 | gate mode 规则、gate evidence schema、run_check/reuse 证据记录 | 可选 run_check | 否 |
| Stage 4 | URG parser 和 summary 生成脚本 | parser、parser unit tests、schema/sample summary、scope check 测试记录 | 否 | 样例数值，不是实际 DUT 数值 |
| Stage 5 | 一键 runner 实现 | runner、dry-run manifest、状态机 log、命令展开记录 | dry-run 不运行，真实模式会运行 | 否 |
| Stage 6 | Makefile/CI/文档入口集成 | `ptw_code_cov` target、CI 判定规则、文档链接和入口说明 | 可选 quick | 否 |
| Stage 7 | quick profile flow smoke | quick VDB、URG、summary、flow sanity result line | 是 | 只作为 flow sanity 数值 |
| Stage 8 | default profile 覆盖率测量 | default 覆盖率 summary、holes_top20、hole action list | 是 | 是，中间 coverage 数值 |
| Stage 9 | signoff/full 覆盖率闭合 | signoff summary、final result、waiver/归档证据 | 是 | 是，最终签核数值 |

## 4. Stage 0：基线确认和计划冻结

### 4.1 任务内容

- 确认仓库根目录和仿真执行目录：
  - 仓库根目录：`/x2025/GPrj1/IC2/mmu_verification`
  - 仿真目录：`/x2025/GPrj1/IC2/mmu_verification/mmu_verification`
- 复核 `ptw_code_coverage_detection_plan.md` 中定义的覆盖率范围、metric、门槛和最终输出格式。
- 确认当前 Makefile 已具备 VCS coverage compile、`run_cov`、`make cov`、URG report 生成能力。
- 确认现有 PTW source signoff 文档、source closure matrix 和 gate 脚本仍是当前功能闭合依据。
- 建立阶段任务计划文档，并作为后续实施 checklist。

### 4.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| 阶段计划文档 | `doc/ptw_uvm_review/ptw_code_coverage_staged_task_plan.md` 创建或更新完成 |
| 执行目录约定 | 明确所有 coverage 命令默认从 `mmu_verification/` 仿真目录执行 |
| 基线能力确认 | 记录 Makefile 已有 `comp_all`、`run_cov`、`regress`、`cov` 能力 |
| 功能闭合前提 | 确认 PTW source signoff gate 是 code coverage 解释前置条件 |
| 范围冻结记录 | 明确 PTW code coverage 不包含全 MMU、testbench、SVA、functional coverage |
| 阶段准入记录 | 后续 Stage 1 到 Stage 9 的依赖关系、退出标准和最终交付件已明确 |

### 4.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_code_coverage_detection_plan.md` | 原始 PTW code coverage 检测计划，是本阶段计划的来源 |
| `doc/ptw_uvm_review/ptw_code_coverage_staged_task_plan.md` | 本文档，定义分阶段实施计划 |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | PTW source-side 功能闭合依据 |
| `doc/ptw_uvm_review/ptw_source_closure_matrix.md` | PTW source closure matrix |
| `mmu_verification/Makefile` | coverage compile、run_cov、URG、regress 入口 |
| `mmu_verification/scripts/run_test.py` | test registry、regress 展开和 log 命名逻辑 |
| `mmu_verification/scripts/run_urg_report.sh` | URG report 生成脚本 |

### 4.4 退出标准检查

- [ ] 已确认所有后续命令默认从 `mmu_verification/` 仿真目录执行。
- [ ] 已确认原始计划中的最终输出三态为 `PASS/FAIL/CONDITIONAL_PASS`。
- [ ] 已确认最终 headline 只允许来自 PTW-only URG report。
- [ ] 已确认本阶段计划文档已创建并纳入 review。
- [ ] 已确认后续实施不会把全 MMU coverage 或 functional coverage 当作 PTW RTL code coverage。

## 5. Stage 1：PTW-only coverage scope 建立

### 5.1 任务内容

- 新增 PTW 专用 coverage hierarchy 配置。
- 首选使用 PTW instance tree：

```text
+tree tb_top.u_dut.x_ct_mmu_ptw
```

- 排除 SVA、testbench、非 PTW RTL scope。
- 如果 VCS 不接受 instance tree，切换到 module whitelist 方案，且必须在 log、manifest、summary 中记录：

```text
scope_method=module_whitelist
scope_reason=instance_tree_not_accepted_by_cm_hier
```

- 执行 coverage compile 验证配置是否可被 VCS 接受。
- 检查 compile log 和后续 URG hierarchy/modlist，确认 scope 只包含 PTW RTL。

### 5.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| PTW hierarchy 配置 | 新增 `mmu_verification/scripts/ptw_cov_hier.cfg` |
| scope 选择记录 | 记录 `instance_tree` 或 `module_whitelist`，以及 fallback 原因 |
| coverage compile baseline | 生成或验证 `output/ptw_cov/simv_ptw.compile.vdb` |
| compile scope 检查记录 | 记录 compile log 中 `cm_hier` 是否通过、PTW module 是否纳入 |
| scope 黑名单检查记录 | 记录非 PTW module、SVA、testbench 是否被排除 |
| Stage 4 parser 输入约束 | 为 parser 提供 allowed/denied module 和 required root 的依据 |

### 5.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/scripts/ptw_cov_hier.cfg` | 新增 PTW-only coverage hierarchy 配置 |
| `mmu_verification/scripts/cov_hier.cfg` | 现有全环境 coverage hierarchy，只能作为参考，不能作为最终 PTW result scope |
| `mmu_verification/Makefile` | `COV_HIER_CFG`、`COV_COMPILE_OPTS`、`comp_all` 的来源 |
| `mmu_verification/output/ptw_cov/simv_ptw.compile.vdb` | PTW coverage compile baseline VDB |
| `mmu_verification/output/ptw_cov/urgReport/` | 后续用于 scope 复核的 URG report |

### 5.4 退出标准检查

- [ ] `scripts/ptw_cov_hier.cfg` 已存在。
- [ ] `ptw_cov_hier.cfg` 不包含全 `tb_top` coverage scope。
- [ ] PTW instance tree 方案或 module whitelist 方案至少有一个可用。
- [ ] coverage compile 通过，无 `cm_hier` 解析错误。
- [ ] compile baseline VDB 存在且非空。
- [ ] scope 黑名单 module 未进入 PTW code coverage metric：
  - `ct_mmu_top`
  - `l1dtlb`
  - `l1itlb`
  - `l2tlb`
  - `pmp`
  - `sysmap`
  - `mmu_*_sva`
  - testbench module
- [ ] 若使用 module whitelist，summary 必须记录 whitelist module 列表和切换原因。

## 6. Stage 2：覆盖率测试集和 profile 建立

### 6.1 任务内容

- 新增默认 PTW coverage regression list。
- 将 PTW source directed、PDE pmpflg、PTW-LSU protocol、Phase12/13 consumer/system-level 场景纳入默认覆盖率刺激。
- 新增 coverage profile JSON，定义 `quick/default/full/signoff` 四档 profile。
- 每个 profile 必须使用 `runs[]` 结构，不允许使用旧式全局 `lists/seeds`。
- 检查每个 list 中 test 是否已注册。
- 展开每个 profile 的 `(test_name, seed)`，检查 duplicate `COV_TAG` 风险。
- 默认不重复运行同一个 `(test_name, seed)`；若同 test/seed 必须用不同 plusargs 运行，必须先实现唯一 `COV_TAG` 传递。

### 6.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| 默认 coverage list | 新增 `mmu_verification/simu/ptw_code_coverage_list` |
| profile 配置 | 新增 `mmu_verification/scripts/ptw_code_coverage_profiles.json` |
| profile 展开记录 | 记录 `quick/default/full/signoff` 每个 run group 的 list、seed 和用途 |
| test registry 检查记录 | 记录每个 list 中 test 是否在 UVM registry 中存在 |
| duplicate 检查记录 | 记录重复 `(test_name, seed)`、dedup 处理或 `duplicate_cov_tag` 风险 |
| seed 成本控制记录 | 确认 full regression seeds 与 PTW source seeds 分开声明，不使用全局 seed 乘法 |
| Stage 5 runner 输入 | 为 runner 提供稳定 profile、list、seed、regression name 生成依据 |

### 6.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/simu/ptw_code_coverage_list` | 新增 default profile 主 coverage list |
| `mmu_verification/scripts/ptw_code_coverage_profiles.json` | 新增 quick/default/full/signoff profile 配置 |
| `mmu_verification/simu/ptw_p0_smoke_list` | quick/profile sanity 来源 |
| `mmu_verification/simu/ptw_p0_list` | PTW P0 directed source coverage 来源 |
| `mmu_verification/simu/ptw_p1_list` | PTW P1 directed source coverage 来源 |
| `mmu_verification/simu/ptw_p2_illegal_list` | illegal guard 和约束路径来源 |
| `mmu_verification/simu/ptw_pde_pmpflg_list` | PDE pmpflg directed coverage 来源 |
| `mmu_verification/simu/ptw_random_list` | PTW random permission cross 来源 |
| `mmu_verification/simu/ptw_consumer_evidence_list` | PTW consumer evidence 来源 |
| `mmu_verification/simu/mmu_ptw_lsu_protocol_list` | PTW-LSU protocol coverage 来源 |
| `mmu_verification/simu/mmu_v4_phase12_list` | PTW-ready、TWU、MBUF、arb system-level 刺激 |
| `mmu_verification/simu/mmu_v4_phase13_list` | PMP/SysMap/4-TWU concurrency 刺激 |
| `mmu_verification/simu/mmu_v4_full_regression_list` | signoff/full 追加覆盖率入口 |
| `mmu_verification/scripts/run_test.py` | test registry 和 testlist 解析逻辑 |

### 6.4 退出标准检查

- [ ] `simu/ptw_code_coverage_list` 已创建。
- [ ] `scripts/ptw_code_coverage_profiles.json` 已创建。
- [ ] profile 只使用 `runs[]`，不存在顶层全局 `lists` 和 `seeds`。
- [ ] `quick` profile 能覆盖最小编译、run_cov、URG、parser sanity。
- [ ] `default` profile 能输出用户日常 PTW coverage 数值。
- [ ] `full` profile 用于 default 未达标后的扩展覆盖率闭合。
- [ ] `signoff` profile 用于最终交付。
- [ ] `make list_tests` 或 `python3 scripts/run_test.py --list` 能找到所有新增 list 中的 test。
- [ ] 展开 profile 后没有未处理的重复 `(test_name, seed)`。
- [ ] 如果存在重复 `(test_name, seed)`，manifest 中有 dedup 记录，或 flow 已实现唯一 `COV_TAG`。

## 7. Stage 3：functional gate 集成规则建立

### 7.1 任务内容

- 将 PTW source-side functional gate 定义为 code coverage 解释前置条件。
- 明确 runner 支持三种 functional gate 模式：
  - `run`：重新运行第 8 节 source signoff gate；
  - `reuse`：复用已有通过证据；
  - `skip`：只允许 debug 或中间结果，不能 signoff PASS。
- 固化 functional gate 使用 `REGRESS_MODE=run_check`，日志名为 `${test}_${seed}.log`。
- 明确 coverage run 使用 `REGRESS_MODE=run_cov`，日志名为 `${test}_${seed}_cov.log`。
- 禁止把 `_cov.log` 传给 `ptw_stage8_signoff_gate.py`。
- gate evidence 必须进入 manifest 和最终 JSON summary。

### 7.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| gate 模式定义 | 明确 `run/reuse/skip` 三种 functional gate 模式和使用限制 |
| gate evidence schema | 定义 log dirs、closure report、git commit、生成时间、gate 命令等证据字段 |
| run_check 命令集合 | 固化第 8 节 PTW source signoff gate 所需 list、seed、regress name |
| reuse 证据要求 | 明确 reuse 时必须提供已有通过证据，且证据可追溯 |
| skip 限制记录 | 明确 skip 只能用于 debug 或中间 profile，不能 signoff PASS |
| manifest 字段定义 | 明确 `functional_gate` 字段写入 `ptw_cov_manifest.json` 和 summary JSON |

### 7.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/scripts/ptw_stage8_signoff_gate.py` | PTW source-side signoff gate 脚本 |
| `mmu_verification/output/regression/ptw_src_*/logs/` | functional gate `run_check` 日志目录 |
| `mmu_verification/output/ptw_stage8_cov_collect/ptw_source_closure_matrix.csv` | source closure matrix 输出 |
| `mmu_verification/output/ptw_stage8_cov_collect/ptw_source_coverage_report.md` | source closure report 输出 |
| `mmu_verification/output/ptw_cov/ptw_cov_manifest.json` | 记录 functional gate 模式和证据 |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json` | 最终 JSON 中记录 `functional_gate` 字段 |

### 7.4 退出标准检查

- [ ] runner 设计中包含 `--functional-gate-mode <run|reuse|skip>`。
- [ ] runner 设计中包含 `--functional-gate-evidence`。
- [ ] `run` 模式会重新生成第 8 节所需 `run_check` 日志。
- [ ] `reuse` 模式要求 evidence 记录 log dirs、closure report、git commit、生成时间和 gate 命令。
- [ ] `skip` 模式不能输出 signoff `PASS`。
- [ ] manifest 能区分 functional gate runs 和 coverage runs。
- [ ] signoff profile 中 `functional_gate.status` 只能是 `PASS` 或 evidence 完整的 `REUSED`。

## 8. Stage 4：URG parser 和 summary 生成脚本

### 8.1 任务内容

- 新增 PTW code coverage parser。
- 支持 URG text 和 HTML report 解析。
- 解析 line、condition、branch、fsm、toggle、assertion 分项。
- 在解析 metric 前先执行 PTW-only scope check。
- 支持 hit/total headline 计算；若只有 percentage，标记较低 confidence。
- 输出 JSON summary、Markdown summary 和 stdout result line。
- 提取 top uncovered holes。
- 编写 parser unit tests，不依赖 VCS license。

### 8.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| parser 脚本 | 新增 `mmu_verification/scripts/ptw_extract_code_coverage.py` |
| parser 单元测试 | 新增 `mmu_verification/scripts/tests/ptw_cov_parser/` 及最小样例 report |
| scope check 实现 | 支持 instance tree 和 module whitelist scope 校验，能拒绝非 PTW RTL scope |
| metric 解析实现 | 支持 line、condition、branch、fsm、toggle、assertion 的 hit/total 或 percentage 解析 |
| headline 计算实现 | 支持 `urg_total_score`、`weighted_hit_total`、`percent_average`，并写入 `headline_method` |
| summary schema | 固化 JSON schema 和 Markdown summary 模板 |
| holes 提取结果 | 输出 `holes_top20`，至少支持 module-level low coverage fallback |
| parser 测试记录 | 记录 unit test 命令、通过结果和失败样例覆盖范围 |
| parser result line | stdout 最后一行可输出 `PTW_CODE_COVERAGE_RESULT` |

### 8.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/scripts/ptw_extract_code_coverage.py` | 新增 parser 和 summary 生成脚本 |
| `mmu_verification/scripts/tests/ptw_cov_parser/` | parser 单元测试和样例 report |
| `mmu_verification/output/ptw_cov/urgReport/` | parser 输入 URG report 目录 |
| `mmu_verification/output/ptw_cov/ptw_extract_code_coverage.log` | parser 执行 log |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.md` | parser 生成 Markdown summary |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json` | parser 生成 JSON summary |
| `mmu_verification/output/ptw_cov/ptw_cov_manifest.json` | parser 引用 run/profile/gate 信息 |

### 8.4 退出标准检查

- [ ] parser 支持 `dashboard.txt`、`hierarchy.txt`、`modlist.txt`。
- [ ] parser 支持 HTML fallback。
- [ ] parser 在 metric 解析前执行 scope check。
- [ ] parser 能拒绝非 PTW RTL scope。
- [ ] parser 能输出 `confidence=high|medium|low`。
- [ ] parser 能区分 `PASS/FAIL/CONDITIONAL_PASS`。
- [ ] parser 能输出 `reason`，例如 `scope_invalid`、`missing_metric`、`threshold_fail`、`ambiguous_metric`。
- [ ] parser 能输出 `holes_top20`。
- [ ] JSON schema 包含 `status/reason/confidence/scope_check/functional_gate/run_manifest/metrics/holes_top20/waivers`。
- [ ] Markdown summary 使用固定结构，包含 Result、Scope、Metrics、Runs、Functional Gate、Holes、Waivers。
- [ ] parser unit tests 通过：

```bash
python3 -m unittest discover -s scripts/tests -p 'test_ptw_cov_*.py'
```

## 9. Stage 5：一键 runner 实现

### 9.1 任务内容

- 新增 `run_ptw_code_coverage.py`。
- 由 runner 编排 `make check_env`、test registry check、functional gate、clean、compile、run_cov、URG、parser、manifest。
- runner 不重写 Makefile 逻辑，只调用现有 Makefile target。
- runner 必须支持 dry-run。
- runner 必须拒绝 `--jobs` 非 1 的覆盖率运行。
- runner 必须按 `(test_name, seed)` 检查 duplicate `COV_TAG`。
- runner 清理时只清理 `output/ptw_cov` 内覆盖率产物，不删除 functional gate logs。
- runner 失败时保留所有证据。

### 9.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| runner 脚本 | 新增 `mmu_verification/scripts/run_ptw_code_coverage.py` |
| dry-run 输出 | 生成 profile 展开、命令列表、regression name、COV 变量和 manifest 预览 |
| runner 状态机 | 固化 `INIT` 到 `DONE/FAILED` 的阶段状态和失败记录 |
| manifest 输出 | 生成 `output/ptw_cov/ptw_cov_manifest.json`，记录 profile、runs、seed、gate evidence、git commit |
| runner log | 生成 `output/ptw_cov/run_ptw_code_coverage.log`，记录每个命令、返回码和日志路径 |
| functional gate 编排 | 支持 `run/reuse/skip`，并把 gate 证据写入 manifest |
| coverage regression 编排 | 串行执行 `make regress REGRESS_MODE=run_cov REGRESS_JOBS=1` |
| duplicate 检查结果 | 记录 `(test_name, seed)` dedup 或 `duplicate_cov_tag` 失败原因 |
| final stdout | runner 完成后打印 parser 或 runner 汇总后的 `PTW_CODE_COVERAGE_RESULT` |

### 9.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/scripts/run_ptw_code_coverage.py` | 新增一键 runner |
| `mmu_verification/scripts/ptw_code_coverage_profiles.json` | runner profile 输入 |
| `mmu_verification/scripts/ptw_cov_hier.cfg` | runner compile/run_cov 使用的 PTW-only hierarchy |
| `mmu_verification/Makefile` | runner 调用 `check_env`、`comp_all`、`regress`、`cov` |
| `mmu_verification/output/ptw_cov/run_ptw_code_coverage.log` | runner 状态机和命令 log |
| `mmu_verification/output/ptw_cov/ptw_cov_manifest.json` | runner manifest |
| `mmu_verification/output/regression/ptw_cov_*/summary.txt` | coverage regression summary |

### 9.4 退出标准检查

- [ ] runner 支持 `--profile <quick|default|full|signoff>`。
- [ ] runner 支持 `--dry-run`，且 dry-run 不运行仿真。
- [ ] runner dry-run 能展开 profile、list、seed、regression name。
- [ ] runner dry-run 能检查 list 文件存在。
- [ ] runner dry-run 能检查 duplicate `(test_name, seed)`。
- [ ] runner 状态机至少包含：
  - `INIT`
  - `CHECK_ENV`
  - `CHECK_TEST_REGISTRY`
  - `CHECK_HIER_CFG`
  - `CLEAN_OUTPUT`
  - `COMPILE`
  - `RUN_FUNCTIONAL_GATE`
  - `RUN_COVERAGE_REGRESSIONS`
  - `GENERATE_URG`
  - `PARSE_REPORT`
  - `WRITE_MANIFEST`
  - `DONE`
  - `FAILED`
- [ ] runner 写出 `run_ptw_code_coverage.log`。
- [ ] runner 写出 `ptw_cov_manifest.json`。
- [ ] runner 对 `REGRESS_JOBS != 1` 报错。
- [ ] runner 对非 PTW `COV_HIER_CFG` 报错。
- [ ] runner 对 coverage regression failure 不解释覆盖率结果。
- [ ] runner 最后打印 `PTW_CODE_COVERAGE_RESULT`。

## 10. Stage 6：Makefile、CI 和文档入口集成

### 10.1 任务内容

- 在 Makefile 中新增 `ptw_code_cov` target。
- 使用 `PTW_COV_*` 变量，避免污染现有 `COV_*` 默认值。
- 支持 profile、cov-root、hier-cfg、jobs、timeout、verbosity、functional gate mode、extra args。
- 明确 quick/default/full/signoff CI 规则。
- 在 source signoff report 中增加 code coverage summary 链接，但不混淆 source-side 功能闭合和 code coverage。

### 10.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| Makefile target | `mmu_verification/Makefile` 新增 `.PHONY: ptw_code_cov` |
| PTW_COV 变量 | 定义 `PTW_COV_PROFILE`、`PTW_COV_ROOT`、`PTW_COV_HIER_CFG`、`PTW_COV_JOBS` 等入口变量 |
| runner 调用入口 | `make ptw_code_cov` 能调用 `scripts/run_ptw_code_coverage.py` |
| CI 判定规则 | 明确 quick/default/full/signoff job 的允许 status 和 artifact 要求 |
| 文档链接 | 在 source signoff report 或相关索引中增加 code coverage summary 链接 |
| debug 参数约束 | 明确 `PTW_COV_EXTRA_ARGS` 只用于 debug，不能用于 signoff job |
| 用户命令说明 | 固化最终用户命令 `make ptw_code_cov PTW_COV_PROFILE=<profile>` |

### 10.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/Makefile` | 新增 `ptw_code_cov` target |
| `mmu_verification/scripts/run_ptw_code_coverage.py` | Makefile target 调用入口 |
| `doc/ptw_uvm_review/ptw_code_coverage_detection_plan.md` | 原始检测计划 |
| `doc/ptw_uvm_review/ptw_code_coverage_staged_task_plan.md` | 分阶段任务计划 |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | 可增加 coverage summary 链接 |
| CI 配置文件 | 若项目有 CI，需要增加 quick/default/signoff jobs |

### 10.4 退出标准检查

- [ ] `make ptw_code_cov` 能调用 runner。
- [ ] `make ptw_code_cov PTW_COV_PROFILE=quick` 能调用 quick profile。
- [ ] `make ptw_code_cov PTW_COV_PROFILE=signoff` 能调用 signoff profile。
- [ ] `PTW_COV_JOBS` 默认是 1。
- [ ] `PTW_COV_FUNCTIONAL_GATE_MODE` 默认是 `run`。
- [ ] debug 选项必须通过 `PTW_COV_EXTRA_ARGS` 显式传递。
- [ ] CI signoff job 只接受 `PTW_CODE_COVERAGE_RESULT status=PASS`。
- [ ] CI quick/default/full job 的 `CONDITIONAL_PASS` 不能当作最终 signoff。
- [ ] 文档中已说明 `make ptw_code_cov` 是最终用户入口。

## 11. Stage 7：quick profile flow smoke

### 11.1 任务内容

- 执行 quick profile，验证完整 flow 是否可运行。
- quick profile 只用于 environment sanity，不作为最终覆盖率签核。
- 检查 compile baseline VDB、coverage VDB、URG report、parser summary 是否生成。
- 检查 stdout result line 是否稳定。
- 如果 quick flow 失败，优先修 flow，不做 coverage hole 解释。

### 11.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| quick run log | `output/ptw_cov/run_ptw_code_coverage.log` 记录 quick flow 全流程 |
| quick manifest | `output/ptw_cov/ptw_cov_manifest.json` 记录 quick profile、list、seed、gate 状态 |
| quick compile VDB | `output/ptw_cov/simv_ptw.compile.vdb` 存在且非空 |
| quick coverage VDB | `output/ptw_cov/simv_ptw.vdb` 存在且非空 |
| quick URG report | `output/ptw_cov/urgReport/` 生成 |
| quick summary | `ptw_code_coverage_summary.md/json` 生成并标记 `profile=quick` |
| quick result line | stdout 输出 `PTW_CODE_COVERAGE_RESULT`，但不得作为最终 signoff PASS |
| flow issue list | 若 quick 失败，记录失败 state、reason、command、log path 和修复动作 |

### 11.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/scripts/ptw_code_coverage_profiles.json` | quick profile 配置 |
| `mmu_verification/output/ptw_cov/simv_ptw.compile.vdb` | coverage compile baseline |
| `mmu_verification/output/ptw_cov/simv_ptw.vdb` | quick coverage aggregate VDB |
| `mmu_verification/output/ptw_cov/urgReport/` | quick URG report |
| `mmu_verification/output/ptw_cov/run_ptw_code_coverage.log` | quick flow log |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.md` | quick summary |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json` | quick JSON summary |

### 11.4 退出标准检查

- [ ] 以下命令可执行完成：

```bash
cd /x2025/GPrj1/IC2/mmu_verification/mmu_verification
make ptw_code_cov PTW_COV_PROFILE=quick
```

- [ ] `run_cov` logs 使用 `_cov.log`。
- [ ] aggregate VDB 存在且非空。
- [ ] URG report 生成。
- [ ] parser 输出 `PTW_CODE_COVERAGE_RESULT`。
- [ ] JSON 中 `profile=quick`。
- [ ] JSON 中 `scope=ptw_core`。
- [ ] JSON 中记录 `functional_gate` 状态。
- [ ] quick 结果即使数值达标，也不会被标成最终 signoff PASS。

## 12. Stage 8：default profile 覆盖率测量

### 12.1 任务内容

- 执行 default profile，产出第一版真实 PTW code coverage 数值。
- 检查 default coverage result 是否达到 headline 和分项门槛。
- 如果未达标，提取 top uncovered holes。
- 对每个 hole 进行分类：
  - stimulus gap；
  - observation/probe gap；
  - spec unreachable；
  - dead/debug RTL；
  - tool/report artifact。
- 建立 hole action list，决定进入 signoff/full、补测、修 parser、修 hierarchy 或 waiver review。

### 12.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| default run log | `output/ptw_cov/run_ptw_code_coverage.log` 记录 default flow |
| default manifest | `output/ptw_cov/ptw_cov_manifest.json` 记录 default runs、seeds、gate evidence |
| default URG report | `output/ptw_cov/urgReport/` 作为 default 数值来源 |
| default summary JSON | `output/ptw_cov/ptw_code_coverage_summary.json` 输出真实 PTW code coverage 数值 |
| default summary Markdown | `output/ptw_cov/ptw_code_coverage_summary.md` 输出可 review 报告 |
| metric 达标表 | 输出 headline、line、condition、branch、fsm、toggle、assertion 与门槛对比 |
| holes_top20 | 输出 top uncovered holes 或说明无法解析 hole detail 的原因 |
| hole action list | 对每个未达标 metric/hole 给出补测、full/signoff、parser 修正、hierarchy 修正或 waiver review 动作 |
| 中间 result line | stdout 输出 `CONDITIONAL_PASS` 或 `FAIL`，不输出最终 signoff PASS |

### 12.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/simu/ptw_code_coverage_list` | default coverage test list |
| `mmu_verification/scripts/ptw_code_coverage_profiles.json` | default profile seed 和 list |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.md` | default 覆盖率报告 |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json` | default JSON 数值和 holes |
| `mmu_verification/output/ptw_cov/urgReport/` | default URG report |
| `mmu_verification/output/ptw_cov/ptw_cov_manifest.json` | default run manifest |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | 对齐功能闭合状态 |

### 12.4 退出标准检查

- [ ] 以下命令可执行完成：

```bash
cd /x2025/GPrj1/IC2/mmu_verification/mmu_verification
make ptw_code_cov PTW_COV_PROFILE=default
```

- [ ] stdout 最后一行包含 `PTW_CODE_COVERAGE_RESULT`。
- [ ] JSON 中 `profile=default`。
- [ ] JSON 中 `scope_check.status=PASS`。
- [ ] JSON 中 `confidence` 至少为 `medium`；若要进入最终签核，必须达到 `high`。
- [ ] JSON 中 line/condition/branch/fsm/toggle/assertion 分项齐全。
- [ ] 若 coverage 达标，结果应是 `CONDITIONAL_PASS reason=non_signoff_profile`，不能作为最终 PASS。
- [ ] 若 coverage 未达标，结果应是 `FAIL reason=threshold_fail` 或其他稳定 reason。
- [ ] holes_top20 已生成，或明确说明没有可解析 hole detail。
- [ ] 每个未达标 metric 都有下一步动作。

## 13. Stage 9：signoff/full 覆盖率闭合

### 13.1 任务内容

- 根据 Stage 8 的 hole action list，决定执行 `full` 或 `signoff` profile。
- 如 default 未达标，优先运行 `full` 评估 full regression 对 holes 的补充效果。
- 最终交付前运行 `signoff` profile。
- 如果 signoff 仍有 uncovered holes：
  - 对 stimulus gap 增加或补跑 directed/hole-fill tests；
  - 对 tool/report artifact 修 parser 或重跑 URG；
  - 对 spec unreachable/dead/debug RTL 建立精确 waiver；
  - 对 observation/probe gap 修 testbench/probe，不把 TB 缺口当 RTL waiver。
- 产出最终 `PTW_CODE_COVERAGE_RESULT`。
- 归档 summary、JSON、manifest、URG report、VDB 和 waiver 记录。

### 13.2 任务产出内容

| 产出 | 内容 |
| --- | --- |
| signoff/full run log | `output/ptw_cov/run_ptw_code_coverage.log` 记录最终 flow |
| final manifest | `output/ptw_cov/ptw_cov_manifest.json` 记录 signoff profile、runs、seeds、gate evidence、git commit |
| final URG report | `output/ptw_cov/urgReport/` 作为最终 PTW-only 覆盖率来源 |
| final coverage VDB | `output/ptw_cov/simv_ptw.vdb` 和 `merged_ptw.vdb` 归档 |
| final summary JSON | `output/ptw_cov/ptw_code_coverage_summary.json` 包含最终 status/reason/confidence/metrics/waivers |
| final summary Markdown | `output/ptw_cov/ptw_code_coverage_summary.md` 包含最终结果、scope、runs、holes、waivers |
| waiver 记录 | 对不可达或保留项记录 file/module/line/object/metric/reason/approval |
| final result line | stdout 输出最终 `PTW_CODE_COVERAGE_RESULT status=PASS|FAIL|CONDITIONAL_PASS` |
| 归档清单 | 明确 VDB、URG、summary、manifest、waiver、log 的保存路径和版本 |

### 13.3 相关文件说明

| 文件 | 作用 |
| --- | --- |
| `mmu_verification/scripts/ptw_code_coverage_profiles.json` | full/signoff profile 配置 |
| `mmu_verification/simu/mmu_v4_full_regression_list` | signoff/full 追加 coverage list |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.md` | 最终 signoff summary |
| `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json` | 最终 signoff JSON |
| `mmu_verification/output/ptw_cov/ptw_cov_manifest.json` | 最终 manifest |
| `mmu_verification/output/ptw_cov/urgReport/` | 最终 URG report |
| `mmu_verification/output/ptw_cov/simv_ptw.vdb` | 最终 aggregate VDB |
| `mmu_verification/output/ptw_cov/merged_ptw.vdb` | 最终 merged VDB |
| waiver 记录文件 | 精确记录 file/module/line/object/metric/reason/approval |

### 13.4 退出标准检查

- [ ] 以下命令可执行完成：

```bash
cd /x2025/GPrj1/IC2/mmu_verification/mmu_verification
make ptw_code_cov PTW_COV_PROFILE=signoff
```

- [ ] stdout 包含 `PTW_CODE_COVERAGE_RESULT status=PASS`，或明确输出 `FAIL/CONDITIONAL_PASS` 和 reason。
- [ ] `profile=signoff`。
- [ ] `functional_gate.status=PASS`，或 `REUSED` 且 evidence 完整。
- [ ] `scope_check.status=PASS`。
- [ ] `confidence=high`。
- [ ] headline >= 99.0%。
- [ ] line >= 99.5%。
- [ ] condition >= 99.0%。
- [ ] branch >= 99.0%。
- [ ] fsm >= 99.0%，或 N/A 且有明确 `na_reason`。
- [ ] toggle >= 98.0%。
- [ ] assertion coverage 100.0%，或 N/A 且有明确 `na_reason`。
- [ ] 所有未达标对象均有精确且正式批准的 waiver，或已通过补测覆盖。
- [ ] JSON、Markdown summary、manifest、URG report、VDB 已归档。
- [ ] 最终结果没有使用全 MMU coverage 或 testbench/SVA coverage 作为 PTW headline。

## 14. 阶段依赖关系

| 阶段 | 依赖 |
| --- | --- |
| Stage 0 | 无 |
| Stage 1 | Stage 0 |
| Stage 2 | Stage 0 |
| Stage 3 | Stage 0 |
| Stage 4 | Stage 1 的 scope 定义和 Stage 0 的 metric/threshold 定义 |
| Stage 5 | Stage 1、Stage 2、Stage 3、Stage 4 |
| Stage 6 | Stage 5 |
| Stage 7 | Stage 1、Stage 2、Stage 3、Stage 4、Stage 5、Stage 6 |
| Stage 8 | Stage 7 |
| Stage 9 | Stage 8 |

Stage 1、Stage 2、Stage 3 可以并行设计，但 Stage 5 runner 实现必须等三者接口冻结后再完成。Stage 7 之后才开始解释实际 coverage 数值。

## 15. 最终交付件清单

最终完成 Stage 9 后，应至少具备以下交付件：

| 类型 | 文件或产物 |
| --- | --- |
| 计划文档 | `doc/ptw_uvm_review/ptw_code_coverage_detection_plan.md` |
| 阶段计划 | `doc/ptw_uvm_review/ptw_code_coverage_staged_task_plan.md` |
| PTW coverage hierarchy | `mmu_verification/scripts/ptw_cov_hier.cfg` |
| coverage list | `mmu_verification/simu/ptw_code_coverage_list` |
| profile 配置 | `mmu_verification/scripts/ptw_code_coverage_profiles.json` |
| parser | `mmu_verification/scripts/ptw_extract_code_coverage.py` |
| parser tests | `mmu_verification/scripts/tests/ptw_cov_parser/` |
| runner | `mmu_verification/scripts/run_ptw_code_coverage.py` |
| Makefile target | `mmu_verification/Makefile` 中的 `ptw_code_cov` |
| runner log | `mmu_verification/output/ptw_cov/run_ptw_code_coverage.log` |
| manifest | `mmu_verification/output/ptw_cov/ptw_cov_manifest.json` |
| URG report | `mmu_verification/output/ptw_cov/urgReport/` |
| coverage VDB | `mmu_verification/output/ptw_cov/simv_ptw.vdb` |
| merged VDB | `mmu_verification/output/ptw_cov/merged_ptw.vdb` |
| final summary markdown | `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.md` |
| final summary JSON | `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json` |
| final result line | `PTW_CODE_COVERAGE_RESULT ...` |

## 16. 阶段执行推荐顺序

推荐执行顺序如下：

1. 完成 Stage 0，冻结计划和执行目录。
2. 完成 Stage 1，建立 PTW-only scope。
3. 完成 Stage 2，建立 coverage list 和 profile。
4. 完成 Stage 3，定义 functional gate 证据规则。
5. 完成 Stage 4，实现 parser 和 unit tests。
6. 完成 Stage 5，实现 runner 和 dry-run。
7. 完成 Stage 6，接入 Makefile/CI/文档。
8. 执行 Stage 7 quick flow smoke。
9. 执行 Stage 8 default coverage 测量和 hole analysis。
10. 执行 Stage 9 signoff/full 覆盖率闭合。

任何阶段失败时，先保留证据并修复该阶段问题，不跳过失败阶段直接解释后续 coverage 数值。
