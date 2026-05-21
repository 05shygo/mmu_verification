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
| Phase 6 | 规划创建 Phase 6 BuildPlan/Progress 文档 | 已完成 | 已创建 `L2TLB_UVM_Phase6_BuildPlan.md` 和 `L2TLB_UVM_Phase6_Progress.md`；本阶段只做文档规划，不修改 UVM、DUT/RTL、Makefile 或 testbench 行为代码 |
| Phase 7 | 为 BuildPlan 中规划的后续实施阶段设计严格退出准则 | 已完成 | 已为 6A~6G 补充严格退出门禁，并将 Phase 6 BuildPlan/Progress 两份文档中文化；不修改 UVM/RTL/Makefile/testbench 行为代码 |

## 当前交付物状态

| 交付物 | 路径 | 状态 | 说明 |
| --- | --- | --- | --- |
| 黄金输入 | `doc/l2tlb_uvm_audit/l2tlb_function_description.txt` | 已存在 | 本文件作为只读黄金输入；当前进度文档不声明其内容已被审完 |
| 工作规格 | `doc/l2tlb_uvm_audit/l2tlb_function_description.md` | 已补充 Phase 2/3/4 | 已新增 Phase 2 `L2TLB_TP_001..058` 测试点清单、Phase 3 `L2TLB_SVA_001..024` SVA requirement，并补充 Phase 4 scoreboard/reference model 建模要求 |
| Phase 2 Excel 测试点表 | `doc/l2tlb_uvm_audit/L2TLB_TRISTAN_IP_Hardware_tp_V1.xlsx` | 已创建 | 与 `.md` 中 `L2TLB_TP_001..058` 一一对应 |
| 实施计划 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Audit_ImplementationPlan.md` | 已更新到 Phase 7 | 记录 Phase 0~7 文档阶段完成状态；不批准后续代码实现 |
| 进度文档 | `doc/l2tlb_uvm_audit/progress.md` | 已创建 | 本文件 |
| Phase 6 代码搭建规划文档 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_BuildPlan.md` | 已中文化并补充门禁 | 已把后续 L2TLB UVM 实施拆成 6A~6G 子阶段，并为每个子阶段补充严格退出准则；只规划蓝图，不执行代码修改 |
| Phase 6 专用进度文档 | `doc/l2tlb_uvm_audit/L2TLB_UVM_Phase6_Progress.md` | 已中文化并补充门禁跟踪 | 已初始化后续实施进度、证据、issue、waiver 和 Phase 7 门禁签核格式；不记录任何 UVM/DUT 代码已实现 |
| 主验证计划同步 | `doc/MMU_VerificationPlan_final.md` | 已完成 | 已同步 Phase 2~4 已 review 内容，并明确 audit `.md` 对旧 F3/F5/TLBOP 冲突条目的优先级 |
| UVM/Makefile/RTL 修改 | N/A | 未开始 | 本阶段不处理 |

## 下一步

下一次会话可从后续代码实施阶段的单独批准开始。Phase 6/7 已产出并中文化两份规划/进度文档，且补充了 6A~6G 严格退出门禁；这些文档不修改 UVM、DUT/RTL、Makefile 或任何行为代码，后续是否进入代码实现必须由新的阶段或新计划另行批准。

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
| Phase 6 不修改 UVM/DUT/RTL/Makefile 确认 | 已确认 |
| Phase 7 后续实施阶段退出准则细化 | 已完成 |
| Phase 6 BuildPlan/Progress 文档中文化 | 已完成 |
| Phase 7 不修改 UVM/DUT/RTL/Makefile 确认 | 已确认 |
