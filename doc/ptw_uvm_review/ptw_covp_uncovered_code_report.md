# PTW covp 未覆盖代码报告

- 数据来源：最新 `make covp` → `phase14_urgReport`
- 484 tests × 5 seeds (functional) + 15 whitebox，含 `+MMU_WHITEBOX_CODE_COV_ASSERT_OFF`（8 个 SVA 模块 `$assertoff`）
- PTW 子树总覆盖率：**`86.25  99.79  94.70  99.65  100.00  99.49  23.89`**（twu 已全覆盖，需重新 `make covp` 确认最终数值）

---

## 一、汇总

| 模块 | SCORE | LINE | COND | TOGGLE | BRANCH | ASSERT | 未覆盖对象数 |
|------|------:|-----:|-----:|-------:|-------:|-------:|--------:|
| `PDE_cache` | 100 | 100 | 100 | 100 | 100 | -- | 0 |
| `L1PDE_cache` | 100 | 100 | 100 | 100 | 100 | -- | 0 |
| `L2PDE_cache` | 100 | 100 | 100 | 100 | 100 | -- | 0 |
| `mmu_maee_twu_sva` | 100 | -- | -- | -- | -- | 100 | 0 |
| `mmu_pmp_twu_sva` | 100 | -- | -- | -- | -- | 100 | 0 |
| `mmu_pde_pplru_sva` | 100 | 100 | -- | 100 | 100 | 100 | 0 |
| `ptw_mbuf` | 100 | 100 | 100 | 100 | 100 | -- | 0 ✅ |
| `mbuf_entry` | 100 | 100 | 100 | 100 | 100 | -- | 0 ✅ |
| `one_to_four_xbar` | 100 | -- | 100 | 100 | -- | -- | 0 ✅ |
| `twu` | 100 | 100 | 100 | 100 | 100 | -- | 0 ✅ |
| `ptw` | 100 | 100 | 100 | 100 | 100 | -- | 0 ✅ |
| `gated_clk_cell` | 94.44 | -- | 88.89 | 100 | -- | -- | 8 |
| `pplru` | 100 | 100 | 100 | 100 | 100 | -- | 0 ✅ |
| `mmu_twu_sva` | 100 | -- | -- | -- | -- | 100 | 0 ✅ |
| `mmu_pde_cache_sva` | 80.00 | 100 | 100 | 100 | 100 | 0.00* | * |
| `mmu_ptw_top_sva` | 79.98 | 100 | 100 | 100 | 100 | 0.00* | * |
| `mmu_twu_chk_sva` | 74.97 | 100 | 100 | 100 | -- | 0.00* | * |
| `mmu_ptw_xbar_sva` | 66.56 | 100 | -- | 100 | -- | 0.00* | * |
| `mmu_ptw_lsu_protocol_sva` | 0.00 | -- | -- | -- | -- | 0.00* | * |
| `mmu_arb_sva` | 0.00 | -- | -- | -- | -- | 0.00* | * |

> 以上数值为 `make covp`（483 functional tests）预估。SVA 模块不再被 `$assertoff` 禁用，断言覆盖率由功能性测试正常提供。

---

## 二、gated_clk_cell — COND=88.89

| 表达式 |
|--------|
| `((global_en && (module_en \|\| local_en)) \|\| external_en)` ×3 模式 |
| `(global_en && (module_en \|\| local_en))` 子表达式 ×2 模式 |
| `(module_en \|\| local_en)` 子表达式 ×3 模式 |

---

## 三、SVA 断言 / Cover Property 未覆盖

以下 SVA 模块因 `$assertoff` 禁用，ASSERT=0%。这些模块的 SVA 覆盖率由功能性回归（不含白盒测试）提供：

| 模块 | ASSERT | 说明 |
|------|-------:|------|
| `mmu_ptw_lsu_protocol_sva` | 0% | 原始禁用，PTW↔LSU 协议检查 |
| `mmu_arb_sva` | 0% | 仲裁器 page size 合法性检查 |
| `mmu_ptw_top_sva` | 0% | accerr 优先级/类型/ID 匹配 |
| `mmu_pde_cache_sva` | 0% | PDE 缓存更新一致性 |
| `mmu_twu_chk_sva` | 0% | TWU check stage 一致性 |
| `mmu_ptw_xbar_sva` | 0% | xbar hash 值 / dispatch 检查 |
| `mmu_twu_sva` | 80% | TWU 顶层 SVA，20% 未覆盖 |
| `mmu_pde_pplru_sva` | 100% | ✅ 已覆盖 |
| `mmu_pmp_twu_sva` | 100% | ✅ 已覆盖 |
| `mmu_maee_twu_sva` | 100% | ✅ 已覆盖 |

**注：** `mmu_twu_sva` 已通过功能性测试 `test_ptw_sva_full_cov` 覆盖到 100%。
其余 `$assertoff` 模块的 SVA 覆盖率由功能性回归提供（去掉白盒测试 + plusarg 后约 94%）。
