# MMU Verification Plan

> **DUT**：`mmu/rtl/ct_mmu_top.v`（OpenRISCV2030 MMU，Sv39 分页）
> **文档版本**：v3.0（RTL 二次核对 + 新 Bug 补充版）
> **发布日期**：2026-04-22
> **模板依据**：[doc/IC验证计划_报告_签核清单.md](IC验证计划_报告_签核清单.md) §1.2 IP 验证计划模板
> **UVM 环境搭建参考**：[doc/MMU_UVM_搭建计划_v2_代码级.md](MMU_UVM_搭建计划_v2_代码级.md)
> **流程参考**：[hpdcache_verification/docs/TestPlan/](../hpdcache_verification/docs/TestPlan)

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| v0.1 | 2026-04-22 | Verification Team | 骨架建立 |
| v1.0 | 2026-04-22 | Verification Team | 首次完整发布（Draft） |
| v2.0 | 2026-04-22 | Verification Team | RTL精读补充：修正F1.1 entry数量（32→16）、F2.3 MB Entry FSM 7状态（补WFG/ACFLT）、F8.2 INVVA single-pass描述；新增F2.3a/b、F3.NEW.1、F4.NEW.1~3、F5.NEW.1、F7.NEW.1~2、F8.NEW.1、F10.NEW.1、F12.NEW.1共12个功能点；12条BUG_HUNT TC；10个新覆盖组；6条新SVA；R15-R18风险；接口表补全 |
| v3.0 | 2026-04-22 | Verification Team | RTL 二次核对 + 用户对 thd_chk 语义的澄清（thd_chk 必为叶 PTE）：证伪 plan_v1 中 6 条疑似缺陷（mmu_arb bank mask literal / twu CSR case 重复 / CSR FSM IDLE else / 跨级 fetch_type 误用 / thd_chk 4K 页 A-bit 检测缺失 / MAEE=0 叶 PTE refill 误触）→ 降级 TC-BUG-001/002/003/004，删除 TC-BUG-009/010；**新增 PTW→LSU 取 PTE 通道串行单 outstanding 协议验证（F4.42a/b/c，3 covergroup bins + 6 SVA）**；新发现 **1 条 P0 高危 Bug**：`twu.sv` L1130 分支重复导致 2MB CSR 跨界 `csr_data_flop` 不更新（F4.NEW.4/TC-BUG-011）；新增 3 条 P1 盲点：csr_grant 互斥（F4.NEW.5）、ptw_write 双级流水 reset 竞争（F5.NEW.2）、xbar 轮转复位偏向 TWU0（F5.NEW.3）；新增 1 条 P2 文档项（F8.NEW.2 死代码清理）；R19 新增，R15/R16 证据强化；追加 `cg_twu_2m_csr_cross` / `cg_xbar_cold_start` / `cg_l2_store_dtlb_tag` + `sva_twu_2m_cross_data` / `sva_csr_grant_onehot` / `sva_ptw_write_pipe_reset_safe`；接口表补齐 `mmu_xx_mmu_en` / `mmu_cp0_tlb_done`；配套 plan_v2.md |

---

## Table of Contents

1. [引言（Introduction）](#1-引言introduction)
2. [设计概述（Design Overview）](#2-设计概述design-overview)
3. [验证策略与方法论（Verification Strategy & Methodology）](#3-验证策略与方法论verification-strategy--methodology)
4. [验证环境架构（Testbench Architecture）](#4-验证环境架构testbench-architecture)
5. [待验证功能点列表（Feature List）](#5-待验证功能点列表feature-list)
6. [测试用例计划（Test Case Plan）](#6-测试用例计划test-case-plan)
7. [覆盖率计划（Coverage Plan）](#7-覆盖率计划coverage-plan)
8. [回归测试策略（Regression Strategy）](#8-回归测试策略regression-strategy)
9. [签核标准（Signoff Criteria）](#9-签核标准signoff-criteria)
10. [资源与时间表（Resources & Schedule）](#10-资源与时间表resources--schedule)
11. [风险评估与规避（Risk Assessment & Mitigation）](#11-风险评估与规避risk-assessment--mitigation)
12. [Traceability Matrix（追溯矩阵节选）](#12-traceability-matrix追溯矩阵节选)

配套 CSV：[MMU_Traceability_Matrix.csv](MMU_Traceability_Matrix.csv)

---

## 1. 引言（Introduction）

### 1.1 文档目的

本文档详细阐述了对 **OpenRISCV2030 MMU IP 核** 进行功能验证的全面计划，旨在确保其设计完全符合 Sv39 RISC-V 特权规范以及内部架构规格书的要求。目标读者：

- 验证工程师（环境与测试开发、回归维护）
- 设计工程师（交付 RTL、回答 Bug、协助覆盖率分析）
- 架构师（签核技术决策）
- 项目经理（进度与资源调度）
- 后端与 SoC 集成团队（集成前依赖此签核）

本计划定义：**为什么要验证（Why）/ 验证什么（What）/ 如何验证（How）/ 何时可以签核（When）**。

### 1.2 项目背景

DUT 是一颗 64 位乱序多发射处理器的 MMU 子系统，负责把 IFU / LSU 发出的虚拟地址翻译为物理地址，完成权限检查、TLB 管理、页表走查（PTW）、物理内存保护（PMP）接口与系统地址映射（SysMap）。架构要点：

- **分页模式**：仅实现 Sv39（3 级页表、VA=39 bit、VPN=27 bit、PPN=28 bit、PTE=64 bit）
- **TLB 层次**：L1 ITLB（单端口，全相联 + PLRU）、L1 DTLB（双端口 Pipe0/Pipe1 + 信用式 Miss Buffer）、L2 TLB/JTLB（Skew-Associative，8 路 × 8 Bank，RRPV 替换）
- **PTW**：支持 4 个并发 Tree Walk Unit，6~8 个 PMP 端口
- **软硬件协同**：SFENCE.VMA 粒度无效化、双 SATP、16 bit ASID、MXR/SUM/MPRV 全支持

### 1.3 参考文档

| 编号 | 文档 | 版本 | 用途 |
|------|------|------|------|
| R01 | RISC-V Privileged Specification (Sv39) | v20211203 | Sv39 分页规范 |
| R02 | OpenRISCV2030 MMU 架构规格（对标 `mmu/rtl` 源码） | 源码即规格（DUT 注释） | 端口/内部机制 |
| R03 | [ct_mmu_top.v](../mmu/rtl/ct_mmu_top.v) | current | 顶层接口 |
| R04 | [doc/IC验证计划_报告_签核清单.md](IC验证计划_报告_签核清单.md) | 2026-04-21 | 验证流程模板 |
| R05 | [doc/MMU_UVM_搭建计划_v2_代码级.md](MMU_UVM_搭建计划_v2_代码级.md) | v2 | UVM 环境搭建（HOW） |
| R06 | [hpdcache_verification/docs/TestPlan/Test_Items_Structured.md](../hpdcache_verification/docs/TestPlan/Test_Items_Structured.md) | current | Test Item 排版参考 |
| R07 | [hpdcache_verification/docs/TestPlan/HPDcache_TRISTAN_IP_Hardware_tp_V1.xlsx](../hpdcache_verification/docs/TestPlan/HPDcache_TRISTAN_IP_Hardware_tp_V1.xlsx) | V1 | 追溯矩阵 CSV 风格参考 |

### 1.4 术语缩写

| 缩写 | 含义 |
|------|------|
| TLB | Translation Lookaside Buffer |
| ITLB / DTLB / JTLB | Instruction / Data / Joint (L2) TLB |
| PTW | Page Table Walker |
| TWU | Tree Walk Unit |
| PTE / PDE | Page Table Entry / Page Directory Entry |
| PMP | Physical Memory Protection |
| SysMap | 硬件地址映射旁路（bypass TLB） |
| VA / PA / VPN / PPN | Virtual / Physical Address / Virtual / Physical Page Number |
| SATP | Supervisor Address Translation and Protection register |
| ASID | Address Space Identifier |
| MXR / SUM / MPRV | Make eXecutable Readable / Supervisor User Memory / Modify PRiVilege |
| RRPV | Re-Reference Prediction Value（L2 TLB 替换策略） |
| PLRU | Pseudo-LRU |
| CDV | Coverage-Driven Verification |
| CSR | Control and Status Register |
| SB | Scoreboard |
| SVA | SystemVerilog Assertion |

---

## 2. 设计概述（Design Overview）

### 2.1 功能描述

MMU 的主要职责：

1. **地址翻译**：VA → PA（Sv39, 4 KB / 2 MB / 1 GB 页面）
2. **权限检查**：基于当前特权模式、PTE 权限位、MXR/SUM/MPRV 配置
3. **多端口并发**：1 个 IFU 端口 + 3 个 LSU 端口（Pipe0 / Pipe1 / Pipe2-prefetch）+ STAMO 端口
4. **TLB 管理**：两级 TLB，支持巨页、ASID、全局页
5. **页表走查**：SATP 根 → 3 级 PTE 读取（通过 LSU 数据端口获取）
6. **系统保护**：PMP 接口（8 端口并发）、SysMap 旁路（8 region）
7. **软件操作**：SFENCE.VMA、TLB 读写探针（TLBP/TLBR/TLBWI/TLBWR）
8. **异常上报**：Page Fault、Access Fault、bad VPN 登记
9. **低功耗**：时钟门控、扫描使能

### 2.2 MMU 顶层框图

```
                 ┌──────────────────────────────────────────────────────┐
                 │                       CP0 / Regs                     │
                 │   SATP / priv_mode / MXR / SUM / MPRV / ptw_en / ... │
                 └───────┬──────────────────────────┬───────────────────┘
                         │                          │
       IFU ──▶ ┌─────────▼─────────┐        ┌───────▼────────┐
               │    L1 ITLB         │        │   TLB Oper      │
               │  (single port,     │        │  SFENCE /       │
               │   PLRU, huge)      │        │  TLBP/R/WI/WR   │
               └─────────┬─────────┘        └───────┬────────┘
                         │ miss                     │ inv broadcast
       LSU Pipe0 ─▶┌─────▼─────────┐                │
       LSU Pipe1 ─▶│   L1 DTLB      │                │
       LSU Pipe2 ─▶│  (2 port, MB8) │                │
       STAMO    ─▶│                 │                │
                   └────┬─────┬─────┘                │
                        │ miss│ miss                 │
                        ▼     ▼                      │
                   ┌─────────────────┐   arb         │
                   │  mmu_arb +      │◀──────────────┘
                   │  one_to_4_xbar  │
                   └────┬────────────┘
                        ▼
                   ┌─────────────────────────────────────────┐
                   │  L2 TLB (JTLB)                          │
                   │  8 Bank × 8 Way Skew-Assoc, RRPV        │
                   │  ReqQ 9 / Miss Buffer 8                 │
                   └──┬───────────────────────┬──────────────┘
                      │ miss                  │ refill to L1
                      ▼                       └──▶ ITLB/DTLB
                   ┌─────────────────────────────────────────┐
                   │  PTW                                    │
                   │  ├─ 4 TWU (concurrent walks)            │
                   │  ├─ L1PDE Cache / L2PDE Cache           │
                   │  └─ ptw_mbuf                            │
                   └──┬─────────────────────┬────────────────┘
                      │ PA check            │ PTE read
                      ▼                     ▼
                   ┌─────────┐        ┌──────────────┐
                   │ SysMap  │        │  LSU data    │
                   │ 8 region│        │  req channel │
                   └─────────┘        └──────────────┘
                      │
                      ▼
                   ┌─────────┐
                   │  PMP    │ (8 port flg/fetch)
                   └─────────┘
```

### 2.3 外部接口分组

顶层 [ct_mmu_top.v](../mmu/rtl/ct_mmu_top.v) 的 8 组接口：

| # | 接口组 | 方向 | 关键信号（摘要） | 作用 |
|---|--------|------|------------------|------|
| 1 | CP0 / CSR | IN/OUT | `cp0_mmu_*` / `mmu_cp0_*` / `cp0_yy_priv_mode` | CSR 配置 + SATP 读写 |
| 2 | IFU | IN/OUT | `ifu_mmu_va_vld/va/abort`、`mmu_ifu_pa/pavld/pgflt/deny/buf/ca/sec` | 取指 VA→PA |
| 3 | LSU Pipe0/1 | IN/OUT | `lsu_mmu_va{0,1}_vld/va/id/st_inst/abort/vabuf`、`mmu_lsu_pa{0,1}_*` | 访存 VA→PA，2 路并发 |
| 4 | LSU Pipe2（prefetch） | IN/OUT | `lsu_mmu_va2_vld/va2[27:0]`、`mmu_lsu_pa2_*` | 预取通道 |
| 5 | LSU STAMO | IN | `lsu_mmu_stamo_vld/pa` | 原子操作 PA 通报 |
| 6 | LSU TLB Inv | IN/OUT | `lsu_mmu_tlb_*inv*`、`lsu_mmu_tlb_va/asid`、`mmu_lsu_tlb_inv_done` | SFENCE.VMA |
| 7 | LSU Data（PTW 取 PTE 通道） | OUT/IN | `mmu_lsu_data_req/addr/size`、`lsu_mmu_data/data_vld/bus_error`、`mmu_lsu_tlb_busy/wakeup[11:0]` | PTW 通过 LSU 发起 PTE 读；**v3.0 明确：采用严格串行单 outstanding 握手协议**——`mmu_lsu_data_req` 拉高后必须保持 `mmu_lsu_data_req` 和 `mmu_lsu_data_req_addr` 稳定直到 `lsu_mmu_data_vld` 返回；无 tag/ID 字段，一次最多一个 outstanding，禁止 LSU 乱序返回（F4.42a~c）。注：`mmu_lsu_tlb_busy` 仅表 MBUF 满；`mmu_lsu_wakeup[11:0]` 为 TLB 层面广播，与 PTE 取数握手无关 |
| 8 | PMP | IN/OUT | `pmp_mmu_flg{0-7}[3:0]`、`mmu_pmp_pa{0-7}`、`mmu_pmp_fetch{3,5,6,7}` | 8 端口 PMP 权限联动 |
| 9 | RTU | IN | `rtu_mmu_bad_vpn/expt_vld`、`rtu_yy_xx_flush` | 异常与 flush |
| 10 | 性能计数（HPCP） | IN/OUT | `hpcp_mmu_cnt_en`、`mmu_hpcp_*_miss` | 性能事件计数 |
| 11 | Debug / 扫描 / SMP | IN/OUT | `mmu_had_debug_info[33:0]`、`pad_yy_icg_scan_en`、`biu_mmu_smp_disable` | Debug / DFT |
| 12 | 广播状态 | OUT | `mmu_yy_xx_no_op` | MMU no-op 状态广播（F10.NEW.1；信号已在 RTL 实现但未列入原接口表）|
| 13 | 全局使能与 TLB Oper 完成 | OUT | `mmu_xx_mmu_en`、`mmu_lsu_mmu_en`、`mmu_cp0_tlb_done` | v3.0 补：顶层 MMU 使能广播（核内各子单元使用）、LSU 侧专用使能、TLB Oper 完成握手 |
| 14 | CSR 细分控制 | IN | `cp0_mmu_cskyee`、`cp0_mmu_reg_num[1:0]`、`cp0_mmu_mpp[1:0]`、`cp0_mmu_wdata[63:0]`、`cp0_mmu_wreg` | v3.0 补：CSR 侧细分信号（CSKYEE 扩展、寄存器号、MPP、CSR 写通道） |

> **v2.0 接口补充**：`pmp_mmu_flg5/6/7` 为后期新增 PTW 扩展端口（RTL 中标注 `[NEW]` / `!!!!!`，F7.NEW.2）；`mmu_pmp_fetch4` 已注释掉（F7.NEW.1）；`lsu_mmu_va2[27:0]` 仅 28 位（传 VPN 而非完整 VA）；`ifu_mmu_va[62:0]` 仅 63 位（bit63 省略）。
>
> **v3.0 接口补充**：补齐 `mmu_xx_mmu_en`（顶层 MMU 使能广播，与 `mmu_lsu_mmu_en` 语义不同）与 `mmu_cp0_tlb_done`（TLB Oper 完成握手，v1 遗漏）；`regs_ptw_cur_asid` 内部为 16-bit（与 SATP.ASID 宽度一致，原 8-bit 注释误记）；`ct_mmu_top.v` 未暴露任何 `pmp_mmu_fetch*` 输入（fetch 方向仅为 MMU→PMP 的 `mmu_pmp_fetch{3,5,6,7}`）。

### 2.4 时钟与复位

- 单时钟域：`forever_cpuclk`
- 低电平同步复位：`cpurst_b`
- 时钟门控：受 `cp0_mmu_icg_en` 控制，扫描模式下强制打开
- SMP Disable：`biu_mmu_smp_disable` 关闭核间一致性相关广播

### 2.5 配置空间

详见 [ct_mmu_regs.v](../mmu/rtl/ct_mmu_regs.v)。MMU 相关 CSR 子集：

| 寄存器 | 宽度 | 功能 |
|--------|------|------|
| SATP0 / SATP1 | 64 | MODE + ASID[15:0] + PPN[27:0]；`cp0_mmu_satp_sel` 选择 |
| MSTATUS.MXR/SUM/MPRV/MPP | - | 权限相关（来自 CP0，间接输入 MMU） |
| MMU Control | - | `ptw_en` / `maee` / `no_op_req` / `tlb_all_inv` 等 |
| TLB Index / Entry（TLBP/R/WI/WR） | - | 软件 TLB 操作的中间寄存器 |
| HPCP 计数器 | - | miss 事件外送 |

### 2.6 内存映射（SysMap 8 Region）

详见 [sysmap.h](../mmu/rtl/sysmap.h) 与 [ct_mmu_sysmap.v](../mmu/rtl/ct_mmu_sysmap.v)。硬件旁路 8 个地址区间，每个区间返回 5-bit 属性 flag（cacheable / bufferable / executable / readable / writable / secure 等组合），优先级 **高于 TLB**。

---

## 3. 验证策略与方法论（Verification Strategy & Methodology）

### 3.1 总体策略

**覆盖率驱动验证（Coverage-Driven Verification, CDV）** 为主，辅以：

1. **定向测试（Directed）**：用于必须精确时序与状态的场景（SFENCE 与 in-flight walk 的冲突、RRPV 初值验证、SysMap 边界）。
2. **约束随机测试（Constrained-Random）**：用于激励空间巨大的场景（Sv39 地址空间、ASID × priv × 权限组合、多 pipe 并发）。
3. **错误注入测试（Error Injection）**：非法 PTE、总线错误、PMP 拒绝、未对齐 PPN。
4. **性能/压力测试**：TLB thrashing、PTW 全端口打满、多 ASID 热切换、1 GB 巨页。
5. **断言验证（SVA）**：接口协议、状态机合法性、不可变量（invariant）；关键 replacement 行为。

**形式验证**：作为可选增量（章节 11 风险缓解），优先对 `mmu_arb` / `pplru` / `one_to_four_xbar` 这类纯组合+小状态模块应用（如 JasperGold FPV 模型）。

### 3.2 验证语言与工具

| 类别 | 选型 |
|------|------|
| HDL | SystemVerilog 2012 / Verilog 2001 |
| 方法学 | UVM 1.2 |
| 仿真器 | **Synopsys VCS**（主）+ Verdi（调试）|
| 覆盖率合并 | URG（VCS 自带） |
| 脚本 | Python 3.9（复用 `hpdcache_verification/scripts/run_test.py` 与 `run_vcs_verdi.py`）、Perl（`scan_logs.pl`） |
| 回归调度 | Makefile + `run_test.py`；CI 可选 Jenkins/GitLab |
| Formal（可选） | JasperGold / VC Formal |
| Lint / CDC | Spyglass / VC SpyGlass |

### 3.3 参考模型（Reference Model）

软件参考模型（SV class，位于 `mmu_verification/testbench/env/refmodel/`）：

- **`mmu_refmodel`**：顶层，包含
  - `shadow_pagetable`：维护当前 SATP 指向的多级页表内存（与 PTW-Mem Agent 的 shadow memory 一致）
  - `shadow_tlb_l1_itlb` / `shadow_tlb_l1_dtlb` / `shadow_tlb_l2`：预测每级 TLB 命中与更新
  - `translate_va(va, asid, priv, mxr, sum, mprv, is_inst, is_store)` → `{pa, pgfault, access_fault, attrs}`
  - **替换策略建模**：PLRU（L1）与 RRPV（L2）行为级模型，用于预测 victim way
  - **SFENCE 行为**：镜像执行 `ct_mmu_tlboper.v` 的无效化语义
- **覆盖率与结果**：逐 transaction 送入 `mmu_translation_sb` 与 DUT 输出对比。

### 3.4 可重用性

- 7 个 Agent（见 §4）按 UVM 标准设计，将复用到后续 SoC 级验证。
- 覆盖组、断言、refmodel 全部 package 化，便于 SoC 级复用。
- 复用 `hpdcache_verification/modules/dv_utils/`（clock_gen / reset_gen / bp_gen / watchdog / memory_rsp_model / memory_shadow / perf_mon / generic_agent）。

---

## 4. 验证环境架构（Testbench Architecture）

### 4.1 UVM 环境框图

```
                ┌─────────────────────── mmu_tb_top ──────────────────────┐
                │                                                          │
                │         ┌────────────────── mmu_env ─────────────────┐   │
                │         │                                              │   │
   ┌────┐       │   ┌────▶│ ifu_agent  ───analysis───────┐               │   │
   │CG/R│◀──────┼───┘     │ lsu_agent  ───analysis──────┐│               │   │
   │FM  │       │         │ cp0_agent  ───analysis─────┐││               │   │
   └────┘       │         │ tlb_inv_agent──────────────┼┼┼─▶ scoreboards │   │
                │         │ ptw_mem_agent(responder)───┼┼┤   ├ translation│   │
                │         │ pmp_agent   (responder) ───┼┼┤   ├ coherency  │   │
                │         │ sysmap_cfg_agent ──────────┼┼┤   ├ invalidation│   │
                │         │ virtual_sequencer          │││   └ performance │   │
                │         │                            │││                 │   │
                │         │ reference_model ◀──────────┘││                 │   │
                │         │ (shadow PT + shadow TLBs)   ││                 │   │
                │         └─────────────────────────────┴┘                 │   │
                │                                                          │   │
                │      ┌──── DUT: ct_mmu_top ────┐   SVA bind (top/*_sva) │   │
                │      │                          │◀──────────────────────┘   │
                │      └──────────────────────────┘                           │
                └──────────────────────────────────────────────────────────┘
```

### 4.2 组件职责

| 组件 | 类别 | 职责 |
|------|------|------|
| `ifu_agent` | Active | 驱动 IFU 取指 VA，监测 PA/pgflt/deny；采样 IFU 覆盖组 |
| `lsu_agent` | Active | 驱动 Pipe0/1/2/STAMO 四类事务；监测 PA 回写；含 TLB Inv 子通道 |
| `cp0_agent` | Active | 驱动 CSR 写（SATP/MXR/SUM/MPRV/priv_mode），监测 cmplt |
| `tlb_inv_agent` | Active | SFENCE.VMA 语义激励（可合并进 `lsu_agent`，按实现决定） |
| `ptw_mem_agent` | Responder + Active | 维护 shadow 页表；响应 PTW 的 PTE 读；注入总线错误与延时 |
| `pmp_agent` | Responder | 按地址范围返回 pmp_mmu_flg[3:0]；支持 8 端口独立行为 |
| `sysmap_cfg_agent` | Active | 初始化 SysMap 8 region 的基址/掩码/权限 |
| `virtual_sequencer` | - | 运行跨 Agent 的 `*_vseq` |
| `mmu_translation_sb` | Checker | 端到端 VA→PA 翻译正确性 + 权限 |
| `mmu_coherency_sb` | Checker | L1/L2 TLB 内容与 shadow 一致性（事件驱动采样） |
| `mmu_invalidation_sb` | Checker | SFENCE 后的 TLB 状态一致性 |
| `mmu_perf_mon` | Monitor | miss rate、walk latency、bank conflict rate |
| `reference_model` | Model | 见 §3.3 |

### 4.3 数据流

1. `cp0_agent` 在 test 启动阶段配置 SATP / priv / MXR / SUM。
2. `ptw_mem_agent.page_table_builder` 根据 refmodel 构造一致的 Sv39 页表到 shadow memory。
3. `sysmap_cfg_agent` 配置 8 SysMap region；`pmp_agent` 配置 PMP 规则。
4. `ifu_agent` / `lsu_agent` 发起地址翻译请求 → DUT。
5. Monitor 把请求、响应、PTW-Mem 访问全部送入 refmodel，refmodel 预测后由 `mmu_translation_sb` 逐 transaction 对齐检查。
6. `mmu_perf_mon` 采集并上报周期性指标。
7. 全局 SVA 由 `testbench/top/*_sva.sv` 绑定到 DUT 内部关键信号。

---

<!-- ===== Feature List & Test Cases (generated by Phase B/C subagents) ===== -->

## 5. 待验证功能点列表（Feature List）

> 本章共 14 大类（F1–F14），**预计 100–200 条功能点**。每条记录对应至少 1 条 Test Case（§6）与 1 个 Covergroup / SVA（§7），并在 Traceability Matrix（§12 + CSV）中登记。
>
> **字段说明**：
> - **F-ID**：全局唯一功能点编号（F<大类>.<子项>）
> - **模块**：所属 RTL 模块 / 子系统
> - **描述**：一句话 what-to-verify
> - **依据**：RTL 文件 / 注释行 / Sv39 规范章节
> - **优先级**：P0（阻塞签核）/ P1（主要）/ P2（次要）
> - **TC-Refs**：对应的 Test Case ID 列表（见 §6）
> - **Cov/SVA**：Covergroup 或 SVA 绑定

### 5.1 L1 TLB — ITLB (F1) + DTLB (F2)

> 模块范围：**L1 ITLB + L1 DTLB (F1, F2)**

### 5.1 F1 — L1 ITLB

| F-ID | 模块 | 描述 | 依据 | 优先级 | TC-Refs | Cov/SVA |
|------|------|------|------|--------|---------|---------|
| F1.1 | `mmu_l1itlb` / `ct_mmu_iplru` | 单端口 PLRU 替换：**16 entry** 全相联（entry0-15），LRU 树更新 | [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L1), [ct_mmu_iplru.v](mmu/rtl/ct_mmu_iplru.v#L20-L43) | P0 | ITLB_HIT_001, ITLB_PLRU_001, ITLB_PLRU_002 | cg_ifu_rsp, sva_plru_valid |
| F1.2 | `ct_mmu_iutlb_entry` | TLB项有效性与权限缓存：V/R/W/X/U/G/A/D bits | [ct_mmu_iutlb_entry.v](mmu/rtl/ct_mmu_iutlb_entry.v#L1) | P0 | ITLB_PERM_001, ITLB_PERM_002, ITLB_PGFLT_001 | cg_ifu_req, sva_entry_valid |
| F1.3 | `mmu_l1itlb` | 4K页面VA→PA翻译：VPN27→PPN28映射+offset12 | Sv39 规范, [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L80-L120) | P0 | ITLB_HIT_001, ITLB_HUGE_001 | cg_ifu_rsp |
| F1.4 | `ct_mmu_iutlb_fst_entry` | 2MB巨页支持：PPN[26:10]全零检查+offset21 | [ct_mmu_iutlb_fst_entry.v](mmu/rtl/ct_mmu_iutlb_fst_entry.v#L1) | P1 | ITLB_HUGE_001, ITLB_HUGE_002 | cg_huge_page, sva_giant_ppn |
| F1.5 | `mmu_l1itlb` | 1GB巨页支持：PPN[26:0]全零检查+offset30 | [ct_mmu_iutlb_fst_entry.v](mmu/rtl/ct_mmu_iutlb_fst_entry.v#L1) | P1 | ITLB_HUGE_003 | cg_huge_page |
| F1.6 | `mmu_l1itlb` + CP0 | 全局页(G位)：跨ASID TLB项有效保留 | Sv39规范, [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L200) | P1 | ITLB_ASID_001, ITLB_ASID_002 | cg_csr, sva_global_page |
| F1.7 | `mmu_l1itlb` | L2 TLB Miss处理：refill路径与credit控制 | [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L120-L160) | P0 | ITLB_REFILL_001, ITLB_REFILL_002 | sva_l2tlb_interface |
| F1.8 | `mmu_l1itlb` | 取指Abort语义：VA无效时立即cancel（ifu_abort） | [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L50) | P1 | ITLB_ABORT_001 | sva_abort_protocol |
| F1.9 | `mmu_l1itlb` | 执行权限检查：X=0时page fault，U/M模式 | Sv39规范, [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L180) | P0 | ITLB_PERM_001, ITLB_PERM_002 | cg_cross_scenario, sva_perm_check |
| F1.10a | `ct_mmu_tlboper` + `mmu_l1itlb` | SFENCE.VMA INV_ALL：无条件全 ITLB 失效 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v#L685-L730) | P0 | ITLB_INV_001 | cg_tlb_inv, sva_inv_done |
| F1.10b | `ct_mmu_iutlb_entry` / `ct_mmu_iutlb_fst_entry` | **SFENCE.VMA INV_VA：RTL 仅比对 vpn[7:0] 8-bit**（K2/GAP-I1.4，与 Sv39 27-bit 完整 VPN 不一致，需设计 review）| [ct_mmu_iutlb_entry.v#L94-L95](mmu/rtl/ct_mmu_iutlb_entry.v#L94), [ct_mmu_iutlb_fst_entry.v#L122-L123](mmu/rtl/ct_mmu_iutlb_fst_entry.v#L122) | P0 | ITLB_INV_002, ITLB_INV_VA8_alias_001 | cg_inv_va_alias |
| F1.10c | `ct_mmu_tlboper` + `mmu_l1itlb` | INV_ASID / INV_VA_ASID 失效；G=1 page 不受 ASID 失效影响 | [ct_mmu_tlboper.v#L685-L730](mmu/rtl/ct_mmu_tlboper.v#L685) | P0 | ITLB_INV_003 | cg_tlb_inv |
| F1.11 | `mmu_l1itlb` | TLB Probe软件探针：TLBP读取匹配项索引 | Sv39规范, [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L250) | P2 | ITLB_PROBE_001 | cg_software_ops |
| F1.12 | `mmu_l1itlb` + RTU | 分支flush：Fetch abort与RTU flush同时处理 | [mmu_l1itlb.sv](mmu/rtl/mmu_l1itlb.sv#L40), RTU接口 | P1 | ITLB_FLUSH_001 | sva_concurrent_flush |
| F1.13 | `ct_mmu_iutlb_fst_entry` vs `ct_mmu_iutlb_entry` | FST/huge entry 与普通 entry 共存语义：何时使用 FST、替换交互（GAP-I1.2） | [ct_mmu_iutlb_fst_entry.v](mmu/rtl/ct_mmu_iutlb_fst_entry.v#L1), [ct_mmu_iutlb_entry.v](mmu/rtl/ct_mmu_iutlb_entry.v#L1) | P1 | ITLB_FST_MIX_001 | cg_huge_page |
| F1.14 | `ct_mmu_iplru` | PLRU 树（p00/p10/...）reset 后初值（全 0）→ 首次替换 tie-break 行为（GAP-I1.3 / GAP-X3.6） | [ct_mmu_iplru.v#L50-L150](mmu/rtl/ct_mmu_iplru.v#L50) | P0 | ITLB_PLRU_RST_001 | sva_plru_reset_init |
| F1.15 | `mmu_l1itlb` + `ct_mmu_tlboper` | L2 refill 完成与 INV_VA 同周期命中同 entry 的 FSM 冲突仲裁（GAP-I1.5） | [mmu_l1itlb.sv#L100-L150](mmu/rtl/mmu_l1itlb.sv#L100) | P1 | ITLB_REFILL_INV_RACE_001 | sva_refill_inv_excl |
| F1.16 | `ct_mmu_iplru` | 同周期 hit + refill 不同 entry 的 PLRU 串行更新冲突（GAP-I1.6） | [ct_mmu_iplru.v#L120-L160](mmu/rtl/ct_mmu_iplru.v#L120) | P1 | ITLB_PLRU_HIT_REFILL_001 | sva_plru_serialize |
| F1.17 | `mmu_l1itlb` | `pgs[2:0]` 编码与 page-size mismatch 处理（GAP-I1.7） | [mmu_l1itlb.sv#L50-L120](mmu/rtl/mmu_l1itlb.sv#L50) | P1 | ITLB_PGS_MISMATCH_001 | cg_huge_page |
| F1.18 | `mmu_l1itlb` | `ifu_abort` 在 refill 流水线中段断言时的 speculative kill（GAP-I1.8） | [mmu_l1itlb.sv#L50-L65](mmu/rtl/mmu_l1itlb.sv#L50) | P1 | ITLB_ABORT_REFILL_001 | sva_abort_protocol |

### 5.2 F2 — L1 DTLB

| F-ID | 模块 | 描述 | 依据 | 优先级 | TC-Refs | Cov/SVA |
|------|------|------|------|--------|---------|---------|
| F2.1 | `mmu_l1dtlb` | 双端口并发访问：Pipe0/Pipe1同周期hit路径无冲突 | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L80-L120), [mmu_l1dtlb_hit_rd.sv](mmu/rtl/mmu_l1dtlb_hit_rd.sv#L1) | P0 | DTLB_HIT_001, DTLB_HIT_002, DTLB_CONCURRENT_001 | cg_lsu_req, sva_dual_port |
| F2.2 | `mmu_l1dtlb` | 16 Entry PLRU替换：MB_DEPTH=8时替换优先级 | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L1), [mmu_l1dtlb_allocator.sv](mmu/rtl/mmu_l1dtlb_allocator.sv#L1) | P0 | DTLB_ALLOC_001, DTLB_PLRU_001 | cg_dtlb, sva_replace_way |
| F2.3 | `mmu_l1dtlb` | Miss Buffer 管理：8 深 MB + 3-bit credit；MB entry FSM 涵盖 IDLE/WFG/WFC/WFI/PGFLT/ACFLT/ABT **七状态**转换（GAP-D2.1；RTL确认：WFG=等待L2仲裁grant，ACFLT=访问错误） | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L10), [mmu_l1dtlb_mb_entry.sv#L105-L160](mmu/rtl/mmu_l1dtlb_mb_entry.sv#L105) | P0 | DTLB_MB_001, DTLB_MB_002, DTLB_CREDIT_001, DTLB_MB_FSM_WFI_001 | cg_dtlb, sva_credit_conserv |
| F2.4 | `mmu_l1dtlb` | 4K页面翻译：VPN27→PPN28+offset12（双端口） | Sv39规范, [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L80) | P0 | DTLB_HIT_001, DTLB_HIT_002 | cg_lsu_rsp |
| F2.5 | `ct_mmu_dutlb_huge_entry` | 2MB巨页支持：PPN[26:10]=0检查+offset21 | [ct_mmu_dutlb_huge_entry.v](mmu/rtl/ct_mmu_dutlb_huge_entry.v#L1) | P1 | DTLB_HUGE_001, DTLB_HUGE_002 | cg_huge_page |
| F2.6 | `ct_mmu_dutlb_huge_entry` | 1GB巨页支持：PPN[26:0]=0检查+offset30 | [ct_mmu_dutlb_huge_entry.v](mmu/rtl/ct_mmu_dutlb_huge_entry.v#L1) | P1 | DTLB_HUGE_003 | cg_huge_page |
| F2.7 | `mmu_l1dtlb` | 读权限检查：R=0时page fault，MXR影响X位可读 | Sv39规范+MXR, [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L150) | P0 | DTLB_PERM_LD_001, DTLB_PERM_LD_002 | cg_cross_scenario, sva_ld_perm |
| F2.8 | `mmu_l1dtlb` | 写权限检查：W=0时page fault；D-bit更新触发 | Sv39规范+D-bit, [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L160) | P0 | DTLB_PERM_ST_001, DTLB_PERM_ST_002 | cg_cross_scenario, sva_st_perm |
| F2.9 | `mmu_l1dtlb` | Access Fault：超出PMP/SysMap区间返回deny | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L170), PMP接口 | P1 | DTLB_PMP_001, DTLB_SYSMAP_001 | cg_pmp, sva_pmp_interface |
| F2.10 | `mmu_l1dtlb_scheduler` | 信用调度：两路并发公平性；credit 边界（0 / CREDIT_MAX）与同周期 req_fire & credit_return 环绕（GAP-D2.4） | [mmu_l1dtlb_scheduler.sv#L70-L100](mmu/rtl/mmu_l1dtlb_scheduler.sv#L70) | P0 | DTLB_SCHED_001, DTLB_CREDIT_002, DTLB_CREDIT_BOUND_001 | cg_scheduler, sva_fairness |
| F2.11 | `mmu_l1dtlb` | Abort处理：未完成请求即时cancel（stall释放） | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L50) | P1 | DTLB_ABORT_001 | sva_abort_semantics |
| F2.12 | `mmu_l1dtlb` | L2 TLB Miss处理：refill路径与多源仲裁 | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv#L120-L160), `mmu_arb` | P0 | DTLB_REFILL_001, DTLB_REFILL_002 | sva_l2_interface |
| F2.13 | `mmu_l1dtlb` + CP0 | SFENCE.VMA 失效：支持 INV_ALL/VA/ASID/VA_ASID；**INV_VA 实际仅比对 vpn[7:0] 8-bit**（K2/GAP-I1.4，需为不匹配的 27-bit alias 补补充 alias TC） | Sv39规范, [ct_mmu_dutlb_entry.v#L80-L120](mmu/rtl/ct_mmu_dutlb_entry.v#L80), [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v#L1) | P0 | DTLB_INV_001~004, DTLB_INV_VA8_alias_001 | cg_tlb_inv, sva_inv_done |
| F2.14 | `mmu_l1dtlb` | **STAMO 仅 Pipe0** 真实使用（Pipe1 挂 1'b0），端口不对称（K6/GAP-D2.11） | [mmu_l1dtlb.sv#L70,L428,L514-L515](mmu/rtl/mmu_l1dtlb.sv#L70) | P0 | DTLB_STAMO_PIPE0_001, DTLB_STAMO_PIPE1_NEG_001 | cg_lsu_req, sva_pipe1_no_stamo |
| F2.15 | `mmu_l1dtlb_install` | 三方安装仲裁 PTW > JTLB > WFI；JTLB 被抢占降级到 WFI（GAP-D2.2） | [mmu_l1dtlb_install.sv#L100-L150](mmu/rtl/mmu_l1dtlb_install.sv#L100) | P0 | DTLB_INSTALL_ARB_001 | sva_install_priority |
| F2.16 | `mmu_l1dtlb_allocator` | FFZ allocator 角落：全满（gnt0/gnt1=0）、交替空满模式、与 scheduler race（GAP-D2.3） | [mmu_l1dtlb_allocator.sv#L30-L80](mmu/rtl/mmu_l1dtlb_allocator.sv#L30) | P0 | DTLB_ALLOC_FULL_001, DTLB_ALLOC_RACE_001 | sva_alloc_excl |
| F2.17 | `mmu_l1dtlb_install` | **`mmu_lsu_tlb_wakeup[11:0]` 为广播信号**（`mb_have_free=1` 时全 1），**非 per-entry one-hot**（K5/GAP-D2.15） | [mmu_l1dtlb_install.sv#L233-L235](mmu/rtl/mmu_l1dtlb_install.sv#L233) | P0 | DTLB_WAKEUP_BCAST_001 | sva_wakeup_broadcast |
| F2.18 | `mmu_l1dtlb` | `mmu_lsu_tlb_busy` 仅在 `&mb_entry_vld`（全满）时拉起；阈值不可配（GAP-D2.16） | [mmu_l1dtlb.sv#L1229](mmu/rtl/mmu_l1dtlb.sv#L1229) | P1 | DTLB_BUSY_THRESHOLD_001 | sva_busy_when_full |
| F2.19 | `mmu_l1dtlb_hit_rd` + `mmu_l1dtlb_allocator` | Pipe0 hit + Pipe1 miss 同周期：PLRU 更新与 allocator FFZ 同时 fire（GAP-D2.7） | [mmu_l1dtlb_hit_rd.sv#L80-L120](mmu/rtl/mmu_l1dtlb_hit_rd.sv#L80) | P1 | DTLB_HIT_MISS_CONCURRENT_001 | sva_plru_alloc_excl |
| F2.20 | `mmu_l1dtlb_mb_entry` | PGFLT/ACFLT 与输出信号 hold；ABT 后 refill 晚到防伪 install（GAP-D2.8 / GAP-D2.9 / GAP-D2.13） | [mmu_l1dtlb_mb_entry.sv#L140-L190](mmu/rtl/mmu_l1dtlb_mb_entry.sv#L140) | P1 | DTLB_MB_PGFLT_001, DTLB_MB_ABT_LATE_REFILL_001 | sva_no_install_after_abt |
| F2.21 | `mmu_l1dtlb_install` | MB entry ID 在三方仲裁中不一致 → 数据走错 entry 风险（GAP-D2.10） | [mmu_l1dtlb_install.sv#L80-L110](mmu/rtl/mmu_l1dtlb_install.sv#L80) | P1 | DTLB_INSTALL_ID_CHK_001 | sva_install_id_match |
| F2.22 | `ct_mmu_dutlb_entry` / `ct_mmu_dutlb_huge_entry` + `ct_mmu_dplru` | 16 entry 池中 huge entry 与普通 entry 共存替换；双端口同 VPN 跨 entry 匹配 → PA mux 优先级（GAP-D2.12 / GAP-X3.6 / GAP-X3.7） | [ct_mmu_dutlb_entry.v](mmu/rtl/ct_mmu_dutlb_entry.v#L1), [ct_mmu_dutlb_huge_entry.v](mmu/rtl/ct_mmu_dutlb_huge_entry.v#L1), [ct_mmu_dplru.v](mmu/rtl/ct_mmu_dplru.v#L1) | P1 | DTLB_HUGE_MIX_001, DTLB_DUAL_HIT_MUX_001 | cg_huge_page, sva_pa_mux |
| F2.3a | `mmu_l1dtlb_mb_entry` | **MB Entry Bypass路径**：`alloc_vld` 且同周期获得 `issue_grant` → IDLE 直接进 WFC（跳过 WFG），覆盖最快 miss-to-L2 请求路径（GAP-MB.NEW.1） | [mmu_l1dtlb_mb_entry.sv#L105-L120](mmu/rtl/mmu_l1dtlb_mb_entry.sv#L105) | P1 | TC-BUG-MB-BYPASS-001 | cg_mb_bypass_path |
| F2.3b | `mmu_l1dtlb_mb_entry` | **WFG+abort 竞争**：WFG 状态同周期收到 `issue_grant` 与 `abort` → 进入 ABT 等待迟到 PTW 响应；`abort_hold_r` 机制防止 install 污染（GAP-MB.NEW.2） | [mmu_l1dtlb_mb_entry.sv#L105-L165](mmu/rtl/mmu_l1dtlb_mb_entry.sv#L105) | P0 | TC-BUG-WFG-ABT-001 | cg_mb_fsm_7state, sva_wfg_abt_race |


---

### 5.2 L2 TLB / JTLB (F3)

> 模块范围：**L2 TLB / JTLB (F3)**

## § 5.3 F3 L2 TLB/JTLB Feature List（14 条）

| F-ID | 模块 | 功能描述 | 依据 | 优先级 | 对应 Test Case | Covergroup / SVA |
|------|------|---------|------|--------|-----------------|-----------------|
| **F3.1** | `mmu_l2tlb_reqq` | ReqQ 分配：L1 ITLB miss → 分配 entry 0；L1 DTLB miss → FFZ 分配 entry 1–8 | [mmu_l2tlb_reqq.sv](mmu/rtl/mmu_l2tlb_reqq.sv) L37–60 | P0 | TC-L2TLB-001 ~ 003 | `l2tlb_reqq_cg` |
| **F3.2** | `mmu_l2tlb_reqq` | ReqQ 出队：FFR 仲裁，按优先级选出 ready entry 发向 L2TLB/arb | [mmu_l2tlb_reqq.sv](mmu/rtl/mmu_l2tlb_reqq.sv) L70–90 | P0 | TC-L2TLB-004 ~ 006 | `l2tlb_reqq_cg` / `mmu_arb_sva` |
| **F3.3** | `mmu_l2tlb_reqq` | ReqQ credit：ITLB/DTLB miss 扣减；refill/miss 时返回；满时不返回 credit（压力） | [mmu_l2tlb_reqq.sv](mmu/rtl/mmu_l2tlb_reqq.sv) L100–120 | P0 | TC-L2TLB-007 ~ 009 | `l2tlb_reqq_cg` / `mmu_l2tlb_sva` |
| **F3.4** | `mmu_l2tlb` Tag 阵列 | Tag match：VPN + ASID + PGS + G + valid 全匹配则命中（8 way 并行比较）；支持 4K/2M/1G 三种页大小 | [ct_mmu_l2tlb_tag_array.sv](mmu/rtl/ct_mmu_l2tlb_tag_array.sv) | P0 | TC-L2TLB-010 ~ 012 | `l2tlb_bank_cg` |
| **F3.5** | `mmu_l2tlb` Data 阵列 | Data read：命中时输出 PPN + flags（D/A/U/X/W/R）；支持任意 bank 并行读（8 bank 独立） | [ct_mmu_l2tlb_data_array.sv](mmu/rtl/ct_mmu_l2tlb_data_array.sv) | P0 | TC-L2TLB-013 ~ 015 | `l2tlb_bank_cg` |
| **F3.6** | `mmu_l2tlb_replacement_policy` | RRPV 初值：新 refill entry 的 RRPV = INIT = 4（RRPV_MAX-3 = 7-3 = 4） | [mmu_l2tlb_replacement_policy.sv](mmu/rtl/mmu_l2tlb_replacement_policy.sv) L14 | P0 | TC-RRPV-001 ~ 003 | `l2tlb_bank_cg` |
| **F3.7** | `mmu_l2tlb_replacement_policy` | RRPV promote on hit：命中时 hit way 的 RRPV → 0；其它 ways RRPV 不变 | [mmu_l2tlb_replacement_policy.sv](mmu/rtl/mmu_l2tlb_replacement_policy.sv) L146–155 | P0 | TC-RRPV-004 ~ 006 | `l2tlb_bank_cg` / `mmu_l2tlb_sva` |
| **F3.8** | `mmu_l2tlb_replacement_policy` | RRPV aging on miss：miss 时所有 valid ways 的 RRPV +1，饱和在 MAX=7 | [mmu_l2tlb_replacement_policy.sv](mmu/rtl/mmu_l2tlb_replacement_policy.sv) L157–165 | P0 | TC-RRPV-007 ~ 009 | `l2tlb_bank_cg` / `mmu_rrpv_aging_vseq` |
| **F3.9** | `mmu_l2tlb_replacement_policy` | Victim way 选择：First-Free > Max-RRPV；无空闲时选 RRPV=MAX 的 way（thermometer + priority encoder） | [mmu_l2tlb_replacement_policy.sv](mmu/rtl/mmu_l2tlb_replacement_policy.sv) L75–110 | P0 | TC-RRPV-010 ~ 012 | `l2tlb_bank_cg` / `mmu_l2tlb_sva` |
| **F3.10** | `mmu_l2tlb` + `mmu_arb` | 8 Bank skew-associative：8 独立 hash index（idx_w0 ~ idx_w7），每个 bank 存放一个 way；同一 VPN 在 8 bank 映射到 8 不同 set → 减少 conflict miss | [mmu_l2tlb.sv](mmu/rtl/mmu_l2tlb.sv) L60–70；[mmu_arb.sv](mmu/rtl/mmu_arb.sv) | P0 | TC-BANK-001 ~ 003 | `l2tlb_bank_cg` |
| **F3.11** | `mmu_l2tlb` + `mmu_arb` | Bank 写冲突处理：多请求同周期写同一 bank → arbiter 仲裁，高优先级（PTW > TLBOp > ReqQ > PFU）先写；低优先级记 retry | [mmu_arb.sv](mmu/rtl/mmu_arb.sv) L80–110 | P1 | TC-BANK-004 ~ 006 | `mmu_arb_sva` / `mmu_l2tlb_bank_conflict_vseq` |
| **F3.12** | `mmu_l2tlb_rrpv_wbuf` | RRPV 延迟回写：hit 或 aging 时的 RRPV 更新先进 wbuf，T+1 周期写回阵列，避免阻塞关键路径 | [mmu_l2tlb_rrpv_wbuf.sv](mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv) | P1 | TC-RRPV-013 ~ 014 | `l2tlb_bank_cg` |
| **F3.13** | `mmu_l2tlb` + `mmu_l2tlb_mb` | MB 分配/释放/防重分配：refill 时 MB entry 分配（FFZ）；PTW 完成后释放；同 VPN+ASID 防止重复分配（比较 vpn+asid） | [mmu_l2tlb_mb.sv](mmu/rtl/mmu_l2tlb_mb.sv) L130–160；[mmu_l2tlb_mb_entry.sv](mmu/rtl/mmu_l2tlb_mb_entry.sv) | P0 | TC-MB-001 ~ 006 | `l2tlb_reqq_cg` / `mmu_l2tlb_sva` |
| **F3.14** | `mmu_l2tlb` | TLB 失效协同：L2TLB 同步接收 INVALL/INV_VA/INV_ASID/INV_VA_ASID；与 in-flight refill 互斥（选择器保证原子性） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) + [mmu_l2tlb.sv](mmu/rtl/mmu_l2tlb.sv) | P0 | TC-INV-001 ~ 005 | `mmu_l2tlb_sva` / 外部 `tlb_inv_cg` |
| **F3.15** | `mmu_arb` | **Skew hash 函数实现**：VPN[26:0] 各 bit 如何 XOR 形成 idx_w0..idx_w7（公式化文档+冲突分布）（GAP-Arb.1 / GAP-Hash.1） | [mmu_arb.sv#L150-L220,L350-L450](mmu/rtl/mmu_arb.sv#L150) | P0 | TC-HASH-001~003, TC-HASH-DOC-001 | `l2tlb_skew_hash_cg` |
| **F3.16** | `ct_spram_wrapper` + tag/data array | 同地址同周期 read+write RAW；CEN/GWEN/WEN active-low；按位 WEN 是否真生效（GAP-L2.2 / GAP-SRAM.1 / GAP-SRAM.2 / GAP-L2.6） | [ct_spram_wrapper.sv](mmu/rtl/ct_spram_wrapper.sv), [ct_mmu_l2tlb_tag_array.sv#L30-L50](mmu/rtl/ct_mmu_l2tlb_tag_array.sv#L30) | P1 | TC-SRAM-RAW-001, TC-SRAM-WEN-001 | `sram_collision_cg`, `sva_sram_raw` |
| **F3.17** | tag / data / RRPV array | **SRAM macro 无 reset**；valid 位由外部 FF 清零；reset 后首次访问防 X（K9/GAP-L2.3 / GAP-SR.1） | [ct_spram_wrapper.sv](mmu/rtl/ct_spram_wrapper.sv), [mmu_fpga_ram.sv#L35-L42](mmu/rtl/mmu_fpga_ram.sv#L35) | P0 | TC-SRAM-RST-001 | `sva_no_x_after_reset` |
| **F3.18** | `mmu_l2tlb_rrpv_array` + `mmu_l2tlb_rrpv_wbuf` | RRPV lookup RAW 顺序；CAM bypass 正确性；同 idx 连续两 cycle 写覆盖 vs FIFO 顺序（GAP-L2.7 / GAP-RRPV.2 / GAP-RRPV.3） | [mmu_l2tlb_rrpv_wbuf.sv#L40-L160](mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L40) | P0 | TC-RRPV-WBUF-001~003 | `rrpv_wbuf_cg`, `sva_rrpv_bypass` |
| **F3.19** | `mmu_l2tlb_rrpv_wbuf` | full=1 backpressure 正确传递到 ReqQ；pop_grant=1 与 buffer empty 时 sram_idx 稳定（GAP-RRPV.4 / GAP-L2X.9） | [mmu_l2tlb_rrpv_wbuf.sv#L35-L100](mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv#L35) | P1 | TC-RRPV-FULL-001 | `rrpv_wbuf_cg` |
| **F3.20** | `mmu_l2tlb_replacement_policy` | RRPV aging 范围（所有 valid way vs 仅非 mask way）；victim 角落（全 mask、全 invalid、tie at MAX）；饱和正确性（GAP-RRPV.1 / GAP-RRPV.5 / GAP-L2X.7） | [mmu_l2tlb_replacement_policy.sv#L75-L130](mmu/rtl/mmu_l2tlb_replacement_policy.sv#L75) | P1 | TC-RRPV-VICTIM-001~003 | `l2tlb_bank_cg` |
| **F3.21** | `pplru` | 16-entry LRU 树 (p00-p47) reset 初值（全 0 vs 交替）→ tie-break 行为；并发 read/write 一致性（GAP-RRPV.6 / GAP-RRPV.7） | [pplru.sv#L35-L150](mmu/rtl/pplru.sv#L35) | P1 | TC-PPLRU-RST-001 | `sva_pplru_consistency` |
| **F3.22** | `mmu_l2tlb_reqq_entry` | Vld/Sent/Dealloc FSM；初态 r_vld=0/r_sent=0；bypass_grant：T0 alloc + issue_grant & !entry_ready → 跳过 ready 队列（GAP-Req.1 / GAP-Req.2） | [mmu_l2tlb_reqq_entry.sv#L60-L130](mmu/rtl/mmu_l2tlb_reqq_entry.sv#L60) | P0 | TC-REQQ-FSM-001, TC-REQQ-BYPASS-001 | `l2tlb_reqq_cg` |
| **F3.23** | `mmu_l2tlb_reqq_entry` | retry：fb_miss_retry 清 r_sent；多次 retry 不死锁（GAP-Req.3） | [mmu_l2tlb_reqq_entry.sv#L100-L110](mmu/rtl/mmu_l2tlb_reqq_entry.sv#L100) | P1 | TC-REQQ-RETRY-001 | `sva_reqq_no_deadlock` |
| **F3.24** | `mmu_l2tlb_reqq` | Thermometer FFZ 单周期仅一个 DTLB entry 分配；ITLB 专用 entry 0 与 DTLB FFZ 不冲突（GAP-Req.5 / GAP-Req.6） | [mmu_l2tlb_reqq.sv#L40-L100](mmu/rtl/mmu_l2tlb_reqq.sv#L40) | P0 | TC-REQQ-FFZ-001, TC-REQQ-ITLB-DTLB-001 | `l2tlb_reqq_cg` |
| **F3.25** | `mmu_l2tlb_mb` + `ptw` | SFENCE 期间 in-flight refill abort（PTW 完成前 MB 清空）（GAP-MB.2） | [mmu_l2tlb_mb.sv](mmu/rtl/mmu_l2tlb_mb.sv), [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) | P0 | TC-MB-SFENCE-ABORT-001 | `sva_sfence_abort_inflight` |
| **F3.26** | `mmu_l2tlb_mb` | 同 VPN 不同 hash 槽位 → dedup 逻辑确保单 PTW walk；FFZ 多 free entry 时偏置（GAP-MB.3 / GAP-MB.5） | [mmu_l2tlb_mb.sv#L80-L140](mmu/rtl/mmu_l2tlb_mb.sv#L80) | P1 | TC-MB-DEDUP-001, TC-MB-FFZ-BIAS-001 | `mbuf_alloc_cg` |
| **F3.27** | `mmu_l2tlb_mb_entry` | dealloc 精确时序：alloc/dealloc race 不留孤儿 refill；Entry FSM 各状态精确周期（GAP-MB.1 / GAP-MB.4） | [mmu_l2tlb_mb_entry.sv#L60-L120](mmu/rtl/mmu_l2tlb_mb_entry.sv#L60) | P1 | TC-MB-DEALLOC-RACE-001 | `mbuf_alloc_cg` |
| **F3.28** | `mmu_l2tlb` + `mmu_l2tlb_mb` | **Atomic refill ordering**：tag/data/RRPV 同 cycle vs staggered；中间态防腐（GAP-L2X.1） | [mmu_l2tlb.sv#L200-L250](mmu/rtl/mmu_l2tlb.sv#L200), [mmu_l2tlb_mb.sv#L200-L250](mmu/rtl/mmu_l2tlb_mb.sv#L200) | P0 | TC-REFILL-ATOMIC-001 | `sva_refill_atomic` |
| **F3.29** | `mmu_l2tlb` + `ct_mmu_tlboper` | INV_VA 与 in-flight refill 竞争同一 VPN 的精确仲裁（GAP-L2X.2） | [mmu_l2tlb.sv](mmu/rtl/mmu_l2tlb.sv) | P0 | TC-INV-REFILL-RACE-001 | `sva_inv_refill_arb` |
| **F3.30** | `mmu_l2tlb_reqq` + `mmu_arb` | trans_id 转发延迟；hit info 返回延迟周期数（GAP-L2X.3 / GAP-L2X.4） | [mmu_l2tlb_reqq.sv#L180-L220](mmu/rtl/mmu_l2tlb_reqq.sv#L180) | P1 | TC-L2-LATENCY-001 | `cg_l2_latency` |
| **F3.31** | `mmu_arb` | Bank 冲突 mask 生成；backpressure mask 传递时延（GAP-Arb.2 / GAP-Arb.3） | [mmu_arb.sv#L220-L350](mmu/rtl/mmu_arb.sv#L220) | P1 | TC-ARB-MASK-001 | `mmu_arb_sva` |
| **F3.32** | `mmu_arb` | Work-conserving 形式化（无空闲 cycle）（GAP-Arb.7） | [mmu_arb.sv](mmu/rtl/mmu_arb.sv) | P1 | TC-ARB-WC-001 | `sva_work_conserving` |
| **F3.33** | `mmu_arb` | PTW + TLBOp + ReqQ 同 bank → 严格优先级胜者（GAP-L2X.8） | [mmu_arb.sv#L80-L110](mmu/rtl/mmu_arb.sv#L80) | P1 | TC-ARB-PRIO-001 | `mmu_arb_sva` |
| **F3.34** | `mmu_fpga_ram` vs ASIC | FPGA 模型与 ASIC SRAM 等价性；同 cycle write-then-read 行为（GAP-L2.5 / GAP-SR.2 / GAP-SRAM.5） | [mmu_fpga_ram.sv#L43-L52](mmu/rtl/mmu_fpga_ram.sv#L43), [ct_spsram_256x196.v#L44-L50](mmu/rtl/ct_spsram_256x196.v#L44) | P1 | TC-FPGA-ASIC-EQ-001 | `sva_sram_equiv` |
| **F3.35** | wrappers | tag/data/RRPV 阵列同周期不同 way 读写无串扰（GAP-SRAM.6） | [ct_mmu_l2tlb_tag_array.sv#L35-L50](mmu/rtl/ct_mmu_l2tlb_tag_array.sv#L35) | P1 | TC-SRAM-CROSS-001 | `sram_collision_cg` |
| **F3.36** | `ct_mmu_regs` + `mmu_l2tlb` | cpurst_b 单脉冲清所有 array vld 位（GAP-L2X.6） | [mmu_fpga_ram.sv#L33-L42](mmu/rtl/mmu_fpga_ram.sv#L33) | P1 | TC-RST-VLD-CLR-001 | `sva_rst_vld_clr` |
| **F3.37** | `mmu_arb` + `one_to_four_xbar` | Selector 编码（VPN bit 选 hash 变体）；Idle TWU 选择算法 fallback；在飞 dispatch 被 abort 取消（GAP-Arb.4 / GAP-Arb.5 / GAP-Arb.6 / GAP-Hash.4） | [one_to_four_xbar.sv#L35-L120](mmu/rtl/one_to_four_xbar.sv#L35), [mmu_arb.sv](mmu/rtl/mmu_arb.sv) | P1 | TC-XBAR-IDLE-001, TC-XBAR-ABORT-001 | `cg_xbar_select` |
| **F3.38** | `mmu_l2tlb` + `ct_mmu_top` | maee/no_op_req 对 L2 TLB 的 gating 范围（GAP-L2X.5） | [mmu_l2tlb.sv](mmu/rtl/mmu_l2tlb.sv), [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P2 | TC-LP-GATING-001 | cg_lp |
| **F3.39** | wrappers | BIST disable / scan_en 对写的影响；scan chain 集成（GAP-L2.4 / GAP-SR.4 / GAP-SR.5） | [ct_spram_wrapper.sv](mmu/rtl/ct_spram_wrapper.sv) | P2 | TC-DFT-SRAM-001 | cg_dft |
| **F3.40** | `mmu_arb` | Hash 真实 workload 冲突分布（熵）+ 可逆性分析（DPA）（GAP-Hash.2 / GAP-Hash.3） | [mmu_arb.sv#L350-L450](mmu/rtl/mmu_arb.sv#L350) | P2 | TC-HASH-DIST-001 | `l2tlb_skew_hash_cg` |
| F3.NEW.1 | `mmu_l2tlb` + `ct_mmu_tlboper` | **SFENCE 后 RRPV 不清零**：TLBWI/INV_VA 无效化某 entry 后，该 way 的 RRPV 值保持不变（不重置为 INIT=4），被无效 entry 的 RRPV 残留影响后续替换决策 — 需设计确认此为意图还是缺陷（GAP-RRPV.NEW.1） | [mmu_l2tlb.sv](mmu/rtl/mmu_l2tlb.sv), [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) | P1 | TC-BUG-007 | cg_rrpv_post_sfence, sva_rrpv_inv_clr |

---


---

### 5.3 Page Table Walker + MMU Arbiter (F4, F5)

> 模块范围：**PTW + MMU Arbiter (F4, F5)**

## 段 1：F4 PTW/TWU + F5 Arbiter 功能点列表

| F-ID | 模块 | 功能描述 | 核心机制 | 依据 | 优先级 | RTL 参考 |
|------|------|---------|---------|------|--------|---------|
| F4.1 | PTW | SATP 根地址加载与锁存 | 从 `regs_ptw_satp_ppn[27:0]` 读取当前 SATP 值，用于 L2 页表基址；支持双 SATP 与 `regs_ptw_clr` 复位 | [ptw.sv](mmu/rtl/ptw.sv)#L5-L10 | P0 | ptw.sv:input regs_ptw_satp_ppn |
| F4.2 | PTW/TWU | L2 级（顶级）PTE 读取与命中判定 | PDE_cache 检测 L2 级 hit（`L2PDE_xbar_hit_vld`），hit 时直接用缓存 PPN；miss 时通过 xbar 分发到 TWU，twu 发起 LSU 内存读（addr=SATP+vpn[26:18]*8） | [ptw.sv](mmu/rtl/ptw.sv)#L200-220, [one_to_four_xbar.sv](mmu/rtl/one_to_four_xbar.sv)#L50-80 | P0 | ptw.sv / L2PDE_cache.sv |
| F4.3 | PTW/TWU | L1 级中间 PDE 读取 | PDE_cache L1 (9-bit tag) 命中时复用；miss 时产生新的 LSU 读请求（addr=PDE_PPN[L2]+vpn[17:9]*8），可能触发 L2 再填充 | [ptw.sv](mmu/rtl/ptw.sv)#L220-240, [L1PDE_cache.sv](mmu/rtl/L1PDE_cache.sv) | P0 | L1PDE_cache.sv:input ptw_vpn |
| F4.4 | PTW/TWU | L0 级（最末）PTE 读取与权限提取 | TWU 读出最后一级 PTE（addr=PDE_PPN[L1]+vpn[8:0]*8），包含 V/R/W/X/U/G/A/D/RSW 等 14 bit flags；通过 flag 验证合法性 | [ptw.sv](mmu/rtl/ptw.sv)#L240-280, [twu.sv](mmu/rtl/twu.sv)#L50-120 | P0 | twu.sv:output twu_arb_ref_data_din |
| F4.5 | TWU/MBUF | 4 并发 TWU 与 MBUF 去重合并 | 4 个独立 TWU 状态机；相同 VPN 的多个请求（来自 IFU/L1D 不同端口）进入 MBUF（8 entry），MBUF 去重后仅向 LSU 发出一次读，多个 TWU 共用响应数据（`mbuf_twu_data_vld[3:0]` 向量） | [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv)#L30-80, [ptw.sv](mmu/rtl/ptw.sv)#L380-420 | P0 | ptw.sv:logic [3:0] twu_mbuf_req |
| F4.6 | MBUF | MBUF 信用与流控管理 | 8 entry MBUF，每条 TWU 请求占用一个 entry；满时阻塞新 TWU 请求（twu_mask 拉高）；响应到来后立即释放对应 entry；避免死锁与重复分配 | [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv)#L150-200 | P0 | ptw_mbuf.sv:logic [3:0] mbuf_grant |
| F4.7 | PTW/TWU | L2 PDE Cache 替换与失效 | L2 PDE Cache 单 entry（18-bit tag），LRU 式替换（每次更新时清除旧 entry）；`regs_ptw_clr` 清除所有缓存 | [L2PDE_cache.sv](mmu/rtl/L2PDE_cache.sv)#L30-80 | P1 | L2PDE_cache.sv / ptw.sv:input regs_ptw_clr |
| F4.8 | PTW/TWU | L1 PDE Cache 替换与失效 | L1 PDE Cache 单 entry（9-bit tag），支持 TTL 式老化；`regs_ptw_clr` 失效 | [L1PDE_cache.sv](mmu/rtl/L1PDE_cache.sv)#L20-70 | P1 | L1PDE_cache.sv / ptw.sv |
| F4.9 | TWU | PTE V=0（非法）检测与终止 | TWU 读出 L0 PTE 后检查 V bit；V=0 则触发 `twu_l2tlb_ref_pgflt` 上报页错，终止 walk | [twu.sv](mmu/rtl/twu.sv)#L100-150 | P0 | twu.sv:output twu_l2tlb_ref_pgflt |
| F4.10 | TWU | PTE R=W=0（非法）检测与拒绝 | 若 R∧W=0（不允许读写），根据访问类型触发 Access Fault（`twu_l2tlb_ref_acc_err`） | [twu.sv](mmu/rtl/twu.sv)#L120-160 | P0 | twu.sv:output twu_l2tlb_ref_acc_err |
| F4.11 | TWU | Reserved Bits 非零检测 | Sv39 PTE reserved bits（63:62, 60:55）非零时触发 Access Fault | [twu.sv](mmu/rtl/twu.sv)#L140-180 | P1 | twu.sv:// reserved bit check |
| F4.12 | TWU | Misaligned PPN 检测 | 巨页 PPN 低位应为零：2M 巨页 PPN[0]=0，1G 巨页 PPN[9:0]=0；违反时触发 Access Fault | [twu.sv](mmu/rtl/twu.sv)#L160-200 | P1 | twu.sv:// ppn alignment check |
| F4.13 | `twu` | **A=0 → page fault（`fst_chk_flg[5]`）；RTL 无 A-bit hw 写回路径**（K10/GAP-AD.1） | [twu.sv#L494](mmu/rtl/twu.sv#L494) | P0 | TC-AD-A-PGFLT-001 | sva_a_bit_pgflt |
| F4.14 | `twu` | **D=0 on store → page fault（`fst_chk_flg[6]`）；RTL 无 D-bit hw 写回路径**（K10/GAP-AD.2） | [twu.sv#L495](mmu/rtl/twu.sv#L495) | P0 | TC-AD-D-PGFLT-001 | sva_d_bit_pgflt |
| F4.15 | TWU | U bit 与 SUM 交互 | Supervisor 访问 User 页面时（U=1, priv=S）：SUM=1 则允许读；SUM=0 则拒绝；通过 `cp0_mmu_sum` 控制 | [twu.sv](mmu/rtl/twu.sv)#L250-300 | P0 | twu.sv:input cp0_mmu_sum |
| F4.16 | TWU | X/W/R 权限检查 | 根据访问类型（fetch/load/store）与 PTE 的 X/W/R bits、priv mode（U/S）进行权限仲裁；X bit + `cp0_mmu_mxr` 控制读权限 | [twu.sv](mmu/rtl/twu.sv)#L300-350 | P0 | twu.sv:input cp0_mmu_mxr |
| F4.17 | TWU | 全局页（G bit）支持 | G=1 时 ASID 匹配失效；TLB hit 检查不对比 ASID；PTE 中 G bit 通过 flag 传递到 L2 TLB tag 的 G 位 | [twu.sv](mmu/rtl/twu.sv)#L350-380 | P0 | twu.sv / ptw.sv:output ptw_l2tlb_ref_* |
| F4.18 | PTW/TWU | 巨页降级（1G→2M→4K）| 从 L2 miss 开始；若 L1 hit 则该级页为 2M（type=2），若 L1 miss 则继续读 L0 以 4K（type=0）；降级链条完整传递 | [ptw.sv](mmu/rtl/ptw.sv)#L300-350, [one_to_four_xbar.sv](mmu/rtl/one_to_four_xbar.sv)#L80-120 | P0 | ptw.sv:logic [2:0] twu_arb_ref_type |
| F4.19 | PTW/TWU | 跨级巨页支持 | 1G 页在 L1 hit，2M 页在 L0 检出；每级独立判定页大小，不强制链式约束 | [ptw.sv](mmu/rtl/ptw.sv)#L350-380 | P1 | ptw.sv:PDE_xbar_type |
| F4.20 | PTW | SATP 切换时的 Walk 行为 | 若 SATP 变化（dual-SATP 切换或软件写），**不自动失效 in-flight walk**；需要通过 SFENCE 配合软件协调 | [ptw.sv](mmu/rtl/ptw.sv)#L1-30 | P0 | ptw.sv:input regs_ptw_satp_ppn / input regs_ptw_clr |
| F4.21 | PTW | SFENCE 与 Walk 冲突处理 | `tlboper_ptw_abort` 拉高时，in-flight walk 应立即停止（abort_flop 置 1）；响应到来后立即清除 abort；避免被 abort 的 walk 结果写入 L2 TLB | [ptw.sv](mmu/rtl/ptw.sv)#L420-460, [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv)#L260-300 | P0 | ptw.sv:input tlboper_ptw_abort |
| F4.22 | MBUF | 总线错误（bus_error）提前终止 | PTW 数据通道若返回 `lsu_mmu_bus_error=1`，所有依赖此请求的 TWU 立即接收错误信号；MBUF 汇总错误类型后上报 `mbuf_bus_error` | [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv)#L300-350 | P0 | ptw_mbuf.sv:input lsu_mmu_bus_error |
| F4.23 | PTW | **`mmu_lsu_wakeup[11:0]` 为广播信号**：`mb_have_free=1` 时全 1，**非 per-entry one-hot**（K5/GAP-PX.10）；LSU 侧需自行判断 MB 哪些可醒 | [mmu_l1dtlb_install.sv#L233-L235](mmu/rtl/mmu_l1dtlb_install.sv#L233), [ptw.sv](mmu/rtl/ptw.sv)#L460-500 | P0 | TC-WAKEUP-BCAST-001 | sva_wakeup_broadcast |
| F4.24 | PTW | tlb_busy 流控与停顿 | PTW MBUF 满（8 entry all occupied）时，`mmu_lsu_tlb_busy=1`；对应 L1 DTLB 停顿后续请求；busy 解除后立即清除停顿 | [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv)#L400-450 | P0 | ptw.sv:output mmu_lsu_tlb_busy |
| F4.25 | TWU | PMP 拒绝时的 Walk 终止 | 若 `pmp_mmu_flg` 返回权限拒绝，TWU 立即终止 walk 并上报 Access Fault；无数据被写入 L2 TLB | [twu.sv](mmu/rtl/twu.sv)#L380-420 | P0 | twu.sv:input pmp_mmu_flg |
| F4.26 | TWU | SysMap 命中绕过 Walk | 若 `sysmap_mmu_hit` 返回 1，PPN 直接由 `sysmap_mmu_pa` 替代，不再继续三级 walk；优先级高于 L2 TLB | [twu.sv](mmu/rtl/twu.sv)#L420-450 | P0 | twu.sv:input sysmap_mmu_hit |
| F4.27 | PTW | 多 SATP 切换压力 | 频繁的双 SATP 切换（`regs_ptw_clr` 序列）不应导致 walk 死锁；cache 失效后新 walk 正常启动 | [ptw.sv](mmu/rtl/ptw.sv)#L1-50 | P1 | ptw.sv:input regs_ptw_clr |
| F5.1 | mmu_arb | PTW 最高优先级 | PTW refill 请求（`ptw_arb_req`）优先级最高，抢占 ReqQ/TLBOPER/Prefetch；当 PTW valid 时其它源被屏蔽 | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L80-150 | P0 | mmu_arb.sv:// Priority: PTW > ReqQ > TLBOPER > Prefetch |
| F5.2 | mmu_arb | 仲裁优先级链 | 4 源优先级：PTW > L2ReqQ > TLBOper > Prefetch；同时有效时严格按优先级发放 grant；仅一条请求获 grant | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L150-220 | P0 | mmu_arb.sv:logic arb_ptw_grant |
| F5.3 | mmu_arb | 无同时双授权 | mmu_arb 输出 grant 时保证 `arb_ptw_grant` / `arb_reqq_grant` / `arb_tlboper_grant` / `arb_pfu_grant` **最多一个**为 1；不允许同周期两个请求获 grant | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L220-280 | P0 | mmu_arb.sv:always @(posedge forever_cpuclk) |
| F5.4 | mmu_arb | Work-Conserving 保证 | 只要 L2 SRAM 未被其它源占用且有效请求在，mmu_arb 必投出 grant；不主动浪费周期 | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L280-350 | P0 | mmu_arb.sv:// work-conserving logic |
| F5.5 | mmu_arb | Skew 索引 8 路独立生成 | 从选定的 VPN 生成 8 个 skewed bank indices（`arb_l2tlb_idx_w0..w7`）；每路索引通过不同哈希函数独立计算，支持多 bank 并发查询 | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L350-450 | P0 | mmu_arb.sv:output [IDX_WIDTH-1:0] arb_l2tlb_idx_w[7:0] |
| F5.6 | mmu_arb | Bank 冲突检测与避让 | Skew 架构中同一 VPN 映射到多个 bank；mmu_arb 预先检测冲突（多路映射到同一 bank），选择能满足的bank配置 | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L450-520 | P1 | mmu_arb.sv:// bank conflict detection |
| F5.7 | mmu_arb | 请求反压与掩码 | 若 L2 SRAM busy 或 L1 DT MB 满，mmu_arb 拉起 `arb_ptw_mask=1` 阻止 PTW 新请求入场 | [mmu_arb.sv](mmu/rtl/mmu_arb.sv)#L520-580 | P0 | mmu_arb.sv:output logic arb_ptw_mask |
| F5.8 | one_to_four_xbar | 1→4 分发器与 TWU 选择 | PDE cache 有请求时，one_to_four_xbar 扫描 4 个 TWU 的 idle bit，选择第一个空闲 TWU，将请求分发给它；idle TWU 被按优先级轮转 | [one_to_four_xbar.sv](mmu/rtl/one_to_four_xbar.sv)#L60-150 | P0 | one_to_four_xbar.sv:output [3:0] xbar_twu_req |
| F5.9 | pplru | PLRU 替换策略 | L1 PDE Cache 与 MBUF 使用 16-way 伪 LRU（pplru）管理替换；每次访问更新 LRU 树，下次替换选最旧 entry（16-bit onehot） | [pplru.sv](mmu/rtl/pplru.sv)#L30-100 | P0 | pplru.sv / ptw_mbuf.sv:// PLRU update |
| F4.28 | `twu` | **CSR FSM** (IDLE→1G_CRS1→1G_CRS2→2M_CRS1→2M_CRS2→CSR_DATA_VLD) 跨界检测；sysmap mismatch 触发 1G→2M / 2M→4K 降级（GAP-T1.1 / GAP-T1.2） | [twu.sv#L1041-L1100](mmu/rtl/twu.sv#L1041), [twu.sv#L1168](mmu/rtl/twu.sv#L1168) | P1 | TC-TWU-CSR-FSM-001 | cg_twu_csr_fsm |
| F4.29 | `twu` | csr_refill_pgs 转换（3'b100→3'b010）→ L0 refill 触发（GAP-T1.3） | [twu.sv#L1095-L1115](mmu/rtl/twu.sv#L1095) | P1 | TC-TWU-CSR-REFILL-001 | cg_twu_csr_fsm |
| F4.30 | `twu` + `mbuf_entry` | `twu_data_ready[2:0]` 与 mbuf level 匹配的 write_back 时序（GAP-T1.4 / GAP-PM.7） | [twu.sv#L826-L830](mmu/rtl/twu.sv#L826), [mbuf_entry.sv#L156-L158](mmu/rtl/mbuf_entry.sv#L156) | P1 | TC-TWU-DATA-RDY-001 | sva_twu_data_ready |
| F4.31 | `ptw_mbuf` | **FFZ 优先编码**（thermometer high/low table）+ entry 8 wrap（GAP-PM.1） | [ptw_mbuf.sv#L290-L340](mmu/rtl/ptw_mbuf.sv#L290) | P0 | TC-PMBUF-FFZ-001 | mbuf_alloc_cg |
| F4.32 | `ptw_mbuf` | round-robin 指针（mbuf_ptr_nxt, twu_req_point_r）背压时不丢失（GAP-PM.2） | [ptw_mbuf.sv#L350-L375](mmu/rtl/ptw_mbuf.sv#L350) | P1 | TC-PMBUF-RR-001 | sva_rr_no_loss |
| F4.33 | `ptw_mbuf` | **entry 8 ITLB 专用槽位**（itlb_sel 优先级覆盖 FFZ）（GAP-PM.3） | [ptw_mbuf.sv#L267-L270](mmu/rtl/ptw_mbuf.sv#L267) | P0 | TC-PMBUF-ITLB-SLOT-001 | mbuf_alloc_cg |
| F4.34 | `ptw_mbuf` | 多 TWU 同 cycle 有效 → mbuf_grant[3:0] onehot 正确性（GAP-PM.4） | [ptw_mbuf.sv#L253-L265](mmu/rtl/ptw_mbuf.sv#L253) | P0 | TC-PMBUF-MULTI-TWU-001 | sva_mbuf_grant_onehot |
| F4.35 | `mbuf_entry` | FSM (vld/on/get/bus_err_flop) 状态组合不冲突（GAP-PM.5） | [mbuf_entry.sv#L78-L140](mmu/rtl/mbuf_entry.sv#L78) | P1 | TC-MBUF-FSM-001 | cg_mbuf_fsm |
| F4.36 | `ptw_mbuf` | Dedup VPN 比较：同 VPN+level 仅一胜出（GAP-PM.6） | [ptw_mbuf.sv#L150-L180](mmu/rtl/ptw_mbuf.sv#L150) | P1 | TC-PMBUF-DEDUP-001 | sva_dedup_unique |
| F4.37 | `ptw_mbuf` | write_back_grant 优先级 mux（entry 8 vs 0-7）公平性（GAP-PM.8） | [ptw_mbuf.sv#L536-L548](mmu/rtl/ptw_mbuf.sv#L536) | P2 | TC-PMBUF-WB-FAIR-001 | cg_mbuf_wb |
| F4.38 | `L1PDE_cache` / `L2PDE_cache` | **TAG 含 ASID 字段但 update 未填充** → SATP 切 ASID 后 stale（K8/GAP-PDE.1 / GAP-PX.16） | [L1PDE_cache.sv#L73-L85](mmu/rtl/L1PDE_cache.sv#L73), [PDE_cache.sv#L92](mmu/rtl/PDE_cache.sv#L92), [ptw_mbuf.sv#L309-L320](mmu/rtl/ptw_mbuf.sv#L309) | P0 | TC-PDE-ASID-STALE-001 | sva_pde_asid_match |
| F4.39 | `PDE_cache` | L1/L2 同时 hit 优先级 mux；L1/L2 hit 互斥；非互斥时 refill_vld 避碰（GAP-PDE.2 / GAP-PDE.4） | [PDE_cache.sv#L244-L259](mmu/rtl/PDE_cache.sv#L244) | P1 | TC-PDE-MUX-001 | sva_pde_mux |
| F4.40 | `L1PDE_cache` / `L2PDE_cache` | regs_ptw_clr 立即清 valid；多周期查询无瞬态 stale（GAP-PDE.3） | [L1PDE_cache.sv#L60-L70](mmu/rtl/L1PDE_cache.sv#L60), [L2PDE_cache.sv#L59-L68](mmu/rtl/L2PDE_cache.sv#L59) | P1 | TC-PDE-CLR-001 | sva_pde_clr |
| F4.41 | `pplru` | plru_ref_num[15:0] onehot 一致性（GAP-PDE.5） | [pplru.sv](mmu/rtl/pplru.sv) | P1 | TC-PPLRU-ONEHOT-001 | sva_pplru_onehot |
| F4.42 | `ptw_mbuf` | mmu_lsu_data_req_addr / req_grant[8:0] / 响应同步到正确 entry on 状态（GAP-LD.1 / GAP-LD.2 / GAP-LD.3） | [ptw_mbuf.sv#L477-L530](mmu/rtl/ptw_mbuf.sv#L477) | P1 | TC-PMBUF-LSU-CHN-001 | sva_lsu_data_chn |
| F4.42a | `ptw_mbuf` | **【v3.0 新增】串行单 outstanding 握手协议**：`mmu_lsu_data_req` 拉高后，必须与 `mmu_lsu_data_req_addr` / `mmu_lsu_data_size` **保持稳定**直到 `lsu_mmu_data_vld`（或 `lsu_mmu_data_bus_error`）返回；任何时刻 **outstanding 请求 ≤ 1**；该请求完成前不得发下一个。RTL 依据：`mbuf_ptr_nxt` 仅在 `lsu_mmu_data_vld_reg & mmu_lsu_data_req` 或 MBUF 变空时更新（L363-L379），地址由 `mbuf_ptr_nxt` one-hot 选中（L401-L410） | [ptw_mbuf.sv#L288,L363-L410](mmu/rtl/ptw_mbuf.sv#L288) | P0 | TC-PMBUF-SERIAL-OUTSTANDING-001, TC-PMBUF-ADDR-STABLE-001 | cg_lsu_req_outstanding, sva_lsu_req_stable_until_vld, sva_lsu_addr_stable_until_vld, sva_single_outstanding |
| F4.42b | `ptw_mbuf` | **【v3.0 新增】无 tag / ID 机制、严格以 outstanding entry 为隐含 ID 按順序返回**：`lsu_mmu_data_vld` 回来时必须和当前 `mbuf_ptr` 所指 entry 一一对应；禁止 LSU 乱序返回或同周期多 entry 都以为自己被命中；验证侧 monitor 需在 `mmu_lsu_data_req=0` 时检查不出现 `lsu_mmu_data_vld=1` | [ptw_mbuf.sv#L532-L550](mmu/rtl/ptw_mbuf.sv#L532) | P0 | TC-PMBUF-NO-TAG-001, TC-PMBUF-INORDER-RESP-001 | sva_response_inorder, sva_vld_only_when_req |
| F4.42c | `ptw_mbuf` | **【v3.0 新增】MBUF 指针更新约束**：`mbuf_ptr` 仅在 `lsu_mmu_data_vld` 收到后或 MBUF 变空时前进；其他周期保持；以此保证地址/请求在 outstanding 期间不变 | [ptw_mbuf.sv#L363-L379](mmu/rtl/ptw_mbuf.sv#L363) | P1 | TC-PMBUF-PTR-HOLD-001 | cg_mbuf_ptr_hold, sva_mbuf_ptr_only_on_response |
| F4.43 | `ptw_mbuf` | **单 cycle 多响应防护**：FSM 不被 stale resp 触发多 entry（GAP-LD.4） | [ptw_mbuf.sv#L532-L550](mmu/rtl/ptw_mbuf.sv#L532) | P0 | TC-PMBUF-MULTI-RESP-001 | sva_no_stale_resp |
| F4.44 | `ptw_mbuf` | mmu_lsu_data_req=1 长期未 grant 的死锁防护（GAP-LD.5） | [ptw_mbuf.sv#L461](mmu/rtl/ptw_mbuf.sv#L461) | P1 | TC-PMBUF-NO-DEADLOCK-001 | sva_lsu_progress |
| F4.45 | `twu` | L0/L1/L2 PTE addr 边界：SysMap 跨界 adder 中间态下游 PMP/SysMap 无 stale lookup（GAP-AG.1~4） | [twu.sv#L427,L587,L745,L1118-L1150](mmu/rtl/twu.sv#L427) | P2 | TC-TWU-ADDR-BOUND-001 | cg_addr_gen |
| F4.46 | `ptw_mbuf` | hw A/D 更新流程在 RTL 中缺失 → 确认 trap-only（GAP-AD.3）；csr_idle vs refill_req 并发不腐（GAP-AD.4） | [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv), [twu.sv#L1123-L1130](mmu/rtl/twu.sv#L1123) | P1 | TC-AD-TRAP-ONLY-001 | sva_no_hw_ad |
| F4.47 | `ptw` + `ptw_mbuf` | abort_flop 双状态 set/clear 时序 + bus_error/data_vld glitch（GAP-PX.1）；regs_ptw_clr 是否清 abort_flop（GAP-PX.2） | [ptw.sv#L244-L252](mmu/rtl/ptw.sv#L244) | P1 | TC-PTW-ABORT-001 | sva_abort_flop |
| F4.48 | `ptw_mbuf` | tlboper_ptw_abort 广播到 9 entry 原子清空（GAP-PX.3） | [ptw_mbuf.sv#L247](mmu/rtl/ptw_mbuf.sv#L247) | P0 | TC-PTW-ABORT-BCAST-001 | sva_abort_clear_all |
| F4.49 | `ptw_mbuf` | bus_error 仲裁及公平性（GAP-PX.4） | [ptw_mbuf.sv#L550-L565](mmu/rtl/ptw_mbuf.sv#L550) | P1 | TC-PMBUF-BUSERR-FAIR-001 | cg_bus_err |
| F4.50 | `ptw` + `twu` | SATP 写但未 ptw_clr → walk 立即用新 SATP_PPN；SATP+priv_mode 同时变化一致性（GAP-PX.5 / GAP-PX.6） | [ptw.sv#L1-L30](mmu/rtl/ptw.sv#L1), [twu.sv#L50-L120](mmu/rtl/twu.sv#L50) | P1 | TC-SATP-WALK-CONSIST-001 | satp_hazard_cg |
| F4.51 | `one_to_four_xbar` | TWU 公平性/饥饿（pointer 不旋转 livelock）；全 4 TWU busy 后 twu_ready=0 能释放（GAP-PX.7 / GAP-PX.8） | [one_to_four_xbar.sv#L77-L105](mmu/rtl/one_to_four_xbar.sv#L77) | P0 | TC-XBAR-FAIR-001, TC-XBAR-DRAIN-001 | sva_xbar_no_starve |
| F4.52 | `ptw` + xbar | twu_mask 传递时延（GAP-PX.9） | [ptw.sv#L242-L244](mmu/rtl/ptw.sv#L242) | P2 | TC-XBAR-MASK-LAT-001 | cg_xbar_mask |
| F4.53 | `ptw` | mmu_lsu_tlb_busy 与 L1 DTLB credit=0 一致性（GAP-PX.11）；walk watchdog 缺失 → 死锁风险（GAP-PX.14） | [ptw.sv](mmu/rtl/ptw.sv) | P1 | TC-PTW-BUSY-CONSIST-001, TC-PTW-WATCHDOG-001 | sva_busy_credit_match |
| F4.54 | `twu` | PMP deny mid-walk：终止 vs 完成 L0 read；pgflt 含 level 信息（GAP-PX.12）；SysMap hit 在 L2 阶段时下游 L1/L0 不再发起（GAP-PX.13） | [twu.sv#L380-L420,L1168](mmu/rtl/twu.sv#L380) | P1 | TC-PMP-MIDWALK-001, TC-SYSMAP-MIDWALK-001 | cg_walk_terminate |
| F4.55 | `twu` / `ptw_mbuf` | RSW（PTE[63:59]）软件保留位的处理（GAP-PX.15）；TWU0/1/2 同 cycle 不同 level walk → MBUF 优先编码确保单 LSU req（GAP-PX.17）；CSR refill vs 普通 refill 优先级（GAP-PX.18） | [twu.sv#L140-L180,L1209-L1250](mmu/rtl/twu.sv#L140), [ptw_mbuf.sv#L253-L265](mmu/rtl/ptw_mbuf.sv#L253) | P1 | TC-PTE-RSW-001, TC-MBUF-MULTI-LEVEL-001, TC-CSR-REFILL-PRIO-001 | cg_pte_rsw |
| F4.NEW.1 | `ptw_mbuf` / `PDE_cache` | **PDE Cache 仅非叶 PTE 更新**：`mbuf_cache_upd` 条件 = V=1 & R=0 & X=0（非叶节点）；叶 PTE 不触叶 PDE Cache 更新；**v3.0 澄清**：thd_chk 仅针对 L0 叶 PTE，因此 `thd_chk_refill_req` 只要不触异常即可发出，**与 `mbuf_cache_upd` 非叶限制不矛盾**；叶 PTE 命中时验证 Cache 无污染（GAP-PDE.NEW.1）| [ptw_mbuf.sv](mmu/rtl/ptw_mbuf.sv), [PDE_cache.sv](mmu/rtl/PDE_cache.sv) | P1 | TC-PDECACHE-LEAF-001（TC-BUG-003 已降级为 Functional） | cg_pde_leaf_nonleaf, sva_pde_nonleaf_upd |
| F4.NEW.2 | `twu` | **TWU 6 级流水线架构**：实际为 FST_PMP→FST_CHK→SCD_PMP→SCD_CHK→THD_PMP→THD_CHK 六级有效寄存器；每级权限检查需验证各级独立的 fetch_type 传播（疑似 scd/thd_chk 复用 fst_chk_fetch_type，GAP-T.NEW.1） | [twu.sv](mmu/rtl/twu.sv) | P1 | TC-TWU-STAGE-FETCH-001 | cg_twu_stage_fetch |
| F4.NEW.3 | `twu` | **thd_chk 路径（叶 PTE）4K 页 A bit 检测正向覆盖**（v3.0 证伪改判）：第三级流水线 **必为叶 PTE**，`thd_chk_page_flt` 中 A bit 检测（`!flg[5]`）对应 4K 页正常执行，非缺陷；保留功能点用于 4K/2M/1G×A=0/1 正向覆盖 | [twu.sv](mmu/rtl/twu.sv) | P1 | TC-BUG-002（降为 Functional） | cg_twu_stage_fetch, sva_thd_a_bit_pgflt |
| F4.NEW.4 | `twu` | **【v3.0 新发现 P0 高危】2MB CSR 跨界 `csr_data_flop` 不更新**（GAP-TWU.NEW.1）：`twu.sv` L1130 处 `else if(twu_crs2_1g && twu_csr_cross)` 与上一行条件**完全重复**，推测应为 `twu_crs2_2m`；导致 **2MB 巨页 CSR 跨界场景下 `csr_data_flop` 不会被 shifted 更新**，后续 CSR refill 使用旧数据 | [twu.sv#L1128-L1133](mmu/rtl/twu.sv#L1128) | P0 | TC-BUG-011 | cg_twu_2m_csr_cross, sva_twu_2m_cross_data |
| F4.NEW.5 | `twu` | **CSR FSM `csr_grant[1:0]` 互斥性**（v3.0 新发现 / GAP-TWU.NEW.2）：TWU_IDLE 状态对 `csr_grant` 按 bit[1] / bit[0] 顺序判断，若仲裁侧异常输出 `2'b11` 则隐式偏向 1G 分支；需显式断言仲裁 onehot 约束 | [twu.sv#L1052-L1063](mmu/rtl/twu.sv#L1052) | P1 | TC-BUG-012 | sva_csr_grant_onehot |
| F5.10 | `mmu_arb` | **Skew hash 实现**（与 F3.15 交叉）：VPN[26:0] 各 bit XOR 成 idx_w0..w7（GAP-Arb.1 / GAP-Hash.1） | [mmu_arb.sv#L150-L450](mmu/rtl/mmu_arb.sv#L150) | P0 | TC-HASH-001~003 | l2tlb_skew_hash_cg |
| F5.11 | `mmu_arb` | Bank 冲突检测算法：PTW/ReqQ/TLBOp 多源映射重叠 bank 时 mask 生成（GAP-Arb.2） | [mmu_arb.sv#L220-L280](mmu/rtl/mmu_arb.sv#L220) | P1 | TC-ARB-BANK-MASK-001 | mmu_arb_sva |
| F5.12 | `mmu_arb` | Backpressure mask 传递：L2 stall → arb_*_mask 时延（GAP-Arb.3） | [mmu_arb.sv#L280-L350](mmu/rtl/mmu_arb.sv#L280) | P1 | TC-ARB-BP-LAT-001 | mmu_arb_sva |
| F5.13 | `one_to_four_xbar` | Idle TWU 选择算法：高低表 fallback、轮转指针保持（GAP-Arb.4） | [one_to_four_xbar.sv#L60-L120](mmu/rtl/one_to_four_xbar.sv#L60) | P1 | TC-XBAR-FALLBACK-001 | cg_xbar_select |
| F5.14 | `one_to_four_xbar` | 在飞 dispatch 被 tlboper_ptw_abort 取消（GAP-Arb.5）；L1PDE 与 L2PDE 同时 hit 的优先级（GAP-Arb.6） | [one_to_four_xbar.sv#L35-L65](mmu/rtl/one_to_four_xbar.sv#L35) | P1 | TC-XBAR-DISPATCH-ABORT-001 | sva_dispatch_cancel |
| F5.15 | `mmu_arb` | Work-conserving 形式化证明（与 F3.32 交叉）（GAP-Arb.7） | [mmu_arb.sv](mmu/rtl/mmu_arb.sv) | P1 | TC-ARB-WC-001 | sva_work_conserving |
| F5.NEW.1 | `mmu_arb` | **mask_bank_sel 编码验证**（v3.0 证伪改判）：v2.0 曾怀疑 `8'b00110011` 字面量缺 `8'b` 前缀；v3.0 RTL 二次核对（`mmu_arb.sv#L142`）确认已正确使用 `8'b` 前缀 → **非缺陷**，保留功能点作为 selector × bank mask 字面量的正向覆盖（非 BUG_HUNT） | [mmu_arb.sv#L140-L150](mmu/rtl/mmu_arb.sv#L140) | P1 | TC-BUG-004（降为 Functional） | cg_bank_mask_sel |
| F5.NEW.2 | `mmu_arb` | **PTW 双级写回流水线 `ptw_write_req1/ptw_write_req2` reset 竞争**（v3.0 新发现 / GAP-Arb.NEW.2）：`arb_ptw_grant` → `req1` → `req2` 两拍传播期间若 `cpurst_b` 断言或 `ptw_xx_cmplt` 中途到达，可能导致 SRAM stale write 或写数据 mismatch | [mmu_arb.sv#L180-L235](mmu/rtl/mmu_arb.sv#L180) | P1 | TC-BUG-013 | sva_ptw_write_pipe_reset_safe |
| F5.NEW.3 | `one_to_four_xbar` | **TWU 轮转指针 reset 初值偏向 TWU0**（v3.0 新发现 / GAP-Xbar.NEW.1）：`twu_req_point_r[3:0]` 复位初值 `4'b0001`（L105）使得冷启动后的第一次 PDE 请求总是偏向 TWU0，影响 4 TWU 冷启动公平性 | [one_to_four_xbar.sv#L100-L115](mmu/rtl/one_to_four_xbar.sv#L100) | P1 | TC-BUG-014 | cg_xbar_cold_start |


---

### 5.4 System-side — SysMap / PMP / TLBOPER / CSR (F6–F9)

> 模块范围：**SysMap + PMP + TLBOPER + CSR (F6-F9)**

## 段 1：§5 Feature List（F6+F7+F8+F9 系统侧功能点，46 条）

| ID | 模块 | 描述 | 依据 | 优先级 | RTL 参考 | 对应 TC |
|-----|------|------|------|--------|---------|--------|
| **F6.1** | SysMap | 8 region 基址与掩码配置正确性 | [ct_mmu_sysmap.v](mmu/rtl/ct_mmu_sysmap.v) 第 15–50 行；[sysmap.h](mmu/rtl/sysmap.h) REGION 定义 | P0 | `sysmap.h` | TC-SYSMAP-001, 002 |
| **F6.2** | SysMap | Region 匹配：PA 落在 [BASE_ADDR, BASE_ADDR+MASK) 范围触发 hit | [ct_mmu_sysmap_hit.v](mmu/rtl/ct_mmu_sysmap_hit.v) 比较逻辑 | P0 | `ct_mmu_sysmap_hit.v` | TC-SYSMAP-003, 004 |
| **F6.3** | SysMap | Hit 向量 `sysmap_mmu_hit{0..7}[7:0]` 唯一性保证（同一 PA 最多 1 region 命中） | [ct_mmu_sysmap.v](mmu/rtl/ct_mmu_sysmap.v) hit 编码 | P0 | `ct_mmu_sysmap.v` | TC-SYSMAP-005 |
| **F6.4** | SysMap | Region 重叠时优先级处理（通常按 region index 从小到大） | [ct_mmu_sysmap_hit.v](mmu/rtl/ct_mmu_sysmap_hit.v) 仲裁逻辑 | P1 | `ct_mmu_sysmap_hit.v` | TC-SYSMAP-006 |
| **F6.5** | SysMap | Flag 5-bit 语义：bit[0]=Cacheable、bit[1]=Bufferable、bit[2]=Executable、bit[3]=Readable、bit[4]=Writable | [sysmap.h](mmu/rtl/sysmap.h) FLG 定义 | P0 | `sysmap.h` | TC-SYSMAP-007, 008 |
| **F6.6** | SysMap | SysMap hit 时返回对应 flag，优先级高于 TLB/PTW 权限 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 第 180–210 行访问权限仲裁 | P0 | `ct_mmu_top.v` | TC-SYSMAP-009, 010 |
| **F6.7** | SysMap | PTW walk 产生的 PTE 物理地址（PPA）命中 SysMap 时，SysMap flag 替代 PTE 属性 | 架构规定：PTE walk 地址保护 | P1 | [ptw.sv](mmu/rtl/ptw.sv) + `ct_mmu_sysmap.v` | TC-SYSMAP-011 |
| **F6.8** | SysMap | Region disable 态（未配置或 enable=0）时不产生 hit | [ct_mmu_sysmap.v](mmu/rtl/ct_mmu_sysmap.v) 控制逻辑 | P1 | `ct_mmu_sysmap.v` | TC-SYSMAP-012 |
| **F6.9** | SysMap | 边界对齐：所有 region 基址应 4KB 对齐（若支持），掩码应为 2^n-1 形式 | [sysmap.h](mmu/rtl/sysmap.h) 宏定义 | P1 | `sysmap.h` | TC-SYSMAP-013 |
| **F7.1** | PMP 接口 | 8 端口并发独立：`mmu_pmp_pa{0..7}[27:0]` 同周期输出，每端口对应一个 PTW walk 通道或访存通道 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 第 169–176 行；[ptw.sv](mmu/rtl/ptw.sv) | P0 | `ct_mmu_top.v` | TC-PMP-001, 002, 003 |
| **F7.2** | PMP 接口 | PMP flag 4-bit 反馈：`pmp_mmu_flg{0..7}[3:0]` 编码（通常：bit[0]=R、bit[1]=W、bit[2]=X、bit[3]=Reserved） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 第 151–160 行 PMP 输入接口 | P0 | `ct_mmu_top.v` | TC-PMP-004, 005 |
| **F7.3** | PMP 接口 | **Fetch 使能仅 4 端口**：`mmu_pmp_fetch{3,5,6,7}` 输出（非 8 端口对称，K7/GAP-PMP.1） | [ct_mmu_top.v#L160-L163](mmu/rtl/ct_mmu_top.v#L160) | P0 | TC-PMP-006, TC-PMP-FETCH-NONSYM-001 | sva_pmp_fetch_4ports |
| **F7.4** | PMP 接口 | PA 输出正确性：`mmu_pmp_pa{i}` 对应 PTW walk 过程中产生的 PTE 物理地址，与 `mmu_lsu_data_req_addr` 一致 | [ptw.sv](mmu/rtl/ptw.sv) + [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P0 | `ptw.sv`, `ct_mmu_top.v` | TC-PMP-007, 008 |
| **F7.5** | PMP 接口 | PMP 拒绝时的异常回传：`pmp_mmu_flg[i]` 权限不足 → 触发 access fault 异常，通过 LSU 数据通道 `lsu_mmu_bus_error` 等信号上报 | [ptw.sv](mmu/rtl/ptw.sv) access check 逻辑 | P0 | `ptw.sv` | TC-PMP-009, 010 |
| **F7.6** | PMP 接口 | PA 对齐性：确保输出的 `mmu_pmp_pa{i}` 与 PTE 预期格式一致（bits [27:0] 有效，高位补零） | [pt.sv](mmu/rtl/ptw.sv) | P1 | `ptw.sv` | TC-PMP-011 |
| **F7.7** | PMP 接口 | 跨 port 独立性：一个 port 的 PMP deny 不影响其它 port；8 port 可独立配置权限 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) + PMP agent | P1 | `ct_mmu_top.v` | TC-PMP-012, 013 |
| **F7.8** | PMP 接口 | L1/L2 PDE 缓存中的 PTE 取出后，仍需经 PMP 检查（SysMap 后优先级） | [ptw.sv](mmu/rtl/ptw.sv) L1PDE/L2PDE cache 读取后的 PMP 路由 | P1 | `ptw.sv` | TC-PMP-014 |
| **F8.1** | TLB Oper | SFENCE.VMA - INV_ALL 模式：无条件全 TLB 失效，`lsu_mmu_tlb_all_inv=1` 触发 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) 第 40–60 行 | P0 | `ct_mmu_tlboper.v` | TC-SFENCE-001, 002 |
| **F8.2** | TLB Oper | **SFENCE.VMA INVVA single-pass FSM**：RTL 已简化为 **5-state single-pass**（原 14-state 多 pass 路径已被注释），仅做一次 L2TLB 查找；仅 `cur_pgs` 匹配的 entry 被无效；混合页面（4K+2M+1G）需验证 huge entry 是否正确失效（K4/GAP-TLBO.1；参见 F8.NEW.1 专项覆盖） | [ct_mmu_tlboper.v#L685-L730](mmu/rtl/ct_mmu_tlboper.v#L685) | P0 | TC-SFENCE-003, 004, TC-SFENCE-MIX-PG-001 | cg_tlb_inv, sva_inv_done |
| **F8.3** | TLB Oper | SFENCE.VMA - INV_ASID 模式：指定 ASID，失效该 ASID 下所有 entry（除非 G=1 global） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) INV_ASID 逻辑 | P0 | `ct_mmu_tlboper.v` | TC-SFENCE-005, 006 |
| **F8.4** | TLB Oper | SFENCE.VMA - INV_VA_ASID 模式：同时指定 VPN 和 ASID，精确失效一条 entry | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) INV_VA_ASID 逻辑 | P0 | `ct_mmu_tlboper.v` | TC-SFENCE-007, 008 |
| **F8.5** | TLB Oper | Global 页特殊规则：G=1 的页不受 INV_ASID / INV_VA_ASID 影响，仅 INV_ALL / INV_VA 能清除 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) global bit 检查 | P0 | `ct_mmu_tlboper.v` | TC-SFENCE-009, 010 |
| **F8.6** | TLB Oper | LSU 路径触发：`lsu_mmu_tlb_*_inv` 系列信号发起，握手信号 `mmu_lsu_tlb_inv_done` 单周期脉冲 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) LSU 接口，[ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 第 132–140 行 | P0 | `ct_mmu_tlboper.v`, `ct_mmu_top.v` | TC-SFENCE-011, 012 |
| **F8.7** | TLB Oper | CP0 路径触发：`cp0_mmu_tlb_all_inv` 经 regs 路由到 tlboper（仅支持 INV_ALL） | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) + `ct_mmu_tlboper.v` | P1 | `ct_mmu_regs.v`, `ct_mmu_tlboper.v` | TC-CSR-017, 018 |
| **F8.8** | TLB Oper | 握手与完成：失效完成后 `mmu_lsu_tlb_inv_done` / `mmu_cp0_tlb_done` 断言 1 周期脉冲 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) 完成信号 | P0 | `ct_mmu_tlboper.v` | TC-SFENCE-013, TC-CSR-019 |
| **F8.9** | TLB Oper | 并发访问中失效：SFENCE 过程中 IFU/LSU 发起的访问应等待失效完成或被 cancel | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) + arbitration logic | P1 | `ct_mmu_tlboper.v` | TC-SFENCE-014, 015 |
| **F8.10** | TLB Oper | 失效与 in-flight PTW 冲突：正在进行中的 walk 被 SFENCE 打断，应正确处理（通常 cancel 该 walk） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) + [ptw.sv](mmu/rtl/ptw.sv) 互联 | P1 | `ct_mmu_tlboper.v`, `ptw.sv` | TC-SFENCE-016 |
| **F8.11** | TLB Oper | 失效与 refill 竞争：同时发起失效和 refill（从 PTW 反填），两者应互斥或有明确序列化 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) + [mmu_l2tlb.sv](mmu/rtl/mmu_l2tlb.sv) | P1 | `ct_mmu_tlboper.v`, `mmu_l2tlb.sv` | TC-SFENCE-017 |
| **F8.12** | TLB Oper | TLBP 操作：在 L2 TLB 中查询 (VPN, ASID) 是否存在，返回 hit 位和 index | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) TLBP 逻辑 | P0 | `ct_mmu_tlboper.v` | TC-TLBP-001, 002 |
| **F8.13** | TLB Oper | TLBR 操作：读出 L2 TLB 中指定 index 的 entry 内容（VPN, ASID, PPN, flags, page size） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) TLBR 逻辑 | P0 | `ct_mmu_tlboper.v` | TC-TLBR-001, 002 |
| **F8.14** | TLB Oper | TLBWI 操作：写 L2 TLB 指定 index 位置的 entry（受 TLBP 结果引导） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) TLBWI 逻辑 | P1 | `ct_mmu_tlboper.v` | TC-TLBWI-001, 002 |
| **F8.15** | TLB Oper | TLBWR 操作：随机替换 L2 TLB 一条 entry（使用硬件替换策略 RRPV） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) TLBWR 逻辑 | P1 | `ct_mmu_tlboper.v` | TC-TLBWR-001, 002 |
| **F9.1** | CSR/CP0 | SATP 读操作：`cp0_mmu_wreg=0` 时，`mmu_cp0_satp_data` 输出选定 SATP 内容 | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) SATP read 逻辑 | P0 | `ct_mmu_regs.v` | TC-CSR-001, 002 |
| **F9.2** | CSR/CP0 | SATP 写操作：`cp0_mmu_wreg=1` 时，`cp0_mmu_wdata[63:0]` 写入 SATP；更新 PPN/ASID/MODE | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) SATP write 逻辑 | P0 | `ct_mmu_regs.v` | TC-CSR-003, 004 |
| **F9.3** | CSR/CP0 | SATP 字段：MODE (bits[63:60])、ASID (bits[59:44])、PPN (bits[43:0])；MODE=0 时 MMU disable；**写入 MODE 仅接受 wdata[62:60]==3'b0（仅 Bare 与 Sv39 两种），非法 MODE 静默丢弃**（K3/GAP-CSR.1） | [ct_mmu_regs.v#L574-L591](mmu/rtl/ct_mmu_regs.v#L574) | P0 | TC-CSR-005, 006, TC-CSR-MODE-ILLEGAL-001 | sva_satp_mode_illegal |
| **F9.4** | CSR/CP0 | 双 SATP：`cp0_mmu_satp_sel` 控制选择 SATP0 或 SATP1；两 SATP 独立存储与切换 | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) dual SATP mux | P0 | `ct_mmu_regs.v` | TC-CSR-007, 008 |
| **F9.5** | CSR/CP0 | SATP 写后自动 TLB 失效：写新 SATP 后，相关 TLB 自动清除或软件显式 SFENCE（实现选项） | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) + [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) SATP write 互联 | P1 | `ct_mmu_regs.v`, `ct_mmu_tlboper.v` | TC-CSR-009 |
| **F9.6** | CSR/CP0 | MXR 影响：`cp0_mmu_mxr=1` 时，可执行页的 X bit 也授予读权限 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 权限检查；MXR 信号转发 | P1 | `ct_mmu_top.v` | TC-PRIV-001, 002 |
| **F9.7** | CSR/CP0 | SUM 影响：`cp0_mmu_sum=1` 时，特权模式(S mode)可访问用户页(U=1) | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 权限检查；SUM 信号转发 | P1 | `ct_mmu_top.v` | TC-PRIV-003, 004 |
| **F9.8** | CSR/CP0 | MPRV 影响：`cp0_mmu_mprv=1` 时，M 模式数据访问使用 `cp0_mmu_mpp` 指定的特权级进行权限检查 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 权限检查 | P1 | `ct_mmu_top.v` | TC-PRIV-005, 006 |
| **F9.9** | CSR/CP0 | 特权模式切换：`cp0_yy_priv_mode[1:0]` (U=0, S=1, M=3)；不同特权级的页权限判断差异 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 第 20–25 行特权信号接收 | P0 | `ct_mmu_top.v` | TC-PRIV-007, 008 |
| **F9.10** | CSR/CP0 | `ptw_en=0` 禁用 walk：配置后发起的地址翻译若 TLB miss，不启动 PTW，直接返回 fault | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) ptw_en 信号；[ptw.sv](mmu/rtl/ptw.sv) 启用检查 | P1 | `ct_mmu_top.v`, `ptw.sv` | TC-CSR-010 |
| **F9.11** | CSR/CP0 | `no_op_req` 行为：该位置 1 后，MMU 暂停处理新请求（已 in-flight 的继续） | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) no_op_req 处理 | P2 | `ct_mmu_regs.v` | TC-CSR-011 |
| **F9.12** | CSR/CP0 | `maee` 使能门控：低功耗配置，disable 时某些模块停止活动 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) maee 信号分发 | P2 | `ct_mmu_top.v` | TC-CSR-012 |
| **F9.13** | CSR/CP0 | `cskyee` 配置：可能与 C-SKY ISA 扩展相关，需根据实现确定含义 | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) cskyee 字段 | P2 | `ct_mmu_regs.v` | TC-CSR-013 |
| **F9.14** | CSR/CP0 | `icg_en` 时钟门控：enabled 时打开所有时钟，disabled 时门控以降功耗 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) 第 4–6 行时钟相关 | P1 | `ct_mmu_top.v` | TC-CSR-014, 015 |
| **F9.15** | CSR/CP0 | CP0 握手与完成：`mmu_cp0_cmplt` 单周期脉冲指示 read/write 完成 | [ct_mmu_regs.v](mmu/rtl/ct_mmu_regs.v) 完成信号生成 | P0 | `ct_mmu_regs.v` | TC-CSR-016 |
| **F6.10** | `ct_mmu_sysmap` + `ct_mmu_top` | 8 端口独立 SysMap 实例（mmu_sysmap_pa0–7）；hit 输出为 8-bit one-hot/端口（GAP-SM.1 / GAP-SM.2） | [ct_mmu_top.v#L371](mmu/rtl/ct_mmu_top.v#L371), [ct_mmu_sysmap.v#L64-L103](mmu/rtl/ct_mmu_sysmap.v#L64) | P1 | TC-SYSMAP-8PORT-001 | sva_sysmap_8port |
| **F6.11** | `ct_mmu_sysmap_hit` | 优先级链（addr_ge_upaddr 级联）+ 多 region 命中处理（GAP-SM.3） | [ct_mmu_sysmap.v#L157-L163](mmu/rtl/ct_mmu_sysmap.v#L157) | P1 | TC-SYSMAP-PRIO-001 | sva_sysmap_priority |
| **F6.12** | `ct_mmu_sysmap` | 无 region 命中默认 flag = 5'b10011（So=1, C=0, B=0, Sh=1, Sec=1）（GAP-SM.4） | [ct_mmu_sysmap.v#L155](mmu/rtl/ct_mmu_sysmap.v#L155) | P2 | TC-SYSMAP-DEFAULT-001 | cg_sysmap |
| **F6.13** | `ct_mmu_sysmap` | 严格小于（< 而非 <=）边界等值行为（GAP-SM.5） | [ct_mmu_sysmap.v#L184-L199](mmu/rtl/ct_mmu_sysmap.v#L184) | P1 | TC-SYSMAP-EDGE-001 | cg_sysmap |
| **F6.14** | `ct_mmu_sysmap` / `sysmap.h` | PA_WIDTH=40；ADDR_WIDTH=PA_WIDTH-12=28（GAP-SM.6） | [ct_mmu_sysmap.v#L64](mmu/rtl/ct_mmu_sysmap.v#L64) | P2 | TC-SYSMAP-WIDTH-001 | cg_sysmap |
| **F6.15** | `ct_mmu_sysmap` + `ct_mmu_regs` | 5-bit flag = [So,C,B,Sh,Sec]；与 MEL [63:59] 对齐（GAP-SM.7） | [ct_mmu_regs.v#L346-L366](mmu/rtl/ct_mmu_regs.v#L346) | P2 | TC-SYSMAP-MEL-ALIGN-001 | cg_sysmap |
| **F6.16** | `ct_mmu_sysmap` | Region disable、对齐要求（GAP-SM.8 / GAP-SM.9） | [ct_mmu_sysmap.v](mmu/rtl/ct_mmu_sysmap.v) | P1 | TC-SYSMAP-DISABLE-001, TC-SYSMAP-ALIGN-001 | cg_sysmap |
| **F7.9** | `ct_mmu_top` + PTW | 8 端口 mmu_pmp_pa{i} 与 PTW walk 通道映射（GAP-PMP.2） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v), [ptw.sv](mmu/rtl/ptw.sv) | P1 | TC-PMP-PTW-MAP-001 | cg_pmp |
| **F7.10** | `ct_mmu_top` | mmu_pmp_pa{i} 与 mmu_lsu_data_req_addr 一致性（GAP-PMP 补） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P1 | TC-PMP-PA-CONSIST-001 | sva_pmp_pa_match |
| **F7.11** | `ct_mmu_top` | 跨 port PMP deny 独立性（8 port 可独立配置权限） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P1 | TC-PMP-INDEP-001 | cg_pmp |
| **F7.12** | `ct_mmu_top` | L1/L2 PDE 缓存中 PTE 取出后的 PMP 检查路由 | [ptw.sv](mmu/rtl/ptw.sv) | P1 | TC-PMP-PDE-CACHE-001 | sva_pmp_after_pde |
| F7.NEW.1 | `ct_mmu_top` | **`mmu_pmp_fetch4` 缺失**：port 4（L2TLB 端口）的 `mmu_pmp_fetch4` 信号已被注释掉，该端口 PMP 访问无法区分 fetch/data 类型（GAP-PMP.NEW.1） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P1 | TC-PMP-FETCH4-MISS-001 | cg_pmp_fetch_map |
| F7.NEW.2 | `ct_mmu_top` + `ptw` | **`pmp_mmu_flg5/6/7` PTW 扩展端口**：三个后加端口（RTL 中标注 `[NEW]`/`!!!!!`）的功能归属（对应哪个 TWU 通道）、权限语义及全路径覆盖（GAP-PMP.NEW.2） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v), [ptw.sv](mmu/rtl/ptw.sv) | P1 | TC-PMP-NEW-PORT-001 | cg_pmp_fetch_map |
| **F8.16** | `ct_mmu_tlboper` | INVVA 无显式计数器（INVALL=255, INVASID=511，11-bit 深度）（GAP-TLBO.2 / GAP-TLBO.3） | [ct_mmu_tlboper.v#L950-L951](mmu/rtl/ct_mmu_tlboper.v#L950) | P2 | TC-TLBOPER-CNT-001 | cg_tlboper |
| **F8.17** | `ct_mmu_tlboper` | tlb_lsu_oper_flop 握手协议；back-to-back SFENCE 阻塞（GAP-TLBO.4） | [ct_mmu_tlboper.v#L1074-L1088](mmu/rtl/ct_mmu_tlboper.v#L1074) | P1 | TC-SFENCE-B2B-001 | sva_sfence_handshake |
| **F8.18** | `ct_mmu_tlboper` | tlboper_ptw_abort = tlb_lsu_oper && !flop 脉冲时序（GAP-TLBO.5） | [ct_mmu_tlboper.v#L1111](mmu/rtl/ct_mmu_tlboper.v#L1111) | P1 | TC-SFENCE-ABORT-PULSE-001 | sva_abort_pulse |
| **F8.19** | `ct_mmu_tlboper` | TLBP/R/WI/WR 全部 gated by !tlb_lsu_oper：与 LSU 串行（GAP-TLBO.6） | [ct_mmu_tlboper.v#L90-L110](mmu/rtl/ct_mmu_tlboper.v#L90) | P2 | TC-TLBOPER-SERIALIZE-001 | sva_tlboper_serial |
| **F8.20** | `ct_mmu_tlboper` | TLBWR 4 状态（WRIDLE/WRWFG/WRTAG/WRWFC）vs TLBP/R/WI 3 状态（GAP-TLBO.7） | [ct_mmu_tlboper.v#L263-L278](mmu/rtl/ct_mmu_tlboper.v#L263) | P2 | TC-TLBWR-FSM-001 | cg_tlbwr_fsm |
| **F8.21** | `ct_mmu_tlboper` | INVVA 时序与跨 page-size hit 联动 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) | P1 | TC-INVVA-XPG-001 | cg_tlb_inv |
| **F8.22** | `ct_mmu_tlboper` | TLBR/TLBWI 在 ASID/G 表现偏移下的语义 | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) | P2 | TC-TLBR-ASID-G-001 | cg_tlboper |
| F8.NEW.1 | `ct_mmu_tlboper` | **SFENCE INVVA single-pass 覆盖**：简化后的 5-state FSM 仅做一次 L2TLB 查找（相较原 14-state 多 pass）；L2TLB 中同一 VPN 有多种 page size 共存时，仅 `cur_pgs` 匹配的 entry 被无效；需专项验证此语义（GAP-TLBO.NEW.1） | [ct_mmu_tlboper.v](mmu/rtl/ct_mmu_tlboper.v) | P0 | TC-SFENCE-INVVA-SINGPASS-001, TC-SFENCE-INVVA-MULTIPGS-001 | cg_sfence_invva_pgs, sva_sfence_invva_single |
| F8.NEW.2 | `ct_mmu_tlboper` | **14-state INVVA FSM 注释残留清理**（v3.0 文档/代码项）：`ct_mmu_tlboper.v` L685-L730 存在大段原 14-state FSM 注释代码，已被 single-pass 实现替代；仅用于文档/代码清理追溯，无功能影响 | [ct_mmu_tlboper.v#L685-L730](mmu/rtl/ct_mmu_tlboper.v#L685) | P2 | TC-BUG-015（文档项） | — |
| **F9.16** | `ct_mmu_regs` | ASID/PPN 总更新（无 MODE guard）；部分写语义（GAP-CSR.2） | [ct_mmu_regs.v#L585-L591](mmu/rtl/ct_mmu_regs.v#L585) | P1 | TC-CSR-PARTIAL-WR-001 | cg_csr |
| **F9.17** | `ct_mmu_regs` | MCIR no-op fast-path：bits[31:26]==0 时立即 mmu_cp0_cmplt（GAP-CSR.3） | [ct_mmu_regs.v#L550-L600](mmu/rtl/ct_mmu_regs.v#L550) | P1 | TC-MCIR-NOOP-001 | sva_mcir_fast |
| **F9.18** | `ct_mmu_regs` | satp_write_en → regs_utlb_clr 组合即时清零；无延迟（GAP-CSR.4） | [ct_mmu_regs.v#L179](mmu/rtl/ct_mmu_regs.v#L179) | P1 | TC-SATP-UTLB-CLR-001 | sva_satp_utlb_imm |
| **F9.19** | `ct_mmu_regs` | mir_probe / mir_tlbp_tfatal 仅 TLBP 完成时更新（GAP-CSR.5）；MEL 三源优先级（GAP-CSR.6）；MEH 记 bad_vpn / MEL ASID 不联动（GAP-CSR.7） | [ct_mmu_regs.v#L260-L418](mmu/rtl/ct_mmu_regs.v#L260) | P2 | TC-MIR-MEL-MEH-001 | cg_csr |
| **F9.20** | `ct_mmu_regs` | SATP write 未 hold-off active PTW（依赖 PTW 自身）；back-to-back CSR write 与 active TLBOper 的 stall（GAP-HZD.1 / GAP-HZD.2） | [ct_mmu_regs.v#L179-L188](mmu/rtl/ct_mmu_regs.v#L179) | P1 | TC-SATP-PTW-HAZARD-001, TC-CSR-TLBOPER-HAZARD-001 | satp_hazard_cg |
| **F9.21** | `ct_mmu_regs` | priv_mode mux MPRV：mp_mu_mpp vs cp0_yy_priv_mode；mmu_lsu_mmu_en vs mmu_xx_mmu_en 分裂（GAP-HZD.3 / K11） | [ct_mmu_regs.v#L645-L648](mmu/rtl/ct_mmu_regs.v#L645) | P2 | TC-MPRV-MUX-001 | cg_priv |
| **F9.22** | `ct_mmu_regs` | 全 CSR reset 默认值（SATP MODE=0 bare, ASID=0, PPN=0, MIR/MEL/MEH=0）（GAP-RST.1） | [ct_mmu_regs.v#L254,L271,L407,L465,L574-L575](mmu/rtl/ct_mmu_regs.v#L254) | P2 | TC-CSR-RST-DEFAULT-001 | sva_csr_reset_val |

---


---

### 5.5 Top-level — 异常/性能/复位/压力 (F10–F14)

> 模块范围：**Top-level / System-level (F10-F14)**

## § 5 Feature List（F10-F14）

| ID | 功能点 | 描述 | 依据/RTL参考 | 优先级 | 关键信号 |
|---|---|---|---|---|---|
| **F10 异常与特权** |
| F10.1 | IFU page fault (V=0) | 指令侧虚页（PTE.V=0）产生 page fault | ct_mmu_top.v:65 / mmu_ifu_pgflt | P0 | `mmu_ifu_pgflt` |
| F10.2 | IFU page fault (U违规) | 指令在用户模式访问监管页产生 fault | mmu_l1itlb.sv / 特权检查 | P0 | `mmu_ifu_pgflt`, `cp0_yy_priv_mode` |
| F10.3 | IFU page fault (X=0) | 指令侧无执行权限产生 fault | mmu_l1itlb.sv / X 位检查 | P0 | `mmu_ifu_pgflt` |
| F10.4 | LSU pipe0 page fault (store) | 管道0 存指令的page fault | mmu_l1dtlb.sv / store 权限 | P0 | `mmu_lsu_page_fault0`, `lsu_mmu_st_inst0` |
| F10.5 | LSU pipe1 page fault (load) | 管道1 读指令的 page fault | mmu_l1dtlb.sv / load 权限 | P0 | `mmu_lsu_page_fault1` |
| F10.6 | LSU access fault (PMP deny) | PMP 拒绝（权限缺失）产生 access fault；page_fault vs access_fault 严格区分（GAP-AT.4） | ct_mmu_top.v:171-180 / PMP接口 | P0 | `mmu_lsu_access_fault0/1`, `mmu_lsu_page_fault0/1` |
| F10.7 | LSU access fault (bus error) | 总线错误转化为 access fault | ptw.sv / bus_error 处理 | P1 | `mmu_lsu_access_fault0/1`, `lsu_mmu_bus_error` |
| F10.8 | Pipe2 (prefetch) pa2_err | Prefetch 通道的翻译错误信号 | ct_mmu_top.v:115 / pipe2 | P1 | `mmu_lsu_pa2_err` |
| F10.9 | bad_vpn 登记正确性 | RTU 异常时 bad_vpn[26:0] 正确记录失败VPN | ct_mmu_top.v:182 / rtu_mmu | P0 | `rtu_mmu_bad_vpn[26:0]` |
| F10.10 | expt_vld 联动清理 MB | RTU 异常信号触发 pending MB 项清理 | ct_mmu_top.v:183 / ptw_mbuf | P0 | `rtu_mmu_expt_vld`, MB valid |
| F10.11 | rtu_yy_xx_flush 全清理 | **rtu_yy_xx_flush 影响范围需明确**：MB / ReqQ / PDE cache / TWU 各自是否清空（K12/GAP-BP.6） | ct_mmu_top.v:184 / L2TLB ReqQ | P0 | `rtu_yy_xx_flush`, ReqQ valid, MB valid, TWU FSM, PDE cache vld |
| F10.12 | deny/sec 位异常条件输出 | 异常时 sec/deny 位保持正确 | mmu_l1itlb.sv / entry flag | P1 | `mmu_ifu_sec`, `mmu_ifu_deny` |
| F10.13 | 多源并发异常优先级 | IFU/LSU0/LSU1/Pipe2 同时异常时优先级唯一 | 多源仲裁逻辑 | P1 | 异常信号集合 |
| F10.14 | 异常后 TLB 正常工作 | 异常清理后 TLB 可继续接收请求 | testbench checker | P1 | TLB 响应信号 |
| **F11 性能计数** |
| F11.1 | iutlb_miss 脉冲计数 | L1 ITLB miss 时 hpcp_mmu_cnt_en=1 脉冲输出 | ct_mmu_top.v:46 / mmu_ifu | P0 | `mmu_hpcp_iutlb_miss`, `hpcp_mmu_cnt_en` |
| F11.2 | iutlb_miss 与真实 miss 1:1 | 每条 L1 ITLB miss 对应恰好 1 个脉冲 | mmu_l1itlb.sv / miss 逻辑 | P0 | 脉冲计数 |
| F11.3 | dutlb_miss pipe0 只计实际 miss | pipe0 miss 时脉冲有效；hit/retry 不计 | mmu_l1dtlb.sv / pipe0 | P0 | `mmu_hpcp_dutlb_miss` |
| F11.4 | dutlb_miss pipe1 只计实际 miss | pipe1 miss 时脉冲有效；hit/retry 不计 | mmu_l1dtlb.sv / pipe1 | P0 | `mmu_hpcp_dutlb_miss` |
| F11.5 | jtlb_miss L2 TLB miss | L2 TLB 真实 miss 产生脉冲 | mmu_l2tlb.sv / miss logics | P0 | `mmu_hpcp_jtlb_miss` |
| F11.6 | 并发 miss 脉冲不丢失 | 同拍 pipe0/pipe1 miss 或 L2 miss，脉冲同时有效 | ReqQ/L2 仲裁 | P1 | 并发脉冲 |
| F11.7 | hpcp_cnt_en 门控使能 | cnt_en=0 时脉冲应屏蔽；cnt_en=1 时脉冲正常 | ct_mmu_top.v / CP0接口 | P0 | `hpcp_mmu_cnt_en` |
| F11.8 | 性能计数与压力并发 | 高压力下（L2 满、PTW 满）计数仍准确 | pressure 场景 | P2 | 计数准确性 |
| **F12 低功耗/DFT** |
| F12.1 | icg_en=0 停止时钟 | 空闲时 icg_en=0 正确停止所有时钟树 | ct_mmu_top.v:39 / icg | P1 | `cp0_mmu_icg_en` |
| F12.2 | icg_en=1 正常工作 | icg_en=1 时所有请求正常处理 | ct_mmu_top.v / 正常流程 | P0 | 时钟使能 |
| F12.3 | scan_en=1 强制时钟打开 | DFT scan mode 时 pad_yy_icg_scan_en=1 强制时钟 | ct_mmu_top.v:176 / scan接口 | P1 | `pad_yy_icg_scan_en` |
| F12.4 | smp_disable 关闭 snoop | biu_mmu_smp_disable=1 时关闭 snoop 广播 | ct_mmu_top.v:44 / smp接口 | P2 | `biu_mmu_smp_disable` |
| F12.5 | 时钟门控序列正确性 | icg 关-开-关转换无毛刺、无异常 | 门控逻辑 | P1 | 时钟信号 |
| **F13 复位与初始化** |
| F13.1 | cpurst_b 异步断言 → 同步释放 | 复位异步断言，同步释放后 TLB 全无效 | ct_mmu_top.v:38 / cpurst_b | P0 | `cpurst_b` |
| F13.2 | 复位后 TLB 全无效 | cpurst_b 释放后，L1 ITLB/DTLB/L2 TLB entry valid 全 0 | mmu_l1itlb.sv / reset | P0 | entry_vld[*] |
| F13.3 | 复位后寄存器默认值 | SATP=0, priv_mode=11(M mode), MXR/SUM=0 | ct_mmu_regs.v / reset | P0 | 寄存器复位值 |
| F13.4 | 中途复位：walk 中止 | PTW 正在 walk 时复位，TWU FSM 停止 | ptw.sv / reset → IDLE | P1 | TWU FSM |
| F13.5 | 中途复位：响应中止 | L1 返回途中复位，pending 响应不产生错误 | mmu_l1itlb/l1dtlb reset | P1 | 响应信号 |
| F13.6 | 复位期间输出 X 保护 | 复位期间所有输出保持已知（0/Z），无 X | RTL reset block | P1 | 输出信号 |
| F13.7 | mmu_xx_mmu_en 复位状态指示 | 复位后应指示 MMU 初始状态（根据 SATP/priv） | ct_mmu_top.v:50 / mmu_xx_mmu_en | P1 | `mmu_xx_mmu_en` |
| F13.8 | 复位后立即可工作 | 复位释放后无需额外初始化即可响应请求 | 验证流程 | P0 | 功能正常性 |
| **F14 压力与综合场景** |
| F14.1 | 3 pipe 同时打满 | IFU + LSU0 + LSU1 + Pipe2 同时最大速率请求 | mmu_stress_all_ports_vseq | P1 | 三路输入 |
| F14.2 | L2 TLB 饱和 + MB 满 | L2 TLB 8×8×256 条目全占用 + MB 9 entry 满 | L2 状态机 | P1 | TLB valid, MB valid |
| F14.3 | 8 bank 冲突 + ReqQ 满 | 并发请求均指向同一 bank，ReqQ 9 entry 满 | mmu_l2tlb_reqq.sv | P2 | ReqQ state |
| F14.4 | PTW 4 TWU 全打满 + wakeup 高密度 | 4 个 Tree Walk Unit 并发处理，wakeup vector 高密度 | ptw.sv / ptw_mbuf | P1 | TWU FSM, MB full |
| F14.5 | 高频 SATP 热切换 | 每隔数十拍切换 SATP 值，并发访问不中断 | mmu_satp_hotswap_vseq | P1 | SATP 切换 |
| F14.6 | 高频 SFENCE.VMA | 背压下连续 SFENCE 请求，TLB 仍正常工作 | tlb_inv_during_walk_vseq | P1 | 无效化信号 |
| F14.7 | 多 ASID 热切换 + thrashing | 高频在多 ASID 间切换，hit rate 恢复快 | mmu_asid_context_switch_vseq | P1 | ASID 值 |
| F14.8 | 1GB 巨页 + 4KB 混合访问 | Sv39 1GB/2MB/4KB 页面混合，替换政策正确 | mmu_huge_page_mix_vseq | P1 | 页大小标记 |
| F14.9 | 长时间稳定运行（≥100K 事务） | 高频多源并发运行 100K+ 个事务无死锁/数据错误 | mmu_stress_all_ports_vseq | P0 | 事务计数 |
| F14.10 | Error rain：random bus_error + illegal PTE | 随机混合总线错误、非法 PTE（V=0/R⊕W/保留位）| mmu_error_rain_vseq | P1 | 错误注入 |
| F14.11 | Replacement policy 压力（RRPV aging） | L2 TLB RRPV 替换在高 miss 率下保持正确 | mmu_rrpv_aging_vseq | P2 | RRPV 值 |
| F14.12 | 复位中途：mid-transaction | 正在 walk/返回时异步复位，恢复无错误 | mmu_reset_midtransaction_vseq | P1 | 复位时序 |
| F14.13 | 电源门控序列（若模块支持） | 低功耗序列中 icg_en/smp_disable 状态转换 | mmu_power_gating_vseq | P2 | 门控信号 |
| **F10.15** | `ct_mmu_top` | **mmu_lsu_mmu_en vs mmu_xx_mmu_en 双输出语义/时序差异**（K11/GAP-TP.1） | [ct_mmu_top.v#L50,L134](mmu/rtl/ct_mmu_top.v#L50), [ct_mmu_regs.v#L106-L108](mmu/rtl/ct_mmu_regs.v#L106) | P0 | TC-MMU-EN-DUAL-001 | sva_mmu_en_consist |
| **F10.16** | `ct_mmu_top` | mmu_had_debug_info[33:0] bit 拆解（iutlb_st[1:0], dutlb_st[2:0], tlbop states 等）（GAP-TP.2） | [ct_mmu_top.v#L940-L955](mmu/rtl/ct_mmu_top.v#L940) | P1 | TC-DBG-INFO-001 | cg_dbg |
| **F10.17** | `ct_mmu_top` | ifu_mmu_abort 与 ifu_mmu_va_vld 在 L1ITLB miss 中段的协议（GAP-TP.4）；lsu_mmu_abort[0:1] 在 L2 refill in-flight 时立即清 MB vs 等 refill（GAP-TP.5） | [ct_mmu_top.v#L57-L73](mmu/rtl/ct_mmu_top.v#L57) | P1 | TC-IFU-ABT-MIDMISS-001, TC-LSU-ABT-INFLIGHT-001 | sva_abt_protocol |
| **F10.18** | `mmu_l1dtlb_hit_rd` | **STAMO bypass**：stamo_vld=1 时 PA 直来自 stamo_pa，跳 TLB 权限检（GAP-AT.2） | [mmu_l1dtlb_hit_rd.sv#L255-L260](mmu/rtl/mmu_l1dtlb_hit_rd.sv#L255) | P0 | TC-STAMO-BYPASS-001 | sva_stamo_bypass |
| **F10.19** | `mmu_l2tlb` + IFU/Pipe2 | Pipe2 仅 mmu_lsu_sec2/share2；ca/buf/sh/so 缺失；VA 仅 28-bit；pa2_err 与 pa2_vld 同为 1的语义（GAP-AT.5 / GAP-AT.6 / GAP-AT.7） | [ct_mmu_top.v#L110-L117](mmu/rtl/ct_mmu_top.v#L110), [mmu_l2tlb.sv#L1157-L1158](mmu/rtl/mmu_l2tlb.sv#L1157) | P1 | TC-PIPE2-ATTR-001 | attr_propagation_cg |
| **F10.20** | `mmu_l1dtlb` | lsu_mmu_vabuf[0:1] 28-bit 协议（GAP-AT.1）；STAMO Pipe0/1 不对称（GAP-AT.3） | [mmu_l1dtlb.sv#L41,L60](mmu/rtl/mmu_l1dtlb.sv#L41) | P2 | TC-VABUF-PROTO-001 | cg_vabuf |
| **F10.21** | `mmu_l1dtlb` + `mmu_l2tlb` + `mmu_arb` | dutlb↔l2tlb credit 控制；L2TLB 4 源仲裁同时 valid worst-case stall；IFU+LSU0+LSU1 三 pipe 同 cycle miss（GAP-MC.3 / GAP-MC.4 / GAP-MC.5） | [ct_mmu_top.v#L490-L545](mmu/rtl/ct_mmu_top.v#L490) | P1 | TC-3PIPE-MISS-001, TC-CREDIT-DEADLOCK-001 | mbuf_alloc_cg |
| **F10.22** | `ct_mmu_top` | 多端口异常并发优先级（IFU pgflt + LSU0/1 + PMP + bus_error）（GAP-BP.7） | [ct_mmu_top.v#L45-L48](mmu/rtl/ct_mmu_top.v#L45) | P1 | TC-EXC-PRIO-001 | sva_exc_priority |
| **F11.9** | HPCP | mmu_hpcp_dutlb_miss / iutlb_miss / jtlb_miss 脉冲宽度明确（1 cycle vs 持续）（GAP-HP.1 / GAP-HP.2 / GAP-HP.3 / GAP-HP.4） | [ct_mmu_top.v#L44-L45](mmu/rtl/ct_mmu_top.v#L44), [ptw.sv#L112](mmu/rtl/ptw.sv#L112) | P1 | TC-HPCP-PULSE-001 | cg_hpcp |
| **F11.10** | `mmu_l1dtlb_install` | dutlb_top_ref_cur_st[2:0] 状态编码（GAP-HP.5） | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv) | P2 | TC-DUTLB-DBG-ST-001 | cg_dbg |
| **F11.11** | `ptw` | TWU 6 端口 vs 4 TWU；端口与 TWU 映射（GAP-HP.6） | [ptw.sv](mmu/rtl/ptw.sv) | P2 | TC-TWU-PORT-MAP-001 | cg_twu_port |
| **F11.12** | HPCP | mmu_hpcp_jtlb_miss = L1+L2 miss vs 仅 L2 miss 语义明确（GAP-HP.3） | [ptw.sv#L112](mmu/rtl/ptw.sv#L112) | P1 | TC-HPCP-JTLB-DEF-001 | cg_hpcp |
| **F11.13** | HPCP | 并发 miss 脉冲不丢失（与原 F11.6 交叉加强） | ReqQ/L2 仲裁 | P1 | TC-HPCP-CONCUR-001 | cg_hpcp |
| **F11.14** | HPCP | hpcp_cnt_en 门控与压力场景下准确性 | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P2 | TC-HPCP-STRESS-001 | cg_hpcp |
| **F12.6** | `ct_spsram_*` + DFT | scan chain 集成（pad_yy_icg_scan_en 仅 gate clock；无 scan_in/out）（GAP-SR.5） | [ct_spram_wrapper.sv#L1](mmu/rtl/ct_spram_wrapper.sv#L1) | P2 | TC-DFT-SCAN-001 | cg_dft |
| **F12.7** | `ct_spsram_*` | BIST 信号在 wrapper 中缺失；FPGA 模型无 BIST（GAP-SR.4） | [ct_spsram_256x196.v](mmu/rtl/ct_spsram_256x196.v) | P2 | TC-DFT-BIST-001 | cg_dft |
| **F12.8** | L1 ITLB+DTLB | cp0_mmu_icg_en 低功耗切换 latch 完整性 / 信号 hold（GAP-X3.1） | [mmu_l1dtlb.sv#L110-L140](mmu/rtl/mmu_l1dtlb.sv#L110), [mmu_l1itlb.sv#L1-L50](mmu/rtl/mmu_l1itlb.sv#L1) | P1 | TC-ICG-LATCH-001 | sva_icg_hold |
| **F13.9** | `ct_spsram_*` | **SRAM macro 无 reset**；valid 位由外部 FF 清零；首 cycle 防 X（K9/GAP-SR.1 / GAP-RS.2） | [ct_spsram_256x196.v#L1-L25](mmu/rtl/ct_spsram_256x196.v#L1) | P0 | TC-SRAM-RST-VALID-001 | sva_no_x_after_reset |
| **F13.10** | `mmu_fpga_ram` vs ASIC | 同 cycle write-then-read 行为差异 → equivalence（GAP-SR.2） | [mmu_fpga_ram.sv#L38-L45](mmu/rtl/mmu_fpga_ram.sv#L38) | P0 | TC-FPGA-ASIC-EQ-002 | sva_sram_equiv |
| **F13.11** | `ct_mmu_top` | cpurst_b 释放顺序：SysMap/PMP/L2TLB FF/PTW startup（GAP-RS.1） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P1 | TC-RST-SEQ-001 | sva_reset_order |
| **F13.12** | `mmu_l1dtlb` + `ptw` + `ct_mmu_regs` | MB entry / PTW reset mid-walk / 寄存器复位顺序（GAP-RS.3 / GAP-RS.4 / GAP-RS.5） | [mmu_l1dtlb.sv](mmu/rtl/mmu_l1dtlb.sv), [ptw.sv#L23](mmu/rtl/ptw.sv#L23), [ct_mmu_regs.v#L143-L147](mmu/rtl/ct_mmu_regs.v#L143) | P1 | TC-RST-MIDWALK-001, TC-RST-MB-CLR-001 | sva_reset_clean |
| **F13.13** | `ct_spram_wrapper` | WEN 按位写是否真正生效（GAP-SR.3） | [ct_spram_wrapper.sv#L1-L16](mmu/rtl/ct_spram_wrapper.sv#L1) | P2 | TC-SRAM-WEN-BIT-001 | sva_wen_bit |
| **F14.14** | `mmu_l1dtlb` | **Bypass 模式属性默认值**（dutlb_xx_mmu_off=!regs_mmu_en ‖ cp0_mach_mode）（GAP-BP.1） | [mmu_l1dtlb.sv#L119](mmu/rtl/mmu_l1dtlb.sv#L119) | P0 | TC-BYPASS-ATTR-001 | attr_propagation_cg |
| **F14.15** | `ct_mmu_top` | **SATP hotswap**：regs_utlb_clr 即时断言 → uTLB 临时失效窗口（GAP-BP.2） | [ct_mmu_regs.v#L179](mmu/rtl/ct_mmu_regs.v#L179) | P0 | TC-SATP-HOTSWAP-001 | satp_hazard_cg |
| **F14.16** | `ct_mmu_top` | cp0_yy_priv_mode 异步切换 vs in-flight 翻译的 race（GAP-BP.3） | [ct_mmu_top.v#L36](mmu/rtl/ct_mmu_top.v#L36) | P1 | TC-PRIV-RACE-001 | sva_priv_race |
| **F14.17** | `ct_mmu_regs` | mmu_cp0_cmplt / mmu_cp0_tlb_done 协议时序（GAP-BP.4）；rtu_mmu_bad_vpn 仅 page fault 触发 vs 也 access fault（GAP-BP.5） | [ct_mmu_regs.v#L37-L40,L104](mmu/rtl/ct_mmu_regs.v#L37) | P1 | TC-CSR-CMPLT-PROTO-001, TC-BADVPN-COND-001 | sva_csr_handshake |
| **F14.18** | `ptw` | **mmu_lsu_data_req 协议**（req-grant vs fire-and-forget）、max in-flight（GAP-BP.8）；data_req_size 含义（GAP-BP.9） | [ct_mmu_top.v#L135-L137](mmu/rtl/ct_mmu_top.v#L135) | P0 | TC-PTW-LSU-PROTO-001 | sva_ptw_lsu_chn |
| **F14.19** | L1 ITLB+DTLB | 参数边界（MB_DEPTH=8, NUM_ENTRY=16/32, CREDIT_MAX=8） power-of-2 wrap（GAP-X3.4 / GAP-X3.8）；age compare 下溢/wrap（GAP-X3.3）；SATP ASID 切换自动失效 vs 手动 SFENCE 协议（GAP-X3.5） | [mmu_l1dtlb.sv#L10-L14](mmu/rtl/mmu_l1dtlb.sv#L10) | P1 | TC-PARAM-WRAP-001, TC-AGE-CMP-001, TC-ASID-PROTO-001 | sva_credit_wrap |
| **F14.20** | `mmu_l1dtlb_scheduler` + `mmu_l1dtlb` | MB 空时 bypass 路径优先级（bypass req 即使 bypass_en 撤销仍优先）（GAP-D2.5）；MB req 与 bypass req 同周期 fire 仲裁（GAP-X3.9）；双端口 hit/PLRU race（GAP-D2.6 / GAP-D2.14） | [mmu_l1dtlb_scheduler.sv#L120-L160](mmu/rtl/mmu_l1dtlb_scheduler.sv#L120), [ct_mmu_dplru.v#L1-L50](mmu/rtl/ct_mmu_dplru.v#L1) | P1 | TC-MB-BYPASS-PRIO-001, TC-DUAL-HIT-PLRU-001 | cg_dtlb_concurrent |
| F10.NEW.1 | `ct_mmu_top` | **`mmu_yy_xx_no_op` 输出语义**：广播 no-op 状态信号，何时为 1、影响哪些下游模块；现有功能点未覆盖此信号的激活条件（GAP-TP.NEW.1）（需设计确认） | [ct_mmu_top.v](mmu/rtl/ct_mmu_top.v) | P2 | TC-NO-OP-001 | cg_no_op_state |
| F12.NEW.1 | `pplru` | **PLRU entry 0 首次命中不更新**：复位后 `hit_num_flop=0`，entry 0 首次命中时 `index==flop` → `plru_read_updt=false`，PLRU 树不更新；对 PDE Cache 首次替换公平性有影响（GAP-PPLRU.NEW.1） | [pplru.sv](mmu/rtl/pplru.sv) | P1 | TC-PPLRU-ENTRY0-FIRST-HIT-001 | cg_pplru_entry0_hit |


---

## 6. 测试用例计划（Test Case Plan）

### 6.1 测试分类与命名规范

- **Sanity**：`test_mmu_sanity_*`
- **Directed**：`test_mmu_dir_<module>_<scenario>`
- **Constrained-Random**：`test_mmu_rand_<scope>_<scenario>`
- **Error-Injection**：`test_mmu_err_<type>_<scope>`
- **Performance / Stress**：`test_mmu_perf_<metric>` / `test_mmu_stress_<scope>`
- **SFENCE / Invalidation**：`test_mmu_sfence_<mode>`
- **ASID Switch**：`test_mmu_asid_<scenario>`
- **Huge Page**：`test_mmu_huge_<size>_<scenario>`
- **Power/Reset**：`test_mmu_pwr_*` / `test_mmu_reset_*`

所有 test class 继承 `mmu_test_base`，配置项通过 `uvm_config_db` 下发；主 sequence 运行在 `virtual_sequencer`。

### 6.2 Sequence 清单（按 Agent 分组，**仅声明不实现**）

#### 6.2.1 `ifu_agent` sequences

| Sequence 类名 | 职责 |
|---|---|
| `ifu_base_seq` | 基础 IFU 事务发起，支持 weight 配置 |
| `ifu_random_vaddr_seq` | 随机 63-bit VA，含合法 / 越界比例可控 |
| `ifu_sequential_fetch_seq` | 顺序取指，覆盖页边界 |
| `ifu_abort_seq` | 有效请求后立即 abort，覆盖 cancel 路径 |
| `ifu_branch_flush_seq` | 触发 RTU flush 时的 IFU 行为 |
| `ifu_pagefault_trigger_seq` | 构造 PTE 无效 / 权限违反的 VA |
| `ifu_exec_perm_mix_seq` | 覆盖 X bit、deny、sec 组合 |
| `ifu_huge_page_fetch_seq` | 2 MB / 1 GB 大页取指 |

#### 6.2.2 `lsu_agent` sequences

| Sequence 类名 | 职责 |
|---|---|
| `lsu_base_seq` | 通用 Pipe0/1 事务 |
| `lsu_pipe0_only_seq` / `lsu_pipe1_only_seq` | 单通道压力 |
| `lsu_pipe01_concurrent_seq` | Pipe0/1 同周期发起，覆盖 arbiter / MB 竞争 |
| `lsu_prefetch_pipe2_seq` | Pipe2 预取，带 abort / miss 组合 |
| `lsu_stamo_seq` | STAMO 原子 PA 通报 |
| `lsu_back2back_seq` | 连续背靠背 |
| `lsu_same_line_hit_miss_seq` | 同 VPN 不同 offset 命中 / miss |
| `lsu_abort_seq` | 请求发出后即时 abort |
| `lsu_huge_page_seq` | 2 MB / 1 GB 数据访问 |
| `lsu_cross_asid_seq` | 跨 ASID 背靠背访问同一 VA |
| `lsu_st_ld_mix_seq` | 读写混合，覆盖 D 位更新 |
| `lsu_unaligned_seq` | 未对齐访问路径 |

#### 6.2.3 `cp0_agent` sequences

| Sequence 类名 | 职责 |
|---|---|
| `cp0_reg_rw_seq` | 所有 MMU CSR 读写 |
| `cp0_satp_switch_seq` | SATP 切换（触发 TLB 自动失效或软件 SFENCE 场景） |
| `cp0_satp_sel_toggle_seq` | 双 SATP 之间切换 |
| `cp0_priv_switch_seq` | U/S/M 模式切换 |
| `cp0_mxr_sum_cross_seq` | MXR / SUM 组合覆盖 |
| `cp0_mprv_seq` | MPRV 与 MPP 配置下的数据访问 |
| `cp0_ptw_disable_seq` | `ptw_en=0` 行为 |
| `cp0_tlb_allinv_seq` | 经 CP0 路径发起全 TLB 失效 |
| `cp0_no_op_seq` | `no_op_req` 置位的行为 |

#### 6.2.4 TLB Invalidation sequences（`tlb_inv_agent` / 合并在 LSU/CP0）

| Sequence 类名 | 职责 |
|---|---|
| `tlb_inv_all_seq` | `lsu_mmu_tlb_all_inv` 全失效 |
| `tlb_inv_va_seq` | 指定 VPN 跨所有 ASID 失效 |
| `tlb_inv_asid_seq` | 指定 ASID 全部失效 |
| `tlb_inv_va_asid_seq` | VPN + ASID 组合失效 |
| `tlb_inv_during_walk_seq` | 正在 PTW 时发起失效 |
| `sfence_vma_stress_seq` | 高频 SFENCE 施压 |

#### 6.2.5 `ptw_mem_agent` sequences（Responder 侧）

| Sequence 类名 | 职责 |
|---|---|
| `ptw_mem_normal_rsp_seq` | 正常延迟响应 |
| `ptw_mem_ooo_rsp_seq` | 多请求乱序返回（通过 wakeup 向量协调） |
| `ptw_mem_slow_rsp_seq` | 大延迟（超 timeout 边界） |
| `ptw_mem_bus_error_inject_seq` | `lsu_mmu_bus_error` 注入 |
| `ptw_mem_illegal_pte_seq` | V=0 / R=W=0 / reserved / misaligned PPN / U-bit 违规 / A=0 / D=0 |
| `ptw_page_table_build_4k_seq` | 构建 4 KB 三级页表 |
| `ptw_page_table_build_2m_seq` | 构建 2 MB 巨页 |
| `ptw_page_table_build_1g_seq` | 构建 1 GB 巨页 |
| `ptw_pte_ad_update_seq` | A/D bit 软硬件更新 |
| `ptw_deep_tree_random_seq` | 深随机页表树，高 PDE miss 率 |

#### 6.2.6 `pmp_agent` sequences

| Sequence 类名 | 职责 |
|---|---|
| `pmp_flg_normal_seq` | 8 端口正常权限 |
| `pmp_flg_deny_fetch_seq` | 拒绝取指权限 |
| `pmp_flg_deny_rw_seq` | 拒绝读写权限 |
| `pmp_flg_cross_8port_seq` | 8 端口独立权限交叉 |

#### 6.2.7 `sysmap_cfg_agent` sequences

| Sequence 类名 | 职责 |
|---|---|
| `sysmap_region_setup_seq` | 配置 8 region 基址/掩码 |
| `sysmap_hit_cross_tlb_seq` | SysMap 命中同时 TLB 也有映射（SysMap 优先） |
| `sysmap_boundary_seq` | 边界对齐 / 跨 region 边界 |
| `sysmap_perm_flag_seq` | 覆盖 5-bit flag 全组合 |

#### 6.2.8 Virtual Sequences（跨 Agent，位于 `virtual_sequencer`）

| Virtual Sequence | 职责 |
|---|---|
| `mmu_smoke_vseq` | 冒烟：SATP 配置 + IFU/LSU 基本翻译 + 无异常 |
| `mmu_concurrent_3pipe_vseq` | IFU + LSU Pipe0 + LSU Pipe1 同步施压 |
| `mmu_ptw_thrash_vseq` | 触发 L2 TLB 饱和与 PTW 满端口 |
| `mmu_sfence_during_walk_vseq` | PTW 进行中发起 SFENCE |
| `mmu_asid_context_switch_vseq` | 高频 ASID 切换 + 并发访问 |
| `mmu_huge_page_mix_vseq` | 4 K / 2 M / 1 G 混合 |
| `mmu_rrpv_aging_vseq` | 覆盖 RRPV 所有老化路径 |
| `mmu_l2tlb_bank_conflict_vseq` | 8 Bank 冲突构造 |
| `mmu_satp_hotswap_vseq` | SATP0↔SATP1 热切换 |
| `mmu_stress_all_ports_vseq` | 全端口打满 |
| `mmu_power_gating_vseq` | ICG 打开/关闭，扫描模式 |
| `mmu_reset_midtransaction_vseq` | 事务过程中发起复位 |
| `mmu_error_rain_vseq` | 随机错误注入（bus err + illegal PTE + PMP deny） |
| `mmu_perf_bench_vseq` | 性能基准 |

### 6.3 Test Case 详表

> 预计 **120+ test case**。详见 §5 功能点表中的 `TC-Refs` 列 + §12 Traceability Matrix + CSV。每条 Test Case 格式：
>
> `| TC-ID | Test Class Name | Requirement | F-ID | Test Type | 主 Sequence | Checker/SB | 通过标准 |`

#### 6.3.1 L1 TLB Test Cases (ITLB / DTLB)

> 对应功能点：**L1 ITLB + L1 DTLB (F1, F2)**

#### 6.3.1 L1 TLB Test Cases

| TC-ID | Test Class | F-ID | Test Type | 主 Sequence | Checker | 通过标准 |
|-------|-----------|------|-----------|------------|---------|---------|
| ITLB_HIT_001 | sanity | F1.1, F1.3 | Directed | `ifu_base_seq` + 4K页表 | translation_sb | 取指PA正确，无pgflt |
| ITLB_HIT_002 | sanity | F1.3 | Directed | `ifu_sequential_fetch_seq` | translation_sb | 顺序取指PA+offset皆正确 |
| ITLB_PLRU_001 | directed | F1.1 | Directed | `ifu_random_vaddr_seq` (16+ VPN) | cov_ifu_rsp | 16个entry遍历后LRU替换 |
| ITLB_PLRU_002 | random | F1.1 | Constrained-Random | `ifu_random_vaddr_seq` × 100 seed | cg_itlb, sva_plru | 替换序列符合伪LRU规则 |
| ITLB_PERM_001 | directed | F1.2, F1.9 | Directed | VA→X=0 PTE构造 | translation_sb | 返回pgflt=1，deny=0 |
| ITLB_PERM_002 | directed | F1.2, F1.9 | Directed | U-mode取指U=0页面 + SUM/MXR组合 | translation_sb + cov_csr | 权限组合覆盖 |
| ITLB_PGFLT_001 | directed | F1.2 | Directed | V=0页面 | translation_sb | pgflt上报 |
| ITLB_HUGE_001 | directed | F1.4 | Directed | 2MB巨页VA(offset<21bit)→PA | translation_sb | offset保留，PA正确 |
| ITLB_HUGE_002 | directed | F1.5 | Directed | 1GB巨页VA(offset<30bit)→PA | translation_sb | offset保留，PA正确 |
| ITLB_HUGE_003 | random | F1.4, F1.5 | Constrained-Random | `ifu_huge_page_fetch_seq` × 50 seed | cg_huge_page | 2M/1G混合命中 |
| ITLB_ASID_001 | directed | F1.6 | Directed | G=1页面跨ASID切换后命中 | coherency_sb | TLB项跨ASID保留 |
| ITLB_ASID_002 | random | F1.6 | Constrained-Random | `cp0_satp_sel_toggle_seq` + G=0页 | coherency_sb | G=0页面在ASID切换后失效 |
| ITLB_REFILL_001 | directed | F1.7 | Directed | 无效→L2MISS→refill | translation_sb | refill后命中 |
| ITLB_REFILL_002 | random | F1.7 | Constrained-Random | `mmu_concurrent_3pipe_vseq` × 50 seed | sva_l2tlb_interface | refill速率满足credit |
| ITLB_ABORT_001 | directed | F1.8 | Directed | IFU abort→无stall | coherency_sb | abort后TLB无污染 |
| ITLB_FLUSH_001 | directed | F1.12 | Directed | RTU flush & IFU abort同时 | coherency_sb | abort优先于flush处理 |
| ITLB_INV_001 | directed | F1.10 | Directed | SFENCE.VMA全失效 | invalidation_sb | 所有TLB项失效 |
| ITLB_INV_002 | directed | F1.10 | Directed | SFENCE.VMA VA失效 | invalidation_sb | 指定VPN失效，其他保留 |
| ITLB_INV_003 | directed | F1.10 | Directed | SFENCE.VMA VA+ASID失效 | invalidation_sb | 组合失效精确匹配 |
| ITLB_PROBE_001 | directed | F1.11 | Directed | TLBP指令查询命中/未命中 | cov_software_ops | 探针结果正确 |
| DTLB_HIT_001 | sanity | F2.1, F2.4 | Directed | `lsu_base_seq` Pipe0 + 4K页表 | translation_sb | PA正确，无stall |
| DTLB_HIT_002 | sanity | F2.1, F2.4 | Directed | `lsu_base_seq` Pipe1 + 4K页表 | translation_sb | PA正确，无stall |
| DTLB_CONCURRENT_001 | directed | F2.1 | Directed | Pipe0/1同周期hit(同VPN/不同VPN) | cg_lsu_req, sva_dual_port | 双端口查询无冲突 |
| DTLB_CONCURRENT_002 | random | F2.1 | Constrained-Random | `lsu_pipe01_concurrent_seq` × 100 seed | cg_dtlb, sva_dual_port | 并发覆盖统计 |
| DTLB_ALLOC_001 | directed | F2.2 | Directed | 16个VPN miss→MB allocate→refill | cov_dtlb | 16个entry填满后替换 |
| DTLB_PLRU_001 | directed | F2.2 | Directed | MB_DEPTH=8时LRU替换 | cov_dtlb | 替换序列符合规则 |
| DTLB_MB_001 | directed | F2.3 | Directed | 8个并发miss请求 | sva_credit_conserv | MB无溢出，credit流控 |
| DTLB_MB_002 | random | F2.3 | Constrained-Random | `mmu_ptw_thrash_vseq` (8 MB满) × 50 seed | cg_scheduler, sva_credit | credit守恒 |
| DTLB_CREDIT_001 | directed | F2.3 | Directed | credit=0时新miss延迟 | sva_credit_conserv | stall触发 |
| DTLB_CREDIT_002 | random | F2.10 | Constrained-Random | Pipe0/1抢credit公平性 | cg_scheduler | 两路权重均衡 |
| DTLB_PERM_LD_001 | directed | F2.7 | Directed | load to R=0页面 | translation_sb | pgflt上报 |
| DTLB_PERM_LD_002 | directed | F2.7 | Directed | load + MXR=1到X=1 R=0页(X可读) | translation_sb | MXR使X可读 |
| DTLB_PERM_ST_001 | directed | F2.8 | Directed | store to W=0页面 | translation_sb | pgflt上报 |
| DTLB_PERM_ST_002 | directed | F2.8 | Directed | store触发D-bit更新 | invalidation_sb | D=0 PTE被置1 |
| DTLB_PMP_001 | directed | F2.9 | Directed | PA超PMP区间 | sva_pmp_interface | deny=1 |
| DTLB_SYSMAP_001 | directed | F2.9 | Directed | SysMap命中override TLB | translation_sb | SysMap优先级高 |
| DTLB_SCHED_001 | directed | F2.10 | Directed | Pipe0/1信用调度序列 | cg_scheduler | 两路取值无饿死 |
| DTLB_ABORT_001 | directed | F2.11 | Directed | LSU abort→TLB无污染 | coherency_sb | abort释放stall与MB |
| DTLB_REFILL_001 | directed | F2.12 | Directed | 无效→L2miss→refill | translation_sb | refill后命中 |
| DTLB_REFILL_002 | random | F2.12 | Constrained-Random | `mmu_concurrent_3pipe_vseq` × 50 seed | sva_l2_interface | Pipe2/STAMO并发refill |
| DTLB_INV_001 | directed | F2.13 | Directed | SFENCE.VMA全失效 | invalidation_sb | 所有DTLB项失效 |
| DTLB_INV_002 | directed | F2.13 | Directed | SFENCE.VMA VA失效 | invalidation_sb | 指定VPN失效 |
| DTLB_INV_003 | directed | F2.13 | Directed | SFENCE.VMA ASID失效 | invalidation_sb | ASID匹配失效 |
| DTLB_INV_004 | random | F2.13 | Constrained-Random | `mmu_sfence_during_walk_vseq` × 50 seed | invalidation_sb, sva_concurrent | 失效与PTW并发 |
| DTLB_STAMO_001 | directed | F2.14 | Directed | STAMO PA通报→MB无阻塞 | cg_lsu_req | STAMO旁路MB |
| STRESS_L1_001 | stress | F1.1, F2.1 | Constrained-Random | `mmu_stress_all_ports_vseq` (IFU+Pipe0/1/2) | perf_mon, cov_*_rsp | 全端口4K/2M/1G混合打满 |
| STRESS_L1_002 | stress | F2.3 | Constrained-Random | `mmu_ptw_thrash_vseq` × 100 seed | cg_dtlb, cg_scheduler | MB满+credit=0压力 |
| CROSSASID_001 | stress | F1.6, F2.13 | Constrained-Random | `mmu_asid_context_switch_vseq` × 50 seed | coherency_sb, cg_csr | ASID快速切换 |


---

#### 6.3.2 L2 TLB Test Cases

> 对应功能点：**L2 TLB / JTLB (F3)**

## § 6.3.2 L2 TLB Test Cases（35 条）

| TC-ID | Test Class Name | Requirement | F-ID | Test Type | 主 Sequence | Checker / SB | 通过标准 | Priority |
|-------|-----------------|-------------|------|-----------|-------------|--------------|--------|----------|
| **TC-L2TLB-001** | `test_mmu_dir_l2tlb_reqq_itlb_alloc` | ITLB miss → ReqQ 分配 entry 0 | F3.1 | Directed | `ifu_base_seq` + L2TLB 监控 | `translation_sb` | entry 0 valid，credit 回写 | P0 |
| **TC-L2TLB-002** | `test_mmu_dir_l2tlb_reqq_dtlb_alloc_0` | DTLB miss → ReqQ 分配 entry 1–3（FFZ） | F3.1 | Directed | `lsu_pipe01_concurrent_seq` | `translation_sb` | entry 1,2,3 valid，独立 credit | P0 |
| **TC-L2TLB-003** | `test_mmu_dir_l2tlb_reqq_dtlb_alloc_full` | ReqQ 满 9 entry → credit 不返回，miss 压力 | F3.1 | Directed | `lsu_back2back_seq` ×50 cyc | `translation_sb` + perf_mon | credit 计数正确；miss rate 飙升 | P0 |
| **TC-L2TLB-004** | `test_mmu_dir_l2tlb_reqq_arbitration_itlb_prior** | FFR：ITLB entry 优先于 DTLB entry 出队 | F3.2 | Directed | `ifu_random_vaddr_seq` + `lsu_base_seq` | `translation_sb` | ITLB req 先被 arbiter 处理 | P0 |
| **TC-L2TLB-005** | `test_mmu_dir_l2tlb_reqq_arbitration_fifo** | FFR：同一周期多 DTLB ready → 按优先级（entry 1 > 2 > ... > 8）出队 | F3.2 | Directed | `lsu_pipe01_concurrent_seq` ×多 seed | `translation_sb` + coverage | entry ready order 符合 FFR | P0 |
| **TC-L2TLB-006** | `test_mmu_rand_l2tlb_reqq_queue_depth_varied** | Random：ReqQ depth 0–9，random hit/miss/aging | F3.2 | Constrained-Random | `mmu_concurrent_3pipe_vseq` | `translation_sb` | 所有深度均覆盖，无死锁 | P1 |
| **TC-L2TLB-007** | `test_mmu_dir_l2tlb_reqq_credit_return_hit** | ReqQ credit：L2 hit 时立即返回 credit | F3.3 | Directed | 构造 L2 hit 序列 | `translation_sb` | credit 计数 +1 | P0 |
| **TC-L2TLB-008** | `test_mmu_dir_l2tlb_reqq_credit_return_refill** | ReqQ credit：PTW refill 完成时返回 credit | F3.3 | Directed | `mmu_ptw_thrash_vseq` | `translation_sb` | refill 后 credit 回 | P0 |
| **TC-L2TLB-009** | `test_mmu_dir_l2tlb_reqq_credit_full_no_return** | ReqQ 满时：新 miss 不分配 entry，credit 不返回（背压） | F3.3 | Directed | 高频 miss，9 depth 都满 | `translation_sb` | no new credit；下一个 refill 后才返回 | P0 |
| **TC-L2TLB-010** | `test_mmu_dir_l2tlb_tag_match_4k_hit** | L2 Tag match：4K 页 VPN+ASID+G 全匹配 → hit | F3.4 | Directed | 特定 VA 构造命中 | `translation_sb` | pavld 输出 | P0 |
| **TC-L2TLB-011** | `test_mmu_dir_l2tlb_tag_match_2m_1g_huge** | L2 Tag match：2M/1G 巨页，PGS 字段+高位 VPN 匹配 → hit | F3.4 | Directed | `ifu_huge_page_fetch_seq` + `lsu_huge_page_seq` | `translation_sb` | pavld；PPN 低位不参与比较 | P0 |
| **TC-L2TLB-012** | `test_mmu_rand_l2tlb_tag_match_cross_asid** | Tag match random：VPN 相同、ASID 不同 → miss；全匹配 → hit | F3.4 | Constrained-Random | `lsu_cross_asid_seq` + 构造 VA 冲突 | `translation_sb` | hit/miss 正确率 100% | P1 |
| **TC-L2TLB-013** | `test_mmu_dir_l2tlb_data_read_flags** | L2 Data read：flags（D/A/U/X/W/R）正确输出 | F3.5 | Directed | 特定 PTE 权限组合 | `translation_sb` | flags 与 page table 一致 | P0 |
| **TC-L2TLB-014** | `test_mmu_rand_l2tlb_data_bank_parallel_read** | Data 8 bank 并行读：无冲突，每 bank 独立输出 | F3.5 | Constrained-Random | `mmu_concurrent_3pipe_vseq` + bank hash 均衡 | `translation_sb` + perf_mon | read latency 恒定；无 stall | P1 |
| **TC-RRPV-001** | `test_mmu_dir_rrpv_init_value** | RRPV init = 4（= 7-3）；refill 时新 entry 的 RRPV 赋值 | F3.6 | Directed | 触发 refill，采样 RRPV 阵列 | `translation_sb` + RTL probe | RRPV 值 = 4 | P0 |
| **TC-RRPV-002** | `test_mmu_dir_rrpv_init_max_value_boundary** | RRPV MAX = 7；aging 时 +1 饱和 | F3.6 | Directed | 老化到 MAX，再 miss | `translation_sb` + RTL probe | RRPV ≤ 7（无溢出） | P0 |
| **TC-RRPV-003** | `test_mmu_rand_rrpv_init_all_ways_varied** | Random：8 ways 同时 refill，RRPV 全部 init = 4 | F3.6 | Constrained-Random | 快速 bank fill up | `translation_sb` + `l2tlb_bank_cg` | coverage：all ways filled | P1 |
| **TC-RRPV-004** | `test_mmu_dir_rrpv_hit_promote_to_zero** | Hit on RRPV>0 way → 该 way RRPV = 0；其它 ways 不变 | F3.7 | Directed | 特定 way hit（通过 VPN 构造） | `translation_sb` + RTL probe | hit way RRPV = 0；others unchanged | P0 |
| **TC-RRPV-005** | `test_mmu_dir_rrpv_multiple_hits_same_vpn** | Multiple hits in same cycle（多 pipe）→ 各自 promote 到 0 | F3.7 | Directed | `lsu_pipe01_concurrent_seq` 同一 VPN | `translation_sb` | 两个 pipe RRPV 都 = 0 | P1 |
| **TC-RRPV-006** | `test_mmu_rand_rrpv_hit_promote_coverage** | Random：hit 所有 RRPV 值（0–7）的 way → promote 到 0 | F3.7 | Constrained-Random | `mmu_rrpv_aging_vseq` | `l2tlb_bank_cg` | cross(initial_rrpv, promote) | P1 |
| **TC-RRPV-007** | `test_mmu_dir_rrpv_aging_miss_increment_all** | Miss → all valid ways RRPV +1（saturating）| F3.8 | Directed | 构造 miss，采样 RRPV | `translation_sb` + RTL probe | all ways RRPV = prev + 1 | P0 |
| **TC-RRPV-008** | `test_mmu_dir_rrpv_aging_saturation_at_max** | RRPV 已 MAX=7 再 miss → stay MAX，无溢出 | F3.8 | Directed | 老化至 MAX，再 miss | `translation_sb` | RRPV = 7（无 wrap） | P0 |
| **TC-RRPV-009** | `test_mmu_dir_rrpv_aging_mixed_hit_miss** | Sequential hit/miss：hit promote，miss aging，验证交替状态 | F3.8 | Directed | `mmu_rrpv_aging_vseq` | `translation_sb` + `l2tlb_bank_cg` | state machine 正确 | P0 |
| **TC-RRPV-010** | `test_mmu_dir_rrpv_victim_selection_first_free** | Victim select：8 ways 中有空闲 → 选空闲（first-free） | F3.9 | Directed | refill 时 VPN 各不相同 | `translation_sb` + RTL probe | victim_way_oh = first free | P0 |
| **TC-RRPV-011** | `test_mmu_dir_rrpv_victim_selection_max_rrpv** | Victim select：无空闲时 → 选 RRPV=MAX 的 way（first of max-RRPV ways） | F3.9 | Directed | bank 全满（8 ways），再 miss | `translation_sb` + RTL probe | victim = way with RRPV=7 | P0 |
| **TC-RRPV-012** | `test_mmu_rand_rrpv_victim_all_scenarios** | Random：victim selection 覆盖所有 mixed states（partial free、mixed RRPV） | F3.9 | Constrained-Random | `mmu_l2tlb_bank_conflict_vseq` | `l2tlb_bank_cg` + `mmu_l2tlb_sva` | cross(free_count, max_rrpv_ways) | P1 |
| **TC-RRPV-013** | `test_mmu_dir_rrpv_wbuf_latency** | RRPV wbuf：hit/aging 时更新先入 wbuf，T+1 写回阵列 | F3.12 | Directed | 采样 wbuf valid/data | `translation_sb` | wbuf 延迟 1 cycle；关键路径快 | P1 |
| **TC-RRPV-014** | `test_mmu_rand_rrpv_wbuf_no_overflow** | RRPV wbuf random：连续 hit/miss，wbuf 不溢出 | F3.12 | Constrained-Random | 高频 访问同一 bank | `translation_sb` + `mmu_l2tlb_sva` | no wbuf overflow event | P1 |
| **TC-BANK-001** | `test_mmu_dir_l2tlb_bank_skew_distribution** | Skew：同一 VPN 在 8 bank 的 8 set index 各不相同（hash 分散） | F3.10 | Directed | 特定 VPN 集合，观察 8 index | `translation_sb` + RTL probe | idx_w0 ≠ idx_w1 ≠ ... ≠ idx_w7 | P0 |
| **TC-BANK-002** | `test_mmu_rand_l2tlb_bank_load_balance** | Random：多 VPN set，8 bank 填充均衡（hash 有效性） | F3.10 | Constrained-Random | `mmu_concurrent_3pipe_vseq` ×many cyc | `l2tlb_bank_cg` | per-bank occupancy ≈ 1/8 total | P1 |
| **TC-BANK-003** | `test_mmu_rand_l2tlb_bank_collision_avoidance** | Random：低 bank conflict 率（hash 冲突概率）| F3.10 | Constrained-Random | `mmu_ptw_thrash_vseq` + stats | perf_mon | collision rate < 5% | P1 |
| **TC-BANK-004** | `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior** | Bank write conflict：PTW + ReqQ 同周期写同 bank → PTW 优先 | F3.11 | Directed | 构造 PTW refill + ReqQ lookup | `translation_sb` + RTL probe | PTW write 成功；ReqQ retry | P0 |
| **TC-BANK-005** | `test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior** | Bank write conflict：TLBOp 优于 ReqQ；记录 retry 请求 | F3.11 | Directed | SFENCE + pending ReqQ | `translation_sb` + RTL probe | SFENCE 成功；ReqQ stall | P0 |
| **TC-BANK-006** | `test_mmu_rand_l2tlb_bank_conflict_multi_source** | Random：PTW/TLBOp/ReqQ/PFU 4 源同时 bank 冲突 → arbiter 完全覆盖优先级 | F3.11 | Constrained-Random | `mmu_l2tlb_bank_conflict_vseq` | `mmu_arb_sva` + `l2tlb_bank_cg` | all 4-source priorities tested | P1 |
| **TC-MB-001** | `test_mmu_dir_l2tlb_mb_alloc_on_miss** | MB alloc：refill 时 FFZ 分配 entry（1 ITLB + 8 DTLB） | F3.13 | Directed | 触发 refill | `translation_sb` + RTL probe | mb_alloc_valid；entry_vld set | P0 |
| **TC-MB-002** | `test_mmu_dir_l2tlb_mb_dealloc_on_complete** | MB dealloc：PTW 完成时 MB entry 释放 | F3.13 | Directed | 等待 PTW 完成 | `translation_sb` + RTL probe | entry_vld clear；credit return | P0 |
| **TC-MB-003** | `test_mmu_dir_l2tlb_mb_dup_alloc_prevention** | MB dup prevention：同 VPN+ASID 已 pending → 新 miss 不分配，反向压力 | F3.13 | Directed | 快速重复同 VA | `translation_sb` + RTL probe | 2nd miss rejected；credit 不返 | P0 |
| **TC-MB-004** | `test_mmu_dir_l2tlb_mb_full_stall** | MB 8 entry 全满 → 新 miss 不分配，credit 不返（background pressure） | F3.13 | Directed | 8 个不同 VA 同时 pending | `translation_sb` + RTL probe | 第 9 个 miss 压力测试 | P0 |
| **TC-MB-005** | `test_mmu_rand_l2tlb_mb_issue_order** | MB issue order：多 pending entry FFR 选择，ITLB entry 优先 | F3.13 | Constrained-Random | `mmu_ptw_thrash_vseq` | `l2tlb_reqq_cg` | ITLB issue first | P1 |
| **TC-INV-001** | `test_mmu_dir_l2tlb_inv_all** | TLB inv：INVALL 清除所有 L2 entry（跨所有 bank/way） | F3.14 | Directed | 发 SFENCE.VMA with INV_ALL 语义 | `translation_sb` + RTL probe | all vld bits = 0 | P0 |
| **TC-INV-002** | `test_mmu_dir_l2tlb_inv_va** | TLB inv：INV_VA(vpn) 清除匹配 VPN 的所有 entry（跨 ASID） | F3.14 | Directed | SFENCE.VMA with VA，无 ASID | `translation_sb` + RTL probe | matching entries vld = 0；others unchanged | P0 |
| **TC-INV-003** | `test_mmu_dir_l2tlb_inv_asid** | TLB inv：INV_ASID(asid) 清除 asid 的所有 entry | F3.14 | Directed | SFENCE.VMA with ASID，无 VA | `translation_sb` + RTL probe | matching entries vld = 0 | P0 |
| **TC-INV-004** | `test_mmu_dir_l2tlb_inv_va_asid** | TLB inv：INV_VA_ASID(vpn,asid) 精确清除单一 entry | F3.14 | Directed | SFENCE.VMA with both VA+ASID | `translation_sb` + RTL probe | exact entry vld = 0 | P0 |

---

## § Traceability Matrix CSV（35 行 × 19 列）


---

#### 6.3.3 PTW + Arbiter Test Cases

> 对应功能点：**PTW + MMU Arbiter (F4, F5)**

## 段 2：测试用例详表

| TC-ID | 测试类名 | 所属 F-ID | 测试类型 | 主 Sequence | Checker/SB | 优先级 | 备注 |
|-------|---------|----------|---------|------------|----------|-------|------|
| PTW-001 | test_ptw_satp_load_basic | F4.1 | Directed | `ptw_mem_normal_rsp_seq` | translation_sb | P0 | SATP 根地址正确加载并用于 L2 页表检索 |
| PTW-002 | test_ptw_satp_load_dual_switch | F4.1 | Directed | `cp0_satp_switch_seq` | translation_sb | P0 | 双 SATP 切换，新 SATP 立即生效 |
| PTW-003 | test_ptw_l2_pde_hit_direct | F4.2 | Directed | `ptw_page_table_build_2m_seq` | ptw_walk_cg | P0 | L2 PDE cache hit 时绕过 LSU 读，直接获得中间 PPN |
| PTW-004 | test_ptw_l2_pde_miss_walk | F4.2 | Directed | `ptw_deep_tree_random_seq` | ptw_walk_cg | P0 | L2 PDE miss 触发 LSU 读，LSU 返回 L1 PTE |
| PTW-005 | test_ptw_l2_pde_cache_replace | F4.7 | Directed | `ptw_page_table_build_2m_seq` + cache invalidation | ptw_walk_cg | P1 | L2 PDE cache 满后替换策略验证 |
| PTW-006 | test_ptw_l1_pde_hit | F4.3 | Directed | `ptw_page_table_build_4k_seq` | ptw_walk_cg | P0 | L1 PDE cache hit，复用缓存 L1 中间 PPN |
| PTW-007 | test_ptw_l1_pde_miss_walk | F4.3 | Directed | `ptw_deep_tree_random_seq` | ptw_walk_cg | P0 | L1 PDE miss 继续读 L0 PTE |
| PTW-008 | test_ptw_l1_pde_cache_replace | F4.8 | Directed | 多次 L1 cache 填充 | ptw_walk_cg | P1 | L1 PDE cache 替换验证 |
| PTW-009 | test_ptw_l0_pte_read_basic | F4.4 | Directed | `ptw_page_table_build_4k_seq` | ptw_walk_cg | P0 | 三级完整 walk，L0 PTE 正确读取与 flag 提取 |
| PTW-010 | test_ptw_l0_pte_permission_check | F4.16 | Directed | `ptw_mem_illegal_pte_seq` | ptw_walk_cg | P0 | L0 PTE 权限位（X/W/R）与访问类型匹配验证 |
| PTW-011 | test_twu_concurrent_4way | F4.5 | Directed | 4 个 TWU 同时发起不同 VPN 的 walk | ptw_walk_cg | P0 | 4 TWU 无干扰并发运行 |
| PTW-012 | test_twu_concurrent_same_vpn | F4.5 | Directed | 多个 TWU 同时请求相同 VPN（不同端口或流） | ptw_walk_cg | P0 | MBUF 去重：仅一条 LSU 读，多 TWU 共用数据 |
| PTW-013 | test_mbuf_credit_management | F4.6 | Directed | MBUF 8 entry 填满后流控 | ptw_walk_cg | P0 | MBUF 满时阻塞新 TWU，满后解除正常流转 |
| PTW-014 | test_mbuf_ooo_response | F4.5 | Directed | `ptw_mem_ooo_rsp_seq` | ptw_walk_cg | P0 | LSU 乱序返回多个 PTE，MBUF 正确分发给对应 TWU |
| PTW-015 | test_pte_v_bit_zero | F4.9 | Directed | `ptw_mem_illegal_pte_seq` (V=0) | ptw_walk_cg | P0 | V=0 PTE 触发 page fault，walk 终止 |
| PTW-016 | test_pte_rw_both_zero | F4.10 | Directed | `ptw_mem_illegal_pte_seq` (R=W=0) | ptw_walk_cg | P0 | R∧W=0 触发 access fault |
| PTW-017 | test_pte_reserved_bits | F4.11 | Directed | `ptw_mem_illegal_pte_seq` (reserved != 0) | ptw_walk_cg | P1 | reserved bits 非零触发 access fault |
| PTW-018 | test_pte_misaligned_ppn_2m | F4.12 | Directed | 2M 巨页 PPN[0] != 0 | ptw_walk_cg | P1 | 巨页 PPN 对齐检查 |
| PTW-019 | test_pte_misaligned_ppn_1g | F4.12 | Directed | 1G 巨页 PPN[9:0] != 0 | ptw_walk_cg | P1 | 1G 巨页 PPN 低 10 位对齐检查 |
| PTW-020 | test_pte_u_bit_sum_interaction | F4.15 | Directed | User page, S mode, SUM=0/1 | ptw_walk_cg | P0 | U bit 与 SUM 权限交互 |
| PTW-021 | test_pte_x_bit_mxr_mix | F4.16 | Directed | X=1 R=0, MXR=0/1 | ptw_walk_cg | P0 | X bit 与 MXR 可执行读交互 |
| PTW-022 | test_pte_global_bit_asid | F4.17 | Directed | G=1 PTE，ASID 切换后 hit 验证 | translation_sb | P0 | G bit 导致 TLB 全局匹配（无 ASID 检查） |
| PTW-023 | test_huge_page_1g_direct | F4.18 | Directed | `ptw_page_table_build_1g_seq` | ptw_walk_cg | P0 | 1G 巨页 L1 hit，无需 L0 walk |
| PTW-024 | test_huge_page_2m_direct | F4.18 | Directed | `ptw_page_table_build_2m_seq` | ptw_walk_cg | P0 | 2M 巨页 L2 miss 但 L1 hit，skip L0 |
| PTW-025 | test_huge_page_4k_full_walk | F4.18 | Directed | `ptw_page_table_build_4k_seq` | ptw_walk_cg | P0 | 4K 页完整三级 walk |
| PTW-026 | test_huge_page_mixed | F4.19 | Directed | `mmu_huge_page_mix_vseq` | ptw_walk_cg | P0 | 1G / 2M / 4K 混合访问 |
| PTW-027 | test_satp_switch_during_walk | F4.20 | Directed | `mmu_satp_hotswap_vseq` | translation_sb | P0 | SATP 切换时 in-flight walk 行为（不自动失效） |
| PTW-028 | test_sfence_abort_walk | F4.21 | Directed | `mmu_sfence_during_walk_vseq` | ptw_walk_cg | P0 | SFENCE 触发 abort，in-flight walk 立即停止 |
| PTW-029 | test_bus_error_terminate | F4.22 | Directed | `ptw_mem_bus_error_inject_seq` | ptw_walk_cg | P0 | LSU bus_error 上报，walk 所有关联 TWU 获得错误信号 |
| PTW-030 | test_wakeup_vector_dispatch | F4.23 | Directed | LSU 响应后 wakeup[11:0] 触发 | ptw_walk_cg | P0 | wakeup 向量唤醒 L1 DTLB MB 对应 entry |
| PTW-031 | test_tlb_busy_stall | F4.24 | Directed | MBUF 满时 tlb_busy 拉起 | ptw_walk_cg | P0 | tlb_busy 流控整个 L1 DTLB 请求 |
| PTW-032 | test_pmp_deny_walk_abort | F4.25 | Directed | PMP 拒绝权限 | ptw_walk_cg | P0 | PMP 否决时 TWU 终止 walk，access fault 上报 |
| PTW-033 | test_sysmap_hit_bypass_walk | F4.26 | Directed | SysMap region hit | ptw_walk_cg | P0 | SysMap 命中绕过页表 walk 直接返回 PA |
| PTW-034 | test_satp_multi_switch_stress | F4.27 | Directed | `mmu_stress_all_ports_vseq` | ptw_walk_cg | P1 | 频繁双 SATP 切换压力测试 |
| TWU-001 | test_twu_idle_state | F4.5 | Directed | Power gate simulation | ptw_walk_cg | P0 | TWU idle 状态转移 |
| ARB-001 | test_arb_ptw_priority_highest | F5.1 | Directed | PTW + ReqQ + TLBOPER + Prefetch 并发 | arb_sva | P0 | PTW grant 优先级最高 |
| ARB-002 | test_arb_reqq_preempt_lower | F5.2 | Directed | ReqQ 优先级抢占 TLBOPER | arb_sva | P0 | ReqQ 优先级 > TLBOPER / Prefetch |
| ARB-003 | test_arb_tlboper_above_prefetch | F5.2 | Directed | TLBOper + Prefetch 并发 | arb_sva | P0 | TLBOper 优先级 > Prefetch |
| ARB-004 | test_arb_no_double_grant | F5.3 | Directed | 所有源同时 valid | arb_sva | P0 | 最多一个 grant 信号为 1 |
| ARB-005 | test_arb_work_conserving | F5.4 | Directed | 交替 grant 周期 | arb_sva | P0 | 有有效请求时不浪费 cycle |
| ARB-006 | test_arb_skew_index_generation | F5.5 | Directed | VPN 转换为 8 bank indices | arb_sva | P0 | 8 条 skew 索引独立生成无重复 |
| ARB-007 | test_arb_bank_conflict_resolution | F5.6 | Directed | 同一 VPN 多 bank 映射 | arb_sva | P1 | Bank 冲突自动检测与配置调整 |
| ARB-008 | test_arb_backpressure_mask | F5.7 | Directed | L2 busy 时 arb_ptw_mask=1 | arb_sva | P0 | 反压信号正确生成与清除 |
| XBAR-001 | test_xbar_1to4_distribution | F5.8 | Directed | PDE 请求分发到 idle TWU | arb_sva | P0 | xbar 扫描 idle 优先级与分发 |
| XBAR-002 | test_xbar_twu_round_robin | F5.8 | Directed | 多次 PDE 请求循环分发 | arb_sva | P0 | xbar 轮转分发 4 个 TWU |
| PDE-001 | test_pde_cache_l2_single_entry | F4.2, F4.7 | Directed | L2 PDE 写入与查询 | ptw_walk_cg | P0 | L2 单 entry cache 基础功能 |
| PDE-002 | test_pde_cache_l1_single_entry | F4.3, F4.8 | Directed | L1 PDE 写入与查询 | ptw_walk_cg | P0 | L1 单 entry cache 基础功能 |
| PDE-003 | test_pde_cache_clear_on_ptw_reset | F4.7, F4.8 | Directed | regs_ptw_clr 复位 | ptw_walk_cg | P0 | PDE cache 被 ptw_clr 正确清空 |
| SYSMAP-PTW-001 | test_sysmap_vs_ptw_priority | F4.26 | Directed | SysMap hit & TLB hit 同时存在 | sysmap_cg | P0 | SysMap 优先级 > TLB |
| SYSMAP-PTW-002 | test_sysmap_multi_region_coverage | F4.26 | Directed | `sysmap_region_setup_seq` × 8 region | sysmap_cg | P0 | 8 个 SysMap region 完整覆盖 |
| SYSMAP-PTW-003 | test_sysmap_no_walk_required | F4.26 | Directed | SysMap hit 时 LSU 无数据请求 | sysmap_cg | P0 | SysMap 命中真正绕过 walk（无 PTW 读） |
| PERF-PTW-001 | test_ptw_walk_latency | F4.1~F4.27 | Performance | Long random walk sequence | perf_mon | P1 | PTW 从请求到完成延迟统计 |
| PERF-ARB-001 | test_arb_throughput_max | F5.1~F5.8 | Performance | `mmu_stress_all_ports_vseq` | perf_mon | P1 | 仲裁最大吞吐量（issue/cycle） |
| RANDOM-PTW-001 | test_ptw_random_walk_10k_seed | F4.1~F4.27 | Constrained-Random | `mmu_ptw_thrash_vseq` × 10K | translation_sb | P0 | 随机 VPN / ASID / 权限组合 |
| RANDOM-ARB-001 | test_arb_random_priority_10k | F5.1~F5.8 | Constrained-Random | 4 源随机 valid 序列 | arb_sva | P1 | 随机优先级仲裁 10K 验证 |


---

#### 6.3.4 System-side Test Cases (SysMap / PMP / TLBOPER / CSR)

> 对应功能点：**SysMap + PMP + TLBOPER + CSR (F6-F9)**

## 段 2：§6.3 Test Case 详表（系统侧 TC，60 条）

| TC-ID | Test Class Name | Requirement | F-ID | Test Type | 主 Sequence | Checker/SB | 通过标准 |
|-------|---|---|---|---|---|---|---|
| **TC-SYSMAP-001** | test_mmu_sysmap_region_config | F6 SysMap 基配 | F6.1 | Directed | `sysmap_region_setup_seq` | translation_sb | 8 region 全覆盖；base_addr/mask 正确写入 |
| **TC-SYSMAP-002** | test_mmu_sysmap_region_default | F6 SysMap 默认值 | F6.1 | Directed | `sysmap_region_setup_seq` | translation_sb | 默认 region 配置与 sysmap.h 宏一致 |
| **TC-SYSMAP-003** | test_mmu_sysmap_hit_match | F6 region 匹配 | F6.2 | Directed | `sysmap_hit_cross_tlb_seq` | translation_sb | PA 落在 region 范围时 hit=1，否则 0 |
| **TC-SYSMAP-004** | test_mmu_sysmap_hit_boundary | F6 边界匹配 | F6.2, F6.9 | Directed | `sysmap_boundary_seq` | translation_sb | region 边界（base+mask）处的 hit 转折正确 |
| **TC-SYSMAP-005** | test_mmu_sysmap_hit_unique | F6 hit 唯一性 | F6.3 | Directed | `sysmap_hit_cross_tlb_seq` | translation_sb | 同一 PA 最多一个 region hit（priority 仲裁）|
| **TC-SYSMAP-006** | test_mmu_sysmap_priority | F6 region 优先级 | F6.4 | Directed | `sysmap_hit_cross_tlb_seq` | translation_sb | region 重叠时按 index 从小到大优先级 |
| **TC-SYSMAP-007** | test_mmu_sysmap_flag_r | F6 flag bit0 readable | F6.5 | Directed | `sysmap_perm_flag_seq` | translation_sb | flag[3]=1 表示可读权限；权限检查正确 |
| **TC-SYSMAP-008** | test_mmu_sysmap_flag_wxec | F6 flag 其他位组合 | F6.5 | Directed | `sysmap_perm_flag_seq` | translation_sb | flag 5-bit 全组合覆盖；权限判断与 flag 对应 |
| **TC-SYSMAP-009** | test_mmu_sysmap_priority_over_tlb | F6 SysMap > TLB | F6.6 | Directed | `sysmap_hit_cross_tlb_seq` | translation_sb | PA 同时命中 SysMap 和 TLB，SysMap flag 优先 |
| **TC-SYSMAP-010** | test_mmu_sysmap_tlb_fallback | F6 SysMap miss 回 TLB | F6.6 | Directed | `sysmap_hit_cross_tlb_seq` | translation_sb | PA 不命中 SysMap，使用 TLB/PTW 路径 |
| **TC-SYSMAP-011** | test_mmu_sysmap_pte_walk_addr | F6 PTE walk 地址保护 | F6.7 | Directed | `ptw_page_table_build_4k_seq` + sysmap | translation_sb + ptw_walk_cg | PTW 获取 PTE 时，PTE 地址命中 SysMap，返回 SysMap flag |
| **TC-SYSMAP-012** | test_mmu_sysmap_disabled | F6 region disable | F6.8 | Directed | `sysmap_region_setup_seq` | translation_sb | 配置 region enable=0，该 region 不产生 hit |
| **TC-SYSMAP-013** | test_mmu_sysmap_alignment | F6 4KB 对齐 | F6.9 | Directed | `sysmap_boundary_seq` | translation_sb | region base_addr 应 4KB 对齐；mask 为 2^n-1 形式 |
| **TC-PMP-001** | test_mmu_pmp_8port_concurrent | F7 8 port 并发 | F7.1 | Constrained-Random | `ptw_mem_ooo_rsp_seq` | ptw_walk_cg | 多 TWU 同时发起 walk，8 个 `mmu_pmp_pa{i}` 并发输出正确 |
| **TC-PMP-002** | test_mmu_pmp_port_independence | F7 port 独立性 | F7.1, F7.7 | Directed | `pmp_flg_cross_8port_seq` | pmp_cg | 每个 port 的 PA 与权限独立；一个 port 的 action 不影响其它 |
| **TC-PMP-003** | test_mmu_pmp_port_saturation | F7 8 port 饱和 | F7.1 | Constrained-Random | `ptw_mem_slow_rsp_seq` | ptw_walk_cg | 连续满载 8 port，PA 输出无丢失或重复 |
| **TC-PMP-004** | test_mmu_pmp_flg_encode | F7 flg 4-bit 编码 | F7.2 | Directed | `pmp_flg_normal_seq` | pmp_cg | `pmp_mmu_flg[i]` 的 4-bit 与权限编码一致（R/W/X/Reserved） |
| **TC-PMP-005** | test_mmu_pmp_flg_combinations | F7 flg 全组合 | F7.2 | Constrained-Random | `pmp_flg_cross_8port_seq` | pmp_cg | 覆盖 16 种 flg 组合在不同 port 上的应用 |
| **TC-PMP-006** | test_mmu_pmp_fetch_selective | F7 fetch 有选择输出 | F7.3 | Directed | `pmp_flg_deny_fetch_seq` | pmp_cg | 仅 port 3/5/6/7 产生 `mmu_pmp_fetch{i}` 脉冲；其它 port 无此信号 |
| **TC-PMP-007** | test_mmu_pmp_pa_correctness | F7 PA 输出正确性 | F7.4 | Directed | `ptw_mem_normal_rsp_seq` + pmp check | pmp_cg + ptw_walk_cg | `mmu_pmp_pa{i}` 与 PTW 内部 PTE req_addr 一致 |
| **TC-PMP-008** | test_mmu_pmp_pa_pipeline | F7 PA 时序跟踪 | F7.4 | Directed | `ptw_deep_tree_random_seq` | ptw_walk_cg | 多周期 walk 过程中，PA 随 walk level 正确变化 |
| **TC-PMP-009** | test_mmu_pmp_deny_access_fault | F7 PMP 拒绝异常 | F7.5 | Directed | `pmp_flg_deny_rw_seq` | pmp_cg + coherency_sb | `pmp_mmu_flg` 权限不足 → PTW access_fault，LSU 侧获得 fault 异常 |
| **TC-PMP-010** | test_mmu_pmp_deny_fetch_fault | F7 PMP 拒绝取指 | F7.5 | Directed | `pmp_flg_deny_fetch_seq` | pmp_cg | `mmu_pmp_fetch{i}=0` 时 IFU 侧拒绝取指，返回 deny/fault |
| **TC-PMP-011** | test_mmu_pmp_pa_alignment | F7 PA 对齐 | F7.6 | Directed | `ptw_mem_normal_rsp_seq` | ptw_walk_cg | `mmu_pmp_pa{i}[27:0]` 有效，高位为 0；与 PTE 格式一致 |
| **TC-PMP-012** | test_mmu_pmp_cross_port_deny | F7 port 之间互不影响 | F7.7 | Constrained-Random | `pmp_flg_cross_8port_seq` | pmp_cg | port 0 deny，port 1–7 仍可正常操作 |
| **TC-PMP-013** | test_mmu_pmp_port_config_independence | F7 port 配置独立 | F7.7 | Directed | `pmp_flg_normal_seq` | pmp_cg | 每个 PMP port 可独立配置权限，互不干扰 |
| **TC-PMP-014** | test_mmu_pmp_pde_cache_flow | F7 L1/L2 PDE 缓存 PMP | F7.8 | Directed | `ptw_mem_ooo_rsp_seq` | ptw_walk_cg | L1/L2 PDE cache hit 返回 PDE 后，仍走 PMP 检查 |
| **TC-SFENCE-001** | test_mmu_sfence_inv_all | F8 SFENCE.INVALL | F8.1 | Directed | `tlb_inv_all_seq` | invalidation_sb | `lsu_mmu_tlb_all_inv=1` 后全 TLB 条目失效 |
| **TC-SFENCE-002** | test_mmu_sfence_inv_all_lsu | F8 LSU 路径 INV_ALL | F8.1, F8.6 | Directed | `tlb_inv_all_seq` | invalidation_sb | LSU 发起 INV_ALL，`mmu_lsu_tlb_inv_done` 脉冲确认 |
| **TC-SFENCE-003** | test_mmu_sfence_inv_va | F8 SFENCE.VA 同 ASID | F8.2 | Directed | `tlb_inv_va_seq` | invalidation_sb | 指定 VPN，所有 ASID 下该 VPN 对应 entry 失效 |
| **TC-SFENCE-004** | test_mmu_sfence_inv_va_precise | F8 INV_VA 精确性 | F8.2 | Directed | `tlb_inv_va_seq` | invalidation_sb | 失效仅影响指定 VPN；其它 VPN 保留 |
| **TC-SFENCE-005** | test_mmu_sfence_inv_asid | F8 SFENCE.ASID | F8.3 | Directed | `tlb_inv_asid_seq` | invalidation_sb | 指定 ASID，该 ASID 下所有 entry 失效 |
| **TC-SFENCE-006** | test_mmu_sfence_inv_asid_global_skip | F8 global 页跳过 | F8.3, F8.5 | Directed | `tlb_inv_asid_seq` | invalidation_sb | G=1 页不被 INV_ASID 清除 |
| **TC-SFENCE-007** | test_mmu_sfence_inv_va_asid | F8 SFENCE.VA+ASID | F8.4 | Directed | `tlb_inv_va_asid_seq` | invalidation_sb | VPN+ASID 精确失效 |
| **TC-SFENCE-008** | test_mmu_sfence_inv_va_asid_multi_asid | F8 多 ASID 仅影响指定 | F8.4 | Directed | `tlb_inv_va_asid_seq` | invalidation_sb | VA+ASID 组合失效，其它 ASID 同 VA 保留 |
| **TC-SFENCE-009** | test_mmu_sfence_global_persist_invall | F8 global 与 INV_ALL | F8.5 | Directed | `tlb_inv_all_seq` | invalidation_sb | INV_ALL 可清除 global 页；INV_ASID/INV_VA_ASID 不能 |
| **TC-SFENCE-010** | test_mmu_sfence_global_va_affected | F8 global 与 INV_VA | F8.5 | Directed | `tlb_inv_va_seq` | invalidation_sb | INV_VA 能清除 global 页 |
| **TC-SFENCE-011** | test_mmu_sfence_lsu_trigger | F8 LSU 触发 | F8.6 | Directed | `tlb_inv_all_seq` + `tlb_inv_va_seq` | invalidation_sb | `lsu_mmu_tlb_*_inv` 信号有效触发失效 |
| **TC-SFENCE-012** | test_mmu_sfence_lsu_done_handshake | F8 LSU 握手 | F8.6, F8.8 | Directed | `tlb_inv_all_seq` | invalidation_sb | `mmu_lsu_tlb_inv_done` 在失效完成后 1 周期脉冲 |
| **TC-SFENCE-013** | test_mmu_sfence_cp0_trigger | F8 CP0 路径 | F8.7 | Directed | 由 `cp0_agent` 发起 | invalidation_sb | `cp0_mmu_tlb_all_inv` 触发 CP0 侧的全失效 |
| **TC-SFENCE-014** | test_mmu_sfence_concurrent_access_stall | F8 失效中并发访问 | F8.9 | Constrained-Random | `sfence_vma_stress_seq` | invalidation_sb | SFENCE 过程中新请求应等待或被 cancel |
| **TC-SFENCE-015** | test_mmu_sfence_back2back | F8 背靠背 SFENCE | F8.9 | Directed | `sfence_vma_stress_seq` | invalidation_sb | 多个 SFENCE 命令背靠背，均正确执行 |
| **TC-SFENCE-016** | test_mmu_sfence_during_walk | F8 walk 中被打断 | F8.10 | Directed | `tlb_inv_during_walk_seq` | invalidation_sb + ptw_walk_cg | in-flight walk 被 SFENCE 打断，walk cancel 或正确完成 |
| **TC-SFENCE-017** | test_mmu_sfence_refill_conflict | F8 失效与 refill 竞争 | F8.11 | Directed | `tlb_inv_all_seq` + `ptw_mem_normal_rsp_seq` 混合 | invalidation_sb + coherency_sb | 失效和 refill 同时发生，L2 TLB 状态一致 |
| **TC-TLBP-001** | test_mmu_tlbp_query_hit | F8 TLBP 查询 hit | F8.12 | Directed | 由 `cp0_agent` 发起 TLBP 请求 | coherency_sb | (VPN, ASID) 存在于 L2 TLB 时，TLBP 返回 hit=1 和正确 index |
| **TC-TLBP-002** | test_mmu_tlbp_query_miss | F8 TLBP 查询 miss | F8.12 | Directed | 由 `cp0_agent` 发起 TLBP 请求 | coherency_sb | (VPN, ASID) 不存在时，TLBP 返回 hit=0 |
| **TC-TLBR-001** | test_mmu_tlbr_read_entry | F8 TLBR 读条目 | F8.13 | Directed | 由 `cp0_agent` 发起 TLBR 请求 | coherency_sb | 读出指定 index 的 L2 TLB entry 内容正确 |
| **TC-TLBR-002** | test_mmu_tlbr_all_fields | F8 TLBR 全字段 | F8.13 | Directed | 由 `cp0_agent` 发起 TLBR 请求 | coherency_sb | 返回 VPN、ASID、PPN、flags、page size、global 位均正确 |
| **TC-TLBWI-001** | test_mmu_tlbwi_write_entry | F8 TLBWI 写条目 | F8.14 | Directed | 由 `cp0_agent` 发起 TLBWI 请求 | coherency_sb | 按指定 index 写入 L2 TLB entry，后续读出内容一致 |
| **TC-TLBWI-002** | test_mmu_tlbwi_overwrite | F8 TLBWI 覆写 | F8.14 | Directed | 由 `cp0_agent` 发起多次 TLBWI | coherency_sb | 覆写同一位置，新旧内容正确转换 |
| **TC-TLBWR-001** | test_mmu_tlbwr_random_replace | F8 TLBWR 随机替换 | F8.15 | Constrained-Random | 由 `cp0_agent` 发起 TLBWR 请求 | coherency_sb + l2tlb_rrpv_cg | RRPV 策略下随机替换一条 entry；新 entry 写入成功 |
| **TC-TLBWR-002** | test_mmu_tlbwr_rrpv_policy | F8 TLBWR 与 RRPV | F8.15 | Directed | 由 `cp0_agent` + `ptw_mem_agent` 配合 | coherency_sb + l2tlb_rrpv_cg | 多次 TLBWR 后，RRPV 老化行为正确反映 |
| **TC-CSR-001** | test_mmu_csr_satp_read | F9 SATP 读 | F9.1 | Directed | `cp0_reg_rw_seq` | csr_cg | 读 SATP 返回当前 PPN+ASID+MODE，`mmu_cp0_satp_data` 准确 |
| **TC-CSR-002** | test_mmu_csr_satp_read_both | F9 双 SATP 读 | F9.1 | Directed | `cp0_satp_sel_toggle_seq` | csr_cg | 切换 `satp_sel` 后读两份 SATP，内容互不影响 |
| **TC-CSR-003** | test_mmu_csr_satp_write | F9 SATP 写 | F9.2 | Directed | `cp0_reg_rw_seq` | csr_cg | 写 SATP 后读回，新值与写入一致 |
| **TC-CSR-004** | test_mmu_csr_satp_fields | F9 SATP 字段 | F9.3 | Directed | `cp0_reg_rw_seq` | csr_cg | MODE/ASID/PPN 字段独立；MODE=0 禁用 MMU |
| **TC-CSR-005** | test_mmu_csr_mode_disable | F9 MODE=0 disable | F9.3 | Directed | `cp0_reg_rw_seq` | csr_cg | MODE=0 设置后地址翻译失效，VA=PA passthrough（若支持） |
| **TC-CSR-006** | test_mmu_csr_mode_sv39 | F9 MODE=8 Sv39 | F9.3 | Directed | `cp0_reg_rw_seq` | csr_cg | MODE=8 启用 Sv39 分页 |
| **TC-CSR-007** | test_mmu_csr_dual_satp_sel | F9 SATP 选择 | F9.4 | Directed | `cp0_satp_sel_toggle_seq` | csr_cg | `satp_sel=0` 选 SATP0，`satp_sel=1` 选 SATP1 |
| **TC-CSR-008** | test_mmu_csr_satp_switch | F9 SATP 切换 | F9.4 | Directed | `cp0_satp_hotswap_vseq` | csr_cg + translation_sb | SATP0↔SATP1 热切换后，新 SATP 参与地址翻译 |
| **TC-CSR-009** | test_mmu_csr_satp_write_tlb_inval | F9 SATP 写后失效 | F9.5 | Directed | `cp0_reg_rw_seq` | csr_cg + invalidation_sb | 写新 SATP 后相关 TLB 自动清除或需显式 SFENCE |
| **TC-PRIV-001** | test_mmu_priv_mxr_impact | F9 MXR 权限 | F9.6 | Directed | `cp0_mxr_sum_cross_seq` | cross_scenario_cg | MXR=1 时执行页可读；MXR=0 时不可 |
| **TC-PRIV-002** | test_mmu_priv_mxr_fetch_denied | F9 MXR 不影响取指 | F9.6 | Directed | `cp0_mxr_sum_cross_seq` | cross_scenario_cg | 即使 MXR=1，无 X 权限仍拒绝取指 |
| **TC-PRIV-003** | test_mmu_priv_sum_impact | F9 SUM 权限 | F9.7 | Directed | `cp0_mxr_sum_cross_seq` | cross_scenario_cg | SUM=1 时 S mode 可访问 U 页；SUM=0 时不可 |
| **TC-PRIV-004** | test_mmu_priv_sum_m_mode | F9 SUM 不影响 M | F9.7 | Directed | `cp0_mxr_sum_cross_seq` | cross_scenario_cg | M mode 访问不受 SUM 影响 |
| **TC-PRIV-005** | test_mmu_priv_mprv_u_mode | F9 MPRV + MPP | F9.8 | Directed | `cp0_mprv_seq` | cross_scenario_cg | MPRV=1 时 M mode 数据访问使用 MPP 特权级 |
| **TC-PRIV-006** | test_mmu_priv_mprv_off | F9 MPRV=0 | F9.8 | Directed | `cp0_mprv_seq` | cross_scenario_cg | MPRV=0 时数据访问使用当前特权级（不受 MPP 影响） |
| **TC-PRIV-007** | test_mmu_priv_mode_u | F9 U mode | F9.9 | Directed | `cp0_priv_switch_seq` | cross_scenario_cg | U mode (priv_mode=0) 权限最低 |
| **TC-PRIV-008** | test_mmu_priv_mode_s | F9 S mode | F9.9 | Directed | `cp0_priv_switch_seq` | cross_scenario_cg | S mode (priv_mode=1) 权限中级；可访问 S/G 页 |
| **TC-CSR-010** | test_mmu_csr_ptw_disable | F9 PTW 禁用 | F9.10 | Directed | `cp0_ptw_disable_seq` | translation_sb + ptw_walk_cg | `ptw_en=0` 后 TLB miss 不启动 walk，返回 fault |
| **TC-CSR-011** | test_mmu_csr_no_op | F9 no_op_req | F9.11 | Directed | `cp0_no_op_seq` | coherency_sb | `no_op_req=1` 后新请求暂停；已 in-flight 请求继续 |
| **TC-CSR-012** | test_mmu_csr_maee | F9 maee 使能 | F9.12 | Directed | 由 `cp0_agent` 配置 | coherency_sb | `maee` 配置影响低功耗门控 |
| **TC-CSR-013** | test_mmu_csr_cskyee | F9 cskyee 配置 | F9.13 | Directed | 由 `cp0_agent` 配置 | coherency_sb | `cskyee` 配置应用与验证 |
| **TC-CSR-014** | test_mmu_csr_icg_enable | F9 ICG 使能 | F9.14 | Directed | 由 `cp0_agent` 配置 | coherency_sb | `icg_en=1` 所有时钟打开 |
| **TC-CSR-015** | test_mmu_csr_icg_disable | F9 ICG 禁用 | F9.14 | Directed | 由 `cp0_agent` 配置 | coherency_sb | `icg_en=0` 时钟门控启用 |
| **TC-CSR-016** | test_mmu_csr_complete_signal | F9 CSR 完成 | F9.15 | Directed | `cp0_reg_rw_seq` | csr_cg | `mmu_cp0_cmplt` 单周期脉冲表示操作完成 |

---


---

#### 6.3.5 Top-level Test Cases (Exception / Perf / Reset / Stress)

> 对应功能点：**Top-level / System-level (F10-F14)**

## § 6.3 Test Case 详表

| TC-ID | Test Class Name | 所属功能点 | Test Type | 主sequence | Checker/SB | 通过标准 | 优先级 |
|---|---|---|---|---|---|---|---|
| **异常相关测试** |
| EXC-001 | test_ifu_pgflt_v_bit_zero | F10.1 | Directed | `ifu_pagefault_trigger_seq` | pgflt_sb | `mmu_ifu_pgflt=1` 准确1拍 | P0 |
| EXC-002 | test_ifu_pgflt_user_priv_vio | F10.2 | Directed | `ifu_pagefault_trigger_seq` + priv=U | pgflt_sb | pgflt 因特权违规触发 | P0 |
| EXC-003 | test_ifu_pgflt_exec_deny | F10.3 | Directed | `ifu_pagefault_trigger_seq` | pgflt_sb | pgflt 因 X=0 触发 | P0 |
| EXC-004 | test_lsu_pgflt_store_pipe0 | F10.4 | Directed | `lsu_pipe0_seq` + store illegal | pgflt_sb | store pipe0 pgflt 正确 | P0 |
| EXC-005 | test_lsu_pgflt_load_pipe1 | F10.5 | Directed | `lsu_pipe1_seq` + load illegal | pgflt_sb | load pipe1 pgflt 正确 | P0 |
| EXC-006 | test_lsu_access_fault_pmp_deny | F10.6 | Directed | `pmp_flg_deny_fetch_seq` | access_fault_sb | PMP 拒绝触发 access_fault | P0 |
| EXC-007 | test_lsu_access_fault_bus_error | F10.7 | Error-Injection | `ptw_mem_bus_error_inject_seq` | access_fault_sb | bus_error 转化为 access_fault | P1 |
| EXC-008 | test_pipe2_prefetch_err | F10.8 | Directed | `lsu_prefetch_pipe2_seq` + error trigger | prefetch_sb | pa2_err 脉冲正确 | P1 |
| EXC-009 | test_bad_vpn_record_accuracy | F10.9 | Directed | multiple pgflt triggers + RTU | pgflt_sb | bad_vpn[26:0] 与异常 VPN 一致 | P0 |
| EXC-010 | test_expt_vld_mb_cleanup | F10.10 | Directed | `ptw_mem_bus_error_inject_seq` + MB full | mb_sb | expt_vld=1 时 MB entry 清理 | P0 |
| EXC-011 | test_rtu_flush_all_pending | F10.11 | Directed | concurrent + rtu_yy_xx_flush | reqq_sb | flush 时所有 ReqQ pending 清理 | P0 |
| EXC-012 | test_sec_deny_during_fault | F10.12 | Constrained-Random | mixed concurrent | pgflt_sb | sec/deny 位在异常时保持 | P1 |
| EXC-013 | test_concurrent_exc_priority | F10.13 | Error-Injection | concurrent IFU/LSU/Pipe2 faults | exception_arb_sb | 优先级唯一、不冲突 | P1 |
| EXC-014 | test_recovery_after_exception | F10.14 | Directed | fault trigger → recovery → normal | recovery_sb | 异常恢复后 TLB 正常工作 | P1 |
| **性能计数相关** |
| PERF-001 | test_iutlb_miss_pulse_1to1 | F11.1, F11.2 | Directed | `ifu_random_vaddr_seq` | perf_mon_sb | iutlb_miss 脉冲与 miss 1:1 | P0 |
| PERF-002 | test_iutlb_miss_gated_by_cnt_en | F11.1, F11.7 | Directed | cnt_en toggle | perf_mon_sb | cnt_en=0 时无脉冲 | P0 |
| PERF-003 | test_dutlb_miss_pipe0_counted | F11.3 | Directed | `lsu_pipe0_seq` + miss trigger | perf_mon_sb | pipe0 miss 计数准确 | P0 |
| PERF-004 | test_dutlb_miss_pipe1_counted | F11.4 | Directed | `lsu_pipe1_seq` + miss trigger | perf_mon_sb | pipe1 miss 计数准确 | P0 |
| PERF-005 | test_jtlb_miss_counted | F11.5 | Directed | L2 TLB miss trigger | perf_mon_sb | jtlb_miss 脉冲正确 | P0 |
| PERF-006 | test_concurrent_miss_pulses | F11.6 | Constrained-Random | `mmu_concurrent_3pipe_vseq` | perf_mon_sb | 并发 miss 脉冲不丢失 | P1 |
| PERF-007 | test_perf_under_stress | F11.8 | Constrained-Random | `mmu_stress_all_ports_vseq` + cnt_en | perf_mon_sb | 压力下计数仍准确 | P2 |
| **低功耗/DFT 相关** |
| PWR-001 | test_icg_en_clock_stop | F12.1 | Directed | icg_en toggle | clock_mon_sb | icg_en=0 时时钟停止 | P1 |
| PWR-002 | test_icg_en_normal_work | F12.2 | Directed | normal operation + icg_en=1 | function_sb | icg_en=1 时功能正常 | P0 |
| PWR-003 | test_scan_en_force_clock | F12.3 | Directed | scan_en=1 | clock_mon_sb | scan_en=1 强制时钟打开 | P1 |
| PWR-004 | test_smp_disable_snoop | F12.4 | Directed | smp_disable toggle | snoop_sb | smp_disable=1 时关闭 snoop | P2 |
| PWR-005 | test_clock_gating_transition | F12.5 | Directed | icg on/off sequence | clock_mon_sb | 时钟门控转换无毛刺 | P1 |
| **复位相关测试** |
| RST-001 | test_cpurst_b_async_assert | F13.1 | Directed | async reset pulse | reset_sb | 复位异步断言正确 | P0 |
| RST-002 | test_tlb_invalid_after_reset | F13.2 | Directed | reset → release → check | tlb_valid_sb | 复位后 TLB 全无效 | P0 |
| RST-003 | test_reg_default_values | F13.3 | Directed | reset → read regs | reg_sb | SATP=0, priv=M mode 等 | P0 |
| RST-004 | test_reset_during_ptw_walk | F13.4 | Directed | PTW walk → async reset | ptw_recovery_sb | walk 中止，TWU FSM → IDLE | P1 |
| RST-005 | test_reset_during_response | F13.5 | Directed | response pipeline → reset | resp_sb | 响应中止无错误 | P1 |
| RST-006 | test_reset_output_no_x | F13.6 | Directed | reset monitor | x_monitor | 复位期间输出无 X | P1 |
| RST-007 | test_mmu_en_after_reset | F13.7 | Directed | reset → release → check mmu_en | mmu_en_sb | mmu_xx_mmu_en 指示正确 | P1 |
| RST-008 | test_reset_immediate_operation | F13.8 | Directed | reset → immediate request | function_sb | 复位后立即可工作 | P0 |
| **压力与综合** |
| STRESS-001 | test_3pipe_concurrent_max_rate | F14.1 | Constrained-Random | `mmu_stress_all_ports_vseq` | arb_sb | 3 pipe 打满无死锁 | P1 |
| STRESS-002 | test_l2tlb_saturated_mb_full | F14.2 | Constrained-Random | L2 full setup | l2_sb | L2+MB 饱和功能正常 | P1 |
| STRESS-003 | test_l2_bank_conflict_and_reqq_full | F14.3 | Constrained-Random | 8 bank conflict scenario | l2_sb | bank 冲突+ReqQ 满可恢复 | P2 |
| STRESS-004 | test_ptw_4tws_full_wakeup_dense | F14.4 | Constrained-Random | `mmu_ptw_thrash_vseq` | ptw_sb | 4 TWU+MB 满，wakeup 正确 | P1 |
| STRESS-005 | test_satp_hotswap_concurrent | F14.5 | Constrained-Random | `mmu_satp_hotswap_vseq` | satp_sb | SATP 热切换无中断 | P1 |
| STRESS-006 | test_sfence_high_frequency | F14.6 | Constrained-Random | `mmu_sfence_during_walk_vseq` | inv_sb | 高频 SFENCE 无死锁 | P1 |
| STRESS-007 | test_asid_thrashing | F14.7 | Constrained-Random | `mmu_asid_context_switch_vseq` | asid_sb | 多 ASID 切换 hit rate 恢复快 | P1 |
| STRESS-008 | test_huge_4k_page_mix | F14.8 | Constrained-Random | `mmu_huge_page_mix_vseq` | page_size_sb | 1G/2M/4K 混合替换正确 | P1 |
| STRESS-009 | test_100k_txn_stable_run | F14.9 | Constrained-Random | `mmu_stress_all_ports_vseq` + 100K seed | txn_sb | 100K+ 事务无死锁/数据错 | P0 |
| STRESS-010 | test_error_rain_mixed_fault | F14.10 | Error-Injection | `mmu_error_rain_vseq` | error_sb | random bus_error + illegal PTE | P1 |
| STRESS-011 | test_rrpv_aging_replacement | F14.11 | Constrained-Random | `mmu_rrpv_aging_vseq` | replace_sb | RRPV 替换在高 miss 下正确 | P2 |
| STRESS-012 | test_reset_mid_transaction | F14.12 | Error-Injection | `mmu_reset_midtransaction_vseq` | mid_txn_sb | mid-transaction 复位恢复正确 | P1 |
| STRESS-013 | test_power_gating_sequence | F14.13 | Directed | `mmu_power_gating_vseq` | power_sb | 门控序列无异常 | P2 |


### 6.4 回归套件编组

| 套件 | 运行频率 | 包含范围 | 预计时长 | 通过标准 |
|------|---------|---------|---------|---------|
| `smoke` | 每次 commit（CI 钩子） | ~20 条 P0 sanity + 主 directed | < 30 min（8 核并行） | 100% 通过 |
| `nightly_full` | 每晚一次 | 所有 Test Case × 5 seed | < 8 h | 100% 通过 |
| `weekly_coverage` | 每周 | 随机 sequences × 10K seed（coverage 收敛） | < 48 h | 不回归指标 |
| `gls_zero_delay` | 版本冻结前 | smoke + 关键 directed | - | 100% 通过 |
| `gls_sdf` | 最终签核前 | 关键 smoke | - | 100% 通过（可选） |

### 6.5 Gap-Driven 新增 Test Case 一览（v2.0 补充）

> 来源：[doc/MMU_GapAudit_v1.md](MMU_GapAudit_v1.md) 165 条 gap → 60 个新 TC（**仅声明**；详细 stimuli/checker 见 §12 / CSV）

| TC-ID | 对应 F-ID | Type | Sequence | Prio |
|---|---|---|---|---|
| TC-GAP-ITLB-001 (`ITLB_PLRU_RST_001`) | F1.14 | Directed | `ifu_random_vaddr_seq` + reset hook | P0 |
| TC-GAP-ITLB-002 (`ITLB_INV_VA8_alias_001`) | F1.10b | Directed | `tlb_inv_va_seq` (VPN[7:0] alias) | P0 |
| TC-GAP-ITLB-003 (`ITLB_REFILL_INV_RACE_001`) | F1.15 | Directed | `tlb_inv_during_walk_vseq` | P1 |
| TC-GAP-ITLB-004 (`ITLB_PLRU_HIT_REFILL_001`) | F1.16 | Directed | hit+refill seq | P1 |
| TC-GAP-ITLB-005 (`ITLB_FST_MIX_001`) | F1.13 | Directed | `ifu_huge_page_fetch_seq` mix | P1 |
| TC-GAP-ITLB-006 (`ITLB_PGS_MISMATCH_001`) | F1.17 | Error | err inject | P1 |
| TC-GAP-ITLB-007 (`ITLB_ABORT_REFILL_001`) | F1.18 | Directed | `ifu_abort_seq` mid-refill | P1 |
| TC-GAP-DTLB-001 (`DTLB_MB_FSM_WFI_001`) | F2.3 | Directed | mb_wfi seq | P0 |
| TC-GAP-DTLB-002 (`DTLB_INSTALL_ARB_001`) | F2.15 | Directed | install_priority seq | P0 |
| TC-GAP-DTLB-003 (`DTLB_ALLOC_FULL_001`, `DTLB_ALLOC_RACE_001`) | F2.16 | Stress | full+race seq | P0 |
| TC-GAP-DTLB-004 (`DTLB_CREDIT_BOUND_001`) | F2.10 | Directed | credit boundary seq | P0 |
| TC-GAP-DTLB-005 (`DTLB_STAMO_PIPE0_001`, `DTLB_STAMO_PIPE1_NEG_001`) | F2.14 | Directed | stamo pipe asym seq | P0 |
| TC-GAP-DTLB-006 (`DTLB_WAKEUP_BCAST_001`) | F2.17, F4.23 | Directed | wakeup_broadcast seq | P0 |
| TC-GAP-DTLB-007 (`DTLB_BUSY_THRESHOLD_001`) | F2.18 | Directed | mb_full seq | P1 |
| TC-GAP-DTLB-008 (`DTLB_MB_PGFLT_001`, `DTLB_MB_ABT_LATE_REFILL_001`) | F2.20 | Directed/Error | abt_late_refill seq | P1 |
| TC-GAP-DTLB-009 (`DTLB_INSTALL_ID_CHK_001`) | F2.21 | SVA | sva trigger | P1 |
| TC-GAP-DTLB-010 (`DTLB_HUGE_MIX_001`, `DTLB_DUAL_HIT_MUX_001`) | F2.22 | Directed | huge mix dual-hit seq | P1 |
| TC-GAP-DTLB-011 (`DTLB_HIT_MISS_CONCURRENT_001`) | F2.19 | Directed | pipe01 mixed hit/miss | P1 |
| TC-GAP-L2-001 (`TC-HASH-001~003`, `TC-HASH-DOC-001`) | F3.15, F5.10 | Directed | hash dist seq | P0 |
| TC-GAP-L2-002 (`TC-SRAM-RST-001`) | F3.17, F13.9 | Directed | reset seq | P0 |
| TC-GAP-L2-003 (`TC-RRPV-WBUF-001~003`) | F3.18 | Directed | wbuf bypass seq | P0 |
| TC-GAP-L2-004 (`TC-RRPV-FULL-001`) | F3.19 | Directed | wbuf full seq | P1 |
| TC-GAP-L2-005 (`TC-RRPV-VICTIM-001~003`) | F3.20 | Directed | victim corner seq | P1 |
| TC-GAP-L2-006 (`TC-PPLRU-RST-001`, `TC-PPLRU-ONEHOT-001`) | F3.21, F4.41 | Directed | pplru seq | P1 |
| TC-GAP-L2-007 (`TC-REQQ-FSM-001`, `TC-REQQ-BYPASS-001`, `TC-REQQ-RETRY-001`, `TC-REQQ-FFZ-001`, `TC-REQQ-ITLB-DTLB-001`) | F3.22, F3.23, F3.24 | Directed | reqq seq | P0 |
| TC-GAP-L2-008 (`TC-MB-SFENCE-ABORT-001`, `TC-MB-DEDUP-001`, `TC-MB-FFZ-BIAS-001`, `TC-MB-DEALLOC-RACE-001`) | F3.25, F3.26, F3.27 | Directed | mb seq | P0 |
| TC-GAP-L2-009 (`TC-REFILL-ATOMIC-001`, `TC-INV-REFILL-RACE-001`) | F3.28, F3.29 | SVA | atomic refill | P0 |
| TC-GAP-L2-010 (`TC-L2-LATENCY-001`, `TC-ARB-MASK-001`, `TC-ARB-WC-001`, `TC-ARB-PRIO-001`, `TC-ARB-BANK-MASK-001`, `TC-ARB-BP-LAT-001`) | F3.30~33, F5.11~12, F5.15 | Directed | arb seq | P1 |
| TC-GAP-L2-011 (`TC-FPGA-ASIC-EQ-001/002`, `TC-SRAM-CROSS-001`, `TC-RST-VLD-CLR-001`, `TC-SRAM-RAW-001`, `TC-SRAM-WEN-001`, `TC-SRAM-WEN-BIT-001`) | F3.34~36, F3.16, F13.10, F13.13 | Directed | sram seq | P1 |
| TC-GAP-L2-012 (`TC-XBAR-IDLE-001`, `TC-XBAR-ABORT-001`, `TC-XBAR-FALLBACK-001`, `TC-XBAR-DISPATCH-ABORT-001`, `TC-XBAR-FAIR-001`, `TC-XBAR-DRAIN-001`, `TC-XBAR-MASK-LAT-001`) | F3.37, F4.51, F4.52, F5.13, F5.14 | Directed | xbar seq | P1 |
| TC-GAP-L2-013 (`TC-LP-GATING-001`, `TC-DFT-SRAM-001`, `TC-DFT-SCAN-001`, `TC-DFT-BIST-001`, `TC-HASH-DIST-001`, `TC-ICG-LATCH-001`) | F3.38, F3.39, F3.40, F12.6, F12.7, F12.8 | Directed | lp/dft seq | P2 |
| TC-GAP-PTW-001 (`TC-TWU-CSR-FSM-001`, `TC-TWU-CSR-REFILL-001`, `TC-TWU-DATA-RDY-001`) | F4.28, F4.29, F4.30 | Directed | twu fsm seq | P1 |
| TC-GAP-PTW-002 (`TC-PMBUF-FFZ-001`, `TC-PMBUF-RR-001`, `TC-PMBUF-ITLB-SLOT-001`, `TC-PMBUF-MULTI-TWU-001`, `TC-PMBUF-DEDUP-001`, `TC-PMBUF-WB-FAIR-001`) | F4.31~34, F4.36, F4.37 | Directed | pmbuf seq | P0 |
| TC-GAP-PTW-003 (`TC-MBUF-FSM-001`) | F4.35 | SVA | sva | P1 |
| TC-GAP-PTW-004 (`TC-PDE-ASID-STALE-001`, `TC-PDE-MUX-001`, `TC-PDE-CLR-001`) | F4.38, F4.39, F4.40 | Directed | pde stale seq | P0 |
| TC-GAP-PTW-005 (`TC-PMBUF-LSU-CHN-001`, `TC-PMBUF-MULTI-RESP-001`, `TC-PMBUF-NO-DEADLOCK-001`) | F4.42, F4.43, F4.44 | Directed | lsu chn seq | P0 |
| TC-GAP-PTW-006 (`TC-TWU-ADDR-BOUND-001`) | F4.45 | Directed | addr bound seq | P2 |
| TC-GAP-PTW-007 (`TC-AD-A-PGFLT-001`, `TC-AD-D-PGFLT-001`, `TC-AD-TRAP-ONLY-001`) | F4.13, F4.14, F4.46 | Directed | A/D trap seq | P0 |
| TC-GAP-PTW-008 (`TC-PTW-ABORT-001`, `TC-PTW-ABORT-BCAST-001`, `TC-PMBUF-BUSERR-FAIR-001`) | F4.47, F4.48, F4.49 | Error | abort/buserr seq | P0 |
| TC-GAP-PTW-009 (`TC-SATP-WALK-CONSIST-001`) | F4.50 | Directed | satp walk seq | P1 |
| TC-GAP-PTW-010 (`TC-PTW-BUSY-CONSIST-001`, `TC-PTW-WATCHDOG-001`) | F4.53 | Stress | watchdog seq | P1 |
| TC-GAP-PTW-011 (`TC-PMP-MIDWALK-001`, `TC-SYSMAP-MIDWALK-001`) | F4.54 | Directed | midwalk seq | P1 |
| TC-GAP-PTW-012 (`TC-PTE-RSW-001`, `TC-MBUF-MULTI-LEVEL-001`, `TC-CSR-REFILL-PRIO-001`) | F4.55 | Directed | rsw/multi-level seq | P1 |
| TC-GAP-PTW-013 (`TC-WAKEUP-BCAST-001`) | F4.23 | Directed | wakeup_broadcast seq | P0 |
| TC-GAP-SYS-001 (`TC-SYSMAP-MIX-PG-001`, `TC-SYSMAP-8PORT-001`, `TC-SYSMAP-PRIO-001`, `TC-SYSMAP-DEFAULT-001`, `TC-SYSMAP-EDGE-001`, `TC-SYSMAP-WIDTH-001`, `TC-SYSMAP-MEL-ALIGN-001`, `TC-SYSMAP-DISABLE-001`, `TC-SYSMAP-ALIGN-001`) | F6.10~16 | Directed | sysmap seq | P1 |
| TC-GAP-SYS-002 (`TC-PMP-FETCH-NONSYM-001`, `TC-PMP-PTW-MAP-001`, `TC-PMP-PA-CONSIST-001`, `TC-PMP-INDEP-001`, `TC-PMP-PDE-CACHE-001`) | F7.3, F7.9~12 | Directed | pmp seq | P1 |
| TC-GAP-SYS-003 (`TC-SFENCE-MIX-PG-001`, `TC-TLBOPER-CNT-001`, `TC-SFENCE-B2B-001`, `TC-SFENCE-ABORT-PULSE-001`, `TC-TLBOPER-SERIALIZE-001`, `TC-TLBWR-FSM-001`, `TC-INVVA-XPG-001`, `TC-TLBR-ASID-G-001`) | F8.2, F8.16~22 | Directed | tlboper seq | P0 |
| TC-GAP-SYS-004 (`TC-CSR-MODE-ILLEGAL-001`, `TC-CSR-PARTIAL-WR-001`, `TC-MCIR-NOOP-001`, `TC-SATP-UTLB-CLR-001`, `TC-MIR-MEL-MEH-001`, `TC-SATP-PTW-HAZARD-001`, `TC-CSR-TLBOPER-HAZARD-001`, `TC-MPRV-MUX-001`, `TC-CSR-RST-DEFAULT-001`) | F9.3, F9.16~22 | Directed | csr seq | P0 |
| TC-GAP-TOP-001 (`TC-MMU-EN-DUAL-001`) | F10.15 | Directed | mmu_en seq | P0 |
| TC-GAP-TOP-002 (`TC-DBG-INFO-001`, `TC-IFU-ABT-MIDMISS-001`, `TC-LSU-ABT-INFLIGHT-001`) | F10.16, F10.17 | Directed | abt seq | P1 |
| TC-GAP-TOP-003 (`TC-STAMO-BYPASS-001`) | F10.18 | Directed | stamo bypass seq | P0 |
| TC-GAP-TOP-004 (`TC-PIPE2-ATTR-001`, `TC-VABUF-PROTO-001`) | F10.19, F10.20 | Directed | pipe2 attr seq | P1 |
| TC-GAP-TOP-005 (`TC-3PIPE-MISS-001`, `TC-CREDIT-DEADLOCK-001`, `TC-EXC-PRIO-001`) | F10.21, F10.22 | Stress | concurrency seq | P1 |
| TC-GAP-TOP-006 (`TC-HPCP-PULSE-001`, `TC-HPCP-JTLB-DEF-001`, `TC-HPCP-CONCUR-001`, `TC-HPCP-STRESS-001`, `TC-DUTLB-DBG-ST-001`, `TC-TWU-PORT-MAP-001`) | F11.9~14 | Directed | hpcp seq | P1 |
| TC-GAP-TOP-007 (`TC-RST-SEQ-001`, `TC-RST-MIDWALK-001`, `TC-RST-MB-CLR-001`) | F13.11, F13.12 | Reset | reset seq | P1 |
| TC-GAP-TOP-008 (`TC-BYPASS-ATTR-001`, `TC-SATP-HOTSWAP-001`, `TC-PRIV-RACE-001`, `TC-CSR-CMPLT-PROTO-001`, `TC-BADVPN-COND-001`) | F14.14~17 | Directed | bypass seq | P0 |
| TC-GAP-TOP-009 (`TC-PTW-LSU-PROTO-001`) | F14.18 | Directed | ptw lsu proto seq | P0 |
| TC-GAP-TOP-010 (`TC-PARAM-WRAP-001`, `TC-AGE-CMP-001`, `TC-ASID-PROTO-001`, `TC-MB-BYPASS-PRIO-001`, `TC-DUAL-HIT-PLRU-001`) | F14.19, F14.20 | Constrained-Random | param wrap seq | P1 |
| TC-BUG-001 | F4.NEW.2 | **Functional**（v3.0 证伪改判：原疑似跨级 fetch_type 错用经 RTL 二次核对确认 fst/scd/thd 各级 `*_pmp_fetch_type` 字段独立，非缺陷） | fst=fetch scd=store 跨级权限场景覆盖；验证三级权限独立传递 | **P1** |
| TC-BUG-002 | F4.NEW.3 | **Functional**（v3.0 证伪改判：thd_chk 必为叶 PTE，A-bit 检测正常执行，非缺陷） | 4K/2M/1G × A=0/1 thd_chk_page_flt 正向覆盖；期望 A=0 触发 page fault | **P1** |
| TC-BUG-003 | F4.NEW.1 | **Functional**（v3.0 证伪改判：thd_chk 必为叶 PTE，`thd_chk_refill_req` 只要不触异常即可发出；PDE Cache 非叶限制仅约束 `mbuf_cache_upd`，两者不矛盾） | 叶 PTE refill 不触异常路径正向覆盖；验证 mbuf_cache_upd 仅非叶 PTE 触发 | **P1** |
| TC-BUG-004 | F5.NEW.1 | **Functional**（v3.0 证伪改判：RTL L142 `8'b00110011` 字面量前缀完整，非缺陷） | selector=00/01/10/11 时 8-bit bank mask 字面量编码覆盖（正向） | **P1** |
| TC-BUG-005 | F3.4 | BUG_HUNT（真实缺陷，v3.0 升 P0） | `mmu_l2tlb.sv#L456` `raw_vld = pipe_vld \|\| ptw_req`（`\|\|` 应为 `&&`）使 PTW 写周期误触 tag compare hit | P0 |
| TC-BUG-006 | F3.5 | BUG_HUNT（真实缺陷，v3.0 升 P0） | `mmu_l2tlb.sv#L512` `arb_l2tlb_is_dtlb` 判断重复 `3'b010` 两次且漏 store type `3'b110`；构造 store miss 验证 | P0 |
| TC-BUG-007 | F3.NEW.1 | BUG_HUNT（真实缺陷，v3.0 升 P0） | SFENCE/INVVA 无效 L2 entry 后 RRPV 残留；连续 INVVA + 新 refill 验证 victim 选择受旧 RRPV 污染 | P0 |
| TC-BUG-008 | F12.NEW.1 | BUG_HUNT（真实缺陷，v3.0 升 P0） | pplru entry 0 首次命中 `hit_num_flop==0` 不触发 PLRU 更新；复位后 entry 0 多次命中 victim 公平性验证 | P0 |
| ~~TC-BUG-009~~ | ~~F4.NEW.2~~ | **【v3.0 删除】** 经 RTL 核对 `twu.sv` CSR Arbiter case 分支为 `2'b01/2'b10`，**不存在重复** → 取消此 TC（编号保留空位以追溯 v2→v3 演化） | — | — |
| ~~TC-BUG-010~~ | ~~F4.NEW.2~~ | **【v3.0 删除】** 经 RTL 核对 `twu.sv` L1056-L1063 CSR FSM IDLE 分支已有 `else ptw_nxt_st = TWU_IDLE`，**无 latch 推断风险** → 取消此 TC | — | — |
| TC-BUG-011 | F4.NEW.4 | **BUG_HUNT（v3.0 新增 P0 高危）** | 构造 2MB 巨页 CSR 跨界场景（`twu_crs2_2m && twu_csr_cross`），采样 `csr_data_flop` 是否 shift 更新；对比 1G vs 2M 行为差异以抓取 `twu.sv#L1130` 重复分支 Bug | P0 |
| TC-BUG-012 | F4.NEW.5 | BUG_HUNT（v3.0 新增） | 仲裁侧注入 `csr_grant == 2'b11` 异常值，验证 TWU_IDLE 状态 FSM 是否进入非法态；或等价地用 `sva_csr_grant_onehot` 形式化保护 | P1 |
| TC-BUG-013 | F5.NEW.2 | BUG_HUNT（v3.0 新增） | 在 `arb_ptw_grant` → `ptw_write_req1` → `ptw_write_req2` 流水线中段断言 `cpurst_b` 或 `ptw_xx_cmplt`，验证 SRAM 写入不产生 stale data | P1 |
| TC-BUG-014 | F5.NEW.3 | BUG_HUNT（v3.0 新增） | 冷启动后连续发起 N 次 PDE 请求，统计 4 TWU 分配分布；验证 `twu_req_point_r=4'b0001` 复位初值是否导致 TWU0 首次被连续偏向 | P1 |
| TC-BUG-015 | F8.NEW.2 | 文档/代码项（v3.0 新增 P2，非仿真 TC） | `ct_mmu_tlboper.v#L685-L730` 原 14-state INVVA FSM 注释死代码清理追溯；仅需代码评审跟踪 | P2 |
| TC-BUG-BYPASS-001 | F2.3a | BUG_HUNT | MB Entry alloc+grant 同周期 IDLE→WFC bypass 路径验证；不经过 WFG 直接握手 | P0 |
| TC-BUG-WFG-ABT-001 | F2.3b | BUG_HUNT | WFG+grant+abort 同周期竞争 → ABT 路径验证；abort_hold_r 防迟到 install 污染 | P0 |

> **v3.0 统计更新**：原 60 条 TC-GAP-* + v2.0 新增 12 条 TC-BUG-* + v3.0 新增 5 条（TC-BUG-011~015）− v3.0 删除 2 条（TC-BUG-009/010）= **共 75 条** Gap/BUG TC。分布：P0=24+9+4=**37**、P1=30+3+4=**37**、P2=6+0+1=**7**（已含 v3.0 将 TC-BUG-005/006/007/008 四条真实缺陷从 P1 升 P0、TC-BUG-001/002/003/004 四条证伪从 P0 降 P1）。具体 stimuli/checker 实现交由后续 sequence 开发阶段跟踪 JIRA。

---

## 7. 覆盖率计划（Coverage Plan）

### 7.1 代码覆盖率目标

| 覆盖类型 | 目标 | 备注 |
|---------|------|------|
| Line | ≥ 99.5% | 豁免需评审 |
| Branch | ≥ 99.0% | |
| Condition | ≥ 98.0% | |
| Toggle | ≥ 98.0% | 端口与内部主要信号 |
| FSM（状态 + 转移） | ≥ 99.0% | 所有 MB/ReqQ/TLBOPER 状态机 |

层级配置见 [hpdcache_verification/scripts/cov_hier.cfg](../hpdcache_verification/scripts/cov_hier.cfg) 风格的 `mmu_verification/scripts/cov_hier.cfg`，默认 `+tree top.u_mmu`，排除 SRAM 模型与 SVA 模块。

### 7.2 功能覆盖率（Covergroup 列表）

| Covergroup | 位置 | 关键 coverpoint / cross |
|-----------|------|-------------------------|
| `ifu_req_cg` | `ifu_monitor` | va_high_bits、abort、back-to-back、huge-page、sec |
| `ifu_rsp_cg` | `ifu_monitor` | pavld、pgflt、deny、ca/buf、sec |
| `lsu_req_cg` | `lsu_monitor` | pipe_id、st/ld、id_range、abort、vabuf、STAMO |
| `lsu_rsp_cg` | `lsu_monitor` | pa_vld、pgflt、access_fault、stall、sh/so/ca/buf |
| `dtlb_cg` | `dtlb_monitor`（bind 内部） | entry_alloc、mb_credit、hit_miss、replace_way、huge |
| `l2tlb_bank_cg` | L2 TLB 绑定 | bank_id、way_id、RRPV 初值/更新/回收、bank_conflict |
| `l2tlb_reqq_cg` | L2 TLB 绑定 | source (ITLB/DTLB)、queue_depth、merge |
| `ptw_walk_cg` | `ptw_mem_monitor` + ptw bind | walk_level、page_size、PDE_hit、bus_error、ad_update、illegal_pte_kind |
| `tlb_inv_cg` | `tlb_inv_monitor` | inv_kind (ALL/VA/ASID/VA_ASID)、concurrent_walk、concurrent_access |
| `csr_cg` | `cp0_monitor` | satp_sel、priv_mode、mxr×sum×mprv、ptw_en、no_op |
| `sysmap_cg` | `sysmap_cfg_monitor` + bind | region_id、hit、flag、boundary |
| `pmp_cg` | `pmp_monitor` | port_id、flg_bits、fetch_allow |
| `pagefault_cg` | translation SB | fault_kind、source (IFU/LSU)、priv、asid |
| `perf_event_cg` | `mmu_perf_mon` | miss counters、walk latency bins |
| `cross_scenario_cg` | virtual seq 触发 | cross(priv, mxr, sum, page_perm, op) — 核心保障 |
| **`l2tlb_skew_hash_cg`** 新 | L2 TLB bind | bank_id × way_id × hash_input_pattern（F3.15 / F5.10） |
| **`rrpv_wbuf_cg`** 新 | L2 TLB bind | wbuf_depth、bypass_path、full_stall、flush_drain（F3.18-19） |
| **`mbuf_alloc_cg`** 新 | L1 DTLB / L2 TLB / PTW bind | mb_credit、ffz_pattern、dedup_hit、sfence_clear、wakeup_broadcast（F2.16-17, F3.25-27, F4.31-37） |
| **`sram_collision_cg`** 新 | L2 TLB bind | wr_addr=rd_addr same cycle、wen_bit_pattern、post_reset_first_read（F3.16, F13.9-10, F13.13） |
| **`satp_hazard_cg`** 新 | `ct_mmu_regs` bind | satp_write × inflight_walk、utlb_clr_pulse、priv_switch、hotswap（F4.50, F9.20, F14.15-16） |
| **`attr_propagation_cg`** 新 | top-level SB | sec/share/ca/buf/sh/so/pa_err、bypass_attr_default、pipe2_subset（F10.18-20, F14.14） |
| **`cg_inv_va_alias`** 新 | tlb_inv bind | VPN[7:0] alias、ASID-only、mix-page-size（F1.10b, F8.16-22） |
| **`cg_twu_csr_fsm`** 新 | `twu` bind | TWU CSR FSM 状态/转换（F4.28-30） |
| **`cg_mbuf_fsm`** 新 | `ptw_mbuf` / `mbuf_entry` bind | mbuf entry FSM、abort/refill、bus_error（F4.35, F4.49） |
| **`cg_xbar_select`** 新 | `one_to_four_xbar` bind | port_select、fairness、drain、abort_dispatch（F4.51-52, F5.13-14） |
| **`cg_dft`** 新 | top bind | scan_en、bist_en、icg_en（F12.6-8） |
| **`cg_hpcp`** 新 | top bind | dutlb_miss/iutlb_miss/jtlb_miss 脉冲、脉宽、并发（F11.9-14） |
| **`cg_mb_fsm_7state`** 新 | `mmu_l1dtlb_mb_entry` bind | MB Entry 7 状态（IDLE/WFG/WFC/WFI/PGFLT/ACFLT/ABT）完整状态 × 转换矩阵（F2.3 补充 / F2.3a / F2.3b） |
| **`cg_mb_bypass_path`** 新 | `mmu_l1dtlb_mb_entry` bind | IDLE→WFC bypass 路径（alloc+grant 同周期）、WFG→ABT 竞争路径（F2.3a / F2.3b） |
| **`cg_pde_leaf_nonleaf`** 新 | `ptw_mbuf` / `PDE_cache` bind | 叶 PTE vs 非叶 PTE 的 `mbuf_cache_upd` 行为（V,R,X bit 全组合覆盖，F4.NEW.1） |
| **`cg_rrpv_post_sfence`** 新 | `mmu_l2tlb` + `mmu_l2tlb_rrpv_array` bind | SFENCE 后被无效 entry 的 RRPV 状态分布；连续 INVVA 后替换受影响方式（F3.NEW.1） |
| **`cg_twu_stage_fetch`** 新 | `twu` bind | fst/scd/thd 各级 fetch_type 组合（load/store/fetch 跨级，F4.NEW.2 / F4.NEW.3） |
| **`cg_bank_mask_sel`** 新 | `mmu_arb` bind | selector=00/01/10/11 时各 8-bank mask 字面量值（F5.NEW.1） |
| **`cg_sfence_invva_pgs`** 新 | `ct_mmu_tlboper` bind | INV_VA 时 cur_pgs 值（4K/2M/1G），及 L2TLB 中是否存在其他 pgs 同 VPN entry（F8.NEW.1） |
| **`cg_pmp_fetch_map`** 新 | `ct_mmu_top` bind | port 0-7 fetch 标志存在性（确认 fetch4 缺失，F7.NEW.1 / F7.NEW.2） |
| **`cg_pplru_entry0_hit`** 新 | `pplru` bind | entry 0 首次命中前后 PLRU 树状态；多次命中后 victim 分布（F12.NEW.1） |
| **`cg_no_op_state`** 新 | `ct_mmu_top` bind | `mmu_yy_xx_no_op` 触发条件与持续时间（F10.NEW.1） |
| **`cg_twu_2m_csr_cross`** 新（v3.0） | `twu` bind | 2MB 巨页 `twu_crs2_2m && twu_csr_cross` 事件覆盖；采样 `csr_data_flop` 前/后值与 shift mask；cross(pgs=2M, csr_cross=1) 必须被命中（F4.NEW.4/TC-BUG-011） |
| **`cg_xbar_cold_start`** 新（v3.0） | `one_to_four_xbar` bind | 复位后前 N（=16）次 `PDE_xbar_req` 的 TWU 分配分布；bin 每个 TWU 的首次分配次数（F5.NEW.3/TC-BUG-014） |
| **`cg_l2_store_dtlb_tag`** 新（v3.0） | `mmu_l2tlb` bind | `d_req_type=3'b110`（store）路径的 `arb_l2tlb_is_dtlb` 判断覆盖；load(010) vs store(110) cross（F3.5/TC-BUG-006） |
| **`cg_lsu_req_outstanding`** 新（v3.0） | `ptw_mbuf` bind | 采样 `mmu_lsu_data_req` 拉高期间的持续周期数、outstanding 数目（必须总是 ≤ 1）、请求周期内 `mmu_lsu_data_req_addr` 改变计数（必须=0）；F4.42a |
| **`cg_mbuf_ptr_hold`** 新（v3.0） | `ptw_mbuf` bind | `mbuf_ptr` 相邻两周期变化时必须命中 `lsu_mmu_data_vld` 或 MBUF 由非空转空两种 bin（F4.42c） |

功能覆盖率目标：**100%**（未覆盖点必须评审豁免）。

### 7.3 断言覆盖率（SVA 清单）

| SVA 文件 | 绑定模块 | 关键断言 |
|---------|---------|---------|
| `mmu_ifu_sva.sv` | `ct_mmu_top` IFU 接口 | pavld/pgflt 互斥、abort 语义、stable 要求 |
| `mmu_lsu_sva.sv` | LSU 接口 | pa_vld 单周期有效、stall 语义、STAMO 合法性 |
| `mmu_cp0_sva.sv` | CP0 接口 | cmplt 握手、satp 写合法性 |
| `mmu_ptw_sva.sv` | `ptw` + `twu` | 无重复 PTE req、walk 完成必有 refill、bus_error 终止、tlb_busy 覆盖区间 |
| `mmu_l2tlb_sva.sv` | `mmu_l2tlb` | ReqQ 不溢出、MB 不重复分配、bank 写唯一、RRPV in-range |
| `mmu_l1dtlb_sva.sv` | `mmu_l1dtlb` | MB credit 守恒、install 路径合法 |
| `mmu_l1itlb_sva.sv` | `mmu_l1itlb` | 单端口互斥、refill 合法 |
| `mmu_tlboper_sva.sv` | `ct_mmu_tlboper` | inv_done 语义、与 refill 互斥 |
| `mmu_arb_sva.sv` | `mmu_arb` | 优先级单热、work-conserving、skew 索引 8 路独立 |
| `mmu_sysmap_sva.sv` | `ct_mmu_sysmap` | hit 优先级、flag 合法 |
| **`mmu_gap_sva.sv`** 新 | top bind | `sva_wakeup_broadcast`（F2.17/F4.23）、`sva_refill_atomic`（F3.28）、`sva_no_x_after_reset`（F13.9）、`sva_a_bit_pgflt` / `sva_d_bit_pgflt`（F4.13/F4.14，A=0读 或 D=0写一律 page-fault，无硬件 write-back）、`sva_pde_asid_match`（F4.38）、`sva_satp_mode_illegal`（F9.3）、`sva_stamo_bypass`（F10.18）、`sva_pmp_fetch_4ports`（F7.3）、`sva_mmu_en_consist`（F10.15）、`sva_priv_race`（F14.16）、`sva_csr_handshake`（F14.17）、`sva_ptw_lsu_chn`（F14.18）、`sva_credit_wrap`（F14.19）、`sva_icg_hold`（F12.8）、`sva_reset_order`（F13.11）、`sva_exc_priority`（F10.22）、`sva_abt_protocol`（F10.17）、`sva_wen_bit`（F13.13）、`sva_thd_a_bit_pgflt`（F4.NEW.3，4K 页 A=0 必须 page fault）、`sva_pde_nonleaf_upd`（F4.NEW.1，仅非叶 PTE 触发 mbuf_cache_upd）、`sva_rrpv_inv_clr`（F3.NEW.1，INV 后 RRPV 状态监控）、`sva_sfence_invva_single`（F8.NEW.1，INVVA FSM 仅一次 L2 查找）、`sva_wfg_abt_race`（F2.3b，WFG grant+abort 竞争正确性）、`sva_bank_sel_valid`（F5.NEW.1，mask_bank_sel 字面量正确性；v3.0 证伪后仅作正向覆盖保障）、`sva_twu_2m_cross_data`（F4.NEW.4，2MB CSR 跨界必须触发 `csr_data_flop` 更新，抓取 twu.sv L1130 分支重复 Bug）、`sva_csr_grant_onehot`（F4.NEW.5，TWU `csr_grant[1:0]` 禁止同时为 1）、`sva_ptw_write_pipe_reset_safe`（F5.NEW.2，reset 断言期间 `ptw_write_req1/req2` 同步清零无 stale）、**`sva_lsu_req_stable_until_vld`（F4.42a，`mmu_lsu_data_req` 拉高期间值不得中途拉低直到 `lsu_mmu_data_vld` 或 `bus_error`）**、**`sva_lsu_addr_stable_until_vld`（F4.42a，`mmu_lsu_data_req_addr` 在 req 持续期间禁止变化）**、**`sva_single_outstanding`（F4.42a，outstanding 请求数总是 ≤ 1）**、**`sva_response_inorder`（F4.42b，`lsu_mmu_data_vld` 到达时必须当前 `mmu_lsu_data_req=1`）**、**`sva_vld_only_when_req`（F4.42b，`mmu_lsu_data_req=0` 时 `lsu_mmu_data_vld` 不得为 1）**、**`sva_mbuf_ptr_only_on_response`（F4.42c，`mbuf_ptr` 仅在 vld 或 MBUF 变空时更新）**|

断言覆盖率：**100% 被触发**（未触发需分析）。

### 7.4 豁免（Waiver）流程

1. 工程师在覆盖率报告中识别未覆盖项；
2. 提交豁免申请到 `mmu_verification/docs/waivers/`，含原因（不可达 / 冗余逻辑 / 后续版本修复）；
3. 验证负责人 + 设计负责人会签；
4. URG `-dir` 中自动加载豁免文件；
5. 签核评审会议最终确认。

---

## 8. 回归测试策略（Regression Strategy）

### 8.1 触发机制

| 回归 | 触发 | 通知 |
|------|------|------|
| smoke | 每次代码 push / merge request | CI 状态 + 邮件 |
| nightly_full | 每日 00:00 | Dashboard + 邮件 |
| weekly_coverage | 每周六 00:00 | Dashboard + 周报 |
| release regression | 版本冻结手动触发 | 签核评审 |

### 8.2 通过标准

- 所有 Test Case 的所有 seed 组合 100% 通过（UVM_ERROR / UVM_FATAL = 0）；
- `scripts/scan_logs.pl` 无未 waived 的 pattern 命中；
- 覆盖率不回退（与前次相比 ≥）；
- 性能指标（§7 `perf_event_cg`）无退化超过 2%。

### 8.3 失败分析流程

1. 仿真失败 → `run_vcs_verdi.py` 自动生成 Verdi FSDB；
2. 日志模式扫描 → `scan_logs.pl` 与 `scripts/patterns/` 规则匹配；
3. 分类：环境 bug / 种子不稳定 / DUT bug；
4. 填 JIRA（DUT bug）或 Gitlab issue（环境），挂钩 F-ID；
5. 修复后跑 focused regression（相关 testcase × 50 seed）确认。

---

## 9. 签核标准（Signoff Criteria）

### 9.1 量化签核准则

| 编号 | 条目 | 目标 | 证据 |
|------|------|------|------|
| S1 | nightly_full 连续 5 晚 100% 通过 | 100% | Dashboard 链接 |
| S2 | weekly_coverage 最近一次无回归 | 100% | Dashboard 链接 |
| S3 | 代码覆盖率达标 | 行≥99.5% / 分支≥99% / 翻转≥98% / FSM≥99% | URG 报告 |
| S4 | 功能覆盖率 | 100% | URG 报告 |
| S5 | 断言覆盖率 | 100% 被触发，0 fail | URG assertion 报告 |
| S6 | P0 / P1 Bug（Open） | 0 | JIRA 快照 |
| S7 | P2 Bug（Open） | 已评审并达成处理共识 | 评审纪要 |
| S8 | 豁免项全部会签 | 100% | `docs/waivers/` |
| S9 | GLS zero-delay 关键集 | 100% 通过 | GLS 回归日志 |
| S10 | Lint / CDC / RDC 无未 waived 违例 | 0 | 工具报告 |
| S11 | 验证计划 / 报告 / 签核清单 | 已批准 | 文档链接 |

### 9.2 签核清单（对齐 IC 指南 §3.3）

采用 [doc/IC验证计划_报告_签核清单.md §3.3](IC验证计划_报告_签核清单.md) IP 模板，本 MMU 具体条目在版本冻结阶段由验证负责人生成 `doc/MMU_SignoffChecklist.md`（本验证计划文档外，后续交付）。

---

## 10. 资源与时间表（Resources & Schedule）

### 10.1 人力

| 角色 | 人数 | 职责 |
|------|------|------|
| 验证负责人 | 1 | 整体规划、评审、签核 |
| 验证工程师（环境） | 1 | Agent / SB / Refmodel / Virtual Seq |
| 验证工程师（测试） | 1 | Test Case 开发、Covergroup、回归维护 |
| 脚本 / CI 工程师 | 0.5 | Makefile、`run_test.py`、回归仪表板 |
| 设计支持 | 2（兼职） | RTL bug fix、豁免评审 |
| 架构师 | 0.3 | 协议解读、方案评审 |

### 10.2 工具与环境

- VCS License × N 并行（按夜间回归并发度确定）
- Verdi License × 3
- 服务器：8 核 × 64 GB × 10 节点（nightly）
- 存储：≥ 2 TB（日志 / fsdb / 覆盖率 .vdb）

### 10.3 里程碑

| MS | 里程碑 | 目标日期（T 为 kickoff） | 关键产出 |
|----|--------|-------------------------|---------|
| MS0 | Plan 冻结 | T | 本文档 v1.0 批准 |
| MS1 | 环境就绪 | T + 4 周 | Sanity 通过、UVM 骨架完整 |
| MS2 | Directed 完成 | T + 8 周 | 所有 P0 directed 通过 |
| MS3 | 功能覆盖率 80% | T + 12 周 | CDV 主体完成 |
| MS4 | 覆盖率收敛 | T + 16 周 | 代码/功能/断言达标 |
| MS5 | Signoff | T + 18 周 | §9 全部通过 + 验证报告批准 |

---

## 11. 风险评估与规避（Risk Assessment & Mitigation）

| # | 风险 | 级别 | 缓解策略 |
|---|------|------|---------|
| R1 | 规格书缺失，完全依赖 RTL 注释 | 高 | 建立"设计-验证日评审"；关键语义由架构师书面确认 |
| R2 | RRPV 替换策略正确性难以功能覆盖 | 中 | 行为级 RRPV model + 断言 + 定向 aging testcase |
| R3 | PTW 并发死锁难以暴露 | 中 | `mmu_stress_all_ports_vseq` + watchdog + SVA 监控握手 |
| R4 | Sv39 PTE reserved/非法组合空间巨大 | 中 | error injection seq 遍历所有非法编码 |
| R5 | RTL 中 TODO/FIXME 未解决 | 中 | 上线前由设计负责人清单签署 |
| R6 | 仿真性能不足，导致覆盖率不收敛 | 中 | 使用加速 sequence（高命中 / 低 idle），必要时引入 Palladium |
| R7 | ASID/VPN 字段宽度一致性 | 低 | 链路检查 + SV typedef 集中在 `mmu_common_pkg` |
| R8 | GLS SDF 时序问题 | 低 | 逐步引入：zero-delay → SDF；关键路径先行 |
| R9 | 外部 PMP/SysMap 配置与 SoC 不一致 | 中 | 由架构师 review 测试模板，SoC 集成阶段再 regression |
| R10 | 人员流动 | 低 | 代码评审 + 文档化 + 知识分享 |
| **R11** | **A/D 位无硬件 write-back、仅 trap-only**（K10/GAP-PT.4） | **中** | 与架构/软件侧书面确认 hot page 频繁 page-fault 可接受；SVA `sva_a_bit_pgflt`/`sva_d_bit_pgflt` 锁定语义 |
| **R12** | **L2TLB SRAM 无 reset 产生首 cycle X**（K9/GAP-SR.1） | **中** | 外部 valid FF 作为隔离；`sva_no_x_after_reset` + post-reset cross cg 保障 |
| **R13** | **CSR/SFENCE/SATP 多 hazard 叠加**（K8/K3/K4） | **中** | satp_hazard_cg 顶层交叉覆盖；`sva_satp_mode_illegal` / `sva_csr_handshake` 探测 |
| **R14** | **STAMO/Pipe2/PMP 在 Pipe 间不对称**（K6/K7） | **中** | `sva_stamo_bypass` / `sva_pmp_fetch_4ports` + DTLB STAMO Pipe1 负向用例守护 |
| **R15** | **L2TLB raw_vld OR 逻辑 / arb_l2tlb_is_dtlb store 类型缺失 / RRPV 无效后残留 / pplru entry 0 首次不更新**（4 条真实缺陷：TC-BUG-005/006/007/008，v3.0 全部升 **P0**）| **高** | 针对每条缺陷 directed TC + SVA（新 `sva_raw_vld_excl` / 新 `sva_l2_store_type_covered` / `sva_rrpv_inv_clr` / `cg_pplru_entry0_hit`）同步锁定；设计 review 逐条签字确认。**注：**原列 TC-BUG-002/003（thd_chk A-bit / PDE 叶非叶）已随用户澄清证伪——thd_chk 必为叶 PTE、A-bit 检测正常执行、`thd_chk_refill_req` 只要不触异常即可发出，R15 条目中已移除 |
| **R16** | **mmu_arb bank mask 编码错误**（TC-BUG-004/F5.NEW.1）| ~~高~~ → **低（v3.0 证伪）** | RTL `mmu_arb.sv#L142` 已核实使用 `8'b00110011` 完整字面量，非缺陷；保留 `cg_bank_mask_sel` 作为正向覆盖；相关 TC-BUG-004 已降为 Functional |
| **R17** | **SFENCE INVVA single-pass 导致混合页大小同 VPN 部分不无效**（F8.NEW.1/TC-SFENCE-INVVA-MULTIPGS-001）| **中** | 架构书面确认 L2TLB 是否禁止多 pgs 同 VPN 共存；`cg_sfence_invva_pgs` + `sva_sfence_invva_single` 验证 |
| **R18** | **pplru entry 0 PLRU 首次更新行为异常**（F12.NEW.1/TC-PPLRU-ENTRY0-FIRST-HIT-001）| **低** | `cg_pplru_entry0_hit` 监控首次替换后的公平性；多次命中后 PLRU 树自行纠正；需确认是否影响 PDE Cache 预热性能 |
| **R19** | **【v3.0 新增 P0 高危】`twu.sv#L1130` 2MB CSR 跨界 `csr_data_flop` 分支重复**（F4.NEW.4/TC-BUG-011）| **高** | RTL 二次核对确认 L1128-L1133 存在两行 `else if(twu_crs2_1g && twu_csr_cross)` 完全相同，第二行推测应为 `twu_crs2_2m`；**独立 JIRA 工单跟踪设计修复**；验证侧用 `cg_twu_2m_csr_cross` + `sva_twu_2m_cross_data` 锁定抓取；修复前所有涉 2MB CSR 跨界测试需豁免 |
| **R20** | **【v3.0 新增】`mmu_arb` PTW 写回双级流水线 reset 竞争 + `one_to_four_xbar` 冷启动偏向 TWU0**（F5.NEW.2/F5.NEW.3/TC-BUG-013/014）| **中** | `sva_ptw_write_pipe_reset_safe` 断言 reset 中段 `ptw_write_req1/2` 无残留；`cg_xbar_cold_start` 监控 4 TWU 首次分配分布；若冷启动偏向超过 1 个周期窗口则算 fail |

---



## 12. Traceability Matrix（追溯矩阵节选）

完整矩阵见 **[MMU_Traceability_Matrix.csv](MMU_Traceability_Matrix.csv)**（可直接用 Excel 打开，UTF-8 with BOM 编码）。

> CSV 列：Requirement_ID · Requirement · Sub_Feature_ID · Sub_Feature · Test_Case_ID · Test_Case_Name · Feature_Description · Verification_Goal · Stimuli · Test_Type · Coverage_Method · Covergroup_Binding · Assertion_Binding · Sequence_Binding · Criteria_Pass_Fail · Priority · RTL_Reference · Spec_Reference · Status
>
> **v2.0 补充**：CSV 在原 248 行基础上追加了 60+ 行 `TC-GAP-*` / `TC-*-*-001` 记录（参考 §6.5 与 [MMU_GapAudit_v1.md](MMU_GapAudit_v1.md)），映射 v2.0 新增的 F1.13~F14.20 sub-feature；全量追溯以 CSV 为准。
>
> 本节仅展示关键行预览（格式与 CSV 对齐的简化 markdown 表）。

| Req | Sub-Feat | TC-ID | TC Name | F-Desc | Type | Seq | Prio | Status |
|---|---|---|---|---|---|---|---|---|
| F1.1.1 | F1.1 | ITLB_HIT_001 | IFU basic 4K hit | L1 ITLB 16 entry PLRU replacement with hit/miss... | Directed | ifu_base_seq | P0 | Active |
| F1.1.2 | F1.1 | ITLB_PLRU_001 | IFU PLRU directed | L1 ITLB 16-way replace policy | Directed | ifu_random_vaddr_seq | P0 | Active |
| F1.1.3 | F1.1 | ITLB_PLRU_002 | IFU PLRU random | L1 ITLB PLRU replacement stress | Constrained-Random | ifu_random_vaddr_seq | P1 | Active |
| F1.2.1 | F1.2 | ITLB_PERM_001 | IFU exec perm X=0 | L1 ITLB entry X-bit permission check | Directed | ifu_pagefault_trigger_seq | P0 | Active |
| F1.2.2 | F1.2 | ITLB_PERM_002 | IFU perm SUM+MXR | L1 ITLB U-bit perm with SUM/MXR | Directed | ifu_exec_perm_mix_seq | P0 | Active |
| F1.2.3 | F1.2 | ITLB_PGFLT_001 | IFU pagefault V=0 | L1 ITLB V-bit validity check | Directed | ifu_pagefault_trigger_seq | P0 | Active |
| F1.3.1 | F1.3 | ITLB_HIT_001 | IFU sanity 4K | L1 ITLB 4K VA→PA translation | Directed | ifu_base_seq | P0 | Active |
| F1.3.2 | F1.3 | ITLB_HIT_002 | IFU sequential fetch 4K | L1 ITLB sequential fetch 4K pages | Directed | ifu_sequential_fetch_seq | P0 | Active |
| F1.4.1 | F1.4 | ITLB_HUGE_001 | IFU huge 2MB | L1 ITLB 2MB huge page VA→PA | Directed | ifu_huge_page_fetch_seq | P1 | Active |
| F1.4.2 | F1.4 | ITLB_HUGE_002 | IFU huge 2MB PLRU | L1 ITLB 2MB huge page PLRU replacement | Directed | ifu_huge_page_fetch_seq | P1 | Active |
| F1.5.1 | F1.5 | ITLB_HUGE_003 | IFU huge 1GB | L1 ITLB 1GB huge page VA→PA | Directed | ifu_huge_page_fetch_seq | P1 | Active |
| F1.6.1 | F1.6 | ITLB_ASID_001 | IFU global page ASID | L1 ITLB global page G-bit across ASID | Directed | cp0_satp_sel_toggle_seq | P1 | Active |
| F1.6.2 | F1.6 | ITLB_ASID_002 | IFU non-global ASID | L1 ITLB non-global page ASID invalidation | Directed | cp0_satp_sel_toggle_seq | P1 | Active |
| F1.7.1 | F1.7 | ITLB_REFILL_001 | IFU L2 miss refill | L1 ITLB refill from L2 TLB miss | Directed | ifu_random_vaddr_seq | P0 | Active |
| F1.7.2 | F1.7 | ITLB_REFILL_002 | IFU concurrent refill credit | L1 ITLB refill credit throttling | Constrained-Random | mmu_concurrent_3pipe_vseq | P0 | Active |
| F1.8.1 | F1.8 | ITLB_ABORT_001 | IFU abort no stall | L1 ITLB fetch abort semantics | Directed | ifu_abort_seq | P1 | Active |
| F1.9.1 | F1.9 | ITLB_PERM_001 | covered in F1.2.1 | covered in F1.2 | covered in F1.2.1 | covered | P0 | Active |
| F1.10.1 | F1.10 | ITLB_INV_001 | IFU SFENCE all | L1 ITLB SFENCE.VMA full invalidation | Directed | tlb_inv_all_seq | P0 | Active |
| F1.10.2 | F1.10 | ITLB_INV_002 | IFU SFENCE VA | L1 ITLB SFENCE.VMA VA-targeted invalidation | Directed | tlb_inv_va_seq | P0 | Active |
| F1.10.3 | F1.10 | ITLB_INV_003 | IFU SFENCE VA_ASID | L1 ITLB SFENCE.VMA combined VA+ASID invalidation | Directed | tlb_inv_va_asid_seq | P0 | Active |
| F1.11.1 | F1.11 | ITLB_PROBE_001 | IFU TLBP | L1 ITLB TLBP probe instruction | Directed | tlb_inv_va_seq | P2 | Active |
| F1.12.1 | F1.12 | ITLB_FLUSH_001 | IFU flush abort concurrent | L1 ITLB concurrent flush and abort | Directed | ifu_branch_flush_seq | P1 | Active |
| F2.1.1 | F2.1 | DTLB_HIT_001 | LSU sanity Pipe0 4K | L1 DTLB dual-port Pipe0/1 concurrent hit | Directed | lsu_base_seq | P0 | Active |
| F2.1.2 | F2.1 | DTLB_HIT_002 | LSU sanity Pipe1 4K | L1 DTLB dual-port Pipe1 independent hit | Directed | lsu_base_seq | P0 | Active |
| F2.1.3 | F2.1 | DTLB_CONCURRENT_001 | LSU concurrent Pipe01 same VPN | L1 DTLB concurrent Pipe0/1 same-entry access | Directed | lsu_pipe01_concurrent_seq | P0 | Active |

---

*END OF DOCUMENT*
