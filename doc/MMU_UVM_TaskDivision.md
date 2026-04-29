# MMU UVM 环境搭建 — 双人分工计划

> **基准文档**：[MMU_UVM_BuildPlan_v3_final.md](MMU_UVM_BuildPlan_v3_final.md)
> **验证计划**：[MMU_VerificationPlan_final.md](MMU_VerificationPlan_final.md)
> **日期**：2026-04-23
> **人员**：工程师 A（基础架构）、工程师 B（激励与覆盖率）

---

## 1. 分工原则

| 原则                           | 说明                                                                                                              |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| **按职责层切分**         | A 负责**编译骨架、响应侧 Agent、参考模型、SVA**；B 负责**主动激励 Agent、Covergroup、Vseq、测试用例** |
| **严格串行 Phase 边界**  | Phase 1→2→3→4→5→… 串行推进；A 完成当前 Phase 退出准则后，B 才能进入依赖该成果的下一步                       |
| **Phase 1–2 由 A 主导** | Phase 1（骨架）、Phase 2（Interface + DUT 接入）由 A 完成；B 在 Phase 2 期间同步阅读 RTL 端口 + 熟悉框架          |
| **Phase 3 并行切入**     | Phase 2 退出后，A 和 B**同步进入**各自负责的 Agent 开发，不再强制串行                                       |
| **接口约定先行**         | B 依赖 A 提供的 Interface（.sv）和 Package；两人在 Phase 2 结束时对全部 Interface 端口签名做 Code Review 后冻结   |

---

## 2. 整体分工总表

| 模块 / 交付物                                               | 负责人                    | 依赖（前置 Phase） |
| ----------------------------------------------------------- | ------------------------- | ------------------ |
| **目录骨架、Makefile、setup_env**                     | A                         | —                 |
| **tb_top.sv（时钟+复位框架）**                        | A                         | —                 |
| **7 个 \*_if.sv（Interface）**                        | A 主写，B Review          | Phase 1            |
| **DUT 接入 + uvm_config_db 连线**                     | A                         | Phase 1            |
| **mmu_params_pkg.sv**                                 | A                         | Phase 1            |
| **mmu_common_pkg.sv**（PTE 工具函数骨架）             | A                         | Phase 1            |
| **cp0_agent** 八件套                                  | A                         | Phase 2            |
| **pmp_agent** 八件套                                  | A                         | Phase 2            |
| **sysmap_cfg_agent** 八件套                           | A                         | Phase 2            |
| **ptw_mem_agent** 十件套 + page_table_builder         | A                         | Phase 3            |
| **mmu_page_table_mem.svh**                            | A                         | Phase 4            |
| **mmu_ref_model.svh**                                 | A                         | Phase 4            |
| **mmu_credit_sb.svh**                                 | A                         | Phase 5            |
| **mmu_top_cfg.svh**                                   | A                         | Phase 2            |
| **mmu_env.svh**                                       | A（骨架） → 双方持续补充 | Phase 3            |
| **mmu_virtual_sequencer.svh**                         | B                         | Phase 5            |
| **misc_agent** 八件套                                 | A                         | Phase 5            |
| **ifu_agent** 八件套                                  | B                         | Phase 3            |
| **lsu_agent** 八件套（含 5 子线程 driver）            | B                         | Phase 3            |
| **mmu_translation_sb.svh**                            | B                         | Phase 5            |
| **mmu_invalidate_sb.svh**                             | B                         | Phase 5            |
| **mmu_perf_mon.svh**                                  | B                         | Phase 5            |
| **全部 \*_covergroups.svh（7 个 Agent）**             | B                         | Phase 5            |
| **env 内白盒 covergroup 集中文件**                    | B                         | Phase 6            |
| **5 个 SVA .sv 文件（top/）**                         | A                         | Phase 6            |
| **mmu_vseq_lib.svh（14 个 vseq）**                    | B                         | Phase 7            |
| **test_pkg.sv + test_base.svh**                       | B（A Review）             | Phase 7            |
| **全部测试用例（~120 个 .svh）**                      | B                         | Phase 8            |
| **回归列表（smoke/nightly/coverage）**                | B                         | Phase 9            |
| **simu/exclude.do 覆盖率豁免**                        | B                         | Phase 9            |
| **Makefile 回归 target（regress_*）**                 | A                         | Phase 9            |
| **Gap-driven TC（Phase 11）**                         | B                         | Phase 10           |
| **MAEE / PTW-ready / TWU 验证 TC + SVA（Phase 12）**  | B（SVA 由 A 审查）        | Phase 11           |
| **sysmap / PMP-deny / PMP-port TC + SVA（Phase 13）** | B（SVA 由 A 审查）        | Phase 12           |
| **全量回归 + 覆盖率合并脚本（Phase 14）**             | A 主导，B 配合            | Phase 13           |

---

## 3. 按 Phase 的具体分工

### Phase 1 — 环境骨架（A 独立完成）

| 工程师      | 工作内容                                                                                                                                                                                |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | 创建 `mmu_verification/` 目录结构；复制 `dv_utils`（写 VERSION.txt）；复制 `scripts/`；裁剪 Makefile；写最简 `tb_top.sv`（仅时钟 + `run_test()`）；写空 `testbench/Files.f` |
| **B** | 并行阅读 `MMU_UVM_BuildPlan_v3_final.md` §2–§7；熟悉 hpdcache_agent 八件套结构；列出 ifu_agent / lsu_agent 信号清单草稿                                                            |

**退出准则（A 验证）**：`make compile` + `make run` 通过，0 cycle 退出无错

---

### Phase 2 — DUT 接入与 Interface 连接（A 主导，B Review）

| 工程师      | 工作内容                                                                                                                                                                                                                |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | 写 `mmu_params_pkg.sv`；写 `mmu_common_pkg.sv` 骨架（函数签名，方法体 TODO）；写全部 7 个 `*_if.sv`；更新 `tb_top.sv` 接入 DUT + 所有 interface + `uvm_config_db::set`；更新 `Files.f` 加入 RTL + interface |
| **B** | Review 7 个 interface 端口完整性（对照 §2.4 端口分组表）；确认 `lsu_if.sv` 5 子分组（pipe0/1/2/stamo/inv）信号无遗漏；Review `mmu_params_pkg.sv` Sv39 参数                                                         |

**Phase 2 结束时双方 Code Review 冻结全部 Interface**

**退出准则**：`make compile` DUT elaboration 无错；`make run` 空 test 退出正常

---

### Phase 3 — 最简 Active Agent + Sanity Test（A/B 并行）

| 工程师      | 工作内容                                                                                                                                                                                                                                        | 文件数               |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| **A** | `cp0_agent` 八件套（driver 实现最简 CSR 写）；`pmp_agent` 八件套（driver 实现 8 端口 flag 驱动）；`sysmap_cfg_agent` 八件套（白盒 force/release）；`mmu_env_pkg.sv` 骨架；`mmu_top_cfg.svh`；`mmu_env.svh`（仅 build 这三个 agent） | 3×9+3 =**30** |
| **B** | `ifu_agent` 八件套（driver 方法体 TODO，先完成 txn/sequencer/monitor/agent 骨架）；`lsu_agent` 八件套（同上，5 子分组 interface clocking block 确认）；写 `test_pkg.sv` + `test_base.svh`                                               | 2×9+2 =**20** |

> B 的 ifu/lsu agent 骨架在 Phase 3 完成，方法体在 Phase 5 填充。

**退出准则（A 主导，B 确认）**：

| # | 检查项                                                                               | 验证方式                                              |
| - | ------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| 1 | `make compile` **0 errors / 0 warnings**（已知工具告警须在注释中记录）       | 编译 log 截图留存                                     |
| 2 | A 的三个 Agent（cp0/pmp/sysmap）**8 件套文件全部存在**                         | `ls testbench/{cp0,pmp,sysmap_cfg}_agent/` 输出核查 |
| 3 | B 的 ifu/lsu**骨架文件全部存在**，`test_pkg.sv` + `test_base.svh` 编译通过 | 编译 log 无 undefined symbol                          |
| 4 | `test_mmu_sanity_csr_pmp_sysmap` 单跑：**UVM_ERROR=0 / UVM_FATAL=0**               | 仿真 log 截图留存                                     |
| 5 | `mmu_xx_mmu_en` 拉高有**波形或 assertion log 佐证**                          | Verdi 截图 / log 中打印确认                           |
| 6 | `mmu_env.svh` build 三个 Agent，run_phase **0 cycle 正常退出**               | log 中无 phase 超时告警                               |
| 7 | B**签字 Review**：ifu/lsu 骨架的端口 bind 与对应 `*_if.sv` 完全一致          | Code Review 记录（Git comment 或文档注释）            |

---

### Phase 4 — PTW 内存模型 + 参考模型（A 独立完成）

| 工程师      | 工作内容                                                                                                                                                                                                                                          | 文件数             |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| **A** | `ptw_mem_agent` 十件套（responder 完整实现：PTE 响应 + 延迟 + bus_error 注入）；`page_table_builder.svh`（`map_4k()` 等工具方法）；`mmu_page_table_mem.svh`（基于 memory_shadow）；`mmu_ref_model.svh`（`translate()` 4K happy path） | 10+3 =**13** |
| **B** | 基于 A 的 `page_table_builder` API 草拟 ifu/lsu sequence 伪代码；准备 Phase 5 的 translation 场景列表（来自 VerificationPlan §6.3 F1/F2/F3 功能点）                                                                                            | —                 |

**退出准则（A 验证）**：

| # | 检查项                                                                                            | 验证方式                             |
| - | ------------------------------------------------------------------------------------------------- | ------------------------------------ |
| 1 | `make compile` **0 errors**                                                               | 编译 log 截图                        |
| 2 | `ptw_mem_agent` **十件套 + `page_table_builder.svh` 全部存在**                          | `ls testbench/ptw_mem_agent/` 核查 |
| 3 | `map_4k()` 专用 directed test **≥10 次**，**5 个独立种子**，每次 UVM_ERROR=0       | 仿真 log × 5 份                     |
| 4 | `map_2m()` / `map_1g()` 至少存在骨架（空方法体），**不报编译错误**                      | 编译通过                             |
| 5 | `ref_model.translate()` **50 次 × 5 种子**（随机 VA），`mismatch=0`                    | 仿真 log 中 translation_check 打印   |
| 6 | `mmu_common_pkg.sv` 内所有 `// TODO` 方法体已实现，保留的 TODO **须显式标注目标 Phase** | code review                          |
| 7 | A 为 `ref_model` 核心 page walk 算法写**内联注释**（每个决策分支说明），供 B Phase 5 对接 | code review                          |

---

### Phase 5 — IFU + LSU Agent + Translation SB（B 主导）

| 工程师      | 工作内容                                                                                                                                                                                                                                                                          | 文件数            |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| **B** | 填充 `ifu_driver.svh` + `ifu_monitor.svh` 方法体；填充 `lsu_driver.svh`（`drive_pipe0/1/2/stamo` 四路，inv 子线程留 TODO 至 Phase 6）+ `lsu_monitor.svh`（4 个 ap）；实现 `mmu_translation_sb.svh`（VA→PA + 异常对比）；更新 `mmu_env.svh` 加入 ifu/lsu 两个 agent | 5（新增/修改）    |
| **A** | `misc_agent` 八件套骨架（driver 实现 `rtu_flush` 单脉冲 + `biu_smp_disable` 静态配置）；`mmu_credit_sb.svh`（L1↔L2 credit / ReqQ / MB 容量守恒）；`mmu_perf_mon.svh` 骨架（接口定义，统计 TODO）；更新 `mmu_env.svh` 加入 misc/credit                                | 9+3 =**12** |

**退出准则**：

| # | 检查项                                                                                                            | 验证方式            |
| - | ----------------------------------------------------------------------------------------------------------------- | ------------------- |
| 1 | `make compile` **0 errors**                                                                               | 编译 log            |
| 2 | IFU 单端口随机 VA：**5 个种子 × 100 次**，UVM_ERROR=0                                                      | 仿真 log × 5 份    |
| 3 | LSU pipe0：**5 个种子 × 100 次 LD**，UVM_ERROR=0；pipe1 / pipe2 / stamo **各 ≥20 次**，UVM_ERROR=0  | 仿真 log            |
| 4 | miss→PTW→refill：**3 个种子 × 100 次混合**，`mismatch=0`                                               | 仿真 log 中 SB 打印 |
| 5 | `mmu_translation_sb` 至少接收 **≥200 笔**比对请求，`mismatch=0`                                        | SB 统计 log         |
| 6 | `mmu_credit_sb` 仿真结束时信用守恒计数 **=0**（无泄露/溢出）                                              | SB 统计 log         |
| 7 | `misc_agent` 八件套**编译通过**；`rtu_flush` + `biu_smp_disable` 在 sanity 用例中被**实际驱动** | log 中信号变化打印  |
| 8 | `scan_logs.pl` 对全部仿真 log 扫描：**无 `$error` / `$fatal` / 非预期 ERROR / FATAL**                 | 脚本输出 0 matches  |

---

### Phase 6 — misc_agent 完善 + TLB 失效 + Invalidate SB（B 主导，A 配合）

| 工程师      | 工作内容                                                                                                                                                               |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **B** | 实现 `lsu_driver.svh` 的 `drive_inv` 子线程（SFENCE.VMA 4 种模式）；实现 `mmu_invalidate_sb.svh`；编写对应的 invalidate sequence（可放入 `lsu_sequences.svh`） |
| **A** | 完善 `misc_agent` driver 中的 RTU flush/expt 注入逻辑；完善 `misc_monitor.svh` 中 HPCP cnt_en 采样                                                                 |

**退出准则**：

| # | 检查项                                                                                                    | 验证方式                     |
| - | --------------------------------------------------------------------------------------------------------- | ---------------------------- |
| 1 | `make compile` **0 errors**                                                                       | 编译 log                     |
| 2 | SFENCE.VMA**4 种模式各 100 次**（从 50 提升）× **3 个种子**，`invalidate_sb mismatch=0`    | 仿真 log × 12 份            |
| 3 | `invalidate_sb` 仿真结束打印统计：**`N_invalidations=XX, mismatch=0`**（XX > 0 以证明路径有效） | SB 统计 log                  |
| 4 | RTU flush → PTW abort：**10 次随机时序注入**（flush 与 PTW 完成点不同偏移），abort 行为全部正确    | 仿真 log 中 abort_check 打印 |
| 5 | B**Code Review + 签字**：`misc_monitor.svh` HPCP `cnt_en` 采样点覆盖所有计数器事件              | Review 记录留存              |

---

### Phase 7 — Covergroup + SVA bind（A/B 并行）

| 工程师      | 工作内容                                                                                                                                                       | 文件数           |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| **B** | 7 个 `*_covergroups.svh`（覆盖 BuildPlan §10 黑盒部分）；env 内白盒 covergroup 集中文件（hierarchical reference）；更新 `mmu_env.svh` 注册所有 covergroup | 7+1 =**8** |
| **A** | 5 个 SVA 文件（`mmu_sva.sv` / `mmu_arb_sva.sv` / `mmu_l2tlb_rrpv_sva.sv` / `mmu_plru_sva.sv` / `credit_sva.sv`）；更新 `tb_top.sv` 加入 bind 语句  | **5**      |

**退出准则**：

| # | 检查项                                                                                | 验证方式                                 |
| - | ------------------------------------------------------------------------------------- | ---------------------------------------- |
| 1 | `make compile` **0 errors / 0 warnings**（重点检查 SVA bind scope 告警）      | 编译 log                                 |
| 2 | **全部 7 个 `*_covergroups.svh` 文件存在**并编译通过                          | `ls testbench/*/` 各含 covergroup 文件 |
| 3 | smoke 跑**≥3 个不同 test**，所有 covergroup**每一个 bin 至少 1 hit**           | 覆盖率 HTML 报告截图                     |
| 4 | **生成 HTML 覆盖率报告**，确认 covergroup 层次正确激活                          | 报告文件路径记录                         |
| 5 | **SVA 0 assertion violations**（log 显式记录 assertion pass/fail 统计）         | 仿真 log 中 SVA summary                  |
| 6 | A 为每条 SVA property 写**"验证意图"注释**（说明设计规则、何时会 fire），防止逻辑写反 | code review                              |
| 7 | B 为每个 covergroup 写**≥2 行说明注释**（覆盖目标、关键 bin 含义）                   | code review                              |

---

### Phase 8 — Virtual Sequence 实现（B 独立完成）

| 工程师      | 工作内容                                                                                                                            | 文件数      |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **B** | `mmu_virtual_sequencer.svh` + `mmu_vseq_lib.svh`（14 个 vseq 的 `body()` 全实现，参考 VerificationPlan §6.3 功能点对应关系） | **2** |
| **A** | Review vseq 对 ref_model/SB API 的调用正确性                                                                                        | —          |

**退出准则**：

| # | 检查项                                                                                               | 验证方式               |
| - | ---------------------------------------------------------------------------------------------------- | ---------------------- |
| 1 | `make compile` **0 errors**                                                                  | 编译 log               |
| 2 | 14 个 vseq**各跑 3 个种子**，UVM_ERROR=0 / SVA fail=0 / 全部 SB mismatch=0                     | 仿真 log × 42 份      |
| 3 | 每个 vseq 运行后输出统计摘要：**txn 总数、miss 次数、PTW 调用次数**（任何一项为 0 须说明原因） | 仿真 log 中统计打印    |
| 4 | A**签字 Review**：vseq 对 `ref_model` / SB API 的调用符合 Phase 4 冻结的接口约定             | Review 记录留存        |
| 5 | B 提交**vseq ↔ VerificationPlan §6.3 功能点对应映射表**（14 行，每行注明覆盖的 F 编号）      | 文档或 vseq 文件头注释 |

---

### Phase 9 — 测试用例填充（B 主导，A Review）

| 工程师      | 工作内容                                                                                                                                                                                                                                                                                                                                              | 文件数          |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| **B** | 按 VerificationPlan §6.3 TC 详表逐条创建 test class（每个 test < 50 行：1–N vseq + 环境配置 + num_txn）；覆盖 `basic_tests/` `l1itlb_tests/` `l1dtlb_tests/` `l2tlb_tests/` `ptw_tests/` `tlbop_tests/` `pmp_tests/` `sysmap_tests/` `cp0_tests/` `flush_tests/` `cross_tests/` `perf_tests/` `err_tests/` 共 13 个子目录 | **≈120** |
| **A** | Review pmp_tests / sysmap_tests / ptw_tests 中涉及参考模型精度的测试用例                                                                                                                                                                                                                                                                              | —              |

**退出准则**：

| # | 检查项                                                                                                     | 验证方式                       |
| - | ---------------------------------------------------------------------------------------------------------- | ------------------------------ |
| 1 | `make compile` **0 errors**，**所有 ~120 个 test class 全部编译通过**                        | 编译 log 无 undefined class    |
| 2 | 所有 test**seed=1 单跑**：UVM_ERROR=0 / SVA fail=0                                                   | 仿真 log 全量截图              |
| 3 | smoke 冒烟列表**3 个种子**各跑，**100% 通过**                                                  | 回归报告 × 3                  |
| 4 | test 内**禁止硬编码 `#XXXXXX` 超时**（一律使用 UVM timeout 机制），由 A review 确认                | code review                    |
| 5 | `scan_logs.pl` 扫描全部 log：**无 unknown error pattern**                                          | 脚本输出 0 unrecognized errors |
| 6 | A**Review** pmp_tests / sysmap_tests / ptw_tests 中涉及参考模型精度的用例，**Review 注释留存** | code review 记录               |

---

### Phase 10 — 回归脚本 + 覆盖率收敛（A 主导）

| 工程师      | 工作内容                                                                                                                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | 添加 Makefile `regress` target；更新 `scripts/cov_hier.cfg`（改 DUT 路径前缀为 `u_dut`）；裁剪 `scripts/run_test.py`（改默认 TEST_NAME）；裁剪 `scripts/run_vcs_verdi.py`（改 top module + Files.f 路径） |
| **B** | 整理 `simu/mmu_smoke_list` / `mmu_nightly_list` / `mmu_coverage_list`（内容参照 VerificationPlan §8）；编写 `simu/exclude.do` 覆盖率豁免条目                                                               |

**退出准则**：

| # | 检查项                                                                                         | 验证方式              |
| - | ---------------------------------------------------------------------------------------------- | --------------------- |
| 1 | `make regress_smoke` **0 errors**，smoke 列表 100% 通过                                | 回归报告              |
| 2 | `make regress_nightly` **≥50% 用例通过**，输出覆盖率初始值（用于基线比对）            | 回归报告 + 覆盖率截图 |
| 3 | 签核标准（VerificationPlan §9）**逐项形成书面清单**（Pass / Fail / Waiver 状态明确）    | 签核清单文件          |
| 4 | `cov_hier.cfg` `u_dut` 前缀在 VCS 报告中**正确显示 DUT 层次**                        | HTML 报告截图         |
| 5 | `run_test.py` 能接受 `TEST_NAME` / `SEED` / `PLUS_ARGS` 参数，**命令行测试通过** | 命令行测试记录        |
| 6 | `exclude.do` **所有豁免条目须有注释**说明豁免理由（不允许无注释豁免）                  | code review           |
| 7 | B 提交三份回归列表（smoke / nightly / coverage），A**Review 完整性**后签字               | Review 记录           |

---

### Phase 11 — v3.0 Gap-driven 回归（B 主导）

| 工程师      | 工作内容                                                                                                                                                                                                                    |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **B** | 补充 `bug_hunt_tests/`（TC-BUG-005~008, 011~015）；补充 `ptw_lsu_protocol_tests/`（5 个 `tc_pmbuf_*` 用例 F4.42a/b/c）；整理 `simu/mmu_bug_hunt_list` / `mmu_ptw_lsu_protocol_list` / `mmu_v3_regression_list` |
| **A** | 添加 Makefile `regress_v3_gap` target；配合 JIRA 联动：R19 `tc_bug_011` 设置 `xfail`；R20 SVA 保护确认                                                                                                                |

**退出准则**：

| # | 检查项                                                                                         | 验证方式              |
| - | ---------------------------------------------------------------------------------------------- | --------------------- |
| 1 | R19 /`tc_bug_011`：须有 **JIRA 关闭截图**或正式关闭记录（不允许仅口头确认）            | JIRA 截图存档         |
| 2 | R20：**10 个种子**分别验证，SVA / covergroup **全部无 fire**                       | 仿真 log × 10 份     |
| 3 | `mmu_v3_regression_list` **3 个种子**跑，输出**回归通过率报告**                  | 回归报告 × 3         |
| 4 | `tc_bug_005~008` / `tc_bug_011~015` **每条单独运行通过**，0 UVM_ERROR                | 仿真 log 全量         |
| 5 | `tc_pmbuf_*` 5 个用例（F4.42a/b/c）各 **3 个种子**通过                                 | 仿真 log × 15 份     |
| 6 | Makefile `regress_v3_gap` target **集成 `scan_logs.pl` 自动检查**，确保无 error 漏过 | make 输出中有扫描结果 |

---

### Phase 12 — MAEE / PTW-ready / TWU bypass 验证（B 主导，A Review SVA）

| 工程师      | 工作内容                                                                                                                                                |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **B** | `testbench/test/maee_twu_tests/` 4 个 TC；`ptw_tests/` 扩充（F4.NEW.6–11, F5.16 共 16+ TC）；对应 covergroup（9 个）；`simu/mmu_v4_phase12_list` |
| **A** | `testbench/top/mmu_maee_twu_sva.sv`（3 条 SVA）；`testbench/top/mmu_pmp_twu_sva.sv` 骨架；Makefile `regress_v4_maee_ptw` target                   |

**退出准则**：

| # | 检查项                                                                                          | 验证方式                 |
| - | ----------------------------------------------------------------------------------------------- | ------------------------ |
| 1 | Phase 12 列表**3 个种子**，**100% 通过**                                            | 回归报告 × 3            |
| 2 | 每条 SVA property 至少触发**20 次**（`cover property` 统计 > 0 证明路径可达，非空验证） | 仿真 log 中 cover 统计   |
| 3 | `mmu_maee_twu_sva.sv` 3 条 SVA **各有对应 `cover property`**                          | code review              |
| 4 | `mmu_pmp_twu_sva.sv` 骨架**编译通过，无 undefined reference**                           | 编译 log                 |
| 5 | 见下表：**9 个**白盒 covergroup 在 Phase 12 合并 URG 报告中**各自 SCORE ≥ 50%**（默认阈值 `PHASE12_CG_MIN_PERCENT`，由 `scripts/phase12_cov_gate.py` 校验） | `make phase12_exit_check` 或 URG `groups.txt` / `groups.html` |
| 6 | B 提交**MAEE / PTW-ready / TWU bypass 场景矩阵**（每个特性 ≥3 个变量维度）               | 场景矩阵文档 / vseq 注释 |

**退出准则 #5 — 9 个 covergroup（与 `mmu_verification/scripts/phase12_exit_check.sh` 中 `PHASE12_CGS`、`doc/phase12_covergroup_matrix.md` 一致）**：

| 序号 | Covergroup（位于 `mmu_env_cg_whitebox`） |
| -: | --- |
| 1 | `cg_ptw_ready_transition` |
| 2 | `cg_twu_idle_vs_mask_state` |
| 3 | `cg_xbar_hit_level` |
| 4 | `cg_twu_except_while_arb_busy` |
| 5 | `cg_twu_data_ready_per_stage` |
| 6 | `cg_arb_grant_type` |
| 7 | `cg_ptw_arb_pgs_type` |
| 8 | `cg_maee_leaf_level` |
| 9 | `cg_maee_path` |

**说明**：URG「Testbench Group List」中的 **Total groups SCORE**（全量 testbench 约 30 个 group 的总分）**不作为** Phase 12 签核指标；签核仅针对上表 **9 个** covergroup 的各自百分比。自动化收口：`mmu_verification` 下执行 **`make phase12_exit_check`**（串起 `run_cov` 回归、`make cov`、summary 与 `phase12_cov_gate.py`）。

---

### Phase 13 — sysmap / PMP-deny / PMP-port 验证（B 主导，A Review SVA）

| 工程师      | 工作内容                                                                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **B** | `pmp_twu_tests_v6/` 15+ TC；`sysmap_tests/` 扩充 8+ TC；对应 covergroup（13 个）；`simu/mmu_v4_phase13_list`                                                  |
| **A** | 补全 `testbench/top/mmu_pmp_twu_sva.sv`；新增 `testbench/top/mmu_sysmap_sva.sv`（3 条 SVA）；Makefile `regress_v4_sysmap_pmp` target；DA-003 端口映射确认跟踪 |

**退出准则**：

| # | 检查项                                                                                   | 验证方式               |
| - | ---------------------------------------------------------------------------------------- | ---------------------- |
| 1 | Phase 13 列表**3 个种子**，**100% 通过**                                     | 回归报告 × 3          |
| 2 | 每条 SVA property 至少触发**20 次**（`cover property` 统计 > 0 证明路径可达）    | 仿真 log 中 cover 统计 |
| 3 | `mmu_sysmap_sva.sv` 3 条 SVA **各有对应 `cover property`**                     | code review            |
| 4 | `mmu_pmp_twu_sva.sv` **完整实现**，所有 property 语法正确，编译 0 errors         | 编译 log               |
| 5 | 13 个 covergroup 在 Phase 13 测试中**每个至少 50% bin 命中**                       | 覆盖率 HTML 报告       |
| 6 | DA-003 须有**书面记录**（关闭凭证 / 正式 waiver 文档），**不允许仅口头确认** | 文档存档 / JIRA 截图   |

---

### Phase 14 — 全量回归收敛与签核（A 主导，B 配合）

| 工程师      | 工作内容                                                                                                                                                                            |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | `simu/mmu_v4_full_regression_list`（Union Phase 1–13）；`simu/mmu_v4_coverage_merge.sh`；`simu/exclude_v4.do`（新增豁免）；Makefile `regress_v4_full` target；签核矩阵更新 |
| **B** | 补充覆盖率闭合（随机种子扩充 + 漏洞修补 TC）；整理 JIRA 状态（DA-003 / R19 / R20 全部关闭或 waiver）                                                                                |

**退出准则**：

| # | 检查项                                                                                                                   | 验证方式         |
| - | ------------------------------------------------------------------------------------------------------------------------ | ---------------- |
| 1 | 全量列表**5 个种子**，**100% 通过**（DA-003 waiver 除外，须有书面豁免记录）                                  | 回归报告 × 5    |
| 2 | 覆盖率**数字化列出**：line coverage ≥95%，toggle coverage ≥90%（或 VerificationPlan §9 中实际指标，以严者为准） | 覆盖率报告截图   |
| 3 | `mmu_v4_coverage_merge.sh` **实际运行成功**，生成合并覆盖率报告                                                  | 报告文件路径记录 |
| 4 | `exclude_v4.do` 所有豁免条目**引用 JIRA 编号**（格式：`// JIRA-XXX: <原因>`）                                  | code review      |
| 5 | 签核矩阵**所有条目 Pass / Waiver 无空白**，无任何未决状态                                                          | 签核矩阵文件     |
| 6 | JIRA**DA-003 / R19 / R20 全部关闭**或有正式 waiver 文档（不允许未解决状态合并）                                    | JIRA 截图存档    |
| 7 | A + B**双方在签核矩阵上 Git commit 留存签字**（commit message 含 `sign-off` 字样）                               | Git log          |

---

## 4. 关键依赖关系图

```
Phase 1 (A)
    └── Phase 2 (A主, B-review) ──┐
                                   │
        ┌──────────────────────────┘
        │
    Phase 3 (A: cp0/pmp/sysmap) ←→ Phase 3 (B: ifu/lsu 骨架)
        │                               │
    Phase 4 (A: ptw_mem + refmodel)     │
        │                               │
    Phase 5 (A: misc+creditSB) ←────── Phase 5 (B: ifu/lsu方法体 + translationSB)
        │                               │
    Phase 6 (A: misc完善) ←─────────── Phase 6 (B: inv子线程 + invalidateSB)
        │                               │
    Phase 7 (A: SVA) ←──────────────── Phase 7 (B: Covergroup)
        │                               │
        └───────────── Phase 8 (B: vseq) ─────┐
                                               │
                                    Phase 9 (B: 测试用例)
                                               │
              Phase 10 (A: 回归脚本) ←─────── Phase 10 (B: 回归列表)
                           │
                      Phase 11 (B: gap TC)
                           │
                      Phase 12 (B: TC, A: SVA)
                           │
                      Phase 13 (B: TC, A: SVA)
                           │
                      Phase 14 (A主, B配合)
```

---

## 5. 工作量估算

| 工程师      | 负责 Phase                                                                                                        | 主要文件数           | 重点难点                                                                           |
| ----------- | ----------------------------------------------------------------------------------------------------------------- | -------------------- | ---------------------------------------------------------------------------------- |
| **A** | Phase 1/2/3(cp0+pmp+sysmap)/4/5(misc+creditSB)/6(misc补)/7(SVA)/10(脚本)/12(SVA)/13(SVA)/14                       | ≈**110 文件** | ref_model 翻译算法精度；credit_sb 容量守恒逻辑；SVA 形式化约束正确性               |
| **B** | Phase 3(ifu+lsu骨架)/5(ifu+lsu方法体+translationSB)/6(inv)/7(cg)/8(vseq)/9(测试用例)/10(列表)/11/12(TC)/13(TC)/14 | ≈**200 文件** | lsu_driver 5 子线程并发驱动；translation_sb VA→PA 对比精度；120+ 测试用例场景覆盖 |

---

## 6. 代码协作约定

| 约定                       | 细节                                                                                                            |
| -------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **分支策略**         | `main` 保持可编译；每人在 `feat/engineer-a` / `feat/engineer-b` 分支开发，每个 Phase 退出时 merge         |
| **Interface 冻结**   | Phase 2 结束后，任何 `*_if.sv` 修改需双方 Sign-off，避免下游 driver/monitor 连锁改动                          |
| **共享 API**         | `page_table_builder` / `mmu_ref_model` 的公开方法签名由 A 冻结后通知 B；B 不得在未协商情况下修改 A 的工具类 |
| **UVM_ERROR 零容忍** | 每个 Phase 的退出准则均要求 0 UVM_ERROR；不允许带 error 合并到 main                                             |
| **日报同步**         | 每天结束时双方各更新本 Phase 的"已完成文件列表"与"当前 blocker"，共享到项目文档区                               |

---

## 附录：文件归属速查

### 工程师 A 负责文件

```
mmu_verification/
├── Makefile
├── setup_env.sh / setup_env.csh
├── modules/dv_utils/               (整块复制)
├── modules/mmu_params/
│   └── mmu_params_pkg.sv
├── scripts/                        (整块复制 + 裁剪)
└── testbench/
    ├── Files.f
    ├── common/mmu_common_pkg.sv
    ├── cp0_agent/           (9 文件)
    ├── pmp_agent/           (9 文件)
    ├── sysmap_cfg_agent/    (9 文件)
    ├── ptw_mem_agent/       (10 文件 + page_table_builder)
    ├── misc_agent/          (9 文件)
    ├── env/
    │   ├── mmu_env_pkg.sv
    │   ├── mmu_top_cfg.svh
    │   ├── mmu_page_table_mem.svh
    │   ├── mmu_ref_model.svh
    │   ├── mmu_credit_sb.svh
    │   └── mmu_env.svh      (持续更新)
    ├── top/
    │   ├── tb_top.sv
    │   ├── mmu_sva.sv
    │   ├── mmu_arb_sva.sv
    │   ├── mmu_l2tlb_rrpv_sva.sv
    │   ├── mmu_plru_sva.sv
    │   ├── credit_sva.sv
    │   ├── mmu_maee_twu_sva.sv     (Phase 12)
    │   ├── mmu_pmp_twu_sva.sv      (Phase 13)
    │   └── mmu_sysmap_sva.sv       (Phase 13)
    └── simu/
        └── (Makefile targets 由 A 维护)
```

### 工程师 B 负责文件

```
testbench/
├── ifu_agent/           (9 文件)
├── lsu_agent/           (9 文件，含 drive_inv 子线程)
├── env/
│   ├── mmu_translation_sb.svh
│   ├── mmu_invalidate_sb.svh
│   ├── mmu_perf_mon.svh
│   ├── mmu_virtual_sequencer.svh
│   └── mmu_vseq_lib.svh
├── test/
│   ├── test_pkg.sv
│   ├── test_base.svh
│   ├── basic_tests/     (~3 文件)
│   ├── l1itlb_tests/
│   ├── l1dtlb_tests/
│   ├── l2tlb_tests/
│   ├── ptw_tests/
│   ├── tlbop_tests/
│   ├── pmp_tests/
│   ├── sysmap_tests/
│   ├── cp0_tests/
│   ├── flush_tests/
│   ├── cross_tests/
│   ├── perf_tests/
│   ├── err_tests/
│   ├── bug_hunt_tests/          (Phase 11)
│   ├── ptw_lsu_protocol_tests/  (Phase 11)
│   ├── maee_twu_tests/          (Phase 12)
│   └── pmp_twu_tests_v6/        (Phase 13)
└── simu/
    ├── run.do
    ├── WAVES.do
    ├── exclude.do
    ├── mmu_smoke_list
    ├── mmu_nightly_list
    ├── mmu_coverage_list
    ├── mmu_bug_hunt_list        (Phase 11)
    ├── mmu_ptw_lsu_protocol_list (Phase 11)
    ├── mmu_v3_regression_list   (Phase 11)
    ├── mmu_v4_phase12_list      (Phase 12)
    └── mmu_v4_phase13_list      (Phase 13)
```

> 所有 `*_covergroups.svh`（ifu/lsu/cp0/ptw_mem/pmp/sysmap_cfg/misc）均由 **B** 负责，放在对应 agent 目录下，但在 Phase 7 统一编译验证。
