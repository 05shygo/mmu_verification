# IFU Request Model

## 1. IFU 侧请求发起与保持规则

IFU 到 MMU 的请求遵循“保持型握手”模型，关键行为如下：

1. `ifu_mmu_va_vld` 在请求阶段会持续为高，不是单拍脉冲。
2. 在 MMU 返回该请求对应的 PA 之前，`ifu_mmu_va` 保持稳定不变。
3. 只有当 MMU 已返回当前请求的 PA 后，`ifu_mmu_va` 才会更新为下一个 VA（进入下一次请求）。

这意味着：同一个未完成请求期间，MMU 看到的是“`va_vld=1` 且 VA 恒定”的输入条件。

---

## 2. MMU 侧两种处理路径

## 2.1 路径一：ITLB Hit（快速返回）

当当前 `ifu_mmu_va` 在 MMU 的 ITLB 中命中时：

- MMU 可直接命中得到翻译结果；
- 随后将 PA 返回给 IFU；
- IFU 收到 PA 后，才推进到下一个 VA 请求。

该路径不需要等待 L2TLB/PTW。

## 2.2 路径二：ITLB Miss（经 L2TLB/PTW 后返回）

当当前 `ifu_mmu_va` 在 ITLB 未命中时：

1. MMU 继续向下级翻译资源查询（L2TLB，必要时进一步到 PTW）。
2. 当下级拿到 VA->PA 关系后，MMU 会执行 refill，将翻译信息写回 ITLB。
3. 由于 IFU 在此期间保持 `ifu_mmu_va_vld=1` 且 `ifu_mmu_va` 不变，请求仍是同一个 VA。
4. refill 完成后，该 VA 将在 ITLB 命中，从而触发 PA 返回给 IFU。
5. IFU 收到 PA 后，再切换到下一个 VA。

---

## 3. 模型要点（验证视角）

- IFU 是“请求保持直到响应”的模式，而不是“请求单拍发射”模式。
- 对同一个 VA，MMU 可能经历“先 miss，再 refill，后 hit 返回”的过程。
- 在响应到达前，`ifu_mmu_va` 不应变化；若变化，属于协议违规或激励异常。
- 监控/评分时应按“一个稳定 VA 对应一个最终 PA 响应”建模，避免把同一请求误判为多个请求。

---

## 4. 一句话总结

IFU 通过持续拉高 `ifu_mmu_va_vld` 并保持 `ifu_mmu_va` 稳定，确保当前请求在 MMU 内部无论走 ITLB hit 还是 miss->L2/PTW->refill->hit 路径，最终都能对同一 VA 返回对应 PA，然后再进入下一请求。
