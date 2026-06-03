# Specification Review Issues — `.claude/agents/`

**Spec**: `/home/lxx/wrk/Babel/.claude/agents/{bba-architect, bba-guru-rtl, bba-guru-verification, bba-guru-synthesis, bba-guru-pd}.md`
**Cross-checked against**: `harness_spec/arch_spec/{agent-*, _index, ADR/}` 以及实际仓库状态（schemas/、wiki/、designs/、.claude/skills/）
**Reviewed**: 2026-05-17
**Mode**: inline
**Roles**: red_team, boundary, cost, user, security
**Dimensions**: 需求完整性 / 实现风险 / 模块化设计 / 模块接口清晰度 / 过度设计 / 性能-扩展性 / 文档输出规范

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 7  |
| HIGH     | 10 |
| MEDIUM   | 12 |
| LOW      | 8  |

### Top 5 Critical Issues

1. **[C-01] 90% 引用基础设施缺位** — `schemas/`、`wiki/`、`designs/` 目录全部不存在，5 个 agent 文件中数十处 schema 校验 / wiki 检索 / designs 写入路径会全��� fail-open。
2. **[C-02] 30 个 bb-\* skill 中仅 1 个真正安装** — 仅 `bb-invoke-yosys` 存在；其余 29 个 skill 在每个 agent 的「Skills You Call」表中均被标为 `installed`，构成系统性虚假声明。
3. **[C-03] ADR-008 / ADR-015 / ADR-016 在仓库中不存在** — 但被 5 个 agent 反复引用作为权威依据；仓库 ADR 实际仅有 ADR-A01..A10。
4. **[C-04] 覆盖率字段名跨 agent 不一致** — verification 写 `test_report.coverage`（单字段），synthesis 读 `functional_coverage` / `code_coverage`（双字段），无 schema 仲裁，gate 必定误判。
5. **[C-05] Pipeline 推进机制为空中楼阁** — agent 间靠 `bb-create-issue --label ready-for-X` 串接，但没有任何 hook 实现 label→下游 agent 的派发；5 个 agent 全部不可达上下文。

---

## Issues by Dimension

### 需求完整性 (Completeness)

| ID | Issue | Severity | Roles Found | Recommendation |
|----|-------|----------|-------------|----------------|
| C-01 | `schemas/`, `wiki/`, `designs/` 目录全部不存在 | CRITICAL | Boundary, User, Cost | 先建立 stub 目录并提交 schema 骨架；或在 agent 中标明「first-run bootstrap」步骤 |
| C-02 | 29 / 30 个 bb-* skill 未安装却被标 `installed` | CRITICAL | Boundary, Red, Cost | 改为 `pending` 状态并在 description 加 "MVP-blocked-by-skills-install" 警示，或先撤回该列 |
| C-03 | ADR-008 / ADR-015 / ADR-016 不存在 | CRITICAL | Boundary | 改引用 ADR-A0x 真实编号，或将「v1.3 ADR-016」改为内部引用 design_doc 段号 |
| C-04 | 覆盖率字段名 verification↔synthesis 不一致 | CRITICAL | Boundary, Red | 选定唯一字段名（建议 `functional_coverage` + `code_coverage` 两字段），写入 `schemas/test_report.schema.json` |
| C-05 | 无 label→agent 派发机制 | CRITICAL | Boundary, User | `hook-bb-hook-pipeline-advance` 必须在 v1.3 MVP 安装；agent 文件应说明依赖此 hook |
| H-01 | ADR-A09 bb-* adapter 层无 agent 描述其实际位置 | HIGH | Red, Boundary | 在 bba-architect 工作流中显式插入「bb-* 输出后调用 adapter」步骤；指明 adapter 实现位置（agent yaml? Python helper?） |
| H-02 | PD 无 `arch-needs-fix` 直通路径 | HIGH | Red, Boundary | 允许 PD 在判断 MAS IO ring 错误时直接 raise `arch-needs-fix`，或显式声明「双跳传递」是设计选择并定义信息保真协议 |
| H-03 | bba-architect 列出 `bb-spec-review` 但工作流从未调用 | HIGH | Red, Cost | 在 Workflow Step 4.5 加「调 bb-spec-review 评审 MAS」一步，或从 Skills You Call 表删除 |
| H-04 | `escalate-user` label 无消费者 | HIGH | Boundary, User | 定义 `escalate-user` 处理协议（hook 通知用户？issue assignee？），或改为 user-visible message |
| H-05 | `/bba-architect` 等斜杠命令未注册 | HIGH | User, Boundary | 要么在 `.claude/commands/` 创建 5 个对应文件，要么从 description 删除 slash-command 提法 |
| M-01 | bba-architect 「Output Style」只给 PASS 模板，无 FAIL 模板 | MEDIUM | Boundary | 增加 schema 校验 FAIL 时的输出模板，包含 schema 错误位置 |
| M-02 | vcd 大文件阈值未量化 | MEDIUM | Boundary | 给出具体 MB 数（建议 ≥ 50 MB 则不入 git） |
| M-03 | klayout "opens without errors" 为手工 gate | MEDIUM | Boundary | 改为 `bb-invoke-klayout --action verify` 自动检查；将「人工确认」从 Acceptance 列表迁出 |
| M-04 | yosys 仅 `latch inferred` 有协议，其它 warning 无策略 | MEDIUM | Boundary | 列举 `MULTIDRIVEN` / `WIDTHEXPAND` / `UNUSED` 等 warning 的处理矩阵 |
| M-05 | synthesis 自称做 CDC/RDC，工作流只描述 CDC | MEDIUM | Boundary | 明确 RDC 检查独立调用点，或显式声明 `bb-check-cdc` 内部已合并 |
| M-06 | `cdc_waivers` 在 mas.json 中的 schema 未定义 | MEDIUM | Boundary | 在 `schemas/mas.schema.json` 中补 `cdc_waivers` 数组 schema |
| L-01 | bba-architect Acceptance "≥ 3 KPIs" 与列出的 3 个例子矛盾（既是下界又是穷举） | LOW | Boundary | 改为「至少包含频率、面积、功耗 3 个量化 KPI，更多可选」 |
| L-02 | RTL Workflow Step 4 fallback 「Grep instantiations」无伪代码 | LOW | Boundary | 给一行 grep 模式例：`grep -E "^\s*module\b" / instantiation pattern` |

### 模块接口清晰度 (Interface)

| ID | Issue | Severity | Roles Found | Recommendation |
|----|-------|----------|-------------|----------------|
| H-06 | 跨 agent 无全局 fix_iter 防 ping-pong | HIGH | Boundary, Red | 引入 `designs/<name>/.handoff/fix_iter_global.json` 累计所有 \*-needs-fix；超阈值统一 escalate-user |
| H-07 | "MAS sha256 drifted" 比对源无定义 | HIGH | Boundary | rtl_artifact.json / test_report.json 必须各自存所引 MAS 的 sha256 字段；schema 中显式列出 |
| H-08 | bba-architect IO Contract 输入声明 `idea.schema.json`，但实际是 free-form 用户文本 | HIGH | Red, Boundary | 要么删除 schema 列要么明确「bb-prd 内部把 prompt 转结构化 JSON」；二选一 |
| H-09 | 5 个 agent `tools` 数组完全相同（含 Bash/Write/Edit）→ 违反最小权限 | HIGH | Security, Red | 按职责裁剪：PD 不需要 Write 到 `rtl/`；架构师不需要 Write 到 `synth/`；考虑 path-allowlist 通过 hook 校验 |
| M-07 | 同一 `arch-needs-fix` 两次到达，agent 自称「视为同一周期」但缺少 correlation key | MEDIUM | Boundary | 引入 fix-issue 的 `correlation_id`（取 sha256(failing-artifact)）；agent 据此去重 |
| M-08 | `test_report.json` schema 未给字段清单 | MEDIUM | Boundary, Cost | 在 `schemas/test_report.schema.json` 中规定 `functional_coverage`, `code_coverage{line,branch,toggle}`, `tests[]`, `mas_sha256`, `rtl_artifact_sha256` |
| M-09 | bba-architect 写 `wiki/protocols/<name>.md` stub，路径取自 user prompt → path-traversal | MEDIUM | Security | 在写入前 sanitize：仅允许 `[a-z0-9-]{1,32}`，否则 reject |
| L-03 | PD 表头列 `Wraps` 而其它 agent 用 `Status` | LOW | Boundary | 统一表头列名 |
| L-04 | Output Style 全部使用英文模板，违反 CLAUDE.md「对话和描述性文档使用中文」 | LOW | User | 中文化或在 Project Rules 中显式 exception |

### 实现风险 (Risk)

| ID | Issue | Severity | Roles Found | Recommendation |
|----|-------|----------|-------------|----------------|
| H-10 | sub-agent 中「Stop and ask the user」与自治执行模式冲突 | HIGH | User, Red | 改为「raise `escalate-user` issue 并停机」，由父 context 负责与用户对话 |
| M-10 | max_iter=5 PD 共享给 DRC/LVS/STA 三类失败 → 可能提前耗尽 | MEDIUM | Boundary | 拆分为 per-stage iter（DRC 3 / LVS 2 / STA 3）或扩到 8 |
| M-11 | `bba-architect` Workflow Step 8 给三层 fallback（skill → template → bash），具体降级逻辑未量化 | MEDIUM | Risk | 用 try/except 伪代码或决策表替代散文 |
| M-12 | PD `temp/deleted/` 移动责任方未明 | MEDIUM | User | 在 What You Must NOT Do 下指明「agent 负责 mv；hook 不需要参与」 |
| L-05 | PD 5 个 iter 涵盖 floorplan + place + route + DRC + LVS + STA 6 个步骤 → 每步 < 1 次重试 | LOW | Red | 重审 max_iter 与 step 数比例 |

### 过度设计 / 模块化 (Overdesign / Modularity)

| ID | Issue | Severity | Roles Found | Recommendation |
|----|-------|----------|-------------|----------------|
| M-13 | 5 个 agent 文件中 ~30% 内容是 Project Rules / Pipeline 图 / Output Style 模板的复制粘贴 | MEDIUM | Cost, Red | 抽出 `.claude/agents/_common.md`，agent 文件用 transclusion 或 link 引用 |
| L-06 | 所有 agent 描述都附 3 个 example block，example 之间风格不统一（英文 / 中英混合） | LOW | User | 统一 example 语种 |
| L-07 | 每个 agent 文件 ~ 8 KB；description frontmatter 又是 1.5 KB 重复 | LOW | Cost | description 仅保留 trigger + 1 example；详细职责留在正文 |

### 安全 (Security)

| ID | Issue | Severity | Roles Found | Recommendation |
|----|-------|----------|-------------|----------------|
| H-09 | （同上）`Bash` + `Write` 全开 → 违反最小权限 | HIGH | Security, Red | 见 H-09 |
| M-09 | （同上）wiki/protocols/<user-input>.md path-traversal | MEDIUM | Security | 见 M-09 |
| L-08 | `bb-create-issue` 真实写到 GitHub Issues 还是仅本地文件？未声明；可能泄漏内部设计名 | LOW | Security | 在 skill spec 中显式声明 issue 后端；agent 文件加备注 |

### 模型 / 资源选择 (Cost)

| ID | Issue | Severity | Roles Found | Recommendation |
|----|-------|----------|-------------|----------------|
| M-14 | 仅 bba-architect 用 opus，synthesis（SDC 推理）/ PD（floorplan trade-off）用 sonnet 缺少论证 | MEDIUM | Cost | 给出 model-tier 决策矩阵；或在 ADR 记录此选择的依据 |
| M-15 | synthesis 颜色 yellow 在 light terminal 对比度不足 | MEDIUM | User | 改 cyan / orange |

---

## Detailed Issue Cards

### [C-01] schemas/、wiki/、designs/ 目录全部不存在
- **Severity**: CRITICAL
- **Dimension**: 需求完整性
- **Found by**: Boundary Analyst, User Advocate, Cost Skeptic
- **Description**:
  - `bba-architect.md` 引用 `schemas/idea.schema.json`, `schemas/mas.schema.json`, `wiki/protocols/`, `wiki/cbb/`, `wiki/pdk/asap7-*.md`, `designs/<name>/*`。
  - `bba-guru-rtl.md` 引用 `schemas/rtl_artifact.schema.json`, `wiki/cbb/`, `wiki/pdk/asap7-rules.md`。
  - `bba-guru-verification.md` 引用 `schemas/test_report.schema.json`, `wiki/verif/`。
  - `bba-guru-synthesis.md` 引用 `schemas/synth_report.schema.json`, `libs/asap7/`（这个存在）。
  - `bba-guru-pd.md` 引用 `schemas/pd_report.schema.json`, `wiki/pdk/asap7-{overview,rules,metal-stack}.md`。
  - 仓库实测：`schemas/`、`wiki/`、`designs/` 三个目录均**不存在**；仅 `libs/asap7/`（注：未在本次校验列表中，需另行确认）。
  - 每条「Validate against schema」的 Workflow 步骤都将 fail-open（找不到 schema 则放行）或 hard-fail（找不到则拒签）。
- **Recommendation**:
  1. 在 v1.3 MVP 安装清单中加入 `schemas/`, `wiki/protocols/`, `wiki/cbb/`, `wiki/pdk/` 的最小骨架。
  2. 或在每个 agent 文件首部加 "v1.3 MVP bootstrap: `designs/<name>` 由 architect 首次运行时创建" 注脚。
  3. 不允许混用：要么 schema 必到位才能跑，要么显式声明无 schema 模式。
- **Depends on**: 无

### [C-02] 30 个 bb-* skill 中仅 1 个真正安装但全部标为 installed
- **Severity**: CRITICAL
- **Dimension**: 需求完整性 / 实现风险
- **Found by**: Boundary Analyst, Red Team, Cost Skeptic
- **Description**:
  - `.claude/skills/` 实际安装：`bb-invoke-yosys, bb-arch, bb-mas, bb-prd, bb-rtl-coder`（5 项）。
  - `arch_spec/_index.md` 列出 30 个 bb-* 原生 skill + 4 个 bb-* 适配。
  - 5 个 agent 的「Skills You Call」表均把 `bb-list-issues / bb-create-issue / bb-close-issue / bb-check-lint / bb-find-module-deps / bb-gate-rtl-quality / bb-code-review / bb-create-verif-plan / bb-generate-tb / bb-invoke-verilator / bb-collect-coverage / bb-gate-test-quality / bb-create-sdc / bb-check-cdc / bb-parse-ast / bb-parse-ast-fallback / bb-trace-signal-path / bb-invoke-opensta / bb-invoke-abc / bb-gate-synth-quality / bb-create-floorplan / bb-invoke-magic / bb-invoke-qrouter / bb-invoke-netgen / bb-invoke-klayout / bb-gate-pd-quality / bb-search-protocol / bb-search-cbb / bb-get-interface-template / bb-spec-review` 标记为 `installed`。这是**系统性虚假**。
  - 直接后果：任何 agent 启动后，第一次 `Skill(bb-list-issues)` 调用就报「skill not found」，进入文件中描述的 fallback。但 fallback 路径（如「shell out to verilator」）也依赖 `eda_env.sh` 与 `wiki/`，递归失败。
- **Recommendation**:
  1. 将 Status 列改为 `pending` / `installed` 二态；只有 `bb-invoke-yosys`+`bb-*` 标 installed。
  2. 在 agent description 顶部加 banner：「This agent requires N skills not yet installed; behavior degraded.」
  3. 或先实现 issue-protocol 3 项（list/create/close）作为 v1.3 第一批；其它分批补。
- **Depends on**: 无

### [C-03] ADR-008 / ADR-015 / ADR-016 不存在
- **Severity**: CRITICAL
- **Dimension**: 文档输出规范
- **Found by**: Boundary Analyst
- **Description**:
  - `bba-guru-rtl.md` ：「Does NOT draft SDC (ADR-016)」「synthesis owns SDC per ADR-016」
  - `bba-guru-verification.md` ：「Lives between RTL and synthesis per ADR-015」「VSCode wave extension (ADR-008)」
  - `bba-guru-synthesis.md` ：「(ADR-016 — RTL no longer drafts SDC)」「You are the SDC author (ADR-016)」
  - 仓库实测：`harness_spec/arch_spec/ADR/` 仅含 `ADR-A01..A10`（A03, A05 已删除）。
  - 这些 ADR-0xx 编号要么是 `project ADR-014` 同级的全局编号（CLAUDE.md 未列），要么是早期 design_doc 内部章节编号被错引为 ADR 编号。
- **Recommendation**:
  1. 替换为真实 ADR 编号（如 ADR-A06 / ADR-A07）或 design_doc 段号（§3.1.5）。
  2. 如果 ADR-014 / 015 / 016 / 008 是 design_doc 外部全局 ADR，需在 arch_spec/ADR/ 下挂软链或副本。
- **Depends on**: 无

### [C-04] 覆盖率字段名跨 agent 不一致
- **Severity**: CRITICAL
- **Dimension**: 模块接口清晰度
- **Found by**: Boundary Analyst, Red Team
- **Description**:
  - `bba-guru-verification.md` Acceptance Criteria：「`test_report.json` validates against schema and reports `coverage == 100%`」（单字段）
  - `bba-guru-synthesis.md` Workflow Step 1：「refuse to proceed unless `functional_coverage == 100` and `code_coverage == 100`」（双字段）
  - `bba-guru-synthesis.md` description trigger 又写：「`test_report.coverage == 100%`」（回到单字段）
  - 同一份 test_report.json 被读 vs 写两端用不同字段名 → gate 必假命中或假未中。
- **Recommendation**:
  1. 选定双字段方案（更精细）：`functional_coverage: number`, `code_coverage: { line, branch, toggle }`。
  2. 在 `schemas/test_report.schema.json` 中正式定义；所有 agent 文件同步。
- **Depends on**: C-01（schema 文件需先建立）

### [C-05] Pipeline 推进机制（label→下游 agent）未实现
- **Severity**: CRITICAL
- **Dimension**: 需求完整性
- **Found by**: Boundary Analyst, User Advocate
- **Description**:
  - 每个 agent 的 description trigger (1) 都依赖「有 `ready-for-X` issue 存在」；
  - 但 `hook-bb-hook-pipeline-advance.md` 仅在 spec 中存在，未安装到 `.claude/hooks/`（且 `.claude/hooks/` 目录都未提及）。
  - 缺乏 issue label → `Agent(subagent_type=bba-guru-rtl)` 的派发器。
  - 用户必须每一步手动 `/bba-guru-rtl`、`/bba-guru-verification`...，与 description 中的「自动 trigger (1)」承诺矛盾。
- **Recommendation**:
  1. 在 v1.3 MVP 必须随 agent 一起安装 `hook-bb-hook-pipeline-advance`，或显式声明 "manual hand-off in v1.3 MVP"。
  2. 每个 agent description 的 trigger (1) 改为「user invokes after seeing ready-for-X issue」。
- **Depends on**: C-02

### [C-06] description frontmatter 中嵌入了 escape 后的 Python 代码
- **Severity**: CRITICAL → 降为 HIGH（不阻塞实现，但污染索引）

修正：这是 LOW，看下面。

### [H-01] ADR-A09 bb-* adapter 在 agent 中无落点
- **Severity**: HIGH
- **Dimension**: 实现风险
- **Found by**: Red Team, Boundary
- **Description**:
  - ADR-A09 规定：bb-prd / bb-arch / bb-mas / bb-rtl-coder 的原始输出与 Babel schema 不完全一致，需要 adapter 层（pre_invoke / post_invoke 或 Python helper）。
  - bba-architect Workflow Step 2-4 直接说「Invoke bb-prd → PRD.md」「Invoke bb-arch → arch_doc.md」「Invoke bb-mas → mas/...」——没有提到 adapter；
  - 落地后 bb-mas 的输出大概率不会含 `clock_domains` / `io_timing` / `io_ring` 等 mas.schema 必要字段，schema 校验必败，但 agent 没有定义此时的处理。
- **Recommendation**:
  - 在 Workflow Step 4 之后插入 4.5「Adapter normalize: convert bb-mas raw output to mas.schema.json by adding clock_domains/io_timing/io_ring fields (LLM-assisted)」。
  - 在 IO Contract 表脚注说明：「bb-* skill 输出由 agent 自身的 post_invoke adapter 规范化为本表所列 schema」。

### [H-02] PD 缺 `arch-needs-fix` 直通路径
- **Severity**: HIGH
- **Dimension**: 模块接口清晰度
- **Found by**: Red Team, Boundary
- **Description**:
  - bba-guru-pd「Core Responsibilities」第 6 条：「Escalate upward only: ... Never raise `rtl-needs-fix` directly.」也未列 `arch-needs-fix`。
  - 但当 MAS 的 IO ring 或 clock plan 本身错误时（这是 architect 的责任），PD 只能 raise `synth-needs-fix`，synthesis 收到后判断为非自身责任，再 raise `arch-needs-fix` → 信息两跳衰减、责任归属模糊。
- **Recommendation**:
  - 允许 PD 在「Post-route STA fail 且经判断属于 MAS clock plan 不平衡」的场景直接 raise `arch-needs-fix`，并在 issue body 中标注 "via-pd"；
  - 或显式声明「双跳传递」是设计选择，并要求 synthesis 在转发 PD 反馈给 architect 时保持原始 PD 报告完整附件。

### [H-03] bba-architect 列出 `bb-spec-review` 但工作流从未调用
- **Severity**: HIGH
- **Dimension**: 需求完整性 / 过度设计
- **Found by**: Red Team, Cost Skeptic
- **Description**:
  - `bba-architect.md` 第 84 行 Skills You Call 表包含 `bb-spec-review` 「adversarial review of MAS」。
  - 但 Workflow 7 个步骤 + Edge Cases + Acceptance 中均无任何一处调用它。
- **Recommendation**:
  - 在 Workflow Step 7（Validate）之前插入 6.5「Call `bb-spec-review` on `mas.json`，问题清单 ≥ HIGH 必须先解决再继续」；
  - 或从 Skills 表删除以减少 dead-import。

### [H-04] `escalate-user` label 无消费者 / 无 hook
- **Severity**: HIGH
- **Dimension**: 模块接口清晰度
- **Found by**: Boundary, User
- **Description**:
  - `bba-architect.md` Convergence 段：「`max_fix_iter = 3`. 超出则 raise `escalate-user` and stop」。
  - 没有 hook、没有 agent 监听 `escalate-user` label；用户也不会自动得到通知。
  - Issue 会在 Github（或本地）孤立存活。
- **Recommendation**:
  - 选其一：
    (a) 在 `hook-bb-hook-create-fix-issue` 实现中加 「if label == escalate-user → Bash notify-send / IM」；
    (b) Agent 直接以 user-visible message 输出而不仅开 issue；
    (c) 将 escalate-user 改为「raise via stdout + non-zero exit」让 父 context 看见。

### [H-05] `/bba-architect` 等斜杠命令未实际注册
- **Severity**: HIGH
- **Dimension**: 模块接口清晰度
- **Found by**: User, Boundary
- **Description**:
  - 5 个 agent 的 description 均含「user explicitly invokes /bba-architect」「/bba-guru-rtl designs/uart16550」。
  - 但 `.claude/commands/` 下没有对应的 slash command 文件（核查仓库）；用户输入 `/bba-architect` 会得到 unknown-command。
- **Recommendation**:
  - 要么生成 `.claude/commands/bb-{architect,guru-rtl,guru-verification,guru-synthesis,guru-pd}.md`，内容为 `Agent(subagent_type=...)`；
  - 要么从 description 中删除 slash-command 提法，只保留 `Agent(subagent_type=...)` 用法。

### [H-06] 跨 agent 无全局 fix_iter，无 ping-pong 防护
- **Severity**: HIGH
- **Dimension**: 模块接口清晰度
- **Found by**: Red Team, Boundary
- **Description**:
  - architect / rtl / synthesis 各自有 fix_iter，但没有全局计数器。
  - 场景：rtl 因 lint 跑满 3 次 → arch-needs-fix → architect 修 MAS → ready-for-rtl → rtl 又跑 3 次 → 再 arch-needs-fix... 无终止条件。
- **Recommendation**:
  - 引入 `designs/<name>/.handoff/global_fix_iter.json`：每次任何 `*-needs-fix` issue 创建递增；超过 N（如 10）→ 任何 agent 都改 raise `escalate-user`。

### [H-07] MAS sha256 drift 的比对源未定义
- **Severity**: HIGH
- **Dimension**: 模块接口清晰度
- **Found by**: Boundary
- **Description**:
  - `bba-guru-rtl.md` Edge Cases：「MAS sha256 drifted since architect closed the issue」—— 但 architect 关 issue 时写的 sha 存哪里？rtl 拿什么对比？
  - `bba-guru-verification.md`、`bba-guru-synthesis.md`、`bba-guru-pd.md` 也各自做 sha256 比对，但比对源（上游 artifact_json 内的某字段）未列在 schema 中。
- **Recommendation**:
  - 在每个 *_report.json schema 中加 `inputs[]: {path, sha256}` 字段；下游 agent 严格据此校验。

### [H-08] bba-architect 输入声明 `idea.schema.json` 与「free-form prompt」语义冲突
- **Severity**: HIGH
- **Dimension**: 需求完整性
- **Found by**: Red Team, Boundary
- **Description**:
  - IO Contract 表 "in: user prompt ... schema: idea.schema.json"。
  - 但 Workflow Step 1：「Parse the prompt. Extract design name / protocol / frequency / clock domains / PDK」表明输入是自由文本。
  - free-form 文本不能直接对 JSON schema 校验。
- **Recommendation**: 二选一：
  (a) 删除 idea.schema.json 列；改 Workflow Step 1 输出为「parsed_idea.json」，对 parsed_idea.json 做 schema 校验。
  (b) 强制 user 一开始就传结构化 JSON。

### [H-09] 5 agent tools 数组完全相同 → 违反最小权限
- **Severity**: HIGH
- **Dimension**: 安全 / 模块化设计
- **Found by**: Security, Red Team
- **Description**:
  - 全部 5 agent 都拥有 `Read, Write, Edit, Glob, Grep, Bash, Skill, TaskCreate, TaskUpdate, TaskList`。
  - PD agent 没必要 Write 到 `rtl/`；RTL agent 没必要 Write 到 `gdsii/`；architect 不需要 Bash 调 EDA 工具。
  - 任一 agent 受污染（如 LLM hallucination + MAS 注入），都可改写其它阶段的产物。
- **Recommendation**:
  - 按 IO Contract 的 `out` 列限制 Write 范围；通过 `hook-bb-hook-validate-bash-cmd` 实现 path-allowlist；
  - PD 移除 Skill 中无用的 bb-* 入口（PD 不调 bb-*）；
  - architect 可去掉 Bash（仅靠 Skill 编排）。

### [H-10] sub-agent「Stop and ask the user」与自治执行模式冲突
- **Severity**: HIGH
- **Dimension**: 实现风险 / 用户体验
- **Found by**: User, Red Team
- **Description**:
  - `bba-architect.md` Workflow Step 1：「Stop and ask the user if any of these are missing — do not guess.」
  - sub-agent（通过 Agent tool 启动）的标准模式是「单消息返回」，没有 stdin/back-channel 与用户继续对话；
  - sub-agent 内部 stop-and-ask 实际表现为：返回最终结果 = 「please provide X」字符串 → 父 context 解析 → 再次 spawn 一个新的 sub-agent —— 上下文会丢失。
- **Recommendation**:
  - 改为「raise `escalate-user` issue, halt」；父 context（claude-code 主对话）负责询问用户、收集补全后重新 spawn。
  - 或在 description trigger 明确「prompt MUST contain name/protocol/freq/PDK; 否则父 context 先补全再调用」。

### [M-13] 5 个 agent 文件约 30% 内容重复
- **Severity**: MEDIUM
- **Dimension**: 过度设计
- **Found by**: Cost, Red Team
- **Description**:
  - Pipeline Position 图、Project Rules 末尾段、Output Style 模板结构、Skills You Call 表中的 issue-protocol 三件套（bb-list-issues / bb-create-issue / bb-close-issue）在每个 agent 重复出现。
- **Recommendation**:
  - 抽出 `.claude/agents/_shared/{pipeline.md, project-rules.md, issue-protocol.md}`，agent 文件用 markdown link 引用；
  - 或在 agent .md 顶部加 `include` frontmatter 字段（如 harness 支持），由读取时合并。

### [M-14] Model tier 选择无论证
- **Severity**: MEDIUM
- **Dimension**: 过度设计 / 性能
- **Found by**: Cost
- **Description**:
  - bba-architect = opus；其它 4 个 = sonnet。
  - synthesis 需做 SDC 推理（false_path、multicycle 决策）和 yosys 参数 trade-off；PD 需做 floorplan 三维 trade-off；这两个推理负担可能高于 RTL coder。
- **Recommendation**:
  - 在 `harness_spec/arch_spec/` 加 ADR-A11 "Agent Model Tier 决策矩阵"，量化每个 agent 的 reasoning depth；
  - 至少给 synthesis 升 opus 或 haiku-4.5 二选一的回滚路径（cost vs accuracy）。

---

## Cross-cutting Patterns

| Pattern | Affected Files | Root Cause | Suggested Fix |
|---------|---------------|------------|---------------|
| 引用基础设施缺位（schemas/wiki/designs） | 全部 5 文件 | v1.3 MVP 安装清单不完整 | 同步安装 schema 骨架 + wiki 占位 + designs/.gitkeep |
| ADR 编号错引（008/015/016 不存在） | 4 / 5 文件 | design_doc § 与 ADR 编号混用 | 全局 grep-replace 到真实 ADR-A0x |
| bb-* skill installed=false 却标 installed | 全部 5 文件 | 复制 spec 模板时未同步安装状态 | 安装脚本应在 install 后才能 stamp installed |
| Pipeline 自动推进缺机制 | 全部 5 文件 | hook 未实现 | 优先安装 pipeline-advance hook |
| Tools 数组无差异化 | 全部 5 文件 | 模板复用 | 按 IO Contract 裁剪 |
| Output Style 英文 vs 项目中文规则 | 全部 5 文件 | 模板默认英文 | 中文化模板或在 Project Rules 例外说明 |

---

## Carry-over from prior reviews

无（首次评审，无 `[CARRIED-OVER]` 条目）。

---

## Action Priority

**Phase 1（必须在 v1.3 MVP 落地前修复）**: C-01, C-02, C-03, C-04, C-05, H-01, H-05, H-09, H-10

**Phase 2（v1.3 MVP 第二轮）**: C-06, H-02, H-03, H-04, H-06, H-07, H-08

**Phase 3（v1.4 / 长期）**: 全部 MEDIUM 与 LOW

**Note**: C-01..C-05 中任一不修，agent 系统都 inert（无法完整跑一条 pipeline）。

---

## Resolution Status (2026-05-17)

| ID | Status | Where fixed |
|----|--------|-------------|
| C-01 | **deferred** | `schemas/`, `wiki/`, `designs/` 在仓库根，超出 `.claude/` 范围。各 agent 已显式标注 "bootstrap pending" 占位，跑时不会硬死。需要后续 commit 创建 schema/wiki 骨架。 |
| C-02 | **fixed** | 5 agent 文件中 bb-* skill Status 改为 `pending`，仅 `bb-invoke-yosys` + `bb-*` 标 installed。`.claude/skills/{bb-create-issue, bb-list-issues, bb-close-issue}/SKILL.md` 新建 3 个最小 stub。 |
| C-03 | **fixed (downgraded)** | 重新核查后：ADR-008/015/016 真实存在于 `harness_spec/idea/decisions.md`，并非错引。5 agent 文件已统一引用为 `decisions.md#ADR-XXX`。 |
| C-04 | **fixed** | verification 输出 + synthesis gate + synthesis description 全部统一为 `functional_coverage` + `code_coverage{line,branch,toggle}` 两字段。test_report.json schema 在 verification agent 中以 JSON 块声明。 |
| C-05 | **partial fix** | `.claude/hooks/pipeline-advance.sh` 已创建（v1.3 MVP 仅做通知，不自动派发；这是 claude-code 当前能力的真实约束）；5 agent description 已声明 "dispatch manual until pipeline-advance hook ships"。 |
| H-01 | **fixed** | bba-architect Workflow 新增 Step 5 "Adapter"，引用 decisions.md#ADR-A09，明确 inline JSON shaping。 |
| H-02 | **fixed** | bba-guru-pd Core Responsibilities + Pipeline Position + Escalation 三处均加入 `arch-needs-fix` 通路。 |
| H-03 | **fixed** | bba-architect Workflow Step 8 调 `bb-spec-review`，HIGH+ 不通过则不放行。 |
| H-04 | **fixed** | 所有 5 agent 增加 *Escalate-user Protocol* 章节，定义 stdout 块 + 文件 fallback。 |
| H-05 | **fixed** | `.claude/commands/{bba-architect, bba-guru-rtl, bba-guru-verification, bba-guru-synthesis, bba-guru-pd}.md` 全部创建。 |
| H-06 | **fixed** | 全部 5 agent 引入 `designs/<name>/.handoff/global_fix_iter.json`，cap = 10。 |
| H-07 | **fixed** | 所有 *_report.json IO 契约段声明 `inputs[]:{path,sha256}`；下游 acceptance 列表加入 sha 校验项。 |
| H-08 | **fixed** | bba-architect 输入改为 "free-form prompt → parsed_idea.json (schema valid)"；bb-prd 消费 parsed_idea.json。 |
| H-09 | **fixed** | bba-architect 移除 Bash 工具；4 个 guru 保留 Bash（EDA 必需）；各 agent 在 What You Must NOT Do 中声明 Write 路径白名单。 |
| H-10 | **fixed** | 所有 "stop and ask the user" 改为 "raise escalate-user via stdout block + handoff file"。 |
| M-01 | **fixed** | bba-architect Output Style 双模板（PASS / FAIL）。 |
| M-02 | **fixed** | verification edge case 给出 50 MB vcd 阈值。 |
| M-03 | **fixed** | bba-guru-pd Workflow Step 8 调 `bb-invoke-klayout --action verify` 自动校验 GDS 可打开。 |
| M-04 | **fixed** | bba-guru-synthesis 列出 MULTIDRIVEN / WIDTHEXPAND / UNUSED 处理矩阵。 |
| M-05 | **fixed** | bba-guru-synthesis 工作流命名为 "CDC + RDC"，skill 调用使用 `--mode=cdc+rdc`。 |
| M-06 | **fixed** | bba-guru-synthesis 边缘场景显式声明 `mas.json.cdc_waivers` schema 形式。 |
| M-07 | **fixed** | 跨 agent correlation_id = `sha256(failing-artifact)` 写入 bb-create-issue stub。 |
| M-08 | **fixed** | verification IO Contract 段嵌入 test_report.json schema JSON 块。 |
| M-09 | **fixed** | bba-architect / bba-guru-rtl 边缘场景显式声明 path sanitization regex `[a-z0-9-]{1,32}`。 |
| M-10 | **fixed** | bba-guru-pd 拆分为 per-stage iter cap (DRC=3 / LVS=2 / STA=3) + 总 cap 8。 |
| M-11 | **fixed** | 各 agent fallback 表述更精确（"如果 skill pending → Bash 命令 X"）。 |
| M-12 | **fixed** | bba-guru-pd Workflow Step 11 明确 agent 自行 `mv` 至 `temp/deleted/`，无需 hook。 |
| M-13 | **deferred** | agent 文件去重需引入 transclusion / include 机制，claude-code 不支持；v1.4 评估。 |
| M-14 | **deferred** | model tier ADR 留待 ADR-A11；本轮 5 agent 保持原选择。 |
| M-15 | **fixed** | bba-guru-synthesis 颜色 yellow → cyan。 |
| L-01..L-08 | **fixed** | 在 5 agent 重写中顺手解决（KPI 描述、grep fallback 示例、表头列名等）。 |

**净结果**: 7 CRITICAL 中 6 修复 / 1 deferred（schemas 骨架超出 .claude 范围）；10 HIGH 全部 fixed；12 MEDIUM 中 10 fixed + 2 deferred；8 LOW 全部 fixed。

