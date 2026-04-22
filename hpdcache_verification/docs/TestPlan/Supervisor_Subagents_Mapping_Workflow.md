# HPDcache TestPoint Mapping: Supervisor + Subagents Architecture

## 1. 目标
将 [docs/TestPlan/Test_Items_Structured.md](docs/TestPlan/Test_Items_Structured.md) 中每一个测试点，映射到：
- 已有 test（`testbench/test/**`）
- 已有 sequence（`testbench/hpdcache_agent/hpdcache_sequences.svh`）
- 或给出“缺失实现”的补齐建议

同时模拟验证团队按测试点编写 sequence/test 的工程流程。

## 2. 架构

### 2.1 Supervisor
职责：
- 统一接收任务（测试点全量映射）
- 拆解子任务并分发给子代理
- 合并证据并去重（同名测试点重复、不同章节复述）
- 输出最终映射矩阵与缺口清单

输入：
- 测试计划文档
- 代码仓 test/sequence/SVA/coverage 文件树

输出：
- `TestPoint -> {Test, Sequence, SVA/CG/SB, Status}` 矩阵
- Gap backlog（待实现）
- “测试点驱动开发”模拟步骤

### 2.2 Subagents

1) `PlanExtractorAgent`
- 从测试计划抽取 `#### 📌 Test Case:`
- 分类：可执行 testcase 名称型、断言型、覆盖型、ENV capability 型、疑似缺失型
- 输出：规范化测试点清单（去重前）

2) `TestSequenceMapperAgent`
- 扫描 `testbench/test/**`
- 解析 `test class -> sequence create/cast/start` 链路
- 提取 `set_type_override_by_type(...)`
- 识别背压方式：
  - memory BP（`set_enable_rd_output/set_enable_wr_output`）
  - ready BP（`bp_vif.force_bp_out/release_bp_out`）

3) `AssertionCoverageAgent`
- 扫描：
  - `testbench/top/hpdcache_fxarb_sva.sv`
  - `testbench/top/hpdcache_sva.sv`
  - `testbench/hpdcache_agent/hpdcache_covergroups.svh`
  - `testbench/hpdcache_agent/hpdcache_monitor.svh`
  - `testbench/env/hpdcache_sb.svh`
- 识别 assert/covergroup/sample/SB check 对应测试点

4) `GapAnalysisAgent`
- 对比计划点与实现点
- 标注：`implemented` / `partially_implemented` / `missing`
- 产出新增 test/sequence 建议

5) `SynthesisAgent`
- 合并多代理结果，生成最终报告
- 产出可评审的映射表和开发闭环流程

## 3. 编排流程（Supervisor 视角）

1. 分发并行任务：`PlanExtractorAgent` + `TestSequenceMapperAgent` + `AssertionCoverageAgent`
2. 聚合中间结果，按测试点标题归一化（统一大小写与空格）
3. 调用 `GapAnalysisAgent` 标记实现状态
4. 调用 `SynthesisAgent` 输出最终矩阵
5. 交付：映射表、缺口单、落地开发步骤

## 4. 数据契约（建议）

### 4.1 测试点对象
```json
{
  "test_point": "Back Pressure with LOAD",
  "doc_ref": "docs/TestPlan/Test_Items_Structured.md#L104",
  "category": "scenario_test",
  "duplicates": ["...#L325", "...#L952"]
}
```

### 4.2 映射对象
```json
{
  "test_point": "Back Pressure with LOAD",
  "status": "implemented",
  "test_classes": [
    "test_hpdcache_multiple_consecutive_set_load_with_memory_bp",
    "test_hpdcache_multiple_consecutive_set_load_with_ready_bp"
  ],
  "sequence_classes": [
    "hpdcache_consecutive_set_access_request_cached"
  ],
  "evidence": [
    "testbench/test/congestion_tests/memory_bp/hpdcache_multiple_consecutive_set_load_with_memory_bp.svh#L24",
    "testbench/hpdcache_agent/hpdcache_sequences.svh#L1095"
  ],
  "notes": "memory_bp与ready_bp均覆盖"
}
```

## 5. 已验证的代表映射（样例）

1. `Arbiter 1 fixed priority check`
- SVA: `hpdcache_fxarb_sva` immediate assert
- 证据：[testbench/top/hpdcache_fxarb_sva.sv](testbench/top/hpdcache_fxarb_sva.sv#L49)

2. `Ready is one hot (Arbiter 1)`
- SVA: `$onehot0(gnt_o)`
- 证据：[testbench/top/hpdcache_fxarb_sva.sv](testbench/top/hpdcache_fxarb_sva.sv#L60)

3. `test_hpdcache_multiple_load_store_requests`
- Test: [testbench/test/basic_tests/hpdcache_multiple_load_store_requests.svh](testbench/test/basic_tests/hpdcache_multiple_load_store_requests.svh#L25)
- Sequence: `hpdcache_multiple_random_requests`
- 证据：[testbench/hpdcache_agent/hpdcache_sequences.svh](testbench/hpdcache_agent/hpdcache_sequences.svh#L719)

4. `Back Pressure with Write ... reset time counter enable`
- Test: [testbench/test/congestion_tests/memory_bp/hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp.svh](testbench/test/congestion_tests/memory_bp/hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp.svh#L24)
- Sequence: `hpdcache_same_tag_set_access_request_cached`
- 证据：[testbench/hpdcache_agent/hpdcache_sequences.svh](testbench/hpdcache_agent/hpdcache_sequences.svh#L1151)

5. `Byte enable coverage`
- Covergroup: `cov_be`
- 证据：[testbench/hpdcache_agent/hpdcache_covergroups.svh](testbench/hpdcache_agent/hpdcache_covergroups.svh#L70)

## 6. 测试点驱动开发模拟流程（团队执行版）

1. 读取测试点
- 输入：测试点文本（目的、约束、判定标准）
- 输出：刺激模板（op分布、地址策略、背压策略）

2. 选择复用或新建 sequence
- 若已有 sequence 能表达：直接复用 + txn override
- 若不能：新增 sequence，并在 base sequence 机制中接入

3. 绑定 test
- 在 `testbench/test/**` 新建 test 类
- 在 `pre_main_phase` 绑定 sequence
- 设置 `override/top_cfg/conf_txn`

4. 接入 checker/coverage
- 协议与时序：SVA
- 功能覆盖：covergroup + monitor.sample
- 语义一致性：scoreboard

5. 通过标准
- 运行窗口内统计值命中期望公式
- 无 `UVM_ERROR/UVM_FATAL`
- 关键 coverage bin 命中

6. 回写矩阵
- 更新 `TestPoint -> Implementation` 映射
- 标记 `implemented/partial/missing`

## 7. Supervisor 执行提示词模板（可直接复用）

```text
你是Supervisor。目标：把测试计划中所有测试点映射到 test/sequence/SVA/coverage。
先并行调用3个子代理：
1) 抽取测试点并分类
2) 建立 test->sequence->override/backpressure 映射
3) 建立 SVA/covergroup/SB 对应关系
然后进行去重和缺口分析，输出最终矩阵（含证据行号）。
```

## 8. 当前仓库限制与建议

- `test_reg_bit_bash / reg access / reg hw reset` 在 test package 未见显式收录，建议单列 gap。
- 性能计数器检查在 `test_base` 有框架但存在注释/FIXME，建议列为 `partially_implemented`。

证据：
- [testbench/test/hpdcache_test_pkg.sv](testbench/test/hpdcache_test_pkg.sv#L35)
- [testbench/test/test_base.svh](testbench/test/test_base.svh#L387)
