# L2TLB UVM Audit 进度

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：基于功能描述的 L2TLB audit 与后续 UVM 重定向
> 黄金输入：`doc/l2tlb_uvm_audit/l2tlb_function_description.txt`
> 工作规格：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 更新时间：2026-05-21

## 整体状态

| Phase | 名称 | 状态 | 说明 |
| --- | --- | --- | --- |
| Phase 0 | 基线审计与保护 | 已完成 | 已确认黄金输入和 audit 目录；不修改 `.txt`，不修改 RTL/UVM 行为 |
| Phase 1 | 创建 markdown 工作副本 | 已完成 | `l2tlb_function_description.md` 已从 `l2tlb_function_description.txt` 创建 |
| Phase 2 | 总结 L2TLB 所有测试点 | 已完成 | 已从头重做 Phase 2：删除旧第 6 章草稿，新增并补充到 `L2TLB_TP_001..058` 测试点清单，并生成对齐 Excel |
| Phase 3 | 补充必要 SVA | 已完成 | 已补充 `L2TLB_SVA_001..024` SVA requirement，只定义需求，不修改 SystemVerilog/UVM 行为代码 |
| Phase 4 | 补充 scoreboard/reference model 建模点 | 已完成 | 已补充 Phase 4 transaction-level scoreboard/reference model 建模边界、状态影子、比较规则和 v1 不检查项 |
| Phase 5 | 同步到 `MMU_VerificationPlan_final.md` | 已完成 | 已在主验证计划中新增 L2TLB audit import/override、coverage import、SVA import 和 Appendix F artifact 表；不声明 UVM/RTL 已实现 |
| Phase 6 | L2TLB UVM 分阶段实施计划 | 已完成 | `L2TLB_UVM_Phase6_BuildPlan.md` 已转为指导 6A~6G UVM 修改补充的实施计划；Makefile/run-flow 可按 phase 修改，DUT/RTL 修改需单独同意 |
| Phase 7 | 为 UVM 搭建阶段设计严格退出准则 | 已完成 | 已为 6A~6G 补充严格退出门禁、金标准回查、关键发现记录和完成记录要求 |

## 当前交付物状态

| 交付物 | 路径 | 状态 | 说明 |
| --- | --- | --- | --- |
| 黄金输入 | `doc/l2tlb_uvm_audit/l2tlb_function_description.txt` | 已存在 | 本文件作为只读黄金输入；当前进度文档不声明其内容已被审完 |
| 工作规格 | `doc/l2tlb_uvm_audit/l2tlb_function_description.md` | 已补充 Phase 2/3/4 | 已新增 Phase 2 `L2TLB_TP_001..058` 测试点清单、Phase 3 `L2TLB_SVA_001..024` SVA requirement，并补充 Phase 4 scoreboard/reference model 建模要求 |
| Phase 2 Excel 测试点表 | `doc/l2tlb_uvm_audit/L2TLB_TRISTAN_IP_Hardware_tp_V1.xlsx` | 已创建 | 与 `.md` 中 `L2TLB_TP_001..058` 一一对应 |
| 实施计划 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Audit_ImplementationPlan.md` | 已更新到 Phase 7 | 记录 Phase 0~7 文档阶段完成状态；不批准后续代码实现 |
| 进度文档 | `doc/l2tlb_uvm_audit/progress.md` | 已创建 | 本文件 |
| Phase 6 UVM 分阶段实施计划 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | 已转为实施计划 | 已把 L2TLB UVM 修改补充拆成 6A~6G 子阶段，并为每个子阶段补充金标准回查、关键发现记录和严格退出准则 |
| Phase 6 专用进度文档 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` | 已中文化并补充门禁跟踪 | 已初始化后续实施进度、证据、issue、waiver 和 Phase 7 门禁签核格式；不记录任何 UVM/DUT 代码已实现 |
| 主验证计划同步 | `doc/MMU_VerificationPlan_final.md` | 已完成 | 已同步 Phase 2~4 已 review 内容，并明确 audit `.md` 对旧 F3/F5/TLBOP 冲突条目的优先级 |
| UVM 修改补充实施计划 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | 已转为实施计划 | 指导 6A~6G 分阶段修改补充 UVM/testbench/Makefile/run-flow；DUT/RTL 修改需单独同意 |

## UVM 修改补充进度

### 实施总则

`doc/l2tlb_uvm_audit/l2tlb_function_description.md` 是 L2TLB UVM 修改补充的金标准。每个 phase 不只执行 `L2TLB_UVM_Phase6_BuildPlan.md` 已列内容，还必须主动检查金标准中是否有 BuildPlan 未描述但验证 L2TLB DUT 必须补充的内容。

所有行为以更高质量验证 DUT 为准则，不以完成表面目标为准则。wrapper 名称、历史 regression pass、generic smoke、总 coverage 分数或 `UVM_ERROR=0` 不能替代真实 trigger evidence 和 pass/fail evidence。

`progress.md` 是 UVM 修改补充的主进度记录。每个 phase 在完成目标的过程中，必须先把关键发现记录到本节的“UVM 修改关键发现日志”；phase 完成时，必须填写“UVM Phase 完成记录”。`L2TLB_UVM_Phase6_Progress.md` 可作为详细 tracker，但不能替代本文件的关键发现和完成记录。

Makefile、仿真列表、regression list、脚本和 coverage/report flow 可按 phase 修改。DUT/RTL 修改必须先记录 blocker 或 `dut-suspect` 发现，并在征得明确同意后执行。

### Phase 进度矩阵

| Phase | 名称 | 状态 | 当前目标 | 严格退出准则状态 | 关键发现记录 | 完成证据 | 剩余缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 6A | 可观测性与 monitor 就绪 | Complete | 已对照金标准确认 L2TLB probe/monitor/consumer；本轮未新增 DUT/RTL/UVM 行为代码 | Passed | 已记录 2026-05-23 Phase6A probe/consumer、future/debug 和 `$root` audit 发现 | `mmu_verification/output/logs/comp_all.log`；`make comp` pass | 6A 只关闭可观测性门禁；不关闭任何 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx` 功能正确性 |
| 6B | 场景 ID、wrapper 与 metadata 对齐 | Complete | 已对照 `L2TLB_TP_001..058` 完成 scenario ID、wrapper class、checker owner、trigger evidence 和 pass/fail evidence 要求对齐；本轮未新增 wrapper/include/run-list 或 DUT/RTL/UVM 行为代码 | Passed | 已记录 2026-05-23 Phase6B wrapper 名称风险、testcase 不充分和 debug/future 分类发现 | `L2TLB_UVM_Phase6_BuildPlan.md` Phase 6B；`L2TLB_UVM_Phase6_Progress.md` 第 4.1/4.2 节；Phase6B 只读检查命令 | 6B 只关闭 ID/metadata/wrapper 对齐门禁；不关闭任何 `L2TLB_TP_xxx` 功能 coverage，后续仍需 6C/6D/6E/6G 补 trigger、checker/SVA、run log、coverage 或 waiver |
| 6C | Scoreboard 与 reference model 扩展 | Complete | 已实现 Phase6C transaction-level L2TLB shadow helper，覆盖 PTW request/completion/refill、L2 final 可见结果比较、INV*/CP0 all-inv、reset/abort/control epoch、PFU classifier、payload-ignore 和 mismatch taxonomy；不声明完整 TP coverage closure | Passed (core implementation smoke) | 已记录 2026-05-23 Phase6C helper 实现、PFU payload-ignore 证据和剩余 TLBOP/ReqQ/timeout closure 边界 | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log` | TLBP/TLBR/TLBWI/TLBWR exact transaction decode、ReqQ/arbiter payload no-cross、完整 MB/OOO、timeout/fairness、RRPV/replacement exact model 和 coverage closure 仍由 6D/6E/6F/6G 关闭 |
| 6D | SVA、bind 与 waiver 实现 | Complete | 已实现 Phase6D 稳定 bind SVA：arbiter block/payload/PFU mask、ReqQ pulse/partition/credit/feedback、L2 no-X/PTW/terminal fault、MB partition/issue/backpressure/feedback，并记录 scope waiver/future | Passed (assertion-enabled compile + smoke) | 已记录 2026-05-23 Phase6D SVA 实现、trigger cover 证据、cover hole 和 waiver/future 分类 | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log`；`mmu_verification/output/logs/test_mmu_rand_l2tlb_bank_conflict_multi_source_63004.log` | Full reset-inv boundary、full TLBOP lifecycle、control hazard negative、RRPV wbuf exact/debug no-overflow、exact replacement/RRPV 仍由 6E/6F/6G 或 future/waiver 关闭 |
| 6E | Directed 与 negative test 实现 | Not started | 新增或加强 directed/negative testcase、trigger gate、checker gate、targeted run list | Not checked | TBD | TBD | TBD |
| 6F | RRPV 与 replacement 重分类 | Not started | 完成 v1/debug/future 分类，实现可关闭的 functional-visible/debug assertion，保留 future exact 风险 | Not checked | TBD | TBD | TBD |
| 6G | Coverage、regression 与最终收口 | Not started | 建立 L2TLB-specific run list、manifest、closure scanner/report 和 coverage/log evidence | Not checked | TBD | TBD | TBD |

### UVM 修改关键发现日志

发现类型固定使用：`golden-spec-gap`、`buildplan-gap`、`testcase-insufficient`、`checker-insufficient`、`sva-insufficient`、`coverage-insufficient`、`probe-missing`、`dut-suspect`、`uvm-bug`、`waiver/future`。

| 日期 | Phase | 发现类型 | 相关 TP/SVA/章节 | 发现内容 | 影响 | 处理决定 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-23 | 6A | buildplan-gap | Phase 6A；Phase 4 scoreboard 规则；`L2TLB_TP_001..058`；`L2TLB_SVA_001..024` | 金标准回查后确认 BuildPlan 已补 ReqQ、arbiter、L2 final、MB、PTW、TLBOP、PFU、reset/abort、RRPV/debug 的 probe inventory、missing-signal decision 和 consumer list；当前 repo 的 `mmu_dut_probes_if.sv`、`tb_top.sv` 与现有 monitor/scoreboard consumer 已覆盖 6A 进入 6C/6D 所需基础观察面。 | 后续 checker/SVA 可基于稳定 virtual interface、analysis transaction 或 bind target 取样；不能把 probe 存在误当作 TP/SVA 功能关闭。 | 本轮不新增 probe 或改 DUT/RTL/UVM 行为；后续 6C/6D 若需要新增观察源，必须回到 6A 增补或写 waiver。 | Closed |
| 2026-05-23 | 6A | waiver/future | `L2TLB_TP_045..047`；`L2TLB_SVA_022..024`；Phase 4 replacement/RRPV 边界 | exact replacement victim、exact RRPV value、wbuf merge/latest-wins、direct array state 仍缺少安全 v1 signoff 观察面，且金标准已定义为 debug/future 或 future exact-model。 | 不阻塞 Phase6A compile/probe 门禁，但不能在 6A 或后续 closure 中静默标为 covered。 | 保持 Phase6F debug/future 分类；需要 exact model 时另启专项或回 6A 增补稳定采样源。 | Open |
| 2026-05-23 | 6A | coverage-insufficient | Phase 6A；`L2TLB_TP_001..058`；`L2TLB_SVA_001..024` | Phase6A 只确认观察源、consumer 和 compile health；coverage hit、probe snapshot、`UVM_ERROR=0` 或 generic compile pass 都不能替代场景 trigger evidence 与 pass/fail evidence。 | P0/P1 TP 和 must SVA 仍需 6B~6G 逐项补 scenario metadata、scoreboard/SVA、directed/negative test、coverage/regression 和 closure manifest。 | 6A 完成记录明确不关闭功能 TP/SVA；后续阶段按 BuildPlan 门禁补证据或 waiver/future。 | Closed |
| 2026-05-23 | 6B | testcase-insufficient | Phase 6B；`L2TLB_TP_001..058` | 金标准回查和 wrapper inventory 后确认 `l2tlb_tests/` 42 个 wrapper、`tlbop_tests/` 25 个 wrapper 及 `test_pkg.sv` suite include 可作为候选入口，但多数是 Phase9 generated wrapper 或通用 TLBOP/SFENCE wrapper；wrapper 名称、`p9_tc_id`、`p9_checker` 和 reviewer 字段不能证明目标 TP 已触发或已被独立 checker/SVA 判错。 | 现有 testcase 不足以完成 L2TLB 测试点覆盖关闭；reset、PTW disabled/fault/access error、PFU、negative/control hazard、timeout/fairness、TLBOP reset 等 P0/P1 场景仍需要 wrapper、checker/SVA、trigger gate 或 waiver。 | Phase6B 仅完成 scenario ID、wrapper class、checker owner 和 evidence 类型对齐；后续 6C/6D/6E/6G 必须补 trigger evidence、pass/fail evidence、run log、coverage 或 waiver 后才能把 TP 标为 Complete。 | Closed |
| 2026-05-23 | 6B | coverage-insufficient | Phase 6B metadata contract；`L2TLB_TP_001..058` | 已在 BuildPlan Phase6B 和 `L2TLB_UVM_Phase6_Progress.md` 第 4.1 节为 58 个 TP 分配 `L2TLB_SCN_*`、wrapper class、candidate/new-wrapper/checker/negative/debug/future 状态、checker owner 和 evidence 要求；这些 metadata 只定义关闭门槛，不构成功能覆盖或 regression pass 证据。 | 后续若只运行现有 wrapper、只看 `UVM_ERROR=0`、只看 coverage hit 或只引用历史 pass，会产生假关闭风险。 | Phase6B 完成记录明确禁止用 wrapper 名称、coverage hit 或 generic pass 关闭 TP；每项 TP 仍需同时具备 trigger evidence 和 pass/fail evidence。 | Closed |
| 2026-05-23 | 6B | waiver/future | `L2TLB_TP_016`, `L2TLB_TP_045..047`；replacement/RRPV debug/future 边界 | multi-hit 只能作为 legal-result/debug classifier；RRPV init/wbuf/replacement wrapper 只能作为 debug 或 future exact-model 候选，不能关闭 exact victim、exact RRPV value、wbuf latest-wins/merge。 | 不阻塞 Phase6B ID/metadata 对齐门禁，但后续 closure 不能把 RRPV wrapper 名称或 debug coverage 当作 exact replacement pass/fail。 | 保持 Phase6F 统一处理：v1 只比较 functional-visible result 和 debug/no-overflow/no-wrong-grant 证据；exact replacement/RRPV/wbuf 行为保持 future，除非另启 exact model 阶段。 | Open |
| 2026-05-23 | 6C | checker-insufficient | Phase 6C TLBOP lifecycle；`L2TLB_TP_034..044` | Phase6C v1 helper 已实现 INV*/CP0 all-inv shadow update 和 epoch gating，但当前 CP0/invalidate transaction 观察面没有稳定解码 TLBP/TLBR/TLBWI/TLBWR request/grant/done/readback 的完整事务字段。 | 不能用当前 Phase6C helper 单独关闭 TLBP/TLBR/TLBWI/TLBWR exact read/write 语义；这些场景仍需专门 monitor/probe/SVA 或 approved waiver。 | 本轮只关闭 Phase6C 核心 helper 门禁；TLBOP exact transaction decode/readback 保持 6D/6E/6G follow-up。 | Open |
| 2026-05-23 | 6C | testcase-insufficient | Phase 6C smoke evidence；INVALL directed；`L2TLB_TP_041` | `test_mmu_dir_l2tlb_inv_all` seed 63002 长时间未自然结束的根因是 wrapper 同时运行 64 次 `tlb_inv_all_seq` 和完整 `mmu_smoke_vseq`，且 `PTW_CHAIN_DBG` 默认打开导致 PTW 活跃周期大量刷 log；未发现 Phase6C shadow helper 死锁。 | 原 wrapper 不适合作为短 INVALL directed gate，且默认 debug 输出会显著拖慢 wall-clock。 | 已将 wrapper 收敛为 8 次 `tlb_inv_all_seq` directed run，并将 PTW chain debug 改为仅在 `+PTW_CHAIN_DBG` 下打开；seed 63002 已自然结束并纳入 Phase6C pass evidence。 | Closed |
| 2026-05-23 | 6D | sva-insufficient | `L2TLB_SVA_001`, `003..014`, `016`, `018..021` | Phase6D 已把原有局部 SVA 扩展为稳定 bind 断言：`mmu_arb_sva` 覆盖 grant/block/payload/PFU mask，`credit_sva` 覆盖 ReqQ pulse、partition、credit、feedback，`mmu_l2tlb_rrpv_sva` 覆盖 L2 no-X、PTW ready/completion 和 terminal fault，新增 `mmu_l2tlb_mb_sva` 覆盖 MB partition、issue、backpressure、feedback 和 abort visible state。 | must SVA 已具备 assertion-enabled compile/run health 基线，但仍不能把未触发 cover 或未实现 exact/lifecycle 项静默标为 fully closed。 | SVA/bind 实现纳入 compile list 和 coverage exclude；用 `make comp_fast` 和四条 smoke 检查无未解释 assertion failure；剩余项写入 waiver/future。 | Closed |
| 2026-05-23 | 6D | waiver/future | `L2TLB_SVA_002`, `013`, `015`, `017`, `022..024` | Full reset-inv boundary、PTW completion type/exact bad-ID negative、完整 TLBOP lifecycle、control hazard negative、RRPV wbuf no-overflow/no-wrong-grant 和 exact replacement/RRPV 仍缺稳定 directed trigger、transaction decode 或 exact model。 | 不阻塞 Phase6D 稳定 SVA bind 门禁，但这些 ID 不能在 6D 被标为 complete coverage；后续 closure 必须逐项提供 directed trigger、negative assertion evidence、debug evidence、approved waiver 或 future。 | `L2TLB_SVA_002/015/017` 转 6E directed/negative；`L2TLB_SVA_022` 转 6F debug/no-overflow；`L2TLB_SVA_023/024` 保持 future exact model；`L2TLB_SVA_013` 只关闭 outstanding ID 子项，type-exact/bad-ID negative 保持 follow-up。 | Open |
| 2026-05-23 | 6D | coverage-insufficient | Phase6D cover properties；`L2TLB_SVA_005/011/014/019/020/021` | 四条 Phase6D smoke 已命中 ReqQ/MB DTLB allocation、PFU mask release 和 PTW fault completion cover，但未命中 ReqQ/PFU 同周期 conflict、ptw_on/tlboper_on block、PTW ready backpressure、MB abort outstanding、多 hit terminal 等 cover。 | assertion pass 不等价于 cover closure；6G 不能用 generic pass summary 关闭这些 cover hole。 | 已把未命中 cover 作为 6G closure/coverage hole；需要 targeted directed wrapper 或 approved waiver。 | Open |

### UVM Phase 完成记录

| Phase | 完成日期 | 修改文件 | 运行命令/日志 | Trigger evidence | Pass/fail evidence | Waiver/Future | Review 结论 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 6A | 2026-05-23 | `doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；未修改 `mmu_verification/testbench/env/mmu_dut_probes_if.sv`、`mmu_verification/testbench/top/tb_top.sv` 或 DUT/RTL/UVM 行为代码 | `cd mmu_verification && make comp`；日志：`mmu_verification/output/logs/comp_all.log`；补充检查：`rg -n '\$root' mmu_verification/testbench doc/l2tlb_uvm_audit -S`、`rg -n 'l2_reqq_vld_vec|l2mb_vld_vec|l2tlb_ptw_req|ptw_l2tlb_cmplt|tlboper_ptw_abort|pfu_l2tlb_deny|l2_final_vld|rtu_yy_xx_flush|arb_pfu_grant' ...` | Probe/monitor inventory 已覆盖 ReqQ、arbiter grant、L2 final response、miss buffer、PTW request/completion、TLBOP/PFU、reset/abort、RRPV/debug；相关 consumer 包括 `mmu_credit_sb.svh`、`mmu_env_cg_whitebox.svh`、`ptw_source_monitor.svh`、`lsu_monitor.svh`、`mmu_translation_sb.svh` 和 bind SVA。 | `make comp` full VCS compile/elab/link pass，生成 `output/simv`；Verdi KDB elaboration `0 error(s), 0 warning(s)`；compile log error/fatal/UVM fatal 关键字扫描未命中真实错误；testbench checker 未发现未批准 `$root` fragile path。 | exact victim、exact RRPV、wbuf merge/latest-wins、direct array state 保持 Phase6F debug/future；6A 不关闭任何 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx` 功能正确性。 | Phase6A 可观测性与 monitor 就绪门禁完成；允许进入 6B/6C/6D 设计和实现，但后续关闭必须逐项提供 trigger evidence 与 pass/fail evidence。 |
| 6B | 2026-05-23 | `doc/l2tlb_uvm_audit/progress.md`；复用 `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` Phase 6B 和 `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` 第 4.1/4.2 节已有 scenario registry；未修改 `mmu_verification/testbench/test/l2tlb_tests/`、`mmu_verification/testbench/test/tlbop_tests/`、`mmu_verification/testbench/test/test_pkg.sv`、Makefile、run list 或 DUT/RTL/UVM 行为代码 | 只读检查：`rg -n "L2TLB_TP_[0-9]{3}" doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`find mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests -maxdepth 2 -type f \| sort`；`rg -n "l2tlb_tests_suite\|tlbop_tests_suite" mmu_verification/testbench/test/test_pkg.sv`；`rg -n "p9_tc_id\|p9_seq_desc\|p9_checker\|p9_reviewer" mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests` | `L2TLB_TP_001..058` 均已进入 Phase6B scenario registry；每项都有稳定 `L2TLB_SCN_*`、wrapper class、候选/新增 wrapper 或 checker/SVA-only/negative/debug/future 分类、checker owner、expected trigger evidence 和 expected pass/fail evidence 类型。 | Phase6B pass/fail 仅为 metadata/wrapper 对齐完成：现有 `l2tlb_tests/`、`tlbop_tests/` 和 suite include 可见性已审阅；明确现有 testcase 不足以关闭 coverage，wrapper 名称、`p9_tc_id`、coverage hit、历史 pass 或 `UVM_ERROR=0` 均不能作为 TP pass/fail 证据。 | `L2TLB_TP_016` multi-hit 为 debug/checker candidate；`L2TLB_TP_045..047` replacement/RRPV exact victim、exact RRPV、wbuf latest-wins/merge 保持 Phase6F debug/future；negative assertion-only 场景 `L2TLB_TP_027/048/058` 后续必须与 normal regression 分离。 | Phase6B 场景 ID、wrapper 与 metadata 对齐门禁完成；不关闭任何功能 TP coverage。允许进入 6C/6D/6E/6G 补 scoreboard/SVA/test/coverage 证据；P0/P1 缺口必须保持 open 直到有 trigger evidence、pass/fail evidence、run log、coverage 或 approved waiver。 |
| 6C | 2026-05-23 | `mmu_verification/testbench/env/mmu_l2tlb_txn_shadow.svh`；`mmu_verification/testbench/env/mmu_env_pkg.sv`；`mmu_verification/testbench/env/mmu_env.svh`；`mmu_verification/testbench/env/mmu_translation_sb.svh`；`mmu_verification/testbench/env/mmu_invalidate_sb.svh`；`mmu_verification/testbench/lsu_agent/lsu_monitor.svh`；`mmu_verification/testbench/test/l2tlb_tests/test_mmu_dir_l2tlb_inv_all.svh`；`mmu_verification/testbench/top/tb_top.sv`；`doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | `git diff --check`；`cd mmu_verification && make comp_fast`，日志：`mmu_verification/output/logs/comp_fast.log`；`cd mmu_verification && make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`，日志：`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`cd mmu_verification && timeout --kill-after=20s 240s make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`，日志：`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；`cd mmu_verification && timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`，日志：`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log`；三条 run 均经 `bash scripts/check_sim_status.sh <log>` 检查。 | tag/refill smoke summary：`ptw_req=200 ptw_data=200 l2_miss=200 inv=1 cp0_all_inv=3 reset_epochs=1 abort_epochs=1 control_epochs=3`；PFU smoke summary：`ptw_req=32 ptw_fault=32 pfu=32 payload_ignore=64 cp0_all_inv=1 reset_epochs=1 control_epochs=1`；INVALL smoke summary：`inv=8 cp0_all_inv=9 reset_epochs=1 abort_epochs=8 control_epochs=9 mismatch=0 waived_future=0`；summary 由 `m_translation_sb` 和 `m_invalidate_sb` 在 `+UVM_ERR_ONLY` 下 `$display` 输出。 | `make comp_fast` pass；三条 directed smoke `UVM_ERROR=0`、`UVM_FATAL=0`、`mismatch=0`、`waived_future=0`；未出现 `PHASE6C_L2_MISMATCH`、`PHASE6C_L2_WAIVER`、`PHASE6C_L2_SHADOW_FUTURE_REPLACEMENT` 或默认 `PTW_CHAIN_DBG` 输出；`test_pipe2_prefetch_err_63003.log` 覆盖 PFU payload-ignore path，`test_mmu_dir_l2tlb_inv_all_63002.log` 覆盖短 INVALL gate。 | Phase6C v1 不关闭 TLBP/TLBR/TLBWI/TLBWR exact transaction decode/readback、ReqQ/arbiter payload no-cross、完整 MB/OOO/ready policy、timeout/fairness、RRPV exact victim/value/wbuf latest-wins/merge。 | Phase6C 核心 scoreboard/helper 实现完成，INVALL seed 63002 长跑问题已修正并有自然结束 pass evidence；允许后续 6D/6E/6F/6G 基于该 helper 补 SVA、directed trigger、coverage 和 closure；本记录不声明 `L2TLB_TP_001..058` 功能 coverage 已关闭。 |
| 6D | 2026-05-23 | `mmu_verification/testbench/top/mmu_arb_sva.sv`；`mmu_verification/testbench/top/credit_sva.sv`；`mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`；`mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv`；`mmu_verification/testbench/top/tb_top.sv`；`mmu_verification/testbench/Files.f`；`mmu_verification/scripts/cov_hier.cfg`；`doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；未修改 DUT/RTL | `git diff --check`；`cd mmu_verification && make comp_fast`，日志：`mmu_verification/output/logs/comp_fast.log`；`cd mmu_verification && make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_rand_l2tlb_bank_conflict_multi_source SEED=63004 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；四条 run 均经 `bash scripts/check_sim_status.sh <log>` 检查。 | Assertion-enabled compile 证明新增 `mmu_l2tlb_mb_sva` include/bind 可 elaboration；cover trigger：tag/refill 和 bank-conflict run 命中 `credit_sva.c_dtlb_alloc_issue=200`、`mmu_l2tlb_mb_sva.c_mb_dtlb_alloc=200`；PFU fault run 命中 `mmu_arb_sva.c_prefetch_mask_release=32`、`mmu_l2tlb_rrpv_sva.c_ptw_fault_completion=32`、`mmu_l2tlb_mb_sva.c_mb_dtlb_alloc=32`。 | `make comp_fast` pass；四条 smoke `UVM_ERROR=0`、`UVM_FATAL=0`，`check_sim_status.sh` 均 PASS；未观察到新增 SVA 未解释失败。`git diff --check` pass。 | Scope waiver/future：`L2TLB_SVA_002` full reset-inv boundary、`L2TLB_SVA_015` full TLBOP lifecycle、`L2TLB_SVA_017` control hazard negative 转 6E；`L2TLB_SVA_022` RRPV wbuf debug no-overflow/no-wrong-grant 转 6F；`L2TLB_SVA_023/024` exact replacement/RRPV 保持 future；`L2TLB_SVA_013` type-exact/bad-ID negative 保持 follow-up。 | Phase6D 稳定 SVA/bind 实现完成并有 assertion-enabled evidence；本记录不声明所有 SVA cover/TP coverage 全关闭，未命中 cover 和 waiver/future 必须在 6E/6F/6G closure 中继续跟踪。 |

### 严格退出准则摘要

| Phase | 严格退出准则摘要 |
| --- | --- |
| 6A | 已完成金标准回查；ReqQ/arbiter/L2 final/MB/PTW/TLBOP/PFU/reset/RRPV 观察源实现、复用、waive 或 future；每个新增 probe 有 consumer；compile 通过；关键发现和完成证据写入本文件。 |
| 6B | `L2TLB_TP_001..058` 均有 scenario ID、wrapper class、checker owner、trigger/pass-fail evidence 要求；已判断 testcase 是否足够覆盖测试点和功能；不足项写入关键发现。 |
| 6C | L2 entry shadow、ownership tracking、PFU classifier、payload-ignore、epoch、mismatch taxonomy 已实现或 waiver；能触发但不能判错的场景不得关闭；运行证据写入完成记录。 |
| 6D | must SVA 全部 implemented+evidence 或 approved waiver；partial-existing 不关闭 ID；assertion-enabled compile/run、fail triage 和 waiver/future 写入本文件。 |
| 6E | 每个 testcase 有 scenario ID、related TP/SVA、trigger gate、checker/SVA gate 和 positive/negative 分类；positive 缺 trigger 必须 fail 或 waiver；negative 与 normal regression 分离。 |
| 6F | RRPV/replacement v1/debug/future 分类完成；exact victim/RRPV/latest-wins future 风险和前置条件明确；v1 functional-visible 和 no-overflow/no-wrong-grant 不被削弱。 |
| 6G | P0/P1 TP 和 must SVA 每项都有 implemented+evidence、approved waiver、future 或 blocked reason；manifest、run list、closure report、coverage/log path 和 remaining holes 写入本文件。 |

## 下一步

按 `L2TLB_UVM_Phase6_BuildPlan.md` 的 6A~6G 执行 UVM 修改补充。每个 phase 开始前先更新本文件 Phase 进度矩阵，实施过程中持续写入关键发现，完成后填写 UVM Phase 完成记录。Makefile/run-list/script 可按 phase 修改；DUT/RTL 修改需单独征得同意。

## 退出检查表

| 检查项 | 状态 |
| --- | --- |
| Phase 0 已完成 | 是 |
| Phase 1 已完成 | 是 |
| Phase 2 测试点总结 | 已完成 |
| Phase 2 Excel 测试点表 | 已完成 |
| Phase 3 SVA 补充 | 已完成 |
| Phase 4 scoreboard/reference model 补充 | 已完成 |
| Phase 5 主计划同步 | 已完成 |
| Phase 6 专用 BuildPlan/Progress 文档创建 | 已完成 |
| Phase 7 后续实施阶段退出准则细化 | 已完成 |
| Phase 6 BuildPlan/Progress 文档中文化 | 已完成 |
| UVM 修改补充进度章节已新增 | 已完成 |
| 6A~6G phase 进度矩阵已新增 | 已完成 |
| UVM 修改关键发现日志模板已新增 | 已完成 |
| UVM Phase 完成记录模板已新增 | 已完成 |
| 每个 phase 严格退出准则摘要已新增 | 已完成 |
| Makefile/run-flow 可按 phase 修改 | 已确认 |
| DUT/RTL 修改需单独同意 | 已确认 |
