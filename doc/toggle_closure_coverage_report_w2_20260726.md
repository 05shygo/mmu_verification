# Toggle 覆盖率闭合 —— 第二轮（Wave-2）覆盖率报告

- 日期：2026-07-26
- 工具：VCS/URG `V-2023.12-SP2`
- 范围：`tb_top` 全设计 toggle（`-metric tgl`），重点 L1 ITLB / L1 DTLB / L2 JTLB 三棵实例树
- 上游文档：`doc/toggle_closure_plan.md`（计划与执行记录）、
  `doc/toggle_closure_coverage_report_20260726.md`（第一轮 Wave-1 报告）、
  `doc/toggle_closure_rtl_issues.md`（RTL 问题单 B1–B7 / N1 / N2）

---

## 〇、数据来源与可比性

四份 URG 报告，**同一份 baseline VDB、同一组 elfile、同一条命令模板**，只增加待评测的 VDB，
因此 A/B/C/D 之间的差值就是新用例的净增量。

| 报告 | 目录 | 输入 VDB | 测试数 | 含义 |
|---|---|---|---|---|
| A | `output/coverage/w2_refA_bp` | `phase14_merged` | 1 | 基线（Wave-1 之前的全回归） |
| B | `output/coverage/w2_refB_bp` | A + `toggle_new` | 8 | 基线 + Wave-1 的 7 个 toggle 用例 |
| C | `output/coverage/w2_refC_bp` | B + `toggle_w2` | 15 | B + Wave-2 的 7 次运行 |
| D | `output/coverage/w2_refD_bp` | C + `toggle_w2b` | 16 | C + 加宽后的 T-I（32→64 页 / 2→4 轮） |

统一命令（**从工程根目录执行**）：

```bash
urg -full64 \
    -dir output/coverage/phase14_merged.vdb \
    -dir output/coverage/toggle_new.vdb \
    -dir output/coverage/toggle_w2.vdb \
    -dir output/coverage/toggle_w2b.vdb \
    -elfile simu/exclude_v4.tgl -elfile simu/fullexclude.tgl \
    -excl_bypass_checks \
    -metric tgl -format both \
    -report output/coverage/w2_refD_bp
```

### 0.1 本轮踩到并确认的 3 条 URG 用法（重要，后续沿用）

1. **`-format both` 必须显式加**。只给 `-metric tgl` 时本环境只产出 HTML，
   没有 `dashboard.txt` / `modlist.txt` / `hierarchy.txt`，脚本化比对无从下手。
2. **`-excl_bypass_checks` 用于跨编译合并**。把不同 compile 产生的 VDB 合到一起时，
   `exclude_v4.tgl` / `fullexclude.tgl` 会报
   `Warning-[UCAPI-EL-MCM] Module checksum mismatch`（本轮命中
   `u_mmu_l1dtlb.x_scheduler` 与 `u_mmu_l1dtlb.x_allocator`）。加上该开关后 MCM 归零，
   且经核对**豁免确实生效**：`hierarchy.txt` 中实例 `x_allocator` = 100.00。
   模块级 `mmu_l1dtlb_allocator` 仍显示 98.26 —— 这是"模块聚合视图不套用实例级豁免"的
   报表粒度问题，不是豁免掉了。
3. **HTML 信号表的列序是 `Name | Toggle | Toggle 1->0 | Toggle 0->1`**，
   `1->0` 在前、`0->1` 在后。本轮一度按 `0->1` 在前解析，得出了与 RTL 分析相反的结论；
   核对表头后修正。所有脚本化统计都必须按这个列序取值。

另外两点经验：

- URG 会把**已全覆盖的相邻位合并成范围行**（如 `entry0_flg[4:1]`），
  所以某个 bit 从逐位列表里"消失"= 它被覆盖了，不是分页截断。
  统计口径应取"仍然列出 `entryN_flg[3]` 且 `1->0 = No` 的条目数"。
- `urg -dump full_exclusions` 在本环境不产出任何文件，无法用它拿 canonical checksum。

---

## 一、总览

### 1.1 全设计（tb_top）

| 口径 | A 基线 | B (+Wave-1) | D (+Wave-2) | ΔWave-2 | Δ合计 |
|---|---:|---:|---:|---:|---:|
| tb_top TOGGLE | **77.71** | **81.90** | **82.46** | +0.56 | **+4.75** |
| u_dut TOGGLE | 80.50 | 85.05 | **85.65** | +0.60 | +5.15 |
| 模块定义汇总 | — | — | 82.12 | — | — |

### 1.2 签核范围（三棵实例树 + 周边）

| 实例 | A 基线 | B (+Wave-1) | D (+Wave-2) | ΔWave-2 | Δ合计 |
|---|---:|---:|---:|---:|---:|
| `x_mmu_l1itlb` | 79.71 | 94.07 | **94.32** | +0.25 | **+14.61** |
| `u_mmu_l1dtlb` | 81.98 | 84.93 | **85.21** | +0.28 | +3.23 |
| `x_mmu_l2tlb` | 85.98 | 88.43 | **89.60** | +1.17 | +3.62 |
| `x_mmu_arb` | 93.37 | 97.86 | **99.25** | +1.39 | +5.88 |
| `x_ct_mmu_tlboper` | 77.20 | 83.99 | **91.86** | **+7.87** | **+14.66** |
| `twu_one` | 94.80 | 95.14 | 95.14 | +0.00 | +0.34 |
| `cp0_if_inst` | 73.15 | 77.78 | **81.02** | +3.24 | +7.87 |
| `ifu_if_inst` | 92.17 | 99.13 | 99.13 | +0.00 | +6.96 |
| `dut_probes_if` | 81.24 | 83.54 | 83.99 | +0.45 | +2.75 |

**Wave-2 的增益集中在 L2 侧**（tlboper +7.87、arb +1.39、l2tlb +1.17、cp0_if +3.24），
这符合 Wave-2 的用例构成：T-F2/T-G2/T-H2 三个 L2 用例 + T-B2/T-D2 两个 L1D 用例 + T-I 一个 L1I 用例。

### 1.3 位级闭合总账（22 个 L1/L2 模块，方向位口径）

数据取自各 module 页的 `Total Bits` 汇总块（URG 权威口径，含 0→1 与 1→0 两个方向）。

| | A 基线 | B (+Wave-1) | D (+Wave-2) |
|---|---:|---:|---:|
| 总方向位 | 46 158 | 46 158 | 46 158 |
| 未覆盖位 | 6 805 | 4 592 | **4 249** |
| 覆盖率 | 85.26% | 90.05% | **90.79%** |
| 本轮闭合 | — | **+2 213 位** | **+343 位** |
| 累计闭合 | — | — | **+2 556 位** |

L2 周边模块（不计入上表）另有：`ct_mmu_tlboper` +216 位、`ct_mmu_regs` +245 位、
`ct_mmu_top` +231 位、`mmu_arb` +110 位、`twu` +12 位 —— Wave-2 单独贡献 +316 位。

**Wave-2 合计闭合约 660 个方向位。**

---

## 二、分模块结果

### 2.1 L1/L2 核心模块逐模块位级闭合

| 模块 | 总位 | missA | missB | missD | ΔW1 | ΔW2 | Δ合计 | A% | D% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `mmu_l1itlb` | 5652 | 1475 | 420 | 403 | +1055 | +17 | +1072 | 73.90 | **92.87** |
| `mmu_l1dtlb` | 11038 | 2000 | 1599 | 1560 | +401 | +39 | +440 | 81.88 | 85.87 |
| `mmu_l2tlb` | 9182 | 1217 | 872 | **660** | +345 | **+212** | +557 | 86.75 | **92.81** |
| `ct_mmu_l2tlb_tag_array` | 1962 | 178 | 134 | 100 | +44 | +34 | +78 | 90.93 | 94.90 |
| `ct_mmu_l2tlb_data_array` | 1758 | 118 | 42 | **22** | +76 | +20 | +96 | 93.29 | **98.75** |
| `mmu_l1dtlb_hit_rd` | 2554 | 410 | 311 | 301 | +99 | +10 | +109 | 83.95 | 88.21 |
| `mmu_l1dtlb_expt_cam` | 1026 | 222 | 220 | 216 | +2 | +4 | +6 | 78.36 | 78.95 |
| `mmu_l1dtlb_install` | 2010 | 487 | 461 | 458 | +26 | +3 | +29 | 75.77 | 77.21 |
| `mmu_l1dtlb_mb_entry` | 604 | 44 | 44 | 42 | +0 | +2 | +2 | 92.72 | 93.05 |
| `ct_mmu_iutlb_fst_entry` | 728 | 96 | 16 | **14** | +80 | +2 | +82 | 86.81 | **98.08** |
| `ct_mmu_iutlb_entry` | 674 | 80 | 10 | 10 | +70 | +0 | +70 | 88.13 | **98.52** |
| `mmu_l1dtlb_scheduler` | 1094 | 134 | 119 | 119 | +15 | +0 | +15 | 87.75 | 89.12 |
| `ct_mmu_iplru` | 762 | 18 | 18 | 18 | 0 | 0 | 0 | 97.64 | 97.64 |
| `mmu_l1dtlb_allocator` | 230 | 4 | 4 | 4 | 0 | 0 | 0 | 98.26 | 98.26 |
| `ct_mmu_dplru` | 630 | 6 | 6 | 6 | 0 | 0 | 0 | 99.05 | 99.05 |
| `mmu_l2tlb_rrpv_wbuf` | 2298 | 4 | 4 | 4 | 0 | 0 | 0 | 99.83 | 99.83 |
| `mmu_l2tlb_reqq` | 1118 | 94 | 94 | 94 | 0 | 0 | 0 | 91.59 | 91.59 |
| `mmu_l2tlb_reqq_entry` | 304 | 70 | 70 | 70 | 0 | 0 | 0 | 76.97 | 76.97 |
| `mmu_l2tlb_mb` | 1104 | 116 | 116 | 116 | 0 | 0 | 0 | 89.49 | 89.49 |
| `mmu_l2tlb_mb_entry` | 268 | 32 | 32 | 32 | 0 | 0 | 0 | 88.06 | 88.06 |
| `ct_mmu_l2tlb_rrpv_array` | 522 | 0 | 0 | 0 | 0 | 0 | 0 | 100.00 | **100.00** |
| `mmu_l2tlb_replacement_policy` | 640 | 0 | 0 | 0 | 0 | 0 | 0 | 100.00 | **100.00** |
| **小计** | **46158** | **6805** | **4592** | **4249** | **+2213** | **+343** | **+2556** | 85.26 | **90.79** |

L2 周边：

| 模块 | 总位 | missA | missB | missD | ΔW1 | ΔW2 | Δ合计 | A% | D% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `ct_mmu_tlboper` | 1362 | 334 | 234 | **118** | +100 | **+116** | +216 | 75.48 | **91.34** |
| `ct_mmu_regs` | 2074 | 806 | 665 | 561 | +141 | +104 | +245 | 61.14 | 72.95 |
| `ct_mmu_top` | 5602 | 569 | 408 | 338 | +161 | +70 | +231 | 89.84 | 93.97 |
| `mmu_arb` | 1874 | 124 | 40 | **14** | +84 | +26 | +110 | 93.38 | **99.25** |
| `twu` | 3582 | 186 | 174 | 174 | +12 | 0 | +12 | 94.81 | 95.14 |

### 2.2 模块百分比增量 Top（Wave-2 单独）

| 模块 | 基线 | Wave-1 | Wave-2 | ΔW2 | Δ合计 |
|---|---:|---:|---:|---:|---:|
| `ct_mmu_tlboper` | 75.48 | 82.82 | **91.34** | **+8.52** | +15.86 |
| `ct_mmu_regs` | 61.14 | 67.94 | 72.95 | +5.01 | +11.81 |
| `mmu_l2tlb` | 86.75 | 90.50 | **92.81** | +2.31 | +6.06 |
| `ct_mmu_l2tlb_tag_array` | 90.93 | 93.17 | 94.90 | +1.73 | +3.97 |
| `mmu_arb` | 93.38 | 97.87 | **99.25** | +1.38 | +5.87 |
| `ct_mmu_top` | 89.84 | 92.72 | 93.97 | +1.25 | +4.13 |
| `ct_mmu_l2tlb_data_array` | 93.29 | 97.61 | **98.75** | +1.14 | +5.46 |
| `mmu_l1dtlb_hit_rd` | 83.95 | 87.82 | 88.21 | +0.39 | +4.26 |
| `mmu_l1dtlb_expt_cam` | 78.36 | 78.56 | 78.95 | +0.39 | +0.59 |
| `mmu_l1dtlb` | 81.88 | 85.51 | 85.87 | +0.36 | +3.99 |
| `mmu_l1dtlb_mb_entry` | 92.72 | 92.72 | 93.05 | +0.33 | +0.33 |
| `mmu_l1itlb` | 73.90 | 92.57 | **92.87** | +0.30 | **+18.97** |
| `ct_mmu_iutlb_fst_entry` | 86.81 | 97.80 | **98.08** | +0.28 | +11.27 |
| `mmu_l1dtlb_install` | 75.77 | 77.06 | 77.21 | +0.15 | +1.44 |

（SVA 模块同步受益：`mmu_l2tlb_ctrl_hazard_sva` 82.26→100.00，
`mmu_l1dtlb_hit_rd_sva` 83.35→88.77，`mmu_l1dtlb_sva` 86.71→90.27。）

---

## 三、Wave-2 用例清单与验收

6 个新用例，全部 **SEED=1 与 SEED=2 双种子通过，0 UVM_ERROR / 0 UVM_FATAL / 0 UVM_WARNING**。

| # | 用例 | vseq | 计划项 | 主攻目标 | 主要成效 |
|---|---|---|---|---|---|
| 1 | `test_mmu_l1dtlb_cov_toggle_entry_sweep_002` | `mmu_l1dtlb_toggle_entry_sweep2_vseq` | T-B2 | L1D 16 entry 的 ppn/flg 反向翻转 | `mmu_l1dtlb` +39 位 |
| 2 | `test_mmu_l1dtlb_cov_toggle_expt_cam_full_001` | `mmu_l1dtlb_toggle_expt_cam_full_vseq` | T-D2 | expt_cam 全 8 槽 + iid[6:0] 极值 | `mmu_l1dtlb_expt_cam` +4 位 |
| 3 | `test_mmu_l2tlb_cov_toggle_sram_002` | `mmu_l2tlb_toggle_sram2_vseq` | T-F2 | tag/data array 高位、skew 全覆盖 | data_array +20、tag_array +34 位 |
| 4 | `test_mmu_l2tlb_cov_toggle_highaddr_002` | `mmu_l2tlb_toggle_highaddr2_vseq` | T-G2 | 高 PA / 高 set 组合 | `mmu_l2tlb` 的 PA 通路 |
| 5 | `test_mmu_l2tlb_cov_toggle_small_modules_002` | `mmu_l2tlb_toggle_small_modules2_vseq` | T-H2 | tlbop/invall/regs 全谱 | **`ct_mmu_tlboper` +116 位 (+8.52%)** |
| 6 | `test_mmu_l1itlb_cov_toggle_flg_clear_001` | `mmu_l1itlb_toggle_flg_clear_vseq` | 计划 §8.3 新增 | ITLB `entryN_flg[3]` 1→0 | 30 → 13（闭合 17 项） |

**验收命令**

```bash
make comp
for t in test_mmu_l1dtlb_cov_toggle_entry_sweep_002 \
         test_mmu_l1dtlb_cov_toggle_expt_cam_full_001 \
         test_mmu_l2tlb_cov_toggle_sram_002 \
         test_mmu_l2tlb_cov_toggle_highaddr_002 \
         test_mmu_l2tlb_cov_toggle_small_modules_002 \
         test_mmu_l1itlb_cov_toggle_flg_clear_001 ; do
  make run TEST_NAME=$t SEED=1 ; make run TEST_NAME=$t SEED=2
done
```

---

## 四、重点发现

### 4.1 TB 缺陷：`raw_ifu_fetch` 多握了一拍（已修复）

**现象**：T-H2 报 2 条、T-I 首跑报 132 条
`IFU rsp observed without pending req: pa=0x...`。前两次尝试（加大 fetch 超时、
去掉 `fork...join`）都没有解决。

**根因**：`raw_ifu_fetch()` 在观测到 `pavld` 之后还多等了一拍
（`@(ivif.driver_cb);`）才拉低 `ifu_mmu_va_vld`。对于 **miss→walk** 的取指，
这一拍恰好落在"walk 刚把该 VA 装进 L1 ITLB"之后，MMU 看到一个仍然有效的请求，
于是**第二次**给出响应；而 `ifu_monitor` 对同一 va/abort 签名保持
`m_rsp_tail_hold`，拒绝重开 pending 请求，多出来的那次响应就被报成
"rsp without pending req"。只有 miss→walk 的取指足够长才会暴露。

**修复**：在观测到 `pavld` 的**同一拍**拉低 `va_vld`。
`mmu_toggle_closure_vseq.svh` 的 **L1 base（~line 96）与 L2 base（~line 800）两处都要改**
（首次只改了 L2 base，导致 T-I 仍报 132 条）。修复后 T-H2 / T-I 均为 0 warning，
T-A 回归无新增 warning。

> 该缺陷影响**所有基于 IFU 的 toggle vseq**，属于 TB 侧真实缺陷，不是用例写法问题。

### 4.2 `ct_mmu_iutlb_entry.utlb_flg[13:0]` 的逐位可达性（已定论）

flg 位映射（据 RTL 确认）：
`[4:0] = PTE[4:0] = {U,X,W,R,V}`（flg[0]=V, [1]=R, [2]=W, [3]=X, [4]=U）；
`[8:5] = PTE[9:6] = {RSW1,RSW0,D,A}`（flg[5]=A, [6]=D, [8:7]=RSW）；
`[13:9] = sysmap_mmu_flg[4:0]`。
**PTE[5]=G 不在 L1 flg 里**，它经 `chk_unit_data[5]` 进入 L2 tag 的 LSB。

Wave-2 之后，`mmu_l1itlb` 中 `entryN_flg[*]` 仍缺 **1→0** 的分布（0→1 已全覆盖）：

| bit | 含义 | 仍缺 1→0 的 entry 数 | 判定 |
|---|---|---:|---|
| `flg[0]` | V | 30 | **结构性不可达** —— 无效化走独立的 `vld` 寄存器，从不回写 flg[0]=0 → 建议豁免 |
| `flg[3]` | X | **13**（原 30） | 可达，T-I 已闭合 17 个；剩余 13 个是 `scd` 槽 |
| `flg[5]` | A | 30 | 页表走查路径不可达（A=0 的 PTE 直接 page fault，不装填）→ 只能靠 TLBWI |
| `flg[9]` | sysmap_mmu_flg[0] | 2 | 需 sysmap 属性变化的重填 |

合计剩余 75 个方向位。

**T-I 的关键发现**：`mmu_l2tlb.sv` 的 L2→L1 重填路径**没有权限检查**
（`final_pa_vld = final_tlb_hit & final_vld`）。这是让 L1 ITLB 装进一条 **X=0**
表项的唯一功能路径 —— 先用 **LSU pipe0**（数据访问，不查 X）把 X=0 的页装进 L2，
再用 **IFU** 取同一 VA，L2 命中后无条件回填 L1I，于是 `flg[3]` 完成 1→0。
该路径本身也记入 RTL 问题单 **N2**。

**为什么剩余 13 个啃不动**：把 T-I 从 32 页/2 轮加宽到 64 页/4 轮，只多闭合 1 个
（14→13）。L1 ITLB 32 项分 4 组，每组的 entry 0/8/16/24 是 `fst` 槽（这 4 个已闭合），
其余是 `scd` 槽，只能通过 **scd→fst 交换**晋升；而交换路径从不晋升一条会 fault（X=0）的表项。
**结论：剩余 13 个 `entryN_flg[3] 1→0` 与 30 个 `flg[0]` / 30 个 `flg[5]` 一并走豁免或 RTL 讨论，
不再投入用例。**

### 4.3 T-D2 的两个用例陷阱（已规避，写在代码注释里）

1. **`acflt_at()` 不能在长序列后段使用**。它依赖
   `force_ptw_bus_error_by_count(1)`，即"下一次 PTW 访存必须属于目标 walk"。
   这个假设只在 bringup 之后立即成立；跑过 8 组 `prefill_mb()`+page-fault 之后就不成立，
   表现为 `td_ac_0/td_ac_1: timed out waiting for L1DTLB access exception write`。
   → T-D2 改用 `pgflt_at(2, ..., iid=127)` / `pgflt_at(3, ..., iid=0)` 来关 iid[6:0] 极值。
2. **不要用 R=0/W=1 造 page fault**。那是 RISC-V 的**保留编码**，walker 会当成 pointer
   继续下探，参考模型报 `translate PAGE_FAULT (3-level exhausted)`。
   → 用 **execute-only（R=0,W=0,X=1）** 这个合法叶子，对 load 一样会 page fault。

### 4.4 T-B2 增益低于预估的原因

计划中 T-B2 预估约 760 位，实测 `mmu_l1dtlb` 只 +39 位。查 D 报告，`mmu_l1dtlb`
剩余 1560 个未覆盖方向位中占大头的是：

| 信号族 | 仍缺方向位数 |
|---|---:|
| `entry_flg_vec[*]` | 90 |
| `entry_ppn_vec[*]` | 34 |
| `mb_hitN_vec[*]` | 4 |
| 其余（`*_clk_en`、`issue_*`、`sysmap_mmu_flg*`、`dutlb_top_*`…） | 零散 |

`entry_flg_vec` / `entry_ppn_vec` 是 16 项 × 位宽的**并行读出向量**，其"缺的那一半"
与 §4.2 的 L1I 情形同源（V/A 位不可达、部分 entry 只在特定 PLRU 序列下被选中）。
真正的堵点不是"没扫到 entry"，而是**每个 entry 的某几个 flg 位在功能上不可达**。
→ 继续加宽 entry sweep 的边际收益已经很低；应转入豁免 + RTL 讨论。

### 4.5 RTL 问题单联动

本轮把 **B2 升级为 P0**（`doc/toggle_closure_rtl_issues.md`）：
`mmu_l1dtlb_hit_rd.sv` 中 `dutlb_off_pgs = 3'b0` → `dutlb_pre_pgs` →
`dutlb_fin_pgs = pre_sel ? pre_pgs : 3'b001`，导致
`mmu_lsu_page_size_x ∈ {3'b000, 3'b001}`，**永远报不出 2M/1G**；
`dutlb_entry_pgs` 对该输出零扇出。这解释了 `mmu_l1dtlb_hit_rd` 里一批 pgs 相关位
无论怎么造 huge page 都翻不动。新增 N1（`expt_wr0_eid == ptw_l1dtlb_ref_id`，
`mmu_l1dtlb.sv:309`）与 N2（L2→L1 重填无权限检查）。

---

## 五、剩余缺口与下一步

### 5.1 已判定为结构性不可达（建议进 `fullexclude.tgl`）

| 位置 | 位数 | 理由 |
|---|---:|---|
| `mmu_l1itlb.entryN_flg[0]` 1→0（30 项） | 30 | 无效化走独立 `vld` 寄存器，flg[0] 不回写 0 |
| `mmu_l1itlb.entryN_flg[5]` 1→0（30 项） | 30 | A=0 的 PTE 直接 page fault，永不装填 |
| `mmu_l1itlb.entryN_flg[3]` 1→0（剩 13 项） | 13 | `scd` 槽只能靠 scd→fst 交换晋升，而交换从不晋升 faulting 表项 |
| `mmu_l1dtlb.entry_flg_vec` 同源位 | ~90 | 与上同源（V/A 位） |

写豁免时务必遵守已验证的 elfile 语法：
声明串**范围写在名字后面**（`Toggle sig "logic sig[27:0]"` 有效，
`"logic [27:0] sig"` 会被静默忽略）；向量**不支持逐位切片**；
`// CHECKSUM: "<a> <b>"` 必须写在 `INSTANCE:` 行**之前**，否则报 `UCAPI-EL-MCM`。

### 5.2 需 RTL 讨论（不是用例问题）

- **B2（P0）**：`mmu_lsu_page_size_x` 恒为 4K/0 —— 若是 bug，修复后会自然打开一批 pgs 位。
- **B7（P0）**：iUTLB 的 U 位 S-mode 检查。
- **N2**：L2→L1 重填无权限检查 —— 现在被 T-I 当作覆盖率手段用，但功能上值得确认。
- **H-2（`mmu_l2tlb_rrpv_wbuf` 满）**：DEPTH=8、ARB_STALL_LEVEL=5、
  `pop_grant = ~arb_l2tlb_req`，在 arb 反压恒定的前提下 wbuf 无法真正填满 → 建议豁免（剩 4 位）。

### 5.3 仍值得写用例的方向（按性价比排序）

| 目标 | 剩余位 | 手段 |
|---|---:|---|
| `mmu_l2tlb_reqq_entry` 76.97% | 70 | reqq 深度/回绕 + 各类请求源混跑 |
| `mmu_l2tlb_mb` 89.49% / `mb_entry` 88.06% | 148 | L2 miss buffer 满 + 合并 + 冲刷 |
| `mmu_l2tlb_reqq` 91.59% | 94 | 与上同批 |
| `mmu_l1dtlb_install` 77.21% | 458 | install 侧仲裁/失效竞争矩阵（大头，值得单独排期） |
| `mmu_l1dtlb_expt_cam` 78.95% | 216 | 与 B2/N1 联动，先等 RTL 结论 |
| `ct_mmu_regs` 72.95% | 561 | CSR 全字段扫描（与 MMU 功能弱相关，优先级低） |

### 5.4 明确不做

- **§7.4 第 9 项（64 位 VA 参考模型以覆盖 off-path `pa[27:26]`，2 位）**：
  收益 2 位、改动面涉及参考模型地址位宽，**延期**。

---

## 六、复现方法

```bash
cd /x2025/GPrj1/IC1/mmu_verification/mmu_verification

# 1) 编译（约 3.5 分钟）
make comp

# 2) 逐个用例带覆盖率跑（COV_DB_DIR 必须是绝对路径）
make run_cov TEST_NAME=test_mmu_l1itlb_cov_toggle_flg_clear_001 SEED=1 \
     COV_DB_DIR=$PWD/output/coverage/toggle_w2.vdb
# …其余 5 个同理

# 3) 出报告（务必在工程根目录执行，否则报 URG-DNF）
urg -full64 \
    -dir output/coverage/phase14_merged.vdb \
    -dir output/coverage/toggle_new.vdb \
    -dir output/coverage/toggle_w2.vdb \
    -dir output/coverage/toggle_w2b.vdb \
    -elfile simu/exclude_v4.tgl -elfile simu/fullexclude.tgl \
    -excl_bypass_checks -metric tgl -format both \
    -report output/coverage/w2_refD_bp

# 4) 关键数字
grep -A3 "Total Coverage Summary" output/coverage/w2_refD_bp/dashboard.txt
grep -E "x_mmu_l1itlb|u_mmu_l1dtlb|x_mmu_l2tlb" output/coverage/w2_refD_bp/hierarchy.txt
```

---

## 七、结论

1. Wave-2 的 6 个用例把 `tb_top` toggle 从 **81.90 推到 82.46**，
   22 个 L1/L2 核心模块的未覆盖方向位从 **4 592 降到 4 249**（本轮 −343，累计 −2 556）。
   两轮合计：**77.71 → 82.46（+4.75）**。
2. 单点最大收益是 `ct_mmu_tlboper`（**+8.52%，闭合 116 位**），来自 T-H2 的
   tlbop/invall 全谱扫描；`mmu_arb` 达到 **99.25%**，
   `ct_mmu_l2tlb_rrpv_array` 与 `mmu_l2tlb_replacement_policy` **已 100%**。
3. 顺带修掉了一个影响所有 IFU toggle 用例的 **TB 驱动缺陷**（`raw_ifu_fetch` 多握一拍）。
4. L1 ITLB/DTLB 的 entry flg 位已经**逐位定性**：剩下的 1→0 缺口基本都是
   V/A 位的结构性不可达，以及 `scd` 槽的晋升路径限制。
   **继续堆用例的边际收益已趋近于零，下一步应转向豁免归档 + RTL 问题单（B2/B7/N2/H-2）闭环。**
5. 若要继续追覆盖率，性价比最高的靶子是 `mmu_l1dtlb_install`（剩 458 位）
   与 L2 的 reqq/mb 家族（剩 ~312 位）。
