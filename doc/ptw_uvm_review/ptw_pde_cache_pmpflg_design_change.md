# PTW PDE Cache PMP Flag Tagging Design Change

本文记录本次 RTL 修改：PDE cache entry 记录生成该 non-leaf PDE 时各级页表访问的 PMP flag，并在后续 PDE cache lookup 时按当前请求 `type` 重新判断该 cached PDE 是否可被复用。该文档用于把本次设计语义、信号流、模块改动和验证影响冻结到 `ptw_uvm_review` 中。

## 1. 问题背景

原设计已经在 PMP 配置改变时清空 PDE cache。这可以解决 PMP 配置更新后的 stale PDE 问题，但不能解决同一 PMP 配置下、不同请求类型复用同一 PDE cache entry 的权限问题。

典型问题场景：

1. 一个 `fetch` 类型请求访问第一级页表。
2. 第一级 PMP 检查按 fetch 权限位通过。
3. PTW 通过 LSU 读回第一级页表数据。
4. 读回的 PTE 是 non-leaf PDE，因此被更新到 L1 PDE cache。
5. 后续一个 `load` 类型请求命中这条 L1 PDE cache entry。
6. 如果只按 VPN tag 命中并直接跳过第一级页表访问流水线，那么 load 请求不会重新经历第一级页表物理地址的 load 权限 PMP 检查。

这不合理，因为 PMP flag 是按请求类型解释的：

| 请求类型              | PTW type 编码    | 使用的 PMP flag bit |
| --------------------- | ---------------- | ------------------- |
| load                  | `3'b010`       | `pmpflg[0]`       |
| fetch                 | `3'b011`       | `pmpflg[2]`       |
| PFU/prefetch          | `3'b100`       | `pmpflg[0]`       |
| store                 | `3'b110`       | `pmpflg[1]`       |
| machine-mode lock/deny | effective M-mode | `pmpflg[3]`，0 表示 M-mode 可 bypass，1 表示不 bypass |

因此，某个 fetch 请求读第一级页表时 PMP 通过，只能证明 `pmpflg[2]` 或 machine override 条件满足，不能证明后续 load/store/PFU 请求也可以复用该 PDE cache entry 并跳过对应 level 的 PMP 检查。

## 2. 修改目标

本次修改的目标是让 PDE cache 命中语义从“VPN 命中即可复用”增强为“VPN 命中且本请求类型在 cached PMP flag 下有权限才可复用”。

具体目标：

1. L1 PDE cache entry 记录第一级页表访问时返回的 `l1pmpflg`。
2. L2 PDE cache entry 同时记录第一级页表访问的 `l1pmpflg` 和第二级页表访问的 `l2pmpflg`。
3. L1 PDE cache lookup 时，当前请求 type 必须通过 entry 中保存的第一级 PMP flag，才算真正 hit。
4. L2 PDE cache lookup 时，当前请求 type 必须同时通过 entry 中保存的第一级和第二级 PMP flag，才算真正 hit。
5. 如果 L2 PDE cache 的 VPN tag 匹配但 PMP flag 不允许当前请求 type 复用，则直接上报 access fault，避免重新访问 LSU 读取第二级页表造成性能下降。
6. L1 PDE cache 的 PMP flag 不匹配不直接上报 access fault，而是当作 miss 继续进入 `fst_pmp`，由正常第一级 PMP 流水线在下一拍判断并触发 access fault。这样只多一个周期，不会多一次 LSU page-table read。

## 3. 整体数据流

### 3.1 FST level non-leaf PDE 建立 L1 PDE cache

1. `fst_pmp` 对第一级页表物理地址进行 PMP 检查。
2. `fst_pmp` 向 MBUF 发送请求时携带当前 PMP 返回的 `pmp_mmu_flg[3:0]`。
3. `twu_mbuf_pmpflg` 对 FST level 请求编码为 `{4'b0, pmp_mmu_flg[3:0]}`。
4. `ptw_mbuf` 根据仲裁选中的 TWU 请求，把 8-bit PMP flag 写入对应 `mbuf_entry`。
5. LSU 返回页表数据后，`ptw_mbuf` 把 entry 中保存的 PMP flag 和页表数据一起返回给 TWU。
6. 如果该 FST PTE 是 non-leaf，则更新 L1 PDE cache，并把 `mbuf_twu_pmpflg[3:0]` 作为 `l1pmpflg` 写入 cache entry。
7. 同一个 non-leaf PTE 返回给 `fst_chk` 时，也把 `mbuf_twu_pmpflg[3:0]` 更新到 `fst_chk_l1pmmpflg`。

### 3.2 FST non-leaf 后进入 SCD level

1. `fst_chk` 发现第一级 PTE 是 non-leaf 且没有 page fault。
2. 请求进入 `scd_pmp`。
3. `scd_pmp` 从 `fst_chk_l1pmmpflg` 继承第一级页表访问的 PMP flag，保存到 `scd_pmp_l1pmpflg`。
4. `scd_pmp` 对第二级页表物理地址进行 PMP 检查，得到新的 `pmp_mmu_flg[3:0]`。
5. `scd_pmp` 向 MBUF 发送请求时携带两级 PMP flag：`{l2pmpflg, l1pmpflg}`，当前 RTL 表达为 `{pmp_mmu_flg[3:0], scd_pmp_l1pmpflg[3:0]}`。
6. LSU 返回第二级页表数据后，如果第二级 PTE 是 non-leaf，则更新 L2 PDE cache，并把低 4 bit 作为 `l1pmpflg`、高 4 bit 作为 `l2pmpflg` 写入 cache entry。

### 3.3 PDE cache hit 使用当前请求 type 重新解释 PMP flag

PDE cache entry 保存的是“当时读 page-table memory 时 PMP 返回的 flag”，不是保存某个固定请求类型的通过结果。后续 lookup 必须使用当前请求的 `ptw_type` 重新解释这些 flag。

L1 PDE cache hit 条件：

```text
vpn_tag_match &&
(
  l1pmp_ok(current_type, cached_l1pmpflg)
  ||
  (effective_machine_mode && !cached_l1pmpflg[3])
)
```

L2 PDE cache hit 条件：

```text
vpn_tag_match &&
(
  l1pmp_ok(current_type, cached_l1pmpflg) &&
  l2pmp_ok(current_type, cached_l2pmpflg)
  ||
  (effective_machine_mode && !cached_l1pmpflg[3] && !cached_l2pmpflg[3])
)
```

其中 `l1pmp_ok/l2pmp_ok` 按请求 type 选择对应 PMP bit：

```text
fetch: pmpflg[2]
load : pmpflg[0]
store: pmpflg[1]
PFU  : pmpflg[0]
```

## 4. L1 PDE Cache 行为

修改文件：`mmu/rtl/L1PDE_cache.sv`

### 4.1 接口变化

原接口：

```systemverilog
input logic [3:0] L1PDE_upd_pmpflg;
output logic      L1PDE_miss_because_pmp;
```

新接口语义：

```systemverilog
input logic [3:0] L1PDE_upd_l1pmpflg;
output logic      L1PDE_entry_hit;
```

`L1PDE_miss_because_pmp` 当前被注释掉，不再从 L1 PDE cache 输出。L1 侧 PMP flag 不匹配只表现为 L1 PDE miss。

### 4.2 Entry 存储内容

每个 L1 PDE cache entry 新增或重命名保存：

```systemverilog
logic [3:0] L1PDE_l1pmpflg;
```

entry 更新时：

```systemverilog
L1PDE_l1pmpflg[3:0] <= L1PDE_upd_l1pmpflg[3:0];
```

### 4.3 Hit 规则

当前请求 type 解析：

```systemverilog
fetch_type = ptw_type == 3'b011;
load_type  = ptw_type == 3'b010;
store_type = ptw_type == 3'b110;
pref_type  = ptw_type == 3'b100;
```

PMP 允许判断：

```systemverilog
fetch -> L1PDE_l1pmpflg[2]
load  -> L1PDE_l1pmpflg[0]
store -> L1PDE_l1pmpflg[1]
PFU   -> L1PDE_l1pmpflg[0]
```

Hit 条件：

```systemverilog
L1PDE_hit =
  (ptw_vpn[TAG_WIDTH-1:0] == L1PDE_tag[TAG_WIDTH-1:0]) &&
  (l1pmp_ok || (cp0_mach_mode && !L1PDE_l1pmpflg[3]));
```

设计含义：

1. VPN 相同但当前 type 不被 cached `l1pmpflg` 允许时，不算 L1 PDE hit。
2. 该请求会进入正常 FST PMP 流水线。
3. 如果真实 FST PMP 对当前 type 不允许，则由 `fst_pmp` 上报 access fault。
4. L1 不额外引出 “tag hit but PMP miss” 的 access fault，是有意设计选择，避免新增 L1 PDE miss fault path；代价只是多一个 PMP pipeline cycle。

## 5. L2 PDE Cache 行为

修改文件：`mmu/rtl/L2PDE_cache.sv`

### 5.1 接口变化

新增请求有效输入：

```systemverilog
input logic ptw_req;
```

更新输入由单一 PMP flag 拆成两级：

```systemverilog
input logic [3:0] L2PDE_upd_l1pmpflg;
input logic [3:0] L2PDE_upd_l2pmpflg;
```

新增 access fault 输出：

```systemverilog
output logic L2PDE_entry_acc_err;
```

### 5.2 Entry 存储内容

每个 L2 PDE cache entry 保存两级 PMP flag：

```systemverilog
logic [3:0] L2PDE_l1pmpflg;
logic [3:0] L2PDE_l2pmpflg;
```

entry 更新时：

```systemverilog
L2PDE_l1pmpflg[3:0] <= L2PDE_upd_l1pmpflg[3:0];
L2PDE_l2pmpflg[3:0] <= L2PDE_upd_l2pmpflg[3:0];
```

### 5.3 Hit 规则

L2 PDE cache hit 需要当前请求同时满足两级 PMP flag：

```systemverilog
L2PDE_hit =
  vpn_tag_match &&
  (
    (l1pmp_ok && l2pmp_ok)
    ||
    (cp0_mach_mode && !L2PDE_l1pmpflg[3] && !L2PDE_l2pmpflg[3])
  );
```

设计含义：

1. L2 PDE cache 命中代表该请求可以同时跳过 FST 和 SCD page-table read。
2. 因此当前请求 type 必须通过 cached L1 PMP flag 和 cached L2 PMP flag。
3. 仅通过 L1、不通过 L2 时，不能再走正常 miss 重新读 SCD page-table；否则会多发一次 LSU 访问，性能上不可接受。

### 5.4 L2 tag hit but PMP denied 直接 access fault

新增判断：

```systemverilog
L2PDE_acc_err =
  ptw_req &&
  vpn_tag_match &&
  !(
    (l1pmp_ok && l2pmp_ok)
    ||
    (cp0_mach_mode && !L2PDE_l1pmpflg[3] && !L2PDE_l2pmpflg[3])
  );
```

设计含义：

1. L2 PDE tag 匹配说明 cached entry 已经知道该请求对应的 L1/L2 non-leaf PDE。
2. PMP flag 不匹配说明当前请求 type 对某一级 page-table memory 没有访问权限。
3. 此时语义上应返回 access fault。
4. 这样避免 “L2 PDE tag hit 但 PMP miss” 被当成普通 cache miss，导致额外访问 LSU 再发现相同 PMP deny。

## 6. PDE Cache Top 行为

修改文件：`mmu/rtl/PDE_cache.sv`

### 6.1 更新接口拆分

MBUF 到 PDE cache 的更新接口从：

```systemverilog
mbuf_cache_upd_pmpflg[3:0]
```

拆分为：

```systemverilog
mbuf_cache_upd_l1pmpflg[3:0]
mbuf_cache_upd_l2pmpflg[3:0]
```

L1 PDE cache 只接收 `mbuf_cache_upd_l1pmpflg`。

L2 PDE cache 同时接收 `mbuf_cache_upd_l1pmpflg` 和 `mbuf_cache_upd_l2pmpflg`。

### 6.2 新增 PDE cache access fault 输出

PDE cache top 新增输出：

```systemverilog
output logic                  PDE_cache_acc_err_vld;
output logic [TYPE_WIDTH-1:0] PDE_cache_acc_err_type;
output logic [ID_WIDTH-1:0]   PDE_cache_acc_err_id;
input  logic                  PDE_cache_acc_err_grant;
```

当任一 L2 entry 发生 `L2PDE_entry_acc_err` 时，PDE cache top 锁存一个 access fault pending：

```systemverilog
PDE_cache_acc_err <= 1'b1;
```

同时锁存当前请求的 `ptw_type` 和 `ptw_id`：

```systemverilog
L2PDE_cache_acc_err_type <= ptw_type;
L2PDE_cache_acc_err_id   <= ptw_id;
```

当 PTW 顶层仲裁给出 `PDE_cache_acc_err_grant` 后清除 pending。

### 6.3 Hit 输出优先级

L2 PDE cache hit 仍优先于 L1 PDE cache hit：

```systemverilog
casez({L2PDE_entry_hit_vld, L1PDE_entry_hit_vld})
  2'b01: PDE_cache_fin_ppn = L1PDE_cache_hit_ppn;
  2'b1?: PDE_cache_fin_ppn = L2PDE_cache_hit_ppn;
endcase
```

输出到 xbar：

```systemverilog
L2PDE_xbar_hit_vld = L2PDE_entry_hit_vld;
L1PDE_xbar_hit_vld = L1PDE_entry_hit_vld & ~L2PDE_entry_hit_vld;
PDE_xbar_ppn       = PDE_cache_fin_ppn;
PDE_xbar_vpn/type/id = ptw_vpn/type/id;
```

### 6.4 Cache clear 条件保持

PDE cache 仍在以下条件清空：

```systemverilog
regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update
```

本次修改不是替代 PMP 更新清空，而是补充“同一 PMP 配置下，不同 request type 不能无条件复用 PDE cache”的动态检查。

## 7. MBUF 中 PMP Flag 的传递

修改文件：`mmu/rtl/mbuf_entry.sv`、`mmu/rtl/ptw_mbuf.sv`

### 7.1 MBUF entry 存储位宽

`mbuf_entry` 的 PMP flag 接口从 4-bit 扩展为 8-bit：

```systemverilog
input  logic [7:0] mbuf_upd_pmpflg;
output logic [7:0] mbuf_entry_pmpflg;
```

设计语义：

```text
mbuf_entry_pmpflg[3:0] = l1pmpflg
mbuf_entry_pmpflg[7:4] = l2pmpflg
```

对于 FST level 请求：

```text
{l2pmpflg, l1pmpflg} = {4'b0, fst_pmp_flg}
```

对于 SCD level 请求：

```text
{l2pmpflg, l1pmpflg} = {scd_pmp_flg, inherited_l1pmpflg}
```

对于 THD level 请求：

```text
PDE cache 不使用 THD 的 PMP flag，因此当前语义为 8'b0。
```

### 7.2 ptw_mbuf 选择和回传

`ptw_mbuf` 的 TWU 输入扩展为：

```systemverilog
input logic [3:0][7:0] twu_mbuf_pmpflg;
```

选中某个 TWU 的 MBUF request 时，8-bit PMP flag 随同 `paddr/vpn/type/id/lvl/twu_idx` 一起写入 MBUF entry。

LSU 返回后，`ptw_mbuf` 从命中的 entry 输出：

```systemverilog
output logic [7:0] mbuf_twu_pmpflg;
```

该信号同时用于：

1. 回传给 TWU 的 `fst_chk`，让 FST non-leaf 之后的 SCD stage 继承 `l1pmpflg`。
2. 生成 PDE cache update 的两级 PMP flag：

```systemverilog
pde_updata_l1pmpflg <= mbuf_twu_pmpflg[3:0];
pde_updata_l2pmpflg <= mbuf_twu_pmpflg[7:4];
```

输出给 PDE cache：

```systemverilog
mbuf_cache_upd_l1pmpflg = pde_updata_l1pmpflg;
mbuf_cache_upd_l2pmpflg = pde_updata_l2pmpflg;
```

## 8. TWU 中 PMP Flag 的传播

修改文件：`mmu/rtl/twu.sv`

### 8.1 MBUF 回传到 FST CHK

TWU 新增 MBUF 回传输入：

```systemverilog
input logic [7:0] mbuf_twu_pmpflg;
```

当 FST level LSU data 返回并进入 `fst_chk` 时，同时保存第一级 PMP flag：

```systemverilog
fst_chk_l1pmmpflg <= mbuf_twu_pmpflg[3:0];
```

### 8.2 FST CHK non-leaf 进入 SCD PMP

当 `fst_chk` 发现 non-leaf 且没有 page fault，并把请求推进到 `scd_pmp` 时：

```systemverilog
scd_pmp_l1pmpflg <= fst_chk_l1pmmpflg;
```

这样第二级页表访问的 MBUF request 能同时携带：

1. 第一级 page-table memory 的 PMP flag。
2. 第二级 page-table memory 的 PMP flag。

### 8.3 SCD PMP request 到 MBUF

TWU 写 MBUF 仲裁中：

FST level：

```systemverilog
twu_mbuf_pmpflg = {4'b0, pmp_mmu_flg[3:0]};
```

SCD level：

```systemverilog
twu_mbuf_pmpflg = {pmp_mmu_flg[3:0], scd_pmp_l1pmpflg[3:0]};
```

THD level：

```systemverilog
twu_mbuf_pmpflg = 8'b0;
```

## 9. PTW Top Access Fault Path

修改文件：`mmu/rtl/ptw.sv`

### 9.1 PDE cache access fault 接入 PTW 顶层

`PDE_cache` 新增 access fault 输出接入 PTW：

```systemverilog
PDE_cache_acc_err_vld
PDE_cache_acc_err_type
PDE_cache_acc_err_id
PDE_cache_acc_err_grant
```

`PDE_cache_acc_err_grant` 连接到顶层 access fault grant 的新增 bit：

```systemverilog
acc_err_twu_grant[5]
```

### 9.2 access fault vld 汇总

原 access fault 来源：

1. 四个 TWU 的 PMP/access fault。
2. MBUF/LSU bus error。

本次新增：

3. PDE cache L2 tag hit but PMP flag denied。

汇总：

```systemverilog
acc_err_vld =
  (|twu_l2tlb_ref_acc_err[3:0])
  | mbuf_bus_error
  | PDE_cache_acc_err_vld;
```

### 9.3 输出 type/id

新增的 PDE cache access fault 返回原始请求的 `type/id`：

```systemverilog
ptw_l2tlb_acc_err_type = PDE_cache_acc_err_type;
ptw_l2tlb_acc_err_id   = PDE_cache_acc_err_id;
```

这保持 PTW exception 返回协议不变：fault class 是 access fault，`type/id` 用于定位原始请求来源和释放对应 miss buffer。

## 10. 行为示例

### 10.1 Fetch 建立 L1 PDE，Load 后续访问同 VPN

1. Fetch 请求读 FST page-table PA，PMP flag 为 `F=1, R=0, W=0`。
2. FST PTE 是 non-leaf，entry 更新到 L1 PDE cache，保存 `l1pmpflg`。
3. 后续 load 请求 lookup L1 PDE cache。
4. VPN tag 匹配，但 load 需要 `l1pmpflg[0]`。
5. 若 `l1pmpflg[0]=0`，L1 PDE cache 不 hit。
6. 请求进入 `fst_pmp`，正常执行第一级 PMP 检查。
7. `fst_pmp` 根据当前 load type 和 PMP flag 上报 access fault。

### 10.2 L2 PDE tag 命中但第二级 PMP 不允许当前 type

1. 先前请求建立了 L2 PDE cache entry，保存 `l1pmpflg` 和 `l2pmpflg`。
2. 后续请求 VPN 命中该 L2 entry。
3. 当前 type 通过 `l1pmpflg`，但不通过 `l2pmpflg`。
4. L2 PDE cache 不输出 hit。
5. 同时产生 `L2PDE_entry_acc_err`。
6. `PDE_cache` 锁存 `PDE_cache_acc_err_vld/type/id`。
7. `ptw` 顶层 access fault 仲裁后把 access fault 返回给原始 source。
8. 不再额外发起一次 LSU page-table read。

### 10.3 PMP 配置改变

1. PMP CSR 或相关配置改变。
2. `pmp_regs_update` 触发。
3. PDE cache 仍被清空。
4. 后续请求不会使用旧 PMP 配置下的 cached PDE。
5. 本次 PMP flag tag 机制只处理“配置未变但请求 type 不同”的复用合法性。

## 11. 对 UVM / Verification 的影响

本次设计变更会影响 PTW source-side reference model、monitor、scoreboard 和 directed/random tests 的预期。

### 11.1 Reference model 需要新增的语义

1. PDE cache model entry 需要保存 `l1pmpflg` 和 `l2pmpflg`。
2. L1 PDE model hit 不能只比较 VPN/tag，还要按当前 `type` 检查 `l1pmpflg`。
3. L2 PDE model hit 不能只比较 VPN/tag，还要同时检查 `l1pmpflg` 和 `l2pmpflg`。
4. L1 tag hit but PMP deny 应建模为 L1 miss，随后由 FST PMP 检查触发 access fault。
5. L2 tag hit but PMP deny 应建模为 PDE cache 直接 access fault，不应再期待 LSU memory request。
6. PMP config update 仍清空 PDE cache。

### 11.2 Monitor/probe 需要关注的信号

建议新增或确认以下可观测性：

1. PDE cache update 时的 `mbuf_cache_upd_l1pmpflg`。
2. PDE cache update 时的 `mbuf_cache_upd_l2pmpflg`。
3. L1 PDE hit 是否因 PMP flag 不匹配而被压成 miss。
4. L2 PDE tag hit but PMP flag denied 时的 `PDE_cache_acc_err_vld/type/id`。
5. PTW 顶层 access fault 输出是否使用 PDE cache 的 `type/id`。

### 11.3 Directed test 建议

建议补充以下 directed cases：

| 场景                                                          | 预期                                                                 |
| ------------------------------------------------------------- | -------------------------------------------------------------------- |
| fetch 建 L1 PDE，load 同 VPN 但 `l1pmpflg[0]=0`             | L1 PDE 不 hit；进入 FST PMP；access fault；无错误复用                |
| fetch 建 L1 PDE，fetch 同 VPN 且 `l1pmpflg[2]=1`            | L1 PDE hit                                                           |
| load 建 L1 PDE，PFU 同 VPN 且 `l1pmpflg[0]=1`               | L1 PDE hit                                                           |
| load 建 L2 PDE，store 同 VPN 但 `l1pmpflg[1]=0`             | L2 PDE acc_err                                                       |
| load 建 L2 PDE，store 同 VPN 且 L1 allow 但 `l2pmpflg[1]=0` | L2 PDE acc_err，不发 LSU                                             |
| L2 tag hit but PMP deny                                       | `PDE_cache_acc_err_vld=1`，PTW 返回 access fault，`type/id` 正确 |
| PMP config update 后再查旧 PDE                                | PDE cache miss，不能使用旧 entry                                     |
| effective M-mode 且 cached `[3]=0` lock 未置位              | 可按 M-mode bypass 命中对应 PDE cache                                |
| effective M-mode 但任一级 cached `[3]=1` lock/deny 置位     | 不能仅靠 M-mode bypass；仍需对应 R/W/X bit 允许，否则 L2 direct acc_err，L1 回 fst path |

### 11.4 Scoreboard 需要避免的错误预期

1. 不能把 L2 PDE tag hit but PMP denied 建模成普通 PDE miss。
2. 不能期待该场景产生新的 PTW memory request。
3. 不能把 L1 PDE tag hit but PMP denied 建模成 PDE cache access fault；L1 应回到 FST PMP path。
4. Access fault 可来自 PDE cache，而不仅来自 TWU PMP stage 或 MBUF bus error。
5. `type/id` 应来自当前触发 PDE cache access fault 的 PTW request。

## 12. 当前 RTL 改动文件清单

本次观察到的 RTL 修改文件：

| 文件                       | 主要修改                                                                                                                     |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `mmu/rtl/L1PDE_cache.sv` | L1 entry 保存 `L1PDE_l1pmpflg`；hit 条件加入当前 type 对 cached l1 PMP flag 的检查；移除/注释 L1 PMP miss 直接输出。       |
| `mmu/rtl/L2PDE_cache.sv` | L2 entry 保存 `L2PDE_l1pmpflg/L2PDE_l2pmpflg`；hit 条件加入两级 PMP flag 检查；新增 `L2PDE_entry_acc_err`。              |
| `mmu/rtl/PDE_cache.sv`   | MBUF update PMP flag 拆成 l1/l2；实例化 L1/L2 cache 新接口；新增 `PDE_cache_acc_err_vld/type/id/grant` pending path。      |
| `mmu/rtl/mbuf_entry.sv`  | MBUF entry PMP flag 接口扩展到 8 bit，用于保存 `{l2pmpflg,l1pmpflg}`。                                                     |
| `mmu/rtl/ptw_mbuf.sv`    | TWU-to-MBUF PMP flag 扩展到 8 bit；LSU data 返回后把 PMP flag 回传 TWU；PDE update 输出 l1/l2 PMP flag。                     |
| `mmu/rtl/twu.sv`         | MBUF data 返回携带 PMP flag；FST CHK 保存 l1 PMP flag；SCD PMP 继承 l1 PMP flag；MBUF request 按 level 生成 8-bit PMP flag。 |
| `mmu/rtl/ptw.sv`         | PDE cache access fault 接入顶层 access fault 汇总和 type/id mux；新增 grant bit。                                            |

## 13. 集成检查点

以下检查点来自当前 RTL diff，应在编译和回归中确认：

1. 所有 `pmpflg` 信号位宽必须端到端一致。设计目标是 TWU->MBUF、MBUF entry、MBUF->TWU、MBUF->PDE update 使用 8-bit `{l2pmpflg,l1pmpflg}`。
2. `twu.sv` 的 `twu_mbuf_pmpflg` 端口应与 `ptw_mbuf.sv` 的 `[7:0]` 输入一致。
3. `ptw_mbuf.sv` 内部 `mbuf_upd_pmpflg`、`mbuf_entry_pmpflg`、`pde_updata_l1pmpflg/l2pmpflg`、`mbuf_twu_pmpflg` 的声明应与 8-bit 传递语义一致。
4. `ptw_mbuf` 实例化 `mbuf_entry` 时，`mbuf_upd_pmpflg` 连接应传完整 8 bit，而不是只传 `[3:0]`。
5. `ptw.sv` 中 `twu_acc_err_sel` 从 5 路扩到 6 路后，声明位宽、赋值位宽和 case 选择宽度必须一致。
6. access fault 仲裁优先级应明确：PDE cache acc_err、MBUF bus error、TWU access fault 同时出现时，grant onehot 和 type/id mux 必须可预测。
7. `PDE_cache_acc_err_vld` pending 期间如果又有新的 L2 acc_err，应确认 type/id 是否允许覆盖，或者应被 pending 阻塞。
8. L2 PDE cache acc_err 应仅在 `ptw_req` 有效且 tag match 时产生，不能在 idle 或无效请求周期误触发。
9. L1 PDE cache tag match but PMP deny 不应更新 PLRU read-hit；当前 L1 hit 已被 PMP 条件过滤，因此 PLRU 只应在合法 hit 时更新。
10. L2 PDE tag match but PMP deny 不应输出 `L2PDE_xbar_hit_vld`，而应走 `PDE_cache_acc_err_vld`。

## 14. 语义冻结

本次变更后，PDE cache 不再是只由 VPN/ASID/level 决定的纯地址缓存。它还包含产生该 cached non-leaf PDE 时 page-table memory 访问的 PMP permission evidence。

最终语义如下：

1. PDE cache entry 可以跨请求复用，但只能被当前请求 type 在 cached PMP flag 下仍有权限的请求复用。
2. PMP 配置改变仍清空 PDE cache，这是配置级 stale 防护。
3. cached PMP flag 是同一配置下跨 type 复用的权限防护。
4. L1 PDE cache PMP 不匹配走 normal FST PMP path。
5. L2 PDE cache PMP 不匹配直接 access fault，避免多余 LSU page-table read。
6. 所有 access fault 返回仍遵守 PTW source 协议：只返回 access fault class，携带原始 `type/id` 用于定位 requester 和释放 miss buffer。

## 15. 待确认问题

我已理解本次修改的主目标：PDE cache entry 保存 page-table memory 访问时的 PMP flag，并在后续 lookup 时用当前请求 `type` 重新解释 cached PMP flag，避免不同请求类型错误复用 non-leaf PDE。下面这些点仍需要确认，否则 UVM reference model 和 checker 的精确建模可能会有歧义。

1. `pmpflg[3]` 的 machine-mode 语义需要统一确认。文档和当前 L1/L2 PDE cache hit 条件写成 `cp0_mach_mode && cached_pmpflg[3]` 允许命中；但 TWU PMP access-fault 逻辑历史上常见写法是 `!(mach_mode && !pmp_mmu_flg[3])`，即 `pmpflg[3]=0` 时 M-mode override 生效。请确认本次 PDE cache 中 `pmpflg[3]` 到底表示 “M-mode allow” 还是 “M-mode lock/deny”。答：是M-mode lock/deny的意思，pde cache中相关我已经修改。
2. L2 PDE cache 的 `L2PDE_acc_err` 是否必须 gated by `L2PDE_vld`？当前语义描述是 “L2 tag hit but PMP denied” 触发 access fault，这通常隐含 entry valid；如果只比较 tag 而不带 valid，reset 后或无效 entry tag 巧合匹配时可能误报 access fault。答：需要带valid，我已经修改。
3. `PDE_cache_acc_err_vld` pending 期间，如果又出现新的 L2 tag-hit PMP deny，`type/id` 是否允许被新请求覆盖？如果不允许覆盖，PDE cache top 是否需要在 pending 未 grant 前阻塞或忽略新的 acc_err 更新？答：因为 `PDE_cache_acc_err_vld`返回的优先级是最高的，所以不会出现被新请求覆盖而丢失的情况。
4. 顶层 access fault 仲裁优先级需要最终确认：当 `PDE_cache_acc_err_vld`、`mbuf_bus_error`、`twu_l2tlb_ref_acc_err` 同时有效时，期望优先级是 PDE cache 高于 bus error 和 TWU，还是 bus error 高于 PDE cache，或按 TWU index 优先？UVM 需要按最终优先级检查返回的 `type/id`。答：优先级是 PDE cache 高于 bus error 和 TWU。
5. 本次设计目标是否要求 `twu_mbuf_pmpflg`、`mbuf_upd_pmpflg`、`mbuf_entry_pmpflg`、`mbuf_twu_pmpflg` 端到端全部为 8-bit `{l2pmpflg,l1pmpflg}`？当前 RTL 片段中仍有部分声明或实例连接保持 4-bit，需确认这是尚未收敛的实现问题，还是某些路径确实只需要低 4 bit。答：8bit是因为有4bit是第一级页表的pmpflg，有4bit是第二级页表的pmpflg。发给mbuf需要两部分都发，因为可能第二级页表是非叶子页表时更新入第二级pde cache可以把两级pmpflg都更新进去。
6. L1 PDE cache tag hit 但 PMP deny 时，文档定义为当作 miss 进入 `fst_pmp`，不直接 access fault。请确认该场景是否允许产生任何 monitor 可见的 “PDE cache lookup tag hit but permission miss” 事件；如果 RTL 不输出该事件，UVM 只能通过后续 FST PMP/access fault 行为间接建模。答：RTL 不输出该事件，该事件通过请求进入fst pmp触发pmp deny而触发访问异常，不在pde cache中触发。
7. L2 PDE cache tag hit 但 PMP deny 时直接 access fault，不再发 LSU page-table read。请确认该 direct acc_err 是否应该和 TWU/MBUF 产生的 access fault 使用完全相同的 source completion/drop 语义，包括同 type/id 未完成请求的释放、scoreboard outstanding entry 清除、coverage 分类。答：该异常的处理按照正常的访问异常处理一样。通过id中LTLB miss buffer部分释放eentry，通过type和其余id部分将该请求的异常上报给L1TLB。
8. L2 PDE hit 条件要求当前 type 同时通过 cached `l1pmpflg` 和 `l2pmpflg`。如果当前 type 不通过 L1 但通过 L2，是否也统一作为 PDE cache direct access fault，而不是回退到 FST PMP path？文档当前倾向于 “任一级不通过都 direct acc_err”，这里需要确认无例外。答：统一作为 PDE cache direct access fault。
9. THD level 请求的 MBUF pmpflg 当前文档定义为 `8'b0` 且 PDE cache 不使用。请确认 THD leaf 或 final PTE 相关 access fault 仍完全由 TWU PMP stage / MBUF bus error 路径处理，UVM 不需要为 THD pmpflg 建 PDE cache 语义。答：因为第三级页表一般情况下必定是叶子页表，不会更新入pde cache，所以不需要携带pmpflg，统一为0即可。
10. PDE cache update 时，如果同一 VPN 已有 entry 但新请求携带不同 PMP flag，当前策略是通过 `entry_before_upd_hit` 避免 refill，还是应该更新 entry 中保存的 PMP flag？这个决定会影响 “先 fetch 建 cache、后 load 因 L1 miss 重新走 FST PMP 并拿到同一 non-leaf PDE” 后 cache evidence 是否会扩展到 load 权限。答：不可能出现同一 VPN 已有 entry但新请求携带不同 PMP flag，因为同一vpn的情况下其生成的访问页表ppn是要求一样的，必然pmpflg也一样。

## 16. 基于 `ptwspec.md` 的 PTW 测试点审查

本节只审查 `ptwspec.md` 中 PTW source-side 相关测试点、scoreboard、monitor、SVA 和覆盖要求，不审查 L1DTLB/L2TLB consumer-only 或 system sysmap/direct-map 自身测试点。审查基准采用本文第 15 节回答后的最终语义：

1. PDE cache entry 除 tag/data 之外，还保存生成该 non-leaf PDE 时 page-table memory 访问返回的 PMP evidence。
2. PMP flag bit 语义为 `pmpflg[0]=R`、`pmpflg[1]=W`、`pmpflg[2]=X`、`pmpflg[3]=M-mode lock/deny`。
3. 当前请求 type 对 cached PMP flag 的允许函数为：

```text
pde_pmp_allow(type, flg, effective_m) =
    (type == fetch && flg[2])
 || (type == load  && flg[0])
 || (type == store && flg[1])
 || (type == pfu   && flg[0])
 || (effective_m && !flg[3])
```

4. L1 PDE cache hit 需要 `valid && tag_match && pde_pmp_allow(current_type, l1pmpflg, effective_m)`。
5. L2 PDE cache hit 需要 `valid && tag_match && pde_pmp_allow(current_type, l1pmpflg, effective_m) && pde_pmp_allow(current_type, l2pmpflg, effective_m)`。
6. L1 tag hit 但 PMP deny 只表现为 L1 PDE miss，后续进入 `fst_pmp`，由正常 PMP path 触发 access fault。
7. L2 tag hit 但任一级 PMP deny 直接产生 PDE cache access fault，不再发 LSU page-table read。
8. L2 PDE cache direct access fault 的处理和普通 PTW access fault 一致，携带原始 `type/id`，释放对应 L2TLB miss buffer，并按 type 上报 L1ITLB/L1DTLB/PFU 目标。

### 16.1 `ptwspec.md` 中需要修正的 PTW 规则

| 位置 | 当前 `ptwspec.md` 规则 | 审查结论 | 需要修改为 |
| --- | --- | --- | --- |
| §3.1 PDE cache 结构 | PDE cache entry 不包含权限、PMA 属性、RSW、A/D 等字段 | `modify` | 保留“不存 ASID/G/RSW/A/D/leaf permission/PMA leaf attr”的结论，但必须新增保存 page-table memory PMP evidence：L1 entry 保存 `l1pmpflg`，L2 entry 保存 `l1pmpflg/l2pmpflg`。 |
| §3.2 Lookup | valid + tag match 即 hit，被跳过级别合法性依赖填入时通过 PMP/CHK | `modify` | hit 还必须按当前 `type` 和 effective mode 重新解释 cached PMP flag。PMP 配置未变也不能跨 type 无条件复用。 |
| §3.3 Update | update 只记录 tag 和 PPN | `modify` | L1 update 必须记录第一级 `l1pmpflg`；L2 update 必须记录 `{l2pmpflg,l1pmpflg}`。 |
| §12.15/12.16 L1 PDE hit flow | L1 hit 后必然跳过 fst 进入 scd | `modify` | 只有 L1 tag hit 且当前 type 被 cached `l1pmpflg` 允许时才跳过 fst；否则进入 fst PMP path。 |
| §12.17 L2 PDE hit flow | L2 hit 后必然跳过 fst/scd 进入 thd | `modify` | 只有 L2 tag hit 且当前 type 同时通过 cached L1/L2 PMP flag 时才进入 thd；任一级 deny 时直接 PDE cache access fault。 |
| §13.1.2 Reference Model 输入 | PMP state 只描述实时 PMP port observation；PDE cache model 不记录 PMP evidence | `modify` | reference model 还必须记录 PDE cache entry 的 cached `l1pmpflg/l2pmpflg`，并在 lookup 时用当前 type/effective mode 重新判断。 |
| §13.1.8 PDE Cache Reference Model | `pde_cache_entry_t` 只有 `valid/tag/ppn` | `modify` | L1 entry 增加 `logic [3:0] l1pmpflg`；L2 entry 增加 `logic [3:0] l1pmpflg,l2pmpflg`。 |
| §13.1.8 PDE cache rules | miss/L1 hit/L2 hit 只按 tag 决定 skip level | `modify` | 增加 L1 permission-qualified miss 和 L2 direct access fault 建模。 |
| §13.2 Assertion/Monitor | PDE cache hit/update/clear 未包含 PMP flag 与 PDE direct access fault | `modify` | 新增 pmpflg propagation、permission-qualified hit、L2 tag-hit deny direct accerr、type/id priority 的断言和 cover。 |
| §13.4 必须覆盖功能场景 | 覆盖 L1 hit、L2 hit、PMP access fault，但没有 PDE cached PMP deny 场景 | `add` | 新增 L1 tag hit but PMP deny、L2 tag hit but L1/L2 PMP deny、PDE accerr priority、cached PMP flag propagation、effective M lock/deny matrix。 |
| §13.12 PDE cache 类测试点最小矩阵 | `PDE-TP-001..012` 没有 pmpflg | `modify + add` | 修改 `PDE-TP-001..004/010/012`，新增 `PDE-TP-013..018`。 |
| §13.21.3 PDE cache SVA | 断言只检查 tag/data/hit level/update/clear | `modify + add` | 修改现有 `PTW-SVA-PDE-003/004/005/006/010`，新增 permission-qualified hit、pmpflg update、direct accerr、valid gate、priority SVA。 |

### 16.2 现有 PTW 测试点需要修改的内容

| 现有测试点或矩阵项 | 当前归属 | 审查结论 | 必须修改的内容 |
| --- | --- | --- | --- |
| `PTW-AUD-005` PDE cache hit/miss/双命中选择 | `modify` | `modify` | hit 判定从 tag-only 改为 tag + cached PMP allow。L1/L2 success flow 必须证明当前 type 允许；双命中仍选 L2，但 L2 也必须 permission-qualified。 |
| `PTW-AUD-006` PDE cache update 条件与时序 | `add` | `modify` | update 条件除 non-leaf/no-page-fault/no-abort 外，还要检查 update payload 中 `l1pmpflg/l2pmpflg` 是否来自正确 level 的 MBUF entry。 |
| `PTW-AUD-007` reset/satp/PMP/abort 清理差异 | `split` | `modify` | PMP config change 仍清空 PDE cache；同时需要证明清空后不会复用旧 cached pmpflg。旧 in-flight walk 重新 update 时应写入其 MBUF entry 保存的 pmpflg。 |
| `PTW-AUD-010` PMP 权限使用原始 request type | `modify` | `modify` | 原始 type 权限不仅要覆盖 TWU PMP stage，也要覆盖 PDE cache lookup 的 cached pmpflg 解释。 |
| `PTW-AUD-011` MPRV/MPP effective privilege | `add` | `modify` | `MPRV=1 && MPP=M` 的 effective M-mode 必须同时覆盖 TWU PMP 检查和 PDE cache cached pmpflg hit/deny。 |
| `PTW-ADD-007` double hit L2 wins | P0 | `modify` | 构造双命中时必须让 L2 cached L1/L2 pmpflg 均允许当前 type；另需新增 L2 tag hit but PMP deny 场景，不能复用该 positive test。 |
| `PTW-ADD-008` lookup/update race | P1 | `modify` | race 检查不仅包含 tag/data，还要包含 pmpflg next-state。lookup 当拍使用旧 pmpflg，update 下一拍才改变 hit/deny 结果。 |
| `PTW-ADD-009` update condition | P0 | `modify` | expected 增加 L1 update 保存 `mbuf_twu_pmpflg[3:0]`，L2 update 保存低 4bit 为 L1、高 4bit 为 L2；leaf/thd leaf/bus error/page fault/abort 不更新 pmpflg。 |
| `PTW-ADD-010` satp/PMP clear no abort | P0 | `modify` | PMP config clear 后旧 entry valid 清零；后续同 VPN 请求不能命中旧 pmpflg。旧 in-flight non-leaf 允许重新 update，并以其 MBUF entry 的 pmpflg 作为新 evidence。 |
| `PTW-ADD-011` abort/reset matrix | P0 | `modify` | abort/reset 不仅屏蔽 tag/data update，也必须屏蔽 pmpflg update 和 PDE direct accerr pending 的 stale 可见性。 |
| `PTW-ADD-014` PMP original type permission | P0 | `modify` | 增加 PDE-cache-hit reuse 子场景：fetch 建 L1/L2 PDE 后 load/store/PFU 复用时按 load/store/PFU 重新解释 cached flag。 |
| `PTW-ADD-015` MPRV MPP M effective mode | P0 | `modify` | 增加 cached pmpflg bit3 lock/deny 矩阵：effective M 且 `flg[3]=0` 可 bypass type bit；`flg[3]=1` 时仍按 type bit 判断。 |
| `PTW-MOD-007` PDE cache smoke tests | `modify` | `modify` | 旧 smoke 不能只证明第二次访问更快或最终 PA 正确；必须补 cached pmpflg、L1 permission miss、L2 direct accerr、no extra LSU request、type/id completion。 |
| `PDE-001/test_pde_cache_l2_single_entry` | `modify` | `modify` | 单 entry L2 hit 必须区分 tag hit allow 和 tag hit deny；deny 不能走普通 miss 或发 LSU。 |
| `PDE-002/test_pde_cache_l1_single_entry` | `modify` | `modify` | 单 entry L1 tag hit deny 应表现为 L1 miss，进入 fst PMP path；不得期待 PDE direct accerr。 |
| `test_ptw_l1_pde_hit.svh` | `modify` | `modify` | 增加当前 type 被 `l1pmpflg` 允许的 positive hit；增加当前 type 不允许时回到 fst PMP 的 negative path。 |
| `test_ptw_l2_pde_hit_direct.svh` | `modify` | `modify` | 增加 L2 cached L1/L2 pmpflg 均允许的 positive hit；新增 L1 deny 和 L2 deny 两个 direct access fault 子场景或拆分测试。 |
| `test_ptw_l1_pde_miss_walk.svh` | `modify` | `modify` | L1 tag hit but PMP deny 也会表现为 miss；测试名和 coverage 需要区分 tag miss 与 permission-qualified miss。 |
| `test_ptw_l2_pde_miss_walk.svh` | `modify` | `modify` | L2 tag hit but PMP deny 不能归入普通 miss walk；必须改 expected 为 PDE direct access fault。 |
| `test_pde_cache_l1_single_entry.svh` | `modify` | `modify` | 增加 `l1pmpflg` update/hit check；tag-only hit expected 作废。 |
| `test_pde_cache_l2_single_entry.svh` | `modify` | `modify` | 增加 `l1pmpflg/l2pmpflg` update/hit/direct accerr check；tag-only hit expected 作废。 |
| `test_mmu_pde_cache_hit_l2_skip_scd.svh` | `modify` | `modify` | 二级 PDE hit 只有 PMP-qualified hit 时才 skip fst/scd；若 tag hit deny，expected 改为 direct access fault。 |
| `test_mmu_pde_cache_full_miss_full_ptw.svh` | `keep + modify` | `modify` | full miss smoke 建 cache 时必须记录 pmpflg，并在后续 hit/reuse 场景中用 source-side monitor 校验。 |
| `test_bug_001_twu_fst_fetch_type.svh` | `modify` | `modify` | fetch/data/PFU original type 不只验证 TWU PMP，也要覆盖 cached pmpflg reuse，尤其 fetch 建 cache 后 load/store 不得无条件 hit。 |

### 16.3 需要新增的 PTW directed 测试点

以下新增测试点应追加到 `ptwspec.md` §13.9 的 `PTW-ADD-*` 或后续实现计划中，编号从当前 `PTW-ADD-036` 之后继续。

| Testpoint ID | 建议测试名 | 绑定需求 | 必须驱动的场景 | Expected behavior / 必须观察点 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| `PTW-ADD-037` | `test_ptw_pde_l1_pmp_tag_deny_fst_fault_001` | `PDE-TP-013`、`PTW-FLOW-024` | 先用 fetch 或 load 建立 L1 PDE entry，后续同 `vpn[2]` 不同 type tag match 但 `l1pmpflg` 不允许当前 type。 | L1 PDE 不输出 hit；请求进入 `fst_pmp`；若实时 FST PMP 也 deny，则正常 TWU access fault；不得产生 PDE direct accerr。 |
| `PTW-ADD-038` | `test_ptw_pde_l1_pmp_tag_allow_reuse_001` | `PDE-TP-013` | L1 tag match 且当前 type 被 cached `l1pmpflg` 允许，包括 load/PFU 共用 R bit、fetch 使用 X bit、store 使用 W bit。 | L1 PDE hit；跳过 fst；进入 scd；无额外 fst LSU read。 |
| `PTW-ADD-039` | `test_ptw_pde_l2_pmp_l1_deny_accerr_001` | `PDE-TP-014`、`PTW-FLOW-025` | L2 entry tag match，cached `l2pmpflg` 允许当前 type，但 cached `l1pmpflg` deny。 | 不输出 L2 hit；`PDE_cache_acc_err_vld=1`；PTW 返回 access fault，`type/id` 为当前请求；不得发新的 LSU page-table read。 |
| `PTW-ADD-040` | `test_ptw_pde_l2_pmp_l2_deny_accerr_001` | `PDE-TP-015`、`PTW-FLOW-026` | L2 entry tag match，cached `l1pmpflg` 允许当前 type，但 cached `l2pmpflg` deny。 | 直接 PDE cache access fault；不回退 scd PMP，不发 LSU；释放对应 L2TLB miss buffer。 |
| `PTW-ADD-041` | `test_ptw_pde_pmpflg_propagation_update_001` | `PDE-TP-016` | 分别执行 FST non-leaf update L1、SCD non-leaf update L2、THD leaf no update。 | FST MBUF payload 为 `{4'b0,l1pmpflg}`；SCD MBUF payload 为 `{l2pmpflg,l1pmpflg}`；L1/L2 cache update 保存正确 pmpflg；THD pmpflg 为 0 且不更新 PDE cache。 |
| `PTW-ADD-042` | `test_ptw_pde_accerr_priority_type_id_001` | `PDE-TP-017`、`PTW-INFRA-008` | PDE cache direct accerr 与 MBUF bus error、TWU access fault 或 page fault 同周期候选。 | PDE cache access fault 优先级最高；输出 fault class 为 access fault；`type/id` 来自 PDE cache 当前请求。 |
| `PTW-ADD-043` | `test_ptw_pde_mmode_lock_matrix_001` | `PDE-TP-018`、`PTW-ADD-015` | effective M-mode 下，cached `pmpflg[3]` 分别为 0/1，并交叉当前 type bit allow/deny。 | `flg[3]=0` 时 M-mode bypass type bit；`flg[3]=1` 时仍按 type bit 决定 hit 或 direct accerr/fst path。 |
| `PTW-ADD-044` | `test_ptw_pde_l2_accerr_valid_gate_001` | `PDE-TP-019` | L2 entry invalid 但 tag reset/旧值巧合匹配，或 `ptw_req=0` 时 tag match。 | 不得产生 `L2PDE_entry_acc_err/PDE_cache_acc_err_vld`；direct accerr 必须 gated by entry valid and request valid。 |
| `PTW-ADD-045` | `test_ptw_pde_pmp_clear_repopulate_001` | `PDE-TP-010/016` | PMP config update 清空 PDE cache，随后旧 in-flight 或新 walk 返回 non-leaf。 | clear 后旧 entry 不可命中；重新 update 的 entry 使用返回请求 MBUF 中保存的 pmpflg。 |

### 16.4 `PDE-TP-*` 最小矩阵修改与新增

| Testpoint | 原结论 | 审查动作 | 更新后的 Expected |
| --- | --- | --- | --- |
| `PDE-TP-001` | PDE miss -> fst 非叶 no-fault 更新 L1 | `modify` | 更新 L1 PDE cache 的同时保存 `l1pmpflg=mbuf_twu_pmpflg[3:0]`，且 `mbuf_twu_pmpflg[7:4]==4'b0`。 |
| `PDE-TP-002` | 一级 hit -> scd 非叶 no-fault，更新 L2 | `modify` | 一级 hit 必须 permission-qualified；SCD non-leaf update L2 时保存 inherited `l1pmpflg` 和 current `l2pmpflg`。 |
| `PDE-TP-003` | 二级 hit 跳 fst/scd | `modify` | 二级 hit 必须同时通过 cached L1/L2 pmpflg；否则不允许进入 thd。 |
| `PDE-TP-004` | 一级和二级同时 hit 选择二级 | `modify` | 双命中选择二级的前提是二级 permission-qualified hit。若二级 tag match 但 PMP deny，应 direct accerr，而不是回退使用一级 hit。 |
| `PDE-TP-005..008` | leaf/page fault/bus error/abort 不 update | `keep + modify` | 除不更新 tag/data 外，还必须不更新 cached pmpflg。 |
| `PDE-TP-009` | lookup/update race | `modify` | lookup 当拍使用旧 tag/data/pmpflg；新 tag/data/pmpflg 下一拍才可影响 hit 或 direct accerr。 |
| `PDE-TP-010` | satp/PMP change clear | `modify` | PMP change 清空 entry valid 后，旧 cached pmpflg 不能再被 lookup 使用；旧 in-flight non-leaf 返回可重新 update 新 pmpflg。 |
| `PDE-TP-011` | reset/tlboper abort | `modify` | reset/abort 必须同时清空或屏蔽 tag/data/pmpflg/direct accerr pending 的 stale 可见性。 |
| `PDE-TP-012` | PLRU hit/write/victim | `modify` | PLRU read-hit 只能由 permission-qualified hit 更新；tag match but PMP deny 不应更新 read-hit PLRU。 |
| `PDE-TP-013` | N/A | `add` | L1 valid tag match but cached `l1pmpflg` denies current type：L1 hit=0，作为 miss 进入 fst path，不产生 PDE direct accerr。 |
| `PDE-TP-014` | N/A | `add` | L2 valid tag match but cached `l1pmpflg` denies current type：产生 PDE direct access fault，不发 LSU，不回退 fst/scd。 |
| `PDE-TP-015` | N/A | `add` | L2 valid tag match but cached `l2pmpflg` denies current type：产生 PDE direct access fault，不发 LSU，不回退 scd。 |
| `PDE-TP-016` | N/A | `add` | TWU->MBUF->PDE cache pmpflg propagation 正确：FST `{0,l1}`，SCD `{l2,l1}`，THD `0`。 |
| `PDE-TP-017` | N/A | `add` | PDE cache direct accerr 返回原始 `type/id`，处理语义等同普通 access fault，并且优先级高于 MBUF bus error 和 TWU accerr。 |
| `PDE-TP-018` | N/A | `add` | effective M-mode 下 cached `pmpflg[3]` lock/deny 语义正确：`flg[3]=0` bypass，`flg[3]=1` 不 bypass。 |
| `PDE-TP-019` | N/A | `add` | L2 direct accerr 必须 gated by `L2PDE_vld && ptw_req && tag_match`，invalid entry 或 idle 周期不得误报。 |

### 16.5 `PTW-FLOW-*` 需要新增的完整流程

| Flow ID | 流程 | 必须 evidence |
| --- | --- | --- |
| `PTW-FLOW-024` | L1 PDE tag hit 但 cached PMP deny | L1 PDE 不 hit；走 fst PMP；若实时 PMP deny，返回普通 TWU access fault；无 PDE direct accerr。 |
| `PTW-FLOW-025` | L2 PDE tag hit，但 cached L1 PMP deny | PDE cache direct access fault；无 xbar hit、无 thd/scd/fst LSU page-table read；`type/id` 正确。 |
| `PTW-FLOW-026` | L2 PDE tag hit，但 cached L2 PMP deny | PDE cache direct access fault；无 xbar hit、无 LSU page-table read；`type/id` 正确。 |
| `PTW-FLOW-027` | PDE cache pmpflg 允许跨 type 复用 | load/PFU 共用 R bit、fetch 使用 X bit、store 使用 W bit；允许时仍按 L1/L2 hit skip-level 流程。 |
| `PTW-FLOW-028` | effective M-mode cached pmpflg lock matrix | `flg[3]=0` 时 bypass type bit；`flg[3]=1` 时仍要求对应 R/W/X bit。 |

### 16.6 需要删除或作废的旧 expected

本次修改不要求删除整个 PTW 测试文件，但以下旧 expected 必须从 PTW source-side closure 中删除或改写：

| 旧 expected | 处理 | 原因 |
| --- | --- | --- |
| PDE cache entry 只由 VPN tag 决定 hit | `delete expected` | 新设计要求 tag + cached PMP flag allow。 |
| PMP 配置改变清 PDE cache 已经足以解决所有跨 type 复用权限问题 | `delete expected` | PMP config 未变但 type 改变时仍可能不能复用 cached PDE。 |
| L1 PDE tag hit but PMP deny 直接由 PDE cache 上报 access fault | `delete expected` | L1 deny 只转为 miss，进入 fst PMP path。 |
| L2 PDE tag hit but PMP deny 被当成普通 PDE miss 并重新访问 LSU | `delete expected` | L2 deny 必须 direct access fault，避免额外 LSU page-table read。 |
| L2 tag hit但二级 PMP deny时回退使用一级 PDE hit | `delete expected` | 二级 tag match 已经说明两级 non-leaf evidence 存在，任一级 deny 都 direct accerr。 |
| `PTW-SVA-PDE-010` 中 “PDE cache entry 不携带 permission/flg” 的绝对表述 | `modify expected` | 应改成“不携带 leaf permission/PMA/RSW/G/ASID，但携带 page-table memory PMP evidence”。 |
| 通过 L1DTLB 最终 fault/replay 证明 PDE cached PMP deny 正确 | `re-scope/consumer-only` | L1DTLB 只能证明消费，不能关闭 PTW source-side L1 miss/L2 direct accerr/no-LSU 行为。 |
| 同 VPN 已有 entry 时要求用不同 pmpflg 覆盖 entry | `delete expected` | 同 VPN 在 PMP 配置稳定时 page-table PA 相同，pmpflg 必然相同；PMP 配置变化会先清 PDE cache。 |

### 16.7 Reference model、scoreboard、monitor 和 SVA 必改项

| 范围 | 审查动作 | 必须支持的内容 |
| --- | --- | --- |
| `ptw_source_ref_model` / `pde_cache_model` | `modify` | `pde_cache_entry_t` 增加 `l1pmpflg/l2pmpflg`；lookup 使用当前 type/effective mode 计算 permission-qualified hit；L2 tag-hit deny 生成 `PTW_EXP_ACCESS_FAULT(pde_cache_pmp_deny)`。 |
| expected transaction | `modify` | `levels[]` 或 `pde{}` trace 增加 `lookup_tag_hit`、`lookup_perm_allow`、`cached_l1pmpflg`、`cached_l2pmpflg`、`pde_direct_accerr`、`pde_accerr_reason=l1pmp_deny/l2pmp_deny`。 |
| PTW memory channel checker | `modify` | L2 direct accerr 场景不得出现新的 LSU PTE read；L1 permission miss 场景允许重新进入 fst PMP 并可能发 LSU 或由 PMP deny 终止。 |
| `ptw_source_sb` | `modify` | access fault 来源新增 PDE cache direct accerr；仍按 `{type,id}` 匹配，并检查目标和 miss buffer release。 |
| PDE cache monitor | `modify` | 捕获 update 时 `mbuf_cache_upd_l1pmpflg/l2pmpflg`，lookup 时 hit level、tag match、permission-qualified hit、L2 accerr valid/type/id。 |
| PMP monitor | `modify` | cached pmpflg allow 函数必须和实时 PMP deny 函数使用同一 type/effective-mode 语义；bit3 按 lock/deny。 |
| coverage | `add` | cross `cache_level(L1/L2) x request_type(fetch/load/store/PFU) x cached_allow/deny x deny_level(L1/L2/both) x effective_m x pmpflg[3]`。 |
| regression grouping | `modify` | `ptw_audit_pde_xbar_list` 加入 `PTW-ADD-037..045`；`ptw_audit_pmp_list` 加入 `PTW-ADD-043`；signoff gate 必须统计 `PDE-TP-013..019`。 |

新增或修改的 source-side SVA/cover 建议如下：

| SVA ID | 断言要求 | 绑定测试点 |
| --- | --- | --- |
| `PTW-SVA-PDE-011` | L1 entry hit iff `valid && tag_match && pde_pmp_allow(type,l1pmpflg,effective_m)`；tag match but deny 不得拉高 L1 hit。 | `PDE-TP-013`、`PTW-ADD-037/038` |
| `PTW-SVA-PDE-012` | L2 entry hit iff `valid && tag_match && allow(l1pmpflg) && allow(l2pmpflg)`。 | `PDE-TP-014/015`、`PTW-ADD-039/040` |
| `PTW-SVA-PDE-013` | L2 valid tag match but either cached PMP deny 时，`PDE_cache_acc_err_vld/type/id` 必须产生，且不得同时产生 `L2PDE_xbar_hit_vld`。 | `PDE-TP-014/015/017` |
| `PTW-SVA-PDE-014` | L2 direct accerr 必须 gated by entry valid and `ptw_req`；invalid/idle tag match 不得误报。 | `PDE-TP-019`、`PTW-ADD-044` |
| `PTW-SVA-PDE-015` | FST/SCD MBUF request 和 PDE cache update 的 pmpflg payload 必须符合 `{4'b0,l1}`、`{l2,l1}`；THD 为 0 且不更新 PDE cache。 | `PDE-TP-016`、`PTW-ADD-041` |
| `PTW-SVA-PDE-016` | L1/L2 tag match but permission deny 不得更新对应 PLRU read-hit；只有 permission-qualified hit 可更新 read-hit PLRU。 | `PDE-TP-012/013/014/015` |
| `PTW-SVA-PDE-017` | PDE cache direct accerr grant 后清 pending；pending 时不得覆盖未授权的 `type/id`。 | `PDE-TP-017`、`PTW-ADD-042` |
| `PTW-SVA-ARB-010` | PDE cache direct access fault 优先级高于 MBUF bus error 和 TWU access fault；输出 `type/id` 来自 PDE cache accerr。 | `PDE-TP-017`、`PTW-ADD-042` |

### 16.8 签核准则更新

1. `PTW-AUD-005/006/007/010/011` 和 `PDE-TP-001..019` 的关闭必须同时具备 source-side scoreboard match 与 PDE/PMP monitor 或 SVA cover hit。
2. L1 permission-qualified miss 必须能证明后续实际进入 fst path；仅看到最终 access fault 不足以关闭，因为该 fault 可能来自错误的 PDE direct accerr。
3. L2 tag-hit deny 必须能证明没有新的 LSU page-table read；仅看到 access fault 不足以关闭，因为错误实现可能多访问一次 LSU 后才 fault。
4. `PTW-ADD-037..045` 不能被普通 PDE cache hit smoke、L1DTLB exception replay 或 end-to-end VA->PA fault 替代。
5. 如果某些 cached pmpflg 或 `PDE_cache_acc_err_*` 信号不可观测，必须登记 monitor/probe 缺口；不能降级为 consumer-only closure。
6. 随机测试只有在报告中输出 `PDE-TP-013..019` 对应 cover bin 命中，并能追溯到 source expected match 时，才能作为本次设计变更的 closure evidence。
