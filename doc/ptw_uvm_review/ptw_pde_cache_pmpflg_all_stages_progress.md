# PTW PDE Cache PMP Flag All Stages Progress

更新时间：2026-05-18

本文档汇总 `ptw_pde_cache_pmpflg_staged_implementation_plan.md` 中各阶段的执行进度。阶段 0 到阶段 7 已完成；阶段 8 directed test 实现已完成，静态接入检查通过，仿真证据待在具备 `make` 的环境中收集；阶段 9 directed test 实现已完成，静态接入检查通过，仿真证据待在具备 `make` 的环境中收集；阶段 10 尚未开始。原阶段独立进度文件已合并到本文档，后续以本文档作为统一进度记录。

## 总体状态

| 阶段 | 名称 | 状态 | 当前产出 |
| --- | --- | --- | --- |
| 0 | semantic freeze and probe audit | done | `ptw_pde_cache_pmpflg_stage0_probe_map.md` |
| 1 | common types and transaction schema | done | `ptw_source_types.svh` |
| 2 | probe wiring and monitor sampling | done | probe if、`tb_top.sv`、`ptw_source_monitor.svh` |
| 3 | pde cache abstract model refactor | done | `ptw_pde_cache_model.svh` |
| 4 | reference model integration | done | `ptw_source_ref_model.svh` |
| 5 | scoreboard and coverage enhancement | done | `ptw_source_sb.svh`、必要 `mmu_env.svh` fanout |
| 6 | SVA and cover | done | `mmu_pde_cache_sva.sv`、`mmu_ptw_top_sva.sv`、必要 bind 显式连接 |
| 7 | directed helper and legacy PDE tests update | done | `ptw_source_directed_base.svh` helper、旧 PDE tests metadata/allow 前提修正 |
| 8 | new P0 directed tests A | implemented, static pass, pending sim | 5 个 directed tests、suite include、`ptw_pde_pmpflg_list` |
| 9 | new P0/P1 directed tests B | implemented, static pass, pending sim | 4 个 directed tests、suite/list、P1 list |
| 10 | regression and signoff freeze | not started | 未开始 |

阶段完成标记：

```text
PMPFLG_STAGE_DONE stage=0 name=semantic_freeze_and_probe_audit
PMPFLG_STAGE_DONE stage=1 name=common_types_and_transaction_schema
PMPFLG_STAGE_DONE stage=2 name=probe_wiring_and_monitor_sampling
PMPFLG_STAGE_DONE stage=3 name=pde_cache_abstract_model_refactor
PMPFLG_STAGE_DONE stage=4 name=source_reference_model_integration
PMPFLG_STAGE_DONE stage=5 name=scoreboard_coverage_no_extra_lsu
PMPFLG_STAGE_DONE stage=6 name=sva_and_cover
PMPFLG_STAGE_DONE stage=7 name=directed_helper_and_legacy_pde_tests_update
PMPFLG_STAGE_IMPL_DONE stage=8 name=new_p0_directed_tests_a
PMPFLG_STAGE_IMPL_DONE stage=9 name=new_p0_p1_directed_tests_b
```

## 阶段 0 进度

状态：done

本阶段只完成语义冻结和信号审计，没有修改 RTL/UVM SystemVerilog 源码，没有新增 tests，没有修改 regression list。

完成内容：

| 类别 | 内容 |
| --- | --- |
| 输入文档审阅 | `ptw_pde_cache_pmpflg_design_change.md`、`ptw_pde_cache_pmpflg_uvm_implementation_plan.md`、`ptw_pde_cache_pmpflg_staged_implementation_plan.md`、`ptwspec.md` |
| RTL 审计 | `L1PDE_cache.sv`、`L2PDE_cache.sv`、`PDE_cache.sv`、`mbuf_entry.sv`、`ptw_mbuf.sv`、`twu.sv`、`ptw.sv` |
| UVM/SVA 审计 | `mmu_dut_probes_if.sv`、`tb_top.sv`、`ptw_source_types.svh`、`ptw_source_monitor.svh`、`ptw_pde_cache_model.svh`、`mmu_pde_cache_sva.sv`、`mmu_ptw_top_sva.sv` |
| 新增审计文档 | `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` |

主要结论：

| 结论 | 说明 |
| --- | --- |
| RTL 已有 cached pmpflg 语义 | L1/L2 PDE cache entry 已保存 pmpflg，并存在 permission-qualified hit 逻辑。 |
| RTL 已有 L2 direct accerr path | L2 tag-hit cached PMP deny 会产生 `PDE_cache_acc_err_vld/type/id/grant` 并接入 PTW access fault arbitration。 |
| MBUF/TWU payload 链路已存在 | `twu_mbuf_pmpflg` -> `mbuf_entry_pmpflg` -> `mbuf_twu_pmpflg` -> `mbuf_cache_upd_l1pmpflg/l2pmpflg`。 |
| UVM probe 原先不足 | 旧 probe 只覆盖 PDE hit/update/clear/update_vec，缺少 pmpflg payload、raw tag hit、cached entry pmpflg、direct accerr vld/type/id/grant。 |
| PMP config update 存在 gap | `pmp_regs_update` 在 `tb_top.sv` DUT instance 中 tie 为 `1'b0`，后续 clear/repopulate 相关阶段需要处理。 |

阶段 0 保留产物：

| 文件 | 状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | 保留，作为后续 probe/SVA/ref/SB 接入依据。 |

## 阶段 1 进度

状态：done

本阶段只完成公共类型、helper 和 transaction schema 扩展；未接 probe，未修改 monitor 采样逻辑，未修改 ref model/SB 行为，未新增 test，未修改 regression list。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_types.svh` | 新增 PDE reason/access source enum；新增 cached pmpflg allow helper；扩展 expected/level/PDE transaction 字段；更新 `convert2string()`。 |

未修改文件边界：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | include 顺序已满足要求，无需修改。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 阶段 1 禁止修改 monitor 采样逻辑。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 阶段 1 禁止修改 ref model 行为。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 阶段 1 禁止修改 scoreboard compare 行为。 |

新增类型与 helper：

| 类别 | 名称 |
| --- | --- |
| enum | `ptw_src_pde_reason_e` |
| enum | `ptw_src_access_src_e` |
| helper | `ptw_src_pde_pmp_type_bit_allow()` |
| helper | `ptw_src_pde_pmp_allow()` |
| helper | `ptw_src_pde_reason_name()` |
| helper | `ptw_src_access_src_name()` |
| helper | `ptw_src_is_data_type()` |

Helper 语义：

| Request type | cached PMP bit |
| --- | --- |
| `PTW_SRC_TYPE_LOAD` | `pmpflg[0]` |
| `PTW_SRC_TYPE_PFU` | `pmpflg[0]` |
| `PTW_SRC_TYPE_STORE` | `pmpflg[1]` |
| `PTW_SRC_TYPE_FETCH` | `pmpflg[2]` |
| effective M-mode bypass | `effective_m && pmpflg[3] == 0` |

Transaction schema delta：

| Transaction | 新增字段 |
| --- | --- |
| `ptw_src_pde_evt_txn` | `l1_tag_hit`、`l2_tag_hit`、permission allow fields、cached/update pmpflg、`mbuf_pmpflg`、`direct_accerr`、`reason`、`access_src`、accerr type/id/grant、raw tag/accerr vectors。 |
| `ptw_src_level_evt_txn` | `twu_mbuf_pmpflg`、`mbuf_pmpflg`、`selected_pmpflg`。 |
| `ptw_src_expected_rsp_txn` | `access_src`、`pde_reason`、`pde_l1pmpflg`、`pde_l2pmpflg`、`pde_direct_accerr`。 |

新增字段在 constructor 中使用 safe default，避免旧 smoke 在未采样新 probe 时打印随机值。

## 阶段 2 进度

状态：done

本阶段只完成 probe 接入与 monitor actual event 采样；未修改 ref model expected，未修改 scoreboard compare，未新增 SVA，未新增 directed tests。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | 新增 pmpflg payload、PDE update pmpflg、raw tag hit、cached pmpflg、direct accerr、accerr grant probes 和 clocking input。 |
| `mmu_verification/testbench/top/tb_top.sv` | 将 RTL `mbuf_cache_upd_*pmpflg`、`twu_mbuf_pmpflg`、`mbuf_twu_pmpflg`、`mbuf_entry_pmpflg`、`PDE_cache_acc_err_*`、`L2PDE_entry_acc_err`、cached pmpflg/raw tag hit vectors 连接到 probe interface。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 采样 level/PDE event 的 pmpflg、raw tag hit、permission allow、direct accerr root cause，并增加 summary counters。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | 更新阶段 2 对阶段 0 gap 的关闭/部分关闭状态。 |

Monitor event delta：

| Event | 新增采样 |
| --- | --- |
| `PTW_LEVEL_EVT` | `twu_mbuf_pmpflg`、`mbuf_pmpflg`、`selected_pmpflg`。 |
| `PTW_PDE_EVT` hit/miss | `l1_tag_hit/l2_tag_hit`、permission allow、cached pmpflg、L2 direct accerr vector、`reason/access_src`。 |
| `PTW_PDE_EVT` update | `update_l1pmpflg/update_l2pmpflg`、`mbuf_pmpflg`、update vectors。 |
| `PTW_PDE_EVT` direct accerr | `direct_accerr=1`、`accerr_type/id/grant`、`PDE_CACHE_PMP_DENY` source。 |

Monitor summary counters：

| Counter | 含义 |
| --- | --- |
| `pde_pmpflg_update` | PDE cache update event 数量。 |
| `pde_l1_deny_miss` | L1 tag hit 但 cached PMP deny，表现为 miss 的 event 数量。 |
| `pde_direct_accerr` | PDE cache direct access fault event 数量。 |

## 阶段 3 进度

状态：done

本阶段只完成 PDE cache abstract model 的 permission-qualified 重构；未修改 monitor，未生成 expected completion，未修改 scoreboard，未新增 tests。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | `pde_entry_s` 保存 `l1pmpflg/l2pmpflg`；新增 `pde_lookup_result_s`；新增 permission-qualified `lookup_detail()`；update API 支持 pmpflg；保留旧 lookup/update 兼容；新增 debug dump/helper。 |

Lookup 语义：

| 场景 | model 行为 |
| --- | --- |
| L2 tag hit 且 L1/L2 cached PMP allow | `lookup_hit=1`、`l2_hit=1`、`hit_level=THD`，更新 L2 age。 |
| L2 tag hit 但任一级 cached PMP deny | `l2_direct_accerr=1`，返回 `L2_L1PMP_DENY`、`L2_L2PMP_DENY` 或 `L2_BOTH_PMP_DENY`，不 fallback 到 L1，不更新 age。 |
| L1 tag hit 且 cached PMP allow | `lookup_hit=1`、`l1_hit=1`、`hit_level=SCD`，更新 L1 age。 |
| L1 tag hit 但 cached PMP deny | `l1_deny_miss=1`、`reason=L1_PMP_DENY`，不更新 age。 |
| all-allow pmpflg 默认 | 旧 `lookup(vpn, ...)`、旧 `queue_update(level,vpn,ppn)`、旧 `commit_update(level,vpn,ppn)` 行为保持 tag-only 兼容。 |

API delta：

| API | 状态 |
| --- | --- |
| `lookup(vpn, hit_level, hit_ppn, l1_hit, l2_hit)` | 保留，内部用 all-allow/default LOAD 兼容旧调用。 |
| `lookup_detail(vpn, req_type, effective_m, update_plru)` | 新增，返回 raw tag hit、qualified hit、deny/direct accerr reason。 |
| `queue_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim)` | 扩展，pmpflg 默认 all-allow。 |
| `commit_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim)` | 扩展，pmpflg 默认 all-allow。 |
| `queue_update_with_pmpflg()` / `commit_update_with_pmpflg()` | 新增显式别名，便于阶段 4 接入。 |
| `lookup_result2string()` / `dump_string()` | 新增 debug helper。 |

## 阶段 4 进度

状态：done

本阶段只完成 source reference model 对 PDE pmpflg golden 语义的集成；未修改 scoreboard compare 规则，未新增 no-extra-LSU checker，未新增 SVA，未新增 directed tests。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 扩展 pending request PDE pmpflg 状态；引入 predicted/observed PDE update window；用 observed PDE update pmpflg commit PDE model；lookup event 调用 `lookup_detail()`；生成 L2 PDE cached PMP deny direct access fault expected；summary 打印新增 pde pmpflg counters。 |

Reference model 行为：

| 场景 | ref model 行为 |
| --- | --- |
| FST non-leaf data return | 记录 predicted L1 PDE update，payload 为 `l1pmpflg=mbuf_pmpflg[3:0]`、`l2pmpflg=0`。 |
| SCD non-leaf data return | 记录 predicted L2 PDE update，payload 为 `l1pmpflg=mbuf_pmpflg[3:0]`、`l2pmpflg=mbuf_pmpflg[7:4]`。 |
| Observed PDE update | 与 predicted update 小窗口匹配，并用 `commit_update_with_pmpflg()` 更新 `m_pde_model`。 |
| PDE lookup actual event | 等 pending context ready 后调用 `lookup_detail(vpn, req_type, effective_machine(pending))`。 |
| L1 tag-hit cached PMP deny | 记录 `pde_l1_tag_hit_deny_seen` 和 `pde_l1_pmp_deny_miss`，不直接生成 access fault expected。 |
| L2 tag-hit cached PMP deny | 生成 `PTW_SRC_EXP_ACCESS_FAULT`，设置 `access_src=PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY`、`pde_reason`、`pde_l1pmpflg/pde_l2pmpflg`、`pde_direct_accerr=1`。 |
| SATP/TLB invalidate/PMP cfg update/abort | clear PDE model，并清空 pmpflg predicted/observed/deferred shadow queue。 |

新增或更新 summary counters：

| Counter | 含义 |
| --- | --- |
| `pde_l1_pmp_deny_miss` | L1 tag hit 但 cached PMP deny，被建模为 miss。 |
| `pde_l2_l1pmp_deny_accerr` | L2 tag hit 且 cached L1 PMP deny direct accerr。 |
| `pde_l2_l2pmp_deny_accerr` | L2 tag hit 且 cached L2 PMP deny direct accerr。 |
| `pde_pmpflg_update_l1` | observed L1 PDE update commit 数量。 |
| `pde_pmpflg_update_l2` | observed L2 PDE update commit 数量。 |
| `pde_mmode_bypass` | effective M-mode cached pmpflg bypass evidence。 |
| `pde_mmode_lock_deny` | effective M-mode lock-deny evidence。 |
| `pde_update_match` | predicted/observed PDE update payload match 数量。 |
| `pde_update_mismatch` | unmatched or mismatched PDE update payload 数量。 |
| `pde_duplicate_direct_accerr` | lookup/direct-accerr 双 event 去重数量。 |

## 阶段 5 进度

状态：done

本阶段只完成 source scoreboard、coverage 和 no-extra-LSU checker 增强；未新增 tests，未新增 SVA，未修改 directed base，未修改 regression list。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 新增 context/PDE event FIFO；扩展 completion compare 的 PDE pmpflg root-cause 校验；新增 PDE pmpflg coverage counters 和 `PTW_SOURCE_SB_PDE_PMP_COVERAGE` banner；新增 L2 direct-accerr no-extra-LSU window checker。 |
| `mmu_verification/testbench/env/mmu_env.svh` | 将已有 `ptw_source_monitor.ap_ctx/ap_pde` fanout 到 source scoreboard，用于覆盖和 root-cause 影子比对。 |

Scoreboard 行为：

| 场景 | 行为 |
| --- | --- |
| `pde_direct_accerr` expected | 要求 expected 为 access fault，`access_src=PDE_CACHE_PMP_DENY`，`pde_reason` 为 L2 cached PMP deny 类，且不被误归类为 bus error。 |
| PDE root-cause event 与 expected 同步 | 使用 monitor PDE event 对 `access_src/pde_reason/pde_direct_accerr/pde_l1pmpflg/pde_l2pmpflg` 做影子比对，并在 mismatch debug 中打印可读 reason。 |
| PDE event 晚于 expected | 暂存 expected root-cause，后续 PDE event 到达时比对；最终仍缺 event 时记 `probe_gap_pde_root_missing`，不把旧 smoke 误报为功能 mismatch。 |
| L2 direct accerr no-extra-LSU | direct accerr window 打开后到 visible completion/drop 前检查 PTW memory req；单 outstanding 严格报错，多 pending 记 `probe_gap_no_extra_lsu_ambiguous`。 |
| Active key retire | visible completion/drop 到达时继续立即 retire `{type,id}`，保持合法复用窗口规则。 |

新增 coverage/banner 字段：

| 字段 | 含义 |
| --- | --- |
| `l1_allow` / `l1_deny_miss` | L1 tag hit allow 与 L1 cached PMP deny miss 证据。 |
| `l2_allow` / `l2_l1deny` / `l2_l2deny` / `l2_bothdeny` | L2 allow 与 L2 cached PMP deny direct accerr 分类。 |
| `update_l1` / `update_l2` | PDE cache update pmpflg payload 覆盖。 |
| `direct_accerr_load/store/fetch/pfu` | Direct accerr request type 覆盖。 |
| `mmode_bypass` / `mmode_lock_deny` | Effective M-mode bypass 和 lock deny 证据。 |
| `no_extra_lsu` | L2 direct accerr 后无额外 PTW memory request 的关闭证据。 |
| `probe_gap_no_extra_lsu_ambiguous` | PTW memory request 无 `{type,id}` 且多 pending 时的不可严格归属计数。 |

## 阶段 6 进度

状态：done

本阶段只完成 SVA 与 cover 增强；未新增 directed tests，未修改 ref model/SB 行为，未修改 regression list。由于 `PDE_cache` bind target 本层没有 cached pmpflg/tag raw arrays，同阶段允许范围内仅在 bind 处增加显式 whitebox 连接，没有改 RTL。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | 新增 pmp allow helper、effective M-mode helper、PDE pmpflg/tag-hit/accerr ports；新增 `PTW-SVA-PDE-011..017` 及对应 `PTW_SVA_COVER` banner；旧 hit/update SVA 收紧为 permission-qualified hit/update 语义。 |
| `mmu_verification/testbench/top/mmu_ptw_top_sva.sv` | 新增 PDE direct accerr priority、completion class、no duplicate grant SVA；新增 `PTW-SVA-ARB-010..012` 对应 cover banner。 |
| `mmu_verification/testbench/top/tb_top.sv` | 仅为 SVA 编译/观测需要，将 `PDE_cache` bind 改为显式连接 L1/L2 raw tag hit 与 cached pmpflg whitebox 信号。 |

新增 SVA/cover：

| SVA ID | 覆盖内容 |
| --- | --- |
| `PTW-SVA-PDE-011` | L1 entry hit 等价于 `valid && tag_hit && allow(type,l1pmpflg,effective_m)`，tag hit deny 不 hit。 |
| `PTW-SVA-PDE-012` | L2 entry hit 等价于 `valid && tag_hit && allow(l1pmpflg) && allow(l2pmpflg)`。 |
| `PTW-SVA-PDE-013` | L2 tag hit deny 产生 PDE direct accerr，且不产生 xbar hit。 |
| `PTW-SVA-PDE-014` | L2 direct accerr vector 由 `ptw_req && valid && tag_hit && deny` gate。 |
| `PTW-SVA-PDE-015` | FST/SCD/THD PDE update payload 与 cached pmpflg 保存检查。 |
| `PTW-SVA-PDE-016` | tag hit deny 不更新 PLRU/read-hit；PLRU read-hit 只由 qualified hit 驱动。 |
| `PTW-SVA-PDE-017` | direct accerr pending type/id stable，grant 后 clear。 |
| `PTW-SVA-ARB-010` | PDE direct accerr 优先级高于 MBUF bus error/TWU accerr，并输出 PDE type/id。 |
| `PTW-SVA-ARB-011` | PDE direct accerr visible 时 completion class onehot。 |
| `PTW-SVA-ARB-012` | PDE direct accerr grant 后不重复返回同一 pending fault。 |

实现边界：

| 边界 | 结果 |
| --- | --- |
| Directed tests | 未新增，符合阶段 6 禁止项。 |
| Ref model/SB 行为 | 未修改，符合阶段 6 禁止项。 |
| Regression list | 未修改，符合阶段 6 禁止项。 |
| Probe interface | 未修改；本阶段只补 SVA bind 需要的 whitebox 连接。 |

## 阶段 7 进度

状态：done

本阶段只完成 directed helper 扩展和已有 PDE/相关旧 wrapper 的 pmpflg 语义修正；未新增 `PTW-ADD-037..045` directed test 文件，未修改 regression list，未修改 signoff gate，未关闭新增 `PTW-ADD-037..045`。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh` | 新增 pmpflg helper、PMP flag 配置 helper、真实 PTW walk prime helper、按 source type 发请求 helper、no PTW memory request window checker。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_l1_pde_hit.svh` | positive L1 PDE hit 显式加入 all-allow pmpflg 前提，checker 描述改为 permission-qualified hit。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_l2_pde_hit_direct.svh` | positive L2 PDE hit 显式加入 all-allow pmpflg 前提，删除 tag-only hit 口径。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_l1_pde_miss_walk.svh` | miss 口径标为 tag-miss profile，并说明 L1 cached-pmpflg deny 是 permission-qualified miss。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_l2_pde_miss_walk.svh` | miss 口径标为 tag-miss profile，并说明 L2 cached-pmpflg deny 是 direct accerr，不是普通 miss。 |
| `mmu_verification/testbench/test/ptw_tests/test_pde_cache_l1_single_entry.svh` | 补 L1 pmpflg update evidence 和 permission-qualified lookup 说明。 |
| `mmu_verification/testbench/test/ptw_tests/test_pde_cache_l2_single_entry.svh` | 补 L1/L2 pmpflg update evidence 和 permission-qualified lookup 说明。 |
| `mmu_verification/testbench/test/ptw_tests/test_mmu_pde_cache_hit_l2_skip_scd.svh` | run body 显式 `phase12_set_pmp_allow_all()`；skip SCD 只在 permission-qualified L1 PDE hit 下成立。 |
| `mmu_verification/testbench/test/ptw_tests/test_mmu_pde_cache_hit_l3_skip_thd.svh` | run body 显式 `phase12_set_pmp_allow_all()`；skip THD/PDE hit 口径改为 permission-qualified。 |
| `mmu_verification/testbench/test/ptw_tests/test_mmu_pde_cache_full_miss_full_ptw.svh` | full miss 建 cache 前显式 all-allow，并补 pmpflg update payload evidence 说明。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_l1_pde_cache_replace.svh` | replacement metadata 标明 PLRU 只由 qualified hit 更新，tag-hit deny 不更新 PLRU。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_l2_pde_cache_replace.svh` | replacement metadata 标明 direct accerr 不更新 PLRU/victim。 |
| `mmu_verification/testbench/test/ptw_tests/test_pde_cache_clear_on_ptw_reset.svh` | clear/reset metadata 标明旧 cached pmpflg 不可产生 hit/direct accerr。 |
| `mmu_verification/testbench/test/bug_hunt_tests/test_bug_001_twu_fst_fetch_type.svh` | fetch-type 旧 wrapper 显式 all-allow pmpflg，并把 checker 口径扩展到 cached execute allow。 |

新增 directed base helper：

| Helper | 用途 |
| --- | --- |
| `ptw_make_pmpflg()` | 按 `{lock,x,w,r}` 生成 cached PMP flag。 |
| `ptw_config_page_table_pmp_region()` | 通过现有 PMP agent 配置 TWU ports `{3,5,6,7}` flag，并记录 base/mask metadata；当前 agent 为 flag-only，无地址 region 字段。 |
| `ptw_prime_l1_pde_cache_with_type()` | 写入 FST nonleaf，通过真实 PTW walk 建立 L1 PDE cache entry，不直接写 DUT cache。 |
| `ptw_prime_l2_pde_cache_with_type()` | 写入 FST/SCD nonleaf，通过真实 PTW walk 建立 L2 PDE cache entry，不直接写 DUT cache。 |
| `ptw_drive_source_req_by_type()` | 按 `LOAD/STORE/FETCH/PFU` 统一发 source request，并沿用 active key guard。 |
| `ptw_expect_no_ptw_mem_req_window()` | 用 probe 检查一段窗口内没有 PTW LSU data request 或 TWU->MBUF request，用于后续 L2 direct accerr no-extra-LSU 场景。 |

实现边界：

| 边界 | 结果 |
| --- | --- |
| 新 directed test | 未新增，符合阶段 7 禁止项。 |
| `PTW-ADD-037..045` closure | 未关闭，仅准备 helper。 |
| Regression/signoff | 未修改。 |
| 临时子阶段计划 | 未创建；本阶段未新增文件，修改文件数 14 个，低于 15 文件拆分阈值。 |

## 阶段 8 进度

状态：implemented，static pass，pending simulation evidence

本阶段只完成 `PTW-ADD-037..041` 第一组 P0 directed tests、suite include 和阶段专用 regression list；未新增 `PTW-ADD-042..045`，未修改 signoff gate，未修改随机 regression closure，未修改 P0 smoke list。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l1_pmp_tag_deny_fst_fault_001.svh` | 新增 stage8 base helper 与 `PTW-ADD-037` L1 cached PMP deny miss test。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l1_pmp_tag_allow_reuse_001.svh` | 新增 `PTW-ADD-038` L1 R/X/W allow reuse matrix。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh` | 新增 `PTW-ADD-039` L2 tag hit cached L1 PMP deny direct-accerr test。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh` | 新增 `PTW-ADD-040` L2 tag hit cached L2 PMP deny direct-accerr test。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_pmpflg_propagation_update_001.svh` | 新增 `PTW-ADD-041` FST/SCD/THD pmpflg propagation/update test。 |
| `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh` | include 阶段 8 的 5 个 test 文件。 |
| `mmu_verification/simu/ptw_pde_pmpflg_list` | 新增阶段 8 directed list，包含 5 个 tests 和 source monitor/ref/SB/cov plusargs。 |

测试构造：

| Requirement | 实现方式 | 当前证据状态 |
| --- | --- | --- |
| `PTW-ADD-037` / `PDE-TP-013` / `PTW-FLOW-024` | 用 fetch + X-only cached pmpflg 建立 L1 PDE；后续同 `vpn[2]` 不同 `vpn[1]` 的 load 被 cached L1 R deny，回退 FST 并由实时 PMP 产生普通 TWU access fault。 | implemented，待仿真确认 source-SB clean 与 L1 deny miss coverage。 |
| `PTW-ADD-038` / `PDE-TP-013` / `PTW-FLOW-027` | 3 个 L1 allow reuse 子场景：load->PFU 共享 R、fetch 使用 X、store 使用 W；均用 2M prime 避免 L2 entry 抢先命中。 | implemented，待仿真确认 L1 permission-qualified hit coverage。 |
| `PTW-ADD-039` / `PDE-TP-014` / `PTW-FLOW-025` | 先用 2M fetch 建 L1，再通过 L1 hit 进入 SCD nonleaf 更新 L2，形成 cached `l1pmpflg=0/l2pmpflg=RX`；后续 load 命中 L2 tag 且仅 L1 cached PMP deny。 | implemented，标 partial evidence：当前 PMP agent 为 flag-only，无法用普通 full-walk 按 PTE region 精确区分 FST/SCD pmpflg；该 test 利用 RTL L1-hit-to-SCD direct path 构造精确 cached L1 deny。 |
| `PTW-ADD-040` / `PDE-TP-015` / `PTW-FLOW-026` | 用 locked X-only 建 L1/L2，后续 data request 通过 `MPRV=1/MPP=M` 让 cached L1 `0` 走 M-mode bypass，而 locked cached L2 deny R，隔离 `L2_L2PMP_DENY`。 | implemented，标 partial evidence：M-mode 仅作为构造手段；完整 effective-M lock/bypass matrix 仍属阶段 9。 |
| `PTW-ADD-041` / `PDE-TP-016` | 分别覆盖 FST nonleaf L1 update、SCD nonleaf L2 update、THD leaf no PDE update，检查 `{0,l1}`、`{l2,l1}`、THD `0/no update` 语义。 | implemented，待仿真确认 update payload coverage。 |

实现边界：

| 边界 | 结果 |
| --- | --- |
| 新增文件数量 | 5 个 test 文件 + 1 个 list，低于 15 文件拆分阈值；未创建临时阶段拆分计划。 |
| Stage 9 tests | 未新增 `PTW-ADD-042..045`。 |
| Signoff gate | 未修改。 |
| P0 smoke list | 未修改，阶段计划中该项为可选。 |
| Closure matrix | 未改成最终 closed；L2 分离类在 test metadata/progress 中保留 partial evidence 说明。 |

## 阶段 9 进度

状态：implemented，static pass，pending simulation evidence

本阶段只完成 `PTW-ADD-042..045` 第二组 P0/P1 directed tests、suite include、`ptw_pde_pmpflg_list` 更新和 P1 list 接入；未修改 `ptw_stage8_signoff_gate.py`，未更新 closure matrix 为最终 closed，未做阶段 10 regression/signoff 冻结。

修改文件：

| 文件 | 修改内容 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_accerr_priority_type_id_001.svh` | 新增 stage9 base helper 与 `PTW-ADD-042` PDE direct accerr priority/type/id directed test。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_mmode_lock_matrix_001.svh` | 新增 `PTW-ADD-043` effective M-mode `pmpflg[3]` lock/bypass matrix。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_l2_accerr_valid_gate_001.svh` | 新增 `PTW-ADD-044` invalid/stale L2 entry direct-accerr valid/request gate test。 |
| `mmu_verification/testbench/test/ptw_tests/test_ptw_pde_pmp_clear_repopulate_001.svh` | 新增 `PTW-ADD-045` clear 后 stale cached pmpflg 不可复用、重新 walk/update test。 |
| `mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh` | include 阶段 9 的 4 个 test 文件。 |
| `mmu_verification/simu/ptw_pde_pmpflg_list` | 加入阶段 9 的 4 个 tests，均带 source monitor/ref/SB/cov plusargs。 |
| `mmu_verification/simu/ptw_p1_list` | 加入 `test_ptw_pde_accerr_priority_type_id_001` 和 `test_ptw_pde_pmp_clear_repopulate_001`。 |

新增 stage9 helper：

| Helper | 用途 |
| --- | --- |
| `stage9_close/partial/open/summary()` | 打印 `PTW_STAGE9_CLOSURE` 和 `PTW_STAGE9_TEST_SUMMARY` metadata。 |
| `stage9_wait_for_pde_accerr()` | 使用 probe 检查 PDE direct accerr type/id stable 和 grant。 |
| `stage9_expect_no_pde_accerr_window()` | 检查 idle/fixed window 内无 PDE direct accerr。 |
| `stage9_expect_no_pde_accerr_for_req()` | 等目标 `{type,id,vpn}` 被 PTW accept 并完成，期间要求无 PDE direct accerr。 |
| `stage9_wait_for_ptw_mem_accept()` | priority test 中先确认独立 PTW memory bus-error 压力请求已被 accept，再发起 PDE direct accerr。 |
| `stage9_cp0_tlb_allinv()` | 使用现有 CP0/TLB invalidation path 触发 PDE clear。 |

测试构造：

| Requirement | 实现方式 | 当前证据状态 |
| --- | --- | --- |
| `PTW-ADD-042` / `PDE-TP-017` | 先用 LOAD 建 locked R-only L2 PDE；后续 STORE 同 L2 tag 触发 PDE direct accerr，同时驱动一个独立 PTW memory bus-error 压力窗口；test 自检 direct accerr `type=STORE/id=0x2c` stable 并看到 grant。 | implemented；同周期 priority 候选必须由 `PTW-SVA-ARB-010` cover 命中作为退出证据。 |
| `PTW-ADD-043` / `PDE-TP-018` / `PTW-FLOW-028` | 四个子场景覆盖 effective M 下 `lock=0/type bits deny` 的 L1/L2 bypass，以及 `lock=1/type bit deny` 的 L1 deny miss 和 L2 direct accerr。 | implemented；source SB `mmode_bypass/mmode_lock_deny` coverage 和 `PTW-SVA-PDE-011/012/013/017` cover 待仿真收集。 |
| `PTW-ADD-044` / `PDE-TP-019` | `vpn[2:1]=0` reset-tag 场景和 L2 stale tag after clear 场景；request-scoped helper 等目标请求被 accept/completed，期间要求无 `L2PDE_entry_acc_err/PDE_cache_acc_err_vld`。 | implemented；`PTW-SVA-PDE-014` 是最终 valid-gate structural evidence。 |
| `PTW-ADD-045` / `PDE-TP-010/016` | 先建 locked W-only L2 entry，clear 后将 PMP flag 改为 load-allow，后续 LOAD 同 L2 tag 必须不复用旧 locked-W pmpflg，并通过新 walk/repopulate 使用 MBUF pmpflg。 | implemented，标 partial evidence：真实 PMP config update clear 仍受 `tb_top.sv` 中 `pmp_regs_update` tie-off 限制，本 test 使用可用 `regs_ptw_clr/tlboper` clear path。 |

实现边界：

| 边界 | 结果 |
| --- | --- |
| 新增文件数量 | 4 个 test 文件，低于 15 文件拆分阈值；未创建临时阶段拆分计划。 |
| Stage 10/signoff | 未修改 signoff gate、closure matrix、P0/P1 全量签核报告。 |
| RTL | 未修改 RTL；`doc/ptw_rtl_debug.md` 中已记录的 RTL bug 仍作为外部限制存在。 |
| PMP config update clear | `pmp_regs_update_probe` 仍为 `1'b0`，`PTW-ADD-045` 不能声明真实 PMP-update clear 完全关闭。 |

## 当前未关闭项

| Item | 后续阶段 |
| --- | --- |
| `PDE-TP-013..016`、`PTW-FLOW-024..027`、`PTW-ADD-037..041` directed tests 已实现，run log/source-SB/SVA cover 证据待收集；`PTW-ADD-039/040` 保留 partial evidence 限制说明 | 阶段 8/10 |
| `PDE-TP-017..019`、`PTW-FLOW-028`、`PTW-ADD-042..045` directed tests 已实现，run log/source-SB/SVA cover 证据待收集；`PTW-ADD-045` 保留 pmp_regs_update tie-off 限制说明 | 阶段 9/10 |
| `pmp_regs_update` testbench tie-off 未处理 | 后续涉及 PMP config clear/repopulate 的阶段 |
| Regression/signoff list、CSV、gate、报告尚未冻结 | 阶段 10 |

## 已执行检查汇总

| 检查 | 结果 |
| --- | --- |
| 阶段 0 RTL/UVM probe 审计 `rg` | pass |
| 阶段 1 enum/helper/transaction 字段 `rg` | pass |
| 阶段 1 SV/SVH 修改边界 | pass，仅 `ptw_source_types.svh` |
| 阶段 2 probe/monitor 字段 `rg` | pass |
| 阶段 2 RTL 被观测层级信号存在性 `rg` | pass |
| 阶段 2 ref/SB/SVA/test 边界 | pass，无相关文件修改 |
| 阶段 3 model 字段/API/reason `rg` | pass |
| 阶段 3 旧 ref model 调用点兼容性检查 | pass，仍为旧 `lookup()` 和 3 参数 update 调用 |
| 阶段 3 ref/SB/monitor/SVA/test 边界 | pass，无相关文件修改 |
| 阶段 4 ref model pmpflg/direct-accerr 关键词 `rg` | pass |
| 阶段 4 SV/SVH 修改边界 | pass，仅 `ptw_source_ref_model.svh` |
| 阶段 4 scoreboard/SVA/test 边界 | pass，无相关文件修改 |
| 阶段 5 scoreboard pmpflg/no-extra-LSU 关键词 `rg` | pass |
| 阶段 5 SV/SVH 修改边界 | pass，仅 `ptw_source_sb.svh` 和必要 `mmu_env.svh` fanout |
| 阶段 5 test/SVA/regression 边界 | pass，无相关文件修改 |
| 阶段 6 SVA ID/banner `rg` | pass，`PTW-SVA-PDE-011..017`、`PTW-SVA-ARB-010..012` 均可检索 |
| 阶段 6 修改边界 | pass，仅 `mmu_pde_cache_sva.sv`、`mmu_ptw_top_sva.sv`、必要 `tb_top.sv` bind |
| 阶段 6 directed/ref/SB/regression 边界 | pass，无 test/ref/SB/regression list 修改 |
| 阶段 6 SVA standalone syntax | pass，`vlog -sv mmu_pde_cache_sva.sv mmu_ptw_top_sva.sv` 为 0 errors / 0 warnings |
| 阶段 7 helper 关键词 `rg` | pass，6 个 helper 和 `PTW_STAGE7_HELPER` metadata 均可检索 |
| 阶段 7 旧 PDE tests pmpflg/permission-qualified metadata `rg` | pass，旧 hit/miss/replacement/clear/bug wrapper 均有新语义描述或 all-allow 前提 |
| 阶段 7 修改边界 | pass，仅 test/bug wrapper 和 directed base；无 regression/signoff 修改 |
| 阶段 8 新 test/list/suite 关键词 `rg` | pass，5 个 test 均已在 `ptw_tests_suite.svh` 和 `ptw_pde_pmpflg_list` 中出现 |
| 阶段 8 修改边界 | pass，仅阶段 8 directed tests、suite/list/progress 相关接入；未新增阶段 9 tests，未修改 signoff gate |
| 阶段 8 `stage8_map_*` 调用参数风格 | pass，阶段 8 新增 test 中 `stage8_map_2m_and_read_fst` / `stage8_map_4k_and_read_path` 调用已统一为 named argument，避免 SV positional/named 混用 |
| 阶段 8 `git diff --check` | pass，仅有 Git line-ending warning |
| 阶段 9 新 test/list/suite 关键词 `rg` | pass，4 个 test 均已在 `ptw_tests_suite.svh`、`ptw_pde_pmpflg_list` 和进度文档中出现；priority/clear 两个 P1 tests 已在 `ptw_p1_list` 中出现 |
| 阶段 9 修改边界 | pass，仅阶段 9 directed tests、suite/list/progress 接入；未修改 signoff gate、closure matrix、RTL |
| 阶段 9 request-scoped no-direct-accerr/helper | pass，`stage9_expect_no_pde_accerr_for_req()` 可检索，并用于 valid-gate 与 clear/repopulate 场景；`stage9_wait_for_ptw_mem_accept()` 可检索，并用于 priority 场景 |
| 阶段 9 `git diff --check` | pass，仅有 Git line-ending warning |
| `git diff --check` | pass，仅有 Git line-ending warning |
| `make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke` | blocked，当前 PowerShell 环境找不到 `make` |
| `make -C mmu_verification run_check ...` | blocked，当前 PowerShell 环境找不到 `make` |

## 退出标准检测命令

```powershell
# 文档合并和阶段进度文件删除检查
Get-ChildItem -Path doc\ptw_uvm_review -Filter "*progress*.md" | Select-Object -ExpandProperty Name
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_all_stages_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage0_probe_map.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage0_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage1_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage2_progress.md
Test-Path doc\ptw_uvm_review\ptw_pde_cache_pmpflg_stage3_progress.md

# 阶段 0 到 3 关键内容可追溯检查
rg -n "PMPFLG_STAGE_DONE|stage=0|stage=1|stage=2|stage=3|stage=4|blocked|make" doc\ptw_uvm_review\ptw_pde_cache_pmpflg_all_stages_progress.md
rg -n "ptw_src_pde_reason_e|ptw_src_access_src_e|ptw_src_pde_pmp_allow|pde_direct_accerr|cached_l1pmpflg" mmu_verification\testbench\env\ptw_source_types.svh
rg -n "pde_cache_update_l1pmpflg|pde_cache_update_l2pmpflg|pde_cache_acc_err|ptw_mbuf_twu_pmpflg|ptw_twu_mbuf_pmpflg" mmu_verification\testbench\env\mmu_dut_probes_if.sv mmu_verification\testbench\top\tb_top.sv mmu_verification\testbench\env\ptw_source_monitor.svh
rg -n "l1pmpflg|l2pmpflg|lookup_detail|pde_lookup_result|direct_accerr|L2_L.*DENY" mmu_verification\testbench\env\ptw_pde_cache_model.svh
rg -n "pde_direct_accerr|PDE_CACHE_PMP_DENY|pde_l1_pmp|pde_l2|lookup_detail|effective_machine|commit_update_with_pmpflg|record_predicted_pde_update|pde_update_match|pde_mmode" mmu_verification\testbench\env\ptw_source_ref_model.svh
rg -n "PTW_SOURCE_SB_PDE_PMP_COVERAGE|no_extra_lsu|access_src|pde_reason|pde_direct_accerr|af_pde|af_ctx" mmu_verification\testbench\env\ptw_source_sb.svh mmu_verification\testbench\env\mmu_env.svh
rg -n "PTW-SVA-PDE-011|PTW-SVA-PDE-012|PTW-SVA-PDE-013|PTW-SVA-PDE-014|PTW-SVA-PDE-015|PTW-SVA-PDE-016|PTW-SVA-PDE-017|PTW-SVA-ARB-010|PTW-SVA-ARB-011|PTW-SVA-ARB-012" mmu_verification\testbench\top
rg -n "bind PDE_cache|L1PDE_tag_hit|L2PDE_tag_hit|L1PDE_l1pmpflg|L2PDE_l1pmpflg|L2PDE_l2pmpflg" mmu_verification\testbench\top\tb_top.sv
rg -n "ptw_make_pmpflg|ptw_config_page_table_pmp_region|ptw_prime_l1_pde_cache_with_type|ptw_prime_l2_pde_cache_with_type|ptw_drive_source_req_by_type|ptw_expect_no_ptw_mem_req_window|PTW_STAGE7_HELPER" mmu_verification\testbench\test\ptw_tests\ptw_source_directed_base.svh
rg -n "pmpflg|permission-qualified|tag-only|direct accerr|PLRU|stale pmpflg|all-allow" mmu_verification\testbench\test\ptw_tests\test_ptw_l1_pde_hit.svh mmu_verification\testbench\test\ptw_tests\test_ptw_l2_pde_hit_direct.svh mmu_verification\testbench\test\ptw_tests\test_ptw_l1_pde_miss_walk.svh mmu_verification\testbench\test\ptw_tests\test_ptw_l2_pde_miss_walk.svh mmu_verification\testbench\test\ptw_tests\test_pde_cache_l1_single_entry.svh mmu_verification\testbench\test\ptw_tests\test_pde_cache_l2_single_entry.svh mmu_verification\testbench\test\ptw_tests\test_mmu_pde_cache_hit_l2_skip_scd.svh mmu_verification\testbench\test\ptw_tests\test_mmu_pde_cache_hit_l3_skip_thd.svh mmu_verification\testbench\test\ptw_tests\test_mmu_pde_cache_full_miss_full_ptw.svh mmu_verification\testbench\test\ptw_tests\test_ptw_l1_pde_cache_replace.svh mmu_verification\testbench\test\ptw_tests\test_ptw_l2_pde_cache_replace.svh mmu_verification\testbench\test\ptw_tests\test_pde_cache_clear_on_ptw_reset.svh mmu_verification\testbench\test\bug_hunt_tests\test_bug_001_twu_fst_fetch_type.svh
git diff --name-only -- mmu_verification\testbench\test mmu_verification\simu doc\ptw_uvm_review
vlog -sv mmu_verification\testbench\top\mmu_pde_cache_sva.sv mmu_verification\testbench\top\mmu_ptw_top_sva.sv

# 工作区和格式检查
git status --short
git diff --check

# 阶段 9 静态接入检查
rg -n "test_ptw_pde_accerr_priority_type_id_001|test_ptw_pde_mmode_lock_matrix_001|test_ptw_pde_l2_accerr_valid_gate_001|test_ptw_pde_pmp_clear_repopulate_001" mmu_verification\testbench\test\ptw_tests mmu_verification\simu doc\ptw_uvm_review\ptw_pde_cache_pmpflg_all_stages_progress.md
rg -n "PTW_STAGE9|stage9_expect_no_pde_accerr_for_req|stage9_wait_for_ptw_mem_accept|PTW-ADD-042|PTW-ADD-043|PTW-ADD-044|PTW-ADD-045|PDE-TP-017|PDE-TP-018|PDE-TP-019|PTW-FLOW-028" mmu_verification\testbench\test\ptw_tests\test_ptw_pde_accerr_priority_type_id_001.svh mmu_verification\testbench\test\ptw_tests\test_ptw_pde_mmode_lock_matrix_001.svh mmu_verification\testbench\test\ptw_tests\test_ptw_pde_l2_accerr_valid_gate_001.svh mmu_verification\testbench\test\ptw_tests\test_ptw_pde_pmp_clear_repopulate_001.svh doc\ptw_uvm_review\ptw_pde_cache_pmpflg_all_stages_progress.md
rg -n "test_ptw_pde_accerr_priority_type_id_001|test_ptw_pde_mmode_lock_matrix_001|test_ptw_pde_l2_accerr_valid_gate_001|test_ptw_pde_pmp_clear_repopulate_001" mmu_verification\testbench\test\ptw_tests\ptw_tests_suite.svh mmu_verification\simu\ptw_pde_pmpflg_list mmu_verification\simu\ptw_p1_list

# 阶段 9 环境具备 make 后再执行编译/运行检查
make -C mmu_verification build TEST_NAME=test_ptw_pde_accerr_priority_type_id_001
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_accerr_priority_type_id_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_mmode_lock_matrix_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_accerr_valid_gate_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_pmp_clear_repopulate_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make regress LIST=simu/ptw_pde_pmpflg_list REGRESS_MODE=run_check REGRESS_NAME=ptw_pde_pmpflg_stage9 REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1

# 阶段 7/8 历史检查，环境具备 make 后按需回归
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification build TEST_NAME=test_ptw_l1_pde_hit
make -C mmu_verification run_check TEST_NAME=test_ptw_l1_pde_hit SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_l2_pde_hit_direct SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_pde_cache_l1_single_entry SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_pde_cache_l2_single_entry SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_mmu_pde_cache_hit_l2_skip_scd SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

预期文档检查结果：

| 命令 | 预期 |
| --- | --- |
| `Get-ChildItem ... "*progress*.md"` | 只显示 `ptw_pde_cache_pmpflg_all_stages_progress.md`。 |
| `Test-Path ... all_stages_progress.md` | `True` |
| `Test-Path ... stage0_probe_map.md` | `True` |
| `Test-Path ... stage0_progress.md` | `False` |
| `Test-Path ... stage1_progress.md` | `False` |
| `Test-Path ... stage2_progress.md` | `False` |
| `Test-Path ... stage3_progress.md` | `False` |

## 已合并并删除的阶段进度文件

以下阶段独立进度文件内容已合并到本文档，并按用户要求删除：

| 文件 | 合并状态 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_progress.md` | merged and removed |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage1_progress.md` | merged and removed |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage2_progress.md` | merged and removed |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage3_progress.md` | merged and removed |
