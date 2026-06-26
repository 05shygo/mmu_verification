# PTW Code Coverage Report — make covp (Phase14)

**Date**: 2026-06-26
**Source**: `make covp` full regression, 483 tests × 5 seeds = 2415 runs
**URG Report**: `output/coverage/phase14_urgReport`

---

## Overall PTW Score

| Module | SCORE | LINE | COND | TOGGLE | FSM | BRANCH | ASSERT |
|--------|-------|------|------|--------|-----|--------|--------|
| `x_ct_mmu_ptw` (ptw top) | **90.69** | 99.19 | 81.79 | 71.53 | 100.00 | 98.32 | 93.30 |

---

## Sub-Module Coverage

### 1. twu (Table Walk Unit)

| Instance | SCORE | LINE | COND | TOGGLE | FSM | BRANCH |
|----------|-------|------|------|--------|-----|--------|
| `twu_one` | **96.96** | 99.42 | 92.42 | 94.05 | 100.00 | 98.89 |
| `x_twu_gateclk` | 47.22 | — | 44.44 | 50.00 | — | — |

- LINE: 99.42% — near complete
- COND: 92.42% — ~7.5% uncovered (FSM transition guards)
- TOGGLE: 94.05% — ~6% uncovered
- FSM: 100.00% — complete
- BRANCH: 98.89% — ~1% uncovered

### 2. ptw_mbuf (PTW Miss Buffer)

| Instance | SCORE | LINE | COND | TOGGLE | BRANCH | ASSERT |
|----------|-------|------|------|--------|--------|--------|
| `u_ptw_mbuf` (top) | **86.46** | 98.35 | 72.10 | 72.06 | 97.05 | 92.73 |
| `mbuf_entry[0..8]` ×9 | ~86.1 | ~98.0 | ~72.6 | ~76.3 | ~96.67 | — |
| `u_ptw_lsu_protocol_sva` | 92.73 | — | — | — | — | 92.73 |

- LINE: 98.35%
- COND: 72.10% — **~28% uncovered** (priority/arbitration expressions)
- TOGGLE: 72.06% — **~28% uncovered** (entry state bits, grant signals)
- BRANCH: 97.05%
- ASSERT: 92.73%

### 3. PDE_cache (PDE Cache)

| Instance | SCORE | LINE | COND | TOGGLE | BRANCH | ASSERT |
|----------|-------|------|------|--------|--------|--------|
| `u_PDE_cache` (top) | **87.22** | 99.68 | 82.68 | 60.56 | 99.15 | 94.02 |
| `u_pde_cache_sva` | 85.83 | 100.00 | 87.50 | 46.92 | 100.00 | 94.74 |

- LINE: 99.68%
- COND: 82.68% — **~17% uncovered**
- TOGGLE: 60.56% — **~39% uncovered** (largest gap)
- BRANCH: 99.15%
- ASSERT: 94.02%

#### 3a. L1 PDE Entries (8×)

All entries have identical LINE=100%, COND=88.64%, BRANCH=100%.
TOGGLE varies by entry:

| Entry | TOGGLE | Entry | TOGGLE |
|-------|--------|-------|--------|
| ent[0] | 72.26 | ent[4] | 58.23 |
| ent[1] | 57.62 | ent[5] | 57.93 |
| ent[2] | 59.76 | ent[6] | 57.62 |
| ent[3] | 60.06 | ent[7] | 58.84 |

- COND: uniform 88.64% — same logic 8×, ~11% uncovered
- TOGGLE: 57–72% — entry[0] best (most frequently used); ~40% gap on others

#### 3b. L2 PDE Entries (16×)

All entries have LINE=100%, BRANCH=100%.
COND: 77.61–85.07% (entry[0] best at 85.07%, entry[11-13] lowest at 77.61%)
TOGGLE: 66.11–78.12% (entry[0] best at 78.12%)

### 4. pplru (PDE PLRU — Replacement Logic)

| Instance | SCORE | LINE | COND | TOGGLE | BRANCH | ASSERT |
|----------|-------|------|------|--------|--------|--------|
| `u_L1PDE_cache_pplru` (8-entry) | **87.95** | 96.49 | 80.00 | 95.73 | 85.71 | 81.82 |
| `u_L2PDE_cache_pplru` (16-entry) | **91.26** | 98.25 | 80.00 | 92.36 | 85.71 | 100.00 |
| L1 SVA | 94.45 | 100.00 | — | 96.00 | 100.00 | 81.82 |
| L2 SVA | 97.67 | 100.00 | — | 90.70 | 100.00 | 100.00 |

- COND: 80.00% — **20% uncovered** (PLRU hit/miss/victim logic)
- BRANCH: 85.71% — **~14% uncovered**
- ASSERT: L1 SVA 81.82%, L2 SVA 100%

### 5. one_to_four_xbar (1:4 Crossbar)

| Instance | SCORE | LINE | COND | TOGGLE | ASSERT |
|----------|-------|------|------|--------|--------|
| `u_one_to_four_xbar` | **92.26** | 100.00 | 100.00 | 74.92 | 94.12 |
| `u_ptw_xbar_sva` | 88.72 | 100.00 | — | 72.05 | 94.12 |

- LINE: 100%, COND: 100% — complete
- TOGGLE: 74.92% — **~25% uncovered**

### 6. ptw_mem_if (PTW Memory Interface)

| Instance | SCORE | COND | TOGGLE |
|----------|-------|------|--------|
| `ptw_mem_if_inst` | 89.05 | 100.00 | 78.10 |

### 7. PTW SVA Modules

| Module | SCORE | LINE | COND | TOGGLE | BRANCH | ASSERT |
|--------|-------|------|------|--------|--------|--------|
| `mmu_ptw_top_sva` | 97.73 | 100.00 | 100.00 | 97.24 | 100.00 | 91.43 |
| `mmu_pde_cache_sva` | 85.83 | 100.00 | 87.50 | 46.92 | 100.00 | 94.74 |
| `mmu_ptw_lsu_protocol_sva` | 92.73 | — | — | — | — | 92.73 |
| `mmu_ptw_xbar_sva` | 88.68 | 100.00 | — | 71.91 | — | 94.12 |

---

## Systemic Gap: Gate-Clock Cells

All `gated_clk_cell` instances show uniform partial coverage:

| Group | COND | TOGGLE |
|-------|------|--------|
| `x_ptw_gateclk` | 33.33 | 37.50 |
| `x_pde_cache_gateclk` | 33.33 | 37.50 |
| `x_twu_gateclk` | 44.44 | 50.00 |
| `x_pplru_gateclk` ×2 | 66.67 | 62.50 |
| `x_L1PDE_entry_gateclk` ×8 | 66.67 | 62.50 |
| `x_L2PDE_entry_gateclk` ×16 | 66.67 | 62.50 |
| `x_mbuf_entry_gateclk` ×9 | 33.33 | 37.50 |

Standard-cell `gated_clk_cell`; enable inputs toggle only during specific phases. Full closure needs dedicated clock-gating tests.

---

## Top Coverage Gaps (by severity)

| # | Module | Metric | Gap | Notes |
|---|--------|--------|-----|-------|
| 1 | PDE_cache (top) | TOGGLE | 39.44% | Entry state/flag signals |
| 2 | pde_cache_sva | TOGGLE | 53.08% | SVA probe signals |
| 3 | L1PDE entries ×8 | TOGGLE | 28–43% | Per-entry toggle |
| 4 | L2PDE entries ×16 | TOGGLE | 22–34% | Per-entry toggle |
| 5 | ptw_mbuf | COND | 27.90% | Priority/arbitration |
| 6 | ptw_mbuf | TOGGLE | 27.94% | Entry state/grant |
| 7 | one_to_four_xbar | TOGGLE | 25.08% | Dispatch signals |
| 8 | pplru (L1+L2) | COND | 20.00% | PLRU replacement |
| 9 | ptw_mem_if | TOGGLE | 21.90% | Memory IF signals |
| 10 | PDE_cache (top) | COND | 17.32% | Update/refill conditions |
| 11 | pplru (L1+L2) | BRANCH | 14.29% | PLRU tree branches |
| 12 | L2PDE entries | COND | 15–23% | Per-entry conditions |
