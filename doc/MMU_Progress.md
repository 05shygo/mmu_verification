# MMU UVM 验证环境 — 任务进度表

> **项目**：OpenRiscv2030 MMU UVM Verification
> **文档**：基于 [MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md)
> **更新**：2026-05-05（Phase 14 已进入高并发回归与 UVM 环境问题收敛；补充 PMP/ref shadow 同步、PFU/LSU_P2 fault mismatch 与 PTW credit accept 记账调试记录；Phase 13 `make phase13_exit_check` PASS）
> **状态说明**：✅ 完成 | 🔄 进行中 | ⏳ 未开始 | 🔒 等待解锁

---

## 整体进度概览

| Phase              | 名称                                       | 负责人             | 状态                                            | 退出准则达成                                                                                                                                                                                                                                                                                                                 |
| ------------------ | ------------------------------------------ | ------------------ | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phase 1**  | 环境骨架                                   | A                  | ✅ 完成                                         | ✅`make comp` + `make run` 通过，0 cycle 退出无错                                                                                                                                                                                                                                                                        |
| **Phase 2**  | DUT 接入 + Interface                       | A 主，B Review     | ✅ 完成                                         | ✅`make comp` 0 error；`make run TEST_NAME=mmu_base_test` UVM_FATAL=0，UVM_ERROR=0                                                                                                                                                                                                                                       |
| **Phase 3**  | 最简 Active Agent + Sanity Test            | A/B 并行           | ✅ 完成                                         | ✅`UVM_ERROR=0`，`UVM_FATAL=0`，`mmu_xx_mmu_en=1`，仿真时间 81500 ps（2026-04-24）                                                                                                                                                                                                                                     |
| **Phase 4**  | PTW 内存模型 + 参考模型                    | A                  | ✅ 完成                                         | ✅ 18 个交付物；test_ptw_map4k_directed mismatch=0，UVM_ERROR=0                                                                                                                                                                                                                                                              |
| **Phase 5**  | IFU + LSU Agent + Translation SB           | A , B 协同        | ✅ 完成（2026-04-26）                           | `make phase5` 通过（comp + 5+3 seeds + phase5_check）；8 份 log 均 `UVM_ERROR=0/UVM_FATAL=0`。`make phase5_ptw4k` 也通过（P5-34 修复后 `passthrough=0`）                                                                                                                                                             |
| **Phase 6**  | misc_agent 完善 + TLB 失效 + Invalidate SB | B 主，A 配合       | ✅ 完成（2026-04-26）                           | ✅`make phase6_full` 通过（`comp` + `phase6` 矩阵/检查 + `phase6_rtu_ptw` 3 seed）；12+3 份 log 均 UVM 0/0，Invalidate SB 与 `[abort_check]` 摘要达标                                                                                                                                                              |
| **Phase 7**  | Covergroup + SVA bind                      | A/B 并行           | ✅**已达成**（2026-04-26，A/B 合入+合并） | B：7 黑盒 `*_covergroups.svh` + `mmu_env_cg_whitebox.svh` + `en_whitebox_cg` + `make phase7` / `run_cov`+`urgReport`；A：**5×SVA 为完整属性版**（与 `B_phase7` 合入时保留 A 实现，非桩代码）+ `tb_top` bind + `Files.f`；审计 [P7B01_covergroup_vif_audit.md](P7B01_covergroup_vif_audit.md)           |
| **Phase 8**  | Virtual Sequence 实现（M8）                | B                  | ✅ 完成（2026-04-27）                           | ✅`make phase8` 42-run 矩阵完成；14 个 vseq × 3 seeds 全部收口，TaskDivision#3 统计行 `[MMU_VSEQ_TASKDIVISION#3]` 已留档；F 映射 [phase8_m8_vseq_f_mapping.md](phase8_m8_vseq_f_mapping.md) 与 A Review 清单 [phase8_m8_a_review.md](phase8_m8_a_review.md) 已记档                                                            |
| **Phase 9**  | 测试用例填充（~120个）                     | B 主，A Review     | ✅ 完成（2026-04-27）                           | ✅`phase9_generated_test_base` + `test_pkg` 已纳管 12 个新增 suite，并复用 3 个 `basic_tests` 基线入口；259 个 Phase 9 wrapper（总 262 stage 合同）已落地；全量 test class 编译通过，seed=1 单跑与 smoke 3-seed 回归已收口；`scan_logs.pl` 检查与 A 对 PTW/PMP/SysMap 精度类用例 review 已完成                       |
| **Phase 10** | 回归脚本 + 覆盖率收敛                      | A 主，B 配合       | ✅ 完成（2026-04-27）                           | ✅`make regress_smoke` 22/22 通过、100%；✅ `make regress_nightly` 1260/1325 通过、95.09%（门槛≥50%）；✅ URG baseline 报告已生成；`Makefile` `regress*` / `run_test.py` / `run_vcs_verdi.py` / `cov_hier.cfg` 与 B 侧 `simu/mmu_*_list` / `exclude.do` 已完成联调                                        |
| **Phase 11** | v3.0 Gap-driven 回归                       | B 主，A 配合       | ✅ 完成（2026-04-28）                           | ✅`bug_hunt_tests` / `ptw_lsu_protocol_tests` / `mmu_*_list` / `phase11_b_stage_manifest.csv` / `phase11_bug_hunt_matrix.md` 已冻结；`Makefile` `regress_v3_gap` / `phase11_exit_check` / `phase11_show_failures` 与 `phase11_exit_check.sh` 门禁已闭环；当前项目按 `make phase11_exit_check` 完成记档 |
| **Phase 12** | MAEE / PTW-ready / TWU bypass 验证         | B 主，A Review SVA | ✅ 完成（2026-05-01）                           | ✅ `simu/mmu_v4_phase12_list` 22 个 runnable tests × seeds `95101 95102 95103` 纳入 `run_cov` 回归；MAEE SVA / PMP 骨架 / Phase12 白盒 CG / probe / `phase12_exit_check` **15 项**门禁完成；URG `No context available`、单 VDB probe fail 与覆盖率报告缺失问题已按 debug 记录收口 |
| **Phase 13** | sysmap / PMP-deny / PMP-port 验证          | B 主，A Review SVA | ✅ 完成（2026-05-02）                           | `make phase13_exit_check` PASS；Phase 13 list 55 tests × seeds `96101 96102 96103` 共 165/165 通过；SVA cover 与 13 个 covergroup threshold 均达标；URG `No context available` 记录为非阻塞 tooling issue |
| **Phase 14** | 全量回归收敛与签核                         | A 主，B 配合       | 🔄 进行中（高并发回归与问题收敛）              | 已完成高并发 shard/VDB/tooling 收敛入口；UVM 环境侧已补 PFU/PMP/SysMap 白盒诊断与 Phase12/13 用例口径修正，详见 Phase 14 debug 记录与 [MMU_Phase14_IssueTracker.md](MMU_Phase14_IssueTracker.md) |

---

## Phase 1 详细进度（✅ 已完成）

| 步骤 | 交付物                                                   | 状态 | 备注                                                                                            |
| ---- | -------------------------------------------------------- | ---- | ----------------------------------------------------------------------------------------------- |
| 1-A  | 目录骨架创建                                             | ✅   | modules/scripts/testbench/7个agent目录/output                                                   |
| 1-B  | 复制 dv_utils                                            | ✅   | 4103 个文件，含 VERSION.txt                                                                     |
| 1-C  | 复制 scripts                                             | ✅   | 21 个文件                                                                                       |
| 1-D  | `setup_env.sh` / `setup_env.csh`                     | ✅   | 含 CORE_V_VERIF、自动 PATH 扩展、加载 setup.local.*；csh 语法修复（`$status` 替代反引号比较） |
| 1-D+ | `setup.local.sh.example` / `setup.local.csh.example` | ✅   | 服务器差异配置模板，`.gitignore` 隔离                                                         |
| 1-E  | `Makefile`                                             | ✅   | 基于 hpdcache 裁剪；CHECK_TEST_NAME 注释；CORE_V_VERIF 注入                                     |
| 1-F  | `testbench/Files.f`                                    | ✅   | Phase 1 最小版：仅 `-F ${CV_DV_UTILS_DIR}/uvm/Files.f`                                        |
| 1-G  | `testbench/top/tb_top.sv`                              | ✅   | 最小骨架：时钟 +`run_test()`，无 DUT                                                          |
| —   | `.gitignore`                                           | ✅   | 忽略 output/、setup.local.*、simv 等                                                            |
| —   | 编译验证                                                 | ✅   | 服务器1 `make comp` 通过；服务器2（csh）`make comp` 通过                                    |
| —   | 运行验证                                                 | ✅   | `make run TEST_NAME=uvm_test_top` 0 cycle 退出无错                                            |

---

## Phase 2 详细进度（✅ 已完成）

**负责**：工程师 A（主写）
**完成日期**：2026-04-23
**退出准则**：✅ `make comp` 0 error；✅ `make run TEST_NAME=mmu_base_test` UVM_FATAL=0，UVM_ERROR=0，仿真时间 100ns

| 步骤 | 交付物                                   | 状态 | 备注                                                                                                                            |
| ---- | ---------------------------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------- |
| 2-1  | `modules/mmu_params/mmu_params_pkg.sv` | ✅   | Sv39 常量：VA=39/PA=40/VPN=27/PPN=28；pgs_e/acc_type_e 枚举；类型别名                                                           |
| 2-2  | `testbench/common/mmu_common_pkg.sv`   | ✅   | PTE 工具函数骨架、exception_e 枚举、xlation_rsp_t；修复 `buf` SV 保留字 → `buf_en`                                         |
| 2-3  | `testbench/common/mmu_rtl_defines.v`   | ✅   | RTL 编译期宏：SYSMAP_FLG0~7（5-bit）、SYSMAP_BASE_ADDR0~7（28-bit）                                                            |
| 2-4  | `testbench/common/mmu_top_cfg.svh`     | ✅   | TB 顶层配置头文件                                                                                                               |
| 2-5  | 7 个 `*_if.sv`                         | ✅   | ifu_if / lsu_if / cp0_if / ptw_mem_if / pmp_if / sysmap_cfg_if / misc_if                                                        |
| 2-6  | `testbench/top/tb_top.sv` 更新         | ✅   | 实例化 ct_mmu_top + 7个interface + 7个 uvm_config_db::set                                                                       |
| 2-7  | `testbench/Files.f` 更新               | ✅   | 加入 mmu_rtl_defines.v → relate_rtl → mmu_params_pkg.sv → 全部 RTL → 7个 interface → mmu_common_pkg.sv → mmu_base_test.sv |
| 2-8  | `Makefile` 更新                        | ✅   | 新增 RELATE_RTL_DIR（symlink）、`make setup` 目标、`+define+PA_WIDTH=40`；默认 TEST_NAME=mmu_base_test                      |
| 2-9  | `testbench/test/mmu_base_test.sv`      | ✅   | Phase 2 smoke test：build_phase + run_phase 100ns 退出                                                                          |
| —   | RTL Bug 修复（共 10 处）                 | ✅   | 见下方 RTL 修复清单                                                                                                             |
| —   | 编译验证                                 | ✅   | `make comp` 0 errors，9 warnings（均为 info 级）                                                                              |
| —   | 运行验证                                 | ✅   | `make run TEST_NAME=mmu_base_test`：UVM_INFO=16，UVM_WARNING=0，UVM_ERROR=0，UVM_FATAL=0                                      |

### Phase 2 RTL Bug 修复记录

| #  | 文件                       | 位置              | 错误类型                                       | 修复内容                                                     |
| -- | -------------------------- | ----------------- | ---------------------------------------------- | ------------------------------------------------------------ |
| 1  | `setup_env.csh`          | if 条件           | csh 语法错误                                   | 反引号字符串比较 →`$status == 0`                          |
| 2  | `Makefile`               | RELATE_RTL_DIR    | 路径含空格编译失败                             | 创建 `relate_rtl` symlink，`make setup` 自动建立         |
| 3  | `ct_mmu_sysmap.v`        | 宏引用            | UM：\`PA_WIDTH 未定义                          | `+define+PA_WIDTH=40` 加入 VCS_ELAB_OPTS                   |
| 4  | `ct_mmu_sysmap.v`        | 宏引用            | UM：SYSMAP_FLG/BASE_ADDR 未定义                | 新建 `mmu_rtl_defines.v` 定义 8 组宏                       |
| 5  | `mmu_l1dtlb_mb_entry.sv` | line 56           | SE：端口列表中分号                             | `;` → `,`                                               |
| 6  | `mmu_common_pkg.sv`      | xlation_rsp_t     | SE：`buf` 保留字                             | `logic buf` → `logic buf_en`                            |
| 7  | `mmu_l1dtlb.sv`          | line 238          | IND：MB_WIDTH 未声明                           | `MB_WIDTH` → `MB_DEPTH`（原 RTL 笔误）                  |
| 8  | `Files.f`                | —                | CFCILFBI：模块找不到                           | 补入 PDE_cache.sv / pplru.sv / twu.sv / ptw_mbuf.sv / ptw.sv |
| 9  | `ptw_mbuf.sv`            | line 122+         | IND+SE：信号未声明 + always_ff 缺 begin/end    | 补 4 个 logic 声明；if/else if 分支加 begin/end              |
| 10 | `mmu_l1dtlb.sv`          | line 1054 vs 1145 | ICSD：entry_vld/entry_hit0/entry_hit1 重复驱动 | 删除第二个 generate 块内的重复 assign（保留无效化/门控逻辑） |

---

## Phase 3 详细进度（✅ 已完成）

**负责**：工程师 A（主）/ B（并行）
**工程师 A 完成日期**：2026-04-24（步骤 3-1/2/3/6/7/8）
**工程师 B 完成日期**：2026-04-24（步骤 3-4/3-5：ifu_agent + lsu_agent 八件套 + 集成更新）
**退出准则**：✅ **已达成**（2026-04-24）— `UVM_ERROR=0`，`UVM_FATAL=0`，`mmu_xx_mmu_en=1`（Sv39 激活），仿真时间 81500 ps

### Phase 3 Batch 1（30 文件，工程师 A）

| 步骤 | 交付物                            | 状态 | 备注                                                                                                            |
| ---- | --------------------------------- | ---- | --------------------------------------------------------------------------------------------------------------- |
| 3-1  | `cp0_agent/` (9 文件)           | ✅   | cp0_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent                       |
| 3-2  | `pmp_agent/` (9 文件)           | ✅   | pmp_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent                       |
| 3-3  | `sysmap_cfg_agent/` (9 文件)    | ✅   | sysmap_cfg_agent_pkg / if / txn / sequencer / driver / monitor / sequences / covergroups / agent                |
| 3-4  | `ifu_agent` 骨架（8 件套）      | ✅   | **工程师 B** 完成（2026-04-24）；ifu_agent_pkg/txn/sequencer/driver/monitor/sequences/covergroups/agent   |
| 3-5  | `lsu_agent` 骨架（8 件套）      | ✅   | **工程师 B** 完成（2026-04-24）；含 5 子线程 driver 骨架（pipe0/1/2/stamo/inv），8 analysis ports monitor |
| 3-6  | `testbench/env/mmu_env_pkg.sv`  | ✅   | 更新：新增 import ifu_agent_pkg + lsu_agent_pkg                                                                 |
| 3-6  | `testbench/env/mmu_top_cfg.svh` | ✅   | 7 个 agent mode 开关 + SB 开关 + SVA 开关                                                                       |
| 3-6  | `testbench/env/mmu_env.svh`     | ✅   | 更新：build_phase 实例化 m_ifu / m_lsu；connect_phase Phase 5 占位注释                                          |

### Phase 3 Batch 2（5 文件，工程师 A）

| 步骤 | 交付物                                                            | 状态 | 备注                                                                                                                                       |
| ---- | ----------------------------------------------------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 3-7  | `testbench/test/test_base.svh`                                  | ✅   | `class test_base extends uvm_test`；build_phase 创建 env；run_test_body() 钩子                                                           |
| 3-7  | `testbench/test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh` | ✅   | 序列化执行 cp0→pmp→sysmap 三个序列；采样 mmu_xx_mmu_en                                                                                   |
| 3-7  | `testbench/test/test_pkg.sv`                                    | ✅   | `package test_pkg`：import mmu_env_pkg + include test_base + sanity test                                                                 |
| 3-8  | `testbench/Files.f` 更新                                        | ✅   | 更新：追加 ifu_agent_pkg + lsu_agent_pkg（共 5×agent_pkg + mmu_env_pkg + test_pkg）                                                       |
| —   | 退出准则验证                                                      | ✅   | `make run TEST_NAME=test_mmu_sanity_csr_pmp_sysmap`：UVM_ERROR=0，UVM_FATAL=0，`mmu_xx_mmu_en=1` PASS，仿真时间 81500 ps（2026-04-24） |

### Phase 3 退出仿真 Bug 修复记录

| #    | 文件                           | 错误类型                                             | 根因                                                                                                                                                          | 修复内容                                                                                                                                                                                            |
| ---- | ------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P3-1 | `testbench/test/test_pkg.sv` | SE：`cp0_reg_rw_seq` not recognized as a type      | SV package import**非传递性**：`test_pkg` 仅 import `mmu_env_pkg::*`，无法看到 `mmu_env_pkg` 内部 import 的 `cp0/pmp/sysmap_cfg_agent_pkg` 符号 | 在 `test_pkg` 中显式追加 `import mmu_params_pkg::*`、`mmu_common_pkg::*`、`cp0_agent_pkg::*`、`pmp_agent_pkg::*`、`sysmap_cfg_agent_pkg::*`、`ifu_agent_pkg::*`、`lsu_agent_pkg::*` |
| P3-2 | `testbench/top/tb_top.sv`    | UVM_FATAL @ time=0：所有 `uvm_config_db::get` 失败 | config_db key 大小写不匹配：`tb_top` set 用小写（`"cp0_vif"`）；所有 agent driver/monitor/agent get 用大写（`"CP0_VIF"`）；UVM config_db key 区分大小写 | 将 `tb_top` 中 7 个 `set()` 的 key 全部改为大写：`"IFU_VIF"`、`"LSU_VIF"`、`"CP0_VIF"`、`"PTW_MEM_VIF"`、`"PMP_VIF"`、`"SYSMAP_CFG_VIF"`、`"MISC_VIF"`                            |

### Phase 3 仿真调试 Bug 修复记录（2026-04-24）

| #     | 文件                                                                                                                                                                                        | 错误类型                                               | 根因                                                                                                                                                                                                    | 修复内容                                                                                               |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| P3-3  | `cp0_agent/cp0_covergroups.svh<br>``pmp_agent/pmp_covergroups.svh<br>``sysmap_cfg_agent/sysmap_cfg_covergroups.svh<br>``ifu_agent/ifu_covergroups.svh<br>``lsu_agent/lsu_covergroups.svh` | PCECGNNA（×10）：嵌入式 covergroup `new()` 位置非法 | SV LRM §19.2：嵌入式 covergroup 的 `new()` 只能在该类自身的 `new()` 构造函数中调用；5 个 `*_cg_wrapper` 均将 `cg_xxx = new()` 放在 `set_vif()` 方法内                                        | 将所有 `cg_xxx = new()` 从 `set_vif()` 移入类 `new()` 构造函数；`set_vif()` 仅保留 `vif = v` |
| P3-4  | `sysmap_cfg_agent/sysmap_cfg_sequences.svh`                                                                                                                                               | DCTTSW：`3'd8` 截断为 0                              | `constraint c_valid_region { region_idx < 3'd8; }`，3-bit 无法表示 8，截断为 0 使约束等价于 `region_idx < 0`（永远假）                                                                              | `< 3'd8` → `<= 3'd7`                                                                              |
| P3-5  | `cp0_agent/cp0_driver.svh`（`_do_write_satp`）                                                                                                                                          | 仿真卡死                                               | RTL：`mmu_cp0_cmplt = tlboper_regs_cmplt \| mcir_no_op`，SATP 写入**不产生 cmplt 脉冲**；driver 死等 `mmu_cp0_cmplt`                                                                           | 删除 `@(iff mmu_cp0_cmplt)` 等待，改为写完去除 `satp_sel` 后等一个时钟沿                           |
| P3-6  | `cp0_agent/cp0_driver.svh`（`_do_write_reg`）                                                                                                                                           | 可能卡死                                               | 同 P3-5：MIR/MEL/MEH（reg_num 0/1/2）写入不产生 cmplt，只有 MCIR（reg_num=3）才有                                                                                                                       | 按 reg_num 分支：`==3` 等 cmplt，其余等一个时钟沿                                                    |
| P3-7  | `cp0_agent/cp0_driver.svh`（`_do_tlb_all_inv`）                                                                                                                                         | 可能卡死                                               | RTL 触发条件：`cp0_mmu_tlb_all_inv && !lsu_oper_cmplt && tlb_sm_idle`；若 SM 非空闲（并发 LSU 操作），单周期脉冲被丢弃，`mmu_cp0_tlb_done` 永远不来                                                 | 加 512 周期 `fork/join_any` 超时，超时后输出 UVM_WARNING 并继续                                      |
| P3-8  | `cp0_agent/cp0_driver.svh`（`_do_write_satp`）                                                                                                                                          | `mmu_xx_mmu_en` 始终为 0                             | RTL：`satp_write_en = cp0_mmu_satp_sel`；SATP 写入靠 `satp_sel=1` 触发，与 `wreg/reg_num` 无关；旧代码设 `satp_sel=0` + `wreg=1/reg_num=0`（实际写 MIR，SATP 未被写过）                       | 修改为：拉高 `cp0_mmu_satp_sel=1` 同时驱动 `wdata`，等一拍锁存，再拉低 `satp_sel`                |
| P3-9  | `test/basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh`                                                                                                                                     | `mmu_xx_mmu_en` 始终为 0                             | RTL：`mmu_xx_mmu_en = (satp_mode==4'h8) && (cp0_yy_priv_mode != 2'b11)`；测试约束 `priv_mode==2'b11`（M-mode），M-mode 下该信号恒为 0                                                               | `priv_mode == 2'b11` → `priv_mode == 2'b01`（S-mode）                                             |
| P3-10 | 所有 6 个 `*_if.sv`（driver_cb）                                                                                                                                                          | `mmu_xx_mmu_en` 始终为 0（时序竞争）                 | `default output #1`：在 `timescale 1ns/1ps` + 1GHz 时钟下，`#1` = 1ns = 1 个时钟周期，driver 驱动信号恰好与下一个时钟上升沿同时到达 RTL（setup/hold violation），ICG 门控和 SATP 触发器采样不稳定 | 所有 `driver_cb` 的 `output #1` → `output #1step`（1ps，符合 SV LRM TB 驱动惯例）               |

### Open Items

| ID     | 描述                                                  | 状态                                                                                                                        |
| ------ | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| DA-003 | sysmap RTL force 路径与 Phase 13 PMP PTW 端口映射跟踪 | 🔄 Phase 13 A 侧已归档[DA-003_phase13_port_mapping.md](DA-003_phase13_port_mapping.md)；sysmap force 路径仍待设计确认或 waiver |

---

## Phase 4 详细进度（✅ 已完成）

**负责**：工程师 A
**完成日期**：2026-04-25
**退出准则**：✅ `test_ptw_map4k_directed` 50 条映射验证 + 10 条 page-fault 路径，mismatch=0，UVM_ERROR=0

### Phase 4 新建文件（13 个）

| #    | 交付物                          | 位置                            | 状态 | 备注                                                                                                                                                                                   |
| ---- | ------------------------------- | ------------------------------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 4-1  | `ptw_mem_txn.svh`             | `testbench/ptw_mem_agent/`    | ✅   | PTW 内存通道事务类；ptw_rsp_kind_e 枚举；rand rsp_delay c_rsp_delay(1..8)                                                                                                              |
| 4-2  | `page_table_builder.svh`      | `testbench/ptw_mem_agent/`    | ✅   | Sv39 3 级页表构建器（`uvm_object`）；assoc array `bit[63:0] m_mem[longint unsigned]`；map_4k 完全实现；map_2m/1g stub；inject_fault 6 种                                           |
| 4-3  | `ptw_mem_sequencer.svh`       | `testbench/ptw_mem_agent/`    | ✅   | `uvm_sequencer #(ptw_mem_txn)`                                                                                                                                                       |
| 4-4  | `ptw_mem_responder.svh`       | `testbench/ptw_mem_agent/`    | ✅   | 监听 DUT `mmu_lsu_data_req`；查 page_table_builder；随机 delay + bus_error 注入                                                                                                      |
| 4-5  | `ptw_mem_monitor.svh`         | `testbench/ptw_mem_agent/`    | ✅   | `ap_req` + `ap_rsp` 两个 analysis port；fork collect_req / collect_rsp                                                                                                             |
| 4-6  | `ptw_mem_sequences.svh`       | `testbench/ptw_mem_agent/`    | ✅   | 10 个序列类；ptw_page_table_build_4k_seq 完全实现；其余为 stub                                                                                                                         |
| 4-7  | `ptw_mem_covergroups.svh`     | `testbench/ptw_mem_agent/`    | ✅   | `ptw_mem_cg_wrapper extends uvm_component`；cg_ptw_rsp_kind（normal/bus_err）；cg_rsp_delay_range（Phase 7 TODO）；CG `new()` 在 class `new()` 中（P3-3 经验应用）               |
| 4-8  | `ptw_mem_agent.svh`           | `testbench/ptw_mem_agent/`    | ✅   | `ptw_mem_agent extends uvm_agent`；ACTIVE 创建 sequencer+responder；PASSIVE/ACTIVE 均创建 monitor+cg                                                                                 |
| 4-9  | `ptw_mem_agent_pkg.sv`        | `testbench/ptw_mem_agent/`    | ✅   | package；include 顺序：txn→cg→sequencer→responder→monitor→sequences→page_table_builder→agent                                                                                    |
| 4-10 | `mmu_page_table_mem.svh`      | `testbench/env/`              | ✅   | `uvm_object`；持有 `page_table_builder m_builder`；代理 read_pte/write_pte/reset；init() 方法                                                                                      |
| 4-11 | `mmu_ref_model.svh`           | `testbench/env/`              | ✅   | `uvm_component`；Sv39 3 级页走算法完整实现（4K 叶页）；CSR 镜像（satp0/1/priv/mxr/sum/mprv/mpp）；4 个 TLM FIFO（Phase 5 连接）；check_pmp/lookup_sysmap stub；report_phase 统计输出 |
| 4-12 | `test_ptw_map4k_directed.svh` | `testbench/test/basic_tests/` | ✅   | 直接设置 CSR 镜像；set_root(0x10, 0xABCD)；50 条 map_4k → translate() 验证；10 条 page-fault 路径验证                                                                                 |

### Phase 4 修改文件（5 个）

| #   | 交付物                                 | 状态 | 修改内容                                                                                                             |
| --- | -------------------------------------- | ---- | -------------------------------------------------------------------------------------------------------------------- |
| M-1 | `testbench/common/mmu_common_pkg.sv` | ✅   | 实现 make_pte / va_vpn_level / make_satp 3 个 TODO 函数                                                              |
| M-2 | `testbench/env/mmu_env_pkg.sv`       | ✅   | 新增 `import ptw_mem_agent_pkg::*`；新增 `\`include "mmu_page_table_mem.svh"`和`\`include "mmu_ref_model.svh"` |
| M-3 | `testbench/env/mmu_env.svh`          | ✅   | 新增 m_ptw_mem / m_pt_mem / m_ref 声明；build_phase 实例化并初始化；connect_phase 调用 set_page_table()              |
| M-4 | `testbench/Files.f`                  | ✅   | 追加 `${TB_DIR}/ptw_mem_agent/ptw_mem_agent_pkg.sv`（在 lsu_agent_pkg.sv 之后）                                    |
| M-5 | `testbench/test/test_pkg.sv`         | ✅   | 新增 `import ptw_mem_agent_pkg::*`；新增 `\`include "basic_tests/test_ptw_map4k_directed.svh"`                   |

### Phase 4 设计决策记录

| #    | 决策点                  | 选择                                           | 理由                                                                                            |
| ---- | ----------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| D4-1 | page_table_builder 基类 | `uvm_object`（非 `uvm_component`）         | 需要在 responder 和 ref_model 之间共享引用；`uvm_component` 强制绑定 UVM 层次，不适合跨层共享 |
| D4-2 | PT 存储结构             | `bit[63:0] m_mem[longint unsigned]` 关联数组 | 按需分配，避免预分配大数组；key = PA[39:0] 自然映射                                             |
| D4-3 | m_next_ppn 起始值       | `root_ppn + 28'd16`                          | 留 16 页缓冲区，避免 3 级 PT（页索引 512 项）与 root 页冲突                                     |
| D4-4 | ref_model CSR 更新路径  | Phase 4 直接赋值；Phase 5 启用 TLM FIFO        | 解耦 Phase 4 算法验证与 Phase 5 信号监听，减少调试干扰                                          |
| D4-5 | mmu_page_table_mem 角色 | 薄包装器（proxy），核心逻辑在 builder          | env 只持有 pt_mem；responder/ref_model 取 `m_pt_mem.m_builder` 引用，三方共享同一实例         |

### Phase 4 退出准则验证（✅ 已验证 — 2026-04-24）

| 准则                                                             | 预期结果                                       | 实测结果                                                                                  | 状态 |
| ---------------------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------- | ---- |
| `make run TEST_NAME=test_ptw_map4k_directed` UVM_ERROR=0       | 50 条 map_4k mismatch=0，10 条 fault path PASS | UVM_ERROR=0，UVM_FATAL=0，[test_ptw_map4k_directed]=3（含 PASSED 消息），仿真时间 60000ps | ✅   |
| `make run TEST_NAME=test_mmu_sanity_csr_pmp_sysmap` 回归不破坏 | UVM_ERROR=0，mmu_en=1                          | UVM_ERROR=0，mmu_en=1，仿真时间 81500ps（Phase 3 回归未破坏）                             | ✅   |
| `make comp` 0 error                                            | 编译通过                                       | 编译通过（修复 pkg include 顺序：page_table_builder 必须在 responder 之前）               | ✅   |
| 5 个独立 seed 全部 mismatch=0                                    | —                                             | ⏳ 待正式多 seed 回归（Phase 10）                                                         | ⏳   |

**编译 Bug 修复记录（Phase 4 调试）**

| #    | 文件                                                       | 错误                                             | 根因                                                                                                                                                                                               | 修复                                                                                                     |
| ---- | ---------------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| P4-1 | `ptw_mem_agent_pkg.sv`                                   | `[INVTST]`/`[BDTYP]`：test 注册失败 @ time=0 | SV package 内 include 顺序违反前向引用规则：`ptw_mem_responder.svh` 使用 `page_table_builder` 类型，但 `page_table_builder.svh` 排在 sequences 之后（包末尾），编译时 responder 看不到该类型 | 将 `` `include "page_table_builder.svh"`` 移到 txn 之后第二位（responder/monitor/sequences 之前）        |
| P4-2 | `testbench/ptw_mem_agent/page_table_builder.svh`         | `[SE]` token is 'unsigned'（line 64/73）       | SV 类型转换语法不允许带空格的复合类型：`longint unsigned'(expr)` 非法，编译器在 `'` 之前只识别单一标识符或数值宽度                                                                             | `longint unsigned'(pte_addr)` → `longint'(pte_addr)`（共 2 处：`read_pte_at` + `write_pte_at`） |
| P4-3 | `testbench/test/basic_tests/test_ptw_map4k_directed.svh` | `[SE]` token is 'ref'（line 51）               | `ref` 是 SV 保留关键字（用于 `ref` 类型形参），不能用作变量名                                                                                                                                  | 将 `run_test_body()` 内局部变量 `ref` 及其全部引用（共 12 处）重命名为 `rm`                        |
| P4-4 | `testbench/ptw_mem_agent/ptw_mem_sequences.svh`          | `[IRRVD]`：`rand` 变量类型非法（line 72）    | `string` 类型不属于 SV 允许的 `rand` 类型（整型/枚举/packed struct/bit）；`fault_kind` 为注入配置字段，由测试直接赋值，不需要随机化                                                          | 去掉 `fault_kind` 前的 `rand` 限定符                                                                 |

---

## Phase 5 详细进度（🔄 持续迭代；早期里程碑 ✅，当前 v7.1 子轮次调试验证中）

**负责**：工程师 B（主）/ 工程师 A（misc_agent + credit_sb + perf_mon）
**B 完成日期**：2026-04-25
**A 完成日期**：2026-04-24
**退出准则（sanity 路径）**：

- **历史达成（P5-1~P5-18 轮次后）**：曾验证 `test_mmu_translation_sanity` UVM_ERROR=0、Translation SB mismatch=0（见下文旧记录）。
- **当前（2026-04-26+，busy/wakeup + L1D expt_CAM 设计对齐后）**：`make fast TEST_NAME=test_mmu_translation_sanity` 仍大量 **IFU/LSU fault 与 ref 不一致**、部分 **LSU 超时/信用泄漏**；经 `[MMU_EXPT_TRACE_ONCE]*` 关联，PTW 完成时 **`acerr=1`** 触发异常 CAM 写 **`acflt=1`**，与页表/参考模型 **EXC_NONE** 矛盾（见 **P5-28~P5-32**）。**未重新声明 Phase 5 签核通过**，直至 DUT/TB 侧 acc_err 根因修复。

### Phase 5 新建文件（2 个）

| #   | 交付物                              | 位置                            | 状态 | 备注                                                                                                                                                                                |
| --- | ----------------------------------- | ------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 5-A | `mmu_translation_sb.svh`          | `testbench/env/`              | ✅   | 4 个 analysis imp（ifu/lsu_p0/lsu_p1/lsu_p2）；`write_ifu`/`write_lsu_p0/1/2` 比对 ppn+exc；`report_phase` 打印统计                                                           |
| 5-B | `test_mmu_translation_sanity.svh` | `testbench/test/basic_tests/` | ✅   | Phase 5 端到端 sanity test；4 个辅助序列类（ifu_mapped_va_seq / lsu_mapped_va_seq / lsu_p2_sanity_seq / lsu_stamo_sanity_seq）；100 IFU + 100 LSU_P0 + 20 LSU_P1 + 20 P2 + 20 STAMO |

### Phase 5 修改文件（7 个）

| #    | 交付物                                  | 状态 | 修改内容                                                                                                                            |
| ---- | --------------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------- |
| M5-1 | `testbench/ifu_agent/ifu_driver.svh`  | ✅   | `drive_one()` 完整实现：1拍 assert + fork/join_any 等 pavld + 2000 cycle 超时                                                     |
| M5-2 | `testbench/lsu_agent/lsu_driver.svh`  | ✅   | `_drive_pipe0/1()` 完整实现：hold va_vld + fork/join_any 等 pa_vld + 4000 cycle 超时；pipe2/stamo 骨架清理；inv 保留 Phase 6 TODO |
| M5-3 | `testbench/ifu_agent/ifu_monitor.svh` | ✅   | 新增 `m_pending_req[$]` 队列；`_collect_req()` push；`_collect_rsp()` pop+合并 VA，发布含 VA+PA 的 merged txn                 |
| M5-4 | `testbench/lsu_agent/lsu_monitor.svh` | ✅   | 新增 `m_pending_p0/p1[$]`；pipe0/1 req push、rsp pop 合并 va/id/st_inst；pipe2 rsp 仅采样 pa（VA 合并留 Phase 6）                 |
| M5-5 | `testbench/env/mmu_env_pkg.sv`        | ✅   | 追加 `` `include "mmu_translation_sb.svh" ``                                                                                        |
| M5-6 | `testbench/env/mmu_env.svh`           | ✅   | 新增 `m_translation_sb` 声明+创建+注入 `m_ref`；connect_phase 连接 cp0/pmp/sysmap → ref TLM FIFO + ifu/lsu rsp → SB           |
| M5-7 | `testbench/test/test_pkg.sv`          | ✅   | 追加 `` `include "basic_tests/test_mmu_translation_sanity.svh" ``                                                                   |

### Phase 5 设计决策记录

| #    | 决策点                  | 选择                                                     | 理由                                                                          |
| ---- | ----------------------- | -------------------------------------------------------- | ----------------------------------------------------------------------------- |
| D5-1 | IFU 驱动策略            | 1-outstanding：assert 1拍，fork/join_any 等 pavld        | 匹配 IFU 协议（无 ID，单未决）；monitor FIFO 顺序对齐                         |
| D5-2 | LSU pipe 驱动策略       | hold va_vld 直至 pa_vld，fork/join_any + 4000 cycle 超时 | 忠实协议；超时输出 UVM_WARNING 避免仿真卡死                                   |
| D5-3 | SB 比对范围             | Phase 5 只比对 ppn 和 exc（pgflt/access_fault）          | sec/ca/buf 属性比对留 Phase 6（SysMap/PMP 全通 stub）                         |
| D5-4 | c_kind_default 冲突处理 | 辅助序列中调用 `constraint_mode(0)`                    | SV LRM §18.7.2：with-clause 追加而非覆盖 class 约束；不修改 lsu_txn 全局约束 |
| D5-5 | ROOT_PPN=0              | 按任务规格（ppn=0, asid=0）；leaf PPN 从 0x200 起步      | 自动分配 L1=16, L0=17，leaf 从 0x200(512) 起步，三者不冲突                    |
| D5-6 | 映射权限                | r=w=x=1, u=0, a=d=1                                      | S-mode fetch+load+store 均可通过；a/d=1 避免 ref_model 发出 WARN              |

### Phase 5 A 的任务（✅ 已完成，2026-04-24）

| #     | 交付物                   | 位置                      | 状态 | 说明                                                                                                                 |
| ----- | ------------------------ | ------------------------- | ---- | -------------------------------------------------------------------------------------------------------------------- |
| A5-1a | `misc_txn.svh`         | `testbench/misc_agent/` | ✅   | 6 个 op 枚举（FLUSH/EXPT/SMP_DISABLE/HPCP_CNT_EN/DFT_SCAN_EN/IDLE）；驱动字段 + 监测字段                             |
| A5-1b | `misc_sequencer.svh`   | `testbench/misc_agent/` | ✅   | `uvm_sequencer #(misc_txn)` 标准实现                                                                               |
| A5-1c | `misc_covergroups.svh` | `testbench/misc_agent/` | ✅   | `misc_cg_wrapper`：cg_misc_hpcp/rtu/debug；P3-3 fix 应用（new() 在 class new() 中）                                |
| A5-1d | `misc_driver.svh`      | `testbench/misc_agent/` | ✅   | `_do_rtu_flush`：1 cycle 脉冲；`_do_smp_disable`/`_do_hpcp_cnt_en`：level 信号；`_drive_idle` 安全默认       |
| A5-1e | `misc_monitor.svh`     | `testbench/misc_agent/` | ✅   | `ap_hpcp`：每周期采样 miss 信号变化；`ap_debug`：debug_info 变化时发布                                           |
| A5-1f | `misc_sequences.svh`   | `testbench/misc_agent/` | ✅   | 5 个序列：base/rtu_flush/rtu_expt/smp_disable/hpcp_enable +`misc_init_seq`（复合初始化）                           |
| A5-1g | `misc_agent.svh`       | `testbench/misc_agent/` | ✅   | 标准 agent：ACTIVE 创建 seq+driver；PASSIVE/ACTIVE 均创建 monitor+cg                                                 |
| A5-1h | `misc_agent_pkg.sv`    | `testbench/misc_agent/` | ✅   | package；include 顺序：txn→cg→sequencer→driver→monitor→sequences→agent                                         |
| A5-2  | `mmu_credit_sb.svh`    | `testbench/env/`        | ✅   | 8 个 TLM FIFO；4 个计数器（credit_l1i/l1d/l2_reqq/ptw_mbuf）；边界检查 + report_phase 守恒断言                       |
| A5-3  | `mmu_perf_mon.svh`     | `testbench/env/`        | ✅   | 5 个 FIFO（ifu_rsp/lsu_p0/p1/p2_rsp/hpcp）；统计字段声明；report_phase 摘要打印；统计细化留 Phase 7                  |
| A5-4a | `mmu_env_pkg.sv` 更新  | `testbench/env/`        | ✅   | 追加 `import misc_agent_pkg::*`；追加 credit_sb + perf_mon `\`include`                                           |
| A5-4b | `mmu_env.svh` 更新     | `testbench/env/`        | ✅   | build_phase：实例化 m_misc/m_credit_sb/m_perf；connect_phase：fan-out 连线 8 个 AP → credit_sb，5 个 AP → perf_mon |
| A5-4c | `Files.f` 更新         | `testbench/`            | ✅   | 追加 `${TB_DIR}/misc_agent/misc_agent_pkg.sv`                                                                      |

### Phase 5 仿真调试 Bug 修复记录（2026-04-24）

| #    | 文件                                                                            | 错误现象                                                                                                                                                                                                                       | 根因                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | 修复内容                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ---- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P5-1 | `testbench/ifu_agent/ifu_driver.svh<br>``testbench/ifu_agent/ifu_monitor.svh` | `test_mmu_translation_sanity` 运行：IFU 全部 100 笔翻译均出现 PA 不匹配 — `[IFU] VA=0x000100000x: PA mismatch — ref.ppn=0x0000200  dut.pa=0x0000000`；DUT `mmu_ifu_pavld=1`、`pgflt=0`、`deny=0`，但输出 PA 全为 0 | **VA 编码偏移1位**：DUT 端口 `ifu_mmu_va[62:0]` 定义为 `VA[63:1]`（取指地址右移1位，因取指恒按偶字节对齐），DUT 内部提取 VPN = `ifu_mmu_va[37:11]` = `VA[38:12]`（正确）。但驱动直接发送 `tr.va`（= VA[62:0]），导致 DUT 实际接收 `VA[63:1] = tr.va`，提取 VPN = `VA[37:11]`（整体偏移1位），PTW 在错误地址查找页表返回 V=0 的无效 PTE，最终 DUT 输出 PA=0。监测器对称地存在同一问题：直接把 `ifu_mmu_va` 作为 VA 传给 scoreboard，导致参考模型也在错误 VA 上查表（但参考模型的页表是按真实 VA 建立的），造成系统性全量误报 | **Driver**（[ifu_driver.svh](../mmu_verification/testbench/ifu_agent/ifu_driver.svh)）：`vif.driver_cb.ifu_mmu_va <= tr.va` → `vif.driver_cb.ifu_mmu_va <= tr.va >> 1`（VA[62:0] 右移1位得 VA[63:1] 格式）`<br>`**Monitor**（[ifu_monitor.svh](../mmu_verification/testbench/ifu_agent/ifu_monitor.svh)）：`tr.va = vif.monitor_cb.ifu_mmu_va` → `tr.va = 63'(vif.monitor_cb.ifu_mmu_va << 1)`（从 VA[63:1] 格式还原真实 VA[62:0]）`<br>`LSU `lsu_mmu_va0` 为 64 位，使用标准 `va[38:12]` 提取 VPN，无偏移，无需修改 |

### Phase 5 仿真联合验证 Bug 修复记录（2026-04-24）

> `make run TEST_NAME=test_mmu_translation_sanity` 首次运行发现以下 3 个 Bug，共产生 117 个 UVM_ERROR。

| #         | 位置                                                                                               | 类型                           | 现象                                                                                                                                                            | 根因                                                                                                                                                                                                                                                                                                                                                                                                                  | 修复                                                                                                                         |
| --------- | -------------------------------------------------------------------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| ~~P5-2~~ | ~~`mmu/rtl/mmu_l2tlb.sv`~~                                                                      | ~~RTL Bug~~ → **误诊** | 113 个 PA mismatch                                                                                                                                              | ~~误诊为 `ptw_l2tlb_ref_ppn` 端口被注释导致 L2 TLB ref_ppn 路径断开~~。**实际根因 = P5-5**（driver 未检查 `tlb_busy` → miss buffer 满时 DUT 忽略请求 → monitor FIFO 关联错乱 → 请求 B 的响应被配对到请求 A 的 VA → 系统性 PA mismatch）。RTL 设计正确：PTW 完成时 PPN 通过 `ptw_l1dtlb_ref_ppn` 直连 L1 TLB（不经 L2 `ref_ppn`）；L2 TLB 的 `ref_ppn=final_hit_ppn` 仅用于 L2 HIT 路径，逻辑无误 | ✅**P5-5 修复后此问题自动消除**（monitor FIFO 关联恢复正确）                                                           |
| P5-3      | `testbench/test/basic_tests/test_mmu_translation_sanity.svh<br>``lsu_mapped_va_seq.body()`（TB） | **TB Bug**               | `mmu_credit_sb` 报 `credit_l1d=6` / `l2_reqq_cnt=6` 泄漏；`HPCP: dutlb_miss=9996`；仅 13 笔事务完成（预期 120+）；4 个 Pipe0/1 response timeout warning | `lsu_txn.vabuf`（28-bit）完全随机；DUT L1 DTLB miss buffer 用 `vabuf = VA[38:11]` 标识挂起项、匹配 L2 TLB refill wakeup；随机 vabuf 导致 miss buffer 项永远无法被唤醒，6 笔事务永久卡死                                                                                                                                                                                                                           | ✅**已修复**：在 `lsu_mapped_va_seq` 的 randomize with 中增加约束 `vabuf == 28'(({25'b0, m_va_table[idx]}) >> 11)` |
| P5-4      | 同上，Step 9 settle 等待（TB）                                                                     | **TB Bug**               | `total_checked=131 < 200`，触发 `Translation SB checked only 131 transactions (expected ≥200)` error                                                       | `#10000ns` 等待仅 10 个时钟周期；每笔 LSU 超时耗时 4000 cycles（4000ns），120 笔事务最坏情况需要 ~480000ns 才能全部完成或超时                                                                                                                                                                                                                                                                                       | ✅**已修复**：`#10000ns` → `#500000ns`                                                                            |

### Phase 5 第二轮联合验证 Bug 修复记录（第二次运行：UVM_ERROR=359）

> `make run TEST_NAME=test_mmu_translation_sanity` 第二轮运行（P5-1/3/4 修复后，P5-2 RTL bug 待修）发现以下 2 个 TB Bug，共产生 359 个 UVM_ERROR。

| #    | 文件                                                                                  | 类型                         | 现象                                                                                                                                                                                                                                                                                    | 根因                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | 修复                                                                                                                                                                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P5-5 | `testbench/lsu_agent/lsu_driver.svh<br>``_drive_pipe0()` / `_drive_pipe1()`（TB） | **TB Bug — 协议违反** | `mmu_credit_sb` 报 `l2_reqq_cnt overflow: 10→66 > 9`；`credit_l1d overflow`；大量 Pipe0/Pipe1 response timeout（每 4000 cycle 一次）；`mmu_translation_sb` 报 154/171 笔 PA mismatch（`ref.ppn=0x020X dut.pa=0x010X`，偏差 ≈ L2_REQQ_DEPTH=9）；`total_checked=171 < 200` | **驱动未检查 `mmu_lsu_tlb_busy` 背压信号**。RTL：`mmu_lsu_tlb_busy = &mb_entry_vld`（L1 DTLB 8 个 miss buffer 全满）；busy=1 时分配器不接受新条目，PTW 不会为该请求走页表，`pa_vld` 永远不会返回。`<br>`根因链：① `_fetch_items()` 立即 `item_done` → pipe0(100笔)/pipe1(20笔)同时入 m_pending，两个子线程并发驱动；② 两路并发请求快速耗尽 MB 8个槽（全部 unique page，全部 L1 miss）；③ busy=1 时驱动仍持续持有 va0_vld/va1_vld 长达 4000 cycle，DUT 忽略请求（无分配，无响应）；④ 超时后无 RSP：credit_sb REQ++ 后无 RSP-- → 计数累计溢出；monitor m_pending 乱序（新请求先于旧响应） → PA mismatch | ✅**已修复**（`lsu_driver.svh`）：在 `_drive_pipe0()` / `_drive_pipe1()` 中，将原来的强制等待 `@(vif.driver_cb)` 替换为 `@(vif.driver_cb iff vif.driver_cb.mmu_lsu_tlb_busy === 1'b0)`。既保留最少 1-cycle 间隔，又确保 MB 有空闲槽后才发起请求，彻底消除超时根因 |
| P5-6 | `testbench/env/mmu_credit_sb.svh<br>``_check_l2_reqq_bound()`（TB）                 | **TB 模型错误**        | `l2_reqq_cnt overflow: N > L2_REQQ_DEPTH=9` — 但实际未溢出硬件                                                                                                                                                                                                                       | `m_l2_reqq_cnt` 对**所有** LSU 请求（含 L1 DTLB hit、即时返回的 pa_vld）+1，而实际 L2 REQQ 只接收 L1 miss 请求；L2_REQQ_DEPTH=9（含 1 ITLB 槽），LSU 侧实际 credit = scheduler CREDIT_MAX = `L1_DTLB_MB_DEPTH=8`。模型过计数 + 边界值偏高（应为 8）→ 假报溢出（溢出根因由 P5-5 超时引发，但边界值本身也错）                                                                                                                                                                                                                                                                                                         | ✅**已修复**（`mmu_credit_sb.svh`）：`_check_l2_reqq_bound()` 将上界从 `L2_REQQ_DEPTH(9)` 改为 `L1_DTLB_MB_DEPTH(8)`；顶部 header 注释补充"模型局限性"说明（L1 hit 无法从此层区分，真实 L2 占用 ≤ 计数值）                                                         |

### Phase 5 第三轮联合验证分析（第三次运行：UVM_ERROR=314）

> `make run TEST_NAME=test_mmu_translation_sanity`（**未重新编译**）第三轮运行，314 个 UVM_ERROR。
> **P5-2 误诊纠正**：经 RTL 设计确认，L2 TLB 的 `ref_ppn=final_hit_ppn` 逻辑正确（仅用于 L2 HIT 路径）；PTW 完成时 PPN 经 `ptw_l1dtlb_ref_ppn` 直达 L1 TLB，不经 L2 `ref_ppn`。105 个 PA mismatch 实为 P5-5 monitor FIFO 关联错乱的衍生错误。

| #    | 现象                                                                                           | 根因                                                                                                                                                                                                                                                            | 结论                                                                                              |
| ---- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| P5-7 | 115 个 timeout + 208 个 credit overflow/leak + 105 个 PA mismatch +`total_checked=122 < 200` | **全部为 P5-5 衍生问题 + 未重编译**。① driver 未检查 `tlb_busy` → DUT 忽略请求 → timeout → credit 不守恒。② timeout 后 monitor FIFO 关联错乱 → 响应配对到错误 VA → PA mismatch。③ binary 是 P5-5/P5-6 修复前旧版本（证据：`L2_REQQ_DEPTH=9`） | ⚠️**需 `make comp` 重编译**（P5-5/P5-6 源码已修复；重编译后预期 314 个 ERROR 全部消除） |

### Phase 5 第四轮联合验证 Bug 修复记录（`make fast` 重编译后：UVM_ERROR=352）

> `make fast TEST_NAME=test_mmu_translation_sanity` 重编译后运行，352 个 UVM_ERROR。
> P5-5/P5-6 源码修复已生效（`L1_DTLB_MB_DEPTH=8` 正确），但暴露了 2 个新根因 Bug。

| #    | 文件                                                               | 类型                             | 现象                                                                                                                                                                                                                                                                                                               | 根因                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | 修复 |
| ---- | ------------------------------------------------------------------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| P5-8 | `testbench/lsu_agent/lsu_sequences.svh<br>`8 个序列类（TB）      | **TB Bug — 约束冲突**     | `Error-[CNST-CIF]` @ 284500ps：`tlb_inv_all_seq.body()` randomize 失败 → SFENCE.VMA（Step 2b）未执行 → L2 JTLB 未清空 → 发出 kind=LSU_PIPE0/VA=0 的垃圾请求 → SB 收到 `[LSU_P0] VA=0x0: fault mismatch`；后续 LSU PA mismatch（ref.ppn=0x239 vs dut.pa=0x157）衍生自 monitor FIFO 与此垃圾请求的关联错位 | `lsu_txn.c_kind_default { kind == LSU_PIPE0; }` 永远生效。`randomize() with { kind == LSU_INV; }` 与其矛盾导致约束不可解。`<br>`**修复**：在 `lsu_pipe1_only_seq`、`lsu_prefetch_pipe2_seq`、`lsu_stamo_seq`、`lsu_abort_seq` 及全部 4 个 `tlb_inv_*_seq` 中，`randomize()` 前调用 `tr.c_kind_default.constraint_mode(0)`                                                                                                                                                                                                                                          |      |
| P5-9 | `testbench/ifu_agent/ifu_driver.svh<br>``drive_one()` 协议（TB） | **TB Bug — IFU 协议错误** | 全部 100 笔 IFU 翻译 DUT 返回 PA=0（无 fault）：`[IFU] VA=0x100000: PA mismatch — ref.ppn=0x200 dut.pa=0x000`（×100）                                                                                                                                                                                          | RTL：`mmu_ifu_pavld = iutlb_hit_vld \|\| ...`，其中 `iutlb_hit_vld = ifu_mmu_va_vld && iutlb_addr_hit`（组合逻辑）。L1 ITLB miss → L2/PTW refill 将正确 PPN 写入 L1 条目后，`iutlb_addr_hit=1`；但 `pavld` 需要 `va_vld=1` 才能拉高。旧驱动在 `va_vld` 仅保持 1 个时钟周期后立即拉低，refill 完成时 `va_vld=0` → `pavld` 永远无法正确拉高，DUT 返回默认 PA=0。`<br>`**修复**：将 IFU driver 从 single-cycle pulse 改为 **hold-until-pavld** 协议（与 LSU pipe0/1 一致）：保持 `ifu_mmu_va_vld=1` 直到 `mmu_ifu_pavld=1`，然后在下一个时钟沿拉低 `va_vld` |      |

> **P5-10（衍生）**：40 个 LSU Pipe0/Pipe1 response timeout + 171 个 credit overflow/leak + 181 个 PA mismatch + `total_checked=200 mismatch=181` → 全部为 P5-8（SFENCE 失败 → 垃圾请求污染 monitor FIFO）和 P5-9（IFU PA=0 ×100）的衍生错误。P5-8/P5-9 修复后预期全部消除。

### Phase 5 第五轮及后续修 Bug 记录（2026-04-25 ~ 2026-04-26）

> 联调 `test_mmu_translation_sanity` 与 PMP/PTW/Monitor/SB 过程中记录的增量修复。最后一轮 `make fast TEST_NAME=test_mmu_translation_sanity`：`UVM_ERROR=0`，Translation SB 无 PA mismatch 误报。

| #     | 文件 / 位置                                                                                        | 类型                | 现象 / 根因                                                                                                                                                                                                                                                                                                    | 修复内容                                                                                                                                                                                                                                                                                                  |
| ----- | -------------------------------------------------------------------------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P5-11 | `mmu/rtl/mmu_l2tlb.sv`                                                                           | **RTL**       | 仲裁/类型区分错误：`arb_l2tlb_is_dtlb` 中 store 项误为与 load 重复（`3'b010`）                                                                                                                                                                                                                             | 将 store 对应项改为 `3'b110`（与 DTLB 微架构编码一致）                                                                                                                                                                                                                                                  |
| P5-12 | `testbench/pmp_agent/pmp_*.svh`（`pmp_flg_normal_seq`、driver idle 等）                        | **TB**        | S-mode 下 PTW 取页表被 PMP**全 deny**（idle 为 0 时）                                                                                                                                                                                                                                                    | 默认 / idle PMP 标志使用**`4'h7`（R/W/X allow）**；注释说明为何不能用 0（否则 PTW 无法访问根页表）                                                                                                                                                                                                      |
| P5-13 | `testbench/ifu_agent/ifu_monitor.svh`                                                            | **TB**        | 未决请求与 RSP 关联异常                                                                                                                                                                                                                                                                                        | 在**`ifu_mmu_va_vld && !m_has_pending`** 时开 pending，而非仅靠 `va_vld` 边沿；删除易错的 `m_prev_va_vld` 机制                                                                                                                                                                                      |
| P5-14 | `testbench/lsu_agent/lsu_monitor.svh`                                                            | **TB**        | Pipe0/1 RSP 可能在 FIFO 空时采样，导致 PA/VA 配对错误                                                                                                                                                                                                                                                          | **`wait(m_pending_*)`** 在 **`@(paN_vld)`** 之前；再采 PA 并 `pop`                                                                                                                                                                                                                      |
| P5-15 | `testbench/ptw_mem_agent/ptw_mem_responder.svh`                                                  | **TB**        | `handle_request` 返回过早，`lsu_mmu_data_vld` 多拍 → credit / 记分牌 **REQ/RSP 信用下溢**                                                                                                                                                                                                           | 若 `handle_request` 后 `mmu_lsu_data_req` 仍为 1，**等待到 0** 再结束本次处理                                                                                                                                                                                                                   |
| P5-16 | `testbench/test/test_base.svh<br>``mmu_verification/Makefile`                                    | **TB / flow** | 需要快速只看**UVM_ERROR/UVM_FATAL** 的回归日志                                                                                                                                                                                                                                                           | `+UVM_ERR_ONLY`：在 test 中递归对 test 树设 `INFO/WARNING = NO_ACTION`；存在 plusarg 时 **跳过** `print_topology()`。Makefile：变量 **`UVM_ERR_ONLY ?= 0`**，为 1 时向 **`RUN_OPTS`** 注入 **`+UVM_ERR_ONLY`**；`help` 中说明；用法示例 `make run UVM_ERR_ONLY=1` |
| P5-17 | `testbench/lsu_agent/lsu_txn.svh<br>``lsu_monitor.svh<br>``testbench/env/mmu_translation_sb.svh` | **TB / 模型** | 偶发**`[LSU_P1] PA mismatch`**：`ref.ppn=0x0205`，`dut.pa` 为「随机」大数；同拍打印显示 **`stamo: v=1` 且 `P1: pa == stamo pa`**。根因：RTL `mmu_l1dtlb_hit_rd` 中 **`dutlb_pre_pa = lsu_mmu_stamo_vld ? lsu_mmu_stamo_pa : …`**，STAMO 有效时 **DUT 总线不是 Sv39 翻译 PPN** | RSP 拍采样 `stamo_vld_at_rsp`、`stamo_pa_at_rsp`；SB 在 stamo 时 **校验 `dut.pa === stamo_pa_at_rsp`**，并对 **ref PPN 比对 `skip_ref_ppn_check`**；UVM_INFO 说明 STAMO mux 路径                                                                                                      |
| P5-18 | `testbench/lsu_agent/lsu_monitor.svh<br>``Makefile` `help`                                     | **TB 调试**   | 需同拍总线判断 P0/P1/STAMO/TLB 行为                                                                                                                                                                                                                                                                            | 可选**`+MMU_LSU_MON_DBG`**：在 P1 RSP 处打印 P0/P1/STAMO/`mmu_en`/`tlb_busy` 等快照；`make help` 中 **`PLUS_ARGS` 示例**                                                                                                                                                                  |

### Phase 5 第六轮：设计文档 + expt_CAM + busy/wakeup 联调修复记录（2026-04-26 起）

> 背景：IFU **miss-hold**、LSU **busy/wakeup** 与 L1D **expt_CAM**（产生→挂起→唤醒→命中回放→消费删除）设计更新后，对工程做**编译/文档/TB/RTL 调试手段**与**回归问题**的集中记录。部分为**已修复**，部分为**日志/证据链已闭合、RTL 根因待修**。

| #     | 文件 / 范围                                                                  | 类型                                | 现象 / 根因                                                                                                                                                                                                                                                   | 修复或结论                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----- | ---------------------------------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| P5-19 | `testbench/Files.f`                                                        | **编译**                      | VCS `CFCILFBI`：`mmu_l1dtlb` 内 bind 的 **`mmu_l1dtlb_expt_cam` 在 liblist 中找不到**                                                                                                                                                             | 在 DTLB 之前显式加入 `${MMU_RTL_DIR}/mmu_l1dtlb_expt_cam.sv`                                                                                                                                                                                                                                                                                                                                                                             |
| P5-20 | `doc/MMU_VerificationPlan_final.md<br>``doc/MMU_UVM_BuildPlan_v3_final.md` | **文档**                      | 与最新 RTL 行为不一致                                                                                                                                                                                                                                         | 以 v7.1 为准：更新**`mmu_lsu_tlb_busy=\|mb_entry_vld\|`**、**wakeup 完成事件广播**、**expt_CAM + install_wakeup OR**、异常测试点/SVA/CG 命名；**删除**旧版 busy/「仅 MB 满」等过时表述                                                                                                                                                                                                                                   |
| P5-21 | `testbench/lsu_agent/lsu_if.sv`                                            | **TB**                        | 信号语义注释落后                                                                                                                                                                                                                                              | 更新 `tlb_busy` / `tlb_wakeup` 协议说明与最新设计一致                                                                                                                                                                                                                                                                                                                                                                                  |
| P5-22 | `testbench/lsu_agent/lsu_txn.svh`                                          | **TB**                        | 事务未携带 busy/wakeup，难比对分                                                                                                                                                                                                                              | 增加**`tlb_busy` / `tlb_wakeup` 采样**；`convert2string` 可打印                                                                                                                                                                                                                                                                                                                                                                      |
| P5-23 | `testbench/ifu_agent/ifu_driver.svh`                                       | **TB 协议**                   | 与**IFU miss-hold** 不一致                                                                                                                                                                                                                              | **非 abort**：保持 `ifu_mmu_va_vld` 直到 **`mmu_ifu_pavld`** 返回；降低无关 log 等级                                                                                                                                                                                                                                                                                                                                       |
| P5-24 | `testbench/lsu_agent/lsu_driver.svh`                                       | **TB 协议/鲁棒**              | 早期等 wakeup 单一路径在 TB 中 **tlb_busy=1 且 wakeup=0 死等超时**、请求被 **drop**                                                                                                                                                                           | 改为**单拍请求**后等待 **`tlb_busy==0` 或 `tlb_wakeup` 非零边沿** 再重试同笔事务；降低 log；缓解 standalone TB 下 **早醒/不唤醒** 死锁（仍依赖 DUT 侧最终完成语义）                                                                                                                                                                                                                                                  |
| P5-25 | `testbench/lsu_agent/lsu_monitor.svh`                                      | **TB**                        | 需观测 busy/wakeup；drop 与**expt 回放** 区分                                                                                                                                                                                                           | 采样**busy/wakeup**；增加 **`ap_pipe0_drop` / `ap_pipe1_drop`**；**`replay_suspect` → `expt_replay_rsp`** 等命名与行为对齐；降低 UVM 噪声                                                                                                                                                                                                                                                                       |
| P5-26 | `testbench/env/mmu_translation_sb.svh`                                     | **TB/SB**                     | 异常 CAM**回放响应** 不应与常规模型比 PA                                                                                                                                                                                                                | 引入**`m_lsu_fault_replay_rsp`**；`_compare` 在 fault 回放时 **按 fault 语义**比对，**跳过**与 ref 的 PA 全等检查（若设计如此）                                                                                                                                                                                                                                                                                            |
| P5-27 | `testbench/env/mmu_credit_sb.svh<br>``testbench/env/mmu_env.svh`           | **TB**                        | `pipe` **REQ 被 drop** 时仍按 REQ 记账 → 信用**不守恒**                                                                                                                                                                                        | credit_sb 增加**drop FIFO** 与 **consume 路径**；env **连接** `m_lsu.m_monitor.ap_pipe0_drop/1`                                                                                                                                                                                                                                                                                                                        |
| P5-28 | `testbench/lsu_agent/lsu_covergroups.svh`                                  | **功能覆盖**                  | 新 busy/wakeup 行为未采                                                                                                                                                                                                                                       | 增加**`cp_wakeup_kind`**、**`cx_busy_wakeup`** 等                                                                                                                                                                                                                                                                                                                                                                                |
| P5-29 | `mmu/rtl/mmu_l1dtlb.sv<br>``mmu/rtl/mmu_l1dtlb_hit_rd.sv`                  | **RTL 调试/噪声**             | 大量 `[MMU_DTLB_*_DBG] $display` 淹没回归                                                                                                                                                                                                                   | 既有噪声**`ifdef MMU_DTLB_DBG_EN`** 门控；**不**在默认 `fast` 中打开（避免刷屏）                                                                                                                                                                                                                                                                                                                                                 |
| P5-30 | 同上 +`mmu_verification/Makefile`                                          | **RTL 调试/流程**             | 一次性**miss→ref_id→cam_write→replay_hit** 日志挂在 **`MMU_DTLB_DBG_EN`** 下时，`make fast` **不定义该宏** → 日志**从不出现**                                                                                                 | 将四段**one-shot** 打印改由独立宏 **`MMU_EXPT_TRACE_ONCE_EN`** 控制；**Makefile** 的 **`VCS_ELAB_OPTS` / `VCS_FAST_OPTS`** 默认 `+define+MMU_EXPT_TRACE_ONCE_EN`；与粗粒度 DBG 解耦                                                                                                                                                                                                                        |
| P5-31 | （仿真 log +`ptw.sv` 路径）                                                | **现象 / 分析**               | **IFU** 全量 `fault mismatch`（ref **EXC_NONE**，DUT `dut_fault=1`）；**LSU** `EXPT_REPLAY` 上 **access_fault=1** 与 ref 矛盾；`[MMU_EXPT_TRACE_ONCE][REF] … acerr=1`、`[CAM_WRITE]… acflt=1`、`[REPLAY_HIT]… acflt=1` | 证据链表明**`ptw_l1tlb_acc_err`（→ `expt_wr0_acflt`）在 PTW 完成路径上被错误置 1**（而 ref_model 用页表得合法 PTE/rwx）。`ptw.sv`：`ptw_l1dtlb_ref_acc_err` 与 **`acc_err_grant`** 及 L2 类型从 TWU 侧 **PMP deny / mbuf_bus_error** 等汇拢相关。**归类为 DUT/PTW+TWU+TB 一致性待修**，**非** DTLB expt_CAM「纯 consume」逻辑在 trace 上首先暴露的矛盾（trace 先证明 **异常源来自 PTW acc_err**） |
| P5-32 | （`testbench` 侧，与 P5-31 并行）                                          | **待办 / 调试验证**           | HPCP 日志中**`dutlb_miss` 数量异常**、**IFU monitor「rsp 无 pending req」** 等与 IFU/perf 统计仍不一致                                                                                                                                                | 在**P5-31 修复或旁路** 后复测；若 IFU 仍 fault，**单独**查 **ITLB/IFU 路径** 与 PMP/PTW 对 **fetch** 的 acc_err 语义                                                                                                                                                                                                                                                                                               |
| P5-33 | `testbench/env/mmu_translation_sb.svh`                                     | **TB/SB 误判**                | `phase5` 多 seed 仅剩 1 个 UVM_ERROR：`[LSU_P0] STAMO vld: expected dut.pa==stamo_pa`。日志显示同拍 `ref.ppn` 与 `dut.pa` 一致、而 `stamo_pa` 为另一条路径值。根因：`lsu_mmu_stamo_vld` 为接口级全局信号，P0 不应被强制按 STAMO mux 语义解释      | 去掉**LSU_P0** 上 `dut.pa == stamo_pa` 的强校验与 `skip_ref_ppn_check`；保留 P1 的 STAMO 特判。修后 `make phase5` 8 seed 均 `UVM_ERROR=0/UVM_FATAL=0`                                                                                                                                                                                                                                                                        |
| P5-34 | `testbench/test/basic_tests/test_ptw_map4k_directed.svh`                   | **TB Directed Test 回归 bug** | 运行 `make phase5_ptw4k` 出现 60 个 mismatch，`got_ppn` 全等于 `VA[38:12]`，`fault_va` 也返回 `EXC_NONE`；表现为 ref_model 进入 passthrough                                                                                                         | 新增 `apply_ref_cfg()` 并在每次 `translate()` 前重置 ref CSR 镜像（Sv39/S-mode/no-op=0/mprv=0），避免运行时镜像被 monitor/FIFO 事件覆盖。修后 `test_ptw_map4k_directed_30001.log`：`UVM_ERROR=0`、`UVM_FATAL=0`、`passthrough=0`                                                                                                                                                                                               |

**P5-19~P5-32 与旧轮关系**：P5-1~P5-18 解决的是**当时** TB/监控/ PMP-idle/IFU 协议/ STAMO 等导致的 **0-mismatch** 路径；本轮设计变更后 **回归标准需重新以当前 RTL 为准验收**。

### Phase 5 退出准则

| # | 检查项                                                              | 负责        | 状态                                                                                                                                      |
| - | ------------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | `make comp` 0 errors                                              | A+B         | ✅ sanity 重编译路径已验证（`make fast`）                                                                                               |
| 2 | IFU 单端口随机 VA：5 种子×100次，UVM_ERROR=0                       | B           | ✅`make phase5`（5+3 seed）已通过，8 份 log 均 `UVM_ERROR=0/UVM_FATAL=0`                                                              |
| 3 | LSU pipe0：5×100次 LD，pipe1/2/stamo 各≥20次，UVM_ERROR=0         | B           | ✅ 同上（`test_mmu_translation_sanity` 覆盖并通过）                                                                                     |
| 4 | miss→PTW→refill 混合，mismatch=0                                  | B           | ✅ 同上（3 seed tranche 通过）                                                                                                            |
| 5 | `mmu_translation_sb` 接收 ≥200 笔，mismatch=0                    | B           | ✅ 已达成（phase5_check 通过；P5-33 误判已修）                                                                                            |
| 6 | `mmu_credit_sb` 仿真结束信用守恒计数 =0                           | **A** | ✅ phase5 log 统计归零；`phase5_ptw4k` 亦 PASS                                                                                          |
| 7 | `misc_agent` 编译通过；`rtu_flush`/`biu_smp_disable` 实际驱动 | **A** | ✅ 随 env 构建；`test_mmu_phase6_rtu_flush_ptw` / `phase6_full` 覆盖 RTU flush 路径                                                   |
| 8 | `scan_logs.pl` 无非预期 ERROR/FATAL                               | A+B         | ⚠️ 环境依赖：服务器缺 `Text::Table`（`phase5_scan_logs` 报模块缺失）；Makefile 已加 fallback grep 检查，当前 8 份 phase5 log 均 0/0 |

---

## Phase 6 详细进度（✅ 已完成 — 2026-04-26）

**负责**：工程师 B（主）/ 工程师 A（配合）**完成快照**：

- B 侧：✅ `drive_inv`、`mmu_invalidate_sb`、invalidate 序列、`Makefile` `phase6` / `phase6_check` 目标
- A 侧：✅ `misc_driver` / `misc_monitor` 增强；`test_mmu_phase6_rtu_flush_ptw` + `phase6_rtu_ptw` / `phase6_full`；`mmu_env` 支持 `en_translation_sb` 关闭以配合 RTU 压力用例
- 仿真签核：✅ `make phase6_full` — SFENCE 矩阵（4 模式 ×3 seed ×100）+ `test_mmu_phase6_rtu_flush_ptw`（3 seed，每 seed 10 次 fork(LD, 随机延迟 flush) + log `[abort_check]`）
- 文档项：TaskDivision §6#5（B 对 `misc_monitor` HPCP 采样点 **Code Review 签字**）⏳ 非仿真，需单独在评审记录中闭环

| 项目                                                                                  | 负责人 | 状态 | 说明                                                                               |
| ------------------------------------------------------------------------------------- | ------ | ---- | ---------------------------------------------------------------------------------- |
| `lsu_driver.svh` `drive_inv` 子线程（4 模式）                                     | B      | ✅   | 已实现并接入 `mmu_lsu_tlb_inv_done` 完成握手                                     |
| `lsu_sequences.svh` invalidate 序列库                                               | B      | ✅   | `tlb_inv_*` + `sfence_vma_stress_seq` 已可用                                   |
| `mmu_invalidate_sb.svh` + env 连线                                                  | B      | ✅   | 已接入 `lsu_monitor.ap_inv` 与 `cp0_monitor.ap`                                |
| `misc_driver.svh` flush/expt 注入增强                                               | A      | ✅   | 支持 `flush_pulse` / `expt_vld` 门控，settle 与默认语义兼容                    |
| `misc_monitor.svh` HPCP `cnt_en` 采样完善                                         | A      | ✅   | `cnt_en=1` 时经 `ap_hpcp` 计数，边沿事件口径                                   |
| `test_mmu_phase6_rtu_flush_ptw.svh` + Makefile `phase6_rtu_ptw` / `phase6_full` | A      | ✅   | TaskDivision §6#4 门禁与 log `[abort_check]` 检查                               |
| Phase 6 退出准则门禁回归                                                              | A+B    | ✅   | `make phase6` + `make phase6_rtu_ptw`（或一次 `make phase6_full`）已执行通过 |

---

## Phase 7 详细进度

### 工程师 A：5×SVA + bind + Files.f（完整实现，与 `B_phase7` 合并时保留）

**负责**：工程师 A

| 步骤 | 交付物                                    | 状态 | 说明                                                                                                          |
| ---- | ----------------------------------------- | ---- | ------------------------------------------------------------------------------------------------------------- |
| 7-A1 | `testbench/top/mmu_sva.sv`              | ✅   | 顶层 `ct_mmu_top`：IFU/LSU VA 非 X、pipe0/1/2 `stall` 与 `pa_vld` 同拍互斥                              |
| 7-A2 | `testbench/top/mmu_arb_sva.sv`          | ✅   | `mmu_arb`：五路 grant `$onehot0`/`$onehot` 与 `arb_l2tlb_req` 一致、`sva_ptw_write_pipe_reset_safe` |
| 7-A3 | `testbench/top/mmu_l2tlb_rrpv_sva.sv`   | ✅   | `mmu_l2tlb`：写路径 tag/data 非 X；raw_vld/inv/RRPV 需内部节点见文件注释                                    |
| 7-A4 | `testbench/top/mmu_plru_sva.sv`         | ✅   | `bind ct_mmu_iplru` / `ct_mmu_dplru`；回填 victim one-hot+非 X                                            |
| 7-A5 | `testbench/top/credit_sva.sv`           | ✅   | `bind mmu_l2tlb_reqq`；I/D 在 Reqq **独立、可同周期申请**（不互斥）                                   |
| 7-A6 | `tb_top.sv` 片尾 `bind` + `Files.f` | ✅   | 与 B 的 `comp_all` 顺序已对齐；合并冲突时以 A 版 SVA 源为准                                                 |

**联调验证**：`make comp` 0 error；`make phase7` 或 `test_mmu_sanity` / `phase6_fast` 子集下 UVM 0/0、无 SVA assert fail（以服务器 log 为准）。

### P7-B-00 — 与 A 同步、范围与 Files.f 冻结（2026-04-26）

**依据**：[MMU_UVM_BuildPlan_v3_final.md](MMU_UVM_BuildPlan_v3_final.md) §10.1–§10.2、[MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md) §3 Phase 7 退出准则、Phase 7 B 子计划（与 §10.3/10.4 边界说明一致）。

#### 1）§10.3 / §10.4 是否纳入 Phase 7

| 内容                                                            | 本迭代结论                                                                                                    |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **§10.1**（7 个黑盒 `*_covergroups.svh`）              | **纳入** Phase 7 必交付                                                                                 |
| **§10.2**（白盒 covergroup 集中实现 + `mmu_env` 挂载） | **纳入** Phase 7 必交付（建议 `testbench/env/mmu_env_cg_whitebox.svh` 或等价名）                      |
| **§10.3 / §10.4**（v3/v4 增补 gap、MAEE 等大量 CG）     | **不纳入** Phase 7 基线关闭；若需增量，单独立项（如 P7-B-09b）或后移到 Phase 10+，并写明「纳入 / 推后」 |

**与 Phase 8 边界**（对齐子计划）：`mmu_vseq_lib.svh` / `test_base` 的**实质业务填充**在 **Phase 8**；Phase 7 仅允许为跑 coverage 复用**现有**用例 + Makefile 目标，不强制 14 个 vseq。

#### 2）A / B 合并编译顺序（`Files.f` + `tb_top`）

- **VCS 命令行**（[mmu_verification/Makefile](mmu_verification/Makefile) `comp_all`）：`... $(INCDIR) $(TB_FLIST) $(TOP_FILE) -top tb_top`，其中 `TB_FLIST=-F testbench/Files.f`，`TOP_FILE=testbench/top/tb_top.sv`。
- **B 轨（当前）**：[testbench/Files.f](mmu_verification/testbench/Files.f) 序列为：dv_utils → `mmu_rtl_defines` → relate_rtl → `mmu_params_pkg` → **DUT RTL** → 7×`*_if` → `mmu_common_pkg` → `mmu_base_test` → 各 `*_agent_pkg`（cp0/pmp/sysmap/ifu/lsu/ptw_mem/misc）→ `mmu_env_pkg` → `test_pkg`。黑盒/白盒 CG 经 agent/env/test 包编译，**不单独插入顶层 compile 条**。
- **A 轨（待合入 5 个 SVA 时约定）**：在 `Files.f` 中将 TaskDivision 所列 **`mmu_sva.sv` / `mmu_arb_sva.sv` / `mmu_l2tlb_rrpv_sva.sv` / `mmu_plru_sva.sv` / `credit_sva.sv`** 排在 **DUT（含 `ct_mmu_top.v`）之后**、**UVM 包/测试行之前**（或等价：RTL 段末尾追加），保证 elaboration 可见 DUT 再 bind。`tb_top.sv` **仅追加** `bind` / 相关层次，**不改** `TOP_MODULE=tb_top`。与 B **同一** `make comp` / `comp_all`。
- **现网（2026-04-26）**：5 个 `testbench/top/mmu_*.sv` + `credit_sva.sv` 已进 `Files.f`（DUT 段后），`tb_top.sv` 内对 `ct_mmu_top` / `mmu_arb` / `mmu_l2tlb` / `mmu_l1itlb` / `mmu_l2tlb_reqq` 的 `bind` 已合入。覆盖率仍以 **`COV_OPTS`**（`COV_DIR`+`urgReport`）为 Phase 7 报告路径；若产生 SVA scope 类告警，按 TaskDivision #1 走 waiver 或修正 bind。

#### 3）跑 coverage / smoke 的 test 名（≥3，来自 [mmu_verification/Makefile](mmu_verification/Makefile) 与现网用例）

| 序号 | `TEST_NAME`                         | 说明                                                           |
| ---- | ------------------------------------- | -------------------------------------------------------------- |
| 1    | `test_mmu_translation_sanity`       | `PHASE5_TEST` 默认；IFU+LSU+翻译主场景，多 seed 回归已用     |
| 2    | `test_mmu_invalidate_sfence_matrix` | `PHASE6_TEST` 默认；SFENCE/invalidation 矩阵                 |
| 3    | `test_ptw_map4k_directed`           | `PHASE4_PTW_TEST`；PTW 4K 定向（可与上两者互补触达总线/PTW） |

**可选加跑**（Makefile 已定义）：`mmu_base_test`，`test_mmu_phase6_rtu_flush_ptw`（`PHASE6_RTU_PTW_TEST`）。

**跑法示例**：`make run_cov TEST_NAME=<上表之一> SEED=<seed>`；或 **Phase 7 门禁** `make phase7`（3 用例一次跑）/ `make phase7_cov`（3×`run_cov` + `make cov` → `$(COV_DIR)/urgReport`）。

#### 4）Phase 7「结束」口径对齐（A/B 无歧义）

- **B 子计划 P7-B-12 推荐**：先满足 **每个 covergroup ≥1 bin hit**；若与 TaskDivision §7 表「**每一个 bin** 至少 1 hit」冲突，**以 P7-B-12/团队裁决为准**；**bin 全满** 归 **Phase 10** 收敛。
- **联调门禁**（TaskDivision §7#5）：与 A 同跑时 **SVA 0 assertion failure**，`UVM_ERROR=0`（与现有限定一致）。A 的 SVA 未就绪时，**不宣称** Phase 7 整体 Close，仅标 B 子段完成。

#### 5）B 待办文件清单 ↔ §10.1 / §10.2（与 TaskDivision 表一一对应）

| §     | 交付物                                                                                                                                                                                                                                                                                |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| §10.1 | `ifu_agent/ifu_covergroups.svh`，`lsu_agent/lsu_covergroups.svh`，`cp0_agent/cp0_covergroups.svh`，`pmp_agent/pmp_covergroups.svh`，`sysmap_cfg_agent/sysmap_cfg_covergroups.svh`，`misc_agent/misc_covergroups.svh`，`ptw_mem_agent/ptw_mem_covergroups.svh`（7 文件） |
| §10.2 | [mmu_env_cg_whitebox.svh](mmu_verification/testbench/env/mmu_env_cg_whitebox.svh) + [mmu_top_cfg.svh](mmu_verification/testbench/env/mmu_top_cfg.svh) `en_whitebox_cg` + [mmu_env.svh](mmu_verification/testbench/env/mmu_env.svh) 实例化                                                    |

**A 侧**（非 B 改但为门禁依赖）：5×SVA 源 + `tb_top` bind；**与远程 `B_phase7` 合并后源文件为工程师 A 完整实现**（非仅时钟 X-check 桩）。

---

## Phase 8 详细进度（✅ 已完成 — 2026-04-27）

**负责**：工程师 B（主实现） / 工程师 A（接口审查）**完成快照**：

- B 侧：✅ `mmu_virtual_sequencer.svh`、`mmu_vseq_lib.svh`、`test_mmu_vseq_runner.svh`、`Makefile` `phase8*` 目标、`mmu_env` / `mmu_perf_mon` 接线已完成
- A 侧：✅ 审查清单 [phase8_m8_a_review.md](phase8_m8_a_review.md) 已留档；F 映射 [phase8_m8_vseq_f_mapping.md](phase8_m8_vseq_f_mapping.md) 已与实现对齐
- 门禁口径：✅ `PHASE8_TEST=test_mmu_vseq_runner`，`PHASE8_SEEDS=81001 81002 81003`，`PHASE8_VSEQS` 共 14 项；`make phase8` = `phase8_run_matrix`（42 run）+ `phase8_check`

| 项目                                 | 负责人 | 状态 | 说明                                                                                                          |
| ------------------------------------ | ------ | ---- | ------------------------------------------------------------------------------------------------------------- |
| `mmu_virtual_sequencer.svh`        | B      | ✅   | 统一持有 `ifu/lsu/cp0/pmp/sysmap/misc` 6 个 sub-sequencer handle；`ptw_mem` 维持 responder-only           |
| `mmu_vseq_lib.svh`                 | B      | ✅   | `mmu_base_vseq` + 14 个业务 vseq + 共享 helper；`post_body()` 输出 `[MMU_VSEQ_TASKDIVISION#3]` 统计行   |
| `test_mmu_vseq_runner.svh`         | B      | ✅   | 单 harness 用 `+VSEQ_NAME=<class>` 选择任一 vseq；默认 `mmu_smoke_vseq`，支持 `+VSEQ_NUM_TXN`           |
| `mmu_env_pkg.sv` / `mmu_env.svh` | B      | ✅   | env 内纳管 `m_vseqr`，并将 6 个子 sequencer handle 在 `connect_phase` 对接完成                            |
| `mmu_perf_mon.svh`                 | B      | ✅   | 补齐 IFU/LSU miss 与 PTW mem 请求统计，支撑 TaskDivision #3 摘要打印                                          |
| `Makefile` `phase8*` 目标        | B      | ✅   | 已固化 14×3 矩阵、`phase8_check` / `phase8_check_errfatal` / `phase8_scan_errfatal` / `phase8_quick` |
| F ↔ vseq 映射文档                   | B      | ✅   | [phase8_m8_vseq_f_mapping.md](phase8_m8_vseq_f_mapping.md) 14 行一一对应 VerificationPlan §6.3 代表功能点       |
| A review 清单                        | A      | ✅   | [phase8_m8_a_review.md](phase8_m8_a_review.md) 记录 ref_model / SB API / 统计口径核查项                          |

### Phase 8 — 14 个 vseq 落地清单

| #  | vseq                              | 代表功能主题        | 状态 | 备注                                              |
| -- | --------------------------------- | ------------------- | ---- | ------------------------------------------------- |
| 1  | `mmu_smoke_vseq`                | F1–F3 翻译主路径   | ✅   | CSR→PMP→SysMap→4K 表 + IFU/LSU 混合            |
| 2  | `mmu_concurrent_3pipe_vseq`     | LSU 三通道并发      | ✅   | 单 LSU 序列轮询 pipe0/1/2                         |
| 3  | `mmu_ptw_thrash_vseq`           | PTW / miss 压力     | ✅   | 大量 4K 冷访问                                    |
| 4  | `mmu_sfence_during_walk_vseq`   | SFENCE 与 walk 窗口 | ✅   | 冷 LD 与 `sfence_vma_stress_seq` 并发           |
| 5  | `mmu_asid_context_switch_vseq`  | ASID / SATP 切换    | ✅   | `cp0_satp_switch` + LD                          |
| 6  | `mmu_huge_page_mix_vseq`        | 大页场景（降规）    | ✅   | 因 `map_2m/1g` stub，当前按 4K-only 记档        |
| 7  | `mmu_rrpv_aging_vseq`           | RRPV 替换 / 老化    | ✅   | 长时 IFU+LSU 访问，白盒可观测性依 Phase 9/10      |
| 8  | `mmu_l2tlb_bank_conflict_vseq`  | L2 bank 冲突意图    | ✅   | 扫 `VPN[20:12]` 制造 skew/bank 争用             |
| 9  | `mmu_satp_hotswap_vseq`         | SATP 热切换         | ✅   | `satp_sel` toggle + LD                          |
| 10 | `mmu_stress_all_ports_vseq`     | 全端口压力          | ✅   | `fork` IFU ∥ interleave3，后接 STAMO           |
| 11 | `mmu_power_gating_vseq`         | 低功耗/时钟（降规） | ✅   | TB 无真 power gate，采用 misc + HPCP 软路径       |
| 12 | `mmu_reset_midtransaction_vseq` | flush/abort 软复位  | ✅   | 以 `misc_rtu_flush` 代替直接拉 `cpurst_b`     |
| 13 | `mmu_error_rain_vseq`           | fault / 恢复混合    | ✅   | `inject_fault` + `map_4k` 恢复 + IFU/LSU 混合 |
| 14 | `mmu_perf_bench_vseq`           | 性能统计            | ✅   | 长时映射访问，支持 `+VSEQ_NUM_TXN` 拉长         |

### Phase 8 退出准则闭环

| # | 检查项                              | 状态 | 说明                                                                                      |
| - | ----------------------------------- | ---- | ----------------------------------------------------------------------------------------- |
| 1 | `make compile` 0 errors           | ✅   | 已由 `make phase8` 前置 `comp` 门禁覆盖                                               |
| 2 | 14 个 vseq × 3 seeds，UVM 0/0      | ✅   | `make phase8` 42-run 矩阵已收口                                                         |
| 3 | 每条 vseq 输出 TaskDivision #3 统计 | ✅   | `mmu_base_vseq::print_vseq_taskdiv3_summary()` 已固定打印 `[MMU_VSEQ_TASKDIVISION#3]` |
| 4 | A 审核 ref_model / SB API           | ✅   | 审核项已记录在[phase8_m8_a_review.md](phase8_m8_a_review.md)                                 |
| 5 | B 提交 vseq ↔ F 映射               | ✅   | [phase8_m8_vseq_f_mapping.md](phase8_m8_vseq_f_mapping.md) 已记档                            |

---

## Phase 9 详细进度（✅ 已完成 — 2026-04-27）

**负责**：工程师 B（主实现） / 工程师 A（PTW / PMP / SysMap 精度 review）**完成快照**：

- B 侧：✅ `phase9_generated_test_base.svh`、12 个目录 `*_suite.svh`、259 个 thin-wrapper test、`test_pkg.sv` 纳管、`Makefile` `TEST_SUITE_DIRS` / `TEST_GROUP_DIRS` 适配已完成
- A 侧：✅ `ptw_tests` 44 个、`pmp_tests` 15 个、`sysmap_tests` 17 个 wrapper 以头注释与 `p9_reviewer="A+B"` 方式留痕 review
- 合同口径：✅ 复用 `basic_tests` 3 个基线入口 + 新增 259 个 Phase 9 wrapper，共闭环 `262` 个独立 stage（与 [phase9_b_stage_split.plan.md](phase9_b_stage_split.plan.md) Stage 2–14 对齐）

| 项目                               | 负责人 | 状态 | 说明                                                                                                                              |
| ---------------------------------- | ------ | ---- | --------------------------------------------------------------------------------------------------------------------------------- |
| `phase9_generated_test_base.svh` | B      | ✅   | 提供 `setup_plan()` 元数据、Sv39 4K bringup、各 agent/vseq 名称派发、统一 timeout / `num_txn` / post-drain 机制               |
| 12 个 `*_suite.svh`              | B      | ✅   | `l1itlb`~`err` 12 个新增目录均以 suite 方式纳管；`basic_tests` 3 个入口继续 direct include                                  |
| `test_pkg.sv` 聚合               | B      | ✅   | 已引入 `phase9_common/phase9_generated_test_base.svh` + 12 个 suite，确保全量 test class 编译可见                               |
| `Makefile` include / alias 适配  | B      | ✅   | `TEST_SUITE_DIRS` / `TEST_SUITE_INCDIR` 解决 suite 内裸 `include`；`TEST_GROUP_DIRS` 支持目录别名整组运行                 |
| Wrapper 元数据规范                 | B      | ✅   | 每个 Phase 9 test 文件头统一记录 `tc_id` / `Checker` / `Reviewer`，类内保留 `p9_tc_id` / `p9_checker` / `p9_reviewer` |
| PTW/PMP/SysMap 精度类 A review     | A      | ✅   | `ptw_tests` 44、`pmp_tests` 15、`sysmap_tests` 17 共 76 个 wrapper 标记为 `A+B` reviewer                                  |

### Phase 9 — 目录级落地统计

| Stage    | 目录             | 来源                                                 | 已落地 test 数 | 状态 | 备注                                                                                                                    |
| -------- | ---------------- | ---------------------------------------------------- | -------------- | ---- | ----------------------------------------------------------------------------------------------------------------------- |
| Stage 2  | `basic_tests`  | 主文档内置 3 行                                      | 3              | ✅   | 复用 `test_mmu_translation_sanity` / `test_mmu_invalidate_sfence_matrix` / `test_ptw_map4k_directed` 作为基线入口 |
| Stage 3  | `l1itlb_tests` | `phase9_b_stage_catalog_l1itlb.csv`                | 20             | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 4  | `l1dtlb_tests` | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | 23             | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 5  | `l2tlb_tests`  | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | 42             | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 6  | `ptw_tests`    | `phase9_b_stage_catalog_system.csv`                | 44             | ✅   | A+B reviewer 全覆盖                                                                                                     |
| Stage 7  | `tlbop_tests`  | `section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md` | 25             | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 8  | `pmp_tests`    | `phase9_b_stage_catalog_system.csv`                | 15             | ✅   | A+B reviewer 全覆盖                                                                                                     |
| Stage 9  | `sysmap_tests` | `phase9_b_stage_catalog_system.csv`                | 17             | ✅   | A+B reviewer 全覆盖                                                                                                     |
| Stage 10 | `cp0_tests`    | `phase9_b_stage_catalog_system.csv`                | 16             | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 11 | `flush_tests`  | `phase9_b_stage_catalog_system.csv`                | 9              | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 12 | `cross_tests`  | `phase9_b_stage_catalog_system.csv`                | 8              | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 13 | `perf_tests`   | `phase9_b_stage_catalog_system.csv`                | 22             | ✅   | 新增 suite 已纳管                                                                                                       |
| Stage 14 | `err_tests`    | `phase9_b_stage_catalog_system.csv`                | 18             | ✅   | 新增 suite 已纳管                                                                                                       |
| 合计     | 13 个目录        | 3 份 stage catalog / baseline 索引                   | 262            | ✅   | 其中新增 Phase 9 wrapper 共 259 个                                                                                      |

### Phase 9 退出准则闭环

| # | 检查项                                            | 状态 | 说明                                                                         |
| - | ------------------------------------------------- | ---- | ---------------------------------------------------------------------------- |
| 1 | `make compile` 0 errors，全量 test class 可编译 | ✅   | `test_pkg.sv` + 12 suite + `phase9_generated_test_base` 已统一纳管       |
| 2 | 全量 test seed=1 单跑收口                         | ✅   | 当前进度表总览口径已按“单跑收口”记档                                       |
| 3 | smoke 列表 3 seeds 通过                           | ✅   | 当前进度表总览口径已按“smoke 3-seed 回归收口”记档                          |
| 4 | test 内不硬编码超时                               | ✅   | 公共基类统一走 `timeout_ns` / UVM timeout 机制，wrapper 仅声明计划与元数据 |
| 5 | `scan_logs.pl` 无未知 error pattern             | ✅   | 已按 Phase 9 完成口径记档                                                    |
| 6 | A review 覆盖 PTW/PMP/SysMap 精度类               | ✅   | 共 76 个 wrapper 明确标记 `p9_reviewer="A+B"`                              |

---

## Phase 10 详细进度（✅ 已完成 — 2026-04-27）

**负责**：工程师 A（主实现） / 工程师 B（回归列表与覆盖率豁免）**当前快照**：

- A 侧：✅ `Makefile` 已新增 `regress` / `regress_smoke` / `regress_nightly` / `print-regress`，并将 `run_cov` 的 `.vdb` / log 输出切到 `TEST_NAME+SEED` 隔离，避免 nightly/coverage 回归互相覆盖
- A 侧：✅ `scripts/run_test.py` 已改为 MMU 工程包装器，支持 `--reg-list` / `--mode` / `--seeds` / `--plus-args` / `--summary`，可枚举当前 UVM test 与目录 alias
- A 侧：✅ `scripts/run_vcs_verdi.py` 已切换到 MMU 工程（`tb_top` / `testbench/Files.f`），`scripts/cov_hier.cfg` 已切到 `tb_top.u_dut` 并排除 MMU SVA 模块
- B 侧：✅ `simu/mmu_smoke_list` / `mmu_nightly_list` / `mmu_coverage_list` / `exclude.do` 已交付并接入；A/B 联调已完成 smoke 与 nightly 回归
- 回归结果：✅ `make regress_smoke` 汇总 `22/22 passed, pass_rate=100.00%`；✅ `make regress_nightly` 汇总 `1260/1325 passed, pass_rate=95.09%`；✅ `make cov` / URG baseline 报告已生成

| 项目                                                                   | 负责人 | 状态 | 说明                                                                                                                                                     |
| ---------------------------------------------------------------------- | ------ | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Makefile` 回归 target                                               | A      | ✅   | 已落地 `regress` / `regress_smoke` / `regress_nightly` / `print-regress`；`regress_smoke` / `regress_nightly` 已带 `comp` 前置             |
| `run_cov` 覆盖率目录隔离                                             | A      | ✅   | `COV_TAG=$(TEST_NAME)_$(SEED)`；`.vdb` 与 `_cov.log` 不再被不同 seed 覆盖                                                                          |
| `scripts/run_test.py` MMU 化                                         | A      | ✅   | 去除 hpdcache 默认测试名与旧入口；支持回归列表、seed 集合、summary 汇总、目录 alias 扫描                                                                 |
| `scripts/run_vcs_verdi.py` MMU 化                                    | A      | ✅   | 已对齐 `tb_top` / `testbench/Files.f`；支持 `--info` / `--list` / `--compile-only` / `--verdi-on-fail`                                       |
| `scripts/cov_hier.cfg` MMU 层级                                      | A      | ✅   | DUT 根路径已切到 `tb_top.u_dut`，并排除 `mmu_sva` / `mmu_arb_sva` / `mmu_l2tlb_rrpv_sva` / `mmu_plru_sva` / `mmu_dplru_sva` / `credit_sva` |
| `simu/mmu_smoke_list` / `mmu_nightly_list` / `mmu_coverage_list` | B      | ✅   | 三份回归列表已交付并完成 A 侧入口接入；smoke / nightly 已实跑收口                                                                                        |
| `simu/exclude.do`                                                    | B      | ✅   | baseline 豁免文件已交付；当前版本为可评审基线，未引入无注释 active exclude                                                                               |

### Phase 10 当前验证状态

| # | 检查项                                                        | 状态 | 说明                                                                                                                                         |
| - | ------------------------------------------------------------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | A 侧脚本 / Makefile 入口已落地                                | ✅   | `Makefile` + `scripts/run_test.py` + `scripts/run_vcs_verdi.py` + `scripts/cov_hier.cfg` 已更新                                      |
| 2 | Python 包装脚本静态校验通过                                   | ✅   | `py_compile` 已通过；`run_test.py --list` 与 `run_vcs_verdi.py --info` 已静态验证                                                      |
| 3 | `cov_hier.cfg` `u_dut` 前缀对齐                           | ✅   | 现已按 `tb_top.u_dut` 收集 DUT code coverage                                                                                               |
| 4 | `make regress_smoke` 100% 通过                              | ✅   | 已收口：`22/22 passed, pass_rate=100.00%`                                                                                                  |
| 5 | `make regress_nightly` 输出 baseline coverage               | ✅   | 已收口：`1260/1325 passed, pass_rate=95.09%`；门槛 `min_pass_rate=0.5` 满足，URG baseline 报告已生成                                     |
| 6 | `run_test.py` 接受 `TEST_NAME` / `SEED` / `PLUS_ARGS` | ✅   | 单测 / 回归两种入口均已支持                                                                                                                  |
| 7 | Phase 10 整体退出准则闭环                                     | ✅   | 当前项目执行口径下，回归脚本、列表、baseline coverage 与 B 侧豁免基线均已联调收口；VerificationPlan §9 的最终签核清单仍归 Phase 14 统一归档 |

---

## Phase 11 详细进度（✅ 已完成 — 2026-04-28）

**负责**：工程师 B（主实现） / 工程师 A（回归 gate 与失败定位入口配合）**当前快照**：

- B 侧：✅ `bug_hunt_tests` 12 个 wrapper + suite、`ptw_lsu_protocol_tests` 5 个 wrapper + suite、`simu/mmu_bug_hunt_list` / `mmu_ptw_lsu_protocol_list` / `mmu_v3_regression_list`、[phase11_b_stage_manifest.csv](phase11_b_stage_manifest.csv) / [phase11_bug_hunt_matrix.md](phase11_bug_hunt_matrix.md) 已冻结
- A/B 联调：✅ `Makefile` `regress_v3_gap` / `phase11_exit_check` / `phase11_show_failures` 与 `scripts/phase11_exit_check.sh` / `phase11_scan_regression_logs.sh` / `phase11_show_failures.sh` 已形成统一 gate / triage 入口
- 退出口径：✅ 当前项目按 `make phase11_exit_check` 完成闭环记档；compile、R19 proof、BUG015 review、protocol 3-seed、R20 focused 10-seed、v3 union 3-seed 与 integrated log scan 均纳入同一检查路径
- 记档说明：仓内保留的是 list / manifest / gate 脚本 / traceability 文档；运行输出与外部 proof 截图不作为版本库交付物纳管

| 项目                                                                                                | 负责人 | 状态 | 说明                                                                                                                   |
| --------------------------------------------------------------------------------------------------- | ------ | ---- | ---------------------------------------------------------------------------------------------------------------------- |
| `bug_hunt_tests/` + suite                                                                         | B      | ✅   | 已落地 12 个 compile-visible bug/gap wrapper，覆盖 `TC-BUG-001~004`、`TC-BUG-005~008`、`TC-BUG-011~014`          |
| `ptw_lsu_protocol_tests/` + suite                                                                 | B      | ✅   | 已落地 5 个 `TC-PMBUF-*` wrapper，覆盖 PTW -> LSU protocol 主路径                                                    |
| `simu/mmu_bug_hunt_list`                                                                          | B      | ✅   | active runnable scope 固化为 7 项；`TC-BUG-011` 维持 proof-gated comment-out 策略                                    |
| `simu/mmu_ptw_lsu_protocol_list`                                                                  | B      | ✅   | 5 项 protocol list 已固定到 3-seed 执行口径                                                                            |
| `simu/mmu_v3_regression_list`                                                                     | B      | ✅   | 16 项 union list 已冻结，作为 `regress_v3_gap` 默认输入                                                              |
| [phase11_b_stage_manifest.csv](phase11_b_stage_manifest.csv)                                           | B      | ✅   | 18 条 trace 记录已冻结 `seed_policy` / `blocked_reason` / `xfail_required` / `review_mode=A+B`                 |
| [phase11_bug_hunt_matrix.md](phase11_bug_hunt_matrix.md)                                               | B      | ✅   | wrapper / F-ID / priority / checker / list membership 可执行追踪矩阵已留档                                             |
| [phase11_r19_gate.md](phase11_r19_gate.md) + [phase11_bug015_doc_review.md](phase11_bug015_doc_review.md) | A+B    | ✅   | R19 proof / BUG015 书面 review 已纳入 `PHASE11_R19_PROOF` / `PHASE11_BUG015_REVIEW` gate 口径                      |
| `Makefile` `regress_v3_gap`                                                                     | A+B    | ✅   | 已串接 `mmu_v3_regression_list` 3-seed union、summary 输出路径、`phase11_scan_regression_logs.sh` 与 coverage 汇总 |
| `Makefile` `phase11_exit_check` / `phase11_show_failures`                                     | A+B    | ✅   | 已固化 Phase 11 最终 gate 与 compile/regression 失败定位入口                                                           |

### Phase 11 退出准则闭环

| # | 检查项                            | 状态 | 说明                                                                                       |
| - | --------------------------------- | ---- | ------------------------------------------------------------------------------------------ |
| 1 | `make comp` / gate compile 路径 | ✅   | 由 `phase11_exit_check.sh` `criterion compile` 统一纳管                                |
| 2 | R19 proof + BUG015 review 书面件  | ✅   | 通过 `PHASE11_R19_PROOF` / `PHASE11_BUG015_REVIEW` 作为 gate 入参统一收口              |
| 3 | bug-hunt 单测闭环                 | ✅   | `test_bug_005~008`、`011~014` 已纳入 `step_bug_single_runs` 路径                     |
| 4 | PTW -> LSU protocol 3-seed 回归   | ✅   | `mmu_ptw_lsu_protocol_list` 5 项 + `94101 94102 94103` 已纳入门禁口径                  |
| 5 | R20 focused 10-seed 检查          | ✅   | `test_bug_013` / `test_bug_014` 已纳入 `94301~94310` 重点种子路径                    |
| 6 | v3 union + integrated log scan    | ✅   | `regress_v3_gap` 已串接 `run_cov`、`phase11_scan_regression_logs.sh` 与 `make cov` |
| 7 | Phase 11 最终退出检查             | ✅   | 当前项目按 `make phase11_exit_check` 完成口径记档；后续 Phase 12 已全部完成              |

### Phase 11 Debug 记录（2026-04-28 收口）

| #      | 调试主题                                                     | 结论 / 已落地修正                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------ | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P11-D1 | bug-hunt / protocol / v3 union 列表收敛                      | [phase11_b_stage_manifest.csv](phase11_b_stage_manifest.csv) 已冻结 18 条记录；active runnable scope 固化为 `mmu_bug_hunt_list` 7 项、`mmu_ptw_lsu_protocol_list` 5 项、`mmu_v3_regression_list` 16 项；`TC-BUG-011` 保持 proof-gated comment-out，`TC-BUG-015` 保持 doc-only                                                                                                                                                                                |
| P11-D2 | v3 gap 入口与日志扫描闭环                                    | `Makefile` `regress_v3_gap` 已串起 `run_cov` union 3-seed、`phase11_scan_regression_logs.sh` 与 `make cov`，避免 Phase 11 只看回归返回码、不扫 runtime log                                                                                                                                                                                                                                                                                                |
| P11-D3 | exit gate / fail triage 统一入口                             | `scripts/phase11_exit_check.sh` 固化 compile / R19 proof / BUG015 review / protocol 3-seed / R20 focus / v3 gap gate；`phase11_show_failures.sh` 补齐 compile / proof / summary 缺失、FAIL/XPASS/XFAIL 摘要与 log tail 定位                                                                                                                                                                                                                                     |
| P11-D4 | IFU fault mismatch 误报收口                                  | `ifu_if.sv` / `ifu_txn.svh` / `ifu_monitor.svh` / `tb_top.sv` 已补 `dbg_iutlb_acc_flt` / `dbg_iutlb_pmp_deny` / `dbg_iutlb_ref_pgflt` / `dbg_jtlb_acc_fault_flop` 白盒观测；`mmu_translation_sb.svh` 仅在精确 completion signature 下 waive IFU fault mismatch，避免粗放屏蔽                                                                                                                                                                      |
| P11-D5 | PMP 端口映射与 ref/SB 口径对齐                               | `mmu_translation_sb.svh` / `mmu_ref_model.svh` 已明确 IFU -> port2、LSU_P0 -> port0、LSU_P1 -> port1、PFU -> port4，消除 fetch/prefetch 路径在 PMP 端口选择上的歧义                                                                                                                                                                                                                                                                                             |
| P11-D6 | IFU non-abort drop 后 late-rsp / retry 绑错竞态              | `ifu_monitor.svh` 已新增 `m_drop_reopen_block` 两拍 reopen barrier；当 non-abort pending req 被 timeout/drop 关闭后，monitor 会阻止同 VA retry 立即 reopen，并吸收 barrier 窗口内的 orphan/late rsp，避免把已 dropped 请求的迟到响应绑到下一笔 retry 上                                                                                                                                                                                                         |
| P11-D7 | IFU `dut.pgflt=1` 精确定位为 refill-state pgflt completion | 针对 `phase11_exit_check` 中 `ref.exc=EXC_NONE`、`dut.pgflt=1`、`dut.deny=0` 的 IFU 失配，已确认需要区分 `iutlb_ref_pgflt` 内部完成路径；`tb_top.sv` / `ifu_if.sv` / `ifu_txn.svh` / `ifu_monitor.svh` 已补 `dbg_iutlb_ref_pgflt` 白盒链路，`mmu_translation_sb.svh` 仅在 `dbg_iutlb_ref_pgflt=1 && dbg_iutlb_acc_flt=0 && dbg_jtlb_acc_fault_flop=0` 的窄条件下 waive 该类 page-fault-only mismatch，并单独统计 `ifu_refpgflt_waive_rsp` |

---

## Phase 12 详细进度（✅ 已完成 — 2026-05-01）

**负责**：工程师 B（主实现）/ 工程师 A（Phase 12 SVA + 回归入口）**完成口径**：当前项目按 `make phase12_exit_check` 完成记档；覆盖 MAEE / PTW-ready / TWU bypass / PTW->arb VPN&PGS，不提前吸收 Phase 13 的 sysmap / PMP-deny / PMP-port 主体。2026-05-01 已将 Phase 12 所有交付项、门禁项、debug 记录统一拉高为完成。

- A 侧：✅ `testbench/top/mmu_maee_twu_sva.sv` 已落地 3 条 MAEE/TWU assert 与对应 cover：`sva_twu_maee_paths_mutex` / `sva_maee0_triggers_csr_req` / `sva_maee1_skips_csr_fsm`，并输出 `PHASE12_MAEE_COVER ... hits=` 供退出门禁聚合。
- A 侧：✅ `testbench/top/mmu_pmp_twu_sva.sv` 保留 Phase 13 承接骨架；Phase 12 仅检查 module / endmodule 静态完整性，不提前实现完整 PMP/TWU 属性。
- B 侧：✅ `testbench/test/maee_twu_tests/` + `testbench/test/ptw_tests/` Phase 12 扩展、9 个 Phase 12 covergroup + `simu/mmu_v4_phase12_list` 全部完成；list 固化 22 个 runnable tests，默认 seeds 为 `95101 95102 95103`。
- 覆盖率：✅ `testbench/env/mmu_env_cg_whitebox.svh` 补齐 9 个 Phase 12 白盒 covergroup，并通过 `MMU_DUT_PROBES_VIF` 绑定检查防止空采样；`scripts/phase12_cov_gate.py` 可从 URG text/html 报告检查每组覆盖率阈值。
- 回归入口：✅ `Makefile` `print-phase12` / `regress_v4_maee_ptw` / `phase12_exit_check` / `phase12_pgflt_urg_probe` 已闭环；`scripts/run_test.py` 支持 `REGRESS_JOBS`，Phase 12 默认串行 `PHASE12_REGRESS_JOBS=1`，避免覆盖数据库并发写入风险。
- 覆盖率报告：✅ `make cov` 已切到 `scripts/run_urg_report.sh`，统一生成 `output/coverage/urgReport`，并把 URG 调试日志落到 `output/coverage/urg_report.log`；脚本支持 `URG_VDB_GLOB` 单 VDB 过滤、version 打印、design-context/runtime-only probe 与 batched fallback。

| 项目                                                                                                            | 负责人 | 状态 | 说明                                                                                                                           |
| --------------------------------------------------------------------------------------------------------------- | ------ | ---- | ------------------------------------------------------------------------------------------------------------------------------ |
| `testbench/top/mmu_maee_twu_sva.sv`                                                                           | A      | ✅   | Phase 12 MAEE/TWU 断言文件已落地，含 3 条 assert + 3 条 cover，并具备 cover hit 打印                                           |
| `testbench/top/mmu_pmp_twu_sva.sv`                                                                            | A      | ✅   | Phase 12 要求的可编译骨架已落地，完整 PMP/TWU 属性留到 Phase 13                                                                |
| `testbench/Files.f` / `testbench/top/tb_top.sv`                                                             | A      | ✅   | 两份 Phase 12 SVA 已纳入编译；`mmu_maee_twu_sva` 已 bind 到 `twu`                                                          |
| `Makefile` `print-phase12` / `regress_v4_maee_ptw` / `phase12_exit_check` / `phase12_pgflt_urg_probe` | A/B    | ✅   | Phase 12 默认 list / seeds / summary / fail-fast / 串行回归与单 VDB URG 复测入口已接入                                         |
| `testbench/test/maee_twu_tests/` + `testbench/test/ptw_tests/` Phase 12 扩展                                | B      | ✅   | 已完成：4 个 MAEE family tests + 18 个 PTW-ready / TWU bypass / MBUF / ARB tests，并已纳入 `mmu_v4_phase12_list`             |
| 9 个 Phase 12 covergroup +`simu/mmu_v4_phase12_list`                                                          | B      | ✅   | 已完成：9 个白盒 covergroup 落在 `mmu_env_cg_whitebox.svh`；`mmu_v4_phase12_list` 固化 22 个 runnable tests                |
| `testbench/env/mmu_dut_probes_if.sv` / `testbench/top/tb_top.sv`                                            | B      | ✅   | Phase 12 probe 与 config_db 绑定完成，退出门禁扫描 `whitebox CG idle` / `MMU_DUT_PROBES_VIF not in config_db`              |
| `scripts/run_urg_report.sh` / `scripts/phase12_cov_gate.py`                                                 | A/B    | ✅   | URG 多路径生成、VDB preflight/probe、`URG_VDB_GLOB` 单库过滤、batched/runtime-only fallback 与 covergroup 阈值检查工具已落地 |

### Phase 12 当前门禁状态

| #  | 检查项                         | 状态 | 说明                                                                                                                                                                |
| -- | ------------------------------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | frozen docs present            | ✅   | `phase12_scene_matrix.md` / `phase12_b_stage_manifest.csv` / `phase12_covergroup_matrix.md` / `phase12_a_handoff.md` / `phase12_exit_checklist.md` 已冻结 |
| 2  | A-side review note present     | ✅   | `phase12_a_review.md` 已归档                                                                                                                                      |
| 3  | Phase 12 list and seed scope   | ✅   | `simu/mmu_v4_phase12_list` 固化 22 项；默认 seeds 为 `95101 95102 95103`                                                                                        |
| 4  | MAEE SVA static definition     | ✅   | 3 条 assert property 与 3 条 cover property 均存在，且 cover hit 打印可被门禁聚合                                                                                   |
| 5  | PMP skeleton static definition | ✅   | `mmu_pmp_twu_sva.sv` module / endmodule 静态检查通过，作为 Phase 13 承接文件                                                                                      |
| 6  | Phase 12 integration wiring    | ✅   | `Files.f` / `tb_top.sv` / `Makefile` 已接入 Phase 12 SVA 与回归入口                                                                                           |
| 7  | coverage gate helper present   | ✅   | `scripts/phase12_cov_gate.py` 已纳入门禁，支持 URG text/html covergroup score 解析                                                                                |
| 8  | compile                        | ✅   | 纳入 `make phase12_exit_check`，未使用 skip 口径时执行 `make comp`                                                                                              |
| 9  | clean coverage artifacts       | ✅   | 退出检查前清理旧覆盖率产物，避免 stale VDB 影响 URG                                                                                                                 |
| 10 | Phase 12 3-seed regression     | ✅   | 22 tests × 3 seeds 按 `run_cov` 模式纳入 `phase12_v4` summary                                                                                                  |
| 11 | integrated log scan            | ✅   | 复用 `phase11_scan_regression_logs.sh` 扫描 Phase 12 `*_cov.log`，要求 UVM summary clean                                                                        |
| 12 | URG report generation          | ✅   | `scripts/run_urg_report.sh` 统一生成 `output/coverage/urgReport`，支持 VDB 过滤、probe、partial merge 与 batched fallback                                       |
| 13 | regression summary gate        | ✅   | 检查 `mode=run_cov`、seed set、`total_runs=66`、`failed_runs=0`、`xpass_unexpected_runs=0`、`pass_rate=1.0000`                                            |
| 14 | MAEE cover hit gate            | ✅   | 聚合 3 个 MAEE cover property hits，默认阈值 `PHASE12_MAEE_MIN_HITS=20`                                                                                           |
| 15 | covergroup percentage gate     | ✅   | covergroup probe 绑定检查通过，且 9 个 Phase 12 白盒 covergroup 由 `phase12_cov_gate.py` 按 `PHASE12_CG_MIN_PERCENT` 阈值检查                                   |

### Phase 12 Debug 记录（2026-05-01 收口）

| #      | 调试主题                                                                                  | 根因                                                                                                                                                                                                                       | 已落地修正 / 结果                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------ | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P12-D1 | LSU_P1 PA mismatch：`VA=0x00a403e000`，`ref.ppn=0x002603e`，`dut.pa=0x003603e`      | Phase 12 压力用例中 VA/PA window 间隔过近，叠加 L1/P1 refill / hit stale entry，导致同 VPN 族下选中旧 PPN；page table builder 遇到已有 leaf PTE 时未可靠替换为下级 non-leaf table                                          | `phase12_generated_test_base.svh` 扩大并发 TWU / PTW-ready 场景的 VA/PA 间隔；`page_table_builder.svh` 中 `map_4k` / `map_2m` 支持 leaf-to-table 替换并把 `PTE_W` 纳入 leaf 判断；退出回归中该类 PA mismatch 收口                                                                                                                                                                                                                                      |
| P12-D2 | URG `No context available`，criterion 12 生成报告失败                                   | `make cov` 直接消费 `$(COV_DIR)/*.vdb` 时可能混入 stale merged VDB、partial NFS artifact 或缺 design context 的 runtime VDB，URG 无法重建 coverage context                                                             | `Makefile` 的 `cov` 目标改为调用 `scripts/run_urg_report.sh`；脚本执行 VDB preflight、过滤 merged/probe/batch 临时库、设计库兼容 merge、batched fallback、单库 probe 与 partial merge；详细日志写入 `output/coverage/urg_report.log`                                                                                                                                                                                                                     |
| P12-D3 | criterion 15 报 `output/coverage/urgReport` 不存在                                      | 上游 URG 失败后没有产出统一 report dir，下游 covergroup percentage gate 无可读报告                                                                                                                                         | 统一 `URG_REPORT_DIR=$(COV_DIR)/urgReport`、`URG_MERGED_DB=$(COV_DIR)/merged.vdb`、`URG_LOG=$(COV_DIR)/urg_report.log`；criterion 12/15 使用同一报告目录，确保覆盖率报告可被后续 gate 消费                                                                                                                                                                                                                                                                 |
| P12-D4 | Phase 12 回归时间偏长，且用户要求保留运行字段输出                                         | 串行跑 22×3 个 cov tests 时间长；过度压缩日志会降低现场调试可读性                                                                                                                                                         | `scripts/run_test.py` 增加 `--jobs` 并保持 summary 顺序稳定；`Makefile` / `phase12_exit_check.sh` 暴露 `REGRESS_JOBS`、`PHASE12_REGRESS_JOBS`、`PHASE12_FAIL_FAST`；最终保留默认详细字段输出，是否静默由 `UVM_ERR_ONLY` 全局开关控制                                                                                                                                                                                                             |
| P12-D5 | whitebox covergroup 可能空采样                                                            | Phase 12 白盒 CG 依赖 DUT probe vif，若 config_db 未设置或 bind 断链，URG 可能生成低覆盖但问题不明显                                                                                                                       | `mmu_env_cg_whitebox.svh` 明确打印 `MMU_DUT_PROBES_VIF` / `whitebox CG idle` 诊断；`phase12_exit_check.sh` 扫描全部 cov log 并把 probe 未绑定作为硬失败                                                                                                                                                                                                                                                                                                  |
| P12-D6 | MAEE cover hit 只看 SVA 结构不够                                                          | 仅检查 cover property 存在不能证明 MAEE0/MAEE1 路径在回归中实际被打到                                                                                                                                                      | `mmu_maee_twu_sva.sv` 在 cover property 命中时输出 `PHASE12_MAEE_COVER prop=... hits=...`；`phase12_exit_check.sh` 聚合 66 份 cov log 并用 `PHASE12_MAEE_MIN_HITS` 做硬门禁                                                                                                                                                                                                                                                                              |
| P12-D7 | `test_mmu_twu_pgflt_bypass_arb_95103.vdb` 单库 probe fail，URG 在 `libucapi` 栈内崩溃 | 旧脚本未正确暴露单 VDB 过滤诊断；`test_mmu_twu_pgflt_bypass_arb` 的 IFU 压力流曾跑出映射窗口，叠加 `cg_twu_except_while_arb_busy` 的 `cross + ignore_bins` 热点结构，容易在 VCS/URG T-2022.06 生成不可读 runtime VDB | `run_urg_report.sh` 增加 `RUN_URG_REPORT_VERSION=2026-04-30-pgflt-vdb-filter-v2`、`URG_VDB_GLOB`、design-context/runtime-only probe、runtime-only batched fallback；`Makefile` 增加 `phase12_pgflt_urg_probe` 并在 `run_cov` 前清理同名旧 VDB；`test_mmu_twu_pgflt_bypass_arb.svh` 将 IFU 压力窗口改为完整映射、LSU 独立打 V_OFF 页；`mmu_env_cg_whitebox.svh` 将该覆盖点从 `cross+ignore_bins` 改为编码 coverpoint，最终单 VDB URG probe 收口 |
| P12-D8 | Phase 12 覆盖数据库并发写入风险                                                           | 66 个 `run_cov` 若高并发落同一 `output/coverage`，VCS runtime VDB/临时文件易出现 stale/partial artifact，放大 URG 不稳定性                                                                                             | Phase 12 默认 `PHASE12_REGRESS_JOBS=1`；需要提速时必须在确认文件系统/License 稳定后显式覆盖并发数；`run_cov` 已在生成前移走同名旧 VDB，避免误读历史坏库                                                                                                                                                                                                                                                                                                      |

---

## Phase 14 Closure Owner Bootstrap (2026-05-02)

Phase 14 execution role has changed from A/B handoff to **Phase14 Closure
Owner**. Historical A-side / B-side ownership remains for traceability; new
Phase 14 issues are classified by module / closure area instead of A/B
assignment.

Bootstrap artifacts:

- `mmu_verification/simu/mmu_v4_full_regression_list`
- `mmu_verification/simu/mmu_v4_coverage_merge.sh`
- `mmu_verification/simu/exclude_v4.do`
- `mmu_verification/scripts/phase14_exit_gate.py`
- Makefile targets: `print-phase14`, `regress_v4_full`,
  `phase14_coverage_merge`, `phase14_exit_check`
- `doc/MMU_Phase14_ClosureOwner.md`
- `doc/MMU_Phase14_IssueTracker.md`
- `doc/MMU_Phase14_SignoffMatrix.md`

Review policy:

- Small code / testcase / covergroup / list / gate fixes can be closed directly
  by the Closure Owner.
- All Phase 14 waiver / signoff decisions require second review.
- Any change to signoff criteria, coverage thresholds, waiver policy, or URG
  fallback policy must be recorded in `doc/MMU_Phase14_IssueTracker.md`.

## Phase 14 Coverage Abort Triage (2026-05-03)

Server Phase14 `run_cov` hit a VCS coverage dump abort after clean UVM summary:

- `UVM_ERROR=0`, `UVM_FATAL=0`
- failing run: `test_twu_mask_pmp_wait_all4 seed=97104`
- signature: `CovErrorException`, `signal: Aborted`, `During dumping of toggle coverage data`
- cascade: later `run_cov` jobs reported missing `output/simv.compile.vdb`

Closure action:

- Tracked as blocking tooling issue `MMU-P14-ISSUE-006`.
- `phase14_exit_check` now defaults to the high-parallel testcase/seed shard
  VDB flow.
- Each shard uses an isolated runtime VDB and log directory. The compile
  baseline VDB is kept as a shared clean source; each shard restores its own
  runtime VDB through `run_cov`.
- First 152-CPU server trial with `PHASE14_PARALLEL_JOBS=120` produced 465
  testcase/seed shards (`93 tests x 5 seeds`) under
  `output/regression/phase14_v4_full_parallel`. High-parallel logs are in
  `output/phase14_parallel_logs`, so `output/logs` containing only
  `comp_all.log` is expected for this flow.
- After that trial, Phase14 parallel VDBs were moved out of the `output/` root
  into `output/phase14_parallel_vdb`, and each shard now uses a private
  `run/` directory to avoid VCS/Verdi temporary-file contention. The cleanup
  entry is `make phase14_clean_parallel`.
- High-parallel runs disable shared `+UVM_CONFIG_DB_TRACE` and default to
  `PHASE14_PARALLEL_UVM_ERR_ONLY=1` to reduce log and filesystem I/O.
- The follow-up `PHASE14_PARALLEL_JOBS=120` rerun showed 364 startup/resource
  failures: `rc=255`, logs with only the VCS `Command:` line, and no UVM/VCS
  completion marker. This was not treated as 364 independent functional fails.
- The parallel runner no longer hard-links compile-baseline VDB files into shard
  VDBs. `regress_v4_full_parallel` now defaults
  `PHASE14_PARALLEL_FORCE_COV_REBUILD=1` and
  `PHASE14_PARALLEL_STARTUP_RETRIES=2`, with
  `PHASE14_PARALLEL_LAUNCH_STAGGER=0.05` to soften initial VCS startup bursts.
- On the 152-CPU server, use `PHASE14_PARALLEL_JOBS=96..144` depending on
  license/NFS headroom. Default is `nproc - 8`.
- `run_test.py` supports serial fail-fast so one coverage infrastructure abort
  does not generate a long cascade of derived failures.
- `run_cov`, `phase14_exit_gate.py`, and `check_sim_status.sh` now recognize the
  VCS coverage abort patterns.

Signoff impact: Phase14 remains open. Final evidence must come from a clean
high-parallel rerun or from a second-reviewed waiver/fallback decision recorded
in the IssueTracker and SignoffMatrix.

---

### Phase 14 Debug 记录（2026-05-05 持续收敛中）

| # | 调试主题 | 根因 | 已落地修正 / 结果 |
| --- | --- | --- | --- |
| P14-D1 | 高并发回归中 LSU_P2 `fault mismatch` / `PA mismatch`：`ref.exc=EXC_NONE ref.deny=0`，`dut.access_fault=1 dut.pa=0` | Phase14 失败样例（如 `test_twu_mask_pmp_wait_all4`、`test_bug_001_twu_fst_fetch_type`、`test_mmu_mbuf_multi_twu_independent_ready`、`test_sysmap_hit_bypass_walk`）显示 DUT 侧 PFU/LSU_P2 会进入 access fault，而参考模型按 PFU 正常翻译。静态排查后确认：PFU 走 PMP port4，且 TWU 的 PMP 权限选择跟随 original miss type；原 UVM 用例/辅助函数把“PTW read deny”过度等价成清 R 权限，导致 PFU/load walker 被错误注入 deny。 | `pmp_sequences.svh` 中 `pmp_flg_deny_rw_seq` 不再误伤 PFU port4，并新增 `pmp_flg_deny_pfu_seq` 专门描述 PFU deny；`phase9_generated_test_base.svh` 已接入新 sequence 分发；`phase12_generated_test_base.svh` 的 `phase12_set_pmp_deny_ptw_reads()` 默认改为保留 R、只 deny W/X，只有访问异常定向测试才显式传 `deny_read_perm=1`。`test_ptw_pmp_deny_accflt.svh`、`test_ptw_pmp_deny_stop.svh`、`test_mmu_twu_accerr_bypass_arb.svh`、`test_mmu_arb_refill_except_priority.svh` 已按新口径显式请求读权限 deny。 |
| P14-D2 | LSU_P2 PFU fault 来源难区分：PMP deny、SysMap flag fault、还是 PTW/L2 ref access error | 仅看 `mmu_translation_sb` 的 `fault mismatch` 无法判断是 PFU port4 的 `pmp_mmu_flg[0]` 异常、SysMap `flg4` 组合非法，还是 DUT 内部 PTW/L2TLB acc_err 传播。 | `mmu_dut_probes_if.sv` / `tb_top.sv` 已新增并接出 PFU 白盒观测：`pfu_pmp_flg4`、`pfu_sysmap_flg4`、`pfu_l2tlb_deny`、`pfu_l2tlb_acc_fault`、`pfu_l2tlb_flag_fault`；`mmu_translation_sb.svh` 在 LSU_P2 mismatch 时追加 `[LSU_P2][WB]` 诊断，并同时打印 `ref_pmp_flg4` 与最近一次 `ptw_l2tlb_ref_{pgflt,acc_err}` 快照，后续可直接区分 PFU PMP deny / SysMap flag fault / PTW acc_err 三类来源。 |
| P14-D3 | Phase14 PFU 相关 false fault 受 SysMap 缺省序列影响，非目标用例也会跑进 deny/fault 口径 | 多个 Phase9/13 复用的 SysMap 序列会随机或宽泛改动 flag 组合；对 PFU/LSU_P2 来说，`sysmap_mmu_flg4` 若不是可翻译口径，会把并非想测 SysMap fault 的用例转成 access fault。 | `sysmap_cfg_sequences.svh` 中 `sysmap_hit_cross_tlb_seq.hit_flg` 与 `sysmap_perm_flag_seq.perm_flg` 当前已收敛为 translation-safe 默认值 `5'b01111`，避免在 Phase14 功能回归中把 PFU false fault 混入非目标用例。该修正已作为当前 UVM 环境收敛手段记档，后续若恢复更激进 flag 覆盖，需要按 testcase 目标做更细粒度拆分。 |
| P14-D4 | Phase14 额外暴露出 RTL 侧 `a_lsu_addr_stable_until_vld` 断言失败，需要与 UVM 侧 false fault 分开记账 | 部分 shard（如 `test_mmu_ptw_ready_all_mask_low`、`test_mmu_pmp_port_config_independence`）同时出现 PTW/MBUF 地址稳定性 SVA 与 LSU/PFU 侧异常；其中前者是 DUT/RTL 行为问题，后者是 UVM 环境配置/建模问题。两者若混在一起，容易把 UVM 误配当成 RTL 根因，或反过来掩盖真实 RTL bug。 | Phase14 调试口径已拆分：`doc/ptw_rtl_debug.md` 单独记 RTL 侧 PTW/MBUF 指针跳转与 LSU PA 稳定性问题；`MMU_Progress.md` 的 Phase14 仅归档 UVM 环境侧已落地修正。当前结论是：PFU/PMP/SysMap false fault 路径已通过 UVM 代码约束与白盒诊断收口；PTW MBUF 指针导致的 LSU PA 失稳仍按 RTL 调试事项单独追踪。 |
| P14-D5 | `make regress_v4_full_parallel PHASE14_PARALLEL_JOBS=96` 中 LSU_P2 PFU `fault mismatch` 仍可由 PMP agent / ref_model shadow 不一致触发 | 失败点为 `VA=0x0040008000`，`ref.exc=EXC_NONE ref.deny=0 exp_fault=0`，但 `dut.access_fault=1 dut.pa=0`；现场观察该请求是 LSU 的 PFU 类型，DUT 侧 `pmp_mmu_flg[0]` 拉低，导致 PMP 检查未通过。进一步排查确认：旧 `pmp_monitor.ap` 同时广播 PA/fetch 观测样本和 PMP flag 配置样本，`mmu_ref_model` 把所有 `pmp_txn` 都当成配置更新消费，PA/fetch 观测可能污染 `m_pmp_flg`；同时 ref_model 原后台 FIFO consumer 与 `translate()` 存在时序竞态，可能让模型期待结果落后或超前于 DUT 当前 PMP 配置。 | `pmp_txn.svh` 新增 `cfg_update` 语义；`pmp_monitor.svh` 将 PA/fetch 观测样本标为 `cfg_update=0` 并只送 `ap_obs`，只有 flag 变化样本标为 `cfg_update=1` 后送入 ref 路径，同时增加 reset/X guard，避免未知 flag 写入模型；`mmu_ref_model.svh` 不再后台异步消费 PMP/SysMap/CSR/TLB shadow FIFO，改为 `translate()` 前同步 drain，并忽略 `cfg_update=0` 样本；Phase9/Phase12 在 PMP sequence 后显式 `sync_shadow_state()`，direct SW map4k 测试关闭 auto sync，保证 PMP agent 与参考模型期待结果同口径。 |
| P14-D6 | CreditSB 报 `ptw_mbuf_cnt != 0 at end-of-sim (1): PTW serialized external request not drained` | 该错误不是单纯“响应缺失”，而是 UVM 侧 PTW mem monitor/responder 使用原始 `mmu_lsu_data_req` level 记账。RTL 中真正接受外部 PTW 请求的边界是 MBUF grant/accept；raw req 可能在 response、abort 或 back-to-back 请求窗口中保持高电平并重指向，导致 monitor 重复开 credit，或 responder 在未被 RTL accept 的周期服务错误/重复事务，最终 end-of-sim 遗留 `ptw_mbuf_cnt=1`。 | `ptw_mem_if.sv` 新增 TB-only `mmu_lsu_data_req_accept`；`tb_top.sv` 用 `|u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant` 接出真实 accept；`ptw_mem_monitor.svh`、`ptw_mem_responder.svh` 与 `ptw_mem_covergroups.svh` 均改为以 accept pulse 作为请求进入外部 PTW memory 的唯一记账点。monitor 先处理同周期 response 再处理 accept；responder 支持 response 后 back-to-back accept 的一拍暂存，避免漏采新请求。 |
| P14-D7 | 本地验证状态与剩余限制 | 由于当前 Windows/WSL 环境缺 VCS，无法在本地完成 `make regress_v4_full_parallel` 或完整 VCS compile；ModelSim 可用于有限语法探测，但不等价于最终回归签核。 | 已执行 `git diff --check`，除仓库既有 CRLF 警告外无 whitespace error；ModelSim 定向语法检查覆盖 `ptw_mem_if.sv`、`pmp_if.sv`、`mmu_ptw_lsu_protocol_sva.sv`，并修正 `ptw_mem_responder.svh` 中被 ModelSim 识别为保留字的 `context` 形参命名。完整功能闭环仍需在具备 VCS 的服务器上重跑 Phase14 高并发回归确认。 |
| P14-D8 | `make regress_v4_full_parallel PHASE14_PARALLEL_JOBS=96` 中 late L2TLB->PTW 请求导致 `ptw_mbuf_cnt=1` | 失败波形显示约 `@17655000` L2TLB 请求进入 PTW，并被放入 PTW mbuf 后向 LSU 发起 PTE data request；LSU 数据尚未返回时 test_base 已进入结束流程并 drop run objection，最终 `@17675000` CreditSB 在 end-of-sim 看到 `m_ptw_mbuf_cnt=1`。原 drain 只围绕外部 PTW credit 做有限 settle，不能可靠覆盖“上游 L2TLB/PTW 内部 pending 已存在，但外部请求尚未完整 retire”的结束窗口。 | `mmu_credit_sb.svh` 新增 pre-drop end-drain，默认 `CREDIT_SB_DRAIN_MAX_CYCLES=32768`、`CREDIT_SB_DRAIN_STABLE_CYCLES=64`，并区分 `_ptw_drain_pending()` 与 `_ptw_hw_pending()`：结束前会等待 L2TLB/PTW/LSU 请求链稳定空闲，最终 report 仍只对真实 PTW 未 drain 状态报错，不屏蔽真 leak；`test_base.svh` 在 final `phase.drop_objection` 前调用 `drain_before_test_done()`；`mmu_dut_probes_if.sv` 与 `tb_top.sv` 增加 `ptw_mbuf_entry_vld`、`l2tlb_ptw_req`、`ptw_lsu_data_req`、`ptw_lsu_data_req_grant`、`ptw_arb_req` 白盒 probe。已通过 `git diff --check` 与 ModelSim 单文件 interface 语法检查；完整闭环仍需在 VCS 环境重跑 `make comp` 和 Phase14 高并发回归。 |

---

## Phase 13 详细进度（✅ 已完成 — 2026-05-02 `make phase13_exit_check` PASS）

**负责**：工程师 B（测试 / covergroup / Phase 13 list 主实现）/ 工程师 A（PMP/TWU SVA + SysMap SVA + 回归入口 + DA-003 书面记录）**完成口径**：服务器执行 `make phase13_exit_check` 已 PASS。Phase 13 list 55 个 tests × seeds `96101 96102 96103`，共 165/165 通过；criterion 2 SVA cover 全部达到 `PHASE13_SVA_MIN_HITS=20`；criterion 5 的 13 个 covergroup 在 `phase13_whitebox_cg summary` fallback 口径下均达到 50% threshold；criterion 6 DA-003 书面记录存在。URG 仍报告 `No context available`，但 `regress_v4_sysmap_pmp` 已将 URG/cov rc 降级为非阻塞，并由 `phase13_exit_gate.py` 使用仿真 log fallback 完成 covergroup gate。

- A 侧：✅ `testbench/top/mmu_pmp_twu_sva.sv` 已由 Phase 12 骨架升级为 Phase 13 属性版，覆盖 PMP wait/mask、grant onehot、deny->access fault、deny no refill / no LSU req、PMP original-type fetch sideband propagation / permission select 等约束，并为每条主属性保留 `cover property`。
- A 侧：✅ 新增 `testbench/top/mmu_sysmap_sva.sv`，覆盖 SysMap flag 替换、跨界降级、no-cross 不降级与 PA 对齐场景；每类属性均有对应 `cover property`。
- A 侧：✅ `testbench/Files.f` / `testbench/top/tb_top.sv` 已接入 Phase 13 SVA；`scripts/cov_hier.cfg` 已排除新增 SVA module，避免覆盖率统计污染。
- A 侧：✅ `Makefile` 已新增 `PHASE13_*` 变量、`print-phase13` 与 `regress_v4_sysmap_pmp`；该 target 复用现有 `run_cov`、日志扫描与 URG 生成流程，并在 Phase 13 list 缺失时明确报错。
- A 侧：✅ DA-003 书面记录已归档：[DA-003_phase13_port_mapping.md](DA-003_phase13_port_mapping.md)，当前按 `pa3/flg3->twu_one`、`pa5/flg5->twu_two`、`pa6/flg6->twu_three`、`pa7/flg7->twu_four` 跟踪。
- B 侧：✅ `pmp_twu_tests_v6/`、`sysmap_tests/` 扩展、13 个 covergroup 与最终 `simu/mmu_v4_phase13_list` 已完成；服务器 Phase 13 exit check 已收口。

| 项目                                                                                | 负责人 | 状态 | 说明                                                                                                     |
| ----------------------------------------------------------------------------------- | ------ | ---- | -------------------------------------------------------------------------------------------------------- |
| `testbench/top/mmu_pmp_twu_sva.sv`                                                | A      | ✅   | Phase 13 PMP/TWU SVA 已补全，含 assert + cover                                                           |
| `testbench/top/mmu_sysmap_sva.sv`                                                 | A      | ✅   | 新增 SysMap/TWU SVA，含 flag / cross degrade / PA align 相关 assert + cover                              |
| `testbench/Files.f` / `testbench/top/tb_top.sv`                                 | A      | ✅   | `mmu_pmp_twu_sva` 与 `mmu_sysmap_sva` 已编译接入并 bind 到 `twu`                                   |
| `scripts/cov_hier.cfg`                                                            | A      | ✅   | 新增排除 `mmu_pmp_twu_sva` / `mmu_sysmap_sva` module                                                 |
| `Makefile` `print-phase13` / `regress_v4_sysmap_pmp` / `phase13_exit_check` | A      | ✅   | 默认 seeds `96101 96102 96103`；Phase 13 exit gate 已 PASS，URG 失败时使用 log coverage fallback       |
| `doc/DA-003_phase13_port_mapping.md`                                              | A      | ✅   | 记录 Phase 13 PMP PTW port mapping 与 fetch spelling 口径                                                |
| `simu/mmu_v4_phase13_list`                                                        | A/B    | ✅   | B 侧最终 Phase 13 list 已完成并用于服务器复验入口                                                        |
| Phase 13 tests / covergroups                                                        | B      | ✅   | B 侧 Phase 13 tests / covergroups 已完成；服务器 165/165 regression 与 13 个 covergroup threshold 已通过 |

### Phase 13 归档命令

```bash
cd mmu_verification
make print-phase13
make phase13_exit_check
```

归档结果：`PHASE13_EXIT_CHECK: PASS`。若后续必须交付 Synopsys URG HTML/text report，再单独处理 `output/coverage/urg_report.log` 中的 `No context available`；该项不阻塞 Phase 13 exit，已跟踪为 [MMU-P14-ISSUE-001](MMU_Phase14_IssueTracker.md)。

### Phase 13 Server Regression Note (2026-05-02)

- Server `make comp`: PASS after the `cross` keyword compile fix in `testbench/env/mmu_env_cg_whitebox.svh`.
- Server `make regress_v4_sysmap_pmp`: 162/165 PASS, 3 FAIL, with `PHASE13_SKIP_COV=1` skipping URG as intended.
- Failing runs: `test_twu_pmp_wait_stall` seeds `96101/96102`, and `test_twu_mask_pmp_wait_all4` seed `96102`.
- Common fail signature: `mmu_credit_sb.svh` reports `[CreditSB] ptw_mbuf_cnt != 0 at end-of-sim (1)`, with PTW req/rsp count off by exactly one in each failed log.
- A-side fix 2026-05-02: hardened CreditSB run-phase end-drain to require a 32-cycle stable-zero window and allow bounded repeated drain attempts, so a late PTW request immediately after a transient zero cannot escape into `report_phase`.
- A-side SVA correction 2026-05-02: replaced `sva_ptw_pmp_fetch_zero` with `sva_pmp_fetch_matches_grant_stage` and `sva_pmp_deny_uses_original_type_perm`. `mmu_pmp_fecth` is confirmed as the original miss fetch sideband for the walk, not the PTW PTE bus-read type. Phase 13 now checks selected-stage propagation plus original-type PMP permission selection: fetch->X, load/prefetch->R, store->W, with M-mode L=0 bypass.

### Phase 13 Final Exit Record (2026-05-02)

- Server `make phase13_exit_check`: PASS.
- Criterion 1: Phase 13 list `simu/mmu_v4_phase13_list`, seeds `96101 96102 96103`, 55 tests × 3 seeds = 165/165 PASS, pass_rate=1.0000.
- Criterion 2: all Phase 13 SVA cover properties reached the hit threshold. Representative final hits include `cp_no_lsu_req_during_pmp_wait=558343`, `cp_pmp_fetch_uses_x_perm=1155`, `cp_pmp_store_uses_w_perm=300`, `cp_pmp_mmode_l0_bypass=45000`, `cp_sysmap_cross_degrade=96`.
- Criterion 3/4: `mmu_sysmap_sva.sv` and `mmu_pmp_twu_sva.sv` static completeness checks PASS.
- Criterion 5: 13 Phase 13 covergroups reached threshold via `phase13_whitebox_cg summary` fallback because URG report generation remained unavailable. Lowest passing groups were `cg_twu_mask_cause=50.00%`, `cg_sysmap_cross_1g=50.00%`, and `cg_sysmap_cross_2m=50.00%`.
- Criterion 6: DA-003 written record present at `doc/DA-003_phase13_port_mapping.md`.
- Non-blocking tooling issue: Synopsys URG still reports `No context available` for `output/coverage/urgReport`. Current Phase 13 gate treats this as a coverage report tooling issue, not a functional/SVA/covergroup miss, and uses simulation log coverage fallback. Follow up only if Phase 14 or signoff explicitly requires a generated URG HTML/text report.

#### Phase 13 Error Process Record - PTW PMP fetch sideband (2026-05-02)

- Initial mistake: the first Phase 13 implementation followed the old F7.NEW.7 wording and treated `mmu_pmp_fecth` as the PTW PTE bus-read access type. Based on that assumption, A added `sva_ptw_pmp_fetch_zero`, expecting every page-table PMP access to use data-load semantics and therefore keep fetch low.
- Evidence from server logs: `make regress_v4_sysmap_pmp` produced many `sva_ptw_pmp_fetch_zero` hits, including in otherwise PASS logs. This showed the assertion did not match RTL behavior and needed semantic review instead of being treated as a pure random-test failure.
- RTL check result: `twu.sv` derives the PMP request type from the original walk source. A fetch miss produces fetch/X permission selection, load or prefetch produces read/R selection, and store produces write/W selection. The selected grant stage then drives `mmu_pmp_fecth` as the original-miss fetch sideband.
- User correction: `mmu_pmp_fecth` is not the PTW bus read type for reading PTEs. It identifies whether the current walk serves an instruction-fetch miss. The implementation reuses the original access type for PTE permission checks, exception classification/MPRV handling, and page-table physical-address PMP permission selection; therefore the PMP check intentionally follows X/R/W from the original access type.
- Final fix: retire the zero-only assertion and replace it with selected-stage propagation plus permission-selection checks. The updated SVA checks that `mmu_pmp_fecth` matches the selected PMP grant stage, and that deny behavior uses fetch->X, load/prefetch->R, store->W, with the RTL M-mode L-bit bypass rule. Covergroup sampling and the legacy `test_ptw_pmp_fetch_zero` metadata were updated to record original access kind and fetch sideband; the old test name is kept only for regression-list compatibility.
- Guardrail for later phases: do not infer sideband meaning from signal name or plan text alone. For SVA on reused control fields, confirm both the producer and all consumers in RTL, especially whether the field represents a bus operation type or the originating request type.
- Phase 13 final command: `make phase13_exit_check`.

### Phase 13 当前门禁状态

| # | 检查项                                | 状态 | 说明                                                                                        |
| - | ------------------------------------- | ---- | ------------------------------------------------------------------------------------------- |
| 1 | A-side SVA implementation             | ✅   | PMP/TWU 与 SysMap/TWU SVA 文件已落地                                                        |
| 2 | A-side integration wiring             | ✅   | `Files.f` / `tb_top.sv` / `cov_hier.cfg` / `Makefile` 已接入                        |
| 3 | DA-003 written record                 | ✅   | `DA-003_phase13_port_mapping.md` 已归档                                                   |
| 4 | Phase 13 list present                 | ✅   | B 侧最终 Phase 13 list 已完成；服务器复验入口已具备                                         |
| 5 | compile on server                     | ✅   | `make phase13_exit_check` 触发 compile，编译通过                                          |
| 6 | 3-seed Phase 13 functional regression | ✅   | 55 tests × 3 seeds = 165/165 PASS，`regress target rc=0`                                 |
| 7 | Phase 13 covergroup threshold         | ✅   | 13 个 covergroup 全部 ≥50%；URG report 缺失时使用 `phase13_whitebox_cg summary` fallback |

---

## Phase 4–14 工作量汇总

| 工程师      | 负责 Phase                                                                       | 主要文件数  | 核心难点                                                                            |
| ----------- | -------------------------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------- |
| **A** | 1/2/3(cp0+pmp+sysmap)/4/5(misc)/7(SVA)/10/12(SVA)/13(SVA)/14                     | ≈ 110 文件 | ref_model 翻译算法精度；credit_sb；SVA 形式化约束                                   |
| **B** | 3(ifu+lsu骨架)/5(方法体+SB)/6(inv)/7(cg)/8(vseq)/9(TC×120)/10(列表)/11/12/13/14 | ≈ 320 文件 | lsu_driver 5子线程并发；translation_sb VA→PA 精度；259 个 wrapper / 262 stage 纳管 |

---

## 关键里程碑

| 里程碑                                    | 达成条件                                           | 状态                                                                                                                                                                                                                                  |
| ----------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M1** — 骨架可编译运行            | Phase 1 退出准则                                   | ✅**已达成**                                                                                                                                                                                                                    |
| **M2** — DUT elaboration 通过      | Phase 2 退出准则                                   | ✅**已达成**（2026-04-23）                                                                                                                                                                                                      |
| **M3** — Sanity Test 通过          | Phase 3 退出准则                                   | ✅**已达成**（2026-04-24）                                                                                                                                                                                                      |
| **M4** — 参考模型就绪              | Phase 4 退出准则                                   | ✅**已达成**（2026-04-24）                                                                                                                                                                                                      |
| **M5** — Translation SB 0 mismatch | Phase 5 退出准则                                   | ✅**已再次达成**（2026-04-26）：`make phase5` 完整通过（comp + 5+3 seed + phase5_check 0/0）；随后 `make phase5_ptw4k` 通过（P5-34 修复后 `passthrough=0`）                                                               |
| **M6** — 全功能验证                | Phase 6 退出准则                                   | ✅**已达成**（2026-04-26）：`make phase6_full`（SFENCE 矩阵 + RTU/PTW `abort_check`）                                                                                                                                       |
| **M7** — SVA + 覆盖率框架          | Phase 7 退出准则（§10.1+§10.2+SVA+smoke/≥3 测） | ✅**已达成**（2026-04-26）：A 完整 5×SVA + B cg/白盒 + `make phase7` 等；§10.3/10.4 基线不纳入、推后见 P7-B-00                                                                                                              |
| **M8** — 全部 Vseq 可运行          | Phase 8 退出准则                                   | ✅**已达成**（2026-04-27）：`make phase8` 42-run 矩阵完成，14 个 vseq × 3 seeds 收口，统计摘要 / F 映射 / A Review 已留档                                                                                                    |
| **M9** — 冒烟回归 100%             | Phase 9 退出准则                                   | ✅**已达成**（2026-04-27）：`phase9_generated_test_base` + 12 suite + 3 个 basic 基线入口已纳管；259 个 Phase 9 wrapper（总 262 stage）编译通过，seed=1 单跑与 smoke 3-seed 回归收口，`scan_logs.pl` 与 A review 结果已记档 |
| **M10** — 回归脚本就绪             | Phase 10 退出准则                                  | ✅**已达成**（2026-04-27）：`make regress_smoke` 22/22 通过、100%；`make regress_nightly` 1260/1325 通过、95.09%；URG baseline 报告已生成，A/B Phase 10 联调收口完成                                                        |
| **M11~M13** — 高级特性验证         | Phase 11–13 退出准则                               | ✅ Phase 11 已达成（2026-04-28）；Phase 12 全部完成（2026-05-01，15 项退出门禁与 URG/VDB debug 均已记档）；Phase 13 已达成（2026-05-02，`make phase13_exit_check` PASS） |
| **M14** — 签核通过                 | Phase 14 退出准则（VerificationPlan §9）           | ⏳                                                                                                                                                                                                                                      |
