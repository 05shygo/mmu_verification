# L2TLB UVM Phase 6 分阶段实施计划

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：指导 L2TLB UVM 在 probe、monitor、scoreboard、SVA、test、coverage、regression、Makefile/run flow 上分阶段修改补充
> 金标准：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 主进度：`doc/l2tlb_uvm_audit/progress.md`
> 详细 tracker：`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`
> 日期：2026-05-23

## 1. 目的、金标准与实施边界

本文档是 L2TLB UVM 分阶段修改补充的实施计划，不再作为文档补充计划使用。实施者应按 6A~6G 分阶段补齐 UVM 可观测性、scoreboard/reference model、SVA/bind、directed/negative test、coverage/regression 和 closure 证据。

`doc/l2tlb_uvm_audit/l2tlb_function_description.md` 是本计划的金标准。每个 phase 在实施前、实施中和退出前都必须回查该文件中相关的 `L2TLB_TP_xxx`、`L2TLB_SVA_xxx`、功能描述和 scoreboard/reference model 规则。如果 BuildPlan 未描述到金标准要求的内容，实施者必须补充 UVM、testcase、checker、SVA、coverage 或 waiver/future 记录，而不是只完成本文原有表格。

所有实施行为以更高质量验证 DUT 为准则，不以完成表面目标为准则。wrapper 名称、历史 regression pass、generic smoke、总 coverage 分数或 `UVM_ERROR=0` 都不能替代真实 trigger evidence 和 pass/fail evidence。

允许按本计划修改 UVM/testbench、Makefile、仿真列表、regression list、脚本和 coverage/report flow。DUT/RTL 修改不由本文档默认授权；若发现必须修改 DUT/RTL 才能继续，应先在 `progress.md` 记录 `dut-suspect` 或 blocker，列出原因、影响文件和验证风险，并在取得明确同意后再修改。

2026-05-24 P1 ReqQ/arbiter/ownership fine-grain 继续实施边界：已取得同意修改验证逻辑，但仅限 Phase6E/Phase6G directed stimulus、诊断 counter/SVA、run list、manifest/scanner 和证据文档。最终 closure 只允许在真实日志同时证明 `four_req`、`ptw_reqq_conflict`、`tlbop_reqq_conflict`、`ptw_tlbop_conflict`、triple conflict、`ptw_on_reqq_block`、`tlboper_on_pfu_block`、PFU mask release 和 clean checker evidence 后落地。2026-05-24 重新编译后的 `delay_1ns_steps=36581` targeted run 已满足该门槛，因此 manifest 可由 blocked row 转为 `P1_REQQ_ARB_FINE_CLOSURE`；该闭环只涉及验证侧 stimulus/diagnostic/checker 与证据，不授权 DUT/RTL 行为修改。若后续 targeted run 暴露 DUT/RTL 可疑行为，仍必须先记录 `dut-suspect` 并另行征得修改 RTL 的同意。

主要输入：

- Phase 2 测试点：`l2tlb_function_description.md` 中的 `L2TLB_TP_001..058`。
- Phase 3 SVA 需求：`l2tlb_function_description.md` 中的 `L2TLB_SVA_001..024`。
- Phase 4 scoreboard/reference model 需求：`l2tlb_function_description.md` 第 8 章。
- 现有 UVM 入口：`mmu_dut_probes_if.sv`、`mmu_translation_sb.svh`、`mmu_invalidate_sb.svh`、`mmu_l2tlb_rrpv_sva.sv`、`l2tlb_tests/` 和 `test_pkg.sv`。

## 2. 统一进入条件、质量原则与记录纪律

任何 phase 在修改 UVM、testbench、Makefile、脚本或 run list 前，实施负责人必须确认：

| 门禁 | 要求 |
| --- | --- |
| 金标准回查 | 已重读 `l2tlb_function_description.md` 中本 phase 相关测试点、SVA、功能和 scoreboard 规则。 |
| 范围明确 | 当前 phase 明确写出允许写入的文件集合；DUT/RTL 修改必须单独征得同意。 |
| 可追溯性 | 每项修改至少映射到一个 `L2TLB_TP_xxx`、`L2TLB_SVA_xxx` 或 Phase 4 scoreboard 规则。 |
| 基线 | 编辑前记录当前 compile/regression 基线。 |
| 关键发现先记录 | 实施过程中发现文档遗漏、testcase 不足、checker/SVA/coverage 缺口、DUT 可疑行为或 waiver/future 项时，先写入 `progress.md` 的 UVM 修改关键发现日志。 |
| 质量优先 | 不为完成表面计划降低 checker 严格度；不能用 wrapper 名称、run pass 或总 coverage 代替功能正确性证据。 |
| Waiver 路径 | 缺失 probe、不稳定信号、不支持场景、已知 DUT/spec gap 都有 issue、waiver、future 或 blocker 行。 |

每个 phase 完成前必须在 `progress.md` 写入 phase 完成记录，包括修改文件、命令和日志路径、trigger evidence、pass/fail evidence、waiver/future、remaining holes 和 review 结论。没有 `progress.md` 记录的 phase 不得标记为完成。

## 3. UVM 分阶段实施子阶段与严格退出门禁

### Phase 6A：可观测性与 monitor 就绪

目标：保证后续 checker 使用稳定 monitor/probe 输入，而不是临时层级路径。

金标准回查与质量规则：6A 实施前必须对照 `l2tlb_function_description.md` 检查 L2TLB 功能、TP、SVA 和 scoreboard 需要的所有观察源。若本文未列出的信号对高质量验证 DUT 必需，必须补充 probe/monitor/checker 输入或记录 waiver/future；不得为了避免增加观察源而降低 checker 严格度。关键发现、缺口和处理决定必须先写入 `progress.md`。

候选落点：

- `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
- `mmu_verification/testbench/top/tb_top.sv`
- 如果顶层 transaction 比 white-box probe 更合适，可复用已有 agent monitor 和 analysis port。

本阶段实施输出：

- ReqQ、arbiter grant、L2 final response、miss buffer、PTW request/completion、TLBOP state、PFU path、reset/abort epoch、RRPV/wbuf debug 的 probe 清单。
- 对每个缺失或不稳定信号选择一种处理：新增稳定 probe、从已有 transaction monitor 派生、waive、或归类为 future debug only。
- 内部 probe 仅作为 debug/checker 输入，不把 L2TLB 内部信号变成普通 sequence drive interface。

#### Phase 6A probe/monitor 实施基线

本小节记录 2026-05-23 代码检查得到的当前观察面。它只说明实施时 checker 可以从哪里取样，不代表对应 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx` 已关闭。

| 观察区域 | 当前稳定来源 | 主要字段 | 6A 决策 |
| --- | --- | --- | --- |
| L2 final response | `mmu_dut_probes_if.sv`，由 `tb_top.sv` 从 `u_dut.x_mmu_l2tlb` 连接 | `l2_final_vld`、`l2_final_tlb_hit`、`l2_miss`、`l2_final_is_dtlb`、`l2_final_vpn`、`l2_final_hit_ppn`、`l2_final_way_hit` | 可作为 L2 ownership/debug 输入；端到端 pass/fail 仍优先来自 IFU/LSU/PFU transaction monitor。 |
| ReqQ | `mmu_dut_probes_if.sv` + `tb_top.sv` | `l2_reqq_vld_vec`、`l2_reqq_rdy_vec`、`l2_reqq_qid`、`l2_reqq_issue_valid`、`l2_reqq_issue_type` | 可用于 credit/queue health、coverage 和 transaction ownership；per-cycle 仲裁优先级只能由具名 SVA/debug checker 关闭。 |
| Arbiter grant | `mmu_dut_probes_if.sv` + bind SVA | `ptw_arb_req`、`arb_ptw_grant`、`arb_pfu_grant`、`arb_l2tlb_req`、`ptw_arb_pgs`、`ptw_arb_vpn` | 可用于流控诊断；arbiter 协议属性由 `mmu_arb_sva.sv` 等 bind checker 负责，不从 scoreboard 临时推断。 |
| Miss buffer | `mmu_dut_probes_if.sv` + `tb_top.sv` generate 连接 | `l2mb_vld_vec`、`l2mb_rdy_vec`、`l2mb_issue_req/eid/type`、`l2mb_alloc_valid`、entry `vpn/l1eid/type/queue_id/sent` | 可用于 MB full、sent/ready、PTW request ownership 和 deadlock 诊断；不把 exact internal scheduling 当 v1 功能 pass/fail。 |
| PTW request/completion | `mmu_dut_probes_if.sv` + `ptw_source_monitor.svh` | `l2tlb_ptw_req/id/type/vpn`、`ptw_l2tlb_cmplt`、`ptw_l2tlb_ref_data_vld`、`ptw_l2tlb_ref_pgflt`、`ptw_l2tlb_ref_acc_err`、`ptw_l2tlb_id/type/flg` | 可作为 6C PTW ownership 和 fault payload-ignore 输入；completion class 必须由 class-specific bit 区分，不能只用 OR completion 关闭场景。 |
| TLBOP / invalidate | `lsu_monitor`/`cp0_monitor` transaction + `mmu_dut_probes_if.sv` | `tlbiva_cur_st`、`tlboper_ptw_abort`、`tlboper_utlb_clr`、`tlboper_utlb_inv_va_req`、`tlboper_utlb_inv_va` | 功能语义优先来自 invalidate/TLBOP transaction；内部 state 只用于 trigger evidence、abort epoch 和 debug coverage。 |
| PFU path | `lsu_monitor` pipe2 transaction + `mmu_dut_probes_if.sv` | `arb_pfu_grant`、`pfu_l2tlb_deny`、`pfu_l2tlb_acc_fault`、`pfu_l2tlb_flag_fault`、PFU PMP/sysmap flags | PFU final result pass/fail 由 pipe2/PFU transaction 和 scoreboard 归类；probe 用于 fault source 解释。 |
| Reset/abort epoch | top reset/interface reset + `mmu_dut_probes_if.sv` | `rst_ni`、`tlboper_ptw_abort`、`ptw_abort_flop`、`rtu_yy_xx_flush` | 后续 checker 必须显式建 epoch；reset/abort 期间的 stale completion 不可直接计为 DUT functional mismatch。 |
| RRPV / replacement debug | `mmu_dut_probes_if.sv` 和 L2 bind SVA | `l2_bank0`、`l2_raw_pre_pgs0`、`l2_final_way_hit`、`mmu_l2tlb_rrpv_sva.sv` bind ports | v1 只作 debug/coverage；exact victim、exact RRPV、wbuf merge/latest-wins 保持 future exact-model item。 |

#### Phase 6A missing-signal decision table

| 需求项 | 当前判断 | 后续处理 |
| --- | --- | --- |
| 6C L2 transaction ownership 所需 ReqQ/MB/PTW/PFU 基础输入 | 已有稳定 probe 和 transaction monitor 可组合使用 | 允许进入 6C 设计，但 6C 必须逐场景证明 trigger evidence 和 pass/fail evidence，不能只引用 probe 存在。 |
| L2 entry shadow 的写入/失效可见源 | 目前有 PTW completion、TLBOP/invalidate transaction、L2 final/debug probe；exact array state 未作为 v1 输入 | 6C 建 transaction-level shadow；若需要直接读 tag/data/RRPV array，必须回到 6A 新增 probe 或列为 future/waiver。 |
| L2 final result payload | `l2_final_*` 有 debug 输入，但最终 IFU/LSU/PFU 响应由 agent monitor 采集 | Scoreboard 不应用内部 final probe 替代外部可见结果；内部 final 只用于 root-cause 和 ownership。 |
| PTW fault/no-pavld payload | 有 `ptw_l2tlb_ref_pgflt/acc_err/data_vld` 和 type/id/flg | 6C 对 fault/no-pavld 场景执行 payload-ignore 规则；缺少 page payload 时不能误报 PPN/flag mismatch。 |
| TLBOP reset/abort epoch | 有 `tlboper_ptw_abort`、`ptw_abort_flop`、`rtu_yy_xx_flush` | 6C/6D checker 必须用 epoch gating；未建 epoch 前不得关闭 reset/abort 相关 TP/SVA。 |
| exact replacement victim/RRPV/wbuf | 当前观察面不足以安全做 exact model signoff | 归类为 Phase 6F debug/future；不得作为 v1 pass/fail blocker，也不得静默标为 covered。 |
| 未批准 `$root` checker path | 2026-05-23 检查未在 testbench checker 中发现 `$root` fragile path | 后续新增 checker 只能通过 virtual interface、analysis transaction 或 bind target 取样；例外必须写入 waiver。 |

#### Phase 6A probe consumer list

| Consumer | 消费方式 | 6A 约束 |
| --- | --- | --- |
| `mmu_credit_sb.svh` | 通过 `MMU_DUT_PROBES_VIF` 消费 ReqQ、MB、PTW、PFU、arbiter、L2 final 快照 | 可用于 credit/deadlock/flow diagnostic；新增字段必须有具体 error、coverage 或 evidence 消费点。 |
| `mmu_env_cg_whitebox.svh` | 通过 virtual `mmu_dut_probes_if` 采样 L2/ReqQ/PTW/TLBOP/PFU bins | coverage hit 只能证明观察到 trigger，不能单独证明功能正确。 |
| `ptw_source_monitor.svh` | 通过 `mon_cb` 采集 L2TLB->PTW accept、PTW completion、fault class 和 path metadata | completion 必须按 refill/page-fault/access-fault 分类；OR-only completion 只能作为诊断。 |
| `lsu_monitor.svh` | 通过 probe 补充 CP0/L1D/PFU metadata，并用 agent transaction 输出最终 LSU/PFU 响应 | functional compare 以 transaction 为主，probe 只补 root-cause/waiver 分类。 |
| `mmu_translation_sb.svh` | 已持有 `v_probe` 并采样 PTW/L2/L1 refill、SATP/abort 等上下文 | 6C 扩展时可复用，但新增 L2 checks 必须分类 mismatch，不能把 probe 缺失归为 pass。 |
| `mmu_l2tlb_rrpv_sva.sv` 和相关 bind SVA | 通过 `bind mmu_l2tlb`/`bind mmu_arb` 等模块端口取样 | 属于 6D SVA owner；bind 端口映射必须在 6D 逐 SVA ID 记录，不算 6A 自动完成。 |

#### Phase 6A 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| 修改范围 | 记录实际修改的 probe、monitor、top wiring、SVA bind、Makefile/run-flow 文件；若无修改，说明金标准回查后无需修改的理由。 |
| Probe/monitor inventory | 记录 ReqQ、arbiter grant、L2 final response、miss buffer、PTW request/completion、TLBOP、PFU、reset/abort、RRPV/debug 的最终观察面。 |
| Missing/future decision | 记录 exact victim、exact RRPV、wbuf merge/latest-wins、direct array state 等缺口的处理：实现、waive、future 或 blocker。 |
| Consumer list | 每个新增或确认的 probe 必须有 consumer、audit ID 映射和用途；无 consumer 的 probe 不得作为完成项。 |
| `$root` fragile path | 记录新增 checker/bind 是否使用稳定 sample source；未批准 fragile `$root` path 必须清零或 waiver。 |
| Compile/run 证据 | 记录 compile 命令、日志路径、warning 处置和 `progress.md` 关键发现条目。 |
| 功能覆盖边界 | 6A 只关闭可观测性门禁，不关闭 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx` 功能正确性。 |

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 已列出本阶段可写文件；已记录修改前 compile 基线；已完成金标准回查；每个新增/改动 probe 都有 consumer。 |
| 交付物 | Probe/monitor inventory；missing-signal decision table；probe consumer list；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | `make comp` 或等价 compile 命令通过；日志路径写入 `progress.md`；新增 Makefile/run-flow 改动必须可复现。 |
| Pass/fail | 无 compile error；无 checker 使用未批准 `$root` fragile path；所有新增 probe 在 top/probe 边界内连接；缺失观察源未导致 checker 降级。 |
| Coverage/SVA/log | 本阶段不要求功能 coverage 达标；必须有 compile log、probe 清单审阅证据和金标准遗漏检查结果。 |
| Waiver | 缺失稳定 probe 必须说明替代 checker、风险和 approver；不能直接因信号缺失把相关 TP/SVA 标为完成。 |

### Phase 6B：场景 ID、wrapper 与 metadata 对齐

目标：把现有 `l2tlb_tests/` wrapper 与 audit 测试点 ID 对齐，但不因 wrapper 名称存在就宣称覆盖已完成。

金标准回查与质量规则：6B 实施前必须对照 `l2tlb_function_description.md` 重新检查 `L2TLB_TP_001..058`，并判断现有 testcase 是否足够覆盖 L2TLB 测试点和功能。本文未列出的场景若对 DUT 验证质量必要，必须补入 scenario metadata、wrapper/checker/SVA/coverage 需求或 waiver/future。关键发现和 testcase 充分性结论必须先写入 `progress.md`。

候选落点：

- `mmu_verification/testbench/test/l2tlb_tests/`
- `mmu_verification/testbench/test/tlbop_tests/`
- `mmu_verification/testbench/test/test_pkg.sv`
- 仿真列表、regression list 和 Makefile target 可在本 phase 或 6G 中按门禁修改。

本阶段实施输出：

- `L2TLB_TP_001..058` 到现有 wrapper、新 wrapper、scoreboard/SVA-only item、negative assertion test 或 future item 的映射表。
- metadata 字段：scenario ID、checker owner、expected observable evidence、reviewer。
- 明确说明：已有 wrapper 名称不足以把测试点标为 covered。

#### Phase 6B wrapper 实施基线

本小节记录 2026-05-23 代码检查得到的当前测试入口。它只说明实施时可复用的候选 wrapper，不代表任何 `L2TLB_TP_xxx` 已经有 trigger evidence 或 pass/fail evidence。

| 区域 | 当前入口 | 6B 判断 |
| --- | --- | --- |
| L2TLB directed/random wrapper | `mmu_verification/testbench/test/l2tlb_tests/`，`l2tlb_tests_suite.svh` include 42 个 wrapper | 已覆盖 ReqQ、MB、tag hit、invalidate、bank conflict、RRPV 等命名入口；多数是 Phase 9 generated wrapper，必须逐项确认实际 vseq、checker 和触发计数。 |
| TLBOP/SFENCE wrapper | `mmu_verification/testbench/test/tlbop_tests/`，`tlbop_tests_suite.svh` include 25 个 wrapper | 可作为 TLBP/TLBR/TLBWI/TLBWR/INV* 候选入口；仍需 L2 entry shadow、TLBOP lifecycle checker 和 reset/abort 交叉证据。 |
| Suite include | `mmu_verification/testbench/test/test_pkg.sv` 已 include `l2tlb_tests_suite.svh` 和 `tlbop_tests_suite.svh` | compile 可见性已存在；本阶段不新增 include、不修改 test list。 |
| Phase 9 metadata | wrapper 内常见 `p9_tc_id`、`p9_seq_desc`、`p9_checker`、`p9_reviewer` | 只能作为候选 metadata；若多个 wrapper 共用通用 vseq 或 checker，不能用 `TC-*` 或 wrapper 名称关闭 audit ID。 |

#### Phase 6B 必须补齐的实现缺口

结论：现有 test case 不足以完成 `L2TLB_TP_001..058` 的覆盖关闭。当前 `l2tlb_tests/` 和 `tlbop_tests/` 只能提供部分候选入口，不能证明所有 P0/P1 测试点已经触发、被独立 checker/SVA 检查并形成 pass/fail evidence。

主要原因：

- 多数 L2TLB wrapper 是 Phase 9 generated wrapper，常复用 `mmu_l2tlb_bank_conflict_vseq`、`mmu_ptw_thrash_vseq`、`mmu_rrpv_aging_vseq` 或通用 TLBOP/SFENCE sequence；wrapper 名称和 `p9_tc_id` 不等价于目标 TP 已触发。
- 现有 checker 多为 `credit_sb` 或 `invalidation_sb` 粗粒度检查，缺少 L2 entry shadow、ReqQ/MB/PTW ownership、PFU result classifier、TLBOP lifecycle、timeout/fairness 和 negative assertion 专项 evidence。
- PFU、PTW fault/acc_err、PTW disabled、out-of-order completion、reset/abort/control hazard 等关键 P0/P1 场景缺少 directed wrapper 或缺少可证明 trigger 的场景门禁。
- RRPV/replacement 相关 wrapper 只能作为 debug/future 辅助；exact victim、exact RRPV、wbuf latest-wins 不属于 v1 coverage closure。

必须补充的内容如下。后续阶段只有补齐对应 trigger evidence 和 pass/fail evidence 后，才能把相关 TP 从 `candidate` 或 `missing` 推进到 `Complete`。

| 补充类型 | 必补内容 | 相关测试点 |
| --- | --- | --- |
| 新增 directed wrapper | cold/warm reset；PTW disabled miss；PTW ready backpressure；PTW page fault/access error；PFU MMU-off/direct、MMU-on L2-hit、PFU miss+PTW、PFU flag fault、PMP/sysmap deny、PFU prefetch_mask、PFU attribute truth table；TLBOP reset；PTW out-of-order completion | `L2TLB_TP_001..002`, `018`, `023`, `025..026`, `028..032`, `043`, `053`, `056..057` |
| 新增 negative suite | bad PTW completion ID/result combo/no-outstanding completion；illegal input/type/page-size/credit overflow；SATP/ASID/MMU/PTW/control 改写 hazard | `L2TLB_TP_027`, `048`, `058` |
| 新增或加强 checker/SVA | arbiter payload no-cross；PFU error payload-ignore；timeout/fairness classifier；coverage closure manifest；PTW/MB ownership and ID scoreboard；TLBOP lifecycle ordering；reset/abort epoch；ReqQ credit/type/lifetime；MB partition full | `L2TLB_TP_003`, `011`, `017..024`, `033`, `034..044`, `049..050`, `055..056` |
| 加强现有 wrapper trigger | ITLB vs DTLB load/store split；4K/2M/1G offset bins；ASID/global bins；MB full retry and partition split；PTW/TLBOP arbitration stall/release；INV* global/non-global and all-set scan | `L2TLB_TP_004..010`, `012..015`, `017`, `019..022`, `034..042`, `051..055` |
| Debug/future 分类 | multi-hit legal-result classifier；RRPV init/wbuf debug cover；replacement exact victim/RRPV exact model future | `L2TLB_TP_016`, `045..047` |

Phase6B 因此只完成 ID、wrapper、metadata 和缺口对齐；不声明现有 test case 足够，不关闭功能 coverage。

#### Phase 6B metadata contract

后续新增或复用 wrapper/checker 时，必须记录以下 metadata。缺任一关键字段时，该测试点只能保持 `Mapped-doc`、`Planned`、`Waived` 或 `Future`，不能标记为 `Complete`。

| 字段 | 要求 |
| --- | --- |
| `scenario_id` | 稳定场景名，推荐格式 `L2TLB_SCN_<topic>_<nnn>`，一条 wrapper 可映射多个 audit ID，但必须分别记录 evidence。 |
| `audit_tp_ids` | 精确列出 `L2TLB_TP_xxx`，不能只写范围或自然语言。 |
| `priority` | 从 Phase 2 继承 P0/P1/P2；P0/P1 缺 evidence 必须有 owner 和后续动作。 |
| `wrapper_class` | 固定取值：`existing_candidate`、`new_wrapper_required`、`checker_sva_only`、`negative_assertion_only`、`debug_only`、`future_exact_model`。 |
| `stimulus_owner` | wrapper/vseq 或外部 backpressure/negative injection owner。 |
| `checker_owner` | scoreboard、SVA、coverage 或 waiver owner；不能只写 wrapper 名称。 |
| `expected_trigger_evidence` | 必须能证明目标场景真实发生，例如 source/result bin、probe counter、SVA cover、scenario gate 或 log token。 |
| `expected_pass_fail_evidence` | 必须能证明 DUT 行为被检查，例如 scoreboard compare、assertion pass/fail、mismatch taxonomy 或 waiver。 |
| `reviewer` | 负责确认 wrapper 名称、触发证据和 checker 证据一致的人或角色。 |
| `status` | `Mapped-doc`、`Existing-wrapper candidate`、`Needs new wrapper`、`Checker/SVA-only`、`Negative-only`、`Debug/Future`、`Complete`、`Waived`。 |

关闭 `L2TLB_TP_xxx` 的最低门槛：

- trigger evidence 和 pass/fail evidence 必须同时存在。
- `UVM_ERROR=0` 只能作为 run health，不能替代场景触发证据。
- `coverage hit` 只能证明观察到触发，不能单独证明功能正确。
- negative assertion-only 场景不得混入普通合法随机回归。
- exact replacement victim、exact RRPV、RRPV wbuf latest-wins 保持 future/debug，除非启动独立 exact reference model 阶段。

#### Phase 6B 初始测试点映射

| 测试点 ID | 优先级 | 分类 | 6B 状态 | 候选 wrapper / checker | Trigger evidence 要求 | Pass/fail evidence 要求 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `L2TLB_TP_001` | P0 | reset | Needs new wrapper | 新增 cold reset directed；`L2TLB_SVA_001/002` | reset 后首笔 ITLB/DTLB/PFU 请求；ReqQ/MB/PTW/PFU/TLBOP idle sample | reset drain checker；无伪 request/refill/fault | 不因 compile reset 成功关闭。 |
| `L2TLB_TP_002` | P0 | reset | Needs new wrapper | 新增 warm reset x lookup/PTW/TLBOP/PFU directed；`L2TLB_SVA_001` | 活跃 transaction 期间 reset；reset release 后新 transaction | pending clear；stale completion ignored | 必须建 reset epoch。 |
| `L2TLB_TP_003` | P0 | UVM boundary | Checker/SVA-only | wrapper metadata audit；testbench `$root` path audit | wrapper class 与 drive interface 分类 | audit report 证明普通测试不直接驱动内部 L2TLB 端口 | metadata audit 项，不靠单个仿真关闭。 |
| `L2TLB_TP_004` | P0 | ReqQ | Existing-wrapper candidate | `test_mmu_dir_l2tlb_reqq_arbitration_itlb_prior`、`test_mmu_rand_l2tlb_reqq_queue_depth_varied`；credit shadow | ITLB source alloc/issue/dealloc | `i_credit_return` 与 entry0 lifecycle compare | wrapper 名称只能作候选。 |
| `L2TLB_TP_005` | P0 | ReqQ | Existing-wrapper candidate | `test_mmu_dir_l2tlb_reqq_dtlb_alloc_0`、`test_mmu_dir_l2tlb_reqq_dtlb_alloc_full`；credit/type shadow | DTLB load/store source；entry1..8 occupancy | `d_credit_return`、eid、type compare | load/store bins 必须分开。 |
| `L2TLB_TP_006` | P1 | ReqQ | Existing-wrapper candidate | ReqQ wrappers；payload stability checker | same-cycle request+grant bypass；queued issue | selected payload equals original request | 需要 white-box trigger。 |
| `L2TLB_TP_007` | P0 | ReqQ/MB full | Existing-wrapper candidate | `test_mmu_dir_l2tlb_reqq_credit_full_no_return`；ReqQ lifetime checker | MB full retry；retry count > 0 | 请求不丢失，释放后完成或合法 retry | 不能只看 no-credit-return 名称。 |
| `L2TLB_TP_008` | P0 | credit | Existing-wrapper candidate | `test_mmu_dir_l2tlb_reqq_credit_return_hit`、`test_mmu_dir_l2tlb_reqq_credit_return_refill`；credit accounting | hit return、refill return、fault return | credit consume/return counter match | fault return 仍需补证据。 |
| `L2TLB_TP_009` | P0 | arbiter | Existing-wrapper candidate | `test_mmu_rand_l2tlb_bank_conflict_multi_source`；`L2TLB_SVA_005` | pairwise/four-source conflict | grant onehot0；single SRAM pipeline access | 以 SVA/checker 关闭，不以随机覆盖关闭。 |
| `L2TLB_TP_010` | P0 | arbiter | Existing-wrapper candidate | `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior`、`test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior`；priority checker | PTW/TLBOP/ReqQ/PFU conflicts | priority/fairness checker pass 或 waiver | 精确优先级需与 RTL/规格复核。 |
| `L2TLB_TP_011` | P0 | arbiter payload | Needs checker/SVA | 新增 source payload scoreboard；`L2TLB_SVA_005/006` | 每类 source grant payload sample | VPN/type/eid/index/write/bank_sel 不串源 | 现有 wrapper 不足以关闭 payload 串源。 |
| `L2TLB_TP_012` | P0 | tag/data lookup | Existing-wrapper candidate | `test_mmu_dir_l2tlb_tag_match_4k_hit`；L2 entry shadow | ITLB 4KB single hit | PPN/flag 返回正确且不进 PTW | 必须证明 ITLB source。 |
| `L2TLB_TP_013` | P0 | tag/data lookup | Existing-wrapper candidate | `test_mmu_dir_l2tlb_tag_match_4k_hit`；transaction scoreboard | DTLB load/store 4KB single hit | eid/type/PPN/flag compare | 不能由 ITLB-only run 关闭。 |
| `L2TLB_TP_014` | P0 | page size | Existing-wrapper candidate | `test_mmu_dir_l2tlb_tag_match_2m_1g_huge`；PA splice checker | 2MB、1GB、offset variation | page-size mask 与 PA/PPN 拼接 compare | 需要 offset bins。 |
| `L2TLB_TP_015` | P0 | ASID/global | Existing-wrapper candidate | `test_mmu_rand_l2tlb_tag_match_cross_asid`；ASID/global checker | ASID match/mismatch、global/non-global | only expected entry hit | 与 invalidate 交叉但不能互相替代。 |
| `L2TLB_TP_016` | P1 | multi-hit | Debug/checker candidate | `test_mmu_dir_rrpv_multiple_hits_same_vpn`；multi-hit classifier | controlled multi-hit ITLB/DTLB/PFU | external result legal；not normal single-hit | 不作为普通 hit pass。 |
| `L2TLB_TP_017` | P0 | MB alloc/PTW req | Existing-wrapper candidate | `test_mmu_dir_l2tlb_mb_alloc_on_miss`；MB shadow/PTW request checker | ITLB/DTLB/PFU miss+MB alloc | MB valid，PTW request ownership compare | PFU source 常需新增 directed。 |
| `L2TLB_TP_018` | P0 | PTW disabled | Needs new wrapper | 新增 PTW disabled directed；terminal fault checker | `cp0_mmu_ptw_en=0` miss | no PTW request；fault/complete 编码正确 | ITLB/DTLB/PFU 三源需分开。 |
| `L2TLB_TP_019` | P0 | MB issue | Existing-wrapper candidate | `test_mmu_rand_l2tlb_mb_issue_order`；MB-to-PTW payload checker | MB alloc 后 PTW ready/fire | PTW id/type/vpn equals MB shadow | PTW ID 是 SVA 重点。 |
| `L2TLB_TP_020` | P0 | MB full | Existing-wrapper candidate | `test_mmu_dir_l2tlb_mb_full_stall`；no-overflow checker | MB full、release then replay | occupancy 有界，无覆盖 valid entry | 需与 TP055 分区 full 区分。 |
| `L2TLB_TP_021` | P1 | duplicate miss | Existing-wrapper candidate, rename/review | `test_mmu_dir_l2tlb_mb_dup_alloc_prevention`；duplicate lifetime checker | duplicate allocated entries | PTW issue count/ownership legal | 规格不要求 duplicate suppression，wrapper 名称需重审。 |
| `L2TLB_TP_022` | P1 | alloc/dealloc race | Existing-wrapper candidate | `test_mmu_dir_l2tlb_mb_dealloc_on_complete`；accounting checker | same-cycle alloc/dealloc | no double-free/lost-alloc | 需要稳定 sample 源。 |
| `L2TLB_TP_023` | P0 | PTW ready | Needs new wrapper | 新增 PTW ready backpressure directed；`L2TLB_SVA_011` | ready stall/release | request payload stable until fire | 外部 fairness 与 DUT progress 分开。 |
| `L2TLB_TP_024` | P0 | PTW refill | Existing-wrapper candidate | MB/PTW directed 或 PTW consumer tests；PTW transaction scoreboard | data_vld completion for ITLB/DTLB/PFU | refill/write 与 final response owner 对齐 | L2 consumer evidence 不能替代 PTW source closure。 |
| `L2TLB_TP_025` | P0 | PTW page fault | Needs new wrapper/checker | 新增 PTW page-fault L2 directed；fault ownership checker | pgflt completion for ITLB/DTLB/PFU | no valid translation write；fault owner correct | payload-ignore 必须明确。 |
| `L2TLB_TP_026` | P0 | PTW access error | Needs new wrapper/checker | 新增 PTW acc_err L2 directed；access error checker | acc_err completion for ITLB/DTLB/PFU | access/error completion owner correct | payload-ignore 必须明确。 |
| `L2TLB_TP_027` | P1 | PTW negative | Negative-only | 新增 negative PTW completion suite；`L2TLB_SVA_012/013` | bad ID、illegal result combo、no outstanding completion | assertion/error handling expected；普通功能不比较 payload | 不混入合法随机。 |
| `L2TLB_TP_028` | P0 | PFU direct | Needs new wrapper | 新增 PFU MMU-off directed；PFU direct checker | `l1dtlb_xx_mmu_off=1` PFU request | direct PA、sec/share/err from PMP/sysmap | 当前 L2 wrapper 基本缺口。 |
| `L2TLB_TP_029` | P0 | PFU L2 hit | Needs new wrapper | 新增 PFU MMU-on hit directed；PFU hit checker | PFU accepted + L2 hit | permission/PMP/sysmap result compare | 不与 L1 permission checker 混淆。 |
| `L2TLB_TP_030` | P0 | PFU PTW | Needs new wrapper | 新增 PFU miss+PTW directed；PFU PTW path checker | PFU miss + data_vld completion | PFU final response equals PTW result | 不做二次 L2 lookup 假设比较。 |
| `L2TLB_TP_031` | P0 | PFU flag fault | Needs new wrapper | 新增 PFU flag fault directed；error classifier | PFU flag fault | `pa2_vld`/`pa2_err` correct；payload ignored | error payload 不作为 mismatch。 |
| `L2TLB_TP_032` | P0 | PFU PMP/sysmap deny | Needs new wrapper | 新增 PFU PMP/sysmap directed；deny checker | PMP deny、sysmap deny | error classification correct | 与 TP057 truth table 交叉。 |
| `L2TLB_TP_033` | P0 | PFU error payload | Needs scoreboard rule | PFU error classifier；payload-ignore rule | flag/PTW/PMP/sysmap error bins | valid/error/class compare；PA/sec/share ignored | Phase 4 scoreboard rule。 |
| `L2TLB_TP_034` | P0 | TLBP | Existing-wrapper candidate | `test_mmu_tlbp_query_hit`、`test_mmu_tlbp_query_miss`；TLBP scoreboard | valid/invalid/multi-hit/page-size TLBP | `va_hit/sel` expected | L2 entry shadow required。 |
| `L2TLB_TP_035` | P0 | TLBR | Existing-wrapper candidate | `test_mmu_tlbr_read_entry`、`test_mmu_tlbr_all_fields`；raw read checker | TLBR valid/invalid | readback fields vs shadow | invalid raw state policy must be explicit。 |
| `L2TLB_TP_036` | P0 | TLBWI | Existing-wrapper candidate | `test_mmu_tlbwi_write_entry`、`test_mmu_tlbwi_overwrite`；shadow update checker | TLBWI valid/invalid | later lookup/TLBP/TLBR natural result | L1/uTLB clear side effect 单独记录。 |
| `L2TLB_TP_037` | P0 | TLBWR | Existing-wrapper candidate | `test_mmu_tlbwr_random_replace`、`test_mmu_tlbwr_rrpv_policy`；functional result checker | TLBWR under free/max-RRPV pressure | visible lookup/TLBP/TLBR result legal | exact victim 不比较。 |
| `L2TLB_TP_038` | P0 | INVVA_ALL | Existing-wrapper candidate | `test_mmu_dir_l2tlb_inv_va`、sfence VA tests；invalidate shadow | INVVA_ALL with ASID mismatch/global | matching VA invalid，non-matching preserved | 需区分 INVVA_ASID。 |
| `L2TLB_TP_039` | P0 | INVASID | Existing-wrapper candidate | `test_mmu_dir_l2tlb_inv_asid`、sfence ASID tests | INVASID hit/no-hit/global skip | matching ASID non-global clear，global remains | 全 set scan evidence。 |
| `L2TLB_TP_040` | P0 | INVVA_ASID | Existing-wrapper candidate | `test_mmu_dir_l2tlb_inv_va_asid`、sfence VA+ASID tests | target ASID/non-global/global clear | matching invalid，other ASID non-global preserved | global clear rule需被触发。 |
| `L2TLB_TP_041` | P0 | INVALL | Existing-wrapper candidate | `test_mmu_dir_l2tlb_inv_all`、sfence INVALL tests；abort/all-invalid checker | INVALL scan，abort side effect | L2 all-invalid，done after scan | reset/abort 交叉不由 INVALL 单独关闭。 |
| `L2TLB_TP_042` | P0 | TLBOP lifecycle | Existing-wrapper candidate + SVA | all TLBOP wrappers；`L2TLB_SVA_015` | request/grant/cmplt/done per op type | no early/missing/duplicate done | SVA/checker owner 必须明确。 |
| `L2TLB_TP_043` | P0 | TLBOP reset | Needs new wrapper | 新增 reset during TLBP/TLBWI/INVALL directed | reset during scan/write | no stale done；post-reset clean request | reset epoch required。 |
| `L2TLB_TP_044` | P0 | abort/stale completion | Existing-wrapper candidate, needs strengthen | `test_mmu_sfence_during_walk`、`test_mmu_sfence_refill_conflict`；stale completion checker | sent/unsent MB abort；late completion | stale completion ignored or legally reissued | 必须区分 old/new context。 |
| `L2TLB_TP_045` | P1 | RRPV init | Debug-only | `test_mmu_dir_rrpv_init_value`、`test_mmu_dir_rrpv_init_max_value_boundary`；RRPV sampler | refill/TLBWI/TLBWR init sample | functional lookup correct；debug coverage hit | exact RRPV 不作 v1 pass/fail。 |
| `L2TLB_TP_046` | P1 | RRPV wbuf | Debug-only | `test_mmu_rand_rrpv_wbuf_no_overflow`、`test_mmu_dir_rrpv_wbuf_latency`；`L2TLB_SVA_022` | wbuf full stall、hit promote pressure | no overflow/no wrong grant | latest-wins 留 future。 |
| `L2TLB_TP_047` | P2 | replacement | Future exact model | `test_mmu_dir_rrpv_victim_selection_*`、`test_mmu_rand_rrpv_victim_all_scenarios` as functional/debug only | replacement pressure bins | visible result legal；no exact victim compare | future replacement 专项。 |
| `L2TLB_TP_048` | P1 | illegal input | Negative-only | 新增 negative suite；`L2TLB_SVA_003/004/018` | bad type、bad pgs、bad ID、credit overflow | assertion/error handling expected | 普通随机保持协议合法。 |
| `L2TLB_TP_049` | P0 | timeout/fairness | Needs scoreboard policy | 新增 timeout classifier | PTW wait、MB retry、TLBOP scan、wbuf stall with release | fairness satisfied -> eventually complete；否则分类报错 | 不用固定永久 backpressure 判断 DUT bug。 |
| `L2TLB_TP_050` | P0 | closure | Checker/SVA-only | Phase 6G closure manifest/scanner | all required source/result bins | coverage/SVA/log 与 waiver 对齐 | Phase 6B 只定义 metadata。 |
| `L2TLB_TP_051` | P0 | ptw_on | Existing-wrapper candidate | `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior`；`L2TLB_SVA_019` | PTW read-to-write with competing sources | ptw_on excludes non-PTW write until release | wrapper 需加强 stall cover。 |
| `L2TLB_TP_052` | P0 | tlboper_on | Existing-wrapper candidate | `test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior`；`L2TLB_SVA_020` | TLBOP scan with competing lookup/PTW/PFU | tlboper_on excludes other grants；done release | 需要 done release evidence。 |
| `L2TLB_TP_053` | P0 | PFU prefetch_mask | Needs new wrapper | 新增 PFU mask directed；`L2TLB_SVA_021` | sustained PFU valid under hit/error/retry | single accept per request；mask release correct | PFU path 当前缺口。 |
| `L2TLB_TP_054` | P1 | index/bank mask | Existing-wrapper candidate | `test_mmu_dir_l2tlb_bank_skew_distribution`；index sampler | selector 00/01/10/11 x 4KB/2MB/1GB | bank mask/index consistency or debug cover | v1 至少 debug cover。 |
| `L2TLB_TP_055` | P0 | MB partition full | Existing-wrapper candidate, needs split | `test_mmu_dir_l2tlb_mb_full_stall`；MB partition checker | ITLB full、DTLB/PFU full、cross-partition non-block | no cross-partition illegal alloc | 比 TP020 更细。 |
| `L2TLB_TP_056` | P0 | PTW out-of-order | Needs new wrapper/checker | 新增 PTW out-of-order completion directed；`L2TLB_SVA_010/013` | out-of-order data/fault/mixed completions | release/ownership by composite ID | 不依赖 issue 顺序。 |
| `L2TLB_TP_057` | P0 | PFU attributes | Needs new wrapper | 新增 PFU truth-table directed；PFU attribute checker | PMP R/L combos、sysmap SO/C、MAEE 0/1 | `pa2_vld/err/sec/share` compare | 细化 TP029/032。 |
| `L2TLB_TP_058` | P1 | control hazard | Negative-only | 新增 control hazard negative suite；`L2TLB_SVA_017` | SATP/ASID/MMU/PTW/control write with outstanding PTW/translation | assertion/error classification expected | 不作为正常功能 coverage。 |

#### Phase 6B 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| 金标准覆盖回查 | 记录 `L2TLB_TP_001..058` 是否全部进入 scenario registry，是否发现 BuildPlan 未描述但金标准要求的场景。 |
| Wrapper inventory | 记录 `l2tlb_tests/`、`tlbop_tests/`、`test_pkg.sv`、suite include、run list 或 Makefile target 的实际修改和候选入口。 |
| Metadata contract | 每个 scenario 记录 wrapper class、trigger evidence、pass/fail evidence、reviewer、status 和 checker owner。 |
| 初始映射 | 58 个测试点均有状态：existing candidate、new wrapper required、checker/SVA-only、negative-only、debug/future、waived 或 blocked。 |
| Testcase 充分性 | 明确说明现有 testcase 是否足够覆盖 L2TLB 测试点和功能；不足项必须列入 `progress.md` 关键发现日志。 |
| 功能覆盖边界 | 6B 只关闭 ID/metadata/wrapper 对齐门禁；TP 完成仍需 6C/6D/6E/6G 的 trigger 和 pass/fail evidence。 |
| 修改范围 | 记录实际修改的 UVM/test/include/run-flow 文件；DUT/RTL 仍需单独同意。 |

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | Phase 2 测试点表和 `.md` ID 清单一致；已完成金标准回查；已定义 wrapper/checker/waiver/future 状态字段。 |
| 交付物 | `L2TLB_TP_001..058` 映射表；新增或复用 wrapper 清单；metadata 记录；testcase 充分性结论；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | 若新增 wrapper、include、run list 或 Makefile target，`test_pkg.sv` 和 suite include 必须 compile 通过；日志路径写入 `progress.md`。 |
| Pass/fail | 每个 P0/P1 测试点都有 wrapper/checker/waiver/future 状态和证据路径；不能只用 wrapper 名称、历史 pass 或 `UVM_ERROR=0` 作为 pass 依据。 |
| Coverage/SVA/log | 本阶段不要求 coverage closure；需要记录每个 ID 的 expected trigger evidence、pass/fail evidence 类型和后续 owner。 |
| Waiver | Waiver 必须精确引用 `L2TLB_TP_xxx`，写明未实现原因、替代证据、质量风险和 approver。 |

### Phase 6C：scoreboard 与 reference model 扩展

目标：实现 Phase 4 定义的 transaction-level L2TLB 模型边界，不建立 cycle-accurate 微架构 scoreboard。

金标准回查与质量规则：6C 实施前必须对照 `l2tlb_function_description.md` 第 8 章和相关 TP 检查 scoreboard/ref-model 需求是否完整。若 testcase 能触发场景但 scoreboard 不能判断 DUT 对错，必须补 checker/ref-model 或记录 blocker；不得用 run pass、credit health 或 debug snapshot 代替功能判错。关键发现、mismatch、UVM/spec/tooling 分类和遗漏项必须先写入 `progress.md`。

候选落点：

- `mmu_verification/testbench/env/mmu_translation_sb.svh`
- `mmu_verification/testbench/env/mmu_invalidate_sb.svh`
- `mmu_verification/testbench/env/mmu_credit_sb.svh`
- `mmu_verification/testbench/env/mmu_ref_model.svh`
- 如果现有 scoreboard 过大，可新增邻近 L2TLB helper class/package。

#### Phase 6C scoreboard/ref-model 实施基线

本小节记录 2026-05-23 对现有 scoreboard/ref-model 的只读检查结论。已有代码提供了可复用基础，但不足以关闭 Phase 4 transaction-level L2TLB scoreboard 边界，也不足以把 Phase6B 的 candidate wrapper 直接升级为 covered。

| 文件 | 当前已有能力 | Phase6C 判断 |
| --- | --- | --- |
| `mmu_translation_sb.svh` | IFU/LSU/PFU 最终响应可调用 `mmu_ref_model.translate()` 比较；已有 PTW request shadow、部分 SATP/abort stale completion 处理、PFU fault/PA compare 和 broad mismatch 计数。 | 可作为最终响应 compare 和 PTW request shadow 的基础；仍缺 L2 entry shadow、TLBWI/TLBWR/PTW refill/INV* 更新规则、完整 ReqQ/MB/PTW/PFU/TLBOP ownership 和统一 mismatch taxonomy。 |
| `mmu_invalidate_sb.svh` | 统计 LSU invalidate、CP0 all-inv done、invalidate kind 和 done count。 | 只能证明事件流被观察；不能证明 L2 entry shadow 被正确 invalidated，也不能关闭 INVVA/INVASID/INVALL/global/non-global 语义。 |
| `mmu_credit_sb.svh` | IFU/LSU/PTW credit conservation、PTW end-drain、L2/PTW/PFU probe snapshot 和 idle health check。 | 可作为 run health、timeout/fairness debug 和 drain evidence；不是 L2TLB functional reference model，不能替代 owner/result compare。 |
| `mmu_ref_model.svh` | 维护 CSR/PMP/SysMap/page-table mirror，提供 Sv39 translate、PFU direct/PMP/SysMap helper。 | 可复用为 page-walk/permission/PFU attribute golden source；`on_tlb_inv()` 仍是 TODO，不具备 L2TLB entry array shadow 和 TLBOP/INV* 语义模型。 |

#### Phase 6C 必须补齐的实现缺口

结论：现有 scoreboard/ref-model 不足以完成 L2TLB 测试点覆盖关闭。现有实现能提供部分 final-response compare、PTW request shadow、credit/drain health 和 debug snapshot，但缺少 Phase 4 要求的 transaction-level L2TLB reference model。因此 Phase6C 必须实现或明确 waiver 下列 scoreboard/ref-model 扩展契约和关闭边界。

必须补齐的内容：

- TLBWI、TLBWR、PTW refill、INV*、reset-inv、abort/reset epoch 的 L2 entry shadow 更新规则。
- 足以归类 L1/PFU 最终响应的 ReqQ/MB/PTW/PFU/TLBOP transaction ownership tracking。
- fault/no-pavld/PFU error 场景的 payload ignore 规则。
- TLB operation 对 shadow state 和 visible result check 的影响。
- mismatch 分类：`RTL bug`、`UVM bug`、`spec gap`、`tooling issue`、`approved waiver`。

#### Phase 6C model contract

实施时推荐新增一个邻近 helper class（例如 `mmu_l2tlb_ref_model` 或 `mmu_l2tlb_txn_shadow`），由现有 scoreboard 调用，避免把全部状态直接堆入 `mmu_translation_sb`。

| 模型项 | 必须建模的最小字段/规则 | 关闭目标 |
| --- | --- | --- |
| L2 entry shadow | `valid`、VPN/ASID/global、page size、PPN、permission/attribute flags、source op、entry epoch；reset/reset-inv 全清；TLBWI index 更新；TLBWR 只比较 visible legal result，不比较 exact victim；PTW data refill 插入；INVVA/INVASID/INVVA_ASID/INVALL 按 VA/ASID/global 规则清除。 | `L2TLB_TP_012..016`, `024`, `034..041`, `045..047` 的 visible result check。 |
| Request ownership | 为 ReqQ/MB/PTW/PFU/TLBOP transaction 维护 owner tuple：source(`ITLB/DTLB_LOAD/DTLB_STORE/PFU/TLBOP`)、VPN、ASID、type/eid、queue/mb/ptw id、page size、epoch。 | `L2TLB_TP_004..011`, `017..027`, `044`, `055..056` 的 no-lost/no-cross/OOO owner check。 |
| PFU path shadow | 区分 MMU-off direct、MMU-on L2 hit、MMU-on miss+PTW 三路径；PFU fault、PMP/SysMap deny、attribute truth table 只比较 valid/error/class/sec/share 等可见字段。 | `L2TLB_TP_028..033`, `053`, `057`。 |
| Payload-ignore rule | 对 page fault、access error、no-pavld、PFU error、illegal negative 输入，只比较 valid/error/fault class/owner；PA、PPN、flag payload 若规格声明无效则不得报 functional mismatch。 | `L2TLB_TP_025..027`, `031..033`, `048`, `058`。 |
| TLBOP lifecycle | TLBP/TLBR/TLBWI/TLBWR/INV* 建立 request/grant/done/visible-result shadow；reset/abort epoch 后旧 done、旧 PTW completion 和旧 refill 必须忽略或报 stale。 | `L2TLB_TP_034..044`, `051..052`。 |
| Timeout/fairness classifier | 对 PTW wait、MB full retry、TLBOP scan、wbuf stall 分类为 environment backpressure、DUT non-progress、debug-only/future 或 waiver；不能用固定永久 backpressure 直接判 DUT bug。 | `L2TLB_TP_049..050`。 |
| Mismatch taxonomy | 每个 `uvm_error` 或 scoreboard mismatch 必须带 `RTL bug`、`UVM bug`、`spec gap`、`tooling issue`、`approved waiver` 之一，并打印 source、VPN、ASID、page size、owner id、expected、observed、epoch。 | 所有 P0/P1 TP 的 pass/fail evidence。 |

#### Phase 6C scenario/checker mapping

| 场景组 | 相关 TP | 需要的 Phase6C checker/ref-model owner | 当前状态 |
| --- | --- | --- | --- |
| Reset / epoch / UVM boundary | `L2TLB_TP_001..003` | reset epoch、stale completion filter、metadata audit result sink | Planned；现有 reset handling 只覆盖部分 PTW/SATP 场景。 |
| ReqQ / arbiter / payload | `L2TLB_TP_004..011`, `051..052` | ReqQ/arbiter owner shadow、payload no-cross compare、ptw_on/tlboper_on exclusion evidence | Planned；`credit_sb` 只能辅助 health/debug。 |
| L2 hit / page size / ASID | `L2TLB_TP_012..016` | L2 entry shadow、PA splice/page-size/ASID/global/multi-hit legal-result classifier | Planned；现有 translate compare 不是 L2 entry shadow。 |
| MB / PTW | `L2TLB_TP_017..027`, `055..056` | MB/PTW ownership、PTW disabled terminal result、ready stability、fault/acc_err/no-outstanding negative classifier、OOO completion composite-ID check | Planned；现有 PTW request shadow 可复用但不完整。 |
| PFU | `L2TLB_TP_028..033`, `053`, `057` | PFU path classifier、PMP/SysMap/flag truth-table compare、PFU payload-ignore rule、prefetch_mask accept/release evidence | Planned；现有 PFU compare 可作为起点。 |
| TLBOP / invalidate / abort | `L2TLB_TP_034..044` | TLBOP lifecycle shadow、L2 entry shadow update/readback、INV* semantic invalidation、reset/abort epoch | Planned；`invalidate_sb` 当前只计数。 |
| Timeout / closure | `L2TLB_TP_049..050` | timeout/fairness classifier、scoreboard evidence manifest input | Planned；最终 closure 仍由 6G 汇总。 |
| RRPV / replacement | `L2TLB_TP_045..047` | debug/future classifier、visible legal-result check only | Debug/Future；不建 exact victim/RRPV v1 模型。 |

v1 transaction pass/fail 明确不包含：

- exact replacement victim way、exact RRPV value、free-way/max-RRPV selection。
- RRPV wbuf latest-wins 或 same-cycle merge 精确行为。
- ReqQ/MB/arbiter/pipeline per-cycle priority，除非由具名 SVA/debug checker 覆盖。
- fault/no-pavld payload 字段和 illegal-protocol functional result。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6A 已提供需要的稳定观察源或 waiver；已完成金标准回查；Phase 4 scoreboard 边界无未决解释项。 |
| 交付物 | L2 entry shadow；PTW/PFU/TLBOP ownership tracking；payload ignore 规则；mismatch taxonomy；scoreboard evidence row；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | compile 通过；directed L2 hit、miss+PTW、PFU 三路径、TLBP/TLBR/TLBWI/TLBWR、INV*、reset/abort、timeout/fairness 至少有 run log 或 waiver。 |
| Pass/fail | 通过场景无未分类 UVM_ERROR/UVM_FATAL；error message 包含 source、VPN、ASID、page size、owner、expected、observed、epoch 和 mismatch category。 |
| Coverage/SVA/log | 需要 pass/fail log；coverage 若未达成可作为后续 6G closure，但不能缺失 scoreboard 场景证据；能触发但不能判错的场景不得关闭。 |
| Waiver | 每个缺口必须分类为 `spec gap`、`tooling issue`、`approved waiver`、`future` 或 `blocked`；不能用 exact RRPV/victim 未建模导致 v1 fail。 |

#### Phase 6C 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Scoreboard inventory | 记录 `mmu_translation_sb`、`mmu_invalidate_sb`、`mmu_credit_sb`、`mmu_ref_model` 及新增 helper 的实际能力和缺口。 |
| 金标准覆盖回查 | 记录 Phase 4 scoreboard/ref-model 要求是否全部覆盖，是否发现 BuildPlan 未描述的判错需求。 |
| Model contract | 记录 L2 entry shadow、ReqQ/MB/PTW/PFU/TLBOP ownership、PFU path、TLBOP lifecycle、timeout/fairness 和 mismatch taxonomy 的实现或 waiver 状态。 |
| TP/checker mapping | 记录 `L2TLB_TP_001..058` 分组到 Phase6C checker/ref-model owner 的实现状态和证据。 |
| 运行证据 | 记录 directed L2 hit、miss+PTW、PFU 三路径、TLBOP、INV*、reset/abort、timeout/fairness 的日志或 waiver。 |
| 修改范围 | 记录实际修改的 scoreboard/ref-model/helper/test/run-flow 文件；DUT/RTL 仍需单独同意。 |

#### Phase 6C 实施完成记录（2026-05-23）

已新增 `mmu_verification/testbench/env/mmu_l2tlb_txn_shadow.svh`，并通过 `mmu_env_pkg.sv` include、`mmu_env.svh` config_db、`mmu_translation_sb.svh`、`mmu_invalidate_sb.svh` 和 `lsu_monitor.svh` 接入现有 UVM 环境。v1 helper 覆盖 PTW request/completion/refill shadow、L2 final 可见结果比较、INV*/CP0 all-inv shadow update、reset/abort/control epoch、PFU classifier、fault/no-pavld/PFU error payload-ignore 和统一 mismatch taxonomy。

本次实施证据：

| 证据项 | 结果 |
| --- | --- |
| Compile | `git diff --check` pass；`cd mmu_verification && make comp_fast` pass，日志：`mmu_verification/output/logs/comp_fast.log`。 |
| Tag/refill smoke | `make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000` pass，日志：`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；summary：`ptw_req=200 ptw_data=200 l2_miss=200 inv=1 cp0_all_inv=3 mismatch=0 waived_future=0`。 |
| PFU payload-ignore smoke | `make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000` pass，日志：`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；summary：`ptw_req=32 ptw_fault=32 pfu=32 payload_ignore=64 mismatch=0 waived_future=0`。 |
| INVALL smoke | `make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000` pass，日志：`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log`；summary：`inv=8 cp0_all_inv=9 reset_epochs=1 abort_epochs=8 control_epochs=9 mismatch=0 waived_future=0`。 |
| Log status | 三条 directed smoke 均经 `bash scripts/check_sim_status.sh <log>` 检查，`UVM_ERROR=0`、`UVM_FATAL=0`；未出现 `PHASE6C_L2_MISMATCH`、`PHASE6C_L2_WAIVER`、`PHASE6C_L2_SHADOW_FUTURE_REPLACEMENT` 或默认 `PTW_CHAIN_DBG` 输出。 |

本次 6C 完成范围不等价于完整 TP closure。以下项继续由后续 6D/6E/6F/6G 关闭或 waiver：TLBP/TLBR/TLBWI/TLBWR exact transaction decode/readback、ReqQ/arbiter payload no-cross、完整 MB/OOO/ready policy、timeout/fairness、RRPV exact victim/value/wbuf latest-wins/merge。`test_mmu_dir_l2tlb_inv_all` seed 63002 的长跑问题已修正：wrapper 收敛为短 INVALL directed run，`PTW_CHAIN_DBG` 改为 opt-in，复跑自然结束并纳入 INVALL smoke evidence。

### Phase 6D：SVA、bind 与 waiver 实现

目标：用稳定 bind 和 reset 语义实现或 waive Phase 3 SVA 需求。

金标准回查与质量规则：6D 实施前必须对照 `l2tlb_function_description.md` 中 `L2TLB_SVA_001..024` 和相关协议描述，检查是否存在本文未拆出的关键 assertion/cover 需求。must SVA 不能由 partial-existing、debug cover、compile pass 或 wrapper pass 关闭；waiver 必须证明不会降低关键 DUT 行为验证质量。SVA 缺口、fail triage 和 waiver/future 必须先写入 `progress.md`。

候选落点：

- `mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`
- `mmu_verification/testbench/top/mmu_arb_sva.sv`
- `mmu_verification/testbench/top/credit_sva.sv`
- 如拆分更清晰，可新增 L2TLB SVA 文件。
- `mmu_verification/testbench/top/tb_top.sv`
- `mmu_verification/testbench/Files.f`
- 如果 assertion module 需要排除在 functional coverage score 外，可调整 coverage exclusion config。

#### Phase 6D SVA/bind 实施基线

本小节记录 2026-05-23 对现有 SVA 文件、compile list 和 bind 状态的只读检查结论。现有 bind 已提供少量 L2TLB 相关 assertion 基础，但不足以关闭 Phase 3 的 `L2TLB_SVA_001..024` 需求。

| 文件 / bind | 当前已有能力 | Phase6D 判断 |
| --- | --- | --- |
| `mmu_l2tlb_rrpv_sva.sv` bind `mmu_l2tlb` | write bus known；PTW read/write raw-stage sanity；ReqQ multi-hit release；PTW disabled miss release。 | 覆盖 `L2TLB_SVA_014` 的一部分和 `L2TLB_SVA_018` 的一部分；不是完整 RRPV SVA，也不覆盖 reset/ReqQ/MB/PTW/TLBOP/control hazard must set。 |
| `mmu_arb_sva.sv` bind `mmu_arb` | five-source grant onehot/onehot when request；PTW write pipeline reset clear。 | 覆盖 `L2TLB_SVA_005` 的 grant onehot 子项和 `L2TLB_SVA_001` 的局部 reset 子项；仍缺 block isolation、payload no-cross、priority cover、ptw_on/tlboper_on/prefetch_mask debug checks。 |
| `credit_sva.sv` bind `mmu_l2tlb_reqq` | ReqQ issue payload known；credit return bits known。 | 只能作为 `L2TLB_SVA_018` 局部 no-X 和 ReqQ debug；不等价于 `L2TLB_SVA_004/007/008` 的 credit/partition/lifetime 检查。 |
| `tb_top.sv` | 已存在 `bind mmu_arb mmu_arb_sva`、`bind mmu_l2tlb mmu_l2tlb_rrpv_sva`、`bind mmu_l2tlb_reqq credit_sva`。 | L2TLB 相关 bind 编译入口存在；新增 bind 仍需避免脆弱 `$root` path，优先使用模块端口、bind scope 内部信号或 `mmu_dut_probes_if`。 |
| `Files.f` | 已 include `mmu_arb_sva.sv`、`mmu_l2tlb_rrpv_sva.sv`、`credit_sva.sv`。 | assertion file compile list 已有基础；新增 SVA 文件必须同步进入 `Files.f` 并跑 assertion-enabled compile。 |

#### Phase 6D SVA sufficiency conclusion

结论：现有 SVA/bind 不足以完成 Phase 3 `L2TLB_SVA_001..024`。当前实现只覆盖少量局部 property；`must` SVA 大多仍是 missing 或 partial，`debug` SVA 多数未实现，`future` SVA 按 Phase 3 定义继续 deferred。实施时不能因为 `tb_top.sv` 已有 bind 或 `Files.f` 已 include SVA 文件，就把 Phase6D 标为关闭。

本阶段实施输出：

- `must`：`L2TLB_SVA_001..005`、`L2TLB_SVA_007..018` 必须实现或 waive。
- `debug`：`L2TLB_SVA_006`、`L2TLB_SVA_019..022` 在 probe 稳定时应作为 assertion/cover/debug checker 实现。
- `future`：`L2TLB_SVA_023..024` 保持 replacement/RRPV exact future item，除非单独批准 exact model 阶段。
- 每条 assertion 记录 trigger、forbidden behavior、reset disable rule、binding target、sampled signals 和 cover property requirement。

#### Phase 6D SVA implementation/waiver plan

| SVA ID | 分类 | 当前状态 | 候选 bind / sample source | Phase6D 后续动作 |
| --- | --- | --- | --- | --- |
| `L2TLB_SVA_001` | must | Partial-existing | `mmu_arb_sva` PTW write pipe reset；新增 `ct_mmu_top`/`mmu_l2tlb` reset checker | 补 ReqQ/MB/PTW/PFU/TLBOP/pipeline active clear；reset assert 检查不得被 `disable iff` 屏蔽。 |
| `L2TLB_SVA_002` | must | Missing | `ct_mmu_top` 或 probe checker | 补 reset-inv 完成边界；完成前普通 IFU/LSU/PFU request 进入可检查窗口应报协议违规。 |
| `L2TLB_SVA_003` | must | Missing | `mmu_l2tlb` 或 `mmu_l2tlb_reqq` | 补 `i_req_valid/d_req_valid` 1-cycle pulse assertion 和 cover。 |
| `L2TLB_SVA_004` | must | Partial-existing | `credit_sva` + `mmu_l2tlb_reqq` internal state | 当前只检查 credit return bit known；需补 no-credit request、counter overflow/underflow、同拍 request+return 规则。 |
| `L2TLB_SVA_005` | must | Partial-existing | `mmu_arb_sva` | 当前只检查 grant onehot；需补 blocked source no-grant、payload no-cross、pairwise/four-source cover。 |
| `L2TLB_SVA_006` | debug | Missing / spec-review | `mmu_arb_sva` | 只在优先级规格确认且 block 条件稳定后实现 priority cover/assert；若 RTL 优先级与 Phase 3 不一致，先更新 waiver/规则。 |
| `L2TLB_SVA_007` | must | Missing | `mmu_l2tlb_reqq` | 补 ITLB entry0、DTLB entry1..8 source partition、issue type/eid no-cross。 |
| `L2TLB_SVA_008` | must | Missing | `mmu_l2tlb_reqq` | 补 full no-overwrite、feedback ID outstanding 命中、miss retry 生命周期保持。 |
| `L2TLB_SVA_009` | must | Missing | `mmu_l2tlb_mb` | 新增 MB SVA bind；补 ITLB/DTLB/PFU partition full、alloc onehot、no-overflow。 |
| `L2TLB_SVA_010` | must | Missing | `mmu_l2tlb_mb` | 补 alloc/dealloc same-cycle、payload accounting、VPN/type/eid/queue id lifetime。 |
| `L2TLB_SVA_011` | must | Missing | `mmu_l2tlb` 或 `mmu_l2tlb_mb` | 补 PTW request ready backpressure payload stability 和 ready/fire one-beat consumption。 |
| `L2TLB_SVA_012` | must | Missing | `mmu_l2tlb` PTW completion interface | 补 data_vld/pgflt/acc_err legal onehot/zero-when-no-completion assertion。 |
| `L2TLB_SVA_013` | must | Missing | `mmu_l2tlb` + `mmu_l2tlb_mb` composite sample 或 probe checker | 补 completion ID/type 匹配 outstanding MB；bad ID/no outstanding 只进 negative assertion test。 |
| `L2TLB_SVA_014` | must | Partial-existing | `mmu_l2tlb_rrpv_sva` | 当前覆盖 multi-hit/PTW-disabled miss release 子项；需补 trigger cover、terminal fault classification 和 MB-full 不错误 retry证据。 |
| `L2TLB_SVA_015` | must | Missing | `ct_mmu_tlboper`、`mmu_l2tlb` 或 probe checker | 补 TLBP/TLBR/TLBWI/TLBWR/INV* request/grant/cmplt/done 一一对应；reset during TLBOP 需 epoch。 |
| `L2TLB_SVA_016` | must | Missing | `mmu_l2tlb_mb` + PTW/L2TLB interface 或 probe checker | 补 abort 后 stale completion 隔离，sent/unsent MB 和 late completion cover。 |
| `L2TLB_SVA_017` | must | Missing / negative-only | `ct_mmu_top`/CP0 monitor + outstanding probe checker | 补 SATP/ASID/MMU/PTW/control 改写前 drain/flush/abort assertion；负向测试只看 assertion/error handling。 |
| `L2TLB_SVA_018` | must | Partial-existing | `mmu_l2tlb_rrpv_sva`、`credit_sva`、新增 interface no-X checker | 当前只覆盖 write bus/ReqQ issue/credit bit 局部 no-X；需补 request、arb、PTW completion、TLBOP、PFU/L1 response valid beat no-X。 |
| `L2TLB_SVA_019` | debug | Missing | `mmu_arb` | 补 `ptw_on` atomic refill block：PTW read-to-write window 只允许对应 PTW write。 |
| `L2TLB_SVA_020` | debug | Missing | `mmu_arb` 或 `ct_mmu_tlboper` | 补 `tlboper_on` block：done 前不得 grant ReqQ/PFU/PTW read，done 后 cover release。 |
| `L2TLB_SVA_021` | debug | Missing | `mmu_l2tlb` 或 `mmu_arb` | 补 PFU `prefetch_mask` 去重、hit/error/retry release cover。 |
| `L2TLB_SVA_022` | debug | Missing | `mmu_l2tlb_rrpv_wbuf` 或 `mmu_l2tlb` | 补 wbuf no-overflow/no-wrong-grant debug assertion；不比较 exact RRPV 值。 |
| `L2TLB_SVA_023` | future | Future | future replacement exact model | v1 不实现；只有批准 exact victim/free-way/max-RRPV model 后升级。 |
| `L2TLB_SVA_024` | future | Future | future RRPV exact model | v1 不实现；只有批准 latest-wins/merge/same-cycle bypass model 后升级。 |

#### Phase 6D bind and waiver rules

- 每条 `must` SVA 的关闭状态只能是 `Implemented + assertion-enabled compile/run evidence` 或 `Approved waiver`；`Partial-existing` 不能关闭 ID。
- `debug` SVA 若不实现，必须保留 debug-deferred 记录；不能被计入 v1 must closure。
- `future` SVA 不进入 v1 pass/fail，但必须在 closure manifest 中保留 `Future` 状态。
- 普通功能回归不得产生负向非法输入；`L2TLB_SVA_013/017/018` 等 negative 场景必须使用独立 negative assertion test。
- 新增 bind 首选模块端口或 bind scope 内部信号；跨模块条件若无法稳定采样，必须使用 `mmu_dut_probes_if` checker 或写明 unavailable-signal waiver。
- assertion fail 必须归类为真 DUT bug、SVA 误报、非法输入负向预期、disable/reset 条件错误、probe/tooling issue 或 approved waiver。

Assertion fail 处理分类：

- 真 bug：DUT 或 UVM 行为违反已确认规格，需要 issue。
- 误报：assertion 触发条件或采样窗口错误，需要修 assertion。
- 非法输入负向预期：仅允许在 negative assertion test 中出现，并需要测试名和预期 fail 证据。
- disable/reset 条件错误：`disable iff`、reset epoch 或 abort epoch 建模不正确，需要修 SVA 或 waiver。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6A 已确认 bind 所需信号；已完成金标准回查；每条 SVA 已分为 must/debug/future；negative test 与普通功能回归分离。 |
| 交付物 | SVA/bind 文件或 waiver rows；SVA ID 到 bind target/sample source 映射；assertion fail 分类规则；cover property 计划；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | assertion enabled compile 通过；must SVA 有 assertion pass log、fail triage 记录或 waiver。 |
| Pass/fail | `must` SVA 全部 implemented 或 approved waiver；partial-existing 不得关闭 ID；普通功能回归中无未解释 assertion failure；negative assertion test 的 fail 必须与预期一致。 |
| Coverage/SVA/log | assertion report 或 log fallback 必须归档；cover property 未达项进入 6G 或 waiver。 |
| Waiver | Waiver 必须说明 unavailable signal、replacement checker、质量风险、approval owner；debug/future 不得被静默计为 v1 pass。 |

#### Phase 6D 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Phase 3 SVA 来源 | 记录 `l2tlb_function_description.md` 中 `L2TLB_SVA_001..024` 的 must/debug/future 分类和金标准回查结论。 |
| SVA/bind inventory | 记录 `mmu_l2tlb_rrpv_sva.sv`、`mmu_arb_sva.sv`、`credit_sva.sv`、`tb_top.sv`、`Files.f` 及新增 SVA 文件的修改和 bind 状态。 |
| SVA ID 分类 | 每条 SVA 记录 implemented、partial、waived、debug-deferred、future 或 blocked；partial-existing 不能关闭 ID。 |
| Assertion 证据 | 记录 assertion-enabled compile/run 日志、fail triage、negative expected fail 和 cover property 缺口。 |
| Waiver/future | 每条 waiver/future 记录 unavailable signal、替代 checker、质量风险、approver 和后续动作。 |
| 修改范围 | 记录实际修改的 SVA/bind/Files.f/Makefile/run-flow 文件；DUT/RTL 仍需单独同意。 |

### Phase 6E：directed 与 negative test 实现

目标：只新增 audit 场景所需测试，不用重复已有 regression 已证明的内容。

金标准回查与质量规则：6E 实施前必须对照 `l2tlb_function_description.md` 检查 testcase 是否覆盖功能组合、边界、错误路径、并发场景和 P0/P1 缺口。本文未列出的必要场景必须新增或加强 wrapper/vseq/negative suite/targeted random constraint。positive test 缺 trigger 必须 fail 或 waiver，negative test 必须隔离。testcase 充分性、缺口和新增用例意图必须先写入 `progress.md`。

候选落点：

- `mmu_verification/testbench/test/l2tlb_tests/`
- `mmu_verification/testbench/test/tlbop_tests/`
- `mmu_verification/testbench/test/flush_tests/`
- `mmu_verification/testbench/test/ptw_tests/`
- `mmu_verification/testbench/test/perf_tests/`
- `mmu_verification/testbench/test/err_tests/`
- `mmu_verification/testbench/test/bug_hunt_tests/`
- `mmu_verification/testbench/test/ptw_lsu_protocol_tests/`
- 优先复用已有 virtual sequence，除非 one-off stimulus 更安全。

#### Phase 6E directed/negative test 实施基线

本小节记录 2026-05-23 对现有 test wrapper、suite include 和可复用 sequence 的只读检查结论。现有入口数量较多，但多数仍是 Phase9/Phase12 粗 wrapper 或通用 stress wrapper；它们只能作为候选入口，不能替代 Phase6B/6C/6D 要求的 trigger evidence、scoreboard/SVA evidence 和 run log。

| 区域 | 当前入口 | Phase6E 判断 |
| --- | --- | --- |
| L2TLB directed/random | `l2tlb_tests/` 下 42 个 `test_*.svh`；`l2tlb_tests_suite.svh` 已 include | 覆盖 ReqQ、MB、tag hit、INV*、bank conflict、RRPV 命名入口；多数复用 `mmu_l2tlb_bank_conflict_vseq` 或 `mmu_rrpv_aging_vseq`，不能单独关闭 P0/P1 TP。 |
| TLBOP/SFENCE | `tlbop_tests/` 下 25 个 `test_*.svh`；`tlbop_tests_suite.svh` 已 include | 可作为 TLBP/TLBR/TLBWI/TLBWR/INV* 候选入口；仍缺 L2 entry shadow、TLBOP lifecycle SVA 和 reset/abort cross evidence。 |
| Reset/flush | `flush_tests/` 下 9 个 `test_*.svh`；`flush_tests_suite.svh` 已 include | 可复用 `mmu_reset_midtransaction_vseq`；仍需 L2TLB-specific cold/warm reset trigger、reset-inv boundary、active lookup/PTW/TLBOP/PFU split evidence。 |
| PTW/PTE/arbiter | `ptw_tests/` 下 74 个 `test_*.svh`；`ptw_tests_suite.svh` 已 include | 有 PTW ready、PTE fault、bus error、MB full、arbiter stress 等候选；仍需 L2TLB owner evidence，且部分 legacy wrapper 标为 obsolete/not source closure。 |
| Perf/stress | `perf_tests/` 下 22 个 `test_*.svh`；`perf_tests_suite.svh` 已 include | 可作为 concurrency/timeout/fairness smoke 候选；不能替代 directed trigger evidence 或 checker pass/fail evidence。 |
| Error/bug/protocol side suites | `err_tests/`、`bug_hunt_tests/`、`ptw_lsu_protocol_tests/` 合计 35 个 `test_*.svh`；均已由 `test_pkg.sv` include | 可提供 negative/error/protocol 候选入口；必须逐项确认是否驱动 L2TLB audit 场景，不能因 suite 已 include 即标记 covered。 |
| 可复用 sequence | `phase9_generated_test_base.svh` 可调度 `mmu_reset_midtransaction_vseq`、`mmu_ptw_thrash_vseq`、`mmu_sfence_during_walk_vseq`、`mmu_rrpv_aging_vseq`、`mmu_l2tlb_bank_conflict_vseq`、`mmu_satp_hotswap_vseq`、`lsu_prefetch_pipe2_seq`、`cp0_ptw_disable_seq`、`ptw_mem_slow_rsp_seq`、`ptw_mem_illegal_pte_seq` 等 | 可作为后续 wrapper 复用基础；需要新增场景门禁和 metadata，不能只复用通用 vseq。 |
| OOO PTW legacy | `ptw_mem_ooo_rsp_seq` 仅 warning，`test_mbuf_ooo_response` 标为 `PTW-014-OBSOLETE-OOO` | 单 outstanding PTE memory protocol 下不支持普通 OOO response；不能用于关闭 `L2TLB_TP_056`，后续若保留 OOO 只能走 negative/future/waiver。 |

#### Phase 6E test sufficiency conclusion

结论：现有 directed/stress/negative-looking test wrapper 不足以完成 L2TLB 测试点覆盖关闭。当前 test pool 足够作为复用基础，但缺少 Phase6E 需要的 per-scenario trigger gate、checker/SVA owner gate、negative test 隔离、targeted run list 和 evidence manifest。

本阶段实施输出：

- reset、ReqQ、L2 hit/miss、MB full/retry、PTW disabled miss、PTW fault/access error、PFU MMU-off/on path、TLBOP variants、invalidate variants、multi-hit、abort、timeout/fairness、selected RRPV debug coverage 的 directed tests。
- 非法协议输入和 control hazard assertion/error handling 仅放入 negative tests。
- 每个测试编码前先定义 trigger evidence 和 checker evidence。

#### Phase 6E directed/negative test plan

| 测试组 | 相关 TP/SVA | 候选复用入口 | Phase6E 必须新增/加强内容 | 关闭条件 |
| --- | --- | --- | --- | --- |
| Reset / reset-inv / warm active reset | `L2TLB_TP_001..002`, `043`; `L2TLB_SVA_001/002` | `flush_tests/*reset*`、`mmu_reset_midtransaction_vseq` | 新增 L2TLB cold reset、warm reset during lookup/PTW/TLBOP/PFU、reset-inv boundary wrapper 或 scenario gate；分开记录 active source。 | reset trigger cover + reset epoch/stale checker/SVA pass。 |
| ReqQ / credit / arbiter payload | `L2TLB_TP_004..011`, `051..052`; `L2TLB_SVA_003..008/019/020` | `l2tlb_tests/*reqq*`、`*bank_conflict*`、`ptw_tests/test_arb_*` | 加强 ITLB entry0、DTLB load/store split、credit fault return、payload no-cross、ptw_on/tlboper_on stall/release trigger。 | ReqQ/arbiter SVA 或 payload scoreboard pass，且 wrapper 自带 trigger gate。 |
| Lookup / page size / ASID / multi-hit | `L2TLB_TP_012..016` | `test_mmu_dir_l2tlb_tag_match_*`、`test_mmu_rand_l2tlb_tag_match_cross_asid`、`test_mmu_dir_rrpv_multiple_hits_same_vpn`、PTW huge page tests | 补 ITLB vs DTLB source split、4K/2M/1G offset bins、ASID/global bins；multi-hit 仅作 legal-result/debug classifier。 | L2 entry shadow/transaction scoreboard pass；multi-hit 不当作 normal hit closure。 |
| MB / PTW normal path | `L2TLB_TP_017`, `019..024`, `055`; `L2TLB_SVA_009..011` | `l2tlb_tests/*mb*`、`ptw_tests/test_mbuf_*`、`test_mmu_ptw_ready_*` | 补 MB alloc/full/issue/dealloc trigger、PTW ready stall/release、same-cycle alloc/dealloc、partition full split、owner ID evidence。 | MB/PTW owner scoreboard + PTW ready SVA pass。 |
| PTW disabled/fault/access error | `L2TLB_TP_018`, `025..026`; `L2TLB_SVA_012/014` | `cp0_ptw_disable_seq`、`ptw_mem_illegal_pte_seq`、`test_bus_error_terminate`、PTE fault wrappers | 新增 L2TLB source-specific PTW disabled miss、page fault、access error directed wrappers；区分 ITLB/DTLB/PFU owner。 | fault class + owner compare pass；payload-ignore rule 生效。 |
| PTW negative / OOO / bad completion | `L2TLB_TP_027`, `056`; `L2TLB_SVA_012/013` | `ptw_mem_ooo_rsp_seq` warning-only；`test_mbuf_ooo_response` obsolete | 新增 isolated negative PTW completion suite 或记录 waiver；不能用 obsolete OOO wrapper 关闭 normal coverage。 | negative assertion expected fail/pass evidence；普通功能不比较未定义 payload。 |
| PFU directed | `L2TLB_TP_028..033`, `053`, `057`; `L2TLB_SVA_021` | `lsu_prefetch_pipe2_seq`、PMP/sysmap/PTE wrappers | 新增 PFU MMU-off direct、MMU-on L2 hit、PFU miss+PTW、flag fault、PMP/sysmap deny、prefetch_mask、attribute truth-table wrappers。 | PFU path classifier + payload-ignore/attribute checker pass。 |
| TLBOP / INV* / abort | `L2TLB_TP_034..044`; `L2TLB_SVA_015/016` | `tlbop_tests/*`、`l2tlb_tests/*inv*`、`test_sfence_abort_walk`、`test_mmu_sfence_*` | 加强 TLBP/TLBR/TLBWI/TLBWR/INV* trigger gates、global/non-global/all-set scan、reset during TLBOP、abort stale completion。 | TLBOP lifecycle SVA + L2 entry shadow compare + stale completion checker pass。 |
| Negative illegal input / control hazard | `L2TLB_TP_048`, `058`; `L2TLB_SVA_003/004/017/018` | `err_tests/`、`bug_hunt_tests/`、`mmu_satp_hotswap_vseq` | 新增 isolated bad type/page-size/bad ID/credit overflow/control-hazard negative wrappers；normal directed/random 必须保持协议合法。 | expected assertion/error handling evidence；不得计入 normal functional coverage。 |
| Timeout / fairness / closure | `L2TLB_TP_049..050` | `perf_tests/*stress*`、`test_ptw_walk_latency`、`test_sfence_high_frequency` | 定义 targeted timeout/fairness run list、environment backpressure release condition、closure manifest input。 | timeout classifier result + evidence manifest row；无 trigger 则 fail 或 waiver。 |
| RRPV / replacement debug | `L2TLB_TP_045..047`; `L2TLB_SVA_022..024` | existing RRPV wrappers | 重分类为 debug/future；只检查 no-overflow/no-wrong-grant/visible result，exact victim/RRPV future。 | debug cover/log；future exact item 不进 v1 pass/fail。 |

#### Phase 6E metadata and run-list rules

- 新增或复用 wrapper 必须写入 `scenario_id`、`audit_tp_ids`、`positive_or_negative`、`trigger_gate`、`checker_gate`、`expected_log_token`、`waiver_policy`。
- Positive directed test 缺少 trigger gate 时必须 fail，不允许 quiet pass。
- Negative test 必须独立命名并从普通功能 run list 分离；预期 assertion/error 必须在 test metadata 中声明。
- 复用 Phase9/Phase12 wrapper 时，必须覆盖原 `p9_tc_id/p12_bucket` 与 `L2TLB_TP_xxx` 的映射差异；obsolete wrapper 默认不能关闭 audit TP。
- Targeted L2TLB run list 至少分为 `l2tlb_smoke`、`l2tlb_directed_p0`、`l2tlb_negative`、`l2tlb_debug_rrpv`、`l2tlb_timeout_fairness` 五类。
- 每次 run 必须把 trigger evidence、checker/SVA evidence、UVM_ERROR/UVM_FATAL summary 和 coverage/log path 写入 Progress evidence log。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6B 已给测试分配 scenario ID；已完成金标准回查；6C/6D 已定义对应 checker 或 assertion；普通功能和 negative test 分组明确。 |
| 交付物 | 新增/复用 test wrapper；scenario ID metadata；trigger evidence 规则；checker evidence 规则；targeted run list；testcase 充分性结论；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | smoke 和 targeted L2TLB directed regression 通过；每个新增测试有日志路径、seed 和触发证据。 |
| Pass/fail | 测试缺少 trigger evidence 时必须 fail，除非明确标记 debug/waiver；无未解释 UVM_ERROR/UVM_FATAL。 |
| Coverage/SVA/log | 每个测试记录触发点、checker 命中或 assertion/scoreboard pass；coverage 缺口进入 6G。 |
| Waiver | 未触发、不可稳定复现或依赖缺失 probe 的场景必须逐 ID waiver，不能因为 generic vseq pass 而标为完成。 |

#### Phase 6E 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Test inventory | 记录 `l2tlb_tests`、`tlbop_tests`、`flush_tests`、`ptw_tests`、`perf_tests`、`err/bug/protocol` suites、可复用 sequence、suite include 和 run list 修改。 |
| 金标准覆盖回查 | 记录 testcase 是否覆盖金标准的功能组合、边界、错误路径和并发场景；不足项写入 `progress.md`。 |
| Directed/negative matrix | 记录 reset、ReqQ、lookup、MB/PTW、PFU、TLBOP、negative、timeout、RRPV 分组的新增/加强内容和关闭条件。 |
| Trigger/checker gate | 每个新增或复用 testcase 记录 scenario ID、related TP/SVA、trigger gate、checker/SVA gate、expected log token 和 positive/negative 分类。 |
| Run 证据 | 记录 smoke、targeted directed、negative、debug RRPV、timeout/fairness 的命令、seed、日志和结果。 |
| 修改范围 | 记录实际新增/修改的 wrapper、vseq、suite include、run list、Makefile target；DUT/RTL 仍需单独同意。 |

### Phase 6F：RRPV 与 replacement 重分类

目标：v1 replacement 检查保持功能/debug 导向，同时保留 future exact-model 入口。

金标准回查与质量规则：6F 实施前必须对照 `l2tlb_function_description.md` 检查 replacement/RRPV 相关功能和风险是否被 v1/debug/future 分类正确覆盖。future exact item 不能成为跳过重要 DUT 风险的借口；若 exact victim/RRPV 仍 future，必须确保 v1 functional-visible checks 和 no-overflow/no-wrong-grant 不被削弱。分类风险和 future 前置条件必须先写入 `progress.md`。

候选落点：

- `l2tlb_tests/` 中已有 RRPV 测试。
- `mmu_l2tlb_rrpv_sva.sv`
- victim、RRPV update 和 wbuf pressure 的 probe/coverage surface。

本阶段实施输出：

- v1 pass/fail 使用功能可观测行为：refill 后可 hit、invalidate 后 entry 被移除、no overflow、no wrong grant。
- debug coverage 记录 hit promote、aging pressure、full stall、victim observed、bank/index bins。
- future exact items 覆盖 victim way、exact RRPV value、free-way/max-RRPV selection、wbuf latest-wins/merge。

#### Phase 6F RRPV/replacement 实施基线

| 区域 | 当前入口 / 观察面 | Phase6F 判断 |
| --- | --- | --- |
| RRPV wrapper | `l2tlb_tests/` 下 `test_mmu_dir_rrpv_*` 和 `test_mmu_rand_rrpv_*` 共 14 个 wrapper，suite 已 include | 多数 wrapper 复用 `mmu_rrpv_aging_vseq` 且 `p9_checker=credit_sb`；只能作为 RRPV pressure/debug 候选，不能证明 exact init/aging/victim/wbuf 行为。 |
| TLBWR/RRPV wrapper | `tlbop_tests/test_mmu_tlbwr_rrpv_policy.svh` | 复用 `cp0_tlbwr_seq + mmu_smoke_vseq` 和 `invalidation_sb`；v1 只能检查 TLBWR 后功能可见结果，不比较 replacement victim。 |
| Perf/bug wrapper | `perf_tests/test_rrpv_aging_replacement.svh`、`bug_hunt_tests/test_bug_007_rrpv_post_inv.svh` | 可作为 pressure 或 post-invalidate debug 候选；没有独立 trigger/checker evidence 时不能关闭 `L2TLB_TP_045..047`。 |
| SVA/bind | `mmu_l2tlb_rrpv_sva.sv` 已 bind 到 `mmu_l2tlb` | 当前只检查 write bus known、PTW read/write staging、multi-hit/PTW-disabled release 等局部项；缺 `L2TLB_SVA_022` wbuf no-overflow/no-wrong-grant，`L2TLB_SVA_023/024` 保持 future。 |
| Probe/coverage | `mmu_dut_probes_if.sv` 暴露 `l2_bank0`、`l2_final_way_hit`、`l2_raw_pre_pgs0`；`mmu_env_cg_whitebox.svh` 有 `cg_l2tlb_bank` | 可覆盖 bank/way/page-size debug bins；没有 wbuf push/pop/full/count、victim_way、exact RRPV value 的稳定 coverage surface。 |
| RTL microarchitecture | `mmu_l2tlb_replacement_policy.sv`、`mmu_l2tlb_rrpv_wbuf.sv`、`mmu_l2tlb.sv` | RTL 中存在 victim、RRPV update、wbuf full/bypass/latest-wins 逻辑；本计划不默认授权 RTL 修改，也不把内部规则直接转成 v1 scoreboard oracle。 |

#### Phase 6F v1/debug/future 分类表

| Item | Audit ID | 分类 | v1 pass/fail 允许检查 | Debug evidence | Future exact-model 条件 |
| --- | --- | --- | --- | --- | --- |
| RRPV init on refill/TLBWI/TLBWR | `L2TLB_TP_045` | Debug with functional fallback | refill/write 后后续 lookup、TLBP/TLBR 或 invalidate 行为可解释；不比较 RRPV=3 exact value | write/init wrapper trigger、bank/way/page-size cover、optional RRPV sampler | 若要检查 exact init value，必须新增稳定 RRPV SRAM/wbuf sampling 和 reference update rule。 |
| Hit promote / miss aging | `L2TLB_TP_045`, `L2TLB_TP_046` | Debug-only | 不因 exact promote-to-zero 或 miss aging value mismatch fail | hit/miss pressure cover、wbuf push/full/stall cover | 需要 cycle-aware RRPV model、valid-entry mask、same-cycle push/bypass 采样点。 |
| Wbuf no overflow | `L2TLB_TP_046`, `L2TLB_SVA_022` | Debug assertion, recommended | wbuf full/stall 下不得 overflow；若采样源稳定，可作为 debug SVA fail | full/empty/push/pop/full-stall bins、no-overflow assertion log | 若缺 wbuf internal source，先回 6A 补 probe 或记录 waiver。 |
| Wbuf full no-wrong-grant | `L2TLB_TP_046`, `L2TLB_SVA_022`, `L2TLB_TP_049` | Debug assertion / timeout support | full active 时不得 grant 会产生新 RRPV update 的 ReqQ/PFU/PTW-read/TLBOP；PTW write 不应被 wbuf full 错误阻塞 | arbiter block cover、eventually drain/release log | 若要检查 exact full watermark/count，必须建 wbuf occupancy reference。 |
| TLBWR/PTW replacement visible result | `L2TLB_TP_037`, `L2TLB_TP_047` | v1 functional | 写入后 translation/TLBP/TLBR/invalidate 结果合法可解释；不预测具体 victim way | replacement pressure bins、victim observed debug log if available | exact victim/free-way/max-RRPV 检查进入 future `L2TLB_SVA_023`。 |
| Exact victim/free-way/max-RRPV | `L2TLB_TP_047`, `L2TLB_SVA_023` | Future exact model | v1 不检查，不作为 blocker | future bins 可记录 pressure observed | 需要 hash/index、entry_vld、mask_way、entry_rrpv、victim_way、PTW/TLBWR timing 的 cycle-accurate model。 |
| Wbuf latest-wins / merge / same-cycle bypass | `L2TLB_TP_045..047`, `L2TLB_SVA_024` | Future exact model | v1 不检查，不作为 blocker | optional trace only | 需要 push/pop/bypass/SRAM read/write 合并规则和同周期采样定义。 |
| Invalid entry stale RRPV after invalidate/reset | `L2TLB_TP_038..041`, `045` | v1 ignore for functional result | invalid entry 的 stale RRPV 不影响 lookup；invalidate 后只检查 valid/tag/data 功能结果 | post-inv RRPV debug wrapper 可记录 | 若未来检查 stale RRPV 清理，需要先修改规格或建立专门 waiver。 |

#### Phase 6F debug coverage plan

实施若打开 `l2tlb_debug_rrpv` run list，至少应记录以下 debug bins。未命中 debug bin 不阻塞 v1 functional closure，但必须进入 Phase6G coverage hole 或 waiver。

| Coverage / assertion | 推荐采样源 | 关闭含义 | 不允许的误用 |
| --- | --- | --- | --- |
| `rrpv_init_refill_seen`、`rrpv_init_tlbwi_seen`、`rrpv_init_tlbwr_seen` | PTW/TLBOP transaction + L2 write/debug sample | 证明 init 类压力出现过 | 不能证明 exact RRPV value 正确。 |
| `rrpv_hit_promote_pressure`、`rrpv_miss_aging_pressure` | `mmu_rrpv_aging_vseq` trigger + L2 final hit/miss sample | 证明 hit/miss aging 压力出现过 | 不能用 `credit_sb pass` 关闭 RRPV aging oracle。 |
| `rrpv_wbuf_full_seen`、`rrpv_wbuf_release_seen` | wbuf full probe/SVA 或 arbiter block log | 证明 wbuf stall/release 场景出现过 | 不能替代 no-overflow/no-wrong-grant assertion。 |
| `rrpv_wbuf_no_overflow` | `L2TLB_SVA_022` 或 wbuf occupancy checker | 证明在采样窗口内无 overflow | 若没有稳定 internal source，不能静默标为 pass。 |
| `rrpv_full_no_wrong_grant` | arbiter grant/block SVA | 证明 full 时未错误接受会产生 RRPV update 的新访问 | 不能错误阻塞 PTW write；PTW write 需要单独 cover。 |
| `replacement_pressure_visible_result` | TLBWR/PTW refill wrapper + L2 entry shadow | 证明 replacement pressure 下功能结果合法 | 不能推断具体 victim way 正确。 |
| `victim_observed_bank_way` | `l2_final_way_hit`、optional victim/debug probe | 只作 bank/way 分布 debug | 不计入 future exact victim closure。 |

#### Phase 6F future exact item list

以下项目必须显式保持 `Future` 或 approved waiver；不能因为 RRPV wrapper 存在、`credit_sb` 通过、或 white-box bank/way cover 命中而标为 covered。

| Future item | 相关 ID | 升级前置条件 | 最低证据要求 |
| --- | --- | --- | --- |
| Exact victim/free-way/max-RRPV model | `L2TLB_TP_047`, `L2TLB_SVA_023` | 独立批准 replacement exact-model 阶段；定义 hash/index、mask_way、entry_vld、entry_rrpv、tie-break、PTW/TLBWR timing。 | cycle-accurate reference model + assertion/scoreboard log + directed victim tests。 |
| Exact RRPV value after hit/miss/refill/write | `L2TLB_TP_045..046` | 稳定 RRPV SRAM/wbuf sampling；定义 valid-entry mask、invalid entry ignore、TLBOP 是否 aging。 | per-event expected/observed RRPV dump + mismatch taxonomy。 |
| Wbuf latest-wins/CAM merge | `L2TLB_TP_046`, `L2TLB_SVA_024` | 暴露或 bind `push_req/push_idx/push_vld/push_data/count/rd_ptr/wr_ptr` 等采样源；定义同 bank/index 多 pending 优先级。 | same-bank/index directed + latest-wins assertion pass。 |
| Same-cycle push bypass | `L2TLB_TP_046`, `L2TLB_SVA_024` | 明确同周期组合采样点和 lookup_req 时序；避免 delta-cycle 误采样。 | same-cycle push+lookup cover + merged value compare。 |
| PTW write / TLBOP write 与 pending wbuf 冲突规则 | `L2TLB_TP_045..047` | 明确 pending RRPV 是否 invalidate、merge 或允许 stale drain；定义功能可见风险。 | directed conflict tests + exact RRPV model evidence。 |

#### Phase 6F run-list and metadata rules

- `l2tlb_debug_rrpv` run list 只允许关闭 debug coverage、`L2TLB_SVA_022` debug assertion 和 functional-visible replacement checks；不得关闭 `L2TLB_SVA_023/024`。
- RRPV wrapper 必须增加或外部记录 `phase6f_class`，取值只能是 `v1_functional_visible`、`debug_coverage`、`debug_assertion`、`future_exact_model`。
- wrapper 名称包含 `victim_selection`、`init_value`、`hit_promote_to_zero`、`aging_saturation` 时，若没有 exact RRPV model，只能按 debug/future 分类；测试通过不能证明名称中的 exact rule。
- `credit_sb`、`invalidation_sb` 或 generic vseq pass 只能作为 health evidence，不能作为 RRPV/replacement closure evidence。
- `L2TLB_TP_047` 在 v1 只能由 visible legal result 关闭；exact victim coverage 保持 future。
- `L2TLB_SVA_022` 若实现，必须独立记录 assertion-enabled compile/run evidence；若不实现，作为 debug missing/waiver 进入 Progress。
- `L2TLB_SVA_023/024` 固定为 future，直到启动独立 exact-model 阶段。

#### Phase 6F 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| RRPV wrapper inventory | 记录 `l2tlb_tests`、`tlbop_tests`、`perf_tests`、`bug_hunt_tests` 中 RRPV/replacement 候选入口、trigger 和 checker 局限。 |
| 金标准覆盖回查 | 记录 replacement/RRPV 相关金标准要求是否被 v1/debug/future 分类覆盖，是否发现 BuildPlan 漏项。 |
| v1/debug/future 分类 | 记录 `L2TLB_TP_045..047`、`L2TLB_SVA_022..024` 的最终分类、风险和完成证据。 |
| Debug coverage plan | 记录 init/hit/miss/wbuf/full/replacement pressure debug bins、no-overflow/no-wrong-grant assertion 或 waiver。 |
| Future exact item | exact victim、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass、PTW/TLBOP pending conflict 必须记录 future 前置条件和风险。 |
| 修改范围 | 记录实际修改的 wrapper、SVA、probe、coverage、run list、Makefile target；DUT/RTL 仍需单独同意。 |

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | Phase 4 replacement 边界已确认；已完成金标准回查；exact victim/RRPV 未作为 v1 pass/fail；debug coverage 采样源来自 6A 或 waiver。 |
| 交付物 | v1/debug/future 分类表；RRPV debug coverage plan；future exact item 清单；相关 TP/SVA 状态更新；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | 相关 RRPV/replacement directed 或 debug runs 有日志；v1 功能可见检查通过或 waiver。 |
| Pass/fail | 不允许测试仅因 exact victim 或 exact RRPV 与未实现模型不一致而 fail；no-overflow/no-wrong-grant 和 visible functional result 仍必须检查或 waiver。 |
| Coverage/SVA/log | Debug coverage 未达不阻塞 v1 closure，但必须记录缺口；future exact coverage 不计入 v1 完成率。 |
| Waiver | Future exact checks 必须显式列为 future 或 waiver，不能静默视为 covered。 |

#### Phase 6F 实施完成记录（2026-05-23）

本轮完成 Phase6F 可实现部分：`L2TLB_SVA_022` 的 wbuf/arbiter debug assertion baseline、RRPV debug run-list、metadata 分类和 targeted run evidence。未修改 DUT/RTL，未建立 exact replacement/RRPV model。

| 检查项 | 完成证据 |
| --- | --- |
| 修改范围 | 新增 `mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv`；强化 `mmu_verification/testbench/top/mmu_arb_sva.sv` 的 wbuf-full no-wrong-grant/PTW-writeback guard；更新 `tb_top.sv` 参数化 bind、`Files.f`、`cov_hier.cfg`、Phase6E base/test metadata 和 `simu/l2tlb_phase6f_debug_rrpv_list`；只改 testbench/SVA/doc/run-list，未改 DUT/RTL。 |
| v1/debug/future 分类 | `test_l2tlb_p6e_rrpv_debug_pressure` 输出 `L2TLB_PHASE6F_META/CLOSE`，`phase6f_class="debug_coverage,debug_assertion,v1_functional_visible,future_exact_model"`，`future_exact_items="exact_victim,exact_rrpv_value,wbuf_latest_wins,wbuf_merge,same_cycle_bypass"`。 |
| Debug assertion | `mmu_l2tlb_rrpv_wbuf_sva` 检查 reset、count/status、push/pop accept accounting、no overflow/no underflow、valid-bank payload known、lookup known；`mmu_arb_sva` 检查 wbuf full 不泄漏新读 grant，且不误阻塞合法 PTW writeback。 |
| Run 证据 | `make comp_fast` pass；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6f_debug_rrpv_list --mode run_check --seeds 65001 --timeout 10000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0` pass；`check_sim_status.sh` pass；日志无 `failed at`、无 `PHASE6C_L2_MISMATCH`，`UVM_ERROR=0`、`UVM_FATAL=0`。 |
| Trigger/coverage evidence | Shadow delta：`ptw_req=48 ptw_data=48 l2_hit=96 l2_miss=48 inv=1 cp0_all_inv=2 abort_epoch=1 control_epoch=2 activity=246`。Cover 命中：`c_rrpv_wbuf_push_new_entry=96`、`c_rrpv_wbuf_pop=96`、`c_rrpv_wbuf_lookup_bypass_hit=48`。 |
| Cover hole / 6G follow-up | `c_rrpv_wbuf_cam_hit_update`、`full_seen`、`true_full_block`、`full_release`、`push_pop_same_cycle`、`c_wbuf_full_blocks_new_reads`、`c_wbuf_full_allows_ptw_writeback` 均为 0，必须转 Phase6G targeted coverage 或 waiver；本轮 PASS 不能关闭 full/latest-wins/same-cycle 行为。 |
| Future exact item | exact victim/free-way/max-RRPV、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass、PTW/TLBOP pending conflict 仍为 future exact-model；不能由 `credit_sb`、generic RRPV wrapper 或本次 debug SVA pass 关闭。 |

### Phase 6G：coverage、regression 与最终收口

目标：定义 UVM 修改补充工作可以关闭所需的证据。

金标准回查与质量规则：6G 实施前必须对照 `l2tlb_function_description.md` 检查 coverage/regression 是否真正覆盖 source/result/page/ASID/control/error/debug/future 分类。总 coverage、`UVM_ERROR=0`、generic regression pass 和历史 URG 报告不能关闭单个 TP/SVA。最终 closure 必须以更高质量验证 DUT 为准则，逐项列出 remaining holes、waiver、future、blocked 项和质量风险，并写入 `progress.md`。

候选落点：

- 现有 covergroup 和 white-box coverage collection。
- 如果现有 bin 不能表达 audit 需求，可新增 L2TLB coverage helper。
- Regression list、Makefile target、closure script 和 coverage/report flow 可按本 phase 门禁修改。

coverage/regression 实施基线：

| 区域 | 当前已有能力 | Phase6G 判断 |
| --- | --- | --- |
| Makefile coverage/run | 已有 `run_check`、`run_cov`、URG 合并、`COV_METRICS := line+cond+fsm+tgl+branch+assert`、`scripts/cov_hier.cfg`。 | 可复用为执行框架；不能单独证明 L2TLB audit source/result bins 已触发。 |
| Generic regression | `scripts/run_test.py` 支持 list、seed、`run_check/run_cov`、summary、expected fail。 | 可复用；L2TLB closure list 必须禁止无 owner 的 `xfail`，或把每个 expected fail 绑定 issue/waiver。 |
| Log hygiene | `scripts/check_sim_status.sh` 能检查 UVM_ERROR/UVM_FATAL 和 fatal/error pattern。 | 只能作为 health gate；不能替代 trigger evidence、scoreboard/SVA evidence 或 coverage bin closure。 |
| Phase13/14 gate | `phase13_exit_gate.py`、`phase14_exit_gate.py` 已有 artifact/threshold/signoff 检查模式。 | 只能作为 gate 脚本设计参考；其 signoff ID 和 coverage group 面向 Phase13/14，不可直接用于 L2TLB。 |
| L1DTLB Phase6G | 已有 `l1dtlb_phase6g_closure.py`、`l1dtlb_phase6g_replay.py`、manifest/run-list 模式。 | 是最接近的可复用模式；L2TLB 仍需独立 manifest、run-list、required counters/covers/report rules。 |
| 现有 run list | `simu/mmu_smoke_list` 有少量 L2TLB smoke；`mmu_nightly_list`、`mmu_coverage_list` 有 L2TLB/PTW/PFU/TLBOP 压力入口。 | 可作为 integration/nightly candidate；不能替代 L2TLB targeted closure list。 |
| Whitebox coverage | `mmu_env_cg_whitebox.svh` 有 `cg_l2tlb_bank`、`cg_l2_reqq`、`cg_tlboper_fsm`、`cg_ptw_walk` 等。 | 可复用部分 bin；当前 log summary 未打印所有 L2TLB 相关 covergroup，report 不可用时缺 L2-specific fallback。 |
| 现有 coverage report | 既有 Phase14 URG report 可展示工具链状态。 | 只能作为历史样例；其中 L2 相关 group 和 assert 仍有明显缺口，不能作为 Phase6G closure。 |

充分性结论：

- 现有 regression/coverage 基础设施不足以完成 L2TLB closure。必须新增或明确批准 L2TLB-specific run list、coverage bin mapping、evidence manifest 和 closure scanner，才能把 `L2TLB_TP_001..058`、`L2TLB_SVA_001..024` 逐项关闭。
- `mmu_smoke_list`、`mmu_nightly_list`、`mmu_coverage_list`、Phase14 URG report、`UVM_ERROR=0` 或 generic summary pass 都只能作为辅助健康证据，不能替代场景触发、checker/SVA pass 和 coverage/report 证据。
- `scripts/cov_hier.cfg` 排除部分 SVA module 的 code coverage 后，assertion/cover property closure 必须从 assertion log、cover property report 或 L2TLB closure manifest 独立记录。
- 若 whitebox covergroup report 无法稳定提取，6G 实施必须补 L2TLB log fallback summary 或显式 waiver；不能用总体 coverage score 推断单个 audit bin 已覆盖。

本阶段实施输出：

- 覆盖关键 source types：ITLB、DTLB load、DTLB store、PFU、PTW refill、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID。
- 覆盖关键 result types：single-hit、miss+MB alloc、MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny、reset/abort。
- Regression tiers：compile、directed smoke、negative assertion、L2TLB targeted、integration/nightly candidate。
- 最终 closure 前记录 coverage threshold 和 waiver 格式。

Coverage bin mapping：

| Coverage family | 必须覆盖的 bin | 相关 ID | 最低证据 |
| --- | --- | --- | --- |
| Source / operation | ITLB、DTLB load、DTLB store、PFU、PTW refill/read/write、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID。 | `L2TLB_TP_004..017`, `028..044`, `051..054` | source trigger counter/cover + owner checker 或 SVA pass；不能只靠 wrapper 名称。 |
| Result / terminal state | single-hit、miss+MB alloc、MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny、reset/abort、timeout/fairness release。 | `L2TLB_TP_012..033`, `043`, `049..050`, `055..057` | final response classifier + transaction scoreboard/SVA evidence；error payload 按 Phase4 ignore rule 处理。 |
| Page / ASID / global | 4K、2M、1G、offset boundary、ASID match/mismatch、global/non-global、multi-way hit classifier。 | `L2TLB_TP_012..016`, `034..041`, `057` | L2 entry shadow compare + page-size/ASID/global cover；multi-hit 不能当 normal single-hit closure。 |
| Arbiter / flow control | ITLB entry0、DTLB entry1..8、PFU source、pairwise/four-source conflict、`ptw_on` stall/release、`tlboper_on` stall/release、prefetch mask、MB partition full。 | `L2TLB_TP_004..011`, `019..024`, `051..055` | ReqQ/MB/PTW/PFU ownership counter + no-cross/no-overwrite/no-stale checker 或 SVA。 |
| Negative / illegal | bad type、bad page size、bad ID/completion、credit overflow、control hazard、protocol-violating CSR/control write。 | `L2TLB_TP_027`, `048`, `056`, `058` | 独立 negative list；expected assertion/error handling evidence；不得混入 normal functional coverage。 |
| Debug / future replacement | RRPV init/hit/miss/wbuf pressure、no-overflow/no-wrong-grant、visible replacement result、future exact victim/RRPV/latest-wins。 | `L2TLB_TP_045..047`, `L2TLB_SVA_022..024` | Debug cover/SVA 或 future/waiver；exact victim/RRPV 不计入 v1 closure。 |

Regression tier 规划：

| Tier | 目的 | 候选入口 | 关闭规则 |
| --- | --- | --- | --- |
| `l2tlb_compile` | 编译和 bind/include 健康检查。 | `make comp` 或 `make comp_fast`。 | compile/elab/link pass；新增 SVA/bind 时必须 assertion-enabled compile。 |
| `l2tlb_smoke` | 快速确认 basic reset、single-hit、basic miss、basic TLBOP。 | 后续新增 `simu/l2tlb_phase6g_smoke_list`。 | 每个 smoke case 有 manifest row；无未解释 UVM_ERROR/UVM_FATAL。 |
| `l2tlb_directed_p0` | 关闭 P0/P1 source/result/owner bins。 | 后续新增 `simu/l2tlb_phase6g_targeted_list`。 | 每个 P0/P1 TP 有 trigger + checker/SVA evidence，或 approved waiver/future。 |
| `l2tlb_negative` | 隔离非法输入、bad completion、control hazard。 | 后续新增 `simu/l2tlb_phase6g_negative_list`。 | expected assertion/error 分类正确；不得污染 normal pass-rate。 |
| `l2tlb_debug_rrpv` | 记录 RRPV/replacement debug pressure。 | 后续新增 `simu/l2tlb_phase6g_debug_rrpv_list`。 | 只关闭 debug evidence；exact victim/RRPV/latest-wins 保持 future。 |
| `l2tlb_timeout_fairness` | 检查 backpressure、retry、eventual release。 | 后续新增 `simu/l2tlb_phase6g_timeout_fairness_list`。 | timeout/fairness classifier pass；环境永久 backpressure 必须单独 waiver。 |
| `l2tlb_coverage` | 生成 coverage/URG 和 L2-specific cover fallback。 | `run_cov` + URG；必要时新增 L2 helper/report。 | threshold 运行前固定；未达 bin 进入 issue/waiver/future。 |
| `integration/nightly candidate` | 确认目标测试进入全局回归后不回退。 | `mmu_nightly_list`、`mmu_coverage_list`、`mmu_v4_full_regression_list` 的后续补充。 | 只能作为 signoff 附加证据；不能替代 targeted closure。 |

Phase6G 必须新增或批准的 closure artifacts：

| Artifact | 用途 | 状态规则 |
| --- | --- | --- |
| `simu/l2tlb_phase6g_smoke_list` | Basic smoke closure list。 | 本 phase 可新增或更新；必须有 manifest row。 |
| `simu/l2tlb_phase6g_targeted_list` | P0/P1 directed closure list。 | 每个 case 必须能回溯到 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx`。 |
| `simu/l2tlb_phase6g_negative_list` | Negative assertion-only list。 | 与 normal directed/random 分离。 |
| `simu/l2tlb_phase6g_debug_rrpv_list` | RRPV/replacement debug list。 | 不关闭 future exact item。 |
| `simu/l2tlb_phase6g_timeout_fairness_list` | Timeout/fairness targeted list。 | 必须带 release/timeout classifier。 |
| `simu/l2tlb_phase6g_evidence_manifest.tsv` | 每个 run 的 closure evidence 索引。 | 缺 manifest row 的 TP/SVA 不得标 Complete。 |
| `scripts/l2tlb_phase6g_closure.py` 或 generic manifest scanner | 检查 log、required report/counter/cover、waiver 和 issue linkage。 | 不能只读 regression pass summary；必须检查 L2TLB-specific evidence。 |
| `scripts/l2tlb_phase6g_replay.py` 或等价 replay flow | 复现 manifest row。 | 可选，但 signoff 前建议保留 seed/command 可复现性。 |
| L2TLB coverage summary/report | 提取 L2 source/result/page/ASID/control bins。 | URG 可用时记录 report path；不可用时记录 log fallback 和工具限制。 |
| Closure report | 汇总 TP/SVA/bin/waiver/future 状态。 | 必须作为最终 review 输入。 |

Evidence manifest 格式建议复用 L1DTLB Phase6G 模式：

```text
case_id|phase|test|seed|status|accepted_warnings|required_reports|required_counters|required_covers|related_ids|notes
```

Manifest 规则：

- `status` 只允许使用明确状态，例如 `closure`、`negative`、`debug`、`waived`、`future_exact_model`、`blocked`；不得用 `pass` 代替 closure 语义。
- `related_ids` 必须列出精确 `L2TLB_TP_xxx`、`L2TLB_SVA_xxx` 或 issue/waiver ID。
- `required_reports|required_counters|required_covers` 为空时，只能表示该行是 compile/health evidence；不能关闭功能覆盖。
- P0/P1 TP 和 must SVA 至少要有一条 `closure` manifest row，或一条 approved waiver/future row；否则 Phase6G 不能 Complete。
- Debug/future 行必须保留在 manifest 中，防止 exact replacement/RRPV 缺口被总覆盖率掩盖。

Closure checklist：

| 检查项 | Phase6G closure 要求 |
| --- | --- |
| Compile | `l2tlb_compile` pass，新增 bind/SVA/include 在 assertion-enabled build 中可见。 |
| TP 状态 | `L2TLB_TP_001..058` 每项必须是 implemented+evidence、approved waiver 或具名 future；P0/P1 不允许 unowned。 |
| SVA 状态 | `L2TLB_SVA_001..024` 每项必须与 6D must/debug/future 分类一致；must 行不能由 partial-existing 关闭。 |
| Source/result bins | 所有 source/result/page/ASID/control bin 命中或逐项 waiver/future。 |
| Negative 隔离 | illegal/control/bad-completion 只在 negative list 中关闭，且 expected assertion/error 分类正确。 |
| Logs | 无未解释 UVM_ERROR/UVM_FATAL/assert fail；negative expected fail 不进入 normal pass-rate。 |
| Coverage threshold | threshold 在运行前写入；未达项进入 issue/waiver/future，不得事后调整阈值掩盖缺口。 |
| Reports | 记录 URG/assertion/SVA cover/report path；report 不可用时记录 L2-specific log fallback。 |
| Regression pass-rate | closure tiers 要求 100% effective pass；任何 xfail 必须绑定 issue/waiver。 |
| Remaining holes | 每个缺口都有 owner、risk、next action 和 review 状态。 |

#### Phase 6G 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Coverage/regression inventory | 记录 Makefile、generic regression、coverage/URG、gate script、run list、whitebox coverage、closure script 的实际修改和可复用范围。 |
| 金标准 coverage 回查 | 记录 source/result/page/ASID/control/error/debug/future bins 是否覆盖金标准要求，未覆盖项逐项进入 issue/waiver/future。 |
| L2TLB closure sufficiency | 记录 L2TLB-specific manifest、run-list、scanner、coverage/SVA/log fallback 是否能逐项关闭 TP/SVA。 |
| Coverage bin mapping | 按 source/result/page/arbiter/negative/debug family 记录最低证据、覆盖结果和缺口。 |
| Regression tiers | 记录 compile、smoke、directed、negative、debug RRPV、timeout/fairness、coverage、integration/nightly candidate 的命令、seed、日志和结果。 |
| Closure artifacts/checklist | 记录 manifest、closure report、threshold、waiver/future、remaining holes、review 结论和 `progress.md` 完成记录。 |

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6A~6F 的 deliverables 已实现、waive、blocked 或移入 future；已完成金标准回查；目标 regression list 已可复现。 |
| 交付物 | Coverage bin mapping；regression tiers；closure checklist；coverage/SVA report 路径；remaining holes/waiver list；`progress.md` 关键发现和完成记录。 |
| 检查命令/证据 | 至少记录 compile、directed smoke、negative assertion、targeted L2TLB regression 的命令、seed 数、日志路径和结果；integration/nightly candidate 若未执行需说明。 |
| Pass/fail | 目标回归无未解释 UVM_ERROR/UVM_FATAL；P0/P1 TP 和 must SVA 全部 implemented+evidence、approved waiver、future 或 blocked reason；未完成门禁不得标为 Complete。 |
| Coverage/SVA/log | Coverage threshold 必须在运行前记录；report 不可用时允许 log fallback，但必须记录工具限制和替代证据。 |
| Waiver | 未达 coverage、未触发场景、SVA cover 缺口必须逐项 waiver 或移入具名 future phase；waiver 需要 approver 和风险说明。 |

#### Phase 6G 实施完成记录（2026-05-23）

本轮已实现 Phase6G closure infrastructure，且 default manifest/scanner gate 已 PASS。所有关闭结论以 manifest/scanner 证据为准，不能用 generic regression PASS 替代；PTW disabled/fault/access-error source-specific harness、isolated negative injector 和 P1 TLBOP/hash exact rows 已用 manifest closure row 关闭，RRPV exact/wbuf 项仍以 future/waiver 形式保留风险边界。

| 项目 | 结果 |
| --- | --- |
| 新增 artifact | `simu/l2tlb_phase6g_smoke_list`、`simu/l2tlb_phase6g_targeted_list`、`simu/l2tlb_phase6g_negative_list`、`simu/l2tlb_phase6g_debug_rrpv_list`、`simu/l2tlb_phase6g_timeout_fairness_list`、`simu/l2tlb_phase6g_evidence_manifest.tsv`、`scripts/l2tlb_phase6g_closure.py`、`scripts/l2tlb_phase6g_replay.py`。 |
| 证据模型 | Manifest 逐 row 记录 `closure/negative/debug/waived/future_exact_model/blocked`，并要求 exact `L2TLB_TP_xxx`、`L2TLB_SVA_xxx`、issue 或 waiver linkage；scanner 检查 report token、required counter、required cover、UVM summary、bad log pattern 和 blocked/waiver/future 合法性。 |
| 运行证据 | `make comp_fast` pass；Phase6G smoke list 3/3 pass，targeted list 更新后 5/5 generic pass，negative list 1/1 pass，debug RRPV list 1/1 pass；aggregate negative `test_l2tlb_p6e_negative_ptw_completion_control` seed 66001、四个 individual negative manifest rows、8 个 P1 exact TLBOP wrapper seeds 65034..65041 和 hash directed seed 66001 均可由 scanner 解析；`python3 -m py_compile` 和 `git diff --check` pass。 |
| Closure gate | Timeout/fairness、TLBOP/PTW LSU、PTW source-specific、negative injector、P1 exact/hash rows 和 P1 ReqQ/arbiter fine-grain row 均已补到 manifest 级证据；default scanner 应输出 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26`。 |
| Closed blocker | `P6E_TLBOP_INV_ABORT` closure：`test_l2tlb_p6e_tlbop_inv_abort_lifecycle` seed 64001 复跑 `UVM_ERROR=0`、无 `failed at`，shadow delta `inv=109 abort_epoch=109 control_epoch=9253`，`cp_lsu_abort_entry_clear=6`；root-cause 为 PTW LSU SVA 未建模合法 TLBOP abort clear。 |
| Closed blocker | `P6G_TIMEOUT_FAIRNESS_CLOSURE` closure：`test_l2tlb_p6e_timeout_fairness_release` seed 64001 复跑 `UVM_ERROR=0`、`UVM_FATAL=0`、`PHASE6C_L2_SHADOW:mismatch=0`，shadow delta `activity=544 pfu=52 payload_ignore=52`，`credit_sva.c_d_req_back_to_back_valid=2`；链接已关闭的 `L2TLB-P6-ISSUE-013`。 |
| Closed blocker | `P6E_PTW_SOURCE_FAULT_CLOSURE` closure：`test_l2tlb_p6e_ptw_disabled_fault_accerr` seed 64001 复跑 `UVM_ERROR=0`、`UVM_FATAL=0`；`PHASE6C_L2_SHADOW` 显示 `ptw_disabled_*` 四源均为 1、`ptw_pgflt_*` 四源均 >0、`ptw_accerr_*` 四源均 >0、`payload_ignore=17`、`mismatch=0`、`waived_future=0`；更新后的 targeted list 5/5 pass，closure scanner PASS。 |
| Closed negative | `P6E_NEG_PROTOCOL_SUITE` closure：`test_l2tlb_p6e_negative_ptw_completion_control` seed 66001 复跑 `UVM_ERROR=0`、`UVM_FATAL=0`；`L2TLB_PHASE6E_CLOSE` 显示 `trigger_count=4`、`checker_count=4`、`waiver_count=0`、`future_or_waiver=0`；individual `no_outstanding`、`bad_id_type`、`illegal_combo`、`control_hazard` rows 均有 `L2TLB_NEG_TRIGGER` 和 `L2TLB_NEG_EXPECTED_CLASS` evidence。 |
| Closed exact | `P1_TLBP/TLBR/TLBWI/TLBWR_*` closure：8 个 exact TLBOP wrapper seeds 65034..65041 均 `UVM_ERROR=0`、`UVM_FATAL=0`，log 中有 `L2TLB_TLBOP_CHECK`/`L2TLB_TLBOP_READBACK` evidence；`P1_L2TLB_HASH_EXACT_DIRECTED` seed 66001 在 RTL owner/user 将 `mask_bank_sel` 常量改为显式 `8'b...` 后复跑 `UVM_ERROR=0`、无 `L2TLB_HASH_FAIL`，selector 00/01/10/11 和 `tlbop_idx_not_va` cover 均命中。 |
| Closed exact/fine-grain | `P1_REQQ_ARB_FINE_CLOSURE`：现有 `P6E_REQQ_ARB_OWNER` 只关闭 coarse DTLB-load ReqQ/credit 和 PTW/TLBOP/ReqQ payload baseline；2026-05-24 targeted `test_l2tlb_p6e_reqq_arb_fine_overlap` 在修复 L1DTLB spec SB stale-shadow current-entry policy、补 CP0 TLBP `cskyee` 前置、增加 MCIR completion guard 和 per-MCIR timestamp 后，将 CP0 TLBP burst 相位对齐到 `delay_1ns_steps=36581`。重新 `make comp_fast` 后有效 run 显示 `event=start t=38042000`、`event=mcir_issue t=38045000 op=0`，并在 `t=38049000` 同拍命中 `four_req`、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、PTW/ReqQ/PFU、TLBOP/ReqQ/PFU、PTW/TLBOP/ReqQ 和 PTW/TLBOP/PFU。最终 `L2TLB_ARB_FINE` 为 `four_req=1 ptw_reqq_conflict=2 tlbop_reqq_conflict=14 ptw_tlbop_conflict=1 reqq_pfu_conflict=378 ptw_reqq_pfu_conflict=2 tlbop_reqq_pfu_conflict=10 ptw_tlbop_reqq_conflict=1 ptw_tlbop_pfu_conflict=1 ptw_on_reqq_block=7 tlboper_on_pfu_block=90 prefetch_mask_release=128`；`L2TLB_REQQ_FINE` 证明 ITLB/DTLB load/store source split `i/d-load/d-store req=104/160/184`；SVA covers `c_pairwise_ptw_reqq_conflict=2`、`c_pairwise_tlbop_reqq_conflict=14`、`c_diag_ptw_tlbop_conflict=1`、`c_diag_ptw_reqq_pfu_conflict=2`、`c_diag_tlbop_reqq_pfu_conflict=10`、`c_ptw_on_blocks_reqq=7`、`c_tlboper_on_blocks_pfu=90`、`c_prefetch_mask_release=128` 均命中。UVM summary clean，Phase6C L2 shadow `orphan=0 mismatch=0`；`waived_future=1` 仅来自既有 L2 hit future waiver，不作为 fine-grain row 的失败条件。DUT/RTL 未修改。 |
| Waiver/future | exact victim/RRPV value、wbuf latest-wins/merge/same-cycle bypass 仍保留 future/waiver row；不得计为已实现 exact-model closure。 |
| Review 结论 | Phase6G run-list/manifest/scanner/replay flow 已落地并能防止表面通过；timeout/fairness、TLBOP/PTW LSU root-cause、PTW source-specific harness、isolated negative injector、P1 TLBOP/hash exact rows 和 P1 ReqQ/arbiter fine-grain row 均已关闭。default gate 应 PASS；exact RRPV/wbuf 缺口仍保留 future/waiver。 |

#### Phase 6G Open Closure Plan（2026-05-23）

以下计划用于承接 Phase6G default closure gate 通过后的剩余深度验证工作。关闭顺序必须以提高 DUT 验证质量为准；任何条目在没有 trigger、checker/SVA、coverage 或 approved waiver/future 证据前，不得因为 wrapper 名称、generic regression pass、`UVM_ERROR=0`、总 coverage 或历史日志而标记为完成。

| 优先级 | 计划项 / 相关 ID | 当前状态 | DUT 验证风险 | 必须实现的动作 | 退出标准 |
| --- | --- | --- | --- | --- | --- |
| P0 | Timeout/fairness root-cause：`L2TLB_TP_049..050`、`L2TLB-P6-ISSUE-013`、`P6G_TIMEOUT_FAIRNESS_CLOSURE` | Closed；seed 64001 已 `UVM_ERROR=0`、shadow mismatch=0 | 初始失败来自 testbench 过严/滞后判断：PFU flag-only 诊断位参与 PA payload compare、L1DTLB MB CAM 只看上一拍 shadow、ReqQ SVA 不允许合法 back-to-back DTLB request | 已实现 PFU payload-ignore classifier、MB current-window classifier、DTLB back-to-back ReqQ SVA policy；manifest row 更新为 closure | Targeted timeout/fairness seed 64001 clean；`activity=544 pfu=52 payload_ignore=52`；`c_d_req_back_to_back_valid=2`；无未解释 UVM_ERROR/UVM_FATAL 或 bad log pattern |
| P0 | TLBOP/INV/abort lifecycle：`L2TLB_TP_034..044`、`L2TLB_SVA_015..016`、`L2TLB-P6-ISSUE-015`、`P6E_TLBOP_INV_ABORT` | Closed；seed 64001 已无 `failed at` | TLBP/TLBR/TLBWI/TLBWR/INV/abort 的 request/grant/done、epoch、payload side-effect 可能被错误关闭 | 已 root-cause：`mbuf_entry_on` 是 entry lifecycle marker，会在合法 TLBOP abort clear 中改变；SVA 改为 accept/response/abort lifecycle event，并新增 abort-entry-clear cover | TLBOP/INV/abort directed row 有 trigger + lifecycle checker/SVA pass；`UVM_ERROR=0`、bad-pattern scan clean、`cp_lsu_abort_entry_clear=6` |
| P0 | PTW disabled/fault/access-error source-specific harness：`L2TLB_TP_018`、`025`、`026`、`033`、`L2TLB_SVA_012`、`014` | Closed；`P6E_PTW_SOURCE_FAULT_CLOSURE` seed 64001 | 原风险是 PTW disabled、page fault、access error 和 PFU error payload 只被粗粒度日志覆盖，未证明 source-specific final response 和 Phase4 payload-ignore 规则正确 | 已新增 directed positive harness，区分 ITLB/DTLB load/DTLB store/PFU；shadow 记录 final response classifier、disabled terminal classifier、payload-ignore evidence；`L2TLB-WAIVE-P6E-001` 已被 closure row supersede | Manifest `closure` row 要求 12 个 source/result counter 全部 >0、`payload_ignore>0`、`mismatch=0`、`waived_future=0`、`UVM_ERROR/FATAL=0`；更新后 targeted list 5/5 pass，该 row 纳入最终 closure scanner PASS |
| P0 | Negative injector：bad PTW completion、illegal input、OOO、control hazard；`L2TLB_TP_027`、`048`、`056`、`058`、`L2TLB_SVA_012`、`013`、`017`、`018`、`L2TLB-WAIVE-P6E-002` | Closed；legacy OOO wrapper 仍 obsolete，不用于 normal coverage | 非法输入或协议违例可能混入 normal functional coverage，或者 expected assertion/error 没有被正确分类 | 已建立独立 negative suite；注入 no-outstanding completion、bad ID/type、illegal result combo 和 outstanding control hazard；normal list 与 negative list 分离；expected shadow mismatch 在 negative window 内分类为预期负向事件 | Negative manifest rows `P6E_NEG_PROTOCOL_SUITE`、`P6E_NEG_PTW_NO_OUTSTANDING`、`P6E_NEG_PTW_BAD_ID_TYPE`、`P6E_NEG_PTW_ILLEGAL_COMBO`、`P6E_NEG_CONTROL_HAZARD` 均 PASS；aggregate seed 66001 `trigger_count=4 checker_count=4 waiver_count=0 future_or_waiver=0 UVM_ERROR=0 UVM_FATAL=0`；normal functional regression 不依赖 negative fail |
| P1 | TLBP/TLBR/TLBWI/TLBWR exact decode/readback：`L2TLB_TP_034..037`、Phase6C remaining hole | Closed after RTL owner/user bank-mask fix | CP0/TLBOP path 可能只验证到 wrapper 运行，未证明 transaction decode、readback data、entry shadow side-effect 正确；hash/index/bank 若只做 debug cover，会遗漏 selector/page-size bank mask bug | 已新增 CP0 TLBOP exact sequences 和共享 L2TLB hash/skew/page-size/bank-mask golden model；`mmu_arb_sva` 对 idx/size/bank 做 exact compare 并把 mismatch 升级为 UVM error；bank mask golden model 由 2.3 arbiter 的 per-bank pre page size 表派生，不再维护重复硬编码 mask 表；`test_arb_skew_index_generation` directed 覆盖 selector 00/01/10/11。RTL owner/user 已将 `mmu_arb.sv` `mask_bank_sel` 常量修为显式 `8'b...` | 8 个 exact TLBOP wrapper seeds 65034..65041 全部 `UVM_ERROR=0`、`UVM_FATAL=0`；hash directed seed 66001 复跑 `UVM_ERROR=0`、无 `L2TLB_HASH_FAIL`、translation SB `mismatch=0`，selector 00/01/10/11 cover 为 787/18/19/12，`tlbop_idx_not_va=768`；manifest scanner P1 rows PASS |
| P1 | ReqQ/arbiter/ownership fine-grain closure：`L2TLB_TP_004..011`、`019..024`、`051..055`、`L2TLB_SVA_003..006`、`019..020`、`L2TLB-P6-ISSUE-017/031` | Closed；`P1_REQQ_ARB_FINE_CLOSURE` seed 64001 | payload no-cross baseline 已有，但 source ownership、ptw_on/tlboper_on stall-release、pairwise/four-source conflict 曾未被完整精确覆盖；现有 `mmu_l2tlb_bank_conflict_vseq` 是串行 LSU load，不能代表 multi-source conflict | 已把 coarse row 收紧到 `L2TLB_REQQ_FINE`/`L2TLB_ARB_FINE` counter，并用 targeted CP0 TLBP phase-aligned overlap 关闭 four-source、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、triple conflict、ptw_on/tlboper_on block 和 PFU mask release；closure row 还要求 clean UVM summary 与 Phase6C L2 shadow `orphan=0/mismatch=0` | 每个 arbiter/flow-control bin 有 trigger + checker/SVA evidence；default closure scanner 无 blocked row；无 owner 丢失或 payload cross；未达 exact RRPV/wbuf 项继续进入 approved waiver/future |
| P1 | PFU source/truth-table closure：`L2TLB_TP_028..033`、`053`、`057`、`L2TLB_SVA_021` | Partial/Open | PFU 粗粒度 pass 不能证明 MMU-off direct、MMU-on L2 hit、PTW path、flag/PMP/sysmap、prefetch mask 和 attribute truth-table 全覆盖 | 补 PFU source-specific directed runs 和 attribute truth-table cover；把 PFU fault/error payload 与 Phase4 ignore 规则绑定 | PFU source/result/truth-table bin 全部命中或 waiver；PFU 相关 manifest row 不只依赖 wrapper 名称 |
| P1 | RRPV/replacement exact model 与 WBUF：`L2TLB_TP_045..047`、`L2TLB_SVA_022..024`、`L2TLB-P6-ISSUE-014`、`L2TLB-WAIVE-P6F-001/002` | Debug/Future/Open | replacement 可见结果、wbuf full/CAM-hit/latest-wins/same-cycle/PTW-writeback 行为可能未被持续观测，exact victim/RRPV 不应被误判为已关闭 | 保持 exact victim/free-way/max-RRPV、exact RRPV value、latest-wins/CAM merge/same-cycle bypass 为 future 或实现精确模型；补 debug cover hole targeted runs | Debug bins 有 cover/SVA evidence；exact model 项要么实现并通过，要么保留 approved future/waiver；v1 functional closure 不被 exact-model 缺口污染 |
| P1 | Coverage/URG/report threshold 与 integration/nightly closure：`L2TLB_TP_050`、Phase6G coverage/checklist | Open | 只有 manifest/scanner 不能替代真实 coverage threshold、L2-specific report 和全局回归防回退证据 | 固定运行前 threshold；执行 `l2tlb_coverage`/URG 或 L2 log fallback；补 integration/nightly candidate list；报告 source/result/page/ASID/control/error/debug bins | Coverage report 或 fallback summary 可追溯；未达项进入 issue/waiver/future；closure tiers 100% effective pass；任何 xfail 绑定 issue/waiver |
| P1 | Waiver/future approval closure：所有 `L2TLB-WAIVE-*`、future exact rows | Open；部分 approver 为 `TBD` | 未签核 waiver/future 会把真实验证缺口伪装成已接受风险 | 为每条 waiver/future 补 owner、approver、风险、替代证据、后续 phase 或不实现理由；未批准项保持 open/blocker | 所有 waiver/future 有 approver 和风险接受记录；未批准 waiver 不得关闭 P0/P1 TP 或 must SVA |

执行约束：

- 任何修复或新增测试都必须同步更新 `simu/l2tlb_phase6g_evidence_manifest.tsv`、closure report、`progress.md` 和相关 run list。
- 若 root-cause 指向 DUT/RTL bug，先记录 issue、最小复现、期望/实际行为和质量风险；DUT/RTL 修改仍需明确同意。
- 若发现 BuildPlan 仍漏掉金标准要求，以 `l2tlb_function_description.md` 为准补计划、测试、checker/SVA、coverage 或 waiver/future，不能为了关闭表格降低验证严格度。

## 4. 候选交付物矩阵

| 区域 | 现有候选 | 实施职责 |
| --- | --- | --- |
| Probe interface | `mmu_dut_probes_if.sv` | 为 L2 final、ReqQ、MB、PTW、TLBOP、PFU、reset/abort、RRPV debug 提供稳定 white-box 观察。 |
| Top wiring | `tb_top.sv` | 连接已批准 probe 和 SVA bind；top 内不放 checker 逻辑。 |
| Translation scoreboard | `mmu_translation_sb.svh` | 负责 transaction-level compare 和 PTW/PFU/L1 final response 归属。 |
| Invalidate scoreboard | `mmu_invalidate_sb.svh` | 若选择该 owner，扩展 invalidate event tracking 到 L2 entry shadow effect。 |
| SVA | `mmu_l2tlb_rrpv_sva.sv` 和可选新文件 | 实现 Phase 3 must/debug SVA 和 cover property。 |
| Directed tests | `l2tlb_tests/`、`tlbop_tests/` | 只有在有明确 TP mapping 和 trigger/checker evidence 时才新增或重标 wrapper。 |
| Package/suite include | `test_pkg.sv`、suite files | 为已批准测试提供 compile-visible wrapper registration。 |
| Coverage | 现有 covergroup 或 L2 helper | 收口 source/result/type bins，不把 debug bins 变成 v1 pass/fail。 |
| Makefile / run flow | Makefile、`simu/*list`、`scripts/*closure*` | 接入 L2TLB compile、smoke、directed、negative、debug、timeout/fairness、coverage 和 closure manifest；修改必须可复现并写入 `progress.md`。 |
| Progress tracking | `progress.md`、可选 `L2TLB_UVM_Phase6_Progress.md` | 每个 phase 的关键发现先写入 `progress.md`；完成后记录修改文件、命令/log、trigger/pass-fail evidence、waiver/future 和 remaining holes。 |

## 5. 风险与 waiver 规则

| 风险 | 必须处理方式 |
| --- | --- |
| 缺失稳定 probe | 在 Phase 6A 新增 probe，或用替代 checker waiver。 |
| 现有 wrapper 名称造成虚假覆盖 | 标为 covered 前必须有 trigger/checker evidence。 |
| BuildPlan 漏掉金标准要求 | 以 `l2tlb_function_description.md` 为准补充 UVM/test/checker/SVA/coverage，并在 `progress.md` 记录 `golden-spec-gap` 或 `buildplan-gap`。 |
| 表面关闭风险 | wrapper 名称、历史 pass、`UVM_ERROR=0`、总 coverage、generic regression pass 都不能替代逐项证据。 |
| Scoreboard 过度建模微架构 | exact replacement/RRPV/per-cycle arbitration 不进入 v1 pass/fail。 |
| 非法输入污染随机测试 | negative assertion test 必须与普通功能回归分离。 |
| Fault payload mismatch 误报 | 使用 Phase 4 payload ignore rules。 |
| 工具无法生成 coverage report | 只有记录门禁限制和 log fallback evidence 时才能 waiver。 |
| DUT/RTL 可疑或需修改 | 先记录 issue/blocker 和质量风险；DUT/RTL 修改必须征得明确同意后执行。 |

## 6. Phase 6 实施退出检查表

| 检查 | 退出要求 |
| --- | --- |
| 金标准回查 | 6A~6G 每个 phase 都已对照 `l2tlb_function_description.md` 检查遗漏项。 |
| Progress 记录 | 每个 phase 的关键发现先写入 `progress.md`，完成后有 phase 完成记录。 |
| 修改范围 | UVM/testbench/Makefile/run-flow 修改均有文件清单；DUT/RTL 修改有单独同意记录。 |
| 可观测性 | Probe/monitor/source consumer 满足 checker/SVA/coverage 需求，缺口有 waiver/future/blocker。 |
| Testcase 充分性 | 现有和新增 testcase 足够覆盖 L2TLB 测试点和功能；不足项有 owner 和后续动作。 |
| Scoreboard/SVA | P0/P1 TP 和 must SVA 有 implemented+evidence、approved waiver、future 或 blocked reason。 |
| Coverage/Regression | L2TLB-specific run list、manifest、closure scanner/report 或等价机制能逐项关闭 TP/SVA。 |
| 表面目标防护 | 不用 wrapper 名称、generic pass、总 coverage 或 `UVM_ERROR=0` 替代 trigger/pass-fail evidence。 |
| Waiver/Future | 所有 waiver/future 有相关 ID、原因、质量风险、approver 和后续动作。 |
