# Phase 12 Scene Matrix

## 适用范围

- Phase 12 只覆盖 `MAEE / PTW-ready / TWU bypass / PTW->arb VPN&PGS`
- 不提前吸收 Phase 13 的 `sysmap` 主体验证和 `PMP-TWU` 主体验证
- Runnable scope 以 `mmu_verification/simu/mmu_v4_phase12_list` 的 22 个 test 为准

## 场景矩阵

| Feature Bucket | F-ID | 变量维度（至少 3 个） | 主场景切片 | 候选测试 | 关键观测点 | 覆盖 / SVA 挂钩 |
| --- | --- | --- | --- | --- | --- | --- |
| MAEE 双路属性选路 | F4.NEW.12 | `maee_mode={0,1,switch}`；`leaf_level={fst,scd,thd}`；`path={csr,refill,mixed-forbidden}`；`switch_timing={static,mid-translation}` | 固化 MAEE=0 走 CSR；MAEE=1 走 direct refill；翻译途中切换不乱序 | `test_mmu_twu_maee0_csr_path`；`test_mmu_twu_maee0_csr_symmetric`；`test_mmu_twu_maee1_direct_refill`；`test_mmu_twu_maee_dynamic_switch` | `*_chk_csr_req` / `*_chk_refill_req`；叶级分布；切换窗口内路径互斥 | `cg_maee_leaf_level`；`cg_maee_path`；`mmu_maee_twu_sva.sv` |
| PTW-ready 反压 | F4.NEW.6 | `mask_count={4,1,0}`；`ready_edge={fall,rise,hold-low}`；`stall_source={pmp_wait,slow_rsp,all_mask}`；`l2tlb_req_behavior={hold,drop-forbidden,recover}` | 4 路全 mask 拉低 ready；任一路解阻塞 ready 恢复；ready=0 期间 L2TLB 不发新请求 | `test_mmu_ptw_ready_all_mask_low`；`test_mmu_ptw_ready_one_unblock`；`test_mmu_ptw_ready_l2tlb_stall` | `ptw_l2tlb_ready`；`twu_mask[3:0]`；stall 窗口内请求行为 | `cg_ptw_ready_transition`；`sva_ptw_l2tlb_ready_when_all_mask` |
| TWU idle vs mask 语义 | F4.NEW.7 | `idle={0,1}`；`mask={0,1}`；`busy_source={pipe_vld,mbuf_have,csr_busy}`；`legality={legal,illegal}` | 证明 `idle=1 -> mask=0`；同时覆盖 `mask=0 && idle=0` 的合法忙态 | `test_mmu_twu_idle_implies_no_mask`；`test_mmu_mbuf_have_no_resend`；`test_mmu_mbuf_multi_twu_independent_ready` | `twu_idle[3:0]`；`twu_mask[3:0]`；`mbuf_twu_have[3:0]` | `cg_twu_idle_vs_mask_state`；`sva_twu_idle_implies_no_mask` |
| PDE Cache hit level / skip stage | F4.NEW.8 | `hit_level={00,10,01}`；`skip_stage={none,skip_fst,skip_fst_scd}`；`page_size={4K,2M,1G}`；`lsu_req_count={3,2,1}` | L3 hit 直达 THD；L2 hit 从 SCD 起步；full miss 完整三级 PTW | `test_mmu_pde_cache_hit_l3_skip_thd`；`test_mmu_pde_cache_hit_l2_skip_scd`；`test_mmu_pde_cache_full_miss_full_ptw` | `xbar_twu_hit_level`；阶段跳转；发往 LSU 的请求级数 | `cg_xbar_hit_level`；`sva_twu_skip_stage_on_hit` |
| TWU 异常直通旁路 | F4.NEW.9 | `arb_busy={0,1}`；`except_type={pgflt,accerr,conflict}`；`delivery_path={bypass,arb-forbidden}`；`mutual_exclusion={single,conflict}` | Arb 忙时 pgflt/accerr 直达 L2TLB；同次遍历 pgflt/accerr 不可同拍同有效 | `test_mmu_twu_pgflt_bypass_arb`；`test_mmu_twu_accerr_bypass_arb`；`test_mmu_twu_except_conflict_pgflt_accflt` | `pgflt_vld`；`acc_err_vld`；`arb_ptw_grant`；L2TLB 接收通路 | `cg_twu_except_while_arb_busy`；`sva_twu_except_bypasses_arb`；`sva_twu_pgflt_acc_mutex` |
| MBUF ready / have 门控 | F4.NEW.10 | `stage={fst,scd,thd}`；`data_ready={0,1}`；`mbuf_twu_have={0,1}`；`share_mode={single_twu,multi_twu}` | data_ready=0 不提前发 vld；have=1 不重发 LSU 请求；多 TWU 对同一 entry 独立 ready | `test_mmu_mbuf_ready_gate_no_early_vld`；`test_mmu_mbuf_have_no_resend`；`test_mmu_mbuf_multi_twu_independent_ready` | `twu_data_ready[][]`；`mbuf_twu_have[]`；重复请求抑制 | `cg_twu_data_ready_per_stage`；`sva_mbuf_waits_twu_ready`；`sva_mbuf_have_no_resend` |
| Arb grant / priority / fairness | F4.NEW.11 | `grant_type={refill,pgflt,accerr}`；`concurrent_req={1,2,3,4}`；`priority_case={onehot,except_over_refill,fairness}`；`request_distribution={single_twu,multi_twu}` | 同拍 one-hot；exception 优先于 refill；多 TWU 持续请求下无饿死 | `test_mmu_arb_grant_onehot_check`；`test_mmu_arb_refill_except_priority`；`test_mmu_arb_multi_twu_fairness` | `arb_ptw_grant`；`ptw_l2tlb_ref_pgflt`；`ptw_l2tlb_ref_acc_err`；grant 分布 | `cg_arb_grant_type`；`sva_arb_twu_grant_onehot` |
| PTW->arb VPN / PGS 一致性 | F5.16 | `pgs={4K,2M,1G}`；`vpn_match={exact,mismatch-forbidden}`；`bank_select={4Kbank,2Mbank,1Gbank}`；`request_source={ifu,lsu}` | tag_din 中 VPN 字段与独立 `ptw_arb_ref_vpn` 一致；不同页大小下 bank 选择正确 | `test_mmu_arb_vpn_match_tag_din`；`test_mmu_arb_pgs_bank_select` | `ptw_arb_vpn`；`ptw_arb_pgs`；`ptw_arb_ref_tag_din` | `cg_ptw_arb_pgs_type`；`sva_ptw_arb_vpn_matches_tag` |

## 运行顺序建议

1. 先跑 `MAEE` 4 个 test，冻结 `mmu_maee_twu_sva.sv` 的触发路径。
2. 再跑 `PTW-ready` 和 `TWU idle`，把 `ptw_l2tlb_ready / twu_idle / twu_mask` 的 probe 口径定死。
3. 然后跑 `PDE hit / except bypass / MBUF gate / arb`，完成 `mmu_env_cg_whitebox.svh` 的 9 个 Phase 12 CG。
4. 最后用 `mmu_v4_phase12_list` 做 3-seed union 回归。

## 不纳入 Phase 12 的项

- `TC-BUG-011 / R19`
- `F4.NEW.13 / F4.NEW.14` 的 PMP 主体验证
- `F6.NEW.*` 的 sysmap 主体验证
- Phase 13 的 `pmp_twu_tests_v6/` 与 `sysmap_tests/`
