---
name: phase7_b_stage_split
overview: 将 Phase 7（B 主责黑盒+白盒 covergroup、A 主责 5 个 SVA+bind 并行联调）拆为可独立启动的多阶段任务，每阶段含任务相关文件、量化产出、退出准则、阶段门禁与 A/B 依赖边界；与 Phase6 计划文档体例一致，便于你逐个手动开启执行。
todos:
  - id: stage0-preflight
    content: Stage0 基线冻结、与 A 对齐 Phase7 范围及 ≥3 个覆盖用例矩阵
    status: pending
  - id: stage1-spec-audit
    content: Stage1 完成 BuildPlan §10.1 与 7 个 vif/agent 的规格对表，阻塞项清零
    status: pending
  - id: stage2-ifu-cg
    content: Stage2 完成 ifu_covergroups 与 BuildPlan/注释门禁对齐
    status: pending
  - id: stage3-lsu-cg
    content: Stage3 完成 lsu_covergroups（pipe0/1/2、inv）对齐
    status: pending
  - id: stage4-cp0-pmp-sysmap
    content: Stage4 完成 cp0 / pmp / sysmap_cfg 三份黑盒 covergroups
    status: pending
  - id: stage5-misc-ptwmem
    content: Stage5 完成 misc（HPCP）与 ptw_mem（含 delay CG 闭合）黑盒
    status: pending
  - id: stage6-whitebox
    content: Stage6 实现 §10.2 白盒集中 file + 可选 §10.3 子集（若 Stage0 纳入）
    status: pending
  - id: stage7-env-integrate
    content: Stage7 更新 mmu_env/Files.f/mmu_top_cfg 挂载白盒与回归编译链
    status: pending
  - id: stage8-cov-gate
    content: Stage8 与 A 联调 SVA、覆盖率硬门禁、MMU_Progress M7 收口
    status: pending
isProject: false
---

# Phase 7（B）分阶段拆分执行方案

## 目标与边界

- **总目标**（与 [doc/MMU_UVM_BuildPlan_v3_final.md](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) §13 Phase 7、[doc/MMU_UVM_TaskDivision.md](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) §3 Phase 7 一致）：

  - **B 主责**：

    1. **黑盒**：[BuildPlan §10.1](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 所覆盖的全部 `*_covergroups.svh`，对应 **7 个 agent 目录**（`ifu` / `lsu` / `cp0` / `pmp` / `sysmap_cfg` / `ptw_mem` / `misc`）各 1 个文件、共 **7 个**。
    2. **白盒**：[BuildPlan §10.2](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 所述 **DUT 内部 hierarchical reference** 的 covergroup，集中在 **1 个** testbench 侧实现文件（建议与 `mmu_perf_mon` 同目录的 `testbench/env/`，如 `mmu_env_cg_whitebox.svh`；名称以团队约定为准）。
    3. **集成**：在 [mmu_env.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_env.svh) 中 **build/connect** 白盒与现有 agent 上已实例化的 `*_cg_wrapper`，保证仿真树中可采样、不破坏 scoreboard/TLM。

  - **A 主责（并行、非 B 提交代码但为 B 的验收依赖）**：

    - 5 个 SVA 文件（分工表命名：`mmu_sva.sv` / `mmu_arb_sva.sv` / `mmu_l2tlb_rrpv_sva.sv` / `mmu_plru_sva.sv` / `credit_sva.sv`）与 [tb_top.sv](d:/mmu_uvm/mmu_verification/testbench/top/tb_top.sv) **bind**；见 [TaskDivision](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) Phase 7 退出准则第 1、5、6 条。

- **B-only 不执行**：不实现 Phase 8 的 `mmu_vseq_lib.svh` 全 14 个 vseq 主体、不将 Phase 7 与「120 个用例 / 回归列表」混为一谈；Phase 7 的激励 **只复用现网 Makefile 已有 test** 作为覆盖/门禁载体。

- **与 Phase 8 的文档口径**：

  - [TaskDivision](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) **§4 依赖图**标注：`Phase 7 (B: Covergroup) → Phase 8 (B: vseq)`。同一文档 **§2 总表**中曾将 vseq 标在 Phase 7 行，**以后文 §3 Phase 7/8 表 + 依赖图为准**：**vseq 为 Phase 8**。

- **§10.3 / §10.4 边界**（BuildPlan 第 10 章中 v3/v4 增补的 gap/MAEE 等）：

  - **Phase 7 基线**按分工表为 **7（黑盒）+1（白盒）** 与 A 的 **5（SVA）**；**§10.2 为必达**；**§10.3/10.4 是否同迭代完成** 必须在 **Stage 0** 书面冻结。默认建议：**先合入 §10.2 基线，再视 RTL/用例是否已具备** 在 **Stage 6** 内以「可选子包」拉取 §10.3 子集，避免与 Phase 11+ 重复或范围失控。

- **前置项目状态**：B 在 Phase 7 假设 **M6/Phase6 已达成**（[MMU_Progress.md](d:/mmu_uvm/doc/MMU_Progress.md) 中 M6 已勾）；否则 inv/translation 类场景不足以支撑 `cg_lsu_inv` 等黑盒，需在 Stage 0 标注 **依赖缺口**。

## 输入依据文件

- 当前进度与里程碑：[d:/mmu_uvm/doc/MMU_Progress.md](d:/mmu_uvm/doc/MMU_Progress.md)
- 任务分工、Phase 7 七条退出准则（含 **SVA 0 违例、≥3 个 test、每 bin 命中、HTML 报告、注释**）：[d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) §3 Phase 7
- Cover 落点与域表：[d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) §10（10.1 / 10.2 / 10.3 可选）及 §13 Phase 7
- 编译与现网 Phase5/6 门禁： [d:/mmu_uvm/mmu_verification/Makefile](d:/mmu_uvm/mmu_verification/Makefile)（`comp`、`phase5`、`phase6`、`phase6_full` 等）

**路径约定（本计划一律采用）**：工程根 `d:/mmu_uvm/`，UVM/仿真 **在 `d:/mmu_uvm/mmu_verification/` 下** `make`；testbench 路径形如 `d:/mmu_uvm/mmu_verification/testbench/...`（**不要**写成省略 `mmu_verification` 的 `testbench/...`）。

## 分阶段执行（B 主责；A 在 Stage0/8 强交集）

### Stage 0 — 基线冻结与依赖门禁（Pre-flight）

- **任务相关文件**：

  - [d:/mmu_uvm/mmu_verification/testbench/Files.f](d:/mmu_uvm/mmu_verification/testbench/Files.f)
  - [d:/mmu_uvm/mmu_verification/testbench/top/tb_top.sv](d:/mmu_uvm/mmu_verification/testbench/top/tb_top.sv)
  - [d:/mmu_uvm/mmu_verification/testbench/env/mmu_env.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_env.svh)
  - [d:/mmu_uvm/mmu_verification/Makefile](d:/mmu_uvm/mmu_verification/Makefile)
  - 协作（只读）：A 的 SVA 文件清单与 `bind` 草图、DUT 顶层例化名（常见 `u_dut`）

- **产出标准**：

  - **一页**「Phase7-B 可开工」清单，至少包含：DUT 层次名与后续白盒 `ref` 前缀；[Files.f](d:/mmu_uvm/mmu_verification/testbench/Files.f) 中 covergroup/白盒/包 **编译顺序** 是否需调整（与 A 合并时序）。
  - 书面冻结：**§10.3/10.4 是否纳入本阶段**、纳入则列出 **F-ID / covergroup 名** 上界，避免与 Phase 11+ 重复造轮子。
  - 选定 **≥3 个不同 `TEST_NAME`**，用于最后覆盖率门禁，且能在当前仓库 **单跑**（建议组合示例，**以你本地可用为准并写入该清单**）：

    1. `test_mmu_translation_sanity` 或与 Phase5 门禁同家族的翻译场景（[Makefile 中 `PHASE5_TEST`](d:/mmu_uvm/mmu_verification/Makefile) 默认名）。
    2. `test_mmu_invalidate_sfence_matrix` 或与 Phase6 门禁同族（[`PHASE6_TEST`](d:/mmu_uvm/mmu_verification/Makefile) 默认；覆盖 inv/LSU/cp0 路径）。
    3. 第三个：`test_mmu_phase6_rtu_flush_ptw`、或 `test_mmu_sanity_csr_pmp_sysmap`、或 Makefile `help` 中推荐的 **其他已存在** test，**必须**与 1/2 在 **vseq/场景维度** 可区分，以便 TaskDivision 所谓「≥3 个不同 test」成立。

- **退出准则**：

  - 上述清单经 **A/B 书面确认**（评论或短文档即可）；**未**确认前，不进入白盒 DUT 层次（Stage 6）的实质编码。
  - 若 A 的 SVA/bind **尚未**合入，允许 B 先完成黑盒 Stages 1–5 与本地 `comp`，但 **Stage 8 硬门禁不通过** 直至 A 合入，且须在清单中标 **阻塞项**。

### Stage 1 — BuildPlan §10.1 与 7 个 vif / agent 规格对表

- **任务相关文件**（每个 agent 的 covergroup、interface、agent 成组核对）：

  - [d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_covergroups.svh) · [d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_if.sv](d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_if.sv) · [d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_agent.svh](d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_agent.svh)
  - [d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_covergroups.svh) · `lsu_if.sv` · [lsu_agent.svh](d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_agent.svh)
  - [d:/mmu_uvm/mmu_verification/testbench/cp0_agent/cp0_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/cp0_agent/cp0_covergroups.svh) · `cp0_if.sv` · `cp0_agent.svh`
  - [d:/mmu_uvm/mmu_verification/testbench/pmp_agent/pmp_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/pmp_agent/pmp_covergroups.svh) · `pmp_if.sv` · `pmp_agent.svh`
  - [d:/mmu_uvm/mmu_verification/testbench/sysmap_cfg_agent/sysmap_cfg_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/sysmap_cfg_agent/sysmap_cfg_covergroups.svh) · `sysmap_cfg_if.sv`（或实际文件名）· `sysmap_cfg_agent.svh`
  - [d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_covergroups.svh) · `ptw_mem_if.sv` · [ptw_mem_agent.svh](d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_agent.svh)
  - [d:/mmu_uvm/mmu_verification/testbench/misc_agent/misc_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/misc_agent/misc_covergroups.svh) · `misc_if.sv` · `misc_agent.svh`
  - [d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) §10.1 表（行 2012–2022 附近）

- **产出标准**：

  - 表格/矩阵，列：covergroup 名、采样 `iff` / 边沿、各 coverpoint 与 **vif/内部信号** 的位域、与 BuildPlan 的差异、**达成 TaskDivision 每 bin 命中** 时依赖的用例/场景（若需额外定向，在 Stage8 前标注）。
  - 对 **IFU**：明确 [BuildPlan](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 要求的 `cp_va_seg(va[62:39] 4 bin)` 与 **当前** `ifu_covergroups` 中 `cp_va_high[38]` 等实现的 **映射或修订计划**。

- **退出准则**：

  - 无未解决的 **blocking** 位宽/信号不存在问题；**非 blocking** 项有 JIRA/纪要或明确推迟到后一 Phase。
  - 本阶段**不要求**全量 `comp` 后覆盖命中，但要求 **可编码**，否则不得进入对应 agent 的 Stage 2+。

### Stage 2 — `ifu_agent` 黑盒 `ifu_covergroups.svh` 落地

- **任务相关文件**：

  - [d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_covergroups.svh)
  - [d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_agent.svh](d:/mmu_uvm/mmu_verification/testbench/ifu_agent/ifu_agent.svh)（`m_cg` / `set_vif` / 若需 `run_phase` 与 CG 的协同）

- **产出标准**：

  - `cg_ifu_req` / `cg_ifu_rsp` 与 [BuildPlan §10.1](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 在 **触发条件与 coverpoint 集合** 上 **一致或可论证等价**；每个 covergroup **≥2 行**中文注释（覆盖目标、关键 bin，满足 TaskDivision #7）。
  - 多采样路径下 **无重复计数竞争**；若用 `run_phase` 内手动 `sample()`，**注释**写清与 LRM 默认 `covergroup` 带 `iff` 的差异。

- **退出准则**：

  - 在 `mmu_verification` 下 `make comp`（或项目惯例 `comp` 目标）**0 error**；新增 warning 有记录或 `//` 工具豁免说明（与 TaskDivision Phase 7 #1 口径一致，最终由 Stage8 总扫）。
  - 至少一次定向仿真（可为翻译 sanity）log 中可看到 **本 agent CG 的采样活动** 或 覆盖率数据库中存在 **本 CG 的 bin 有非零命中**（后者可放到 Stage8 统一，但本 Stage 应 **无** 明显「从不触发」的编码错误）。

### Stage 3 — `lsu_agent` 黑盒 `lsu_covergroups.svh` 落地

- **任务相关文件**：

  - [d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_covergroups.svh)
  - [d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_if.sv](d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_if.sv)
  - [d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_agent.svh](d:/mmu_uvm/mmu_verification/testbench/lsu_agent/lsu_agent.svh) · `lsu_monitor.svh`（若 inv 与 pipe 的可见性需对齐）

- **产出标准**：

  - 覆盖 [BuildPlan](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 所列 `cg_lsu_pipe[2]`（pipe0/1）、`cg_lsu_pipe2`、`cg_lsu_inv`；`cross` 维度与 DUT/协议一致，**非法交叉** 用 `ignore_bins` 或合法组合定义写清，避免全表不可达。
  - `cg_lsu_inv` 的 **模式 / done 时序** 等 bin 在 Phase6 用例中 **有激励路径**；若需额外用例，在 Stage0 的第三 test 中体现或新增 Makefile 只读说明。

- **退出准则**：

  - `make comp` 0 error；与 Phase5/6 不冲突的 **UVM 日志** 下 inv 与 pipe 至少一类 CG 在仿真中**可**达到非全零 bin（最终「每 bin」由 Stage8 用 HTML 报告证明）。

### Stage 4 — `cp0` / `pmp` / `sysmap_cfg` 三份黑盒 covergroups

- **任务相关文件**：

  - [d:/mmu_uvm/mmu_verification/testbench/cp0_agent/cp0_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/cp0_agent/cp0_covergroups.svh) · [cp0_if.sv](d:/mmu_uvm/mmu_verification/testbench/cp0_agent/cp0_if.sv) · `cp0_agent.svh`
  - [d:/mmu_uvm/mmu_verification/testbench/pmp_agent/pmp_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/pmp_agent/pmp_covergroups.svh) · `pmp_if.sv` · `pmp_agent.svh`
  - [d:/mmu_uvm/mmu_verification/testbench/sysmap_cfg_agent/sysmap_cfg_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/sysmap_cfg_agent/sysmap_cfg_covergroups.svh) · 对应 if · `sysmap_cfg_agent.svh` · `sysmap_cfg_monitor.svh`（若采样依赖 monitor 时间窗）

- **产出标准**：

  - `cg_cp0`：priv、MXR、SUM、MPRV、MPP、SATP 模式，以及 [BuildPlan](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 所述 **priv 切换** 的采样定义（允许 `if` 或 `sequence` 风格辅助，**注释**说明等价性）。
  - `cg_pmp`：`cp_entry_hit` 0..7、`cp_acc_type`、`cp_violation`、**cross**。
  - `cg_sysmap`：8 region 与 **attr 分量** 在 **配置写** 或 **可观测短脉冲** 上采样，与 [BuildPlan](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md)「配置变更脉冲」一致。
  - 三文件均满足 **每 covergroup ≥2 行** 注释（TaskDivision #7）。

- **退出准则**：

  - `make comp` 0 error；三类 agent 的 CSR/PMP/SysMap 在 **sanity 或 phase5/6 用例** 中至少能驱动 **每类 1+ bin**（Stage8 扩到「每 bin」若任务过重，须书面偏差说明与 A 一致）。

### Stage 5 — `misc` + `ptw_mem` 黑盒 covergroups 闭合

- **任务相关文件**：

  - [d:/mmu_uvm/mmu_verification/testbench/misc_agent/misc_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/misc_agent/misc_covergroups.svh) · [misc_if.sv](d:/mmu_uvm/mmu_verification/testbench/misc_agent/misc_if.sv) · `misc_agent.svh`
  - [d:/mmu_uvm/mmu_verification/testbench/env/mmu_perf_mon.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_perf_mon.svh)（**仅**核对 HPCP/统计口径不冲突、不复读 Progress 为 CG 源）
  - [d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_covergroups.svh](d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_covergroups.svh) · [ptw_mem_responder.svh](d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_responder.svh)（或实际带 **delay/异常** 语义的 responder 体）
  - [d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_agent.svh](d:/mmu_uvm/mmu_verification/testbench/ptw_mem_agent/ptw_mem_agent.svh)

- **产出标准**：

  - `misc`：`cg_hpcp` 在 `hpcp_mmu_cnt_en`（或 if 中约定名）为真时，对 I/D/J TLB miss 三类事件采样；与 [BuildPlan](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) 一致。
  - `ptw_mem`：**补全** `cg_rsp_delay_range`（文件头已注明 Phase7 应完成；当前为 TODO 壳）；`cg_ptw_rsp_kind` 的 normal / bus_err 与接口一致；若 delay 在 responder 为内部变量，需 **显式**在 wrapper 中暴露采样周期（如通过 `uvm_reg` 式 latch 或 `clocking` 采样，**不得** 裸引用未在 time slot 稳定的数据）。

- **退出准则**：

  - `make comp` 0 error；PTW 侧在 **有 PTW/LSU 总线活动** 的用例中，`cg_ptw_rsp_kind` 与 delay bins **有可达性设计**；若工具链限制，须在 Stage8 的 waiver 中 **单列** 并 **非默认绕过**「每 bin」要求。

### Stage 6 — 白盒 covergroup 集中实现（BuildPlan §10.2，可选 +§10.3）

- **任务相关文件**（新建为主）：

  - 建议路径：`d:/mmu_uvm/mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`（或经评审的等效名）
  - DUT RTL 树（**只读**）：`ptw` / `mmu_l1itlb` / `mmu_l1dtlb` / `mmu_l2tlb` / `mmu_l2tlb_reqq` / `ct_mmu_tlboper` 等子模块 **实例名** 以 [tb_top.sv](d:/mmu_uvm/mmu_verification/testbench/top/tb_top.sv) 与 elaboration 为准
  - [d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md) §10.2；若 Stage0 纳入，附加 §10.3 表

- **产出标准**：

  - 实现 [BuildPlan §10.2](d:/mmu_uvm/doc/MMU_UVM_BuildPlan_v3_final.md)：`cg_ptw_walk`、`cg_l2tlb_bank`、`cg_l1itlb`、`cg_l1dtlb`、`cg_l2_reqq`、`cg_tlboper_fsm`；**类封装** 为 `uvm_component` 或等效、在 **UVM 树** 中可挂接；`virtual interface` 不足处用 **`bind` 或 hierarchical ref** 到 DUT 内部 net/reg，**禁止** 硬编码与 elaboration 不符的路径。
  - 每个白盒 **covergroup** **≥2 行** 注释；`default disable iff` / 复位 与 DUT 一致。

  - **若**纳入 §10.3 子集：在文件头用 `ifdef` 或独立 `import` 块分隔，并列出与 **F-ID** 的对应，避免与 [VerificationPlan v3 后续](d:/mmu_uvm/doc) 的 gap TC 实现重复时产生维护双份。

- **退出准则**：

  - `make comp` 与 **elaboration** 无 `illegal hierarchical name`；至少一次长仿真或三 test 之一中 **每个 §10.2 的 covergroup 结构** 在覆盖率 DB 中 **有实例、且整体有 hit**；§10.3 若开，则对纳入表 **逐条** 有 hit 或 **登记 bin 名 + 推迟原因**。

### Stage 7 — `mmu_env` 集成、配置开关与 `Files.f`

- **任务相关文件**：

  - [d:/mmu_uvm/mmu_verification/testbench/env/mmu_env.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_env.svh)
  - [d:/mmu_uvm/mmu_verification/testbench/env/mmu_top_cfg.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_top_cfg.svh)（如增加 `en_whitebox_cg`、`en_*` 等）
  - [d:/mmu_uvm/mmu_verification/testbench/Files.f](d:/mmu_uvm/mmu_verification/testbench/Files.f)
  - [d:/mmu_uvm/mmu_verification/testbench/mmu_env_pkg.sv](d:/mmu_uvm/mmu_verification/testbench/mmu_env_pkg.sv) 或等效 **include 链**（若白盒以 `` `include`` 进包）
  - Stage6 产出的 `mmu_env_cg_whitebox.svh`（名从实）

- **产出标准**：

  - 在 `build_phase` **create** 白盒 wrapper；`connect_phase` 或 `end_of_elaboration` 完成 DUT 句柄/层次指针的绑定；不破坏 [mmu_env.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_env.svh) 内既有 **translation_sb / invalidate_sb / credit_sb / tlm** 连接顺序。
  - 若 [mmu_top_cfg.svh](d:/mmu_uvm/mmu_verification/testbench/env/mmu_top_cfg.svh) 增加开关：默认在 Phase7 中 **开** 白盒/黑盒 CG，**关** 的路径仅用于调试且文档说明。
  - [Files.f](d:/mmu_uvm/mmu_verification/testbench/Files.f) 更新后 **`make comp` 单命令** 可复现，无手改命令行多文件补编译。

- **退出准则**：

  - 全量 `comp` 通过；UVM 打印或 `+UVM_VERBOSITY` 可确认白盒在树中，且 **7 个 agent 内** `m_cg` 的 `set_vif` 仍被调用；若回归脚本尚未有 `phase7` 目标，本 Stage 交付物中 **向 Makefile 提需求** 或 在 **Stage8 一并** 加 `make phase7`（可在 Stage8 实现）。

### Stage 8 — 与 A 联调、覆盖率硬门禁、M7 与 Progress 收口

- **任务相关文件**：

  - A：`tb_top` bind 与 5 个 `*_sva.sv`；B 侧无责或只读合并冲突
  - [d:/mmu_uvm/mmu_verification/Makefile](d:/mmu_uvm/mmu_verification/Makefile)（可新增 `phase7` / `phase7_cov` 目标，**与 Phase6 体例一致**）
  - 覆盖率输出目录、HTML 报告路径（VCS/Verdi/项目脚本 以实际为准，见 `scripts/`)
  - [d:/mmu_uvm/doc/MMU_Progress.md](d:/mmu_uvm/doc/MMU_Progress.md) 中 **M7**、Phase 7 行

- **产出标准**（**对齐** [TaskDivision](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) Phase 7 退出表 **#1–#7**）：

  1. **编译**：`make compile` / `comp` **0 errors**；**0 warnings** 或 全量列表明细 + 批准（分工表第 1 条重点：**SVA bind scope** 告警为 0 或已豁免备案）。
  2. **文件存在性**：7 个 `d:/mmu_uvm/mmu_verification/testbench/*_agent/*_covergroups.svh` + 1 个白盒文件 存在并参与链接（第 2 条）。
  3. **覆盖**：[TaskDivision 原文](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) 为 **「所有 covergroup 每一个 bin 至少 1 hit」**（第 3 条）—— 本计划**执行口径** 为：对 **在 BuildPlan §10.1/§10.2（及 Stage0 已纳入的 §10.3）中列为 **已实现** 的 covergroup 与显式 `bins` / `ignore_bins` 外 **已声明的 bin**，在 **HTML 报告** 中 **≥1 hit**；对 **unreachable/保留/待 RTL** bin，须 **waiver 条目** 指向 JIRA/BuildPlan 章节，且 **A+B 双签**。
  4. **HTML 报告**：路径写入 Progress 或本仓库短 README（仅当团队允许，否则 **仅** Progress/ MR 描述）（第 4 条）。
  5. **SVA**：log 中 **0 assertion failure**、assertion summary 可复查（第 5 条）。
  6. **A** 的 SVA **验证意图** 注释完整（第 6 条，A 的交付，B 的验收）。
  7. **B** 的每个 covergroup **≥2 行** 说明注释 已走读（第 7 条）。

- **退出准则**（**硬门禁**）：

  - 使用 Stage0 冻结的 **≥3 个** `TEST_NAME`，**可相同 seed 或 项目默认 seed** 单跑，三份可对比的 **log + 覆盖率**；**任一条** 出现 `UVM_ERROR` / SVA fail / 覆盖率 **未命中且无已批准 waiver** → **不**关闭 M7。
  - [MMU_Progress.md](d:/mmu_uvm/doc/MMU_Progress.md) 中 **M7** 状态更新为已达成、并附 **报告路径、test 三件套名称、A 的 commit 或 tag** 指针。
  - 对外 handoff：声明 **Phase 8（vseq）可启动**，**无** 未决 Phase7 blocking。

## 阶段间门禁与阻断策略

- **Gate A（Stage0→1）**：三 test 名 + 是否纳 §10.3/10.4 已书面冻结；DUT 层次名可指向。
- **Gate B（Stage1→2）**：对表无 blocking；IFU/LSU 的 cover 修订**路线** 已写清。
- **Gate C（Stage2→3）**：IFU `comp` 与 CG 可采样 **或** 明确推迟理由（不推广到全 Phase7）。
- **Gate D（Stage3→4）**：LSU 同类。
- **Gate E（Stage4→5）**：cp0/pmp/sysmap 三文件 `comp` 与 bin 可达性 无**结构性** 全零。
- **Gate F（Stage5→6）**：ptw_mem `cg_rsp_delay_range` 非空实现；misc HPCP 与 perf_mon **不抢同一采样竞争** 已审。
- **Gate G（Stage6→7）**：白盒 **无** 非法层次；`cg_*` 在 coverage DB 有壳。
- **Gate H（Stage7→8）**：全量 `comp` + `mmu_env` 不破坏 **Phase5/6 既有** `make phase5` / `make phase6_full` 或团队规定的 **不回归** 基线（若因 CG 采样引入 **新** 竞态，须先修再进 Stage8）。

- **最终 Gate I（Phase7 Exit）**：仅当 **A 的 SVA+bind 已合入** 且 [TaskDivision](d:/mmu_uvm/doc/MMU_UVM_TaskDivision.md) 七条 **全满足** 或 **已批准 waiver** 清单齐备。

## 风险与缓解（Phase7 高相关）

- **DUT 层次/拼写** 与 RTL 改版不一致 → 白盒 ref 在 Stage6 用 **parameter 化** 或 `+define+DUT_HIER=...` 与一次 elaboration 打印交叉校验；与 `scripts/cov_hier.cfg` 后续（Phase 10）**前缀** 对齐 [tb_top 实例名](d:/mmu_uvm/mmu_verification/testbench/top/tb_top.sv)。

- **TaskDivision #3「每 bin」** 与 实施成本 → 早日在 Stage0/8 采用 **waiver 最小集** 与 **F-ID** 对应，避免尾声才发现不可达。

- **黑盒多 `sample()` 与 `run_phase` 永久循环** 性能/重复采样 → 用 **单一采样点/事件** 或 **clocking block** 统一边沿，并在注释中写清 LRM 语义。

- **A 的 SVA 与 B 的 cover 竞争仿真时间/异步复位** → Stage8 联合跑；若 SVA 失败，**先** 判 A 责任再改 CG 采样，避免无原则削弱断言。

- **scope**：§10.4 大量 MAEE/PMP 后续功能 **勿** 在 Phase7 无冻结情况下一次性涌入；坚持 Stage0 开关。

## Skill 使用判断

- 与 [phase6 拆分说明](d:/mmu_uvm/doc/phase6_b_stage_split_a3982c49.plan.md) 相同：当前 Cursor 默认 **挂载 skills** 偏工作流，**不直接**提高 SystemVerilog covergroup 的代码质量；本拆分以 **BuildPlan/RTL 细读** 与 **可选手动 UVM/验证规范** 为主。
- 若你本地在 `.cursor` 或团队库中 **自建有** `coverpoint/cross` 模板或公司 **DV lint skill**，**推荐** 用于 **Stage1（对表）** 与 **Stage6（白盒层次）** 的重复结构，减少手误。

## 与 Phase6 计划体例的对照

| 体例项 | Phase6 文档 | 本 Phase7 文档 |
|--------|-------------|----------------|
| 目标与 B-only 边界 | 有 | 有，并列 A 并行职责 |
| 输入依据 | Progress + TaskDivision + BuildPlan | 同上 + `mmu_verification/Makefile` |
| 分阶段 文件/产出/退出 | Stage0 起，逐条可执行 | Stage0–8，路径统一 `mmu_verification/testbench/...` |
| 硬门禁/矩阵 | 4 模式×100×3 seeds 等 | TaskDivision 七条 + 3 test 覆盖矩阵 |
| 风险与 Skill | 有 | 有 |

**说明**：若需将本文件同步为 Cursor 内置 plan，可复制 frontmatter+正文到 `.cursor/plans/` 下同名件；**以 `doc/phase7_b_stage_split.plan.md` 为项目内权威副本即可。**
