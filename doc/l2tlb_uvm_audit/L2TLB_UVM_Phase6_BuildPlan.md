# L2TLB UVM Phase 6 搭建计划

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：仅作为 L2TLB UVM 后续实现蓝图
> 规格来源：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 进度跟踪：`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`
> 日期：2026-05-21

## 1. 目的与边界

Phase 6 只创建后续 L2TLB UVM 实现的代码级蓝图。它不实现或修改 UVM、DUT/RTL、Makefile、仿真脚本、测试列表或 testbench 行为。

后续实现必须在本文档和 Phase 6 进度文档完成 review 后，由新的已批准阶段或计划启动。

主要输入：

- Phase 2 测试点：`l2tlb_function_description.md` 中的 `L2TLB_TP_001..058`。
- Phase 3 SVA 需求：`l2tlb_function_description.md` 中的 `L2TLB_SVA_001..024`。
- Phase 4 scoreboard/reference model 需求：`l2tlb_function_description.md` 第 8 章。
- 现有 UVM 入口：`mmu_dut_probes_if.sv`、`mmu_translation_sb.svh`、`mmu_invalidate_sb.svh`、`mmu_l2tlb_rrpv_sva.sv`、`l2tlb_tests/` 和 `test_pkg.sv`。

## 2. 后续代码阶段统一进入条件

任何后续代码阶段在修改 UVM 或 DUT 邻近文件前，实施负责人必须确认：

| 门禁 | 要求 |
| --- | --- |
| Review | 本 BuildPlan 和 `L2TLB_UVM_Phase6_Progress.md` 已完成 review。 |
| 范围批准 | 新阶段明确写出要实现的子阶段和允许写入的文件集合。 |
| 可追溯性 | 每项修改至少映射到一个 `L2TLB_TP_xxx`、`L2TLB_SVA_xxx` 或 Phase 4 scoreboard 规则。 |
| 基线 | 编辑前记录当前 compile/regression 基线。 |
| Waiver 路径 | 缺失 probe、不稳定信号、不支持场景、已知 RTL/spec gap 都有 issue 或 waiver 行。 |

本文档不得被后续阶段解释为默认批准修改 SystemVerilog、Makefile、RTL、脚本或回归列表。

## 3. 后续实施子阶段与严格退出门禁

### Phase 6A：可观测性与 monitor 就绪

目标：保证后续 checker 使用稳定 monitor/probe 输入，而不是临时层级路径。

候选落点：

- `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
- `mmu_verification/testbench/top/tb_top.sv`
- 如果顶层 transaction 比 white-box probe 更合适，可复用已有 agent monitor 和 analysis port。

后续实现的规划输出：

- ReqQ、arbiter grant、L2 final response、miss buffer、PTW request/completion、TLBOP state、PFU path、reset/abort epoch、RRPV/wbuf debug 的 probe 清单。
- 对每个缺失或不稳定信号选择一种处理：新增稳定 probe、从已有 transaction monitor 派生、waive、或归类为 future debug only。
- 内部 probe 仅作为 debug/checker 输入，不把 L2TLB 内部信号变成普通 sequence drive interface。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 已列出本阶段可写文件；已记录修改前 compile 基线；每个新增/改动 probe 都有 consumer。 |
| 交付物 | Probe/monitor inventory；missing-signal decision table；probe consumer list；对应 progress row。 |
| 检查命令/证据 | `make comp` 或后续阶段批准的等价 compile 命令通过；日志路径写入 evidence log。 |
| Pass/fail | 无 compile error；无 checker 使用未批准 `$root` fragile path；所有新增 probe 在 top/probe 边界内连接。 |
| Coverage/SVA/log | 本阶段不要求功能 coverage 达标；必须有 compile log 和 probe 清单审阅证据。 |
| Waiver | 缺失稳定 probe 必须说明替代 checker、风险和 approver；不能直接因信号缺失把相关 TP/SVA 标为完成。 |

### Phase 6B：场景 ID、wrapper 与 metadata 对齐

目标：把现有 `l2tlb_tests/` wrapper 与 audit 测试点 ID 对齐，但不因 wrapper 名称存在就宣称覆盖已完成。

候选落点：

- `mmu_verification/testbench/test/l2tlb_tests/`
- `mmu_verification/testbench/test/tlbop_tests/`
- `mmu_verification/testbench/test/test_pkg.sv`
- 仿真列表文件只能在后续已批准代码阶段修改。

后续实现的规划输出：

- `L2TLB_TP_001..058` 到现有 wrapper、新 wrapper、scoreboard/SVA-only item、negative assertion test 或 future item 的映射表。
- metadata 字段：scenario ID、checker owner、expected observable evidence、reviewer。
- 明确说明：已有 wrapper 名称不足以把测试点标为 covered。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | Phase 2 测试点表和 `.md` ID 清单一致；已定义 wrapper/checker/waiver/future 状态字段。 |
| 交付物 | `L2TLB_TP_001..058` 映射表；新增或复用 wrapper 清单；metadata 记录；progress row 更新。 |
| 检查命令/证据 | 若新增 wrapper 或 include，`test_pkg.sv` 和 suite include 必须 compile 通过；日志路径写入 evidence log。 |
| Pass/fail | 每个 P0/P1 测试点都有 wrapper/checker/waiver/future 状态和证据路径；不能只用 wrapper 名称作为 pass 依据。 |
| Coverage/SVA/log | 本阶段不要求 coverage closure；需要记录每个 ID 的 expected trigger evidence 和 pass/fail evidence 类型。 |
| Waiver | Waiver 必须精确引用 `L2TLB_TP_xxx`，写明未实现原因、替代证据、风险和 approver。 |

### Phase 6C：scoreboard 与 reference model 扩展

目标：实现 Phase 4 定义的 transaction-level L2TLB 模型边界，不建立 cycle-accurate 微架构 scoreboard。

候选落点：

- `mmu_verification/testbench/env/mmu_translation_sb.svh`
- `mmu_verification/testbench/env/mmu_invalidate_sb.svh`
- 如果现有 scoreboard 过大，可新增邻近 L2TLB helper class/package。

后续实现的规划输出：

- TLBWI、TLBWR、PTW refill、INV*、reset-inv、abort/reset epoch 的 L2 entry shadow 更新规则。
- 足以归类 L1/PFU 最终响应的 ReqQ/MB/PTW/PFU/TLBOP transaction ownership tracking。
- fault/no-pavld/PFU error 场景的 payload ignore 规则。
- TLB operation 对 shadow state 和 visible result check 的影响。
- mismatch 分类：`RTL bug`、`UVM bug`、`spec gap`、`tooling issue`、`approved waiver`。

v1 transaction pass/fail 明确不包含：

- exact replacement victim way、exact RRPV value、free-way/max-RRPV selection。
- RRPV wbuf latest-wins 或 same-cycle merge 精确行为。
- ReqQ/MB/arbiter/pipeline per-cycle priority，除非由具名 SVA/debug checker 覆盖。
- fault/no-pavld payload 字段和 illegal-protocol functional result。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6A 已提供需要的稳定观察源或 waiver；Phase 4 scoreboard 边界无未决解释项。 |
| 交付物 | L2 entry shadow；PTW/PFU/TLBOP ownership tracking；payload ignore 规则；mismatch taxonomy；scoreboard evidence row。 |
| 检查命令/证据 | compile 通过；directed L2 hit、miss+PTW、PFU 三路径、TLBP/TLBR/TLBWI/TLBWR、INV*、reset/abort、timeout/fairness 至少有 run log 或 waiver。 |
| Pass/fail | 通过场景无未分类 UVM_ERROR/UVM_FATAL；error message 包含 source、VPN、ASID、page size、expected、observed 和 mismatch category。 |
| Coverage/SVA/log | 需要 pass/fail log；coverage 若未达成可作为后续 6G closure，但不能缺失 scoreboard 场景证据。 |
| Waiver | 每个缺口必须分类为 `spec gap`、`tooling issue`、`approved waiver` 或 future；不能用 exact RRPV/victim 未建模导致 v1 fail。 |

### Phase 6D：SVA、bind 与 waiver 实现

目标：用稳定 bind 和 reset 语义实现或 waive Phase 3 SVA 需求。

候选落点：

- `mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`
- 如拆分更清晰，可新增 L2TLB SVA 文件。
- `mmu_verification/testbench/top/tb_top.sv`
- `mmu_verification/testbench/Files.f`
- 如果 assertion module 需要排除在 functional coverage score 外，可调整 coverage exclusion config。

后续实现的规划输出：

- `must`：`L2TLB_SVA_001..005`、`L2TLB_SVA_007..018` 必须实现或 waive。
- `debug`：`L2TLB_SVA_006`、`L2TLB_SVA_019..022` 在 probe 稳定时应作为 assertion/cover/debug checker 实现。
- `future`：`L2TLB_SVA_023..024` 保持 replacement/RRPV exact future item，除非单独批准 exact model 阶段。
- 每条 assertion 记录 trigger、forbidden behavior、reset disable rule、binding target、sampled signals 和 cover property requirement。

Assertion fail 处理分类：

- 真 bug：DUT 或 UVM 行为违反已确认规格，需要 issue。
- 误报：assertion 触发条件或采样窗口错误，需要修 assertion。
- 非法输入负向预期：仅允许在 negative assertion test 中出现，并需要测试名和预期 fail 证据。
- disable/reset 条件错误：`disable iff`、reset epoch 或 abort epoch 建模不正确，需要修 SVA 或 waiver。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6A 已确认 bind 所需信号；每条 SVA 已分为 must/debug/future；negative test 与普通功能回归分离。 |
| 交付物 | SVA/bind 文件或 waiver rows；SVA ID 到 bind target/sample source 映射；assertion fail 分类规则；cover property 计划。 |
| 检查命令/证据 | assertion enabled compile 通过；must SVA 有 assertion pass log、fail triage 记录或 waiver。 |
| Pass/fail | `must` SVA 全部 implemented 或 approved waiver；普通功能回归中无未解释 assertion failure；negative assertion test 的 fail 必须与预期一致。 |
| Coverage/SVA/log | assertion report 或 log fallback 必须归档；cover property 未达项进入 6G 或 waiver。 |
| Waiver | Waiver 必须说明 unavailable signal、replacement checker、risk、approval owner；debug/future 不得被静默计为 v1 pass。 |

### Phase 6E：directed 与 negative test 实现

目标：只新增 audit 场景所需测试，不用重复已有 regression 已证明的内容。

候选落点：

- `mmu_verification/testbench/test/l2tlb_tests/`
- `mmu_verification/testbench/test/tlbop_tests/`
- 优先复用已有 virtual sequence，除非 one-off stimulus 更安全。

后续实现的规划输出：

- reset、ReqQ、L2 hit/miss、MB full/retry、PTW disabled miss、PTW fault/access error、PFU MMU-off/on path、TLBOP variants、invalidate variants、multi-hit、abort、timeout/fairness、selected RRPV debug coverage 的 directed tests。
- 非法协议输入和 control hazard assertion/error handling 仅放入 negative tests。
- 每个测试编码前先定义 trigger evidence 和 checker evidence。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6B 已给测试分配 scenario ID；6C/6D 已定义对应 checker 或 assertion；普通功能和 negative test 分组明确。 |
| 交付物 | 新增/复用 test wrapper；scenario ID metadata；trigger evidence 规则；checker evidence 规则；targeted run list。 |
| 检查命令/证据 | smoke 和 targeted L2TLB directed regression 通过；每个新增测试有日志路径和触发证据。 |
| Pass/fail | 测试缺少 trigger evidence 时必须 fail，除非明确标记 debug/waiver；无未解释 UVM_ERROR/UVM_FATAL。 |
| Coverage/SVA/log | 每个测试记录触发点、checker 命中或 assertion/scoreboard pass；coverage 缺口进入 6G。 |
| Waiver | 未触发、不可稳定复现或依赖缺失 probe 的场景必须逐 ID waiver，不能因为 generic vseq pass 而标为完成。 |

### Phase 6F：RRPV 与 replacement 重分类

目标：v1 replacement 检查保持功能/debug 导向，同时保留 future exact-model 入口。

候选落点：

- `l2tlb_tests/` 中已有 RRPV 测试。
- `mmu_l2tlb_rrpv_sva.sv`
- victim、RRPV update 和 wbuf pressure 的 probe/coverage surface。

后续实现的规划输出：

- v1 pass/fail 使用功能可观测行为：refill 后可 hit、invalidate 后 entry 被移除、no overflow、no wrong grant。
- debug coverage 记录 hit promote、aging pressure、full stall、victim observed、bank/index bins。
- future exact items 覆盖 victim way、exact RRPV value、free-way/max-RRPV selection、wbuf latest-wins/merge。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | Phase 4 replacement 边界已确认；exact victim/RRPV 未作为 v1 pass/fail；debug coverage 采样源来自 6A 或 waiver。 |
| 交付物 | v1/debug/future 分类表；RRPV debug coverage plan；future exact item 清单；相关 TP/SVA 状态更新。 |
| 检查命令/证据 | 相关 RRPV/replacement directed 或 debug runs 有日志；v1 功能可见检查通过或 waiver。 |
| Pass/fail | 不允许测试仅因 exact victim 或 exact RRPV 与未实现模型不一致而 fail；no-overflow/no-wrong-grant 仍必须检查或 waiver。 |
| Coverage/SVA/log | Debug coverage 未达不阻塞 v1 closure，但必须记录缺口；future exact coverage 不计入 v1 完成率。 |
| Waiver | Future exact checks 必须显式列为 future 或 waiver，不能静默视为 covered。 |

### Phase 6G：coverage、regression 与最终收口

目标：定义后续实现工作可以关闭所需的证据。

候选落点：

- 现有 covergroup 和 white-box coverage collection。
- 如果现有 bin 不能表达 audit 需求，可新增 L2TLB coverage helper。
- Regression list 和 Makefile target 只能在后续已批准实现阶段修改。

后续实现的规划输出：

- 覆盖关键 source types：ITLB、DTLB load、DTLB store、PFU、PTW refill、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID。
- 覆盖关键 result types：single-hit、miss+MB alloc、MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny、reset/abort。
- Regression tiers：compile、directed smoke、negative assertion、L2TLB targeted、integration/nightly candidate。
- 最终 closure 前记录 coverage threshold 和 waiver 格式。

严格退出门禁：

| 项目 | 准则 |
| --- | --- |
| 进入条件 | 6A~6F 的 planned deliverables 已实现、waive 或移入 future；目标 regression list 已可复现。 |
| 交付物 | Coverage bin mapping；regression tiers；closure checklist；coverage/SVA report 路径；remaining holes/waiver list。 |
| 检查命令/证据 | 至少记录 compile、directed smoke、negative assertion、targeted L2TLB regression 的命令、seed 数、日志路径和结果；integration/nightly candidate 若未执行需说明。 |
| Pass/fail | 目标回归无未解释 UVM_ERROR/UVM_FATAL；P0/P1 gate 全部 pass 或 approved waiver；未完成门禁不得标为 Complete。 |
| Coverage/SVA/log | Coverage threshold 必须在运行前记录；report 不可用时允许 log fallback，但必须记录工具限制和替代证据。 |
| Waiver | 未达 coverage、未触发场景、SVA cover 缺口必须逐项 waiver 或移入具名 future phase；waiver 需要 approver 和风险说明。 |

## 4. 候选交付物矩阵

| 区域 | 现有候选 | 后续实现意图 |
| --- | --- | --- |
| Probe interface | `mmu_dut_probes_if.sv` | 为 L2 final、ReqQ、MB、PTW、TLBOP、PFU、reset/abort、RRPV debug 提供稳定 white-box 观察。 |
| Top wiring | `tb_top.sv` | 连接已批准 probe 和 SVA bind；top 内不放 checker 逻辑。 |
| Translation scoreboard | `mmu_translation_sb.svh` | 负责 transaction-level compare 和 PTW/PFU/L1 final response 归属。 |
| Invalidate scoreboard | `mmu_invalidate_sb.svh` | 若选择该 owner，扩展 invalidate event tracking 到 L2 entry shadow effect。 |
| SVA | `mmu_l2tlb_rrpv_sva.sv` 和可选新文件 | 实现 Phase 3 must/debug SVA 和 cover property。 |
| Directed tests | `l2tlb_tests/`、`tlbop_tests/` | 只有在有明确 TP mapping 和 trigger/checker evidence 时才新增或重标 wrapper。 |
| Package/suite include | `test_pkg.sv`、suite files | 为已批准测试提供 compile-visible wrapper registration。 |
| Coverage | 现有 covergroup 或 L2 helper | 收口 source/result/type bins，不把 debug bins 变成 v1 pass/fail。 |

## 5. 风险与 waiver 规则

| 风险 | 必须处理方式 |
| --- | --- |
| 缺失稳定 probe | 在 Phase 6A 新增 probe，或用替代 checker waiver。 |
| 现有 wrapper 名称造成虚假覆盖 | 标为 covered 前必须有 trigger/checker evidence。 |
| Scoreboard 过度建模微架构 | exact replacement/RRPV/per-cycle arbitration 不进入 v1 pass/fail。 |
| 非法输入污染随机测试 | negative assertion test 必须与普通功能回归分离。 |
| Fault payload mismatch 误报 | 使用 Phase 4 payload ignore rules。 |
| 工具无法生成 coverage report | 只有记录门禁限制和 log fallback evidence 时才能 waiver。 |

## 6. Phase 6/7 文档退出检查表

| 检查 | 状态 |
| --- | --- |
| BuildPlan 已创建 | Complete |
| Progress tracker 已创建 | Complete |
| 后续实现已拆成独立子阶段 | Complete |
| 进入条件禁止隐式代码修改 | Complete |
| 候选 UVM 落点已识别 | Complete |
| v1/debug/future replacement 边界已记录 | Complete |
| 6A~6G 严格退出门禁已补充 | Complete |
| Phase 6/7 本身不修改 UVM/DUT/RTL/Makefile/testbench 行为 | Complete |
