# Phase 12 Exit Checklist

## 推荐执行命令

- Phase 12 **单命令 gate（推荐收口入口）**：一次满足回归、`run_cov`、URG 合并与 **9 个 covergroup ≥50%** 校验（见 `mmu_verification/Makefile` 中 `phase12_exit_check`）
  - `make phase12_exit_check`
  - （可选跳过编译或回归）`PHASE12_SKIP_COMPILE=1`、`PHASE12_SKIP_REGRESSION=1` 等见 Makefile
- 编译：
  - `make comp`
- Phase 12 **带覆盖率**主回归（产出 `output/coverage/*.vdb` 与 URG；与 TaskDivision「9 个 CG ≥50%」证据一致）：
  - `make regress_v4_maee_ptw`（`LIST=simu/mmu_v4_phase12_list`，`REGRESS_MODE=run_cov`，种子见 `PHASE12_SEEDS` 默认）
  - 或手搓等价：`cd mmu_verification && make regress LIST=simu/mmu_v4_phase12_list REGRESS_MODE=run_cov REGRESS_NAME=phase12_v4 REGRESS_SEEDS="95101 95102 95103" REGRESS_MIN_PASS_RATE=1.0`（需已 `make comp`），结束后 `make cov`
- 若仅跑功能回归**不设覆盖率**，无法满足 Covergroup 门禁；签核前必须以 **`run_cov`** 合并报告为准。

## B 侧文档与范围门禁

- [ ] `doc/phase12_scene_matrix.md` 已冻结，且每个 feature bucket 都有至少 3 个变量维度。
- [ ] `doc/phase12_b_stage_manifest.csv` 已冻结，覆盖 22 个 runnable tests、9 个 CG、A/B handoff 和最终 gate。
- [ ] `doc/phase12_covergroup_matrix.md` 已冻结，9 个 CG 都写明 sample source、bin intent、candidate tests 和 probe 状态。
- [ ] `doc/phase12_a_handoff.md` 已冻结，明确 `B done / A pending / joint items`。
- [ ] Phase 12 范围内不包含 `TC-BUG-011`、Phase 13 `sysmap`、Phase 13 `PMP-TWU` 主体验证。

## A 侧集成门禁

- [ ] `mmu_verification/testbench/top/mmu_maee_twu_sva.sv` 已纳管编译。
- [ ] `mmu_maee_twu_sva.sv` 中存在 3 条 property。
- [ ] 每条 property 都有对应 `cover property`。
- [ ] `mmu_verification/Makefile` 推荐提供 `phase12_exit_check` 单命令 gate，统一串起 compile / regress / summary / exit checks。
- [ ] `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv` 骨架编译通过，且无 undefined reference。
- [ ] `mmu_verification/Makefile` 已提供 `regress_v4_maee_ptw` 或等价入口，消费 `simu/mmu_v4_phase12_list`。

## 回归门禁

- [ ] `mmu_v4_phase12_list` 3 个 seeds 全部执行：`95101 95102 95103`。
- [ ] 22 个 tests 在 3-seed union 下通过率为 `100%`。
- [ ] 回归 summary 中无 `UVM_ERROR` / `UVM_FATAL`。
- [ ] `scan_logs.pl` 或等效日志扫描结果为无未知 error pattern。

## SVA 可达性门禁

- [ ] `sva_twu_maee_paths_mutex` / `cp_twu_maee_paths_mutex` 聚合命中次数 `>=20`。
- [ ] `sva_maee0_triggers_csr_req` / `cp_maee0_triggers_csr_req` 聚合命中次数 `>=20`。
- [ ] `sva_maee1_skips_csr_fsm` / `cp_maee1_skips_csr_fsm` 聚合命中次数 `>=20`。
- [ ] 既有 `ptw/twu/xbar/arb` 相关 SVA 在 Phase 12 主回归中无新增 false fire。

## Covergroup 门禁

与 **TaskDivision §Phase 12 退出准则 #5** 一致：仅下列 **9 个** covergroup（宿主 `mmu_env_cg_whitebox.svh`），各自 URG **SCORE ≥ 50%**。自动化校验见 `scripts/phase12_exit_check.sh` → `step_covergroup_gate` → `scripts/phase12_cov_gate.py`（组名列表 `PHASE12_CGS`，阈值默认 `PHASE12_CG_MIN_PERCENT=50`）。**不包括** URG「Total groups」汇总分或其它 agent 内 CG。

- [ ] `cg_ptw_ready_transition` bin 命中率 `>=50%`
- [ ] `cg_twu_idle_vs_mask_state` bin 命中率 `>=50%`
- [ ] `cg_xbar_hit_level` bin 命中率 `>=50%`
- [ ] `cg_twu_except_while_arb_busy` bin 命中率 `>=50%`
- [ ] `cg_twu_data_ready_per_stage` bin 命中率 `>=50%`
- [ ] `cg_arb_grant_type` bin 命中率 `>=50%`
- [ ] `cg_ptw_arb_pgs_type` bin 命中率 `>=50%`
- [ ] `cg_maee_leaf_level` bin 命中率 `>=50%`
- [ ] `cg_maee_path` bin 命中率 `>=50%`

## 证据包清单

- [ ] `make comp` 日志
- [ ] `mmu_v4_phase12_list` 3-seed summary
- [ ] `mmu_maee_twu_sva.sv` property / cover property 命中统计
- [ ] 9 个 CG 的覆盖率摘要或 HTML 报告截图
- [ ] A side review note，说明 `MAEE SVA` 与既有 `PTW/TWU/ARB` SVA 的最终口径
- [ ] 若有未完成项，已明确标记为 `A-side pending`、`Phase 13 carry-over` 或 `blocked by RTL`

## 最终退出结论

- [ ] Phase 12 可关闭
- [ ] 若任一项未满足，保持 Phase 12 `进行中`，不得口头转 Phase 13
