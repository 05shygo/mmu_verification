# MMU UVM 验证环境搭建计划 — v3 终版（代码搭建蓝图）

> **文档版本**：v3.0（Final, Code Skeleton Only）
> **日期**：2026-04-22
> **适用 DUT**：`mmu/rtl/ct_mmu_top.v`（OpenRISCV2030 MMU，Sv39）
> **参考框架**：[hpdcache_verification/](../hpdcache_verification/)（UVM 1.2 + VCS/Verdi）
> **验证计划**：[MMU_VerificationPlan.md](MMU_VerificationPlan.md)（功能点 / 测试用例 / 覆盖率目标 / 回归 / 签核）
> **历史版本**：[MMU_UVM_搭建计划_v2_代码级.md](MMU_UVM_搭建计划_v2_代码级.md)（保留作历史）

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| v2.0 | 2026-04-22 | Verification Team | 初版细化代码级计划（含测试点/回归） |
| v3.0 | 2026-04-22 | Verification Team | 终版：剥离测试点/覆盖率目标/回归/签核到 VerificationPlan；扩充文件骨架与实施阶段 |

---

## Table of Contents

- [第 0 章 文档定位与范围](#第-0-章-文档定位与范围)
- [第 1 章 前置决策冻结](#第-1-章-前置决策冻结)
- [第 2 章 RTL 接口与子模块速查](#第-2-章-rtl-接口与子模块速查)
- [第 3 章 目录结构与文件清单](#第-3-章-目录结构与文件清单)
- [第 4 章 dv_utils + scripts 复用清单](#第-4-章-dv_utils--scripts-复用清单)
- [第 5 章 Package 与公共类型骨架](#第-5-章-package-与公共类型骨架)
- [第 6 章 Interface 清单](#第-6-章-interface-清单)
- [第 7 章 Agent 详细骨架（7 个）](#第-7-章-agent-详细骨架7-个)
- [第 8 章 Env 层骨架](#第-8-章-env-层骨架)
- [第 9 章 Top 层与 SVA](#第-9-章-top-层与-sva)
- [第 10 章 Covergroup 实现侧落点](#第-10-章-covergroup-实现侧落点)
- [第 11 章 Test 基类骨架](#第-11-章-test-基类骨架)
- [第 12 章 编译与运行](#第-12-章-编译与运行)
- [第 13 章 实施落地阶段（10 个 Phase）](#第-13-章-实施落地阶段10-个-phase)
- [附录 A：v2 → v3 变更映射](#附录-av2--v3-变更映射)
- [附录 B：与 VerificationPlan 引用对照表](#附录-b与-verificationplan-引用对照表)
- [附录 C：与 hpdcache_verification 文件复用对位](#附录-c与-hpdcache_verification-文件复用对位)

---

## 第 0 章 文档定位与范围

### 0.1 本文档是什么

**MMU UVM 环境搭建的代码蓝图**：以"代码工程师 / Coding AI 不需要任何架构脑力劳动即可逐文件落地"为目标，给出：

- 完整目录树（精确到每个 `.sv` / `.svh`）
- 每个文件的 `class` / `interface` / `typedef` / 字段声明 / **方法签名**（不含方法体）
- 文件之间的依赖关系与编译顺序（`Files.f`）
- 10 个串行实施 Phase（每个 Phase 给出交付文件清单与可独立验证的退出准则）

### 0.2 本文档不是什么

| 不写 | 去哪里看 |
|------|---------|
| 待验证功能点列表（F1–F14, 共 100+ 条） | [VerificationPlan.md §5](MMU_VerificationPlan.md#5-待验证功能点列表feature-list) |
| 测试用例详表（TC-XXX，共 120+ 条，含通过标准） | [VerificationPlan.md §6.3](MMU_VerificationPlan.md#63-test-case-详表) |
| 覆盖率目标百分比 / 豁免机制 | [VerificationPlan.md §7](MMU_VerificationPlan.md#7-覆盖率计划coverage-plan) |
| 回归测试列表（smoke / nightly / coverage） | [VerificationPlan.md §8](MMU_VerificationPlan.md#8-回归测试策略regression-strategy) |
| 签核标准 / Signoff Checklist | [VerificationPlan.md §9](MMU_VerificationPlan.md#9-签核标准signoff-criteria) |
| 资源与时间表 / 风险评估 | [VerificationPlan.md §10–§11](MMU_VerificationPlan.md#10-资源与时间表resources--schedule) |
| Sv39 规范细节 / DUT 行为决策（refmodel 算法语义） | [VerificationPlan.md §3.3](MMU_VerificationPlan.md#33-参考模型reference-model) + RISC-V Privileged Spec |
| SystemVerilog 方法体 / 算法伪代码 | 由代码实现工程师在 Phase 4–8 编写 |

### 0.3 阅读对象

UVM 代码实现工程师 / Coding AI（具备 SystemVerilog + UVM 1.2 基础，无需理解 MMU 架构细节，按本文档建文件 → 填类签名 → 引用 VerificationPlan 写方法体）。

---

## 第 1 章 前置决策冻结

### 1.1 工具链与方法学

| 项 | 决策 | 备注 |
|---|------|------|
| 分页模式 | 仅 Sv39 | 3 级、VPN=27、PPN=28、PA=40、PTE=64 bit |
| 仿真器 | Synopsys VCS | 复用 hpdcache 的 Makefile/run.do |
| 调试器 | Verdi | 配套 `novas.conf` |
| 覆盖率合并 | URG | 参考 `cov_hier.cfg` |
| UVM 版本 | UVM 1.2 | `-ntb_opts uvm-1.2` |
| HVL | SystemVerilog 2012 | |
| 脚本 | Python 3.9 + Perl | 复用 hpdcache `scripts/` |
| 工作目录 | `mmu_verification/` | 与 `hpdcache_verification/` **平级** |
| RTL 引用 | `Files.f` 引用 `../mmu/rtl/*` | 不复制 RTL 源码，避免冗余 |
| dv_utils | **整块复制** | 复制到 `mmu_verification/modules/dv_utils/`，VERSION.txt 锁 commit |
| scripts | **整块复制** | `mmu_verification/scripts/`，按需裁剪 |

### 1.2 Agent 划分（冻结为 7 个）

| # | Agent | 类型 | 对应 DUT 接口组 | 复用源 |
|---|-------|------|----------------|--------|
| 1 | `ifu_agent` | Active | IFU 取指（`ifu_mmu_*` / `mmu_ifu_*`） | 新写，参考 `hpdcache_agent` |
| 2 | `lsu_agent` | Active | LSU Pipe0/1/2/STAMO + TLB Inv 子通道（`lsu_mmu_*0/1/2`、`lsu_mmu_stamo_*`、`lsu_mmu_tlb_*inv*`） | 新写，5 子线程 driver |
| 3 | `cp0_agent` | Active | CP0/CSR（`cp0_mmu_*` / `mmu_cp0_*` / `cp0_yy_priv_mode`） | 新写，参考 `conf_and_perf_agent` |
| 4 | `ptw_mem_agent` | Responder | PTW 数据通道（`mmu_lsu_data_*` / `lsu_mmu_data*` / `lsu_mmu_bus_error` / `mmu_lsu_tlb_busy/wakeup`） | 复用 `memory_response_model` + `memory_shadow` |
| 5 | `pmp_agent` | Responder | PMP 8 端口（`pmp_mmu_flg{0..7}` / `mmu_pmp_pa{0..7}` / `mmu_pmp_fetch{3,5,6,7}`） | 新写，配置式 responder |
| 6 | `sysmap_cfg_agent` | Active | SysMap 区域配置（仅 build/初始化阶段） | 新写，最简 active |
| 7 | `misc_agent` | Passive + 注入 | RTU flush/expt + HPCP cnt_en/miss + biu_smp_disable + scan_en + had_debug | 新写，多子接口聚合 |

> **合并理由**：v1 的 `tlb_inv_agent` 合入 `lsu_agent`（DUT 上 SFENCE 信号在 LSU 端口组）；RTU 与 HPCP 信号量小，合并为 `misc_agent` 减少 boilerplate。

### 1.3 与 hpdcache_verification 框架的对位映射

| MMU UVM 组件 | hpdcache_verification 对应 | 复用方式 |
|---|---|---|
| `mmu_env` | `hpdcache_env` ([env/hpdcache_env.svh](../hpdcache_verification/testbench/env/hpdcache_env.svh)) | 仿照结构（多 SB + cfg + watchdog） |
| `mmu_translation_sb` | `hpdcache_sb` | 仿照 TLM analysis fifo + ref_model 比对 |
| `ifu_agent` / `lsu_agent` | `hpdcache_agent` ([hpdcache_agent/](../hpdcache_verification/testbench/hpdcache_agent/)) | 仿照八件套结构 |
| `cp0_agent` | `conf_and_perf_agent` | 仿照 CSR-style agent |
| `ptw_mem_agent` | `dram_mon` + `memory_response_model` | 复用 dv_utils 内 memory_response_model |
| `tb_top.sv` | [top/top_axi2mem.sv](../hpdcache_verification/testbench/top/top_axi2mem.sv) | 仿照接口实例 + DUT 连线 + uvm_config_db |
| SVA: `mmu_arb_sva.sv` | `hpdcache_fxarb_sva.sv` | 仿照 fixed-priority arbiter SVA |
| SVA: `mmu_plru_sva.sv` | `hpdcache_plru_sva.sv` | 仿照 PLRU SVA |
| SVA: `credit_sva.sv` | `hpdcache_sva.sv` 内的 outstanding 检查 | 仿照 |
| Makefile | [hpdcache_verification/Makefile](../hpdcache_verification/Makefile) | 复制后裁剪 |
| `scripts/run_test.py` | 同名 | 直接复用 |

---

## 第 2 章 RTL 接口与子模块速查

### 2.1 顶层互联框图

```
               ┌──────────────┐   credit  ┌────────────────┐
   IFU  ──►──  │   L1 ITLB    │ ────────► │  L2TLB ReqQ    │
               │(mmu_l1itlb)  │           │ (1 ITLB slot + │
               └──────┬───────┘           │  8 DTLB slots) │
                      │                   └────┬──────────┬┘
               ┌──────▼───────┐                │           │
   LSU  ──►──  │   L1 DTLB    │                ▼           ▼
 P0/P1/STAMO   │(mmu_l1dtlb)  │            ┌──────────────────┐
               │(8 MB entries)│            │   mmu_arb        │
               └──────┬───────┘            │(skew idx gen ×8) │
                      │                    └─┬───┬───┬───┬────┘
   LSU.P2 ─►── ┌──────▼───────┐              │   │   │   │
  (prefetch)   │   L2 TLB     │◄─────────────┘   │   │   │
               │ 8 banks ×    │                  ▼   │   │
               │ 8 ways ×     │             ┌─────────────┐
               │ 256 sets     │             │    PTW      │──► LSU mem req
               │ +MB(1i+8d)   │◄────────────┤  (4 TWU)    │◄── LSU mem rsp
               └──────┬───────┘             │  +L1/L2 PDE │
                      │                     └──────┬──────┘
               ┌──────▼───────┐                    │
               │ replacement  │                    ▼
               │ (SRRIP/RRPV) │          ┌──────────────────┐
               └──────────────┘          │  Sysmap  │  PMP  │
                                         └──────────────────┘
      ┌─────────────┐
      │ tlboper FSM │◄── CP0 / LSU SFENCE / Regs
      │ (7 FSMs)    │──► L1 utlb clr, L2 inv, PTW abort
      └─────────────┘
```

### 2.2 子模块参数冻结表

| 模块 | 文件 | 参数 |
|---|---|---|
| L1 ITLB | [mmu_l1itlb.sv](../mmu/rtl/mmu_l1itlb.sv) | 16 entries 全相联，PLRU，CREDIT_MAX=8，支持 huge 2M |
| L1 DTLB | [mmu_l1dtlb.sv](../mmu/rtl/mmu_l1dtlb.sv) | NUM_ENTRY=16, MB_DEPTH=8, dual pipe + STAMO + PFU(pipe2), dPLRU |
| L2 TLB | [mmu_l2tlb.sv](../mmu/rtl/mmu_l2tlb.sv) | Skew-Assoc 8 ways × 256 sets × 8 banks，RRPV 3-bit，MB 1(ITLB)+8(DTLB) |
| L2 ReqQ | [mmu_l2tlb_reqq.sv](../mmu/rtl/mmu_l2tlb_reqq.sv) | TOTAL_DEPTH=9（1 ITLB + 8 DTLB），FFZ 分配 + FFR 仲裁 |
| Arb | [mmu_arb.sv](../mmu/rtl/mmu_arb.sv) | 4 源仲裁：PTW(高) > TLBOp > ReqQ > PFU；8 bank skew idx |
| Replacement | [mmu_l2tlb_replacement_policy.sv](../mmu/rtl/mmu_l2tlb_replacement_policy.sv) | SRRIP，First-Free > Max-RRPV，RRPV_INIT=4(=MAX-3) |
| PTW | [ptw.sv](../mmu/rtl/ptw.sv) | 4 TWU + ptw_mbuf + L1/L2PDE_cache + xbar 1→4 + pplru |
| TLBOper | [ct_mmu_tlboper.v](../mmu/rtl/ct_mmu_tlboper.v) | 7 FSM：tlbiall/tlbiasid/tlbiva/tlbp/tlbr/tlbwi/tlbwr |
| Sysmap | [ct_mmu_sysmap.v](../mmu/rtl/ct_mmu_sysmap.v) + [sysmap.h](../mmu/rtl/sysmap.h) | 8 region，每 region 5-bit FLG |
| Regs | [ct_mmu_regs.v](../mmu/rtl/ct_mmu_regs.v) | satp0/1, priv, mir/mel/meh，`reg_num[1:0]` 选择 |
| PMP 接口 | 顶层端口 | 8 entries，每 entry 4-bit flag + 4 fetch enable |

### 2.3 关键 FSM 表（覆盖率与定向激励参考）

| FSM | 文件 | 状态宽度 |
|---|---|---|
| L1 ITLB ref FSM | `mmu_l1itlb.sv` | 2 bit |
| L1 DTLB ref FSM | `mmu_l1dtlb.sv` | 3 bit |
| L2 TLB MB（per entry） | `mmu_l2tlb_mb.sv` | IDLE/ALLOC/WAIT_PTW/DONE |
| TLBOper tlbiall | `ct_mmu_tlboper.v` | 1 bit |
| TLBOper tlbiasid | 同 | 3 bit |
| TLBOper tlbiva | 同 | 4 bit |
| TLBOper tlbp / tlbr / tlbwi / tlbwr | 同 | 各 2 bit |
| PTW TWU FSM ×4 | [twu.sv](../mmu/rtl/twu.sv) | 读 PTE → check → 下级/refill |
| PTW mbuf entry | [ptw_mbuf.sv](../mmu/rtl/ptw_mbuf.sv) | alloc/walking/refill/done |

### 2.4 `ct_mmu_top.v` 端口分组 → Agent 映射

| 端口分组 | 信号前缀 | 归属 Agent / Interface |
|----------|---------|----------------------|
| 时钟复位 | `forever_cpuclk`, `cpurst_b` | `tb_top` 直接生成（dv_utils clock_driver / reset_driver） |
| CP0/CSR | `cp0_mmu_*`, `mmu_cp0_*`, `cp0_yy_priv_mode` | `cp0_if` ↔ `cp0_agent` |
| HPCP | `hpcp_mmu_cnt_en`, `mmu_hpcp_*_miss` | `misc_if`（hpcp 子分组）↔ `misc_agent` |
| Debug / SMP / DFT | `mmu_had_debug_info`, `biu_mmu_smp_disable`, `pad_yy_icg_scan_en`, `mmu_xx_mmu_en`, `mmu_yy_xx_no_op` | `misc_if`（debug/dft 子分组）↔ `misc_agent` |
| IFU | `ifu_mmu_*`, `mmu_ifu_*` | `ifu_if` ↔ `ifu_agent` |
| LSU Pipe0/1 | `lsu_mmu_va{0,1}_*`, `mmu_lsu_*{0,1}` | `lsu_if`（pipe0/1 子分组）↔ `lsu_agent` |
| LSU Pipe2 (Prefetch) | `lsu_mmu_va2*`, `mmu_lsu_pa2*`, `mmu_lsu_share2`, `mmu_lsu_sec2` | `lsu_if`（pipe2 子分组）↔ `lsu_agent` |
| LSU STAMO | `lsu_mmu_stamo_*` | `lsu_if`（stamo 子分组）↔ `lsu_agent` |
| LSU TLB Inv | `lsu_mmu_tlb_*inv*`, `lsu_mmu_tlb_va`, `lsu_mmu_tlb_asid`, `mmu_lsu_tlb_inv_done` | `lsu_if`（inv 子分组）↔ `lsu_agent` |
| LSU PTW Data | `mmu_lsu_data_*`, `lsu_mmu_data*`, `lsu_mmu_bus_error`, `mmu_lsu_tlb_busy/wakeup`, `mmu_lsu_mmu_en` | `ptw_mem_if` ↔ `ptw_mem_agent` |
| PMP | `pmp_mmu_flg{0..7}`, `mmu_pmp_pa{0..7}`, `mmu_pmp_fetch{3,5,6,7}` | `pmp_if` ↔ `pmp_agent` |
| RTU | `rtu_mmu_bad_vpn`, `rtu_mmu_expt_vld`, `rtu_yy_xx_flush` | `misc_if`（rtu 子分组）↔ `misc_agent` |
| Sysmap | （无顶层端口，纯内部）配置经 `ct_mmu_sysmap.v` 实例参数 | `sysmap_cfg_if`（白盒注入）↔ `sysmap_cfg_agent` |

### 2.5 关键 CP0 寄存器位

| 信号 | 影响 | 验证关注 |
|---|---|---|
| `cp0_mmu_satp_sel` | satp0/1 选择 | 双 SATP 切换 |
| `cp0_mmu_mxr` | X 页可读 | load 到 X-only 页 |
| `cp0_mmu_sum` | S 模式访问 U 页 | 权限交叉 |
| `cp0_mmu_mprv` + `cp0_mmu_mpp` | M 模式按 MPP 查 | LD/ST 权限切换 |
| `cp0_mmu_maee` | M 模式是否走 TLB | 边界场景 |
| `cp0_mmu_ptw_en` | 关闭后 L2 miss 直 pgflt | PTW 禁用 |
| `cp0_mmu_no_op_req` | 停止 MMU | TLB 不响应 |
| `cp0_mmu_tlb_all_inv` | CP0 路径全失效 | 与 LSU 路径竞争 |
| `cp0_mmu_icg_en` | 时钟门控 | 低功耗 |
| `cp0_yy_priv_mode[1:0]` | 当前 priv（00=U,01=S,11=M） | 权限基础 |

---

## 第 3 章 目录结构与文件清单

### 3.1 完整目录树

```
mmu_verification/
├── Makefile                                # 复制自 hpdcache，裁剪 CONFIG，改 RTL_FLIST
├── README.md                               # 项目说明（用户已提供 doc/）
├── setup_env.sh / setup_env.csh            # 复制自 hpdcache_verification/config/
├── doc/                                    # 已存在
│   ├── MMU_VerificationPlan.md
│   ├── MMU_UVM_BuildPlan_v3_final.md       # 本文档
│   └── MMU_Traceability_Matrix.csv
├── scripts/                                # 整块复制自 hpdcache_verification/scripts/
│   ├── run_test.py
│   ├── run_vcs_verdi.py
│   ├── scan_logs.pl
│   ├── cov_hier.cfg
│   ├── patterns/
│   ├── perl5/
│   └── sim/
├── modules/
│   ├── dv_utils/                           # 整块复制 + VERSION.txt
│   │   └── lib/cv_dv_utils/uvm/
│   │       ├── Files.f
│   │       ├── clock_gen/  reset_gen/  bp_gen/  watchdog/
│   │       ├── memory_rsp_model/  memory_shadow/  memory_partition/
│   │       ├── pulse_gen/  perf_mon/  generic_agent/
│   │       └── unix_utils/
│   └── mmu_params/
│       ├── mmu_params_pkg.sv               # Sv39 常量 + TLB 参数
│       └── VERSION.txt                     # 锁源 commit
└── testbench/
    ├── Files.f                             # 编译总入口
    ├── common/
    │   └── mmu_common_pkg.sv               # PTE 工具函数 + VPN 分段
    ├── ifu_agent/                          # 9 文件
    │   ├── ifu_agent_pkg.sv
    │   ├── ifu_if.sv
    │   ├── ifu_txn.svh
    │   ├── ifu_sequencer.svh
    │   ├── ifu_driver.svh
    │   ├── ifu_monitor.svh
    │   ├── ifu_sequences.svh
    │   ├── ifu_covergroups.svh
    │   └── ifu_agent.svh
    ├── lsu_agent/                          # 9 文件（driver 含 5 子线程）
    │   ├── lsu_agent_pkg.sv
    │   ├── lsu_if.sv                       # 含 pipe0/1/2/stamo/inv 5 子分组
    │   ├── lsu_txn.svh                     # kind enum + 各 pipe 字段
    │   ├── lsu_sequencer.svh
    │   ├── lsu_driver.svh                  # fork: drive_pipe0/1/2/stamo/inv
    │   ├── lsu_monitor.svh                 # 4 ap: pipe0_ap/pipe1_ap/pipe2_ap/inv_ap
    │   ├── lsu_sequences.svh
    │   ├── lsu_covergroups.svh
    │   └── lsu_agent.svh
    ├── cp0_agent/                          # 9 文件
    │   ├── cp0_agent_pkg.sv
    │   ├── cp0_if.sv
    │   ├── cp0_txn.svh
    │   ├── cp0_sequencer.svh
    │   ├── cp0_driver.svh
    │   ├── cp0_monitor.svh
    │   ├── cp0_sequences.svh
    │   ├── cp0_covergroups.svh
    │   └── cp0_agent.svh
    ├── ptw_mem_agent/                      # 10 文件（含 page_table_builder 工具）
    │   ├── ptw_mem_agent_pkg.sv
    │   ├── ptw_mem_if.sv
    │   ├── ptw_mem_txn.svh
    │   ├── ptw_mem_responder.svh           # PTE 响应 + 延迟 + bus_error 注入
    │   ├── ptw_mem_monitor.svh
    │   ├── ptw_mem_sequences.svh
    │   ├── ptw_mem_covergroups.svh
    │   ├── page_table_builder.svh          # 工具类，跨 agent/refmodel 共享
    │   ├── ptw_mem_agent.svh
    │   └── (复用 dv_utils memory_shadow)
    ├── pmp_agent/                          # 9 文件
    │   ├── pmp_agent_pkg.sv
    │   ├── pmp_if.sv
    │   ├── pmp_txn.svh
    │   ├── pmp_sequencer.svh
    │   ├── pmp_driver.svh                  # 8 端口独立 flag 驱动
    │   ├── pmp_monitor.svh
    │   ├── pmp_sequences.svh
    │   ├── pmp_covergroups.svh
    │   └── pmp_agent.svh
    ├── sysmap_cfg_agent/                   # 9 文件
    │   ├── sysmap_cfg_agent_pkg.sv
    │   ├── sysmap_cfg_if.sv                # 白盒 force/release 通道
    │   ├── sysmap_cfg_txn.svh
    │   ├── sysmap_cfg_sequencer.svh
    │   ├── sysmap_cfg_driver.svh
    │   ├── sysmap_cfg_monitor.svh
    │   ├── sysmap_cfg_sequences.svh
    │   ├── sysmap_cfg_covergroups.svh
    │   └── sysmap_cfg_agent.svh
    ├── misc_agent/                         # 9 文件（rtu + hpcp + dft/debug 聚合）
    │   ├── misc_agent_pkg.sv
    │   ├── misc_if.sv                      # rtu/hpcp/debug/dft 子分组
    │   ├── misc_txn.svh
    │   ├── misc_sequencer.svh
    │   ├── misc_driver.svh                 # rtu_flush / expt 注入
    │   ├── misc_monitor.svh                # hpcp/debug 采样
    │   ├── misc_sequences.svh
    │   ├── misc_covergroups.svh
    │   └── misc_agent.svh
    ├── env/
    │   ├── mmu_env_pkg.sv
    │   ├── mmu_top_cfg.svh                 # 环境配置（agent active/passive、SVA 开关）
    │   ├── mmu_page_table_mem.svh          # 共享 shadow PT（基于 memory_shadow）
    │   ├── mmu_ref_model.svh               # translate API + CSR 镜像
    │   ├── mmu_translation_sb.svh          # VA→PA + 异常对比
    │   ├── mmu_invalidate_sb.svh           # SFENCE 后 TLB 状态
    │   ├── mmu_credit_sb.svh               # L1↔L2 credit / ReqQ / MB 容量守恒
    │   ├── mmu_perf_mon.svh                # miss rate / walk latency 统计
    │   ├── mmu_virtual_sequencer.svh
    │   ├── mmu_vseq_lib.svh                # 14 个 vseq 类签名
    │   └── mmu_env.svh
    ├── top/
    │   ├── tb_top.sv                       # DUT 实例 + interface + uvm_config_db
    │   ├── mmu_sva.sv                      # 顶层接口 X-check + 翻译完成性
    │   ├── mmu_arb_sva.sv                  # arb grant 一热 + work-conserving
    │   ├── mmu_l2tlb_rrpv_sva.sv           # SRRIP 行为
    │   ├── mmu_plru_sva.sv                 # L1 PLRU 行为
    │   └── credit_sva.sv                   # outstanding ≤ MAX
    ├── test/
    │   ├── test_pkg.sv                     # `include 所有 test
    │   ├── test_base.svh
    │   ├── basic_tests/                    # 3 个 sanity
    │   ├── l1itlb_tests/                   # 详见 VerificationPlan §6
    │   ├── l1dtlb_tests/
    │   ├── l2tlb_tests/
    │   ├── ptw_tests/
    │   ├── tlbop_tests/
    │   ├── pmp_tests/
    │   ├── sysmap_tests/
    │   ├── cp0_tests/
    │   ├── flush_tests/
    │   ├── cross_tests/
    │   ├── perf_tests/
    │   └── err_tests/
    └── simu/
        ├── run.do                          # Verdi 启动脚本
        ├── WAVES.do                        # 默认信号集
        ├── exclude.do                      # 覆盖率豁免
        ├── mmu_smoke_list                  # 见 VerificationPlan §8
        ├── mmu_nightly_list                # 见 VerificationPlan §8
        └── mmu_coverage_list               # 见 VerificationPlan §8
```

### 3.2 命名规范

| 层级 | 规范 | 示例 |
|------|------|------|
| Package | `<scope>_pkg.sv` / `<agent>_agent_pkg.sv` | `mmu_params_pkg.sv` / `ifu_agent_pkg.sv` |
| Interface | `<agent>_if.sv` | `lsu_if.sv` |
| Transaction | `<agent>_txn.svh` | `cp0_txn.svh` |
| Driver | `<agent>_driver.svh` | `pmp_driver.svh` |
| Monitor | `<agent>_monitor.svh` | `ifu_monitor.svh` |
| Sequencer | `<agent>_sequencer.svh` | `lsu_sequencer.svh` |
| Sequence Library | `<agent>_sequences.svh` | `ptw_mem_sequences.svh` |
| Covergroup | `<agent>_covergroups.svh` | `cp0_covergroups.svh` |
| Agent | `<agent>_agent.svh` | `misc_agent.svh` |
| Scoreboard | `mmu_<scope>_sb.svh` | `mmu_translation_sb.svh` |
| Test | `test_mmu_<category>_<scenario>.svh` | `test_mmu_dir_l2tlb_reqq_alloc.svh` |
| Virtual Sequence | `mmu_<scope>_vseq` 类，统一放 `mmu_vseq_lib.svh` | `mmu_smoke_vseq` |
| SVA 文件 | `<scope>_sva.sv` | `mmu_arb_sva.sv` |

### 3.3 文件总数统计

| 模块 | 文件数 |
|------|--------|
| dv_utils（复制） | 不计入 |
| `modules/mmu_params/` | 2 |
| `testbench/common/` | 1 |
| 7 × Agent 八件套（ptw_mem 多 page_table_builder） | 9×6 + 10 = **64** |
| `testbench/env/` | 11 |
| `testbench/top/` | 6 |
| `testbench/test/` 基类 | 2（test_pkg + test_base） |
| `testbench/test/` 各分类 | ≈120（详见 [VerificationPlan §6](MMU_VerificationPlan.md#6-测试用例计划test-case-plan)） |
| `testbench/simu/` | 6 |
| `Files.f` + `Makefile` + `setup_env.*` | 4 |
| **环境本体（不含测试用例）** | **≈ 96 文件** |

---

## 第 4 章 dv_utils + scripts 复用清单

### 4.1 dv_utils 复用模块（来自 [hpdcache_verification/modules/dv_utils/lib/cv_dv_utils/uvm/](../hpdcache_verification/modules/dv_utils/lib/cv_dv_utils/uvm/)）

| 模块路径 | 用途 | 在 MMU 环境中的使用点 |
|---------|------|---------------------|
| `clock_gen/` | `clock_driver_c` / `clock_config_c` | `tb_top` 生成 `forever_cpuclk` |
| `reset_gen/` | `reset_driver_c` | `tb_top` 生成 `cpurst_b`，含中途 reset |
| `bp_gen/` | `bp_agent` / `bp_virtual_sequence` | （可选）pipe2 prefetch backpressure |
| `watchdog/` | `watchdog_c` | `mmu_env` 注册超时 |
| `memory_rsp_model/` | `memory_response_model` | `ptw_mem_agent` 内部模型 |
| `memory_shadow/` | shadow memory 容器 | `mmu_page_table_mem` 共享后端 |
| `memory_partition/` | `memory_partitions_cfg` | （可选）页表区与数据区分区 |
| `pulse_gen/` | `pulse_gen_driver` / `pulse_gen_cfg` | `misc_agent` 生成 RTU flush 单脉冲 |
| `perf_mon/` | 通用性能监控 | `mmu_perf_mon` 基类 |
| `generic_agent/` | 模板 agent | 6 个新 agent 的代码生成参考 |
| `unix_utils/` | 各类辅助 | 通用 |

> **VERSION.txt**：在 `mmu_verification/modules/dv_utils/VERSION.txt` 内记录复制源 commit hash 与日期，避免后续上游变更不一致。

### 4.2 scripts 复用清单（来自 [hpdcache_verification/scripts/](../hpdcache_verification/scripts/)）

| 脚本 | 用途 | 裁剪 |
|------|------|------|
| `run_test.py` | 单测试 / 回归调度 | 改 default TEST_NAME，去掉 hpdcache 专用 CONFIG 选项 |
| `run_vcs_verdi.py` | VCS + Verdi 启动包装 | 改 top module、Files.f 路径 |
| `scan_logs.pl` | 日志扫描（PASS/FAIL/UVM_ERROR） | 直接复用 |
| `cov_hier.cfg` | URG 层次配置 | 改 DUT 模块路径前缀（`u_dut`） |
| `patterns/` | 错误模式表 | 直接复用并增补 MMU 相关 |
| `sim/` | 仿真子工具 | 直接复用 |

### 4.3 Makefile 关键变量（基于 [hpdcache_verification/Makefile](../hpdcache_verification/Makefile) 裁剪）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PROJECT_DIR` | `$(shell pwd)` | `mmu_verification/` |
| `MMU_RTL_DIR` | `$(PROJECT_DIR)/../mmu/rtl` | DUT 源码 |
| `CV_DV_UTILS_DIR` | `$(PROJECT_DIR)/modules/dv_utils/lib/cv_dv_utils` | 复用库 |
| `TOP_MODULE` | `tb_top` | |
| `UVM_VERSION` | `1.2` | |
| `TEST_NAME` | `test_mmu_sanity_ifu` | 默认冒烟 |
| `SEED` | `random` | |
| `VERBOSITY` | `UVM_MEDIUM` | |
| `TIMEOUT` | `10000000` | |
| `OUTPUT_DIR` / `LOG_DIR` / `WAVE_DIR` / `COV_DIR` | 同 hpdcache | |

> **裁剪点**：删除 `CONFIG=CONFIG1_HPC` 等 hpdcache 配置；删除 `CONFIG_FILE` 与 `SRAM_BEHAV` 块；新增 `+incdir+` 指向 7 个 agent 目录与 `env/` `common/`。

---

## 第 5 章 Package 与公共类型骨架

### 5.1 `modules/mmu_params/mmu_params_pkg.sv`

```systemverilog
package mmu_params_pkg;
  // ==== Sv39 固定 ====
  parameter int unsigned VA_WIDTH       = 39;
  parameter int unsigned PA_WIDTH       = 40;
  parameter int unsigned VPN_WIDTH      = 27;
  parameter int unsigned PPN_WIDTH      = 28;
  parameter int unsigned PAGE_OFFSET    = 12;
  parameter int unsigned ASID_WIDTH     = 16;
  parameter int unsigned PTE_WIDTH      = 64;
  parameter int unsigned PT_LEVELS      = 3;
  parameter int unsigned PT_LEVEL_BITS  = 9;
  parameter int unsigned PTES_PER_PAGE  = 512;

  // PTE bit index
  parameter int unsigned PTE_V = 0, PTE_R = 1, PTE_W = 2, PTE_X = 3;
  parameter int unsigned PTE_U = 4, PTE_G = 5, PTE_A = 6, PTE_D = 7;
  parameter int unsigned PTE_PPN_LSB = 10;

  // TLB 组织
  parameter int unsigned L1_ITLB_ENTRIES   = 16;
  parameter int unsigned L1_DTLB_ENTRIES   = 16;
  parameter int unsigned L1_DTLB_MB_DEPTH  = 8;
  parameter int unsigned L2_TLB_BANKS      = 8;
  parameter int unsigned L2_TLB_WAYS       = 8;
  parameter int unsigned L2_TLB_SETS       = 256;
  parameter int unsigned L2_TLB_MB_ITLB    = 1;
  parameter int unsigned L2_TLB_MB_DTLB    = 8;
  parameter int unsigned L2_REQQ_DEPTH     = 9;
  parameter int unsigned L2_RRPV_WIDTH     = 3;
  parameter int unsigned L2_RRPV_INIT      = 4;   // RRPV_MAX-3 = 7-3
  parameter int unsigned L2_RRPV_MAX       = 7;

  // PTW
  parameter int unsigned PTW_TWU_NUM       = 4;
  parameter int unsigned PTW_MBUF_DEPTH    = 4;

  // Priv
  parameter bit [1:0] PRIV_U = 2'b00;
  parameter bit [1:0] PRIV_S = 2'b01;
  parameter bit [1:0] PRIV_M = 2'b11;

  // Sysmap / PMP
  parameter int unsigned SYSMAP_REGIONS = 8;
  parameter int unsigned PMP_ENTRIES    = 8;

  // Page size
  typedef enum bit [2:0] {
    PGS_4K = 3'd0,
    PGS_2M = 3'd1,
    PGS_1G = 3'd2
  } pgs_e;

  // Access type
  typedef enum bit [2:0] {
    ACC_FETCH = 3'd0,
    ACC_LOAD  = 3'd1,
    ACC_STORE = 3'd2,
    ACC_PFU   = 3'd3
  } acc_type_e;

  // 类型 typedef
  typedef bit [VA_WIDTH-1:0]   va_t;
  typedef bit [PA_WIDTH-1:0]   pa_t;
  typedef bit [VPN_WIDTH-1:0]  vpn_t;
  typedef bit [PPN_WIDTH-1:0]  ppn_t;
  typedef bit [ASID_WIDTH-1:0] asid_t;
  typedef bit [PTE_WIDTH-1:0]  pte_t;
endpackage
```

### 5.2 `testbench/common/mmu_common_pkg.sv`

```systemverilog
package mmu_common_pkg;
  import mmu_params_pkg::*;

  // PTE 构造工具（方法体由实现工程师按 Sv39 编码填）
  function automatic pte_t make_pte(ppn_t ppn,
                                    bit v=1, bit r=1, bit w=1, bit x=1,
                                    bit u=0, bit g=0, bit a=1, bit d=1);
  endfunction

  // VA 分段
  function automatic bit [PT_LEVEL_BITS-1:0] va_vpn_level(va_t va, int level);
  endfunction

  // SATP 编码（MODE=8 Sv39）
  function automatic bit [63:0] make_satp(bit [3:0] mode, asid_t asid, ppn_t ppn);
  endfunction

  // 异常类型枚举（refmodel/SB 共用）
  typedef enum bit [2:0] {
    EXC_NONE        = 3'd0,
    EXC_PAGE_FAULT  = 3'd1,
    EXC_ACCESS_FAULT= 3'd2,
    EXC_PMP_DENY    = 3'd3,
    EXC_BUS_ERROR   = 3'd4
  } mmu_exc_e;
endpackage
```

### 5.3 包导入依赖图

```
uvm_pkg ──┐
          ├──► mmu_params_pkg ──► mmu_common_pkg ──┐
          │                                          ├──► <agent>_agent_pkg (×7)
          │                                          ├──► mmu_env_pkg
          │                                          └──► test_pkg
          └─► dv_utils 各 pkg（clock/reset/bp/watchdog/mem_rsp/...）
                  │
                  └──► mmu_env_pkg
```

---

## 第 6 章 Interface 清单

> 每个 interface 必须满足：① 端口完整与 [ct_mmu_top.v](../mmu/rtl/ct_mmu_top.v) 一一对应；② 含 `clk_i` / `rst_ni`；③ 内含 X-check assertion 占位；④ 在文件头列出对应 DUT 端口范围。

### 6.1 `ifu_agent/ifu_if.sv`

```systemverilog
interface ifu_if(input bit clk_i, input bit rst_ni);
  // === DUT 输入（TB 驱动） ===
  logic         ifu_mmu_va_vld;
  logic [62:0]  ifu_mmu_va;
  logic         ifu_mmu_abort;
  // === DUT 输出（TB 采样） ===
  logic         mmu_ifu_pavld;
  logic [27:0]  mmu_ifu_pa;
  logic         mmu_ifu_buf;
  logic         mmu_ifu_ca;
  logic         mmu_ifu_deny;
  logic         mmu_ifu_pgflt;
  logic         mmu_ifu_sec;
  // X-check assertion 占位（见 top/mmu_sva.sv）
endinterface
```

### 6.2 `lsu_agent/lsu_if.sv`

```systemverilog
interface lsu_if(input bit clk_i, input bit rst_ni);
  // ---- Pipe0 ----
  logic         lsu_mmu_va0_vld;
  logic [6:0]   lsu_mmu_id0;
  logic [63:0]  lsu_mmu_va0;
  logic         lsu_mmu_st_inst0;
  logic         lsu_mmu_abort0;
  logic [27:0]  lsu_mmu_vabuf0;
  logic         mmu_lsu_pa0_vld;
  logic [27:0]  mmu_lsu_pa0;
  logic         mmu_lsu_page_fault0;
  logic         mmu_lsu_access_fault0;
  logic         mmu_lsu_stall0;
  logic         mmu_lsu_sec0, mmu_lsu_sh0, mmu_lsu_so0, mmu_lsu_buf0, mmu_lsu_ca0;
  // ---- Pipe1（同 Pipe0 信号 + 后缀 1） ----
  logic         lsu_mmu_va1_vld;
  logic [6:0]   lsu_mmu_id1;
  logic [63:0]  lsu_mmu_va1;
  logic         lsu_mmu_st_inst1;
  logic         lsu_mmu_abort1;
  logic [27:0]  lsu_mmu_vabuf1;
  logic         mmu_lsu_pa1_vld;
  logic [27:0]  mmu_lsu_pa1;
  logic         mmu_lsu_page_fault1;
  logic         mmu_lsu_access_fault1;
  logic         mmu_lsu_stall1;
  logic         mmu_lsu_sec1, mmu_lsu_sh1, mmu_lsu_so1, mmu_lsu_buf1, mmu_lsu_ca1;
  // ---- Pipe2 (Prefetch) ----
  logic         lsu_mmu_va2_vld;
  logic [27:0]  lsu_mmu_va2;
  logic         mmu_lsu_pa2_vld;
  logic [27:0]  mmu_lsu_pa2;
  logic         mmu_lsu_sec2;
  logic         mmu_lsu_pa2_err;
  logic         mmu_lsu_share2;
  // ---- STAMO ----
  logic         lsu_mmu_stamo_vld;
  logic [27:0]  lsu_mmu_stamo_pa;
  // ---- TLB Invalidate (SFENCE.VMA) ----
  logic         lsu_mmu_tlb_va_all_inv;
  logic         lsu_mmu_tlb_all_inv;
  logic         lsu_mmu_tlb_va_asid_inv;
  logic         lsu_mmu_tlb_asid_all_inv;
  logic [26:0]  lsu_mmu_tlb_va;
  logic [15:0]  lsu_mmu_tlb_asid;
  logic         mmu_lsu_tlb_inv_done;
endinterface
```

### 6.3 `cp0_agent/cp0_if.sv`

```systemverilog
interface cp0_if(input bit clk_i, input bit rst_ni);
  // CSR 写控制
  logic         cp0_mmu_wreg;
  logic [1:0]   cp0_mmu_reg_num;
  logic         cp0_mmu_satp_sel;
  logic [63:0]  cp0_mmu_wdata;
  // Mode / 权限位
  logic         cp0_mmu_cskyee;
  logic         cp0_mmu_icg_en;
  logic         cp0_mmu_maee;
  logic [1:0]   cp0_mmu_mpp;
  logic         cp0_mmu_mprv;
  logic         cp0_mmu_mxr;
  logic         cp0_mmu_no_op_req;
  logic         cp0_mmu_ptw_en;
  logic         cp0_mmu_sum;
  logic         cp0_mmu_tlb_all_inv;
  logic [1:0]   cp0_yy_priv_mode;
  // 反馈
  logic         mmu_cp0_cmplt;
  logic [63:0]  mmu_cp0_data;
  logic [63:0]  mmu_cp0_satp_data;
  logic         mmu_cp0_tlb_done;
  logic         mmu_xx_mmu_en;
  logic         mmu_yy_xx_no_op;
endinterface
```

### 6.4 `ptw_mem_agent/ptw_mem_if.sv`

```systemverilog
interface ptw_mem_if(input bit clk_i, input bit rst_ni);
  // PTW 发出（TB 采样）
  logic         mmu_lsu_data_req;
  logic [39:0]  mmu_lsu_data_req_addr;
  logic         mmu_lsu_data_req_size;
  logic         mmu_lsu_mmu_en;
  // PTW 流控反向
  logic         mmu_lsu_tlb_busy;
  logic [11:0]  mmu_lsu_tlb_wakeup;
  // 响应（TB 驱动）
  logic         lsu_mmu_bus_error;
  logic         lsu_mmu_data_vld;
  logic [63:0]  lsu_mmu_data;
endinterface
```

### 6.5 `pmp_agent/pmp_if.sv`

```systemverilog
interface pmp_if(input bit clk_i, input bit rst_ni);
  // 8 端口 PA 输出（TB 采样）
  logic [27:0]  mmu_pmp_pa0, mmu_pmp_pa1, mmu_pmp_pa2, mmu_pmp_pa3;
  logic [27:0]  mmu_pmp_pa4, mmu_pmp_pa5, mmu_pmp_pa6, mmu_pmp_pa7;
  // 4 个 fetch enable 输出
  logic         mmu_pmp_fetch3, mmu_pmp_fetch5, mmu_pmp_fetch6, mmu_pmp_fetch7;
  // 8 端口 4-bit flag 输入（TB 驱动）
  logic [3:0]   pmp_mmu_flg0, pmp_mmu_flg1, pmp_mmu_flg2, pmp_mmu_flg3;
  logic [3:0]   pmp_mmu_flg4, pmp_mmu_flg5, pmp_mmu_flg6, pmp_mmu_flg7;
endinterface
```

### 6.6 `sysmap_cfg_agent/sysmap_cfg_if.sv`

```systemverilog
interface sysmap_cfg_if(input bit clk_i, input bit rst_ni);
  // SysMap 配置仅在 build_phase / 复位后通过 force/release 注入到 RTL 内部
  // 这里只承载配置数据，不直接连到 DUT 端口（端口不存在）
  // 实际 force 路径见 sysmap_cfg_driver.svh
  bit [27:0] cfg_base[8];     // region 基址
  bit [27:0] cfg_mask[8];     // region 掩码
  bit [4:0]  cfg_flg[8];      // 5-bit 属性
  bit        cfg_enable[8];   // region 使能
endinterface
```

### 6.7 `misc_agent/misc_if.sv`

```systemverilog
interface misc_if(input bit clk_i, input bit rst_ni);
  // ---- RTU 子分组（TB 驱动） ----
  logic [26:0]  rtu_mmu_bad_vpn;
  logic         rtu_mmu_expt_vld;
  logic         rtu_yy_xx_flush;
  // ---- HPCP 子分组 ----
  logic         hpcp_mmu_cnt_en;            // 驱动
  logic         mmu_hpcp_dutlb_miss;        // 采样
  logic         mmu_hpcp_iutlb_miss;        // 采样
  logic         mmu_hpcp_jtlb_miss;         // 采样
  // ---- DFT / 低功耗子分组 ----
  logic         pad_yy_icg_scan_en;         // 驱动
  logic         biu_mmu_smp_disable;        // 驱动
  // ---- Debug 子分组（采样） ----
  logic [33:0]  mmu_had_debug_info;
endinterface
```

---

## 第 7 章 Agent 详细骨架（7 个）

> 每个 agent 八件套；以下仅给出**类签名与字段**，方法体留空。

### 7.1 `ifu_agent/`

#### 7.1.1 `ifu_txn.svh`

```systemverilog
class ifu_txn extends uvm_sequence_item;
  `uvm_object_utils(ifu_txn)
  // 激励字段
  rand bit [62:0] va;
  rand bit        abort;
  rand int        idle_cycles;
  // 响应字段（monitor 回填）
  bit [27:0] pa;
  bit        pgflt, deny, sec, ca, buf_bit;
  // 约束
  constraint c_idle { idle_cycles inside {[0:10]}; }
  function new(string name = "ifu_txn");
  extern function string convert2string();
endclass
```

#### 7.1.2 `ifu_driver.svh`

```systemverilog
class ifu_driver extends uvm_driver #(ifu_txn);
  `uvm_component_utils(ifu_driver)
  virtual ifu_if vif;
  function new(string name, uvm_component parent);
  extern function void set_ifu_vif(virtual ifu_if v);
  extern task run_phase(uvm_phase phase);
  extern task drive_one(ifu_txn tr);
endclass
```

#### 7.1.3 `ifu_monitor.svh`

```systemverilog
class ifu_monitor extends uvm_monitor;
  `uvm_component_utils(ifu_monitor)
  virtual ifu_if vif;
  uvm_analysis_port #(ifu_txn) ap_req;     // VA 发射时
  uvm_analysis_port #(ifu_txn) ap_rsp;     // PA 返回时
  function new(string name, uvm_component parent);
  extern function void set_ifu_vif(virtual ifu_if v);
  extern function void set_is_active();
  extern task run_phase(uvm_phase phase);
  extern task collect_req();
  extern task collect_rsp();
endclass
```

#### 7.1.4 `ifu_sequencer.svh`

```systemverilog
class ifu_sequencer extends uvm_sequencer #(ifu_txn);
  `uvm_component_utils(ifu_sequencer)
  function new(string name, uvm_component parent);
endclass
```

#### 7.1.5 `ifu_sequences.svh`

```systemverilog
class ifu_base_sequence extends uvm_sequence #(ifu_txn);
  `uvm_object_utils(ifu_base_sequence)
  rand int unsigned num_txn;
  function new(string name = "ifu_base_sequence");
  extern task body();
endclass

class ifu_random_vaddr_seq    extends ifu_base_sequence; `uvm_object_utils(ifu_random_vaddr_seq)    endclass
class ifu_sequential_fetch_seq extends ifu_base_sequence; `uvm_object_utils(ifu_sequential_fetch_seq) endclass
class ifu_abort_seq           extends ifu_base_sequence; `uvm_object_utils(ifu_abort_seq)           endclass
class ifu_branch_flush_seq    extends ifu_base_sequence; `uvm_object_utils(ifu_branch_flush_seq)    endclass
class ifu_pagefault_trigger_seq extends ifu_base_sequence; `uvm_object_utils(ifu_pagefault_trigger_seq) endclass
class ifu_exec_perm_mix_seq   extends ifu_base_sequence; `uvm_object_utils(ifu_exec_perm_mix_seq)   endclass
class ifu_huge_page_fetch_seq extends ifu_base_sequence; `uvm_object_utils(ifu_huge_page_fetch_seq) endclass
```

#### 7.1.6 `ifu_covergroups.svh`

```systemverilog
class ifu_cg_wrapper extends uvm_component;
  `uvm_component_utils(ifu_cg_wrapper)
  virtual ifu_if vif;
  // covergroup 定义见 §10
  covergroup cg_ifu_req @(posedge vif.clk_i iff vif.ifu_mmu_va_vld);
    cp_va_seg : coverpoint vif.ifu_mmu_va[62:39];
    cp_abort  : coverpoint vif.ifu_mmu_abort;
  endgroup
  covergroup cg_ifu_rsp @(posedge vif.clk_i iff vif.mmu_ifu_pavld);
    cp_pgflt : coverpoint vif.mmu_ifu_pgflt;
    cp_deny  : coverpoint vif.mmu_ifu_deny;
    cp_sec   : coverpoint vif.mmu_ifu_sec;
    cross cp_pgflt, cp_deny;
  endgroup
  function new(string name, uvm_component parent);
  extern function void set_ifu_vif(virtual ifu_if v);
endclass
```

#### 7.1.7 `ifu_agent.svh`

```systemverilog
class ifu_agent extends uvm_agent;
  `uvm_component_utils_begin(ifu_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
  `uvm_component_utils_end
  protected uvm_active_passive_enum is_active = UVM_ACTIVE;
  ifu_sequencer  m_sequencer;
  ifu_driver     m_driver;
  ifu_monitor    m_monitor;
  ifu_cg_wrapper m_cg;
  virtual ifu_if vif;
  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass
```

#### 7.1.8 `ifu_agent_pkg.sv`

```systemverilog
package ifu_agent_pkg;
  timeunit 1ns; timeprecision 1ps;
  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;
  `include "uvm_macros.svh"
  `include "ifu_txn.svh"
  `include "ifu_covergroups.svh"
  `include "ifu_sequencer.svh"
  `include "ifu_driver.svh"
  `include "ifu_monitor.svh"
  `include "ifu_sequences.svh"
  `include "ifu_agent.svh"
endpackage
```

### 7.2 `lsu_agent/`

#### 7.2.1 `lsu_txn.svh`

```systemverilog
typedef enum bit [2:0] {
  LSU_PIPE0,
  LSU_PIPE1,
  LSU_PIPE2,    // prefetch
  LSU_STAMO,
  LSU_INV
} lsu_kind_e;

typedef enum bit [1:0] {
  INV_ALL,
  INV_VA_ALL,
  INV_ASID_ALL,
  INV_VA_ASID
} lsu_inv_kind_e;

class lsu_txn extends uvm_sequence_item;
  `uvm_object_utils(lsu_txn)
  rand lsu_kind_e     kind;
  // pipe0/1
  rand bit [63:0]     va;
  rand bit [6:0]      id;
  rand bit            st_inst;
  rand bit            abort;
  rand bit [27:0]     vabuf;
  // pipe2
  rand bit [27:0]     va2;
  // stamo
  rand bit [27:0]     stamo_pa;
  // inv
  rand lsu_inv_kind_e inv_kind;
  rand bit [26:0]     inv_va;
  rand bit [15:0]     inv_asid;
  // timing
  rand int            idle_cycles;
  // rsp 回填
  bit [27:0] pa;
  bit        pgflt, access_fault, stall, sec;
  function new(string name = "lsu_txn");
  extern function string convert2string();
endclass
```

#### 7.2.2 `lsu_driver.svh`（5 子线程 fork）

```systemverilog
class lsu_driver extends uvm_driver #(lsu_txn);
  `uvm_component_utils(lsu_driver)
  virtual lsu_if vif;
  function new(string name, uvm_component parent);
  extern function void set_lsu_vif(virtual lsu_if v);
  extern task run_phase(uvm_phase phase);
  // 5 子线程
  extern task drive_pipe0();
  extern task drive_pipe1();
  extern task drive_pipe2();
  extern task drive_stamo();
  extern task drive_inv();
  // 子任务（实现工程师按 kind 分发 seq_item）
endclass
```

#### 7.2.3 `lsu_monitor.svh`（4 个 analysis_port）

```systemverilog
class lsu_monitor extends uvm_monitor;
  `uvm_component_utils(lsu_monitor)
  virtual lsu_if vif;
  uvm_analysis_port #(lsu_txn) ap_pipe0;
  uvm_analysis_port #(lsu_txn) ap_pipe1;
  uvm_analysis_port #(lsu_txn) ap_pipe2;
  uvm_analysis_port #(lsu_txn) ap_inv;
  function new(string name, uvm_component parent);
  extern function void set_lsu_vif(virtual lsu_if v);
  extern function void set_is_active();
  extern task run_phase(uvm_phase phase);
  extern task collect_pipe(int unsigned p);
  extern task collect_inv();
endclass
```

#### 7.2.4 `lsu_sequencer.svh`

```systemverilog
class lsu_sequencer extends uvm_sequencer #(lsu_txn);
  `uvm_component_utils(lsu_sequencer)
  function new(string name, uvm_component parent);
endclass
```

#### 7.2.5 `lsu_sequences.svh`

```systemverilog
class lsu_base_seq extends uvm_sequence #(lsu_txn);
  `uvm_object_utils(lsu_base_seq)
  rand int unsigned num_txn;
  function new(string name = "lsu_base_seq");
  extern task body();
endclass

class lsu_pipe0_only_seq         extends lsu_base_seq; `uvm_object_utils(lsu_pipe0_only_seq)         endclass
class lsu_pipe1_only_seq         extends lsu_base_seq; `uvm_object_utils(lsu_pipe1_only_seq)         endclass
class lsu_pipe01_concurrent_seq  extends lsu_base_seq; `uvm_object_utils(lsu_pipe01_concurrent_seq)  endclass
class lsu_prefetch_pipe2_seq     extends lsu_base_seq; `uvm_object_utils(lsu_prefetch_pipe2_seq)     endclass
class lsu_stamo_seq              extends lsu_base_seq; `uvm_object_utils(lsu_stamo_seq)              endclass
class lsu_back2back_seq          extends lsu_base_seq; `uvm_object_utils(lsu_back2back_seq)          endclass
class lsu_same_line_hit_miss_seq extends lsu_base_seq; `uvm_object_utils(lsu_same_line_hit_miss_seq) endclass
class lsu_abort_seq              extends lsu_base_seq; `uvm_object_utils(lsu_abort_seq)              endclass
class lsu_huge_page_seq          extends lsu_base_seq; `uvm_object_utils(lsu_huge_page_seq)          endclass
class lsu_cross_asid_seq         extends lsu_base_seq; `uvm_object_utils(lsu_cross_asid_seq)         endclass
class lsu_st_ld_mix_seq          extends lsu_base_seq; `uvm_object_utils(lsu_st_ld_mix_seq)          endclass
class lsu_unaligned_seq          extends lsu_base_seq; `uvm_object_utils(lsu_unaligned_seq)          endclass
// TLB Inv 子序列
class tlb_inv_all_seq            extends lsu_base_seq; `uvm_object_utils(tlb_inv_all_seq)            endclass
class tlb_inv_va_seq             extends lsu_base_seq; `uvm_object_utils(tlb_inv_va_seq)             endclass
class tlb_inv_asid_seq           extends lsu_base_seq; `uvm_object_utils(tlb_inv_asid_seq)           endclass
class tlb_inv_va_asid_seq        extends lsu_base_seq; `uvm_object_utils(tlb_inv_va_asid_seq)        endclass
class sfence_vma_stress_seq      extends lsu_base_seq; `uvm_object_utils(sfence_vma_stress_seq)      endclass
```

#### 7.2.6 `lsu_covergroups.svh`

```systemverilog
class lsu_cg_wrapper extends uvm_component;
  `uvm_component_utils(lsu_cg_wrapper)
  virtual lsu_if vif;
  // 见 §10：lsu_pipe_cg ×2 + lsu_pipe2_cg + lsu_inv_cg
  function new(string name, uvm_component parent);
  extern function void set_lsu_vif(virtual lsu_if v);
endclass
```

#### 7.2.7 `lsu_agent.svh` / 7.2.8 `lsu_agent_pkg.sv`

结构同 §7.1.7 / §7.1.8（替换类型名）。

### 7.3 `cp0_agent/`

#### 7.3.1 `cp0_txn.svh`

```systemverilog
typedef enum bit [3:0] {
  CP0_WRITE_SATP,
  CP0_READ_SATP,
  CP0_WRITE_REG,         // mir/mel/meh by reg_num
  CP0_READ_REG,
  CP0_SET_PRIV,
  CP0_SET_MXR,
  CP0_SET_SUM,
  CP0_SET_MPRV_MPP,
  CP0_SET_PTW_EN,
  CP0_SET_NO_OP,
  CP0_SET_MAEE,
  CP0_SET_ICG_EN,
  CP0_SET_CSKYEE,
  CP0_TLB_ALL_INV
} cp0_op_e;

class cp0_txn extends uvm_sequence_item;
  `uvm_object_utils(cp0_txn)
  rand cp0_op_e   op;
  rand bit [1:0]  reg_num;
  rand bit        satp_sel;
  rand bit [63:0] wdata;
  rand bit [1:0]  priv_mode;
  rand bit        mxr, sum, mprv;
  rand bit [1:0]  mpp;
  rand bit        ptw_en, no_op_req, maee, icg_en, cskyee;
  // rsp
  bit [63:0] rdata;
  bit        cmplt, tlb_done;
  function new(string name = "cp0_txn");
endclass
```

#### 7.3.2–7.3.8 driver / monitor / sequencer / sequences / covergroups / agent / pkg

```systemverilog
class cp0_driver    extends uvm_driver #(cp0_txn);  `uvm_component_utils(cp0_driver)    virtual cp0_if vif; endclass
class cp0_monitor   extends uvm_monitor;            `uvm_component_utils(cp0_monitor)   virtual cp0_if vif; uvm_analysis_port #(cp0_txn) ap; endclass
class cp0_sequencer extends uvm_sequencer #(cp0_txn);`uvm_component_utils(cp0_sequencer) endclass
// sequences
class cp0_reg_rw_seq           extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_reg_rw_seq)           endclass
class cp0_satp_switch_seq      extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_satp_switch_seq)      endclass
class cp0_satp_sel_toggle_seq  extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_satp_sel_toggle_seq)  endclass
class cp0_priv_switch_seq      extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_priv_switch_seq)      endclass
class cp0_mxr_sum_cross_seq    extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_mxr_sum_cross_seq)    endclass
class cp0_mprv_seq             extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_mprv_seq)             endclass
class cp0_ptw_disable_seq      extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_ptw_disable_seq)      endclass
class cp0_tlb_allinv_seq       extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_tlb_allinv_seq)       endclass
class cp0_no_op_seq            extends uvm_sequence #(cp0_txn); `uvm_object_utils(cp0_no_op_seq)            endclass
```

### 7.4 `ptw_mem_agent/`

#### 7.4.1 `ptw_mem_txn.svh`

```systemverilog
typedef enum bit [1:0] {
  PTW_RSP_NORMAL,
  PTW_RSP_SLOW,
  PTW_RSP_BUS_ERR,
  PTW_RSP_OOO
} ptw_rsp_kind_e;

class ptw_mem_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_mem_txn)
  bit [39:0]      addr;        // monitor 采样
  bit             req_size;
  rand ptw_rsp_kind_e rsp_kind;
  rand int        rsp_delay;
  bit [63:0]      pte_data;    // builder/ref_model 决定
  bit             bus_error;
  function new(string name = "ptw_mem_txn");
endclass
```

#### 7.4.2 `page_table_builder.svh`（核心工具类）

```systemverilog
class page_table_builder extends uvm_object;
  `uvm_object_utils(page_table_builder)
  // 复用 dv_utils 的 memory_shadow 作为后端存储
  // memory_shadow_c m_mem;   // 由实现工程师实例化
  ppn_t  m_root_ppn;          // 当前 SATP.PPN
  asid_t m_root_asid;
  function new(string name = "page_table_builder");
  // 配置 API
  extern function void set_root(ppn_t root_ppn, asid_t asid);
  extern function void map_4k(va_t va, pa_t pa, bit v=1, bit r=1, bit w=1, bit x=1,
                              bit u=0, bit g=0, bit a=1, bit d=1);
  extern function void map_2m(va_t va, pa_t pa, bit v=1, bit r=1, bit w=1, bit x=1,
                              bit u=0, bit g=0, bit a=1, bit d=1);
  extern function void map_1g(va_t va, pa_t pa, bit v=1, bit r=1, bit w=1, bit x=1,
                              bit u=0, bit g=0, bit a=1, bit d=1);
  extern function void invalidate(va_t va);
  extern function void inject_fault(va_t va, string fault_kind);
      // fault_kind: "V_OFF", "RW_RESERVED", "A_OFF", "D_OFF",
      //             "MISALIGNED", "U_VIOLATION", "RESERVED_BITS"
  // 读写 PTE
  extern function pte_t read_pte_at(pa_t pte_addr);
  extern function void  write_pte_at(pa_t pte_addr, pte_t pte);
endclass
```

#### 7.4.3 `ptw_mem_responder.svh`

```systemverilog
class ptw_mem_responder extends uvm_component;
  `uvm_component_utils(ptw_mem_responder)
  virtual ptw_mem_if vif;
  page_table_builder m_pt;
  // 配置参数
  int unsigned m_rsp_delay_min = 1;
  int unsigned m_rsp_delay_max = 8;
  int unsigned m_bus_error_rate_permille = 0;
  function new(string name, uvm_component parent);
  extern function void set_ptw_mem_vif(virtual ptw_mem_if v);
  extern function void set_page_table(page_table_builder pt);
  extern task run_phase(uvm_phase phase);
  extern task handle_request(bit [39:0] addr);
endclass
```

#### 7.4.4 `ptw_mem_monitor.svh`

```systemverilog
class ptw_mem_monitor extends uvm_monitor;
  `uvm_component_utils(ptw_mem_monitor)
  virtual ptw_mem_if vif;
  uvm_analysis_port #(ptw_mem_txn) ap_req;
  uvm_analysis_port #(ptw_mem_txn) ap_rsp;
  function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);
endclass
```

#### 7.4.5 `ptw_mem_sequences.svh`

```systemverilog
class ptw_mem_normal_rsp_seq        extends uvm_sequence; `uvm_object_utils(ptw_mem_normal_rsp_seq)        endclass
class ptw_mem_ooo_rsp_seq           extends uvm_sequence; `uvm_object_utils(ptw_mem_ooo_rsp_seq)           endclass
class ptw_mem_slow_rsp_seq          extends uvm_sequence; `uvm_object_utils(ptw_mem_slow_rsp_seq)          endclass
class ptw_mem_bus_error_inject_seq  extends uvm_sequence; `uvm_object_utils(ptw_mem_bus_error_inject_seq)  endclass
class ptw_mem_illegal_pte_seq       extends uvm_sequence; `uvm_object_utils(ptw_mem_illegal_pte_seq)       endclass
class ptw_page_table_build_4k_seq   extends uvm_sequence; `uvm_object_utils(ptw_page_table_build_4k_seq)   endclass
class ptw_page_table_build_2m_seq   extends uvm_sequence; `uvm_object_utils(ptw_page_table_build_2m_seq)   endclass
class ptw_page_table_build_1g_seq   extends uvm_sequence; `uvm_object_utils(ptw_page_table_build_1g_seq)   endclass
class ptw_pte_ad_update_seq         extends uvm_sequence; `uvm_object_utils(ptw_pte_ad_update_seq)         endclass
class ptw_deep_tree_random_seq      extends uvm_sequence; `uvm_object_utils(ptw_deep_tree_random_seq)      endclass
```

### 7.5 `pmp_agent/`

```systemverilog
class pmp_txn extends uvm_sequence_item;
  `uvm_object_utils(pmp_txn)
  rand bit [3:0] flg[8];           // 8 端口独立 flag
  // monitor 采样
  bit [27:0] pa[8];
  bit        fetch_en[4];          // port 3,5,6,7
  function new(string name = "pmp_txn");
endclass

class pmp_driver    extends uvm_driver #(pmp_txn); `uvm_component_utils(pmp_driver)    virtual pmp_if vif; endclass
class pmp_monitor   extends uvm_monitor;           `uvm_component_utils(pmp_monitor)   virtual pmp_if vif; uvm_analysis_port #(pmp_txn) ap; endclass
class pmp_sequencer extends uvm_sequencer #(pmp_txn); `uvm_component_utils(pmp_sequencer) endclass

class pmp_flg_normal_seq      extends uvm_sequence #(pmp_txn); `uvm_object_utils(pmp_flg_normal_seq)      endclass
class pmp_flg_deny_fetch_seq  extends uvm_sequence #(pmp_txn); `uvm_object_utils(pmp_flg_deny_fetch_seq)  endclass
class pmp_flg_deny_rw_seq     extends uvm_sequence #(pmp_txn); `uvm_object_utils(pmp_flg_deny_rw_seq)     endclass
class pmp_flg_cross_8port_seq extends uvm_sequence #(pmp_txn); `uvm_object_utils(pmp_flg_cross_8port_seq) endclass
```

### 7.6 `sysmap_cfg_agent/`

```systemverilog
class sysmap_cfg_txn extends uvm_sequence_item;
  `uvm_object_utils(sysmap_cfg_txn)
  rand bit [27:0] base[8];
  rand bit [27:0] mask[8];
  rand bit [4:0]  flg[8];
  rand bit        enable[8];
  function new(string name = "sysmap_cfg_txn");
endclass

class sysmap_cfg_driver  extends uvm_driver #(sysmap_cfg_txn); `uvm_component_utils(sysmap_cfg_driver) virtual sysmap_cfg_if vif; endclass
class sysmap_cfg_monitor extends uvm_monitor;                  `uvm_component_utils(sysmap_cfg_monitor) endclass
class sysmap_cfg_sequencer extends uvm_sequencer #(sysmap_cfg_txn); `uvm_component_utils(sysmap_cfg_sequencer) endclass

class sysmap_region_setup_seq    extends uvm_sequence #(sysmap_cfg_txn); `uvm_object_utils(sysmap_region_setup_seq)    endclass
class sysmap_hit_cross_tlb_seq   extends uvm_sequence #(sysmap_cfg_txn); `uvm_object_utils(sysmap_hit_cross_tlb_seq)   endclass
class sysmap_boundary_seq        extends uvm_sequence #(sysmap_cfg_txn); `uvm_object_utils(sysmap_boundary_seq)        endclass
class sysmap_perm_flag_seq       extends uvm_sequence #(sysmap_cfg_txn); `uvm_object_utils(sysmap_perm_flag_seq)       endclass
```

### 7.7 `misc_agent/`

```systemverilog
typedef enum bit [2:0] {
  MISC_RTU_FLUSH,
  MISC_RTU_EXPT,
  MISC_HPCP_CNT_EN,
  MISC_DFT_SCAN_EN,
  MISC_SMP_DISABLE
} misc_op_e;

class misc_txn extends uvm_sequence_item;
  `uvm_object_utils(misc_txn)
  rand misc_op_e op;
  rand bit [26:0] bad_vpn;
  rand bit        flush_pulse;
  rand bit        expt_vld;
  rand bit        cnt_en;
  rand bit        scan_en;
  rand bit        smp_disable;
  // monitor 采样
  bit dutlb_miss, iutlb_miss, jtlb_miss;
  bit [33:0] debug_info;
  function new(string name = "misc_txn");
endclass

class misc_driver    extends uvm_driver #(misc_txn);   `uvm_component_utils(misc_driver)    virtual misc_if vif; endclass
class misc_monitor   extends uvm_monitor;              `uvm_component_utils(misc_monitor)   virtual misc_if vif; uvm_analysis_port #(misc_txn) ap_hpcp; uvm_analysis_port #(misc_txn) ap_debug; endclass
class misc_sequencer extends uvm_sequencer #(misc_txn);`uvm_component_utils(misc_sequencer) endclass

class misc_rtu_flush_seq    extends uvm_sequence #(misc_txn); `uvm_object_utils(misc_rtu_flush_seq)    endclass
class misc_rtu_expt_seq     extends uvm_sequence #(misc_txn); `uvm_object_utils(misc_rtu_expt_seq)     endclass
class misc_hpcp_enable_seq  extends uvm_sequence #(misc_txn); `uvm_object_utils(misc_hpcp_enable_seq)  endclass
class misc_dft_scan_seq     extends uvm_sequence #(misc_txn); `uvm_object_utils(misc_dft_scan_seq)     endclass
class misc_smp_toggle_seq   extends uvm_sequence #(misc_txn); `uvm_object_utils(misc_smp_toggle_seq)   endclass
```

---

## 第 8 章 Env 层骨架

### 8.1 `env/mmu_env_pkg.sv`

```systemverilog
package mmu_env_pkg;
  timeunit 1ns; timeprecision 1ps;
  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;
  // dv_utils
  import clock_driver_pkg::*;
  import reset_driver_pkg::*;
  import bp_pkg::*;
  import watchdog_pkg::*;
  import pulse_gen_pkg::*;
  import memory_response_model_pkg::*;
  import memory_shadow_pkg::*;
  import perf_mon_pkg::*;
  // 7 agent
  import ifu_agent_pkg::*;
  import lsu_agent_pkg::*;
  import cp0_agent_pkg::*;
  import ptw_mem_agent_pkg::*;
  import pmp_agent_pkg::*;
  import sysmap_cfg_agent_pkg::*;
  import misc_agent_pkg::*;
  `include "uvm_macros.svh"
  `include "mmu_top_cfg.svh"
  `include "mmu_page_table_mem.svh"
  `include "mmu_ref_model.svh"
  `include "mmu_translation_sb.svh"
  `include "mmu_invalidate_sb.svh"
  `include "mmu_credit_sb.svh"
  `include "mmu_perf_mon.svh"
  `include "mmu_virtual_sequencer.svh"
  `include "mmu_vseq_lib.svh"
  `include "mmu_env.svh"
endpackage
```

### 8.2 `mmu_top_cfg.svh`

```systemverilog
class mmu_top_cfg extends uvm_object;
  `uvm_object_utils(mmu_top_cfg)
  // Agent active/passive 开关
  uvm_active_passive_enum ifu_active        = UVM_ACTIVE;
  uvm_active_passive_enum lsu_active        = UVM_ACTIVE;
  uvm_active_passive_enum cp0_active        = UVM_ACTIVE;
  uvm_active_passive_enum ptw_mem_active    = UVM_ACTIVE;  // responder
  uvm_active_passive_enum pmp_active        = UVM_ACTIVE;  // responder
  uvm_active_passive_enum sysmap_cfg_active = UVM_ACTIVE;
  uvm_active_passive_enum misc_active       = UVM_ACTIVE;
  // SB 开关
  bit en_translation_sb = 1;
  bit en_invalidate_sb  = 1;
  bit en_credit_sb      = 1;
  bit en_perf_mon       = 1;
  // ref_model 模式
  bit ref_model_strict  = 1;     // 严格 cycle-accurate vs 宽松事务级
  // SVA 开关（与 top bind 联动）
  bit en_sva_arb     = 1;
  bit en_sva_rrpv    = 1;
  bit en_sva_plru    = 1;
  bit en_sva_credit  = 1;
  function new(string name = "mmu_top_cfg");
endclass
```

### 8.3 `mmu_page_table_mem.svh`

```systemverilog
// 共享 shadow 页表存储：ptw_mem_responder 和 ref_model 都引用此对象
class mmu_page_table_mem extends uvm_object;
  `uvm_object_utils(mmu_page_table_mem)
  // 复用 dv_utils memory_shadow（具体类型由 dv_utils 定义）
  // memory_shadow_c m_mem;
  page_table_builder m_builder;
  function new(string name = "mmu_page_table_mem");
  extern function void init();
endclass
```

### 8.4 `mmu_ref_model.svh`

```systemverilog
typedef struct packed {
  bit [27:0] pa;
  mmu_exc_e  exc;
  bit        sec, ca, buf_bit, sh, so, deny;
} xlation_rsp_t;

class mmu_ref_model extends uvm_component;
  `uvm_component_utils(mmu_ref_model)
  // CSR 镜像
  ppn_t     m_satp0_ppn,  m_satp1_ppn;
  asid_t    m_satp0_asid, m_satp1_asid;
  bit [3:0] m_satp0_mode, m_satp1_mode;
  bit       m_satp_sel;
  bit [1:0] m_priv;
  bit       m_mxr, m_sum, m_mprv;
  bit [1:0] m_mpp;
  bit       m_mmu_en, m_ptw_en, m_maee, m_no_op;
  // PMP / SysMap 镜像
  bit [3:0]  m_pmp_flg [PMP_ENTRIES];
  typedef struct {
    bit [27:0] base;
    bit [27:0] mask;
    bit [4:0]  flg;
    bit        enable;
  } sysmap_entry_t;
  sysmap_entry_t m_sysmap [SYSMAP_REGIONS];
  // 共享 shadow 页表
  mmu_page_table_mem m_pt;
  // 当前各 TLB 镜像（事件驱动更新；用于 invalidate_sb 检查）
  // 实现工程师按需扩展：m_shadow_l1_itlb / m_shadow_l1_dtlb / m_shadow_l2tlb

  function new(string name, uvm_component parent);
  // 核心 API
  extern function xlation_rsp_t translate(va_t va, acc_type_e acc);
  extern function bit            check_pmp(pa_t pa, acc_type_e acc, int port_idx);
  extern function sysmap_entry_t lookup_sysmap(pa_t pa);
  // 事件订阅
  extern function void on_csr_write(cp0_txn tr);
  extern function void on_tlb_inv(lsu_txn tr);
  extern function void on_pmp_cfg_change(pmp_txn tr);
  extern function void on_sysmap_cfg_change(sysmap_cfg_txn tr);
endclass
```

### 8.5 Scoreboard 拆分

#### 8.5.1 `mmu_translation_sb.svh`

```systemverilog
class mmu_translation_sb extends uvm_scoreboard;
  `uvm_component_utils(mmu_translation_sb)
  uvm_tlm_analysis_fifo #(ifu_txn) af_ifu_req, af_ifu_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe0, af_lsu_pipe1, af_lsu_pipe2;
  mmu_ref_model m_ref;
  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern task check_ifu();
  extern task check_lsu_pipe(int unsigned pipe_idx);
endclass
```

#### 8.5.2 `mmu_invalidate_sb.svh`

```systemverilog
class mmu_invalidate_sb extends uvm_scoreboard;
  `uvm_component_utils(mmu_invalidate_sb)
  uvm_tlm_analysis_fifo #(lsu_txn) af_inv;
  uvm_tlm_analysis_fifo #(cp0_txn) af_cp0;
  mmu_ref_model m_ref;
  function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);
endclass
```

#### 8.5.3 `mmu_credit_sb.svh`

```systemverilog
// 检查 L1↔L2 credit 守恒、ReqQ/MB 容量上界、PTW MBUF 上界
class mmu_credit_sb extends uvm_scoreboard;
  `uvm_component_utils(mmu_credit_sb)
  // 监听点：ifu_req/rsp、lsu_pipe0/1/2 req/rsp、ptw_mem req/rsp
  // 维护：credit_l1i, credit_l1d, l2_reqq_cnt, l2_mb_cnt, ptw_mbuf_cnt
  function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);
endclass
```

#### 8.5.4 `mmu_perf_mon.svh`

```systemverilog
class mmu_perf_mon extends uvm_component;
  `uvm_component_utils(mmu_perf_mon)
  // 复用 dv_utils perf_mon 基类（如有）
  uvm_tlm_analysis_fifo #(ifu_txn) af_ifu_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_rsp[3];
  uvm_tlm_analysis_fifo #(misc_txn) af_hpcp;
  // 统计
  longint unsigned n_ifu_req, n_ifu_miss;
  longint unsigned n_lsu_req[3], n_lsu_miss[3];
  longint unsigned n_l2_miss, n_walk_complete;
  real             walk_latency_sum;
  function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);
endclass
```

### 8.6 `mmu_virtual_sequencer.svh`

```systemverilog
class mmu_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(mmu_virtual_sequencer)
  ifu_sequencer        ifu_sqr;
  lsu_sequencer        lsu_sqr;
  cp0_sequencer        cp0_sqr;
  pmp_sequencer        pmp_sqr;
  sysmap_cfg_sequencer sysmap_sqr;
  misc_sequencer       misc_sqr;
  // ptw_mem 是 responder，无 sequencer
  function new(string name, uvm_component parent);
endclass
```

### 8.7 `mmu_vseq_lib.svh`（14 个 vseq 类签名）

```systemverilog
class mmu_base_vseq extends uvm_sequence;
  `uvm_object_utils(mmu_base_vseq)
  mmu_virtual_sequencer p_sequencer;
  rand int unsigned num_txn;
  function new(string name = "mmu_base_vseq");
  extern task pre_body();
  extern task body();
endclass

class mmu_smoke_vseq                extends mmu_base_vseq; `uvm_object_utils(mmu_smoke_vseq)                endclass
class mmu_concurrent_3pipe_vseq     extends mmu_base_vseq; `uvm_object_utils(mmu_concurrent_3pipe_vseq)     endclass
class mmu_ptw_thrash_vseq           extends mmu_base_vseq; `uvm_object_utils(mmu_ptw_thrash_vseq)           endclass
class mmu_sfence_during_walk_vseq   extends mmu_base_vseq; `uvm_object_utils(mmu_sfence_during_walk_vseq)   endclass
class mmu_asid_context_switch_vseq  extends mmu_base_vseq; `uvm_object_utils(mmu_asid_context_switch_vseq)  endclass
class mmu_huge_page_mix_vseq        extends mmu_base_vseq; `uvm_object_utils(mmu_huge_page_mix_vseq)        endclass
class mmu_rrpv_aging_vseq           extends mmu_base_vseq; `uvm_object_utils(mmu_rrpv_aging_vseq)           endclass
class mmu_l2tlb_bank_conflict_vseq  extends mmu_base_vseq; `uvm_object_utils(mmu_l2tlb_bank_conflict_vseq)  endclass
class mmu_satp_hotswap_vseq         extends mmu_base_vseq; `uvm_object_utils(mmu_satp_hotswap_vseq)         endclass
class mmu_stress_all_ports_vseq     extends mmu_base_vseq; `uvm_object_utils(mmu_stress_all_ports_vseq)     endclass
class mmu_power_gating_vseq         extends mmu_base_vseq; `uvm_object_utils(mmu_power_gating_vseq)         endclass
class mmu_reset_midtransaction_vseq extends mmu_base_vseq; `uvm_object_utils(mmu_reset_midtransaction_vseq) endclass
class mmu_error_rain_vseq           extends mmu_base_vseq; `uvm_object_utils(mmu_error_rain_vseq)           endclass
class mmu_perf_bench_vseq           extends mmu_base_vseq; `uvm_object_utils(mmu_perf_bench_vseq)           endclass
```

### 8.8 `mmu_env.svh`

```systemverilog
class mmu_env extends uvm_env;
  `uvm_component_utils(mmu_env)
  // 配置
  mmu_top_cfg              m_cfg;
  // 7 agent
  ifu_agent                m_ifu;
  lsu_agent                m_lsu;
  cp0_agent                m_cp0;
  ptw_mem_agent            m_ptw_mem;
  pmp_agent                m_pmp;
  sysmap_cfg_agent         m_sysmap_cfg;
  misc_agent               m_misc;
  // 共享对象
  mmu_page_table_mem       m_pt_mem;
  mmu_ref_model            m_ref;
  // SB
  mmu_translation_sb       m_trans_sb;
  mmu_invalidate_sb        m_inv_sb;
  mmu_credit_sb            m_credit_sb;
  mmu_perf_mon             m_perf;
  // Virtual sequencer
  mmu_virtual_sequencer    m_vseqr;
  // dv_utils 公共
  clock_driver_c           m_clk_drv;
  clock_config_c           m_clk_cfg;
  reset_driver_c #(1'b1,50,0) m_rst_drv;
  watchdog_c               m_watchdog;
  pulse_gen_driver         m_flush_pulse_drv;
  pulse_gen_cfg            m_flush_pulse_cfg;

  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass
```

---

## 第 9 章 Top 层与 SVA

### 9.1 `top/tb_top.sv`

```systemverilog
`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import mmu_env_pkg::*;
  import test_pkg::*;

  bit clk;
  bit rst_n;

  // 7 个 interface 实例
  ifu_if         ifu_vif       (clk, rst_n);
  lsu_if         lsu_vif       (clk, rst_n);
  cp0_if         cp0_vif       (clk, rst_n);
  ptw_mem_if     ptw_mem_vif   (clk, rst_n);
  pmp_if         pmp_vif       (clk, rst_n);
  sysmap_cfg_if  sysmap_cfg_vif(clk, rst_n);
  misc_if        misc_vif      (clk, rst_n);

  // DUT 实例（端口连接清单按 §2.4 端口分组）
  ct_mmu_top u_dut (
    // 时钟复位
    .forever_cpuclk        (clk),
    .cpurst_b              (rst_n),
    // CP0
    .cp0_mmu_cskyee        (cp0_vif.cp0_mmu_cskyee),
    .cp0_mmu_icg_en        (cp0_vif.cp0_mmu_icg_en),
    .cp0_mmu_maee          (cp0_vif.cp0_mmu_maee),
    .cp0_mmu_mpp           (cp0_vif.cp0_mmu_mpp),
    .cp0_mmu_mprv          (cp0_vif.cp0_mmu_mprv),
    .cp0_mmu_mxr           (cp0_vif.cp0_mmu_mxr),
    .cp0_mmu_no_op_req     (cp0_vif.cp0_mmu_no_op_req),
    .cp0_mmu_ptw_en        (cp0_vif.cp0_mmu_ptw_en),
    .cp0_mmu_reg_num       (cp0_vif.cp0_mmu_reg_num),
    .cp0_mmu_satp_sel      (cp0_vif.cp0_mmu_satp_sel),
    .cp0_mmu_sum           (cp0_vif.cp0_mmu_sum),
    .cp0_mmu_tlb_all_inv   (cp0_vif.cp0_mmu_tlb_all_inv),
    .cp0_mmu_wdata         (cp0_vif.cp0_mmu_wdata),
    .cp0_mmu_wreg          (cp0_vif.cp0_mmu_wreg),
    .cp0_yy_priv_mode      (cp0_vif.cp0_yy_priv_mode),
    .mmu_cp0_cmplt         (cp0_vif.mmu_cp0_cmplt),
    .mmu_cp0_data          (cp0_vif.mmu_cp0_data),
    .mmu_cp0_satp_data     (cp0_vif.mmu_cp0_satp_data),
    .mmu_cp0_tlb_done      (cp0_vif.mmu_cp0_tlb_done),
    // HPCP / Debug / SMP / DFT
    .hpcp_mmu_cnt_en       (misc_vif.hpcp_mmu_cnt_en),
    .mmu_hpcp_dutlb_miss   (misc_vif.mmu_hpcp_dutlb_miss),
    .mmu_hpcp_iutlb_miss   (misc_vif.mmu_hpcp_iutlb_miss),
    .mmu_hpcp_jtlb_miss    (misc_vif.mmu_hpcp_jtlb_miss),
    .biu_mmu_smp_disable   (misc_vif.biu_mmu_smp_disable),
    .mmu_had_debug_info    (misc_vif.mmu_had_debug_info),
    .mmu_xx_mmu_en         (cp0_vif.mmu_xx_mmu_en),
    .mmu_yy_xx_no_op       (cp0_vif.mmu_yy_xx_no_op),
    .pad_yy_icg_scan_en    (misc_vif.pad_yy_icg_scan_en),
    // IFU
    .ifu_mmu_va_vld        (ifu_vif.ifu_mmu_va_vld),
    .ifu_mmu_va            (ifu_vif.ifu_mmu_va),
    .ifu_mmu_abort         (ifu_vif.ifu_mmu_abort),
    .mmu_ifu_buf           (ifu_vif.mmu_ifu_buf),
    .mmu_ifu_ca            (ifu_vif.mmu_ifu_ca),
    .mmu_ifu_deny          (ifu_vif.mmu_ifu_deny),
    .mmu_ifu_pa            (ifu_vif.mmu_ifu_pa),
    .mmu_ifu_pavld         (ifu_vif.mmu_ifu_pavld),
    .mmu_ifu_pgflt         (ifu_vif.mmu_ifu_pgflt),
    .mmu_ifu_sec           (ifu_vif.mmu_ifu_sec),
    // LSU Pipe0/1（实现工程师按 lsu_if 字段一一对应连接）
    .lsu_mmu_va0_vld       (lsu_vif.lsu_mmu_va0_vld),
    .lsu_mmu_id0           (lsu_vif.lsu_mmu_id0),
    .lsu_mmu_va0           (lsu_vif.lsu_mmu_va0),
    // ... <按 ct_mmu_top.v 端口顺序补全所有 lsu/pipe2/stamo/inv/data 信号>
    // PTW data 通道
    .mmu_lsu_mmu_en        (ptw_mem_vif.mmu_lsu_mmu_en),
    .mmu_lsu_data_req      (ptw_mem_vif.mmu_lsu_data_req),
    .mmu_lsu_data_req_addr (ptw_mem_vif.mmu_lsu_data_req_addr),
    .mmu_lsu_data_req_size (ptw_mem_vif.mmu_lsu_data_req_size),
    .lsu_mmu_bus_error     (ptw_mem_vif.lsu_mmu_bus_error),
    .lsu_mmu_data_vld      (ptw_mem_vif.lsu_mmu_data_vld),
    .lsu_mmu_data          (ptw_mem_vif.lsu_mmu_data),
    .mmu_lsu_tlb_busy      (ptw_mem_vif.mmu_lsu_tlb_busy),
    .mmu_lsu_tlb_wakeup    (ptw_mem_vif.mmu_lsu_tlb_wakeup),
    // PMP（8 端口 flag 输入 + 8 PA 输出 + 4 fetch_en 输出）
    .pmp_mmu_flg0          (pmp_vif.pmp_mmu_flg0),
    .pmp_mmu_flg1          (pmp_vif.pmp_mmu_flg1),
    .pmp_mmu_flg2          (pmp_vif.pmp_mmu_flg2),
    .pmp_mmu_flg3          (pmp_vif.pmp_mmu_flg3),
    .pmp_mmu_flg4          (pmp_vif.pmp_mmu_flg4),
    .pmp_mmu_flg5          (pmp_vif.pmp_mmu_flg5),
    .pmp_mmu_flg6          (pmp_vif.pmp_mmu_flg6),
    .pmp_mmu_flg7          (pmp_vif.pmp_mmu_flg7),
    .mmu_pmp_pa0           (pmp_vif.mmu_pmp_pa0),
    // ... <补全 pa1..pa7、fetch3/5/6/7>
    // RTU
    .rtu_mmu_bad_vpn       (misc_vif.rtu_mmu_bad_vpn),
    .rtu_mmu_expt_vld      (misc_vif.rtu_mmu_expt_vld),
    .rtu_yy_xx_flush       (misc_vif.rtu_yy_xx_flush)
  );

  // 时钟由 dv_utils clock_driver 接管（下面只是占位，实际由 env 内 m_clk_drv 通过 force/binding 驱动）
  // 实现工程师按 hpdcache_verification/testbench/top/top_axi2mem.sv 模式连接
  initial begin clk = 0; forever #0.5 clk = ~clk; end  // 1 GHz 占位

  // uvm_config_db 设置
  initial begin
    uvm_config_db#(virtual ifu_if)        ::set(null, "*", "IFU_VIF",        ifu_vif);
    uvm_config_db#(virtual lsu_if)        ::set(null, "*", "LSU_VIF",        lsu_vif);
    uvm_config_db#(virtual cp0_if)        ::set(null, "*", "CP0_VIF",        cp0_vif);
    uvm_config_db#(virtual ptw_mem_if)    ::set(null, "*", "PTW_MEM_VIF",    ptw_mem_vif);
    uvm_config_db#(virtual pmp_if)        ::set(null, "*", "PMP_VIF",        pmp_vif);
    uvm_config_db#(virtual sysmap_cfg_if) ::set(null, "*", "SYSMAP_CFG_VIF", sysmap_cfg_vif);
    uvm_config_db#(virtual misc_if)       ::set(null, "*", "MISC_VIF",       misc_vif);
    run_test();
  end

  // SVA bind
  bind mmu_l2tlb       mmu_l2tlb_rrpv_sva u_l2_rrpv_sva (.*);
  bind mmu_arb         mmu_arb_sva        u_arb_sva     (.*);
  bind mmu_l1itlb      mmu_plru_sva       u_l1i_plru    (.*);
  bind mmu_l1dtlb      mmu_plru_sva       u_l1d_plru    (.*);
endmodule
```

### 9.2 SVA 文件清单

| 文件 | 监督对象 | 主要属性 |
|------|---------|---------|
| `top/mmu_sva.sv` | 所有顶层接口 | va_vld 时 va 不为 X / 同期 stall+pavld 互斥 / abort 后 N cycle 内 pavld 不应继续 |
| `top/mmu_arb_sva.sv` | `mmu_arb` | grant one-hot / 优先级链严格 PTW>TLBOp>ReqQ>PFU / work-conserving |
| `top/mmu_l2tlb_rrpv_sva.sv` | `mmu_l2tlb` 内 RRPV 阵列 | hit 后 promote=0 / miss 后 +1 饱和 / new fill 初值=4 |
| `top/mmu_plru_sva.sv` | `mmu_l1itlb` / `mmu_l1dtlb` | PLRU 树更新规则、victim 选择正确 |
| `top/credit_sva.sv` | L1↔L2 credit / ReqQ / MB | outstanding ≤ MAX、credit 守恒（issue+return-net=0） |

每个 SVA 文件采用 `module <name>(...)` 结构，通过 `bind` 绑定到 RTL 实例（参考 [hpdcache_verification/testbench/top/hpdcache_fxarb_sva.sv](../hpdcache_verification/testbench/top/hpdcache_fxarb_sva.sv)）。

---

## 第 10 章 Covergroup 实现侧落点

> 仅列出 **位置 / 触发时钟 / coverpoint 字段表**。覆盖率目标值（百分比、豁免）见 [VerificationPlan §7](MMU_VerificationPlan.md#7-覆盖率计划coverage-plan)。

### 10.1 黑盒 covergroup（在各 agent 内）

| Covergroup | 文件 | 触发 | Coverpoint / Cross |
|-----------|------|------|--------------------|
| `cg_ifu_req` | `ifu_covergroups.svh` | `posedge clk_i iff vif.ifu_mmu_va_vld` | cp_va_seg(va[62:39] 4 bin), cp_abort |
| `cg_ifu_rsp` | 同 | `posedge clk_i iff vif.mmu_ifu_pavld` | cp_pgflt, cp_deny, cp_sec, cross(pgflt,deny) |
| `cg_lsu_pipe[2]` | `lsu_covergroups.svh` | `posedge clk_i iff vif.lsu_mmu_va<i>_vld` | cp_op{LD,ST}, cp_st_inst, cp_abort, cp_stall, cp_pa_vld, cp_pgflt, cp_access_fault, cross(op,pgflt,access_fault) |
| `cg_lsu_pipe2` | 同 | `posedge clk_i iff vif.lsu_mmu_va2_vld` | cp_va2_vld, cp_pa2_vld, cp_pa2_err, cp_share2, cp_sec2 |
| `cg_lsu_inv` | 同 | `posedge clk_i iff (vif.lsu_mmu_tlb_*_inv)` | cp_kind{ALL,VA,ASID,VA_ASID}, cp_during_ptw, cp_inv_done_latency |
| `cg_cp0` | `cp0_covergroups.svh` | `posedge clk_i iff vif.cp0_mmu_wreg \|\| <priv 切换>` | cp_priv, cp_mxr, cp_sum, cp_mprv, cp_mpp, cp_satp_mode, cross(priv,mxr,sum,mprv) |
| `cg_pmp` | `pmp_covergroups.svh` | `posedge clk_i` | cp_entry_hit(0..7), cp_acc_type, cp_violation, cross(entry,acc_type) |
| `cg_sysmap` | `sysmap_cfg_covergroups.svh` | 配置变更脉冲 | cp_region(0..7), cp_attr(sec/ca/buf/sh/so) |
| `cg_hpcp` | `misc_covergroups.svh` | `posedge clk_i iff hpcp_mmu_cnt_en` | cp_iutlb_miss, cp_dutlb_miss, cp_jtlb_miss |

### 10.2 白盒 covergroup（在 env 内通过 bind / hierarchical reference）

| Covergroup | bind 目标 | Coverpoint / Cross |
|-----------|----------|--------------------|
| `cg_ptw_walk` | `ptw.sv` 内部 | cp_walk_depth(1/2/3), cp_leaf_level(L0/L1/L2), cp_fault{V,R,W,X,U,A,D,PMP,BUS}, cp_acc_type, cross(walk_depth, acc_type, fault) |
| `cg_l2tlb_bank` | `mmu_l2tlb.sv` 内部 | cp_bank(0..7), cp_way(0..7), cp_pgs, cp_refill_source{PTW,DIRECT}, cp_rrpv(0..7), cross(bank,way) |
| `cg_l1itlb` | `mmu_l1itlb.sv` 内部 | cp_entry_vld_count, cp_credit_remain, cp_fsm_state |
| `cg_l1dtlb` | `mmu_l1dtlb.sv` 内部 | cp_mb_occupancy, cp_fsm_state |
| `cg_l2_reqq` | `mmu_l2tlb_reqq.sv` | cp_alloc_idx(0..8), cp_depth(0..9), cp_credit_back |
| `cg_tlboper_fsm` | `ct_mmu_tlboper.v` | cp_fsm_state（7 个 FSM 状态全采样） |

### 10.3 覆盖率合并配置

`scripts/cov_hier.cfg`（复制自 hpdcache 并改前缀）：包含 / 排除按 `tb_top.u_dut.*` 树状路径过滤；testbench 自身代码覆盖率排除。

---

## 第 11 章 Test 基类骨架

### 11.1 `test/test_base.svh`

```systemverilog
class test_base extends uvm_test;
  `uvm_component_utils(test_base)
  mmu_env       env;
  mmu_top_cfg   m_cfg;
  uvm_table_printer printer;
  // +plusarg
  int unsigned  num_txn;
  int unsigned  timeout_ns;
  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern task          run_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);
endclass
```

### 11.2 测试目录划分

参考 [VerificationPlan §6.3](MMU_VerificationPlan.md#63-test-case-详表)：

| 目录 | 涵盖 F-ID | TC 数（参考） |
|------|----------|------------|
| `basic_tests/` | 跨多类 | 3 |
| `l1itlb_tests/` | F1 | ≈12 |
| `l1dtlb_tests/` | F2 | ≈14 |
| `l2tlb_tests/` | F3 | ≈14 |
| `ptw_tests/` | F4 | ≈17 |
| `tlbop_tests/` | F8 | ≈10 |
| `pmp_tests/` | F7 | ≈8 |
| `sysmap_tests/` | F6 | ≈4 |
| `cp0_tests/` | F9 | ≈13 |
| `flush_tests/` | F10/F13 | ≈6 |
| `cross_tests/` | 跨多类 | ≈16 |
| `perf_tests/` | F11/F14 | ≈8 |
| `err_tests/` | F12/异常 | ≈8 |

### 11.3 测试类模板（仅签名）

```systemverilog
class test_mmu_<category>_<scenario> extends test_base;
  `uvm_component_utils(test_mmu_<category>_<scenario>)
  function new(string name, uvm_component parent);
  extern task main_phase(uvm_phase phase);
endclass
```

### 11.4 +plusarg 协议

| Plusarg | 类型 | 默认值 | 用途 |
|---------|------|--------|------|
| `+TEST_NAME=<name>` | string | （Makefile 传） | UVM 启动测试 |
| `+UVM_TESTNAME=<name>` | string | 同上 | UVM 标准 |
| `+SEED=<int>` | int | random | VCS `+ntb_random_seed` |
| `+NB_TXNS=<int>` | int | 5000 | 主激励数量 |
| `+UVM_VERBOSITY=<lvl>` | string | UVM_MEDIUM | 日志级别 |
| `+TIMEOUT=<ns>` | int | 10000000 | watchdog 超时 |

---

## 第 12 章 编译与运行

### 12.1 `testbench/Files.f`（完整编译顺序）

```
# === dv_utils 基础 ===
-F ${CV_DV_UTILS_DIR}/uvm/Files.f

# === MMU params ===
${PROJECT_DIR}/modules/mmu_params/mmu_params_pkg.sv

# === Common ===
${PROJECT_DIR}/testbench/common/mmu_common_pkg.sv

# === Interfaces ===
${PROJECT_DIR}/testbench/ifu_agent/ifu_if.sv
${PROJECT_DIR}/testbench/lsu_agent/lsu_if.sv
${PROJECT_DIR}/testbench/cp0_agent/cp0_if.sv
${PROJECT_DIR}/testbench/ptw_mem_agent/ptw_mem_if.sv
${PROJECT_DIR}/testbench/pmp_agent/pmp_if.sv
${PROJECT_DIR}/testbench/sysmap_cfg_agent/sysmap_cfg_if.sv
${PROJECT_DIR}/testbench/misc_agent/misc_if.sv

# === Agent packages ===
${PROJECT_DIR}/testbench/ifu_agent/ifu_agent_pkg.sv
${PROJECT_DIR}/testbench/lsu_agent/lsu_agent_pkg.sv
${PROJECT_DIR}/testbench/cp0_agent/cp0_agent_pkg.sv
${PROJECT_DIR}/testbench/ptw_mem_agent/ptw_mem_agent_pkg.sv
${PROJECT_DIR}/testbench/pmp_agent/pmp_agent_pkg.sv
${PROJECT_DIR}/testbench/sysmap_cfg_agent/sysmap_cfg_agent_pkg.sv
${PROJECT_DIR}/testbench/misc_agent/misc_agent_pkg.sv

# === Env ===
${PROJECT_DIR}/testbench/env/mmu_env_pkg.sv

# === Test ===
${PROJECT_DIR}/testbench/test/test_pkg.sv

# === SVA ===
${PROJECT_DIR}/testbench/top/mmu_sva.sv
${PROJECT_DIR}/testbench/top/mmu_arb_sva.sv
${PROJECT_DIR}/testbench/top/mmu_l2tlb_rrpv_sva.sv
${PROJECT_DIR}/testbench/top/mmu_plru_sva.sv
${PROJECT_DIR}/testbench/top/credit_sva.sv

# === DUT ===
+incdir+${MMU_RTL_DIR}
${MMU_RTL_DIR}/sysmap.h
${MMU_RTL_DIR}/ct_spram_wrapper.sv
${MMU_RTL_DIR}/ct_spsram_256x196.v
${MMU_RTL_DIR}/ct_spsram_256x84.v
${MMU_RTL_DIR}/ct_mmu_sysmap_hit.v
${MMU_RTL_DIR}/ct_mmu_sysmap.v
${MMU_RTL_DIR}/ct_mmu_regs.v
${MMU_RTL_DIR}/ct_mmu_dplru.v
${MMU_RTL_DIR}/ct_mmu_iplru.v
${MMU_RTL_DIR}/pplru.sv
${MMU_RTL_DIR}/ct_mmu_dutlb_entry.v
${MMU_RTL_DIR}/ct_mmu_dutlb_huge_entry.v
${MMU_RTL_DIR}/ct_mmu_iutlb_entry.v
${MMU_RTL_DIR}/ct_mmu_iutlb_fst_entry.v
${MMU_RTL_DIR}/mmu_l1dtlb_mb_entry.sv
${MMU_RTL_DIR}/mmu_l1dtlb_allocator.sv
${MMU_RTL_DIR}/mmu_l1dtlb_scheduler.sv
${MMU_RTL_DIR}/mmu_l1dtlb_hit_rd.sv
${MMU_RTL_DIR}/mmu_l1dtlb_install.sv
${MMU_RTL_DIR}/mmu_l1dtlb.sv
${MMU_RTL_DIR}/mmu_l1itlb.sv
${MMU_RTL_DIR}/ct_mmu_l2tlb_tag_array.sv
${MMU_RTL_DIR}/ct_mmu_l2tlb_data_array.sv
${MMU_RTL_DIR}/ct_mmu_l2tlb_rrpv_array.sv
${MMU_RTL_DIR}/mmu_l2tlb_rrpv_wbuf.sv
${MMU_RTL_DIR}/mmu_l2tlb_replacement_policy.sv
${MMU_RTL_DIR}/mmu_l2tlb_reqq_entry.sv
${MMU_RTL_DIR}/mmu_l2tlb_reqq.sv
${MMU_RTL_DIR}/mmu_l2tlb_mb_entry.sv
${MMU_RTL_DIR}/mmu_l2tlb_mb.sv
${MMU_RTL_DIR}/mmu_l2tlb.sv
${MMU_RTL_DIR}/mbuf_entry.sv
${MMU_RTL_DIR}/ptw_mbuf.sv
${MMU_RTL_DIR}/twu.sv
${MMU_RTL_DIR}/one_to_four_xbar.sv
${MMU_RTL_DIR}/PDE_cache.sv
${MMU_RTL_DIR}/L1PDE_cache.sv
${MMU_RTL_DIR}/L2PDE_cache.sv
${MMU_RTL_DIR}/ptw.sv
${MMU_RTL_DIR}/mmu_arb.sv
${MMU_RTL_DIR}/ct_mmu_tlboper.v
${MMU_RTL_DIR}/ct_mmu_top.v
${MMU_RTL_DIR}/mmu_fpga_ram.sv

# === TB top ===
${PROJECT_DIR}/testbench/top/tb_top.sv
```

> **依赖顺序原则**（写入文件首注释）：dv_utils → params → common → if → agent_pkg → env_pkg → test_pkg → SVA → DUT → tb_top。

### 12.2 Makefile 关键 target

| Target | 说明 |
|--------|------|
| `compile` | VCS 编译生成 simv |
| `run` | 运行单个 TEST_NAME |
| `wave` | Verdi 加载 fsdb |
| `cov_merge` | URG 合并各次仿真覆盖率 |
| `cov_report` | 生成 HTML 覆盖率报告 |
| `regress` | 调用 `scripts/run_test.py` 跑 regression list |
| `clean` | 清理 output |

### 12.3 单测试运行命令样例

```bash
make run TEST_NAME=test_mmu_sanity_ifu SEED=12345 VERBOSITY=UVM_HIGH
make wave TEST_NAME=test_mmu_sanity_ifu
make regress LIST=simu/mmu_smoke_list
```

### 12.4 `simu/run.do`（Verdi）

参考 [hpdcache_verification/scripts/sim/](../hpdcache_verification/scripts/sim/) 内同名脚本，仅改 fsdb 路径与 top 模块名。

---

## 第 13 章 实施落地阶段（10 个 Phase）

> 每个 Phase **必须**在前一个 Phase 退出准则全部满足后才开始；每个 Phase 都可独立验证。

### Phase 1：环境骨架（编译框架打通）

- **交付文件**：
  - `mmu_verification/` 目录结构（按 §3.1）
  - `modules/dv_utils/`（整块复制 + `VERSION.txt`）
  - `scripts/`（整块复制）
  - `Makefile`（裁剪自 hpdcache）
  - `setup_env.sh` / `setup_env.csh`
  - `testbench/Files.f`（按 §12.1，但仅含 dv_utils + 空 `tb_top.sv`）
  - `testbench/top/tb_top.sv`：仅 module 定义 + 时钟 + uvm_pkg import + run_test()
- **退出准则**：`make compile` 通过；`make run TEST_NAME=uvm_test_top` 跑 0 cycle 退出无错。

### Phase 2：DUT 接入与 Interface 连接

- **交付文件**：
  - `modules/mmu_params/mmu_params_pkg.sv`（§5.1 完整内容）
  - `testbench/common/mmu_common_pkg.sv`（§5.2 完整内容，函数体可留 TODO）
  - 7 个 `*_if.sv`（§6 全部）
  - `testbench/top/tb_top.sv`：接入 DUT、所有 interface 实例化、`uvm_config_db::set` 调用
  - `testbench/Files.f`：按 §12.1 加入 DUT 全部 RTL 与 interface
- **退出准则**：`make compile` + `make run` 通过；DUT elaboration 0 错误（仅信号未驱动 X 警告允许）；空 `uvm_test_top` 跑完即退。

### Phase 3：最简 Active Agent + Sanity Test

- **交付范围**：`cp0_agent` + `pmp_agent` + `sysmap_cfg_agent` 八件套（仅 driver 实现 set CSR / 拉 PMP flag / 配 SysMap region 的最简任务）
- **交付文件**：3 × 9 = 27 文件 + `mmu_env_pkg.sv` 骨架 + `mmu_top_cfg.svh` + `mmu_env.svh`（仅 build 这三个 agent）+ `test_pkg.sv` + `test_base.svh` + `test_mmu_sanity_csr_pmp_sysmap.svh`
- **退出准则**：sanity 测试中 cp0/pmp/sysmap 配置完成后无 UVM_ERROR；DUT `mmu_xx_mmu_en` 拉高。

### Phase 4：PTW 内存模型 + Reference Model（最小翻译）

- **交付范围**：`ptw_mem_agent` 完整十件套 + `mmu_page_table_mem.svh` + `mmu_ref_model.svh`（仅实现 `translate()` 的 happy path：4K 页 + R/W/X 全开 + U=0 + S 模式访问）
- **交付文件**：10 + 2 = 12 文件
- **退出准则**：
  1. `page_table_builder.map_4k()` 写入页表 → `ptw_mem_responder` 能正确响应 PTE 读
  2. ref_model 对一个测试 VA 的 `translate()` 返回与 RTL 走 PTW 后 IFU/LSU 的 PA 一致（即使 IFU/LSU agent 还没接，可由 cp0_agent 配 SATP 后用直驱 IFU vif 信号验证）

### Phase 5：IFU + LSU Agent + Translation SB

- **交付范围**：`ifu_agent` + `lsu_agent` 完整八件套 + `mmu_translation_sb.svh`
- **交付文件**：2 × 9 + 1 = 19 文件
- **退出准则**：
  1. IFU 单端口随机 VA 100 次，全部命中 ref_model 预测
  2. LSU pipe0 单端口 100 次 LD，全部命中
  3. 引入 miss → PTW → refill 后命中：100 次混合，0 mismatch

### Phase 6：misc_agent + TLB 失效 + Invalidate SB

- **交付范围**：`misc_agent` 八件套 + `lsu_agent` 中 `drive_inv` 子线程实现 + `mmu_invalidate_sb.svh`
- **交付文件**：9 + 1 = 10 文件（lsu 已存在，仅补 inv 子线程方法体）
- **退出准则**：
  1. SFENCE.VMA 4 种模式各 50 次，invalidate_sb 0 mismatch
  2. RTU flush 注入下，PTW 中途 abort 行为正确（`tlb_busy` 清零、`mmu_lsu_tlb_inv_done` 脉冲）

### Phase 7：Covergroup + SVA bind

- **交付范围**：所有 `*_covergroups.svh`（§10.1 黑盒部分）+ env 内白盒 covergroup（§10.2，通过 hierarchical reference）+ 5 个 SVA 文件
- **交付文件**：7（agent 内 cg）+ 1（env 内白盒 cg 集中文件，可放入 `mmu_perf_mon.svh` 旁边）+ 5（SVA）
- **退出准则**：编译通过；smoke 测试报告显示所有 covergroup 至少有 1 个 hit；SVA 0 fire（vacuous 也接受）。

### Phase 8：Virtual Sequence 实现

- **交付范围**：`mmu_virtual_sequencer.svh` + `mmu_vseq_lib.svh` 全 14 个 vseq 的 `body()` 实现
- **退出准则**：14 个 vseq 各运行一次，0 UVM_ERROR / 0 SVA fail / 全部 SB 0 mismatch。

### Phase 9：测试用例填充

- **交付范围**：按 [VerificationPlan §6.3](MMU_VerificationPlan.md#63-test-case-详表) 列表逐条创建 test class（每个 test class 通常 < 50 行：调用 1–N 个 sequence + 配置环境 + 设定 num_txn）
- **退出准则**：所有 test 单跑通过；冒烟列表 100% 通过。

### Phase 10：回归脚本 + 覆盖率收敛

- **交付范围**：
  - `simu/mmu_smoke_list` / `mmu_nightly_list` / `mmu_coverage_list`（内容见 [VerificationPlan §8](MMU_VerificationPlan.md#8-回归测试策略regression-strategy)）
  - `simu/exclude.do`（覆盖率豁免）
  - `Makefile` 添加 `regress` target
- **退出准则**：参考 [VerificationPlan §9 签核标准](MMU_VerificationPlan.md#9-签核标准signoff-criteria)。

### 阶段交付物总量

| Phase | 新建文件数 | 累计文件数 |
|-------|-----------|----------|
| 1 | ≈ 8 | 8 |
| 2 | ≈ 10 | 18 |
| 3 | ≈ 30 | 48 |
| 4 | ≈ 12 | 60 |
| 5 | ≈ 19 | 79 |
| 6 | ≈ 10 | 89 |
| 7 | ≈ 13 | 102 |
| 8 | ≈ 0（仅填充） | 102 |
| 9 | ≈ 120（test case 文件） | 222 |
| 10 | ≈ 4（回归列表 + exclude） | 226 |

---

## 附录 A：v2 → v3 变更映射

| v2 章节 | 内容 | v3 处理 | 归宿 |
|---------|------|---------|------|
| Part A 前置决策 | 工具链 / dv_utils 复用 | ✅ 保留并扩充（新增 Agent 划分表 + hpdcache 对位映射） | v3 §1 |
| Part B.1 顶层互联 | 框图 | ✅ 保留 | v3 §2.1 |
| Part B.2 子模块参数 | 参数冻结表 | ✅ 保留 | v3 §2.2 |
| Part B.3 关键 FSM | 12 个 FSM | ✅ 保留 | v3 §2.3 |
| Part B.4 CP0 寄存器位 | 寄存器位影响表 | ✅ 保留 | v3 §2.5 |
| Part C.0–C.13 测试点 196 个 TP-XXX | 测试点列表 | ❌ **剥离** | [VerificationPlan §5（F1–F14 功能点）](MMU_VerificationPlan.md#5-待验证功能点列表feature-list) |
| Part C.14 测试点→用例映射 | 110+ 测试用例映射 | ❌ **剥离** | [VerificationPlan §6.3](MMU_VerificationPlan.md#63-test-case-详表) |
| Part D.1 mmu_params_pkg | 包骨架 | ✅ 保留 | v3 §5.1 |
| Part D.2 mmu_common_pkg | 工具函数 | ✅ 保留并精简（仅签名） | v3 §5.2 |
| Part D.3–D.8 各 agent 骨架 | 类签名 + 部分方法体 | ✅ **保留 + 精简方法体** | v3 §6, §7, §8 |
| Part D.9 Files.f | 编译顺序 | ✅ 保留并扩充 misc_agent | v3 §12.1 |
| Part D.10 Makefile 变量 | 关键变量 | ✅ 保留 | v3 §4.3, §12 |
| Part D.11 目录全量清单 | 目录树 | ✅ 保留并扩充至 misc_agent / sysmap_cfg_agent / vseq_lib | v3 §3.1 |
| Part E.1 代码覆盖率目标 | 99% / 98% | ❌ **剥离目标值** | [VerificationPlan §7](MMU_VerificationPlan.md#7-覆盖率计划coverage-plan) |
| Part E.2 功能 covergroup 表 | covergroup 字段表 | ✅ 保留 | v3 §10 |
| Part E.3 SVA 文件 | SVA 清单 | ✅ 保留 | v3 §9.2 |
| Part F.1 回归列表 | smoke / nightly / coverage list | ❌ **剥离** | [VerificationPlan §8](MMU_VerificationPlan.md#8-回归测试策略regression-strategy) |
| Part F.2 签核矩阵 | 签核条目表 | ❌ **剥离** | [VerificationPlan §9](MMU_VerificationPlan.md#9-签核标准signoff-criteria) |
| —（v2 无） | 实施落地 10 阶段 | ✨ **新增** | v3 §13 |
| —（v2 无） | 端口分组→Agent 映射 | ✨ **新增** | v3 §2.4 |
| —（v2 无） | 与 hpdcache 框架对位映射 | ✨ **新增** | v3 §1.3 |
| —（v2 无） | 文档定位与范围声明 | ✨ **新增** | v3 §0 |

---

## 附录 B：与 VerificationPlan 引用对照表

| 本文档章节 | 引用 VerificationPlan |
|-----------|---------------------|
| §0.2（不写内容清单） | §5 / §6 / §7 / §8 / §9 / §10 / §11 |
| §2.5（CP0 寄存器位） | §2.5 配置空间 |
| §3.3（测试用例数） | §6 测试用例计划 |
| §10（covergroup 落点） | §7 覆盖率计划（目标值） |
| §11.2（测试目录） | §6.3 Test Case 详表 |
| §13 Phase 9（测试用例填充） | §6.3 Test Case 详表 |
| §13 Phase 10（回归脚本） | §8 回归策略 + §9 签核标准 |

---

## 附录 C：与 hpdcache_verification 文件复用对位

| MMU UVM 文件 | hpdcache_verification 参考 |
|---|---|
| [Makefile](../mmu_verification/Makefile)（待建） | [hpdcache_verification/Makefile](../hpdcache_verification/Makefile) |
| `testbench/Files.f` | [hpdcache_verification/testbench/Files.f](../hpdcache_verification/testbench/Files.f) |
| `testbench/common/mmu_common_pkg.sv` | [hpdcache_common_pkg.sv](../hpdcache_verification/testbench/common/hpdcache_common_pkg.sv) |
| `ifu_agent/*` / `lsu_agent/*` | [hpdcache_agent/*](../hpdcache_verification/testbench/hpdcache_agent/) |
| `cp0_agent/*` | [conf_and_perf_agent/*](../hpdcache_verification/testbench/conf_and_perf_agent/) |
| `ptw_mem_agent/*` | [dram_mon/*](../hpdcache_verification/testbench/dram_mon/) + dv_utils `memory_response_model` |
| `env/mmu_env.svh` | [env/hpdcache_env.svh](../hpdcache_verification/testbench/env/hpdcache_env.svh) |
| `env/mmu_translation_sb.svh` | [env/hpdcache_sb.svh](../hpdcache_verification/testbench/env/hpdcache_sb.svh) |
| `env/mmu_top_cfg.svh` | [env/hpdcache_top_cfg.svh](../hpdcache_verification/testbench/env/hpdcache_top_cfg.svh) |
| `top/tb_top.sv` | [top/top_axi2mem.sv](../hpdcache_verification/testbench/top/top_axi2mem.sv) |
| `top/mmu_arb_sva.sv` | [top/hpdcache_fxarb_sva.sv](../hpdcache_verification/testbench/top/hpdcache_fxarb_sva.sv) |
| `top/mmu_plru_sva.sv` | [top/hpdcache_plru_sva.sv](../hpdcache_verification/testbench/top/hpdcache_plru_sva.sv) |
| `top/credit_sva.sv` | [top/hpdcache_sva.sv](../hpdcache_verification/testbench/top/hpdcache_sva.sv) |
| `test/test_base.svh` | [test/test_base.svh](../hpdcache_verification/testbench/test/test_base.svh) |
| `test/test_pkg.sv` | [test/test_pkg.sv](../hpdcache_verification/testbench/test/test_pkg.sv) + [test/hpdcache_test_pkg.sv](../hpdcache_verification/testbench/test/hpdcache_test_pkg.sv) |
| `scripts/*` | [hpdcache_verification/scripts/](../hpdcache_verification/scripts/) |
| `modules/dv_utils/*` | [hpdcache_verification/modules/dv_utils/](../hpdcache_verification/modules/dv_utils/) |

---

**文档结束。** 工程师可从 **Phase 1：环境骨架** 开始，按 [§13 实施落地阶段](#第-13-章实施落地阶段10-个-phase) 逐 Phase 落地。
