# MMU UVM 验证环境 — 任务进度表

> **项目**：OpenRiscv2030 MMU UVM Verification
> **文档**：基于 [MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md)
> **更新**：2026-04-23
> **状态说明**：✅ 完成 | 🔄 进行中 | ⏳ 未开始 | 🔒 等待解锁

---

## 整体进度概览

| Phase | 名称 | 负责人 | 状态 | 退出准则达成 |
|-------|------|--------|------|------------|
| **Phase 1** | 环境骨架 | A | ✅ 完成 | ✅ `make compile` + `make run` 通过，0 cycle 退出无错 |
| **Phase 2** | DUT 接入 + Interface | A 主，B Review | ⏳ 未开始 | — |
| **Phase 3** | 最简 Active Agent + Sanity Test | A/B 并行 | 🔒 等待 Phase 2 | — |
| **Phase 4** | PTW 内存模型 + 参考模型 | A | 🔒 等待 Phase 3 | — |
| **Phase 5** | IFU + LSU Agent + Translation SB | B 主，A 配合 | 🔒 等待 Phase 4 | — |
| **Phase 6** | misc_agent 完善 + TLB 失效 + Invalidate SB | B 主，A 配合 | 🔒 等待 Phase 5 | — |
| **Phase 7** | Covergroup + SVA bind | A/B 并行 | 🔒 等待 Phase 6 | — |
| **Phase 8** | Virtual Sequence 实现 | B | 🔒 等待 Phase 7 | — |
| **Phase 9** | 测试用例填充（~120个）| B 主，A Review | 🔒 等待 Phase 8 | — |
| **Phase 10** | 回归脚本 + 覆盖率收敛 | A 主，B 配合 | 🔒 等待 Phase 9 | — |
| **Phase 11** | v3.0 Gap-driven 回归 | B 主，A 配合 | 🔒 等待 Phase 10 | — |
| **Phase 12** | MAEE / PTW-ready / TWU bypass 验证 | B 主，A Review SVA | 🔒 等待 Phase 11 | — |
| **Phase 13** | sysmap / PMP-deny / PMP-port 验证 | B 主，A Review SVA | 🔒 等待 Phase 12 | — |
| **Phase 14** | 全量回归收敛与签核 | A 主，B 配合 | 🔒 等待 Phase 13 | — |

---

## Phase 1 详细进度（✅ 已完成）

| 步骤 | 交付物 | 状态 | 备注 |
|------|--------|------|------|
| 1-A | 目录骨架创建 | ✅ | modules/scripts/testbench/7个agent目录/output |
| 1-B | 复制 dv_utils | ✅ | 4103 个文件，含 VERSION.txt |
| 1-C | 复制 scripts | ✅ | 21 个文件 |
| 1-D | `setup_env.sh` / `setup_env.csh` | ✅ | 含 CORE_V_VERIF、自动 PATH 扩展、加载 setup.local.* |
| 1-D+ | `setup.local.sh.example` / `setup.local.csh.example` | ✅ | 服务器差异配置模板，`.gitignore` 隔离 |
| 1-E | `Makefile` | ✅ | 基于 hpdcache 裁剪；CHECK_TEST_NAME 注释；CORE_V_VERIF 注入 |
| 1-F | `testbench/Files.f` | ✅ | Phase 1 最小版：仅 `-F ${CV_DV_UTILS_DIR}/uvm/Files.f` |
| 1-G | `testbench/top/tb_top.sv` | ✅ | 最小骨架：时钟 + `run_test()`，无 DUT |
| — | `.gitignore` | ✅ | 忽略 output/、setup.local.*、simv 等 |
| — | 编译验证 | ✅ | 服务器1 `make comp` 通过；服务器2（csh）`make comp` 通过 |
| — | 运行验证 | ✅ | `make run TEST_NAME=uvm_test_top` 0 cycle 退出无错 |

---

## Phase 2 任务清单（⏳ 待开始）

**负责**：工程师 A（主写）+ 工程师 B（Review）
**解锁条件**：Phase 1 退出准则已达成 ✅

| 步骤 | 交付物 | 负责人 | 状态 |
|------|--------|--------|------|
| 2-1 | `modules/mmu_params/mmu_params_pkg.sv`（Sv39 参数） | A | ⏳ |
| 2-2 | `testbench/common/mmu_common_pkg.sv`（PTE 工具函数骨架） | A | ⏳ |
| 2-3 | `testbench/common/mmu_top_cfg.svh` | A | ⏳ |
| 2-4 | 7 个 `*_if.sv`（ifu/lsu/cp0/ptw_mem/pmp/sysmap_cfg/misc） | A | ⏳ |
| 2-5 | `tb_top.sv` 更新：DUT 实例化 + interface + uvm_config_db | A | ⏳ |
| 2-6 | `testbench/Files.f` 更新：加入 RTL flist + interface | A | ⏳ |
| 2-7 | Code Review：7 个 interface 端口完整性 | B | ⏳ |

**退出准则**：`make compile` DUT elaboration 无错；`make run` 空 test 正常退出

---

## Phase 3–14 工作量汇总

| 工程师 | 负责 Phase | 主要文件数 | 核心难点 |
|--------|-----------|-----------|---------|
| **A** | 1/2/3(cp0+pmp+sysmap)/4/5(misc)/7(SVA)/10/12(SVA)/13(SVA)/14 | ≈ 110 文件 | ref_model 翻译算法精度；credit_sb；SVA 形式化约束 |
| **B** | 3(ifu+lsu骨架)/5(方法体+SB)/6(inv)/7(cg)/8(vseq)/9(TC×120)/10(列表)/11/12/13/14 | ≈ 200 文件 | lsu_driver 5子线程并发；translation_sb VA→PA 精度；120+ TC 场景覆盖 |

---

## 关键里程碑

| 里程碑 | 达成条件 | 状态 |
|--------|---------|------|
| **M1** — 骨架可编译运行 | Phase 1 退出准则 | ✅ **已达成** |
| **M2** — DUT elaboration 通过 | Phase 2 退出准则 | ⏳ |
| **M3** — Sanity Test 通过 | Phase 3 退出准则 | ⏳ |
| **M4** — 参考模型就绪 | Phase 4 退出准则 | ⏳ |
| **M5** — Translation SB 0 mismatch | Phase 5 退出准则 | ⏳ |
| **M6** — 全功能验证 | Phase 6 退出准则 | ⏳ |
| **M7** — SVA + 覆盖率框架 | Phase 7 退出准则 | ⏳ |
| **M8** — 全部 Vseq 可运行 | Phase 8 退出准则 | ⏳ |
| **M9** — 冒烟回归 100% | Phase 9 退出准则 | ⏳ |
| **M10** — 回归脚本就绪 | Phase 10 退出准则 | ⏳ |
| **M11~M13** — 高级特性验证 | Phase 11–13 退出准则 | ⏳ |
| **M14** — 签核通过 | Phase 14 退出准则（VerificationPlan §9） | ⏳ |
