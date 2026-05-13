# PTW Test、SVA、Reference Model 与 Scoreboard 实现修改计划

本文档依据 `doc/ptw_uvm_review/ptwspec.md` 制定 PTW UVM 修改计划。目标不是重新写总体验证计划，而是把 PTW source-side 的 directed/random test 场景、testbench helper、monitor/probe、reference model、scoreboard、SVA、覆盖闭环和回归签核方式拆成可执行任务。

分阶段实施计划已独立维护在 `doc/ptw_uvm_review/ptw_staged_implementation_plan.md`。本文档只保留详细任务库，不重复维护阶段拆分内容。

本计划以 `ptwspec.md` 全文为唯一功能真值，包括 §0-§13.21 的正式规格、§14 的旧答案冲突收敛、§15 的原始澄清问答覆盖索引，以及 §16 的 `ptw_overview.md` 原文归档。若旧 verification plan、旧 test name、旧 SVA 名称、现有 reference model 或已有 expected behavior 与 `ptwspec.md` 冲突，一律按本文计划修改、拆分、删除、重归属或标记为 obsolete。

## 1. 总体范围

本计划必须覆盖以下内容：

1. PTW source-side 测试点的 test 场景实现，包括 stimulus、页表构造、CSR/PMP/sysmap 设置、请求类型、异常/回填期望、覆盖点和关闭条件。
2. PTW source-side SVA 的新增与增强，包括 bind 目标、信号依赖、断言语义、cover property、与 test 场景的闭环关系。
3. PTW source-side reference model 与 scoreboard，包括 `{type,id}` 事务匹配、PDE cache model、PMP/PTE/MAEE/sysmap/degrade/abort/drop golden result、report 和 end-of-test signoff。
4. 为 test、SVA、reference model 和 scoreboard 服务的 testbench 基础设施修改，包括 page table builder、PTW memory responder、PTW source monitor/probe、scenario metadata、回归列表和 coverage gate。
5. 现有 test 的保留、修改、拆分、删除或重归属策略。

本计划不修改 PTW RTL 功能逻辑。若实施时发现 SVA、monitor 或 scoreboard 需要只读内部信号，优先通过 `bind` 层级引用或 `mmu_dut_probes_if.sv` 暴露 probe；禁止为了验证而改动 DUT functional path。

## 2. 当前仓库锚点

### 2.1 已有 test 目录

| 目录 | 当前用途 | 处理计划 |
| --- | --- | --- |
| `mmu_verification/testbench/test/ptw_tests` | PTW smoke、PDE、PTE、xbar、arb、abort 相关 wrapper | 作为 PTW source-side 主目录；新增 directed tests，修改/拆分旧 PTW 测试。 |
| `mmu_verification/testbench/test/ptw_lsu_protocol_tests` | PTW MBUF/LSU protocol directed tests | 增强为 `MBUF-TP-*` 的主目录；补 bus error、CHK not ready、abort outstanding。 |
| `mmu_verification/testbench/test/pmp_twu_tests_v6` | PMP/TWU source-side tests | 保留并增强；补 level/type/effective privilege 矩阵。 |
| `mmu_verification/testbench/test/maee_twu_tests` | MAEE path tests | 保留并增强；补 1G/2M/4K all-size、THD 4K、MAEE 动态采样。 |
| `mmu_verification/testbench/test/sysmap_tests` | sysmap 和 phase13 degrade tests | 只把 PTW MAEE=0 leaf refill/degrade 相关项归入 PTW；system direct-map tests 重归属。 |
| `mmu_verification/testbench/test/l1dtlb_tests` | L1DTLB consumer-side tests | 仅作为 PTW consumer evidence；不能关闭 PTW source-side PTE/PMP/PDE/MAEE。 |
| `mmu_verification/testbench/test/tlbop_tests` | TLBOp/SFENCE/system invalidation tests | 只把 `tlboper_ptw_abort` 交叉行为映射到 PTW；L1/L2 invalidate 归 system。 |

### 2.2 已有 helper 与 sequence

| 文件 | 可复用能力 | 计划补充 |
| --- | --- | --- |
| `phase9_generated_test_base.svh` | 通用 bringup、sequence dispatch、4K map window | 新增或派生 PTW source-side base，避免每个 test 手写 bringup。 |
| `phase12_generated_test_base.svh` | PTW/PMP/MAEE/sysmap 压力 helper | 继续复用；新增 PTW source helper 和 scenario id 记录。 |
| `page_table_builder.svh` | `map_4k/2m/1g`、PTE storage、基础 fault injection | 增加 raw PTE、RSW、G、高保留位、misaligned huge PPN、指定 level leaf/non-leaf 构造 API。 |
| `ptw_mem_sequences.svh` | PTW memory responder delay、bus error、illegal PTE seq | 增加 deterministic bus error by address/count、CHK not-ready/slow response 支持、raw PTE 配置 seq。 |
| `cp0_sequences.svh` | SATP、priv、MXR/SUM、MPRV/MPP、MAEE、TLB all inv | 增加“使用点采样”场景 helper，或在 PTW source base 中组合已有 seq。 |
| `pmp_sequences.svh` | allow、deny fetch、deny rw、deny PFU、raw flg、deny PTW read | 继续复用；补按 PTW type/level 定位的 raw port 设置 helper。 |
| `sysmap_cfg_sequences.svh` | region/flag 配置 | 继续复用；补 PTW MAEE=0 degrade 专用 region 布局 helper。 |

### 2.3 已有 SVA

| 文件 | 当前状态 | 计划动作 |
| --- | --- | --- |
| `mmu_ptw_lsu_protocol_sva.sv` | 已有 single outstanding、地址稳定、response in-order | 增强 entry 分配、CHK not ready hold、bus error no CHK、abort same-cycle data/bus_error。 |
| `mmu_pmp_twu_sva.sv` | 已有 PMP grant/deny/type/MPRV 若干检查 | 增强 PTE PA 公式、level cover、deny 后 no lower side effect、fetch MPRV 不参与。 |
| `mmu_maee_twu_sva.sv` | 当前说明只覆盖 FST/SCD | 增强 THD/4K、MAEE=0 4K sysmap、MAEE=1 all-size direct refill。 |
| `mmu_sysmap_sva.sv` | 已有 flg substitution、cross degrade、PA align | 增强 1G->4K、no lower walk、flag order、misaligned before degrade。 |
| `mmu_arb_sva.sv` | 已有部分 arb 检查 | 增强 PTW output class priority、tag/data layout、type/id routing。 |
| `mmu_l1dtlb_sva.sv` | L1DTLB consumer-side 断言较完整 | 只新增 PTW consumer routing 交叉断言，不能替代 source-side。 |

### 2.4 必须新增的 SVA 文件

| 新文件 | bind 目标 | 关闭范围 |
| --- | --- | --- |
| `mmu_ptw_top_sva.sv` | `ptw` 或 `ct_mmu_top` 中 PTW 相关端口 | L2TLB->PTW ready/hold、type/id、PTW visible output class、abort 顶层边界。 |
| `mmu_pde_cache_sva.sv` | `PDE_cache`、`L1PDE_cache`、`L2PDE_cache` | PDE lookup/update/clear/double-hit/race/PLRU。 |
| `mmu_ptw_xbar_sva.sv` | `one_to_four_xbar` | VPN hash、target mask、backpressure payload hold、abort no dispatch。 |
| `mmu_twu_chk_sva.sv` | `twu` | PTE leaf/non-leaf/page fault、PFU 权限、G/RSW/flg、huge alignment、no lower walk。 |

所有新增 SVA 文件加入 `mmu_verification/testbench/Files.f` 的 SVA 段，并在对应文件内或统一 bind 文件中完成 bind。每个 P0/P1 assert 必须配套 `cover property` 或 covergroup bin。

### 2.5 全局常量、约束与非法输入

所有 test、monitor、SVA、reference model 和 scoreboard 必须使用同一套 type/page-size 常量，禁止在不同文件中手写不一致的 magic number。

```systemverilog
localparam logic [2:0] PTW_TYPE_LOAD  = 3'b010;
localparam logic [2:0] PTW_TYPE_FETCH = 3'b011;
localparam logic [2:0] PTW_TYPE_PFU   = 3'b100;
localparam logic [2:0] PTW_TYPE_STORE = 3'b110;

localparam logic [2:0] PTW_PGS_4K = 3'b001;
localparam logic [2:0] PTW_PGS_2M = 3'b010;
localparam logic [2:0] PTW_PGS_1G = 3'b100;
```

返回目标固定如下：

| type | 来源 | 成功 refill 目标 | 异常返回 |
| --- | --- | --- | --- |
| `PTW_TYPE_FETCH` | IUTLB/fetch | L1ITLB + L2TLB | L2TLB/fetch fault path；`id[2:0]` 无 L1D entry 语义。 |
| `PTW_TYPE_LOAD` | LSU load | L1DTLB + L2TLB | L2TLB/L1D fault path。 |
| `PTW_TYPE_STORE` | LSU store/atomic | L1DTLB + L2TLB | L2TLB/L1D fault path。 |
| `PTW_TYPE_PFU` | LSU pipe2 prefetch | L2TLB only | L2TLB/PFU fault path；不得触发 L1 refill。 |

以下输入默认约束不产生。若某 test 专门做 negative/illegal-stress，必须在 test name、scenario metadata 和 report 中标明，不得用于正常 PTW requirement closure。

1. Bare 模式请求进入 PTW。
2. 纯 M 态且不做地址翻译的请求进入 PTW。
3. sysmap 无命中或多命中。
4. IUTLB 多 outstanding。
5. DTLB miss buffer 超过 8 个 outstanding。
6. 同 `{type,id}` 未完成、未 drop 前复用。
7. PTW memory response out-of-order 或无 pending response。
8. satp.asid/satp.ppn 无 abort mid-walk 改变，除非专门验证该交错风险。

关闭 PTW source-side requirement 必须有 `ptw_source_ref_model + ptw_source_sb` match，或有等价 source-side monitor/SVA 直接证据并明确说明不能建模的原因。`mmu_translation_sb`、`mmu_l1dtlb_spec_sb` 和 L1/L2TLB SVA 只能作为 consumer-side evidence，不能替代 PTW source-side PTE/PMP/PDE/MAEE/MBUF/abort 检查。monitor-only match 在 source scoreboard 接入前可作为临时 smoke evidence，但最终 report 必须降级标注为 `provisional`，不能签核 P0/P1 requirement。

## 4. Testbench 基础设施修改计划

### 4.1 新增 PTW source directed base

新增文件：

```text
mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh
```

该 base 建议继承 `phase12_generated_test_base`，统一提供以下 API：

| API | 功能 |
| --- | --- |
| `ptw_src_setup_sv39(root_ppn, asid, maee, priv, mxr, sum, mprv, mpp)` | 配置 SATP、priv、MXR/SUM、MPRV/MPP、MAEE，并同步 PTW source ref model shadow。 |
| `ptw_src_set_pmp_ptw_ports(flg3, flg5, flg6, flg7)` | 设置四个 TWU PMP port raw flg。 |
| `ptw_src_set_pmp_allow_all()` | 恢复 PMP allow-all。 |
| `ptw_src_cfg_mem_rsp(min_delay, max_delay, bus_error_mode)` | 配置 PTW memory responder 延迟和 bus error 注入方式。 |
| `ptw_src_map_raw(level, va, pte_raw, parent_policy)` | 在 fst/scd/thd 指定 level 写 raw PTE，必要时自动构造父级 pointer。 |
| `ptw_src_map_leaf(level, va, ppn, pte_attr)` | 构造 1G/2M/4K leaf，允许 raw G、RSW、high reserved、扩展属性、misaligned PPN。 |
| `ptw_src_map_nonleaf(level, va, next_ppn, pte_attr)` | 构造合法或非法 non-leaf pointer。 |
| `ptw_src_drive_fetch(va)` | 通过 IFU 产生 fetch/IUTLB miss。 |
| `ptw_src_drive_load(va, pipe)` | 通过 LSU pipe0/pipe1 产生 load miss。 |
| `ptw_src_drive_store(va, pipe)` | 通过 LSU pipe0/pipe1 产生 store/atomic type miss。 |
| `ptw_src_drive_pfu(vpn)` | 通过 LSU pipe2 产生 PFU miss。 |
| `ptw_src_wait_quiescent(ctx)` | 等待 PTW/L1/L2 drain，失败时打印 PTW memory 和 credit debug。 |
| `ptw_src_expect(scenario_id, req_type, vpn, expected_kind, expected_fields)` | 向 source scoreboard 或 scenario logger 注册期望；最终以 source ref model 计算结果为准。 |

实现原则：

1. 所有 directed test 必须声明 `scenario_id`、`requirement_ids[]`、`expected_kind`。
2. 所有 PTE 类 test 必须显式声明 level、leaf/non-leaf、request type、PTE bit、CSR context。
3. 所有需要 PFU 的场景必须通过 `LSU_PIPE2` 或 `lsu_prefetch_pipe2_seq` 驱动，不能把 PFU 当 load。
4. 所有会触发 satp/PMP mid-walk 的场景必须写明是否允许无 abort 交错；普通 random 默认禁止该交错。

### 4.2 page table builder 增强

修改文件：

```text
mmu_verification/testbench/ptw_mem_agent/page_table_builder.svh
```

新增或公开以下能力：

| API | 说明 |
| --- | --- |
| `function pa_t calc_pte_addr(ppn_t ppn, logic [8:0] vpn_idx)` | 将当前 protected `_pte_addr` 公开给 directed test 和 source model。 |
| `function pte_t make_raw_pte(ptw_pte_attr_s attr)` | 支持 So/C/B/Sh/Sec、high reserved、RSW、D/A/G/U/X/W/R/V。 |
| `function void write_root_pte(va, pte)` | 指定 VPN[2] 写 fst PTE。 |
| `function void write_scd_pte(va, pte, bit auto_parent=1)` | 指定 VPN[2:1] 写 scd PTE，自动创建 fst pointer。 |
| `function void write_thd_pte(va, pte, bit auto_parent=1)` | 指定 VPN[2:0] 写 thd PTE，自动创建 fst/scd pointer。 |
| `function void map_1g_raw(va, pte)`、`map_2m_raw`、`map_4k_raw` | 不强制对齐和权限，允许构造负向 PTE。 |
| `function void inject_fault_at_level(va, level, fault_kind)` | 支持 `V_OFF`、`WRITE_ONLY`、`A_OFF`、`D_OFF`、`U_PAGE`、`S_PAGE`、`RSW_NONZERO`、`HIGH_RESERVED_NONZERO`、`G_NONLEAF`、`G_LEAF`、`MISALIGNED_1G`、`MISALIGNED_2M`、`X_ONLY`。 |

必须保留现有 `map_4k/2m/1g` 行为，以免破坏已有 tests。新增 raw API 用于 PTW source directed test。

### 4.3 PTW source monitor 与 scenario logger

monitor、scenario logger、reference model 和 scoreboard 按统一 schema 设计，可以分步落地，但最终签核必须全部接入：

1. `ptw_source_monitor` 捕获 PTW request、completion、refill tag/data、exception、memory channel、PDE update/clear、MAEE/sysmap path，用于 test 记录、SVA debug 和 scoreboard actual。
2. `ptw_source_ref_model` 使用 request/context/memory/PDE/abort 事件生成 expected。
3. `ptw_source_sb` 使用相同 transaction schema 做 `{type,id}` 匹配、字段比较、drop/no-output 检查和 report。

建议新增文件：

```text
mmu_verification/testbench/env/ptw_source_txn.svh
mmu_verification/testbench/env/ptw_source_monitor.svh
mmu_verification/testbench/env/ptw_scenario_db.svh
```

PTW source transaction 至少包含：

```text
tc_id
scenario_id
requirement_ids[]
request={accept_cycle,vpn,type,id,source}
context_samples={satp_ppn_cycle,asid_cycle,chk_priv_cycle,mxr,sum,mprv,mpp,maee}
pde={lookup_level,hit_l1,hit_l2,update_level,update_tag,update_ppn,clear_seen,clear_source}
levels[]={
  level,pte_addr,pmp_flg,pmp_deny,mem_req_cycle,mem_rsp_cycle,
  raw_pte,bus_error,leaf,page_fault,fault_kind,nonleaf_update
}
maee_sysmap={maee_at_leaf,sysmap_hits,sysmap_flg,degrade_from,degrade_to,final_ppn}
expected={kind,type,id,vpn,asid,page_size,ppn,global,flg,target,drop_reason}
actual={kind,type,id,vpn,asid,page_size,ppn,global,flg,target,refill_tag,refill_data}
result={matched,mismatch_field,waiver_id}
```

没有 `tc_id/scenario_id/requirement_ids` 的 match 只能计入 smoke，不得关闭具体测试点。没有 `levels[]` 的 match 只能证明最终输出，不得关闭 PTE PA、PMP level、PDE update、bus error 或 MAEE/degrade 类 requirement。

需要在 `mmu_dut_probes_if.sv` 和 `tb_top.sv` 补足的只读 probe：

| Probe | 用途 |
| --- | --- |
| `l2tlb_ptw_vpn` 或可由 L2MB entry 还原的 request VPN | source request expected key。 |
| `ptw_arb_ref_data_din` | flg/PPN bit layout 检查。 |
| `ptw_l2tlb_ref_data_vld` 或等价 refill visible class | 区分 normal refill。 |
| `tlboper_ptw_abort` | abort/drop 关联。 |
| PDE hit/update/clear tag/data/level/victim | PDE tests 和 SVA debug。 |
| TWU CHK raw PTE/level/type/id 或 mbuf return raw PTE | PTE/page fault/RSW/G/high reserved 直接证据。 |
| `regs_ptw_clr`、`pmp_regs_update` | satp/PMP clear-only 检查。当前 `tb_top` 顶层 `pmp_regs_update` 接 0，若 spec 要测 PMP config change 清 PDE，需要补可驱动路径或标记为 TB gap。 |

## 5. P0 Test 场景实现计划

P0 是必须优先落地的 directed tests。每个 P0 test 必须有明确的 source-side expected，并至少命中一个 P0 SVA cover 和一个 source scoreboard match；在 source scoreboard 尚未接入前，只能暂时记录为 monitor evidence，不能最终签核。

### 5.1 PTE/no-check/refill bit layout

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_pte_rsw_no_fault_flg_001` | `ptw_tests` | `PTW-AUD-001` | 构造 4K leaf，`RSW=2'b10`，权限合法，load/fetch/store 至少 load 一次。 | 不 page fault；normal refill；`flg[8:7]=RSW`。 | `PTW-SVA-CHK-009`、`PTW-SVA-ARB-008`、source scoreboard flg。 |
| `test_ptw_pte_high_reserved_ignored_001` | `ptw_tests` | `PTW-AUD-001` | 1G/2M/4K leaf 各一条，`PTE[58:38]` 非 0，权限合法。 | 不因 high reserved fault；回填字段正确。 | source scoreboard raw PTE 与 completion；禁止旧 `test_pte_reserved_bits` 期待 fault。 |
| `test_ptw_global_rsw_flg_layout_001` | `ptw_tests` | `PTW-AUD-002` | 组合 leaf G=1/0、non-leaf G=1、RSW 非 0；跑 miss 和 PDE hit 两条路径。 | `global=leaf.G`；non-leaf G 不 OR；G 不进入 data flg；RSW 进入 flg。 | `PTW-SVA-CHK-010`、`PTW-SVA-ARB-008`、refill tag/data bit decode。 |
| `test_ptw_refill_flg_bit_layout_001` | `ptw_tests` | `PTW-AUD-001/002/034` | MAEE=1 raw ext attr、MAEE=0 sysmap attr、RSW、D/A/U/X/W/R/V 全字段组合。 | `refill_data[41:14]=ppn`，`flg[13:9]={So,C,B,Sh,Sec}`，`flg[8:7]=RSW`，`flg[6:0]=D/A/U/X/W/R/V`。 | `PTW-SVA-ARB-008`、`PTW-SVA-MAEE-004`、source scoreboard。 |

旧 test 修改：

1. `test_pte_reserved_bits` 改为 positive no-fault test，删除 reserved/RSW fault expected。
2. `test_pte_global_bit_asid` 拆成 leaf global、non-leaf no-OR、G-not-in-flg 三个子场景。

### 5.2 Type/id、返回目标与 PFU

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_type_id_target_success_001` | `ptw_tests` | `PTW-AUD-003` | 同一页表窗口分别驱动 fetch、load、store、PFU miss；每条 id 不复用。 | fetch refill L1ITLB+L2；load/store refill L1DTLB+L2；PFU 只 refill L2。`type/id/vpn` 保持。 | `PTW-SVA-ARB-004..007`、`L1D-SVA-PTW-001`、source scoreboard target。 |
| `test_ptw_type_id_fault_target_001` | `ptw_tests` | `PTW-AUD-004` | 对 fetch/load/store/PFU 分别构造 page fault 和 access fault。 | 异常只携带原始 `type/id`；PFU fault 返回 L2/PFU 路径；IUTLB 低 3 bit 只保留字段，不当 L1D entry。 | `PTW-SVA-ARB-005..007`、L1D expt consumer SVA。 |
| `test_ptw_pfu_success_only_l2_001` | `ptw_tests` | `PTW-AUD-003/020` | `LSU_PIPE2` prefetch，合法 leaf。 | 成功只 refill L2TLB，不触发 L1D/L1I refill；PFU completion 释放 L2MB。 | `PTW-SVA-ARB-007`、`L1D-SVA-PTW-001`。 |
| `test_ptw_pfu_permission_matrix_001` | `ptw_tests` | `PTW-AUD-013` | PFU leaf 覆盖 `R=0`、`X=0`、`MXR=0/1`、`D=0`、`A=0`、U/S/SUM。 | PFU 不要求 R/MXR/X/D；仍要求 V、A、write-only、U/S、huge align。 | `PTW-SVA-CHK-006`、source scoreboard expected。 |

### 5.3 PDE cache 精确规则

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_pde_hit_level_matrix_001` | `ptw_tests` | `PTW-AUD-005` | 先 miss 填 PDE1/PDE2，再分别构造一级 hit、二级 hit、双 hit。双 hit 故意让一级/二级 PPN 不一致。 | 一级 hit 跳 fst；二级 hit 跳 fst/scd；双 hit 选二级，不校验一级一致性。 | `PTW-SVA-PDE-003/004/005`、memory channel 不出现被跳过级访问。 |
| `test_ptw_pde_update_condition_001` | `ptw_tests` | `PTW-AUD-006` | 非叶 no fault、leaf、非叶 page fault、PMP deny、LSU bus error、abort 返回非叶。 | 只有 non-leaf + no page fault + no bus error + 未 abort/drop 才 update。 | `PTW-SVA-PDE-006/007`、PDE monitor update log。 |
| `test_ptw_pde_lookup_update_race_001` | `ptw_tests` | `PTW-AUD-006` | 两个请求同 tag：第一个返回非叶 update 与第二个 lookup 同拍。 | 第二个 lookup 读旧值；update 下一拍才可命中。 | `PTW-SVA-PDE-008`、cover race 前件。 |
| `test_ptw_pde_clear_context_matrix_001` | `ptw_tests` | `PTW-AUD-007` | reset、satp write、PMP config update、tlboper abort 四类事件。 | reset/abort 清 PDE 并 flush；satp/PMP 只清 PDE，不 flush in-flight；旧 walk 可重新 update。 | `PTW-SVA-PDE-001/002/010`、`PTW-SVA-CTX-*`。 |
| `test_ptw_pde_plru_victim_001` | `ptw_tests` | `PDE-TP-012` | 填满 16 entry，命中若干 entry 后写入第 17 个。 | invalid first；无 invalid 时按 PLRU victim；hit/write 更新 PLRU。 | `PTW-SVA-PDE-009`、whitebox victim cover。 |

旧 test 修改：

1. `test_ptw_l1_pde_hit`、`test_ptw_l2_pde_hit_direct` 只能保留 smoke，新增 skip-level monitor check。
2. `test_pde_cache_l1_single_entry`、`test_pde_cache_l2_single_entry` 必须绑定 `PDE-TP-001..004/009/010`。
3. `test_pde_cache_clear_on_ptw_reset` 只关闭 reset clear，不关闭 satp/PMP clear-only 和 abort flush。

### 5.4 Xbar、ready/backpressure

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_xbar_hash_dispatch_001` | `ptw_tests` | `PTW-AUD-008` | 选择 VPN 覆盖 hash 到 TWU0/1/2/3。 | `xbar_twu_req` onehot 等于 `vpn[1:0]^vpn[10:9]^vpn[19:18]^vpn[26:25]`。 | `PTW-SVA-XBAR-001`。 |
| `test_ptw_xbar_target_mask_backpressure_001` | `ptw_tests` | `PTW-AUD-008` | 目标 TWU mask=1，非目标 mask=0。 | ready low；不派发到非目标；L2TLB valid/vpn/type/id 保持。 | `PTW-SVA-REQ-001`、`PTW-SVA-XBAR-002/006`。 |
| `test_ptw_xbar_nontarget_mask_no_block_001` | `ptw_tests` | `PTW-AUD-008` | 目标 TWU unmasked，非目标 masked。 | 当前请求可 accept，只派发到 hash 目标。 | `PTW-SVA-XBAR-003`。 |
| `test_ptw_xbar_abort_dispatch_block_001` | `ptw_tests` | `PTW-AUD-008/017` | xbar stall/dispatch 与 `tlboper_ptw_abort` 交叉。 | abort 当拍不得产生新 dispatch；未 accept 请求不建 expected。 | `PTW-SVA-XBAR-004`、`PTW-SVA-REQ-002`。 |

旧 test 修改：

1. `test_xbar_twu_round_robin` 删除 round-robin expected，改为 hash distribution 或标 `obsolete-by-spec`。
2. `test_xbar_1to4_distribution` 只保留 hash distribution，删除 idle-first/pointer fallback 口径。

### 5.5 PMP/TWU access fault 与 MPRV/MPP

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_pmp_level_deny_matrix_001` | `pmp_twu_tests_v6` | `PTW-AUD-009` | 分别构造 fst/scd/thd PTE PA PMP deny；每级覆盖 load/fetch/store/PFU 至少关键类型。 | access fault；无 mbuf/LSU/CHK/page fault/refill/PDE update。 | `PTW-SVA-PMP-003/004/008/009`。 |
| `test_ptw_pmp_original_type_perm_001` | `pmp_twu_tests_v6` | `PTW-AUD-010` | raw flg 组合：fetch deny X、load/PFU deny R、store deny W。 | PMP deny 使用原始 request type，不把 PTE read 统一当 load。 | `PTW-SVA-PMP-005/006`。 |
| `test_ptw_mprv_mpp_effective_priv_001` | `pmp_twu_tests_v6` | `PTW-AUD-011` | load/store/PFU 在 `MPRV=1 && MPP=M`，PMP flg L=0 且 R/W deny；fetch 同时真实 S/U。 | data/PFU effective M 跳过 deny；fetch 不用 MPRV，仍按真实 privilege。 | `PTW-SVA-PMP-007`、`PTW-SVA-CHK-007`。 |
| `test_ptw_pmp_deny_no_side_effect_001` | `pmp_twu_tests_v6` | `PTW-AUD-009` | PMP deny 后延长运行窗口并制造其他 refill/page fault。 | 被 deny 的 transaction 不产生 refill、page fault、PDE update 或 lower-level PMP。 | `PTW-SVA-PMP-003/009`、`PTW-SVA-PDE-007`。 |

### 5.6 PTE page fault 矩阵

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_nonleaf_fault_matrix_001` | `ptw_tests` | `PTW-AUD-012` | fst/scd/thd non-leaf；`V=0`；write-only；合法 pointer。 | fst/scd 合法 pointer 不 fault；thd non-leaf fault；`V=0` 和 write-only fault。 | `PTW-SVA-CHK-001/002/011`。 |
| `test_ptw_leaf_perm_fetch_load_store_001` | `ptw_tests` | `PTW-AUD-013` | fetch/load/store leaf 权限矩阵：X/R/W/MXR/A/D/U/S/SUM。 | 按 spec 公式产生 refill 或 page fault。 | `PTW-SVA-CHK-003/004/005/007`、source scoreboard expected。 |
| `test_ptw_write_only_mxr_x_matrix_001` | `ptw_tests` | `PTW-AUD-013` | `W=1,R=0,X=0/1,MXR=0/1` 交叉。 | `W && !(R || (MXR && X))` fault；`W=1,R=0,X=1,MXR=1` 不因 write-only fault。 | `PTW-SVA-CHK-001`。 |
| `test_ptw_us_sum_mprv_matrix_001` | `ptw_tests` | `PTW-AUD-013/021` | effective U/S/M，SUM=0/1，MPRV/MPP 切换。 | effective M 跳过 U/S；S 访问 U page 且 SUM=0 fault；U 访问 S page fault。 | `PTW-SVA-CHK-007`。 |
| `test_ptw_huge_align_before_degrade_001` | `sysmap_tests` 或 `ptw_tests` | `PTW-AUD-014` | MAEE=0，1G leaf `PPN[17:0]!=0`、2M leaf `PPN[8:0]!=0`，sysmap 设置为可跨区。 | 先 page fault；不进入 sysmap/degrade；不 refill；不 lower walk。 | `PTW-SVA-CHK-008`、`PTW-SVA-MAEE-008`。 |

旧 test 修改：

1. `test_ptw_l0_pte_permission_check` 拆成 fetch/load/store/PFU 权限矩阵。
2. `test_pte_rw_both_zero` 拆成合法 pointer、thd non-leaf、write-only、X-only。
3. `test_pte_x_bit_mxr_mix` 必须显式设置 MXR 和 expected，不能落到默认 `V_OFF`。
4. `test_pte_misaligned_ppn_1g/2m` 必须真实构造巨页 leaf 错位，expected 是 page fault 且 no sysmap/degrade。

### 5.7 MBUF、LSU bus error 与 abort

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_mbuf_entry_alloc_priority_001` | `ptw_lsu_protocol_tests` | `PTW-AUD-015` | IUTLB 与 DTLB/PFU 同拍竞争 mbuf；DTLB/PFU 多次写。 | fetch 用 entry8 且优先；DTLB/PFU 用 entry0-7，指针 one-hot 左移，不覆盖 valid。 | `PTW-SVA-MBUF-001/002`。 |
| `test_ptw_mbuf_chk_not_ready_hold_001` | `ptw_lsu_protocol_tests` | `PTW-AUD-016` | LSU normal data 返回时目标 CHK not ready。通过多 TWU/慢响应制造等待。 | entry 保存 data，置 get；ready 后只送一次；不重复发 LSU；其他 entry 可推进。 | `PTW-SVA-MBUF-006/007`。 |
| `test_ptw_lsu_bus_error_priority_001` | `ptw_lsu_protocol_tests` | `PTW-AUD-016` | deterministic bus error，与 TWU page fault/refill/access fault 并发。 | bus error 不进 CHK、不 page fault、不 refill、不 update PDE；access fault 优先。 | `PTW-SVA-MBUF-008/009`、`PTW-SVA-ARB-002`。 |
| `test_ptw_abort_lsu_outstanding_matrix_001` | `ptw_lsu_protocol_tests` | `PTW-AUD-017` | 子场景：abort 无 outstanding；abort 前一拍 req valid=1；abort 同拍 data；abort 同拍 bus error；已有异常寄存器 grant。 | 普通 data 丢弃；新 bus error 不上报；已有授权异常可见；normal refill/PDE update 被屏蔽；必要时保持 LSU req/PA 到返回。 | `PTW-SVA-MBUF-010/011/012`、`PTW-SVA-CTX-003..005`。 |

旧 test 修改：

1. `test_bus_error_terminate` 删除“所有 TWU 获得错误”口径，按原 mbuf entry `type/id` 上报 access fault。
2. `test_mbuf_ooo_response` 删除或标 `obsolete-by-spec`；PTW PTE channel 是 single outstanding，无合法 OOO。
3. `test_mbuf_full_backpressure` 重归属 upstream credit/no-overwrite，不关闭 PTW MBUF 功能。

### 5.8 MAEE、sysmap 与大页降级

| Test | 目录 | Requirement | 场景实现 | Expected | 必须检查 |
| --- | --- | --- | --- | --- | --- |
| `test_ptw_maee1_ext_attr_all_sizes_001` | `maee_twu_tests` | `PTW-AUD-018` | MAEE=1，1G/2M/4K leaf raw ext attr 各不相同。 | refill ext attr 来自 PTE[63:59]；不查 sysmap；不降级。 | `PTW-SVA-MAEE-001`、refill data flg。 |
| `test_ptw_maee0_4k_sysmap_refill_001` | `maee_twu_tests` 或 `sysmap_tests` | `PTW-AUD-019` | MAEE=0，THD 4K leaf，sysmap region flg 非默认。 | 4K 不降级但必须查 sysmap；ext attr 来自 sysmap。 | `PTW-SVA-MAEE-002/004`、THD cover。 |
| `test_ptw_maee0_1g_degrade_matrix_001` | `sysmap_tests` | `PTW-AUD-020` | 1G no-cross、1G->2M、1G->4K 三子场景。 | page_size/PPN 正确；不访问下一级页表；权限/G/RSW/A/D/U/X/W/R/V 来自原 1G leaf。 | `PTW-SVA-MAEE-005/006/007/010`。 |
| `test_ptw_maee0_2m_degrade_matrix_001` | `sysmap_tests` | `PTW-AUD-020` | 2M no-cross、2M->4K。 | page_size/PPN/flg 正确；不访问 thd；权限来自原 2M leaf。 | `PTW-SVA-MAEE-005/006/007`。 |
| `test_ptw_sysmap_flag_order_default_001` | `sysmap_tests` | `PTW-AUD-020` | region0/region7/默认 flg，MAEE=0 refill。 | ext attr 顺序固定 `{So,C,B,Sh,Sec}`；no-hit/multi-hit 若不支持则约束或 illegal。 | `PTW-SVA-MAEE-004`、`PTW-SVA-MAEE-010`。 |
| `test_ptw_context_sampling_points_001` | `ptw_tests` | `PTW-AUD-021` | request accept 后，在 PMP/CHK/refill/MAEE sysmap 入口前后改变 ASID/MXR/SUM/MAEE/MPRV/MPP。 | MXR/SUM/effective priv 在 CHK 使用点采样；ASID 在 refill 当拍采样；进入 MAEE=0 sysmap/degrade 后 MAEE 改变不回退。 | `PTW-SVA-ARB-009`、`PTW-SVA-MAEE-009`、source monitor context samples + source scoreboard compare。 |

旧 test 修改：

1. `test_mmu_twu_maee1_direct_refill` 扩展到 1G/2M/4K all sizes。
2. `test_mmu_twu_maee0_csr_path` 必须覆盖 THD/4K，不只 FST/SCD。
3. `test_sysmap_phase13_cross_1g_degrade` 必须区分 1G->2M 和 1G->4K。
4. `test_sysmap_hit_bypass_walk`、`test_sysmap_no_walk_required` 重归属 system direct-map，不关闭 PTW MAEE=0。

### 5.9 第 12 章完整流程签核

新增 umbrella test 或 scenario suite：

```text
test_ptw_full_flow_trace_001_023
```

建议不要写成单个巨大 UVM class，而是建立 23 个 `scenario_id`，由一个或多个 wrapper 分组执行：

| Flow | Scenario | Test 归属 |
| --- | --- | --- |
| `PTW-FLOW-001` | miss 1G success | `test_ptw_flow_success_pagesize_001` |
| `PTW-FLOW-002` | miss 2M success | `test_ptw_flow_success_pagesize_001` |
| `PTW-FLOW-003` | miss 4K success | `test_ptw_flow_success_pagesize_001` |
| `PTW-FLOW-004` | MAEE=0 1G->2M | `test_ptw_maee0_1g_degrade_matrix_001` |
| `PTW-FLOW-005` | MAEE=0 1G->4K | `test_ptw_maee0_1g_degrade_matrix_001` |
| `PTW-FLOW-006` | MAEE=0 2M->4K | `test_ptw_maee0_2m_degrade_matrix_001` |
| `PTW-FLOW-007` | MAEE=0 1G/2M no degrade | `test_ptw_maee0_*_degrade_matrix_001` |
| `PTW-FLOW-008` | MAEE=0 4K sysmap | `test_ptw_maee0_4k_sysmap_refill_001` |
| `PTW-FLOW-009..011` | fst/scd/thd PMP access fault | `test_ptw_pmp_level_deny_matrix_001` |
| `PTW-FLOW-012..014` | fst/scd/thd CHK page fault | `test_ptw_nonleaf_fault_matrix_001`、PTE matrix tests |
| `PTW-FLOW-015..017` | PDE hit final 2M/4K | `test_ptw_pde_hit_level_matrix_001` |
| `PTW-FLOW-018` | LSU bus error | `test_ptw_lsu_bus_error_priority_001` |
| `PTW-FLOW-019` | abort LSU outstanding | `test_ptw_abort_lsu_outstanding_matrix_001` |
| `PTW-FLOW-020` | PFU success | `test_ptw_pfu_success_only_l2_001` |
| `PTW-FLOW-021` | PFU exception | `test_ptw_pfu_permission_matrix_001`、PMP deny test |
| `PTW-FLOW-022` | satp/PMP clear PDE | `test_ptw_pde_clear_context_matrix_001` |
| `PTW-FLOW-023` | MPRV=1 && MPP=M | `test_ptw_mprv_mpp_effective_priv_001` |

每个 flow 关闭标准：directed test pass + source scoreboard expected match + 对应 SVA cover hit。只有 consumer-side pass 的 flow 状态为 `consumer-only`，不能签核。

## 6. P1/P2 Test 场景实现计划

P1 在 P0 之后实现，目的是补齐精度、交叉和压力。P2 用于约束/非法输入/随机回归质量。

| Test | Priority | 场景 | 关闭标准 |
| --- | --- | --- | --- |
| `test_ptw_pde_satp_old_walk_reupdate_001` | P1 | satp clear-only 后旧 in-flight non-leaf 返回并 update PDE。 | PDE clear cover + re-update cover + source scoreboard no drop。 |
| `test_ptw_pmp_cfg_clear_no_flush_001` | P1 | PMP config change 只清 PDE，不 flush in-flight。 | 若 `pmp_regs_update` 当前不可驱动，先标 TB gap；补驱动后关闭。 |
| `test_ptw_asid_refill_current_sample_001` | P1 | request accept 后改变 ASID，refill 当拍采样当前 ASID。 | `PTW-SVA-ARB-009` + source scoreboard tag ASID。 |
| `test_ptw_maee_mid_sysmap_change_001` | P1 | 进入 MAEE=0 sysmap/degrade 后切 MAEE=1。 | 当前请求仍走 sysmap/degrade，不回退 PTE attr。 |
| `test_ptw_random_pte_perm_cross_001` | P1 | constrained-random 覆盖 leaf/nonleaf 权限矩阵。 | PTE cover bins 全部命中，无 illegal id reuse。 |
| `test_ptw_same_id_no_reuse_constraint_001` | P2 | random constraint 检查同 `{type,id}` 未完成前不复用。 | constraint cover 或 illegal-stimulus checker。 |
| `test_ptw_bare_mode_no_request_constraint_001` | P2 | Bare/纯 M no-translation 下不向 PTW 发 request。 | assume/constraint cover；误入 PTW 只标 illegal，不算 DUT fail。 |

## 7. SVA 实现计划

### 7.1 总原则

1. SVA 只检查周期级协议、路由、字段保持、onehot/priority、abort/drop 边界、PDE 更新时序和不可发生事件。
2. 事务级 PTE/PMP/MAEE golden result 由 source ref model/scoreboard 关闭；source monitor 提供 actual/probe transaction，SVA 只保护关键 RTL 分支和协议。
3. 每个 P0/P1 assert 必须有 cover。assert pass 但 cover 未命中不能关闭测试点。
4. `tlboper_ptw_abort` 是被测功能，不能被全局放入所有 `disable iff`。只有普通稳定性断言可在 abort 时 disable。
5. 统一输出 cover report：

```text
PTW_SVA_COVER module=<module> name=<cover_name> hits=<N>
```

### 7.2 `mmu_ptw_top_sva.sv`

| SVA ID | Priority | 断言语义 | Cover |
| --- | --- | --- | --- |
| `PTW-SVA-REQ-001` | P0 | `l2tlb_ptw_req && !ptw_jtlb_ready` 时，`req/vpn/type/id` 保持到 ready 或合法 abort。 | stall 后 ready accept。 |
| `PTW-SVA-REQ-002` | P0 | abort outstanding 等待期间不提前 accept 新请求；ready 与 PDE/xbar ready 和 abort 状态一致。 | abort hold ready low。 |
| `PTW-SVA-REQ-003` | P0 | 每周期最多 accept 一个 PTW request。 | accept cover。 |
| `PTW-SVA-REQ-004` | P1 | accepted type 只能是 fetch/load/store/PFU。 | 四种 type cover。 |
| `PTW-SVA-REQ-005` | P1 | fetch/IUTLB request `id[2:0]` 固定 0 或被标 consumer ignored。 | fetch id cover。 |
| `PTW-SVA-ARB-001` | P0 | PTW visible class onehot0：refill/page fault/access fault 至多一种。 | 三类 class cover。 |
| `PTW-SVA-ARB-002` | P0 | 同周期 class priority：access fault > page fault > refill。 | conflict cover。 |
| `PTW-SVA-ARB-003` | P0 | abort flush 窗口不得产生 normal refill；已有授权异常按 spec 可见。 | abort refill blocked。 |
| `PTW-SVA-ARB-004` | P0 | `ptw_l2tlb_cmplt` 等于 refill/page/access visible OR。 | completion cover。 |
| `PTW-SVA-ARB-005` | P0 | output `type/id` 与被授权 refill/exception register payload 一致。 | type/id route cover。 |
| `PTW-SVA-ARB-006` | P0 | fetch/load/store/PFU 成功返回目标正确。 | 四 type target cover。 |
| `PTW-SVA-ARB-007` | P0 | PFU 不触发 L1I/L1D refill。 | PFU success cover。 |
| `PTW-SVA-ARB-008` | P0 | refill tag/data bit layout：valid/vpn/asid/page_size/global/ppn/flg。 | flg layout cover。 |
| `PTW-SVA-ARB-009` | P1 | refill ASID 使用 refill 当拍 active satp ASID。 | ASID changed before refill cover。 |

输入依赖：

```text
l2tlb_ptw_req, l2tlb_ptw_vpn, l2tlb_ptw_type, l2tlb_ptw_id, ptw_jtlb_ready
ptw_l2tlb_cmplt, ptw_l2tlb_type, ptw_l2tlb_id
ptw_l2tlb_ref_pgflt, ptw_l2tlb_ref_acc_err, ptw_l2tlb_ref_data_vld
ptw_arb_req, arb_ptw_grant, ptw_arb_vpn, ptw_arb_pgs
ptw_arb_ref_tag_din, ptw_arb_ref_data_din
ptw_l1itlb_cmplt, ptw_l1dtlb_cmplt, ptw_l1dtlb_id, tlboper_ptw_abort
```

### 7.3 `mmu_pde_cache_sva.sv`

| SVA ID | Priority | 断言语义 | Cover |
| --- | --- | --- | --- |
| `PTW-SVA-PDE-001` | P0 | reset、satp clear、PMP update、abort 后所有 PDE valid 下一拍为 0。 | 四类 clear source cover。 |
| `PTW-SVA-PDE-002` | P0 | abort 当拍屏蔽 `mbuf_cache_upd`，不得留下新 valid entry。 | abort + update same-cycle cover。 |
| `PTW-SVA-PDE-003` | P0 | L1/L2 双命中时选择 L2，L1 hit output 被抑制。 | double hit cover。 |
| `PTW-SVA-PDE-004` | P0 | hit_level 编码：miss/L1 hit/L2 hit 与 spec 一致。 | 三类 hit level cover。 |
| `PTW-SVA-PDE-005` | P0 | 命中输出 PPN 等于被命中 entry PPN，L2 优先。 | ppn match cover。 |
| `PTW-SVA-PDE-006` | P0 | `mbuf_cache_upd_lvl` 只更新对应级别，update vector onehot0。 | L1/L2 update cover。 |
| `PTW-SVA-PDE-007` | P0 | leaf/page fault/bus error/abort/drop 不产生 PDE update。 | negative cover。 |
| `PTW-SVA-PDE-008` | P0 | lookup/update 同拍同 tag 时 lookup 用旧值，新值下一拍才生效。 | race cover。 |
| `PTW-SVA-PDE-009` | P1 | invalid entry 优先，否则 PLRU victim；hit/write 更新 PLRU。 | victim cover。 |
| `PTW-SVA-PDE-010` | P1 | PDE entry 不携带 ASID/G/RSW/flg/permission；satp/PMP clear-only 后旧 walk 可重新 update。 | clear-only re-update cover。 |

实施注意：

1. `PDE_cache` 顶层若没有直接暴露 update source level、tag、data、victim，需要在 bind 中层级引用 `L1PDE_cache/L2PDE_cache` entry signal。
2. 若 PLRU 内部信号命名不稳定，P0 先关闭 functional PDE 行为；PLRU 放 P1。

### 7.4 `mmu_ptw_xbar_sva.sv`

| SVA ID | Priority | 断言语义 | Cover |
| --- | --- | --- | --- |
| `PTW-SVA-XBAR-001` | P0 | dispatch onehot 等于 `ptw_hash_onehot(PDE_xbar_vpn)`。 | hash 0/1/2/3 cover。 |
| `PTW-SVA-XBAR-002` | P0 | hash 目标 mask=1 时 ready=0 且不 dispatch。 | target mask cover。 |
| `PTW-SVA-XBAR-003` | P0 | 非目标 mask=1 不阻塞当前请求。 | non-target mask cover。 |
| `PTW-SVA-XBAR-004` | P0 | abort 当拍不得产生新 `xbar_twu_req`。 | abort dispatch cover。 |
| `PTW-SVA-XBAR-005` | P1 | 派发 payload `vpn/type/id/ppn/hit_level` 等于 PDE 输出。 | payload cover。 |
| `PTW-SVA-XBAR-006` | P1 | backpressure 期间 PDE_xbar payload 保持稳定直到 ready。 | hold cover。 |

旧 `round_robin` 检查全部废弃。若保留旧测试名，checker 必须改成 hash/ready-hold。

### 7.5 `mmu_pmp_twu_sva.sv` 增强

在现有文件上增加：

| SVA ID | Priority | 增强点 |
| --- | --- | --- |
| `PTW-SVA-PMP-008` | P0 | PTE PA 公式：fst=`{satp_ppn,vpn[26:18],3'b0}`，scd=`{parent_ppn,vpn[17:9],3'b0}`，thd=`{parent_ppn,vpn[8:0],3'b0}`。 |
| `PTW-SVA-PMP-009` | P1 | PMP pass 后才允许进入 mbuf；PMP wait/deny 期间不得产生 CHK/page fault。 |
| `PTW-SVA-PMP-010` | P1 | fst/scd/thd deny cover 按 level/type 分桶打印。 |

现有 `sva_pmp_deny_uses_original_type_perm`、`sva_pmp_fetch_matches_grant_stage`、`sva_pmp_deny_no_lsu_req` 保留，并绑定到 `PTW-AUD-009/010/011`。

### 7.6 `mmu_twu_chk_sva.sv`

| SVA ID | Priority | 断言语义 | Cover |
| --- | --- | --- | --- |
| `PTW-SVA-CHK-001` | P0 | `leaf=V&&(R||X)`；`write_only_fault=W&&!(R||(MXR&&X))`。 | leaf/write-only cover。 |
| `PTW-SVA-CHK-002` | P0 | fst/scd 合法 pointer 不 page fault；thd non-leaf 必 page fault。 | level cover。 |
| `PTW-SVA-CHK-003` | P0 | fetch leaf fault 公式。 | fetch fault/no-fault cover。 |
| `PTW-SVA-CHK-004` | P0 | load leaf fault 公式。 | load MXR/R cover。 |
| `PTW-SVA-CHK-005` | P0 | store leaf fault 公式。 | store W/D cover。 |
| `PTW-SVA-CHK-006` | P0 | PFU leaf fault 公式，不要求 R/MXR/X/D。 | PFU no-R/no-D cover。 |
| `PTW-SVA-CHK-007` | P0 | U/S/SUM/effective M 规则。 | U/S/M cover。 |
| `PTW-SVA-CHK-008` | P0 | 1G/2M PPN misaligned 先 page fault，不 sysmap/degrade/refill。 | misalign cover。 |
| `PTW-SVA-CHK-009` | P1 | high reserved 和 RSW 不参与 page fault。 | no-check cover。 |
| `PTW-SVA-CHK-010` | P1 | raw G 不进 data flg，只进 tag/global；非叶 G 不 OR。 | G cover。 |
| `PTW-SVA-CHK-011` | P0 | page fault 不产生 refill、PDE update 或下一级 PMP request。 | no side effect cover。 |
| `PTW-SVA-WAIT-001` | P0 | PMP request 未获 PMP grant、PMP pass 后 mbuf 未授权、PMP deny 后 access exception register 未授权时，对应 PMP stage valid/data 保持并拉 wait。 | PMP wait cover。 |
| `PTW-SVA-WAIT-002` | P0 | `fst_chk/scd_chk` 检出 non-leaf 且下一级 PMP wait 时，当前 CHK stage valid/data 保持，不重复消耗 mbuf data。 | lower PMP wait cover。 |
| `PTW-SVA-WAIT-003` | P0 | CHK 检出 leaf 且 MAEE=1，但 refill 寄存器/仲裁未授权时，当前 CHK stage valid/data/refill payload 保持。 | refill wait cover。 |
| `PTW-SVA-WAIT-004` | P0 | CHK 检出 page fault，但 page fault 寄存器未授权时，当前 CHK stage valid/data/fault payload 保持。 | page fault wait cover。 |
| `PTW-SVA-WAIT-005` | P0 | CHK 检出 MAEE=0 leaf，但跨页/sysmap 状态机不空闲或 CSR/sysmap 仲裁未授权时，当前请求保持，不误走 direct refill。 | sysmap wait cover。 |

输入依赖：

```text
fst/scd/thd_chk_vld
fst/scd/thd_chk_type/id/vpn/data
fst/scd/thd_chk_leaf_vld
fst/scd/thd_chk_page_flt
fst/scd/thd_chk_refill_req
fst/scd_chk_csr_req, csr_refill_req
scd/thd_pmp_vld request
cp0_mmu_mxr, cp0_mmu_sum, cp0_mmu_mprv, cp0_mmu_mpp, cp0_yy_priv_mode
PMP grant/wait, mbuf grant, refill/page/access register grant, sysmap/csr busy/grant
```

若 raw PTE 只在 mbuf return 点可见，CHK SVA 可以在 `mbuf_twu_data_vld` 到 CHK stage 之间打一拍 shadow，仅用于断言。

### 7.7 `mmu_ptw_lsu_protocol_sva.sv` 增强

| SVA ID | Priority | 增强点 |
| --- | --- | --- |
| `PTW-SVA-MBUF-001` | P0 | mbuf 写入 grant onehot0；fetch/IUTLB 同拍优先 entry8；DTLB/PFU 只 entry0-7。 |
| `PTW-SVA-MBUF-002` | P0 | abort 当拍不得 create 新 mbuf entry。 |
| `PTW-SVA-MBUF-006` | P0 | normal data + CHK ready 时，只向原 TWU/lvl 写回一次，payload 保持。 |
| `PTW-SVA-MBUF-007` | P0 | normal data + CHK not ready 时，entry hold/get，ready 后只写回一次，不重复 LSU。 |
| `PTW-SVA-MBUF-008` | P0 | bus error 不进 CHK、不 page fault、不 refill、不 PDE update，生成 access fault pending。 |
| `PTW-SVA-MBUF-009` | P0 | bus error access fault 在写异常寄存器/获 grant 前不丢失。 |
| `PTW-SVA-MBUF-010` | P0 | abort 前一拍 LSU req=1 时，保持 req/PA 到 response，普通 data 丢弃。 |
| `PTW-SVA-MBUF-011` | P0 | abort 同拍新 bus error 不上报。 |
| `PTW-SVA-MBUF-012` | P0 | abort 前已在异常寄存器且当拍获 grant 的异常可见。 |

现有 `a_single_outstanding`、`a_response_inorder`、`a_lsu_addr_stable_until_vld` 保留。

### 7.7.1 Refill、异常寄存器与仲裁 SVA

`ptwspec.md` §9 的仲裁和寄存器授权必须由 SVA/monitor 关闭，不能只靠 scoreboard 最终匹配。

| SVA ID | Priority | 断言语义 | Cover |
| --- | --- | --- | --- |
| `PTW-SVA-REG-001` | P0 | 每个 TWU 的 normal refill/page fault/access fault 寄存器已有 valid 且未被顶层仲裁接受时，新同类请求必须反压对应流水，保持 payload。 | register full wait cover。 |
| `PTW-SVA-REG-002` | P0 | TWU 内部 page/access/refill register 写入 payload 的 `type/id/vpn/page_size/ppn/flg/fault_class` 必须等于来源 stage。 | payload route cover。 |
| `PTW-SVA-REG-003` | P0 | TWU 内部通用优先级为 `IUTLB > thd > scd > fst`。 | priority conflict cover。 |
| `PTW-SVA-REG-004` | P0 | normal refill 内部优先级为 `IUTLB > 跨页检查状态机 > thd > scd > fst`。 | refill conflict cover。 |
| `PTW-SVA-REG-005` | P0 | 跨页检查状态机完成后若 refill 寄存器未授权，状态机/refill payload 必须保持到写入或 abort。 | degrade refill wait cover。 |
| `PTW-SVA-ARB-010` | P0 | 顶层 4 TWU 仲裁同类输出时，按 IUTLB/DTLB 分类和 TWU index 低优先规则授权，grant onehot。 | multi-TWU grant cover。 |
| `PTW-SVA-ARB-011` | P0 | 最终输出 class priority 固定为 `access fault > page fault > normal refill`；LSU bus error 在 access fault 源中优先于 4 个 TWU access fault。 | class conflict cover。 |

### 7.8 MAEE/sysmap SVA 增强

`mmu_maee_twu_sva.sv`：

| SVA ID | Priority | 增强点 |
| --- | --- | --- |
| `PTW-SVA-MAEE-001` | P0 | MAEE=1，1G/2M/4K leaf 均 direct refill，不进入 CSR/sysmap。 |
| `PTW-SVA-MAEE-002` | P0 | MAEE=0，1G/2M/4K leaf 均进入 sysmap/CSR；4K 也必须查 sysmap。 |
| `PTW-SVA-MAEE-003` | P0 | direct refill path 与 CSR/sysmap path mutex。 |
| `PTW-SVA-MAEE-009` | P1 | 进入 sysmap/degrade 后 MAEE 改变不回退。 |

`mmu_sysmap_sva.sv`：

| SVA ID | Priority | 增强点 |
| --- | --- | --- |
| `PTW-SVA-MAEE-004` | P0 | MAEE=0 refill ext attr 来自 `sysmap_mmu_flg[4:0]`，顺序 `{So,C,B,Sh,Sec}`。 |
| `PTW-SVA-MAEE-005` | P0 | 1G 跨 region 降级为 2M 或继续 4K；2M 跨 region 降级为 4K。 |
| `PTW-SVA-MAEE-006` | P0 | no-cross 不降级，page size 保持。 |
| `PTW-SVA-MAEE-007` | P0 | 降级只改 final PPN/page size/属性，不访问下一级页表。 |
| `PTW-SVA-MAEE-008` | P0 | misaligned huge PPN 先 page fault，不进入 sysmap/degrade。 |
| `PTW-SVA-MAEE-010` | P1 | `mmu_sysmap_pa*` 等于 adder PA `[39:12]`，四个 TWU 均覆盖。 |

### 7.9 L1DTLB consumer-side SVA

在 `mmu_l1dtlb_sva.sv` 增加或确认：

| SVA ID | Priority | 断言语义 | 用途 |
| --- | --- | --- | --- |
| `L1D-SVA-PTW-001` | P0 | `ptw_l1dtlb_ref_pa_vld` 只允许 load/store type install；PFU/fetch 不写 L1D。 | PFU only L2 evidence。 |
| `L1D-SVA-PTW-002` | P0 | PTW completion `id[2:0]` 必须命中 WFC/WFI 或 exception entry；stale id 不 install/consume。 | consumer-side id evidence。 |
| `L1D-SVA-PTW-003` | P0 | PTW page fault 与 access fault 写 expt CAM 互斥，fault class 不丢失。 | consumer fault evidence。 |
| `L1D-SVA-PTW-004` | P1 | L1D install payload 与 PTW source monitor/scoreboard 同 `{type,id}` refill 一致。 | 调试和 consumer cross-check。 |
| `L1D-SVA-PTW-005` | P1 | L1D fault replay terminal response，不重新分配新 PTW miss。 | consumer-only closure。 |

这些断言只作为 consumer evidence，不关闭 PTW source-side PTE/PMP/PDE/MAEE。

## 8. 现有 Test 修改、删除、重归属清单

| 旧 test | 动作 | 原因 |
| --- | --- | --- |
| `test_xbar_twu_round_robin` | 修改或删除 | spec 使用 VPN hash，不是 round-robin。 |
| `test_mbuf_ooo_response` | 删除或标 obsolete | PTW->LSU PTE channel single outstanding，无合法 OOO。 |
| `test_mbuf_full_backpressure` | 重归属 upstream credit/no-overwrite | PTW spec 不以 mbuf full backpressure 作为功能需求。 |
| `test_pte_reserved_bits` | 修改 | high reserved/RSW 不 fault，RSW 进 flg。 |
| `test_pte_rw_both_zero` | 拆分 | 合法 pointer、thd non-leaf、write-only、X-only 是不同 requirement。 |
| `test_pte_global_bit_asid` | 拆分 | leaf G、non-leaf G no-OR、G not in flg 分开关闭。 |
| `test_ptw_l0_pte_permission_check` | 拆分 | fetch/load/store/PFU 权限不同，PFU 不按 load。 |
| `test_sfence_abort_walk` | 拆分 | 改成 `tlboper_ptw_abort` 无 outstanding、有 outstanding、same-cycle data/bus_error、已有异常 grant。 |
| `test_satp_switch_during_walk` | 拆分 | satp 改变只清 PDE，不 flush in-flight；普通随机可约束不生成无 abort ASID/PPN 交错。 |
| `test_sysmap_hit_bypass_walk`、`test_sysmap_no_walk_required` | 重归属 | system direct-map，不关闭 PTW MAEE=0 leaf refill。 |
| L1DTLB busy/wakeup/MB tests | 重归属 | L1DTLB-owned；只做 consumer evidence。 |

### 8.1 Traceability 与旧 CSV ID 闭环

必须新增或更新 PTW closure mapping，建议输出为 markdown 表和可机读 CSV：

```text
doc/ptw_uvm_review/ptw_source_closure_matrix.md
mmu_verification/simu/ptw_source_closure_matrix.csv
```

每一行至少包含：

```text
legacy_id, audit_id, flow_id, test_name, scenario_id,
status, source_checker, sva_cover, consumer_evidence,
waiver_id, open_reason
```

处理规则：

1. `MMU_Traceability_Matrix.csv` 中原始 `PTW-*`、`F4/F4.NEW`、XBAR、MAEE/SysMap、PMP/PTW-PMP、L1DTLB/L2TLB/CSR/Perf 间接项必须映射到 `PTW-AUD-*`、`PTW-ADD-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*` 或 `PTW-FLOW-*`。
2. 与 `ptwspec.md` 冲突的旧 ID 不删除历史记录，而是标 `obsolete-by-spec`，并给出替代 scenario。
3. L1DTLB/L2TLB/CSR/Perf 间接 evidence 必须标 `consumer-only` 或 `auxiliary`；不能自动关闭 PTW source-side。
4. 每个 P0/P1 requirement 必须有 source checker 字段；没有 source checker 的行只能是 `open`、`waived` 或 `consumer-only`。
5. waiver 必须包含作用域、原因、替代 evidence 和预计关闭条件；禁止用全局 waiver 覆盖 `flg/page_size/ppn/fault_kind/target` mismatch。

### 8.2 新增测试点 ID 索引

| ID | 建议测试名 | 关闭范围 | Priority |
| --- | --- | --- | --- |
| `PTW-ADD-001` | `test_ptw_pte_rsw_no_fault_flg_001` | RSW 不 fault 且进入 flg。 | P0 |
| `PTW-ADD-002` | `test_ptw_pte_high_reserved_ignored_001` | `PTE[58:38]` 不 fault。 | P0 |
| `PTW-ADD-003` | `test_ptw_pte_g_leaf_only_001` | G 只进 tag/global，非叶 G 不 OR。 | P0 |
| `PTW-ADD-004` | `test_ptw_req_type_success_targets_001` | fetch/load/store/PFU 成功目标。 | P0 |
| `PTW-ADD-005` | `test_ptw_req_type_exception_targets_001` | 四类 type 的 page/access fault 返回。 | P0 |
| `PTW-ADD-006` | `test_ptw_return_priority_type_id_001` | access/page/refill priority、乱序按 `{type,id}` 匹配。 | P1 |
| `PTW-ADD-007` | `test_ptw_pde_cache_double_hit_l2_wins_001` | PDE 双命中选 L2。 | P0 |
| `PTW-ADD-008` | `test_ptw_pde_cache_lookup_update_race_001` | lookup/update 同拍读旧写新。 | P1 |
| `PTW-ADD-009` | `test_ptw_pde_cache_update_condition_001` | PDE update 条件。 | P0 |
| `PTW-ADD-010` | `test_ptw_pde_cache_satp_pmp_clear_no_abort_001` | satp/PMP clear-only no flush。 | P0 |
| `PTW-ADD-011` | `test_ptw_pde_cache_abort_reset_matrix_001` | reset/abort/PDE clear/flush 差异。 | P0 |
| `PTW-ADD-012` | `test_ptw_xbar_hash_ready_hold_001` | xbar hash、ready hold、mask。 | P0 |
| `PTW-ADD-013` | `test_ptw_pmp_deny_by_level_no_lsu_001` | fst/scd/thd PMP deny no side-effect。 | P0 |
| `PTW-ADD-014` | `test_ptw_pmp_original_type_perm_001` | PMP original type permission。 | P0 |
| `PTW-ADD-015` | `test_ptw_mprv_mpp_m_effective_mode_001` | data/PFU MPRV/MPP effective M；fetch 不受 MPRV。 | P0 |
| `PTW-ADD-016` | `test_ptw_nonleaf_rule_by_level_001` | nonleaf by level、V=0、write-only。 | P0 |
| `PTW-ADD-017` | `test_ptw_write_only_mxr_matrix_001` | `W && !(R || (MXR && X))`。 | P0 |
| `PTW-ADD-018` | `test_ptw_leaf_access_perm_matrix_001` | fetch/load/store/PFU leaf 权限。 | P0 |
| `PTW-ADD-019` | `test_ptw_leaf_ad_us_sum_matrix_001` | A/D/U/S/SUM/effective mode。 | P0 |
| `PTW-ADD-020` | `test_ptw_huge_align_before_degrade_001` | 1G/2M 对齐先于 sysmap/degrade。 | P0 |
| `PTW-ADD-021` | `test_ptw_mbuf_entry_alloc_priority_001` | mbuf entry8/entry0-7 分配。 | P1 |
| `PTW-ADD-022` | `test_ptw_mbuf_chk_not_ready_hold_001` | CHK not-ready hold。 | P1 |
| `PTW-ADD-023` | `test_ptw_lsu_bus_error_priority_001` | bus error access fault/no CHK/PDE。 | P0 |
| `PTW-ADD-024` | `test_ptw_abort_lsu_outstanding_matrix_001` | abort outstanding/data/bus_error/old exception。 | P0 |
| `PTW-ADD-025` | `test_ptw_maee1_ext_attr_all_sizes_001` | MAEE=1 1G/2M/4K raw attr。 | P0 |
| `PTW-ADD-026` | `test_ptw_maee0_4k_sysmap_refill_001` | MAEE=0 4K sysmap。 | P0 |
| `PTW-ADD-027` | `test_ptw_maee0_1g_degrade_matrix_001` | 1G no-cross、1G->2M、1G->4K。 | P0 |
| `PTW-ADD-028` | `test_ptw_maee0_2m_degrade_matrix_001` | 2M no-cross、2M->4K。 | P0 |
| `PTW-ADD-029` | `test_ptw_sysmap_flag_order_default_001` | sysmap flag order/default。 | P1 |
| `PTW-ADD-030` | `test_ptw_context_sampling_points_001` | ASID/MXR/SUM/MAEE 使用点采样。 | P1 |
| `PTW-ADD-031` | `test_ptw_full_flow_trace_001..023` | 第 12 章 23 条 flow。 | P0 |
| `PTW-ADD-032` | `test_ptw_l1dtlb_consumer_trace_001` | L1DTLB consumer-only evidence。 | P1 |
| `PTW-ADD-033` | `test_ptw_pfu_permission_matrix_001` | PFU 特殊权限矩阵。 | P0 |
| `PTW-ADD-034` | `test_ptw_refill_flg_bit_layout_001` | refill tag/data/flg bit layout。 | P0 |
| `PTW-ADD-035` | `test_ptw_same_id_no_reuse_constraint_001` | 同 `{type,id}` 不复用约束。 | P2 |
| `PTW-ADD-036` | `test_ptw_bare_mode_no_request_constraint_001` | Bare/M no-request 约束。 | P2 |

### 8.3 Requirement-driven Audit Matrix

| Audit ID | Requirement | 关闭测试点 | 核心 evidence |
| --- | --- | --- | --- |
| `PTW-AUD-001` | RSW/high reserved/strong-order 不参与 page fault | `PTW-ADD-001/002/034` | source scoreboard flg/no-fault + CHK/ARB SVA。 |
| `PTW-AUD-002` | raw G 只生成 global/tag | `PTW-ADD-003/034` | refill tag/data bit compare。 |
| `PTW-AUD-003` | 请求 type 成功返回目标 | `PTW-ADD-004/033` | target compare + L1D/L1I consumer evidence。 |
| `PTW-AUD-004` | 异常返回 type/id 与 PFU/IUTLB 规则 | `PTW-ADD-005/006` | fault class/key compare。 |
| `PTW-AUD-005` | PDE cache hit/miss/双命中选择 | `PTW-ADD-007` | PDE hit/start-level/memory skip evidence。 |
| `PTW-AUD-006` | PDE cache update 条件与时序 | `PTW-ADD-008/009` | PDE update event + race SVA。 |
| `PTW-AUD-007` | reset/satp/PMP/abort 清理差异 | `PTW-ADD-010/011/024` | PDE clear/drop/re-update evidence。 |
| `PTW-AUD-008` | xbar hash 与 ready/backpressure | `PTW-ADD-012` | xbar hash SVA + request hold cover。 |
| `PTW-AUD-009` | PMP 检查对象与 deny 终止 | `PTW-ADD-013` | PTE PA PMP deny + no LSU/CHK/refill。 |
| `PTW-AUD-010` | PMP 权限使用原始 request type | `PTW-ADD-014` | fetch X、load/PFU R、store W。 |
| `PTW-AUD-011` | MPRV/MPP effective privilege | `PTW-ADD-015/030` | fetch real priv；data/PFU MPRV/MPP。 |
| `PTW-AUD-012` | 非叶 PTE page fault 规则 | `PTW-ADD-016` | fst/scd pointer、thd nonleaf fault。 |
| `PTW-AUD-013` | Leaf PTE 权限矩阵 | `PTW-ADD-017/018/019/033` | fetch/load/store/PFU formulas。 |
| `PTW-AUD-014` | 巨页 PPN 对齐优先于降级 | `PTW-ADD-020` | page fault no sysmap/degrade。 |
| `PTW-AUD-015` | MBUF entry 分配与 LSU single outstanding | `PTW-ADD-021` | mbuf entry/LSU protocol SVA。 |
| `PTW-AUD-016` | CHK not ready 与 bus error | `PTW-ADD-022/023` | hold/get + bus error access fault。 |
| `PTW-AUD-017` | Abort LSU outstanding 边界 | `PTW-ADD-024` | dropped/no stale output + abort SVA。 |
| `PTW-AUD-018` | MAEE=1 direct attr | `PTW-ADD-025` | raw PTE ext attr all sizes。 |
| `PTW-AUD-019` | MAEE=0 4K sysmap refill | `PTW-ADD-026` | THD 4K sysmap evidence。 |
| `PTW-AUD-020` | MAEE=0 1G/2M degrade | `PTW-ADD-027/028/029` | final page_size/PPN/flg + no lower walk。 |
| `PTW-AUD-021` | 上下文采样点 | `PTW-ADD-030` | context sample transaction + expected match。 |
| `PTW-AUD-022` | 第 12 章完整流程 | `PTW-ADD-031` | `PTW-FLOW-001..023` 表逐项关闭。 |
| `PTW-AUD-023` | L1DTLB 间接消费 PTW 输出 | `PTW-ADD-032` | consumer-only evidence，不替代 source closure。 |

### 8.4 Infrastructure Matrix

这些 `PTW-INFRA-*` 不是功能测试点，而是关闭 `PTW-AUD-*`、`PTW-ADD-*`、`PTW-FLOW-*` 所需的基础设施工作项；没有对应基础设施时，相关测试只能标 `open/provisional`，不能签核。

| Infra ID | 工作项 | 覆盖范围 | 完成判据 |
| --- | --- | --- | --- |
| `PTW-INFRA-001` | `ptw_source_ref_model` | source-side golden：request accept、PDE cache、PMP、PTE decode、MAEE/sysmap/degrade、abort/drop。 | 可按 `{type,id}` 生成 expected；能解释 no-output/drop；不依赖固定延迟。 |
| `PTW-INFRA-002` | page table builder 与 PTW memory sequences | raw PTE 构造、PTE PA 响应、bus error、same-cycle abort/data、sysmap region。 | 每级 PTE PA、raw PTE、bus error 可控；scenario metadata 记录完整。 |
| `PTW-INFRA-003` | PTW refill/expt/source monitor 与 source scoreboard | request/output/probe transaction 采集和 expected/actual 比对。 | 输出 `PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0`；consumer-only 与 source closure 分开统计。 |
| `PTW-INFRA-004` | PDE cache monitor/SVA | hit/update/clear/race/replacement/drop。 | double-hit、old-state lookup、clear-only、abort flush 均有 assert/cover 或 monitor evidence。 |
| `PTW-INFRA-005` | PTW LSU/MBUF protocol SVA | mbuf entry、single outstanding、CHK not-ready、bus error、abort outstanding。 | P0 protocol assert 0 fail，关键 abort/bus error cover hit。 |
| `PTW-INFRA-006` | PMP/TWU/CHK SVA 与 context probes | PTE PA PMP、original type permission、MPRV/MPP、CHK permission formulas。 | PMP deny no-side-effect、fetch no-MPRV、PFU 权限例外均能被 checker 关闭。 |
| `PTW-INFRA-007` | MAEE/sysmap/degrade SVA 与 whitebox coverage | MAEE=1 attr、MAEE=0 4K sysmap、1G/2M degrade、no lower walk。 | all page sizes 覆盖；sysmap flag order 和 malformed constraint 明确。 |
| `PTW-INFRA-008` | xbar/arb monitor/SVA | VPN hash、target mask、ready hold、completion priority、type/id route。 | ready/valid payload hold、target route、`ptw_l2tlb_cmplt` OR-only 语义有 evidence。 |
| `PTW-INFRA-009` | coverage gate、closure CSV 与 regression report | `PTW-AUD/PTW-ADD/PDE/MBUF/MAEE/FLOW/INFRA` 全量签核。 | 每条 requirement 有 test、source match、SVA/cover、状态和 open/waiver reason。 |

## 9. 覆盖与签核

### 9.1 Scenario metadata

每个新 test 必须在日志中打印：

```text
PTW_SCENARIO_BEGIN tc=<test_name> scenario=<scenario_id> reqs=<requirement_ids>
PTW_SCENARIO_EXPECT kind=<refill/page/access/drop> type=<...> vpn=<...> page_size=<...>
PTW_SCENARIO_END scenario=<scenario_id> result=<pass/fail/waived>
```

### 9.2 SVA cover gate

每个 SVA module final block 输出：

```text
PTW_SVA_COVER module=<module> name=<cover_name> hits=<N>
```

回归脚本必须检查：

1. P0 assert fail 数为 0。
2. P0 directed test 对应 cover hit > 0。
3. P0 scenario source scoreboard match > 0。
4. 没有 pending unmatched PTW request，除非 drop/abort/reset 规则命中。
5. consumer-only tests 不计入 source-side closure。

### 9.3 建议回归列表

新增或更新：

```text
mmu_verification/simu/ptw_p0_list
mmu_verification/simu/ptw_p1_list
mmu_verification/simu/ptw_sva_smoke_list
```

`ptw_p0_list` 至少包含：

```text
test_ptw_pte_rsw_no_fault_flg_001
test_ptw_pte_high_reserved_ignored_001
test_ptw_global_rsw_flg_layout_001
test_ptw_refill_flg_bit_layout_001
test_ptw_type_id_target_success_001
test_ptw_type_id_fault_target_001
test_ptw_pfu_success_only_l2_001
test_ptw_pfu_permission_matrix_001
test_ptw_pde_hit_level_matrix_001
test_ptw_pde_update_condition_001
test_ptw_pde_lookup_update_race_001
test_ptw_pde_clear_context_matrix_001
test_ptw_xbar_hash_dispatch_001
test_ptw_xbar_target_mask_backpressure_001
test_ptw_xbar_nontarget_mask_no_block_001
test_ptw_pmp_level_deny_matrix_001
test_ptw_pmp_original_type_perm_001
test_ptw_mprv_mpp_effective_priv_001
test_ptw_nonleaf_fault_matrix_001
test_ptw_leaf_perm_fetch_load_store_001
test_ptw_write_only_mxr_x_matrix_001
test_ptw_us_sum_mprv_matrix_001
test_ptw_huge_align_before_degrade_001
test_ptw_mbuf_entry_alloc_priority_001
test_ptw_mbuf_chk_not_ready_hold_001
test_ptw_lsu_bus_error_priority_001
test_ptw_abort_lsu_outstanding_matrix_001
test_ptw_maee1_ext_attr_all_sizes_001
test_ptw_maee0_4k_sysmap_refill_001
test_ptw_maee0_1g_degrade_matrix_001
test_ptw_maee0_2m_degrade_matrix_001
test_ptw_full_flow_trace_001_023
```

## 10. 风险与阻塞项

| 风险 | 影响 | 处理计划 |
| --- | --- | --- |
| `pmp_regs_update` 当前 `tb_top` 顶层接常 0 | 无法真实验证 PMP config change 清 PDE | 标记 TB gap；补可驱动接口或 whitebox force 方案后关闭 `PDE-TP-010` 的 PMP 部分。 |
| PTW request VPN probe 可能不完整 | source ref/scoreboard 不能可靠建立 expected | 优先从 L2MB entry 重建；仍不足则补 `l2tlb_ptw_vpn` probe。 |
| `ptw_arb_ref_data_din` 未暴露 | flg bit layout 只能间接检查 | 必须补 probe；否则 `PTW-ADD-034` 只能 open。 |
| CHK raw PTE/level 不可见 | PTE/no-check/page fault SVA 难以直接断言 | 通过 `mbuf_twu_data` 和 `mbuf_twu_lvl` shadow；必要时 bind TWU 内部 chk data。 |
| MAEE THD/4K path 现有 SVA 明确未覆盖 | MAEE=0 4K sysmap 不能关闭 | 必须增强 `mmu_maee_twu_sva.sv` 或新增 THD bind。 |
| abort same-cycle bus error 精确窗口难构造 | `PTW-AUD-017` 可能 cover 难命中 | PTW memory responder 增加 deterministic response-at-cycle/address API。 |
| source scoreboard 未接入前仅有 monitor evidence | P0 test 不能最终签核 | 尽早接入 `ptw_source_ref_model + ptw_source_sb`；monitor-only 结果只能标 `provisional`。 |

## 11. 统一交付物

完成后应交付：

1. 新增/修改 test helper 和 page table builder API。
2. P0/P1 directed tests 加入 suite 和回归列表。
3. 新增 `mmu_ptw_top_sva.sv`、`mmu_pde_cache_sva.sv`、`mmu_ptw_xbar_sva.sv`、`mmu_twu_chk_sva.sv`。
4. 增强现有 MBUF/PMP/MAEE/Sysmap/ARB/L1D SVA。
5. 新增 `ptw_source_types`、`ptw_pde_cache_model`、`ptw_source_ref_model`、`ptw_source_monitor`、`ptw_source_sb`，并接入 `mmu_env_pkg.sv/mmu_env.svh/mmu_top_cfg.svh`。
6. `Files.f` 接入新增 SVA/source checker 文件，suite include 接入新增 tests。
7. 回归报告，包含 assert fail、cover hit、source scoreboard match/mismatch、pending request、illegal stimulus、consumer-only evidence。
8. 旧 test 修改/删除/重归属说明，禁止旧错误 expected 继续关闭 PTW requirement。

## 12. 统一完成判据

可签核条件：

1. `ptw_p0_list` 全部测试 compile/run 通过；P1/P2 中已纳入签核范围的测试必须列出 pass/fail/waive 状态。
2. 所有 P0 SVA 0 fail。
3. 所有 P0 directed scenario 对应 cover hit > 0。
4. 所有 P0 scenario 有 `ptw_source_ref_model + ptw_source_sb` source-side match；consumer-only evidence 单独列出，不能替代 source-side closure。
5. `PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0`，非法/stress list 除外。
6. `PTW-FLOW-001..023` 每条至少绑定一个 test、一个 source scoreboard match 和一个 checker/SVA/cover 证据；未实现项必须有明确 open reason。
7. 旧 spec 冲突测试已修改、删除或标 `obsolete-by-spec`，不再计入 PTW closure。
8. 回归报告能按 `PTW-AUD-*`、`PTW-ADD-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*`、`PTW-FLOW-*` 输出 closure 状态。

### 12.1 `ptwspec.md` 全文覆盖核对表

| `ptwspec.md` 章节 | 本计划落点 | 必须闭环的关键点 |
| --- | --- | --- |
| §1 地址、模式、PTE 格式 | 2.5、4.2、5.1、18.5、18.6 | Sv39 only；Bare/M no-request 约束；VPN/PPN 分段；raw PTE bit；RSW/G/flg 映射；high reserved ignored。 |
| §2 请求与返回接口 | 2.5、5.2、7.2、18.1、22.2-22.5 | type 编码；`id[5:3]/id[2:0]`；PFU only L2；page_size 编码；`ptw_l2tlb_cmplt` 只是 OR。 |
| §3 PDE Cache | 5.3、7.3、19 | 两级 16-entry 全相联；L1/L2/double-hit；old-state lookup；next-cycle update；clear source；satp/PMP clear-only。 |
| §4 Xbar/Ready | 5.4、7.4、23 | hash 公式；target mask blocks only target；ready low payload hold；abort dispatch block。 |
| §5 TWU 流水 | 7.5、7.6、18.2-18.5 | PMP stage PA/type/effective privilege；CHK wait；no fixed cycle scoreboard。 |
| §6 PTE 检查 | 5.6、7.6、18.5 | leaf/write-only；nonleaf fault；fetch/load/store/PFU leaf fault；U/S/SUM/MPRV；huge align before degrade；不检查项。 |
| §7 MPRV/上下文采样 | 5.5、5.8、18.3、23 | fetch real priv；load/store/PFU MPRV/MPP；ASID refill 当拍；MAEE leaf/sysmap 入口；普通随机约束无 abort ASID/PPN 交错。 |
| §8 Mbuf/LSU | 5.7、7.7、18.4、21 | entry 分配；single outstanding；CHK not-ready hold；bus error access fault；no CHK/no PDE update。 |
| §9 Refill/异常/仲裁 | 7.2、7.7、18.6、22 | access > page > refill；grant onehot；tag/data bit layout；type/id route；target route。 |
| §10 MAEE/Sysmap/Degrade | 5.8、7.8、20 | MAEE=1 all-size raw attr；MAEE=0 all-size sysmap；4K sysmap；1G/2M degrade PPN；no lower walk；sysmap malformed illegal。 |
| §11 Reset/satp/PMP/Abort | 5.3、5.7、7.7、19.4、21 | reset/abort flush；satp/PMP only clear PDE；abort same-cycle data/bus error；pre-existing exception grant allowed。 |
| §12 完整处理流程 | 5.9、12、26 | `PTW-FLOW-001..023` 每条必须有 test + source match + SVA/cover。 |
| §13.1 Reference/Scoreboard | 13-29 | source ref/sb 分工；`{type,id}` matching；memory channel association；drop；report。 |
| §13.2-13.3 Assertion/约束 | 2.5、7、23 | ready/valid、xbar、PDE race、abort、illegal stimulus constraints。 |
| §13.4-13.20 测试点/Traceability | 5-12、27 | `PTW-AUD/PTW-ADD/PDE/MBUF/MAEE/FLOW` closure；旧 test modify/split/delete/re-scope；CSV ID 回归映射。 |
| §13.21 SVA 规格 | 7、26、27 | PTW source-side SVA、consumer-side L1DTLB SVA 分工；cover hit gate。 |
| §14 旧答案冲突与最终解释 | 2.5、5-8、12、17-22、28 | abort 全清/flush；RSW 进 flg；不额外检查 reserved/strong-order；satp/PMP clear-only；MPRV machine effective；sysmap flag order。 |
| §15 原始澄清问答覆盖索引 | 5-12、18-22、25-29 | Q1-Q180 均映射到正式 requirement、test/SVA/source checker 或 illegal constraint；后轮覆盖前轮。 |
| §16 `ptw_overview.md` 原文归档 | 12.1、14、27 | 只作为追溯来源；若与正式规格或 §14/§15 收敛项冲突，按正式规格执行并在 closure report 标 `obsolete-by-spec`。 |

## 13. Reference Model 与 Scoreboard 范围

1. 新增 PTW source-side reference model，按 `ptwspec.md` §1-§12 建模 `vpn/type/id` 请求、PDE cache、PMP、PTE decode、page fault、LSU bus error、MAEE/sysmap/degrade、refill、page/access fault、abort/reset/drop。
2. 新增 PTW source-side scoreboard，按 `{type,id}` 匹配 expected 和 actual，比较 refill tag/data、page/access fault、target、drop/no-output 和非法 stimulus。
3. 新增或增强 PTW source monitor、context/probe monitor、PDE cache monitor，把 DUT 内部 PTW request、visible output、PDE hit/update/clear、PMP/sysmap/abort/LSU bus error 信息转换为 UVM transaction。
4. 将现有 `ptw_mem_monitor.ap_req/ap_rsp/ap_drop` 接入 PTW source-side checker，确保 golden model 使用实际返回的 raw PTE 和 bus error，而不是只从 shadow page table 反推。
5. 修改 env/package/config/build/connect，使 source checker 默认可打开、可单独关闭、可输出独立 signoff report。
6. 明确现有 `mmu_ref_model.translate()` 和 `mmu_translation_sb` 的职责边界，禁止用 consumer-side end-to-end PA 比较替代 PTW source-side closure。

Reference model 与 scoreboard 不做：

1. 不检查固定 T0/T1/T2 cycle、固定 LSU latency 或固定仲裁延迟；这些由 SVA/monitor 关闭。
2. 不把 L1DTLB/L1ITLB/L2TLB 内部 CAM、replacement、busy/wakeup、preselect/replay 作为 PTW source scoreboard 的 golden 目标。
3. 不在 scoreboard 中检查 PLRU bit-level 翻转；若 test 以 replacement 为目标，由 PDE cache SVA/whitebox monitor 关闭。
4. 不修改 PTW RTL 功能路径。若缺少观测字段，只补 testbench probe 或 bind monitor。

## 14. 当前 Reference/Scoreboard 差距

### 14.1 `mmu_ref_model.svh` 差距

当前 `mmu_ref_model.translate()` 是 consumer-side VA->PA reference model，不能直接作为 PTW source-side golden。必须保留它继续服务 `mmu_translation_sb`，同时新增独立 PTW model。主要差距如下：

| 差距 | 当前行为 | PTW source 要求 |
| --- | --- | --- |
| Bare/M-mode | `translate()` 支持 passthrough | PTW source model 不定义 Bare 请求误入；默认约束不产生，若出现报 illegal。 |
| PMP 对象 | 可能按最终翻译 PA 或 consumer 端语义比较 | PTW source model 只检查 PTE read PA，即每级 PTE 地址的 PMP。 |
| PFU 权限 | 可能按 load 检查 R/MXR/X/D | PFU 不要求 R/MXR/X/D，只检查 V、write-only、U/S、A、huge align。 |
| write-only | 使用标准 `W=1,R=0` reserved fault | 必须使用本设计规则 `W && !(R || (MXR && X))`。 |
| reserved/RSW | 可能按标准 Sv39 fault | high reserved bit 和 RSW 不 fault；RSW 进入 refill flg。 |
| PDE cache | 无 PTW PDE cache hit/update/clear/drop 状态 | 必须建模两级 16 entry 全相联 PDE cache。 |
| MAEE/sysmap/degrade | 不能完整覆盖 1G/2M/4K all-size sysmap 和降级 | 必须按 MAEE=0/1、sysmap region、degrade 公式建模。 |
| abort/drop | 没有 PTW source transaction drop 语义 | reset/abort/bus-error 边界必须生成 `DROPPED` 或 visible fault。 |
| output 字段 | 只输出最终 PA/fault | 必须输出 `vpn/asid/page_size/ppn/global/flg/type/id/target/fault_kind/drop_reason`。 |

### 14.2 `mmu_translation_sb.svh` 差距

当前 `mmu_translation_sb` 订阅 IFU/LSU response monitor，通过 `m_ref.translate()` 比较最终 translation 结果。它只能证明 PTW/L1/L2 的结果被下游消费，不能关闭 PTW source-side 要求。

统一分工如下：

| Checker | 定位 | 能关闭 | 不能关闭 |
| --- | --- | --- | --- |
| `ptw_source_ref_model` | PTW source golden | PTE/PMP/PDE/MAEE/sysmap/degrade/abort 的期望生成 | IFU/LSU 最终 PA、L1 replacement |
| `ptw_source_sb` | PTW source actual vs expected | refill tag/data、fault、target、drop、illegal | fixed-cycle ready/valid、PLRU bit |
| `mmu_translation_sb` | consumer-side evidence | IFU/LSU 最终 PA/fault 端到端消费 | PTW source PTE/PMP/MAEE/PDE 源头正确性 |
| `mmu_l1dtlb_spec_sb` | L1DTLB 局部行为 | L1 refill 消费、exception CAM、replay | PTW refill 字段生成和 fault 源头 |
| SVA/monitor | cycle/protocol | ready/valid hold、arb priority、xbar、LSU single outstanding、abort 边界 | 事务级 golden result 完整替代 |

## 15. 新增/修改文件总表

### 15.1 新增文件

| 文件 | 类型 | 主要内容 | 完成条件 |
| --- | --- | --- | --- |
| `mmu_verification/testbench/env/ptw_source_types_pkg.sv` 或 `ptw_source_types.svh` | type/utility | PTW source scoreboard/ref model 所需 enum、struct、decode helper、format helper | 编译通过；所有类型被 `mmu_env_pkg.sv` 正确 include/import。 |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | reference helper | 两级 16-entry PDE cache abstract model，lookup/update/clear/drop 规则 | 能独立 unit/self-check；支持 old-state lookup、next-cycle update。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | UVM component/object | PTW source golden algorithm、CSR/PMP/sysmap mirror、pending state、expected 生成 | directed 基本流能产生完整 expected；不调用 `mmu_ref_model.translate()`。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | UVM monitor | 从 `mmu_dut_probes_if` 采样 PTW request、visible completion、refill tag/data、target、abort/reset | 能输出 `ap_req_accept/ap_actual_rsp/ap_abort/ap_ctx/ap_pde_evt`。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | UVM scoreboard | TLM fan-in、expected map、actual compare、illegal/drop/pending/report | P0 directed tests 全部能由 source-side match 关闭。 |
| `mmu_verification/testbench/env/ptw_source_report.svh` 可选 | report helper | report 计数、field mismatch histogram、requirement closure 输出 | report 格式稳定，回归脚本可 grep。 |

若工具链不方便新增 package 文件，可把 `ptw_source_types.svh` include 在 `mmu_env_pkg.sv` 内；但类型必须集中定义，禁止在 ref model 和 scoreboard 中各自复制字段定义。

### 15.2 修改文件

| 文件 | 修改点 | 必须注意 |
| --- | --- | --- |
| `mmu_verification/testbench/env/mmu_top_cfg.svh` | 增加 `en_ptw_source_sb`、`en_ptw_source_ref_model`、strict/relaxed knobs、probe sync knobs、illegal stimulus knobs | 默认打开 source checker；debug 可单独关闭。 |
| `mmu_verification/testbench/env/mmu_env_pkg.sv` | include 新类型、PDE cache model、source ref model、source monitor、source sb | include 顺序必须在 `mmu_env.svh` 前。 |
| `mmu_verification/testbench/env/mmu_env.svh` | 声明、build、connect 新组件；连接 CP0/PMP/sysmap/PTW mem/source monitor TLM | 不破坏现有 `m_ref` 和 `m_translation_sb`。 |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv` | 增加缺失 PTW source probe | probe 只读，不改变 DUT。 |
| `mmu_verification/testbench/top/tb_top.sv` | 给新增 probe assign 层级信号 | 只允许层级读取；不要在 env package 中使用 `$root`。 |
| `mmu_verification/testbench/ptw_mem_agent/ptw_mem_monitor.svh` | 文档/连接增强；必要时补 transaction 字段 `cycle/drop_reason` | 现有 `ap_req/ap_rsp/ap_drop` 保留并 fanout 给 source checker。 |
| `mmu_verification/testbench/common/mmu_common_pkg.sv` | 如已有 enum 不足，补共享常量或映射函数 | 避免重复定义与现有类型冲突。 |
| `mmu_verification/testbench/Files.f` | 若新增独立 package/interface/SVA monitor 文件，加入编译列表 | 保持 package 编译顺序。 |

### 15.3 `mmu_top_cfg.svh` 建议 knob

```systemverilog
bit en_ptw_source_ref_model       = 1;
bit en_ptw_source_sb              = 1;
bit ptw_source_strict             = 1;
bit ptw_source_strict_refill_bits = 1;
bit ptw_source_check_l1_targets   = 1;
bit ptw_source_check_pde_model    = 1;
bit ptw_source_use_whitebox_pde   = 1;
bit ptw_source_allow_illegal      = 0;
bit ptw_source_fail_on_pending    = 1;
bit ptw_source_report_all_matches = 0;
```

knob 语义：

1. `en_ptw_source_ref_model=0` 时，不创建 source ref model；只能做 monitor/report，不允许关闭 source requirement。
2. `en_ptw_source_sb=0` 时，不做 actual compare；directed debug 可用，但回归 signoff 不允许关闭。
3. `ptw_source_strict=1` 时，任何字段 mismatch、illegal stimulus、pending 非 0 都报 error/fatal。
4. `ptw_source_strict_refill_bits=1` 时，同时按语义字段和 bit layout 比较 tag/data。
5. `ptw_source_use_whitebox_pde=1` 时，PDE cache replacement/victim 可由 whitebox event 同步；若关闭，则 directed tests 必须避免超过 16 entry 替换歧义。
6. `ptw_source_allow_illegal=1` 仅用于非法/stress test，report 必须打印 `ILLEGAL_EXPECTED`，不得计入正常 closure。

## 16. PTW Source 数据结构计划

先落地统一类型，再实现 ref model 和 scoreboard。建议核心类型如下，字段名可按代码风格微调，但语义必须完整。

### 16.1 enum

```systemverilog
typedef enum int unsigned {
  PTW_LVL_FST = 0,
  PTW_LVL_SCD = 1,
  PTW_LVL_THD = 2
} ptw_level_e;

typedef enum int unsigned {
  PTW_EXP_REFILL,
  PTW_EXP_PAGE_FAULT,
  PTW_EXP_ACCESS_FAULT,
  PTW_EXP_DROPPED
} ptw_exp_kind_e;

typedef enum int unsigned {
  PTW_DROP_NONE,
  PTW_DROP_RESET,
  PTW_DROP_ABORT,
  PTW_DROP_ABORT_LSU_DATA,
  PTW_DROP_ABORT_BUS_ERROR,
  PTW_DROP_ABORT_PENDING_EXCEPTION_MASKED
} ptw_drop_reason_e;

typedef enum int unsigned {
  PTW_FAULT_NONE,
  PTW_FAULT_PMP_DENY,
  PTW_FAULT_LSU_BUS_ERROR,
  PTW_FAULT_PTE_V0,
  PTW_FAULT_PTE_WRITE_ONLY,
  PTW_FAULT_THD_NONLEAF,
  PTW_FAULT_FETCH_X,
  PTW_FAULT_LOAD_R,
  PTW_FAULT_STORE_W,
  PTW_FAULT_US,
  PTW_FAULT_A,
  PTW_FAULT_D,
  PTW_FAULT_HUGE_ALIGN
} ptw_fault_kind_e;
```

`fault_kind` 必须是 machine-readable enum，不建议只用 string。string 可作为 report 辅助字段。

### 16.2 request key/context

```systemverilog
typedef struct packed {
  logic [2:0] type;
  logic [5:0] id;
} ptw_req_key_t;

typedef struct {
  bit           valid;
  logic [26:0] vpn;
  logic [2:0]  type;
  logic [5:0]  id;
  time         accept_time;
  longint unsigned accept_cycle;
  int unsigned source;
  logic [2:0] l2_eid;    // id[5:3]
  logic [2:0] l1_eid;    // id[2:0]
  bit         pde_l1_hit;
  bit         pde_l2_hit;
  ptw_level_e start_level;
} ptw_req_ctx_t;
```

request accept 定义固定为：

```text
ptw_req_accept = l2tlb_ptw_req && ptw_jtlb_ready
```

`l2tlb_ptw_req=1 && ptw_jtlb_ready=0` 不能创建 expected；该场景由 SVA 检查 payload hold。

### 16.3 每级访问记录

```systemverilog
typedef struct {
  bit           valid;
  ptw_level_e   level;
  logic [39:0]  pte_addr;
  logic [27:0]  base_ppn;
  logic [63:0]  pte_raw;
  bit           pmp_checked;
  bit           pmp_deny;
  bit           bus_error;
  bit           leaf;
  bit           page_fault;
  bit           nonleaf_update;
  ptw_fault_kind_e fault_kind;
  longint unsigned req_cycle;
  longint unsigned rsp_cycle;
} ptw_level_obs_t;
```

每个实际访问的 level 都必须记录。PDE cache hit 跳过的 level 不生成 memory request，但 expected object 中应记录 `start_level` 和 hit 状态，方便 report 证明 skip-level 路径被覆盖。

### 16.4 expected response

```systemverilog
typedef struct {
  ptw_exp_kind_e kind;
  ptw_req_key_t  key;
  logic [26:0]   vpn;
  logic [15:0]   asid;
  logic [2:0]    page_size;
  logic [27:0]   ppn;
  bit            global;
  logic [13:0]   flg;
  bit            target_l2tlb;
  bit            target_l1itlb;
  bit            target_l1dtlb;
  bit            target_pfu;
  ptw_fault_kind_e fault_kind;
  ptw_drop_reason_e drop_reason;
  ptw_level_obs_t levels[$];
  longint unsigned done_cycle;
  string         detail;
} ptw_expected_rsp_t;
```

### 16.5 actual response

```systemverilog
typedef struct {
  bit            valid;
  ptw_exp_kind_e kind;
  ptw_req_key_t  key;
  logic [26:0]   vpn;
  logic [15:0]   asid;
  logic [2:0]    page_size;
  logic [27:0]   ppn;
  bit            global;
  logic [13:0]   flg;
  logic [47:0]   refill_tag;
  logic [41:0]   refill_data;
  bit            target_l2tlb;
  bit            target_l1itlb;
  bit            target_l1dtlb;
  bit            target_pfu;
  bit            pgflt;
  bit            acc_err;
  longint unsigned cycle;
} ptw_actual_rsp_t;
```

actual response 必须由 monitor 从 visible output 解码。`ptw_l2tlb_cmplt` 只能作为 completion OR 触发入口，不能单独决定 `kind`。

## 17. PTW Source Reference Model 架构

### 17.1 组件职责

`ptw_source_ref_model` 建议实现为 `uvm_component`，内部维护 context mirror、PDE cache model、pending request map 和 expected queue。它不直接报 mismatch，只生成 expected；比较由 `ptw_source_sb` 完成。

推荐接口：

```systemverilog
class ptw_source_ref_model extends uvm_component;
  uvm_tlm_analysis_fifo #(ptw_req_accept_txn) af_req_accept;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)        af_ptw_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)        af_ptw_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)        af_ptw_mem_drop;
  uvm_tlm_analysis_fifo #(cp0_txn)            af_csr_write;
  uvm_tlm_analysis_fifo #(pmp_txn)            af_pmp_cfg;
  uvm_tlm_analysis_fifo #(sysmap_cfg_txn)     af_sysmap_cfg;
  uvm_tlm_analysis_fifo #(ptw_abort_txn)      af_abort;
  uvm_analysis_port #(ptw_expected_rsp_t)     ap_expected;
endclass
```

若 event ordering 需要 scoreboard 统一调度，也可以由 `ptw_source_sb` 持有 `ptw_source_ref_model` object 并同步调用 `on_req/on_mem_rsp/on_abort`。关键要求是：所有影响结果的事件必须按 monitor 采样 cycle 有序处理。

### 17.2 内部状态

| 状态 | 内容 | 更新来源 |
| --- | --- | --- |
| `m_pending_by_key[ptw_req_key_t]` | accepted 但未完成/drop 的 request context | request accept、completion、abort/reset |
| `m_walk_state_by_key` | 当前 request 的 start level、当前 level、prev nonleaf PPN、levels[$] | PDE lookup、PMP、mem rsp、CHK |
| `m_mem_pending` | serial PTW memory outstanding，包含 key、level、pte_addr | `ptw_mem_monitor.ap_req/ap_rsp/ap_drop` |
| `m_pde_model` | 两级 PDE cache committed/next state | request lookup、nonleaf update、clear/abort/reset |
| `m_context` | SATP/ASID/MXR/SUM/priv/MPRV/MPP/MAEE/PMP/sysmap mirror | CP0/PMP/sysmap monitor 和 probe |
| `m_drop_windows` | abort/reset 后禁止 stale output 的 key/时间窗口 | abort/reset/drop |
| `m_stats` | accepted、expected、drop、illegal、PDE/PMP/PTE/MAEE/bus counters | 所有事件 |

### 17.3 事件排序原则

同一 cycle 内必须使用稳定、可解释的排序。建议实现时把每个 monitor transaction 都带 `cycle`，在 ref model 内按以下优先级处理：

1. reset active：清 pending、清 memory pending、清 PDE、产生 `DROPPED(reset)`。
2. `tlboper_ptw_abort`：清 PDE，flush 未获授权 in-flight，产生 `DROPPED(abort*)`。
3. visible completion already granted：若 spec 允许 abort 当拍已有异常 grant 穿透，则先识别为 visible fault，再对其他 pending drop。
4. PTW memory response：普通 data 进入 CHK；bus error 进入 access fault 或 abort-drop。
5. PTW memory request accept：绑定到当前 expected level，检查地址。
6. PTW request accept：创建新 pending，做 PDE lookup，决定 start level。
7. satp/PMP clear：只清 PDE cache，不 flush pending。
8. CSR/PMP/sysmap mirror update：供后续使用点采样。

实际排序可按 DUT monitor 采样能力微调，但必须在代码注释和 report 中固定；任何无法 disambiguate 的同拍窗口必须由 SVA 关闭或由 directed test 避免。

## 18. PTW Golden Algorithm 实现计划

### 18.1 Request accept 与 key 管理

实现步骤：

1. `ptw_source_monitor` 看到 `l2tlb_ptw_req && ptw_jtlb_ready` 时发送 `ptw_req_accept_txn`。
2. ref model 构造 `ptw_req_key_t'{type,id}`。
3. 若 `m_pending_by_key.exists(key)`，默认报 illegal：同 `{type,id}` 未完成前复用。非法/stress test 只有在 `ptw_source_allow_illegal=1` 时降级为 expected-illegal report。
4. 保存 `vpn/type/id/accept_cycle/l2_eid/l1_eid/source`。
5. 使用 committed PDE cache old state 做 lookup：
   - miss：`start_level=PTW_LVL_FST`
   - L1 hit only：`start_level=PTW_LVL_SCD`
   - L2 hit only：`start_level=PTW_LVL_THD`
   - double hit：选择 L2，`start_level=PTW_LVL_THD`
6. 根据 start level 生成第一笔 expected PTE read 地址，并等待 PMP/memory 事件推进。

Bare、M-mode no-translation 请求进入 PTW 默认 illegal。若 test 专门验证非法输入，必须在 scenario metadata 中标记，不能用于正常 PTW closure。

### 18.2 PTE PA 生成

每级实际访问的 PTE PA 公式固定：

```text
fst_pte_pa = {regs_ptw_satp_ppn, vpn[26:18], 3'b0}
scd_pte_pa = {prev_nonleaf_ppn,  vpn[17:9],  3'b0}
thd_pte_pa = {prev_nonleaf_ppn,  vpn[8:0],   3'b0}
```

采样要求：

1. `regs_ptw_satp_ppn` 在 `fst_pmp_pa` 生成使用点采样，不在 request accept 时提前锁存。
2. `prev_nonleaf_ppn` 来自上一实际访问级别的 raw PTE PPN，或来自 PDE cache hit data。
3. PDE L1 hit 时，`scd_pte_pa` 的 `prev_nonleaf_ppn` 来自 L1 PDE cache data。
4. PDE L2 hit 时，`thd_pte_pa` 的 `prev_nonleaf_ppn` 来自 L2 PDE cache data。
5. 跳过级别不得出现对应 PTW memory request；若出现，由 scoreboard/SVA 报错。

### 18.3 PMP access fault 建模

PMP 检查对象是 PTE read PA，不是最终翻译 PA。deny 公式：

```text
deny = (fetch && !pmp_mmu_flg[2]
     || load  && !pmp_mmu_flg[0]
     || store && !pmp_mmu_flg[1]
     || pfu   && !pmp_mmu_flg[0])
     && !(effective_machine_mode && !pmp_mmu_flg[3])
```

实现细节：

1. fetch 使用真实流水线 privilege，忽略 MPRV/MPP。
2. load/store/PFU 在 `MPRV=1` 时使用 `mstatus.MPP` 作为 effective privilege，否则使用真实 privilege。
3. effective M-mode 且 `pmp_mmu_flg[3]==0` 时跳过 deny；`pmp_mmu_flg[3]==1` 时仍按 R/W/X 位判断。
4. fetch 映射 PMP X 权限；load/PFU 映射 R 权限；store/atomic 映射 W 权限。
5. PMP deny 立即生成 `PTW_EXP_ACCESS_FAULT`：
   - 不发 LSU request。
   - 不读取/解码 PTE。
   - 不进入 CHK。
   - 不产生 page fault。
   - 不更新 PDE cache。
   - 不产生 refill。
6. scoreboard 必须比较实际 PMP PA、type、deny、level；若 PMP probe 不完整，至少要用 memory request 缺失和 access fault 输出进行端到端 source 证明，但对应 field coverage 不能关闭。

### 18.4 PTW memory channel 建模

现有 `ptw_mem_monitor` 已提供：

```text
ap_req  : mmu_lsu_data_req_accept
ap_rsp  : lsu_mmu_data_vld || lsu_mmu_bus_error
ap_drop : reset 清 pending
```

连接要求：

1. `ap_req.addr` 必须等于 ref model 当前 level 计算出的 `pte_addr`。
2. PTW memory channel 是 strict serial single-outstanding；response 前再次 accept 报 protocol error。
3. `ap_rsp.pte_data` 是 CHK 的 raw PTE 输入；ref model 不得绕过它直接从 shadow page table 读取 expected PTE。
4. `ap_rsp.bus_error=1` 直接生成 `PTW_EXP_ACCESS_FAULT(PTW_FAULT_LSU_BUS_ERROR)`。
5. bus error 不解码 `pte_data`，不产生 page fault/refill/PDE update。
6. reset drop 只说明 memory channel pending 被清除；source request 是否 drop 仍按 reset/abort pending 规则处理。
7. `PTW_RSP_OOO` 或任何 out-of-order response 是非法 stimulus；相关旧 test 必须标 obsolete 或 illegal-stress。

建议给 `ptw_mem_txn` 增加非功能字段：

```systemverilog
longint unsigned cycle;
bit              dropped_by_reset;
string           debug_reason;
```

这些字段只用于 ordering/report，不影响现有 responder 行为。

### 18.5 PTE decode/page fault 建模

raw PTE bit 采用 `ptwspec.md` §1.3。模型必须显式派生：

```text
leaf             = V && (R || X)
write_only_fault = W && !(R || (MXR && X))
```

禁止加入以下额外 fault：

1. `PTE[58:38]` high reserved bit 非 0。
2. RSW 非 0。
3. strong-order/fetch meets strong order。
4. 标准 Sv39 `W=1,R=0` 一律 fault。
5. store 额外要求 R。
6. PFU 按 load 要求 R/MXR/X/D。

非叶子 fault 规则：

```text
nonleaf_page_fault = !V
                   || write_only_fault
                   || (level == PTW_LVL_THD && !leaf)
```

leaf fault 规则：

```text
fetch_fault = !V
           || write_only_fault
           || !X
           || us_fault
           || !A
           || huge_align_fault

load_fault  = !V
           || write_only_fault
           || (!R && !(MXR && X))
           || us_fault
           || !A
           || huge_align_fault

store_fault = !V
           || write_only_fault
           || !W
           || us_fault
           || !A
           || !D
           || huge_align_fault

pfu_fault   = !V
           || write_only_fault
           || us_fault
           || !A
           || huge_align_fault
```

`us_fault` 规则：

1. effective U-mode 访问 `U=0` page：fault。
2. effective S-mode 访问 `U=1` page 且 `SUM=0`：load/store/PFU fault；fetch 不能通过 SUM 访问 U page。
3. effective M-mode：跳过 S/U 检查。
4. fetch 使用真实 privilege；load/store/PFU 使用 MPRV 后的 effective privilege。

huge align fault：

1. FST leaf 1G：`pte.ppn[1] == 0 && pte.ppn[0] == 0`，否则 page fault。
2. SCD leaf 2M：`pte.ppn[0] == 0`，否则 page fault。
3. THD leaf 4K：无 huge align fault。
4. align fault 先于 MAEE=0 sysmap/degrade；对齐错误不得进入 degrade。

### 18.6 Refill tag/data/flg 建模

正常 refill tag/data bit layout 固定：

```text
refill_tag[47]    = valid
refill_tag[46:20] = vpn[26:0]
refill_tag[19:4]  = asid[15:0]
refill_tag[3:1]   = page_size[2:0]
refill_tag[0]     = global

refill_data[41:14] = ppn[27:0]
refill_data[13:9]  = ext_attr[4:0] = {So,C,B,Sh,Sec}
refill_data[8:7]   = RSW[1:0]
refill_data[6]     = D
refill_data[5]     = A
refill_data[4]     = U
refill_data[3]     = X
refill_data[2]     = W
refill_data[1]     = R
refill_data[0]     = V
```

`flg[13:0]` 即 `refill_data[13:0]`。注意：

1. G 只进入 `refill_tag[0]`，不得进入 data `flg`。
2. RSW 必须进入 `flg[8:7]`，但不参与 page fault。
3. `global` 只等于当前 leaf PTE 的 G，不 OR 上级非叶 G。
4. `asid` 在 refill 输出当拍采样 active satp ASID；request accept 时不锁存 ASID。
5. `page_size` 编码：1G=`3'b100`，2M=`3'b010`，4K=`3'b001`。
6. `type/id` 与 request 完整一致。

MAEE=1：

```text
ext_attr = raw_pte[63:59]
data     = {raw_pte[37:10], raw_pte[63:59], raw_pte[9:6], raw_pte[4:0]}
```

MAEE=0：

```text
ext_attr = sysmap_mmu_flg[4:0]
data     = {final_ppn[27:0], sysmap_mmu_flg[4:0], raw_pte[9:6], raw_pte[4:0]}
```

## 19. PDE Cache Reference Model 实现计划

### 19.1 结构

```systemverilog
typedef struct {
  bit          valid;
  logic [8:0]  tag_l1;      // vpn[2]
  logic [17:0] tag_l2;      // {vpn[2],vpn[1]}
  logic [27:0] ppn;
  int unsigned entry_idx;
} pde_cache_entry_t;
```

实际代码建议拆成两个数组：

```systemverilog
pde_cache_entry_t l1[16];
pde_cache_entry_t l2[16];
```

### 19.2 lookup 规则

1. 每个 accepted request 使用 committed old state lookup。
2. 一级 tag=`vpn[26:18]`。
3. 二级 tag=`{vpn[26:18],vpn[17:9]}`。
4. L1 hit：跳过 `fst_pmp/fst_chk`，从 `scd_pmp` 开始。
5. L2 hit：跳过 `fst_pmp/fst_chk/scd_pmp/scd_chk`，从 `thd_pmp` 开始。
6. 双命中：选择 L2 hit。
7. hit data 只提供下一级 page table PPN；不携带 ASID/G/RSW/权限/属性/A/D。

### 19.3 update 规则

PDE cache update 条件：

1. raw PTE 为 non-leaf。
2. 无 page fault。
3. 无 PMP access fault。
4. 无 LSU bus error。
5. 未被 reset、`tlboper_ptw_abort` 或其他 flush 屏蔽。
6. 当前 level 是 FST 或 SCD；THD non-leaf 是 page fault，不 update。

update 内容：

1. FST non-leaf：更新 L1 PDE cache，tag=`vpn[2]`，data=`pte.ppn`。
2. SCD non-leaf：更新 L2 PDE cache，tag=`{vpn[2],vpn[1]}`，data=`pte.ppn`。
3. L1 PDE hit 后，SCD 返回 non-leaf 且无异常时，仍更新 L2 PDE cache。
4. leaf/page fault/access fault/drop 不更新。

### 19.4 clear/abort/context 规则

| 事件 | PDE cache | in-flight request |
| --- | --- | --- |
| reset | 全清 | 全部 drop |
| `tlboper_ptw_abort` | 全清；当拍 update 屏蔽 | 未获授权输出全部 drop |
| satp 任意字段改变 | 全清 | 不 flush；旧 walk 可继续 |
| PMP 配置改变 | 全清 | 不 flush；旧 walk 可继续 |

satp/PMP 改变后，旧 in-flight walk 若后续返回 non-leaf 且未被 abort/reset 屏蔽，允许重新 update PDE cache。scoreboard 不得把这种 update 判错。

### 19.5 replacement/victim 策略

建议分两种模式：

1. Directed strict 模式：PDE cache 每级不超过 16 个 live unique entry，不触发 victim 歧义；ref model 自己维护全相联内容即可。
2. Whitebox sync 模式：从 PDE update monitor 读取实际 update entry/victim/tag/data，同步 ref model；用于随机/替换压力。

若无法观测 update entry/victim，则 replacement 后的 hit/miss 预测会有歧义。此时必须：

1. directed closure 避免超过 16 entry 替换。
2. 随机压力只把 source scoreboard 结果作为部分 evidence。
3. PDE replacement requirement 由 `mmu_pde_cache_sva.sv` 或 whitebox monitor 单独关闭。

## 20. MAEE、Sysmap 与 Degrade 实现计划

### 20.1 MAEE 使用点

MAEE 在 leaf CHK 时决定走 raw PTE attr 还是 sysmap/degrade。进入 MAEE=0 sysmap/degrade 流程后，即使后续 MAEE 改变，最终 refill 仍使用 sysmap/degrade 结果，不回退到 raw PTE attr。

### 20.2 MAEE=1

实现规则：

1. 1G/2M/4K leaf 都直接使用 raw PTE `PTE[63:59]={So,C,B,Sh,Sec}`。
2. 不访问 sysmap。
3. 不做 1G/2M 跨 region 降级。
4. 仍执行 huge align、权限、U/S、A/D、write-only 检查。
5. refill page_size 等于 leaf level 原始 page size。

### 20.3 MAEE=0

实现规则：

1. 所有 leaf page size 的 refill ext attr 都来自 sysmap，包括 4K。
2. 1G/2M 先检查 huge align；align fault 直接 page fault。
3. sysmap 以最终 4K PPN 判断 region；offset 不参与。
4. sysmap 无命中/多命中视为非法 stimulus，不映射成 PTW fault。

### 20.4 1G 降级

1G leaf 初始 PPN：

```text
leaf_1g_ppn = {pte.ppn[2], 9'b0, 9'b0}
first_4k_ppn = {pte.ppn[2], 9'b0,   9'b0}
last_4k_ppn  = {pte.ppn[2], 9'h1ff, 9'h1ff}
```

规则：

1. 首尾同 sysmap region：不降级，`page_size=1G`，`ppn=leaf_1g_ppn`，ext attr 取尾地址 region flg。
2. 首尾不同 region：先降级为 2M：

```text
degrade_2m_ppn = {pte.ppn[2], vpn[1], 9'b0}
```

3. 对降级后的 2M 再做首尾 region 检查。
4. 若该 2M 同 region：最终 `page_size=2M`，`ppn=degrade_2m_ppn`，ext attr 取该 2M 尾地址 region flg。
5. 若该 2M 仍跨 region：继续降级为 4K：

```text
degrade_4k_ppn = {pte.ppn[2], vpn[1], vpn[0]}
```

最终 `page_size=4K`，ext attr 取最终 4K PPN 所在 region flg。

### 20.5 2M 降级

2M leaf 初始 PPN：

```text
leaf_2m_ppn = {pte.ppn[2], pte.ppn[1], 9'b0}
first_4k_ppn = {pte.ppn[2], pte.ppn[1], 9'b0}
last_4k_ppn  = {pte.ppn[2], pte.ppn[1], 9'h1ff}
```

规则：

1. 首尾同 sysmap region：不降级，`page_size=2M`，`ppn=leaf_2m_ppn`，ext attr 取尾地址 region flg。
2. 首尾不同 region：降级为 4K：

```text
degrade_4k_ppn = {pte.ppn[2], pte.ppn[1], vpn[0]}
```

最终 `page_size=4K`，ext attr 取最终 4K PPN 所在 region flg。

### 20.6 4K sysmap

4K leaf 在 MAEE=0 时不降级，但必须查 sysmap：

```text
final_ppn = pte.ppn[27:0]
ext_attr  = sysmap_lookup(final_ppn).flg
page_size = 3'b001
```

若 4K 是 1G/2M 降级得到的，`final_ppn` 使用降级后的 PPN，不再访问下一级页表。

## 21. Abort、Reset、Bus Error 与 Drop 实现计划

### 21.1 drop 必须显式建模

scoreboard 不能把未完成 expected 直接删除。只有命中以下规则时，才能把 pending request 转成 `PTW_EXP_DROPPED`：

1. reset flush。
2. `tlboper_ptw_abort` flush。
3. abort 同拍 ordinary data 返回被丢弃。
4. abort 同拍新 bus error 被屏蔽。
5. abort 后等待 LSU late response，返回后丢弃。

每个 drop 必须记录 `drop_reason`，并在 report 中计数。

### 21.2 reset

reset 行为：

1. 清空 PDE cache。
2. 所有 pending PTW request -> `PTW_EXP_DROPPED(PTW_DROP_RESET)`。
3. memory pending 清除；若 `ptw_mem_monitor.ap_drop` 发生，关联到对应 request。
4. reset 后禁止出现 stale refill/page fault/access fault/PDE update；若出现报 error。

### 21.3 `tlboper_ptw_abort`

abort 行为：

1. 当拍清空全部 PDE cache。
2. 冲刷 PDE cache lookup 中的 request。
3. 屏蔽 PDE cache update。
4. 清/flush TWU/mbuf/refill/page fault/access fault 待写路径。
5. normal refill 被屏蔽。
6. 未进入异常寄存器、未获顶层 grant 的新异常被屏蔽。
7. 只有 abort 到来前已经进入异常寄存器，并在 abort 当拍参与顶层仲裁且获 grant 的异常可以 visible。

scoreboard 实现：

1. `ptw_source_monitor` 必须输出 abort event，并标记当拍 visible completion。
2. 对没有 allowed visible completion 的 pending request，生成 `PTW_EXP_DROPPED(PTW_DROP_ABORT)`。
3. 对 allowed visible exception，保留 expected fault 并继续比较一次 actual fault。
4. abort 后若 L2TLB 重发同一 miss，应作为新的 accept/new expected，不和旧 dropped transaction 混合。

### 21.4 abort 与 LSU outstanding

边界定义：

```text
abort 前一拍 LSU request valid 已经为 1 => 必须保持 request valid/PA 到 response 返回。
```

scoreboard 检查：

1. abort 前一拍 LSU request valid 不是 1，且 request 尚未真正发出：可直接 drop，不期待 memory response。
2. abort 前一拍 LSU request valid 是 1：进入 wait-for-late-rsp/drop 状态。
3. late ordinary data：必须丢弃，不进 CHK、不 refill、不 update PDE。
4. abort 同拍 ordinary data：必须丢弃。
5. abort 同拍新 bus error：不上报 access fault，因为 abort 阻止写入 mbuf access exception register。
6. abort 前 bus error 已写入 access exception register，并在 abort 当拍 top arb grant：允许上报 access fault 一次。

### 21.5 bus error 无 abort

LSU bus error 无 abort 时：

1. 生成 `PTW_EXP_ACCESS_FAULT(PTW_FAULT_LSU_BUS_ERROR)`。
2. 不解码 raw PTE。
3. 不 page fault。
4. 不 refill。
5. 不 update PDE。
6. 返回目标按原始 `type/id`。

## 22. PTW Source Scoreboard 架构

### 22.1 组件职责

`ptw_source_sb` 负责：

1. 接收 ref model expected。
2. 接收 source monitor actual completion。
3. 接收 request/memory/abort/context 事件用于 illegal 检查和 debug。
4. 按 `{type,id}` 匹配 expected 与 actual。
5. 对 dropped transaction 检查 no visible stale output。
6. end-of-test 检查 pending/unmatched。
7. 输出 PTW source signoff report。

建议接口：

```systemverilog
class ptw_source_sb extends uvm_scoreboard;
  uvm_analysis_imp_expected #(ptw_expected_rsp_t, ptw_source_sb) af_expected;
  uvm_analysis_imp_actual   #(ptw_actual_rsp_t,   ptw_source_sb) af_actual;
  uvm_analysis_imp_req      #(ptw_req_accept_txn, ptw_source_sb) af_req;
  uvm_analysis_imp_mem_req  #(ptw_mem_txn,        ptw_source_sb) af_mem_req;
  uvm_analysis_imp_mem_rsp  #(ptw_mem_txn,        ptw_source_sb) af_mem_rsp;
  uvm_analysis_imp_mem_drop #(ptw_mem_txn,        ptw_source_sb) af_mem_drop;
endclass
```

### 22.2 matching 规则

匹配键固定：

```text
{type, id}
```

规则：

1. 每个 expected 放入 `expected_by_key[key]`。
2. 每个 actual completion 用 `{type,id}` 查找 expected。
3. 返回顺序允许乱序；不按 accept 顺序比较。
4. 同 key 若存在多个 outstanding expected，默认 illegal；正常 PTW 不允许旧请求完成/drop 前复用。
5. 若 actual 找不到 expected，报 unexpected output。
6. 若 expected kind 与 actual kind 不一致，报 class mismatch。
7. `PTW_EXP_DROPPED` 不期待 actual completion；若 drop 后出现同 key stale output，报 error，除非已记录为重发后的新 accept。
8. end-of-test expected map 非空报 error，除非全部为明确 drop/waiver。

### 22.3 completion class 解码

actual completion 必须区分：

| actual kind | visible 条件 | 说明 |
| --- | --- | --- |
| `PTW_EXP_REFILL` | refill grant/data valid 类信号有效，且 page/access fault 不有效 | 比较 tag/data/target。 |
| `PTW_EXP_PAGE_FAULT` | `ptw_l2tlb_ref_pgflt` | 不比较 refill data。 |
| `PTW_EXP_ACCESS_FAULT` | `ptw_l2tlb_ref_acc_err` | 不比较 refill data。 |

`ptw_l2tlb_cmplt` 只能作为 completion OR。若同拍 `refill/page_fault/access_fault` 多热，由 SVA 报协议错误；scoreboard 也应报 actual class illegal，不能任意择一。

### 22.4 refill 比较

`compare_refill(exp, act)` 必须逐字段比较：

1. `type`。
2. `id`。
3. `vpn`。
4. `asid`。
5. `page_size`。
6. `ppn`。
7. `global`。
8. `flg[13:0]`。
9. `refill_tag[47:0]` bit layout。
10. `refill_data[41:0]` bit layout。
11. `target_l2tlb`。
12. `target_l1itlb`。
13. `target_l1dtlb`。
14. `target_pfu`。

target 规则：

| type | 成功 refill 目标 |
| --- | --- |
| fetch `3'b011` | L1ITLB + L2TLB |
| load `3'b010` | L1DTLB + L2TLB |
| store/atomic `3'b110` | L1DTLB + L2TLB |
| PFU `3'b100` | L2TLB only |

PFU 成功时不得期待 L1I/L1D refill。fetch 的 `id[2:0]` 无 L1D entry 语义，但 PTW 输出完整 id 仍必须正确。

### 22.5 page/access fault 比较

`compare_fault(exp, act)` 必须比较：

1. `kind`：page fault 或 access fault。
2. `type`。
3. `id`。
4. target/释放路径。
5. `fault_kind`，若 DUT 不输出细分类，则至少用 source trace 判定 root cause 并在 report 中记录。
6. 禁止同时出现 refill data valid。

page fault 不比较 `ppn/flg/page_size`。access fault 不比较 `ppn/flg/page_size`，并且若 root cause 是 PMP/bus error，应检查没有后续 CHK/PDE update/refill。

### 22.6 drop/no-output 比较

对 `PTW_EXP_DROPPED`：

1. 不期待 normal refill。
2. 不期待新 page fault。
3. 不期待新 access fault。
4. 不期待 PDE update。
5. 若 memory late response 返回普通 data，记录为 consumed/drop，不产生 mismatch。
6. 若 drop 后上游重发同 `{type,id}`，重发 accept 创建新 expected；旧 dropped transaction 已关闭。

### 22.7 mismatch 分类

report 中 mismatch 必须按字段分类：

```text
PTW_SB_MISMATCH kind
PTW_SB_MISMATCH type
PTW_SB_MISMATCH id
PTW_SB_MISMATCH vpn
PTW_SB_MISMATCH asid
PTW_SB_MISMATCH page_size
PTW_SB_MISMATCH ppn
PTW_SB_MISMATCH global
PTW_SB_MISMATCH flg
PTW_SB_MISMATCH refill_tag
PTW_SB_MISMATCH refill_data
PTW_SB_MISMATCH target
PTW_SB_MISMATCH fault_kind
PTW_SB_MISMATCH unexpected_output
PTW_SB_MISMATCH pending_at_eot
PTW_SB_MISMATCH illegal_stimulus
```

每条 mismatch 日志必须打印 `type/id/vpn/accept_cycle/done_cycle/level trace/PTE raw/PMP/sysmap/PDE hit`，方便定位。

## 23. Monitor 与 Probe 实现计划

### 23.1 `ptw_source_monitor.svh`

`ptw_source_monitor` 使用 `virtual mmu_dut_probes_if`，在 `run_phase` 每拍采样并输出 transaction。

analysis ports：

```systemverilog
uvm_analysis_port #(ptw_req_accept_txn) ap_req_accept;
uvm_analysis_port #(ptw_actual_rsp_t)   ap_actual_rsp;
uvm_analysis_port #(ptw_abort_txn)      ap_abort;
uvm_analysis_port #(ptw_pde_evt_t)      ap_pde_evt;
uvm_analysis_port #(ptw_ctx_sample_t)   ap_ctx;
```

采样内容：

1. request accept：`l2tlb_ptw_req && ptw_jtlb_ready`，字段 `vpn/type/id`。
2. output completion：refill/page fault/access fault class、`type/id`、tag/data、target bits。
3. abort/reset：`tlboper_ptw_abort`、reset edge、可见 grant。
4. PDE event：lookup hit level、double-hit、update level/tag/data/entry、clear reason。
5. context sample：active satp PPN/ASID、MXR/SUM/priv/MPRV/MPP/MAEE。
6. debug trace：TWU level、PMP PA/deny、sysmap result、raw PTE/level。

### 23.2 必须补齐的 probe

若现有 `mmu_dut_probes_if.sv` 缺少以下字段，必须补齐：

| probe | 用途 | 缺失影响 |
| --- | --- | --- |
| `l2tlb_ptw_vpn` | request expected key/context | 无法可靠建模 PTE PA。 |
| `l2tlb_ptw_type`、`l2tlb_ptw_id`、`ptw_jtlb_ready` | request accept | 无法按 `{type,id}` 匹配。 |
| `ptw_arb_ref_tag_din` | refill tag bit layout | 无法检查 ASID/global/page_size/vpn。 |
| `ptw_arb_ref_data_din` | refill data/flg bit layout | 无法检查 flg、RSW、G not in flg。 |
| visible refill valid/grant | completion class | 无法区分 refill 与 cmplt OR。 |
| `ptw_l2tlb_ref_pgflt`、`ptw_l2tlb_ref_acc_err` | fault class | 无法区分 page/access fault。 |
| `ptw_l2tlb_type/id` 或等价输出字段 | actual key | 无法匹配 expected。 |
| `ptw_l1i_ref_cmplt`、`ptw_l1d_ref_cmplt`、`ptw_l1d_ref_id` | target check | 无法关闭 target requirement。 |
| `tlboper_ptw_abort` | drop/abort | 无法正确关闭 abort tests。 |
| PDE lookup hit L1/L2、double-hit | start level | 无法验证 skip-level。 |
| PDE update level/tag/data/entry | ref PDE sync | 随机 replacement 后无法预测 hit。 |
| PDE clear reason | reset/satp/PMP/abort clear | 无法区分 clear/drop。 |
| PMP PA/type/flg/deny per level | PMP source check | 无法证明 PTE PA PMP。 |
| raw PTE + level 或 mbuf data/level | PTE decode debug | mismatch 难定位；SVA 也无法闭环。 |
| sysmap hit/flg/final PPN | MAEE=0/degrade | 无法关闭 all-size sysmap/degrade。 |

当前已知 gap：`pmp_regs_update` 在 `tb_top` 可能接常 0，这会阻塞 “PMP 配置改变清 PDE cache” 的真实验证。必须修正为可驱动/可观测，或把该项明确 open，不能用常 0 环境签核。

### 23.3 probe 添加原则

1. 只在 `tb_top.sv` 做层级 assign。
2. env/package/class 中只使用 virtual interface，不直接 `$root`。
3. probe 不进入 DUT functional path。
4. 对高扇出 internal bus 优先采样到 monitor transaction，避免在 scoreboard 里每处读取 vif。
5. probe 命名应保持 PTW source 语义，例如 `ptw_src_*` 或沿用 RTL 端口名。

## 24. Env/Package/Connect 修改计划

### 24.1 `mmu_env_pkg.sv` include 顺序

建议顺序：

```systemverilog
`include "mmu_top_cfg.svh"
`include "mmu_page_table_mem.svh"
`include "mmu_ref_model.svh"
`include "ptw_source_types.svh"
`include "ptw_pde_cache_model.svh"
`include "ptw_source_ref_model.svh"
`include "ptw_source_monitor.svh"
`include "ptw_source_sb.svh"
`include "mmu_translation_sb.svh"
...
`include "mmu_env.svh"
```

若使用独立 `ptw_source_types_pkg.sv`，则该 package 必须在 `mmu_env_pkg.sv` 前编译，并在 `mmu_env_pkg` 内 `import ptw_source_types_pkg::*;`。

### 24.2 `mmu_env.svh` build

新增成员：

```systemverilog
ptw_source_monitor   m_ptw_source_mon;
ptw_source_ref_model m_ptw_source_ref;
ptw_source_sb        m_ptw_source_sb;
```

build 规则：

1. `m_ptw_source_mon` 在 `en_ptw_source_sb || en_ptw_source_ref_model` 时创建。
2. `m_ptw_source_ref` 在 `en_ptw_source_ref_model` 时创建。
3. `m_ptw_source_sb` 在 `en_ptw_source_sb` 时创建，并注入 cfg。
4. `m_ptw_source_ref` 不复用 `m_ref.translate()`；可共享 `m_pt_mem` 指针仅用于 debug，不作为 raw PTE golden 来源。
5. 若 probe vif 缺失，monitor 可以 idle，但 source checker 必须报无法关闭 source requirement。

### 24.3 `mmu_env.svh` connect

必须连接：

```systemverilog
// Existing context monitor fanout
m_cp0.m_monitor.ap.connect(m_ptw_source_ref.af_csr_write.analysis_export);
m_pmp.m_monitor.ap.connect(m_ptw_source_ref.af_pmp_cfg.analysis_export);
m_sysmap_cfg.m_monitor.ap.connect(m_ptw_source_ref.af_sysmap_cfg.analysis_export);

// PTW memory channel
m_ptw_mem.m_monitor.ap_req.connect(m_ptw_source_ref.af_ptw_mem_req.analysis_export);
m_ptw_mem.m_monitor.ap_rsp.connect(m_ptw_source_ref.af_ptw_mem_rsp.analysis_export);
m_ptw_mem.m_monitor.ap_drop.connect(m_ptw_source_ref.af_ptw_mem_drop.analysis_export);

// Source monitor to ref/sb
m_ptw_source_mon.ap_req_accept.connect(m_ptw_source_ref.af_req_accept.analysis_export);
m_ptw_source_mon.ap_abort.connect(m_ptw_source_ref.af_abort.analysis_export);
m_ptw_source_ref.ap_expected.connect(m_ptw_source_sb.af_expected);
m_ptw_source_mon.ap_actual_rsp.connect(m_ptw_source_sb.af_actual);

// Optional debug fanout
m_ptw_source_mon.ap_req_accept.connect(m_ptw_source_sb.af_req);
m_ptw_mem.m_monitor.ap_req.connect(m_ptw_source_sb.af_mem_req);
m_ptw_mem.m_monitor.ap_rsp.connect(m_ptw_source_sb.af_mem_rsp);
m_ptw_mem.m_monitor.ap_drop.connect(m_ptw_source_sb.af_mem_drop);
```

若 SystemVerilog analysis imp suffix 已占用，新增 suffix 时必须放在 package/include 的 class 外部，避免宏重复冲突。

### 24.4 与现有 `m_ref` 的关系

1. `m_ref` 继续由 `mmu_translation_sb` 使用。
2. `m_ptw_source_ref` 自己维护 CSR/PMP/sysmap mirror，避免与 `m_ref.sync_shadow_state()` 的 FIFO drain 产生多消费者 race。
3. CP0/PMP/sysmap monitor analysis port 可以 fanout 到两个 ref model，各自拥有独立 FIFO。
4. 若后续重构，可把 CSR/PMP/sysmap mirror 抽成共享 helper；本计划不强制重构，以降低风险。

## 25. Reference Model API 与实现顺序

### 25.1 推荐核心函数

```systemverilog
function void on_req_accept(ptw_req_accept_txn tr);
function void on_mem_req(ptw_mem_txn tr);
function void on_mem_rsp(ptw_mem_txn tr);
function void on_abort(ptw_abort_txn tr);
function void on_reset();
function void on_csr_write(cp0_txn tr);
function void on_pmp_cfg(pmp_txn tr);
function void on_sysmap_cfg(sysmap_cfg_txn tr);

protected function void start_walk(ptw_req_key_t key);
protected function logic [39:0] calc_pte_pa(ptw_walk_state_t st, ptw_level_e lvl);
protected function bit pmp_deny(ptw_walk_state_t st, logic [39:0] pte_pa, ptw_level_e lvl);
protected function void handle_pte_data(ptw_req_key_t key, logic [63:0] pte_raw);
protected function bit is_leaf(logic [63:0] pte_raw);
protected function bit page_fault(...);
protected function ptw_expected_rsp_t build_refill(...);
protected function ptw_expected_rsp_t build_fault(...);
protected function void publish_expected(ptw_expected_rsp_t exp);
```

### 25.2 MVP 到完整实现顺序

| Step | 目标 | 退出条件 |
| --- | --- | --- |
| R1 | 类型、monitor skeleton、env/package/config 接入 | compile 通过；source monitor 能打印 request/output。 |
| R2 | basic request/refill scoreboard | 1G/2M/4K MAEE=1 no fault directed 能 match。 |
| R3 | PTE page fault 矩阵 | V/write-only/U/S/A/D/X/R/W/PFU/huge align directed match。 |
| R4 | PMP/access fault 与 PTW memory bus error | fst/scd/thd/type/effective-mode/PFU/bus_error directed match。 |
| R5 | PDE cache model | miss/L1 hit/L2 hit/double-hit/update/clear directed match。 |
| R6 | MAEE=0 sysmap/degrade | 4K sysmap、1G->2M、1G->4K、2M->4K、不降级 directed match。 |
| R7 | abort/reset/drop | no outstanding、outstanding、same-cycle data、same-cycle bus error、pre-existing exception grant directed match。 |
| R8 | random/regression/report | P0/P1 list source scoreboard 0 mismatch；report 可被脚本解析。 |

每一步都必须保持已有 `mmu_translation_sb` regressions 不被破坏。

## 26. Test、SVA 与 Scoreboard 闭环关系

统一闭环要求：

| 测试类 | source checker 关闭点 |
| --- | --- |
| raw PTE/RSW/high reserved | `flg[8:7]`、no page fault、G not in flg、reserved ignored。 |
| type/id/target | `{type,id}` matching、L1/L2/PFU target compare。 |
| PDE cache | start level、skip-level no mem request、update/clear/drop report。 |
| PMP | PTE PA、type permission、MPRV/MPP effective mode、access fault no side effect。 |
| PTE permission | page fault kind、PFU special permission、write-only/MXR rule。 |
| MBUF/LSU/bus error | memory addr alignment、raw PTE response、bus error access fault。 |
| MAEE/sysmap/degrade | ext_attr、final page_size/PPN、no lower walk、4K sysmap。 |
| abort/reset | dropped transaction、no stale output、late LSU response discard。 |
| full flow trace | `levels[$]` trace、PDE/PMP/PTE/MAEE/refill end-to-end source evidence。 |

回归 signoff 中，P0 test 必须至少满足：

1. test pass。
2. P0 SVA 0 fail。
3. `ptw_source_sb` 对应 scenario 至少 1 个 match。
4. 若 scenario 是 drop，`ptw_source_sb` 至少 1 个 expected drop 且无 stale output。
5. report 中无 illegal stimulus，除非 test 显式标 illegal-stress。

## 27. Report 与 Signoff 输出计划

`ptw_source_sb` final report 必须输出机器可读摘要：

```text
PTW_SOURCE_SB_SUMMARY accepted=<N> matched=<N> mismatch=<N> pending=<N> illegal=<N>
PTW_SOURCE_SB_KIND refill=<N> page_fault=<N> access_fault=<N> dropped=<N>
PTW_SOURCE_SB_TYPE fetch=<N> load=<N> store=<N> pfu=<N>
PTW_SOURCE_SB_MISMATCH_FIELD kind=<N> vpn=<N> asid=<N> page_size=<N> ppn=<N> global=<N> flg=<N> target=<N> fault_kind=<N>
PTW_SOURCE_SB_PDE l1_hit=<N> l2_hit=<N> double_hit=<N> l1_update=<N> l2_update=<N> reset_clear=<N> abort_clear=<N> satp_clear=<N> pmp_clear=<N>
PTW_SOURCE_SB_PMP allow=<N> deny=<N> fst=<N> scd=<N> thd=<N> fetch=<N> load=<N> store=<N> pfu=<N>
PTW_SOURCE_SB_PTE leaf_1g=<N> leaf_2m=<N> leaf_4k=<N> nonleaf=<N> write_only_fault=<N> pfu_pass=<N>
PTW_SOURCE_SB_MAEE maee1=<N> maee0_4k=<N> maee0_1g_keep=<N> maee0_1g_to_2m=<N> maee0_1g_to_4k=<N> maee0_2m_keep=<N> maee0_2m_to_4k=<N>
PTW_SOURCE_SB_ABORT reset_drop=<N> abort_drop=<N> late_data_drop=<N> abort_bus_error_drop=<N> granted_exception=<N>
```

每个 mismatch 详细日志格式：

```text
PTW_SOURCE_SB_ERROR field=<field> key={type,id} vpn=<vpn> exp=<...> act=<...>
  accept_cycle=<...> actual_cycle=<...>
  pde={l1_hit,l2_hit,start_level}
  levels=[{lvl,pte_addr,pte_raw,pmp_deny,bus_error,leaf,page_fault,fault_kind}, ...]
  maee/sysmap/degrade=<...>
```

回归脚本 gate：

1. `PTW_SOURCE_SB_SUMMARY mismatch=0`。
2. `pending=0`。
3. `illegal=0`，非法/stress list 除外。
4. P0 scenario expected kind 覆盖全部命中。
5. P0 field coverage 中 `flg/global/page_size/ppn/fault_kind/target` 均有非零 compare。

## 28. Source Checker 风险与阻塞项

| 风险 | 影响 | 处理计划 |
| --- | --- | --- |
| request VPN probe 缺失 | 无法计算 PTE PA，source model 不可信 | 补 `l2tlb_ptw_vpn` 或从 L2MB accepted entry 重建；否则 source checker不签核。 |
| refill data/tag probe 缺失 | 无法 bit-exact 比较 flg/ASID/G/RSW | 补 `ptw_arb_ref_tag_din`、`ptw_arb_ref_data_din`；临时只能 semantic partial，不关闭 P0。 |
| PDE replacement victim 不可见 | 随机替换后 hit/miss 预测歧义 | directed 避免超过 16 entry；随机用 whitebox update entry 同步；PLRU 由 SVA 关闭。 |
| abort 同拍 visible exception 难判定 | drop 与 allowed fault 可能误判 | monitor 增加 top arb grant/exception register valid probe；无法观测时该子项 open。 |
| CSR/PMP/sysmap 使用点采样与 monitor FIFO ordering | 同拍 context change 可能误采样 | 所有 context sample transaction 带 cycle；按固定 ordering；模糊窗口用 directed 约束或 SVA。 |
| `pmp_regs_update` 常 0 | PMP config change 清 PDE cache 无法验证 | 必须接真实驱动/monitor；否则 `PDE clear by PMP` open。 |
| existing `mmu_ref_model` FIFO drain 与新 ref model 竞争 | shadow context 不一致 | 新 ref model 使用独立 analysis FIFO，analysis port fanout，不共享 FIFO。 |
| legacy tests 仍使用错误 expected | source scoreboard 会报大量 mismatch | 回归先跑 `ptw_p0_list`；旧 tests 逐个标 obsolete/modify/waive scope。 |
| PTW visible output字段命名不统一 | monitor 接入慢 | 先实现 transaction schema 和 probe gap 表，再逐字段 bind/assign。 |

## 29. Source Checker 完成判据

source checker 可签核条件：

1. 新增 `ptw_source_types`、`ptw_pde_cache_model`、`ptw_source_ref_model`、`ptw_source_monitor`、`ptw_source_sb` 已接入编译和 env。
2. `mmu_top_cfg` 可独立开关 PTW source ref/sb，默认回归打开。
3. `ptw_source_ref_model` 不调用 `mmu_ref_model.translate()` 生成 PTW expected。
4. `ptw_mem_monitor.ap_req/ap_rsp/ap_drop` 已 fanout 到 PTW source checker，raw PTE 和 bus error 均来自实际 response。
5. P0 directed tests 的 refill/page fault/access fault/drop 全部由 `ptw_source_sb` match。
6. `ptw_source_sb` 比较 `vpn/asid/page_size/ppn/global/flg/type/id/target/fault_kind`，并按字段输出 mismatch。
7. PDE cache miss/L1 hit/L2 hit/double-hit/update/clear/drop 均有 source evidence 或 SVA evidence。
8. MAEE=1 all-size、MAEE=0 4K sysmap、1G->2M、1G->4K、2M->4K、不降级路径均由 source scoreboard 比较 final `page_size/ppn/flg`。
9. PMP fst/scd/thd、fetch/load/store/PFU、MPRV/MPP effective privilege、PMP config clear PDE 均有 evidence；若 `pmp_regs_update` 仍不可驱动，必须明确 open。
10. abort/reset/drop 矩阵无 stale refill/fault/PDE update，late LSU response discard 被 report。
11. `PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0`，非法/stress list 除外。
12. `mmu_translation_sb` 仍通过原有 consumer-side regressions，且文档/report 明确它只是补充 evidence。
13. 回归报告能同时列出 SVA cover 和 source scoreboard match，形成 PTW source-side closure 表。
