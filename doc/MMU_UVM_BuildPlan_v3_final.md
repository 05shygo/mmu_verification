# MMU UVM 验证环境搭建计划 — v3 终版（代码搭建蓝图）

> **文档版本**：v3.0（Final, Code Skeleton Only）
> **日期**：2026-04-22
> **适用 DUT**：`mmu/rtl/ct_mmu_top.v`（OpenRISCV2030 MMU，Sv39）
> **参考框架**：[hpdcache_verification/](../hpdcache_verification/)（UVM 1.2 + VCS/Verdi）
> **验证计划**：[MMU_VerificationPlan.md](MMU_VerificationPlan.md)（功能点 / 测试用例 / 覆盖率目标 / 回归 / 签核）
> **历史版本**：[MMU_UVM_搭建计划_v2_代码级.md](MMU_UVM_搭建计划_v2_代码级.md)（保留作历史）
> **Phase 14 Closure Owner**：[MMU_Phase14_ClosureOwner.md](MMU_Phase14_ClosureOwner.md)

| 版本                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | 日期       | 作者              | 变更说明                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| v2.0                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | 2026-04-22 | Verification Team | 初版细化代码级计划（含测试点/回归）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| v3.0                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | 2026-04-22 | Verification Team | 终版：剥离测试点/覆盖率目标/回归/签核到 VerificationPlan；扩充文件骨架与实施阶段                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| v3.0 Final                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | 2026-04-22 | Verification Team | 对齐 `MMU_VerificationPlan_v3.md`：吸收 plan_v1/v2/v3 三轮完善（6 条错判降级、2 条删除、4 条真实缺陷 P0 升级、5 条 v3 新缺陷、F4.42a/b/c PTW→LSU 协议补强、接口表第 13/14 组补齐、5 个新 covergroup、9 条新 SVA、R19/R20 风险新增）。新增 `bug_hunt_tests/` 与 `ptw_lsu_protocol_tests/` 测试子目录、`mmu_ptw_lsu_protocol_sva.sv`、`mmu_twu_sva.sv`；§13 追加 Phase 11 v3.0 Gap-driven 回归。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| v3.0 Final+ | 2026-04-22 | Verification Team | TWU/MBUF architecture clarification: TWU is a 6-stage pipeline, twu_mask is per-TWU self-stall, PTW MBUF does not backpressure TWU by fullness; latest tlb_busy protocol is L1 DTLB MB non-empty (|mb_entry_vld), not PTW MBUF full. Added coverage/SVA for TWU occupancy, MBUF invariants, and tlb_busy source independence. |
| （对齐 MMU_VerificationPlan_v3.md F2.NEW.3-6 / F3.NEW.2-5 / F4.NEW.6-14 / F5.16 / F6.NEW.1-7 / F7.NEW.3-9）：新增 76 条 TC（含 L1DTLB MMU-off 广播、L2TLB req_is_load 标志、双信号回填语义、PTW ready 反压、TWU MAEE 双路属性选路、PMP 三级序列化、sysmap flag 替换与跨界降级、PTW PMP 端口映射等）；新增 SVA 文件 `mmu_maee_twu_sva.sv` / `mmu_pmp_twu_sva.sv` / `mmu_sysmap_sva.sv`；新增 30+ covergroup；新增测试子目录 `maee_twu_tests/` / `pmp_twu_tests_v6/`；`pmp_if.sv` 修正 RTL typo `mmu_pmp_fecth7`（ptw.sv:L62）并添加 DA-003 端口分配注释；§13 追加 Phase 12/13/14。 |            |                   |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| v3.1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | 2026-04-25 | Verification Team | 新增 IFU miss-hold 与 LSU expt lifecycle UVM 实现约束：IFU non-abort miss pending 期间禁止新 PC 请求（严格 hold）；LSU 异常处理采用“产生→挂起→唤醒→回放命中→消费删除”语义，并在 scoreboard 中区分 replay fault 与普通翻译比较路径。 |

---

### Phase 13 F7.NEW.7 Errata (2026-05-02)

- `mmu_pmp_fetch{3,5,6,7}` / internal `mmu_pmp_fecth` is the original miss fetch sideband for the walk, not the PTW PTE bus-read command type.
- The old `sva_ptw_pmp_fetch_zero` intent is retired. Active Phase 13 checks are `sva_pmp_fetch_matches_grant_stage` and `sva_pmp_deny_uses_original_type_perm`.
- PMP permission selection for PTW ports follows the original access type: fetch->X (`flg[2]`), load/prefetch->R (`flg[0]`), store->W (`flg[1]`), with M-mode L=0 bypass.

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

| 不写                                              | 去哪里看                                                                                              |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 待验证功能点列表（F1–F14, 共 100+ 条）           | [VerificationPlan.md §5](MMU_VerificationPlan.md#5-待验证功能点列表feature-list)                        |
| 测试用例详表（TC-XXX，共 120+ 条，含通过标准）    | [VerificationPlan.md §6.3](MMU_VerificationPlan.md#63-test-case-详表)                                   |
| 覆盖率目标百分比 / 豁免机制                       | [VerificationPlan.md §7](MMU_VerificationPlan.md#7-覆盖率计划coverage-plan)                             |
| 回归测试列表（smoke / nightly / coverage）        | [VerificationPlan.md §8](MMU_VerificationPlan.md#8-回归测试策略regression-strategy)                     |
| 签核标准 / Signoff Checklist                      | [VerificationPlan.md §9](MMU_VerificationPlan.md#9-签核标准signoff-criteria)                            |
| 资源与时间表 / 风险评估                           | [VerificationPlan.md §10–§11](MMU_VerificationPlan.md#10-资源与时间表resources--schedule)             |
| Sv39 规范细节 / DUT 行为决策（refmodel 算法语义） | [VerificationPlan.md §3.3](MMU_VerificationPlan.md#33-参考模型reference-model) + RISC-V Privileged Spec |
| SystemVerilog 方法体 / 算法伪代码                 | 由代码实现工程师在 Phase 4–8 编写                                                                    |

### 0.3 阅读对象

UVM 代码实现工程师 / Coding AI（具备 SystemVerilog + UVM 1.2 基础，无需理解 MMU 架构细节，按本文档建文件 → 填类签名 → 引用 VerificationPlan 写方法体）。

---

## 第 1 章 前置决策冻结

### 1.1 工具链与方法学

| 项         | 决策                              | 备注                                                                 |
| ---------- | --------------------------------- | -------------------------------------------------------------------- |
| 分页模式   | 仅 Sv39                           | 3 级、VPN=27、PPN=28、PA=40、PTE=64 bit                              |
| 仿真器     | Synopsys VCS                      | 复用 hpdcache 的 Makefile/run.do                                     |
| 调试器     | Verdi                             | 配套 `novas.conf`                                                  |
| 覆盖率合并 | URG                               | 参考 `cov_hier.cfg`                                                |
| UVM 版本   | UVM 1.2                           | `-ntb_opts uvm-1.2`                                                |
| HVL        | SystemVerilog 2012                |                                                                      |
| 脚本       | Python 3.9 + Perl                 | 复用 hpdcache `scripts/`                                           |
| 工作目录   | `mmu_verification/`             | 与 `hpdcache_verification/` **平级**                         |
| RTL 引用   | `Files.f` 引用 `../mmu/rtl/*` | 不复制 RTL 源码，避免冗余                                            |
| dv_utils   | **整块复制**                | 复制到 `mmu_verification/modules/dv_utils/`，VERSION.txt 锁 commit |
| scripts    | **整块复制**                | `mmu_verification/scripts/`，按需裁剪                              |

### 1.2 Agent 划分（冻结为 7 个）

| # | Agent                | 类型           | 对应 DUT 接口组                                                                                                                                                                                                                               | 复用源                                             |
| - | -------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| 1 | `ifu_agent`        | Active         | IFU 取指（`ifu_mmu_*` / `mmu_ifu_*`）                                                                                                                                                                                                     | 新写，参考 `hpdcache_agent`                      |
| 2 | `lsu_agent`        | Active         | LSU Pipe0/1/2/STAMO + TLB Inv 子通道（`lsu_mmu_*0/1/2`、`lsu_mmu_stamo_*`、`lsu_mmu_tlb_*inv*`）                                                                                                                                        | 新写，5 子线程 driver                              |
| 3 | `cp0_agent`        | Active         | CP0/CSR（`cp0_mmu_*` / `mmu_cp0_*` / `cp0_yy_priv_mode`）                                                                                                                                                                               | 新写，参考 `conf_and_perf_agent`                 |
| 4 | `ptw_mem_agent`    | Responder      | PTW 数据通道（`mmu_lsu_data_*` / `lsu_mmu_data*` / `lsu_mmu_bus_error`）；**v7.3 修订**：`mmu_lsu_tlb_busy` / `mmu_lsu_tlb_wakeup[11:0]` / `mmu_lsu_mmu_en` 已移至 `lsu_agent`（L1DTLB → LSU 广播子分组 `tlb_status`） | 复用 `memory_response_model` + `memory_shadow` |
| 5 | `pmp_agent`        | Responder      | PMP 8 端口（`pmp_mmu_flg{0..7}` / `mmu_pmp_pa{0..7}` / `mmu_pmp_fetch{3,5,6,7}`）                                                                                                                                                       | 新写，配置式 responder                             |
| 6 | `sysmap_cfg_agent` | Active         | SysMap 区域配置（仅 build/初始化阶段）                                                                                                                                                                                                        | 新写，最简 active                                  |
| 7 | `misc_agent`       | Passive + 注入 | RTU flush/expt + HPCP cnt_en/miss + biu_smp_disable + scan_en + had_debug                                                                                                                                                                     | 新写，多子接口聚合                                 |

> **合并理由**：v1 的 `tlb_inv_agent` 合入 `lsu_agent`（DUT 上 SFENCE 信号在 LSU 端口组）；RTU 与 HPCP 信号量小，合并为 `misc_agent` 减少 boilerplate。

### 1.3 与 hpdcache_verification 框架的对位映射

| MMU UVM 组件                  | hpdcache_verification 对应                                                                      | 复用方式                                |
| ----------------------------- | ----------------------------------------------------------------------------------------------- | --------------------------------------- |
| `mmu_env`                   | `hpdcache_env` ([env/hpdcache_env.svh](../hpdcache_verification/testbench/env/hpdcache_env.svh)) | 仿照结构（多 SB + cfg + watchdog）      |
| `mmu_translation_sb`        | `hpdcache_sb`                                                                                 | 仿照 TLM analysis fifo + ref_model 比对 |
| `ifu_agent` / `lsu_agent` | `hpdcache_agent` ([hpdcache_agent/](../hpdcache_verification/testbench/hpdcache_agent/))         | 仿照八件套结构                          |
| `cp0_agent`                 | `conf_and_perf_agent`                                                                         | 仿照 CSR-style agent                    |
| `ptw_mem_agent`             | `dram_mon` + `memory_response_model`                                                        | 复用 dv_utils 内 memory_response_model  |
| `tb_top.sv`                 | [top/top_axi2mem.sv](../hpdcache_verification/testbench/top/top_axi2mem.sv)                        | 仿照接口实例 + DUT 连线 + uvm_config_db |
| SVA:`mmu_arb_sva.sv`        | `hpdcache_fxarb_sva.sv`                                                                       | 仿照 fixed-priority arbiter SVA         |
| SVA:`mmu_plru_sva.sv`       | `hpdcache_plru_sva.sv`                                                                        | 仿照 PLRU SVA                           |
| SVA:`credit_sva.sv`         | `hpdcache_sva.sv` 内的 outstanding 检查                                                       | 仿照                                    |
| Makefile                      | [hpdcache_verification/Makefile](../hpdcache_verification/Makefile)                                | 复制后裁剪                              |
| `scripts/run_test.py`       | 同名                                                                                            | 直接复用                                |

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

| 模块        | 文件                                                                       | 参数                                                                     |
| ----------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| L1 ITLB     | [mmu_l1itlb.sv](../mmu/rtl/mmu_l1itlb.sv)                                     | 16 entries 全相联，PLRU，CREDIT_MAX=8，支持 huge 2M                      |
| L1 DTLB     | [mmu_l1dtlb.sv](../mmu/rtl/mmu_l1dtlb.sv)                                     | NUM_ENTRY=16, MB_DEPTH=8, dual pipe + STAMO + PFU(pipe2), dPLRU          |
| L2 TLB      | [mmu_l2tlb.sv](../mmu/rtl/mmu_l2tlb.sv)                                       | Skew-Assoc 8 ways × 256 sets × 8 banks，RRPV 3-bit，MB 1(ITLB)+8(DTLB) |
| L2 ReqQ     | [mmu_l2tlb_reqq.sv](../mmu/rtl/mmu_l2tlb_reqq.sv)                             | TOTAL_DEPTH=9（1 ITLB + 8 DTLB），FFZ 分配 + FFR 仲裁                    |
| Arb         | [mmu_arb.sv](../mmu/rtl/mmu_arb.sv)                                           | 4 源仲裁：PTW(高) > TLBOp > ReqQ > PFU；8 bank skew idx                  |
| Replacement | [mmu_l2tlb_replacement_policy.sv](../mmu/rtl/mmu_l2tlb_replacement_policy.sv) | SRRIP，First-Free > Max-RRPV，RRPV_INIT=4(=MAX-3)                        |
| PTW         | [ptw.sv](../mmu/rtl/ptw.sv)                                                   | 4 TWU + ptw_mbuf + L1/L2PDE_cache + xbar 1→4 + pplru                    |
| TLBOper     | [ct_mmu_tlboper.v](../mmu/rtl/ct_mmu_tlboper.v)                               | 7 FSM：tlbiall/tlbiasid/tlbiva/tlbp/tlbr/tlbwi/tlbwr                     |
| Sysmap      | [ct_mmu_sysmap.v](../mmu/rtl/ct_mmu_sysmap.v) + [sysmap.h](../mmu/rtl/sysmap.h)  | 8 region，每 region 5-bit FLG                                            |
| Regs        | [ct_mmu_regs.v](../mmu/rtl/ct_mmu_regs.v)                                     | satp0/1, priv, mir/mel/meh，`reg_num[1:0]` 选择                        |
| PMP 接口    | 顶层端口                                                                   | 8 entries，每 entry 4-bit flag + 4 fetch enable                          |

### 2.3 关键 FSM 表（覆盖率与定向激励参考）

| FSM                                                                | 文件                               | 状态宽度                                                                                                                                                                                                         |
| ------------------------------------------------------------------ | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1 ITLB ref FSM                                                    | `mmu_l1itlb.sv`                  | 2 bit                                                                                                                                                                                                            |
| L1 DTLB ref FSM                                                    | `mmu_l1dtlb.sv`                  | 3 bit                                                                                                                                                                                                            |
| L2 TLB MB（per entry）                                             | `mmu_l2tlb_mb.sv`                | IDLE/ALLOC/WAIT_PTW/DONE                                                                                                                                                                                         |
| TLBOper tlbiall                                                    | `ct_mmu_tlboper.v`               | 1 bit                                                                                                                                                                                                            |
| TLBOper tlbiasid                                                   | 同                                 | 3 bit                                                                                                                                                                                                            |
| TLBOper tlbiva                                                     | 同                                 | 4 bit                                                                                                                                                                                                            |
| TLBOper tlbp / tlbr / tlbwi / tlbwr                                | 同                                 | 各 2 bit                                                                                                                                                                                                         |
| PTW TWU**6 级流水线** ×4（v3.0 架构澄清：流水线而非状态机） | [twu.sv](../mmu/rtl/twu.sv)           | FST_PMP→FST_CHK→SCD_PMP→SCD_CHK→THD_PMP→THD_CHK 六级有效寄存器串联；稳定态每周期可入 1 新请求；单 TWU 可多笔 PTE 读在飞；`twu_mask` 为 **per-TWU 自阻塞**（PMP/PTE wait），**非 MBUF 满反压** |
| PTW mbuf entry（9 entry：0-7 通用 + 8 ITLB 专用）                  | [ptw_mbuf.sv](../mmu/rtl/ptw_mbuf.sv) | alloc/walking/refill/done；**容量与 L2TLB Miss Buffer 一对一匹配，设计上不溢出，RTL 无"MBUF 满→阻塞 TWU"反压路径**                                                                                        |

### 2.4 `ct_mmu_top.v` 端口分组 → Agent 映射

| 端口分组                                                                      | 信号前缀                                                                                                                                                          | 归属 Agent / Interface                                                                                                                                                          |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 时钟复位                                                                      | `forever_cpuclk`, `cpurst_b`                                                                                                                                  | `tb_top` 直接生成（dv_utils clock_driver / reset_driver）                                                                                                                     |
| CP0/CSR                                                                       | `cp0_mmu_*`, `mmu_cp0_*`, `cp0_yy_priv_mode`                                                                                                                | `cp0_if` ↔ `cp0_agent`                                                                                                                                                     |
| HPCP                                                                          | `hpcp_mmu_cnt_en`, `mmu_hpcp_*_miss`                                                                                                                          | `misc_if`（hpcp 子分组）↔ `misc_agent`                                                                                                                                     |
| Debug / SMP / DFT                                                             | `mmu_had_debug_info`, `biu_mmu_smp_disable`, `pad_yy_icg_scan_en`, `mmu_xx_mmu_en`, `mmu_yy_xx_no_op`                                                   | `misc_if`（debug/dft 子分组）↔ `misc_agent`                                                                                                                                |
| IFU                                                                           | `ifu_mmu_*`, `mmu_ifu_*`                                                                                                                                      | `ifu_if` ↔ `ifu_agent`                                                                                                                                                     |
| LSU Pipe0/1                                                                   | `lsu_mmu_va{0,1}_*`, `mmu_lsu_*{0,1}`                                                                                                                         | `lsu_if`（pipe0/1 子分组）↔ `lsu_agent`                                                                                                                                    |
| LSU Pipe2 (Prefetch)                                                          | `lsu_mmu_va2*`, `mmu_lsu_pa2*`, `mmu_lsu_share2`, `mmu_lsu_sec2`                                                                                          | `lsu_if`（pipe2 子分组）↔ `lsu_agent`                                                                                                                                      |
| LSU STAMO                                                                     | `lsu_mmu_stamo_*`                                                                                                                                               | `lsu_if`（stamo 子分组）↔ `lsu_agent`                                                                                                                                      |
| LSU TLB Inv                                                                   | `lsu_mmu_tlb_*inv*`, `lsu_mmu_tlb_va`, `lsu_mmu_tlb_asid`, `mmu_lsu_tlb_inv_done`                                                                         | `lsu_if`（inv 子分组）↔ `lsu_agent`                                                                                                                                        |
| LSU PTW Data                                                                  | `mmu_lsu_data_*`, `lsu_mmu_data*`, `lsu_mmu_bus_error`                                                                                                      | `ptw_mem_if` ↔ `ptw_mem_agent`（**严格串行单 outstanding，见下表第 7 组说明**）                                                                                      |
| **【v7.3 新增】L1DTLB → LSU 广播（`tlb_status` 子分组）**            | `mmu_lsu_tlb_busy`（源：`mmu_l1dtlb.sv#L1252` `|mb_entry_vld`，任意 L1DTLB MB 在途即 busy）、`mmu_lsu_tlb_wakeup[11:0]`（源：`mmu_l1dtlb_install.sv` 完成事件广播，`sel_ptw || sel_jtlb || sel_wfi || l1dtlb_expt_for_taken` 时输出 `12'hfff` 解挂 LSIQ）、`mmu_lsu_mmu_en `（语义归 L1DTLB 域；RTL 驱动源 = `ct_mmu_regs.v#L645` SATP.mode） |
| PMP                                                                           | `pmp_mmu_flg{0..7}`, `mmu_pmp_pa{0..7}`, `mmu_pmp_fetch{3,5,6,7}`                                                                                           | `pmp_if` ↔ `pmp_agent`                                                                                                                                                     |
| RTU                                                                           | `rtu_mmu_bad_vpn`, `rtu_mmu_expt_vld`, `rtu_yy_xx_flush`                                                                                                    | `misc_if`（rtu 子分组）↔ `misc_agent`                                                                                                                                      |
| Sysmap                                                                        | （无顶层端口，纯内部）配置经 `ct_mmu_sysmap.v` 实例参数                                                                                                         | `sysmap_cfg_if`（白盒注入）↔ `sysmap_cfg_agent`                                                                                                                            |
| **【v3.0 Final 新增 / v7.3 修订】全局使能 / TLB Oper 完成（第 13 组）** | `mmu_xx_mmu_en`（顶层使能广播）、`mmu_cp0_tlb_done`（TLB Oper 完成握手）；**v7.3 修订**：`mmu_lsu_mmu_en` 已移至 L1DTLB → LSU 广播组（见上方新增行） | `cp0_if` / `misc_if`（在 `misc_agent` 内 monitor 广播信号，在 `cp0_agent` 内 monitor `tlb_done`）                                                                     |
| **【v3.0 Final 新增】CSR 细分控制（第 14 组）**                         | `cp0_mmu_cskyee`、`cp0_mmu_reg_num[1:0]`、`cp0_mmu_mpp[1:0]`、`cp0_mmu_wdata[63:0]`、`cp0_mmu_wreg`                                                     | `cp0_if` ↔ `cp0_agent`（driver 细分字段支持）                                                                                                                              |

> **【v3.0 Final 勘误】**
>
> 1. `regs_ptw_cur_asid` 宽度为 **16-bit**（与 SATP.ASID 一致）；早期 v2 接口表曾按 8-bit 注释。
> 2. `ct_mmu_top.v` 顶层**不存在** `pmp_mmu_fetch*` 输入；fetch 方向仅有 MMU→PMP 的 `mmu_pmp_fetch{3,5,6,7}`（4 端口）；v2 接口表措辞已澄清。
> 3. L1 ITLB entry 数量为 **16**（非 32）；L1 DTLB MB FSM 实际状态为 7 个（含 WFG）；SFENCE INVVA 已由 14-state 简化为 **single-pass FSM**（见 VerificationPlan v3 F8.NEW.1）。

> **【v3.0 Final ★ 关键协议补齐】PTW → LSU 数据通道（第 7 组）严格串行单 outstanding 握手**
>
> RTL 证据：[ptw_mbuf.sv#L288,L363-L410](../mmu/rtl/ptw_mbuf.sv#L288)；`mbuf_ptr_nxt` 仅在 `(lsu_mmu_data_vld_reg & mmu_lsu_data_req)` 或 MBUF 变空时更新，通道无 tag/ID 字段。
>
> | 语义                                                           | 约束                                                                                                                                                                                                                                                                                                                                                                                         | SVA                                                                            |
> | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
> | 请求稳定                                                       | `mmu_lsu_data_req` 拉高后，`mmu_lsu_data_req_addr` / `mmu_lsu_data_req_size` 必须保持稳定直到 `lsu_mmu_data_vld` 或 `lsu_mmu_bus_error` 返回                                                                                                                                                                                                                                       | `sva_lsu_req_stable_until_vld` / `sva_lsu_addr_stable_until_vld`（F4.42a） |
> | 单 outstanding                                                 | 任意周期 outstanding 请求数 ≤ 1                                                                                                                                                                                                                                                                                                                                                             | `sva_single_outstanding`（F4.42a）                                           |
> | 无 tag，按序返回                                               | 通道无 tag/ID 字段；`lsu_mmu_data_vld=1` 必须 `mmu_lsu_data_req=1`；对应当前 `mbuf_ptr` entry                                                                                                                                                                                                                                                                                          | `sva_response_inorder` / `sva_vld_only_when_req`（F4.42b）                 |
> | 指针约束                                                       | `mbuf_ptr` 仅在 `lsu_mmu_data_vld` 或 MBUF 变空时前进                                                                                                                                                                                                                                                                                                                                    | `sva_mbuf_ptr_only_on_response`（F4.42c）                                    |
> | 不参与握手（**v7.3 归属修订：三信号已迁至 `lsu_if`**） | `mmu_lsu_tlb_busy`（源 = L1DTLB MB 非空 `|mb_entry_vld`，`mmu_l1dtlb.sv#L1252`，表示 MMU 侧存在在途 miss/refill）、`mmu_lsu_tlb_wakeup[11:0]`（源 = `mmu_l1dtlb_install.sv` 完成事件广播；`sel_ptw/sel_jtlb/sel_wfi/l1dtlb_expt_for_taken` 触发 `12'hfff`）、`mmu_lsu_mmu_en`（MMU 使能广播，语义归 L1DTLB 域，RTL 源 = `ct_mmu_regs.v#L645`）均 **与 PTE 数据握手无关，归 L1DTLB → LSU 广播通道**（见 §2.4 新行） | —                                                                             |

> **【v3.0 Final ★ TWU/MBUF 架构澄清】**
>
> 1. **TWU 为 6 级流水线**（FST_PMP→FST_CHK→SCD_PMP→SCD_CHK→THD_PMP→THD_CHK），**非状态机**；理想稳定态每时钟可从 xbar 接一个新 PDE 请求；单个 TWU 内可同时有多笔 PTE 读在飞，因此 **一个 TWU 可向 MBUF 发出多笔请求**。
> 2. **`twu_mask[3:0]` 为 per-TWU 自阻塞信号**（twu.sv#L359 `twu_mask = fst_pmp_wait | scd_pmp_wait | thd_pmp_wait | ...`），表示该 TWU 因 PMP/PTE 检查 wait 或流水中间级未让出入口；**与 MBUF 是否满无关**。xbar 侧 `twu_ready = ~(&twu_mask[3:0])`，任一 TWU 未 mask 即可派发。
> 3. **MBUF 容量与 L2TLB Miss Buffer 一一对应、不可能溢出**：上游 L2TLB 分配 miss entry 时即已消耗配额，因此 PTW MBUF 可能填满但**不会溢出**，**RTL 无 MBUF 满 → 阻塞新 TWU 请求的反压逻辑**。验证环境的 ptw_mem_agent monitor **不得以 MBUF 满推导 `twu_mask`**。
> 4. **`mmu_lsu_tlb_busy` 源头**：由 L1 DTLB MB 非空（`|mb_entry_vld`）驱动（mmu_l1dtlb.sv#L1252），**不是 PTW MBUF 满**；它是 LSU/IDU LSIQ 的 TLB busy 等待协作信号，不是容量满告警。
>
> 对应 VerificationPlan v3 功能点：F4.5 / F4.6 / F4.24 / F4.52 / F4.53 / F4.NEW.2。

### 2.5 关键 CP0 寄存器位

| 信号                               | 影响                        | 验证关注          |
| ---------------------------------- | --------------------------- | ----------------- |
| `cp0_mmu_satp_sel`               | satp0/1 选择                | 双 SATP 切换      |
| `cp0_mmu_mxr`                    | X 页可读                    | load 到 X-only 页 |
| `cp0_mmu_sum`                    | S 模式访问 U 页             | 权限交叉          |
| `cp0_mmu_mprv` + `cp0_mmu_mpp` | M 模式按 MPP 查             | LD/ST 权限切换    |
| `cp0_mmu_maee`                   | M 模式是否走 TLB            | 边界场景          |
| `cp0_mmu_ptw_en`                 | 关闭后 L2 miss 直 pgflt     | PTW 禁用          |
| `cp0_mmu_no_op_req`              | 停止 MMU                    | TLB 不响应        |
| `cp0_mmu_tlb_all_inv`            | CP0 路径全失效              | 与 LSU 路径竞争   |
| `cp0_mmu_icg_en`                 | 时钟门控                    | 低功耗            |
| `cp0_yy_priv_mode[1:0]`          | 当前 priv（00=U,01=S,11=M） | 权限基础          |

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

| 层级             | 规范                                                 | 示例                                         |
| ---------------- | ---------------------------------------------------- | -------------------------------------------- |
| Package          | `<scope>_pkg.sv` / `<agent>_agent_pkg.sv`        | `mmu_params_pkg.sv` / `ifu_agent_pkg.sv` |
| Interface        | `<agent>_if.sv`                                    | `lsu_if.sv`                                |
| Transaction      | `<agent>_txn.svh`                                  | `cp0_txn.svh`                              |
| Driver           | `<agent>_driver.svh`                               | `pmp_driver.svh`                           |
| Monitor          | `<agent>_monitor.svh`                              | `ifu_monitor.svh`                          |
| Sequencer        | `<agent>_sequencer.svh`                            | `lsu_sequencer.svh`                        |
| Sequence Library | `<agent>_sequences.svh`                            | `ptw_mem_sequences.svh`                    |
| Covergroup       | `<agent>_covergroups.svh`                          | `cp0_covergroups.svh`                      |
| Agent            | `<agent>_agent.svh`                                | `misc_agent.svh`                           |
| Scoreboard       | `mmu_<scope>_sb.svh`                               | `mmu_translation_sb.svh`                   |
| Test             | `test_mmu_<category>_<scenario>.svh`               | `test_mmu_dir_l2tlb_reqq_alloc.svh`        |
| Virtual Sequence | `mmu_<scope>_vseq` 类，统一放 `mmu_vseq_lib.svh` | `mmu_smoke_vseq`                           |
| SVA 文件         | `<scope>_sva.sv`                                   | `mmu_arb_sva.sv`                           |

### 3.3 文件总数统计

| 模块                                               | 文件数                                                                                 |
| -------------------------------------------------- | -------------------------------------------------------------------------------------- |
| dv_utils（复制）                                   | 不计入                                                                                 |
| `modules/mmu_params/`                            | 2                                                                                      |
| `testbench/common/`                              | 1                                                                                      |
| 7 × Agent 八件套（ptw_mem 多 page_table_builder） | 9×6 + 10 =**64**                                                                |
| `testbench/env/`                                 | 11                                                                                     |
| `testbench/top/`                                 | 6                                                                                      |
| `testbench/test/` 基类                           | 2（test_pkg + test_base）                                                              |
| `testbench/test/` 各分类                         | ≈120（详见[VerificationPlan §6](MMU_VerificationPlan.md#6-测试用例计划test-case-plan)） |
| `testbench/simu/`                                | 6                                                                                      |
| `Files.f` + `Makefile` + `setup_env.*`       | 4                                                                                      |
| **环境本体（不含测试用例）**                 | **≈ 96 文件**                                                                   |

---

## 第 4 章 dv_utils + scripts 复用清单

### 4.1 dv_utils 复用模块（来自 [hpdcache_verification/modules/dv_utils/lib/cv_dv_utils/uvm/](../hpdcache_verification/modules/dv_utils/lib/cv_dv_utils/uvm/)）

| 模块路径              | 用途                                     | 在 MMU 环境中的使用点                      |
| --------------------- | ---------------------------------------- | ------------------------------------------ |
| `clock_gen/`        | `clock_driver_c` / `clock_config_c`  | `tb_top` 生成 `forever_cpuclk`         |
| `reset_gen/`        | `reset_driver_c`                       | `tb_top` 生成 `cpurst_b`，含中途 reset |
| `bp_gen/`           | `bp_agent` / `bp_virtual_sequence`   | （可选）pipe2 prefetch backpressure        |
| `watchdog/`         | `watchdog_c`                           | `mmu_env` 注册超时                       |
| `memory_rsp_model/` | `memory_response_model`                | `ptw_mem_agent` 内部模型                 |
| `memory_shadow/`    | shadow memory 容器                       | `mmu_page_table_mem` 共享后端            |
| `memory_partition/` | `memory_partitions_cfg`                | （可选）页表区与数据区分区                 |
| `pulse_gen/`        | `pulse_gen_driver` / `pulse_gen_cfg` | `misc_agent` 生成 RTU flush 单脉冲       |
| `perf_mon/`         | 通用性能监控                             | `mmu_perf_mon` 基类                      |
| `generic_agent/`    | 模板 agent                               | 6 个新 agent 的代码生成参考                |
| `unix_utils/`       | 各类辅助                                 | 通用                                       |

> **VERSION.txt**：在 `mmu_verification/modules/dv_utils/VERSION.txt` 内记录复制源 commit hash 与日期，避免后续上游变更不一致。

### 4.2 scripts 复用清单（来自 [hpdcache_verification/scripts/](../hpdcache_verification/scripts/)）

| 脚本                 | 用途                            | 裁剪                                                 |
| -------------------- | ------------------------------- | ---------------------------------------------------- |
| `run_test.py`      | 单测试 / 回归调度               | 改 default TEST_NAME，去掉 hpdcache 专用 CONFIG 选项 |
| `run_vcs_verdi.py` | VCS + Verdi 启动包装            | 改 top module、Files.f 路径                          |
| `scan_logs.pl`     | 日志扫描（PASS/FAIL/UVM_ERROR） | 直接复用                                             |
| `cov_hier.cfg`     | URG 层次配置                    | 改 DUT 模块路径前缀（`u_dut`）                     |
| `patterns/`        | 错误模式表                      | 直接复用并增补 MMU 相关                              |
| `sim/`             | 仿真子工具                      | 直接复用                                             |

### 4.3 Makefile 关键变量（基于 [hpdcache_verification/Makefile](../hpdcache_verification/Makefile) 裁剪）

| 变量                                                      | 默认值                                              | 说明                  |
| --------------------------------------------------------- | --------------------------------------------------- | --------------------- |
| `PROJECT_DIR`                                           | `$(shell pwd)`                                    | `mmu_verification/` |
| `MMU_RTL_DIR`                                           | `$(PROJECT_DIR)/../mmu/rtl`                       | DUT 源码              |
| `CV_DV_UTILS_DIR`                                       | `$(PROJECT_DIR)/modules/dv_utils/lib/cv_dv_utils` | 复用库                |
| `TOP_MODULE`                                            | `tb_top`                                          |                       |
| `UVM_VERSION`                                           | `1.2`                                             |                       |
| `TEST_NAME`                                             | `test_mmu_sanity_ifu`                             | 默认冒烟              |
| `SEED`                                                  | `random`                                          |                       |
| `VERBOSITY`                                             | `UVM_MEDIUM`                                      |                       |
| `TIMEOUT`                                               | `10000000`                                        |                       |
| `OUTPUT_DIR` / `LOG_DIR` / `WAVE_DIR` / `COV_DIR` | 同 hpdcache                                         |                       |

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
  // ---- L1DTLB → LSU 广播子分组（v7.3：从 ptw_mem_if 搬入） ----
  // 源：mmu_l1dtlb.sv#L79-L80, L1252（tlb_busy = |mb_entry_vld）
  //     mmu_l1dtlb_install.sv#L220-L262（完成事件广播 wakeup：
  //       sel_ptw/sel_jtlb/sel_wfi/l1dtlb_expt_for_taken -> 12'hfff）
  //     ct_mmu_regs.v#L645（mmu_en 驱动源 = SATP.mode；语义归 L1DTLB 域）
  logic         mmu_lsu_tlb_busy;
  logic [11:0]  mmu_lsu_tlb_wakeup;
  logic         mmu_lsu_mmu_en;
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
  // v7.3：mmu_lsu_mmu_en / mmu_lsu_tlb_busy / mmu_lsu_tlb_wakeup[11:0] 已迁至 lsu_if（L1DTLB → LSU 广播子分组 tlb_status）
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
  // 4 个 fetch enable 输出（PTW 读 PTE 为 Data Load，恒为 0；见 F7.NEW.7）
  logic         mmu_pmp_fetch3, mmu_pmp_fetch5, mmu_pmp_fetch6;
  logic         mmu_pmp_fecth7;  // ⚠ RTL typo：ptw.sv:L62 拼写缺 'c'，testbench 必须用此名（见 F7.NEW.8）
  // PTW→PMP 端口分配（见 F7.NEW.9 / DA-003）：
  // pa3/flg3 = twu_one（ptw.sv:L291/300）; pa5/flg5 = twu_two（ptw.sv:L344/353）
  // pa6/flg6 = twu_three（ptw.sv:L397/406）; pa7/flg7 = twu_four（ptw.sv:L450/459）
  // ⚠ [需设计确认 DA-003]：pa3 归属（PTW twu_one vs IFU）存在文档冲突
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

### 7.0a v3.1 协议增量（实现约束）

- IFU 严格 miss-hold（core 场景）：
  - non-abort 请求在 response 前必须保持有效，不允许 pending 未完成时发新 PC 请求。
  - monitor 发现 pending 期间 VA 前推/去使能且无 rsp，按协议错误归类，避免误记为 PA mismatch。
- LSU expt lifecycle（UVM 判定口径）：
  - replay fault 返回与普通翻译返回分开比较；
  - replay 路径优先比较 fault 语义（pgflt/acflt）和消费语义，避免把旁路 PA 当普通翻译 PA 做硬比较。

### 7.1 `ifu_agent/`

#### 7.1.1 `ifu_txn.svh`

```systemverilog
class ifu_txn extends uvm_sequence_item;
  `uvm_object_utils(ifu_txn)
  // 激励字段
  rand bit [62:0] va;
  rand bit        abort;
  rand int        idle_cycles;
  // v3.1 协议控制字段
  rand bit        hold_mode_en;       // 1=严格 hold
  rand int        min_hold_cycles;    // miss-hold 最小保持周期
  // 响应字段（monitor 回填）
  bit [27:0] pa;
  bit        pgflt, deny, sec, ca, buf_bit;
  // 约束
  constraint c_idle { idle_cycles inside {[0:10]}; }
  constraint c_hold_default { hold_mode_en == 1'b1; min_hold_cycles inside {[0:64]}; }
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
  extern task drive_stamo();   // ⚠ 仅驱动单一 STAMO 端口；Pipe1 的 STAMO 在 RTL 内部硬接 1'b0（F2.14）
  extern task drive_inv();
  // 子任务（实现工程师按 kind 分发 seq_item）
endclass
```

#### 7.2.3 `lsu_monitor.svh`（8 个 analysis_port）

> **设计说明**：对齐 hpdcache `hpdcache_monitor`（ap_req / ap_rsp 分离）模式。LSU Pipe0/1 翻译存在多周期延迟（L2 miss 需 PTW 走表），若 req 与 rsp 合并到同一 ap 则监控线程必须阻塞等待响应，导致无法观测请求间时序行为。STAMO 独立 ap 用于 PMP/sysmap 合法性检查。

```systemverilog
class lsu_monitor extends uvm_monitor;
  `uvm_component_utils(lsu_monitor)
  virtual lsu_if vif;
  // Pipe0：请求在 lsu_mmu_va0_vld & ready 握手时发送
  uvm_analysis_port #(lsu_txn) ap_pipe0_req;
  // Pipe0：响应在 mmu_lsu_pa0_vld 或 mmu_lsu_page_fault0 时发送
  uvm_analysis_port #(lsu_txn) ap_pipe0_rsp;
  // Pipe1：同 Pipe0
  uvm_analysis_port #(lsu_txn) ap_pipe1_req;
  uvm_analysis_port #(lsu_txn) ap_pipe1_rsp;
  // Pipe2（预取）：va2_vld 时发请求，pa2_vld 时发响应
  uvm_analysis_port #(lsu_txn) ap_pipe2_req;
  uvm_analysis_port #(lsu_txn) ap_pipe2_rsp;
  // TLB 无效化：lsu_mmu_tlb_*_inv 拉高时发；mmu_lsu_tlb_inv_done 时附加完成标志
  uvm_analysis_port #(lsu_txn) ap_inv;
  // STAMO：lsu_mmu_stamo_vld 时发（PA 已知，用于 PMP/sysmap 检查）
  uvm_analysis_port #(lsu_txn) ap_stamo;
  function new(string name, uvm_component parent);
  extern function void set_lsu_vif(virtual lsu_if v);
  extern function void set_is_active();
  extern task run_phase(uvm_phase phase);
  // fork 中并行运行的 8 个采集子线程
  extern task collect_pipe_req(int unsigned p);    // p=0,1,2：VA 握手时刻
  extern task collect_pipe_rsp(int unsigned p);    // p=0,1,2：PA/fault 返回时刻
  extern task collect_inv();
  extern task collect_stamo();
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
// ★ cp0_monitor.ap 数据流说明：
//   (1) CSR 写（SATP/priv/MXR/SUM 等）→ invalidate_sb.af_cp0 + m_ref.af_csr_write（ref_model CSR 镜像同步）
//   (2) CP0_TLB_ALL_INV（cp0_mmu_tlb_all_inv=1）→ DUT TLBOper tlbiall FSM → 全清 → mmu_cp0_tlb_done
//       → cp0_monitor 采样 tlb_done → ap → invalidate_sb.af_cp0（验证残留不命中）
//   (3) TLBOper 软件操作（TLBR/TLBWI/TLBWR/TLBP，对应 cp0_mmu_tlb_{r,wi,wr,p} 脉冲）：
//       → DUT ct_mmu_tlboper.v 读写 L1/L2 TLB entry → mmu_cp0_{entryhi/lo0/lo1/index/random} 回读
//       → cp0_monitor 采样回读数据打包入 txn.rdata / txn.tlb_done → ap → m_ref 软件 TLB 镜像更新
//       注意：TLBR/TLBWI/TLBWR/TLBP 使用 cp0_if 中 cp0_mmu_reg_num / cp0_mmu_wdata 等字段区分；
//             驱动由 cp0_driver 在 CP0_WRITE_REG / CP0_READ_REG 事务中分发
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

> **PTW PDE Cache 命中层级对 LSU 请求次数的影响（F4.NEW.8）**：
> `ptw_mem_responder` 通过 `page_table_builder` 查找 PTE，但实际到达 LSU 侧的请求次数取决于 DUT 内部 PDE Cache 命中情况：
>
> - **L2 PDE Cache 命中**（3 级 walk 中 L2/L1 PDE 均命中）：PTW 只需 1 次 LSU 内存请求（仅取叶子 PTE）
> - **L1 PDE Cache 命中**（L2 PDE 命中，L1 miss）：PTW 需要 2 次 LSU 内存请求（L1 PDE + 叶子 PTE）
> - **全 miss**（L2/L1 PDE 均 miss）：PTW 需要 3 次串行 LSU 内存请求（L2 PDE → L1 PDE → 叶子 PTE）
>   `ptw_mem_responder.handle_request()` 对每次请求独立响应；`page_table_builder` 须预先写入各级 PDE，以便 responder 按地址正确返回 PTE 数据。
>   SVA `sva_ptw_mbuf_no_overflow` 与 `mmu_credit_sb` 验证 PTW MBUF 在 PDE cache miss 时的 outstanding 深度不超过 9。

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
// ap 下游：connect_phase 连接到 m_ref.af_pmp_cfg（驱动 ref_model PMP 镜像更新）
// 注：PMP flag 是纯配置输入，无 req/rsp 对，单 ap 即可；flg 变化时 monitor 采样打包发出
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
class sysmap_cfg_monitor extends uvm_monitor;
  `uvm_component_utils(sysmap_cfg_monitor)
  virtual sysmap_cfg_if vif;
  // 每次 sysmap_cfg_driver 完成 force 写入后，monitor 将当前配置快照打包发出
  // 下游：mmu_env.connect_phase 连接到 ref_model 的 af_sysmap_cfg（见 §8.4）
  //
  // ★ SysMap 命中绕过翻译路径说明（数据流 ⑤）：
  //   sysmap_cfg_driver 通过白盒 force 写入 ct_mmu_sysmap.v 的 base/mask/flg/enable 寄存器
  //   → DUT ct_mmu_sysmap_hit.v 对 IFU/LSU 物理地址做比对
  //   → 命中时：PA 由 SysMap adder 直接生成（**优先于 TLB 查找**，不触发 PTW）
  //   → sysmap_cfg_monitor.ap → m_ref.af_sysmap_cfg（ref_model 同步 SysMap 映射）
  //   → mmu_translation_sb 调用 ref_model.translate() 时若 SysMap 命中，
  //     按 sysmap_adder 计算期望 PA，而非 page-table walk 结果
  //   注意：SysMap 权限标志（flg[4:0]）同时参与 PMP 等效检查，
  //         sysmap_hit 结果须与 mmu_translation_sb 的 PMP check 路径互斥
  uvm_analysis_port #(sysmap_cfg_txn) ap;
  function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);   // 观测 vif.cfg_enable 变化，ap.write(snapshot)
endclass
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

  // ── TLM 订阅入口（由 mmu_env.connect_phase 连接各 monitor AP）──────────────
  // 模式：各 monitor 的 analysis_port 通过 analysis_export 推入下面的 FIFO；
  // ref_model.run_phase 中用 fork 分别 get() 消费，调用对应的 on_* 方法。
  // 这样 ref_model 自己不需要 uvm_analysis_imp，连接方式与 SB 一致。
  uvm_tlm_analysis_fifo #(cp0_txn)        af_csr_write;     // ← cp0_monitor.ap fan-out
  uvm_tlm_analysis_fifo #(lsu_txn)        af_tlb_inv;       // ← lsu_monitor.ap_inv fan-out
  uvm_tlm_analysis_fifo #(pmp_txn)        af_pmp_cfg;       // ← pmp_monitor.ap fan-out
  uvm_tlm_analysis_fifo #(sysmap_cfg_txn) af_sysmap_cfg;    // ← sysmap_cfg_monitor.ap

  function new(string name, uvm_component parent);
  // 核心 API（被 SB 的 check_* 任务调用）
  extern function xlation_rsp_t translate(va_t va, acc_type_e acc);
  extern function bit            check_pmp(pa_t pa, acc_type_e acc, int port_idx);
  extern function sysmap_entry_t lookup_sysmap(pa_t pa);
  // 内部状态更新（由 run_phase fork 消费 FIFO 后调用，不直接暴露给外部）
  extern function void on_csr_write(cp0_txn tr);
  extern function void on_tlb_inv(lsu_txn tr);
  extern function void on_pmp_cfg_change(pmp_txn tr);
  extern function void on_sysmap_cfg_change(sysmap_cfg_txn tr);
  // 生命周期
  extern function void build_phase(uvm_phase phase);
  extern task          run_phase(uvm_phase phase);  // fork 消费 4 个 FIFO
endclass
```

### 8.5 Scoreboard 拆分

#### 8.5.1 `mmu_translation_sb.svh`

> **数据流说明**：
>
> - IFU 侧：`ifu_monitor.ap_req → af_ifu_req`（VA 握手），`ifu_monitor.ap_rsp → af_ifu_rsp`（PA 返回）
> - LSU Pipe0/1 侧：`lsu_monitor.ap_pipe{0,1}_req/rsp` 各自对应 req/rsp FIFO（分离模式）
> - LSU Pipe2（预取）：`lsu_monitor.ap_pipe2_req/rsp`
> - LSU STAMO：`lsu_monitor.ap_stamo → af_lsu_stamo`（PMP/sysmap 合法性检查）
> - PTW 内存侧（类比 hpdcache dram_monitor）：`ptw_mem_monitor.ap_req → af_ptw_req`、`ptw_mem_monitor.ap_rsp → af_ptw_rsp`；SB 据此得知实际走表地址与 PTE 内容，与 ref_model shadow PT 对比，验证 walk 结果正确性
>
> **v3.1 增量通道**：
>
> - IFU miss-hold 协议检查：pending 生命周期 + request stability（禁止 pending 期间新请求）。
> - LSU expt replay 分类检查：普通翻译 vs replay fault 双路径比较（replay 以 fault/消费语义为主）。

```systemverilog
class mmu_translation_sb extends uvm_scoreboard;
  `uvm_component_utils(mmu_translation_sb)
  // IFU 侧
  uvm_tlm_analysis_fifo #(ifu_txn) af_ifu_req;
  uvm_tlm_analysis_fifo #(ifu_txn) af_ifu_rsp;
  // LSU Pipe0/1（req/rsp 分离，对齐 hpdcache 双 AP 模式）
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe0_req;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe0_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe1_req;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe1_rsp;
  // LSU Pipe2 预取
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe2_req;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe2_rsp;
  // LSU STAMO（PA 直通，PMP/sysmap 检查）
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_stamo;
  // PTW 内存侧（类比 hpdcache af_mem_req/read_rsp）
  uvm_tlm_analysis_fifo #(ptw_mem_txn) af_ptw_req;   // PTW 发出的 PA 地址请求
  uvm_tlm_analysis_fifo #(ptw_mem_txn) af_ptw_rsp;   // LSU 返回的 PTE 数据
  mmu_ref_model m_ref;
  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern task check_ifu();
  extern task check_lsu_pipe(int unsigned pipe_idx);  // pipe_idx=0,1,2
  extern task check_lsu_stamo();
  extern task check_ptw_walk();   // 对比 PTW 实际读取的 PTE 与 ref_model shadow PT
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

> **数据流说明**：
>
> - `af_ifu_req/rsp` ← `ifu_monitor.ap_req/rsp`：追踪 L1I credit 发出/回收
> - `af_lsu_pipe0/1_req/rsp` ← `lsu_monitor.ap_pipe{0,1}_req/rsp`：追踪 L1D MB + L2 ReqQ 占用
> - `af_ptw_req/rsp` ← `ptw_mem_monitor.ap_req/rsp`：追踪 PTW MBUF 发出/回收（验证 MBUF ≤ 9 且 ≤ L2TLB MB 配额）
> - run_phase 维护计数器，每周期与 SVA `sva_ptw_mbuf_no_overflow` 结论双重保险

```systemverilog
// 检查 L1↔L2 credit 守恒、ReqQ/MB 容量上界、PTW MBUF 上界
class mmu_credit_sb extends uvm_scoreboard;
  `uvm_component_utils(mmu_credit_sb)
  // IFU 侧（L1I credit 追踪）
  uvm_tlm_analysis_fifo #(ifu_txn) af_ifu_req;
  uvm_tlm_analysis_fifo #(ifu_txn) af_ifu_rsp;
  // LSU Pipe0/1（L1D MB + L2 ReqQ 追踪）
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe0_req;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe0_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe1_req;
  uvm_tlm_analysis_fifo #(lsu_txn) af_lsu_pipe1_rsp;
  // PTW 内存侧（MBUF 占用 / 释放追踪）
  uvm_tlm_analysis_fifo #(ptw_mem_txn) af_ptw_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn) af_ptw_rsp;
  // 运行时计数器（由 run_phase 维护）
  int unsigned credit_l1i;        // L1ITLB → L2TLB credit 剩余，上界 CREDIT_MAX=8
  int unsigned credit_l1d;        // L1DTLB → L2TLB credit 剩余
  int unsigned l2_reqq_cnt;       // L2 ReqQ 占用，上界 L2_REQQ_DEPTH=9
  int unsigned l2_mb_cnt;         // L2TLB Miss Buffer 占用，上界 1(ITLB)+8(DTLB)=9
  int unsigned ptw_mbuf_cnt;      // PTW MBUF 占用，上界 = l2_mb_cnt（一一对应）
  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
endclass
```

#### 8.5.4 `mmu_perf_mon.svh`

```systemverilog
class mmu_perf_mon extends uvm_component;
  `uvm_component_utils(mmu_perf_mon)
  // 复用 dv_utils perf_mon 基类（如有）
  // 接收来自各 monitor 的 rsp AP（响应时才有 PA 和延迟数据）
  uvm_tlm_analysis_fifo #(ifu_txn)     af_ifu_rsp;
  uvm_tlm_analysis_fifo #(lsu_txn)     af_lsu_pipe0_rsp;   // ← lsu_monitor.ap_pipe0_rsp
  uvm_tlm_analysis_fifo #(lsu_txn)     af_lsu_pipe1_rsp;   // ← lsu_monitor.ap_pipe1_rsp
  uvm_tlm_analysis_fifo #(lsu_txn)     af_lsu_pipe2_rsp;   // ← lsu_monitor.ap_pipe2_rsp
  uvm_tlm_analysis_fifo #(misc_txn)    af_hpcp;             // ← misc_monitor.ap_hpcp
  // 统计
  longint unsigned n_ifu_req, n_ifu_miss;
  longint unsigned n_lsu_req[3], n_lsu_miss[3];
  longint unsigned n_l2_miss, n_walk_complete;
  real             walk_latency_sum;
  function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
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
  // ─────────────────────────────────────────────────────────────────────────
  // connect_phase：所有 TLM 连线均在此完成（对齐 hpdcache_env.svh 模式）
  // 规则：ap.connect(fifo.analysis_export)；analysis_port 支持 1→N fan-out，
  //       只需在同一个 ap 上多次调用 connect() 即可连接多个 FIFO。
  // ─────────────────────────────────────────────────────────────────────────
  // ── 数据流 ①：IFU 翻译检查 ────────────────────────────────────────────────
  //   ifu_monitor.ap_req → translation_sb.af_ifu_req
  //   ifu_monitor.ap_rsp → translation_sb.af_ifu_rsp [fan-out 1]
  //                      → perf_mon.af_ifu_rsp       [fan-out 2]
  //
  // ── 数据流 ②/③：LSU Pipe0/1/2 翻译检查 ──────────────────────────────────
  //   lsu_monitor.ap_pipe{0,1}_req → translation_sb.af_lsu_pipe{0,1}_req [fan-out 1]
  //                                → credit_sb.af_lsu_pipe{0,1}_req      [fan-out 2]
  //   lsu_monitor.ap_pipe{0,1}_rsp → translation_sb.af_lsu_pipe{0,1}_rsp [fan-out 1]
  //                                → credit_sb.af_lsu_pipe{0,1}_rsp      [fan-out 2]
  //                                → perf_mon.af_lsu_pipe{0,1}_rsp       [fan-out 3]
  //   lsu_monitor.ap_pipe2_req → translation_sb.af_lsu_pipe2_req
  //   lsu_monitor.ap_pipe2_rsp → translation_sb.af_lsu_pipe2_rsp [fan-out 1]
  //                            → perf_mon.af_lsu_pipe2_rsp       [fan-out 2]
  //   lsu_monitor.ap_stamo     → translation_sb.af_lsu_stamo
  //
  // ── 数据流 ④：TLB 无效化检查（LSU SFENCE + CP0 全无效化） ────────────────
  //   lsu_monitor.ap_inv → invalidate_sb.af_inv  [fan-out 1]
  //                      → m_ref.af_tlb_inv       [fan-out 2]
  //   cp0_monitor.ap     → invalidate_sb.af_cp0   [fan-out 1]
  //                      → m_ref.af_csr_write      [fan-out 2]
  //   ★ CP0 全无效化路径（独立于 LSU SFENCE.VMA）：
  //     cp0_agent 驱动 cp0_if.cp0_mmu_tlb_all_inv=1（CP0_TLB_ALL_INV 事务）
  //     → DUT ct_mmu_tlboper.v：tlbiall FSM → L1 ITLB/DTLB + L2 TLB 全清
  //     → mmu_cp0_tlb_done 握手回应 cp0_agent
  //     cp0_monitor 采样 tlb_done → ap → invalidate_sb.af_cp0
  //     invalidate_sb 检查：全无效化后 L1/L2 不得有残留有效 entry（ref_model 同步清空）
  //
  // ── 数据流 ⑥：PTW 内存侧监控（类比 hpdcache dram_monitor） ───────────────
  //   ptw_mem_monitor.ap_req → translation_sb.af_ptw_req [fan-out 1]
  //                          → credit_sb.af_ptw_req       [fan-out 2]
  //   ptw_mem_monitor.ap_rsp → translation_sb.af_ptw_rsp [fan-out 1]
  //                          → credit_sb.af_ptw_rsp       [fan-out 2]
  //
  // ── 数据流 ⑦/⑧：配置侧 → ref_model 更新 ────────────────────────────────
  //   pmp_monitor.ap          → m_ref.af_pmp_cfg
  //   sysmap_cfg_monitor.ap   → m_ref.af_sysmap_cfg
  //
  // ── 数据流 ⑨：MMU 关闭（mmu_xx_mmu_en=0）直通行为 ──────────────────────
  //   cp0_agent 通过 cp0_if 驱动 mmu_xx_mmu_en=0（misc_if 广播）
  //   → DUT：MMU off 状态下 IFU/LSU VA 直接作为 PA 输出（passthrough）
  //     mmu_lsu_mmu_en=0（ptw_mem_if 广播），L1/L2 TLB 查找不触发
  //   → ref_model.translate()：检查 mmu_en flag，若 0 则直接返回 PA=VA[39:0]（零扩展）
  //   → mmu_translation_sb 以 mmu_en=0 模式比对，验证 DUT 不产生翻译结果差异
  //   注意：mmu_xx_mmu_en=0 时 MMU 仍接受请求，但直通；TLB 状态不变（不清空）
  //
  // ── 数据流 ⑩：HPCP 性能计数 ─────────────────────────────────────────────
  //   misc_monitor.ap_hpcp → perf_mon.af_hpcp
  //
  // ── Virtual Sequencer 句柄绑定（非 TLM，赋值即可） ─────────────────────
  //   m_vseqr.ifu_sqr      = m_ifu.m_sequencer
  //   m_vseqr.lsu_sqr      = m_lsu.m_sequencer
  //   m_vseqr.cp0_sqr      = m_cp0.m_sequencer
  //   m_vseqr.pmp_sqr      = m_pmp.m_sequencer
  //   m_vseqr.sysmap_sqr   = m_sysmap_cfg.m_sequencer
  //   m_vseqr.misc_sqr     = m_misc.m_sequencer
  //
  // ── ref_model / SB 共享句柄（非 TLM，build_phase 或 connect_phase 赋值） ──
  //   m_trans_sb.m_ref = m_ref;  m_inv_sb.m_ref = m_ref
  //   m_ref.m_pt       = m_pt_mem;  m_trans_sb.m_pt = m_pt_mem（如需直接查）
  extern function void connect_phase(uvm_phase phase);
endclass

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
    // PTW data 通道（v7.3：mmu_en / tlb_busy / tlb_wakeup 归 lsu_vif，L1DTLB → LSU 广播子分组）
    .mmu_lsu_mmu_en        (lsu_vif.mmu_lsu_mmu_en),
    .mmu_lsu_data_req      (ptw_mem_vif.mmu_lsu_data_req),
    .mmu_lsu_data_req_addr (ptw_mem_vif.mmu_lsu_data_req_addr),
    .mmu_lsu_data_req_size (ptw_mem_vif.mmu_lsu_data_req_size),
    .lsu_mmu_bus_error     (ptw_mem_vif.lsu_mmu_bus_error),
    .lsu_mmu_data_vld      (ptw_mem_vif.lsu_mmu_data_vld),
    .lsu_mmu_data          (ptw_mem_vif.lsu_mmu_data),
    .mmu_lsu_tlb_busy      (lsu_vif.mmu_lsu_tlb_busy),
    .mmu_lsu_tlb_wakeup    (lsu_vif.mmu_lsu_tlb_wakeup),
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

| 文件                                                             | 监督对象                              | 主要属性                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ---------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `top/mmu_sva.sv`                                               | 所有顶层接口                          | va_vld 时 va 不为 X / 同期 stall+pavld 互斥 / abort 后 N cycle 内 pavld 不应继续                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `top/mmu_arb_sva.sv`                                           | `mmu_arb`                           | grant one-hot / 优先级链严格 PTW>TLBOp>ReqQ>PFU / work-conserving；**【v3】追加 `sva_ptw_write_pipe_reset_safe`（F5.NEW.2：`arb_ptw_grant`→`ptw_write_req1`→`ptw_write_req2` 两拍流水 reset 期间同步清零无 stale write）**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `top/mmu_l2tlb_rrpv_sva.sv`                                    | `mmu_l2tlb` 内 RRPV 阵列            | hit 后 promote=0 / miss 后 +1 饱和 / new fill 初值=4；**【v3】追加 `sva_raw_vld_and_gate`（F3.4 TC-BUG-005：`raw_vld` 必须为 `&&` 门控）、`sva_l2_is_dtlb_match`（F3.5 TC-BUG-006：load/store 3'b010/3'b110 均需正确分流）、`sva_rrpv_inv_state`（F3.NEW.1 TC-BUG-007：SFENCE INVVA 无效化后该 entry RRPV 必须被视为 invalid / 复位到 RRPV_INIT）**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `top/mmu_plru_sva.sv`                                          | `mmu_l1itlb` / `mmu_l1dtlb`       | PLRU 树更新规则、victim 选择正确；**【v3】追加 `sva_pplru_entry0_first_hit`（F12.NEW.1 TC-BUG-008：复位后 entry 0 首次命中 PLRU 树必须更新）**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `top/credit_sva.sv`                                            | L1↔L2 credit / ReqQ / MB             | outstanding ≤ MAX、credit 守恒（issue+return-net=0）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **`top/mmu_twu_sva.sv`【v3.0 Final 新建】**              | `twu.sv`                            | `sva_twu_2m_cross_data`（F4.NEW.4 TC-BUG-011 P0 高危：2MB 巨页 CSR 跨界 `twu_crs2_2m && twu_csr_cross` 时 `csr_data_flop` 必须被 shift 更新）；`sva_csr_grant_onehot`（F4.NEW.5 TC-BUG-012：`csr_grant[1:0]` 禁止同时为 1）；**【v3.0 Final 追加：TWU 流水线 / twu_mask 语义修正】**`sva_twu_mask_semantics`（F4.52 / F4.NEW.2：`twu_mask_i` 等价于 `fst_pmp_wait \| scd_pmp_wait \| thd_pmp_wait \| <非叶 chk wait>`，**不得由 MBUF 满驱动**）、`sva_twu_pipeline_no_stall_when_unmasked`（F4.NEW.2：`xbar_twu_req_i && !twu_mask_i` 时下一拍 `fst_pmp_vld_i` 必拉高，验证每周期可接 1 新请求）、`sva_twu_multi_inflight_legal`（F4.5：单 TWU 多级 valid 可同时为 1 不视为非法）；**正向保护 SVA**（v2 证伪后保留）：`sva_thd_a_bit_pgflt`（thd_chk 4K/2M/1G A=0 触 pgflt）、`sva_pde_nonleaf_upd`（PDE Cache 仅接受非叶 PTE 更新） |
| **`top/mmu_ptw_lsu_protocol_sva.sv`【v3.0 Final 新建】** | `ptw_mbuf.sv` / `ptw_mem_if`      | **F4.42a/b/c 严格串行单 outstanding 握手补强**：`sva_lsu_req_stable_until_vld`、`sva_lsu_addr_stable_until_vld`、`sva_single_outstanding`、`sva_response_inorder`、`sva_vld_only_when_req`、`sva_mbuf_ptr_only_on_response`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **`top/one_to_four_xbar_sva.sv`【v3.0 Final 可选】**     | `one_to_four_xbar.sv`               | `sva_xbar_cold_start`（F5.NEW.3 TC-BUG-014：`twu_req_point_r` 复位初值 `4'b0001` 冷启动偏向 TWU0 的分布观察；以 covergroup 为主，SVA 仅做复位值断言）；**【v3.0 Final 追加】**`sva_twu_ready_equiv`（F4.6 / F4.52：`twu_ready == ~(&twu_mask)`）、`sva_xbar_drop_when_all_mask`（F4.52 TC-TWU-MASK-ALL-001：`&twu_mask` 期间 `xbar_pde_ready=0`，`PDE_xbar_req` 保持不被消费）                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **top/mmu_mbuf_invariant_sva.sv** | ptw_mbuf.sv + mmu_l1dtlb.sv | F4.6 / F4.24 / F4.53 MBUF invariants and tlb_busy protocol: sva_ptw_mbuf_no_overflow, sva_no_backpressure_to_twu_from_mbuf_full, sva_busy_from_any_dtlb_mb_entry (mmu_lsu_tlb_busy == |mb_entry_vld_l1dtlb), plus independence from ptw_mbuf_full. |
| **`top/mmu_maee_twu_sva.sv`【v4.0 新建】**               | `twu.sv`                            | **F4.NEW.12 / F6.NEW.1 MAEE 双路属性选路保护**：`sva_twu_maee_paths_mutex`（`fst_chk_csr_req` 与 `fst_chk_refill_req` 互斥，同一周期不同时为 1）；`sva_maee0_triggers_csr_req`（MAEE=0 时叶 PTE 发现后必有 `fst/scd/thd_chk_csr_req`）；`sva_maee1_skips_csr_fsm`（MAEE=1 时 `fst_chk_csr_req` 恒为 0）；对称适用于 FST/SCD/THD 三级                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **`top/mmu_pmp_twu_sva.sv`【v4.0 新建】**                | `twu.sv` + `ptw.sv`               | **F4.NEW.13 / F4.NEW.14 / F7.NEW.3-9 PMP 序列化与端口约束**：`sva_pmp_check_before_lsu_req`（PMP pass 后才允许 `mmu_lsu_data_req` 拉高）；`sva_pmp_wait_implies_mask`（`pmp_wait=1` 时该 TWU `twu_mask=1`）；`sva_pmp_deny_no_refill`（PMP deny 后无 L2TLB refill）；`sva_pmp_deny_acc_fault`（PMP deny→AccessFault 路径）；`sva_pmp_grant_onehot`（`pmp_grant[2:0]` 同周期最多 1 bit）；`sva_no_lsu_req_during_pmp_wait`（`pmp_wait=1` 期间 `mmu_lsu_data_req=0`）；`sva_ptw_pmp_fetch_zero`（`mmu_pmp_fecth3/5/6/7` PTW 侧恒为 0，见 F7.NEW.7 typo 名称）；`sva_pmp_deny_no_lsu_req`（F7.NEW.5）                                                                                                                                                                                                                                         |
| **`top/mmu_sysmap_sva.sv`【v4.0 新建】**                 | `twu.sv` + `ct_mmu_sysmap.v`      | **F6.NEW.2-5 sysmap flag 替换、跨界检测与降级**：`sva_csr_refill_flg_matches_sysmap`（MAEE=0 回填时 `csr_refill_data[60:56]` 与 `sysmap_mmu_flg[4:0]` 位对位一致）；`sva_sysmap_cross_degrade`（`twu_csr_cross=1` 时 1G→2M 或 2M→4K 降级，回填 pgs 正确）；`sva_sysmap_no_cross_no_degrade`（不跨界时 pgs 不降级）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

每个 SVA 文件采用 `module <name>(...)` 结构，通过 `bind` 绑定到 RTL 实例（参考 [hpdcache_verification/testbench/top/hpdcache_fxarb_sva.sv](../hpdcache_verification/testbench/top/hpdcache_fxarb_sva.sv)）。

#### 9.2.1 【v3.0 Final】新增 SVA 属性签名（伪代码）

```systemverilog
// mmu_ptw_lsu_protocol_sva.sv（F4.42a/b/c）
property p_lsu_req_stable_until_vld;
  @(posedge clk_i) disable iff (!rst_ni)
  $rose(mmu_lsu_data_req) |-> (mmu_lsu_data_req throughout
     ##[1:$] (lsu_mmu_data_vld || lsu_mmu_bus_error));
endproperty
sva_lsu_req_stable_until_vld:   assert property(p_lsu_req_stable_until_vld);

property p_lsu_addr_stable_until_vld;
  @(posedge clk_i) disable iff (!rst_ni)
  mmu_lsu_data_req && !(lsu_mmu_data_vld || lsu_mmu_bus_error)
     |=> $stable(mmu_lsu_data_req_addr) && $stable(mmu_lsu_data_req_size);
endproperty
sva_lsu_addr_stable_until_vld:  assert property(p_lsu_addr_stable_until_vld);

sva_single_outstanding:         assert property(@(posedge clk_i) disable iff(!rst_ni)
  (outstanding_cnt <= 1));
sva_vld_only_when_req:          assert property(@(posedge clk_i) disable iff(!rst_ni)
  lsu_mmu_data_vld |-> mmu_lsu_data_req);
sva_response_inorder:           assert property(@(posedge clk_i) disable iff(!rst_ni)
  lsu_mmu_data_vld |-> mbuf_entry_vld[mbuf_ptr]);
sva_mbuf_ptr_only_on_response:  assert property(@(posedge clk_i) disable iff(!rst_ni)
  (mbuf_ptr != $past(mbuf_ptr))
     |-> ($past(lsu_mmu_data_vld) || $past(mbuf_going_empty)));

// mmu_twu_sva.sv（F4.NEW.4 / F4.NEW.5）
sva_twu_2m_cross_data: assert property(@(posedge clk_i) disable iff(!rst_ni)
  (twu_crs2_2m && twu_csr_cross) |=> (csr_data_flop != $past(csr_data_flop)));
sva_csr_grant_onehot:  assert property(@(posedge clk_i) disable iff(!rst_ni)
  $onehot0(csr_grant));

// mmu_arb_sva.sv（F5.NEW.2 追加）
sva_ptw_write_pipe_reset_safe: assert property(@(posedge clk_i)
  (!rst_ni) |-> !(ptw_write_req1 || ptw_write_req2));

// mmu_twu_sva.sv（v3.0 Final 追加 · F4.NEW.2 / F4.52 TWU 流水线 & twu_mask 语义）
sva_twu_mask_semantics: assert property(@(posedge clk_i) disable iff(!rst_ni)
  twu_mask_i == (fst_pmp_wait_i || scd_pmp_wait_i || thd_pmp_wait_i
               || (fst_chk_vld_i && !fst_chk_page_flt_i && !fst_chk_leaf_vld_i && !scd_pmp_wait_i)
               || (scd_chk_vld_i && !scd_chk_page_flt_i && !scd_chk_leaf_vld_i && !thd_pmp_wait_i)));
sva_twu_pipeline_no_stall_when_unmasked: assert property(@(posedge clk_i) disable iff(!rst_ni)
  (xbar_twu_req_i && !twu_mask_i && (xbar_twu_hit_level_i == 2'b00))
     |=> fst_pmp_vld_i);
sva_twu_multi_inflight_legal: cover property(@(posedge clk_i) disable iff(!rst_ni)
  ($countones({fst_pmp_vld_i, fst_chk_vld_i, scd_pmp_vld_i, scd_chk_vld_i,
               thd_pmp_vld_i, thd_chk_vld_i}) >= 2));

// one_to_four_xbar_sva.sv（v3.0 Final 追加 · F4.6 / F4.52）
sva_twu_ready_equiv: assert property(@(posedge clk_i) disable iff(!rst_ni)
  twu_ready == ~(&twu_mask));
sva_xbar_drop_when_all_mask: assert property(@(posedge clk_i) disable iff(!rst_ni)
  (&twu_mask) |-> !xbar_pde_ready);

// mmu_mbuf_invariant_sva.sv（v3.0 Final 新建 · F4.6 / F4.24 / F4.53）
sva_ptw_mbuf_no_overflow: assert property(@(posedge clk_i) disable iff(!rst_ni)
  (ptw_mbuf_occ <= 9) && (ptw_mbuf_occ <= l2tlb_mb_occ));
sva_no_backpressure_to_twu_from_mbuf_full: assert property(@(posedge clk_i) disable iff(!rst_ni)
  (&mbuf_entry_vld) |-> $stable(twu_mask));  // 以 stable 证实：MBUF 满不改变 twu_mask
sva_busy_from_any_dtlb_mb_entry: assert property(@(posedge clk_i) disable iff(!rst_ni)
  mmu_lsu_tlb_busy == (|mb_entry_vld_l1dtlb));
```

---

## 第 10 章 Covergroup 实现侧落点

> 仅列出 **位置 / 触发时钟 / coverpoint 字段表**。覆盖率目标值（百分比、豁免）见 [VerificationPlan §7](MMU_VerificationPlan.md#7-覆盖率计划coverage-plan)。

### 10.1 黑盒 covergroup（在各 agent 内）

| Covergroup         | 文件                           | 触发                                                  | Coverpoint / Cross                                                                                               |
| ------------------ | ------------------------------ | ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `cg_ifu_req`     | `ifu_covergroups.svh`        | `posedge clk_i iff vif.ifu_mmu_va_vld`              | cp_va_seg(va[62:39] 4 bin), cp_abort                                                                             |
| `cg_ifu_rsp`     | 同                             | `posedge clk_i iff vif.mmu_ifu_pavld`               | cp_pgflt, cp_deny, cp_sec, cross(pgflt,deny)                                                                     |
| `cg_lsu_pipe[2]` | `lsu_covergroups.svh`        | `posedge clk_i iff vif.lsu_mmu_va<i>_vld`           | cp_op{LD,ST}, cp_st_inst, cp_abort, cp_stall, cp_pa_vld, cp_pgflt, cp_access_fault, cross(op,pgflt,access_fault) |
| `cg_lsu_pipe2`   | 同                             | `posedge clk_i iff vif.lsu_mmu_va2_vld`             | cp_va2_vld, cp_pa2_vld, cp_pa2_err, cp_share2, cp_sec2                                                           |
| `cg_lsu_inv`     | 同                             | `posedge clk_i iff (vif.lsu_mmu_tlb_*_inv)`         | cp_kind{ALL,VA,ASID,VA_ASID}, cp_during_ptw, cp_inv_done_latency                                                 |
| `cg_cp0`         | `cp0_covergroups.svh`        | `posedge clk_i iff vif.cp0_mmu_wreg \|\| <priv 切换>` | cp_priv, cp_mxr, cp_sum, cp_mprv, cp_mpp, cp_satp_mode, cross(priv,mxr,sum,mprv)                                 |
| `cg_pmp`         | `pmp_covergroups.svh`        | `posedge clk_i`                                     | cp_entry_hit(0..7), cp_acc_type, cp_violation, cross(entry,acc_type)                                             |
| `cg_sysmap`      | `sysmap_cfg_covergroups.svh` | 配置变更脉冲                                          | cp_region(0..7), cp_attr(sec/ca/buf/sh/so)                                                                       |
| `cg_hpcp`        | `misc_covergroups.svh`       | `posedge clk_i iff hpcp_mmu_cnt_en`                 | cp_iutlb_miss, cp_dutlb_miss, cp_jtlb_miss                                                                       |

### 10.2 白盒 covergroup（在 env 内通过 bind / hierarchical reference）

| Covergroup         | bind 目标              | Coverpoint / Cross                                                                                                              |
| ------------------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `cg_ptw_walk`    | `ptw.sv` 内部        | cp_walk_depth(1/2/3), cp_leaf_level(L0/L1/L2), cp_fault{V,R,W,X,U,A,D,PMP,BUS}, cp_acc_type, cross(walk_depth, acc_type, fault) |
| `cg_l2tlb_bank`  | `mmu_l2tlb.sv` 内部  | cp_bank(0..7), cp_way(0..7), cp_pgs, cp_refill_source{PTW,DIRECT}, cp_rrpv(0..7), cross(bank,way)                               |
| `cg_l1itlb`      | `mmu_l1itlb.sv` 内部 | cp_entry_vld_count(**0..16**), cp_credit_remain, cp_fsm_state                                                             |
| `cg_l1dtlb`      | `mmu_l1dtlb.sv` 内部 | cp_mb_occupancy, cp_fsm_state（**7 状态含 WFG**）                                                                         |
| `cg_l2_reqq`     | `mmu_l2tlb_reqq.sv`  | cp_alloc_idx(0..8), cp_depth(0..9), cp_credit_back                                                                              |
| `cg_tlboper_fsm` | `ct_mmu_tlboper.v`   | cp_fsm_state（7 个 FSM 状态全采样；**INVVA 已简化为 single-pass FSM**）                                                   |

### 10.3 【v3.0 Final 新增】Gap/BUG-Driven Covergroup（对应 VerificationPlan v3 §7.2 新增 5 项）

| Covergroup                                                                   | bind 目标                             | Coverpoint / Cross                                                                                                                                                                                                                    | 关联                                                                |
| ---------------------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `cg_twu_2m_csr_cross`                                                      | `twu.sv`                            | cp_crs2_2m, cp_csr_cross, cp_csr_data_flop_change（前后值比较）, cross(crs2_2m, csr_cross)                                                                                                                                            | F4.NEW.4 / TC-BUG-011 P0 高危（2MB CSR 跨界）                       |
| `cg_xbar_cold_start`                                                       | `one_to_four_xbar.sv`               | cp_first_n_reqs(1..16), cp_twu_id(0..3), cp_twu_req_point_r_init 分布                                                                                                                                                                 | F5.NEW.3 / TC-BUG-014（冷启动轮转分布）                             |
| `cg_l2_store_dtlb_tag`                                                     | `mmu_l2tlb.sv`                      | cp_d_req_type{3'b010 load, 3'b110 store}, cp_arb_l2tlb_is_dtlb, cross(req_type, is_dtlb)                                                                                                                                              | F3.5 / TC-BUG-006（load/store 分流）                                |
| `cg_lsu_req_outstanding`                                                   | `ptw_mbuf.sv`                       | cp_req_high_cycles(分 bin), cp_outstanding_cnt(0,1,>=2), cp_addr_changes_in_req(=0 required)                                                                                                                                          | F4.42a / TC-PMBUF-SERIAL-OUTSTANDING-001 / TC-PMBUF-ADDR-STABLE-001 |
| `cg_mbuf_ptr_hold`                                                         | `ptw_mbuf.sv`                       | bin_on_vld（`mbuf_ptr` 变化且 `lsu_mmu_data_vld`）、bin_on_empty（MBUF 由非空转空）、bin_illegal（其他）                                                                                                                          | F4.42c / TC-PMBUF-PTR-HOLD-001                                      |
| `cg_mb_fsm_wfg`                                                            | `mmu_l1dtlb_mb_entry.sv`            | cp_fsm_state{IDLE,WFG,WFC,PGFLT,ACFLT,ABT,WFI}, cp_wfg_bypass, cross                                                                                                                                                                  | F2.3a/b（MB FSM WFG/bypass/竞争）                                   |
| `cg_sfence_invva_pgs`                                                      | `ct_mmu_tlboper.v`                  | cp_pgs{4K,2M,1G,MIX}, cp_invva_pass_count(=1 expected), cross(pgs, single_pass)                                                                                                                                                       | F8.NEW.1（single-pass FSM 混合页面大小）                            |
| **`cg_twu_pipeline_occupancy`**【v3.0 Final 新增 · TWU 流水线澄清】 | `twu.sv`                            | cp_stage_vld{fst_pmp_vld, fst_chk_vld, scd_pmp_vld, scd_chk_vld, thd_pmp_vld, thd_chk_vld, csr_busy} 每 bit 0/1、cp_occupancy(0..6) 同时在飞笔数、cp_back2back(连续 N 周期接收 `xbar_twu_req`, N=1..6)、cross(occupancy, back2back) | F4.NEW.2 / F4.5（TWU 流水线架构、单 TWU 多笔在飞）                  |
| **`cg_twu_mask_per_twu`**【v3.0 Final 新增 · twu_mask 语义修正】    | `twu.sv` / `one_to_four_xbar.sv`  | cp_twu_id(0..3)、cp_twu_mask_bit(0/1)、cp_mask_cause{fst_pmp_wait, scd_pmp_wait, thd_pmp_wait, fst_chk_nonleaf_wait, scd_chk_nonleaf_wait}、cp_mask_all(全 4 mask)、cp_ready_has_one(任一 ready)、cross(twu_id, mask_cause)           | F4.52 / F4.NEW.2（per-TWU mask 语义 + xbar 联动）                   |
| **`cg_mbuf_no_overflow`**【v3.0 Final 新增 · MBUF 不溢出断言覆盖】  | `ptw_mbuf.sv` + `mmu_l2tlb_mb.sv` | cp_ptw_mbuf_occ(0..9)、cp_l2tlb_mb_occ(0..对应配额)、cp_diff = L2TLB_MB_occ − PTW_MBUF_occ（**期望恒 ≥ 0**）                                                                                                                  | F4.6（MBUF 配额一一对应不溢出）                                     |
| **`cg_tlb_busy_source`**【v3.0 Final 新增 · tlb_busy 源头澄清】     | `mmu_l1dtlb.sv` + `ptw_mbuf.sv`   | cp_dtlb_mb_any(`|mb_entry_vld`)、cp_ptw_mbuf_full、cp_tlb_busy、cross(dtlb_mb_any, tlb_busy) **期望等价**；cross(ptw_mbuf_full, tlb_busy) **期望独立**                                                               | F4.24 / F4.53（tlb_busy 由 L1 DTLB 任意 MB entry 在途驱动）          |

### 10.4 【v4.0 新增】plan_v4/v5/v6 Covergroup 落点

| Covergroup                       | RTL 绑定文件                         | 采样点 / 交叉覆盖                                                                                      | 对应 F-ID                          |
| -------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------ | ---------------------------------- |
| `cg_dtlb_mmu_off`              | `mmu_l1dtlb.sv`                    | cp_mmu_off_state(0/1)、cp_l2req_sent_when_off(应为0)、cross                                            | F2.NEW.3（MMU off 广播）           |
| `cg_l2tlb_req_type`            | `mmu_l1dtlb.sv` / `mmu_arb.sv`   | cp_is_load(0/1)、cp_req_type{LD,ST}、cross(is_load, req_type)                                          | F2.NEW.4（req_is_load 标志）       |
| `cg_l2ref_dual_signal`         | `mmu_l1dtlb.sv`                    | cp_ref_cmplt(0/1)、cp_ref_pavld(0/1)、cross(cmplt, pavld) — 期望 {1,0} 合法                           | F2.NEW.5（L2TLB 回填双信号）       |
| `cg_ptw_ref_dual_signal`       | `mmu_l1dtlb.sv` / `ptw.sv`       | cp_ptw_cmplt(0/1)、cp_ptw_pavld(0/1)、cross — AccessFault/PageFault 路径 {1,0}                        | F2.NEW.6（PTW→L1DTLB 回填双信号） |
| `cg_ptw_l2ref_dual_signal`     | `mmu_l2tlb.sv` / `ptw.sv`        | cp_l2_cmplt(0/1)、cp_l2_data_vld(0/1)、cross — error 路径 {1,0}                                       | F3.NEW.4（PTW→L2TLB 回填双信号）  |
| `cg_l2tlb_cmp_mode`            | `mmu_arb.sv` / `mmu_l2tlb.sv`    | cp_cmp_with_va(0/1)、cp_pgs{4K,2M,1G}、cross(cmp_with_va, pgs)                                         | F3.NEW.2（Tag 比较模式）           |
| `cg_l2tlb_ptw_cmplt`           | `mmu_l2tlb.sv`                     | cp_ptw_cmplt_pulse(1周期脉冲)、cp_cmplt_after_refill_cycles(1..4)                                      | F3.NEW.3（L2TLB PTW 完成通知）     |
| `cg_l2ptw_id_coverage`         | `mmu_l2tlb.sv` / `ptw.sv`        | cp_id_width(完整宽度)、cp_concurrent_ids(1..9)、cp_id_unchanged(PTW返回=发出)                          | F3.NEW.5（复合 ID 端到端）         |
| `cg_ptw_ready_transition`      | `ptw.sv` / `one_to_four_xbar.sv` | cp_ready_state(0/1)、cp_mask_count(0..4)、cp_ready_edge{rise, fall}、cross                             | F4.NEW.6（PTW ready 反压）         |
| `cg_twu_idle_vs_mask_state`    | `twu.sv`                           | cp_twu_idle(0/1)、cp_twu_mask(0/1)、cross — {idle=1,mask=1} 非法                                      | F4.NEW.7（idle vs mask 语义）      |
| `cg_xbar_hit_level`            | `one_to_four_xbar.sv` / `twu.sv` | cp_hit_level{3'b000,3'b001,3'b010,3'b100}、cross(hit_level, skip_stage)                                | F4.NEW.8（PDE Cache 命中级别）     |
| `cg_twu_except_while_arb_busy` | `twu.sv` / `mmu_l2tlb.sv`        | cp_arb_busy(0/1)、cp_pgflt(0/1)、cp_acc_err(0/1)、cross(arb_busy, except_type)                         | F4.NEW.9（异常直通旁路）           |
| `cg_twu_data_ready_per_stage`  | `ptw_mbuf.sv` / `twu.sv`         | cp_stage{FST,SCD,THD}、cp_data_ready(0/1)、cp_have(0/1)、cross                                         | F4.NEW.10（data_ready 分级门控）   |
| `cg_arb_grant_type`            | `mmu_arb.sv`                       | cp_grant_type{refill,pgflt,acc_err}、cp_concurrent_req(1..4)、cross(type, concurrent)                  | F4.NEW.11（三通道 grant 仲裁）     |
| `cg_ptw_arb_pgs_type`          | `mmu_arb.sv` / `ptw.sv`          | cp_pgs{4K,2M,1G}、cp_vpn_matches_tag(0/1)、cross                                                       | F5.16（ptw_arb_ref_vpn）           |
| `cg_maee_leaf_level`           | `twu.sv`                           | cp_maee(0/1)、cp_leaf_level{FST,SCD,THD}、cp_csr_req(0/1)、cp_refill_req(0/1)、cross(maee, leaf_level) | F4.NEW.12（MAEE 叶级触发）         |
| `cg_maee_path`                 | `twu.sv`                           | cp_maee(0/1)、cp_path{csr_fsm, direct_refill}、cross — 互斥验证                                       | F4.NEW.12 / F6.NEW.1（MAEE 选路）  |
| `cg_pmp_per_level_result`      | `twu.sv`                           | cp_level{FST,SCD,THD}、cp_result{pass, deny, wait}、cross(level, result)                               | F4.NEW.13 / F7.NEW.3（PMP 序列化） |
| `cg_pmp_grant_level`           | `twu.sv`                           | cp_pmp_grant{3'b000,3'b001,3'b010,3'b100}、cp_one_hot_check                                            | F4.NEW.14（pmp_grant one-hot）     |
| `cg_pmp_pa_format`             | `twu.sv`                           | cp_pgs{4K,2M,1G,none}、cp_pa_low_zero{[8:0]=0, [17:0]=0, [27:0]=valid}、cross                          | F4.NEW.14 / F7.NEW.4（PA 页对齐）  |
| `cg_pmp_deny_by_level`         | `twu.sv`                           | cp_level{FST,SCD,THD}、cp_deny_cause{R=0,W=0,X=0}、cp_mode{M+L0,M+L1,S,U}、cross                       | F7.NEW.5（PMP deny 场景）          |
| `cg_twu_mask_cause`            | `twu.sv`                           | cp_mask_cause{fst_pmp_wait,scd_pmp_wait,thd_pmp_wait}、cp_mask_all(0/1)                                | F7.NEW.6（PMP wait→mask 传播）    |
| `cg_ptw_pmp_port_map`          | `ptw.sv`                           | cp_port{3,5,6,7}、cp_twu{one,two,three,four}、cp_pa_routed、cross                                      | F7.NEW.9（PTW PMP 端口映射）       |
| `cg_sysmap_flg_per_region`     | `ct_mmu_sysmap.v` / `twu.sv`     | cp_region{0..7}、cp_flg_bits{5'd0..5'd31}(关键值采样)、cp_maee0_refill_match                           | F6.NEW.2（sysmap flag 替换）       |
| `cg_sysmap_cross_1g`           | `twu.sv`                           | cp_cross(0/1)、cp_pgs_before{1G}、cp_crs1_hit、cp_crs2_hit、cross(cross, hit_pair)                     | F6.NEW.3（1G 跨界检测）            |
| `cg_sysmap_cross_2m`           | `twu.sv`                           | cp_cross(0/1)、cp_pgs_before{2M}、cp_crs1_hit、cp_crs2_hit、cross                                      | F6.NEW.3（2M 跨界检测）            |
| `cg_sysmap_degrade_pgs`        | `twu.sv`                           | cp_before_pgs{1G,2M,4K}、cp_after_pgs{2M,4K}、cross(before,after) — 降级规则                          | F6.NEW.4（跨界降级）               |
| `cg_sysmap_pa_align`           | `twu.sv`                           | cp_pgs{4K,2M,1G}、cp_pa_low_zero{[8:0]=0,[17:0]=0,valid}、cross                                        | F6.NEW.5（PA 页级对齐）            |
| `cg_sysmap_4twu_concurrent`    | `ptw.sv`                           | cp_twu_count{1,2,3,4}同时 CSR 查询、cp_port_map_correct                                                | F6.NEW.6（4 TWU 并发查询）         |
| `cg_sysmap_default_flag`       | `ct_mmu_sysmap.v`                  | cp_no_hit(0/1)、cp_default_flg(5'b10011)、cp_propagated_to_tlb                                         | F6.NEW.7（无命中默认属性）         |

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

参考 [VerificationPlan §6.3](MMU_VerificationPlan.md#63-test-case-详表) 与 [MMU_VerificationPlan_v3.md](../lc_test_plan_doc/MMU_VerificationPlan_v3.md) §6.5 Gap/BUG TC 清单：

| 目录                                                     | 涵盖 F-ID                                            | TC 数（参考）                   |
| -------------------------------------------------------- | ---------------------------------------------------- | ------------------------------- |
| `basic_tests/`                                         | 跨多类                                               | 3                               |
| `l1itlb_tests/`                                        | F1                                                   | ≈12                            |
| `l1dtlb_tests/`                                        | F2                                                   | ≈14                            |
| `l2tlb_tests/`                                         | F3                                                   | ≈14                            |
| `ptw_tests/`                                           | F4                                                   | ≈17                            |
| `tlbop_tests/`                                         | F8                                                   | ≈10                            |
| `pmp_tests/`                                           | F7                                                   | ≈8                             |
| `sysmap_tests/`                                        | F6                                                   | ≈4                             |
| `cp0_tests/`                                           | F9                                                   | ≈13                            |
| `flush_tests/`                                         | F10/F13                                              | ≈6                             |
| `cross_tests/`                                         | 跨多类                                               | ≈16                            |
| `perf_tests/`                                          | F11/F14                                              | ≈8                             |
| `err_tests/`                                           | F12/异常                                             | ≈8                             |
| **`bug_hunt_tests/`【v3.0 Final 新增】**         | **Gap-Driven TC-BUG-* 专项**                     | **13（含升/降级与新增）** |
| **`ptw_lsu_protocol_tests/`【v3.0 Final 新增】** | **F4.42a/b/c PTW→LSU 严格串行握手**           | **5**                     |
| **`ifu_hold_tests/`【v3.1 新增】**               | **IFU miss-hold 严格协议（core 行为）**            | **4**                     |
| **`lsu_expt_lifecycle_tests/`【v3.1 新增】**     | **LSU expt 生命周期（产生/挂起/唤醒/回放/消费）**   | **6**                     |
| `maee_twu_tests/`【v4.0 新增】                         | F4.NEW.12 TWU MAEE 双路属性选路                      | 4                               |
| `pmp_twu_tests_v6/`【v4.0 新增】                       | F4.NEW.13/14 / F7.NEW.3-9 PMP 序列化与端口映射       | ≈18                            |
| `sysmap_tests/`（v4.0 扩充）                           | F6 / F6.NEW.1-7 sysmap flag 替换、跨界降级           | ≈22（原≈4+18新增）            |
| `ptw_tests/`（v4.0 扩充）                              | F4 / F4.NEW.6-11 PTW ready 反压、TWU 旁路、MBUF 门控 | ≈31（原≈17+14新增）           |
| `pmp_tests/`（v4.0 扩充）                              | F7 / F7.NEW.3-9 PMP deny/wait/端口                   | ≈14（原≈8+6新增）             |

#### 11.2.1 【v3.0 Final】`bug_hunt_tests/` 目录文件清单

> 命名与 [`MMU_Traceability_Matrix.csv`](./MMU_Traceability_Matrix.csv) TC-ID 对齐；每个 test 头部注释需声明 `PRIORITY=` 与 `STATUS=`（`Blocked-Waiting-RTL-Fix` 对应等待设计修复）。

| 文件                                             | F-ID               | Priority                   | Status                  | 处置说明（对齐 plan_v3 §A/§B/§C）                                                                                                                                                                                                 |
| ------------------------------------------------ | ------------------ | -------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `tc_bug_001_twu_fst_fetch_type.sv`             | F4.NEW.2           | **P1**（由 P0 降级） | Functional              | 错判证伪：scd/thd 各级使用独立 `*_pmp_fetch_type`，非缺陷；保留作功能覆盖                                                                                                                                                          |
| `tc_bug_002_thd_chk_4k_a_bit.sv`               | F4.NEW.3           | **P1**（由 P0 降级） | Functional              | 错判证伪：thd_chk 必为叶 PTE，A-bit 检测正常；保留 `sva_thd_a_bit_pgflt` 正向保护                                                                                                                                                  |
| `tc_bug_003_thd_chk_leaf_refill.sv`            | F4.NEW.1           | **P1**（由 P0 降级） | Functional              | 错判证伪：`thd_chk_refill_req` 与 `mbuf_cache_upd` 非叶限制不矛盾；保留 `sva_pde_nonleaf_upd`                                                                                                                                  |
| `tc_bug_004_mmu_arb_bank_mask.sv`              | F5.NEW.1           | **P1**（由 P0 降级） | Functional              | 错判证伪：`mmu_arb.sv#L142` 字面量为 `8'b00110011` 完整形式；保留作正向覆盖                                                                                                                                                      |
| `tc_bug_005_l2_raw_vld_and_gate.sv`            | F3.4               | **P0**（由 P1 升级） | Blocked-Waiting-RTL-Fix | 真实缺陷：`raw_vld = pipe_vld \|\| ptw_req` 应为 `&&`，SVA `sva_raw_vld_and_gate`                                                                                                                                                |
| `tc_bug_006_l2_is_dtlb_store.sv`               | F3.5               | **P0**（由 P1 升级） | Blocked-Waiting-RTL-Fix | 真实缺陷：`arb_l2tlb_is_dtlb` 重复 `3'b010`、漏 `3'b110`；covergroup `cg_l2_store_dtlb_tag`                                                                                                                                  |
| `tc_bug_007_rrpv_post_inv.sv`                  | F3.NEW.1           | **P0**（由 P1 升级） | Blocked-Waiting-RTL-Fix | 真实缺陷：SFENCE 无效化后 RRPV 残留；SVA `sva_rrpv_inv_state`                                                                                                                                                                      |
| `tc_bug_008_pplru_entry0_first_hit.sv`         | F12.NEW.1          | **P0**（由 P1 升级） | Blocked-Waiting-RTL-Fix | 真实缺陷：复位后 entry 0 首次命中 PLRU 不更新；SVA `sva_pplru_entry0_first_hit`                                                                                                                                                    |
| ~~`tc_bug_009_twu_csr_arb_dup.sv`~~           | —                 | —                         | **DELETED_v3**    | 证伪删除：`twu.sv` CSR Arbiter 实际 case `2'b01`/`2'b10`，不重复。编号保留 gap                                                                                                                                                 |
| ~~`tc_bug_010_csr_fsm_idle_latch.sv`~~        | —                 | —                         | **DELETED_v3**    | 证伪删除：CSR FSM IDLE 有 `else ptw_nxt_st = TWU_IDLE` 闭合分支                                                                                                                                                                    |
| **`tc_bug_011_twu_2m_csr_cross.sv`**     | **F4.NEW.4** | **P0 高危（R19）**   | Blocked-Waiting-RTL-Fix | **新发现**：`twu.sv#L1128-L1133` 分支重复，推测第二行应为 `twu_crs2_2m && twu_csr_cross`；2MB 巨页 CSR 跨界 `csr_data_flop` 不更新；SVA `sva_twu_2m_cross_data` + cg `cg_twu_2m_csr_cross`；**独立 JIRA 工单** |
| **`tc_bug_012_csr_grant_onehot.sv`**     | F4.NEW.5           | P1                         | Planned                 | 新盲点：`csr_grant[1:0]=2'b11` 偏向 1G 分支；SVA `sva_csr_grant_onehot`                                                                                                                                                          |
| **`tc_bug_013_ptw_write_pipe_reset.sv`** | F5.NEW.2           | P1                         | Planned                 | 新盲点：PTW 写双级流水 reset 竞争；SVA `sva_ptw_write_pipe_reset_safe`                                                                                                                                                             |
| **`tc_bug_014_xbar_cold_start.sv`**      | F5.NEW.3           | P1                         | Planned                 | 新盲点：`twu_req_point_r` 复位 `4'b0001` 偏向 TWU0；cg `cg_xbar_cold_start`                                                                                                                                                    |
| **`tc_bug_015_invva_legacy_fsm_doc.sv`** | F8.NEW.2           | P2                         | DOC_REVIEW（非仿真 TC） | 14-state INVVA FSM 注释残留；代码评审追踪                                                                                                                                                                                            |

#### 11.2.2 【v3.0 Final】`ptw_lsu_protocol_tests/` 目录文件清单

| 文件                                   | F-ID   | Priority | Status  | 目标 SVA / covergroup                                                                    |
| -------------------------------------- | ------ | -------- | ------- | ---------------------------------------------------------------------------------------- |
| `tc_pmbuf_serial_outstanding_001.sv` | F4.42a | P0       | Planned | `sva_single_outstanding`、`sva_lsu_req_stable_until_vld`、`cg_lsu_req_outstanding` |
| `tc_pmbuf_addr_stable_001.sv`        | F4.42a | P0       | Planned | `sva_lsu_addr_stable_until_vld`、`cg_lsu_req_outstanding`                            |
| `tc_pmbuf_no_tag_001.sv`             | F4.42b | P0       | Planned | `sva_vld_only_when_req`                                                                |
| `tc_pmbuf_inorder_resp_001.sv`       | F4.42b | P0       | Planned | `sva_response_inorder`                                                                 |
| `tc_pmbuf_ptr_hold_001.sv`           | F4.42c | P1       | Planned | `sva_mbuf_ptr_only_on_response`、`cg_mbuf_ptr_hold`                                  |

#### 11.2.2a 【v3.0 Final 新增】`ptw_twu_arch_tests/` — TWU 流水线 / MBUF 配额 / twu_mask 语义修正支持 TC

| 文件                                 | F-ID            | Priority | Status  | 目标 SVA / covergroup                                                                                |
| ------------------------------------ | --------------- | -------- | ------- | ---------------------------------------------------------------------------------------------------- |
| `tc_twu_pipeline_back2back_001.sv` | F4.NEW.2 / F4.5 | P0       | Planned | `sva_twu_pipeline_no_stall_when_unmasked`、`cg_twu_pipeline_occupancy`（N=2..6 bin）             |
| `tc_twu_multi_inflight_001.sv`     | F4.5 / F4.NEW.2 | P1       | Planned | `sva_twu_multi_inflight_legal`、`cg_twu_pipeline_occupancy`（occupancy≥2）                      |
| `tc_twu_mask_self_001.sv`          | F4.52           | P0       | Planned | `sva_twu_mask_semantics`、`cg_twu_mask_per_twu`（单 TWU mask，其余 ready）                       |
| `tc_twu_mask_all_001.sv`           | F4.52           | P0       | Planned | `sva_xbar_drop_when_all_mask`、`sva_twu_ready_equiv`、`cg_twu_mask_per_twu.cp_mask_all`        |
| `tc_mbuf_no_overflow_001.sv`       | F4.6            | P0       | Planned | `sva_ptw_mbuf_no_overflow`、`sva_no_backpressure_to_twu_from_mbuf_full`、`cg_mbuf_no_overflow` |
| `tc_busy_any_dtlb_mb_001.sv`       | F4.24 / F4.53   | P0       | Planned | `sva_busy_from_any_dtlb_mb_entry`、`cg_tlb_busy_source`（交叉等价）                                   |

#### 11.2.3 【v3.0 Final】Agent 扩写要点（对应 `ptw_lsu_protocol_tests/` 支持）

`ptw_mem_agent` 增补：

- **Monitor**：`single_outstanding_checker` 子线程，跟踪 `mmu_lsu_data_req` 拉高周期数、地址变化计数、与 `lsu_mmu_data_vld` 对齐关系，驱动 `cg_lsu_req_outstanding` / `cg_mbuf_ptr_hold` 采样
- **Sequences**（新增）：`ptw_resp_inorder_seq`、`ptw_resp_back2back_seq`、`ptw_resp_delay_seq`（严格按序前提下注入抖动）
- **反向错误注入 sequences**（默认 disable，仅用于 SVA 负向测试）：`bad_vld_no_req_seq`、`bad_addr_change_seq`
- **【v3.0 Final 追加 · TWU/MBUF 架构澄清】Monitor 保护性检查**：
  - `no_overflow_checker`：采样 `ptw_mbuf_occ` 与 `l2tlb_mb_occ`，断言 `ptw_mbuf_occ ≤ l2tlb_mb_occ ≤ 配额`；若出现 `ptw_mbuf_occ > l2tlb_mb_occ` 立刻 `uvm_fatal`（证伪"配额一一对应"假设即测试失败）
  - `twu_mask_source_checker`：采样 `twu_mask[3:0]` 与 `fst_pmp_wait / scd_pmp_wait / thd_pmp_wait / <非叶 chk wait>`，**不得**把 `&mbuf_entry_vld`（MBUF 满）加入 `twu_mask` 推导；对应 `sva_twu_mask_semantics`
  - `tlb_busy_source_checker`：断言 `mmu_lsu_tlb_busy ⇔ |mb_entry_vld_l1dtlb`（F4.24 / F4.53），与 `ptw_mbuf_full` **无直接等价**
- **【v3.0 Final 追加 · TWU 流水线压测】Sequences**：
  - `twu_pipeline_back2back_seq`：背靠背连续 N 拍注入 xbar PDE 请求（N=2..6），观察 `fst_pmp_vld → fst_chk_vld → scd_pmp_vld → ...` 流水充满，期望 `cg_twu_pipeline_occupancy.cp_occupancy` 覆盖 2~6 bin
  - `twu_mask_single_seq` / `twu_mask_all_seq`：通过 PMP 拒绝延迟制造单 TWU mask 与四 TWU 同时 mask 场景，分别验证 xbar 仍能派发给其余 TWU 与 xbar 全停一周期不丢请求
  - `twu_multi_inflight_seq`：同一 TWU 不同级分别走 1G/2M/4K 路径，验证一 TWU 多笔 PTE 读在飞（与 MBUF 多笔共享响应）

`cp0_agent` 增补：driver 支持 CSR 细分字段 `reg_num/mpp/wdata/wreg/cskyee`（§14 组）。

`misc_agent` 增补：`mmu_xx_mmu_en` 广播信号驱动（切换顶层 en）；`mmu_cp0_tlb_done` TLB Oper 完成握手 monitor（§13 组）。

### 11.3 测试类模板（仅签名）

```systemverilog
class test_mmu_<category>_<scenario> extends test_base;
  `uvm_component_utils(test_mmu_<category>_<scenario>)
  function new(string name, uvm_component parent);
  extern task main_phase(uvm_phase phase);
endclass
```

### 11.4 +plusarg 协议

| Plusarg                  | 类型   | 默认值          | 用途                     |
| ------------------------ | ------ | --------------- | ------------------------ |
| `+TEST_NAME=<name>`    | string | （Makefile 传） | UVM 启动测试             |
| `+UVM_TESTNAME=<name>` | string | 同上            | UVM 标准                 |
| `+SEED=<int>`          | int    | random          | VCS `+ntb_random_seed` |
| `+NB_TXNS=<int>`       | int    | 5000            | 主激励数量               |
| `+UVM_VERBOSITY=<lvl>` | string | UVM_MEDIUM      | 日志级别                 |
| `+TIMEOUT=<ns>`        | int    | 10000000        | watchdog 超时            |

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
${MMU_RTL_DIR}/mmu_l1dtlb_expt_cam.sv
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

| Target         | 说明                                            |
| -------------- | ----------------------------------------------- |
| `compile`    | VCS 编译生成 simv                               |
| `run`        | 运行单个 TEST_NAME                              |
| `wave`       | Verdi 加载 fsdb                                 |
| `cov_merge`  | URG 合并各次仿真覆盖率                          |
| `cov_report` | 生成 HTML 覆盖率报告                            |
| `regress`    | 调用 `scripts/run_test.py` 跑 regression list |
| `clean`      | 清理 output                                     |

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

### Phase 11：【v3.0 Final 新增】v3.0 Gap-driven 回归

- **交付范围**：
  - `simu/mmu_bug_hunt_list`：包含 `tc_bug_005`~`008`（真实缺陷 P0，`xfail` 标注直到 RTL 修复）、`tc_bug_011`（R19 P0 高危，独立 JIRA 跟踪，**修复前冻结 2MB CSR 跨界相关 TC**）、`tc_bug_012`~`014`（P1 新盲点）、`tc_bug_015`（P2 DOC_REVIEW，非仿真）
  - `simu/mmu_ptw_lsu_protocol_list`：包含 5 个 `tc_pmbuf_*` 用例（F4.42a/b/c P0/P1）
  - `simu/mmu_v3_regression_list`：Union 上述 + 正向保护（`tc_bug_001`~`004` P1 Functional、cg/SVA 全绿）
  - `Makefile` 添加 `regress_v3_gap` target
- **JIRA 联动**：
  - R19（F4.NEW.4 / TC-BUG-011）独立 JIRA；修复前 `tc_bug_011` 与依赖 `csr_data_flop` 的 2MB CSR 跨界场景 TC 设置 `Status=Blocked-Waiting-RTL-Fix` + `xfail`
  - R20（F5.NEW.2 / F5.NEW.3）中等风险，由 `sva_ptw_write_pipe_reset_safe` + `cg_xbar_cold_start` 作为主保护
- **签核增量条件**：
  1. `tc_bug_005`~`008`、`tc_bug_011` 全 pass（或 known-fix 关闭）
  2. F4.42a/b/c 全部 SVA 全绿，`cg_lsu_req_outstanding` / `cg_mbuf_ptr_hold` 100% 命中
  3. `cg_twu_2m_csr_cross` / `cg_xbar_cold_start` / `cg_l2_store_dtlb_tag` / `cg_mb_fsm_wfg` / `cg_sfence_invva_pgs` 达 [VerificationPlan v3 §7 覆盖率目标](../lc_test_plan_doc/MMU_VerificationPlan_v3.md)
- **退出准则**：R19 关闭 或 `tc_bug_011` pass；R20 两条 SVA/cg 无 fire + 分布平衡；`mmu_v3_regression_list` 通过率 100%。

### Phase 12：【v4.0 新增】plan_v4/v5 MAEE 双路、PTW-ready 反压与 TWU 旁路验证

- **交付范围**：
  - `testbench/test/maee_twu_tests/` 目录（4 个 TC：`TC-TWU-MAEE0-CSR-001/002`、`TC-TWU-MAEE1-REFILL-001`、`TC-TWU-MAEE-SWITCH-001`）
  - `testbench/top/mmu_maee_twu_sva.sv`（`sva_twu_maee_paths_mutex` / `sva_maee0_triggers_csr_req` / `sva_maee1_skips_csr_fsm`）
  - `testbench/top/mmu_pmp_twu_sva.sv`（骨架，详见 Phase 13 补全）
  - `testbench/test/ptw_tests/` 扩充：`TC-PTW-READY-001/002/003`（F4.NEW.6）、`TC-TWU-IDLE-MASK-001`（F4.NEW.7）、`TC-PDE-CACHE-HIT-L3/L2/MISS-001`（F4.NEW.8）、`TC-TWU-PGFLT/ACCERR/EXCEPT-BYPASS-001`（F4.NEW.9）、`TC-MBUF-READY-GATE/HAVE/MULTI-001`（F4.NEW.10）、`TC-ARB-GRANT/REFILL-PRIO/FAIRNESS-001`（F4.NEW.11）、`TC-ARB-VPN/PGS-MATCH-001`（F5.16）
  - 对应 covergroup：`cg_ptw_ready_transition` / `cg_twu_idle_vs_mask_state` / `cg_xbar_hit_level` / `cg_twu_except_while_arb_busy` / `cg_twu_data_ready_per_stage` / `cg_arb_grant_type` / `cg_ptw_arb_pgs_type` / `cg_maee_leaf_level` / `cg_maee_path`
  - `simu/mmu_v4_phase12_list` 回归列表
  - `Makefile` 添加 `regress_v4_maee_ptw` target
- **签核增量条件**：
  1. MAEE 双路 SVA（`sva_twu_maee_paths_mutex`）全绿，`cg_maee_path` 两路 bins 均命中
  2. `cg_ptw_ready_transition` 含 fall/rise edge，ready 拉低恢复时序正确
  3. F4.NEW.6-11 全部 TC 单跑通过
- **退出准则**：Phase 12 列表通过率 100%；MAEE + PTW-ready + TWU-bypass SVA 无 fire。

### Phase 13：【v4.0 新增】plan_v6 sysmap / PMP-deny / PMP-port 验证

- **交付范围**：
  - `testbench/test/pmp_twu_tests_v6/` 目录（`TC-TWU-PMP-SERIAL-001`、`TC-TWU-PMP-WAIT-STALL-001`、`TC-PTW-PMP-BEFORE-LSU-001`、`TC-PTW-PMP-DENY-STOP-001`、`TC-TWU-PMP-GRANT-ONEHOT-001`、`TC-PTW-PMP-PA-1G/2M/4K-001`、`TC-PTW-PMP-WAIT-NO-LSU-001`、`TC-PTW-PMP-PA-ZERO-001`、`TC-PTW-PMP-DENY-ACCFLT/NO-REFILL-001`、`TC-PTW-PMP-MMODE-L0/L1-001`、`TC-TWU-MASK-PMP-WAIT/ALL4-001`、`TC-PTW-PMP-FETCH-ZERO-001`、`TC-PTW-PMP-R-CHECK-001`、`TC-PTW-PMP-TYPO-BIND-001`、`TC-PTW-PMP-PORT-MAP/CONCURRENT-001`）
  - `testbench/top/mmu_pmp_twu_sva.sv` 完整实现（见 §9.2 v4.0 SVA 表）
  - `testbench/test/sysmap_tests/` 扩充（`TC-SYSMAP-MAEE0-ATTR-001/002`、`TC-SYSMAP-MAEE1-SKIP-CSR-001`、`TC-SYSMAP-FLG-REFILL/REGION0/REGION7-001`、`TC-SYSMAP-CROSS-SAME/1G/2M/PARTIAL-001`、`TC-SYSMAP-DEGRADE-1G2M/2M4K/NO-1G/NO-2M-001`、`TC-SYSMAP-PA-ALIGN-1G/2M/4K-001`、`TC-SYSMAP-4TWU-CONCURRENT/PORT-MAP-001`、`TC-SYSMAP-NO-HIT-DEFAULT/DEFAULT-FLAG-BIT-001`）
  - `testbench/top/mmu_sysmap_sva.sv`（`sva_csr_refill_flg_matches_sysmap` / `sva_sysmap_cross_degrade` / `sva_sysmap_no_cross_no_degrade`）
  - 对应 covergroup：`cg_pmp_per_level_result` / `cg_pmp_grant_level` / `cg_pmp_pa_format` / `cg_pmp_deny_by_level` / `cg_twu_mask_cause` / `cg_ptw_pmp_port_map` / `cg_sysmap_flg_per_region` / `cg_sysmap_cross_1g` / `cg_sysmap_cross_2m` / `cg_sysmap_degrade_pgs` / `cg_sysmap_pa_align` / `cg_sysmap_4twu_concurrent` / `cg_sysmap_default_flag`
  - `simu/mmu_v4_phase13_list` 回归列表
  - `Makefile` 添加 `regress_v4_sysmap_pmp` target
- **关键 RTL 对位**：
  - `pmp_if.sv` 使用 `mmu_pmp_fecth7`（typo）绑定，验证 `TC-PTW-PMP-TYPO-BIND-001`（F7.NEW.8）；编译失败即验证失败
  - PTW PMP 端口映射：pa3/flg3→twu_one，pa5/flg5→twu_two，pa6/flg6→twu_three，pa7/flg7→twu_four（需设计确认 DA-003）
- **签核增量条件**：
  1. PMP 序列化 SVA（`sva_pmp_check_before_lsu_req` / `sva_pmp_wait_implies_mask`）全绿
  2. sysmap 跨界降级 SVA（`sva_sysmap_cross_degrade`）全绿，`cg_sysmap_degrade_pgs` cross bins 命中
  3. `cg_sysmap_flg_per_region` 全 8 region bin 命中
- **退出准则**：Phase 13 列表通过率 100%；PMP + sysmap SVA 无 fire；DA-003 已设计确认或有 workaround。

### Phase 14：【v4.0 新增】全量回归收敛与签核

- **交付范围**：
  - `simu/mmu_v4_full_regression_list`：Union Phase 1–13 全量列表（`mmu_v3_regression_list` + Phase 12/13 新增 TC）
  - `simu/mmu_v4_coverage_merge.sh`：合并所有 Phase 覆盖率数据库
  - `simu/exclude_v4.do`：Phase 12/13 新增豁免条目（DA-003 冲突端口等待确认期间的豁免）
  - `Makefile` 添加 `regress_v4_full` target
- **JIRA 联动**：
  - DA-003（pa3 端口归属冲突）解决前 `TC-PTW-PMP-PORT-MAP-001` 设置 `Status=Blocked-Waiting-Design-Confirm`
  - F7.NEW.8 typo 绑定（`mmu_pmp_fecth7`）纳入静态代码检查 checklist
- **签核增量条件**：
  1. 全量 FA/FB/FC covergroup 达 [VerificationPlan v3 §7](../lc_test_plan_doc/MMU_VerificationPlan_v3.md) 目标
  2. 所有 P0 SVA 无 fire（含 Phase 12/13 新增）
  3. DA-003 已关闭或有书面 waiver
- **退出准则**：`mmu_v4_full_regression_list` 通过率 100%（DA-003 waiver 标注除外）；覆盖率达标；签核矩阵更新。

### 阶段交付物总量

| Phase | 新建文件数                                             | 累计文件数 |
| ----- | ------------------------------------------------------ | ---------- |
| 1     | ≈ 8                                                   | 8          |
| 2     | ≈ 10                                                  | 18         |
| 3     | ≈ 30                                                  | 48         |
| 4     | ≈ 12                                                  | 60         |
| 5     | ≈ 19                                                  | 79         |
| 6     | ≈ 10                                                  | 89         |
| 7     | ≈ 13                                                  | 102        |
| 8     | ≈ 0（仅填充）                                         | 102        |
| 9     | ≈ 120（test case 文件）                               | 222        |
| 10    | ≈ 4（回归列表 + exclude）                             | 226        |
| 11    | ≈ 20（gap-driven TC + 回归列表）                      | 246        |
| 12    | ≈ 24（MAEE / PTW-ready / TWU-bypass TC + 3 SVA 文件） | 270        |
| 13    | ≈ 30（sysmap / PMP-deny / PMP-port TC）               | 300        |
| 14    | ≈ 6（全量回归列表 + 覆盖率合并脚本）                  | 306        |

---

## 附录 A：v2 → v3 变更映射

| v2 章节                             | 内容                            | v3 处理                                                  | 归宿                                                                                          |
| ----------------------------------- | ------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Part A 前置决策                     | 工具链 / dv_utils 复用          | ✅ 保留并扩充（新增 Agent 划分表 + hpdcache 对位映射）   | v3 §1                                                                                        |
| Part B.1 顶层互联                   | 框图                            | ✅ 保留                                                  | v3 §2.1                                                                                      |
| Part B.2 子模块参数                 | 参数冻结表                      | ✅ 保留                                                  | v3 §2.2                                                                                      |
| Part B.3 关键 FSM                   | 12 个 FSM                       | ✅ 保留                                                  | v3 §2.3                                                                                      |
| Part B.4 CP0 寄存器位               | 寄存器位影响表                  | ✅ 保留                                                  | v3 §2.5                                                                                      |
| Part C.0–C.13 测试点 196 个 TP-XXX | 测试点列表                      | ❌**剥离**                                         | [VerificationPlan §5（F1–F14 功能点）](MMU_VerificationPlan.md#5-待验证功能点列表feature-list) |
| Part C.14 测试点→用例映射          | 110+ 测试用例映射               | ❌**剥离**                                         | [VerificationPlan §6.3](MMU_VerificationPlan.md#63-test-case-详表)                              |
| Part D.1 mmu_params_pkg             | 包骨架                          | ✅ 保留                                                  | v3 §5.1                                                                                      |
| Part D.2 mmu_common_pkg             | 工具函数                        | ✅ 保留并精简（仅签名）                                  | v3 §5.2                                                                                      |
| Part D.3–D.8 各 agent 骨架         | 类签名 + 部分方法体             | ✅**保留 + 精简方法体**                            | v3 §6, §7, §8                                                                              |
| Part D.9 Files.f                    | 编译顺序                        | ✅ 保留并扩充 misc_agent                                 | v3 §12.1                                                                                     |
| Part D.10 Makefile 变量             | 关键变量                        | ✅ 保留                                                  | v3 §4.3, §12                                                                                |
| Part D.11 目录全量清单              | 目录树                          | ✅ 保留并扩充至 misc_agent / sysmap_cfg_agent / vseq_lib | v3 §3.1                                                                                      |
| Part E.1 代码覆盖率目标             | 99% / 98%                       | ❌**剥离目标值**                                   | [VerificationPlan §7](MMU_VerificationPlan.md#7-覆盖率计划coverage-plan)                        |
| Part E.2 功能 covergroup 表         | covergroup 字段表               | ✅ 保留                                                  | v3 §10                                                                                       |
| Part E.3 SVA 文件                   | SVA 清单                        | ✅ 保留                                                  | v3 §9.2                                                                                      |
| Part F.1 回归列表                   | smoke / nightly / coverage list | ❌**剥离**                                         | [VerificationPlan §8](MMU_VerificationPlan.md#8-回归测试策略regression-strategy)                |
| Part F.2 签核矩阵                   | 签核条目表                      | ❌**剥离**                                         | [VerificationPlan §9](MMU_VerificationPlan.md#9-签核标准signoff-criteria)                       |
| —（v2 无）                         | 实施落地 10 阶段                | ✨**新增**                                         | v3 §13                                                                                       |
| —（v2 无）                         | 端口分组→Agent 映射            | ✨**新增**                                         | v3 §2.4                                                                                      |
| —（v2 无）                         | 与 hpdcache 框架对位映射        | ✨**新增**                                         | v3 §1.3                                                                                      |
| —（v2 无）                         | 文档定位与范围声明              | ✨**新增**                                         | v3 §0                                                                                        |

---

## 附录 B：与 VerificationPlan 引用对照表

| 本文档章节                   | 引用 VerificationPlan                     |
| ---------------------------- | ----------------------------------------- |
| §0.2（不写内容清单）        | §5 / §6 / §7 / §8 / §9 / §10 / §11 |
| §2.5（CP0 寄存器位）        | §2.5 配置空间                            |
| §3.3（测试用例数）          | §6 测试用例计划                          |
| §10（covergroup 落点）      | §7 覆盖率计划（目标值）                  |
| §11.2（测试目录）           | §6.3 Test Case 详表                      |
| §13 Phase 9（测试用例填充） | §6.3 Test Case 详表                      |
| §13 Phase 10（回归脚本）    | §8 回归策略 + §9 签核标准               |

---

## 附录 C：与 hpdcache_verification 文件复用对位

| MMU UVM 文件                                  | hpdcache_verification 参考                                                                                                                                    |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Makefile](../mmu_verification/Makefile)（待建） | [hpdcache_verification/Makefile](../hpdcache_verification/Makefile)                                                                                              |
| `testbench/Files.f`                         | [hpdcache_verification/testbench/Files.f](../hpdcache_verification/testbench/Files.f)                                                                            |
| `testbench/common/mmu_common_pkg.sv`        | [hpdcache_common_pkg.sv](../hpdcache_verification/testbench/common/hpdcache_common_pkg.sv)                                                                       |
| `ifu_agent/*` / `lsu_agent/*`             | [hpdcache_agent/*](../hpdcache_verification/testbench/hpdcache_agent/)                                                                                           |
| `cp0_agent/*`                               | [conf_and_perf_agent/*](../hpdcache_verification/testbench/conf_and_perf_agent/)                                                                                 |
| `ptw_mem_agent/*`                           | [dram_mon/*](../hpdcache_verification/testbench/dram_mon/) + dv_utils `memory_response_model`                                                                  |
| `env/mmu_env.svh`                           | [env/hpdcache_env.svh](../hpdcache_verification/testbench/env/hpdcache_env.svh)                                                                                  |
| `env/mmu_translation_sb.svh`                | [env/hpdcache_sb.svh](../hpdcache_verification/testbench/env/hpdcache_sb.svh)                                                                                    |
| `env/mmu_top_cfg.svh`                       | [env/hpdcache_top_cfg.svh](../hpdcache_verification/testbench/env/hpdcache_top_cfg.svh)                                                                          |
| `top/tb_top.sv`                             | [top/top_axi2mem.sv](../hpdcache_verification/testbench/top/top_axi2mem.sv)                                                                                      |
| `top/mmu_arb_sva.sv`                        | [top/hpdcache_fxarb_sva.sv](../hpdcache_verification/testbench/top/hpdcache_fxarb_sva.sv)                                                                        |
| `top/mmu_plru_sva.sv`                       | [top/hpdcache_plru_sva.sv](../hpdcache_verification/testbench/top/hpdcache_plru_sva.sv)                                                                          |
| `top/credit_sva.sv`                         | [top/hpdcache_sva.sv](../hpdcache_verification/testbench/top/hpdcache_sva.sv)                                                                                    |
| `test/test_base.svh`                        | [test/test_base.svh](../hpdcache_verification/testbench/test/test_base.svh)                                                                                      |
| `test/test_pkg.sv`                          | [test/test_pkg.sv](../hpdcache_verification/testbench/test/test_pkg.sv) + [test/hpdcache_test_pkg.sv](../hpdcache_verification/testbench/test/hpdcache_test_pkg.sv) |
| `scripts/*`                                 | [hpdcache_verification/scripts/](../hpdcache_verification/scripts/)                                                                                              |
| `modules/dv_utils/*`                        | [hpdcache_verification/modules/dv_utils/](../hpdcache_verification/modules/dv_utils/)                                                                            |

---

---

## 附录 D：v3.0 Final ↔ MMU_VerificationPlan_v3.md 交叉引用索引

> 本附录汇总本次 v3.0 Final 改动与 [MMU_VerificationPlan_v3.md](../lc_test_plan_doc/MMU_VerificationPlan_v3.md) 及 plan_v1/v2/v3 改动清单的逐项对位，便于走查。

### D.1 接口表补齐（§2.4 + §6）

| 来源                                                                                   | UVM BuildPlan v3 Final 锚点                      |
| -------------------------------------------------------------------------------------- | ------------------------------------------------ |
| plan_v2 §D 第 13 组 `mmu_xx_mmu_en` / `mmu_lsu_mmu_en` / `mmu_cp0_tlb_done`     | §2.4 新增行 + §6.3 `cp0_if` 已含（勘误确认） |
| plan_v2 §D 第 14 组 CSR 细分 `cskyee/reg_num/mpp/wdata/wreg`                        | §2.4 新增行 + §6.3 `cp0_if`（已完整含有）    |
| plan_v2 勘误：`regs_ptw_cur_asid` 16-bit                                             | §2.4 勘误段                                     |
| plan_v2 勘误：顶层无 `pmp_mmu_fetch*` 输入（仅 MMU→PMP `mmu_pmp_fetch{3,5,6,7}`） | §2.4 勘误段 + §6.5                             |
| plan_v1 勘误：ITLB 16 entry / MB FSM 7 状态含 WFG / SFENCE INVVA single-pass           | §2.4 勘误段 + §10.2 cg 注记                    |
| plan_v3 §B.4 PTW→LSU 串行单 outstanding 协议说明                                     | §2.4 LSU 协议补齐段（专有大段）                 |

### D.2 新 SVA 与 covergroup

| plan_v3 §E 条目                                                                                                                                                                                           | UVM BuildPlan v3 Final 位置                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `sva_twu_2m_cross_data`（F4.NEW.4 P0）                                                                                                                                                                   | §9.2 `mmu_twu_sva.sv` 新建 + §9.2.1 伪代码                       |
| `sva_csr_grant_onehot`（F4.NEW.5）                                                                                                                                                                       | §9.2 `mmu_twu_sva.sv` + §9.2.1                                   |
| `sva_ptw_write_pipe_reset_safe`（F5.NEW.2）                                                                                                                                                              | §9.2 `mmu_arb_sva.sv` 追加行 + §9.2.1                            |
| `sva_lsu_req_stable_until_vld` / `sva_lsu_addr_stable_until_vld` / `sva_single_outstanding` / `sva_response_inorder` / `sva_vld_only_when_req` / `sva_mbuf_ptr_only_on_response`（F4.42a/b/c） | §9.2 `mmu_ptw_lsu_protocol_sva.sv` 新建 + §9.2.1 伪代码          |
| `sva_raw_vld_and_gate`（F3.4 TC-BUG-005）                                                                                                                                                                | §9.2 `mmu_l2tlb_rrpv_sva.sv` 追加行                               |
| `sva_l2_is_dtlb_match`（F3.5 TC-BUG-006）                                                                                                                                                                | §9.2 同上                                                           |
| `sva_rrpv_inv_state`（F3.NEW.1 TC-BUG-007）                                                                                                                                                              | §9.2 同上                                                           |
| `sva_pplru_entry0_first_hit`（F12.NEW.1 TC-BUG-008）                                                                                                                                                     | §9.2 `mmu_plru_sva.sv` 追加行                                     |
| `sva_thd_a_bit_pgflt` / `sva_pde_nonleaf_upd`（v2 证伪后保留为正向保护）                                                                                                                               | §9.2 `mmu_twu_sva.sv` 正向保护段                                  |
| `cg_twu_2m_csr_cross` / `cg_xbar_cold_start` / `cg_l2_store_dtlb_tag` / `cg_lsu_req_outstanding` / `cg_mbuf_ptr_hold`                                                                            | §10.3 新增 5 行；另追加 `cg_mb_fsm_wfg` / `cg_sfence_invva_pgs` |

### D.3 Test / Agent 落地

| 来源                                                                                                                                                       | UVM BuildPlan v3 Final 位置                                                                    |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| plan_v3 §B.4 PTW→LSU 协议补强、§C 真实缺陷升 P0、§A 错判降级                                                                                           | §11.2.1 `bug_hunt_tests/` 15 行文件清单 + §11.2.2 `ptw_lsu_protocol_tests/` 5 行文件清单 |
| plan_v3 Agent 扩写（`ptw_mem_agent` 单 outstanding checker / inorder seq / 反向错误注入；`cp0_agent` CSR 细分字段；`misc_agent` en 广播 + tlb_done） | §11.2.3 Agent 扩写要点                                                                        |

### D.4 风险 / 回归 / 签核

| plan_v3 §G 条目                              | UVM BuildPlan v3 Final 位置                             |
| --------------------------------------------- | ------------------------------------------------------- |
| R15 收敛、R16 下调、R19 新增 P0、R20 新增中等 | §13 Phase 11 JIRA 联动段                               |
| 75 条 BUG/GAP TC，P0/P1/P2 = 37/37/7          | 对齐 `MMU_Traceability_Matrix.csv` 新行 Priority 分布 |
| Phase 11 回归列表与签核增量                   | §13 Phase 11 完整段                                    |

---

**文档结束。** 工程师可从 **Phase 1：环境骨架** 开始，按 [§13 实施落地阶段](#第-13-章实施落地阶段10-个-phase) 逐 Phase 落地；v3.0 Gap-driven 回归由 **Phase 11** 统一纳管。

---

## 第 9 章 v5 ~ v7.2 增量补丁（PMP Agent 升级 / v7 新 SVA / PDE Cache 重构 / xbar 两级分发）

> **本章目的**：记录自 v4.0 之后，验证计划 `MMU_VerificationPlan_v3.md` 继续滚动到 **v7.2** 期间的增量搭建改动。**v5.0 ~ v7.2 共计 5 轮增量**，全部落地在本章；前面章节保持 v4.0 原貌不动。

### 9.1 版本历史（增量）

| 版本 | 日期       | 作者              | 变更说明                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---- | ---------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| v5.0 | 2026-04-22 | Verification Team | plan_v5：吸收 F4.NEW.6/7/8/9/10/11 PTW↔L2TLB↔arb 接口规格（`ptw_l2tlb_ready` 反压、`twu_idle` vs `twu_xbar_mask` 语义区分、`xbar_twu_hit_level`、异常直通、`twu_data_ready` 数据分发、mmu_arb 三通道仲裁）；新增 SVA `mmu_ptw_lsu_protocol_sva.sv` 完善协议断言；新增测试子目录 `ptw_twu_arch_tests/` 扩充 P0 case。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| v6.0 | 2026-04-22 | Verification Team | plan_v6：吸收 MAEE/SysMap/PMP PTW 精化——F4.NEW.12 双路属性选路、F4.NEW.13 PMP 三级序列化、F4.NEW.14 pmp_grant one-hot、F6.NEW.1-7 sysmap 7 点、F7.NEW.3-9 PMP 7 点；新增 SVA 文件 `mmu_maee_twu_sva.sv` / `mmu_pmp_twu_sva.sv` / `mmu_sysmap_sva.sv`；修正 pmp_if.sv 的 `mmu_pmp_fecth7` RTL typo。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| v7.0 | 2026-04-23 | Verification Team | `lsu_mmu_bus_error` 并发协议（bus_error 与 data_vld **同拍非互斥**），`mbuf_get !bus_error` 门控，`write_back_req/bus_err_write_back_req` 双路径，PDE Cache 更新时序重构（`pde_updata_data_vld/data_flop/vpn/lvl` 四寄存器，次周期驱动 `mbuf_cache_upd`，`pde_updata_lvl[0]=1` 排除 THD/4K 叶级更新）。新增 SVA：`sva_bus_err_with_data_vld` / `sva_mbuf_get_not_set_on_bus_err` / `sva_mbuf_get_bus_err_mutex` / `sva_pde_cache_one_cycle_delay` / `sva_pde_cache_no_leaf_entry`；新增 CG：`cg_mbuf_bus_err_concurrent` / `cg_pde_cache_timing`；新增 TC：TC-MBUF-BUS-ERR-CONCURRENT-001 / TC-MBUF-GET-NO-BUS-ERR-001 / TC-PDE-CACHE-TIMING-001 / TC-PDE-CACHE-LVL-001；新增测试子目录 `bus_err_concurrent_tests/`。                                                                                                                                                                                                                                                                                                                            |
| v7.1 | 2026-04-23 | Verification Team | PTW RTL 核对补丁：F4.23 归属纠错（`mmu_lsu_tlb_wakeup[11:0]` 源头 = **L1DTLB**，非 PTW）；F4.51 重写——`one_to_four_xbar` 为**两级分发**（Stage-1 优先编码器 `twu_idle` → Stage-2 `twu_req_point_r` fallback）；F4.52 补全 `mbuf_twu_have[3:0]` per-TWU 位向量语义；新增 F4.NEW.15/16/17（xbar 两级分发 P0 / mbuf_twu_have 生成 P1 / twu_busy 含 mbuf_twu_have P1）。新增 SVA：`sva_xbar_idle_first_priority` / `sva_xbar_pointer_only_when_no_idle` / `sva_mbuf_twu_have_from_vld_entries` / `sva_twu_busy_includes_mbuf_have`；新增 CG：`cg_xbar_dispatch_mode` / `cg_mbuf_twu_have_patterns`；新增 SVA 文件 `mmu_xbar_sva.sv`。                                                                                                                                                                                                                                                                                                                                                                                                           |
| v7.3 | 2026-04-23 | Verification Team | **信号归属修订**（对齐 `MMU_VerificationPlan_v3.md` v7.3，RTL 精读 `mmu_l1dtlb.sv` / `mmu_l1dtlb_install.sv` / `ct_mmu_regs.v`）：`mmu_lsu_tlb_busy` / `mmu_lsu_tlb_wakeup[11:0]` / `mmu_lsu_mmu_en` 三信号从 `ptw_mem_agent` / `ptw_mem_if` 搬到 `lsu_agent` / `lsu_if`（L1DTLB → LSU 广播子分组 `tlb_status`）；`busy` 定义为任意 L1DTLB MB 在途（`|mb_entry_vld`），`wakeup` 定义为完成事件广播解挂（完成事件触发 `12'hfff`）。RTL 证据：`mmu_l1dtlb.sv#L1252` + `mmu_l1dtlb_install.sv#L220-L262` + `ct_mmu_regs.v#L645`。                                                                                                                                                                                                                                                                                                                                                                                                 |
| v7.2 | 2026-04-23 | Verification Team | **PMP Agent 验证计划完善**（对照 `pmp/rtl/ct_pmp_*.v` 精读）：§2.3 Row 8 修订（`pmp_mmu_flg[3:0]={L,X,W,R}`，bit[3]=L）、F7.2 纠错（Reserved→L 锁定）；新增 F7.NEW.10..F7.NEW.22 共 **13 条**特性；新增 **19 条** PMP TC（TOR/NAPOT/NA4/优先级/默认权限/L-lock/MPRV/pmpcfg2/5-vs-8 端口）；**10 条** SVA（`sva_pmp_flg_bit_layout` / `sva_pmp_priority_lowest_wins` / `sva_pmp_tor_chain` / `sva_pmp_napot_mask_shape` / `sva_pmp_na4_never_hits` / `sva_pmp_l_bit_lock_no_update` / `sva_pmp_m_mode_no_match_allow` / `sva_pmp_u_mode_no_match_deny` / `sva_pmp_mprv_port2_zero` / `sva_pmp_mprv_port3_fetch_mask`）；**7 条** CG（`cg_pmp_addr_mode_per_entry` / `cg_pmp_napot_size` / `cg_pmp_priority_hit_index` / `cg_pmp_priv_perm_matrix` / `cg_pmp_lock_sequence` / `cg_pmp_mprv_scenarios` / `cg_pmp_port_concurrency`）；**4 条**新风险 R-NEW.PMP.1..4；新增 SVA 文件 `mmu_pmp_sva.sv`；新增测试子目录 `pmp_v7_tests/`；pmp_agent 类型由 **Responder 升级为 Responder + Active**。 |

### 9.2 pmp_agent 架构升级（v7.2：Responder + Active with Reference Model）

> **定位变化**：v4.0 版本 `pmp_agent` 仅作为 **Responder**（被动按 PA 返回 `pmp_mmu_flg`）。v7.2 升级为 **Responder + Active 混合模式**，新增 CSR 激励、Reference Model、7 类 CG，用于覆盖 F7.NEW.10..F7.NEW.22 全部特性点。

#### 9.2.1 pmp_driver（新增，Active 能力）

**文件**：`testbench/pmp_agent/pmp_driver.sv`

**职责**：

- 通过 CP0 接口驱动 `pmpcfg0/1` 与 `pmpaddr0..7` CSR 写序列（8 entry，`pmpcfg2` 硬连线 0 故无写）。
- 编程 4 种 Addr-Match 模式：**OFF / TOR / NA4 / NAPOT**（NA4/pmpcfg2 需配合"实现缺失 → 按规格写但观测无命中"回归）。
- 驱动 L-bit 锁定序列（`pmp{i}cfg.L=1 → 后续写吞`，以及 TOR 依赖锁：`pmp{i+1}.L && A==TOR → pmp{i}addr` 写也吞）。
- 支持 M/U/S priv 模式切换激励（通过 cp0_agent 协作）、MPRV 激励（port 2 免疫 / port 3 fetch 屏蔽差异化验证）。

#### 9.2.2 pmp_responder + pmp_monitor（保留 v4.0，小幅扩展）

**文件**：`testbench/pmp_agent/pmp_responder.sv`、`testbench/pmp_agent/pmp_monitor.sv`

**职责（相对 v4.0）**：

- Responder 继续按物理地址返回 `pmp_mmu_flg{0..7}[3:0]`（**v7.2 确认位序 {L,X,W,R}**）。
- Monitor 扩充采样：`mmu_pmp_pa{0..7}`、`mmu_pmp_fetch{0,1,3,5,6,7}`（注意 fetch4 已注释 / fecth7 为 RTL typo）、`pmpcfg0/1/2` 回读（pmpcfg2 应恒 0）。
- 5 端口 vs 8 端口实测：对 `ct_pmp_acc0..4`（5 端口）独立监控；`port5..7` 按 **waiver** 记录（R-NEW.PMP.1）。

#### 9.2.3 pmp_ref_model（新增，v7.2）

**文件**：`testbench/pmp_agent/pmp_ref_model.sv`

**职责**：

- 维护 shadow 寄存器：`pmp_cfg[8]` / `pmp_addr[8]`，`pmpcfg2` 镜像恒 0。
- 复现 4 种 Addr-Match：OFF（恒不命中）、TOR（`bottom[i]=pmpaddr[i-1]`，`bottom[0]=29'b1`，hit = `addr ≥ bottom && addr < upaddr`）、NA4（**恒不命中 / RTL Gap**）、NAPOT（casez 匹配 4KB..1TB 共 29 档）。
- 优先级选择：多 entry 同时 hit 时取 **lowest index**（对标 `ct_pmp_acc.v#L170-L192`）。
- 默认权限：M-mode 无命中 → `4'b0111`（L=0, X=W=R=1）；非 M-mode 无命中 → `4'b0000`。
- L-bit 锁定：`pmp{i}cfg.L=1` 吞写；TOR 依赖锁；**复位清 L（RTL Gap，与 Priv spec sticky 偏离）**。
- MPRV 差异化：port 2 `mprv=0`；port 3 `mprv=mprv & !fetch3`；其余 port `mprv` 透传。

#### 9.2.4 pmp_sequences（新增 19 类 seq，v7.2）

**文件**：`testbench/pmp_agent/pmp_sequences/*.sv`

| Sequence 名                  | 对应 TC                          | 关键行为                                             |
| ---------------------------- | -------------------------------- | ---------------------------------------------------- |
| `pmp_tor_chain_seq`        | TC-PMP-TOR-CHAIN-001             | 编程 2/3/多 TOR 区间 + 正常区间命中                  |
| `pmp_tor_zero_len_seq`     | TC-PMP-TOR-ZERO-LEN-001          | 零宽 / 逆序 TOR 退化                                 |
| `pmp_tor_lock_seq`         | TC-PMP-TOR-LOCK-DEP-001          | L-lock + TOR 依赖锁（锁 pmp{i+1} 后再写 pmp{i}addr） |
| `pmp_napot_size_sweep_seq` | TC-PMP-NAPOT-ALL-SIZES-001       | 4KB..1TB 29 档全覆盖                                 |
| `pmp_napot_illegal_seq`    | TC-PMP-NAPOT-ILLEGAL-001         | 非法 pattern → mask=0                               |
| `pmp_na4_seq`              | TC-PMP-NA4-UNSUPPORTED-001       | NA4 配置恒不命中（RTL Gap 登记）                     |
| `pmp_multi_hit_seq`        | TC-PMP-PRIORITY-LOWEST-IDX-001   | 多 entry 同 hit → winner=min idx                    |
| `pmp_default_m_seq`        | TC-PMP-DEFAULT-M-ALLOW-001       | M-mode 无命中 allow                                  |
| `pmp_default_u_seq`        | TC-PMP-DEFAULT-U-DENY-001        | U/S-mode 无命中 deny                                 |
| `pmp_flg_order_seq`        | TC-PMP-FLG-LXWR-ORDER-001        | 位序 {L,X,W,R} Ref Model 一致性                      |
| `pmp_lock_seq`             | TC-PMP-L-BIT-LOCK-001            | L=1 吞 cfg/addr 写                                   |
| `pmp_reset_seq`            | TC-PMP-L-BIT-RESET-CLR-001       | 复位后 L=0 验证                                      |
| `pmp_mprv_port2_seq`       | TC-PMP-MPRV-PORT2-IMMUNE-001     | port 2 对 MPRV 免疫                                  |
| `pmp_mprv_port3_seq`       | TC-PMP-MPRV-PORT3-FETCH-MASK-001 | port 3 fetch 时屏蔽 MPRV                             |
| `pmp_pmpcfg2_seq`          | TC-PMP-PMPCFG2-ZERO-001          | pmpcfg2 硬连线 0 读写验证                            |
| `pmp_5port_concurrent_seq` | TC-PMP-5PORT-REGRESS-001         | 5 端口 ct_pmp_acc0..4 并发实测                       |
| `pmp_8port_spec_seq`       | TC-PMP-8PORT-SPEC-001            | 8 端口规格回归（port5..7 waiver）                    |
| `pmp_csr_warl_seq`         | —（辅助）                       | pmpcfg WARL bits[6:5]=0 回读                         |
| `pmp_comprehensive_seq`    | —（主 vseq 调度）               | 上述 seq 组合大回归                                  |

#### 9.2.5 pmp_covergroups（新增 7 CG，v7.2）

**文件**：`testbench/pmp_agent/pmp_covergroups.sv`

| Covergroup                     | 覆盖维度                                               |
| ------------------------------ | ------------------------------------------------------ |
| `cg_pmp_addr_mode_per_entry` | 每 entry × {OFF/TOR/NA4/NAPOT} 4 模式交叉             |
| `cg_pmp_napot_size`          | NAPOT 29 档尺寸（4KB..1TB）+ 非法 pattern              |
| `cg_pmp_priority_hit_index`  | winner index ∈ {0..7}（多 hit 时）                    |
| `cg_pmp_priv_perm_matrix`    | priv {M/S/U} × access {R/W/X} × outcome {allow/deny} |
| `cg_pmp_lock_sequence`       | L-bit 锁定状态 × TOR 依赖锁 × 复位清                 |
| `cg_pmp_mprv_scenarios`      | MPRV × port{0..7} × fetch={0,1}                      |
| `cg_pmp_port_concurrency`    | 同拍并发端口数 {1..5}（实测）+ {1..8}（规格）          |

### 9.3 新增测试子目录（v5 ~ v7.2 累计）

```
testbench/test/
├── maee_twu_tests/          # v6：F4.NEW.12 / F6.NEW.1..F6.NEW.4 MAEE×sysmap
├── pmp_twu_tests_v6/        # v6：F4.NEW.13/14 + F7.NEW.3..F7.NEW.9
├── bus_err_concurrent_tests/ # v7.0：F4.22 / F4.35 / F4.42a / F4.NEW.1 bus_error
├── sysmap_degrade_tests/    # v6：F6.NEW.3/4 跨界降级
├── pmp_v7_tests/            # v7.2：F7.NEW.10..F7.NEW.22（19 TC）
└── ptw_twu_arch_tests/      # v5/v7.1：F4.NEW.6/7/15/16/17 xbar + mbuf_twu_have
```

### 9.4 新增 SVA 文件（v5 ~ v7.2 累计 8 个）

| SVA 文件                        | 属于版本 | 涵盖 SVA（按声明顺序）                                                                                                                                                                                                                                                                                                                      |
| ------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mmu_ptw_lsu_protocol_sva.sv` | v5.0     | `sva_lsu_req_stable_until_vld` / `sva_single_outstanding` / `sva_response_inorder` / `sva_vld_only_when_req` / `sva_mbuf_ptr_only_on_response`                                                                                                                                                                                    |
| `mmu_twu_sva.sv`              | v4/v5    | `sva_twu_mask_semantics` / `sva_twu_pipeline_no_stall_when_unmasked` / `sva_twu_multi_inflight_legal` / `sva_twu_ready_equiv`                                                                                                                                                                                                       |
| `mmu_mbuf_invariant_sva.sv`   | v4       | `sva_ptw_mbuf_no_overflow` / `sva_no_backpressure_to_twu_from_mbuf_full` / `sva_busy_from_any_dtlb_mb_entry`                                                                                                                                                                                                                               |
| `mmu_maee_twu_sva.sv`         | v6.0     | `sva_twu_maee_mutex` / `sva_maee0_csr_req` / `sva_maee1_skip_csr`                                                                                                                                                                                                                                                                     |
| `mmu_pmp_twu_sva.sv`          | v6.0     | `sva_no_lsu_req_during_pmp_wait` / `sva_pmp_grant_onehot` / `sva_pmp_deny_acc_fault` / `sva_pmp_deny_no_lsu_req` / `sva_ptw_pmp_fetch_zero` / `sva_pmp_wait_implies_mask`                                                                                                                                                       |
| `mmu_sysmap_sva.sv`           | v6.0     | `sva_sysmap_cross_degrade` / `sva_csr_refill_flg_matches_sysmap` / `sva_sysmap_pa_align`                                                                                                                                                                                                                                              |
| `mmu_xbar_sva.sv`             | v7.1     | `sva_xbar_idle_first_priority` / `sva_xbar_pointer_only_when_no_idle` / `sva_mbuf_twu_have_from_vld_entries` / `sva_twu_busy_includes_mbuf_have` + v7.0：`sva_bus_err_with_data_vld` / `sva_mbuf_get_not_set_on_bus_err` / `sva_mbuf_get_bus_err_mutex` / `sva_pde_cache_one_cycle_delay` / `sva_pde_cache_no_leaf_entry` |
| `mmu_pmp_sva.sv`              | v7.2     | `sva_pmp_flg_bit_layout` / `sva_pmp_priority_lowest_wins` / `sva_pmp_tor_chain` / `sva_pmp_napot_mask_shape` / `sva_pmp_na4_never_hits` / `sva_pmp_l_bit_lock_no_update` / `sva_pmp_m_mode_no_match_allow` / `sva_pmp_u_mode_no_match_deny` / `sva_pmp_mprv_port2_zero` / `sva_pmp_mprv_port3_fetch_mask`               |

### 9.5 新增 Virtual Sequence（v7 系列）

- `mmu_pmp_comprehensive_vseq`（v7.2 主回归）：依次调度 9.2.4 的 19 类 seq，覆盖 F7.NEW.10..22。
- `mmu_bus_err_concurrent_vseq`（v7.0）：ptw_mem_agent 注入 `bus_error & data_vld` 同拍 + 观察 mbuf_get 门控。
- `mmu_sysmap_degrade_vseq`（v6.0）：大页跨界 + 触发降级。
- `mmu_maee_vseq`（v6.0）：MAEE 0/1 切换 + 双路属性选路。
- `mmu_pde_cache_vseq`（v7.0）：PDE Cache 时序重构（4 寄存器次周期驱动 + 叶级排除）。

### 9.6 Env 更新（`mmu_env.svh`）

- 新增组件句柄：`pmp_ref_model m_pmp_ref_model`（v7.2）。
- 新增 Virtual Interface：`pmp_cfg_if m_pmp_cfg_vif`（driver ↔ CP0 CSR 激励路径）。
- `mmu_top_cfg` 新增配置位：`pmp_agent_active=1`（v7.2 默认 Active）、`pmp_5port_mode=1`（默认仅校验 5 端口，避开 R-NEW.PMP.1 port5..7 端口悬空）。

### 9.7 风险登记（v7.2 新增 4 条）

| ID          | 级别 | 描述                                                                                                  | 闭环建议                                                                                          |
| ----------- | ---- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| R-NEW.PMP.1 | 高   | `ct_pmp_top.v` 仅实例化 5 个 `ct_pmp_acc`（`x_ct_pmp_acc0..4`），规格目标 8 端口，port5..7 悬空 | 与设计方对齐 ECO 或 waiver；TC-PMP-5PORT-REGRESS-001 作为主线，TC-PMP-8PORT-SPEC-001 做 spec 回归 |
| R-NEW.PMP.2 | 中   | NA4 模式未实现（`mmu_na4_addr_match=1'b0`）                                                         | 登记为已知行为；建议 ECO 或用 NAPOT(4KB) 替代                                                     |
| R-NEW.PMP.3 | 中   | L-bit 复位清 0，偏离 RISC-V Priv spec sticky 语义                                                     | 登记 spec 偏差；建议改为 power-on reset only 或 sticky FF                                         |
| R-NEW.PMP.4 | 低   | `pmpcfg2` 硬连线 0，pmp8-15 不实现（RISC-V 允许 0/16/64 entry）                                     | 文档注明 8 entry 实现；测试侧不访问 pmp8-15 区段                                                  |

---
