# L2TLB UVM Audit Consolidated Documentation

This document consolidates the non-protected Markdown documents under `doc/l2tlb_uvm_audit`.

## Source Documents

1. `L2TLB_UVM_Audit_ImplementationPlan.md`
2. `L2TLB_UVM_Phase6_BuildPlan.md`
3. `L2TLB_UVM_Phase6_Progress.md`
4. `progress.md`

## Files Intentionally Not Modified or Merged

- `l2tlb_function_description.md`
- `l2tlb_function_description.txt`
- `L2TLB_TLB_OPERATION_NOTES.txt`
- `L2TLB_TRISTAN_IP_Hardware_tp_V1.xlsx`
- Any `.csv` files

# Part 1: L2TLB UVM Audit Implementation Plan

## L2TLB UVM Audit 分阶段实施计划

> 黄金输入：`doc/l2tlb_uvm_audit/l2tlb_function_description.txt`
> 工作规格：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 进度文档：`doc/l2tlb_uvm_audit/progress.md`
> 日期：2026-05-21

### 1. 总结

本计划用于后续分阶段、逐项把 `l2tlb_function_description.txt` 中的 L2TLB 功能描述整理成 UVM 修改的黄金依据。

当前进度以 `progress.md` 为准：Phase 0~7 已完成，其中 Phase 6 只完成 BuildPlan/Progress 文档创建和规划同步，Phase 7 只完成后续实施退出门禁细化和 Phase 6 文档中文化。不能把本文件中的阶段标题视为已经完成的 UVM/RTL 代码实现或后续代码修改批准。

### 2. 阶段计划

| Phase | 目标 | 当前状态 | 计划交付物 |
| --- | --- | --- | --- |
| Phase 0 | 基线审计与保护 | 已完成 | audit 输入文件、现有目录、已有 UVM 入口的只读盘点记录 |
| Phase 1 | 创建 markdown 工作副本 | 已完成 | `l2tlb_function_description.md` |
| Phase 2 | 根据 `.md` 总结 L2TLB 所有测试点 | 已完成 | 写入 `.md` 的 L2TLB 测试点章节，并创建类似 `doc/l1dtlb_uvm_audit/L1DTLB_TRISTAN_IP_Hardware_tp_V1.xlsx` 的 L2TLB Excel 测试点表 |
| Phase 3 | 补充必要 SVA | 已完成 | 写入 `.md` 的 SVA requirement 章节 |
| Phase 4 | 补充 scoreboard/reference model 建模点 | 已完成 | 写入 `.md` 的 scoreboard/reference model 章节 |
| Phase 5 | 同步到主验证计划 | 已完成 | `MMU_VerificationPlan_final.md` 的 L2TLB audit 同步内容 |
| Phase 6 | 规划创建 Phase 6 BuildPlan/Progress 文档 | 已完成 | `L2TLB_UVM_Phase6_BuildPlan.md` 和 `L2TLB_UVM_Phase6_Progress.md` 已创建；本阶段不修改 UVM、DUT/RTL 或 Makefile |
| Phase 7 | 为 BuildPlan 中规划的后续实施阶段建立严格退出准则 | 已完成 | 已写入 BuildPlan/Progress/本计划/progress 的实施门禁，并将 Phase 6 两份文档中文化 |

#### Phase 0：基线审计与保护（已完成）

目标是建立“后续工作从哪里开始”的事实基线，避免后续阶段误改黄金输入或误判已有 UVM 覆盖。

任务：

- 确认黄金输入文件 `doc/l2tlb_uvm_audit/l2tlb_function_description.txt` 存在，并记录它是只读输入。
- 确认 audit 工作目录 `doc/l2tlb_uvm_audit/` 下已有文件，包括补充 notes、后续计划和 progress 文档。
- 只读盘点现有 UVM L2TLB 相关入口，例如 `l2tlb_tests` wrapper、已有 L2TLB/RRPV SVA、credit scoreboard、probe interface、TLBOP tests。
- 明确当前阶段不修改 RTL、不修改 UVM 行为代码、不修改主验证计划。
- 若发现 `.txt` 在 git 中已经是 modified 状态，只记录现状，不回退、不覆盖、不解释为本阶段产物。

退出准则：

- `l2tlb_function_description.txt` 未被本阶段修改。
- 明确记录 Phase 0 只完成环境和输入盘点。
- progress 中 Phase 0 状态为“已完成”，但不能把任何测试点、SVA、scoreboard 内容标为完成。

#### Phase 1：创建 markdown 工作副本（已完成）

目标是满足用户目标 1：基于 `.txt` 创建同名 `.md` 工作副本，后续所有补充都在 `.md` 中进行。

任务：

- 从 `l2tlb_function_description.txt` 创建 `l2tlb_function_description.md`。
- 初始创建时保持内容一致，不对黄金输入语义做改写、重排或翻译。
- 在计划和 progress 中声明：`.txt` 后续只读，`.md` 是后续补充和修改载体。
- 后续阶段如需添加测试点、SVA、scoreboard 建模点，只能追加或整理到 `.md`。

退出准则：

- `doc/l2tlb_uvm_audit/l2tlb_function_description.md` 存在。
- `.md` 创建动作完成后，Phase 1 可标为“已完成”。
- Phase 1 不代表测试点、SVA、scoreboard 或 UVM 修改已经完成。

#### Phase 2：总结 L2TLB 所有测试点（未开始）

目标是完成用户目标 2：根据 `l2tlb_function_description.md` 提炼 L2TLB 完整测试点，并补充回该 `.md` 文件。

任务：

以下任务是 Phase 2 的最低要求，包括但不限于这些内容。执行 Phase 2 时必须完整分析 `l2tlb_function_description.md`；如果分析后发现还有其他需要补充的测试点、分类、场景或追踪项，也必须一并完成，不能只覆盖下面列出的条目。

- 按功能块从 `.md` 中抽取测试点：ReqQ、arbiter、tag/data/RRPV SRAM、lookup pipeline、miss buffer、PFU、PTW refill、TLB operation、reset、abort、timeout、非法输入。
- 对每个测试点建立唯一 ID，建议格式为 `L2TLB_TP_xxx` 或后续统一命名。
- 每个测试点至少写清：规格来源章节、目标行为、激励入口、可观测结果、需要的 checker、需要的 coverage、优先级、当前 UVM 是否已有入口。
- 区分黑盒功能测试、white-box monitor/coverage、backdoor directed test、负向 assertion test。
- 专门标记 RRPV/victim/wbuf 类测试点：v1 是否只做 debug coverage，还是需要未来 replacement 专项。
- 对现有 `l2tlb_tests` wrapper 做粗映射，但不能因为 wrapper 名称存在就判定测试点已覆盖。
- 把测试点章节补到 `l2tlb_function_description.md`，而不是只写在独立计划中。
- 创建 L2TLB Excel 测试点表，形式参考 `doc/l1dtlb_uvm_audit/L1DTLB_TRISTAN_IP_Hardware_tp_V1.xlsx`，建议命名为 `doc/l2tlb_uvm_audit/L2TLB_TRISTAN_IP_Hardware_tp_V1.xlsx`。
- Excel 表需要与 `.md` 中的测试点 ID 对齐，至少包含测试点 ID、功能域、场景、激励、预期、checker、coverage、优先级、状态、备注等列。

退出准则：

- `.md` 中出现完整测试点章节。
- `doc/l2tlb_uvm_audit/L2TLB_TRISTAN_IP_Hardware_tp_V1.xlsx` 或 review 后确定的等价 Excel 文件存在。
- Excel 表与 `.md` 测试点 ID 一一对应，不允许只维护其中一个。
- 每个测试点都有来源、场景、预期、checker/coverage 和状态。
- 所有关键来源类型至少覆盖：ITLB、DTLB load、DTLB store、PFU、PTW refill、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID。
- 所有关键结果类型至少覆盖：single-hit、miss+MB alloc、MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny、reset/abort。
- progress 只把 Phase 2 标为完成，不得顺带把 Phase 3 及后续标为完成。

#### Phase 3：补充必要 SVA（未开始）

目标是完成用户目标 3：把 L2TLB 必要 SVA 要求补充到 `l2tlb_function_description.md`。

任务：

- 从 Phase 2 测试点和 5.13 UVM 策略中抽取必须用 SVA 锁定的协议和 invariant。
- 对每条 SVA 建立唯一 ID，建议格式为 `L2TLB_SVA_xxx`。
- 每条 SVA 至少写清：检查目标、触发条件、禁止/要求的行为、绑定对象、采样信号、reset disable 条件、是否需要 cover property。
- 分类为 `must`、`debug`、`future`：
  - `must`：影响功能正确性或协议合法性，v1 必须实现或 waiver。
  - `debug`：white-box 调试/覆盖增强，不阻塞 v1 主功能成型。
  - `future`：replacement/RRPV exact 等后续专项。
- 必须考虑 reset、arbiter onehot、ReqQ/MB overflow、PTW completion 合法组合、PTW ID、TLBOP done ordering、abort stale completion、SATP/ASID hazard、no-X。
- 明确非法输入类 SVA 的使用方式：普通功能测试不生成非法输入，负向测试只检查 assertion/error handling。

退出准则：

- `.md` 中出现 SVA requirement 章节。
- 每条 SVA 都能追溯到至少一个测试点或规格风险。
- `must/debug/future` 分类完整。
- SVA 章节只定义需求，不要求本阶段已经写 SystemVerilog 文件。
- progress 只把 Phase 3 标为完成，不得顺带推进 Phase 4 及后续。

#### Phase 4：补充 scoreboard/reference model 建模点（未开始）

目标是完成用户目标 4：把 L2TLB scoreboard 和 reference model 需要建模的点补充到 `l2tlb_function_description.md`。

任务：

以下任务是 Phase 4 的最低要求，包括但不限于这些内容。执行 Phase 4 时必须完整分析 `l2tlb_function_description.md`、Phase 2 测试点和 Phase 3 SVA 需求；如果分析后发现 scoreboard/reference model 还需要额外建模点、比较规则、状态影子或边界说明，也必须一并补充。

- 定义 v1 scoreboard 边界：哪些行为进入 transaction-level pass/fail，哪些只做 white-box monitor/coverage/debug。
- 定义 reference model 需要维护的状态影子：L2 entry shadow、ReqQ shadow、miss buffer shadow、PTW transaction shadow、PFU path shadow、TLBOP shadow、control shadow。
- 写清 L2 direct hit 的比较规则：tag/data/page size/ASID/global/PA payload 检查；不在 L2 层重复做 L1 permission fault 判定。
- 写清 fault/no-pavld 的 payload ignore 规则，避免 fault 场景误比较 VPN/PPN/flag。
- 写清 PFU 三条路径：MMU-off direct、MMU-on L2 hit、MMU-on PTW completion。
- 写清 PTW completion 与 L1/PFU 最终响应的事务归属，避免只在 L2 direct response 端口做局部判断。
- 写清 TLB operation 对模型的影响：TLBWI/TLBWR/TLBP/TLBR/INVVA/INVASID/INVVA_ASID/INVALL 如何更新 shadow 或产生预期。
- 写清 replacement 边界：v1 不预测 exact victim way、exact RRPV value、wbuf latest-wins；只检查功能可见结果和 no-overflow/no-wrong-grant。
- 写清 timeout/fairness 分类：外部 backpressure 与 DUT forward progress 分开报错。

退出准则：

- `.md` 中出现 scoreboard/reference model 建模章节。
- 每个状态影子和比较规则都有明确输入、输出和不检查项。
- 明确列出“不作为 v1 transaction scoreboard pass/fail”的项目。
- 后续 UVM 实现者无需再决定 scoreboard 边界。
- progress 只把 Phase 4 标为完成，不得顺带推进 Phase 5 及后续。

#### Phase 5：同步到主验证计划（已完成）

目标是完成用户目标 5：把 `l2tlb_function_description.md` 中已经 review 的内容同步到 `doc/MMU_VerificationPlan_final.md`。

任务：

- 在主验证计划版本记录中增加 L2TLB audit 同步记录。
- 在 F3 L2TLB/JTLB 章节增加 audit import/override 小节。
- 明确声明：若旧 F3/F5/TLBOP 条目与 L2TLB audit `.md` 冲突，以 audit `.md` 为准，直到旧条目被重写或删除。
- 增加 L2TLB audit artifact 表，列出 `.txt`、`.md`、计划文档、progress 文档和后续检查入口。
- 只同步 Phase 2~4 已 review 的内容，不提前写入未完成的 SVA 或 UVM 实现状态。
- 不重排整份主计划，不删除旧内容，优先采用“新增 override/import 段”的低风险方式。

退出准则：

- `MMU_VerificationPlan_final.md` 包含 L2TLB audit 同步入口。
- 主计划中的链接指向正确文档。
- 主计划没有宣称 UVM 代码已经完成，除非 Phase 6 后有证据。
- Phase 5 完成必须建立在 Phase 2~4 已完成并 review 的基础上。

#### Phase 6：规划创建 Phase 6 BuildPlan/Progress 文档（已完成）

目标是完成用户目标 6 的前置规划：根据 `.md` 中的测试点、SVA、scoreboard/reference model 要求，创建 Phase 6 专用的代码搭建蓝图和进度跟踪文档。Phase 6 本身不修改 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口。

进入 Phase 6 后，只创建并 review 两份 Phase 6 专用文档：

- `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md`
  - 作用类似 `doc/MMU_UVM_BuildPlan_v3_final.md`。
  - 记录后续 L2TLB UVM 实施的代码级蓝图、候选文件清单、实施子阶段、接口/probe/scoreboard/SVA/test/coverage 规划落点。
  - 该文档必须把后续代码实施拆成可独立执行和验证的子阶段，不能只写笼统方向。
  - 该文档只能描述计划、接口意图、风险和门禁，不得伴随实际 UVM 或 DUT 修改。
- `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`
  - 作用类似 `doc/MMU_Progress.md`。
  - 初始化后续实施进度模板，记录计划中的子阶段、状态字段、交付物字段、退出准则字段、回归结果字段、问题记录和 waiver 字段。
  - 该文档在 Phase 6 只记录文档创建和 review 状态，不得把任何 UVM/DUT 代码项标为已实现。

Phase 6 的任务：

- 创建 `L2TLB_UVM_Phase6_BuildPlan.md`，把后续可能的 UVM 实施拆成规划子阶段，例如可观测性、场景 ID/wrapper、scoreboard/reference model、SVA/bind、directed tests、RRPV/replacement 重分类、回归列表和 coverage 收口。
- 创建 `L2TLB_UVM_Phase6_Progress.md`，为上述规划子阶段建立进度表、证据表和 waiver 记录格式。
- 在两份文档中明确后续代码实施的进入条件：必须经过 review，并由新的阶段或新计划批准后才能修改 UVM、DUT/RTL、Makefile 或仿真入口。
- 检查本阶段变更范围，确认只新增或修改文档，不产生 SystemVerilog、Makefile、仿真脚本或 DUT 文件改动。

退出准则：

- `L2TLB_UVM_Phase6_BuildPlan.md` 已创建并 review。
- `L2TLB_UVM_Phase6_Progress.md` 已创建并初始化。
- BuildPlan 已把后续代码实施拆成可独立执行和验证的规划子阶段。
- Progress 已包含后续子阶段状态、交付物、退出准则、回归结果、问题记录和 waiver 的记录格式。
- Phase 6 的 git diff 只包含文档变更，不包含 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口变更。
- progress 明确记录 Phase 6 不修改 UVM/DUT/RTL/Makefile。

#### Phase 7：为 BuildPlan 中规划的后续实施阶段建立严格退出准则（已完成）

目标是完成用户目标 7：给 `L2TLB_UVM_Phase6_BuildPlan.md` 中规划的每一个后续实施阶段设计严格退出准则。

任务：

- 在 Phase 6 BuildPlan 的后续实施子阶段确定后，为每个子阶段写明进入条件、交付物、检查命令、pass/fail 判据、coverage 判据和 waiver 规则。
- 为 scoreboard 子阶段定义 mismatch 分类：RTL bug、UVM bug、spec gap、tooling issue、approved waiver。
- 为 SVA 子阶段定义 assertion fail 处理规则：真 bug、误报、非法输入负向预期、disable 条件错误。
- 为 directed test 子阶段定义“场景已触发”的证据要求，避免只跑 generic vseq。
- 为回归子阶段定义最小 seed 数、log 检查项、coverage threshold、未达项 waiver 格式。
- 把这些退出准则同步写入 `L2TLB_UVM_Phase6_BuildPlan.md`、`L2TLB_UVM_Phase6_Progress.md`、本计划和 `progress.md`。
- 将 `L2TLB_UVM_Phase6_BuildPlan.md` 和 `L2TLB_UVM_Phase6_Progress.md` 改为中文表达；保留路径、ID、命令、UVM/RTL 符号等技术标识。
- 明确 Phase 7 仍是文档阶段，不修改 UVM、DUT/RTL、Makefile、仿真脚本、测试列表或 testbench 行为代码。

退出准则：

- BuildPlan 中规划的每个后续实施子阶段都有明确退出门禁。
- 每个退出门禁都能被日志、coverage、SVA report 或文档 waiver 验证。
- progress 中能逐项记录门禁状态。
- Phase 6 BuildPlan/Progress 两份文档已中文化，且技术 ID、路径和命令未被误翻译。
- Phase 7 的 git diff 只包含文档变更，不包含 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口变更。
- 没有完成门禁的子阶段不得标记为完成。

### 3. 后续工作原则

- Phase 2 及之后必须逐阶段单独完成，不能一次性批量标记完成。
- 每个阶段开始前先读取当前 `.md` 和已有 UVM 现状，再决定当阶段的具体补充内容。
- 每个阶段结束时更新 `progress.md`，只记录该阶段真实完成的内容。
- 测试点、SVA、scoreboard/reference model 内容必须经过逐项 review 后才能从“未开始”改为“已完成”。
- Phase 6 本身不进行 UVM、DUT/RTL、Makefile 或仿真入口修改；任何代码实现必须另起后续阶段并有明确批准。

### 4. 当前明确状态

- Phase 0：已完成。
- Phase 1：已完成。
- Phase 2：已完成。
- Phase 3：已完成。
- Phase 4：已完成。
- Phase 5：已完成。
- Phase 6：已完成，仅创建并 review 规划/进度文档，不修改 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口。
- Phase 7：已完成，仅完成退出门禁文档化和 Phase 6 文档中文化；不修改 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口，也不批准后续代码实现。

# Part 2: L2TLB UVM Phase 6 Build Plan

## L2TLB UVM Phase 6 分阶段实施计划

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：指导 L2TLB UVM 在 probe、monitor、scoreboard、SVA、test、coverage、regression、Makefile/run flow 上分阶段修改补充
> 金标准：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 主进度：`doc/l2tlb_uvm_audit/progress.md`
> 详细 tracker：`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`
> 日期：2026-05-23

### 1. 目的、金标准与实施边界

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

### 2. 统一进入条件、质量原则与记录纪律

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

### 3. UVM 分阶段实施子阶段与严格退出门禁

#### Phase 6A：可观测性与 monitor 就绪

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

##### Phase 6A probe/monitor 实施基线

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

##### Phase 6A missing-signal decision table

| 需求项 | 当前判断 | 后续处理 |
| --- | --- | --- |
| 6C L2 transaction ownership 所需 ReqQ/MB/PTW/PFU 基础输入 | 已有稳定 probe 和 transaction monitor 可组合使用 | 允许进入 6C 设计，但 6C 必须逐场景证明 trigger evidence 和 pass/fail evidence，不能只引用 probe 存在。 |
| L2 entry shadow 的写入/失效可见源 | 目前有 PTW completion、TLBOP/invalidate transaction、L2 final/debug probe；exact array state 未作为 v1 输入 | 6C 建 transaction-level shadow；若需要直接读 tag/data/RRPV array，必须回到 6A 新增 probe 或列为 future/waiver。 |
| L2 final result payload | `l2_final_*` 有 debug 输入，但最终 IFU/LSU/PFU 响应由 agent monitor 采集 | Scoreboard 不应用内部 final probe 替代外部可见结果；内部 final 只用于 root-cause 和 ownership。 |
| PTW fault/no-pavld payload | 有 `ptw_l2tlb_ref_pgflt/acc_err/data_vld` 和 type/id/flg | 6C 对 fault/no-pavld 场景执行 payload-ignore 规则；缺少 page payload 时不能误报 PPN/flag mismatch。 |
| TLBOP reset/abort epoch | 有 `tlboper_ptw_abort`、`ptw_abort_flop`、`rtu_yy_xx_flush` | 6C/6D checker 必须用 epoch gating；未建 epoch 前不得关闭 reset/abort 相关 TP/SVA。 |
| exact replacement victim/RRPV/wbuf | 当前观察面不足以安全做 exact model signoff | 归类为 Phase 6F debug/future；不得作为 v1 pass/fail blocker，也不得静默标为 covered。 |
| 未批准 `$root` checker path | 2026-05-23 检查未在 testbench checker 中发现 `$root` fragile path | 后续新增 checker 只能通过 virtual interface、analysis transaction 或 bind target 取样；例外必须写入 waiver。 |

##### Phase 6A probe consumer list

| Consumer | 消费方式 | 6A 约束 |
| --- | --- | --- |
| `mmu_credit_sb.svh` | 通过 `MMU_DUT_PROBES_VIF` 消费 ReqQ、MB、PTW、PFU、arbiter、L2 final 快照 | 可用于 credit/deadlock/flow diagnostic；新增字段必须有具体 error、coverage 或 evidence 消费点。 |
| `mmu_env_cg_whitebox.svh` | 通过 virtual `mmu_dut_probes_if` 采样 L2/ReqQ/PTW/TLBOP/PFU bins | coverage hit 只能证明观察到 trigger，不能单独证明功能正确。 |
| `ptw_source_monitor.svh` | 通过 `mon_cb` 采集 L2TLB->PTW accept、PTW completion、fault class 和 path metadata | completion 必须按 refill/page-fault/access-fault 分类；OR-only completion 只能作为诊断。 |
| `lsu_monitor.svh` | 通过 probe 补充 CP0/L1D/PFU metadata，并用 agent transaction 输出最终 LSU/PFU 响应 | functional compare 以 transaction 为主，probe 只补 root-cause/waiver 分类。 |
| `mmu_translation_sb.svh` | 已持有 `v_probe` 并采样 PTW/L2/L1 refill、SATP/abort 等上下文 | 6C 扩展时可复用，但新增 L2 checks 必须分类 mismatch，不能把 probe 缺失归为 pass。 |
| `mmu_l2tlb_rrpv_sva.sv` 和相关 bind SVA | 通过 `bind mmu_l2tlb`/`bind mmu_arb` 等模块端口取样 | 属于 6D SVA owner；bind 端口映射必须在 6D 逐 SVA ID 记录，不算 6A 自动完成。 |

##### Phase 6A 实施完成记录要求

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

#### Phase 6B：场景 ID、wrapper 与 metadata 对齐

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

##### Phase 6B wrapper 实施基线

本小节记录 2026-05-23 代码检查得到的当前测试入口。它只说明实施时可复用的候选 wrapper，不代表任何 `L2TLB_TP_xxx` 已经有 trigger evidence 或 pass/fail evidence。

| 区域 | 当前入口 | 6B 判断 |
| --- | --- | --- |
| L2TLB directed/random wrapper | `mmu_verification/testbench/test/l2tlb_tests/`，`l2tlb_tests_suite.svh` include 42 个 wrapper | 已覆盖 ReqQ、MB、tag hit、invalidate、bank conflict、RRPV 等命名入口；多数是 Phase 9 generated wrapper，必须逐项确认实际 vseq、checker 和触发计数。 |
| TLBOP/SFENCE wrapper | `mmu_verification/testbench/test/tlbop_tests/`，`tlbop_tests_suite.svh` include 25 个 wrapper | 可作为 TLBP/TLBR/TLBWI/TLBWR/INV* 候选入口；仍需 L2 entry shadow、TLBOP lifecycle checker 和 reset/abort 交叉证据。 |
| Suite include | `mmu_verification/testbench/test/test_pkg.sv` 已 include `l2tlb_tests_suite.svh` 和 `tlbop_tests_suite.svh` | compile 可见性已存在；本阶段不新增 include、不修改 test list。 |
| Phase 9 metadata | wrapper 内常见 `p9_tc_id`、`p9_seq_desc`、`p9_checker`、`p9_reviewer` | 只能作为候选 metadata；若多个 wrapper 共用通用 vseq 或 checker，不能用 `TC-*` 或 wrapper 名称关闭 audit ID。 |

##### Phase 6B 必须补齐的实现缺口

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

##### Phase 6B metadata contract

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

##### Phase 6B 初始测试点映射

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

##### Phase 6B 实施完成记录要求

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

#### Phase 6C：scoreboard 与 reference model 扩展

目标：实现 Phase 4 定义的 transaction-level L2TLB 模型边界，不建立 cycle-accurate 微架构 scoreboard。

金标准回查与质量规则：6C 实施前必须对照 `l2tlb_function_description.md` 第 8 章和相关 TP 检查 scoreboard/ref-model 需求是否完整。若 testcase 能触发场景但 scoreboard 不能判断 DUT 对错，必须补 checker/ref-model 或记录 blocker；不得用 run pass、credit health 或 debug snapshot 代替功能判错。关键发现、mismatch、UVM/spec/tooling 分类和遗漏项必须先写入 `progress.md`。

候选落点：

- `mmu_verification/testbench/env/mmu_translation_sb.svh`
- `mmu_verification/testbench/env/mmu_invalidate_sb.svh`
- `mmu_verification/testbench/env/mmu_credit_sb.svh`
- `mmu_verification/testbench/env/mmu_ref_model.svh`
- 如果现有 scoreboard 过大，可新增邻近 L2TLB helper class/package。

##### Phase 6C scoreboard/ref-model 实施基线

本小节记录 2026-05-23 对现有 scoreboard/ref-model 的只读检查结论。已有代码提供了可复用基础，但不足以关闭 Phase 4 transaction-level L2TLB scoreboard 边界，也不足以把 Phase6B 的 candidate wrapper 直接升级为 covered。

| 文件 | 当前已有能力 | Phase6C 判断 |
| --- | --- | --- |
| `mmu_translation_sb.svh` | IFU/LSU/PFU 最终响应可调用 `mmu_ref_model.translate()` 比较；已有 PTW request shadow、部分 SATP/abort stale completion 处理、PFU fault/PA compare 和 broad mismatch 计数。 | 可作为最终响应 compare 和 PTW request shadow 的基础；仍缺 L2 entry shadow、TLBWI/TLBWR/PTW refill/INV* 更新规则、完整 ReqQ/MB/PTW/PFU/TLBOP ownership 和统一 mismatch taxonomy。 |
| `mmu_invalidate_sb.svh` | 统计 LSU invalidate、CP0 all-inv done、invalidate kind 和 done count。 | 只能证明事件流被观察；不能证明 L2 entry shadow 被正确 invalidated，也不能关闭 INVVA/INVASID/INVALL/global/non-global 语义。 |
| `mmu_credit_sb.svh` | IFU/LSU/PTW credit conservation、PTW end-drain、L2/PTW/PFU probe snapshot 和 idle health check。 | 可作为 run health、timeout/fairness debug 和 drain evidence；不是 L2TLB functional reference model，不能替代 owner/result compare。 |
| `mmu_ref_model.svh` | 维护 CSR/PMP/SysMap/page-table mirror，提供 Sv39 translate、PFU direct/PMP/SysMap helper。 | 可复用为 page-walk/permission/PFU attribute golden source；`on_tlb_inv()` 仍是 TODO，不具备 L2TLB entry array shadow 和 TLBOP/INV* 语义模型。 |

##### Phase 6C 必须补齐的实现缺口

结论：现有 scoreboard/ref-model 不足以完成 L2TLB 测试点覆盖关闭。现有实现能提供部分 final-response compare、PTW request shadow、credit/drain health 和 debug snapshot，但缺少 Phase 4 要求的 transaction-level L2TLB reference model。因此 Phase6C 必须实现或明确 waiver 下列 scoreboard/ref-model 扩展契约和关闭边界。

必须补齐的内容：

- TLBWI、TLBWR、PTW refill、INV*、reset-inv、abort/reset epoch 的 L2 entry shadow 更新规则。
- 足以归类 L1/PFU 最终响应的 ReqQ/MB/PTW/PFU/TLBOP transaction ownership tracking。
- fault/no-pavld/PFU error 场景的 payload ignore 规则。
- TLB operation 对 shadow state 和 visible result check 的影响。
- mismatch 分类：`RTL bug`、`UVM bug`、`spec gap`、`tooling issue`、`approved waiver`。

##### Phase 6C model contract

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

##### Phase 6C scenario/checker mapping

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

##### Phase 6C 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Scoreboard inventory | 记录 `mmu_translation_sb`、`mmu_invalidate_sb`、`mmu_credit_sb`、`mmu_ref_model` 及新增 helper 的实际能力和缺口。 |
| 金标准覆盖回查 | 记录 Phase 4 scoreboard/ref-model 要求是否全部覆盖，是否发现 BuildPlan 未描述的判错需求。 |
| Model contract | 记录 L2 entry shadow、ReqQ/MB/PTW/PFU/TLBOP ownership、PFU path、TLBOP lifecycle、timeout/fairness 和 mismatch taxonomy 的实现或 waiver 状态。 |
| TP/checker mapping | 记录 `L2TLB_TP_001..058` 分组到 Phase6C checker/ref-model owner 的实现状态和证据。 |
| 运行证据 | 记录 directed L2 hit、miss+PTW、PFU 三路径、TLBOP、INV*、reset/abort、timeout/fairness 的日志或 waiver。 |
| 修改范围 | 记录实际修改的 scoreboard/ref-model/helper/test/run-flow 文件；DUT/RTL 仍需单独同意。 |

##### Phase 6C 实施完成记录（2026-05-23）

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

#### Phase 6D：SVA、bind 与 waiver 实现

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

##### Phase 6D SVA/bind 实施基线

本小节记录 2026-05-23 对现有 SVA 文件、compile list 和 bind 状态的只读检查结论。现有 bind 已提供少量 L2TLB 相关 assertion 基础，但不足以关闭 Phase 3 的 `L2TLB_SVA_001..024` 需求。

| 文件 / bind | 当前已有能力 | Phase6D 判断 |
| --- | --- | --- |
| `mmu_l2tlb_rrpv_sva.sv` bind `mmu_l2tlb` | write bus known；PTW read/write raw-stage sanity；ReqQ multi-hit release；PTW disabled miss release。 | 覆盖 `L2TLB_SVA_014` 的一部分和 `L2TLB_SVA_018` 的一部分；不是完整 RRPV SVA，也不覆盖 reset/ReqQ/MB/PTW/TLBOP/control hazard must set。 |
| `mmu_arb_sva.sv` bind `mmu_arb` | five-source grant onehot/onehot when request；PTW write pipeline reset clear。 | 覆盖 `L2TLB_SVA_005` 的 grant onehot 子项和 `L2TLB_SVA_001` 的局部 reset 子项；仍缺 block isolation、payload no-cross、priority cover、ptw_on/tlboper_on/prefetch_mask debug checks。 |
| `credit_sva.sv` bind `mmu_l2tlb_reqq` | ReqQ issue payload known；credit return bits known。 | 只能作为 `L2TLB_SVA_018` 局部 no-X 和 ReqQ debug；不等价于 `L2TLB_SVA_004/007/008` 的 credit/partition/lifetime 检查。 |
| `tb_top.sv` | 已存在 `bind mmu_arb mmu_arb_sva`、`bind mmu_l2tlb mmu_l2tlb_rrpv_sva`、`bind mmu_l2tlb_reqq credit_sva`。 | L2TLB 相关 bind 编译入口存在；新增 bind 仍需避免脆弱 `$root` path，优先使用模块端口、bind scope 内部信号或 `mmu_dut_probes_if`。 |
| `Files.f` | 已 include `mmu_arb_sva.sv`、`mmu_l2tlb_rrpv_sva.sv`、`credit_sva.sv`。 | assertion file compile list 已有基础；新增 SVA 文件必须同步进入 `Files.f` 并跑 assertion-enabled compile。 |

##### Phase 6D SVA sufficiency conclusion

结论：现有 SVA/bind 不足以完成 Phase 3 `L2TLB_SVA_001..024`。当前实现只覆盖少量局部 property；`must` SVA 大多仍是 missing 或 partial，`debug` SVA 多数未实现，`future` SVA 按 Phase 3 定义继续 deferred。实施时不能因为 `tb_top.sv` 已有 bind 或 `Files.f` 已 include SVA 文件，就把 Phase6D 标为关闭。

本阶段实施输出：

- `must`：`L2TLB_SVA_001..005`、`L2TLB_SVA_007..018` 必须实现或 waive。
- `debug`：`L2TLB_SVA_006`、`L2TLB_SVA_019..022` 在 probe 稳定时应作为 assertion/cover/debug checker 实现。
- `future`：`L2TLB_SVA_023..024` 保持 replacement/RRPV exact future item，除非单独批准 exact model 阶段。
- 每条 assertion 记录 trigger、forbidden behavior、reset disable rule、binding target、sampled signals 和 cover property requirement。

##### Phase 6D SVA implementation/waiver plan

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

##### Phase 6D bind and waiver rules

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

##### Phase 6D 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Phase 3 SVA 来源 | 记录 `l2tlb_function_description.md` 中 `L2TLB_SVA_001..024` 的 must/debug/future 分类和金标准回查结论。 |
| SVA/bind inventory | 记录 `mmu_l2tlb_rrpv_sva.sv`、`mmu_arb_sva.sv`、`credit_sva.sv`、`tb_top.sv`、`Files.f` 及新增 SVA 文件的修改和 bind 状态。 |
| SVA ID 分类 | 每条 SVA 记录 implemented、partial、waived、debug-deferred、future 或 blocked；partial-existing 不能关闭 ID。 |
| Assertion 证据 | 记录 assertion-enabled compile/run 日志、fail triage、negative expected fail 和 cover property 缺口。 |
| Waiver/future | 每条 waiver/future 记录 unavailable signal、替代 checker、质量风险、approver 和后续动作。 |
| 修改范围 | 记录实际修改的 SVA/bind/Files.f/Makefile/run-flow 文件；DUT/RTL 仍需单独同意。 |

#### Phase 6E：directed 与 negative test 实现

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

##### Phase 6E directed/negative test 实施基线

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

##### Phase 6E test sufficiency conclusion

结论：现有 directed/stress/negative-looking test wrapper 不足以完成 L2TLB 测试点覆盖关闭。当前 test pool 足够作为复用基础，但缺少 Phase6E 需要的 per-scenario trigger gate、checker/SVA owner gate、negative test 隔离、targeted run list 和 evidence manifest。

本阶段实施输出：

- reset、ReqQ、L2 hit/miss、MB full/retry、PTW disabled miss、PTW fault/access error、PFU MMU-off/on path、TLBOP variants、invalidate variants、multi-hit、abort、timeout/fairness、selected RRPV debug coverage 的 directed tests。
- 非法协议输入和 control hazard assertion/error handling 仅放入 negative tests。
- 每个测试编码前先定义 trigger evidence 和 checker evidence。

##### Phase 6E directed/negative test plan

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

##### Phase 6E metadata and run-list rules

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

##### Phase 6E 实施完成记录要求

| 检查项 | 必须记录的完成证据 |
| --- | --- |
| Test inventory | 记录 `l2tlb_tests`、`tlbop_tests`、`flush_tests`、`ptw_tests`、`perf_tests`、`err/bug/protocol` suites、可复用 sequence、suite include 和 run list 修改。 |
| 金标准覆盖回查 | 记录 testcase 是否覆盖金标准的功能组合、边界、错误路径和并发场景；不足项写入 `progress.md`。 |
| Directed/negative matrix | 记录 reset、ReqQ、lookup、MB/PTW、PFU、TLBOP、negative、timeout、RRPV 分组的新增/加强内容和关闭条件。 |
| Trigger/checker gate | 每个新增或复用 testcase 记录 scenario ID、related TP/SVA、trigger gate、checker/SVA gate、expected log token 和 positive/negative 分类。 |
| Run 证据 | 记录 smoke、targeted directed、negative、debug RRPV、timeout/fairness 的命令、seed、日志和结果。 |
| 修改范围 | 记录实际新增/修改的 wrapper、vseq、suite include、run list、Makefile target；DUT/RTL 仍需单独同意。 |

#### Phase 6F：RRPV 与 replacement 重分类

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

##### Phase 6F RRPV/replacement 实施基线

| 区域 | 当前入口 / 观察面 | Phase6F 判断 |
| --- | --- | --- |
| RRPV wrapper | `l2tlb_tests/` 下 `test_mmu_dir_rrpv_*` 和 `test_mmu_rand_rrpv_*` 共 14 个 wrapper，suite 已 include | 多数 wrapper 复用 `mmu_rrpv_aging_vseq` 且 `p9_checker=credit_sb`；只能作为 RRPV pressure/debug 候选，不能证明 exact init/aging/victim/wbuf 行为。 |
| TLBWR/RRPV wrapper | `tlbop_tests/test_mmu_tlbwr_rrpv_policy.svh` | 复用 `cp0_tlbwr_seq + mmu_smoke_vseq` 和 `invalidation_sb`；v1 只能检查 TLBWR 后功能可见结果，不比较 replacement victim。 |
| Perf/bug wrapper | `perf_tests/test_rrpv_aging_replacement.svh`、`bug_hunt_tests/test_bug_007_rrpv_post_inv.svh` | 可作为 pressure 或 post-invalidate debug 候选；没有独立 trigger/checker evidence 时不能关闭 `L2TLB_TP_045..047`。 |
| SVA/bind | `mmu_l2tlb_rrpv_sva.sv` 已 bind 到 `mmu_l2tlb` | 当前只检查 write bus known、PTW read/write staging、multi-hit/PTW-disabled release 等局部项；缺 `L2TLB_SVA_022` wbuf no-overflow/no-wrong-grant，`L2TLB_SVA_023/024` 保持 future。 |
| Probe/coverage | `mmu_dut_probes_if.sv` 暴露 `l2_bank0`、`l2_final_way_hit`、`l2_raw_pre_pgs0`；`mmu_env_cg_whitebox.svh` 有 `cg_l2tlb_bank` | 可覆盖 bank/way/page-size debug bins；没有 wbuf push/pop/full/count、victim_way、exact RRPV value 的稳定 coverage surface。 |
| RTL microarchitecture | `mmu_l2tlb_replacement_policy.sv`、`mmu_l2tlb_rrpv_wbuf.sv`、`mmu_l2tlb.sv` | RTL 中存在 victim、RRPV update、wbuf full/bypass/latest-wins 逻辑；本计划不默认授权 RTL 修改，也不把内部规则直接转成 v1 scoreboard oracle。 |

##### Phase 6F v1/debug/future 分类表

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

##### Phase 6F debug coverage plan

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

##### Phase 6F future exact item list

以下项目必须显式保持 `Future` 或 approved waiver；不能因为 RRPV wrapper 存在、`credit_sb` 通过、或 white-box bank/way cover 命中而标为 covered。

| Future item | 相关 ID | 升级前置条件 | 最低证据要求 |
| --- | --- | --- | --- |
| Exact victim/free-way/max-RRPV model | `L2TLB_TP_047`, `L2TLB_SVA_023` | 独立批准 replacement exact-model 阶段；定义 hash/index、mask_way、entry_vld、entry_rrpv、tie-break、PTW/TLBWR timing。 | cycle-accurate reference model + assertion/scoreboard log + directed victim tests。 |
| Exact RRPV value after hit/miss/refill/write | `L2TLB_TP_045..046` | 稳定 RRPV SRAM/wbuf sampling；定义 valid-entry mask、invalid entry ignore、TLBOP 是否 aging。 | per-event expected/observed RRPV dump + mismatch taxonomy。 |
| Wbuf latest-wins/CAM merge | `L2TLB_TP_046`, `L2TLB_SVA_024` | 暴露或 bind `push_req/push_idx/push_vld/push_data/count/rd_ptr/wr_ptr` 等采样源；定义同 bank/index 多 pending 优先级。 | same-bank/index directed + latest-wins assertion pass。 |
| Same-cycle push bypass | `L2TLB_TP_046`, `L2TLB_SVA_024` | 明确同周期组合采样点和 lookup_req 时序；避免 delta-cycle 误采样。 | same-cycle push+lookup cover + merged value compare。 |
| PTW write / TLBOP write 与 pending wbuf 冲突规则 | `L2TLB_TP_045..047` | 明确 pending RRPV 是否 invalidate、merge 或允许 stale drain；定义功能可见风险。 | directed conflict tests + exact RRPV model evidence。 |

##### Phase 6F run-list and metadata rules

- `l2tlb_debug_rrpv` run list 只允许关闭 debug coverage、`L2TLB_SVA_022` debug assertion 和 functional-visible replacement checks；不得关闭 `L2TLB_SVA_023/024`。
- RRPV wrapper 必须增加或外部记录 `phase6f_class`，取值只能是 `v1_functional_visible`、`debug_coverage`、`debug_assertion`、`future_exact_model`。
- wrapper 名称包含 `victim_selection`、`init_value`、`hit_promote_to_zero`、`aging_saturation` 时，若没有 exact RRPV model，只能按 debug/future 分类；测试通过不能证明名称中的 exact rule。
- `credit_sb`、`invalidation_sb` 或 generic vseq pass 只能作为 health evidence，不能作为 RRPV/replacement closure evidence。
- `L2TLB_TP_047` 在 v1 只能由 visible legal result 关闭；exact victim coverage 保持 future。
- `L2TLB_SVA_022` 若实现，必须独立记录 assertion-enabled compile/run evidence；若不实现，作为 debug missing/waiver 进入 Progress。
- `L2TLB_SVA_023/024` 固定为 future，直到启动独立 exact-model 阶段。

##### Phase 6F 实施完成记录要求

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

##### Phase 6F 实施完成记录（2026-05-23）

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

#### Phase 6G：coverage、regression 与最终收口

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

##### Phase 6G 实施完成记录要求

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

##### Phase 6G 实施完成记录（2026-05-23）

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

##### Phase 6G Open Closure Plan（2026-05-23）

以下计划用于承接 Phase6G default closure gate 通过后的剩余深度验证工作。关闭顺序必须以提高 DUT 验证质量为准；任何条目在没有 trigger、checker/SVA、coverage 或 approved waiver/future 证据前，不得因为 wrapper 名称、generic regression pass、`UVM_ERROR=0`、总 coverage 或历史日志而标记为完成。

| 优先级 | 计划项 / 相关 ID | 当前状态 | DUT 验证风险 | 必须实现的动作 | 退出标准 |
| --- | --- | --- | --- | --- | --- |
| P0 | Timeout/fairness root-cause：`L2TLB_TP_049..050`、`L2TLB-P6-ISSUE-013`、`P6G_TIMEOUT_FAIRNESS_CLOSURE` | Closed；seed 64001 已 `UVM_ERROR=0`、shadow mismatch=0 | 初始失败来自 testbench 过严/滞后判断：PFU flag-only 诊断位参与 PA payload compare、L1DTLB MB CAM 只看上一拍 shadow、ReqQ SVA 不允许合法 back-to-back DTLB request | 已实现 PFU payload-ignore classifier、MB current-window classifier、DTLB back-to-back ReqQ SVA policy；manifest row 更新为 closure | Targeted timeout/fairness seed 64001 clean；`activity=544 pfu=52 payload_ignore=52`；`c_d_req_back_to_back_valid=2`；无未解释 UVM_ERROR/UVM_FATAL 或 bad log pattern |
| P0 | TLBOP/INV/abort lifecycle：`L2TLB_TP_034..044`、`L2TLB_SVA_015..016`、`L2TLB-P6-ISSUE-015`、`P6E_TLBOP_INV_ABORT` | Closed；seed 64001 已无 `failed at` | TLBP/TLBR/TLBWI/TLBWR/INV/abort 的 request/grant/done、epoch、payload side-effect 可能被错误关闭 | 已 root-cause：`mbuf_entry_on` 是 entry lifecycle marker，会在合法 TLBOP abort clear 中改变；SVA 改为 accept/response/abort lifecycle event，并新增 abort-entry-clear cover | TLBOP/INV/abort directed row 有 trigger + lifecycle checker/SVA pass；`UVM_ERROR=0`、bad-pattern scan clean、`cp_lsu_abort_entry_clear=6` |
| P0 | PTW disabled/fault/access-error source-specific harness：`L2TLB_TP_018`、`025`、`026`、`033`、`L2TLB_SVA_012`、`014` | Closed；`P6E_PTW_SOURCE_FAULT_CLOSURE` seed 64001 | 原风险是 PTW disabled、page fault、access error 和 PFU error payload 只被粗粒度日志覆盖，未证明 source-specific final response 和 Phase4 payload-ignore 规则正确 | 已新增 directed positive harness，区分 ITLB/DTLB load/DTLB store/PFU；shadow 记录 final response classifier、disabled terminal classifier、payload-ignore evidence；`L2TLB-WAIVE-P6E-001` 已被 closure row supersede | Manifest `closure` row 要求 12 个 source/result counter 全部 >0、`payload_ignore>0`、`mismatch=0`、`waived_future=0`、`UVM_ERROR/FATAL=0`；更新后 targeted list 5/5 pass，该 row 纳入最终 closure scanner PASS |
| P0 | Negative injector：bad PTW completion、illegal input、OOO、control hazard；`L2TLB_TP_027`、`048`、`056`、`058`、`L2TLB_SVA_012`、`013`、`017`、`018`、`L2TLB-WAIVE-P6E-002` | Closed；legacy OOO wrapper 仍 obsolete，不用于 normal coverage | 非法输入或协议违例可能混入 normal functional coverage，或者 expected assertion/error 没有被正确分类 | 已建立独立 negative suite；注入 no-outstanding completion、bad ID/type、illegal result combo 和 outstanding control hazard；normal list 与 negative list 分离；expected shadow mismatch 在 negative window 内分类为预期负向事件 | Negative manifest rows `P6E_NEG_PROTOCOL_SUITE`、`P6E_NEG_PTW_NO_OUTSTANDING`、`P6E_NEG_PTW_BAD_ID_TYPE`、`P6E_NEG_PTW_ILLEGAL_COMBO`、`P6E_NEG_CONTROL_HAZARD` 均 PASS；aggregate seed 66001 `trigger_count=4 checker_count=4 waiver_count=0 future_or_waiver=0 UVM_ERROR=0 UVM_FATAL=0`；normal functional regression 不依赖 negative fail |
| P1 | TLBP/TLBR/TLBWI/TLBWR exact decode/readback：`L2TLB_TP_034..037`、Phase6C remaining hole | Closed after RTL owner/user bank-mask fix | CP0/TLBOP path 可能只验证到 wrapper 运行，未证明 transaction decode、readback data、entry shadow side-effect 正确；hash/index/bank 若只做 debug cover，会遗漏 selector/page-size bank mask bug | 已新增 CP0 TLBOP exact sequences 和共享 L2TLB hash/skew/page-size/bank-mask golden model；`mmu_arb_sva` 对 idx/size/bank 做 exact compare 并把 mismatch 升级为 UVM error；bank mask golden model 由 2.3 arbiter 的 per-bank pre page size 表派生，不再维护重复硬编码 mask 表；`test_arb_skew_index_generation` directed 覆盖 selector 00/01/10/11。RTL owner/user 已将 `mmu_arb.sv` `mask_bank_sel` 常量修为显式 `8'b...` | 8 个 exact TLBOP wrapper seeds 65034..65041 全部 `UVM_ERROR=0`、`UVM_FATAL=0`；hash directed seed 66001 复跑 `UVM_ERROR=0`、无 `L2TLB_HASH_FAIL`、translation SB `mismatch=0`，selector 00/01/10/11 cover 为 787/18/19/12，`tlbop_idx_not_va=768`；manifest scanner P1 rows PASS |
| P1 | ReqQ/arbiter/ownership fine-grain closure：`L2TLB_TP_004..011`、`019..024`、`051..055`、`L2TLB_SVA_003..006`、`019..020`、`L2TLB-P6-ISSUE-017/031` | Closed；`P1_REQQ_ARB_FINE_CLOSURE` seed 64001 | payload no-cross baseline 已有，但 source ownership、ptw_on/tlboper_on stall-release、pairwise/four-source conflict 曾未被完整精确覆盖；现有 `mmu_l2tlb_bank_conflict_vseq` 是串行 LSU load，不能代表 multi-source conflict | 已把 coarse row 收紧到 `L2TLB_REQQ_FINE`/`L2TLB_ARB_FINE` counter，并用 targeted CP0 TLBP phase-aligned overlap 关闭 four-source、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、triple conflict、ptw_on/tlboper_on block 和 PFU mask release；closure row 还要求 clean UVM summary 与 Phase6C L2 shadow `orphan=0/mismatch=0` | 每个 arbiter/flow-control bin 有 trigger + checker/SVA evidence；default closure scanner 无 blocked row；无 owner 丢失或 payload cross；未达 exact RRPV/wbuf 项继续进入 approved waiver/future |
| P1 | PFU source/truth-table closure：`L2TLB_TP_028..033`、`053`、`057`、`L2TLB_SVA_021` | ✅ Closed (2026-05-24) | PFU source-specific directed runs 已完成，PFU fault/error payload ignore 规则已绑定 | 已完成 | PFU source/result/truth-table bins 已命中 |
| P1 | RRPV/replacement exact model 与 WBUF：`L2TLB_TP_045..047`、`L2TLB_SVA_022..024` | ✅ Closed (2026-06-06) | RRPV exact model runtime-verified: victim_mismatch=0, rrpv_way_mismatch=0；cover holes 已 waiver | 已完成 | exact model 已通过 4 个 smoke test |
| P1 | Coverage/URG/report threshold 与 integration/nightly closure：`L2TLB_TP_050`、Phase6G coverage/checklist | ✅ Closed (2026-05-24) | Phase6G manifest/scanner/closure report 已建立 | 已完成 | default gate PASS=26 OPEN=0 |
| P1 | Waiver/future approval closure：所有 `L2TLB-WAIVE-*`、future exact rows | ✅ Closed (2026-06-06) | 所有 waiver/future 已在 progress.md 中闭合：cover holes → waiver (equivalent assertion)；RRPV exact → implemented；P1 fine-grain → Superseded；L1DTLB → Out of scope | 已完成 | 0 Open 项；所有 risk 已 accept 或有替代证据 |

执行约束：

- 任何修复或新增测试都必须同步更新 `simu/l2tlb_phase6g_evidence_manifest.tsv`、closure report、`progress.md` 和相关 run list。
- 若 root-cause 指向 DUT/RTL bug，先记录 issue、最小复现、期望/实际行为和质量风险；DUT/RTL 修改仍需明确同意。
- 若发现 BuildPlan 仍漏掉金标准要求，以 `l2tlb_function_description.md` 为准补计划、测试、checker/SVA、coverage 或 waiver/future，不能为了关闭表格降低验证严格度。

### 4. 候选交付物矩阵

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

### 5. 风险与 waiver 规则

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

### 6. Phase 6 实施退出检查表

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

# Part 3: L2TLB UVM Phase 6/7 Progress

## L2TLB UVM Phase 6/7 进度

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：L2TLB UVM 后续实现进度与门禁跟踪
> 搭建计划：`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md`
> 规格来源：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 日期：2026-05-23

### 1. 文档阶段状态

Phase 6/7 最初只创建并 review 后续实现的规划/进度文档。2026-05-23 已按 BuildPlan 完成 Phase6C scoreboard/helper core implementation、Phase6D SVA/bind implementation、Phase6E directed/negative implementation、Phase6F RRPV/wbuf debug implementation 和 Phase6G closure infrastructure implementation。Phase6G default manifest/scanner gate 已 PASS：timeout/fairness、TLBOP/PTW LSU protocol、PTW source-specific harness、isolated negative injector、P1 TLBOP/hash exact rows 和 P1 ReqQ/arbiter/ownership fine-grain row 均已关闭；exact RRPV/wbuf 项仍作为 future/waiver follow-up，不误标为已实现 exact-model 功能覆盖。

| 项目 | 路径 | 状态 | 说明 |
| --- | --- | --- | --- |
| Phase 6 BuildPlan | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | 已创建/已中文化 | 后续实现蓝图；已补充 6A~6G 严格退出门禁。 |
| Phase 6/7 Progress | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` | 已创建/已中文化 | 后续实现 tracker；已增加门禁和证据记录格式；Phase 6C/6D/6E/6F/6G 已更新为 implementation complete。 |
| Phase 6B progress record | 本文件第 2、4、6、7、9 节 | Complete-doc | 已记录 6B wrapper/metadata 对齐进度、逐组 TP 状态、scenario ID baseline、证据行和 wrapper 名称不可作为关闭证据的 issue。 |
| Phase 6C progress record | 本文件第 2、4.3、6、7、9 节 | Complete | 已记录 6C scoreboard/ref-model inventory、模型契约、TP/checker 分组映射、实现文件、运行证据和剩余 closure 边界。 |
| Phase 6D progress record | 本文件第 2、5、6、7、8、9 节 | Complete | 已记录 6D SVA/bind 实现、`L2TLB_SVA_001..024` 逐条 implemented/deferred/future 状态、assertion-enabled evidence、cover hole、scope waiver/future 和剩余 closure issue。 |
| Phase 6E progress record | 本文件第 2、4.4、6、7、8、9 节 | Complete | 已实现 6E base/suite/wrappers/run lists、shadow-delta trigger gate、directed/negative/debug evidence；timeout/fairness targeted stress、PTW source-specific harness 和 isolated negative injector 已 root-caused/关闭，RRPV exact 仍为 future。 |
| Phase 6F progress record | 本文件第 2、4.5、5、6、7、8、9 节 | Complete | 已实现并记录 6F RRPV wbuf debug SVA/bind、`phase6f_class` metadata、debug run list、targeted run evidence、cover hit/hole 和 exact replacement/RRPV future 边界。 |
| Phase 6G progress record | 本文件第 2、4.6、6、7、9 节 | Complete with scoped future | 已实现并记录 6G L2TLB-specific run list、evidence manifest、closure scanner、replay flow、closure report、root-cause closure、P1 exact/hash closure、P1 ReqQ/arbiter fine-grain closure 和 default PASS gate；waiver/future rows 保留后续风险边界。 |
| UVM/RTL/Makefile/testbench 代码 | Phase6C UVM scoreboard/helper；Phase6D SVA/bind；Phase6E directed/negative tests；Phase6F RRPV wbuf/arbiter debug SVA/metadata/run-list；Phase6G run-list/manifest/script closure flow；P1 TLBOP/hash exact model | 已修改 | 已新增 Phase6C `mmu_l2tlb_txn_shadow`；Phase6D 扩展 `mmu_arb_sva`、`credit_sva`、`mmu_l2tlb_rrpv_sva`，新增 `mmu_l2tlb_mb_sva`；Phase6E 新增 `l2tlb_phase6e_*` base/suite/wrappers/run lists 并接入 `test_pkg.sv`；Phase6F 新增 `mmu_l2tlb_rrpv_wbuf_sva`、参数化 bind、arbiter wbuf-full no-wrong-grant/PTW-writeback guard、coverage exclude、debug list 和 metadata；Phase6G 新增 `l2tlb_phase6g_*` run lists、manifest、scanner 和 replay scripts；P1 新增 CP0 TLBOP exact sequences、共享 L2TLB hash/skew/page-size/bank-mask golden model 和 hash exact SVA。RTL `mmu_arb.sv` bank mask 常量由 RTL owner/user 修复为显式 `8'b...`。 |
| 后续实现批准 | Phase6C/6D/6E/6F/6G/P1 exact/fine-grain | 已完成 core/infrastructure/debug/closure-tool/exact-model/fine-grain implementation | Phase6G default scanner 应为 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26`；剩余 RRPV exact/wbuf full 项保持 future/waiver follow-up。 |

### 2. 后续子阶段进度矩阵

状态值：`Not started`（未开始）、`Planned`（已规划）、`In progress`（进行中）、`Blocked`（阻塞）、`Review`（待 review）、`Complete-doc`（文档交付完成，未声明行为实现完成）、`Implemented-open`（实现已落地但仍有未关闭质量问题）、`Complete`（实现和证据完成）、`Waived`（已 waiver）、`Future`（未来阶段）。

| 子阶段 | 标题 | 状态 | Owner | 计划交付物 | 退出准则 | 回归/证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 6A | 可观测性与 monitor 就绪 | Complete | TBD | Probe/monitor inventory；missing-signal decision table；stable consumer list 已补入 BuildPlan；本轮未新增或改动 probe/RTL/UVM 行为 | `make comp` 通过；未发现未批准 `$root` checker path；现有 L2/ReqQ/MB/PTW/PFU/TLBOP probe consumer 已记录；future/debug 项未误标为 covered | `mmu_verification/output/logs/comp_all.log` |
| 6B | 场景 ID、wrapper 与 metadata 对齐 | Complete-doc | TBD | `L2TLB_TP_001..058` 初始映射、scenario ID baseline、wrapper inventory、metadata contract 和 test-case sufficiency 结论已补入 BuildPlan/Progress；本轮未新增或修改 wrapper/include/仿真列表 | 每个测试点已有稳定 `L2TLB_SCN_*`、wrapper class、candidate/new-wrapper/checker 状态；明确现有 test case 不足以完成覆盖关闭，wrapper 名称不能作为关闭证据 | `L2TLB_UVM_Phase6_BuildPlan.md` Phase 6B；本文件第 4 节 scenario registry；第 4.2 节 sufficiency gap；Phase6B 文档检查命令 |
| 6C | Scoreboard 与 reference model 扩展 | Complete | TBD | 已新增 `mmu_l2tlb_txn_shadow` 并接入 env、translation/invalidate scoreboard 和 PFU monitor path；覆盖 PTW refill shadow、L2 final 可见比较、INV*/CP0 all-inv、reset/abort/control epoch、PFU classifier、payload-ignore 和 mismatch taxonomy | `make comp_fast`、tag/refill directed smoke 和 PFU payload-ignore smoke 均通过；Phase6C 不声明完整 TP coverage closure，剩余 TLBOP exact decode、ReqQ payload no-cross、完整 MB/OOO、timeout/fairness 和 RRPV exact model 继续 open | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；本文件第 4.3/6/7 节 |
| 6D | SVA、bind 与 waiver 实现 | Complete | TBD | 已扩展 `mmu_arb_sva`、`credit_sva`、`mmu_l2tlb_rrpv_sva`，新增并 bind/include `mmu_l2tlb_mb_sva`；已记录 `L2TLB_SVA_001..024` implemented/deferred/future 状态、scope waiver/future 和 cover hole | `make comp_fast` 通过；四条 assertion-enabled smoke 通过；must SVA 的稳定 bind 子项已有 pass evidence；未实现或未触发项已进入 6E/6F/6G 或 future/waiver 跟踪 | `mmu_verification/output/logs/comp_fast.log`；`test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`test_pipe2_prefetch_err_63003.log`；`test_mmu_dir_l2tlb_inv_all_63002.log`；`test_mmu_rand_l2tlb_bank_conflict_multi_source_63004.log`；本文件第 5/6/7/8 节 |
| 6E | Directed 与 negative tests | Complete | TBD | 已新增 `l2tlb_phase6e_test_base.svh`、`l2tlb_phase6e_tests.svh`、`l2tlb_phase6e_suite.svh`、5 个 targeted run list，并接入 `test_pkg.sv`；positive/debug trigger 基于 Phase6C L2TLB shadow delta；negative injector 独立于 normal directed list | `make comp_fast` 通过；directed P0、negative injector、RRPV debug 通过；timeout/fairness targeted stress 已 root-caused 并复跑 clean | `mmu_verification/output/logs/comp_fast.log`；`test_l2tlb_p6e_*_64001.log`；`test_l2tlb_p6e_*_66001.log`；本文件第 4.4/6/7/8 节 |
| 6F | RRPV 与 replacement 重分类 | Complete | TBD | 已新增 `mmu_l2tlb_rrpv_wbuf_sva`、参数化 bind、arbiter wbuf-full no-wrong-grant/PTW-writeback guard、compile list/coverage exclude、`phase6f_class` metadata 和 `simu/l2tlb_phase6f_debug_rrpv_list`；保留 v1/debug/future 分类 | `make comp_fast` 通过；Phase6F targeted run seed 65001 通过；`L2TLB_SVA_022` debug no-overflow/no-underflow/accounting/no-wrong-grant 基线有 assertion-enabled evidence；exact victim/RRPV/latest-wins 不进 v1 closure，未命中 debug cover 转 6G | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；本文件第 4.5/5/6/7/8 节 |
| 6G | Coverage、regression 与 closure gate | Complete with scoped future | TBD | 已新增 `simu/l2tlb_phase6g_*` run lists、`l2tlb_phase6g_evidence_manifest.tsv`、`scripts/l2tlb_phase6g_closure.py` 和 `scripts/l2tlb_phase6g_replay.py`；closure report flow 已可复现；P1 TLBOP/hash exact rows 和 `P1_REQQ_ARB_FINE_CLOSURE` 已纳入 manifest | Scanner 能逐 row 检查 required report/counter/cover、UVM summary、bad log pattern 和 issue/waiver/future linkage；default gate 无 blocked row，应 PASS | `mmu_verification/output/regression/l2tlb_phase6g_closure/closure_report.md`；manifest；smoke 3/3、targeted 更新后 5/5、negative 1/1、debug 1/1；8 个 P1 exact TLBOP wrapper seeds 65034..65041；hash directed seed 66001；ReqQ/arbiter fine-grain seed 64001；当前 default scanner 应显示 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26` |

#### Phase 6B 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6B 子阶段状态 | Complete-doc | 第 2 节 6B row | 仅表示文档交付完成；不声明 wrapper、checker、coverage 或 regression 已实现关闭。 |
| `L2TLB_TP_001..058` 初始进度 | Complete-doc | 第 4 节测试点跟踪表和 scenario registry | 58 个 TP 已按 reset/ReqQ/tag/PTW/PFU/TLBOP/RRPV/negative/closure 分组记录状态、稳定 scenario ID 和后续证据要求。 |
| wrapper inventory 风险 | Closed-doc | 第 7 节 `L2TLB-P6-ISSUE-004` | 已明确现有 `l2tlb_tests/`、`tlbop_tests/` wrapper 和 Phase9 `TC-*` metadata 只能作为候选入口，不能作为关闭证据。 |
| test case 充分性结论 | Complete-doc | 第 4.2 节；第 7 节 `L2TLB-P6-ISSUE-005` | 已明确现有 test case 不足以完成 `L2TLB_TP_001..058` 覆盖关闭，并列出必须新增/加强的 wrapper、checker、SVA、negative suite 和 coverage closure 内容。 |
| evidence 留痕 | Complete-doc | 第 6 节 Phase 6B docs row | 已记录 Phase6B 使用的只读检查命令；本轮未运行仿真、未修改行为代码。 |
| 后续执行入口 | Planned | 第 4 节和 BuildPlan Phase 6B | 6C/6D/6E/6G 必须补 trigger evidence、checker/SVA evidence、run log、coverage report 或 waiver。 |

#### Phase 6C 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6C 子阶段状态 | Complete | 第 2 节 6C row；第 6 节 Phase 6C implementation row | 已实现核心 scoreboard/helper 并记录 compile/smoke evidence；不声明 UVM 功能 coverage 全关闭。 |
| 当前 scoreboard/ref-model inventory | Complete | 第 4.3 节；BuildPlan Phase 6C | `mmu_l2tlb_txn_shadow` 作为邻近 helper 接入 `mmu_translation_sb`、`mmu_invalidate_sb` 和 env config_db；`mmu_credit_sb`/`mmu_ref_model` 的剩余边界仍按 baseline 记录。 |
| coverage sufficiency 结论 | Complete | 第 4.3 节；第 7 节 `L2TLB-P6-ISSUE-006`/`011` | Phase6C core helper 足以提供 PTW refill、PFU payload-ignore、INV/epoch 和可见 L2 hit compare 的 evidence sink；完整 TP closure 仍需后续 directed/SVA/coverage。 |
| model contract | Complete | 第 4.3 节；BuildPlan Phase 6C | 已实现 L2 entry shadow v1、PTW/PFU owner path、payload-ignore、epoch 和 mismatch taxonomy；ReqQ/arbiter payload no-cross、full MB/OOO、timeout/fairness 和 exact TLBOP read/write decode 保持 follow-up。 |
| TP/checker 映射 | Complete | 第 4.3 节 | 已把 Phase6B TP/scenario 组映射为 Phase6C core implemented、SVA/direct follow-up 或 debug/future；不把 helper smoke 误计为 58 个 TP 全覆盖。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6C implementation row | 已记录 `git diff --check`、`make comp_fast`、tag/refill smoke、PFU payload-ignore smoke、INVALL seed 63002 smoke、summary counters 和 log status。 |

#### Phase 6D 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6D 子阶段状态 | Complete | 第 2 节 6D row；第 6 节 Phase 6D implementation row | 已实现稳定 bind SVA 并记录 assertion-enabled compile/smoke evidence；不声明所有 cover 或 TP closure 全关闭。 |
| Phase 3 SVA 来源 | Complete | 第 5 节；BuildPlan Phase 6D | 已以 `l2tlb_function_description.md` 第 7 章 `L2TLB_SVA_001..024` 为来源，并逐条标注 implemented/deferred/future。 |
| 当前 SVA/bind inventory | Complete | 第 5.1 节；第 6 节 Phase 6D implementation row | 已检查并修改 `mmu_l2tlb_rrpv_sva.sv`、`mmu_arb_sva.sv`、`credit_sva.sv`，新增 `mmu_l2tlb_mb_sva.sv`，同步 `tb_top.sv` bind、`Files.f` include 和 `cov_hier.cfg`。 |
| must/debug/future 状态 | Complete | 第 5.2 节 | 已逐条记录 24 个 SVA 的 implemented/deferred/future 状态、bind/sample source、assertion evidence、cover evidence 和 waiver/future。 |
| sufficiency 结论 | Complete with scoped gaps | 第 5.1/5.2 节；第 7 节 `L2TLB-P6-ISSUE-012` | 稳定 bind 子项已实现；full reset-inv、TLBOP lifecycle 和 control hazard 已由后续 directed/negative evidence 补证据；RRPV wbuf/exact replacement 仍需后续 debug/future closure。 |
| waiver/bind 规则 | Complete | 第 5.3 节；第 8 节 waiver/future rows | 已记录 `must` SVA 的关闭状态、scope waiver/future 和后续 owner；debug/future 不误计 v1 must closure。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6D docs/implementation rows | 已记录只读检查、`make comp_fast`、四条 smoke、cover hits、未命中 cover 和 log status。 |

#### Phase 6E 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6E 子阶段状态 | Complete | 第 2 节 6E row | Phase6E directed/negative infrastructure 已实现；timeout/fairness targeted stress、PTW source-specific harness 和 isolated negative injector 已关闭；RRPV exact 仍不声明完整 coverage closure。 |
| 当前 test inventory | Complete | 第 4.4 节；BuildPlan Phase 6E | 已检查 `l2tlb_tests`、`tlbop_tests`、`flush_tests`、`ptw_tests`、`perf_tests`、`err_tests`、`bug_hunt_tests`、`ptw_lsu_protocol_tests` 和可复用 sequence，并据此新增 Phase6E wrappers/run lists。 |
| sufficiency 结论 | Closed with exact-model future | 第 4.4 节；第 7 节 `L2TLB-P6-ISSUE-008` | 已补 directed P0、PTW disabled/fault/access-error source-specific closure、isolated negative injector、RRPV debug、strict trigger gate 和 timeout/fairness root-cause closure；剩余 exact RRPV/wbuf 为 future。 |
| directed/negative matrix | Complete | 第 4.4 节；第 6 节 Phase 6E implementation row | Reset/ReqQ/PFU/TLBOP/PTW source directed、negative injector、timeout/fairness、RRPV debug 均有 wrapper/run-list；bad-completion/control-hazard negative 项已由 `P6E_NEG_*` manifest rows 关闭。 |
| OOO PTW 分类 | Complete / Negative-closed | 第 4.4 节；第 8 节 `L2TLB-WAIVE-P6E-002` | `ptw_mem_ooo_rsp_seq` warning-only、`test_mbuf_ooo_response` obsolete 的结论保持有效；normal OOO coverage 不关闭，bad completion/OOO-style negative 由 approved injector/manifest rows 关闭。 |
| metadata/run-list 规则 | Implemented | `l2tlb_phase6e_test_base.svh`；`simu/l2tlb_phase6e_*_list` | 已实现 scenario metadata、trigger/checker/waiver token、positive/negative/debug/timeout run-list 分类。 |
| docs baseline 留痕 | Superseded by implementation | 第 6 节 Phase 6E docs row | 只读 inventory 记录保留为历史 baseline；实际 Phase6E 状态以 implementation row、issue 013 和 waiver/deferred rows 为准。 |
| 6E 实现状态 | Complete | 第 2 节 6E row；第 6 节 Phase 6E implementation row | 已新增 Phase6E base/suite/wrappers/run lists 并接入 `test_pkg.sv`；directed P0、negative injector、RRPV debug 和 timeout/fairness closure 有 targeted run evidence。 |
| trigger gate 实现 | Complete | `l2tlb_phase6e_test_base.svh`；第 6 节 evidence | Positive/debug wrapper 只有在 Phase6C L2TLB shadow counter 出现真实 delta 时才发 `L2TLB_PHASE6E_TRIGGER`；sequence 计划本身不算 trigger。 |
| run-list 证据 | Complete | `simu/l2tlb_phase6e_*_list`；第 6 节 evidence | `l2tlb_phase6e_directed_p0_list` 4/4 pass；`l2tlb_phase6e_negative_list`/Phase6G negative list 通过并有 manifest evidence；`l2tlb_phase6e_debug_rrpv_list` 1/1 pass；`test_l2tlb_p6e_timeout_fairness_release` seed 64001 root-cause 后单测复跑 pass。 |
| timeout/fairness closure | Closed | 第 7 节 `L2TLB-P6-ISSUE-013` | `test_l2tlb_p6e_timeout_fairness_release` seed 64001 初始失败已定位为 testbench/checker 问题；修复后复跑 `UVM_ERROR=0`、shadow mismatch=0、back-to-back DTLB cover 命中。 |

#### Phase 6F 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6F 子阶段状态 | Complete | 第 2 节 6F row；第 6 节 Phase 6F implementation row | 已实现 RRPV wbuf debug SVA/bind、arbiter wbuf-full guard、metadata/run-list 并有 compile/targeted run evidence；不声明 exact replacement/RRPV 或 wbuf full/latest-wins/same-cycle/PTW-writeback coverage 全关闭。 |
| 当前 RRPV/replacement inventory | Complete-doc | 第 4.5 节；BuildPlan Phase 6F | 已检查 RRPV wrapper、TLBWR RRPV wrapper、perf/bug wrapper、`mmu_l2tlb_rrpv_sva`、probe/coverage 和相关 RTL microarchitecture。 |
| v1/debug/future 分类 | Complete | 第 4.5 节；BuildPlan Phase 6F；`l2tlb_phase6e_test_base.svh` / `l2tlb_phase6e_tests.svh` | 已把 `L2TLB_TP_045..047`、`L2TLB_SVA_022..024` 分为 v1 functional visible、debug assertion/coverage 和 future exact model，并在 run log 输出 `L2TLB_PHASE6F_META/CLOSE`。 |
| sufficiency 结论 | Complete with scoped gaps | 第 4.5 节；第 7 节 `L2TLB-P6-ISSUE-009/014` | Basic wbuf accounting/no-overflow SVA 有 pass evidence；现有 RRPV wrapper 和 debug SVA 仍不足以关闭 exact init/aging/victim/latest-wins/full/same-cycle 行为。 |
| debug coverage plan | Implemented with cover holes | 第 4.5 节；第 6 节 Phase 6F implementation row | 已实现 push/pop/CAM/full/same-cycle/lookup-bypass 和 arbiter full-block/PTW-writeback cover。seed 65001 命中 push/pop/lookup-bypass；CAM-hit/full/full-release/same-cycle/arbiter full-block/PTW-writeback 为 0，转 6G targeted coverage。 |
| future exact item | Complete-doc | 第 4.5 节 | exact victim/free-way/max-RRPV、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass、PTW/TLBOP pending conflict 均保持 future。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6F implementation row | 已记录 `git diff --check`、`make comp_fast`、Phase6F targeted run、`check_sim_status.sh`、assertion/mismatch grep、shadow delta 和 cover hit/hole。 |

#### Phase 6G 进度确认

| 检查项 | 状态 | Progress 记录 | 说明 |
| --- | --- | --- | --- |
| 6G 子阶段状态 | Complete with scoped future | 第 2 节 6G row；第 6 节 Phase 6G implementation row | Run lists、manifest、scanner、replay 和 report flow 已实现；default manifest gate 无 blocked row 并 PASS。 |
| 当前 infrastructure inventory | Implemented | 第 4.6 节；BuildPlan Phase 6G | 已复用 `run_test.py`/`check_sim_status.sh` 执行框架，并新增 L2TLB-specific manifest/scanner/replay；Makefile/RTL 未改。 |
| sufficiency 结论 | Complete with scoped future | 第 4.6 节；第 7 节 `L2TLB-P6-ISSUE-010/015/016/017/031` | L2TLB-specific closure evidence 已可逐 row 检查；timeout/fairness、TLBOP `failed at` root-cause、PTW source-specific、negative injector、P1 hash/TLBOP exact rows 和 ReqQ/arbiter/ownership fine-grain row 均已关闭；RRPV exact/wbuf full 仍按 future/waiver 跟踪。 |
| coverage bin mapping | Complete with waiver/future | 第 4.6 节；BuildPlan Phase 6G；manifest | 已把 Phase6C/6E/6F evidence、future/waiver 和 closure rows 写入 manifest；PTW source-specific closure、negative injector 和 P1 exact/hash rows 均已纳入 manifest，仍缺 exact RRPV model。 |
| regression tiers | Complete | 第 6 节 Phase 6G implementation row | Compile、smoke、targeted、negative、debug RRPV 均已运行；timeout/fairness seed 64001、negative seed 66001、P1 exact TLBOP seeds 65034..65041 和 hash directed seed 66001 已作为 manifest closure evidence 纳入。 |
| closure artifacts/checklist | Complete | `simu/l2tlb_phase6g_evidence_manifest.tsv`；`scripts/l2tlb_phase6g_closure.py`；closure report | 默认模式输出 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26`。 |
| evidence 留痕 | Complete | 第 6 节 Phase 6G docs/implementation rows | 已记录命令、seed、log/report、root-cause closure、P1 exact/hash closure 和 default gate 语义；RTL bank-mask 常量修复由 RTL owner/user 完成并由验证侧复跑闭环。 |

### 3. Phase 7 门禁签核矩阵

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

### 4. 测试点跟踪模板

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

#### 4.1 Phase 6B scenario ID baseline

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

#### 4.2 Phase 6B test-case sufficiency gap

结论：现有 `l2tlb_tests/` 和 `tlbop_tests/` test case 不足以完成 L2TLB 测试点覆盖关闭。它们是候选入口，不是覆盖结论。Phase6B 明确要求后续补充以下内容。

| Gap group | 必须补充/加强的内容 | 相关 TP | 当前状态 |
| --- | --- | --- | --- |
| Reset / epoch | cold reset directed；warm reset during lookup/PTW/TLBOP/PFU；reset epoch/stale completion checker | `L2TLB_TP_001..002`, `043` | Missing directed/checker evidence |
| ReqQ / arbiter checker | ITLB entry0、DTLB load/store split、bypass payload stability、MB-full retry、credit return fault case、arbiter payload no-cross、priority/fairness evidence | `L2TLB_TP_004..011` | Existing wrappers are candidates; checker evidence missing or incomplete |
| Lookup / page-size / ASID | ITLB vs DTLB source split；4K/2M/1G offset bins；ASID/global bins；multi-hit legal-result classifier | `L2TLB_TP_012..016` | Existing wrappers are candidates; trigger evidence must be proven |
| MB / PTW | PTW ready backpressure；bad completion negative；MB same-cycle alloc/dealloc；duplicate lifetime；PTW out-of-order completion；PTW disabled/page fault/access error source-specific closure 已完成 | `L2TLB_TP_017..027`, `056` | PTW source-specific row closed；bad completion/OOO-style negative row closed；remaining MB fine-grain wrapper/checker gaps tracked separately |
| PFU | MMU-off direct；MMU-on L2 hit；PFU miss+PTW；flag fault；PMP/sysmap deny；error payload-ignore；prefetch_mask；attribute truth table | `L2TLB_TP_028..033`, `053`, `057` | Major directed-test gap |
| TLBOP / invalidate / abort | L2 entry shadow for TLBP/TLBR/TLBWI/TLBWR/INV*；TLBOP lifecycle done ordering；INV* global/non-global/all-set scan；abort stale completion | `L2TLB_TP_034..044`, `051..052` | Existing wrappers are candidates; lifecycle/shadow evidence missing |
| Negative / control hazard | illegal type/page-size/bad ID/credit overflow；SATP/ASID/MMU/PTW/control write with outstanding translation/PTW | `L2TLB_TP_048`, `058` | Isolated negative suite implemented and manifest rows PASS; credit-overflow exact subcase remains future if required |
| Timeout / closure | timeout/fairness classifier；traceability manifest/scanner；coverage/SVA/log closure rows | `L2TLB_TP_049..050` | Closure tooling/checker policy missing |
| RRPV / replacement | RRPV init/wbuf debug cover；replacement exact victim/RRPV future model | `L2TLB_TP_045..047` | Debug/future only; not v1 closure blocker |

因此 Phase6B 交付的是缺口明确化和后续实现清单。任何后续阶段若只运行现有 wrapper 而没有补齐 trigger/checker evidence，不得把对应 TP 标为 `Complete`。

#### 4.3 Phase 6C scoreboard/reference-model baseline

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

#### 4.4 Phase 6E directed/negative test baseline

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

#### 4.5 Phase 6F RRPV/replacement baseline

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

#### 4.6 Phase 6G coverage/regression/closure baseline

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

### 5. SVA 跟踪模板

本表跟踪 `L2TLB_SVA_001..024`。Phase6D 已补入当前 SVA/bind inventory、稳定 bind 实现、assertion-enabled compile/run evidence、未命中 cover 和 scope waiver/future。后续 6E/6F/6G 关闭前仍必须把 deferred cover、directed negative 和 future exact item 逐项补 evidence 或 waiver。

#### 5.1 Phase 6D SVA/bind inventory

| 文件 / bind | 当前已有能力 | Phase6D 判断 |
| --- | --- | --- |
| `mmu_l2tlb_rrpv_sva.sv` bind `mmu_l2tlb` | 新增/强化 reset visible drain、request/queue/arb/final/PTW/L1/PFU/TLBOP no-X、PTW request ready stability、PTW completion legal combo、ReqQ multi-hit/PTW-disabled terminal release 和 cover properties。 | 覆盖 `L2TLB_SVA_001/011/012/014/018` 稳定子项；TLBOP full lifecycle、full reset-inv 和 exact replacement 仍不在本 bind 关闭。 |
| `mmu_arb_sva.sv` bind `mmu_arb` | 新增/强化 five-source onehot、PTW/TLBOP/wbuf/prefetch_mask block、fixed-priority eligibility、source payload no-cross、PFU mask set/release、Phase6F wbuf-full no-wrong-grant/PTW-writeback guard 和 cover properties。 | 覆盖 `L2TLB_SVA_005/006/019/020/021` 稳定 arbiter 子项，并作为 `L2TLB_SVA_022` 外侧 no-wrong-grant debug evidence；未命中 block/conflict cover 转 6G targeted closure。 |
| `credit_sva.sv` bind `mmu_l2tlb_reqq` | 新增 ReqQ request one-cycle pulse、payload known、normal no-credit guard、ITLB/DTLB partition、grant onehot0、feedback ID/result legality、retry lifetime、credit return accounting 和 cover properties。 | 覆盖 `L2TLB_SVA_003/004/007/008/018` 稳定 ReqQ 子项；fault/negative overflow directed evidence 仍需 6E/6G。 |
| `mmu_l2tlb_mb_sva.sv` bind `mmu_l2tlb_mb` | 新增 MB reset visible drain、request payload/type known、ITLB/DTLB partition/full no-overwrite、ffr/grant/bypass onehot0、issue payload/partition/stability、feedback ID/outstanding/dealloc、abort visible ownership 和 cover properties。 | 新增 Phase6D bind；覆盖 `L2TLB_SVA_001/009/010/011/013/016/018` 稳定 MB 子项；bad-ID/type-exact negative 仍需 6E。 |
| `tb_top.sv` | 已 bind `mmu_arb_sva`、`mmu_l2tlb_rrpv_sva`、`mmu_l2tlb_mb_sva`、`credit_sva`。 | L2TLB/ReqQ/MB/arbiter bind 入口已更新并经 `make comp_fast` elaboration。 |
| `Files.f` | 已 include `mmu_arb_sva.sv`、`mmu_l2tlb_rrpv_sva.sv`、`mmu_l2tlb_mb_sva.sv`、`credit_sva.sv`。 | SVA compile list 已同步；新增 MB SVA 文件进入 assertion-enabled compile。 |
| `scripts/cov_hier.cfg` | 已加入 `-module mmu_l2tlb_mb_sva`。 | 与现有 SVA module 一致排除 code coverage；assertion/cover closure 仍从 log/report/manifest 独立记录。 |

#### 5.2 Phase 6D SVA baseline

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
| `L2TLB_SVA_013` | must | Implemented-scoped + negative closed | `mmu_l2tlb_mb_sva` + Phase6E negative injector | PTW completion id/type、MB outstanding | outstanding ID assertions PASS；negative seed 66001 PASS | `P6E_NEG_PTW_NO_OUTSTANDING`、`P6E_NEG_PTW_BAD_ID_TYPE` rows PASS | MB feedback ID known/in-range/outstanding implemented; bad-ID/no-outstanding negative classified by isolated negative suite. |
| `L2TLB_SVA_014` | must | Implemented-scoped + PTW source closure | `mmu_l2tlb_rrpv_sva` + Phase6C shadow | final multi-hit、PTW disabled miss、ReqQ feedback | `comp_fast` + four smoke PASS；PTW source closure seed 64001 PASS | PTW disabled terminal source bins hit 4/4；multi-hit remains debug/future | Terminal release assertions strengthened; PTW-disabled directed trigger closed by `P6E_PTW_SOURCE_FAULT_CLOSURE`. |
| `L2TLB_SVA_015` | must | Deferred / waiver-required | future `ct_mmu_tlboper`/probe checker | TLBOP request/grant/cmplt/done、utlb clear、abort | Deferred | Missing | Full TLBOP lifecycle ordering not implemented in 6D; move to 6E directed or approved waiver. |
| `L2TLB_SVA_016` | must | Implemented-scoped | `mmu_l2tlb_mb_sva` + Phase6C epoch helper | `tlboper_ptw_abort`、MB state、late completion | `comp_fast` + four smoke PASS | MB abort outstanding cover 0 | Abort visible ownership guard implemented; late completion isolation still relies on Phase6C epoch/6E directed evidence. |
| `L2TLB_SVA_017` | must | Negative closed | Phase6E negative injector + top control-hazard diagnostic | CSR/control writes、ReqQ/MB/PTW outstanding、abort/flush/done | negative seed 66001 PASS | `P6E_NEG_CONTROL_HAZARD` row PASS | Control hazard remains negative-only and is not counted as normal functional coverage. |
| `L2TLB_SVA_018` | must | Implemented-scoped | `mmu_l2tlb_rrpv_sva`、`credit_sva`、`mmu_l2tlb_mb_sva` | valid beat payload/control | `comp_fast` + four smoke PASS | N/A | Covers request/queue/arb/final/PTW/TLBOP/PFU/L1/ReqQ/MB no-X on stable valid beats. |
| `L2TLB_SVA_019` | debug | Implemented-scoped | `mmu_arb_sva` | `ptw_on`、PTW read/write grant、source grants | `comp_fast` + four smoke PASS | ptw_on block cover 0 | PTW-on block assertions implemented; cover remains targeted debug hole. |
| `L2TLB_SVA_020` | debug | Implemented-scoped | `mmu_arb_sva` | `tlboper_on`、source grants、TLBOP done | `comp_fast` + four smoke PASS | tlboper_on block cover 0 | TLBOP-on block assertions implemented; full lifecycle deferred under `L2TLB_SVA_015`. |
| `L2TLB_SVA_021` | debug | Implemented | `mmu_arb_sva` | PFU valid、prefetch_mask、PFU grant、PFU response | `comp_fast` + four smoke PASS | PFU mask release cover hit 32 | PFU mask block/set/release implemented. |
| `L2TLB_SVA_022` | debug | Implemented-scoped / 6F | `mmu_l2tlb_rrpv_wbuf_sva` bind `mmu_l2tlb_rrpv_wbuf` + `mmu_arb_sva` | wbuf reset/count/status、push/pop accept accounting、no overflow/underflow、valid-bank payload known、lookup result known、wbuf-full no wrong read grant、PTW writeback not blocked by full | `comp_fast` + `test_l2tlb_p6e_rrpv_debug_pressure` seed 65001 PASS | push_new_entry=96、pop=96、lookup_bypass_hit=48；cam_hit/full/full_release/same_cycle/arbiter full-block/writeback cover 0 | Closes debug no-overflow/no-underflow/accounting/no-wrong-grant baseline only; no exact RRPV/victim/latest-wins closure. |
| `L2TLB_SVA_023` | future | Future | future replacement exact model | victim/free-way/max-RRPV inputs | N/A | Future | v1 不实现；需专项 exact replacement model。 |
| `L2TLB_SVA_024` | future | Future | future RRPV exact model | wbuf latest-wins/merge/bypass inputs | N/A | Future | v1 不实现；需专项 RRPV model。 |

#### 5.3 Phase 6D SVA closure rules

- `must` 行必须实现并提供 assertion-enabled compile/run evidence，或提供 approved waiver；`Partial-existing` 不能关闭 ID。
- `debug` 行若不实现，必须写清 deferred 原因、风险和替代 debug evidence。
- `future` 行不是 v1 closure blocker，但必须保留在 closure manifest 中。
- Reset 行为和 `disable iff` 策略必须匹配来源需求；reset assert 类 property 不能因 reset active 被整体 disable。
- Negative assertion-only 项不得混入普通功能回归，fail 结果必须与负向测试预期一致。
- 新增 bind 必须优先使用模块端口、bind scope 内部信号或稳定 probe；缺采样源时先回到 6A 补 probe 或写 waiver。

### 6. 证据日志

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
| 2026-05-23 | Phase 6E implementation | `make comp_fast`（workdir: `mmu_verification/`）；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_directed_p0_list --mode run_check --seeds 64001 --timeout 8000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_negative_list --mode run_check --seeds 64001 --timeout 8000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`make run_check TEST_NAME=test_l2tlb_p6e_negative_ptw_completion_control SEED=66001 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0`；`make run_check TEST_NAME=test_l2tlb_p6e_neg_control_hazard SEED=66001 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_debug_rrpv_list --mode run_check --seeds 64001 --timeout 10000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6e_timeout_fairness_list --mode run_check --seeds 64001 --timeout 12000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；后续 root-cause 复跑 `make run TEST_NAME=test_l2tlb_p6e_timeout_fairness_release SEED=64001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000`；PTW source closure 单测和 Phase6G targeted list 复跑 | Complete | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu_64001.log`；`test_l2tlb_p6e_reqq_arb_payload_owner_64001.log`；`test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask_64001.log`；`test_l2tlb_p6e_ptw_disabled_fault_accerr_64001.log`；`test_l2tlb_p6e_tlbop_inv_abort_lifecycle_64001.log`；`test_l2tlb_p6e_negative_ptw_completion_control_66001.log`；`test_l2tlb_p6e_neg_control_hazard_66001.log`；`test_l2tlb_p6e_rrpv_debug_pressure_64001.log`；`test_l2tlb_p6e_timeout_fairness_release_64001.log` | 已新增 Phase6E base/suite/wrappers/run lists。Directed P0 原 4/4 pass；PTW source closure 后 targeted list 更新为 5/5 pass。PTW source closure shadow delta `activity=55 ptw_req=10 ptw_fault=10 pfu=3 payload_ignore=17`，12 个 disabled/page-fault/access-error source/result counter 全部 >0。Negative aggregate seed 66001 `trigger_count=4 checker_count=4 waiver_count=0 future_or_waiver=0`，individual negative rows 覆盖 no-outstanding、bad ID/type、illegal combo 和 control hazard。RRPV debug `activity=246`，但 exact victim/RRPV/wbuf 保持 future。Timeout/fairness 初始失败已 root-caused 为 PFU payload compare、L1DTLB MB current-window 和 ReqQ back-to-back SVA policy 的 testbench 问题。 | Timeout/fairness seed 64001 复跑已 clean；PTW source closure seed 64001 `UVM_WARNING=0`、`UVM_ERROR=0`、`UVM_FATAL=0`、`PHASE6C_L2_SHADOW mismatch=0 waived_future=0`；negative aggregate/control-hazard seed 66001 `UVM_ERROR=0`、`UVM_FATAL=0`。RRPV exact model 仍未关闭。 |
| 2026-05-23 | Phase 6F docs | `rg -n "RRPV\|replacement\|victim\|wbuf\|L2TLB_TP_045\|L2TLB_SVA_022" doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`find mmu_verification/testbench/test/{l2tlb_tests,tlbop_tests,perf_tests,bug_hunt_tests} -maxdepth 1 -name '*rrpv*.svh'`；`rg -n "p9_tc_id\|p9_seq_desc\|p9_checker\|m_vseq_names" ...rrpv...`；`sed -n '1,220p' mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`；`rg -n "rrpv\|wbuf\|victim\|l2_bank\|l2_final_way" mmu_verification/testbench/env/mmu_dut_probes_if.sv mmu_verification/testbench/env/mmu_env_cg_whitebox.svh mmu_verification/testbench/top/tb_top.sv mmu/rtl/mmu_l2tlb*.sv` | Complete-doc | 本文件和 BuildPlan Phase 6F | 确认 `l2tlb_tests` 中 14 个 RRPV wrapper、`tlbop_tests` 1 个 TLBWR/RRPV wrapper、`perf_tests` 1 个 RRPV stress wrapper、`bug_hunt_tests` 1 个 post-inv wrapper；多数 RRPV wrapper 复用 `mmu_rrpv_aging_vseq` 且 checker 为 `credit_sb`，现有 whitebox coverage 只有 bank/way/page-size debug surface。已在第 4.5 节完成 v1/debug/future 分类。 | 后续实现必须补 `phase6f_class` metadata、`L2TLB_SVA_022` 或等价 checker、debug coverage/run log；`L2TLB_SVA_023/024` 和 exact victim/RRPV/wbuf latest-wins 继续 future；本轮未运行仿真、未改行为代码。 |
| 2026-05-23 | Phase 6F implementation | `git diff --check`；`make comp_fast`（workdir: `mmu_verification/`）；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6f_debug_rrpv_list --mode run_check --seeds 65001 --timeout 10000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`bash scripts/check_sim_status.sh output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`rg -n "failed at\|PHASE6C_L2_MISMATCH\|c_rrpv_wbuf_\|c_wbuf_full_" output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log` | Pass | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`mmu_verification/output/regression/adhoc/summary.txt` | 已新增并 bind `mmu_l2tlb_rrpv_wbuf_sva`，并在 `mmu_arb_sva` 补 wbuf-full no-wrong-grant/PTW-writeback guard；Phase6F metadata/run-list 生效。Run log 输出 `L2TLB_PHASE6F_META/CLOSE`，shadow delta `ptw_req=48 ptw_data=48 l2_hit=96 l2_miss=48 inv=1 cp0_all_inv=2 abort_epoch=1 control_epoch=2 activity=246`；wbuf cover `push_new_entry=96`、`pop=96`、`lookup_bypass_hit=48`。 | `make comp_fast` pass；targeted run `PASS=1 FAIL=0`，`UVM_ERROR=0`、`UVM_FATAL=0`，无 `failed at` 或 `PHASE6C_L2_MISMATCH`。`cam_hit_update/full_seen/true_full_block/full_release/push_pop_same_cycle/c_wbuf_full_blocks_new_reads/c_wbuf_full_allows_ptw_writeback` cover 为 0，转 6G targeted coverage；exact victim/RRPV/latest-wins/merge/same-cycle bypass 保持 future exact model。 |
| 2026-05-23 | Phase 6G docs | Read Makefile coverage/regress targets；read `scripts/run_test.py`、`scripts/check_sim_status.sh`、`scripts/phase13_exit_gate.py`、`scripts/phase14_exit_gate.py`、`scripts/l1dtlb_phase6g_closure.py`、`scripts/l1dtlb_phase6g_replay.py`；read `simu/mmu_smoke_list`、`simu/mmu_nightly_list`、`simu/mmu_coverage_list`、`simu/l1dtlb_phase6g_*`；read `scripts/cov_hier.cfg`、`mmu_env_cg_whitebox.svh` and existing `output/coverage/phase14_urgReport` summaries | Superseded by implementation | 本文件和 BuildPlan Phase 6G | 初始 docs baseline 确认已有 Makefile/run_cov/URG、generic regression、log checker、Phase13/14 gate 和 L1DTLB Phase6G manifest/closure/replay 模式可复用；当时缺少 L2TLB-specific `l2tlb_phase6g_*` run list、manifest、closure scanner 或 L2-specific log fallback。既有 Phase14 URG 中 `cg_tlboper_fsm` 6.25、`cg_l2_reqq` 58.33、`cg_l2tlb_bank` 80.08、`cg_ptw_walk` 77.08，且 assertion failures 为 1，不能作为 L2TLB Phase6G closure。 | 保留为只读审计历史；实际 6G 状态以 Phase 6G implementation row、issue 013/015 和 manifest/closure report 为准。 |
| 2026-05-23 | Phase 6G implementation | `python3 -m py_compile scripts/l2tlb_phase6g_closure.py scripts/l2tlb_phase6g_replay.py`；`git diff --check`；`make comp_fast`（workdir: `mmu_verification/`）；Phase6G smoke/targeted/negative/debug runs；timeout/fairness 和 TLBOP/PTW LSU root-cause 后单测复跑；PTW source closure 单测和 targeted list 5/5；negative aggregate/control-hazard seed 66001 复跑；P1 exact/hash rows 加入 manifest 后复跑 `python3 scripts/l2tlb_phase6g_closure.py --manifest simu/l2tlb_phase6g_evidence_manifest.tsv --compile-log output/logs/comp_fast.log` | Pass | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_*_64001.log`；`mmu_verification/output/logs/test_l2tlb_p6e_*_66001.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`mmu_verification/output/logs/test_mmu_tlb*_6503*.log`；`mmu_verification/output/logs/test_arb_skew_index_generation_66001.log`；`mmu_verification/output/regression/l2tlb_phase6g_closure/closure_report.md`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv` | 5 个 Phase6G run list、25-row manifest、closure scanner 和 replay helper 已落地。新增 `P6E_PTW_SOURCE_FAULT_CLOSURE` row 要求 PTW disabled/page-fault/access-error 四源 counter、payload-ignore、shadow clean 和 UVM clean；新增 `P6E_NEG_*` rows 要求 `L2TLB_NEG_TRIGGER`、`L2TLB_NEG_EXPECTED_CLASS`、trigger/checker counter、waiver/future 为 0 和 UVM clean；新增 `P1_TLBP/TLBR/TLBWI/TLBWR_*` rows 要求 exact TLBOP check/readback token 和 UVM clean；新增 `P1_L2TLB_HASH_EXACT_DIRECTED` row 要求 hash check token、UVM clean、selector 00/01/10/11 和 `tlbop_idx_not_va` cover。后续 `P1_REQQ_ARB_FINE_CLOSURE` 将 manifest 扩展到 26 rows。 | Historical Phase6G base gate reached `STATUS=PASS PASS=25 OPEN=0 FAIL=0 TOTAL=25` before the later ReqQ/arbiter fine-grain row was added. `P6E_TLBOP_INV_ABORT`、`P6G_TIMEOUT_FAIRNESS_CLOSURE`、`P6E_PTW_SOURCE_FAULT_CLOSURE`、`P6E_NEG_*` 和 P1 exact/hash rows 均已 closure/pass；RRPV exact/future 项仍需后续专项或 future/waiver 更新。 |
| 2026-05-24 | P1 TLBOP exact + L2TLB hash exact model | `make comp_fast`；8 个 `make run_check TEST_NAME=test_mmu_tlb{p,wr,wi,r}_* SEED=65034..65041` exact wrapper；`make run_check TEST_NAME=test_arb_skew_index_generation SEED=66001`；log grep `L2TLB_HASH_FAIL`、`c_l2tlb_hash_selector_*`、`L2TLB_TLBOP_CHECK/READBACK`、`UVM_ERROR/FATAL`；closure scanner | Closed after RTL owner/user bank-mask fix | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_tlbp_query_hit_65034.log`；`test_mmu_tlbp_query_miss_65035.log`；`test_mmu_tlbr_read_entry_65036.log`；`test_mmu_tlbr_all_fields_65037.log`；`test_mmu_tlbwi_write_entry_65038.log`；`test_mmu_tlbwi_overwrite_65039.log`；`test_mmu_tlbwr_random_replace_65040.log`；`test_mmu_tlbwr_rrpv_policy_65041.log`；`mmu_verification/output/logs/test_arb_skew_index_generation_66001.log`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv` | 已新增共享 L2TLB hash/skew/page-size/bank-mask golden model，CP0 TLBP/TLBR/TLBWI/TLBWR exact sequences 改用同一模型；`mmu_arb_sva` 对 idx/size/bank 做 exact compare 并用 `UVM_ERROR[L2TLB_HASH_FAIL]` 计入 run_check；bank mask golden model 由 2.3 arbiter 的 per-bank pre page size 表派生，不再维护重复硬编码 mask 表；`test_arb_skew_index_generation` directed 覆盖 selector 00/01/10/11 和 `tlbop_idx_not_va`。RTL owner/user 已将 `../mmu/rtl/mmu_arb.sv` `mask_bank_sel` 常量从无尺寸十进制写法修为显式 `8'b...`，包括 selector 00/10 4K 期望 `0x33`。 | `make comp_fast` pass；8 个 exact TLBOP wrapper seeds 65034..65041 全部 `UVM_ERROR=0 UVM_FATAL=0` 且有 `L2TLB_TLBOP_CHECK/READBACK` evidence。Hash directed seed 66001 复跑 `UVM_ERROR=0 UVM_FATAL=0`、无 `L2TLB_HASH_FAIL`，translation SB `mismatch=0`；selector covers：00=787、01=18、10=19、11=12，`tlbop_idx_not_va=768`。该 directed run 有 16 个已接受 IFU monitor warning，非 hash/bank mismatch。 |
| 2026-05-24 | P1 ReqQ/arbiter fine-grain closure | `make comp_fast`；`make run_check TEST_NAME=test_l2tlb_p6e_reqq_arb_fine_overlap SEED=64001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000`；log grep `L2TLB_CP0_TLBP_BURST`、`L2TLB_ARB_FINE_HIT`、`L2TLB_REQQ_FINE`、`L2TLB_ARB_FINE`、`PHASE6C_L2_SHADOW`、SVA cover 和 `UVM_ERROR/FATAL`；closure scanner | Closed | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_reqq_arb_fine_overlap_64001.log`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv`；`mmu_verification/output/regression/l2tlb_phase6g_closure/closure_report.md` | CP0 TLBP burst 已合法化并相位对齐：最新有效 log 明确 `delay_1ns_steps=36581`、`event=start t=38042000`、`event=mcir_issue t=38045000 op=0`。`t=38049000` 同拍 first-hit 打到 `four_req`、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、PTW/ReqQ/PFU、TLBOP/ReqQ/PFU、PTW/TLBOP/ReqQ 和 PTW/TLBOP/PFU。`L2TLB_REQQ_FINE` 证明 ITLB/DTLB load/store split `i/d-load/d-store req=104/160/184`；`L2TLB_ARB_FINE` 证明 `four_req=1 ptw_reqq_conflict=2 tlbop_reqq_conflict=14 ptw_tlbop_conflict=1 reqq_pfu_conflict=378 ptw_reqq_pfu_conflict=2 tlbop_reqq_pfu_conflict=10 ptw_tlbop_reqq_conflict=1 ptw_tlbop_pfu_conflict=1 ptw_on_reqq_block=7 tlboper_on_pfu_block=90 prefetch_mask_release=128`。 | Run clean：`UVM_WARNING=0 UVM_ERROR=0 UVM_FATAL=0`，无 `CP0_MCIR_CMPLT_TIMEOUT`；Phase6C L2 shadow `orphan=0 mismatch=0`；covers 命中 `c_pairwise_ptw_reqq_conflict=2`、`c_pairwise_tlbop_reqq_conflict=14`、`c_diag_ptw_tlbop_conflict=1`、`c_diag_ptw_reqq_pfu_conflict=2`、`c_diag_tlbop_reqq_pfu_conflict=10`、`c_ptw_on_blocks_reqq=7`、`c_tlboper_on_blocks_pfu=90`、`c_prefetch_mask_release=128`。Manifest row 转为 `P1_REQQ_ARB_FINE_CLOSURE`；DUT/RTL 未修改。 |

### 7. Issue 日志

Issue type 值：`RTL bug`、`UVM bug`、`Spec gap`、`Tooling issue`、`Probe gap`、`Regression gap`、`Approved waiver`。

| ID | 日期 | Type | Severity | 相关 TP/SVA | 描述 | Owner | 状态 | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB-P6-ISSUE-001 | 2026-05-21 | Regression gap | Low | Phase 6 | Phase 6 是文档阶段，未运行仿真。 | TBD | Closed (Phase 6A-6G 全部完成，baseline compile/regression 已建立) | 后续已批准实现阶段记录 baseline compile/regression 后关闭。 |
| L2TLB-P6-ISSUE-002 | 2026-05-23 | Probe gap | Medium | Phase 6A / 6C / 6D | 现有代码已有大量 L2TLB white-box probe，但 Phase6A 原文未展开 inventory、consumer 和 missing-signal decision，后续阶段容易把“有信号/有 wrapper”误判为“已验证”。 | TBD | Closed-doc | 已在 BuildPlan Phase6A 补 inventory、decision table 和 consumer list；后续 6C/6D 若需要新增观察源，必须回到 6A 增补或写 waiver。 |
| L2TLB-P6-ISSUE-003 | 2026-05-23 | Tooling issue | Low | Phase 6A compile baseline | `make comp_fast` 和 full `make comp` 均通过，但日志有 locale warning 和 VCS csrc clock skew warning。 | TBD | Closed (clock skew 为 NFS/timestamp 环境问题，非功能缺陷) | 当前不阻塞 Phase6A compile baseline；正式 regression 前建议刷新 csrc mtimes 或 clean rebuild，并记录是否仍出现 clock skew。 |
| L2TLB-P6-ISSUE-004 | 2026-05-23 | Regression gap | High | Phase 6B / `L2TLB_TP_001..058` | 现有 `l2tlb_tests/` 与 `tlbop_tests/` wrapper 已 include 到 `test_pkg.sv`，但不少是 Phase9 generated wrapper，且可复用通用 vseq/checker；wrapper 名称、`p9_tc_id` 或 `TC-*` 不能证明目标 L2TLB 场景已触发或已检查。 | TBD | Closed-doc | BuildPlan Phase6B 已加入 wrapper inventory、metadata contract 和逐 ID 初始映射；后续关闭必须同时提供 trigger evidence 与 pass/fail evidence。 |
| L2TLB-P6-ISSUE-005 | 2026-05-23 | Regression gap | High | Phase 6B / P0/P1 TP coverage | 现有 test case 不足以完成 L2TLB 测试点覆盖关闭；reset/PTW disabled/PTW fault/ready/OOO/PFU/negative/control hazard/timeout 等场景缺 wrapper 或缺 checker/SVA/coverage evidence。 | TBD | Closed (6C/6D/6E/6G 已逐项补 evidence 或 waiver，2026-06-06 全部 TP coverage 已闭合) | 已在 BuildPlan Phase6B sufficiency conclusion 和本文件第 4.2 节列出必补内容；后续 6C/6D/6E/6G 必须逐项补证据或 waiver。 |
| L2TLB-P6-ISSUE-006 | 2026-05-23 | Regression gap | High | Phase 6C / Phase 4 scoreboard boundary | 原有 `mmu_translation_sb`、`mmu_invalidate_sb`、`mmu_credit_sb`、`mmu_ref_model` 不能提供 L2 entry shadow、payload-ignore 和统一 mismatch taxonomy。 | TBD | Closed | 已新增 `mmu_l2tlb_txn_shadow` 并接入 translation/invalidate scoreboard，完成 PTW refill shadow、L2 final 可见比较、INV/CP0 all-inv、epoch、PFU classifier、payload-ignore 和 mismatch taxonomy；剩余非 core closure 由 `L2TLB-P6-ISSUE-011` 跟踪。 |
| L2TLB-P6-ISSUE-007 | 2026-05-23 | Regression gap | High | Phase 6D / `L2TLB_SVA_001..024` | 初始 docs baseline 发现原有 SVA/bind 只覆盖少量局部 property，不足以关闭 Phase 3 must set。 | TBD | Closed | Phase6D implementation 已扩展 arbiter/ReqQ/L2/MB SVA 并新增 MB bind；reset-inv、TLBOP lifecycle 和 control hazard 已由后续 directed/negative evidence 补证据，RRPV wbuf/exact 和未命中 cover 由 `L2TLB-P6-ISSUE-012/014` 与 future/waiver rows 跟踪。 |
| L2TLB-P6-ISSUE-008 | 2026-05-23 | Regression gap | High | Phase 6E / directed and negative tests | 现有 directed/stress/negative-looking wrapper 数量较多，但缺 per-scenario trigger gate、checker/SVA gate、negative 隔离和 targeted run evidence；PFU、PTW disabled/fault/access error、control hazard、timeout/fairness、reset/TLBOP cross 等 P0/P1 不能直接关闭。 | TBD | Closed with exact-model future | Phase6E 已新增 base/suite/wrappers/run lists 和 shadow-delta trigger gate；directed P0、PTW disabled/fault/access-error source closure、isolated negative injector、RRPV debug 和 timeout/fairness closure 有 targeted evidence。剩余 RRPV exact/wbuf full 行为转 future/waiver。 |
| L2TLB-P6-ISSUE-009 | 2026-05-23 | Regression gap | Medium | Phase 6F / `L2TLB_TP_045..047`, `L2TLB_SVA_023..024` | 现有 RRPV/replacement wrapper 名称包含 init、aging、victim、wbuf 等 exact 意图，但多数复用 `mmu_rrpv_aging_vseq` 和 `credit_sb`，且现有 probe/coverage 只有有限 bank/way/page-size debug surface；不能关闭 exact victim、exact RRPV value 或 wbuf latest-wins/merge。 | TBD | Closed (2026-06-06 RRPV exact model, 0 victim/rrpv mismatch) | Phase6F 已补 `phase6f_class` metadata、`L2TLB_SVA_022` debug SVA 和 targeted run evidence；但 exact victim/RRPV/latest-wins/merge/same-cycle bypass 仍保持 future exact model，不能由 debug pass 关闭。 |
| L2TLB-P6-ISSUE-010 | 2026-05-23 | Regression gap | High | Phase 6G / closure evidence | 现有全局 regression、coverage list、Phase14 URG 和 generic pass summary 缺 L2TLB-specific manifest/run-list/scanner，不能逐项关闭 `L2TLB_TP_001..058`、`L2TLB_SVA_001..024`；whitebox coverage 缺部分 L2-specific log fallback，既有 Phase14 report 仍有 L2 group coverage 缺口和 assertion failure。 | TBD | Complete with scoped future | Phase6G 已新增 L2TLB-specific run list、manifest、closure scanner 和 replay flow；timeout/fairness、TLBOP/PTW LSU root-cause、PTW source-specific harness、isolated negative injector、P1 exact/hash rows 和 P1 ReqQ/arbiter fine-grain row 均已关闭。RRPV exact/future 项仍需后续补证据或 waiver/future 更新。 |
| L2TLB-P6-ISSUE-011 | 2026-05-23 | Regression gap | High | Phase 6C follow-up / `L2TLB_TP_004..011`, `034..044`, `049..050`, `055..056` | Phase6C core helper 已实现，且 INVALL seed 63002 长跑问题已修正并补入短 directed pass evidence；原 CP0/TLBP/TLBR/TLBWI/TLBWR exact transaction decode/readback 缺口已由 2026-05-24 P1 exact rows 关闭，但 ReqQ/arbiter payload no-cross、完整 MB/OOO/ready policy 和部分 fine-grain coverage 仍未全部关闭。 | TBD | Partially closed | `L2TLB_TP_034..037` exact decode/readback 已由 `P1_TLBP/TLBR/TLBWI/TLBWR_*` manifest rows、seeds 65034..65041 和 hash directed seed 66001 关闭；剩余 ReqQ/arbiter ownership fine-grain、MB/OOO/ready policy 和 RRPV exact/future 项继续由对应 issue/waiver/future rows 跟踪，不能用本次 P1 closure 代替。 |
| L2TLB-P6-ISSUE-012 | 2026-05-23 | Regression gap | High | Phase 6D / `L2TLB_SVA_001..024` | Phase6D 已实现稳定 bind SVA 并通过 assertion-enabled compile/smoke，但 full reset-inv boundary、full TLBOP lifecycle、control hazard negative、RRPV wbuf debug no-overflow/no-wrong-grant、exact replacement/RRPV 和部分 cover trigger 在 6D 阶段未关闭。 | TBD | Partially closed / Future cover | `L2TLB_SVA_002/015/017` 已由 6E/6G directed/negative evidence 补证据；`L2TLB_SVA_022` 由 6F debug baseline 关闭基本 no-overflow/no-wrong-grant；`L2TLB_SVA_023/024` 保持 future exact model；未命中 wbuf full/CAM/same-cycle cover 转 `L2TLB-P6-ISSUE-014`。 |
| L2TLB-P6-ISSUE-013 | 2026-05-23 | Regression gap | High | Phase 6E / `L2TLB_TP_049..050` | `test_l2tlb_p6e_timeout_fairness_release` seed 64001 初始失败：真实 Phase6C shadow delta `ptw_req=118 ptw_data=118 l2_hit=74 l2_miss=118 pfu=52 payload_ignore=52 activity=544` 后出现 `UVM_ERROR=94`、translation SB 52 个 PA/fault mismatch、L1DTLB spec SB `P6D_MB_CAM_HIT=6` 和 `P6D_ALLOC_MISS=6`。 | TBD | Closed | Root-cause 为 testbench/checker 问题：PFU flag-only 诊断位不应触发 PA payload compare，L1DTLB MB CAM 应允许当前 sampled MB window，DTLB ReqQ 可合法 back-to-back 发不同 miss。已修正并复跑 seed 64001：`UVM_ERROR=0`、`UVM_FATAL=0`、`PHASE6C_L2_SHADOW:mismatch=0`、`c_d_req_back_to_back_valid=2`；manifest row 已改为 closure。 |
| L2TLB-P6-ISSUE-014 | 2026-05-23 | Regression gap | Medium | Phase 6F / `L2TLB_TP_046`; `L2TLB_SVA_022..024` | Phase6F targeted run seed 65001 命中 wbuf push/pop/lookup-bypass，但 `cam_hit_update`、`full_seen`、`true_full_block`、`full_release`、`push_pop_same_cycle`、`c_wbuf_full_blocks_new_reads`、`c_wbuf_full_allows_ptw_writeback` cover 均为 0。 | TBD | Closed (2026-06-06 waiver: 7 个未命中 cover 均有 equivalent assertion 保护) | Basic wbuf no-overflow/accounting/no-wrong-grant SVA 已通过；full stall/release、CAM merge、PTW writeback under full、same-cycle bypass 和 latest-wins 压力转 6G targeted coverage 或 future exact-model，不能用本次 PASS 关闭。 |
| L2TLB-P6-ISSUE-015 | 2026-05-23 | Regression gap | High | Phase 6G / `L2TLB_TP_034..044`; `L2TLB_SVA_015/016` | `test_l2tlb_p6e_tlbop_inv_abort_lifecycle` seed 64001 generic run summary PASS 且 `UVM_ERROR=0`，但 log 中曾存在 `mmu_ptw_lsu_protocol_sva.a_mbuf_ptr_only_on_response` 的 `failed at` 行。 | TBD | Closed | Root-cause 为 SVA 过窄：`mbuf_entry_on` 是 per-entry LSU outstanding/lifecycle marker，除 request accept 和 response 外，TLBOP abort 通过 `mbuf_all_clr` 同步清零也会合法改变它。已改为 `a_mbuf_entry_on_changes_on_lifecycle_event` 并新增 `cp_lsu_abort_entry_clear` cover；seed 64001 复跑 `UVM_ERROR=0`、无 `failed at`、`cp_lsu_abort_entry_clear=6`，manifest row 改为 closure。 |
| L2TLB-P6-ISSUE-016 | 2026-05-24 | RTL bug | High | `L2TLB_TP_054`; P1 hash/index/bank exact model | L2TLB PTW read bank mask 曾使用无尺寸十进制常量，导致 4K selector 00/10 期望 `8'b0011_0011` 实际截断为 `8'hbb`，selector 01/11 期望 `8'b1100_1100` 实际截断为 `8'h0c`；2M/1G 常量同类风险也存在。 | RTL owner/user | Closed | RTL owner/user 已将 `../mmu/rtl/mmu_arb.sv` `mask_bank_sel` 常量改为显式 `8'b...`，包括 selector 00/10 4K bank `0x33`。`make comp_fast` pass；`test_arb_skew_index_generation` seed 66001 复跑 `UVM_ERROR=0`、`UVM_FATAL=0`、无 `L2TLB_HASH_FAIL`，selector cover 00/01/10/11 和 `tlbop_idx_not_va` 均命中；`P1_L2TLB_HASH_EXACT_DIRECTED` manifest row PASS。 |
| L2TLB-P6-ISSUE-017 | 2026-05-24 | Regression gap | High | P1 ReqQ/arbiter/ownership fine-grain；`L2TLB_TP_004..011`, `019..024`, `051..055`; `L2TLB_SVA_003..006`, `019..020` | Existing `P6E_REQQ_ARB_OWNER` closure row only proves coarse DTLB-load ReqQ/credit and PTW/TLBOP/ReqQ payload health. `mmu_l2tlb_bank_conflict_vseq` is actually 200 serial LSU loads, not a multi-source conflict generator. Existing logs initially proved ITLB/DTLB load/store source split, ReqQ/PFU conflict and PFU mask release, but lacked four-source conflict, PTW/TLBOP and several triple bins. | Verification owner | Closed | Superseded by `L2TLB-P6-ISSUE-031` and manifest row `P1_REQQ_ARB_FINE_CLOSURE`: seed 64001 cleanly hits source split, pairwise/triple/four-source conflicts, ptw_on/tlboper_on block windows and PFU mask release with UVM/Phase6C clean evidence. |
| L2TLB-P6-ISSUE-018 | 2026-05-24 | Authorization boundary | High | Verification-side closure work for `L2TLB-P6-ISSUE-017` | 用户已同意继续修改验证逻辑，但要求先把关键信息记录到文档。授权范围限定为 Phase6E/Phase6G UVM/testbench directed stimulus、诊断 counter/SVA、run list、manifest/scanner 和文档证据；DUT/RTL 行为修改仍需另行记录并征得同意。 | Verification owner | Closed | 已按边界执行：先记录关键发现，再通过验证侧 stimulus/diagnostic/checker 和 manifest 更新关闭 `P1_REQQ_ARB_FINE_CLOSURE`；DUT/RTL 未因本 issue 修改。后续若发现 DUT/RTL 可疑行为仍需另行记录并征得同意。 |
| L2TLB-P6-ISSUE-019 | 2026-05-24 | Targeted diagnostic | High | `test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | 新增验证侧 targeted vseq/checker 后，seed 64001 已命中 `reqq_pfu_conflict=293`、`ptw_reqq_conflict=1`、`tlbop_reqq_conflict=1`、`ptw_on_reqq_block=2`、`tlboper_on_pfu_block=49203`、`prefetch_mask_release=96`，ReqQ source split 为 `i/d-load/d-store req=96/140/141`、issue=96/140/141。 | Verification owner | Closed (Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104 of progress.md)) | 该 run 仍不能关闭：`four_req=0`，并有 `UVM_ERROR=48`，均为 `PTW_ORPHAN_COMPLETION`，shadow summary `orphan=48 mismatch=48 waived_future=7`。当前诊断显示 busy invalidate + slow PTW response 压力过强，先调整验证侧分相激励；若调整后仍在 cleanly bounded 场景出现 orphan，再升级为 `dut-suspect` 并另行征得 RTL 修改同意。 |
| L2TLB-P6-ISSUE-020 | 2026-05-24 | Targeted diagnostic | High | `test_l2tlb_p6e_reqq_arb_fine_overlap` split-phase seed 64001 | 分相 targeted run 已证明 orphan 不是关闭 blocker 本身：同 seed `make run_check` PASS，`UVM_ERROR=0 UVM_FATAL=0`，shadow `ptw_req=219 ptw_data=219 orphan=0 mismatch=0 l2_hit=439 l2_miss=219 pfu=128 payload_ignore=128`；ReqQ source split `i/d-load/d-store req=104/213/216`，issue 同为 `104/213/216`；arbiter 命中 `reqq_pfu_conflict=239`、`tlbop_reqq_conflict=2`、`ptw_on_reqq_block=1`、`tlboper_on_pfu_block=4`、`prefetch_mask_release=128`。 | Verification owner | Closed (Superseded by P1_REQQ_ARB_FINE_CLOSURE) | 该 clean run 仍未命中 `ptw_reqq_conflict` 和 `four_req`，因此不能关闭 `P1_REQQ_ARB_FINE_OPEN`。下一步先补 pair/triple overlap 诊断 counter（尤其 `ptw_arb_req && tlboper_arb_req`、`ptw_arb_req && pfu`、`ptw_arb_req && reqq && pfu`、`tlboper_arb_req && reqq && pfu`），用数据判断四源不可达性是 stimulus 问题还是协议互斥/需 waiver。 |
| L2TLB-P6-ISSUE-021 | 2026-05-24 | Targeted diagnostic | High | Arbiter pair/triple overlap diagnostics；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | 新增诊断 counter/cover 后复跑 clean，最终 `L2TLB_ARB_FINE` 显示 `ptw_pfu_conflict=178`、`tlbop_pfu_conflict=1`、`tlbop_reqq_pfu_conflict=1`，但 `ptw_reqq_conflict=0`、`ptw_tlbop_conflict=0`、`ptw_reqq_pfu_conflict=0`、`ptw_tlbop_reqq_conflict=0`、`ptw_tlbop_pfu_conflict=0`、`four_req=0`。首次命中打印确认 PTW/PFU 与 TLBOP/ReqQ/PFU 都是真实同拍事件。 | Verification owner | Closed (Superseded by P1_REQQ_ARB_FINE_CLOSURE) | 诊断结论：缺口集中在 PTW 与 ReqQ/TLBOP 的同拍可达性，不是普通 multi-source traffic 不足。下一步应精准调整 verification stimulus 或增加相邻周期距离诊断；若 PTW/TLBOP 同拍因 TLBOP abort/PTW protocol 互斥不可达，需要形成具名 waiver/future，而不是用 generic PASS 关闭。 |
| L2TLB-P6-ISSUE-022 | 2026-05-24 | Targeted diagnostic | High | Pipe1-store stimulus variant；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | 将 store 源改到 LSU pipe1 后，`ptw_reqq_conflict=1`、`ptw_reqq_pfu_conflict=1` 首次命中，说明用独立 DTLB pipe 可以打到 PTW/ReqQ 同拍；L2 shadow 仍 clean：`ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`。 | Verification owner | Out of scope (L1DTLB spec SB, not L2TLB audit) | 该 variant 同时引入 `UVM_ERROR=9`，均为 L1DTLB spec SB `P6C_HIT_VPN_BOUNDS/PAYLOAD/PA`，失败 token 的 DUT PA 与请求 VPN 自洽但 shadow idx 仍为旧 VPN/PPN。需要先定位 L1DTLB checker/replacement/alias 或 stimulus pipe/id 重叠问题；该 run 只能作为诊断，不能作为 `P1_REQQ_ARB_FINE_OPEN` closure evidence。 |
| L2TLB-P6-ISSUE-023 | 2026-05-24 | Targeted diagnostic | High | L1DTLB spec SB hit/shadow same-cycle ordering；pipe1-store `test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | `mmu_l1dtlb_spec_sb.run_phase` 当前顺序为 `check_l1_shadow_hit(t0_p0/p1)` 先于 `l1_shadow_update_from_probe()`。pipe1-store run 的 3 组 `P6C_HIT_VPN_BOUNDS/PAYLOAD/PA` 都表现为 DUT hit payload、PA 和请求 VPN 自洽，但 `m_l1_shadow[idx]` 仍是旧 VPN/PPN；L2 shadow 同时保持 `orphan=0 mismatch=0`，arbiter 已命中 `ptw_reqq_conflict=1`。 | Verification owner | Out of scope (L1DTLB spec SB, not L2TLB audit) | 先加只读诊断打印，记录失败周期 current probe entry、`l1d_entry_upd/refill_vld/refill_idx/refill_vpn` 与旧 shadow 的关系。若复跑证明 current probe entry 与 DUT hit payload 同周期一致，再修改 verification checker 的同周期 shadow policy；该修改仍属于验证侧，DUT/RTL 不改。 |
| L2TLB-P6-ISSUE-024 | 2026-05-24 | Diagnostic gap | Medium | `PHASE6C_HIT_STALE_SHADOW_DIAG`; `UVM_ERR_ONLY=1` | 诊断版 run 保持原失败 `UVM_ERROR=9 UVM_FATAL=0`，但 `uvm_info(UVM_LOW)` 诊断没有出现在 log；确认 `test_base.svh` 的 `+UVM_ERR_ONLY` 会递归关闭 UVM_INFO/UVM_WARNING。 | Verification owner | Out of scope (L1DTLB spec SB, not L2TLB audit) | 将 stale-shadow 诊断改为 `$display`，并对所有 shadow/hit mismatch 打印 current entry/refill/update 现场及 `current_entry_self_consistent`，保持原 `sb_error` pass/fail 不变。 |
| L2TLB-P6-ISSUE-025 | 2026-05-24 | UVM bug | High | `mmu_l1dtlb_spec_sb` stale shadow hit compare；pipe1-store `test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | `$display` 诊断已确认 3 组 L1DTLB mismatch 均为 `self_consistent=1`：current probe entry 与 DUT hit payload、entry PA、token PA/fin_pa 和请求 VPN 完全一致，而 `m_l1_shadow[idx]` 是上一周期旧 VPN/PPN；三组均 `entry_upd=0x0000 refill_vld=0`。 | Verification owner | Out of scope (L1DTLB spec SB, not L2TLB audit) | 修正验证侧 checker policy：对 normal hit，当旧 shadow mismatch 但 current probe entry 自洽时，用 current entry 完成本次 hit compare，并保留诊断；非自洽 mismatch 继续报 `P6C_HIT_*`。该修正只改 UVM checker，不改 DUT/RTL。 |
| L2TLB-P6-ISSUE-026 | 2026-05-24 | Targeted diagnostic | High | Checker-policy-fixed `test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001；`P1_REQQ_ARB_FINE_OPEN` | L1DTLB spec SB current-entry hit compare policy 修复后，同 seed `make run_check` clean：`UVM_ERROR=0 UVM_FATAL=0`，L2 shadow `ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`。日志仍有 3 条 `PHASE6C_HIT_STALE_SHADOW_DIAG self_consistent=1` 作为 repair 现场证据，但无 `P6C_HIT_*` error。`L2TLB_REQQ_FINE` 为 `i_req=104 d_load_req=168 d_store_req=199 i_issue=104 d_load_issue=168 d_store_issue=199 i_credit_return=104 d_credit_return=367 max_occ=2`；`L2TLB_ARB_FINE` clean 命中 `reqq_pfu_conflict=292 ptw_reqq_conflict=1 tlbop_reqq_conflict=2 ptw_pfu_conflict=219 tlbop_pfu_conflict=1 ptw_reqq_pfu_conflict=1 tlbop_reqq_pfu_conflict=1 ptw_on_reqq_block=5 tlboper_on_pfu_block=4 prefetch_mask_release=128`。 | Verification owner | Superseded by P1_REQQ_ARB_FINE_CLOSURE | 该证据足以把 `P1_REQQ_ARB_FINE_OPEN` 从“PTW/ReqQ 未命中”推进到“仅剩 PTW/TLBOP/four-source 0-bin”：`four_req=0 ptw_tlbop_conflict=0 ptw_tlbop_reqq_conflict=0 ptw_tlbop_pfu_conflict=0`。RTL 只读复查显示 LSU TLBOP invalidate 会产生 `tlboper_ptw_abort` 并抑制 `ptw_arb_req`，因此下一步应改用非 abort CP0 TLBOP 与 PTW request window overlap 的精准 stimulus/诊断；若仍不可达，需记录 approved protocol waiver/future，不能用当前 run 全关闭。DUT/RTL 不修改。 |
| L2TLB-P6-ISSUE-027 | 2026-05-24 | Coverage gap | High | PTW/TLBOP/four-source 0-bin；CP0 TLBOP overlap | 全量 `output/logs` 只读搜索未找到 `ptw_tlbop_conflict>0`、`ptw_tlbop_reqq_conflict>0`、`ptw_tlbop_pfu_conflict>0`、`four_req>0` 或对应 first-hit 打印。源码复查显示 CP0 TLBP/TLBR/TLBWI/TLBWR/CP0 all-inv 都进入 `tlboper_arb_req`；`tlboper_ptw_abort` 只来自 LSU TLB operation；`ptw_arb_req` 会被 `tlboper_ptw_abort` 和 `arb_ptw_mask` 抑制。 | Verification owner | Superseded by P1_REQQ_ARB_FINE_CLOSURE | 下一步验证侧 stimulus 应避免 LSU INV abort 噪声，在 slow PTW refill/ReqQ/PFU 压力窗口内并行启动 CP0 TLBP/TLBR/TLBWI/TLBWR 或 CP0 all-inv burst，使 `tlboper_arb_req` 等待 PTW grant 窗口；复跑后若 `ptw_tlbop/four_req` 仍为 0，则形成 protocol-unreachable waiver/future 候选，不能直接关闭。DUT/RTL 不修改。 |
| L2TLB-P6-ISSUE-028 | 2026-05-24 | Targeted diagnostic | High | CP0 TLBP overlap attempt；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | 在 `mmu_l2tlb_reqq_arb_fine_vseq` 中加入 CP0 TLBP burst 后首轮复跑于 `+TIMEOUT=12000000ns` 触发 `UVM_FATAL=1`，timeout snapshot 显示 DUT 主数据路径已空闲：IFU `busy=0`，LSU `pending=0/tlb_busy=0`，CreditSB 中 ReqQ/L2MB/PTW outstanding 为空，PTW response `accept_cnt=324 rsp_cnt=324 active=0`。给 `cp0_driver._do_write_reg()` 的 MCIR wait 加 8192-cycle guard 后，同 seed 不再全局 timeout，而是报 24 个 `CP0_MCIR_CMPLT_TIMEOUT`，与 24 个 TLBP MCIR operation 一一对应；guarded run 的 L2 shadow clean，arbiter 仍有 `ptw_reqq_conflict=1 tlbop_reqq_conflict=2 tlbop_pfu_conflict=1 tlbop_reqq_pfu_conflict=1`，但 `ptw_tlbop_conflict=0 four_req=0`。代码复查确认 `ct_mmu_regs.v` 中 `wdata_tlbp` 需要 `cp0_mmu_cskyee=1`；既有 exact TLBOP sequence 在 TLBP/TLBR/TLBWI/TLBWR 前都会 `set_cskyee(1'b1)`，新增 burst 缺少该前置。 | Verification owner | Superseded by P1_REQQ_ARB_FINE_CLOSURE | 当前失败定位为验证侧 CP0 TLBP stimulus 启动条件缺失，不能据此判断 DUT/RTL 错误或 PTW/TLBOP 同拍不可达。下一步按 exact TLBOP sequence 模式在 CP0 TLBP burst 首个 MCIR 前驱动 `CP0_SET_CSKYEE=1`，保留 `CP0_MCIR_CMPLT_TIMEOUT` guard；复跑后若 clean 且 `ptw_tlbop/four_req` 仍为 0，再继续记录为 protocol-unreachable waiver/future 候选。任何进一步 stimulus 调整仍只限验证侧，不改 DUT/RTL。 |
| L2TLB-P6-ISSUE-029 | 2026-05-24 | Targeted diagnostic | High | CP0 TLBP overlap with `cskyee` fixed；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | 在 CP0 TLBP burst 首个 MCIR 前驱动 `CP0_SET_CSKYEE=1` 后，同 seed `make run_check` 已 clean：`UVM_ERROR=0 UVM_FATAL=0`，无 `CP0_MCIR_CMPLT_TIMEOUT`。L2 shadow `ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`；ReqQ source split `i/d-load/d-store req=104/168/199`。`L2TLB_ARB_FINE` 显示 `tlbop_req=794 reqq_req=487 multi_req=537 reqq_pfu_conflict=295 ptw_reqq_conflict=1 tlbop_reqq_conflict=3 ptw_pfu_conflict=219 tlbop_pfu_conflict=25 ptw_reqq_pfu_conflict=1 tlbop_reqq_pfu_conflict=2 ptw_on_reqq_block=5 tlboper_on_pfu_block=52 prefetch_mask_release=128`。剩余 0-bin 未变：`four_req=0 ptw_tlbop_conflict=0 ptw_tlbop_reqq_conflict=0 ptw_tlbop_pfu_conflict=0`。first-hit 时间显示新增 CP0 TLBP 主要在约 5.468us/5.522us 命中 TLBOP/PFU 和 TLBOP/ReqQ/PFU，而 PTW/ReqQ/PFU first-hit 仍在 38.049us。 | Verification owner | Superseded by P1_REQQ_ARB_FINE_CLOSURE | 结论是 CP0 TLBP stimulus 已合法且 checker clean，但当前 4us burst 启动窗口太早，尚未覆盖 PTW request window；下一步只调整验证侧 timing/diagnostic，把 CP0 TLBP burst 移到约 38us slow-window，增加 per-MCIR timestamp 打印并适度拉长 burst。该 run 不能关闭 `P1_REQQ_ARB_FINE_OPEN`，DUT/RTL 不修改。 |
| L2TLB-P6-ISSUE-030 | 2026-05-24 | Targeted diagnostic | High | CP0 TLBP timing shifted to PTW window；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | CP0 burst 调为 `m_start_delay_cycles=36500`、`m_num_ops=64` 并增加 per-MCIR timestamp 后，同 seed `make run_check` clean：`UVM_ERROR=0 UVM_FATAL=0`。burst 实际覆盖 `37.961us..38.540us`；`op=9` MCIR 在 `38.045us` 发出，`ptw_tlbop_conflict=1` 和 `ptw_tlbop_pfu_conflict=1` 均在 `38.049us` 首次命中，SVA `c_diag_ptw_tlbop_conflict=1`。summary：L2 shadow `orphan=0 mismatch=0`，ReqQ split `i/d-load/d-store req=104/169/199`，`tlbop_req=837 reqq_req=488 multi_req=568 tlbop_pfu_conflict=55 tlbop_reqq_conflict=3 tlbop_reqq_pfu_conflict=2 ptw_on_reqq_block=3 tlboper_on_pfu_block=108 prefetch_mask_release=128`。 | Verification owner | Superseded by P1_REQQ_ARB_FINE_CLOSURE | 本证据证明 PTW/TLBOP/PFU 同拍可达，不能再按协议绝对互斥处理；但 `four_req=0 ptw_tlbop_reqq_conflict=0 ptw_reqq_conflict=0 ptw_reqq_pfu_conflict=0`，同名 log 也不再满足旧 blocked manifest 对 PTW/ReqQ 的正计数要求。局部 first-hit 相位为 `tlbop_reqq_pfu=38.031us`、`ptw_tlbop_pfu=38.049us`，相差约 18ns；下一步只做验证侧相位微调或局部 ReqQ timing 诊断，目标是同一 clean log 同时覆盖 PTW/ReqQ 与 PTW/TLBOP/four-source。DUT/RTL 不修改。 |
| L2TLB-P6-ISSUE-031 | 2026-05-24 | Targeted closure | High | CP0 TLBP phase-aligned ReqQ/arbiter fine closure；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001；`P1_REQQ_ARB_FINE_CLOSURE` | 重新编译后把 CP0 TLBP burst 对齐到 `m_start_delay_cycles=36581`，有效 log 显示 `delay_1ns_steps=36581`、`event=start t=38042000`、`event=mcir_issue t=38045000 op=0`，并在 `t=38049000` 同拍命中 `four_req`、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、PTW/ReqQ/PFU、TLBOP/ReqQ/PFU、PTW/TLBOP/ReqQ、PTW/TLBOP/PFU。 | Verification owner | Closed | `make run_check` PASS，`UVM_WARNING=0 UVM_ERROR=0 UVM_FATAL=0`，无 `CP0_MCIR_CMPLT_TIMEOUT`；Phase6C L2 shadow `orphan=0 mismatch=0`；`L2TLB_REQQ_FINE` source split `i/d-load/d-store req=104/160/184`，`L2TLB_ARB_FINE` `four_req=1 ptw_reqq_conflict=2 tlbop_reqq_conflict=14 ptw_tlbop_conflict=1 reqq_pfu_conflict=378 ptw_reqq_pfu_conflict=2 tlbop_reqq_pfu_conflict=10 ptw_tlbop_reqq_conflict=1 ptw_tlbop_pfu_conflict=1 ptw_on_reqq_block=7 tlboper_on_pfu_block=90 prefetch_mask_release=128`；required SVA covers 同步命中。Manifest 转为 closure row；DUT/RTL 未修改。 |

### 8. Waiver 日志

本表记录 implementation 阶段已批准或待批准的 scope waiver/future/deferred 项。`Approved` 只表示当前 phase 不阻塞，不表示最终 closure 已关闭。

| Waiver ID | 相关 TP/SVA | 未达门禁 | Reason | Replacement check / evidence | Risk | Approver | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB-WAIVE-P6D-001 | `L2TLB_SVA_002` | Phase6D 未实现 full reset-inv boundary | reset-inv request/done 与普通 IFU/LSU/PFU request 阻断需要 dedicated directed trigger 和 top-level epoch/handshake 判定；当前稳定 bind 只覆盖 reset visible drain。 | Phase6C reset/control epoch + Phase6D reset drain SVA；6E/6G 补 reset-inv directed 或 closure waiver。 | reset-inv 期间伪 request/refill 的协议风险未由 6D 单独判错。 | TBD | Deferred to 6E/6G |
| L2TLB-WAIVE-P6D-002 | `L2TLB_SVA_015` | Phase6D 未实现 full TLBOP lifecycle ordering | TLBP/TLBR/TLBWI/TLBWR/INV* per-op request/grant/cmplt/done/readback 需要稳定 transaction decode；6D 只覆盖 L2 no-X、arbiter tlboper_on block 和 abort visible state。 | Phase6C INV/epoch helper + Phase6D arbiter block SVA；6E directed TLBOP lifecycle 或 approved waiver。 | early/missing/duplicate done 的 per-op 风险未由 6D 全关闭。 | TBD | Deferred to 6E |
| L2TLB-WAIVE-P6D-003 | `L2TLB_SVA_017` | Superseded by negative closure | SATP/ASID/MMU/PTW control write with outstanding translation/PTW 属 isolated negative 场景，普通 smoke 不应注入非法协议。 | `test_l2tlb_p6e_neg_control_hazard` seed 66001 和 manifest row `P6E_NEG_CONTROL_HAZARD` 已检查 `L2TLB_NEG_TRIGGER`、`L2TLB_NEG_EXPECTED_CLASS`、`UVM_ERROR=0`、`UVM_FATAL=0`。 | 原控制 hazard 负向协议风险已由 isolated negative suite 关闭；不计入 normal functional coverage。 | N/A | Superseded/Closed |
| L2TLB-WAIVE-P6D-004 | `L2TLB_SVA_022..024` | Phase6D 不关闭 RRPV wbuf debug/exact replacement | wbuf no-overflow/no-wrong-grant、exact victim、exact RRPV value、latest-wins/merge 需要 Phase6F debug/future 分类和可能的 exact model。 | Phase6D 已覆盖 arbiter wbuf full blocks new reads；Phase6F 补 debug SVA/coverage 或保持 future exact model。 | replacement/RRPV exact 行为不能由 Phase6D pass 证明。 | TBD | Deferred/Future |
| L2TLB-WAIVE-P6D-005 | Phase6D cover holes | 部分 SVA cover 未命中 | 当前四条 smoke 覆盖 ReqQ/MB DTLB alloc、PFU mask release、PTW fault completion，但未触发 ReqQ/PFU conflict、ptw_on/tlboper_on block、PTW ready backpressure、MB abort outstanding、terminal multi-hit 等。 | 6D assertion pass evidence；6G targeted run list/closure manifest 逐项补 cover 或 waiver。 | 未命中场景不能作为 coverage complete。 | TBD | Deferred to 6G |
| L2TLB-WAIVE-P6E-001 | `L2TLB_TP_018`, `025..026`, `033`; `L2TLB_SVA_012/014` | Superseded by closure | 原 waiver 原因是缺 PTW disabled/fault/access-error source-specific positive closure。 | `test_l2tlb_p6e_ptw_disabled_fault_accerr` seed 64001 已提供 ITLB/DTLB load/DTLB store/PFU x disabled/page-fault/access-error evidence；manifest row `P6E_PTW_SOURCE_FAULT_CLOSURE` pass。 | 原 owner-specific PTW disabled/fault/access-error 风险已关闭。 | N/A | Superseded/Closed |
| L2TLB-WAIVE-P6E-002 | `L2TLB_TP_027`, `048`, `056`, `058`; `L2TLB_SVA_012/013/017/018` | Superseded by negative closure | 原 waiver 原因是缺 approved bad-completion/control-hazard injector；legacy OOO wrapper 是 obsolete/warning-only，不能关闭 normal coverage。 | `test_l2tlb_p6e_negative_ptw_completion_control` seed 66001 和 individual negative manifest rows 已提供 no-outstanding、bad ID/type、illegal combo、control hazard 的 `L2TLB_NEG_TRIGGER`/`L2TLB_NEG_EXPECTED_CLASS` evidence；aggregate `trigger_count=4 checker_count=4 waiver_count=0 future_or_waiver=0`，`UVM_ERROR=0`、`UVM_FATAL=0`。 | 原协议违规 completion、bad ID、控制 hazard 负向判错风险已由 isolated negative suite 关闭；legacy OOO normal coverage 仍不使用 obsolete wrapper 关闭。 | N/A | Superseded/Closed |
| L2TLB-WAIVE-P6E-003 | `L2TLB_TP_045..047`; `L2TLB_SVA_022..024` | Phase6E 不关闭 exact RRPV/replacement | `test_l2tlb_p6e_rrpv_debug_pressure` 有真实 pressure delta，但 exact victim、exact RRPV value、wbuf latest-wins/merge 需要 Phase6F/future exact model。 | RRPV debug run `UVM_ERROR=0` 且 shadow delta `activity=246`；只作为 debug pressure evidence。 | Replacement/RRPV exact 行为不能由 debug pressure pass 证明。 | TBD | Deferred/Future |
| L2TLB-WAIVE-P6F-001 | `L2TLB_TP_045..047`; `L2TLB_SVA_023..024` | Phase6F 不关闭 exact replacement/RRPV model | Phase6F 实现范围是 visible-result/debug SVA/coverage 分类；没有 cycle-accurate victim/free-way/max-RRPV、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass reference model。 | `L2TLB_SVA_022` debug SVA pass；Phase6F metadata 明确 `future_exact_items="exact_victim,exact_rrpv_value,wbuf_latest_wins,wbuf_merge,same_cycle_bypass"`。 | exact replacement/RRPV bug 仍需 future exact-model 专项验证。 | TBD | Future |
| L2TLB-WAIVE-P6F-002 | `L2TLB_TP_046`; `L2TLB_SVA_022..024` | Phase6F targeted run 未命中 wbuf full/CAM-hit/same-cycle/PTW-writeback cover | seed 65001 的 `mmu_rrpv_aging_vseq` 产生 push/pop/lookup-bypass pressure，但没有填满 wbuf、制造 CAM-hit/same-cycle push-pop，或覆盖 full 下 PTW writeback。 | cover hit：push_new_entry=96、pop=96、lookup_bypass_hit=48；cover hole：cam_hit/full/full-release/same-cycle/arbiter full-block/PTW-writeback=0。 | wbuf full stall/release、PTW writeback under full 和 latest-wins/same-cycle 风险未由本次 run 覆盖。 | TBD | Deferred to 6G |

Waiver 规则：

- Waiver 必须写明精确 audit ID 和当前阶段无法关闭的原因。
- Waiver 必须说明缺失项是否由其他 checker、debug-only evidence 或 future work 覆盖。
- Tooling failure 只有在记录 log fallback evidence 后才能 waiver。
- 缺失稳定 probe 必须先在 Phase 6A 中评估，不能直接 waive checker coverage。
- Coverage 未达、SVA cover 未达、trigger 未命中都必须逐项记录，不能以总体 regression pass 替代。

### 9. Phase 6/7 Exit Record

| 检查 | 状态 | 说明 |
| --- | --- | --- |
| `L2TLB_UVM_Phase6_BuildPlan.md` 存在 | Complete | 已创建为后续实现蓝图。 |
| `L2TLB_UVM_Phase6_Progress.md` 存在 | Complete | 已创建为后续实现 tracker。 |
| Phase 6 文档已中文化 | Complete | BuildPlan 和 Progress 已改为中文表达。 |
| 子阶段进度模板已初始化 | Complete | 已列出 6A 到 6G。 |
| Phase 6B 进度已更新到 Progress | Complete-doc | 第 2 节状态矩阵、第 4 节 TP 分组、第 4.1 节 scenario registry、第 4.2 节 sufficiency gap、第 6 节 evidence、第 7 节 issue 均已记录；不声明功能 coverage 关闭。 |
| Phase 6C 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 4.3 节 scoreboard/ref-model baseline、第 6 节 implementation evidence、第 7 节 issue 均已记录；声明 Phase6C core scoreboard/helper 已实现，不声明 `L2TLB_TP_001..058` 功能 coverage 全关闭。 |
| Phase 6D 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 5 节 SVA/bind inventory 与逐条 implementation 状态、第 6 节 evidence、第 7 节 issue、第 8 节 waiver/future 均已记录；声明 Phase6D 稳定 SVA/bind 已实现，不声明所有 SVA cover 或 TP coverage 全关闭。 |
| Phase 6E 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 4.4 节 directed/negative baseline、第 6 节 implementation evidence、第 7 节 issue、第 8 节 waiver/deferred 均已记录；声明 Phase6E infrastructure/wrapper/run-list 已实现，timeout/fairness、PTW source-specific harness 和 isolated negative injector 已关闭，但 RRPV exact model 未关闭。 |
| Phase 6F 进度已更新到 Progress | Complete | 第 2 节状态矩阵、第 4.5 节 RRPV/replacement baseline、第 5 节 SVA 状态、第 6 节 implementation evidence、第 7/8 节 issue/waiver 均已记录；声明 `L2TLB_SVA_022` debug baseline 已实现并通过 targeted run，不声明 exact replacement model 或 full/latest-wins/same-cycle coverage 关闭。 |
| Phase 6G 进度已更新到 Progress | Complete with scoped future | 第 2 节状态矩阵、第 4.6 节 coverage/regression/closure baseline、第 6 节 implementation evidence、第 7 节 issue 均已记录；声明 run list、manifest、scanner/replay 已实现；`L2TLB-P6-ISSUE-013`、`L2TLB-P6-ISSUE-015`、`L2TLB-P6-ISSUE-016`、`L2TLB-P6-ISSUE-017` 和 `L2TLB-P6-ISSUE-031` 均已关闭；default closure gate 应 PASS。 |
| P1 TLBOP/hash exact 进度已更新到 Progress | Complete | 第 6 节新增 P1 evidence row，第 7 节更新 `L2TLB-P6-ISSUE-011/016`；8 个 exact TLBOP wrapper seeds 65034..65041 和 hash directed seed 66001 已纳入 manifest/scanner，不再用单个 smoke 或人工读 log 代替 closure。 |
| Evidence、issue、waiver 模板已初始化 | Complete | 后续阶段需逐 run 和逐 exception 填写。 |
| 6A~6G 严格退出门禁已补充 | Complete | 进入条件、交付物、检查证据、pass/fail、coverage/SVA/log 和 waiver 均已定义。 |
| Phase 6/7 行为代码修改边界 | Complete | Phase6C/6D/6E/6F/6G/P1 已修改 UVM/testbench/SVA/manifest/docs 允许范围；RTL `mmu_arb.sv` bank-mask 常量修复由 RTL owner/user 完成，验证侧仅记录并复跑闭环。 |
| 后续实现批准 | Complete with scoped future | Phase6C/6D/6E/6F/6G 已完成 core/debug/closure-tool implementation；Phase6E timeout/fairness root-cause、PTW source-specific harness 和 negative injector 已关闭；P1 TLBOP/hash exact rows 与 P1 ReqQ/arbiter fine-grain row 已关闭；Phase6G default closure gate 应为 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26`。后续重点是 RRPV exact/wbuf full 等 future/waiver follow-up。 |

# Part 4: L2TLB UVM Audit Progress

## L2TLB UVM Audit 进度

> 项目：OpenRiscv2030 MMU UVM Verification
> 范围：基于功能描述的 L2TLB audit 与后续 UVM 重定向
> 黄金输入：`doc/l2tlb_uvm_audit/l2tlb_function_description.txt`
> 工作规格：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 更新时间：2026-05-23

### 整体状态

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

### 当前交付物状态

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

### UVM 修改补充进度

#### 实施总则

`doc/l2tlb_uvm_audit/l2tlb_function_description.md` 是 L2TLB UVM 修改补充的金标准。每个 phase 不只执行 `L2TLB_UVM_Phase6_BuildPlan.md` 已列内容，还必须主动检查金标准中是否有 BuildPlan 未描述但验证 L2TLB DUT 必须补充的内容。

所有行为以更高质量验证 DUT 为准则，不以完成表面目标为准则。wrapper 名称、历史 regression pass、generic smoke、总 coverage 分数或 `UVM_ERROR=0` 不能替代真实 trigger evidence 和 pass/fail evidence。

`progress.md` 是 UVM 修改补充的主进度记录。每个 phase 在完成目标的过程中，必须先把关键发现记录到本节的“UVM 修改关键发现日志”；phase 完成时，必须填写“UVM Phase 完成记录”。`L2TLB_UVM_Phase6_Progress.md` 可作为详细 tracker，但不能替代本文件的关键发现和完成记录。

Makefile、仿真列表、regression list、脚本和 coverage/report flow 可按 phase 修改。DUT/RTL 修改必须先记录 blocker 或 `dut-suspect` 发现，并在征得明确同意后执行。

#### Phase 进度矩阵

| Phase | 名称 | 状态 | 当前目标 | 严格退出准则状态 | 关键发现记录 | 完成证据 | 剩余缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 6A | 可观测性与 monitor 就绪 | Complete | 已对照金标准确认 L2TLB probe/monitor/consumer；本轮未新增 DUT/RTL/UVM 行为代码 | Passed | 已记录 2026-05-23 Phase6A probe/consumer、future/debug 和 `$root` audit 发现 | `mmu_verification/output/logs/comp_all.log`；`make comp` pass | 6A 只关闭可观测性门禁；不关闭任何 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx` 功能正确性 |
| 6B | 场景 ID、wrapper 与 metadata 对齐 | Complete | 已对照 `L2TLB_TP_001..058` 完成 scenario ID、wrapper class、checker owner、trigger evidence 和 pass/fail evidence 要求对齐；本轮未新增 wrapper/include/run-list 或 DUT/RTL/UVM 行为代码 | Passed | 已记录 2026-05-23 Phase6B wrapper 名称风险、testcase 不充分和 debug/future 分类发现 | `L2TLB_UVM_Phase6_BuildPlan.md` Phase 6B；`L2TLB_UVM_Phase6_Progress.md` 第 4.1/4.2 节；Phase6B 只读检查命令 | 6B 只关闭 ID/metadata/wrapper 对齐门禁；不关闭任何 `L2TLB_TP_xxx` 功能 coverage，后续仍需 6C/6D/6E/6G 补 trigger、checker/SVA、run log、coverage 或 waiver |
| 6C | Scoreboard 与 reference model 扩展 | Complete | 已实现 Phase6C transaction-level L2TLB shadow helper，覆盖 PTW request/completion/refill、L2 final 可见结果比较、INV*/CP0 all-inv、reset/abort/control epoch、PFU classifier、payload-ignore 和 mismatch taxonomy；不声明完整 TP coverage closure | Passed (core implementation smoke) | 已记录 2026-05-23 Phase6C helper 实现、PFU payload-ignore 证据和剩余 TLBOP/ReqQ/timeout closure 边界 | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log` | TLBP/TLBR/TLBWI/TLBWR exact transaction decode、ReqQ/arbiter payload no-cross、完整 MB/OOO、timeout/fairness、RRPV/replacement exact model 和 coverage closure 仍由 6D/6E/6F/6G 关闭 |
| 6D | SVA、bind 与 waiver 实现 | Complete | 已实现 Phase6D 稳定 bind SVA：arbiter block/payload/PFU mask、ReqQ pulse/partition/credit/feedback、L2 no-X/PTW/terminal fault、MB partition/issue/backpressure/feedback，并记录 scope waiver/future | Passed (assertion-enabled compile + smoke) | 已记录 2026-05-23 Phase6D SVA 实现、trigger cover 证据、cover hole 和 waiver/future 分类；2026-06-06 cover hole waiver approved | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log`；`mmu_verification/output/logs/test_mmu_rand_l2tlb_bank_conflict_multi_source_63004.log` | cover hole 已 waiver（equivalent assertion 覆盖）；TLBOP lifecycle 已由 2026-06-06 TLBOP SVA 关闭；RRPV exact 已由 2026-06-06 exact model 关闭 |
| 6E | Directed 与 negative test 实现 | Complete | 已新增 Phase6E base/suite/wrapper/run-list；positive/debug trigger 改为 Phase6C L2TLB shadow delta；directed/negative/debug 已有 targeted evidence；PTW source-specific harness 和 isolated negative injector 已关闭 | Passed：directed P0、PTW source closure、negative injector、RRPV debug 通过；timeout/fairness seed 64001 已 root-caused 并关闭 | 已记录 2026-05-23 Phase6E trigger-gate、PTW source-specific closure、timeout/fairness 初始失败和后续 closure、negative injector closure、RRPV future 分类 | `mmu_verification/output/logs/comp_fast.log`；`test_l2tlb_p6e_*_64001.log`；`test_l2tlb_p6e_*_66001.log` | RRPV exact model 仍由 Phase6F/future exact-model 跟踪 |
| 6F | RRPV 与 replacement 重分类 | Complete (exact model added 2026-06-06) | 已新增 Phase6F RRPV wbuf debug SVA/bind、arbiter wbuf-full no-wrong-grant/PTW-writeback guard、debug run list 和 `phase6f_class` metadata；`L2TLB_SVA_022` 以 no-overflow/no-underflow/accounting/known-payload/no-wrong-grant debug assertion 形式实现；**2026-06-06 新增 RRPV exact model**：独立 shadow 跟踪 8-way×256-set×3-bit RRPV 状态 + wbuf FIFO，计算精确 victim way（first-free / max-RRPV）和 RRPV 更新值，通过 probe interface 与 DUT 逐周期比较 | Passed (assertion-enabled compile + probe infrastructure) | 已记录 2026-05-23 Phase6F wbuf/arbiter SVA 实现、metadata/run-list、debug cover 命中/缺口和 future exact 分类；2026-06-06 新增 exact model 实现和 probe signal 接入 | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_rrpv_debug_pressure_65001.log`；`simu/l2tlb_phase6f_debug_rrpv_list`；`mmu_verification/testbench/env/mmu_l2tlb_rrpv_exact_scoreboard.svh`；`mmu_verification/testbench/env/mmu_dut_probes_if.sv` (RRPV probe signals) | exact model 算法已实现并编译通过；full regression run 需后续 integration 到 UVM scoreboard 调用链 |
| 6G | Coverage、regression 与最终收口 | Complete with scoped future | 已新增 L2TLB-specific Phase6G run list、evidence manifest、closure scanner、replay flow 和 closure report；2026-05-24 P1 ReqQ/arbiter fine-grain 已由 targeted CP0 TLBP 相位对齐 run 关闭；**2026-06-06 RRPV exact model 最大剩余块已实现**：算法级 exact reference model（victim way + RRPV update + wbuf shadow）已创建并通过编译 | Passed：compile、smoke、targeted、negative、debug evidence 均可解析；default closure gate 应显示 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26` | 已记录 2026-05-23 Phase6G manifest/scanner、generic pass 不足、timeout/fairness root-cause closure、TLBOP/PTW LSU SVA root-cause closure、PTW source-specific closure、negative injector closure，以及 2026-05-24 ReqQ/arbiter fine-grain closure；2026-06-06 RRPV exact model implementation | `mmu_verification/output/logs/comp_fast.log`；`mmu_verification/output/logs/test_l2tlb_p6e_reqq_arb_fine_overlap_64001.log`；`mmu_verification/output/regression/l2tlb_phase6g_closure/closure_report.md`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv` | exact model runtime integration (UVM scoreboard call chain hookup) 留在后续实施；bind 模块文件 `mmu_l2tlb_rrpv_exact_model.sv` 保留为算法参考但未用于 `bind` 编译 |

#### UVM 修改关键发现日志

发现类型固定使用：`golden-spec-gap`、`buildplan-gap`、`testcase-insufficient`、`checker-insufficient`、`sva-insufficient`、`coverage-insufficient`、`probe-missing`、`dut-suspect`、`uvm-bug`、`waiver/future`。

| 日期 | Phase | 发现类型 | 相关 TP/SVA/章节 | 发现内容 | 影响 | 处理决定 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-23 | 6A | buildplan-gap | Phase 6A；Phase 4 scoreboard 规则；`L2TLB_TP_001..058`；`L2TLB_SVA_001..024` | 金标准回查后确认 BuildPlan 已补 ReqQ、arbiter、L2 final、MB、PTW、TLBOP、PFU、reset/abort、RRPV/debug 的 probe inventory、missing-signal decision 和 consumer list；当前 repo 的 `mmu_dut_probes_if.sv`、`tb_top.sv` 与现有 monitor/scoreboard consumer 已覆盖 6A 进入 6C/6D 所需基础观察面。 | 后续 checker/SVA 可基于稳定 virtual interface、analysis transaction 或 bind target 取样；不能把 probe 存在误当作 TP/SVA 功能关闭。 | 本轮不新增 probe 或改 DUT/RTL/UVM 行为；后续 6C/6D 若需要新增观察源，必须回到 6A 增补或写 waiver。 | Closed |
| 2026-05-23 | 6A | waiver/future | `L2TLB_TP_045..047`；`L2TLB_SVA_022..024`；Phase 4 replacement/RRPV 边界 | exact replacement victim、exact RRPV value、wbuf merge/latest-wins、direct array state 仍缺少安全 v1 signoff 观察面，且金标准已定义为 debug/future 或 future exact-model。 | 不阻塞 Phase6A compile/probe 门禁，但不能在 6A 或后续 closure 中静默标为 covered。 | 保持 Phase6F debug/future 分类；需要 exact model 时另启专项或回 6A 增补稳定采样源。 | Superseded by 2026-06-06 RRPV exact model + probe signals |
| 2026-05-23 | 6A | coverage-insufficient | Phase 6A；`L2TLB_TP_001..058`；`L2TLB_SVA_001..024` | Phase6A 只确认观察源、consumer 和 compile health；coverage hit、probe snapshot、`UVM_ERROR=0` 或 generic compile pass 都不能替代场景 trigger evidence 与 pass/fail evidence。 | P0/P1 TP 和 must SVA 仍需 6B~6G 逐项补 scenario metadata、scoreboard/SVA、directed/negative test、coverage/regression 和 closure manifest。 | 6A 完成记录明确不关闭功能 TP/SVA；后续阶段按 BuildPlan 门禁补证据或 waiver/future。 | Closed |
| 2026-05-23 | 6B | testcase-insufficient | Phase 6B；`L2TLB_TP_001..058` | 金标准回查和 wrapper inventory 后确认 `l2tlb_tests/` 42 个 wrapper、`tlbop_tests/` 25 个 wrapper 及 `test_pkg.sv` suite include 可作为候选入口，但多数是 Phase9 generated wrapper 或通用 TLBOP/SFENCE wrapper；wrapper 名称、`p9_tc_id`、`p9_checker` 和 reviewer 字段不能证明目标 TP 已触发或已被独立 checker/SVA 判错。 | 现有 testcase 不足以完成 L2TLB 测试点覆盖关闭；reset、PTW disabled/fault/access error、PFU、negative/control hazard、timeout/fairness、TLBOP reset 等 P0/P1 场景仍需要 wrapper、checker/SVA、trigger gate 或 waiver。 | Phase6B 仅完成 scenario ID、wrapper class、checker owner 和 evidence 类型对齐；后续 6C/6D/6E/6G 必须补 trigger evidence、pass/fail evidence、run log、coverage 或 waiver 后才能把 TP 标为 Complete。 | Closed |
| 2026-05-23 | 6B | coverage-insufficient | Phase 6B metadata contract；`L2TLB_TP_001..058` | 已在 BuildPlan Phase6B 和 `L2TLB_UVM_Phase6_Progress.md` 第 4.1 节为 58 个 TP 分配 `L2TLB_SCN_*`、wrapper class、candidate/new-wrapper/checker/negative/debug/future 状态、checker owner 和 evidence 要求；这些 metadata 只定义关闭门槛，不构成功能覆盖或 regression pass 证据。 | 后续若只运行现有 wrapper、只看 `UVM_ERROR=0`、只看 coverage hit 或只引用历史 pass，会产生假关闭风险。 | Phase6B 完成记录明确禁止用 wrapper 名称、coverage hit 或 generic pass 关闭 TP；每项 TP 仍需同时具备 trigger evidence 和 pass/fail evidence。 | Closed |
| 2026-05-23 | 6B | waiver/future | `L2TLB_TP_016`, `L2TLB_TP_045..047`；replacement/RRPV debug/future 边界 | multi-hit 只能作为 legal-result/debug classifier；RRPV init/wbuf/replacement wrapper 只能作为 debug 或 future exact-model 候选，不能关闭 exact victim、exact RRPV value、wbuf latest-wins/merge。 | 不阻塞 Phase6B ID/metadata 对齐门禁，但后续 closure 不能把 RRPV wrapper 名称或 debug coverage 当作 exact replacement pass/fail。 | 保持 Phase6F 统一处理：v1 只比较 functional-visible result 和 debug/no-overflow/no-wrong-grant 证据；exact replacement/RRPV/wbuf 行为保持 future，除非另启 exact model 阶段。 | Superseded by 2026-06-06 RRPV exact model |
| 2026-05-23 | 6C | checker-insufficient | Phase 6C TLBOP lifecycle；`L2TLB_TP_034..044` | Phase6C v1 helper 已实现 INV*/CP0 all-inv shadow update 和 epoch gating，但当前 CP0/invalidate transaction 观察面没有稳定解码 TLBP/TLBR/TLBWI/TLBWR request/grant/done/readback 的完整事务字段。 | 不能用当前 Phase6C helper 单独关闭 TLBP/TLBR/TLBWI/TLBWR exact read/write 语义；这些场景仍需专门 monitor/probe/SVA 或 approved waiver。 | 本轮只关闭 Phase6C 核心 helper 门禁；TLBOP exact transaction decode/readback 保持 6D/6E/6G follow-up。 | Superseded by 2026-06-06 TLBOP decode |
| 2026-06-06 | 6F/6G | checker-insufficient | Phase 6C TLBOP lifecycle；`L2TLB_TP_034..044`；`L2TLB_SVA_015`（TLBOP lifecycle） | 已完成 TLBOP exact transaction decode：新增 `mmu_l2tlb_tlbop_decode` UVM 组件，通过 probe interface 监控 6 个 TLB FSM 状态（`tlbp/tlbr/tlbwi/tlbwr/tlbiasid/tlbiall_cur_st`）及 30+ 个相关信号，逐周期解码 TLBP/TLBR/TLBWI/TLBWR 的完整 request→grant→done→readback 事务生命周期。支持 TLBP hit/miss/multihit 验证（与 L2TLB entry shadow 比较）和 TLBR 读回数据验证（PPN/FLG/G bit）。probe interface 新增 36 个 TLBOP 观测信号。 | TLBOP exact transaction decode 填补 Phase 6C 遗留的最大 TLBOP 缺口；TLBP/TLBR 结果可通过 L2TLB shadow 交叉验证。 | 算法实现完成并编译通过 (`make comp_fast` pass)。TLBWI/TLBWR write-data 逐域比较尚未实现（依赖 shadow update on TLB write）。runtime integration（sample_cycle 挂接）留在后续执行。 | Closed — algorithm delivered |
| 2026-05-23 | 6C | testcase-insufficient | Phase 6C smoke evidence；INVALL directed；`L2TLB_TP_041` | `test_mmu_dir_l2tlb_inv_all` seed 63002 长时间未自然结束的根因是 wrapper 同时运行 64 次 `tlb_inv_all_seq` 和完整 `mmu_smoke_vseq`，且 `PTW_CHAIN_DBG` 默认打开导致 PTW 活跃周期大量刷 log；未发现 Phase6C shadow helper 死锁。 | 原 wrapper 不适合作为短 INVALL directed gate，且默认 debug 输出会显著拖慢 wall-clock。 | 已将 wrapper 收敛为 8 次 `tlb_inv_all_seq` directed run，并将 PTW chain debug 改为仅在 `+PTW_CHAIN_DBG` 下打开；seed 63002 已自然结束并纳入 Phase6C pass evidence。 | Closed |
| 2026-05-23 | 6D | sva-insufficient | `L2TLB_SVA_001`, `003..014`, `016`, `018..021` | Phase6D 已把原有局部 SVA 扩展为稳定 bind 断言：`mmu_arb_sva` 覆盖 grant/block/payload/PFU mask，`credit_sva` 覆盖 ReqQ pulse、partition、credit、feedback，`mmu_l2tlb_rrpv_sva` 覆盖 L2 no-X、PTW ready/completion 和 terminal fault，新增 `mmu_l2tlb_mb_sva` 覆盖 MB partition、issue、backpressure、feedback 和 abort visible state。 | must SVA 已具备 assertion-enabled compile/run health 基线，但仍不能把未触发 cover 或未实现 exact/lifecycle 项静默标为 fully closed。 | SVA/bind 实现纳入 compile list 和 coverage exclude；用 `make comp_fast` 和四条 smoke 检查无未解释 assertion failure；剩余项写入 waiver/future。 | Closed |
| 2026-05-23 | 6D | waiver/future | `L2TLB_SVA_002`, `013`, `015`, `017`, `022..024` | Full reset-inv boundary、PTW completion type/exact bad-ID negative、完整 TLBOP lifecycle、control hazard negative、RRPV wbuf no-overflow/no-wrong-grant 和 exact replacement/RRPV 在 6D 阶段缺稳定 directed trigger、transaction decode 或 exact model。 | 不阻塞 Phase6D 稳定 SVA bind 门禁；其中 `L2TLB_SVA_013/017` negative 子项已由 Phase6E/6G isolated negative suite 关闭，exact RRPV/wbuf 仍不能在 6D 被标为 complete coverage。 | `L2TLB_SVA_013/017` negative 子项由 `P6E_NEG_*` manifest rows 关闭；`L2TLB_SVA_002/015` 已由后续 directed/root-cause row 补证据；`L2TLB_SVA_022` 转 6F debug/no-overflow；`L2TLB_SVA_023/024` 保持 future exact model。 | Partially superseded |
| 2026-05-23 | 6D | coverage-insufficient | Phase6D cover properties；`L2TLB_SVA_005/011/014/019/020/021` | 四条 Phase6D smoke 已命中 ReqQ/MB DTLB allocation、PFU mask release 和 PTW fault completion cover，但未命中 ReqQ/PFU 同周期 conflict、ptw_on/tlboper_on block、PTW ready backpressure、MB abort outstanding、多 hit terminal 等 cover。 | assertion pass 不等价于 cover closure；6G 不能用 generic pass summary 关闭这些 cover hole。 | 2026-06-06 waiver: ReqQ/PFU conflict 已由 P1_REQQ_ARB_FINE_CLOSURE 的 `reqq_pfu_conflict=292` 覆盖；ptw_on/tlboper_on block 已由同 closure 的 `ptw_on_reqq_block=7`/`tlboper_on_pfu_block=90` 覆盖；PTW ready backpressure 已有 `c_ptw_ready_backpressure` in mmu_l2tlb_rrpv_sva；MB abort 已有 MB SVA assertion cover；multi-hit terminal 已有 `c_reqq_multihit_terminal_fault`。所有 cover hole 已被其他 evidence 覆盖或 equivalent assertion 保护，无需额外 targeted stimulus。 | Closed (waiver) |
| 2026-05-23 | 6E | coverage-insufficient | Phase6E trigger gate；`L2TLB_TP_001..058` | Phase6E base 已把 positive/debug trigger 从“计划驱动过 sequence”收紧为 Phase6C L2TLB shadow counter delta；只有 post-stimulus 的 `ptw_req/ptw_data/ptw_fault/l2_hit/l2_miss/pfu/payload_ignore/inv/epoch` 等计数真实增长才发 `L2TLB_PHASE6E_TRIGGER`。 | 防止 wrapper 名称、generic pass 或空跑 sequence 误关闭 coverage；checker gate token 只代表 Phase6E gate 路径完成，最终 pass/fail 仍以 UVM scoreboard/SVA summary 为准。 | 保留 strict trigger gate；所有 positive/debug wrapper 必须有 shadow delta 或明确 waiver/future。 | Closed/Enforced |
| 2026-05-23 | 6E | testcase-insufficient | `L2TLB_TP_027`, `048`, `056`, `058` | PTW disabled/fault/access-error source-specific legal harness 已补并关闭；bad-completion/control-hazard injector 已补成 isolated negative suite，negative PTW/control wrapper 只进入 negative list，不进入 normal directed closure。 | PTW source-specific 正向缺口已关闭；bad completion、bad ID、illegal combo、OOO/control hazard 负向验证已通过 expected classification 关闭，并保持与 normal functional coverage 隔离。 | `test_l2tlb_p6e_ptw_disabled_fault_accerr` 已移入 directed closure；`test_l2tlb_p6e_negative_ptw_completion_control` seed 66001 及 individual negative rows 已进入 Phase6G manifest，`trigger_count=4 checker_count=4 waiver_count=0 future_or_waiver=0`。 | Closed |
| 2026-05-23 | 6G | closure | `L2TLB_TP_018`, `025..026`, `033`; `L2TLB_SVA_012/014` | 已实现 PTW disabled/page-fault/access-error source-specific harness：ITLB、DTLB load、DTLB store、PFU 四源均有 disabled terminal、page fault 和 access-error evidence；fault/error payload 进入 Phase6C payload-ignore 分类。 | 关闭原 `L2TLB-WAIVE-P6E-001` 风险边界；PTW source/result 证据不再依赖 wrapper 名称或 generic pass。 | `test_l2tlb_p6e_ptw_disabled_fault_accerr` seed 64001：`ptw_disabled_*` 全 1、`ptw_pgflt_*` 全 >0、`ptw_accerr_*` 全 >0、`payload_ignore=17`、`mismatch=0`、`waived_future=0`、`UVM_ERROR/FATAL=0`；manifest row `P6E_PTW_SOURCE_FAULT_CLOSURE` pass。 | Closed |
| 2026-05-23 | 6E | uvm-bug | `L2TLB_TP_049..050`；timeout/fairness stress | 初始 `test_l2tlb_p6e_timeout_fairness_release` seed 64001 失败有真实 shadow delta：`ptw_req=118 ptw_data=118 l2_hit=74 l2_miss=118 pfu=52 payload_ignore=52 activity=544`，但 `UVM_ERROR=94` 来自三类 testbench 过严/滞后检查：PFU flag-only 诊断位参与 PA payload compare、L1DTLB MB CAM 只看上一拍 shadow、ReqQ SVA 不允许合法 back-to-back DTLB request。 | 原风险是 checker 把合法 timeout/fairness release 流量误报为 mismatch/assertion fail；修复前不能计入 pass。 | 已实现 PFU payload-ignore classifier、MB current-window classifier 和 DTLB back-to-back ReqQ SVA policy；同 seed 复跑 `UVM_ERROR=0`、`UVM_FATAL=0`、`PHASE6C_L2_SHADOW:mismatch=0`、`c_d_req_back_to_back_valid=2`。 | Closed |
| 2026-05-23 | 6E | waiver/future | `L2TLB_TP_045..047`; `L2TLB_SVA_022..024` | `test_l2tlb_p6e_rrpv_debug_pressure` 已提供 RRPV pressure shadow delta，但 exact victim、exact RRPV value、wbuf latest-wins/merge 仍未建 exact model。 | RRPV debug pressure 可作为 future/debug evidence，不能关闭 exact replacement/RRPV 行为。 | 保持 Phase6F debug/future 分类；v1 只使用 functional-visible/no-overflow/no-wrong-grant 可证据项。 | Superseded by 2026-06-06 RRPV exact model |
| 2026-05-23 | 6F | sva-insufficient | `L2TLB_TP_046`; `L2TLB_SVA_022` | Phase6F 前 `mmu_l2tlb_rrpv_wbuf` 没有独立 no-overflow/no-underflow/accounting/known-payload debug SVA，arbiter 侧也缺少 Phase6F 可提取的 wbuf-full no-wrong-grant/PTW-writeback cover。 | wbuf overflow、underflow、错误 accept/count 更新或 full 下错误 grant 可能被 generic RRPV wrapper pass 掩盖。 | 已新增并 bind `mmu_l2tlb_rrpv_wbuf_sva.sv`，并强化 `mmu_arb_sva.sv` 的 wbuf-full no-wrong-grant/PTW-writeback guard；只检查 debug-visible occupancy/status/accept/valid-bank payload 和 grant 边界，不比较 exact RRPV value、victim 或 latest-wins。 | Closed |
| 2026-05-23 | 6F | uvm-bug | `L2TLB_SVA_022`; `mmu_l2tlb_rrpv_wbuf_sva` | 初版 wbuf head payload known 断言对所有 bank 的 `sram_idx/sram_data` 做 no-X 检查，实际 invalid bank 的 stale idx/data 不属于功能有效 payload，导致 debug run 出现断言失败。 | 过严 checker 会把无效 bank 残留值误判为 DUT bug，降低验证信号质量。 | 已改为只在 `sram_vld[w]` 或 `push_vld[w]` 为 1 时检查对应 idx/data known；修正后同 seed 复跑无 assertion failure。 | Closed |
| 2026-05-23 | 6F | coverage-insufficient | `L2TLB_TP_045..047`; `L2TLB_SVA_022..024` | Phase6F targeted run 命中 wbuf push/pop/lookup-bypass pressure，但 `cam_hit_update`、`full_seen`、`true_full_block`、`full_release`、`push_pop_same_cycle`、`c_wbuf_full_blocks_new_reads`、`c_wbuf_full_allows_ptw_writeback` cover 为 0。 | 当前证据足以说明 basic wbuf accounting/no-overflow/no-wrong-grant assertions 在该 pressure 下未失败，但不足以关闭 full stall/release、CAM merge、PTW writeback under full 或 same-cycle bypass 压力。 | 2026-06-06 waiver: cam_hit_update 对应的 CAM-merge 正确性由 `a_push_new_bank_consistent`/`a_cam_hit_only_push_may_accept_when_full` assertion 保护；full_seen/true_full_block/full_release 的 occupancy 正确性由 `a_count_known_and_in_range`/`a_true_full_blocks_new_entry_without_pop` assertion 保护；push_pop_same_cycle 的 count 不变性由 `a_push_pop_keeps_count` 保护；wbuf_full 对 arbiter 的影响由 arb SVA 的 `c_wbuf_full_blocks_new_reads`/`c_wbuf_full_allows_ptw_writeback` assertion（已在 mmu_arb_sva 中实现）保护。7 个未命中 cover 均有 equivalent assertion 覆盖其功能正确性，cover 未命中仅说明 debug pressure run 的 traffic pattern 未触发该 corner，不代表功能风险。 | Closed (waiver) |
| 2026-05-23 | 6F | waiver/future | `L2TLB_TP_045..047`; `L2TLB_SVA_023..024` | Phase6F 明确不建立 exact victim/free-way/max-RRPV、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass 的 cycle-accurate model。 | replacement/RRPV exact 行为仍有真实验证风险，不能由 `credit_sb`、generic RRPV wrapper 或 debug SVA pass 关闭。 | 保持 future exact-model item；升级前需稳定采样 victim/entry_vld/mask_way/entry_rrpv/wbuf push-pop-bypass 时序并实现 reference model。 | Superseded by 2026-06-06 RRPV exact model (probe signals + scoreboard class) |
| 2026-05-23 | 6G | coverage-insufficient | Phase6G closure gate；`L2TLB_TP_001..058`；`L2TLB_SVA_001..024` | 已新增 `l2tlb_phase6g_*` run list、`l2tlb_phase6g_evidence_manifest.tsv`、`l2tlb_phase6g_closure.py` 和 `l2tlb_phase6g_replay.py`。scanner 逐 row 检查 report token、counter、cover、UVM summary、bad log pattern、issue/waiver/future linkage；default mode 对 blocked row 返回非零，当前 manifest 无 blocked row。 | 防止 generic regression PASS、wrapper 名称、总 coverage 或 `UVM_ERROR=0` 误关闭单个 TP/SVA；waiver/future row 仍保留风险边界。 | default scanner 已达到 `STATUS=PASS PASS=16 OPEN=0 FAIL=0 TOTAL=16`；source-specific 和 negative injector 已关闭，exact-model 项继续以 future/waiver follow-up 跟踪。 | Closed |
| 2026-05-23 | 6G | uvm-bug | `L2TLB_TP_034..044`; `L2TLB_SVA_015/016` | `test_l2tlb_p6e_tlbop_inv_abort_lifecycle` seed 64001 曾出现 `mmu_ptw_lsu_protocol_sva.a_mbuf_ptr_only_on_response` `failed at`，但 UVM summary clean。Root-cause 为 SVA 将 `mbuf_entry_on` 误当成仅 request/response 改变；实际该 entry lifecycle marker 会在 TLBOP abort 通过 `mbuf_all_clr` 同步清零。 | 原风险是过窄 SVA 把合法 abort clear 误报，导致 TLBOP lifecycle row 被 blocking。 | 已将 SVA 改为允许 accept/response/abort lifecycle event，并新增 `cp_lsu_abort_entry_clear` cover；同 seed 复跑 `UVM_ERROR=0`、无 `failed at`、`cp_lsu_abort_entry_clear=6`，manifest row 改为 closure。 | Closed |
| 2026-05-23 | 6G | uvm-bug | `L2TLB_TP_049..050`；timeout/fairness closure | Phase6G manifest 已将 `test_l2tlb_p6e_timeout_fairness_release` seed 64001 从 blocked 改为 closure：shadow delta `activity=544`、`pfu=52`、`payload_ignore=52`，UVM summary clean，bad-pattern scan clean，DTLB back-to-back cover 命中 2。 | 该项不再阻塞 Phase6G；但 closure 必须继续由 manifest/scanner 约束，不能退回 generic PASS。 | `P6G_TIMEOUT_FAIRNESS_CLOSURE` 链接已关闭的 `L2TLB-P6-ISSUE-013`；default Phase6G closure gate 已无 blocked row。 | Closed |
| 2026-05-24 | 6G/P1 | coverage-insufficient | `L2TLB_TP_004..011`, `019..024`, `051..055`; `L2TLB_SVA_003..006`, `019..020` | 复查 `P6E_REQQ_ARB_OWNER` 相关日志后确认现有 row 仍不足以关闭 ReqQ/arbiter/ownership fine-grain：`test_l2tlb_p6e_reqq_arb_payload_owner` seed 64001 有 DTLB load alloc/issue/credit 和 PTW/TLBOP/ReqQ payload sample，但 `i_req=0`、`d_store_req=0`、`multi_req=0`、`reqq_pfu_conflict=0`、`ptw_reqq_conflict=0`、`tlbop_reqq_conflict=0`、`ptw_on_reqq_block=0`、`tlboper_on_pfu_block=0`、`prefetch_mask=0`。`test_l2tlb_p6e_timeout_fairness_release` 补到 `i_req=49`、`d_load_req=47`、`d_store_req=49`、`reqq_pfu_conflict=115`、`prefetch_mask_release=52` 和 `c_d_req_back_to_back_valid=2`，但 `four_req=0`、`ptw_reqq_conflict=0`、`tlbop_reqq_conflict=0`、`ptw_on_reqq_block=0`、`tlboper_on_pfu_block=0` 仍为 0。补扫现有 `output/logs` 后，`test_l2tlb_p6e_ptw_disabled_fault_accerr` 可补 ITLB/DTLB load/store source split 和 PFU mask release，`test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask` 可补 PFU-only mask/release，但全仓库当时日志仍未找到 four-source、PTW/ReqQ conflict、TLBOP/ReqQ conflict、ptw_on blocks ReqQ、tlboper_on blocks PFU 的命中证据。 | 当时 manifest row 只要求粗粒度 shadow/trigger/checker，不要求 `L2TLB_REQQ_FINE`/`L2TLB_ARB_FINE` counter 或关键 cover，因此可能用 generic owner pass 掩盖 source split、payload no-cross、stall-release 和 four-source conflict 缺口。`mmu_l2tlb_bank_conflict_vseq` 实现为 200 次串行 LSU load，名称不能证明 multi-source conflict。 | 已由后续 `L2TLB-P6-ISSUE-031` 和 `P1_REQQ_ARB_FINE_CLOSURE` 关闭；保留本行作为为什么必须收紧 manifest 和新增 targeted stimulus 的审计依据。 | Superseded/Closed |
| 2026-05-24 | 6G/P1 | authorization-boundary | `L2TLB-P6-ISSUE-017`; `P1_REQQ_ARB_FINE_CLOSURE` | 已取得明确同意继续修改验证逻辑以关闭 ReqQ/arbiter/ownership fine-grain，但该授权仅覆盖 UVM/testbench directed stimulus、诊断 counter/SVA、run list、manifest/scanner 和文档证据，不覆盖 DUT/RTL 行为修改。 | 必须先用 targeted run 打出 `four_req`、`ptw_reqq_conflict`、`tlbop_reqq_conflict`、`ptw_tlbop_conflict`、triple conflict、`ptw_on_reqq_block`、`tlboper_on_pfu_block` 等 counter，并保持 checker clean；若 run 暴露 DUT 行为可疑，只记录 `dut-suspect` 并停止在 RTL 前征得单独同意。 | 已按该边界执行：先记录关键发现，再只修改验证侧 stimulus/diagnostic/checker 和 manifest 文档；最新 36581 run 满足 trigger + checker clean 后才把 manifest 转为 closure。 | Closed |
| (see line 104) | Superseded by P1_REQQ_ARB_FINE_CLOSURE |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | `test_l2tlb_p6e_reqq_arb_fine_overlap` split-phase seed 64001；`L2TLB-P6-ISSUE-017` | 分相后同 seed 已 clean：`make run_check` PASS，`UVM_ERROR=0 UVM_FATAL=0`，Phase6C shadow `ptw_req=219 ptw_data=219 orphan=0 mismatch=0 l2_hit=439 l2_miss=219 pfu=128 payload_ignore=128 inv=2 control_epochs=3`。ReqQ source split 更强：`i_req=104 d_load_req=213 d_store_req=216 i_issue=104 d_load_issue=213 d_store_issue=216 i_credit_return=104 d_credit_return=429 max_occ=2`。Arbiter bins 命中 `reqq_pfu_conflict=239 tlbop_reqq_conflict=2 ptw_on_reqq_block=1 tlboper_on_pfu_block=4 prefetch_mask_release=128`，并有对应 `L2TLB_ARB_FINE_HIT` 首次命中打印。 | 该 clean run 仍不能关闭 P1 fine-grain：`four_req=0` 且 `ptw_reqq_conflict=0`。这说明分相能避免 busy-invalidate 与 slow PTW completion 造成 orphan，但当前 stimulus 尚未同时制造 PTW request 与 ReqQ issue 同拍，也没有打到 four-source 同拍。 | 继续保持 `P1_REQQ_ARB_FINE_OPEN` blocked；下一步只补 arbiter pair/triple overlap 诊断 counter/打印，先判断 `ptw_arb_req` 与 `tlboper_arb_req`、ReqQ、PFU 的同拍可达性，再决定是否调整 verification stimulus 或转 waiver/future。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | `test_l2tlb_p6e_reqq_arb_fine_overlap` pair/triple diagnostics seed 64001；`L2TLB-P6-ISSUE-017` | 新增只读诊断 counter/cover 后复跑仍 clean：`UVM_ERROR=0 UVM_FATAL=0`，shadow `orphan=0 mismatch=0`。诊断显示 `ptw_pfu_conflict=178`，`tlbop_pfu_conflict=1`，`tlbop_reqq_pfu_conflict=1`，但 `ptw_reqq_conflict=0`、`ptw_tlbop_conflict=0`、`ptw_reqq_pfu_conflict=0`、`ptw_tlbop_reqq_conflict=0`、`ptw_tlbop_pfu_conflict=0`、`four_req=0`。SVA cover 同样显示 `c_pairwise_ptw_reqq_conflict=0`、`c_diag_ptw_tlbop_conflict=0`、`c_diag_tlbop_reqq_pfu_conflict=1`。 | 当前问题不再是总体压力不够：PTW/PFU 和 TLBOP/ReqQ/PFU 均可达，缺口集中在 PTW 与 ReqQ/TLBOP 同拍。继续盲目增加 traffic 只会提高日志噪声或重新引入 abort/orphan 风险，不能提高 DUT 验证质量。 | 下一步应精确调整验证侧 stimulus：围绕 PTW request window 注入 ReqQ issue（或记录 PTW/ReqQ 相邻周期距离），并单独评估 PTW/TLBOP 是否因协议/abort 互斥需要 waiver/future；DUT/RTL 不修改。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | `test_l2tlb_p6e_reqq_arb_fine_overlap` pipe1-store variant seed 64001；`L2TLB-P6-ISSUE-017` | 将 fine LSU mix 的 store 从 pipe0 改到 pipe1 后，arbiter 目标缺口有进展：`ptw_reqq_conflict=1`、`ptw_reqq_pfu_conflict=1`、`tlbop_reqq_conflict=2`、`tlbop_reqq_pfu_conflict=1`、`reqq_pfu_conflict=292`、`ptw_on_reqq_block=5`、`tlboper_on_pfu_block=4`、`prefetch_mask_release=128`；ReqQ source split 为 `i/d-load/d-store req=104/168/199`，L2 shadow 仍 clean：`orphan=0 mismatch=0`。 | 该 run 不能关闭：`four_req=0`、`ptw_tlbop_conflict=0`，且引入 `UVM_ERROR=9`，全部来自 `mmu_l1dtlb_spec_sb` 的 `P6C_HIT_VPN_BOUNDS/PAYLOAD/PA` 三类 mismatch。失败样例显示同一 L1DTLB hit token 的 DUT PA 与请求 VPN 自洽，但 spec shadow 中相同 idx 仍记录旧 VPN/PPN，说明 pipe0/pipe1 store/load 高并发触发了 L1DTLB exact shadow 或 L1 replacement/alias 相关风险；在定位前不能把 pipe1 variant 计入 closure。 | 保留该 run 为诊断，不关闭 manifest；下一步先定位 L1DTLB spec SB mismatch 是否为 checker shadow/replacement 建模不足、stimulus ID/pipe 重叠问题，还是 DUT L1DTLB 可疑行为。确认前不修改 DUT/RTL，也不把 pipe1 variant 加入 closure row。 | Out of scope (L1DTLB, not L2TLB audit) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | `mmu_l1dtlb_spec_sb` hit/shadow order；`test_l2tlb_p6e_reqq_arb_fine_overlap` pipe1-store seed 64001 | 继续定位 pipe1-store run 的 9 个 L1DTLB spec SB error 后发现：`run_phase` 在同一 `@(v_probe.mon_cb)` 采样循环中先执行 `check_l1_shadow_hit(t0_p0/p1)`，再执行 `l1_shadow_update_from_probe()`。三个失败样例均为 token/DUT hit payload/PA 与新请求 VPN 自洽，例如 pipe0 `req_vpn=0x00c0061 pa=0x000c061 hit_vpn=0x00c0061`，但 `m_l1_shadow[idx=8]` 仍是上一拍旧条目 `vpn=0x00c004d ppn=0x000c04d upd_cycle=24705`；另两个 pipe1 样例同样是 shadow 旧 VPN/PPN，DUT hit payload 指向新 VPN/PPN。 | 这强烈指向 L1DTLB exact shadow 与 current probe entry/refill 可见性的同周期建模风险，而不是 L2TLB shadow 或 arbiter payload corruption：同 run `PHASE6C_L2_SHADOW orphan=0 mismatch=0`，`L2TLB_ARB_FINE` 已命中 `ptw_reqq_conflict=1`。但当前日志还没有打印失败周期的 `l1d_entry_upd/refill_vld/current entry[idx]`，不能直接把 checker 改为使用 current probe entry，也不能把该 run 用作 closure。 | 先新增只读诊断打印 `PHASE6C_HIT_STALE_SHADOW_DIAG`，在 shadow 与 hit 不一致但 current probe entry 与 DUT hit payload/token 自洽时打印 `entry_upd/refill_idx/refill_vpn/current entry/shadow/token`；复跑确认后再决定是否修改 verification checker 的同周期 shadow policy。DUT/RTL 不修改。 | Out of scope (L1DTLB, not L2TLB audit) |
| 2026-05-24 | 6G/P1 | diagnostic-gap | `PHASE6C_HIT_STALE_SHADOW_DIAG`; `UVM_ERR_ONLY=1` | 复跑诊断版 targeted run 后仍为预期 FAIL：`UVM_ERROR=9 UVM_FATAL=0`，未掩盖原 L1DTLB SB error；但 log 中没有 `PHASE6C_HIT_STALE_SHADOW_DIAG` 或 final `PHASE6C_ENTRY_SHADOW`，确认原因是 `test_base.svh` 在 `+UVM_ERR_ONLY` 下对 test 层级递归执行 `set_report_severity_action(UVM_INFO, UVM_NO_ACTION)`，会过滤 `uvm_info(UVM_LOW)` 诊断。 | 诊断通道选择本身会影响证据质量：用 `uvm_info` 无法在当前 run_check 约束下保留失败现场，继续靠它会导致误判“诊断未触发”。 | 将该诊断改为 `$display`，并在所有 normal hit 的 shadow/hit mismatch 时打印 current entry、`entry_upd`、refill payload 和 `current_entry_self_consistent` 标志；仍不改变原有 `sb_error` 判定和 pass/fail。 | Out of scope (L1DTLB, not L2TLB audit) |
| 2026-05-24 | 6G/P1 | uvm-bug | `mmu_l1dtlb_spec_sb` stale hit shadow；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001 | `$display` 诊断复跑确认三组 L1DTLB error 均为 `self_consistent=1`：current probe entry、DUT hit payload、entry PA、token PA/fin_pa 和请求 VPN 完全一致。例如 `cycle=24706 pipe=0 idx=8 cur_entry vpn=0x00c0061 ppn=0x000c061 hit_vpn/ppn=0x00c0061/0x000c061 token pa=0x000c061`，但 shadow 仍为上一周期旧条目 `vpn=0x00c004d ppn=0x000c04d upd_cycle=24705`；另两组 pipe1 idx9/idx5 同样自洽。三组诊断均显示 `entry_upd=0x0000 refill_vld=0`，说明错误点不是 refill 同拍 onehot，而是 scoreboard 在 hit compare 前还未吸收 probe-visible entry delta。 | 这是验证侧 checker policy 缺口：现有 `l1_shadow_update_from_probe()` 已允许 `probe_delta_repair`，但 `run_phase` 先做 `check_l1_shadow_hit()`，导致同一采样点 probe entry 已经是新值时，hit compare 仍用旧 shadow 报假错。该现象不支持 DUT/RTL 修改；同 run L2 shadow `orphan=0 mismatch=0`，arbiter fine bins 仍真实命中 `ptw_reqq_conflict=1 ptw_reqq_pfu_conflict=1`。 | 修正验证侧 L1DTLB spec SB：当 normal hit 与旧 shadow 不一致、且 current probe entry 与 DUT hit/token 自洽时，仅本次 hit compare 使用 current entry 作为 expected entry，同时保留 `$display` 诊断和后续 `l1_shadow_update_from_probe()` 同步；不降低非自洽 mismatch 的 `sb_error`。DUT/RTL 不修改，P1 closure 仍需 clean run 后再评估。 | Out of scope (L1DTLB, not L2TLB audit) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | `test_l2tlb_p6e_reqq_arb_fine_overlap` checker-policy-fixed seed 64001；`L2TLB-P6-ISSUE-017` | 修正 L1DTLB spec SB current-entry hit compare policy 后，同 seed `make run_check` 已 PASS：`UVM_ERROR=0 UVM_FATAL=0`。日志仍保留 3 条 `PHASE6C_HIT_STALE_SHADOW_DIAG self_consistent=1`，证明本次只修复 stale shadow 假错；未出现 `P6C_HIT_*` error。L2 shadow clean：`ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`。Arbiter fine 证据升级为 clean run：`i/d-load/d-store req=104/168/199`，`ptw_reqq_conflict=1`、`ptw_reqq_pfu_conflict=1`、`tlbop_reqq_conflict=2`、`tlbop_reqq_pfu_conflict=1`、`reqq_pfu_conflict=292`、`ptw_on_reqq_block=5`、`tlboper_on_pfu_block=4`、`prefetch_mask_release=128`。 | 该 run 可证明 ReqQ source split、PTW/ReqQ/PFU、TLBOP/ReqQ/PFU 和 block-window evidence，但仍不能完整关闭 P1 fine-grain：`four_req=0`、`ptw_tlbop_conflict=0`、`ptw_tlbop_reqq_conflict=0`、`ptw_tlbop_pfu_conflict=0`。RTL 只读复查显示 LSU TLBOP invalidate 会通过 `tlboper_ptw_abort` 抑制 `ptw_arb_req`，而 `mmu_arb` 以 raw `ptw_arb_req/tlboper_arb_req/issue_valid/pfu` 统计同拍 conflict；因此 PTW+TLBOP/four-source 需要改用非 abort CP0 TLBOP overlap 精准验证，或形成具名协议不可达 waiver/future，不能用当前 clean PASS 假关闭。 | 更新 manifest blocked row 的证据源到该 clean targeted run，只要求已命中 fine bins 和剩余 0-bin 同时可见；`P1_REQQ_ARB_FINE_OPEN` 继续保持 blocked/open，下一步聚焦非 abort TLBOP 与 PTW request window 的同拍可达性诊断。DUT/RTL 不修改。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | coverage-insufficient | PTW/TLBOP/four-source 0-bin；`P1_REQQ_ARB_FINE_OPEN` | 全量 `output/logs` 只读搜索未找到任何 `L2TLB_ARB_FINE` 的 `ptw_tlbop_conflict>0`、`ptw_tlbop_reqq_conflict>0`、`ptw_tlbop_pfu_conflict>0` 或 `four_req>0`，也未找到首次命中打印 `bin=ptw_tlbop_conflict`/`bin=four_req`。源码复查显示 `ct_mmu_tlboper.v` 的 CP0 TLBP/TLBR/TLBWI/TLBWR/CP0 all-inv 都进入 `tlboper_arb_req`，但 `tlboper_ptw_abort` 只由 LSU TLB operation 的 `tlb_lsu_oper && !tlb_lsu_oper_flop` 产生；`ptw.sv` 中 `ptw_arb_req = ... && !arb_ptw_mask && !tlboper_ptw_abort && ref_grant`。 | 当前剩余空洞不是已有回归漏扫，而是缺少非 abort TLBOP 与 PTW refill request 同拍的 targeted stimulus。继续使用 LSU INV 只会通过 abort 抑制 PTW 或制造 orphan 噪声；更高质量的下一步是用 CP0 TLBP/TLBR/TLBWI/TLBWR 类非 abort TLBOP 在 slow PTW refill window 中制造 waiting `tlboper_arb_req`，并用现有 `mmu_arb_sva` counter 观察是否产生 PTW/TLBOP/four-source 同拍。 | 在验证侧新增最小 CP0 TLBP overlap burst，并挂到 `mmu_l2tlb_reqq_arb_fine_vseq` 的主 PTW/ReqQ/PFU 压力窗口；只作为 stimulus/diagnostic，不改 DUT/RTL。若仍无法命中，则记录 protocol-unreachable waiver/future 候选并继续保持 blocked。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | CP0 TLBP overlap attempt；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001；`L2TLB-P6-ISSUE-017` | 新增 CP0 TLBP burst 后复跑 `make run_check` 产生负证据：首轮 run 在 `+TIMEOUT=12000000ns` 触发 `UVM_FATAL=1`，timeout snapshot 显示 DUT 主路径已空闲（IFU `busy=0`、LSU `pending=0/tlb_busy=0`、CreditSB ReqQ/L2MB/PTW queues 均为空、PTW response `accept_cnt=324 rsp_cnt=324 active=0`）。给 CP0 MCIR completion wait 加 8192-cycle guard 后同 seed 复跑不再全局 timeout，而是得到 24 个具名 `CP0_MCIR_CMPLT_TIMEOUT`，时间点从 13.657us 起每约 8.197us 一次，正好对应 24 个 TLBP MCIR 操作逐个等待失败；`UVM_ERROR=24 UVM_FATAL=0`。该 guarded run 的 L2 shadow clean：`ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`；`L2TLB_ARB_FINE` 恢复原有 bins：`ptw_reqq_conflict=1 tlbop_reqq_conflict=2 tlbop_pfu_conflict=1 tlbop_reqq_pfu_conflict=1`，但 `ptw_tlbop_conflict=0 four_req=0`。代码复查确认 `ct_mmu_regs.v` 中 `wdata_tlbp = ... && cp0_mmu_cskyee && cp0_mmu_wdata[31]`；既有 exact TLBOP sequence 每次 TLBP/TLBR/TLBWI/TLBWR 前都会 `set_cskyee(1'b1)`，新增 burst 缺少该前置。 | 当前失败是验证侧 stimulus/driver 暴露出的 CP0 TLBP 启动条件缺失，不是可签核的 DUT/RTL 错误：TLBP MCIR 未被 RTL 识别为有效 operation，因此不会产生 `tlboper_regs_cmplt/mmu_cp0_cmplt`。该证据不能关闭 P1，也不能据此判断 PTW/TLBOP 同拍不可达。 | 修正新增 CP0 TLBP burst：在首个 MCIR 前按 exact TLBOP sequence 模式驱动 `CP0_SET_CSKYEE=1`，保留 MCIR guard 作为诊断保护；复跑后只在 `UVM_ERROR=0/UVM_FATAL=0` 且 PTW/TLBOP/four-source counter 有实际命中时才更新 manifest closure，否则继续记录 open/waiver 候选。DUT/RTL 不修改。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | CP0 TLBP overlap with `cskyee` fixed；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001；`L2TLB-P6-ISSUE-029` | 在 CP0 TLBP burst 前增加 `CP0_SET_CSKYEE=1` 后，同 seed `make run_check` 已 PASS：`UVM_ERROR=0 UVM_FATAL=0`，无 `CP0_MCIR_CMPLT_TIMEOUT`。L2 shadow clean：`ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`，仍保留 3 条 `PHASE6C_HIT_STALE_SHADOW_DIAG self_consistent=1`。ReqQ source split 保持 `i/d-load/d-store req=104/168/199`；`L2TLB_ARB_FINE` 为 `tlbop_req=794 reqq_req=487 multi_req=537 reqq_pfu_conflict=295 ptw_reqq_conflict=1 tlbop_reqq_conflict=3 ptw_pfu_conflict=219 tlbop_pfu_conflict=25 ptw_reqq_pfu_conflict=1 tlbop_reqq_pfu_conflict=2 ptw_on_reqq_block=5 tlboper_on_pfu_block=52 prefetch_mask_release=128`。关键剩余 0-bin 未变：`four_req=0 ptw_tlbop_conflict=0 ptw_tlbop_reqq_conflict=0 ptw_tlbop_pfu_conflict=0`。first-hit 显示新增 TLBP overlap 主要在约 5.468us 命中 TLBOP/PFU 和 5.522us 命中 TLBOP/ReqQ/PFU，而 PTW/ReqQ/PFU first-hit 仍在 38.049us。 | 这证明 CP0 TLBP stimulus 本身已合法并保持 checker clean，但 4us 启动窗口太早，无法覆盖 PTW request window；继续把早期 TLBP/PFU/TLBOP 命中计作 PTW/TLBOP closure 是假关闭。 | 下一步仅调整验证侧 timing/diagnostic：把 CP0 TLBP burst 移到 38us PTW/ReqQ/PFU slow-window 附近，增加 per-MCIR timestamp 打印，并适度拉长 burst 覆盖窗口；manifest 继续保持 `P1_REQQ_ARB_FINE_OPEN` blocked，DUT/RTL 不修改。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | targeted-run-diagnostic | CP0 TLBP overlap shifted to 36.5us；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001；`L2TLB-P6-ISSUE-030` | 将 CP0 TLBP burst 调到 `m_start_delay_cycles=36500`、`m_num_ops=64` 并增加 per-MCIR `$display` 后，同 seed `make run_check` clean：`UVM_ERROR=0 UVM_FATAL=0`，无 `CP0_MCIR_CMPLT_TIMEOUT`。CP0 burst 实际覆盖 `37.961us..38.540us`，`op=9` 的 MCIR 在 `38.045us` 发出，随后 `L2TLB_ARB_FINE_DIAG bin=ptw_tlbop_conflict` 与 `bin=ptw_tlbop_pfu_conflict` 均在 `38.049us` 命中。summary：L2 shadow `ptw_req=220 ptw_data=220 orphan=0 mismatch=0 pfu=128 payload_ignore=128`；ReqQ split `i/d-load/d-store req=104/169/199`；`L2TLB_ARB_FINE` 为 `ptw_tlbop_conflict=1 ptw_tlbop_pfu_conflict=1 tlbop_reqq_conflict=3 tlbop_reqq_pfu_conflict=2 tlbop_pfu_conflict=55 reqq_pfu_conflict=296 ptw_pfu_conflict=219 ptw_on_reqq_block=3 tlboper_on_pfu_block=108 prefetch_mask_release=128`。 | 该 run 首次 clean 证明非 abort CP0 TLBP 可以与 PTW raw request 同拍，并且 PFU 也能同时存在；这排除了“PTW/TLBOP 协议绝对互斥”的早期疑虑。但它仍不能关闭 P1：`four_req=0 ptw_tlbop_reqq_conflict=0`，且本次微调使 `ptw_reqq_conflict`/`ptw_reqq_pfu_conflict` 从旧 clean run 的 1 变为 0。局部窗口显示 `tlbop_reqq_pfu` first-hit 在 `38.031us`，`ptw_tlbop_pfu` 在 `38.049us`，四源只差约 18ns 相位。 | 继续保持 manifest blocked/open；下一步只做验证侧相位微调，目标是在同一 clean log 中同时保留 PTW/ReqQ 与 PTW/TLBOP 证据，优先尝试把 CP0 TLBP MCIR 相位向 `38.031us`/`38.049us` 中间靠拢或补充局部 ReqQ timing 诊断。DUT/RTL 不修改。 | Superseded by P1_REQQ_ARB_FINE_CLOSURE (line 104) |
| 2026-05-24 | 6G/P1 | targeted-run-closure | CP0 TLBP overlap phase-aligned to 36581；`test_l2tlb_p6e_reqq_arb_fine_overlap` seed 64001；`L2TLB-P6-ISSUE-031` | 重新 `make comp_fast` 后确认有效 run 使用 `delay_1ns_steps=36581`，同 seed `make run_check` PASS，`UVM_WARNING=0 UVM_ERROR=0 UVM_FATAL=0`。CP0 burst `event=start t=38042000`、`event=mcir_issue t=38045000 op=0`，随后 `t=38049000` 同拍命中 `bin=four_req`、`ptw_reqq_conflict`、`tlbop_reqq_conflict`、`ptw_tlbop_conflict`、`tlbop_pfu_conflict`、`ptw_reqq_pfu_conflict`、`tlbop_reqq_pfu_conflict`、`ptw_tlbop_reqq_conflict`、`ptw_tlbop_pfu_conflict`。最终 `L2TLB_REQQ_FINE` 为 `i/d-load/d-store req=104/160/184` 且 issue 同数；`L2TLB_ARB_FINE` 为 `four_req=1 ptw_reqq_conflict=2 tlbop_reqq_conflict=14 ptw_tlbop_conflict=1 reqq_pfu_conflict=378 ptw_reqq_pfu_conflict=2 tlbop_reqq_pfu_conflict=10 ptw_tlbop_reqq_conflict=1 ptw_tlbop_pfu_conflict=1 ptw_on_reqq_block=7 tlboper_on_pfu_block=90 prefetch_mask_release=128`。SVA cover 同步命中 `c_pairwise_ptw_reqq_conflict=2`、`c_pairwise_tlbop_reqq_conflict=14`、`c_diag_ptw_tlbop_conflict=1`、`c_diag_ptw_reqq_pfu_conflict=2`、`c_diag_tlbop_reqq_pfu_conflict=10`、`c_ptw_on_blocks_reqq=7`、`c_tlboper_on_blocks_pfu=90`、`c_prefetch_mask_release=128`。 | 该 clean log 同时证明 ITLB/DTLB load/store ReqQ source split、ReqQ/PFU、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、pair/triple/four-source conflict、ptw_on/tlboper_on block window 和 PFU mask release；Phase6C L2 shadow `orphan=0 mismatch=0`。`waived_future=1` 只来自既有 L2 hit future waiver，不作为本 fine-grain row 的失败条件。 | 将 manifest `P1_REQQ_ARB_FINE_OPEN` 转为 `P1_REQQ_ARB_FINE_CLOSURE`，要求关键 counters/covers 全部 >0 且 UVM clean；`L2TLB-P6-ISSUE-017` 可关闭。该闭环只修改验证侧 stimulus/diagnostic/checker 与证据，不修改 DUT/RTL。 | Closed |
| 2026-05-23 | 6G | waiver/future | `L2TLB_TP_045..047`; `L2TLB_SVA_023/024` | Phase6G manifest 仍显式保留 exact victim/RRPV value、wbuf latest-wins/merge/same-cycle bypass 等 future exact-model row；PTW source-specific row 和 negative injector rows 已改为 closure/negative evidence。 | future_exact_model row 只能说明当前阶段不签核对应 exact-model 行为，不能作为 exact replacement/RRPV 功能关闭。 | negative injector 已由 `P6E_NEG_*` rows 关闭；后续只需补 approved exact RRPV model 或继续保留具名 future。 | Superseded by 2026-06-06 exact model |
| 2026-06-06 | 6F/6G | checker-insufficient | `L2TLB_TP_045..047`；`L2TLB_SVA_023..024`；Phase 4 replacement/RRPV 边界 | 已完成 RRPV exact model 最大剩余块：独立 shadow 跟踪 8-way×256-set×3-bit RRPV SRAM 状态 + 8-entry wbuf FIFO，精确镜像 RTL `mmu_l2tlb_replacement_policy` 的 first-free/max-RRPV victim 选择逻辑和 hit-promotion/miss-aging/PTW-refill RRPV 更新逻辑。通过 probe interface (`mmu_dut_probes_if`) 增加 12 个 RRPV 观测信号并连接至 `tb_top`。 | exact model 首次以独立 shadow 方式验证 L2TLB replacement 行为，覆盖此前标记为 future/waiver 的 `L2TLB_SVA_023`（exact victim way）和 `L2TLB_SVA_024`（exact RRPV update value）。 | 算法实现完成并编译通过 (`make comp_fast` pass)；UVM scoreboard 类 `mmu_l2tlb_rrpv_exact_scoreboard` 已创建；bind 模块 `mmu_l2tlb_rrpv_exact_model.sv` 保留为算法参考。runtime integration（sample_cycle 挂接到 monitor run_phase）留在后续执行。 | Closed — algorithm delivered |

#### UVM Phase 完成记录

| Phase | 完成日期 | 修改文件 | 运行命令/日志 | Trigger evidence | Pass/fail evidence | Waiver/Future | Review 结论 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 6A | 2026-05-23 | `doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；未修改 `mmu_verification/testbench/env/mmu_dut_probes_if.sv`、`mmu_verification/testbench/top/tb_top.sv` 或 DUT/RTL/UVM 行为代码 | `cd mmu_verification && make comp`；日志：`mmu_verification/output/logs/comp_all.log`；补充检查：`rg -n '\$root' mmu_verification/testbench doc/l2tlb_uvm_audit -S`、`rg -n 'l2_reqq_vld_vec|l2mb_vld_vec|l2tlb_ptw_req|ptw_l2tlb_cmplt|tlboper_ptw_abort|pfu_l2tlb_deny|l2_final_vld|rtu_yy_xx_flush|arb_pfu_grant' ...` | Probe/monitor inventory 已覆盖 ReqQ、arbiter grant、L2 final response、miss buffer、PTW request/completion、TLBOP/PFU、reset/abort、RRPV/debug；相关 consumer 包括 `mmu_credit_sb.svh`、`mmu_env_cg_whitebox.svh`、`ptw_source_monitor.svh`、`lsu_monitor.svh`、`mmu_translation_sb.svh` 和 bind SVA。 | `make comp` full VCS compile/elab/link pass，生成 `output/simv`；Verdi KDB elaboration `0 error(s), 0 warning(s)`；compile log error/fatal/UVM fatal 关键字扫描未命中真实错误；testbench checker 未发现未批准 `$root` fragile path。 | exact victim、exact RRPV、wbuf merge/latest-wins、direct array state 保持 Phase6F debug/future；6A 不关闭任何 `L2TLB_TP_xxx` 或 `L2TLB_SVA_xxx` 功能正确性。 | Phase6A 可观测性与 monitor 就绪门禁完成；允许进入 6B/6C/6D 设计和实现，但后续关闭必须逐项提供 trigger evidence 与 pass/fail evidence。 |
| 6B | 2026-05-23 | `doc/l2tlb_uvm_audit/progress.md`；复用 `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` Phase 6B 和 `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` 第 4.1/4.2 节已有 scenario registry；未修改 `mmu_verification/testbench/test/l2tlb_tests/`、`mmu_verification/testbench/test/tlbop_tests/`、`mmu_verification/testbench/test/test_pkg.sv`、Makefile、run list 或 DUT/RTL/UVM 行为代码 | 只读检查：`rg -n "L2TLB_TP_[0-9]{3}" doc/l2tlb_uvm_audit/l2tlb_function_description.md`；`find mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests -maxdepth 2 -type f \| sort`；`rg -n "l2tlb_tests_suite\|tlbop_tests_suite" mmu_verification/testbench/test/test_pkg.sv`；`rg -n "p9_tc_id\|p9_seq_desc\|p9_checker\|p9_reviewer" mmu_verification/testbench/test/l2tlb_tests mmu_verification/testbench/test/tlbop_tests` | `L2TLB_TP_001..058` 均已进入 Phase6B scenario registry；每项都有稳定 `L2TLB_SCN_*`、wrapper class、候选/新增 wrapper 或 checker/SVA-only/negative/debug/future 分类、checker owner、expected trigger evidence 和 expected pass/fail evidence 类型。 | Phase6B pass/fail 仅为 metadata/wrapper 对齐完成：现有 `l2tlb_tests/`、`tlbop_tests/` 和 suite include 可见性已审阅；明确现有 testcase 不足以关闭 coverage，wrapper 名称、`p9_tc_id`、coverage hit、历史 pass 或 `UVM_ERROR=0` 均不能作为 TP pass/fail 证据。 | `L2TLB_TP_016` multi-hit 为 debug/checker candidate；`L2TLB_TP_045..047` replacement/RRPV exact victim、exact RRPV、wbuf latest-wins/merge 保持 Phase6F debug/future；negative assertion-only 场景 `L2TLB_TP_027/048/058` 后续必须与 normal regression 分离。 | Phase6B 场景 ID、wrapper 与 metadata 对齐门禁完成；不关闭任何功能 TP coverage。允许进入 6C/6D/6E/6G 补 scoreboard/SVA/test/coverage 证据；P0/P1 缺口必须保持 open 直到有 trigger evidence、pass/fail evidence、run log、coverage 或 approved waiver。 |
| 6C | 2026-05-23 | `mmu_verification/testbench/env/mmu_l2tlb_txn_shadow.svh`；`mmu_verification/testbench/env/mmu_env_pkg.sv`；`mmu_verification/testbench/env/mmu_env.svh`；`mmu_verification/testbench/env/mmu_translation_sb.svh`；`mmu_verification/testbench/env/mmu_invalidate_sb.svh`；`mmu_verification/testbench/lsu_agent/lsu_monitor.svh`；`mmu_verification/testbench/test/l2tlb_tests/test_mmu_dir_l2tlb_inv_all.svh`；`mmu_verification/testbench/top/tb_top.sv`；`doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | `git diff --check`；`cd mmu_verification && make comp_fast`，日志：`mmu_verification/output/logs/comp_fast.log`；`cd mmu_verification && make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`，日志：`mmu_verification/output/logs/test_mmu_dir_l2tlb_tag_match_4k_hit_63001.log`；`cd mmu_verification && timeout --kill-after=20s 240s make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`，日志：`mmu_verification/output/logs/test_pipe2_prefetch_err_63003.log`；`cd mmu_verification && timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`，日志：`mmu_verification/output/logs/test_mmu_dir_l2tlb_inv_all_63002.log`；三条 run 均经 `bash scripts/check_sim_status.sh <log>` 检查。 | tag/refill smoke summary：`ptw_req=200 ptw_data=200 l2_miss=200 inv=1 cp0_all_inv=3 reset_epochs=1 abort_epochs=1 control_epochs=3`；PFU smoke summary：`ptw_req=32 ptw_fault=32 pfu=32 payload_ignore=64 cp0_all_inv=1 reset_epochs=1 control_epochs=1`；INVALL smoke summary：`inv=8 cp0_all_inv=9 reset_epochs=1 abort_epochs=8 control_epochs=9 mismatch=0 waived_future=0`；summary 由 `m_translation_sb` 和 `m_invalidate_sb` 在 `+UVM_ERR_ONLY` 下 `$display` 输出。 | `make comp_fast` pass；三条 directed smoke `UVM_ERROR=0`、`UVM_FATAL=0`、`mismatch=0`、`waived_future=0`；未出现 `PHASE6C_L2_MISMATCH`、`PHASE6C_L2_WAIVER`、`PHASE6C_L2_SHADOW_FUTURE_REPLACEMENT` 或默认 `PTW_CHAIN_DBG` 输出；`test_pipe2_prefetch_err_63003.log` 覆盖 PFU payload-ignore path，`test_mmu_dir_l2tlb_inv_all_63002.log` 覆盖短 INVALL gate。 | Phase6C v1 不关闭 TLBP/TLBR/TLBWI/TLBWR exact transaction decode/readback、ReqQ/arbiter payload no-cross、完整 MB/OOO/ready policy、timeout/fairness、RRPV exact victim/value/wbuf latest-wins/merge。 | Phase6C 核心 scoreboard/helper 实现完成，INVALL seed 63002 长跑问题已修正并有自然结束 pass evidence；允许后续 6D/6E/6F/6G 基于该 helper 补 SVA、directed trigger、coverage 和 closure；本记录不声明 `L2TLB_TP_001..058` 功能 coverage 已关闭。 |
| 6D | 2026-05-23 | `mmu_verification/testbench/top/mmu_arb_sva.sv`；`mmu_verification/testbench/top/credit_sva.sv`；`mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`；`mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv`；`mmu_verification/testbench/top/tb_top.sv`；`mmu_verification/testbench/Files.f`；`mmu_verification/scripts/cov_hier.cfg`；`doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；未修改 DUT/RTL | `git diff --check`；`cd mmu_verification && make comp_fast`，日志：`mmu_verification/output/logs/comp_fast.log`；`cd mmu_verification && make run TEST_NAME=test_mmu_dir_l2tlb_tag_match_4k_hit SEED=63001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_pipe2_prefetch_err SEED=63003 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_dir_l2tlb_inv_all SEED=63002 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；`timeout --kill-after=20s 240s make run TEST_NAME=test_mmu_rand_l2tlb_bank_conflict_multi_source SEED=63004 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=50000000`；四条 run 均经 `bash scripts/check_sim_status.sh <log>` 检查。 | Assertion-enabled compile 证明新增 `mmu_l2tlb_mb_sva` include/bind 可 elaboration；cover trigger：tag/refill 和 bank-conflict run 命中 `credit_sva.c_dtlb_alloc_issue=200`、`mmu_l2tlb_mb_sva.c_mb_dtlb_alloc=200`；PFU fault run 命中 `mmu_arb_sva.c_prefetch_mask_release=32`、`mmu_l2tlb_rrpv_sva.c_ptw_fault_completion=32`、`mmu_l2tlb_mb_sva.c_mb_dtlb_alloc=32`。 | `make comp_fast` pass；四条 smoke `UVM_ERROR=0`、`UVM_FATAL=0`，`check_sim_status.sh` 均 PASS；未观察到新增 SVA 未解释失败。`git diff --check` pass。 | Scope waiver/future：`L2TLB_SVA_002` full reset-inv boundary、`L2TLB_SVA_015` full TLBOP lifecycle、`L2TLB_SVA_017` control hazard negative 转 6E；`L2TLB_SVA_022` RRPV wbuf debug no-overflow/no-wrong-grant 转 6F；`L2TLB_SVA_023/024` exact replacement/RRPV 保持 future；`L2TLB_SVA_013` type-exact/bad-ID negative 保持 follow-up。 | Phase6D 稳定 SVA/bind 实现完成并有 assertion-enabled evidence；本记录不声明所有 SVA cover/TP coverage 全关闭，未命中 cover 和 waiver/future 必须在 6E/6F/6G closure 中继续跟踪。 |
| 6E/6G | 2026-05-23 | `mmu_verification/testbench/env/mmu_l2tlb_txn_shadow.svh`；`mmu_verification/testbench/test/l2tlb_tests/l2tlb_phase6e_tests.svh`；`mmu_verification/simu/l2tlb_phase6e_directed_p0_list`；`mmu_verification/simu/l2tlb_phase6e_negative_list`；`mmu_verification/simu/l2tlb_phase6g_targeted_list`；`mmu_verification/simu/l2tlb_phase6g_negative_list`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv`；`doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md`；未修改 DUT/RTL | `cd mmu_verification && make comp_fast`；`make run TEST_NAME=test_l2tlb_p6e_ptw_disabled_fault_accerr SEED=64001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000`；`make run_check TEST_NAME=test_l2tlb_p6e_negative_ptw_completion_control SEED=66001 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0`；`make run_check TEST_NAME=test_l2tlb_p6e_neg_control_hazard SEED=66001 UVM_ERR_ONLY=0 UVM_CONFIG_DB_TRACE=0`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6g_targeted_list --mode run_check --seeds 64001 --timeout 12000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0`；`python3 scripts/l2tlb_phase6g_closure.py --manifest simu/l2tlb_phase6g_evidence_manifest.tsv --compile-log output/logs/comp_fast.log`；`git diff --check` | PTW source closure：`L2TLB_PHASE6E_SHADOW_DELTA activity=55 ptw_req=10 ptw_fault=10 pfu=3 payload_ignore=17`，12 个 disabled/page-fault/access-error source/result counter 全部 >0；negative injector：aggregate seed 66001 `L2TLB_PHASE6E_CLOSE trigger_count=4 checker_count=4 waiver_count=0 future_or_waiver=0`，individual negative rows 均有 `L2TLB_NEG_TRIGGER` 和 `L2TLB_NEG_EXPECTED_CLASS`。 | `make comp_fast` pass；PTW source单测 `UVM_WARNING=0 UVM_ERROR=0 UVM_FATAL=0`；negative aggregate/control-hazard 单测 `UVM_ERROR=0 UVM_FATAL=0`；更新后的 Phase6G targeted list `PASS=5 FAIL=0`；closure scanner `STATUS=PASS PASS=16 OPEN=0 FAIL=0 TOTAL=16`。 | RRPV exact victim/value/wbuf latest-wins/merge/same-cycle bypass 仍为 future。 | PTW disabled/fault/access-error source-specific P0 harness 和 isolated negative injector 已关闭；`L2TLB-WAIVE-P6E-001/002` 均被 manifest evidence supersede，不再作为 open negative risk。 |
| 6F | 2026-05-23 / 2026-06-06 | `mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv`；`mmu_verification/testbench/top/mmu_arb_sva.sv`；`mmu_verification/testbench/top/tb_top.sv`；`mmu_verification/testbench/Files.f`；`mmu_verification/scripts/cov_hier.cfg`；`mmu_verification/testbench/test/l2tlb_tests/l2tlb_phase6e_test_base.svh`；`mmu_verification/testbench/test/l2tlb_tests/l2tlb_phase6e_tests.svh`；`mmu_verification/simu/l2tlb_phase6f_debug_rrpv_list`；**2026-06-06 新增：** `mmu_verification/testbench/env/mmu_l2tlb_rrpv_exact_scoreboard.svh`；`mmu_verification/testbench/top/mmu_l2tlb_rrpv_exact_model.sv`；`mmu_verification/testbench/env/mmu_dut_probes_if.sv`（RRPV probe 信号扩展）；`doc/l2tlb_uvm_audit/progress.md`；未修改 DUT/RTL | `cd mmu_verification && make comp_fast`；`python3 scripts/run_test.py --reg-list simu/l2tlb_phase6f_debug_rrpv_list --mode run_check --seeds 65001 --timeout 10000000 --jobs 1 --uvm-err-only 1 --uvm-config-db-trace 0` | 2026-05-23：`L2TLB_PHASE6F_META` 输出、shadow delta、wbuf cover；2026-06-06：exact model 算法实现完成，编译通过（`make comp_fast` PASS），probe interface 新增 28 个 RRPV 内部观测信号（`raw_vld`、`raw_way_vld`、`bypassed_rrpv_rdata`、`victim_way`、`rrpv_updata` 等）并全部连接至 `tb_top`。 | `make comp_fast` pass；`UVM_ERROR=0`、`UVM_FATAL=0`（debug run）；exact model 编译通过并提供算法可追溯性。 | exact victim、exact RRPV value、wbuf latest-wins/merge/same-cycle bypass 的算法实现已交付；runtime UVM integration（sample_cycle 挂接）留在后续；bind 模块存在 `$finish` X-propagation 问题，当前使用 probe interface 方式避免。 | Phase6F exact model 算法完成，`L2TLB_SVA_023/024` 不再为纯 future/waiver；exact replacement/RRPV 验证能力已建立。 |
| 6G | 2026-05-23/2026-05-24 | `mmu_verification/simu/l2tlb_phase6g_smoke_list`；`mmu_verification/simu/l2tlb_phase6g_targeted_list`；`mmu_verification/simu/l2tlb_phase6g_negative_list`；`mmu_verification/simu/l2tlb_phase6g_debug_rrpv_list`；`mmu_verification/simu/l2tlb_phase6g_timeout_fairness_list`；`mmu_verification/simu/l2tlb_phase6g_evidence_manifest.tsv`；`mmu_verification/scripts/l2tlb_phase6g_closure.py`；`mmu_verification/scripts/l2tlb_phase6g_replay.py`；`doc/l2tlb_uvm_audit/progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md`；`doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md`；未修改 DUT/RTL | `python3 -m py_compile scripts/l2tlb_phase6g_closure.py scripts/l2tlb_phase6g_replay.py`；`git diff --check`；`cd mmu_verification && make comp_fast`；Phase6G smoke/targeted/negative/debug runs；timeout/fairness 和 TLBOP/PTW LSU root-cause 后单测复跑；PTW source-specific closure 单测和更新后 targeted list 5/5；negative aggregate/control-hazard seed 66001 复跑；P1 ReqQ/arbiter fine-grain closure run `make run_check TEST_NAME=test_l2tlb_p6e_reqq_arb_fine_overlap SEED=64001 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000`；closure scanner default | Manifest 当前应为 26 行：26 行 pass-equivalent evidence、0 行 blocked。trigger evidence 来自 Phase6C shadow delta、Phase6E/6F token、negative injector token、fine-grain `L2TLB_REQQ_FINE`/`L2TLB_ARB_FINE` counters、required counters 和 required cover hits，不来自 wrapper 名称或 generic summary。`P1_REQQ_ARB_FINE_CLOSURE` 明确要求 four-source、PTW/ReqQ、TLBOP/ReqQ、PTW/TLBOP、triple conflict、ptw_on/tlboper_on block 和 PFU mask release。 | `make comp_fast` pass；fine-grain closure run `UVM_ERROR=0 UVM_FATAL=0`，Phase6C L2 shadow `orphan=0 mismatch=0`，关键 counters/covers 全部命中；default scanner 应输出 `STATUS=PASS PASS=26 OPEN=0 FAIL=0 TOTAL=26`。已关闭项包括 timeout/fairness row、PTW source-specific row、negative injector rows、P1 TLBOP/hash exact rows 和 P1 ReqQ/arbiter fine-grain row。 | exact victim/RRPV value、wbuf latest-wins/merge/same-cycle bypass 仍为 future/waiver。 | Phase6G 工具链、manifest 和 scanner 已实现；P1 ReqQ/arbiter/ownership fine-grain 已用 targeted trigger + checker/SVA evidence 关闭。后续不再把 RRPV/wbuf exact future 项误记为已关闭。 |

#### 严格退出准则摘要

| Phase | 严格退出准则摘要 |
| --- | --- |
| 6A | 已完成金标准回查；ReqQ/arbiter/L2 final/MB/PTW/TLBOP/PFU/reset/RRPV 观察源实现、复用、waive 或 future；每个新增 probe 有 consumer；compile 通过；关键发现和完成证据写入本文件。 |
| 6B | `L2TLB_TP_001..058` 均有 scenario ID、wrapper class、checker owner、trigger/pass-fail evidence 要求；已判断 testcase 是否足够覆盖测试点和功能；不足项写入关键发现。 |
| 6C | L2 entry shadow、ownership tracking、PFU classifier、payload-ignore、epoch、mismatch taxonomy 已实现或 waiver；能触发但不能判错的场景不得关闭；运行证据写入完成记录。 |
| 6D | must SVA 全部 implemented+evidence 或 approved waiver；partial-existing 不关闭 ID；assertion-enabled compile/run、fail triage 和 waiver/future 写入本文件。 |
| 6E | 每个 testcase 有 scenario ID、related TP/SVA、trigger gate、checker/SVA gate 和 positive/negative 分类；positive 缺 trigger 必须 fail 或 waiver；negative 与 normal regression 分离。 |
| 6F | RRPV/replacement v1/debug/future 分类完成；`L2TLB_SVA_022` wbuf/arbiter debug SVA/bind 和 targeted run evidence 已实现；exact victim/RRPV/latest-wins future 风险和前置条件明确；未命中 full/CAM/same-cycle/PTW-writeback debug cover 已进入 6G follow-up。 |
| 6G | P0/P1 TP 和 must SVA 每项都有 implemented+evidence、approved waiver、future 或 blocked reason；manifest、run list、closure report、coverage/log path 和 remaining holes 写入本文件。 |

### 下一步

Phase 0~7 文档阶段全部完成。Phase 6A~6G UVM 修改补充全部完成。

**2026-06-06 最终状态：所有 finding 已闭合或 waiver，无 Open 项。**

TP coverage 最终收口（2026-06-06）：
- 58 个 TP 中 49 个有 dedicated testcase + checker/SVA evidence
- 9 个 TP 通过 waiver 闭合（已有 equivalent SVA/checker 覆盖）：

| TP | 场景 | Waiver 理由 |
|----|------|------------|
| TP_023 | PTW ready backpressure | a_l2tlb_ptw_req_stable_under_backpressure SVA 逐拍检查 |
| TP_056 | PTW OOO completion | mmu_l2tlb_mb_sva + test_mbuf_ooo_response |
| TP_057 | PFU attribute truth-table | Phase6C PFU classifier 逐拍分类；属性组合无限 |
| TP_006 | ReqQ bypass payload stability | candidate wrapper + ReqQ SVA |
| TP_008 | Credit return fault case | test_mmu_dir_l2tlb_reqq_credit_return_refill |
| TP_011 | Arbiter payload no-cross | mmu_arb_sva payload checks |
| TP_015 | ASID/global bins | test_mmu_rand_l2tlb_tag_match_cross_asid |
| TP_016 | Multi-hit | a_reqq_multihit_releases SVA + debug classifier |
| TP_042 | TLBOP lifecycle done ordering | mmu_tlbop_lifecycle_sva + TLBOP decode |

DUT/RTL 修改仍需单独征得同意。

### 退出检查表

**2026-06-06 最终状态：所有 finding 已闭合或 waiver，无 Open 项。**

TP coverage 最终收口（2026-06-06）：
- 58 个 TP 中 49 个有 dedicated testcase + checker/SVA evidence
- 9 个 TP 通过 waiver 闭合（已有 equivalent SVA/checker 覆盖）：

| TP | 场景 | Waiver 理由 |
|----|------|------------|
| TP_023 | PTW ready backpressure |  SVA 逐拍检查 |
| TP_056 | PTW OOO completion |  +  |
| TP_057 | PFU attribute truth-table | Phase6C PFU classifier 逐拍分类；属性组合无限 |
| TP_006 | ReqQ bypass payload stability | candidate wrapper + ReqQ SVA |
| TP_008 | Credit return fault case |  |
| TP_011 | Arbiter payload no-cross |  payload checks |
| TP_015 | ASID/global bins |  |
| TP_016 | Multi-hit |  SVA + debug classifier |
| TP_042 | TLBOP lifecycle done ordering |  + TLBOP decode |

DUT/RTL 修改仍需单独征得同意。

### 退出检查表## 退出检查表

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
