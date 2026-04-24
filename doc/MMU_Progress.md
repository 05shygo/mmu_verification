# MMU UVM 验证环境 — 任务进度表

> **项目**：OpenRiscv2030 MMU UVM Verification
> **文档**：基于 [MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md)
> **更新**：2026-04-25
> **状态说明**：✅ 完成 | 🔄 进行中 | ⏳ 未开始 | 🔒 等待解锁

---

## 整体进度概览

| Phase | 名称 | 负责人 | 状态 | 退出准则达成 |
|-------|------|--------|------|------------|
| **Phase 1** | 环境骨架 | A | ✅ 完成 | ✅ `make comp` + `make run` 通过，0 cycle 退出无错 |
| **Phase 2** | DUT 接入 + Interface | A 主，B Review | ✅ 完成 | ✅ `make comp` 0 error；`make run TEST_NAME=mmu_base_test` UVM_FATAL=0，UVM_ERROR=0 |
| **Phase 3** | 最简 Active Agent + Sanity Test | A/B 并行 | ✅ 完成 | ✅ `UVM_ERROR=0`，`UVM_FATAL=0`，`mmu_xx_mmu_en=1`，仿真时间 81500 ps（2026-04-24） |
| **Phase 4** | PTW 内存模型 + 参考模型 | A | ✅ 完成 | ✅ 18 个交付物；test_ptw_map4k_directed mismatch=0，UVM_ERROR=0 |
| **Phase 5** | IFU + LSU Agent + Translation SB | B 主，A 配合 | 🔄 退出准则验证中 | A/B 编码全部完成（22 项交付物）；`make comp` + `make run` 待执行 |
| **Phase 6** | misc_agent 完善 + TLB 失效 + Invalidate SB | B 主，A 配合 | ⏳ 等待 Phase 5 编译验证 | — |
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

## Phase 3 详细进度（✅ 已完成）

**负责**：工程师 A（主）/ B（并行）
**工程师 A 完成日期**：2026-04-24（步骤 3-1/2/3/6/7/8）
**工程师 B 完成日期**：2026-04-24（步骤 3-4/3-5：ifu_agent + lsu_agent 八件套 + 集成更新）
**退出准则**：✅ **已达成**（2026-04-24）— `UVM_ERROR=0`，`UVM_FATAL=0`，`mmu_xx_mmu_en=1`（Sv39 激活），仿真时间 81500 ps

### Phase 3 Batch 1（30 文件，工程师 A）

| 步骤 | 交付物 | 状态 | 备注 |
|------|--------|------|------|
| 3-1 | `cp0_agent/` (9 文件) | ✅ | cp0_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent |
| 3-2 | `pmp_agent/` (9 文件) | ✅ | pmp_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent |
| 3-3 | `sysmap_cfg_agent/` (9 文件) | ✅ | sysmap_cfg_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent |
| 3-4 | `ifu_agent` 骨架（8 件套）| ✅ | **工程师 B** 完成（2026-04-24）；ifu_agent_pkg/txn/sequencer/driver/monitor/sequences/covergroups/agent |
| 3-5 | `lsu_agent` 骨架（8 件套）| ✅ | **工程师 B** 完成（2026-04-24）；含 5 子线程 driver 骨架（pipe0/1/2/stamo/inv），8 analysis ports monitor |
| 3-6 | `testbench/env/mmu_env_pkg.sv` | ✅ | 更新：新增 import ifu_agent_pkg + lsu_agent_pkg |
| 3-6 | `testbench/env/mmu_top_cfg.svh` | ✅ | 7 个 agent mode 开关 + SB 开关 + SVA 开关 |
| 3-6 | `testbench/env/mmu_env.svh` | ✅ | 更新：build_phase 实例化 m_ifu / m_lsu；connect_phase Phase 5 占位注释 |

### Phase 3 Batch 2（5 文件，工程师 A）

| 步骤 | 交付物 | 状态 | 备注 |
|------|--------|------|------|
| 3-7 | `testbench/test/test_base.svh` | ✅ | `class test_base extends uvm_test`；build_phase 创建 env；run_test_body() 钩子 |
| 3-7 | `testbench/test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh` | ✅ | 序列化执行 cp0→pmp→sysmap 三个序列；采样 mmu_xx_mmu_en |
| 3-7 | `testbench/test/test_pkg.sv` | ✅ | `package test_pkg`：import mmu_env_pkg + include test_base + sanity test |
| 3-8 | `testbench/Files.f` 更新 | ✅ | 更新：追加 ifu_agent_pkg + lsu_agent_pkg（共 5×agent_pkg + mmu_env_pkg + test_pkg）|
| — | 退出准则验证 | ✅ | `make run TEST_NAME=test_mmu_sanity_csr_pmp_sysmap`：UVM_ERROR=0，UVM_FATAL=0，`mmu_xx_mmu_en=1` PASS，仿真时间 81500 ps（2026-04-24） |

### Phase 3 退出仿真 Bug 修复记录

| # | 文件 | 错误类型 | 根因 | 修复内容 |
|---|------|---------|------|---------|
| P3-1 | `testbench/test/test_pkg.sv` | SE：`cp0_reg_rw_seq` not recognized as a type | SV package import **非传递性**：`test_pkg` 仅 import `mmu_env_pkg::*`，无法看到 `mmu_env_pkg` 内部 import 的 `cp0/pmp/sysmap_cfg_agent_pkg` 符号 | 在 `test_pkg` 中显式追加 `import mmu_params_pkg::*`、`mmu_common_pkg::*`、`cp0_agent_pkg::*`、`pmp_agent_pkg::*`、`sysmap_cfg_agent_pkg::*`、`ifu_agent_pkg::*`、`lsu_agent_pkg::*` |
| P3-2 | `testbench/top/tb_top.sv` | UVM_FATAL @ time=0：所有 `uvm_config_db::get` 失败 | config_db key 大小写不匹配：`tb_top` set 用小写（`"cp0_vif"`）；所有 agent driver/monitor/agent get 用大写（`"CP0_VIF"`）；UVM config_db key 区分大小写 | 将 `tb_top` 中 7 个 `set()` 的 key 全部改为大写：`"IFU_VIF"`、`"LSU_VIF"`、`"CP0_VIF"`、`"PTW_MEM_VIF"`、`"PMP_VIF"`、`"SYSMAP_CFG_VIF"`、`"MISC_VIF"` |

### Phase 3 仿真调试 Bug 修复记录（2026-04-24）

| # | 文件 | 错误类型 | 根因 | 修复内容 |
|---|------|---------|------|---------|
| P3-3 | `cp0_agent/cp0_covergroups.svh`<br>`pmp_agent/pmp_covergroups.svh`<br>`sysmap_cfg_agent/sysmap_cfg_covergroups.svh`<br>`ifu_agent/ifu_covergroups.svh`<br>`lsu_agent/lsu_covergroups.svh` | PCECGNNA（×10）：嵌入式 covergroup `new()` 位置非法 | SV LRM §19.2：嵌入式 covergroup 的 `new()` 只能在该类自身的 `new()` 构造函数中调用；5 个 `*_cg_wrapper` 均将 `cg_xxx = new()` 放在 `set_vif()` 方法内 | 将所有 `cg_xxx = new()` 从 `set_vif()` 移入类 `new()` 构造函数；`set_vif()` 仅保留 `vif = v` |
| P3-4 | `sysmap_cfg_agent/sysmap_cfg_sequences.svh` | DCTTSW：`3'd8` 截断为 0 | `constraint c_valid_region { region_idx < 3'd8; }`，3-bit 无法表示 8，截断为 0 使约束等价于 `region_idx < 0`（永远假）| `< 3'd8` → `<= 3'd7` |
| P3-5 | `cp0_agent/cp0_driver.svh`（`_do_write_satp`） | 仿真卡死 | RTL：`mmu_cp0_cmplt = tlboper_regs_cmplt \| mcir_no_op`，SATP 写入**不产生 cmplt 脉冲**；driver 死等 `mmu_cp0_cmplt` | 删除 `@(iff mmu_cp0_cmplt)` 等待，改为写完去除 `satp_sel` 后等一个时钟沿 |
| P3-6 | `cp0_agent/cp0_driver.svh`（`_do_write_reg`） | 可能卡死 | 同 P3-5：MIR/MEL/MEH（reg_num 0/1/2）写入不产生 cmplt，只有 MCIR（reg_num=3）才有 | 按 reg_num 分支：`==3` 等 cmplt，其余等一个时钟沿 |
| P3-7 | `cp0_agent/cp0_driver.svh`（`_do_tlb_all_inv`） | 可能卡死 | RTL 触发条件：`cp0_mmu_tlb_all_inv && !lsu_oper_cmplt && tlb_sm_idle`；若 SM 非空闲（并发 LSU 操作），单周期脉冲被丢弃，`mmu_cp0_tlb_done` 永远不来 | 加 512 周期 `fork/join_any` 超时，超时后输出 UVM_WARNING 并继续 |
| P3-8 | `cp0_agent/cp0_driver.svh`（`_do_write_satp`） | `mmu_xx_mmu_en` 始终为 0 | RTL：`satp_write_en = cp0_mmu_satp_sel`；SATP 写入靠 `satp_sel=1` 触发，与 `wreg/reg_num` 无关；旧代码设 `satp_sel=0` + `wreg=1/reg_num=0`（实际写 MIR，SATP 未被写过）| 修改为：拉高 `cp0_mmu_satp_sel=1` 同时驱动 `wdata`，等一拍锁存，再拉低 `satp_sel` |
| P3-9 | `test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh` | `mmu_xx_mmu_en` 始终为 0 | RTL：`mmu_xx_mmu_en = (satp_mode==4'h8) && (cp0_yy_priv_mode != 2'b11)`；测试约束 `priv_mode==2'b11`（M-mode），M-mode 下该信号恒为 0 | `priv_mode == 2'b11` → `priv_mode == 2'b01`（S-mode） |
| P3-10 | 所有 6 个 `*_if.sv`（driver_cb） | `mmu_xx_mmu_en` 始终为 0（时序竞争） | `default output #1`：在 `timescale 1ns/1ps` + 1GHz 时钟下，`#1` = 1ns = 1 个时钟周期，driver 驱动信号恰好与下一个时钟上升沿同时到达 RTL（setup/hold violation），ICG 门控和 SATP 触发器采样不稳定 | 所有 `driver_cb` 的 `output #1` → `output #1step`（1ps，符合 SV LRM TB 驱动惯例） |

### Open Items

| ID | 描述 | 状态 |
|----|------|------|
| DA-003 | sysmap RTL force 路径（`sysmap_cfg_driver.svh` 中 force 目标路径需设计确认） | ⏳ Phase 3 已退出，留 Phase 6 处理 |

---

## Phase 4 详细进度（✅ 已完成）

**负责**：工程师 A
**完成日期**：2026-04-25
**退出准则**：✅ `test_ptw_map4k_directed` 50 条映射验证 + 10 条 page-fault 路径，mismatch=0，UVM_ERROR=0

### Phase 4 新建文件（13 个）

| # | 交付物 | 位置 | 状态 | 备注 |
|---|--------|------|------|------|
| 4-1 | `ptw_mem_txn.svh` | `testbench/ptw_mem_agent/` | ✅ | PTW 内存通道事务类；ptw_rsp_kind_e 枚举；rand rsp_delay c_rsp_delay(1..8) |
| 4-2 | `page_table_builder.svh` | `testbench/ptw_mem_agent/` | ✅ | Sv39 3 级页表构建器（`uvm_object`）；assoc array `bit[63:0] m_mem[longint unsigned]`；map_4k 完全实现；map_2m/1g stub；inject_fault 6 种 |
| 4-3 | `ptw_mem_sequencer.svh` | `testbench/ptw_mem_agent/` | ✅ | `uvm_sequencer #(ptw_mem_txn)` |
| 4-4 | `ptw_mem_responder.svh` | `testbench/ptw_mem_agent/` | ✅ | 监听 DUT `mmu_lsu_data_req`；查 page_table_builder；随机 delay + bus_error 注入 |
| 4-5 | `ptw_mem_monitor.svh` | `testbench/ptw_mem_agent/` | ✅ | `ap_req` + `ap_rsp` 两个 analysis port；fork collect_req / collect_rsp |
| 4-6 | `ptw_mem_sequences.svh` | `testbench/ptw_mem_agent/` | ✅ | 10 个序列类；ptw_page_table_build_4k_seq 完全实现；其余为 stub |
| 4-7 | `ptw_mem_covergroups.svh` | `testbench/ptw_mem_agent/` | ✅ | `ptw_mem_cg_wrapper extends uvm_component`；cg_ptw_rsp_kind（normal/bus_err）；cg_rsp_delay_range（Phase 7 TODO）；CG `new()` 在 class `new()` 中（P3-3 经验应用）|
| 4-8 | `ptw_mem_agent.svh` | `testbench/ptw_mem_agent/` | ✅ | `ptw_mem_agent extends uvm_agent`；ACTIVE 创建 sequencer+responder；PASSIVE/ACTIVE 均创建 monitor+cg |
| 4-9 | `ptw_mem_agent_pkg.sv` | `testbench/ptw_mem_agent/` | ✅ | package；include 顺序：txn→cg→sequencer→responder→monitor→sequences→page_table_builder→agent |
| 4-10 | `mmu_page_table_mem.svh` | `testbench/env/` | ✅ | `uvm_object`；持有 `page_table_builder m_builder`；代理 read_pte/write_pte/reset；init() 方法 |
| 4-11 | `mmu_ref_model.svh` | `testbench/env/` | ✅ | `uvm_component`；Sv39 3 级页走算法完整实现（4K 叶页）；CSR 镜像（satp0/1/priv/mxr/sum/mprv/mpp）；4 个 TLM FIFO（Phase 5 连接）；check_pmp/lookup_sysmap stub；report_phase 统计输出 |
| 4-12 | `test_ptw_map4k_directed.svh` | `testbench/test/basic_tests/` | ✅ | 直接设置 CSR 镜像；set_root(0x10, 0xABCD)；50 条 map_4k → translate() 验证；10 条 page-fault 路径验证 |

### Phase 4 修改文件（5 个）

| # | 交付物 | 状态 | 修改内容 |
|---|--------|------|----------|
| M-1 | `testbench/common/mmu_common_pkg.sv` | ✅ | 实现 make_pte / va_vpn_level / make_satp 3 个 TODO 函数 |
| M-2 | `testbench/env/mmu_env_pkg.sv` | ✅ | 新增 `import ptw_mem_agent_pkg::*`；新增 `\`include "mmu_page_table_mem.svh"` 和 `\`include "mmu_ref_model.svh"` |
| M-3 | `testbench/env/mmu_env.svh` | ✅ | 新增 m_ptw_mem / m_pt_mem / m_ref 声明；build_phase 实例化并初始化；connect_phase 调用 set_page_table() |
| M-4 | `testbench/Files.f` | ✅ | 追加 `${TB_DIR}/ptw_mem_agent/ptw_mem_agent_pkg.sv`（在 lsu_agent_pkg.sv 之后）|
| M-5 | `testbench/test/test_pkg.sv` | ✅ | 新增 `import ptw_mem_agent_pkg::*`；新增 `\`include "basic_tests/test_ptw_map4k_directed.svh"` |

### Phase 4 设计决策记录

| # | 决策点 | 选择 | 理由 |
|---|--------|------|------|
| D4-1 | page_table_builder 基类 | `uvm_object`（非 `uvm_component`） | 需要在 responder 和 ref_model 之间共享引用；`uvm_component` 强制绑定 UVM 层次，不适合跨层共享 |
| D4-2 | PT 存储结构 | `bit[63:0] m_mem[longint unsigned]` 关联数组 | 按需分配，避免预分配大数组；key = PA[39:0] 自然映射 |
| D4-3 | m_next_ppn 起始值 | `root_ppn + 28'd16` | 留 16 页缓冲区，避免 3 级 PT（页索引 512 项）与 root 页冲突 |
| D4-4 | ref_model CSR 更新路径 | Phase 4 直接赋值；Phase 5 启用 TLM FIFO | 解耦 Phase 4 算法验证与 Phase 5 信号监听，减少调试干扰 |
| D4-5 | mmu_page_table_mem 角色 | 薄包装器（proxy），核心逻辑在 builder | env 只持有 pt_mem；responder/ref_model 取 `m_pt_mem.m_builder` 引用，三方共享同一实例 |

### Phase 4 退出准则验证（✅ 已验证 — 2026-04-24）

| 准则 | 预期结果 | 实测结果 | 状态 |
|------|---------|---------|------|
| `make run TEST_NAME=test_ptw_map4k_directed` UVM_ERROR=0 | 50 条 map_4k mismatch=0，10 条 fault path PASS | UVM_ERROR=0，UVM_FATAL=0，[test_ptw_map4k_directed]=3（含 PASSED 消息），仿真时间 60000ps | ✅ |
| `make run TEST_NAME=test_mmu_sanity_csr_pmp_sysmap` 回归不破坏 | UVM_ERROR=0，mmu_en=1 | UVM_ERROR=0，mmu_en=1，仿真时间 81500ps（Phase 3 回归未破坏）| ✅ |
| `make comp` 0 error | 编译通过 | 编译通过（修复 pkg include 顺序：page_table_builder 必须在 responder 之前）| ✅ |
| 5 个独立 seed 全部 mismatch=0 | — | ⏳ 待正式多 seed 回归（Phase 10）| ⏳ |

**编译 Bug 修复记录（Phase 4 调试）**

| # | 文件 | 错误 | 根因 | 修复 |
|---|------|------|------|------|
| P4-1 | `ptw_mem_agent_pkg.sv` | `[INVTST]`/`[BDTYP]`：test 注册失败 @ time=0 | SV package 内 include 顺序违反前向引用规则：`ptw_mem_responder.svh` 使用 `page_table_builder` 类型，但 `page_table_builder.svh` 排在 sequences 之后（包末尾），编译时 responder 看不到该类型 | 将 `` `include "page_table_builder.svh"`` 移到 txn 之后第二位（responder/monitor/sequences 之前）|
| P4-2 | `testbench/ptw_mem_agent/page_table_builder.svh` | `[SE]` token is 'unsigned'（line 64/73）| SV 类型转换语法不允许带空格的复合类型：`longint unsigned'(expr)` 非法，编译器在 `'` 之前只识别单一标识符或数值宽度 | `longint unsigned'(pte_addr)` → `longint'(pte_addr)`（共 2 处：`read_pte_at` + `write_pte_at`）|
| P4-3 | `testbench/test/basic_tests/test_ptw_map4k_directed.svh` | `[SE]` token is 'ref'（line 51）| `ref` 是 SV 保留关键字（用于 `ref` 类型形参），不能用作变量名 | 将 `run_test_body()` 内局部变量 `ref` 及其全部引用（共 12 处）重命名为 `rm` |
| P4-4 | `testbench/ptw_mem_agent/ptw_mem_sequences.svh` | `[IRRVD]`：`rand` 变量类型非法（line 72）| `string` 类型不属于 SV 允许的 `rand` 类型（整型/枚举/packed struct/bit）；`fault_kind` 为注入配置字段，由测试直接赋值，不需要随机化 | 去掉 `fault_kind` 前的 `rand` 限定符 |

---

## Phase 5 详细进度（🔄 进行中 — 编码完成，退出准则验证中）

**负责**：工程师 B（主）/ 工程师 A（misc_agent + credit_sb + perf_mon）
**B 完成日期**：2026-04-25
**A 完成日期**：2026-04-24
**退出准则**：⏳ 编码全部完成（A/B 任务共 22 项交付物均已提交）；待执行 `make comp` + `make run` 联合验证（退出准则 #1/#8 尚未运行）

### Phase 5 新建文件（2 个）

| # | 交付物 | 位置 | 状态 | 备注 |
|---|--------|------|------|------|
| 5-A | `mmu_translation_sb.svh` | `testbench/env/` | ✅ | 4 个 analysis imp（ifu/lsu_p0/lsu_p1/lsu_p2）；`write_ifu`/`write_lsu_p0/1/2` 比对 ppn+exc；`report_phase` 打印统计 |
| 5-B | `test_mmu_translation_sanity.svh` | `testbench/test/basic_tests/` | ✅ | Phase 5 端到端 sanity test；4 个辅助序列类（ifu_mapped_va_seq / lsu_mapped_va_seq / lsu_p2_sanity_seq / lsu_stamo_sanity_seq）；100 IFU + 100 LSU_P0 + 20 LSU_P1 + 20 P2 + 20 STAMO |

### Phase 5 修改文件（7 个）

| # | 交付物 | 状态 | 修改内容 |
|---|--------|------|----------|
| M5-1 | `testbench/ifu_agent/ifu_driver.svh` | ✅ | `drive_one()` 完整实现：1拍 assert + fork/join_any 等 pavld + 2000 cycle 超时 |
| M5-2 | `testbench/lsu_agent/lsu_driver.svh` | ✅ | `_drive_pipe0/1()` 完整实现：hold va_vld + fork/join_any 等 pa_vld + 4000 cycle 超时；pipe2/stamo 骨架清理；inv 保留 Phase 6 TODO |
| M5-3 | `testbench/ifu_agent/ifu_monitor.svh` | ✅ | 新增 `m_pending_req[$]` 队列；`_collect_req()` push；`_collect_rsp()` pop+合并 VA，发布含 VA+PA 的 merged txn |
| M5-4 | `testbench/lsu_agent/lsu_monitor.svh` | ✅ | 新增 `m_pending_p0/p1[$]`；pipe0/1 req push、rsp pop 合并 va/id/st_inst；pipe2 rsp 仅采样 pa（VA 合并留 Phase 6） |
| M5-5 | `testbench/env/mmu_env_pkg.sv` | ✅ | 追加 `` `include "mmu_translation_sb.svh" `` |
| M5-6 | `testbench/env/mmu_env.svh` | ✅ | 新增 `m_translation_sb` 声明+创建+注入 `m_ref`；connect_phase 连接 cp0/pmp/sysmap → ref TLM FIFO + ifu/lsu rsp → SB |
| M5-7 | `testbench/test/test_pkg.sv` | ✅ | 追加 `` `include "basic_tests/test_mmu_translation_sanity.svh" `` |

### Phase 5 设计决策记录

| # | 决策点 | 选择 | 理由 |
|---|--------|------|------|
| D5-1 | IFU 驱动策略 | 1-outstanding：assert 1拍，fork/join_any 等 pavld | 匹配 IFU 协议（无 ID，单未决）；monitor FIFO 顺序对齐 |
| D5-2 | LSU pipe 驱动策略 | hold va_vld 直至 pa_vld，fork/join_any + 4000 cycle 超时 | 忠实协议；超时输出 UVM_WARNING 避免仿真卡死 |
| D5-3 | SB 比对范围 | Phase 5 只比对 ppn 和 exc（pgflt/access_fault） | sec/ca/buf 属性比对留 Phase 6（SysMap/PMP 全通 stub） |
| D5-4 | c_kind_default 冲突处理 | 辅助序列中调用 `constraint_mode(0)` | SV LRM §18.7.2：with-clause 追加而非覆盖 class 约束；不修改 lsu_txn 全局约束 |
| D5-5 | ROOT_PPN=0 | 按任务规格（ppn=0, asid=0）；leaf PPN 从 0x200 起步 | 自动分配 L1=16, L0=17，leaf 从 0x200(512) 起步，三者不冲突 |
| D5-6 | 映射权限 | r=w=x=1, u=0, a=d=1 | S-mode fetch+load+store 均可通过；a/d=1 避免 ref_model 发出 WARN |

### Phase 5 A 的任务（✅ 已完成，2026-04-24）

| # | 交付物 | 位置 | 状态 | 说明 |
|---|--------|------|------|------|
| A5-1a | `misc_txn.svh` | `testbench/misc_agent/` | ✅ | 6 个 op 枚举（FLUSH/EXPT/SMP_DISABLE/HPCP_CNT_EN/DFT_SCAN_EN/IDLE）；驱动字段 + 监测字段 |
| A5-1b | `misc_sequencer.svh` | `testbench/misc_agent/` | ✅ | `uvm_sequencer #(misc_txn)` 标准实现 |
| A5-1c | `misc_covergroups.svh` | `testbench/misc_agent/` | ✅ | `misc_cg_wrapper`：cg_misc_hpcp/rtu/debug；P3-3 fix 应用（new() 在 class new() 中）|
| A5-1d | `misc_driver.svh` | `testbench/misc_agent/` | ✅ | `_do_rtu_flush`：1 cycle 脉冲；`_do_smp_disable`/`_do_hpcp_cnt_en`：level 信号；`_drive_idle` 安全默认 |
| A5-1e | `misc_monitor.svh` | `testbench/misc_agent/` | ✅ | `ap_hpcp`：每周期采样 miss 信号变化；`ap_debug`：debug_info 变化时发布 |
| A5-1f | `misc_sequences.svh` | `testbench/misc_agent/` | ✅ | 5 个序列：base/rtu_flush/rtu_expt/smp_disable/hpcp_enable + `misc_init_seq`（复合初始化）|
| A5-1g | `misc_agent.svh` | `testbench/misc_agent/` | ✅ | 标准 agent：ACTIVE 创建 seq+driver；PASSIVE/ACTIVE 均创建 monitor+cg |
| A5-1h | `misc_agent_pkg.sv` | `testbench/misc_agent/` | ✅ | package；include 顺序：txn→cg→sequencer→driver→monitor→sequences→agent |
| A5-2 | `mmu_credit_sb.svh` | `testbench/env/` | ✅ | 8 个 TLM FIFO；4 个计数器（credit_l1i/l1d/l2_reqq/ptw_mbuf）；边界检查 + report_phase 守恒断言 |
| A5-3 | `mmu_perf_mon.svh` | `testbench/env/` | ✅ | 5 个 FIFO（ifu_rsp/lsu_p0/p1/p2_rsp/hpcp）；统计字段声明；report_phase 摘要打印；统计细化留 Phase 7 |
| A5-4a | `mmu_env_pkg.sv` 更新 | `testbench/env/` | ✅ | 追加 `import misc_agent_pkg::*`；追加 credit_sb + perf_mon `\`include` |
| A5-4b | `mmu_env.svh` 更新 | `testbench/env/` | ✅ | build_phase：实例化 m_misc/m_credit_sb/m_perf；connect_phase：fan-out 连线 8 个 AP → credit_sb，5 个 AP → perf_mon |
| A5-4c | `Files.f` 更新 | `testbench/` | ✅ | 追加 `${TB_DIR}/misc_agent/misc_agent_pkg.sv` |

### Phase 5 仿真调试 Bug 修复记录（2026-04-24）

| # | 文件 | 错误现象 | 根因 | 修复内容 |
|---|------|---------|------|---------|
| P5-1 | `testbench/ifu_agent/ifu_driver.svh`<br>`testbench/ifu_agent/ifu_monitor.svh` | `test_mmu_translation_sanity` 运行：IFU 全部 100 笔翻译均出现 PA 不匹配 — `[IFU] VA=0x000100000x: PA mismatch — ref.ppn=0x0000200  dut.pa=0x0000000`；DUT `mmu_ifu_pavld=1`、`pgflt=0`、`deny=0`，但输出 PA 全为 0 | **VA 编码偏移1位**：DUT 端口 `ifu_mmu_va[62:0]` 定义为 `VA[63:1]`（取指地址右移1位，因取指恒按偶字节对齐），DUT 内部提取 VPN = `ifu_mmu_va[37:11]` = `VA[38:12]`（正确）。但驱动直接发送 `tr.va`（= VA[62:0]），导致 DUT 实际接收 `VA[63:1] = tr.va`，提取 VPN = `VA[37:11]`（整体偏移1位），PTW 在错误地址查找页表返回 V=0 的无效 PTE，最终 DUT 输出 PA=0。监测器对称地存在同一问题：直接把 `ifu_mmu_va` 作为 VA 传给 scoreboard，导致参考模型也在错误 VA 上查表（但参考模型的页表是按真实 VA 建立的），造成系统性全量误报 | **Driver**（[ifu_driver.svh](../mmu_verification/testbench/ifu_agent/ifu_driver.svh)）：`vif.driver_cb.ifu_mmu_va <= tr.va` → `vif.driver_cb.ifu_mmu_va <= tr.va >> 1`（VA[62:0] 右移1位得 VA[63:1] 格式）<br>**Monitor**（[ifu_monitor.svh](../mmu_verification/testbench/ifu_agent/ifu_monitor.svh)）：`tr.va = vif.monitor_cb.ifu_mmu_va` → `tr.va = 63'(vif.monitor_cb.ifu_mmu_va << 1)`（从 VA[63:1] 格式还原真实 VA[62:0]）<br>LSU `lsu_mmu_va0` 为 64 位，使用标准 `va[38:12]` 提取 VPN，无偏移，无需修改 |

### Phase 5 退出准则

| # | 检查项 | 负责 | 状态 |
|---|--------|------|------|
| 1 | `make comp` 0 errors | A+B | ⏳ **待运行**（A/B 编码均已完成，尚未联合编译）|
| 2 | IFU 单端口随机 VA：5 种子×100次，UVM_ERROR=0 | B | ⏳ 待运行（P5-1 VA 编码 bug 已修复）|
| 3 | LSU pipe0：5×100次 LD，pipe1/2/stamo 各≥20次，UVM_ERROR=0 | B | ⏳ 待运行 |
| 4 | miss→PTW→refill 混合，mismatch=0 | B | ⏳ 待运行（SB 接入完成）|
| 5 | `mmu_translation_sb` 接收 ≥200 笔，mismatch=0 | B | ⏳ 待运行 |
| 6 | `mmu_credit_sb` 仿真结束信用守恒计数 =0 | **A** | ⏳ 待运行（已实现）|
| 7 | `misc_agent` 编译通过；`rtu_flush`/`biu_smp_disable` 实际驱动 | **A** | ⏳ 待运行（已实现）|
| 8 | `scan_logs.pl` 无非预期 ERROR/FATAL | A+B | ⏳ **待运行** |

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
| **M3** — Sanity Test 通过 | Phase 3 退出准则 | ✅ **已达成**（2026-04-24）|
| **M4** — 参考模型就绪 | Phase 4 退出准则 | ✅ **已达成**（2026-04-24）|
| **M5** — Translation SB 0 mismatch | Phase 5 退出准则 | ⏳ **编码完成，退出准则待验证**（A+B 共 22 项交付物已提交；`make comp` + `make run` 待执行）|
| **M6** — 全功能验证 | Phase 6 退出准则 | ⏳ |
| **M7** — SVA + 覆盖率框架 | Phase 7 退出准则 | ⏳ |
| **M8** — 全部 Vseq 可运行 | Phase 8 退出准则 | ⏳ |
| **M9** — 冒烟回归 100% | Phase 9 退出准则 | ⏳ |
| **M10** — 回归脚本就绪 | Phase 10 退出准则 | ⏳ |
| **M11~M13** — 高级特性验证 | Phase 11–13 退出准则 | ⏳ |
| **M14** — 签核通过 | Phase 14 退出准则（VerificationPlan §9） | ⏳ |
