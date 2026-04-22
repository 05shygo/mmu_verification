# MMU UVM 验证环境框架说明

> **参考图片**：`hpdcache_verification/Images/dcache_uvm.io.drawio.drawio.png`（整体结构）、  
> `dcache_sb.io.drawio.png`（Scoreboard 内部数据流）  
> **框图文件**：[doc/image/MMU_UVM_Env_Diagram.drawio](image/MMU_UVM_Env_Diagram.drawio)  
> **详细骨架**：[MMU_UVM_BuildPlan_v3_final.md](MMU_UVM_BuildPlan_v3_final.md)

---

## 1. 总览

MMU 验证环境完全对标 hpdcache 的 UVM 框架（见参考图），采用"同心矩形"布局：最外层是 Test 测试层，第二层是 tb_top 仿真顶层，内层是 mmu_env 环境容器，正中心是 DUT（`ct_mmu_top.v`）。所有 Agent 通过各自的 Virtual Interface（vif）与 DUT 双向连接；所有激励由 Virtual Sequencer 统一调度；所有检查收束到底部的 Scoreboard / Reference Model 层。

```
╔══════════════════════════════════════════════════════════════════════════╗
║  Test Layer  (test_base / 14 类 test 子目录)                             ║
║  ┌──────────────────────────────────────────────────────────────────┐    ║
║  │  tb_top.sv                                                       │    ║
║  │  ┌──────────────────────────────────────────────────────────┐    │    ║
║  │  │  mmu_env                                                 │    │    ║
║  │  │                                                          │    │    ║
║  │  │  ┌─Active Agents(左)─┐   ┌─────DUT─────┐  ┌─Resp(右)─┐ │    │    ║
║  │  │  │ ifu_agent         │◄─►│             │◄►│ptw_mem   │ │    │    ║
║  │  │  │ lsu_agent(×5drv)  │◄─►│ct_mmu_top.v │◄►│pmp_agent │ │    │    ║
║  │  │  │ cp0_agent         │◄─►│   (Sv39)    │  └──────────┘ │    │    ║
║  │  │  │ sysmap_cfg_agent  │   │             │   mmu_top_cfg │    │    ║
║  │  │  │ misc_agent        │   │   SVA bind  │   virt_seqr   │    │    ║
║  │  │  └───────────────────┘   └─────────────┘               │    │    ║
║  │  │                                                          │    │    ║
║  │  │  ┌──────SB / RefModel 带(底部)──────────────────────┐   │    │    ║
║  │  │  │ PT_mem │ ref_model │ trans_sb │ inv_sb │ credit_sb│   │    │    ║
║  │  │  └─────────────────────────────────────────────────-─┘   │    │    ║
║  │  └──────────────────────────────────────────────────────────┘    │    ║
║  └──────────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## 2. 各区域详细说明

### 2.1 Test 层（图中最顶部横幅）

**位置**：整个框图的最上方，横跨全幅，浅紫色背景。

| 组件 | 文件路径 | 职责 |
|---|---|---|
| `test_base` | `testbench/test/test_base.svh` | 基类：build virtual seqr、注册 config、设置 timeout |
| 14 类子目录 | `basic/ l1itlb/ l1dtlb/ l2tlb/ ptw/ tlbop/ pmp/ sysmap/ cp0/ flush/ cross/ perf/ err/` 等 | 每类对应验证计划中一组功能特性 |
| `test_pkg.sv` | `testbench/test/test_pkg.sv` | `include` 所有 test 类，统一编译入口 |

**数据流**：Test 实例化后调用 `start()` 将 Virtual Sequence 压入 `mmu_virtual_sequencer`，由后者向下分发到各 Agent sequencer。

---

### 2.2 tb_top（仿真顶层，图中第二层外框）

**位置**：紧包在 Test 层之内，是 SV 模块顶层（非 UVM class）。

| 子组件 | 来源 | 职责 |
|---|---|---|
| `clock_driver_c` | dv_utils `clock_gen/` | 生成 `forever_cpuclk`（对标 hpdcache 的 Clock Driver） |
| `reset_driver_c` | dv_utils `reset_gen/` | 生成 `cpurst_b`，支持中途 reset 注入 |
| `uvm_config_db` set | tb_top.sv | 将 7 个 vif 句柄注入 UVM 配置数据库 |
| DUT 实例 `u_dut` | `ct_mmu_top.v` | 被验证 RTL |
| 7 个 interface 实例 | `ifu_if / lsu_if / cp0_if / ptw_mem_if / pmp_if / sysmap_cfg_if / misc_if` | 信号总线，连接 TB 与 DUT |

> **对应参考图**：参考图左下角的 Reset Driver → vif、Clock Driver → vif，以及中央 DUT 矩形，在 MMU 环境里完全平行复用。

---

### 2.3 mmu_env（环境容器，图中第三层虚线框）

**位置**：tb_top 内部，蓝色虚线外框，包含所有 UVM component 实例。  
**关键文件**：`testbench/env/mmu_env.svh`，通过 `mmu_env_pkg.sv` 统一编译。

#### 2.3.1 mmu_top_cfg

**位置**：env 右侧，紫色小块（对标参考图的 "Top Configuration"）。  
职责：存放环境级开关配置——各 Agent 的 `is_active` 标志、SVA enable 开关、覆盖率采集开关。  
通过 `uvm_config_db::set/get` 传递给所有 Agent 和 SB。

#### 2.3.2 watchdog

**位置**：env 内部顶部（对标参考图的 "Watch Dog"）。  
来源：dv_utils `watchdog/`。  
职责：仿真超时保护，超时后发 fatal 并 dump 波形。

#### 2.3.3 mmu_virtual_sequencer

**位置**：env 右侧中部，紫色块。  
职责：持有所有 7 个 Agent 的 sequencer 句柄（`p_ifu_seqr`、`p_lsu_seqr` 等），Virtual Sequence 通过它统一调度多 Agent 激励。

#### 2.3.4 mmu_vseq_lib（14 个 vseq 类）

内嵌在 virtual sequencer 中，典型类包括：
`mmu_smoke_vseq`、`mmu_l2tlb_stress_vseq`、`mmu_sfence_cross_vseq`、`mmu_ptw_deep_walk_vseq` 等。

---

### 2.4 左侧：Active Agents（激励驱动端）

位于框图左侧纵列，共 5 个 Active Agent（浅蓝色），对标参考图左侧的 "HPDcache Request Agent" 与 "HWPF Stride Agent"。

#### 2.4.1 ifu_agent（最左上）

| 子组件 | 职责 |
|---|---|
| sequencer / driver | 驱动 `ifu_if`：`ifu_mmu_va_vld`、`ifu_mmu_va[62:0]`、`ifu_mmu_abort` |
| monitor | 采样请求（`va_vld`）和响应（`mmu_ifu_pavld`、`pa`、`pgflt`、`deny`） |
| `ifu_covergroups` | `cg_ifu_req`（VA 段分布）、`cg_ifu_rsp`（pgflt × deny × sec 交叉覆盖） |
| analysis_port | `ap_req` → 送往 `mmu_translation_sb` |

**数据流**：
```
Test → vseq → ifu_sequencer → ifu_driver ──(ifu_if)──► DUT[L1 ITLB]
                                                         │
              ifu_monitor ◄──────────────────────────────┘
                   │
              ap_rsp ──────────────────────────────────────► mmu_translation_sb
```

#### 2.4.2 lsu_agent（左侧第二块，最大）

包含 5 个子线程 driver（**Pipe0 / Pipe1 / Pipe2 / STAMO / TLB-INV**），对标 DUT 的 LSU 多通道接口。

| 子通道 | 驱动信号 | 采样信号 |
|---|---|---|
| Pipe0 | `lsu_mmu_va0_vld`、`va0[63:0]`、`id0[6:0]`、`st_inst0`、`abort0` | `mmu_lsu_pa0_vld`、`pa0`、`page_fault0`、`stall0` |
| Pipe1 | 同 Pipe0，后缀 `1` | 同上，后缀 `1` |
| Pipe2 (Prefetch) | `lsu_mmu_va2_vld`、`va2[27:0]` | `mmu_lsu_pa2_vld`、`pa2`、`pa2_err` |
| STAMO | `lsu_mmu_stamo_vld`、`stamo_pa[27:0]` | （仅观测 DUT 内部 TLB 状态） |
| TLB-INV (SFENCE) | `tlb_va_all_inv`、`tlb_all_inv`、`tlb_va_asid_inv`、`inv_va`、`inv_asid` | `mmu_lsu_tlb_inv_done` |

```
vseq → lsu_sequencer ──(lsu_txn: kind)──►  lsu_driver ──fork──► drive_pipe0 ──(lsu_if)──► DUT
                                                              ├──► drive_pipe1
                                                              ├──► drive_pipe2
                                                              ├──► drive_stamo
                                                              └──► drive_inv

lsu_monitor.ap_pipe0/1  ──────────────────────────────────────────────────────► mmu_translation_sb
lsu_monitor.ap_inv      ──────────────────────────────────────────────────────► mmu_invalidate_sb
```

#### 2.4.3 cp0_agent（左侧第三块）

驱动 CSR 写入（`satp0/1`、权限模式、`mxr`/`sum`/`mprv`/`ptw_en` 等），采样 `mmu_cp0_cmplt`、`mmu_cp0_data`。

**数据流**：
```
vseq → cp0_sequencer → cp0_driver ──(cp0_if)──► DUT[ct_mmu_regs / tlboper]
                                                  │
cp0_monitor.ap ──────────────────────────────────►│──► mmu_ref_model（更新 CSR 镜像）
```

> CSR 镜像（satp、priv_mode、mxr、sum 等）是 Reference Model 推导翻译结果的基础。

#### 2.4.4 sysmap_cfg_agent（左侧第四块）

通过白盒 force/release 向 `ct_mmu_sysmap.v` 内部注入 8 个区域配置（base/mask/flg），仅在 build_phase / 复位后执行，对标参考图左下的 "Memory Rsp Configuration" 位置。

#### 2.4.5 misc_agent（左侧最底块，Passive+注入）

| 子分组 | 方向 | 信号 |
|---|---|---|
| RTU（注入） | TB→DUT | `rtu_yy_xx_flush`（单脉冲）、`rtu_mmu_bad_vpn`、`rtu_mmu_expt_vld` |
| HPCP（采样） | DUT→TB | `mmu_hpcp_dutlb_miss`、`iutlb_miss`、`jtlb_miss` |
| DFT/低功耗（注入） | TB→DUT | `pad_yy_icg_scan_en`、`biu_mmu_smp_disable` |
| Debug（采样） | DUT→TB | `mmu_had_debug_info[33:0]` |

```
misc_driver ──(misc_if)──► DUT（flush / expt 注入）
misc_monitor.ap_hpcp  ──────────────────────────────────────────────────────► mmu_perf_mon
misc_monitor.ap_debug ──────────────────────────────────────────────────────► （调试分析）
```

---

### 2.5 右侧：Responder Agents（响应/配置端）

位于框图右侧纵列，对标参考图右侧的 "Memory Agent"、"BP Driver" 和 "Memory Request Arbiter"。

#### 2.5.1 ptw_mem_agent（右侧最上，浅橙色）

DUT 内 PTW（Page Table Walker）发出内存读请求时，由此 Agent 响应。

| 子组件 | 职责 |
|---|---|
| `ptw_mem_responder` | 采样 `mmu_lsu_data_req`，查 `page_table_builder`，延迟 `rsp_delay` 个周期后驱动 `lsu_mmu_data_vld`+`lsu_mmu_data[63:0]`；支持 bus_error 注入 |
| `page_table_builder` | 基于 dv_utils `memory_shadow` 的 Sv39 页表工具类；提供 `map_4k/2M/1G`、`invalidate`、`inject_fault` API；与 `mmu_page_table_mem`（共享 shadow PT）双向同步 |
| `ptw_mem_monitor` | `ap_req` 采样 PTW 地址、`ap_rsp` 采样返回 PTE 数据，送往 `mmu_translation_sb` |

**数据流**：
```
DUT[PTW] ──(mmu_lsu_data_req + addr)──► ptw_mem_if ──► ptw_mem_responder
                                                         │ 查 page_table_builder
                                                         │ 等 rsp_delay 周期
                                         ◄──────────────┘
DUT[PTW] ◄──(lsu_mmu_data_vld + data[63:0])──────────── ptw_mem_if

ptw_mem_monitor.ap_req ────────────────────────────────────────────► mmu_translation_sb
ptw_mem_monitor.ap_rsp ────────────────────────────────────────────► mmu_credit_sb
```

#### 2.5.2 pmp_agent（右侧中部，浅橙色）

DUT 翻译完成后将 PA 广播到 8 个 PMP 端口（`mmu_pmp_pa{0..7}`），pmp_agent 响应 flag（`pmp_mmu_flg{0..7}[3:0]`）。

```
DUT ──(mmu_pmp_pa × 8)──► pmp_if ──► pmp_monitor.ap ──► mmu_translation_sb（PMP 拒绝校验）
TB  ──(pmp_mmu_flg × 8)──► pmp_if ──► DUT（PMP 结果输入）
```

---

### 2.6 中央：DUT（ct_mmu_top.v）

**位置**：框图正中央，浅红色大矩形。

内部关键子模块与验证关注点：

| 子模块 | 参数 | 验证关注点 |
|---|---|---|
| L1 ITLB | 16 entries 全相联，PLRU，credit_max=8 | Hit/Miss、huge page（2M）、credit 流控 |
| L1 DTLB | 16 entries，MB_DEPTH=8，dPLRU，双 pipe + STAMO + PFU | 三通道并发、MB 满、替换策略 |
| L2 TLB | Skew-Assoc 8 way × 256 set × 8 bank，3-bit RRPV（SRRIP） | 替换策略、ReqQ(9深)仲裁、MB(1i+8d) |
| PTW | 4 TWU + L1/L2 PDE cache + mbuf + 1→4 xbar + PPLRU | 3 级页表行走、OOO 响应、PTE 位检查 |
| TLBOper | 7 FSM（tlbiall/asid/va/p/r/wi/wr） | SFENCE 后残留条目、与 PTW 并发 |
| SysMap | 8 region，5-bit FLG | 命中优先级、白盒配置路径 |
| PMP | 8 端口 × 4-bit flag + fetch enable | 拒绝访问、fetch 门控 |

DUT 内部还 bind 了 5 个 SVA 模块（见 §2.7）。

---

### 2.7 SVA（SystemVerilog Assertions）

**位置**：紧贴 DUT 上方小红框，通过 `bind` 无侵入接入，对标参考图 DUT 内的两个 "bind SV ... assertions" 矩形。

| SVA 文件 | 检查内容 |
|---|---|
| `mmu_sva.sv` | 顶层端口 X-check、翻译完整性（发出 valid 必有 valid 响应） |
| `mmu_arb_sva.sv` | arb grant 一热、work-conserving（对标 hpdcache_fxarb_sva） |
| `mmu_l2tlb_rrpv_sva.sv` | SRRIP 行为：命中时 RRPV→0，First-Free 优先于 Max-RRPV |
| `mmu_plru_sva.sv` | L1 DTLB dPLRU 替换路数正确性（对标 hpdcache_plru_sva） |
| `credit_sva.sv` | L1↔L2 outstanding ≤ credit_max |

---

### 2.8 底部：Scoreboard / Reference Model 层

**位置**：框图底部横向排列 6 个块（浅色带），对标参考图上方的 "HPDcache Scoreboard" 横幅及 "Memory Shadow" 角块。

#### 2.8.1 mmu_page_table_mem（最左）

- 基于 dv_utils `memory_shadow` 的共享页表内存。  
- 由 `page_table_builder`（ptw_mem_agent 内）写入页表数据。  
- Reference Model 从中读 PTE，推导预期翻译结果。

#### 2.8.2 mmu_ref_model（左二）

核心 SW 参考模型，暴露 `translate(va, priv, csr_ctx)` API：
1. 读取 CP0 monitor 维护的 CSR 镜像（satp、priv_mode、mxr、sum）。  
2. 查 `mmu_page_table_mem` 模拟 3 级 Sv39 页表行走。  
3. 应用 PMP flag 推导最终 PA 或异常类型（`mmu_exc_e`：NONE / PAGE_FAULT / ACCESS_FAULT / PMP_DENY / BUS_ERROR）。  
4. 将预期结果送往 `mmu_translation_sb`。

#### 2.8.3 mmu_translation_sb（中）

最核心的 Scoreboard，对标参考图中的 "HPDcache Scoreboard + data check"。

```
                  ifu_monitor.ap_rsp  ──────────────────────┐
                  lsu_monitor.ap_pipe0/1 ────────────────── ▼
                  ptw_mem_monitor.ap_rsp ─────────────────► [analysis FIFO]
                  pmp_monitor.ap ──────────────────────────►  mmu_translation_sb
                                                                │
              mmu_ref_model（translate 结果）─────────────────► 比对 DUT 输出 vs 预期
                                                                │
                                                          PASS / FAIL + report
```

比对项：PA 值、pgflt/access_fault/deny 异常标志、属性位（sec/ca/buf/sh/so）。

#### 2.8.4 mmu_invalidate_sb（中右）

专项检查 SFENCE.VMA 后 TLB 条目状态：
```
lsu_monitor.ap_inv ──────────────────► mmu_invalidate_sb
                                         │ 触发 inv 操作后
                                         │ 检查后续访问不命中已失效条目
                                         ▼
                                        PASS / FAIL
```

#### 2.8.5 mmu_credit_sb（右二）

守恒性检查：L1↔L2 credit 计数、L2 ReqQ(9 深) 满载、MB 条目总数：
```
ptw_mem_monitor.ap_rsp ─────────────► mmu_credit_sb（统计 outstanding 请求数）
lsu_monitor.ap_pipe0/1 ─────────────►（对比 credit_sva 断言结果）
```

#### 2.8.6 mmu_perf_mon（最右）

统计 L1/L2 TLB miss rate 与 PTW walk latency（对标参考图左下的 "Memory Rsp Configuration" + "Scoreboard HWPF Stride" 的性能统计侧）：
```
misc_monitor.ap_hpcp ────────────────────────────────────► mmu_perf_mon
                                                             │
                                          输出：miss_rate、walk_latency_avg
```

---

## 3. 完整数据流路径

### 3.1 正常翻译流（IFU 侧）

```
① Test 调用 mmu_smoke_vseq.start(virt_seqr)
② virt_seqr 向 cp0_sequencer 发 cp0_satp_switch_seq → cp0_driver 写 SATP
③ cp0_monitor.ap → mmu_ref_model 更新 CSR 镜像
④ virt_seqr 向 ptw_mem_sequencer 发 ptw_page_table_build_4k_seq
   → page_table_builder.map_4k(va, pa) → mmu_page_table_mem 写入页表
⑤ virt_seqr 向 ifu_sequencer 发 ifu_random_vaddr_seq
   → ifu_driver 驱动 ifu_if(va_vld=1, va=0x...）
⑥ DUT L1 ITLB miss → 发起 L2 TLB 查找 → L2 miss → credit 消耗 → PTW 发出内存请求
⑦ DUT.mmu_lsu_data_req=1 → ptw_mem_if → ptw_mem_responder
   → 查 page_table_builder → 延迟 N 周期 → 驱动 lsu_mmu_data_vld=1, data=PTE
⑧ DUT PTW 解析 PTE → 回填 L2/L1 TLB → 返回 mmu_ifu_pavld=1, pa=0x...
⑨ ifu_monitor.ap_rsp 捕获 {va, pa, pgflt, deny, sec, ca, buf}
⑩ mmu_ref_model.translate(va) 输出预期 {pa, exc_type}
⑪ mmu_translation_sb 比对 ⑨ vs ⑩ → PASS / report ERROR
```

### 3.2 TLB 无效化流（SFENCE.VMA）

```
① virt_seqr → lsu_sequencer 发 lsu_sfence_vma_stress_seq
   → lsu_driver.drive_inv() 驱动 tlb_va_asid_inv=1, inv_va=X, inv_asid=Y
② DUT TLBOper FSM 执行 tlbiasid（7 FSM 之一）→ 清除 L1/L2 条目
③ lsu_monitor.ap_inv 捕获 inv_txn → mmu_invalidate_sb 标记 ASID=Y 已失效
④ virt_seqr 继续发 lsu_back2back_seq（相同 va 访问）
   → lsu_monitor.ap_pipe0 捕获结果
⑤ mmu_invalidate_sb 检查：失效 VA/ASID 访问必须触发新的 PTW，不能命中残留条目
⑥ PASS / report ERROR（TLB 残留 stale entry 问题）
```

### 3.3 PMP 拒绝流

```
① virt_seqr → pmp_sequencer 发 pmp_flg_deny_fetch_seq
   → pmp_driver 驱动 pmp_mmu_flg3[3:0]=DENY
② DUT 翻译后将 PA 广播到 mmu_pmp_pa{0..7}，读回 pmp_mmu_flg3
③ DUT 输出 mmu_ifu_deny=1
④ ifu_monitor.ap_rsp 捕获 {deny=1}
⑤ mmu_ref_model 按 PMP flag 推导预期 exc=EXC_PMP_DENY
⑥ mmu_translation_sb 比对 → PASS
```

### 3.4 总线错误注入流（PTW bus_error）

```
① virt_seqr → ptw_mem_sequencer 发 ptw_mem_bus_error_inject_seq
   → ptw_mem_responder 设置 m_bus_error_rate_permille > 0
② ptw_mem_responder 驱动 lsu_mmu_bus_error=1
③ DUT PTW TWU FSM → 转换为 access_fault，返回 mmu_lsu_page_fault0=0, access_fault0=1
④ lsu_monitor.ap_pipe0 捕获 {access_fault=1}
⑤ mmu_ref_model 推导 exc=EXC_BUS_ERROR → EXC_ACCESS_FAULT
⑥ mmu_translation_sb 比对 → PASS
```

---

## 4. Package 与编译依赖

```
uvm_pkg
   ├──► mmu_params_pkg（Sv39 常量 / typedef）
   │         └──► mmu_common_pkg（PTE 工具 / exc_e）
   │                   ├──► ifu_agent_pkg
   │                   ├──► lsu_agent_pkg
   │                   ├──► cp0_agent_pkg
   │                   ├──► ptw_mem_agent_pkg
   │                   ├──► pmp_agent_pkg
   │                   ├──► sysmap_cfg_agent_pkg
   │                   ├──► misc_agent_pkg
   │                   └──► mmu_env_pkg ──► test_pkg
   │
   └──► dv_utils 各 pkg（clock / reset / watchdog / memory_rsp / memory_shadow / ...）
               └──► mmu_env_pkg
```

---

## 5. 与 hpdcache 参考图的对位关系

| hpdcache_verification（参考图） | MMU 对应组件 | 位置 |
|---|---|---|
| HPDcache Scoreboard（顶部横幅） | mmu_translation_sb / mmu_invalidate_sb / mmu_credit_sb | 底部横向排列 |
| Memory Shadow（右上角） | mmu_page_table_mem（基于 memory_shadow） | 底部左端 |
| Watch Dog | dv_utils watchdog_c（在 mmu_env 内） | env 顶部内侧 |
| Pulse Gen(flush) | misc_agent 内 pulse_gen_driver（RTU flush） | 左侧 misc_agent |
| Memory Partition | dv_utils memory_partition（可选，页表 / 数据分区） | ptw_mem_agent 配置 |
| Top Configuration | mmu_top_cfg | env 右侧 |
| HPDcache Request Agent → vif → DUT | ifu_agent / lsu_agent → ifu_if / lsu_if → DUT | 左侧 |
| Scoreboard HWPF Stride | mmu_invalidate_sb（TLBOper 后状态） | 底部 |
| HWPF Stride + CSR | cp0_agent（CSR 写入）+ sysmap_cfg_agent | 左侧 |
| Memory Agent + Monitor（右侧） | ptw_mem_agent（Responder）+ ptw_mem_monitor | 右侧 |
| BP Driver | pmp_agent（8 端口 flag responder） | 右侧 |
| axiomem / Memory Request Arbiter | ptw_mem_responder + page_table_builder | 右侧 |
| Memory Response Model（底部横幅） | mmu_ref_model（translate API + Sv39 walker） | 底部 |
| bind SV PLRU MODEL and assertions | mmu_plru_sva.sv（bind 到 DUT） | DUT 内 bind |
| bind SV arbiter models and assertions | mmu_arb_sva.sv / credit_sva.sv | DUT 内 bind |
| Reset Driver → vif | dv_utils reset_driver_c（tb_top） | tb_top 底部 |
| Clock Driver → vif | dv_utils clock_driver_c（tb_top） | tb_top 底部 |

---

## 6. 文件统计速查

| 模块层 | 文件数 | 关键文件 |
|---|---|---|
| tb_top + SVA | 6 | `tb_top.sv`、5 个 `*_sva.sv` |
| mmu_params / common | 3 | `mmu_params_pkg.sv`、`mmu_common_pkg.sv`、`mmu_types_pkg.sv` |
| 7 × Agent（八件套 + 工具） | 65 | `*_txn/driver/monitor/seqr/sequences/cov/agent/pkg` |
| env 层 | 11 | `mmu_env.svh`、3 × SB、ref_model、PT_mem、perf_mon、virt_seqr、vseq_lib、top_cfg、pkg |
| test 层 | ≈ 122 | `test_base`、14 目录 × 约 8 test/目录 |
| simu / scripts | 10 | `run_test.py`、`run_vcs_verdi.py`、`Makefile`、`Files.f` 等 |
| **环境本体（不含 TC）** | **≈ 96** | — |
