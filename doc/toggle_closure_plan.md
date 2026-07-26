# MMU TLB Toggle Coverage 闭合计划（v2 修订版）

> 基准报告：L1TLB — URG `Thu Jul 2 00:07:17 2026`；L2TLB — URG `Sun Jun 21 22:44:xx 2026`
> 编写日期：2026-07-26　　修订日期：2026-07-26　　作者：IC1
>
> **v2 修订说明**：v1 评审中对照 RTL / 覆盖率报告 / TB 逐条核查后发现三类问题并全部修正：
> ① 约 50+ bit 的目标信号在 RTL 中是硬连线常量或未驱动死信号（`assign ... = 1'b0` / 赋值被注释 / 例化硬连），
> 　v1 为其安排了测试任务但物理上不可覆盖——全部移入豁免清单并提 RTL 问题单（见 §二、§二-B）；
> ② 大量缺口只缺 **1→0 方向**（0→1 已覆盖），v1 的单轮"写高值"填充无法闭合——所有填充类 phase 改为
> 　**≥2 轮互补 pattern**；
> ③ 若干激励参数/机理错误（ASID=0xA5A5 的 bit14=0 恰好盖不住报告点名的 `*_asid[14]`；tag bit0 实为
> 　G 位而非 VPN[0]/ASID[0]；`plru_iutlb_ref_num` 是 one-hot 而非计数器；VA 示例超出 39 位；
> 　credit_cnt 豁免理由中 CREDIT_MAX 应为 8）——全部更正。
> 另：任务 T-E 整体取消（目标信号为例化硬连常量），T-C 大幅缩水，T-A 补充 1G 取指页与 flag 多样化轮次。
> **v2 复核补遗（同日）**：对照评审逐条复核后再修两处遗留——① 评审点名的 `ifu_mmu_va[62]`
> 列入 T-A Phase 1（经核实 TB `mmu_vseq_va64` 符号扩展可自然双向覆盖，见 §五 #11）；
> ② T-B Phase 2 的 VPN[23] 示例 VA 数值更正（§五 #12）。其余评审点经 RTL/报告/TB 交叉核实
> 均已在 v2 正文落实。

---

## 〇、执行前置条件（新增）

1. **先刷新覆盖率基线再动工**：L2TLB 基准报告是 6/21 URG，而 6/22 已合入并跑通 19 个覆盖用例
   （`test_mmu_l2tlb_cov_toggle_sweep`/`cond_769`(G 位)/`mb_cond` 等，见
   `doc/l2tlb_uvm_review/l2tlb_covp_closure_implementation_log.md`）。T-F/T-G/T-H 的部分目标可能已被
   覆盖。执行顺序：全量回归 → 重跑 URG → 按新基线对本计划各任务逐项裁剪。
2. L1TLB 基线（7/2）相对较新，但 `test_mmu_l1dtlb_cov_toggle_entry_sweep_001`（512 次 LFSR 填充）
   的覆盖只在独立 VDB 验证过，尚未合入全量 VDB——合并后 install/scheduler/mb_entry 预计直接到
   100%（豁免后），T-B 无需重复这三个模块的工作。
3. 豁免文件更新（§二）应与测试开发**并行先行**，因为豁免直接决定各模块可达上限。

---

## 一、Toggle 缺口总览（数字按报告校正）

> 口径说明（v1 有误，此处更正）：
> - L1TLB：原始未覆盖 toggle 记录 **1620** 条（端口 636 + 内部 984），合并后唯一模式 **784** 项
>   （v1 把 784 误标为"原始条目"）；
> - L2TLB：原始 **294** 条（端口 120 + 内部 174），合并后 **203** 项（v1 的"203 原始条目"实为合并数）。
> - 下表"未翻转 bit 数"取报告《翻转覆盖薄弱模块》表；`mmu_l1dtlb_scheduler_sva`/`mb_entry_sva` 两行
>   该表疑似给的是合并模式数（汇总表分别为 20/8 个未覆盖对象），已加注。

### 1.1 L1TLB

| 模块 | TOGGLE % | 未翻转 bit 数 | 主要信号族 | 对应任务 |
|---|---:|---:|---|---|
| `mmu_l1dtlb` | 81.88 | **497**（v1 误记 467） | entry_flg_vec / entry_ppn_vec / mb_entry_* / 尾部功能信号 | T-B / T-C |
| `mmu_l1itlb` | 73.90 | **421** | entryN_ppn/flg/pgs（32 entry 参数化位段） | T-A |
| `mmu_l1dtlb_hit_rd` | 83.95 | 158 | entry_flg_vec / entry_ppn_vec（下游） | T-B（联动） |
| `mmu_l1dtlb_hit_rd_sva` | 83.35 | 141 | 同 hit_rd | T-B（联动） |
| `mmu_l1dtlb_sva` | 86.71 | 99（v1 误记 95） | entry_ppn/vpn/pgs 高位 | T-B（联动） |
| `mmu_l1dtlb_install` | 75.77 | 70（v1 误记 66） | mb_entry_ppn/vpn/flg/pgs（entry_sweep 独立 VDB 已证 100%） | 已有 sweep |
| `mmu_l1dtlb_install_sva` | 72.70 | 70（v1 误记 66） | 同 install | 已有 sweep |
| `mmu_l1dtlb_expt_cam` | 78.36 | **56**（v1 误记 7，7 是合并模式数） | ent[N].vpn/iid / same_hit_entry 等 | T-D |
| `ct_mmu_iutlb_fst_entry` | 86.81 | 25 | utlb_*ppn/flg 高位 | T-A |
| `mmu_l1dtlb_scheduler` | 87.75 | 21（v1 误记 20） | mb_entry_vpn 高位（sweep 已证 18/19 + credit_cnt[4] 豁免） | 已有 sweep |
| `ct_mmu_iutlb_entry` | 88.13 | 21（v1 误记 19） | utlb_*ppn/flg 高位 | T-A |
| `mmu_l1dtlb_mb_entry` | 92.72 | 4（薄弱模块表；v1 记 11） | ppn_r/flg_r 高位（sweep 已证 100%） | 已有 sweep |
| `mmu_l1dtlb_mb_entry_sva` | 93.85 | 2（汇总表 8） | 同 mb_entry | 已有 sweep |
| `mmu_l1dtlb_scheduler_sva` | 84.51 | 2（汇总表 20，疑合并数） | 同 scheduler | 已有 sweep |
| `mmu_l1dtlb_allocator` | 98.26 | 3 | cpurst_b / req0/1_port_id（**全部豁免**，见 §二） | T-I / 豁免 |
| `mmu_l1dtlb_expt_cam_sva` | 99.41 | 1 | 已接近收口 | T-D（联动） |

### 1.2 L2TLB

| 模块 | TOGGLE % | 未翻转 bit 数 | 主要信号族 | 对应任务 |
|---|---:|---:|---|---|
| `mmu_l2tlb` | 85.18 | 168（v1 误记 160） | tag/data dout bus、PPN/PA 高位、ASID 高位 | T-F / T-G |
| `ct_mmu_l2tlb_tag_array` | 90.21 | 49 | 各 way G 位（bit0）×25、ASID/VPN 高位 | T-F |
| `ct_mmu_l2tlb_data_array` | 91.47 | 20 | 各 way FLG[4]（聚合示例 bit130）×10、PPN 高位 | T-F |
| `mmu_l2tlb_reqq` | 91.32 | 17（v1 误记 7） | d_req_type / bypass_grant_vec[8:4] / entry ASID | T-H |
| `mmu_l2tlb_mb` | 89.04 | 17（v1 误记 7） | entry_rdy_vec/ffr_oh/entry_grant_vec[8:4] / queue_id | T-H |
| `mmu_l2tlb_mb_entry` | 86.19 | 10 | entry_queue_id / entry_eid / entry_type | T-H |
| `mmu_l2tlb_reqq_entry` | 74.67 | 8 | entry_asid / entry_type | T-H |
| `mmu_l2tlb_rrpv_wbuf` | 99.78 | 3 | count[3] / fifo_full / rst_n | T-H(专项)/T-I |
| `mmu_l2tlb_replacement_policy` | 99.84 | 1 | rst_n | T-I |
| `ct_mmu_l2tlb_rrpv_array` | 99.62 | 1 | pad_yy_icg_scan_en | 豁免 |

---

## 二、豁免清单（Waiver，v2 大幅扩充）

### 二-A：结构性不可翻转信号（全部经 RTL 核实，附证据行号）

以下信号**物理上不可能**通过任何测试翻转，直接加入 `mmu_verification/fullexclude.tgl`，
并在豁免文档中登记证据。

**（a）v1 已列、v2 核实通过（个别理由更正）**

| 信号 | 出现模块 | RTL 证据 / 豁免理由 |
|---|---|---|
| `pad_yy_icg_scan_en` | 所有模块 | DFT 扫描信号，功能仿真恒 0 |
| `hpcp_mmu_cnt_en` | `mmu_l1dtlb`、`mmu_l1itlb` | 性能计数使能，TB 静态（报告仅缺 0→1） |
| `biu_mmu_smp_disable` | `mmu_l1dtlb`、`mmu_l1dtlb_hit_rd` | SMP disable，TB 静态 |
| `credit_cnt[4]` | `mmu_l1dtlb_scheduler` | **理由更正**：`CREDIT_MAX=8`（`mmu_l1dtlb.sv:855`，v1 误写 16）；计数器宽度 `[$clog2(8+1):0]=[4:0]`，复位值 8=5'b01000，最大值即 8，bit[4]=1 需计数 ≥16，结构不可达 |
| `dutlb_req_id_older` | `mmu_l1dtlb_hit_rd` | TB 场景单方向；沿用 7/2 报告 sweep 方法学既有豁免 |
| `lsu_mmu_stamo_vld0` / `lsu_mmu_stamo_pa0` | `mmu_l1dtlb` | `mmu_l1dtlb.sv:562` `assign lsu_mmu_stamo_vld0 = 1'b0` 硬连线 |
| `final_par_fail`、**`l2tlb_arb_par_clr`** | `mmu_l2tlb` | `mmu_l2tlb.sv:865-866` `final_par_fail=1'b0`，且 `l2tlb_arb_par_clr = final_par_fail`——v1 中"需确认"项已确认：**同源恒 0，一并豁免** |

**（b）v2 新增：v1 误安排为测试目标的死信号 / 常量（约 50+ bit）**

| 信号 | 出现模块 | RTL 证据 | v1 原安排（作废） |
|---|---|---|---|
| `dutlb_top_ref_cur_st[2:0]` / `dutlb_top_ref_type` / `dutlb_top_scd_updt` | `mmu_l1dtlb`（输出端口） | `mmu_l1dtlb.sv:1304-1306` `assign ... = '0; // TODO` stub | T-C 三种激励 |
| `mmu_lsu_stall0` / `mmu_lsu_stall1` | `mmu_l1dtlb`、`mmu_l1dtlb_hit_rd` | `mmu_l1dtlb_hit_rd.sv:151` `assign mmu_lsu_stall_x = 1'b0` | T-C MB 满背压 |
| `dutlb_inst_id_hit` | `mmu_l1dtlb_hit_rd` | `hit_rd.sv:222-223` 赋值整段被注释，未驱动网 | T-C 同 inst_id 双端口 |
| `issue_req` / `issue_vpn[26:0]` / `issue_eid[2:0]` | `mmu_l1dtlb` | `mmu_l1dtlb.sv:257-259` 声明；唯一使用处 `1063-1066` 被注释——31 bit 死信号 | T-C 高 VPN issue |
| `dutlb_fin_pgs[2:1]`、`mmu_lsu_page_size_x[2:1]`（两端口实例） | `mmu_l1dtlb_hit_rd`、`mmu_l1dtlb` | `hit_rd.sv:284` `fin_pgs = pre_sel ? pre_pgs(=3'b0) : 3'b001`；`:153` page_size 直连 fin_pgs——**命中恒报 4K**，2M/1G 命中也不会置位 | T-C "同 T-B 1G/2M 构造" |
| `dutlb_off_pgs[2:0]` / `dutlb_pre_pgs[2:0]` | `mmu_l1dtlb_hit_rd` | `hit_rd.sv:257` `= 3'b0` 常量；`:273` pre=off | T-C off-chip 路径 |
| `dutlb_off_flg[8:0]` / `dutlb_pre_flg[8:0]` | `mmu_l1dtlb_hit_rd` | `hit_rd.sv:256` `= {sysmap_flg[4:0], 5'b00110, 3'b111, 1'b1}`——低 9 bit 常量拼接；**仅 [13:9]（sysmap 段）可翻**，保留在 T-C | T-C off-chip 路径 |
| `iutlb_off_pgs[2:0]` / `iutlb_off_flg[8:0]` | `mmu_l1itlb` | `mmu_l1itlb.sv:2230` `= 3'b1` 常量；`:2232` 低 9 bit 常量拼接，仅 [13:9] 可翻 | T-A Phase 5 |
| `iutlb_bypass_vld` | `mmu_l1itlb` | `mmu_l1itlb.sv:508` `= 1'b0`（真实赋值 `:507` 被注释） | T-A Phase 5 |
| `expt_wr1_acflt` | `mmu_l1dtlb`、`mmu_l1dtlb_expt_cam`（输入） | `mmu_l1dtlb.sv:323` `= 1'b0`（wr0 侧 `:313` 为活逻辑） | T-C / T-D Phase 2 |
| `req0_port_id` / `req1_port_id` | `mmu_l1dtlb_allocator` | `mmu_l1dtlb.sv:826/832` 例化硬连 `.req0_port_id(1'b0)`, `.req1_port_id(1'b1)` | **T-E 整个任务** |

**（c）复位方向（不入豁免，走 T-I mid-reset）**

| 信号 | 处理 |
|---|---|
| `cpurst_b` 1→0（各模块） | T-I 中途复位覆盖，不豁免 |
| `rst_n` 1→0（`mmu_l2tlb_replacement_policy`、`mmu_l2tlb_rrpv_wbuf`） | 同上（确认与 cpurst_b 同源后随 T-I） |

> **操作**：(a)+(b) 合计豁免约 **110~120 条原始缺口**（v1 估 60~70）。豁免文件更新后重跑 URG，
> 各模块可达上限同步修正（尤其 `mmu_l1dtlb_hit_rd`：stall/inst_id/fin_pgs/off·pre 常量段集中在此，
> 豁免后其分母显著变化）。

### 二-B：RTL 问题单（新增，与豁免同步提交设计侧）

豁免只解决覆盖率报表问题；下列 stub/死代码建议同时给设计提单确认：

| 编号 | 问题 | 影响 |
|---|---|---|
| B1 | `dutlb_top_ref_cur_st/ref_type/scd_updt` 输出 TODO stub（`mmu_l1dtlb.sv:1304-1306`） | 顶层观测口无信息，确认是否废弃或待实现 |
| B2 | `mmu_lsu_page_size` 命中恒报 4K（`hit_rd.sv:284`） | **潜在功能缺陷**：LSU 若依赖 page size（如合并/对齐判断），2M/1G 命中时拿到错误值 |
| B3 | `issue_req/vpn/eid` 死代码（`mmu_l1dtlb.sv:257-259,1063-1066`） | 建议清理 |
| B4 | `iutlb_bypass_vld = 1'b0` stub（`mmu_l1itlb.sv:507-508`） | bypass 功能未实现或废弃，需确认 |
| B5 | `expt_wr1_acflt = 1'b0`（`mmu_l1dtlb.sv:323`） | JTLB 路径 access-fault 信息被丢弃，确认是否设计意图 |
| B6 | `mmu_lsu_stall_x = 1'b0`（`hit_rd.sv:151`） | MB 满时对 LSU 无背压，确认上游如何处理 |

---

## 三、测试任务详表

### T-A：iUTLB Entry Full Sweep（最高优先级）

**目标模块**：`mmu_l1itlb`（421）、`ct_mmu_iutlb_entry`（21）、`ct_mmu_iutlb_fst_entry`（25）
**预计覆盖原始缺口**：~440 条（豁免 iutlb_off_flg[8:0]/off_pgs/bypass_vld 约 13 bit 后）

#### 信号分析（v2 按报告方向数据修正）

| 信号族 | 未覆盖内容与**方向** | 条目数 | 根因与对策 |
|---|---|---:|---|
| `entryN_flg[4]`（32 entries） | **双向全缺**（U 位从未为 1） | 32 | 从未安装 U=1 用户页；Phase 3 双向覆盖 |
| `entryN_flg[3:0]`、`flg[6:5]`（≈30 entries 各） | **只缺 1→0**（0→1 已覆盖） | ~59 | 已装入 flg 低位=1 的页但从未被 flg=0 的页**重写**；Phase 4b flag 多样化重写轮 |
| `entryN_flg[10:9]`、`flg[8:7]` | 多数只缺 1→0，部分双缺 | ~60 | sysmap/pmp 属性页 + 回落轮（Phase 4/4b） |
| `entryN_ppn` 高位（[27:20] 等） | 高位多为**双缺**，中位（[11:10]/[15:14]）多**只缺 1→0** | 123 | 高 PA 填充（0→1）+ **互补第二轮**（1→0）；Phase 1 两轮制 |
| `entryN_pgs[2:1]` | **双向全缺**（2M/1G 从未装入） | ~50 | pgs[1]：Phase 2（2M）；**pgs[2]：Phase 2b（1G，v1 遗漏）**；各含回落轮 |
| `entryN_vpn[26,25,21]` | 高位 | 5 | VA[38:33] 遍历（Phase 1 VPN 规划） |
| `utlb_swp/upd_ppn` 高位（两 entry 模块） | 同 ppn | 38 | 随 Phase 1/2 交换/更新路径联动 |
| `utlb_entry_ppn/flg` 高位 | entry 输出 | 24 | 同上 |
| `mmu_ifu_pa`、`iutlb_hit_pa_fst/scd`、`pa_fin/aft_bypass`、`iutlb_pa_buf` 高位 | 组合输出总线，双向随访问序列自然覆盖 | 11 | 高 PA 命中后接低 PA 命中即可 |
| `iutlb_off_flg[13:9]` | sysmap 段（低 9 bit 已豁免） | – | sysmap flag 配置变化（Phase 5） |
| `iutlb_disable_vld` | MMU disable 路径 | 1 | `mmu_l1itlb.sv:510` 活逻辑（`va_vld && off_hit`）；Phase 5 |
| `iutlb_flg_aft_bypass[4]` / `flg_fin[4]` | U 位输出 | 2 | 随 Phase 3 联动 |
| `plru_iutlb_ref_num[8]` | **机理更正**：该信号是 refill 目标 entry 的 **one-hot**（`ct_mmu_iplru.v:369 = refill_num_onehot`），bit[8] 即"entry8 被 refill"，**不是** v1 所述"refill 计数 ≥256" | 1 | Phase 1 填满 32 entry 时自然覆盖，无需专门 phase |
| `ifu_mmu_va[62]`（评审补，v2 初稿遗漏） | **双向全缺**（现有测试取指 VA 均在 VA[38]=0 段） | 1 | TB `mmu_vseq_va64` 按 VA[38] 符号扩展（`mmu_vseq_lib.svh:14-15`），且接口映射 `ifu_mmu_va[62]=va64[63]`——Phase 1 Round A 的 VA[38]=1 地址自动置 1（canonical 合法，不触发 `iutlb_va_illegal`），Round B 低 VA 回 0；**列为 Phase 1 显式验收信号** |
| ~~`iutlb_bypass_vld`~~ / ~~`iutlb_off_flg[8:0]`~~ / ~~`iutlb_off_pgs`~~ | — | ~13 | **已移豁免**（§二-B(b)） |

#### 激励策略（v2：两轮制 + 新增 1G）

```
Phase 1: 4K 页两轮互补填满 32 entry（覆盖 ppn 双向 + vpn 高位 + ref_num one-hot + va[62]）
  Round A: PA 基址 0x0800_0000，LFSR 使 ppn[27:20] 各 bit 出现 1（0→1）
           VA 规划：32 个 VPN 遍历 VA[38:33] 各值（39'h40_0000_0000=VPN[26]、
           39'h20_0000_0000=VPN[25]、39'h02_0000_0000=VPN[21] 等合法 39-bit 值）；
           VA[38]=1 的地址经 TB 符号扩展（mmu_vseq_va64: va64[63:39] 全 1）自动使
           ifu_mmu_va[62] 完成 0→1——canonical 合法地址，不触发 iutlb_va_illegal，
           正常走 miss→refill
  Round B: 同一批 VPN 重新 miss/refill，PPN 改为按位取反（或低 PA 0x0000_xxxx），
           使每 entry 每 bit 完成 1→0；VA 回落到 VA[38]=0 段使 ifu_mmu_va[62] 1→0
  注：entry8 在 Round A 被 refill 即覆盖 plru_iutlb_ref_num[8]（one-hot）

Phase 2: 2M 页（pgs[1]）两轮 → 16 个 FST entry（ct_mmu_iutlb_fst_entry）
  Round A 高 PA / Round B 低 PA；结束后用 4K 页重写同 entry 使 pgs[1] 回 0

Phase 2b（新增）: 1G 页（pgs[2]）两轮
  安装 1G 取指页（VPN[8:0]=0 对齐），填 FST/主 entry；再用 4K/2M 重写使 pgs[2] 回 0
  ——v1 信号表列了 pgs[0..2] 但激励只有 2M，此 phase 补齐 pgs[2] 双向

Phase 3: U 位双向（flg[4] 双缺）
  supervisor mode 安装 U=0 页取指（保持 0）→ user mode 安装/访问 U=1 页（0→1）
  → 同 entry 再装 U=0 页（1→0）

Phase 4: sh/prot/sec 属性（flg[10:7]，含回落轮）
  sysmap_mmu_flg2[0]=1（SO）、pmp_mmu_flg2[3]=1 组合安装属性页 → 恢复普通属性页重写

Phase 4b（新增）: flag 低位多样化重写轮（flg[3:0]/[6:5] 只缺 1→0）
  JTLB refill 携带多样化 PTE flag（含低 flag 组合，如 A/D/W/R 相关位为 0 的模式）
  重写已含 flg=1 的 entry——若 refill 数据通路对某些 flag 位有 force-1 逻辑，
  执行中标注为新的结构豁免候选并留证

Phase 5: disable / off 路径
  短暂 cp0_mmu_en=0 触发 iutlb_disable_vld；sysmap flag2 配置变化翻转 iutlb_off_flg[13:9]
  （bypass_vld 已豁免，不再构造 PA-direct 场景）
```

#### 新增文件（不变）

| 文件 | 类型 | 说明 |
|---|---|---|
| `testbench/test/l1itlb_tests/test_mmu_l1itlb_cov_toggle_entry_sweep_001.svh` | 测试包装 | 调用下方 vseq |
| `testbench/env/mmu_vseq_lib.svh`（追加） | vseq 类 | `mmu_l1itlb_toggle_entry_sweep_vseq`（Phase 1~5，两轮制） |

#### 覆盖预测（豁免修正后口径）

| 模块 | 预测 TOGGLE | 当前 | 达成前提 |
|---|---:|---:|---|
| `mmu_l1itlb` | ≥ 92% | 73.90% | 两轮制 + Phase 2b/4b 落实；off_flg 低位等已豁免 |
| `ct_mmu_iutlb_entry` | ≥ 97% | 88.13% | 同上 |
| `ct_mmu_iutlb_fst_entry` | ≥ 97% | 86.81% | 含 1G 轮次 |

---

### T-B：dTLB 1G 大页 + 高物理地址填充（两轮制）

**目标模块**：`mmu_l1dtlb`、`mmu_l1dtlb_sva`、`mmu_l1dtlb_hit_rd`、`mmu_l1dtlb_hit_rd_sva`
（install/scheduler/mb_entry 三模块由已有 `toggle_entry_sweep_001` 收口，本任务只做增量）
**预计覆盖原始缺口**：~250 条

#### 信号分析（方向标注）

| 信号族 | 方向 | 条目数 | 对策 |
|---|---|---:|---|
| `l1dtlb_ent_pgs[N][2]` / `mb_entry_pgs[1][2]` | 双缺（1G 从未装入） | ~18 | Phase 1 1G refill + 回落轮 |
| `entry_ppn[N][27:24]` / `l1dtlb_ent_ppn` 高位 | **只缺 1→0 为主**（如 entry_ppn[3][8]×26 的 0→1 已覆盖） | ~88 | 高 PA 轮（补 0→1 双缺位）+ **低 PA 重写轮（关键，闭 1→0）** |
| `mb_entry_ppn[0][15]` 等 MB 高位 | 只缺 1→0 | ~26 | 多轮 miss 自然重写（已有 sweep 具备；确认合并） |
| `l1dtlb_ent_vpn[N][23]` / `mb_entry_vpn[N][25]` | 只缺 1→0 为主 | ~37 | 高 VPN 轮 + 低 VPN 重写轮 |
| `entry_flg[1][1:0]` / `l1dtlb_ent_flg[1][1:0]` | 只缺 1→0（V/R 恒 1） | 30 | 用 flg 低位=0 的 PTE 重写（联动 T-A Phase 4b 思路） |
| `entry_flg_vec`（flg[4]=U 段） | 1→0 缺 57、0→1 缺 14 | 88（dtlb+hit_rd+hit_rd_sva） | supv-only（U=0）页安装在**曾装过 U=1 的 entry** 上（1→0）+ U=1 轮（0→1） |
| `jtlb_utlb_ref_ppn[27:24]` / `utlb_refill_vpn[26]` | ref 总线 | 3 | 随高 PA/高 VPN refill 联动 |

#### 激励策略

```
Phase 1: 高物理地址 + 三种页大小，两轮制
  Round A: PA 基址 0x0800_0000——16×4K miss→PTW refill；4×2M；4×1G（VPN[8:0]=0 对齐）
  Round B: 同批 VA 重新 miss，PPN 取反/低 PA 重写同 entry（闭 ppn 1→0）；
           1G/2M entry 用 4K 重写（闭 pgs 1→0）

Phase 2: 高 VPN 双向（v1 示例 VA 超 39 位，更正）
  Round A: VA = 39'h50_0000_0000（VPN[26]=VPN[24]=1）、39'h20_0000_0000（VPN[25]）、
           39'h08_0000_0000（VPN[23]=VA[35]；v2 初稿误写 39'h00_8000_0000，那是 VPN[19]）
           等合法值 miss→refill
  Round B: 低 VPN 重写同 entry（闭 vpn 高位 1→0）

Phase 3: supv-only 页（flg[4] 双向）
  先 user 页填 entry（U=1，补 0→1 缺 14）→ supervisor 安装 U=0 页重写同 entry（闭 1→0 缺 57）
  → user mode 访问 U=0 页产生 page fault（联动 dutlb_fin_flg[4] 场景）

Phase 4: 双端口命中（hit_rd/hit_rd_sva 联动）
  双端口同时访问已 install 的高/低 PPN 页，将 entry_flg_vec/ppn_vec 变化传递到下游

Phase 5（新增）: dtlb 侧 flag 低位重写
  用 R=0/V=0 语义的 PTE 数据 refill 曾为全 1 的 entry（entry_flg[1][1:0] 1→0）；
  若 install 通路对 V 位 force-1，标注结构豁免候选并留证
```

#### 与现有测试的关系（更新）

- `test_mmu_l1dtlb_cov_toggle_entry_sweep_001`（512 次 LFSR 双向填充）已独立 VDB 验证覆盖
  install/scheduler/mb_entry 全部 gap——**本任务不重复**，等全量合并确认即可。
- `test_mmu_l1dtlb_cov_cond_1190_1194_huge_001` 的 1G 页构造逻辑复用于 Phase 1。

#### 新增/修改文件（不变）

| 文件 | 类型 | 说明 |
|---|---|---|
| `testbench/test/l1dtlb_tests/test_mmu_l1dtlb_cov_toggle_highpa_1g_001.svh` | 新增测试 | 高 PA + 1G + 两轮制 sweep |
| `testbench/env/mmu_l1dtlb_coverage_vseq.svh`（追加） | vseq 类 | `mmu_l1dtlb_toggle_highpa_1g_vseq` |

#### 覆盖预测

| 模块 | 预测 TOGGLE | 当前 | 备注 |
|---|---:|---:|---|
| `mmu_l1dtlb` | ≥ 88% | 81.88% | 需两轮制；死信号豁免后分母修正 |
| `mmu_l1dtlb_sva` | ≥ 92% | 86.71% | |
| `mmu_l1dtlb_hit_rd` | ≥ 90% | 83.95% | stall/inst_id/fin_pgs/off·pre 常量豁免后 |
| `mmu_l1dtlb_hit_rd_sva` | ≥ 90% | 83.35% | 同上 |
| `mmu_l1dtlb_install`(+sva) | 100% / ≥98% | 75.77/72.70 | 由已有 sweep 合并达成 |
| `mmu_l1dtlb_scheduler` / `mb_entry` | 100% | 87.75/92.72 | 同上（credit_cnt[4] 豁免） |

---

### T-C：dTLB 尾部功能信号（v2 大幅缩水：死信号已剔除）

**目标模块**：`mmu_l1dtlb`、`mmu_l1dtlb_hit_rd` 存活尾部信号
**预计覆盖原始缺口**：~15 条（v1 估 ~35，其中约 20 bit 经核实为死信号，已移 §二-B(b) 豁免）

#### 存活信号与激励

| 信号 | 状态 | 激励方法 |
|---|---|---|
| `dutlb_fin_flg[0]` | 可达 | 同一测试内先后出现"可翻译区 miss（pre_sel=0 且无 hit → fin_flg=0）"与"命中（=1）" |
| `dutlb_fin_flg[13:9]`/`dutlb_off_flg[13:9]` | 可达（仅 sysmap 段） | sysmap flag 配置变化（sysmap_cfg_agent 中途重配） |
| `dutlb_pa_buf[27]` | 可达 | 高 PA 命中后接低 PA 命中（随 T-B Phase 1 联动） |
| `ctc_inv_va_hit_clr[15:9]` | 可达 | entry 9..15 valid 后逐一发 VA invalidate（同时闭 `a_va8_inv_clears_matching_entry` SVA 缺口） |
| `sysmap_mmu_flg0[0]` / `sysmap_mmu_flg1[0]` | 可达 | port0/port1 访问地址配置到 sysmap SO region，再切回非 SO（双向） |
| `pmp_mmu_flg1[3]` | 可达 | PMP 覆盖 port1 地址且 M-mode lock=1，再解除（双向） |
| `mb_hit1_vec[4]` | 可达 | MB entry0..4 pending 后 port1 再次访问 entry4 的 VPN |
| `mb_clk_en`/`sched_clk_en`/`dplru_clk_en`/`dutlb_clk_en` | 待确认 | 已有 `test_mmu_l1dtlb_cov_gateclk_001`；合并后仍缺则查 cp0_mmu_icg_en 切换 |
| `cp0_mmu_mpp[0]` | 可达 | mpp 在 M/S/U 编码间切换（报告缺 0→1） |
| ~~mmu_lsu_stall0/1、dutlb_top_ref_*、dutlb_inst_id_hit、issue_*、dutlb_fin_pgs[2:1]、mmu_lsu_page_size_x[2:1]、dutlb_off_pgs、dutlb_off_flg[8:0]、expt_wr1_acflt~~ | **死信号** | **已移 §二-B(b) 豁免 + §二-B 问题单** |

#### 新增/修改文件（不变）

| 文件 | 类型 | 说明 |
|---|---|---|
| `testbench/test/l1dtlb_tests/test_mmu_l1dtlb_cov_toggle_tail_001.svh` | 新增测试 | 存活尾部信号组合 |
| `testbench/env/mmu_l1dtlb_coverage_vseq.svh`（追加） | vseq 类 | `mmu_l1dtlb_toggle_tail_vseq` |

---

### T-D：expt_cam 专项覆盖

**目标模块**：`mmu_l1dtlb_expt_cam`（**56 个未翻 bit**，v1 误记 7——7 是合并模式数）
**预计覆盖原始缺口**：~50 条（expt_wr1_acflt 已豁免）

#### 信号分析（Phase 2 机理更正）

| 信号 | 方向 | 激励方法 |
|---|---|---|
| `ent[1].vpn[25]`（×14，双向部分缺） | 双向 | 多个不同 VPN 的 fault 依次写入，含 bit25=1 与 =0 交替 |
| `ent[2].vpn[26:20]`/`[14:12]`（双缺） | 双向 | VPN 相应位 ≠0 的 fault 写 entry2，再写 =0 的 fault |
| `ent[3].vpn[19:15]`/`[11:10]`、`ent[3].iid[2:1]` | 1→0 为主 | 高位=1 写入后用低位值重写 entry3 |
| `same_hit_entry` | 0→1 | port0/port1 同拍命中同一 expt entry（复用 `test_mmu_l1dtlb_cov_expt_entry_precise_001` 双端口逻辑；同时闭 `a_expt_entry_overlap_is_terminal_replay`） |
| `hit1_vec[3]` / `hit1_use_vec[6:3]` | 0→1 | entry3..6 填充后 port1 逐一命中 |
| `same_wr_eid` | 0→1，**高难度** | 需 `expt_wr0_vld`（PTW acc err 完成）与 `expt_wr1_vld`（JTLB pgflt refill）**同拍**且 eid 相同（`expt_cam.sv:130`）；需精确时序控制 PTW/JTLB 响应延时。若窗口不可构造，做可达性论证后豁免 |
| ~~`expt_wr1_acflt`~~ | — | **`mmu_l1dtlb.sv:323` 硬连 0，已豁免** |

#### 激励策略（Phase 2 更正）

```
Phase 1: PTW acc fault 依次填 entry0..3（VPN 覆盖 [26:10] 各位、iid[2:1]≠0），
         随后用互补 VPN/iid 的 fault 重写（闭 1→0）
Phase 2（更正）: JTLB **page fault** 写入路径
  v1 写的是"JTLB refill 返回 acc_fault"——该路径 acflt 位是 stub；
  但 expt_wr1_vld = jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt（mmu_l1dtlb.sv:315）是活逻辑，
  构造 JTLB refill 携带 pgflt=1 即可经 port1 写入 ent[N]（覆盖 wr1 侧 iid/vpn 写入路径），
  并为 Phase 2b 的 same_wr_eid 提供 wr1 激励源
Phase 2b: same_wr_eid 时序窗口尝试（PTW acc err 与 JTLB pgflt 同拍、同 eid）
Phase 3: 双端口同命中（same_hit_entry）
Phase 4: port1 依次命中 entry3..6（hit1_vec[3]、hit1_use_vec[6:3]）
```

#### 新增/修改文件（不变）

| 文件 | 类型 | 说明 |
|---|---|---|
| `testbench/test/l1dtlb_tests/test_mmu_l1dtlb_cov_toggle_expt_cam_001.svh` | 新增测试 | expt_cam VPN/iid/same_hit 专项 |
| `testbench/env/mmu_l1dtlb_coverage_vseq.svh`（追加） | vseq 类 | `mmu_l1dtlb_toggle_expt_cam_vseq` |

---

### T-E：~~dTLB allocator 端口 ID 信号~~（v2 取消）

**取消原因**：`req0_port_id`/`req1_port_id` 在例化处硬连常量
（`mmu_l1dtlb.sv:826` `.req0_port_id(1'b0)`、`:832` `.req1_port_id(1'b1)`），
无论哪个端口发起 miss 都不可能翻转。v1 的"port1 发起 miss"方案无效。
两信号移入 §二-B(b) 豁免；`mmu_l1dtlb_allocator` 剩余缺口仅 `cpurst_b` 1→0（T-I 覆盖），
豁免+T-I 后该模块 TOGGLE 预计 100%。

---

### T-F：L2TLB SRAM 输出位翻转（bit 映射按 RTL 更正）

**目标模块**：`ct_mmu_l2tlb_tag_array`（49）、`ct_mmu_l2tlb_data_array`（20）、`mmu_l2tlb` dout_bus（~45）
**预计覆盖原始缺口**：~110 条

#### 位段映射（v2 更正，依据 `ct_mmu_tlboper.v:1085-1095` 组包与阵列注释）

```
tag（每 way 48 bit）  = {VLD[47], VPN[46:20], ASID[19:4], PGS[3:1], G[0]}
data（每 way 42 bit） = {PPN[41:14], FLG[13:0]}
```

| 报告信号 | v1 判断 | **v2 实际含义** | 对策 |
|---|---|---|---|
| `l2tlb_tag_dout[0]` ×25 | "VPN[0] 或 ASID[0]" | **各 way 的 G（global）位** | Step 3（G=1 全局页）覆盖——v1 的"奇数 VPN"对此无效 |
| `l2tlb_tag_dout` 高位散列位段 | ASID/VPN 扩展位 | way-bit [19:4]=ASID 各位、[46:44] 等=VPN 高位 | Step 1/2 |
| `l2tlb_tag_din[18]` ×2 | "bit[18] 未为 1" | **ASID[14]** | Step 1 的 ASID 值必须含 bit14=1（v1 的 0xA5A5 bit14=0，**恰好盖不住**） |
| `l2tlb_data_dout[130]` ×10 | "G/sec/SO 标志位" | **各 way 的 FLG[4]**（130=3×42+4，即 way3 相对位 4；聚合含其余 way） | Step 3 属性页（G/U 相关 flag）写入读出 |
| `l2tlb_data_dout` 各 way [41:33] 段 | 高 PPN | PPN[27:19] ✓（v1 正确） | Step 4 |
| `l2tlb_data_din[37:35]` | "flg 域" | **PPN[23:21]**（din 相对位 37:35 落在 PPN 段） | Step 4 高 PPN 写入 |

#### 激励策略（两轮制）

```
复用/扩展现有 mmu_l2tlb_toggle_sweep_vseq（先按 §〇 刷新基线裁剪）：

Step 1: ASID 双向全位段
  Round A: CP0.ASID=0xFFFF（或 0xAAAA）miss→填充→命中读出（覆盖 tag ASID 段 0→1，
           含 tag_din[18]=ASID[14]）
  Round B: ASID=0x0000（或 0x5555）重复（闭 1→0；同时闭 regs_l2tlb_cur_asid[15:5] 的 1→0）

Step 2: VPN 双向（理由更正：与 tag bit0 无关）
  高 VPN（39'h7F_FFFF_F000 一类）与低 VPN 两轮填充，覆盖 tag way-bit [46:44] 等 VPN 段

Step 3: G=1 全局页（tag bit0 ×25 + data FLG 位）
  TLBWI/PTW 安装 G=1 条目填满 8 way 并命中读出（0→1）→ G=0 条目重写同 set/way（1→0）
  （G 位写入通路已有先例：cond_769 用例 "Vary global bit"，mmu_l2tlb_coverage_vseq.svh:1086）

Step 4: 高 PPN 两轮（data 各 way PPN[27:19] + data_din[37:35]）
  PA > 0x0800_0000 与低 PA 交替填充

Step 5: 2M/1G 页（tag way-bit [3:1] PGS 段）两轮
```

#### 新增/修改文件（不变）

| 文件 | 类型 | 说明 |
|---|---|---|
| `testbench/env/mmu_l2tlb_coverage_vseq.svh`（追加/修改） | vseq 扩展 | `mmu_l2tlb_toggle_sweep_vseq` 增加 Step 1..5（两轮制） |
| `testbench/test/l2tlb_tests/test_mmu_l2tlb_cov_toggle_sram_001.svh` | 新增测试 | 调用扩展后的 sweep vseq |

#### 覆盖预测

| 模块 | 预测 TOGGLE | 当前 |
|---|---:|---:|
| `ct_mmu_l2tlb_tag_array` | ≥ 99% | 90.21% |
| `ct_mmu_l2tlb_data_array` | ≥ 99% | 91.47% |
| `mmu_l2tlb`（dout_bus 相关） | ≥ 93% | 85.18% |

---

### T-G：L2TLB 功能信号（Global 页/多类型请求/高 VPN）

**目标模块**：`mmu_l2tlb` 尾部功能信号（~50 条）
**预计覆盖原始缺口**：~48 条（par_clr 豁免后）

信号清单与 v1 相同，以下为**修正点**：

| 项 | v1 | v2 修正 |
|---|---|---|
| ASID 示例值 | 0xA5A5（bit14=0，盖不住 `l2tlb_tlbr_asid[14]`/`final_idx_asid[14]`） | **0xFFFF↔0x0000 两轮**（或 0xAAAA/0x5555 交替）；`regs_l2tlb_cur_asid[15:5]` 只缺 1→0，**测试尾部必须切回低 ASID** |
| VA 示例 | "VA[38:12]=0x5_0000_0000"（35 bit 值填 27 bit 字段） | 合法 39-bit VA：`39'h50_0000_0000`（VPN[26,24]=1）、`39'h7F_FFFF_F000`（VPN 全 1）等 |
| `l2tlb_arb_par_clr` | "需确认是否豁免" | **已确认豁免**：`mmu_l2tlb.sv:866` `= final_par_fail`（恒 0），移 §二-A(a) |
| 其余（G 页、2M/1G VPN mask、TLBR/TLBW、PFU 高地址 secure、ITLB-type 请求、fb_hit/miss 时序等） | — | 保留 v1 方案；执行前按新基线裁剪（6/22 的 19 个用例可能已覆盖部分） |

**新增/修改文件**（不变）：`mmu_l2tlb_toggle_highaddr_vseq` + `test_mmu_l2tlb_cov_toggle_highaddr_001.svh`

---

### T-H：L2TLB 小模块专项

**目标模块**：`mmu_l2tlb_reqq`（17）、`mmu_l2tlb_reqq_entry`（8）、`mmu_l2tlb_mb`（17）、`mmu_l2tlb_mb_entry`（10）、`mmu_l2tlb_rrpv_wbuf`（2 + rst_n 走 T-I）
**预计覆盖原始缺口**：~40 条（rrpv_wbuf 满属高风险项，单列）

#### H-1：并发深度 / 类型 / ASID（保留 v1 方案，参数核实无误）

- MB `TOTAL_DEPTH = 1 + DTLB_DEPTH(8) = 9` ✓（`mmu_l2tlb_mb.sv:63`），L1 dtlb 侧
  `MB_DEPTH=8`、scheduler `CREDIT_MAX=8` ✓——8 个并发 dTLB miss + 2 个 ITLB miss 可将
  entry4..8 推入 ready/grant/bypass（`entry_rdy_vec/ffr_oh/entry_grant_vec/bypass_grant_vec[8:4]`）。
- 类型位（`d_req_type[1:0]`/`alloc_type`/`entry_type`）：混入 ITLB miss（type[1]=1）与
  store 类请求（type[0]），TB 为全 MMU DUT（`ct_mmu_top`），ifu_agent 可直接产生 ITLB miss ✓。
- ASID/EID：ASID 用 **0xFFFF↔0x0000 两轮**（同 T-F Step 1，v1 的 0xA5A5 作废）；
  EID[2]=1 需第 5+ 个并发 dtlb miss（eid≥4）。
- `entry_queue_id[3:0]`/`alloc_queue_id`：reqq 高 ID entry（≥4）分配给 MB 时出现，随并发深度自然覆盖。

#### H-2：rrpv_wbuf 满（count[3]/fifo_full + 3 条配套 SVA）——**高风险专项**（v2 重写）

v1 一笔带过（"参考 sva_targeted 的 wbuf 填满方法"），但 6/22 实现日志明确记录该方法**失败**：

- 自然填充到不了 full：`wbuf_pop_grant = ~arb_l2tlb_req`，lookup 间隙的空闲拍都会 pop；
- `uvm_hdl_force` fifo_full/count/pop_grant 均触发 `a_idle_keeps_count` 断言炸。

参数事实：例化 `DEPTH=8`（`mmu_l2tlb.sv:1077`，覆盖模块默认 4）→ `count[3:0]`，full=8；
`ARB_STALL_LEVEL = DEPTH-3 = 5`。

**v2 处置**：先做 30 分钟级可达性分析，再决定测试或豁免——

```
分析问题：count 能否到 8？
  push 条件 = eviction（RRPV 写回）；pop 条件 = ~arb_l2tlb_req（arbiter 空闲拍）
  ⇒ 需要构造"arb_l2tlb_req 连续有效（压住 pop）且每拍/隔拍产生 evict push"的流：
     背靠背 miss→refill→evict 流水（不同 set，命中率 0，全部触发替换写回）
  关键检查点：ARB_STALL_LEVEL=5 的 stall 机制是否在 count≥5 时切断新 lookup——
     若切断则 push 源同步消失，count 理论上限 5+in-flight(≤3)，恰好 8 或 <8 需精确推演
结论 A（可达）：编写背靠背 evict 流用例（同时闭 3 条 rrpv_wbuf SVA + c_rrpv_wbuf_true_full_block）
结论 B（不可达）：写结构豁免论证（count[3]/fifo_full + 3 条 SVA 一并豁免），
     并给设计提单确认 ARB_STALL_LEVEL 与 DEPTH 的裕量设计意图
```

#### 新增/修改文件（不变）

| 文件 | 类型 | 说明 |
|---|---|---|
| `testbench/env/mmu_l2tlb_coverage_vseq.svh`（追加） | vseq 类 | `mmu_l2tlb_toggle_small_modules_vseq` |
| `testbench/test/l2tlb_tests/test_mmu_l2tlb_cov_toggle_small_modules_001.svh` | 新增测试 | 5+ 并发 miss + 高 ASID/EID（+ wbuf 专项视 H-2 结论） |

---

### T-I：中途复位（cpurst_b / rst_n 1→0 方向）

（v1 方案可行，保留；补充说明）

- 复用 `assert_mid_test_reset()`（`mmu_l1_l2_tlb_common_vseq.svh:122/274` 已实现）；
- L2TLB：`test_mmu_l2tlb_cov_mid_reset` 已存在，但**基准报告（6/21）早于该测试入库（6/22）**，
  当前缺口不代表测试无效——刷新基线后确认，若已闭合则本项仅剩 L1 侧；
- L1TLB：在 T-A/T-B 测试末尾插入 `assert_mid_test_reset()`（各模块 cpurst_b 的 0→1 已覆盖，
  只补 1→0）；
- `mmu_l2tlb_replacement_policy`/`mmu_l2tlb_rrpv_wbuf` 的 `rst_n`：确认与 cpurst_b 同源后随
  L2 mid-reset 覆盖。

**预计覆盖原始缺口**：~12 条。

---

## 四、修订后预测汇总与验收口径

| 类别 | 预计闭合方式 | 数量（原始条目） |
|---|---|---:|
| 测试新增覆盖（T-A/B/C/D/F/G/H/I） | 8 个任务（T-E 取消） | ~915 |
| 结构豁免（§二-A a+b） | fullexclude.tgl + 豁免文档 | ~110–120 |
| 已有用例待合并（l1dtlb toggle_entry_sweep_001、L2 6/22 批次） | 全量回归合并 | ~150–200 |
| 残余（same_wr_eid 时序窗、rrpv_wbuf 满、flag force-1 待查项等） | 可达性论证后二次决策 | ~30–50 |

**验收口径**：豁免生效后的合并 URG 中——
L1 各模块 TOGGLE ≥ 92%（install/scheduler/mb_entry/allocator = 100%）；
L2 各模块 TOGGLE ≥ 93%（tag/data array ≥ 99%，wbuf 视 H-2 结论）。

## 五、v1 → v2 修订对照（供评审追溯）

| # | v1 问题 | v2 处置 |
|---|---|---|
| 1 | ~50+ bit 死信号被安排为测试目标（stall/top_ref_*/inst_id_hit/issue_*/fin_pgs[2:1]/page_size[2:1]/off_pgs/off_flg[8:0]/bypass_vld/expt_wr1_acflt/port_id） | 全部移 §二-A(b) 豁免 + §二-B 问题单；T-E 取消、T-C 缩水、T-A Phase5/T-D Phase2 改写 |
| 2 | 单轮填充无法闭合"只缺 1→0"的主力缺口 | T-A/T-B/T-F 全部改两轮互补制；ASID/高 PA/高 VPN 测试尾部回落 |
| 3 | ASID=0xA5A5 的 bit14=0 | 改 0xFFFF↔0x0000（或 0xAAAA/0x5555） |
| 4 | tag bit0 误判为 VPN[0]/ASID[0]（实为 G 位）；data bit130 实为 FLG[4]；tag_din[18]=ASID[14]；data_din[37:35]=PPN[23:21] | T-F 位段映射表整体重写 |
| 5 | plru_iutlb_ref_num 误判为计数器（实为 one-hot） | T-A Phase 6 删除，归并 Phase 1 |
| 6 | credit_cnt 豁免理由 CREDIT_MAX 写成 16（实为 8） | §二-A(a) 更正 |
| 7 | VA 示例超 39 位 | 全部改合法 39-bit 值 |
| 8 | T-A 缺 1G 取指页、缺 flg[3:0]/[6:5] 重写激励 | 新增 Phase 2b/4b |
| 9 | rrpv_wbuf 满沿用已失败的方法 | H-2 改为可达性分析 → 测试或豁免二选一 |
| 10 | L2 基线陈旧（6/21 报告 vs 6/22 已入 19 用例）、台账数字多处与报告不符 | 新增 §〇 前置条件；§一 全表校正并注明 v1 误记值 |
| 11 | **（v2 复核补遗）**评审 §四 点名的 `ifu_mmu_va[62]`（双向全缺，报告 toggle 端口表 `mmu_l1itlb:33`）v2 初稿仍未列入任何任务 | 列入 T-A Phase 1 显式验收信号：TB `mmu_vseq_va64` 对 VA[38] 符号扩展 + 接口映射 `ifu_mmu_va[62]=va64[63]`，Round A 高 VA（canonical 合法）0→1 / Round B 低 VA 1→0，无需新增 phase |
| 12 | **（v2 复核补遗）**T-B Phase 2 示例 `39'h00_8000_0000` 误标 VPN[23]（实为 VPN[19]） | 更正为 `39'h08_0000_0000`（VPN[23]=VA[35]）；T-A Phase 1 同步给出 VPN[26]/[25]/[21] 显式 VA 值 |

---

## 六、实现落地记录（2026-07-26，按 v2 计划创建用例）

### 6.1 新增文件

| 文件 | 内容 |
|---|---|
| `testbench/env/mmu_toggle_closure_vseq.svh`（新增，~1090 行） | 8 个 vseq：`mmu_toggle_l1_base_vseq` / `mmu_l1itlb_toggle_entry_sweep_vseq`(T-A) / `mmu_l1dtlb_toggle_highpa_1g_vseq`(T-B) / `mmu_l1dtlb_toggle_tail_vseq`(T-C) / `mmu_l1dtlb_toggle_expt_cam_vseq`(T-D) / `mmu_toggle_l2_base_vseq` / `mmu_l2tlb_toggle_sram_vseq`(T-F) / `mmu_l2tlb_toggle_highaddr_vseq`(T-G) / `mmu_l2tlb_toggle_small_modules_vseq`(T-H)；T-I 以 `mid_test_reset_with_tlbop()` 挂在 T-A/T-B 尾部（无 `+MMU_TLBOP_RESET_MODE` 时优雅空转） |
| `test/l1itlb_tests/test_mmu_l1itlb_cov_toggle_entry_sweep_001.svh` | T-A 测试壳（`phase9_generated_test_base`） |
| `test/l1dtlb_tests/test_mmu_l1dtlb_cov_toggle_highpa_1g_001.svh` | T-B 测试壳（`l1dtlb_directed_test_base`） |
| `test/l1dtlb_tests/test_mmu_l1dtlb_cov_toggle_tail_001.svh` | T-C 测试壳 |
| `test/l1dtlb_tests/test_mmu_l1dtlb_cov_toggle_expt_cam_001.svh` | T-D 测试壳 |
| `test/l2tlb_tests/test_mmu_l2tlb_cov_toggle_sram_001.svh` | T-F 测试壳（`l2tlb_phase6e_test_base`） |
| `test/l2tlb_tests/test_mmu_l2tlb_cov_toggle_highaddr_001.svh` | T-G 测试壳 |
| `test/l2tlb_tests/test_mmu_l2tlb_cov_toggle_small_modules_001.svh` | T-H 测试壳 |

集成改动：`env/mmu_env_pkg.sv` 追加 include；`test/phase9_common/phase9_generated_test_base.svh`
的 `start_vseq_by_name()` 追加 7 个分支；三个 suite（`l1itlb_tests_suite.svh` /
`l1dtlb_tests_suite.svh` / `l2tlb_phase6e_tests.svh`）追加 include。`make comp` 0 error。

### 6.2 为覆盖高半 VA 而新增的两个 raw 驱动（关键）

评审 §四 点名的 `ifu_mmu_va[62]` 与 `entry_vpn[26]` 之所以一直全缺，根因是**现有 TB 无法产生
canonical 的高半 VA**：

- `ifu_driver` 驱动 `ifu_mmu_va <= tr.va >> 1`，`ifu_mmu_va[62]` 恒 0；
- `l1dtlb_directed_vseq::canon_va()` = `{25'b0, va}`（零扩展），高半 VA 会踩
  `dutlb_va_illegal`（`mmu_l1dtlb_hit_rd.sv:165`）/ `iutlb_va_illegal`（`mmu_l1itlb.sv:548`）。

因此在 `mmu_toggle_l1_base_vseq` / `mmu_toggle_l2_base_vseq` 内各实现：
`raw_pipe0_hi()`（用 `mmu_vseq_va64()` 符号扩展后整 64 bit 驱 `lsu_mmu_va0`）与
`raw_ifu_fetch()`（直接驱 `ifu_mmu_va = va64[63:1]`，并等 `mmu_ifu_pavld`）。
两者都保持 canonical，因此高半 VA 走正常翻译路径而非非法 VA 路径。

### 6.3 Bring-up 中发现并修正的问题（本次实现自查）

| # | 现象 | 根因 | 处置 |
|---|---|---|---|
| 1 | T-A 5 条 `[IFU] PA mismatch`（VA=0x04_0000_0000，dut 恒返回旧 PPN） | Phase 2b 的 1G 窗口 `(i+16)<<30` 与 `itlb_va(3)`(=1<<34) **同属 L1 slot 16**，1G leaf 覆盖掉该 VA 的 4K 子树，后续 `map_round` 再也改不动该页 | 1G 窗口改 `(i+17)<<30`（避开 itlb_va 占用的 slot {0,4,8,16,32,64,128,256,511} 与 2M 窗口 slot 1）；同一坑在 T-B 已核查无冲突 |
| 2 | T-A 2 条 M 模式 `PA mismatch`（VA=0x7F_FFFF_F000 / 0x40_0000_0000） | bare/M 模式 RTL 输出 `pa[27:0] = va64[39:12]`，canonical 高半 VA 的符号位使 `pa[27]=1`；`mmu_ref_model::translate()` 只收 39 bit VA 并零扩展（`mmu_ref_model.svh:555`） | T-A Phase 5 的 off-path VA 全部限制在低半区（改 `0x3F_FFFF_F000` / `0x20_0000_0000`）。**off-path `pa[27:26]` 仍缺**，需 ref model 打通 64 bit VA 后再闭合 → 记入残余项 |
| 3 | T-B 结尾 `TLB busy did not clear`，`l1d_mb=0xff` 8 个 entry 卡 state=3 | Phase 5 用 `map_4k(v=1,r=0,w=0,x=0)`——在末级这是**非叶编码**，16 次 load 全部 page fault，故障 MB entry 需 LSU flush 才退休 | ① Phase 5 改 `r=1,w=0,d=0`（同样闭合 W/D 位 1→0 且不产生故障）；② base 新增 `flush_and_drain()`（`raw_rtu_flush` + `wait_l1d_mb_empty`），T-B Phase 3 两处有意故障后各调一次 |
| 4 | T-F/T-G/T-H 潜在致命：`satp_write_asid()` 写入 `44'h0` 根 PPN | L2 三个用例的 bring-up 由 test base 完成，vseq 本地 `m_root_ppn` 仍是 0，改 ASID 时会把 satp.PPN 一起打成 0 → 之后所有 walk 崩 | 两个 base 的 `satp_write_asid()` 改为从 `m_env_h.m_ref.m_satp0_ppn`（CSR mirror）取回当前根 PPN 后再写 |
| 5 | sysmap 窗口"释放"写法有害 | `sysmap_window(base, mask=0, flg=0)`：mask=0 意味着**命中所有 PA**，等于把 flg=0 施加到全测试余下部分，而不是释放 | 改为写回 match-all + translation-safe flags（`sysmap_window(0, 0, 5'b01111)`） |
| 6 | T-D `prefill_mb()` 两处缺陷 | ① 复用同一批 VA → 第二次调用直接 L1 命中、不占 MB slot；② 预填未预装 JTLB，强制的 PTW 总线错会落到预填 miss 上 | ① 增加单调 `m_pf_idx`，每次预填用全新 VA；② 沿用 `DTLB_EXPT_ENTRY_PRECISE_001` 的做法先 `cp0_tlbwr_entry` 装 JTLB，使预填 miss 不进 PTW |
| 7 | T-G TLBP 位宽错 | `{18'b0, va_t'(...)>>12, 3'b001, 16'hFFFF}` 把 39 bit 塞进 27 bit 字段 | 显式 `bit [26:0] p_vpn = 27'((39'h0_C000_0000)>>12)` |

### 6.4 新发现的 RTL 待确认项（补 §二-B 问题单）

**B7（新增）：iUTLB 命中路径的 U 位 S 态检查未生效。**
`mmu_l1itlb.sv:551-562` 的 `iutlb_page_fault` 含
`iutlb_flg_aft_bypass[4] && cp0_supv_mode && !cp0_mmu_sum`，即"S 态取指命中 U=1 页应 page fault"。
实测：U=1 页在 **U 态取指装入 iUTLB 后，切到 S 态再取同一 VA**，DUT 返回 `mmu_ifu_pavld=1`、
`mmu_ifu_pgflt=0`、PA 正常（ref model 判 EXC_PAGE_FAULT，SB 报 fault mismatch）；
同一条件下走 TWU 新 walk 则正常 page fault（`mmu_twu_chk_sva.sv:195` 有对应检查）。
**结论**：命中路径与 walk 路径对 U 位的处理不一致，需设计确认是"iUTLB 只在装入时检查 U"的
架构意图，还是 `flg[4]` 未正确写入/未参与命中判定的缺陷。
（另附：RISC-V 中 SUM 只作用于 load/store，此处把 `!cp0_mmu_sum` 用在取指路径上也需确认。）
**规避**：T-A Phase 3 的 S 态故障取指前先 `tlb_inv_all_and_wait()`，让故障由 TWU 产生。

### 6.5 冒烟结果

编译：`make comp` → 0 Errors。

| 用例 | SEED=1 | SEED=2 | 说明 |
|---|---:|---:|---|
| `test_mmu_l1itlb_cov_toggle_entry_sweep_001` (T-A) | 0 | 0 | 修 #1/#2 + B7 规避后通过 |
| `test_mmu_l1dtlb_cov_toggle_highpa_1g_001` (T-B) | 0 | 0 | 修 #1/#3 后通过 |
| `test_mmu_l1dtlb_cov_toggle_tail_001` (T-C) | 0 | 0 | 首轮即通过 |
| `test_mmu_l1dtlb_cov_toggle_expt_cam_001` (T-D) | 0 | 0 | 首轮即通过 |
| `test_mmu_l2tlb_cov_toggle_sram_001` (T-F) | 0 | 0 | 修 #4 后通过 |
| `test_mmu_l2tlb_cov_toggle_highaddr_001` (T-G) | 0 | 0 | 修 #4/#7 后通过 |
| `test_mmu_l2tlb_cov_toggle_small_modules_001` (T-H) | 0 | 0 | 修 #4 后通过 |

（UVM_WARNING / UVM_FATAL 均为 0。）

### 6.6 仍未开工项（沿用 v2 结论）

1. `fullexclude.tgl` 按 §二-A(a)+(b) 增补豁免条目 + 豁免论证文档；
2. §二-B 问题单 B1–B6 与本节 B7 提交设计确认；
3. 刷新 L2 URG 基线（§〇 前置条件 1），据新基线裁剪 T-F/T-G/T-H；
4. H-2（rrpv_wbuf 满）可达性分析——T-H 中已显式**不做** force，注释说明原因；
5. off-path `pa[27:26]`：需 ref model `translate()` 携带 64 bit VA 后才能闭合（本节 6.3 #2）；
6. ~~实测覆盖率验收~~ → **已完成，见 §七**。

---

## 七、实测覆盖率结果（2026-07-26）

完整报告：**`doc/toggle_closure_coverage_report_20260726.md`**

**方法**：7 个用例各跑一次 `run_cov`（SEED=1）累加到独立 VDB
`output/coverage/toggle_new.vdb`，再与官方基线 `output/coverage/phase14_merged.vdb`
用同一份 `simu/exclude_v4.tgl` 合并出 `output/coverage/toggle_merged_urgReport`
（`Number of tests: 8`）。已逐模块核对 URG `Total Bits` 分母全部一致，合并同口径。

### 7.1 结果摘要

| 范围 | TOGGLE 基线 → 合并 | Δ |
|---|---|---:|
| 全设计 `tb_top` | 77.67 → 81.85 | **+4.18** |
| `x_mmu_l1itlb` 实例树 | 79.71 → 94.07 | **+14.36** |
| `u_mmu_l1dtlb` 实例树 | 81.80 → 84.75 | **+2.95** |
| `x_mmu_l2tlb` 实例树 | 85.98 → 88.43 | **+2.45** |

模块级最大增益：`mmu_l1itlb` +18.67（92.57）、`ct_mmu_iutlb_fst_entry` +10.99（97.80）、
`ct_mmu_iutlb_entry` +10.39（98.52）、`ct_mmu_tlboper` +7.34（82.82）、
`ct_mmu_l2tlb_data_array` +4.32（97.61）、`mmu_l2tlb` +3.75（90.50）、
`mmu_l1dtlb_hit_rd` +3.87（87.82）、`mmu_l1dtlb` +3.63（85.51）。

位级：21 个 L1/L2 模块基线共 **6064** 个未覆盖方向位 → 本轮闭合 **1898（31.3%）**，
剩余 4166（其中 160 属 §二-A 死信号豁免候选）。

### 7.2 对评审意见的实测验证

| 评审意见 | 实测 |
|---|---|
| ④ `ifu_mmu_va[62]` 未列入任何任务 | T-A Phase 1 已闭合，**两个方向均覆盖** |
| ② 多数缺口只缺 1→0，单轮填充无效 | `mmu_l1itlb` 1→0 +22.47（67.16→89.63）> 0→1 +14.87，**两轮互补制生效** |
| ① T-E 无效（`req0/1_port_id` 硬连线） | 合并后 `req0/1_port_id` 4 位仍全缺，**证实取消 T-E 正确**；豁免后 allocator 即达 100% |
| ① `off_flg[8:0]`/`off_pgs` 等死信号 | 全部仍缺，且本轮**新证实** `iutlb_off_flg[8:0]`（`mmu_l1itlb.sv:2232`）、`dutlb_pre_flg[8:0]`/`dutlb_pre_pgs`（`mmu_l1dtlb_hit_rd.sv:272-273` 别名）同为硬连线常量，应一并豁免 |
| ⑤ rrpv_wbuf 满高风险 | 未做 force，`count`/`fifo_full` 4 位仍缺，等 H-2 结论 |

### 7.3 与 §四 验收口径的差距

达标：`mmu_l1itlb` 92.57 ✅、`ct_mmu_iutlb_entry` 98.52 ✅、`ct_mmu_iutlb_fst_entry` 97.80 ✅、
`mmu_l2tlb_replacement_policy` 100 ✅、`ct_mmu_l2tlb_rrpv_array` 100 ✅、`mmu_l2tlb_rrpv_wbuf` 99.83 ✅。

未达标：D-TLB 侧（`mmu_l1dtlb` 85.51 / `hit_rd` 87.82 / `install` 77.06 / `expt_cam` 78.56 /
`scheduler` 89.12 / `mb_entry` 92.72）与 L2 队列侧（`l2tlb` 90.50 / `reqq` 91.59 /
`mb` 89.49 / `mb_entry` 88.06 / `reqq_entry` 76.97 / `tag_array` 93.17）。

**根因不是用例失效，而是覆盖面**：这些缺口集中在"阵列/队列的逐条目多值写入"——
T-A 对 iTLB 32 条目做的两轮扫描已证明该方法有效，但没有推广到
D-TLB 16 条目（`entry_flg_vec`/`entry_ppn_vec` 剩 460 位）、
MB 8 slot（`mb_entry_*[7:0]` 剩 ~300 位）、
expt_cam 8 条目（`ent[2..7].vpn` 剩 190 位）、
L2 8 way（`final_way_*`/`raw_way_*` 剩 ~450 位）。

### 7.4 后续（更新版待办）

| # | 事项 | 预计收益 |
|---|---|---|
| 1 | **T-B2**：把 T-A 的 entry sweep 方法照搬到 D-TLB（16 条目 + 8 MB slot × ≥3 轮互补值） | ~760 位 |
| 2 | **T-D2**：连续 ≥8 个不同 VA 的故障，填满 expt_cam 8 条目 | ~190 位 |
| 3 | **T-F2/T-G2**：写入互补 tag 后逐条 TLBR 读回；同 set 8 way 逐一命中 | ~580 位 |
| 4 | **T-H2**：TLBWI 灌互补 VPN/ASID + 完整 INVALL 让 `invall_cnt` 走满 | ~230 位 |
| 5 | `fullexclude.tgl` 豁免（§二-A + §7.2 新增两组常量）+ 豁免论证 | ~160 位（直接换算 allocator→100%） |
| 6 | 问题单 B1–B7 提交设计确认 | — |
| 7 | H-2（rrpv_wbuf 满）可达性分析 | 4 位 |
| 8 | `mmu_l1itlb.entryN_flg[3]/[5] 1→0` 可达性分析（合法 PTE 下 X/A 恒为 1，疑似结构不可达） | ~300 位，用例 or 豁免二选一 |
| 9 | off-path `pa[27:26]`：ref model `translate()` 打通 64 bit VA | 2 位 |

---

## 八、§7.4 待办执行记录（2026-07-26 第二轮）

### 8.1 完成情况总览

| # | 事项 | 状态 | 产出 |
|---|---|---|---|
| 1 | T-B2 D-TLB entry sweep | ✅ 已实现并跑通（0 warning） | `mmu_l1dtlb_toggle_entry_sweep_vseq` / `test_mmu_l1dtlb_cov_toggle_entry_sweep_002` |
| 2 | T-D2 expt_cam 8 条目 | ✅ 已实现并跑通（0 warning） | `mmu_l1dtlb_toggle_expt_cam_full_vseq` / `..._expt_cam_full_001` |
| 3 | T-F2 / T-G2 | ✅ 已实现并跑通 | `mmu_l2tlb_toggle_sram_v2_vseq` / `..._highaddr_v2_vseq` + `..._sram_002` / `..._highaddr_002` |
| 4 | T-H2 invall_cnt | ✅ 已实现并跑通（0 warning） | `mmu_l2tlb_toggle_small_modules_v2_vseq` / `..._small_modules_002` |
| 5 | `fullexclude.tgl` 豁免 | ✅ 已验证生效 | `simu/fullexclude.tgl`（8 条 Toggle 指令，附 URG 语法结论） |
| 6 | 问题单 B1–B7 | ✅ 已成文 | **`doc/toggle_closure_rtl_issues.md`** |
| 7 | H-2（rrpv_wbuf 满）可达性 | ✅ 已分析，结论：不做 force，建议豁免 | 本节 §8.2 |
| 8 | `entryN_flg[3]/[5] 1→0` 可达性 | ✅ 已分析，**flg[3] 可达并已实现用例**；flg[0]/[5] 结构不可达 | 本节 §8.3 + `test_mmu_l1itlb_cov_toggle_flg_clear_001` |
| 9 | off-path `pa[27:26]`（ref model 64bit VA） | ⏸ 未做（2 位，优先级最低） | 本节 §8.5 |

### 8.2 H-2：`mmu_l2tlb_rrpv_wbuf` 的 `count[3:2]` / `full` / `fifo_full`

RTL 事实（`mmu_l2tlb_rrpv_wbuf.sv` + `mmu_l2tlb.sv:1070-1093`）：

```
DEPTH = 8                       (mmu_l2tlb.sv:1077)
ARB_STALL_LEVEL = DEPTH - 3 = 5 (rrpv_wbuf.sv:94)
full      = (count >= 5)        (rrpv_wbuf.sv:135)
fifo_full = (count == 8)        (rrpv_wbuf.sv:134)
wbuf_pop_grant = ~arb_l2tlb_req (mmu_l2tlb.sv:1071)
wbuf_push_req  = push_req & (final_reqq_req | final_pfu_req)
```

关键点：**`pop_grant` 就是"仲裁器本周期没有请求"**。也就是说只要 L2 仲裁总线出现
**任意一个空闲周期**，就会 pop 掉一项。且 push 对**相同 set index 会合并**
（`push_new_entry` 门控，`mmu_l2tlb.sv:1083` 注释"merge same index data"），
合并的 push 不增加 `count`。

因此 `count` 要爬到 5 / 8，需要同时满足：
1. 连续 ≥5（≥8）个周期 `arb_l2tlb_req` 不间断；
2. 这 ≥5（≥8）次查找命中**不同的 set index**（否则被合并）。

可用激励源只有 2 个 LSU 端口 + 1 个 IFU 端口 + PTW + PFU。要让 reqq 连续 5~8 拍
不空档，必须把 reqq 压到深度积压——T-H2 Phase 3 已经做到 8 个 dTLB MB slot +
2 个 iTLB miss 同时在飞，仍不足以消除空闲周期。

**结论**：`count[3:2]`、`full`、`fifo_full` 共 4 个方向位属于**队列深水位**类缺口。
可选路径：
- (a) 白盒 `force arb_l2tlb_req = 1'b1` 若干周期 —— **不推荐**：强推仲裁内部信号
  会同时伪造大量周边覆盖率，得不偿失；
- (b) 加入 PFU 流式预取 + 双 LSU 端口满流 + 8 MB slot 的组合压力用例 —— 收益 4 位、
  成本高、且不保证收敛；
- (c) **建议采纳**：写入豁免并附本节论证。模块当前 99.83%，4 位不影响验收结论。

### 8.3 `ct_mmu_iutlb_entry.utlb_flg[13:0]` 的 `1→0` 逐位可达性

`utlb_flg` 只有三个写者（`ct_mmu_iutlb_entry.v:150-173`）：

| 写者 | 数据源 |
|---|---|
| `!cpurst_b` | `14'h0` |
| `utlb_entry_upd` | `utlb_upd_flg = ptw_l1tlb_ref_flg \| jtlb_utlb_ref_flg`（`mmu_l1itlb.sv:1936`） |
| `utlb_entry_swp` | `utlb_swp_flg` ＝另一条 L1I 条目的 flg（同值域） |

**注意：TLB invalidate 不清 flg**，只清 valid。所以 `flg[k] 1→0` 必须靠"再来一次
携带 `flg[k]=0` 的 refill"（或整芯片复位）。

存储布局（从 `twu.sv:1157` 的 refill 打包 `{data[37:10], high_flg[4:0], data[9:6],
data[4:0]}` 与 `twu.sv:1114` 的 `chk_unit_flg[8:0] = {data[9:6], data[4:0]}` 反推）：

| flg 位 | PTE 位 | 含义 |
|---|---|---|
| `[0]` | PTE[0] | V |
| `[1]` | PTE[1] | R |
| `[2]` | PTE[2] | W |
| `[3]` | PTE[3] | X |
| `[4]` | PTE[4] | U |
| `[5]` | PTE[6] | A |
| `[6]` | PTE[7] | D |
| `[8:7]` | PTE[9:8] | RSW[1:0] |
| `[13:9]` | sysmap_mmu_flg[4:0] / PTE[63:59] | MAEE 高位属性 |

（**PTE[5] = G 不存在于 L1 flg 中**，G 只进 L2 tag 的最低位，见
`twu.sv:1158` `..., chk_unit_data[5]}`。）

因为 `chk_unit_refill_req = ... & (!chk_unit_page_flt)`（`twu.sv:1152`），逐位判定：

| flg 位 | `chk_unit_page_flt` 中的相关项（`twu.sv:1131-1145`） | `1→0` 可达性 |
|---|---|---|
| `[0]` V | `!flg[0]` **无条件** fault | ❌ 结构不可达 |
| `[5]` A | `!flg[5]` **无条件** fault | ❌ 结构不可达（页表通路） |
| `[3]` X | `!flg[3] && fetch_type` fault | ✅ **可达**，见下 |
| `[2]` W | 仅 `!flg[2] && store_type` fault | ✅ 可达（load/fetch walk 照装） |
| `[6]` D | 仅 `!flg[6] && store_type` fault | ✅ 可达 |
| `[1]` R | 仅 `!flg[1] && !flg[3] && thd` fault | ✅ 可达（execute-only 合法叶） |
| `[4]` U | 与特权态相关，两向都合法 | ✅ 可达（T-A 已覆盖） |
| `[8:7]` RSW | 纯软件位，MMU 不检查 | ✅ 可达，但 `map_4k()` API 未暴露 RSW → 见 §8.4 |
| `[13:9]` | sysmap / MAEE | ✅ 可达（T-A/T-B2 sysmap 轮次） |

**`flg[3]` 为什么可达 —— 关键 RTL 发现**

取指 walk 遇到 `X=0` 一定 fault，所以 PTW 通路装不进 `X=0`。但

```
mmu_l2tlb.sv:1013  final_pa_vld = final_tlb_hit & final_vld;
mmu_l2tlb.sv:1178  l2tlb_l1itlb_ref_pavld = final_pa_vld & (acc_type == 3'b011);
```

**L2→L1I 回填通路没有任何权限项**。于是：

1. 用 **load** 访问一个 `R=1,W=0,X=0,A=1,D=0` 的页 → walk 成功（load 不查 X/W/D）
   → 该表项以 `flg[3]=flg[2]=flg[6]=0` 装入 L2；
2. 再对同一 VA 发 **取指** → L1I miss → L2 命中 → **原样回填 L1I**，
   `flg[3]/[2]/[6]` 完成 `1→0`；
3. 之后 L1I 命中检查才报 instruction page fault —— 架构上正确，且 ref model
   看到的是同一张页表、预测同一个 fault，`translation_sb` 不会报错。

已实现为 `mmu_l1itlb_toggle_flg_clear_vseq` /
`test_mmu_l1itlb_cov_toggle_flg_clear_001`（2 pass × 32 条目，SEED=1 **0 warning**）。
该通路同时被登记为 RTL 共识条目 N2（`doc/toggle_closure_rtl_issues.md`）。

**`flg[0]`/`flg[5]` 的处置建议（二选一）**

- (a) **软件 TLBWI 通路**：`cp0_tlbwr_entry()` 写的 `MMU_ELO` 就是一条裸 PTE
  （`mmu_l1dtlb_vseq_lib.svh:1752`，当前把 A/D/R/W/X 写死为 1/1/1/1/1）。
  软件写 L2 data array **不做权限检查**，因此写入 `A=0` 后再让 L1 miss→L2 命中，
  即可让 `flg[5] 1→0`。代价：给 `cp0_tlbwr_entry` 增加 7 个带默认值的可选
  flag 形参（向后兼容），再写一个 T-I2。
- (b) **中途真复位**：`tb_top.sv:265-320` 已有 `cpurst_b` 注入器
  （`+MMU_TLBOP_RESET_MODE=<mode>`），`assert_mid_test_reset()`
  （`mmu_l1_l2_tlb_common_vseq.svh:122`）已在 T-A 尾部挂好钩子（当前因未加
  plusarg 而以一条 warning 优雅跳过）。复位会把 32 条目的 `flg/ppn/pgs`
  一次性从载值清零，**一发闭合所有 `1→0`**（含 V/A）。代价：复位后环境需重新
  bringup，且必须用 `PLUS_ARGS=` 运行，无法纳入默认回归。

**建议**：先走 (a) 覆盖 `flg[5]`（属功能可达，价值更高）；`flg[0]=V` 在有效条目里
恒为 1，`1→0` 只能靠复位，直接豁免并附本节论证。

### 8.4 `map_4k()` API 未暴露的 PTE 位

`m_pt_mem.m_builder.map_4k()` 形参只有 `v/r/w/x/u/g/a/d`，没有 `rsw[1:0]`，
所以 `flg[8:7]` 只能恒为 0（`0→1` 与 `1→0` 都缺）。这不是 RTL 不可达，而是
**TB API 缺口**。建议给 `map_4k/map_2m/map_1g` 增加 `bit [1:0] rsw = 2'b00`
形参（向后兼容），T-A/T-B2 各轮次交替写 `2'b01`/`2'b10` 即可闭合。

### 8.5 off-path `pa[27:26]`（2 位）

`m_ref.translate()` 目前按 39 bit VA 建模，off-path（`va[63:39]` 非规范）分支
无法产出预期 PA，导致 `pa[27:26]` 的一个方向拿不到参考值。属 ref model 增强，
收益 2 位，优先级最低，本轮不做。

### 8.6 本轮新增的两个 TB 缺陷修复（非计划项，但影响所有 IFU 用例）

**(1) `raw_ifu_fetch()` 多余保持一拍导致虚假响应**

`mmu_toggle_closure_vseq.svh` 的两份 `raw_ifu_fetch`（L1 base / L2 base）原本在
观察到 `mmu_ifu_pavld` 后**又等一拍**才撤 `ifu_mmu_va_vld`。那一拍里 MMU 看到的是
"一个仍然有效的请求 + 刚刚被 walk 装进 L1I 的 VA" → **再答一次**；而
`ifu_monitor`（`ifu_monitor.svh:127-131`）的 `m_rsp_tail_hold` 对同 va/abort 签名
拒绝重开 pending，于是把第二次响应报成

```
IFU rsp observed without pending req: pa=0x...
```

只有 **miss→walk** 的长延迟取指才暴露（hit 时 req 与 rsp 同拍，不构成额外窗口），
所以此前只在 T-H2 Phase 3 的 2 次 post-INVALL 取指上出现，一直被当成"偶发"。
T-I 做 128 次 miss 取指后一次性放大到 **132 条 warning**，才定位到根因。

修复：在观察到 `pavld` 的**同一拍**撤请求。T-A 回归 0 增量 warning
（原有 1 条 `mid-test reset ... ensure +MMU_TLBOP_RESET_MODE` 属 plusarg 未加的
预期提示）。**建议同步修正其他 vseq 库中同形状的裸 IFU 驱动。**

**(2) T-D2 的 `acflt_at()` 竞争 与 保留编码误用**

- `acflt_at()` 依赖 `force_ptw_bus_error_by_count(1)` 命中**下一个** PTW 访存，
  该假设只在 bringup 之后立即成立。放在 8 次 `prefill_mb`+页故障之后，残余
  JTLB/MB 流量会抢走那次访存 → 实测 `td_ac_0/td_ac_1` 超时。改用 pgflt 通路
  （只需 MB 占用条件）后 0 warning。参见 RTL 共识条目 N1。
- Phase 4 原用 `R=0,W=1` 造 fault —— 那是 **RISC-V 保留编码**，walker 会当指针
  继续下探，ref model 报 `translate PAGE_FAULT (3-level exhausted)` warning。
  改为 `R=0,W=0,X=1`（合法 execute-only 叶）后干净。
