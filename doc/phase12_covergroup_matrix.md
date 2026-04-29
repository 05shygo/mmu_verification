# Phase 12 Covergroup Matrix

## 宿主与采样原则

- Phase 12 的 9 个 covergroup 统一建议落在 `mmu_verification/testbench/env/mmu_env_cg_whitebox.svh`
- 本轮已在以下文件中补齐 Phase 12 所需 probe：
  - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
  - `mmu_verification/testbench/top/tb_top.sv`
- `cg_arb_grant_type`、`cg_maee_leaf_level`、`cg_maee_path` 使用了轻量推导信号，并在代码中保留了推导依据注释。

## Covergroup 映射表

| Covergroup | 对应特性 | 采样信号 / 候选来源 | Bin intent | 候选测试 | Probe 状态 |
| --- | --- | --- | --- | --- | --- |
| `cg_ptw_ready_transition` | `F4.NEW.6` PTW-ready 反压 | `ptw_jtlb_ready`；`ptw_twu_mask[3:0]`；`arb_l2tlb_req` | `ready_fall_when_mask4`；`ready_rise_when_any_unmask`；`ready_low_stall_window` | `test_mmu_ptw_ready_all_mask_low`；`test_mmu_ptw_ready_one_unblock`；`test_mmu_ptw_ready_l2tlb_stall` | 已落地 |
| `cg_twu_idle_vs_mask_state` | `F4.NEW.7` idle vs mask | `ptw_twu_idle[3:0]`；`ptw_twu_mask[3:0]`；`ptw_mbuf_twu_have[3:0]` | `idle1_mask0_legal`；`idle0_mask0_busy`；`idle0_mask1_self_block`；`idle1_mask1_illegal` | `test_mmu_twu_idle_implies_no_mask`；`test_mmu_mbuf_have_no_resend`；`test_mmu_mbuf_multi_twu_independent_ready` | 已落地 |
| `cg_xbar_hit_level` | `F4.NEW.8` PDE hit level | `ptw_xbar_hit_lvl`；`ptw_arb_pgs` | `miss_00`；`hit_l2_10`；`hit_l3_01`；`reserved_11` | `test_mmu_pde_cache_full_miss_full_ptw`；`test_mmu_pde_cache_hit_l2_skip_scd`；`test_mmu_pde_cache_hit_l3_skip_thd` | 已落地 |
| `cg_twu_except_while_arb_busy` | `F4.NEW.9` 异常直通旁路 | `ptw_twu_pgflt_vec`；`ptw_twu_acc_err_vec`；`ptw_pgflt_vld`；`ptw_acc_err_vld`；`arb_ptw_grant`；`arb_l2tlb_req` | `pgflt_when_arb_busy`；`accerr_when_arb_busy`；`conflict_filtered` | `test_mmu_twu_pgflt_bypass_arb`；`test_mmu_twu_accerr_bypass_arb`；`test_mmu_twu_except_conflict_pgflt_accflt` | 已落地 |
| `cg_twu_data_ready_per_stage` | `F4.NEW.10` MBUF ready/have 门控 | `ptw_twu_data_ready[3:0][2:0]`；`ptw_mbuf_twu_have[3:0]`；`ptw_twu_ref_req[3:0]` | `fst_wait_no_vld`；`scd_have_no_resend`；`thd_multi_twu_independent` | `test_mmu_mbuf_ready_gate_no_early_vld`；`test_mmu_mbuf_have_no_resend`；`test_mmu_mbuf_multi_twu_independent_ready` | 已落地 |
| `cg_arb_grant_type` | `F4.NEW.11` arb grant/prio/fairness | `arb_ptw_grant`；`ptw_pgflt_vld`；`ptw_acc_err_vld`；`ptw_l2tlb_ref_pgflt`；`ptw_l2tlb_ref_acc_err`；`ptw_twu_ref_req[3:0]` | `grant_onehot_refill`；`grant_onehot_pgflt`；`grant_onehot_accerr`；`except_over_refill`；`fairness_rotation` | `test_mmu_arb_grant_onehot_check`；`test_mmu_arb_refill_except_priority`；`test_mmu_arb_multi_twu_fairness` | 已落地 |
| `cg_ptw_arb_pgs_type` | `F5.16` PTW->arb VPN/PGS | `ptw_arb_pgs`；`ptw_arb_vpn`；`ptw_arb_ref_tag_din` | `vpn_match_4k`；`vpn_match_2m`；`vpn_match_1g`；`bank_select_per_pgs` | `test_mmu_arb_vpn_match_tag_din`；`test_mmu_arb_pgs_bank_select` | 已落地 |
| `cg_maee_leaf_level` | `F4.NEW.12` MAEE 叶级分布 | `ptw_cp0_maee`；`maee_leaf_lvl1_hit`；`maee_leaf_lvl2_hit`；`maee_leaf_lvl3_hit` | `maee0_fst_csr`；`maee0_scd_csr`；`maee1_leaf_refill` | `test_mmu_twu_maee0_csr_path`；`test_mmu_twu_maee0_csr_symmetric`；`test_mmu_twu_maee1_direct_refill` | 已落地 |
| `cg_maee_path` | `F4.NEW.12` MAEE path / switch | `ptw_cp0_maee`；`maee_csr_path_hit`；`maee_refill_path_hit`；`ptw_jtlb_ready` | `maee0_csr_only`；`maee1_refill_only`；`switch_no_mixed_fire` | `test_mmu_twu_maee0_csr_path`；`test_mmu_twu_maee1_direct_refill`；`test_mmu_twu_maee_dynamic_switch` | 已落地 |

## 50% bin 命中最低目标

- `cg_ptw_ready_transition`：3 个主 bin 全命中
- `cg_twu_idle_vs_mask_state`：至少命中 `idle1_mask0_legal`、`idle0_mask0_busy`、`idle0_mask1_self_block`
- `cg_xbar_hit_level`：至少命中 `00/10/01`
- `cg_twu_except_while_arb_busy`：至少命中 `pgflt_when_arb_busy`、`accerr_when_arb_busy`
- `cg_twu_data_ready_per_stage`：至少命中 `fst_wait_no_vld`、`scd_have_no_resend`、`thd_multi_twu_independent`
- `cg_arb_grant_type`：至少命中 `refill`、`pgflt/accerr`、`except_over_refill`
- `cg_ptw_arb_pgs_type`：至少命中 `4K/2M/1G` 三种 `pgs`
- `cg_maee_leaf_level`：至少命中 `maee0_fst_csr`、`maee0_scd_or_thd_csr`、`maee1_leaf_refill`
- `cg_maee_path`：至少命中 `maee0_csr_only`、`maee1_refill_only`、`switch_no_mixed_fire`

## 建议最小 probe 扩展集

- `ptw_jtlb_ready`
- `ptw_twu_mask[3:0]`
- `ptw_twu_idle[3:0]`
- `ptw_twu_data_ready[3:0][2:0]`
- `ptw_mbuf_twu_have[3:0]`
- `ptw_twu_ref_req[3:0]`
- `ptw_twu_pgflt_vec[3:0]`
- `ptw_twu_acc_err_vec[3:0]`
- `ptw_pgflt_vld`
- `ptw_acc_err_vld`
- `ptw_l2tlb_ref_pgflt`
- `ptw_l2tlb_ref_acc_err`
- `arb_ptw_grant`
- `arb_l2tlb_req`
- `ptw_arb_pgs`
- `ptw_arb_vpn`
- `ptw_arb_ref_tag_din`
- `ptw_cp0_maee`
- `maee_leaf_lvl1_hit / maee_leaf_lvl2_hit / maee_leaf_lvl3_hit`
- `maee_csr_path_hit / maee_refill_path_hit`
