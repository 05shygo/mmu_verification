# PTW MBUF LSU ID/Grant UVM 修改实施计划

本文档根据 `doc/ptw_uvm_review/ptw_lsu_id/mmu_ptw_mbuf_lsu_id_grant_update.md` 中记录的 RTL 设计变更，制定现有 UVM 验证环境的修改计划。目标是让 PTW memory channel agent、source-side reference model、scoreboard、SVA、directed tests、regression gate 能完整覆盖以下 RTL 新语义：

1. PTW 发给 LSU 的页表项读取 request 携带 4-bit request ID。
2. Request ID 等于 MBUF entry index。
3. LSU response 携带 4-bit response ID，并按 ID 路由回对应 MBUF entry。
4. `mmu_lsu_data_req && lsu_mmu_data_req_grant` 同拍成立才算 request fire。
5. Grant 前 request addr/id 必须保持稳定。
6. 每个 MBUF entry ID 最多一笔 outstanding，但多个不同 ID 可同时 outstanding。
7. Response 可以按 ID 乱序返回；旧 single-outstanding/no-tag/in-order 口径不再适用。
8. Abort 只清 entry `vld/get/bus_err_flop`，不直接清 `on`；abort drain 等所有 outstanding response 通过 ID 回来后结束。
9. Abort drain 期间禁止新建 MBUF entry、禁止新发 LSU request、禁止 PDE cache update。
10. PDE cache 连续 update 时，entry write enable 与 PLRU replacement way 必须同拍对应当前 update。

本文档只描述 UVM 修改计划，不直接修改 RTL/UVM 源码。

## 1. 范围和输入

### 1.1 输入文档和代码

| 输入 | 用途 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_lsu_id/mmu_ptw_mbuf_lsu_id_grant_update.md` | 本次 RTL 行为变更冻结语义。 |
| `doc/MMU_Traceability_Matrix.csv` | 现有全量测试点矩阵；当前重点审查 PTW/MBUF/LSU/PDE/abort 相关 rows。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_uvm_implementation_plan.md` | 本计划的组织结构参考。 |
| `mmu_verification/testbench/ptw_mem_agent/*` | PTW page-table memory channel UVC，当前仍按 strict serial single-outstanding 建模。 |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv`、`testbench/top/tb_top.sv` | whitebox probe 与 DUT/top/interface 连接。 |
| `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` | 当前 PTW-LSU protocol SVA，旧口径为 single outstanding/no tag/in-order。 |
| `mmu_verification/testbench/env/ptw_source_*.svh` | PTW source-side monitor/ref model/scoreboard。 |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh`、`top/mmu_pde_cache_sva.sv` | PDE cache golden model 与 SVA。 |
| `mmu_verification/testbench/test/ptw_lsu_protocol_tests/*` | 现有 PTW-LSU protocol directed wrappers。 |
| `mmu_verification/testbench/test/ptw_tests/*` | PTW source/PDE/abort directed tests。 |
| `mmu_verification/simu/mmu_ptw_lsu_protocol_list`、`ptw_p0_list`、`ptw_p1_list`、`ptw_code_coverage_list` | regression list。 |
| `mmu_verification/scripts/ptw_stage8_signoff_gate.py`、`ptw_functional_gate_rules.json` | 当前 PTW signoff gate 规则。 |

### 1.2 当前工作树观察到的关键差异

当前 `mmu/rtl/ptw.sv`、`ptw_mbuf.sv`、`mbuf_entry.sv`、`pplru.sv` 已出现新 ID/grant/abort drain/PLRU 逻辑；但 `mmu_verification/testbench/top/tb_top.sv` 和 `ptw_mem_if.sv` 仍按旧端口连接，尚未暴露：

```text
mmu_lsu_data_req_id[3:0]
lsu_mmu_data_id[3:0]
lsu_mmu_data_req_grant
```

同时 `ct_mmu_top.v` 的顶层 PTW-LSU 端口需要在 Phase 0 审计中确认已经与设计文档一致。如果仿真使用的 `mmu/rtl/ct_mmu_top.v` 仍缺少这些 top-level ports，则 UVM 适配前必须先同步 RTL top port，否则 testbench 无法合法连接新协议。

### 1.3 本计划覆盖内容

本计划覆盖：

1. PTW memory channel interface、transaction、monitor、responder。
2. PTW-LSU ID/grant/outstanding scoreboard 和 source-side reference model。
3. Abort drain 与 late response/no update/no new request 检查。
4. PTW-LSU protocol SVA 重写。
5. PDE cache 连续 update 与 PPLRU 同拍选路检查。
6. 旧 PTW-LSU tests 的重新归属和新增 directed tests。
7. regression list、closure matrix、signoff gate 更新。

本计划不覆盖：

1. LSU RTL 修改。
2. PTW/MBUF RTL 再设计。
3. 非 PTW source-side consumer scoreboard 的全面重构。
4. L1DTLB/L1ITLB/L2TLB 功能语义重写；它们只作为触发 PTW 场景的 stimulus source。

## 2. 设计语义冻结

### 2.1 PTW-LSU 外部协议

新增或重定义的协议信号：

| 信号 | 方向 | 位宽 | 语义 |
| --- | --- | --- | --- |
| `mmu_lsu_data_req` | PTW -> LSU | 1 | PTW page-table memory read valid。 |
| `mmu_lsu_data_req_addr` | PTW -> LSU | 40 | PTE 物理地址。 |
| `mmu_lsu_data_req_size` | PTW -> LSU | 1 | PTE read size，当前应保持 8B。 |
| `mmu_lsu_data_req_id` | PTW -> LSU | 4 | request ID，等于 MBUF entry index。合法范围 `0..8`。 |
| `lsu_mmu_data_req_grant` | LSU -> PTW | 1 | LSU 接收 request 的 grant/ready。 |
| `lsu_mmu_data_vld` | LSU -> PTW | 1 | LSU data response valid。 |
| `lsu_mmu_bus_error` | LSU -> PTW | 1 | LSU bus error response qualifier。 |
| `lsu_mmu_data` | LSU -> PTW | 64 | PTE data。 |
| `lsu_mmu_data_id` | LSU -> PTW | 4 | response ID，必须等于原 request ID。 |

协议 fire 定义：

```systemverilog
lsu_req_fire = mmu_lsu_data_req && lsu_mmu_data_req_grant;
```

UVM 中所有 PTW memory request 接收、计数、outstanding、responder lookup 都必须以 `lsu_req_fire` 为准，不能再使用旧的 whitebox `|mmu_lsu_data_req_grant[8:0]` 或单独 `mmu_lsu_data_req`。

### 2.2 Request ID 语义

Request ID 固定为发起 request 的 MBUF entry index：

```text
mmu_lsu_data_req_id == selected_mbuf_entry_index
```

UVM 必须检查：

1. `mmu_lsu_data_req_id` 在 `lsu_req_fire` 当拍合法：`0 <= id <= 8`。
2. `id` 与当前 selected/held MBUF entry onehot 一致。
3. 同一 `id` 在 response 返回前不能再次 fire。
4. 不同 `id` 可以并发 outstanding。
5. Response ID 只影响对应 entry；其它 entry 不得清 `on`、不得 latch data、不得 latch bus error。

### 2.3 Grant/hold 语义

`mmu_lsu_data_req` 是 valid，不是 accept。LSU 未 grant 时，PTW 必须保持同一笔 request 的地址和 ID：

```text
req=1, grant=0:
  addr/id/size stable
  entry.on not set
  outstanding not incremented

req=1, grant=1:
  request fire
  selected entry.on set
  outstanding[id] allocated
```

UVM 必须支持 grant backpressure，例如连续 `N` 拍 `grant=0` 后再 `grant=1`，并检查：

1. grant 前 `addr/id/size` 稳定。
2. grant 前没有 response 被调度。
3. grant 前 abort 可取消 held request，不产生 outstanding。
4. grant 后下一笔 request 才能选择其它 pending entry。

### 2.4 Response ID 和乱序返回语义

Response 通过 `lsu_mmu_data_id` 路由：

```text
lsu_mmu_data_id == i
  -> lsu_mmu_data_vld_entry[i] 或 lsu_mmu_bus_error_entry[i]
  -> entry i 状态更新
```

UVM responder 必须从旧的 FIFO/in-order 模式升级为 ID-indexed outstanding model：

1. 可以保持 in-order response 作为基础模式。
2. 必须支持 out-of-order response，即先 grant 的 request 不要求先 response。
3. 必须支持 bus error response 带 ID。
4. 必须支持非法 response ID `9..15` 的 negative mode，用于 SVA/robustness；默认合法 stimulus 不应产生非法 ID。
5. 对合法 response，monitor/ref model/scoreboard 必须按 response ID 找到原 request，而不是要求全局 pending 唯一。

### 2.5 Bus error 语义

Bus error 是 LSU response 的一种 completion，必须携带 ID。现有 RTL/SVA 口径中 bus error response 应与 `lsu_mmu_data_vld` 同拍有效；若最终 RTL 定义允许 `bus_error=1,data_vld=0`，Phase 0 需先冻结该规则并同步 SVA。

正常非 abort 情况：

```text
lsu_mmu_bus_error=1, lsu_mmu_data_id=i
  -> entry i bus_err_flop 或 bus_error writeback
  -> PTW source expected access fault
  -> access_src = MBUF_BUS_ERROR
```

Abort drain 情况：

```text
entry i 已被 abort 清 vld，但 on 仍为 1
lsu_mmu_bus_error=1, id=i
  -> 只用于清 entry i.on
  -> 不回 TWU
  -> 不产生 visible completion
  -> 不更新 PDE cache
```

### 2.6 Abort drain 语义

Abort 拆成两个概念：

| 概念 | 周期 | 作用 |
| --- | --- | --- |
| `mbuf_all_clr` | abort 当拍 | 清 entry `vld/get/bus_err_flop`，取消未完成 source transaction。 |
| `ptw_abort_drain` | abort 当拍到所有 `on` 清零 | 阻止新创建、新 request、新 PDE update，等待 LSU response drain。 |

UVM 必须建模：

1. Abort 当拍不直接清 `entry.on`。
2. 已 grant 的 request 仍等待 response ID 清 `on`。
3. 未 grant 的 held request 被取消，不进入 outstanding。
4. Drain 期间 `ptw_jtlb_ready` 应保持不可接收新 request。
5. Drain 期间不得新建 MBUF entry。
6. Drain 期间不得发新 LSU request。
7. Drain 期间不得产生 PDE cache update。
8. Drain 结束条件是所有 `entry.on==0`，不是看到第一笔 response。

### 2.7 PDE cache update 和 PLRU 连续更新语义

本次 RTL 修改同时修复 PDE cache 连续 update 路径：

1. `mbuf_cache_upd` 只允许在非 abort/drain 状态由正常 writeback data 触发。
2. 第三级 leaf、page fault、bus error、abort drain response 都不得更新 PDE cache。
3. 连续两拍 `mbuf_cache_upd` 必须可以连续写入不同 entry。
4. `pplru.write_num` 同拍输出为 `plru_PDE_ref_num`，不能使用上一拍 way。
5. L1/L2 update 由 `mbuf_cache_upd_lvl` 互斥选择。
6. L1/L2 update vector 必须 onehot0；update 为 1 时必须 onehot。
7. update vector 的 way 必须对应本拍 update data/vpn/ppn/pmpflg。

## 3. 现有 UVM 缺口

### 3.1 Top/interface 连接缺口

`ptw_mem_if.sv` 当前只有：

```text
mmu_lsu_data_req
mmu_lsu_data_req_addr
mmu_lsu_data_req_size
mmu_lsu_data_req_accept  // TB-only old whitebox pulse
lsu_mmu_data_vld
lsu_mmu_data
lsu_mmu_bus_error
```

缺少：

```text
mmu_lsu_data_req_id
lsu_mmu_data_req_grant
lsu_mmu_data_id
```

`tb_top.sv` 当前 DUT instantiation 也未连接这些新 top ports。若保持现状，新 RTL 将无法被 UVM 正确驱动和观测。

### 3.2 PTW memory transaction 缺口

`ptw_mem_txn.svh` 当前 transaction 只有 `addr/req_size/rsp_delay/pte_data/bus_error`，无法表达：

1. request ID。
2. response ID。
3. accept/fire cycle。
4. grant wait cycles。
5. response order index。
6. response 是否 out-of-order。
7. response 是否非法 ID。
8. response 是否属于 abort drain。
9. pending source key `{type,id,vpn}` 与 MBUF entry ID 的绑定。

### 3.3 Responder 缺口

`ptw_mem_responder.svh` 当前实现严格串行：

1. `m_has_accepted_req` 只有一个 slot。
2. `handle_request()` 阻塞直到当前 response 结束。
3. 无法在 response 前接收第二个 request。
4. 无法乱序返回。
5. 无法按 ID 注入 bus error。
6. 无法控制 grant backpressure。
7. 无法模拟 abort 前未 grant request 被取消。
8. 无法对同一 ID duplicate outstanding 做保护或 negative injection。

这与新 RTL 的多 outstanding ID 模型冲突。

### 3.4 Monitor 缺口

`ptw_mem_monitor.svh` 当前 pending state 也是单 slot：

1. `m_has_pending` 只能记录一笔 request。
2. response 到来时只按 pending slot 填 `addr/size`。
3. 若 response 时没有 pending，只能 warning。
4. 无法判断 response ID 是否命中具体 request。
5. 无法证明 out-of-order response 合法。
6. 无法证明 invalid ID 不影响 MBUF。
7. abort late response 只有 “req dropped/replaced” log，不能区分已 grant drain response 和未 grant cancel。

### 3.5 Source reference model 缺口

`ptw_source_ref_model.svh` 中 bus error 处理目前依赖 “只有一个 pending”：

```text
if (m_pending.num() == 1) selected_key = only pending;
else warning bus_error_without_unique_pending
```

新协议下这是错误口径。多 pending 是合法状态，bus error 必须通过 response ID 找到 MBUF entry，再找到 source key。

还需要补充：

1. request fire event 到 source key 的映射。
2. MBUF entry ID 到 pending walk key 的映射。
3. abort 后 pending source key drop 与 outstanding memory response drain 的分离。
4. invalid response ID 的 no-visible-effect 建模。
5. drain response 不产生 completion/PDE update。

### 3.6 Scoreboard 缺口

`ptw_source_sb.svh` 当前 no-extra-LSU checker 中存在旧口径：

```text
class=strict_single_outstanding
```

新协议下，PDE direct accerr 后仍可能存在其它 ID 的合法 outstanding request 或其它 source request 的合法 memory access。因此 no-extra-LSU 不能再用全局 “有任何 mem_req 就 fail” 规则，必须改成：

```text
对触发 PDE direct accerr 的 source key：
  accerr 生效后不得再出现同一 source key 的新 PTW memory request；
其它 source key / 已存在 outstanding / drain response 不作为 violation。
```

### 3.7 SVA 缺口

`mmu_ptw_lsu_protocol_sva.sv` 当前标题和实现仍是：

```text
strict single-outstanding PTE fetch protocol
No tag/ID field; responses in-order
```

其中以下旧断言需要删除或重写：

| 旧断言/cover | 问题 | 新口径 |
| --- | --- | --- |
| `a_single_outstanding` | 多 ID outstanding 合法 | 改为 no duplicate outstanding per ID。 |
| `a_response_inorder` | 乱序 response 合法 | 改为 response ID must match an outstanding ID。 |
| `a_lsu_addr_stable_until_vld` | 稳定到 response 的旧模型 | 改为 req held until grant/abort drain。 |
| `a_mbuf_entry_on_changes_on_lifecycle_event` | 允许 abort 清 on | 改为 on 只由 fire 置位、对应 ID response 清零。 |
| `cp_lsu_single_outstanding` | 覆盖目标过期 | 改为 two-or-more outstanding / OOO response cover。 |

### 3.8 Directed tests 缺口

现有 `ptw_lsu_protocol_tests`：

```text
test_pmbuf_serial_outstanding_001
test_pmbuf_no_tag_001
test_pmbuf_inorder_resp_001
test_pmbuf_addr_stable_001
test_pmbuf_ptr_hold_001
```

其中前三个名字和 expected 与新 RTL 冲突：

1. `serial_outstanding` 不再是关闭目标；应改成多 outstanding by ID。
2. `no_tag` 不再成立；应改成 request/response ID echo/route。
3. `inorder_resp` 只能保留为合法子场景，不能作为约束；必须新增 OOO response 场景。

### 3.9 PDE cache/PLRU 连续 update 缺口

现有 PDE pmpflg UVM 已有 update payload 观测，但本次连续 update 修复还需要额外闭环：

1. 连续两拍 update 的 way 不得重复使用上一拍 way。
2. 初始 invalid entries 应按 first invalid 填充 way0/way1/...。
3. L1/L2 连续 update 分别覆盖。
4. L1->L2 或 L2->L1 back-to-back update 不得互相污染。
5. Abort drain response 不得触发 update，即使返回 PTE 是合法 non-leaf。
6. PLRU update 使用同一拍 write_num，不得打一拍。

### 3.10 本轮复审新增的实际 UVM 差异

本节是对当前代码的二次复审结论，用于把前面的计划从“设计语义驱动”细化成“按现有 UVM 组件逐点修改”。

#### 3.10.1 RTL/top 当前不同步，属于 Phase 0 blocker

实际代码中 `mmu/rtl/ptw.sv` 和 `mmu/rtl/ptw_mbuf.sv` 已经有：

```text
mmu_lsu_data_req_id
lsu_mmu_data_id
lsu_mmu_data_req_grant
```

但 `mmu/rtl/ct_mmu_top.v` 仍只声明旧 PTW-LSU top ports：

```text
mmu_lsu_data_req
mmu_lsu_data_req_addr
mmu_lsu_data_req_size
lsu_mmu_bus_error
lsu_mmu_data_vld
lsu_mmu_data
```

`tb_top.sv` 也只连接旧 ports，并继续用旧 whitebox alias：

```systemverilog
assign ptw_mem_if_inst.mmu_lsu_data_req_accept =
  |u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant;
```

因此当前仿真入口不是“只差 UVM agent 修改”，而是 top integration 先不匹配。Phase 0 必须先同步 `ct_mmu_top.v` top port 和 `tb_top.sv` DUT instantiation；否则后续 responder/monitor 都无法合法连接 `req_id/rsp_id/grant`。

#### 3.10.2 `ptw_mem_agent` 内部有四个 single-slot 点

实际 UVC 中 single outstanding 假设分布在四个文件，不只在 responder：

| 文件 | 当前 single-slot 代码形态 | 必须替换为 |
| --- | --- | --- |
| `ptw_mem_if.sv` | 只有 `mmu_lsu_data_req_accept`，无 ID/grant/response ID。 | 明确 request valid、grant、request ID、response ID；`accept` 只能作为 deprecated fire alias。 |
| `ptw_mem_responder.svh` | `m_has_accepted_req`、`m_active_req`、blocking `handle_request()`、`_stash_accept_if_seen()`。 | grant thread + response scheduler thread；`m_outstanding_by_id[16]`；允许 response 与新 request fire 同拍。 |
| `ptw_mem_monitor.svh` | `m_has_pending/m_pending_addr/m_pending_size` 单 slot。 | `m_pending_by_id[16]`，response 用 `lsu_mmu_data_id` 查 pending。 |
| `ptw_mem_covergroups.svh` | `req_latched/rsp_start_cyc` 只能度量一笔 request。 | per-ID accept cycle、outstanding depth、OOO response、grant wait、abort drain coverage。 |

`ptw_mem_sequences.svh` 里 `ptw_mem_ooo_rsp_seq` 当前打印 “OOO not supported by single-outstanding protocol”，这必须改为合法 directed mode，而不是继续作为非法刺激。

#### 3.10.3 环境连接会把 `ptw_mem_txn` 广播到多个消费者

`mmu_env.svh` 当前把 `m_ptw_mem.m_monitor.ap_req/ap_rsp/ap_drop` 同时连到：

1. `ptw_source_ref_model`
2. `ptw_source_sb`
3. `ptw_scenario_db`
4. `mmu_credit_sb`
5. `mmu_perf_mon`

因此最保守的 schema 方案是优先扩展 `ptw_mem_txn`，而不是只新增一个没有被现有环境连接的 sideband transaction。若新增 `ptw_src_mem_evt_txn`，也必须同步修改 `mmu_env.svh` 连接关系，不能只在 monitor 中创建 AP。

#### 3.10.4 `mmu_credit_sb` 会把正确的多 outstanding 当成错误

`mmu_credit_sb.svh` 当前 PTW credit 逻辑是：

```text
m_ptw_mbuf_cnt++;
if (m_ptw_mbuf_cnt > 1) uvm_error("serialized PTW ext outstanding overflow")
```

这与新协议冲突。它必须从 scalar count 改为 ID-indexed outstanding set：

```text
ptw_outstanding_by_id[0..8]
count <= 9
duplicate same id before response/drop -> error
different ids outstanding simultaneously -> legal and covered
```

end-of-test drain、timeout snapshot、report banner 也必须从 “serialized ext limit=1” 改成 `peak_ptw_mbuf <= 9` 和 `id_mask`。

#### 3.10.5 `ptw_source_*` 已经有 PDE PMP 建模，但 memory ID 仍缺口

`ptw_source_types.svh`、`ptw_source_monitor.svh`、`ptw_source_ref_model.svh`、`ptw_source_sb.svh` 已经包含较多 PDE cache PMP flag/direct accerr 字段与 coverage，例如 `pde_reason`、`access_src`、`pde_direct_accerr`、`cached_l1pmpflg/l2pmpflg`。本次不要重复重做这部分基础 schema。

实际仍需补的是 memory-ID 绑定：

1. `ptw_source_ref_model.collect_mem_req()` 当前只计数，未建立 `mbuf_id -> source_key` map。
2. `collect_mem_rsp()` 仍使用 `m_pending.num()==1` 来定位 bus error source key。
3. `ptw_source_sb.check_mem_req_against_no_extra_lsu()` 仍输出 `class=strict_single_outstanding`。
4. `ptw_source_directed_base.ptw_enable_ptw_mem_ooo()` 当前把 OOO 当 illegal warning；新协议下 normal directed tests 要能启用合法 OOO-by-ID。

#### 3.10.6 PDE cache SVA 已覆盖 PMP flag，但缺连续 update/PLRU

`mmu_pde_cache_sva.sv` 当前已经覆盖 permission-qualified L1/L2 hit、L2 deny direct accerr、pmpflg update payload、tag deny no PLRU read-hit 等规则。这些不应在本计划中被当作“完全缺失”。

仍缺的部分是本次 RTL change 特有的连续 update 问题：

1. back-to-back `mbuf_cache_upd` 下第二拍 update vector 必须来自本拍 PLRU/refill way。
2. 初始 invalid entry 存在时连续两拍不应重复写同一 way。
3. L1/L2 mixed consecutive update 互不污染。
4. abort drain 或 bus error response 不能产生 update。

#### 3.10.7 旧 Phase 11 wrappers 是 metadata shell，必须改名字或重定向

`ptw_lsu_protocol_tests` 里的 wrappers 当前只配置 sequence/checker 字符串，不直接表达新行为。以下 wrapper 的名字和 checker 已过期：

| 当前 wrapper | 当前 checker | 新处理 |
| --- | --- | --- |
| `test_pmbuf_serial_outstanding_001` | `sva_single_outstanding` | 改成 multi-outstanding-by-ID wrapper 或 compatibility alias。 |
| `test_pmbuf_no_tag_001` | `sva_vld_only_when_req` | 改成 request/response ID basic route。 |
| `test_pmbuf_inorder_resp_001` | `sva_response_inorder` | 只保留 in-order legal subset，不再要求 response in-order。 |
| `test_pmbuf_addr_stable_001` | stable until vld | 改成 stable until grant。 |
| `test_pmbuf_ptr_hold_001` | pointer hold old checker | 改成 grant backpressure 下 `req_hold_ptr` hold/release。 |

Signoff gate 必须拒绝旧 marker，例如 `strict_single_outstanding`、`NO_TAG`、`sva_response_inorder` 作为 closure evidence。

#### 3.10.8 scenario/perf 也要同步新协议字段

`ptw_scenario_db.svh` 和 `mmu_perf_mon.svh` 不是 closure scoreboard，但它们是当前 regression 最常被拿来做 debug snapshot 的下游消费者，所以也不能继续把 PTW memory channel 当成单 outstanding 的标量流。

`ptw_scenario_db` 现有只是在 `scenario_id + kind + convert2string()` 里打印事件。后续必须确保 `ptw_mem_txn.convert2string()` 含有：

1. `req_id/rsp_id`。
2. `req_fire/grant_wait_cycles/accept_order/response_order`。
3. `ooo/invalid_rsp_id/abort_drain/bus_error`。
4. source key / MBUF id。

这样 directed test 的 scenario log 才能证明是哪一个 ID 被延迟、乱序或 drain。

`mmu_perf_mon` 现有只累计 `n_ptw_mem_req/n_ptw_mem_rsp`。后续至少要补：

1. peak outstanding 或 outstanding histogram。
2. OOO response 计数。
3. grant wait latency，至少要有 max grant wait。
4. abort drain response 计数。

这些统计不是新的 signoff 关闭条件，但它们必须和 `ptw_mem_txn` schema 同步，否则 perf dump 仍会误导成旧的 single-slot 协议。

## 4. 总体实施原则

1. 先让 top/interface 编译通过，再改 monitor/ref model。没有真实 `req_id/resp_id/grant` 观测时不能关闭任何新协议点。
2. 所有 PTW memory request 统计以 `req && grant` 为准。
3. `mmu_lsu_data_req` 拉高但未 grant 的周期不算 outstanding。
4. 多 outstanding 合法，但同一 MBUF entry ID 重复 outstanding 非法。
5. UVM responder 默认产生合法 ID echo；invalid ID 只在 negative/directed 模式启用。
6. Source-side closure 不能依赖 consumer-side VA->PA pass；必须有 PTW memory event、MBUF state、SVA cover 或 source scoreboard evidence。
7. Abort drop 和 abort drain 是两个不同事件：source request 被 drop，不代表已 grant memory response 被丢弃；response 必须继续 drain entry `on`。
8. PDE update closure 必须同时看 `mbuf_cache_upd`、L1/L2 update vector、entry payload/way、PLRU cover。
9. 旧测试名可以保留做兼容 wrapper，但 expected 必须更新；不能让过期测试名继续表达错误 spec。

## 5. 分阶段实施计划

下面的总览表先把每个 phase 的相关文件、任务内容、最终产出和退出标准收拢到一起；后面的 phase 小节继续保留展开说明。

| Phase | 相关文件 | 任务内容 | 最终产出 | 退出标准 |
| --- | --- | --- | --- | --- |
| 0 | `mmu/rtl/ct_mmu_top.v` / `ptw.sv` / `ptw_mbuf.sv` / `mbuf_entry.sv` / `pplru.sv` / `tb_top.sv` / `Files.f` | 审计 top 端口、ID/grant 传递、abort drain、PLRU 时序；确认编译入口。 | 新旧端口映射表；RTL/top blocker 记录。 | `ct_mmu_top`/`tb_top` 端口一致，build 能进编译阶段。 |
| 1 | `ptw_mem_if.sv` / `tb_top.sv` / `mmu_dut_probes_if.sv` | 接通 `req_id/rsp_id/grant`，重定义 fire，补 probes。 | 可驱动/可观测的新协议接口。 | 仿真不再依赖旧 `accept` 作为主语义。 |
| 2 | `ptw_mem_txn.svh` | 扩展 txn schema、enum、`convert2string()`。 | 支持 ID/order/grant/abort-drain 字段的统一 txn。 | 所有 PTW mem AP 消费者可编译。 |
| 3 | `ptw_mem_responder.svh` / `ptw_mem_if.sv` / `ptw_mem_sequences.svh` | 改成 ID-indexed outstanding + grant/backpressure scheduler。 | 可合法驱动多 outstanding/OOO/bus-error-by-ID。 | P0 basic ID、multi-outstanding、OOO test 能启动。 |
| 4 | `ptw_mem_monitor.svh` / `ptw_mem_if.sv` | 改成 `pending_by_id`，按 `rsp_id` 匹配/广播。 | ID-aware monitor/analysis AP。 | legal response 不再 unmatched，drop/rsp 语义分离。 |
| 5 | `ptw_source_types.svh` / `ptw_source_monitor.svh` | 扩展 source-side memory event schema 和 source-key 绑定。 | 统一的 source/key/request-id event 模型。 | source 侧能打印 `req_id/rsp_id/source_key`。 |
| 6 | `ptw_source_ref_model.svh` / `mmu_dut_probes_if.sv` | 改成 response-ID matching，处理 abort drain/no-update。 | source ref model 能按 ID 回溯 completion。 | bus error/data completion 不再依赖唯一 pending。 |
| 7 | `ptw_source_sb.svh` / `mmu_credit_sb.svh` / `ptw_scenario_db.svh` / `mmu_perf_mon.svh` | 改 coverage、no-extra-LSU、credit 计数和 logger/perf 汇总。 | 新的 LSU ID coverage、credit 报告、scenario/perf 报告。 | `strict_single_outstanding` 退出，ID/OOO/grant_wait 覆盖非零。 |
| 8 | `mmu_ptw_lsu_protocol_sva.sv` / `mmu_ptw_top_sva.sv` | 重写协议 SVA，删除单槽/无 tag/必须 in-order 旧断言。 | ID/grant/drain 协议断言集。 | 新 SVA 编译通过，旧口径断言移除。 |
| 9 | `mmu_pde_cache_sva.sv` | 补连续 update、same-cycle PLRU、abort-drain no-update。 | PDE/PLRU 特有 SVA 覆盖。 | back-to-back update 和 abort drain 用例有证据。 |
| 10 | `ptw_source_directed_base.svh` / `ptw_mem_sequences.svh` | 加 grant backpressure、OOO-by-ID、bus-error-by-ID helpers。 | 新 directed stimulus 基础库。 | 能生成 P0/P1 所需定向序列。 |
| 11 | `ptw_lsu_protocol_tests/*.svh` | 迁移旧 wrappers，重命名或重定向旧 metadata。 | 旧 wrapper 与新协议一致的兼容层。 | 旧 `NO_TAG`/`single_outstanding` 不再作为 closure 语义。 |
| 12 | `ptw_lsu_protocol_tests/*.svh` / `ptw_tests/*pde*` | 新增 ID/OOO/abort/PDE consecutive directed tests。 | 新 P0/P1/P2 directed test 集。 | 对应 test cases 可单独 run_check。 |
| 13 | `simu/*list` / suite include | 更新 regression list 和 suite include。 | 新专项/烟测/主回归入口。 | 列表中无过期测试残留。 |
| 14 | `ptw_source_closure_matrix.csv` / `doc/MMU_Traceability_Matrix.csv` | 更新矩阵 rows 与 requirement 绑定。 | 新 traceability 映射。 | 新 requirement/test/SVA/Cover 一一对应。 |
| 15 | `ptw_stage8_signoff_gate.py` / `ptw_functional_gate_rules.json` | 扩展现有 signoff gate，检查旧 marker、coverage、log evidence、negative list。 | 可执行 LSU-ID gate 扩展。 | gate 拒绝旧口径并放行新证据。 |

### 5.1 当前进度表

| Phase | 状态 | 当前进展 | 证据/备注 |
| --- | --- | --- | --- |
| 0 | Done | 已完成 RTL/top port 与编译入口审计，仿真入口可进入编译。 | 详见 `phase0_progress_debug.md`。 |
| 1 | Done | 已接通 PTW-LSU `req_id/rsp_id/grant`，并补充相关 probe/连接。 | 详见 `phase0_progress_debug.md`。 |
| 2 | Done | `ptw_mem_txn` 已扩展 ID/order/grant/abort-drain/source-key 字段，现有 PTW mem AP 消费者可编译。 | 详见 `phase0_progress_debug.md`。 |
| 3 | Done | `ptw_mem_responder` 已改为 ID-indexed outstanding model，支持 grant/backpressure、多 outstanding、显式 OOO、bus-error-by-ID、invalid response ID negative mode；`ptw_mem_sequences` 已补充对应轻量 sequence。 | Debug 记录 D-009；`comp_fast` 与 `run_check test_ptw_source_stage2_smoke` 通过。 |
| 4 | Done | `ptw_mem_monitor` 已改为 `pending_by_id[16]`，按 response ID 匹配 request/response/drop；同时补充 held request 稳定性检查、未 grant cancel drop、invalid ID 与 legal response without pending 标记。 | Debug 记录 D-010；`comp_fast` 与 `run_check test_ptw_source_stage2_smoke` 通过。 |
| 5 | Done | 已新增 `ptw_src_mem_evt_txn`/`ap_mem_evt` source-side memory event schema；`ptw_source_monitor` 通过 per-entry MBUF metadata probe 维护 `mbuf_id -> source key` map，并把 req/rsp/drop event fanout 到 source ref model、source scoreboard 和 scenario DB。 | Debug 记录 D-011；`comp_fast` 与 `run_check test_ptw_source_stage2_smoke` 通过。 |
| 6 | Done | `ptw_source_ref_model` 已新增 `m_mem_by_mbuf_id[16]` per-MBUF outstanding 表，使用 `ptw_src_mem_evt_txn.req_fire/rsp_fire` 按 `req_id/rsp_id` 建表和匹配；bus-error completion 改为按 ID/source key 回溯 pending source，abort/drop 只标记已 grant outstanding 等待 response drain，并阻止 abort-drain late data 产生 visible completion/PDE update 预测。 | Debug 记录 D-012；`comp_fast` 与显式 `+EN_PTW_SOURCE_REF_MODEL` 的 `run_check test_ptw_source_stage2_smoke` 通过。 |
| 7 | Done | `ptw_source_sb` 已新增 LSU ID coverage/outstanding、source-key scoped no-extra-LSU、bus-error/abort-drain/PDE-update contiguous summary；`mmu_credit_sb` 已改为 ID-indexed PTW outstanding set；`ptw_scenario_db`/`mmu_perf_mon` 已输出同源 memory event 的 ID/OOO/grant_wait/drain 汇总。 | Debug 记录 D-013；`comp_fast` 与显式 `+EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_SB` 的 `run_check test_ptw_source_stage2_smoke` 通过。 |
| 8 | Done | `mmu_ptw_lsu_protocol_sva` 已从 strict serial model 改为 ID/grant/outstanding model，新增 MBUF internal port bind、per-ID duplicate/response matching、fire 后 entry-on、response 只清对应 ID、invalid response no-side-effect、grant hold/no-ungranted-on、abort-drain hold cancel/no-new-req/no-cache-update、abort_reg 等待 entry_on 清空，以及 Phase8 cover/final summary。`mmu_ptw_top_sva` 静态检查无旧 PTW-LSU single/no-tag/in-order 口径，无需修改。 | Debug 记录 D-014；`comp_fast` 与显式 `+EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_SB` 的 `run_check test_ptw_source_stage2_smoke` 通过。 |
| 9 | Done | `mmu_pde_cache_sva` 已补齐 `PTW-SVA-PDE-UPD-020..026`：连续 update onehot/known、invalid way 未满时不复用上一拍 way、L1/L2 entry update 与同拍 PLRU refill vector 一致、L1/L2 update 互斥、abort-drain no-update、bus-error same/next-cycle no-update；新增 `mmu_pde_pplru_sva` bind 到 `pplru` 检查 `write_num -> plru_PDE_ref_num` 同拍 onehot 和 all-invalid/first-invalid/full-valid 选路；`ptw_source_sb` 已有 PDE update contiguous/abort-drain summary。 | Debug 记录 D-015；`comp_fast` 与显式 `+EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_SB` 的 `run_check test_ptw_source_stage2_smoke` 通过。默认 smoke 已命中 L1/L2 PLRU refill、PDE mutual exclusion、bus-error no-update；back-to-back/abort-drain cover hit 由后续 directed tests 负责。 |
| 10 | Done | directed helper/sequences 已新增 grant backpressure、OOO-by-ID、bus-error-by-ID、invalid response ID negative 和观察 helper。 | Debug 记录 D-016；`comp_fast` 与 directed smoke 通过。 |
| 11 | Done | 旧 PTW-LSU protocol wrappers 已重归属为 LSU-ID 兼容语义，旧 single/no-tag/in-order 不再作为 closure 证据。 | Debug 记录 D-017；legacy wrapper smoke 通过。 |
| 12 | Done | 已新增 LSU-ID 专用 Phase12 base、PTW-LSU ID/grant/OOO/abort/bus-error/invalid/stress tests 与 PDE consecutive/no-update tests。 | Debug 记录 D-018；Phase12 focused smoke 收口通过。 |
| 13 | Done | 已更新 suite include 与 regression lists；新增 `ptw_lsu_id_grant_list`；P0/P1 normal list 隔离 invalid response negative，旧 5 个 Phase11 wrapper 不再作为 active regression list 条目。 | Debug 记录 D-019；`ptw_lsu_id_grant_list` 单 seed regression 7/7 PASS。 |
| 14 | Done | traceability matrix 已更新并与 source closure matrix 同步。 | Debug 记录 D-020；14 个新增 requirement ID 在两份矩阵中各唯一出现一次。 |
| 15 | Done | 已在现有 `ptw_stage8_signoff_gate.py` 中加入可选 LSU-ID gate 扩展，并同步 `ptw_functional_gate_rules.json`。 | Debug 记录 D-021；静态/单测 gate 检查通过，完整 gate PASS 需基于新生成的 606/707 run_check 日志包执行。 |

### Phase 0: RTL/top port 和编译入口审计

目标：确认当前仿真 RTL 与设计文档端口一致，并让 UVM 有能力连接新协议。

必须审计：

| 文件 | 审计内容 |
| --- | --- |
| `mmu/rtl/ct_mmu_top.v` | 是否声明 `mmu_lsu_data_req_id`、`lsu_mmu_data_id`、`lsu_mmu_data_req_grant` top ports。 |
| `mmu/rtl/ptw.sv` | 新端口是否存在，是否传入 `ptw_mbuf`。 |
| `mmu/rtl/ptw_mbuf.sv` | `req_hold_vld/ptr`、`lsu_req_fire`、ID 解码、abort drain 信号名。 |
| `mmu/rtl/mbuf_entry.sv` | `mbuf_on` 不被 abort 清、data/error routed response 逻辑。 |
| `mmu/rtl/pplru.sv` | `plru_PDE_ref_num` 是否由本拍 `write_num` 生成。 |
| `mmu_verification/testbench/top/tb_top.sv` | DUT instantiation 和 probes 是否连到新 ports。 |
| `mmu_verification/testbench/Files.f` | SVA/interface 编译顺序是否满足新增端口。 |

Phase 0 输出：

1. 新旧 port 名准确映射表。
2. 若 `ct_mmu_top.v` 尚未暴露新 ports，记录为 RTL/top integration blocker，不能用 hierarchical force 规避。
3. `make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke` 至少能进入 UVM 编译阶段。

### Phase 1: `ptw_mem_if` 和 `tb_top` 协议连接升级

修改 `mmu_verification/testbench/ptw_mem_agent/ptw_mem_if.sv`：

新增 request side signals：

```systemverilog
logic        mmu_lsu_data_req;
logic [39:0] mmu_lsu_data_req_addr;
logic        mmu_lsu_data_req_size;
logic [3:0]  mmu_lsu_data_req_id;
```

新增 response/grant side signals：

```systemverilog
logic        lsu_mmu_data_req_grant;
logic        lsu_mmu_data_vld;
logic [63:0] lsu_mmu_data;
logic        lsu_mmu_bus_error;
logic [3:0]  lsu_mmu_data_id;
```

保留或重命名 TB helper：

```systemverilog
wire mmu_lsu_data_req_fire = mmu_lsu_data_req & lsu_mmu_data_req_grant;
```

旧 `mmu_lsu_data_req_accept` 建议改为 deprecated alias：

```systemverilog
assign mmu_lsu_data_req_accept = mmu_lsu_data_req_fire;
```

但新增代码不得再依赖 `accept` 名称表达 old serial accept。

修改 `tb_top.sv`：

1. DUT instantiation 连接 `mmu_lsu_data_req_id` 到 `ptw_mem_if_inst.mmu_lsu_data_req_id`。
2. DUT instantiation 连接 `lsu_mmu_data_id` 到 `ptw_mem_if_inst.lsu_mmu_data_id`。
3. DUT instantiation 连接 `lsu_mmu_data_req_grant` 到 `ptw_mem_if_inst.lsu_mmu_data_req_grant`。
4. 删除或重定义 `assign ptw_mem_if_inst.mmu_lsu_data_req_accept = |u_dut.x_ct_mmu_ptw.u_ptw_mbuf.mmu_lsu_data_req_grant;`。
5. timeout/diag print 增加 request ID、response ID、grant。

修改 `mmu_dut_probes_if.sv`：

新增：

```systemverilog
wire [3:0] ptw_lsu_data_req_id;
wire [3:0] ptw_lsu_data_rsp_id;
wire       ptw_lsu_data_req_grant;
wire       ptw_lsu_data_req_fire;
wire       ptw_abort_drain;
wire       ptw_mbuf_req_hold_vld;
wire [8:0] ptw_mbuf_req_hold_ptr;
wire [8:0] ptw_mbuf_req_sel_ptr;
wire [8:0] ptw_mbuf_req_on_ptr;
wire [8:0] ptw_mbuf_req_pending;
wire [8:0] ptw_mbuf_resp_dec;
wire [8:0] ptw_mbuf_data_vld_entry;
wire [8:0] ptw_mbuf_bus_error_entry;
wire [8:0] ptw_mbuf_entry_on;
wire [8:0] ptw_mbuf_entry_get;
wire [8:0] ptw_mbuf_entry_bus_err_flop;
```

PDE/PLRU 额外 probes：

```systemverilog
wire [15:0] pde_l1_update_vec;
wire [15:0] pde_l2_update_vec;
wire [15:0] pde_l1_valid_vec;
wire [15:0] pde_l2_valid_vec;
wire [15:0] pde_l1_plru_ref_num;
wire [15:0] pde_l2_plru_ref_num;
wire        pde_l1_refill_vld;
wire        pde_l2_refill_vld;
```

若 `pplru.write_num` 没有 module port，SVA 可以通过 bind 到 `pplru` 内部信号，或在 `PDE_cache` bind 中使用 `plru_LxPDE_ref_num` 作为同拍结果。

### Phase 2: `ptw_mem_txn` schema 扩展

修改 `ptw_mem_txn.svh`，新增字段：

```systemverilog
bit [3:0]        req_id;
bit [3:0]        rsp_id;
bit              req_fire;
bit              rsp_valid;
bit              rsp_is_ooo;
bit              rsp_id_invalid;
bit              duplicate_id_error;
bit              aborted_before_grant;
bit              abort_drain_rsp;
int unsigned     req_cycle;
int unsigned     grant_wait_cycles;
int unsigned     accept_order;
int unsigned     response_order;
logic [2:0]      source_type;
logic [6:0]      source_id;
logic [26:0]     source_vpn;
```

新增 response order enum：

```systemverilog
typedef enum bit [2:0] {
  PTW_RSP_IN_ORDER      = 3'd0,
  PTW_RSP_BY_ID_OOO     = 3'd1,
  PTW_RSP_BUS_ERR_BY_ID = 3'd2,
  PTW_RSP_INVALID_ID    = 3'd3,
  PTW_RSP_DUPLICATE_ID  = 3'd4
} ptw_rsp_order_e;
```

新增 grant mode enum：

```systemverilog
typedef enum bit [2:0] {
  PTW_GRANT_ALWAYS_READY = 3'd0,
  PTW_GRANT_DELAY_FIXED  = 3'd1,
  PTW_GRANT_DELAY_RANDOM = 3'd2,
  PTW_GRANT_HOLD_UNTIL_ABORT = 3'd3
} ptw_grant_mode_e;
```

`convert2string()` 必须打印：

```text
addr size req_id rsp_id req_cycle accept_order response_order
grant_wait bus_error rsp_kind ooo invalid_id abort_drain source={type,id,vpn}
```

### Phase 3: PTW memory responder 改成 ID-indexed outstanding model

目标：Responder 真实扮演 LSU request grant + data response channel。

核心数据结构：

```systemverilog
typedef struct {
  bit              valid;
  bit [3:0]        id;
  bit [39:0]       addr;
  bit              size;
  bit [63:0]       pte;
  bit              bus_error;
  int unsigned     accept_order;
  int unsigned     target_rsp_cycle;
  bit              abort_seen_after_accept;
} ptw_outstanding_s;

ptw_outstanding_s m_outstanding_by_id[16];
int unsigned      m_legal_outstanding_count;
int unsigned      m_accept_count;
int unsigned      m_response_count;
```

Responder run loop 拆成两个并行线程：

1. Grant/request accept thread。
2. Response scheduler thread。

Request accept thread：

1. 每拍采样 `mmu_lsu_data_req` 和 `mmu_lsu_data_req_id`。
2. 按 grant mode 决定 `lsu_mmu_data_req_grant`。
3. 当 `req && grant` 时：
   - 检查 `req_id <= 8`。
   - 检查该 `req_id` 当前没有 outstanding。
   - 读取 page table builder 得到 PTE。
   - 创建 `m_outstanding_by_id[req_id]`。
   - 记录 accept order。
4. 当 `req && !grant` 时：
   - 记录 held request snapshot。
   - 若 addr/id/size 跳变，报 UVM error 或交给 SVA。
5. 当 abort 时：
   - held but not granted 的 request 清除，不加入 outstanding。
   - 已 granted 的 outstanding 标记 `abort_seen_after_accept`，等待 response。

Response scheduler thread：

1. 每拍扫描 outstanding。
2. 按 policy 选择 response ID：
   - `IN_ORDER`：最小 accept_order。
   - `OOO`：可选择非最老 outstanding。
   - `BY_ID`：directed 指定 ID。
   - `BUS_ERR`：directed 指定 ID/addr/count。
3. drive:

```systemverilog
lsu_mmu_data_vld  <= 1'b1;
lsu_mmu_data      <= selected.pte;
lsu_mmu_bus_error <= selected.bus_error;
lsu_mmu_data_id   <= selected.id;
```

4. response 一拍后清 drive。
5. 删除对应 outstanding。
6. 若 enabled invalid-ID negative，drive `rsp_id=9..15`，但不得删除合法 outstanding。

新增 directed control APIs：

```systemverilog
set_grant_delay_for_count(count, cycles)
set_grant_delay_for_id(id, cycles)
set_delay_for_id(id, cycles)
set_delay_for_addr(addr, cycles)
set_bus_error_for_id(id)
set_bus_error_for_addr(addr)
set_response_order_mode(PTW_RSP_BY_ID_OOO)
force_next_response_id(id)
force_invalid_response_id(id_9_to_15)
set_max_outstanding(depth)
clear_directed_controls()
```

默认合法模式：

1. grant always ready。
2. delay range `[1:8]`。
3. response may be in-order unless test enables OOO。
4. no invalid ID。
5. no duplicate response。

### Phase 4: PTW memory monitor 改成 ID-aware monitor

Monitor 必须输出三个概念不同的事件：

| AP | 触发 | 语义 |
| --- | --- | --- |
| `ap_req` | `req && grant` | 一笔 request 被 LSU 接收。 |
| `ap_rsp` | `data_vld || bus_error` | 一笔 response 返回，带 `rsp_id`。 |
| `ap_drop` | reset 或未 grant request 被 abort cancel | request 未进入 outstanding 或 pending 被 reset 清除。 |

Monitor 内部数据结构：

```systemverilog
ptw_mem_txn m_pending_by_id[16];
bit         m_has_pending_by_id[16];
int unsigned m_accept_order_next;
int unsigned m_response_order_next;
```

Request 采样：

1. `req_fire = mmu_lsu_data_req && lsu_mmu_data_req_grant`。
2. fire 时创建 `ptw_mem_txn`，填 `req_id/addr/size/req_cycle/accept_order`。
3. 如果 `req_id > 8`，报错。
4. 如果同 ID already pending，报错。
5. 广播 `ap_req`。

Response 采样：

1. `rsp_id = lsu_mmu_data_id`。
2. 填 `rsp_id/pte_data/bus_error/response_order`。
3. 如果 `rsp_id <= 8` 且 pending exists，补齐原 request addr/source metadata 并删除 pending。
4. 如果 `rsp_id > 8`，标记 `rsp_id_invalid=1`，广播用于 negative/SVA evidence。
5. 如果 `rsp_id <= 8` 但无 pending，标记 `rsp_without_pending=1` 并 warning/error，默认合法 tests 应 fail。
6. 若 response 对应 pending 已被 abort 标记，标记 `abort_drain_rsp=1`。

Grant hold 采样：

1. `req && !grant` 第一个周期记录 held `{addr,id,size}`。
2. 继续 `req && !grant` 必须保持一致。
3. 若 abort/drain 清 req，发出 held-cancel evidence。

### Phase 5: source-side transaction/schema 扩展

在 `ptw_source_types.svh` 中新增或扩展 PTW memory event schema。建议新增独立 transaction：

```systemverilog
class ptw_src_mem_evt_txn extends uvm_sequence_item;
  int unsigned cycle;
  bit          req_fire;
  bit          rsp_fire;
  bit [3:0]    req_id;
  bit [3:0]    rsp_id;
  bit [39:0]   addr;
  bit          size;
  bit [63:0]   data;
  bit          bus_error;
  bit          ooo;
  bit          invalid_rsp_id;
  bit          abort_drain;
  ptw_src_req_type_e req_type;
  logic [6:0]  source_id;
  logic [26:0] vpn;
endclass
```

如果不新增 class，也必须把相同字段加入 `ptw_mem_txn` 并在 source ref model/SB 中消费。

关键 mapping：

```text
MBUF entry id -> accepted PTW memory request
accepted PTW memory request -> source key {type, source_id, vpn}
response id -> MBUF entry id -> source key
```

source key 不能从 response 当拍的当前 PTW request 推断，必须来自 request fire 当拍保存的 entry metadata。

### Phase 6: source reference model 改成 response-ID matching

修改 `ptw_source_ref_model.svh`：

#### 6.1 新增 MBUF outstanding map

```systemverilog
typedef struct {
  bit                    valid;
  bit [3:0]              mbuf_id;
  string                 source_key;
  ptw_src_req_type_e     req_type;
  logic [6:0]            source_id;
  logic [26:0]           vpn;
  logic [39:0]           addr;
  bit                    aborted;
  bit                    visible_allowed;
  int unsigned           accept_cycle;
} ptw_mem_outstanding_s;

ptw_mem_outstanding_s m_mem_by_mbuf_id[16];
```

#### 6.2 request fire 处理

在 `collect_mem_req()` 中：

1. 使用 `tr.req_id` 建立 `m_mem_by_mbuf_id[tr.req_id]`。
2. 通过当前 MBUF entry probe 或最近 level event 找到 source key。
3. 如果找不到 source key，记录 probe gap，但仍保存 addr/id。
4. 若同 ID 已 valid，报 duplicate outstanding mismatch。

#### 6.3 response 处理

在 `collect_mem_rsp()` 中删除旧逻辑：

```systemverilog
if (m_pending.num() == 1) ...
else bus_error_without_unique_pending
```

改为：

1. `rsp_id = tr.rsp_id`。
2. 如果 `rsp_id > 8`：
   - 记录 invalid response coverage。
   - 不产生 completion。
   - 不更新 PDE model。
3. 如果 `m_mem_by_mbuf_id[rsp_id].valid == 0`：
   - 默认 UVM error，negative test 可 downgrade。
4. 如果 pending `aborted==1`：
   - 删除 outstanding。
   - 不产生 expected refill/page/access completion。
   - 不预测 PDE update。
5. 如果 `tr.bus_error==1` 且未 aborted：
   - 对该 source key 生成 expected access fault。
   - `fault_kind=PTW_SRC_FAULT_BUS_ERROR`。
   - `access_src=PTW_SRC_ACCESS_SRC_MBUF_BUS_ERROR`。
6. 如果 normal data：
   - 按原 level/PTE decode 更新 pending walk。
   - non-leaf 且非 fault 时预测 PDE update。

#### 6.4 abort/drop 处理

当 source monitor 发出 abort drop：

1. 对 source pending key 标记 drop expected。
2. 对所有与该 source key 相关的 `m_mem_by_mbuf_id[*]` 标记 `aborted=1`。
3. 不删除已 grant outstanding；必须等待 response ID。
4. 对 held but not granted request，由 monitor drop 直接删除，不进入 outstanding。

#### 6.5 PDE update 预测

PDE update 预测必须增加 drain gate：

```text
if mem response belongs to aborted/drain request:
  no predicted PDE update
else if normal non-leaf:
  predict PDE update
```

并增加 consecutive update queue 检查：连续两拍 observed update 均必须有 predicted update match，不允许第二拍 timeout 或 way 覆盖造成 missing update。

### Phase 7: scoreboard/coverage 升级

修改 `ptw_source_sb.svh`：

#### 7.1 memory channel coverage

新增 counters：

```systemverilog
n_cov_lsu_req_id[9]
n_cov_lsu_rsp_id[9]
n_cov_lsu_req_rsp_id_match
n_cov_lsu_two_outstanding
n_cov_lsu_max_outstanding
n_cov_lsu_ooo_response
n_cov_lsu_grant_wait
n_cov_lsu_abort_drain_rsp
n_cov_lsu_invalid_rsp_id_ignored
n_cov_lsu_bus_error_by_id
n_cov_lsu_duplicate_id_blocked
```

report 增加：

```text
PTW_SOURCE_SB_LSU_ID_COVERAGE
  req_id_mask rsp_id_mask two_outstanding ooo grant_wait abort_drain
  buserr_by_id invalid_id duplicate_id max_outstanding
```

#### 7.2 no-extra-LSU checker 改口径

删除或废弃：

```text
class=strict_single_outstanding
```

改为：

```text
class=source_key_scoped
```

规则：

1. PDE direct accerr 对某 `{type,id,vpn}` 生效后，不能再出现同 key 的新 PTW memory request fire。
2. 已经在 accerr 前 fire 的其它 ID response 不算 violation。
3. 不同 source key 的 request 不算 violation。
4. 如果缺少 source key probe，标 `probe_gap_source_key_missing`，不能关闭对应 requirement。

#### 7.3 bus error compare

bus error expected/actual compare 增加：

1. `mbuf_id`。
2. `rsp_id`。
3. source key。
4. abort drain flag。

若 bus error response id 对应 aborted request，scoreboard 不应期待 visible access fault。

#### 7.4 PDE consecutive update coverage

新增 counters：

```systemverilog
n_cov_pde_consecutive_l1_update
n_cov_pde_consecutive_l2_update
n_cov_pde_consecutive_mixed_l1_l2
n_cov_pde_update_way_changes_when_invalid_available
n_cov_pde_update_blocked_by_abort_drain
```

report 增加：

```text
PTW_SOURCE_SB_PDE_UPDATE_CONTIG_COVERAGE
```

#### 7.5 downstream logger / perf consumer 对齐

`mmu_credit_sb.svh`、`ptw_scenario_db.svh`、`mmu_perf_mon.svh` 都要消费同一份扩展后的 `ptw_mem_txn`，但各自职责不同：

1. `mmu_credit_sb` 负责把 PTW scalar count 改成 ID-indexed outstanding set，并保留 peak mask、duplicate ID、drain 退出等报告。
2. `ptw_scenario_db` 负责把 `req_id/rsp_id/grant_wait/ooo/abort_drain` 写进 scenario log，方便 directed case 回溯。
3. `mmu_perf_mon` 负责把 PTW walk 统计从 `req/rsp` 数量扩展到 peak outstanding、OOO response、grant wait 和 abort latency 的汇总。

这些 consumer 不负责关 requirement，但它们的 report 输出必须与新协议一致，否则 regression 日志仍会保留过时的 single-outstanding 语义。

### Phase 8: `mmu_ptw_lsu_protocol_sva.sv` 重写

将 SVA 从 strict serial model 改为 ID/grant/outstanding model。

#### 8.1 新增端口

建议端口：

```systemverilog
input logic        mmu_lsu_data_req;
input logic [39:0] mmu_lsu_data_req_addr;
input logic        mmu_lsu_data_req_size;
input logic [3:0]  mmu_lsu_data_req_id;
input logic        lsu_mmu_data_req_grant;
input logic        lsu_mmu_data_vld;
input logic        lsu_mmu_bus_error;
input logic [3:0]  lsu_mmu_data_id;
input logic [8:0]  mbuf_entry_vld;
input logic [8:0]  mbuf_entry_on;
input logic [8:0]  mbuf_entry_get;
input logic [8:0]  mbuf_entry_bus_err_flop;
input logic [8:0]  mbuf_entry_upd;
input logic [8:0]  mbuf_entry_req_grant;
input logic [8:0]  lsu_mmu_data_vld_entry;
input logic [8:0]  lsu_mmu_bus_error_entry;
input logic [8:0]  req_sel_ptr;
input logic [8:0]  req_hold_ptr;
input logic        req_hold_vld;
input logic [8:0]  mmu_lsu_data_req_ptr;
input logic        ptw_abort_drain;
input logic        tlboper_ptw_abort_reg;
input logic        mbuf_cache_upd;
input logic [8:0]  write_back_req;
input logic [8:0]  write_back_grant;
input logic [8:0]  bus_err_write_back_req;
```

若 bind `.*` 无法自动连接 internal names，改为显式 bind 或新增 wrapper。

#### 8.2 必须删除/替换的旧 assertion

1. 删除 `a_single_outstanding`。
2. 删除 `a_response_inorder`。
3. 删除旧 `a_lsu_addr_stable_until_vld`。
4. 删除 “abort clears entry_on” 相关 cover。

#### 8.3 新增 assertion

| SVA ID | 规则 | 说明 |
| --- | --- | --- |
| `PTW-SVA-LSUID-001` | `req && grant -> req_id inside {[0:8]}` | request ID 合法。 |
| `PTW-SVA-LSUID-002` | `req && grant -> !outstanding[req_id]` | 同 ID 不允许重复 outstanding。 |
| `PTW-SVA-LSUID-003` | `req && grant -> ##1 mbuf_entry_on[req_id]` | fire 后对应 entry on。 |
| `PTW-SVA-LSUID-004` | `data_vld/bus_error && rsp_id<=8 -> outstanding[rsp_id]` | response 必须命中 outstanding ID。 |
| `PTW-SVA-LSUID-005` | response ID `i` 只能清 `entry_on[i]` | 其它 entry 不受影响。 |
| `PTW-SVA-LSUID-006` | invalid `rsp_id>8` 不得清任何 entry/get/buserr/writeback/update | 非法 ID no side effect。 |
| `PTW-SVA-GRANT-001` | `req && !grant && !abort_drain |=> stable(addr,id,size)` | grant 前稳定。 |
| `PTW-SVA-GRANT-002` | `req && !grant` 不置任何 entry on | 未 grant 不 outstanding。 |
| `PTW-SVA-GRANT-003` | abort drain 清 hold，且 held request 不 fire | abort before grant cancel。 |
| `PTW-SVA-ABDRN-001` | abort 不直接清 `entry_on` | `on` 只能由对应 response 清。 |
| `PTW-SVA-ABDRN-002` | drain 期间 `mbuf_entry_upd==0` | 不新建 entry。 |
| `PTW-SVA-ABDRN-003` | drain 期间 `mmu_lsu_data_req==0` | 不发新 request。 |
| `PTW-SVA-ABDRN-004` | drain 期间 `mbuf_cache_upd==0` | 不更新 PDE。 |
| `PTW-SVA-ABDRN-005` | abort_reg 直到所有 `entry_on==0` 才清 | drain 完整等待。 |
| `PTW-SVA-BUSERR-001` | bus error response by ID 只产生 buserr path，不产生 normal writeback/cache update | bus error routing。 |

#### 8.4 新增 cover

| Cover | 目标 |
| --- | --- |
| `cp_lsu_req_id_all` | request ID 0..8 都被 fire。 |
| `cp_lsu_two_outstanding` | 同时至少两个不同 ID outstanding。 |
| `cp_lsu_max_pressure` | outstanding 数达到配置目标，建议至少 4，P1 覆盖 8/9。 |
| `cp_lsu_ooo_response` | response order 与 accept order 不同。 |
| `cp_lsu_grant_wait` | `req && !grant` 持续至少 2 拍后 fire。 |
| `cp_lsu_abort_drain_multi` | abort 时至少两个 `entry_on`，多个 response 后 drain exit。 |
| `cp_lsu_abort_before_grant` | held request 被 abort 取消。 |
| `cp_lsu_buserr_by_id` | bus error response id 命中非最老 outstanding。 |
| `cp_lsu_invalid_id_ignored` | invalid response ID negative cover。 |

### Phase 9: PDE cache/PPLRU SVA 增强

可以在 `mmu_pde_cache_sva.sv` 中扩展，也可以新增 `mmu_pde_pplru_sva.sv` bind 到 `PDE_cache`/`pplru`。

#### 9.1 连续 update assertion

| SVA ID | 规则 |
| --- | --- |
| `PTW-SVA-PDE-UPD-020` | `mbuf_cache_upd && $past(mbuf_cache_upd)` 时，本拍 update vector 仍 onehot 且非 X。 |
| `PTW-SVA-PDE-UPD-021` | 初始 invalid way 存在时，连续 update 不得重复上一拍已写 valid way。 |
| `PTW-SVA-PDE-UPD-022` | `L1PDE_entry_upd == plru_L1PDE_ref_num & {16{L1PDE_plru_refill_vld}}` 同拍成立。 |
| `PTW-SVA-PDE-UPD-023` | `L2PDE_entry_upd == plru_L2PDE_ref_num & {16{L2PDE_plru_refill_vld}}` 同拍成立。 |
| `PTW-SVA-PDE-UPD-024` | L1/L2 update vectors 互斥，除非设计明确允许不同 level 同拍。 |
| `PTW-SVA-PDE-UPD-025` | `ptw_abort_drain -> !mbuf_cache_upd`。 |
| `PTW-SVA-PDE-UPD-026` | bus error response 当拍/后一拍不产生 `mbuf_cache_upd`。 |

#### 9.2 PLRU bind assertion

如果 bind 到 `pplru`：

```systemverilog
plru_write_updt |-> (plru_PDE_ref_num == onehot(write_num))
```

并覆盖：

1. all invalid -> way0。
2. way0 valid -> next invalid way1。
3. way0/1 valid -> next invalid way2。
4. full valid -> PLRU way。

#### 9.3 PDE update monitor/SB check

在 monitor 中已经采样：

```text
pde_cache_update
pde_cache_update_level
pde_l1_update_vec
pde_l2_update_vec
```

需要新增软件检查：

1. 连续 update 的 `update_vec` 都非零。
2. cache 未满时第二拍 update 不应复用第一拍 way。
3. observed update payload 与 predicted non-leaf response 顺序匹配。
4. abort drain response 不得出现在 update event 中。

### Phase 10: directed base helper 和 sequences 扩展

修改 `ptw_source_directed_base.svh` 或现有 stage base，新增 helper：

```systemverilog
ptw_mem_grant_delay_by_count(count, cycles)
ptw_mem_grant_delay_by_id(id, cycles)
ptw_mem_response_delay_by_id(id, cycles)
ptw_mem_response_order_ooo()
ptw_mem_force_next_response_id(id)
ptw_mem_bus_error_by_id(id)
ptw_expect_lsu_req_id(id, addr)
ptw_expect_lsu_rsp_id(id)
ptw_expect_abort_drain_no_update(window)
ptw_expect_pde_consecutive_update(level, count)
```

修改 `ptw_mem_sequences.svh`：

1. `ptw_mem_normal_rsp_seq`：默认 ID echo。
2. `ptw_mem_slow_rsp_seq`：允许多 outstanding，不阻塞 accept。
3. `ptw_mem_ooo_rsp_seq`：从 obsolete/illegal 改为合法 ID-based OOO sequence。
4. `ptw_mem_bus_error_inject_seq`：支持 by id/by addr。
5. 新增 `ptw_mem_grant_backpressure_seq`。
6. 新增 `ptw_mem_abort_drain_rsp_seq`。
7. 新增 `ptw_mem_invalid_rsp_id_negative_seq`，只放 P2 illegal/negative list。

### Phase 11: 修改旧 PTW-LSU protocol tests

旧 tests 不应直接删除，建议保留 wrapper 名以免 regression list 断裂，但 metadata/expected 必须更新：

| 旧 test | 新处理 |
| --- | --- |
| `test_pmbuf_serial_outstanding_001` | 改名或重定向为 `test_pmbuf_multi_outstanding_id_001`；expected 从 single outstanding 改为 two-or-more outstanding legal。 |
| `test_pmbuf_no_tag_001` | 改为 `test_pmbuf_req_resp_id_basic_001`；expected 检查 request ID echo/response ID route。 |
| `test_pmbuf_inorder_resp_001` | 保留为 in-order legal subset，但不再检查必须 in-order；新增 OOO test 才是核心。 |
| `test_pmbuf_addr_stable_001` | 扩展为 `addr/id/size stable until grant`，不是 stable until response。 |
| `test_pmbuf_ptr_hold_001` | 扩展为 grant backpressure 下 `req_hold_ptr` 保持，并验证 grant 后切换。 |
| `test_mbuf_ooo_response` | 从 obsolete illegal stress 重新审查：旧 “无 tag OOO illegal” 删除；新合法 OOO-by-ID 可以新建 test，旧 wrapper 可改为 compatibility alias。 |

每个 wrapper 需要更新：

```text
p11_trace_id
p11_seq_desc
p11_checker
p11_status
ptw_meta_add_req(...)
```

### Phase 12: 新增 directed tests

建议新增 `mmu_verification/testbench/test/ptw_lsu_protocol_tests/` 下 tests：

| Test | Priority | 关闭目标 |
| --- | --- | --- |
| `test_pmbuf_req_resp_id_basic_001` | P0 | 单笔 request ID 等于 entry index，response ID echo，data 正确 route。 |
| `test_pmbuf_multi_outstanding_id_001` | P0 | 至少两个不同 ID 同时 outstanding。 |
| `test_pmbuf_ooo_response_by_id_001` | P0 | 后 grant 的 ID 先 response，两个 source completion 均正确。 |
| `test_pmbuf_grant_hold_addr_id_001` | P0 | grant 延迟期间 addr/id/size 稳定，未 grant 不置 on。 |
| `test_pmbuf_abort_before_grant_cancel_001` | P0 | held request abort 前未 grant，不进入 outstanding，不要求 response。 |
| `test_pmbuf_bus_error_route_by_id_001` | P0 | bus error response 按 ID 只影响对应 entry/source key。 |
| `test_pmbuf_abort_drain_single_001` | P0 | abort 后单 outstanding data/error drain，无 TWU writeback/PDE update。 |
| `test_pmbuf_abort_drain_multi_001` | P0 | abort 时多个 `entry_on`，必须等全部 response 后 ready。 |
| `test_pmbuf_no_new_req_during_drain_001` | P0 | drain 期间 no create/no LSU req/no PDE update。 |
| `test_pmbuf_duplicate_id_blocked_001` | P1 | 同 entry on 期间不得再次 fire 同 ID。 |
| `test_pmbuf_invalid_rsp_id_ignored_001` | P2 negative | response ID 9..15 不影响任何 entry。 |
| `test_pde_consecutive_l1_update_plru_001` | P0 | L1 PDE 连续两拍 update 写不同当前 way。 |
| `test_pde_consecutive_l2_update_plru_001` | P0 | L2 PDE 连续两拍 update 写不同当前 way。 |
| `test_pde_consecutive_mixed_update_001` | P1 | L1/L2 back-to-back update 互不污染。 |
| `test_pde_abort_drain_no_update_001` | P0 | abort drain response 是 non-leaf PTE 也不得 update PDE。 |
| `test_pmbuf_random_id_ooo_stress_001` | P1 | grant stall、OOO response、multi-outstanding/PTW pressure 随机交叉；bus error 由 P0 directed 覆盖。 |

#### 12.1 directed test 通用结构

每个 test 必须：

1. 使用 mapped Sv39 page table，避免随机 page fault 掩盖 PTW-LSU 协议。
2. 开启 source side:

```text
+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
```

3. 明确配置 responder mode。
4. 打印 metadata：

```text
PTW_META req_ids=...
PTW_SOURCE_SB_LSU_ID_COVERAGE ...
PTW_SVA_COVER module=mmu_ptw_lsu_protocol_sva ...
```

5. P0 tests 不使用 invalid ID 或 duplicate response negative stimulus。

#### 12.2 multi outstanding stimulus 要点

构造方式：

1. 使用多个 LSU/IFU/PFU source request 或 directed PTW thrash，使多个 TWU 发出 page-table read。
2. Responder 对第一批 request 延迟 response，但继续 grant 后续 request。
3. 观察 `ptw_mbuf_entry_on` 至少两个 bit 为 1。
4. 指定 response order：例如 `id=3` 先于 `id=0` 返回。
5. 检查每个 source key 的 completion 与 PTE 对应。

#### 12.3 abort drain stimulus 要点

构造方式：

1. grant 两笔 request，延迟 response。
2. 触发 `tlboper_ptw_abort`。
3. 在 drain 期间尝试产生新 PTW request source pressure。
4. Responder 依次返回两个 response ID。
5. 检查：
   - `entry.vld` abort 当拍清。
   - `entry.on` response 前保持。
   - response 清对应 `on`。
   - `ptw_jtlb_ready` drain 期间低。
   - no `mbuf_cache_upd`。
   - drain 结束后新 request 才可进入。

#### 12.4 PDE consecutive update stimulus 要点

构造方式：

1. 准备两个不同 VPN 的 first-level 或 second-level non-leaf PTE。
2. 通过 responder 让两个 writeback grant 连续发生，形成连续 `mbuf_cache_upd`。
3. 初始 clear PDE cache，保证 invalid entries 存在。
4. 检查 update vector：
   - cycle N: way0。
   - cycle N+1: way1。
   - 不允许第二拍仍写 way0。
5. 对 L1/L2 分别覆盖；mixed case 覆盖 back-to-back level 切换。

#### 12.5 新增/修改测试点完整矩阵

本节用于把本次 UVM 计划需要新增或修改的测试点一次性列全。测试点 ID 建议同步写入 `ptw_source_closure_matrix.csv`，并在最终更新 `doc/MMU_Traceability_Matrix.csv` 时保持一致。P0/P1 normal regression 不允许使用 invalid response ID 或 duplicate response 等非法 LSU stimulus；这类 negative stimulus 只能放入 P2/illegal list。

##### 12.5.1 旧测试点修改清单

| 测试点 ID | 修改对象 | 旧语义 | 新语义/任务 | 必须证据 |
| --- | --- | --- | --- | --- |
| `MOD-LSU-001` | `test_pmbuf_serial_outstanding_001` | single outstanding 必须成立。 | 改成 multi-outstanding-by-ID legal，或作为 compatibility alias 指向 `test_pmbuf_multi_outstanding_id_001`。 | `cp_lsu_two_outstanding` 命中；`mmu_credit_sb` peak PTW outstanding > 1；无 duplicate same ID。 |
| `MOD-LSU-002` | `test_pmbuf_no_tag_001` | PTW-LSU 无 tag。 | 改成 request ID/response ID basic route。 | request fire 时 `req_id==mbuf_entry_index`；response `rsp_id` 只更新对应 entry。 |
| `MOD-LSU-003` | `test_pmbuf_inorder_resp_001` | response 必须 in-order。 | 保留为 legal in-order subset；不能再作为约束。 | log/gate 中无 `sva_response_inorder` closure marker；OOO test 单独关闭。 |
| `MOD-LSU-004` | `test_pmbuf_addr_stable_001` | addr stable until response。 | 改成 addr/id/size stable until grant 或 abort cancel。 | `grant_wait>=2`；`PTW-SVA-GRANT-001` 通过。 |
| `MOD-LSU-005` | `test_pmbuf_ptr_hold_001` | old pointer hold checker。 | 改成 grant backpressure 下 `req_hold_ptr` hold/release。 | grant 前 selected ptr 不跳变；grant 后才能切换下一 entry。 |
| `MOD-LSU-006` | `test_mbuf_ooo_response` | 无 tag 场景下 OOO 是 illegal/stress。 | 改成合法 OOO-by-ID test；invalid ID 另放 P2 negative。 | `cp_lsu_ooo_response` 命中；source completion 与 `rsp_id` 对应。 |
| `MOD-LSU-007` | 所有依赖 `mmu_lsu_data_req_accept` 的 wrapper/checker | `accept` 作为旧 serial accept。 | 统一改成 `req && grant` fire。 | log 中打印 `req_fire`；新 checker 不再直接依赖 old whitebox accept。 |
| `MOD-LSU-008` | Phase 11 metadata/checker string | `strict_single_outstanding`、`NO_TAG` 等可作为关闭证据。 | metadata 改成新 requirement/testpoint ID。 | signoff gate 拒绝旧 marker。 |

##### 12.5.2 PTW-LSU ID/grant/multi-outstanding 测试点

| 测试点 ID | 优先级 | 建议 test | stimulus / 场景 | 必须检查 |
| --- | --- | --- | --- | --- |
| `LSUID-TP-001` | P0 | `test_pmbuf_req_resp_id_basic_001` | 单笔 page-table read，grant always ready。 | `req_id` 合法且等于 MBUF entry index；`rsp_id` echo。 |
| `LSUID-TP-002` | P0 | `test_pmbuf_req_resp_id_basic_001` | normal data response by ID。 | data 只 latch 到对应 entry；其它 entry `on/get/buserr` 不受影响。 |
| `LSUID-TP-003` | P1 | `test_pmbuf_req_id_sweep_001` | 触发 ID 0..8 全部发起 request。 | `req_id_mask==9'h1ff`；每个 ID 至少完成一次。 |
| `LSUID-TP-004` | P2 negative | `test_pmbuf_invalid_rsp_id_ignored_001` | LSU 返回 `rsp_id=9..15`。 | 不清任何 valid entry；不产生 visible completion；SVA no-side-effect 通过。 |
| `LSUID-TP-005` | P2 negative | `test_pmbuf_rsp_without_pending_001` | 合法范围 ID 但无 pending。 | monitor/SVA 报错；normal regression 不允许出现。 |
| `LSUID-TP-006` | P2 negative | `test_pmbuf_duplicate_rsp_id_001` | 同一 request 返回两次 response。 | 第二次 response 被 checker 捕获，不二次清 entry。 |
| `LSUGRANT-TP-001` | P0 | `test_pmbuf_grant_hold_addr_id_001` | `req=1, grant=0` 持续多拍。 | 未 grant 不计 outstanding、不置 `entry.on`。 |
| `LSUGRANT-TP-002` | P0 | `test_pmbuf_grant_hold_addr_id_001` | grant wait 期间有更高优先级 pending entry。 | `addr/id/size` 稳定；`req_hold_ptr` 不跳变。 |
| `LSUGRANT-TP-003` | P0 | `test_pmbuf_abort_before_grant_cancel_001` | held request 在 grant 前遇到 abort。 | 不创建 outstanding；后续不要求 response；无 source completion。 |
| `LSUGRANT-TP-004` | P1 | `test_pmbuf_grant_and_rsp_cross_001` | 某 ID response 与另一 ID request fire 同拍或相邻拍。 | monitor/responder 无 race；pending set 正确增删。 |
| `LSUMULTI-TP-001` | P0 | `test_pmbuf_multi_outstanding_id_001` | 延迟第一个 response，继续 grant 第二个 request。 | 至少两个不同 ID 同时 outstanding。 |
| `LSUMULTI-TP-002` | P1 | `test_pmbuf_max_outstanding_pressure_001` | 压到 4/8/9 个 outstanding。 | `count<=9`；不同 ID legal；peak 计数正确。 |
| `LSUMULTI-TP-003` | P1/P2 | `test_pmbuf_duplicate_id_blocked_001` | 同 entry `on` 未清时试图再次 fire 同 ID。 | SVA/checker 报 duplicate ID；normal P0 不出现。 |
| `LSUOOO-TP-001` | P0 | `test_pmbuf_ooo_response_by_id_001` | 后 grant 的 ID 先返回。 | `response_order != accept_order`；completion 按 `rsp_id` 匹配。 |
| `LSUOOO-TP-002` | P1 | `test_pmbuf_ooo_bus_error_by_id_001` | 非最老 outstanding 返回 bus error。 | bus error 只影响该 ID/source key。 |
| `BUSERR-TP-001` | P0 | `test_pmbuf_bus_error_route_by_id_001` | legal bus error response by ID。 | expected access fault 的 source key 来自 request fire map。 |
| `BUSERR-TP-002` | P1 | `test_pmbuf_bus_error_data_vld_rule_001` | 覆盖最终冻结的 `bus_error/data_vld` 同拍规则。 | SVA 与 ref model 对 bus error qualifier 一致。 |

##### 12.5.3 abort drain、source-side 和下游 consumer 测试点

| 测试点 ID | 优先级 | 建议 test | stimulus / 场景 | 必须检查 |
| --- | --- | --- | --- | --- |
| `ABDRN-TP-001` | P0 | `test_pmbuf_abort_drain_single_001` | 单 outstanding 后触发 abort。 | abort 当拍清 `vld/get`，不清 `on`；response 后清对应 `on`。 |
| `ABDRN-TP-002` | P0 | `test_pmbuf_abort_drain_multi_001` | 多 outstanding 后触发 abort。 | drain 结束条件是所有 `entry_on==0`，不是第一笔 response。 |
| `ABDRN-TP-003` | P0 | `test_pmbuf_no_new_req_during_drain_001` | drain 期间持续施加 source pressure。 | no new MBUF entry；no new LSU req；`ptw_jtlb_ready` 不接收。 |
| `ABDRN-TP-004` | P0 | `test_pde_abort_drain_no_update_001` | abort drain response 返回 non-leaf PTE。 | 不产生 `mbuf_cache_upd`；PDE model 不 update。 |
| `ABDRN-TP-005` | P1 | `test_pmbuf_abort_drain_buserr_001` | abort drain 期间返回 bus error。 | 只清对应 `on`；不产生 visible access fault。 |
| `ABDRN-TP-006` | P1 | `test_pmbuf_abort_then_new_walk_001` | drain 完成后再发新 source request。 | drain 完成前拒绝新建；完成后能正常接收。 |
| `SRCID-TP-001` | P0 | `test_pmbuf_bus_error_route_by_id_001` | 多 source pending 下 bus error by ID。 | ref model 不再用 `m_pending.num()==1` 推断 source。 |
| `SRCID-TP-002` | P0 | `test_pmbuf_ooo_response_by_id_001` | 多 source + OOO response。 | `{type,id,vpn}` 与 MBUF ID 映射稳定。 |
| `SRCID-TP-003` | P0 | `test_pde_direct_accerr_no_extra_lsu_001` | PDE direct accerr 后仍有其它 ID outstanding。 | no-extra-LSU 只按同 source key 检查。 |
| `SRCID-TP-004` | P1 | `test_pde_direct_accerr_overlap_sources_001` | 一个 source direct accerr，另一个 source 合法 walk。 | 不同 source key 的 request 不误报。 |
| `CREDIT-TP-001` | P0 | `test_pmbuf_multi_outstanding_id_001` | PTW outstanding > 1。 | `mmu_credit_sb` 不报 old overflow；peak/id_mask 正确。 |
| `CREDIT-TP-002` | P1 | `test_pmbuf_max_outstanding_pressure_001` | peak outstanding 接近 9。 | `count<=9`；end-of-test drain 为 0。 |
| `LOG-TP-001` | P0 | all P0 PTW-LSU tests | scenario_db 记录 PTW mem req/rsp。 | log 含 `req_id/rsp_id/grant_wait/ooo/abort_drain/source_key`。 |
| `PERF-TP-001` | P1 | stress/regression | perf monitor 汇总 PTW req/rsp。 | report 含 peak outstanding、OOO count、max grant wait、abort drain count。 |

##### 12.5.4 PDE consecutive update / PLRU 测试点

| 测试点 ID | 优先级 | 建议 test | stimulus / 场景 | 必须检查 |
| --- | --- | --- | --- | --- |
| `PDEUPD-TP-001` | P0 | `test_pde_consecutive_l1_update_plru_001` | L1 两拍连续 non-leaf update，cache 初始 invalid。 | cycle N 写 way0，cycle N+1 写 way1；不复用上一拍 way。 |
| `PDEUPD-TP-002` | P0 | `test_pde_consecutive_l2_update_plru_001` | L2 两拍连续 non-leaf update，cache 初始 invalid。 | L2 update vector 同拍 onehot，way 跟本拍 PLRU。 |
| `PDEUPD-TP-003` | P1 | `test_pde_consecutive_mixed_update_001` | L1->L2、L2->L1 back-to-back。 | 两个 level 的 update vector 互不污染。 |
| `PDEUPD-TP-004` | P1 | `test_pde_full_valid_plru_replace_001` | PDE cache full valid 后连续 refill。 | replacement way 使用本拍 `write_num/ref_num`，不是上一拍。 |
| `PDEUPD-TP-005` | P0 | `test_pde_abort_drain_no_update_001` | abort drain late data 是 non-leaf。 | no `mbuf_cache_upd`；no L1/L2 update vec。 |
| `PDEUPD-TP-006` | P0 | `test_pmbuf_bus_error_route_by_id_001` | bus error response 命中 non-leaf 地址。 | bus error 不触发 PDE update。 |
| `PDEUPD-TP-007` | P1 | `test_pde_leaf_fault_no_update_001` | THD leaf、page fault、access fault response。 | leaf/fault 均不 update PDE cache。 |
| `PDEUPD-TP-008` | P1 | `test_pde_update_payload_match_001` | 连续 update 带不同 vpn/ppn/pmpflg。 | observed payload 与 predicted non-leaf response 顺序匹配。 |
| `PDEUPD-TP-009` | P0 | SVA cover + P0 tests | update vector 规则。 | L1/L2 update onehot0；update 时 onehot；互斥规则满足。 |
| `PDEUPD-TP-010` | P1 | `test_pde_invalid_way_sweep_001` | invalid way 从 way0 到 way15 逐步填充。 | first-invalid 选择顺序覆盖。 |

##### 12.5.5 regression、coverage 和 signoff 测试点

| 测试点 ID | 优先级 | 覆盖位置 | 要求 | 退出标准 |
| --- | --- | --- | --- | --- |
| `COV-LSUID-001` | P0 | `ptw_mem_covergroups` / `ptw_source_sb` | request ID、response ID mask。 | P0/P1 aggregate 中 `req_id_mask` 和 `rsp_id_mask` 覆盖目标达成。 |
| `COV-LSUID-002` | P0 | SVA cover | two outstanding、OOO response、grant wait。 | `cp_lsu_two_outstanding`、`cp_lsu_ooo_response`、`cp_lsu_grant_wait` 非零。 |
| `COV-ABDRN-001` | P0 | SVA/source SB | abort drain single/multi、no update。 | `cp_lsu_abort_drain_multi` 和 PDE no-update coverage 命中。 |
| `COV-PDEUPD-001` | P0 | PDE SVA/source SB | L1/L2 consecutive update。 | `PTW_SOURCE_SB_PDE_UPDATE_CONTIG_COVERAGE` 中 L1/L2 非零。 |
| `REG-LIST-001` | P0 | `ptw_p0_smoke_list` | 加入 basic ID、OOO by ID、abort drain 代表测试。 | smoke list 能覆盖主要协议风险。 |
| `REG-LIST-002` | P0 | `ptw_p0_list` | 加入所有 P0 ID/grant/abort/PDE tests。 | P0 list 无旧 single/no-tag expected。 |
| `REG-LIST-003` | P1 | `ptw_p1_list` | 加入 max pressure、mixed PDE、random stress。 | P1 list 覆盖压力和交叉场景。 |
| `REG-LIST-004` | P2 | `ptw_p2_illegal_list` | 隔离 invalid ID、response-without-pending、duplicate response。 | P2 negative 不混入 P0/P1。 |
| `GATE-TP-001` | P0 | signoff gate | 拒绝 old markers。 | `strict_single_outstanding`、`NO_TAG`、`sva_response_inorder` 不能作为 evidence。 |
| `GATE-TP-002` | P0 | signoff gate | 检查 required tests、coverage、SVA cover、negative isolation。 | gate 对新专项 regression pass。 |

##### 12.5.6 单个测试点关闭要求

每个 P0/P1 测试点关闭时至少要同时具备：

1. test metadata：`PTW_META` 中列出 testpoint ID、requirement ID、responder mode、req/rsp ID 目标。
2. monitor evidence：`ptw_mem_monitor` 打印 `req_fire/req_id/rsp_id/accept_order/response_order`。
3. source evidence：`ptw_source_ref_model` 与 `ptw_source_sb` expected/actual match，无 source-key gap。
4. SVA evidence：相关 `PTW-SVA-LSUID`、`PTW-SVA-GRANT`、`PTW-SVA-ABDRN`、`PTW-SVA-PDE-UPD` 无 fail，必要 cover 命中。
5. coverage evidence：`PTW_SOURCE_SB_LSU_ID_COVERAGE` 或 `PTW_SOURCE_SB_PDE_UPDATE_CONTIG_COVERAGE` 中对应 counter 非零。
6. downstream evidence：`mmu_credit_sb` 无 old scalar overflow，scenario/perf log 字段与新 schema 一致。
7. regression hygiene：P0/P1 log 不含 old closure marker；P2 negative stimulus 只在 P2 list 出现。

### Phase 13: regression list 和 suite 更新

修改：

| 文件 | 修改 |
| --- | --- |
| `ptw_lsu_protocol_tests_suite.svh` | include 新 tests，旧 wrappers 更新 expected。 |
| `ptw_tests_suite.svh` | include PDE consecutive/abort drain tests。 |
| `simu/mmu_ptw_lsu_protocol_list` | 替换旧 single/no-tag/in-order tests 为新 P0/P1 tests。 |
| `simu/ptw_p0_smoke_list` | 加入 2-3 个代表 P0：basic ID、OOO by ID、abort drain。 |
| `simu/ptw_p0_list` | 加入全部 P0 PTW-LSU-ID/abort/PDE consecutive tests。 |
| `simu/ptw_p1_list` | 加入 random/stress/mixed consecutive tests。 |
| `simu/ptw_p2_illegal_list` | 加入 invalid ID/duplicate response negative tests。 |
| `simu/ptw_code_coverage_list` | 加入 ID/OOO/grant/abort/PDE update coverage tests。 |
| `simu/mmu_all_tests_list`、`mmu_v4_full_regression_list` | 删除或重定向旧过期 expected。 |

新增建议专项 list：

```text
mmu_verification/simu/ptw_lsu_id_grant_list
```

内容示例：

```text
test_pmbuf_req_resp_id_basic_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pmbuf_multi_outstanding_id_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pmbuf_ooo_response_by_id_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pmbuf_grant_hold_addr_id_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pmbuf_abort_drain_multi_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pde_consecutive_l1_update_plru_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
test_pde_consecutive_l2_update_plru_001 +EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV
```

### Phase 14: traceability matrix 更新

更新 `mmu_verification/simu/ptw_source_closure_matrix.csv` 和 `doc/MMU_Traceability_Matrix.csv`。

#### 14.1 修改旧 rows

| 旧 row/test | 当前 notes | 修改方向 |
| --- | --- | --- |
| `TC-GAP-PTW-005` | “LSU single outstanding/no tag/in-order；multi-response 不能建模为合法 OOO” | 改为 “ID/grant multi outstanding；OOO by ID legal；no-tag/in-order old expected obsolete”。 |
| `test_pmbuf_serial_outstanding_001` | single outstanding | 改为 multi outstanding by ID。 |
| `test_pmbuf_no_tag_001` | no tag | 改为 req/resp ID echo。 |
| `test_pmbuf_inorder_resp_001` | response in-order | 改为 in-order subset；新增 OOO closure。 |
| `TC-GAP-PTW-008` | abort/buserr split | 细化为 abort drain with ID response。 |
| `PDE-TP-008` | abort returned nonleaf no update | 扩展为 abort drain late response no update。 |
| `PDE-TP-012` | PLRU P1/P2 precision | 增补 consecutive update same-cycle PLRU way。 |

#### 14.2 新增 requirement IDs

建议新增：

| 新 requirement | 设计语义 | UVM 组件 | Directed test | SVA/Cover |
| --- | --- | --- | --- | --- |
| `PTW-LSU-ID-001` | request ID 等于 MBUF entry index | ptw_mem_monitor/SVA | `test_pmbuf_req_resp_id_basic_001` | `PTW-SVA-LSUID-001/003` |
| `PTW-LSU-ID-002` | response ID 路由 data 到对应 entry | responder/ref model/SB | `test_pmbuf_req_resp_id_basic_001` | `PTW-SVA-LSUID-004/005` |
| `PTW-LSU-ID-003` | response ID 路由 bus error 到对应 entry | ref model/SB | `test_pmbuf_bus_error_route_by_id_001` | `PTW-SVA-BUSERR-001` |
| `PTW-LSU-ID-004` | invalid response ID 无副作用 | negative monitor/SVA | `test_pmbuf_invalid_rsp_id_ignored_001` | `PTW-SVA-LSUID-006` |
| `PTW-LSU-GRANT-001` | 只有 req&&grant 才 fire | responder/monitor/SVA | `test_pmbuf_grant_hold_addr_id_001` | `PTW-SVA-GRANT-001/002` |
| `PTW-LSU-GRANT-002` | grant 前 addr/id/size 稳定 | monitor/SVA | `test_pmbuf_grant_hold_addr_id_001` | `PTW-SVA-GRANT-001` |
| `PTW-LSU-MULTI-001` | 不同 ID 多 outstanding 合法 | responder/SB | `test_pmbuf_multi_outstanding_id_001` | `cp_lsu_two_outstanding` |
| `PTW-LSU-MULTI-002` | response 可 OOO by ID | responder/ref model/SB | `test_pmbuf_ooo_response_by_id_001` | `cp_lsu_ooo_response` |
| `PTW-LSU-ABORT-001` | abort 不清 on，response 按 ID drain | monitor/ref model/SVA | `test_pmbuf_abort_drain_multi_001` | `PTW-SVA-ABDRN-001/005` |
| `PTW-LSU-ABORT-002` | drain 期间 no create/no req/no PDE update | probes/SVA/SB | `test_pmbuf_no_new_req_during_drain_001` | `PTW-SVA-ABDRN-002/003/004` |
| `PTW-LSU-ABORT-003` | abort before grant cancels held req | responder/monitor/SVA | `test_pmbuf_abort_before_grant_cancel_001` | `PTW-SVA-GRANT-003` |
| `PDE-UPD-020` | 连续 L1 update 使用本拍 PLRU way | PDE monitor/SVA | `test_pde_consecutive_l1_update_plru_001` | `PTW-SVA-PDE-UPD-020/022` |
| `PDE-UPD-021` | 连续 L2 update 使用本拍 PLRU way | PDE monitor/SVA | `test_pde_consecutive_l2_update_plru_001` | `PTW-SVA-PDE-UPD-020/023` |
| `PDE-UPD-022` | abort drain response 不更新 PDE | source SB/SVA | `test_pde_abort_drain_no_update_001` | `PTW-SVA-PDE-UPD-025` |

### Phase 15: signoff gate 更新

已扩展现有 `scripts/ptw_stage8_signoff_gate.py`，没有新增零散 signoff 脚本；`scripts/ptw_functional_gate_rules.json` 同步纳入 `ptw_lsu_id_grant_list` focused regression，并在 gate command 中传入 `--lsu-id-list` 和 `--lsu-id-seed`。

Gate 实现检查：

1. 新 required tests 都在 P0/P1/P2/focused 正确 list。
2. P0/P1/focused/P2 logs 与 closure matrix evidence 中没有旧口径 marker：
   - `strict_single_outstanding`
   - `NO_TAG`
   - `response_inorder required`
   - `sva_response_inorder`
   - `PTW-014-OBSOLETE-OOO` 作为 closure evidence
3. LSU-ID gate 打开时，P0/focused LSU-ID tests 有 `PTW_SOURCE_SB_LSU_ID_COVERAGE`。
4. aggregate SVA cover 命中 cover-capable req IDs；assertion-only IDs 通过 closure matrix row 和 clean log evidence 关闭，避免要求不存在的独立 cover counter。
5. `cp_lsu_two_outstanding` 和 `cp_lsu_ooo_response` 至少在专项 regression 中命中。
6. `no_extra_lsu_violation==0`。
7. PDE consecutive update coverage 非零。
8. invalid ID negative test 只允许出现在 P2/negative list，不得进入 P0/P1 normal regression。

## 6. 文件级修改清单

| 文件 | 操作 | 具体修改 |
| --- | --- | --- |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_if.sv` | modify | 增加 req_id、rsp_id、grant；重定义 request fire；更新 clocking block。 |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_txn.svh` | modify | 增加 ID/order/grant/abort-drain/source-key 字段和 enums。 |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_responder.svh` | rewrite | 从 single-slot blocking responder 改成 grant thread + ID outstanding response scheduler。 |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_monitor.svh` | rewrite | 从 single pending 改成 `pending_by_id[16]`；按 ID 匹配 response。 |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_sequences.svh` | modify/add | 增加 OOO-by-ID、grant backpressure、abort drain、invalid ID negative sequences。 |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_covergroups.svh` | modify | 增加 req_id/rsp_id/outstanding depth/OOO/grant wait/abort drain coverpoints。 |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | modify | 增加 PTW-LSU ID/grant/hold/drain/per-entry response decode/PDE PLRU probes。 |
| `mmu_verification/testbench/env/mmu_credit_sb.svh` | modify | 从 scalar PTW outstanding 改成 ID-indexed outstanding set，并更新 peak / timeout / banner 报告。 |
| `mmu_verification/testbench/env/ptw_scenario_db.svh` | modify | 打印 req_id/rsp_id/grant_wait/ooo/abort_drain/source key 的 scenario 日志。 |
| `mmu_verification/testbench/env/mmu_perf_mon.svh` | modify | 统计 PTW peak outstanding、OOO response、grant wait、abort latency。 |
| `mmu_verification/testbench/test/ptw_source_directed_base.svh` | modify | 增加 grant backpressure、OOO-by-ID、bus-error-by-ID 等 directed helper。 |
| `mmu_verification/testbench/top/tb_top.sv` | modify | 连接 DUT 新 top ports；更新 diag/timeout print；更新 old accept alias。 |
| `mmu_verification/testbench/env/ptw_source_types.svh` | modify | 增加 memory event fields 或新 txn；增加 coverage/debug names。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | modify | 采样 PTW-LSU ID/grant/drain events，向 source ref/SB 广播。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | modify | bus error/data response 改按 `rsp_id` 匹配 MBUF outstanding；abort drain no visible completion/no update。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | modify | no-extra-LSU 改 source-key scoped；新增 LSU ID coverage；新增 PDE consecutive coverage。 |
| `mmu_verification/testbench/top/mmu_ptw_lsu_protocol_sva.sv` | rewrite | 删除 single/no-tag/in-order assertions；新增 ID/grant/drain SVA。 |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | modify | 增加 abort-drain no update、consecutive update、same-cycle PLRU way assertions。 |
| `mmu_verification/testbench/top/mmu_ptw_top_sva.sv` | modify | 增加 `ptw_jtlb_ready` drain gate 与 completion/no-new-request 交叉检查。 |
| `mmu_verification/testbench/test/ptw_lsu_protocol_tests/*.svh` | modify/add | 更新旧 wrappers，新增 ID/grant/OOO/abort tests。 |
| `mmu_verification/testbench/test/ptw_tests/*pde*` | add/modify | 新增 PDE consecutive update/abort drain no update tests。 |
| `mmu_verification/simu/mmu_ptw_lsu_protocol_list` | modify | 更新专项 list。 |
| `mmu_verification/simu/ptw_p0_smoke_list`、`ptw_p0_list`、`ptw_p1_list`、`ptw_p2_illegal_list` | modify | 加入新 tests，隔离 negative invalid ID。 |
| `mmu_verification/simu/ptw_source_closure_matrix.csv` | modify | 新增 requirement rows，修改旧 obsolete rows。 |
| `doc/MMU_Traceability_Matrix.csv` | modify | 与 source closure matrix 同步 traceability。 |
| `mmu_verification/scripts/ptw_stage8_signoff_gate.py` | modify | 加入 LSU ID/grant/abort/PDE update signoff checks。 |
| `mmu_verification/scripts/ptw_functional_gate_rules.json` | modify | 纳入 `ptw_lsu_id_grant_list` focused regression，并同步 gate command 的 LSU-ID 参数。 |

## 7. 实施顺序和依赖

推荐顺序：

1. Phase 0：RTL/top port audit。
2. Phase 1：interface、tb_top、probe 连接。
3. Phase 2：transaction schema。
4. Phase 3：responder ID outstanding model。
5. Phase 4：monitor ID-aware model。
6. Phase 8：基础 SVA 先改到可编译，关闭明显协议错误。
7. Phase 6：source ref model 按 response ID matching。
8. Phase 7：scoreboard/coverage。
9. Phase 10：directed helper/sequences。
10. Phase 11：旧 tests 重新归属。
11. Phase 12：新增 directed tests。
12. Phase 9：PDE/PLRU SVA 和 tests 完整闭环。
13. Phase 13/14/15：list、matrix、gate。

不能提前关闭的事项：

1. 未完成 Phase 1 前，不能声明任何 ID/grant test closed。
2. 未完成 responder 多 outstanding 前，不能关闭 OOO response。
3. 未完成 source ref model ID matching 前，不能关闭 bus error by ID。
4. 未完成 abort drain SVA 前，不能关闭 abort drain。
5. 未完成 PDE consecutive SVA/coverage 前，不能关闭 PLRU 连续 update 修复。

## 8. 风险和处理策略

| 风险 | 表现 | 处理 |
| --- | --- | --- |
| RTL top ports 未同步 | UVM 无法连接 `req_id/rsp_id/grant` | Phase 0 标 blocker，同步 RTL top 后继续。 |
| responder 改成多线程后 race | grant/response 同拍采样不稳定 | 使用 clocking block，所有 drive 一拍脉冲；monitor 用同一 clocking edge 采样。 |
| source key 无法从 MBUF ID 找到 | bus error/refill expected 无法定位 | 增加 MBUF entry metadata probes；fallback 只标 probe gap，不关闭 P0。 |
| 旧 tests 名称误导 | regression 看似通过但关闭错误 spec | gate 拒绝 old marker；wrapper metadata 明确 obsolete/re-scoped。 |
| invalid ID negative 污染 P0 | normal regression 出现非法 LSU behavior | invalid ID 只在 P2 list；P0/P1 responder 默认禁止。 |
| abort drain response 与 reset drop 混淆 | scoreboard expected 错误 drop | 区分 `reset_drop`、`abort_source_drop`、`abort_drain_rsp`。 |
| PDE consecutive update 难稳定触发 | coverage 不收敛 | directed force two non-leaf writebacks with fixed response timing；必要时使用 whitebox cover 辅助。 |
| PLRU exact way 与 implementation 细节耦合 | SVA 过拟合 | P0 只检查同拍/non-overwrite；exact PLRU tree full replacement 放 P1。 |

## 9. 推荐验证命令

### 9.1 编译

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
```

### 9.2 单 test run_check

```bash
make -C mmu_verification run_check TEST_NAME=test_pmbuf_req_resp_id_basic_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_pmbuf_multi_outstanding_id_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_pmbuf_ooo_response_by_id_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_pmbuf_abort_drain_multi_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_pde_consecutive_l1_update_plru_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

### 9.3 专项 regression

```bash
make -C mmu_verification regress LIST=simu/ptw_lsu_id_grant_list REGRESS_MODE=run_check REGRESS_NAME=ptw_lsu_id_grant REGRESS_SEEDS="606 707" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
```

### 9.4 P0/P1 回归

```bash
make -C mmu_verification regress LIST=simu/ptw_p0_smoke_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_smoke_after_lsu_id REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1

make -C mmu_verification regress LIST=simu/ptw_p0_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_after_lsu_id REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1

make -C mmu_verification regress LIST=simu/ptw_p1_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p1_after_lsu_id REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
```

### 9.5 Signoff gate

```bash
cd mmu_verification
python3 scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list simu/ptw_p0_smoke_list \
  --p0-list simu/ptw_p0_list \
  --p1-list simu/ptw_p1_list \
  --pde-pmpflg-list simu/ptw_pde_pmpflg_list \
  --lsu-id-list simu/ptw_lsu_id_grant_list \
  --p2-list simu/ptw_p2_illegal_list \
  --random-list simu/ptw_random_list \
  --consumer-list simu/ptw_consumer_evidence_list \
  --log-dir output/ptw_functional_gate/logs \
  --p0-seed 606 \
  --p1-seed 606 \
  --stage7-seed 707 \
  --pde-pmpflg-seed "606 707" \
  --lsu-id-seed "606 707" \
  --consumer-seed 707 \
  --csv simu/ptw_source_closure_matrix.csv \
  --report ../doc/ptw_uvm_review/ptw_source_signoff_report.md \
  --legacy ../doc/ptw_uvm_review/ptw_legacy_test_action_list.md
```

## 10. 最终退出标准

本次 UVM 修改完成必须同时满足：

1. 新 RTL top ports 与 `ptw_mem_if` 连接完整。
2. `ptw_mem_responder` 支持 grant backpressure、多 outstanding、OOO response、bus error by ID。
3. `ptw_mem_monitor` 按 ID 匹配 request/response，report 中无 unmatched legal response。
4. `ptw_source_ref_model` 不再使用 “pending 唯一” 推断 bus error；bus error 按 response ID 映射到 source key。
5. `ptw_source_sb` no-extra-LSU 改为 source-key scoped。
6. `mmu_ptw_lsu_protocol_sva.sv` 不再包含 single-outstanding/no-tag/in-order 旧断言。
7. P0 tests 至少覆盖：
   - basic req/rsp ID。
   - two outstanding。
   - OOO response by ID。
   - grant wait stable。
   - bus error by ID。
   - abort drain multi outstanding。
   - PDE consecutive L1/L2 update。
8. P2 negative 单独覆盖 invalid response ID no side effect。
9. `PTW_SOURCE_SB_LSU_ID_COVERAGE` 中 `req_rsp_id_match`、`two_outstanding`、`ooo`、`grant_wait`、`abort_drain`、`buserr_by_id`、`invalid_id` 非零。
10. `PTW_SOURCE_SB_PDE_UPDATE_CONTIG_COVERAGE` 中 L1/L2 consecutive update 非零。
11. signoff gate 拒绝旧 obsolete marker 并通过新 required IDs。
12. `ptw_p0_smoke_list`、`ptw_p0_list`、`ptw_p1_list` 全部 run_check clean。

## 11. 不允许的关闭方式

以下方式不能作为本次变更关闭依据：

1. 只证明 consumer-side VA->PA/fault 正确。
2. 继续使用 old `strict_single_outstanding` 断言通过。
3. 把 OOO response 仍当 illegal stimulus。
4. 只看 `mmu_lsu_data_req`，不看 `lsu_mmu_data_req_grant`。
5. 只用 addr 匹配 response，不用 response ID。
6. abort 后直接删除 outstanding，不等待 response ID drain。
7. PDE consecutive update 只看 `mbuf_cache_upd`，不检查 update way/vector。
8. invalid response ID negative test 混入 P0/P1 normal regression。
9. 使用 hierarchical force 绕开缺失 top ports。

## 12. 推荐首个实现切入点

建议先做一个最小可编译闭环：

1. 在 `ptw_mem_if.sv`、`tb_top.sv`、`mmu_dut_probes_if.sv` 中接通 `req_id/rsp_id/grant`。
2. 将 responder 改成最简单的 ID outstanding：grant always ready，response in-order by ID echo。
3. 将 monitor 改成 `pending_by_id`。
4. 跑通 `test_pmbuf_req_resp_id_basic_001`。
5. 再打开 responder OOO mode，跑 `test_pmbuf_ooo_response_by_id_001`。
6. 最后接入 abort drain 和 PDE consecutive update。

这个顺序能最早暴露 top port、clocking block、transaction schema 的编译问题，避免在 source model 和 SVA 同时大改时难以定位基础协议错误。
