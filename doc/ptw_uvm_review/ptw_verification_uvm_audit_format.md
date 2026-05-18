# PTW Verification Plan and UVM Audit Format

本文档用于指导后续基于 `ptwspec.md` 审核当前 verification plan 和 UVM 中 PTW 相关测试点。审核目标是确认现有 plan/test/sequence/coverage 是否完整、是否与 PTW spec 一致、是否存在误测或弱检查，并沉淀后续需要新增、修改、删除、拆分或合并的测试点。

本文只定义审核格式和特别注意事项，不执行具体审核，不设计 scoreboard/reference model 的实现细节。

## 1. Scope

当前阶段从 `ptwspec.md` 的正式规则出发，反向审核 verification plan 和 UVM 中已有 PTW 相关测试点是否覆盖正确、是否漏测、是否误测、是否重复测，以及是否暴露出 TB 可观测性或建模缺口。

审核表格的主键必须是 PTW function item / requirement item，而不是已有 coverage item、test name 或 sequence name。已有 plan/UVM 条目只能作为映射对象；不能因为已有测试点存在就默认 spec 已覆盖。

本阶段只决定测试点应保留、修改、新增、删除、拆分、合并或待澄清。若某个测试点后续需要 scoreboard、reference model、monitor、assertion 或 probe 支持，只在 Action Notes 中标记依赖，不在本阶段展开实现方案。

PTW 审核覆盖对象包括：

1. verification plan 中所有 PTW、L2TLB->PTW、PTW->L1TLB/L2TLB refill、PDE cache、PMP/page fault、MAEE/sysmap、abort/reset/satp/PMP change、PFU、fetch/load/store walk 相关条目。
2. UVM 中直接或间接刺激 PTW 的 test、vseq、sequence、directed scenario、random scenario、coverage、SVA、monitor 和 scoreboard 检查。
3. 通过 L1DTLB 或 L2TLB 场景间接覆盖 PTW 的测试点。此类条目可以映射到 PTW audit row，但 audit row 的主语仍必须是 PTW requirement。

## 2. 推荐表格字段

| Audit ID | PTW Function / Requirement Item | Spec Source | Required Scenario / Condition | Expected Behavior | Related Verification Plan Item | Related UVM Test / Sequence | Observable Check | Current Status | Gap Type | Action | Action Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PTW-AUD-001 | 待审核的 PTW 功能项或 requirement 名称 | `ptwspec.md` 章节号或关键规则 | 触发该 requirement 所需的输入、PTE、CSR/PMP/sysmap 状态或时序条件 | 按 spec 应验证的功能行为，不写 RTL 私有实现细节 | plan 中对应条目；没有则写 N/A | 当前 UVM 中对应 test/sequence；没有则写 N/A | 当前阶段可从接口、log、coverage、SVA、monitor 或 probe 判断的检查方向 | keep / modify / add / delete / split / merge / unclear | no_gap / missing_test / wrong_expected / duplicate / weak_check / tb_model_gap / spec_gap | 保留 / 修改 / 新增 / 删除 / 拆分 / 合并 / 待澄清 | 简要说明原因、缺口、建议动作和后续依赖 |

## 3. 字段填写规则

Audit ID：使用稳定编号，例如 `PTW-AUD-001`、`PTW-AUD-002`。一个审核行只覆盖一个明确 requirement，避免一行同时包含多个独立功能要求。

PTW Function / Requirement Item：写从 `ptwspec.md` 抽取出来的功能项，例如 “PDE cache 两级同时命中选择第二级”、“MAEE=0 1G 降级为 4K”、“abort 同拍 LSU bus error 不上报”。不要写成已有 coverage item 名称。

Spec Source：引用 `ptwspec.md` 章节号、表格或关键规则，例如 “3.2 Lookup”、“6.3 Leaf PTE page fault”、“11.5 Abort 与 LSU outstanding”、“13.4 必须覆盖的功能场景”。若依据来自最终采用规则，必须标出第 0 章对应规则。

Required Scenario / Condition：写触发该 requirement 的最小条件，包括请求 type、vpn/id、PDE cache 状态、PTE raw bit、PMP 权限、MAEE/sysmap、satp/MPRV/MPP/MXR/SUM、abort/reset、LSU 返回类型等。

Expected Behavior：只写按 spec 应发生什么，例如 “PMP deny 后不写 mbuf、不发 LSU、不进入 CHK，并最终返回 access fault”。不要把固定 cycle、内部信号名或当前 RTL 偶然行为写成期望，除非该行为已在 `ptwspec.md` 明确要求。

Related Verification Plan Item：填写现有 verification plan 中的章节、测试点编号、feature ID 或用例名；如果未找到对应项，写 N/A。

Related UVM Test / Sequence：填写当前 UVM 中已有 test、vseq、sequence、directed wrapper、coverage 或 SVA 名称；如果没有，写 N/A。若测试通过 L1DTLB/L2TLB 间接触发 PTW，也要说明是间接覆盖。

Observable Check：写当前审核阶段能判断该测试是否真的覆盖 requirement 的观察方向，例如 “检查 refill page_size/ppn/flg/global”、“检查 L2TLB valid 被 backpressure 时字段保持”、“检查 abort 后无 normal refill”。可以标记需要 monitor/SVA/probe 支持，但不展开实现。

Current Status：只允许使用 `keep`、`modify`、`add`、`delete`、`split`、`merge`、`unclear`。

Gap Type：记录缺口类型。`no_gap` 表示未发现缺口；其他类型用于后续集中修复。

Action：写下一步动作，例如 “保留现有测试”、“修改 expected behavior”、“新增 directed test”、“新增 assertion/monitor check”、“删除与 spec 冲突的测试”、“拆成 success/page fault/access fault 三个测试点”。

Action Notes：写简短理由。若需要后续 scoreboard/reference model 支持，只标记“后续需要 scoreboard 支持”或“后续需要 monitor/SVA 支持”，不在本表中设计模型。

## 4. Current Status 含义

| Status | 含义 |
| --- | --- |
| keep | 该 requirement 已有测试覆盖，测试目标和 expected behavior 与 `ptwspec.md` 一致，检查点足够清晰，可以保留。 |
| modify | 已有测试覆盖方向正确，但 stimulus、expected behavior、命名、覆盖条件、检查点或 plan 描述需要调整。 |
| add | `ptwspec.md` 有明确 requirement，但 verification plan 或 UVM 中未找到对应测试点。 |
| delete | 现有测试点与 spec 冲突、测试了 spec 明确不检查的行为，或重复且无独立价值。 |
| split | 一个现有测试点混合多个独立 spec 行为，导致目标和判定不清，需要拆分。 |
| merge | 多个测试点覆盖同一 requirement，且没有必要保持独立，需要合并或共享 stimulus。 |
| unclear | 仅凭当前 spec 或现有测试说明无法判断，需要补充信息。 |

## 5. Gap Type 含义

| Gap Type | 含义 |
| --- | --- |
| no_gap | 未发现测试点缺口。 |
| missing_test | 漏测，spec 中存在 requirement，但 plan/UVM 没有对应测试点。 |
| wrong_expected | 误测，现有测试点的 expected behavior 与 `ptwspec.md` 冲突。 |
| duplicate | 重复测，多个测试点覆盖同一 requirement 且无必要区分。 |
| weak_check | 弱检查，stimulus 可能覆盖到了场景，但没有足够可观察检查证明行为正确。 |
| tb_model_gap | TB 建模或可观测性缺口，测试该 requirement 需要 monitor、assertion、coverage、probe、agent 或 scoreboard 能力，但当前 TB 可能缺失。 |
| spec_gap | spec 缺口，当前 `ptwspec.md` 不足以决定测试点该如何设计或判定。 |

## 6. Action 取值建议

1. 保留现有测试。
2. 修改测试目标或 expected behavior。
3. 修改 stimulus/sequence。
4. 修改 coverage item。
5. 新增 directed test。
6. 新增 constrained-random 覆盖。
7. 新增 assertion/monitor check。
8. 删除测试点。
9. 拆分测试点。
10. 合并测试点。
11. 标记为后续 scoreboard/reference model 阶段处理。
12. 标记为后续 spec 澄清。

## 7. PTW Requirement 分组建议

审核时建议按以下 PTW requirement group 分批抽取 audit row，避免直接从现有测试列表出发。

| Group | 审核范围 | 主要 spec 来源 |
| --- | --- | --- |
| PTW-REQ-ADDR | Sv39 模式、VPN/PPN 分段、raw PTE / `ptw_flg` / refill `flg` 映射 | 1.1-1.4 |
| PTW-REQ-REQRSP | L2TLB 请求字段、type/id、成功 refill、异常返回目标、输出优先级 | 2.1-2.3 |
| PTW-REQ-PDEC | PDE cache 结构、lookup、update、clear、PLRU 边界 | 3.1-3.4 |
| PTW-REQ-XBAR | ready/backpressure、valid 字段保持、xbar hash、每周期 accept 限制 | 4 |
| PTW-REQ-TWU | `fst/scd/thd` PMP/CHK 流水、wait、mbuf 写入、下一级跳转 | 5.1-5.3 |
| PTW-REQ-PMP | 页表项物理地址 PMP 检查、effective mode、access fault | 5.1, 7, 12.9-12.11 |
| PTW-REQ-PF | leaf/non-leaf 判定、page fault 条件、不检查项 | 6.1-6.4 |
| PTW-REQ-CTX | MPRV/MPP、MXR/SUM、satp ASID/PPN、MAEE 使用点采样 | 7 |
| PTW-REQ-MBUF | mbuf entry、LSU 单 outstanding、普通 data、bus error | 8.1-8.4 |
| PTW-REQ-ARB | refill/page fault/access fault 寄存器、TWU/顶层仲裁优先级 | 9 |
| PTW-REQ-MAEE | MAEE=1、MAEE=0、sysmap、1G/2M 降级、4K sysmap refill | 10.1-10.8 |
| PTW-REQ-FLUSH | reset、satp/PMP change、`tlboper_ptw_abort`、LSU outstanding 边界 | 11.1-11.5 |
| PTW-REQ-FLOW | 23 个完整处理流程和最低功能场景 | 12.1-12.23, 13.4 |
| PTW-REQ-UVM | scoreboard/monitor/assertion/constraint 分工和可观测性 | 13.1-13.3 |

## 8. 特别注意事项

### 8.1 先按最终采用规则裁剪旧期望

审核必须先套用 `ptwspec.md` 第 0 章。若 verification plan 或 UVM 仍保留旧口径，应标记为 `wrong_expected` 或 `modify`。

重点检查：

1. RSW 进入 refill `flg`，但不参与 page fault。
2. raw PTE 的 G 位不进入 data `flg`，只进入 refill tag/global。
3. PTW 不额外检查 PTE high reserved bits、RSW、strong-order，也不因 MAEE=0 检查 PTE 扩展属性非 0。
4. 1G/2M PPN 对齐错误触发 page fault。
5. satp/PMP 改变只清 PDE cache，不 abort in-flight walk；旧 walk 未被 abort/flush 屏蔽时仍可重新更新 PDE cache。
6. `tlboper_ptw_abort` 清全部 PDE cache 并 flush in-flight PTW。
7. abort 同拍新形成的 LSU bus error 不上报。
8. load/store/PFU 在 `MPRV=1` 时使用 `MPP` 作为 effective privilege；fetch 不使用 MPRV。

### 8.2 不要把标准 Sv39 额外规则误写成 PTW 期望

PTW page fault 必须按 `ptwspec.md` 的本设计规则审核，不额外加入标准 Sv39 保留位、RSW、strong-order 等规则。若已有测试期待这些条件触发 page fault，应标记为 `wrong_expected`。

非叶子 PTE 只检查：

1. `V=0`。
2. 本设计 write-only 规则。
3. 第三级仍非叶子。

leaf PTE 需要重点覆盖：

1. `V=0`。
2. write-only：`W=1 && !(R || (MXR && X))`。
3. load 的 `R` 或 `MXR && X`。
4. store/atomic 的 `W` 和 `D`。
5. fetch 的 `X`。
6. PFU 的独立规则：不要求 `R`、不要求 `MXR && X`、不检查 `D`，但仍要求 `A`。
7. U/S 与 effective privilege、SUM。
8. 所有 leaf 都要求 `A=1`。
9. 1G/2M PPN 对齐。

### 8.3 区分事务级功能检查和周期级协议检查

`ptwspec.md` 明确规定 scoreboard 只做事务级最终匹配，不设固定周期上限。审核时不要因为某个测试没有固定 cycle latency 检查就直接判缺口；应判断该 requirement 属于哪类检查。

事务级 scoreboard 适合检查：

1. `type + id` 匹配。
2. 最终 refill/异常返回目标。
3. page size、PPN、ASID、global、flg。
4. PMP access fault、LSU bus error、page fault 的最终分类。
5. MAEE/sysmap 属性和大页降级结果。

assertion/monitor 更适合检查：

1. ready 低时 valid 和字段保持。
2. 每周期最多 accept 一个 L2TLB 请求。
3. xbar hash 选择。
4. PDE cache lookup/update 同拍读旧值、写下拍生效。
5. LSU request valid 拉高后 PA 稳定直到 data valid。
6. LSU 单 outstanding。
7. abort 时 normal refill 屏蔽、异常可见性边界。
8. 仲裁优先级和 wait/valid hold。

### 8.4 PDE cache 审核不能只看 hit/miss smoke

PDE cache 至少要按以下独立 requirement 审核：

1. 第一级命中跳过 `fst_pmp/fst_chk`，进入 `scd_pmp`。
2. 第二级命中跳过 `fst/scd` 两级，进入 `thd_pmp`。
3. 两级同时命中时选择第二级。
4. lookup/update 同拍时 lookup 看到旧值，update 下一拍生效。
5. 非叶子且无 page fault 才允许 update。
6. 第一级命中后第二级非叶子仍可更新第二级 PDE cache。
7. PDE cache 不存 ASID/global/权限/PMA/RSW/A/D。
8. satp 任意字段改变、PMP 配置改变、reset、abort 的清理语义不同。
9. satp/PMP 改变清空后，未 abort 的旧 in-flight walk 仍可重新 update。

若现有测试只覆盖 “PDE cache hit 后能成功翻译”，通常应标记为 `weak_check`，因为它不能证明跳级、双命中选择、update 条件和清理语义。

### 8.5 MAEE=0 与 sysmap/降级是高风险误审区

审核 MAEE/sysmap 时必须逐项确认：

1. `MAEE=1` 时 1G/2M/4K 都直接使用 PTE 高位扩展属性 `{So,C,B,Sh,Sec}`，不做 sysmap 和降级。
2. `MAEE=0` 时所有 page size 的 refill 扩展属性都来自 sysmap。
3. `MAEE=0` 的 4K leaf 也必须查询 sysmap，即使不降级。
4. 1G/2M 只比较首尾 4K PPN 所在 sysmap 区域。
5. 1G 可降级为 2M 或 4K；2M 可降级为 4K。
6. 降级不重新访问下一级页表，权限和 G/RSW/D/A/U/X/W/R/V 仍来自原始 leaf PTE。
7. 大页对齐错误先触发 page fault，不进入降级流程。
8. sysmap 无命中或多命中可被约束不产生，不应作为当前 PTW functional test 的默认错误场景。

### 8.6 请求 type、id 和返回目标必须逐项检查

PTW 请求只有 `vpn/type/id`。审核时要避免把 ASID、VMID、page size、IID、pipe id 等不存在于请求接口的字段写成请求检查点。

重点检查：

1. `type=3'b011` fetch/IUTLB 成功 refill L1ITLB 和 L2TLB。
2. `type=3'b010` load 成功 refill L1DTLB 和 L2TLB。
3. `type=3'b110` store/atomic 成功 refill L1DTLB 和 L2TLB。
4. `type=3'b100` PFU 成功只 refill L2TLB。
5. PFU 异常返回给 L2TLB，再由 L2TLB 上报 LSU prefetch 端口。
6. IUTLB 请求低 3 bit L1 DTLB id 固定为 0，scoreboard 应忽略 L1 部分。
7. 同一个 id 不会在旧请求完成前复用；若测试需要复用 id，必须先完成旧事务。
8. 顶层最终输出优先级固定为 `access fault > page fault > normal refill`。

### 8.7 PMP access fault 与 page fault 不能混淆

PMP 检查对象是读取 PTE 的物理地址，不是最终翻译出的物理地址。PMP deny 后请求结束，不写 mbuf、不发 LSU、不进入 CHK，也不会再产生 page fault。

审核 PMP 场景时要覆盖：

1. fst/scd/thd 三个级别的 PMP access fault。
2. fetch/load/store/PFU 对 PMP 权限位的不同解释。
3. effective M-mode 且 `pmp_mmu_flg[3]==0` 时跳过 PMP deny。
4. effective M-mode 但 `pmp_mmu_flg[3]==1` 时仍按权限判断。
5. LSU bus error access fault 与 TWU PMP access fault 的来源和优先级不同。

### 8.8 Abort、reset、satp/PMP change 不能合并成一个 flush 测试

这些事件语义不同，审核时应拆开：

1. reset 清 PDE cache 并 flush/清空 in-flight PTW、TWU、mbuf、refill 和异常寄存器。
2. satp 改变只清 PDE cache，不 flush in-flight。
3. PMP 配置改变只清 PDE cache，不 abort/flush in-flight。
4. `tlboper_ptw_abort` 清 PDE cache 并 flush in-flight PTW。
5. abort 前已经进入异常寄存器且当拍获得顶层授权的异常可见。
6. abort 同拍新形成异常不可见，特别是 LSU bus error 不上报。
7. abort 前一拍 LSU request valid 已经为 1 时，必须继续保持 LSU request valid 和 PA 到 data valid 返回。
8. abort 后返回普通 LSU 数据应丢弃，不进入 CHK、不 update PDE cache、不 refill。

若已有测试名类似 “flush/reset/abort common”，通常需要 `split`，因为它无法证明上述差异。

### 8.9 Mbuf 和 LSU 场景必须覆盖接口边界

mbuf 审核重点不是只看最终翻译成功，而是确认页表访问请求和返回处理符合 PTW 语义：

1. entry0-entry7 用于 DTLB/LSU/PFU，entry8 用于 IUTLB/fetch。
2. IUTLB 写 mbuf 优先级高于 TWU0-3。
3. DTLB 侧按 one-hot/左移指针轮转分配 entry0-entry7。
4. LSU 无 grant/ready，request valid 拉高后 PA 稳定直到 data valid。
5. LSU 串行单 outstanding。
6. 普通数据就是完整 64-bit PTE。
7. CHK 不 ready 时，mbuf 保存数据并置 `get`，后续 ready 再送回。
8. LSU bus error 不进入 CHK，直接形成 access fault；写异常寄存器成功前 entry 不可复用。
9. 顶层 access fault 仲裁中 LSU bus error 优先于 4 个 TWU access fault。

### 8.10 plan-only 覆盖与 UVM 实现覆盖要分开记录

审核时应区分三种情况：

1. plan 有条目，UVM 有明确测试和检查：通常为 `keep` 或 `modify`。
2. plan 有条目，UVM 没有落地或只有 generic random：通常为 `add` 或 `weak_check`。
3. plan 没有条目，但 `ptwspec.md` 有明确 requirement：通常为 `add`。

对于 generic random、stress 或 smoke 测试，只有在能证明 scenario gate、coverage bin、monitor event 或 log check 确实命中目标 requirement 时，才能算有效覆盖。否则应标记为 `weak_check`，并在 Action Notes 中说明需要 directed stimulus 或 coverage gate。

## 9. 最低 Required Scenario 清单

后续审核表至少应能追踪到以下场景。该清单来自 `ptwspec.md` 13.4，并按审核粒度补充了容易漏掉的变体。

| Scenario ID | Required Scenario | 审核关注点 |
| --- | --- | --- |
| PTW-SCN-001 | PDE cache miss，1G success | fst PMP/CHK、1G leaf、page_size=`3'b100`、返回目标 |
| PTW-SCN-002 | PDE cache miss，2M success | fst 非叶子 update PDE1、scd leaf、page_size=`3'b010` |
| PTW-SCN-003 | PDE cache miss，4K success | PDE1/PDE2 update、thd leaf、page_size=`3'b001` |
| PTW-SCN-004 | MAEE=1，PTE 扩展属性 refill | `{So,C,B,Sh,Sec}` 来自 raw PTE |
| PTW-SCN-005 | MAEE=0，1G 不降级 | 首尾同 sysmap 区域，属性来自 sysmap |
| PTW-SCN-006 | MAEE=0，1G->2M | 降级 PPN/page_size、无需访问第二级页表 |
| PTW-SCN-007 | MAEE=0，1G->4K | 连续降级，权限来自原 1G leaf |
| PTW-SCN-008 | MAEE=0，2M 不降级 | 2M 首尾同 sysmap 区域 |
| PTW-SCN-009 | MAEE=0，2M->4K | 不访问第三级页表 |
| PTW-SCN-010 | MAEE=0，4K sysmap refill | 4K 不降级但仍查 sysmap |
| PTW-SCN-011 | PMP access fault at fst | 不写 mbuf、不发 LSU、不 page fault |
| PTW-SCN-012 | PMP access fault at scd | 第一级已通过且非叶子 |
| PTW-SCN-013 | PMP access fault at thd | 前两级已通过且非叶子 |
| PTW-SCN-014 | CHK page fault at fst | 1G leaf fault 或 fst 非叶子 fault |
| PTW-SCN-015 | CHK page fault at scd | 2M leaf fault 或 scd 非叶子 fault |
| PTW-SCN-016 | CHK page fault at thd | 第三级非叶子或 4K leaf fault |
| PTW-SCN-017 | LSU bus error | 不进 CHK，access fault，LSU bus error 优先 |
| PTW-SCN-018 | 第一级 PDE cache hit，最终 2M | 跳过 fst，进入 scd |
| PTW-SCN-019 | 第一级 PDE cache hit，最终 4K | 跳过 fst，scd 非叶子后 update PDE2 |
| PTW-SCN-020 | 第二级 PDE cache hit，最终 4K | 同时命中时也选第二级 |
| PTW-SCN-021 | satp 改变清 PDE cache | 不 flush in-flight |
| PTW-SCN-022 | PMP 改变清 PDE cache | 不 flush in-flight，旧 walk 可 update |
| PTW-SCN-023 | `tlboper_ptw_abort` 无 LSU outstanding | 清 PDE/TWU/mbuf/refill/异常待写 |
| PTW-SCN-024 | `tlboper_ptw_abort` 有 LSU outstanding | 保持 LSU valid/PA 到返回并丢弃 |
| PTW-SCN-025 | abort 同拍普通 LSU data | 丢弃，不 CHK、不 update、不 refill |
| PTW-SCN-026 | abort 同拍 LSU bus error | 新形成 access fault 不上报 |
| PTW-SCN-027 | abort 前异常寄存器已获授权 | 异常可见 |
| PTW-SCN-028 | PFU success | 只 refill L2TLB，PTE 权限按 PFU 规则 |
| PTW-SCN-029 | PFU access fault/page fault | 异常返回 L2TLB，不产生独立 prefetch cause |
| PTW-SCN-030 | Load/Store/PFU with `MPRV=1 && MPP=M` | direct-map VA=PA and no PTW source; fetch ignores MPRV/MPP and uses real privilege |
| PTW-SCN-031 | raw PTE G/RSW/flg 映射 | G 只进 global，RSW 进 flg 且不 page fault |
| PTW-SCN-032 | ready/backpressure | ready 低时 L2TLB valid/字段保持 |
| PTW-SCN-033 | xbar hash | hash 选中 TWU 与 spec 公式一致 |
| PTW-SCN-034 | refill/page/access 仲裁 | `access fault > page fault > normal refill` |

## 10. 审核输出建议

后续实际审核建议产出两个文件或两个章节：

1. `PTW requirement-driven audit table`：使用第 2 章字段，逐行记录每个 PTW requirement 的 plan/UVM 覆盖状态。
2. `PTW existing testpoint index`：以现有 verification plan item 或 UVM test name 为主键，反向列出它覆盖的 `PTW-AUD-*`，用于发现重复测、孤儿测试和 plan/UVM 命名不一致。

每个新增或修改的测试点建议建立 traceability：

```text
ptwspec.md section -> PTW-AUD-* -> plan item -> UVM test/sequence -> coverage/SVA/monitor/check
```

审核完成前不要把 “有 random/stress 测试可能碰到” 当作关闭依据。关闭一个 audit row 至少需要说明 stimulus 如何命中、observability 如何判断、expected behavior 是否与 `ptwspec.md` 一致。
