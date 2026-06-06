# PTW Code Coverage Detection Plan

## 1. 目标

本文档定义 PTW RTL 代码覆盖率检测计划，用于在现有 PTW/UVM 功能回归已经通过之后，进一步确认 PTW 部分代码覆盖率是否达标，并产出一个可审计的 PTW 代码覆盖率数值结果。

最终产物必须是 PTW-only 口径的覆盖率结果，不能使用全 MMU 覆盖率、testbench 覆盖率或 SVA 覆盖率替代。

最终报告至少输出以下内容：

```text
PTW_CODE_COVERAGE_RESULT status=<PASS|FAIL|CONDITIONAL_PASS>
scope=<ptw_core>
headline=<xx.xx>
line=<xx.xx|N/A>
condition=<xx.xx|N/A>
branch=<xx.xx|N/A>
fsm=<xx.xx|N/A>
toggle=<xx.xx|N/A>
assertion=<xx.xx|N/A>
report=<URG report path>
cov_db=<VDB path>
```

其中 `headline` 是 PTW 代码覆盖率的最终数值。该数值只允许来自 PTW-only URG report，且必须同时给出 line/condition/branch/fsm/toggle 分项，避免单一总分掩盖某一类覆盖率缺口。`PASS` 只能用于高可信、PTW-only scope、所有门槛满足，或未达标对象已有精确且正式批准的 waiver 的 signoff 结果；`CONDITIONAL_PASS` 用于非 signoff profile、functional gate 证据不完整、parser 可信度不足、或只有临时/待审批 waiver 的中间结果。

## 2. 路径和执行目录约定

当前仓库根目录为：

```text
/x2025/GPrj1/IC2/mmu_verification
```

本文档保存于仓库根目录下：

```text
doc/ptw_uvm_review/ptw_code_coverage_detection_plan.md
```

仿真 Makefile、testlist、script 和 output 目录位于仓库根目录下的 `mmu_verification/` 子目录：

```text
mmu_verification/Makefile
mmu_verification/scripts/
mmu_verification/simu/
mmu_verification/output/
```

除非特别说明，本文档中的 `make`、`scripts/...`、`simu/...`、`output/...` 命令都必须先进入仿真目录后执行：

```bash
cd /x2025/GPrj1/IC2/mmu_verification/mmu_verification
```

如果从仓库根目录执行，需要给 `make` 增加 `-C mmu_verification`，并相应调整脚本和输出路径。

## 3. 当前环境事实

### 3.1 已有功能 signoff 资料

现有 PTW 修改计划和功能闭合资料位于：

- `doc/ptw_uvm_review/ptw_staged_implementation_plan.md`
- `doc/ptw_uvm_review/ptw_phase1_test_sva_implementation_plan.md`
- `doc/ptw_uvm_review/ptw_source_signoff_report.md`
- `doc/ptw_uvm_review/ptw_source_closure_matrix.md`

这些资料已经建立 PTW source-side 功能闭合口径，但它们不是代码覆盖率闭合结果。代码覆盖率检测需要在功能回归通过的基础上单独执行 VCS/URG 覆盖率流程。

### 3.2 Makefile 覆盖率能力

当前 `mmu_verification/Makefile` 已经支持 VCS code coverage：

- 编译覆盖率开关：`COV_COMPILE_OPTS`
- 运行覆盖率开关：`COV_RUN_COMMON_OPTS`
- 覆盖率类型：`COV_METRICS := line+cond+fsm+tgl+branch+assert`
- 覆盖率层级配置：`COV_HIER_CFG := $(PROJECT_DIR)/scripts/cov_hier.cfg`
- 聚合 VDB：`COV_DB_DIR ?= $(OUTPUT_DIR)/simv.vdb`
- compile baseline VDB：`COV_BASE_DB_DIR ?= $(OUTPUT_DIR)/simv.compile.vdb`
- URG 报告目录：`URG_REPORT_DIR ?= $(COV_DIR)/urgReport`

关键目标：

- `make comp_all`：带覆盖率重新编译并生成 compile baseline。
- `make run_cov`：运行单个测试并把覆盖率写入聚合 VDB。
- `make regress REGRESS_MODE=run_cov`：按测试列表批量运行覆盖率。
- `make cov`：调用 `scripts/run_urg_report.sh` 生成 URG report。

重要限制：

- `run_cov` 会写同一个聚合 VDB，因此覆盖率回归必须使用 `REGRESS_JOBS=1` 串行执行。
- 当前默认 `scripts/cov_hier.cfg` 是全 `tb_top` 口径，不是 PTW-only 口径，不能直接作为最终 PTW 覆盖率依据。

### 3.3 当前默认 coverage hierarchy 风险

当前 `mmu_verification/scripts/cov_hier.cfg` 内容以 `+tree tb_top` 为起点，并排除了部分 SVA module。该配置适合全环境覆盖率，但不适合作为 PTW-only 覆盖率结果，因为它可能包含：

- `ct_mmu_top` 顶层逻辑；
- L1ITLB/L1DTLB/L2TLB/PMP/SysMap 等非 PTW RTL；
- testbench wrapper；
- 未排除的 PTW SVA 或其他 SVA module。

因此本计划要求建立独立的 PTW coverage hierarchy 配置。

### 3.4 现有测试列表和覆盖率刺激来源

本计划已核对当前 PTW 相关 testlist 和消费者场景 testlist。它们在覆盖率计划中的用途如下：

| Testlist | Entry Count | 覆盖率用途 |
| --- | ---: | --- |
| `simu/ptw_p0_smoke_list` | 5 | PTW source-side smoke 和环境 sanity；若 `ptw_p0_list` 已覆盖相同 test/seed，不重复写入 coverage aggregate |
| `simu/ptw_p0_list` | 13 | P0 directed 主入口，覆盖 PTE layout、type/PFU fault、permission、PDE/MBUF/PMP、MAEE/SysMap、flow trace、PDE pmpflg 基础场景 |
| `simu/ptw_p1_list` | 7 | P1 directed 扩展，覆盖 satp old walk reupdate、PMP cfg clear、ASID current sample、MAEE/SysMap mid-change、随机 permission cross 和 PDE accerr/pmp clear |
| `simu/ptw_p2_illegal_list` | 3 | illegal/no-request/constraint guard，防止 bare mode、same ID reuse 等非法路径污染功能和覆盖率解释 |
| `simu/ptw_pde_pmpflg_list` | 9 | PDE cache pmpflg directed closure，覆盖 L1/L2 PDE PMP deny/allow、propagation、priority、clear/repopulate |
| `simu/ptw_random_list` | 1 | PTW random PTE permission cross，作为随机补洞入口 |
| `simu/ptw_consumer_evidence_list` | 7 | consumer-only evidence，补充上游消费者触发 PTW 的可见场景 |
| `simu/mmu_ptw_lsu_protocol_list` | 5 | PTW 与 LSU memory channel protocol、grant/response/backpressure 场景 |
| `simu/mmu_v4_phase12_list` | 22 | MAEE/TWU bypass/PTW-ready/MBUF/arb 相关系统级刺激 |
| `simu/mmu_v4_phase13_list` | 55 | PMP/TWU、SysMap、4-TWU concurrency 和系统级 corner 刺激 |
| `simu/mmu_v4_full_regression_list` | 93 | 最终 signoff 或 hole-fill 全回归入口 |

`ptw_p0_*`、`ptw_p1_list`、`ptw_p2_illegal_list`、`ptw_pde_pmpflg_list` 和 `ptw_random_list` 均带有 PTW source-side plusargs，例如：

```text
+EN_PTW_SOURCE_SB
+EN_PTW_SOURCE_REF_MODEL
+EN_PTW_SOURCE_MONITOR
+EN_PTW_SOURCE_COV
```

这些 plusargs 用于功能 scoreboard、reference model、monitor 和 source functional coverage marker，不改变 VCS/URG code coverage scope。PTW code coverage 的 scope 仍由 `ptw_cov_hier.cfg` 决定。

L1DTLB/L2TLB audit 资料中有大量通过 PTW 路径形成的 consumer 场景，例如 refill、fault、install arbitration、PTW completion、PMP/SysMap/TLBOP 交互等。这些场景可以用于刺激 PTW RTL 未覆盖分支，但不能把 L1DTLB/L2TLB RTL、SVA 或 functional coverage 计入 PTW code coverage headline。

### 3.5 现有 PTW 测试内容明细

现有 PTW 测试不是单一来源，而是由 source-directed tests、legacy Phase9 wrappers、Phase11 protocol tests、Phase12/13 system-level consumers 共同组成。代码覆盖率计划必须理解这些测试实际在做什么，避免把 wrapper 名称误当成真实场景覆盖。

#### 3.5.1 PTW source-directed 基础设施

`testbench/test/ptw_tests/ptw_source_directed_base.svh` 是当前 PTW source-side directed 测试的核心基类。它提供：

- Sv39 上下文配置；
- raw PTE/PDE 构造；
- 1G/2M/4K leaf 和 non-leaf page-table 写入；
- IFU/LSU/PFU source request 驱动；
- PMP/SysMap/PTW-memory 控制；
- quiescent wait；
- illegal stimulus guard；
- scenario metadata 打点；
- `PTW_SCENARIO_*`、`PTW_SOURCE_*`、closure marker 输出；
- 在 `+EN_PTW_SOURCE_MONITOR` 打开时注册 scenario DB。

因此 `ptw_p0_*`、`ptw_p1_list`、`ptw_p2_illegal_list`、`ptw_pde_pmpflg_list` 中的 source tests 是真实 directed 场景，不是薄 wrapper smoke。

#### 3.5.2 P0 source-directed tests

`simu/ptw_p0_list` 当前包含 13 个测试，其中 6 个是 Stage6 P0 matrix 测试，7 个是 PDE pmpflg directed 测试。

P0 Stage6 matrix 测试内容：

| Test | 主要内容 |
| --- | --- |
| `test_ptw_p0_pte_layout_matrix` | RSW/high-reserved 4K leaf；1G leaf global；non-leaf G bit 不向 leaf global OR；覆盖 PTE layout、global、RSW/high-reserved 解释 |
| `test_ptw_p0_type_pfu_fault_matrix` | fetch/load/store/PFU source type；PFU fault 行为；PMP original type permission，包括 fetch X deny 和 load R allow |
| `test_ptw_p0_permission_matrix` | write-only + MXR=0 fault；MXR=1 success；store D=0 fault；S-mode U page + SUM=0 fault；U-mode supervisor leaf fault；1G alignment before degrade；THD non-leaf page fault；SCD V=0 page fault |
| `test_ptw_p0_pde_mbuf_pmp_matrix` | L1 PDE hit final 2M；L2 PDE hit final 4K；FST PMP deny access fault；MBUF CHK-not-ready hold；LSU bus error priority access fault；MPRV/MPP=M data/PFU direct-map no-PTW |
| `test_ptw_p0_maee_sysmap_matrix` | MAEE=1 下 1G/2M/4K ext_attr；MAEE=0 下 4K SysMap refill |
| `test_ptw_p0_flow_trace_umbrella` | PTW-FLOW-001..023 flow trace umbrella；用于把 Stage6 flow closure marker 和 source/SVA evidence 对齐 |

这些测试会输出 `PTW_STAGE6_CLOSURE`、`PTW_FLOW_BIND`、`PTW_SOURCE_SB_SUMMARY` 和 `PTW_SVA_COVER` 等 marker，是功能 signoff gate 的主依据。

#### 3.5.3 P1/P2/random source-directed tests

`simu/ptw_p1_list`、`simu/ptw_p2_illegal_list`、`simu/ptw_random_list` 来自 `test_ptw_stage7_suite.svh`。

| Test | 主要内容 |
| --- | --- |
| `test_ptw_pde_satp_old_walk_reupdate_001` | SATP old-walk/reupdate 场景，覆盖旧 walk 与新上下文切换后的 PDE/refill 行为 |
| `test_ptw_pmp_cfg_clear_no_flush_001` | PMP cfg clear no-flush 场景，覆盖 PMP 配置变化对 PTW/PDE cache 行为的影响 |
| `test_ptw_asid_refill_current_sample_001` | ASID change/abort constraint，验证 refill 使用当前上下文采样并阻断非法旧上下文可见性 |
| `test_ptw_maee_mid_sysmap_change_001` | MAEE 与 SysMap mid-change 场景，覆盖 walk/refill 路径中的 SysMap/MAEE 动态变化 |
| `test_ptw_random_pte_perm_cross_001` | 随机 PTE permission cross，覆盖 V/R/W/X/U/A/D/MXR/SUM/priv/type 组合 |
| `test_ptw_same_id_no_reuse_constraint_001` | same ID reuse 非法约束，不应把非法 reuse 当作 DUT failure |
| `test_ptw_bare_mode_no_request_constraint_001` | bare/M-mode no-request 约束，验证无 PTW 请求路径 |
| `test_ptw_p2_illegal_constraint_matrix` | SysMap malformed、same ID reuse、bare mode、PTW memory OOO 等非法刺激约束矩阵 |

P2 illegal tests 的目标是证明非法场景被 testbench 约束或被环境识别，不能把它们当作普通 PTW source closure。它们可以帮助解释 code coverage 中某些非法分支为何不可由正常测试触发。

#### 3.5.4 PDE pmpflg directed tests

`simu/ptw_pde_pmpflg_list` 覆盖 PDE cache 中 `pmpflg` 相关路径。当前测试包括：

| Test | 主要内容 |
| --- | --- |
| `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001` | L1 PDE tag hit 后 cached PMP X deny；FST fault/access-fault path |
| `test_ptw_pde_l1_pmp_tag_allow_reuse_001` | L1 PDE cached PMP allow reuse；验证允许路径不会误报 direct accerr |
| `test_ptw_pde_l2_pmp_l1_deny_accerr_001` | L2 cached PDE 命中但 L1 PMP deny；验证 direct accerr 和 no-extra-LSU |
| `test_ptw_pde_l2_pmp_l2_deny_accerr_001` | L2 PMP deny accerr 相关 open/known-gap 场景 |
| `test_ptw_pde_pmpflg_propagation_update_001` | FST update L1 payload；SCD update L2 payload；THD leaf no update |
| `test_ptw_pde_accerr_priority_type_id_001` | PDE accerr priority、source type、ID 传播 |
| `test_ptw_pde_mmode_lock_matrix_001` | M-mode lock matrix 相关 open/known-gap 场景 |
| `test_ptw_pde_l2_accerr_valid_gate_001` | L2 accerr invalid reset tag0 gate；invalid stale tag gate |
| `test_ptw_pde_pmp_clear_repopulate_001` | PMP clear/repopulate；覆盖清除后重新填充路径 |

这些测试会输出 `PTW_STAGE8_CLOSURE`、`PTW_STAGE9_CLOSURE`、`PTW_SOURCE_SB_PDE_PMP_COVERAGE` 和 PDE pmpflg SVA cover marker。现有 signoff gate 对这些 marker 有专门检查。

#### 3.5.5 Legacy Phase9 PTW wrappers

`testbench/test/ptw_tests/ptw_tests_suite.svh` 还包含大量 Phase9 generated wrapper。它们通常继承 `phase9_generated_test_base`，通过 `setup_plan()` 声明 `p9_tc_id`、`p9_seq_desc`、checker metadata 和复用 sequence 列表。

`phase9_generated_test_base` 默认会做：

- CP0 TLB all-inv；
- PMP allow/default setup；
- SysMap setup；
- SATP Sv39 enable；
- 4K page mapping bring-up；
- 依次启动 `m_cp0_seq_names`、`m_pmp_seq_names`、`m_sysmap_seq_names`、`m_ptw_seq_names`、`m_ifu_seq_names`、`m_lsu_seq_names`、`m_vseq_names` 中声明的 sequence。

这类 wrapper 对 code coverage 有价值，因为它们能补 PTW datapath/control 的结构覆盖，但不能全部当作 source signoff 证据。主要功能族包括：

- basic page walk：`test_ptw_satp_load_basic`、`test_ptw_l0_pte_read_basic`、`test_ptw_l0_pte_permission_check`；
- huge page：`test_huge_page_1g_direct`、`test_huge_page_2m_direct`、`test_huge_page_4k_full_walk`、`test_huge_page_mixed`；
- PTE fault/attribute：`test_pte_v_bit_zero`、`test_pte_rw_both_zero`、`test_pte_u_bit_sum_interaction`、`test_pte_x_bit_mxr_mix`、`test_pte_global_bit_asid`、`test_pte_misaligned_ppn_1g`、`test_pte_misaligned_ppn_2m`；
- PDE cache：`test_ptw_l1_pde_hit`、`test_ptw_l1_pde_miss_walk`、`test_ptw_l1_pde_cache_replace`、`test_ptw_l2_pde_hit_direct`、`test_ptw_l2_pde_miss_walk`、`test_ptw_l2_pde_cache_replace`、`test_pde_cache_l1_single_entry`、`test_pde_cache_l2_single_entry`、`test_pde_cache_clear_on_ptw_reset`；
- xbar/TWU：`test_xbar_1to4_distribution`、`test_twu_concurrent_same_vpn`、`test_twu_concurrent_4way`、`test_twu_idle_state`；
- MBUF/LSU memory：`test_mbuf_full_backpressure`、`test_mbuf_credit_management`、`test_bus_error_terminate`；
- arbiter：`test_arb_backpressure_mask`、`test_arb_bank_conflict_resolution`、`test_arb_no_double_grant`、`test_arb_ptw_priority_highest`、`test_arb_reqq_preempt_lower`、`test_arb_work_conserving`、`test_arb_tlboper_above_prefetch`、`test_arb_skew_index_generation`；
- control hazard：`test_satp_switch_during_walk`、`test_ptw_satp_load_dual_switch`、`test_sfence_abort_walk`。

部分 legacy wrapper 已在源码 metadata 中标为 obsolete-by-spec 或 not-source-closure，例如旧的 xbar round-robin、reserved-bit fault、MBUF OOO expectation。它们不能用于功能闭合结论；若纳入 code coverage aggregate，必须确认当前 regression 已通过且不会引入非法行为解释偏差。

#### 3.5.6 Phase11 PTW-LSU protocol tests

`simu/mmu_ptw_lsu_protocol_list` 来自 `testbench/test/ptw_lsu_protocol_tests/`，继承 `phase11_generated_test_base`。这些测试专门刺激 PTW MBUF 到 LSU/PTW-memory channel：

| Test | 主要内容 |
| --- | --- |
| `test_pmbuf_serial_outstanding_001` | slow PTW memory response + mapped LSU pipe0 back-to-back；检查 single outstanding 和 request stable |
| `test_pmbuf_addr_stable_001` | slow PTW memory response + mapped LSU pipe0 round-robin；检查 LSU address stable 和 outstanding cover |
| `test_pmbuf_no_tag_001` | normal response + mapped LSU pipe0；检查 no-tag/normal response path |
| `test_pmbuf_inorder_resp_001` | normal response + LSU pipe0/pipe1 concurrent；检查 in-order response 行为 |
| `test_pmbuf_ptr_hold_001` | slow response + LSU pipe0/pipe1 concurrent；检查 MBUF pointer 只在 response 时推进 |

这些测试主要补 `ptw_mbuf.sv`、PTW memory request/response、grant/response backpressure、single-outstanding 相关 code coverage。

#### 3.5.7 Phase12/Phase13 consumer/system-level tests

`simu/mmu_v4_phase12_list` 包含 22 个测试，主要覆盖：

- MAEE family：CSR path、symmetric、direct refill、dynamic switch；
- PTW-ready family：all mask low、one unblock、L2TLB stall；
- TWU bypass/PTW/MBUF/arb family：PDE cache hit skip、PDE full miss full PTW、page/access fault bypass arb、MBUF ready gate、multi-TWU ready、arb grant/refill/fairness/VPN tag/page-size bank select。

`simu/mmu_v4_phase13_list` 包含 55 个测试，主要覆盖：

- PMP/TWU family：serial/wait/stall、PMP before LSU、deny stop、PMP PA 1G/2M/4K/zero、deny accflt/no-refill、M-mode L0、mask wait all4、fetch zero、port map concurrent；
- existing PMP baseline：deny access/fetch/cross-port/8-port/port independence/saturation/alignment/pipeline/PDE cache flow；
- SysMap family：flag refill region0/7、1G/2M degrade、no-cross no-degrade、PA alignment、4-TWU concurrent、default flag、多 region、no-walk、SysMap vs PTW priority。

这些测试可以刺激 `twu.sv`、`one_to_four_xbar.sv`、PMP/SysMap interaction 和 multi-TWU concurrency 的结构覆盖。最终 code coverage scope 仍必须限制在 PTW RTL，不纳入 PMP/SysMap/L1/L2TLB RTL。

#### 3.5.8 Consumer-only evidence tests

`simu/ptw_consumer_evidence_list` 包含：

- `test_mmu_l1dtlb_dtlb_refill_001`
- `test_mmu_l1dtlb_dtlb_mb_pgflt_001`
- `test_mmu_l1dtlb_dtlb_access_fault_source_parity_001`
- `test_mmu_l1dtlb_dtlb_refill_stale_id_001`
- `test_mmu_l1dtlb_dtlb_sysmap_001`
- `test_mmu_l1itlb_itlb_pgflt_001`
- `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior`

这些测试证明 PTW-facing output 被下游消费，但不关闭 PTW source-side PTE/PMP/PDE/MAEE/MBUF 功能点。它们适合放在 coverage T2 中作为 PTW RTL 刺激来源。

## 4. PTW 覆盖率范围定义

### 4.1 DUT 层级

测试平台中 DUT 实例路径为：

```text
tb_top.u_dut
```

MMU 顶层 `ct_mmu_top.v` 内部 PTW 实例为：

```text
tb_top.u_dut.x_ct_mmu_ptw
```

PTW-only 覆盖率的首选 scope 是该实例树：

```text
tb_top.u_dut.x_ct_mmu_ptw
```

### 4.2 PTW RTL module 范围

PTW coverage 应覆盖以下 RTL module：

- `ptw`
- `ptw_mbuf`
- `twu`
- `PDE_cache`
- `L1PDE_cache`
- `L2PDE_cache`
- `one_to_four_xbar`
- `pplru`

这些 module 对应的主要源码文件位于 `mmu/rtl/`：

- `ptw.sv`
- `ptw_mbuf.sv`
- `twu.sv`
- `PDE_cache.sv`
- `L1PDE_cache.sv`
- `L2PDE_cache.sv`
- `one_to_four_xbar.sv`
- `pplru.sv`

`PDE_cache` 内部包含 L1/L2 PDE entry generate 实例和 `pplru`；`ptw` 内部包含 `PDE_cache`、`one_to_four_xbar`、4 个 `twu` 和 `ptw_mbuf`。因此该 module 集合可以覆盖 PTW core datapath、control、PDE cache、TWU walk/check/refill/fault path、xbar dispatch 和 MBUF/LSU memory channel。

### 4.3 明确不纳入 PTW code coverage 的范围

以下对象不纳入 PTW 代码覆盖率 headline：

- `ct_mmu_top` 及其非 PTW glue logic；
- L1ITLB/L1DTLB/L2TLB RTL；
- PMP/SysMap 独立 RTL；
- UVM testbench class；
- interface、monitor、scoreboard、reference model；
- SVA module；
- 通用 clock gating cell，例如 `gated_clk_cell`，除非项目覆盖率规范明确要求将其计入 PTW 代码覆盖率。

SVA/assertion 覆盖率可以作为补充质量信号单独报告，但不能混入 PTW RTL code coverage headline。

## 5. PTW-only coverage hierarchy 配置

### 5.1 首选配置：实例树口径

建议新增临时或受控配置文件：

```text
mmu_verification/scripts/ptw_cov_hier.cfg
```

首选内容：

```text
+tree tb_top.u_dut.x_ct_mmu_ptw
-module mmu_sva
-module mmu_arb_sva
-module mmu_l2tlb_rrpv_sva
-module mmu_l2tlb_rrpv_wbuf_sva
-module mmu_l2tlb_mb_sva
-module mmu_plru_sva
-module mmu_dplru_sva
-module credit_sva
-module mmu_twu_sva
-module mmu_maee_twu_sva
-module mmu_pmp_twu_sva
-module mmu_sysmap_sva
-module mmu_ptw_lsu_protocol_sva
-module mmu_ptw_top_sva
-module mmu_pde_cache_sva
-module mmu_ptw_xbar_sva
-module mmu_twu_chk_sva
-module mmu_ptw_source_sva
```

该配置直接绑定 PTW 实例树，是最准确的 PTW-only scope。

### 5.2 备选配置：module 白名单口径

如果 VCS `-cm_hier` 不接受实例树路径，或者编译日志显示该实例树没有匹配对象，则切换到 module 白名单配置：

```text
+module ptw
+module ptw_mbuf
+module twu
+module PDE_cache
+module L1PDE_cache
+module L2PDE_cache
+module one_to_four_xbar
+module pplru
-module mmu_sva
-module mmu_arb_sva
-module mmu_l2tlb_rrpv_sva
-module mmu_l2tlb_rrpv_wbuf_sva
-module mmu_l2tlb_mb_sva
-module mmu_plru_sva
-module mmu_dplru_sva
-module credit_sva
-module mmu_twu_sva
-module mmu_maee_twu_sva
-module mmu_pmp_twu_sva
-module mmu_sysmap_sva
-module mmu_ptw_lsu_protocol_sva
-module mmu_ptw_top_sva
-module mmu_pde_cache_sva
-module mmu_ptw_xbar_sva
-module mmu_twu_chk_sva
-module mmu_ptw_source_sva
```

备选配置仍然必须通过 URG hierarchy/modlist 检查，确认 report 中没有非 PTW RTL module 被计入 headline。

## 6. 指标和达标标准

### 6.1 代码覆盖率指标

PTW code coverage 采集以下 VCS/URG metric：

- line
- condition
- branch
- fsm
- toggle

assertion coverage 单独报告，不计入 PTW code coverage headline。功能覆盖率和 scoreboard/SVA cover marker 也单独报告，不计入 headline。

### 6.2 headline 数值定义

首选 headline 计算方式为按覆盖对象数量加权：

```text
PTW_CODE_COVERAGE =
  (line_hit + condition_hit + branch_hit + fsm_hit + toggle_hit)
  /
  (line_total + condition_total + branch_total + fsm_total + toggle_total)
  * 100
```

如果 URG PTW-only report 已经提供明确的 total score，并且该 score 的 scope 已确认只包含 PTW RTL，则以 URG total score 为准。

如果 URG 文本报告只提供百分比，不提供 hit/total 数量，则可以临时输出百分比算术平均值，但必须标记为：

```text
headline_method=percent_average
```

最终 signoff 推荐使用 hit/total 加权值或 URG total score。

### 6.3 达标门槛

建议 PTW code coverage 门槛如下：

| Metric | Threshold |
| --- | ---: |
| headline | >= 99.0% |
| line | >= 99.5% |
| condition | >= 99.0% |
| branch | >= 99.0% |
| fsm | >= 99.0% |
| toggle | >= 98.0% |
| assertion | >= 100.0% 或已解释的 N/A |

如果某个 metric 在 PTW RTL 中没有适用对象，报告为 `N/A`，不能按 0% 处理。`N/A` metric 需要在最终 summary 中说明。

门槛判断必须同时满足：

- headline 达标；
- 各代码覆盖率分项达标；
- 未达标项有明确 hole analysis 和 waiver/修复闭环；
- 功能 signoff gate 保持 PASS。

### 6.4 覆盖率统计口径细则

PTW code coverage 的统计单元必须来自 PTW RTL scope 中的 URG code coverage 对象。统计时按以下规则处理：

| Metric | URG/VCS 名称 | 是否进入 headline | 统计对象 | 备注 |
| --- | --- | --- | --- | --- |
| line | line | 是 | 可执行语句/行 | 行覆盖率是基本门槛，低于 99.5% 必须分析 |
| condition | cond / condition | 是 | 条件表达式真/假组合 | Makefile 使用 `line+cond+fsm+tgl+branch+assert`，所以 parser 必须支持 condition |
| branch | branch | 是 | if/case/?: 等分支对象 | 与 condition 分开统计，不能互相替代 |
| fsm | fsm | 是，若 applicable | FSM state/transition | 如果 PTW scope 没有 URG 可识别 FSM，对该项报 N/A |
| toggle | tgl / toggle | 是 | RTL net/reg toggle | toggle 覆盖率对 tie-off、低功耗/clock gating、只读配置敏感 |
| assertion | assert / assertion | 否 | SVA assertion/cover | 单独报告，不进入 code headline |

`assertion` 不进入 headline 的原因：

- assertion coverage 是验证结构覆盖，不是 RTL code object；
- 当前 hierarchy 需要排除 SVA module，避免把 SVA 文件纳入 RTL code coverage；
- SVA cover marker 已由 PTW source signoff gate 独立检查。

### 6.5 hit/total、N/A 和 waiver 处理

每个 metric 都必须被解析为以下结构：

```json
{
  "name": "line",
  "hit": 1234,
  "total": 1240,
  "pct": 99.52,
  "status": "PASS",
  "source": "urgReport/dashboard.txt",
  "applicable": true
}
```

处理规则：

1. `total > 0`：`pct = hit / total * 100`。
2. `total == 0` 且 URG 明确表示无对象：`applicable=false`，报告为 `N/A`。
3. `total == 0` 但 URG 没有明确无对象说明：报告 `parse_error`，不能自动按 N/A 通过。
4. `hit > total`：报告 `parse_error`。
5. percentage-only 可用但 hit/total 不可用：保存 `pct`，`hit=null`，`total=null`，`headline_method=percent_average`。
6. 被 waiver 的未达标 metric 仍保留实际数值，`status=WAIVED`，不得把数值改写成 100%。

`N/A` 只能用于没有适用覆盖对象的 metric，例如没有 FSM 对象。不能把解析失败、scope 错误、URG 缺失、工具崩溃标成 N/A。

### 6.6 headline 计算优先级

headline 计算按以下优先级执行：

1. 如果 URG 提供 PTW-only scope 的 total score 且 report scope 已通过校验，记录：

   ```text
   headline_method=urg_total_score
   ```

2. 如果所有进入 headline 的 metric 都有 hit/total，使用加权算法：

   ```text
   headline_method=weighted_hit_total
   headline = sum(metric.hit) / sum(metric.total) * 100
   ```

   其中只统计 `applicable=true` 且进入 headline 的 metric，排除 assertion。

3. 如果只有百分比，没有 hit/total，使用百分比平均值：

   ```text
   headline_method=percent_average
   headline = average(line_pct, condition_pct, branch_pct, fsm_pct, toggle_pct)
   ```

   其中排除 `N/A` metric。该方法只能作为临时结果，最终 signoff 推荐补 parser 或导出格式拿到 hit/total。

4. 如果任何必要 metric 无法解析且没有明确 N/A 或 waiver，结果为：

   ```text
   status=FAIL reason=missing_metric
   ```

### 6.7 覆盖率结果可信度分级

最终 summary 必须给出结果可信度：

| Confidence | 条件 |
| --- | --- |
| `high` | PTW-only scope 校验通过，所有 code metric 都有 hit/total，headline 为 `urg_total_score` 或 `weighted_hit_total` |
| `medium` | PTW-only scope 校验通过，但某些 metric 只有 percentage-only，headline 为 `percent_average` |
| `low` | report scope、metric、parser 任一项存在不确定性；低可信结果不能作为 signoff PASS |

最终交付只接受 `confidence=high` 且 `profile=signoff` 的 `PASS`。`quick`、`default`、`full` 即使覆盖率数值达标，也应作为中间结果输出 `CONDITIONAL_PASS reason=non_signoff_profile`，除非项目 owner 明确把该 profile 定义为 signoff 等价 profile。

## 7. 运行前检查

### 7.1 环境检查

在 `mmu_verification` 目录执行：

```bash
make check_env
```

确认：

- VCS 可用；
- URG 可用；
- `MMU_RTL_ROOT`、`PROJECT_DIR` 等路径正确；
- `Files.f` 可以解析；
- 覆盖率相关目录可写。

### 7.2 测试注册检查

执行：

```bash
make list_tests
```

底层等价检查方式为：

```bash
python3 scripts/run_test.py --list
```

确认 PTW 覆盖率计划中使用的测试名均在 UVM test registry 中存在。至少需要覆盖以下 testlist：

- `simu/ptw_p0_smoke_list`
- `simu/ptw_p0_list`
- `simu/ptw_p1_list`
- `simu/ptw_p2_illegal_list`
- `simu/ptw_pde_pmpflg_list`
- `simu/ptw_random_list`
- `simu/ptw_consumer_evidence_list`
- `simu/mmu_ptw_lsu_protocol_list`
- `simu/mmu_v4_phase12_list`
- `simu/mmu_v4_phase13_list`
- `simu/mmu_v4_full_regression_list`

若发现未注册测试，必须先修正 test package include 或 testlist，再执行覆盖率。

## 8. 覆盖率执行前功能门禁

代码覆盖率只能在功能回归健康的前提下解释。因此覆盖率回归前先执行 PTW source-side signoff gate。

### 8.1 重新生成 PTW source signoff 日志

使用普通 `run_check` 模式生成 gate 所需日志，保留 PTW source marker：

```bash
make regress LIST=simu/ptw_p0_smoke_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_p0_smoke \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

make regress LIST=simu/ptw_p0_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_p0 \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

make regress LIST=simu/ptw_p1_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_p1 \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

make regress LIST=simu/ptw_pde_pmpflg_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_pde_pmpflg \
  REGRESS_SEEDS="606 707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

make regress LIST=simu/ptw_p2_illegal_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_p2_illegal \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

make regress LIST=simu/ptw_random_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_random \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

make regress LIST=simu/ptw_consumer_evidence_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_consumer \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0
```

### 8.2 执行 PTW signoff gate

根据现有 signoff 资料执行：

```bash
python3 scripts/ptw_stage8_signoff_gate.py \
  --log-dir output/regression/ptw_src_p0_smoke/logs \
  --log-dir output/regression/ptw_src_p0/logs \
  --log-dir output/regression/ptw_src_p1/logs \
  --log-dir output/regression/ptw_src_pde_pmpflg/logs \
  --log-dir output/regression/ptw_src_p2_illegal/logs \
  --log-dir output/regression/ptw_src_random/logs \
  --log-dir output/regression/ptw_src_consumer/logs \
  --closure-csv output/ptw_stage8_cov_collect/ptw_source_closure_matrix.csv \
  --closure-report output/ptw_stage8_cov_collect/ptw_source_coverage_report.md
```

要求：

- 所有 UVM test PASS；
- 无 UVM_ERROR/UVM_FATAL；
- `PTW_SOURCE_SB_SUMMARY` marker 完整；
- `PTW_SVA_COVER` marker 完整；
- PDE `pmpflg` cover marker 完整；
- closure matrix/report 与当前 RTL/testbench 状态一致。

该门禁 PASS 后再执行 code coverage。若该门禁 FAIL，停止 code coverage 解释，先修复功能闭合问题。

## 9. PTW code coverage 编译

### 9.1 建议输出目录

使用独立目录保存 PTW 覆盖率，避免污染已有全 MMU 覆盖率数据：

```bash
export PTW_COV_ROOT="$PWD/output/ptw_cov"
```

### 9.2 覆盖率编译命令

在 `mmu_verification` 目录执行：

```bash
make clean_cov \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp" \
  URG_REPORT_DIR="$PTW_COV_ROOT/urgReport" \
  URG_MERGED_DB="$PTW_COV_ROOT/merged_ptw.vdb" \
  URG_LOG="$PTW_COV_ROOT/urg_ptw.log"

make comp_all \
  COV_FORCE_REBUILD=1 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"
```

编译后检查：

- compile log 中没有 `cm_hier` 解析错误；
- compile baseline VDB 存在；
- PTW module 被纳入 coverage；
- SVA/testbench/非 PTW RTL 没有进入 PTW code coverage scope。

如果实例树配置没有生效，切换到 module 白名单配置并重新执行 `make comp_all`。

## 10. 覆盖率回归测试集

覆盖率回归分三层执行。所有 `run_cov` 必须串行：

```text
REGRESS_MODE=run_cov
REGRESS_JOBS=1
```

所有运行必须使用同一组 coverage 变量：

```bash
COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg"
COV_DIR="$PTW_COV_ROOT"
COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb"
COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb"
COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"
```

### 10.1 T1：PTW source directed closure

T1 用于覆盖 PTW source-side 关键架构路径、fault path、PDE cache path、pmpflg path 和随机 source 请求。

`ptw_p0_smoke_list` 作为功能 gate 和覆盖率环境 sanity 用例保留；最终 coverage aggregate 以 `ptw_p0_list` 为 P0 完整入口。如果确认 `ptw_p0_list` 已包含 smoke 用例，不要再用相同 seed 把 `ptw_p0_smoke_list` 重复写入同一个 aggregate VDB。

```bash
make regress LIST=simu/ptw_p0_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t1_p0 \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/ptw_p1_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t1_p1 \
  REGRESS_SEEDS="606 707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/ptw_pde_pmpflg_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t1_pde_pmpflg \
  REGRESS_SEEDS="606 707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/ptw_p2_illegal_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t1_p2_illegal \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/ptw_random_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t1_random \
  REGRESS_SEEDS="707 808 909" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"
```

### 10.2 T2：PTW consumer/protocol/phase12/phase13 coverage

T2 用于补齐 PTW 与 LSU protocol、TWU bypass、MAEE/PMP/SysMap consumer 场景的结构覆盖。

```bash
make regress LIST=simu/ptw_consumer_evidence_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t2_consumer \
  REGRESS_SEEDS="707" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/mmu_ptw_lsu_protocol_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t2_lsu_protocol \
  REGRESS_SEEDS="94101 94102 94103" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/mmu_v4_phase12_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t2_phase12 \
  REGRESS_SEEDS="95101 95102 95103" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"

make regress LIST=simu/mmu_v4_phase13_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t2_phase13 \
  REGRESS_SEEDS="96101 96102 96103" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"
```

### 10.3 T3：full regression 和 hole-fill

如果 T1+T2 后任一 metric 未达标，或者需要最终 signoff 级别证明，执行 full regression 覆盖率：

```bash
make regress LIST=simu/mmu_v4_full_regression_list \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=ptw_cov_t3_full \
  REGRESS_SEEDS="97101 97102 97103 97104 97105" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PTW_COV_ROOT/.simv_ptw.compile.stamp"
```

如果 full regression 后仍有覆盖率空洞，根据 URG hole report 选择性补跑定向测试。优先考虑以下 PTW 高价值场景：

- 4 TWU full wakeup/dense wakeup；
- PTW walk latency；
- reset during PTW walk；
- reset during response；
- MMU CSR PTW disable；
- satp hot-swap concurrent；
- high-frequency sfence；
- PDE cache clear/update/hit/miss；
- LSU grant/response backpressure；
- access/page fault corner；
- pmp/sysmap bypass 与 fault 组合；
- pmpflg update/clear 相关路径。

新增 hole-fill 测试必须进入独立 regression name，例如：

```text
ptw_cov_t4_holefill_<topic>
```

并记录测试名、seed、目标 hole、覆盖率变化。

## 11. URG 报告生成

所有 `run_cov` 完成后执行：

```bash
make cov \
  COV_DIR="$PTW_COV_ROOT" \
  COV_DB_DIR="$PTW_COV_ROOT/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PTW_COV_ROOT/simv_ptw.compile.vdb" \
  URG_REPORT_DIR="$PTW_COV_ROOT/urgReport" \
  URG_MERGED_DB="$PTW_COV_ROOT/merged_ptw.vdb" \
  URG_LOG="$PTW_COV_ROOT/urg_ptw.log"
```

要求生成：

- `$PTW_COV_ROOT/urgReport/dashboard.txt` 或等价 summary；
- `$PTW_COV_ROOT/urgReport/hierarchy.txt` 或 HTML hierarchy；
- `$PTW_COV_ROOT/urgReport/modlist.txt` 或 module summary；
- `$PTW_COV_ROOT/urg_ptw.log`；
- `$PTW_COV_ROOT/merged_ptw.vdb` 或等价 merged DB。

如果 `make cov` 的直接 URG flow 失败，允许使用 `scripts/run_urg_report.sh` 内部 fallback；但最终仍必须确认 report 是 PTW-only。

## 12. 数值提取和报告生成

### 12.1 提取规则

建议新增或临时使用一个解析脚本，例如：

```text
scripts/ptw_extract_code_coverage.py
```

输入：

```bash
python3 scripts/ptw_extract_code_coverage.py \
  --urg-report "$PTW_COV_ROOT/urgReport" \
  --scope ptw_core \
  --hier-cfg "$PWD/scripts/ptw_cov_hier.cfg" \
  --out-md "$PTW_COV_ROOT/ptw_code_coverage_summary.md" \
  --out-json "$PTW_COV_ROOT/ptw_code_coverage_summary.json"
```

解析脚本必须执行以下检查：

- URG report 目录存在；
- report scope 只包含 PTW RTL module 或 PTW instance tree；
- 非 PTW module 未进入 headline；
- line/condition/branch/fsm/toggle 分项可以被解析；
- hit/total 数量可用时用加权 headline；
- hit/total 不可用时标记 `headline_method=percent_average`；
- 低于门槛的 metric 输出 top uncovered holes；
- 输出 `PASS`、`FAIL` 或 `CONDITIONAL_PASS` status，并记录 `reason`、`confidence` 和 functional gate 状态。

### 12.2 JSON 报告字段

JSON 至少包含：

```json
{
  "status": "PASS",
  "reason": "all_thresholds_met",
  "confidence": "high",
  "profile": "signoff",
  "scope": "ptw_core",
  "hier_cfg": "scripts/ptw_cov_hier.cfg",
  "cov_db": "output/ptw_cov/simv_ptw.vdb",
  "urg_report": "output/ptw_cov/urgReport",
  "headline_method": "weighted_hit_total",
  "ptw_code_coverage": 99.23,
  "line_pct": 99.71,
  "condition_pct": 99.12,
  "branch_pct": 99.06,
  "fsm_pct": 100.0,
  "toggle_pct": 98.42,
  "assertion_pct": 100.0,
  "thresholds": {
    "headline": 99.0,
    "line": 99.5,
    "condition": 99.0,
    "branch": 99.0,
    "fsm": 99.0,
    "toggle": 98.0,
    "assertion": 100.0
  },
  "threshold_status": "PASS",
  "functional_gate": {
    "status": "PASS",
    "mode": "run",
    "log_dirs": ["output/regression/ptw_src_p0/logs"],
    "closure_report": "output/ptw_stage8_cov_collect/ptw_source_coverage_report.md"
  },
  "run_manifest": {
    "profile": "signoff",
    "runs": [
      {
        "list": "simu/ptw_code_coverage_list",
        "seeds": ["606", "707", "808", "909"],
        "regress_names": [
          "ptw_cov_signoff_ptw_code_coverage_list_606",
          "ptw_cov_signoff_ptw_code_coverage_list_707",
          "ptw_cov_signoff_ptw_code_coverage_list_808",
          "ptw_cov_signoff_ptw_code_coverage_list_909"
        ]
      }
    ],
    "deduped_entries": []
  },
  "holes_top20": [],
  "waivers": []
}
```

上例中的数值只是格式示例，不能作为实际结果。

### 12.3 Markdown 报告内容

Markdown summary 至少包含：

- 执行日期；
- git commit/hash；
- PTW coverage hierarchy 配置摘要；
- 覆盖率 VDB/report 路径；
- 测试列表、seed、PASS/FAIL summary；
- line/condition/branch/fsm/toggle/assertion 分项；
- headline PTW code coverage；
- threshold status；
- top uncovered holes；
- waiver 列表；
- 下一步动作。

### 12.4 URG 文件解析优先级

不同 URG 版本的 report 文件布局可能不同，parser 不能只绑定单一文件名。解析顺序如下：

1. 首选文本 summary：
   - `urgReport/dashboard.txt`
   - `urgReport/hierarchy.txt`
   - `urgReport/modlist.txt`
   - `urgReport/groups.txt`
   - `urgReport/tests.txt`
2. 次选 HTML：
   - `urgReport/dashboard.html`
   - `urgReport/hierarchy.html`
   - `urgReport/modlist.html`
   - `urgReport/**/*.html`
3. 最后扫描所有 `.txt`、`.html`、`.htm` 文件，寻找 metric 表格。

文本解析规则：

- 先移除 HTML tag、实体转义和多余空白；
- metric alias 大小写不敏感；
- `cond` 和 `condition` 视为同一个 metric；
- `tgl` 和 `toggle` 视为同一个 metric；
- 支持以下形式：

```text
Line    1234/1240    99.52%
LINE    Covered 1234 Total 1240 Score 99.52
line    99.52%
```

HTML 解析规则：

- 优先解析 table row，而不是对整页做粗暴正则；
- `<th>` 或第一列含 metric 名；
- 同一 row 内寻找 percentage 和 hit/total；
- 如果 HTML 表格结构复杂，允许降级为 sanitize 后的文本解析，但必须记录 `parser_mode=html_sanitized_text`。

### 12.5 scope 校验算法

parser 必须在读取 metric 前先校验 scope。建议算法：

1. 从 `hierarchy.txt/html`、`modlist.txt/html`、`dashboard.txt/html` 收集 module/hierarchy names。
2. 如果能看到实例路径，必须存在：

   ```text
   tb_top.u_dut.x_ct_mmu_ptw
   ```

   或该路径下的子实例。

3. 如果只能看到 module 名，必须全部属于白名单：

   ```text
   ptw
   ptw_mbuf
   twu
   PDE_cache
   L1PDE_cache
   L2PDE_cache
   one_to_four_xbar
   pplru
   ```

4. 如果发现以下 module 被计入 metric 表，scope 失败：

   ```text
   ct_mmu_top
   l1dtlb
   l1itlb
   l2tlb
   mmu_sva
   mmu_ptw_top_sva
   mmu_pde_cache_sva
   mmu_ptw_xbar_sva
   mmu_twu_chk_sva
   mmu_ptw_source_sva
   mmu_ptw_lsu_protocol_sva
   mmu_pmp_twu_sva
   mmu_sysmap_sva
   ```

5. `pmp`、`sysmap`、`l2tlb` 字样只出现在 test name、log path、profile name 中时不能判 scope 失败；只有它们作为 report module/hierarchy scope 出现才失败。

scope 校验结果写入 JSON：

```json
{
  "scope_check": {
    "status": "PASS",
    "method": "instance_tree",
    "required_root": "tb_top.u_dut.x_ct_mmu_ptw",
    "allowed_modules": ["ptw", "ptw_mbuf", "twu", "PDE_cache", "L1PDE_cache", "L2PDE_cache", "one_to_four_xbar", "pplru"],
    "rejected_modules": [],
    "source_files": ["urgReport/hierarchy.txt", "urgReport/modlist.txt"]
  }
}
```

### 12.6 uncovered holes 提取

如果任一 metric 未达标，summary 必须输出 top holes。提取优先级：

1. URG text hole/uncovered report；
2. URG HTML detail 页面；
3. hierarchy/module summary 中最低覆盖率 module；
4. 如果没有详细 hole 文件，至少输出低覆盖 module/metric。

hole JSON 结构：

```json
{
  "metric": "branch",
  "module": "twu",
  "file": "mmu/rtl/twu.sv",
  "line": 512,
  "object": "if pmp_acc_err && page_fault",
  "hit": 0,
  "total": 1,
  "pct": 0.0,
  "classification": "unclassified",
  "action": "analyze"
}
```

如果无法得到 line/object，仍要输出 module-level hole：

```json
{
  "metric": "toggle",
  "module": "ptw_mbuf",
  "file": null,
  "line": null,
  "object": "module-level low toggle coverage",
  "hit": null,
  "total": null,
  "pct": 94.2,
  "classification": "module_low_coverage",
  "action": "inspect_urg_html"
}
```

### 12.7 JSON schema 完整要求

最终 JSON 必须可被 CI 直接读取。建议顶层结构：

```json
{
  "schema_version": "ptw_code_coverage_v1",
  "status": "PASS",
  "reason": "all_thresholds_met",
  "confidence": "high",
  "generated_at": "2026-06-03T00:00:00+08:00",
  "git_commit": "<hash>",
  "scope": "ptw_core",
  "scope_check": {},
  "functional_gate": {
    "status": "PASS",
    "mode": "run",
    "evidence": {
      "log_dirs": [
        "output/regression/ptw_src_p0_smoke/logs",
        "output/regression/ptw_src_p0/logs",
        "output/regression/ptw_src_p1/logs",
        "output/regression/ptw_src_pde_pmpflg/logs",
        "output/regression/ptw_src_p2_illegal/logs",
        "output/regression/ptw_src_random/logs",
        "output/regression/ptw_src_consumer/logs"
      ],
      "closure_report": "output/ptw_stage8_cov_collect/ptw_source_coverage_report.md"
    }
  },
  "headline_method": "weighted_hit_total",
  "ptw_code_coverage": 99.23,
  "metrics": {
    "line": {"hit": 1234, "total": 1240, "pct": 99.52, "status": "PASS", "applicable": true, "threshold": 99.5},
    "condition": {"hit": 800, "total": 808, "pct": 99.01, "status": "PASS", "applicable": true, "threshold": 99.0},
    "branch": {"hit": 610, "total": 616, "pct": 99.03, "status": "PASS", "applicable": true, "threshold": 99.0},
    "fsm": {"hit": 20, "total": 20, "pct": 100.0, "status": "PASS", "applicable": true, "threshold": 99.0},
    "toggle": {"hit": 4210, "total": 4275, "pct": 98.48, "status": "PASS", "applicable": true, "threshold": 98.0},
    "assertion": {"hit": 50, "total": 50, "pct": 100.0, "status": "PASS", "applicable": true, "threshold": 100.0, "included_in_headline": false}
  },
  "paths": {
    "urg_report": "output/ptw_cov/urgReport",
    "cov_db": "output/ptw_cov/simv_ptw.vdb",
    "merged_db": "output/ptw_cov/merged_ptw.vdb",
    "hier_cfg": "scripts/ptw_cov_hier.cfg"
  },
  "run_manifest": {
    "profile": "signoff",
    "runs": [
      {
        "list": "simu/ptw_code_coverage_list",
        "seeds": ["606", "707", "808", "909"],
        "regress_names": [
          "ptw_cov_signoff_ptw_code_coverage_list_606",
          "ptw_cov_signoff_ptw_code_coverage_list_707",
          "ptw_cov_signoff_ptw_code_coverage_list_808",
          "ptw_cov_signoff_ptw_code_coverage_list_909"
        ]
      }
    ],
    "deduped_entries": []
  },
  "holes_top20": [],
  "waivers": []
}
```

字段规则：

- `status` 只能是 `PASS`、`FAIL`、`CONDITIONAL_PASS`。
- `reason` 必须是稳定字符串，例如 `all_thresholds_met`、`non_signoff_profile`、`scope_invalid`、`missing_metric`、`threshold_fail`、`regression_fail`、`urg_fail`、`functional_gate_fail`、`functional_gate_skipped`、`duplicate_cov_tag`、`confidence_low`、`conditional_pass_only`。
- `ptw_code_coverage` 为数字或 `null`。
- metric 为 N/A 时：`applicable=false`、`pct=null`、`status=N/A`、`na_reason` 必填。
- `functional_gate.status` 只能是 `PASS`、`FAIL`、`SKIPPED`、`REUSED`；`REUSED` 必须提供 evidence 路径和生成时间。
- `run_manifest.runs[]` 是唯一允许的 list/seed 展开结构；禁止同时使用旧式顶层 `lists` 和 `seeds`，防止把 full regression 误乘 PTW source seed。
- `waivers` 为空时写 `[]`，不能省略。

### 12.8 Markdown summary 固定模板

`ptw_code_coverage_summary.md` 建议固定结构：

```markdown
# PTW Code Coverage Summary

## Result

PTW_CODE_COVERAGE_RESULT status=<PASS|FAIL|CONDITIONAL_PASS> scope=ptw_core headline=99.23 ...

## Scope

- Hier cfg: scripts/ptw_cov_hier.cfg
- Scope method: instance_tree
- Root: tb_top.u_dut.x_ct_mmu_ptw
- Rejected modules: none

## Metrics

| Metric | Hit | Total | Pct | Threshold | Status | Included In Headline |
| --- | ---: | ---: | ---: | ---: | --- | --- |

## Runs

| List | Seeds | Regress Name | Summary | Status |
| --- | --- | --- | --- | --- |

## Functional Gate

| Mode | Status | Evidence | Notes |
| --- | --- | --- | --- |

## Holes

| Metric | Module | File | Line | Object | Action |
| --- | --- | --- | ---: | --- | --- |

## Waivers

| ID | Metric | Module | File | Line | Reason | Approval |
| --- | --- | --- | --- | ---: | --- | --- |
```

固定模板可以让后续 review 和 CI diff 更稳定。

## 13. 覆盖率空洞分析规则

对未覆盖对象按以下类别处理：

| 类别 | 处理方式 |
| --- | --- |
| stimulus gap | 增加或补跑定向测试，直到覆盖或证明不可达 |
| observation/probe gap | 修正 testbench/probe/monitor，不把 TB 缺口当作 RTL waiver |
| spec unreachable | 建立精确 waiver，关联 spec/signoff 条目 |
| dead/debug RTL | RTL owner review 后决定删除、保留并 waiver，或新增测试 |
| tool/report artifact | 重新生成 VDB/URG 或调整解析脚本 |

waiver 要求：

- 精确到 file/module/line/branch/toggle/FSM state；
- 必须说明不可达原因；
- 必须关联 spec、设计限制或 signoff ID；
- 禁止对整个 module 或整个 PTW scope 做粗粒度 waiver。

特别注意：现有环境中 `pmp_regs_update` 在 DUT 顶层被绑到 `1'b0`。如果该行为导致 PDE `pmpflg` update/clear 相关代码覆盖率空洞，不能直接隐藏；需要关联已有 PTW closure gap 或补充设计说明，再决定是补测试、修环境还是 waiver。

## 14. 判定标准

PTW 代码覆盖率最终 `PASS` 必须同时满足：

1. 执行 profile 为 `signoff`，或 summary 明确声明当前 profile 被 owner 批准为 signoff 等价 profile。
2. PTW source-side signoff gate `PASS`，或 `REUSED` 且 evidence 完整、commit/timestamp 可审计。
3. 所有 coverage regression summary PASS。
4. 覆盖率运行日志无 UVM_ERROR/UVM_FATAL、simulation crash、license failure、timeout。
5. `run_cov` 全程串行，聚合 VDB 未被并发写坏。
6. URG report 存在且确认为 PTW-only scope。
7. parser confidence 为 `high`。
8. headline >= 99.0%。
9. line >= 99.5%。
10. condition >= 99.0%。
11. branch >= 99.0%。
12. fsm >= 99.0% 或 N/A 且说明原因。
13. toggle >= 98.0%。
14. assertion coverage 100.0% 或 N/A 且说明原因。
15. 所有未达标或被 waiver 的 hole 均有审计记录。

任一条件不满足，最终结果为 `FAIL` 或 `CONDITIONAL_PASS`，不能写成 `PASS`。其中覆盖率数值已达标但 profile 不是 signoff、functional gate 被 skip、parser 只有 medium confidence、或 waiver 只是临时/待审批状态时，应优先输出 `CONDITIONAL_PASS` 并写清原因。精确且正式批准的 waiver 可以进入最终 `PASS`，但 summary 必须列出 waiver ID、对象、原因和 approval。

## 15. 验证环境需要增加和修改的内容

用户后续希望“增加一个测试，跑完后输出 PTW 代码覆盖率”。这里的“测试”必须定义为一个 coverage regression 入口，而不是单个 UVM `TEST_NAME`。

原因是 VCS code coverage 的最终数值不是 DUT 仿真过程中由 UVM test 直接计算出来的，而是仿真结束后由 VCS VDB + URG merge/report + report parser 生成。因此正确实现方式是新增一个一键入口，例如：

```bash
make ptw_code_cov
```

或：

```bash
python3 scripts/run_ptw_code_coverage.py --profile signoff
```

该入口内部完成编译、串行 run_cov、URG 生成、PTW-only scope 校验和数值解析，最终在 stdout 和 summary 文件中打印 `PTW_CODE_COVERAGE_RESULT`。

### 15.1 必须新增：PTW-only coverage hierarchy

新增文件：

```text
mmu_verification/scripts/ptw_cov_hier.cfg
```

首选内容为：

```text
+tree tb_top.u_dut.x_ct_mmu_ptw
-module mmu_sva
-module mmu_arb_sva
-module mmu_l2tlb_rrpv_sva
-module mmu_l2tlb_rrpv_wbuf_sva
-module mmu_l2tlb_mb_sva
-module mmu_plru_sva
-module mmu_dplru_sva
-module credit_sva
-module mmu_twu_sva
-module mmu_maee_twu_sva
-module mmu_pmp_twu_sva
-module mmu_sysmap_sva
-module mmu_ptw_lsu_protocol_sva
-module mmu_ptw_top_sva
-module mmu_pde_cache_sva
-module mmu_ptw_xbar_sva
-module mmu_twu_chk_sva
-module mmu_ptw_source_sva
```

如果 VCS 不接受该实例树，脚本必须自动或人工切换为 module 白名单配置。切换不能静默发生，必须在 log 和 summary 中记录：

```text
scope_method=module_whitelist
scope_reason=instance_tree_not_accepted_by_cm_hier
```

### 15.2 必须新增：PTW coverage regression list

新增文件：

```text
mmu_verification/simu/ptw_code_coverage_list
```

该列表作为一键 coverage test 的默认 profile，目标是在运行时间和覆盖率质量之间取得平衡。建议初版内容如下：

```text
# PTW code coverage default regression list
# Scope is controlled by scripts/ptw_cov_hier.cfg.
# Source plusargs are retained for source marker visibility but do not affect RTL code coverage scope.

test_ptw_p0_pte_layout_matrix +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_p0_type_pfu_fault_matrix +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_p0_permission_matrix +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_p0_pde_mbuf_pmp_matrix +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_p0_maee_sysmap_matrix +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_p0_flow_trace_umbrella +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_l1_pmp_tag_deny_fst_fault_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_l1_pmp_tag_allow_reuse_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_l2_pmp_l1_deny_accerr_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_pmpflg_propagation_update_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_accerr_priority_type_id_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_l2_accerr_valid_gate_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_pmp_clear_repopulate_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pde_satp_old_walk_reupdate_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_pmp_cfg_clear_no_flush_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_asid_refill_current_sample_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_maee_mid_sysmap_change_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_random_pte_perm_cross_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_same_id_no_reuse_constraint_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_bare_mode_no_request_constraint_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_ptw_p2_illegal_constraint_matrix +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pmbuf_serial_outstanding_001
test_pmbuf_addr_stable_001
test_pmbuf_no_tag_001
test_pmbuf_inorder_resp_001
test_pmbuf_ptr_hold_001
test_mmu_ptw_ready_all_mask_low
test_mmu_ptw_ready_one_unblock
test_mmu_ptw_ready_l2tlb_stall
test_mmu_twu_idle_implies_no_mask
test_mmu_pde_cache_hit_l3_skip_thd
test_mmu_pde_cache_hit_l2_skip_scd
test_mmu_pde_cache_full_miss_full_ptw
test_mmu_twu_pgflt_bypass_arb
test_mmu_twu_accerr_bypass_arb
test_mmu_twu_except_conflict_pgflt_accflt
test_mmu_mbuf_ready_gate_no_early_vld
test_mmu_mbuf_have_no_resend
test_mmu_mbuf_multi_twu_independent_ready
test_mmu_arb_grant_onehot_check
test_mmu_arb_refill_except_priority
test_mmu_arb_multi_twu_fairness
test_mmu_arb_vpn_match_tag_din
test_mmu_arb_pgs_bank_select
test_ptw_pmp_before_lsu
test_ptw_pmp_deny_stop
test_ptw_pmp_pa_1g
test_ptw_pmp_pa_2m
test_ptw_pmp_pa_4k
test_ptw_pmp_wait_no_lsu
test_ptw_pmp_pa_zero
test_ptw_pmp_deny_accflt
test_ptw_pmp_deny_no_refill
test_ptw_pmp_mmode_l0
test_ptw_pmp_fetch_zero
test_ptw_pmp_port_map_concurrent
test_sysmap_phase13_flg_refill_region0
test_sysmap_phase13_flg_refill_region7
test_sysmap_phase13_cross_1g_degrade
test_sysmap_phase13_cross_2m_degrade
test_sysmap_phase13_no_cross_no_degrade
test_sysmap_phase13_pa_align_1g
test_sysmap_phase13_pa_align_2m_4k
test_sysmap_phase13_4twu_concurrent
test_sysmap_phase13_default_flag
test_mmu_l1dtlb_dtlb_refill_001
test_mmu_l1dtlb_dtlb_mb_pgflt_001
test_mmu_l1dtlb_dtlb_access_fault_source_parity_001
test_mmu_l1dtlb_dtlb_refill_stale_id_001
test_mmu_l1dtlb_dtlb_sysmap_001
test_mmu_l1itlb_itlb_pgflt_001
test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior
```

说明：

- 该 list 合并了 PTW source closure、PDE pmpflg、PTW-LSU protocol、Phase12 PTW-ready/TWU bypass、Phase13 PMP/SysMap 和 consumer evidence。
- 默认 list 不直接包含全部 `mmu_v4_full_regression_list`，避免“一键测试”运行时间过长。
- 如果该默认 list 后覆盖率未达标，再由脚本进入 `--profile full` 或 `--profile signoff`，追加 `simu/mmu_v4_full_regression_list` 和 hole-fill tests。
- list 中保留少量 P2 illegal guard，是为了观察非法约束相关 RTL guard/tie-off 行为；若它们造成不稳定或无意义覆盖，应从默认 list 移至 `ptw_code_coverage_illegal_list`。

### 15.3 建议新增：coverage profile 文件

新增文件：

```text
mmu_verification/scripts/ptw_code_coverage_profiles.json
```

建议内容：

```json
{
  "quick": {
    "runs": [
      {"list": "simu/ptw_p0_smoke_list", "seeds": ["606"]},
      {"list": "simu/mmu_ptw_lsu_protocol_list", "seeds": ["94101"]}
    ],
    "purpose": "fast environment sanity only; not signoff"
  },
  "default": {
    "runs": [
      {"list": "simu/ptw_code_coverage_list", "seeds": ["606", "707"]}
    ],
    "purpose": "default PTW code coverage measurement"
  },
  "full": {
    "runs": [
      {"list": "simu/ptw_code_coverage_list", "seeds": ["606", "707", "808", "909"]},
      {"list": "simu/mmu_v4_full_regression_list", "seeds": ["97101", "97102", "97103"]}
    ],
    "purpose": "expanded PTW code coverage measurement after default holes"
  },
  "signoff": {
    "runs": [
      {"list": "simu/ptw_code_coverage_list", "seeds": ["606", "707", "808", "909"]},
      {"list": "simu/mmu_v4_full_regression_list", "seeds": ["97101", "97102", "97103", "97104", "97105"]}
    ],
    "purpose": "signoff-level PTW code coverage measurement"
  }
}
```

profile 规则：

- `quick` 只用于检查编译、run_cov、URG、parser 是否通；
- `default` 是用户所说“跑完后输出 PTW 覆盖率”的常规入口；
- `full` 用于 default 未达标后的扩展覆盖率闭合，不一定达到最终 signoff seed 深度；
- `signoff` 用于最终交付或 default 未达标后的完整覆盖率闭合；
- profile 中每个 run group 的 list/seeds 必须在 summary 里记录；
- 使用现有 `make regress REGRESS_MODE=run_cov` flow 时，`COV_TAG` 默认来自 `$(TEST_NAME)_$(SEED)`，因此 runner 必须按 `(test_name, seed)` 做唯一性检查；
- 如果同一个 `(test_name, seed)` 在多个 list 中重复出现且 plusargs 相同，runner 应去重并在 manifest 记录；
- 如果同一个 `(test_name, seed)` 需要用不同 plusargs 重复运行，默认 `make regress` flow 不满足唯一 `COV_TAG` 要求，runner 必须报 `duplicate_cov_tag`，除非已经实现 per-run `COV_TAG` 传递。

profile 不使用单一全局 seed 列表，是为了避免把 `mmu_v4_full_regression_list` 乘上 PTW source 的 606/707/808/909 seed，导致运行成本失控。每个 run group 必须显式声明 seeds。

### 15.4 必须新增：PTW code coverage 解析脚本

新增文件：

```text
mmu_verification/scripts/ptw_extract_code_coverage.py
```

职责：

1. 读取 URG report 目录。
2. 解析 line、condition、branch、fsm、toggle、assertion 分项。
3. 检查 report hierarchy/module list，只允许 PTW RTL scope。
4. 计算 `PTW_CODE_COVERAGE` headline。
5. 生成 markdown 和 JSON summary。
6. stdout 打印一行机器可读结果。

最低参数：

```bash
python3 scripts/ptw_extract_code_coverage.py \
  --urg-report output/ptw_cov/urgReport \
  --hier-cfg scripts/ptw_cov_hier.cfg \
  --cov-db output/ptw_cov/simv_ptw.vdb \
  --out-md output/ptw_cov/ptw_code_coverage_summary.md \
  --out-json output/ptw_cov/ptw_code_coverage_summary.json \
  --line-threshold 99.5 \
  --condition-threshold 99.0 \
  --branch-threshold 99.0 \
  --fsm-threshold 99.0 \
  --toggle-threshold 98.0 \
  --headline-threshold 99.0
```

scope 校验白名单：

```text
ptw
ptw_mbuf
twu
PDE_cache
L1PDE_cache
L2PDE_cache
one_to_four_xbar
pplru
```

scope 校验黑名单：

```text
tb_top
ct_mmu_top
mmu_sva
mmu_ptw_top_sva
mmu_pde_cache_sva
mmu_ptw_xbar_sva
mmu_twu_chk_sva
mmu_ptw_source_sva
mmu_ptw_lsu_protocol_sva
l1dtlb
l1itlb
l2tlb
pmp
sysmap
```

黑名单检查必须基于 module/hierarchy context 处理，不能因为测试名或路径字符串中出现 `pmp`/`sysmap` 就误判。真正需要拒绝的是 report scope 中的非 PTW RTL module。

stdout 必须输出：

```text
PTW_CODE_COVERAGE_RESULT status=<PASS|FAIL|CONDITIONAL_PASS> scope=ptw_core headline=<xx.xx> line=<xx.xx|N/A> condition=<xx.xx|N/A> branch=<xx.xx|N/A> fsm=<xx.xx|N/A> toggle=<xx.xx|N/A> assertion=<xx.xx|N/A> report=<path> cov_db=<path>
```

如果解析失败：

```text
PTW_CODE_COVERAGE_RESULT status=FAIL reason=<parse_error|scope_invalid|missing_metric|threshold_fail|ambiguous_metric>
```

#### 15.4.1 解析脚本函数级设计

`ptw_extract_code_coverage.py` 建议按以下函数组织：

```text
parse_args()
load_text_files(report_dir) -> list[ReportFile]
sanitize_html(text) -> str
discover_scope(report_files) -> ScopeInfo
check_scope(scope_info, allowed_modules, denied_modules) -> ScopeCheck
extract_metric_candidates(report_files) -> list[MetricCandidate]
select_metric(candidates, metric_name) -> MetricResult
compute_headline(metrics, preferred_urg_total) -> HeadlineResult
extract_holes(report_files, metrics) -> list[Hole]
evaluate_thresholds(metrics, headline, thresholds) -> Verdict
write_json(result, out_json)
write_markdown(result, out_md)
print_result_line(result)
main()
```

关键实现要求：

- `load_text_files()` 只读取 report 目录内文件，拒绝跟随指向目录外的 symlink；
- `sanitize_html()` 使用 Python 标准库 `html.unescape` 和正则去 tag 即可，不引入额外依赖；
- `discover_scope()` 必须优先读取 hierarchy/modlist，再读 dashboard；
- `select_metric()` 遇到多个候选时优先选择 scope 更具体、带 hit/total、来源更可信的候选；
- `compute_headline()` 必须保存参与计算的 metric 列表，便于审计；
- `write_json()` 必须使用 `sort_keys=True` 和稳定缩进，便于 diff；
- `print_result_line()` 必须是脚本最后一个主要输出，便于 CI `tail -1` 或 grep。

#### 15.4.2 metric 候选选择规则

同一个 metric 可能在 dashboard、hierarchy、module detail 中多次出现。选择规则：

1. scope 精确匹配 `tb_top.u_dut.x_ct_mmu_ptw` 的候选优先；
2. module 白名单聚合候选优先于全 report total；
3. 同时有 hit/total 和 percentage 的候选优先；
4. 文本 report 优先于 HTML sanitize fallback；
5. 如果多个候选数值冲突超过 0.01%，报告 `ambiguous_metric`，不要任选一个。

冲突示例：

```text
dashboard.txt: line=99.70
modlist.html: line=96.10
```

如果二者都声称是 PTW total，但数值不同，说明 scope 或 parser 有问题，结果必须 FAIL。

#### 15.4.3 解析脚本单元测试建议

新增目录：

```text
mmu_verification/scripts/tests/ptw_cov_parser/
```

至少准备以下最小样例：

- `dashboard_hit_total.txt`：包含 line/cond/branch/fsm/toggle hit/total；
- `dashboard_percent_only.txt`：只有百分比；
- `hier_scope_pass.txt`：只含 PTW module；
- `hier_scope_fail_l2tlb.txt`：含 L2TLB module，期望 scope fail；
- `metric_conflict.txt`：同一 metric 两个冲突数值，期望 fail；
- `metric_na_fsm.txt`：FSM total=0 且明确无 FSM，期望 N/A；
- `holes_branch_twu.txt`：包含 branch uncovered hole，期望 holes_top20 非空。

建议测试命令：

```bash
python3 -m unittest discover -s scripts/tests -p 'test_ptw_cov_*.py'
```

这些 parser 测试不依赖 VCS license，应作为日常 CI 的轻量检查。

### 15.5 必须新增：一键运行脚本

新增文件：

```text
mmu_verification/scripts/run_ptw_code_coverage.py
```

该脚本是“新增一个测试，跑完输出 PTW 代码覆盖率”的核心入口。它不应重写 Makefile 的编译/运行逻辑，而是编排现有目标：

1. 环境检查：`make check_env`。
2. 测试注册检查：`make list_tests` 或 `python3 scripts/run_test.py --list`。
3. 创建/检查 `scripts/ptw_cov_hier.cfg`。
4. 根据 profile 选择 run groups。
5. 运行或检查 PTW source functional gate。
6. 清理 PTW coverage 输出目录。
7. `make comp_all COV_FORCE_REBUILD=1 ...`。
8. 串行执行 `make regress REGRESS_MODE=run_cov REGRESS_JOBS=1 ...`。
9. `make cov ...` 生成 URG。
10. 调用 `scripts/ptw_extract_code_coverage.py`。
11. 把最终结果打印到 stdout，并写入 `output/ptw_cov/ptw_code_coverage_summary.md/json`。

建议命令：

```bash
python3 scripts/run_ptw_code_coverage.py \
  --profile default \
  --cov-root output/ptw_cov \
  --hier-cfg scripts/ptw_cov_hier.cfg \
  --jobs 1
```

脚本必须拒绝以下配置：

- `--jobs` 不是 1；
- `REGRESS_MODE` 不是 `run_cov`；
- `COV_HIER_CFG` 不是 PTW 专用配置；
- URG report scope 非 PTW-only；
- 覆盖率 compile baseline 不存在或为空；
- 任何 coverage log 出现 crash/license/fatal；
- regression summary effective pass rate 小于 100%。

脚本建议输出目录结构：

```text
output/ptw_cov/
  run_ptw_code_coverage.log
  ptw_cov_manifest.json
  simv_ptw.vdb
  simv_ptw.compile.vdb
  merged_ptw.vdb
  urgReport/
  ptw_code_coverage_summary.md
  ptw_code_coverage_summary.json
```

`ptw_cov_manifest.json` 至少记录：

```json
{
  "profile": "default",
  "runs": [
    {
      "list": "simu/ptw_code_coverage_list",
      "seeds": ["606", "707"],
      "regress_names": [
        "ptw_cov_default_ptw_code_coverage_list_606",
        "ptw_cov_default_ptw_code_coverage_list_707"
      ]
    }
  ],
  "cov_hier_cfg": "scripts/ptw_cov_hier.cfg",
  "cov_root": "output/ptw_cov",
  "git_commit": "<hash>",
  "start_time": "<timestamp>",
  "end_time": "<timestamp>"
}
```

#### 15.5.1 runner 参数设计

`run_ptw_code_coverage.py` 建议支持：

```text
--profile <quick|default|full|signoff>
--profile-file scripts/ptw_code_coverage_profiles.json
--cov-root output/ptw_cov
--hier-cfg scripts/ptw_cov_hier.cfg
--jobs 1
--force-rebuild
--functional-gate-mode <run|reuse|skip>
--functional-gate-evidence <path-to-json-or-md>
--skip-functional-gate
--skip-compile
--skip-run
--skip-urg
--parse-only
--keep-going-on-regress-fail
--timeout 10000000
--verbosity UVM_MEDIUM
--uvm-err-only 0
--extra-plus-args "<args>"
```

默认值：

```text
profile=default
jobs=1
force_rebuild=true
functional_gate_mode=run
skip_compile=false
skip_run=false
skip_urg=false
parse_only=false
uvm_err_only=0
verbosity=UVM_MEDIUM
```

使用约束：

- `--parse-only` 只允许在 `urgReport` 已存在时使用；
- `--skip-run` 必须要求 VDB 已存在且非空；
- `--keep-going-on-regress-fail` 只用于 debug，最终 signoff 禁止；
- `--skip-functional-gate` 等价于 `--functional-gate-mode skip`，只用于快速调试，最终 summary 必须记录 `functional_gate.status=SKIPPED` 且 status 不能是 signoff PASS；
- `--functional-gate-mode run` 是默认模式，runner 必须重新生成第 8 节中的 `run_check` 日志并调用 `ptw_stage8_signoff_gate.py`；
- `--functional-gate-mode reuse` 只允许在 `--functional-gate-evidence` 指向已有通过证据时使用，证据必须记录 log dirs、closure report、git commit、生成时间和 gate 脚本命令；
- `--functional-gate-mode skip` 时，如果 profile 是 `signoff`，最终状态只能是 `CONDITIONAL_PASS` 或 `FAIL`；如果 profile 是 `quick/default/full`，也必须在 result line 中写 `functional_gate=SKIPPED`。

功能 gate 与 coverage run 必须隔离：

- 功能 gate 使用 `REGRESS_MODE=run_check`，日志名为 `${test}_${seed}.log`；
- coverage run 使用 `REGRESS_MODE=run_cov`，日志名为 `${test}_${seed}_cov.log`；
- `ptw_stage8_signoff_gate.py` 只能检查 `run_check` 日志，不能检查 `_cov.log`；
- 如果用户传 `--skip-functional-gate`，最终 JSON 中必须记录 `functional_gate.status=SKIPPED`；
- `profile=signoff` 且 functional gate 被 skip 时，整体 `status` 不能为 `PASS`，只能是 `CONDITIONAL_PASS` 或 `FAIL`。

functional gate 命令模板：

```bash
make regress LIST=simu/ptw_p0_list \
  REGRESS_MODE=run_check \
  REGRESS_NAME=ptw_src_p0 \
  REGRESS_SEEDS="606" \
  REGRESS_JOBS=1 \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0

python3 scripts/ptw_stage8_signoff_gate.py \
  --log-dir output/regression/ptw_src_p0/logs \
  --closure-csv output/ptw_stage8_cov_collect/ptw_source_closure_matrix.csv \
  --closure-report output/ptw_stage8_cov_collect/ptw_source_coverage_report.md
```

实际实现必须展开第 8 节列出的全部 PTW source gate list，而不能只跑上面的单个示例命令。runner 在 manifest 中记录每个 gate list、seed、regress name 和 log dir，避免后续把 coverage `_cov.log` 误作为功能闭合证据。

#### 15.5.2 runner 调用 Makefile 的命令模板

所有命令从仿真目录执行：

```text
/x2025/GPrj1/IC2/mmu_verification/mmu_verification
```

runner 应生成以下公共变量：

```text
PTW_COV_ROOT=output/ptw_cov
PTW_COV_DB=output/ptw_cov/simv_ptw.vdb
PTW_COV_BASE_DB=output/ptw_cov/simv_ptw.compile.vdb
PTW_COV_STAMP=output/ptw_cov/.simv_ptw.compile.stamp
PTW_URG_REPORT=output/ptw_cov/urgReport
PTW_URG_MERGED_DB=output/ptw_cov/merged_ptw.vdb
PTW_URG_LOG=output/ptw_cov/urg_ptw.log
```

编译命令：

```bash
make comp_all \
  COV_FORCE_REBUILD=1 \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PWD/output/ptw_cov" \
  COV_DB_DIR="$PWD/output/ptw_cov/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PWD/output/ptw_cov/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PWD/output/ptw_cov/.simv_ptw.compile.stamp"
```

每个 list/seed 的 run_cov 命令：

```bash
make regress \
  LIST=<list> \
  REGRESS_MODE=run_cov \
  REGRESS_NAME=<unique_regress_name> \
  REGRESS_SEEDS="<seed>" \
  REGRESS_JOBS=1 \
  REGRESS_SUMMARY="$PWD/output/regression/<unique_regress_name>/summary.txt" \
  UVM_ERR_ONLY=0 \
  UVM_CONFIG_DB_TRACE=0 \
  TIMEOUT=<timeout> \
  VERBOSITY=<verbosity> \
  PLUS_ARGS="<extra_plus_args>" \
  COV_HIER_CFG="$PWD/scripts/ptw_cov_hier.cfg" \
  COV_DIR="$PWD/output/ptw_cov" \
  COV_DB_DIR="$PWD/output/ptw_cov/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PWD/output/ptw_cov/simv_ptw.compile.vdb" \
  COV_BASELINE_STAMP="$PWD/output/ptw_cov/.simv_ptw.compile.stamp"
```

URG 命令：

```bash
make cov \
  COV_DIR="$PWD/output/ptw_cov" \
  COV_DB_DIR="$PWD/output/ptw_cov/simv_ptw.vdb" \
  COV_BASE_DB_DIR="$PWD/output/ptw_cov/simv_ptw.compile.vdb" \
  URG_REPORT_DIR="$PWD/output/ptw_cov/urgReport" \
  URG_MERGED_DB="$PWD/output/ptw_cov/merged_ptw.vdb" \
  URG_LOG="$PWD/output/ptw_cov/urg_ptw.log"
```

parser 命令：

```bash
python3 scripts/ptw_extract_code_coverage.py \
  --urg-report "$PWD/output/ptw_cov/urgReport" \
  --hier-cfg "$PWD/scripts/ptw_cov_hier.cfg" \
  --cov-db "$PWD/output/ptw_cov/simv_ptw.vdb" \
  --out-md "$PWD/output/ptw_cov/ptw_code_coverage_summary.md" \
  --out-json "$PWD/output/ptw_cov/ptw_code_coverage_summary.json"
```

#### 15.5.3 runner 内部状态机

runner 状态建议固定为：

```text
INIT
CHECK_ENV
CHECK_TEST_REGISTRY
CHECK_HIER_CFG
CLEAN_OUTPUT
COMPILE
RUN_FUNCTIONAL_GATE
RUN_COVERAGE_REGRESSIONS
GENERATE_URG
PARSE_REPORT
WRITE_MANIFEST
DONE
FAILED
```

每个状态进入和退出都写入：

```text
output/ptw_cov/run_ptw_code_coverage.log
```

失败时必须记录：

- state；
- command；
- return code；
- stdout/stderr log path；
- 建议下一步。

#### 15.5.4 清理策略

runner 不能使用危险的全局删除。允许清理：

```text
output/ptw_cov/*.vdb
output/ptw_cov/*.vdb.failed.*
output/ptw_cov/*.vdb.stale.*
output/ptw_cov/urgReport
output/ptw_cov/merged*
output/ptw_cov/urg_ptw.log
output/ptw_cov/ptw_extract_code_coverage.log
output/ptw_cov/ptw_code_coverage_summary.md
output/ptw_cov/ptw_code_coverage_summary.json
output/ptw_cov/ptw_cov_manifest.json
```

`make clean_cov` 可以作为辅助步骤，但 runner 不能只依赖 `clean_cov`，因为自定义 `URG_LOG`、`ptw_extract_code_coverage.log`、manifest 和 compile stamp 可能不会被默认 target 完整清掉。runner 必须显式清理 PTW coverage root 内的上述产物，且不得清理 `output/regression/ptw_src_*` 功能 gate 证据。

如果遇到 NFS busy，采用与 `clean_cov` 类似的 stale rename 策略，不直接失败，除非无法 rename 且无法删除。

#### 15.5.5 regression name 和 COV_TAG 规则

为了避免 log/VDB coverage name 混乱，runner 应给每个 list/seed 生成稳定 regression name：

```text
ptw_cov_<profile>_<list_basename>_<seed>
```

示例：

```text
ptw_cov_default_ptw_code_coverage_list_606
ptw_cov_default_ptw_code_coverage_list_707
ptw_cov_signoff_mmu_v4_full_regression_list_808
```

`run_cov` 的 `COV_TAG` 默认是 `$(TEST_NAME)_$(SEED)`，同一个 test/seed 不能在同一个 aggregate 中重复跑。使用现有 `run_test.py -> make regress -> make run_cov` 路径时，runner 必须按 `(test, seed)` 去重，而不是按 `(test, seed, plusargs)` 去重，因为 plusargs 不会自动进入 `COV_TAG`。

如果 profile 中存在重复 `(test, seed)` 且 plusargs 相同，runner 必须去重并在 manifest 记录：

```json
{
  "deduped_entries": [
    {
      "test": "test_ptw_random_pte_perm_cross_001",
      "seed": "707",
      "kept_from": "simu/ptw_code_coverage_list",
      "dropped_from": "simu/ptw_random_list"
    }
  ]
}
```

如果 profile 中存在重复 `(test, seed)` 但 plusargs 不同，有两种合法处理方式：

1. 默认处理：runner 报 `duplicate_cov_tag` 并停止，要求 profile 改 seed 或删除重复项。
2. 扩展处理：先修改 Makefile/run_test.py，使每个 run 可以显式传入唯一 `COV_TAG=ptw_cov_<profile>_<list_basename>_<seed>_<hash>`，并在 manifest 中记录 `cov_tag`。没有完成这项修改前，不能用不同 plusargs 重复跑同一 test/seed。

#### 15.5.6 runner 验收测试

runner 的轻量测试不应依赖 VCS。建议新增 mock 模式：

```bash
python3 scripts/run_ptw_code_coverage.py --profile quick --dry-run
```

`--dry-run` 只打印将执行的 Makefile 命令和 manifest，不执行仿真。验收点：

- profile 解析正确；
- list 文件存在；
- seed 展开正确；
- regression name 唯一；
- COV 变量完整；
- jobs=1；
- parser 命令完整；
- manifest 可写。

真实 flow 验收：

```bash
make ptw_code_cov PTW_COV_PROFILE=quick
```

必须至少证明：

- compile baseline VDB 生成；
- `run_cov` 产生 `_cov.log`；
- aggregate VDB 非空；
- URG report 生成；
- parser 输出 `PTW_CODE_COVERAGE_RESULT`。

### 15.6 建议修改 Makefile：新增一键 target

在 `mmu_verification/Makefile` 中新增：

```makefile
PTW_COV_PROFILE ?= default
PTW_COV_ROOT ?= $(OUTPUT_DIR)/ptw_cov
PTW_COV_HIER_CFG ?= $(PROJECT_DIR)/scripts/ptw_cov_hier.cfg
PTW_COV_JOBS ?= 1
PTW_COV_FORCE_REBUILD ?= 1
PTW_COV_TIMEOUT ?= $(TIMEOUT)
PTW_COV_VERBOSITY ?= $(VERBOSITY)
PTW_COV_FUNCTIONAL_GATE_MODE ?= run
PTW_COV_FUNCTIONAL_GATE_EVIDENCE ?=
PTW_COV_EXTRA_ARGS ?=

.PHONY: ptw_code_cov
ptw_code_cov:
	$(PYTHON) "$(PROJECT_DIR)/scripts/run_ptw_code_coverage.py" \
		--profile "$(PTW_COV_PROFILE)" \
		--cov-root "$(PTW_COV_ROOT)" \
		--hier-cfg "$(PTW_COV_HIER_CFG)" \
		--jobs "$(PTW_COV_JOBS)" \
		--timeout "$(PTW_COV_TIMEOUT)" \
		--verbosity "$(PTW_COV_VERBOSITY)" \
		--functional-gate-mode "$(PTW_COV_FUNCTIONAL_GATE_MODE)" \
		$(if $(PTW_COV_FUNCTIONAL_GATE_EVIDENCE),--functional-gate-evidence "$(PTW_COV_FUNCTIONAL_GATE_EVIDENCE)") \
		$(if $(filter 1,$(PTW_COV_FORCE_REBUILD)),--force-rebuild) \
		$(PTW_COV_EXTRA_ARGS)
```

用户最终运行：

```bash
make ptw_code_cov
```

或运行 signoff profile：

```bash
make ptw_code_cov PTW_COV_PROFILE=signoff
```

Makefile target 只做编排入口，实际逻辑放在 Python 脚本中，便于记录 manifest、解析 JSON 和失败原因。

Makefile target 必须放在现有 `Coverage` 或 `Test List` 区块附近，保持维护者容易发现。新增变量名统一使用 `PTW_COV_*`，避免覆盖现有 `COV_*` 默认值。

如果使用 `PTW_COV_EXTRA_ARGS` 传递 debug 选项，例如 `--parse-only` 或 `--skip-functional-gate`，CI 配置必须单独标记该 job 为 debug，不能把该 job 结果当作 signoff coverage。

### 15.7 可选新增：UVM smoke wrapper

如果团队坚持“新增一个 UVM test name”，可以新增一个 smoke wrapper：

```text
testbench/test/ptw_tests/test_ptw_code_cov_smoke.svh
```

并加入：

```text
testbench/test/ptw_tests/ptw_tests_suite.svh
simu/ptw_code_coverage_smoke_list
```

该 UVM test 只能承担 smoke 和补洞刺激，例如继承 `ptw_source_directed_base`，复用 P0/P1/PDE/MBUF/TWU 典型 scenario，运行后输出功能 marker。它不能在仿真内部输出最终 VCS code coverage 数值，因为 URG 必须在仿真结束后运行。

因此推荐最终用户入口仍是：

```bash
make ptw_code_cov
```

而不是：

```bash
make run TEST_NAME=test_ptw_code_cov_smoke
```

### 15.8 必须修改：文档和报告归档

新增或更新以下文档/产物索引：

- 本文档：记录一键入口和 scope 规则；
- `doc/ptw_uvm_review/ptw_source_signoff_report.md`：增加 code coverage result 链接，但不把 code coverage 混入 source-side closure；
- `output/ptw_cov/ptw_code_coverage_summary.md`：每次覆盖率执行自动生成；
- `output/ptw_cov/ptw_code_coverage_summary.json`：供 CI/脚本读取；
- `output/ptw_cov/ptw_cov_manifest.json`：记录 profile/list/seed/commit。

### 15.9 CI 或人工门禁建议

CI 中增加两个层级：

```bash
make ptw_code_cov PTW_COV_PROFILE=quick
```

用于检查 coverage flow 是否可运行。

```bash
make ptw_code_cov PTW_COV_PROFILE=default
```

用于日常 PTW code coverage 数值监控。

最终交付前运行：

```bash
make ptw_code_cov PTW_COV_PROFILE=signoff
```

CI pass 条件：

- command return code 为 0；
- signoff job 的 stdout 包含 `PTW_CODE_COVERAGE_RESULT status=PASS`；
- quick/default/full 监控 job 允许 `CONDITIONAL_PASS`，但必须把 `reason`、`profile` 和 `confidence` 写入 CI artifact；
- JSON 中 `scope=ptw_core`；
- JSON 中 `ptw_code_coverage >= 99.0`；
- JSON 中各 metric 达到门槛或 N/A 已解释；
- JSON 中 `functional_gate.status=PASS` 或 `REUSED`，且 signoff job 不允许 `SKIPPED`；
- JSON 中 `confidence=high`，否则不能 signoff；
- URG report path 和 VDB path 存在。

### 15.10 最终用户命令和预期输出

新增入口实现后，用户只需要执行：

```bash
cd /x2025/GPrj1/IC2/mmu_verification/mmu_verification
make ptw_code_cov
```

脚本完成后必须在终端最后输出一行：

```text
PTW_CODE_COVERAGE_RESULT status=<PASS|FAIL|CONDITIONAL_PASS> scope=ptw_core profile=<profile> functional_gate=<PASS|REUSED|SKIPPED|FAIL> confidence=<high|medium|low> headline=<actual> line=<actual> condition=<actual> branch=<actual> fsm=<actual|N/A> toggle=<actual> assertion=<actual|N/A> reason=<reason> report=output/ptw_cov/urgReport cov_db=output/ptw_cov/simv_ptw.vdb
```

同时生成：

```text
output/ptw_cov/ptw_code_coverage_summary.md
output/ptw_cov/ptw_code_coverage_summary.json
```

如果覆盖率未达标，命令仍必须输出实际数值，但 `status=FAIL`，并在 JSON/Markdown 中列出低于门槛的 metric 和 top uncovered holes。失败示例：

```text
PTW_CODE_COVERAGE_RESULT status=FAIL scope=ptw_core headline=97.84 line=99.61 condition=98.10 branch=96.72 fsm=100.00 toggle=97.20 assertion=100.00 reason=threshold_fail report=output/ptw_cov/urgReport cov_db=output/ptw_cov/simv_ptw.vdb
```

### 15.11 实现 checklist

新增/修改完成后，逐项检查：

| Item | 文件 | 必须满足 |
| --- | --- | --- |
| PTW hierarchy | `scripts/ptw_cov_hier.cfg` | PTW-only scope；SVA module 排除；实例树或 module 白名单有效 |
| coverage list | `simu/ptw_code_coverage_list` | 所有 test 已注册；source tests 保留 PTW plusargs；不含 xfail |
| profile | `scripts/ptw_code_coverage_profiles.json` | quick/default/full/signoff 四档存在；每档使用 runs[]；list 和 seed 可展开；full regression seed 不被全局 seed 误乘 |
| parser | `scripts/ptw_extract_code_coverage.py` | 支持 text/html；支持 hit/total 和 percentage-only；scope 校验；JSON/Markdown 输出 |
| runner | `scripts/run_ptw_code_coverage.py` | 编排 make；jobs=1；manifest；functional gate 隔离；失败状态清晰；stdout result line |
| Makefile | `Makefile` | `ptw_code_cov` target 可运行；变量使用 `PTW_COV_*` |
| docs | 本文档和 signoff report | 链接最终 coverage summary；不混淆功能覆盖和代码覆盖 |
| smoke | `make ptw_code_cov PTW_COV_PROFILE=quick` | 能生成 VDB、URG、summary |
| default | `make ptw_code_cov PTW_COV_PROFILE=default` | 输出实际 PTW code coverage 数值 |
| signoff | `make ptw_code_cov PTW_COV_PROFILE=signoff` | 用于最终交付 |

### 15.12 失败原因和处理表

| reason | 触发条件 | 处理 |
| --- | --- | --- |
| `check_env_fail` | VCS/URG/path 环境不可用 | 修复环境，不解释覆盖率 |
| `test_not_registered` | list 中 test 不在 UVM registry | 修 include/test_pkg/testlist |
| `hier_cfg_missing` | `ptw_cov_hier.cfg` 不存在 | 新增或修正 hierarchy 配置 |
| `profile_invalid` | profile 缺失、不是 runs[] 结构、list 不存在或 seed 非法 | 修 `ptw_code_coverage_profiles.json` |
| `duplicate_cov_tag` | 同一 `(test, seed)` 重复进入 aggregate，或同 test/seed 需不同 plusargs 但没有唯一 COV_TAG 支持 | 去重、换 seed，或实现 per-run `COV_TAG` |
| `functional_gate_fail` | `run_check` 功能门禁失败 | 修功能回归，不解释 code coverage |
| `functional_gate_skipped` | 跳过功能门禁且请求 signoff PASS | 改为 run/reuse gate，或仅作为 debug/conditional 结果 |
| `compile_fail` | `make comp_all` 失败 | 看 `output/logs/comp_all.log` |
| `compile_vdb_missing` | compile baseline VDB 不存在或为空 | 重新 compile，检查 COV vars |
| `regression_fail` | 任一 run_cov 失败或 summary 未达 100% | 先修测试/环境，不解释覆盖率 |
| `coverage_log_fail` | `_cov.log` 有 fatal/crash/license | 修仿真或 license 问题 |
| `urg_fail` | `make cov` 失败或 report 缺失 | 看 `output/ptw_cov/urg_ptw.log` |
| `scope_invalid` | URG report 含非 PTW RTL scope | 修 `ptw_cov_hier.cfg` 并重跑 |
| `missing_metric` | 必要 metric 无法解析 | 修 parser 或 URG 输出 |
| `ambiguous_metric` | 同一 metric 多个候选冲突 | 修 scope 或 parser 选择规则 |
| `confidence_low` | parser 低可信或 scope/metric 证据不足 | 补 URG 输出、修 parser 或重跑 |
| `threshold_fail` | headline 或分项低于门槛 | hole analysis、补测或 waiver |
| `waiver_missing` | 未达标项无精确 waiver | 补 waiver 或补测试 |
| `conditional_pass_only` | 数值达标但 profile 非 signoff、gate skip/reuse 证据不足或存在临时 waiver | 按 signoff 要求重跑或补证据 |

失败时仍应尽量保留已生成的 logs/VDB/report，便于 debug。runner 不应在失败后自动删除证据。

## 16. 推荐执行顺序

1. 创建 `scripts/ptw_cov_hier.cfg`，优先使用 `+tree tb_top.u_dut.x_ct_mmu_ptw`。
2. 创建 `simu/ptw_code_coverage_list`，纳入 source/PDE/protocol/consumer 默认覆盖率测试。
3. 创建 `scripts/ptw_extract_code_coverage.py`，实现 URG 解析、PTW-only scope 校验和 JSON/Markdown 输出。
4. 创建 `scripts/run_ptw_code_coverage.py`，编排 check_env、compile、run_cov、URG、parser。
5. 在 `Makefile` 增加 `ptw_code_cov` target。
6. 执行 `make list_tests`，确认新增 list 中所有 test 已注册。
7. 执行 `make ptw_code_cov PTW_COV_PROFILE=quick`，验证 coverage flow 可跑通。
8. 执行 `make ptw_code_cov PTW_COV_PROFILE=default`，产出第一版 PTW code coverage 数值。
9. 检查 `output/ptw_cov/ptw_code_coverage_summary.md/json` 和 stdout `PTW_CODE_COVERAGE_RESULT`。
10. 如果达标，归档 summary 和 manifest。
11. 如果未达标，执行 hole analysis。
12. 根据 hole 类型补 run `PTW_COV_PROFILE=signoff`、full regression 或 targeted hole-fill tests。
13. 对 spec-unreachable/dead/debug code 建立精确 waiver。
14. 重新运行 `make ptw_code_cov PTW_COV_PROFILE=signoff`。
15. 输出最终 `PTW_CODE_COVERAGE_RESULT`。

## 17. 风险和控制项

| 风险 | 控制 |
| --- | --- |
| 使用全 MMU coverage 冒充 PTW coverage | 使用独立 PTW hierarchy，解析脚本强制检查 scope |
| `run_cov` 并发写 VDB | `REGRESS_JOBS=1` |
| 同一 test/seed 重复写入同一 aggregate | runner 按 `(test, seed)` 去重；不同 plusargs 需要唯一 `COV_TAG` 支持 |
| 覆盖率编译 scope 不生效 | 检查 compile log 和 URG hierarchy/modlist |
| SVA/testbench 被计入 code coverage | hierarchy 配置排除 SVA，summary 检查 module list |
| 把 `_cov.log` 当作功能 signoff gate 证据 | functional gate 只检查 `run_check` 日志，manifest 分开记录 gate 和 coverage runs |
| 功能 marker 被 `UVM_ERR_ONLY=1` 隐藏 | source signoff gate 使用 `UVM_ERR_ONLY=0` |
| 随机 seed 不稳定 | 固定 seed 列表，summary 记录 seed |
| profile seed 展开导致 full regression 成本爆炸 | profile 使用 runs[]，每个 list 单独声明 seeds |
| 空洞被粗粒度 waiver 掩盖 | waiver 精确到 file/line/branch/toggle/FSM |
| pmpflg update/clear 路径受顶层绑线限制 | 单独标记并关联设计/验证闭合记录 |
| 误以为单个 UVM test 可以输出最终 code coverage | 使用 `make ptw_code_cov` 编排 VCS/URG/parser，UVM test 只负责刺激 |
| 默认 coverage list 运行时间过长 | 使用 quick/default/full/signoff profile 分层 |
| default profile 未达标 | 自动或人工进入 signoff/full + hole-fill 流程 |

## 18. 计划新增或产出的文件

建议新增：

- `mmu_verification/scripts/ptw_cov_hier.cfg`
- `mmu_verification/scripts/ptw_extract_code_coverage.py`
- `mmu_verification/scripts/run_ptw_code_coverage.py`
- `mmu_verification/scripts/ptw_code_coverage_profiles.json`
- `mmu_verification/scripts/tests/ptw_cov_parser/`
- `mmu_verification/simu/ptw_code_coverage_list`
- `mmu_verification/Makefile` 中的 `ptw_code_cov` target
- 可选：`mmu_verification/testbench/test/ptw_tests/test_ptw_code_cov_smoke.svh`
- 可选：`mmu_verification/simu/ptw_code_coverage_smoke_list`

建议产出：

- `mmu_verification/output/ptw_cov/run_ptw_code_coverage.log`
- `mmu_verification/output/ptw_cov/ptw_cov_manifest.json`
- `mmu_verification/output/ptw_cov/simv_ptw.vdb`
- `mmu_verification/output/ptw_cov/simv_ptw.compile.vdb`
- `mmu_verification/output/ptw_cov/merged_ptw.vdb`
- `mmu_verification/output/ptw_cov/urgReport/`
- `mmu_verification/output/ptw_cov/urg_ptw.log`
- `mmu_verification/output/ptw_cov/ptw_extract_code_coverage.log`
- `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.md`
- `mmu_verification/output/ptw_cov/ptw_code_coverage_summary.json`

本文档本身保存为：

```text
doc/ptw_uvm_review/ptw_code_coverage_detection_plan.md
```

## 19. 最终结果模板

实际覆盖率执行完成后，在 `ptw_code_coverage_summary.md` 和最终汇报中使用以下格式：

```text
PTW_CODE_COVERAGE_RESULT status=PASS
scope=ptw_core
profile=signoff
functional_gate=PASS
confidence=high
headline=99.23
line=99.71
condition=99.12
branch=99.06
fsm=100.00
toggle=98.42
assertion=100.00
headline_method=weighted_hit_total
urg_report=output/ptw_cov/urgReport
cov_db=output/ptw_cov/simv_ptw.vdb
```

如果实际执行结果未达标：

```text
PTW_CODE_COVERAGE_RESULT status=FAIL
scope=ptw_core
headline=<actual>
line=<actual>
condition=<actual>
branch=<actual>
fsm=<actual|N/A>
toggle=<actual>
assertion=<actual|N/A>
fail_reason=<metric below threshold or scope invalid>
next_action=<hole-fill test or waiver review>
```

如果当前 profile 不是 signoff，或 functional gate 被 skip/reuse 证据不足，但覆盖率数值已经达标，应输出条件通过而不是最终通过：

```text
PTW_CODE_COVERAGE_RESULT status=CONDITIONAL_PASS
scope=ptw_core
profile=default
functional_gate=SKIPPED
confidence=high
headline=<actual>
line=<actual>
condition=<actual>
branch=<actual>
fsm=<actual|N/A>
toggle=<actual>
assertion=<actual|N/A>
reason=non_signoff_profile
next_action=rerun profile=signoff with functional_gate=run_or_valid_reuse
```

模板中的数值是示例。最终只能填写由 PTW-only URG report 解析得到的实际数值。

## 20. 文档审查和实现前检查清单

在真正新增脚本、testlist 和 Makefile target 前，按以下清单再次确认文档和实现保持一致：

| Check | 必须满足 |
| --- | --- |
| 执行目录 | 所有命令从 `mmu_verification/` 仿真目录执行，或使用 `make -C mmu_verification` 并修正路径 |
| PTW-only scope | `ptw_cov_hier.cfg` 使用 PTW instance tree 或 PTW module whitelist，parser 能拒绝 L1/L2TLB、PMP、SysMap、SVA/testbench scope |
| profile 结构 | `ptw_code_coverage_profiles.json` 只使用 `runs[]`，不使用旧式全局 `lists/seeds` |
| profile 语义 | `quick/default/full` 是中间结果；只有 `signoff` 或 owner 批准的等价 profile 可输出最终 `PASS` |
| seed 展开 | full regression 的 seed 与 PTW source seed 分开声明，不能被全局 seed 乘爆 |
| duplicate 处理 | runner 按 `(test_name, seed)` 去重；不同 plusargs 重复运行同 test/seed 时必须有唯一 `COV_TAG` 支持 |
| functional gate | gate 使用 `run_check` 日志和第 8 节 gate 脚本；不能用 `_cov.log` 作为功能闭合证据 |
| coverage run | 所有 `run_cov` 串行，`REGRESS_JOBS=1`，同一 aggregate VDB 不并发写 |
| 清理策略 | 只清理 `output/ptw_cov` 内 PTW coverage 产物，不删除功能 gate logs 或其他 regression 证据 |
| URG 生成 | `make cov` 生成 `urgReport`、`merged_ptw.vdb`、`urg_ptw.log`，失败时保留证据 |
| parser 可信度 | signoff 必须 `confidence=high`，即 PTW-only scope 通过且主要 metric 有 hit/total |
| JSON schema | 顶层包含 `status/reason/confidence/scope_check/functional_gate/run_manifest/metrics/holes_top20/waivers` |
| stdout result | 最后一行包含 `PTW_CODE_COVERAGE_RESULT`，并带 profile、functional gate、confidence、headline 和各 metric |
| CI 判定 | signoff job 只接受 `status=PASS`；中间 job 的 `CONDITIONAL_PASS` 不能当最终 signoff |
| waiver | waiver 精确到 file/module/line/object/metric，不能对整个 PTW module 粗粒度 waiver |
| 可复现性 | manifest 记录 git commit、profile、list、seed、regress name、cov tag、gate evidence 和时间戳 |

实现完成后的第一轮推荐验证顺序：

1. `python3 scripts/run_ptw_code_coverage.py --profile quick --dry-run`
2. `python3 -m unittest discover -s scripts/tests -p 'test_ptw_cov_*.py'`
3. `make ptw_code_cov PTW_COV_PROFILE=quick`
4. `make ptw_code_cov PTW_COV_PROFILE=default`
5. 若 default 未达标或需要最终交付，运行 `make ptw_code_cov PTW_COV_PROFILE=signoff`

以上 5 步中，只有第 5 步在满足第 14 节全部条件时可以输出最终 `PASS`；前 4 步即使数值达标，也只能作为 flow sanity 或中间 coverage 监控结果。
