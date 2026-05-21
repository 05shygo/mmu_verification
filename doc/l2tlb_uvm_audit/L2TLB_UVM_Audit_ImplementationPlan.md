# L2TLB UVM Audit 分阶段实施计划

> 黄金输入：`doc/l2tlb_uvm_audit/l2tlb_function_description.txt`
> 工作规格：`doc/l2tlb_uvm_audit/l2tlb_function_description.md`
> 进度文档：`doc/l2tlb_uvm_audit/progress.md`
> 日期：2026-05-21

## 1. 总结

本计划用于后续分阶段、逐项把 `l2tlb_function_description.txt` 中的 L2TLB 功能描述整理成 UVM 修改的黄金依据。

当前进度以 `progress.md` 为准：Phase 0~7 已完成，其中 Phase 6 只完成 BuildPlan/Progress 文档创建和规划同步，Phase 7 只完成后续实施退出门禁细化和 Phase 6 文档中文化。不能把本文件中的阶段标题视为已经完成的 UVM/RTL 代码实现或后续代码修改批准。

## 2. 阶段计划

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

### Phase 0：基线审计与保护（已完成）

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

### Phase 1：创建 markdown 工作副本（已完成）

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

### Phase 2：总结 L2TLB 所有测试点（未开始）

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

### Phase 3：补充必要 SVA（未开始）

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

### Phase 4：补充 scoreboard/reference model 建模点（未开始）

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

### Phase 5：同步到主验证计划（已完成）

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

### Phase 6：规划创建 Phase 6 BuildPlan/Progress 文档（已完成）

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

### Phase 7：为 BuildPlan 中规划的后续实施阶段建立严格退出准则（已完成）

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

## 3. 后续工作原则

- Phase 2 及之后必须逐阶段单独完成，不能一次性批量标记完成。
- 每个阶段开始前先读取当前 `.md` 和已有 UVM 现状，再决定当阶段的具体补充内容。
- 每个阶段结束时更新 `progress.md`，只记录该阶段真实完成的内容。
- 测试点、SVA、scoreboard/reference model 内容必须经过逐项 review 后才能从“未开始”改为“已完成”。
- Phase 6 本身不进行 UVM、DUT/RTL、Makefile 或仿真入口修改；任何代码实现必须另起后续阶段并有明确批准。

## 4. 当前明确状态

- Phase 0：已完成。
- Phase 1：已完成。
- Phase 2：已完成。
- Phase 3：已完成。
- Phase 4：已完成。
- Phase 5：已完成。
- Phase 6：已完成，仅创建并 review 规划/进度文档，不修改 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口。
- Phase 7：已完成，仅完成退出门禁文档化和 Phase 6 文档中文化；不修改 UVM、DUT/RTL、Makefile、testbench 行为代码或仿真入口，也不批准后续代码实现。
