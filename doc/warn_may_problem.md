# IFU Warning 可能原因分析（warn_may_problem）

## 1. 告警内容

`UVM_WARNING ... ifu_monitor.svh(119) ... IFU pending req dropped on va_vld deassert: va=0x0000100000`

该告警含义是：  
`ifu_monitor` 已经记录了一个 pending IFU 请求（REQ 已观测到），但在收到配对的 `mmu_ifu_pavld` 之前，发现 `ifu_mmu_va_vld` 被拉低，因此将该 pending 请求丢弃。

---

## 2. 可能原因（按概率/常见度排序）

## 2.1 请求生命周期未闭环（最常见）

在该 VA 的请求窗口内：

- monitor 已捕获 REQ；
- 但没有捕获到对应 RSP（`mmu_ifu_pavld`）；
- 请求窗口结束（`va_vld` 下降），触发 dropped。

这通常是“请求有开始、无完成”的直接体现。

## 2.2 IFU 侧提前撤销请求

虽然 IFU 协议期望“拿到 PA 后再切下一个 VA”，但如果激励或时序中出现提前去使能（`va_vld` 拉低），monitor 会把未完成请求判定为 dropped。

## 2.3 hit 快路径/边界拍采样错位

若 `mmu_ifu_pavld` 出现在临界边沿，而 monitor 在该拍未成功识别，会出现“看起来没有 rsp，下一拍 `va_vld` 又拉低”的现象，从而触发 dropped。

## 2.4 miss 路径响应未及时返回（L2/PTW/refill链路延迟或阻塞）

当 ITLB miss 后走 L2TLB/PTW 路径，如果返回过慢或链路阻塞，可能导致请求在 monitor 视角内长时间无响应，最终随 `va_vld` 拉低被 dropped。

## 2.5 异常终止路径口径差异（abort/flush）

若存在 abort/flush 等终止场景，而 monitor 将该请求作为普通 pending 管理，但协议上不再返回 rsp，也会触发 dropped 告警。

---

## 3. 对验证结果的影响

- 该告警本身不一定代表 DUT 功能错误；
- 但它会导致 req/rsp 统计闭环被破坏，常与 `credit_l1i` 偏高或溢出同时出现；
- 若频繁出现，说明 IFU 请求建模、采样时序或请求终止语义仍需收敛。

---

## 4. 建议排查方向

1. 对告警 VA（如 `0x0000100000`）前后波形检查：`ifu_mmu_va_vld`、`ifu_mmu_va`、`mmu_ifu_pavld` 同拍关系。
2. 确认该请求是否属于 hit 快路径（是否存在同拍 rsp）。
3. 确认是否存在 abort/flush 或测试侧主动撤销请求。
4. 若为 miss 路径，检查 L2/PTW/refill 是否在合理周期内返回。
5. 统计 dropped 频次与 `credit_l1i` 曲线，判断是否已演化为系统性泄漏问题。
