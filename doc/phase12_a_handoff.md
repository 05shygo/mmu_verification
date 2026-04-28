# Phase 12 A Handoff

## B 已完成 / 已冻结

- Phase 12 runnable scope 已冻结为 `mmu_verification/simu/mmu_v4_phase12_list` 中的 22 个 tests。
- B 侧文档包已就位：
  - `doc/phase12_scene_matrix.md`
  - `doc/phase12_b_stage_manifest.csv`
  - `doc/phase12_covergroup_matrix.md`
  - `doc/phase12_exit_checklist.md`
- `MAEE / PTW-ready / TWU bypass / PTW->arb VPN&PGS` 的 bucket、F-ID、candidate tests、9 个 covergroups 和 3-seed 口径已经冻结。
- 本阶段不提前吸收：
  - `TC-BUG-011 / R19`
  - Phase 13 的 `sysmap` 主体验证
  - Phase 13 的 `PMP-TWU` 主体验证

## A 待完成

### 1. `mmu_verification/testbench/top/mmu_maee_twu_sva.sv`

- 需要 3 条可编译、可触发、带 `cover property` 的 MAEE SVA。
- 推荐按当前 B 侧 checker 口径收敛为：
  - `sva_twu_maee_paths_mutex`
  - `sva_maee0_leaf_uses_csr_req`
  - `sva_maee1_leaf_skips_csr_req`
- 如 A 侧沿用 BuildPlan 旧名，可在文件头注明别名映射，但最终需要与 B 侧 review 记录一一对位。

### 2. `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv`

- Phase 12 只要求骨架可编译。
- 不要求在本阶段完成 Phase 13 的 PMP 主语义。
- 退出口径仅为：
  - 无 undefined reference
  - 可被 `make comp` 纳管

### 3. `mmu_verification/Makefile`

- 需要增加 `regress_v4_maee_ptw` 或等价入口。
- 建议消费：
  - `LIST=simu/mmu_v4_phase12_list`
  - `REGRESS_SEEDS="95101 95102 95103"`

## Joint Items

| Joint Item | B 侧触发测试 | A 侧动作 | Review hook | 关闭条件 |
| --- | --- | --- | --- | --- |
| MAEE 路径互斥 | `test_mmu_twu_maee0_csr_path`；`test_mmu_twu_maee1_direct_refill`；`test_mmu_twu_maee_dynamic_switch` | 实现 `sva_twu_maee_paths_mutex` + `cover property` | 检查 MAEE=0/1/switch 三类路径都命中且无 mixed-fire | 3 类路径均有命中统计，且 3-seed union 无 assertion fail |
| MAEE=0 叶级走 CSR | `test_mmu_twu_maee0_csr_path`；`test_mmu_twu_maee0_csr_symmetric` | 实现 `sva_maee0_leaf_uses_csr_req` + `cover property` | 检查 FST/SCD/THD 至少有 2 个叶级被 cover 到；`csr_req` 为主路径 | A/B 对 `leaf_level` 命中报告签字 |
| MAEE=1 跳过 CSR | `test_mmu_twu_maee1_direct_refill`；`test_mmu_twu_maee_dynamic_switch` | 实现 `sva_maee1_leaf_skips_csr_req` + `cover property` | 检查 MAEE=1 条件下 `csr_req=0` 且 `refill_req=1` | 3-seed union 下 cover hit 达标、无 false fire |
| 既有 PTW/TWU SVA 复核 | `test_mmu_ptw_ready_*`；`test_mmu_twu_idle_implies_no_mask`；`test_mmu_twu_pgflt_bypass_arb`；`test_mmu_twu_accerr_bypass_arb`；`test_mmu_mbuf_*`；`test_mmu_arb_*` | A 复核现有 `ptw/twu/xbar/arb` SVA 的绑定点和信号名是否与 Phase 12 probe 口径一致 | 对照 `doc/phase12_covergroup_matrix.md` 的 signal map | review note 写明“沿用/修改/待补”结论 |
| Phase 12 回归入口 | `mmu_v4_phase12_list` 全表 | A 在 Makefile 中落入口并串 summary | 确认 list 只消费这 22 个 tests，默认 3 seeds | `regress_v4_maee_ptw` 能独立跑通并产出 summary |

## 推荐对位命令

- 编译入口：
  - `make comp`
- Phase 12 union：
  - `make regress LIST=simu/mmu_v4_phase12_list REGRESS_MODE=run_check REGRESS_SEEDS="95101 95102 95103"`
- 如果 A 已补 Makefile target：
  - `make regress_v4_maee_ptw REGRESS_SEEDS="95101 95102 95103"`

## 交接边界说明

- B 不在本批次承担 `testbench/top/*.sv` 的新增 SVA 实现。
- A 不需要改写 B 侧 test 命名、list 分桶和 scene matrix。
- 若 A 侧需要改 property 名称或 probe 命名，先回写本文件，再动代码。
