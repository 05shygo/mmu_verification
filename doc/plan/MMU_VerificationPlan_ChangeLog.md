# MMU Verification Plan ChangeLog

> 合并日期：2026-06-07
> 维护范围：原 `doc/plan/plan_v1.md` ~ `plan_v7.md` 的验证计划变更记录。

## 合并说明

- 本文件是 `doc/plan` 的唯一维护入口，用于保留 MMU Verification Plan 从 v1.0 到 v7.0 的历史变更。
- `plan_v2.md` 与 `plan_v3.md` 内容完全一致，合并时仅保留一份，标记为 `v2/v3.0`。
- 原始分散文件已归档到 `../archive_merged_20260607/plan/`，只作为历史快照，不再作为维护入口。
- 主验证计划仍以 `../MMU_VerificationPlan_final.md` 为准；本文件只记录各版本改动背景、依据和增量清单。

## 源文件映射

| 原文件 | 合并后章节 | 说明 |
| --- | --- | --- |
| `plan_v1.md` | `v1.0` | 初始验证计划完善 |
| `plan_v2.md` | `v2/v3.0` | 与 `plan_v3.md` 内容一致，合并时保留此份 |
| `plan_v3.md` | `v2/v3.0` | 与 `plan_v2.md` 重复，归档保留 |
| `plan_v4.md` | `v4.0` | 接口规格对齐 |
| `plan_v5.md` | `v5.0` | MMU/PTW 接口补全 |
| `plan_v6.md` | `v6.0` | PMP/sysmap/PTW 深化 |
| `plan_v7.md` | `v7.0` | bus_error / MBUF / PDE Cache 更新 |

---
## v1.0 - 初始验证计划完善

> 原标题：Plan: MMU 验证计划完善
> 原始来源：`../archive_merged_20260607/plan/plan_v1.md`


### TL;DR
在现有极详细的 MMU_VerificationPlan.md（1500+行，F1-F14，120+TC，60+Gap TC）基础上，通过深度 RTL 分析发现了多处验证盲点、潜在 RTL 缺陷、遗漏功能点及覆盖率缺口，进行系统性补充和修订。

### 核心发现（须补入计划）

#### A. 严重潜在 RTL 缺陷（需在验证计划中显式设计 Negative TC 捕获）

1. **twu.sv**: `scd_chk` / `thd_chk` 权限模式判断错误地使用了 `fst_chk_fetch_type`（应为各自的 fetch_type），跨级访问类型不一致时权限检查会出错
2. **twu.sv**: `thd_chk` (4K页) 缺少 A bit violation 检测（`!flg[5]`），4K页 A=0 不触发 page fault（F4.13 仅描述了 A bit，但 TC 需明确针对 4K 页的 thd_chk 路径）
3. **twu.sv**: `thd_chk_refill_req` 缺少 `cp0_mmu_maee` 和 `leaf_vld` 检查，MAEE=0 时或非叶节点 4K PTE 会错误触发 refill
4. **mmu_arb.sv**: `mask_bank_sel` 中 binary literal 可能写成十进制整数（如 `00110011` 无 `8'b` 前缀），bank 选择完全错误
5. **mmu_l2tlb.sv**: `raw_vld` 条件 `||` 应为 `&&`，导致 PTW 读/写也进入命中判断流水线
6. **mmu_l2tlb.sv**: `arb_l2tlb_is_dtlb` 重复条件（两次 `== 3'b010`），缺少 store type `3'b110`
7. **mmu_l2tlb.sv**: SFENCE/TLBWI 无效化后 RRPV 不清零，被无效 entry 的 RRPV 仍保留，污染后续替换决策
8. **pplru.sv**: 复位后 entry 0 首次命中不触发 PLRU 更新（`hit_num_flop=0`，首次命中 entry 0 时 `index==flop`，skip update）
9. **twu.sv**: CSR Arbiter 中 case 重复分支（`3'b010` 出现两次），`scd_csr` 路径永远不可达
10. **twu.sv**: CSR FSM IDLE 分支缺少 else，可能推断 latch

#### B. 遗漏功能点（需新增 F-ID）

- **F2.3 修正**：MB Entry FSM 实际有 7 个状态（IDLE/WFG/WFC/PGFLT/ACFLT/ABT/WFI），现有计划漏了 WFG 状态
- **F2.NEW.1**: MB Entry bypass path：`alloc_vld` 且同时 `issue_grant` → IDLE 直接到 WFC（跳过 WFG）
- **F2.NEW.2**: MB Entry WFG 中 grant + abort 同周期的竞争（→ ABT 路径）
- **F4.NEW.1**: PDE Cache 更新限制：仅非叶 PTE（V=1,R=0,X=0）才更新 PDE Cache，叶 PTE 不应触发更新
- **F4.NEW.2**: TWU 6 级流水线架构（FST/SCD/THD PMP+CHK stages）而非纯 FSM
- **F4.NEW.3**: 4K 页 A bit 缺失检测专属（thd_chk 路径专属 TC）
- **F3.NEW.1**: SFENCE 无效化后 RRPV 不清零的验证（确认 RTL 行为，还是缺陷？）
- **F7.NEW.1**: `mmu_pmp_fetch4` 被注释掉，L2TLB PMP 端口无 fetch 类型（验证影响）
- **F7.NEW.2**: `pmp_mmu_flg5,6,7` 标注为 [NEW]（PTW 扩展端口，验证计划需明确其功能）
- **F8.NEW.1**: SFENCE INVVA 已简化为单 pass（非原 14 状态多 pass），混合页大小同 VPN 场景覆盖不足
- **F10.NEW.1**: `mmu_yy_xx_no_op` 输出信号未在现有计划中出现
- **F12.NEW.1**: pplru entry 0 首次命中非更新行为需显式验证

#### C. 覆盖率补充（需新增 Covergroup / SVA）

- `cg_mb_fsm_wfg`：MB Entry WFG 状态和 bypass/竞争路径
- `cg_pde_leaf_nonleaf`：PDE cache 更新中叶/非叶 PTE 区分
- `cg_rrpv_post_inv`：SFENCE 后 RRPV 状态分布（是否清零）
- `cg_twu_stage_cross`：TWU 不同 stage (fst/scd/thd) 的 fetch_type 组合
- `sva_thd_a_bit_pgflt`：thd_chk 中 A=0 对 4K page 的 page fault 断言
- `sva_pde_nonleaf_upd`：非叶 PTE 才更新 PDE cache 的断言
- `sva_rrpv_inv_state`：INV 后对应 RRPV 的有效状态断言
- `cg_bank_sel_mask`：mask_bank_sel 各模式覆盖（防 literal 编码错误）
- `cg_sfence_invva_single_pass`：单 pass INV 的覆盖
- `cg_pmp_fetch_ports`：fetch 仅 4 端口的覆盖

#### D. 需修正的现有描述错误

- F1.1：描述写"32 entry"但 RTL 实际为 16 entry（session memory 也确认 16 entries）
- F2.3：FSM 状态列表不完整（缺 WFG）
- F8.2：未明确 INVVA 已从 14 状态简化为 5 状态（single-pass）
- 第 5 章 L2 TLB 特性 F3.4 需更新：tag match 实际含 kid0-kid5 6 路并行比较
- §2.3 接口表：缺 `mmu_yy_xx_no_op` 信号

### 步骤（写文件时的改进范围）

**Phase 1：修正现有错误（高优先）**
1. F1.1：ITLB entry 数量修正为 16
2. F2.3：FSM 状态列表补充 WFG（7 状态）
3. F8.2：明确 SFENCE INVVA 已简化为 5-state single-pass FSM
4. §2.3：接口表补充 `mmu_yy_xx_no_op`、`pmp_mmu_flg5/6/7` 标注

**Phase 2：新增功能点**
5. F2.3 下新增 F2.3a/b：bypass 路径 + WFG/ABT 竞争
6. F4 下新增 F4.NEW.1-3：PDE cache 限制、TWU 6-stage、4K thd_chk A bit
7. F3 下新增 F3.NEW.1：SFENCE 后 RRPV 不清零语义
8. F7 下新增 F7.NEW.1-2：fetch4 缺失、flg5-7 NEW 端口
9. F10 下新增 F10.NEW.1：mmu_yy_xx_no_op
10. F12 下新增 F12.NEW.1：pplru entry 0 first hit

**Phase 3：潜在 RTL 缺陷驱动 TC**
11. 为 10 个潜在缺陷（Section A）各新增 1-2 个 TC，标注为 "BUG_HUNT" 类型
12. 更新 §6.5 Gap-Driven TC 列表

**Phase 4：覆盖率补充**
13. §7.2 功能覆盖率表新增 10 个 covergroup
14. §7.3 SVA 清单新增 4 个新断言

**Phase 5：文档一致性**
15. §12 Traceability Matrix 更新（新增 F-ID 和 TC-ID 映射）
16. 风险表（§11）新增 R15-R17 对应新发现的 RTL 缺陷风险

### 关键文件
- `c:\Users\LIUCONG\Desktop\mmu_verification-main\MMU_VerificationPlan.md` — 唯一修改目标

### 验证步骤
1. 检查 F1.1 entry 数量修正是否影响其他章节引用
2. 确认 Phase 2 新 F-ID 不与现有编号冲突
3. 确认 Phase 3 TC-ID 命名规范（`TC-BUG-*`）与现有体系兼容

### 决策
- 将潜在 RTL 缺陷以"需设计确认"方式记录，不直接定性为 Bug
- 保持现有编号体系，新增内容用 ".NEW.*" 或追加序号
- 仅修改 MMU_VerificationPlan.md，不创建新文件

---

## v2/v3.0 - 二次完善（plan_v2.md 与 plan_v3.md 内容一致，合并时去重）

> 原标题：MMU 验证计划 第二次完善（v2.0 → v3.0）改动清单
> 原始来源：`../archive_merged_20260607/plan/plan_v2.md`


> **说明**：本文件对标 `plan_v1.md`，列出在 `MMU_VerificationPlan_v1.md`（v2.0 → v3.0）之上所做的**全部第二次完善点**。改动围绕两条主线：(1) 通过 RTL 二次核对**纠正 v2.0 中的错判**；(2) 追加新发现的高危 Bug 与覆盖盲点。
>
> **编辑对象**：直接在 `MMU_VerificationPlan_v1.md` 中就地更新为 v3.0 版本。
> **日期**：2026-04-22
> **作者**：Verification Team

---

### 0. 本次完善总体方针

1. **先纠错、再补充**：v2.0 继承自 plan_v1.md 的 10 条“潜在 RTL 缺陷”经过二次 RTL 走读后，**6 条为错判**（用户澄清：thd_chk 必为叶 PTE，进一步证伪 TC-BUG-002/003）、**4 条真实存在**。先把错判降级并做透明化记录（保留 TC 编号 gap 以便追溯演化），再在真实缺陷之上升级优先级。
2. **强证据、不定性**：v3.0 所有新发现以"RTL 二次核对 — 疑似，需设计确认"语气书写；对应 TC 打 BUG_HUNT 标签并配 SVA 形式化保护，不在验证侧擅自定性。
3. **覆盖率闭环**：每一条新 Gap 必须同时具备 **Feature 表行 + TC 行 + covergroup 或 SVA**，避免只在某一层落单。
4. **接口表一致性**：补齐 v1 遗漏的**广播/全局使能/CSR 细分**信号，保证 §2.3 接口表与 `ct_mmu_top.v` 端口列表一一对应。

---

### A. 纠错项（v2.0 → v3.0 证伪）

RTL 二次核对（`mmu_arb.sv` / `twu.sv` / `mmu_l2tlb.sv`）及用户对 thd_chk 语义的澄清后，确认 v2.0 中以下 **6 条疑似缺陷不成立**：

| v2.0 原判定 | v3.0 证伪依据 | v1.md 处置 |
|-------------|--------------|-----------|
| TC-BUG-001 / F4.NEW.2：`twu` 跨级使用 fst_pmp_fetch_type 错误 | `twu.sv#L1175` `fst_pmp_itlb_sel = fst_pmp_vld & fst_pmp_fetch_type`；scd/thd 各级对应 `scd_pmp_*` / `thd_pmp_*` 独立字段，无误用 | **TC-BUG-001 由 BUG_HUNT 降级为 Functional，P0→P1**；Feature 表 F4.NEW.2 保留但去除"错误"定性 || TC-BUG-002 / F4.NEW.3：`twu` thd_chk 路径 4K 页 A-bit 检测缺失 | 用户澄清：thd_chk 必为叶 PTE，`thd_chk_page_flt` 中 A-bit 检测（`!flg[5]`）正常执行，4K/2M/1G 均有对应分支，非缺陷 | **TC-BUG-002 降为 Functional，P0→P1**；`sva_thd_a_bit_pgflt` 保留作正向保护 |
| TC-BUG-003 / F4.NEW.1：MAEE=0 + 叶 PTE 时 thd_chk_refill_req 误触 / `mbuf_cache_upd` 误入 Cache | 用户澄清：thd_chk 必为叶 PTE，`thd_chk_refill_req` **只要不触异常即可发出**；`mbuf_cache_upd` 的“仅非叶 PTE”限制仅作用于 Cache 内容，与 refill 发送不矛盾 | **TC-BUG-003 降为 Functional，P0→P1**；`sva_pde_nonleaf_upd` 保留作 Cache 污染保护 || TC-BUG-004 / F5.NEW.1：`mmu_arb` bank mask 字面量缺 `8'b` 前缀 | `mmu_arb.sv#L142` 使用 `8'b00110011` 等完整字面量，未出现无前缀 decimal | **TC-BUG-004 降为 Functional，P0→P1**；F5.NEW.1 描述改为"正向覆盖"；**R16 风险等级由高降为低** |
| TC-BUG-009 / F4.NEW.2：`twu` CSR Arbiter `2'b10` case 分支重复 | `twu.sv` CSR Arbiter 实际 case 为 `2'b01`/`2'b10`，不存在重复 | **TC-BUG-009 整行删除**（编号保留空位以便 v2→v3 演化追溯）|
| TC-BUG-010 / F4.NEW.2：CSR FSM IDLE 无 else 分支可能 latch 推断 | `twu.sv#L1040` 已有 `else ptw_nxt_st = TWU_IDLE` 闭合分支 | **TC-BUG-010 整行删除** |

---

### B. 新发现项（v3.0 新增）

#### B.1 **P0 高危 Bug（强证据）**

| ID | 定位 | 描述 |
|----|------|------|
| **F4.NEW.4 / TC-BUG-011 / R19** | `twu.sv#L1128-L1133` | `else if(twu_crs2_1g && twu_csr_cross)` **与上一行完全重复**；推测第二行应为 `twu_crs2_2m && twu_csr_cross`。导致 **2MB 巨页 CSR 跨界场景下 `csr_data_flop` 不会被 shift 更新**，后续 CSR refill 使用旧数据。**应作为 P0 高危 Bug 建 JIRA 工单** |

#### B.2 **P1 新盲点（RTL 行为正确但缺乏保护）**

| ID | 定位 | 描述 |
|----|------|------|
| **F4.NEW.5 / TC-BUG-012** | `twu.sv#L1052-L1063` | TWU_IDLE 状态按 bit[1]/bit[0] 依次判断 `csr_grant`；若仲裁侧异常输出 `2'b11` 会隐式偏向 1G 分支。需 `sva_csr_grant_onehot` 约束 |
| **F5.NEW.2 / TC-BUG-013** | `mmu_arb.sv#L180-L235` | `arb_ptw_grant` → `ptw_write_req1` → `ptw_write_req2` 两拍流水中段若 reset / `ptw_xx_cmplt` 到达可能产生 SRAM stale write。需 `sva_ptw_write_pipe_reset_safe` |
| **F5.NEW.3 / TC-BUG-014** | `one_to_four_xbar.sv#L100-L115` | `twu_req_point_r` 复位初值 `4'b0001` 造成冷启动首请求偏向 TWU0。需 `cg_xbar_cold_start` 监控分布 |

#### B.3 P2 文档项

| ID | 定位 | 描述 |
|----|------|------|
| **F8.NEW.2 / TC-BUG-015** | `ct_mmu_tlboper.v#L685-L730` | 原 14-state INVVA FSM 注释残留（已被 single-pass 替代）。非仿真 TC，仅代码评审追踪 |

#### B.4 **PTW → LSU 取 PTE 通道协议补强（v3.0 新增 F4.42a/b/c）**

**背景**：用户澄清——PTW 发给 LSU 的请求是**严格串行单 outstanding**。请求一旦拉起，必须**保持 `mmu_lsu_data_req` 与 `mmu_lsu_data_req_addr` 稳定**直到 `lsu_mmu_data_vld`（或 `bus_error`）返回；任一时刻至多只有一个 outstanding 请求；LSU 数据通道**无 tag/ID 字段**，也不支持乱序返回。

**原计划思路（缺陷）**：v2.0 仅有 F4.42 一条 `sva_lsu_data_chn`，描述为"`mmu_lsu_data_req_addr` / `req_grant[8:0]` / 响应同步到正确 entry on 状态"，**优先级 P1**。
- ❌ 未声明"请求/地址在 outstanding 期间必须保持稳定"
- ❌ 未声明"outstanding 请求数 ≤ 1"
- ❌ 未明确"无 tag/ID、LSU 不会乱序返回"
- ❌ 未约束"`lsu_mmu_data_vld=1` 必须 `mmu_lsu_data_req=1`"
- ❌ 未约束 MBUF 指针更新时机
- ❌ 接口表第 7 组仅列信号未描述握手语义

**RTL 证据**（[ptw_mbuf.sv#L288,L363-L410](mmu/rtl/ptw_mbuf.sv#L288)）：
1. `mmu_lsu_data_req = |(mbuf_entry_vld & ~mbuf_entry_get & ~mbuf_entry_bus_err_flop) & !tlboper_ptw_abort`
2. `mbuf_ptr_nxt` **只在** `(lsu_mmu_data_vld_reg & mmu_lsu_data_req)` 或 MBUF 变空时更新；其余周期 `mbuf_ptr_nxt = mbuf_ptr`
3. 地址由 `mbuf_ptr_nxt` one-hot 选择 `mbuf_entry_padder[*]`——因此 outstanding 期间地址稳定
4. 无 tag/ID 信号存在
5. `mmu_lsu_tlb_busy` 仅表 MBUF 满，`mmu_lsu_wakeup[11:0]` 是 TLB 层广播，均与 PTE 握手协议无关

**改进后描述**（已落入 MMU_VerificationPlan_v2.md）：

| ID | Feature 表 | 新增验证点 |
|----|-----------|------------|
| **F4.42a（新 P0）** | 串行单 outstanding 握手 | `mmu_lsu_data_req` 拉高后必须与 `mmu_lsu_data_req_addr` / `mmu_lsu_data_size` **保持稳定**直到 `lsu_mmu_data_vld` 或 `lsu_mmu_data_bus_error` 返回；outstanding ≤ 1；TC-PMBUF-SERIAL-OUTSTANDING-001、TC-PMBUF-ADDR-STABLE-001；SVA: `sva_lsu_req_stable_until_vld` / `sva_lsu_addr_stable_until_vld` / `sva_single_outstanding`；covergroup: `cg_lsu_req_outstanding` |
| **F4.42b（新 P0）** | 无 tag/ID、按顺序返回 | `lsu_mmu_data_vld` 返回时必须对应当前 `mbuf_ptr` 所指 entry；`mmu_lsu_data_req=0` 时 `lsu_mmu_data_vld` 不得为 1；禁止 LSU 乱序；TC-PMBUF-NO-TAG-001、TC-PMBUF-INORDER-RESP-001；SVA: `sva_response_inorder` / `sva_vld_only_when_req` |
| **F4.42c（新 P1）** | MBUF 指针更新约束 | `mbuf_ptr` 仅在 `lsu_mmu_data_vld` 或 MBUF 变空时前进，其他周期保持；TC-PMBUF-PTR-HOLD-001；SVA: `sva_mbuf_ptr_only_on_response`；covergroup: `cg_mbuf_ptr_hold` |

**接口表（§2.3 第 7 组）**：明确追加"串行单 outstanding 握手协议"说明并说明 `mmu_lsu_tlb_busy` / `mmu_lsu_wakeup[11:0]` 不参与此握手。

---

### C. 真实缺陷 TC 优先级升级（plan_v1.md 真实项）

下列 **4 条**经 RTL 二次核对**确认为真实缺陷或强疑似缺陷**，v3.0 全部从 P1 升为 P0（注：原列入 TC-BUG-002/003 已随用户澄清证伪——thd_chk 必为叶 PTE，A-bit 检测正常执行、`thd_chk_refill_req` 与 `mbuf_cache_upd` 非叶限制不矛盾，已移出本表并在§A 记录）：

| TC | 定位 | 真实缺陷证据 |
|----|------|--------------|
| TC-BUG-005 / F3.4 | `mmu_l2tlb.sv#L456` | `raw_vld = pipe_vld \|\| ptw_req`（应为 `&&`），PTW 写同周期误触发 tag compare hit |
| TC-BUG-006 / F3.5 | `mmu_l2tlb.sv#L512` | `arb_l2tlb_is_dtlb` 判断重复 `3'b010` 两次且漏 store 类型 `3'b110` |
| TC-BUG-007 / F3.NEW.1 | `mmu_l2tlb_replacement_policy.sv` | SFENCE INVVA 无效化 entry 后 RRPV 未复位，受旧残留影响下一次 victim 选择 |
| TC-BUG-008 / F12.NEW.1 | `pplru.sv` | entry 0 `hit_num_flop == 0` 首次命中 PLRU 树不更新 |

---

### D. §2.3 接口表补齐

补充 v1.md §2.3 表中原本遗漏的 2 行端口组（第 13/14 组）：

| 组 | 补齐信号 | 说明 |
|----|---------|------|
| **13 全局使能 / TLB Oper 完成** | `mmu_xx_mmu_en`（顶层使能广播）、`mmu_lsu_mmu_en`（LSU 专用）、`mmu_cp0_tlb_done`（TLB Oper 完成握手） | v2.0 接口表仅列 `mmu_lsu_mmu_en`，遗漏顶层广播 en 与 TLB Oper 完成握手 |
| **14 CSR 细分控制** | `cp0_mmu_cskyee`、`cp0_mmu_reg_num[1:0]`、`cp0_mmu_mpp[1:0]`、`cp0_mmu_wdata[63:0]`、`cp0_mmu_wreg` | v2.0 仅列 CP0 大类，未列出 CSR 侧的寄存器号、MPP、写通道等细分字段 |

其他勘误：
- `regs_ptw_cur_asid` 内部宽度为 **16-bit**（与 SATP.ASID 一致），v2.0 曾按 8-bit 注释，更正为 16-bit；
- `ct_mmu_top.v` 顶层**不存在** `pmp_mmu_fetch*` 输入信号（fetch 方向只有 MMU→PMP 的 `mmu_pmp_fetch{3,5,6,7}`），v2.0 接口表措辞已澄清。

---

### E. Covergroup / SVA 扩充

#### 新增 Covergroup（3 个）

| 名称 | bind 位置 | 作用 |
|------|----------|------|
| `cg_twu_2m_csr_cross` | `twu` | 2MB 巨页 `twu_crs2_2m && twu_csr_cross` 事件必须被命中；采样 `csr_data_flop` 前后值抓取 L1130 分支重复 Bug（F4.NEW.4） |
| `cg_xbar_cold_start` | `one_to_four_xbar` | 复位后前 16 次 `PDE_xbar_req` 的 TWU 分配分布（F5.NEW.3） |
| `cg_l2_store_dtlb_tag` | `mmu_l2tlb` | `d_req_type=3'b110`（store）路径的 `arb_l2tlb_is_dtlb` 判断覆盖；load(010) vs store(110) cross（F3.5） |
| `cg_lsu_req_outstanding` | `ptw_mbuf` | 采样 `mmu_lsu_data_req` 拉高持续周期数、outstanding 请求数（必须 ≤1）、请求期内地址改变计数（必须=0）（F4.42a）|
| `cg_mbuf_ptr_hold` | `ptw_mbuf` | `mbuf_ptr` 相邻两周期变化时必须命中 `lsu_mmu_data_vld` 或 MBUF 由非空转空两种 bin（F4.42c）|

#### 新增 SVA（3 条）

| 名称 | 对应特性 |
|------|---------|
| `sva_twu_2m_cross_data` | F4.NEW.4：2MB CSR 跨界必须触发 `csr_data_flop` 更新 |
| `sva_csr_grant_onehot` | F4.NEW.5：`csr_grant[1:0]` 禁止同时为 1 |
| `sva_ptw_write_pipe_reset_safe` | F5.NEW.2：reset 断言期间 `ptw_write_req1/req2` 同步清零无 stale |
| `sva_lsu_req_stable_until_vld` | F4.42a：`mmu_lsu_data_req` 拉高期间不得中途拉低直到 `lsu_mmu_data_vld` 或 `bus_error` |
| `sva_lsu_addr_stable_until_vld` | F4.42a：`mmu_lsu_data_req_addr` 在 req 持续期间禁止变化 |
| `sva_single_outstanding` | F4.42a：任意周期 outstanding 请求数 ≤ 1 |
| `sva_response_inorder` | F4.42b：`lsu_mmu_data_vld=1` 时必须 `mmu_lsu_data_req=1` |
| `sva_vld_only_when_req` | F4.42b：`mmu_lsu_data_req=0` 时 `lsu_mmu_data_vld` 不得为 1 |
| `sva_mbuf_ptr_only_on_response` | F4.42c：`mbuf_ptr` 仅在 `lsu_mmu_data_vld` 或 MBUF 变空时更新 |

---

### F. TC 统计更新

| 口径 | v2.0 | v3.0 |
|------|------|------|
| 原 TC-GAP-* | 60 | 60 |
| v2.0 新增 TC-BUG-* | 12 | 12 |
| v3.0 新增 TC-BUG-011~015 | — | +5 |
| v3.0 删除 TC-BUG-009/010 | — | −2 |
| **合计** | 72 | **75** |
| P0 / P1 / P2 分布 | 29 / 35 / 8 | **37 / 37 / 7**（4 条真实缺陷升 P0，4 条证伪降 P1）|

---

### G. 风险表更新（§11）

| 风险 | v3.0 处置 |
|------|----------|
| R15 | 描述收敛为 4 条真实缺陷合并保护（TC-BUG-005/006/007/008 全升 P0）；原列入的 TC-BUG-002/003 随用户澄清证伪（thd_chk 必为叶 PTE，A-bit 检测与 `thd_chk_refill_req` 均为正常设计）从 R15 移除 |
| **R16** | **等级由高降为低**（v2.0 怀疑的 bank mask 编码错误证伪） |
| R17/R18 | 保持原状 |
| **R19 新增** | **P0 高危**：`twu.sv#L1130` 2MB CSR 跨界分支重复，独立 JIRA 工单跟踪；修复前豁免相关测试 |
| **R20 新增** | **中等**：`mmu_arb` PTW 写双级流水 reset 竞争 + `one_to_four_xbar` 冷启动偏向 TWU0，由 `sva_ptw_write_pipe_reset_safe` + `cg_xbar_cold_start` 保护 |

---

### H. 交叉引用索引（便于走查）

- **版本元数据**：v1.md 行 4（文档版本）、行 14（变更说明行 v3.0 新条目）
- **§2.3 接口表**：第 13/14 行及 "v3.0 接口补充" 段
- **§5.2 Feature 表**：F4.NEW.4 / F4.NEW.5（§F4 段）、F5.NEW.2 / F5.NEW.3（§F5 段）、F8.NEW.2（§F8 段）
- **§6.5 TC-BUG 表**：TC-BUG-001/004 降级注记、TC-BUG-009/010 删除行、TC-BUG-011~015 新行
- **§7.2 Covergroup 表**：`cg_twu_2m_csr_cross` / `cg_xbar_cold_start` / `cg_l2_store_dtlb_tag`
- **§7.3 SVA 段**：`sva_twu_2m_cross_data` / `sva_csr_grant_onehot` / `sva_ptw_write_pipe_reset_safe`
- **§11 风险表**：R15 描述扩写、R16 等级下调、R19 新增、R20 新增

---

### I. 遗留 / 下一步

1. **F4.NEW.4 修复前**，建议冻结 2MB CSR 跨界相关测试用例，避免误判 regression；
2. **R20（F5.NEW.2/F5.NEW.3）** 二条均为"RTL 行为当前未观察到显式错误但缺防护"，设计侧可并行评审；
3. plan_v1.md 中提及的"ct_mmu_tlboper 14→5 状态简化"已映射为 F8.NEW.2，仅作文档清理项，不入仿真 regression；
4. 所有 v3.0 新增 TC/CG/SVA 的 stimuli 实现由后续 sequence 开发阶段跟踪 JIRA，本次仅在计划层声明。

---

## v4.0 - 接口规格对齐变更记录

> 原标题：MMU Verification Plan v4.0 变更记录
> 原始来源：`../archive_merged_20260607/plan/plan_v4.md`


> **基于版本**：MMU_VerificationPlan_v3.md（v3.0 Final）  
> **更新版本**：v4.0  
> **日期**：2026-04-22  
> **参考接口文档**：
> - `doc/L1DTLB_Interfaces.md`（L1 DTLB 接口规格，约 85 个信号，15 个接口组）
> - `doc/L2TLB_Interface.md`（L2 TLB 接口规格，35 个信号，Arbiter⟺L2TLB + PTW⟺L2TLB）

---

### 1. 错误修正

#### 1.1 F5.2 仲裁优先级顺序错误（Critical Fix）

- **错误内容**：F5.2 原描述 `4 源优先级：PTW > L2ReqQ > TLBOper > Prefetch`，顺序有误。
- **正确内容**：`PTW > TLBOper > L2TLB Request Queue > PFU`
- **来源依据**：`doc/L2TLB_Interface.md` §3.3.1 仲裁优先级规格；F3.11/F3.33 已按正确顺序描述。
- **修改位置**：F5.2 描述字段。

#### 1.2 F5.1 优先级描述文本错误

- **错误内容**：F5.1 原描述 `抢占 ReqQ/TLBOPER/Prefetch`，列举顺序与接口规格不一致。
- **正确内容**：`抢占 TLBOper/ReqQ/PFU`，RTL 注释同步修正为 `PTW > TLBOper > ReqQ > PFU`。
- **修改位置**：F5.1 描述字段与 RTL 参考字段。

---

### 2. 规格与 RTL 不一致标注（需设计方确认）

#### 2.1 F2.17 — `mmu_lsu_tlb_wakeup[11:0]` 语义不一致

| 维度 | 内容 |
|------|------|
| 接口规格（L1DTLB_Interfaces.md §2.6.3） | 12 位独热编码，每 bit 对应一个 LSU 操作项，回填完成时拉高对应 bit（per-entry one-hot） |
| RTL 实现（mmu_l1dtlb_install.sv#L233-L235） | 广播信号：`mb_have_free=1` 时全 1（所有 bit 同时拉高） |
| 处理方式 | 在 F2.17 描述中添加 `[v4.0 规格与 RTL 不一致，需设计确认]` 标注，要求设计方明确最终行为语义 |

#### 2.2 F2.18 — `mmu_lsu_tlb_busy` 触发条件不一致

| 维度 | 内容 |
|------|------|
| 接口规格（L1DTLB_Interfaces.md §2.6.3） | Miss Buffer **非空**时触发 busy（非空即拉高） |
| RTL 实现（mmu_l1dtlb.sv#L1229） | 仅在 Miss Buffer **全满**（`&mb_entry_vld`）时触发 |
| 处理方式 | 在 F2.18 描述中添加 `[v4.0 规格与 RTL 不一致，需设计确认]` 标注 |

---

### 3. 新增功能点（8 条）

#### 3.1 F2 侧新增（4 条）

| F-ID | 优先级 | 标题 | 核心内容 | 接口依据 |
|------|--------|------|---------|---------|
| F2.NEW.3 | P1 | `dutlb_xx_mmu_off` MMU 关闭广播 | MMU 关闭时（`regs_mmu_en=0` 或 Machine 模式）L1DTLB 广播状态，通知下游模块；TC：TC-DTLB-MMU-OFF-001；Cov：cg_dtlb_mmu_off, sva_mmu_off_no_req | L1DTLB_Interfaces.md §2.6.3 |
| F2.NEW.4 | P1 | `dutlb_l2tlb_req_is_load` L2TLB 请求 Load 标志 | Miss 请求随 1-bit Load/Store 标志传递，L2TLB 据此实现 Load-before-Store 调度；TC：TC-DTLB-L2-IS-LOAD-001；Cov：cg_l2tlb_req_type | L1DTLB_Interfaces.md §2.3.1 |
| F2.NEW.5 | **P0** | L2TLB 回填双信号语义：`jtlb_dutlb_ref_pavld` vs `jtlb_dutlb_ref_cmplt` | `ref_cmplt=1, pavld=0` 表示 Page Fault；L1DTLB 只释放 MB Entry 不安装 PA；TC：TC-L2REF-CMPLT-NO-PAVLD-001；SVA：sva_l2ref_cmplt_pavld_excl | L1DTLB_Interfaces.md §2.3.2 |
| F2.NEW.6 | **P0** | PTW→L1DTLB 回填双信号语义：`ptw_l1dtlb_ref_pavld` vs `ptw_l1dtlb_ref_cmplt` | `ref_cmplt=1, ref_pavld=0` 表示 PTW 错误（acc_err/pgflt）；L1DTLB 不安装 PA 直接上报异常；TC：TC-PTWREF-CMPLT-ACCERR-001, TC-PTWREF-CMPLT-PGFLT-001；SVA：sva_ptw_ref_pavld_when_no_err | L1DTLB_Interfaces.md §2.4.1 |

#### 3.2 F3 侧新增（4 条）

| F-ID | 优先级 | 标题 | 核心内容 | 接口依据 |
|------|--------|------|---------|---------|
| F3.NEW.2 | P1 | `arb_l2tlb_cmp_with_va` Tag 比较模式控制 | Arbiter 控制 L2TLB Tag 比较时是否使用完整 VA，按页大小（4KB/2MB/1GB）动态切换 VPN 有效比较位宽；TC：TC-L2TLB-CMP-VA-001~003；Cov：cg_l2tlb_cmp_mode, sva_cmp_with_va_per_pgs | L2TLB_Interface.md §3.2 |
| F3.NEW.3 | P1 | `l2tlb_arb_ptw_cmplt` PTW 操作完成通知 Arbiter | PTW Refill 写回后 L2TLB 产生 1 周期脉冲通知 Arbiter 释放资源；TC：TC-L2TLB-PTW-CMPLT-001；SVA：sva_ptw_cmplt_after_refill | L2TLB_Interface.md §3.1 |
| F3.NEW.4 | **P0** | PTW→L2TLB 回填双信号语义：`ptw_l2tlb_ref_cmplt` vs `ptw_l2tlb_ref_data_vld` | `ref_cmplt=1, ref_data_vld=0` 表示 Walk 完成但有错误（pgflt/acc_err）；L2TLB 仅释放 MB Entry 不写 Tag/Data；TC：TC-PTW-L2REF-NOVALID-001；SVA：sva_ptw_l2tlb_ref_cmplt_vld_legal | L2TLB_Interface.md §4.2 |
| F3.NEW.5 | **P0** | `l2tlb_ptw_id` 复合 ID 端到端完整性追踪 | 复合 ID = [L1EID \| L2EID]；PTW 完成后原样返回，L2TLB 用 L2EID 释放自身 MB Entry，用 L1EID 触发 L1DTLB 重查；多并发 Miss 时 ID 不交叉污染；TC：TC-L2PTW-ID-CHAIN-001, TC-L2PTW-ID-MULTI-MISS-001；SVA：sva_l2ptw_id_integrity | L2TLB_Interface.md §4.1/§4.2 |

**优先级汇总**：P0 共 4 条（F2.NEW.5, F2.NEW.6, F3.NEW.4, F3.NEW.5），P1 共 4 条。

---

### 4. 描述完善（6 条）

| F-ID | 完善内容 | 信息来源 |
|------|---------|---------|
| F2.3 | 新增 `credit_return` 接口说明：1-bit 脉冲信号（L2TLB 释放 credit 时拉高一拍）；L1DTLB 内部维护 3-bit 信用计数器跟踪可发送请求数量 | L1DTLB_Interfaces.md §2.3.1 |
| F2.12 | 新增 `jtlb_utlb_ref_pgs[2:0]` 说明：L2TLB 回填时携带 3-bit 页面大小编码（4KB/2MB/1GB），L1DTLB 据此存储正确页大小标识 | L1DTLB_Interfaces.md §2.3.2 |
| F3.4 | 新增 Tag 写入宽度说明：`arb_l2tlb_tag_din[47:0]`（48 bit），字段含 VPN、ASID、有效位、页大小标志 | L2TLB_Interface.md §3.2 |
| F3.5 | 新增 Data 写入宽度说明：`arb_l2tlb_data_din[41:0]`（42 bit），含 PPN 及权限/属性位 | L2TLB_Interface.md §3.2 |
| F3.12 | 新增 RRPV roundtrip 路径说明：L2TLB→Arbiter（`rrpv_updata[WAY_NUM×RRPV_WIDTH-1:0]`）→ L2TLB（`arb_l2tlb_rrpv_din`）；需验证此路径时序正确性及 wbuf 中间态一致性 | L2TLB_Interface.md §3.1/§3.2 |
| F3.13 | 新增复合 ID 语义说明：`l2tlb_ptw_id[L1EID_WIDTH+L2EID_WIDTH-1:0]` 高位=L1EID，低位=L2EID；通过 `ptw_l2tlb_ref_id` 原样返回并双向路由到 L1DTLB/L2TLB MB Entry | L2TLB_Interface.md §4.1/§4.2 |

---

### 5. 接口表补充（§2.3）

#### 5.1 Row 3 信号补充

- **修改位置**：§2.3 外部接口分组表 Row 3（LSU Pipe0/1）
- **新增信号**：`mmu_lsu_sh{0,1}`（Shareable）、`mmu_lsu_so{0,1}`（StrongOrder）、`mmu_lsu_sec{0,1}`（Security/TrustZone）、`mmu_lsu_stall{0,1}`（流水线停顿）
- **来源**：L1DTLB_Interfaces.md §2.2.2/§2.2.4

#### 5.2 Row 15 新增

- **新增行**：`| 15 | L1DTLB 状态广播 | OUT | dutlb_xx_mmu_off | v4.0 新增：L1DTLB 向下游广播 MMU 已关闭状态 |`
- **对应功能点**：F2.NEW.3

---

### 6. 影响分析

| 变更类型 | 数量 | 影响范围 |
|---------|------|---------|
| 错误修正（priority order） | 2 条（F5.1, F5.2） | 仲裁相关 TC 需检查对齐 |
| 规格/RTL 不一致（待确认） | 2 条（F2.17, F2.18） | 需设计方书面确认后更新 TC 期望行为 |
| 新增功能点 | 8 条（4×F2 + 4×F3） | 需新增对应 TC、covergroup、SVA；P0 共 4 条须优先实现 |
| 描述完善 | 6 条 | 不影响 TC 数量，完善现有 TC 约束边界 |
| 接口表补充 | 2 处 | §2.3 Row 3 + Row 15 |

---

### 7. 新增 TC 汇总

| TC-ID | 关联 F-ID | 优先级 | 简述 |
|-------|----------|--------|------|
| TC-DTLB-MMU-OFF-001 | F2.NEW.3 | P1 | MMU 关闭广播信号时序验证 |
| TC-DTLB-L2-IS-LOAD-001 | F2.NEW.4 | P1 | Load/Store 标志随 L2TLB 请求传递 |
| TC-L2REF-CMPLT-NO-PAVLD-001 | F2.NEW.5 | P0 | L2TLB 回填 cmplt=1 pavld=0（Page Fault）路径 |
| TC-PTWREF-CMPLT-ACCERR-001 | F2.NEW.6 | P0 | PTW Access Fault 时 ref_cmplt=1 ref_pavld=0 路径 |
| TC-PTWREF-CMPLT-PGFLT-001 | F2.NEW.6 | P0 | PTW Page Fault 时 ref_cmplt=1 ref_pavld=0 路径 |
| TC-L2TLB-CMP-VA-001/002/003 | F3.NEW.2 | P1 | 三种页大小下 cmp_with_va 控制位正确性 |
| TC-L2TLB-PTW-CMPLT-001 | F3.NEW.3 | P1 | PTW Refill 后 ptw_cmplt 脉冲时序 |
| TC-PTW-L2REF-NOVALID-001 | F3.NEW.4 | P0 | PTW→L2TLB 回填 cmplt=1 data_vld=0（pgflt/acc_err）路径 |
| TC-L2PTW-ID-CHAIN-001 | F3.NEW.5 | P0 | 复合 ID 端到端不变性追踪 |
| TC-L2PTW-ID-MULTI-MISS-001 | F3.NEW.5 | P0 | 多并发 Miss 时复合 ID 不交叉污染 |

---

### 8. 新增 SVA / Covergroup 汇总

| 名称 | 类型 | 关联 F-ID | 描述 |
|------|------|----------|------|
| `sva_mmu_off_no_req` | SVA | F2.NEW.3 | MMU 关闭时 L2TLB 不收到翻译请求 |
| `cg_dtlb_mmu_off` | CG | F2.NEW.3 | MMU on/off 状态覆盖 |
| `cg_l2tlb_req_type` | CG | F2.NEW.4 | Load/Store 请求类型覆盖 |
| `sva_l2ref_cmplt_pavld_excl` | SVA | F2.NEW.5 | `cmplt=0, pavld=1` 非法状态断言 |
| `cg_l2ref_dual_signal` | CG | F2.NEW.5 | L2TLB 回填双信号四种组合覆盖 |
| `sva_ptw_ref_pavld_when_no_err` | SVA | F2.NEW.6 | PTW 无错误时 ref_pavld 必须为 1 |
| `cg_ptw_ref_dual_signal` | CG | F2.NEW.6 | PTW→L1DTLB 回填双信号四种组合覆盖 |
| `sva_cmp_with_va_per_pgs` | SVA | F3.NEW.2 | 不同页大小下 cmp_with_va 正确性 |
| `cg_l2tlb_cmp_mode` | CG | F3.NEW.2 | cmp_with_va=0/1 × 三种页大小覆盖 |
| `sva_ptw_cmplt_after_refill` | SVA | F3.NEW.3 | Refill 写入后次周期 ptw_cmplt=1 |
| `cg_l2tlb_ptw_cmplt` | CG | F3.NEW.3 | ptw_cmplt 脉冲时序覆盖 |
| `sva_ptw_l2tlb_ref_cmplt_vld_legal` | SVA | F3.NEW.4 | `cmplt=0, data_vld=1` 非法状态断言 |
| `cg_ptw_l2ref_dual_signal` | CG | F3.NEW.4 | PTW→L2TLB 回填双信号四种组合覆盖 |
| `sva_l2ptw_id_integrity` | SVA | F3.NEW.5 | 复合 ID 全流程不变性断言 |
| `cg_l2ptw_id_coverage` | CG | F3.NEW.5 | ID 路由与多并发 Miss 场景覆盖 |

---

## v5.0 - MMU/PTW 接口补全变更记录

> 原标题：MMU_VerificationPlan v5.0 — 变更记录
> 原始来源：`../archive_merged_20260607/plan/plan_v5.md`


> **基准版本**：v4.0（接口规格对齐 L1DTLB + L2TLB）
> **升级依据**：`doc/MMU_Interfaces.md`（完整 MMU 系统接口，含 CP0/IFU/LSU/PMP/RTU/HPCP 等）+ `doc/MMU_PTW_Interface.md`（PTW 模块接口，含 PTW 顶层/TWU/MBUF/PDE Cache）
> **修改文件**：`lc_test_plan_doc/MMU_VerificationPlan_v3.md`
> **日期**：2026-04-22

---

### 一、§2.3 接口表修改（5 处 Row 级补全）

#### 1.1 Row 1（CP0/CSR）— 补充 MMU→CP0 响应信号

**问题**：原文使用 `mmu_cp0_*` 通配符，遗漏了 MMU 向 CP0 回传的三路独立响应信号。

**修改内容**：
- 展开 CP0 输入侧 15 个信号（含 `cp0_mmu_ptw_en`、`cp0_mmu_maee`、`cp0_mmu_mxr`、`cp0_mmu_sum`、`cp0_mmu_mpp[1:0]`、`cp0_mmu_mprv`、`cp0_mmu_wdata[63:0]`、`cp0_mmu_wreg`、`cp0_mmu_tlb_all_inv`、`cp0_mmu_satp_sel`、`cp0_mmu_reg_num[1:0]`、`cp0_mmu_cskyee`、`cp0_mmu_icg_en`、`cp0_mmu_no_op_req`、`cp0_yy_priv_mode[1:0]`）
- 补充 MMU→CP0 响应输出三路信号：
  - `mmu_cp0_cmplt`（操作完成脉冲）
  - `mmu_cp0_data[63:0]`（CSR 读出数据，64-bit）
  - `mmu_cp0_satp_data[63:0]`（SATP 寄存器当前值，64-bit）

**来源**：`doc/MMU_Interfaces.md §2.1.2`

---

#### 1.2 Row 3（LSU Pipe0/1）— 补充 Buf/Ca/PageFault/AccessFault 信号

**问题**：v4.0 已补充 sh/so/sec/stall，但 `mmu_lsu_pa{0,1}_*` 通配符仍遗漏 4 路属性信号。

**修改内容**：
- 展开 LSU Pipe0/1 请求侧完整信号（含 `lsu_mmu_va{0,1}[63:0]`（64-bit 完整 VA）、`lsu_mmu_id{0,1}[6:0]`（7-bit 请求 ID）等）
- 补充 MMU→LSU Pipe0/1 响应输出 4 路新信号：
  - `mmu_lsu_buf{0,1}`（Bufferable 属性）
  - `mmu_lsu_ca{0,1}`（Cacheable 属性）
  - `mmu_lsu_page_fault{0,1}`（Page Fault，页表异常）
  - `mmu_lsu_access_fault{0,1}`（Access Fault，PMP 检查失败或总线错误）

**来源**：`doc/MMU_Interfaces.md §2.3.2 / §2.3.4`

---

#### 1.3 Row 4（LSU Pipe2 prefetch）— 展开 `pa2_*` 通配符

**问题**：原文 `mmu_lsu_pa2_*` 通配符遗漏了两个独立信号，且信号名 `mmu_lsu_share2` 与 Pipe0/1 的 `sh0/sh1` 命名规则不同，易混淆。

**修改内容**：
- 展开为具名信号列表：`mmu_lsu_pa2_vld`、`mmu_lsu_pa2[27:0]`、`mmu_lsu_sec2`
- 新增：
  - `mmu_lsu_pa2_err`（翻译错误合并指示：Page Fault 或 Access Fault）
  - `mmu_lsu_share2`（Shareable 属性；**注意**：此信号名为 `share2` 而非 `sh2`，与 Pipe0/1 的 `sh{0,1}` 命名规则不一致）

**来源**：`doc/MMU_Interfaces.md §2.3.5`

---

#### 1.4 Row 7（LSU Data / PTW 取 PTE 通道）— 补注 `data_req_size` 语义

**问题**：
1. 信号列表中 `mmu_lsu_data_req/addr/size` 用斜杠缩写，未标注 size 语义。
2. `mmu_lsu_wakeup[11:0]` 信号名缺少 `_tlb_` 中缀（应为 `mmu_lsu_tlb_wakeup[11:0]`）。

**修改内容**：
- 展开信号列表为：`mmu_lsu_data_req`、`mmu_lsu_data_req_addr[39:0]`（40-bit PA）、`mmu_lsu_data_req_size`（**1-bit：0=32-bit / 1=64-bit**）、`lsu_mmu_data[63:0]`、`lsu_mmu_data_vld`、`lsu_mmu_bus_error`、`mmu_lsu_tlb_busy`、`mmu_lsu_tlb_wakeup[11:0]`、`mmu_lsu_mmu_en`
- 在描述末尾追加 v5.0 补注：`mmu_lsu_data_req_size` 为 1-bit（0=32-bit 请求，1=64-bit 请求）
- 修正 `mmu_lsu_wakeup[11:0]` → `mmu_lsu_tlb_wakeup[11:0]`（补全 `_tlb_` 中缀）

**来源**：`doc/MMU_Interfaces.md §2.3.8`

---

#### 1.5 Row 8（PMP）— 补充端口功能分配注释

**问题**：原文 `mmu_pmp_pa{0-7}` 通配符未注明各端口的功能映射，验证时无法确认 LSU/IFU/PTW 的对应关系。

**修改内容**：
- 展开输入标志：`pmp_mmu_flg{0-7}[3:0]`，注明 bit[0]=R，bit[1]=W，bit[2]=X，bit[3]=L（锁定）
- 展开 PA 输出端口功能分配：
  - `mmu_pmp_pa0` = LSU Pipe 0
  - `mmu_pmp_pa1` = LSU Pipe 1
  - `mmu_pmp_pa2` = LSU Pipe 2（预取）
  - `mmu_pmp_pa3` = IFU 取指
  - `mmu_pmp_pa4-7` = PTW 扩展（`mmu_pmp_pa7`/`mmu_pmp_fetch7` 为 PTW 第四扩展端口）
- 注：`mmu_pmp_fetch4` 已注释掉（F7.NEW.1，v2.0 注记）

**⚠ 设计待确认（标注 [需设计确认]）**：
> `MMU_Interfaces.md §2.4.2` 显示 pa3=IFU 取指；而 `MMU_PTW_Interface.md` 显示 PTW 使用端口 3/5/6/7（而非 4/5/6/7）。两份文档存在出入，需设计方给出最终端口分配表。

**来源**：`doc/MMU_Interfaces.md §2.4.2` + `doc/MMU_PTW_Interface.md`

---

### 二、§2.3 接口注记追加（v5.0 段落）

在原 `v3.0 接口补充` 注记之后追加 `v5.0 接口补充` 段落，汇总以下内容：
1. CP0 响应三路信号补全（来源 §2.1.2）
2. LSU Pipe0/1 响应属性补全（来源 §2.3.2/§2.3.4）
3. LSU Pipe2 通配符展开（来源 §2.3.5）
4. `mmu_lsu_data_req_size` 语义（1-bit，0=32b/1=64b，来源 §2.3.8）
5. PMP 端口功能分配（pa0=LSU Pipe 0, pa1=LSU Pipe 1, pa2=LSU Pipe 2, pa3=IFU, pa4-7=PTW，来源 §2.4.2；含 `[需设计确认]` 注记）
6. RTU 接口确认（`rtu_mmu_bad_vpn[26:0]`/`rtu_mmu_expt_vld`/`rtu_yy_xx_flush`，来源 §2.5）
7. HPCP 接口确认（`mmu_hpcp_dutlb/iutlb/jtlb_miss` 为单周期脉冲，来源 §2.6）

---

### 三、现有功能点修订（2 处）

#### 3.1 F4.6 — `twu_xbar_mask` 接口名澄清

**修改位置**：F4.6 描述字段末尾（追加在 `twu_mask 与 MBUF 满无关` 之后）

**修改内容**：
- 澄清 RTL 内部 wire `twu_mask` 的对外接口规格端口名为 `twu_xbar_mask`（TWU 向 xbar 输出的自阻塞掩码），两者对应关系明确
- 说明 `twu_idle`（TWU 完全空闲，6 级流水全空、CSR FSM 为 IDLE）与 `!twu_xbar_mask`（仅表示当前不阻塞）**语义不等价**，交叉引用 F4.NEW.7
- 补充：4 个 TWU 全部 `twu_xbar_mask=1` 时 `ptw_l2tlb_ready` 拉低，交叉引用 F4.NEW.6
- RTL 注记列更新：`twu.sv:output twu_mask（接口规格对外名 twu_xbar_mask）`

**来源**：`doc/MMU_PTW_Interface.md`

---

#### 3.2 F4.52 — `twu_xbar_mask` 接口名 + `ptw_l2tlb_ready` 交叉引用

**修改位置**：F4.52 描述字段末尾（追加在 `mask 解除 → 轮转指针正确恢复` 之后）

**修改内容**：
1. 接口规格文档中 `twu_mask` 对外端口名为 `twu_xbar_mask`，RTL 内部 wire 为 `twu_mask`
2. 当 4 个 TWU 全部 `twu_xbar_mask=1` 时，`ptw_l2tlb_ready` 拉低（交叉引用 F4.NEW.6）
3. 四路全停等待时 `twu_req_point_r` 指针不复位（防冷启动偏向，交叉引用 F5.NEW.3）
4. `twu_idle`（完全空闲）与 `!twu_xbar_mask`（未阻塞）语义不等价（交叉引用 F4.NEW.7）

**来源**：`doc/MMU_PTW_Interface.md`

---

### 四、新增功能点（7 条）

#### F4.NEW.6（P0）— `ptw_l2tlb_ready` PTW→L2TLB 反压机制

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P0 |
| **RTL 参考** | ptw.sv, twu.sv, one_to_four_xbar.sv |
| **TC** | TC-PTW-READY-001/002/003 |
| **覆盖组** | sva_ptw_l2tlb_ready_when_all_mask, cg_ptw_ready_transition |

**描述**：  
PTW 向 L2TLB 暴露 `ptw_l2tlb_ready` 反压信号。当且仅当 4 个 TWU 的 `twu_xbar_mask` 全部为高时，`ptw_l2tlb_ready` 拉低，通知 L2TLB 暂停发送新的 PTW 请求（`jtlb_ptw_req`）；任意一路 TWU 退出阻塞态则恢复高电平。

**验证关注点**：
1. 全部 4 TWU 同时 mask=1 时，ready 在同周期或下一周期拉低（不得延迟两拍以上）
2. 只要有任意一路 TWU mask=0，ready 保持高电平
3. L2TLB 在 ready=0 时不发送新请求（协议约束）
4. ready 拉低期间已接受的 outstanding 请求继续完成，不应被撤销

---

#### F4.NEW.7（P1）— `twu_idle` 与 `twu_xbar_mask` 语义区分

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv, ptw.sv |
| **TC** | TC-TWU-IDLE-MASK-001 |
| **覆盖组** | sva_twu_idle_implies_no_mask, cg_twu_idle_vs_mask_state |

**描述**：  
- `twu_idle`：TWU 完全空闲（6 级流水全空、MBUF 无在途请求、CSR FSM 为 IDLE，即 `twu_busy=0`）  
- `twu_xbar_mask`（对应 RTL wire `twu_mask`）：当前流水线阻塞，无法接受新 xbar 派发的 PDE 请求

**逻辑关系**：`twu_idle=1` 蕴含 `twu_xbar_mask=0`，但反之不成立（TWU 可有在途请求但仍可接收新派发）。

**验证关注点**：
1. 断言 `twu_idle=1` 时 `twu_xbar_mask` 必须为 0
2. TWU 处于"有在途请求但未 mask"状态下，xbar 仍可派发新 PDE 请求
3. `ptw_l2tlb_ready` 计算应基于 `twu_xbar_mask`，而非 `twu_idle`

---

#### F4.NEW.8（P1）— `xbar_twu_hit_level[2:0]` PDE Cache 命中级别编码

| 属性 | 内容 |
|------|------|
| **模块** | `one_to_four_xbar` + PDE Cache |
| **优先级** | P1 |
| **RTL 参考** | L1PDE_cache.sv, L2PDE_cache.sv, PDE_cache.sv, one_to_four_xbar.sv, twu.sv |
| **TC** | TC-PDE-CACHE-HIT-L3-001, TC-PDE-CACHE-HIT-L2-001, TC-PDE-CACHE-MISS-001 |
| **覆盖组** | cg_xbar_hit_level, sva_twu_skip_stage_on_hit |

**描述**：  
xbar 向被派发 TWU 传送 3-bit 命中级别 `xbar_twu_hit_level[2:0]` = `{L3PDE_hit_vld, L2PDE_hit_vld, L1PDE_hit_vld}`，决定 TWU 流水线入口：
- `3'b100`（L3PDE 命中）→ 直接进入 THD_PMP 阶段
- `3'b010`（L2PDE 命中）→ 进入 SCD_PMP 阶段  
- `3'b001` 或 `3'b000`（L1PDE 命中/全 Miss）→ 进入 FST_PMP 阶段

新增信号补充：`PDE_xbar_bank_sel[2:0]`（命中时的 bank 选择，用于多路 PDE Cache 组织）。

**验证关注点**：
1. 三种命中场景下 TWU 正确跳过对应级别 PMP 检查
2. `PDE_xbar_bank_sel` 正确路由 PDE 数据到对应 bank
3. 全 Miss 时 TWU 正常启动完整三级 PTW
4. PDE Cache 命中数据无 stale 污染（与 F4.38/F4.39 交叉）

---

#### F4.NEW.9（P0）— TWU→L2TLB 异常直通旁路路径

| 属性 | 内容 |
|------|------|
| **模块** | `twu` → `mmu_l2tlb` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv, mmu_l2tlb.sv |
| **TC** | TC-TWU-PGFLT-BYPASS-001, TC-TWU-ACCERR-BYPASS-001, TC-TWU-EXCEPT-CONFLICT-001 |
| **覆盖组** | sva_twu_except_bypasses_arb, sva_twu_pgflt_acc_mutex, cg_twu_except_while_arb_busy |

**描述**：  
TWU 发现页表遍历异常时，**异常通知直接从 TWU 发往 L2TLB，绕过 mmu_arb**，无需争用 Arbiter 总线。

两类独立异常直通路径：
- **（A）Page Fault 路径**：`twu_jtlb_ref_pgflt` + `twu_jtlb_ref_pgflt_id[6:0]` + `twu_jtlb_ref_pgflt_type[2:0]`
- **（B）Access Error 路径**：`twu_jtlb_ref_acc_err` + `twu_jtlb_ref_acc_err_id[6:0]` + `twu_jtlb_ref_acc_err_type[2:0]`

对比：正常 PTE 回填走 TWU→Arbiter→L2TLB；异常通知直连 TWU→L2TLB。

**验证关注点**：
1. Arbiter 被其他 TWU 占用时，本 TWU 产生异常 → 异常通知即时（同周期或下一周期）到达 L2TLB
2. 正常回填信号与异常通知信号同时有效时，L2TLB 接收方仲裁逻辑正确
3. `twu_jtlb_ref_acc_err` 与 `twu_jtlb_ref_pgflt` 的互斥性（同一次遍历不能同时报两种异常）
4. 异常后对应 miss entry 及时释放，无 miss buffer 泄漏（与 F4.48 交叉）

---

#### F4.NEW.10（P1）— `twu_data_ready[2:0]` MBUF→TWU 数据分发门控

| 属性 | 内容 |
|------|------|
| **模块** | `twu` ↔ MBUF |
| **优先级** | P1 |
| **RTL 参考** | ptw_mbuf.sv, twu.sv, mbuf_entry.sv |
| **TC** | TC-MBUF-READY-GATE-001, TC-MBUF-HAVE-001, TC-MBUF-MULTI-TWU-READY-001 |
| **覆盖组** | sva_mbuf_waits_twu_ready, cg_twu_data_ready_per_stage, sva_mbuf_have_no_resend |

**描述**：  
MBUF 从 LSU 收到 PTE 数据后，等待 TWU 侧 `twu_data_ready[2:0]` 就绪信号再分发：
- bit[0]：FST_PMP 级就绪（等待 L2 PDE 读结果）
- bit[1]：SCD_PMP 级就绪（等待 L1 PDE 读结果）
- bit[2]：THD_PMP 级就绪（等待 L0 叶 PTE 读结果）

另有 `mbuf_twu_have`：MBUF 已有对应 VPN 缓存时通知 TWU 无需重发 LSU 请求（与 F4.36 去重交叉）。

**验证关注点**：
1. `twu_data_ready` 对应 bit=0 时 MBUF 不提前发出 `mbuf_twu_data_vld`
2. TWU 流水线流速与 MBUF 分发时序一致（无空泡、无数据竞争）
3. `mbuf_twu_have=1` 时 TWU 不重发 LSU 请求
4. 多 TWU 共享同一 MBUF entry 时，各 TWU `twu_data_ready` 独立控制接收时刻

---

#### F4.NEW.11（P1）— Arbiter→TWU 三通道 grant 仲裁

| 属性 | 内容 |
|------|------|
| **模块** | `mmu_arb` → `twu` |
| **优先级** | P1 |
| **RTL 参考** | mmu_arb.sv, twu.sv, mmu_l2tlb.sv |
| **TC** | TC-ARB-GRANT-ONEHOT-001, TC-ARB-REFILL-EXCEPT-PRIO-001, TC-ARB-MULTI-TWU-FAIRNESS-001 |
| **覆盖组** | sva_arb_twu_grant_onehot, cg_arb_grant_type, sva_twu_din_stable_on_grant |

**描述**：  
Arbiter 向 TWU 发送三类独立 grant 信号（非单一总线）：
- **`refill_arb_twu_grant`**：正常 PTE 回填授权，允许 TWU 写 L2TLB SRAM
- **`acc_err_twu_grant`**：访问错误通知授权
- **`pgflt_twu_grant`**：Page Fault 通知授权

三路 grant 同周期最多一路有效（one-hot）。

TWU→Arbiter 请求信号：`twu_arb_ref_req`、`twu_arb_ref_type[2:0]`、`twu_arb_ref_data_din`、`twu_arb_ref_tag_din`、`twu_arb_ref_pgs[2:0]`、`twu_arb_ref_id[6:0]`。

**验证关注点**：
1. 三路 grant 同周期 one-hot（断言 `refill + acc_err + pgflt ≤ 1`）
2. 多 TWU 同时 refill 请求时，Arbiter round-robin 调度，不能饿死任何 TWU
3. exception grant 与 refill grant 的相对优先级
4. grant 回来时 TWU din 数据稳定（与 F5.NEW.2 双级流水 reset 竞争交叉）

---

#### F5.16（P1）— `ptw_arb_ref_vpn` PTW→Arbiter 独立 VPN 字段

| 属性 | 内容 |
|------|------|
| **模块** | `mmu_arb` |
| **优先级** | P1 |
| **RTL 参考** | mmu_arb.sv, ptw.sv |
| **TC** | TC-ARB-VPN-MATCH-001, TC-ARB-PGS-MATCH-001 |
| **覆盖组** | sva_ptw_arb_vpn_matches_tag, cg_ptw_arb_pgs_type |

**描述**：  
PTW 向 Arbiter 发起 L2TLB 回填请求时，除 `ptw_arb_data_din` 和 `ptw_arb_tag_din` 外，还单独传递 `ptw_arb_ref_vpn`（VPN 独立字段，用于 Arbiter 端 skew hash/bank 选择，避免 Arbiter 解包 tag_din 产生额外时序路径延长）。

完整 PTW→Arbiter 信号集：
- `ptw_arb_req`（请求有效）
- `ptw_arb_data_din`（data SRAM 写入数据）
- `ptw_arb_tag_din`（tag SRAM 写入数据）
- `ptw_arb_pgs[2:0]`（页大小：4K/2M/1G 编码，与 F2.12 一致）
- `ptw_arb_ref_vpn`（独立 VPN 字段）

**验证关注点**：
1. `ptw_arb_ref_vpn` 与 `ptw_arb_tag_din` 中编码的 VPN 字段位对位一致性（防不一致导致写错 bank）
2. `ptw_arb_pgs` 与 `ptw_arb_data_din` 中叶 PTE 编码页类型一致性
3. `arb_ptw_grant` 回来时三路 din 信号在一拍内稳定驱动（与 F5.NEW.2 交叉）

---

### 五、设计待确认事项

#### DA-001（P0）— PMP 端口 3 分配冲突

| 项目 | 内容 |
|------|------|
| **涉及功能点** | §2.3 Row 8, F7 section |
| **问题描述** | `MMU_Interfaces.md §2.4.2` 显示 pa3=IFU 取指；而 `MMU_PTW_Interface.md` 显示 PTW 使用 PMP 输入端口 3/5/6 和输出端口 3/5/6/7（而非 4/5/6/7）。两份文档的 PMP 端口 3 分配存在出入。 |
| **影响范围** | 如果 pa3=PTW（而非 IFU），则 IFU PMP 检查端口编号需重新确认，影响 F7 系统侧 PMP 功能点的验证约束。 |
| **建议** | 设计方给出最终端口分配表（Port 0~7 的功能归属）；暂时在 §2.3 Row 8 中标注 `[需设计确认]`。 |

#### DA-002（P1）— `jtlb_ptw_id[6:0]` 与复合 ID 宽度

| 项目 | 内容 |
|------|------|
| **涉及功能点** | F3.NEW.5 |
| **问题描述** | `MMU_PTW_Interface.md` 显示 `jtlb_ptw_id[6:0]` 为 7-bit 单字段；而 v4.0 F3.NEW.5 描述了 `l2tlb_ptw_id[L1EID_WIDTH+L2EID_WIDTH-1:0]` 复合 ID。7-bit 可能是复合 ID 的总宽度（如 4b L1EID + 3b L2EID = 7b）。 |
| **建议** | 设计方确认 `jtlb_ptw_id` 的 bit 字段划分；F3.NEW.5 现有描述保留，补注总线宽度为 7-bit。 |

---

### 六、修改统计

| 类别 | 数量 |
|------|------|
| §2.3 接口表 Row 级修改 | 5 处 |
| §2.3 注记追加 | 1 处（v5.0 段落）|
| 现有功能点修订（F4.6/F4.52） | 2 处 |
| 新增功能点（F4.NEW.6-11 + F5.16） | 7 条 |
| 新增 TC | 16 条（TC-PTW-READY-001~003, TC-TWU-IDLE-MASK-001, TC-PDE-CACHE-HIT-L3/L2/MISS, TC-TWU-PGFLT-BYPASS-001, TC-TWU-ACCERR-BYPASS-001, TC-TWU-EXCEPT-CONFLICT-001, TC-MBUF-READY-GATE-001, TC-MBUF-HAVE-001, TC-MBUF-MULTI-TWU-READY-001, TC-ARB-GRANT-ONEHOT-001, TC-ARB-REFILL-EXCEPT-PRIO-001, TC-ARB-MULTI-TWU-FAIRNESS-001, TC-ARB-VPN-MATCH-001, TC-ARB-PGS-MATCH-001）|
| 新增 SVA / 覆盖组 | 14 条 |
| 设计待确认项 | 2 项（DA-001/DA-002）|

---

## v6.0 - PMP/sysmap/PTW 深化变更记录

> 原标题：MMU_VerificationPlan v6.0 — 变更记录
> 原始来源：`../archive_merged_20260607/plan/plan_v6.md`


> **基准版本**：v5.0（MMU_Interfaces.md + MMU_PTW_Interface.md 接口对齐）
> **升级依据**：
> - `doc/MMU_Interfaces.md`（MMU 系统完整接口，含 PMP/sysmap 端口映射）
> - 用户补充说明 ①：**PMP 检查是 PTW 每次发 LSU 请求的前提**——PTW 必须先完成 PMP 权限检查，通过后才允许向 LSU 发出 PTE 加载请求。
> - 用户补充说明 ②：**sysmap 用于 PTW 模块的 CSR 属性获取**——MAEE=1 时直接使用页表数据中的属性字段，MAEE=0 时需通过 sysmap 查询 PA 所在内存区域（8 个区域之一）的默认属性；若 PA 跨越内存划分边界则强制页大小降级。
> - RTL 精读：`mmu/rtl/twu.sv`、`mmu/rtl/ptw.sv`、`mmu/rtl/ct_mmu_sysmap.v`、`mmu/rtl/sysmap.h`
>
> **修改文件**：`lc_test_plan_doc/MMU_VerificationPlan_v3.md`
> **日期**：2026-04-22

---

### 一、§2.3 接口表修改（Row 8 PMP 补注）

#### 1.1 Row 8（PMP）— v6.0 补注：PTW 端口映射精化 + RTL typo 标注

**修改位置**：§2.3 Row 8 "作用" 列末尾（在 v5.0 [需设计确认] 注记之后追加）

**修改内容**：

- **PTW TWU 端口映射精化**（来自 RTL ptw.sv 精读）：
  - `mmu_pmp_pa3` / `pmp_mmu_flg3` → **twu_one**（ptw.sv:L291/L300）
  - `mmu_pmp_pa5` / `pmp_mmu_flg5` → **twu_two**（ptw.sv:L344/L353）
  - `mmu_pmp_pa6` / `pmp_mmu_flg6` → **twu_three**（ptw.sv:L397/L406）
  - `mmu_pmp_pa7` / `pmp_mmu_flg7` → **twu_four**（ptw.sv:L450/L459）
  - 端口号为 **3/5/6/7**（非 4/5/6/7），与 v5.0 注记中的 `pa4-7` 存在不一致，保留 `[需设计确认]` 标注

- **PTW PMP fetch 信号恒为 0**：PTW 读页表属于数据 Load，`mmu_pmp_fecth{3,5,6,7}` 对所有 PTW 端口恒为 0，PMP 使用 R-bit（flg[0]）检查；`mmu_pmp_fetch4` 已注释掉（v2.0 注记保留）

- **RTL 拼写 typo 标注**：`ptw.sv:L62` 端口名为 `mmu_pmp_fecth7`（缺少字母 `c`），其他端口 `mmu_pmp_fetch3/5/6` 拼写正确；testbench 接口绑定必须使用 typo 名称（详见 F7.NEW.8）

- **PMP 前置约束引用**：PTW 在 PMP 检查通过前不得向 LSU 发请求（详见 F7.NEW.3）

**来源**：`mmu/rtl/ptw.sv:L52-64`，用户补充说明 ①

---

#### 1.2 §2.3 v6.0 接口补充段落

在 §2.3 接口表之后（v5.0 接口补充注记之后）追加 **v6.0 接口补充** 说明段落，内容如下：

1. **MAEE 双路选路**：`cp0_mmu_maee=1` → TWU 使用 PTE 扩展属性字段（`fst_chk_refill_req`），跳过 CSR FSM；`cp0_mmu_maee=0` → 进入 CSR FSM，通过 sysmap 获取默认内存区域属性（`fst_chk_csr_req`）（来自 twu.sv:L413/L424/L553/L560）

2. **sysmap CSR 属性替换**：MAEE=0 时，sysmap 返回的 `sysmap_mmu_flg[4:0]` 替换 CSR refill data 中 PTE 的 flag 字段（bit[60:56]），5-bit 编码：Sec/So/Buf/Ca/Sh（来自 twu.sv:L1086 + sysmap.h）

3. **PMP 前置于 LSU 请求**：TWU 每级（FST/SCD/THD）在发现叶 PTE 后，先发 PMP 检查请求，等 PMP 检查通过（`!pmp_deny`）后才允许下一步 LSU 请求；PMP deny → 直接 Access Fault，不发 LSU（来自 twu.sv:L243-246/L372-376/L961-964）

4. **sysmap 跨界检测**：CSR FSM 内 CRS1 阶段捕获大页起始地址 hit 向量（`twu_hit_num`），CRS2 阶段比较末尾地址 hit 向量；两次 hit 不同 → `twu_csr_cross=1` → 强制页大小降级（1G→2M 或 2M→4K）（来自 twu.sv:L1040-1055）

5. **PTW PMP 端口分配**：4 TWU 各独立 PMP 端口（pa3/5/6/7），`mmu_pmp_fecth7` RTL 拼写 typo 记录（来自 ptw.sv:L62；testbench 绑定必须使用 typo 名）

---

### 二、新增功能点——F4 侧（3 条）

#### F4.NEW.12（P0）— TWU MAEE 双路属性选路

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L413, L424, L553, L560 |
| **TC** | TC-TWU-MAEE0-CSR-001, TC-TWU-MAEE0-CSR-002, TC-TWU-MAEE1-REFILL-001, TC-TWU-MAEE-SWITCH-001 |
| **SVA / 覆盖组** | sva_twu_maee_paths_mutex, cg_maee_leaf_level |

**描述**：

TWU 发现叶 PTE 时，根据 `cp0_mmu_maee` 单 bit 决定属性来源路径，两路互斥：

- **（A）MAEE=1 路径（扩展属性使能）**：触发 `fst_chk_refill_req = fst_chk_vld & fst_chk_leaf_vld & cp0_mmu_maee & (!fst_chk_page_flt)`（twu.sv:L413），直接使用 PTE 中的扩展属性字段（bit[63:8]）进行回填，**跳过 CSR FSM** 与 sysmap 查询。

- **（B）MAEE=0 路径（默认内存区域属性）**：触发 `fst_chk_csr_req = fst_chk_vld & fst_chk_leaf_vld & (!cp0_mmu_maee) & (!fst_chk_page_flt)`（twu.sv:L424），进入 CSR FSM（IDLE → 1G_CRS1 → 1G_CRS2 → ... → CSR_DATA_VLD），查询 sysmap 区域属性，用 `sysmap_mmu_flg[4:0]` 替换回填数据中的 flag 字段（见 F6.NEW.2）。

SCD/THD 级对称（twu.sv:L553/L560）。

**验证关注点**：
1. MAEE=1 时 `fst_chk_csr_req` 必须为 0（断言互斥）
2. MAEE=0 时 `fst_chk_refill_req` 必须为 0
3. 动态切换 MAEE：翻译途中切换 MAEE 不得导致属性乱序（依赖 CSR 写序列化）
4. MAEE=1 时 SCD/THD 级同样对称跳过 CSR FSM（交叉 F4.28 CSR FSM）

---

#### F4.NEW.13（P0）— PMP 三级序列化检查——PTW 发 LSU 请求的前提

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L243-246, L961-964, L1001-1014 |
| **TC** | TC-TWU-PMP-SERIAL-001, TC-TWU-PMP-WAIT-STALL-001, TC-PTW-PMP-BEFORE-LSU-001, TC-PTW-PMP-DENY-STOP-REQ-001 |
| **SVA / 覆盖组** | sva_pmp_check_before_lsu_req, sva_pmp_deny_no_refill, cg_pmp_per_level_result |

**描述**：

TWU 每级（FST/SCD/THD）发现叶 PTE 时必须先发起 PMP 权限检查；同一 TWU 只有一个 PMP 端口，三级通过 `pmp_grant[2:0]` one-hot 分时复用（见 F4.NEW.14）。

**关键约束**：`fst_pmp_wait / scd_pmp_wait / thd_pmp_wait` 在 PMP 检查返回前阻塞对应流水级，且 `twu_mask = fst_pmp_wait | scd_pmp_wait | thd_pmp_wait | ...`（twu.sv:L243-246）——PMP 等待期间 TWU 整体阻塞。

**与 LSU 请求的顺序关系**：`mmu_lsu_data_req`（PTW 向 LSU 请求 PTE 加载）只能在当前级 PMP 检查**通过**（`!pmp_deny`）后才允许推进；PMP deny 时直接报 Access Fault（`twu_jtlb_ref_acc_err`），不发 LSU 请求（见 F7.NEW.3/F7.NEW.5）。

**验证关注点**：
1. FST 级 PMP deny 时，不得出现后续 SCD/THD 的 LSU 请求
2. 三级序列化顺序：FST PMP 完成 → SCD PMP → THD PMP，不得乱序
3. PMP wait 期间 `twu_mask=1`，xbar 不派发新请求（交叉 F4.NEW.6/F7.NEW.6）
4. PMP 检查通过后的 MBUF 请求时序（交叉 F4.NEW.10）

---

#### F4.NEW.14（P1）— `pmp_grant[2:0]` one-hot 仲裁控制 `mmu_pmp_pa` 多路选择

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv:L1001-1014 |
| **TC** | TC-TWU-PMP-GRANT-ONEHOT-001, TC-PTW-PMP-PA-1G-001, TC-PTW-PMP-PA-2M-001, TC-PTW-PMP-PA-4K-001 |
| **SVA / 覆盖组** | sva_pmp_grant_onehot, cg_pmp_grant_level |

**描述**：

TWU 内部 `pmp_grant[2:0]` 为 one-hot 信号，控制向 PMP 模块发出的物理地址 `mmu_pmp_pa[27:0]` 的多路选择（twu.sv:L1001-1014）：

| pmp_grant | 页级 | mmu_pmp_pa 格式 |
|-----------|------|-----------------|
| `3'b100` | FST / 1G 叶 | `{satp_ppn[27:0], fst_pmp_vpn[26:18], 3'b0}`（1G 对齐，低 18 bit = 0） |
| `3'b010` | SCD / 2M 叶 | `{scd_pmp_ppn[27:0], scd_pmp_vpn[17:9], 3'b0}`（2M 对齐，低 9 bit = 0） |
| `3'b001` | THD / 4K 叶 | `{thd_pmp_ppn[27:0], thd_pmp_vpn[8:0], 3'b0}`（4K 对齐，全 28 bit 有效） |
| `3'b000` | 无有效请求 | 全零 |

`mmu_pmp_fecth` 同样受 `pmp_grant` 控制；PTW 数据读恒为 0（见 F7.NEW.7）。

**验证关注点**：
1. `pmp_grant[2:0]` 同周期最多 1 bit 有效（断言 one-hot）
2. 三种页大小 PA 格式位域正确（交叉 F7.NEW.4）
3. grant=3'b000 时 `mmu_pmp_pa` 为全零，不产生误判
4. PMP 模块接收 PA 后，`pmp_mmu_flg[3:0]` 在约定拍数内返回（时序约束，交叉 F7.NEW.3）

---

### 三、新增功能点——F6 侧（7 条）

#### F6.NEW.1（P0）— MAEE 控制 TWU 进入 sysmap CSR 路径还是 PTE 直通路径

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L413, L424, L553, L560; ptw.sv |
| **TC** | TC-SYSMAP-MAEE0-ATTR-001, TC-SYSMAP-MAEE0-ATTR-002, TC-SYSMAP-MAEE1-SKIP-CSR-001 |
| **SVA / 覆盖组** | sva_twu_maee_paths_mutex, cg_maee_path |

**描述**：

当 `cp0_mmu_maee=0`（默认内存区域属性模式）时，TWU 在检测到叶 PTE 后不直接回填，而是触发 CSR FSM 请求（`fst_chk_csr_req`），通过 sysmap 查询 PA 所在的 8 个内存区域中的哪个，并获取该区域的默认属性（`sysmap_mmu_flg[4:0]`）；当 `cp0_mmu_maee=1`（扩展内存属性使能）时，直接使用 PTE 中的属性字段（`fst_chk_refill_req`），CSR FSM 不进入。

**核心意义**：sysmap 是 MAEE=0 时 PTW 叶 PTE 属性的唯一来源，决定最终回填到 TLB 中的内存属性（Cacheable/Bufferable/Shareable/Security/StrongOrder）。

**验证关注点**：
1. `cp0_mmu_maee=0` 时每次叶 PTE 发现都触发 sysmap 查询
2. `cp0_mmu_maee=1` 时 CSR FSM 不进入（`fst_chk_csr_req=0`）
3. 三种叶级别（FST/SCD/THD）分别触发 `fst/scd/thd_chk_csr_req`（对称结构）
4. MAEE 切换后已在飞请求的属性一致性（交叉 F4.NEW.12）

---

#### F6.NEW.2（P0）— `sysmap_mmu_flg[4:0]` 替换 CSR refill data 中的 flag 字段

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1086; sysmap.h |
| **TC** | TC-SYSMAP-FLG-REFILL-001, TC-SYSMAP-FLG-REGION0-001, TC-SYSMAP-FLG-REGION7-001 |
| **SVA / 覆盖组** | cg_sysmap_flg_per_region, sva_csr_refill_flg_matches_sysmap |

**描述**：

MAEE=0 路径（CSR FSM）完成后，TWU 构造回填数据时用 `sysmap_mmu_flg[4:0]` **替换** PTE 中原始属性字段（bit[60:56]）：

```
csr_refill_data = {csr_data_flop[PPN+9:10], sysmap_mmu_flg[4:0], csr_data_flop[9:6], csr_data_flop[4:0]}
```
（twu.sv:L1086）

**sysmap flag 5-bit 编码**（sysmap.h）：

| bit | 含义 | 缩写 |
|-----|------|------|
| bit[4] | Security | Sec |
| bit[3] | StrongOrder | So |
| bit[2] | Bufferable | Buf |
| bit[1] | Cacheable | Ca |
| bit[0] | Shareable | Sh |

**各 region 默认 flag 值**：SYSMAP0/4/5/7 = `5'b01111`；SYSMAP1/2/6 = `5'b10000`；SYSMAP3 = `5'b01101`；无命中默认 = `5'b10011`（见 F6.NEW.7）。

**验证关注点**：
1. TLB 回填后属性字段与 sysmap 对应 region flag 位对位一致
2. MAEE=1 时回填数据**不包含** sysmap flag（由 PTE 原始属性填充）
3. 覆盖 8 个 region 的不同 flag 组合，确认属性正确传播到 IFU/LSU 输出

---

#### F6.NEW.3（P0）— 跨界检测算法——两相 sysmap hit 比较

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1050-1055 |
| **TC** | TC-SYSMAP-CROSS-SAME-001, TC-SYSMAP-CROSS-1G-DIFF-001, TC-SYSMAP-CROSS-2M-DIFF-001, TC-SYSMAP-CROSS-PARTIAL-HIT-001 |
| **SVA / 覆盖组** | sva_sysmap_cross_degrade, cg_sysmap_cross_1g, cg_sysmap_cross_2m |

**描述**：

在 CSR FSM 的两阶段检查（CRS1/CRS2）中，sysmap 分别对大页的**起始地址**和**末尾地址** PA 进行区域查询，通过比较两次 hit 向量判断大页是否跨越内存区域边界：

- **CRS1 阶段**（TWU 状态 `1G_CRS1` 或 `2M_CRS1`）：捕获 `twu_hit_num[7:0] <= sysmap_mmu_hit[7:0]`（大页起始地址所在 region）（twu.sv:L1050-1053）
- **CRS2 阶段**（`1G_CRS2` 或 `2M_CRS2`）：再次查询大页末尾地址，计算 `twu_csr_cross = twu_crs2_chk && (twu_hit_num[7:0] != sysmap_mmu_hit[7:0])`（twu.sv:L1055）——两次 hit 向量不同即跨界

**跨界场景**：1G 页起始在 region A、末尾在 region B（或无命中）→ 跨界 → 触发降级（见 F6.NEW.4）。

**验证关注点**：
1. 不跨界：两次 hit 相同，`twu_csr_cross=0`，页大小保持（交叉 F6.NEW.4）
2. 1G 跨界：hit 不同，`twu_csr_cross=1`，触发 1G→2M 降级
3. 2M 跨界：同样检测，触发 2M→4K 降级
4. 一次 hit 有效一次无命中（无命中→默认 flag），也视为跨界
5. 4K 页不进入 CSR FSM，无需跨界检测（交叉 F4.28）

---

#### F6.NEW.4（P0）— sysmap 跨界触发强制页大小降级

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1040-1048 |
| **TC** | TC-SYSMAP-DEGRADE-1G2M-001, TC-SYSMAP-DEGRADE-2M4K-001, TC-SYSMAP-NO-DEGRADE-1G-001, TC-SYSMAP-NO-DEGRADE-2M-001 |
| **SVA / 覆盖组** | sva_sysmap_cross_degrade, cg_sysmap_degrade_pgs |

**描述**：

跨界检测（见 F6.NEW.3）结果为 `twu_csr_cross=1` 时，TWU 强制降低页大小，以保证整个翻译区域属于同一内存 region（属性一致性约束）。降级逻辑（`csr_refill_pgs[2:0]` 寄存器更新，twu.sv:L1040-1048）：

- **初始赋值**：`csr_refill_pgs = {csr_grant[1:0], 1'b0}`（1G → `3'b100`，2M → `3'b010`）
- **1G 跨界降级**：`if (ptw_crs2_1g && ptw_chk_cross) csr_refill_pgs <= 3'b010`（降为 2M）
- **2M 跨界降级**：`if (ptw_crs2_2m && ptw_chk_cross) csr_refill_pgs <= 3'b001`（降为 4K）
- **不跨界**：维持原页大小

降级后回填到 L2TLB 的 `pgs` 字段使用降级后的值，确保 TLB 命中时覆盖范围不跨 region 边界。

**验证关注点**：
1. 1G 跨界 → 回填 pgs=`3'b010`（2M）而非 `3'b100`（1G）
2. 2M 跨界 → 回填 pgs=`3'b001`（4K）
3. 不跨界 1G/2M → 回填 pgs 保持 `3'b100`/`3'b010`
4. 降级后 PTW 仍使用正确的 PTE 数据（PPN 不变，仅 pgs 降级）
5. 降级次数统计覆盖（与 F4.18 巨页降级交叉）

---

#### F6.NEW.5（P1）— PTW 向 sysmap 发送的 PA 按页级对齐

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv, ptw.sv |
| **TC** | TC-SYSMAP-PA-ALIGN-1G-001, TC-SYSMAP-PA-ALIGN-2M-001, TC-SYSMAP-PA-ALIGN-4K-001 |
| **SVA / 覆盖组** | cg_sysmap_pa_align |

**描述**：

TWU 在 CRS1/CRS2 阶段向 sysmap 发送的物理地址 `mmu_sysmap_pa[27:0]` 根据当前叶级别对齐：

| 叶级别 | PA 对齐 | 低位清零 |
|--------|---------|---------|
| FST（1G 叶） | 1G 对齐 | bit[17:0] = 0 |
| SCD（2M 叶） | 2M 对齐 | bit[8:0] = 0 |
| THD（4K 叶） | 4K 对齐 | 全 28 bit 有效 |

CRS1 发送起始地址，CRS2 发送末尾地址（起始 + 页大小 - 4K），确保跨界检测地址范围完整，不溢出下一个 4K 边界。PA 对齐格式与 PMP PA 一致（交叉 F7.NEW.4）。

**验证关注点**：
1. 1G 页 PA 低 18 bit 恒为 0
2. 2M 页 PA 低 9 bit 恒为 0
3. 4K 页 PA 全 28 bit 有效
4. CRS2 末尾地址正确（不溢出，不越过下一 4K 边界）
5. sysmap PA 与 PMP PA 对齐格式一致（交叉 F7.NEW.4）

---

#### F6.NEW.6（P1）— 4 TWU 实例各自独立 sysmap 端口并发查询

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P1 |
| **RTL 参考** | ptw.sv:L289-290, L342-343, L395-396, L448-449 |
| **TC** | TC-SYSMAP-4TWU-CONCURRENT-001, TC-SYSMAP-TWU-PORT-MAP-001 |
| **SVA / 覆盖组** | cg_sysmap_4twu_concurrent |

**描述**：

`ptw.sv` 中 4 个 TWU 实例分别连接到独立的 sysmap PA/flg/hit 端口：

| TWU 实例 | PA 端口 | flg 端口 | hit 端口 |
|----------|---------|---------|---------|
| twu_one | `mmu_sysmap_pa3` | `sysmap_mmu_flg3` | `sysmap_mmu_hit3` |
| twu_two | `mmu_sysmap_pa5` | `sysmap_mmu_flg5` | `sysmap_mmu_hit5` |
| twu_three | `mmu_sysmap_pa6` | `sysmap_mmu_flg6` | `sysmap_mmu_hit6` |
| twu_four | `mmu_sysmap_pa7` | `sysmap_mmu_flg7` | `sysmap_mmu_hit7` |

端口号为 **3/5/6/7**（非连续，非 4/5/6/7）。4 路完全独立，允许 4 个 TWU 在同一周期各自进行不同 PA 的 sysmap 查询，互不阻塞。

**注意**：sysmap 为纯组合逻辑，4 路查询同周期结果独立有效，无内部仲裁。

**验证关注点**：
1. 4 TWU 同周期并发 sysmap 查询时，各路 hit/flg 独立正确
2. 端口号 3/5/6/7 映射关系正确（TWU one=3，TWU two=5，TWU three=6，TWU four=7）
3. sysmap 实例为纯组合逻辑，4 路查询无冲突（与 F6.NEW.3 跨界检测交叉）

---

#### F6.NEW.7（P2）— sysmap 无命中时默认 flag = `5'b10011`

| 属性 | 内容 |
|------|------|
| **模块** | `ct_mmu_sysmap` |
| **优先级** | P2 |
| **RTL 参考** | ct_mmu_sysmap.v:L155 |
| **TC** | TC-SYSMAP-NO-HIT-DEFAULT-001, TC-SYSMAP-DEFAULT-FLAG-BIT-001 |
| **SVA / 覆盖组** | cg_sysmap_default_flag |

**描述**：

当物理地址 PA 不属于已配置的 8 个 region 中的任何一个时（`casez` default 分支，ct_mmu_sysmap.v:L155），sysmap 返回默认 flag `5'b10011`（Sec=0/So=1/Buf=0/Ca=0/Sh=1，含义：可共享、不可缓存、强排序，保守属性配置）。

此默认值在 MAEE=0 时会被回填到 TLB 属性字段，影响所有未在 sysmap 中配置的物理地址区域的内存属性。

**验证关注点**：
1. PA 落在所有 region 范围外时 `sysmap_mmu_flg = 5'b10011`
2. 所有 8 个 sysmap hit 均为 0 时 `sysmap_mmu_hit[7:0] = 8'b0`（与 F6.3 hit 唯一性交叉）
3. 无命中 + MAEE=0 时 TLB 回填属性为 So=1/不可缓存（不产生不安全的缓存行）

---

### 四、新增功能点——F7 侧（7 条）

#### F7.NEW.3（P0）— PMP 检查是 PTW 发 LSU 请求的前提——顺序约束

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L243-246 |
| **TC** | TC-PTW-PMP-BEFORE-LSU-001, TC-PTW-PMP-DENY-STOP-REQ-001, TC-PTW-PMP-WAIT-NO-LSU-001 |
| **SVA / 覆盖组** | sva_pmp_check_before_lsu_req, sva_no_lsu_req_during_pmp_wait |

**描述**：

PTW 每次向 LSU 发起 PTE 数据读请求（`mmu_lsu_data_req=1`）之前，必须已完成对应级别的 PMP 权限检查。机制：当 TWU 在某级（FST/SCD/THD）发现叶 PTE 且需要继续 walk 时，先通过 `pmp_grant[2:0]` 发出 PMP 请求，在 `fst/scd/thd_pmp_wait` 阻塞对应流水级期间，**任何新的 `mmu_lsu_data_req` 不得拉高**；PMP 检查通过（`!pmp_deny`）后，才允许推进流水线并最终发出 LSU 读请求。

PMP deny 时：直接报 Access Fault，不产生 LSU 请求（见 F7.NEW.5）。此顺序约束通过 `twu_mask` 信号（包含 `pmp_wait` 分量，见 F7.NEW.6）体现，防止 xbar 向阻塞中的 TWU 派发新请求，间接阻止提前发出 LSU 访问。

**验证关注点**：
1. 在 `pmp_wait=1` 的任意周期，`mmu_lsu_data_req` 必须为 0（SVA 断言）
2. PMP 返回后的下一周期，LSU 请求可合法拉高
3. PMP deny 场景下，整个 TWU 流水线不产生 LSU 请求，并报 Access Fault（交叉 F4.NEW.13/F7.NEW.5）

---

#### F7.NEW.4（P0）— PTW 各级 PMP 检查的 PA 格式——页级对齐

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1001-1014 |
| **TC** | TC-PTW-PMP-PA-1G-001, TC-PTW-PMP-PA-2M-001, TC-PTW-PMP-PA-4K-001, TC-PTW-PMP-PA-ZERO-001 |
| **SVA / 覆盖组** | sva_pmp_grant_onehot, cg_pmp_pa_format |

**描述**：

TWU 每个流水级向 PMP 发送的物理地址 `mmu_pmp_pa[27:0]` 格式由 `pmp_grant[2:0]` 多路选择（twu.sv:L1001-1014）：

| pmp_grant | 叶级别 | PA 格式 | 对齐 |
|-----------|--------|---------|------|
| `3'b100` | FST / 1G | `{satp_ppn[27:0], fst_pmp_vpn[26:18], 3'b0}` | 1G 对齐（低 18 bit = 0） |
| `3'b010` | SCD / 2M | `{scd_pmp_ppn[27:0], scd_pmp_vpn[17:9], 3'b0}` | 2M 对齐（低 9 bit = 0） |
| `3'b001` | THD / 4K | `{thd_pmp_ppn[27:0], thd_pmp_vpn[8:0], 3'b0}` | 4K 对齐（全 28 bit 有效） |
| `3'b000` | 无有效请求 | 全零 | — |

PMP 据此判断对应物理地址的访问权限（R/W/X/L），反馈 `pmp_mmu_flg[3:0]`。PA 对齐格式与 sysmap PA 格式一致（交叉 F6.NEW.5）。

**验证关注点**：
1. grant=3'b100 时 PA 低 18 bit 为 0
2. grant=3'b010 时 PA 低 9 bit 为 0
3. grant=3'b001 时 PA 全 28 bit 有效
4. PA 与 `mmu_lsu_data_req_addr[39:0]` 高 28 bit 一致性（交叉 F7.4/F7.10）
5. PMP 模块在同一周期仅接受一路 PA（per-TWU 单端口，交叉 F4.NEW.14）

---

#### F7.NEW.5（P0）— PMP deny → TWU Access Fault → L2TLB 异常直通

| 属性 | 内容 |
|------|------|
| **模块** | `twu` → `mmu_l2tlb` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L372-376, L961-964; mmu_l2tlb.sv |
| **TC** | TC-PTW-PMP-DENY-ACCFLT-001, TC-PTW-PMP-DENY-NO-REFILL-001, TC-PTW-PMP-MMODE-L0-001, TC-PTW-PMP-MMODE-L1-001 |
| **SVA / 覆盖组** | sva_pmp_deny_acc_fault, sva_pmp_deny_no_lsu_req, cg_pmp_deny_by_level |

**描述**：

PMP 返回 `pmp_mmu_flg[3:0]` 后，TWU 根据访问类型检查权限（twu.sv:L372-376）：

```
pmp_deny = (fetch && !flg[2]) || (load && !flg[0]) || (store && !flg[1]) || (pref && !flg[0])
```

**M-mode 特殊规则**：处于 M-mode 且 L-bit（flg[3]）=0 时，PMP 检查被绕过（Sv39 规范）；L=1 时检查生效。

PMP deny 时：
1. TWU 不发出 LSU 请求、不进行回填
2. 记录 Access Fault：`twu_acc_err_vld <= 1'b1`（twu.sv:L961-964）
3. 通过 `twu_jtlb_ref_acc_err` + `twu_jtlb_ref_acc_err_id[6:0]` + `twu_jtlb_ref_acc_err_type[2:0]` **直接发往 L2TLB，绕过 mmu_arb**（交叉 F4.NEW.9）

**PTW 访问页表为数据 Load**，使用 R-bit（flg[0]）检查，R=0 则产生 Access Fault。

**验证关注点**：
1. PTW 访问 R=0 的 PMP region → Access Fault，不产生 LSU 请求（交叉 F7.NEW.3）
2. M-mode + L=0 → PMP 检查被绕过，不产生 Access Fault
3. M-mode + L=1 → PMP 检查生效
4. Access Fault 后对应 miss entry 正确释放（与 F4.48/F4.NEW.9 交叉）
5. Access Fault 与 Page Fault 互斥（同一次遍历只报一种异常）

---

#### F7.NEW.6（P1）— PMP wait 状态触发 `twu_xbar_mask`

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv:L243-246; ptw.sv |
| **TC** | TC-TWU-MASK-PMP-WAIT-001, TC-TWU-MASK-ALL4-PMP-001 |
| **SVA / 覆盖组** | sva_pmp_wait_implies_mask, cg_twu_mask_cause |

**描述**：

`twu_mask`（接口规格对外名 `twu_xbar_mask`）的生成逻辑包含所有 PMP 等待状态分量（twu.sv:L243-246）：

```
twu_mask = fst_pmp_wait | scd_pmp_wait | thd_pmp_wait
         | (fst_chk_vld & !fst_leaf & !scd_pmp_wait)
         | (scd_chk_vld & !scd_leaf & !thd_pmp_wait)
```

其中 `fst/scd/thd_pmp_wait` 在对应级别 PMP 检查请求已发出但尚未获得 grant 时为高。

**传播链**：PMP wait → `twu_mask=1` → `ptw_l2tlb_ready` 在全部 4 TWU mask 时拉低（见 F4.NEW.6）→ L2TLB 停止发送新 PTW 请求。

**与 `twu_idle` 的区别**：`twu_mask` 反映"正在 PMP 检查中"；`twu_idle=1` 时 `twu_mask=0`，但反之不成立（交叉 F4.NEW.7）。

**验证关注点**：
1. PMP wait 期间 `twu_mask` 必须为 1
2. PMP grant 返回后的下一周期 `twu_mask` 可降低（若无其他阻塞）
3. 4 TWU 全 PMP wait 时 `ptw_l2tlb_ready=0`（压力场景，交叉 F4.NEW.6）

---

#### F7.NEW.7（P1）— PTW PMP 端口 `mmu_pmp_fecth` 恒为 0

| 属性 | 内容 |
|------|------|
| **模块** | `twu` + `ptw` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv:L1001-1014; ptw.sv:L61-64 |
| **TC** | TC-PTW-PMP-FETCH-ZERO-001, TC-PTW-PMP-R-CHECK-001 |
| **SVA / 覆盖组** | sva_ptw_pmp_fetch_zero |

**描述**：

PTW 通过 TWU 发起的 PMP 检查属于**数据读取**（Load PTE from memory），因此 `mmu_pmp_fecth`（注意 typo，详见 F7.NEW.8）对所有 4 个 PTW PMP 端口（pa3/5/6/7）恒为 0。`pmp_mmu_flg[2]`（X bit）在 `pmp_deny` 计算中用于 fetch type，PTW 不使用该路径，而是检查 `pmp_mmu_flg[0]`（R bit，因为 PTE 是 Load 操作）。

**验证关注点**：
1. 所有 PTW PMP 检查场景下，`mmu_pmp_fecth{3,5,6,7}` 均为 0
2. PMP 模块接收 fetch=0 后，使用 R-bit 而非 X-bit 进行权限判断
3. R=0 且 fetch=0（数据访问）→ 产生 Access Fault（交叉 F7.NEW.5）

---

#### F7.NEW.8（P1）— RTL 拼写 typo：`mmu_pmp_fecth7`

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P1 |
| **RTL 参考** | ptw.sv:L62 |
| **TC** | TC-PTW-PMP-TYPO-BIND-001 |
| **SVA / 覆盖组** | — |

**描述**：

`ptw.sv` 第 62 行端口声明为 `output logic mmu_pmp_fecth7`（缺少字母 `c`，应为 `mmu_pmp_fetch7`），而其他端口 `mmu_pmp_fetch3/5/6`（ptw.sv:L61-64）拼写正确。此 RTL typo 必须在 testbench 接口绑定时使用**错误拼写名称** `mmu_pmp_fecth7`，否则端口连接失败（仿真时 0 驱动信号）。实例化时 twu_four 内部也使用 typo 名（ptw.sv:L459-460）。

**验证关注点**：
1. UVM pmp_agent 中 port7（twu_four）的 fetch 监控端口绑定必须使用 `mmu_pmp_fecth7` 而非 `mmu_pmp_fetch7`
2. 建议在 UVM interface 中添加 `// RTL typo: should be fetch7` 注释标记以提醒后续维护者
3. 建议向设计团队提交 typo 修复 ECO（不影响功能，仅命名问题）

---

#### F7.NEW.9（P1）— PTW 4 TWU PMP 端口分配（pa3/5/6/7）

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P1 |
| **RTL 参考** | ptw.sv:L52-64, L291, L300, L344, L353, L397, L406, L450, L459 |
| **TC** | TC-PTW-PMP-PORT-MAP-001, TC-PTW-PMP-PORT-CONCURRENT-001 |
| **SVA / 覆盖组** | cg_ptw_pmp_port_map |

**描述**：

PTW PMP 端口分配（ptw.sv 确认）：

| TWU 实例 | PA 端口 | flg 端口 | fetch 端口 | RTL 行号 |
|----------|---------|---------|-----------|----------|
| twu_one | `mmu_pmp_pa3` | `pmp_mmu_flg3` | `mmu_pmp_fetch3` | L291/L300 |
| twu_two | `mmu_pmp_pa5` | `pmp_mmu_flg5` | `mmu_pmp_fetch5` | L344/L353 |
| twu_three | `mmu_pmp_pa6` | `pmp_mmu_flg6` | `mmu_pmp_fetch6` | L397/L406 |
| twu_four | `mmu_pmp_pa7` | `pmp_mmu_flg7` | `mmu_pmp_fecth7` ⚠ | L450/L459 |

**关键注意**：端口号为 **3/5/6/7**（非 4/5/6/7），与 LSU/IFU 端口（pa0/1/2）不连续；pa4 功能归属存在歧义（`MMU_Interfaces.md §2.4.2` 与 `MMU_PTW_Interface.md` 描述出入，保留 `[⚠ 需设计确认]` 标注）。

**验证关注点**：
1. `pmp_mmu_flg3` 反馈给 twu_one（非 twu_two），端口映射不得错位
2. UVM pmp_agent 必须按正确映射驱动各端口（交叉 F7.NEW.8 typo）
3. 4 TWU 同时发出 PMP 请求时，4 路 pa/flg 信号独立正确（交叉 F7.1 并发独立性）
4. sysmap 端口与 PMP 端口映射一致（均为 3/5/6/7，交叉 F6.NEW.6）

---

### 五、设计待确认事项（v6.0 新增）

#### DA-003（P0）— PMP 端口 3 / pa3 归属最终确认

| 项目 | 内容 |
|------|------|
| **继承自** | v5.0 DA-001 |
| **问题描述** | v6.0 RTL 精读（ptw.sv:L291）确认 PTW 使用 pa3，但 `MMU_Interfaces.md §2.4.2` 仍显示 pa3=IFU 取指；两者冲突，保留 `[⚠ 需设计确认]` 标注。 |
| **影响范围** | 若 pa3=PTW，则 IFU PMP 端口编号需重新确认；UVM pmp_agent 端口映射表须同步修正。 |
| **建议** | 设计方给出最终 Port 0~7 功能分配表（含 pa4 归属），并修正接口规格文档。 |

---

### 六、修改统计

| 类别 | 数量 |
|------|------|
| §2.3 接口表 Row 级修改 | 1 处（Row 8 PMP 补注） |
| §2.3 注记追加 | 1 处（v6.0 段落） |
| 新增功能点 F4 侧 | 3 条（F4.NEW.12 / F4.NEW.13 / F4.NEW.14） |
| 新增功能点 F6 侧 | 7 条（F6.NEW.1 ~ F6.NEW.7） |
| 新增功能点 F7 侧 | 7 条（F7.NEW.3 ~ F7.NEW.9） |
| **合计新增功能点** | **17 条** |
| 新增 TC | 40 条 |
| 新增 SVA / 覆盖组 | 20 条 |
| 设计待确认项 | 1 项（DA-003，继承并精化 v5.0 DA-001） |

#### 新增 TC 汇总

| 类别 | TC 编号 |
|------|---------|
| MAEE 双路选路 | TC-TWU-MAEE0-CSR-001/002, TC-TWU-MAEE1-REFILL-001, TC-TWU-MAEE-SWITCH-001 |
| PMP 三级序列化 | TC-TWU-PMP-SERIAL-001, TC-TWU-PMP-WAIT-STALL-001, TC-PTW-PMP-BEFORE-LSU-001, TC-PTW-PMP-DENY-STOP-REQ-001 |
| PMP PA 格式 | TC-TWU-PMP-GRANT-ONEHOT-001, TC-PTW-PMP-PA-1G-001, TC-PTW-PMP-PA-2M-001, TC-PTW-PMP-PA-4K-001, TC-PTW-PMP-PA-ZERO-001 |
| sysmap 路径控制 | TC-SYSMAP-MAEE0-ATTR-001/002, TC-SYSMAP-MAEE1-SKIP-CSR-001 |
| sysmap flag 替换 | TC-SYSMAP-FLG-REFILL-001, TC-SYSMAP-FLG-REGION0-001, TC-SYSMAP-FLG-REGION7-001 |
| sysmap 跨界检测 | TC-SYSMAP-CROSS-SAME-001, TC-SYSMAP-CROSS-1G-DIFF-001, TC-SYSMAP-CROSS-2M-DIFF-001, TC-SYSMAP-CROSS-PARTIAL-HIT-001 |
| sysmap 降级 | TC-SYSMAP-DEGRADE-1G2M-001, TC-SYSMAP-DEGRADE-2M4K-001, TC-SYSMAP-NO-DEGRADE-1G-001, TC-SYSMAP-NO-DEGRADE-2M-001 |
| sysmap PA 对齐 | TC-SYSMAP-PA-ALIGN-1G-001, TC-SYSMAP-PA-ALIGN-2M-001, TC-SYSMAP-PA-ALIGN-4K-001 |
| sysmap 并发 | TC-SYSMAP-4TWU-CONCURRENT-001, TC-SYSMAP-TWU-PORT-MAP-001 |
| sysmap 无命中 | TC-SYSMAP-NO-HIT-DEFAULT-001, TC-SYSMAP-DEFAULT-FLAG-BIT-001 |
| PMP deny → Access Fault | TC-PTW-PMP-WAIT-NO-LSU-001, TC-PTW-PMP-DENY-ACCFLT-001, TC-PTW-PMP-DENY-NO-REFILL-001, TC-PTW-PMP-MMODE-L0-001, TC-PTW-PMP-MMODE-L1-001 |
| PMP wait → twu_mask | TC-TWU-MASK-PMP-WAIT-001, TC-TWU-MASK-ALL4-PMP-001 |
| PTW fetch=0 | TC-PTW-PMP-FETCH-ZERO-001, TC-PTW-PMP-R-CHECK-001 |
| RTL typo 绑定 | TC-PTW-PMP-TYPO-BIND-001 |
| PTW 端口映射 | TC-PTW-PMP-PORT-MAP-001, TC-PTW-PMP-PORT-CONCURRENT-001 |

#### 新增 SVA / 覆盖组汇总

| 信号 / 模块 | SVA / cg 名称 |
|-------------|--------------|
| MAEE 路径互斥 | sva_twu_maee_paths_mutex, cg_maee_leaf_level, cg_maee_path |
| PMP 检查先于 LSU | sva_pmp_check_before_lsu_req, sva_no_lsu_req_during_pmp_wait |
| PMP deny 无 LSU | sva_pmp_deny_no_refill, sva_pmp_deny_no_lsu_req |
| PMP grant one-hot | sva_pmp_grant_onehot, cg_pmp_grant_level, cg_pmp_per_level_result |
| PMP PA 格式 | cg_pmp_pa_format |
| sysmap CSR refill 匹配 | sva_csr_refill_flg_matches_sysmap, cg_sysmap_flg_per_region |
| sysmap 跨界降级 | sva_sysmap_cross_degrade, cg_sysmap_cross_1g, cg_sysmap_cross_2m, cg_sysmap_degrade_pgs |
| sysmap PA 对齐 | cg_sysmap_pa_align |
| sysmap 并发查询 | cg_sysmap_4twu_concurrent |
| sysmap 无命中默认 | cg_sysmap_default_flag |
| PMP deny → Access Fault | sva_pmp_deny_acc_fault, cg_pmp_deny_by_level |
| PMP wait → mask | sva_pmp_wait_implies_mask, cg_twu_mask_cause |
| PTW fetch 恒零 | sva_ptw_pmp_fetch_zero |
| PTW 端口映射 | cg_ptw_pmp_port_map |

---

## v7.0 - bus_error / MBUF / PDE Cache 变更记录

> 原标题：MMU 验证计划变更记录 v7.0
> 原始来源：`../archive_merged_20260607/plan/plan_v7.md`


| 字段 | 内容 |
|------|------|
| 版本 | v7.0 |
| 日期 | 2026-04-23 |
| 基于 | MMU_VerificationPlan_v3.md v6.0 |
| 变更依据 | RTL 修改：mbuf_entry.sv + ptw_mbuf.sv 三处改动 |

---

### 一、协议澄清：lsu_mmu_bus_error 与 lsu_mmu_data_vld 并发语义

**背景**：v3.0 在 F4.22/F4.42a 中描述"bus_error 或 data_vld 之一返回"暗示两者互斥。

**更正（v7.0）**：RTL 精读（mbuf_entry.sv）确认：
- `lsu_mmu_bus_error=1` **必然伴随** `lsu_mmu_data_vld=1` **同拍**到来
- `lsu_mmu_data_vld=1` 是 PTW→LSU 串行握手的**唯一**完成信号
- 总线错误时 `lsu_mmu_data[63:0]` 无效，但握手完成信号 `data_vld` 仍拉高
- 影响功能点：F4.22、F4.35、F4.42a

---

### 二、RTL 变更说明

#### 变更 1：mbuf_entry.sv — mbuf_get 逻辑修订

**修改**：`mbuf_get` 置 1 条件新增 `(!lsu_mmu_bus_error)` 门控

旧：`if(mbuf_on & lsu_mmu_data_vld & (!write_back_grant)) mbuf_get <= 1'b1;`

新：`if(mbuf_on & lsu_mmu_data_vld & (!lsu_mmu_bus_error) & (!write_back_grant)) mbuf_get <= 1'b1;`

**原因**：bus_error=1 与 data_vld=1 同拍到来时，若 mbuf_get 被置 1，后续 write_back_req 会使用无效数据回填 TWU，导致错误 PTE 写入 TLB。

#### 变更 2：mbuf_entry.sv — write_back_req / bus_err_write_back_req 双路径

区分 mbuf_on=1（检查实时 LSU 信号）与 mbuf_on=0（检查寄存 flop 信号）两路：

```
write_back_req = mbuf_vld & level_match & (mbuf_on & data_vld & !bus_error | mbuf_get)
bus_err_write_back_req = mbuf_vld & (mbuf_on & bus_error | mbuf_bus_err_flop) & !mask
```

#### 变更 3：ptw_mbuf.sv — PDE Cache 更新时序及条件重构

**旧实现**：mbuf_cache_upd 由 lsu_mmu_data_vld 直接组合驱动，使用 ptw_chk_thd 判断叶 PTE。

**新实现**：引入 4 个内部寄存器，`|write_back_grant[8:0]` 拉高后**次周期**驱动 mbuf_cache_upd：
- `pde_updata_data_vld` — `|write_back_grant` 后 1 拍的脉冲
- `pde_updata_data_flop[DATA_WIDTH-1:0]` — 锁存 `mbuf_twu_data`
- `pde_updata_vpn[VPN_WIDTH-1:0]` — 锁存 `mbuf_twu_vpn`
- `pde_updata_lvl[2:0]` — 锁存 `mbuf_twu_lvl`

新更新条件：

```
mbuf_cache_upd = pde_updata_data_vld
              & pde_updata_data_flop[0]    // V=1
              & (!pde_updata_data_flop[1]  // R=0 非叶
              &  !pde_updata_data_flop[3]) // X=0 非叶
              & (!(pde_updata_data_flop[2] // W=0
              |   pde_updata_lvl[0]));     // lvl[0]=0（FST或SCD，非THD/4K叶级）
```

级别编码：3'b100=FST/1G（允许更新），3'b010=SCD/2M（允许更新），3'b001=THD/4K（禁止更新）

---

### 三、验证计划修改点概要

| 功能点 | 修改类型 | 主要内容 |
|--------|---------|---------|
| F4.22 | 重写 | 并发协议修订；mbuf_get !bus_error 门控；双路 write_back 说明 |
| F4.35 | 扩充 | bus_error 并发合法过渡状态；sva_mbuf_get_bus_err_mutex |
| F4.42a | 修订 | 移除"或 lsu_mmu_data_bus_error"互斥暗示；改为并发语义 |
| F4.NEW.1 | 重写 | 寄存路径 + pde_updata_lvl[0] 条件 + 新 TC/SVA/cg |

---

### 四、新增测试用例规格

| TC ID | 优先级 | 功能点 | 场景 |
|-------|--------|--------|------|
| TC-MBUF-BUS-ERR-CONCURRENT-001 | P0 | F4.22/F4.35 | bus_error=data_vld=1 同拍（mbuf_on=1 期间）→ mbuf_get=0, bus_err_flop→1, bus_err_write_back_req 拉高 |
| TC-MBUF-GET-NO-BUS-ERR-001 | P0 | F4.22/F4.35 | data_vld=1 & bus_error=0 → mbuf_get 置 1，write_back_req 正常拉高 |
| TC-PDE-CACHE-TIMING-001 | P1 | F4.NEW.1 | write_back_grant 后恰好 1 周期 mbuf_cache_upd 按条件生效 |
| TC-PDE-CACHE-LVL-001 | P1 | F4.NEW.1 | THD 级（lvl=3'b001）时 mbuf_cache_upd=0；FST/SCD 有效非叶时 mbuf_cache_upd=1 |

---

### 五、新增 SVA 断言规格

| SVA 名称 | 功能点 | 断言逻辑 |
|---------|--------|---------|
| sva_bus_err_with_data_vld | F4.22 | `@(posedge clk) lsu_mmu_bus_error \|-> lsu_mmu_data_vld` |
| sva_mbuf_get_not_set_on_bus_err | F4.22/F4.35 | `@(posedge clk) (mbuf_on & lsu_mmu_bus_error) \|-> ##1 !mbuf_get` |
| sva_mbuf_get_bus_err_mutex | F4.35 | `@(posedge clk) !(mbuf_get & mbuf_bus_err_flop)` |
| sva_pde_cache_one_cycle_delay | F4.NEW.1 | `@(posedge clk) \|write_back_grant[8:0] \|-> ##1 pde_updata_data_vld` |
| sva_pde_cache_no_leaf_entry | F4.NEW.1 | `@(posedge clk) pde_updata_lvl[0] \|-> !mbuf_cache_upd` |

---

### 六、新增 Covergroup 规格

#### cg_mbuf_bus_err_concurrent（关联 F4.22/F4.35）
- cp_response：覆盖 {bus_error, data_vld}：2'b11 并发 / 2'b01 正常 / 2'b00 空闲
- cx_concurrent_vs_get：cross(cp_response, mbuf_get)

#### cg_pde_cache_timing（关联 F4.NEW.1）
- cp_lvl_bit0：覆盖 pde_updata_lvl[0]（leaf=1 / nonleaf=0）
- cx_lvl_vs_upd：cross(cp_lvl_bit0, mbuf_cache_upd)

---

### 七、风险

| 风险 ID | 风险描述 | 缓解措施 |
|---------|---------|---------|
| R-V7.1 | bus_error 并发语义需设计方书面确认 | 追加设计文档确认 |
| R-V7.2 | mbuf_bus_err_flop 清零时机需 RTL 精读确认 | 阅读 mbuf_entry.sv 完整 always_ff |
| R-V7.3 | pde_updata 寄存路径 reset 后及连续 grant 时的边界行为 | 增加边界 TC |

---
