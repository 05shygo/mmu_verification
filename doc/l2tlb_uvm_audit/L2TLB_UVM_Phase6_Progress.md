# L2TLB UVM Phase 6/7 进度

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：L2TLB UVM 后续实现进度与门禁跟踪
> 搭建计划：`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md`
> 规格来源：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 日期：2026-05-21

## 1. 文档阶段状态

Phase 6 只创建并 review 后续实现的规划/进度文档。Phase 7 只把后续实现子阶段的严格退出门禁文档化。两者都不把任何 UVM、DUT/RTL、Makefile、仿真脚本、回归列表或行为代码项标为已实现。

| 项目 | 路径 | 状态 | 说明 |
| --- | --- | --- | --- |
| Phase 6 BuildPlan | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | 已创建/已中文化 | 后续实现蓝图；已补充 6A~6G 严格退出门禁。 |
| Phase 6/7 Progress | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` | 已创建/已中文化 | 后续实现 tracker；已增加门禁和证据记录格式。 |
| UVM/RTL/Makefile/testbench 代码 | N/A | 未修改 | Phase 6/7 都不执行实现。 |
| 后续实现批准 | N/A | 未开始 | 必须由新阶段或新计划打开。 |

## 2. 后续子阶段进度矩阵

状态值：`Not started`（未开始）、`Planned`（已规划）、`In progress`（进行中）、`Blocked`（阻塞）、`Review`（待 review）、`Complete`（完成）、`Waived`（已 waiver）、`Future`（未来阶段）。

| 子阶段 | 标题 | 状态 | Owner | 计划交付物 | 退出准则 | 回归/证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 6A | 可观测性与 monitor 就绪 | Planned | TBD | Probe/monitor inventory；missing-signal decision table；stable consumer list | Compile 通过；无未批准 `$root` fragile path；每个新增 probe 有 consumer 和证据 | TBD |
| 6B | 场景 ID、wrapper 与 metadata 对齐 | Planned | TBD | `L2TLB_TP_001..058` 到 wrapper/checker/waiver/future 的映射 | 每个 P0/P1 测试点有状态、证据路径和 reviewer；不能只凭 wrapper 名称关闭 | TBD |
| 6C | Scoreboard 与 reference model 扩展 | Planned | TBD | L2 entry shadow；PTW/PFU/TLBOP ownership；payload ignore；mismatch taxonomy | Directed 场景有 pass/fail 证据或 waiver；mismatch 必须分类 | TBD |
| 6D | SVA、bind 与 waiver 实现 | Planned | TBD | must/debug SVA 实现计划；bind list；missing-input waiver rows | `must` SVA implemented 或 approved waiver；assertion enabled compile 通过 | TBD |
| 6E | Directed 与 negative tests | Planned | TBD | Directed wrappers；negative assertion tests；trigger/checker evidence | 新测试映射 audit ID；缺少 trigger evidence 必须 fail 或 waiver | TBD |
| 6F | RRPV 与 replacement 重分类 | Planned | TBD | v1/debug/future 分类；RRPV debug coverage plan | v1 不因 exact victim/RRPV 未建模而 fail；future exact items 显式记录 | TBD |
| 6G | Coverage、regression 与 closure gate | Planned | TBD | Coverage bins；regression tiers；closure checklist | 目标回归可复现；coverage/SVA/log 证据归档；剩余缺口 fixed/waived/future | TBD |

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
| `L2TLB_TP_001..058` | TBD | TBD | Planned | TBD | TBD | TBD | Phase 6B/6E/6G 填写。 |

规则：

- 不得因为存在相似名称的 wrapper 就把测试点标为 `Complete`。
- 完整记录必须同时包含 trigger evidence 和 checker/pass-fail evidence。
- Negative assertion-only 项不得混入普通随机功能回归。
- Future replacement/RRPV exact 项必须保持 `Future`，除非批准 exact reference model 阶段。

## 5. SVA 跟踪模板

本表跟踪 `L2TLB_SVA_001..024`。后续实现关闭前必须填具体行。

| SVA ID | 分类 | 状态 | Bind target | Sample source | Assertion evidence | Cover evidence | Waiver / notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `L2TLB_SVA_001..005` | must | Planned | TBD | TBD | TBD | TBD | Implement 或 waive。 |
| `L2TLB_SVA_007..018` | must | Planned | TBD | TBD | TBD | TBD | Implement 或 waive。 |
| `L2TLB_SVA_006` | debug | Planned | TBD | TBD | TBD | TBD | 若 probe 稳定，实现为 debug checker/cover。 |
| `L2TLB_SVA_019..022` | debug | Planned | TBD | TBD | TBD | TBD | 若 probe 稳定，实现为 debug checker/cover。 |
| `L2TLB_SVA_023..024` | future | Future | TBD | TBD | N/A | TBD | Replacement/RRPV exact future items。 |

规则：

- `must` 行必须实现或有已 review waiver。
- `debug` 行只有在写清原因和风险后才能 deferred。
- `future` 行不是 v1 closure blocker。
- Reset 行为和 `disable iff` 策略必须匹配来源需求。

## 6. 证据日志

后续阶段必须记录每次 compile、directed run、negative assertion run、targeted regression、coverage/SVA report。

| 日期 | 子阶段 | 命令 / run | 结果 | Log / report 路径 | 摘要 | 后续动作 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-21 | Phase 6 docs | 文档创建 | Complete | 本文件和 BuildPlan | Phase 6 未运行仿真或改代码 | 后续代码阶段需记录基线。 |
| 2026-05-21 | Phase 7 docs | 退出准则文档化 | Complete | 本文件和 BuildPlan | 6A~6G 严格门禁已写入；未执行实现 | 后续实现阶段按门禁填证据。 |

## 7. Issue 日志

Issue type 值：`RTL bug`、`UVM bug`、`Spec gap`、`Tooling issue`、`Probe gap`、`Regression gap`、`Approved waiver`。

| ID | 日期 | Type | Severity | 相关 TP/SVA | 描述 | Owner | 状态 | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB-P6-ISSUE-001 | 2026-05-21 | Regression gap | Low | Phase 6 | Phase 6 是文档阶段，未运行仿真。 | TBD | Open | 后续已批准实现阶段记录 baseline compile/regression 后关闭。 |

## 8. Waiver 日志

Phase 6/7 不批准任何实现 waiver。后续阶段在把缺失测试/checker/SVA 作为非阻塞项前，必须使用本表。

| Waiver ID | 相关 TP/SVA | 未达门禁 | Reason | Replacement check / evidence | Risk | Approver | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | Not approved |

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
| Evidence、issue、waiver 模板已初始化 | Complete | 后续阶段需逐 run 和逐 exception 填写。 |
| 6A~6G 严格退出门禁已补充 | Complete | 进入条件、交付物、检查证据、pass/fail、coverage/SVA/log 和 waiver 均已定义。 |
| Phase 6/7 不修改 UVM/DUT/RTL/Makefile/testbench 行为 | Complete | 需由 git diff 范围检查确认。 |
| 后续实现批准 | Not started | 必须由新阶段或新计划另行批准。 |
