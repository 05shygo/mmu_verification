# Plan: MMU 验证计划完善

## TL;DR
在现有极详细的 MMU_VerificationPlan.md（1500+行，F1-F14，120+TC，60+Gap TC）基础上，通过深度 RTL 分析发现了多处验证盲点、潜在 RTL 缺陷、遗漏功能点及覆盖率缺口，进行系统性补充和修订。

## 核心发现（须补入计划）

### A. 严重潜在 RTL 缺陷（需在验证计划中显式设计 Negative TC 捕获）

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

### B. 遗漏功能点（需新增 F-ID）

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

### C. 覆盖率补充（需新增 Covergroup / SVA）

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

### D. 需修正的现有描述错误

- F1.1：描述写"32 entry"但 RTL 实际为 16 entry（session memory 也确认 16 entries）
- F2.3：FSM 状态列表不完整（缺 WFG）
- F8.2：未明确 INVVA 已从 14 状态简化为 5 状态（single-pass）
- 第 5 章 L2 TLB 特性 F3.4 需更新：tag match 实际含 kid0-kid5 6 路并行比较
- §2.3 接口表：缺 `mmu_yy_xx_no_op` 信号

## 步骤（写文件时的改进范围）

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

## 关键文件
- `c:\Users\LIUCONG\Desktop\mmu_verification-main\MMU_VerificationPlan.md` — 唯一修改目标

## 验证步骤
1. 检查 F1.1 entry 数量修正是否影响其他章节引用
2. 确认 Phase 2 新 F-ID 不与现有编号冲突
3. 确认 Phase 3 TC-ID 命名规范（`TC-BUG-*`）与现有体系兼容

## 决策
- 将潜在 RTL 缺陷以"需设计确认"方式记录，不直接定性为 Bug
- 保持现有编号体系，新增内容用 ".NEW.*" 或追加序号
- 仅修改 MMU_VerificationPlan.md，不创建新文件
