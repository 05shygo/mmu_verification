# MMU 验证计划 第二次完善（v2.0 → v3.0）改动清单

> **说明**：本文件对标 `plan_v1.md`，列出在 `MMU_VerificationPlan_v1.md`（v2.0 → v3.0）之上所做的**全部第二次完善点**。改动围绕两条主线：(1) 通过 RTL 二次核对**纠正 v2.0 中的错判**；(2) 追加新发现的高危 Bug 与覆盖盲点。
>
> **编辑对象**：直接在 `MMU_VerificationPlan_v1.md` 中就地更新为 v3.0 版本。
> **日期**：2026-04-22
> **作者**：Verification Team

---

## 0. 本次完善总体方针

1. **先纠错、再补充**：v2.0 继承自 plan_v1.md 的 10 条“潜在 RTL 缺陷”经过二次 RTL 走读后，**6 条为错判**（用户澄清：thd_chk 必为叶 PTE，进一步证伪 TC-BUG-002/003）、**4 条真实存在**。先把错判降级并做透明化记录（保留 TC 编号 gap 以便追溯演化），再在真实缺陷之上升级优先级。
2. **强证据、不定性**：v3.0 所有新发现以"RTL 二次核对 — 疑似，需设计确认"语气书写；对应 TC 打 BUG_HUNT 标签并配 SVA 形式化保护，不在验证侧擅自定性。
3. **覆盖率闭环**：每一条新 Gap 必须同时具备 **Feature 表行 + TC 行 + covergroup 或 SVA**，避免只在某一层落单。
4. **接口表一致性**：补齐 v1 遗漏的**广播/全局使能/CSR 细分**信号，保证 §2.3 接口表与 `ct_mmu_top.v` 端口列表一一对应。

---

## A. 纠错项（v2.0 → v3.0 证伪）

RTL 二次核对（`mmu_arb.sv` / `twu.sv` / `mmu_l2tlb.sv`）及用户对 thd_chk 语义的澄清后，确认 v2.0 中以下 **6 条疑似缺陷不成立**：

| v2.0 原判定 | v3.0 证伪依据 | v1.md 处置 |
|-------------|--------------|-----------|
| TC-BUG-001 / F4.NEW.2：`twu` 跨级使用 fst_pmp_fetch_type 错误 | `twu.sv#L1175` `fst_pmp_itlb_sel = fst_pmp_vld & fst_pmp_fetch_type`；scd/thd 各级对应 `scd_pmp_*` / `thd_pmp_*` 独立字段，无误用 | **TC-BUG-001 由 BUG_HUNT 降级为 Functional，P0→P1**；Feature 表 F4.NEW.2 保留但去除"错误"定性 || TC-BUG-002 / F4.NEW.3：`twu` thd_chk 路径 4K 页 A-bit 检测缺失 | 用户澄清：thd_chk 必为叶 PTE，`thd_chk_page_flt` 中 A-bit 检测（`!flg[5]`）正常执行，4K/2M/1G 均有对应分支，非缺陷 | **TC-BUG-002 降为 Functional，P0→P1**；`sva_thd_a_bit_pgflt` 保留作正向保护 |
| TC-BUG-003 / F4.NEW.1：MAEE=0 + 叶 PTE 时 thd_chk_refill_req 误触 / `mbuf_cache_upd` 误入 Cache | 用户澄清：thd_chk 必为叶 PTE，`thd_chk_refill_req` **只要不触异常即可发出**；`mbuf_cache_upd` 的“仅非叶 PTE”限制仅作用于 Cache 内容，与 refill 发送不矛盾 | **TC-BUG-003 降为 Functional，P0→P1**；`sva_pde_nonleaf_upd` 保留作 Cache 污染保护 || TC-BUG-004 / F5.NEW.1：`mmu_arb` bank mask 字面量缺 `8'b` 前缀 | `mmu_arb.sv#L142` 使用 `8'b00110011` 等完整字面量，未出现无前缀 decimal | **TC-BUG-004 降为 Functional，P0→P1**；F5.NEW.1 描述改为"正向覆盖"；**R16 风险等级由高降为低** |
| TC-BUG-009 / F4.NEW.2：`twu` CSR Arbiter `2'b10` case 分支重复 | `twu.sv` CSR Arbiter 实际 case 为 `2'b01`/`2'b10`，不存在重复 | **TC-BUG-009 整行删除**（编号保留空位以便 v2→v3 演化追溯）|
| TC-BUG-010 / F4.NEW.2：CSR FSM IDLE 无 else 分支可能 latch 推断 | `twu.sv#L1040` 已有 `else ptw_nxt_st = TWU_IDLE` 闭合分支 | **TC-BUG-010 整行删除** |

---

## B. 新发现项（v3.0 新增）

### B.1 **P0 高危 Bug（强证据）**

| ID | 定位 | 描述 |
|----|------|------|
| **F4.NEW.4 / TC-BUG-011 / R19** | `twu.sv#L1128-L1133` | `else if(twu_crs2_1g && twu_csr_cross)` **与上一行完全重复**；推测第二行应为 `twu_crs2_2m && twu_csr_cross`。导致 **2MB 巨页 CSR 跨界场景下 `csr_data_flop` 不会被 shift 更新**，后续 CSR refill 使用旧数据。**应作为 P0 高危 Bug 建 JIRA 工单** |

### B.2 **P1 新盲点（RTL 行为正确但缺乏保护）**

| ID | 定位 | 描述 |
|----|------|------|
| **F4.NEW.5 / TC-BUG-012** | `twu.sv#L1052-L1063` | TWU_IDLE 状态按 bit[1]/bit[0] 依次判断 `csr_grant`；若仲裁侧异常输出 `2'b11` 会隐式偏向 1G 分支。需 `sva_csr_grant_onehot` 约束 |
| **F5.NEW.2 / TC-BUG-013** | `mmu_arb.sv#L180-L235` | `arb_ptw_grant` → `ptw_write_req1` → `ptw_write_req2` 两拍流水中段若 reset / `ptw_xx_cmplt` 到达可能产生 SRAM stale write。需 `sva_ptw_write_pipe_reset_safe` |
| **F5.NEW.3 / TC-BUG-014** | `one_to_four_xbar.sv#L100-L115` | `twu_req_point_r` 复位初值 `4'b0001` 造成冷启动首请求偏向 TWU0。需 `cg_xbar_cold_start` 监控分布 |

### B.3 P2 文档项

| ID | 定位 | 描述 |
|----|------|------|
| **F8.NEW.2 / TC-BUG-015** | `ct_mmu_tlboper.v#L685-L730` | 原 14-state INVVA FSM 注释残留（已被 single-pass 替代）。非仿真 TC，仅代码评审追踪 |

---

## C. 真实缺陷 TC 优先级升级（plan_v1.md 真实项）

下列 **4 条**经 RTL 二次核对**确认为真实缺陷或强疑似缺陷**，v3.0 全部从 P1 升为 P0（注：原列入 TC-BUG-002/003 已随用户澄清证伪——thd_chk 必为叶 PTE，A-bit 检测正常执行、`thd_chk_refill_req` 与 `mbuf_cache_upd` 非叶限制不矛盾，已移出本表并在§A 记录）：

| TC | 定位 | 真实缺陷证据 |
|----|------|--------------|
| TC-BUG-005 / F3.4 | `mmu_l2tlb.sv#L456` | `raw_vld = pipe_vld \|\| ptw_req`（应为 `&&`），PTW 写同周期误触发 tag compare hit |
| TC-BUG-006 / F3.5 | `mmu_l2tlb.sv#L512` | `arb_l2tlb_is_dtlb` 判断重复 `3'b010` 两次且漏 store 类型 `3'b110` |
| TC-BUG-007 / F3.NEW.1 | `mmu_l2tlb_replacement_policy.sv` | SFENCE INVVA 无效化 entry 后 RRPV 未复位，受旧残留影响下一次 victim 选择 |
| TC-BUG-008 / F12.NEW.1 | `pplru.sv` | entry 0 `hit_num_flop == 0` 首次命中 PLRU 树不更新 |

---

## D. §2.3 接口表补齐

补充 v1.md §2.3 表中原本遗漏的 2 行端口组（第 13/14 组）：

| 组 | 补齐信号 | 说明 |
|----|---------|------|
| **13 全局使能 / TLB Oper 完成** | `mmu_xx_mmu_en`（顶层使能广播）、`mmu_lsu_mmu_en`（LSU 专用）、`mmu_cp0_tlb_done`（TLB Oper 完成握手） | v2.0 接口表仅列 `mmu_lsu_mmu_en`，遗漏顶层广播 en 与 TLB Oper 完成握手 |
| **14 CSR 细分控制** | `cp0_mmu_cskyee`、`cp0_mmu_reg_num[1:0]`、`cp0_mmu_mpp[1:0]`、`cp0_mmu_wdata[63:0]`、`cp0_mmu_wreg` | v2.0 仅列 CP0 大类，未列出 CSR 侧的寄存器号、MPP、写通道等细分字段 |

其他勘误：
- `regs_ptw_cur_asid` 内部宽度为 **16-bit**（与 SATP.ASID 一致），v2.0 曾按 8-bit 注释，更正为 16-bit；
- `ct_mmu_top.v` 顶层**不存在** `pmp_mmu_fetch*` 输入信号（fetch 方向只有 MMU→PMP 的 `mmu_pmp_fetch{3,5,6,7}`），v2.0 接口表措辞已澄清。

---

## E. Covergroup / SVA 扩充

### 新增 Covergroup（3 个）

| 名称 | bind 位置 | 作用 |
|------|----------|------|
| `cg_twu_2m_csr_cross` | `twu` | 2MB 巨页 `twu_crs2_2m && twu_csr_cross` 事件必须被命中；采样 `csr_data_flop` 前后值抓取 L1130 分支重复 Bug（F4.NEW.4） |
| `cg_xbar_cold_start` | `one_to_four_xbar` | 复位后前 16 次 `PDE_xbar_req` 的 TWU 分配分布（F5.NEW.3） |
| `cg_l2_store_dtlb_tag` | `mmu_l2tlb` | `d_req_type=3'b110`（store）路径的 `arb_l2tlb_is_dtlb` 判断覆盖；load(010) vs store(110) cross（F3.5） |

### 新增 SVA（3 条）

| 名称 | 对应特性 |
|------|---------|
| `sva_twu_2m_cross_data` | F4.NEW.4：2MB CSR 跨界必须触发 `csr_data_flop` 更新 |
| `sva_csr_grant_onehot` | F4.NEW.5：`csr_grant[1:0]` 禁止同时为 1 |
| `sva_ptw_write_pipe_reset_safe` | F5.NEW.2：reset 断言期间 `ptw_write_req1/req2` 同步清零无 stale |

---

## F. TC 统计更新

| 口径 | v2.0 | v3.0 |
|------|------|------|
| 原 TC-GAP-* | 60 | 60 |
| v2.0 新增 TC-BUG-* | 12 | 12 |
| v3.0 新增 TC-BUG-011~015 | — | +5 |
| v3.0 删除 TC-BUG-009/010 | — | −2 |
| **合计** | 72 | **75** |
| P0 / P1 / P2 分布 | 29 / 35 / 8 | **37 / 37 / 7**（4 条真实缺陷升 P0，4 条证伪降 P1）|

---

## G. 风险表更新（§11）

| 风险 | v3.0 处置 |
|------|----------|
| R15 | 描述收敛为 4 条真实缺陷合并保护（TC-BUG-005/006/007/008 全升 P0）；原列入的 TC-BUG-002/003 随用户澄清证伪（thd_chk 必为叶 PTE，A-bit 检测与 `thd_chk_refill_req` 均为正常设计）从 R15 移除 |
| **R16** | **等级由高降为低**（v2.0 怀疑的 bank mask 编码错误证伪） |
| R17/R18 | 保持原状 |
| **R19 新增** | **P0 高危**：`twu.sv#L1130` 2MB CSR 跨界分支重复，独立 JIRA 工单跟踪；修复前豁免相关测试 |
| **R20 新增** | **中等**：`mmu_arb` PTW 写双级流水 reset 竞争 + `one_to_four_xbar` 冷启动偏向 TWU0，由 `sva_ptw_write_pipe_reset_safe` + `cg_xbar_cold_start` 保护 |

---

## H. 交叉引用索引（便于走查）

- **版本元数据**：v1.md 行 4（文档版本）、行 14（变更说明行 v3.0 新条目）
- **§2.3 接口表**：第 13/14 行及 "v3.0 接口补充" 段
- **§5.2 Feature 表**：F4.NEW.4 / F4.NEW.5（§F4 段）、F5.NEW.2 / F5.NEW.3（§F5 段）、F8.NEW.2（§F8 段）
- **§6.5 TC-BUG 表**：TC-BUG-001/004 降级注记、TC-BUG-009/010 删除行、TC-BUG-011~015 新行
- **§7.2 Covergroup 表**：`cg_twu_2m_csr_cross` / `cg_xbar_cold_start` / `cg_l2_store_dtlb_tag`
- **§7.3 SVA 段**：`sva_twu_2m_cross_data` / `sva_csr_grant_onehot` / `sva_ptw_write_pipe_reset_safe`
- **§11 风险表**：R15 描述扩写、R16 等级下调、R19 新增、R20 新增

---

## I. 遗留 / 下一步

1. **F4.NEW.4 修复前**，建议冻结 2MB CSR 跨界相关测试用例，避免误判 regression；
2. **R20（F5.NEW.2/F5.NEW.3）** 二条均为"RTL 行为当前未观察到显式错误但缺防护"，设计侧可并行评审；
3. plan_v1.md 中提及的"ct_mmu_tlboper 14→5 状态简化"已映射为 F8.NEW.2，仅作文档清理项，不入仿真 regression；
4. 所有 v3.0 新增 TC/CG/SVA 的 stimuli 实现由后续 sequence 开发阶段跟踪 JIRA，本次仅在计划层声明。
