# MMU Phase 5 仿真错误分析报告

> **仿真命令**：`make fast TEST_NAME=test_mmu_translation_sanity`
> **日志文件**：`log/run_sanity_debug_new1.txt`
> **分析日期**：2026-04-25
> **状态**：Phase 5 退出准则验证 — 第五轮（P5-1/3/4/5/6/8/9 源码修复已编译）

---

## 仿真结果总览

| 指标 | 值 | 预期 | 状态 |
|------|------|------|------|
| Translation SB total_checked | **175** | ≥ 200 | FAIL |
| Translation SB mismatch | **159** | 0 | FAIL |
| credit_l1i (仿真结束) | 0 | 0 | PASS |
| credit_l1d (仿真结束) | **61** (peak=62) | 0 | FAIL — 泄漏 |
| l2_reqq_cnt (仿真结束) | **61** (peak=62) | 0 | FAIL — 未排空 |
| ptw_mbuf_cnt (仿真结束) | 0 | 0 | PASS |
| IFU req 发出 | 100 | 100 | OK |
| LSU0 req 被 monitor 捕获 | **47** | 100 | FAIL — 53 笔超时 |
| LSU1 req 被 monitor 捕获 | **12** | 20 | FAIL — 8 笔超时 |
| ref_model 调用次数 | 159 | ≥ 200 | 低于预期 |
| HPCP dutlb_miss | 216771 | — | 异常偏高 |
| 仿真时间 | 501288 ns | — | — |

---

## 错误分类

本轮仿真错误可归纳为 **三大独立根因**，它们相互叠加后产生了 159 笔 mismatch + 大量 credit 溢出 + 事务不足等衍生错误。

---

### 问题 1：IFU 全量 PA=0（100 笔 IFU 翻译全部失败）

**现象**

- 全部 100 笔 IFU 取指翻译：ref_model 正确翻译（`ref.ppn=0x200~0x263`），但 DUT 输出 `dut.pa=0x0000000`。
- 每笔 IFU 翻译仅耗时 **7ns（7 个时钟周期）**，说明 DUT 立即返回 `mmu_ifu_pavld=1`（组合逻辑级响应），未经过 PTW 页表遍历。
- 无任何 IFU response timeout 警告（即 driver 的 fork/join_any 在 wait_rsp 分支命中，非 timeout 分支）。
- IFU credit_l1i = 0（正常守恒），说明 IFU 请求/响应配对正确，只是 PA 值本身为 0。

**证据**

```
@ 594000:  [IFU] VA=0x0000100000: PA mismatch — ref.ppn=0x0000200  dut.pa=0x0000000
@ 601000:  [IFU] VA=0x0000101000: PA mismatch — ref.ppn=0x0000201  dut.pa=0x0000000
@ 608000:  [IFU] VA=0x0000102000: PA mismatch — ref.ppn=0x0000202  dut.pa=0x0000000
  ... (100 笔，PA 全为 0)
```

**猜测根因**

P5-9 修复（IFU driver 从单周期脉冲改为 hold-until-pavld）已编译到本次仿真二进制中。Driver 确实保持 `va_vld=1` 直到 `pavld=1`，但 DUT **在 7 个周期内就返回 `pavld=1` 且 PA=0**。可能的深层原因：

| # | 猜测 | 分析 |
|---|------|------|
| 1a | **L1 ITLB 命中了无效/残留条目（PPN=0）** | SFENCE（Step 0 + Step 2b）后 ITLB 应被清空，但若 RTL 的 ITLB valid 位未被正确清除，或 hit 逻辑未门控 valid 位，则空条目（PPN=0）被当作 hit，pavld 立即拉高，PA=0 |
| 1b | **IFU 响应路径存在旁路/默认返回** | RTL 中 `mmu_ifu_pavld` 可能不仅由 `iutlb_hit_vld` 驱动，还有其他组合逻辑路径（如 M-mode 直通、mmu_en=0 旁路）。若 IFU 通道的 `mmu_en` 判断有误，可能走了一条返回 PA=0 的旁路 |
| 1c | **PTW responder 未响应 IFU 发起的页表遍历请求** | 若 IFU 通道的 L1 ITLB miss → L2 miss → PTW walk 请求从未被 ptw_mem_responder 正确服务（例如 IFU/LSU 共享的 PTW 入口竞争、或 IFU miss 请求被 LSU 请求挤占），则 ITLB 永远不会被填充，每次访问都"命中"初始值 PPN=0 |
| 1d | **IFU PA 输出多路选择器 Bug** | `mmu_ifu_pa` 的来源可能有多个（ITLB hit、PTW direct refill、bypass 等），若 MUX 选择信号不正确，即使 ITLB 已被正确填充，PA 输出仍为 0 |
| 1e | **monitor 采样时序问题** | `driver_cb` 的 input sampling 可能在组合逻辑稳定之前读取 PA，导致采样到全 0 |

**建议排查步骤**

1. 在仿真中 `$display` 或波形中查看 ITLB 内部的 `entry_vld[]`、`entry_vpn[]`、`entry_ppn[]`，确认 SFENCE 后条目是否被清空
2. 确认 `mmu_ifu_pavld` 的驱动逻辑：是否仅来自 `iutlb_hit_vld`，还是有旁路路径
3. 检查 IFU 通道的 `mmu_en` 信号：`mmu_xx_mmu_en` 对 IFU 是否生效，还是 IFU 有独立的使能判断
4. 波形确认第一笔 IFU 请求（@594ns）时 `ifu_mmu_va_vld`、`mmu_ifu_pavld`、`mmu_ifu_pa` 三者的时序关系

---

### 问题 2：LSU PA = VPN（Bare Mode 直通行为，翻译未生效）

**现象**

- 前几笔 LSU Pipe0/Pipe1 响应立即返回，PA 值 = VA >> 12（VPN），这是经典的 **Bare/直通模式** 行为。
- 例如：VA=0x100000 → ref.ppn=0x200, dut.pa=0x**100**（= 0x100000 >> 12 = VPN）
- 后续 LSU 交易中，PA 偏移逐渐增大（因 monitor FIFO 关联错乱导致配对偏移），不再是简单的 VPN=PPN。

**证据**

```
@ 1298000:  [LSU_P1] VA=0x0000100000: PA mismatch — ref.ppn=0x0000200  dut.pa=0x0000100
@ 1305000:  [LSU_P0] VA=0x0000100000: PA mismatch — ref.ppn=0x0000200  dut.pa=0x0000100
@ 1305000:  [LSU_P1] VA=0x0000101000: PA mismatch — ref.ppn=0x0000201  dut.pa=0x0000101
@ 1324000:  [LSU_P0] VA=0x0000101000: PA mismatch — ref.ppn=0x0000201  dut.pa=0x0000101
```

**猜测根因**

| # | 猜测 | 分析 |
|---|------|------|
| 2a | **SATP 写入未生效 / mmu_lsu_mmu_en=0** | `mmu_xx_mmu_en = (satp_mode==4'h8) && (priv_mode != 2'b11)`。若 SATP 写入由于时序竞争未被 RTL 正确锁存（P3-8/P3-10 经验），mmu_en 仍为 0，DUT 走 Bare 模式直通 VA→PA |
| 2b | **Step 2b 的 SFENCE 执行异常** | `tlb_inv_all_seq` 的 `c_kind_default.constraint_mode(0)` 修复（P5-8）已编译。但 SFENCE 发到 LSU INV 子线程后，若 RTL 的 TLB invalidation FSM 未正确完成（超时退出），L2 JTLB 可能保留了初始值条目（PPN=VPN 的映射残留），导致 LSU 查询直接命中 L2 的错误条目 |
| 2c | **L1 DTLB 初始条目干扰** | 若 SFENCE 后 L1 DTLB 的 entry_vld 未被正确清零，且条目的 PPN 恰好等于 VPN（未初始化的硬件寄存器默认值），则 L1 hit 直接返回 VPN 作为 PPN |
| 2d | **Pipe0/Pipe1 并发导致 L1 hit 判断异常** | 100 笔 pipe0 + 20 笔 pipe1 同时驱动（因 `_fetch_items()` 立即 item_done），两路并发的 va_vld 可能干扰 L1 DTLB 的 hit 判断逻辑 |

**关键线索**

- IFU 返回 PA=0（非 VPN），LSU 返回 PA=VPN —— 两条路径的异常模式不同，暗示 IFU 和 LSU 各有独立的问题根因
- 早期 LSU 响应极快（~10ns），未经过 PTW → 说明 L1/L2 TLB 有"命中"（但 PPN 错误）

**建议排查步骤**

1. **优先级最高**：波形确认 `mmu_lsu_mmu_en` 和 `mmu_xx_mmu_en` 在 Step 4 开始时（@594ns）是否为 1
2. 确认 SATP readback（test 中有 debug probe，完整日志中应有 `DEBUG SATP readback` 打印）
3. 波形确认 Step 2b SFENCE 执行后 `lsu_mmu_tlb_all_inv` 是否正确拉高、DUT 是否响应 `mmu_lsu_tlb_inv_done`
4. 对比 `mmu_lsu_pa0[27:0]` 与 `lsu_mmu_va0[38:12]`，确认是否真正是 PA=VPN

---

### 问题 3：LSU Pipe0/Pipe1 超时级联（61 笔泄漏 → credit 溢出 → FIFO 关联错乱）

**现象**

- 从 @5310ns 开始，Pipe1 出现第一次 timeout（VA=0x102000, 4000 cycle 超时）
- 随后 Pipe0 和 Pipe1 交替超时，每 4000~4006 ns 一次
- credit_l1d 从 0 单调递增至 61，l2_reqq_cnt 同步增长
- 仅 47/100 笔 pipe0 + 12/20 笔 pipe1 成功完成（共 59 笔），61 笔永久超时
- 后期 PA mismatch 呈现随机偏移模式（ref.ppn=0x207 vs dut.pa=0x10c），因 monitor FIFO 请求-响应配对错位

**证据**

```
@ 5310000:  Pipe1 response timeout: va=0x102000 id=60
@ 9349000:  Pipe0 response timeout: va=0x105000 id=76
@ 17359000: l2_reqq_cnt overflow: 9 > L1_DTLB_MB_DEPTH=8
  ...
@ 501288000: credit_l1d=61 (peak=62), l2_reqq_cnt=61 (peak=62)
```

**猜测根因**

| # | 猜测 | 分析 |
|---|------|------|
| 3a | **PTW 遍历未正常完成** | 若问题 2 中的根因成立（mmu_en=0 或 TLB 有残留），则 L1 miss → L2 miss → PTW walk 路径可能异常。PTW 遍历在 mmu_en=0 时可能不触发，或遍历错误地址的页表，导致 miss buffer 项永远等不到 refill 唤醒 |
| 3b | **Miss buffer 饱和后新请求被静默丢弃** | P5-5 修复在发送前检查 `tlb_busy`（MB 全满标志），但 `tlb_busy=0` 只表示"至少有一个空闲 MB 槽"。若 PTW 遍历极慢（3 级页表 × 多笔响应延迟），8 个 MB 槽很快被占满，新请求在 hold 期间等待 `tlb_busy=0` 但 busy 长期不释放（因旧的 MB 项未完成） |
| 3c | **Pipe0/Pipe1 并发争抢 MB 资源** | 100 笔 pipe0 + 20 笔 pipe1 的 unique page 请求同时驱动，每笔都是 L1 miss → 需要 MB 槽。8 个 MB 槽被快速耗尽后，后续请求必须等待前序请求的 PTW 完成。若前序 PTW 因问题 2/3a 未能完成，则形成死锁级联 |
| 3d | **Pipe0/Pipe1 超时后 monitor FIFO 关联错乱** | 当 driver 因 timeout 放弃一笔请求时，monitor 的 `m_pending_p0/p1[$]` 队列中该请求的 req 条目不会被 pop（因为没有对应的 rsp）。后续真正的 rsp 被配对到错误的 req → PA mismatch 衍生错误 |

**关键线索**

- `dutlb_miss=216771` 异常偏高（500000 cycle 中有 216771 次 DTLB miss 事件），说明 L1 DTLB 一直在 miss，refill 从未成功
- `ptw_mbuf_cnt=0` 提示 PTW miss buffer 没有泄漏 —— 但这可能因为 PTW 请求本身就没有被正确发出

**建议排查步骤**

1. 波形确认 PTW 是否发出内存请求（`mmu_lsu_data_req`）
2. 确认 `ptw_mem_responder` 是否正确收到并回复了 PTW 请求
3. 检查 miss buffer `mb_entry_vld[7:0]` 的波形：是否有条目长期卡在 valid 状态
4. 确认 L2 JTLB refill 路径（PTW 完成 → L2 写入 → L1 refill → `pa_vld`）的完整性

---

## 错误因果关系图

```
问题 1: IFU PA=0                       问题 2: LSU PA=VPN
(ITLB 命中无效条目 / IFU 旁路)        (Bare mode / SATP 未生效)
       │                                      │
       └──→ 100 笔 IFU mismatch              └──→ 早期 LSU mismatch
                                               │
                                               ├──→ 问题 3: PTW 未正常完成
                                               │         │
                                               │         ├──→ MB 永久卡死
                                               │         │         │
                                               │         │         ├──→ Pipe0/Pipe1 超时 (61 笔)
                                               │         │         │         │
                                               │         │         │         ├──→ credit 溢出
                                               │         │         │         │
                                               │         │         │         └──→ monitor FIFO 错位
                                               │         │         │                   │
                                               │         │         │                   └──→ 衍生 PA mismatch
                                               │         │         │
                                               │         │         └──→ total_checked < 200
                                               │         │
                                               │         └──→ HPCP dutlb_miss=216771
```

---

## 核心疑问 & 下一步行动

| # | 疑问 | 排查方式 | 优先级 |
|---|------|---------|--------|
| Q1 | `mmu_xx_mmu_en` 和 `mmu_lsu_mmu_en` 在 Step 4 开始时是否为 1？ | 查看完整日志中 `DEBUG MMU STATE` 打印 + 波形 | **P0** |
| Q2 | `mmu_cp0_satp_data` readback 值是否为 `0x8000000000000000`（Sv39, PPN=0, ASID=0）？ | 查看完整日志中 `DEBUG SATP readback` 打印 | **P0** |
| Q3 | SFENCE（Step 2b）是否成功执行？`lsu_mmu_tlb_all_inv` 是否拉高？`mmu_lsu_tlb_inv_done` 是否返回？ | 波形 | **P0** |
| Q4 | 第一笔 IFU 请求（@594ns）时 ITLB 内部 entry_vld 状态？ | 波形 / `$display` | P1 |
| Q5 | PTW 是否发出过内存请求（`mmu_lsu_data_req`）？responder 是否收到并回复？ | 波形 + responder 日志 | P1 |
| Q6 | L1 DTLB miss buffer 条目何时被分配、是否被释放？ | 波形 `mb_entry_vld[]` | P1 |
| Q7 | IFU 的 `mmu_ifu_pavld` 组合逻辑来源？是否有非 ITLB-hit 的旁路路径？ | RTL 代码审查 | P2 |

---

## 与已修复 Bug 的关系

| 已修复 Bug | 本轮是否生效 | 判断依据 |
|-----------|------------|---------|
| P5-1 (IFU VA>>1 编码) | ✅ 已生效 | ifu_driver.svh line 67: `tr.va >> 1` 存在 |
| P5-3 (LSU vabuf 约束) | ✅ 已生效 | lsu_mapped_va_seq: `vabuf == 28'(...)` 约束存在 |
| P5-4 (settle 等待延长) | ✅ 已生效 | test: `#500000ns` 存在 |
| P5-5 (LSU tlb_busy 背压) | ✅ 已生效 | lsu_driver.svh: `iff mmu_lsu_tlb_busy === 1'b0` 存在 |
| P5-6 (credit_sb 边界修正) | ✅ 已生效 | credit_sb: `L1_DTLB_MB_DEPTH=8` 正确 |
| P5-8 (lsu_sequences 约束冲突) | ✅ 已生效 | tlb_inv_all_seq: `c_kind_default.constraint_mode(0)` 存在 |
| P5-9 (IFU hold-until-pavld) | ✅ 已生效 | ifu_driver.svh: fork/join_any 等待 pavld 存在 |

> **结论**：所有已知修复均已编译生效。本轮错误来自 **新的、尚未发现的根因**。

---

## 总结

本轮仿真暴露了 Phase 5 中 **至少两个新的独立根因**（IFU PA=0 和 LSU 翻译未生效），它们与之前发现并修复的 P5-1~P5-9 Bug 不同。最高优先级是确认 **Q1/Q2/Q3**（MMU 是否真正使能、SATP 是否写入成功、SFENCE 是否执行成功），因为如果 `mmu_en=0`，则所有翻译相关错误都是该根因的直接衍生。建议先从完整日志中提取 `DEBUG MMU STATE` 和 `DEBUG SATP readback` 信息，或重新仿真加 `+UVM_VERBOSITY=UVM_MEDIUM` 以获取更多调试输出。
