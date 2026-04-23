# MMU UVM 验证环境 — 任务进度表

> **项目**：OpenRiscv2030 MMU UVM Verification
> **文档**：基于 [MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md)
> **更新**：2026-04-24
> **状态说明**：✅ 完成 | 🔄 进行中 | ⏳ 未开始 | 🔒 等待解锁

---

## 整体进度概览

| Phase | 名称 | 负责人 | 状态 | 退出准则达成 |
|-------|------|--------|------|------------|
| **Phase 1** | 环境骨架 | A | ✅ 完成 | ✅ `make comp` + `make run` 通过，0 cycle 退出无错 |
| **Phase 2** | DUT 接入 + Interface | A 主，B Review | ✅ 完成 | ✅ `make comp` 0 error；`make run TEST_NAME=mmu_base_test` UVM_FATAL=0，UVM_ERROR=0 |
| **Phase 3** | 最简 Active Agent + Sanity Test | A/B 并行 | 🔄 进行中（工程师 A 完成，待 B 同步） | ⏳ 待验证（步骤 3-4/3-5 工程师 B 未完成） |
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
| 1-D | `setup_env.sh` / `setup_env.csh` | ✅ | 含 CORE_V_VERIF、自动 PATH 扩展、加载 setup.local.*；csh 语法修复（`$status` 替代反引号比较） |
| 1-D+ | `setup.local.sh.example` / `setup.local.csh.example` | ✅ | 服务器差异配置模板，`.gitignore` 隔离 |
| 1-E | `Makefile` | ✅ | 基于 hpdcache 裁剪；CHECK_TEST_NAME 注释；CORE_V_VERIF 注入 |
| 1-F | `testbench/Files.f` | ✅ | Phase 1 最小版：仅 `-F ${CV_DV_UTILS_DIR}/uvm/Files.f` |
| 1-G | `testbench/top/tb_top.sv` | ✅ | 最小骨架：时钟 + `run_test()`，无 DUT |
| — | `.gitignore` | ✅ | 忽略 output/、setup.local.*、simv 等 |
| — | 编译验证 | ✅ | 服务器1 `make comp` 通过；服务器2（csh）`make comp` 通过 |
| — | 运行验证 | ✅ | `make run TEST_NAME=uvm_test_top` 0 cycle 退出无错 |

---

## Phase 2 详细进度（✅ 已完成）

**负责**：工程师 A（主写）
**完成日期**：2026-04-23
**退出准则**：✅ `make comp` 0 error；✅ `make run TEST_NAME=mmu_base_test` UVM_FATAL=0，UVM_ERROR=0，仿真时间 100ns

| 步骤 | 交付物 | 状态 | 备注 |
|------|--------|------|------|
| 2-1 | `modules/mmu_params/mmu_params_pkg.sv` | ✅ | Sv39 常量：VA=39/PA=40/VPN=27/PPN=28；pgs_e/acc_type_e 枚举；类型别名 |
| 2-2 | `testbench/common/mmu_common_pkg.sv` | ✅ | PTE 工具函数骨架、exception_e 枚举、xlation_rsp_t；修复 `buf` SV 保留字 → `buf_en` |
| 2-3 | `testbench/common/mmu_rtl_defines.v` | ✅ | RTL 编译期宏：SYSMAP_FLG0~7（5-bit）、SYSMAP_BASE_ADDR0~7（28-bit） |
| 2-4 | `testbench/common/mmu_top_cfg.svh` | ✅ | TB 顶层配置头文件 |
| 2-5 | 7 个 `*_if.sv` | ✅ | ifu_if / lsu_if / cp0_if / ptw_mem_if / pmp_if / sysmap_cfg_if / misc_if |
| 2-6 | `testbench/top/tb_top.sv` 更新 | ✅ | 实例化 ct_mmu_top + 7个interface + 7个 uvm_config_db::set |
| 2-7 | `testbench/Files.f` 更新 | ✅ | 加入 mmu_rtl_defines.v → relate_rtl → mmu_params_pkg.sv → 全部 RTL → 7个 interface → mmu_common_pkg.sv → mmu_base_test.sv |
| 2-8 | `Makefile` 更新 | ✅ | 新增 RELATE_RTL_DIR（symlink）、`make setup` 目标、`+define+PA_WIDTH=40`；默认 TEST_NAME=mmu_base_test |
| 2-9 | `testbench/test/mmu_base_test.sv` | ✅ | Phase 2 smoke test：build_phase + run_phase 100ns 退出 |
| — | RTL Bug 修复（共 10 处） | ✅ | 见下方 RTL 修复清单 |
| — | 编译验证 | ✅ | `make comp` 0 errors，9 warnings（均为 info 级） |
| — | 运行验证 | ✅ | `make run TEST_NAME=mmu_base_test`：UVM_INFO=16，UVM_WARNING=0，UVM_ERROR=0，UVM_FATAL=0 |

### Phase 2 RTL Bug 修复记录

| # | 文件 | 位置 | 错误类型 | 修复内容 |
|---|------|------|---------|---------|
| 1 | `setup_env.csh` | if 条件 | csh 语法错误 | 反引号字符串比较 → `$status == 0` |
| 2 | `Makefile` | RELATE_RTL_DIR | 路径含空格编译失败 | 创建 `relate_rtl` symlink，`make setup` 自动建立 |
| 3 | `ct_mmu_sysmap.v` | 宏引用 | UM：\`PA_WIDTH 未定义 | `+define+PA_WIDTH=40` 加入 VCS_ELAB_OPTS |
| 4 | `ct_mmu_sysmap.v` | 宏引用 | UM：SYSMAP_FLG/BASE_ADDR 未定义 | 新建 `mmu_rtl_defines.v` 定义 8 组宏 |
| 5 | `mmu_l1dtlb_mb_entry.sv` | line 56 | SE：端口列表中分号 | `;` → `,` |
| 6 | `mmu_common_pkg.sv` | xlation_rsp_t | SE：`buf` 保留字 | `logic buf` → `logic buf_en` |
| 7 | `mmu_l1dtlb.sv` | line 238 | IND：MB_WIDTH 未声明 | `MB_WIDTH` → `MB_DEPTH`（原 RTL 笔误） |
| 8 | `Files.f` | — | CFCILFBI：模块找不到 | 补入 PDE_cache.sv / pplru.sv / twu.sv / ptw_mbuf.sv / ptw.sv |
| 9 | `ptw_mbuf.sv` | line 122+ | IND+SE：信号未声明 + always_ff 缺 begin/end | 补 4 个 logic 声明；if/else if 分支加 begin/end |
| 10 | `mmu_l1dtlb.sv` | line 1054 vs 1145 | ICSD：entry_vld/entry_hit0/entry_hit1 重复驱动 | 删除第二个 generate 块内的重复 assign（保留无效化/门控逻辑） |

---

## Phase 3 详细进度（🔄 进行中）

**负责**：工程师 A（主）/ B（并行）
**工程师 A 完成日期**：2026-04-24（步骤 3-1/2/3/6/7/8）
**退出准则**：⏳ 待验证 — 需工程师 B 完成步骤 3-4/3-5（ifu_agent/lsu_agent 骨架）后，`make run TEST_NAME=test_mmu_sanity_csr_pmp_sysmap` UVM_ERROR=0，UVM_FATAL=0

### Phase 3 Batch 1（30 文件，工程师 A）

| 步骤 | 交付物 | 状态 | 备注 |
|------|--------|------|------|
| 3-1 | `cp0_agent/` (9 文件) | ✅ | cp0_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent |
| 3-2 | `pmp_agent/` (9 文件) | ✅ | pmp_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent |
| 3-3 | `sysmap_cfg_agent/` (9 文件) | ✅ | sysmap_cfg_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent |
| 3-4 | `ifu_agent` 骨架（driver + monitor） | ⏳ | **工程师 B** 负责 |
| 3-5 | `lsu_agent` 骨架（driver + monitor） | ⏳ | **工程师 B** 负责 |
| 3-6 | `testbench/env/mmu_env_pkg.sv` | ✅ | 导入 3 个 agent 包；include mmu_top_cfg.svh + mmu_env.svh |
| 3-6 | `testbench/env/mmu_top_cfg.svh` | ✅ | 7 个 agent mode 开关 + SB 开关 + SVA 开关 |
| 3-6 | `testbench/env/mmu_env.svh` | ✅ | build_phase 实例化 cp0/pmp/sysmap_cfg agents；Phase 5 占位注释 |

### Phase 3 Batch 2（5 文件，工程师 A）

| 步骤 | 交付物 | 状态 | 备注 |
|------|--------|------|------|
| 3-7 | `testbench/test/test_base.svh` | ✅ | `class test_base extends uvm_test`；build_phase 创建 env；run_test_body() 钩子 |
| 3-7 | `testbench/test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh` | ✅ | 序列化执行 cp0→pmp→sysmap 三个序列；采样 mmu_xx_mmu_en |
| 3-7 | `testbench/test/test_pkg.sv` | ✅ | `package test_pkg`：import mmu_env_pkg + include test_base + sanity test |
| 3-8 | `testbench/Files.f` 更新 | ✅ | 追加 3×agent_pkg + mmu_env_pkg + test_pkg（编译顺序正确）|
| — | 退出准则验证 | ⏳ | 等待工程师 B 完成步骤 3-4/3-5 后运行 `make run TEST_NAME=test_mmu_sanity_csr_pmp_sysmap` |

### Open Items

| ID | 描述 | 状态 |
|----|------|------|
| DA-003 | sysmap RTL force 路径（`sysmap_cfg_driver.svh` 中 force 目标路径需设计确认） | 🔒 待设计回复 |

---

## Phase 4–14 工作量汇总

| 工程师 | 负责 Phase | 主要文件数 | 核心难点 |
|--------|-----------|-----------|---------|
| **A** | 1/2/3(cp0+pmp+sysmap)/4/5(misc)/7(SVA)/10/12(SVA)/13(SVA)/14 | ≈ 110 文件 | ref_model 翻译算法精度；credit_sb；SVA 形式化约束 |
| **B** | 3(ifu+lsu骨架)/5(方法体+SB)/6(inv)/7(cg)/8(vseq)/9(TC×120)/10(列表)/11/12/13/14 | ≈ 200 文件 | lsu_driver 5子线程并发；translation_sb VA→PA 精度；120+ TC 场景覆盖 |

---

## 关键里程碑

| 里程碑 | 达成条件 | 状态 |
|--------|---------|------|
| **M1** — 骨架可编译运行 | Phase 1 退出准则 | ✅ **已达成** |
| **M2** — DUT elaboration 通过 | Phase 2 退出准则 | ✅ **已达成**（2026-04-23） |
| **M3** — Sanity Test 通过 | Phase 3 退出准则 | ⏳ 待工程师 B 步骤 3-4/3-5 完成后验证 |
| **M4** — 参考模型就绪 | Phase 4 退出准则 | ⏳ |
| **M5** — Translation SB 0 mismatch | Phase 5 退出准则 | ⏳ |
| **M6** — 全功能验证 | Phase 6 退出准则 | ⏳ |
| **M7** — SVA + 覆盖率框架 | Phase 7 退出准则 | ⏳ |
| **M8** — 全部 Vseq 可运行 | Phase 8 退出准则 | ⏳ |
| **M9** — 冒烟回归 100% | Phase 9 退出准则 | ⏳ |
| **M10** — 回归脚本就绪 | Phase 10 退出准则 | ⏳ |
| **M11~M13** — 高级特性验证 | Phase 11–13 退出准则 | ⏳ |
| **M14** — 签核通过 | Phase 14 退出准则（VerificationPlan §9） | ⏳ |
