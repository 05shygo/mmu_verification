# PTW UVM 分阶段实施计划

本文档是 `ptw_phase1_test_sva_implementation_plan.md` 中“分阶段实施计划”的独立版本，并在抽离后重新按 `ptwspec.md` 全文和 PTW UVM 修改计划进行审核。后续 PTW verification plan 和 UVM 修改应按本文阶段逐个推进。

本文档只定义实施阶段、阶段产出、退出标准、文件归属和阶段间依赖；详细 test 场景、SVA 语义、reference model/scoreboard 算法仍以 `ptw_phase1_test_sva_implementation_plan.md` 的详细章节为任务库。

## 1. 输入文档与优先级

| 输入 | 作用 | 优先级 |
| --- | --- | --- |
| `doc/ptw_uvm_review/ptwspec.md` | PTW 全部功能真值，包含 §0-§16、旧答案冲突收敛、Q1-Q180 覆盖索引和 `ptw_overview.md` 归档。 | 最高 |
| `doc/ptw_uvm_review/ptw_phase1_test_sva_implementation_plan.md` | Verification plan 和 UVM 中 PTW 部分的详细修改计划，包含 test、SVA、reference、scoreboard、monitor、report。 | 高 |
| 现有 verification plan、traceability CSV、已有 UVM tests/SVA/ref model | 只能作为现状输入；若与 `ptwspec.md` 冲突，必须修改、拆分、删除、重归属或标 `obsolete-by-spec`。 | 低 |

实施中若发现本文与 `ptwspec.md` 冲突，按 `ptwspec.md` 修正本文；若本文与 `ptw_phase1_test_sva_implementation_plan.md` 的详细任务库冲突，优先检查是否是阶段边界或详细任务需要同步，不能靠口头解释关闭 requirement。

## 2. 全局签核原则

1. PTW source-side closure 必须由 `ptw_source_ref_model + ptw_source_sb` match，或由明确 source-side SVA/monitor 直接证据关闭。
2. `mmu_translation_sb`、`mmu_l1dtlb_spec_sb`、L1DTLB/L2TLB/CSR/Perf tests 只能作为 `consumer-only` 或 `auxiliary` evidence，不能替代 PTW source-side PTE/PMP/PDE/MAEE/MBUF/abort 检查。
3. Scoreboard 按 `{type,id}` 事务匹配，不检查固定 walk latency、固定 LSU latency 或固定仲裁返回顺序。
4. SVA 负责周期级协议、ready/valid 保持、onehot、priority、abort/drop 边界、PDE race、字段路由和不可发生事件；事务级 golden result 由 source ref/sb 关闭。
5. `ptw_l2tlb_cmplt` 只能作为 L2TLB completion OR，不允许用它单独决定 actual completion class。
6. 所有阶段都不得修改 PTW RTL functional path；缺少观测信号时只补 bind/probe/monitor，并在 probe gap 表登记。
7. 每个 P0/P1 assert 必须有 cover；assert pass 但 cover 未命中不能关闭测试点。
8. monitor-only 结果只能作为 `provisional`，不能签核 P0/P1 requirement。
9. Illegal/stress 场景必须从正常 regression gate 中隔离，不能把非法输入作为 DUT fail。

## 3. 不可遗漏的 PTW 规则

以下规则来自 `ptwspec.md`，是阶段审核时的硬检查点。任何阶段若影响这些规则，必须在阶段产出和退出标准中体现。

| 规则族 | 必须遵守的最终规则 | 主要关闭阶段 |
| --- | --- | --- |
| 请求模式 | Bare 模式、纯 M 态无翻译请求默认不进入 PTW；`MPRV=1 && MPP=M` 的 load/store/PFU direct-map VA=PA，不进入 PTW；fetch 不受 MPRV/MPP 影响，按真实流水线特权级判断。 | 阶段 0、2、4、6、7 |
| type/id | type 固定为 load `010`、fetch `011`、PFU `100`、store `110`；同 `{type,id}` 未完成前不得复用。 | 阶段 1、2、3、4、6、7 |
| 返回目标 | fetch 成功 refill L1ITLB+L2TLB；load/store 成功 refill L1DTLB+L2TLB；PFU 成功只 refill L2TLB；异常按原始 type/id 返回。 | 阶段 3、4、5、6 |
| PTE bit | `PTE[58:38]` high reserved 不 fault；RSW 不参与 page fault 但进入 refill `flg[8:7]`；G 不进 data flg，只进 tag/global。 | 阶段 2、4、5、6 |
| PTE fault | 不额外套标准 Sv39 reserved/strong-order；write-only 规则为 `W && !(R || (MXR && X))`；PFU 不要求 R/MXR/X/D，但要求 V/A/U-S/huge align/write-only。 | 阶段 4、5、6 |
| PMP | PMP 检查对象是读取 PTE 的物理地址，不是最终 PA；权限使用原始 request type；fetch 不受 MPRV，load/store/PFU 在 MPRV=1 时用 MPP。 | 阶段 2、4、5、6 |
| PDE cache | 两级 16 entry 全相联；double-hit 选 L2；lookup/update 同拍读旧值；satp/PMP clear-only 不 flush in-flight；abort/reset flush。 | 阶段 3、4、5、6、7 |
| MBUF/LSU | PTW PTE channel single outstanding；LSU bus error 不进 CHK、不 page fault、不 refill、不 PDE update；CHK not-ready 需 hold。 | 阶段 2、3、4、5、6 |
| MAEE/sysmap | MAEE=1 all page size 使用 raw PTE ext attr；MAEE=0 所有 page size 都用 sysmap，包括 4K；1G/2M 先 huge align fault，再 degrade；degrade 不访问 lower page table。 | 阶段 2、4、5、6、7 |
| Abort | `tlboper_ptw_abort` 全清 PDE cache 并 flush in-flight；abort 同拍普通 data 丢弃；abort 同拍新 bus error 不上报；abort 前已进入异常寄存器且当拍 grant 的异常可见。 | 阶段 2、3、4、5、6、7 |
| Sysmap illegal | sysmap no-hit/multi-hit 默认不产生；若 negative test 注入，必须标 illegal stimulus。 | 阶段 0、2、7 |

## 4. 阶段总览

| 阶段 | 名称 | 核心目标 | 主要产出 | 硬退出门槛 |
| --- | --- | --- | --- | --- |
| 阶段 0 | Spec baseline 与 traceability 冻结 | 把 `ptwspec.md` 全文转成可签核 requirement map。 | closure matrix、legacy test action list、ID audit。 | 每个 `PTW-AUD-*` 有绑定项；旧冲突 expected 不再作为 PTW closure。 |
| 阶段 1 | 公共类型与编译骨架 | 建立 source checker/SVA/test 的公共类型、开关和 include 路径。 | `ptw_source_types`、cfg knobs、env skeleton、filelist。 | 默认 compile 不破坏；开关打开可创建组件并打印 banner。 |
| 阶段 2 | Directed base 与刺激基础设施 | 稳定构造 raw PTE、PMP、sysmap、bus error、abort 窗口。 | PTW source base、page table builder 增强、PTW memory responder 增强。 | 任意 level/raw PTE 和关键 fault/drop 场景可复现。 |
| 阶段 3 | Probe/monitor/logger | 建立 source-side actual/probe transaction 可观测性。 | probe if、source monitor、scenario db、probe gap table。 | request/completion/refill/fault/drop 均可按 `{type,id}` 捕获。 |
| 阶段 4 | Reference/scoreboard MVP | 建立 P0 主干 source golden 和事务比对。 | PDE model、source ref model、source sb、summary report。 | success/fault/bus error/drop smoke 可 `mismatch=0 pending=0 illegal=0`。 |
| 阶段 5 | P0 SVA 与 cover gate | 固化周期级协议、路由、优先级、abort、PDE/MBUF/MAEE 边界。 | 新增/增强 SVA、bind/filelist、cover report。 | P0 SVA compile 通过，assert 0 fail，cover 可解析。 |
| 阶段 6 | P0 directed 与旧 test 修正 | 关闭 P0 source-side 功能主干，并清理旧错误 test。 | P0 tests、P0 list、legacy test patch、P0 closure report。 | P0 source match + SVA cover hit；`PTW-FLOW-001..023` 有证据或 open reason。 |
| 阶段 7 | P1/P2/random 完整化 | 补齐精度、压力、约束和随机回归解释能力。 | 完整 ref/sb、P1/P2 tests、random profile、field coverage。 | P1/P2 状态完整；随机无 unexpected mismatch/pending/illegal。 |
| 阶段 8 | Regression/signoff 冻结 | 形成可重复运行、可审查、可签核的最终交付。 | final lists、parser/gate、signoff report、waiver/open register。 | P0 全 pass；final report 可追溯每个 requirement 状态。 |

## 5. 阶段完成记录模板

每个阶段完成时必须在 closure matrix 或阶段报告中新增一条记录：

```text
PTW_STAGE_DONE stage=<N> name=<stage_name>
  status=<done|partial|blocked>
  commit_or_patch=<id/path>
  changed_files=[...]
  tests_run=[...]
  source_sb_summary=<mismatch/pending/illegal/provisional>
  sva_summary=<assert_fail/cover_missing>
  closure_delta=[PTW-AUD-..., PTW-ADD-..., PTW-FLOW-...]
  open_items=[...]
  next_stage_blockers=[...]
```

若某阶段因为缺 probe、旧环境限制、未接入回归脚本而只能部分完成，必须标 `partial`，并把受影响 requirement 写入 closure matrix。不能用“阶段已完成”掩盖未关闭的 source-side evidence。

## 6. 阶段 0：Spec Baseline、Traceability 与旧计划冻结

目标：把 `ptwspec.md` 全文收敛成可执行 closure 基线，冻结旧 verification plan 中与 PTW 相关的条目归属，避免后续实现期间继续沿用错误 expected。

任务：

1. 逐条确认 `ptwspec.md` §0-§16 的最终规则已经映射到本计划的 `PTW-AUD-*`、`PTW-ADD-*`、`PTW-FLOW-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*`、`PTW-INFRA-*`。
2. 建立或更新 `ptw_source_closure_matrix.md/csv`，列出 legacy id、audit id、flow id、test name、scenario id、source checker、SVA cover、consumer evidence、waiver/open reason。
3. 扫描现有 verification plan、`MMU_Traceability_Matrix.csv`、已有 test list，把旧 round-robin xbar、reserved-bit fault、PFU 按 load 检查、PTW memory OOO、system direct-map sysmap 等冲突项标记为 `obsolete-by-spec` 或重归属。
4. 定义统一术语和 ID 使用规则：PTW source-side、consumer-only、auxiliary、illegal stimulus、provisional、open、waived。
5. 明确默认非法/受约束输入：Bare 进 PTW、纯 M 态无翻译进 PTW、sysmap malformed、同 `{type,id}` 复用、PTW memory OOO、satp.asid/ppn 无 abort mid-walk。

任务产出：

| 产出 | 内容 |
| --- | --- |
| `ptw_source_closure_matrix.md` | 面向人工审查的 closure 表，列出每个 requirement 的当前状态。 |
| `ptw_source_closure_matrix.csv` | 面向脚本 gate 的可机读版本。 |
| legacy test action list | 每个旧 test 的保留、修改、拆分、删除、重归属或 obsolete 结论。 |
| ID coverage audit | `PTW-AUD-001..023`、`PTW-ADD-001..036`、`PTW-INFRA-001..009`、`PTW-FLOW-001..023` 的完整性检查。 |

相关文件：

| 文件/目录 | 说明 |
| --- | --- |
| `doc/ptw_uvm_review/ptwspec.md` | 唯一功能真值。 |
| `doc/ptw_uvm_review/ptw_phase1_test_sva_implementation_plan.md` | 详细任务库。 |
| `doc/ptw_uvm_review/ptw_source_closure_matrix.md` | 建议新增，记录人工 closure。 |
| `mmu_verification/simu/ptw_source_closure_matrix.csv` | 建议新增，供回归脚本解析。 |
| `MMU_Traceability_Matrix.csv` | 若仓库存在，必须完成 legacy id 映射。 |

退出标准：

1. 每个 `PTW-AUD-*` 至少绑定一个 `PTW-ADD-*` 或 `PTW-FLOW-*`，并有预期 source checker/SVA evidence。
2. 与 `ptwspec.md` 冲突的旧测试点全部有处理动作，不允许继续作为 PTW closure。
3. 所有 illegal stimulus 已在 matrix 中标明，不会被正常 regression 计入 DUT fail。
4. 本阶段不要求新增 UVM 代码，但要求文档和 closure matrix 可用于指导后续实现。

## 7. 阶段 1：公共类型、配置开关与编译骨架

目标：先建立 PTW source checker、SVA 和 test 的公共编译骨架，保证后续阶段可以增量接入，不在多个文件中重复定义 magic number 或临时 struct。

任务：

1. 新增 `ptw_source_types`，统一定义 type/page-size enum、fault kind、page level、drop reason、target kind、PTE raw decode helper、flg/tag/data format helper。
2. 在 `mmu_top_cfg.svh` 增加 source checker/SVA/coverage/report 开关，包括 `en_ptw_source_ref_model`、`en_ptw_source_sb`、`en_ptw_source_monitor`、`en_ptw_source_cov`、`en_ptw_source_strict_illegal`。
3. 在 `mmu_env_pkg.sv` 接入新增类型和空组件声明，保证 include/import 顺序稳定。
4. 在 `mmu_env.svh` 建立 build/connect 的空骨架，不要求完整功能，但开关关闭时不得影响现有回归。
5. 在 `Files.f` 或统一 filelist 中加入新增 SVA/source checker 文件占位，先保证编译路径明确。
6. 建立统一 report banner 和 summary 格式占位：`PTW_SOURCE_SB_SUMMARY`、`PTW_SVA_COVER`、`PTW_SOURCE_CLOSURE`。

任务产出：

| 产出 | 内容 |
| --- | --- |
| `ptw_source_types_pkg.sv` 或 `ptw_source_types.svh` | 公共 enum、struct、decode/format helper。 |
| cfg knob patch | 所有 PTW source checker 组件可独立打开/关闭。 |
| env/package skeleton | 组件声明、build/connect 占位、analysis port 名称固定。 |
| filelist patch | 新增文件进入编译路径，默认不破坏现有 suite。 |

相关文件：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_source_types_pkg.sv` 或 `ptw_source_types.svh` | 新增公共类型。 |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | include/import 新类型。 |
| `mmu_verification/testbench/env/mmu_env.svh` | build/connect 新组件占位。 |
| `mmu_verification/testbench/top/mmu_top_cfg.svh` | checker/SVA/report 开关。 |
| `mmu_verification/testbench/Files.f` | 新增源文件和 SVA 文件。 |

退出标准：

1. 默认配置下现有 smoke compile 通过。
2. 打开 `en_ptw_source_monitor/ref_model/sb` 时组件能创建并打印 banner，即使还不产生完整 expected。
3. 所有 PTW type/page-size 常量只来自公共定义，不再在新文件中手写 magic number。
4. 关闭新增开关时，现有 `mmu_ref_model` 和 `mmu_translation_sb` 行为不变。

## 8. 阶段 2：Directed Test Base、Page Table Builder 与 PTW Memory Responder

目标：让后续 directed test 能稳定构造 `ptwspec.md` 要求的 raw PTE、页级、权限、PMP、sysmap、bus error、abort 同拍窗口，而不是每个 test 手写刺激。

任务：

1. 新增 `ptw_source_directed_base.svh`，封装 Sv39 setup、SATP/ASID、MAEE、MXR/SUM、priv、MPRV/MPP、PMP allow/deny、sysmap region、PTW request driver、quiescent wait。
2. 增强 `page_table_builder.svh`，支持 raw PTE、leaf/non-leaf 指定 level、RSW、G、高保留位、扩展属性、1G/2M misaligned PPN、合法 pointer、非法 non-leaf。
3. 增强 `ptw_mem_sequences.svh`，支持 by-address/by-count deterministic response delay、bus error、same-cycle abort/data、same-cycle abort/bus-error、CHK not-ready/slow response。
4. 增强或组合 `cp0_sequences.svh`、`pmp_sequences.svh`、`sysmap_cfg_sequences.svh`，提供 PTW source directed helper，而不是让 test 直接操作底层寄存器。
5. 在 base 中统一记录 `tc_id/scenario_id/requirement_ids/context_samples/levels/expected/actual/result`。
6. 建立非法刺激保护：同 `{type,id}` 不复用、Bare/M no-request、sysmap malformed 默认禁止、PTW memory OOO 默认禁止。

任务产出：

| 产出 | 内容 |
| --- | --- |
| `ptw_source_directed_base.svh` | 所有 PTW directed tests 的公共基类和 helper API。 |
| enhanced `page_table_builder.svh` | 可构造所有 PTE/no-check/page-fault/degrade 场景。 |
| enhanced `ptw_mem_sequences.svh` | 可构造 bus error、slow response、abort 边界。 |
| scenario metadata API | 每个 test 可输出统一 scenario transaction。 |
| base smoke tests | 至少 1G/2M/4K success、page fault、access fault、bus error 各一个 smoke 场景。 |

相关文件：

| 文件/目录 | 说明 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh` | 建议新增。 |
| `mmu_verification/testbench/test/common/page_table_builder.svh` | 增强 raw PTE 与 page level 构造。 |
| `mmu_verification/testbench/test/common/ptw_mem_sequences.svh` | 增强 PTW memory responder。 |
| `mmu_verification/testbench/test/common/cp0_sequences.svh` | 复用或补 context helper。 |
| `mmu_verification/testbench/test/common/pmp_sequences.svh` | 复用或补 PTW level/type deny helper。 |
| `mmu_verification/testbench/test/common/sysmap_cfg_sequences.svh` | 复用或补 degrade region helper。 |
| `mmu_verification/testbench/test/ptw_tests` | 新增 base smoke wrapper。 |

退出标准：

1. 可以用公共 helper 构造任意 fst/scd/thd raw PTE，不需要 test 手写页表地址。
2. 可以 deterministic 触发 fst/scd/thd PMP deny、PTE page fault、LSU bus error、abort same-cycle data/bus-error。
3. 每个 smoke 场景都能打印完整 scenario metadata，至少包含 `type/id/vpn/level/raw_pte/pte_pa/context`。
4. 未接入 source scoreboard 前，结果只能标 `provisional`，但基础刺激必须稳定可复现。

## 9. 阶段 3：Probe、Monitor、Scenario Logger 与可观测性闭环

目标：把 DUT 内部 PTW request、memory channel、PDE cache、PMP/CHK、MAEE/sysmap、refill/exception/abort/drop 等事件转换为可用于 source ref/sb 的 transaction。

任务：

1. 新增或增强 `mmu_dut_probes_if.sv`，只读暴露 PTW request accept、VPN/type/id、refill tag/data、exception class、PDE hit/update/clear、PMP/sysmap/abort/LSU bus error 等必要信号。
2. 在 `tb_top.sv` 或 bind 文件中连接 probe，不改变 DUT functional path。
3. 实现 `ptw_source_monitor.svh`，输出 accepted request、actual completion、level event、PDE event、memory request/response、context sample、drop event。
4. 实现 `ptw_scenario_db.svh` 或等价 logger，保存 test 注册的 `scenario_id/requirement_id` 与 monitor actual transaction 的关联。
5. 将现有 `ptw_mem_monitor.ap_req/ap_rsp/ap_drop` fanout 到 PTW source checker，保证 raw PTE 和 bus error 以实际 memory response 为准。
6. 建立 probe gap 表：每个缺失 probe 必须说明影响、临时替代 evidence、关闭条件。

任务产出：

| 产出 | 内容 |
| --- | --- |
| enhanced `mmu_dut_probes_if.sv` | PTW source checker 所需只读 probe。 |
| `ptw_source_monitor.svh` | 统一 actual/probe transaction 生产者。 |
| `ptw_scenario_db.svh` | scenario metadata 记录和查询。 |
| probe gap table | 缺失信号、影响范围、计划补齐方式。 |
| monitor smoke report | 能看到 request、PTE memory response、refill/fault/drop transaction。 |

相关文件：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/top/mmu_dut_probes_if.sv` | 新增 PTW probe 字段。 |
| `mmu_verification/testbench/top/tb_top.sv` 或统一 bind 文件 | probe 连接。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 新增 monitor。 |
| `mmu_verification/testbench/env/ptw_scenario_db.svh` | 建议新增。 |
| `mmu_verification/testbench/env/mmu_env.svh` | monitor build/connect。 |
| `ptw_mem_monitor` 相关文件 | ap_req/ap_rsp/ap_drop fanout。 |

退出标准：

1. monitor 能按 `{type,id}` 捕获 request 和 visible completion，且不使用固定延迟假设。
2. `ptw_l2tlb_cmplt` 只作为 completion OR，不被 monitor 单独当作 completion class。
3. 对 refill，monitor 至少能捕获 `vpn/asid/page_size/ppn/global/flg/type/id/target`。
4. 对 fault，monitor 至少能区分 page fault/access fault、原始 `type/id` 和 target。
5. 对 drop，monitor 能捕获 reset/abort/late data/abort bus error/pre-existing exception grant 的关键窗口，不能捕获的必须登记 open。

## 10. 阶段 4：Source Reference Model 与 Scoreboard MVP

目标：先实现能关闭 P0 主干场景的 source-side golden model 和 scoreboard，建立 `{type,id}` 事务匹配、PTE/PMP/PDE/MAEE/abort/drop 的基本闭环。

任务：

1. 实现 `ptw_pde_cache_model.svh`，支持两级 16-entry 全相联、L1/L2/double-hit、lookup old-state、next-cycle update、clear-only、abort flush、directed replacement。
2. 实现 `ptw_source_ref_model.svh` MVP：request accept、PTE PA 生成、PMP deny、PTW memory response、PTE decode/page fault、refill tag/data/flg、MAEE=1、MAEE=0 4K sysmap、基本 abort/drop。
3. 实现 `ptw_source_sb.svh` MVP：expected queue、actual completion matching、drop/no-output matching、mismatch 分类、end-of-test pending 检查。
4. 明确 event ordering：request accept、satp/PMP clear、abort/reset、PDE lookup/update、memory response、actual completion 在同拍冲突时按 `ptwspec.md` 建模。
5. 比较字段覆盖 `vpn/asid/page_size/ppn/global/flg/type/id/target/fault_kind`，但不检查固定 latency。
6. 输出 summary：`PTW_SOURCE_SB_SUMMARY mismatch=<N> pending=<N> illegal=<N> provisional=<N>`。

任务产出：

| 产出 | 内容 |
| --- | --- |
| `ptw_pde_cache_model.svh` | PDE cache abstract model。 |
| `ptw_source_ref_model.svh` | PTW source golden algorithm MVP。 |
| `ptw_source_sb.svh` | `{type,id}` matching 和 mismatch report。 |
| source checker unit/smoke | 1G/2M/4K success、page fault、access fault、drop 能 match。 |
| mismatch taxonomy | `field_mismatch/class_mismatch/drop_mismatch/pending/illegal/probe_gap`。 |

相关文件：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | 新增。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 新增。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 新增。 |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | include 新组件。 |
| `mmu_verification/testbench/env/mmu_env.svh` | analysis port connect。 |
| `mmu_verification/testbench/top/mmu_top_cfg.svh` | checker 开关。 |

退出标准：

1. 基本成功、page fault、PMP access fault、LSU bus error、reset/abort drop 均可由 source scoreboard match。
2. scoreboard 不调用 `mmu_ref_model.translate()` 生成 PTW expected。
3. 同 `{type,id}` 未完成前复用会被标 illegal，不会污染正常 expected。
4. access/page/refill class 不由 `ptw_l2tlb_cmplt` 推断，必须来自具体 visible output。
5. end-of-test 能报 `mismatch=0 pending=0 illegal=0` 或明确列出 open/probe gap。

## 11. 阶段 5：P0 Source-side SVA 与 Cover Gate

目标：用 SVA 固化周期级协议、路由、优先级、保持、abort、PDE race、MBUF/LSU、MAEE/sysmap 等 source-side 规则，并建立 cover gate。

任务：

1. 新增 `mmu_ptw_top_sva.sv`，覆盖 request ready/hold、type/id、completion class OR、target route、access/page/refill priority、abort normal refill block。
2. 新增 `mmu_pde_cache_sva.sv`，覆盖 clear、double-hit L2 wins、hit level、update level、old-state lookup、no update on leaf/fault/bus error/abort/drop。
3. 新增 `mmu_ptw_xbar_sva.sv`，覆盖 VPN hash、target mask blocks only target、non-target mask no block、payload hold、abort no dispatch。
4. 新增 `mmu_twu_chk_sva.sv`，覆盖 leaf/non-leaf、write-only、fetch/load/store/PFU permission、U/S/SUM/effective M、huge align before degrade、RSW/high reserved no-fault、G not in flg。
5. 增强 `mmu_pmp_twu_sva.sv`，覆盖 PTE PA formula、original type permission、fetch no MPRV、load/store/PFU MPRV/MPP、deny no side effect。
6. 增强 `mmu_ptw_lsu_protocol_sva.sv`，覆盖 mbuf entry allocation、single outstanding、CHK not-ready hold、bus error no CHK/PDE/refill、abort outstanding、same-cycle data/bus-error。
7. 增强 `mmu_maee_twu_sva.sv`/`mmu_sysmap_sva.sv`，覆盖 MAEE=1 all-size、MAEE=0 all-size sysmap、4K sysmap、1G/2M degrade/no-degrade、no lower walk、flag order。
8. 在 `mmu_l1dtlb_sva.sv` 增加或确认 consumer-side PTW routing SVA，但明确标为 `consumer-only`。
9. 每个 P0/P1 assertion 配套 cover property 或 covergroup bin，并统一输出 `PTW_SVA_COVER`。

任务产出：

| 产出 | 内容 |
| --- | --- |
| new source-side SVA files | `mmu_ptw_top_sva.sv`、`mmu_pde_cache_sva.sv`、`mmu_ptw_xbar_sva.sv`、`mmu_twu_chk_sva.sv`。 |
| enhanced existing SVA | PMP、MBUF/LSU、MAEE/Sysmap、ARB、L1D consumer SVA。 |
| bind/filelist update | 所有新增 SVA compile 和 bind 成功。 |
| cover gate script/report | 每个 SVA cover hit 可被 regression 解析。 |

相关文件：

| 文件 | 说明 |
| --- | --- |
| `mmu_verification/testbench/top/mmu_ptw_top_sva.sv` | 建议新增。 |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | 建议新增。 |
| `mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv` | 建议新增。 |
| `mmu_verification/testbench/top/mmu_twu_chk_sva.sv` | 建议新增。 |
| `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv` | 增强。 |
| `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` | 增强。 |
| `mmu_verification/testbench/top/mmu_maee_twu_sva.sv` | 增强。 |
| `mmu_verification/testbench/top/mmu_sysmap_sva.sv` | 增强。 |
| `mmu_verification/testbench/top/mmu_arb_sva.sv` | 增强。 |
| `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` | consumer-side 补强。 |
| `mmu_verification/testbench/Files.f` | SVA 编译接入。 |

退出标准：

1. 所有新增/增强 SVA compile 通过，基础 smoke 无误报。
2. 每条 P0 assert 有对应 cover，cover 名称可在 report 中定位到 `PTW-AUD-*` 或 `PTW-ADD-*`。
3. abort 相关断言没有被全局 `disable iff (tlboper_ptw_abort)` 误屏蔽。
4. SVA 不使用 monitor-only 状态作为 DUT 功能判断输入，不改变 DUT path。
5. 已知无法观测的 SVA 子项必须登记 probe gap，不能静默跳过。

## 12. 阶段 6：P0 Directed Tests 与旧 Test 冲突修正

目标：实现能够关闭所有 P0 PTW source-side requirement 的 directed tests，并同步修改/拆分/删除与 `ptwspec.md` 冲突的旧测试。

任务：

1. 实现 PTE/no-check/refill bit layout tests：RSW no fault/flg、高保留位 no fault、G leaf-only、refill flg bit layout。
2. 实现 type/id/target/PFU tests：fetch/load/store/PFU success target、exception target、PFU only L2、PFU permission matrix。
3. 实现 PDE cache tests：hit level、double-hit L2 wins、update condition、lookup/update race、reset/satp/PMP/abort clear matrix。
4. 实现 xbar/ready tests：hash dispatch、target mask backpressure、non-target mask no block、abort dispatch block。
5. 实现 PMP/MPRV tests：fst/scd/thd deny、original type permission、MPRV/MPP data direct-map no-PTW 约束、fetch real-privilege、deny no side effect。
6. 实现 PTE page fault matrix：non-leaf by level、fetch/load/store/PFU leaf permission、write-only/MXR、U/S/SUM/effective mode、huge align before degrade。
7. 实现 MBUF/LSU/abort tests：entry allocation、CHK not-ready hold、bus error priority、abort outstanding/data/bus-error/pre-existing exception。
8. 实现 MAEE/sysmap/degrade tests：MAEE=1 all-size、MAEE=0 4K sysmap、1G no-cross/1G->2M/1G->4K、2M no-cross/2M->4K、sysmap flag order。
9. 实现 `PTW-FLOW-001..023` umbrella scenario suite 或 wrapper，把第 12 章完整流程逐条绑定到 directed tests。
10. 修改旧 tests：删除 round-robin expected、reserved/RSW fault expected、PTW memory OOO expected、PFU 按 load expected、system direct-map 误归属。

任务产出：

| 产出 | 内容 |
| --- | --- |
| P0 directed test classes | 覆盖 `PTW-ADD-001..034` 和 `PTW-FLOW-001..023` 的主干。 |
| modified legacy tests | 与 spec 冲突的旧 expected 已修正或 obsolete。 |
| P0 regression list | 可一键运行 P0 directed suite。 |
| P0 closure report | 每个 P0 scenario 有 directed pass、source scoreboard match、SVA cover。 |

相关文件/目录：

| 文件/目录 | 说明 |
| --- | --- |
| `mmu_verification/testbench/test/ptw_tests` | PTE、PDE、xbar、type/id、full-flow 主目录。 |
| `mmu_verification/testbench/test/ptw_lsu_protocol_tests` | MBUF/LSU/bus error/abort 主目录。 |
| `mmu_verification/testbench/test/pmp_twu_tests_v6` | PMP/MPRV 主目录。 |
| `mmu_verification/testbench/test/maee_twu_tests` | MAEE direct/sysmap 主目录。 |
| `mmu_verification/testbench/test/sysmap_tests` | PTW degrade 相关场景；system direct-map 需重归属。 |
| `mmu_verification/testbench/test/l1dtlb_tests` | 只作为 consumer evidence。 |
| `mmu_verification/simu/ptw_p0_list` 或等价回归配置 | 建议新增。 |

退出标准：

1. `PTW-ADD-001..034` 中 P0 项全部有测试实现或明确 open/blocked reason。
2. `PTW-FLOW-001..023` 每条至少绑定一个 directed scenario、一个 source scoreboard match、一个 SVA/cover evidence。
3. P0 regression 中 `PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0`，非法/stress list 除外。
4. 所有 P0 SVA assert 0 fail，且对应 cover hit > 0。
5. 旧冲突 tests 不再计入 PTW source-side closure。

## 13. 阶段 7：Reference/Scoreboard 完整化、P1/P2 与随机压力

目标：在 P0 主干稳定后补齐高精度、交叉、压力和约束质量，提升 source checker 对随机回归和 corner case 的解释能力。

任务：

1. 完整化 `ptw_source_ref_model`：PDE replacement/victim、satp/PMP clear-only re-update、MAEE mid-sysmap change、abort/drop 全矩阵、pre-existing exception grant、context same-cycle ordering。
2. 完整化 `ptw_source_sb`：pending aging debug、illegal stimulus 分类、consumer-only 关联、partial/provisional evidence 标注、field coverage、per-requirement summary。
3. 实现 P1 tests：satp old-walk re-update、PMP config clear no flush、ASID refill current sample、MAEE mid-sysmap change、random PTE permission cross。
4. 实现 P2 tests/constraints：same `{type,id}` no reuse、Bare/M no request、sysmap malformed constraint、PTW memory OOO illegal checker。
5. 扩展 random/regression：在不违反 illegal constraints 的前提下随机组合 type、level、permission、PMP、MAEE、delay、abort window。
6. 完善 legacy/traceability 回归映射，把 L1DTLB/L2TLB/CSR/Perf 间接项全部标 `consumer-only` 或 `auxiliary`。

任务产出：

| 产出 | 内容 |
| --- | --- |
| complete source ref/sb | 覆盖 P0/P1/P2 和随机压力。 |
| P1/P2 directed tests | 补齐精度、约束、压力场景。 |
| random regression profile | 可控 seed、合法约束、非法分类。 |
| field/function coverage | flg/global/page_size/ppn/fault_kind/target/drop/context bins。 |
| updated closure matrix | P1/P2、consumer-only、waiver/open 状态完整。 |

相关文件/目录：

| 文件/目录 | 说明 |
| --- | --- |
| `ptw_source_ref_model.svh` | 完整 golden model。 |
| `ptw_source_sb.svh` | 完整 matching/report/coverage。 |
| `ptw_pde_cache_model.svh` | replacement/victim 与 clear/re-update 补齐。 |
| `mmu_verification/testbench/test/ptw_tests` | P1/P2 tests。 |
| `mmu_verification/simu/ptw_p1_list`、`ptw_random_list` | 建议新增。 |
| `ptw_source_closure_matrix.md/csv` | 更新状态。 |

退出标准：

1. P1 列表中已纳入签核范围的 tests 全部 pass 或有明确 waiver/open reason。
2. P2/illegal tests 不把非法刺激记为 DUT fail，且能证明约束/illegal checker 生效。
3. 随机回归无 source scoreboard mismatch、pending、unexpected illegal。
4. source scoreboard 能按 requirement 输出 coverage/match，而不是只输出全局 pass/fail。
5. 所有 consumer-only evidence 均不自动提升为 source-side closure。

## 14. 阶段 8：Regression、Report、Signoff 与交付冻结

目标：形成可重复运行、可审查、可签核的 PTW source-side 回归包，并冻结最终交付物。

任务：

1. 建立或更新 regression lists：P0 smoke、P0 full、P1 directed、P2/illegal、random/stress、consumer-only evidence。
2. 实现 report parser/gate，解析 `PTW_SOURCE_SB_SUMMARY`、`PTW_SVA_COVER`、assert fail、scenario metadata、closure matrix。
3. 输出 final signoff report，按 `PTW-AUD-*`、`PTW-ADD-*`、`PTW-FLOW-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*`、`PTW-INFRA-*` 列出 pass/fail/open/waive。
4. 对每个 waiver 写明作用域、原因、替代 evidence、预计关闭条件，禁止全局 waiver 覆盖 `flg/page_size/ppn/fault_kind/target` mismatch。
5. 对每个 open/blocker 写明责任文件、缺失 probe 或环境限制、下一步修复动作。
6. 冻结旧 test 处理结果，确保 obsolete tests 不再被 CI 或人工报告当作 PTW closure。

任务产出：

| 产出 | 内容 |
| --- | --- |
| final regression lists | P0/P1/P2/random/consumer-only 可分别运行。 |
| parser/gate scripts | 自动判断 mismatch、pending、illegal、cover hit、assert fail。 |
| PTW source signoff report | 面向评审的最终签核报告。 |
| waiver/open register | 每个未关闭项都有明确原因和关闭路径。 |
| frozen closure matrix | 与最终 regression report 一致。 |

相关文件/目录：

| 文件/目录 | 说明 |
| --- | --- |
| `mmu_verification/simu/ptw_p0_list` | P0 回归入口。 |
| `mmu_verification/simu/ptw_p1_list` | P1 回归入口。 |
| `mmu_verification/simu/ptw_random_list` | 随机/压力入口。 |
| `mmu_verification/simu/ptw_consumer_evidence_list` | L1/L2 consumer evidence 入口。 |
| regression parser/gate script | 仓库现有脚本位置优先，若无则新增。 |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | 建议新增最终报告。 |
| `doc/ptw_uvm_review/ptw_source_closure_matrix.md` | 最终 closure 状态。 |

退出标准：

1. P0 regression 全 pass，P0 source scoreboard `mismatch=0 pending=0 illegal=0`。
2. 所有 P0 assert 0 fail，P0 required cover hit > 0。
3. `PTW-FLOW-001..023` 全部关闭或有逐项 waiver/open reason。
4. P1/P2/random 的状态在 report 中完整列出，不能留空。
5. final report 能从日志自动生成或至少能由脚本校验关键字段。
6. 任何未关闭项都有明确责任文件和下一步动作。

## 15. 阶段依赖与可并行项

| 阶段 | 依赖 | 可并行工作 | 不可提前签核项 |
| --- | --- | --- | --- |
| 阶段 0 | 无 | 可与代码熟悉并行 | 不能跳过 legacy/traceability 冻结直接写 P0 tests。 |
| 阶段 1 | 阶段 0 的 ID/术语冻结 | 可同时准备 SVA 空文件和 cfg knobs | 未统一 type/page-size 前不能大规模写 tests。 |
| 阶段 2 | 阶段 1 编译骨架 | 可与阶段 3 probe 设计并行 | 无公共 base 时写出的 directed tests 不计最终交付。 |
| 阶段 3 | 阶段 1，部分依赖阶段 2 smoke | 可与阶段 5 SVA 信号梳理并行 | monitor-only 不能关闭 P0/P1。 |
| 阶段 4 | 阶段 2/3 的 transaction 输入 | 可与阶段 5 SVA 并行 | source scoreboard 未接入前，P0 tests 只能 provisional。 |
| 阶段 5 | 阶段 1/3 的 probe 与 bind 路径 | 可与阶段 6 test 编写并行 | assert pass 但 cover 未命中不能关闭测试点。 |
| 阶段 6 | 阶段 2/4/5 | 各 test family 可分人并行 | 没有 source match + SVA cover 的 P0 不能签核。 |
| 阶段 7 | 阶段 6 主干稳定 | P1/P2/random 可按 family 并行 | illegal/stress 不能污染 P0 gate。 |
| 阶段 8 | 阶段 6/7 report 数据 | waiver/open 清理可并行 | final signoff 不能引用 obsolete tests。 |

## 16. `ptwspec.md` 全文覆盖审核矩阵

| `ptwspec.md` 范围 | 关键内容 | 覆盖阶段 | 审核结论 |
| --- | --- | --- | --- |
| §0 最终采用规则 | 旧答案冲突收敛、最终规则优先级。 | 阶段 0、8 | 阶段 0 冻结；阶段 8 signoff 防止旧 expected 回流。 |
| §1 地址、模式、PTE 格式 | Sv39、VPN/PPN、raw PTE、RSW/G/flg、高保留位。 | 阶段 1、2、4、5、6 | 公共类型、builder、ref/sb、CHK/ARB SVA、PTE tests 均覆盖。 |
| §2 请求与返回接口 | type/id、返回目标、page size、异常返回、PFU。 | 阶段 1、3、4、5、6 | monitor/ref/sb/SVA/test 均按 `{type,id}` 和 target 关闭。 |
| §3 PDE Cache | 两级 16 entry、lookup、update、clear、double-hit、old-state。 | 阶段 3、4、5、6、7 | PDE monitor/ref model/SVA/P0/P1 tests 均覆盖。 |
| §4 Xbar/Ready | VPN hash、ready/backpressure、target mask。 | 阶段 3、5、6 | xbar SVA 和 P0 xbar tests 覆盖；旧 round-robin 作废。 |
| §5 TWU 流水 | PMP/CHK/wait、PTE PA、流水反压。 | 阶段 3、4、5、6 | PMP/CHK SVA、monitor level event、source model 覆盖。 |
| §6 PTE 检查 | leaf/non-leaf、PFU、write-only、U/S/SUM/A/D、huge align、不检查项。 | 阶段 2、4、5、6 | builder、source algorithm、CHK SVA、PTE matrix tests 覆盖。 |
| §7 MPRV/Privilege/上下文采样 | fetch real priv、data/PFU MPRV/MPP、ASID/MAEE 使用点。 | 阶段 2、3、4、6、7 | context monitor/ref model/P1 sampling tests 覆盖。 |
| §8 MBUF/LSU | entry 分配、single outstanding、CHK hold、bus error。 | 阶段 2、3、4、5、6 | memory responder、monitor、source sb、MBUF SVA/tests 覆盖。 |
| §9 Refill/异常/仲裁 | access > page > refill、grant onehot、tag/data/flg、target。 | 阶段 3、4、5、6 | ARB SVA、source sb field compare、target tests 覆盖。 |
| §10 MAEE/Sysmap/Degrade | MAEE=1/0、4K sysmap、1G/2M degrade、no lower walk。 | 阶段 2、4、5、6、7 | sysmap helper、MAEE model/SVA/tests 覆盖。 |
| §11 Reset/satp/PMP/Abort | reset/abort flush、satp/PMP clear-only、abort LSU outstanding。 | 阶段 3、4、5、6、7 | source drop model、CTX/MBUF/PDE SVA、abort tests 覆盖。 |
| §12 完整处理流程 | `PTW-FLOW-001..023`。 | 阶段 6、8 | 阶段 6 实现并绑定 evidence；阶段 8 最终签核。 |
| §13.1 Reference/Scoreboard | ref/sb 输入输出、matching、golden algorithm、不检查项、report。 | 阶段 1、3、4、7、8 | source checker 架构、完整化和 report gate 覆盖。 |
| §13.2-13.3 Assertion/约束 | SVA/monitor 和 UVM constraints。 | 阶段 0、2、5、7 | illegal constraints 和 SVA cover gate 覆盖。 |
| §13.4-13.20 测试点/Traceability | audit matrix、新增/旧测试、regression、CSV closure。 | 阶段 0、6、7、8 | closure matrix、P0/P1/P2 tests、report 覆盖。 |
| §13.21 SVA 规格 | source-side SVA、L1DTLB consumer-side SVA、SVA signoff。 | 阶段 5、6、8 | SVA implementation/cover gate/final report 覆盖。 |
| §14 旧答案冲突 | abort、RSW、reserved、satp/PMP、MPRV、sysmap order。 | 阶段 0、4、5、6、8 | 阶段 0 冻结；阶段 4-6 实现；阶段 8 防回归。 |
| §15 Q1-Q180 索引 | 所有澄清问题映射。 | 阶段 0、6、7、8 | 阶段 0 建 mapping；阶段 6/7 实现；阶段 8 检查缺口。 |
| §16 原文归档 | 追溯来源，冲突时以前文正式规格为准。 | 阶段 0、8 | 只作 traceability，不直接作为 expected。 |

## 17. 原修改计划覆盖审核矩阵

| `ptw_phase1_test_sva_implementation_plan.md` 范围 | 内容 | 主负责阶段 | 审核结论 |
| --- | --- | --- | --- |
| §1-§2 | 总体范围、仓库锚点、全局常量和非法输入。 | 阶段 0、1、2 | 阶段计划已承接全局约束、目录归属和常量统一。 |
| §4 | Testbench 基础设施。 | 阶段 2、3 | base/builder/memory responder/monitor/logger 均有独立阶段。 |
| §5 | P0 test 场景实现。 | 阶段 6 | PTE/type/PDE/xbar/PMP/MBUF/MAEE/FLOW 已逐族列入阶段 6。 |
| §6 | P1/P2 test 场景。 | 阶段 7 | 精度、约束和随机压力统一放入阶段 7。 |
| §7 | SVA 实现计划。 | 阶段 5 | source-side SVA 与 cover gate 独立实施。 |
| §8 | 旧 test 修改、traceability、audit/infra matrix。 | 阶段 0、6、8 | 先冻结归属，P0 时修正旧 tests，最终 signoff 防回流。 |
| §9 | 覆盖与签核。 | 阶段 5、6、7、8 | cover gate、P0 closure、random coverage、final report 分层实现。 |
| §10 | 风险与阻塞项。 | 所有阶段 | 每阶段完成记录必须更新 open/blocker。 |
| §11-§12 | 统一交付物和完成判据。 | 阶段 8 | 最终交付冻结阶段承接。 |
| §13-§15 | Reference/scoreboard 范围、差距、文件表。 | 阶段 1、3、4、7 | 类型/env 骨架、monitor、MVP、完整化分阶段承接。 |
| §16-§22 | 数据结构、golden algorithm、PDE/MAEE/abort、scoreboard。 | 阶段 4、7 | MVP 先关闭 P0 主干，阶段 7 补齐复杂 corner。 |
| §23-§24 | Monitor/probe/env connect。 | 阶段 3、1 | env skeleton 在阶段 1，实际观测闭环在阶段 3。 |
| §25 | Ref model API 和实现顺序。 | 阶段 4、7 | R1-R5 对应阶段 4；R6-R8 对应阶段 7/8。 |
| §26-§29 | Test/SVA/SB 闭环、report、风险、完成判据。 | 阶段 6、7、8 | P0/P1/random/final signoff 分阶段关闭。 |

## 18. Requirement 到阶段映射

### 18.1 `PTW-AUD-*`

| Audit ID | 主题 | 主关闭阶段 | 必须 evidence |
| --- | --- | --- | --- |
| `PTW-AUD-001` | RSW/high reserved/strong-order 不参与 page fault | 阶段 6 | source sb flg/no-fault + CHK/ARB SVA cover。 |
| `PTW-AUD-002` | G 只生成 tag/global | 阶段 6 | refill tag/data compare + CHK/ARB SVA。 |
| `PTW-AUD-003` | 请求 type 成功返回目标 | 阶段 6 | target compare + L1 consumer evidence。 |
| `PTW-AUD-004` | 异常返回 type/id/PFU/IUTLB 规则 | 阶段 6 | fault class/key compare。 |
| `PTW-AUD-005` | PDE hit/miss/double-hit | 阶段 6 | PDE event + SVA cover。 |
| `PTW-AUD-006` | PDE update 条件与时序 | 阶段 6/7 | update event + old-state race evidence。 |
| `PTW-AUD-007` | reset/satp/PMP/abort 清理差异 | 阶段 6/7 | clear/drop/re-update evidence。 |
| `PTW-AUD-008` | xbar hash 与 ready/backpressure | 阶段 6 | xbar/REQ SVA + directed tests。 |
| `PTW-AUD-009` | PMP 检查对象与 deny 终止 | 阶段 6 | PTE PA PMP deny + no side effect。 |
| `PTW-AUD-010` | PMP 使用原始 request type | 阶段 6 | fetch/load/store/PFU permission evidence。 |
| `PTW-AUD-011` | MPRV/MPP effective privilege | 阶段 6/7 | fetch real priv + data/PFU MPRV/MPP。 |
| `PTW-AUD-012` | 非叶 PTE page fault | 阶段 6 | fst/scd pointer、thd nonleaf fault。 |
| `PTW-AUD-013` | Leaf PTE 权限矩阵 | 阶段 6 | fetch/load/store/PFU formulas。 |
| `PTW-AUD-014` | 巨页 PPN 对齐优先于降级 | 阶段 6 | page fault no sysmap/degrade。 |
| `PTW-AUD-015` | MBUF entry 分配与 LSU single outstanding | 阶段 6 | MBUF SVA + directed test。 |
| `PTW-AUD-016` | CHK not ready 与 bus error | 阶段 6 | hold/get + bus error access fault。 |
| `PTW-AUD-017` | Abort LSU outstanding 边界 | 阶段 6/7 | abort matrix + SVA cover。 |
| `PTW-AUD-018` | MAEE=1 direct attr | 阶段 6 | raw PTE ext attr all sizes。 |
| `PTW-AUD-019` | MAEE=0 4K sysmap refill | 阶段 6 | THD 4K sysmap evidence。 |
| `PTW-AUD-020` | MAEE=0 1G/2M degrade | 阶段 6 | final page_size/PPN/flg + no lower walk。 |
| `PTW-AUD-021` | 上下文采样点 | 阶段 7 | context sample transaction + expected match。 |
| `PTW-AUD-022` | 第 12 章完整流程 | 阶段 6/8 | `PTW-FLOW-001..023` closure。 |
| `PTW-AUD-023` | L1DTLB 间接消费 PTW 输出 | 阶段 6/8 | consumer-only evidence，不替代 source closure。 |

### 18.2 `PTW-INFRA-*`

| Infra ID | 工作项 | 主实施阶段 | 审核结论 |
| --- | --- | --- | --- |
| `PTW-INFRA-001` | `ptw_source_ref_model` | 阶段 4、7 | MVP 和完整化分阶段实现。 |
| `PTW-INFRA-002` | page table builder / PTW memory sequences | 阶段 2 | 独立成刺激基础设施阶段。 |
| `PTW-INFRA-003` | source monitor / source scoreboard | 阶段 3、4、7 | monitor、MVP sb、完整 sb 分层。 |
| `PTW-INFRA-004` | PDE cache monitor/SVA | 阶段 3、5、6 | monitor/SVA/test 三方闭环。 |
| `PTW-INFRA-005` | PTW LSU/MBUF protocol SVA | 阶段 5、6 | SVA 与 directed tests 绑定。 |
| `PTW-INFRA-006` | PMP/TWU/CHK SVA 与 probes | 阶段 3、5、6 | probe/SVA/test 绑定。 |
| `PTW-INFRA-007` | MAEE/sysmap/degrade SVA 与 coverage | 阶段 5、6 | SVA/test/ref model 均覆盖。 |
| `PTW-INFRA-008` | xbar/arb monitor/SVA | 阶段 3、5、6 | monitor/SVA/test 绑定。 |
| `PTW-INFRA-009` | coverage gate/regression report | 阶段 8 | final signoff 阶段实现。 |

### 18.3 `PTW-ADD-*`

| ID | 内容 | 主关闭阶段 | 必须 evidence |
| --- | --- | --- | --- |
| `PTW-ADD-001` | RSW 不 fault 且进入 flg。 | 阶段 6 | source sb flg compare + CHK/ARB SVA cover。 |
| `PTW-ADD-002` | `PTE[58:38]` 不 fault。 | 阶段 6 | source sb no-fault + old reserved-fault test obsolete。 |
| `PTW-ADD-003` | G 只进 tag/global，非叶 G 不 OR。 | 阶段 6 | refill tag/data compare。 |
| `PTW-ADD-004` | fetch/load/store/PFU 成功返回目标。 | 阶段 6 | target compare + L1/L2 consumer evidence。 |
| `PTW-ADD-005` | 四类 type 的 page/access fault 返回。 | 阶段 6 | fault class/key/target compare。 |
| `PTW-ADD-006` | access/page/refill priority、按 `{type,id}` 匹配。 | 阶段 6 | source sb + ARB priority SVA。 |
| `PTW-ADD-007` | PDE double-hit 选 L2。 | 阶段 6 | PDE monitor event + PDE SVA cover。 |
| `PTW-ADD-008` | PDE lookup/update 同拍读旧写新。 | 阶段 7 | old-state race SVA + source model match。 |
| `PTW-ADD-009` | PDE update 条件。 | 阶段 6 | nonleaf no-fault only update evidence。 |
| `PTW-ADD-010` | satp/PMP clear-only no flush。 | 阶段 6/7 | clear-only + old walk re-update evidence。 |
| `PTW-ADD-011` | reset/abort/PDE clear/flush 差异。 | 阶段 6 | CTX/PDE SVA + drop report。 |
| `PTW-ADD-012` | xbar hash、ready hold、mask。 | 阶段 6 | XBAR/REQ SVA + directed tests。 |
| `PTW-ADD-013` | fst/scd/thd PMP deny no side effect。 | 阶段 6 | PTE PA PMP deny + no LSU/CHK/refill/PDE。 |
| `PTW-ADD-014` | PMP original type permission。 | 阶段 6 | fetch X、load/PFU R、store W evidence。 |
| `PTW-ADD-015` | data/PFU `MPRV=1 && MPP=M` direct-map/no PTW source；fetch 不受 MPRV。 | 阶段 6 | consumer direct-map sanity + source monitor illegal-accept guard；fetch source case按真实 privilege。 |
| `PTW-ADD-016` | nonleaf by level、V=0、write-only。 | 阶段 6 | CHK SVA + page fault source compare。 |
| `PTW-ADD-017` | `W && !(R || (MXR && X))`。 | 阶段 6 | write-only/MXR directed matrix。 |
| `PTW-ADD-018` | fetch/load/store/PFU leaf 权限。 | 阶段 6 | CHK SVA + source sb expected formulas。 |
| `PTW-ADD-019` | A/D/U/S/SUM/effective mode。 | 阶段 6 | permission matrix + effective mode probes。 |
| `PTW-ADD-020` | 1G/2M 对齐先于 sysmap/degrade。 | 阶段 6 | page fault no sysmap/degrade cover。 |
| `PTW-ADD-021` | MBUF entry8/entry0-7 分配。 | 阶段 6 | MBUF SVA + directed allocation test。 |
| `PTW-ADD-022` | CHK not-ready hold。 | 阶段 6 | hold/get SVA + no duplicate LSU evidence。 |
| `PTW-ADD-023` | bus error access fault/no CHK/PDE。 | 阶段 6 | MBUF/ARB SVA + source sb access fault。 |
| `PTW-ADD-024` | abort outstanding/data/bus_error/old exception。 | 阶段 6/7 | abort matrix + drop report。 |
| `PTW-ADD-025` | MAEE=1 1G/2M/4K raw attr。 | 阶段 6 | all-size raw ext attr compare。 |
| `PTW-ADD-026` | MAEE=0 4K sysmap。 | 阶段 6 | THD 4K sysmap evidence。 |
| `PTW-ADD-027` | 1G no-cross、1G->2M、1G->4K。 | 阶段 6 | final page_size/PPN/flg + no lower walk。 |
| `PTW-ADD-028` | 2M no-cross、2M->4K。 | 阶段 6 | final page_size/PPN/flg + no thd walk。 |
| `PTW-ADD-029` | sysmap flag order/default。 | 阶段 6/7 | `{So,C,B,Sh,Sec}` compare + malformed constraint。 |
| `PTW-ADD-030` | ASID/MXR/SUM/MAEE 使用点采样。 | 阶段 7 | context sample transaction + expected match。 |
| `PTW-ADD-031` | 第 12 章 23 条 flow。 | 阶段 6/8 | `PTW-FLOW-001..023` table closure。 |
| `PTW-ADD-032` | L1DTLB consumer-only evidence。 | 阶段 6/8 | L1D consumer SVA/report，不能替代 source closure。 |
| `PTW-ADD-033` | PFU 特殊权限矩阵。 | 阶段 6 | PFU no R/MXR/X/D compare + remaining checks。 |
| `PTW-ADD-034` | refill tag/data/flg bit layout。 | 阶段 6 | bit-exact `flg/global/page_size/ppn` compare。 |
| `PTW-ADD-035` | 同 `{type,id}` 不复用约束。 | 阶段 7 | constraint/illegal checker evidence。 |
| `PTW-ADD-036` | Bare/M no-request 约束。 | 阶段 7 | constraint/illegal checker evidence。 |

### 18.4 `PTW-FLOW-*`

| Flow ID | 内容 | 主关闭阶段 | 必须 evidence |
| --- | --- | --- | --- |
| `PTW-FLOW-001` | PDE miss，1G success。 | 阶段 6 | fst PMP/CHK leaf + 1G refill source match。 |
| `PTW-FLOW-002` | PDE miss，2M success。 | 阶段 6 | fst nonleaf update + scd 2M refill source match。 |
| `PTW-FLOW-003` | PDE miss，4K success。 | 阶段 6 | fst/scd nonleaf update + thd 4K refill source match。 |
| `PTW-FLOW-004` | MAEE=0 1G->2M。 | 阶段 6 | degrade final 2M PPN/flg + no lower walk。 |
| `PTW-FLOW-005` | MAEE=0 1G->4K。 | 阶段 6 | degrade final 4K PPN/flg + no lower walk。 |
| `PTW-FLOW-006` | MAEE=0 2M->4K。 | 阶段 6 | degrade final 4K PPN/flg + no thd walk。 |
| `PTW-FLOW-007` | MAEE=0 1G/2M no degrade。 | 阶段 6 | original page size retained + sysmap attr compare。 |
| `PTW-FLOW-008` | MAEE=0 4K sysmap refill。 | 阶段 6 | THD 4K sysmap attr compare。 |
| `PTW-FLOW-009` | 第一级 PMP access fault。 | 阶段 6 | fst PTE PA PMP deny + no side effect。 |
| `PTW-FLOW-010` | 第二级 PMP access fault。 | 阶段 6 | scd PTE PA PMP deny + no side effect。 |
| `PTW-FLOW-011` | 第三级 PMP access fault。 | 阶段 6 | thd PTE PA PMP deny + no side effect。 |
| `PTW-FLOW-012` | 第一级 CHK page fault。 | 阶段 6 | fst PTE fault + no lower walk/refill。 |
| `PTW-FLOW-013` | 第二级 CHK page fault。 | 阶段 6 | scd PTE fault + no thd/refill。 |
| `PTW-FLOW-014` | 第三级 CHK page fault。 | 阶段 6 | thd PTE fault + no refill。 |
| `PTW-FLOW-015` | 第一级 PDE cache hit，最终 2M。 | 阶段 6 | skip fst + scd 2M refill。 |
| `PTW-FLOW-016` | 第一级 PDE cache hit，最终 4K。 | 阶段 6 | skip fst + scd nonleaf + thd 4K refill。 |
| `PTW-FLOW-017` | 第二级 PDE cache hit，最终 4K。 | 阶段 6 | skip fst/scd + thd 4K refill。 |
| `PTW-FLOW-018` | LSU bus error access fault。 | 阶段 6 | bus error access fault + no CHK/PDE/refill。 |
| `PTW-FLOW-019` | Abort 且 LSU outstanding。 | 阶段 6/7 | hold request until response + late data drop。 |
| `PTW-FLOW-020` | PFU 成功。 | 阶段 6 | L2-only refill + no L1 install。 |
| `PTW-FLOW-021` | PFU 异常。 | 阶段 6 | PFU fault to L2/PFU path + no L1 refill。 |
| `PTW-FLOW-022` | satp/PMP 改变清 PDE cache。 | 阶段 6/7 | clear-only + no in-flight flush + possible re-update。 |
| `PTW-FLOW-023` | Load/Store/PFU，`MPRV=1 && MPP=M`。 | 阶段 6 | data/PFU direct-map/no PTW source；fetch remains real-privilege。 |

## 19. 文件归属总表

| 文件/目录 | 阶段 | 处理方式 |
| --- | --- | --- |
| `doc/ptw_uvm_review/ptwspec.md` | 阶段 0 | 只读真值输入。 |
| `doc/ptw_uvm_review/ptw_phase1_test_sva_implementation_plan.md` | 阶段 0-8 | 详细任务库，本文不复制其全部内容。 |
| `doc/ptw_uvm_review/ptw_source_closure_matrix.md` | 阶段 0、7、8 | 建议新增/持续更新。 |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | 阶段 8 | 建议新增最终报告。 |
| `mmu_verification/testbench/env/ptw_source_types_pkg.sv` 或 `.svh` | 阶段 1 | 新增。 |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | 阶段 4、7 | 新增。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | 阶段 4、7 | 新增。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | 阶段 3 | 新增。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | 阶段 4、7 | 新增。 |
| `mmu_verification/testbench/env/ptw_scenario_db.svh` | 阶段 3 | 建议新增。 |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | 阶段 1、4 | include/import 新组件。 |
| `mmu_verification/testbench/env/mmu_env.svh` | 阶段 1、3、4 | build/connect 新组件。 |
| `mmu_verification/testbench/top/mmu_top_cfg.svh` | 阶段 1 | 新增 knobs。 |
| `mmu_verification/testbench/top/mmu_dut_probes_if.sv` | 阶段 3 | 新增 PTW probes。 |
| `mmu_verification/testbench/top/tb_top.sv` 或 bind 文件 | 阶段 3、5 | probe/SVA bind。 |
| `mmu_verification/testbench/top/mmu_ptw_top_sva.sv` | 阶段 5 | 新增。 |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | 阶段 5 | 新增。 |
| `mmu_verification/testbench/top/mmu_ptw_xbar_sva.sv` | 阶段 5 | 新增。 |
| `mmu_verification/testbench/top/mmu_twu_chk_sva.sv` | 阶段 5 | 新增。 |
| `mmu_verification/testbench/top/mmu_pmp_twu_sva.sv` | 阶段 5 | 增强。 |
| `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` | 阶段 5 | 增强。 |
| `mmu_verification/testbench/top/mmu_maee_twu_sva.sv` | 阶段 5 | 增强。 |
| `mmu_verification/testbench/top/mmu_sysmap_sva.sv` | 阶段 5 | 增强。 |
| `mmu_verification/testbench/top/mmu_arb_sva.sv` | 阶段 5 | 增强。 |
| `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` | 阶段 5、6 | consumer-side evidence。 |
| `mmu_verification/testbench/test/ptw_tests` | 阶段 2、6、7 | base、PTE/PDE/xbar/type/full-flow tests。 |
| `mmu_verification/testbench/test/ptw_lsu_protocol_tests` | 阶段 6 | MBUF/LSU/bus error/abort tests。 |
| `mmu_verification/testbench/test/pmp_twu_tests_v6` | 阶段 6 | PMP/MPRV tests。 |
| `mmu_verification/testbench/test/maee_twu_tests` | 阶段 6 | MAEE tests。 |
| `mmu_verification/testbench/test/sysmap_tests` | 阶段 6 | PTW degrade tests；system direct-map 重归属。 |
| `mmu_verification/testbench/test/l1dtlb_tests` | 阶段 6、8 | consumer-only evidence。 |
| `mmu_verification/testbench/Files.f` | 阶段 1、5 | source checker/SVA 接入。 |
| `mmu_verification/simu/ptw_p0_list` | 阶段 6、8 | 建议新增。 |
| `mmu_verification/simu/ptw_p1_list` | 阶段 7、8 | 建议新增。 |
| `mmu_verification/simu/ptw_random_list` | 阶段 7、8 | 建议新增。 |
| `mmu_verification/simu/ptw_consumer_evidence_list` | 阶段 8 | 建议新增。 |

## 20. 审核结论

本次拆分计划重新审核后，阶段边界满足以下条件：

1. `ptwspec.md` §0-§16 均有阶段承接，没有只靠 L1/L2 consumer evidence 关闭 PTW source-side 的规则。
2. 原修改计划的 test、SVA、reference model、scoreboard、monitor/probe、report/signoff 工作项均被分配到阶段 0-8。
3. P0 主干不会在 source scoreboard 和 P0 SVA cover gate 前提前签核；阶段 4 和阶段 5 是阶段 6 的硬依赖。
4. P1/P2/random 不会污染 P0 gate；illegal/stress 在阶段 7 独立处理。
5. 旧 test 冲突处理前置到阶段 0，并在阶段 6/8 再次检查，防止旧 expected 回流。
6. `PTW-INFRA-*` 已明确落到具体阶段，避免 test 写完但缺 scoreboard/probe/report 无法签核。
7. 对当前已知风险，如 `pmp_regs_update` 可驱动性、refill data/tag probe、abort visible exception probe，阶段 3/5/8 均要求登记 open 或补齐，不允许静默 waiver。

本文档可作为后续逐阶段实施的入口；实施细节仍回到 `ptw_phase1_test_sva_implementation_plan.md` 对应章节展开。
