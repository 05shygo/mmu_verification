# L2TLB UVM Phase 6/7 进度

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：L2TLB UVM 后续实现进度与门禁跟踪
> 搭建计划：`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md`
> 规格来源：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 日期：2026-05-23

## 1. 文档阶段状态

Phase 6/7 最初只创建并 review 后续实现的规划/进度文档。2026-05-23 已按 BuildPlan 完成 Phase6C scoreboard/helper core implementation、Phase6D SVA/bind implementation、Phase6E directed/negative infrastructure implementation、Phase6F RRPV/wbuf debug implementation 和 Phase6G closure infrastructure implementation。Phase6G default manifest/scanner gate 已 PASS：timeout/fairness、TLBOP/PTW LSU protocol 和 PTW source-specific harness 均已关闭；negative injector 和 exact RRPV/wbuf 项仍作为 waiver/future follow-up，不误标为已实现功能覆盖。

| 项目 | 路径 | 状态 | 说明 |
| --- | --- | --- | --- |
| Phase 6 BuildPlan | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | 已创建/已中文化 | 后续实现蓝图；已补充 6A~6G 严格退出门禁。 |
| Phase 6/7 Progress | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` | 已创建/已中文化 | 后续实现 tracker；已增加门禁和证据记录格式；Phase 6C/6D/6F/6G 已更新为 implementation complete，Phase6E 仍为 `Implemented-open`。 |
| Phase 6B progress record | 本文件第 2、4、6、7、9 节 | Complete-doc | 已记录 6B wrapper/metadata 对齐进度、逐组 TP 状态、scenario ID baseline、证据行和 wrapper 名称不可作为关闭证据的 issue。 |
| Phase 6C progress record | 本文件第 2、4.3、6、7、9 节 | Complete | 已记录 6C scoreboard/ref-model inventory、模型契约、TP/checker 分组映射、实现文件、运行证据和剩余 closure 边界。 |
| Phase 6D progress record | 本文件第 2、5、6、7、8、9 节 | Complete | 已记录 6D SVA/bind 实现、`L2TLB_SVA_001..024` 逐条 implemented/deferred/future 状态、assertion-enabled evidence、cover hole、scope waiver/future 和剩余 closure issue。 |
| Phase 6E progress record | 本文件第 2、4.4、6、7、8、9 节 | Implemented-open | 已实现 6E base/suite/wrappers/run lists、shadow-delta trigger gate、directed/negative/debug evidence；timeout/fairness targeted stress 和 PTW source-specific harness 已 root-caused/关闭，negative injector 和 RRPV exact 仍为 open/future。 |
| Phase 6F progress record | 本文件第 2、4.5、5、6、7、8、9 节 | Complete | 已实现并记录 6F RRPV wbuf debug SVA/bind、`phase6f_class` metadata、debug run list、targeted run evidence、cover hit/hole 和 exact replacement/RRPV future 边界。 |
| Phase 6G progress record | 本文件第 2、4.6、6、7、9 节 | Complete | 已实现并记录 6G L2TLB-specific run list、evidence manifest、closure scanner、replay flow、closure report、root-cause closure 和 default PASS gate；waiver/future rows 保留后续风险边界。 |
| UVM/RTL/Makefile/testbench 代码 | Phase6C UVM scoreboard/helper；Phase6D SVA/bind；Phase6E directed/negative tests；Phase6F RRPV wbuf/arbiter debug SVA/metadata/run-list；Phase6G run-list/manifest/script closure flow | 已修改 | 已新增 Phase6C `mmu_l2tlb_txn_shadow`；Phase6D 扩展 `mmu_arb_sva`、`credit_sva`、`mmu_l2tlb_rrpv_sva`，新增 `mmu_l2tlb_mb_sva`；Phase6E 新增 `l2tlb_phase6e_*` base/suite/wrappers/run lists 并接入 `test_pkg.sv`；Phase6F 新增 `mmu_l2tlb_rrpv_wbuf_sva`、参数化 bind、arbiter wbuf-full no-wrong-grant/PTW-writeback guard、coverage exclude、debug list 和 metadata；Phase6G 新增 `l2tlb_phase6g_*` run lists、manifest、scanner 和 replay scripts；未修改 DUT/RTL。 |
| 后续实现批准 | Phase6C/6D/6E/6F/6G | 已完成 core/infrastructure/debug/closure-tool implementation | Phase6G default scanner 已 `STATUS=PASS`；剩余 negative injector、RRPV exact/wbuf full 项保持 waiver/future follow-up。 |

## 2. 后续子阶段进度矩阵

状态值：`Not started`（未开始）、`Planned`（已规划）、`In progress`（进行中）、`Blocked`（阻塞）、`Review`（待 review）、`Complete-doc`（文档交付完成，未声明行为实现完成）、`Implemented-open`（实现已落地但仍有未关闭质量问题）、`Complete`（实现和证据完成）、`Waived`（已 waiver）、`Future`（未来阶段）。

| 子阶段 | 标题 | 状态 | Owner | 计划交付物 | 退出准则 | 回归/证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 6A | 可观测性与 monitor 就绪 | Complete | TBD | Probe/monitor inventory；missing-signal decision table；stable consumer list 已补入 BuildPlan；本轮未新增或改动 probe/RTL/UVM 行为 | `make comp` 通过；未发现未批准 `$root` checker path；现有 L2/ReqQ/MB/PTW/PFU/TLBOP probe consumer 已记录；future/debug 项未误标为 covered | `mmu_verification/output/logs/comp_all.log` |
| 6B | 场景 ID、wrapper 与 metadata 对齐 | Complete-doc | TBD | `L2TLB_TP_001..058` 初始映射、scenario ID baseline、wrapper inventory、metadata contract 和 test-case sufficiency 结论已补入 BuildPlan/Progress；本轮未新增或修改 wrapper/include/仿真列表 | 每个测试点已有稳定 `L2TLB_SCN_*`、wrapper class、candidate/new-wrapper/checker 状态；明确现有 test case 不足以完成覆盖关闭，wrapper 名称不能作为关闭证据 | `L2TLB_UVM_Phase6_BuildPlan.md` Phase 6B；本文件第 4 节 scenario registry；第 4.2 节 sufficiency gap；Phase6B 文档检查命令 |
| 6C | Scoreboard 与 reference model 扩展 | Complete | TBD | 已新增 `mmu_l2tlb_txn_shadow` 并接入 env、translation/invalidate scoreboard 和 PFU monitor path；覆盖 PTW refill shadow、L2 final 可见比较、INV*/CP0 all-inv、reset/abort/control epoch、PFU classifier、payload-ignore 和 mismatch taxonomy | `make comp_fast`、tag/refill directed smoke 和 PFU payload-ignore smoke 均通过；Phase6C 不声明完整 TP coverage closure，剩余 TLBOP exact decode、ReqQ payload no-cross、完整 MB/OOO、timeout/fairness 和 RRPV exact model 继续 open | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；本文件第 4.3/6/7 节 |
| 6D | SVA、bind 与 waiver 实现 | Complete | TBD | 已扩展 `mmu_arb_sva`、`credit_sva`、`mmu_l2tlb_rrpv_sva`，新增并 bind/include `mmu_l2tlb_mb_sva`；已记录 `L2TLB_SVA_001..024` implemented/deferred/future 状态、scope waiver/future 和 cover hole | `make comp_fast` 通过；四条 assertion-enabled smoke 通过；must SVA 的稳定 bind 子项已有 pass evidence；未实现或未触发项已进入 6E/6F/6G 或 future/waiver 跟踪 | `mmu_verification/output/logs/comp_fast.log`；`test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`test_pipe2_prefetch_err_63003.log`；`test_mmu_dir_l2tlb_inv_all_63002.log`；`test_mmu_rand_l2tlb_bank_conflict_multi_source_63004.log`；本文件第 5/6/7/8 节 |
| 6E | Directed 与 negative tests | Implemented-open | TBD | 已新增 `l2tlb_phase6e_test_base.svh`、`l2tlb_phase6e_tests.svh`、`l2tlb_phase6e_suite.svh`、5 个 targeted run list，并接入 `test_pkg.sv`；positive/debug trigger 基于 Phase6C L2TLB shadow delta | `make comp_fast` 通过；directed P0、negative 分类、RRPV debug 通过；timeout/fairness targeted stress 已 root-caused 并复跑 clean | `mmu_verification/output/logs/comp_fast.log`；`test_l2tlb_p6e_*_64001.log`；本文件第 4.4/6/7/8 节 |
| 6F | RRPV 与 replacement 重分类 | Complete | TBD | 已新增 `mmu_l2tlb_rrpv_wbuf_sva`、参数化 bind、arbiter wbuf-full no-wrong-grant/PTW-writeback guard、compile list/coverage exclude、`phase6f_class` metadata 和 `simu/l2tlb_phase6f_debug_rrpv_list`；保留 v1/debug/future 分类 | `make comp_fast` 通过；Phase6F targeted run seed 65001 通过；`L2TLB_SVA_022` debug no-overflow/no-underflow/accounting/no-wrong-grant 基线有 assertion-enabled evidence；exact victim/RRPV/latest-wins 不进 v1 closure，未命中 debug cover 转 6G | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；本文件第 4.5/5/6/7/8 节 |
| 6G | Coverage、regression 与 closure gate | Complete | TBD | 已新增 `simu/l2tlb_phase6g_*` run lists、`l2tlb_phase6g_evidence_manifest.tsv`、`scripts/l2tlb_phase6g_closure.py` 和 `scripts/l2tlb_phase6g_replay.py`；closure report flow 已可复现 | Scanner 能逐 row 检查 required report/counter/cover、UVM summary、bad log pattern 和 issue/waiver/future linkage；default gate 无 blocked row并 PASS | `mmu_verification/output/regression/l2tlb_phase6g_closure/closure_report.md`；manifest；smoke 3/3、targeted 更新后 5/5、negative 1/1、debug 1/1；default scanner `STATUS=PASS` |

### Phase 6B 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6B 子阶段状态 | Complete-doc | 第 2 节 6B row | 仅表示文档交付完成；不声明 wrapper、checker、coverage 或 regression 已实现关闭。 |
| `L2TLB_TP_001..058` 初始进度 | Complete-doc | 第 4 节测试点跟踪表和 scenario registry | 58 个 TP 已按 reset/ReqQ/tag/PTW/PFU/TLBOP/RRPV/negative/closure 分组记录状态、稳定 scenario ID 和后续证据要求。 |
| wrapper inventory 风险 | Closed-doc | 第 7 节 `L2TLB-P6-ISSUE-004` | 已明确现有 `l2tlb_tests/`、`tlbop_tests/` wrapper 和 Phase9 `TC-*` metadata 只能作为候选入口，不能作为关闭证据。 |
| test case 充分性结论 | Complete-doc | 第 4.2 节；第 7 节 `L2TLB-P6-ISSUE-005` | 已明确现有 test case 不足以完成 `L2TLB_TP_001..058` 覆盖关闭，并列出必须新增/加强的 wrapper、checker、SVA、negative suite 和 coverage closure 内容。 |
| evidence 留痕 | Complete-doc | 第 6 节 Phase 6B docs row | 已记录 Phase6B 使用的只读检查命令；本轮未运行仿真、未修改行为代码。 |
| 后续执行入口 | Planned | 第 4 节和 BuildPlan Phase 6B | 6C/6D/6E/6G 必须补 trigger evidence、checker/SVA evidence、run log、coverage report 或 waiver。 |

### Phase 6C 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6C 子阶段状态 | Complete | 第 2 节 6C row；第 6 节 Phase 6C implementation row | 已实现核心 scoreboard/helper 并记录 compile/smoke evidence；不声明 UVM 功能 coverage 全关闭。 |
| 当前 scoreboard/ref-model inventory | Complete | 第 4.3 节；BuildPlan Phase 6C | `mmu_l2tlb_txn_shadow` 作为邻近 helper 接入 `mmu_translation_sb`、`mmu_invalidate_sb` 和 env config_db；`mmu_credit_sb`/`mmu_ref_model` 的剩余边界仍按 baseline 记录。 |
| coverage sufficiency 结论 | Complete | 第 4.3 节；第 7 节 `L2TLB-P6-ISSUE-006`/`011` | Phase6C core helper 足以提供 PTW refill、PFU payload-ignore、INV/epoch 和可见 L2 hit compare 的 evidence sink；完整 TP closure 仍需后续 directed/SVA/coverage。 |
| model contract | Complete | 第 4.3 节；BuildPlan Phase 6C | 已实现 L2 entry shadow v1、PTW/PFU owner path、payload-ignore、epoch 和 mismatch taxonomy；ReqQ/arbiter payload no-cross、full MB/OOO、timeout/fairness 和 exact TLBOP read/write decode 保持 follow-up。 |
| TP/checker 映射 | Complete | 第 4.3 节 | 已把 Phase6B TP/scenario 组映射为 Phase6C core implemented、SVA/direct follow-up 或 debug/future；不把 helper smoke 误计为 58 个 TP 全覆盖。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6C implementation row | 已记录 `git diff --check`、`make comp_fast`、tag/refill smoke、PFU payload-ignore smoke、INVALL seed 63002 smoke、summary counters 和 log status。 |

### Phase 6D 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6D 子阶段状态 | Complete | 第 2 节 6D row；第 6 节 Phase 6D implementation row | 已实现稳定 bind SVA 并记录 assertion-enabled compile/smoke evidence；不声明所有 cover 或 TP closure 全关闭。 |
| Phase 3 SVA 来源 | Complete | 第 5 节；BuildPlan Phase 6D | 已以 `l2tlb_function_description.md` 第 7 章 `L2TLB_SVA_001..024` 为来源，并逐条标注 implemented/deferred/future。 |
| 当前 SVA/bind inventory | Complete | 第 5.1 节；第 6 节 Phase 6D implementation row | 已检查并修改 `mmu_l2tlb_rrpv_sva.sv`、`mmu_arb_sva.sv`、`credit_sva.sv`，新增 `mmu_l2tlb_mb_sva.sv`，同步 `tb_top.sv` bind、`Files.f` include 和 `cov_hier.cfg`。 |
| must/debug/future 状态 | Complete | 第 5.2 节 | 已逐条记录 24 个 SVA 的 implemented/deferred/future 状态、bind/sample source、assertion evidence、cover evidence 和 waiver/future。 |
| sufficiency 结论 | Complete with scoped gaps | 第 5.1/5.2 节；第 7 节 `L2TLB-P6-ISSUE-012` | 稳定 bind 子项已实现；full reset-inv、TLBOP lifecycle、control hazard、RRPV wbuf/exact replacement 仍需后续 directed/debug/future closure。 |
| waiver/bind 规则 | Complete | 第 5.3 节；第 8 节 waiver/future rows | 已记录 `must` SVA 的关闭状态、scope waiver/future 和后续 owner；debug/future 不误计 v1 must closure。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6D docs/implementation rows | 已记录只读检查、`make comp_fast`、四条 smoke、cover hits、未命中 cover 和 log status。 |

### Phase 6E 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6E 子阶段状态 | Implemented-open | 第 2 节 6E row | Phase6E directed/negative infrastructure 已实现；timeout/fairness targeted stress 和 PTW source-specific harness 已关闭；negative injector 和 RRPV exact 仍不声明完整 coverage closure。 |
| 当前 test inventory | Complete | 第 4.4 节；BuildPlan Phase 6E | 已检查 `l2tlb_tests`、`tlbop_tests`、`flush_tests`、`ptw_tests`、`perf_tests`、`err_tests`、`bug_hunt_tests`、`ptw_lsu_protocol_tests` 和可复用 sequence，并据此新增 Phase6E wrappers/run lists。 |
| sufficiency 结论 | Partially closed / Open follow-up | 第 4.4 节；第 7 节 `L2TLB-P6-ISSUE-008` | 已补 directed P0、PTW disabled/fault/access-error source-specific closure、negative 分类、RRPV debug、strict trigger gate 和 timeout/fairness root-cause closure；bad completion/control-hazard injector 仍未关闭。 |
| directed/negative matrix | Implemented-open | 第 4.4 节；第 6 节 Phase 6E implementation row | Reset/ReqQ/PFU/TLBOP/PTW source directed、negative classification、timeout/fairness、RRPV debug 均有 wrapper/run-list；bad-completion/control-hazard negative 项仍为 deferred/waiver。 |
| OOO PTW 分类 | Complete / Deferred | 第 4.4 节；第 8 节 `L2TLB-WAIVE-P6E-002` | `ptw_mem_ooo_rsp_seq` warning-only、`test_mbuf_ooo_response` obsolete 的结论保持有效；bad completion/OOO negative 需要 approved injector 后再关闭。 |
| metadata/run-list 规则 | Implemented | `l2tlb_phase6e_test_base.svh`；`simu/l2tlb_phase6e_*_list` | 已实现 scenario metadata、trigger/checker/waiver token、positive/negative/debug/timeout run-list 分类。 |
| docs baseline 留痕 | Superseded by implementation | 第 6 节 Phase 6E docs row | 只读 inventory 记录保留为历史 baseline；实际 Phase6E 状态以 implementation row、issue 013 和 waiver/deferred rows 为准。 |
| 6E 实现状态 | Implemented-open | 第 2 节 6E row；第 6 节 Phase 6E implementation row | 已新增 Phase6E base/suite/wrappers/run lists 并接入 `test_pkg.sv`；directed P0、negative 分类、RRPV debug 和 timeout/fairness closure 有 targeted run evidence。 |
| trigger gate 实现 | Complete | `l2tlb_phase6e_test_base.svh`；第 6 节 evidence | Positive/debug wrapper 只有在 Phase6C L2TLB shadow counter 出现真实 delta 时才发 `L2TLB_PHASE6E_TRIGGER`；sequence 计划本身不算 trigger。 |
| run-list 证据 | Implemented-open | `simu/l2tlb_phase6e_*_list`；第 6 节 evidence | `l2tlb_phase6e_directed_p0_list` 4/4 pass；`l2tlb_phase6e_negative_list` 2/2 pass 但为分类/waiver；`l2tlb_phase6e_debug_rrpv_list` 1/1 pass；`test_l2tlb_p6e_timeout_fairness_release` seed 64001 root-cause 后单测复跑 pass。 |
| timeout/fairness closure | Closed | 第 7 节 `L2TLB-P6-ISSUE-013` | `test_l2tlb_p6e_timeout_fairness_release` seed 64001 初始失败已定位为 testbench/checker 问题；修复后复跑 `UVM_ERROR=0`、shadow mismatch=0、back-to-back DTLB cover 命中。 |

### Phase 6F 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6F 子阶段状态 | Complete | 第 2 节 6F row；第 6 节 Phase 6F implementation row | 已实现 RRPV wbuf debug SVA/bind、arbiter wbuf-full guard、metadata/run-list 并有 compile/targeted run evidence；不声明 exact replacement/RRPV 或 wbuf full/latest-wins/same-cycle/PTW-writeback coverage 全关闭。 |
| 当前 RRPV/replacement inventory | Complete-doc | 第 4.5 节；BuildPlan Phase 6F | 已检查 RRPV wrapper、TLBWR RRPV wrapper、perf/bug wrapper、`mmu_l2tlb_rrpv_sva`、probe/coverage 和相关 RTL microarchitecture。 |
| v1/debug/future 分类 | Complete | 第 4.5 节；BuildPlan Phase 6F；`l2tlb_phase6e_test_base.svh` / `l2tlb_phase6e_tests.svh` | 已把 `L2TLB_TP_045..047`、`L2TLB_SVA_022..024` 分为 v1 functional visible、debug assertion/coverage 和 future exact model，并在 run log 输出 `L2TLB_PHASE6F_META/CLOSE`。 |
| sufficiency 结论 | Complete with scoped gaps | 第 4.5 节；第 7 节 `L2TLB-P6-ISSUE-009/014` | Basic wbuf accounting/no-overflow SVA 有 pass evidence；现有 RRPV wrapper 和 debug SVA 仍不足以关闭 exact init/aging/victim/latest-wins/full/same-cycle 行为。 |
| debug coverage plan | Implemented with cover holes | 第 4.5 节；第 6 节 Phase 6F implementation row | 已实现 push/pop/CAM/full/same-cycle/lookup-bypass 和 arbiter full-block/PTW-writeback cover。seed 65001 命中 push/pop/lookup-bypass；CAM-hit/full/full-release/same-cycle/arbiter full-block/PTW-writeback 为 0，转 6G targeted coverage。 |
| future exact item | Complete-doc | 第 4.5 节 | exact victim/free-way/max-RRPV、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass、PTW/TLBOP pending conflict 均保持 future。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6F implementation row | 已记录 `git diff --check`、`make comp_fast`、Phase6F targeted run、`check_sim_status.sh`、assertion/mismatch grep、shadow delta 和 cover hit/hole。 |

### Phase 6G 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6G 子阶段状态 | Complete | 第 2 节 6G row；第 6 节 Phase 6G implementation row | Run lists、manifest、scanner、replay 和 report flow 已实现；default manifest gate 无 blocked row并 PASS。 |
| 当前 infrastructure inventory | Implemented | 第 4.6 节；BuildPlan Phase 6G | 已复用 `run_test.py`/`check_sim_status.sh` 执行框架，并新增 L2TLB-specific manifest/scanner/replay；Makefile/RTL 未改。 |
| sufficiency 结论 | Complete with waiver/future | 第 4.6 节；第 7 节 `L2TLB-P6-ISSUE-010/015` | L2TLB-specific closure evidence 已可逐 row 检查；timeout/fairness 与 TLBOP `failed at` root-cause 均已关闭。 |
| coverage bin mapping | Complete with waiver/future | 第 4.6 节；BuildPlan Phase 6G；manifest | 已把 Phase6C/6E/6F evidence、waiver/future 和 closure rows 写入 manifest；PTW source-specific closure 已纳入 manifest，仍缺 negative injector 和 exact RRPV model。 |
| regression tiers | Implemented-open | 第 6 节 Phase 6G implementation row | Compile、smoke、targeted、negative、debug RRPV 均已运行；timeout/fairness seed 64001 已作为 manifest closure evidence 纳入。 |
| closure artifacts/checklist | Complete | `simu/l2tlb_phase6g_evidence_manifest.tsv`；`scripts/l2tlb_phase6g_closure.py`；closure report | 默认模式输出 `STATUS=PASS PASS=12 OPEN=0 FAIL=0 TOTAL=12`。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6G docs/implementation rows | 已记录命令、seed、log/report、root-cause closure、default gate 语义；未修改 DUT/RTL。 |

## 3. Phase 7 门禁签核矩阵

本表记录 Phase 7 已完成的文档化门禁，不代表 6A~6G 已执行。

| 门禁项 | 状态 | 证据 |
| --- | --- | --- |
| 6A 可观测性退出准则已细化 | Complete | `L2TLB_UVM_Phase6_BuildPlan.md` 第 3 节 |
| 6B 场景 ID/wrapper 退出准则已细化 | Complete | `L2TLB_UVM_Phase6_BuildPlan.md` 第 3 节 |
| 6C scoreboard mismatch 分类已定义 | Complete | 分类为 `RTL bug`、`UVM bug`、`spec gap`、`tooling issue`、`approved waiver` |
| 6D assertion fail 处理规则已定义 | Complete | 真 bug、误报、非法输入负向预期、disable/reset 条件错误 |
| 6E trigger evidence 要求已定义 | Complete | directed test 缺少场景触发证据不得关闭 |
| 6F RRPV v1/debug/future 边界已细化 | Complete | exact victim/RRPV 不作为 v1 pass/fail |
| 6G regression/coverage closure 门禁已细化 | Complete | compile、directed smoke、negative assertion、targeted L2TLB、coverage/SVA/log fallback |
| Phase 7 不修改行为代码 | Complete | 本阶段仅文档变更；需由 git diff 范围检查确认 |

## 4. 测试点跟踪模板

后续阶段在声明实现关闭前，必须为相关 `L2TLB_TP_xxx` 填写逐项记录。

| 测试点 ID | 优先级 | 分类 | 实现状态 | Wrapper / checker | Trigger evidence | Pass/fail evidence | 备注 / waiver |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `L2TLB_TP_001..003` | P0 | reset / UVM boundary | Mapped-doc | reset directed、metadata audit、`L2TLB_SVA_001/002` | reset 活跃窗口、post-reset 首笔请求、wrapper drive-interface 分类 | reset drain / stale-response checker；metadata audit report | 6B 只定义需求；TP003 不靠单个仿真关闭。 |
| `L2TLB_TP_004..011` | P0/P1 | ReqQ / arbiter | Existing-wrapper candidate / Needs checker | 现有 ReqQ、bank conflict wrapper；credit/type/payload/onehot checker | source alloc/issue/dealloc、pairwise/four-source conflict、payload sample | credit shadow、payload scoreboard、arbiter SVA/checker | wrapper 名称和 Phase9 `TC-*` 只能作候选。 |
| `L2TLB_TP_012..016` | P0/P1 | tag/data lookup | Existing-wrapper candidate / Debug candidate | 4K hit、2M/1G huge、cross-ASID、multi-hit wrapper；L2 entry shadow | ITLB/DTLB/PFU source、page-size/ASID/global/multi-hit bins | PA/PPN/flag compare；multi-hit legal-result classifier | multi-hit 不作为 normal single-hit evidence。 |
| `L2TLB_TP_017..027` | P0/P1 | MB / PTW | Existing-wrapper candidate / Needs new wrapper / Negative-only | MB alloc/full/issue wrapper；PTW disabled/fault/accerr/out-of-order/bad-ID directed；`L2TLB_SVA_009..013` | MB alloc/issue/full、ready stall、data/fault/accerr/bad-ID/out-of-order completion | MB/PTW ownership scoreboard；payload-stability SVA；negative assertion result | PTW consumer evidence 不能替代 L2 ownership evidence。 |
| `L2TLB_TP_028..033` | P0 | PFU | Needs new wrapper / Needs scoreboard rule | 新增 PFU MMU-off、MMU-on hit、PTW、flag fault、PMP/sysmap directed；PFU payload-ignore rule | PFU source、direct/hit/PTW/error bins | PFU final response compare；error payload ignored by rule | 当前主要缺口。 |
| `L2TLB_TP_034..044` | P0 | TLBOP / invalidate / abort | Existing-wrapper candidate / Needs new reset-abort wrapper | TLBP/TLBR/TLBWI/TLBWR/SFENCE wrappers；TLBOP lifecycle and stale-completion checker | all TLBOP types、INV* variants、reset during TLBOP、abort sent/unsent MB | L2 entry shadow、done ordering SVA、stale-completion checker | reset/abort epoch 未建前不得关闭。 |
| `L2TLB_TP_045..047` | P1/P2 | RRPV / replacement | Debug/Future | RRPV init/wbuf/victim wrappers；RRPV sampler；future exact model | refill/write init、wbuf pressure、replacement pressure bins | functional visible result；debug cover；future exact victim waiver | exact victim/RRPV/latest-wins 不作为 v1 closure blocker。 |
| `L2TLB_TP_048` | P1 | illegal input | Negative-only | 新增 negative suite；`L2TLB_SVA_003/004/018` | bad type、bad page size、bad ID、credit overflow | assertion/error handling expected | 不混入普通合法随机。 |
| `L2TLB_TP_049..050` | P0 | timeout / closure | Needs checker / Checker-only | timeout classifier；Phase6G closure manifest/scanner | PTW wait、MB retry、TLBOP scan、wbuf stall、all source/result bins | eventually-complete 分类；coverage/SVA/log 与 waiver 对齐 | `UVM_ERROR=0` 不能替代 trigger/closure evidence。 |
| `L2TLB_TP_051..054` | P0/P1 | ptw_on / tlboper_on / PFU mask / index | Existing-wrapper candidate / Needs PFU wrapper | bank conflict/skew wrappers；PFU mask directed；`L2TLB_SVA_019..021` | ptw_on stall、tlboper_on stall、prefetch_mask hit/error/retry release、selector/page-size bins | exclusion/release checker；index/bank sampler | PFU mask 是新增 directed 缺口。 |
| `L2TLB_TP_055..057` | P0 | MB partition / PTW OOO / PFU attrs | Needs new wrapper/checker | MB partition full split；PTW out-of-order completion；PFU truth-table directed | ITLB vs DTLB/PFU partition full、OOO data/fault/mixed、PMP/sysmap/MAEE combos | partition checker、composite-ID ownership、PFU attr compare | 比已有 MB/PFU 粗 wrapper 更细。 |
| `L2TLB_TP_058` | P1 | control hazard | Negative-only | 新增 SATP/ASID/MMU/PTW/control hazard negative suite；`L2TLB_SVA_017` | outstanding translation/PTW 期间 control write | assertion/error classification expected | 不作为正常功能 coverage。 |

规则：

- 不得因为存在相似名称的 wrapper 就把测试点标为 `Complete`。
- 完整记录必须同时包含 trigger evidence 和 checker/pass-fail evidence。
- Negative assertion-only 项不得混入普通随机功能回归。
- Future replacement/RRPV exact 项必须保持 `Future`，除非批准 exact reference model 阶段。

### 4.1 Phase 6B scenario ID baseline

本表是 Phase6B 在 Progress 中的可执行基线。`Candidate / required wrapper` 只说明后续实现入口，不是 coverage/pass 证据；所有 `Existing-candidate` 行仍必须在 6C/6D/6E/6G 补 trigger 和 pass/fail evidence 后才能关闭。

| Scenario ID | TP | Wrapper class | Candidate / required wrapper | Checker owner | 6B disposition |
| --- | --- | --- | --- | --- | --- |
| `L2TLB_SCN_RESET_COLD_001` | `L2TLB_TP_001` | `new_wrapper_required` | 新增 cold reset directed | reset drain checker + `L2TLB_SVA_001/002` | Missing wrapper；Phase6B 完成 ID 分配。 |
| `L2TLB_SCN_RESET_WARM_ACTIVE_002` | `L2TLB_TP_002` | `new_wrapper_required` | 新增 warm reset x lookup/PTW/TLBOP/PFU directed | reset epoch scoreboard + `L2TLB_SVA_001` | Missing wrapper；必须检查 stale completion。 |
| `L2TLB_SCN_UVM_BOUNDARY_AUDIT_003` | `L2TLB_TP_003` | `checker_sva_only` | wrapper metadata audit | audit checklist | Progress/BuildPlan 记录关闭；不声明功能覆盖。 |
| `L2TLB_SCN_REQQ_ITLB_ENTRY0_004` | `L2TLB_TP_004` | `existing_candidate` | `test_mmu_dir_l2tlb_reqq_arbitration_itlb_prior`、`test_mmu_rand_l2tlb_reqq_queue_depth_varied` | credit shadow | Candidate only；需 ITLB entry0 trigger。 |
| `L2TLB_SCN_REQQ_DTLB_LOAD_STORE_005` | `L2TLB_TP_005` | `existing_candidate` | `test_mmu_dir_l2tlb_reqq_dtlb_alloc_0`、`test_mmu_dir_l2tlb_reqq_dtlb_alloc_full` | credit/type shadow | Candidate only；load/store bins 必须分开。 |
| `L2TLB_SCN_REQQ_BYPASS_PAYLOAD_006` | `L2TLB_TP_006` | `existing_candidate` | ReqQ wrapper family | payload stability checker | Candidate only；需要 bypass trigger。 |
| `L2TLB_SCN_REQQ_MB_FULL_RETRY_007` | `L2TLB_TP_007` | `existing_candidate` | `test_mmu_dir_l2tlb_reqq_credit_full_no_return` | ReqQ lifetime checker | Candidate only；不能只看 wrapper 名称。 |
| `L2TLB_SCN_REQQ_CREDIT_RETURN_008` | `L2TLB_TP_008` | `existing_candidate` | `test_mmu_dir_l2tlb_reqq_credit_return_hit`、`test_mmu_dir_l2tlb_reqq_credit_return_refill` | credit accounting checker | Candidate only；fault return 仍缺 directed evidence。 |
| `L2TLB_SCN_ARB_ONEHOT_MULTI_SOURCE_009` | `L2TLB_TP_009` | `existing_candidate` | `test_mmu_rand_l2tlb_bank_conflict_multi_source` | arbiter onehot checker + `L2TLB_SVA_005` | Candidate only；需 onehot/pass evidence。 |
| `L2TLB_SCN_ARB_PRIORITY_FAIRNESS_010` | `L2TLB_TP_010` | `existing_candidate` | `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior`、`test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior` | priority/fairness checker | Candidate only；精确优先级需复核。 |
| `L2TLB_SCN_ARB_PAYLOAD_NO_CROSS_011` | `L2TLB_TP_011` | `checker_sva_only` | 新增 source payload scoreboard | payload scoreboard + `L2TLB_SVA_005/006` | Missing checker；wrapper 不足以关闭。 |
| `L2TLB_SCN_LOOKUP_ITLB_4K_HIT_012` | `L2TLB_TP_012` | `existing_candidate` | `test_mmu_dir_l2tlb_tag_match_4k_hit` | L2 entry shadow | Candidate only；必须证明 ITLB source。 |
| `L2TLB_SCN_LOOKUP_DTLB_4K_HIT_013` | `L2TLB_TP_013` | `existing_candidate` | `test_mmu_dir_l2tlb_tag_match_4k_hit` | transaction scoreboard | Candidate only；不能由 ITLB-only evidence 关闭。 |
| `L2TLB_SCN_LOOKUP_HUGE_SPLICE_014` | `L2TLB_TP_014` | `existing_candidate` | `test_mmu_dir_l2tlb_tag_match_2m_1g_huge` | PA splice checker | Candidate only；需要 2M/1G offset bins。 |
| `L2TLB_SCN_LOOKUP_ASID_GLOBAL_015` | `L2TLB_TP_015` | `existing_candidate` | `test_mmu_rand_l2tlb_tag_match_cross_asid` | ASID/global checker | Candidate only；与 invalidate 交叉但不互相替代。 |
| `L2TLB_SCN_LOOKUP_MULTI_HIT_016` | `L2TLB_TP_016` | `debug_only` | `test_mmu_dir_rrpv_multiple_hits_same_vpn` | multi-hit classifier | Debug/candidate only；不是 normal hit pass。 |
| `L2TLB_SCN_MB_ALLOC_PTW_REQ_017` | `L2TLB_TP_017` | `existing_candidate` | `test_mmu_dir_l2tlb_mb_alloc_on_miss` | MB shadow + PTW request checker | Candidate only；PFU source 常需新增。 |
| `L2TLB_SCN_PTW_DISABLED_MISS_018` | `L2TLB_TP_018` | `implemented_closure` | `test_l2tlb_p6e_ptw_disabled_fault_accerr` | source-specific disabled terminal checker | Closed by `P6E_PTW_SOURCE_FAULT_CLOSURE`；ITLB/DTLB load/DTLB store/PFU bins 全部命中。 |
| `L2TLB_SCN_MB_ISSUE_PAYLOAD_019` | `L2TLB_TP_019` | `existing_candidate` | `test_mmu_rand_l2tlb_mb_issue_order` | MB-to-PTW payload checker | Candidate only；PTW ID 是 SVA 重点。 |
| `L2TLB_SCN_MB_FULL_NO_OVERFLOW_020` | `L2TLB_TP_020` | `existing_candidate` | `test_mmu_dir_l2tlb_mb_full_stall` | no-overflow checker | Candidate only；需与 TP055 分区 full 区分。 |
| `L2TLB_SCN_MB_DUPLICATE_LIFETIME_021` | `L2TLB_TP_021` | `existing_candidate` | `test_mmu_dir_l2tlb_mb_dup_alloc_prevention` | duplicate lifetime checker | Candidate only；wrapper 名称需重审。 |
| `L2TLB_SCN_MB_ALLOC_DEALLOC_RACE_022` | `L2TLB_TP_022` | `existing_candidate` | `test_mmu_dir_l2tlb_mb_dealloc_on_complete` | accounting checker | Candidate only；需要 same-cycle evidence。 |
| `L2TLB_SCN_PTW_READY_STABILITY_023` | `L2TLB_TP_023` | `new_wrapper_required` | 新增 PTW ready backpressure directed | PTW handshake checker + `L2TLB_SVA_011` | Missing wrapper。 |
| `L2TLB_SCN_PTW_REFILL_OWNER_024` | `L2TLB_TP_024` | `existing_candidate` | MB/PTW directed 或 PTW consumer tests | PTW transaction scoreboard | Candidate only；consumer evidence 不能替代 ownership。 |
| `L2TLB_SCN_PTW_PAGE_FAULT_OWNER_025` | `L2TLB_TP_025` | `implemented_closure` | `test_l2tlb_p6e_ptw_disabled_fault_accerr` | source-specific page-fault ownership checker | Closed by `P6E_PTW_SOURCE_FAULT_CLOSURE`；payload-ignore counter `payload_ignore=17`。 |
| `L2TLB_SCN_PTW_ACCESS_ERROR_OWNER_026` | `L2TLB_TP_026` | `implemented_closure` | `test_l2tlb_p6e_ptw_disabled_fault_accerr` | source-specific access-error ownership checker | Closed by `P6E_PTW_SOURCE_FAULT_CLOSURE`；access-error 四源 counter 全部 >0。 |
| `L2TLB_SCN_PTW_NEG_PROTOCOL_027` | `L2TLB_TP_027` | `negative_assertion_only` | 新增 negative PTW completion suite | negative protocol checker + `L2TLB_SVA_012/013` | Negative-only；不进合法随机。 |
| `L2TLB_SCN_PFU_DIRECT_MMU_OFF_028` | `L2TLB_TP_028` | `new_wrapper_required` | 新增 PFU MMU-off directed | PFU direct checker | Missing PFU directed。 |
| `L2TLB_SCN_PFU_MMU_ON_L2_HIT_029` | `L2TLB_TP_029` | `new_wrapper_required` | 新增 PFU MMU-on hit directed | PFU hit checker | Missing PFU directed。 |
| `L2TLB_SCN_PFU_MISS_PTW_030` | `L2TLB_TP_030` | `new_wrapper_required` | 新增 PFU miss+PTW directed | PFU PTW path checker | Missing PFU directed。 |
| `L2TLB_SCN_PFU_FLAG_FAULT_031` | `L2TLB_TP_031` | `new_wrapper_required` | 新增 PFU flag fault directed | PFU error classifier | Missing PFU directed；error payload ignored。 |
| `L2TLB_SCN_PFU_PMP_SYSMAP_DENY_032` | `L2TLB_TP_032` | `new_wrapper_required` | 新增 PFU PMP/sysmap directed | deny checker | Missing PFU directed。 |
| `L2TLB_SCN_PFU_ERROR_PAYLOAD_IGNORE_033` | `L2TLB_TP_033` | `checker_sva_only` | PFU error classifier rule | payload-ignore scoreboard rule | Missing scoreboard rule。 |
| `L2TLB_SCN_TLBP_QUERY_034` | `L2TLB_TP_034` | `existing_candidate` | `test_mmu_tlbp_query_hit`、`test_mmu_tlbp_query_miss` | TLBP scoreboard | Candidate only；L2 shadow required。 |
| `L2TLB_SCN_TLBR_READ_035` | `L2TLB_TP_035` | `existing_candidate` | `test_mmu_tlbr_read_entry`、`test_mmu_tlbr_all_fields` | TLBR raw read checker | Candidate only；invalid raw policy required。 |
| `L2TLB_SCN_TLBWI_WRITE_036` | `L2TLB_TP_036` | `existing_candidate` | `test_mmu_tlbwi_write_entry`、`test_mmu_tlbwi_overwrite` | shadow update checker | Candidate only。 |
| `L2TLB_SCN_TLBWR_FUNCTIONAL_037` | `L2TLB_TP_037` | `existing_candidate` | `test_mmu_tlbwr_random_replace`、`test_mmu_tlbwr_rrpv_policy` | functional result checker | Candidate only；exact victim 不比较。 |
| `L2TLB_SCN_INVVA_ALL_038` | `L2TLB_TP_038` | `existing_candidate` | `test_mmu_dir_l2tlb_inv_va`、sfence VA wrappers | invalidate shadow checker | Candidate only。 |
| `L2TLB_SCN_INVASID_039` | `L2TLB_TP_039` | `existing_candidate` | `test_mmu_dir_l2tlb_inv_asid`、sfence ASID wrappers | invalidate shadow checker | Candidate only。 |
| `L2TLB_SCN_INVVA_ASID_040` | `L2TLB_TP_040` | `existing_candidate` | `test_mmu_dir_l2tlb_inv_va_asid`、sfence VA+ASID wrappers | invalidate shadow checker | Candidate only。 |
| `L2TLB_SCN_INVALL_ABORT_041` | `L2TLB_TP_041` | `existing_candidate` | `test_mmu_dir_l2tlb_inv_all`、sfence INVALL wrappers | all-invalid + abort checker | Candidate only；reset/abort 交叉另证。 |
| `L2TLB_SCN_TLBOP_LIFECYCLE_042` | `L2TLB_TP_042` | `existing_candidate` | all TLBOP wrappers | TLBOP lifecycle checker + `L2TLB_SVA_015` | Candidate only；done ordering evidence required。 |
| `L2TLB_SCN_TLBOP_RESET_043` | `L2TLB_TP_043` | `new_wrapper_required` | 新增 reset during TLBP/TLBWI/INVALL directed | reset plus TLBOP checker | Missing wrapper。 |
| `L2TLB_SCN_ABORT_STALE_CMPLT_044` | `L2TLB_TP_044` | `existing_candidate` | `test_mmu_sfence_during_walk`、`test_mmu_sfence_refill_conflict` | stale completion checker | Candidate only；需要 old/new context evidence。 |
| `L2TLB_SCN_RRPV_INIT_DEBUG_045` | `L2TLB_TP_045` | `debug_only` | `test_mmu_dir_rrpv_init_value`、`test_mmu_dir_rrpv_init_max_value_boundary` | RRPV debug sampler | Debug-only；exact RRPV 不关闭 v1。 |
| `L2TLB_SCN_RRPV_WBUF_DEBUG_046` | `L2TLB_TP_046` | `debug_only` | `test_mmu_rand_rrpv_wbuf_no_overflow`、`test_mmu_dir_rrpv_wbuf_latency` | wbuf checker + `L2TLB_SVA_022` | Debug-only；latest-wins future。 |
| `L2TLB_SCN_REPLACEMENT_FUTURE_047` | `L2TLB_TP_047` | `future_exact_model` | RRPV victim wrapper family | future exact replacement model | Future；visible functional result 可作辅助。 |
| `L2TLB_SCN_NEG_ILLEGAL_INPUT_048` | `L2TLB_TP_048` | `negative_assertion_only` | 新增 illegal input negative suite | negative checker + `L2TLB_SVA_003/004/018` | Negative-only。 |
| `L2TLB_SCN_TIMEOUT_FAIRNESS_049` | `L2TLB_TP_049` | `checker_sva_only` | timeout classifier | timeout/fairness scoreboard | Missing policy/checker。 |
| `L2TLB_SCN_CLOSURE_MANIFEST_050` | `L2TLB_TP_050` | `checker_sva_only` | Phase6G closure manifest/scanner | traceability closure checker | Closure-only；Phase6B 定义 metadata。 |
| `L2TLB_SCN_ARB_PTW_ON_051` | `L2TLB_TP_051` | `existing_candidate` | `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior` | ptw_on exclusion checker + `L2TLB_SVA_019` | Candidate only；stall cover required。 |
| `L2TLB_SCN_ARB_TLBOPER_ON_052` | `L2TLB_TP_052` | `existing_candidate` | `test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior` | tlboper_on exclusion checker + `L2TLB_SVA_020` | Candidate only；done release evidence required。 |
| `L2TLB_SCN_PFU_PREFETCH_MASK_053` | `L2TLB_TP_053` | `new_wrapper_required` | 新增 PFU mask directed | PFU accept/mask checker + `L2TLB_SVA_021` | Missing PFU directed。 |
| `L2TLB_SCN_INDEX_BANK_MASK_054` | `L2TLB_TP_054` | `existing_candidate` | `test_mmu_dir_l2tlb_bank_skew_distribution` | index/bank sampler | Candidate/debug only。 |
| `L2TLB_SCN_MB_PARTITION_FULL_055` | `L2TLB_TP_055` | `existing_candidate` | split from `test_mmu_dir_l2tlb_mb_full_stall` | MB partition checker | Candidate only；needs split evidence。 |
| `L2TLB_SCN_PTW_OOO_COMPLETION_056` | `L2TLB_TP_056` | `new_wrapper_required` | 新增 PTW out-of-order completion directed | PTW ID scoreboard + `L2TLB_SVA_010/013` | Missing wrapper/checker。 |
| `L2TLB_SCN_PFU_ATTR_TRUTH_TABLE_057` | `L2TLB_TP_057` | `new_wrapper_required` | 新增 PFU truth-table directed | PFU attribute checker | Missing PFU directed。 |
| `L2TLB_SCN_NEG_CONTROL_HAZARD_058` | `L2TLB_TP_058` | `negative_assertion_only` | 新增 control hazard negative suite | control hazard assertion checker + `L2TLB_SVA_017` | Negative-only。 |

### 4.2 Phase 6B test-case sufficiency gap

结论：现有 `l2tlb_tests/` 和 `tlbop_tests/` test case 不足以完成 L2TLB 测试点覆盖关闭。它们是候选入口，不是覆盖结论。Phase6B 明确要求后续补充以下内容。

| Gap group | 必须补充/加强的内容 | 相关 TP | 当前状态 |
| --- | --- | --- | --- |
| Reset / epoch | cold reset directed；warm reset during lookup/PTW/TLBOP/PFU；reset epoch/stale completion checker | `L2TLB_TP_001..002`, `043` | Missing directed/checker evidence |
| ReqQ / arbiter checker | ITLB entry0、DTLB load/store split、bypass payload stability、MB-full retry、credit return fault case、arbiter payload no-cross、priority/fairness evidence | `L2TLB_TP_004..011` | Existing wrappers are candidates; checker evidence missing or incomplete |
| Lookup / page-size / ASID | ITLB vs DTLB source split；4K/2M/1G offset bins；ASID/global bins；multi-hit legal-result classifier | `L2TLB_TP_012..016` | Existing wrappers are candidates; trigger evidence must be proven |
| MB / PTW | PTW ready backpressure；bad completion negative；MB same-cycle alloc/dealloc；duplicate lifetime；PTW out-of-order completion；PTW disabled/page fault/access error source-specific closure 已完成 | `L2TLB_TP_017..027`, `056` | PTW source-specific row closed；several MB/negative wrappers/checkers still missing |
| PFU | MMU-off direct；MMU-on L2 hit；PFU miss+PTW；flag fault；PMP/sysmap deny；error payload-ignore；prefetch_mask；attribute truth table | `L2TLB_TP_028..033`, `053`, `057` | Major directed-test gap |
| TLBOP / invalidate / abort | L2 entry shadow for TLBP/TLBR/TLBWI/TLBWR/INV*；TLBOP lifecycle done ordering；INV* global/non-global/all-set scan；abort stale completion | `L2TLB_TP_034..044`, `051..052` | Existing wrappers are candidates; lifecycle/shadow evidence missing |
| Negative / control hazard | illegal type/page-size/bad ID/credit overflow；SATP/ASID/MMU/PTW/control write with outstanding translation/PTW | `L2TLB_TP_048`, `058` | Negative suite missing |
| Timeout / closure | timeout/fairness classifier；traceability manifest/scanner；coverage/SVA/log closure rows | `L2TLB_TP_049..050` | Closure tooling/checker policy missing |
| RRPV / replacement | RRPV init/wbuf debug cover；replacement exact victim/RRPV future model | `L2TLB_TP_045..047` | Debug/future only; not v1 closure blocker |

因此 Phase6B 交付的是缺口明确化和后续实现清单。任何后续阶段若只运行现有 wrapper 而没有补齐 trigger/checker evidence，不得把对应 TP 标为 `Complete`。

### 4.3 Phase 6C scoreboard/reference-model baseline

结论：现有 scoreboard/ref-model 不足以完成 L2TLB 测试点覆盖关闭。它们提供了最终响应 compare、PTW request shadow、credit/drain health 和调试 snapshot 的基础，但还没有 Phase 4 要求的 transaction-level L2TLB entry shadow、owner tracking、payload-ignore 和统一 mismatch taxonomy。

| Model/checker owner | 必须负责的内容 | 当前源码基础 | 主要缺口 | 相关 TP/SVA |
| --- | --- | --- | --- | --- |
| L2 entry shadow | TLBWI/TLBWR/PTW refill/INV*/reset-inv/abort epoch 更新；TLBP/TLBR/lookup visible result compare | `mmu_ref_model.svh` 提供 page-table/PMP/SysMap translate；`mmu_translation_sb.svh` 可比较最终 IFU/LSU/PFU 响应 | `on_tlb_inv()` 仍未维护 TLB entry array；缺 L2 entry valid/VPN/ASID/global/page-size/PPN/flag shadow | `L2TLB_TP_012..016`, `024`, `034..041`, `045..047` |
| ReqQ/arbiter owner | ITLB/DTLB/PFU/TLBOP source、entry/eid/type、payload no-cross、ptw_on/tlboper_on exclusion | `mmu_credit_sb.svh` 有 L2/PTW snapshot 和 credit health | 不比较每笔 ReqQ/arbiter payload，不证明 grant/source/owner 不串源 | `L2TLB_TP_004..011`, `051..052`；`L2TLB_SVA_005/006/019/020` |
| MB/PTW owner | MB alloc/issue/full/dealloc、PTW request/ready/data/fault/acc_err/out-of-order completion composite-ID | `mmu_translation_sb.svh` 已有 `m_ptw_req_shadow` 和 SATP/abort 相关 stale 处理；Phase6C shadow 已补 PTW source/result bins | 完整 MB shadow、ready-stability、no-outstanding negative 分类和 OOO owner closure 仍缺；PTW disabled/page-fault/access-error source-specific closure 已完成 | `L2TLB_TP_017..027`, `055..056`；`L2TLB_SVA_009..013` |
| PFU path shadow | MMU-off direct、MMU-on L2-hit、MMU-on miss+PTW；PMP/SysMap/flag fault；prefetch_mask；attribute truth table | `mmu_translation_sb.svh` 已对 PFU 调用 `m_ref.translate(va, ACC_PFU, 4)`；`mmu_ref_model.svh` 有 PFU direct/PMP/SysMap helper | 缺 PFU path classifier、PFU owner、payload-ignore 统一规则和 directed evidence sink | `L2TLB_TP_028..033`, `053`, `057`；`L2TLB_SVA_021` |
| TLBOP/invalidate lifecycle | TLBP/TLBR/TLBWI/TLBWR/INV* request/grant/done/readback；INVVA/INVASID/global/non-global/all-set 语义 | `mmu_invalidate_sb.svh` 统计 invalidate event/done；TLBOP wrapper 已存在候选入口 | 当前只计数，不证明 L2 entry shadow 被正确更新，不证明 reset/abort/stale done | `L2TLB_TP_034..044`, `051..052`；`L2TLB_SVA_015/016/020` |
| Reset/abort/control epoch | reset during active lookup/PTW/TLBOP/PFU；stale completion/drop；control hazard negative 分类 | `mmu_translation_sb.svh` 已有部分 reset/abort/PTW shadow clear | 缺统一 epoch 模型；control hazard 只能走 negative assertion，不应由普通 functional compare 关闭 | `L2TLB_TP_001..002`, `043..044`, `058`；`L2TLB_SVA_001/002/017` |
| Payload-ignore rule | page fault、access error、no-pavld、PFU error、illegal negative 场景只比较 owner/fault class/valid；忽略无效 PA/PPN/flag payload | 现有 translation scoreboard 有若干 fault waiver/token 逻辑 | 规则分散且未覆盖 L2TLB TP；缺统一记录到 evidence 的分类字段 | `L2TLB_TP_025..027`, `031..033`, `048`, `058` |
| Timeout/fairness classifier | PTW wait、MB retry、TLBOP scan、wbuf stall 分类为 environment backpressure、DUT non-progress、debug/future 或 waiver | `mmu_credit_sb.svh` 有 end-drain/idle snapshot | 缺 per-scenario timeout policy 和 closure manifest 输入 | `L2TLB_TP_049..050` |
| Mismatch taxonomy | 每个 scoreboard error 记录 source、VPN、ASID、page size、owner id、expected、observed、epoch、category | 现有 mismatch counter 和部分 diagnostic message | 缺统一 `RTL bug`/`UVM bug`/`spec gap`/`tooling issue`/`approved waiver` 分类字段 | 所有 P0/P1 TP |
| RRPV/replacement debug | RRPV init/wbuf/replacement pressure 只作 debug/future；visible result legal 即可 | 现有 RRPV wrapper 可作为候选入口 | 不建 exact victim、exact RRPV、wbuf latest-wins v1 模型 | `L2TLB_TP_045..047`；`L2TLB_SVA_022..024` |

Phase6C 后续实现最低要求：

- 新增或扩展 L2TLB helper model 时，必须把 L2 entry shadow 和 owner tracking 作为独立可 review 单元；不能把 `UVM_ERROR=0` 或 credit drain pass 当作功能正确。
- scoreboard error 必须带 mismatch category；未分类 mismatch 不能用于关闭 TP。
- fault/no-pavld/PFU error/illegal negative 场景必须先定义 payload-ignore 规则，再决定是 compare、assertion-only、waiver 还是 future。
- RRPV exact victim、exact RRPV、wbuf latest-wins 保持 debug/future，不作为 v1 transaction scoreboard 失败原因。

### 4.4 Phase 6E directed/negative test baseline

结论：现有 directed/stress/negative-looking wrapper 不足以完成 L2TLB 测试点覆盖关闭。`test_pkg.sv` 已 include 多个相关 suite，且现有 test pool 可作为后续实现基础；但多数 wrapper 是 Phase9/Phase12 粗入口，缺少 per-scenario trigger gate、checker/SVA gate、negative 隔离和 targeted run evidence。

| 区域 | 当前入口 | Phase6E 判断 |
| --- | --- | --- |
| L2TLB directed/random | `l2tlb_tests/` 下 42 个 `test_*.svh`；suite 已 include | ReqQ、MB、tag hit、INV*、bank conflict、RRPV 候选入口；多数复用通用 vseq/checker，不能单独关闭 TP。 |
| TLBOP/SFENCE | `tlbop_tests/` 下 25 个 `test_*.svh`；suite 已 include | TLBP/TLBR/TLBWI/TLBWR/INV* 候选入口；仍缺 L2 entry shadow、TLBOP lifecycle SVA 和 reset/abort cross evidence。 |
| Reset/flush | `flush_tests/` 下 9 个 `test_*.svh`；suite 已 include | 可复用 `mmu_reset_midtransaction_vseq`；需 L2TLB-specific cold/warm reset、reset-inv boundary 和 active source split。 |
| PTW/PTE/arbiter | `ptw_tests/` 下 74 个 `test_*.svh`；suite 已 include | 有 PTW ready、PTE fault、bus error、MB full、arbiter stress 候选；仍需 L2TLB owner evidence，legacy obsolete wrapper 不可关闭 source。 |
| Perf/stress | `perf_tests/` 下 22 个 `test_*.svh`；suite 已 include | 可作为 timeout/fairness/concurrency smoke；不能替代 directed trigger evidence。 |
| Error/bug/protocol | `err_tests`、`bug_hunt_tests`、`ptw_lsu_protocol_tests` 合计 35 个 `test_*.svh`；suite 已 include | 可作为 negative/error/protocol 候选；需确认是否真实驱动 L2TLB audit 场景。 |
| 可复用 sequence | `mmu_reset_midtransaction_vseq`、`mmu_ptw_thrash_vseq`、`mmu_sfence_during_walk_vseq`、`mmu_rrpv_aging_vseq`、`mmu_l2tlb_bank_conflict_vseq`、`mmu_satp_hotswap_vseq`、`lsu_prefetch_pipe2_seq`、`cp0_ptw_disable_seq`、`ptw_mem_slow_rsp_seq`、`ptw_mem_illegal_pte_seq` 等 | 可复用；每个 wrapper 仍必须添加 scenario metadata、trigger gate 和 checker gate。 |
| OOO PTW legacy | `ptw_mem_ooo_rsp_seq` warning-only；`test_mbuf_ooo_response` 标为 `PTW-014-OBSOLETE-OOO` | 单 outstanding PTE memory protocol 下不能关闭 `L2TLB_TP_056` normal coverage；只能 negative/future/waiver。 |

| 测试组 | 相关 TP/SVA | 候选复用入口 | Phase6E 必须新增/加强内容 | 关闭条件 |
| --- | --- | --- | --- | --- |
| Reset / reset-inv / warm active reset | `L2TLB_TP_001..002`, `043`; `L2TLB_SVA_001/002` | `flush_tests/*reset*`、`mmu_reset_midtransaction_vseq` | L2TLB cold reset、warm reset during lookup/PTW/TLBOP/PFU、reset-inv boundary wrapper 或 scenario gate。 | reset trigger cover + reset epoch/stale checker/SVA pass。 |
| ReqQ / credit / arbiter payload | `L2TLB_TP_004..011`, `051..052`; `L2TLB_SVA_003..008/019/020` | `l2tlb_tests/*reqq*`、`*bank_conflict*`、`ptw_tests/test_arb_*` | ITLB entry0、DTLB load/store split、credit fault return、payload no-cross、ptw_on/tlboper_on stall/release trigger。 | ReqQ/arbiter SVA 或 payload scoreboard pass，且 wrapper 自带 trigger gate。 |
| Lookup / page size / ASID / multi-hit | `L2TLB_TP_012..016` | `test_mmu_dir_l2tlb_tag_match_*`、`test_mmu_rand_l2tlb_tag_match_cross_asid`、`test_mmu_dir_rrpv_multiple_hits_same_vpn`、PTW huge page tests | ITLB vs DTLB source split、4K/2M/1G offset bins、ASID/global bins；multi-hit 仅作 legal-result/debug classifier。 | L2 entry shadow/transaction scoreboard pass；multi-hit 不当作 normal hit closure。 |
| MB / PTW normal path | `L2TLB_TP_017`, `019..024`, `055`; `L2TLB_SVA_009..011` | `l2tlb_tests/*mb*`、`ptw_tests/test_mbuf_*`、`test_mmu_ptw_ready_*` | MB alloc/full/issue/dealloc trigger、PTW ready stall/release、same-cycle alloc/dealloc、partition full split、owner ID evidence。 | MB/PTW owner scoreboard + PTW ready SVA pass。 |
| PTW disabled/fault/access error | `L2TLB_TP_018`, `025..026`; `L2TLB_SVA_012/014` | `cp0_ptw_disable_seq`、`ptw_mem_illegal_pte_seq`、`test_bus_error_terminate`、PTE fault wrappers | L2TLB source-specific PTW disabled miss、page fault、access error directed wrappers；区分 ITLB/DTLB/PFU owner。 | fault class + owner compare pass；payload-ignore rule 生效。 |
| PTW negative / OOO / bad completion | `L2TLB_TP_027`, `056`; `L2TLB_SVA_012/013` | `ptw_mem_ooo_rsp_seq` warning-only；`test_mbuf_ooo_response` obsolete | 新增 isolated negative PTW completion suite 或记录 waiver；不能用 obsolete OOO wrapper 关闭 normal coverage。 | negative assertion expected fail/pass evidence；普通功能不比较未定义 payload。 |
| PFU directed | `L2TLB_TP_028..033`, `053`, `057`; `L2TLB_SVA_021` | `lsu_prefetch_pipe2_seq`、PMP/sysmap/PTE wrappers | PFU MMU-off direct、MMU-on L2 hit、PFU miss+PTW、flag fault、PMP/sysmap deny、prefetch_mask、attribute truth-table wrappers。 | PFU path classifier + payload-ignore/attribute checker pass。 |
| TLBOP / INV* / abort | `L2TLB_TP_034..044`; `L2TLB_SVA_015/016` | `tlbop_tests/*`、`l2tlb_tests/*inv*`、`test_sfence_abort_walk`、`test_mmu_sfence_*` | TLBP/TLBR/TLBWI/TLBWR/INV* trigger gates、global/non-global/all-set scan、reset during TLBOP、abort stale completion。 | TLBOP lifecycle SVA + L2 entry shadow compare + stale completion checker pass。 |
| Negative illegal input / control hazard | `L2TLB_TP_048`, `058`; `L2TLB_SVA_003/004/017/018` | `err_tests/`、`bug_hunt_tests/`、`mmu_satp_hotswap_vseq` | Isolated bad type/page-size/bad ID/credit overflow/control-hazard negative wrappers；normal directed/random 必须保持协议合法。 | expected assertion/error handling evidence；不得计入 normal functional coverage。 |
| Timeout / fairness / closure | `L2TLB_TP_049..050` | `perf_tests/*stress*`、`test_ptw_walk_latency`、`test_sfence_high_frequency` | targeted timeout/fairness run list、environment backpressure release condition、closure manifest input。 | timeout classifier result + evidence manifest row；无 trigger 则 fail 或 waiver。 |
| RRPV / replacement debug | `L2TLB_TP_045..047`; `L2TLB_SVA_022..024` | existing RRPV wrappers | 重分类为 debug/future；只检查 no-overflow/no-wrong-grant/visible result，exact victim/RRPV future。 | debug cover/log；future exact item 不进 v1 pass/fail。 |

Phase6E 后续实现最低要求：

- Positive directed test 必须有 `trigger_gate` 和 `checker_gate`；缺任一项时该测试必须 fail 或进入 waiver。
- Negative test 必须独立命名并从普通功能回归分离；pass/fail 只看预期 assertion/error handling。
- Obsolete wrapper 默认不能关闭 `L2TLB_TP_xxx`；若要复用，必须写明 replacement evidence。
- Targeted run list 至少分为 `l2tlb_smoke`、`l2tlb_directed_p0`、`l2tlb_negative`、`l2tlb_debug_rrpv`、`l2tlb_timeout_fairness`。
- 每次 run 必须把 trigger evidence、checker/SVA evidence、UVM_ERROR/UVM_FATAL summary 和 log path 写入第 6 节 evidence log。

### 4.5 Phase 6F RRPV/replacement baseline

结论：现有 RRPV/replacement wrapper、SVA 和 probe 足以作为后续 debug/future 的候选入口，但不足以关闭 exact replacement。v1 只能用功能可见结果和 debug/no-overflow/no-wrong-grant 证据保护 DUT 质量；exact victim、exact RRPV value、wbuf latest-wins/merge 必须保持 future 或 approved waiver。

| 区域 | 当前入口 / 观察面 | Phase6F 判断 |
| --- | --- | --- |
| RRPV wrapper | `l2tlb_tests/` 下 14 个 `test_*rrpv*.svh`；suite 已 include | 多数 wrapper 复用 `mmu_rrpv_aging_vseq`，checker 多为 `credit_sb`；只能作为 pressure/debug 候选，不能证明 exact init/aging/victim/wbuf 行为。 |
| TLBWR/RRPV wrapper | `tlbop_tests/test_mmu_tlbwr_rrpv_policy.svh` | 复用 `cp0_tlbwr_seq + mmu_smoke_vseq` 和 `invalidation_sb`；v1 只检查 TLBWR 后功能可见结果，不比较 victim way。 |
| Perf/bug wrapper | `perf_tests/test_rrpv_aging_replacement.svh`、`bug_hunt_tests/test_bug_007_rrpv_post_inv.svh` | 可作为 stress/post-invalidate debug 候选；没有独立 trigger/checker evidence 时不能关闭 `L2TLB_TP_045..047`。 |
| SVA/bind | `mmu_l2tlb_rrpv_sva.sv` bind `mmu_l2tlb` | 当前只覆盖局部 write bus known、PTW read/write staging、multi-hit/PTW-disabled release；`L2TLB_SVA_022` 仍缺 wbuf no-overflow/no-wrong-grant，`L2TLB_SVA_023/024` future。 |
| Probe/coverage | `mmu_dut_probes_if.sv` 暴露 `l2_bank0`、`l2_final_way_hit`、`l2_raw_pre_pgs0`；`mmu_env_cg_whitebox.svh` 有 `cg_l2tlb_bank` | 可覆盖 bank/way/page-size debug bins；没有稳定暴露 wbuf push/pop/full/count、victim_way、exact RRPV value。 |
| RTL microarchitecture | `mmu_l2tlb_replacement_policy.sv`、`mmu_l2tlb_rrpv_wbuf.sv`、`mmu_l2tlb.sv` | RTL 中有 victim、RRPV update、wbuf full/bypass/latest-wins 逻辑；Phase6F 不直接建立 v1 exact oracle。 |

| Item | Audit ID | 分类 | v1 pass/fail 允许检查 | Debug evidence | Future exact-model 条件 |
| --- | --- | --- | --- | --- | --- |
| RRPV init on refill/TLBWI/TLBWR | `L2TLB_TP_045` | Debug with functional fallback | refill/write 后 lookup、TLBP/TLBR 或 invalidate 行为可解释；不比较 exact RRPV=3 | init wrapper trigger、bank/way/page-size cover、optional sampler | 新增稳定 RRPV SRAM/wbuf sampling 和 reference update rule。 |
| Hit promote / miss aging | `L2TLB_TP_045`, `L2TLB_TP_046` | Debug-only | 不因 exact promote-to-zero 或 miss aging value mismatch fail | hit/miss pressure cover、wbuf push/full/stall cover | cycle-aware RRPV model、valid-entry mask、same-cycle push/bypass 采样点。 |
| Wbuf no overflow | `L2TLB_TP_046`, `L2TLB_SVA_022` | Debug assertion recommended | wbuf full/stall 下不得 overflow；采样源稳定时可作为 debug SVA fail | full/empty/push/pop/full-stall bins、no-overflow assertion log | 缺 internal source 时回 6A 补 probe 或 waiver。 |
| Wbuf full no-wrong-grant | `L2TLB_TP_046`, `L2TLB_SVA_022`, `L2TLB_TP_049` | Debug assertion / timeout support | full active 时不得 grant 会产生新 RRPV update 的 ReqQ/PFU/PTW-read/TLBOP；PTW write 不应被 wbuf full 错误阻塞 | arbiter block cover、eventually drain/release log | 若检查 exact watermark/count，需 wbuf occupancy reference。 |
| TLBWR/PTW replacement visible result | `L2TLB_TP_037`, `L2TLB_TP_047` | v1 functional | 写入后 translation/TLBP/TLBR/invalidate 结果合法可解释；不预测 victim way | replacement pressure bins、victim observed debug log if available | exact victim/free-way/max-RRPV 进入 future `L2TLB_SVA_023`。 |
| Exact victim/free-way/max-RRPV | `L2TLB_TP_047`, `L2TLB_SVA_023` | Future exact model | v1 不检查，不作为 blocker | future pressure bins | 需要 hash/index、entry_vld、mask_way、entry_rrpv、victim_way、PTW/TLBWR timing 的 cycle-accurate model。 |
| Wbuf latest-wins / merge / same-cycle bypass | `L2TLB_TP_045..047`, `L2TLB_SVA_024` | Future exact model | v1 不检查，不作为 blocker | optional trace only | 需要 push/pop/bypass/SRAM read/write 合并规则和同周期采样定义。 |
| Invalid entry stale RRPV after invalidate/reset | `L2TLB_TP_038..041`, `045` | v1 ignore for functional result | invalid entry 的 stale RRPV 不影响 lookup；invalidate 后只检查 valid/tag/data 功能结果 | post-inv debug wrapper 可记录 | 若未来要求清理 stale RRPV，需规格澄清或专项 waiver。 |

Phase6F debug coverage plan：

- `rrpv_init_refill_seen`、`rrpv_init_tlbwi_seen`、`rrpv_init_tlbwr_seen`：只证明 init 类压力出现过，不能证明 exact RRPV value。
- `rrpv_hit_promote_pressure`、`rrpv_miss_aging_pressure`：只证明 hit/miss aging 压力出现过，不能用 `credit_sb pass` 关闭 RRPV aging oracle。
- `rrpv_wbuf_full_seen`、`rrpv_wbuf_release_seen`：证明 wbuf stall/release 场景出现过，不能替代 no-overflow/no-wrong-grant assertion。
- `rrpv_wbuf_no_overflow`、`rrpv_full_no_wrong_grant`：需要 `L2TLB_SVA_022` 或等价 checker/run log；若无稳定采样源，必须回 6A 或 waiver。
- `replacement_pressure_visible_result`：证明 replacement pressure 下功能结果合法，不能推断具体 victim way 正确。
- `victim_observed_bank_way`：只作 bank/way 分布 debug，不计入 future exact victim closure。

Phase6F future exact item：

| Future item | 相关 ID | 升级前置条件 | 最低证据要求 |
| --- | --- | --- | --- |
| Exact victim/free-way/max-RRPV model | `L2TLB_TP_047`, `L2TLB_SVA_023` | 独立批准 replacement exact-model 阶段；定义 hash/index、mask_way、entry_vld、entry_rrpv、tie-break、PTW/TLBWR timing。 | cycle-accurate reference model + assertion/scoreboard log + directed victim tests。 |
| Exact RRPV value after hit/miss/refill/write | `L2TLB_TP_045..046` | 稳定 RRPV SRAM/wbuf sampling；定义 valid-entry mask、invalid entry ignore、TLBOP 是否 aging。 | per-event expected/observed RRPV dump + mismatch taxonomy。 |
| Wbuf latest-wins/CAM merge | `L2TLB_TP_046`, `L2TLB_SVA_024` | 暴露或 bind `push_req/push_idx/push_vld/push_data/count/rd_ptr/wr_ptr` 等采样源；定义同 bank/index 多 pending 优先级。 | same-bank/index directed + latest-wins assertion pass。 |
| Same-cycle push bypass | `L2TLB_TP_046`, `L2TLB_SVA_024` | 明确同周期组合采样点和 lookup_req 时序；避免 delta-cycle 误采样。 | same-cycle push+lookup cover + merged value compare。 |
| PTW write / TLBOP write 与 pending wbuf 冲突规则 | `L2TLB_TP_045..047` | 明确 pending RRPV 是否 invalidate、merge 或允许 stale drain；定义功能可见风险。 | directed conflict tests + exact RRPV model evidence。 |

Phase6F 后续实现最低要求：

- `l2tlb_debug_rrpv` run list 只允许关闭 debug coverage、`L2TLB_SVA_022` debug assertion 和 functional-visible replacement checks；不得关闭 `L2TLB_SVA_023/024`。
- RRPV wrapper 必须记录 `phase6f_class`，取值只能是 `v1_functional_visible`、`debug_coverage`、`debug_assertion`、`future_exact_model`。
- wrapper 名称包含 `victim_selection`、`init_value`、`hit_promote_to_zero`、`aging_saturation` 时，若没有 exact RRPV model，只能按 debug/future 分类。
- `credit_sb`、`invalidation_sb` 或 generic vseq pass 只能作为 health evidence，不能作为 RRPV/replacement closure evidence。
- `L2TLB_TP_047` 在 v1 只能由 visible legal result 关闭；exact victim coverage 保持 future。

### 4.6 Phase 6G coverage/regression/closure baseline

结论：现有 coverage、regression 和历史 URG 资产不能直接完成 L2TLB 测试点关闭。它们可以提供编译、运行、coverage 工具链和全局 nightly 健康度，但缺少 L2TLB-specific coverage bin mapping、targeted run list、evidence manifest、closure scanner、SVA cover/report linkage 和逐 TP/SVA waiver/future 状态。Phase6G 的后续实现必须先补这些 closure artifacts，才能声明 `L2TLB_TP_001..058` 或 `L2TLB_SVA_001..024` 完成。

| 区域 | 当前入口 / 观察面 | Phase6G 判断 |
| --- | --- | --- |
| Makefile coverage/run | `run_check`、`run_cov`、URG merge、`COV_METRICS := line+cond+fsm+tgl+branch+assert`、`scripts/cov_hier.cfg` | 可作为执行框架；`cov_hier.cfg` 排除部分 SVA module code coverage 后，assertion/cover property 必须独立记录。 |
| Generic regression wrapper | `scripts/run_test.py` 支持 list、seed、summary、expected_fail/effective_pass | 可复用；closure list 中任何 `xfail` 必须绑定 issue/waiver，不能用 effective pass 掩盖未关闭场景。 |
| Log hygiene | `scripts/check_sim_status.sh` 检查 UVM_ERROR/UVM_FATAL 和 fatal/error pattern | 只能证明日志健康；不能证明 source/result bin 触发或 checker/SVA 检查通过。 |
| Existing gate scripts | `scripts/phase13_exit_gate.py`、`scripts/phase14_exit_gate.py` | 可复用 artifact/threshold/signoff 检查思路；signoff ID 和 coverage group 非 L2TLB-specific。 |
| L1DTLB Phase6G pattern | `scripts/l1dtlb_phase6g_closure.py`、`scripts/l1dtlb_phase6g_replay.py`、`simu/l1dtlb_phase6g_*` | 是 L2TLB closure scanner/manifest/replay 的最佳模板；不能直接复用 L1DTLB manifest 关闭 L2TLB。 |
| Existing run lists | `simu/mmu_smoke_list`、`simu/mmu_nightly_list`、`simu/mmu_coverage_list`、`simu/mmu_v4_full_regression_list` | 有 L2TLB/PTW/PFU/TLBOP 候选入口；没有逐 `L2TLB_TP_xxx`/`L2TLB_SVA_xxx` manifest，不足以 signoff。 |
| Whitebox covergroups | `mmu_env_cg_whitebox.svh` 中 `cg_l2tlb_bank`、`cg_l2_reqq`、`cg_tlboper_fsm`、`cg_ptw_walk` 等 | 可覆盖部分 bank/ReqQ/TLBOP/PTW bins；当前 log summary 未打印所有 L2TLB group，URG 不可用时缺 L2 fallback。 |
| Historical URG evidence | 既有 `output/coverage/phase14_urgReport` | 只能证明工具链曾生成 report；其中 L2 相关 group 覆盖仍有低分项且 assertion 有 failure，不能作为 Phase6G closure。 |

现有 evidence 不足点：

- 没有 `simu/l2tlb_phase6g_*` run list、`l2tlb_phase6g_evidence_manifest.tsv` 或 L2TLB closure scanner。
- `mmu_smoke_list` 中只有少量 L2TLB smoke；`mmu_nightly_list`/`mmu_coverage_list` 是全局列表，不能保证每个 source/result/page/negative/debug bin 命中并被检查。
- Whitebox coverage 有 L2TLB 相关 covergroup，但 summary log 缺少 `cg_l2tlb_bank`、`cg_l2_reqq`、`cg_tlboper_fsm` 等 L2-specific fallback 行；report 不可用时无法逐 bin 关闭。
- 既有 Phase14 URG report 中 `cg_tlboper_fsm`、`cg_l2_reqq`、`cg_l2tlb_bank`、`cg_ptw_walk` 仍有未达满覆盖项，且 assertion report 存在 failure；只能作为 gap evidence，不能作为 signoff evidence。

Coverage bin mapping：

| Coverage family | 必须覆盖的 bin | 相关 ID | 最低证据 |
| --- | --- | --- | --- |
| Source / operation | ITLB、DTLB load、DTLB store、PFU、PTW refill/read/write、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID | `L2TLB_TP_004..017`, `028..044`, `051..054` | source trigger counter/cover + owner checker 或 SVA pass；wrapper 名称不能关闭。 |
| Result / terminal state | single-hit、miss+MB alloc、MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny、reset/abort、timeout/fairness release | `L2TLB_TP_012..033`, `043`, `049..050`, `055..057` | final response classifier + scoreboard/SVA evidence；fault/error payload 按 Phase4 ignore rule。 |
| Page / ASID / global | 4K、2M、1G、offset boundary、ASID match/mismatch、global/non-global、multi-way hit classifier | `L2TLB_TP_012..016`, `034..041`, `057` | L2 entry shadow compare + page-size/ASID/global cover；multi-hit 不当作 normal hit。 |
| Arbiter / flow control | ITLB entry0、DTLB entry1..8、PFU source、pairwise/four-source conflict、`ptw_on`/`tlboper_on` stall/release、prefetch mask、MB partition full | `L2TLB_TP_004..011`, `019..024`, `051..055` | ReqQ/MB/PTW/PFU ownership counter + no-cross/no-overwrite/no-stale checker 或 SVA。 |
| Negative / illegal | bad type、bad page size、bad ID/completion、credit overflow、control hazard、protocol-violating CSR/control write | `L2TLB_TP_027`, `048`, `056`, `058` | 独立 negative list；expected assertion/error handling；不得混入 normal functional coverage。 |
| Debug / future replacement | RRPV init/hit/miss/wbuf pressure、no-overflow/no-wrong-grant、visible replacement result、future exact victim/RRPV/latest-wins | `L2TLB_TP_045..047`, `L2TLB_SVA_022..024` | Debug cover/SVA 或 future/waiver；exact victim/RRPV 不计入 v1 closure。 |

Regression tiers：

| Tier | 目的 | 后续 artifact | Phase6G closure 规则 |
| --- | --- | --- | --- |
| `l2tlb_compile` | 编译、bind/include、SVA 可见性 | `make comp` 或 `make comp_fast` log | compile/elab/link pass；新增 bind/SVA 必须 assertion-enabled compile。 |
| `l2tlb_smoke` | reset、single-hit、basic miss、basic TLBOP 快速健康检查 | `simu/l2tlb_phase6g_smoke_list` | 每个 smoke case 有 manifest row；无未解释 UVM_ERROR/UVM_FATAL。 |
| `l2tlb_directed_p0` | 关闭 P0/P1 source/result/owner bins | `simu/l2tlb_phase6g_targeted_list` | 每个 P0/P1 TP 有 trigger + checker/SVA evidence，或 approved waiver/future。 |
| `l2tlb_negative` | 隔离非法输入、bad completion、control hazard | `simu/l2tlb_phase6g_negative_list` | expected assertion/error 分类正确；不得计入 normal pass-rate。 |
| `l2tlb_debug_rrpv` | 记录 RRPV/replacement debug pressure | `simu/l2tlb_phase6g_debug_rrpv_list` | 只关闭 debug evidence；exact victim/RRPV/latest-wins 保持 future。 |
| `l2tlb_timeout_fairness` | backpressure、retry、eventual release | `simu/l2tlb_phase6g_timeout_fairness_list` | timeout/fairness classifier pass；永久 backpressure 必须 waiver。 |
| `l2tlb_coverage` | 生成 URG、assertion/SVA cover、L2 fallback summary | `run_cov`、URG、L2 helper/report | threshold 运行前固定；未达 bin 进入 issue/waiver/future。 |
| `integration/nightly candidate` | 确认进入全局回归后不回退 | `mmu_nightly_list`、`mmu_coverage_list`、`mmu_v4_full_regression_list` 后续补充 | 只能作为附加证据；不能替代 targeted closure。 |

Phase6G 后续必须新增或批准的 closure artifacts：

| Artifact | 用途 | 规则 |
| --- | --- | --- |
| `simu/l2tlb_phase6g_smoke_list` | Basic smoke closure list | 后续实现阶段新增；文档阶段不修改 run list。 |
| `simu/l2tlb_phase6g_targeted_list` | P0/P1 directed closure list | 每个 case 绑定 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx`。 |
| `simu/l2tlb_phase6g_negative_list` | Negative assertion-only list | 与 normal directed/random 分离。 |
| `simu/l2tlb_phase6g_debug_rrpv_list` | RRPV/replacement debug list | 不关闭 future exact item。 |
| `simu/l2tlb_phase6g_timeout_fairness_list` | Timeout/fairness targeted list | 必须带 release/timeout classifier。 |
| `simu/l2tlb_phase6g_evidence_manifest.tsv` | 每个 run 的 closure evidence 索引 | 缺 manifest row 的 TP/SVA 不得标 Complete。 |
| `scripts/l2tlb_phase6g_closure.py` 或 generic manifest scanner | 检查 log、required report/counter/cover、waiver 和 issue linkage | 不能只读 regression pass summary；必须检查 L2TLB-specific evidence。 |
| `scripts/l2tlb_phase6g_replay.py` 或等价 replay flow | 复现 manifest row | 可选但建议用于 signoff seed/command 可复现。 |
| L2TLB coverage summary/report | 提取 L2 source/result/page/ASID/control bins | URG 可用时记录 path；不可用时记录 L2-specific log fallback。 |
| Closure report | 汇总 TP/SVA/bin/waiver/future 状态 | 必须作为最终 review 输入。 |

Manifest 格式建议：

```text
case_id|phase|test|seed|status|accepted_warnings|required_reports|required_counters|required_covers|related_ids|notes
```

Manifest/checklist 规则：

- `status` 只允许 `closure`、`negative`、`debug`、`waived`、`future_exact_model`、`blocked` 等有 closure 语义的值；不得用单纯 `pass` 代替。
- `related_ids` 必须列出精确 `L2TLB_TP_xxx`、`L2TLB_SVA_xxx`、issue 或 waiver ID。
- `required_reports|required_counters|required_covers` 为空时，该行只能作为 compile/health evidence，不能关闭功能覆盖。
- `L2TLB_TP_001..058` 每项必须是 implemented+evidence、approved waiver 或具名 future；P0/P1 不允许 unowned。
- `L2TLB_SVA_001..024` 每项必须与 6D must/debug/future 分类一致；must 行不能由 partial-existing 关闭。
- Closure tiers 要求 100% effective pass；任何 `xfail` 必须绑定 issue/waiver。
- Coverage threshold 必须在运行前固定；未达项进入 issue/waiver/future，不得事后调整阈值掩盖缺口。

## 5. SVA 跟踪模板

本表跟踪 `L2TLB_SVA_001..024`。Phase6D 已补入当前 SVA/bind inventory、稳定 bind 实现、assertion-enabled compile/run evidence、未命中 cover 和 scope waiver/future。后续 6E/6F/6G 关闭前仍必须把 deferred cover、directed negative 和 future exact item 逐项补 evidence 或 waiver。

### 5.1 Phase 6D SVA/bind inventory

| 文件 / bind | 当前已有能力 | Phase6D 判断 |
| --- | --- | --- |
| `mmu_l2tlb_rrpv_sva.sv` bind `mmu_l2tlb` | 新增/强化 reset visible drain、request/queue/arb/final/PTW/L1/PFU/TLBOP no-X、PTW request ready stability、PTW completion legal combo、ReqQ multi-hit/PTW-disabled terminal release 和 cover properties。 | 覆盖 `L2TLB_SVA_001/011/012/014/018` 稳定子项；TLBOP full lifecycle、full reset-inv 和 exact replacement 仍不在本 bind 关闭。 |
| `mmu_arb_sva.sv` bind `mmu_arb` | 新增/强化 five-source onehot、PTW/TLBOP/wbuf/prefetch_mask block、fixed-priority eligibility、source payload no-cross、PFU mask set/release、Phase6F wbuf-full no-wrong-grant/PTW-writeback guard 和 cover properties。 | 覆盖 `L2TLB_SVA_005/006/019/020/021` 稳定 arbiter 子项，并作为 `L2TLB_SVA_022` 外侧 no-wrong-grant debug evidence；未命中 block/conflict cover 转 6G targeted closure。 |
| `credit_sva.sv` bind `mmu_l2tlb_reqq` | 新增 ReqQ request one-cycle pulse、payload known、normal no-credit guard、ITLB/DTLB partition、grant onehot0、feedback ID/result legality、retry lifetime、credit return accounting 和 cover properties。 | 覆盖 `L2TLB_SVA_003/004/007/008/018` 稳定 ReqQ 子项；fault/negative overflow directed evidence 仍需 6E/6G。 |
| `mmu_l2tlb_mb_sva.sv` bind `mmu_l2tlb_mb` | 新增 MB reset visible drain、request payload/type known、ITLB/DTLB partition/full no-overwrite、ffr/grant/bypass onehot0、issue payload/partition/stability、feedback ID/outstanding/dealloc、abort visible ownership 和 cover properties。 | 新增 Phase6D bind；覆盖 `L2TLB_SVA_001/009/010/011/013/016/018` 稳定 MB 子项；bad-ID/type-exact negative 仍需 6E。 |
| `tb_top.sv` | 已 bind `mmu_arb_sva`、`mmu_l2tlb_rrpv_sva`、`mmu_l2tlb_mb_sva`、`credit_sva`。 | L2TLB/ReqQ/MB/arbiter bind 入口已更新并经 `make comp_fast` elaboration。 |
| `Files.f` | 已 include `mmu_arb_sva.sv`、`mmu_l2tlb_rrpv_sva.sv`、`mmu_l2tlb_mb_sva.sv`、`credit_sva.sv`。 | SVA compile list 已同步；新增 MB SVA 文件进入 assertion-enabled compile。 |
| `scripts/cov_hier.cfg` | 已加入 `-module mmu_l2tlb_mb_sva`。 | 与现有 SVA module 一致排除 code coverage；assertion/cover closure 仍从 log/report/manifest 独立记录。 |

### 5.2 Phase 6D SVA baseline

| SVA ID | 分类 | 当前状态 | Bind target | Sample source | Assertion evidence | Cover evidence | Waiver / notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `L2TLB_SVA_001` | must | Implemented-scoped | `mmu_arb_sva`；`mmu_l2tlb_rrpv_sva`；`mmu_l2tlb_mb_sva` | reset visible drain for PTW write pipe/L2 final/PTW/L1/PFU/TLBOP/MB visible state | `comp_fast` + four smoke PASS | N/A | reset-inv full boundary remains `L2TLB_SVA_002`; reset assertions intentionally not all disabled by reset. |
| `L2TLB_SVA_002` | must | Deferred / waiver-required | future reset-inv checker or directed wrapper | reset-inv request/done、IFU/LSU/PFU valid | Deferred | Missing | Full reset-inv boundary not implemented in 6D; move to 6E/6G with directed trigger or approved waiver. |
| `L2TLB_SVA_003` | must | Implemented | `credit_sva` | `i_req_valid`, `d_req_valid` | `comp_fast` + four smoke PASS | N/A | Checks one-cycle pulse and request payload known/type legal. |
| `L2TLB_SVA_004` | must | Implemented-scoped | `credit_sva` | credit return、request、ReqQ valid/rdy/dealloc | `comp_fast` + four smoke PASS | DTLB alloc/issue cover hit 200 | Normal no-credit/credit-return accounting covered; illegal overflow negative remains 6E if needed. |
| `L2TLB_SVA_005` | must | Implemented | `mmu_arb_sva` | source request/grant、block flags、payload | `comp_fast` + four smoke PASS | PFU mask release cover hit 32; ReqQ/PFU conflict cover 0 | Onehot, block isolation and payload no-cross implemented; conflict trigger cover hole goes to 6G. |
| `L2TLB_SVA_006` | debug | Implemented-scoped | `mmu_arb_sva` | source request/grant、block flags | `comp_fast` + four smoke PASS | priority/block cover partially 0 | Fixed-priority eligibility implemented for stable RTL priority conditions; unhit covers remain 6G debug hole. |
| `L2TLB_SVA_007` | must | Implemented | `credit_sva` | entry valid/rdy、issue queue/type/eid | `comp_fast` + four smoke PASS | DTLB alloc/issue cover hit 200 | ITLB entry0 and DTLB entry1..N partition assertions implemented. |
| `L2TLB_SVA_008` | must | Implemented-scoped | `credit_sva` | entry valid/rdy/dealloc、feedback ID、miss retry | `comp_fast` + four smoke PASS | retry feedback cover 0 | Feedback ID/outstanding/result combo/retry lifetime implemented; retry trigger remains cover hole. |
| `L2TLB_SVA_009` | must | Implemented | `mmu_l2tlb_mb_sva` | req alloc、MB entry valid/rdy、alloc onehot | `comp_fast` + four smoke PASS | MB DTLB alloc cover hit 200/32 | MB ITLB/DTLB partition/full no-overwrite implemented. |
| `L2TLB_SVA_010` | must | Implemented-scoped | `mmu_l2tlb_mb_sva` | MB payload、alloc/dealloc、issue id/type/vpn | `comp_fast` + four smoke PASS | MB DTLB alloc cover hit 200/32 | Issue payload/accounting implemented; same-cycle alloc/dealloc directed cover remains 6G if required. |
| `L2TLB_SVA_011` | must | Implemented-scoped | `mmu_l2tlb_rrpv_sva`；`mmu_l2tlb_mb_sva` | `l2tlb_ptw_req`, `ptw_ready`, PTW id/type/vpn | `comp_fast` + four smoke PASS | PTW ready backpressure cover 0; MB PTW backpressure cover 0 | Payload stability under ready-low implemented; targeted backpressure trigger remains 6E/6G. |
| `L2TLB_SVA_012` | must | Implemented | `mmu_l2tlb_rrpv_sva` | `ptw_l2tlb_ref_cmplt/data_vld/pgflt/acc_err` | `comp_fast` + four smoke PASS | PTW fault completion cover hit 32 | Completion OR and onehot0 result legality implemented. |
| `L2TLB_SVA_013` | must | Partial implemented / negative follow-up | `mmu_l2tlb_mb_sva` + future negative checker | PTW completion id/type、MB outstanding | outstanding ID assertions PASS | Missing bad-ID/type negative | MB feedback ID known/in-range/outstanding implemented; PTW type-exact and bad-ID/no-outstanding negative remain 6E. |
| `L2TLB_SVA_014` | must | Implemented-scoped + PTW source closure | `mmu_l2tlb_rrpv_sva` + Phase6C shadow | final multi-hit、PTW disabled miss、ReqQ feedback | `comp_fast` + four smoke PASS；PTW source closure seed 64001 PASS | PTW disabled terminal source bins hit 4/4；multi-hit remains debug/future | Terminal release assertions strengthened; PTW-disabled directed trigger closed by `P6E_PTW_SOURCE_FAULT_CLOSURE`. |
| `L2TLB_SVA_015` | must | Deferred / waiver-required | future `ct_mmu_tlboper`/probe checker | TLBOP request/grant/cmplt/done、utlb clear、abort | Deferred | Missing | Full TLBOP lifecycle ordering not implemented in 6D; move to 6E directed or approved waiver. |
| `L2TLB_SVA_016` | must | Implemented-scoped | `mmu_l2tlb_mb_sva` + Phase6C epoch helper | `tlboper_ptw_abort`、MB state、late completion | `comp_fast` + four smoke PASS | MB abort outstanding cover 0 | Abort visible ownership guard implemented; late completion isolation still relies on Phase6C epoch/6E directed evidence. |
| `L2TLB_SVA_017` | must | Deferred / negative-only | future CP0/control hazard negative checker | CSR/control writes、ReqQ/MB/PTW outstanding、abort/flush/done | Deferred | Missing | Control hazard negative not implemented in 6D; move to 6E isolated negative suite. |
| `L2TLB_SVA_018` | must | Implemented-scoped | `mmu_l2tlb_rrpv_sva`、`credit_sva`、`mmu_l2tlb_mb_sva` | valid beat payload/control | `comp_fast` + four smoke PASS | N/A | Covers request/queue/arb/final/PTW/TLBOP/PFU/L1/ReqQ/MB no-X on stable valid beats. |
| `L2TLB_SVA_019` | debug | Implemented-scoped | `mmu_arb_sva` | `ptw_on`、PTW read/write grant、source grants | `comp_fast` + four smoke PASS | ptw_on block cover 0 | PTW-on block assertions implemented; cover remains targeted debug hole. |
| `L2TLB_SVA_020` | debug | Implemented-scoped | `mmu_arb_sva` | `tlboper_on`、source grants、TLBOP done | `comp_fast` + four smoke PASS | tlboper_on block cover 0 | TLBOP-on block assertions implemented; full lifecycle deferred under `L2TLB_SVA_015`. |
| `L2TLB_SVA_021` | debug | Implemented | `mmu_arb_sva` | PFU valid、prefetch_mask、PFU grant、PFU response | `comp_fast` + four smoke PASS | PFU mask release cover hit 32 | PFU mask block/set/release implemented. |
| `L2TLB_SVA_022` | debug | Implemented-scoped / 6F | `mmu_l2tlb_rrpv_wbuf_sva` bind `mmu_l2tlb_rrpv_wbuf` + `mmu_arb_sva` | wbuf reset/count/status、push/pop accept accounting、no overflow/underflow、valid-bank payload known、lookup result known、wbuf-full no wrong read grant、PTW writeback not blocked by full | `comp_fast` + `test_l2tlb_p6e_rrpv_debug_pressure` seed 65001 PASS | push_new_entry=96、pop=96、lookup_bypass_hit=48；cam_hit/full/full_release/same_cycle/arbiter full-block/writeback cover 0 | Closes debug no-overflow/no-underflow/accounting/no-wrong-grant baseline only; no exact RRPV/victim/latest-wins closure. |
| `L2TLB_SVA_023` | future | Future | future replacement exact model | victim/free-way/max-RRPV inputs | N/A | Future | v1 不实现；需专项 exact replacement model。 |
| `L2TLB_SVA_024` | future | Future | future RRPV exact model | wbuf latest-wins/merge/bypass inputs | N/A | Future | v1 不实现；需专项 RRPV model。 |

### 5.3 Phase 6D SVA closure rules

- `must` 行必须实现并提供 assertion-enabled compile/run evidence，或提供 approved waiver；`Partial-existing` 不能关闭 ID。
- `debug` 行若不实现，必须写清 deferred 原因、风险和替代 debug evidence。
- `future` 行不是 v1 closure blocker，但必须保留在 closure manifest 中。
- Reset 行为和 `disable iff` 策略必须匹配来源需求；reset assert 类 property 不能因 reset active 被整体 disable。
- Negative assertion-only 项不得混入普通功能回归，fail 结果必须与负向测试预期一致。
- 新增 bind 必须优先使用模块端口、bind scope 内部信号或稳定 probe；缺采样源时先回到 6A 补 probe 或写 waiver。

## 6. 证据日志

后续阶段必须记录每次 compile、directed run、negative assertion run、targeted regression、coverage/SVA report。

| 日期 | 子阶段 | 命令 / run | 结果 | Log / report 路径 | 摘要 | 后续动作 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-21 | Phase 6 docs | 文档创建 | Complete | 本文件和 BuildPlan | Phase 6 未运行仿真或改代码 | 后续代码阶段需记录基线。 |
| 2026-05-21 | Phase 7 docs | 退出准则文档化 | Complete | 本文件和 BuildPlan | 6A~6G 严格门禁已写入；未执行实现 | 后续实现阶段按门禁填证据。 |
| 2026-05-23 | Phase 6A docs | `make comp_fast`（workdir: `mmu_verification/`） | Pass | `mmu_verification/output/logs/comp_fast.log` | VCS compile/elab/link 完成并生成 `output/simv`；有 locale 和 csrc clock-skew warning，但无 compile error。 | Full debug build 已补跑 `make comp`，见下一行。 |
| 2026-05-23 | Phase 6A docs | `rg '\$root' mmu_verification/testbench doc/l2tlb_uvm_audit -S` | Pass | 命令输出 | testbench checker 未发现未批准 `$root` fragile path；`$root` 只出现在文档约束和 probe 禁用说明中。 | 后续新增 checker 仍必须通过 probe/interface、transaction monitor 或 bind target 取样。 |
| 2026-05-23 | Phase 6A docs | `make comp`（workdir: `mmu_verification/`） | Pass | `mmu_verification/output/logs/comp_all.log` | Full VCS compile/elab/link 通过，`output/simv` 生成；Verdi KDB elaboration `0 error(s), 0 warning(s)`；error/fatal 关键字检查未命中。 | 6A compile gate 关闭；clock-skew/locale warning 继续由 `L2TLB-P6-ISSUE-003` 跟踪。 |
| 2026-05-23 | Phase 6B docs | `rg -n "L2TLB_TP_[0-9]{3}" doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`find mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests -maxdepth 2 -type f \| sort`；`rg -n "l2tlb_tests_suite\|tlbop_tests_suite\|l2tlb\|tlbop" mmu_verification/testbench/test/test_pkg.sv mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests`；wrapper metadata parse for `p9_tc_id/p9_seq_desc/p9_checker/p9_reviewer` | Complete-doc | 本文件和 BuildPlan Phase 6B | 确认 `L2TLB_TP_001..058` 为 Phase6B 映射来源；`l2tlb_tests_suite.svh` 和 `tlbop_tests_suite.svh` 已被 `test_pkg.sv` include；已在第 4.1 节为每个 TP 分配稳定 `L2TLB_SCN_*` 并记录 wrapper class/candidate/checker owner；第 4.2 节明确现有 test case 不足以完成覆盖关闭。 | 后续 6C/6D/6E/6G 必须补 trigger evidence、checker/SVA evidence、run log、coverage report 或 waiver；本轮未运行仿真、未改行为代码。 |
| 2026-05-23 | Phase 6C docs | `sed -n '2220,2285p' doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`rg -n "class mmu_translation_sb\|m_ptw_req_shadow\|l2tlb\|pfu\|reset\|abort\|mismatch\|translate\\(" mmu_verification/testbench/env/mmu_translation_sb.svh`；`rg -n "class mmu_invalidate_sb\|invalidate\|done\|shadow\|l2tlb" mmu_verification/testbench/env/mmu_invalidate_sb.svh`；`rg -n "l2tlb\|ptw\|pfu\|arb\|credit\|class mmu_credit_sb" mmu_verification/testbench/env/mmu_credit_sb.svh`；`rg -n "class mmu_ref_model\|shadow\|tlb\|invalidate\|translate\|PFU\|PMP\|sysmap\|TODO" mmu_verification/testbench/env/mmu_ref_model.svh` | Complete-doc | 本文件和 BuildPlan Phase 6C | 确认 Phase 4 要求 transaction-level L2TLB model；现有 `translation_sb` 有 final-response compare、PTW request shadow 和部分 PFU/SATP/abort 处理，`invalidate_sb` 只计数，`credit_sb` 偏 health/drain，`ref_model` 尚未维护 L2TLB entry shadow；已在第 4.3 节写入模型契约和 TP/checker 映射。 | 后续实现必须补 L2 entry shadow、ReqQ/MB/PTW/PFU/TLBOP ownership、payload-ignore、timeout/fairness classifier、mismatch taxonomy 和 run evidence；本轮未运行仿真、未改行为代码。 |
| 2026-05-23 | Phase 6C implementation | `git diff --check`；`make comp_fast`（workdir: `mmu_verification/`）；`make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`bash scripts/check_sim_status.sh <log>` | Pass | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log` | 已实现 `mmu_l2tlb_txn_shadow` 并通过 config_db 接入 env/translation/invalidate scoreboard；tag/refill smoke summary 为 `ptw_req=200 ptw_data=200 l2_miss=200 inv=1 cp0_all_inv=3 mismatch=0 waived_future=0`；PFU smoke summary 为 `ptw_req=32 ptw_fault=32 pfu=32 payload_ignore=64 mismatch=0 waived_future=0`；INVALL smoke summary 为 `inv=8 cp0_all_inv=9 reset_epochs=1 abort_epochs=8 control_epochs=9 mismatch=0 waived_future=0`。 | `test_mmu_dir_l2tlb_inv_all` seed 63002 长跑根因为 wrapper 同时运行 64 次 INVALL 和完整 smoke vseq，且 `PTW_CHAIN_DBG` 默认打开导致大量日志；已收敛为短 INVALL directed wrapper，并将 PTW chain debug 改为 opt-in。TLBOP exact decode/readback、ReqQ no-cross、full MB/OOO、timeout/fairness 和 RRPV exact model 继续由后续阶段关闭。 |
| 2026-05-23 | Phase 6D docs | `rg -n "L2TLB_SVA_[0-9]{3}\|SVA Requirement\|must\|debug\|future" doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`sed -n '1,260p' mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`；`sed -n '1,260p' mmu_verification/testbench/top/mmu_arb_sva.sv`；`sed -n '1,220p' mmu_verification/testbench/top/credit_sva.sv`；`rg -n "mmu_l2tlb_rrpv_sva\|mmu_arb_sva\|credit_sva\|bind\|sva" mmu_verification/testbench/top/tb_top.sv mmu_verification/testbench/Files.f`；`sed` read of `mmu/rtl/mmu_l2tlb*.sv` and `mmu/rtl/mmu_arb.sv` ports | Superseded by implementation | 本文件和 BuildPlan Phase 6D | 初始 docs baseline 确认 Phase 3 `L2TLB_SVA_001..024` 来源和原有 SVA/bind 缺口；随后 Phase6D implementation row 已实现稳定 bind 子项并更新第 5 节逐项状态。 | 保留为只读审计历史；实际 6D 状态以 Phase 6D implementation row、issue 012 和 waiver/future rows 为准。 |
| 2026-05-23 | Phase 6D implementation | `git diff --check`；`make comp_fast`（workdir: `mmu_verification/`）；`make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_rand_l2tlb_bank_conflict_multi_source SEED=63004 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`bash scripts/check_sim_status.sh <log>` | Pass | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log`；`mmu_verification/output/logs/test_mmu_rand_l2tlb_bank_conflict_multi_source_63004.log` | 已扩展 arbiter/ReqQ/L2/MB SVA 并新增 `mmu_l2tlb_mb_sva` bind/include。Cover evidence：`credit_sva.c_dtlb_alloc_issue=200`，`mmu_l2tlb_mb_sva.c_mb_dtlb_alloc=200`，`mmu_arb_sva.c_prefetch_mask_release=32`，`mmu_l2tlb_rrpv_sva.c_ptw_fault_completion=32`。四条 smoke 均 `UVM_ERROR=0`、`UVM_FATAL=0` 且 `check_sim_status.sh` PASS。 | 未命中 cover：ReqQ/PFU conflict、ptw_on/tlboper_on block、PTW ready backpressure、MB abort outstanding、multi-hit/PTW-disabled terminal、retry feedback。`L2TLB_SVA_002/015/017/022..024` 和 `L2TLB_SVA_013` type-exact/bad-ID negative 继续由 6E/6F/6G 或 future/waiver 关闭。 |
| 2026-05-23 | Phase 6E docs | `find mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests mmu_verification/testbench/test/flush_tests mmu_verification/testbench/test/ptw_tests mmu_verification/testbench/test/perf_tests -maxdepth 1 -type f \| sort`；`rg -n "l2tlb_tests_suite\|tlbop_tests_suite\|flush_tests_suite\|ptw_tests_suite\|perf_tests_suite\|err_tests\|bug_hunt\|ptw_lsu_protocol" mmu_verification/testbench/test/test_pkg.sv mmu_verification/testbench/test/*/*_suite.svh`；`rg -n "ptw_mem_ooo_rsp_seq\|cp0_ptw_disable_seq\|lsu_prefetch_pipe2_seq\|mmu_reset_midtransaction_vseq" ...`；read `ptw_mem_sequences.svh` and `test_mbuf_ooo_response.svh` OOO notes | Complete-doc | 本文件和 BuildPlan Phase 6E | 确认 `l2tlb_tests` 42、`tlbop_tests` 25、`flush_tests` 9、`ptw_tests` 74、`perf_tests` 22、err/bug/protocol 35 个候选 wrapper 已在 suite/test_pkg 可见；但多为粗粒度 Phase9/12 wrapper。已在第 4.4 节记录 must-add directed/negative matrix、metadata/run-list 规则和 OOO PTW obsolete 分类。 | 后续实现必须补 trigger gate、checker/SVA gate、targeted run list、run log 或 waiver；本轮未运行仿真、未新增 wrapper、未改 suite/include。 |
| 2026-05-23 | Phase 6E implementation | `make comp_fast`（workdir: `mmu_verification/`）；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_directed_p0_list --mode run_check --seeds 64001 --timeout 8000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_negative_list --mode run_check --seeds 64001 --timeout 8000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_debug_rrpv_list --mode run_check --seeds 64001 --timeout 10000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_timeout_fairness_list --mode run_check --seeds 64001 --timeout 12000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；后续 root-cause 复跑 `make run TEST_NAME=test_l2tlb_p6e_timeout_fairness_release SEED=64001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000`；PTW source closure 单测和 Phase6G targeted list 复跑 | Implemented-open | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu_64001.log`；`test_l2tlb_p6e_reqq_arb_payload_owner_64001.log`；`test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask_64001.log`；`test_l2tlb_p6e_ptw_disabled_fault_accerr_64001.log`；`test_l2tlb_p6e_tlbop_inv_abort_lifecycle_64001.log`；`test_l2tlb_p6e_negative_ptw_completion_control_64001.log`；`test_l2tlb_p6e_rrpv_debug_pressure_64001.log`；`test_l2tlb_p6e_timeout_fairness_release_64001.log` | 已新增 Phase6E base/suite/wrappers/run lists。Directed P0 原 4/4 pass；PTW source closure 后 targeted list 更新为 5/5 pass。PTW source closure shadow delta `activity=55 ptw_req=10 ptw_fault=10 pfu=3 payload_ignore=17`，12 个 disabled/page-fault/access-error source/result counter 全部 >0。RRPV debug `activity=246`，但 exact victim/RRPV/wbuf 保持 future。Timeout/fairness 初始失败已 root-caused 为 PFU payload compare、L1DTLB MB current-window 和 ReqQ back-to-back SVA policy 的 testbench 问题。 | Timeout/fairness seed 64001 复跑已 clean；PTW source closure seed 64001 `UVM_WARNING=0`、`UVM_ERROR=0`、`UVM_FATAL=0`、`PHASE6C_L2_SHADOW mismatch=0 waived_future=0`。bad completion/control-hazard injector 和 RRPV exact model 仍未关闭。 |
| 2026-05-23 | Phase 6F docs | `rg -n "RRPV\|replacement\|victim\|wbuf\|L2TLB_TP_045\|L2TLB_SVA_022" doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`find mmu_verification/testbench/test/{l2tlb_tests,tlbop_tests,perf_tests,bug_hunt_tests} -maxdepth 1 -name '*rrpv*.svh'`；`rg -n "p9_tc_id\|p9_seq_desc\|p9_checker\|m_vseq_names" ...rrpv...`；`sed -n '1,220p' mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`；`rg -n "rrpv\|wbuf\|victim\|l2_bank\|l2_final_way" mmu_verification/testbench/env/mmu_dut_probes_if.sv mmu_verification/testbench/env/mmu_env_cg_whitebox.svh mmu_verification/testbench/top/tb_top.sv mmu/rtl/mmu_l2tlb*.sv` | Complete-doc | 本文件和 BuildPlan Phase 6F | 确认 `l2tlb_tests` 中 14 个 RRPV wrapper、`tlbop_tests` 1 个 TLBWR/RRPV wrapper、`perf_tests` 1 个 RRPV stress wrapper、`bug_hunt_tests` 1 个 post-inv wrapper；多数 RRPV wrapper 复用 `mmu_rrpv_aging_vseq` 且 checker 为 `credit_sb`，现有 whitebox coverage 只有 bank/way/page-size debug surface。已在第 4.5 节完成 v1/debug/future 分类。 | 后续实现必须补 `phase6f_class` metadata、`L2TLB_SVA_022` 或等价 checker、debug coverage/run log；`L2TLB_SVA_023/024` 和 exact victim/RRPV/wbuf latest-wins 继续 future；本轮未运行仿真、未改行为代码。 |
| 2026-05-23 | Phase 6F implementation | `git diff --check`；`make comp_fast`（workdir: `mmu_verification/`）；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6f_debug_rrpv_list --mode run_check --seeds 65001 --timeout 10000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`bash scripts/check_sim_status.sh output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`rg -n "failed at\|PHASE6C_L2_MISMATCH\|c_rrpv_wbuf_\|c_wbuf_full_" output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log` | Pass | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`mmu_verification/output/regression/adhoc/summary.txt` | 已新增并 bind `mmu_l2tlb_rrpv_wbuf_sva`，并在 `mmu_arb_sva` 补 wbuf-full no-wrong-grant/PTW-writeback guard；Phase6F metadata/run-list 生效。Run log 输出 `L2TLB_PHASE6F_META/CLOSE`，shadow delta `ptw_req=48 ptw_data=48 l2_hit=96 l2_miss=48 inv=1 cp0_all_inv=2 abort_epoch=1 control_epoch=2 activity=246`；wbuf cover `push_new_entry=96`、`pop=96`、`lookup_bypass_hit=48`。 | `make comp_fast` pass；targeted run `PASS=1 FAIL=0`，`UVM_ERROR=0`、`UVM_FATAL=0`，无 `failed at` 或 `PHASE6C_L2_MISMATCH`。`cam_hit_update/full_seen/true_full_block/full_release/push_pop_same_cycle/c_wbuf_full_blocks_new_reads/c_wbuf_full_allows_ptw_writeback` cover 为 0，转 6G targeted coverage；exact victim/RRPV/latest-wins/merge/same-cycle bypass 保持 future exact model。 |
| 2026-05-23 | Phase 6G docs | Read Makefile coverage/regress targets；read `scripts/run_test.py`、`scripts/check_sim_status.sh`、`scripts/phase13_exit_gate.py`、`scripts/phase14_exit_gate.py`、`scripts/l1dtlb_phase6g_closure.py`、`scripts/l1dtlb_phase6g_replay.py`；read `simu/mmu_smoke_list`、`simu/mmu_nightly_list`、`simu/mmu_coverage_list`、`simu/l1dtlb_phase6g_*`；read `scripts/cov_hier.cfg`、`mmu_env_cg_whitebox.svh` and existing `output/coverage/phase14_urgReport` summaries | Superseded by implementation | 本文件和 BuildPlan Phase 6G | 初始 docs baseline 确认已有 Makefile/run_cov/URG、generic regression、log checker、Phase13/14 gate 和 L1DTLB Phase6G manifest/closure/replay 模式可复用；当时缺少 L2TLB-specific `l2tlb_phase6g_*` run list、manifest、closure scanner 或 L2-specific log fallback。既有 Phase14 URG 中 `cg_tlboper_fsm` 6.25、`cg_l2_reqq` 58.33、`cg_l2tlb_bank` 80.08、`cg_ptw_walk` 77.08，且 assertion failures 为 1，不能作为 L2TLB Phase6G closure。 | 保留为只读审计历史；实际 6G 状态以 Phase 6G implementation row、issue 013/015 和 manifest/closure report 为准。 |
| 2026-05-23 | Phase 6G implementation | `python3 -m py_compile scripts/l2tlb_phase6g_closure.py scripts/l2tlb_phase6g_replay.py`；`git diff --check`；`make comp_fast`（workdir: `mmu_verification/`）；Phase6G smoke/targeted/negative/debug runs；timeout/fairness 和 TLBOP/PTW LSU root-cause 后单测复跑；PTW source closure 单测和 targeted list 5/5；`python3 scripts/l2tlb_phase6g_closure.py --manifest simu/l2tlb_phase6g_evidence_manifest.tsv --compile-log output/logs/comp_fast.log` | Pass | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_*_64001.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`mmu_verification/output/regression/l2tlb_phase6g_closure/closure_report.md`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv` | 5 个 Phase6G run list、12-row manifest、closure scanner 和 replay helper 已落地。新增 `P6E_PTW_SOURCE_FAULT_CLOSURE` row 要求 PTW disabled/page-fault/access-error 四源 counter、payload-ignore、shadow clean 和 UVM clean。Timeout/fairness row 要求 `activity>0`、`pfu>0`、`payload_ignore>0`、shadow mismatch/waiver 为 0、UVM clean 和 `c_d_req_back_to_back_valid>0`；TLBOP row 要求 abort/control epoch、shadow clean、UVM clean 和 `cp_lsu_abort_entry_clear>0`。 | Default closure gate `STATUS=PASS PASS=12 OPEN=0 FAIL=0 TOTAL=12`。`P6E_TLBOP_INV_ABORT`、`P6G_TIMEOUT_FAIRNESS_CLOSURE` 和 `P6E_PTW_SOURCE_FAULT_CLOSURE` 均已 closure；negative injector 和 RRPV exact/future 项仍需后续专项或 waiver/future 更新。 |

## 7. Issue 日志

Issue type 值：`RTL bug`、`UVM bug`、`Spec gap`、`Tooling issue`、`Probe gap`、`Regression gap`、`Approved waiver`。

| ID | 日期 | Type | Severity | 相关 TP/SVA | 描述 | Owner | 状态 | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB-P6-ISSUE-001 | 2026-05-21 | Regression gap | Low | Phase 6 | Phase 6 是文档阶段，未运行仿真。 | TBD | Open | 后续已批准实现阶段记录 baseline compile/regression 后关闭。 |
| L2TLB-P6-ISSUE-002 | 2026-05-23 | Probe gap | Medium | Phase 6A / 6C / 6D | 现有代码已有大量 L2TLB white-box probe，但 Phase6A 原文未展开 inventory、consumer 和 missing-signal decision，后续阶段容易把“有信号/有 wrapper”误判为“已验证”。 | TBD | Closed-doc | 已在 BuildPlan Phase6A 补 inventory、decision table 和 consumer list；后续 6C/6D 若需要新增观察源，必须回到 6A 增补或写 waiver。 |
| L2TLB-P6-ISSUE-003 | 2026-05-23 | Tooling issue | Low | Phase 6A compile baseline | `make comp_fast` 和 full `make comp` 均通过，但日志有 locale warning 和 VCS csrc clock skew warning。 | TBD | Open | 当前不阻塞 Phase6A compile baseline；正式 regression 前建议刷新 csrc mtimes 或 clean rebuild，并记录是否仍出现 clock skew。 |
| L2TLB-P6-ISSUE-004 | 2026-05-23 | Regression gap | High | Phase 6B / `L2TLB_TP_001..058` | 现有 `l2tlb_tests/` 与 `tlbop_tests/` wrapper 已 include 到 `test_pkg.sv`，但不少是 Phase9 generated wrapper，且可复用通用 vseq/checker；wrapper 名称、`p9_tc_id` 或 `TC-*` 不能证明目标 L2TLB 场景已触发或已检查。 | TBD | Closed-doc | BuildPlan Phase6B 已加入 wrapper inventory、metadata contract 和逐 ID 初始映射；后续关闭必须同时提供 trigger evidence 与 pass/fail evidence。 |
| L2TLB-P6-ISSUE-005 | 2026-05-23 | Regression gap | High | Phase 6B / P0/P1 TP coverage | 现有 test case 不足以完成 L2TLB 测试点覆盖关闭；reset/PTW disabled/PTW fault/ready/OOO/PFU/negative/control hazard/timeout 等场景缺 wrapper 或缺 checker/SVA/coverage evidence。 | TBD | Open | 已在 BuildPlan Phase6B sufficiency conclusion 和本文件第 4.2 节列出必补内容；后续 6C/6D/6E/6G 必须逐项补证据或 waiver。 |
| L2TLB-P6-ISSUE-006 | 2026-05-23 | Regression gap | High | Phase 6C / Phase 4 scoreboard boundary | 原有 `mmu_translation_sb`、`mmu_invalidate_sb`、`mmu_credit_sb`、`mmu_ref_model` 不能提供 L2 entry shadow、payload-ignore 和统一 mismatch taxonomy。 | TBD | Closed | 已新增 `mmu_l2tlb_txn_shadow` 并接入 translation/invalidate scoreboard，完成 PTW refill shadow、L2 final 可见比较、INV/CP0 all-inv、epoch、PFU classifier、payload-ignore 和 mismatch taxonomy；剩余非 core closure 由 `L2TLB-P6-ISSUE-011` 跟踪。 |
| L2TLB-P6-ISSUE-007 | 2026-05-23 | Regression gap | High | Phase 6D / `L2TLB_SVA_001..024` | 初始 docs baseline 发现原有 SVA/bind 只覆盖少量局部 property，不足以关闭 Phase 3 must set。 | TBD | Closed | Phase6D implementation 已扩展 arbiter/ReqQ/L2/MB SVA 并新增 MB bind；剩余 reset-inv、TLBOP lifecycle、control hazard、RRPV wbuf/exact 和未命中 cover 由 `L2TLB-P6-ISSUE-012` 与 waiver/future rows 跟踪。 |
| L2TLB-P6-ISSUE-008 | 2026-05-23 | Regression gap | High | Phase 6E / directed and negative tests | 现有 directed/stress/negative-looking wrapper 数量较多，但缺 per-scenario trigger gate、checker/SVA gate、negative 隔离和 targeted run evidence；PFU、PTW disabled/fault/access error、control hazard、timeout/fairness、reset/TLBOP cross 等 P0/P1 不能直接关闭。 | TBD | Partially closed / Open follow-up | Phase6E 已新增 base/suite/wrappers/run lists 和 shadow-delta trigger gate；directed P0、PTW disabled/fault/access-error source closure、negative 分类、RRPV debug 和 timeout/fairness closure 有 targeted evidence。bad-completion/control-hazard injector 仍保持 open。 |
| L2TLB-P6-ISSUE-009 | 2026-05-23 | Regression gap | Medium | Phase 6F / `L2TLB_TP_045..047`, `L2TLB_SVA_023..024` | 现有 RRPV/replacement wrapper 名称包含 init、aging、victim、wbuf 等 exact 意图，但多数复用 `mmu_rrpv_aging_vseq` 和 `credit_sb`，且现有 probe/coverage 只有有限 bank/way/page-size debug surface；不能关闭 exact victim、exact RRPV value 或 wbuf latest-wins/merge。 | TBD | Open / Future exact | Phase6F 已补 `phase6f_class` metadata、`L2TLB_SVA_022` debug SVA 和 targeted run evidence；但 exact victim/RRPV/latest-wins/merge/same-cycle bypass 仍保持 future exact model，不能由 debug pass 关闭。 |
| L2TLB-P6-ISSUE-010 | 2026-05-23 | Regression gap | High | Phase 6G / closure evidence | 现有全局 regression、coverage list、Phase14 URG 和 generic pass summary 缺 L2TLB-specific manifest/run-list/scanner，不能逐项关闭 `L2TLB_TP_001..058`、`L2TLB_SVA_001..024`；whitebox coverage 缺部分 L2-specific log fallback，既有 Phase14 report 仍有 L2 group coverage 缺口和 assertion failure。 | TBD | Closed with waiver/future follow-up | Phase6G 已新增 L2TLB-specific run list、manifest、closure scanner 和 replay flow；timeout/fairness、TLBOP/PTW LSU root-cause 和 PTW source-specific harness 均已关闭，default scanner `STATUS=PASS`。negative injector、RRPV exact/future 项仍需后续补证据或 waiver/future 更新。 |
| L2TLB-P6-ISSUE-011 | 2026-05-23 | Regression gap | High | Phase 6C follow-up / `L2TLB_TP_004..011`, `034..044`, `049..050`, `055..056` | Phase6C core helper 已实现，且 INVALL seed 63002 长跑问题已修正并补入短 directed pass evidence；但当前 CP0/invalidate path 仍没有稳定 TLBP/TLBR/TLBWI/TLBWR exact transaction decode/readback，ReqQ/arbiter payload no-cross、完整 MB/OOO/ready policy 和 timeout/fairness 也未关闭。 | TBD | Open | 后续 6D/6E/6G 必须补 monitor/probe/SVA、directed trigger gate、run log/coverage 或 approved waiver；本轮完成记录不把这些 TP 标为 covered。 |
| L2TLB-P6-ISSUE-012 | 2026-05-23 | Regression gap | High | Phase 6D / `L2TLB_SVA_001..024` | Phase6D 已实现稳定 bind SVA 并通过 assertion-enabled compile/smoke，但 full reset-inv boundary、full TLBOP lifecycle、control hazard negative、RRPV wbuf debug no-overflow/no-wrong-grant、exact replacement/RRPV 和部分 cover trigger 仍未关闭。 | TBD | Open | `L2TLB_SVA_002/015/017` 转 6E directed/negative；`L2TLB_SVA_022` 转 6F debug；`L2TLB_SVA_023/024` 保持 future exact model；未命中 cover 转 6G closure manifest。 |
| L2TLB-P6-ISSUE-013 | 2026-05-23 | Regression gap | High | Phase 6E / `L2TLB_TP_049..050` | `test_l2tlb_p6e_timeout_fairness_release` seed 64001 初始失败：真实 Phase6C shadow delta `ptw_req=118 ptw_data=118 l2_hit=74 l2_miss=118 pfu=52 payload_ignore=52 activity=544` 后出现 `UVM_ERROR=94`、translation SB 52 个 PA/fault mismatch、L1DTLB spec SB `P6D_MB_CAM_HIT=6` 和 `P6D_ALLOC_MISS=6`。 | TBD | Closed | Root-cause 为 testbench/checker 问题：PFU flag-only 诊断位不应触发 PA payload compare，L1DTLB MB CAM 应允许当前 sampled MB window，DTLB ReqQ 可合法 back-to-back 发不同 miss。已修正并复跑 seed 64001：`UVM_ERROR=0`、`UVM_FATAL=0`、`PHASE6C_L2_SHADOW:mismatch=0`、`c_d_req_back_to_back_valid=2`；manifest row 已改为 closure。 |
| L2TLB-P6-ISSUE-014 | 2026-05-23 | Regression gap | Medium | Phase 6F / `L2TLB_TP_046`; `L2TLB_SVA_022..024` | Phase6F targeted run seed 65001 命中 wbuf push/pop/lookup-bypass，但 `cam_hit_update`、`full_seen`、`true_full_block`、`full_release`、`push_pop_same_cycle`、`c_wbuf_full_blocks_new_reads`、`c_wbuf_full_allows_ptw_writeback` cover 均为 0。 | TBD | Open | Basic wbuf no-overflow/accounting/no-wrong-grant SVA 已通过；full stall/release、CAM merge、PTW writeback under full、same-cycle bypass 和 latest-wins 压力转 6G targeted coverage 或 future exact-model，不能用本次 PASS 关闭。 |
| L2TLB-P6-ISSUE-015 | 2026-05-23 | Regression gap | High | Phase 6G / `L2TLB_TP_034..044`; `L2TLB_SVA_015/016` | `test_l2tlb_p6e_tlbop_inv_abort_lifecycle` seed 64001 generic run summary PASS 且 `UVM_ERROR=0`，但 log 中曾存在 `mmu_ptw_lsu_protocol_sva.a_mbuf_ptr_only_on_response` 的 `failed at` 行。 | TBD | Closed | Root-cause 为 SVA 过窄：`mbuf_entry_on` 是 per-entry LSU outstanding/lifecycle marker，除 request accept 和 response 外，TLBOP abort 通过 `mbuf_all_clr` 同步清零也会合法改变它。已改为 `a_mbuf_entry_on_changes_on_lifecycle_event` 并新增 `cp_lsu_abort_entry_clear` cover；seed 64001 复跑 `UVM_ERROR=0`、无 `failed at`、`cp_lsu_abort_entry_clear=6`，manifest row 改为 closure。 |

## 8. Waiver 日志

本表记录 implementation 阶段已批准或待批准的 scope waiver/future/deferred 项。`Approved` 只表示当前 phase 不阻塞，不表示最终 closure 已关闭。

| Waiver ID | 相关 TP/SVA | 未达门禁 | Reason | Replacement check / evidence | Risk | Approver | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB-WAIVE-P6D-001 | `L2TLB_SVA_002` | Phase6D 未实现 full reset-inv boundary | reset-inv request/done 与普通 IFU/LSU/PFU request 阻断需要 dedicated directed trigger 和 top-level epoch/handshake 判定；当前稳定 bind 只覆盖 reset visible drain。 | Phase6C reset/control epoch + Phase6D reset drain SVA；6E/6G 补 reset-inv directed 或 closure waiver。 | reset-inv 期间伪 request/refill 的协议风险未由 6D 单独判错。 | TBD | Deferred to 6E/6G |
| L2TLB-WAIVE-P6D-002 | `L2TLB_SVA_015` | Phase6D 未实现 full TLBOP lifecycle ordering | TLBP/TLBR/TLBWI/TLBWR/INV* per-op request/grant/cmplt/done/readback 需要稳定 transaction decode；6D 只覆盖 L2 no-X、arbiter tlboper_on block 和 abort visible state。 | Phase6C INV/epoch helper + Phase6D arbiter block SVA；6E directed TLBOP lifecycle 或 approved waiver。 | early/missing/duplicate done 的 per-op 风险未由 6D 全关闭。 | TBD | Deferred to 6E |
| L2TLB-WAIVE-P6D-003 | `L2TLB_SVA_017` | Phase6D 未实现 control hazard negative assertion | SATP/ASID/MMU/PTW control write with outstanding translation/PTW 属 isolated negative 场景，普通 smoke 不应注入非法协议。 | Phase6C epoch handling；后续 6E negative suite 检查 expected assertion/error handling。 | 控制 hazard 负向协议风险需后续专门触发。 | TBD | Deferred to 6E |
| L2TLB-WAIVE-P6D-004 | `L2TLB_SVA_022..024` | Phase6D 不关闭 RRPV wbuf debug/exact replacement | wbuf no-overflow/no-wrong-grant、exact victim、exact RRPV value、latest-wins/merge 需要 Phase6F debug/future 分类和可能的 exact model。 | Phase6D 已覆盖 arbiter wbuf full blocks new reads；Phase6F 补 debug SVA/coverage 或保持 future exact model。 | replacement/RRPV exact 行为不能由 Phase6D pass 证明。 | TBD | Deferred/Future |
| L2TLB-WAIVE-P6D-005 | Phase6D cover holes | 部分 SVA cover 未命中 | 当前四条 smoke 覆盖 ReqQ/MB DTLB alloc、PFU mask release、PTW fault completion，但未触发 ReqQ/PFU conflict、ptw_on/tlboper_on block、PTW ready backpressure、MB abort outstanding、terminal multi-hit 等。 | 6D assertion pass evidence；6G targeted run list/closure manifest 逐项补 cover 或 waiver。 | 未命中场景不能作为 coverage complete。 | TBD | Deferred to 6G |
| L2TLB-WAIVE-P6E-001 | `L2TLB_TP_018`, `025..026`, `033`; `L2TLB_SVA_012/014` | Superseded by closure | 原 waiver 原因是缺 PTW disabled/fault/access-error source-specific positive closure。 | `test_l2tlb_p6e_ptw_disabled_fault_accerr` seed 64001 已提供 ITLB/DTLB load/DTLB store/PFU x disabled/page-fault/access-error evidence；manifest row `P6E_PTW_SOURCE_FAULT_CLOSURE` pass。 | 原 owner-specific PTW disabled/fault/access-error 风险已关闭；仍保留的 negative injector 风险由 `L2TLB-WAIVE-P6E-002` 跟踪。 | N/A | Superseded/Closed |
| L2TLB-WAIVE-P6E-002 | `L2TLB_TP_027`, `048`, `056`, `058`; `L2TLB_SVA_012/013/017/018` | Phase6E 未关闭 bad PTW completion/control-hazard negative | 当前没有 approved bad-completion/control-hazard injector；legacy OOO wrapper 是 obsolete/warning-only，不能关闭 normal or negative coverage。 | `test_l2tlb_p6e_negative_ptw_completion_control` 只证明 negative wrapper 隔离和 waiver token；不关闭功能 TP。 | 协议违规 completion、bad ID、控制 hazard 的负向判错仍未验证。 | TBD | Deferred/Open |
| L2TLB-WAIVE-P6E-003 | `L2TLB_TP_045..047`; `L2TLB_SVA_022..024` | Phase6E 不关闭 exact RRPV/replacement | `test_l2tlb_p6e_rrpv_debug_pressure` 有真实 pressure delta，但 exact victim、exact RRPV value、wbuf latest-wins/merge 需要 Phase6F/future exact model。 | RRPV debug run `UVM_ERROR=0` 且 shadow delta `activity=246`；只作为 debug pressure evidence。 | Replacement/RRPV exact 行为不能由 debug pressure pass 证明。 | TBD | Deferred/Future |
| L2TLB-WAIVE-P6F-001 | `L2TLB_TP_045..047`; `L2TLB_SVA_023..024` | Phase6F 不关闭 exact replacement/RRPV model | Phase6F 实现范围是 visible-result/debug SVA/coverage 分类；没有 cycle-accurate victim/free-way/max-RRPV、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass reference model。 | `L2TLB_SVA_022` debug SVA pass；Phase6F metadata 明确 `future_exact_items="exact_victim,exact_rrpv_value,wbuf_latest_wins,wbuf_merge,same_cycle_bypass"`。 | exact replacement/RRPV bug 仍需 future exact-model 专项验证。 | TBD | Future |
| L2TLB-WAIVE-P6F-002 | `L2TLB_TP_046`; `L2TLB_SVA_022..024` | Phase6F targeted run 未命中 wbuf full/CAM-hit/same-cycle/PTW-writeback cover | seed 65001 的 `mmu_rrpv_aging_vseq` 产生 push/pop/lookup-bypass pressure，但没有填满 wbuf、制造 CAM-hit/same-cycle push-pop，或覆盖 full 下 PTW writeback。 | cover hit：push_new_entry=96、pop=96、lookup_bypass_hit=48；cover hole：cam_hit/full/full-release/same-cycle/arbiter full-block/PTW-writeback=0。 | wbuf full stall/release、PTW writeback under full 和 latest-wins/same-cycle 风险未由本次 run 覆盖。 | TBD | Deferred to 6G |

Waiver 规则：

- Waiver 必须写明精确 audit ID 和当前阶段无法关闭的原因。
- Waiver 必须说明缺失项是否由其他 checker、debug-only evidence 或 future work 覆盖。
- Tooling failure 只有在记录 log fallback evidence 后才能 waiver。
- 缺失稳定 probe 必须先在 Phase 6A 中评估，不能直接 waive checker coverage。
- Coverage 未达、SVA cover 未达、trigger 未命中都必须逐项记录，不能以总体 regression pass 替代。

## 9. Phase 6/7 Exit Record

| 检查 | 状态 | 说明 |
| --- | --- | --- |
| `L2TLB_UVM_Phase6_BuildPlan.md` 存在 | Complete | 已创建为后续实现蓝图。 |
| `L2TLB_UVM_Phase6_Progress.md` 存在 | Complete | 已创建为后续实现 tracker。 |
| Phase 6 文档已中文化 | Complete | BuildPlan 和 Progress 已改为中文表达。 |
| 子阶段进度模板已初始化 | Complete | 已列出 6A 到 6G。 |
| Phase 6B 进度已更新到 Progress | Complete-doc | 第 2 节状态矩阵、第 4 节 TP 分组、第 4.1 节 scenario registry、第 4.2 节 sufficiency gap、第 6 节 evidence、第 7 节 issue 均已记录；不声明功能 coverage 关闭。 |
| Phase 6C 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 4.3 节 scoreboard/ref-model baseline、第 6 节 implementation evidence、第 7 节 issue 均已记录；声明 Phase6C core scoreboard/helper 已实现，不声明 `L2TLB_TP_001..058` 功能 coverage 全关闭。 |
| Phase 6D 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 5 节 SVA/bind inventory 与逐条 implementation 状态、第 6 节 evidence、第 7 节 issue、第 8 节 waiver/future 均已记录；声明 Phase6D 稳定 SVA/bind 已实现，不声明所有 SVA cover 或 TP coverage 全关闭。 |
| Phase 6E 进度已更新到 Progress | Implemented-open | 第 2 节状态矩阵、第 4.4 节 directed/negative baseline、第 6 节 implementation evidence、第 7 节 issue、第 8 节 waiver/deferred 均已记录；声明 Phase6E infrastructure/wrapper/run-list 已实现，timeout/fairness 和 PTW source-specific harness 已关闭，但 negative injector 和 RRPV exact model 未关闭。 |
| Phase 6F 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 4.5 节 RRPV/replacement baseline、第 5 节 SVA 状态、第 6 节 implementation evidence、第 7/8 节 issue/waiver 均已记录；声明 `L2TLB_SVA_022` debug baseline 已实现并通过 targeted run，不声明 exact replacement model 或 full/latest-wins/same-cycle coverage 关闭。 |
| Phase 6G 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 4.6 节 coverage/regression/closure baseline、第 6 节 implementation evidence、第 7 节 issue 均已记录；声明 run list、manifest、scanner、replay 已实现；`L2TLB-P6-ISSUE-013` 和 `L2TLB-P6-ISSUE-015` 均已关闭，default gate PASS。 |
| Evidence、issue、waiver 模板已初始化 | Complete | 后续阶段需逐 run 和逐 exception 填写。 |
| 6A~6G 严格退出门禁已补充 | Complete | 进入条件、交付物、检查证据、pass/fail、coverage/SVA/log 和 waiver 均已定义。 |
| Phase 6/7 行为代码修改边界 | Complete | Phase6C/6D 已修改 UVM/testbench/SVA 文档内允许范围；未修改 DUT/RTL。 |
| 后续实现批准 | In progress | Phase6C/6D/6F/6G 已完成 core/debug/closure-tool implementation；Phase6E timeout/fairness root-cause 和 PTW source-specific harness 已关闭；Phase6G default closure gate `STATUS=PASS`。后续重点是 negative injector、RRPV exact/wbuf full 等 waiver/future follow-up。 |
