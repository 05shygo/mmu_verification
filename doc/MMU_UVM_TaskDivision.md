# MMU UVM 环境搭建 — 双人分工计划

> **基准文档**：[MMU_UVM_BuildPlan_v3_final.md](MMU_UVM_BuildPlan_v3_final.md)
> **验证计划**：[MMU_VerificationPlan_final.md](MMU_VerificationPlan_final.md)
> **日期**：2026-04-23
> **人员**：工程师 A（基础架构）、工程师 B（激励与覆盖率）

---

## 1. 分工原则

| 原则 | 说明 |
|------|------|
| **按职责层切分** | A 负责**编译骨架、响应侧 Agent、参考模型、SVA**；B 负责**主动激励 Agent、Covergroup、Vseq、测试用例** |
| **严格串行 Phase 边界** | Phase 1→2→3→4→5→… 串行推进；A 完成当前 Phase 退出准则后，B 才能进入依赖该成果的下一步 |
| **Phase 1–2 由 A 主导** | Phase 1（骨架）、Phase 2（Interface + DUT 接入）由 A 完成；B 在 Phase 2 期间同步阅读 RTL 端口 + 熟悉框架 |
| **Phase 3 并行切入** | Phase 2 退出后，A 和 B **同步进入**各自负责的 Agent 开发，不再强制串行 |
| **接口约定先行** | B 依赖 A 提供的 Interface（.sv）和 Package；两人在 Phase 2 结束时对全部 Interface 端口签名做 Code Review 后冻结 |

---

## 2. 整体分工总表

| 模块 / 交付物 | 负责人 | 依赖（前置 Phase） |
|---|---|---|
| **目录骨架、Makefile、setup_env** | A | — |
| **tb_top.sv（时钟+复位框架）** | A | — |
| **7 个 \*_if.sv（Interface）** | A 主写，B Review | Phase 1 |
| **DUT 接入 + uvm_config_db 连线** | A | Phase 1 |
| **mmu_params_pkg.sv** | A | Phase 1 |
| **mmu_common_pkg.sv**（PTE 工具函数骨架） | A | Phase 1 |
| **cp0_agent** 八件套 | A | Phase 2 |
| **pmp_agent** 八件套 | A | Phase 2 |
| **sysmap_cfg_agent** 八件套 | A | Phase 2 |
| **ptw_mem_agent** 十件套 + page_table_builder | A | Phase 3 |
| **mmu_page_table_mem.svh** | A | Phase 4 |
| **mmu_ref_model.svh** | A | Phase 4 |
| **mmu_credit_sb.svh** | A | Phase 5 |
| **mmu_top_cfg.svh** | A | Phase 2 |
| **mmu_env.svh** | A（骨架） → 双方持续补充 | Phase 3 |
| **mmu_virtual_sequencer.svh** | B | Phase 5 |
| **misc_agent** 八件套 | A | Phase 5 |
| **ifu_agent** 八件套 | B | Phase 3 |
| **lsu_agent** 八件套（含 5 子线程 driver） | B | Phase 3 |
| **mmu_translation_sb.svh** | B | Phase 5 |
| **mmu_invalidate_sb.svh** | B | Phase 5 |
| **mmu_perf_mon.svh** | B | Phase 5 |
| **全部 \*_covergroups.svh（7 个 Agent）** | B | Phase 5 |
| **env 内白盒 covergroup 集中文件** | B | Phase 6 |
| **5 个 SVA .sv 文件（top/）** | A | Phase 6 |
| **mmu_vseq_lib.svh（14 个 vseq）** | B | Phase 7 |
| **test_pkg.sv + test_base.svh** | B（A Review） | Phase 7 |
| **全部测试用例（~120 个 .svh）** | B | Phase 8 |
| **回归列表（smoke/nightly/coverage）** | B | Phase 9 |
| **simu/exclude.do 覆盖率豁免** | B | Phase 9 |
| **Makefile 回归 target（regress_*）** | A | Phase 9 |
| **Gap-driven TC（Phase 11）** | B | Phase 10 |
| **MAEE / PTW-ready / TWU 验证 TC + SVA（Phase 12）** | B（SVA 由 A 审查） | Phase 11 |
| **sysmap / PMP-deny / PMP-port TC + SVA（Phase 13）** | B（SVA 由 A 审查） | Phase 12 |
| **全量回归 + 覆盖率合并脚本（Phase 14）** | A 主导，B 配合 | Phase 13 |

---

## 3. 按 Phase 的具体分工

### Phase 1 — 环境骨架（A 独立完成）

| 工程师 | 工作内容 |
|--------|---------|
| **A** | 创建 `mmu_verification/` 目录结构；复制 `dv_utils`（写 VERSION.txt）；复制 `scripts/`；裁剪 Makefile；写最简 `tb_top.sv`（仅时钟 + `run_test()`）；写空 `testbench/Files.f` |
| **B** | 并行阅读 `MMU_UVM_BuildPlan_v3_final.md` §2–§7；熟悉 hpdcache_agent 八件套结构；列出 ifu_agent / lsu_agent 信号清单草稿 |

**退出准则（A 验证）**：`make compile` + `make run` 通过，0 cycle 退出无错

---

### Phase 2 — DUT 接入与 Interface 连接（A 主导，B Review）

| 工程师 | 工作内容 |
|--------|---------|
| **A** | 写 `mmu_params_pkg.sv`；写 `mmu_common_pkg.sv` 骨架（函数签名，方法体 TODO）；写全部 7 个 `*_if.sv`；更新 `tb_top.sv` 接入 DUT + 所有 interface + `uvm_config_db::set`；更新 `Files.f` 加入 RTL + interface |
| **B** | Review 7 个 interface 端口完整性（对照 §2.4 端口分组表）；确认 `lsu_if.sv` 5 子分组（pipe0/1/2/stamo/inv）信号无遗漏；Review `mmu_params_pkg.sv` Sv39 参数 |

**Phase 2 结束时双方 Code Review 冻结全部 Interface**

**退出准则**：`make compile` DUT elaboration 无错；`make run` 空 test 退出正常

---

### Phase 3 — 最简 Active Agent + Sanity Test（A/B 并行）

| 工程师 | 工作内容 | 文件数 |
|--------|---------|-------|
| **A** | `cp0_agent` 八件套（driver 实现最简 CSR 写）；`pmp_agent` 八件套（driver 实现 8 端口 flag 驱动）；`sysmap_cfg_agent` 八件套（白盒 force/release）；`mmu_env_pkg.sv` 骨架；`mmu_top_cfg.svh`；`mmu_env.svh`（仅 build 这三个 agent） | 3×9+3 = **30** |
| **B** | `ifu_agent` 八件套（driver 方法体 TODO，先完成 txn/sequencer/monitor/agent 骨架）；`lsu_agent` 八件套（同上，5 子分组 interface clocking block 确认）；写 `test_pkg.sv` + `test_base.svh` | 2×9+2 = **20** |

> B 的 ifu/lsu agent 骨架在 Phase 3 完成，方法体在 Phase 5 填充。

**退出准则（A 主导）**：`test_mmu_sanity_csr_pmp_sysmap`（由 A 编写）通过；`mmu_xx_mmu_en` 拉高

---

### Phase 4 — PTW 内存模型 + 参考模型（A 独立完成）

| 工程师 | 工作内容 | 文件数 |
|--------|---------|-------|
| **A** | `ptw_mem_agent` 十件套（responder 完整实现：PTE 响应 + 延迟 + bus_error 注入）；`page_table_builder.svh`（`map_4k()` 等工具方法）；`mmu_page_table_mem.svh`（基于 memory_shadow）；`mmu_ref_model.svh`（`translate()` 4K happy path） | 10+3 = **13** |
| **B** | 基于 A 的 `page_table_builder` API 草拟 ifu/lsu sequence 伪代码；准备 Phase 5 的 translation 场景列表（来自 VerificationPlan §6.3 F1/F2/F3 功能点） | — |

**退出准则（A 验证）**：`page_table_builder.map_4k()` → `ptw_mem_responder` 正确响应；ref_model `translate()` 结果与 RTL PA 一致

---

### Phase 5 — IFU + LSU Agent + Translation SB（B 主导）

| 工程师 | 工作内容 | 文件数 |
|--------|---------|-------|
| **B** | 填充 `ifu_driver.svh` + `ifu_monitor.svh` 方法体；填充 `lsu_driver.svh`（`drive_pipe0/1/2/stamo` 四路，inv 子线程留 TODO 至 Phase 6）+ `lsu_monitor.svh`（4 个 ap）；实现 `mmu_translation_sb.svh`（VA→PA + 异常对比）；更新 `mmu_env.svh` 加入 ifu/lsu 两个 agent | 5（新增/修改） |
| **A** | `misc_agent` 八件套骨架（driver 实现 `rtu_flush` 单脉冲 + `biu_smp_disable` 静态配置）；`mmu_credit_sb.svh`（L1↔L2 credit / ReqQ / MB 容量守恒）；`mmu_perf_mon.svh` 骨架（接口定义，统计 TODO）；更新 `mmu_env.svh` 加入 misc/credit | 9+3 = **12** |

**退出准则**：IFU 单端口随机 VA 100 次全部命中；LSU pipe0 100 次 LD 全部命中；miss→PTW→refill 100 次混合 0 mismatch

---

### Phase 6 — misc_agent 完善 + TLB 失效 + Invalidate SB（B 主导，A 配合）

| 工程师 | 工作内容 |
|--------|---------|
| **B** | 实现 `lsu_driver.svh` 的 `drive_inv` 子线程（SFENCE.VMA 4 种模式）；实现 `mmu_invalidate_sb.svh`；编写对应的 invalidate sequence（可放入 `lsu_sequences.svh`） |
| **A** | 完善 `misc_agent` driver 中的 RTU flush/expt 注入逻辑；完善 `misc_monitor.svh` 中 HPCP cnt_en 采样 |

**退出准则**：SFENCE.VMA 4 种模式各 50 次，invalidate_sb 0 mismatch；RTU flush 下 PTW abort 行为正确

---

### Phase 7 — Covergroup + SVA bind（A/B 并行）

| 工程师 | 工作内容 | 文件数 |
|--------|---------|-------|
| **B** | 7 个 `*_covergroups.svh`（覆盖 BuildPlan §10 黑盒部分）；env 内白盒 covergroup 集中文件（hierarchical reference）；更新 `mmu_env.svh` 注册所有 covergroup | 7+1 = **8** |
| **A** | 5 个 SVA 文件（`mmu_sva.sv` / `mmu_arb_sva.sv` / `mmu_l2tlb_rrpv_sva.sv` / `mmu_plru_sva.sv` / `credit_sva.sv`）；更新 `tb_top.sv` 加入 bind 语句 | **5** |

**退出准则**：编译通过；smoke 测试所有 covergroup 至少 1 hit；SVA 0 fire

---

### Phase 8 — Virtual Sequence 实现（B 独立完成）

| 工程师 | 工作内容 | 文件数 |
|--------|---------|-------|
| **B** | `mmu_virtual_sequencer.svh` + `mmu_vseq_lib.svh`（14 个 vseq 的 `body()` 全实现，参考 VerificationPlan §6.3 功能点对应关系） | **2** |
| **A** | Review vseq 对 ref_model/SB API 的调用正确性 | — |

**退出准则**：14 个 vseq 各运行一次，0 UVM_ERROR / 0 SVA fail / 全部 SB 0 mismatch

---

### Phase 9 — 测试用例填充（B 主导，A Review）

| 工程师 | 工作内容 | 文件数 |
|--------|---------|-------|
| **B** | 按 VerificationPlan §6.3 TC 详表逐条创建 test class（每个 test < 50 行：1–N vseq + 环境配置 + num_txn）；覆盖 `basic_tests/` `l1itlb_tests/` `l1dtlb_tests/` `l2tlb_tests/` `ptw_tests/` `tlbop_tests/` `pmp_tests/` `sysmap_tests/` `cp0_tests/` `flush_tests/` `cross_tests/` `perf_tests/` `err_tests/` 共 13 个子目录 | **≈120** |
| **A** | Review pmp_tests / sysmap_tests / ptw_tests 中涉及参考模型精度的测试用例 | — |

**退出准则**：所有 test 单跑通过；冒烟列表 100% 通过

---

### Phase 10 — 回归脚本 + 覆盖率收敛（A 主导）

| 工程师 | 工作内容 |
|--------|---------|
| **A** | 添加 Makefile `regress` target；更新 `scripts/cov_hier.cfg`（改 DUT 路径前缀为 `u_dut`）；裁剪 `scripts/run_test.py`（改默认 TEST_NAME）；裁剪 `scripts/run_vcs_verdi.py`（改 top module + Files.f 路径） |
| **B** | 整理 `simu/mmu_smoke_list` / `mmu_nightly_list` / `mmu_coverage_list`（内容参照 VerificationPlan §8）；编写 `simu/exclude.do` 覆盖率豁免条目 |

**退出准则**：参照 VerificationPlan §9 签核标准逐项评估

---

### Phase 11 — v3.0 Gap-driven 回归（B 主导）

| 工程师 | 工作内容 |
|--------|---------|
| **B** | 补充 `bug_hunt_tests/`（TC-BUG-005~008, 011~015）；补充 `ptw_lsu_protocol_tests/`（5 个 `tc_pmbuf_*` 用例 F4.42a/b/c）；整理 `simu/mmu_bug_hunt_list` / `mmu_ptw_lsu_protocol_list` / `mmu_v3_regression_list` |
| **A** | 添加 Makefile `regress_v3_gap` target；配合 JIRA 联动：R19 `tc_bug_011` 设置 `xfail`；R20 SVA 保护确认 |

**退出准则**：R19 关闭或 `tc_bug_011` pass；R20 SVA/cg 无 fire；`mmu_v3_regression_list` 通过率 100%

---

### Phase 12 — MAEE / PTW-ready / TWU bypass 验证（B 主导，A Review SVA）

| 工程师 | 工作内容 |
|--------|---------|
| **B** | `testbench/test/maee_twu_tests/` 4 个 TC；`ptw_tests/` 扩充（F4.NEW.6–11, F5.16 共 16+ TC）；对应 covergroup（9 个）；`simu/mmu_v4_phase12_list` |
| **A** | `testbench/top/mmu_maee_twu_sva.sv`（3 条 SVA）；`testbench/top/mmu_pmp_twu_sva.sv` 骨架；Makefile `regress_v4_maee_ptw` target |

**退出准则**：Phase 12 列表通过率 100%；MAEE + PTW-ready + TWU-bypass SVA 无 fire

---

### Phase 13 — sysmap / PMP-deny / PMP-port 验证（B 主导，A Review SVA）

| 工程师 | 工作内容 |
|--------|---------|
| **B** | `pmp_twu_tests_v6/` 15+ TC；`sysmap_tests/` 扩充 8+ TC；对应 covergroup（13 个）；`simu/mmu_v4_phase13_list` |
| **A** | 补全 `testbench/top/mmu_pmp_twu_sva.sv`；新增 `testbench/top/mmu_sysmap_sva.sv`（3 条 SVA）；Makefile `regress_v4_sysmap_pmp` target；DA-003 端口映射确认跟踪 |

**退出准则**：Phase 13 列表通过率 100%；PMP + sysmap SVA 无 fire；DA-003 已确认或有 workaround

---

### Phase 14 — 全量回归收敛与签核（A 主导，B 配合）

| 工程师 | 工作内容 |
|--------|---------|
| **A** | `simu/mmu_v4_full_regression_list`（Union Phase 1–13）；`simu/mmu_v4_coverage_merge.sh`；`simu/exclude_v4.do`（新增豁免）；Makefile `regress_v4_full` target；签核矩阵更新 |
| **B** | 补充覆盖率闭合（随机种子扩充 + 漏洞修补 TC）；整理 JIRA 状态（DA-003 / R19 / R20 全部关闭或 waiver） |

**退出准则**：全量列表通过率 100%（DA-003 waiver 除外）；覆盖率达 VerificationPlan §9 签核标准；签核矩阵最终更新

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

| 工程师 | 负责 Phase | 主要文件数 | 重点难点 |
|--------|-----------|-----------|---------|
| **A** | Phase 1/2/3(cp0+pmp+sysmap)/4/5(misc+creditSB)/6(misc补)/7(SVA)/10(脚本)/12(SVA)/13(SVA)/14 | ≈ **110 文件** | ref_model 翻译算法精度；credit_sb 容量守恒逻辑；SVA 形式化约束正确性 |
| **B** | Phase 3(ifu+lsu骨架)/5(ifu+lsu方法体+translationSB)/6(inv)/7(cg)/8(vseq)/9(测试用例)/10(列表)/11/12(TC)/13(TC)/14 | ≈ **200 文件** | lsu_driver 5 子线程并发驱动；translation_sb VA→PA 对比精度；120+ 测试用例场景覆盖 |

---

## 6. 代码协作约定

| 约定 | 细节 |
|------|------|
| **分支策略** | `main` 保持可编译；每人在 `feat/engineer-a` / `feat/engineer-b` 分支开发，每个 Phase 退出时 merge |
| **Interface 冻结** | Phase 2 结束后，任何 `*_if.sv` 修改需双方 Sign-off，避免下游 driver/monitor 连锁改动 |
| **共享 API** | `page_table_builder` / `mmu_ref_model` 的公开方法签名由 A 冻结后通知 B；B 不得在未协商情况下修改 A 的工具类 |
| **UVM_ERROR 零容忍** | 每个 Phase 的退出准则均要求 0 UVM_ERROR；不允许带 error 合并到 main |
| **日报同步** | 每天结束时双方各更新本 Phase 的"已完成文件列表"与"当前 blocker"，共享到项目文档区 |

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
