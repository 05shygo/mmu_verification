# PTW PDE Cache PMP Flag UVM 修改实施计划

本文档根据 `ptw_pde_cache_pmpflg_design_change.md` 中冻结的 RTL 设计语义，制定现有 UVM 验证环境的修改计划。目标是让 PTW source-side reference model、monitor、scoreboard、SVA、directed tests、regression gate 都能精确覆盖 “PDE cache entry 携带 page-table memory PMP evidence，并在 lookup 时按当前 request type 重新解释” 这一设计变更。

本文档只描述实施计划，不直接修改 RTL/UVM 源码。

## 1. 范围和输入

### 1.1 输入文档

| 文档 | 用途 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_design_change.md` | 本次 RTL 设计变更的冻结语义、信号流、测试点审查结论。 |
| `doc/ptw_uvm_review/ptwspec.md` | 既有 PTW 测试点、source-side closure 规则、PDE cache/SVA 规范。 |
| `mmu_verification/testbench/env/ptw_pde_cache_model.svh` | 现有 PDE cache 抽象模型，目前为 tag-only lookup。 |
| `mmu_verification/testbench/env/ptw_source_types.svh` | PTW source-side transaction 与 enum 定义。 |
| `mmu_verification/testbench/env/ptw_source_monitor.svh` | PTW source-side monitor，当前仅采样 PDE hit/miss/update/clear。 |
| `mmu_verification/testbench/env/ptw_source_ref_model.svh` | PTW source-side reference model，当前未建模 cached pmpflg hit/deny。 |
| `mmu_verification/testbench/env/ptw_source_sb.svh` | PTW source-side scoreboard，当前 coverage 未区分 PDE cached PMP deny。 |
| `mmu_verification/testbench/top/mmu_pde_cache_sva.sv` | PDE cache SVA，当前只覆盖 clear、hit level、PPN、update level、ready 等旧规则。 |
| `mmu_verification/testbench/top/mmu_arb_sva.sv`、`mmu_ptw_top_sva.sv` | completion/fault priority 相关 SVA。 |
| `mmu_verification/testbench/env/mmu_dut_probes_if.sv`、`testbench/top/tb_top.sv` | whitebox probe 接口和 DUT 内部信号连接。 |
| `mmu_verification/testbench/test/ptw_tests/*` | PTW directed tests 和 suite include。 |
| `mmu_verification/simu/ptw_p0_list`、`ptw_p1_list`、`ptw_p0_smoke_list` | 现有 regression list。 |
| `mmu_verification/scripts/ptw_stage8_signoff_gate.py` | 现有 PTW signoff gate。 |

### 1.2 本计划只覆盖 PTW UVM

本计划不覆盖以下内容：

1. RTL bug 修复或 RTL 重构。
2. 非 PTW consumer-side scoreboard 的全面重构。
3. L1DTLB/L1ITLB/L2TLB 自身功能测试点重写。
4. PMP agent 的底层协议语义变更，除非为了驱动本次 PTW 场景需要新增 helper。

consumer-side `mmu_translation_sb`、`mmu_l1dtlb_spec_sb` 只能作为补充 evidence。关闭本次变更必须以 PTW source-side expected match、PDE/PMP monitor evidence、SVA cover/assertion 为主。

## 2. 设计语义冻结

### 2.1 PMP flag bit 解释

`pmpflg[3:0]` 保存的是 page-table memory 访问当时 PMP 返回的 evidence，不是 leaf PTE permission，也不是 request type 固定结论。

| bit | 语义 | 当前 request type 使用方式 |
| --- | --- | --- |
| `pmpflg[0]` | R | `LOAD` 和 `PFU` 复用 PDE cache 时需要该 bit 为 1，除非 effective M-mode bypass 生效。 |
| `pmpflg[1]` | W | `STORE` 复用 PDE cache 时需要该 bit 为 1，除非 effective M-mode bypass 生效。 |
| `pmpflg[2]` | X | `FETCH` 复用 PDE cache 时需要该 bit 为 1，除非 effective M-mode bypass 生效。 |
| `pmpflg[3]` | machine lock/deny | `0` 表示 effective M-mode 可 bypass type bit；`1` 表示 effective M-mode 不可 bypass，仍按 type bit 判断。 |

当前 request type 到 permission bit 的映射必须全 UVM 统一：

```systemverilog
function automatic bit ptw_src_pde_pmp_type_bit_allow(
  input ptw_src_req_type_e req_type,
  input logic [3:0]        pmpflg
);
  case (req_type)
    PTW_SRC_TYPE_LOAD,
    PTW_SRC_TYPE_PFU:   return pmpflg[0];
    PTW_SRC_TYPE_STORE: return pmpflg[1];
    PTW_SRC_TYPE_FETCH: return pmpflg[2];
    default:            return 1'b0;
  endcase
endfunction
```

effective M-mode bypass 必须只在 `effective_m == 1 && pmpflg[3] == 0` 时成立。

```systemverilog
function automatic bit ptw_src_pde_pmp_allow(
  input ptw_src_req_type_e req_type,
  input logic [3:0]        pmpflg,
  input bit                effective_m
);
  return ptw_src_pde_pmp_type_bit_allow(req_type, pmpflg)
      || (effective_m && !pmpflg[3]);
endfunction
```

### 2.2 L1 PDE cache lookup 语义

L1 PDE entry 保存第一级 page-table memory 访问的 `l1pmpflg`。

L1 lookup 的完整命中条件：

```text
entry.valid && l1_tag_match && pde_pmp_allow(current_type, entry.l1pmpflg, effective_m)
```

L1 tag match 但 cached `l1pmpflg` deny 当前 request type 时：

1. 不算 L1 PDE hit。
2. 不产生 PDE cache direct access fault。
3. 请求继续进入 `fst_pmp`。
4. 若实时 FST PMP 对当前 request type deny，则由普通 TWU PMP access fault path 返回。
5. 若实时 FST PMP allow，则可正常发 LSU 读取 FST page-table memory。

UVM 不能把该场景建模成 direct access fault，也不能把它作为 tag-only hit。

### 2.3 L2 PDE cache lookup 语义

L2 PDE entry 保存两级 page-table memory 访问的 PMP evidence：

```text
entry.l1pmpflg = 生成该 L2 PDE 时继承的第一级 page-table memory PMP flag
entry.l2pmpflg = 生成该 L2 PDE 时第二级 page-table memory PMP flag
```

L2 lookup 的完整命中条件：

```text
entry.valid &&
l2_tag_match &&
pde_pmp_allow(current_type, entry.l1pmpflg, effective_m) &&
pde_pmp_allow(current_type, entry.l2pmpflg, effective_m)
```

L2 valid tag match 但任一级 cached PMP flag deny 当前 request type 时：

1. 不算 L2 PDE hit。
2. 不回退使用 L1 PDE hit。
3. 不重新进入 FST/SCD PMP/LSU page-table read。
4. PDE cache 直接产生 access fault pending。
5. PTW 顶层 completion class 为 access fault。
6. 返回 `type/id` 必须来自当前触发 L2 tag-hit deny 的 PTW request。

这是本次 UVM 修改最重要的 golden 行为差异。

### 2.4 update payload 语义

PDE cache update 的 pmpflg payload 必须按来源 level 解释：

| 来源 | MBUF 保存的 8-bit payload | PDE cache update |
| --- | --- | --- |
| FST non-leaf | `{4'b0, l1pmpflg}` | 更新 L1 PDE cache，保存 `l1pmpflg=payload[3:0]`，`payload[7:4]` 应为 0。 |
| SCD non-leaf | `{l2pmpflg, l1pmpflg}` | 更新 L2 PDE cache，保存 `l1pmpflg=payload[3:0]`、`l2pmpflg=payload[7:4]`。 |
| THD leaf 或 THD fault | `8'b0` | 不更新 PDE cache。 |

leaf、page fault、LSU bus error、abort/reset 屏蔽的数据返回都不得更新 PDE cache，也不得更新 cached pmpflg。

### 2.5 clear 与 stale 规则

PDE cache 仍在以下事件下清空：

```text
regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update
```

本次 pmpflg tagging 不是替代 PMP update clear，而是补充 “PMP 配置未变但 request type 改变” 的复用合法性检查。

清空后：

1. 旧 entry valid 必须为 0。
2. invalid entry 即使 tag/pmpflg 寄存器保留旧值，也不能产生 hit 或 direct accerr。
3. satp/PMP clear-only 不 flush in-flight walk；旧 in-flight non-leaf 返回仍允许重新 update，但必须使用该 MBUF entry 保存的 pmpflg evidence。
4. reset/tlboper abort 需要 flush 或屏蔽 in-flight update 和 direct accerr pending。

### 2.6 priority 语义

L2 PDE direct access fault 是 PTW access fault 的一个新来源。UVM 必须按 RTL 冻结语义建模：

1. fault class 是 `PTW_SRC_EXP_ACCESS_FAULT`。
2. visible `fault_kind` 可以保持为 `PTW_SRC_FAULT_ACCESS`，但需要单独记录 root cause 为 PDE cache PMP deny。
3. `type/id` 来自当前 PDE lookup request。
4. 如果与 MBUF bus error、TWU access fault 同周期竞争，按设计文档要求验证 PDE direct accerr 优先级。
5. priority 检查必须覆盖 pending 不被未 grant 的新请求覆盖。

## 3. 现有 UVM 缺口

### 3.1 transaction 缺口

`ptw_source_types.svh` 当前状态：

1. `ptw_src_pde_evt_kind_e` 只有 `HIT/UPDATE/CLEAR/MISS`，无法表达 L2 direct accerr、tag hit but permission deny。
2. `ptw_src_pde_evt_txn` 只有 hit/update/clear 的基础字段，没有 cached `l1pmpflg/l2pmpflg`、tag hit、permission allow、deny reason、direct accerr type/id。
3. `ptw_src_expected_rsp_txn` 只有 generic `fault_kind`，不能区分 access fault root cause 是 TWU PMP、MBUF bus error、PDE cache cached PMP deny。
4. `ptw_src_level_evt_txn` 没有 MBUF 8-bit pmpflg payload，无法证明 FST/SCD pmpflg propagation。

### 3.2 PDE model 缺口

`ptw_pde_cache_model.svh` 当前状态：

1. `pde_entry_s` 只有 `valid/tag/ppn/age`。
2. `lookup()` 只按 tag 返回 L1/L2 hit，L2 hit wins。
3. `queue_update()` 和 `commit_update()` 不保存 pmpflg。
4. 没有区分 raw tag hit、permission-qualified hit、L1 permission miss、L2 direct accerr。
5. PLRU/age 更新当前基于 tag-only hit，无法保证 tag hit but PMP deny 不更新 read-hit PLRU。

### 3.3 monitor/probe 缺口

`mmu_dut_probes_if.sv` 和 `tb_top.sv` 当前状态：

1. 已有 `pde_cache_req/ready/clear`、`pde_l1_hit_vld/pde_l2_hit_vld`、`pde_xbar_*`、`pde_cache_update_*`、`pde_l1_update_vec/pde_l2_update_vec`。
2. 没有 `mbuf_cache_upd_l1pmpflg/l2pmpflg`。
3. 没有 `ptw_mbuf_twu_pmpflg` 或 selected TWU MBUF pmpflg payload。
4. 没有 PDE cache direct accerr `vld/type/id/grant`。
5. 没有 L1/L2 raw tag hit、per-entry cached pmpflg、L2 entry accerr vector。
6. 现有 `p13_pmp_flg_vec` 是 PMP port 观测，不足以证明 MBUF entry 保存和回传的 pmpflg payload。

### 3.4 ref model 缺口

`ptw_source_ref_model.svh` 当前状态：

1. `collect_level()` 在 non-leaf/no-fault 时调用 `m_pde_model.queue_update(level, vpn, ppn)`，没有 pmpflg。
2. `collect_pde()` 对 DUT PDE event 只 commit/update/lookup，不比较 permission-qualified behavior。
3. PDE lookup 结果不参与 expected completion 生成，因此无法为 L2 tag-hit deny 生成 expected access fault。
4. bus error/PMP deny/page fault/refill 的 completion 建模已经存在，但新增 PDE direct accerr 需要接入同一 completion path。
5. current context/effective M-mode 已有基础函数，需要复用于 cached pmpflg lookup。

### 3.5 scoreboard 和 coverage 缺口

`ptw_source_sb.svh` 当前状态：

1. access fault coverage 只统计 generic access/bus/page/drop。
2. 没有 L1 permission miss、L2 cached L1 deny、L2 cached L2 deny、effective M bypass/lock 的 coverage counters。
3. 没有 no-extra-LSU request 的 source-side evidence。
4. mismatch diff 不能指出 `pde_accerr_reason`，调试信息不足。

### 3.6 SVA 缺口

`mmu_pde_cache_sva.sv` 当前状态：

1. `PTW-SVA-PDE-003/004/005` 只检查 hit level 和 PPN，没有 permission-qualified hit 条件。
2. `PTW-SVA-PDE-006/008` 只检查 update level 和 old-state lookup，没有 pmpflg update old/new state。
3. 没有 L1 tag-hit deny must miss。
4. 没有 L2 tag-hit deny direct accerr。
5. 没有 direct accerr valid gate、pending clear、type/id stable、priority。
6. `PTW-SVA-PDE-010` 的旧表述 “PDE cache entry 不携带 permission/flg” 需要改成 “不携带 leaf permission/PTE flg，但携带 page-table memory PMP evidence”。

## 4. 总体实施原则

1. 先补 probe 和 transaction schema，再改 reference model。不能在信息不可观测的情况下用 consumer-side pass 代替 source-side closure。
2. PDE cache model 中必须同时保留 raw tag hit 和 permission-qualified hit。L1 和 L2 的 deny 行为不同，不能用同一个 “miss” 简化。
3. update evidence 必须从 MBUF payload 到 PDE cache entry 闭环，不能只从 PMP port 瞬时 flag 推断。
4. direct accerr 必须按 access fault completion 统一匹配 `{type,id}`，但 coverage/debug 需要单独标注 root cause。
5. 所有新增 tests 都应绑定 `PTW-ADD-037..045`、`PDE-TP-013..019`、`PTW-FLOW-024..028`。
6. 随机测试只作为补充。P0 directed test + source-side checker + SVA/cover 才能关闭本次设计变更。
7. 任何 tag-only hit 的旧 expected 必须修改或删除。

## 5. 分阶段实施计划

### Phase 0: probe 和 RTL 信号名审计

目标：确认 UVM 可以观测本次变更的所有必要信号。若 RTL 内部信号名与设计文档不同，先在本阶段建立准确映射。

需要读取或审计的文件：

| 文件 | 审计内容 |
| --- | --- |
| `mmu/rtl/L1PDE_cache.sv` | `L1PDE_upd_l1pmpflg`、entry `L1PDE_l1pmpflg`、raw tag hit、permission-qualified hit、`L1PDE_entry_hit` 的真实信号名。 |
| `mmu/rtl/L2PDE_cache.sv` | `L2PDE_upd_l1pmpflg/l2pmpflg`、entry pmpflg、raw tag hit、`L2PDE_entry_acc_err`、valid/request gate。 |
| `mmu/rtl/PDE_cache.sv` | `PDE_cache_acc_err_vld/type/id/grant`、pending type/id、xbar hit 优先级、update pmpflg 输入。 |
| `mmu/rtl/ptw_mbuf.sv`、`mbuf_entry.sv` | `twu_mbuf_pmpflg[7:0]`、`mbuf_entry_pmpflg[7:0]`、`mbuf_twu_pmpflg[7:0]`、PDE update pmpflg。 |
| `mmu/rtl/twu.sv` | FST/SCD/THD payload 生成、`fst_chk_l1pmpflg`、`scd_pmp_l1pmpflg` 真实信号名。 |
| `mmu/rtl/ptw.sv` | PDE direct accerr 接入 top access fault priority 的真实信号名。 |

建议新增 whitebox probe：

| probe 名称建议 | 位宽 | 来源 | 用途 |
| --- | --- | --- | --- |
| `pde_cache_update_l1pmpflg` | `[3:0]` | `ptw.mbuf_cache_upd_l1pmpflg` 或 PDE_cache input | monitor update payload。 |
| `pde_cache_update_l2pmpflg` | `[3:0]` | `ptw.mbuf_cache_upd_l2pmpflg` 或 PDE_cache input | monitor update payload。 |
| `ptw_mbuf_twu_pmpflg` | `[7:0]` | `ptw_mbuf.mbuf_twu_pmpflg` | 证明 MBUF entry 回传 payload。 |
| `ptw_twu_mbuf_pmpflg` | `[3:0][7:0]` | each TWU request payload | 证明 FST/SCD/THD 编码。 |
| `pde_cache_acc_err_vld` | `1` | `PDE_cache.PDE_cache_acc_err_vld` | monitor direct accerr event。 |
| `pde_cache_acc_err_type` | `[2:0]` | `PDE_cache.PDE_cache_acc_err_type` | direct accerr type/id 匹配。 |
| `pde_cache_acc_err_id` | `[5:0]` | `PDE_cache.PDE_cache_acc_err_id` | direct accerr type/id 匹配。 |
| `pde_cache_acc_err_grant` | `1` | `PDE_cache.PDE_cache_acc_err_grant` | pending clear 和 priority。 |
| `pde_l1_tag_hit_vec` | `[15:0]` | L1 raw tag hit vector | 区分 tag hit deny 与 tag miss。 |
| `pde_l2_tag_hit_vec` | `[15:0]` | L2 raw tag hit vector | 区分 tag hit deny 与 tag miss。 |
| `pde_l2_entry_acc_err_vec` | `[15:0]` | L2 entry direct accerr vector | direct accerr valid gate 和 deny entry。 |
| `pde_l1_entry_l1pmpflg` | `[15:0][3:0]` | L1 entry array | SVA/coverage。 |
| `pde_l2_entry_l1pmpflg` | `[15:0][3:0]` | L2 entry array | SVA/coverage。 |
| `pde_l2_entry_l2pmpflg` | `[15:0][3:0]` | L2 entry array | SVA/coverage。 |

文件修改计划：

1. `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
   - 增加上述 wire。
   - 在 `clocking mon_cb` 中增加 input。
   - 保持命名与 `tb_top.sv` assign 一致。
2. `mmu_verification/testbench/top/tb_top.sv`
   - 用 `assign dut_probes_if.* = u_dut.x_ct_mmu_ptw...` 连接新增 probe。
   - 若部分信号只在 bind module scope 可见，不强行接入 interface，转给 SVA 直接 `bind PDE_cache` 观测。
3. `doc/ptw_uvm_review/ptw_stage*_probe_gap_table.md`
   - 若实现阶段发现无法观测的信号，新增 gap 表或更新已有 gap 表，明确 waiver 不允许 consumer-only closure。

Phase 0 退出标准：

1. 新增 probe 编译通过。
2. `ptw_source_monitor` 可以采样 update pmpflg 和 direct accerr event。
3. 至少一个简单 PTW test 日志打印新增 probe 的 debug/cover 信息。
4. 若某个 probe 不可用，文档中必须记录替代 SVA 或 waiver。

建议命令：

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

### Phase 1: source transaction schema 扩展

目标：让 UVM transaction 能表达 cached pmpflg、permission-qualified lookup、direct accerr root cause。

修改文件：

```text
mmu_verification/testbench/env/ptw_source_types.svh
```

建议新增 enum：

```systemverilog
typedef enum int unsigned {
  PTW_SRC_PDE_REASON_NONE = 0,
  PTW_SRC_PDE_REASON_L1_TAG_MISS = 1,
  PTW_SRC_PDE_REASON_L2_TAG_MISS = 2,
  PTW_SRC_PDE_REASON_L1_PMP_DENY = 3,
  PTW_SRC_PDE_REASON_L2_L1PMP_DENY = 4,
  PTW_SRC_PDE_REASON_L2_L2PMP_DENY = 5,
  PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY = 6
} ptw_src_pde_reason_e;

typedef enum int unsigned {
  PTW_SRC_ACCESS_SRC_NONE = 0,
  PTW_SRC_ACCESS_SRC_TWU_PMP = 1,
  PTW_SRC_ACCESS_SRC_MBUF_BUS_ERROR = 2,
  PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY = 3,
  PTW_SRC_ACCESS_SRC_UNMODELED = 4
} ptw_src_access_src_e;
```

建议扩展 `ptw_src_pde_evt_kind_e`：

```systemverilog
PTW_SRC_PDE_EVT_TAG_MISS,
PTW_SRC_PDE_EVT_L1_PMP_DENY_MISS,
PTW_SRC_PDE_EVT_L2_PMP_DENY_ACCERR,
PTW_SRC_PDE_EVT_ACCERR
```

如果担心 enum 兼容性，可以保留 `HIT/MISS/UPDATE/CLEAR`，新增 `reason` 和 `direct_accerr` 字段表达细分语义。推荐后者，减少旧 scoreboard 分支冲击。

建议扩展 `ptw_src_pde_evt_txn`：

```systemverilog
bit                    l1_tag_hit;
bit                    l2_tag_hit;
bit                    l1_perm_allow;
bit                    l2_l1_perm_allow;
bit                    l2_l2_perm_allow;
bit                    l2_perm_allow;
logic [3:0]            cached_l1pmpflg;
logic [3:0]            cached_l2pmpflg;
logic [3:0]            update_l1pmpflg;
logic [3:0]            update_l2pmpflg;
logic [7:0]            mbuf_pmpflg;
bit                    direct_accerr;
ptw_src_pde_reason_e   reason;
ptw_src_access_src_e    access_src;
ptw_src_req_type_e      accerr_type;
logic [5:0]             accerr_id;
bit                    accerr_grant;
logic [15:0]            l1_tag_hit_vec;
logic [15:0]            l2_tag_hit_vec;
logic [15:0]            l2_accerr_vec;
```

建议扩展 `ptw_src_level_evt_txn`：

```systemverilog
logic [7:0] mbuf_pmpflg;
logic [7:0] twu_mbuf_pmpflg;
logic [3:0] selected_pmpflg;
```

含义：

1. `twu_mbuf_pmpflg` 表示 TWU 发给 MBUF 的 payload。
2. `mbuf_pmpflg` 表示 MBUF data 返回时回传给 TWU/PDE update 的 payload。
3. `selected_pmpflg` 表示当前 level PMP port 的原始 `pmp_mmu_flg[3:0]`，仅作为 payload 生成的辅助 evidence。

建议扩展 `ptw_src_expected_rsp_txn`：

```systemverilog
ptw_src_access_src_e  access_src;
ptw_src_pde_reason_e pde_reason;
logic [3:0]          pde_l1pmpflg;
logic [3:0]          pde_l2pmpflg;
bit                  pde_direct_accerr;
```

`convert2string()` 必须打印这些字段，便于 debug：

```text
access_src=PDE_CACHE_PMP_DENY pde_reason=L2_L2PMP_DENY pde_pmp={l1=0x?,l2=0x?} pde_direct_accerr=1
```

建议新增公共 helper：

```systemverilog
function automatic bit ptw_src_pde_pmp_type_bit_allow(...);
function automatic bit ptw_src_pde_pmp_allow(...);
function automatic string ptw_src_pde_reason_name(...);
function automatic bit ptw_src_is_data_type(...);
```

Phase 1 退出标准：

1. `ptw_source_types.svh` 编译通过。
2. 所有 `convert2string()` 不产生未初始化字段误导。
3. 旧 test 在不开启新 direct accerr 场景时 source SB 仍能通过。

建议命令：

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
make -C mmu_verification run_check TEST_NAME=test_ptw_source_stage2_smoke SEED=404 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

### Phase 2: PDE cache abstract model 重构

目标：把 tag-only model 升级为 permission-qualified model。

修改文件：

```text
mmu_verification/testbench/env/ptw_pde_cache_model.svh
```

建议数据结构：

```systemverilog
typedef struct {
  bit          valid;
  logic [26:0] tag;
  ppn_t        ppn;
  logic [3:0]  l1pmpflg;
  logic [3:0]  l2pmpflg;
  int unsigned age;
} pde_entry_s;

typedef struct {
  bit                  lookup_hit;
  bit                  l1_hit;
  bit                  l2_hit;
  bit                  l1_tag_hit;
  bit                  l2_tag_hit;
  bit                  l1_perm_allow;
  bit                  l2_l1_perm_allow;
  bit                  l2_l2_perm_allow;
  bit                  l2_direct_accerr;
  ptw_src_level_e      hit_level;
  ppn_t                hit_ppn;
  logic [3:0]          cached_l1pmpflg;
  logic [3:0]          cached_l2pmpflg;
  ptw_src_pde_reason_e reason;
  int                  l1_idx;
  int                  l2_idx;
} pde_lookup_result_s;

typedef struct {
  bit             valid;
  ptw_src_level_e level;
  vpn_t           vpn;
  ppn_t           ppn;
  logic [3:0]     l1pmpflg;
  logic [3:0]     l2pmpflg;
  int             directed_victim;
} pde_pending_update_s;
```

lookup API 建议：

```systemverilog
virtual function pde_lookup_result_s lookup_detail(
  input vpn_t              vpn,
  input ptw_src_req_type_e req_type,
  input bit                effective_m,
  input bit                update_plru = 1'b1
);
```

兼容旧调用可保留 wrapper：

```systemverilog
virtual function bit lookup(
  input  vpn_t           vpn,
  input  ptw_src_req_type_e req_type,
  input  bit             effective_m,
  output ptw_src_level_e hit_level,
  output ppn_t           hit_ppn,
  output bit             l1_hit,
  output bit             l2_hit
);
```

核心规则：

1. `find_tag_l1()` 和 `find_tag_l2()` 只返回 valid tag hit index，不判断 permission。
2. L2 优先级先于 L1：
   - 如果 L2 valid tag hit 且两级 pmp allow，则 L2 hit。
   - 如果 L2 valid tag hit 但任一级 deny，则 `l2_direct_accerr=1`，不允许 fallback 到 L1。
   - 只有 L2 没有 valid tag hit 时，才考虑 L1。
3. L1 valid tag hit 且 pmp allow，则 L1 hit。
4. L1 valid tag hit 但 deny，则 `l1_tag_hit=1`、`l1_hit=0`、`reason=L1_PMP_DENY`，表现为 miss。
5. PLRU/age 更新只允许 permission-qualified hit 更新。
6. tag hit deny 不更新 age，避免 scoreboard 预测 PLRU 与 RTL 偏离。

update API 建议：

```systemverilog
virtual function void queue_update(
  input ptw_src_level_e level,
  input vpn_t           vpn,
  input ppn_t           ppn,
  input logic [3:0]     l1pmpflg,
  input logic [3:0]     l2pmpflg,
  input int             directed_victim = -1
);

virtual function void commit_update(
  input ptw_src_level_e level,
  input vpn_t           vpn,
  input ppn_t           ppn,
  input logic [3:0]     l1pmpflg,
  input logic [3:0]     l2pmpflg,
  input int             directed_victim = -1
);
```

level 规则：

1. `PTW_SRC_LEVEL_FST` 只更新 L1 entry：
   - `entry.l1pmpflg = l1pmpflg`
   - `entry.l2pmpflg = 4'h0`
   - 若传入 `l2pmpflg != 0`，发 `uvm_warning` 或记录 probe gap。
2. `PTW_SRC_LEVEL_SCD` 只更新 L2 entry：
   - `entry.l1pmpflg = l1pmpflg`
   - `entry.l2pmpflg = l2pmpflg`
3. `THD` 不允许更新 PDE cache。

需要特别处理的旧模型行为：

1. 现有 ref model 中 `collect_level()` 和 `collect_pde()` 都可能更新 `m_pde_model`。实现时应拆成两个概念：
   - predicted update payload：由 level/MBUF event 计算，作为 `collect_pde()` 比较依据。
   - committed model state：只在观察到 DUT `pde_cache_update` event 后 commit，保证 model 与实际 cache 状态同步。
2. 如果为了兼容旧 tests 保留 `tick()`，则 `tick()` 只能 commit predicted update 到 shadow-expected model，不得与 observed model double commit。
3. 推荐维护两个对象：
   - `m_pde_pred_model`：从 level events 预测 golden 行为。
   - `m_pde_obs_model`：从 observed PDE update/clear events 跟随 DUT。
   若实现复杂度需控制，也可以单模型加 pending expected update queue，但必须避免 double update。

Phase 2 退出标准：

1. 单元编译通过。
2. 旧 PDE hit/miss tests 在 pmpflg 全 allow 情况下行为不变。
3. 可以通过 UVM info 打印 L1/L2 entry cached pmpflg。
4. lookup unit debug 能区分：
   - tag miss
   - L1 tag hit deny miss
   - L1 qualified hit
   - L2 qualified hit
   - L2 L1 cached PMP deny direct accerr
   - L2 L2 cached PMP deny direct accerr

### Phase 3: monitor 和 probe 采样升级

目标：把新增 probe 转成 source-side transaction evidence。

修改文件：

```text
mmu_verification/testbench/env/ptw_source_monitor.svh
```

`sample_level_events()` 修改计划：

1. 对每个 TWU，采样当前 selected level 的 PMP flag：
   - 优先使用新增 `ptw_twu_mbuf_pmpflg[twu]`。
   - 若只观测到 `p13_pmp_flg_vec[twu]`，必须用 `p13_pmp_mbuf_req_vec[twu]` 和 level onehot 证明该 flag 与本 level MBUF request 同周期。
2. 当 `ptw_twu_mbuf_req[twu]` 为 1：
   - FST level 期望 `twu_mbuf_pmpflg == {4'h0, selected_fst_pmpflg}`。
   - SCD level 期望 `twu_mbuf_pmpflg[7:4] == selected_scd_pmpflg`，`[3:0]` 等于 inherited l1pmpflg。
   - THD level 期望 `twu_mbuf_pmpflg == 8'h00`。
3. 当 `ptw_mbuf_twu_data_vld[twu]` 为 1：
   - 采样 `ptw_mbuf_twu_pmpflg` 到 `tr.mbuf_pmpflg`。
   - 该 payload 是 PDE update 的直接 evidence。

`sample_pde_events()` 修改计划：

1. lookup event：
   - 保留 `pde_cache_req && pde_cache_ready` 采样。
   - 新增 raw tag hit vector、permission-qualified hit、cached pmpflg、reason。
   - `kind` 仍可为 `HIT/MISS`，但 `reason` 必须准确。
   - L1 tag hit deny 时 `kind=MISS`、`l1_tag_hit=1`、`l1_hit=0`、`reason=L1_PMP_DENY`。
   - L2 tag hit deny 时可以采样为单独 `kind=ACCERR` 或 `kind=MISS + direct_accerr=1`。推荐 `kind=ACCERR`，更清晰。
2. update event：
   - 采样 `update_l1pmpflg/update_l2pmpflg`。
   - FST update 时要求 `update_l2pmpflg==0`。
   - SCD update 时要求两级 pmpflg 都有效。
3. clear event：
   - 保留清空 event。
   - 如果当拍 direct accerr pending 被 clear/abort 屏蔽，也记录 drop/debug reason。
4. direct accerr event：
   - 采样 `pde_cache_acc_err_vld/type/id/grant`。
   - 生成 `ptw_src_pde_evt_txn`，设置：
     - `direct_accerr=1`
     - `access_src=PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY`
     - `accerr_type/accerr_id`
     - `reason=L2_L1PMP_DENY/L2_L2PMP_DENY/L2_BOTH_PMP_DENY`

debug 输出建议：

```text
PTW_PDE_EVT cycle=... kind=ACCERR type=... id=... vpn=...
  tag_hit={l1=0,l2=1} allow={l1=1,l2_l1=1,l2_l2=0}
  cached_pmp={l1=0x7,l2=0x1} reason=L2_L2PMP_DENY
```

Phase 3 退出标准：

1. monitor 能在 L1/L2 update 时打印 pmpflg。
2. monitor 能在 L2 direct accerr 时产生 `PTW_PDE_EVT kind=ACCERR`。
3. 旧 tests 日志中没有未初始化 `x` 被误判为 deny。
4. source monitor summary 增加 PDE pmpflg 相关 counters。

### Phase 4: source reference model 接入 PDE pmpflg golden

目标：让 PTW source expected 能正确预测 PDE cache pmpflg hit/deny 及 direct accerr completion。

修改文件：

```text
mmu_verification/testbench/env/ptw_source_ref_model.svh
```

#### 4.1 effective M-mode 复用

已有函数：

```systemverilog
protected function bit effective_machine(input pending_req_s pending);
```

本次 PDE cache lookup 的权限判断必须使用同一个 effective-mode helper，确保 MPRV/MPP 语义与 TWU PMP stage 一致。但在 top-level PTW source flow 中，data/PFU effective-M 请求应已被上游 direct-map 消除；若 monitor 观察到这类 source accept，应作为 illegal stimulus/report 处理，而不是用它关闭 cached pmpflg coverage。

1. fetch 不受 MPRV 影响，只按真实流水线 privilege 判断；真实 M fetch 不进入 PTW，真实 S/U fetch 可进入 PTW。
2. load/store/PFU 在 `MPRV=1` 时用 `MPP` 计算 data effective privilege，否则用真实 privilege。
3. load/store/PFU 的 data effective privilege 为 M 时 direct-map VA=PA，不应出现合法 PTW source request。
4. cached `pmpflg[3]` 的 effective-M lock/bypass matrix 若无法由合法 top-level source 触发，只能由 lower-level PDE-cache stimulus 或 RTL unit evidence 关闭。

#### 4.2 pending request 扩展

`pending_req_s` 建议新增字段：

```systemverilog
bit                  pde_direct_accerr_seen;
ptw_src_pde_reason_e pde_reason;
logic [3:0]          pde_l1pmpflg;
logic [3:0]          pde_l2pmpflg;
bit                  pde_l1_tag_hit_deny_seen;
bit                  pde_l2_tag_hit_deny_seen;
int unsigned         pde_lookup_cycle;
int unsigned         pde_direct_accerr_cycle;
```

#### 4.3 PDE lookup event 处理

`collect_pde()` 在 lookup event 时应执行：

1. 用 current pending 的 `vpn/type/id/context` 调 `m_pde_model.lookup_detail(vpn, req_type, effective_machine(pending))`。
2. 比较 model 结果和 monitor event：
   - model L1 hit == actual `pde_l1_hit_vld`。
   - model L2 hit == actual `pde_l2_hit_vld`。
   - model L2 direct accerr == actual `direct_accerr` 或后续 `PDE_cache_acc_err_vld`。
   - model cached pmpflg == monitor cached pmpflg，若 probe 可用。
3. L1 tag-hit deny：
   - 不 emit expected access fault。
   - 标记 `pending.pde_l1_tag_hit_deny_seen=1`。
   - 等待后续 FST PMP/MBUF/CHK event。
4. L2 tag-hit deny：
   - 设置 `pending.expected_access_fault=1`。
   - 设置 `pending.pde_direct_accerr_seen=1`。
   - 设置 `access_src=PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY`。
   - 调用统一 `build_and_emit_completion()` 生成 `PTW_SRC_EXP_ACCESS_FAULT`。
   - completion cycle 使用 `PDE_cache_acc_err_vld` 采样周期或 lookup event 周期，具体以 DUT visible completion 对齐为准。
5. L2 tag-hit deny 后不应再期待同一 `{type,id}` 产生新的 PTW memory request。该约束可在 Phase 5 的 scoreboard 中校验。

#### 4.4 PDE update event 处理

当前 `collect_level()` 会在 non-leaf/no-fault 时 `queue_update()`，`collect_pde()` 又会 `commit_update()`。本次建议改成：

1. `collect_level()` 只生成 predicted update payload：
   - FST non-leaf：记录 `level=FST`、`vpn`、`ppn`、`l1pmpflg=tr.mbuf_pmpflg[3:0]`、`l2pmpflg=0`。
   - SCD non-leaf：记录 `level=SCD`、`vpn`、`ppn`、`l1pmpflg=tr.mbuf_pmpflg[3:0]`、`l2pmpflg=tr.mbuf_pmpflg[7:4]`。
2. `collect_pde()` 在 observed `PTW_SRC_PDE_EVT_UPDATE` 到来时：
   - 与 predicted update queue 比较 level/vpn/ppn/l1pmpflg/l2pmpflg。
   - 比较通过后 commit 到 `m_pde_model`。
   - 若没有 predicted update，但 observed update 发生，发 `PTW_SOURCE_PROBE_GAP` 或 `uvm_error`，取决于是否已有足够 probe。
3. 如果为了兼容旧 event ordering，允许 level event 晚于 PDE update，则用小 FIFO/window 匹配，不允许无限宽松。

#### 4.5 direct accerr completion

`build_and_emit_completion()` 需要支持新增字段：

```systemverilog
input ptw_src_access_src_e access_src = PTW_SRC_ACCESS_SRC_NONE,
input ptw_src_pde_reason_e pde_reason = PTW_SRC_PDE_REASON_NONE,
input logic [3:0] pde_l1pmpflg = 4'h0,
input logic [3:0] pde_l2pmpflg = 4'h0
```

对于 PDE direct accerr：

```systemverilog
kind        = PTW_SRC_EXP_ACCESS_FAULT
fault_kind  = PTW_SRC_FAULT_ACCESS
access_src  = PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY
pde_direct_accerr = 1'b1
target      = target_from_type(req_type)
target_l2tlb = 1
target_l1i/l1d/pfu 按原始 req_type
```

注意：PFU exception 目标仍按现有 PTW source-side 规则处理，不能因为 PDE direct accerr 改成 L1D/L1I。

#### 4.6 clear/abort 处理

1. `collect_csr_write()` 中 `CP0_WRITE_SATP`、`CP0_TLB_ALL_INV`、PMP cfg update 仍 clear PDE model。
2. clear-only 不删除 pending walk。
3. reset/tlboper abort 应：
   - clear PDE model。
   - 清 pending predicted update queue。
   - 清 direct accerr pending shadow。
4. 若 direct accerr pending 已 visible 且 grant 前遇到 abort/reset，需要按 RTL 行为分类为 drop 或 completion，不能双发 expected。

Phase 4 退出标准：

1. L1 pmp deny 被建模为 miss，不直接 access fault。
2. L2 pmp deny 被建模为 direct access fault。
3. update payload 比较包含 pmpflg。
4.旧 stage7/stage8 tests 在 all-allow pmpflg 下不回归。
5. ref-model summary 打印新增 counters：
   - `pde_l1_pmp_deny_miss`
   - `pde_l2_l1pmp_deny_accerr`
   - `pde_l2_l2pmp_deny_accerr`
   - `pde_pmpflg_update_l1`
   - `pde_pmpflg_update_l2`
   - `pde_mmode_bypass`
   - `pde_mmode_lock_deny`

### Phase 5: scoreboard、coverage 和 no-extra-LSU checker

目标：让 scoreboard 既能匹配 final completion，又能关闭本次变更的关键行为证据。

修改文件：

```text
mmu_verification/testbench/env/ptw_source_sb.svh
```

#### 5.1 completion compare 扩展

`compare_completion()` 需要：

1. 对 `access_src` 做比较。
2. 对 PDE direct accerr 的 `pde_reason` 做比较。
3. 对 `pde_l1pmpflg/pde_l2pmpflg` 做比较。如果 actual completion 没有这些字段，至少 expected/monitor PDE event 必须在 summary 中记录。
4. bus error root cause 仍允许 visible fault_kind 为 generic access fault，但 PDE direct accerr 不应被误归类为 bus error。

#### 5.2 active key 规则保持

之前修过同 `{type,id}` legal reuse 的问题。本次新增 direct accerr 后仍应保持：

1. visible DUT completion 出现后即可 retire active key。
2. ref-model expected FIFO 晚到不能导致 false illegal stimulus。
3. PDE direct accerr completion 也属于 visible completion。

#### 5.3 no-extra-LSU checker

L2 tag-hit deny direct accerr 场景必须证明没有额外 LSU page-table read。建议在 scoreboard 中新增轻量 checker：

数据结构：

```systemverilog
typedef struct {
  bit                active;
  ptw_src_req_type_e req_type;
  logic [5:0]        id;
  vpn_t              vpn;
  int unsigned       start_cycle;
  int unsigned       mem_req_seen_after_accerr;
} pde_direct_accerr_window_s;
```

规则：

1. 当 ref model 或 monitor 发现 L2 direct accerr 时，打开 window。
2. 从 direct accerr event 到该 `{type,id}` visible completion/drop 之间，不允许出现归属于该 request 的新 PTW memory request。
3. 如果 memory request agent 无法携带 `{type,id}`，则用以下保守条件：
   - 当 direct accerr window active 且没有其他 pending request 时，任何 `ptw_mem_req` 都是 error。
   - 当有多个 pending request 时，不报 error，但计入 `probe_gap_no_extra_lsu_ambiguous`，不能关闭 `PTW-ADD-039/040`。
4. `PTW-ADD-039/040/042` 的 directed tests 应避免多 pending 干扰，确保 no-extra-LSU 可严格检查。

#### 5.4 coverage counters

新增 counters：

```text
n_cov_pde_l1_tag_hit_allow
n_cov_pde_l1_tag_hit_deny_miss
n_cov_pde_l2_tag_hit_allow
n_cov_pde_l2_l1pmp_deny_accerr
n_cov_pde_l2_l2pmp_deny_accerr
n_cov_pde_l2_both_pmp_deny_accerr
n_cov_pde_update_l1_pmpflg
n_cov_pde_update_l2_pmpflg
n_cov_pde_direct_accerr_type_load
n_cov_pde_direct_accerr_type_store
n_cov_pde_direct_accerr_type_fetch
n_cov_pde_direct_accerr_type_pfu
n_cov_pde_mmode_bypass
n_cov_pde_mmode_lock_deny
n_cov_pde_no_extra_lsu
```

summary banner 建议：

```text
PTW_SOURCE_SB_PDE_PMP_COVERAGE stage=pde_pmpflg
  l1_allow=... l1_deny_miss=...
  l2_allow=... l2_l1deny=... l2_l2deny=... l2_bothdeny=...
  update_l1=... update_l2=...
  direct_accerr_load=... direct_accerr_store=... direct_accerr_fetch=... direct_accerr_pfu=...
  mmode_bypass=... mmode_lock_deny=...
  no_extra_lsu=...
```

Phase 5 退出标准：

1. source SB summary clean。
2. `PTW_SOURCE_SB_PDE_PMP_COVERAGE` 至少打印全部新增字段。
3. L2 direct accerr tests 中 `no_extra_lsu` 命中。
4. L1 deny miss tests 中不出现 `pde_direct_accerr`。

### Phase 6: SVA 修改和新增

目标：用 source-side SVA 直接约束 RTL PDE cache PMP flag 行为。

修改文件：

```text
mmu_verification/testbench/top/mmu_pde_cache_sva.sv
mmu_verification/testbench/top/mmu_arb_sva.sv
mmu_verification/testbench/top/mmu_ptw_top_sva.sv
```

#### 6.1 `mmu_pde_cache_sva.sv` 新增端口

如果 bind target 是 `PDE_cache`，优先使用 `bind PDE_cache mmu_pde_cache_sva u_pde_cache_sva (.*);` 自动连接同名信号。缺同名时显式连接。

建议新增端口：

```systemverilog
input logic [TYPE_WIDTH-1:0]                     ptw_type,
input logic [ID_WIDTH-1:0]                       ptw_id,
input logic [VPN_WIDTH-1:0]                      ptw_vpn,
input logic                                      ptw_req,
input logic                                      cp0_mach_mode,
input logic [3:0]                                mbuf_cache_upd_l1pmpflg,
input logic [3:0]                                mbuf_cache_upd_l2pmpflg,
input logic [L1PDE_ENTRY_NUM-1:0][3:0]           L1PDE_l1pmpflg,
input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l1pmpflg,
input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_tag_hit,
input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_tag_hit,
input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_acc_err,
input logic                                      PDE_cache_acc_err_vld,
input logic [TYPE_WIDTH-1:0]                     PDE_cache_acc_err_type,
input logic [ID_WIDTH-1:0]                       PDE_cache_acc_err_id,
input logic                                      PDE_cache_acc_err_grant
```

如果 `cp0_mach_mode` 在 PDE cache 内不可见，需要接入 RTL 实际使用的 effective M-mode signal，而不是 testbench 自行推断。

#### 6.2 helper function

在 SVA module 中定义：

```systemverilog
function automatic logic pde_pmp_type_allow(
  input logic [TYPE_WIDTH-1:0] req_type,
  input logic [3:0] pmpflg
);
  case (req_type)
    3'b010,
    3'b100: return pmpflg[0];
    3'b110: return pmpflg[1];
    3'b011: return pmpflg[2];
    default: return 1'b0;
  endcase
endfunction

function automatic logic pde_pmp_allow(
  input logic [TYPE_WIDTH-1:0] req_type,
  input logic [3:0] pmpflg,
  input logic effective_m
);
  return pde_pmp_type_allow(req_type, pmpflg)
      || (effective_m && !pmpflg[3]);
endfunction
```

#### 6.3 修改现有 SVA

| 现有 SVA | 修改要求 |
| --- | --- |
| `PTW-SVA-PDE-003` | 双 hit 选择二级的前提必须是 L2 permission-qualified hit。若 L2 tag hit deny，不允许回退 L1 hit。 |
| `PTW-SVA-PDE-004` | hit level 输出只反映 permission-qualified hit。 |
| `PTW-SVA-PDE-005` | PPN match 只在 qualified hit 时检查。 |
| `PTW-SVA-PDE-006` | update onehot 保持，同时增加 update pmpflg 保存检查。 |
| `PTW-SVA-PDE-008` | lookup/update 同拍同 tag 时，lookup 使用旧 tag/data/pmpflg。 |
| `PTW-SVA-PDE-010` | 改写说明：PDE cache 不携带 leaf PTE permission/flg，但携带 page-table memory PMP evidence。 |

#### 6.4 新增 SVA

| SVA ID | 断言 | 绑定测试点 |
| --- | --- | --- |
| `PTW-SVA-PDE-011` | L1 entry hit iff `valid && tag_match && allow(type,l1pmpflg,effective_m)`；L1 tag match but deny 不得拉高 L1 hit。 | `PDE-TP-013`、`PTW-ADD-037/038` |
| `PTW-SVA-PDE-012` | L2 entry hit iff `valid && tag_match && allow(type,l1pmpflg,effective_m) && allow(type,l2pmpflg,effective_m)`。 | `PDE-TP-014/015` |
| `PTW-SVA-PDE-013` | L2 valid tag match but either cached PMP deny 时，必须产生 `PDE_cache_acc_err_vld`，且不得产生 `L2PDE_xbar_hit_vld`。 | `PTW-ADD-039/040` |
| `PTW-SVA-PDE-014` | L2 direct accerr 必须 gated by `ptw_req && entry.valid && tag_match`；invalid/idle tag match 不得误报。 | `PTW-ADD-044` |
| `PTW-SVA-PDE-015` | FST update 保存 `{0,l1}`，SCD update 保存 `{l2,l1}`，THD 不更新 PDE cache。 | `PTW-ADD-041` |
| `PTW-SVA-PDE-016` | PLRU/read-hit update 只允许 qualified hit；tag hit deny 不得更新 PLRU hit state。 | `PDE-TP-012/013/014/015` |
| `PTW-SVA-PDE-017` | direct accerr pending 在 grant 前 type/id stable；grant 后清 pending。 | `PTW-ADD-042` |

#### 6.5 fault priority SVA

`mmu_arb_sva.sv` 或 `mmu_ptw_top_sva.sv` 新增：

| SVA ID | 断言 |
| --- | --- |
| `PTW-SVA-ARB-010` | PDE cache direct accerr 与 MBUF bus error/TWU accerr 同周期竞争时，输出 access fault 使用 PDE cache `type/id`。 |
| `PTW-SVA-ARB-011` | PDE cache direct accerr visible 时 completion class onehot，不能同时 normal refill/page fault。 |
| `PTW-SVA-ARB-012` | PDE cache direct accerr grant 后不再重复返回同一 pending fault。 |

Phase 6 退出标准：

1. SVA 编译通过。
2. 新增 `PTW_SVA_COVER` banner 可被现有脚本解析。
3. `PTW-SVA-PDE-011..017` 和 `PTW-SVA-ARB-010..012` 至少在 directed suite 中各有 cover hit 或明确 waiver。

### Phase 7: directed base helper 扩展

目标：让新增 tests 能稳定构造 cached pmpflg 场景，而不是依赖随机 PMP 配置。

修改文件：

```text
mmu_verification/testbench/test/ptw_tests/ptw_source_directed_base.svh
```

建议新增 helper：

```systemverilog
protected function logic [3:0] ptw_make_pmpflg(
  input bit r,
  input bit w,
  input bit x,
  input bit lock
);

protected task ptw_config_page_table_pmp_region(
  input pa_t base,
  input pa_t mask_or_size,
  input logic [3:0] pmpflg,
  input string region_name
);

protected task ptw_prime_l1_pde_cache_with_type(
  input ptw_src_req_type_e req_type,
  input va_t va,
  input pte_t fst_nonleaf,
  input logic [3:0] l1pmpflg,
  input int unsigned id
);

protected task ptw_prime_l2_pde_cache_with_type(
  input ptw_src_req_type_e req_type,
  input va_t va,
  input pte_t fst_nonleaf,
  input pte_t scd_nonleaf,
  input logic [3:0] l1pmpflg,
  input logic [3:0] l2pmpflg,
  input int unsigned id
);

protected task ptw_drive_source_req_by_type(
  input ptw_src_req_type_e req_type,
  input va_t va,
  input int unsigned id,
  input int unsigned idle = 0
);

protected task ptw_expect_no_ptw_mem_req_window(
  input string scenario_id,
  input int unsigned min_cycles,
  input int unsigned max_cycles
);
```

helper 设计要求：

1. prime helper 必须通过真实 PTW walk 建立 PDE cache，不能 testbench 直接写 DUT 内部 cache。
2. pmpflg 生成必须通过 PMP agent 配置，让 RTL 真实获得对应 `pmp_mmu_flg`。
3. 对 L1 deny miss 测试，第二个请求要同 VPN tag match，但 request type 不被 cached `l1pmpflg` 允许。
4. 对 L2 direct accerr 测试，第二个请求要同 L2 tag match，且只打开一个 pending request，方便 no-extra-LSU checker 严格关闭。
5. metadata 中写入 requirement：
   - `PTW-ADD-037..045`
   - `PDE-TP-013..019`
   - `PTW-FLOW-024..028`
6. helper 不应绕过 source SB 的 same `{type,id}` active key 规则。每个 scenario 用不同 id 或等待 completion 后复用。

Phase 7 退出标准：

1. directed base 编译通过。
2. 旧 directed tests 不受 helper 默认值影响。
3. 新 helper 能打印 scenario metadata，包括 pmpflg 和 expected path。

### Phase 8: 修改现有 tests 和 expected

目标：删除或修正 tag-only PDE cache expected，避免旧 tests 在新 RTL 下表达错误预期。

需要修改的现有 PTW tests：

| 文件 | 修改内容 |
| --- | --- |
| `test_ptw_l1_pde_hit.svh` | positive hit 必须配置 `l1pmpflg` allow 当前 type；新增或拆出 L1 tag hit deny 子场景，expected 为进入 FST path。 |
| `test_ptw_l2_pde_hit_direct.svh` | positive hit 必须配置 L1/L2 cached pmpflg 均 allow；tag hit deny 不再作为 miss walk。 |
| `test_ptw_l1_pde_miss_walk.svh` | 把 miss 分为 tag miss 和 permission-qualified miss。L1 tag hit deny 允许走 FST。 |
| `test_ptw_l2_pde_miss_walk.svh` | L2 tag hit deny 不能作为普通 miss；应改 expected 为 PDE direct access fault。 |
| `test_pde_cache_l1_single_entry.svh` | 增加 `l1pmpflg` update 和 lookup allow/deny 检查。 |
| `test_pde_cache_l2_single_entry.svh` | 增加 `l1pmpflg/l2pmpflg` update、qualified hit、direct accerr 检查。 |
| `test_mmu_pde_cache_hit_l2_skip_scd.svh` | L2 skip scd 仅在 permission-qualified hit 时成立。 |
| `test_mmu_pde_cache_full_miss_full_ptw.svh` | full miss 建 cache 时检查 update pmpflg payload。 |
| `test_mmu_pde_cache_hit_l3_skip_thd.svh` | 文件名口径需核对；如果实际是 L2 PDE hit 进入 THD，应加入 permission-qualified 前提。 |
| `test_ptw_l1_pde_cache_replace.svh` | PLRU hit 更新只由 qualified hit 触发，tag hit deny 不更新 PLRU。 |
| `test_ptw_l2_pde_cache_replace.svh` | L2 tag hit deny 不更新 PLRU，direct accerr 不选择 victim。 |
| `test_pde_cache_clear_on_ptw_reset.svh` | clear 后旧 cached pmpflg 不可产生 hit/direct accerr；reset/abort 清 pending。 |
| `test_bug_001_twu_fst_fetch_type.svh` | fetch 建 cache 后 load/store/PFU 复用必须按 cached pmpflg 重新解释。 |

需要删除或改写的旧 expected：

| 旧 expected | 新 expected |
| --- | --- |
| PDE hit 只由 VPN tag 决定 | PDE hit = valid + tag + cached pmpflg allow。 |
| L1 tag hit deny 直接 PDE accerr | L1 tag hit deny 是 L1 miss，走 FST PMP path。 |
| L2 tag hit deny 是普通 miss walk | L2 tag hit deny 是 PDE direct access fault，不能发 LSU。 |
| L2 tag hit deny 可 fallback L1 hit | 不允许 fallback，必须 direct accerr。 |
| PMP config clear 足以覆盖跨 type 权限 | 仍需要 cached pmpflg lookup 重新解释。 |

Phase 8 退出标准：

1. 所有旧 PDE tests 预期与新语义一致。
2. all-allow pmpflg 场景仍保持旧 positive flow。
3. tag-deny 场景不再出现 consumer-only closure。

### Phase 9: 新增 directed tests

目标：为 `PTW-ADD-037..045` 提供 source-side directed evidence。

建议新增文件：

| Testpoint | 建议文件 | P0/P1 | 场景 | 必须观察 |
| --- | --- | --- | --- | --- |
| `PTW-ADD-037` | `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001.svh` | P0 | fetch 建 L1 PDE，load 同 L1 tag，cached `l1pmpflg[0]=0`。 | L1 tag hit 但 no hit；进入 FST PMP；若实时 FST deny，则普通 TWU access fault；无 PDE direct accerr。 |
| `PTW-ADD-038` | `test_ptw_pde_l1_pmp_tag_allow_reuse_001.svh` | P0 | load/PFU 共用 R，fetch 用 X，store 用 W。 | L1 permission-qualified hit，跳过 FST。 |
| `PTW-ADD-039` | `test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh` | P0 | L2 tag match，cached L2 allow，cached L1 deny。 | PDE direct accerr；不发 LSU；type/id 正确。 |
| `PTW-ADD-040` | `test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh` | P0 | L2 tag match，cached L1 allow，cached L2 deny。 | PDE direct accerr；不回退 SCD；不发 LSU。旧 `MPRV=1/MPP=M` data construction 不合法，top-level source test 只能 open，需 alternate legal/lower-level evidence。 |
| `PTW-ADD-041` | `test_ptw_pde_pmpflg_propagation_update_001.svh` | P0 | FST/SCD/THD payload 全覆盖。 | FST `{0,l1}`，SCD `{l2,l1}`，THD `0` 且不更新。 |
| `PTW-ADD-042` | `test_ptw_pde_accerr_priority_type_id_001.svh` | P1 | PDE direct accerr 与 bus error/TWU accerr 竞争。 | PDE accerr priority，type/id stable。 |
| `PTW-ADD-043` | `test_ptw_pde_mmode_lock_matrix_001.svh` | P0 | effective M-mode，`pmpflg[3]` 0/1，type bit allow/deny 交叉。 | 最新规格下 top-level data/PFU `MPRV=1/MPP=M` 不进入 PTW；本 test 只能记录 open/unreachable，实际关闭需 lower-level PDE-cache stimulus 或 RTL unit evidence。 |
| `PTW-ADD-044` | `test_ptw_pde_l2_accerr_valid_gate_001.svh` | P0 | invalid entry tag 旧值匹配或 `ptw_req=0`。 | 不产生 direct accerr。 |
| `PTW-ADD-045` | `test_ptw_pde_pmp_clear_repopulate_001.svh` | P1 | PMP update clear 后重新 walk/update。 | 旧 entry 不可用；新 update pmpflg 来自 MBUF entry。 |

#### 9.1 每个 test 的通用结构

每个新增 test 建议继承 `ptw_source_directed_base`：

```systemverilog
class test_ptw_pde_l2_pmp_l2_deny_accerr_001 extends ptw_source_directed_base;
  `uvm_component_utils(test_ptw_pde_l2_pmp_l2_deny_accerr_001)

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    ptw_meta_begin("PTW-ADD-040", "pde_l2_pmp_l2_deny_accerr");
    ptw_meta_add_req("PTW-ADD-040");
    ptw_meta_add_req("PDE-TP-015");
    ptw_meta_add_req("PTW-FLOW-026");
    ...
    phase.drop_objection(this);
  endtask
endclass
```

每个 test 必须：

1. 明确配置 `satp/asid/priv/mxr/sum/mprv/mpp/maee`。
2. 明确配置 page-table memory 和 PTE raw value。
3. 明确配置 PMP region，使 FST/SCD page-table PA 返回指定 `pmpflg`。
4. prime cache 时用真实请求建立 PDE cache。
5. 第二个请求触发目标 allow/deny。
6. 设置 expected path 字符串，包含：
   - cached pmpflg
   - request type
   - expected L1/L2 behavior
   - expected completion class
   - no-extra-LSU 是否必须成立

#### 9.2 测试拆分原则

新增文件数量预计 9 个，小于 15 个，不需要临时阶段拆分计划。

如果后续实现时发现每个 test 需要拆多个子类，优先拆成：

1. P0 basic correctness list。
2. P1 priority/clear/repopulate list。
3. Random/coverage supplement list。

临时拆分计划只能用于实现过程，完成本 phase 后删除。

Phase 9 退出标准：

1. 新增 tests 编译通过。
2. 每个新增 test 日志包含 scenario metadata。
3. 每个 P0 test source SB clean。
4. 每个 P0 test 命中对应 `PTW_SVA_COVER` 或 monitor cover。

### Phase 10: suite、list、closure matrix 和 signoff gate

目标：把新增 test 和新增 closure requirement 接入 regression/signoff。

修改文件：

```text
mmu_verification/testbench/test/ptw_tests/ptw_tests_suite.svh
mmu_verification/simu/ptw_p0_list
mmu_verification/simu/ptw_p1_list
mmu_verification/simu/ptw_p0_smoke_list
mmu_verification/simu/ptw_pde_pmpflg_list
mmu_verification/simu/ptw_source_closure_matrix.csv
mmu_verification/scripts/ptw_stage8_signoff_gate.py
doc/ptw_uvm_review/ptw_source_closure_matrix.md
doc/ptw_uvm_review/ptw_source_signoff_report.md
```

#### 10.1 suite include

在 `ptw_tests_suite.svh` 中加入：

```systemverilog
`include "test_ptw_pde_l1_pmp_tag_deny_fst_fault_001.svh"
`include "test_ptw_pde_l1_pmp_tag_allow_reuse_001.svh"
`include "test_ptw_pde_l2_pmp_l1_deny_accerr_001.svh"
`include "test_ptw_pde_l2_pmp_l2_deny_accerr_001.svh"
`include "test_ptw_pde_pmpflg_propagation_update_001.svh"
`include "test_ptw_pde_accerr_priority_type_id_001.svh"
`include "test_ptw_pde_mmode_lock_matrix_001.svh"
`include "test_ptw_pde_l2_accerr_valid_gate_001.svh"
`include "test_ptw_pde_pmp_clear_repopulate_001.svh"
```

#### 10.2 regression lists

新增 `mmu_verification/simu/ptw_pde_pmpflg_list`：

```text
test_ptw_pde_l1_pmp_tag_deny_fst_fault_001
test_ptw_pde_l1_pmp_tag_allow_reuse_001
test_ptw_pde_l2_pmp_l1_deny_accerr_001
test_ptw_pde_l2_pmp_l2_deny_accerr_001
test_ptw_pde_pmpflg_propagation_update_001
test_ptw_pde_mmode_lock_matrix_001
test_ptw_pde_l2_accerr_valid_gate_001
```

P1 list 加入：

```text
test_ptw_pde_accerr_priority_type_id_001
test_ptw_pde_pmp_clear_repopulate_001
```

P0 smoke list 建议只加入两个代表场景：

```text
test_ptw_pde_l1_pmp_tag_deny_fst_fault_001
test_ptw_pde_l2_pmp_l2_deny_accerr_001
```

#### 10.3 closure matrix

`ptw_source_closure_matrix.csv` 必须新增：

| requirement | test | source_checker | sva_cover | status |
| --- | --- | --- | --- | --- |
| `PTW-ADD-037` | `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001` | source SB clean + pde coverage | `PTW-SVA-PDE-011` | closed after pass |
| `PTW-ADD-038` | `test_ptw_pde_l1_pmp_tag_allow_reuse_001` | source SB clean + pde coverage | `PTW-SVA-PDE-011` | closed after pass |
| `PTW-ADD-039` | `test_ptw_pde_l2_pmp_l1_deny_accerr_001` | source SB clean + no-extra-LSU | `PTW-SVA-PDE-013` | closed after pass |
| `PTW-ADD-040` | `test_ptw_pde_l2_pmp_l2_deny_accerr_001` | open/unreachable for old `MPRV=1/MPP=M` construction; no illegal source traffic | `PTW-SVA-PDE-013` if covered by alternate legal stimulus | open until legal/lower-level evidence |
| `PTW-ADD-041` | `test_ptw_pde_pmpflg_propagation_update_001` | update pmpflg match | `PTW-SVA-PDE-015` | closed after pass |
| `PTW-ADD-042` | `test_ptw_pde_accerr_priority_type_id_001` | source SB clean + priority debug | `PTW-SVA-ARB-010` | P1 closed |
| `PTW-ADD-043` | `test_ptw_pde_mmode_lock_matrix_001` | open/unreachable top-level source marker | lower-level PDE-cache/RTL-unit evidence required | open |
| `PTW-ADD-044` | `test_ptw_pde_l2_accerr_valid_gate_001` | source SB clean | `PTW-SVA-PDE-014` | closed after pass |
| `PTW-ADD-045` | `test_ptw_pde_pmp_clear_repopulate_001` | source SB clean + clear/update coverage | `PTW-SVA-PDE-001/015` | P1 closed |

同时新增/更新：

```text
PDE-TP-013..019
PTW-FLOW-024..028
PTW-SVA-PDE-011..017
PTW-SVA-ARB-010..012
```

#### 10.4 signoff gate

`ptw_stage8_signoff_gate.py` 修改计划：

1. `required_ids("PTW-ADD", 1, 36)` 扩展到 `45`。
2. `required_ids("PDE-TP", 1, 12)` 扩展到 `19`。
3. 新增 `PTW-FLOW-024..028` required ids。
4. 新增对 `PTW_SOURCE_SB_PDE_PMP_COVERAGE` banner 的检查。
5. 新增对 `PTW_SVA_COVER` 中以下 req 的检查：
   - `PTW-SVA-PDE-011`
   - `PTW-SVA-PDE-012`
   - `PTW-SVA-PDE-013`
   - `PTW-SVA-PDE-014`
   - `PTW-SVA-PDE-015`
   - `PTW-SVA-PDE-017`
   - `PTW-SVA-ARB-010`
6. 对 `ptw_pde_pmpflg_list` 每个 log 做 source clean 检查。
7. 对 `PTW-ADD-039/040` 对应 log 强制检查 `no_extra_lsu` coverage > 0。
8. 保持 Python 兼容旧环境，不使用 `from __future__ import annotations`，避免之前 stage8 gate 在旧 Python 解析失败。

Phase 10 退出标准：

1. 新 list 可被 `make regress` 读取。
2. signoff gate 在新增 requirement 未关闭时会失败。
3. 所有新增 tests 通过后 signoff gate 通过。

## 6. 新增 requirement traceability

| 新 requirement | 设计语义 | UVM 组件 | Directed test | SVA/Cover |
| --- | --- | --- | --- | --- |
| `PDE-TP-013` | L1 tag hit but cached PMP deny -> miss/FST path | pde model、monitor、ref model | `PTW-ADD-037` | `PTW-SVA-PDE-011` |
| `PDE-TP-014` | L2 tag hit but cached L1 PMP deny -> direct accerr | pde model、ref model、SB no-extra-LSU | `PTW-ADD-039` | `PTW-SVA-PDE-012/013` |
| `PDE-TP-015` | L2 tag hit but cached L2 PMP deny -> direct accerr | pde model、ref model、SB no-extra-LSU | `PTW-ADD-040` | `PTW-SVA-PDE-012/013` |
| `PDE-TP-016` | FST/SCD/THD pmpflg propagation | monitor、ref model update compare | `PTW-ADD-041` | `PTW-SVA-PDE-015` |
| `PDE-TP-017` | PDE direct accerr type/id and priority | ref model、SB、arb SVA | `PTW-ADD-042` | `PTW-SVA-PDE-017`、`PTW-SVA-ARB-010` |
| `PDE-TP-018` | effective M-mode bit3 lock matrix | pde pmp allow helper | `PTW-ADD-043` | top-level source unreachable under corrected spec; lower-level evidence required |
| `PDE-TP-019` | L2 direct accerr valid/request gate | monitor、SVA | `PTW-ADD-044` | `PTW-SVA-PDE-014` |
| `PTW-FLOW-024` | L1 tag hit deny full flow | ref model、SB | `PTW-ADD-037` | `PTW-SVA-PDE-011` |
| `PTW-FLOW-025` | L2 tag hit L1 deny full flow | ref model、SB no-extra-LSU | `PTW-ADD-039` | `PTW-SVA-PDE-013` |
| `PTW-FLOW-026` | L2 tag hit L2 deny full flow | ref model、SB no-extra-LSU | `PTW-ADD-040` | `PTW-SVA-PDE-013` |
| `PTW-FLOW-027` | cached pmpflg allow cross-type reuse | pde model、coverage | `PTW-ADD-038` | `PTW-SVA-PDE-011/012` |
| `PTW-FLOW-028` | effective M-mode cached pmpflg lock/bypass | pde model、coverage | `PTW-ADD-043` | top-level source unreachable under corrected spec; lower-level evidence required |

## 7. 文件级修改清单

| 文件 | 操作 | 具体修改 |
| --- | --- | --- |
| `mmu_dut_probes_if.sv` | modify | 新增 pde pmpflg update、MBUF pmpflg payload、PDE direct accerr、raw tag hit、cached pmpflg probes。 |
| `tb_top.sv` | modify | 新增 whitebox assign；确认 `bind PDE_cache` 自动端口连接不被破坏。 |
| `ptw_source_types.svh` | modify | 新增 PDE reason/access source enum，扩展 level/pde/expected transaction 字段和 helper。 |
| `ptw_pde_cache_model.svh` | modify | entry 增加 pmpflg；lookup 改为 permission-qualified；L2 tag-hit deny direct accerr；update 保存 pmpflg。 |
| `ptw_source_monitor.svh` | modify | 采样 pmpflg payload、cached pmpflg、L1/L2 deny reason、PDE direct accerr。 |
| `ptw_source_ref_model.svh` | modify | PDE lookup/update/clear golden，L2 direct accerr expected completion，update payload compare。 |
| `ptw_source_sb.svh` | modify | compare access_src/pde_reason，新增 coverage/no-extra-LSU checker。 |
| `mmu_pde_cache_sva.sv` | modify | 新增 ports/helper/assert/cover `PTW-SVA-PDE-011..017`。 |
| `mmu_arb_sva.sv` | modify | 新增 PDE direct accerr priority SVA。 |
| `mmu_ptw_top_sva.sv` | modify | 如 priority 信号只在 PTW top 可见，则在此补 completion class/type-id 断言。 |
| `ptw_source_directed_base.svh` | modify | 新增 pmpflg/PDE cache prime/source request helper。 |
| `ptw_tests_suite.svh` | modify | include 新增 tests。 |
| `test_ptw_l1_pde_hit.svh` 等现有 PDE tests | modify | 修正 tag-only expected，加入 pmpflg allow 前提。 |
| `test_ptw_pde_*.svh` 新增 9 个 | add | 覆盖 `PTW-ADD-037..045`。 |
| `simu/ptw_pde_pmpflg_list` | add | 新增专项 list。 |
| `simu/ptw_p0_list`、`ptw_p1_list`、`ptw_p0_smoke_list` | modify | 加入代表 tests。 |
| `simu/ptw_source_closure_matrix.csv` | modify | 新增 requirements 和 closure evidence。 |
| `scripts/ptw_stage8_signoff_gate.py` | modify | required ids 扩展，新增 PDE PMP coverage/no-extra-LSU 检查，保持旧 Python 兼容。 |
| `doc/ptw_uvm_review/ptw_source_signoff_report.md` | modify | 最终关闭时记录新增 coverage 和 debug 结论。 |

## 8. 实施顺序和依赖

推荐严格按以下顺序执行：

1. Phase 0 probe 审计和新增。
2. Phase 1 transaction schema。
3. Phase 2 PDE model。
4. Phase 3 monitor。
5. Phase 4 ref model。
6. Phase 5 scoreboard/coverage。
7. Phase 6 SVA。
8. Phase 7 directed base helper。
9. Phase 8 旧 tests 修正。
10. Phase 9 新 tests。
11. Phase 10 regression/gate。

不能提前做的事项：

1. 不能在 Phase 0/1 未完成前实现 direct accerr expected，否则 ref model 无法定位 root cause。
2. 不能在 Phase 4 未完成前新增大量 tests，否则失败原因会被 checker 缺口淹没。
3. 不能在 Phase 6 未完成前关闭 `PDE-TP-013..019`，因为 consumer-side pass 不足以证明 source behavior。
4. 不能只通过 `mmu_translation_sb` 的 VA->PA/fault pass 关闭 no-extra-LSU，必须有 PTW memory request evidence 或 SVA evidence。

## 9. 风险和处理策略

| 风险 | 影响 | 处理 |
| --- | --- | --- |
| RTL 内部 raw tag hit/cached pmpflg 信号不可见 | 无法区分 tag miss 与 permission deny | 先通过 `bind PDE_cache` SVA 直接观测；monitor 侧标记 probe gap，不用 consumer-only 关闭。 |
| `p13_pmp_flg_vec` 不能唯一对应 level | update pmpflg 预测可能错误 | 必须增加 MBUF payload probe，不能只用 PMP port flag 推断。 |
| ref model event ordering 与 monitor FIFO 不稳定 | update compare false fail | predicted update queue 使用小 window 匹配，并打印 unmatched debug；不能无限宽松。 |
| L2 direct accerr 与 bus error/TWU accerr 同周期优先级不清 | expected completion 可能错误 | 以 RTL 设计文档为准，新增 priority SVA 和 directed priority test。 |
| all-allow 旧 tests 被 pmpflg 新字段初始化影响 | 大面积回归失败 | 默认 pmpflg 初始化为 allow-safe，例如 `4'h7` 或根据真实 PMP default；不可让 `x` 参与 allow 判断。 |
| MPRV/MPP effective mode 语义重复实现不一致 | M-mode bypass 测试误判，或把 data/PFU `MPRV=1 && MPP=M` 误建模成合法 PTW source | 所有 pde pmp allow 调用统一 helper；top-level source 侧 data/PFU effective-M accept 必须报 illegal，cached pmpflg bit3 matrix 需 lower-level/RTL unit evidence。 |
| no-extra-LSU checker 无法归属 memory request | 不能关闭性能语义 | directed tests 保持单 outstanding；多 pending 随机只作为 supplemental。 |

## 10. 推荐验证命令

### 10.1 每阶段基础编译

```bash
make -C mmu_verification build TEST_NAME=test_ptw_source_stage2_smoke
```

### 10.2 单 test run_check

```bash
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l1_pmp_tag_deny_fst_fault_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_pmp_l1_deny_accerr_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_pmp_l2_deny_accerr_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_ptw_pde_pmpflg_propagation_update_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"

make -C mmu_verification run_check TEST_NAME=test_ptw_pde_mmode_lock_matrix_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

### 10.3 专项 regression

```bash
make regress LIST=simu/ptw_pde_pmpflg_list REGRESS_MODE=run_check REGRESS_NAME=ptw_pde_pmpflg REGRESS_SEEDS="606 707" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
```

### 10.4 P0/P1 回归

```bash
make regress LIST=simu/ptw_p0_smoke_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_smoke_after_pde_pmpflg REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1

make regress LIST=simu/ptw_p0_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p0_after_pde_pmpflg REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1

make regress LIST=simu/ptw_p1_list REGRESS_MODE=run_check REGRESS_NAME=ptw_p1_after_pde_pmpflg REGRESS_SEEDS="606" REGRESS_JOBS=1 UVM_CONFIG_DB_TRACE=0 UVM_ERR_ONLY=1
```

### 10.5 signoff gate

```bash
python3 scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list simu/ptw_p0_smoke_list \
  --p0-list simu/ptw_p0_list \
  --p1-list simu/ptw_p1_list \
  --legacy ../doc/ptw_uvm_review/ptw_legacy_test_action_list.md
```

如果新增专项 list 后 gate 支持 `--pde-pmpflg-list`，则使用：

```bash
python3 scripts/ptw_stage8_signoff_gate.py \
  --p0-smoke-list simu/ptw_p0_smoke_list \
  --p0-list simu/ptw_p0_list \
  --p1-list simu/ptw_p1_list \
  --pde-pmpflg-list simu/ptw_pde_pmpflg_list \
  --legacy ../doc/ptw_uvm_review/ptw_legacy_test_action_list.md
```

## 11. 最终退出标准

本次 UVM 修改完成后，必须同时满足：

1. 编译通过，无新增 VCS error，关键 warning 有解释或已清理。
2. 所有新增 `test_ptw_pde_*pmp*` directed tests 通过。
3. 所有被修改的旧 PDE tests 通过。
4. `ptw_pde_pmpflg_list` 在至少 `606` 和 `707` 两个 seed 通过。
5. `ptw_p0_smoke_list`、`ptw_p0_list`、`ptw_p1_list` 不回归。
6. source SB summary：
   - `mismatch=0`
   - `pending=0`
   - `illegal=0`
7. 新增 PDE PMP coverage banner 中关键 bin 命中：
   - L1 tag hit allow
   - L1 tag hit deny miss
   - L2 tag hit allow
   - L2 cached L1 deny direct accerr
   - L2 cached L2 deny direct accerr
   - pmpflg update L1/L2
   - effective M bypass
   - effective M lock deny
   - no-extra-LSU
8. SVA cover 命中：
   - `PTW-SVA-PDE-011`
   - `PTW-SVA-PDE-012`
   - `PTW-SVA-PDE-013`
   - `PTW-SVA-PDE-014`
   - `PTW-SVA-PDE-015`
   - `PTW-SVA-PDE-017`
   - `PTW-SVA-ARB-010`
9. `ptw_stage8_signoff_gate.py` 更新后通过。
10. `ptw_source_closure_matrix.csv`、`ptw_source_signoff_report.md` 更新并能追溯到所有新增 requirement。

## 12. Debug 关注点

实现和调试时优先看以下日志字段：

1. `PTW_PDE_EVT`：
   - `kind`
   - `reason`
   - `l1_tag_hit/l2_tag_hit`
   - `l1_hit/l2_hit`
   - `cached_l1pmpflg/cached_l2pmpflg`
   - `direct_accerr`
2. `PTW_EXPECTED`：
   - `access_src`
   - `pde_reason`
   - `pde_direct_accerr`
   - `fault_kind`
   - `target_mask`
3. `PTW_SOURCE_MISMATCH`：
   - 若 class mismatch，先确认 L1 deny 是否被错误建模为 direct accerr。
   - 若 pending mismatch，确认 direct accerr visible completion 是否 retire active key。
   - 若 unexpected memory request，确认 L2 tag-hit deny 是否错误走了 miss path。
4. `PTW_SVA_COVER`：
   - 若 cover 不命中，先确认 directed test 是否真的建立了 PDE cache entry。
   - 若 assertion fail，优先检查 effective M-mode 和 pmpflg bit3 语义。

## 13. 不允许的关闭方式

以下方式不能关闭本次设计变更：

1. 仅看到最终 L1DTLB/L2TLB access fault。
2. 仅看到 translation scoreboard pass。
3. 仅看到 PDE cache hit 后最终 refill 正确。
4. 随机 seed 中疑似触发但没有 source-side cover。
5. L2 direct accerr 场景没有证明 no-extra-LSU。
6. 未观测 cached pmpflg，却用 PMP port 瞬时 flag 推断 update payload。
7. 把 L1 tag hit deny 和 L2 tag hit deny 用同一个 miss expected 关闭。

## 14. 计划完成后的文档更新

实现完成并通过退出标准后，需要更新：

1. `doc/ptw_uvm_review/ptw_implementation_process.md`
   - 记录本次 PDE cache pmpflg UVM 修改阶段完成。
   - 记录新增 tests、list、gate 和退出命令。
2. `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_design_change.md`
   - 如实现中发现设计文档需要澄清，追加 debug/clarification，不覆盖原始结论。
3. `doc/ptw_uvm_review/ptw_source_signoff_report.md`
   - 记录最终 signoff evidence。
4. `doc/ptw_uvm_review/ptw_source_closure_matrix.md` 或 CSV 对应源文件
   - 标记 `PTW-ADD-037..045`、`PDE-TP-013..019`、`PTW-FLOW-024..028` closure 状态。

## 15. 推荐首个实现切入点

建议实际实现时先做最小闭环：

1. 增加 probe：`pde_cache_update_l1pmpflg/l2pmpflg`、`pde_cache_acc_err_vld/type/id`。
2. 扩展 `ptw_src_pde_evt_txn` 和 monitor。
3. 扩展 `ptw_pde_cache_model.lookup_detail()`。
4. 新增 `test_ptw_pde_l2_pmp_l2_deny_accerr_001`。
5. 跑通 L2 cached L2 deny direct accerr。

这个闭环覆盖最大风险点：L2 tag hit deny 不能当 miss，且不能发 LSU。该点通过后，再补 L1 deny miss、pmpflg propagation、M-mode matrix 和 priority。
