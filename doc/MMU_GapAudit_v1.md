# MMU 验证计划差距审计报告 v1

> **审计对象**：[doc/MMU_VerificationPlan.md](MMU_VerificationPlan.md) v1.0
> **DUT 范围**：`mmu/rtl/`（OpenRISCV2030 MMU，Sv39）
> **审计方法**：5 个并行 RTL 审计 subagent，逐模块比对计划 §5 Feature List 与 RTL 实现
> **发布日期**：2026-04-22
> **作者**：Verification Team

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| v1.0 | 2026-04-22 | Verification Team | 首版差距审计，165 条 gap |

---

## 0. 摘要

5 个 Explore subagent 对 `mmu/rtl/` 全量审计后，发现 **165 条**功能点未在原 `MMU_VerificationPlan.md` v1.0 中明确覆盖。分布如下：

| 模块组 | Gap 数 | 对应原计划章节 |
|--------|--------|----------------|
| L1 TLB（ITLB+DTLB） | 34 | §5.1 F1+F2 |
| L2 TLB + Arbiter | 40 | §5.2 F3 + §5.3 F5 |
| PTW（含 PDE cache、TWU、MBUF） | 42 | §5.3 F4 |
| 系统侧（SysMap+PMP+TLBOper+CSR） | 21 | §5.4 F6-F9 |
| Top + 集成（异常/HPCP/复位/SRAM/Bypass） | 47 | §5.5 F10-F14 |
| **合计** | **184** | （含交叉条目，去重后 ≈165） |

按优先级：**P0 ≈ 35 条**（含 12 条架构事实修订）、**P1 ≈ 110 条**、**P2 ≈ 40 条**。

### 0.1 P0 关键发现（12 条须立即合入计划与设计 review）

| # | 模块 | 描述 | RTL 证据 | 建议动作 |
|---|------|------|----------|----------|
| K1 | `ct_mmu_iplru` | L1 ITLB 实体数 = 32（entry0–31），原计划 F1.1 写 16 | [ct_mmu_iplru.v](../mmu/rtl/ct_mmu_iplru.v#L20-L43) | 修订 §2.1 与 F1.1 |
| K2 | `ct_mmu_iutlb_entry` / `ct_mmu_iutlb_fst_entry` | INV_VA 比对仅用 `vpn[7:0]`（8-bit），完整 27-bit VPN 未参与匹配 | [ct_mmu_iutlb_entry.v#L94](../mmu/rtl/ct_mmu_iutlb_entry.v#L94)、[ct_mmu_iutlb_fst_entry.v#L122](../mmu/rtl/ct_mmu_iutlb_fst_entry.v#L122) | 设计 review；修订 F1.10 / F2.13 |
| K3 | `ct_mmu_regs` | SATP 写入仅接受 `wdata[62:60]==3'b0` 的 MODE，非法 MODE 静默丢弃 | [ct_mmu_regs.v#L574-L577](../mmu/rtl/ct_mmu_regs.v#L574) | 修订 F9.3，新增非法 MODE TC |
| K4 | `ct_mmu_tlboper` | INVVA FSM 简化为单 4K 扫描，原多 page-size 状态被注释 | [ct_mmu_tlboper.v#L685-L730](../mmu/rtl/ct_mmu_tlboper.v#L685) | 修订 F8.2，混合页面 SFENCE.VA 必测 |
| K5 | `mmu_l1dtlb_install` | `mmu_lsu_tlb_wakeup[11:0]` 是广播信号（`mb_have_free=1` 时全 1），并非 per-entry onehot | [mmu_l1dtlb_install.sv#L233-L235](../mmu/rtl/mmu_l1dtlb_install.sv#L233) | 修订 F4.23 / F2.3 描述 |
| K6 | `mmu_l1dtlb` | STAMO 仅 Pipe0 真实使用，Pipe1 接 1'b0 | [mmu_l1dtlb.sv#L428,L514-L515](../mmu/rtl/mmu_l1dtlb.sv#L428) | 修订 F2.14，新增 Pipe0/1 不对称 TC |
| K7 | `ct_mmu_top` | `mmu_pmp_fetch` 仅 4 端口（3,5,6,7）有信号，非 8 端口 | [ct_mmu_top.v#L160-L163](../mmu/rtl/ct_mmu_top.v#L160) | 修订 F7.3 |
| K8 | `L1PDE_cache` / `L2PDE_cache` | TAG 含 ASID 字段但 update 时未填充 → SATP 切 ASID 后存在 stale 数据风险 | [L1PDE_cache.sv#L73-L85](../mmu/rtl/L1PDE_cache.sv#L73)、[PDE_cache.sv#L92](../mmu/rtl/PDE_cache.sv#L92) | 设计 review；新增 stale TC |
| K9 | `ct_spsram_*` | SRAM macro 无 reset，valid 位需外部 FF 清零 → 复位后首次访问 X 风险 | [ct_spsram_256x196.v](../mmu/rtl/ct_spsram_256x196.v) | 新增 F13 子项 + SVA |
| K10 | `twu` / `ptw_mbuf` | 仅看到 A=0/D=0 → page fault；未见 hw write-back | [twu.sv#L494-L495](../mmu/rtl/twu.sv#L494) | 修订 F4.13/F4.14 为 trap-only，§11 加 R11 |
| K11 | `ct_mmu_top` | 双使能 `mmu_lsu_mmu_en` vs `mmu_xx_mmu_en` 语义/时序差异 | [ct_mmu_top.v#L50,L134](../mmu/rtl/ct_mmu_top.v#L50)、[ct_mmu_regs.v#L645-L648](../mmu/rtl/ct_mmu_regs.v#L645) | 新增 F10 子项 |
| K12 | `ct_mmu_top` | `rtu_yy_xx_flush` 影响范围（MB / ReqQ / PDE cache / TWU）未明确 | [ct_mmu_top.v#L127](../mmu/rtl/ct_mmu_top.v#L127) | 修订 F10.11，明确 4 范围分别测 |

### 0.2 报告组织
- §1 L1 TLB Gaps（34 条）
- §2 L2 TLB + Arbiter Gaps（40 条）
- §3 PTW Gaps（42 条）
- §4 系统侧 Gaps（21 条）
- §5 Top / 集成 Gaps（47 条）
- §6 设计 Review 建议清单（12 项）

---

## 1. L1 TLB Gaps（F1+F2 修订）

### 1.1 ITLB

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-I1.1 | `mmu_l1itlb` / `ct_mmu_iplru` | ITLB 实体数实为 32（entry0-31），不是 16 | [ct_mmu_iplru.v#L20-L43](../mmu/rtl/ct_mmu_iplru.v#L20) | **P0** |
| GAP-I1.2 | `ct_mmu_iutlb_fst_entry` vs `ct_mmu_iutlb_entry` | FST（fast/huge）entry 与普通 entry 共存语义未明：何时使用、替换交互 | [ct_mmu_iutlb_fst_entry.v#L1-L30](../mmu/rtl/ct_mmu_iutlb_fst_entry.v#L1)、[ct_mmu_iutlb_entry.v#L1-L30](../mmu/rtl/ct_mmu_iutlb_entry.v#L1) | P1 |
| GAP-I1.3 | `ct_mmu_iplru` | PLRU 树（p00/p10/...）reset 后初始状态对首次替换的影响 | [ct_mmu_iplru.v#L50-L150](../mmu/rtl/ct_mmu_iplru.v#L50) | **P0** |
| GAP-I1.4 | `ct_mmu_iutlb_entry` / `ct_mmu_iutlb_fst_entry` | INV_VA 比对仅用 `lsu_mmu_tlb_va[7:0]` 与 `utlb_vpn[7:0]`，并非全 27-bit | [ct_mmu_iutlb_entry.v#L94-L95](../mmu/rtl/ct_mmu_iutlb_entry.v#L94)、[ct_mmu_iutlb_fst_entry.v#L122-L123](../mmu/rtl/ct_mmu_iutlb_fst_entry.v#L122) | **P0** |
| GAP-I1.5 | `mmu_l1itlb` + `ct_mmu_tlboper` | L2 refill 完成与 INV_VA 同周期命中同 entry 的 FSM 冲突处理 | [mmu_l1itlb.sv#L100-L150](../mmu/rtl/mmu_l1itlb.sv#L100) | P1 |
| GAP-I1.6 | `ct_mmu_iplru` | 同周期 hit + refill 不同 entry 的 PLRU 更新冲突 | [ct_mmu_iplru.v#L120-L160](../mmu/rtl/ct_mmu_iplru.v#L120) | P1 |
| GAP-I1.7 | `mmu_l1itlb` | `pgs[2:0]` 编码与 page size mismatch 处理 | [mmu_l1itlb.sv#L50-L120](../mmu/rtl/mmu_l1itlb.sv#L50) | P1 |
| GAP-I1.8 | `mmu_l1itlb` | `ifu_abort` 在 refill 流水线中段断言时的 speculative kill | [mmu_l1itlb.sv#L50-L65](../mmu/rtl/mmu_l1itlb.sv#L50) | P1 |

### 1.2 DTLB

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-D2.1 | `mmu_l1dtlb_mb_entry` | MB entry FSM 的 WFI（Wait For Install）状态转换；PTW + JTLB refill 同时指向同一 MB entry 的仲裁 | [mmu_l1dtlb_mb_entry.sv#L105-L160](../mmu/rtl/mmu_l1dtlb_mb_entry.sv#L105) | **P0** |
| GAP-D2.2 | `mmu_l1dtlb_install` | 三方安装仲裁 PTW > JTLB > WFI；JTLB 被抢占降级到 WFI 的状态转换 | [mmu_l1dtlb_install.sv#L100-L150](../mmu/rtl/mmu_l1dtlb_install.sv#L100) | **P0** |
| GAP-D2.3 | `mmu_l1dtlb_allocator` | FFZ allocator 角落：所有 slot 占满（gnt0/gnt1 都为 0）、交替空满模式、与 scheduler 的 race | [mmu_l1dtlb_allocator.sv#L30-L80](../mmu/rtl/mmu_l1dtlb_allocator.sv#L30) | **P0** |
| GAP-D2.4 | `mmu_l1dtlb_scheduler` | Credit 计数边界（恰为 0、CREDIT_MAX）+ 同周期 req_fire & credit_return 的环绕 | [mmu_l1dtlb_scheduler.sv#L70-L100](../mmu/rtl/mmu_l1dtlb_scheduler.sv#L70) | **P0** |
| GAP-D2.5 | `mmu_l1dtlb_scheduler` | MB 空时 bypass 路径的优先级：bypass req 即使 bypass_en 撤销也优先 | [mmu_l1dtlb_scheduler.sv#L120-L150](../mmu/rtl/mmu_l1dtlb_scheduler.sv#L120) | P1 |
| GAP-D2.6 | `mmu_l1dtlb_hit_rd` | 双端口同 entry 同周期 hit（Pipe0+Pipe1）：PLRU 更新串行化与 PA 输出 mux | [mmu_l1dtlb_hit_rd.sv#L100-L150](../mmu/rtl/mmu_l1dtlb_hit_rd.sv#L100) | P1 |
| GAP-D2.7 | `mmu_l1dtlb_hit_rd` + `mmu_l1dtlb_allocator` | Pipe0 hit + Pipe1 miss 同周期：PLRU hit 更新与 allocator FFZ 同时 fire | [mmu_l1dtlb_hit_rd.sv#L80-L120](../mmu/rtl/mmu_l1dtlb_hit_rd.sv#L80)、[mmu_l1dtlb_allocator.sv#L50](../mmu/rtl/mmu_l1dtlb_allocator.sv#L50) | P1 |
| GAP-D2.8 | `mmu_l1dtlb_mb_entry` | PGFLT/ACFLT 状态：从 pgflt=1 到 `mmu_lsu_page_fault_x` 输出的延迟与 hold | [mmu_l1dtlb_mb_entry.sv#L140-L160](../mmu/rtl/mmu_l1dtlb_mb_entry.sv#L140) | P1 |
| GAP-D2.9 | `mmu_l1dtlb_mb_entry` | ABT 状态后 refill 晚到（refill_vld 在 abort_this_cyc 撤销后断言）→ 防止伪 install | [mmu_l1dtlb_mb_entry.sv#L150-L170](../mmu/rtl/mmu_l1dtlb_mb_entry.sv#L150) | P1 |
| GAP-D2.10 | `mmu_l1dtlb_install` | MB entry ID 在三方仲裁中不一致 → 数据走错 entry 风险 | [mmu_l1dtlb_install.sv#L80-L110](../mmu/rtl/mmu_l1dtlb_install.sv#L80) | P1 |
| GAP-D2.11 | `mmu_l1dtlb` | STAMO 仅 Pipe0 实使，Pipe1 接 1'b0 → 端口不对称 | [mmu_l1dtlb.sv#L70,L428,L514-L515](../mmu/rtl/mmu_l1dtlb.sv#L70) | **P0** |
| GAP-D2.12 | `ct_mmu_dutlb_entry` / `ct_mmu_dutlb_huge_entry` | 16 entry 池中 huge entry 与普通 entry 共存的替换策略 | [ct_mmu_dutlb_entry.v#L1](../mmu/rtl/ct_mmu_dutlb_entry.v#L1)、[ct_mmu_dutlb_huge_entry.v#L1](../mmu/rtl/ct_mmu_dutlb_huge_entry.v#L1) | P1 |
| GAP-D2.13 | `mmu_l1dtlb_mb_entry` | WFC 状态期间 INV_VA 抵达：abort_this_cyc 与 STATE_ABT 转换 | [mmu_l1dtlb_mb_entry.sv#L170-L190](../mmu/rtl/mmu_l1dtlb_mb_entry.sv#L170) | P1 |
| GAP-D2.14 | `mmu_l1dtlb` + `ct_mmu_dplru` | 双端口 hit[0]/hit[1] 同时与 pending refill 更新 PLRU 的 race | [ct_mmu_dplru.v#L1-L50](../mmu/rtl/ct_mmu_dplru.v#L1)、[mmu_l1dtlb.sv#L310-L340](../mmu/rtl/mmu_l1dtlb.sv#L310) | P1 |
| GAP-D2.15 | `mmu_l1dtlb_install` | `mmu_lsu_tlb_wakeup[11:0]` 实为广播：`mb_have_free=1` 时全 1，并非 per-entry onehot | [mmu_l1dtlb_install.sv#L233-L235](../mmu/rtl/mmu_l1dtlb_install.sv#L233) | **P0** |
| GAP-D2.16 | `mmu_l1dtlb` | `mmu_lsu_tlb_busy` 仅在 `&mb_entry_vld`（全满）时拉起；阈值不可配 | [mmu_l1dtlb.sv#L1229](../mmu/rtl/mmu_l1dtlb.sv#L1229) | P1 |
| GAP-D2.17 | `mmu_l1dtlb_install` | **【v3.1 新增】wakeup 触发源 OR 通路被原计划遗漏**：`wakeup_vec_next = {12{mb_have_free}} \| {12{l1dtlb_expt_for_taken}}`，**MB 释放空槽 OR PTW/L2 异常返回** 任一即触发；原 GAP-D2.15 仅描述 `mb_have_free` 路径，缺失 `l1dtlb_expt_for_taken = ptw_ref_fault \| l2tlb_ref_fault` 异常路径覆盖 | [mmu_l1dtlb_install.sv#L233-L290](../mmu/rtl/mmu_l1dtlb_install.sv#L233) | **P0** |
| GAP-D2.18 | `mmu_l1dtlb_install` | **【v3.1 新增】wakeup 信号属性误标**：原 F4.23 / GAP-PX.10 将 `mmu_lsu_tlb_wakeup[11:0]` 归属为 PTW 输出；实际驱动模块为 `mmu_l1dtlb_install`，PTW 仅为刺激源之一；文档已修正归属（M1/F4.23） | [mmu_l1dtlb_install.sv#L233-L290](../mmu/rtl/mmu_l1dtlb_install.sv#L233), [ct_mmu_top.v#L106,L144](../mmu/rtl/ct_mmu_top.v#L106) | P1 |
| GAP-D2.19 | `mmu_l1dtlb_mb_entry` | **【v3.1 新增】PGFLT/ACFLT 仅持续 1 周期**：状态 `state_nxt` 直接回 `STATE_IDLE`，对 LSU 输出表现为 1-cycle pulse（**非 hold**）；原 GAP-D2.8 描述 hold 与 RTL 不符；需 `sva_pgflt_pulse_1cyc` 守护 | [mmu_l1dtlb_mb_entry.sv#L121-L195](../mmu/rtl/mmu_l1dtlb_mb_entry.sv#L121) | P1 |
| GAP-D2.20 | `mmu_l1dtlb_install` | **【v3.1 新增】JTLB 路径不会产生 ACFLT**：`req_jtlb_expt = jtlb_dutlb_pgflt;`（`jtlb_dutlb_acc_err` 在 RTL 注释掉），ACFLT 仅来自 PTW；负向覆盖确认设计意图 | [mmu_l1dtlb_install.sv#L260-L290](../mmu/rtl/mmu_l1dtlb_install.sv#L260) | P1 |
| GAP-D2.21 | `mmu_l1dtlb_scheduler` | **【v3.1 新增 / RTL Lint】顶层 `CREDIT_WIDTH=3` 为死参数**：scheduler 内部 `credit_cnt` 实为 5-bit (`$clog2(9)+1`)，不引用顶层参数；建议 RTL 清理或 sva 守护 `credit_cnt[$bits(credit_cnt)-1:0] <= 8` | [mmu_l1dtlb.sv#L10](../mmu/rtl/mmu_l1dtlb.sv#L10), [mmu_l1dtlb_scheduler.sv#L60-L100](../mmu/rtl/mmu_l1dtlb_scheduler.sv#L60) | P2 |
| GAP-D2.22 | `mmu_l1dtlb` | **【v3.1 新增 / RTL Lint P1】未定义符号 `MB_WIDTH`**：`mmu_l1dtlb.sv` ~L244 处 `logic [MB_WIDTH-1:0][PGS_WIDTH-1:0] mb_entry_pgs;` 引用未定义参数 `MB_WIDTH`，疑为 `MB_DEPTH-1` 或 `$clog2(MB_DEPTH)` 笔误；需 RTL fix + lint 守护 | [mmu_l1dtlb.sv#L244](../mmu/rtl/mmu_l1dtlb.sv#L244) | **P1** |
| GAP-D2.23 | `mmu_l1dtlb_install` | **【v3.1 新增 / RTL 死代码 P2】PLRU bank1 路径未连接**：`plru_bank1_refill_way` 在 install 模块未被消费，bank1 PLRU 更新路径疑似缺失或与 bank0 共用；需评估 16-entry PLRU 双 bank 是否对称、是否影响替换公平性 | [mmu_l1dtlb_install.sv](../mmu/rtl/mmu_l1dtlb_install.sv) | P2 |
| GAP-D2.24 | `ct_mmu_top` | **【v3.1 新增】PTW→DTLB ID 顶层截断**：`ct_mmu_top.v` 实例化 DTLB 时连接 `.ptw_l1dtlb_ref_id (ptw_l1dtlb_id[2:0])`，6→3 bit 截断；需验证截断后 ID 与 DTLB MB 8-entry 索引无 alias、不会误投递 | [ct_mmu_top.v#L106](../mmu/rtl/ct_mmu_top.v#L106) | P1 |

### 1.3 L1 共性

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-X3.1 | L1 ITLB+DTLB | `cp0_mmu_icg_en` 在低功耗切换时的 latch 完整性、信号 hold | [mmu_l1dtlb.sv#L110-L140](../mmu/rtl/mmu_l1dtlb.sv#L110)、[mmu_l1itlb.sv#L1-L50](../mmu/rtl/mmu_l1itlb.sv#L1) | P1 |
| GAP-X3.2 | `ct_mmu_iutlb_entry` / `ct_mmu_dutlb_entry` | VPN 27-bit 输入截断/扩展边界（VA[62:0] → VPN[26:0]） | [ct_mmu_iutlb_entry.v#L60](../mmu/rtl/ct_mmu_iutlb_entry.v#L60)、[ct_mmu_dutlb_entry.v#L50](../mmu/rtl/ct_mmu_dutlb_entry.v#L50) | **P0** |
| GAP-X3.3 | `mmu_l1dtlb_allocator` | `ct_rtu_compare_iid` age compare 模块下溢/wrap 处理 | [mmu_l1dtlb_allocator.sv#L60-L70](../mmu/rtl/mmu_l1dtlb_allocator.sv#L60) | P1 |
| GAP-X3.4 | L1 ITLB+DTLB | 参数边界（MB_DEPTH=8, NUM_ENTRY=16/32, CREDIT_MAX=8）：power-of-2 wrap | [mmu_l1dtlb.sv#L10-L14](../mmu/rtl/mmu_l1dtlb.sv#L10) | P1 |
| GAP-X3.5 | L1 ITLB+DTLB | SATP 中 ASID 切换：自动失效 vs 手动 SFENCE 的协议 | [mmu_l1itlb.sv#L1-L30](../mmu/rtl/mmu_l1itlb.sv#L1)、[mmu_l1dtlb.sv#L1-L30](../mmu/rtl/mmu_l1dtlb.sv#L1) | P1 |
| GAP-X3.6 | `ct_mmu_dplru` | 16-entry PLRU 树 reset 状态：全 0 → 首次替换可能集中冲突 | [ct_mmu_dplru.v#L100-L150](../mmu/rtl/ct_mmu_dplru.v#L100) | **P0** |
| GAP-X3.7 | DTLB | 双端口同 VPN 跨多个 entry 匹配 → PA 输出 mux/优先级 | [ct_mmu_dutlb_entry.v#L80-L120](../mmu/rtl/ct_mmu_dutlb_entry.v#L80)、[mmu_l1dtlb_hit_rd.sv#L50-L100](../mmu/rtl/mmu_l1dtlb_hit_rd.sv#L50) | P1 |
| GAP-X3.8 | L1 | MB allocator/scheduler 指针 wrap 边界 | [mmu_l1dtlb_allocator.sv#L40-L60](../mmu/rtl/mmu_l1dtlb_allocator.sv#L40) | P1 |
| GAP-X3.9 | DTLB | MB req 与 bypass req 同周期 fire 的仲裁 | [mmu_l1dtlb_scheduler.sv#L140-L160](../mmu/rtl/mmu_l1dtlb_scheduler.sv#L140) | P1 |
| GAP-X3.10 | L1 | VPN/PPN/FLG 参数化宽度 mismatch 边界 | [mmu_l1itlb.sv#L1-L20](../mmu/rtl/mmu_l1itlb.sv#L1)、[mmu_l1dtlb.sv#L1-L20](../mmu/rtl/mmu_l1dtlb.sv#L1) | P2 |

**L1 小节合计：34 条（P0=8, P1=24, P2=2）**

---

## 2. L2 TLB + Arbiter Gaps（F3+F5 修订）

### 2.1 Tag/Data/RRPV 阵列

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-L2.1 | `ct_mmu_l2tlb_tag_array` + `mmu_arb` | Skew hash 函数实现细节：哪些 VPN bit XOR 形成 idx_w0..w7；冲突分布 | [ct_mmu_l2tlb_tag_array.sv](../mmu/rtl/ct_mmu_l2tlb_tag_array.sv)、[mmu_arb.sv](../mmu/rtl/mmu_arb.sv) | **P0** |
| GAP-L2.2 | `ct_spsram_wrapper` + tag array | 同地址同周期 read+write 的 RAW；CEN/GWEN/WEN active-low 协议 | [ct_spram_wrapper.sv#L1-L20](../mmu/rtl/ct_spram_wrapper.sv#L1)、[ct_mmu_l2tlb_tag_array.sv#L30-L50](../mmu/rtl/ct_mmu_l2tlb_tag_array.sv#L30) | P1 |
| GAP-L2.3 | tag/data array | SRAM 复位后 valid 位初值（依赖外部 FF 清零）→ 防 X 传播 | [ct_spram_wrapper.sv](../mmu/rtl/ct_spram_wrapper.sv)、[mmu_fpga_ram.sv#L35-L42](../mmu/rtl/mmu_fpga_ram.sv#L35) | **P0** |
| GAP-L2.4 | `ct_spsram_wrapper` | BIST disable 与 scan_en 对写的影响 | [ct_spram_wrapper.sv](../mmu/rtl/ct_spram_wrapper.sv) | P2 |
| GAP-L2.5 | FPGA RAM vs ASIC | write-enable 时序、PortADataOut 输出时序差异 | [mmu_fpga_ram.sv#L43-L52](../mmu/rtl/mmu_fpga_ram.sv#L43) | P1 |
| GAP-L2.6 | `ct_mmu_l2tlb_data_array` | WEN bitmask 是否真正生效（按位 vs 整字） | [ct_mmu_l2tlb_data_array.sv](../mmu/rtl/ct_mmu_l2tlb_data_array.sv)、[ct_spsram_256x196.v](../mmu/rtl/ct_spsram_256x196.v) | P1 |
| GAP-L2.7 | `ct_mmu_l2tlb_rrpv_array` | RRPV lookup 的 RAW 顺序；CAM bypass 正确性 | [ct_mmu_l2tlb_rrpv_array.sv](../mmu/rtl/ct_mmu_l2tlb_rrpv_array.sv)、[mmu_l2tlb_rrpv_wbuf.sv#L40-L100](../mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L40) | **P0** |

### 2.2 ReqQ

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-Req.1 | `mmu_l2tlb_reqq_entry` | Vld/Sent/Dealloc FSM；初态 r_vld=0 / r_sent=0 转换 | [mmu_l2tlb_reqq_entry.sv#L60-L130](../mmu/rtl/mmu_l2tlb_reqq_entry.sv#L60) | **P0** |
| GAP-Req.2 | `mmu_l2tlb_reqq_entry` | bypass_grant：T0 alloc 同周期 issue_grant & !entry_ready → 跳过 ready 队列 | [mmu_l2tlb_reqq_entry.sv#L107-L120](../mmu/rtl/mmu_l2tlb_reqq_entry.sv#L107) | P1 |
| GAP-Req.3 | `mmu_l2tlb_reqq_entry` | retry：fb_miss_retry 清 r_sent；多次 retry 不死锁 | [mmu_l2tlb_reqq_entry.sv#L100-L110](../mmu/rtl/mmu_l2tlb_reqq_entry.sv#L100) | P1 |
| GAP-Req.4 | `mmu_l2tlb_reqq` | credit 返回时序与流水线深度 | [mmu_l2tlb_reqq.sv](../mmu/rtl/mmu_l2tlb_reqq.sv)、[mmu_l2tlb.sv#L70-L90](../mmu/rtl/mmu_l2tlb.sv#L70) | P1 |
| GAP-Req.5 | `mmu_l2tlb_reqq` | Thermometer FFZ：单周期仅一个 DTLB entry 分配 | [mmu_l2tlb_reqq.sv#L70-L100](../mmu/rtl/mmu_l2tlb_reqq.sv#L70) | **P0** |
| GAP-Req.6 | `mmu_l2tlb_reqq` | ITLB 专用 entry 0 与 DTLB FFZ 不冲突 | [mmu_l2tlb_reqq.sv#L40-L65](../mmu/rtl/mmu_l2tlb_reqq.sv#L40) | **P0** |

### 2.3 MB

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-MB.1 | `mmu_l2tlb_mb_entry` | Entry FSM 各状态转换的精确周期 | [mmu_l2tlb_mb_entry.sv#L60-L120](../mmu/rtl/mmu_l2tlb_mb_entry.sv#L60) | P1 |
| GAP-MB.2 | `mmu_l2tlb_mb` + `ptw` | SFENCE 期间 in-flight refill abort：PTW 完成前 MB 清空 | [mmu_l2tlb_mb.sv](../mmu/rtl/mmu_l2tlb_mb.sv)、[ct_mmu_tlboper.v](../mmu/rtl/ct_mmu_tlboper.v) | **P0** |
| GAP-MB.3 | `mmu_l2tlb_mb` | **【v3.1 已证伪】** 原猜测“同 VPN 不同 hash 槽位 → dedup 逻辑”，实际 RTL `mmu_l2tlb_mb` 不含 VPN/ASID 比较（仅 FFZ）。dedup 验证责任转移到 PTW MBUF (GAP-PM.6)。 | [mmu_l2tlb_mb.sv#L80-L110](../mmu/rtl/mmu_l2tlb_mb.sv#L80) | 证伪完成 |
| GAP-MB.4 | `mmu_l2tlb_mb_entry` | dealloc 精确时序：alloc/dealloc race 不留孤儿 refill | [mmu_l2tlb_mb_entry.sv#L80-L95](../mmu/rtl/mmu_l2tlb_mb_entry.sv#L80) | P1 |
| GAP-MB.5 | `mmu_l2tlb_mb` | FFZ 多 free entry 时的偏置（按 index 顺序 vs wrap） | [mmu_l2tlb_mb.sv#L100-L140](../mmu/rtl/mmu_l2tlb_mb.sv#L100) | P2 |

### 2.4 Replacement / RRPV（pplru 已迁移到 PTW 章节）

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-RRPV.1 | `mmu_l2tlb_replacement_policy` | RRPV aging 范围：所有 valid way vs 仅非 mask way | [mmu_l2tlb_replacement_policy.sv#L110-L130](../mmu/rtl/mmu_l2tlb_replacement_policy.sv#L110) | P1 |
| GAP-RRPV.2 | `mmu_l2tlb_rrpv_wbuf` | 同 idx 连续两 cycle 写：覆盖 vs FIFO 顺序 | [mmu_l2tlb_rrpv_wbuf.sv#L60-L120](../mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L60) | P1 |
| GAP-RRPV.3 | `mmu_l2tlb_rrpv_wbuf` | bypass 冲突：lookup_idx 命中两条 buffer entry 的优先级 | [mmu_l2tlb_rrpv_wbuf.sv#L110-L160](../mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L110) | P1 |
| GAP-RRPV.4 | `mmu_l2tlb_rrpv_wbuf` | full=1 的 backpressure 是否正确传递到 ReqQ | [mmu_l2tlb_rrpv_wbuf.sv#L35-L50](../mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L35) | P1 |
| GAP-RRPV.5 | `mmu_l2tlb_replacement_policy` | victim 角落：(1) 全 mask、(2) 全 invalid、(3) tie at MAX | [mmu_l2tlb_replacement_policy.sv#L75-L110](../mmu/rtl/mmu_l2tlb_replacement_policy.sv#L75) | P1 |
| GAP-RRPV.6 | `pplru` | 16-entry LRU 树 (p00-p47) 节点语义；并发 read/write 一致性 | [pplru.sv#L35-L80](../mmu/rtl/pplru.sv#L35) | P1 |
| GAP-RRPV.7 | `pplru` | reset 后 PLRU 初值（全 0 vs 交替） → tie-break 行为 | [pplru.sv#L80-L150](../mmu/rtl/pplru.sv#L80) | P1 |

### 2.5 Arbiter / xbar

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-Arb.1 | `mmu_arb` | Skew hash 实现：VPN[26:0] 各 bit 如何形成 idx_w0..w7 | [mmu_arb.sv#L150-L220](../mmu/rtl/mmu_arb.sv#L150) | **P0** |
| GAP-Arb.2 | `mmu_arb` | Bank 冲突检测算法：PTW/ReqQ/TLBOp 多源映射重叠 bank 时 mask 生成 | [mmu_arb.sv#L220-L280](../mmu/rtl/mmu_arb.sv#L220) | P1 |
| GAP-Arb.3 | `mmu_arb` | Backpressure mask 传递：L2 stall → arb_*_mask 时延 | [mmu_arb.sv#L280-L350](../mmu/rtl/mmu_arb.sv#L280) | P1 |
| GAP-Arb.4 | `one_to_four_xbar` | Idle TWU 选择算法：高低表 fallback、轮转指针保持 | [one_to_four_xbar.sv#L60-L120](../mmu/rtl/one_to_four_xbar.sv#L60) | P1 |
| GAP-Arb.5 | `one_to_four_xbar` | 在飞 dispatch 被 tlboper_ptw_abort 取消的处理 | [one_to_four_xbar.sv#L45-L65](../mmu/rtl/one_to_four_xbar.sv#L45) | P1 |
| GAP-Arb.6 | `one_to_four_xbar` | L1PDE 与 L2PDE 同时 hit 的优先级 | [one_to_four_xbar.sv#L35-L45](../mmu/rtl/one_to_four_xbar.sv#L35) | P1 |
| GAP-Arb.7 | `mmu_arb` | Work-conserving 形式化证明（无空闲 cycle） | [mmu_arb.sv](../mmu/rtl/mmu_arb.sv) | P1 |

### 2.6 SRAM wrapper / FPGA RAM

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-SRAM.1 | `ct_spram_wrapper` | GWEN=0 全局写使能：是否 gate 所有写（即使 CEN=0） | [ct_spram_wrapper.sv#L10-L20](../mmu/rtl/ct_spram_wrapper.sv#L10) | P1 |
| GAP-SRAM.2 | `mmu_fpga_ram` | WEN 位掩码行为是否真正按 bit 写 | [mmu_fpga_ram.sv#L1-L52](../mmu/rtl/mmu_fpga_ram.sv#L1) | P1 |
| GAP-SRAM.3 | wrappers | 读时序：T+0 write-through vs T+1 buffered | [ct_spram_wrapper.sv](../mmu/rtl/ct_spram_wrapper.sv)、[mmu_fpga_ram.sv#L43-L52](../mmu/rtl/mmu_fpga_ram.sv#L43) | P1 |
| GAP-SRAM.4 | `mmu_fpga_ram` | 初值 ASIC 流程是否一致 | [mmu_fpga_ram.sv#L33-L42](../mmu/rtl/mmu_fpga_ram.sv#L33) | P2 |
| GAP-SRAM.5 | 256x196 / 256x84 | FPGA vs ASIC 等价性（CEN/GWEN/WEN 差异） | [ct_spsram_256x196.v#L44-L50](../mmu/rtl/ct_spsram_256x196.v#L44)、[ct_spsram_256x84.v#L44-L50](../mmu/rtl/ct_spsram_256x84.v#L44) | P1 |
| GAP-SRAM.6 | wrappers | tag/data/RRPV 阵列同周期不同 way 读写无串扰 | [ct_mmu_l2tlb_tag_array.sv#L35-L50](../mmu/rtl/ct_mmu_l2tlb_tag_array.sv#L35) | P1 |

### 2.7 其它

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-L2X.1 | `mmu_l2tlb` + `mmu_l2tlb_mb` | Atomic refill ordering：tag/data/RRPV 同 cycle vs staggered；中间态防腐 | [mmu_l2tlb.sv#L200-L250](../mmu/rtl/mmu_l2tlb.sv#L200)、[mmu_l2tlb_mb.sv#L200-L250](../mmu/rtl/mmu_l2tlb_mb.sv#L200) | **P0** |
| GAP-L2X.2 | `mmu_l2tlb` + `ct_mmu_tlboper` | INV_VA 与 in-flight refill 竞争同一 VPN 的精确仲裁 | [mmu_l2tlb.sv](../mmu/rtl/mmu_l2tlb.sv)、[ct_mmu_tlboper.v](../mmu/rtl/ct_mmu_tlboper.v) | **P0** |
| GAP-L2X.3 | `mmu_l2tlb_reqq` + `mmu_arb` | trans_id 转发延迟 | [mmu_l2tlb_reqq.sv#L180-L220](../mmu/rtl/mmu_l2tlb_reqq.sv#L180) | P1 |
| GAP-L2X.4 | `mmu_l2tlb` | hit info 返回延迟（cycle 数） | [mmu_l2tlb.sv#L1-L100](../mmu/rtl/mmu_l2tlb.sv#L1) | P1 |
| GAP-L2X.5 | `ct_mmu_top` + `mmu_l2tlb` | **【v3.1 已证伪】** L2TLB `clk_en` 实际不包含 maee/no_op_req。gating 责任转移到 mmu_arb 侧 `mmu_yy_xx_no_op` 广播路径。 | [mmu_l2tlb.sv](../mmu/rtl/mmu_l2tlb.sv)、[ct_mmu_top.v](../mmu/rtl/ct_mmu_top.v) | 证伪完成 |
| GAP-L2X.6 | `ct_mmu_regs` + `mmu_l2tlb` | cpurst_b 单脉冲是否清所有 array vld 位 | [mmu_fpga_ram.sv#L33-L42](../mmu/rtl/mmu_fpga_ram.sv#L33) | P1 |
| GAP-L2X.7 | `mmu_l2tlb_replacement_policy` | RRPV 饱和正确性（formal 推荐） | [mmu_l2tlb_replacement_policy.sv#L115-L130](../mmu/rtl/mmu_l2tlb_replacement_policy.sv#L115) | P1 |
| GAP-L2X.8 | `mmu_arb` | PTW + TLBOp + ReqQ 同 bank → 严格优先级胜者 | [mmu_arb.sv#L80-L110](../mmu/rtl/mmu_arb.sv#L80) | P1 |
| GAP-L2X.9 | `mmu_l2tlb_rrpv_wbuf` | pop_grant=1 与 buffer 同时 empty 的 sram_idx 稳定性 | [mmu_l2tlb_rrpv_wbuf.sv#L60-L100](../mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L60) | P1 |
| GAP-Hash.1 | `mmu_arb` | Hash 函数表达式公式化文档 | [mmu_arb.sv#L350-L450](../mmu/rtl/mmu_arb.sv#L350) | **P0** |
| GAP-Hash.2 | `mmu_arb` | 真实 workload 下 hash 冲突分布（熵） | [mmu_arb.sv](../mmu/rtl/mmu_arb.sv) | P2 |
| GAP-Hash.3 | `mmu_arb` | Hash 可逆性分析（安全/DPA） | [mmu_arb.sv#L350-L450](../mmu/rtl/mmu_arb.sv#L350) | P2 |
| GAP-Hash.4 | `one_to_four_xbar` + `mmu_arb` | Selector 编码（VPN bit 选 hash 变体） | [one_to_four_xbar.sv](../mmu/rtl/one_to_four_xbar.sv)、[mmu_arb.sv](../mmu/rtl/mmu_arb.sv) | P1 |

### 2.8 【v3.1 新增】L2TLB BUG_HUNT (GAP-L2.NEW)

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-L2.NEW.1 | `mmu_l2tlb_reqq` | `ID_W=3` 与 `TOTAL_DEPTH=9` 不匹配：entry 8 的 trans_id (`4'b1000`) 被截断为 `3'b000`，feedback 误命中 entry 0 (ITLB) | [mmu_l2tlb_reqq.sv#L23](../mmu/rtl/mmu_l2tlb_reqq.sv#L23)、[#L194](../mmu/rtl/mmu_l2tlb_reqq.sv#L194) | **P0** |
| GAP-L2.NEW.2 | `mmu_l2tlb_rrpv_wbuf` | 默认 `RRPV_WIDTH=2` 与顶层实例化 3 不一致（实例化已覆写），可移植性盲点 | [mmu_l2tlb_rrpv_wbuf.sv](../mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv) | P1 |
| GAP-L2.NEW.3 | `mmu_l2tlb_mb` + `mmu_l2tlb_mb_entry` | mb_entry 未接 abort/sfence，SFENCE 后 in-flight PTW refill 是否仍写 SRAM/dealloc MB 需明确 | [mmu_l2tlb_mb.sv](../mmu/rtl/mmu_l2tlb_mb.sv)、[mmu_l2tlb_mb_entry.sv](../mmu/rtl/mmu_l2tlb_mb_entry.sv) | **P0** |
| GAP-L2.NEW.4 | `mmu_l2tlb` | `arb_l2tlb_is_dtlb = (acc_type==3'b010) \| (acc_type==3'b010)` 重复表达式 → store(3'b110) 被误判为 ITLB | [mmu_l2tlb.sv](../mmu/rtl/mmu_l2tlb.sv) | **P0** |
| GAP-L2.NEW.5 | `mmu_l2tlb` | `raw_vld` 触发条件 `acc_type != 3'b101 \|\| acc_type != 3'b000` 恒为真，屏蔽失效，PTW write/refill 也会拉 raw_vld | [mmu_l2tlb.sv](../mmu/rtl/mmu_l2tlb.sv) | P1 |

**L2+Arb 小节合计：40 条（P0=8, P1=29, P2=3）**

---

## 3. PTW Gaps（F4 修订）

### 3.1 TWU FSM

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-T1.1 | `twu` | CSR FSM (IDLE→1G_CRS1→1G_CRS2→2M_CRS1→2M_CRS2→CSR_DATA_VLD) 跨界检测 | [twu.sv#L1041-L1100](../mmu/rtl/twu.sv#L1041)、[twu.sv#L1168](../mmu/rtl/twu.sv#L1168) | P1 |
| GAP-T1.2 | `twu` | sysmap mismatch 触发 1G→2M / 2M→4K 降级状态语义 | [twu.sv#L1065-L1080](../mmu/rtl/twu.sv#L1065) | P1 |
| GAP-T1.3 | `twu` | csr_refill_pgs 转换（3'b100→3'b010）→ L0 refill 触发 | [twu.sv#L1095-L1115](../mmu/rtl/twu.sv#L1095) | P1 |
| GAP-T1.4 | `twu` + `mbuf_entry` | `twu_data_ready[2:0]` 与 mbuf level 匹配的 write_back 时序 | [twu.sv#L826-L830](../mmu/rtl/twu.sv#L826)、[mbuf_entry.sv#L156-L158](../mmu/rtl/mbuf_entry.sv#L156) | P1 |

### 3.2 ptw_mbuf 分配 / Entry FSM

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-PM.1 | `ptw_mbuf` | FFZ 优先级编码（thermometer high/low table）+ entry 8 wrap | [ptw_mbuf.sv#L290-L340](../mmu/rtl/ptw_mbuf.sv#L290) | **P0** |
| GAP-PM.2 | `ptw_mbuf` | round-robin 指针（mbuf_ptr_nxt, twu_req_point_r）背压时不丢失 | [ptw_mbuf.sv#L350-L375](../mmu/rtl/ptw_mbuf.sv#L350) | P1 |
| GAP-PM.3 | `ptw_mbuf` | entry 8 ITLB 专用槽位（itlb_sel 优先级覆盖 FFZ） | [ptw_mbuf.sv#L267-L270](../mmu/rtl/ptw_mbuf.sv#L267) | **P0** |
| GAP-PM.4 | `ptw_mbuf` | 多 TWU 同 cycle 有效 → mbuf_grant[3:0] onehot 正确性 | [ptw_mbuf.sv#L253-L265](../mmu/rtl/ptw_mbuf.sv#L253) | **P0** |
| GAP-PM.5 | `mbuf_entry` | FSM (vld/on/get/bus_err_flop) 状态组合不冲突 | [mbuf_entry.sv#L78-L140](../mmu/rtl/mbuf_entry.sv#L78) | P1 |
| GAP-PM.6 | `ptw_mbuf` | Dedup VPN 比较：同 VPN+level 仅一胜出 | [ptw_mbuf.sv#L150-L180](../mmu/rtl/ptw_mbuf.sv#L150) | P1 |
| GAP-PM.7 | `mbuf_entry` | write_back_req 触发：twu_data_ready[idx] 与 lvl 匹配 | [mbuf_entry.sv#L156-L158](../mmu/rtl/mbuf_entry.sv#L156) | P1 |
| GAP-PM.8 | `ptw_mbuf` | write_back_grant 优先级 mux（entry 8 vs 0-7）的公平性 | [ptw_mbuf.sv#L536-L548](../mmu/rtl/ptw_mbuf.sv#L536) | P2 |

### 3.3 PDE Cache

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-PDE.1 | `L1PDE_cache` / `L2PDE_cache` | TAG 含 ASID 字段但 update 时未填充 → SATP 切 ASID stale | [L1PDE_cache.sv#L73-L85](../mmu/rtl/L1PDE_cache.sv#L73)、[PDE_cache.sv#L92](../mmu/rtl/PDE_cache.sv#L92) | **P0** |
| GAP-PDE.2 | `PDE_cache` | L1/L2 同时 hit 的优先级 mux | [PDE_cache.sv#L244-L250](../mmu/rtl/PDE_cache.sv#L244) | P1 |
| GAP-PDE.3 | `L1PDE_cache` / `L2PDE_cache` | regs_ptw_clr 立即清 valid，多周期查询无瞬态 stale | [L1PDE_cache.sv#L60-L70](../mmu/rtl/L1PDE_cache.sv#L60)、[L2PDE_cache.sv#L59-L68](../mmu/rtl/L2PDE_cache.sv#L59) | P1 |
| GAP-PDE.4 | `PDE_cache` | L1/L2 hit 互斥；非互斥时 refill_vld 避碰 | [PDE_cache.sv#L258-L259](../mmu/rtl/PDE_cache.sv#L258) | P1 |
| GAP-PDE.5 | `pplru` | plru_ref_num[15:0] onehot 一致性 | [pplru.sv](../mmu/rtl/pplru.sv) | P1 |

### 3.4 PTW↔LSU Data Channel

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-LD.1 | `ptw_mbuf` | mmu_lsu_data_req_addr 由 mbuf_ptr_nxt[8:0] 选择（指针有效性） | [ptw_mbuf.sv#L484-L495](../mmu/rtl/ptw_mbuf.sv#L484) | P1 |
| GAP-LD.2 | `ptw_mbuf` | mmu_lsu_data_req_grant[8:0] 单 cycle onehot | [ptw_mbuf.sv#L477-L480](../mmu/rtl/ptw_mbuf.sv#L477) | P1 |
| GAP-LD.3 | `ptw_mbuf` | LSU 响应同步到正确 entry 的 on 状态 | [ptw_mbuf.sv#L520-L530](../mmu/rtl/ptw_mbuf.sv#L520) | P1 |
| GAP-LD.4 | `ptw_mbuf` | 单 cycle 多响应防护：FSM 不被 stale resp 触发多 entry | [ptw_mbuf.sv#L532-L550](../mmu/rtl/ptw_mbuf.sv#L532) | **P0** |
| GAP-LD.5 | `ptw_mbuf` | mmu_lsu_data_req=1 长期未 grant 的死锁防护 | [ptw_mbuf.sv#L461](../mmu/rtl/ptw_mbuf.sv#L461) | P1 |

### 3.5 地址生成与边界

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-AG.1 | `twu` | L2 PTE addr {SATP_PPN[27:0], vpn[26:18], 3'b0} 边界 | [twu.sv#L427](../mmu/rtl/twu.sv#L427) | P2 |
| GAP-AG.2 | `twu` | L1 PTE addr {scd_ppn[27:0], vpn[17:9], 3'b0} 边界 | [twu.sv#L587](../mmu/rtl/twu.sv#L587) | P2 |
| GAP-AG.3 | `twu` | L0 PTE addr {thd_ppn[27:0], vpn[8:0], 3'b0} 边界 | [twu.sv#L745](../mmu/rtl/twu.sv#L745) | P2 |
| GAP-AG.4 | `twu` | SysMap 跨界 adder 中间态 PMP/SysMap 无 stale lookup | [twu.sv#L1118-L1150](../mmu/rtl/twu.sv#L1118) | P1 |

### 3.6 A/D Bit 硬件更新

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-AD.1 | `twu` | A=0 走 page fault（fst_chk_flg[5]）；无 A-bit hw 写回路径 | [twu.sv#L494](../mmu/rtl/twu.sv#L494) | **P0** |
| GAP-AD.2 | `twu` | D=0 on store 走 page fault（fst_chk_flg[6]）；无 D-bit hw 写回 | [twu.sv#L495](../mmu/rtl/twu.sv#L495) | **P0** |
| GAP-AD.3 | `ptw_mbuf` | hw A/D 更新流程在 RTL 中缺失 → 确认 trap-only 实现 | [ptw_mbuf.sv](../mmu/rtl/ptw_mbuf.sv) | P1 |
| GAP-AD.4 | `twu` | csr_idle 与 refill_req 在 A/D 更新（如启用）的并发不腐 | [twu.sv#L1123-L1130](../mmu/rtl/twu.sv#L1123) | P1 |

### 3.7 PTW 跨切

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-PX.1 | `ptw` + `ptw_mbuf` | abort_flop 双状态 set/clear 时序 + bus_error/data_vld glitch | [ptw.sv#L248-L252](../mmu/rtl/ptw.sv#L248) | P1 |
| GAP-PX.2 | `ptw` | regs_ptw_clr 是否清 abort_flop；与 SFENCE 抵达冲突 | [ptw.sv#L244-L252](../mmu/rtl/ptw.sv#L244) | P1 |
| GAP-PX.3 | `ptw_mbuf` | tlboper_ptw_abort 广播到 9 entry 原子清空 | [ptw_mbuf.sv#L247](../mmu/rtl/ptw_mbuf.sv#L247) | **P0** |
| GAP-PX.4 | `ptw_mbuf` | bus_error 仲裁：哪 entry 的 bus_err_grant 先 fire；公平性 | [ptw_mbuf.sv#L550-L565](../mmu/rtl/ptw_mbuf.sv#L550) | P1 |
| GAP-PX.5 | `ptw` | 软件写 SATP 但未 ptw_clr → walk 立即用新 SATP_PPN | [ptw.sv#L1-L30](../mmu/rtl/ptw.sv#L1) | P1 |
| GAP-PX.6 | `twu` | SATP+priv_mode 同时变化的 walk consistency | [twu.sv#L50-L120](../mmu/rtl/twu.sv#L50) | P2 |
| GAP-PX.7 | `one_to_four_xbar` | xbar TWU 公平性/饥饿（pointer 不旋转的 livelock） | [one_to_four_xbar.sv#L85-L105](../mmu/rtl/one_to_four_xbar.sv#L85) | P1 |
| GAP-PX.8 | `one_to_four_xbar` | 全 4 TWU busy → twu_ready=0 stall 后必能释放 | [one_to_four_xbar.sv#L77-L79](../mmu/rtl/one_to_four_xbar.sv#L77) | **P0** |
| GAP-PX.9 | `ptw` + xbar | twu_mask 传递时延 | [ptw.sv#L242-L244](../mmu/rtl/ptw.sv#L242) | P2 |
| GAP-PX.10 | `ptw_mbuf` | mmu_lsu_wakeup[11:0] 实为广播（与 K5/D2.15 一致），原 F4.23 描述需修正 | [ptw_mbuf.sv](../mmu/rtl/ptw_mbuf.sv) | **P0** |
| GAP-PX.11 | `ptw` | mmu_lsu_tlb_busy 与 L1 DTLB credit=0 一致性 | [ptw.sv](../mmu/rtl/ptw.sv) | P1 |
| GAP-PX.12 | `twu` | PMP deny mid-walk：终止 vs 完成 L0 read；pgflt 含 level 信息 | [twu.sv#L380-L420](../mmu/rtl/twu.sv#L380) | P1 |
| GAP-PX.13 | `twu` | SysMap hit 在 L2 阶段时下游 L1/L0 不再发起 | [twu.sv#L1168](../mmu/rtl/twu.sv#L1168) | P1 |
| GAP-PX.14 | `ptw` | walk watchdog 缺失 → 死锁风险 | [ptw.sv](../mmu/rtl/ptw.sv) | P1 |
| GAP-PX.15 | `twu` / `ptw_mbuf` | RSW（PTE[63:59]）软件保留位的处理 | [twu.sv#L140-L180](../mmu/rtl/twu.sv#L140) | P2 |
| GAP-PX.16 | `ptw_mbuf` | L1/L2 PDE cache update 不查 ASID → 部分 SATP 切换时残留 stale | [ptw_mbuf.sv#L309-L320](../mmu/rtl/ptw_mbuf.sv#L309) | P1 |
| GAP-PX.17 | `twu` | TWU0/1/2 同 cycle 不同 level walk → MBUF 优先级编码确保单 LSU req | [ptw_mbuf.sv#L253-L265](../mmu/rtl/ptw_mbuf.sv#L253) | P1 |
| GAP-PX.18 | `twu` | CSR refill 路径 vs 普通 refill 优先级（CSR 不被 starve） | [twu.sv#L1209-L1250](../mmu/rtl/twu.sv#L1209) | P1 |

**PTW 小节合计：42 条（P0=8, P1=27, P2=7）**

---

## 4. 系统侧 Gaps（F6/F7/F8/F9 修订）

### 4.1 SysMap

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-SM.1 | `ct_mmu_sysmap` + `ct_mmu_top` | 8 端口独立 SysMap 实例（top 上 mmu_sysmap_pa0–7） | [ct_mmu_top.v#L371](../mmu/rtl/ct_mmu_top.v#L371)、[ct_mmu_sysmap.v#L64-L65](../mmu/rtl/ct_mmu_sysmap.v#L64) | P1 |
| GAP-SM.2 | `ct_mmu_sysmap` | hit 输出为 8-bit one-hot 每端口（sysmap_mmu_hit_y[7:0]） | [ct_mmu_sysmap.v#L92-L103](../mmu/rtl/ct_mmu_sysmap.v#L92) | P2 |
| GAP-SM.3 | `ct_mmu_sysmap_hit` | 优先级链（addr_ge_upaddr 级联） + 多 region 命中处理 | [ct_mmu_sysmap.v#L157-L163](../mmu/rtl/ct_mmu_sysmap.v#L157) | P1 |
| GAP-SM.4 | `ct_mmu_sysmap` | 无 region 命中默认 flag = 5'b10011（So=1, C=0, B=0, Sh=1, Sec=1） | [ct_mmu_sysmap.v#L155](../mmu/rtl/ct_mmu_sysmap.v#L155) | P2 |
| GAP-SM.5 | `ct_mmu_sysmap` | 严格小于（< 而非 <=）的边界等值行为 | [ct_mmu_sysmap.v#L184-L199](../mmu/rtl/ct_mmu_sysmap.v#L184) | P1 |
| GAP-SM.6 | `ct_mmu_sysmap` / `sysmap.h` | PA_WIDTH=40 假设：ADDR_WIDTH=PA_WIDTH-12=28 | [ct_mmu_sysmap.v#L64](../mmu/rtl/ct_mmu_sysmap.v#L64) | P2 |
| GAP-SM.7 | `ct_mmu_sysmap` + `ct_mmu_regs` | 5-bit flag 语义 = [So, C, B, Sh, Sec]；与 MEL 寄存器 [63:59] 对齐 | [ct_mmu_regs.v#L346-L366](../mmu/rtl/ct_mmu_regs.v#L346) | P2 |

### 4.2 PMP 接口

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-PMP.1 | `ct_mmu_top` | mmu_pmp_fetch 仅 4 端口（3,5,6,7）；端口非对称 | [ct_mmu_top.v#L160-L163](../mmu/rtl/ct_mmu_top.v#L160) | P1 |
| GAP-PMP.2 | `ct_mmu_top` + PTW | 8 端口 mmu_pmp_pa{i} 与 PTW walk 通道映射 | [ct_mmu_top.v](../mmu/rtl/ct_mmu_top.v)、[ptw.sv](../mmu/rtl/ptw.sv) | P1 |

### 4.3 TLBOper

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-TLBO.1 | `ct_mmu_tlboper` | INVVA FSM 简化：仅单 4K 扫描，原多 page-size 路径被注释 | [ct_mmu_tlboper.v#L685-L730](../mmu/rtl/ct_mmu_tlboper.v#L685) | **P0** |
| GAP-TLBO.2 | `ct_mmu_tlboper` | INVVA 无显式计数器（INVALL=255, INVASID=511） | [ct_mmu_tlboper.v#L950-L951](../mmu/rtl/ct_mmu_tlboper.v#L950) | P2 |
| GAP-TLBO.3 | `ct_mmu_tlboper` | 计数器深度 11-bit (256/512)；与实际 L2 TLB 深度对齐 | [ct_mmu_tlboper.v#L951](../mmu/rtl/ct_mmu_tlboper.v#L951) | P2 |
| GAP-TLBO.4 | `ct_mmu_tlboper` | tlb_lsu_oper_flop 握手协议；back-to-back SFENCE 阻塞 | [ct_mmu_tlboper.v#L1074-L1088](../mmu/rtl/ct_mmu_tlboper.v#L1074) | P1 |
| GAP-TLBO.5 | `ct_mmu_tlboper` | tlboper_ptw_abort = tlb_lsu_oper && !flop 的脉冲时序 | [ct_mmu_tlboper.v#L1111](../mmu/rtl/ct_mmu_tlboper.v#L1111) | P1 |
| GAP-TLBO.6 | `ct_mmu_tlboper` | TLBP/R/WI/WR 全部 gated by !tlb_lsu_oper：与 LSU 串行 | [ct_mmu_tlboper.v#L90-L110](../mmu/rtl/ct_mmu_tlboper.v#L90) | P2 |
| GAP-TLBO.7 | `ct_mmu_tlboper` | TLBWR 4 状态（WRIDLE/WRWFG/WRTAG/WRWFC）vs TLBP/R/WI 3 状态 | [ct_mmu_tlboper.v#L263-L278](../mmu/rtl/ct_mmu_tlboper.v#L263) | P2 |

### 4.4 CSR / Regs

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-CSR.1 | `ct_mmu_regs` | SATP MODE 写仅接 wdata[62:60]==3'b0；非法 MODE 静默丢弃 | [ct_mmu_regs.v#L574-L577](../mmu/rtl/ct_mmu_regs.v#L574) | **P0** |
| GAP-CSR.2 | `ct_mmu_regs` | ASID/PPN 总更新（无 MODE guard）；部分写语义 | [ct_mmu_regs.v#L585-L591](../mmu/rtl/ct_mmu_regs.v#L585) | P1 |
| GAP-CSR.3 | `ct_mmu_regs` | MCIR no-op fast-path：bits[31:26]==0 时立即 mmu_cp0_cmplt | [ct_mmu_regs.v#L550-L560,L600](../mmu/rtl/ct_mmu_regs.v#L550) | P1 |
| GAP-CSR.4 | `ct_mmu_regs` | satp_write_en → regs_utlb_clr 组合即时清零；无延迟 | [ct_mmu_regs.v#L179](../mmu/rtl/ct_mmu_regs.v#L179) | P1 |
| GAP-CSR.5 | `ct_mmu_regs` | mir_probe / mir_tlbp_tfatal 仅 TLBP 完成时更新（read-only from MIR write） | [ct_mmu_regs.v#L260-L280](../mmu/rtl/ct_mmu_regs.v#L260) | P2 |
| GAP-CSR.6 | `ct_mmu_regs` | MEL 三源（cp0 写 / TLBR 自动 / 异常）优先级 | [ct_mmu_regs.v#L346-L370](../mmu/rtl/ct_mmu_regs.v#L346) | P2 |
| GAP-CSR.7 | `ct_mmu_regs` | MEH 异常捕获：rtu_mmu_expt_vld 时记 bad_vpn；MEL/ASID 不联动 | [ct_mmu_regs.v#L413-L418](../mmu/rtl/ct_mmu_regs.v#L413) | P2 |

### 4.5 CSR ↔ Pipeline Hazards

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-HZD.1 | `ct_mmu_regs` | SATP write 未 hold-off active PTW；依赖 PTW 自身 | [ct_mmu_regs.v#L179,L185](../mmu/rtl/ct_mmu_regs.v#L179) | P1 |
| GAP-HZD.2 | `ct_mmu_regs` | back-to-back CSR write 与 active TLBOper 的 stall | [ct_mmu_regs.v#L180-L188](../mmu/rtl/ct_mmu_regs.v#L180) | P1 |
| GAP-HZD.3 | `ct_mmu_regs` | priv_mode mux MPRV：cp0_mmu_mpp vs cp0_yy_priv_mode；mmu_lsu_mmu_en vs mmu_xx_mmu_en 分裂 | [ct_mmu_regs.v#L645-L648](../mmu/rtl/ct_mmu_regs.v#L645) | P2 |

### 4.6 Reset

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-RST.1 | `ct_mmu_regs` | 全 CSR reset 默认值（SATP MODE=0 bare, ASID=0, PPN=0, MIR/MEL/MEH=0） | [ct_mmu_regs.v#L254,L271,L407,L465,L574-L575](../mmu/rtl/ct_mmu_regs.v#L254) | P2 |

**系统侧小节合计：21 条（P0=3, P1=10, P2=8）**

---

## 5. Top + 集成 Gaps（F10–F14 修订）

### 5.1 ct_mmu_top.v 端口级

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-TP.1 | `ct_mmu_top` | mmu_lsu_mmu_en vs mmu_xx_mmu_en 双输出语义/时序 | [ct_mmu_top.v#L50,L134](../mmu/rtl/ct_mmu_top.v#L50)、[ct_mmu_regs.v#L106-L108](../mmu/rtl/ct_mmu_regs.v#L106) | **P0** |
| GAP-TP.2 | `ct_mmu_top` | mmu_had_debug_info[33:0] bit 拆解（iutlb_st[1:0], dutlb_st[2:0], tlbop states 等） | [ct_mmu_top.v#L940-L955](../mmu/rtl/ct_mmu_top.v#L940) | P1 |
| GAP-TP.3 | `ct_mmu_top` | PMP fetch 仅 4 端口（与 GAP-PMP.1 一致） | [ct_mmu_top.v#L160-L163](../mmu/rtl/ct_mmu_top.v#L160) | P1 |
| GAP-TP.4 | `ct_mmu_top` | ifu_mmu_abort 与 ifu_mmu_va_vld 在 L1ITLB miss 中段的协议 | [ct_mmu_top.v#L57-L59](../mmu/rtl/ct_mmu_top.v#L57) | P1 |
| GAP-TP.5 | `ct_mmu_top` | lsu_mmu_abort[0:1] 在 L2 refill in-flight 时立即清 MB 状态 vs 等 refill | [ct_mmu_top.v#L72-L73](../mmu/rtl/ct_mmu_top.v#L72) | P1 |

### 5.2 属性 flag 传播

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-AT.1 | `mmu_l1dtlb` | lsu_mmu_vabuf[0:1] 28-bit 协议未明 | [mmu_l1dtlb.sv#L41,L60](../mmu/rtl/mmu_l1dtlb.sv#L41)、[mmu_l1dtlb_hit_rd.sv#L63](../mmu/rtl/mmu_l1dtlb_hit_rd.sv#L63) | P2 |
| GAP-AT.2 | `mmu_l1dtlb_hit_rd` | STAMO bypass：stamo_vld=1 时 PA 直来自 stamo_pa，跳 TLB 权限检 | [mmu_l1dtlb_hit_rd.sv#L255-L260](../mmu/rtl/mmu_l1dtlb_hit_rd.sv#L255) | **P0** |
| GAP-AT.3 | `mmu_l1dtlb` | Pipe0/1 STAMO 不对称（与 K6/D2.11 一致） | [mmu_l1dtlb.sv#L428,L514-L515](../mmu/rtl/mmu_l1dtlb.sv#L428) | P2 |
| GAP-AT.4 | `mmu_l1dtlb_hit_rd` | mmu_lsu_page_fault vs mmu_lsu_access_fault 区分 | [ct_mmu_top.v#L81-L82,L100-L101](../mmu/rtl/ct_mmu_top.v#L81) | **P0** |
| GAP-AT.5 | `mmu_l2tlb` + IFU | Pipe2 仅 mmu_lsu_sec2 / mmu_lsu_share2；ca/buf/sh/so 缺失 | [ct_mmu_top.v#L115-L117](../mmu/rtl/ct_mmu_top.v#L115) | P1 |
| GAP-AT.6 | `mmu_l2tlb` | Pipe2 VA 仅 28-bit（vs Pipe0/1 64-bit） | [ct_mmu_top.v#L110](../mmu/rtl/ct_mmu_top.v#L110) | P1 |
| GAP-AT.7 | `mmu_l2tlb` | pa2_err 与 pa2_vld 同时为 1（pfu_deny_st） | [mmu_l2tlb.sv#L1157-L1158](../mmu/rtl/mmu_l2tlb.sv#L1157) | P1 |

### 5.3 多端口并发 / 排序

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-MC.1 | `mmu_l1dtlb_install` | mmu_lsu_tlb_wakeup[11:0] 广播语义（与 K5 / D2.15 一致） | [mmu_l1dtlb_install.sv#L233-L235](../mmu/rtl/mmu_l1dtlb_install.sv#L233) | **P0** |
| GAP-MC.2 | `mmu_l1dtlb` | mmu_lsu_tlb_busy 仅 &mb_entry_vld 时拉起 | [mmu_l1dtlb.sv#L1229](../mmu/rtl/mmu_l1dtlb.sv#L1229) | P1 |
| GAP-MC.3 | `mmu_l1dtlb` + `mmu_l2tlb` | dutlb→l2tlb credit 控制：max in-flight 与死锁 | [ct_mmu_top.v#L490-L493](../mmu/rtl/ct_mmu_top.v#L490) | P1 |
| GAP-MC.4 | `mmu_arb` | L2TLB 4 源仲裁同时 valid 的 worst-case stall | [ct_mmu_top.v#L701-L755](../mmu/rtl/ct_mmu_top.v#L701) | P1 |
| GAP-MC.5 | `mmu_l2tlb` | IFU + LSU0 + LSU1 三 pipe 同 cycle miss → ReqQ 8 容量 + bank 冲突 + wakeup 顺序 | [ct_mmu_top.v#L500-L545](../mmu/rtl/ct_mmu_top.v#L500) | P1 |

### 5.4 SRAM Wrapper / FPGA RAM

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-SR.1 | `ct_spsram_*` | 无 reset 输入；valid 位需外部 FF 清零；首 cycle 防 X | [ct_spsram_256x196.v#L1-L25](../mmu/rtl/ct_spsram_256x196.v#L1) | **P0** |
| GAP-SR.2 | `mmu_fpga_ram` vs ASIC | 同 cycle write-then-read 行为差异 → equivalence 测试 | [mmu_fpga_ram.sv#L38-L45](../mmu/rtl/mmu_fpga_ram.sv#L38) | **P0** |
| GAP-SR.3 | `ct_spram_wrapper` | WEN 按位写未真正生效 | [ct_spram_wrapper.sv#L1-L16](../mmu/rtl/ct_spram_wrapper.sv#L1) | P2 |
| GAP-SR.4 | `ct_spsram_*` | BIST 信号在 wrapper 中缺失；FPGA 模型无 BIST | [ct_spsram_256x196.v](../mmu/rtl/ct_spsram_256x196.v) | P2 |
| GAP-SR.5 | `ct_spram_wrapper` | scan chain 集成（pad_yy_icg_scan_en 仅 gate clock；无 scan_in/out） | [ct_spram_wrapper.sv#L1](../mmu/rtl/ct_spram_wrapper.sv#L1) | P2 |

### 5.5 复位序列

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-RS.1 | `ct_mmu_top` | cpurst_b 释放顺序：SysMap/PMP/L2TLB FF/PTW startup | [ct_mmu_top.v#L1](../mmu/rtl/ct_mmu_top.v#L1) | P1 |
| GAP-RS.2 | `ct_spsram_256x196` | L2 TLB RAM valid 位由外部 FF reset；reset 与首次 refill 时序 | [ct_spsram_256x196.v](../mmu/rtl/ct_spsram_256x196.v) | P1 |
| GAP-RS.3 | `mmu_l1dtlb` | MB entry reset 与 valid bit FF 清零相对时序 | [mmu_l1dtlb.sv](../mmu/rtl/mmu_l1dtlb.sv) | P2 |
| GAP-RS.4 | `ptw` | PTW reset mid-walk：partial result 是否丢弃 | [ptw.sv#L23](../mmu/rtl/ptw.sv#L23) | P1 |
| GAP-RS.5 | `ct_mmu_regs` | 寄存器复位顺序（SATP/PTW/MMU mode） | [ct_mmu_regs.v#L143-L147](../mmu/rtl/ct_mmu_regs.v#L143) | P2 |

### 5.6 性能 / HPCP 细节

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-HP.1 | `mmu_l1dtlb` | mmu_hpcp_dutlb_miss 脉冲宽度（1 cycle 还是持续） | [ct_mmu_top.v#L45](../mmu/rtl/ct_mmu_top.v#L45) | P1 |
| GAP-HP.2 | `mmu_l1itlb` | mmu_hpcp_iutlb_miss 同上 | [ct_mmu_top.v#L44](../mmu/rtl/ct_mmu_top.v#L44) | P1 |
| GAP-HP.3 | `ptw` | mmu_hpcp_jtlb_miss = L1+L2 miss 还是仅 L2 miss | [ptw.sv#L112](../mmu/rtl/ptw.sv#L112) | P1 |
| GAP-HP.4 | `mmu_l1dtlb` | miss 脉冲与 va_vld 时序（同 cycle / 1-cycle 延迟） | [mmu_l1dtlb.sv#L79](../mmu/rtl/mmu_l1dtlb.sv#L79) | P1 |
| GAP-HP.5 | `mmu_l1dtlb_install` | dutlb_top_ref_cur_st[2:0] 状态编码 | [mmu_l1dtlb.sv](../mmu/rtl/mmu_l1dtlb.sv) | P2 |
| GAP-HP.6 | `ptw` | TWU 6 端口 vs 4 TWU；端口与 TWU 映射 | [ptw.sv](../mmu/rtl/ptw.sv) | P2 |

### 5.7 Bypass / SoC Interface

| GAP-ID | 模块 | 描述 | RTL 证据 | 优先级 |
|--------|------|------|----------|--------|
| GAP-BP.1 | `mmu_l1dtlb` | Bypass 模式属性默认值（dutlb_xx_mmu_off=!regs_mmu_en \|\| cp0_mach_mode） | [mmu_l1dtlb.sv#L119](../mmu/rtl/mmu_l1dtlb.sv#L119) | **P0** |
| GAP-BP.2 | `ct_mmu_top` | SATP hotswap：regs_utlb_clr 即时断言导致 uTLB 临时失效窗口 | [ct_mmu_regs.v#L179](../mmu/rtl/ct_mmu_regs.v#L179) | **P0** |
| GAP-BP.3 | `ct_mmu_top` | cp0_yy_priv_mode 异步切换 vs in-flight 翻译的 race | [ct_mmu_top.v#L36](../mmu/rtl/ct_mmu_top.v#L36) | P1 |
| GAP-BP.4 | `ct_mmu_regs` | mmu_cp0_cmplt / mmu_cp0_tlb_done 协议时序 | [ct_mmu_regs.v#L37-L40](../mmu/rtl/ct_mmu_regs.v#L37) | P2 |
| GAP-BP.5 | `ct_mmu_regs` | rtu_mmu_bad_vpn 仅 page fault 触发 vs 也 access fault | [ct_mmu_regs.v#L104](../mmu/rtl/ct_mmu_regs.v#L104) | P1 |
| GAP-BP.6 | `ct_mmu_top` | rtu_yy_xx_flush 范围（MB / ReqQ / PDE cache / TWU） + 时序 vs expt_vld | [ct_mmu_top.v#L127](../mmu/rtl/ct_mmu_top.v#L127) | **P0** |
| GAP-BP.7 | `mmu_l1dtlb` | 多端口异常并发优先级（IFU pgflt + LSU0/1 + PMP + bus_error） | [ct_mmu_top.v#L45-L48](../mmu/rtl/ct_mmu_top.v#L45) | P1 |
| GAP-BP.8 | `ptw` | mmu_lsu_data_req 协议（req-grant vs fire-and-forget），max in-flight | [ct_mmu_top.v#L135-L137](../mmu/rtl/ct_mmu_top.v#L135) | **P0** |
| GAP-BP.9 | `ptw` | mmu_lsu_data_req_size 含义（1-bit size? 编码值?） | [ct_mmu_top.v#L137](../mmu/rtl/ct_mmu_top.v#L137) | P1 |

**Top 小节合计：47 条（P0=8, P1=29, P2=10）**

---

## 6. 设计 Review 建议清单（12 项）

以下 12 项需 **设计架构师签字确认** 是 RTL 实现意图、规格落实，还是潜在 bug：

| # | GAP-ID | 待确认问题 | 影响 |
|---|--------|------------|------|
| 1 | GAP-I1.1 | L1 ITLB 实体数 = 32（计划/规格写 16）；规格更新还是 RTL 多实例化？ | F1.1 描述、§2.1 框图、覆盖率参数 |
| 2 | GAP-I1.4 | INV_VA 仅比对 vpn[7:0] 8-bit，与 SFENCE.VMA 27-bit 完整 VPN 语义不符；属设计简化（接受误失效）还是 bug？ | SFENCE 语义；可能影响软件假设 |
| 3 | GAP-CSR.1 | 非法 SATP MODE 静默丢弃（不报异常）；符合特权规范？ | CSR 写行为；软件需感知 |
| 4 | GAP-TLBO.1 | INVVA FSM 简化为单 4K 扫描；混合页面的 SFENCE.VA 是否能正确失效 huge page？ | 混合页面运行时正确性 |
| 5 | GAP-MC.1 / GAP-PX.10 / GAP-D2.15 | mmu_lsu_tlb_wakeup[11:0] 实为广播信号（mb_have_free 时全 1），并非 per-entry onehot；与原 F4.23 描述差异 | LSU 唤醒模型；原 SB 期望模型需修正 |
| 6 | GAP-D2.11 / GAP-AT.3 | STAMO 仅 Pipe0 真用（Pipe1 接 1'b0）；架构是否承诺仅 Pipe0 走 STAMO？ | UVM agent 配置 |
| 7 | GAP-PMP.1 / GAP-TP.3 | mmu_pmp_fetch 仅 4 端口（3,5,6,7）；其余端口语义？ | PMP agent 行为模型 |
| 8 | GAP-PDE.1 | L1/L2 PDE cache TAG 含 ASID 字段但 update 未填充 → SATP 切 ASID 后存 stale；属 bug？ | 多 ASID 多任务运行正确性 |
| 9 | GAP-SR.1 / GAP-L2.3 | SRAM macro 无 reset；valid 位依靠外部 FF 清零；reset 后首次访问行为是否已通过 lint/CDC？ | 防 X 传播；reset 序列 |
| 10 | GAP-AD.1 / GAP-AD.2 | A=0 / D=0 走 page fault；未见 hw write-back；确认 trap-only 实现？ | F4.13/F4.14；§11 风险更新 |
| 11 | GAP-TP.1 | mmu_lsu_mmu_en vs mmu_xx_mmu_en 双使能差异（priv mux + MPRV） | MMU enable 模型 |
| 12 | GAP-BP.6 | rtu_yy_xx_flush 影响范围（MB / ReqQ / PDE cache / TWU 各自是否清空）需明确 | 异常恢复路径 |

---

## 7. 后续动作

1. 主计划 [doc/MMU_VerificationPlan.md](MMU_VerificationPlan.md) 按本报告逐条 in-place 修订（§2 设计概述、§5 Feature List、§6 Test Case、§7 覆盖率、§11 风险、§12 Traceability）
2. [doc/MMU_Traceability_Matrix.csv](MMU_Traceability_Matrix.csv) 同步追加新行
3. 第 6 节"设计 Review 建议清单" 12 项作为下次设计-验证联合评审议程
4. §11 风险表追加：**R11 = A/D bit 仅 trap-only，无硬件 write-back，对软件 hot page 触发频繁 page fault 的容忍度需评估**

---

*END OF MMU_GapAudit_v1.md*
