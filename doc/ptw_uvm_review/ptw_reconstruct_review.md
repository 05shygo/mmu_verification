# PTW/TWU PMP/CHK 重构 Review

本文基于当前 working tree 相对 `HEAD` 的差异整理，覆盖本次已经修改的 RTL 文件：

- `mmu/rtl/twu.sv`
- `mmu/rtl/PDE_cache.sv`
- `mmu/rtl/L1PDE_cache.sv`
- `mmu/rtl/one_to_four_xbar.sv`
- `mmu/rtl/ptw.sv`
- `mmu/rtl/ptw_mbuf.sv`
- `mmu/rtl/mbuf_entry.sv`

本次重构的主线是把 `twu` 内部原有的三级 PMP 检查流水和三级 PTE check 流水，收敛成一个统一 `pmp_unit` 和一个统一 `chk_unit`。统一 `pmp_unit` 负责第一级、第二级、三级页表访问前的 PMP 检查；统一 `chk_unit` 只接收 PTW mbuf 返回的 PTE data，并按 `lvl` 在同一套逻辑内完成 page fault/access path 后续处理、refill、CSR/sysmap 跨页检查或继续进入下一层级 PMP 检查。

## 总体结构变化

修改前：

```text
xbar/PDE hit
  -> fst_pmp -> mbuf -> fst_chk
       non-leaf -> scd_pmp -> mbuf -> scd_chk
                       non-leaf -> thd_pmp -> mbuf -> thd_chk

PMP 侧需要 fst/scd/thd 三路 pmp_grant 仲裁。
CHK、page fault、access fault、CSR、refill、mbuf write 侧也有多路选择。
mbuf 返回时通过 twu_data_ready[2:0] 按 level 选择对应 chk ready。
```

修改后：

```text
PDE cache/xbar request
              \
               -> pmp_unit -> mbuf -> chk_unit -> page fault
chk non-leaf  /                         |       -> refill
                                        |       -> CSR/sysmap cross check
                                        \       -> next-level pmp_unit

pmp_unit 的请求来源只有两类：
1. chk_unit 非叶子、无 page fault 的继续 walk 请求，优先级更高。
2. PDE cache/xbar 请求，优先级更低。
```

`lvl` 采用 3bit one-hot 编码：

```text
3'b100: 第一级页表，1G leaf 或进入第二级页表
3'b010: 第二级页表，2M leaf 或进入第三级页表
3'b001: 第三级页表，4K leaf
```

`pmpflg` 的随路信息也被合并到统一 PMP 单元：

```systemverilog
assign pmp_unit_l1pmpflg[3:0] = ptw_addr_fst ? pmp_mmu_flg[3:0] : pmp_unit_pmpflg[3:0];
assign twu_mbuf_pmpflg[7:0] = {pmp_mmu_flg[3:0],pmp_unit_l1pmpflg[3:0]};
```

`twu_mbuf_pmpflg` 的位段语义按 PDE cache 回填需求固定：`[3:0]` 是第一级页表的 PMP flag，`[7:4]` 是第二级页表的 PMP flag。`pmp_unit_l1pmpflg` 专门生成 `[3:0]` 的 L1 PMP flag：当 `ptw_addr_fst` 为 1，当前 PMP 检查正在访问第一级页表，所以刚返回的 `pmp_mmu_flg[3:0]` 就是 L1 PMP flag；当 `ptw_addr_fst` 为 0，当前访问已经是第二级或第三级页表，L1 PMP flag 必须继续使用随路保存的 `pmp_unit_pmpflg[3:0]`。`twu_mbuf_pmpflg[7:4]` 在第二级页表访问时由当前 `pmp_mmu_flg[3:0]` 提供，正好对应 L2 PMP flag；第一级回填 L1PDE 时 `[7:4]` 不作为 L2 flag 使用。

## 文件级修改清单

| 文件 | 修改类型 | 目的 |
| --- | --- | --- |
| `L1PDE_cache.sv` | 增加 L1PDE entry 的 l1pmpflg 输出赋值 | L1PDE cache 命中时把 entry 内保存的 L1 PMP flag 传出 |
| `PDE_cache.sv` | 增加 `PDE_xbar_l1pmpflg` 输出，增加 L1 hit flag 选择逻辑 | 将 L1PDE hit entry 的 PMP flag 送到 xbar/TWU |
| `one_to_four_xbar.sv` | 增加 `PDE_xbar_l1pmpflg` 输入和 `xbar_twu_l1pmpflg` 输出 | 透传 PDE cache 的 L1 PMP flag |
| `ptw.sv` | 增加 `PDE_xbar_l1pmpflg/xbar_twu_l1pmpflg` 顶层连线，并把 `twu_data_ready` 改为 1bit | 保证新字段能从 PDE cache 传到 TWU，并让顶层接口与统一 `chk_unit` 匹配 |
| `ptw_mbuf.sv` | `twu_data_ready` 从 3bit 改为 1bit | 适配统一 `chk_unit` 后只有一个 data ready |
| `mbuf_entry.sv` | `twu_data_ready` 从 3bit 改为 1bit，writeback 条件改为直接看 ready | mbuf 不再按 level 选择 fst/scd/thd chk ready |
| `twu.sv` | 主体重构 | 注释旧三级 PMP/CHK，实现统一 PMP/CHK、单源 fault、单源 mbuf、双源 refill |

## 修改理由总览

- `L1PDE_cache.sv`：新增 L1PDE entry 的 `l1pmpflg` 输出，是为了让 L1PDE cache 命中后仍能把已保存的第一级页表 PMP flag 带回 TWU。否则 L1PDE hit 后继续访问二级页表时，后续 L2PDE cache 回填无法恢复 L1 PMP flag。
- `PDE_cache.sv`：新增 `PDE_xbar_l1pmpflg` 和 L1 hit flag 选择逻辑，是为了把命中 entry 的 L1 PMP flag 随 PDE cache hit 请求送到 xbar/TWU，避免只传 PPN 而丢掉权限上下文。
- `one_to_four_xbar.sv`：新增 `PDE_xbar_l1pmpflg -> xbar_twu_l1pmpflg` 透传，是为了保持请求 payload 完整。xbar 只负责 ready/mask 和字段转发，不重新解释 pmpflg。
- `ptw.sv`：同步新增顶层 `PDE_xbar_l1pmpflg` 和 `xbar_twu_l1pmpflg` 中间信号，并分别接入 `PDE_cache`、`one_to_four_xbar` 和 `twu` 实例；同时把顶层 `twu_data_ready` 从 3bit 改成 1bit，避免子模块端口位宽不一致。
- `ptw_mbuf.sv`：`twu_data_ready` 改成 1bit，是因为 TWU 内部只剩一个 `chk_unit`。`mbuf_twu_pmpflg[3:0]` 和 `[7:4]` 的拆分逻辑固定为 L1/L2 PMP flag，是 PDE cache 回填 pmpflg 的依据。
- `mbuf_entry.sv`：writeback 条件从按 level ready mask 改为统一 `twu_data_ready`，是因为 mbuf 返回不再需要按 fst/scd/thd 三个 chk pipeline 分流，只需要判断统一 `chk_unit` 是否可接收。
- `twu.sv`：统一 PMP UNIT 的修改理由是去掉三级 PMP pipeline 和 PMP arbiter，让所有页表访问 PMP 检查都串到同一个单元里处理。统一 CHK UNIT 的修改理由是去掉三级 CHK pipeline、page fault 多路选择、CSR 多路仲裁和 refill 多路仲裁，使 mbuf 返回只有一个消费端。
- `twu.sv` 的 `twu_mask` 修改理由是让 `pmp_unit_wait` 或 `chk_unit` next-level walk 直接反压 PDE cache/xbar，保证 `chk_unit` 继续 walk 的优先级高于 PDE cache 新请求，并通过 ready 拉低阻止 L2TLB 继续推新请求。
- `twu.sv` 的 `pmp_unit_l1pmpflg` 修改理由是修正发给 mbuf 的 pmpflg 位段：`[3:0]` 必须稳定表示 L1 PMP flag，`[7:4]` 在第二级页表访问时表示 L2 PMP flag，匹配 `ptw_mbuf` 对 PDE cache 回填字段的拆分。

## 非 `twu` 文件的代码对比

### `L1PDE_cache.sv`

修改前：

```systemverilog
assign L1PDE_entry_vld = L1PDE_vld;
assign L1PDE_entry_ppn = L1PDE_ppn;
assign L1PDE_entry_hit = L1PDE_hit;
```

修改后：

```systemverilog
assign L1PDE_entry_vld = L1PDE_vld;
assign L1PDE_entry_ppn = L1PDE_ppn;
assign L1PDE_entry_hit = L1PDE_hit;
assign L1PDE_entry_l1pmpflg[3:0] = L1PDE_l1pmpflg[3:0];
```

说明：`L1PDE_l1pmpflg` 原本已经在 entry update 时由 `L1PDE_upd_l1pmpflg[3:0]` 写入，并参与 L1PDE hit 时的 PMP 权限判断。本次新增赋值的目的，是让 L1PDE cache 命中 entry 内保存的 L1 PMP flag 可以继续向上层 `PDE_cache` 输出，从而通过 xbar 传到 TWU。

### `PDE_cache.sv`

接口修改前：

```systemverilog
output logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
output logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
output logic [TYPE_WIDTH-1:0] PDE_xbar_type,
output logic [ID_WIDTH-1:0]   PDE_xbar_id,
output logic                  PDE_xbar_req,
```

接口修改后：

```systemverilog
output logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
output logic [3:0]            PDE_xbar_l1pmpflg,
output logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
output logic [TYPE_WIDTH-1:0] PDE_xbar_type,
output logic [ID_WIDTH-1:0]   PDE_xbar_id,
output logic                  PDE_xbar_req,
```

L1PDE entry 实例修改前：

```systemverilog
.L1PDE_entry_ppn                (L1PDE_entry_ppn[L1PDE_ent] ),
.L1PDE_entry_vld                (L1PDE_entry_vld[L1PDE_ent] ),
.L1PDE_entry_hit                (L1PDE_entry_hit[L1PDE_ent] )
```

修改后：

```systemverilog
.L1PDE_entry_ppn                (L1PDE_entry_ppn[L1PDE_ent] ),
.L1PDE_entry_vld                (L1PDE_entry_vld[L1PDE_ent] ),
.L1PDE_entry_hit                (L1PDE_entry_hit[L1PDE_ent] ),
.L1PDE_entry_l1pmpflg           (L1PDE_entry_l1pmpflg[L1PDE_ent] )
```

新增 L1 hit flag 选择逻辑：

```systemverilog
always_comb begin
    L1PDE_cache_hit_l1pmpflg[3:0] = {4{1'b0}};
        for(int i = 0; i < L1PDE_ENTRY_NUM; i = i + 1) begin
            if(L1PDE_entry_hit_idx[i])
                L1PDE_cache_hit_l1pmpflg[3:0] = L1PDE_entry_l1pmpflg[i][3:0];
        end
end
```

输出修改前：

```systemverilog
assign PDE_xbar_ppn[PPN_WIDTH-1:0] = PDE_cache_fin_ppn[PPN_WIDTH-1:0];
assign PDE_xbar_vpn[VPN_WIDTH-1:0] = ptw_vpn[VPN_WIDTH-1:0];
```

输出修改后：

```systemverilog
assign PDE_xbar_ppn[PPN_WIDTH-1:0] = PDE_cache_fin_ppn[PPN_WIDTH-1:0];
assign PDE_xbar_l1pmpflg[3:0] = L1PDE_cache_hit_l1pmpflg[3:0];
assign PDE_xbar_vpn[VPN_WIDTH-1:0] = ptw_vpn[VPN_WIDTH-1:0];
```

说明：L1PDE hit 时，`PDE_xbar_l1pmpflg` 携带命中 entry 的 L1 PMP flag。L2PDE hit 时，当前代码仍直接输出 `L1PDE_cache_hit_l1pmpflg`，没有 L1 hit 时该值为默认 0。该 flag 只作为后续 TWU walk 的随路信息，不改变 `PDE_cache_fin_ppn` 和 hit level 的优先级选择。

### `one_to_four_xbar.sv`

修改前：

```systemverilog
input  logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
...
output logic [PPN_WIDTH-1:0]  xbar_twu_ppn,
```

修改后：

```systemverilog
input  logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
input  logic [3:0]            PDE_xbar_l1pmpflg,
...
output logic [PPN_WIDTH-1:0]  xbar_twu_ppn,
output logic [3:0]            xbar_twu_l1pmpflg,
```

新增透传：

```systemverilog
assign xbar_twu_l1pmpflg[3:0] = PDE_xbar_l1pmpflg[3:0];
```

说明：xbar 的 ready/mask 行为没有变化。`PDE_xbar_l1pmpflg` 和 `PDE_xbar_ppn/vpn/type/id` 一起被透传到 TWU；当 `twu_mask` 拉高时，`xbar_pde_ready` 拉低，PDE cache 请求停在 PDE cache 中。

### `ptw.sv`

顶层中间信号修改前：

```systemverilog
logic [PPN_WIDTH-1:0]  PDE_xbar_ppn;
logic [PPN_WIDTH-1:0]  xbar_twu_ppn;
logic [PTE_LEVEL-1:0]  twu_data_ready;
```

修改后：

```systemverilog
logic [PPN_WIDTH-1:0]  PDE_xbar_ppn;
logic [3:0]            PDE_xbar_l1pmpflg;
logic [PPN_WIDTH-1:0]  xbar_twu_ppn;
logic [3:0]            xbar_twu_l1pmpflg;
logic                  twu_data_ready;
```

`PDE_cache` 实例新增输出连接：

```systemverilog
.PDE_xbar_ppn        (PDE_xbar_ppn),
.PDE_xbar_l1pmpflg   (PDE_xbar_l1pmpflg),
.PDE_xbar_vpn        (PDE_xbar_vpn),
```

`one_to_four_xbar` 实例新增输入和输出连接：

```systemverilog
.PDE_xbar_ppn        (PDE_xbar_ppn),
.PDE_xbar_l1pmpflg   (PDE_xbar_l1pmpflg),
...
.xbar_twu_ppn        (xbar_twu_ppn),
.xbar_twu_l1pmpflg   (xbar_twu_l1pmpflg),
```

`twu` 实例新增输入连接，并把 `twu_data_ready` 改成 scalar 连接：

```systemverilog
.xbar_twu_ppn        (xbar_twu_ppn),
.xbar_twu_l1pmpflg   (xbar_twu_l1pmpflg),
...
.twu_data_ready      (twu_data_ready),
```

`ptw_mbuf` 实例同样连接 scalar `twu_data_ready`：

```systemverilog
.twu_data_ready      (twu_data_ready),
```

说明：`ptw.sv` 是 `PDE_cache -> one_to_four_xbar -> twu -> ptw_mbuf` 的顶层汇合点。新增 `l1pmpflg` 字段后，如果只修改子模块而不在顶层接线，named port elaboration 会失败，或者字段被悬空。`twu_data_ready` 改成 1bit 后，顶层也必须改成 scalar，否则 `twu`、`ptw_mbuf`、`mbuf_entry` 的 ready 语义不一致。

### `ptw_mbuf.sv`

修改前：

```systemverilog
input  logic [PTE_LEVEL-1:0]        twu_data_ready,
```

修改后：

```systemverilog
input  logic                        twu_data_ready,
```

说明：统一 `chk_unit` 后，mbuf 返回不再区分 fst/scd/thd 三个 ready，所以接口从 `PTE_LEVEL` 位改为 1bit。

### `mbuf_entry.sv`

接口修改前：

```systemverilog
input  logic [PTE_LEVEL-1:0]      twu_data_ready,
```

接口修改后：

```systemverilog
input  logic                      twu_data_ready,
```

writeback 条件修改前：

```systemverilog
assign write_back_req = mbuf_vld
                      & (!mbuf_all_clr)
                      & (|(twu_data_ready[PTE_LEVEL-1:0] & mbuf_lvl[PTE_LEVEL-1:0]))
                      & ((mbuf_on & lsu_mmu_data_routed) | mbuf_get);
```

修改后：

```systemverilog
assign write_back_req = mbuf_vld
                      & (!mbuf_all_clr)
                      & twu_data_ready
                      & ((mbuf_on & lsu_mmu_data_routed) | mbuf_get);
```

说明：修改前 mbuf entry 只有在自身 `mbuf_lvl` 对应的 `twu_data_ready` bit 为 1 时才能返回。修改后所有 mbuf entry 只看统一 `chk_unit` ready。

## `twu.sv` 端口和声明修改

### xbar 到 TWU 新增 L1 PMP flag

修改前：

```systemverilog
input  logic [PTE_LEVEL-2:0]   xbar_twu_hit_level,
input  logic [PPN_WIDTH-1:0]   xbar_twu_ppn,
input  logic [VPN_WIDTH-1:0]   xbar_twu_vpn,
```

修改后：

```systemverilog
input  logic [PTE_LEVEL-2:0]   xbar_twu_hit_level,
input  logic [PPN_WIDTH-1:0]   xbar_twu_ppn,
input  logic [3:0]             xbar_twu_l1pmpflg,
input  logic [VPN_WIDTH-1:0]   xbar_twu_vpn,
```

用途：当 PDE cache 命中 L1PDE 后，`xbar_twu_l1pmpflg` 把 L1 PDE entry 内保存的 L1 PMP flag 带入 TWU。若该请求后续走到第二级 PTE 且仍非叶子，`pmp_unit_pmpflg` 会继续保存该 flag，用于后续 mbuf/PDE cache 回填。

### `twu_data_ready` 改为 1bit

修改前：

```systemverilog
output logic [PTE_LEVEL-1:0]   twu_data_ready,
```

修改后：

```systemverilog
output logic                   twu_data_ready,
```

修改前有三个 chk pipeline，所以 ready 是 3bit。修改后只有统一 `chk_unit`，ready 只需要 1bit。

### 新增统一 PMP UNIT 声明

```systemverilog
logic                  pmp_unit_vld;
logic                  pmp_unit_wait;
logic [VPN_WIDTH-1:0]  pmp_unit_vpn;
logic [TYPE_WIDTH-1:0] pmp_unit_type;
logic [ID_WIDTH-1:0]   pmp_unit_id;
logic [PPN_WIDTH-1:0]  pmp_unit_ppn;
logic [PTE_LEVEL-1:0]  pmp_unit_lvl;
logic [3:0]            pmp_unit_pmpflg;
logic [3:0]            pmp_unit_l1pmpflg;
logic                  pmp_unit_fst_sel;
logic                  pmp_fetch_type;
logic                  pmp_load_type;
logic                  pmp_store_type;
logic                  pmp_pref_type;
logic                  pmp_cp0_mach_mode;
logic                  pmp_unit_deny;
logic                  pmp_mbuf_req;
logic                  acc_err_pmp_unit_grant;
logic [PADDR_WIDTH-1:0] ptw_fst_addr;
logic [PADDR_WIDTH-1:0] ptw_scd_addr;
logic [PADDR_WIDTH-1:0] ptw_thd_addr;
logic                  ptw_addr_fst;
logic                  ptw_addr_scd;
logic                  ptw_addr_thd;
logic [PADDR_WIDTH-1:0] pmp_unit_pa;
```

这些信号替代旧的 `fst_pmp_*`、`scd_pmp_*`、`thd_pmp_*` 三套寄存器、PA 生成、PMP deny 和 mbuf request 信号。

### 新增统一 CHK UNIT 声明

```systemverilog
logic                  chk_unit_vld;
logic                  chk_unit_wait;
logic [VPN_WIDTH-1:0]  chk_unit_vpn;
logic [TYPE_WIDTH-1:0] chk_unit_type;
logic [ID_WIDTH-1:0]   chk_unit_id;
logic [PTE_LEVEL-1:0]  chk_unit_lvl;
logic [DATA_WIDTH-1:0] chk_unit_data;
logic [3:0]            chk_unit_pmpflg;
logic [8:0]            chk_unit_flg;
logic                  chk_unit_fetch_type;
logic                  chk_unit_load_type;
logic                  chk_unit_store_type;
logic                  chk_unit_cp0_user_mode;
logic                  chk_unit_cp0_supv_mode;
logic                  chk_unit_fst;
logic                  chk_unit_scd;
logic                  chk_unit_thd;
logic                  chk_unit_hit_1g;
logic                  chk_unit_hit_2m;
logic                  chk_unit_leaf_vld;
logic                  chk_unit_page_flt;
logic [PPN_WIDTH-1:0]  chk_unit_ppn;
logic [4:0]            chk_unit_refill_high_flg;
logic                  chk_unit_refill_req;
logic [RDATA_WIDTH-1:0] chk_unit_refill_data;
logic [PTE_LEVEL-1:0]  chk_unit_refill_pgs;
logic [TAG_WIDTH-1:0]  chk_unit_refill_tag;
logic [TYPE_WIDTH-1:0] chk_unit_refill_type;
logic [ID_WIDTH-1:0]   chk_unit_refill_id;
logic                  chk_unit_csr_req;
logic [VPN_WIDTH-1:0]  chk_unit_csr_vpn;
logic [TYPE_WIDTH-1:0] chk_unit_csr_type;
logic [ID_WIDTH-1:0]   chk_unit_csr_id;
logic [DATA_WIDTH-1:0] chk_unit_csr_data;
logic [PTE_LEVEL-1:0]  chk_unit_csr_pgs;
logic                  chk_unit_csr_grant;
logic                  pgflt_chk_unit_grant;
```

这些信号替代旧的 `fst_chk_*`、`scd_chk_*`、`thd_chk_*` 三套 PTE data 寄存、PTE flag decode、page fault、CSR、refill 和 wait 信号。

### 旧声明保留为注释

旧的三级 pipeline 声明没有删除，而是整体保留在块注释中：

```systemverilog
/*
 * Legacy fst/scd/thd pipeline declarations.  The related implementation has
 * been commented out below, so these declarations are also kept commented.
 *
logic [1:0] cp0_priv_mode        ;
logic       fst_chk_cp0_user_mode;
...
logic [3:0]             fst_chk_l1pmpflg;
logic [3:0]             scd_pmp_l1pmpflg;
*/
```

## `twu_mask` 反压逻辑修改

修改前：

```systemverilog
assign twu_mask = fst_pmp_wait
                | scd_pmp_wait
                | thd_pmp_wait
                | (fst_chk_vld & (!fst_chk_page_flt) & (!fst_chk_leaf_vld) & (!scd_pmp_wait))
                | (scd_chk_vld & (!scd_chk_page_flt) & (!scd_chk_leaf_vld) & (!thd_pmp_wait));
```

修改后：

```systemverilog
assign twu_mask = pmp_unit_wait
                | chk_unit_vld & (!chk_unit_leaf_vld) & (!chk_unit_page_flt);
```

行为变化：

- 修改前要综合三路 PMP wait，以及 fst/scd chk 准备进入下一层级 walk 的状态。
- 修改后只要统一 `pmp_unit` 正在 wait，或者 `chk_unit` 正在持有非叶子且无 page fault 的 PTE，就拉高 `twu_mask`。
- `one_to_four_xbar` 根据 `twu_mask` 拉低 `xbar_pde_ready`，使 PDE cache 请求停在 PDE cache 侧。
- 因为 PDE cache ready 拉低，PDE cache 也不会继续接受 L2TLB 新请求。
- `chk_unit` 的继续 walk 请求优先级高于 PDE cache/xbar 请求。
- 该表达式按 SystemVerilog 运算符优先级等价于 `pmp_unit_wait | (chk_unit_vld & !chk_unit_leaf_vld & !chk_unit_page_flt)`。
- `pmp_unit_wait` 覆盖 PMP allow 但 mbuf 未 grant，以及 PMP deny 但 access fault 未 grant 两类情况。
- `chk_unit_vld & !chk_unit_leaf_vld & !chk_unit_page_flt` 覆盖当前 PTE 确认需要继续访问下一层页表的情况。此时拉高 mask 可以阻止 PDE cache/xbar 把低优先级请求送进 `pmp_unit`，保证 `chk_unit` 的 next-level walk 优先。

## 旧三级 PMP/CHK 逻辑保留为注释

从 `FST PMP` 开始，到 `THD CHK` 结束，旧实现整体被块注释保留：

```systemverilog
/*
//==============================================================================
//                  FST PMP
//==============================================================================
...
//==============================================================================
//                  FST CHK
//==============================================================================
...
//==============================================================================
//                  SCD PMP
//==============================================================================
...
//==============================================================================
//                  SCD CHK
//==============================================================================
...
//==============================================================================
//                  THD PMP
//==============================================================================
...
//==============================================================================
//                  THD CHK
//==============================================================================
...
*/
```

旧结构中的职责对应关系如下：

- `fst_pmp`：第一级页表 PMP 检查，PA 来自 `satp.ppn + vpn[26:18]`。
- `fst_chk`：第一级 PTE 检查，1G leaf 可 refill 或 CSR/sysmap，非叶子进入 `scd_pmp`。
- `scd_pmp`：第二级页表 PMP 检查，请求可来自 PDE cache L1 hit 或 `fst_chk` 非叶子。
- `scd_chk`：第二级 PTE 检查，2M leaf 可 refill 或 CSR/sysmap，非叶子进入 `thd_pmp`。
- `thd_pmp`：第三级页表 PMP 检查，请求可来自 PDE cache L2 hit 或 `scd_chk` 非叶子。
- `thd_chk`：第三级 PTE 检查，只能产生最终 4K refill 或 page fault。

## 新统一 PMP UNIT

### valid 仲裁

```systemverilog
always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        pmp_unit_vld <= 1'b0;
    else if(abort)
        pmp_unit_vld <= 1'b0;
    else if(pmp_unit_wait)
        pmp_unit_vld <= pmp_unit_vld;
    else if(chk_unit_vld & (!chk_unit_leaf_vld) & (!chk_unit_page_flt) & (!pmp_unit_wait))
        pmp_unit_vld <= 1'b1;
    else if(xbar_twu_req & (!pmp_unit_wait))
        pmp_unit_vld <= 1'b1;
    else
        pmp_unit_vld <= 1'b0;
end
```

说明：`pmp_unit_wait` 为 1 时保持当前请求。非 wait 时先接收 `chk_unit` 的非叶子、无异常请求；只有没有 `chk_unit` 请求时才接收 `xbar_twu_req`。

### 请求寄存器载入

```systemverilog
assign pmp_unit_fst_sel = xbar_twu_hit_level == 2'b00;

always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)begin
        pmp_unit_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
        pmp_unit_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
        pmp_unit_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
        pmp_unit_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
        pmp_unit_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
        pmp_unit_pmpflg[3:0] <= 4'b0;
    end else if(chk_unit_vld & (!chk_unit_leaf_vld) & (!chk_unit_page_flt) & (!pmp_unit_wait))begin
        pmp_unit_vpn[VPN_WIDTH-1:0] <= chk_unit_vpn[VPN_WIDTH-1:0];
        pmp_unit_type[TYPE_WIDTH-1:0] <= chk_unit_type[TYPE_WIDTH-1:0];
        pmp_unit_id[ID_WIDTH-1:0] <= chk_unit_id[ID_WIDTH-1:0];
        pmp_unit_ppn[PPN_WIDTH-1:0] <= chk_unit_ppn[PPN_WIDTH-1:0];
        pmp_unit_lvl[PTE_LEVEL-1:0] <= {chk_unit_lvl[0],chk_unit_lvl[2:1]};
        pmp_unit_pmpflg[3:0] <= chk_unit_pmpflg[3:0];
    end else if(xbar_twu_req & (!pmp_unit_wait))begin
        pmp_unit_vpn[VPN_WIDTH-1:0] <= xbar_twu_vpn[VPN_WIDTH-1:0];
        pmp_unit_type[TYPE_WIDTH-1:0] <= xbar_twu_type[TYPE_WIDTH-1:0];
        pmp_unit_id[ID_WIDTH-1:0] <= xbar_twu_id[ID_WIDTH-1:0];
        pmp_unit_ppn[PPN_WIDTH-1:0] <= xbar_twu_ppn[PPN_WIDTH-1:0];
        pmp_unit_lvl[PTE_LEVEL-1:0] <= {pmp_unit_fst_sel,xbar_twu_hit_level[1:0]};
        pmp_unit_pmpflg[3:0] <= xbar_twu_l1pmpflg[3:0];
    end
end
```

level 转换说明：

- 从 `chk_unit` 进入时，`{chk_unit_lvl[0], chk_unit_lvl[2:1]}` 表示向下一级转换：`3'b100 -> 3'b010`，`3'b010 -> 3'b001`。
- 从 xbar/PDE cache 进入时，`{pmp_unit_fst_sel,xbar_twu_hit_level[1:0]}` 生成起始 walk level：无 PDE hit 为 `3'b100`，L1PDE hit 为 `3'b010`，L2PDE hit 为 `3'b001`。
- `pmp_unit_pmpflg` 保存 PDE cache 或上一级 `chk_unit` 带来的 L1 PMP flag，用于生成 `twu_mbuf_pmpflg[3:0]`。真正送到 mbuf 低 4bit 的值由 `pmp_unit_l1pmpflg` 修正：一级页表访问使用当前 `pmp_mmu_flg`，二级/三级页表访问使用随路保存的 `pmp_unit_pmpflg`。`twu_mbuf_pmpflg[7:4]` 用于承载第二级页表 PMP flag，在第二级页表访问时由当前 `pmp_mmu_flg` 提供。

### PMP 权限判断

```systemverilog
assign pmp_fetch_type = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b011;
assign pmp_load_type  = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b010;
assign pmp_store_type = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b110;
assign pmp_pref_type  = pmp_unit_type[TYPE_WIDTH-1:0] == 3'b100;

assign pmp_cp0_mach_mode = pmp_fetch_type ? cp0_yy_priv_mode[1:0] == 2'b11
                                      : cp0_priv_mode[1:0] == 2'b11;

assign pmp_unit_deny = (pmp_fetch_type && !pmp_mmu_flg[2]
                    || pmp_load_type  && !pmp_mmu_flg[0]
                    || pmp_store_type && !pmp_mmu_flg[1]
                    || pmp_pref_type  && !pmp_mmu_flg[0])
                       && !(pmp_cp0_mach_mode && !pmp_mmu_flg[3]);
```

该判断复用了旧三级 PMP 的权限语义，只把信号统一到 `pmp_unit`。

### PA 生成和 MBUF 请求

修改前，PA 分散在三级 PMP：

```systemverilog
assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};
assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};
assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8:0],3'b0};
```

修改后，统一 `pmp_unit` 根据 one-hot `lvl` 选择：

```systemverilog
assign ptw_fst_addr[PADDR_WIDTH-1:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],
                                 pmp_unit_vpn[VPN_WIDTH-1:VPN_PERLEL*2], 3'b0};
assign ptw_scd_addr[PADDR_WIDTH-1:0] = {pmp_unit_ppn[PPN_WIDTH-1:0],
                                 pmp_unit_vpn[VPN_PERLEL*2-1:VPN_PERLEL*1], 3'b0};
assign ptw_thd_addr[PADDR_WIDTH-1:0] = {pmp_unit_ppn[PPN_WIDTH-1:0],
                                 pmp_unit_vpn[VPN_PERLEL*1-1:VPN_PERLEL*0], 3'b0};

assign ptw_addr_fst = pmp_unit_lvl[2];
assign ptw_addr_scd = pmp_unit_lvl[1];
assign ptw_addr_thd = pmp_unit_lvl[0];
assign pmp_unit_pa[PADDR_WIDTH-1:0] =
                {PADDR_WIDTH{ptw_addr_fst}} & ptw_fst_addr[PADDR_WIDTH-1:0]
              | {PADDR_WIDTH{ptw_addr_scd}} & ptw_scd_addr[PADDR_WIDTH-1:0]
              | {PADDR_WIDTH{ptw_addr_thd}} & ptw_thd_addr[PADDR_WIDTH-1:0];

assign pmp_mbuf_req = pmp_unit_vld & (~pmp_unit_deny);
assign twu_mbuf_req = pmp_mbuf_req;
assign twu_mbuf_paddr[PADDR_WIDTH-1:0] = pmp_unit_pa[PADDR_WIDTH-1:0];
assign twu_mbuf_vpn[VPN_WIDTH-1:0] = pmp_unit_vpn[VPN_WIDTH-1:0];
assign twu_mbuf_type[TYPE_WIDTH-1:0] = pmp_unit_type[TYPE_WIDTH-1:0];
assign twu_mbuf_id[ID_WIDTH-1:0] = pmp_unit_id[ID_WIDTH-1:0];
assign twu_mbuf_lvl[PTE_LEVEL-1:0] = pmp_unit_lvl[PTE_LEVEL-1:0];
assign pmp_unit_l1pmpflg[3:0] = ptw_addr_fst ? pmp_mmu_flg[3:0] : pmp_unit_pmpflg[3:0];
assign twu_mbuf_pmpflg[7:0] = {pmp_mmu_flg[3:0],pmp_unit_l1pmpflg[3:0]};
```

说明：第一级地址使用 `regs_ptw_satp_ppn`；第二级和第三级地址使用上一级 PTE 的 PPN。MBUF 请求随路携带 `vpn/type/id/lvl/pmpflg/pa`。

#### 最新 pmpflg 修正说明

`ptw_mbuf.sv` 对 `mbuf_twu_pmpflg` 的使用决定了 TWU 发给 mbuf 的 pmpflg 位段定义：

```systemverilog
pde_updata_l1pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
pde_updata_l2pmpflg[3:0] <= mbuf_twu_pmpflg[7:4];
```

因此文档中统一采用如下定义：

```text
twu_mbuf_pmpflg[3:0] = 第一级页表 PMP flag
twu_mbuf_pmpflg[7:4] = 第二级页表 PMP flag
```

新增的 `pmp_unit_l1pmpflg` 是为了保证 `[3:0]` 永远能给出正确的第一级页表 PMP flag。原先直接使用 `{pmp_mmu_flg, pmp_unit_pmpflg}` 时，第一级页表访问的低 4bit 会来自寄存器 `pmp_unit_pmpflg`，但第一级 walk 的 L1 PMP flag 实际是在当前这次 PMP 检查后才由 `pmp_mmu_flg` 返回。因此第一级页表访问必须特殊处理：

```systemverilog
assign pmp_unit_l1pmpflg[3:0] = ptw_addr_fst ? pmp_mmu_flg[3:0] : pmp_unit_pmpflg[3:0];
assign twu_mbuf_pmpflg[7:0] = {pmp_mmu_flg[3:0],pmp_unit_l1pmpflg[3:0]};
```

具体含义和修改理由：

- `ptw_addr_fst == 1`：当前访问第一级页表，`pmp_mmu_flg[3:0]` 是刚得到的 L1 PMP flag，所以 `twu_mbuf_pmpflg[3:0]` 必须填当前 `pmp_mmu_flg`。这样 L1PDE cache 回填时能拿到正确的 L1 flag。
- `ptw_addr_scd == 1`：当前访问第二级页表，`pmp_mmu_flg[3:0]` 是 L2 PMP flag，放入 `twu_mbuf_pmpflg[7:4]`；`pmp_unit_l1pmpflg[3:0]` 来自随路保存的 L1 flag，放入 `twu_mbuf_pmpflg[3:0]`。这样 L2PDE cache 回填时同时拥有 L1 和 L2 两级 PMP flag。
- `ptw_addr_thd == 1`：当前访问第三级页表。mbuf 的 PDE cache 回填逻辑会排除第三级页表项，所以 `[7:4]` 不作为 L2PDE 回填 flag 使用；`[3:0]` 仍继续携带 L1 flag 给后续逻辑使用。
- 修改理由是 PDE cache 的 L1 entry 只需要 L1 PMP flag，而 L2 entry 需要同时保存 L1 PMP flag 和 L2 PMP flag。位段固定后，`ptw_mbuf` 可以无条件按 `[3:0]` 和 `[7:4]` 拆分并回填，不需要再根据 level 重新解释 pmpflg。

这个修正保证了第一级页表访问不会丢失当前刚返回的 L1 PMP flag，也保证第二级页表非叶子回填 L2PDE cache 时，`[7:4]` 是第二级页表 PMP flag、`[3:0]` 是第一级页表 PMP flag。

### PMP 输出和 wait

修改前，`mmu_pmp_pa/mmu_pmp_fecth` 由 `pmp_grant[2:0]` 选择 fst/scd/thd。修改后统一直接驱动：

```systemverilog
assign mmu_pmp_pa[PPN_WIDTH-1:0] = pmp_unit_pa[PPN_WIDTH+11:12];
assign mmu_pmp_fecth = pmp_fetch_type;

assign acc_err_pmp_unit_grant = pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant);
assign pmp_unit_wait =  pmp_mbuf_req & (!mbuf_grant)
                    | pmp_unit_vld & pmp_unit_deny & (!acc_err_pmp_unit_grant);
```

PMP 仲裁器因此不再需要。

## 新统一 CHK UNIT

### valid 和寄存器

修改前，mbuf 返回按 `mbuf_twu_lvl[2:0]` 分别进入 `fst_chk/scd_chk/thd_chk`。修改后，所有 mbuf 返回统一进入 `chk_unit`：

```systemverilog
always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        chk_unit_vld <= 1'b0;
    else if(abort)
        chk_unit_vld <= 1'b0;
    else if(chk_unit_wait)
        chk_unit_vld <= chk_unit_vld;
    else if(mbuf_twu_data_vld & (!chk_unit_wait))
        chk_unit_vld <= 1'b1;
    else
        chk_unit_vld <= 1'b0;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
    if(!cpurst_b)begin
        chk_unit_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
        chk_unit_type[TYPE_WIDTH-1:0] <= {TYPE_WIDTH{1'b0}};
        chk_unit_id[ID_WIDTH-1:0] <= {ID_WIDTH{1'b0}};
        chk_unit_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
        chk_unit_data[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
        chk_unit_pmpflg[3:0] <= 4'b0;
    end else if(mbuf_twu_data_vld & (!chk_unit_wait))begin
        chk_unit_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
        chk_unit_type[TYPE_WIDTH-1:0] <= mbuf_twu_type[TYPE_WIDTH-1:0];
        chk_unit_id[ID_WIDTH-1:0] <= mbuf_twu_id[ID_WIDTH-1:0];
        chk_unit_lvl[PTE_LEVEL-1:0] <= mbuf_twu_lvl[PTE_LEVEL-1:0];
        chk_unit_data[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
        chk_unit_pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
    end
end
```

`chk_unit` 寄存器包含需求中的 `vpn/type/id/lvl/data`，并额外保存 `pmpflg`。当前 `chk_unit_pmpflg` 取 `mbuf_twu_pmpflg[3:0]`，即继续传递低 4bit 的 L1 PMP flag。

### level、leaf 和 page fault

```systemverilog
assign chk_unit_flg[8:0] = {chk_unit_data[9:6], chk_unit_data[4:0]};
assign chk_unit_fetch_type = chk_unit_type[TYPE_WIDTH-1:0] == 3'b011;
assign chk_unit_load_type  = chk_unit_type[TYPE_WIDTH-1:0] == 3'b010;
assign chk_unit_store_type = chk_unit_type[TYPE_WIDTH-1:0] == 3'b110;

assign chk_unit_fst = chk_unit_lvl[PTE_LEVEL-1:0] == 3'b100;
assign chk_unit_scd = chk_unit_lvl[PTE_LEVEL-1:0] == 3'b010;
assign chk_unit_thd = chk_unit_lvl[PTE_LEVEL-1:0] == 3'b001;

assign chk_unit_hit_1g = chk_unit_fst && chk_unit_flg[0] && (chk_unit_flg[1] || chk_unit_flg[3]);
assign chk_unit_hit_2m = chk_unit_scd && chk_unit_flg[0] && (chk_unit_flg[1] || chk_unit_flg[3]);
assign chk_unit_leaf_vld = chk_unit_hit_1g | chk_unit_hit_2m | chk_unit_thd;
```

统一 page fault 判断：

```systemverilog
assign chk_unit_page_flt = ((!chk_unit_flg[0]
                   ||  !(chk_unit_flg[1] || cp0_mmu_mxr && chk_unit_flg[3])
                        && chk_unit_flg[2]
                   ||  (!chk_unit_flg[1] && chk_unit_load_type
                       && !(cp0_mmu_mxr && chk_unit_flg[3])
                   || !chk_unit_flg[2] && chk_unit_store_type
                   || !chk_unit_flg[3] && chk_unit_fetch_type
                   ||  chk_unit_flg[4] && chk_unit_cp0_supv_mode && !cp0_mmu_sum
                   || !chk_unit_flg[4] && chk_unit_cp0_user_mode
                   || !chk_unit_flg[5]
                   || !chk_unit_flg[6] && chk_unit_store_type
//                   ||  chk_unit_flg[13] && chk_unit_fetch_type
                   ||  chk_unit_hit_1g && chk_unit_data[27:10] != 18'b0
                   ||  chk_unit_hit_2m && chk_unit_data[18:10] != 9'b0
                     ) && chk_unit_leaf_vld)
                   || !chk_unit_flg[1] && !chk_unit_flg[3]
                       && chk_unit_thd);
```

保留的异常检查包括 invalid、write-only、R/W/X 权限、SUM、U/S、A/D bit、1G/2M 对齐，以及第三级无 R/X。`fetch so` 相关判断仍保留注释占位。

### refill、sysmap x3 和 CSR 请求

```systemverilog
assign chk_unit_ppn[PPN_WIDTH-1:0] = chk_unit_data[37:10];
assign mmu_sysmap_pax3[PPN_WIDTH-1:0] = chk_unit_ppn[PPN_WIDTH-1:0];
assign chk_unit_refill_high_flg[4:0] = cp0_mmu_maee ? chk_unit_data[63:59] : sysmap_mmu_flgx3[4:0];

assign chk_unit_refill_req = chk_unit_vld
                           & (((chk_unit_hit_1g | chk_unit_hit_2m) & cp0_mmu_maee) | chk_unit_thd)
                           & (!chk_unit_page_flt);
assign chk_unit_refill_data[RDATA_WIDTH-1:0] = {chk_unit_data[37:10],chk_unit_refill_high_flg[4:0],chk_unit_data[9:6],chk_unit_data[4:0]};
assign chk_unit_refill_pgs[PTE_LEVEL-1:0] = chk_unit_lvl[PTE_LEVEL-1:0];
assign chk_unit_refill_tag[TAG_WIDTH-1:0] = {1'b1,chk_unit_vpn[VPN_WIDTH-1:0],regs_ptw_cur_asid[ASID_WIDTH-1:0],chk_unit_refill_pgs[PTE_LEVEL-1:0],chk_unit_data[5]};
assign chk_unit_refill_type[TYPE_WIDTH-1:0] = chk_unit_type[TYPE_WIDTH-1:0];
assign chk_unit_refill_id[ID_WIDTH-1:0] = chk_unit_id[ID_WIDTH-1:0];

assign chk_unit_csr_req = chk_unit_vld & (chk_unit_hit_1g | chk_unit_hit_2m) & (!cp0_mmu_maee) & (!chk_unit_page_flt);
assign chk_unit_csr_vpn[VPN_WIDTH-1:0] = chk_unit_vpn[VPN_WIDTH-1:0];
assign chk_unit_csr_type[TYPE_WIDTH-1:0] = chk_unit_type[TYPE_WIDTH-1:0];
assign chk_unit_csr_id[ID_WIDTH-1:0] = chk_unit_id[ID_WIDTH-1:0];
assign chk_unit_csr_data[DATA_WIDTH-1:0] = chk_unit_data[DATA_WIDTH-1:0];
assign chk_unit_csr_pgs[PTE_LEVEL-1:0] = chk_unit_lvl[PTE_LEVEL-1:0];
```

行为说明：

- 1G/2M leaf 且 `cp0_mmu_maee=1` 时，直接由 `chk_unit` 发 refill。
- 1G/2M leaf 且 `cp0_mmu_maee=0` 时，进入 CSR/sysmap 跨页检查状态机。
- 第三级 PTE refill 直接由 `chk_unit` 发出。
- 第三级在 `maee=0` 时，不再像旧逻辑那样先打一拍再替换 flag，而是当前组合生成 `mmu_sysmap_pax3`，并用 `sysmap_mmu_flgx3` 生成 refill high flag。

### wait 和 data ready

```systemverilog
assign chk_unit_wait =    chk_unit_vld & pmp_unit_wait & (!chk_unit_leaf_vld) & (!chk_unit_page_flt)
                      |  chk_unit_vld & chk_unit_refill_req & (!refill_chk_unit_grant)
                      |  chk_unit_vld & chk_unit_page_flt & (!pgflt_chk_unit_grant)
                      |  chk_unit_vld & chk_unit_csr_req & (!chk_unit_csr_grant);
assign pgflt_chk_unit_grant = chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant);

assign twu_data_ready = !(chk_unit_vld & chk_unit_wait);
```

`chk_unit` 非叶子且无 page fault 时，如果 `pmp_unit_wait`，`chk_unit` 保持。leaf refill、page fault、CSR request 没有被对应后级接收时也保持。`twu_data_ready` 不再按 level 输出，只表示统一 `chk_unit` 是否可接收新 mbuf data。

## fault 输出修改

### Page fault 来源从三路变成一路

修改前：

```systemverilog
else if(thd_chk_vld & thd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
    twu_pgflt_vld <= 1'b1;
else if(scd_chk_vld & scd_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
    twu_pgflt_vld <= 1'b1;
else if(fst_chk_vld & fst_chk_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
    twu_pgflt_vld <= 1'b1;
```

修改后：

```systemverilog
else if(chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))
    twu_pgflt_vld <= 1'b1;
```

type/id 记录也从三路选择变为 `chk_unit` 单路：

```systemverilog
end else if(chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant))begin
    twu_pgflt_type[TYPE_WIDTH-1:0] <= chk_unit_type[TYPE_WIDTH-1:0];
    twu_pgflt_id[ID_WIDTH-1:0] <= chk_unit_id[ID_WIDTH-1:0];
end
```

旧 grant：

```systemverilog
assign pgflt_thd_chk_grant = ...;
assign pgflt_scd_chk_grant = ...;
assign pgflt_fst_chk_grant = ...;
```

新 grant：

```systemverilog
assign pgflt_chk_unit_grant = chk_unit_vld & chk_unit_page_flt & (!twu_pgflt_vld | pgflt_twu_grant);
```

### Access fault 来源从三路变成一路

修改前：

```systemverilog
else if(thd_pmp_vld & thd_pmp_deny & thd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
    twu_acc_err_vld <= 1'b1;
else if(scd_pmp_vld & scd_pmp_deny & scd_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
    twu_acc_err_vld <= 1'b1;
else if(fst_pmp_vld & fst_pmp_deny & fst_pmp_grant & (!twu_acc_err_vld | acc_err_twu_grant))
    twu_acc_err_vld <= 1'b1;
```

修改后：

```systemverilog
else if(pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant))
    twu_acc_err_vld <= 1'b1;
```

type/id 记录也从三路选择变为 `pmp_unit` 单路：

```systemverilog
end else if(pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant))begin
    twu_acc_err_type[TYPE_WIDTH-1:0] <= pmp_unit_type[TYPE_WIDTH-1:0];
    twu_acc_err_id[ID_WIDTH-1:0] <= pmp_unit_id[ID_WIDTH-1:0];
end
```

旧 grant：

```systemverilog
assign acc_err_thd_pmp_grant = ...;
assign acc_err_scd_pmp_grant = ...;
assign acc_err_fst_pmp_grant = ...;
```

新 grant：

```systemverilog
assign acc_err_pmp_unit_grant = pmp_unit_vld & pmp_unit_deny & (!twu_acc_err_vld | acc_err_twu_grant);
```

## PMP Arbiter 删除

修改前需要三路 PMP 仲裁：

```systemverilog
assign fst_pmp_itlb_sel = fst_pmp_vld & fst_pmp_fetch_type;
assign scd_pmp_itlb_sel = scd_pmp_vld & scd_pmp_fetch_type;
assign thd_pmp_itlb_sel = thd_pmp_vld & thd_pmp_fetch_type;

assign pmp_itlb_sel = fst_pmp_itlb_sel | scd_pmp_itlb_sel | thd_pmp_itlb_sel;

always_comb begin
    case({pmp_itlb_sel,fst_pmp_sel,scd_pmp_sel,thd_pmp_sel})
        4'b1000 : pmp_grant[2:0] = {fst_pmp_itlb_sel,scd_pmp_itlb_sel,thd_pmp_itlb_sel};
        4'b0100 : pmp_grant[2:0] = 3'b100;
        4'b0010 : pmp_grant[2:0] = 3'b010;
        4'b0001 : pmp_grant[2:0] = 3'b001;
        default : pmp_grant[2:0] = 3'b000;
    endcase
end
```

修改后，该段整体进入块注释，PMP 输出改由 `pmp_unit` 直接驱动。因为所有 PMP 请求都先进入统一 `pmp_unit`，不再存在三路同时驱动 PMP 的需求。

## CSR Arbiter 和 CSR FSM 修改

### CSR Arbiter 删除

修改前 CSR 请求来自 `fst_chk_csr_req/scd_chk_csr_req` 两路，需要 arbiter：

```systemverilog
assign csr_req = |csr_grant[1:0];

assign fst_csr_itlb_sel = fst_chk_csr_req & fst_chk_fetch_type;
assign scd_csr_itlb_sel = scd_chk_csr_req & scd_chk_fetch_type;
assign csr_itlb_sel = fst_csr_itlb_sel | scd_csr_itlb_sel;

always_comb begin
    case({csr_itlb_sel,fst_csr_sel,scd_csr_sel})
        3'b100  : csr_grant[1:0] = {fst_csr_itlb_sel,scd_csr_itlb_sel};
        3'b010  : csr_grant[1:0] = 2'b10;
        3'b001  : csr_grant[1:0] = 2'b01;
        default : csr_grant[1:0] = 2'b00;
    endcase
end
```

修改后，该段整体保留在注释中，CSR 输入直接来自 `chk_unit`：

```systemverilog
assign csr_vpn[VPN_WIDTH-1:0] = chk_unit_csr_vpn[VPN_WIDTH-1:0];
assign csr_type[TYPE_WIDTH-1:0] = chk_unit_csr_type[TYPE_WIDTH-1:0];
assign csr_id[ID_WIDTH-1:0] = chk_unit_csr_id[ID_WIDTH-1:0];
assign csr_data[DATA_WIDTH-1:0] = chk_unit_csr_data[DATA_WIDTH-1:0];
assign csr_fst = chk_unit_csr_pgs[PTE_LEVEL-1:0] == 3'b100;
assign csr_scd = chk_unit_csr_pgs[PTE_LEVEL-1:0] == 3'b010;
```

### CSR FSM 状态和进入条件

状态定义：

```systemverilog
parameter TWU_IDLE        = 3'b000,
          TWU_1G_CRS      = 3'b001,
          TWU_2M_CRS      = 3'b010,
          CSR_DATA_VLD    = 3'b011;
```

进入条件修改前：

```systemverilog
if(csr_req & csr_grant[1])
    ptw_nxt_st[2:0] = TWU_1G_CRS;
else if(csr_req & csr_grant[0])
    ptw_nxt_st[2:0] = TWU_2M_CRS;
```

修改后：

```systemverilog
if(chk_unit_csr_req & csr_fst)
    ptw_nxt_st[2:0] = TWU_1G_CRS;
else if(chk_unit_csr_req & csr_scd)
    ptw_nxt_st[2:0] = TWU_2M_CRS;
```

新增 grant：

```systemverilog
assign chk_unit_csr_grant = chk_unit_csr_req & csr_idle;
```

CSR 请求信息寄存条件从 `csr_req & csr_idle` 改为 `chk_unit_csr_req & csr_idle`：

```systemverilog
end else if(chk_unit_csr_req & csr_idle)begin
    csr_vpn_flop[VPN_WIDTH-1:0] <= csr_vpn[VPN_WIDTH-1:0];
    csr_type_flop[TYPE_WIDTH-1:0] <= csr_type[TYPE_WIDTH-1:0];
    csr_id_flop[ID_WIDTH-1:0] <= csr_id[ID_WIDTH-1:0];
end
```

sysmap 地址生成从 old `csr_grant[1:0]` 改为 `chk_unit_csr_grant & csr_fst/csr_scd`：

```systemverilog
end else if(chk_unit_csr_grant & csr_fst)begin
    twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
    twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH], 18'h3ffff, 12'b0};
end else if(chk_unit_csr_grant & csr_scd)begin
    twu_sysmap_adderx1[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:10], 12'b0};
    twu_sysmap_adderx2[PADDR_WIDTH-1:0] <= {csr_data[PPN_WIDTH+9:PPN_WIDTH-9], 9'h1ff, 12'b0};
end
```

CSR refill page size 从 old grant 组合改为直接保存 `chk_unit_csr_pgs`：

```systemverilog
else if(chk_unit_csr_req & csr_idle)
    csr_refill_pgs[PGS_WIDTH-1:0] <= chk_unit_csr_pgs[PTE_LEVEL-1:0];
```

跨页判断：

```systemverilog
assign twu_csr_cross = twu_crs_chk & (sysmap_mmu_hitx1[7:0] != sysmap_mmu_hitx2[7:0]);
assign sysmap_mmu_flg[4:0] = sysmap_mmu_flgx2[4:0];
```

## write MBUF Arbiter 删除

修改前，`twu_mbuf_*` 由 `fst_pmp_mbuf_req/scd_pmp_mbuf_req/thd_pmp_mbuf_req` 三路选择：

```systemverilog
assign twu_mbuf_lvl[PTE_LEVEL-1:0] = {fst_pmp_mbuf_req,scd_pmp_mbuf_req,thd_pmp_mbuf_req};
assign twu_mbuf_req = |twu_mbuf_lvl[PTE_LEVEL-1:0];

always_comb begin
    case(twu_mbuf_lvl[PTE_LEVEL-1:0])
        3'b001: begin
            twu_mbuf_paddr[PADDR_WIDTH-1:0] = thd_pmp_pa[PADDR_WIDTH-1:0];
            twu_mbuf_vpn[VPN_WIDTH-1:0] = thd_pmp_vpn[VPN_WIDTH-1:0];
            twu_mbuf_type[TYPE_WIDTH-1:0] = thd_pmp_type[TYPE_WIDTH-1:0];
            twu_mbuf_id[ID_WIDTH-1:0] = thd_pmp_id[ID_WIDTH-1:0];
            twu_mbuf_pmpflg[7:0] = 8'b0;
        end
        3'b010: begin
            twu_mbuf_paddr[PADDR_WIDTH-1:0] = scd_pmp_pa[PADDR_WIDTH-1:0];
            twu_mbuf_vpn[VPN_WIDTH-1:0] = scd_pmp_vpn[VPN_WIDTH-1:0];
            twu_mbuf_type[TYPE_WIDTH-1:0] = scd_pmp_type[TYPE_WIDTH-1:0];
            twu_mbuf_id[ID_WIDTH-1:0] = scd_pmp_id[ID_WIDTH-1:0];
            twu_mbuf_pmpflg[7:0] = {pmp_mmu_flg[3:0],scd_pmp_l1pmpflg[3:0]};
        end
        3'b100: begin
            twu_mbuf_paddr[PADDR_WIDTH-1:0] = fst_pmp_pa[PADDR_WIDTH-1:0];
            twu_mbuf_vpn[VPN_WIDTH-1:0] = fst_pmp_vpn[VPN_WIDTH-1:0];
            twu_mbuf_type[TYPE_WIDTH-1:0] = fst_pmp_type[TYPE_WIDTH-1:0];
            twu_mbuf_id[ID_WIDTH-1:0] = fst_pmp_id[ID_WIDTH-1:0];
            twu_mbuf_pmpflg[7:0] = {4'b0,pmp_mmu_flg[3:0]};
        end
    endcase
end
```

修改后，该段整体保留在注释中，`twu_mbuf_*` 在 PMP UNIT 内由 `pmp_unit` 直接赋值。

## refill arbiter 修改

修改前，refill 来源是 4 路：`fst_chk`、`scd_chk`、`thd_chk`、`csr_refill`。

```systemverilog
assign fst_chk_itlb_sel = fst_chk_refill_req & fst_chk_fetch_type;
assign scd_chk_itlb_sel = scd_chk_refill_req & scd_chk_fetch_type;
assign thd_chk_itlb_sel = thd_chk_refill_req & thd_chk_fetch_type;
assign csr_ref_itlb_sel = csr_refill_req & csr_fetch_type;

assign refill_itlb_sel = fst_chk_itlb_sel | scd_chk_itlb_sel | thd_chk_itlb_sel | csr_ref_itlb_sel;
```

修改后，refill 来源变成 2 路：`chk_unit_refill` 和 `csr_refill`。

```systemverilog
assign chk_unit_itlb_sel = chk_unit_refill_req & chk_unit_fetch_type;
assign csr_ref_itlb_sel = csr_refill_req & csr_fetch_type;

assign refill_itlb_sel = chk_unit_itlb_sel | csr_ref_itlb_sel;
assign chk_unit_sel = (!refill_itlb_sel) & (!csr_refill_req) & chk_unit_refill_req;
assign csr_ref_sel = (!refill_itlb_sel) & csr_refill_req;

always_comb begin
    case({refill_itlb_sel,chk_unit_sel,csr_ref_sel})
        3'b100   : refill_grant[1:0] = {chk_unit_itlb_sel,csr_ref_itlb_sel};
        3'b010   : refill_grant[1:0] = 2'b10;
        3'b001   : refill_grant[1:0] = 2'b01;
        default  : refill_grant[1:0] = 2'b00;
    endcase
end

assign refill_req = |refill_grant[1:0];
```

refill data 寄存从 4 路缩成 2 路：

```systemverilog
end else if(refill_grant[1] & twu_refill_idle)begin
    twu_ref_data_din[RDATA_WIDTH-1:0] <= chk_unit_refill_data[RDATA_WIDTH-1:0];
    twu_ref_tag_din[TAG_WIDTH-1:0] <= chk_unit_refill_tag[TAG_WIDTH-1:0];
    twu_ref_pgs[PGS_WIDTH-1:0] <= chk_unit_refill_pgs[PGS_WIDTH-1:0];
    twu_ref_type[TYPE_WIDTH-1:0] <= chk_unit_refill_type[TYPE_WIDTH-1:0];
    twu_ref_id[ID_WIDTH-1:0] <= chk_unit_refill_id[ID_WIDTH-1:0];
end else if(refill_grant[0] & twu_refill_idle)begin
    twu_ref_data_din[RDATA_WIDTH-1:0] <= csr_refill_data[RDATA_WIDTH-1:0];
    twu_ref_tag_din[TAG_WIDTH-1:0] <= csr_refill_tag[TAG_WIDTH-1:0];
    twu_ref_pgs[PGS_WIDTH-1:0] <= csr_refill_pgs[PGS_WIDTH-1:0];
    twu_ref_type[TYPE_WIDTH-1:0] <= csr_refill_type[TYPE_WIDTH-1:0];
    twu_ref_id[ID_WIDTH-1:0] <= csr_refill_id[ID_WIDTH-1:0];
end
```

旧的三级页表 `maee=0` 特殊打一拍逻辑被注释：

```systemverilog
/*
always_ff@(posedge twu_clk or negedge cpurst_b) begin
    ...
    thd_chk_refill_no_maee_sel <= 1'b1;
end

always_ff@(posedge twu_clk or negedge cpurst_b) begin
    ...
    mmu_sysmap_pax3[PPN_WIDTH-1:0] <= thd_chk_refill_data[RDATA_WIDTH-1:14];
end

assign thd_chk_refill_data_no_maee[RDATA_WIDTH-1:0] =
    {twu_ref_data_din[RDATA_WIDTH-1:14], sysmap_mmu_flgx3[4:0],twu_ref_data_din[8:0]};
*/
```

输出给 refill arbiter 的 data 不再二选一：

修改前：

```systemverilog
assign twu_arb_ref_data_din[RDATA_WIDTH-1:0] =
    thd_chk_refill_no_maee_sel ? thd_chk_refill_data_no_maee[RDATA_WIDTH-1:0] : twu_ref_data_din[RDATA_WIDTH-1:0];
```

修改后：

```systemverilog
assign twu_arb_ref_data_din[RDATA_WIDTH-1:0] = twu_ref_data_din[RDATA_WIDTH-1:0];
```

## PMP flag 传递链路总结

`twu_mbuf_pmpflg[7:0]` 的固定语义是：

```text
[3:0] = 第一级页表 PMP flag
[7:4] = 第二级页表 PMP flag
```

传递和回填链路如下：

```text
L1PDE_cache
  L1PDE_l1pmpflg
    -> L1PDE_entry_l1pmpflg
      -> PDE_cache L1PDE_cache_hit_l1pmpflg
        -> PDE_xbar_l1pmpflg
          -> one_to_four_xbar xbar_twu_l1pmpflg
            -> twu pmp_unit_pmpflg
              -> twu pmp_unit_l1pmpflg = ptw_addr_fst ? current L1 pmp_mmu_flg : carried L1 pmp_unit_pmpflg
                -> twu_mbuf_pmpflg[3:0] = L1 PMP flag
                -> twu_mbuf_pmpflg[7:4] = L2 PMP flag when the current PMP access is level 2
                  -> ptw_mbuf mbuf_twu_pmpflg
                    -> pde_updata_l1pmpflg = mbuf_twu_pmpflg[3:0]
                    -> pde_updata_l2pmpflg = mbuf_twu_pmpflg[7:4]
                      -> PDE cache refill pmpflg
```

`ptw_mbuf.sv` 原有代码已经把 mbuf 返回的 pmp flag 拆分给 PDE cache refill：

```systemverilog
pde_updata_l1pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
pde_updata_l2pmpflg[3:0] <= mbuf_twu_pmpflg[7:4];
```

修改理由：PDE cache 回填发生在非叶子 PTE 上。第一级非叶子回填 L1PDE cache 时，需要保存第一级页表 PMP flag；第二级非叶子回填 L2PDE cache 时，需要同时保存第一级和第二级页表 PMP flag。固定 `[3:0]` 为 L1、`[7:4]` 为 L2，可以让 `ptw_mbuf` 和 `PDE_cache` 的回填逻辑保持简单稳定。

## ready/反压链路总结

修改前：

```text
twu_data_ready[2] = fst_chk_ready
twu_data_ready[1] = scd_chk_ready
twu_data_ready[0] = thd_chk_ready

mbuf_entry writeback:
|(twu_data_ready & mbuf_lvl)
```

修改后：

```text
twu_data_ready = !(chk_unit_vld & chk_unit_wait)

mbuf_entry writeback:
twu_data_ready
```

修改前 `twu_mask` 需要综合三级 PMP wait 和两级非叶子继续 walk。修改后 `twu_mask` 只看统一 PMP wait 和统一 CHK 非叶子：

```text
pmp_unit_wait | chk_unit_non_leaf_no_fault
```

这满足 pdecache 请求没有被授权就拉低 ready，并停滞在 pdecache 中；因为 ready 拉低，也不接受 L2TLB 请求的设计意图。

## fault 来源总结

修改前：

```text
page fault:
  thd_chk -> scd_chk -> fst_chk priority

access fault:
  thd_pmp -> scd_pmp -> fst_pmp priority, and each source requires pmp_grant
```

修改后：

```text
page fault:
  chk_unit only

access fault:
  pmp_unit only
```

因为三级 chk/pmp 都被合并到统一单元，fault 输出不再需要多级优先级选择。

## 关键新增和变更信号说明

| 信号 | 位宽 | 所在位置 | 说明 |
| --- | --- | --- | --- |
| `L1PDE_entry_l1pmpflg` | `[3:0]` | `L1PDE_cache.sv -> PDE_cache.sv` | L1PDE entry 内保存的第一级页表 PMP flag。每个 L1PDE entry 独立输出，`PDE_cache` 按命中 index 选择。 |
| `PDE_xbar_l1pmpflg` | `[3:0]` | `PDE_cache.sv -> one_to_four_xbar.sv` | PDE cache L1 hit 时送出的 L1 PMP flag。L2 hit 时该字段不参与 L2 cache 权限判断，L2 权限已经在 `L2PDE_cache` 内部完成。 |
| `xbar_twu_l1pmpflg` | `[3:0]` | `one_to_four_xbar.sv -> twu.sv` | xbar 透传到 TWU 的 L1 PMP flag，作为 `pmp_unit_pmpflg` 的 xbar 来源。 |
| `twu_mask` | `1` | `twu.sv -> one_to_four_xbar.sv` | `pmp_unit_wait` 或 `chk_unit` 需要继续 walk 时拉高，用于反压 PDE cache/xbar。 |
| `twu_data_ready` | `1` | `twu.sv -> ptw_mbuf.sv/mbuf_entry.sv` | 统一 `chk_unit` 的 mbuf data 接收 ready。为 0 时 mbuf entry 不返回 data。 |
| `pmp_unit_vld` | `1` | `twu.sv` | 统一 PMP unit 当前请求有效。请求来源是 `chk_unit` next-level walk 或 xbar/PDE cache。 |
| `pmp_unit_wait` | `1` | `twu.sv` | 统一 PMP unit 保持当前请求的条件，包括 mbuf 未 grant 或 access fault 未被接收。 |
| `pmp_unit_vpn/type/id` | `VPN/TYPE/ID` | `twu.sv` | PMP 请求随路事务信息，后续原样送入 mbuf 或 fault 输出。 |
| `pmp_unit_ppn` | `PPN_WIDTH` | `twu.sv` | 第二级/第三级页表地址生成使用的上一级 PTE PPN；第一级地址使用 `regs_ptw_satp_ppn`。 |
| `pmp_unit_lvl` | `[2:0]` | `twu.sv` | 页表等级 one-hot。`3'b100` 第一级，`3'b010` 第二级，`3'b001` 第三级。 |
| `pmp_unit_pmpflg` | `[3:0]` | `twu.sv` | 随路保存的 L1 PMP flag；xbar 来源来自 `xbar_twu_l1pmpflg`，chk 来源来自 `chk_unit_pmpflg`。 |
| `pmp_unit_l1pmpflg` | `[3:0]` | `twu.sv` | 生成 `twu_mbuf_pmpflg[3:0]` 的修正信号。访问第一级时取当前 `pmp_mmu_flg`，访问第二/三级时取随路 `pmp_unit_pmpflg`。 |
| `pmp_unit_pa` | `PADDR_WIDTH` | `twu.sv -> PMP/MBUF` | 根据 `pmp_unit_lvl` 在 `ptw_fst_addr/ptw_scd_addr/ptw_thd_addr` 中选择，直接送 PMP 和 mbuf。 |
| `pmp_unit_deny` | `1` | `twu.sv` | 统一 PMP 权限失败标志，是 access fault 的唯一来源。 |
| `pmp_mbuf_req` | `1` | `twu.sv` | PMP 检查通过后发给 mbuf 的请求有效信号。 |
| `chk_unit_vld` | `1` | `twu.sv` | 统一 CHK unit 当前 PTE data 有效，只由 `mbuf_twu_data_vld` 置起。 |
| `chk_unit_wait` | `1` | `twu.sv` | CHK unit 保持当前 PTE 的条件，包括 next-level PMP wait、refill 未 grant、page fault 未 grant、CSR 未 grant。 |
| `chk_unit_vpn/type/id/lvl/data` | 对应字段位宽 | `twu.sv` | 从 mbuf 返回请求中锁存的 PTE 检查上下文。 |
| `chk_unit_pmpflg` | `[3:0]` | `twu.sv` | 从 `mbuf_twu_pmpflg[3:0]` 锁存的 L1 PMP flag，用于非叶子继续 walk 时传回 `pmp_unit`。 |
| `chk_unit_flg` | `[8:0]` | `twu.sv` | 从 PTE data 中抽取的 `{data[9:6], data[4:0]}`，用于 page fault 和 leaf 判断。 |
| `chk_unit_leaf_vld` | `1` | `twu.sv` | 1G leaf、2M leaf 或第三级检查目标成立时为 1。非叶子且无 fault 时会进入 `pmp_unit`。 |
| `chk_unit_page_flt` | `1` | `twu.sv` | 统一 page fault 判断结果，是 page fault 输出的唯一来源。 |
| `chk_unit_ppn` | `PPN_WIDTH` | `twu.sv` | 从 PTE data `[37:10]` 抽取的 PPN，供 next-level walk、refill 和 `mmu_sysmap_pax3` 使用。 |
| `chk_unit_refill_req` | `1` | `twu.sv` | `chk_unit_vld` 且 leaf 可 refill 时置起。1G/2M leaf 需要 `maee=1`，第三级 leaf 直接 refill。 |
| `chk_unit_csr_req` | `1` | `twu.sv` | 1G/2M leaf 且 `maee=0` 时进入 CSR/sysmap 跨页检查。 |
| `chk_unit_refill_high_flg` | `[4:0]` | `twu.sv` | Refill data 的高 flag。`maee=1` 取 PTE data `[63:59]`，否则取 `sysmap_mmu_flgx3`。 |
| `refill_grant` | `[1:0]` | `twu.sv` | Refill 二路仲裁结果。`[1]` 表示 `chk_unit_refill`，`[0]` 表示 `csr_refill`。 |
| `refill_chk_unit_grant` | `1` | `twu.sv` | `refill_grant[1] & twu_refill_idle`，反馈给 `chk_unit_wait`。 |
| `refill_csr_grant` | `1` | `twu.sv` | `refill_grant[0] & twu_refill_idle`，反馈给 CSR FSM。 |

## 代码确认点处理结果

上一版文档列出的待确认项已经按当前 RTL 重新核对，结果如下：

1. `ptw.sv` 顶层接线已补齐。当前代码已经声明 `PDE_xbar_l1pmpflg[3:0]` 和 `xbar_twu_l1pmpflg[3:0]`，并在 `PDE_cache -> one_to_four_xbar -> twu` 三个实例之间完成 named port 连接。
2. `ptw.sv` 中 `twu_data_ready` 已改为 scalar `logic twu_data_ready`，`twu` 和 `ptw_mbuf` 实例也都连接 scalar，不再使用 `twu_data_ready[PTE_LEVEL-1:0]`。
3. `L1PDE_cache.sv` 的 module port list 已声明 `output logic [3:0] L1PDE_entry_l1pmpflg`，并由 `assign L1PDE_entry_l1pmpflg[3:0] = L1PDE_l1pmpflg[3:0];` 输出 entry 内保存的 L1 PMP flag。
4. `PDE_cache.sv` 中 `L1PDE_entry_l1pmpflg` 和 `L1PDE_cache_hit_l1pmpflg` 的声明位宽已经确认完整：`L1PDE_entry_l1pmpflg` 是 `[L1PDE_ENTRY_NUM-1:0][3:0]`，`L1PDE_cache_hit_l1pmpflg` 是 `[3:0]`。
5. 本次修正了 `PDE_cache.sv` 中 `L1PDE_cache` 实例的 pmp flag 连接：由 `L1PDE_entry_l1pmpflg[3:0]` 改为 `L1PDE_entry_l1pmpflg[L1PDE_ent]`。理由是 generate 中每个 entry 必须写入自己对应的 4bit slot，不能把整个数组切片接给单个 4bit output。
6. `twu.sv` 中 `pmp_unit_l1pmpflg[3:0]` 已经在声明区补齐，位宽与 `twu_mbuf_pmpflg[3:0]` 和 `pmp_mmu_flg[3:0]` 一致。
7. `twu.sv` 中统一 PMP level 信号当前命名为 `pmp_unit_lvl`，文档已经同步更新；上一版文档里的拼写错误属于过期描述。
8. `chk_unit_refill_req` 已经显式与 `chk_unit_vld` 相与，避免 `chk_unit_vld=0` 时依赖寄存器残值产生 refill request。
9. `refill_grant` 位含义已经与 data mux 和 grant feedback 对齐：`refill_grant[1]` 对应 `chk_unit_refill`，`refill_grant[0]` 对应 `csr_refill`；末尾赋值为 `refill_chk_unit_grant = refill_grant[1] & twu_refill_idle`，`refill_csr_grant = refill_grant[0] & twu_refill_idle`。
10. `git diff --check` 已重新检查，当前只剩 Git 对 `mbuf_entry.sv` 行尾转换的提示，没有功能相关的 whitespace error。

当前文档不再保留开放的代码待确认项。后续仍建议用项目原有编译/仿真流程覆盖 PMP allow/deny、L1/L2 PDE cache hit、CSR/sysmap cross check、三级 leaf refill 和 abort/drain 场景。

## 本次重构后的关键不变量

- TWU 到 MBUF 的请求只有一个来源：`pmp_unit`。
- TWU 到 PMP 的请求只有一个来源：`pmp_unit_pa` 和 `pmp_fetch_type`。
- CHK 请求只有一个来源：`mbuf_twu_data_vld` 返回数据。
- CHK 后续继续 walk 只在非叶子、无 page fault 时进入 `pmp_unit`。
- CHK 后续 leaf 处理只走两种路径：`maee=1` 的 1G/2M leaf 或第三级 leaf 进入 refill；`maee=0` 的 1G/2M leaf 进入 CSR/sysmap cross check 再 refill。
- Page fault 输出只来自 `chk_unit`。
- Access fault 输出只来自 `pmp_unit`。
- `twu_data_ready` 只有 1bit。
- L1 PDE hit 后，L1 PMP flag 需要从 PDE cache/xbar/TWU/mbuf 路径继续传递。





