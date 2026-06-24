# L1DTLB / L2TLB Covergroup 覆盖率缺口分析

> 生成日期：2026-06-23
> 对比来源：
> - `doc/l1dtlb_uvm_audit/l1dtlb_testpoint_audit.md`（42 个审计项 L1DTLB-AUD-001 ~ 042）
> - `doc/l2tlb_uvm_audit/l2tlb_function_description.md` §6.2（58 个测试点 L2TLB_TP_001 ~ 058）
> - `testbench/env/mmu_env_cg_whitebox.svh`（现有 36 个 covergroup）
> - `testbench/env/mmu_dut_probes_if.sv`（可用 probe 信号清单）

---

## 1. L1DTLB 缺口分析

### 1.1 现有覆盖（`cg_l1dtlb`，14 个 coverpoint）

| coverpoint | 覆盖内容 | 状态 |
|-----------|---------|------|
| `cp_entry_occupancy` | TLB entry 占用率 (0/1-4/5-12/13-15/16) | ✅ |
| `cp_mb_occupancy` | MB 占用率 (0/1-3/4-7/8) | ✅ |
| `cp_fsm_state` | MB FSM 状态 (idle/wfg/wfc/pgflt/acflt/abt/wfi) | ✅ |
| `cp_dual_lookup` | 双端口并发类型 (none/dual_hit/hit_miss/dual_miss) | ✅ |
| `cp_refill_src` | refill 来源 (none/ptw/l2/wfi) | ✅ |
| `cp_refill_pgs` | refill 页大小 (4K/2M/1G) | ✅ |
| `cp_hit_pgs` | hit 页大小 (4K/2M/1G) | ✅ |
| `cp_one_free_dual_diff` | 单空闲双 miss 不同 VPN | ✅ |
| `cp_stamo_kind` | STAMO 类型 | ✅ |
| `cp_direct_kind` | 直接映射类型 | ✅ |
| `cp_l2_req` / `cp_l2_req_eid` / `cp_l2_req_type` | L2 请求及属性 | ✅ |
| `cp_credit_cnt` | 调度 credit 计数器 (0/1-3/4-7/8) | ✅ |

### 1.2 审计测试点 vs covergroup 对照表

| 审计 ID | 功能描述 | 对应 coverpoint | 状态 | 缺失原因 |
|---------|---------|----------------|------|---------|
| AUD-001 | Pipe0 basic hit | `cp_hit_pgs` + `cp_dual_lookup` | ✅ | — |
| AUD-002 | Pipe1 basic hit | `cp_hit_pgs` + `cp_dual_lookup` | ✅ | — |
| AUD-003 | Same-cycle dual hit | `cp_dual_lookup` bin `dual_hit` | ✅ | — |
| AUD-004 | Hit+miss same cycle | `cp_dual_lookup` bin `hit_miss` | ✅ | — |
| AUD-005 | Dual miss same 4K dedup | `cp_one_free_dual_diff` | ✅ | — |
| AUD-006 | Dual miss different 4K, two free | `cp_dual_lookup` bin `dual_miss` | ⚠️ | 缺两个不同 VPN 都分配的交叉验证 |
| AUD-007 | Dual miss diff 4K, one free (IID priority) | — | ❌ | 缺 IID 优先级 coverpoint |
| AUD-008 | MB full=8 drop/retry | `cp_mb_occupancy` bin `full={8}` | ✅ | — |
| AUD-009 | `tlb_busy` semantics | — | ❌ | 缺 `tlb_busy` × `mb_occupancy` cross |
| AUD-010 | Wakeup: refill时 OR MB有pgflt/acflt entry时拉高 (l1dtlb_function_description.txt line 8) | — | ❌ | 缺 wakeup 信号 coverpoint |
| AUD-011 | Abort+hit response | `cp_fsm_state` bin `abt` | ⚠️ | 有 abt 状态，缺 abort×hit cross |
| AUD-012 | Abort+miss no-allocate | — | ❌ | 缺 abort×miss 验证 |
| AUD-013 | Abort must not consume expt array | — | ❌ | 缺 abort×expt 交叉 |
| AUD-014 | `vabuf` no functional effect | — | ❌ | 未覆盖（低优先级守卫项） |
| AUD-015 | T0/T1 response timing (pulse width) | — | ❌ | 缺时序级 coverpoint |
| AUD-016 | Load R=0 page fault | — | ❌ | **无任何权限 fault coverpoint** |
| AUD-017 | Load MXR behavior | — | ❌ | 同上 |
| AUD-018 | Store W=0 and D=0 page faults | — | ❌ | 同上 |
| AUD-019 | Store flag→L2 request type | `cp_l2_req_type` (load/store) | ✅ | — |
| AUD-020 | MB CAM hit no-allocate/wakeup | — | ❌ | 缺 MB CAM hit 重复请求行为 |
| AUD-021 | Credit boundary (credit=0+return no-fire) | `cp_credit_cnt` | ⚠️ | 有计数，缺 credit=0 同拍 return 不发射的 cross |
| AUD-022 | Scheduler priority (old MB vs bypass) | — | ❌ | 缺调度优先级 coverpoint |
| AUD-023 | Bypass allocate+issue (WFG skip) | `cp_fsm_state` bin `wfc` | ⚠️ | 有 wfc，缺 bypass×issue cross |
| AUD-024 | Install arbitration WFI > PTW > L2 | — | ❌ | **缺 install 仲裁优先级** |
| AUD-025 | Multiple WFI entry selection | — | ❌ | spec_gap，待澄清 |
| AUD-026 | Refill fault→exception array, not TLB | — | ❌ | **缺 exception-CAM 写入路径** |
| AUD-027 | PTW+L2 simultaneous fault writes | — | ❌ | 缺双源 fault 同拍写入 |
| AUD-028 | Exception array replay and consume | — | ❌ | **缺 expt-CAM 生命周期** |
| AUD-029 | Dual pipe same exception entry | — | ❌ | 缺双端口同 expt entry 竞争 |
| AUD-030 | ABT late refill drain | `cp_fsm_state` bin `abt` | ⚠️ | 有 abt，缺 late-refill×abt cross |
| AUD-031 | RTU flush clears MB and exception array | — | ❌ | 缺 flush 清理行为 |
| AUD-032 | Full-associative match 4K/2M/1G | `cp_hit_pgs` | ✅ | — |
| AUD-033 | Multiple entries match same VA | — | ❌ | spec_gap，待澄清 |
| AUD-034 | Invalidate all clears L1DTLB entries | — | ❌ | **缺 invalidate 行为** |
| AUD-035 | SATP/ASID-related L1 clear | — | ❌ | |
| AUD-036 | VA invalidate low-8-bit clear | — | ❌ | |
| AUD-037 | Invalidate×hit same cycle race | — | ❌ | |
| AUD-038 | Invalidate×install same entry same cycle | — | ❌ | |
| AUD-039 | STAMO pipe0 bypass | `cp_stamo_kind` | ✅ | — |
| AUD-040 | STAMO pipe1 negative | `cp_stamo_kind` bin `pipe1_bypass` | ✅ | — |
| AUD-041 | MMU off / machine-mode direct map | `cp_direct_kind` | ✅ | — |
| AUD-042 | Reset initial state | — | ❌ | 缺 reset 后初始状态检查 |

### 1.3 缺口汇总

| 分类 | 审计项数 | 已覆盖 | 部分覆盖 | 完全缺失 |
|------|---------|--------|---------|---------|
| Hit/Miss/Alloc | 8 | 5 | 2 | 1 |
| Permission Fault | 3 | 0 | 0 | **3** |
| Exception-CAM | 4 | 0 | 0 | **4** |
| Invalidate | 5 | 0 | 0 | **5** |
| Abort | 3 | 0 | 1 | 2 |
| Install/Refill Arb | 2 | 0 | 0 | **2** |
| Scheduler/Credit | 3 | 0 | 2 | 1 |
| Wakeup/Busy | 2 | 0 | 0 | **2** |
| STAMO/Direct | 4 | 3 | 0 | 1 |
| Other | 8 | 4 | 1 | 3 |
| **合计** | **42** | **12** | **6** | **24** |

### 1.4 最大缺口归类（按严重程度）

**🔴 P0 — 权限 Fault（AUD-016/017/018）**
- 可用 probe：LSU vif `mmu_lsu_page_fault0/1`、`mmu_lsu_access_fault0/1`
- 建议新增：`cp_perm_fault` — page_fault / access_fault per pipe

**🔴 P0 — Exception-CAM 生命周期（AUD-026/027/028/029）**
- 可用 probe：`l1d_expt_wr0_vld`、`l1d_expt_wr1_vld`、`l1d_expt_pgflt0/1`、`l1d_expt_acflt0/1`、`l1d_expt_hit_vec`、`l1d_expt_wakeup`
- 建议新增：`cp_expt_wr`（写入），`cp_expt_replay`（replay/match）

**🔴 P0 — Invalidate（AUD-034/035/036/037/038）**
- 可用 probe：`tlboper_utlb_clr`、`tlboper_utlb_inv_va_req`、`tlboper_utlb_inv_va` + entry_vld 变化
- 建议新增：`cp_inv_type`（操作类型）

**🟡 P1 — Install 仲裁（AUD-024）**
- 可用 probe：`l1d_install_req_ptw/l2/wfi`、`l1d_install_sel_ptw/l2/wfi`
- 建议新增：`cp_install_arb`（仲裁结果）

**🟡 P1 — Wakeup / Busy（AUD-009/010）**
- Wakeup 语义已更新为：refill 时 OR MB 有 pgflt/acflt entry 时拉高（l1dtlb_function_description.txt line 8）
- 可用 probe：`l1d_expt_wakeup` + MB vld 计数
- 建议新增：`cx_mb_busy` cross，`cp_wakeup`

**🟢 P2 — Abort 细分（AUD-011/012/013）**
- 可用 probe：LSU vif abort 信号 + `l1d_p0_hit_vld/miss_vld`
- 建议新增：`cp_abort_kind`

**🟢 P2 — Credit 边界（AUD-021）**
- 可用 probe：`l1d_sched_credit_cnt` + `l1d_l2_req_vld` + `l1d_l2_credit_ret`
- 建议新增：`cx_credit_boundary`

---

## 2. L2TLB 缺口分析

### 2.1 现有覆盖

| 覆盖手段 | 覆盖内容 | 审计 TP 覆盖 |
|---------|---------|-------------|
| `cg_l2tlb_bank` (cp_bank/cp_way/cp_pgs + cx_bw) | bank×way 分布、页大小 | TP_054 (部分) |
| `cg_l2_reqq` (cp_alloc_idx/cp_depth) | ReqQ 分配索引和深度 | TP_004/005/007/008 (部分) |
| `cg_tlboper_fsm` | TLBOP 各 FSM 状态 | TP_034-042 (部分) |
| `mmu_l2tlb_mb_sva` (5 props) | MB valid/allocation | TP_017/020/022 |
| `mmu_l2tlb_rrpv_sva` (5 props) | RRPV 替换行为 | TP_045/047 |
| `mmu_l2tlb_rrpv_wbuf_sva` (8 props) | RRPV write buffer | TP_046 |
| `mmu_l2tlb_rrpv_exact_model` (8 props) | RRPV 精确模型(debug) | TP_045/047 |

### 2.2 58 个审计测试点逐个对照

| TP ID | 功能域 | 类型 | 现有覆盖 | 状态 |
|-------|--------|------|---------|------|
| TP_001 | cold reset | Black-box | — | ❌ |
| TP_002 | warm reset | Black-box | — | ❌ |
| TP_003 | UVM boundary audit | White-box | — | ❌ (meta) |
| TP_004 | ITLB ReqQ entry0 | Black-box | `cg_l2_reqq` cp_alloc_idx | ⚠️ 缺 source type |
| TP_005 | DTLB ReqQ alloc | Black-box | `cg_l2_reqq` cp_alloc_idx | ⚠️ 缺 eid/type 覆盖 |
| TP_006 | bypass issue | White-box | — | ❌ |
| TP_007 | MB full retry | Black-box | MB SVA | ⚠️ |
| TP_008 | credit return | Black-box | `cg_l2_reqq` cp_depth | ⚠️ |
| TP_009 | arbiter onehot | White-box | — | ❌ |
| TP_010 | arbiter priority | White-box | — | ❌ |
| TP_011 | arbiter payload | White-box | — | ❌ |
| TP_012 | ITLB 4KB single-hit | Black-box | — | ❌ |
| TP_013 | DTLB load/store single-hit | Black-box | — | ❌ |
| TP_014 | 2MB/1GB huge page hit | Black-box | — | ❌ |
| TP_015 | ASID/global match | Black-box | — | ❌ |
| TP_016 | multi-hit | Backdoor | — | ❌ |
| TP_017 | miss+MB alloc | Black-box | MB SVA | ⚠️ |
| TP_018 | PTW disabled miss | Black-box | — | ❌ |
| TP_019 | MB→PTW payload | White-box | — | ❌ |
| TP_020 | MB full no-overflow | Black-box | MB SVA | ⚠️ |
| TP_021 | MB duplicate alloc | Black-box | — | ❌ |
| TP_022 | MB alloc/dealloc race | White-box | MB SVA | ⚠️ |
| TP_023 | PTW ready backpressure | Black-box | `cg_ptw_ready_transition` | ✅ |
| TP_024 | PTW data completion | Black-box | — | ❌ |
| TP_025 | PTW page fault | Black-box | — | ❌ |
| TP_026 | PTW access error | Black-box | — | ❌ |
| TP_027 | illegal PTW completion | Negative | — | ❌ |
| TP_028 | PFU MMU-off direct | Black-box | — | ❌ |
| TP_029 | PFU L2 hit permission | Black-box | — | ❌ |
| TP_030 | PFU PTW completion | Black-box | — | ❌ |
| TP_031 | PFU flag fault | Black-box | — | ❌ |
| TP_032 | PFU PMP/sysmap deny | Black-box | — | ❌ |
| TP_033 | PFU error payload ignore | Black-box | — | ❌ |
| TP_034 | TLBP probe | Black-box | `cg_tlboper_fsm` | ⚠️ 缺 operation type |
| TP_035 | TLBR read | Black-box | `cg_tlboper_fsm` | ⚠️ |
| TP_036 | TLBWI write | Black-box | `cg_tlboper_fsm` | ⚠️ |
| TP_037 | TLBWR write | Black-box | `cg_tlboper_fsm` | ⚠️ |
| TP_038 | INVVA_ALL | Black-box | — | ❌ |
| TP_039 | INVASID | Black-box | — | ❌ |
| TP_040 | INVVA_ASID | Black-box | — | ❌ |
| TP_041 | INVALL | Black-box | — | ❌ |
| TP_042 | TLBOP lifecycle | White-box | `cg_tlboper_fsm` | ⚠️ |
| TP_043 | TLBOP+reset | Black-box | — | ❌ |
| TP_044 | abort | Black-box | — | ❌ |
| TP_045 | RRPV init | White-box | RRPV SVA | ✅ |
| TP_046 | RRPV wbuf | White-box | RRPV wbuf SVA | ✅ |
| TP_047 | replacement | White-box | RRPV SVA | ⚠️ |
| TP_048 | illegal input | Negative | — | ❌ |
| TP_049 | timeout/fairness | Black-box | — | ❌ |
| TP_050 | coverage closure | White-box | (meta) | — |
| TP_051 | ptw_on stall | White-box | — | ❌ |
| TP_052 | tlboper_on stall | White-box | — | ❌ |
| TP_053 | prefetch_mask | Black-box | — | ❌ |
| TP_054 | skew/index/bank mask | White-box | `cg_l2tlb_bank` cp_bank | ⚠️ |
| TP_055 | MB partition ITLB vs DTLB | Black-box | — | ❌ |
| TP_056 | PTW out-of-order completion | Black-box | — | ❌ |
| TP_057 | PFU truth table | Black-box | — | ❌ |
| TP_058 | control hazard | Negative | — | ❌ |

### 2.3 缺口汇总

| 分类 | TP 数 | 有覆盖 | 部分覆盖 | 完全缺失 |
|------|-------|--------|---------|---------|
| ReqQ | 5 | 0 | 4 | 1 |
| Arbiter | 3 | 0 | 0 | **3** |
| Tag/Data Lookup | 5 | 0 | 0 | **5** |
| Miss Buffer | 6 | 0 | 4 | 2 |
| PTW Interface/Refill | 5 | 1 | 0 | **4** |
| PFU | 6 | 0 | 0 | **6** |
| TLB Operation | 10 | 0 | 8 | 2 |
| Abort | 1 | 0 | 0 | 1 |
| Reset | 3 | 0 | 0 | **3** |
| RRPV/victim | 3 | 2 | 1 | 0 |
| Arbiter blocking | 3 | 0 | 0 | **3** |
| MB partition/OOO | 2 | 0 | 0 | 2 |
| Illegal/Negative | 3 | 0 | 0 | **3** |
| Other | 3 | 0 | 0 | 3 |
| **合计** | **58** | **3** | **17** | **38** |

### 2.4 最大缺口归类

**🔴 P0 — Tag/Data Lookup（TP_012-016）**
- 缺 hit/miss、page size、ASID/global match、multi-hit 分类
- 可用 probe：`l2_final_vld`、`l2_final_tlb_hit`、`l2_miss`、`l2_raw_pre_pgs0`、`l2_final_is_dtlb`、`l2_final_vpn`
- 建议新增：`cg_l2tlb_lookup` — cp_hit_result, cp_page_size, cp_source_type

**🔴 P0 — PFU 全部 6 条路径（TP_028-033/053/057）**
- 缺 PFU direct/L2 hit/PTW 三条路径和 deny/fault 结果
- 可用 probe：`l2_pfu_req_vld`、`l2_pfu_rsp_vld`、`l2_pfu_rsp_pa`、`pfu_l2tlb_deny`、`pfu_l2tlb_flag_fault`、`pfu_l2tlb_acc_fault`、`arb_pfu_grant`
- 建议新增：`cg_l2tlb_pfu` — cp_path, cp_result, cp_fault_kind

**🔴 P0 — PTW Interface/Refill（TP_023-027）**
- 缺 PTW req/cmplt/fault completion
- 可用 probe：`l2tlb_ptw_req`、`ptw_l2tlb_cmplt`、`ptw_l2tlb_ref_data_vld`、`ptw_l2tlb_ref_pgflt`、`ptw_l2tlb_ref_acc_err`、`l2tlb_ptw_id/type/vpn`
- 建议新增：`cg_l2tlb_ptw_if` — cp_req, cp_cmplt_type, cp_cmplt_source

**🟡 P1 — Arbiter（TP_009-011/051-054）**
- 缺多 source 竞争、优先级、onehot、bank skew
- 可用 probe：`l2_arb_req`、`l2_arb_write`、`l2_arb_acc_type`、`l2_arb_bank_sel`、`arb_l2tlb_req`、`arb_pfu_grant`
- 建议新增：`cg_l2tlb_arbiter` — cp_source, cp_bank_sel, cp_acc_type

**🟡 P1 — TLB Operation 分类（TP_034-043）**
- `cg_tlboper_fsm` 只覆盖 FSM 状态，缺 operation type（TLBP/R/WI/WR/INV*）的分类
- 可用 probe：`tlbop_l2_tlboper_cmplt`、`tlbop_l2_tlboper_sel`、各 FSM 状态
- 建议新增：cp_op_type（在 `cg_tlboper_fsm` 中追加）

**🟢 P2 — Reset（TP_001-002/043）**
- 缺 reset 后初始状态，warm reset 打断

**🟢 P2 — MB partition（TP_055）**
- 可用 probe：`l2mb_entry_queue_id`

---

## 3. 可用 Probe 信号清单

### 3.1 已有但未被 covergroup 使用的 L1DTLB probe

| Probe 信号 | 可用于覆盖 |
|-----------|-----------|
| `l1d_p0_hit_vld` / `l1d_p1_hit_vld` | AUD-001/002 hit 验证 |
| `l1d_p0_miss_vld` / `l1d_p1_miss_vld` | AUD-004/006 miss 验证 |
| `l1d_p0_expt_match` / `l1d_p1_expt_match` | AUD-028/029 expt match |
| `l1d_expt_wr0_vld` / `l1d_expt_wr1_vld` | AUD-026/027 expt write |
| `l1d_expt_pgflt0/1` / `l1d_expt_acflt0/1` | AUD-026/027 fault type |
| `l1d_expt_hit_vec` / `l1d_expt_wakeup` | AUD-028/010 expt replay/wakeup |
| `l1d_expt_clear_req` | AUD-031 expt clear |
| `l1d_install_req_ptw/l2/wfi` | AUD-024 install request |
| `l1d_install_sel_ptw/l2/wfi` | AUD-024 install select |
| `l1d_cp0_mxr` / `l1d_cp0_sum` / `l1d_cp0_mprv` | AUD-017/018 权限配置 |
| `tlboper_utlb_clr` | AUD-034 invalidate all |
| `tlboper_utlb_inv_va_req` / `tlboper_utlb_inv_va` | AUD-036 VA invalidate |

### 3.2 已有但未被 covergroup 使用的 L2TLB probe

| Probe 信号 | 可用于覆盖 |
|-----------|-----------|
| `l2_final_vld` / `l2_final_tlb_hit` / `l2_miss` | TP_012-016 lookup result |
| `l2_final_vpn` / `l2_final_hit_ppn` | TP_012/014 tag/PA match |
| `l2_final_is_dtlb` | TP_004/005 source type |
| `l2_final_acc_type` | TP_013 load/store 分类 |
| `l2_raw_pre_pgs0` | TP_014 page size |
| `l2_final_way_hit` / `l2_victim_way` | TP_047 replacement |
| `l2_arb_req` / `l2_arb_write` / `l2_arb_acc_type` | TP_009-011 arbiter |
| `l2_arb_bank_sel` | TP_054 bank select |
| `l2_pfu_req_vld` / `l2_pfu_req_vpn` | TP_028-033 PFU request |
| `l2_pfu_rsp_vld` / `l2_pfu_rsp_pa` | TP_028-033 PFU response |
| `pfu_l2tlb_deny` / `pfu_l2tlb_flag_fault` / `pfu_l2tlb_acc_fault` | TP_031/032 PFU fault |
| `l2tlb_ptw_req` / `l2tlb_ptw_id/type/vpn` | TP_019/023 PTW interface |
| `ptw_l2tlb_cmplt` / `ptw_l2tlb_ref_data_vld` | TP_024 PTW completion |
| `ptw_l2tlb_ref_pgflt` / `ptw_l2tlb_ref_acc_err` | TP_025/026 PTW fault |
| `tlboper_ptw_abort` | TP_044 abort |
| `l2mb_entry_queue_id` / `l2mb_entry_vld` | TP_055 MB partition |
| `pfu_pmp_flg4` / `pfu_sysmap_flg4` | TP_057 PFU truth table |

---

## 4. 修复优先级建议

### 4.1 L1DTLB — 在 `cg_l1dtlb` 中新增 coverpoint

| 优先级 | 新增 coverpoint | 覆盖审计项 | 依赖 probe |
|--------|---------------|-----------|-----------|
| P0 | `cp_perm_fault` | AUD-016/017/018 | LSU vif page_fault/access_fault |
| P0 | `cp_expt_wr` | AUD-026/027 | `l1d_expt_wr0/1_vld`, `l1d_expt_pgflt/acflt` |
| P0 | `cp_expt_replay` | AUD-028/029 | `l1d_p0/1_expt_match`, `l1d_expt_hit_vec` |
| P1 | `cp_inv_type` | AUD-034/035/036 | `tlboper_utlb_clr`, `tlboper_utlb_inv_va_req` |
| P1 | `cp_install_arb` | AUD-024 | `l1d_install_sel_ptw/l2/wfi` |
| P1 | `cx_mb_busy` | AUD-009 | LSU vif `tlb_busy` × `l1d_mb_vld` 计数 |
| P2 | `cp_abort_kind` | AUD-011/012 | LSU vif abort + hit/miss |
| P2 | `cp_wakeup` | AUD-010 | `l1d_expt_wakeup` |
| P2 | `cx_credit_boundary` | AUD-021 | `l1d_sched_credit_cnt` + `l1d_l2_req_vld` |

### 4.2 L2TLB — 新建 covergroup

| 优先级 | 新 covergroup | 覆盖 TP | 依赖 probe |
|--------|-------------|---------|-----------|
| P0 | `cg_l2tlb_lookup` | TP_012-016 | `l2_final_vld/hit/miss`, `l2_raw_pre_pgs0`, `l2_final_is_dtlb` |
| P0 | `cg_l2tlb_pfu` | TP_028-033 | `l2_pfu_req/rsp_vld`, `pfu_l2tlb_deny/flag_fault/acc_fault` |
| P0 | `cg_l2tlb_ptw_if` | TP_023-027 | `l2tlb_ptw_req`, `ptw_l2tlb_cmplt/data_vld/pgflt/acc_err` |
| P1 | `cg_l2tlb_arbiter` | TP_009-011/051-054 | `l2_arb_req/write/acc_type/bank_sel` |
| P1 | `cp_op_type` (追加到 `cg_tlboper_fsm`) | TP_034-043 | `tlbop_l2_tlboper_cmplt`, FSM states |
| P2 | `cg_l2tlb_mb_part` | TP_055 | `l2mb_entry_queue_id` |
| P2 | `cg_l2tlb_reset` | TP_001-002 | `cpurst_b` + valid 清零观测 |

---

## 5. 实现注意事项

1. **采样时机**：所有 covergroup 在 `sample_dut()` 中统一赋值成员变量后在 `run_phase` 的 `@(posedge clk_i)` 中采样，rst 期间 skip。

2. **`cg_l1dtlb` 拆分风险**：当前 `cg_l1dtlb` 通过 `sample_l1dtlb_covergroup()` 按 FSM state 多次调用 `.sample()`，新增的 permission fault / expt 等 coverpoint 采样条件与 FSM state 无关，需要独立的 sample 逻辑（直接在 `run_phase` 中按条件 sample，不走 FSM state 循环）。

3. **LSU/IFU vif 依赖**：部分 probe（如 page_fault、tlb_busy）来自 `lsu_vif` / `ifu_vif`，vif null 时对应 coverpoint 不采样。

4. **新增 covergroup 注册**：需要在 `new()` 中实例化、`run_phase()` 中 sample、`final_phase()` 中打印覆盖率。

5. **向后兼容**：`cg_l1dtlb` 的现有 `sample_l1dtlb_covergroup()` 调用路径保持不动，新增的独立 sample 调用在 `run_phase` 中追加。

---

## 6. 文档追溯

| 文档 | 路径 | 用途 |
|------|------|------|
| L1DTLB 审计测试点 | `doc/l1dtlb_uvm_audit/l1dtlb_testpoint_audit.md` | 42 个审计项 |
| L2TLB 功能描述+测试点 | `doc/l2tlb_uvm_audit/l2tlb_function_description.md` §6.2 | 58 个测试点 |
| 现有 covergroup 实现 | `testbench/env/mmu_env_cg_whitebox.svh` | 36 个 covergroup，1114 行 |
| Probe 接口定义 | `testbench/env/mmu_dut_probes_if.sv` | ~220 个 probe 信号 |
| Probe 接线 | `testbench/top/tb_top.sv` | tb_top 中 assign 到 probe if |
| 验证计划 | `doc/archive_merged_20260607/MMU_VerificationPlan.md` | 219 条 Feature→TC→cg 追溯 |
