# PTW covp 未覆盖代码报告

本报告原始版本基于 `make covp` 生成的 URG 覆盖率报告：`mmu_verification/output/coverage/phase14_urgReport`。
- 原始 URG 日期：Tue Jun 16 23:27:13 2026
- URG 命令：urg -full64 -dir /x2025/GPrj1/IC2/mmu_verification/mmu_verification/output/coverage/phase14_merged.vdb -elfile /x2025/GPrj1/IC2/mmu_verification/mmu_verification/simu/exclude_v4.tgl -format both -report /x2025/GPrj1/IC2/mmu_verification/mmu_verification/output/coverage/phase14_urgReport
- 统计范围：`tb_top.u_dut.x_ct_mmu_ptw` 下所有实例，即 PTW 模块及其子模块。
- `hierarchy.txt` 中 PTW 子树覆盖率汇总：`83.97  97.11  80.14  61.79  75.00  95.68  94.12 x_ct_mmu_ptw(x)`
- 解析到的 PTW 子树实例数：`127`。
- 原始未覆盖记录数：`4202`；合并后唯一代码对象数：`1783`。

### 更新记录 (2026-06-17)

基于以下新增定向测试的覆盖率结果，对 PDECACHE 相关模块的未覆盖项进行了更新：

| 测试 | URG 报告 | 运行时间 |
| --- | --- | --- |
| `test_ptw_l1pde_cache_cov_closure_001` | `l1pde_single_urgReport` | Jun 17 13:39 |
| `test_ptw_l2pde_pde_cache_cov_closure_001` | `l2pde_pde_single_urgReport` | Jun 17 15:44 |

各 PDECACHE 子模块在新测试中的**模块类型级**覆盖率对比（modlist 汇总）：

| 模块 | 指标 | phase14 (合并) | l1pde_single | l2pde_pde_single |
| --- | --- | ---: | ---: | ---: |
| `L1PDE_cache` | COND / TOGGLE | 94.29% / 69.81% | **100% / 100%** | 85.71% / 51.30% |
| `L2PDE_cache` | COND / TOGGLE | 87.93% / 76.98% | 65.52% / 49.50% | **89.66% / 98.02%** |
| `PDE_cache` | TOGGLE | 37.95% | 41.84% | **70.75%** |
| `pplru` (8-entry) | TOGGLE | 93.51% | **98.84%** | 24.42% |
| `pplru` (16-entry) | TOGGLE | 93.51% | 13.64% | **100%** |

**已处理：** L1PDE_cache 条目 0-7 在 l1pde_single 中达到 LINE/COND/TOGGLE/BRANCH 全 100%，对应未覆盖项已从本报告移除。L1PDE_cache 条目 8-15 仍需后续覆盖。其他模块的显著改进已标注。

## 阅读说明

- 重复实例按覆盖率类型、模块、源码行号和代码文本合并；`影响实例数` 表示 PTW 子树中有多少实例命中同一个未覆盖对象。
- 表格中的 `行号` 是源码行号，`未覆盖代码/对象` 是 URG 指出的语句、表达式、信号、端口、状态迁移或 SVA 对象，`URG 细节` 保留原始覆盖率细节。
- 代码块只给出定位上下文，`>>` 标记 URG 对应的源码行；上下相邻行用于辅助判断该代码属于哪个 if/case/always/assert 块。
- Toggle 覆盖率在 URG 中通常没有可执行源码行；这里列出未翻转的端口/信号以及源码中匹配到的声明或赋值位置。
- `implicit_else` 是 VCS/URG 推导出的隐式 else 路径未覆盖，不一定对应 RTL 中显式写出的 `else` 行。

## 代码列说明

- 如果 `未覆盖代码/对象` 是完整 RTL/SVA 语句，表示该语句在本次回归中没有达到 URG 统计要求。
- 如果显示 `EXPRESSION` 或 `SUB-EXPRESSION`，表示条件表达式中的某些取值组合没有被测到；`URG 细节` 中的 0/1 串按表达式 term 顺序排列。
- 如果显示 `signal[range] -> declaration`，左侧是未完整翻转的位段，右侧是源码中匹配到的声明或赋值，用来定位信号定义。
- `MISSING_ELSE after previous statement` 表示前一条条件语句的隐式 else/默认路径没有被覆盖。
- 断言/cover 条目中的 `RealSuccesses=0` 或 `Matches=0` 表示该 SVA 对象虽然可能被 attempt，但没有真正成功或命中。

## 汇总

| 覆盖类型 | 原始未覆盖记录数 | 合并后唯一代码对象数 |
| --- | ---: | ---: |
| 行覆盖 | 93 | 29 |
| 隐式 else / 缺失分支 | 2 | 1 |
| 条件覆盖 | 1156 | 174 |
| 分支覆盖 | 73 | 23 |
| FSM 状态迁移覆盖 | 8 | 2 |
| 翻转覆盖 - 端口 | 1118 | 576 |
| 翻转覆盖 - 内部信号 | 1725 | 957 |
| 断言/cover 命中覆盖 | 27 | 21 |

| 模块 | PTW 子树实例数 | phase14 未覆盖对象数 | 当前剩余 (6/17更新后) | 源码 |
| --- | ---: | ---: | ---: | --- |
| `L1PDE_cache` | 16 | 65 | **0** 🟢 (条目0-7已全覆盖; 条目8-15待补齐) | `mmu/rtl/L1PDE_cache.sv` |
| `L2PDE_cache` | 16 | 57 | **5** 🟡 (toggle已基本覆盖, 条件5项保留) | `mmu/rtl/L2PDE_cache.sv` |
| `PDE_cache` | 1 | 45 | **45** 🟡 (toggle提升+32.8%, 条件+剩余toggle保留) | `mmu/rtl/PDE_cache.sv` |
| `gated_clk_cell` | 50 | 8 | 8 | `mmu/rtl/relate rtl/clk/gated_clk_cell.v` |
| `mbuf_entry` | 9 | 140 | 140 | `mmu/rtl/mbuf_entry.sv` |
| `mmu_maee_twu_sva` | 4 | 0 | 0 | `mmu_verification/testbench/top/mmu_maee_twu_sva.sv` |
| `mmu_pde_cache_sva` | 1 | 82 | **82** 🔴 (未针对增强) | `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` |
| `mmu_pde_pplru_sva` | 2 | 6 | **6** 🔴 (未针对增强) | `mmu_verification/testbench/top/mmu_pde_pplru_sva.sv` |
| `mmu_pmp_twu_sva` | 4 | 0 | 0 | `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv` |
| `mmu_ptw_lsu_protocol_sva` | 1 | 0 | 0 | `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` |
| `mmu_ptw_top_sva` | 1 | 19 | 19 | `mmu_verification/testbench/top/mmu_ptw_top_sva.sv` |
| `mmu_ptw_xbar_sva` | 1 | 4 | 4 | `mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv` |
| `mmu_sysmap_sva` | 4 | 1 | 1 | `mmu_verification/testbench/top/mmu_sysmap_sva.sv` |
| `mmu_twu_chk_sva` | 4 | 156 | 156 | `mmu_verification/testbench/top/mmu_twu_chk_sva.sv` |
| `mmu_twu_sva` | 4 | 1 | 1 | `mmu_verification/testbench/top/mmu_twu_sva.sv` |
| `one_to_four_xbar` | 1 | 2 | 2 | `mmu/rtl/one_to_four_xbar.sv` |
| `pplru` | 2 | 22 | **10** 🟢 (toggle已基本覆盖, cond/branch/line/implied_else保留) | `mmu/rtl/pplru.sv` |
| `ptw` | 1 | 202 | 202 | `mmu/rtl/ptw.sv` |
| `ptw_mbuf` | 1 | 44 | 44 | `mmu/rtl/ptw_mbuf.sv` |
| `twu` | 4 | 929 | 929 | `mmu/rtl/twu.sv` |

## 模块 `L1PDE_cache`

源码：`mmu/rtl/L1PDE_cache.sv`
PTW 子树实例数：`16`；合并后唯一未覆盖代码对象数（phase14）：`65`。

> **🟢 覆盖率更新 (2026-06-17):**
> `test_ptw_l1pde_cache_cov_closure_001` (l1pde_single_urgReport) 对 L1PDE_cache 条目 0-7 达到了 LINE=100%、COND=100%、TOGGLE=100%、BRANCH=100%。
> 以下 phase14 报告的未覆盖项（行覆盖 x4、条件覆盖 x5、分支覆盖 x2、toggle 端口/内部信号共 x54）在条目 0-7 上均已覆盖，**已从本报告移除**。
> 
> **⚠️ 待处理:** L1PDE_cache 条目 8-15 在 l1pde_single 中未被激活（hierarchy 中仅出现 8 个实例）。条目 8-15 的等效覆盖缺口需要后续测试补充，可参考条目 0-7 已覆盖的缺口模式进行定向激励。
> 
> 原 phase14 未覆盖详情（已覆盖，保留供参考）：
> - 行覆盖：L1PDE_vld<=1'b1 (line 82), L1PDE_tag<=upd_vpn (line 95), L1PDE_ppn<=upd_ppn (line 96), L1PDE_l1pmpflg<=upd_l1pmpflg (line 97)
> - 条件覆盖：regs_ptw_clr|L1PDE_entry_upd (line 56), cp0_yy_priv_mode==2'b11 (line 58), cp0_mach_mode & !L1PDE_l1pmpflg[3] (line 120), l1pmp_ok | (cp0_mach_mode & !L1PDE_l1pmpflg[3]) (line 120), L1PDE_vld & (before_upd_vpn==L1PDE_tag) (line 122)
> - 分支覆盖：if(!cpurst_b) (line 77, 90)
> - Toggle 覆盖：L1PDE_vld/tag/ppn/l1pmpflg/l1pmp_ok, entry_upd/ppn/vld/before_upd_hit 等端口和内部信号
> 
## 模块 `L2PDE_cache`

源码：`mmu/rtl/L2PDE_cache.sv`
PTW 子树实例数：`16`；合并后唯一未覆盖代码对象数（phase14）：`57`。

> **🟡 覆盖率更新 (2026-06-17):**
> `test_ptw_l2pde_pde_cache_cov_closure_001` (l2pde_pde_single_urgReport) 对 L2PDE_cache 达到了 LINE=100%、TOGGLE=98.02%（phase14 中 TOGGLE=76.98%）、BRANCH=100%。COND 略有提升（87.93%→89.66%）。
> 以下未覆盖项中，**toggle 相关项大部分已覆盖**（TOGGLE 提升 ~21%），条件覆盖项**大部分仍保留**（COND 仅提升 ~1.7%）。
> 
### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 61 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b11)` | 1 Not Covered x16 | 16 |
| 136 | `SUB-EXPRESSION (cp0_mach_mode & ((!L2PDE_l1pmpflg[3])) & ((!L2PDE_l2pmpflg[3])))` | 1 0 1 Not Covered x16; 1 1 0 Not Covered x16 | 16 |
| 136 | `SUB-EXPRESSION (l1pmp_ok & l2pmp_ok)` | 1 0 Not Covered x16 | 16 |
| 137 | `SUB-EXPRESSION (cp0_mach_mode & ((!L2PDE_l1pmpflg[3])) & ((!L2PDE_l2pmpflg[3])))` | 1 0 1 Not Covered x16; 1 1 0 Not Covered x16 | 16 |
| 137 | `SUB-EXPRESSION (l1pmp_ok & l2pmp_ok)` | 1 0 Not Covered x16 | 16 |

`mmu/rtl/L2PDE_cache.sv:61`

```systemverilog
      59: assign L2PDE_entry_clk_en = regs_ptw_clr | L2PDE_entry_upd;
      60: 
>>    61: assign cp0_mach_mode = ptw_type[TYPE_WIDTH-1:0] == 3'b011 ? cp0_yy_priv_mode[1:0] == 2'b11
      62:                                       : cp0_priv_mode[1:0] == 2'b11;
      63: 
```

`mmu/rtl/L2PDE_cache.sv:136`

```systemverilog
     134: //                  Entry Hit
     135: //------------------------------------------------------------
>>   136: assign L2PDE_hit = (ptw_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]) & ((l1pmp_ok & l2pmp_ok) | cp0_mach_mode & !L2PDE_l1pmpflg[3] & !L2PDE_l2pmpflg[3]);
     137: assign L2PDE_acc_err = L2PDE_vld & ptw_req & (ptw_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]) & !((l1pmp_ok & l2pmp_ok) | cp0_mach_mode & !L2PDE_l1pmpflg[3] & !L2PDE_l2pmpflg[3]);
     138: assign L2PDE_entry_before_upd_hit = L2PDE_vld & (L2PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]);
```

`mmu/rtl/L2PDE_cache.sv:137`

```systemverilog
     135: //------------------------------------------------------------
     136: assign L2PDE_hit = (ptw_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]) & ((l1pmp_ok & l2pmp_ok) | cp0_mach_mode & !L2PDE_l1pmpflg[3] & !L2PDE_l2pmpflg[3]);
>>   137: assign L2PDE_acc_err = L2PDE_vld & ptw_req & (ptw_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]) & !((l1pmp_ok & l2pmp_ok) | cp0_mach_mode & !L2PDE_l1pmpflg[3] & !L2PDE_l2pmpflg[3]);
     138: assign L2PDE_entry_before_upd_hit = L2PDE_vld & (L2PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]);
     139: //------------------------------------------------------------
```

### 翻转覆盖 (端口 + 内部信号)

> **🟢 已覆盖 (2026-06-17):** L2PDE_cache 的 TOGGLE 覆盖率从 phase14 的 76.98% 提升至 l2pde_pde_single 的 98.02%（+21%）。
> 原 phase14 报告的 22 项 toggle 缺口（端口 11 项 + 内部信号 11 项）已基本覆盖，**已从本报告移除**。
> 剩余约 2% 的 toggle 缺口集中在个别 bit 位上，可在后续合并回归中确认是否完全闭合。

## 模块 `PDE_cache`

源码：`mmu/rtl/PDE_cache.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数（phase14）：`45`。

> **🟡 覆盖率更新 (2026-06-17):**
> `test_ptw_l2pde_pde_cache_cov_closure_001` (l2pde_pde_single_urgReport) 对 PDE_cache 的重要改进：TOGGLE 从 37.95% 提升到 70.75%（+32.8%）。
> 大部分 toggle 缺口已覆盖，但仍有 ~30% toggle 缺口和条件缺口（COND 89.19%）需要后续补充。
> 以下仅列出 phase14 中仍可能在合并后存在的未覆盖项。
> 

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 180 | `EXPRESSION (regs_ptw_clr \| tlboper_ptw_abort \| pmp_regs_update)` | 0 0 1 Not Covered | 1 |
| 345 | `EXPRESSION (mbuf_cache_upd & mbuf_cache_upd_lvl[1] & ((!(\|L1PDE_entry_before_upd_hit[(L1PDE_ENTRY_NUM - 1):0]))))` | 1 0 1 Not Covered | 1 |

`mmu/rtl/PDE_cache.sv:180`

```systemverilog
     178: //==============================================================================
     179: //L1PDE_cache
>>   180: assign pde_cache_clear = regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update;
     181: 
     182: generate
```

`mmu/rtl/PDE_cache.sv:345`

```systemverilog
     343: assign L2PDE_plru_read_hit_vld = L2PDE_entry_hit_vld;
     344: 
>>   345: assign L1PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[1] & (!(|L1PDE_entry_before_upd_hit[L1PDE_ENTRY_NUM-1:0])));
     346: assign L2PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[0] & (!(|L2PDE_entry_before_upd_hit[L2PDE_ENTRY_NUM-1:0])));
     347: 
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 32 | `cp0_mmu_mpp[0] -> input logic [1:0] cp0_mmu_mpp,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 47 | `mbuf_cache_upd_ppn[23:22] -> input logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 47 | `mbuf_cache_upd_ppn[27:24] -> input logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 62 | `PDE_xbar_ppn[27:11] -> output logic [PPN_WIDTH-1:0] PDE_xbar_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 70 | `pmp_regs_update -> input logic pmp_regs_update,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 74 | `PDE_cache_acc_err_id[2:1] -> output logic [ID_WIDTH-1:0] PDE_cache_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 74 | `PDE_cache_acc_err_id[6:5] -> output logic [ID_WIDTH-1:0] PDE_cache_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |

`mmu/rtl/PDE_cache.sv:32`

```systemverilog
      30: 	input  logic                  cp0_mmu_mprv,
      31: 	input  logic [1:0]            cp0_yy_priv_mode,
>>    32: 	input  logic [1:0]            cp0_mmu_mpp,
      33: 
      34: //!******************************************
```

`mmu/rtl/PDE_cache.sv:47`

```systemverilog
      45:     input  logic                  mbuf_cache_upd,
      46:     input  logic [PTE_LEVEL-2:0]  mbuf_cache_upd_lvl,
>>    47:     input  logic [PPN_WIDTH-1:0]  mbuf_cache_upd_ppn,
      48:     input  logic [VPN_WIDTH-1:0]  mbuf_cache_upd_vpn,
      49:     input  logic [3:0]            mbuf_cache_upd_l1pmpflg,
```

`mmu/rtl/PDE_cache.sv:62`

```systemverilog
      60:     output logic                  L2PDE_xbar_hit_vld,
      61:     output logic                  L1PDE_xbar_hit_vld,
>>    62:     output logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
      63:     output logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
      64:     output logic [TYPE_WIDTH-1:0] PDE_xbar_type,
```

`mmu/rtl/PDE_cache.sv:70`

```systemverilog
      68: //input  logic 			twu_cache_stop,
      69:     input  logic                  tlboper_ptw_abort,
>>    70:     input  logic                  pmp_regs_update,
      71:     input  logic                  xbar_pde_ready,
      72:     output logic                  PDE_cache_acc_err_vld,
```

`mmu/rtl/PDE_cache.sv:74`

```systemverilog
      72:     output logic                  PDE_cache_acc_err_vld,
      73:     output logic [TYPE_WIDTH-1:0] PDE_cache_acc_err_type,
>>    74:     output logic [ID_WIDTH-1:0]   PDE_cache_acc_err_id,
      75:     input  logic                  PDE_cache_acc_err_grant,
      76:     output logic                  pde_cache_ready
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 86 | `L1PDE_entry_upd[15:8] -> logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_upd ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 88 | `L1PDE_entry_ppn[0][10:5] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[1][1:0] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[1][4:3] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[2][1:0] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[2][5:3] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[3][0] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[3][5:2] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[4][2:1] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[4][5:4] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[5][4:3] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[6][0] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[6][4:3] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[7][1:0] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 88 | `L1PDE_entry_ppn[7][4:3] -> logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 89 | `L1PDE_entry_vld[15:8] -> logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_vld ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 91 | `L2PDE_entry_ppn[0][10:6] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[11][5] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[12][3] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[1][6] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[4][3] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[6][3] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[7][2] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[7][5] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[8][6] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 91 | `L2PDE_entry_ppn[9][6] -> logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 92 | `L2PDE_entry_vld[15:8] -> logic [L2PDE_ENTRY_NUM-1:0] L2PDE_entry_vld ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 94 | `L1PDE_cache_hit_ppn[27:11] -> logic [PPN_WIDTH-1:0] L1PDE_cache_hit_ppn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 95 | `L2PDE_cache_hit_ppn[27:11] -> logic [PPN_WIDTH-1:0] L2PDE_cache_hit_ppn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 96 | `PDE_cache_fin_ppn[27:11] -> logic [PPN_WIDTH-1:0] PDE_cache_fin_ppn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 103 | `L1PDE_entry_hit_idx[15:8] -> logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_hit_idx ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 105 | `L1PDE_entry_before_upd_hit[15:8] -> logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_before_upd_hit;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 110 | `plru_L1PDE_ref_num[15:9] -> logic [L1PDE_ENTRY_NUM-1:0] plru_L1PDE_ref_num ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 112 | `pde_cache_clk_en -> logic pde_cache_clk_en ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 118 | `L2PDE_cache_acc_err_id[2:1] -> logic [ID_WIDTH-1:0] L2PDE_cache_acc_err_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 118 | `L2PDE_cache_acc_err_id[6:5] -> logic [ID_WIDTH-1:0] L2PDE_cache_acc_err_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/PDE_cache.sv:86`

```systemverilog
      84: logic [ID_WIDTH-1:0]                       ptw_id                 ;
      85: logic                                      ptw_req                ;
>>    86: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd        ;
      87: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd        ;
      88: logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn        ;
```

`mmu/rtl/PDE_cache.sv:88`

```systemverilog
      86: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd        ;
      87: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd        ;
>>    88: logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn        ;
      89: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld        ;
      90: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit        ;
```

`mmu/rtl/PDE_cache.sv:89`

```systemverilog
      87: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd        ;
      88: logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn        ;
>>    89: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld        ;
      90: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit        ;
      91: logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn        ;
```

`mmu/rtl/PDE_cache.sv:91`

```systemverilog
      89: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld        ;
      90: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit        ;
>>    91: logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn        ;
      92: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld        ;
      93: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit        ;
```

`mmu/rtl/PDE_cache.sv:92`

```systemverilog
      90: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit        ;
      91: logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn        ;
>>    92: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld        ;
      93: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit        ;
      94: logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn    ;
```

`mmu/rtl/PDE_cache.sv:94`

```systemverilog
      92: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld        ;
      93: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit        ;
>>    94: logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn    ;
      95: logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn    ;
      96: logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn      ;
```

`mmu/rtl/PDE_cache.sv:95`

```systemverilog
      93: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit        ;
      94: logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn    ;
>>    95: logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn    ;
      96: logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn      ;
      97: logic                                      L1PDE_entry_hit_vld    ;
```

`mmu/rtl/PDE_cache.sv:96`

```systemverilog
      94: logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn    ;
      95: logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn    ;
>>    96: logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn      ;
      97: logic                                      L1PDE_entry_hit_vld    ;
      98: logic                                      L2PDE_entry_hit_vld    ;
```

`mmu/rtl/PDE_cache.sv:103`

```systemverilog
     101: logic                                      L1PDE_plru_refill_vld  ;
     102: logic                                      L2PDE_plru_refill_vld  ;
>>   103: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit_idx    ;
     104: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit_idx    ;
     105: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit;
```

`mmu/rtl/PDE_cache.sv:105`

```systemverilog
     103: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit_idx    ;
     104: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit_idx    ;
>>   105: logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit;
     106: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_before_upd_hit;
     107: logic                                      pde_cache_clear          ;
```

`mmu/rtl/PDE_cache.sv:110`

```systemverilog
     108: //logic [L1PDE_INDEX_WIDTH-1:0]              L1PDE_hit_idx_num      ;
     109: //logic [L2PDE_INDEX_WIDTH-1:0]              L2PDE_hit_idx_num      ;
>>   110: logic [L1PDE_ENTRY_NUM-1:0]                plru_L1PDE_ref_num     ;
     111: logic [L2PDE_ENTRY_NUM-1:0]                plru_L2PDE_ref_num     ;
     112: logic                                      pde_cache_clk_en       ;
```

`mmu/rtl/PDE_cache.sv:112`

```systemverilog
     110: logic [L1PDE_ENTRY_NUM-1:0]                plru_L1PDE_ref_num     ;
     111: logic [L2PDE_ENTRY_NUM-1:0]                plru_L2PDE_ref_num     ;
>>   112: logic                                      pde_cache_clk_en       ;
     113: logic                                      pde_cache_clk          ;
     114: logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_acc_err    ;
```

`mmu/rtl/PDE_cache.sv:118`

```systemverilog
     116: logic                                      PDE_cache_acc_err        ;
     117: logic [TYPE_WIDTH-1:0]                     L2PDE_cache_acc_err_type ;
>>   118: logic [ID_WIDTH-1:0]                       L2PDE_cache_acc_err_id   ;
     119: logic                                      L2PDE_entry_acc_err_vld  ;
     120: logic [1:0]                                cp0_priv_mode          ;
```

## 模块 `gated_clk_cell`

源码：`mmu/rtl/relate rtl/clk/gated_clk_cell.v`
PTW 子树实例数：`50`；合并后唯一未覆盖代码对象数：`8`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 37 | `EXPRESSION ((global_en && (module_en \|\| local_en)) \|\| external_en)` | 0 0 Not Covered x16; 0 1 Not Covered x50 | 50 |
| 37 | `SUB-EXPRESSION (global_en && (module_en \|\| local_en))` | 0 1 Not Covered x50; 1 0 Not Covered x16 | 50 |
| 37 | `SUB-EXPRESSION (module_en \|\| local_en)` | 0 0 Not Covered x16; 0 1 Not Covered x34; 1 0 Not Covered x16 | 50 |

`mmu/rtl/relate rtl/clk/gated_clk_cell.v:37`

```systemverilog
      35: wire   SE;
      36: 
>>    37: assign clk_en_bf_latch = (global_en && (module_en || local_en)) || external_en ;
      38: 
      39: // SE driven from primary input, held constant
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 27 | `global_en -> input global_en;` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x50 | 50 |
| 29 | `local_en -> input local_en;` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x16 | 16 |
| 30 | `external_en -> input external_en;` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x50 | 50 |

`mmu/rtl/relate rtl/clk/gated_clk_cell.v:27`

```systemverilog
      25: 
      26: input  clk_in;
>>    27: input  global_en;
      28: input  module_en;
      29: input  local_en;
```

`mmu/rtl/relate rtl/clk/gated_clk_cell.v:29`

```systemverilog
      27: input  global_en;
      28: input  module_en;
>>    29: input  local_en;
      30: input  external_en;
      31: input  pad_yy_icg_scan_en;
```

`mmu/rtl/relate rtl/clk/gated_clk_cell.v:30`

```systemverilog
      28: input  module_en;
      29: input  local_en;
>>    30: input  external_en;
      31: input  pad_yy_icg_scan_en;
      32: output clk_out;
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 34 | `clk_en_bf_latch -> wire clk_en_bf_latch;` | Toggle=No, 1->0=No, 0->1=No x16 | 16 |
| 35 | `SE -> wire SE;` | Toggle=No, 1->0=No, 0->1=No x50 | 50 |

`mmu/rtl/relate rtl/clk/gated_clk_cell.v:34`

```systemverilog
      32: output clk_out;
      33: 
>>    34: wire   clk_en_bf_latch;
      35: wire   SE;
      36: 
```

`mmu/rtl/relate rtl/clk/gated_clk_cell.v:35`

```systemverilog
      33: 
      34: wire   clk_en_bf_latch;
>>    35: wire   SE;
      36: 
      37: assign clk_en_bf_latch = (global_en && (module_en || local_en)) || external_en ;
```

## 模块 `mbuf_entry`

源码：`mmu/rtl/mbuf_entry.sv`
PTW 子树实例数：`9`；合并后唯一未覆盖代码对象数：`140`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 142 | `mbuf_get <= 1'b1;` | 0/1 x4 | 4 |
| 156 | `mbuf_bus_err_flop <= 1'b1;` | 0/1 x9 | 9 |
| 192 | `mbuf_lsu_data[63:0] <= lsu_mmu_data[63:0];` | 0/1 x4 | 4 |
| 199 | `4'b0100 : idx = 2'b10;` | 0/1 | 1 |

`mmu/rtl/mbuf_entry.sv:142`

```systemverilog
     140:     // PDE cache。
     141:     else if(mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
>>   142:         mbuf_get <= 1'b1;
     143:     else if(write_back_grant)
     144:         mbuf_get <= 1'b0;
```

`mmu/rtl/mbuf_entry.sv:156`

```systemverilog
     154:     // 再通过 bus_err_write_back_req 报给 TWU。
     155:     else if(mbuf_on & lsu_mmu_err_routed & (!mbuf_bus_error_grant))
>>   156:         mbuf_bus_err_flop <= 1'b1;
     157:     else if(mbuf_bus_error_grant)
     158:         mbuf_bus_err_flop <= 1'b0;
```

`mmu/rtl/mbuf_entry.sv:192`

```systemverilog
     190:         mbuf_lsu_data[63:0] <= 64'b0;
     191:     else if((!mbuf_all_clr) & mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
>>   192:         mbuf_lsu_data[63:0] <= lsu_mmu_data[63:0];
     193: end
     194: 
```

`mmu/rtl/mbuf_entry.sv:199`

```systemverilog
     197:         4'b0001 : idx = 2'b00;
     198:         4'b0010 : idx = 2'b01;
>>   199:         4'b0100 : idx = 2'b10;
     200:         4'b1000 : idx = 2'b11;
     201:         default : idx = 2'b00;
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 86 | `EXPRESSION (lsu_mmu_data_vld \| lsu_mmu_bus_error)` | 0 1 Not Covered x9 | 9 |
| 124 | `EXPRESSION (mbuf_on & lsu_mmu_resp_vld)` | 0 1 Not Covered x9 | 9 |
| 128 | `EXPRESSION (((!mbuf_all_clr)) & mmu_lsu_data_req_grant)` | 0 1 Not Covered x9 | 9 |
| 141 | `EXPRESSION (mbuf_on & lsu_mmu_data_routed & ((!write_back_grant)))` | 0 1 1 Not Covered x9; 1 1 1 Not Covered x4 | 9 |
| 155 | `EXPRESSION (mbuf_on & lsu_mmu_err_routed & ((!mbuf_bus_error_grant)))` | 0 1 1 Not Covered x9; 1 1 1 Not Covered x9 | 9 |
| 191 | `EXPRESSION (((!mbuf_all_clr)) & mbuf_on & lsu_mmu_data_routed & ((!write_back_grant)))` | 0 1 1 1 Not Covered x8; 1 0 1 1 Not Covered x9; 1 1 1 1 Not Covered x4 | 9 |
| 204 | `SUB-EXPRESSION ((mbuf_on & lsu_mmu_data_routed) \| mbuf_get)` | 0 1 Not Covered x4 | 4 |
| 208 | `EXPRESSION (mbuf_vld & ((!mbuf_all_clr)) & ((mbuf_on & lsu_mmu_err_routed) \| mbuf_bus_err_flop) & ((!mbuf_entry_bus_err_req_mask)))` | 0 1 1 1 Not Covered x9; 1 0 1 1 Not Covered x9; 1 1 1 0 Not Covered x9 | 9 |
| 208 | `SUB-EXPRESSION ((mbuf_on & lsu_mmu_err_routed) \| mbuf_bus_err_flop)` | 0 1 Not Covered x9 | 9 |
| 224 | `EXPRESSION (mbuf_get ? mbuf_lsu_data[63:0] : lsu_mmu_data[63:0])` | 1 Not Covered x4 | 4 |

`mmu/rtl/mbuf_entry.sv:86`

```systemverilog
      84: // “这个 response 就是给我的”。这样 response 路由只有一处，逻辑更直接，也
      85: // 避免每个 entry 重复生成比较器。
>>    86: assign lsu_mmu_resp_vld               = lsu_mmu_data_vld | lsu_mmu_bus_error;
      87: assign lsu_mmu_data_routed            = lsu_mmu_data_vld & (!lsu_mmu_bus_error);
      88: assign lsu_mmu_err_routed             = lsu_mmu_bus_error;
```

`mmu/rtl/mbuf_entry.sv:124`

```systemverilog
     122:     // 的 outstanding 记录；必须等 ptw_mbuf 按 LSU response id 解码后，把
     123:     // response valid/error 直接送到本 entry，再由本 entry 清 on。
>>   124: 	else if(mbuf_on & lsu_mmu_resp_vld)
     125: 		mbuf_on <= 1'b0;
     126:     // 只有 PTW/MBUF 侧的 req 和 LSU 的 grant 同时成立时，才认为请求真正发
```

`mmu/rtl/mbuf_entry.sv:128`

```systemverilog
     126:     // 只有 PTW/MBUF 侧的 req 和 LSU 的 grant 同时成立时，才认为请求真正发
     127:     // 出。未 grant 的请求即使 mmu_lsu_data_req 曾经拉高，也不能置 mbuf_on。
>>   128: 	else if((!mbuf_all_clr) & mmu_lsu_data_req_grant)
     129: 		mbuf_on <= 1'b1;
     130: end
```

`mmu/rtl/mbuf_entry.sv:141`

```systemverilog
     139:     // abort 后这个 entry 不会再向 TWU 返回，也不会经由 write_back 路径更新
     140:     // PDE cache。
>>   141:     else if(mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
     142:         mbuf_get <= 1'b1;
     143:     else if(write_back_grant)
```

`mmu/rtl/mbuf_entry.sv:155`

```systemverilog
     153:     // 返回才会被记录；abort 清 vld 后，即使后续 drain 期间错误返回，也不会
     154:     // 再通过 bus_err_write_back_req 报给 TWU。
>>   155:     else if(mbuf_on & lsu_mmu_err_routed & (!mbuf_bus_error_grant))
     156:         mbuf_bus_err_flop <= 1'b1;
     157:     else if(mbuf_bus_error_grant)
```

`mmu/rtl/mbuf_entry.sv:191`

```systemverilog
     189:     if(!cpurst_b)
     190:         mbuf_lsu_data[63:0] <= 64'b0;
>>   191:     else if((!mbuf_all_clr) & mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
     192:         mbuf_lsu_data[63:0] <= lsu_mmu_data[63:0];
     193: end
```

`mmu/rtl/mbuf_entry.sv:204`

```systemverilog
     202:     endcase
     203: end
>>   204: assign write_back_req = mbuf_vld
     205:                       & (!mbuf_all_clr)
     206:                       & (|(twu_data_ready[idx][PTE_LEVEL-1:0] & mbuf_lvl[PTE_LEVEL-1:0]))
```

`mmu/rtl/mbuf_entry.sv:208`

```systemverilog
     206:                       & (|(twu_data_ready[idx][PTE_LEVEL-1:0] & mbuf_lvl[PTE_LEVEL-1:0]))
     207:                       & ((mbuf_on & lsu_mmu_data_routed) | mbuf_get);
>>   208: assign bus_err_write_back_req = mbuf_vld
     209:                               & (!mbuf_all_clr)
     210:                               & ((mbuf_on & lsu_mmu_err_routed) | mbuf_bus_err_flop)
```

`mmu/rtl/mbuf_entry.sv:224`

```systemverilog
     222: assign mbuf_entry_lvl = mbuf_lvl[PTE_LEVEL-1:0];
     223: assign mbuf_entry_pmpflg = mbuf_pmpflg[7:0];
>>   224: assign mbuf_entry_data = mbuf_get ? mbuf_lsu_data[63:0] : lsu_mmu_data[63:0];
     225: assign mbuf_entry_get = mbuf_get;
     226: assign mbuf_entry_bus_err_flop = mbuf_bus_err_flop;
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 133 | `if(!cpurst_b)` | 0 0 1 - Not Covered x4 | 4 |
| 148 | `if(!cpurst_b)` | 0 0 1 - Not Covered x9 | 9 |
| 189 | `if(!cpurst_b)` | 0 1 Not Covered x4 | 4 |
| 196 | `case(mbuf_twu_idx[3:0])` | 4'b0100 Not Covered | 1 |
| 224 | `assign mbuf_entry_data = mbuf_get ? mbuf_lsu_data[63:0] : lsu_mmu_data[63:0];` | 1 Not Covered x4 | 4 |

`mmu/rtl/mbuf_entry.sv:133`

```systemverilog
     131: 
     132: always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
>>   133:     if(!cpurst_b)
     134:         mbuf_get <= 1'b0;
     135:     else if(mbuf_all_clr | mbuf_entry_upd)
```

`mmu/rtl/mbuf_entry.sv:148`

```systemverilog
     146: 
     147: always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
>>   148:     if(!cpurst_b)
     149:         mbuf_bus_err_flop <= 1'b0;
     150:     else if(mbuf_all_clr | mbuf_entry_upd)
```

`mmu/rtl/mbuf_entry.sv:189`

```systemverilog
     187: 
     188: always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
>>   189:     if(!cpurst_b)
     190:         mbuf_lsu_data[63:0] <= 64'b0;
     191:     else if((!mbuf_all_clr) & mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
```

`mmu/rtl/mbuf_entry.sv:196`

```systemverilog
     194: 
     195: always_comb begin
>>   196:     case(mbuf_twu_idx[3:0])
     197:         4'b0001 : idx = 2'b00;
     198:         4'b0010 : idx = 2'b01;
```

`mmu/rtl/mbuf_entry.sv:224`

```systemverilog
     222: assign mbuf_entry_lvl = mbuf_lvl[PTE_LEVEL-1:0];
     223: assign mbuf_entry_pmpflg = mbuf_pmpflg[7:0];
>>   224: assign mbuf_entry_data = mbuf_get ? mbuf_lsu_data[63:0] : lsu_mmu_data[63:0];
     225: assign mbuf_entry_get = mbuf_get;
     226: assign mbuf_entry_bus_err_flop = mbuf_bus_err_flop;
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 24 | `lsu_mmu_data[33:32] -> input logic [63:0] lsu_mmu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x9 | 9 |
| 24 | `lsu_mmu_data[58:55] -> input logic [63:0] lsu_mmu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x9 | 9 |
| 28 | `mbuf_upd_padder[2:0] -> input logic [PADDR_WIDTH-1:0] mbuf_upd_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x9 | 9 |
| 28 | `mbuf_upd_padder[39:23] -> input logic [PADDR_WIDTH-1:0] mbuf_upd_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x9 | 9 |
| 37 | `mbuf_entry_bus_err_req_mask -> input logic mbuf_entry_bus_err_req_mask,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x9 | 9 |
| 42 | `mbuf_entry_padder[13] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[14] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[15:13] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[15:14] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[15] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x3 | 3 |
| 42 | `mbuf_entry_padder[17] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[21:19] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[2:0] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x9 | 9 |
| 42 | `mbuf_entry_padder[39:17] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 42 | `mbuf_entry_padder[39:18] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x3 | 3 |
| 42 | `mbuf_entry_padder[39:22] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 42 | `mbuf_entry_padder[39:23] -> output logic [PADDR_WIDTH-1:0] mbuf_entry_padder,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[10:9] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[10] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[11:10] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x3 | 3 |
| 45 | `mbuf_entry_vpn[11] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[12] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 45 | `mbuf_entry_vpn[15] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[20:18] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[26:11] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 45 | `mbuf_entry_vpn[26:12] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 45 | `mbuf_entry_vpn[26:21] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 45 | `mbuf_entry_vpn[8] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 45 | `mbuf_entry_vpn[9] -> output logic [VPN_WIDTH-1:0] mbuf_entry_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 46 | `mbuf_entry_type[0] -> output logic [TYPE_WIDTH-1:0] mbuf_entry_type,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x8 | 8 |
| 46 | `mbuf_entry_type[1:0] -> output logic [TYPE_WIDTH-1:0] mbuf_entry_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 46 | `mbuf_entry_type[1] -> output logic [TYPE_WIDTH-1:0] mbuf_entry_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x4 | 4 |
| 46 | `mbuf_entry_type[2] -> output logic [TYPE_WIDTH-1:0] mbuf_entry_type,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 47 | `mbuf_entry_id[2] -> output logic [ID_WIDTH-1:0] mbuf_entry_id,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 47 | `mbuf_entry_id[3] -> output logic [ID_WIDTH-1:0] mbuf_entry_id,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 47 | `mbuf_entry_id[5:4] -> output logic [ID_WIDTH-1:0] mbuf_entry_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 2 |
| 47 | `mbuf_entry_id[6:0] -> output logic [ID_WIDTH-1:0] mbuf_entry_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 47 | `mbuf_entry_id[6] -> output logic [ID_WIDTH-1:0] mbuf_entry_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x3 | 3 |
| 48 | `mbuf_entry_twu_idx[2] -> output logic [3:0] mbuf_entry_twu_idx,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 50 | `mbuf_entry_pmpflg[3] -> output logic [7:0] mbuf_entry_pmpflg,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x8 | 8 |
| 50 | `mbuf_entry_pmpflg[7] -> output logic [7:0] mbuf_entry_pmpflg,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x8 | 8 |
| 51 | `mbuf_entry_data[33:32] -> output logic [63:0] mbuf_entry_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x9 | 9 |
| 51 | `mbuf_entry_data[58:55] -> output logic [63:0] mbuf_entry_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x9 | 9 |
| 52 | `mbuf_entry_get -> output logic mbuf_entry_get,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 53 | `mbuf_entry_bus_err_flop -> output logic mbuf_entry_bus_err_flop` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x9 | 9 |

`mmu/rtl/mbuf_entry.sv:24`

```systemverilog
      22:     input  logic                      mbuf_all_clr,
      23:     input  logic                      lsu_mmu_data_vld,
>>    24:     input  logic [63:0]               lsu_mmu_data,
      25:     input  logic                      mmu_lsu_data_req_grant,
      26:     input  logic                      lsu_mmu_bus_error,
```

`mmu/rtl/mbuf_entry.sv:28`

```systemverilog
      26:     input  logic                      lsu_mmu_bus_error,
      27:     input  logic                      mbuf_entry_upd,
>>    28:     input  logic [PADDR_WIDTH-1:0]    mbuf_upd_padder,
      29:     input  logic [VPN_WIDTH-1:0]      mbuf_upd_vpn,
      30:     input  logic [TYPE_WIDTH-1:0]     mbuf_upd_type,
```

`mmu/rtl/mbuf_entry.sv:37`

```systemverilog
      35:     input  logic [3:0][PTE_LEVEL-1:0] twu_data_ready,
      36:     input  logic                      write_back_grant,
>>    37:     input  logic                      mbuf_entry_bus_err_req_mask,
      38:     input  logic                      mbuf_bus_error_grant,
      39: 
```

`mmu/rtl/mbuf_entry.sv:42`

```systemverilog
      40:     output logic                      write_back_req,
      41:     output logic                      bus_err_write_back_req,
>>    42:     output logic [PADDR_WIDTH-1:0]    mbuf_entry_padder,
      43:     output logic                      mbuf_entry_vld,
      44:     output logic                      mbuf_entry_on,
```

`mmu/rtl/mbuf_entry.sv:45`

```systemverilog
      43:     output logic                      mbuf_entry_vld,
      44:     output logic                      mbuf_entry_on,
>>    45:     output logic [VPN_WIDTH-1:0]      mbuf_entry_vpn,
      46:     output logic [TYPE_WIDTH-1:0]     mbuf_entry_type,
      47:     output logic [ID_WIDTH-1:0]       mbuf_entry_id,
```

`mmu/rtl/mbuf_entry.sv:46`

```systemverilog
      44:     output logic                      mbuf_entry_on,
      45:     output logic [VPN_WIDTH-1:0]      mbuf_entry_vpn,
>>    46:     output logic [TYPE_WIDTH-1:0]     mbuf_entry_type,
      47:     output logic [ID_WIDTH-1:0]       mbuf_entry_id,
      48:     output logic [3:0]                mbuf_entry_twu_idx,
```

`mmu/rtl/mbuf_entry.sv:47`

```systemverilog
      45:     output logic [VPN_WIDTH-1:0]      mbuf_entry_vpn,
      46:     output logic [TYPE_WIDTH-1:0]     mbuf_entry_type,
>>    47:     output logic [ID_WIDTH-1:0]       mbuf_entry_id,
      48:     output logic [3:0]                mbuf_entry_twu_idx,
      49:     output logic [PTE_LEVEL-1:0]      mbuf_entry_lvl,
```

`mmu/rtl/mbuf_entry.sv:48`

```systemverilog
      46:     output logic [TYPE_WIDTH-1:0]     mbuf_entry_type,
      47:     output logic [ID_WIDTH-1:0]       mbuf_entry_id,
>>    48:     output logic [3:0]                mbuf_entry_twu_idx,
      49:     output logic [PTE_LEVEL-1:0]      mbuf_entry_lvl,
      50:     output logic [7:0]                mbuf_entry_pmpflg,
```

`mmu/rtl/mbuf_entry.sv:50`

```systemverilog
      48:     output logic [3:0]                mbuf_entry_twu_idx,
      49:     output logic [PTE_LEVEL-1:0]      mbuf_entry_lvl,
>>    50:     output logic [7:0]                mbuf_entry_pmpflg,
      51:     output logic [63:0]               mbuf_entry_data,
      52:     output logic                      mbuf_entry_get,
```

`mmu/rtl/mbuf_entry.sv:51`

```systemverilog
      49:     output logic [PTE_LEVEL-1:0]      mbuf_entry_lvl,
      50:     output logic [7:0]                mbuf_entry_pmpflg,
>>    51:     output logic [63:0]               mbuf_entry_data,
      52:     output logic                      mbuf_entry_get,
      53:     output logic                      mbuf_entry_bus_err_flop
```

`mmu/rtl/mbuf_entry.sv:52`

```systemverilog
      50:     output logic [7:0]                mbuf_entry_pmpflg,
      51:     output logic [63:0]               mbuf_entry_data,
>>    52:     output logic                      mbuf_entry_get,
      53:     output logic                      mbuf_entry_bus_err_flop
      54: );
```

`mmu/rtl/mbuf_entry.sv:53`

```systemverilog
      51:     output logic [63:0]               mbuf_entry_data,
      52:     output logic                      mbuf_entry_get,
>>    53:     output logic                      mbuf_entry_bus_err_flop
      54: );
      55: 
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 59 | `mbuf_padder[13] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 59 | `mbuf_padder[14] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 59 | `mbuf_padder[15:13] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 59 | `mbuf_padder[15:14] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 59 | `mbuf_padder[15] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 59 | `mbuf_padder[17] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 59 | `mbuf_padder[21:19] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 59 | `mbuf_padder[2:0] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No x9 | 9 |
| 59 | `mbuf_padder[39:17] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 59 | `mbuf_padder[39:18] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 59 | `mbuf_padder[39:22] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 59 | `mbuf_padder[39:23] -> logic [PADDR_WIDTH-1:0] mbuf_padder ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 60 | `mbuf_vpn[10:9] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 60 | `mbuf_vpn[10] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 60 | `mbuf_vpn[11:10] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 60 | `mbuf_vpn[11] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 60 | `mbuf_vpn[12] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 60 | `mbuf_vpn[15] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 60 | `mbuf_vpn[20:18] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 60 | `mbuf_vpn[26:11] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 60 | `mbuf_vpn[26:12] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 60 | `mbuf_vpn[26:21] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 60 | `mbuf_vpn[8] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 60 | `mbuf_vpn[9] -> logic [VPN_WIDTH-1:0] mbuf_vpn ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 61 | `mbuf_type[0] -> logic [TYPE_WIDTH-1:0] mbuf_type ;` | Toggle=No, 1->0=No, 0->1=No x8 | 8 |
| 61 | `mbuf_type[1:0] -> logic [TYPE_WIDTH-1:0] mbuf_type ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 61 | `mbuf_type[1] -> logic [TYPE_WIDTH-1:0] mbuf_type ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 61 | `mbuf_type[2] -> logic [TYPE_WIDTH-1:0] mbuf_type ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 62 | `mbuf_id[2] -> logic [ID_WIDTH-1:0] mbuf_id ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 62 | `mbuf_id[3] -> logic [ID_WIDTH-1:0] mbuf_id ; //` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 62 | `mbuf_id[5:4] -> logic [ID_WIDTH-1:0] mbuf_id ; //` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 62 | `mbuf_id[6:0] -> logic [ID_WIDTH-1:0] mbuf_id ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 62 | `mbuf_id[6] -> logic [ID_WIDTH-1:0] mbuf_id ; //` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 63 | `mbuf_twu_idx[2] -> logic [3:0] mbuf_twu_idx ; //` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[10:8] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[11:10] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[11] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[13:10] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 65 | `mbuf_lsu_data[13:12] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[14] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[15:13] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[15:14] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[16:15] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 65 | `mbuf_lsu_data[16] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[17] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[18:17] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[18] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[19] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 65 | `mbuf_lsu_data[21:17] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 65 | `mbuf_lsu_data[21:20] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 65 | `mbuf_lsu_data[22] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 65 | `mbuf_lsu_data[23:16] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[23] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[24:22] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[24] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[25:23] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[25:24] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[25] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[26:25] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[27:26] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[29:27] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[29:28] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 65 | `mbuf_lsu_data[3:0] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes x5 | 5 |
| 65 | `mbuf_lsu_data[5:4] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No x5 | 5 |
| 65 | `mbuf_lsu_data[63:0] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 65 | `mbuf_lsu_data[63:25] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[63:26] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[63:28] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `mbuf_lsu_data[63:30] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 65 | `mbuf_lsu_data[7:6] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=Yes x5 | 5 |
| 65 | `mbuf_lsu_data[9:8] -> logic [63:0] mbuf_lsu_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 67 | `mbuf_get -> logic mbuf_get ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 68 | `mbuf_bus_err_flop -> logic mbuf_bus_err_flop;` | Toggle=No, 1->0=No, 0->1=No x9 | 9 |
| 69 | `mbuf_entry_clk_en -> logic mbuf_entry_clk_en;` | Toggle=No, 1->0=No, 0->1=No x9 | 9 |
| 71 | `mbuf_pmpflg[3] -> logic [7:0] mbuf_pmpflg ;` | Toggle=No, 1->0=No, 0->1=No x8 | 8 |
| 71 | `mbuf_pmpflg[7] -> logic [7:0] mbuf_pmpflg ;` | Toggle=No, 1->0=No, 0->1=No x8 | 8 |

`mmu/rtl/mbuf_entry.sv:59`

```systemverilog
      57: logic                   mbuf_vld         ;                      //
      58: logic                   mbuf_on          ;                      //
>>    59: logic [PADDR_WIDTH-1:0] mbuf_padder      ;                      //
      60: logic [VPN_WIDTH-1:0]   mbuf_vpn         ;                      //
      61: logic [TYPE_WIDTH-1:0]  mbuf_type        ;
```

`mmu/rtl/mbuf_entry.sv:60`

```systemverilog
      58: logic                   mbuf_on          ;                      //
      59: logic [PADDR_WIDTH-1:0] mbuf_padder      ;                      //
>>    60: logic [VPN_WIDTH-1:0]   mbuf_vpn         ;                      //
      61: logic [TYPE_WIDTH-1:0]  mbuf_type        ;
      62: logic [ID_WIDTH-1:0]    mbuf_id          ;                      //
```

`mmu/rtl/mbuf_entry.sv:61`

```systemverilog
      59: logic [PADDR_WIDTH-1:0] mbuf_padder      ;                      //
      60: logic [VPN_WIDTH-1:0]   mbuf_vpn         ;                      //
>>    61: logic [TYPE_WIDTH-1:0]  mbuf_type        ;
      62: logic [ID_WIDTH-1:0]    mbuf_id          ;                      //
      63: logic [3:0]             mbuf_twu_idx     ;                      //
```

`mmu/rtl/mbuf_entry.sv:62`

```systemverilog
      60: logic [VPN_WIDTH-1:0]   mbuf_vpn         ;                      //
      61: logic [TYPE_WIDTH-1:0]  mbuf_type        ;
>>    62: logic [ID_WIDTH-1:0]    mbuf_id          ;                      //
      63: logic [3:0]             mbuf_twu_idx     ;                      //
      64: logic [PTE_LEVEL-1:0]   mbuf_lvl         ;                      //
```

`mmu/rtl/mbuf_entry.sv:63`

```systemverilog
      61: logic [TYPE_WIDTH-1:0]  mbuf_type        ;
      62: logic [ID_WIDTH-1:0]    mbuf_id          ;                      //
>>    63: logic [3:0]             mbuf_twu_idx     ;                      //
      64: logic [PTE_LEVEL-1:0]   mbuf_lvl         ;                      //
      65: logic [63:0]            mbuf_lsu_data    ;
```

`mmu/rtl/mbuf_entry.sv:65`

```systemverilog
      63: logic [3:0]             mbuf_twu_idx     ;                      //
      64: logic [PTE_LEVEL-1:0]   mbuf_lvl         ;                      //
>>    65: logic [63:0]            mbuf_lsu_data    ;
      66: logic [1:0]             idx              ;
      67: logic                   mbuf_get         ;
```

`mmu/rtl/mbuf_entry.sv:67`

```systemverilog
      65: logic [63:0]            mbuf_lsu_data    ;
      66: logic [1:0]             idx              ;
>>    67: logic                   mbuf_get         ;
      68: logic                   mbuf_bus_err_flop;
      69: logic                   mbuf_entry_clk_en;
```

`mmu/rtl/mbuf_entry.sv:68`

```systemverilog
      66: logic [1:0]             idx              ;
      67: logic                   mbuf_get         ;
>>    68: logic                   mbuf_bus_err_flop;
      69: logic                   mbuf_entry_clk_en;
      70: logic                   mbuf_entry_clk   ;
```

`mmu/rtl/mbuf_entry.sv:69`

```systemverilog
      67: logic                   mbuf_get         ;
      68: logic                   mbuf_bus_err_flop;
>>    69: logic                   mbuf_entry_clk_en;
      70: logic                   mbuf_entry_clk   ;
      71: logic [7:0]             mbuf_pmpflg      ;
```

`mmu/rtl/mbuf_entry.sv:71`

```systemverilog
      69: logic                   mbuf_entry_clk_en;
      70: logic                   mbuf_entry_clk   ;
>>    71: logic [7:0]             mbuf_pmpflg      ;
      72: logic                   lsu_mmu_resp_vld ;
      73: logic                   lsu_mmu_data_routed;
```

## 模块 `mmu_pde_cache_sva`

源码：`mmu_verification/testbench/top/mmu_pde_cache_sva.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数（phase14）：`82`。

> **🔴 覆盖率更新 (2026-06-17):**
> `l2pde_pde_single` 中 `mmu_pde_cache_sva` 的 ASSERT 覆盖率为 61.46%（phase14 为 87.50%），单个测试的 SVA 覆盖率低于合并回归结果。
> 断言/cover 项在本轮未专门针对性增强，以下所有未覆盖项**仍保留**，待后续 SVA 专项测试处理。
> 
### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 136 | `SUB-EXPRESSION (cp0_yy_priv_mode == 2'b11)` | 1 Not Covered | 1 |

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:136`

```systemverilog
     134:     input logic [TYPE_WIDTH-1:0] req_type
     135:   );
>>   136:     pde_effective_m = (req_type == PTW_TYPE_FETCH)
     137:                     ? (cp0_yy_priv_mode == 2'b11)
     138:                     : (cp0_priv_mode == 2'b11);
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 24 | `pmp_regs_update -> input logic pmp_regs_update,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 30 | `mbuf_cache_upd_ppn[23:22] -> input logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 30 | `mbuf_cache_upd_ppn[27:24] -> input logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 37 | `L1PDE_entry_upd[15:8] -> input logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_upd,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 39 | `plru_L1PDE_ref_num[15:9] -> input logic [L1PDE_ENTRY_NUM-1:0] plru_L1PDE_ref_num,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `L1PDE_entry_vld[15:8] -> input logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_vld,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 44 | `L2PDE_entry_vld[15:8] -> input logic [L2PDE_ENTRY_NUM-1:0] L2PDE_entry_vld,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 47 | `L1PDE_entry_hit_idx[15:8] -> input logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_hit_idx,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[1][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[2][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[3][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[4][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[5][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[6][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 51 | `L1PDE_l1pmpflg[7][2:0] -> input logic [L1PDE_ENTRY_NUM-1:0][3:0] L1PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 52 | `L2PDE_l1pmpflg[13][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 52 | `L2PDE_l1pmpflg[6][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 52 | `L2PDE_l1pmpflg[7][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l1pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[0][0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[10][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[11][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[12][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[13][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[14][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[15][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[1][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[2][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[3][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[4][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[5][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[6][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[7][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[8][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 53 | `L2PDE_l2pmpflg[9][2:0] -> input logic [L2PDE_ENTRY_NUM-1:0][3:0] L2PDE_l2pmpflg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[0][10:5] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[1][1:0] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[1][4:3] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[2][1:0] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[2][5:3] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[3][0] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[3][5:2] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[4][2:1] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[4][5:4] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[5][4:3] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[6][0] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[6][4:3] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[7][1:0] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `L1PDE_entry_ppn[7][4:3] -> input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[0][10:6] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[11][5] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[12][3] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[1][6] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[4][3] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[6][3] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[7][2] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[7][5] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[8][6] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 55 | `L2PDE_entry_ppn[9][6] -> input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 56 | `L1PDE_entry_before_upd_hit[15:8] -> input logic [L1PDE_ENTRY_NUM-1:0] L1PDE_entry_before_upd_hit,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 60 | `L1PDE_cache_hit_ppn[27:11] -> input logic [PPN_WIDTH-1:0] L1PDE_cache_hit_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 61 | `L2PDE_cache_hit_ppn[27:11] -> input logic [PPN_WIDTH-1:0] L2PDE_cache_hit_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 62 | `PDE_cache_fin_ppn[27:11] -> input logic [PPN_WIDTH-1:0] PDE_cache_fin_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 68 | `PDE_xbar_ppn[27:11] -> input logic [PPN_WIDTH-1:0] PDE_xbar_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 75 | `PDE_cache_acc_err_id[2:1] -> input logic [ID_WIDTH-1:0] PDE_cache_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 75 | `PDE_cache_acc_err_id[6:5] -> input logic [ID_WIDTH-1:0] PDE_cache_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:24`

```systemverilog
      22:     input logic                                      ptw_writeback_req_any,
      23:     input logic                                      ptw_writeback_grant_any,
>>    24:     input logic                                      pmp_regs_update,
      25:     input logic                                      pde_cache_clear,
      26:     input logic                                      xbar_pde_ready,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:30`

```systemverilog
      28:     input logic                                      mbuf_cache_upd,
      29:     input logic [PTE_LEVEL-2:0]                      mbuf_cache_upd_lvl,
>>    30:     input logic [PPN_WIDTH-1:0]                      mbuf_cache_upd_ppn,
      31:     input logic [VPN_WIDTH-1:0]                      mbuf_cache_upd_vpn,
      32:     input logic [3:0]                                mbuf_cache_upd_l1pmpflg,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:37`

```systemverilog
      35:     input logic [1:0]                                cp0_priv_mode,
      36:     input logic                                      ptw_req,
>>    37:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd,
      38:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd,
      39:     input logic [L1PDE_ENTRY_NUM-1:0]                plru_L1PDE_ref_num,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:39`

```systemverilog
      37:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd,
      38:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd,
>>    39:     input logic [L1PDE_ENTRY_NUM-1:0]                plru_L1PDE_ref_num,
      40:     input logic [L2PDE_ENTRY_NUM-1:0]                plru_L2PDE_ref_num,
      41:     input logic                                      L1PDE_plru_refill_vld,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:43`

```systemverilog
      41:     input logic                                      L1PDE_plru_refill_vld,
      42:     input logic                                      L2PDE_plru_refill_vld,
>>    43:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld,
      44:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld,
      45:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:44`

```systemverilog
      42:     input logic                                      L2PDE_plru_refill_vld,
      43:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld,
>>    44:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld,
      45:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit,
      46:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:47`

```systemverilog
      45:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit,
      46:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit,
>>    47:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit_idx,
      48:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit_idx,
      49:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_tag_hit,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:51`

```systemverilog
      49:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_tag_hit,
      50:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_tag_hit,
>>    51:     input logic [L1PDE_ENTRY_NUM-1:0][3:0]           L1PDE_l1pmpflg,
      52:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l1pmpflg,
      53:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:52`

```systemverilog
      50:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_tag_hit,
      51:     input logic [L1PDE_ENTRY_NUM-1:0][3:0]           L1PDE_l1pmpflg,
>>    52:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l1pmpflg,
      53:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
      54:     input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:53`

```systemverilog
      51:     input logic [L1PDE_ENTRY_NUM-1:0][3:0]           L1PDE_l1pmpflg,
      52:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l1pmpflg,
>>    53:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
      54:     input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
      55:     input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:54`

```systemverilog
      52:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l1pmpflg,
      53:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
>>    54:     input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
      55:     input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,
      56:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:55`

```systemverilog
      53:     input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
      54:     input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
>>    55:     input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,
      56:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit,
      57:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_before_upd_hit,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:56`

```systemverilog
      54:     input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
      55:     input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,
>>    56:     input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit,
      57:     input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_before_upd_hit,
      58:     input logic                                      L1PDE_entry_hit_vld,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:60`

```systemverilog
      58:     input logic                                      L1PDE_entry_hit_vld,
      59:     input logic                                      L2PDE_entry_hit_vld,
>>    60:     input logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn,
      61:     input logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn,
      62:     input logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:61`

```systemverilog
      59:     input logic                                      L2PDE_entry_hit_vld,
      60:     input logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn,
>>    61:     input logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn,
      62:     input logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn,
      63:     input logic                                      L1PDE_plru_read_hit_vld,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:62`

```systemverilog
      60:     input logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn,
      61:     input logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn,
>>    62:     input logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn,
      63:     input logic                                      L1PDE_plru_read_hit_vld,
      64:     input logic                                      L2PDE_plru_read_hit_vld,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:68`

```systemverilog
      66:     input logic                                      L2PDE_xbar_hit_vld,
      67:     input logic                                      L1PDE_xbar_hit_vld,
>>    68:     input logic [PPN_WIDTH-1:0]                      PDE_xbar_ppn,
      69:     input logic [VPN_WIDTH-1:0]                      PDE_xbar_vpn,
      70:     input logic [TYPE_WIDTH-1:0]                     PDE_xbar_type,
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:75`

```systemverilog
      73:     input logic                                      PDE_cache_acc_err_vld,
      74:     input logic [TYPE_WIDTH-1:0]                     PDE_cache_acc_err_type,
>>    75:     input logic [ID_WIDTH-1:0]                       PDE_cache_acc_err_id,
      76:     input logic                                      PDE_cache_acc_err_grant,
      77:     input logic [VPN_WIDTH-1:0]                      ptw_vpn,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 111 | `pde_past_valid -> logic pde_past_valid;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 113 | `l1_expected_hit_vec[15:8] -> logic [L1PDE_ENTRY_NUM-1:0] l1_expected_hit_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 114 | `l1_deny_vec[15:1] -> logic [L1PDE_ENTRY_NUM-1:0] l1_deny_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:111`

```systemverilog
     109:   int unsigned cp_pde_bus_error_no_update_hits;
     110: 
>>   111:   logic pde_past_valid;
     112:   logic [L1PDE_ENTRY_NUM-1:0] l1_allow_vec;
     113:   logic [L1PDE_ENTRY_NUM-1:0] l1_expected_hit_vec;
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:113`

```systemverilog
     111:   logic pde_past_valid;
     112:   logic [L1PDE_ENTRY_NUM-1:0] l1_allow_vec;
>>   113:   logic [L1PDE_ENTRY_NUM-1:0] l1_expected_hit_vec;
     114:   logic [L1PDE_ENTRY_NUM-1:0] l1_deny_vec;
     115:   logic [L2PDE_ENTRY_NUM-1:0] l2_l1_allow_vec;
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:114`

```systemverilog
     112:   logic [L1PDE_ENTRY_NUM-1:0] l1_allow_vec;
     113:   logic [L1PDE_ENTRY_NUM-1:0] l1_expected_hit_vec;
>>   114:   logic [L1PDE_ENTRY_NUM-1:0] l1_deny_vec;
     115:   logic [L2PDE_ENTRY_NUM-1:0] l2_l1_allow_vec;
     116:   logic [L2PDE_ENTRY_NUM-1:0] l2_l2_allow_vec;
```

### 断言/cover 命中覆盖

说明：这里列出 assertion real success 为 0 或 cover property matches 为 0 的 SVA 对象。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 185 | `cp_pde_abort_update_clear -> cp_pde_abort_update_clear: cover property (@(posedge pde_cache_clk)` | CoverProperty Attempts=219727958, Matches=0, Incomplete=0 | 1 |
| 288 | `a_pde_l1_consecutive_refill_no_reuse_when_invalid -> a_pde_l1_consecutive_refill_no_reuse_when_invalid: assert property (@(posedge pde_cache_clk)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 300 | `cp_pde_l1_consecutive_advance -> cp_pde_l1_consecutive_advance: cover property (@(posedge pde_cache_clk)` | CoverProperty Attempts=219727958, Matches=0, Incomplete=0 | 1 |
| 467 | `a_pde_thd_update_does_not_allocate -> a_pde_thd_update_does_not_allocate: assert property (@(posedge pde_cache_clk)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[10].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[11].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[12].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[13].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[14].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[15].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[8].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 472 | `gen_l1_update_pmp_sva[9].a_pde_l1_update_saves_l1pmpflg -> for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 514 | `a_pde_accerr_pending_type_id_stable -> a_pde_accerr_pending_type_id_stable: assert property (@(posedge pde_cache_clk)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:185`

```systemverilog
     183:   end
     184: 
>>   185:   cp_pde_abort_update_clear: cover property (@(posedge pde_cache_clk)
     186:     disable iff (!cpurst_b)
     187:     tlboper_ptw_abort && mbuf_cache_upd
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:288`

```systemverilog
     286: 
     287:   // PTW-SVA-PDE-UPD-021: while invalid ways remain, consecutive refill cannot reuse the previous way.
>>   288:   a_pde_l1_consecutive_refill_no_reuse_when_invalid: assert property (@(posedge pde_cache_clk)
     289:     disable iff (!cpurst_b || !pde_past_valid)
     290:     mbuf_cache_upd && L1PDE_plru_refill_vld && !(&L1PDE_entry_vld)
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:300`

```systemverilog
     298:     |-> ((L2PDE_entry_upd & $past(L2PDE_entry_upd)) == '0));
     299: 
>>   300:   cp_pde_l1_consecutive_advance: cover property (@(posedge pde_cache_clk)
     301:     disable iff (!cpurst_b || !pde_past_valid)
     302:     mbuf_cache_upd && L1PDE_plru_refill_vld && !(&L1PDE_entry_vld)
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:467`

```systemverilog
     465:     mbuf_cache_upd && mbuf_cache_upd_lvl[1] |-> (mbuf_cache_upd_l2pmpflg == 4'h0));
     466: 
>>   467:   a_pde_thd_update_does_not_allocate: assert property (@(posedge pde_cache_clk)
     468:     disable iff (!cpurst_b)
     469:     mbuf_cache_upd && (mbuf_cache_upd_lvl == '0) |-> (!(|L1PDE_entry_upd) && !(|L2PDE_entry_upd)));
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:472`

```systemverilog
     470: 
     471:   generate
>>   472:     for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva
     473:       a_pde_l1_update_saves_l1pmpflg: assert property (@(posedge pde_cache_clk)
     474:         disable iff (!cpurst_b)
```

`mmu_verification/testbench/top/mmu_pde_cache_sva.sv:514`

```systemverilog
     512: 
     513:   // PTW-SVA-PDE-017: direct accerr pending payload is stable until grant and clears after grant.
>>   514:   a_pde_accerr_pending_type_id_stable: assert property (@(posedge pde_cache_clk)
     515:     disable iff (!cpurst_b || tlboper_ptw_abort)
     516:     PDE_cache_acc_err_vld && !PDE_cache_acc_err_grant
```

## 模块 `mmu_pde_pplru_sva`

源码：`mmu_verification/testbench/top/mmu_pde_pplru_sva.sv`
PTW 子树实例数：`2`；合并后唯一未覆盖代码对象数（phase14）：`6`。

> **🔴 覆盖率更新 (2026-06-17):**
> 本模块的断言/cover 项在本轮未专门针对性增强，以下所有未覆盖项**仍保留**，待后续处理。
> 
### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 13 | `PDE_plru_read_vld[15:8] -> input logic [PDE_ENTRY_NUM-1:0] PDE_plru_read_vld,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 15 | `plru_PDE_ref_num[15:9] -> input logic [PDE_ENTRY_NUM-1:0] plru_PDE_ref_num,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 18 | `plru_num[1:0] -> input logic [PDE_INDEX_WIDTH-1:0] plru_num` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 18 | `plru_num[2] -> input logic [PDE_INDEX_WIDTH-1:0] plru_num` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |

`mmu_verification/testbench/top/mmu_pde_pplru_sva.sv:13`

```systemverilog
      11:     input logic                         forever_cpuclk,
      12:     input logic                         cpurst_b,
>>    13:     input logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_vld,
      14:     input logic                         PDE_plru_refill_vld,
      15:     input logic [PDE_ENTRY_NUM-1:0]     plru_PDE_ref_num,
```

`mmu_verification/testbench/top/mmu_pde_pplru_sva.sv:15`

```systemverilog
      13:     input logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_vld,
      14:     input logic                         PDE_plru_refill_vld,
>>    15:     input logic [PDE_ENTRY_NUM-1:0]     plru_PDE_ref_num,
      16:     input logic                         plru_write_updt,
      17:     input logic [PDE_INDEX_WIDTH-1:0]   write_num,
```

`mmu_verification/testbench/top/mmu_pde_pplru_sva.sv:18`

```systemverilog
      16:     input logic                         plru_write_updt,
      17:     input logic [PDE_INDEX_WIDTH-1:0]   write_num,
>>    18:     input logic [PDE_INDEX_WIDTH-1:0]   plru_num
      19: );
      20: 
```

### 断言/cover 命中覆盖

说明：这里列出 assertion real success 为 0 或 cover property matches 为 0 的 SVA 对象。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 85 | `a_pplru_full_valid_selects_plru_way -> a_pplru_full_valid_selects_plru_way: assert property (@(posedge forever_cpuclk)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 103 | `cp_pplru_full_valid_plru -> cp_pplru_full_valid_plru: cover property (@(posedge forever_cpuclk)` | CoverProperty Attempts=219727958, Matches=0, Incomplete=0 | 1 |

`mmu_verification/testbench/top/mmu_pde_pplru_sva.sv:85`

```systemverilog
      83:   endgenerate
      84: 
>>    85:   a_pplru_full_valid_selects_plru_way: assert property (@(posedge forever_cpuclk)
      86:     disable iff (!cpurst_b)
      87:     plru_write_updt && (&PDE_plru_read_vld)
```

`mmu_verification/testbench/top/mmu_pde_pplru_sva.sv:103`

```systemverilog
     101:   end
     102: 
>>   103:   cp_pplru_full_valid_plru: cover property (@(posedge forever_cpuclk)
     104:     disable iff (!cpurst_b)
     105:     plru_write_updt && (&PDE_plru_read_vld)
```

## 模块 `mmu_ptw_top_sva`

源码：`mmu_verification/testbench/top/mmu_ptw_top_sva.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数：`19`。

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 31 | `ptw_arb_vpn[26] -> input logic [VPN_WIDTH-1:0] ptw_arb_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 32 | `ptw_arb_ref_data_din[37:35] -> input logic [DATA_WIDTH-1:0] ptw_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 33 | `ptw_arb_ref_tag_din[19:16] -> input logic [TAG_WIDTH-1:0] ptw_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 33 | `ptw_arb_ref_tag_din[46] -> input logic [TAG_WIDTH-1:0] ptw_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 41 | `twu_l2tlb_ref_acc_err_type[0][1] -> input logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 41 | `twu_l2tlb_ref_acc_err_type[1][1] -> input logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 41 | `twu_l2tlb_ref_acc_err_type[2][1] -> input logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 41 | `twu_l2tlb_ref_acc_err_type[3][1] -> input logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 45 | `mbuf_bus_error_id[2] -> input logic [ID_WIDTH-1:0] mbuf_bus_error_id,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 48 | `PDE_cache_acc_err_id[2:1] -> input logic [ID_WIDTH-1:0] PDE_cache_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 48 | `PDE_cache_acc_err_id[6:5] -> input logic [ID_WIDTH-1:0] PDE_cache_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 59 | `ptw_l1dtlb_ref_vpn[26] -> input logic [VPN_WIDTH-1:0] ptw_l1dtlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 61 | `ptw_l1dtlb_ref_ppn[23:21] -> input logic [PPN_WIDTH-1:0] ptw_l1dtlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 67 | `ptw_l1itlb_ref_vpn[26] -> input logic [VPN_WIDTH-1:0] ptw_l1itlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 69 | `ptw_l1itlb_ref_ppn[23:21] -> input logic [PPN_WIDTH-1:0] ptw_l1itlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:31`

```systemverilog
      29:     input logic                   arb_ptw_mask,
      30:     input logic                   ptw_arb_req,
>>    31:     input logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
      32:     input logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
      33:     input logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:32`

```systemverilog
      30:     input logic                   ptw_arb_req,
      31:     input logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
>>    32:     input logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
      33:     input logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
      34:     input logic [PGS_WIDTH-1:0]   ptw_arb_ref_pgs,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:33`

```systemverilog
      31:     input logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
      32:     input logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
>>    33:     input logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
      34:     input logic [PGS_WIDTH-1:0]   ptw_arb_ref_pgs,
      35:     input logic [TYPE_WIDTH-1:0]  ptw_arb_ref_type,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:41`

```systemverilog
      39:     input logic                   ref_vld,
      40:     input logic [3:0]             twu_l2tlb_ref_acc_err,
>>    41:     input logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,
      42:     input logic [3:0][ID_WIDTH-1:0]   twu_l2tlb_ref_acc_err_id,
      43:     input logic                   mbuf_bus_error,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:45`

```systemverilog
      43:     input logic                   mbuf_bus_error,
      44:     input logic [TYPE_WIDTH-1:0]  mbuf_bus_error_type,
>>    45:     input logic [ID_WIDTH-1:0]    mbuf_bus_error_id,
      46:     input logic                   PDE_cache_acc_err_vld,
      47:     input logic [TYPE_WIDTH-1:0]  PDE_cache_acc_err_type,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:48`

```systemverilog
      46:     input logic                   PDE_cache_acc_err_vld,
      47:     input logic [TYPE_WIDTH-1:0]  PDE_cache_acc_err_type,
>>    48:     input logic [ID_WIDTH-1:0]    PDE_cache_acc_err_id,
      49:     input logic [5:0]             acc_err_twu_grant,
      50:     input logic                   ptw_l2tlb_ref_acc_err,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:59`

```systemverilog
      57:     input logic                   ptw_l1dtlb_ref_pa_vld,
      58:     input logic                   ptw_l1dtlb_cmplt,
>>    59:     input logic [VPN_WIDTH-1:0]   ptw_l1dtlb_ref_vpn,
      60:     input logic [PGS_WIDTH-1:0]   ptw_l1dtlb_ref_pgs,
      61:     input logic [PPN_WIDTH-1:0]   ptw_l1dtlb_ref_ppn,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:61`

```systemverilog
      59:     input logic [VPN_WIDTH-1:0]   ptw_l1dtlb_ref_vpn,
      60:     input logic [PGS_WIDTH-1:0]   ptw_l1dtlb_ref_pgs,
>>    61:     input logic [PPN_WIDTH-1:0]   ptw_l1dtlb_ref_ppn,
      62:     input logic [FLG_WIDTH-1:0]   ptw_l1dtlb_ref_flg,
      63:     input logic                   ptw_l1dtlb_pgflt,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:67`

```systemverilog
      65:     input logic                   ptw_l1itlb_ref_pa_vld,
      66:     input logic                   ptw_l1itlb_cmplt,
>>    67:     input logic [VPN_WIDTH-1:0]   ptw_l1itlb_ref_vpn,
      68:     input logic [PGS_WIDTH-1:0]   ptw_l1itlb_ref_pgs,
      69:     input logic [PPN_WIDTH-1:0]   ptw_l1itlb_ref_ppn,
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:69`

```systemverilog
      67:     input logic [VPN_WIDTH-1:0]   ptw_l1itlb_ref_vpn,
      68:     input logic [PGS_WIDTH-1:0]   ptw_l1itlb_ref_pgs,
>>    69:     input logic [PPN_WIDTH-1:0]   ptw_l1itlb_ref_ppn,
      70:     input logic [FLG_WIDTH-1:0]   ptw_l1itlb_ref_flg,
      71:     input logic                   ptw_l1itlb_pgflt,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 96 | `ptw_sva_past_valid -> logic ptw_sva_past_valid;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:96`

```systemverilog
      94:   int unsigned cp_pde_accerr_no_dup_hits;
      95:   logic tlboper_ptw_abort_q;
>>    96:   logic ptw_sva_past_valid;
      97: 
      98:   always_ff @(posedge ptw_clk or negedge cpurst_b) begin
```

### 断言/cover 命中覆盖

说明：这里列出 assertion real success 为 0 或 cover property matches 为 0 的 SVA 对象。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 135 | `cp_ptw_req_reselect_under_backpressure -> cp_ptw_req_reselect_under_backpressure: cover property (@(posedge ptw_clk)` | CoverProperty Attempts=219727958, Matches=0, Incomplete=0 | 1 |
| 288 | `a_ptw_pde_accerr_priority_type_id -> a_ptw_pde_accerr_priority_type_id: assert property (@(posedge ptw_clk)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 | 1 |
| 295 | `cp_ptw_pde_accerr_priority -> cp_ptw_pde_accerr_priority: cover property (@(posedge ptw_clk)` | CoverProperty Attempts=219727958, Matches=0, Incomplete=0 | 1 |

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:135`

```systemverilog
     133:   end
     134: 
>>   135:   cp_ptw_req_reselect_under_backpressure: cover property (@(posedge ptw_clk)
     136:     disable iff (!cpurst_b || !ptw_sva_past_valid)
     137:     l2tlb_ptw_req && !ptw_jtlb_ready
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:288`

```systemverilog
     286:     PDE_cache_acc_err_vld |-> (acc_err_twu_grant[5] && !(|acc_err_twu_grant[4:0])));
     287: 
>>   288:   a_ptw_pde_accerr_priority_type_id: assert property (@(posedge ptw_clk)
     289:     disable iff (!cpurst_b)
     290:     PDE_cache_acc_err_vld && (mbuf_bus_error || (|twu_l2tlb_ref_acc_err))
```

`mmu_verification/testbench/top/mmu_ptw_top_sva.sv:295`

```systemverilog
     293:       && (ptw_l2tlb_id == PDE_cache_acc_err_id)));
     294: 
>>   295:   cp_ptw_pde_accerr_priority: cover property (@(posedge ptw_clk)
     296:     disable iff (!cpurst_b)
     297:     PDE_cache_acc_err_vld && (mbuf_bus_error || (|twu_l2tlb_ref_acc_err))
```

## 模块 `mmu_ptw_xbar_sva`

源码：`mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数：`4`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 57 | `default: hash_onehot = 4'b0000;` | 0/1 | 1 |

`mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv:57`

```systemverilog
      55:       2'b10: hash_onehot = 4'b0100;
      56:       2'b11: hash_onehot = 4'b1000;
>>    57:       default: hash_onehot = 4'b0000;
      58:     endcase
      59:   endfunction
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 52 | `case (h)` | default Not Covered | 1 |

`mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv:52`

```systemverilog
      50: 
      51:   function automatic logic [3:0] hash_onehot(input logic [1:0] h);
>>    52:     case (h)
      53:       2'b00: hash_onehot = 4'b0001;
      54:       2'b01: hash_onehot = 4'b0010;
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 20 | `PDE_xbar_ppn[27:11] -> input logic [PPN_WIDTH-1:0] PDE_xbar_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 26 | `xbar_twu_ppn[27:11] -> input logic [PPN_WIDTH-1:0] xbar_twu_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |

`mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv:20`

```systemverilog
      18:     input logic                  L2PDE_xbar_hit_vld,
      19:     input logic                  L1PDE_xbar_hit_vld,
>>    20:     input logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
      21:     input logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
      22:     input logic [TYPE_WIDTH-1:0] PDE_xbar_type,
```

`mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv:26`

```systemverilog
      24:     input logic [3:0]            xbar_twu_req,
      25:     input logic [PTE_LEVEL-2:0]  xbar_twu_hit_level,
>>    26:     input logic [PPN_WIDTH-1:0]  xbar_twu_ppn,
      27:     input logic [VPN_WIDTH-1:0]  xbar_twu_vpn,
      28:     input logic [TYPE_WIDTH-1:0] xbar_twu_type,
```

## 模块 `mmu_sysmap_sva`

源码：`mmu_verification/testbench/top/mmu_sysmap_sva.sv`
PTW 子树实例数：`4`；合并后唯一未覆盖代码对象数：`1`。

### 断言/cover 命中覆盖

说明：这里列出 assertion real success 为 0 或 cover property matches 为 0 的 SVA 对象。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 72 | `sva_sysmap_cross_degrade_2m -> sva_sysmap_cross_degrade_2m: assert property (@(posedge twu_clk)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 x2 | 2 |

`mmu_verification/testbench/top/mmu_sysmap_sva.sv:72`

```systemverilog
      70:     sysmap_cross_1g |=> (csr_refill_pgs == 3'b010));
      71: 
>>    72:   sva_sysmap_cross_degrade_2m: assert property (@(posedge twu_clk)
      73:     disable iff (!cpurst_b || tlboper_ptw_abort)
      74:     sysmap_cross_2m |=> (csr_refill_pgs == 3'b001));
```

## 模块 `mmu_twu_chk_sva`

源码：`mmu_verification/testbench/top/mmu_twu_chk_sva.sv`
PTW 子树实例数：`4`；合并后唯一未覆盖代码对象数：`156`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 104 | `EXPRESSION (flg[0] && (flg[1] \|\| flg[3]))` | 0 1 Not Covered x4 | 4 |
| 104 | `SUB-EXPRESSION (flg[1] \|\| flg[3])` | 0 1 Not Covered x4; 1 0 Not Covered | 4 |

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:104`

```systemverilog
     102: 
     103:   function automatic bit leaf_from_flg(input logic [8:0] flg);
>>   104:     leaf_from_flg = flg[0] && (flg[1] || flg[3]);
     105:   endfunction
     106: 
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 19 | `cp0_mmu_mpp[0] -> input logic [1:0] cp0_mmu_mpp,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT x4 | 4 |
| 26 | `fst_chk_id[6] -> input logic [ID_WIDTH-1:0] fst_chk_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 27 | `fst_chk_data[10:8] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[10] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[13] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[16] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 27 | `fst_chk_data[17] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[18] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[19] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[20:15] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[20:19] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[27:20] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 27 | `fst_chk_data[27:21] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 27 | `fst_chk_data[28] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[29:28] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[37:29] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[39] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[3:1] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[41] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[43] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[45] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[47] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[49:30] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[49] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[4] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 27 | `fst_chk_data[50] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[51] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[53] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[58:30] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[58:55] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[59:29] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[59] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[5:4] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 27 | `fst_chk_data[5] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[60:51] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[61:59] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[61] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 27 | `fst_chk_data[62] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[63:61] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[63:62] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 27 | `fst_chk_data[8] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[9:6] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 27 | `fst_chk_data[9] -> input logic [DATA_WIDTH-1:0] fst_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 28 | `fst_chk_flg[3:1] -> input logic [8:0] fst_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 28 | `fst_chk_flg[4] -> input logic [8:0] fst_chk_flg,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 28 | `fst_chk_flg[7] -> input logic [8:0] fst_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 28 | `fst_chk_flg[8:5] -> input logic [8:0] fst_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 28 | `fst_chk_flg[8:7] -> input logic [8:0] fst_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 28 | `fst_chk_flg[8] -> input logic [8:0] fst_chk_flg,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 30 | `fst_chk_leaf_vld -> input logic fst_chk_leaf_vld,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 31 | `fst_chk_refill_req -> input logic fst_chk_refill_req,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 33 | `fst_chk_wait -> input logic fst_chk_wait,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 40 | `scd_chk_vpn[15] -> input logic [VPN_WIDTH-1:0] scd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 40 | `scd_chk_vpn[20:19] -> input logic [VPN_WIDTH-1:0] scd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 40 | `scd_chk_vpn[23] -> input logic [VPN_WIDTH-1:0] scd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 40 | `scd_chk_vpn[26:21] -> input logic [VPN_WIDTH-1:0] scd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 40 | `scd_chk_vpn[26:25] -> input logic [VPN_WIDTH-1:0] scd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 40 | `scd_chk_vpn[26] -> input logic [VPN_WIDTH-1:0] scd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 42 | `scd_chk_id[6] -> input logic [ID_WIDTH-1:0] scd_chk_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[0] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[16:15] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[16] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[18:15] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[18] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[19:16] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[20:19] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[20] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[22] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[23:21] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[23] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 43 | `scd_chk_data[24] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[25:24] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[25] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[28:25] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[29] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[31:30] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[37:27] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[38] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[3:0] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[3] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[42:39] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[43] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[45:32] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[46] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[48:26] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[49] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[4] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[58:44] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[58:50] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[59:47] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[5:4] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x3 | 3 |
| 43 | `scd_chk_data[60] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 43 | `scd_chk_data[62:59] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[63:27] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[63:61] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[63] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 43 | `scd_chk_data[7:5] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `scd_chk_data[8] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 3 |
| 43 | `scd_chk_data[9:8] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 43 | `scd_chk_data[9] -> input logic [DATA_WIDTH-1:0] scd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 44 | `scd_chk_flg[0] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 44 | `scd_chk_flg[3:0] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 44 | `scd_chk_flg[3] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 44 | `scd_chk_flg[4] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 44 | `scd_chk_flg[6:5] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 44 | `scd_chk_flg[7] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 3 |
| 44 | `scd_chk_flg[8:7] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 44 | `scd_chk_flg[8] -> input logic [8:0] scd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 45 | `scd_chk_page_flt -> input logic scd_chk_page_flt,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT x2 | 2 |
| 46 | `scd_chk_leaf_vld -> input logic scd_chk_leaf_vld,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 49 | `scd_chk_wait -> input logic scd_chk_wait,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 56 | `thd_chk_vpn[21] -> input logic [VPN_WIDTH-1:0] thd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 56 | `thd_chk_vpn[23] -> input logic [VPN_WIDTH-1:0] thd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 56 | `thd_chk_vpn[24] -> input logic [VPN_WIDTH-1:0] thd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 56 | `thd_chk_vpn[26:21] -> input logic [VPN_WIDTH-1:0] thd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 56 | `thd_chk_vpn[26:25] -> input logic [VPN_WIDTH-1:0] thd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 56 | `thd_chk_vpn[26] -> input logic [VPN_WIDTH-1:0] thd_chk_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 58 | `thd_chk_id[6] -> input logic [ID_WIDTH-1:0] thd_chk_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 59 | `thd_chk_data[0] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x3 | 3 |
| 59 | `thd_chk_data[25] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[29] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[31:28] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x3 | 3 |
| 59 | `thd_chk_data[33:32] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 59 | `thd_chk_data[37:34] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x3 | 3 |
| 59 | `thd_chk_data[38:34] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[38] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x3 | 3 |
| 59 | `thd_chk_data[41:40] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x3; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 4 |
| 59 | `thd_chk_data[45:43] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 59 | `thd_chk_data[48:46] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[4] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 59 | `thd_chk_data[53:49] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 59 | `thd_chk_data[54:43] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[54] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[58:43] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 59 | `thd_chk_data[58:55] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 59 | `thd_chk_data[5:4] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 59 | `thd_chk_data[5] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x3 | 3 |
| 59 | `thd_chk_data[60:59] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x4 | 4 |
| 59 | `thd_chk_data[62] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 59 | `thd_chk_data[63:62] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 3 |
| 59 | `thd_chk_data[63] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[9:6] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[9:7] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 59 | `thd_chk_data[9:8] -> input logic [DATA_WIDTH-1:0] thd_chk_data,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 60 | `thd_chk_flg[0] -> input logic [8:0] thd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x3 | 3 |
| 60 | `thd_chk_flg[4] -> input logic [8:0] thd_chk_flg,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 60 | `thd_chk_flg[8:4] -> input logic [8:0] thd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 60 | `thd_chk_flg[8:6] -> input logic [8:0] thd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 60 | `thd_chk_flg[8:7] -> input logic [8:0] thd_chk_flg,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 69 | `scd_pmp_wait -> input logic scd_pmp_wait,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 71 | `refill_fst_chk_grant -> input logic refill_fst_chk_grant,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 81 | `twu_data_ready[1] -> input logic [2:0] twu_data_ready` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 81 | `twu_data_ready[2] -> input logic [2:0] twu_data_ready` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:19`

```systemverilog
      17:     input logic                  cp0_mmu_mxr,
      18:     input logic                  cp0_mmu_sum,
>>    19:     input logic [1:0]            cp0_mmu_mpp,
      20:     input logic                  cp0_mmu_mprv,
      21:     input logic [1:0]            cp0_yy_priv_mode,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:26`

```systemverilog
      24:     input logic [VPN_WIDTH-1:0]  fst_chk_vpn,
      25:     input logic [TYPE_WIDTH-1:0] fst_chk_type,
>>    26:     input logic [ID_WIDTH-1:0]   fst_chk_id,
      27:     input logic [DATA_WIDTH-1:0] fst_chk_data,
      28:     input logic [8:0]            fst_chk_flg,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:27`

```systemverilog
      25:     input logic [TYPE_WIDTH-1:0] fst_chk_type,
      26:     input logic [ID_WIDTH-1:0]   fst_chk_id,
>>    27:     input logic [DATA_WIDTH-1:0] fst_chk_data,
      28:     input logic [8:0]            fst_chk_flg,
      29:     input logic                  fst_chk_page_flt,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:28`

```systemverilog
      26:     input logic [ID_WIDTH-1:0]   fst_chk_id,
      27:     input logic [DATA_WIDTH-1:0] fst_chk_data,
>>    28:     input logic [8:0]            fst_chk_flg,
      29:     input logic                  fst_chk_page_flt,
      30:     input logic                  fst_chk_leaf_vld,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:30`

```systemverilog
      28:     input logic [8:0]            fst_chk_flg,
      29:     input logic                  fst_chk_page_flt,
>>    30:     input logic                  fst_chk_leaf_vld,
      31:     input logic                  fst_chk_refill_req,
      32:     input logic                  fst_chk_csr_req,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:31`

```systemverilog
      29:     input logic                  fst_chk_page_flt,
      30:     input logic                  fst_chk_leaf_vld,
>>    31:     input logic                  fst_chk_refill_req,
      32:     input logic                  fst_chk_csr_req,
      33:     input logic                  fst_chk_wait,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:33`

```systemverilog
      31:     input logic                  fst_chk_refill_req,
      32:     input logic                  fst_chk_csr_req,
>>    33:     input logic                  fst_chk_wait,
      34:     input logic                  fst_chk_fetch_type,
      35:     input logic                  fst_chk_load_type,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:40`

```systemverilog
      38:     input logic                  fst_chk_cp0_supv_mode,
      39:     input logic                  scd_chk_vld,
>>    40:     input logic [VPN_WIDTH-1:0]  scd_chk_vpn,
      41:     input logic [TYPE_WIDTH-1:0] scd_chk_type,
      42:     input logic [ID_WIDTH-1:0]   scd_chk_id,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:42`

```systemverilog
      40:     input logic [VPN_WIDTH-1:0]  scd_chk_vpn,
      41:     input logic [TYPE_WIDTH-1:0] scd_chk_type,
>>    42:     input logic [ID_WIDTH-1:0]   scd_chk_id,
      43:     input logic [DATA_WIDTH-1:0] scd_chk_data,
      44:     input logic [8:0]            scd_chk_flg,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:43`

```systemverilog
      41:     input logic [TYPE_WIDTH-1:0] scd_chk_type,
      42:     input logic [ID_WIDTH-1:0]   scd_chk_id,
>>    43:     input logic [DATA_WIDTH-1:0] scd_chk_data,
      44:     input logic [8:0]            scd_chk_flg,
      45:     input logic                  scd_chk_page_flt,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:44`

```systemverilog
      42:     input logic [ID_WIDTH-1:0]   scd_chk_id,
      43:     input logic [DATA_WIDTH-1:0] scd_chk_data,
>>    44:     input logic [8:0]            scd_chk_flg,
      45:     input logic                  scd_chk_page_flt,
      46:     input logic                  scd_chk_leaf_vld,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:45`

```systemverilog
      43:     input logic [DATA_WIDTH-1:0] scd_chk_data,
      44:     input logic [8:0]            scd_chk_flg,
>>    45:     input logic                  scd_chk_page_flt,
      46:     input logic                  scd_chk_leaf_vld,
      47:     input logic                  scd_chk_refill_req,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:46`

```systemverilog
      44:     input logic [8:0]            scd_chk_flg,
      45:     input logic                  scd_chk_page_flt,
>>    46:     input logic                  scd_chk_leaf_vld,
      47:     input logic                  scd_chk_refill_req,
      48:     input logic                  scd_chk_csr_req,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:49`

```systemverilog
      47:     input logic                  scd_chk_refill_req,
      48:     input logic                  scd_chk_csr_req,
>>    49:     input logic                  scd_chk_wait,
      50:     input logic                  scd_chk_fetch_type,
      51:     input logic                  scd_chk_load_type,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:56`

```systemverilog
      54:     input logic                  scd_chk_cp0_supv_mode,
      55:     input logic                  thd_chk_vld,
>>    56:     input logic [VPN_WIDTH-1:0]  thd_chk_vpn,
      57:     input logic [TYPE_WIDTH-1:0] thd_chk_type,
      58:     input logic [ID_WIDTH-1:0]   thd_chk_id,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:58`

```systemverilog
      56:     input logic [VPN_WIDTH-1:0]  thd_chk_vpn,
      57:     input logic [TYPE_WIDTH-1:0] thd_chk_type,
>>    58:     input logic [ID_WIDTH-1:0]   thd_chk_id,
      59:     input logic [DATA_WIDTH-1:0] thd_chk_data,
      60:     input logic [8:0]            thd_chk_flg,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:59`

```systemverilog
      57:     input logic [TYPE_WIDTH-1:0] thd_chk_type,
      58:     input logic [ID_WIDTH-1:0]   thd_chk_id,
>>    59:     input logic [DATA_WIDTH-1:0] thd_chk_data,
      60:     input logic [8:0]            thd_chk_flg,
      61:     input logic                  thd_chk_page_flt,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:60`

```systemverilog
      58:     input logic [ID_WIDTH-1:0]   thd_chk_id,
      59:     input logic [DATA_WIDTH-1:0] thd_chk_data,
>>    60:     input logic [8:0]            thd_chk_flg,
      61:     input logic                  thd_chk_page_flt,
      62:     input logic                  thd_chk_refill_req,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:69`

```systemverilog
      67:     input logic                  thd_chk_cp0_user_mode,
      68:     input logic                  thd_chk_cp0_supv_mode,
>>    69:     input logic                  scd_pmp_wait,
      70:     input logic                  thd_pmp_wait,
      71:     input logic                  refill_fst_chk_grant,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:71`

```systemverilog
      69:     input logic                  scd_pmp_wait,
      70:     input logic                  thd_pmp_wait,
>>    71:     input logic                  refill_fst_chk_grant,
      72:     input logic                  refill_scd_chk_grant,
      73:     input logic                  refill_thd_chk_grant,
```

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:81`

```systemverilog
      79:     input logic                  twu_l2tlb_ref_pgflt,
      80:     input logic                  twu_arb_ref_req,
>>    81:     input logic [2:0]            twu_data_ready
      82: );
      83: 
```

### 断言/cover 命中覆盖

说明：这里列出 assertion real success 为 0 或 cover property matches 为 0 的 SVA 对象。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 234 | `cp_chk_huge_align -> cp_chk_huge_align: cover property (@(posedge twu_clk)` | CoverProperty Attempts=219727958, Matches=0, Incomplete=0 x3 | 3 |

`mmu_verification/testbench/top/mmu_twu_chk_sva.sv:234`

```systemverilog
     232:     and (scd_chk_vld && scd_chk_leaf_vld && huge2m_misaligned(scd_chk_data) |-> (scd_chk_page_flt && !scd_chk_refill_req && !scd_chk_csr_req)));
     233: 
>>   234:   cp_chk_huge_align: cover property (@(posedge twu_clk)
     235:     disable iff (!cpurst_b || tlboper_ptw_abort)
     236:     (fst_chk_vld && fst_chk_leaf_vld && huge1g_misaligned(fst_chk_data))
```

## 模块 `mmu_twu_sva`

源码：`mmu_verification/testbench/top/mmu_twu_sva.sv`
PTW 子树实例数：`4`；合并后唯一未覆盖代码对象数：`1`。

### 断言/cover 命中覆盖

说明：这里列出 assertion real success 为 0 或 cover property matches 为 0 的 SVA 对象。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 34 | `a_twu_2m_cross_data -> a_twu_2m_cross_data: assert property (@(posedge twu_clk) disable iff (!cpurst_b)` | Assertion Attempts=219727958, RealSuccesses=0, Failures=0, Incomplete=0 x4 | 4 |

`mmu_verification/testbench/top/mmu_twu_sva.sv:34`

```systemverilog
      32: 
      33:   // R19: 2 MB CSR cross must shift-update csr_data_flop.
>>    34:   a_twu_2m_cross_data: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
      35:     (twu_crs2_2m && twu_csr_cross) |=> (csr_data_flop != $past(csr_data_flop)));
      36: 
```

## 模块 `one_to_four_xbar`

源码：`mmu/rtl/one_to_four_xbar.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数：`2`。

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 38 | `PDE_xbar_ppn[27:11] -> input logic [PPN_WIDTH-1:0] PDE_xbar_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 48 | `xbar_twu_ppn[27:11] -> output logic [PPN_WIDTH-1:0] xbar_twu_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |

`mmu/rtl/one_to_four_xbar.sv:38`

```systemverilog
      36:     input  logic                  L2PDE_xbar_hit_vld,
      37:     input  logic                  L1PDE_xbar_hit_vld,
>>    38:     input  logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
      39:     input  logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
      40:     input  logic [TYPE_WIDTH-1:0] PDE_xbar_type,
```

`mmu/rtl/one_to_four_xbar.sv:48`

```systemverilog
      46:     output logic [3:0]            xbar_twu_req,
      47:     output logic [PTE_LEVEL-2:0]  xbar_twu_hit_level,
>>    48:     output logic [PPN_WIDTH-1:0]  xbar_twu_ppn,
      49:     output logic [VPN_WIDTH-1:0]  xbar_twu_vpn,
      50:     output logic [TYPE_WIDTH-1:0] xbar_twu_type,
```

## 模块 `pplru`

源码：`mmu/rtl/pplru.sv`
PTW 子树实例数：`2`；合并后唯一未覆盖代码对象数（phase14）：`22`。

> **🟢 覆盖率更新 (2026-06-17):**
> - pplru(16-entry, L2PDE用): `l2pde_pde_single` 中 TOGGLE=100%（phase14 中 93.51%）
> - pplru(8-entry, L1PDE用): `l1pde_single` 中 TOGGLE=98.84%（phase14 中 93.51%）
> COND 保持在 87.50%（无变化），BRANCH 保持在 91.67%。
> 以下未覆盖项中 toggle 相关**基本已覆盖**，条件/分支/行覆盖项仍保留。
> 
### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 68 | `write_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};` | 0/1 x2 | 2 |

`mmu/rtl/pplru.sv:68`

```systemverilog
      66: 
      67:     if((!invalid_entry_found) && (plru_num[PDE_INDEX_WIDTH-1:0] >= PDE_ENTRY_NUM))
>>    68:         write_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
      69: end
      70: 
```

### 隐式 else / 缺失分支

说明：这里列出工具推导出的未覆盖 else/默认路径，常见于 if/else-if 链或 case 的未命中分支。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 98 | `MISSING_ELSE after previous statement` | 0 Not Covered x2 | 2 |

`mmu/rtl/pplru.sv:98`

```systemverilog
      96: 
      97:     if(PDE_ENTRY_NUM > 8)
>>    98:         hit_num_index[PDE_INDEX_WIDTH-1:0] = 8;
      99: 
     100:     for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 67 | `EXPRESSION (((!invalid_entry_found)) && (plru_num[(PDE_INDEX_WIDTH - 1):0] >= PDE_ENTRY_NUM))` | 0 1 Not Covered x2; 1 0 Not Covered; 1 1 Not Covered x2 | 2 |

`mmu/rtl/pplru.sv:67`

```systemverilog
      65:     end
      66: 
>>    67:     if((!invalid_entry_found) && (plru_num[PDE_INDEX_WIDTH-1:0] >= PDE_ENTRY_NUM))
      68:         write_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
      69: end
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 67 | `if((!invalid_entry_found) && (plru_num[PDE_INDEX_WIDTH-1:0] >= PDE_ENTRY_NUM))` | 1 Not Covered x2 | 2 |
| 97 | `if(PDE_ENTRY_NUM > 8)` | 0 Not Covered x2 | 2 |

`mmu/rtl/pplru.sv:67`

```systemverilog
      65:     end
      66: 
>>    67:     if((!invalid_entry_found) && (plru_num[PDE_INDEX_WIDTH-1:0] >= PDE_ENTRY_NUM))
      68:         write_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
      69: end
```

`mmu/rtl/pplru.sv:97`

```systemverilog
      95:     hit_num_index[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
      96: 
>>    97:     if(PDE_ENTRY_NUM > 8)
      98:         hit_num_index[PDE_INDEX_WIDTH-1:0] = 8;
      99: 
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 8 | `PDE_plru_read_vld[15:8] -> input logic [PDE_ENTRY_NUM-1:0] PDE_plru_read_vld,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 13 | `plru_PDE_ref_num[15:9] -> output logic [PDE_ENTRY_NUM-1:0] plru_PDE_ref_num` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |

`mmu/rtl/pplru.sv:8`

```systemverilog
       6:     input  logic                         cp0_mmu_icg_en,
       7:     input  logic                         cpurst_b,
>>     8:     input  logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_vld,
       9:     input  logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_hit,
      10:     input  logic                         PDE_plru_read_hit_vld,
```

`mmu/rtl/pplru.sv:13`

```systemverilog
      11:     input  logic                         PDE_plru_refill_vld,
      12: 
>>    13:     output logic [PDE_ENTRY_NUM-1:0]     plru_PDE_ref_num
      14: );
      15: 
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 24 | `invalid_entry_found -> logic invalid_entry_found;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=Yes, 0->1=No | 2 |
| 26 | `vld_entry_num[15:8] -> logic [PDE_ENTRY_NUM-1:0] vld_entry_num;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 27 | `refill_num_onehot[15:9] -> logic [PDE_ENTRY_NUM-1:0] refill_num_onehot;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 32 | `plru_num[1:0] -> logic [PDE_INDEX_WIDTH-1:0] plru_num;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 32 | `plru_num[2] -> logic [PDE_INDEX_WIDTH-1:0] plru_num;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 33 | `plru_bits[11] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 33 | `plru_bits[14:12] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 33 | `plru_bits[2] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 33 | `plru_bits[5] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 33 | `plru_bits[6] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 34 | `plru_bits_next[11] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits_next;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 34 | `plru_bits_next[14:12] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits_next;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 34 | `plru_bits_next[2] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits_next;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 34 | `plru_bits_next[5] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits_next;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 34 | `plru_bits_next[6] -> logic [PDE_PLRU_NODE_NUM-1:0] plru_bits_next;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/pplru.sv:24`

```systemverilog
      22: logic                             plru_write_updt;
      23: logic                             plru_read_updt;
>>    24: logic                             invalid_entry_found;
      25: logic                             hit_num_onehot_vld;
      26: logic [PDE_ENTRY_NUM-1:0]         vld_entry_num;
```

`mmu/rtl/pplru.sv:26`

```systemverilog
      24: logic                             invalid_entry_found;
      25: logic                             hit_num_onehot_vld;
>>    26: logic [PDE_ENTRY_NUM-1:0]         vld_entry_num;
      27: logic [PDE_ENTRY_NUM-1:0]         refill_num_onehot;
      28: logic [PDE_ENTRY_NUM-1:0]         hit_num_onehot;
```

`mmu/rtl/pplru.sv:27`

```systemverilog
      25: logic                             hit_num_onehot_vld;
      26: logic [PDE_ENTRY_NUM-1:0]         vld_entry_num;
>>    27: logic [PDE_ENTRY_NUM-1:0]         refill_num_onehot;
      28: logic [PDE_ENTRY_NUM-1:0]         hit_num_onehot;
      29: logic [PDE_INDEX_WIDTH-1:0]       write_num;
```

`mmu/rtl/pplru.sv:32`

```systemverilog
      30: logic [PDE_INDEX_WIDTH-1:0]       hit_num_index;
      31: logic [PDE_INDEX_WIDTH-1:0]       hit_num_flop;
>>    32: logic [PDE_INDEX_WIDTH-1:0]       plru_num;
      33: logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits;
      34: logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits_next;
```

`mmu/rtl/pplru.sv:33`

```systemverilog
      31: logic [PDE_INDEX_WIDTH-1:0]       hit_num_flop;
      32: logic [PDE_INDEX_WIDTH-1:0]       plru_num;
>>    33: logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits;
      34: logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits_next;
      35: 
```

`mmu/rtl/pplru.sv:34`

```systemverilog
      32: logic [PDE_INDEX_WIDTH-1:0]       plru_num;
      33: logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits;
>>    34: logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits_next;
      35: 
      36: //==========================================================
```

## 模块 `ptw`

源码：`mmu/rtl/ptw.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数：`202`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 1238 | `$display("[%0t][PTW LSU REQ] addr=0x%010h id=0x%0h size=%0b grant=%0b satp_base=0x%07h",` | 0/1 | 1 |

`mmu/rtl/ptw.sv:1238`

```systemverilog
    1236:                || (mmu_lsu_data_req_addr != ptw_lsu_addr_dbg_q)
    1237:                || (mmu_lsu_data_req_id != ptw_lsu_id_dbg_q))) begin
>>  1238: 			$display("[%0t][PTW LSU REQ] addr=0x%010h id=0x%0h size=%0b grant=%0b satp_base=0x%07h",
    1239: 			         $time, mmu_lsu_data_req_addr, mmu_lsu_data_req_id, mmu_lsu_data_req_size,
    1240:                      lsu_mmu_data_req_grant, regs_ptw_satp_ppn);
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 892 | `EXPRESSION (pgflt_vld & ((!acc_err_vld)))` | 1 0 Not Covered | 1 |
| 899 | `EXPRESSION (((!twu_l2tlb_ref_pgflt[0])) & ((!twu_l2tlb_ref_pgflt[1])) & ((!twu_l2tlb_ref_pgflt[2])) & twu_l2tlb_ref_pgflt[3] & pgflt_grant)` | 0 1 1 1 1 Not Covered; 1 0 1 1 1 Not Covered; 1 1 0 1 1 Not Covered | 1 |
| 900 | `EXPRESSION (((!twu_l2tlb_ref_pgflt[0])) & ((!twu_l2tlb_ref_pgflt[1])) & twu_l2tlb_ref_pgflt[2] & pgflt_grant)` | 0 1 1 1 Not Covered; 1 0 1 1 Not Covered | 1 |
| 901 | `EXPRESSION (((!twu_l2tlb_ref_pgflt[0])) & twu_l2tlb_ref_pgflt[1] & pgflt_grant)` | 0 1 1 Not Covered | 1 |
| 947 | `EXPRESSION (((!mbuf_bus_error)) & ((!PDE_cache_acc_err_vld)) & ((!twu_l2tlb_ref_acc_err[0])) & twu_l2tlb_ref_acc_err[1] & acc_err_grant)` | 0 1 1 1 1 Not Covered; 1 0 1 1 1 Not Covered; 1 1 0 1 1 Not Covered; 1 1 1 1 0 Not Covered | 1 |
| 948 | `EXPRESSION (((!mbuf_bus_error)) & ((!PDE_cache_acc_err_vld)) & twu_l2tlb_ref_acc_err[0] & acc_err_grant)` | 0 1 1 1 Not Covered; 1 0 1 1 Not Covered; 1 1 1 0 Not Covered | 1 |
| 949 | `EXPRESSION (((!PDE_cache_acc_err_vld)) & mbuf_bus_error & acc_err_grant)` | 0 1 1 Not Covered | 1 |
| 950 | `EXPRESSION (PDE_cache_acc_err_vld & acc_err_grant)` | 1 0 Not Covered | 1 |
| 1207 | `EXPRESSION (l2tlb_miss & ((!l2tlb_miss_cnt)))` | 1 0 Not Covered | 1 |

`mmu/rtl/ptw.sv:892`

```systemverilog
     890: 
     891: assign acc_err_grant = acc_err_vld;
>>   892: assign pgflt_grant = pgflt_vld & (!acc_err_vld);
     893: assign ref_grant = ref_vld & (!acc_err_vld) & (!pgflt_vld);
     894: 
```

`mmu/rtl/ptw.sv:899`

```systemverilog
     897: //                page fault arbiter
     898: //==============================================================================
>>   899: assign twu_pgflt_sel[3] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & (!twu_l2tlb_ref_pgflt[2]) & (twu_l2tlb_ref_pgflt[3]) & pgflt_grant;
     900: assign twu_pgflt_sel[2] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & twu_l2tlb_ref_pgflt[2] & pgflt_grant;
     901: assign twu_pgflt_sel[1] = (!twu_l2tlb_ref_pgflt[0]) & twu_l2tlb_ref_pgflt[1] & pgflt_grant;
```

`mmu/rtl/ptw.sv:900`

```systemverilog
     898: //==============================================================================
     899: assign twu_pgflt_sel[3] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & (!twu_l2tlb_ref_pgflt[2]) & (twu_l2tlb_ref_pgflt[3]) & pgflt_grant;
>>   900: assign twu_pgflt_sel[2] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & twu_l2tlb_ref_pgflt[2] & pgflt_grant;
     901: assign twu_pgflt_sel[1] = (!twu_l2tlb_ref_pgflt[0]) & twu_l2tlb_ref_pgflt[1] & pgflt_grant;
     902: assign twu_pgflt_sel[0] = twu_l2tlb_ref_pgflt[0] & pgflt_grant;
```

`mmu/rtl/ptw.sv:901`

```systemverilog
     899: assign twu_pgflt_sel[3] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & (!twu_l2tlb_ref_pgflt[2]) & (twu_l2tlb_ref_pgflt[3]) & pgflt_grant;
     900: assign twu_pgflt_sel[2] = (!twu_l2tlb_ref_pgflt[0]) & (!twu_l2tlb_ref_pgflt[1]) & twu_l2tlb_ref_pgflt[2] & pgflt_grant;
>>   901: assign twu_pgflt_sel[1] = (!twu_l2tlb_ref_pgflt[0]) & twu_l2tlb_ref_pgflt[1] & pgflt_grant;
     902: assign twu_pgflt_sel[0] = twu_l2tlb_ref_pgflt[0] & pgflt_grant;
     903: 
```

`mmu/rtl/ptw.sv:947`

```systemverilog
     945: assign twu_acc_err_sel[3] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & (!twu_l2tlb_ref_acc_err[0]) & (!twu_l2tlb_ref_acc_err[1]) & (!twu_l2tlb_ref_acc_err[2]) & (twu_l2tlb_ref_acc_err[3]) & acc_err_grant;
     946: assign twu_acc_err_sel[2] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & (!twu_l2tlb_ref_acc_err[0]) & (!twu_l2tlb_ref_acc_err[1]) & twu_l2tlb_ref_acc_err[2] & acc_err_grant;
>>   947: assign twu_acc_err_sel[1] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & (!twu_l2tlb_ref_acc_err[0]) & twu_l2tlb_ref_acc_err[1] & acc_err_grant;
     948: assign twu_acc_err_sel[0] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & twu_l2tlb_ref_acc_err[0] & acc_err_grant;
     949: assign twu_acc_err_sel[4] = (!PDE_cache_acc_err_vld) & (mbuf_bus_error) & acc_err_grant;
```

`mmu/rtl/ptw.sv:948`

```systemverilog
     946: assign twu_acc_err_sel[2] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & (!twu_l2tlb_ref_acc_err[0]) & (!twu_l2tlb_ref_acc_err[1]) & twu_l2tlb_ref_acc_err[2] & acc_err_grant;
     947: assign twu_acc_err_sel[1] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & (!twu_l2tlb_ref_acc_err[0]) & twu_l2tlb_ref_acc_err[1] & acc_err_grant;
>>   948: assign twu_acc_err_sel[0] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & twu_l2tlb_ref_acc_err[0] & acc_err_grant;
     949: assign twu_acc_err_sel[4] = (!PDE_cache_acc_err_vld) & (mbuf_bus_error) & acc_err_grant;
     950: assign twu_acc_err_sel[5] = PDE_cache_acc_err_vld & acc_err_grant;
```

`mmu/rtl/ptw.sv:949`

```systemverilog
     947: assign twu_acc_err_sel[1] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & (!twu_l2tlb_ref_acc_err[0]) & twu_l2tlb_ref_acc_err[1] & acc_err_grant;
     948: assign twu_acc_err_sel[0] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & twu_l2tlb_ref_acc_err[0] & acc_err_grant;
>>   949: assign twu_acc_err_sel[4] = (!PDE_cache_acc_err_vld) & (mbuf_bus_error) & acc_err_grant;
     950: assign twu_acc_err_sel[5] = PDE_cache_acc_err_vld & acc_err_grant;
     951: assign acc_err_twu_grant[5:0] = twu_acc_err_sel[5:0];
```

`mmu/rtl/ptw.sv:950`

```systemverilog
     948: assign twu_acc_err_sel[0] = (!mbuf_bus_error) & (!PDE_cache_acc_err_vld) & twu_l2tlb_ref_acc_err[0] & acc_err_grant;
     949: assign twu_acc_err_sel[4] = (!PDE_cache_acc_err_vld) & (mbuf_bus_error) & acc_err_grant;
>>   950: assign twu_acc_err_sel[5] = PDE_cache_acc_err_vld & acc_err_grant;
     951: assign acc_err_twu_grant[5:0] = twu_acc_err_sel[5:0];
     952: 
```

`mmu/rtl/ptw.sv:1207`

```systemverilog
    1205:     else if(l2tlb_miss_cnt)
    1206:         l2tlb_miss <= 1'b1;
>>  1207:     else if(l2tlb_miss & (!l2tlb_miss_cnt))
    1208:         l2tlb_miss <= 1'b0;
    1209: end
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 1228 | `if(!cpurst_b) begin` | 0 1 - Not Covered | 1 |

`mmu/rtl/ptw.sv:1228`

```systemverilog
    1226: // can be checked while req waits for grant.
    1227: always_ff @(posedge ptw_clk or negedge cpurst_b) begin
>>  1228: 	if(!cpurst_b) begin
    1229: 		ptw_lsu_req_dbg_q  <= 1'b0;
    1230: 		ptw_lsu_addr_dbg_q <= {PADDR_WIDTH{1'b0}};
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 34 | `cp0_mmu_mpp[0] -> input logic [1:0] cp0_mmu_mpp,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 42 | `regs_ptw_cur_asid[15:5] -> input logic [ASID_WIDTH-1:0] regs_ptw_cur_asid,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 43 | `regs_ptw_satp_ppn[27:7] -> input logic [PPN_WIDTH-1:0] regs_ptw_satp_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 49 | `sysmap_mmu_flg3[1:0] -> input logic [4:0] sysmap_mmu_flg3,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 51 | `sysmap_mmu_flg5[1:0] -> input logic [4:0] sysmap_mmu_flg5,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 52 | `sysmap_mmu_flg6[0] -> input logic [4:0] sysmap_mmu_flg6,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 52 | `sysmap_mmu_flg6[1] -> input logic [4:0] sysmap_mmu_flg6,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 53 | `sysmap_mmu_flg7[1:0] -> input logic [4:0] sysmap_mmu_flg7,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 53 | `sysmap_mmu_flg7[3:2] -> input logic [4:0] sysmap_mmu_flg7,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 53 | `sysmap_mmu_flg7[4] -> input logic [4:0] sysmap_mmu_flg7,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 54 | `sysmap_mmu_flg8[1:0] -> input logic [4:0] sysmap_mmu_flg8,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 55 | `sysmap_mmu_flg9[0] -> input logic [4:0] sysmap_mmu_flg9,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 55 | `sysmap_mmu_flg9[1] -> input logic [4:0] sysmap_mmu_flg9,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 56 | `sysmap_mmu_flg10[0] -> input logic [4:0] sysmap_mmu_flg10,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 56 | `sysmap_mmu_flg10[3:1] -> input logic [4:0] sysmap_mmu_flg10,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 56 | `sysmap_mmu_flg10[4] -> input logic [4:0] sysmap_mmu_flg10,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 57 | `sysmap_mmu_flg11[0] -> input logic [4:0] sysmap_mmu_flg11,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 58 | `sysmap_mmu_flg12[0] -> input logic [4:0] sysmap_mmu_flg12,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 58 | `sysmap_mmu_flg12[1] -> input logic [4:0] sysmap_mmu_flg12,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 59 | `sysmap_mmu_flg13[0] -> input logic [4:0] sysmap_mmu_flg13,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 59 | `sysmap_mmu_flg13[1] -> input logic [4:0] sysmap_mmu_flg13,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 60 | `sysmap_mmu_flg14[0] -> input logic [4:0] sysmap_mmu_flg14,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 61 | `sysmap_mmu_flg15[0] -> input logic [4:0] sysmap_mmu_flg15,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 63 | `sysmap_mmu_hit3[7:2] -> input logic [7:0] sysmap_mmu_hit3,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 65 | `sysmap_mmu_hit5[7:2] -> input logic [7:0] sysmap_mmu_hit5,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 66 | `sysmap_mmu_hit6[3:2] -> input logic [7:0] sysmap_mmu_hit6,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 66 | `sysmap_mmu_hit6[6:4] -> input logic [7:0] sysmap_mmu_hit6,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 66 | `sysmap_mmu_hit6[7] -> input logic [7:0] sysmap_mmu_hit6,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 67 | `sysmap_mmu_hit7[0] -> input logic [7:0] sysmap_mmu_hit7,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 67 | `sysmap_mmu_hit7[1] -> input logic [7:0] sysmap_mmu_hit7,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 67 | `sysmap_mmu_hit7[7:2] -> input logic [7:0] sysmap_mmu_hit7,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 68 | `sysmap_mmu_hit8[7:2] -> input logic [7:0] sysmap_mmu_hit8,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 69 | `sysmap_mmu_hit9[3:2] -> input logic [7:0] sysmap_mmu_hit9,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 69 | `sysmap_mmu_hit9[6:4] -> input logic [7:0] sysmap_mmu_hit9,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 69 | `sysmap_mmu_hit9[7] -> input logic [7:0] sysmap_mmu_hit9,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 70 | `sysmap_mmu_hit10[0] -> input logic [7:0] sysmap_mmu_hit10,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 70 | `sysmap_mmu_hit10[1] -> input logic [7:0] sysmap_mmu_hit10,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 70 | `sysmap_mmu_hit10[2] -> input logic [7:0] sysmap_mmu_hit10,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 70 | `sysmap_mmu_hit10[7:3] -> input logic [7:0] sysmap_mmu_hit10,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 71 | `sysmap_mmu_hit11[7:4] -> input logic [7:0] sysmap_mmu_hit11,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 72 | `sysmap_mmu_hit12[3:2] -> input logic [7:0] sysmap_mmu_hit12,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 72 | `sysmap_mmu_hit12[6:4] -> input logic [7:0] sysmap_mmu_hit12,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 72 | `sysmap_mmu_hit12[7] -> input logic [7:0] sysmap_mmu_hit12,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 73 | `sysmap_mmu_hit13[2] -> input logic [7:0] sysmap_mmu_hit13,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 73 | `sysmap_mmu_hit13[7:3] -> input logic [7:0] sysmap_mmu_hit13,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 74 | `sysmap_mmu_hit14[7:4] -> input logic [7:0] sysmap_mmu_hit14,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 75 | `sysmap_mmu_hit15[6:4] -> input logic [7:0] sysmap_mmu_hit15,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 75 | `sysmap_mmu_hit15[7] -> input logic [7:0] sysmap_mmu_hit15,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 1 |
| 77 | `mmu_sysmap_pa3[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[12] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[13] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[17] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[27:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 77 | `mmu_sysmap_pa3[9:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 79 | `mmu_sysmap_pa5[18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa5,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 79 | `mmu_sysmap_pa5[27:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa5,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 80 | `mmu_sysmap_pa6[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa6,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 80 | `mmu_sysmap_pa6[20:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa6,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 80 | `mmu_sysmap_pa6[23:21] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa6,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 80 | `mmu_sysmap_pa6[27:24] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa6,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[10:9] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[13:12] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[15:14] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[16] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[17] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[27:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 81 | `mmu_sysmap_pa7[8:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 82 | `mmu_sysmap_pa8[0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa8,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 82 | `mmu_sysmap_pa8[18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa8,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 82 | `mmu_sysmap_pa8[27:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa8,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 83 | `mmu_sysmap_pa9[11:10] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa9,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 83 | `mmu_sysmap_pa9[20:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa9,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 83 | `mmu_sysmap_pa9[23:21] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa9,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 83 | `mmu_sysmap_pa9[27:24] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa9,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 84 | `mmu_sysmap_pa10[13:10] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa10,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 84 | `mmu_sysmap_pa10[14] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa10,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 84 | `mmu_sysmap_pa10[17:15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa10,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 84 | `mmu_sysmap_pa10[19:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa10,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 84 | `mmu_sysmap_pa10[27:20] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa10,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 84 | `mmu_sysmap_pa10[8:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa10,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 85 | `mmu_sysmap_pa11[19:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa11,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 85 | `mmu_sysmap_pa11[27:20] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa11,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 85 | `mmu_sysmap_pa11[8:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa11,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 86 | `mmu_sysmap_pa12[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa12,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 86 | `mmu_sysmap_pa12[15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa12,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 86 | `mmu_sysmap_pa12[20:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa12,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 86 | `mmu_sysmap_pa12[23:21] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa12,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 86 | `mmu_sysmap_pa12[27:24] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa12,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 87 | `mmu_sysmap_pa13[13] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa13,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 87 | `mmu_sysmap_pa13[15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa13,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 87 | `mmu_sysmap_pa13[19:17] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa13,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 87 | `mmu_sysmap_pa13[27:20] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa13,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 87 | `mmu_sysmap_pa13[9:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa13,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 88 | `mmu_sysmap_pa14[19:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa14,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 88 | `mmu_sysmap_pa14[27:20] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa14,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 88 | `mmu_sysmap_pa14[8:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa14,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 89 | `mmu_sysmap_pa15[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa15,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 89 | `mmu_sysmap_pa15[20:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa15,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 89 | `mmu_sysmap_pa15[23:21] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa15,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 89 | `mmu_sysmap_pa15[27:24] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pa15,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 100 | `mmu_pmp_pa3[27:11] -> output logic [PPN_WIDTH-1:0] mmu_pmp_pa3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 102 | `mmu_pmp_pa7[27:10] -> output logic [PPN_WIDTH-1:0] mmu_pmp_pa7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 103 | `mmu_pmp_pa5[27:11] -> output logic [PPN_WIDTH-1:0] mmu_pmp_pa5,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 104 | `mmu_pmp_pa6[27:10] -> output logic [PPN_WIDTH-1:0] mmu_pmp_pa6,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 105 | `mmu_pmp_fetch3 -> output logic mmu_pmp_fetch3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 107 | `mmu_pmp_fetch7 -> output logic mmu_pmp_fetch7,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 108 | `mmu_pmp_fetch5 -> output logic mmu_pmp_fetch5,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 109 | `mmu_pmp_fetch6 -> output logic mmu_pmp_fetch6,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 110 | `pmp_regs_update -> input logic pmp_regs_update,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 123 | `lsu_mmu_data[33:32] -> input logic [63:0] lsu_mmu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 123 | `lsu_mmu_data[58:55] -> input logic [63:0] lsu_mmu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 134 | `mmu_lsu_data_req_addr[2:0] -> output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 134 | `mmu_lsu_data_req_addr[39:23] -> output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 138 | `mmu_lsu_data_req_size -> output logic mmu_lsu_data_req_size,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 146 | `ptw_arb_vpn[26] -> output logic [VPN_WIDTH-1:0] ptw_arb_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 148 | `ptw_arb_ref_data_din[37:35] -> output logic [DATA_WIDTH-1:0] ptw_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 149 | `ptw_arb_ref_tag_din[19:16] -> output logic [TAG_WIDTH-1:0] ptw_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 149 | `ptw_arb_ref_tag_din[46] -> output logic [TAG_WIDTH-1:0] ptw_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 154 | `ptw_l1dtlb_ref_vpn[26] -> output logic [VPN_WIDTH-1:0] ptw_l1dtlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 156 | `ptw_l1dtlb_ref_ppn[23:21] -> output logic [PPN_WIDTH-1:0] ptw_l1dtlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 164 | `ptw_l1itlb_ref_vpn[26] -> output logic [VPN_WIDTH-1:0] ptw_l1itlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 166 | `ptw_l1itlb_ref_ppn[23:21] -> output logic [PPN_WIDTH-1:0] ptw_l1itlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 181 | `ptw_l2tlb_ref_vpn[26] -> output logic [VPN_WIDTH-1:0] ptw_l2tlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 183 | `ptw_l2tlb_ref_ppn[23:21] -> output logic [PPN_WIDTH-1:0] ptw_l2tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |

`mmu/rtl/ptw.sv:34`

```systemverilog
      32:     input  logic                   cp0_mmu_icg_en,
      33:     input  logic                   cp0_mmu_maee,
>>    34:     input  logic [1:0]             cp0_mmu_mpp,
      35:     input  logic                   cp0_mmu_mprv,
      36:     input  logic                   cp0_mmu_mxr,
```

`mmu/rtl/ptw.sv:42`

```systemverilog
      40:     input  logic                   hpcp_mmu_cnt_en,
      41: 
>>    42:     input  logic [ASID_WIDTH-1:0]  regs_ptw_cur_asid,
      43:     input  logic [PPN_WIDTH-1:0]   regs_ptw_satp_ppn,
      44:     input  logic                   regs_ptw_clr,
```

`mmu/rtl/ptw.sv:43`

```systemverilog
      41: 
      42:     input  logic [ASID_WIDTH-1:0]  regs_ptw_cur_asid,
>>    43:     input  logic [PPN_WIDTH-1:0]   regs_ptw_satp_ppn,
      44:     input  logic                   regs_ptw_clr,
      45: 
```

`mmu/rtl/ptw.sv:49`

```systemverilog
      47: //! Systemmap <=> ptw
      48: //!******************************************
>>    49:     input  logic [4:0]             sysmap_mmu_flg3,
      50: //input  logic [4 :0]	 	sysmap_mmu_flg4,
      51:     input  logic [4:0]             sysmap_mmu_flg5,
```

`mmu/rtl/ptw.sv:51`

```systemverilog
      49:     input  logic [4:0]             sysmap_mmu_flg3,
      50: //input  logic [4 :0]	 	sysmap_mmu_flg4,
>>    51:     input  logic [4:0]             sysmap_mmu_flg5,
      52:     input  logic [4:0]             sysmap_mmu_flg6,
      53:     input  logic [4:0]             sysmap_mmu_flg7,
```

`mmu/rtl/ptw.sv:52`

```systemverilog
      50: //input  logic [4 :0]	 	sysmap_mmu_flg4,
      51:     input  logic [4:0]             sysmap_mmu_flg5,
>>    52:     input  logic [4:0]             sysmap_mmu_flg6,
      53:     input  logic [4:0]             sysmap_mmu_flg7,
      54:     input  logic [4:0]             sysmap_mmu_flg8,
```

`mmu/rtl/ptw.sv:53`

```systemverilog
      51:     input  logic [4:0]             sysmap_mmu_flg5,
      52:     input  logic [4:0]             sysmap_mmu_flg6,
>>    53:     input  logic [4:0]             sysmap_mmu_flg7,
      54:     input  logic [4:0]             sysmap_mmu_flg8,
      55:     input  logic [4:0]             sysmap_mmu_flg9,
```

`mmu/rtl/ptw.sv:54`

```systemverilog
      52:     input  logic [4:0]             sysmap_mmu_flg6,
      53:     input  logic [4:0]             sysmap_mmu_flg7,
>>    54:     input  logic [4:0]             sysmap_mmu_flg8,
      55:     input  logic [4:0]             sysmap_mmu_flg9,
      56:     input  logic [4:0]             sysmap_mmu_flg10,
```

`mmu/rtl/ptw.sv:55`

```systemverilog
      53:     input  logic [4:0]             sysmap_mmu_flg7,
      54:     input  logic [4:0]             sysmap_mmu_flg8,
>>    55:     input  logic [4:0]             sysmap_mmu_flg9,
      56:     input  logic [4:0]             sysmap_mmu_flg10,
      57:     input  logic [4:0]             sysmap_mmu_flg11,
```

`mmu/rtl/ptw.sv:56`

```systemverilog
      54:     input  logic [4:0]             sysmap_mmu_flg8,
      55:     input  logic [4:0]             sysmap_mmu_flg9,
>>    56:     input  logic [4:0]             sysmap_mmu_flg10,
      57:     input  logic [4:0]             sysmap_mmu_flg11,
      58:     input  logic [4:0]             sysmap_mmu_flg12,
```

`mmu/rtl/ptw.sv:57`

```systemverilog
      55:     input  logic [4:0]             sysmap_mmu_flg9,
      56:     input  logic [4:0]             sysmap_mmu_flg10,
>>    57:     input  logic [4:0]             sysmap_mmu_flg11,
      58:     input  logic [4:0]             sysmap_mmu_flg12,
      59:     input  logic [4:0]             sysmap_mmu_flg13,
```

`mmu/rtl/ptw.sv:58`

```systemverilog
      56:     input  logic [4:0]             sysmap_mmu_flg10,
      57:     input  logic [4:0]             sysmap_mmu_flg11,
>>    58:     input  logic [4:0]             sysmap_mmu_flg12,
      59:     input  logic [4:0]             sysmap_mmu_flg13,
      60:     input  logic [4:0]             sysmap_mmu_flg14,
```

`mmu/rtl/ptw.sv:59`

```systemverilog
      57:     input  logic [4:0]             sysmap_mmu_flg11,
      58:     input  logic [4:0]             sysmap_mmu_flg12,
>>    59:     input  logic [4:0]             sysmap_mmu_flg13,
      60:     input  logic [4:0]             sysmap_mmu_flg14,
      61:     input  logic [4:0]             sysmap_mmu_flg15,
```

`mmu/rtl/ptw.sv:60`

```systemverilog
      58:     input  logic [4:0]             sysmap_mmu_flg12,
      59:     input  logic [4:0]             sysmap_mmu_flg13,
>>    60:     input  logic [4:0]             sysmap_mmu_flg14,
      61:     input  logic [4:0]             sysmap_mmu_flg15,
      62: 
```

`mmu/rtl/ptw.sv:61`

```systemverilog
      59:     input  logic [4:0]             sysmap_mmu_flg13,
      60:     input  logic [4:0]             sysmap_mmu_flg14,
>>    61:     input  logic [4:0]             sysmap_mmu_flg15,
      62: 
      63:     input  logic [7:0]             sysmap_mmu_hit3,
```

`mmu/rtl/ptw.sv:63`

```systemverilog
      61:     input  logic [4:0]             sysmap_mmu_flg15,
      62: 
>>    63:     input  logic [7:0]             sysmap_mmu_hit3,
      64: //input  logic [7 :0]	 	sysmap_mmu_hit4,
      65:     input  logic [7:0]             sysmap_mmu_hit5,
```

`mmu/rtl/ptw.sv:65`

```systemverilog
      63:     input  logic [7:0]             sysmap_mmu_hit3,
      64: //input  logic [7 :0]	 	sysmap_mmu_hit4,
>>    65:     input  logic [7:0]             sysmap_mmu_hit5,
      66:     input  logic [7:0]             sysmap_mmu_hit6,
      67:     input  logic [7:0]             sysmap_mmu_hit7,
```

`mmu/rtl/ptw.sv:66`

```systemverilog
      64: //input  logic [7 :0]	 	sysmap_mmu_hit4,
      65:     input  logic [7:0]             sysmap_mmu_hit5,
>>    66:     input  logic [7:0]             sysmap_mmu_hit6,
      67:     input  logic [7:0]             sysmap_mmu_hit7,
      68:     input  logic [7:0]             sysmap_mmu_hit8,
```

`mmu/rtl/ptw.sv:67`

```systemverilog
      65:     input  logic [7:0]             sysmap_mmu_hit5,
      66:     input  logic [7:0]             sysmap_mmu_hit6,
>>    67:     input  logic [7:0]             sysmap_mmu_hit7,
      68:     input  logic [7:0]             sysmap_mmu_hit8,
      69:     input  logic [7:0]             sysmap_mmu_hit9,
```

`mmu/rtl/ptw.sv:68`

```systemverilog
      66:     input  logic [7:0]             sysmap_mmu_hit6,
      67:     input  logic [7:0]             sysmap_mmu_hit7,
>>    68:     input  logic [7:0]             sysmap_mmu_hit8,
      69:     input  logic [7:0]             sysmap_mmu_hit9,
      70:     input  logic [7:0]             sysmap_mmu_hit10,
```

`mmu/rtl/ptw.sv:69`

```systemverilog
      67:     input  logic [7:0]             sysmap_mmu_hit7,
      68:     input  logic [7:0]             sysmap_mmu_hit8,
>>    69:     input  logic [7:0]             sysmap_mmu_hit9,
      70:     input  logic [7:0]             sysmap_mmu_hit10,
      71:     input  logic [7:0]             sysmap_mmu_hit11,
```

`mmu/rtl/ptw.sv:70`

```systemverilog
      68:     input  logic [7:0]             sysmap_mmu_hit8,
      69:     input  logic [7:0]             sysmap_mmu_hit9,
>>    70:     input  logic [7:0]             sysmap_mmu_hit10,
      71:     input  logic [7:0]             sysmap_mmu_hit11,
      72:     input  logic [7:0]             sysmap_mmu_hit12,
```

`mmu/rtl/ptw.sv:71`

```systemverilog
      69:     input  logic [7:0]             sysmap_mmu_hit9,
      70:     input  logic [7:0]             sysmap_mmu_hit10,
>>    71:     input  logic [7:0]             sysmap_mmu_hit11,
      72:     input  logic [7:0]             sysmap_mmu_hit12,
      73:     input  logic [7:0]             sysmap_mmu_hit13,
```

`mmu/rtl/ptw.sv:72`

```systemverilog
      70:     input  logic [7:0]             sysmap_mmu_hit10,
      71:     input  logic [7:0]             sysmap_mmu_hit11,
>>    72:     input  logic [7:0]             sysmap_mmu_hit12,
      73:     input  logic [7:0]             sysmap_mmu_hit13,
      74:     input  logic [7:0]             sysmap_mmu_hit14,
```

`mmu/rtl/ptw.sv:73`

```systemverilog
      71:     input  logic [7:0]             sysmap_mmu_hit11,
      72:     input  logic [7:0]             sysmap_mmu_hit12,
>>    73:     input  logic [7:0]             sysmap_mmu_hit13,
      74:     input  logic [7:0]             sysmap_mmu_hit14,
      75:     input  logic [7:0]             sysmap_mmu_hit15,
```

`mmu/rtl/ptw.sv:74`

```systemverilog
      72:     input  logic [7:0]             sysmap_mmu_hit12,
      73:     input  logic [7:0]             sysmap_mmu_hit13,
>>    74:     input  logic [7:0]             sysmap_mmu_hit14,
      75:     input  logic [7:0]             sysmap_mmu_hit15,
      76: 
```

`mmu/rtl/ptw.sv:75`

```systemverilog
      73:     input  logic [7:0]             sysmap_mmu_hit13,
      74:     input  logic [7:0]             sysmap_mmu_hit14,
>>    75:     input  logic [7:0]             sysmap_mmu_hit15,
      76: 
      77:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa3,
```

`mmu/rtl/ptw.sv:77`

```systemverilog
      75:     input  logic [7:0]             sysmap_mmu_hit15,
      76: 
>>    77:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa3,
      78: //output logic [27:0]	 	mmu_sysmap_pa4,
      79:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa5,
```

`mmu/rtl/ptw.sv:79`

```systemverilog
      77:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa3,
      78: //output logic [27:0]	 	mmu_sysmap_pa4,
>>    79:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa5,
      80:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa6,
      81:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa7,
```

`mmu/rtl/ptw.sv:80`

```systemverilog
      78: //output logic [27:0]	 	mmu_sysmap_pa4,
      79:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa5,
>>    80:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa6,
      81:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa7,
      82:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa8,
```

`mmu/rtl/ptw.sv:81`

```systemverilog
      79:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa5,
      80:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa6,
>>    81:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa7,
      82:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa8,
      83:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa9,
```

`mmu/rtl/ptw.sv:82`

```systemverilog
      80:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa6,
      81:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa7,
>>    82:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa8,
      83:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa9,
      84:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa10,
```

`mmu/rtl/ptw.sv:83`

```systemverilog
      81:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa7,
      82:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa8,
>>    83:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa9,
      84:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa10,
      85:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa11,
```

`mmu/rtl/ptw.sv:84`

```systemverilog
      82:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa8,
      83:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa9,
>>    84:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa10,
      85:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa11,
      86:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa12,
```

`mmu/rtl/ptw.sv:85`

```systemverilog
      83:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa9,
      84:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa10,
>>    85:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa11,
      86:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa12,
      87:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa13,
```

`mmu/rtl/ptw.sv:86`

```systemverilog
      84:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa10,
      85:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa11,
>>    86:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa12,
      87:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa13,
      88:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa14,
```

`mmu/rtl/ptw.sv:87`

```systemverilog
      85:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa11,
      86:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa12,
>>    87:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa13,
      88:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa14,
      89:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa15,
```

`mmu/rtl/ptw.sv:88`

```systemverilog
      86:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa12,
      87:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa13,
>>    88:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa14,
      89:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa15,
      90: 
```

`mmu/rtl/ptw.sv:89`

```systemverilog
      87:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa13,
      88:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa14,
>>    89:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pa15,
      90: 
      91: //!******************************************
```

`mmu/rtl/ptw.sv:100`

```systemverilog
      98:     input  logic [3:0]             pmp_mmu_flg6,
      99: 
>>   100:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa3,
     101: //output logic [27:0]	 	mmu_pmp_pa4,
     102:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa7,
```

`mmu/rtl/ptw.sv:102`

```systemverilog
     100:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa3,
     101: //output logic [27:0]	 	mmu_pmp_pa4,
>>   102:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa7,
     103:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa5,
     104:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa6,
```

`mmu/rtl/ptw.sv:103`

```systemverilog
     101: //output logic [27:0]	 	mmu_pmp_pa4,
     102:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa7,
>>   103:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa5,
     104:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa6,
     105:     output logic                   mmu_pmp_fetch3,
```

`mmu/rtl/ptw.sv:104`

```systemverilog
     102:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa7,
     103:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa5,
>>   104:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa6,
     105:     output logic                   mmu_pmp_fetch3,
     106: //output logic  		 	mmu_pmp_fetch4,
```

`mmu/rtl/ptw.sv:105`

```systemverilog
     103:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa5,
     104:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa6,
>>   105:     output logic                   mmu_pmp_fetch3,
     106: //output logic  		 	mmu_pmp_fetch4,
     107:     output logic                   mmu_pmp_fetch7,
```

`mmu/rtl/ptw.sv:107`

```systemverilog
     105:     output logic                   mmu_pmp_fetch3,
     106: //output logic  		 	mmu_pmp_fetch4,
>>   107:     output logic                   mmu_pmp_fetch7,
     108:     output logic                   mmu_pmp_fetch5,
     109:     output logic                   mmu_pmp_fetch6,
```

`mmu/rtl/ptw.sv:108`

```systemverilog
     106: //output logic  		 	mmu_pmp_fetch4,
     107:     output logic                   mmu_pmp_fetch7,
>>   108:     output logic                   mmu_pmp_fetch5,
     109:     output logic                   mmu_pmp_fetch6,
     110:     input  logic                   pmp_regs_update,
```

`mmu/rtl/ptw.sv:109`

```systemverilog
     107:     output logic                   mmu_pmp_fetch7,
     108:     output logic                   mmu_pmp_fetch5,
>>   109:     output logic                   mmu_pmp_fetch6,
     110:     input  logic                   pmp_regs_update,
     111: //!******************************************
```

`mmu/rtl/ptw.sv:110`

```systemverilog
     108:     output logic                   mmu_pmp_fetch5,
     109:     output logic                   mmu_pmp_fetch6,
>>   110:     input  logic                   pmp_regs_update,
     111: //!******************************************
     112: //! L2TLB Request
```

`mmu/rtl/ptw.sv:123`

```systemverilog
     121: //!******************************************
     122:     input  logic                   lsu_mmu_bus_error,
>>   123:     input  logic [63:0]            lsu_mmu_data,
     124:     input  logic                   lsu_mmu_data_vld,
     125:     // LSU 返回 PTW load response 时带回的 MBUF entry id。
```

`mmu/rtl/ptw.sv:134`

```systemverilog
     132: 
     133:     output logic                   mmu_lsu_data_req,
>>   134:     output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,
     135:     // PTW 发给 LSU 的 request id，取自当前发起请求的 MBUF entry index。
     136:     // LSU 必须在 response 上带回同一个 id。
```

`mmu/rtl/ptw.sv:138`

```systemverilog
     136:     // LSU 必须在 response 上带回同一个 id。
     137:     output logic [MBUF_ID_WIDTH-1:0] mmu_lsu_data_req_id,
>>   138:     output logic                   mmu_lsu_data_req_size,
     139: 
     140: //!******************************************
```

`mmu/rtl/ptw.sv:146`

```systemverilog
     144:     input  logic                   arb_ptw_mask,
     145: 
>>   146:     output logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
     147:     output logic                   ptw_arb_req,
     148:     output logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
```

`mmu/rtl/ptw.sv:148`

```systemverilog
     146:     output logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
     147:     output logic                   ptw_arb_req,
>>   148:     output logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
     149:     output logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
     150:     output logic [PGS_WIDTH-1:0]   ptw_arb_ref_pgs,
```

`mmu/rtl/ptw.sv:149`

```systemverilog
     147:     output logic                   ptw_arb_req,
     148:     output logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
>>   149:     output logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
     150:     output logic [PGS_WIDTH-1:0]   ptw_arb_ref_pgs,
     151: 
```

`mmu/rtl/ptw.sv:154`

```systemverilog
     152: // to l1tlb
     153:     output logic                   ptw_l1dtlb_ref_pa_vld,
>>   154:     output logic [VPN_WIDTH-1:0]   ptw_l1dtlb_ref_vpn,
     155:     output logic [PGS_WIDTH-1:0]   ptw_l1dtlb_ref_pgs,
     156:     output logic [PPN_WIDTH-1:0]   ptw_l1dtlb_ref_ppn,
```

`mmu/rtl/ptw.sv:156`

```systemverilog
     154:     output logic [VPN_WIDTH-1:0]   ptw_l1dtlb_ref_vpn,
     155:     output logic [PGS_WIDTH-1:0]   ptw_l1dtlb_ref_pgs,
>>   156:     output logic [PPN_WIDTH-1:0]   ptw_l1dtlb_ref_ppn,
     157:     output logic [FLG_WIDTH-1:0]   ptw_l1dtlb_ref_flg,
     158:     output logic [ID_WIDTH-1:0]    ptw_l1tlb_id,
```

`mmu/rtl/ptw.sv:164`

```systemverilog
     162: 
     163:     output logic                   ptw_l1itlb_ref_pa_vld,
>>   164:     output logic [VPN_WIDTH-1:0]   ptw_l1itlb_ref_vpn,
     165:     output logic [PGS_WIDTH-1:0]   ptw_l1itlb_ref_pgs,
     166:     output logic [PPN_WIDTH-1:0]   ptw_l1itlb_ref_ppn,
```

`mmu/rtl/ptw.sv:166`

```systemverilog
     164:     output logic [VPN_WIDTH-1:0]   ptw_l1itlb_ref_vpn,
     165:     output logic [PGS_WIDTH-1:0]   ptw_l1itlb_ref_pgs,
>>   166:     output logic [PPN_WIDTH-1:0]   ptw_l1itlb_ref_ppn,
     167:     output logic [FLG_WIDTH-1:0]   ptw_l1itlb_ref_flg,
     168:     output logic                   ptw_l1itlb_cmplt,
```

`mmu/rtl/ptw.sv:181`

```systemverilog
     179:     output logic [ID_WIDTH-1:0]    ptw_l2tlb_id,
     180:     output logic [FLG_WIDTH-1:0]   ptw_l2tlb_flg,
>>   181:     output logic [VPN_WIDTH-1:0]   ptw_l2tlb_ref_vpn,
     182:     output logic [PGS_WIDTH-1:0]   ptw_l2tlb_ref_pgs,
     183:     output logic [PPN_WIDTH-1:0]   ptw_l2tlb_ref_ppn,
```

`mmu/rtl/ptw.sv:183`

```systemverilog
     181:     output logic [VPN_WIDTH-1:0]   ptw_l2tlb_ref_vpn,
     182:     output logic [PGS_WIDTH-1:0]   ptw_l2tlb_ref_pgs,
>>   183:     output logic [PPN_WIDTH-1:0]   ptw_l2tlb_ref_ppn,
     184: 
     185:     output logic                   ptw_jtlb_ready,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 196 | `mbuf_cache_upd_ppn[23:22] -> logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 196 | `mbuf_cache_upd_ppn[27:24] -> logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 203 | `PDE_xbar_ppn[27:11] -> logic [PPN_WIDTH-1:0] PDE_xbar_ppn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 208 | `twu_cache_stop -> logic twu_cache_stop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 212 | `xbar_twu_ppn[27:11] -> logic [PPN_WIDTH-1:0] xbar_twu_ppn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 221 | `mbuf_twu_data[33:32] -> logic [63:0] mbuf_twu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 221 | `mbuf_twu_data[58:55] -> logic [63:0] mbuf_twu_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 230 | `twu_mbuf_twu_idx[3:0][3:0] -> logic [3:0][3:0] twu_mbuf_twu_idx ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 231 | `twu_mbuf_mask[3:0] -> logic [3:0] twu_mbuf_mask ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 233 | `twu_arb_ref_data_din[0][0] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[0][25] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[0][2] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[0][34:33] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[0][41:38] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[0][6:5] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[0][8] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[1][25:24] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[1][2:0] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[1][34:33] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[1][41:38] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[1][7:5] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[2][2:0] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[2][32] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[2][34] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[2][41:38] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[2][8:5] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[3][2:0] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[3][34:33] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[3][41:38] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 233 | `twu_arb_ref_data_din[3][8:5] -> logic [3:0][DATA_WIDTH-1:0] twu_arb_ref_data_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[0][10:7] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[0][15:12] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[0][47] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[1][10:5] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[1][15:12] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[1][43] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[1][47] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][10:7] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][15:12] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][2] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][31] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][44] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][47] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[2][4] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[3][15:8] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[3][47] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `twu_arb_ref_tag_din[3][6:4] -> logic [3:0][TAG_WIDTH-1:0] twu_arb_ref_tag_din ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 235 | `twu_arb_ref_pgs[2][1] -> logic [3:0][PGS_WIDTH-1:0] twu_arb_ref_pgs ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 237 | `twu_arb_ref_id[1][6] -> logic [3:0][ID_WIDTH-1:0] twu_arb_ref_id ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 240 | `twu_l2tlb_ref_pgflt_type[0][0] -> logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_pgflt_type ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 242 | `twu_l2tlb_ref_acc_err_type[0][1] -> logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 242 | `twu_l2tlb_ref_acc_err_type[1][1] -> logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 242 | `twu_l2tlb_ref_acc_err_type[2][1] -> logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 242 | `twu_l2tlb_ref_acc_err_type[3][1] -> logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 258 | `mbuf_bus_error_id[2] -> logic [ID_WIDTH-1:0] mbuf_bus_error_id ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 263 | `PDE_cache_acc_err_id[2:1] -> logic [ID_WIDTH-1:0] PDE_cache_acc_err_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 263 | `PDE_cache_acc_err_id[6:5] -> logic [ID_WIDTH-1:0] PDE_cache_acc_err_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 270 | `acc_err_rant -> logic acc_err_rant ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 271 | `ref_rant -> logic ref_rant ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 278 | `ptw_clk_en -> assign ptw_clk_en = 1'b1;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1085 | `ptw_lsu_addr_dbg_q[2:0] -> //logic [39:0] ptw_lsu_addr_dbg_q;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1085 | `ptw_lsu_addr_dbg_q[39:23] -> //logic [39:0] ptw_lsu_addr_dbg_q;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1218 | `ptw_lsu_req_trace_en -> logic ptw_lsu_req_trace_en;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/ptw.sv:196`

```systemverilog
     194: logic                  mbuf_cache_upd    ;
     195: logic [PTE_LEVEL-2:0]  mbuf_cache_upd_lvl;
>>   196: logic [PPN_WIDTH-1:0]  mbuf_cache_upd_ppn;
     197: logic [VPN_WIDTH-1:0]  mbuf_cache_upd_vpn;
     198: logic [3:0]            mbuf_cache_upd_l1pmpflg;
```

`mmu/rtl/ptw.sv:203`

```systemverilog
     201: logic                  L2PDE_xbar_hit_vld;
     202: logic                  L1PDE_xbar_hit_vld;
>>   203: logic [PPN_WIDTH-1:0]  PDE_xbar_ppn      ;
     204: logic [VPN_WIDTH-1:0]  PDE_xbar_vpn      ;
     205: logic [TYPE_WIDTH-1:0] PDE_xbar_type     ;
```

`mmu/rtl/ptw.sv:208`

```systemverilog
     206: logic [ID_WIDTH-1:0]   PDE_xbar_id       ;
     207: logic                  PDE_xbar_req      ;
>>   208: logic                  twu_cache_stop    ;
     209: //logic	[3:0]			twu_idle				    ;
     210: logic [3:0]                  xbar_twu_req              ;
```

`mmu/rtl/ptw.sv:212`

```systemverilog
     210: logic [3:0]                  xbar_twu_req              ;
     211: logic [PTE_LEVEL-2:0]        xbar_twu_hit_level        ;
>>   212: logic [PPN_WIDTH-1:0]        xbar_twu_ppn              ;
     213: logic [VPN_WIDTH-1:0]        xbar_twu_vpn              ;
     214: logic [TYPE_WIDTH-1:0]       xbar_twu_type             ;
```

`mmu/rtl/ptw.sv:221`

```systemverilog
     219: logic [ID_WIDTH-1:0]         mbuf_twu_id               ;
     220: logic [PTE_LEVEL-1:0]        mbuf_twu_lvl              ;
>>   221: logic [63:0]                 mbuf_twu_data             ;
     222: logic [3:0]                  mbuf_twu_data_vld         ;
     223: logic [3:0]                  mbuf_grant                ;
```

`mmu/rtl/ptw.sv:230`

```systemverilog
     228: logic [3:0][ID_WIDTH-1:0]    twu_mbuf_id               ;
     229: logic [3:0][PTE_LEVEL-1:0]   twu_mbuf_lvl              ;
>>   230: logic [3:0][3:0]             twu_mbuf_twu_idx          ;
     231: logic [3:0]                  twu_mbuf_mask             ;
     232: logic [3:0]                  twu_arb_ref_req           ;
```

`mmu/rtl/ptw.sv:231`

```systemverilog
     229: logic [3:0][PTE_LEVEL-1:0]   twu_mbuf_lvl              ;
     230: logic [3:0][3:0]             twu_mbuf_twu_idx          ;
>>   231: logic [3:0]                  twu_mbuf_mask             ;
     232: logic [3:0]                  twu_arb_ref_req           ;
     233: logic [3:0][DATA_WIDTH-1:0]  twu_arb_ref_data_din      ;
```

`mmu/rtl/ptw.sv:233`

```systemverilog
     231: logic [3:0]                  twu_mbuf_mask             ;
     232: logic [3:0]                  twu_arb_ref_req           ;
>>   233: logic [3:0][DATA_WIDTH-1:0]  twu_arb_ref_data_din      ;
     234: logic [3:0][TAG_WIDTH-1:0]   twu_arb_ref_tag_din       ;
     235: logic [3:0][PGS_WIDTH-1:0]   twu_arb_ref_pgs           ;
```

`mmu/rtl/ptw.sv:234`

```systemverilog
     232: logic [3:0]                  twu_arb_ref_req           ;
     233: logic [3:0][DATA_WIDTH-1:0]  twu_arb_ref_data_din      ;
>>   234: logic [3:0][TAG_WIDTH-1:0]   twu_arb_ref_tag_din       ;
     235: logic [3:0][PGS_WIDTH-1:0]   twu_arb_ref_pgs           ;
     236: logic [3:0][TYPE_WIDTH-1:0]  twu_arb_ref_type          ;
```

`mmu/rtl/ptw.sv:235`

```systemverilog
     233: logic [3:0][DATA_WIDTH-1:0]  twu_arb_ref_data_din      ;
     234: logic [3:0][TAG_WIDTH-1:0]   twu_arb_ref_tag_din       ;
>>   235: logic [3:0][PGS_WIDTH-1:0]   twu_arb_ref_pgs           ;
     236: logic [3:0][TYPE_WIDTH-1:0]  twu_arb_ref_type          ;
     237: logic [3:0][ID_WIDTH-1:0]    twu_arb_ref_id            ;
```

`mmu/rtl/ptw.sv:237`

```systemverilog
     235: logic [3:0][PGS_WIDTH-1:0]   twu_arb_ref_pgs           ;
     236: logic [3:0][TYPE_WIDTH-1:0]  twu_arb_ref_type          ;
>>   237: logic [3:0][ID_WIDTH-1:0]    twu_arb_ref_id            ;
     238: logic [3:0]                  twu_l2tlb_ref_pgflt       ;
     239: logic [3:0][ID_WIDTH-1:0]    twu_l2tlb_ref_pgflt_id    ;
```

`mmu/rtl/ptw.sv:240`

```systemverilog
     238: logic [3:0]                  twu_l2tlb_ref_pgflt       ;
     239: logic [3:0][ID_WIDTH-1:0]    twu_l2tlb_ref_pgflt_id    ;
>>   240: logic [3:0][TYPE_WIDTH-1:0]  twu_l2tlb_ref_pgflt_type  ;
     241: logic [3:0]                  twu_l2tlb_ref_acc_err     ;
     242: logic [3:0][TYPE_WIDTH-1:0]  twu_l2tlb_ref_acc_err_type;
```

`mmu/rtl/ptw.sv:242`

```systemverilog
     240: logic [3:0][TYPE_WIDTH-1:0]  twu_l2tlb_ref_pgflt_type  ;
     241: logic [3:0]                  twu_l2tlb_ref_acc_err     ;
>>   242: logic [3:0][TYPE_WIDTH-1:0]  twu_l2tlb_ref_acc_err_type;
     243: logic [3:0][ID_WIDTH-1:0]    twu_l2tlb_ref_acc_err_id  ;
     244: //logic	[3:0]			mbuf_twu_have           	;
```

`mmu/rtl/ptw.sv:258`

```systemverilog
     256: logic                      mbuf_bus_error     ;
     257: logic [TYPE_WIDTH-1:0]     mbuf_bus_error_type;
>>   258: logic [ID_WIDTH-1:0]       mbuf_bus_error_id  ;
     259: logic [3:0]                twu_pgflt_sel      ;
     260: logic [5:0]                twu_acc_err_sel    ;
```

`mmu/rtl/ptw.sv:263`

```systemverilog
     261: logic                      PDE_cache_acc_err_vld;
     262: logic [TYPE_WIDTH-1:0]     PDE_cache_acc_err_type;
>>   263: logic [ID_WIDTH-1:0]       PDE_cache_acc_err_id;
     264: logic [3:0]                twu_ref_sel        ;
     265: logic [3:0][PTE_LEVEL-1:0] twu_data_ready     ;
```

`mmu/rtl/ptw.sv:270`

```systemverilog
     268: logic                      ref_vld            ;
     269: logic                      pgflt_grant        ;
>>   270: logic                      acc_err_rant       ;
     271: logic                      ref_rant           ;
     272: logic                      l2tlb_miss         ;
```

`mmu/rtl/ptw.sv:271`

```systemverilog
     269: logic                      pgflt_grant        ;
     270: logic                      acc_err_rant       ;
>>   271: logic                      ref_rant           ;
     272: logic                      l2tlb_miss         ;
     273: logic                      l2tlb_miss_cnt     ;
```

`mmu/rtl/ptw.sv:278`

```systemverilog
     276: 
     277: 
>>   278: assign ptw_clk_en = 1'b1;
     279: // &Instance("gated_clk_cell", "x_ptw_gateclk"); @59
     280: gated_clk_cell  x_ptw_gateclk (
```

`mmu/rtl/ptw.sv:1085`

```systemverilog
    1083: //logic [2:0]            ptw_rsp_pgs_q;
    1084: //logic                  ptw_lsu_req_dbg_q;
>>  1085: //logic [39:0]           ptw_lsu_addr_dbg_q;
    1086: //
    1087: //assign ptw_l2tlb_ref_type[TYPE_WIDTH-1:0] = ptw_arb_ref_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/ptw.sv:1218`

```systemverilog
    1216: logic [PADDR_WIDTH-1:0] ptw_lsu_addr_dbg_q;
    1217: logic [MBUF_ID_WIDTH-1:0] ptw_lsu_id_dbg_q;
>>  1218: logic                   ptw_lsu_req_trace_en;
    1219: 
    1220: initial begin
```

## 模块 `ptw_mbuf`

源码：`mmu/rtl/ptw_mbuf.sv`
PTW 子树实例数：`1`；合并后唯一未覆盖代码对象数：`44`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 292 | `EXPRESSION (((!twu_itlb_sel)) & ((!twu_mbuf_req[3])) & ((!twu_mbuf_req[2])) & ((!twu_mbuf_req[1])) & twu_mbuf_req[0])` | 1 0 1 1 1 Not Covered; 1 1 0 1 1 Not Covered | 1 |
| 771 | `EXPRESSION (((\|write_back_grant[(MBUF_ENTRY_NUM - 1):0])) & ((!ptw_abort_drain)))` | 1 0 Not Covered | 1 |
| 800 | `SUB-EXPRESSION (pde_updata_data_flop[1] \| pde_updata_data_flop[3] \| pde_updata_data_flop[2] \| pde_updata_lvl[0])` | 0 0 1 0 Not Covered; 0 1 0 0 Not Covered; 1 0 0 0 Not Covered | 1 |

`mmu/rtl/ptw_mbuf.sv:292`

```systemverilog
     290: assign thd_twu_sel = (!twu_itlb_sel) & (!twu_mbuf_req[3]) & twu_mbuf_req[2];
     291: assign scd_twu_sel = (!twu_itlb_sel) & (!twu_mbuf_req[3]) & (!twu_mbuf_req[2]) & twu_mbuf_req[1];
>>   292: assign fst_twu_sel = (!twu_itlb_sel) & (!twu_mbuf_req[3]) & (!twu_mbuf_req[2]) & (!twu_mbuf_req[1]) & twu_mbuf_req[0];
     293: 
     294: always_comb begin
```

`mmu/rtl/ptw_mbuf.sv:771`

```systemverilog
     769:     // 允许进入 PDE cache refill 判断。abort 当拍 entry.vld 已经被清掉，drain
     770:     // 期间后续 LSU response 只用于清 entry.on，不能污染 PDE cache。
>>   771:     else if(|write_back_grant[MBUF_ENTRY_NUM-1:0] & (!ptw_abort_drain))
     772:         pde_updata_data_vld <= 1'b1;
     773:     else
```

`mmu/rtl/ptw_mbuf.sv:800`

```systemverilog
     798: //   - pde_updata_lvl[0]     = 0                            -> 当前不是第 3 级 PTW 检查
     799: //                                                       (最后一级不应再作为 PDE 缓存)
>>   800: assign mbuf_cache_upd = pde_updata_data_vld
     801:                       & pde_updata_data_flop[0]                    // V = 1
     802:                       & (!(pde_updata_data_flop[1] | pde_updata_data_flop[3]      // R=0 且 X=0 -> 非叶子
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 40 | `twu_mbuf_twu_idx[3:0][3:0] -> input logic [3:0][3:0] twu_mbuf_twu_idx,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 48 | `lsu_mmu_data[33:32] -> input logic [DATA_WIDTH-1:0] lsu_mmu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 48 | `lsu_mmu_data[58:55] -> input logic [DATA_WIDTH-1:0] lsu_mmu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT | 1 |
| 57 | `mmu_lsu_data_req_addr[2:0] -> output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 57 | `mmu_lsu_data_req_addr[39:23] -> output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 59 | `mmu_lsu_data_req_size -> output logic mmu_lsu_data_req_size,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 68 | `mbuf_twu_data[33:32] -> output logic [DATA_WIDTH-1:0] mbuf_twu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 68 | `mbuf_twu_data[58:55] -> output logic [DATA_WIDTH-1:0] mbuf_twu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 78 | `mbuf_cache_upd_ppn[23:22] -> output logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 78 | `mbuf_cache_upd_ppn[27:24] -> output logic [PPN_WIDTH-1:0] mbuf_cache_upd_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 89 | `mbuf_bus_error_id[2] -> output logic [ID_WIDTH-1:0] mbuf_bus_error_id,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |

`mmu/rtl/ptw_mbuf.sv:40`

```systemverilog
      38:     input  logic [3:0][ID_WIDTH-1:0]    twu_mbuf_id,
      39:     input  logic [3:0][PTE_LEVEL-1:0]   twu_mbuf_lvl,
>>    40:     input  logic [3:0][3:0]             twu_mbuf_twu_idx,
      41:     input  logic [3:0][7:0]             twu_mbuf_pmpflg,
      42: //input logic	 [3:0]      twu_mbuf_mask,
```

`mmu/rtl/ptw_mbuf.sv:48`

```systemverilog
      46: //!******************************************
      47:     input  logic                        lsu_mmu_data_vld,
>>    48:     input  logic [DATA_WIDTH-1:0]       lsu_mmu_data,
      49:     input  logic [MBUF_ID_WIDTH-1:0]    lsu_mmu_data_id,
      50:     // LSU 对 PTW load 请求的接收确认。
```

`mmu/rtl/ptw_mbuf.sv:57`

```systemverilog
      55: 
      56:     output logic                        mmu_lsu_data_req,
>>    57:     output logic [PADDR_WIDTH-1:0]      mmu_lsu_data_req_addr,
      58:     output logic [MBUF_ID_WIDTH-1:0]    mmu_lsu_data_req_id,
      59:     output logic                        mmu_lsu_data_req_size,
```

`mmu/rtl/ptw_mbuf.sv:59`

```systemverilog
      57:     output logic [PADDR_WIDTH-1:0]      mmu_lsu_data_req_addr,
      58:     output logic [MBUF_ID_WIDTH-1:0]    mmu_lsu_data_req_id,
>>    59:     output logic                        mmu_lsu_data_req_size,
      60: //!******************************************
      61: //! Responce to TWU
```

`mmu/rtl/ptw_mbuf.sv:68`

```systemverilog
      66:     output logic [ID_WIDTH-1:0]         mbuf_twu_id,
      67:     output logic [PTE_LEVEL-1:0]        mbuf_twu_lvl,
>>    68:     output logic [DATA_WIDTH-1:0]       mbuf_twu_data,
      69:     output logic [7:0]                  mbuf_twu_pmpflg,
      70:     output logic [3:0]                  mbuf_twu_data_vld,
```

`mmu/rtl/ptw_mbuf.sv:78`

```systemverilog
      76: //!******************************************
      77:     output logic                        mbuf_cache_upd,
>>    78:     output logic [PPN_WIDTH-1:0]        mbuf_cache_upd_ppn,
      79:     output logic [PTE_LEVEL-2:0]        mbuf_cache_upd_lvl,
      80:     output logic [VPN_WIDTH-1:0]        mbuf_cache_upd_vpn,
```

`mmu/rtl/ptw_mbuf.sv:89`

```systemverilog
      87:     output logic                        mbuf_bus_error,
      88:     output logic [TYPE_WIDTH-1:0]       mbuf_bus_error_type,
>>    89:     output logic [ID_WIDTH-1:0]         mbuf_bus_error_id,
      90:     input  logic                        acc_err_mbuf_grant
      91: 
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 111 | `mbuf_upd_padder[2:0] -> logic [PADDR_WIDTH-1:0] mbuf_upd_padder;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 111 | `mbuf_upd_padder[39:23] -> logic [PADDR_WIDTH-1:0] mbuf_upd_padder;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 152 | `mbuf_entry_padder[3][17] -> logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 152 | `mbuf_entry_padder[5][14] -> logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 152 | `mbuf_entry_padder[6][13] -> logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 152 | `mbuf_entry_padder[8][21:19] -> logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[2][11] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[3][11:10] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[3][15] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[3][20:18] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[4][11:10] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[5][11:10] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[6][10:9] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[7][10] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `mbuf_entry_vpn[7][8] -> logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0] mbuf_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 156 | `mbuf_entry_type[4][1] -> logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0] mbuf_entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 156 | `mbuf_entry_type[5][1] -> logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0] mbuf_entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 156 | `mbuf_entry_type[6][1] -> logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0] mbuf_entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 156 | `mbuf_entry_type[7][1] -> logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0] mbuf_entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 156 | `mbuf_entry_type[8][1:0] -> logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0] mbuf_entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 157 | `mbuf_entry_id[6][2] -> logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0] mbuf_entry_id;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 157 | `mbuf_entry_id[6][5:4] -> logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0] mbuf_entry_id;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 157 | `mbuf_entry_id[7][3] -> logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0] mbuf_entry_id;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 172 | `mbuf_entry_get[7:4] -> logic [MBUF_ENTRY_NUM-1:0] mbuf_entry_get;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 173 | `mbuf_entry_bus_err_flop[8:0] -> logic [MBUF_ENTRY_NUM-1:0] mbuf_entry_bus_err_flop;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 178 | `mbuf_entry_bus_err_req_mask -> logic mbuf_entry_bus_err_req_mask;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 182 | `mbuf_clk_en -> logic mbuf_clk_en;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 184 | `pde_updata_data_flop[33:32] -> logic [DATA_WIDTH-1:0] pde_updata_data_flop;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 184 | `pde_updata_data_flop[37:34] -> logic [DATA_WIDTH-1:0] pde_updata_data_flop;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 184 | `pde_updata_data_flop[58:55] -> logic [DATA_WIDTH-1:0] pde_updata_data_flop;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/ptw_mbuf.sv:111`

```systemverilog
     109: logic [3:0]                 mbuf_grant_raw;
     110: logic [3:0]                 mbuf_twu_idx;
>>   111: logic [PADDR_WIDTH-1:0]    mbuf_upd_padder;
     112: logic [VPN_WIDTH-1:0]      mbuf_upd_vpn;
     113: logic [TYPE_WIDTH-1:0]     mbuf_upd_type;
```

`mmu/rtl/ptw_mbuf.sv:152`

```systemverilog
     150: logic [MBUF_ENTRY_NUM-1:0]                  lsu_mmu_data_vld_entry;
     151: logic [MBUF_ENTRY_NUM-1:0]                  lsu_mmu_bus_error_entry;
>>   152: logic [MBUF_ENTRY_NUM-1:0][PADDR_WIDTH-1:0] mbuf_entry_padder;
     153: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_vld;
     154: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_on;
```

`mmu/rtl/ptw_mbuf.sv:155`

```systemverilog
     153: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_vld;
     154: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_on;
>>   155: logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0]   mbuf_entry_vpn;
     156: logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0]  mbuf_entry_type;
     157: logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0]    mbuf_entry_id;
```

`mmu/rtl/ptw_mbuf.sv:156`

```systemverilog
     154: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_on;
     155: logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0]   mbuf_entry_vpn;
>>   156: logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0]  mbuf_entry_type;
     157: logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0]    mbuf_entry_id;
     158: logic [MBUF_ENTRY_NUM-1:0][3:0]             mbuf_entry_twu_idx;
```

`mmu/rtl/ptw_mbuf.sv:157`

```systemverilog
     155: logic [MBUF_ENTRY_NUM-1:0][VPN_WIDTH-1:0]   mbuf_entry_vpn;
     156: logic [MBUF_ENTRY_NUM-1:0][TYPE_WIDTH-1:0]  mbuf_entry_type;
>>   157: logic [MBUF_ENTRY_NUM-1:0][ID_WIDTH-1:0]    mbuf_entry_id;
     158: logic [MBUF_ENTRY_NUM-1:0][3:0]             mbuf_entry_twu_idx;
     159: logic [MBUF_ENTRY_NUM-1:0][PTE_LEVEL-1:0]   mbuf_entry_lvl;
```

`mmu/rtl/ptw_mbuf.sv:172`

```systemverilog
     170: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_bus_error_grant;
     171: logic [MBUF_ENTRY_NUM-1:0]                  bus_err_write_back_req;
>>   172: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_get;
     173: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_bus_err_flop;
     174: 
```

`mmu/rtl/ptw_mbuf.sv:173`

```systemverilog
     171: logic [MBUF_ENTRY_NUM-1:0]                  bus_err_write_back_req;
     172: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_get;
>>   173: logic [MBUF_ENTRY_NUM-1:0]                  mbuf_entry_bus_err_flop;
     174: 
     175: //==============================================================================
```

`mmu/rtl/ptw_mbuf.sv:178`

```systemverilog
     176: // Internal — TWU response merge / clock / PDE refill / LSU req sequencing
     177: //==============================================================================
>>   178: logic                       mbuf_entry_bus_err_req_mask;
     179: logic [TYPE_WIDTH-1:0]      entry_bus_err_type;
     180: logic [ID_WIDTH-1:0]        entry_bus_err_id;
```

`mmu/rtl/ptw_mbuf.sv:182`

```systemverilog
     180: logic [ID_WIDTH-1:0]        entry_bus_err_id;
     181: logic                       mbuf_clk;
>>   182: logic                       mbuf_clk_en;
     183: logic                       pde_updata_data_vld;
     184: logic [DATA_WIDTH-1:0]      pde_updata_data_flop;
```

`mmu/rtl/ptw_mbuf.sv:184`

```systemverilog
     182: logic                       mbuf_clk_en;
     183: logic                       pde_updata_data_vld;
>>   184: logic [DATA_WIDTH-1:0]      pde_updata_data_flop;
     185: logic [VPN_WIDTH-1:0]       pde_updata_vpn;
     186: logic [PTE_LEVEL-1:0]       pde_updata_lvl;
```

## 模块 `twu`

源码：`mmu/rtl/twu.sv`
PTW 子树实例数：`4`；合并后唯一未覆盖代码对象数：`929`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 410 | `fst_pmp_vld <= fst_pmp_vld;` | 0/1 x4 | 4 |
| 472 | `fst_chk_vld <= fst_chk_vld;` | 0/1 | 1 |
| 562 | `scd_pmp_vld <= scd_pmp_vld;` | 0/1 x2 | 2 |
| 637 | `scd_chk_vld <= scd_chk_vld;` | 0/1 x2 | 2 |
| 922 | `twu_acc_err_vld <= 1'b1;` | 0/1 x4 | 4 |
| 938 | `twu_acc_err_type[TYPE_WIDTH-1:0] <= scd_pmp_type[TYPE_WIDTH-1:0];` | 0/1 x4 | 4 |
| 939 | `twu_acc_err_id[ID_WIDTH-1:0] <= scd_pmp_id[ID_WIDTH-1:0];` | 0/1 x4 | 4 |
| 1237 | `ptw_nxt_st[2:0] = TWU_IDLE;` | 0/1 x4 | 4 |
| 1273 | `twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= twu_sysmap_adderx1[PADDR_WIDTH-1:0];` | 0/1 x2 | 2 |
| 1274 | `twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH-9], csr_vpn_flop[8:0], 12'b0};` | 0/1 x2 | 2 |
| 1286 | `csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH-9], csr_vpn_flop[8:0], csr_data_flop[9:0]};` | 0/1 x2 | 2 |
| 1297 | `csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b001;` | 0/1 x2 | 2 |
| 1381 | `5'b00100 : refill_grant[3:0] = 4'b0100;` | 0/1 | 1 |
| 1442 | `twu_ref_data_din[RDATA_WIDTH-1:0] <= fst_chk_refill_data[RDATA_WIDTH-1:0];` | 0/1 | 1 |
| 1443 | `twu_ref_tag_din[TAG_WIDTH-1:0] <= fst_chk_refill_tag[TAG_WIDTH-1:0];` | 0/1 | 1 |
| 1444 | `twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b100;` | 0/1 | 1 |
| 1445 | `twu_ref_type[TYPE_WIDTH-1:0] <= fst_chk_refill_type[TYPE_WIDTH-1:0];` | 0/1 | 1 |
| 1446 | `twu_ref_id[ID_WIDTH-1:0] <= fst_chk_refill_id[ID_WIDTH-1:0];` | 0/1 | 1 |

`mmu/rtl/twu.sv:410`

```systemverilog
     408: 		fst_pmp_vld <= 1'b0;
     409: 	else if(fst_pmp_wait)
>>   410: 		fst_pmp_vld <= fst_pmp_vld;
     411: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b00)& (!fst_pmp_wait))
     412: 		fst_pmp_vld <= 1'b1;
```

`mmu/rtl/twu.sv:472`

```systemverilog
     470: 		fst_chk_vld <= 1'b0;
     471: 	else if(fst_chk_wait)
>>   472: 		fst_chk_vld <= fst_chk_vld;
     473: 	else if(mbuf_twu_data_vld & mbuf_twu_lvl[2]& (!fst_chk_wait))
     474: 		fst_chk_vld <= 1'b1;
```

`mmu/rtl/twu.sv:562`

```systemverilog
     560: 		scd_pmp_vld <= 1'b0;
     561: 	else if(scd_pmp_wait)
>>   562: 		scd_pmp_vld <= scd_pmp_vld;
     563: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b10) & (!scd_pmp_wait))
     564: 		scd_pmp_vld <= 1'b1;
```

`mmu/rtl/twu.sv:637`

```systemverilog
     635: 		scd_chk_vld <= 1'b0;
     636: 	else if(scd_chk_wait)
>>   637: 		scd_chk_vld <= scd_chk_vld;
     638: 	else if(mbuf_twu_data_vld & mbuf_twu_lvl[1] & (!scd_chk_wait))
     639: 		scd_chk_vld <= 1'b1;
```

`mmu/rtl/twu.sv:922`

```systemverilog
     920:         twu_acc_err_vld <= 1'b1;
     921:     else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
>>   922:         twu_acc_err_vld <= 1'b1;
     923:     else if(fst_pmp_vld & fst_pmp_deny& fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
     924:         twu_acc_err_vld <= 1'b1;
```

`mmu/rtl/twu.sv:938`

```systemverilog
     936: 		twu_acc_err_id[ID_WIDTH-1:0] <= thd_pmp_id[ID_WIDTH-1:0];
     937: 	end else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
>>   938: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= scd_pmp_type[TYPE_WIDTH-1:0];
     939: 		twu_acc_err_id[ID_WIDTH-1:0] <= scd_pmp_id[ID_WIDTH-1:0];
     940: 	end else if(fst_pmp_vld & fst_pmp_deny& fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
```

`mmu/rtl/twu.sv:939`

```systemverilog
     937: 	end else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
     938: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= scd_pmp_type[TYPE_WIDTH-1:0];
>>   939: 		twu_acc_err_id[ID_WIDTH-1:0] <= scd_pmp_id[ID_WIDTH-1:0];
     940: 	end else if(fst_pmp_vld & fst_pmp_deny& fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
     941: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= fst_pmp_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:1237`

```systemverilog
    1235: 		end
    1236: 		default:begin
>>  1237: 			ptw_nxt_st[2:0] = TWU_IDLE;
    1238: 		end
    1239: 	endcase
```

`mmu/rtl/twu.sv:1273`

```systemverilog
    1271: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 9'h1ff, 12'b0};
    1272: 	end else if(twu_crs_2m & twu_csr_cross)begin
>>  1273: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= twu_sysmap_adderx1[PADDR_WIDTH-1:0];
    1274: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH-9], csr_vpn_flop[8:0], 12'b0};
    1275: 	end
```

`mmu/rtl/twu.sv:1274`

```systemverilog
    1272: 	end else if(twu_crs_2m & twu_csr_cross)begin
    1273: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= twu_sysmap_adderx1[PADDR_WIDTH-1:0];
>>  1274: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH-9], csr_vpn_flop[8:0], 12'b0};
    1275: 	end
    1276: end
```

`mmu/rtl/twu.sv:1286`

```systemverilog
    1284: 		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH], csr_vpn_flop[17:9], csr_data_flop[18:0]};
    1285: 	else if(twu_crs_2m && twu_csr_cross)
>>  1286: 		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH-9], csr_vpn_flop[8:0], csr_data_flop[9:0]};
    1287: end
    1288: 
```

`mmu/rtl/twu.sv:1297`

```systemverilog
    1295: 		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b010;
    1296: 	else if(twu_crs_2m && twu_csr_cross)
>>  1297: 		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b001;
    1298: end
    1299: 
```

`mmu/rtl/twu.sv:1381`

```systemverilog
    1379:         5'b10000    : refill_grant[3:0] = {csr_ref_itlb_sel,fst_chk_itlb_sel,scd_chk_itlb_sel,thd_chk_itlb_sel};
    1380:         5'b01000    : refill_grant[3:0] = 4'b1000;
>>  1381:         5'b00100    : refill_grant[3:0] = 4'b0100;
    1382:         5'b00010    : refill_grant[3:0] = 4'b0010;
    1383:         5'b00001    : refill_grant[3:0] = 4'b0001;
```

`mmu/rtl/twu.sv:1442`

```systemverilog
    1440: 		twu_ref_id[ID_WIDTH-1:0] <= scd_chk_refill_id[ID_WIDTH-1:0];
    1441: 	end else if(refill_grant[2] & twu_refill_idle)begin
>>  1442: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= fst_chk_refill_data[RDATA_WIDTH-1:0];
    1443: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= fst_chk_refill_tag[TAG_WIDTH-1:0];
    1444: 		twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b100;
```

`mmu/rtl/twu.sv:1443`

```systemverilog
    1441: 	end else if(refill_grant[2] & twu_refill_idle)begin
    1442: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= fst_chk_refill_data[RDATA_WIDTH-1:0];
>>  1443: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= fst_chk_refill_tag[TAG_WIDTH-1:0];
    1444: 		twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b100;
    1445: 		twu_ref_type[TYPE_WIDTH-1:0] <= fst_chk_refill_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:1444`

```systemverilog
    1442: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= fst_chk_refill_data[RDATA_WIDTH-1:0];
    1443: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= fst_chk_refill_tag[TAG_WIDTH-1:0];
>>  1444: 		twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b100;
    1445: 		twu_ref_type[TYPE_WIDTH-1:0] <= fst_chk_refill_type[TYPE_WIDTH-1:0];
    1446: 		twu_ref_id[ID_WIDTH-1:0] <= fst_chk_refill_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:1445`

```systemverilog
    1443: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= fst_chk_refill_tag[TAG_WIDTH-1:0];
    1444: 		twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b100;
>>  1445: 		twu_ref_type[TYPE_WIDTH-1:0] <= fst_chk_refill_type[TYPE_WIDTH-1:0];
    1446: 		twu_ref_id[ID_WIDTH-1:0] <= fst_chk_refill_id[ID_WIDTH-1:0];
    1447: 	end else if(refill_grant[3] & twu_refill_idle)begin
```

`mmu/rtl/twu.sv:1446`

```systemverilog
    1444: 		twu_ref_pgs[PGS_WIDTH-1:0] <= 3'b100;
    1445: 		twu_ref_type[TYPE_WIDTH-1:0] <= fst_chk_refill_type[TYPE_WIDTH-1:0];
>>  1446: 		twu_ref_id[ID_WIDTH-1:0] <= fst_chk_refill_id[ID_WIDTH-1:0];
    1447: 	end else if(refill_grant[3] & twu_refill_idle)begin
    1448: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= csr_refill_data[RDATA_WIDTH-1:0];
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 411 | `EXPRESSION (xbar_twu_req & (xbar_twu_hit_level == 2'b0) & ((!fst_pmp_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 422 | `EXPRESSION (xbar_twu_req & (xbar_twu_hit_level == 2'b0) & ((!fst_pmp_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 437 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b11)` | 1 Not Covered x4 | 4 |
| 440 | `SUB-EXPRESSION (fst_pmp_cp0_mach_mode && ((!pmp_mmu_flg[3])))` | 1 0 Not Covered x4 | 4 |
| 440 | `SUB-EXPRESSION (fst_pmp_pref_type && ((!pmp_mmu_flg[0])))` | 1 1 Not Covered x4 | 4 |
| 473 | `EXPRESSION (mbuf_twu_data_vld & mbuf_twu_lvl[2] & ((!fst_chk_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 488 | `EXPRESSION (mbuf_twu_data_vld & mbuf_twu_lvl[2] & ((!fst_chk_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 505 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b0)` | 1 Not Covered x4 | 4 |
| 507 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b1)` | 0 Not Covered x4 | 4 |
| 510 | `SUB-EXPRESSION ( ! (cp0_mmu_mxr && fst_chk_flg[3]) )` | 1 Not Covered x3 | 3 |
| 510 | `SUB-EXPRESSION (( ! (fst_chk_flg[1] \|\| (cp0_mmu_mxr && fst_chk_flg[3])) ) && fst_chk_flg[2])` | 1 1 Not Covered x4 | 4 |
| 510 | `SUB-EXPRESSION (((!fst_chk_flg[1])) && fst_chk_load_type && ( ! (cp0_mmu_mxr && fst_chk_flg[3]) ))` | 1 1 0 Not Covered x4 | 4 |
| 510 | `SUB-EXPRESSION (((!fst_chk_flg[4])) && fst_chk_cp0_user_mode)` | 0 1 Not Covered x4 | 4 |
| 510 | `SUB-EXPRESSION (cp0_mmu_mxr && fst_chk_flg[3])` | 1 1 Not Covered x6 | 3 |
| 510 | `SUB-EXPRESSION (fst_chk_flg[1] \|\| (cp0_mmu_mxr && fst_chk_flg[3]))` | 0 1 Not Covered x4 | 4 |
| 510 | `SUB-EXPRESSION (fst_chk_flg[4] && fst_chk_cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered x4; 1 1 0 Not Covered x4; 1 1 1 Not Covered x4 | 4 |
| 524 | `EXPRESSION (fst_chk_flg[0] && (fst_chk_flg[1] \|\| fst_chk_flg[3]))` | 0 1 Not Covered x4 | 4 |
| 524 | `SUB-EXPRESSION (fst_chk_flg[1] \|\| fst_chk_flg[3])` | 0 1 Not Covered x4; 1 0 Not Covered x4 | 4 |
| 529 | `EXPRESSION (fst_chk_vld & fst_chk_leaf_vld & cp0_mmu_maee & ((!fst_chk_page_flt)))` | 0 1 1 1 Not Covered; 1 1 1 0 Not Covered; 1 1 1 1 Not Covered | 1 |
| 538 | `EXPRESSION (fst_chk_vld & fst_chk_leaf_vld & ((!cp0_mmu_maee)) & ((!fst_chk_page_flt)))` | 1 1 0 1 Not Covered; 1 1 1 0 Not Covered | 1 |
| 547 | `SUB-EXPRESSION (fst_chk_vld & fst_chk_leaf_vld & ((!fst_chk_page_flt)) & ((!cp0_mmu_maee)) & ((!fst_csr_grant)))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered | 1 |
| 547 | `SUB-EXPRESSION (fst_chk_vld & fst_chk_leaf_vld & ((!fst_chk_page_flt)) & cp0_mmu_maee & ((!refill_fst_chk_grant)))` | 0 1 1 1 1 Not Covered; 1 1 0 1 1 Not Covered; 1 1 1 1 0 Not Covered; 1 1 1 1 1 Not Covered | 1 |
| 547 | `SUB-EXPRESSION (fst_chk_vld & fst_chk_page_flt & ((!pgflt_fst_chk_grant)))` | 1 1 1 Not Covered | 1 |
| 547 | `SUB-EXPRESSION (fst_chk_vld & scd_pmp_wait & ((!fst_chk_leaf_vld)) & ((!fst_chk_page_flt)))` | 1 1 0 1 Not Covered x3; 1 1 1 0 Not Covered x3 | 4 |
| 563 | `EXPRESSION (xbar_twu_req & (xbar_twu_hit_level == 2'b10) & ((!scd_pmp_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 565 | `EXPRESSION (fst_chk_vld & ((!fst_chk_leaf_vld)) & ((!fst_chk_page_flt)) & ((!scd_pmp_wait)))` | 1 1 1 0 Not Covered x4 | 4 |
| 578 | `EXPRESSION (xbar_twu_req & (xbar_twu_hit_level == 2'b10) & ((!scd_pmp_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 584 | `EXPRESSION (fst_chk_vld & ((!fst_chk_leaf_vld)) & ((!fst_chk_page_flt)) & ((!scd_pmp_wait)))` | 1 1 1 0 Not Covered x4 | 4 |
| 601 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b11)` | 1 Not Covered x4 | 4 |
| 605 | `SUB-EXPRESSION (scd_pmp_cp0_mach_mode && ((!pmp_mmu_flg[3])))` | 1 0 Not Covered x4 | 4 |
| 605 | `SUB-EXPRESSION (scd_pmp_fetch_type && ((!pmp_mmu_flg[2])))` | 1 1 Not Covered | 1 |
| 605 | `SUB-EXPRESSION (scd_pmp_load_type && ((!pmp_mmu_flg[0])))` | 1 1 Not Covered | 1 |
| 605 | `SUB-EXPRESSION (scd_pmp_pref_type && ((!pmp_mmu_flg[0])))` | 1 1 Not Covered x3 | 3 |
| 605 | `SUB-EXPRESSION (scd_pmp_store_type && ((!pmp_mmu_flg[1])))` | 1 1 Not Covered x2 | 2 |
| 614 | `EXPRESSION (scd_pmp_vld & ((!scd_pmp_deny)) & scd_pmp_grant)` | 1 0 1 Not Covered x2 | 2 |
| 620 | `SUB-EXPRESSION (scd_pmp_vld & scd_pmp_grant & scd_pmp_deny & ((!acc_err_scd_pmp_grant)))` | 0 1 1 1 Not Covered x4; 1 0 1 1 Not Covered x3; 1 1 1 0 Not Covered x4; 1 1 1 1 Not Covered x2 | 4 |
| 638 | `EXPRESSION (mbuf_twu_data_vld & mbuf_twu_lvl[1] & ((!scd_chk_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 650 | `EXPRESSION (mbuf_twu_data_vld & mbuf_twu_lvl[1] & ((!scd_chk_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 666 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b0)` | 1 Not Covered x4 | 4 |
| 668 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b1)` | 0 Not Covered x4 | 4 |
| 671 | `SUB-EXPRESSION ( ! (cp0_mmu_mxr && scd_chk_flg[3]) )` | 1 Not Covered x4 | 4 |
| 671 | `SUB-EXPRESSION (( ! (scd_chk_flg[1] \|\| (cp0_mmu_mxr && scd_chk_flg[3])) ) && scd_chk_flg[2])` | 1 1 Not Covered x4 | 4 |
| 671 | `SUB-EXPRESSION (((!scd_chk_flg[1])) && scd_chk_load_type && ( ! (cp0_mmu_mxr && scd_chk_flg[3]) ))` | 1 1 0 Not Covered x4 | 4 |
| 671 | `SUB-EXPRESSION (((!scd_chk_flg[4])) && scd_chk_cp0_user_mode)` | 0 1 Not Covered x4 | 4 |
| 671 | `SUB-EXPRESSION (cp0_mmu_mxr && scd_chk_flg[3])` | 1 1 Not Covered x8 | 4 |
| 671 | `SUB-EXPRESSION (scd_chk_flg[1] \|\| (cp0_mmu_mxr && scd_chk_flg[3]))` | 0 1 Not Covered x4 | 4 |
| 671 | `SUB-EXPRESSION (scd_chk_flg[4] && scd_chk_cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered x4; 1 1 0 Not Covered x4; 1 1 1 Not Covered x4 | 4 |
| 685 | `EXPRESSION (scd_chk_flg[0] && (scd_chk_flg[1] \|\| scd_chk_flg[3]))` | 0 1 Not Covered x4 | 4 |
| 685 | `SUB-EXPRESSION (scd_chk_flg[1] \|\| scd_chk_flg[3])` | 0 1 Not Covered x4; 1 0 Not Covered | 4 |
| 690 | `EXPRESSION (scd_chk_vld & scd_chk_leaf_vld & cp0_mmu_maee & ((!scd_chk_page_flt)))` | 1 1 1 0 Not Covered x2 | 2 |
| 699 | `EXPRESSION (scd_chk_vld & scd_chk_leaf_vld & ((!cp0_mmu_maee)) & ((!scd_chk_page_flt)))` | 1 1 1 0 Not Covered x2 | 2 |
| 708 | `SUB-EXPRESSION (scd_chk_vld & scd_chk_leaf_vld & ((!scd_chk_page_flt)) & ((!cp0_mmu_maee)) & ((!scd_csr_grant)))` | 1 1 0 1 1 Not Covered x2 | 2 |
| 708 | `SUB-EXPRESSION (scd_chk_vld & scd_chk_leaf_vld & ((!scd_chk_page_flt)) & cp0_mmu_maee & ((!refill_scd_chk_grant)))` | 1 1 0 1 1 Not Covered x2 | 2 |
| 708 | `SUB-EXPRESSION (scd_chk_vld & scd_chk_page_flt & ((!pgflt_scd_chk_grant)))` | 1 1 1 Not Covered x4 | 4 |
| 708 | `SUB-EXPRESSION (scd_chk_vld & thd_pmp_wait & ((!scd_chk_leaf_vld)) & ((!scd_chk_page_flt)))` | 1 1 0 1 Not Covered x3; 1 1 1 0 Not Covered x4 | 4 |
| 724 | `EXPRESSION (xbar_twu_req & (xbar_twu_hit_level == 2'b1) & ((!thd_pmp_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 726 | `EXPRESSION (scd_chk_vld & ((!scd_chk_leaf_vld)) & ((!scd_chk_page_flt)) & ((!thd_pmp_wait)))` | 1 1 1 0 Not Covered x4 | 4 |
| 738 | `EXPRESSION (xbar_twu_req & (xbar_twu_hit_level == 2'b1) & ((!thd_pmp_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 743 | `EXPRESSION (scd_chk_vld & ((!scd_chk_leaf_vld)) & ((!scd_chk_page_flt)) & ((!thd_pmp_wait)))` | 1 1 1 0 Not Covered x4 | 4 |
| 759 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b11)` | 1 Not Covered x4 | 4 |
| 763 | `SUB-EXPRESSION (thd_pmp_cp0_mach_mode && ((!pmp_mmu_flg[3])))` | 1 0 Not Covered x4 | 4 |
| 763 | `SUB-EXPRESSION (thd_pmp_load_type && ((!pmp_mmu_flg[0])))` | 1 1 Not Covered x2 | 2 |
| 763 | `SUB-EXPRESSION (thd_pmp_pref_type && ((!pmp_mmu_flg[0])))` | 1 1 Not Covered x4 | 4 |
| 772 | `EXPRESSION (thd_pmp_vld & ((~thd_pmp_deny)) & thd_pmp_grant)` | 0 1 1 Not Covered x4 | 4 |
| 778 | `SUB-EXPRESSION (thd_pmp_vld & thd_pmp_grant & thd_pmp_deny & ((!acc_err_thd_pmp_grant)))` | 0 1 1 1 Not Covered x4 | 4 |
| 795 | `EXPRESSION (mbuf_twu_data_vld & mbuf_twu_lvl[0] & ((!thd_chk_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 807 | `EXPRESSION (mbuf_twu_data_vld & mbuf_twu_lvl[0] & ((!thd_chk_wait)))` | 1 1 0 Not Covered x4 | 4 |
| 823 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b0)` | 1 Not Covered x4 | 4 |
| 825 | `SUB-EXPRESSION (cp0_yy_priv_mode[1:0] == 2'b1)` | 0 Not Covered x4 | 4 |
| 828 | `SUB-EXPRESSION (((!thd_chk_flg[2])) && thd_chk_store_type)` | 1 1 Not Covered x2 | 2 |
| 828 | `SUB-EXPRESSION (((!thd_chk_flg[3])) && thd_chk_fetch_type)` | 1 1 Not Covered x2 | 2 |
| 828 | `SUB-EXPRESSION (((!thd_chk_flg[4])) && thd_chk_cp0_user_mode)` | 0 1 Not Covered x2 | 2 |
| 828 | `SUB-EXPRESSION (((!thd_chk_flg[6])) && thd_chk_store_type)` | 1 1 Not Covered x2 | 2 |
| 828 | `SUB-EXPRESSION (thd_chk_flg[4] && thd_chk_cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered x2; 1 1 0 Not Covered x2; 1 1 1 Not Covered | 3 |
| 854 | `EXPRESSION ((thd_chk_vld & ((~thd_chk_page_flt)) & ((!refill_thd_chk_grant))) \| (thd_chk_vld & thd_chk_page_flt & ((!pgflt_thd_chk_grant))))` | 0 1 Not Covered x4 | 4 |
| 854 | `SUB-EXPRESSION (thd_chk_vld & thd_chk_page_flt & ((!pgflt_thd_chk_grant)))` | 1 1 1 Not Covered x4 | 4 |
| 874 | `EXPRESSION (thd_chk_vld & thd_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 874 | `SUB-EXPRESSION (((!twu_pgflt_vld)) \| pgflt_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 876 | `EXPRESSION (scd_chk_vld & scd_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 876 | `SUB-EXPRESSION (((!twu_pgflt_vld)) \| pgflt_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 878 | `EXPRESSION (fst_chk_vld & fst_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 878 | `SUB-EXPRESSION (((!twu_pgflt_vld)) \| pgflt_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 888 | `EXPRESSION (thd_chk_vld & thd_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 888 | `SUB-EXPRESSION (((!twu_pgflt_vld)) \| pgflt_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 891 | `EXPRESSION (scd_chk_vld & scd_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 891 | `SUB-EXPRESSION (((!twu_pgflt_vld)) \| pgflt_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 894 | `EXPRESSION (fst_chk_vld & fst_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 894 | `SUB-EXPRESSION (((!twu_pgflt_vld)) \| pgflt_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 902 | `EXPRESSION (thd_chk_vld & thd_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant))` | 1 1 0 Not Covered x4 | 4 |
| 903 | `EXPRESSION (scd_chk_vld & scd_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant) & ((!pgflt_thd_chk_grant)))` | 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4 | 4 |
| 904 | `EXPRESSION (fst_chk_vld & fst_chk_page_flt & (((!twu_pgflt_vld)) \| pgflt_twu_grant) & ((!pgflt_scd_chk_grant)) & ((!pgflt_thd_chk_grant)))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered x4; 1 1 1 1 0 Not Covered x4 | 4 |
| 919 | `EXPRESSION (thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4 | 4 |
| 919 | `SUB-EXPRESSION (((!twu_acc_err_vld)) \| acc_err_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 921 | `EXPRESSION (scd_pmp_vld & scd_pmp_deny & scd_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4; 1 1 1 1 Not Covered x4 | 4 |
| 921 | `SUB-EXPRESSION (((!twu_acc_err_vld)) \| acc_err_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 923 | `EXPRESSION (fst_pmp_vld & fst_pmp_deny & fst_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4 | 4 |
| 923 | `SUB-EXPRESSION (((!twu_acc_err_vld)) \| acc_err_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 934 | `EXPRESSION (thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4 | 4 |
| 934 | `SUB-EXPRESSION (((!twu_acc_err_vld)) \| acc_err_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 937 | `EXPRESSION (scd_pmp_vld & scd_pmp_deny & scd_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4; 1 1 1 1 Not Covered x4 | 4 |
| 937 | `SUB-EXPRESSION (((!twu_acc_err_vld)) \| acc_err_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 940 | `EXPRESSION (fst_pmp_vld & fst_pmp_deny & fst_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x4; 1 1 1 0 Not Covered x4 | 4 |
| 940 | `SUB-EXPRESSION (((!twu_acc_err_vld)) \| acc_err_twu_grant)` | 0 0 Not Covered x4 | 4 |
| 948 | `EXPRESSION (thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x3; 1 1 1 0 Not Covered x2 | 4 |
| 949 | `EXPRESSION (scd_pmp_vld & scd_pmp_deny & scd_pmp_grant & (((!twu_acc_err_vld)) \| acc_err_twu_grant))` | 0 1 1 1 Not Covered x4; 1 1 0 1 Not Covered x3; 1 1 1 0 Not Covered x4; 1 1 1 1 Not Covered x2 | 4 |
| 967 | `EXPRESSION (((!pmp_itlb_sel)) & ((!scd_pmp_vld)) & ((!thd_pmp_vld)) & fst_pmp_vld)` | 1 0 1 1 Not Covered x4; 1 1 0 1 Not Covered x4 | 4 |
| 968 | `EXPRESSION (((!pmp_itlb_sel)) & ((!thd_pmp_vld)) & scd_pmp_vld)` | 1 0 1 Not Covered x4 | 4 |
| 1015 | `EXPRESSION (scd_chk_csr_req & scd_chk_fetch_type)` | 1 1 Not Covered | 1 |
| 1017 | `EXPRESSION (fst_csr_itlb_sel \| scd_csr_itlb_sel)` | 0 1 Not Covered | 1 |
| 1019 | `EXPRESSION (((!csr_itlb_sel)) & ((!scd_chk_csr_req)) & fst_chk_csr_req)` | 1 0 1 Not Covered x4 | 4 |
| 1020 | `EXPRESSION (((!csr_itlb_sel)) & scd_chk_csr_req)` | 0 1 Not Covered | 1 |
| 1214 | `EXPRESSION (csr_req & csr_grant[1])` | 0 1 Not Covered x4 | 4 |
| 1216 | `EXPRESSION (csr_req & csr_grant[0])` | 0 1 Not Covered x4; 1 0 Not Covered x4 | 4 |
| 1263 | `EXPRESSION (csr_grant[1] & csr_idle)` | 1 0 Not Covered | 1 |
| 1266 | `EXPRESSION (csr_grant[0] & csr_idle)` | 1 0 Not Covered x2 | 2 |
| 1269 | `EXPRESSION (twu_crs_1g & twu_csr_cross)` | 0 1 Not Covered x2 | 2 |
| 1272 | `EXPRESSION (twu_crs_2m & twu_csr_cross)` | 0 1 Not Covered x4; 1 1 Not Covered x2 | 4 |
| 1283 | `EXPRESSION (twu_crs_1g && twu_csr_cross)` | 0 1 Not Covered x2 | 2 |
| 1285 | `EXPRESSION (twu_crs_2m && twu_csr_cross)` | 0 1 Not Covered x4; 1 1 Not Covered x2 | 4 |
| 1294 | `EXPRESSION (twu_crs_1g && twu_csr_cross)` | 0 1 Not Covered x2 | 2 |
| 1296 | `EXPRESSION (twu_crs_2m && twu_csr_cross)` | 0 1 Not Covered x4; 1 1 Not Covered x2 | 4 |
| 1301 | `EXPRESSION (twu_crs_chk & (sysmap_mmu_hitx1[7:0] != sysmap_mmu_hitx2[7:0]))` | 0 1 Not Covered x2 | 2 |
| 1365 | `EXPRESSION (fst_chk_refill_req & fst_chk_fetch_type)` | 1 0 Not Covered; 1 1 Not Covered x4 | 4 |
| 1366 | `EXPRESSION (scd_chk_refill_req & scd_chk_fetch_type)` | 1 1 Not Covered | 1 |
| 1370 | `EXPRESSION (fst_chk_itlb_sel \| scd_chk_itlb_sel \| thd_chk_itlb_sel \| csr_ref_itlb_sel)` | 0 1 0 0 Not Covered; 1 0 0 0 Not Covered x4 | 4 |
| 1372 | `EXPRESSION (((!refill_itlb_sel)) & ((!csr_refill_req)) & ((!thd_chk_refill_req)) & ((!scd_chk_refill_req)) & fst_chk_refill_req)` | 0 1 1 1 1 Not Covered x4; 1 0 1 1 1 Not Covered x4; 1 1 0 1 1 Not Covered x4; 1 1 1 0 1 Not Covered x4; 1 1 1 1 1 Not Covered | 4 |
| 1373 | `EXPRESSION (((!refill_itlb_sel)) & ((!csr_refill_req)) & ((!thd_chk_refill_req)) & scd_chk_refill_req)` | 0 1 1 1 Not Covered; 1 0 1 1 Not Covered x4; 1 1 0 1 Not Covered x4 | 4 |
| 1374 | `EXPRESSION (((!refill_itlb_sel)) & ((!csr_refill_req)) & thd_chk_refill_req)` | 1 0 1 Not Covered x3 | 3 |
| 1435 | `EXPRESSION (refill_grant[1] & twu_refill_idle)` | 1 0 Not Covered x4 | 4 |
| 1441 | `EXPRESSION (refill_grant[2] & twu_refill_idle)` | 1 0 Not Covered x4; 1 1 Not Covered | 4 |
| 1447 | `EXPRESSION (refill_grant[3] & twu_refill_idle)` | 1 0 Not Covered x3 | 3 |
| 1462 | `EXPRESSION (refill_grant[3] & twu_refill_idle)` | 1 0 Not Covered x2 | 2 |
| 1463 | `EXPRESSION (refill_grant[2] & twu_refill_idle)` | 1 0 Not Covered; 1 1 Not Covered | 1 |

`mmu/rtl/twu.sv:411`

```systemverilog
     409: 	else if(fst_pmp_wait)
     410: 		fst_pmp_vld <= fst_pmp_vld;
>>   411: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b00)& (!fst_pmp_wait))
     412: 		fst_pmp_vld <= 1'b1;
     413: 	else
```

`mmu/rtl/twu.sv:422`

```systemverilog
     420: 		fst_pmp_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
     421: 		fst_pmp_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
>>   422: 	end else if(xbar_twu_req & (xbar_twu_hit_level == 3'b000) & (!fst_pmp_wait))begin
     423: 		fst_pmp_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
     424: 		fst_pmp_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:437`

```systemverilog
     435: assign fst_pmp_pref_type  = fst_pmp_type[TYPE_WIDTH-1:0] == 3'b100;
     436: 
>>   437: assign fst_pmp_cp0_mach_mode = fst_pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
     438:                                       : cp0_priv_mode[1:0] == 2'b11;
     439: 
```

`mmu/rtl/twu.sv:440`

```systemverilog
     438:                                       : cp0_priv_mode[1:0] == 2'b11;
     439: 
>>   440: assign fst_pmp_deny = (fst_pmp_fetch_type && !pmp_mmu_flg[2]
     441:                     || fst_pmp_load_type  && !pmp_mmu_flg[0]
     442:                     || fst_pmp_store_type && !pmp_mmu_flg[1]
```

`mmu/rtl/twu.sv:473`

```systemverilog
     471: 	else if(fst_chk_wait)
     472: 		fst_chk_vld <= fst_chk_vld;
>>   473: 	else if(mbuf_twu_data_vld & mbuf_twu_lvl[2]& (!fst_chk_wait))
     474: 		fst_chk_vld <= 1'b1;
     475: //	else if(mbuf_twu_data_vld_reg & mbuf_twu_lvl_reg[2]& (!fst_chk_wait))
```

`mmu/rtl/twu.sv:488`

```systemverilog
     486: 		fst_chk_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
     487: 		fst_chk_l1pmpflg[3:0] <= {4'b0};
>>   488: 	end else if(mbuf_twu_data_vld & mbuf_twu_lvl[2] & (!fst_chk_wait))begin
     489: 		fst_chk_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
     490: 		fst_chk_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:505`

```systemverilog
     503: assign fst_chk_store_type = fst_chk_type[TYPE_WIDTH-1:0] == 3'b110;
     504: 
>>   505: assign fst_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
     506:                                       : cp0_priv_mode[1:0] == 2'b00;
     507: assign fst_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
```

`mmu/rtl/twu.sv:507`

```systemverilog
     505: assign fst_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
     506:                                       : cp0_priv_mode[1:0] == 2'b00;
>>   507: assign fst_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
     508:                                       : cp0_priv_mode[1:0] == 2'b01;
     509: 
```

`mmu/rtl/twu.sv:510`

```systemverilog
     508:                                       : cp0_priv_mode[1:0] == 2'b01;
     509: 
>>   510: assign fst_chk_page_flt =  (!fst_chk_flg[0]                       // not valid
     511: 						||  !(fst_chk_flg[1] || cp0_mmu_mxr && fst_chk_flg[3])
     512: 								&& fst_chk_flg[2]         // write only
```

`mmu/rtl/twu.sv:524`

```systemverilog
     522: 							) && fst_chk_leaf_vld);
     523: 
>>   524: assign fst_chk_leaf_vld = fst_chk_flg[0] && (fst_chk_flg[1] || fst_chk_flg[3]);
     525: 
     526: //!******************************************
```

`mmu/rtl/twu.sv:529`

```systemverilog
     527: //! refill
     528: //!******************************************
>>   529: assign fst_chk_refill_req = fst_chk_vld & fst_chk_leaf_vld & cp0_mmu_maee & (!fst_chk_page_flt);
     530: assign fst_chk_refill_data[RDATA_WIDTH-1:0] = {fst_chk_data[37:10],fst_chk_data[63:59],fst_chk_data[9:6],fst_chk_data[4:0]};
     531: assign fst_chk_refill_tag[TAG_WIDTH-1:0] = {1'b1,fst_chk_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],3'b100,fst_chk_data[5]};
```

`mmu/rtl/twu.sv:538`

```systemverilog
     536: //! CSR
     537: //!******************************************
>>   538: assign fst_chk_csr_req = fst_chk_vld &  fst_chk_leaf_vld & (!cp0_mmu_maee) & (!fst_chk_page_flt);
     539: assign fst_chk_csr_vpn[VPN_WIDTH-1:0] = fst_chk_vpn[VPN_WIDTH-1:0];
     540: assign fst_chk_csr_type[TYPE_WIDTH-1:0] = fst_chk_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:547`

```systemverilog
     545: //! wait
     546: //!******************************************
>>   547: assign fst_chk_wait =    fst_chk_vld & scd_pmp_wait & (!fst_chk_leaf_vld) & (!fst_chk_page_flt)
     548: 					  |  fst_chk_vld & fst_chk_leaf_vld & (!fst_chk_page_flt) & cp0_mmu_maee & (!refill_fst_chk_grant)
     549: 					  |  fst_chk_vld & fst_chk_page_flt & (!pgflt_fst_chk_grant)
```

`mmu/rtl/twu.sv:563`

```systemverilog
     561: 	else if(scd_pmp_wait)
     562: 		scd_pmp_vld <= scd_pmp_vld;
>>   563: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b10) & (!scd_pmp_wait))
     564: 		scd_pmp_vld <= 1'b1;
     565: 	else if(fst_chk_vld & (!fst_chk_leaf_vld) & (!fst_chk_page_flt) & (!scd_pmp_wait))
```

`mmu/rtl/twu.sv:565`

```systemverilog
     563: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b10) & (!scd_pmp_wait))
     564: 		scd_pmp_vld <= 1'b1;
>>   565: 	else if(fst_chk_vld & (!fst_chk_leaf_vld) & (!fst_chk_page_flt) & (!scd_pmp_wait))
     566: 		scd_pmp_vld <= 1'b1;
     567: 	else
```

`mmu/rtl/twu.sv:578`

```systemverilog
     576: 		scd_pmp_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
     577: 		scd_pmp_l1pmpflg[3:0] <= {4'b0};
>>   578: 	end	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b10) & (!scd_pmp_wait))begin
     579: 		scd_pmp_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
     580: 		scd_pmp_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:584`

```systemverilog
     582: 		scd_pmp_ppn[PPN_WIDTH-1:0] <= xbar_twu_ppn[PPN_WIDTH-1:0];
     583: 		scd_pmp_l1pmpflg[3:0] <= {4'b0};
>>   584: 	end else if(fst_chk_vld & (!fst_chk_leaf_vld) & (!fst_chk_page_flt) & (!scd_pmp_wait))begin
     585: 		scd_pmp_vpn[VPN_WIDTH-1:0] <= fst_chk_vpn[VPN_WIDTH-1:0];
     586: 		scd_pmp_type[TYPE_WIDTH-1:0] <= fst_chk_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:601`

```systemverilog
     599: assign scd_pmp_pref_type  = scd_pmp_type[TYPE_WIDTH-1:0] == 3'b100;
     600: 
>>   601: assign scd_pmp_cp0_mach_mode = scd_pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
     602:                                       : cp0_priv_mode[1:0] == 2'b11;
     603: 
```

`mmu/rtl/twu.sv:605`

```systemverilog
     603: 
     604: 
>>   605: assign scd_pmp_deny = (scd_pmp_fetch_type && !pmp_mmu_flg[2]
     606:                     || scd_pmp_load_type  && !pmp_mmu_flg[0]
     607:                     || scd_pmp_store_type && !pmp_mmu_flg[1]
```

`mmu/rtl/twu.sv:614`

```systemverilog
     612: //! write MBUF
     613: //!******************************************
>>   614: assign scd_pmp_mbuf_req = scd_pmp_vld & (!scd_pmp_deny) & scd_pmp_grant;
     615: assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};
     616: 
```

`mmu/rtl/twu.sv:620`

```systemverilog
     618: //! wait
     619: //!******************************************
>>   620: assign scd_pmp_wait =    scd_pmp_vld & (!scd_pmp_grant)
     621: 					   | scd_pmp_mbuf_req & (!mbuf_grant)
     622: 					   | scd_pmp_vld & scd_pmp_grant & scd_pmp_deny & (!acc_err_scd_pmp_grant);
```

`mmu/rtl/twu.sv:638`

```systemverilog
     636: 	else if(scd_chk_wait)
     637: 		scd_chk_vld <= scd_chk_vld;
>>   638: 	else if(mbuf_twu_data_vld & mbuf_twu_lvl[1] & (!scd_chk_wait))
     639: 		scd_chk_vld <= 1'b1;
     640: 	else
```

`mmu/rtl/twu.sv:650`

```systemverilog
     648: 		scd_chk_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
     649: 		scd_chk_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
>>   650: 	end else if(mbuf_twu_data_vld & mbuf_twu_lvl[1] & (!scd_chk_wait))begin
     651: 		scd_chk_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
     652: 		scd_chk_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:666`

```systemverilog
     664: assign scd_chk_store_type = scd_chk_type[TYPE_WIDTH-1:0] == 3'b110;
     665: 
>>   666: assign scd_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
     667:                                    : cp0_priv_mode[1:0] == 2'b00;
     668: assign scd_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
```

`mmu/rtl/twu.sv:668`

```systemverilog
     666: assign scd_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
     667:                                    : cp0_priv_mode[1:0] == 2'b00;
>>   668: assign scd_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
     669:                                       : cp0_priv_mode[1:0] == 2'b01;
     670: 
```

`mmu/rtl/twu.sv:671`

```systemverilog
     669:                                       : cp0_priv_mode[1:0] == 2'b01;
     670: 
>>   671: assign scd_chk_page_flt =  (!scd_chk_flg[0]                       // not valid
     672: 						||  !(scd_chk_flg[1] || cp0_mmu_mxr && scd_chk_flg[3])
     673: 								&& scd_chk_flg[2]         // write only
```

`mmu/rtl/twu.sv:685`

```systemverilog
     683: 							) && scd_chk_leaf_vld);
     684: 
>>   685: assign scd_chk_leaf_vld = scd_chk_flg[0] && (scd_chk_flg[1] || scd_chk_flg[3]);
     686: 
     687: //!******************************************
```

`mmu/rtl/twu.sv:690`

```systemverilog
     688: //! refill
     689: //!******************************************
>>   690: assign scd_chk_refill_req = scd_chk_vld & scd_chk_leaf_vld & cp0_mmu_maee & (!scd_chk_page_flt);
     691: assign scd_chk_refill_data[RDATA_WIDTH-1:0] = {scd_chk_data[37:10],scd_chk_data[63:59],scd_chk_data[9:6],scd_chk_data[4:0]};
     692: assign scd_chk_refill_tag[TAG_WIDTH-1:0] = {1'b1,scd_chk_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],3'b010,scd_chk_data[5]};
```

`mmu/rtl/twu.sv:699`

```systemverilog
     697: //! CSR
     698: //!******************************************
>>   699: assign scd_chk_csr_req = scd_chk_vld & scd_chk_leaf_vld & (!cp0_mmu_maee) & (!scd_chk_page_flt);
     700: assign scd_chk_csr_vpn[VPN_WIDTH-1:0] = scd_chk_vpn[VPN_WIDTH-1:0];
     701: assign scd_chk_csr_type[TYPE_WIDTH-1:0] = scd_chk_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:708`

```systemverilog
     706: //! wait
     707: //!******************************************
>>   708: assign scd_chk_wait =    scd_chk_vld & thd_pmp_wait & (!scd_chk_leaf_vld) & (!scd_chk_page_flt)
     709: 					  |  scd_chk_vld & scd_chk_leaf_vld & (!scd_chk_page_flt) & cp0_mmu_maee & (!refill_scd_chk_grant)
     710: 					  |  scd_chk_vld & scd_chk_page_flt & (!pgflt_scd_chk_grant)
```

`mmu/rtl/twu.sv:724`

```systemverilog
     722: 	else if(thd_pmp_wait)
     723: 		thd_pmp_vld <= thd_pmp_vld;
>>   724: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b01) & (!thd_pmp_wait))
     725: 		thd_pmp_vld <= 1'b1;
     726: 	else if(scd_chk_vld & (!scd_chk_leaf_vld) & (!scd_chk_page_flt) & (!thd_pmp_wait))
```

`mmu/rtl/twu.sv:726`

```systemverilog
     724: 	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b01) & (!thd_pmp_wait))
     725: 		thd_pmp_vld <= 1'b1;
>>   726: 	else if(scd_chk_vld & (!scd_chk_leaf_vld) & (!scd_chk_page_flt) & (!thd_pmp_wait))
     727: 		thd_pmp_vld <= 1'b1;
     728: 	else
```

`mmu/rtl/twu.sv:738`

```systemverilog
     736: 		thd_pmp_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
     737: 		thd_pmp_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
>>   738: 	end	else if(xbar_twu_req & (xbar_twu_hit_level == 2'b01) & (!thd_pmp_wait))begin
     739: 		thd_pmp_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
     740: 		thd_pmp_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:743`

```systemverilog
     741: 		thd_pmp_id[ID_WIDTH-1:0] <= xbar_twu_id[ID_WIDTH-1:0];
     742: 		thd_pmp_ppn[PPN_WIDTH-1:0] <= xbar_twu_ppn[PPN_WIDTH-1:0];
>>   743: 	end else if(scd_chk_vld & (!scd_chk_leaf_vld) & (!scd_chk_page_flt) & (!thd_pmp_wait))begin
     744: 		thd_pmp_vpn[VPN_WIDTH-1:0] <= scd_chk_vpn[VPN_WIDTH-1:0];
     745: 		thd_pmp_type[TYPE_WIDTH-1:0] <= scd_chk_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:759`

```systemverilog
     757: assign thd_pmp_pref_type  = thd_pmp_type[TYPE_WIDTH-1:0] == 3'b100;
     758: 
>>   759: assign thd_pmp_cp0_mach_mode = thd_pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
     760:                                       : cp0_priv_mode[1:0] == 2'b11;
     761: 
```

`mmu/rtl/twu.sv:763`

```systemverilog
     761: 
     762: 
>>   763: assign thd_pmp_deny = (thd_pmp_fetch_type && !pmp_mmu_flg[2]
     764:                     || thd_pmp_load_type  && !pmp_mmu_flg[0]
     765:                     || thd_pmp_store_type && !pmp_mmu_flg[1]
```

`mmu/rtl/twu.sv:772`

```systemverilog
     770: //! write MBUF
     771: //!******************************************
>>   772: assign thd_pmp_mbuf_req = thd_pmp_vld & (~thd_pmp_deny) & thd_pmp_grant;
     773: assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8:0],3'b0};
     774: 
```

`mmu/rtl/twu.sv:778`

```systemverilog
     776: //! wait
     777: //!******************************************
>>   778: assign thd_pmp_wait =    thd_pmp_vld & (!thd_pmp_grant)
     779: 					   | thd_pmp_mbuf_req & (!mbuf_grant)
     780: 					   | thd_pmp_vld & thd_pmp_grant & thd_pmp_deny & (!acc_err_thd_pmp_grant);
```

`mmu/rtl/twu.sv:795`

```systemverilog
     793: 	else if(thd_chk_wait)
     794: 		thd_chk_vld <= thd_chk_vld;
>>   795: 	else if(mbuf_twu_data_vld & mbuf_twu_lvl[0] & (!thd_chk_wait))
     796: 		thd_chk_vld <= 1'b1;
     797: 	else
```

`mmu/rtl/twu.sv:807`

```systemverilog
     805: 		thd_chk_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
     806: 		thd_chk_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
>>   807: 	end else if(mbuf_twu_data_vld & mbuf_twu_lvl[0] & (!thd_chk_wait))begin
     808: 		thd_chk_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
     809: 		thd_chk_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
```

`mmu/rtl/twu.sv:823`

```systemverilog
     821: assign thd_chk_store_type = thd_chk_type[TYPE_WIDTH-1:0] == 3'b110;
     822: 
>>   823: assign thd_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
     824:                                 : cp0_priv_mode[1:0] == 2'b00;
     825: assign thd_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
```

`mmu/rtl/twu.sv:825`

```systemverilog
     823: assign thd_chk_cp0_user_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b00
     824:                                 : cp0_priv_mode[1:0] == 2'b00;
>>   825: assign thd_chk_cp0_supv_mode = fst_chk_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b01
     826:                                       : cp0_priv_mode[1:0] == 2'b01;
     827: 
```

`mmu/rtl/twu.sv:828`

```systemverilog
     826:                                       : cp0_priv_mode[1:0] == 2'b01;
     827: 
>>   828: assign thd_chk_page_flt =  (!thd_chk_flg[0]                       // not valid
     829: 						||  !(thd_chk_flg[1] || cp0_mmu_mxr && thd_chk_flg[3])
     830: 								&& thd_chk_flg[2]         // write only
```

`mmu/rtl/twu.sv:854`

```systemverilog
     852: //! wait
     853: //!******************************************
>>   854: assign thd_chk_wait =    thd_chk_vld & (~thd_chk_page_flt) & (!refill_thd_chk_grant)
     855: 					  |  thd_chk_vld & thd_chk_page_flt & (!pgflt_thd_chk_grant);
     856: 
```

`mmu/rtl/twu.sv:874`

```systemverilog
     872:     else if(abort)
     873:         twu_pgflt_vld <= 1'b0;
>>   874:     else if(thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
     875:         twu_pgflt_vld <= 1'b1;
     876:     else if(scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
```

`mmu/rtl/twu.sv:876`

```systemverilog
     874:     else if(thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
     875:         twu_pgflt_vld <= 1'b1;
>>   876:     else if(scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
     877:         twu_pgflt_vld <= 1'b1;
     878:     else if(fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
```

`mmu/rtl/twu.sv:878`

```systemverilog
     876:     else if(scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
     877:         twu_pgflt_vld <= 1'b1;
>>   878:     else if(fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
     879:         twu_pgflt_vld <= 1'b1;
     880:     else if(pgflt_twu_grant)
```

`mmu/rtl/twu.sv:888`

```systemverilog
     886: 		twu_pgflt_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
     887: 		twu_pgflt_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
>>   888: 	end else if(thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))begin
     889: 		twu_pgflt_type[TYPE_WIDTH-1:0] <= thd_chk_type[TYPE_WIDTH-1:0];
     890: 		twu_pgflt_id[ID_WIDTH-1:0] <= thd_chk_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:891`

```systemverilog
     889: 		twu_pgflt_type[TYPE_WIDTH-1:0] <= thd_chk_type[TYPE_WIDTH-1:0];
     890: 		twu_pgflt_id[ID_WIDTH-1:0] <= thd_chk_id[ID_WIDTH-1:0];
>>   891: 	end else if(scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))begin
     892: 		twu_pgflt_type[TYPE_WIDTH-1:0] <= scd_chk_type[TYPE_WIDTH-1:0];
     893: 		twu_pgflt_id[ID_WIDTH-1:0] <= scd_chk_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:894`

```systemverilog
     892: 		twu_pgflt_type[TYPE_WIDTH-1:0] <= scd_chk_type[TYPE_WIDTH-1:0];
     893: 		twu_pgflt_id[ID_WIDTH-1:0] <= scd_chk_id[ID_WIDTH-1:0];
>>   894: 	end else if(fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))begin
     895: 		twu_pgflt_type[TYPE_WIDTH-1:0] <= fst_chk_type[TYPE_WIDTH-1:0];
     896: 		twu_pgflt_id[ID_WIDTH-1:0] <= fst_chk_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:902`

```systemverilog
     900: 
     901: 
>>   902: assign pgflt_thd_chk_grant = thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant);
     903: assign pgflt_scd_chk_grant = scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant) & (!pgflt_thd_chk_grant);
     904: assign pgflt_fst_chk_grant = fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant) & (!pgflt_scd_chk_grant & !pgflt_thd_chk_grant);
```

`mmu/rtl/twu.sv:903`

```systemverilog
     901: 
     902: assign pgflt_thd_chk_grant = thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant);
>>   903: assign pgflt_scd_chk_grant = scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant) & (!pgflt_thd_chk_grant);
     904: assign pgflt_fst_chk_grant = fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant) & (!pgflt_scd_chk_grant & !pgflt_thd_chk_grant);
     905: 
```

`mmu/rtl/twu.sv:904`

```systemverilog
     902: assign pgflt_thd_chk_grant = thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant);
     903: assign pgflt_scd_chk_grant = scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant) & (!pgflt_thd_chk_grant);
>>   904: assign pgflt_fst_chk_grant = fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant) & (!pgflt_scd_chk_grant & !pgflt_thd_chk_grant);
     905: 
     906: assign twu_l2tlb_ref_pgflt = twu_pgflt_vld;
```

`mmu/rtl/twu.sv:919`

```systemverilog
     917:     else if(abort)
     918:         twu_acc_err_vld <= 1'b0;
>>   919:     else if(thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
     920:         twu_acc_err_vld <= 1'b1;
     921:     else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
```

`mmu/rtl/twu.sv:921`

```systemverilog
     919:     else if(thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
     920:         twu_acc_err_vld <= 1'b1;
>>   921:     else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
     922:         twu_acc_err_vld <= 1'b1;
     923:     else if(fst_pmp_vld & fst_pmp_deny& fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
```

`mmu/rtl/twu.sv:923`

```systemverilog
     921:     else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
     922:         twu_acc_err_vld <= 1'b1;
>>   923:     else if(fst_pmp_vld & fst_pmp_deny& fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
     924:         twu_acc_err_vld <= 1'b1;
     925:     else if(acc_err_twu_grant)
```

`mmu/rtl/twu.sv:934`

```systemverilog
     932: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
     933: 		twu_acc_err_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
>>   934: 	end else if(thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
     935: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= thd_pmp_type[TYPE_WIDTH-1:0];
     936: 		twu_acc_err_id[ID_WIDTH-1:0] <= thd_pmp_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:937`

```systemverilog
     935: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= thd_pmp_type[TYPE_WIDTH-1:0];
     936: 		twu_acc_err_id[ID_WIDTH-1:0] <= thd_pmp_id[ID_WIDTH-1:0];
>>   937: 	end else if(scd_pmp_vld & scd_pmp_deny& scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
     938: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= scd_pmp_type[TYPE_WIDTH-1:0];
     939: 		twu_acc_err_id[ID_WIDTH-1:0] <= scd_pmp_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:940`

```systemverilog
     938: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= scd_pmp_type[TYPE_WIDTH-1:0];
     939: 		twu_acc_err_id[ID_WIDTH-1:0] <= scd_pmp_id[ID_WIDTH-1:0];
>>   940: 	end else if(fst_pmp_vld & fst_pmp_deny& fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))begin
     941: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= fst_pmp_type[TYPE_WIDTH-1:0];
     942: 		twu_acc_err_id[ID_WIDTH-1:0] <= fst_pmp_id[ID_WIDTH-1:0];
```

`mmu/rtl/twu.sv:948`

```systemverilog
     946: 
     947: 
>>   948: assign acc_err_thd_pmp_grant = thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant);
     949: assign acc_err_scd_pmp_grant = scd_pmp_vld & scd_pmp_deny & scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant);
     950: assign acc_err_fst_pmp_grant = fst_pmp_vld & fst_pmp_deny & fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant);
```

`mmu/rtl/twu.sv:949`

```systemverilog
     947: 
     948: assign acc_err_thd_pmp_grant = thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant);
>>   949: assign acc_err_scd_pmp_grant = scd_pmp_vld & scd_pmp_deny & scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant);
     950: assign acc_err_fst_pmp_grant = fst_pmp_vld & fst_pmp_deny & fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant);
     951: 
```

`mmu/rtl/twu.sv:967`

```systemverilog
     965: assign pmp_itlb_sel = fst_pmp_itlb_sel | scd_pmp_itlb_sel | thd_pmp_itlb_sel;
     966: 
>>   967: assign fst_pmp_sel = (!pmp_itlb_sel) & (!scd_pmp_vld) & (!thd_pmp_vld) & fst_pmp_vld;
     968: assign scd_pmp_sel = (!pmp_itlb_sel) & (!thd_pmp_vld) & scd_pmp_vld;
     969: assign thd_pmp_sel = (!pmp_itlb_sel) & thd_pmp_vld;
```

`mmu/rtl/twu.sv:968`

```systemverilog
     966: 
     967: assign fst_pmp_sel = (!pmp_itlb_sel) & (!scd_pmp_vld) & (!thd_pmp_vld) & fst_pmp_vld;
>>   968: assign scd_pmp_sel = (!pmp_itlb_sel) & (!thd_pmp_vld) & scd_pmp_vld;
     969: assign thd_pmp_sel = (!pmp_itlb_sel) & thd_pmp_vld;
     970: 
```

`mmu/rtl/twu.sv:1015`

```systemverilog
    1013: 
    1014: assign fst_csr_itlb_sel = fst_chk_csr_req & fst_chk_fetch_type;
>>  1015: assign scd_csr_itlb_sel = scd_chk_csr_req & scd_chk_fetch_type;
    1016: 
    1017: assign csr_itlb_sel = fst_csr_itlb_sel | scd_csr_itlb_sel;
```

`mmu/rtl/twu.sv:1017`

```systemverilog
    1015: assign scd_csr_itlb_sel = scd_chk_csr_req & scd_chk_fetch_type;
    1016: 
>>  1017: assign csr_itlb_sel = fst_csr_itlb_sel | scd_csr_itlb_sel;
    1018: 
    1019: assign fst_csr_sel = (!csr_itlb_sel) & (!scd_chk_csr_req) & fst_chk_csr_req;
```

`mmu/rtl/twu.sv:1019`

```systemverilog
    1017: assign csr_itlb_sel = fst_csr_itlb_sel | scd_csr_itlb_sel;
    1018: 
>>  1019: assign fst_csr_sel = (!csr_itlb_sel) & (!scd_chk_csr_req) & fst_chk_csr_req;
    1020: assign scd_csr_sel = (!csr_itlb_sel) & scd_chk_csr_req;
    1021: 
```

`mmu/rtl/twu.sv:1020`

```systemverilog
    1018: 
    1019: assign fst_csr_sel = (!csr_itlb_sel) & (!scd_chk_csr_req) & fst_chk_csr_req;
>>  1020: assign scd_csr_sel = (!csr_itlb_sel) & scd_chk_csr_req;
    1021: 
    1022: always_comb begin
```

`mmu/rtl/twu.sv:1214`

```systemverilog
    1212: 	case (ptw_cur_st)
    1213: 		TWU_IDLE:begin
>>  1214: 		if(csr_req & csr_grant[1])
    1215: 			ptw_nxt_st[2:0] = TWU_1G_CRS;
    1216: 		else if(csr_req & csr_grant[0])
```

`mmu/rtl/twu.sv:1216`

```systemverilog
    1214: 		if(csr_req & csr_grant[1])
    1215: 			ptw_nxt_st[2:0] = TWU_1G_CRS;
>>  1216: 		else if(csr_req & csr_grant[0])
    1217: 			ptw_nxt_st[2:0] = TWU_2M_CRS;
    1218: 		else
```

`mmu/rtl/twu.sv:1263`

```systemverilog
    1261: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
    1262: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
>>  1263: 	end else if(csr_grant[1] & csr_idle)begin
    1264: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
    1265: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH], 18'h3ffff, 12'b0};
```

`mmu/rtl/twu.sv:1266`

```systemverilog
    1264: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
    1265: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH], 18'h3ffff, 12'b0};
>>  1266: 	end else if(csr_grant[0] & csr_idle)begin
    1267: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
    1268: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH-9], 9'h1ff, 12'b0};
```

`mmu/rtl/twu.sv:1269`

```systemverilog
    1267: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
    1268: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH-9], 9'h1ff, 12'b0};
>>  1269: 	end else if(twu_crs_1g & twu_csr_cross)begin
    1270: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 21'b0};
    1271: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 9'h1ff, 12'b0};
```

`mmu/rtl/twu.sv:1272`

```systemverilog
    1270: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 21'b0};
    1271: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH], csr_vpn_flop[17:9], 9'h1ff, 12'b0};
>>  1272: 	end else if(twu_crs_2m & twu_csr_cross)begin
    1273: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= twu_sysmap_adderx1[PADDR_WIDTH-1:0];
    1274: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data_flop[PPN_WIDTH+9:PPN_WIDTH-9], csr_vpn_flop[8:0], 12'b0};
```

`mmu/rtl/twu.sv:1283`

```systemverilog
    1281: 	else if(csr_req & csr_idle)
    1282: 		csr_data_flop[DATA_WIDTH-6:0] <= csr_data[DATA_WIDTH-6:0];
>>  1283: 	else if(twu_crs_1g && twu_csr_cross)
    1284: 		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH], csr_vpn_flop[17:9], csr_data_flop[18:0]};
    1285: 	else if(twu_crs_2m && twu_csr_cross)
```

`mmu/rtl/twu.sv:1285`

```systemverilog
    1283: 	else if(twu_crs_1g && twu_csr_cross)
    1284: 		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH], csr_vpn_flop[17:9], csr_data_flop[18:0]};
>>  1285: 	else if(twu_crs_2m && twu_csr_cross)
    1286: 		csr_data_flop[DATA_WIDTH-6:0] <= {csr_data_flop[58:PPN_WIDTH-9], csr_vpn_flop[8:0], csr_data_flop[9:0]};
    1287: end
```

`mmu/rtl/twu.sv:1294`

```systemverilog
    1292: 	else if(csr_req & csr_idle)
    1293: 		csr_refill_pgs[PGS_WIDTH-1:0] <= {csr_grant[1:0],1'b0};
>>  1294: 	else if(twu_crs_1g && twu_csr_cross)
    1295: 		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b010;
    1296: 	else if(twu_crs_2m && twu_csr_cross)
```

`mmu/rtl/twu.sv:1296`

```systemverilog
    1294: 	else if(twu_crs_1g && twu_csr_cross)
    1295: 		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b010;
>>  1296: 	else if(twu_crs_2m && twu_csr_cross)
    1297: 		csr_refill_pgs[PGS_WIDTH-1:0] <= 3'b001;
    1298: end
```

`mmu/rtl/twu.sv:1301`

```systemverilog
    1299: 
    1300: 
>>  1301: assign twu_csr_cross = twu_crs_chk & (sysmap_mmu_hitx1[7:0] != sysmap_mmu_hitx2[7:0]);
    1302: assign sysmap_mmu_flg[4:0] = sysmap_mmu_flgx2[4:0];
    1303: 
```

`mmu/rtl/twu.sv:1365`

```systemverilog
    1363: assign twu_arb_ref_req = twu_refill_vld;
    1364: 
>>  1365: assign fst_chk_itlb_sel = fst_chk_refill_req & fst_chk_fetch_type;
    1366: assign scd_chk_itlb_sel = scd_chk_refill_req & scd_chk_fetch_type;
    1367: assign thd_chk_itlb_sel = thd_chk_refill_req & thd_chk_fetch_type;
```

`mmu/rtl/twu.sv:1366`

```systemverilog
    1364: 
    1365: assign fst_chk_itlb_sel = fst_chk_refill_req & fst_chk_fetch_type;
>>  1366: assign scd_chk_itlb_sel = scd_chk_refill_req & scd_chk_fetch_type;
    1367: assign thd_chk_itlb_sel = thd_chk_refill_req & thd_chk_fetch_type;
    1368: assign csr_ref_itlb_sel = csr_refill_req & csr_fetch_type;
```

`mmu/rtl/twu.sv:1370`

```systemverilog
    1368: assign csr_ref_itlb_sel = csr_refill_req & csr_fetch_type;
    1369: 
>>  1370: assign refill_itlb_sel = fst_chk_itlb_sel | scd_chk_itlb_sel | thd_chk_itlb_sel | csr_ref_itlb_sel;
    1371: 
    1372: assign fst_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & (!scd_chk_refill_req) & fst_chk_refill_req;
```

`mmu/rtl/twu.sv:1372`

```systemverilog
    1370: assign refill_itlb_sel = fst_chk_itlb_sel | scd_chk_itlb_sel | thd_chk_itlb_sel | csr_ref_itlb_sel;
    1371: 
>>  1372: assign fst_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & (!scd_chk_refill_req) & fst_chk_refill_req;
    1373: assign scd_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & scd_chk_refill_req;
    1374: assign thd_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & thd_chk_refill_req;
```

`mmu/rtl/twu.sv:1373`

```systemverilog
    1371: 
    1372: assign fst_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & (!scd_chk_refill_req) & fst_chk_refill_req;
>>  1373: assign scd_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & scd_chk_refill_req;
    1374: assign thd_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & thd_chk_refill_req;
    1375: assign csr_ref_sel = (!refill_itlb_sel) & csr_refill_req;
```

`mmu/rtl/twu.sv:1374`

```systemverilog
    1372: assign fst_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & (!scd_chk_refill_req) & fst_chk_refill_req;
    1373: assign scd_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & (!thd_chk_refill_req) & scd_chk_refill_req;
>>  1374: assign thd_ref_sel = (!refill_itlb_sel) & (!csr_refill_req) & thd_chk_refill_req;
    1375: assign csr_ref_sel = (!refill_itlb_sel) & csr_refill_req;
    1376: 
```

`mmu/rtl/twu.sv:1435`

```systemverilog
    1433: 		twu_ref_type[TYPE_WIDTH-1:0] <= thd_chk_refill_type[TYPE_WIDTH-1:0];
    1434: 		twu_ref_id[ID_WIDTH-1:0] <= thd_chk_refill_id[ID_WIDTH-1:0];
>>  1435: 	end else if(refill_grant[1] & twu_refill_idle)begin
    1436: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= scd_chk_refill_data[RDATA_WIDTH-1:0];
    1437: 		twu_ref_tag_din[TAG_WIDTH-1:0] = scd_chk_refill_tag[TAG_WIDTH-1:0];
```

`mmu/rtl/twu.sv:1441`

```systemverilog
    1439: 		twu_ref_type[TYPE_WIDTH-1:0] <= scd_chk_refill_type[TYPE_WIDTH-1:0];
    1440: 		twu_ref_id[ID_WIDTH-1:0] <= scd_chk_refill_id[ID_WIDTH-1:0];
>>  1441: 	end else if(refill_grant[2] & twu_refill_idle)begin
    1442: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= fst_chk_refill_data[RDATA_WIDTH-1:0];
    1443: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= fst_chk_refill_tag[TAG_WIDTH-1:0];
```

`mmu/rtl/twu.sv:1447`

```systemverilog
    1445: 		twu_ref_type[TYPE_WIDTH-1:0] <= fst_chk_refill_type[TYPE_WIDTH-1:0];
    1446: 		twu_ref_id[ID_WIDTH-1:0] <= fst_chk_refill_id[ID_WIDTH-1:0];
>>  1447: 	end else if(refill_grant[3] & twu_refill_idle)begin
    1448: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= csr_refill_data[RDATA_WIDTH-1:0];
    1449: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= csr_refill_tag[TAG_WIDTH-1:0];
```

`mmu/rtl/twu.sv:1462`

```systemverilog
    1460: assign twu_arb_ref_id[ID_WIDTH-1:0] = twu_ref_id[ID_WIDTH-1:0];
    1461: 
>>  1462: assign refill_csr_grant = refill_grant[3] & twu_refill_idle;
    1463: assign refill_fst_chk_grant = refill_grant[2] & twu_refill_idle;
    1464: assign refill_scd_chk_grant = refill_grant[1] & twu_refill_idle;
```

`mmu/rtl/twu.sv:1463`

```systemverilog
    1461: 
    1462: assign refill_csr_grant = refill_grant[3] & twu_refill_idle;
>>  1463: assign refill_fst_chk_grant = refill_grant[2] & twu_refill_idle;
    1464: assign refill_scd_chk_grant = refill_grant[1] & twu_refill_idle;
    1465: assign refill_thd_chk_grant = refill_grant[0] & twu_refill_idle;
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 405 | `if(!cpurst_b)` | 0 0 1 - Not Covered x4 | 4 |
| 467 | `if(!cpurst_b)` | 0 0 1 - Not Covered | 1 |
| 557 | `if(!cpurst_b)` | 0 0 1 - - Not Covered x2 | 2 |
| 632 | `if(!cpurst_b)` | 0 0 1 - Not Covered x2 | 2 |
| 915 | `if(!cpurst_b)` | 0 0 0 1 - - Not Covered x4 | 4 |
| 931 | `if(!cpurst_b)begin` | 0 0 1 - Not Covered x4 | 4 |
| 1212 | `case (ptw_cur_st)` | default - - - - Not Covered x4 | 4 |
| 1260 | `if (!cpurst_b)begin` | 0 0 0 0 1 Not Covered x2 | 2 |
| 1279 | `if (!cpurst_b)` | 0 0 0 1 Not Covered x2 | 2 |
| 1290 | `if (!cpurst_b)` | 0 0 0 1 Not Covered x2 | 2 |
| 1378 | `case({refill_itlb_sel,csr_ref_sel,fst_ref_sel,scd_ref_sel,thd_ref_sel})` | 5'b00100 Not Covered | 1 |
| 1423 | `if(!cpurst_b)begin` | 0 0 0 1 - Not Covered | 1 |

`mmu/rtl/twu.sv:405`

```systemverilog
     403: //==============================================================================
     404: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>   405: 	if(!cpurst_b)
     406: 		fst_pmp_vld <= 1'b0;
     407: 	else if(abort)
```

`mmu/rtl/twu.sv:467`

```systemverilog
     465: 
     466: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>   467: 	if(!cpurst_b)
     468: 		fst_chk_vld <= 1'b0;
     469: 	else if(abort)
```

`mmu/rtl/twu.sv:557`

```systemverilog
     555: //==============================================================================
     556: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>   557: 	if(!cpurst_b)
     558: 		scd_pmp_vld <= 1'b0;
     559: 	else if(abort)
```

`mmu/rtl/twu.sv:632`

```systemverilog
     630: 
     631: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>   632: 	if(!cpurst_b)
     633: 		scd_chk_vld <= 1'b0;
     634: 	else if(abort)
```

`mmu/rtl/twu.sv:915`

```systemverilog
     913: //==============================================================================
     914: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>   915:     if(!cpurst_b)
     916:         twu_acc_err_vld <= 1'b0;
     917:     else if(abort)
```

`mmu/rtl/twu.sv:931`

```systemverilog
     929: 
     930: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>   931: 	if(!cpurst_b)begin
     932: 		twu_acc_err_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
     933: 		twu_acc_err_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
```

`mmu/rtl/twu.sv:1212`

```systemverilog
    1210: 
    1211: always_comb begin
>>  1212: 	case (ptw_cur_st)
    1213: 		TWU_IDLE:begin
    1214: 		if(csr_req & csr_grant[1])
```

`mmu/rtl/twu.sv:1260`

```systemverilog
    1258: 
    1259: always_ff @(posedge twu_clk or negedge cpurst_b)begin
>>  1260: 	if (!cpurst_b)begin
    1261: 		twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
    1262: 		twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {PADDR_WIDTH{1'b0}};
```

`mmu/rtl/twu.sv:1279`

```systemverilog
    1277: 
    1278: always_ff @(posedge twu_clk or negedge cpurst_b)begin
>>  1279: 	if (!cpurst_b)
    1280: 		csr_data_flop[DATA_WIDTH-6:0] <= {DATA_WIDTH-6{1'b0}};
    1281: 	else if(csr_req & csr_idle)
```

`mmu/rtl/twu.sv:1290`

```systemverilog
    1288: 
    1289: always @(posedge twu_clk or negedge cpurst_b)begin
>>  1290: 	if (!cpurst_b)
    1291: 		csr_refill_pgs[PGS_WIDTH-1:0] <= {PGS_WIDTH{1'b0}};
    1292: 	else if(csr_req & csr_idle)
```

`mmu/rtl/twu.sv:1378`

```systemverilog
    1376: 
    1377: always_comb begin
>>  1378:     case({refill_itlb_sel,csr_ref_sel,fst_ref_sel,scd_ref_sel,thd_ref_sel})
    1379:         5'b10000    : refill_grant[3:0] = {csr_ref_itlb_sel,fst_chk_itlb_sel,scd_chk_itlb_sel,thd_chk_itlb_sel};
    1380:         5'b01000    : refill_grant[3:0] = 4'b1000;
```

`mmu/rtl/twu.sv:1423`

```systemverilog
    1421: 
    1422: always_ff@(posedge twu_clk or negedge cpurst_b) begin
>>  1423: 	if(!cpurst_b)begin
    1424: 		twu_ref_data_din[RDATA_WIDTH-1:0] <= {RDATA_WIDTH{1'b0}};
    1425: 		twu_ref_tag_din[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
```

### FSM 状态迁移覆盖

说明：这里列出状态机未覆盖的状态迁移，通常需要特定状态跳转场景才能命中。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 1204 | `TWU_1G_CRS->TWU_IDLE` | Not Covered x4 | 4 |
| 1204 | `TWU_2M_CRS->TWU_IDLE` | Not Covered x4 | 4 |

`mmu/rtl/twu.sv:1204`

```systemverilog
    1202: always_ff @(posedge twu_clk or negedge cpurst_b)begin
    1203: 	if (!cpurst_b)
>>  1204: 		ptw_cur_st[2:0] <= TWU_IDLE;
    1205: 	else if(abort)
    1206: 		ptw_cur_st[2:0] <= TWU_IDLE;
```

### 翻转覆盖 - 端口

说明：这里列出 PTW 子树实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 27 | `twu_idx[3:0] -> input logic [3:0] twu_idx,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 35 | `cp0_mmu_mpp[0] -> input logic [1:0] cp0_mmu_mpp,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT x4 | 4 |
| 42 | `regs_ptw_cur_asid[15:5] -> input logic [ASID_WIDTH-1:0] regs_ptw_cur_asid,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x4 | 4 |
| 43 | `regs_ptw_satp_ppn[27:7] -> input logic [PPN_WIDTH-1:0] regs_ptw_satp_ppn,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x4 | 4 |
| 50 | `xbar_twu_ppn[27:11] -> input logic [PPN_WIDTH-1:0] xbar_twu_ppn,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 62 | `mbuf_twu_data[33:32] -> input logic [DATA_WIDTH-1:0] mbuf_twu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 62 | `mbuf_twu_data[58:55] -> input logic [DATA_WIDTH-1:0] mbuf_twu_data,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 71 | `sysmap_mmu_flgx1[0] -> input logic [4:0] sysmap_mmu_flgx1,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 71 | `sysmap_mmu_flgx1[1:0] -> input logic [4:0] sysmap_mmu_flgx1,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 71 | `sysmap_mmu_flgx1[1] -> input logic [4:0] sysmap_mmu_flgx1,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 71 | `sysmap_mmu_flgx1[3:1] -> input logic [4:0] sysmap_mmu_flgx1,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 71 | `sysmap_mmu_flgx1[3:2] -> input logic [4:0] sysmap_mmu_flgx1,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT | 1 |
| 71 | `sysmap_mmu_flgx1[4] -> input logic [4:0] sysmap_mmu_flgx1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 72 | `sysmap_mmu_flgx2[0] -> input logic [4:0] sysmap_mmu_flgx2,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 72 | `sysmap_mmu_flgx2[1:0] -> input logic [4:0] sysmap_mmu_flgx2,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 73 | `sysmap_mmu_flgx3[0] -> input logic [4:0] sysmap_mmu_flgx3,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 73 | `sysmap_mmu_flgx3[1] -> input logic [4:0] sysmap_mmu_flgx3,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT x3 | 3 |
| 74 | `sysmap_mmu_hitx1[0] -> input logic [7:0] sysmap_mmu_hitx1,` | Toggle=No, 1->0=Yes, 0->1=No, Direction=INPUT x2 | 2 |
| 74 | `sysmap_mmu_hitx1[1] -> input logic [7:0] sysmap_mmu_hitx1,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT | 2 |
| 74 | `sysmap_mmu_hitx1[2] -> input logic [7:0] sysmap_mmu_hitx1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x2 | 2 |
| 74 | `sysmap_mmu_hitx1[7:2] -> input logic [7:0] sysmap_mmu_hitx1,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 74 | `sysmap_mmu_hitx1[7:3] -> input logic [7:0] sysmap_mmu_hitx1,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 75 | `sysmap_mmu_hitx2[7:2] -> input logic [7:0] sysmap_mmu_hitx2,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 75 | `sysmap_mmu_hitx2[7:4] -> input logic [7:0] sysmap_mmu_hitx2,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x2 | 2 |
| 76 | `sysmap_mmu_hitx3[3:2] -> input logic [7:0] sysmap_mmu_hitx3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x3 | 3 |
| 76 | `sysmap_mmu_hitx3[6:4] -> input logic [7:0] sysmap_mmu_hitx3,` | Toggle=No, 1->0=No, 0->1=No, Direction=INPUT x4 | 4 |
| 76 | `sysmap_mmu_hitx3[7] -> input logic [7:0] sysmap_mmu_hitx3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=INPUT x4 | 4 |
| 83 | `twu_mbuf_paddr[2:0] -> output logic [PADDR_WIDTH-1:0] twu_mbuf_paddr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 83 | `twu_mbuf_paddr[39:22] -> output logic [PADDR_WIDTH-1:0] twu_mbuf_paddr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 83 | `twu_mbuf_paddr[39:23] -> output logic [PADDR_WIDTH-1:0] twu_mbuf_paddr,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 86 | `twu_mbuf_id[6] -> output logic [ID_WIDTH-1:0] twu_mbuf_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 88 | `twu_mbuf_twu_idx[3:0] -> output logic [3:0] twu_mbuf_twu_idx,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 89 | `twu_mbuf_pmpflg[3] -> output logic [7:0] twu_mbuf_pmpflg,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 89 | `twu_mbuf_pmpflg[7] -> output logic [7:0] twu_mbuf_pmpflg,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 95 | `mmu_pmp_pa[27:10] -> output logic [PPN_WIDTH-1:0] mmu_pmp_pa,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 95 | `mmu_pmp_pa[27:11] -> output logic [PPN_WIDTH-1:0] mmu_pmp_pa,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[10:9] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 2 |
| 97 | `mmu_sysmap_pax1[12] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[13:10] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[13:12] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[13] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 2 |
| 97 | `mmu_sysmap_pax1[14] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[15:14] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[16] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[17:15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[17] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[19:17] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[19:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 97 | `mmu_sysmap_pax1[27:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[27:20] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[8:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 97 | `mmu_sysmap_pax1[9:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax1,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 98 | `mmu_sysmap_pax2[0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax2,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 98 | `mmu_sysmap_pax2[18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax2,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x2 | 2 |
| 98 | `mmu_sysmap_pax2[19:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax2,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x2 | 2 |
| 98 | `mmu_sysmap_pax2[27:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax2,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 98 | `mmu_sysmap_pax2[27:20] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax2,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 98 | `mmu_sysmap_pax2[8:0] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax2,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x2 | 2 |
| 99 | `mmu_sysmap_pax3[11:10] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 99 | `mmu_sysmap_pax3[11] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x3 | 3 |
| 99 | `mmu_sysmap_pax3[15] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 99 | `mmu_sysmap_pax3[20:18] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x3 | 3 |
| 99 | `mmu_sysmap_pax3[20:19] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 99 | `mmu_sysmap_pax3[23:21] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 99 | `mmu_sysmap_pax3[27:24] -> output logic [PPN_WIDTH-1:0] mmu_sysmap_pax3,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x4 | 4 |
| 105 | `twu_arb_ref_data_din[0] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[25:24] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[25] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[2:0] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x3 | 3 |
| 105 | `twu_arb_ref_data_din[2] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[32] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[34:33] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x3 | 3 |
| 105 | `twu_arb_ref_data_din[34] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[37:35] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 105 | `twu_arb_ref_data_din[41:38] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x4 | 4 |
| 105 | `twu_arb_ref_data_din[4] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x3 | 3 |
| 105 | `twu_arb_ref_data_din[6:5] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[7:5] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 105 | `twu_arb_ref_data_din[8:5] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x2 | 2 |
| 105 | `twu_arb_ref_data_din[8] -> output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[0] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x3 | 3 |
| 106 | `twu_arb_ref_tag_din[10:5] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[10:7] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x2 | 2 |
| 106 | `twu_arb_ref_tag_din[11] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x3 | 3 |
| 106 | `twu_arb_ref_tag_din[15:12] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x3 | 3 |
| 106 | `twu_arb_ref_tag_din[15:8] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[19:16] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 106 | `twu_arb_ref_tag_din[2] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[31] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[43:41] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[43] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[44] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[46:45] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 106 | `twu_arb_ref_tag_din[46] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 106 | `twu_arb_ref_tag_din[47] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x4 | 4 |
| 106 | `twu_arb_ref_tag_din[4] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 106 | `twu_arb_ref_tag_din[6:4] -> output logic [TAG_WIDTH-1:0] twu_arb_ref_tag_din,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 107 | `twu_arb_ref_pgs[1] -> output logic [PGS_WIDTH-1:0] twu_arb_ref_pgs,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 109 | `twu_arb_ref_id[6] -> output logic [ID_WIDTH-1:0] twu_arb_ref_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT; Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 2 |
| 115 | `twu_l2tlb_ref_pgflt_id[6] -> output logic [ID_WIDTH-1:0] twu_l2tlb_ref_pgflt_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |
| 116 | `twu_l2tlb_ref_pgflt_type[0] -> output logic [TYPE_WIDTH-1:0] twu_l2tlb_ref_pgflt_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT | 1 |
| 118 | `twu_l2tlb_ref_acc_err_type[1] -> output logic [TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,` | Toggle=No, 1->0=No, 0->1=Yes, Direction=OUTPUT x4 | 4 |
| 119 | `twu_l2tlb_ref_acc_err_id[2:1] -> output logic [ID_WIDTH-1:0] twu_l2tlb_ref_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 119 | `twu_l2tlb_ref_acc_err_id[6:5] -> output logic [ID_WIDTH-1:0] twu_l2tlb_ref_acc_err_id,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x4 | 4 |
| 125 | `twu_data_ready[1] -> output logic [PTE_LEVEL-1:0] twu_data_ready,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT x2 | 2 |
| 125 | `twu_data_ready[2] -> output logic [PTE_LEVEL-1:0] twu_data_ready,` | Toggle=No, 1->0=No, 0->1=No, Direction=OUTPUT | 1 |

`mmu/rtl/twu.sv:27`

```systemverilog
      25:     input  logic                   forever_cpuclk,
      26:     input  logic                   cpurst_b,
>>    27:     input  logic [3:0]             twu_idx,
      28:     input  logic                   refill_arb_twu_grant,
      29: 
```

`mmu/rtl/twu.sv:35`

```systemverilog
      33:     input  logic                   cp0_mmu_icg_en,
      34:     input  logic                   cp0_mmu_maee,
>>    35:     input  logic [1:0]             cp0_mmu_mpp,
      36:     input  logic                   cp0_mmu_mprv,
      37:     input  logic                   cp0_mmu_mxr,
```

`mmu/rtl/twu.sv:42`

```systemverilog
      40:     input  logic                   pad_yy_icg_scan_en,
      41: 
>>    42:     input  logic [ASID_WIDTH-1:0]  regs_ptw_cur_asid,
      43:     input  logic [PPN_WIDTH-1:0]   regs_ptw_satp_ppn,
      44: 
```

`mmu/rtl/twu.sv:43`

```systemverilog
      41: 
      42:     input  logic [ASID_WIDTH-1:0]  regs_ptw_cur_asid,
>>    43:     input  logic [PPN_WIDTH-1:0]   regs_ptw_satp_ppn,
      44: 
      45: //!******************************************
```

`mmu/rtl/twu.sv:50`

```systemverilog
      48:     input  logic                   xbar_twu_req,
      49:     input  logic [PTE_LEVEL-2:0]   xbar_twu_hit_level,
>>    50:     input  logic [PPN_WIDTH-1:0]   xbar_twu_ppn,
      51:     input  logic [VPN_WIDTH-1:0]   xbar_twu_vpn,
      52:     input  logic [TYPE_WIDTH-1:0]  xbar_twu_type,
```

`mmu/rtl/twu.sv:62`

```systemverilog
      60:     input  logic [TYPE_WIDTH-1:0]  mbuf_twu_type,
      61:     input  logic [ID_WIDTH-1:0]    mbuf_twu_id,
>>    62:     input  logic [DATA_WIDTH-1:0]  mbuf_twu_data,
      63: 	input  logic [7:0]             mbuf_twu_pmpflg,
      64:     input  logic                   mbuf_twu_data_vld,
```

`mmu/rtl/twu.sv:71`

```systemverilog
      69: //! sysmap and pmp
      70: //!******************************************
>>    71:     input  logic [4:0]             sysmap_mmu_flgx1,
      72:     input  logic [4:0]             sysmap_mmu_flgx2,
      73:     input  logic [4:0]             sysmap_mmu_flgx3,
```

`mmu/rtl/twu.sv:72`

```systemverilog
      70: //!******************************************
      71:     input  logic [4:0]             sysmap_mmu_flgx1,
>>    72:     input  logic [4:0]             sysmap_mmu_flgx2,
      73:     input  logic [4:0]             sysmap_mmu_flgx3,
      74:     input  logic [7:0]             sysmap_mmu_hitx1,
```

`mmu/rtl/twu.sv:73`

```systemverilog
      71:     input  logic [4:0]             sysmap_mmu_flgx1,
      72:     input  logic [4:0]             sysmap_mmu_flgx2,
>>    73:     input  logic [4:0]             sysmap_mmu_flgx3,
      74:     input  logic [7:0]             sysmap_mmu_hitx1,
      75:     input  logic [7:0]             sysmap_mmu_hitx2,
```

`mmu/rtl/twu.sv:74`

```systemverilog
      72:     input  logic [4:0]             sysmap_mmu_flgx2,
      73:     input  logic [4:0]             sysmap_mmu_flgx3,
>>    74:     input  logic [7:0]             sysmap_mmu_hitx1,
      75:     input  logic [7:0]             sysmap_mmu_hitx2,
      76:     input  logic [7:0]             sysmap_mmu_hitx3,
```

`mmu/rtl/twu.sv:75`

```systemverilog
      73:     input  logic [4:0]             sysmap_mmu_flgx3,
      74:     input  logic [7:0]             sysmap_mmu_hitx1,
>>    75:     input  logic [7:0]             sysmap_mmu_hitx2,
      76:     input  logic [7:0]             sysmap_mmu_hitx3,
      77:     input  logic [3:0]             pmp_mmu_flg,
```

`mmu/rtl/twu.sv:76`

```systemverilog
      74:     input  logic [7:0]             sysmap_mmu_hitx1,
      75:     input  logic [7:0]             sysmap_mmu_hitx2,
>>    76:     input  logic [7:0]             sysmap_mmu_hitx3,
      77:     input  logic [3:0]             pmp_mmu_flg,
      78: 
```

`mmu/rtl/twu.sv:83`

```systemverilog
      81: //!******************************************
      82:     output logic                   twu_mbuf_req,
>>    83:     output logic [PADDR_WIDTH-1:0] twu_mbuf_paddr,
      84:     output logic [VPN_WIDTH-1:0]   twu_mbuf_vpn,
      85:     output logic [TYPE_WIDTH-1:0]  twu_mbuf_type,
```

`mmu/rtl/twu.sv:86`

```systemverilog
      84:     output logic [VPN_WIDTH-1:0]   twu_mbuf_vpn,
      85:     output logic [TYPE_WIDTH-1:0]  twu_mbuf_type,
>>    86:     output logic [ID_WIDTH-1:0]    twu_mbuf_id,
      87:     output logic [PTE_LEVEL-1:0]   twu_mbuf_lvl,
      88:     output logic [3:0]             twu_mbuf_twu_idx,
```

`mmu/rtl/twu.sv:88`

```systemverilog
      86:     output logic [ID_WIDTH-1:0]    twu_mbuf_id,
      87:     output logic [PTE_LEVEL-1:0]   twu_mbuf_lvl,
>>    88:     output logic [3:0]             twu_mbuf_twu_idx,
      89:     output logic [7:0]             twu_mbuf_pmpflg,
      90: //output logic		twu_mbuf_mask,
```

`mmu/rtl/twu.sv:89`

```systemverilog
      87:     output logic [PTE_LEVEL-1:0]   twu_mbuf_lvl,
      88:     output logic [3:0]             twu_mbuf_twu_idx,
>>    89:     output logic [7:0]             twu_mbuf_pmpflg,
      90: //output logic		twu_mbuf_mask,
      91: 
```

`mmu/rtl/twu.sv:95`

```systemverilog
      93: //! TWU to sysmap and pmp
      94: //!******************************************
>>    95:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa,
      96:     output logic                   mmu_pmp_fecth,
      97:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax1,
```

`mmu/rtl/twu.sv:97`

```systemverilog
      95:     output logic [PPN_WIDTH-1:0]   mmu_pmp_pa,
      96:     output logic                   mmu_pmp_fecth,
>>    97:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax1,
      98:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax2,
      99:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax3,
```

`mmu/rtl/twu.sv:98`

```systemverilog
      96:     output logic                   mmu_pmp_fecth,
      97:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax1,
>>    98:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax2,
      99:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax3,
     100: 
```

`mmu/rtl/twu.sv:99`

```systemverilog
      97:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax1,
      98:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax2,
>>    99:     output logic [PPN_WIDTH-1:0]   mmu_sysmap_pax3,
     100: 
     101: //!******************************************
```

`mmu/rtl/twu.sv:105`

```systemverilog
     103: //!******************************************
     104:     output logic                   twu_arb_ref_req,
>>   105:     output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,
     106:     output logic [TAG_WIDTH-1:0]   twu_arb_ref_tag_din,
     107:     output logic [PGS_WIDTH-1:0]   twu_arb_ref_pgs,
```

`mmu/rtl/twu.sv:106`

```systemverilog
     104:     output logic                   twu_arb_ref_req,
     105:     output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,
>>   106:     output logic [TAG_WIDTH-1:0]   twu_arb_ref_tag_din,
     107:     output logic [PGS_WIDTH-1:0]   twu_arb_ref_pgs,
     108:     output logic [TYPE_WIDTH-1:0]  twu_arb_ref_type,
```

`mmu/rtl/twu.sv:107`

```systemverilog
     105:     output logic [RDATA_WIDTH-1:0] twu_arb_ref_data_din,
     106:     output logic [TAG_WIDTH-1:0]   twu_arb_ref_tag_din,
>>   107:     output logic [PGS_WIDTH-1:0]   twu_arb_ref_pgs,
     108:     output logic [TYPE_WIDTH-1:0]  twu_arb_ref_type,
     109:     output logic [ID_WIDTH-1:0]    twu_arb_ref_id,
```

`mmu/rtl/twu.sv:109`

```systemverilog
     107:     output logic [PGS_WIDTH-1:0]   twu_arb_ref_pgs,
     108:     output logic [TYPE_WIDTH-1:0]  twu_arb_ref_type,
>>   109:     output logic [ID_WIDTH-1:0]    twu_arb_ref_id,
     110: 
     111: //!******************************************
```

`mmu/rtl/twu.sv:115`

```systemverilog
     113: //!******************************************
     114:     output logic                   twu_l2tlb_ref_pgflt,
>>   115:     output logic [ID_WIDTH-1:0]    twu_l2tlb_ref_pgflt_id,
     116:     output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_pgflt_type,
     117:     output logic                   twu_l2tlb_ref_acc_err,
```

`mmu/rtl/twu.sv:116`

```systemverilog
     114:     output logic                   twu_l2tlb_ref_pgflt,
     115:     output logic [ID_WIDTH-1:0]    twu_l2tlb_ref_pgflt_id,
>>   116:     output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_pgflt_type,
     117:     output logic                   twu_l2tlb_ref_acc_err,
     118:     output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_acc_err_type,
```

`mmu/rtl/twu.sv:118`

```systemverilog
     116:     output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_pgflt_type,
     117:     output logic                   twu_l2tlb_ref_acc_err,
>>   118:     output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_acc_err_type,
     119:     output logic [ID_WIDTH-1:0]    twu_l2tlb_ref_acc_err_id,
     120: //!******************************************
```

`mmu/rtl/twu.sv:119`

```systemverilog
     117:     output logic                   twu_l2tlb_ref_acc_err,
     118:     output logic [TYPE_WIDTH-1:0]  twu_l2tlb_ref_acc_err_type,
>>   119:     output logic [ID_WIDTH-1:0]    twu_l2tlb_ref_acc_err_id,
     120: //!******************************************
     121: //! TWU to xbar
```

`mmu/rtl/twu.sv:125`

```systemverilog
     123:     output logic                   twu_mask,
     124: //output logic 		twu_idle,
>>   125:     output logic [PTE_LEVEL-1:0]   twu_data_ready,
     126: 
     127:     input  logic                   acc_err_twu_grant,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响实例数 |
| ---: | --- | --- | ---: |
| 149 | `fst_pmp_wait -> logic fst_pmp_wait ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 150 | `fst_chk_wait -> logic fst_chk_wait ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 151 | `scd_pmp_wait -> logic scd_pmp_wait ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 152 | `scd_chk_wait -> logic scd_chk_wait ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 157 | `fst_pmp_id[6] -> logic [ID_WIDTH-1:0] fst_pmp_id ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 158 | `scd_pmp_vpn[15] -> logic [VPN_WIDTH-1:0] scd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 158 | `scd_pmp_vpn[20:19] -> logic [VPN_WIDTH-1:0] scd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 158 | `scd_pmp_vpn[23] -> logic [VPN_WIDTH-1:0] scd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 158 | `scd_pmp_vpn[26:21] -> logic [VPN_WIDTH-1:0] scd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 158 | `scd_pmp_vpn[26:25] -> logic [VPN_WIDTH-1:0] scd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 158 | `scd_pmp_vpn[26] -> logic [VPN_WIDTH-1:0] scd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 160 | `scd_pmp_id[6] -> logic [ID_WIDTH-1:0] scd_pmp_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 161 | `thd_pmp_vpn[21] -> logic [VPN_WIDTH-1:0] thd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 161 | `thd_pmp_vpn[23] -> logic [VPN_WIDTH-1:0] thd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 161 | `thd_pmp_vpn[24] -> logic [VPN_WIDTH-1:0] thd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 161 | `thd_pmp_vpn[26:21] -> logic [VPN_WIDTH-1:0] thd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 161 | `thd_pmp_vpn[26:25] -> logic [VPN_WIDTH-1:0] thd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 161 | `thd_pmp_vpn[26] -> logic [VPN_WIDTH-1:0] thd_pmp_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 163 | `thd_pmp_id[6] -> logic [ID_WIDTH-1:0] thd_pmp_id ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 166 | `fst_chk_id[6] -> logic [ID_WIDTH-1:0] fst_chk_id ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 167 | `fst_chk_data[10:8] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[10] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[13] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[16] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 167 | `fst_chk_data[17] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[18] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[19] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[20:15] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[20:19] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[27:20] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 167 | `fst_chk_data[27:21] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 167 | `fst_chk_data[28] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[29:28] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[37:29] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[39] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[3:1] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[41] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[43] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[45] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[47] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[49:30] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[49] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[4] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 167 | `fst_chk_data[50] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[51] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[53] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[58:30] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[58:55] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[59:29] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[59] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[5:4] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 167 | `fst_chk_data[5] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[60:51] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[61:59] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[61] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 167 | `fst_chk_data[62] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[63:61] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[63:62] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 167 | `fst_chk_data[8] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[9:6] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 167 | `fst_chk_data[9] -> logic [DATA_WIDTH-1:0] fst_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 168 | `scd_chk_vpn[15] -> logic [VPN_WIDTH-1:0] scd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 168 | `scd_chk_vpn[20:19] -> logic [VPN_WIDTH-1:0] scd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 168 | `scd_chk_vpn[23] -> logic [VPN_WIDTH-1:0] scd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 168 | `scd_chk_vpn[26:21] -> logic [VPN_WIDTH-1:0] scd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 168 | `scd_chk_vpn[26:25] -> logic [VPN_WIDTH-1:0] scd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 168 | `scd_chk_vpn[26] -> logic [VPN_WIDTH-1:0] scd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 170 | `scd_chk_id[6] -> logic [ID_WIDTH-1:0] scd_chk_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[0] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[16:15] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[16] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[18:15] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[18] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[19:16] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[20:19] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[20] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[22] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[23:21] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[23] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 171 | `scd_chk_data[24] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[25:24] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[25] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[28:25] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[29] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[31:30] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[37:27] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[38] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[3:0] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[3] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[42:39] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[43] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[45:32] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[46] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[48:26] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[49] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[4] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[58:44] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[58:50] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[59:47] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[5:4] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 171 | `scd_chk_data[60] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 171 | `scd_chk_data[62:59] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[63:27] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[63:61] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[63] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 171 | `scd_chk_data[7:5] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `scd_chk_data[8] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2; Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 171 | `scd_chk_data[9:8] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 171 | `scd_chk_data[9] -> logic [DATA_WIDTH-1:0] scd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 172 | `thd_chk_vpn[21] -> logic [VPN_WIDTH-1:0] thd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 172 | `thd_chk_vpn[23] -> logic [VPN_WIDTH-1:0] thd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 172 | `thd_chk_vpn[24] -> logic [VPN_WIDTH-1:0] thd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 172 | `thd_chk_vpn[26:21] -> logic [VPN_WIDTH-1:0] thd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 172 | `thd_chk_vpn[26:25] -> logic [VPN_WIDTH-1:0] thd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 172 | `thd_chk_vpn[26] -> logic [VPN_WIDTH-1:0] thd_chk_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 174 | `thd_chk_id[6] -> logic [ID_WIDTH-1:0] thd_chk_id ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 175 | `thd_chk_data[0] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 175 | `thd_chk_data[25] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[29] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[31:28] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 175 | `thd_chk_data[33:32] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 175 | `thd_chk_data[37:34] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 175 | `thd_chk_data[38:34] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[38] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 175 | `thd_chk_data[41:40] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x3; Toggle=No, 1->0=No, 0->1=Yes | 4 |
| 175 | `thd_chk_data[45:43] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 175 | `thd_chk_data[48:46] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[4] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 175 | `thd_chk_data[53:49] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 175 | `thd_chk_data[54:43] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[54] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[58:43] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 175 | `thd_chk_data[58:55] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 175 | `thd_chk_data[5:4] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 175 | `thd_chk_data[5] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 175 | `thd_chk_data[60:59] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 175 | `thd_chk_data[62] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 175 | `thd_chk_data[63:62] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes x2 | 3 |
| 175 | `thd_chk_data[63] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[9:6] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[9:7] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 175 | `thd_chk_data[9:8] -> logic [DATA_WIDTH-1:0] thd_chk_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 201 | `fst_pmp_pa[2:0] -> logic [PADDR_WIDTH-1:0] fst_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 201 | `fst_pmp_pa[39:19] -> logic [PADDR_WIDTH-1:0] fst_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 203 | `scd_pmp_pa[12] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 203 | `scd_pmp_pa[15] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 203 | `scd_pmp_pa[21:17] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 203 | `scd_pmp_pa[21:18] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 203 | `scd_pmp_pa[22:16] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 203 | `scd_pmp_pa[2:0] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 203 | `scd_pmp_pa[39:22] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 203 | `scd_pmp_pa[39:23] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 203 | `scd_pmp_pa[9] -> logic [PADDR_WIDTH-1:0] scd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 205 | `thd_pmp_pa[21:18] -> logic [PADDR_WIDTH-1:0] thd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 205 | `thd_pmp_pa[22:17] -> logic [PADDR_WIDTH-1:0] thd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 205 | `thd_pmp_pa[2:0] -> logic [PADDR_WIDTH-1:0] thd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 205 | `thd_pmp_pa[39:22] -> logic [PADDR_WIDTH-1:0] thd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 205 | `thd_pmp_pa[39:23] -> logic [PADDR_WIDTH-1:0] thd_pmp_pa ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 206 | `fst_chk_flg[3:1] -> logic [8:0] fst_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 206 | `fst_chk_flg[4] -> logic [8:0] fst_chk_flg ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 206 | `fst_chk_flg[7] -> logic [8:0] fst_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 206 | `fst_chk_flg[8:5] -> logic [8:0] fst_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 206 | `fst_chk_flg[8:7] -> logic [8:0] fst_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 206 | `fst_chk_flg[8] -> logic [8:0] fst_chk_flg ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 207 | `scd_chk_flg[0] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 207 | `scd_chk_flg[3:0] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 207 | `scd_chk_flg[3] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 207 | `scd_chk_flg[4] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 207 | `scd_chk_flg[6:5] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 207 | `scd_chk_flg[7] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=No x2; Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 207 | `scd_chk_flg[8:7] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 207 | `scd_chk_flg[8] -> logic [8:0] scd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 208 | `thd_chk_flg[0] -> logic [8:0] thd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 208 | `thd_chk_flg[4] -> logic [8:0] thd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 208 | `thd_chk_flg[8:4] -> logic [8:0] thd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 208 | `thd_chk_flg[8:6] -> logic [8:0] thd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 208 | `thd_chk_flg[8:7] -> logic [8:0] thd_chk_flg ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 210 | `scd_chk_page_flt -> logic scd_chk_page_flt ;` | Toggle=No, 1->0=Yes, 0->1=No x2 | 2 |
| 212 | `fst_chk_leaf_vld -> logic fst_chk_leaf_vld ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 213 | `scd_chk_leaf_vld -> logic scd_chk_leaf_vld ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 214 | `thd_chk_leaf_vld -> logic thd_chk_leaf_vld ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 215 | `fst_chk_refill_req -> logic fst_chk_refill_req ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 216 | `fst_chk_refill_date[41:0] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_date;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 217 | `fst_chk_refill_tag[0] -> logic [TAG_WIDTH-1:0] fst_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 217 | `fst_chk_refill_tag[19:9] -> logic [TAG_WIDTH-1:0] fst_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 217 | `fst_chk_refill_tag[3:0] -> logic [TAG_WIDTH-1:0] fst_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 217 | `fst_chk_refill_tag[3:1] -> logic [TAG_WIDTH-1:0] fst_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 217 | `fst_chk_refill_tag[47] -> logic [TAG_WIDTH-1:0] fst_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 219 | `fst_chk_refill_id[6] -> logic [ID_WIDTH-1:0] fst_chk_refill_id ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 221 | `scd_chk_refill_date[41:0] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_date;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 222 | `scd_chk_refill_tag[0] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 222 | `scd_chk_refill_tag[19:9] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 222 | `scd_chk_refill_tag[35] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 222 | `scd_chk_refill_tag[3:0] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 222 | `scd_chk_refill_tag[3:1] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 222 | `scd_chk_refill_tag[40:39] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 222 | `scd_chk_refill_tag[43] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 222 | `scd_chk_refill_tag[47:41] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 222 | `scd_chk_refill_tag[47:45] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 222 | `scd_chk_refill_tag[47:46] -> logic [TAG_WIDTH-1:0] scd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 224 | `scd_chk_refill_id[6] -> logic [ID_WIDTH-1:0] scd_chk_refill_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 226 | `thd_chk_refill_date[41:0] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_date;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 227 | `thd_chk_refill_tag[19:9] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 227 | `thd_chk_refill_tag[3:0] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 227 | `thd_chk_refill_tag[41] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 227 | `thd_chk_refill_tag[43] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 227 | `thd_chk_refill_tag[44] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 227 | `thd_chk_refill_tag[47:41] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 227 | `thd_chk_refill_tag[47:45] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 227 | `thd_chk_refill_tag[47:46] -> logic [TAG_WIDTH-1:0] thd_chk_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 229 | `thd_chk_refill_id[6] -> logic [ID_WIDTH-1:0] thd_chk_refill_id ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 233 | `fst_chk_csr_id[6] -> logic [ID_WIDTH-1:0] fst_chk_csr_id ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 234 | `fst_chk_csr_data[10:8] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[10] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[13] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[16] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 234 | `fst_chk_csr_data[17] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[18] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[19] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[20:15] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[20:19] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[27:20] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 234 | `fst_chk_csr_data[27:21] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 234 | `fst_chk_csr_data[28] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[29:28] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[37:29] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[39] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[3:1] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[41] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[43] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[45] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[47] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[49:30] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[49] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[4] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 234 | `fst_chk_csr_data[50] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[51] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[53] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[58:30] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[58:55] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[59:29] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[59] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[5:4] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 234 | `fst_chk_csr_data[5] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[60:51] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[61:59] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[61] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 234 | `fst_chk_csr_data[62] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[63:61] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[63:62] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `fst_chk_csr_data[8] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[9:6] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `fst_chk_csr_data[9] -> logic [DATA_WIDTH-1:0] fst_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 236 | `scd_chk_csr_vpn[15] -> logic [VPN_WIDTH-1:0] scd_chk_csr_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 236 | `scd_chk_csr_vpn[20:19] -> logic [VPN_WIDTH-1:0] scd_chk_csr_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 236 | `scd_chk_csr_vpn[23] -> logic [VPN_WIDTH-1:0] scd_chk_csr_vpn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 236 | `scd_chk_csr_vpn[26:21] -> logic [VPN_WIDTH-1:0] scd_chk_csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 236 | `scd_chk_csr_vpn[26:25] -> logic [VPN_WIDTH-1:0] scd_chk_csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 236 | `scd_chk_csr_vpn[26] -> logic [VPN_WIDTH-1:0] scd_chk_csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 238 | `scd_chk_csr_id[6] -> logic [ID_WIDTH-1:0] scd_chk_csr_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[0] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[16:15] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[16] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[18:15] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[18] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[19:16] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[20:19] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[20] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[22] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[23:21] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[23] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 239 | `scd_chk_csr_data[24] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[25:24] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[25] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[28:25] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[29] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[31:30] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[37:27] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[38] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[3:0] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[3] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[42:39] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[43] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[45:32] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[46] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[48:26] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[49] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[4] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[58:44] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[58:50] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[59:47] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[5:4] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 239 | `scd_chk_csr_data[60] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 239 | `scd_chk_csr_data[62:59] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[63:27] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[63:61] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[63] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 239 | `scd_chk_csr_data[7:5] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 239 | `scd_chk_csr_data[8] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2; Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 239 | `scd_chk_csr_data[9:8] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `scd_chk_csr_data[9] -> logic [DATA_WIDTH-1:0] scd_chk_csr_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 253 | `twu_pgflt_type[0] -> logic [TYPE_WIDTH-1:0] twu_pgflt_type ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 254 | `twu_pgflt_id[6] -> logic [ID_WIDTH-1:0] twu_pgflt_id ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 256 | `twu_acc_err_type[1] -> logic [TYPE_WIDTH-1:0] twu_acc_err_type ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 257 | `twu_acc_err_id[2:1] -> logic [ID_WIDTH-1:0] twu_acc_err_id ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 257 | `twu_acc_err_id[6:5] -> logic [ID_WIDTH-1:0] twu_acc_err_id ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 262 | `acc_err_scd_pmp_grant -> logic acc_err_scd_pmp_grant;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 274 | `scd_csr_itlb_sel -> logic scd_csr_itlb_sel ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[0] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[11:10] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[12:10] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[13] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[15:13] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[15:14] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[15] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[19] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[21] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[22] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[23:20] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[26:24] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 279 | `csr_vpn[26:25] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 279 | `csr_vpn[8:1] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 279 | `csr_vpn[8:3] -> logic [VPN_WIDTH-1:0] csr_vpn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 281 | `csr_id[2:1] -> logic [ID_WIDTH-1:0] csr_id ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 281 | `csr_id[6:5] -> logic [ID_WIDTH-1:0] csr_id ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 282 | `csr_data[18:8] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[19:10] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[19:8] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[21] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[22] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[23:10] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[23] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[25:24] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[25] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 282 | `csr_data[27:25] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[27] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 282 | `csr_data[58:30] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[59:30] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 282 | `csr_data[5:4] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 282 | `csr_data[63:29] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 282 | `csr_data[63:62] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 282 | `csr_data[8] -> logic [DATA_WIDTH-1:0] csr_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 283 | `ptw_cur_st[2] -> logic [2:0] ptw_cur_st ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 284 | `ptw_nxt_st[2] -> logic [2:0] ptw_nxt_st ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 287 | `twu_crs1_1g -> logic twu_crs1_1g ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 288 | `twu_crs2_1g -> logic twu_crs2_1g ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 289 | `twu_crs1_2m -> logic twu_crs1_2m ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 290 | `twu_crs2_2m -> logic twu_crs2_2m ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 291 | `twu_crs2_chk -> logic twu_crs2_chk ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 292 | `csr_vpn_flop[0] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes x2 | 3 |
| 292 | `csr_vpn_flop[10] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[11:10] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[12:10] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[12] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[13:12] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[13] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 292 | `csr_vpn_flop[15:13] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[15:14] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[15] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[18:16] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[19:16] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[19:17] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[19] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[20] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[21:19] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[21] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 292 | `csr_vpn_flop[22] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[23:20] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[23:22] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[24] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 292 | `csr_vpn_flop[26:24] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `csr_vpn_flop[26:25] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 292 | `csr_vpn_flop[2:0] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[2:1] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 292 | `csr_vpn_flop[8:1] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 292 | `csr_vpn_flop[8:3] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 292 | `csr_vpn_flop[9] -> logic [VPN_WIDTH-1:0] csr_vpn_flop ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 293 | `csr_type_flop[1] -> logic [TYPE_WIDTH-1:0] csr_type_flop ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 293 | `csr_type_flop[2:1] -> logic [TYPE_WIDTH-1:0] csr_type_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 294 | `csr_id_flop[2:1] -> logic [ID_WIDTH-1:0] csr_id_flop ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 294 | `csr_id_flop[6:5] -> logic [ID_WIDTH-1:0] csr_id_flop ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 295 | `twu_sysmap_adder[39:0] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adder;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 296 | `csr_data_flop[18:10] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[18:11] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[19:10] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[19:8] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[20:19] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[21] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 296 | `csr_data_flop[22] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[23:20] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[23:22] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[23] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 296 | `csr_data_flop[24] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[25:24] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[25] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 296 | `csr_data_flop[26] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[27:25] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[27] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 296 | `csr_data_flop[28] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 296 | `csr_data_flop[29:27] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[29:28] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[3:0] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 296 | `csr_data_flop[5:4] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 296 | `csr_data_flop[63:29] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 296 | `csr_data_flop[63:30] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 296 | `csr_data_flop[7:6] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 296 | `csr_data_flop[8] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[9:6] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 296 | `csr_data_flop[9:8] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `csr_data_flop[9] -> logic [DATA_WIDTH-1:0] csr_data_flop ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 297 | `csr_refill_pgs[0] -> logic [PGS_WIDTH-1:0] csr_refill_pgs ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 298 | `twu_hit_num[7:0] -> logic [7:0] twu_hit_num ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 302 | `csr_refill_data[10:7] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 302 | `csr_refill_data[22:14] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[22:15] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[23:14] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 302 | `csr_refill_data[24:23] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[25] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 302 | `csr_refill_data[26] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[27:24] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[27:26] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[27] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 302 | `csr_refill_data[28] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[29:28] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[29] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 302 | `csr_refill_data[30] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[31:29] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[31] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 302 | `csr_refill_data[32] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 302 | `csr_refill_data[33:31] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[33:32] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[3:0] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 302 | `csr_refill_data[41:33] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 302 | `csr_refill_data[41:34] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 302 | `csr_refill_data[4] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 302 | `csr_refill_data[6:5] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 302 | `csr_refill_data[7] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `csr_refill_data[8:5] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[8] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 302 | `csr_refill_data[9] -> logic [RDATA_WIDTH-1:0] csr_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 303 | `csr_refill_tag[0] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 303 | `csr_refill_tag[19:9] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[1:0] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 303 | `csr_refill_tag[20:9] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 303 | `csr_refill_tag[20] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[22:21] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[22:9] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[28:21] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 303 | `csr_refill_tag[28:23] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 303 | `csr_refill_tag[29] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 303 | `csr_refill_tag[30] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[31:30] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[32:30] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[32] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[33:32] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[33] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 303 | `csr_refill_tag[35:33] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[35:34] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[35] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[38:36] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[39:36] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[39:37] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[39] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[40] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[41:39] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[41] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 303 | `csr_refill_tag[42] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[43:40] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[43:42] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 303 | `csr_refill_tag[44] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 303 | `csr_refill_tag[47:44] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 303 | `csr_refill_tag[47:45] -> logic [TAG_WIDTH-1:0] csr_refill_tag ;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 304 | `csr_refill_type[1] -> logic [TYPE_WIDTH-1:0] csr_refill_type ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 304 | `csr_refill_type[2:1] -> logic [TYPE_WIDTH-1:0] csr_refill_type ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 305 | `csr_refill_id[2:1] -> logic [ID_WIDTH-1:0] csr_refill_id ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 305 | `csr_refill_id[6:5] -> logic [ID_WIDTH-1:0] csr_refill_id ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 307 | `fst_chk_itlb_sel -> logic fst_chk_itlb_sel;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 308 | `scd_chk_itlb_sel -> logic scd_chk_itlb_sel;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 312 | `refill_grant[2] -> logic [3:0] refill_grant ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 314 | `refill_fst_chk_grant -> logic refill_fst_chk_grant;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 317 | `fst_chk_refill_data[10:9] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 317 | `fst_chk_refill_data[11:5] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[11] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 317 | `fst_chk_refill_data[12] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[13:12] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 317 | `fst_chk_refill_data[14:11] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[14] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[17] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 317 | `fst_chk_refill_data[20] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 317 | `fst_chk_refill_data[21] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[22] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[23] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[24:19] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[24:23] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[31:24] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 317 | `fst_chk_refill_data[31:25] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 317 | `fst_chk_refill_data[32] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[33:32] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[3:1] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[41:33] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 317 | `fst_chk_refill_data[41:34] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 317 | `fst_chk_refill_data[4] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 317 | `fst_chk_refill_data[7] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[8:7] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `fst_chk_refill_data[9:8] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 317 | `fst_chk_refill_data[9] -> logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 318 | `scd_pmp_ppn[0] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 318 | `scd_pmp_ppn[10:4] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 318 | `scd_pmp_ppn[27:10] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 318 | `scd_pmp_ppn[27:11] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 318 | `scd_pmp_ppn[3] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 318 | `scd_pmp_ppn[9:5] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 318 | `scd_pmp_ppn[9:6] -> logic [PPN_WIDTH-1:0] scd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[0] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[10] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 319 | `scd_chk_refill_data[12:8] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[13:11] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[13:7] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[13] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 319 | `scd_chk_refill_data[20:19] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[20] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[22:19] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[22] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[23:20] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[24:23] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[24] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[26] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[27:25] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[27] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 319 | `scd_chk_refill_data[28] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[29:28] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[29] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[32:29] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[33] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[35:34] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[3:0] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[3] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[41:30] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[41:31] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 319 | `scd_chk_refill_data[41:36] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 319 | `scd_chk_refill_data[4] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 319 | `scd_chk_refill_data[6:5] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[7] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x2; Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 319 | `scd_chk_refill_data[8] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 319 | `scd_chk_refill_data[9] -> logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 320 | `thd_chk_refill_data[0] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 320 | `thd_chk_refill_data[10:4] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 320 | `thd_chk_refill_data[10:6] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 320 | `thd_chk_refill_data[10:7] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 320 | `thd_chk_refill_data[12] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 320 | `thd_chk_refill_data[13:12] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes x2 | 3 |
| 320 | `thd_chk_refill_data[13] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 320 | `thd_chk_refill_data[29] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 320 | `thd_chk_refill_data[33] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 320 | `thd_chk_refill_data[35:32] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 320 | `thd_chk_refill_data[37:36] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 320 | `thd_chk_refill_data[41:38] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 320 | `thd_chk_refill_data[4] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 321 | `thd_pmp_ppn[10:5] -> logic [PPN_WIDTH-1:0] thd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 321 | `thd_pmp_ppn[27:10] -> logic [PPN_WIDTH-1:0] thd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 321 | `thd_pmp_ppn[27:11] -> logic [PPN_WIDTH-1:0] thd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 321 | `thd_pmp_ppn[9:6] -> logic [PPN_WIDTH-1:0] thd_pmp_ppn ;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 329 | `ptw_chk_cross -> logic ptw_chk_cross ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 330 | `ptw_crs2_1g -> logic ptw_crs2_1g ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 331 | `ptw_crs2_2m -> logic ptw_crs2_2m ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 336 | `fst_ref_sel -> logic fst_ref_sel ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 345 | `fst_chk_ready -> logic fst_chk_ready ;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 346 | `scd_chk_ready -> logic scd_chk_ready ;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 349 | `twu_clk_en -> logic twu_clk_en ;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 352 | `thd_chk_refill_data_no_maee[0] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[10] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=Yes, 0->1=No x3 | 3 |
| 352 | `thd_chk_refill_data_no_maee[25:24] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[25] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[2:0] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 352 | `thd_chk_refill_data_no_maee[2] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[32] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[34:33] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 352 | `thd_chk_refill_data_no_maee[34] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[37:35] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 352 | `thd_chk_refill_data_no_maee[41:38] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 352 | `thd_chk_refill_data_no_maee[4] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 352 | `thd_chk_refill_data_no_maee[6:5] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[7:5] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[8:5] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 352 | `thd_chk_refill_data_no_maee[8] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 352 | `thd_chk_refill_data_no_maee[9] -> logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 354 | `twu_ref_data_din[0] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[12:10] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[12] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[25:24] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[25] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[2:0] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 354 | `twu_ref_data_din[2] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[32] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[34:33] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 354 | `twu_ref_data_din[34] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[37:35] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 354 | `twu_ref_data_din[41:38] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 354 | `twu_ref_data_din[4] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 354 | `twu_ref_data_din[6:5] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[7:5] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 354 | `twu_ref_data_din[8:5] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 354 | `twu_ref_data_din[8] -> logic [RDATA_WIDTH-1:0] twu_ref_data_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[0] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 355 | `twu_ref_tag_din[10:5] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[10:7] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 355 | `twu_ref_tag_din[11] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=No x3 | 3 |
| 355 | `twu_ref_tag_din[15:12] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes x3 | 3 |
| 355 | `twu_ref_tag_din[15:8] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[19:16] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 355 | `twu_ref_tag_din[2] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[31] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[43:41] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 355 | `twu_ref_tag_din[43] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[44] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[46:45] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 355 | `twu_ref_tag_din[46] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 355 | `twu_ref_tag_din[47] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes x4 | 4 |
| 355 | `twu_ref_tag_din[4] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 355 | `twu_ref_tag_din[6:4] -> logic [TAG_WIDTH-1:0] twu_ref_tag_din;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 356 | `twu_ref_pgs[1] -> logic [PGS_WIDTH-1:0] twu_ref_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 358 | `twu_ref_id[6] -> logic [ID_WIDTH-1:0] twu_ref_id;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 359 | `twu_sysmap_adderx1[20:0] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 359 | `twu_sysmap_adderx1[21:0] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 359 | `twu_sysmap_adderx1[22:21] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 359 | `twu_sysmap_adderx1[23] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 359 | `twu_sysmap_adderx1[24] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 359 | `twu_sysmap_adderx1[25:22] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 359 | `twu_sysmap_adderx1[25:24] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 359 | `twu_sysmap_adderx1[25] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No; Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 359 | `twu_sysmap_adderx1[26] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 359 | `twu_sysmap_adderx1[27:26] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 359 | `twu_sysmap_adderx1[27] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 359 | `twu_sysmap_adderx1[28] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 359 | `twu_sysmap_adderx1[29:27] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 359 | `twu_sysmap_adderx1[29] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 359 | `twu_sysmap_adderx1[30] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 359 | `twu_sysmap_adderx1[31:29] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 359 | `twu_sysmap_adderx1[31:30] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 359 | `twu_sysmap_adderx1[39:31] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 359 | `twu_sysmap_adderx1[39:32] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 360 | `twu_sysmap_adderx2[11:0] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=No x4 | 4 |
| 360 | `twu_sysmap_adderx2[12] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 360 | `twu_sysmap_adderx2[20:12] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 360 | `twu_sysmap_adderx2[30] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 360 | `twu_sysmap_adderx2[31:30] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 360 | `twu_sysmap_adderx2[39:31] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 360 | `twu_sysmap_adderx2[39:32] -> logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 361 | `sysmap_mmu_flg[0] -> logic [4:0] sysmap_mmu_flg;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 361 | `sysmap_mmu_flg[1:0] -> logic [4:0] sysmap_mmu_flg;` | Toggle=No, 1->0=No, 0->1=No x2 | 2 |
| 362 | `fst_chk_l1pmpflg[0] -> logic [3:0] fst_chk_l1pmpflg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 362 | `fst_chk_l1pmpflg[1:0] -> logic [3:0] fst_chk_l1pmpflg;` | Toggle=No, 1->0=No, 0->1=Yes x2 | 2 |
| 362 | `fst_chk_l1pmpflg[3:0] -> logic [3:0] fst_chk_l1pmpflg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 362 | `fst_chk_l1pmpflg[3] -> logic [3:0] fst_chk_l1pmpflg;` | Toggle=No, 1->0=No, 0->1=No x2; Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 363 | `scd_pmp_l1pmpflg[3] -> logic [3:0] scd_pmp_l1pmpflg;` | Toggle=No, 1->0=No, 0->1=No x2; Toggle=No, 1->0=No, 0->1=Yes x2 | 4 |

`mmu/rtl/twu.sv:149`

```systemverilog
     147: logic                   thd_pmp_vld        ;
     148: logic                   thd_chk_vld        ;
>>   149: logic                   fst_pmp_wait       ;
     150: logic                   fst_chk_wait       ;
     151: logic                   scd_pmp_wait       ;
```

`mmu/rtl/twu.sv:150`

```systemverilog
     148: logic                   thd_chk_vld        ;
     149: logic                   fst_pmp_wait       ;
>>   150: logic                   fst_chk_wait       ;
     151: logic                   scd_pmp_wait       ;
     152: logic                   scd_chk_wait       ;
```

`mmu/rtl/twu.sv:151`

```systemverilog
     149: logic                   fst_pmp_wait       ;
     150: logic                   fst_chk_wait       ;
>>   151: logic                   scd_pmp_wait       ;
     152: logic                   scd_chk_wait       ;
     153: logic                   thd_pmp_wait       ;
```

`mmu/rtl/twu.sv:152`

```systemverilog
     150: logic                   fst_chk_wait       ;
     151: logic                   scd_pmp_wait       ;
>>   152: logic                   scd_chk_wait       ;
     153: logic                   thd_pmp_wait       ;
     154: logic                   thd_chk_wait       ;
```

`mmu/rtl/twu.sv:157`

```systemverilog
     155: logic [VPN_WIDTH-1:0]   fst_pmp_vpn        ;
     156: logic [TYPE_WIDTH-1:0]  fst_pmp_type       ;
>>   157: logic [ID_WIDTH-1:0]    fst_pmp_id         ;
     158: logic [VPN_WIDTH-1:0]   scd_pmp_vpn        ;
     159: logic [TYPE_WIDTH-1:0]  scd_pmp_type       ;
```

`mmu/rtl/twu.sv:158`

```systemverilog
     156: logic [TYPE_WIDTH-1:0]  fst_pmp_type       ;
     157: logic [ID_WIDTH-1:0]    fst_pmp_id         ;
>>   158: logic [VPN_WIDTH-1:0]   scd_pmp_vpn        ;
     159: logic [TYPE_WIDTH-1:0]  scd_pmp_type       ;
     160: logic [ID_WIDTH-1:0]    scd_pmp_id         ;
```

`mmu/rtl/twu.sv:160`

```systemverilog
     158: logic [VPN_WIDTH-1:0]   scd_pmp_vpn        ;
     159: logic [TYPE_WIDTH-1:0]  scd_pmp_type       ;
>>   160: logic [ID_WIDTH-1:0]    scd_pmp_id         ;
     161: logic [VPN_WIDTH-1:0]   thd_pmp_vpn        ;
     162: logic [TYPE_WIDTH-1:0]  thd_pmp_type       ;
```

`mmu/rtl/twu.sv:161`

```systemverilog
     159: logic [TYPE_WIDTH-1:0]  scd_pmp_type       ;
     160: logic [ID_WIDTH-1:0]    scd_pmp_id         ;
>>   161: logic [VPN_WIDTH-1:0]   thd_pmp_vpn        ;
     162: logic [TYPE_WIDTH-1:0]  thd_pmp_type       ;
     163: logic [ID_WIDTH-1:0]    thd_pmp_id         ;
```

`mmu/rtl/twu.sv:163`

```systemverilog
     161: logic [VPN_WIDTH-1:0]   thd_pmp_vpn        ;
     162: logic [TYPE_WIDTH-1:0]  thd_pmp_type       ;
>>   163: logic [ID_WIDTH-1:0]    thd_pmp_id         ;
     164: logic [VPN_WIDTH-1:0]   fst_chk_vpn        ;
     165: logic [TYPE_WIDTH-1:0]  fst_chk_type       ;
```

`mmu/rtl/twu.sv:166`

```systemverilog
     164: logic [VPN_WIDTH-1:0]   fst_chk_vpn        ;
     165: logic [TYPE_WIDTH-1:0]  fst_chk_type       ;
>>   166: logic [ID_WIDTH-1:0]    fst_chk_id         ;
     167: logic [DATA_WIDTH-1:0]  fst_chk_data       ;
     168: logic [VPN_WIDTH-1:0]   scd_chk_vpn        ;
```

`mmu/rtl/twu.sv:167`

```systemverilog
     165: logic [TYPE_WIDTH-1:0]  fst_chk_type       ;
     166: logic [ID_WIDTH-1:0]    fst_chk_id         ;
>>   167: logic [DATA_WIDTH-1:0]  fst_chk_data       ;
     168: logic [VPN_WIDTH-1:0]   scd_chk_vpn        ;
     169: logic [TYPE_WIDTH-1:0]  scd_chk_type       ;
```

`mmu/rtl/twu.sv:168`

```systemverilog
     166: logic [ID_WIDTH-1:0]    fst_chk_id         ;
     167: logic [DATA_WIDTH-1:0]  fst_chk_data       ;
>>   168: logic [VPN_WIDTH-1:0]   scd_chk_vpn        ;
     169: logic [TYPE_WIDTH-1:0]  scd_chk_type       ;
     170: logic [ID_WIDTH-1:0]    scd_chk_id         ;
```

`mmu/rtl/twu.sv:170`

```systemverilog
     168: logic [VPN_WIDTH-1:0]   scd_chk_vpn        ;
     169: logic [TYPE_WIDTH-1:0]  scd_chk_type       ;
>>   170: logic [ID_WIDTH-1:0]    scd_chk_id         ;
     171: logic [DATA_WIDTH-1:0]  scd_chk_data       ;
     172: logic [VPN_WIDTH-1:0]   thd_chk_vpn        ;
```

`mmu/rtl/twu.sv:171`

```systemverilog
     169: logic [TYPE_WIDTH-1:0]  scd_chk_type       ;
     170: logic [ID_WIDTH-1:0]    scd_chk_id         ;
>>   171: logic [DATA_WIDTH-1:0]  scd_chk_data       ;
     172: logic [VPN_WIDTH-1:0]   thd_chk_vpn        ;
     173: logic [TYPE_WIDTH-1:0]  thd_chk_type       ;
```

`mmu/rtl/twu.sv:172`

```systemverilog
     170: logic [ID_WIDTH-1:0]    scd_chk_id         ;
     171: logic [DATA_WIDTH-1:0]  scd_chk_data       ;
>>   172: logic [VPN_WIDTH-1:0]   thd_chk_vpn        ;
     173: logic [TYPE_WIDTH-1:0]  thd_chk_type       ;
     174: logic [ID_WIDTH-1:0]    thd_chk_id         ;
```

`mmu/rtl/twu.sv:174`

```systemverilog
     172: logic [VPN_WIDTH-1:0]   thd_chk_vpn        ;
     173: logic [TYPE_WIDTH-1:0]  thd_chk_type       ;
>>   174: logic [ID_WIDTH-1:0]    thd_chk_id         ;
     175: logic [DATA_WIDTH-1:0]  thd_chk_data       ;
     176: logic                   fst_pmp_fetch_type ;
```

`mmu/rtl/twu.sv:175`

```systemverilog
     173: logic [TYPE_WIDTH-1:0]  thd_chk_type       ;
     174: logic [ID_WIDTH-1:0]    thd_chk_id         ;
>>   175: logic [DATA_WIDTH-1:0]  thd_chk_data       ;
     176: logic                   fst_pmp_fetch_type ;
     177: logic                   fst_pmp_load_type  ;
```

`mmu/rtl/twu.sv:201`

```systemverilog
     199: logic                   thd_pmp_deny       ;
     200: logic                   fst_pmp_mbuf_req   ;
>>   201: logic [PADDR_WIDTH-1:0] fst_pmp_pa         ;
     202: logic                   scd_pmp_mbuf_req   ;
     203: logic [PADDR_WIDTH-1:0] scd_pmp_pa         ;
```

`mmu/rtl/twu.sv:203`

```systemverilog
     201: logic [PADDR_WIDTH-1:0] fst_pmp_pa         ;
     202: logic                   scd_pmp_mbuf_req   ;
>>   203: logic [PADDR_WIDTH-1:0] scd_pmp_pa         ;
     204: logic                   thd_pmp_mbuf_req   ;
     205: logic [PADDR_WIDTH-1:0] thd_pmp_pa         ;
```

`mmu/rtl/twu.sv:205`

```systemverilog
     203: logic [PADDR_WIDTH-1:0] scd_pmp_pa         ;
     204: logic                   thd_pmp_mbuf_req   ;
>>   205: logic [PADDR_WIDTH-1:0] thd_pmp_pa         ;
     206: logic [8:0]             fst_chk_flg        ;
     207: logic [8:0]             scd_chk_flg        ;
```

`mmu/rtl/twu.sv:206`

```systemverilog
     204: logic                   thd_pmp_mbuf_req   ;
     205: logic [PADDR_WIDTH-1:0] thd_pmp_pa         ;
>>   206: logic [8:0]             fst_chk_flg        ;
     207: logic [8:0]             scd_chk_flg        ;
     208: logic [8:0]             thd_chk_flg        ;
```

`mmu/rtl/twu.sv:207`

```systemverilog
     205: logic [PADDR_WIDTH-1:0] thd_pmp_pa         ;
     206: logic [8:0]             fst_chk_flg        ;
>>   207: logic [8:0]             scd_chk_flg        ;
     208: logic [8:0]             thd_chk_flg        ;
     209: logic                   fst_chk_page_flt   ;
```

`mmu/rtl/twu.sv:208`

```systemverilog
     206: logic [8:0]             fst_chk_flg        ;
     207: logic [8:0]             scd_chk_flg        ;
>>   208: logic [8:0]             thd_chk_flg        ;
     209: logic                   fst_chk_page_flt   ;
     210: logic                   scd_chk_page_flt   ;
```

`mmu/rtl/twu.sv:210`

```systemverilog
     208: logic [8:0]             thd_chk_flg        ;
     209: logic                   fst_chk_page_flt   ;
>>   210: logic                   scd_chk_page_flt   ;
     211: logic                   thd_chk_page_flt   ;
     212: logic                   fst_chk_leaf_vld   ;
```

`mmu/rtl/twu.sv:212`

```systemverilog
     210: logic                   scd_chk_page_flt   ;
     211: logic                   thd_chk_page_flt   ;
>>   212: logic                   fst_chk_leaf_vld   ;
     213: logic                   scd_chk_leaf_vld   ;
     214: logic                   thd_chk_leaf_vld   ;
```

`mmu/rtl/twu.sv:213`

```systemverilog
     211: logic                   thd_chk_page_flt   ;
     212: logic                   fst_chk_leaf_vld   ;
>>   213: logic                   scd_chk_leaf_vld   ;
     214: logic                   thd_chk_leaf_vld   ;
     215: logic                   fst_chk_refill_req ;
```

`mmu/rtl/twu.sv:214`

```systemverilog
     212: logic                   fst_chk_leaf_vld   ;
     213: logic                   scd_chk_leaf_vld   ;
>>   214: logic                   thd_chk_leaf_vld   ;
     215: logic                   fst_chk_refill_req ;
     216: logic [RDATA_WIDTH-1:0] fst_chk_refill_date;
```

`mmu/rtl/twu.sv:215`

```systemverilog
     213: logic                   scd_chk_leaf_vld   ;
     214: logic                   thd_chk_leaf_vld   ;
>>   215: logic                   fst_chk_refill_req ;
     216: logic [RDATA_WIDTH-1:0] fst_chk_refill_date;
     217: logic [TAG_WIDTH-1:0]   fst_chk_refill_tag ;
```

`mmu/rtl/twu.sv:216`

```systemverilog
     214: logic                   thd_chk_leaf_vld   ;
     215: logic                   fst_chk_refill_req ;
>>   216: logic [RDATA_WIDTH-1:0] fst_chk_refill_date;
     217: logic [TAG_WIDTH-1:0]   fst_chk_refill_tag ;
     218: logic [TYPE_WIDTH-1:0]  fst_chk_refill_type;
```

`mmu/rtl/twu.sv:217`

```systemverilog
     215: logic                   fst_chk_refill_req ;
     216: logic [RDATA_WIDTH-1:0] fst_chk_refill_date;
>>   217: logic [TAG_WIDTH-1:0]   fst_chk_refill_tag ;
     218: logic [TYPE_WIDTH-1:0]  fst_chk_refill_type;
     219: logic [ID_WIDTH-1:0]    fst_chk_refill_id  ;
```

`mmu/rtl/twu.sv:219`

```systemverilog
     217: logic [TAG_WIDTH-1:0]   fst_chk_refill_tag ;
     218: logic [TYPE_WIDTH-1:0]  fst_chk_refill_type;
>>   219: logic [ID_WIDTH-1:0]    fst_chk_refill_id  ;
     220: logic                   scd_chk_refill_req ;
     221: logic [RDATA_WIDTH-1:0] scd_chk_refill_date;
```

`mmu/rtl/twu.sv:221`

```systemverilog
     219: logic [ID_WIDTH-1:0]    fst_chk_refill_id  ;
     220: logic                   scd_chk_refill_req ;
>>   221: logic [RDATA_WIDTH-1:0] scd_chk_refill_date;
     222: logic [TAG_WIDTH-1:0]   scd_chk_refill_tag ;
     223: logic [TYPE_WIDTH-1:0]  scd_chk_refill_type;
```

`mmu/rtl/twu.sv:222`

```systemverilog
     220: logic                   scd_chk_refill_req ;
     221: logic [RDATA_WIDTH-1:0] scd_chk_refill_date;
>>   222: logic [TAG_WIDTH-1:0]   scd_chk_refill_tag ;
     223: logic [TYPE_WIDTH-1:0]  scd_chk_refill_type;
     224: logic [ID_WIDTH-1:0]    scd_chk_refill_id  ;
```

`mmu/rtl/twu.sv:224`

```systemverilog
     222: logic [TAG_WIDTH-1:0]   scd_chk_refill_tag ;
     223: logic [TYPE_WIDTH-1:0]  scd_chk_refill_type;
>>   224: logic [ID_WIDTH-1:0]    scd_chk_refill_id  ;
     225: logic                   thd_chk_refill_req ;
     226: logic [RDATA_WIDTH-1:0] thd_chk_refill_date;
```

`mmu/rtl/twu.sv:226`

```systemverilog
     224: logic [ID_WIDTH-1:0]    scd_chk_refill_id  ;
     225: logic                   thd_chk_refill_req ;
>>   226: logic [RDATA_WIDTH-1:0] thd_chk_refill_date;
     227: logic [TAG_WIDTH-1:0]   thd_chk_refill_tag ;
     228: logic [TYPE_WIDTH-1:0]  thd_chk_refill_type;
```

`mmu/rtl/twu.sv:227`

```systemverilog
     225: logic                   thd_chk_refill_req ;
     226: logic [RDATA_WIDTH-1:0] thd_chk_refill_date;
>>   227: logic [TAG_WIDTH-1:0]   thd_chk_refill_tag ;
     228: logic [TYPE_WIDTH-1:0]  thd_chk_refill_type;
     229: logic [ID_WIDTH-1:0]    thd_chk_refill_id  ;
```

`mmu/rtl/twu.sv:229`

```systemverilog
     227: logic [TAG_WIDTH-1:0]   thd_chk_refill_tag ;
     228: logic [TYPE_WIDTH-1:0]  thd_chk_refill_type;
>>   229: logic [ID_WIDTH-1:0]    thd_chk_refill_id  ;
     230: logic                   fst_chk_csr_req    ;
     231: logic [VPN_WIDTH-1:0]   fst_chk_csr_vpn    ;
```

`mmu/rtl/twu.sv:233`

```systemverilog
     231: logic [VPN_WIDTH-1:0]   fst_chk_csr_vpn    ;
     232: logic [TYPE_WIDTH-1:0]  fst_chk_csr_type   ;
>>   233: logic [ID_WIDTH-1:0]    fst_chk_csr_id     ;
     234: logic [DATA_WIDTH-1:0]  fst_chk_csr_data   ;
     235: logic                   scd_chk_csr_req    ;
```

`mmu/rtl/twu.sv:234`

```systemverilog
     232: logic [TYPE_WIDTH-1:0]  fst_chk_csr_type   ;
     233: logic [ID_WIDTH-1:0]    fst_chk_csr_id     ;
>>   234: logic [DATA_WIDTH-1:0]  fst_chk_csr_data   ;
     235: logic                   scd_chk_csr_req    ;
     236: logic [VPN_WIDTH-1:0]   scd_chk_csr_vpn    ;
```

`mmu/rtl/twu.sv:236`

```systemverilog
     234: logic [DATA_WIDTH-1:0]  fst_chk_csr_data   ;
     235: logic                   scd_chk_csr_req    ;
>>   236: logic [VPN_WIDTH-1:0]   scd_chk_csr_vpn    ;
     237: logic [TYPE_WIDTH-1:0]  scd_chk_csr_type   ;
     238: logic [ID_WIDTH-1:0]    scd_chk_csr_id     ;
```

`mmu/rtl/twu.sv:238`

```systemverilog
     236: logic [VPN_WIDTH-1:0]   scd_chk_csr_vpn    ;
     237: logic [TYPE_WIDTH-1:0]  scd_chk_csr_type   ;
>>   238: logic [ID_WIDTH-1:0]    scd_chk_csr_id     ;
     239: logic [DATA_WIDTH-1:0]  scd_chk_csr_data   ;
     240: //logic				thd_chk_csr_req      ;
```

`mmu/rtl/twu.sv:239`

```systemverilog
     237: logic [TYPE_WIDTH-1:0]  scd_chk_csr_type   ;
     238: logic [ID_WIDTH-1:0]    scd_chk_csr_id     ;
>>   239: logic [DATA_WIDTH-1:0]  scd_chk_csr_data   ;
     240: //logic				thd_chk_csr_req      ;
     241: //logic	[26:0]		thd_chk_csr_vpn      ;
```

`mmu/rtl/twu.sv:253`

```systemverilog
     251: //logic				data_reg_cmplt       ;
     252: logic                  twu_pgflt_vld        ;
>>   253: logic [TYPE_WIDTH-1:0] twu_pgflt_type       ;
     254: logic [ID_WIDTH-1:0]   twu_pgflt_id         ;
     255: logic                  twu_acc_err_vld      ;
```

`mmu/rtl/twu.sv:254`

```systemverilog
     252: logic                  twu_pgflt_vld        ;
     253: logic [TYPE_WIDTH-1:0] twu_pgflt_type       ;
>>   254: logic [ID_WIDTH-1:0]   twu_pgflt_id         ;
     255: logic                  twu_acc_err_vld      ;
     256: logic [TYPE_WIDTH-1:0] twu_acc_err_type     ;
```

`mmu/rtl/twu.sv:256`

```systemverilog
     254: logic [ID_WIDTH-1:0]   twu_pgflt_id         ;
     255: logic                  twu_acc_err_vld      ;
>>   256: logic [TYPE_WIDTH-1:0] twu_acc_err_type     ;
     257: logic [ID_WIDTH-1:0]   twu_acc_err_id       ;
     258: logic                  pgflt_thd_chk_grant  ;
```

`mmu/rtl/twu.sv:257`

```systemverilog
     255: logic                  twu_acc_err_vld      ;
     256: logic [TYPE_WIDTH-1:0] twu_acc_err_type     ;
>>   257: logic [ID_WIDTH-1:0]   twu_acc_err_id       ;
     258: logic                  pgflt_thd_chk_grant  ;
     259: logic                  pgflt_scd_chk_grant  ;
```

`mmu/rtl/twu.sv:262`

```systemverilog
     260: logic                  pgflt_fst_chk_grant  ;
     261: logic                  acc_err_thd_pmp_grant;
>>   262: logic                  acc_err_scd_pmp_grant;
     263: logic                  acc_err_fst_pmp_grant;
     264: logic                  fst_pmp_itlb_sel     ;
```

`mmu/rtl/twu.sv:274`

```systemverilog
     272: logic                  csr_req              ;
     273: logic                  fst_csr_itlb_sel     ;
>>   274: logic                  scd_csr_itlb_sel     ;
     275: logic                  csr_itlb_sel         ;
     276: logic [1:0]            csr_grant            ;
```

`mmu/rtl/twu.sv:279`

```systemverilog
     277: logic                  scd_csr_grant        ;
     278: logic                  fst_csr_grant        ;
>>   279: logic [VPN_WIDTH-1:0]  csr_vpn              ;
     280: logic [TYPE_WIDTH-1:0] csr_type             ;
     281: logic [ID_WIDTH-1:0]   csr_id               ;
```

`mmu/rtl/twu.sv:281`

```systemverilog
     279: logic [VPN_WIDTH-1:0]  csr_vpn              ;
     280: logic [TYPE_WIDTH-1:0] csr_type             ;
>>   281: logic [ID_WIDTH-1:0]   csr_id               ;
     282: logic [DATA_WIDTH-1:0] csr_data             ;
     283: logic [2:0]            ptw_cur_st           ;
```

`mmu/rtl/twu.sv:282`

```systemverilog
     280: logic [TYPE_WIDTH-1:0] csr_type             ;
     281: logic [ID_WIDTH-1:0]   csr_id               ;
>>   282: logic [DATA_WIDTH-1:0] csr_data             ;
     283: logic [2:0]            ptw_cur_st           ;
     284: logic [2:0]            ptw_nxt_st           ;
```

`mmu/rtl/twu.sv:283`

```systemverilog
     281: logic [ID_WIDTH-1:0]   csr_id               ;
     282: logic [DATA_WIDTH-1:0] csr_data             ;
>>   283: logic [2:0]            ptw_cur_st           ;
     284: logic [2:0]            ptw_nxt_st           ;
     285: logic                  csr_idle             ;
```

`mmu/rtl/twu.sv:284`

```systemverilog
     282: logic [DATA_WIDTH-1:0] csr_data             ;
     283: logic [2:0]            ptw_cur_st           ;
>>   284: logic [2:0]            ptw_nxt_st           ;
     285: logic                  csr_idle             ;
     286: //logic				csr_busy  	         ;
```

`mmu/rtl/twu.sv:287`

```systemverilog
     285: logic                  csr_idle             ;
     286: //logic				csr_busy  	         ;
>>   287: logic                   twu_crs1_1g     ;
     288: logic                   twu_crs2_1g     ;
     289: logic                   twu_crs1_2m     ;
```

`mmu/rtl/twu.sv:288`

```systemverilog
     286: //logic				csr_busy  	         ;
     287: logic                   twu_crs1_1g     ;
>>   288: logic                   twu_crs2_1g     ;
     289: logic                   twu_crs1_2m     ;
     290: logic                   twu_crs2_2m     ;
```

`mmu/rtl/twu.sv:289`

```systemverilog
     287: logic                   twu_crs1_1g     ;
     288: logic                   twu_crs2_1g     ;
>>   289: logic                   twu_crs1_2m     ;
     290: logic                   twu_crs2_2m     ;
     291: logic                   twu_crs2_chk    ;
```

`mmu/rtl/twu.sv:290`

```systemverilog
     288: logic                   twu_crs2_1g     ;
     289: logic                   twu_crs1_2m     ;
>>   290: logic                   twu_crs2_2m     ;
     291: logic                   twu_crs2_chk    ;
     292: logic [VPN_WIDTH-1:0]   csr_vpn_flop    ;
```

`mmu/rtl/twu.sv:291`

```systemverilog
     289: logic                   twu_crs1_2m     ;
     290: logic                   twu_crs2_2m     ;
>>   291: logic                   twu_crs2_chk    ;
     292: logic [VPN_WIDTH-1:0]   csr_vpn_flop    ;
     293: logic [TYPE_WIDTH-1:0]  csr_type_flop   ;
```

`mmu/rtl/twu.sv:292`

```systemverilog
     290: logic                   twu_crs2_2m     ;
     291: logic                   twu_crs2_chk    ;
>>   292: logic [VPN_WIDTH-1:0]   csr_vpn_flop    ;
     293: logic [TYPE_WIDTH-1:0]  csr_type_flop   ;
     294: logic [ID_WIDTH-1:0]    csr_id_flop     ;
```

`mmu/rtl/twu.sv:293`

```systemverilog
     291: logic                   twu_crs2_chk    ;
     292: logic [VPN_WIDTH-1:0]   csr_vpn_flop    ;
>>   293: logic [TYPE_WIDTH-1:0]  csr_type_flop   ;
     294: logic [ID_WIDTH-1:0]    csr_id_flop     ;
     295: logic [PADDR_WIDTH-1:0] twu_sysmap_adder;
```

`mmu/rtl/twu.sv:294`

```systemverilog
     292: logic [VPN_WIDTH-1:0]   csr_vpn_flop    ;
     293: logic [TYPE_WIDTH-1:0]  csr_type_flop   ;
>>   294: logic [ID_WIDTH-1:0]    csr_id_flop     ;
     295: logic [PADDR_WIDTH-1:0] twu_sysmap_adder;
     296: logic [DATA_WIDTH-1:0]  csr_data_flop   ;
```

`mmu/rtl/twu.sv:295`

```systemverilog
     293: logic [TYPE_WIDTH-1:0]  csr_type_flop   ;
     294: logic [ID_WIDTH-1:0]    csr_id_flop     ;
>>   295: logic [PADDR_WIDTH-1:0] twu_sysmap_adder;
     296: logic [DATA_WIDTH-1:0]  csr_data_flop   ;
     297: logic [PGS_WIDTH-1:0]   csr_refill_pgs  ;
```

`mmu/rtl/twu.sv:296`

```systemverilog
     294: logic [ID_WIDTH-1:0]    csr_id_flop     ;
     295: logic [PADDR_WIDTH-1:0] twu_sysmap_adder;
>>   296: logic [DATA_WIDTH-1:0]  csr_data_flop   ;
     297: logic [PGS_WIDTH-1:0]   csr_refill_pgs  ;
     298: logic [7:0]             twu_hit_num     ;
```

`mmu/rtl/twu.sv:297`

```systemverilog
     295: logic [PADDR_WIDTH-1:0] twu_sysmap_adder;
     296: logic [DATA_WIDTH-1:0]  csr_data_flop   ;
>>   297: logic [PGS_WIDTH-1:0]   csr_refill_pgs  ;
     298: logic [7:0]             twu_hit_num     ;
     299: logic                   twu_csr_cross   ;
```

`mmu/rtl/twu.sv:298`

```systemverilog
     296: logic [DATA_WIDTH-1:0]  csr_data_flop   ;
     297: logic [PGS_WIDTH-1:0]   csr_refill_pgs  ;
>>   298: logic [7:0]             twu_hit_num     ;
     299: logic                   twu_csr_cross   ;
     300: logic                   csr_fetch_type  ;
```

`mmu/rtl/twu.sv:302`

```systemverilog
     300: logic                   csr_fetch_type  ;
     301: logic                   csr_refill_req  ;
>>   302: logic [RDATA_WIDTH-1:0] csr_refill_data ;
     303: logic [TAG_WIDTH-1:0]   csr_refill_tag  ;
     304: logic [TYPE_WIDTH-1:0]  csr_refill_type ;
```

`mmu/rtl/twu.sv:303`

```systemverilog
     301: logic                   csr_refill_req  ;
     302: logic [RDATA_WIDTH-1:0] csr_refill_data ;
>>   303: logic [TAG_WIDTH-1:0]   csr_refill_tag  ;
     304: logic [TYPE_WIDTH-1:0]  csr_refill_type ;
     305: logic [ID_WIDTH-1:0]    csr_refill_id   ;
```

`mmu/rtl/twu.sv:304`

```systemverilog
     302: logic [RDATA_WIDTH-1:0] csr_refill_data ;
     303: logic [TAG_WIDTH-1:0]   csr_refill_tag  ;
>>   304: logic [TYPE_WIDTH-1:0]  csr_refill_type ;
     305: logic [ID_WIDTH-1:0]    csr_refill_id   ;
     306: //logic				twu_arb_ref_req      ;
```

`mmu/rtl/twu.sv:305`

```systemverilog
     303: logic [TAG_WIDTH-1:0]   csr_refill_tag  ;
     304: logic [TYPE_WIDTH-1:0]  csr_refill_type ;
>>   305: logic [ID_WIDTH-1:0]    csr_refill_id   ;
     306: //logic				twu_arb_ref_req      ;
     307: logic fst_chk_itlb_sel;
```

`mmu/rtl/twu.sv:307`

```systemverilog
     305: logic [ID_WIDTH-1:0]    csr_refill_id   ;
     306: //logic				twu_arb_ref_req      ;
>>   307: logic fst_chk_itlb_sel;
     308: logic scd_chk_itlb_sel;
     309: logic thd_chk_itlb_sel;
```

`mmu/rtl/twu.sv:308`

```systemverilog
     306: //logic				twu_arb_ref_req      ;
     307: logic fst_chk_itlb_sel;
>>   308: logic scd_chk_itlb_sel;
     309: logic thd_chk_itlb_sel;
     310: //logic				csr_itlb_sel         ;
```

`mmu/rtl/twu.sv:312`

```systemverilog
     310: //logic				csr_itlb_sel         ;
     311: logic                   refill_itlb_sel     ;
>>   312: logic [3:0]             refill_grant        ;
     313: logic                   refill_csr_grant    ;
     314: logic                   refill_fst_chk_grant;
```

`mmu/rtl/twu.sv:314`

```systemverilog
     312: logic [3:0]             refill_grant        ;
     313: logic                   refill_csr_grant    ;
>>   314: logic                   refill_fst_chk_grant;
     315: logic                   refill_scd_chk_grant;
     316: logic                   refill_thd_chk_grant;
```

`mmu/rtl/twu.sv:317`

```systemverilog
     315: logic                   refill_scd_chk_grant;
     316: logic                   refill_thd_chk_grant;
>>   317: logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;
     318: logic [PPN_WIDTH-1:0]   scd_pmp_ppn         ;
     319: logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;
```

`mmu/rtl/twu.sv:318`

```systemverilog
     316: logic                   refill_thd_chk_grant;
     317: logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;
>>   318: logic [PPN_WIDTH-1:0]   scd_pmp_ppn         ;
     319: logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;
     320: logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;
```

`mmu/rtl/twu.sv:319`

```systemverilog
     317: logic [RDATA_WIDTH-1:0] fst_chk_refill_data ;
     318: logic [PPN_WIDTH-1:0]   scd_pmp_ppn         ;
>>   319: logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;
     320: logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;
     321: logic [PPN_WIDTH-1:0]   thd_pmp_ppn         ;
```

`mmu/rtl/twu.sv:320`

```systemverilog
     318: logic [PPN_WIDTH-1:0]   scd_pmp_ppn         ;
     319: logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;
>>   320: logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;
     321: logic [PPN_WIDTH-1:0]   thd_pmp_ppn         ;
     322: //logic	[TYPE_WIDTH-1:0]			twu_l2tlb_ref_pgflt_type;
```

`mmu/rtl/twu.sv:321`

```systemverilog
     319: logic [RDATA_WIDTH-1:0] scd_chk_refill_data ;
     320: logic [RDATA_WIDTH-1:0] thd_chk_refill_data ;
>>   321: logic [PPN_WIDTH-1:0]   thd_pmp_ppn         ;
     322: //logic	[TYPE_WIDTH-1:0]			twu_l2tlb_ref_pgflt_type;
     323: //logic	[6:0]			twu_l2tlb_ref_pgflt_id;
```

`mmu/rtl/twu.sv:329`

```systemverilog
     327: //logic   [6:0]                   twu_l2tlb_ref_acc_err_id;
     328: //logic	[5:0]			csr_id			;
>>   329: logic ptw_chk_cross   ;
     330: logic ptw_crs2_1g     ;
     331: logic ptw_crs2_2m     ;
```

`mmu/rtl/twu.sv:330`

```systemverilog
     328: //logic	[5:0]			csr_id			;
     329: logic ptw_chk_cross   ;
>>   330: logic ptw_crs2_1g     ;
     331: logic ptw_crs2_2m     ;
     332: logic twu_crs_1g      ;
```

`mmu/rtl/twu.sv:331`

```systemverilog
     329: logic ptw_chk_cross   ;
     330: logic ptw_crs2_1g     ;
>>   331: logic ptw_crs2_2m     ;
     332: logic twu_crs_1g      ;
     333: logic twu_crs_2m      ;
```

`mmu/rtl/twu.sv:336`

```systemverilog
     334: logic twu_crs_chk     ;
     335: logic csr_ref_itlb_sel;
>>   336: logic fst_ref_sel     ;
     337: logic scd_ref_sel     ;
     338: logic thd_ref_sel     ;
```

`mmu/rtl/twu.sv:345`

```systemverilog
     343: logic scd_pmp_sel     ;
     344: logic thd_pmp_sel     ;
>>   345: logic fst_chk_ready   ;
     346: logic scd_chk_ready   ;
     347: logic thd_chk_ready   ;
```

`mmu/rtl/twu.sv:346`

```systemverilog
     344: logic thd_pmp_sel     ;
     345: logic fst_chk_ready   ;
>>   346: logic scd_chk_ready   ;
     347: logic thd_chk_ready   ;
     348: //logic   [2:0]       twu_data_ready;
```

`mmu/rtl/twu.sv:349`

```systemverilog
     347: logic thd_chk_ready   ;
     348: //logic   [2:0]       twu_data_ready;
>>   349: logic twu_clk_en    ;
     350: logic twu_clk       ;
     351: logic twu_refill_vld;
```

`mmu/rtl/twu.sv:352`

```systemverilog
     350: logic twu_clk       ;
     351: logic twu_refill_vld;
>>   352: logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;
     353: logic  			        thd_chk_refill_no_maee_sel;
     354: logic [RDATA_WIDTH-1:0] twu_ref_data_din;
```

`mmu/rtl/twu.sv:354`

```systemverilog
     352: logic [RDATA_WIDTH-1:0] thd_chk_refill_data_no_maee;
     353: logic  			        thd_chk_refill_no_maee_sel;
>>   354: logic [RDATA_WIDTH-1:0] twu_ref_data_din;
     355: logic [TAG_WIDTH-1:0]   twu_ref_tag_din;
     356: logic [PGS_WIDTH-1:0]   twu_ref_pgs;
```

`mmu/rtl/twu.sv:355`

```systemverilog
     353: logic  			        thd_chk_refill_no_maee_sel;
     354: logic [RDATA_WIDTH-1:0] twu_ref_data_din;
>>   355: logic [TAG_WIDTH-1:0]   twu_ref_tag_din;
     356: logic [PGS_WIDTH-1:0]   twu_ref_pgs;
     357: logic [TYPE_WIDTH-1:0]  twu_ref_type;
```

`mmu/rtl/twu.sv:356`

```systemverilog
     354: logic [RDATA_WIDTH-1:0] twu_ref_data_din;
     355: logic [TAG_WIDTH-1:0]   twu_ref_tag_din;
>>   356: logic [PGS_WIDTH-1:0]   twu_ref_pgs;
     357: logic [TYPE_WIDTH-1:0]  twu_ref_type;
     358: logic [ID_WIDTH-1:0]    twu_ref_id;
```

`mmu/rtl/twu.sv:358`

```systemverilog
     356: logic [PGS_WIDTH-1:0]   twu_ref_pgs;
     357: logic [TYPE_WIDTH-1:0]  twu_ref_type;
>>   358: logic [ID_WIDTH-1:0]    twu_ref_id;
     359: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;
     360: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
```

`mmu/rtl/twu.sv:359`

```systemverilog
     357: logic [TYPE_WIDTH-1:0]  twu_ref_type;
     358: logic [ID_WIDTH-1:0]    twu_ref_id;
>>   359: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;
     360: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
     361: logic [4:0] 			sysmap_mmu_flg;
```

`mmu/rtl/twu.sv:360`

```systemverilog
     358: logic [ID_WIDTH-1:0]    twu_ref_id;
     359: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;
>>   360: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
     361: logic [4:0] 			sysmap_mmu_flg;
     362: logic [3:0]             fst_chk_l1pmpflg;
```

`mmu/rtl/twu.sv:361`

```systemverilog
     359: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx1;
     360: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
>>   361: logic [4:0] 			sysmap_mmu_flg;
     362: logic [3:0]             fst_chk_l1pmpflg;
     363: logic [3:0]             scd_pmp_l1pmpflg;
```

`mmu/rtl/twu.sv:362`

```systemverilog
     360: logic [PADDR_WIDTH-1:0] twu_sysmap_adderx2;
     361: logic [4:0] 			sysmap_mmu_flg;
>>   362: logic [3:0]             fst_chk_l1pmpflg;
     363: logic [3:0]             scd_pmp_l1pmpflg;
     364: 
```

`mmu/rtl/twu.sv:363`

```systemverilog
     361: logic [4:0] 			sysmap_mmu_flg;
     362: logic [3:0]             fst_chk_l1pmpflg;
>>   363: logic [3:0]             scd_pmp_l1pmpflg;
     364: 
     365: assign twu_clk_en = 1'b1;
```
