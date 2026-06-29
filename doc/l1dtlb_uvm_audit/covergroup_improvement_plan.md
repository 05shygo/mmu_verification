# L1DTLB / L2TLB Covergroup 分阶段完善计划

> 依据：`covergroup_gap_analysis.md`
> 目标：`mmu_env_cg_whitebox.svh`，只追加不修改现有代码
> 关键约束：`cg_l1dtlb` 新增 coverpoint 与 FSM state 无关，需在 `run_phase` 独立 sample

---

## Phase 1：L1DTLB 权限 Fault + Exception-CAM（7 项）

**覆盖**：AUD-016/017/018（权限fault）、AUD-026/027/028/029（exception-CAM 写入/匹配/replay）

**任务**：
1. 在 `sample_dut()` 中从 `lsu_vif` 读 `mmu_lsu_page_fault0/1`、`mmu_lsu_access_fault0/1`，算出 `wb_dtlb_p0/p1_perm_fault_kind`
2. 在 `sample_dut()` 中从 `v_probe` 读 `l1d_expt_wr*`、`l1d_expt_pgflt/acflt`、`l1d_expt_hit_vec`，算出 expt 写入来源/类型/命中计数
3. 在 `cg_l1dtlb` 追加 6 个 coverpoint：`cp_perm_fault_p0/p1`、`cp_expt_wr_src`、`cp_expt_wr_type`、`cp_expt_match`、`cp_expt_hit_cnt`
4. 在 `run_phase` 独立 sample 这些 coverpoint（权限fault 依赖 `lsu_vif != null`）

**验收标准**：
- [ ] `cp_perm_fault_p0/p1` 的 `iff` 条件为 `lsu_p0_pa_vld` / `lsu_p1_pa_vld`（仅 LSU 返回有效 PA 时采样）
- [ ] `cp_expt_wr_src` 正确区分 single_p0 / single_p1 / dual 三种写入源
- [ ] `cp_expt_wr_type` 的 bin 覆盖 pgflt / acflt / dual_fault 三种 fault 组合
- [ ] `cp_expt_hit_cnt` bin 边界正确（0 / 1 / 2-8），不会因 8-bit vector 产生溢出
- [ ] 权限 fault 采样包裹在 `if (lsu_vif != null)` 中，vif 缺失时不崩溃

---

## Phase 2：L1DTLB Invalidate（5 项）

**覆盖**：AUD-034/035/036/037/038

> **spec_gap 警告（AUD-037/038）**：L1DTLB 审计标记这两个为 spec_gap——"Function description asks but does not finalize this race"。`cp_inv_race` 的 coverpoint **只记录竞争事件是否发生**（覆盖率），**绝对不能基于此加结果 checker / scoreboard 预期**，直到设计团队澄清 race 的预期最终 valid 状态。

**任务**：
1. 在 `sample_dut()` 中从 `v_probe.tlboper_utlb_clr/inv_va_req/inv_va` 算出 `wb_dtlb_inv_kind`、`wb_dtlb_inv_during_hit/install`
2. 在 `cg_l1dtlb` 追加 2 个 coverpoint：`cp_inv_type`（INV_ALL/INV_VA/INV_ASID）、`cp_inv_race`（invalidate×hit、invalidate×install 同拍）
3. 在 `run_phase` 独立 sample

**验收标准**：
- [ ] `cp_inv_type` 的 `iff` 条件为 `wb_dtlb_inv_kind != 0`（仅发生 invalidate 时采样）
- [ ] `cp_inv_race` 能区分四种场景：无竞争 / hit 同拍 / install 同拍 / 双重竞争
- [ ] INV_ASID 的推断逻辑有明确注释说明依赖的信号（当前通过 entry_vld 大面积清零推断）
- [ ] **AUD-037/038**：coverpoint 代码注释中标注"spec_gap，仅覆盖事件发生，不加结果检查"

---

## Phase 3：L2TLB 核心 covergroup — Lookup + PFU + PTW Interface（15 项）

**覆盖**：TP_012~016（tag lookup）、TP_023~026（PTW interface 合法 completion）、TP_028~033（PFU）

> **TP_027 不在此 Phase**：TP_027 是 Negative assertion（非法 PTW completion），规格明确"不进入普通功能比较、普通随机不生成"，由 Phase 9 SVA 覆盖。
>
> **TP_016 部分覆盖**：`cp_lookup_way_hit_cnt` 的 `bins multi` 是**被动观测** multi-hit 是否在随机仿真中自然发生。multi-hit 极少自然产生（需 TLBWI 写相同 VPN 到不同 way）。完整覆盖需要 Phase 11 定向 vseq 通过 TLBWI 主动构造。

**任务**：
1. 新建 `cg_l2tlb_lookup`：`cp_lookup_result`（hit/miss）、`cp_lookup_pgs`（4K/2M/1G）、`cp_lookup_source`（ITLB/DTLB）、`cp_lookup_acc_type`（load/store）、`cp_lookup_way_hit_cnt`（single/multi-hit）、`cx_lookup_src_res`、`cx_lookup_pgs_src`
2. 新建 `cg_l2tlb_pfu`：`cp_pfu_fault_kind`（pass/flag_fault/acc_fault/deny），依赖 `l2_pfu_rsp_vld`
3. 新建 `cg_l2tlb_ptw_if`：`cp_ptw_req`、`cp_ptw_req_type`、`cp_ptw_cmplt_type`（data_valid/pgflt/acc_err），依赖 `l2tlb_ptw_req` / `ptw_l2tlb_cmplt`
4. 在 `run_phase` 每个 cycle sample 这 3 个 covergroup

**验收标准**：
- [ ] `cg_l2tlb_lookup`：`cp_lookup_result` 三个 bin（hit/miss/idle）互斥完备；`cp_lookup_pgs` 仅在 hit 时采样；cross 项 `cx_lookup_src_res` / `cx_lookup_pgs_src` 不产生非法组合
- [ ] `cg_l2tlb_pfu`：`cp_pfu_fault_kind` 的 `iff` 为 `l2_pfu_rsp_vld`，四个 bin 互斥完备
- [ ] `cg_l2tlb_ptw_if`：`cp_ptw_cmplt_type` 正确区分 data_valid（cmplt=1 + data_vld=1）、page_fault（cmplt=1 + pgflt=1）、access_err（cmplt=1 + acc_err=1）
- [ ] 三个新 covergroup 不依赖任何 `sample_dut()` 中的 `wb_*` 变量，直接引用 `v_probe` 信号（自包含）

---

## Phase 4：L1DTLB Install 仲裁 + Wakeup/Busy（3 项）

**覆盖**：AUD-024（install 仲裁）、AUD-009/010（tlb_busy/wakeup）

**任务**：
1. 在 `sample_dut()` 中从 `v_probe.l1d_install_sel_*` 和 `l1d_expt_wakeup` 算出 install 仲裁选择和 wakeup 状态
2. 在 `cg_l1dtlb` 追加 3 个 coverpoint：`cp_install_arb_sel`（ptw/l2/wfi）、`cp_install_arb_conflict`（多源竞争）、`cp_wakeup`（active/inactive）
3. 在 `run_phase` 独立 sample

**验收标准**：
- [ ] `cp_install_arb_sel` 的优先级逻辑与 RTL 一致（wfi > l2 > ptw），`iff` 条件确保仅在发生 install 选择时采样
- [ ] `cp_install_arb_conflict` 正确检测 ≥2 个 install_req 同时为 1 的场景
- [ ] `cp_wakeup` 使用 `l1d_expt_wakeup != 0` 作为触发源，与 RTL wakeup 语义（refill 时 OR MB 有 pgflt/acflt entry 时）对齐

---

## Phase 5：L2TLB Arbiter + TLBOP 操作类型分类（14 项）

**覆盖**：TP_009~011（arbiter）、TP_034~044（TLBOP 各操作类型含 abort）

**任务**：
1. 新建 `cg_l2tlb_arbiter`：`cp_arb_req_type`（read/write）、`cp_arb_acc_type`（load/store）、`cp_arb_bank_sel_cnt`、`cp_arb_stall`
2. 在 `sample_dut()` 中从 `tlbop_l2_tlboper_sel` 推断 `wb_tlboper_op_type`（TLBP/R/WI/WR/INV*）
3. 在现有 `cg_tlboper_fsm` 追加 `cp_op_type`
4. 在 `run_phase` sample 新 covergroup（`cp_op_type` 随已有 `cg_tlboper_fsm.sample()`）

**验收标准**：
- [ ] `cg_l2tlb_arbiter`：所有 coverpoint 的 `iff` 条件为 `l2_arb_req`（仅在仲裁请求时采样），write bin 仅在 `l2_arb_write=1` 时命中
- [ ] `cp_arb_stall` 能区分 normal_flow（req + vld 同时高）和 stall（req 高但 vld 低）
- [ ] `cp_op_type` 的 bin 编码与 RTL `tlbop_l2_tlboper_sel` 的 bit 对应关系有注释说明
- [ ] `cp_op_type` 追加到 `cg_tlboper_fsm` 内部，不破坏现有 FSM state coverpoint 的采样逻辑

---

## Phase 6：L1DTLB Abort 细分 + Credit 边界（4 项）

**覆盖**：AUD-011/012/013（abort×hit/miss）、AUD-021（credit=0 同时 return）

**任务**：
1. 在 `sample_dut()` 中从 `lsu_vif` abort + `v_probe` hit/miss 算出 `wb_dtlb_abort_kind_p0/p1`
2. 从 `v_probe.l1d_sched_credit_cnt` + `l1d_l2_credit_ret` 算出 credit 边界条件
3. 在 `cg_l1dtlb` 追加 3 个 coverpoint：`cp_abort_kind_p0`、`cp_abort_kind_p1`、`cp_credit_boundary_cond`
4. 在 `run_phase` 独立 sample（abort 依赖 `lsu_vif != null`）

**验收标准**：
- [ ] `cp_abort_kind_p0/p1` 仅在 `lsu_mmu_abort0/1=1` 时采样，bin 区分 hit_abort（abort 时 TLB hit）和 miss_abort（abort 时 TLB miss）
- [ ] `cp_credit_boundary_cond` 仅在 `l1d_sched_credit_cnt==0` **且** `l1d_l2_credit_ret==1` 同时满足时命中 `zero_ret` bin
- [ ] abort coverpoint 采样包裹在 `if (lsu_vif != null)` 中

---

## Phase 6B：L1DTLB 遗漏补充 — IID 优先级 / MB CAM hit / Scheduler 优先级（4 项）

> 交叉核查 `covergroup_gap_analysis.md` 时发现 AUD-007/020/022/042 在原始计划中遗漏。

**覆盖**：AUD-007（IID 优先级）、AUD-020（MB CAM hit 不分配不 wakeup）、AUD-022（Scheduler old MB vs bypass）、AUD-042（L1DTLB reset 初始状态）

**任务**：
1. 在 `sample_dut()` 中追算：`wb_dtlb_iid_winner`（双 miss 仅 1 空位时谁胜出）、`wb_dtlb_mb_cam_hit_req`（MB CAM hit 事件）、`wb_dtlb_sched_old_mb_prio`（旧 MB vs bypass 调度结果）、`wb_dtlb_reset_done_state`（reset 释放后首拍状态）
2. 在 `cg_l1dtlb` 追加 4 个 coverpoint：`cp_iid_priority`、`cp_mb_cam_hit_no_alloc`、`cp_sched_priority`、`cp_reset_initial_state`
3. 在 `run_phase` 独立 sample（reset 状态检测依赖 `rst_ni` 上升沿）

**验收标准**：
- [ ] `cp_iid_priority` 在 `wb_dtlb_one_free_dual_diff==1` 时采样，区分 `p0_wins` / `p1_wins` / `tie`（同 IID 不可能出现，但留 bin 防 X）
- [ ] `cp_mb_cam_hit_no_alloc` 的 `iff` 条件为 MB CAM hit 事件：某 pipe 在 T0 miss、T1 MB CAM hit、且不分配新 entry
- [ ] `cp_sched_priority` 区分 `old_mb_granted`（旧 MB 优先发 L2 请求）和 `bypass_granted`（新 miss bypass 直接 issue）
- [ ] `cp_reset_initial_state` 在 `rst_ni` 上升沿后第一个 `posedge clk_i` 采样，确认 TLB entry_vld=0、MB vld=0、expt vld=0、credit=INIT

---

## Phase 7：L2TLB Reset + MB Partition + 遗漏补充（7 项）

**覆盖**：TP_001/002（cold/warm reset）、TP_043（TLBOP+reset）、TP_055（MB partition ITLB vs DTLB）、TP_047（replacement victim way）、AUD-031（RTU flush 清理 MB/expt）

> **❌ 删除 `cp_illegal_cmplt`**：TP_027 是 Negative assertion（规格明确"不进入普通功能比较、普通随机不生成"），用 coverpoint 覆盖是**验证方法论错误**：
> - 非法 bin（illegal_no_pending / illegal_multi_flags / illegal_bad_id）在正常仿真中**永远不会命中**，只会产生 0% 死 bin 污染覆盖率报告
> - 合法 bin（legal_data_vld / legal_pgflt / legal_acc_err）与 Phase 3 `cp_ptw_cmplt_type` **完全重复**
> - TP_027 的正确验证手段是 Phase 9 SVA（`illegal_ptw_completion` property）
>
> **需删除的代码**：
> - `wb_illegal_cmplt_kind` 变量声明（~line 156）
> - `cp_illegal_cmplt` coverpoint 定义及全部 bin（~line 354-359）
> - `sample_dut()` 中 `wb_illegal_cmplt_kind` 赋值逻辑（~line 2010-2024）
> - `run_phase` 中 `cp_illegal_cmplt.sample()` 调用（如有）
> - `final_phase` 打印中相关项（如有）

**任务**：
1. 新建 `cg_l2tlb_reset`：`cp_cold_reset_state`、`cp_reset_during_tlbop`
2. 新建 `cg_l2tlb_mb_part`：`cp_mb_queue_id`（ITLB/DTLB 分布），依赖 `l2mb_alloc_valid` + `l2mb_entry_queue_id`
3. ~~在 `cg_l2tlb_ptw_if` 追加 `cp_illegal_cmplt`~~ → **已删除，TP_027 改由 Phase 9 SVA 覆盖**
4. 在 `cg_l2tlb_lookup`（Phase 3 已建）追加 `cp_victim_way`：覆盖 L2TLB replacement 选中的 victim way（0-7），仅在 refill/TLBWI/TLBWR 写入时采样
5. 在 `cg_l2tlb_reset` 同组追加 `cp_l1d_flush_clear`：覆盖 AUD-031，RTU flush 后 L1DTLB MB vld 和 expt vld 是否清零
6. 在 `run_phase` sample 这 2 个新 covergroup + 2 个追加 coverpoint

**验收标准**：
- [ ] `cp_cold_reset_state` 能捕获 `rst_ni=0` 时 `l2mb_vld_vec==0` 的状态（bin `reset_active_entries_zero`）
- [ ] `cp_reset_during_tlbop` 的触发逻辑有注释说明（依赖 `sample_dut()` 中跨 cycle 状态检测）
- [ ] `cp_mb_queue_id` 仅在 `l2mb_alloc_valid=1` 时采样，正确区分 ITLB（queue_id=0/1）和 DTLB（queue_id=2）
- [ ] **`cp_illegal_cmplt` 及关联变量/赋值/sample 已全部删除**，编译通过无残留引用
- [ ] `cp_victim_way` 仅在 `l2_arb_write==1` 且 `l2_arb_acc_type` 为 refill/TLBWI/TLBWR 时采样
- [ ] `cp_l1d_flush_clear` 在 `rtu_yy_xx_flush` 上升沿后的 cycle 采样 MB vld 和 expt vld 清零状态

**任务**：
1. 新建 `cg_l2tlb_reset`：`cp_cold_reset_state`、`cp_reset_during_tlbop`
2. 新建 `cg_l2tlb_mb_part`：`cp_mb_queue_id`（ITLB/DTLB 分布），依赖 `l2mb_alloc_valid` + `l2mb_entry_queue_id`
3. 在 `run_phase` sample 这 2 个 covergroup

**验收标准**：
- [ ] `cp_cold_reset_state` 能捕获 `rst_ni=0` 时 `l2mb_vld_vec==0` 的状态（bin `reset_active_entries_zero`）
- [ ] `cp_reset_during_tlbop` 的触发逻辑有注释说明（依赖 `sample_dut()` 中跨 cycle 状态检测）
- [ ] `cp_mb_queue_id` 仅在 `l2mb_alloc_valid=1` 时采样，正确区分 ITLB（queue_id=0/1）和 DTLB（queue_id=2）

---

## Phase 8：收尾

**任务**：
1. 在 `final_phase()` 追加新增 6 个 covergroup 的覆盖率打印
2. 更新 `MMU_Phase14_SignoffMatrix.md` 标记 covergroup 覆盖率项为 updated

**验收标准**：
- [ ] `final_phase()` 的 `$sformatf` 字符串包含全部 6 个新 covergroup 的 `get_coverage()`
- [ ] 打印格式与现有其他 covergroup 的输出一致（`%0.2f` 格式）
- [ ] Signoff Matrix 中 P1-P7 覆盖的审计项对应行标记为 covergroup 已覆盖

---

## 阶段汇总

| Phase | 范围 | 新增 coverpoint | 新建 covergroup | 覆盖审计项 |
|-------|------|:---:|:---:|---|
| P1 | L1DTLB 权限Fault + Expt-CAM | 6 | — | AUD-016~018, 026~029 (7) |
| P2 | L1DTLB Invalidate | 2 | — | AUD-034~038 (5) |
| P3 | L2TLB Lookup / PFU / PTW | 7 | 3 | TP_012~016, 023~026, 028~033 (15) |
| P4 | L1DTLB Install仲裁 + Wakeup | 3 | — | AUD-009/010/024 (3) |
| P5 | L2TLB Arbiter + TLBOP op_type | 5 | 1 | TP_009~011, 034~044 (14) |
| P6 | L1DTLB Abort + Credit边界 | 3 | — | AUD-011~013, 021 (4) |
| P6B | L1DTLB 遗漏补充（IID/MB CAM/Sched/Reset） | 4 | — | AUD-007, 020, 022, 042 (4) |
| P7 | L2TLB Reset + MB Partition + 遗漏补充 | 5 | 2 | TP_001/002, 027, 043, 047, 055 + AUD-031 (7) |
| P8 | 收尾 | — | — | — |
| **合计** | | **35** | **6** | **60 项** |

## 完成后覆盖状态

| 模块 | 完成后 | 剩余 | 剩余处理 |
|------|--------|------|---------|
| L1DTLB (42) | 42 项全覆盖 | 0 | — |
| L2TLB (58) | 48 项有覆盖 | 10 项 | Phase 9-12 |

---

# 剩余缺口实现计划（非 covergroup 方式）

以下 11 项不能用/不适合在 `cg_l1dtlb` 或 L2TLB covergroup 中实现，需要其他验证手段。

---

## Phase 9：SVA / Assertion 覆盖（6 项）

> 新建 assertion 文件或在现有 assertion 模块中追加。捕获时序关系和边界条件。

**覆盖**：AUD-014, AUD-015, TP_027, TP_048, TP_049, TP_056, TP_058

| ID | SVA 属性 | 检测内容 | probe 信号 |
|----|---------|---------|-----------|
| AUD-014 | `vabuf_no_effect` | vabuf 翻转时 TLB 行为不变 | `l1d_p0/1_hit_vld`, `mmu_lsu_pa0/1` |
| AUD-015 | `t0_t1_pulse_width` | T0/T1 响应脉冲宽度 ≥ N cycles | `mmu_lsu_pa0_vld`, `mmu_lsu_pa1_vld` |
| TP_027 | `illegal_ptw_completion` | 非法 completion（bad ID / 无 outstanding MB）触发 assertion，不进入功能比较 | `ptw_l2tlb_ref_id`, `l2mb_vld_vec`, `l2mb_entry_sent` |
| TP_048 | `no_x_propagation` | 非法输入时关键 payload 不为 X/Z（协议防护，**不检查 DUT 拒绝行为**） | `l2_arb_req`, `l2tlb_ptw_req`, 各 valid/payload |
| TP_049 | `no_starvation` | ReqQ/MB 请求不被无限期阻塞 | `l2_reqq_vld_vec`, `l2mb_vld_vec` |
| TP_056 | `ptw_ooo_completion` | PTW 乱序完成时 ID 匹配正确 | `ptw_l2tlb_id`, `l2tlb_ptw_id` |
| TP_058 | `control_hazard_safe` | 控制冒险不导致非法状态跳转 | `l2_final_vld`, `l2_arb_req` |

**验收标准**：
- [ ] 每条 SVA 在 `rst_ni=1` 时生效，`$past()` 引用的信号有复位后初始化
- [ ] `no_starvation` 使用 `$stable` + 超时计数器，而非无限时间窗口
- [ ] 仿真回归中 assertion 不产生误报（false positive）

---

## Phase 10：追加 L2TLB coverpoint（9 项）

> 在 Phase 3/5/7 已建 covergroup 中追加，或在 `sample_dut()` 中追加变量后于 `run_phase` 采样。

**覆盖**：TP_006, TP_007, TP_017, TP_018, TP_019, TP_022, TP_053, TP_054, TP_057

| ID | 追加位置 | 新增 coverpoint | probe 信号 |
|----|---------|---------------|-----------|
| TP_006 | `cg_l2tlb_arbiter` | `cp_bypass_issue` | `l2_arb_req` + `arb_l2tlb_req` 同拍 grant |
| TP_007 | `cg_l2tlb_mb_part` | `cp_mb_full_retry` | `l2mb_vld_vec` 全满 + 新 miss 到达 |
| TP_017 | `cg_l2tlb_mb_part` | `cp_mb_alloc_source` | `l2mb_alloc_valid` + `l2mb_entry_queue_id` |
| TP_018 | `cg_l2tlb_ptw_if` | `cp_ptw_disabled` | `l2_miss` + `ptw_on`（或 `cp0_mmu_ptw_en`） |
| TP_019 | `cg_l2tlb_ptw_if` | `cx_mb_to_ptw_payload`（cross） | `l2tlb_ptw_req` + `l2tlb_ptw_vpn` + `l2mb_entry_vpn` |
| TP_022 | `cg_l2tlb_mb_part` | `cp_mb_alloc_dealloc_same_cycle` | `l2mb_alloc_valid` + `l2mb_dealloc_valid` 同拍 |
| TP_053 | `cg_l2tlb_lookup` | `cp_prefetch_mask` | `l2_pfu_req_vld` + `prefetch_mask` |
| TP_054 | `cg_l2tlb_arbiter` | `cp_bank_skew` | `l2_arb_bank_sel` 分布（debug cover） |
| TP_057 | `cg_l2tlb_pfu` | `cp_pfu_truth_table` | `pfu_pmp_flg4`、`pfu_sysmap_flg4` |

> **注（TP_054）**：规格明确"不要求 v1 hard close exact hash，至少 debug cover"（line 2143）。`cp_bank_skew` 只覆盖 bank_sel 分布观测，不检查 hash 正确性。

> **注**：TP_021（MB duplicate alloc）规格说明明确"不要求 duplicate suppression"——DUT 不做去重，重复分配是允许行为，已移至 Phase 12。

**任务**：
1. 确认各 probe 信号在 `mmu_dut_probes_if.sv` 中已暴露，缺失则先补 probe
2. 在对应 covergroup 的 `endgroup` 前追加 coverpoint / cross
3. 若需 `wb_*` 中间变量，在 `sample_dut()` 中追加计算
4. 在 `run_phase` 追加独立 sample 调用

**验收标准**：
- [ ] 每个新 coverpoint 有 `iff` 条件，不产生无意义采样
- [ ] `cp_mb_full_retry`（TP_007）正确检测 MB 全满（9 entry 全 valid）+ 新 miss 到达且不分配的场景
- [ ] `cp_mb_alloc_source`（TP_017）的 bin 区分 ITLB（queue_id=0）/ DTLB（queue_id=1-8）/ PFU（queue_id=9）
- [ ] `cp_mb_alloc_dealloc_same_cycle`（TP_022）正确检测 alloc 和 dealloc 同拍发生（用 prev 变量追踪边沿）
- [ ] `cx_mb_to_ptw_payload` 的 cross 项不产生非法组合（MB issue 与 PTW req 时序对齐）
- [ ] `cp_pfu_truth_table` 的 bin 覆盖 PFU 所有输入组合（pmp_flg × sysmap_flg × deny）

---

## Phase 11：Directed vseq 负向测试 + 定向构造（3 项）

> 在 `mmu_l2tlb_coverage_vseq.svh` 或新建 vseq 中追加定向激励。

**覆盖**：TP_048（负向）、TP_058（控制冒险）、TP_016（multi-hit 定向构造）

| ID | vseq 名称 | 激励场景 |
|----|----------|---------|
| TP_048 | `vseq_l2tlb_illegal_input` | 注入非法 access type(3'b111)、bad completion ID、credit overflow；**验证 assertion 触发或协议检查命中，不比较功能结果**（规格明确非法输入"不应产生"，DUT 行为未定义） |
| TP_058 | `vseq_l2tlb_control_hazard` | 在同拍切换 ptw_on / tlboper_on，验证 FSM 不进入非法状态 |
| TP_016 | `vseq_l2tlb_multi_hit_construct` | 通过 TLBWI/TLBWR 向不同 way 写入相同 VPN+ASID+pgs 的 valid entry，主动构造 multi-hit；验证 DUT 返回 page fault 路径（`l2tlb_l1dtlb_pgflt` / `l2tlb_l1itlb_pgflt`），不当作正常 single-hit 更新 |

**任务**：
1. 在 `mmu_l2tlb_coverage_vseq.svh` 中新增 `vseq_l2tlb_illegal_input`、`vseq_l2tlb_control_hazard`、`vseq_l2tlb_multi_hit_construct`
2. 在 `mmu_vseq_lib.svh` 或测试列表中注册这三个 sequence
3. TP_048 验证方式：检查 SVA assertion 触发（Phase 9 的 `no_x_propagation`），**不设功能预期**，不触发 `uvm_error`
4. TP_058 验证方式：检查 control 改写前 outstanding 已 drain/flush/abort
5. TP_016 验证方式：构造 multi-hit 后检查 DUT 走 page fault 路径（multi-hit 不作为正常 hit），同时 Phase 3 `cp_lookup_way_hit_cnt` 的 `bins multi` 被命中

**验收标准**：
- [ ] TP_048 vseq 至少包含 3 种非法输入组合（bad access type / bad completion ID / credit overflow）
- [ ] TP_048 vseq **不比较 DUT 功能输出**，只检查 SVA assertion 是否触发
- [ ] TP_058 vseq 覆盖 `ptw_on` 下降沿与 `tlboper_on` 上升沿同拍的场景
- [ ] TP_058 vseq 验证 control 改写前 outstanding translation 已完成 drain/flush/abort
- [ ] TP_016 vseq 成功通过 TLBWI 构造 ≥2 way 的 multi-hit，且 Phase 3 `cp_lookup_way_hit_cnt` 的 `bins multi` 命中

---

## Phase 12：设计澄清 / Meta（5 项）

> 依赖设计团队确认或流程审计，不产生代码。

| ID | 类型 | 行动 |
|----|------|------|
| AUD-025 | spec_gap | 与设计确认：多 WFI entry 同时存在时的选择策略，确认后补充 coverpoint 或 SVA |
| AUD-033 | spec_gap | 与设计确认：多 entry 命中同一 VA 是否允许、如何处理，确认后补充 |
| TP_003 | meta | UVM 环境边界审计——检查是否所有 `*_if` 信号都被 monitor 捕获，是否有时序窗口遗漏 |
| TP_021 | spec 已澄清 | 规格明确"不要求 duplicate suppression"——DUT 允许重复分配。现有 `test_mmu_dir_l2tlb_mb_dup_alloc_prevention` 需重审/改名以反映此规格决策（验证目标是"重复分配被允许且各 entry 独立 issue PTW"，而非"防止重复"） |
| TP_050 | meta | 覆盖率收敛——在所有 Phase 完成后，检查整体覆盖率 ≥95%，未命中 bin 有 waiver 说明 |

**验收标准**：
- [ ] AUD-025 / AUD-033 有设计团队的书面答复（邮件/issue/文档注释）
- [ ] TP_003 审计结果记录在 `l1dtlb_testpoint_audit.md` 中
- [ ] TP_021 的现有测试 `test_mmu_dir_l2tlb_mb_dup_alloc_prevention` 已重审并改名（去掉 "prevention"），验证逻辑改为"确认重复 entry 各自独立 issue PTW"
- [ ] TP_050 在回归报告中体现：总覆盖率 / 未命中 bin 列表 / waiver 理由

---

## 剩余缺口阶段汇总

| Phase | 实现方式 | 覆盖项数 | 覆盖 ID |
|-------|---------|:---:|------|
| P9 | SVA / Assertion | 6 | AUD-014, AUD-015, TP_048, TP_049, TP_056, TP_058 |
| P10 | 追加 coverpoint | 9 | TP_006, TP_007, TP_017, TP_018, TP_019, TP_022, TP_053, TP_054, TP_057 |
| P11 | Directed vseq | 3 | TP_048, TP_058（与 P9 互补）, TP_016（与 P3 互补） |
| P12 | 设计澄清 / Meta | 5 | AUD-025, AUD-033, TP_003, TP_021, TP_050 |
| **合计** | | **22 次覆盖** | **16 项**（TP_048/058 跨 P9+P11 双重覆盖） |

## 全覆盖验证

| 模块 | 总量 | P1-P8 covergroup | P9-P12 其他方式 | 合计 | 状态 |
|------|:---:|:---:|:---:|:---:|:---:|
| L1DTLB | 42 | 42 | 0 | 42 | ✅ 全覆盖 |
| L2TLB | 58 | 48 | 10 | 58 | ✅ 全覆盖 |
| **总计** | **100** | **90** | **10** | **100** | ✅ |

## 修改点

只改一个文件 `mmu_env_cg_whitebox.svh`，8 个插入位置：
- class 成员变量区：追加 `wb_*` 变量（P1-P7 + P6B 新增 4 个）
- class 顶部：追加 6 个新 covergroup 定义（P3×3 + P5×1 + P7×2）
- `cg_l1dtlb` endgroup 前：追加 P1/P2/P4/P6/P6B 的 coverpoint（共 22 个）
- `cg_l2tlb_ptw_if` endgroup 前：追加 `cp_illegal_cmplt`（P7）
- `cg_l2tlb_lookup` endgroup 前：追加 `cp_victim_way`（P7）
- `cg_tlboper_fsm` endgroup 前：追加 `cp_op_type`（P5）
- `sample_dut()` 末尾：追加各 Phase 的变量赋值（P1-P7 + P6B）
- `run_phase()` 循环内：追加各 Phase 的独立 sample 调用
