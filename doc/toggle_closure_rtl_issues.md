# MMU RTL 问题单（Toggle 闭合过程中定位）— 提交设计确认

> 来源：`doc/toggle_closure_plan.md` §二-B / §六-B7 / §七.4#6
> 全部行号基于 `mmu/rtl/`，2026-07-26 复核有效。
> 分级：**P0 = 疑似功能缺陷**；**P1 = 死代码/未实现，需确认是否废弃**。

---

## B2（P0，本轮升级）`mmu_lsu_page_size_x` 恒为 4K，DTLB 条目真实 pgs 从未上送

**位置** `mmu_l1dtlb_hit_rd.sv:257 / 273 / 284 / 153`

```
257: assign dutlb_off_pgs[PGS_WIDTH-1:0] = 3'b0;                       // 4K default
273: assign dutlb_pre_pgs[PGS_WIDTH-1:0] = dutlb_off_pgs[PGS_WIDTH-1:0];
284: assign dutlb_fin_pgs[PGS_WIDTH-1:0] = dutlb_pre_sel ? dutlb_pre_pgs[PGS_WIDTH-1:0]
                                                        : 3'b001;
153: assign mmu_lsu_page_size_x[PGS_WIDTH-1:0] = dutlb_fin_pgs[PGS_WIDTH-1:0];
```

**分析**
- `dutlb_pre_sel == 1` 分支取 `dutlb_pre_pgs`，而它经 273 → 257 恒为 `3'b000`。
- `dutlb_pre_sel == 0`（**普通 DTLB 条目命中**）分支直接写死 `3'b001`。
- 结论：`mmu_lsu_page_size_x` 的取值域只有 `{3'b000, 3'b001}`，**永远不会输出
  2M(`3'b010`) / 1G(`3'b100`)**；命中条目里保存的 `dutlb_entry_pgs` 在整个 hit_rd
  中**没有任何 fan-out 到该输出**（`grep dutlb_entry_pgs` 在本文件仅出现于声明）。
- 注意条目内的 `pgs` 本身是**有效**的——它参与 VPN 比较掩码，只是输出端口断了。

**影响** 若 LSU 用 page size 做跨页判断、非对齐拆分、store merge 或 PMA 粒度选择，
则 2M/1G 命中时会拿到 4K，属**功能错误**。若 LSU 实际不用该端口，则应删除端口
并同步接口文档。

**请设计确认** ①LSU 是否消费 `mmu_lsu_page_size_x`？②若消费，是否应改为
`dutlb_fin_pgs = dutlb_pre_sel ? dutlb_pre_pgs : dutlb_entry_pgs`？

**覆盖率副作用** 该信号的 2M/1G 编码 toggle 不可达；`dutlb_off_pgs`/`dutlb_pre_pgs`
已在 `simu/fullexclude.tgl` 豁免（见该文件第 2 组）。

---

## B7（P0）iUTLB 命中路径 U 位 S 态检查未生效

**位置** `mmu_l1itlb.sv`（详见 `doc/toggle_closure_plan.md` §六-B7 原始记录）

S 态取指命中一条 `U=1` 的 iUTLB 条目时未产生 page fault（`SUM` 对取指无效，
按 RISC-V 规范应无条件 fault）。T-A 用例需规避该行为才能通过。

**请设计确认** 是否为已知偏差（例如依赖 IFU 侧另做检查）？

---

## B5（P1→P0 待定）`expt_wr1_acflt = 1'b0`：JTLB 路径 access-fault 信息被丢弃

**位置** `mmu_l1dtlb.sv:323`

`expt_cam` 的 wr1（JTLB/页故障写口）恒写入 `acflt=0`。若 L2/JTLB 侧确实可能返回
access fault（PMP deny / 总线错误），则该信息在 wr1 路径上丢失，异常类型会被
错报为 page fault。

**请设计确认** JTLB 返回路径是否结构上不可能带 access fault？若是，`wr1_acflt`
端口应删除。

**覆盖率副作用** 已在 `simu/fullexclude.tgl` 豁免（第 4 组）。

---

## B6（P1）`mmu_lsu_stall_x = 1'b0`：MB 满时对 LSU 无背压

**位置** `mmu_l1dtlb_hit_rd.sv:151`

MB（8 slot）满时不向 LSU 回压。需确认上游是靠 credit 机制（`mmu_lsu_*_credit`）
完全约束，还是该端口是遗留未实现。

---

## B1（P1）顶层观测口 TODO stub

**位置** `mmu_l1dtlb.sv:1304-1306`

```
assign dutlb_top_ref_cur_st = 3'b0;  // TODO
assign dutlb_top_ref_type   = 1'b0;  // TODO
assign dutlb_top_scd_updt   = 1'b0;  // TODO
```

三个顶层状态观测口无信息。确认是废弃还是待实现；若废弃请删除端口。

---

## B3（P1）`issue_req / issue_vpn / issue_eid` 死代码

**位置** `mmu_l1dtlb.sv:257-259, 1063-1066` — 建议清理。

---

## B4（P1）`iutlb_bypass_vld = 1'b0` stub

**位置** `mmu_l1itlb.sv:507-508`（另见 `2224` 行被注释掉的 `iutlb_bypass_flg`）

refill bypass 通路未实现。确认是废弃还是待实现。

---

## 附：本轮新增的两条 RTL 结构性结论（非缺陷，供设计/验证共识）

### N1 `expt_wr0_eid == ptw_l1dtlb_ref_id` —— expt-CAM 条目号就是 MB slot 号
`mmu_l1dtlb.sv:309`。因此"写到 expt_cam 第 N 条"不是独立可控维度，必须先让
N 个 MB slot 处于占用态。验证侧影响：定向填 ent[4..7] 必须配合 `prefill_mb()`，
且**不能**再叠加 `force_ptw_bus_error_by_count()`（两个条件的竞争会大概率失败，
实测 8 次中 6 次超时）。已在 `mmu_l1dtlb_toggle_expt_cam_full_vseq` 注释中固化。

### N2 L2→L1 refill 通路**不做权限检查**
`mmu_l2tlb.sv:1013` `final_pa_vld = final_tlb_hit & final_vld`；
`mmu_l2tlb.sv:1178` `l2tlb_l1itlb_ref_pavld = final_pa_vld & (acc_type==3'b011)`。
即 L2 命中即回填 L1，**没有任何 page-fault 项**。

后果：一条由 **load** 装入 L2 的 `X=0` 表项，会在下一次**取指** miss 时被原样
回填进 L1 ITLB（随后 L1 命中检查才报 instruction page fault）。这是
`ct_mmu_iutlb_entry.utlb_flg[3]` 能出现 `1→0` 的**唯一**功能通路，已被
`test_mmu_l1itlb_cov_toggle_flg_clear_001` 利用。

设计确认点：这是有意的（把权限检查统一收敛到 L1 hit_rd）还是应在 refill 端提前拦截？
若有意，请在设计文档中显式说明——否则容易被误读为安全问题
（非可执行页被写入 I-TLB）。
