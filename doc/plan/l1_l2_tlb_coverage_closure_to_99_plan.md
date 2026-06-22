# L1TLB / L2TLB 覆盖率收敛到 99%+ 的逐项推进计划

- 文档路径: `doc/plan/l1_l2_tlb_coverage_closure_to_99_plan.md`
- 输入报告:
  - `doc/l1tlb_uvm_review/l1tlb_covp_uncovered_code_report.md`（L1TLB，未覆盖唯一对象 1190 条，含 13 LINE / 86 COND / 9 BRANCH / 2 FSM / 434+636 TOGGLE / 10 ASSERT&COVER）
  - `doc/l2tlb_uvm_review/l2tlb_covp_uncovered_code_report.md`（L2TLB，未覆盖唯一对象 263 条，含 2 LINE / 47 COND / 2 BRANCH / 2 FSM / 83+120 TOGGLE / 7 ASSERT&COVER）
- 覆盖率数据源: `mmu_verification/output/coverage/phase14_urgReport` ← `phase14_merged.vdb`
- 目标: 所有相关模块的 LINE / COND / BRANCH / FSM / TOGGLE / ASSERT（含 cover）均收敛到 **≥ 99%**。
- 强约束（来自任务下达人）:
  1. **只能修改 UVM 侧（testbench / env / sequences / SVA testbench / vseq / test list / covp 配置 / 激励）**；
  2. **禁止修改 RTL**（`mmu/rtl/*.sv` / `mmu/rtl/*.v`）；
  3. **一次只推进一项覆盖率缺口**（每个 TASK 独立开发、独立回归、独立 merge，禁止把多项功能激励塞进同一次提交）；
  4. **以更高质量地验证 DUT 为原则**：每一项必须对应一条真实可激励、可观测、可检查的功能路径；不允许通过 force / backdoor load / 注入伪响应、放宽 scoreboard、把不可达代码加进 exclude 文件等方式刷数字。

---

## 1. 工作原则（所有 TASK 通用）

每一条 TASK 必须独立满足下列硬约束，否则不允许合入主干。

1. **根因导向**: 每个 TASK 标注其根因（root cause）以及它将要闭合的 URG 唯一对象清单（模块 + 行号 / 信号名 / SVA 名）。同一根因下若同时连带闭合了多条 URG 记录，必须在文档中如实列出，但 TASK 的工作量按"一个根因 = 一个 TASK"。
2. **激励合法性**: 只允许通过 DUT 的标准输入接口（LSU port0/1、IFU、CP0、PMP、SYSMAP、PTW slave、tlbop、rtu_flush、reset 等）产生激励；不允许在 testbench 中直接 `force` DUT 内部信号，不允许通过 hierarchical reference 写 DUT 寄存器或 RAM。
3. **checker 不放宽**: 不允许为了闭合覆盖率而关闭 scoreboard、关闭 reference model、关闭既有 SVA 或降低其严重级别；不允许向 `exclude_v4.tgl` / `exclude_v4.do` 中新增 RTL 行（exclude 仅用于已被 design 团队签字的不可达/不在验范围内的代码）。
4. **可复现、可回归**: 每个 TASK 必须给出 `+UVM_TESTNAME=...`、seed、plusarg、test list 条目，确保他人能用一条命令复现该 TASK 的覆盖率增量。
5. **观测点 + 验收标准**: 每个 TASK 给出"何时算完成"——必须按第 2.5 节定义的 C1–C5 五维度逐条给出可量化、可复核的验收证据（覆盖率指标、SVA/cover 命中、功能正确性、回归稳定性、文档归档），任何一维度不达标即视为未完成。
6. **DUT 行为正确**: TASK 引入的新激励产生的所有响应必须通过 translation scoreboard / spec scoreboard / ref model / SVA；任何 UVM_ERROR / UVM_FATAL 必须先定位、修复后才能进入下一项。
7. **一次一项**: 不允许在同一次 PR/commit 中同时落地两个 TASK 的激励。Coverage merge 的回归可以包含多个已各自通过单项闭环的 TASK。

---

## 2. 通用开发与回归流程

每一个 TASK 的生命周期固定为下列 8 步，必须按序执行，且**只有当前 TASK 走完 1–8 步并 merge 后，才能开始下一个 TASK**。

1. **调查 (Investigate)**: 阅读对应 RTL/SVA 代码上下文，确认未覆盖对象真实可达，且属于本 UVM 环境（`tb_top.u_dut.u_mmu_l1dtlb` / `x_mmu_l1itlb` / `x_mmu_l2tlb` 子树）的合法激励范围。
2. **设计 (Design)**: 写出最小、合法、可观测的激励序列草图，明确要新引入的 vseq / sequence / test wrapper / cov list 条目；若依赖现有 vseq，则声明复用点。
3. **实现 (Implement)**: 只动 UVM 侧代码；新增/扩展的 vseq 放在 `mmu_verification/testbench/env/` 下既有的 `mmu_l1dtlb_coverage_vseq.svh` / `mmu_l2tlb_directed_vseq.svh` / 新建 `mmu_l*_coverage_vseq.svh`；新增 test wrapper 放在 `mmu_verification/testbench/test/coverage_tests/`。
4. **编译 (Compile)**: `make comp` 必须干净；新增 include 必须进入 `test_pkg.sv` 的对应区段（或对应 `*_suite.svh`）。
5. **单测 (Single-test smoke)**: 用新 `+UVM_TESTNAME` 跑 1 个 seed，确认 UVM 通过、目标 SVA `Matches≥1` 或目标行被命中（可用 `urg -line` 单测 report 比对）。
6. **覆盖率增量 (Delta covp)**: 把该测试的 vdb 合并到 baseline，重新 `urg -full64 -dir ...`，确认本 TASK 名义闭合的 URG 对象全部由 0 变 1；同时确认**没有引入新的未覆盖对象**（防止副作用）。
7. **DUT 质量自检 (Quality gate)**: 检查 `translation_sb` / `l1dtlb_spec_sb` / `mmu_l2tlb_*_sb` / `phase6c_l2_shadow` / `phase6d_sva` 等检查器没有触发新增错误；如有 SVA/cover 命中，必须能解释其行为。
8. **合入 (Merge)**: 在 `simu/` 下新增/更新 test list（例如 `phase15_l1_l2_cov_closure_list`），把该测试纳入回归；提交 commit 信息里固定带 `[CovTask <ID>]` 标签。

---

## 2.5 任务验收标准通用模板（每个 TASK 必须逐条满足）

每个 TASK 在第 8 步"合入"之前，必须按下述 5 个维度（**C1–C5**）逐条提供可量化、可复核的验收证据。任何一维度未达标即视为该 TASK 未完成，禁止合入主干。

- **C1 覆盖率指标验收（Coverage metric acceptance）**
  - 必须列出本 TASK 名义闭合的全部 URG 唯一对象（模块 + 行号 / 信号位段 / SVA 名），并逐一标注"baseline: Not Covered → 闭合后: Covered"。
  - 给出本 TASK 影响范围内每个模块、每种覆盖率类型（LINE/COND/BRANCH/FSM/TOGGLE/ASSERT）的量化前后对比（如 `mmu_l1dtlb COND 83.62% → ≥99%`）。
  - 必须确认**未引入新的未覆盖对象**（delta covp 报告中新增 uncovered 计数 = 0）。

- **C2 SVA / cover 命中验收（Assertion & cover hit acceptance）**
  - 列出本 TASK 目标 SVA / cover point 名称，给出 URG 中 `RealSuccesses≥1` 或 `Matches≥1` 的截图/数值证据。
  - 反向要求：本 TASK 激励不得触发任何既有 SVA `assertion failure`（含 `mmu_l*_sva`、`credit_sva`、`l2tlb_negative_sva_guard` 等）；若某既有 SVA 因本 TASK 激励自然首次命中，必须给出行为解释并归档。

- **C3 功能正确性验收（Functional correctness acceptance）**
  - 必须列出本 TASK 激励需通过的 scoreboard / ref model 检查器清单（如 `translation_sb`、`l1dtlb_spec_sb`、`mmu_l2tlb_txn_shadow`、`mmu_l2tlb_rrpv_exact_scoreboard`、`phase6c_l2_shadow`、`phase6d_sva`），并附最终 UVM report 中"0 UVM_ERROR / 0 UVM_FATAL"证据。
  - 对本 TASK 引入的关键激励路径，必须给出至少 1 条"预期 DUT 行为 → 实际观测"的对照断言（如"flush 命中 WFG 后下一周期 state==IDLE"，由 probe if 观测确认）。

- **C4 回归稳定性验收（Regression stability acceptance）**
  - 本 TASK 的 `+UVM_TESTNAME` 必须用 **≥3 个不同 seed** 全部 UVM 通过（无 timeout、无 UVM_ERROR/FATAL、无 assertion failure）。
  - 目标覆盖率增量（C1 中列出的 URG 对象从 0→1）必须在所有 seed 的合并 vdb 上稳定复现，不依赖单一 seed 的偶发时序。

- **C5 文档与 evidence 验收（Documentation & evidence acceptance）**
  - 归档目录 `doc/l1tlb_uvm_review/evidence/<TASK_ID>/` 或 `doc/l2tlb_uvm_review/evidence/<TASK_ID>/`，至少包含:
    1. 单测试 log（含 UVM report 末尾的 PASS / 0 error 摘要）；
    2. 该测试的 urg 单测 report（`urg -dir <test.vdb> -report ...`）；
    3. delta covp diff（baseline vs baseline+本 TASK）；
    4. 目标 SVA 命中证据（urg report 中该 SVA 行的 Matches/Successes 数值）；
    5. commit hash 与 test list 登记条目。
  - 在本计划文档第 12 节 checklist 中勾选对应 TASK 并附上述归档路径。

> 注：C1–C5 五维度中只要有一项不达标，该 TASK 必须回到第 3 步"实现"重新迭代，不允许通过放宽检查、加 exclude 或多任务捆绑来绕过。

---

## 3. 覆盖率基线快照（取自两份 review）

### 3.1 L1TLB 当前覆盖率（来自 `l1tlb_covp_uncovered_code_report.md` 汇总）

| 模块 | SCORE | LINE | COND | TOGGLE | FSM | BRANCH | ASSERT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `mmu_l1dtlb` | 86.97 | 95.22 | 83.62 | 71.98 | -- | 97.06 | -- |
| `mmu_l1dtlb_mb_entry` | 93.03 | 95.45 | 87.67 | 89.90 | 100 | 92.11 | -- |
| `mmu_l1dtlb_expt_cam` | 87.15 | 100 | 80.77 | 67.84 | -- | 100 | -- |
| `mmu_l1dtlb_hit_rd` | 88.93 | 100 | 78.66 | 77.06 | -- | 100 | -- |
| `mmu_l1dtlb_install` | 84.67 | 100 | 79.41 | 59.25 | -- | 100 | -- |
| `mmu_l1dtlb_scheduler` | 94.10 | 100 | 96.77 | 79.62 | -- | 100 | -- |
| `mmu_l1itlb` | 81.90 | 92.06 | 78.65 | 73.53 | 77.78 | 87.50 | -- |
| `ct_mmu_iutlb_entry` | 96.28 | 100 | 97.44 | 87.69 | -- | 100 | -- |
| `ct_mmu_iutlb_fst_entry` | 95.96 | 100 | 97.44 | 86.40 | -- | 100 | -- |
| `mmu_l1dtlb_sva` (总模块) | 93.83 | 100 | 100 | 79.50 | -- | 100 | 89.67 |

### 3.2 L2TLB 当前覆盖率（来自 `l2tlb_covp_uncovered_code_report.md` 汇总）

| 模块 | SCORE | LINE | COND | TOGGLE | FSM | BRANCH | ASSERT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `mmu_l2tlb` | 88.94 | 99.43 | 90.67 | 85.18 | 71.43 | 98.00 | -- |
| `mmu_l2tlb_reqq` | 97.24 | 100 | 97.63 | 91.32 | -- | 100 | -- |
| `mmu_l2tlb_reqq_entry` | 93.67 | 100 | 100 | 74.67 | -- | 100 | -- |
| `mmu_l2tlb_replacement_policy` | 99.96 | 100 | 100 | 99.84 | -- | 100 | -- |
| `mmu_l2tlb_rrpv_wbuf` | 93.99 | 100 | 76.19 | 99.78 | -- | 100 | -- |
| `mmu_l2tlb_mb` | 95.53 | 100 | 93.06 | 89.04 | -- | 100 | -- |
| `mmu_l2tlb_mb_entry` | 95.08 | 100 | 94.12 | 86.19 | -- | 100 | -- |
| `ct_mmu_l2tlb_tag_array` | 90.21 | -- | -- | 90.21 | -- | -- | -- |
| `ct_mmu_l2tlb_data_array` | 91.47 | -- | -- | 91.47 | -- | -- | -- |
| `mmu_l2tlb_rrpv_sva` | 96.00 | -- | -- | -- | -- | -- | 96.00 |
| `mmu_l2tlb_mb_sva` | 86.96 | -- | -- | -- | -- | -- | 86.96 |
| `mmu_l2tlb_rrpv_wbuf_sva` | 89.66 | -- | -- | -- | -- | -- | 89.66 |

### 3.3 距离 99% 的差距清单（按类型聚合，闭合优先级依据差距大小排序）

- **L1TLB 最大差距**: TOGGLE（`mmu_l1dtlb` 71.98%、`mmu_l1itlb` 73.53%、`mmu_l1dtlb_install` 59.25%、`mmu_l1dtlb_expt_cam` 67.84%、`mmu_l1dtlb_hit_rd` 77.06%）; COND（`mmu_l1dtlb_hit_rd` 78.66%、`mmu_l1dtlb_install` 79.41%、`mmu_l1itlb` 78.65%）。FSM 仅 `mmu_l1itlb` 77.78% 一项差距。
- **L2TLB 最大差距**: TOGGLE（`mmu_l2tlb_reqq_entry` 74.67%、`mmu_l2tlb` 85.18%、`ct_mmu_l2tlb_tag_array` 90.21%）。COND（`mmu_l2tlb_rrpv_wbuf` 76.19%、`mmu_l2tlb` 90.67%、`mmu_l2tlb_mb` 93.06%）。FSM `mmu_l2tlb` 71.43%。ASSERT `mmu_l2tlb_mb_sva` 86.96%、`mmu_l2tlb_rrpv_wbuf_sva` 89.66%。

---

## 4. 任务依赖与总体推进顺序

任务被划分为 5 个阶段，**阶段间严格串行，阶段内也建议按 ID 顺序逐项完成**（因为同一阶段内的多个 TASK 往往共享同一份 vseq 文件，并行修改会冲突）。

- **Phase A — 共享底座修复**（影响所有后续阶段的 vseq 基础能力，必须最先完成）。
- **Phase B — L1DTLB 行为补齐**（含 LINE / BRANCH / FSM / COND / 部分参数化 TOGGLE 的根因修复）。
- **Phase C — L1ITLB 行为补齐**（WFG FSM、perm/expt 矩阵、ITLB reset 等）。
- **Phase D — L2TLB 行为补齐**（PFU、5-way hit、arb 写类型、rrpv_wbuf 真 满、MB full、多 way tag/data 写）。
- **Phase E — 全局收敛扫尾**（参数化高位 PPN/VPN/FLG/ASID 位段的定向激励，依赖 A–D 的 vseq 能力）。

依赖图（简化）:

```
A0 vseq 基类扩展 ──► B1..Bn ──► E1
                  ├─► C1..Cn ──► E2
                  └─► D1..Dn ──► E3
```

具体 ID 与依赖见第 5、6、7、8、9 节。

---

## 5. Phase A — 共享底座 TASK

### TASK A0 — 扩展 directed vseq 公共能力（无覆盖率目标，基础设施）

- **目的**: 为后续所有覆盖率 TASK 提供一组可复用、受 scoreboard 检查的原子激励任务，避免每项 TASK 重复造轮子。
- **修改文件（仅 UVM）**:
  - `mmu_verification/testbench/env/mmu_l1dtlb_coverage_vseq.svh`: 在既有 `l1dtlb_directed_vseq` 派生类之外，新增一个 `mmu_l1_tlb_common_vseq`（也继承 `l1dtlb_directed_vseq`）作为后续 coverage vseq 的公共父类，封装以下受控原子任务：
    - `task drive_lsu_miss_to_entry(int entry_idx, bit store, bit [2:0] iid);` 通过对特定 VPN 模式发射 miss，使 `l1dtlb_ent_*[entry_idx]` 被 install/refill/invalidate。
    - `task drive_ifu_fetch_to_itlb_entry(int idx);` 通过 `ifu_sequential_fetch_seq` 命中 iutlb 的 16 entry。
    - `task assert_rtu_flush_at_vpn(va_t va);` 在指定 VPN miss in-flight 时发 `rtu_yy_xx_flush`。
    - `task assert_mid_test_reset();` 触发 `cpurst_b` 真实 1→0→1（用于闭合多个 SVA 的 `cpurst_b` toggle 1→0=No 缺口）。
  - `mmu_verification/testbench/env/mmu_l2tlb_directed_vseq.svh`: 扩展或新建 `mmu_l2tlb_common_vseq`，封装：
    - `task drive_l2tlb_write_with_type(bit [2:0] acc_type, bit write, bit tag_msb);` 经 arb 接口驱动 `arb_l2tlb_acc_type==3'b101/001` + `arb_l2tlb_write=1` + `arb_l2tlb_tag_din[TAG_WIDTH-1]` 取值可变。
    - `task drive_multiway_hit(int ways_hit_mask);` 通过向多个 way 写相同 VPN + 不同 ASID/global 组合，构造 5-way `final_way_hit_kid0..4` 命中分布。
    - `task drive_pfu_pipe2_with_pmp_deny();` 已有 `mmu_l2tlb_pfu_chk_deny_vseq` 的抽象版本。
- **验收标准（C1–C5）**:
  - **C1**: 本 TASK 为基础设施，不直接闭合 URG 对象；要求新增的每个原子任务（`drive_lsu_miss_to_entry` / `drive_ifu_fetch_to_itlb_entry` / `assert_rtu_flush_at_vpn` / `assert_mid_test_reset` / `drive_l2tlb_write_with_type` / `drive_multiway_hit` / `drive_pfu_pipe2_with_pmp_deny`）在后续至少 1 个 TASK 中被实际调用并产生覆盖率增量（以"复用证据"形式归档）。
  - **C2**: 不触发任何既有 SVA 失败；新增原子任务内部若有自检断言（如 `assert(grant_onehot)`），需 RealSuccesses≥1。
  - **C3**: `make comp` 0 error / 0 fatal；至少 1 个既有测试切到新父类后 UVM PASS，`translation_sb` / `l1dtlb_spec_sb` 报告 0 error。
  - **C4**: ≥3 个 seed 跑既有回归子集（`phase14_dut_quality_closure_list` 中取 5 个代表测试）全部 PASS。
  - **C5**: 归档编译日志、复用证据清单（列出哪些后续 TASK 将使用哪个原子任务）。
- **DUT 质量原则**: 该 TASK 不直接闭合任何 URG 记录，但所有后续 TASK 复用其原子任务；该 TASK 必须为每一原子任务提供 scoreboard 自检。

---

## 6. Phase B — L1DTLB 覆盖率 TASK（按 ID 顺序逐项完成）

> 命名约定: `L1DTLB-T<NN>`；每项 TASK 对应一个 `+UVM_TESTNAME=test_mmu_l1dtlb_cov_<name>` 测试 wrapper，扩展 `l1dtlb_directed_test_base`，并在 `mmu_l1dtlb_coverage_vseq.svh` 中新增同名 vseq；test list 文件 `simu/phase15_l1_l2_cov_closure_list` 增量登记。

### TASK L1DTLB-T01 — DTLB entry 8..15 全量 install/hit/invalidate（参数化 TOGGLE/COND/cover 根因修复）

- **覆盖目标（根因）**: 现有激励只命中 entry 0/1，导致 `l1dtlb_ent_ppn[N][...]`、`l1dtlb_ent_vpn[N][...]`、`l1dtlb_ent_flg[N][...]`、`l1dtlb_ent_pgs[N][...]`、`mb_entry_*[N]`（N=8..15）、`gen_l1dtlb_entry_sva[N].a_va8_inv_clears_matching_entry`（14 个 SVA 实例）、line 1116/1120/1190/1194 在 entry 2..7 上的 COND 未覆盖。
- **URG 名义闭合对象（部分代表性条目）**:
  - `mmu_l1dtlb` 行 1116 / 1120 / 1190 / 1194 的所有 entry ≥2 实例。
  - `mmu_l1dtlb_sva.gen_l1dtlb_entry_sva[10..15].a_va8_inv_clears_matching_entry`（共 14 个 assertion）。
  - `mmu_l1dtlb_hit_rd`/`mmu_l1dtlb_sva` 中 `entry_ppn[0][15]`、`entry_ppn[0][27:24]`、`entry_flg_vec[0]`、`entry_ppn_vec[15]` 等位段 toggle。
- **根因**: `mmu_l1dtlb_coverage_vseq` 中循环步长 `i = 0..71` 但 VPN 哈希到 dutlb entry 索引主要由 `va[11:8]` 等低位决定，未能覆盖全部 16 个 dutlb entry。
- **激励设计**:
  1. 复用 `TASK A0` 的 `drive_lsu_miss_to_entry(entry_idx, ...)`；
  2. 新 vseq `mmu_l1dtlb_entry_sweep_vseq`: 对 `entry_idx = 0..15` 依次:
     - 计算能命中 entry_idx 的 VPN（白盒：读 `m_probe_vif.l1dtlb_ent_vpn[idx]` 与 `l1dtlb_ent_pgs[idx]` 反推；或直接 `va[15:12] = idx << 1` 走 4KB 模式）；
     - 发射 miss → 等待 PTW refill → 读 hit；
     - 紧接发 `tlboper_utlb_inv_va_req` 命中该 entry 的 VPN 低 8 位；
     - 等待 `a_va8_inv_clears_matching_entry[idx]` Matches++。
- **UVM 修改文件**:
  - `mmu_verification/testbench/env/mmu_l1dtlb_coverage_vseq.svh` 新增 vseq；
  - `mmu_verification/testbench/test/coverage_tests/test_mmu_l1dtlb_cov_entry_sweep.svh`（新建）；
  - `mmu_verification/testbench/test/test_pkg.sv` 新增 include；
  - `mmu_verification/simu/phase15_l1_l2_cov_closure_list`（新建列表）登记。
- **验收标准（C1–C5）**:
  - **C1**:
    - `mmu_l1dtlb` line 1116 / 1120 / 1190 / 1194 在 entry 2..7 上全部 `Covered`（baseline: 多处 `1 1 1 Not Covered` / `0 0 1 Not Covered` → 闭合后: Covered）。
    - `mmu_l1dtlb` 与 `mmu_l1dtlb_sva` 中 entry 参数化位段（`entry_ppn[N][...]` / `entry_flg[N][...]` / `entry_ppn_vec[...]` 等 N=8..15）toggle 未覆盖计数较 baseline 下降 ≥ 80%。
    - delta covp 报告新增 uncovered 计数 = 0。
  - **C2**:
    - `mmu_l1dtlb_sva.gen_l1dtlb_entry_sva[0..15].a_va8_inv_clears_matching_entry` 全部 16 个实例 `Matches≥1`（baseline: entry 10..15 共 14 个 Matches=0）。
    - 不触发任何既有 assertion failure。
  - **C3**: `translation_sb` + `l1dtlb_spec_sb` 报告 0 UVM_ERROR / 0 UVM_FATAL；probe if 观测确认每次 `tlboper_utlb_inv_va_req` 后目标 entry `vld=0`、后续同 VPN miss 重新走 PTW。
  - **C4**: ≥3 个 seed 全部 PASS；entry 8..15 的 toggle 增量在 3 seed 合并 vdb 上稳定复现。
  - **C5**: 归档单测 log、urg 单测 report、entry sweep 前后位段 toggle diff、SVA Matches 证据、test list 条目。
- **DUT 质量原则**: 每次 invalidate 后 scoreboard 必须看到该 entry 的 `vld=0` 且后续同 VPN miss 会重新走 PTW；不允许直接 `force l1dtlb_ent_vld[idx]=1`。

### TASK L1DTLB-T02 — JTLB/UTLB refill 路径（LINE 987–991 未执行）

- **覆盖目标**:
  - `mmu_l1dtlb.sv:987` `entry_ref_ppn = jtlb_utlb_ref_ppn;`
  - `mmu_l1dtlb.sv:988` `entry_ref_flg = jtlb_utlb_ref_flg;`
  - `mmu_l1dtlb.sv:989` `entry_ref_pgflt = jtlb_dutlb_pgflt;`
  - `mmu_l1dtlb.sv:990` `entry_ref_acflt = 1'b0;`
  - `mmu_l1dtlb.sv:991` `entry_ref_pgs = jtlb_utlb_ref_pgs;`
  - 以及 `mmu_l1dtlb.sv:980` 的分支覆盖 `0 1 Not Covered`（即 `is_ptw_refill=0, is_jtlb_refill=1`）。
- **根因**: 现有回归主要通过 PTW 走 refill，JTLB/UTLB（`jtlb_dutlb_ref_*`）的 refill-from-jtlb 路径从未被激励；该分支要求 `is_jtlb_refill=1` 即 `jtlb_dutlb_ref_cmplt && jtlb_dutlb_ref_id == i[EID_WIDTH-1:0]`。
- **激励设计**: 设计一个 cp0 + ptw_mem 组合场景，让 DUT 进入"jtlb refill 优先于 ptw refill"的状态：构造 dutlb miss → 在 PTW 仍 pending 时，通过 `ptw_mem_agent`（其扮演 jtlb 来源）发 `jtlb_dutlb_ref_cmplt=1` + 合法 `jtlb_dutlb_ref_id` + `jtlb_dutlb_ref_ppn/flg/pgs`，并控制 `ptw_l1dtlb_ref_cmplt=0`。
  - 必须先在 `ptw_mem_agent` 增加/复用一个 "jtlb_dutlb_refill_response_seq"（若不存在）；该 seq 必须经 `translation_sb` 校验最终 PA。
- **UVM 修改文件**:
  - `mmu_verification/testbench/ptw_mem_agent/` 下若没有 jtlb response seq 则新增（参考既有 ptw response seq 的合法驱动）；
  - `mmu_verification/testbench/env/mmu_l1dtlb_coverage_vseq.svh` 新增 `mmu_l1dtlb_jtlb_refill_vseq`；
  - `mmu_verification/testbench/test/coverage_tests/test_mmu_l1dtlb_cov_jtlb_refill.svh`（新建）；
  - `test_pkg.sv` 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb.sv:980` 分支组合 `0 1` Covered（baseline: Not Covered）；line 987 / 988 / 989 / 990 / 991 LINE `Hit≥1`（baseline: 0/N）；`mmu_l1dtlb` LINE 覆盖率 ≥ 99%；delta covp 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；若 `mmu_l1dtlb_install_sva` / `mmu_l1dtlb_sva` 中与 jtlb refill 相关的 cover 首次命中需归档解释。
  - **C3**: `translation_sb` 对 jtlb refill 完成后的 PA 校验通过（0 error）；probe if 观测到 `is_jtlb_refill=1 && is_ptw_refill=0` 至少 1 次；ref_model 与 DUT 的 entry_ref_ppn/flg/pgs 一致。
  - **C4**: ≥3 个 seed 全部 PASS；line 987–991 在 3 seed 合并 vdb 上稳定 Hit≥1。
  - **C5**: 归档单测 log、urg line report（987–991 命中证据）、jtlb response seq 的合法驱动说明、test list 条目。
  - **附带**: `ptw_l1tlb_*` 与 `jtlb_utlb_*` 高位 bit toggle 由本 TASK 部分自然带动，完整闭合在 Phase E 的 E-L1-01 完成。
- **DUT 质量原则**: 不允许 backdoor 写 PTE；JTLB 响应必须来自合法 page table 内存模型。

### TASK L1DTLB-T03 — PTW refill 异常组合（line 305 / 315 COND 多 term）

- **覆盖目标**:
  - `mmu_l1dtlb.sv:305` 表达式 `ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err) && mb_entry_vld[ptw_l1dtlb_ref_id] && (state==WFC) && !flush` 缺失组合 `0 1 1 1 1`、`1 1 0 1 1`。
  - `mmu_l1dtlb.sv:315` 表达式 `jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt && mb_entry_vld[..] && state==WFC && !flush` 缺失组合 `1 1 0 1 1`、`1 1 1 0 1`、`1 1 1 1 0`。
- **根因**: 这些 term 组合分别表示: (a) 异常位为 0 时仍触发 expt_wr0/1； (b) ref_id 指向无效 mb entry； (c) mb entry state 非 WFC； (d) flush 同时发生。现有测试要么是纯异常要么是纯正常，没有专门走"条件部分满足、整体不成立"的边沿。
- **激励设计**: 复用 `mmu_l1dtlb_mb_expt_coverage_vseq`，扩展出 `mmu_l1dtlb_ptw_refill_cond_matrix_vseq`，定向构造下列子场景（每个子场景一个独立 test wrapper 以保证"一次一项"）:
  - 子场景 a: ptw 完成无 pgflt/acc_err → expt_wr0 应=0；
  - 子场景 b: ptw 完成有 pgflt 但 mb_entry_vld=0；
  - 子场景 c: ptw 完成有 pgflt、mb entry valid 但 state≠WFC（如 STATE_WFI）；
  - 子场景 d: ptw 完成有 pgflt、mb entry WFC，但同周期 `rtu_yy_xx_flush=1`。
  - 对 jtlb 路径同样 4 个子场景。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 vseq（内部含 8 个子场景 loop）；
  - 新建 1 个 test wrapper `test_mmu_l1dtlb_cov_refill_cond_matrix.svh`（因为 8 个子场景属于同一根因 = line 305/315 表达式的 term 边沿覆盖；用户"一次一项"约束按根因粒度划分）；
  - test_pkg.sv / test list 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb.sv:305` 表达式缺失组合 `0 1 1 1 1` / `1 1 0 1 1` Covered；`:315` 缺失组合 `1 1 0 1 1` / `1 1 1 0 1` / `1 1 1 1 0` Covered；`mmu_l1dtlb` COND 覆盖率提升且 delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；`mmu_l1dtlb_sva` 中 expt_wr 相关 cover 若首次命中需归档。
  - **C3**: `l1dtlb_spec_sb` 对 8 个子场景（ptw/jtlb × 4 term 边沿）的 `expt_wr0/1_vld` 行为有预期断言并通过；`translation_sb` 0 error；每种子场景附"条件部分满足 → expt_wr 应保持原值"的对照观测。
  - **C4**: ≥3 个 seed 全部 PASS；8 个子场景对应 term 组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 8 子场景的 log + 每场景的 spec_sb 断言摘要 + urg COND report + test list 条目。
- **DUT 质量原则**: 通过 scoreboard 校验"在组合不成立时，expt_wr0/1 必须保持原值"，这是 RTL 真实行为，不能为刷覆盖率而伪造。

### TASK L1DTLB-T04 — same_4k_miss01 与 allocator dedup SVA

- **覆盖目标**:
  - `mmu_l1dtlb.sv:802` `same_4k_miss01` 表达式缺失组合 `1 0 1 1 1`、`1 1 1 0 1`（即 miss0_abort_q / miss1_abort_q 不同步取值）。
  - `mmu_l1dtlb.sv:817` `miss0_vld_q && !miss0_abort_q && !mb_hit0 && !flush` 缺失 `1 0 1 1`；以及 miss1 侧 `1 0 1 1 1`。
  - `mmu_l1dtlb_allocator_sva.a_same_4k_dual_miss_dedup` assertion（Successes=0）。
  - `mmu_l1dtlb_allocator_sva.cp_l1dtlb_c004_same_vpn_dedup` cover（Matches=0）。
- **根因**: 这两条 SVA 触发要求"双端口同周期请求相同 VPN + 至少 1 个 free mb entry + gnt0 且 !gnt1"。现有 `concurrent` 系列测试双端口 VPN 不同；`mb_high_entry_matrix` 没有专门构造"同 VPN"。
- **激励设计**: 新 vseq `mmu_l1dtlb_same_vpn_dual_miss_vseq`:
  - 在 free mb entry > 0 时，对 pipe0、pipe1 同周期发同一 VPN 的 load miss；
  - 通过 `configure_ptw_delay` 控制让一个端口在 PTW 应答前收到 `lsu_mmu_abort`（构造 miss0_abort_q / miss1_abort_q 的不同步），覆盖 line 802 的 2 种缺失组合。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 vseq；
  - `coverage_tests/test_mmu_l1dtlb_cov_same_vpn_dedup.svh`；
  - test_pkg.sv / test list 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb.sv:802` 缺失组合 `1 0 1 1 1` / `1 1 1 0 1` Covered；`:817` 缺失组合 `1 0 1 1`（miss0 侧）与 `1 0 1 1 1`（miss1 侧）Covered；delta 新增 uncovered = 0。
  - **C2**: `mmu_l1dtlb_allocator_sva.a_same_4k_dual_miss_dedup` `RealSuccesses≥1`（baseline: 0）；`cp_l1dtlb_c004_same_vpn_dedup` `Matches≥1`（baseline: 0）；不触发既有 assertion failure。
  - **C3**: `l1dtlb_spec_sb` 校验 dedup 后 `$onehot(alloc_we)` 且只分配 1 个 mb entry（probe if 观测确认）；`translation_sb` 0 error。
  - **C4**: ≥3 个 seed 全部 PASS；同 VPN dedup 场景在 3 seed 上稳定触发 SVA。
  - **C5**: 归档 SVA RealSuccesses/Matches 数值证据、alloc_we onehot 观测、urg COND report、test list 条目。
- **DUT 质量原则**: 必须通过 scoreboard 验证 `alloc_we` 是 onehot 且只命中 1 个 entry。

### TASK L1DTLB-T05 — PTW refill ref_id 命中 entry 2..7（line 957 / 958 / 969）

- **覆盖目标**:
  - `mmu_l1dtlb.sv:957` `jtlb_dutlb_ref_cmplt && (jtlb_dutlb_ref_id == 3)` → 影响 10 个实例（entry 3..7 等）。
  - `mmu_l1dtlb.sv:958` `ptw_l1dtlb_ref_cmplt && (ptw_l1dtlb_ref_id == 2)` → 影响 12 个实例（entry 2..7）。
  - `mmu_l1dtlb.sv:969` `gen_mb_entries[3].is_jtlb_refill || is_ptw_refill` → entry 3 的 refill 合并表达式。
- **根因**: 与 T01 同源但更精细——即便 entry 被命中，refill 完成信号的 `ref_id` 字段也必须分别命中 entry 2..7。
- **激励设计**: 复用 T01 的 entry sweep vseq，在每次 install 后让对应 mb entry `WFC` 状态时，ptw/jtlb 完成信号带回 `ref_id = entry_idx`；通过 scoreboard 监控 `ptw_l1dtlb_ref_id` 字段是否被 DUT 路由正确。
- **UVM 修改文件**: 复用 T01 的 vseq，但新增 1 个 test wrapper `test_mmu_l1dtlb_cov_ref_id_sweep.svh`（隔离 seed 与参数便于回归单独追踪）。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb.sv:957` 的 entry 3..7 实例（影响 10 个）全部 Covered；`:958` 的 entry 2..7 实例（影响 12 个）全部 Covered；`:969` 的 `gen_mb_entries[3]` 实例 Covered；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 校验每个 ref_id 路由的 PA 正确（0 error）；probe if 观测 `ptw_l1dtlb_ref_id` / `jtlb_dutlb_ref_id` 字段在 entry 2..7 上分别命中至少 1 次。
  - **C4**: ≥3 个 seed 全部 PASS；entry 2..7 的 ref_id 命中在合并 vdb 上稳定 Covered。
  - **C5**: 归档 ref_id × entry 矩阵的命中证据、urg report、test list 条目。
- **DUT 质量原则**: `translation_sb` 验证每个 ref_id 路由的 PA 正确。

### TASK L1DTLB-T06 — miss-buffer entry FSM: STATE_WFI flush / ACFLT / default

- **覆盖目标**:
  - `mmu_l1dtlb_mb_entry.sv:200` `state_nxt = STATE_IDLE;`（WFI + abort_this_cyc）
  - `mmu_l1dtlb_mb_entry.sv:216` `state_nxt = STATE_IDLE;`（ACFLT + abort / expt_hit）
  - `mmu_l1dtlb_mb_entry.sv:228` `default: state_nxt = STATE_IDLE;`
  - `mmu_l1dtlb_mb_entry` COND: 行 120、134、144、150、257、283、288。
  - `mmu_l1dtlb_mb_entry_sva.a_idle_flush_blocks_alloc`、`a_wfi_data_stable_without_grant`、`a_wfi_flush_to_idle`（全部 Successes=0）。
- **根因**: 现有 `mb_fsm_wfi_001` / `wfi_data_hold_001` 覆盖了 WFI 的稳定路径，但没有覆盖"WFI 期间 flush → 回 IDLE"和"ACFLT 状态下 flush / expt_hit → IDLE"两条 abort 路径；default 分支从未进入（FSM 编码不会自然进入非法态，需要特殊手段）。
- **激励设计**:
  - 子场景 a: 在 WFI 状态（ refill 数据已准备好但 install 未授权）时发 `rtu_yy_xx_flush`；用 probe if 观测到 `state==WFI` 后下周期 `state==IDLE`；
  - 子场景 b: 让 mb entry 进入 STATE_ACFLT（需要先触发 access fault），再发 flush / 等 expt_hit；
  - 子场景 c（default）: 由于 default 分支不可由合法状态激励，本子项**不走 force**，而是评估该 default 分支是否应进 `exclude_v4.do`——由 design 团队签字确认后走 exclude（合规且符合"不刷表面数字"原则）。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 `mmu_l1dtlb_mb_fsm_abort_vseq`；
  - `coverage_tests/test_mmu_l1dtlb_cov_mb_fsm_abort.svh`；
  - 若 default 分支需要 exclude，新增 `simu/exclude_v4.do` 条目（需附 design sign-off 链接）。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb_mb_entry.sv:200` LINE `Hit≥1`（baseline: 0/N）；`:216` LINE `Hit≥1`；`:228` default 分支经合规 exclude（附 design sign-off）后该模块 BRANCH 覆盖率 = 100%；mb_entry COND 行 120 / 134 / 144 / 150 / 257 / 283 / 288 全部缺失组合 Covered；delta 新增 uncovered = 0。
  - **C2**: `mmu_l1dtlb_mb_entry_sva.a_idle_flush_blocks_alloc` / `a_wfi_data_stable_without_grant` / `a_wfi_flush_to_idle` 三者 `RealSuccesses≥1`（baseline: 全 0）；不触发既有 assertion failure。
  - **C3**: `l1dtlb_spec_sb` + `mmu_l1dtlb_mb_entry_sva` 报告 0 error；probe if 观测"WFI 状态下 flush → 下一周期 state==IDLE"及"ACFLT + flush/expt_hit → IDLE"各至少 1 次。
  - **C4**: ≥3 个 seed 全部 PASS；line 200/216 命中与 3 条 SVA 触发在合并 vdb 上稳定复现。
  - **C5**: 归档 mb_fsm_abort 单测 log、SVA RealSuccesses 证据、design sign-off 链接（针对 line 228 exclude）、urg LINE/BRANCH report、test list 条目。
- **DUT 质量原则**: default 分支只能走 exclude 路径；不允许通过 `force state_r=2'h?` 进入。

### TASK L1DTLB-T07 — exception CAM 边沿（expt_cam line 95/96/98/130/155）

- **覆盖目标**:
  - `mmu_l1dtlb_expt_cam.sv:95` `lsu_mmu_va1_vld && hit1_any && !lsu_mmu_abort1` 缺失 `1 1 0`；
  - `:96` `hit0_any && hit1_any && (hit0_idx == hit1_idx)` 缺失 `1 1 1`；
  - `:98` `consume1 && !same_hit_entry` 缺失 `1 0`；
  - `:130` `expt_wr0_vld && expt_wr1_vld && (expt_wr0_eid == expt_wr1_eid)` 缺失 `1 1 1`；
  - `:155` `expt_wr1_vld && !same_wr_eid` 缺失 `1 0`。
- **根因**: expt_cam 同时双端口命中相同/不同 entry 的边沿从未被构造；expt_wr0/wr1 同周期指向同 eid 的情况也未激励。
- **激励设计**: 新 vseq `mmu_l1dtlb_expt_cam_edge_vseq`:
  - 让 pipe0、pipe1 同时 miss → PTW 完成时同时返回 pgflt（形成 expt_wr0_vld && expt_wr1_vld），且 `ref_id` 相同 / 不同两套；
  - 让一个端口的 va1_vld 命中 expt_cam 但同周期 abort。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 vseq；
  - `coverage_tests/test_mmu_l1dtlb_cov_expt_cam_edge.svh`；
  - test_pkg.sv / test list 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb_expt_cam.sv:95` 组合 `1 1 0` Covered；`:96` 组合 `1 1 1` Covered；`:98` 组合 `1 0` Covered；`:130` 组合 `1 1 1` Covered；`:155` 组合 `1 0` Covered；`mmu_l1dtlb_expt_cam` COND 覆盖率 80.77% → 100%；delta 新增 uncovered = 0。
  - **C2**: 不触发 `mmu_l1dtlb_expt_cam_sva` 及既有 assertion failure。
  - **C3**: `l1dtlb_spec_sb` 校验双端口同周期 expt 写入的 onehot / same_eid 行为正确（0 error）；probe if 观测 `expt_wr0_vld && expt_wr1_vld && (expt_wr0_eid == expt_wr1_eid)` 至少 1 次。
  - **C4**: ≥3 个 seed 全部 PASS；5 条 COND 组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档双端口 expt 写入场景的 log、urg COND report、same_eid 观测证据、test list 条目。

### TASK L1DTLB-T08 — expt_entry_overlap_is_terminal_replay SVA + cover

- **覆盖目标**:
  - `mmu_l1dtlb_hit_rd_sva.a_expt_entry_overlap_is_terminal_replay`（Successes=0）；
  - `cp_l1dtlb_expt_entry_overlap_replay`（Matches=0）。
- **根因**: 触发条件 `lsu_mmu_va_vld_x && (|entry_hit_vec) && expt_match_x`：同一 VPN 在 dutlb 命中、同时 expt_cam 命中 replay。现有测试要么纯 hit、要么纯 expt。
- **激励设计**:
  - 让某 VPN 先 install 进 dutlb（hit_vec 置位）；
  - 之后让该 VPN 触发一次 access fault 写入 expt_cam；
  - 紧接着对同一 VPN 再发读 → 此时 `entry_hit_vec=1 && expt_match_x=1`，SVA 应触发。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 `mmu_l1dtlb_expt_overlap_replay_vseq`；
  - `coverage_tests/test_mmu_l1dtlb_cov_expt_overlap_replay.svh`。
- **验收标准（C1–C5）**:
  - **C1**: 本 TASK 主要闭合 SVA/cover，不直接针对 URG 行；delta 新增 uncovered = 0。
  - **C2**: `mmu_l1dtlb_hit_rd_sva.a_expt_entry_overlap_is_terminal_replay` `RealSuccesses≥1`（baseline: 0）；`cp_l1dtlb_expt_entry_overlap_replay` `Matches≥1`（baseline: 0）；不触发既有 assertion failure。
  - **C3**: `translation_sb` 验证最终 PA 来自 sysmap（fault 路径），不是 dutlb entry 的 PA（0 error）；probe if 观测 `entry_hit_vec != 0 && expt_match_x` 至少 1 周期，且该周期 `dutlb_miss_vld_x==0`。
  - **C4**: ≥3 个 seed 全部 PASS；overlap replay 场景在合并 vdb 上稳定命中 SVA。
  - **C5**: 归档 SVA RealSuccesses/Matches 证据、PA 来源对照观测、urg SVA report、test list 条目。

### TASK L1DTLB-T09 — hit_rd 权限/地址异常矩阵（hit_rd line 165/170/183/185/194/209/216 COND）

- **覆盖目标**: `mmu_l1dtlb_hit_rd.sv` 多个权限/异常表达式 term 组合，含 mxr/sum/supv/user/pmp/sysmap 的多 term 组合，以及 `lsu_mmu_va_x` 高位非法地址判定。
- **根因**: 与既有 `test_mmu_l1dtlb_dtlb_hit_rd_perm_mode_matrix_001` 同源但矩阵不全；`lsu_mmu_va_x[VPN_WIDTH+11]` 与 `lsu_mmu_va_x[63:(VPN_WIDTH+12)]` 符号扩展非法的边沿从未激励。
- **激励设计**: 扩展 `mmu_l1dtlb_vseq_lib.svh` 的 perm matrix，新增:
  - (a) supv 模式 + entry flg U=1/S=0 + SUM=0（应触发 fault）；
  - (b) user 模式 + entry flg U=0 + MXR=1/0 + READ 类型；
  - (c) VA 高位非法（`lsu_mmu_va_x[VPN_WIDTH+11]=0` 但高位有 1；或反之）；
  - (d) `pmp_flg_vld ^ lsu_mmu_va_vld_x` 的 XOR term。
- **UVM 修改文件**:
  - 扩展 `mmu_l1dtlb_vseq_lib.svh` 中的 `scenario_dtlb_hit_rd_perm_mode_matrix`；
  - 不新增 test wrapper，但新增 1 个 `test_mmu_l1dtlb_cov_hit_rd_perm_full.svh` 以独立 seed 跑扩展矩阵。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb_hit_rd.sv` 行 165 / 170 / 183 / 185 / 194 / 209 / 216 的所有缺失 term 组合 Covered（详见 review 报告中该模块 COND 表）；`mmu_l1dtlb_hit_rd` COND 覆盖率 78.66% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；hit_rd 相关 cover 若首次命中需归档。
  - **C3**: `translation_sb` 对每条 term 的预期 fault/hit 行为正确（0 error）；具体校验: supv+S=0+SUM=0 应 fault、user+U=0+MXR=0/1 read 应 fault/hit、VA 高位非法应 va_illegal。
  - **C4**: ≥3 个 seed 全部 PASS；perm 矩阵全部 term 组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 perm 矩阵 × 预期结果对照表、translation_sb 断言摘要、urg COND report、test list 条目。

### TASK L1DTLB-T10 — install 模块 COND（line 100/103）

- **覆盖目标**:
  - `mmu_l1dtlb_install.sv:100` `ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt && mb_entry_vld[id_ptw] && !req_ptw_expt && !req_ptw_aborted` 缺失 `1 1 0 1 1`、`1 1 1 0 1`。
  - `mmu_l1dtlb_install.sv:103` jtlb 路径同表达式缺失 `1 1 0 1 1`、`1 1 1 0 1`、`1 1 1 1 0`。
  - `mmu_l1dtlb_install_sva` 端口 toggle 缺口。
- **根因**: install 触发需要 `ref_pavld && ref_cmplt` 同周期、且 mb_entry_vld 对应位 = 1；现有测试很少同周期满足 pavld+cmplt。
- **激励设计**: 与 T03 联动但独立成项——专门构造 install 入口的 5 个 term 边沿，包括 `pavld=1 cmplt=1` 但 `mb_entry_vld=0`（PTW 完成对应 entry 已被 flush 释放）等。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 `mmu_l1dtlb_install_term_matrix_vseq`；
  - `coverage_tests/test_mmu_l1dtlb_cov_install_term_matrix.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb_install.sv:100` 缺失组合 `1 1 0 1 1` / `1 1 1 0 1` Covered；`:103` 缺失组合 `1 1 0 1 1` / `1 1 1 0 1` / `1 1 1 1 0` Covered；`mmu_l1dtlb_install` COND 覆盖率 79.41% → 100%；delta 新增 uncovered = 0。
  - **C2**: 不触发 `mmu_l1dtlb_install_sva` 及既有 assertion failure。
  - **C3**: `l1dtlb_spec_sb` 校验 install 触发条件 `ref_pavld && ref_cmplt && mb_entry_vld && !expt && !aborted` 与实际 install 行为一致（0 error）；probe if 观测每条 term 边沿（pavld+cmplt 但 mb_entry_vld=0 等）至少 1 次。
  - **C4**: ≥3 个 seed 全部 PASS；install term 组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 install term 矩阵 log、probe 观测、urg COND report、test list 条目。

### TASK L1DTLB-T11 — scheduler bypass term（line 214）

- **覆盖目标**: `mmu_l1dtlb_scheduler.sv:214` `bypass_req_vld && credit_avail && !mb_req_vld` 缺失 `1 0 1`、`1 1 0`。
- **根因**: bypass 路径要求 credit_avail=1 且无 mb_req_vld 才能直通；现有测试常满足全部 = 1。
- **激励设计**: 通过精确控制 credit_cnt（让 credit_avail=0）或在同周期发 mb_req，构造 2 种缺失组合。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh` 新增 `mmu_l1dtlb_sched_bypass_term_vseq`；
  - `coverage_tests/test_mmu_l1dtlb_cov_sched_bypass_term.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb_scheduler.sv:214` `bypass_req_vld && credit_avail && !mb_req_vld` 缺失组合 `1 0 1` / `1 1 0` Covered（baseline: Not Covered）；`mmu_l1dtlb_scheduler` COND 覆盖率 96.77% → 100%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `l1dtlb_spec_sb` 校验 credit_avail=0 时 bypass 被阻塞、mb_req_vld=1 时 bypass 被阻塞的行为正确（0 error）；probe if 观测 credit_cnt 与 bypass_grant 的时序关系。
  - **C4**: ≥3 个 seed 全部 PASS；2 种缺失组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 bypass term 场景 log、credit 观测、urg COND report、test list 条目。

### TASK L1DTLB-T12 — `cpurst_b` 1→0 mid-test reset（多 SVA 端口 toggle 共享根因）

- **覆盖目标**:
  - `mmu_l1dtlb`、`mmu_l1dtlb_sva`、`mmu_l1dtlb_allocator_sva`、`mmu_l1dtlb_install_sva`、`mmu_l1dtlb_scheduler_sva`、`mmu_l1dtlb_expt_cam_sva` 等模块的 `cpurst_b` 端口 Toggle `1->0=No`。
  - `cp_l1dtlb_c001_reset_then_miss` cover（Matches=0）。
- **根因**: 测试中从未触发真实复位下沿。
- **激励设计**: 复用 `test_mmu_l1dtlb_cov_reset_mid` 已有的 `mmu_l1_reset_mid_op_vseq`，但需要确认 mid-test reset 真的把 `cpurst_b` 拉低再拉高（硬件信号级别）；若是，则补一个 cover point 命中；若否，则在 `misc_agent` 增加 `misc_mid_reset_seq`（合法驱动 top-level reset）。
- **UVM 修改文件**:
  - `mmu_verification/testbench/misc_agent/` 若需要则新增 reset 序列；
  - `coverage_tests/test_mmu_l1dtlb_cov_mid_reset_assert.svh`；
  - test list 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb` / `mmu_l1dtlb_sva` / `mmu_l1dtlb_allocator_sva` / `mmu_l1dtlb_install_sva` / `mmu_l1dtlb_scheduler_sva` / `mmu_l1dtlb_expt_cam_sva` 等模块的 `cpurst_b` 端口 Toggle `1->0=Yes & 0->1=Yes`（baseline: 1->0=No）；delta 新增 uncovered = 0。
  - **C2**: `cp_l1dtlb_c001_reset_then_miss` `Matches≥1`（baseline: 0）；不触发既有 assertion failure。
  - **C3**: reset 期间 DUT 不得输出未知 PA（`translation_sb` 在 reset window 内无新 error）；reset 后 scoreboard 观测所有 mb entry / dutlb entry 清空（`vld==0`）；ref model 与 DUT 状态同步。
  - **C4**: ≥3 个 seed 全部 PASS；reset toggle 增量在合并 vdb 上稳定复现。
  - **C5**: 归档 mid-reset 波形/观测、cpurst_b toggle 证据、SVA Matches、test list 条目。
- **DUT 质量原则**: reset 期间 DUT 不得输出未知 PA；reset 后 scoreboard 必须看到所有 mb entry / dutlb entry 清空。

---

## 7. Phase C — L1ITLB 覆盖率 TASK

### TASK L1ITLB-T01 — iUTLB ref_cur_st WFG→IDLE / WFG→ABT FSM 迁移

- **覆盖目标**:
  - `mmu_l1itlb.sv:735` FSM 迁移 `WFG -> IDLE`（由 `ifu_mmu_abort && credit_cnt==0` 触发）。
  - `mmu_l1itlb.sv:753` FSM 迁移 `WFG -> ABT`（由 `ifu_mmu_abort && credit_cnt!=0` 触发）。
  - 对应 LINE 缺口 `mmu_l1itlb.sv:753/755/759/763`（多个 ref_nxt_st 赋值分支）。
  - `ref_cur_st` FSM 覆盖率从 77.78% 提升至 100%。
- **根因**: ifu_agent 在 WFG（等 PTW 授权）状态时没有专门发 `ifu_mmu_abort`；现有 `ifu_abort_seq` 只在 fetch 命中后发 abort。
- **激励设计**: 在 `ifu_agent` 中扩展 `ifu_abort_seq` 或新增 `ifu_wfg_abort_seq`:
  - 让 IFU 发出 fetch miss → DUT 进入 WFG（等 PTW grant）；
  - 在 WFG 期间（通过 probe if 观测）发 `ifu_mmu_abort=1`；分两套：`credit_cnt==0`（→ IDLE）与 `credit_cnt!=0`（→ ABT）。
- **UVM 修改文件**:
  - `mmu_verification/testbench/ifu_agent/ifu_sequences.svh` 新增 `ifu_wfg_abort_seq`；
  - `coverage_tests/test_mmu_l1itlb_cov_wfg_abort.svh`；
  - test list 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1itlb.sv:735` FSM 迁移 `WFG -> IDLE` Covered；`:753` FSM 迁移 `WFG -> ABT` Covered；LINE 753 / 755 / 759 / 763 `Hit≥1`（baseline: 0/N）；`mmu_l1itlb` FSM 覆盖率 77.78% → 100%、LINE 92.06% → ≥ 99%、BRANCH 87.50% → 100%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；`coherency_sb` 相关 cover 若首次命中需归档。
  - **C3**: `coherency_sb` / ITLB scoreboard 报告 0 error；probe if 观测 `ref_cur_st==WFG` 时 `ifu_mmu_abort=1` 分别配合 `credit_cnt==0`（→ IDLE）与 `credit_cnt!=0`（→ ABT）各至少 1 次。
  - **C4**: ≥3 个 seed 全部 PASS；两条 FSM 迁移在合并 vdb 上稳定 Covered。
  - **C5**: 归档 WFG abort 单测 log、FSM 迁移观测、urg FSM/LINE report、test list 条目。

### TASK L1ITLB-T02 — iUTLB perm / bypass / pmp 矩阵（line 520/551/566/727 COND）

- **覆盖目标**:
  - `mmu_l1itlb.sv:551` 多 term 权限表达式（7 种未覆盖组合）；
  - `:520` `iutlb_bypass_vld || hit || disable || acc_flt || ref_pgflt || va_illegal` 缺失 2 种组合；
  - `:566` pmp + mach_mode term；
  - `:727` ifu_mmu_va_vld && !addr_hit && !off_hit && !no_op_req term。
- **根因**: 既有 `ifu_exec_perm_mix_seq` / `ifu_pagefault_trigger_seq` 没有覆盖 supv/user × SUM/MXR × pmp_flg 的完整组合。
- **激励设计**: 扩展 `ifu_sequences.svh` 增加 `ifu_perm_full_matrix_seq`，在 cp0_agent 协同下循环 supv/user/mach 模式 × MXR/SUM × sysmap/pmp_flg 的合法/非法组合；每种组合 fetch 一次。
- **UVM 修改文件**:
  - `ifu_sequences.svh` 新增 perm matrix seq；
  - `coverage_tests/test_mmu_l1itlb_cov_perm_matrix.svh`；
  - test list 登记。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1itlb.sv:551` 7 种未覆盖 term 组合全部 Covered；`:520` 缺失 2 种组合 Covered；`:566` 缺失 `1 0 1` / `1 1 1` Covered；`:727` 缺失 `1 1 0 1` / `1 1 1 0` Covered；`mmu_l1itlb` COND 78.65% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 对 supv/user × MXR/SUM × pmp/sysmap_flg 每种组合的 fault/hit 预期正确（0 error）；具体: supv+U=1+SUM=0 应 fault、user+U=0+MXR=0 read 应 fault、mach+pmp_X=0 应 fault。
  - **C4**: ≥3 个 seed 全部 PASS；perm 矩阵在合并 vdb 上稳定 Covered。
  - **C5**: 归档 perm 矩阵 × 预期对照表、translation_sb 断言摘要、urg COND report、test list 条目。

### TASK L1ITLB-T03 — iUTLB entry 全量 install/hit/invalidate（参数化 TOGGLE 根因）

- **覆盖目标**: `mmu_l1itlb`、`ct_mmu_iutlb_entry`、`ct_mmu_iutlb_fst_entry` 中所有 `entryN_ppn[*]` / `entryN_vpn[*]` / `entry16_*` 参数化位段 toggle；`entry16_vpn[11]`、`entry0_ppn[11]`、`entry3_ppn[10]` 等。
- **根因**: ifu 现有 fetch 用少量 VA，未走完 16 iutlb entry。
- **激励设计**: 新 vseq `mmu_l1itlb_entry_sweep_vseq`，遍历 iutlb 16 entry，每 entry: fetch miss → 等 refill → 再 fetch hit → invalidate → 再 fetch miss。
- **UVM 修改文件**:
  - `mmu_l1dtlb_coverage_vseq.svh`（或新建 `mmu_l1itlb_coverage_vseq.svh`）新增 vseq；
  - `coverage_tests/test_mmu_l1itlb_cov_entry_sweep.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1itlb` / `ct_mmu_iutlb_entry` / `ct_mmu_iutlb_fst_entry` 中 `entryN_ppn[*]` / `entryN_vpn[*]` / `entry16_*` 参数化位段 toggle 双向 Yes；`mmu_l1itlb` TOGGLE 73.53% → ≥ 99%、`ct_mmu_iutlb_entry` 87.69% → ≥ 99%、`ct_mmu_iutlb_fst_entry` 86.40% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 校验每个 entry 的 fetch→refill→hit→inv→miss 流程 PA 正确（0 error）；probe if 观测 16 个 entry 的 vld/ppn/vpn 均被写过。
  - **C4**: ≥3 个 seed 全部 PASS；16 entry 遍历在合并 vdb 上稳定复现。
  - **C5**: 归档 entry sweep log、toggle diff、urg TOGGLE report、test list 条目。

### TASK L1ITLB-T04 — iUTLB 共享 `cpurst_b` 1→0 reset

- **覆盖目标**: `mmu_l1itlb`、`ct_mmu_iutlb_entry`、`ct_mmu_iutlb_fst_entry` 的 `cpurst_b` 端口 Toggle 1->0=No。
- **依赖**: 复用 L1DTLB-T12 的 mid-reset 能力。
- **激励设计**: 在 L1ITLB 测试中也启用 misc_mid_reset_seq，在 fetch 期间触发 reset。
- **UVM 修改文件**: 同 L1DTLB-T12；额外登记 `coverage_tests/test_mmu_l1itlb_cov_mid_reset.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1itlb` / `ct_mmu_iutlb_entry` / `ct_mmu_iutlb_fst_entry` 的 `cpurst_b` 端口 Toggle `1->0=Yes & 0->1=Yes`（baseline: 1->0=No）；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: reset 期间不产生未知 PA；reset 后所有 iutlb entry `vld==0`（probe if 观测）；`translation_sb` 0 error。
  - **C4**: ≥3 个 seed 全部 PASS；reset toggle 在合并 vdb 上稳定复现。
  - **C5**: 归档 mid-reset 观测、cpurst_b toggle 证据、test list 条目。

---

## 8. Phase D — L2TLB 覆盖率 TASK

### TASK L2TLB-T01 — PFU_DENY FSM 迁移 + LINE 1368/1382 + 相关 COND

- **覆盖目标**:
  - `mmu_l2tlb.sv:1368` LINE `pfu_nxt_st = PFU_DENY;`
  - `mmu_l2tlb.sv:1382` LINE default `pfu_nxt_st = PFU_IDLE;`
  - FSM `pfu_cur_st` 迁移 `PFU_CHK -> PFU_DENY`、`PFU_CHK -> PFU_IDLE`。
  - 分支 `:1354` case PFU_CHK / default。
  - 关联 COND `:1234` `cp0_mach_mode && !pmp_mmu_flg4[3]` 缺失 `1 0`。
- **根因**: 现有 `test_mmu_l2tlb_pfu_pmp_deny_chk` 已经引入 `mmu_l2tlb_pfu_chk_deny_vseq`，但 `l2tlb_pfu_deny` 的真实激励条件 `!pmp_mmu_flg4[0] && !(cp0_mach_mode && !pmp_mmu_flg4[3])` 没有被合法满足（即 PFU pipe2 的 PMP 检查必须拒绝）。
- **激励设计**:
  - 审计既有 `pmp_flg_deny_pfu_seq`：确认其设置 `pmp_mmu_flg4[0]=0`（L=0）+ `pmp_mmu_flg4[3]=0`（X=0）+ cp0 处于 supv/user（非 mach）。
  - 扩展 `mmu_l2tlb_pfu_chk_deny_vseq`:
    - 子场景 a: cp0_mach_mode=0、pmp_mmu_flg4[0]=0 → 应进入 PFU_DENY；
    - 子场景 b: cp0_mach_mode=1、pmp_mmu_flg4[3]=0 → mach 模式但无执行权限 → 仍 DENY（覆盖 COND `1 0`）；
    - 子场景 c: 让 PFU 回 IDLE 的正常路径（l2tlb_pfu_cmplt=0），覆盖 FSM PFU_CHK->PFU_IDLE（注：该迁移实际指 default 分支或回 IDLE 路径，需结合 RTL 确认）。
- **UVM 修改文件**:
  - `mmu_verification/testbench/env/mmu_l2tlb_directed_vseq.svh` 扩展；
  - `mmu_verification/testbench/pmp_agent/` 下扩展或新建 `pmp_flg_deny_pfu_mach_seq`；
  - `coverage_tests/test_mmu_l2tlb_cov_pfu_deny_fsm.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:1368` LINE `Hit≥1`（baseline: 0/N）；`:1382` LINE `Hit≥1`；`:1354` case 分支 PFU_CHK / default Covered；FSM `pfu_cur_st` 迁移 `PFU_CHK->PFU_DENY` 与 `PFU_CHK->PFU_IDLE` Covered；`:1234` COND 缺失 `1 0` Covered；`mmu_l2tlb` FSM 71.43% → 100%、LINE 99.43% → ≥ 99.5%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；若 `c_l2tlb_ptw_reselect_under_backpressure` 在本 TASK 命中也记录（否则由 T13 闭合）。
  - **C3**: `mmu_l2tlb_txn_shadow` / phase6c_l2_shadow 校验 PFU_DENY 后 DUT 对 pipe2 的响应为 fault/miss（0 error）；probe if 观测 `l2tlb_pfu_deny=1` 由 PMP 拒绝真实产生（pmp_mmu_flg4[0]=0），非 force。
  - **C4**: ≥3 个 seed 全部 PASS；PFU_DENY FSM 迁移在合并 vdb 上稳定 Covered。
  - **C5**: 归档 PFU deny 子场景 log、PMP 配置证据、urg LINE/FSM/COND report、test list 条目。
- **DUT 质量原则**: PFU_DENY 必须由 PMP 拒绝真实产生；不允许 force `l2tlb_pfu_deny=1`。

### TASK L2TLB-T02 — 5-way final_way_hit 表达式（line 814 / 816）

- **覆盖目标**:
  - `mmu_l2tlb.sv:814` `final_way_hit_kid0..4` 的多 way 命中表达式缺失组合 `1 1 0 1`、`1 0 1 1`、`0 1 1 1`（影响 11 个实例）。
  - SUB-EXPR `final_way_hit_kid3 & final_way_hit_kid4` 缺失 `1 0`。
  - `:816` `final_way_vld && !final_way_g && (final_way_asid == tlboper_l2tlb_inv_asid)` 缺失 `1 0 1`。
  - `:769` `raw_way_g || tlboper_l2tlb_cmp_noasid` 缺失 `1 0`。
- **根因**: L2TLB 是 8-way 结构；现有激励只命中 way0，导致其他 way 上的 `final_way_hit_kid3/4`、`raw_way_g`、ASID 命中比较从未翻转。
- **激励设计**: 新 vseq `mmu_l2tlb_multiway_install_hit_vseq`:
  - 通过 `arb_l2tlb_write` + `arb_l2tlb_tag_din`/`arb_l2tlb_data_din` 向 way 1..7 写不同 VPN + ASID + global 位；
  - 再发 lookup，使多个 way 同时命中或部分命中；
  - 配合 `tlboper_l2tlb_inv_asid` 触发 `final_way_asid_hit`。
- **UVM 修改文件**:
  - `mmu_l2tlb_directed_vseq.svh` 新增 vseq；
  - 需要扩展 `mmu_l2tlb_tlbop_decode.svh`（或对应 tlbop agent）以合法驱动 inv_asid；
  - `coverage_tests/test_mmu_l2tlb_cov_multiway_hit.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:814` 缺失组合 `1 1 0 1` / `1 0 1 1` / `0 1 1 1` Covered（影响 11 个实例）；SUB-EXPR `final_way_hit_kid3 & final_way_hit_kid4` 缺失 `1 0` Covered（影响 8 个）；`:816` 缺失 `1 0 1` Covered（影响 7 个）；`:769` 缺失 `1 0` Covered（影响 5 个）；`mmu_l2tlb` COND 90.67% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；多 way 命中相关 cover 若首次命中需归档。
  - **C3**: `mmu_l2tlb_txn_shadow` scoreboard 0 error；probe if 观测多 way 命中分布与 ASID/global 比较结果；`translation_sb` 校验 inv_asid 后对应 way 被正确 invalidate。
  - **C4**: ≥3 个 seed 全部 PASS；多 way 命中组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 multiway install/hit log、way 命中分布观测、urg COND report、test list 条目。

### TASK L2TLB-T03 — arb 写/安装类型（line 553/555/1041）

- **覆盖目标**:
  - `mmu_l2tlb.sv:553` `arb_l2tlb_req & (acc_type==3'b101) & arb_l2tlb_write` 缺失 `0 1 1`、`1 1 0`；
  - `:555` `arb_l2tlb_req & acc_type==3'b001 & write & tag_din[TAG_WIDTH-1]` 缺失 `0 1 1 1`；
  - `:1041` 同 `:553`。
- **根因**: arb 写接口（`rrpv_write_ptw/rrpv_write_tlboper`）的多种 acc_type + write 组合未激励。
- **激励设计**: 复用 T02 的 arb 写能力，专门构造:
  - `acc_type=3'b101 & write=0`（rrpv_write_ptw 条件不成立）；
  - `acc_type!=3'b101 & req=1 & write=1`（其他类型）；
  - `acc_type=3'b001 & write=1 & tag_din[msb]=1/0`。
- **UVM 修改文件**: 复用 T02 的 vseq；新建 `test_mmu_l2tlb_cov_arb_write_type.svh` 独立追踪。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:553` 缺失组合 `0 1 1` / `1 1 0` Covered（影响 2 个）；`:555` 缺失 `0 1 1 1` Covered；`:1041` 缺失 `0 1 1` / `1 1 0` Covered（影响 2 个）；`mmu_l2tlb` COND ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验 rrpv_write_ptw / rrpv_write_tlboper 的触发条件与 acc_type/write/tag_din 一致（0 error）；probe if 观测 `rrpv_write_en` 与各子使能的时序。
  - **C4**: ≥3 个 seed 全部 PASS；arb 写类型组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 arb 写类型矩阵 log、probe 观测、urg COND report、test list 条目。

### TASK L2TLB-T04 — final_tlb_hit_mult / final_tlb_miss / par_fail（line 869/870/872/1167）

- **覆盖目标**:
  - `:869` `final_hit_sum==1 & cmp_with_va & !par_fail` 缺失 `1 1 0`；
  - `:870` `cmp_with_va & !miss & !hit & !par_fail` 缺失 `1 1 1 0`（即 par_fail=1）；
  - `:872` `(vld & cmp_with_va & miss) | par_fail` 缺失 `0 1`（par_fail 单独触发）；
  - `:1167` `final_l1tlb_cmplt` 多 term 缺失 `1 1 0 1`。
- **根因**: parity fail 路径从未激励；多 way 命中（hit_mult）也未与 par_fail 组合。
- **激励设计**:
  - 通过 `l2tlb_negative_inject_if`（合法的负向注入接口，已用于 phase6e）注入 tag/data parity error；
  - 在多 way install 后再 lookup 同时注入 parity。
- **UVM 修改文件**:
  - 复用 `l2tlb_phase6e_test_base.phase6e_inject_ptw_negative`；
  - 新增 `mmu_l2tlb_par_fail_vseq`；
  - `coverage_tests/test_mmu_l2tlb_cov_par_fail.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:869` 缺失 `1 1 0` Covered；`:870` 缺失 `1 1 1 0` Covered；`:872` 缺失 `0 1` Covered；`:1167` 缺失 `1 1 0 1` Covered；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；`mmu_l2tlb_*_sva` 中 par_fail 相关 cover 若首次命中需归档。
  - **C3**: 负向 scoreboard（`l2tlb_negative_inject_if` 的 checker）验证 DUT 在 par_fail 时正确发出 miss / fault（0 error）；probe if 观测 `final_par_fail=1` 由注入产生且非 force。
  - **C4**: ≥3 个 seed 全部 PASS；par_fail 组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 par_fail 注入场景 log、checker 命中证据、urg COND report、test list 条目。

### TASK L2TLB-T05 — final_acc_type 路径（line 934/939/1186/1204/1418）

- **覆盖目标**:
  - `:934` `final_reqq_req` acc_type ∈ {010,110,011} 缺失 `1 0 1`；
  - `:939` `final_pfu_req` acc_type==100 缺失 `1 0 1`；
  - `:1186` l1itlb pgflt: `!ptw_en & l2tlb_miss & acc_type==011` 缺失 `0 1 1 1`；
  - `:1204` l1dtlb pgflt: acc_type[1:0]==10 缺失 2 组合；
  - `:1418` `l2tlb_pfu_acc_fault` 多 term 缺失组合。
- **根因**: acc_type 编码空间未遍历；cp0_mmu_ptw_en 的 0/1 切换与 acc_type 联合未系统覆盖。
- **激励设计**: 扩展 T02 vseq 的 acc_type 循环到全部 8 种编码，并配合 cp0_mmu_ptw_en=0/1 两套；对每种组合产生一次 L2TLB lookup。
- **UVM 修改文件**: 复用 T02 vseq；新建 `test_mmu_l2tlb_cov_acc_type_matrix.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:934` 缺失 `1 0 1` Covered；`:939` 缺失 `1 0 1` Covered；`:1186` 缺失 `0 1 1 1` Covered；`:1204` 缺失 `0 1 1 1` / `1 1 0 1` Covered；`:1418` 缺失 `0 0 1 0` Covered；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` + `translation_sb` 校验每种 acc_type 的下游响应（reqq_req / pfu_req / l1itlb_pgflt / l1dtlb_pgflt / pfu_acc_fault）正确（0 error）；probe if 观测 acc_type 与 cp0_mmu_ptw_en 的组合。
  - **C4**: ≥3 个 seed 全部 PASS；acc_type 矩阵在合并 vdb 上稳定 Covered。
  - **C5**: 归档 acc_type × ptw_en 矩阵 log、下游响应对照表、urg COND report、test list 条目。

### TASK L2TLB-T06 — PTW miss 与 mb_alloc（line 1005/1021/1031）

- **覆盖目标**:
  - `:1005` `mb_issue_req & cp0_mmu_ptw_en` 缺失 `1 0`；
  - `:1021` `final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid` 缺失 `1 0 1`；
  - `:1031` 同 `:1021`。
- **根因**: cp0_mmu_ptw_en=0 时 mb_issue_req 路径、或 ptw_en=1 但 mb_alloc_valid=0 的 retry 路径未激励。
- **激励设计**:
  - 子场景 a: cp0_mmu_ptw_en=0 时发 L2TLB miss → 验证不发 ptw_req；
  - 子场景 b: ptw_en=1 但 L2 mb 满 → mb_alloc_valid=0，reqq 应 retry。
- **UVM 修改文件**:
  - `mmu_l2tlb_directed_vseq.svh` 新增 `mmu_l2tlb_ptw_mb_alloc_vseq`；
  - `coverage_tests/test_mmu_l2tlb_cov_ptw_mb_alloc.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:1005` 缺失 `1 0` Covered；`:1021` 缺失 `1 0 1` Covered；`:1031` 缺失 `1 0 1` Covered；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure；若 `mmu_l2tlb_mb_sva.a_dtlb_full_no_overwrite` / `a_itlb_full_no_overwrite` 在本 TASK 命中也记录（完整闭合在 T08）。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验 ptw_en=0 时不发 ptw_req、mb 满时 reqq retry 的行为正确（0 error）；probe if 观测 `mb_alloc_valid` 与 `l2tlb_reqq_fb_miss_retry` 的时序。
  - **C4**: ≥3 个 seed 全部 PASS；ptw_mb_alloc 组合在合并 vdb 上稳定 Covered。
  - **C5**: 归档 ptw_en × mb_alloc 场景 log、retry 观测、urg COND report、test list 条目。

### TASK L2TLB-T07 — rrpv_wbuf 真满场景 + 3 条 SVA

- **覆盖目标**:
  - `mmu_l2tlb_rrpv_wbuf_sva.a_cam_hit_only_push_may_accept_when_full`（Successes=0）；
  - `a_true_full_blocks_new_entry_without_pop`（Successes=0）；
  - `c_rrpv_wbuf_true_full_block`（Matches=0）。
  - COND `mmu_l2tlb_rrpv_wbuf.sv:129` `(!push_new_entry) || (!fifo_full) || pop_do` 缺失 3 组合；
  - `:134` `count == DEPTH` 缺失 `1`。
- **根因**: rrpv_wbuf 深 FIFO 从未真正写满（`fifo_full` / `count==DEPTH`），所以真满 + CAM hit / 新 entry / pop 的组合都未发生。
- **激励设计**: 新 vseq `mmu_l2tlb_rrpv_wbuf_full_vseq`:
  - 连续 push 不重复的 rrpv 更新直到 `fifo_full`；
  - 在 full 时:
    - 子 a: push 一个 CAM 命中（应被 accept，不增加 count）；
    - 子 b: push 一个新 entry 且无 pop（应被 block，count 不变）；
    - 子 c: push 新 entry + 同周期 pop（应 accept，count 不变）。
- **UVM 修改文件**:
  - `mmu_l2tlb_directed_vseq.svh` 新增 vseq；
  - `coverage_tests/test_mmu_l2tlb_cov_rrpv_wbuf_full.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb_rrpv_wbuf.sv:129` 缺失 `0 0 0` / `0 0 1` / `1 0 0` Covered；`:134` 缺失 `1` Covered（即 `count==DEPTH` 命中）；`mmu_l2tlb_rrpv_wbuf` COND 76.19% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: `mmu_l2tlb_rrpv_wbuf_sva.a_cam_hit_only_push_may_accept_when_full` `RealSuccesses≥1`（baseline: 0）；`a_true_full_blocks_new_entry_without_pop` `RealSuccesses≥1`（baseline: 0）；`c_rrpv_wbuf_true_full_block` `Matches≥1`（baseline: 0）；不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_rrpv_exact_scoreboard` 校验真满时 CAM-hit accept / 新 entry block / pop+push count 不变的计数行为正确（0 error）；probe if 观测 `fifo_full==1 && count==DEPTH` 至少 1 周期。
  - **C4**: ≥3 个 seed 全部 PASS；rrpv_wbuf 真满场景在合并 vdb 上稳定命中 3 条 SVA。
  - **C5**: 归档 rrpv_wbuf 满场景 log、3 条 SVA 命中证据、count 观测、urg COND report、test list 条目。

### TASK L2TLB-T08 — L2 MB full 与 backpressure（mb_sva 3 条）

- **覆盖目标**:
  - `mmu_l2tlb_mb_sva.a_dtlb_full_no_overwrite`（Successes=0）；
  - `a_itlb_full_no_overwrite`（Successes=0）；
  - `c_mb_issue_reselect_under_backpressure`（Matches=0）。
  - COND `mmu_l2tlb_mb.sv:135`、`:215`、`:220`、`:227`（entry_rdy_vec | ffr_therm 组合）。
- **根因**: L2 mb 的 dtlb/itlb 分区从未真正写满；issue 在 PTW backpressure 下重新选择 entry 的场景也未构造。
- **激励设计**:
  - 子 a: 让 dtlb 分区（entry 1..TOTAL_DEPTH-1）全写满，再发 dtlb 请求，验证 alloc=0；
  - 子 b: 同样让 itlb 分区（entry 0）满；
  - 子 c: 让 issue_req=1 但 ptw_ready=0 持续 2 周期，并在第 2 周期让 ready entry 切换（reselect）。
- **UVM 修改文件**:
  - `mmu_l2tlb_directed_vseq.svh` 新增 `mmu_l2tlb_mb_full_backpressure_vseq`；
  - `coverage_tests/test_mmu_l2tlb_cov_mb_full_bp.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb_mb.sv:135` 缺失 `1 1 0` Covered；`:215` 缺失 `1 0`（entry_rdy_vec | ffr_therm，影响 5 个实例）Covered；`:220` 缺失 `1 1`（影响 5 个）Covered；`:227` 缺失 `0 1` Covered；`mmu_l2tlb_mb` COND 93.06% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: `mmu_l2tlb_mb_sva.a_dtlb_full_no_overwrite` `RealSuccesses≥1`（baseline: 0）；`a_itlb_full_no_overwrite` `RealSuccesses≥1`（baseline: 0）；`c_mb_issue_reselect_under_backpressure` `Matches≥1`（baseline: 0）；不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验 dtlb/itlb 分区满后 `req_alloc_valid==0 && alloc_en_vec==0`（0 error）；probe if 观测 `(&entry_vld_vec[dtlb_partition])` 真满状态及 issue reselect 时 `issue_eid` 变化。
  - **C4**: ≥3 个 seed 全部 PASS；mb full + backpressure 场景在合并 vdb 上稳定命中 3 条 SVA。
  - **C5**: 归档 mb full 场景 log、3 条 SVA 命中证据、alloc_en_vec 观测、urg COND report、test list 条目。

### TASK L2TLB-T09 — reqq credit / depth（line 203 COND + reqq_entry toggle）

- **覆盖目标**:
  - `mmu_l2tlb_reqq.sv:203` `fb_valid && (fb_trans_id == 4)` 缺失 `0 1`；
  - `mmu_l2tlb_reqq_entry` 多个 toggle（alloc_type / entry_out_* / fb_miss_retry）。
- **根因**: reqq 的 trans_id 字段从未达到 4（depth-1），且 feedback retry 路径未激励。
- **激励设计**: 复用 `test_mmu_l2tlb_reqq_depth_matrix_001`，扩展到让所有 trans_id 0..7 都出现一次 feedback；并构造一次 fb_miss_retry=1。
- **UVM 修改文件**:
  - 扩展既有 `mmu_l2tlb_*` vseq（在 `mmu_l2tlb_directed_vseq.svh`）；
  - `coverage_tests/test_mmu_l2tlb_cov_reqq_full_depth.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb_reqq.sv:203` 缺失 `0 1` Covered（影响 4 个）；`mmu_l2tlb_reqq` TOGGLE 91.32% → ≥ 99%、`mmu_l2tlb_reqq_entry` TOGGLE 74.67% → ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验所有 trans_id 0..7 的 feedback 路由与 fb_miss_retry 的重发行为正确（0 error）；probe if 观测 `fb_trans_id` 取到 4 及 `fb_miss_retry=1` 至少 1 次。
  - **C4**: ≥3 个 seed 全部 PASS；trans_id 全值域与 retry 在合并 vdb 上稳定复现。
  - **C5**: 归档 reqq depth 矩阵 log、retry 观测、urg COND/TOGGLE report、test list 条目。

### TASK L2TLB-T10 — reqq_entry / mb_entry 位段 toggle

- **覆盖目标**: `mmu_l2tlb_reqq_entry`、`mmu_l2tlb_mb_entry`、`mmu_l2tlb_mb` 中 `gen_entries[N].local_*`、`entry_out_asid/type/iid` 等位段 toggle。
- **根因**: entry index 未遍历 + ASID/type 字段未走全值域。
- **激励设计**: 通过扩展 T02 / T08 的 vseq，让所有 mb entry index 都被分配/释放；ASID 在 cp0_agent 中遍历 0..0xFFFF 合法子集。
- **UVM 修改文件**: 复用既有 vseq；新建 `test_mmu_l2tlb_cov_entry_field_sweep.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb_reqq_entry` / `mmu_l2tlb_mb_entry` / `mmu_l2tlb_mb` 中 `gen_entries[N].local_*` / `entry_out_asid/type/iid` / `alloc_type` 等位段 toggle 双向 Yes；上述 3 模块 TOGGLE 均达 ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验各 entry index 的 alloc/dealloc 与字段值正确（0 error）；ASID/type 字段全值域遍历不产生非法 PA。
  - **C4**: ≥3 个 seed 全部 PASS；entry 字段遍历在合并 vdb 上稳定复现。
  - **C5**: 归档 entry field sweep log、toggle diff、urg TOGGLE report、test list 条目。

### TASK L2TLB-T11 — l2tlb 共享 `cpurst_b` reset

- **覆盖目标**: `mmu_l2tlb`、`mmu_l2tlb_reqq`、`mmu_l2tlb_reqq_entry` 等的 `cpurst_b` Toggle 1->0=No。
- **依赖**: 复用 L1DTLB-T12 的 misc_mid_reset_seq。
- **UVM 修改文件**: `coverage_tests/test_mmu_l2tlb_cov_mid_reset.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb` / `mmu_l2tlb_reqq` / `mmu_l2tlb_reqq_entry` 等模块的 `cpurst_b` 端口 Toggle `1->0=Yes & 0->1=Yes`（baseline: 1->0=No）；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: reset 期间不产生未知 PA；reset 后 L2TLB 各 mb entry / reqq entry / tag-data array 状态清空（probe if 观测）；`mmu_l2tlb_txn_shadow` 0 error。
  - **C4**: ≥3 个 seed 全部 PASS；reset toggle 在合并 vdb 上稳定复现。
  - **C5**: 归档 mid-reset 观测、cpurst_b toggle 证据、test list 条目。

### TASK L2TLB-T12 — final_hit_flg / sysmap_mmu_flg4 / ptw_l2tlb_ref_flg 权限异常矩阵（line 1409/1418 COND）

- **覆盖目标**:
  - `:1409` `l2tlb_pfu_flag_fault` 表达式 4 种未覆盖组合（含 sum/mxr/supv/user 与 final_hit_flg 多 term）；
  - `:1418` `l2tlb_pfu_acc_fault` 相关 term；
  - `sysmap_mmu_flg4` / `ptw_l2tlb_ref_flg` 相关 SUB-EXPR 多组合。
- **根因**: 与 L1DTLB hit_rd 权限矩阵同源；cp0 的 sum/mxr/supv/user 与 final_hit_flg/D/R/W/X/U 位的组合未遍历。
- **激励设计**: 在 L2TLB install 后，用 cp0_agent 切换 priv/mxr/sum，并配合 sysmap_mmu_flg4 / pmp_mmu_flg4 的合法 R/W/X 组合，遍历 line 1409 表达式全部 term。
- **UVM 修改文件**:
  - `mmu_l2tlb_directed_vseq.svh` 新增 `mmu_l2tlb_perm_matrix_vseq`；
  - `coverage_tests/test_mmu_l2tlb_cov_perm_matrix.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.sv:1409` 缺失 4 种组合（含 `0 0 0 0 0 1 0` / `0 0 1 0 0 0 0` / `0 1 0 0 0 0 0` 等）Covered；`:1418` 缺失 `0 0 1 0` 及 SUB-EXPR `sysmap_mmu_flg4` / `ptw_l2tlb_ref_flg` 的缺失组合 Covered；`mmu_l2tlb` COND ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 对 supv/user × MXR/SUM × final_hit_flg(D/R/W/X/U) 每种组合的 pfu_flag_fault / pfu_acc_fault 预期正确（0 error）；probe if 观测 `l2tlb_pfu_flag_fault` / `l2tlb_pfu_acc_fault` 的产生条件。
  - **C4**: ≥3 个 seed 全部 PASS；权限矩阵在合并 vdb 上稳定 Covered。
  - **C5**: 归档 perm 矩阵 × 预期对照表、translation_sb 断言摘要、urg COND report、test list 条目。

### TASK L2TLB-T13 — maee / twu 相关 SVA（`c_l2tlb_ptw_reselect_under_backpressure`）

- **覆盖目标**: `mmu_l2tlb_rrpv_sva.c_l2tlb_ptw_reselect_under_backpressure`（Matches=0）。
- **根因**: PTW 在 backpressure 下对 rrpv 重新选择的场景未构造。
- **激励设计**: 与 T08 子 c 类似但聚焦 rrpv 路径；让 ptw 拒绝首次 rrpv 写入，DUT 应在同周期选择另一 way/entry。
- **UVM 修改文件**: 复用 T07/T08 vseq；新建 `test_mmu_l2tlb_cov_ptw_reselect.svh`。
- **验收标准（C1–C5）**:
  - **C1**: 本 TASK 主要闭合 cover point，不直接针对 URG 行；delta 新增 uncovered = 0。
  - **C2**: `mmu_l2tlb_rrpv_sva.c_l2tlb_ptw_reselect_under_backpressure` `Matches≥1`（baseline: 0，attempts=206452807）；不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_rrpv_exact_scoreboard` 校验 PTW backpressure 下 rrpv 重选后 victim/way 选择正确（0 error）；probe if 观测 `issue_eid != $past(issue_eid)` 且 `!ptw_ready` 持续 2 周期。
  - **C4**: ≥3 个 seed 全部 PASS；reselect 场景在合并 vdb 上稳定 Matches≥1。
  - **C5**: 归档 reselect 场景 log、cover Matches 证据、probe 观测、test list 条目。

---

## 9. Phase E — 全局 TOGGLE 收敛（参数化位段 / 高位 PPN / VPN / FLG / ASID）

> 本阶段依赖 Phase B/C/D 的 vseq 能力。本阶段每一项仍然按"一个根因 = 一个 TASK"推进，但根因均属于"位段未走完 0/1 翻转"。

### TASK E-L1-01 — L1DTLB entry PPN/FLG/VPN 高位 bit 翻转

- **覆盖目标**: `mmu_l1dtlb` 中 `entry_ppn[0][27:24]`、`entry_ppn[1..3][20:18]`、`entry_flg[1..3][*:0]`、`mb_entry_vpn[*][11]` 等位段 toggle；`mmu_l1dtlb_hit_rd.entry_ppn_vec[135..447]` 等大位段。
- **根因**: PTW refill 时返回的 PPN 高位总是相同（用例页表只用低地址）；entry_flg 的 D/A/U/X 位也非全值遍历。
- **激励设计**:
  - 在 `mmu_page_table_mem` 中为 bringup 页表配置多种 PPN 高位值（合法物理地址范围内），使 refill 时 `ptw_l1tlb_ref_ppn[27:24]`、`jtlb_utlb_ref_ppn[27:24]` 翻转；
  - 让 PTE 的 flg 字段在多次 refill 中遍历 D/A/U/X/R/W/V/G 全组合（合法 page table 内容）。
- **UVM 修改文件**:
  - `mmu_verification/testbench/env/mmu_page_table_mem.svh` 扩展 PPN/flg 配置；
  - `coverage_tests/test_mmu_l1dtlb_cov_pte_value_sweep.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l1dtlb` 中 `entry_ppn[0][27:24]` / `entry_ppn[1..3][20:18]` / `entry_flg[1..3][...]` / `mb_entry_vpn[*][11]` / `l1dtlb_ent_ppn[0][27:24]` 等位段 Toggle `0->1=Yes & 1->0=Yes`；`mmu_l1dtlb_hit_rd.entry_ppn_vec[135..447]` 等大位段双向 Yes；`mmu_l1dtlb` / `mmu_l1dtlb_hit_rd` / `mmu_l1dtlb_sva` TOGGLE 均达 ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 校验高位 PPN 的物理地址合法、PTE flg 全组合下 fault/hit 预期正确（0 error）；`mmu_page_table_mem` 配置的高位 PPN 不触发 PA 范围 SVA。
  - **C4**: ≥3 个 seed 全部 PASS；高位 bit 翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 PTE value sweep log、toggle diff、page table 配置说明、urg TOGGLE report、test list 条目。

### TASK E-L1-02 — L1ITLB entry PPN/VPN 高位 bit 翻转

- **覆盖目标**: `mmu_l1itlb` 的 `entry0_ppn[11]` / `entry16_ppn[13]` / `entry3_ppn[10]` / `entry4_ppn[13]` / `entry6_ppn[11]` / `entry16_vpn[11]` 等参数化位段。
- **根因**: 同 E-L1-01；iutlb entry 的高位 PPN/VPN bit 因 fetch VA 与 page table 配置不够分散而从未翻转。
- **激励设计**: 与 E-L1-01 协同，在 `mmu_page_table_mem` 中为 iutlb 路径配置高位 PPN；ifu fetch VA 高位也走翻转（覆盖 `entry*_vpn[11]`）。
- **UVM 修改文件**:
  - `mmu_page_table_mem.svh` 扩展（与 E-L1-01 共享）；
  - `coverage_tests/test_mmu_l1itlb_cov_pte_value_sweep.svh`。
- **验收标准（C1–C5）**:
  - **C1**: 上述 `entry*_ppn/vpn` 位段 Toggle `0->1=Yes & 1->0=Yes`；`mmu_l1itlb` TOGGLE ≥ 99%（与 L1ITLB-T03 协同，本 TASK 聚焦高位 bit）；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 校验 iutlb entry PPN/VPN 高位 fetch 后 PA 正确（0 error）；高位 VA 不触发 va_illegal 误判。
  - **C4**: ≥3 个 seed 全部 PASS；高位 bit 翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 iutlb PTE sweep log、toggle diff、urg TOGGLE report、test list 条目。

### TASK E-L2-01 — L2TLB tag/data SRAM 位段翻转

- **覆盖目标**: `ct_mmu_l2tlb_tag_array.l2tlb_tag_dout[0]`（25 个位段）、`ct_mmu_l2tlb_data_array.l2tlb_data_dout[130]`（10 个位段）、`mmu_l2tlb.l2tlb_tag_dout_bus[*]` / `l2tlb_data_dout_bus[*]`。
- **根因**: 写入 tag/data array 的数据未遍历位段；尤其 way0 的 bit0 与 data array 的 bit130 从未翻转。
- **激励设计**: 通过 T02 multiway vseq 在写 tag/data 时，刻意遍历每 way 的关键字段 bit（VPN 高位、PPN 高位、flg、ASID 全位）。
- **UVM 修改文件**: 复用 T02 vseq；新建 `test_mmu_l2tlb_cov_sram_bit_sweep.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `ct_mmu_l2tlb_tag_array.l2tlb_tag_dout[0]`（25 个位段）全部双向 Yes；`ct_mmu_l2tlb_data_array.l2tlb_data_dout[130]`（10 个位段）全部双向 Yes；`mmu_l2tlb.l2tlb_tag_dout_bus[*]` / `l2tlb_data_dout_bus[*]` 全部目标位段双向 Yes；`ct_mmu_l2tlb_tag_array` TOGGLE 90.21% → ≥ 99%、`ct_mmu_l2tlb_data_array` 91.47% → ≥ 99%、`mmu_l2tlb` TOGGLE 提升；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验 SRAM 写入/读出数据一致（0 error）；probe if 观测 tag/data array 各 way 各 bit 被写过并读出。
  - **C4**: ≥3 个 seed 全部 PASS；SRAM 位段翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 SRAM bit sweep log、toggle diff、urg TOGGLE report、test list 条目。

### TASK E-L2-02 — L2TLB PPN/PA 高位 bit 翻转

- **覆盖目标**: `mmu_l2tlb` 的 `l2tlb_l1tlb_ref_ppn[27:24]`、`l2tlb_tlbr_ppn[27:24]`、`mmu_lsu_pa2[27:20]`、`mmu_pmp_pa4[27:20]`、`mmu_sysmap_pa4[27:20]`、`ptw_l2tlb_ref_ppn[23:21]`、`ptw_l2tlb_ref_vpn[26]` 等。
- **根因**: 同 E-L1-01；L2TLB 看到的高位 PA/PPN 不够分散。
- **激励设计**: 与 E-L1-01 联动，让 page table 的 PPN 高位真正走 0/1 翻转；同时让 lookup 的 VA 高位也走翻转（覆盖 `ptw_l2tlb_ref_vpn[26]`）。
- **UVM 修改文件**: 复用 E-L1-01 page table 扩展；新建 `test_mmu_l2tlb_cov_pa_high_bits.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb` 中 `l2tlb_l1tlb_ref_ppn[27:24]` / `l2tlb_tlbr_ppn[27:24]` / `mmu_lsu_pa2[27:20]` / `mmu_pmp_pa4[27:20]` / `mmu_sysmap_pa4[27:20]` / `ptw_l2tlb_ref_ppn[23:21]` / `ptw_l2tlb_ref_vpn[26]` 等位段 Toggle 双向 Yes；`mmu_l2tlb` TOGGLE ≥ 99%；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` 校验高位 PA 在 pmp/sysmap 合法范围内（0 error）；高位 PPN 不触发 PA 范围 SVA。
  - **C4**: ≥3 个 seed 全部 PASS；高位 PA/PPN 翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 PA high bits sweep log、toggle diff、pmp/sysmap 配置说明、urg TOGGLE report、test list 条目。

### TASK E-L2-03 — L2TLB ASID / regs_l2tlb_cur_asid 高位翻转

- **覆盖目标**: `mmu_l2tlb.regs_l2tlb_cur_asid[15:5]`、`l2tlb_tlbr_asid[14]`、`final_way_asid[*][0]` 等 ASID 位段。
- **根因**: cp0_agent 设置的 ASID 总是用低 5 位；高位 ASID 从未使用。
- **激励设计**: cp0_agent 增加 `cp0_asid_high_bits_seq`，在合法 ASID 空间内随机 / 步进覆盖 bit5..15。
- **UVM 修改文件**:
  - `mmu_verification/testbench/cp0_agent/` 扩展序列；
  - `coverage_tests/test_mmu_l2tlb_cov_asid_sweep.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb.regs_l2tlb_cur_asid[15:5]` / `l2tlb_tlbr_asid[14]` / `final_way_asid[*][0]` / `raw_way_asid[*]` 高位 ASID 位段 Toggle 双向 Yes；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验高 ASID 值下 entry 命中/invalidate 行为正确（0 error）；`translation_sb` 校验 ASID 切换后 hit/miss 预期正确。
  - **C4**: ≥3 个 seed 全部 PASS；ASID 高位翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 ASID sweep log、toggle diff、cp0 asid 配置说明、urg TOGGLE report、test list 条目。

### TASK E-L2-04 — L2TLB `raw_tag`/`final_tag`/`raw_way_g` 等 way 级信号翻转

- **覆盖目标**: `raw_tag[18]`、`final_tag[*]`、`raw_way_g[0..7]`、`final_way_g[0..7]`、`raw_way_*` 等。
- **根因**: 与 T02 多 way 写入同根因，但聚焦信号 toggle 而非 COND。
- **激励设计**: 复用 T02；补 1 个 test wrapper 专门追踪这些信号 toggle。
- **验收标准（C1–C5）**:
  - **C1**: `mmu_l2tlb` 中 `raw_tag[18]` / `final_tag[*]` / `raw_way_g[0..7]` / `final_way_g[0..7]` / `raw_way_*` 等信号 Toggle 双向 Yes；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `mmu_l2tlb_txn_shadow` 校验多 way 写入后 tag/g 位字段一致（0 error）。
  - **C4**: ≥3 个 seed 全部 PASS；way 级信号翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 way-level signal toggle log、toggle diff、urg TOGGLE report、test list 条目。

### TASK E-L2-05 — L2TLB 杂项端口 toggle（cp0_mmu_mpp、pad_yy_icg_scan_en、tlboper_xx_pgs 等）

- **覆盖目标**: `cp0_mmu_mpp[0]`、`pad_yy_icg_scan_en`、`tlboper_xx_pgs[2:1]`、`biu_mmu_smp_disable`、`hpcp_mmu_cnt_en` 等。
- **根因**: 这些 cp0 / 配置输入在测试中固定值，未做翻转。
- **激励设计**: 在 misc_agent / cp0_agent 增加合法的配置翻转序列（如 cp0_mmu_mpp 在 U/S/M 间切；pad_yy_icg_scan_en 在测试末尾切 0/1；tlboper_xx_pgs 在 4K/2M/1G 间循环）。
- **UVM 修改文件**:
  - misc_agent / cp0_agent / tlbop agent 序列；
  - `coverage_tests/test_mmu_l*_cov_cfg_toggle.svh`。
- **验收标准（C1–C5）**:
  - **C1**: `cp0_mmu_mpp[0]` / `pad_yy_icg_scan_en` / `tlboper_xx_pgs[2:1]` / `biu_mmu_smp_disable` / `hpcp_mmu_cnt_en` 等端口 Toggle 双向 Yes；delta 新增 uncovered = 0。
  - **C2**: 不触发既有 assertion failure。
  - **C3**: `translation_sb` + `mmu_l2tlb_txn_shadow` 校验配置翻转期间 DUT 功能不受影响（0 error）；具体: `pad_yy_icg_scan_en` 翻转不产生错误 PA、`cp0_mmu_mpp` 切换后 priv 模式正确、`tlboper_xx_pgs` 切换后 page size 比较正确。
  - **C4**: ≥3 个 seed 全部 PASS；配置端口翻转在合并 vdb 上稳定复现。
  - **C5**: 归档 cfg toggle log、toggle diff、配置翻转时序说明、urg TOGGLE report、test list 条目。

---

## 10. 回归、覆盖率合并与 sign-off 流程

1. **test list 文件**: 所有新测试统一登记到 `mmu_verification/simu/phase15_l1_l2_cov_closure_list`，并按 Phase A/B/C/D/E 分段注释。
2. **每项 TASK 单项回归**: TASK 合入前，至少用 3 个 seed 跑该测试，确认 UVM 通过 + 目标 SVA / 行覆盖命中。
3. **覆盖率合并**: 每完成 5 个 TASK 跑一次 `mmu_v4_coverage_merge.sh`，合并到 `phase15_merged.vdb`，再 `urg -full64 -dir ... -report phase15_urgReport`。
4. **回归 checker**: 扩展 `scripts/l1dtlb_phase6g_closure.py` / `l2tlb_phase6g_closure.py`（或新建 `scripts/phase15_tlb_closure.py`）校验:
   - 每个 TASK 对应的 SVA RealSuccesses/Matches ≥ 1；
   - 每个 TASK 名义闭合的 URG 行 / 信号 Hit ≥ 1；
   - 测试日志不含 `UVM_ERROR` / `UVM_FATAL` / `ASSERT FAIL`。
5. **sign-off 门**:
   - 所有相关模块 LINE/COND/BRANCH/FSM/ASSERT ≥ 99%；
   - TOGGLE ≥ 99%（除设计签字 exclude 的位段，如物理不可达的 scan-only 端口）；
   - 新增 exclude 必须附 design 团队 sign-off 链接；
   - 全部 checker 通过。

---

## 11. 风险与降级策略

| 风险 | 描述 | 降级策略 |
| --- | --- | --- |
| 部分 COND 组合在合法激励下不可达 | 如 `default` 分支或某些 X-only 路径 | 由 design 团队签字后走 `exclude_v4.do`，必须附说明；不允许默默 exclude |
| 高位 PPN 翻转触发新 SVA 失败 | page table 配置高位 PPN 可能触发 PA 范围检查 SVA | 调整 sysmap/pmp 配置使高位 PA 合法；不允许关 SVA |
| JTLB refill 路径激励与 PTW agent 实现冲突 | ptw_mem_agent 可能没有 jtlb response 能力 | 优先扩展 agent 而非绕过 scoreboard；必要时与 IP owner 对齐接口语义 |
| rrpv_wbuf 满 + CAM 命中时序窗口窄 | 难以稳定命中 `a_cam_hit_only_push_may_accept_when_full` | 用 `+plusarg` 控制重试次数；通过 probe if 同步 push 时机；不允许 force 内部 FIFO |
| reset mid-test 导致 scoreboard 残留状态 | reset 后 ref model 与 DUT 状态不同步 | reset 序列必须发 scoreboard 的 `reset_state()` 同步钩子；不允许跳过检查 |
| 部分 TASK 的激励合法性需要 design 确认 | 如 cp0_mmu_mpp 在 reset 中途切换 | 在 TASK 描述中标注"需 design 确认"，未确认前不合入 |

---

## 12. TASK 顺序总览（执行 checklist）

> 一项完成并合入后才能开始下一项；同 Phase 内 ID 小的优先。

- [x] **Phase A**: A0 — commit pending: `mmu_l1_l2_tlb_common_vseq.svh` (mmu_l1_tlb_common_vseq, mmu_l2tlb_common_vseq) + env_pkg include; VCS compile clean (0 err / 18 warn).
- [~] **Phase B (L1DTLB)**: T01 (PARTIAL — see evidence below) → T02 → T03 → T04 → T05 → T06 → T07 → T08 → T09 → T10 → T11 → T12
- [ ] **Phase C (L1ITLB)**: T01 → T02 → T03 → T04
- [ ] **Phase D (L2TLB)**: T01 → T02 → T03 → T04 → T05 → T06 → T07 → T08 → T09 → T10 → T11 → T12 → T13
- [ ] **Phase E**: E-L1-01 → E-L1-02 → E-L2-01 → E-L2-02 → E-L2-03 → E-L2-04 → E-L2-05

### TASK A0 — Evidence
- Files: `testbench/env/mmu_l1_l2_tlb_common_vseq.svh` (new), `testbench/env/mmu_env_pkg.sv` (include added).
- Compile: `make comp` clean (VCS V-2023.12-SP2, 0 errors, 18 warnings, all pre-existing).
- The two new base classes (`mmu_l1_tlb_common_vseq`, `mmu_l2tlb_common_vseq`) provide reusable atomic tasks (`drive_lsu_miss_to_entry`, `drive_ifu_fetch_to_itlb_entry`, `assert_rtu_flush_at_vpn`, `assert_mid_test_reset`, `drive_l2tlb_write_with_type`, `drive_multiway_hit`, `drive_pfu_pipe2_with_pmp_deny`) — to be consumed by later Phase B/C/D/E TASKs.
- Pre-existing compile bug fixed in passing: `testbench/test/ptw_tests/test_ptw_l2pde_cache_cond_toggle_cov.svh` had several single-arg `pulse_bit(...)` callsites; restored the missing `ctx` argument.

### TASK L1DTLB-T01 — PARTIAL Evidence (not yet signed off)
- Files: `testbench/env/mmu_l1dtlb_coverage_vseq.svh` (new vseq `mmu_l1dtlb_entry_sweep_vseq`), `testbench/test/l1dtlb_tests/test_mmu_l1dtlb_cov_entry_sweep.svh` (new test wrapper), `testbench/test/l1dtlb_tests/l1dtlb_tests_suite.svh` (include added), `testbench/test/phase9_common/phase9_generated_test_base.svh` (vseq name registered).
- Pre-existing bug fixed: `test_mmu_l1dtlb_cov_hit_sweep.svh` and `test_mmu_l1dtlb_cov_mb_expt.svh` test wrappers never pushed their vseq name to `m_vseq_names`, so the vseq actually never ran; restored the push so both wrappers now run their intended vseq.
- Single-test PASS: `make run_cov TEST_NAME=test_mmu_l1dtlb_cov_entry_sweep SEED=97101` exits 0, UVM_ERROR=0, UVM_FATAL=0.
- URG single-test SVA hit counts for `a_va8_inv_clears_matching_entry[N]`: entry[0] hit=8.
- Baseline phase14 already covers entry[0] (40) and entry[1] (20).  This vseq alone has not yet added NEW entry coverage (still investigating why the DTLB PLRU only fills entry[0] under the bulk-install cadence — likely an L2TLB-set pressure effect since all 16 sweep VPNs map to the same L2TLB set).
- **STATUS: PARTIAL — needs more investigation to cover entries 2..15 before signing off.**

每项完成后更新本文档对应 checkbox，并附: PR/commit hash、urg report 路径、SVA 命中证据、scoreboard 报告路径。

---

## 附录 A — 不允许的反模式（明令禁止）

1. ❌ 在 testbench 中 `force tb_top.u_dut.x_mmu_l2tlb.l2tlb_pfu_deny = 1'b1;` 以闭合 PFU_DENY 覆盖率。
2. ❌ 通过 hierarchical reference 直接写 SRAM（`initial l2tlb_tag_array.mem[...] = ...`）以闭合 TOGGLE。
3. ❌ 向 `exclude_v4.tgl` / `exclude_v4.do` 中加入可达代码以提升数字。
4. ❌ 关闭既有 SVA（`-suppress` / `+noasserts`）以避免新增激励触发既有检查。
5. ❌ 在 scoreboard / ref model 中放宽比较以让错误响应通过。
6. ❌ 用一个 vseq 同时闭合多个不相关根因（如把 PFU deny 与 rrpv_wbuf 满塞进同一个 vseq），违反"一次一项"。
7. ❌ 用 backdoor load 直接写 dutlb entry 以闭合 entry 8..15 的 toggle（必须经合法 PTW/JTLB refill 路径）。

## 附录 B — 允许且鼓励的模式

1. ✅ 扩展既有 directed vseq、复用 scoreboard 与 SVA。
2. ✅ 通过合法 agent（cp0/pmp/sysmap/ifu/lsu/ptw_mem/misc/tlbop）产生激励。
3. ✅ 利用 `mmu_dut_probes_if` 只读观测 DUT 内部状态以决定激励时机（read-only probe，不写）。
4. ✅ 引入新的 cover property / covergroup（在 SVA testbench 中）以更精细地度量功能行为。
5. ✅ 与 design 团队协同，对真正不可达代码走合规 exclude 流程。
6. ✅ 把每个 TASK 的 evidence（log + urg + SVA 报告）归档到 `doc/l1tlb_uvm_review/evidence/<TASK_ID>/` 或 `doc/l2tlb_uvm_review/evidence/<TASK_ID>/`。
