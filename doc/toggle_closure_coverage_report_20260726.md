# Toggle 闭合用例覆盖率实测报告（2026-07-26）

对应计划：`doc/toggle_closure_plan.md`（v2，含 §六 实现落地记录）。
本报告回答 §六.6 遗留项 6："7 个新用例实测能闭合多少 toggle 缺口"。

---

## 〇、数据来源与可比性

| 项 | 值 |
|---|---|
| 基线 VDB | `output/coverage/phase14_merged.vdb`（2026-07-02 并行回归合并，1 个 merged test） |
| 基线报告 | `output/coverage/phase14_urgReport`（即 L1/L2 未覆盖代码报告所依据的口径） |
| 新增 VDB | `output/coverage/toggle_new.vdb`（本次 7 个用例，SEED=1，逐个串行累加） |
| 合并 VDB | `output/coverage/toggle_merged.vdb` |
| 合并报告 | `output/coverage/toggle_merged_urgReport`（`Number of tests: 8`） |
| 仅新用例报告 | `output/coverage/toggle_new_urgReport` |
| URG 命令 | `urg -full64 -dir <baseline> -dir <new> -elfile simu/exclude_v4.tgl -format both -dbname ... -report ...` |
| 排除文件 | `simu/exclude_v4.tgl`（与基线完全一致，**尚未加入本计划 §二-A 的新豁免**） |

**可比性核对**：逐模块比对 URG `Total Bits` 分母，21 个 L1/L2 模块**全部完全一致**
（例：`mmu_l1itlb` 5652=5652、`mmu_l1dtlb` 11038=11038、`mmu_l2tlb` 9182=9182），
说明两份 VDB 的设计覆盖模型同构，合并为同口径叠加，不存在分母漂移。

7 个用例的覆盖率运行全部 `rc=0`、`UVM_ERROR=0`、`UVM_FATAL=0`。

---

## 一、总览

### 1.1 全设计（tb_top）

| 指标 | 基线 | 合并后 | Δ |
|---|---:|---:|---:|
| SCORE | 89.16 | 90.28 | **+1.12** |
| LINE | 97.07 | 97.15 | +0.08 |
| COND | 87.83 | 88.91 | +1.08 |
| **TOGGLE** | **77.67** | **81.85** | **+4.18** |
| FSM | 96.32 | 96.32 | 0 |
| BRANCH | 95.23 | 95.39 | +0.16 |
| ASSERT | 88.12 | 88.43 | +0.31 |
| GROUP | 81.85 | 83.89 | +2.04 |

### 1.2 签核范围（三棵实例树）

| 实例树 | SCORE 基线→合并 | **TOGGLE 基线→合并** |
|---|---|---|
| `tb_top.u_dut.x_mmu_l1itlb` | 93.58 → 96.44 (+2.86) | **79.71 → 94.07 (+14.36)** |
| `tb_top.u_dut.u_mmu_l1dtlb` | 91.37 → 91.91 (+0.54) | **81.80 → 84.75 (+2.95)** |
| `tb_top.u_dut.x_mmu_l2tlb`  | 94.57 → 95.07 (+0.50) | **85.98 → 88.43 (+2.45)** |

### 1.3 位级闭合总账（21 个 L1/L2 模块，方向位口径）

| 项 | 数量 |
|---|---:|
| 基线未覆盖方向位 | 6064 |
| **本轮 7 个用例闭合** | **1898（31.3%）** |
| 剩余 | 4166 |
| 　├ 属计划 §二-A 死信号豁免候选 | 160 |
| 　└ 真实缺口（需后续用例） | 4006 |

---

## 二、分模块结果

| 模块 | 位数(方向) | 基线 TOGGLE | 仅新 7 例 | 合并后 | Δ | 0→1 基线→合并 | 1→0 基线→合并 |
|---|---:|---:|---:|---:|---:|---|---|
| `mmu_l1itlb` | 5652 | 73.90 | 90.32 | **92.57** | **+18.67** | 80.64 → 95.51 | 67.16 → 89.63 |
| `ct_mmu_iutlb_entry` | 674 | 88.13 | 93.62 | **98.52** | **+10.39** | 88.43 → 98.81 | 87.83 → 98.22 |
| `ct_mmu_iutlb_fst_entry` | 728 | 86.81 | 92.99 | **97.80** | **+10.99** | 89.84 → 99.45 | 83.79 → 96.15 |
| `mmu_l1dtlb` | 11038 | 81.88 | 61.54 | 85.51 | +3.63 | 89.45 → 91.01 | 74.31 → 80.01 |
| `mmu_l1dtlb_allocator` | 230 | 98.26 | 85.65 | 98.26 | +0.00 | 98.26 → 98.26 | 98.26 → 98.26 |
| `mmu_l1dtlb_expt_cam` | 1026 | 78.36 | 47.08 | 78.56 | +0.20 | 85.19 → 85.38 | 71.54 → 71.73 |
| `mmu_l1dtlb_hit_rd` | 2554 | 83.95 | 70.05 | 87.82 | +3.87 | 92.56 → 93.66 | 75.33 → 81.99 |
| `mmu_l1dtlb_install` | 2010 | 75.77 | 51.59 | 77.06 | +1.29 | 80.90 → 82.49 | 70.65 → 71.64 |
| `mmu_l1dtlb_scheduler` | 1094 | 87.75 | 61.15 | 89.12 | +1.37 | 89.95 → 91.77 | 85.56 → 86.47 |
| `mmu_l1dtlb_mb_entry` | 604 | 92.72 | 70.36 | 92.72 | +0.00 | 94.04 → 94.04 | 91.39 → 91.39 |
| `mmu_l2tlb` | 9182 | 86.75 | 69.79 | 90.50 | +3.75 | 87.67 → 91.00 | 85.82 → 90.00 |
| `mmu_l2tlb_mb` | 1104 | 89.49 | 78.89 | 89.49 | +0.00 | 89.49 → 89.49 | 89.49 → 89.49 |
| `mmu_l2tlb_mb_entry` | 268 | 88.06 | 83.21 | 88.06 | +0.00 | 88.81 → 88.81 | 87.31 → 87.31 |
| `mmu_l2tlb_reqq` | 1118 | 91.59 | 76.30 | 91.59 | +0.00 | 91.59 → 91.59 | 91.59 → 91.59 |
| `mmu_l2tlb_reqq_entry` | 304 | 76.97 | 74.67 | 76.97 | +0.00 | 76.97 → 76.97 | 76.97 → 76.97 |
| `mmu_l2tlb_replacement_policy` | 640 | 100.00 | 98.12 | 100.00 | +0.00 | — | — |
| `mmu_l2tlb_rrpv_wbuf` | 2298 | 99.83 | 29.94 | 99.83 | +0.00 | 99.83 → 99.83 | 99.83 → 99.83 |
| `ct_mmu_l2tlb_tag_array` | 1962 | 90.93 | 76.96 | 93.17 | +2.24 | 90.93 → 93.17 | 90.93 → 93.17 |
| `ct_mmu_l2tlb_data_array` | 1758 | 93.29 | 87.77 | **97.61** | **+4.32** | 93.29 → 97.84 | 93.29 → 97.38 |
| `ct_mmu_l2tlb_rrpv_array` | 522 | 100.00 | 99.62 | 100.00 | +0.00 | — | — |
| `ct_mmu_tlboper` | 1362 | 75.48 | 59.25 | 82.82 | **+7.34** | 76.06 → 84.14 | 74.89 → 81.50 |

> "仅新 7 例"列是这 7 个用例单独跑出的绝对覆盖率，仅供判断用例是否命中该模块，
> **不代表贡献**（大部分位早已被主回归覆盖）。判断贡献只看 Δ 列。

### 2.1 逐模块位级闭合

| 模块 | 基线未覆盖 | 闭合 | 剩余 | 闭合率 |
|---|---:|---:|---:|---:|
| `mmu_l1itlb` | 1477 | **1055** | 422 | 71.4% |
| `ct_mmu_iutlb_entry` | 80 | 70 | 10 | 87.5% |
| `ct_mmu_iutlb_fst_entry` | 96 | 80 | 16 | 83.3% |
| `mmu_l1dtlb` | 1458 | 170 | 1288 | 11.7% |
| `mmu_l1dtlb_hit_rd` | 410 | 99 | 311 | 24.1% |
| `mmu_l1dtlb_install` | 249 | 6 | 243 | 2.4% |
| `mmu_l1dtlb_expt_cam` | 222 | 2 | 220 | 0.9% |
| `mmu_l1dtlb_scheduler` | 82 | 0 | 82 | 0.0% |
| `mmu_l1dtlb_mb_entry` | 44 | 0 | 44 | 0.0% |
| `mmu_l1dtlb_allocator` | 4 | 0 | 4 | 0.0% |
| `mmu_l2tlb` | 984 | 196 | 788 | 19.9% |
| `ct_mmu_l2tlb_data_array` | 118 | **76** | 42 | 64.4% |
| `ct_mmu_l2tlb_tag_array` | 178 | 44 | 134 | 24.7% |
| `ct_mmu_tlboper` | 334 | 100 | 234 | 29.9% |
| `mmu_l2tlb_mb` | 120 | 0 | 120 | 0.0% |
| `mmu_l2tlb_reqq` | 96 | 0 | 96 | 0.0% |
| `mmu_l2tlb_reqq_entry` | 70 | 0 | 70 | 0.0% |
| `mmu_l2tlb_mb_entry` | 38 | 0 | 38 | 0.0% |
| `mmu_l2tlb_rrpv_wbuf` | 4 | 0 | 4 | 0.0% |
| **合计** | **6064** | **1898** | **4166** | **31.3%** |

---

## 三、计划点名信号的逐条验收

评审意见 §④ 点名的遗漏项、以及 §一 各任务的显式验收信号：

| 信号 | 所属任务 | 基线 | 合并后 | 结论 |
|---|---|---|---|---|
| `ifu_mmu_va[62]`（评审点名"未列入任何任务"） | T-A Phase 1 | 0→1 / 1→0 均缺 | **两向均覆盖** | ✅ 闭合 |
| `entry0_vpn[26]`（VPN 高位） | T-A Phase 1 | 两向均缺 | **两向均覆盖** | ✅ 闭合 |
| `entry0_ppn[27:25]`（高 PA） | T-A Phase 2 | 缺 | **覆盖** | ✅ 闭合 |
| `mmu_ifu_pa[27:25]`、`mmu_ifu_pa[23:20]` | T-A Phase 2 | 两向均缺 | **两向均覆盖** | ✅ 闭合 |
| `entry31_*`（iTLB 尾部条目） | T-A Phase 1 全 32 项扫描 | 大量缺 | 31 项闭合 / 14 项剩 | 🟡 大部闭合 |
| `l2tlb_data_dout[*]`（way3 FLG/PPN 高位） | T-F | 118 缺 | 闭合 76 | 🟡 64% |
| `l2tlb_tag_dout[*]` | T-F | 178 缺 | 闭合 44 | 🟡 25% |
| `dutlb_top_ref_cur_st[2:0]` | §二-A(b) 豁免 | 缺 | 仍缺（6） | ⚪ 豁免候选（已验证确为死信号） |
| `mmu_lsu_stall0/1` | §二-A(b) 豁免 | 缺 | 仍缺（4） | ⚪ 豁免候选 |
| `issue_req` / `issue_vpn` / `issue_eid` | §二-A(b) 豁免 | 缺 | 仍缺（62） | ⚪ 豁免候选 |
| `expt_wr1_acflt` | §二-A(b) 豁免 | 缺 | 仍缺（2） | ⚪ 豁免候选 |
| `req0/1_port_id`（T-E 取消依据） | §二-A(b) 豁免 | 缺 | 仍缺（4） | ⚪ 豁免候选，**证实 T-E 取消正确** |
| `iutlb_bypass_vld` | §二-A(b) 豁免 | 1→0 缺 | 仍缺（2） | ⚪ 豁免候选 |
| `credit_cnt`（scheduler） | §二-A(a) 豁免 | 缺 | 仍缺（2） | ⚪ 豁免候选（CREDIT_MAX=8） |
| `rrpv_wbuf count[3]` / `fifo_full` | H-2 待可达性分析 | 缺 | 仍缺（4） | ⚪ 未做 force，符合计划 |

**结论**：评审最关心的两条——`ifu_mmu_va[62]` 全缺、以及"只缺 1→0 需两轮互补"——
均在实测中验证有效：`mmu_l1itlb` 的 1→0 从 67.16% 拉到 89.63%（+22.47），
提升幅度显著大于 0→1（+14.87），说明两轮制针对性生效。

---

## 四、对照 §四 验收口径

计划验收口径：**豁免生效后**的合并 URG 中，L1 各模块 TOGGLE ≥ 92%
（install/scheduler/mb_entry/allocator = 100%）；L2 各模块 ≥ 93%（tag/data array ≥ 99%）。

当前**豁免尚未加入** `exclude_v4.tgl`，故只能给出未豁免口径的达标情况：

| 模块 | 目标 | 现值 | 达标 |
|---|---:|---:|:--:|
| `mmu_l1itlb` | ≥92 | 92.57 | ✅ |
| `ct_mmu_iutlb_entry` | ≥92 | 98.52 | ✅ |
| `ct_mmu_iutlb_fst_entry` | ≥92 | 97.80 | ✅ |
| `mmu_l1dtlb_mb_entry` | 100 | 92.72 | ❌ |
| `mmu_l1dtlb` | ≥92 | 85.51 | ❌ |
| `mmu_l1dtlb_hit_rd` | ≥92 | 87.82 | ❌ |
| `mmu_l1dtlb_scheduler` | 100 | 89.12 | ❌ |
| `mmu_l1dtlb_allocator` | 100 | 98.26 | ❌（差 4 位，全为 `port_id` 豁免候选 → 豁免后即 100） |
| `mmu_l1dtlb_expt_cam` | ≥92 | 78.56 | ❌ |
| `mmu_l1dtlb_install` | 100 | 77.06 | ❌ |
| `mmu_l2tlb_replacement_policy` | ≥93 | 100.00 | ✅ |
| `ct_mmu_l2tlb_rrpv_array` | ≥99 | 100.00 | ✅ |
| `mmu_l2tlb_rrpv_wbuf` | ≥93 | 99.83 | ✅（差 4 位，全为 H-2 待定项） |
| `ct_mmu_l2tlb_data_array` | ≥99 | 97.61 | ❌（差 42 位） |
| `ct_mmu_l2tlb_tag_array` | ≥99 | 93.17 | ❌（差 134 位） |
| `mmu_l2tlb` | ≥93 | 90.50 | ❌ |
| `mmu_l2tlb_reqq` | ≥93 | 91.59 | ❌ |
| `mmu_l2tlb_mb` | ≥93 | 89.49 | ❌ |
| `mmu_l2tlb_mb_entry` | ≥93 | 88.06 | ❌ |
| `mmu_l2tlb_reqq_entry` | ≥93 | 76.97 | ❌ |

**判定**：iTLB 侧（3 个模块）已达标；D-TLB 与 L2 侧未达标。
未达标的根因不是用例失效，而是**计划本身的覆盖预测偏乐观**：
§四 预测"测试新增覆盖 ~915 条"，实测这 7 个用例闭合了 1898 个方向位——
数量上远超预测，但计划漏估了 D-TLB entry 阵列与 L2 队列的规模（见下节）。

---

## 五、剩余缺口分析与后续建议

### 5.1 已验证为结构性死信号（应走豁免，不应再写用例）

本轮实测在计划 §二-A 名单外**新确认**两组硬连线常量：

| 信号 | RTL 依据 | 位数 |
|---|---|---:|
| `mmu_l1itlb.iutlb_off_flg[8:0]` | `mmu_l1itlb.sv:2232` `= {sysmap_mmu_flg2[4:0], 5'b00010, 3'b111, 1'b1}` → 低 9 位为常量 | 18 |
| `mmu_l1dtlb_hit_rd.dutlb_off_flg[8:0]` | `mmu_l1dtlb_hit_rd.sv:256` `= {sysmap_mmu_flg_x[4:0], 5'b00110, 3'b111, 1'b1}` | 18 |
| `mmu_l1dtlb_hit_rd.dutlb_pre_flg[8:0]` | `:272` 直接 `= dutlb_off_flg` 的别名 | 18 |
| `mmu_l1dtlb_hit_rd.dutlb_off_pgs` / `dutlb_pre_pgs` | `:257` `= 3'b0`（4K 常量）、`:273` 别名 | 12 |

加上 §二-A 原名单，剩余 4166 位中至少 **160 位**属豁免候选，
豁免后可直接换算：`mmu_l1dtlb_allocator` → 100%、`mmu_l2tlb_rrpv_wbuf` → 100%（若 H-2 判定不可达）。

### 5.2 真实缺口 Top（4006 位），按"下一步该写什么用例"归并

| 优先级 | 缺口簇 | 剩余位 | 现象与建议 |
|---|---|---:|---|
| P0 | `mmu_l1dtlb.entry_flg_vec` + `entry_ppn_vec`（同时出现在 `hit_rd`） | 460 | **D-TLB 16 条目的 flg/ppn 阵列缺乏逐条目多值写入**。T-B/T-C 只针对高 PA 与尾部条目，未做 T-A 那样的"32 条目 × 多轮互补值"扫描。**建议新增 T-B2：把 T-A 的 entry sweep 方法照搬到 D-TLB**（16 条目 × ≥3 轮 `pat_ppn`/flg 互补），预计一次闭合 400+ 位 |
| P0 | `mmu_l1dtlb_install` / `scheduler` 的 `mb_entry_{ppn,vpn,flg,pgs}[7:0]` | ~300 | MB 高编号条目（6、7）几乎不被多值填充。建议在 T-B2 中把 8 个 MB slot 全部占满并逐 slot 灌不同 PPN/VPN/FLG（可复用 T-D 的 `prefill_mb` + 单调 VA） |
| P0 | `mmu_l1dtlb_expt_cam.ent[2..7].vpn` | 190 | expt_cam 条目 2–7 的 VPN 位从未多值。T-D 只把 CAM 填到低编号。建议 T-D2：连续制造 ≥8 个不同 VA 的故障，强制 CAM 8 条目全占 |
| P1 | `ct_mmu_l2tlb_tag_array.l2tlb_tag_dout[*]` | 134 | T-F 已闭合 44 位（din 全闭合），dout 侧还差 134。需要**读出**含这些位的 tag，即写入后必须真正命中/TLBR 读回。建议 T-F2：写入互补 tag 后逐条 TLBR 读回 |
| P1 | `mmu_l2tlb` 的 `final_way_*` / `raw_way_*` / `*_vpn_1g` / `arb_l2tlb_vpn_internal` | ~450 | 8 way 的 way 级旁路总线需要"命中在不同 way 且 VPN 位型互补"。建议 T-G2：对同一 set 的 8 个 way 逐一命中，每 way 用互补 VPN/ASID/PPN |
| P1 | `ct_mmu_tlboper` 的 `tlboper_tag_din`/`regs_tlboper_cur_vpn`/`invall_cnt`/`invasid_cnt`/`jtlb_cnt`/`tlb_vpn_aft_mask` | 234 | TLBWI/TLBWR 的写入值与 INV 计数器位型单一。建议 T-H2：TLBWI 灌互补 VPN/ASID，并跑一次完整 INVALL（让 `invall_cnt` 走满 0→255） |
| P2 | `mmu_l2tlb_reqq_entry.entry_asid`/`entry_out_asid` 各 32 | 64 | reqq 条目的 ASID 字段位型单一。需要在 L2 请求队列里排队多个**不同 ASID** 的请求（并发深度 + ASID 轮换，即计划 H-1） |
| P2 | `mmu_l2tlb_mb.gen_entries[*].local_alloc_l2_queue_id` | 64 | 8 个 MB 条目的 queue_id 字段。需要 8 路并发 miss 且 queue id 分布互补 |
| P2 | `mmu_l1itlb.entry{10..31}_flg[7:10]`、`flg[0/3/5] 1→0` | ~300 | flg[3]=X、flg[5]=A 在合法 PTE 下恒为 1（否则装入前即 fault），**1→0 可能结构不可达**；flg[7:10] 来自 sysmap/PMP 属性通道。**先做可达性分析，再决定用例 or 豁免** |
| P2 | `mmu_l1dtlb.lsu_mmu_stamo_pa0` | 56 | STAMO 通道 PA 位型单一，需要 AMO 类访存并给出高位 PA |

### 5.3 结论

1. 7 个用例**本身有效**：单靠它们就把 21 个 L1/L2 模块的未覆盖方向位削掉 31.3%，
   iTLB 三个模块直接跨过 92% 验收线，`ifu_mmu_va[62]` 等评审点名的信号全部闭合。
2. **未达标模块的共性**是"阵列/队列的逐条目多值写入"，而不是新的机理问题——
   T-A 已经证明这种扫描方法有效，只是没有推广到 D-TLB entry / MB / expt_cam / L2 way。
   §5.2 的 P0 三条（T-B2 / T-D2）预计可再闭合约 950 位。
3. 计划 §四 的验收口径要成立，仍必须先完成 §六.6 的第 1 项（豁免落地）。

---

## 六、复现方法

```bash
cd mmu_verification
make comp

# 1) 7 个用例跑覆盖率，累加到独立 VDB（勿污染 output/simv.vdb）
for t in test_mmu_l1itlb_cov_toggle_entry_sweep_001 \
         test_mmu_l1dtlb_cov_toggle_highpa_1g_001 \
         test_mmu_l1dtlb_cov_toggle_tail_001 \
         test_mmu_l1dtlb_cov_toggle_expt_cam_001 \
         test_mmu_l2tlb_cov_toggle_sram_001 \
         test_mmu_l2tlb_cov_toggle_highaddr_001 \
         test_mmu_l2tlb_cov_toggle_small_modules_001 ; do
  make run_cov TEST_NAME=$t SEED=1 UVM_ERR_ONLY=1 \
       COV_DB_DIR=$PWD/output/coverage/toggle_new.vdb RUN_DIR=output/rc_$t
done

# 2) 与基线合并出报告
urg -full64 \
    -dir $PWD/output/coverage/phase14_merged.vdb \
    -dir $PWD/output/coverage/toggle_new.vdb \
    -elfile $PWD/simu/exclude_v4.tgl -format both \
    -dbname $PWD/output/coverage/toggle_merged.vdb \
    -report $PWD/output/coverage/toggle_merged_urgReport

# 3) 提取分模块 / 位级差异（本次新增的三个小工具）
python3 scripts/urg_modinfo_toggle.py output/coverage/phase14_urgReport/modinfo.txt      mmu_l1itlb ... > base_mod.json
python3 scripts/urg_modinfo_toggle.py output/coverage/toggle_merged_urgReport/modinfo.txt mmu_l1itlb ... > merged_mod.json
python3 scripts/urg_toggle_bits.py    output/coverage/phase14_urgReport        mmu_l1itlb ... > bits_base.json
python3 scripts/urg_toggle_bits.py    output/coverage/toggle_merged_urgReport  mmu_l1itlb ... > bits_merged.json
python3 scripts/urg_toggle_bitdiff.py bits_base.json bits_merged.json modlist.txt   # 位级 closed/left 表
```

| 脚本 | 作用 |
|---|---|
| `scripts/urg_modinfo_toggle.py` | 从 URG `modinfo.txt` 抽取模块级 SCORE/LINE/COND/TOGGLE/FSM/BRANCH/ASSERT 与 toggle 位统计 → JSON |
| `scripts/urg_toggle_bits.py` | 从 URG HTML（`modlist.html` + `modNN.html`）抽取**逐信号/逐位** Toggle / 1→0 / 0→1 明细 → JSON |
| `scripts/urg_toggle_bitdiff.py` | 展开 `sig[hi:lo]` 位区间后做两份报告的位级 diff，输出 closed/left 清单（写到 `/tmp/bd_<mod>.json`） |
