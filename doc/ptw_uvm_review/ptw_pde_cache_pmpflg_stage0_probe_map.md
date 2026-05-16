# PTW PDE Cache PMP Flag Stage 0 Probe Map

本文件记录 `ptw_pde_cache_pmpflg_staged_implementation_plan.md` 阶段 0 的 RTL/UVM 信号审计结果。阶段 0 只冻结语义、信号名、层级路径、观测方案和 gap，不修改 RTL/UVM SystemVerilog 源码，不新增 test，不改 regression list。

审计日期：2026-05-16

## 1. 设计语义摘要

`pmpflg[3:0]` 是读取 page-table memory 时 PMP 返回的 evidence。PDE cache entry 保存这个 evidence，后续 lookup 必须按当前 PTW request `type` 重新解释，而不是把 entry 视为 tag-only hit。

| Request type | 编码 | 使用 bit | 备注 |
| --- | --- | --- | --- |
| Fetch | `3'b011` | `pmpflg[2]` | I-side PTW。 |
| Load | `3'b010` | `pmpflg[0]` | D-side load。 |
| Store/atomic | `3'b110` | `pmpflg[1]` | Store 和 atomic 同类。 |
| PFU | `3'b100` | `pmpflg[0]` | PFU 按 load 权限。 |
| effective M-mode | N/A | `pmpflg[3]` | `pmpflg[3]==0` 可 bypass type bit；`pmpflg[3]==1` 不可 bypass。 |

关键行为：

1. L1 PDE entry 保存 `L1PDE_l1pmpflg`。L1 tag match 但 cached L1 PMP deny 时不产生 PDE direct access fault，只表现为 L1 miss，继续进入 `fst_pmp`。
2. L2 PDE entry 保存 `L2PDE_l1pmpflg` 和 `L2PDE_l2pmpflg`。L2 tag match 但任一级 cached PMP deny 时产生 PDE cache direct access fault，不回退 L1 hit，不重新发 LSU page-table read。
3. FST non-leaf update L1 时保存 `mbuf_twu_pmpflg[3:0]`。SCD non-leaf update L2 时保存 `{l2pmpflg,l1pmpflg}=mbuf_twu_pmpflg[7:0]`。THD 不更新 PDE cache。
4. `regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update` 清空 PDE cache。当前 testbench 把 DUT `pmp_regs_update` tie 到 `1'b0`，这是现有环境 gap。

## 2. RTL 实际信号和层级路径

以下路径以 `tb_top.u_dut.x_ct_mmu_ptw` 为 PTW instance 根。

| 语义 | RTL 信号 | 层级路径或作用域 | 审计结论 |
| --- | --- | --- | --- |
| L1 update PMP input | `L1PDE_upd_l1pmpflg[3:0]` | `u_PDE_cache.u_L1PDE_ent[i].u_L1PDE_cache.L1PDE_upd_l1pmpflg` | 已存在，由 `mbuf_cache_upd_l1pmpflg` 驱动。 |
| L1 cached PMP entry | `L1PDE_l1pmpflg[3:0]` | `L1PDE_cache` 子实例内部 | 已存在，仅子实例内部可见。 |
| L1 permission-qualified hit | `L1PDE_hit` / `L1PDE_entry_hit` | `L1PDE_cache` 子实例输出到 `PDE_cache.L1PDE_entry_hit[i]` | 已存在。注意 per-entry hit 本身未 gate valid，top 用 `L1PDE_entry_vld & L1PDE_entry_hit` 形成 hit idx。 |
| L1 raw tag hit | commented `L1PDE_short_hit` | `L1PDE_cache.sv` 中被注释 | 当前无 dedicated raw tag hit 输出；可在 bind 内按 tag 重新计算。 |
| L1 PMP deny miss indicator | commented `L1PDE_miss_because_pmp` | `L1PDE_cache.sv` 中被注释 | 当前无 RTL 输出。后续只能由 raw tag hit + qualified hit + cached pmpflg 推导。 |
| L2 request gate | `ptw_req` | `u_PDE_cache.u_L2PDE_ent[i].u_L2PDE_cache.ptw_req` | 已存在，参与 direct accerr gate。 |
| L2 update PMP inputs | `L2PDE_upd_l1pmpflg[3:0]`, `L2PDE_upd_l2pmpflg[3:0]` | `u_PDE_cache.u_L2PDE_ent[i].u_L2PDE_cache.*` | 已存在，由 `mbuf_cache_upd_l1pmpflg/l2pmpflg` 驱动。 |
| L2 cached PMP entry | `L2PDE_l1pmpflg[3:0]`, `L2PDE_l2pmpflg[3:0]` | `L2PDE_cache` 子实例内部 | 已存在，仅子实例内部可见。 |
| L2 permission-qualified hit | `L2PDE_hit` / `L2PDE_entry_hit` | `PDE_cache.L2PDE_entry_hit[i]` | 已存在。top 用 `L2PDE_entry_vld & L2PDE_entry_hit` 形成 hit idx。 |
| L2 raw tag hit | expression only | `L2PDE_cache`: `ptw_vpn == L2PDE_tag` | 当前无 dedicated raw tag hit 输出；可在 bind 内按 tag 重新计算。 |
| L2 direct accerr per entry | `L2PDE_entry_acc_err` | `PDE_cache.L2PDE_entry_acc_err[i]` | 已存在，包含 `L2PDE_vld & ptw_req & tag_match & !allow`。 |
| Direct accerr pending | `PDE_cache_acc_err` | `u_PDE_cache.PDE_cache_acc_err` | 已存在，`L2PDE_entry_acc_err_vld` set，`PDE_cache_acc_err_grant` clear。 |
| Direct accerr visible outputs | `PDE_cache_acc_err_vld/type/id` | `u_PDE_cache.PDE_cache_acc_err_*` and PTW local `PDE_cache_acc_err_*` | 已存在，type/id 锁存当前 `ptw_type/id`。 |
| Direct accerr grant | `PDE_cache_acc_err_grant` | `u_PDE_cache.PDE_cache_acc_err_grant`, driven by `acc_err_twu_grant[5]` | 已存在。 |
| PDE update pmpflg from MBUF | `mbuf_cache_upd_l1pmpflg[3:0]`, `mbuf_cache_upd_l2pmpflg[3:0]` | PTW local and `u_PDE_cache` input | 已存在。 |
| TWU to MBUF pmpflg payload | `twu_mbuf_pmpflg[3:0][7:0]` | PTW local; each `twu` output | 已存在。FST `{4'b0,pmp_mmu_flg}`，SCD `{pmp_mmu_flg,scd_pmp_l1pmpflg}`，THD `8'b0`。 |
| MBUF entry stored pmpflg | `mbuf_entry_pmpflg[MBUF_ENTRY_NUM-1:0][7:0]` | `u_ptw_mbuf.mbuf_entry_pmpflg` | 已存在。 |
| MBUF return pmpflg | `mbuf_twu_pmpflg[7:0]` | PTW local, `u_ptw_mbuf.mbuf_twu_pmpflg` | 已存在，回传给所有 TWU 并生成 PDE update pmpflg。 |
| FST inherited l1 pmpflg | `fst_chk_l1pmpflg[3:0]` | each `twu` instance | 已存在，来自 `mbuf_twu_pmpflg[3:0]`。 |
| SCD inherited l1 pmpflg | `scd_pmp_l1pmpflg[3:0]` | each `twu` instance | 已存在，来自 `fst_chk_l1pmpflg`；L1 PDE hit 进入 SCD 时当前 RTL 置 `4'b0`，需后续阶段确认是否符合期望场景建模。 |
| Access fault arbitration | `acc_err_vld`, `twu_acc_err_sel[5:0]`, `acc_err_twu_grant[5:0]` | PTW top | 已存在。`acc_err_twu_grant[5]` 授权 PDE direct accerr。 |
| Completion type/id | `ptw_l2tlb_acc_err_type/id` | PTW top always_comb | 已存在，case `6'b100000` 选择 `PDE_cache_acc_err_type/id`。 |
| PMP config clear input | `pmp_regs_update` | `ptw` input, `PDE_cache` input | RTL 支持，但 testbench currently ties it to `1'b0`。 |

## 3. 当前 UVM 观测能力

| 范围 | 当前已接 probe | 当前缺口 |
| --- | --- | --- |
| `mmu_dut_probes_if.sv` | `pde_cache_req/ready/clear`, `pde_l1_hit_vld`, `pde_l2_hit_vld`, `pde_xbar_*`, `pde_cache_update`, `pde_cache_update_level/ppn/vpn`, `pde_l1_update_vec`, `pde_l2_update_vec` | 没有 pmpflg payload、raw tag hit、cached pmpflg entry、direct accerr vld/type/id/grant/vector。 |
| `tb_top.sv` | 已 assign 旧 PDE probe；`p13_pmp_*` vectors 可观察实时 PMP port。 | `pmp_regs_update` 和 `pmp_regs_update_probe` 均为 `1'b0`；PMP port flag 不能代替 MBUF saved pmpflg evidence。 |
| `ptw_source_monitor.svh` | `PTW_PDE_EVT` 可输出 hit/miss/update/clear；`PTW_LEVEL_EVT` 可输出 PMP vld/grant/deny/wait、MBUF req/data。 | PDE event transaction 没有 pmpflg、raw tag hit、deny reason、direct accerr；level event 没有 `twu_mbuf_pmpflg` 和 `mbuf_twu_pmpflg`。 |
| `ptw_source_types.svh` | `ptw_src_pde_evt_txn` 有 `l1_hit/l2_hit/update_level/update_vpn/update_ppn/update_vec`。 | 没有 pde reason/access source enum，没有 cached/update pmpflg 字段，没有 direct accerr type/id/grant 字段。 |
| `ptw_pde_cache_model.svh` | 16-entry L1/L2 tag-only abstract model，L2 hit wins，old-state update。 | Entry 未保存 pmpflg；lookup 未区分 raw tag hit、permission-qualified hit、L1 deny miss、L2 direct accerr。 |
| `mmu_pde_cache_sva.sv` | bind `PDE_cache`，能直接看到 `PDE_cache` scope 内的 hit/update/clear/ready/PPN signals。 | 端口未包含 pmpflg/direct accerr；当前 bind scope 不能直接看到 `L1PDE_cache`/`L2PDE_cache` 子实例内部 pmpflg entry，除非新增子模块 bind 或显式端口/层级引用。 |
| `mmu_ptw_top_sva.sv` | bind `ptw`，能看到 completion class priority 和 type/id route。 | 还没有 PDE direct accerr root-cause priority/type-id/pending assertions。 |

## 4. 必需观测信号表

| ID | 必需信号/事件 | RTL 实际来源 | Stage 0 分类 | 当前状态 | 影响 requirement |
| --- | --- | --- | --- | --- | --- |
| OBS-001 | PDE request key `{vpn,type,id}` | `u_PDE_cache.PDE_xbar_vpn/type/id`, `PDE_xbar_req` | monitor-probe | 已接旧 probe | PDE-TP-013..019, PTW-FLOW-024..028 |
| OBS-002 | L1 permission-qualified hit | `u_PDE_cache.L1PDE_xbar_hit_vld`, `L1PDE_entry_hit_idx` | monitor-probe + sva-bind | `pde_l1_hit_vld` 已接；entry idx 仅 SVA bind 当前可见 | PDE-TP-013, PTW-ADD-037/038 |
| OBS-003 | L2 permission-qualified hit | `u_PDE_cache.L2PDE_xbar_hit_vld`, `L2PDE_entry_hit_idx` | monitor-probe + sva-bind | `pde_l2_hit_vld` 已接；entry idx 仅 SVA bind 当前可见 | PDE-TP-014/015, PTW-ADD-039/040 |
| OBS-004 | L1 raw tag hit vector | child `L1PDE_tag` compared with current `ptw_vpn[26:18]` | sva-bind | gap for monitor; no RTL output | PDE-TP-013, PTW-FLOW-024 |
| OBS-005 | L2 raw tag hit vector | child `L2PDE_tag` compared with current `ptw_vpn[26:9]` | sva-bind | gap for monitor; no RTL output | PDE-TP-014/015/019, PTW-FLOW-025/026 |
| OBS-006 | L1 cached pmpflg per entry | child `L1PDE_l1pmpflg` | sva-bind | gap for monitor; child-internal only | PDE-TP-013/016/018 |
| OBS-007 | L2 cached pmpflg per entry | child `L2PDE_l1pmpflg/l2pmpflg` | sva-bind | gap for monitor; child-internal only | PDE-TP-014/015/016/018/019 |
| OBS-008 | PDE update pmpflg payload | PTW `mbuf_cache_upd_l1pmpflg/l2pmpflg` | monitor-probe | RTL path known; not currently in probe interface | PDE-TP-016, PTW-ADD-041/045 |
| OBS-009 | TWU request pmpflg payload | PTW `twu_mbuf_pmpflg[3:0][7:0]` | monitor-probe | RTL path known; not currently in probe interface | PDE-TP-016, PTW-ADD-041 |
| OBS-010 | MBUF stored pmpflg | `u_ptw_mbuf.mbuf_entry_pmpflg[*][7:0]` | monitor-probe or sva-bind | RTL path known; not currently in probe interface | PDE-TP-016, PTW-ADD-041/045 |
| OBS-011 | MBUF return pmpflg | PTW `mbuf_twu_pmpflg[7:0]` | monitor-probe | RTL path known; not currently in probe interface | PDE-TP-016, PTW-ADD-041/045 |
| OBS-012 | FST/SCD inherited pmpflg | child TWU `fst_chk_l1pmpflg`, `scd_pmp_l1pmpflg` | sva-bind | not currently monitored | PDE-TP-016, PTW-ADD-041 |
| OBS-013 | L2 entry direct accerr vector | `u_PDE_cache.L2PDE_entry_acc_err[15:0]` | monitor-probe + sva-bind | RTL path known; not currently in probe interface | PDE-TP-014/015/019 |
| OBS-014 | PDE direct accerr visible event | `u_PDE_cache.PDE_cache_acc_err_vld/type/id` | monitor-probe + sva-bind | RTL path known; not currently in probe interface | PDE-TP-014/015/017/019, PTW-ADD-039/040/042/044 |
| OBS-015 | PDE direct accerr grant/pending clear | `u_PDE_cache.PDE_cache_acc_err_grant`, PTW `acc_err_twu_grant[5]` | monitor-probe + sva-bind | RTL path known; not currently in probe interface | PDE-TP-017, PTW-ADD-042 |
| OBS-016 | PTW access-fault arbitration root cause | PTW `twu_acc_err_sel[5:0]`, `acc_err_twu_grant[5:0]` | sva-bind | no current root-cause monitor field | PDE-TP-017, PTW-ADD-042 |
| OBS-017 | No-extra-LSU evidence | existing `ptw_lsu_data_req`, `ptw_twu_mbuf_req`, plus direct accerr event | monitor-probe | LSU/TWU req probes exist; direct accerr root cause missing | PTW-FLOW-025/026, PTW-ADD-039/040 |
| OBS-018 | PMP config update clear reason | `ptw.pmp_regs_update`, `PDE_cache.pmp_regs_update` | gap | TB ties `pmp_regs_update` to `1'b0` | PDE-TP-010/016, PTW-ADD-045 |

## 5. UVM probe 映射方案

Stage 2 应在 `mmu_dut_probes_if.sv` 和 `tb_top.sv` 中补以下 monitor-side probes。阶段 0 不实现，只冻结建议命名和来源。

| 建议 probe | 位宽 | 建议 tb_top 来源 |
| --- | --- | --- |
| `pde_cache_update_l1pmpflg` | `[3:0]` | `u_dut.x_ct_mmu_ptw.mbuf_cache_upd_l1pmpflg` |
| `pde_cache_update_l2pmpflg` | `[3:0]` | `u_dut.x_ct_mmu_ptw.mbuf_cache_upd_l2pmpflg` |
| `ptw_twu_mbuf_pmpflg` | `[3:0][7:0]` | `u_dut.x_ct_mmu_ptw.twu_mbuf_pmpflg` |
| `ptw_mbuf_twu_pmpflg` | `[7:0]` | `u_dut.x_ct_mmu_ptw.mbuf_twu_pmpflg` |
| `ptw_mbuf_entry_pmpflg` | `[8:0][7:0]` | `u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mbuf_entry_pmpflg` |
| `pde_cache_acc_err_vld` | `1` | `u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_cache_acc_err_vld` |
| `pde_cache_acc_err_type` | `[2:0]` | `u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_cache_acc_err_type` |
| `pde_cache_acc_err_id` | `[5:0]` | `u_dut.x_ct_mmu_ptw.u_PDE_cache.PDE_cache_acc_err_id` |
| `pde_cache_acc_err_grant` | `1` | `u_dut.x_ct_mmu_ptw.acc_err_twu_grant[5]` or `u_PDE_cache.PDE_cache_acc_err_grant` |
| `pde_l2_entry_acc_err_vec` | `[15:0]` | `u_dut.x_ct_mmu_ptw.u_PDE_cache.L2PDE_entry_acc_err` |
| `pde_l1_hit_idx_vec` | `[15:0]` | `u_dut.x_ct_mmu_ptw.u_PDE_cache.L1PDE_entry_hit_idx` |
| `pde_l2_hit_idx_vec` | `[15:0]` | `u_dut.x_ct_mmu_ptw.u_PDE_cache.L2PDE_entry_hit_idx` |
| `ptw_acc_err_grant_vec` | `[5:0]` | `u_dut.x_ct_mmu_ptw.acc_err_twu_grant` |

不建议用 `p13_pmp_flg_vec` 代替 `twu_mbuf_pmpflg/mbuf_twu_pmpflg`，因为实时 PMP port flag 不能证明 MBUF entry 保存和返回的 cached evidence。

## 6. SVA bind 直连方案

Stage 6 应优先使用以下 bind 方案补足 monitor 不适合采样的 per-entry 子模块信息。

| 目标 | 建议 bind scope | 必需可见信号 | 用途 |
| --- | --- | --- | --- |
| L1 permission-qualified hit iff | `bind L1PDE_cache` | `L1PDE_vld`, `L1PDE_tag`, `L1PDE_l1pmpflg`, `ptw_vpn`, `ptw_type`, `cp0_mach_mode`, `L1PDE_entry_hit` | 证明 tag match but cached PMP deny 不拉高 L1 hit。 |
| L2 permission-qualified hit iff | `bind L2PDE_cache` | `L2PDE_vld`, `L2PDE_tag`, `L2PDE_l1pmpflg`, `L2PDE_l2pmpflg`, `ptw_req`, `ptw_vpn`, `ptw_type`, `cp0_mach_mode`, `L2PDE_entry_hit` | 证明 L2 hit 同时受 L1/L2 cached pmpflg gate。 |
| L2 direct accerr valid gate | `bind L2PDE_cache` | `L2PDE_entry_acc_err`, valid/tag/allow signals | 证明 invalid entry 或 `ptw_req=0` 不误报。 |
| PDE direct accerr pending/type/id | `bind PDE_cache` | `L2PDE_entry_acc_err`, `PDE_cache_acc_err_vld/type/id/grant`, `ptw_type/id` | 证明 pending set/clear 和 type/id lock。 |
| Access fault priority | `bind ptw` or extend `mmu_ptw_top_sva` | `PDE_cache_acc_err_vld/type/id`, `mbuf_bus_error`, `twu_l2tlb_ref_acc_err`, `acc_err_twu_grant`, `ptw_l2tlb_type/id` | 证明 PDE direct accerr priority 和 visible type/id。 |
| pmpflg payload propagation | `bind ptw_mbuf` and/or `bind twu` | `twu_mbuf_pmpflg`, `mbuf_entry_pmpflg`, `mbuf_twu_pmpflg`, `fst_chk_l1pmpflg`, `scd_pmp_l1pmpflg` | 证明 FST/SCD/THD payload 编码和继承。 |

## 7. 当前不可观测 gap

| Gap ID | Gap | 影响 requirement | 后续关闭条件 |
| --- | --- | --- | --- |
| PMPFLG-ST0-GAP-001 | `mbuf_cache_upd_l1pmpflg/l2pmpflg` 未接入 `mmu_dut_probes_if` 和 monitor。 | PDE-TP-016, PTW-ADD-041, PTW-ADD-045 | Stage 2 接 probe，`PTW_PDE_EVT` update 打印 L1/L2 update pmpflg。 |
| PMPFLG-ST0-GAP-002 | `twu_mbuf_pmpflg`、`mbuf_twu_pmpflg`、`mbuf_entry_pmpflg` 未接入 monitor。 | PDE-TP-016, PTW-ADD-041, PTW-ADD-045 | Stage 2/6 接 probe 或 bind，能证明 FST `{0,l1}`、SCD `{l2,l1}`、THD `0`。 |
| PMPFLG-ST0-GAP-003 | PDE direct accerr `vld/type/id/grant` 和 `L2PDE_entry_acc_err` 未接入 UVM probe。 | PDE-TP-014/015/017/019, PTW-FLOW-025/026, PTW-ADD-039/040/042/044 | Stage 2 接 monitor probe；Stage 6 增加 pending/type-id/valid-gate SVA。 |
| PMPFLG-ST0-GAP-004 | L1/L2 raw tag hit 没有 RTL 输出，当前 monitor 只能看到 permission-qualified hit/miss。 | PDE-TP-013/014/015/019, PTW-FLOW-024/025/026 | Stage 6 用 `bind L1PDE_cache/L2PDE_cache` 直接按 tag 重新计算；如需要 source debug，再在 Stage 2 加 raw-hit probe。 |
| PMPFLG-ST0-GAP-005 | cached pmpflg per entry 是 child instance internal，当前 monitor 不可见。 | PDE-TP-013..018, PTW-FLOW-024..028 | Stage 6 子模块 bind 直观测；或 Stage 2/5 通过 update payload + abstract model 做 source-side evidence。 |
| PMPFLG-ST0-GAP-006 | `pmp_regs_update` 在 `tb_top.sv` DUT instance 被 tie 为 `1'b0`，`pmp_regs_update_probe` 也为 `1'b0`。 | PDE-TP-010/016, PTW-ADD-045 | 后续阶段若要关闭 PMP config clear/repopulate，必须让 testbench 可驱动/可观测真实 `pmp_regs_update`。 |
| PMPFLG-ST0-GAP-007 | PDE direct accerr 与 TWU/MBUF access fault 的 root-cause priority 当前没有专用 monitor/SVA。 | PDE-TP-017, PTW-ADD-042 | Stage 6 扩展 `mmu_ptw_top_sva` 或新增 PTW accerr priority SVA，检查 `acc_err_twu_grant[5]`、type/id 和 pending clear。 |
| PMPFLG-ST0-GAP-008 | L1 tag-hit deny 进入 `fst_pmp` 需要 raw-tag evidence 与后续 level event 关联，当前没有单个 transaction 表达。 | PDE-TP-013, PTW-FLOW-024, PTW-ADD-037 | Stage 1/2 扩展 transaction/monitor；Stage 4/5 ref/SB 用 request key 关联 L1 deny miss 和后续 FST event。 |

### Stage 2 Gap Update

| Gap ID | Stage 2 状态 | 备注 |
| --- | --- | --- |
| PMPFLG-ST0-GAP-001 | closed for monitor probe | `pde_cache_update_l1pmpflg/l2pmpflg` 已接入 probe 和 `PTW_PDE_EVT` update。 |
| PMPFLG-ST0-GAP-002 | partially closed | `twu_mbuf_pmpflg`、`mbuf_twu_pmpflg`、`mbuf_entry_pmpflg` 已接入 probe；Stage 6 仍需 SVA/bind 证明 payload 编码和继承。 |
| PMPFLG-ST0-GAP-003 | partially closed | `pde_cache_acc_err_vld/type/id/grant` 和 `L2PDE_entry_acc_err` 已接入 probe/monitor；Stage 6 仍需 pending/type-id/valid-gate/priority SVA。 |
| PMPFLG-ST0-GAP-004 | partially closed | Stage 2 通过 `tb_top` 白盒层级 assign 生成 monitor raw tag hit vector；Stage 6 仍需 bind 做严格 assertion。 |
| PMPFLG-ST0-GAP-005 | partially closed | Stage 2 已将 child internal cached pmpflg vector 接到 monitor probe；Stage 6 仍需 bind assertion 覆盖 per-entry 语义。 |
| PMPFLG-ST0-GAP-006 | open | `pmp_regs_update` 仍为 testbench tie-off，本阶段未修改。 |
| PMPFLG-ST0-GAP-007 | open for SVA | Stage 2 只采样 `acc_err_twu_grant[5:0]` 和 direct accerr event；priority assertion 留到 Stage 6。 |
| PMPFLG-ST0-GAP-008 | partially closed | Stage 2 PDE event 可表达 L1 tag-hit deny miss；ref/SB 关联留到 Stage 4/5。 |

## 8. 阶段 1 到阶段 6 文件边界

| 阶段 | 文件边界 | 本阶段审计结论 |
| --- | --- | --- |
| 阶段 1 | `mmu_verification/testbench/env/ptw_source_types.svh`; optional `mmu_env_pkg.sv` | 需要新增 pde reason/access source enum、pmp allow helper、transaction pmpflg/direct-accerr fields。 |
| 阶段 2 | `mmu_dut_probes_if.sv`, `tb_top.sv`, `ptw_source_monitor.svh`, 本 probe map 文档 | 接入 Stage 0 表中 monitor-probe signals；monitor 输出 pmpflg update/direct accerr event。 |
| 阶段 3 | `ptw_pde_cache_model.svh`; optional `ptw_source_types.svh` helper | 现有 model 是 tag-only，必须保存 L1/L2 pmpflg 并返回 raw/qualified/deny/direct-accerr lookup detail。 |
| 阶段 4 | `ptw_source_ref_model.svh`; optional `ptw_pde_cache_model.svh`, `ptw_source_types.svh` | ref model 需根据 monitor event 和 model lookup 生成 L2 direct accerr expected。 |
| 阶段 5 | `ptw_source_sb.svh` | scoreboard/coverage 需要比较 `access_src/pde_reason/direct_accerr`，并检查 no-extra-LSU。 |
| 阶段 6 | `mmu_pde_cache_sva.sv`, `mmu_ptw_top_sva.sv`, optional new bind module for `L1PDE_cache/L2PDE_cache/twu/ptw_mbuf` | 需要补 permission-qualified hit、direct accerr、valid gate、priority、pmpflg propagation SVA/cover。 |

## 9. Stage 0 退出状态

| 退出标准 | 状态 |
| --- | --- |
| `ptw_pde_cache_pmpflg_stage0_probe_map.md` 已创建 | Done |
| 每个必需信号归类为 `monitor-probe`、`sva-bind` 或 `gap` | Done, 见第 4 节和第 7 节 |
| 每个 gap 列出影响的 `PDE-TP/PTW-ADD/PTW-FLOW` | Done |
| 阶段 1 到阶段 6 文件边界没有未知项 | Done, 见第 8 节 |
| 本阶段没有修改 UVM/RTL SystemVerilog 源码 | Done, 由 git diff/status 检查 |

## 10. 退出标准检查命令

PowerShell 环境建议使用：

```powershell
rg -n "L1PDE.*pmp|L2PDE.*pmp|PDE_cache_acc_err|mbuf.*pmpflg|twu_mbuf_pmpflg" mmu/rtl
rg -n "pde_cache|pmpflg|acc_err|L1PDE|L2PDE" mmu_verification/testbench/env mmu_verification/testbench/top
Test-Path doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md
git diff --name-only -- "*.sv" "*.svh"
```
