# MMU CreditSB 报错/警告原因分析（bug_may_problem）

> 日志片段：
>
> - `UVM_ERROR ... mmu_credit_sb.svh(247) ... credit_l1d overflow: 22 > L1_DTLB_ENTRIES=16`
> - `UVM_WARNING ... mmu_credit_sb.svh(257) ... lsu_ext_outstanding approx overflow: 22 > L1_DTLB_MB_DEPTH=8 (includes LSU-side sleeping requests)`

---

## 1. 现象解读

同一时刻出现：

1. `credit_l1d=22` 超过 `L1_DTLB_ENTRIES=16`（硬错误）
2. `lsu_ext_outstanding=22` 超过 `L1_DTLB_MB_DEPTH=8`（近似计数告警）

这说明 **LSU 请求发出速度远大于响应回收速度**，并且至少一部分请求在长期“未完成”状态。

---

## 2. 两个计数器的语义差异（必须先统一口径）

### `credit_l1d`

- 来源：`ap_pipe0_req/ap_pipe1_req` `+1`，`ap_pipe0_rsp/ap_pipe1_rsp` `-1`
- 语义：**外部可见的 LSU 未完成翻译请求数**
- 该计数 > 16，表示“在 TB 观测层面，未完成请求已经堆积超过 L1 DTLB entry 容量预期”

### `lsu_ext_outstanding`

- 同样由 req/rsp 近似计数，但文档已标注是 **approx**
- 会把 “LSU 侧休眠等待 wakeup、尚未真正进入 MMU miss buffer” 的请求也算进去
- 因此它超过 8 不一定是 DUT 内部 MB 真实溢出，属于辅助告警信号

---

## 3. 可能原因（按概率排序）

## 3.1 高概率：LSU 请求超时导致 req/rsp 不守恒（最主要）

### 机制链路

1. pipe0/pipe1 持续发请求（req 计数不断 +1）
2. 部分请求因 PTW/refill 未完成、或 wakeup 不到位，迟迟没有 `pa*_vld`
3. driver 4000-cycle timeout 后放弃该请求
4. 该请求在 scoreboard 视角上“只有 req 无 rsp”，导致 `credit_l1d` 单调上涨

### 与日志一致性

- 22 这种明显偏高值通常不是瞬时尖峰，而是多笔 timeout 积累结果
- 若后续又出现 `credit_l1d != 0 at end-of-sim`，可直接佐证该链路

---

## 3.2 高概率：MMU 翻译路径未真正打通（PTW 未有效回流）

常见子因：

- SFENCE/TLB invalidation 时序不对，TLB stale entry 残留
- L1 miss 后未触发有效 PTW 请求，或 PTW 请求发出但 responder/回填链路异常
- refill 未写回 L1 DTLB（导致持续 miss，随后 timeout）

结果表现为：

- 请求“卡死”而非正常出 rsp
- `credit_l1d` 与 `lsu_ext_outstanding` 同步升高

---

## 3.3 中概率：pipe0/pipe1 并发窗口过宽导致竞争与拥塞

即使已有 backpressure（`mmu_lsu_tlb_busy`）检查，若两路长期并发、且请求分布高度离散（几乎全 miss），仍可能出现：

- MB 很快占满
- 后续请求进入 LSU 侧休眠（等待 wakeup）
- rsp 回收速率显著低于 req 注入速率

这会优先触发 `lsu_ext_outstanding` 告警，并进一步推高 `credit_l1d`。

---

## 3.4 中概率：monitor/driver 在 timeout 场景下配对处理不一致

若 timeout 后：

- driver 已结束该事务；
- monitor 仍保留 pending 项（或反向误弹出）；

会引发配对偏移，进一步制造“虚假未完成”或错配 rsp，间接放大 `credit_l1d`。

---

## 3.5 次概率：scoreboard 模型口径与 DUT 内部资源定义不完全对齐

尤其 `lsu_ext_outstanding`：

- 其设计就是“外部近似量”，不是内部 MB 真值
- 在 wakeup/重发闭环不充分可观测时，出现大于 8 的告警是合理的

但这不能解释 `credit_l1d` ERROR（`>16`），只能解释 WARNING 的“可能偏大”。

---

## 4. 对当前两条信息的联合结论

仅看这两条日志可得：

1. `lsu_ext_outstanding` WARNING：**可能包含睡眠请求，告警本身不必然等于内部 MB 溢出**
2. `credit_l1d` ERROR：**存在真实的 req/rsp 不守恒风险（高概率由超时累积导致）**

也就是说，真正需要优先修复的是：

- 为什么多笔 LSU 请求最终没有形成 rsp 闭环；
- 而不是单纯调大 scoreboard 上限。

---

## 5. 建议排查顺序（实操）

1. 先统计同一轮日志中 `Pipe0/Pipe1 response timeout` 数量与时间分布
2. 对照 `credit_l1d` 增长曲线，确认“每次 timeout 后 credit 不回收”的对应关系
3. 检查 `mmu_lsu_data_req`、`lsu_mmu_data_vld`、`mmu_lsu_tlb_wakeup` 是否形成有效闭环
4. 检查 SFENCE 后首批 LSU 请求是否仍表现为异常快速“伪命中”
5. 最后再评估 `lsu_ext_outstanding` 阈值/告警级别是否需要按场景分级

---

## 6. 归档建议

在后续回归报告中建议将这类问题拆成两类统计：

- **A类（功能错误）**：`credit_l1d` 溢出/终态不归零（req/rsp 真不守恒）
- **B类（模型近似告警）**：`lsu_ext_outstanding > MB_DEPTH`（可能由睡眠请求引起）

这样可以避免把“模型近似噪声”与“真实功能堵塞”混为一谈。

