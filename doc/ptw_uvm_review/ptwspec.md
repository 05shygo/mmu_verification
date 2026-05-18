# PTW UVM Review Specification

本文档是 `ptw_overview.md` 的正式化规格版本，用于后续 UVM reference model、scoreboard、monitor、assertion 和覆盖场景编写。本文保留 `ptw_overview.md` 中的所有有效结论，并对后续澄清已经覆盖的旧答案做了收敛；如果旧回答和后续回答冲突，以本文的“最终采用规则”为准。

本文档中的 `fst/scd/thd` 分别表示 Sv39 第一级、第二级、第三级页表访问流水；`PMP` 表示页表项所在物理地址的 PMP 检查；`CHK` 表示 LSU 返回 PTE 后的 PTE 合法性、页表异常、叶子页表和 refill/下一级跳转检查。

## 0. 最终采用规则

1. 后轮澄清覆盖前轮澄清：第六轮问题优先级最高，其次第五轮、第四轮、第三轮、第二轮、第一轮以及正文描述。
2. 字段映射采用第六轮 Q174、第五轮 Q164/Q165，覆盖旧 Q130：RSW 进入 refill `flg`，但不参与 page fault；raw PTE 的 G 位不进入 data `flg`，只进入 tag/global。
3. page fault 规则采用第六轮 Q176、第五轮 Q166/Q167、第三轮 Q131-Q133：reference model 不额外套标准 Sv39 的保留位、RSW、strong-order 检查；非叶子 PTE 只检查 `V=0`、本设计 write-only 规则、以及第三级仍非叶子。
4. abort 与 LSU bus error 采用第五轮 Q161/Q162、第四轮 Q159、第三轮 Q124/Q148：`tlboper_ptw_abort` 清空全部 PDE cache 并 flush in-flight PTW；abort 同拍新形成的 LSU bus error 不上报。
5. PDE cache 更新与上下文变化采用第六轮 Q175、第五轮 Q168/Q169、第三轮 Q136-Q140/Q155：satp/PMP 变化只清 PDE cache，不 abort in-flight walk；旧 in-flight walk 未被 abort/flush 屏蔽时仍可重新更新 PDE cache。
6. MPRV/MPP 采用最新修正规则：fetch 使用真实流水线特权级，不受 MPRV/MPP 影响；load/store/PFU 在 `MPRV=1` 时使用 `mstatus.MPP` 决定 data effective privilege 和 data MMU enable。只要 data effective privilege 为 M，load/store/PFU 就走 data direct-map，物理地址等于虚拟地址，不会进入 L1D/L2TLB/PTW source path；典型场景包括真实流水线 `priv=S/U` 且 `MPRV=1 && MPP=M`。
7. scoreboard 与仲裁采用第五轮 Q172、第二/三轮 Q114-Q118/Q143/Q144：scoreboard 做事务级最终匹配；周期级仲裁、ready/backpressure、valid 保持、abort 时序由 assertion/monitor 检查。
8. 当前不存在已知 RTL 待修项。旧文档中提到的 “tlboper 清 PDE cache 需要 RTL 修改” 和 “MAEE=0 且 4K 走 sysmap 需要 RTL 修改” 已经被后续回答覆盖为已修好。
9. 文档中残留的 `scd_pmp` 笔误如果出现在第三级流程里，一律按 `thd_pmp/thd_pmp_pa` 理解。
10. 本文没有新增待澄清问题；按当前回答，PTW 行为已经足够用于 UVM 建模。

## 1. 地址、模式与 PTE 格式

### 1.1 支持模式

PTW 只支持 Sv39 地址翻译语义：三级页表、4KB 基页，最终 leaf page size 可以是 1G、2M、4K。Bare 模式存在，但 Bare 模式下上游保证不会向 PTW 发起 walk 请求；如果 bare 下需要地址转换，语义上 `ppn=野地址对应 vpn`，不经 PTW。本 spec 不定义 bare 模式请求误入 PTW 的行为，UVM 可以约束不产生。

PTW 输入只有 `vpn[26:0]`，不包含 VA offset，也不包含高位虚拟地址。canonical/sign-extension 检查不在 PTW 中完成，由 PTW 上游保证不会出现非 canonical 输入。

### 1.2 VPN/PPN 分段

Sv39 VPN 与本文档字段对应如下：

| 字段 | 位段 | 含义 |
| --- | --- | --- |
| `vpn[2]` | `vpn[26:18]` | 第一级页表索引 |
| `vpn[1]` | `vpn[17:9]` | 第二级页表索引 |
| `vpn[0]` | `vpn[8:0]` | 第三级页表索引 |

物理地址为 40 bit，由 `ppn[27:0]` 和 `offset[11:0]` 组成。PPN 分段如下：

| 字段 | PPN 位段 | PTE 位段 | 含义 |
| --- | --- | --- | --- |
| `ppn[2]` | `ppn[27:18]` | `PTE[37:28]` | 高 10 bit PPN |
| `ppn[1]` | `ppn[17:9]` | `PTE[27:19]` | 中 9 bit PPN |
| `ppn[0]` | `ppn[8:0]` | `PTE[18:10]` | 低 9 bit PPN |

`regs_ptw_satp_ppn[PPN_WIDTH-1:0]` 是根页表 PPN，用于生成第一级 PTE 访问地址。

### 1.3 PTE raw bit 定义

64 bit PTE raw bit 格式如下：

| raw PTE 位段 | 字段 |
| --- | --- |
| `PTE[63]` | `So` |
| `PTE[62]` | `C` |
| `PTE[61]` | `B` |
| `PTE[60]` | `Sh` |
| `PTE[59]` | `Sec` |
| `PTE[58:38]` | 保留位，PTW 不检查，按设计假定为 0 |
| `PTE[37:28]` | `PPN[2]` |
| `PTE[27:19]` | `PPN[1]` |
| `PTE[18:10]` | `PPN[0]` |
| `PTE[9:8]` | `RSW[1:0]` |
| `PTE[7]` | `D` |
| `PTE[6]` | `A` |
| `PTE[5]` | `G` |
| `PTE[4]` | `U` |
| `PTE[3]` | `X` |
| `PTE[2]` | `W` |
| `PTE[1]` | `R` |
| `PTE[0]` | `V` |

PTE 中 PPN 字段总宽度就是 28 bit，因此不会出现超出 40 bit 物理地址范围的信息。PTW 不额外检查 `PTE[58:38]` 高位保留位，也不因为 MAEE 开关改变对这些保留位的处理。

### 1.4 raw PTE、内部 `ptw_flg` 与 refill `flg`

本文区分三套字段：

1. raw PTE bit：按上表从内存返回的原始 PTE 位定义。
2. 内部 `ptw_flg`：去掉 raw PTE 的 `G` 位后重新打包，因此低位含义为 `ptw_flg[0]=V`、`ptw_flg[1]=R`、`ptw_flg[2]=W`、`ptw_flg[3]=X`、`ptw_flg[4]=U`、`ptw_flg[5]=A`、`ptw_flg[6]=D`。
3. refill tag/data：L2TLB refill tag 包含 `vpn/asid/page_size/global`；L2TLB refill data 包含 `ppn/flg`。raw PTE 的 `G` 不进入 data `flg`，只作为 `global` 进入 tag。

refill `flg` 包含：

1. 扩展属性 `{So,C,B,Sh,Sec}`。
2. `RSW[1:0]`。RSW 进入 refill `flg`，但不参与 page fault。
3. 标准状态与权限位 `D/A/U/X/W/R/V`。G 位不包含在 data `flg` 中。

`MAEE=1` 时，refill 扩展属性来自 raw PTE 的 `PTE[63:59]={So,C,B,Sh,Sec}`。`MAEE=0` 时，所有 page size 的 refill 扩展属性都来自 sysmap，顺序仍为 `{So,C,B,Sh,Sec}`，raw PTE 的扩展属性被忽略。

## 2. 请求与返回接口

### 2.1 L2TLB 到 PTW 请求

L2TLB 发给 PTW 的请求字段包括 `vpn`、`type`、`id[5:0]`。ASID、VMID 等不作为请求字段传入；ASID 在 refill 返回当拍直接使用当前 satp 中的 ASID。MXR、SUM、privilege、MPRV、MAEE 等 CP0/CSR 状态直接连接到 PTW，在 PMP/CHK/refill 使用点读取当前值，不在 request accept 时统一锁存。

`type` 编码如下：

| type | 来源/含义 | 返回目标 |
| --- | --- | --- |
| `3'b100` | PFU，LSU port2 prefetch | 成功只 refill L2TLB；异常返回 L2TLB 后由 L2TLB 上报 LSU prefetch 端口 |
| `3'b011` | IUTLB/fetch | 成功 refill L1ITLB 和 L2TLB |
| `3'b010` | Load | 成功 refill L1DTLB 和 L2TLB |
| `3'b110` | Store/atomic | 成功 refill L1DTLB 和 L2TLB |

不存在独立 atomic/AMO type；store type 同时覆盖普通 store 和 atomic，对 PMP store 权限和 PTE D/W 检查按 store 处理。

`id[5:0]` 为复合 ID：

1. `id[5:3]` 是 L2TLB miss buffer entry。新分配时来自 `dtlb_alloc_index`，从缓冲就绪条目发出时来自 `entry_rdy_id`。
2. `id[2:0]` 是 L1 DTLB miss entry，对应 `req_l1eid/entry_rdy_eid`。
3. IUTLB 请求没有 L1DTLB entry，低 3 bit 固定为 0；scoreboard 应忽略 IUTLB 返回中的 L1 部分。
4. 同一个 id 不会在旧请求完成前被新请求复用。

### 2.2 正常 refill 字段与 page size 编码

正常 refill 返回字段包括 `vpn`、`asid`、`page_size`、`global`、`ppn`、`flg`、`type`、`id`。L2TLB 需要完整 tag/data；L1TLB 不需要 ASID/global，只需要 `vpn/page_size/ppn/flg` 以及用于定位 miss entry 的信息。

page size 编码：

| page size | 编码 |
| --- | --- |
| 1G | `3'b100` |
| 2M | `3'b010` |
| 4K | `3'b001` |

`global` 只使用当前 leaf PTE 的 G 位，不 OR 任意上级非叶子 PTE 的 G 位。PDE cache 不存 G 位，因此 PDE cache 命中路径最终 global 仍来自真正读到的 leaf PTE。

### 2.3 异常返回

访问异常和页表异常返回只区分两类：access fault 和 page fault，不再细分 instruction/load/store/prefetch cause。异常返回携带 `type/id`，用于定位请求来源和释放 L2TLB miss buffer；`type` 不是异常 cause 编码。

异常目标：

1. IUTLB/fetch 异常上报给 L1ITLB，同时释放 L2TLB miss buffer。
2. Load/Store 异常上报给 L1DTLB 对应 miss entry，同时释放 L2TLB miss buffer。
3. PFU 异常返回给 L2TLB，然后 L2TLB 上报 LSU prefetch 端口，同时释放 L2TLB miss buffer。

同周期最终输出只允许一种结果，优先级固定为：

```text
access fault > page fault > normal refill
```

## 3. PDE Cache

### 3.1 结构

PTW 有两级 PDE cache，每级 16 entry、全相联、寄存器堆实现，每级有独立 PLRU 替换状态。

| PDE cache | tag | data | 用途 |
| --- | --- | --- | --- |
| 第一级 PDE cache | `vpn[2]` | 第一级非叶子 PTE 的 PPN | 生成第二级 PTE 访问地址 |
| 第二级 PDE cache | `{vpn[2],vpn[1]}` | 第二级非叶子 PTE 的 PPN | 生成第三级 PTE 访问地址 |

PDE cache entry 不包含 ASID、global、权限、PMA 属性、RSW、A/D 等字段。地址空间切换依靠 satp 任意字段改变时清空 PDE cache；PMP 配置改变也清空 PDE cache。

### 3.2 Lookup

每个被 PTW accept 的 L2TLB 请求都会先进入 PDE cache，同时并行查找两级 PDE cache 的所有 entry。每周期最多 accept 一个 L2TLB 请求，因此 PDE cache lookup 不需要多请求仲裁。

命中规则：

1. 第一级任意 entry valid 且 tag 等于 `vpn[2]`，认为第一级命中。
2. 第二级任意 entry valid 且 tag 等于 `{vpn[2],vpn[1]}`，认为第二级命中。
3. 两级同时命中时选择第二级命中，不校验一级与二级内容一致性，因为第二级更接近 leaf。
4. 第一级命中后跳过 `fst_pmp/fst_chk`，携带第一级 PDE cache data PPN 进入 `scd_pmp`。
5. 第二级命中后跳过 `fst_pmp/fst_chk/scd_pmp/scd_chk`，携带第二级 PDE cache data PPN 进入 `thd_pmp`。

被跳过级别的 PMP/CHK 合法性依赖当初填入 PDE cache 时已经通过 PMP 和 page fault 检查。

### 3.3 Update

PDE cache update 由 mbuf 在 LSU 返回 PTE 时判断。更新条件：

1. 返回的 PTE 是非叶子 PTE。
2. 该 PTE 未触发 page fault。
3. 当前请求未被 reset、`tlboper_ptw_abort` 或其他 flush 屏蔽。

不要求 satp/PMP 上下文仍然有效。也就是说，satp/PMP 配置改变只清空 PDE cache、不 abort in-flight walk 时，旧 in-flight walk 后续返回的非叶子 PTE 若满足上述条件，仍允许重新更新 PDE cache。UVM 可以约束 satp.asid/satp.ppn 改变通常伴随 abort，避免旧 walk 使用新 ASID refill 的软件不期望交错。

更新级别：

1. 第一级 PTE 返回且为非叶子无 page fault，更新第一级 PDE cache，tag=`vpn[2]`，data=`PTE.PPN`。
2. 第二级 PTE 返回且为非叶子无 page fault，更新第二级 PDE cache，tag=`{vpn[2],vpn[1]}`，data=`PTE.PPN`。
3. 第一级 PDE cache 命中后，如果 `scd_chk` 对应的第二级 PTE 为非叶子且无异常，仍按 `lvl=scd` 更新第二级 PDE cache。

同拍 lookup 与 update 时，lookup 看到旧值，update 下一拍生效。PLRU 在命中和写入时都会更新；写入时若存在 invalid entry，优先使用 invalid entry，否则使用 PLRU victim。

### 3.4 Clear

| 事件 | PDE cache | in-flight PTW/TWU/mbuf/refill/异常寄存器 |
| --- | --- | --- |
| reset | 全清 | flush/清 valid |
| `tlboper_ptw_abort` | 全清 | flush/清 valid，并处理 LSU outstanding 边界 |
| satp 任意字段改变 | 下一拍所有 entry valid 拉低 | 不 flush，不要求 L2TLB 重发 |
| PMP 配置改变 | 硬件自动清空 | 不 flush，不要求 L2TLB 重发 |

不存在按 VA/ASID 精确失效 PDE cache 的行为。

## 4. Xbar 与 Ready/Backpressure

PDE cache 之后通过 `xbar_one_to_four` 将请求分发给 4 个 TWU。hash 函数为：

```systemverilog
assign twu_hash[1:0] =
    PDE_xbar_vpn[1:0]   ^
    PDE_xbar_vpn[10:9]  ^
    PDE_xbar_vpn[19:18] ^
    PDE_xbar_vpn[26:25];
```

PTW 每周期最多 accept 一个 L2TLB 请求。若 hash 选中的目标 TWU 当前不能接收新请求，PTW 拉低 ready；L2TLB 认为该请求未被 PTW accept，必须保持 valid 和请求字段稳定，后续继续发同一个请求。

从时序描述看，`T0` L2TLB 请求拉高，`T1` 进入 PDE cache lookup，之后经 xbar 进入对应 TWU；文档中 T0/T1/T2 是行为顺序和典型流水示例。UVM scoreboard 不做 fixed-cycle 检查；cycle-accurate 的 ready、valid 保持、xbar 分发、PDE lookup/update 时序交给 assertion/monitor。

TWU 暂时无法接收 xbar 请求的典型情况包括：

1. 对应 TWU 的 PMP 类流水线存在 wait，无法保证新请求落点不冲突。
2. `fst_chk/scd_chk` 检出非叶子且准备进入下一级 PMP 流水时，下一级 PMP 流水或其 wait 状态会阻塞新请求。
3. refill/page fault/access fault 寄存器或 mbuf 写仲裁未授权导致上游流水线 wait。
4. MAEE=0 且 leaf 需要进入跨页/sysmap 流程，但跨页状态机不空闲。

## 5. TWU 流水

每个 TWU 有 6 级流水：

```text
fst_pmp -> fst_chk -> scd_pmp -> scd_chk -> thd_pmp -> thd_chk
```

如果 PDE cache 命中，会跳过对应的前级流水：

```text
PDE miss       : fst_pmp -> fst_chk -> scd_pmp -> scd_chk -> thd_pmp -> thd_chk
L1 PDE hit    : scd_pmp -> scd_chk -> thd_pmp -> thd_chk
L2 PDE hit    : thd_pmp -> thd_chk
```

### 5.1 PMP 类流水

PMP 类流水负责生成页表项所在物理地址，并对该物理地址做 PMP 权限检查。检查对象是“读取 PTE 的物理地址”，不是最终翻译出的物理地址。PMP 检查精确到 4KB 物理块。

地址生成公式：

```systemverilog
fst_pmp_pa = {regs_ptw_satp_ppn, vpn[26:18], 3'b0};
scd_pmp_pa = {prev_nonleaf_ppn,  vpn[17:9],  3'b0};
thd_pmp_pa = {prev_nonleaf_ppn,  vpn[8:0],   3'b0};
```

`fst_pmp` 不携带上级 PPN，使用 `regs_ptw_satp_ppn`。`scd_pmp/thd_pmp` 携带上一级非叶子 PTE 的 PPN，可能来自 LSU 返回的非叶子 PTE，也可能来自 PDE cache。

PMP 访问类型跟随原始请求 type，而不是统一作为 load：

1. IUTLB/fetch 按 fetch 检查。
2. Load 按 load 检查。
3. Store/atomic 按 store 检查。
4. PFU 按 load 类 PMP 权限检查。

PMP deny 规则为：

```systemverilog
deny = (fetch && !pmp_mmu_flg[2]
     || load  && !pmp_mmu_flg[0]
     || store && !pmp_mmu_flg[1]
     || pfu   && !pmp_mmu_flg[0])
     && !(effective_machine_mode && !pmp_mmu_flg[3]);
```

`pmp_mmu_flg[3]` 是 M-mode L-bit 相关规则：当 effective mode 为 M 且 `pmp_mmu_flg[3]==0` 时，跳过 PMP deny，不触发 access fault；如果 effective mode 为 M 但 `pmp_mmu_flg[3]==1`，仍按对应权限位判断。

PMP 未通过时，该请求立即结束，不写 mbuf、不发 LSU、不进入 CHK，也不可能再产生 page fault。PMP 类流水会发起写访问异常寄存器请求，写入 `type/id` 后等待顶层仲裁上报。

PMP 通过时，PMP 类流水向 mbuf 写入请求，携带：

```text
padder/pa, vpn, type, id, twu_idx, lvl
```

`twu_idx` 用于 mbuf 返回数据时定位目标 TWU；`lvl` 用于定位 `fst_chk/scd_chk/thd_chk`。

### 5.2 CHK 类流水

CHK 类流水接收 mbuf 从 LSU 返回的 64 bit PTE，执行 page fault 检查、leaf 判断、PDE cache update 条件判断配合、下一级跳转或 refill/异常寄存器写入。

CHK 行为：

1. 若 PTE 触发 page fault，写页表异常寄存器，携带 `type/id`，请求结束，不进入下一级 PMP，不 refill。
2. 若无 page fault 且为 leaf PTE，生成 refill 数据；MAEE=1 可直接按 PTE 扩展属性 refill，MAEE=0 需进入 sysmap/跨页状态机后 refill。
3. 若无 page fault 且为非叶子 PTE，进入下一级 PMP；如果当前级为第三级，则第三级非叶子触发 page fault。

PMP 返回 `flg` 是组合返回；PMP 仲裁失败时流水线 valid/data 保持并拉 wait。CHK 从 mbuf 收到数据后，页表异常检查、leaf 判断、发往下一级 PMP 或 refill 请求按一拍完成建模即可；实际周期检查交给 assertion。

### 5.3 TWU 内部 wait 条件

PMP wait：

1. 多个请求竞争 PMP 仲裁，本级 PMP 请求未获授权。
2. PMP 通过后写 mbuf 请求未获 mbuf 授权。
3. PMP deny 后写访问异常寄存器请求未获授权。

`fst_chk_wait`：

1. 检出非叶子且需要进入 `scd_pmp`，但 `scd_pmp_wait` 拉高。
2. 检出 leaf 且 `MAEE=1`，发 normal refill 请求但 refill 寄存器/仲裁未授权。
3. 检出 page fault，写页表异常寄存器未授权。
4. 检出 leaf 且 `MAEE=0`，但跨页/sysmap 状态机不空闲或进入跨页仲裁未授权。

`scd_chk_wait`：

1. 检出非叶子且需要进入 `thd_pmp`，但 `thd_pmp_wait` 拉高。
2. 检出 leaf 且 `MAEE=1`，normal refill 未授权。
3. 检出 page fault，页表异常寄存器未授权。
4. 检出 leaf 且 `MAEE=0`，跨页/sysmap 状态机不空闲或仲裁未授权。

`thd_chk_wait`：

1. 检出 leaf 后发 normal refill 请求但未获授权。
2. 检出 page fault 后写页表异常寄存器未获授权。

## 6. PTE 检查与 Page Fault

### 6.1 Leaf 判定

leaf PTE 判定为：

```text
V=1 && (R=1 || X=1)
```

W alone 不构成 leaf。第三级如果 `R=0 && X=0`，即仍为非叶子形态，则触发 page fault。

### 6.2 非叶子 PTE page fault

非叶子 PTE 最终只检查：

1. `V=0`。
2. 本设计 write-only 规则命中。
3. 第三级仍为非叶子，即 `thd_chk` 中 `R=0 && X=0`。

除此之外，非叶子 PTE 的 `U/G/A/D/RSW/PTE[58:38]/So/C/B/Sh/Sec` 都不参与 page fault 检查。非叶子 G 不参与最终 global，PDE cache 也不存 G。

### 6.3 Leaf PTE page fault

leaf PTE page fault 按本设计 RTL/文字规则建模，不额外套标准 Sv39 保留位、RSW、strong-order 检查。主要条件如下：

1. `V=0` 触发 page fault。
2. write-only 规则：`W=1 && !(R || (MXR && X))` 触发 page fault。因此 `W=1,R=0,X=1,MXR=1` 在本设计中允许通过，不触发 write-only fault。
3. Load 权限：load 要求 `R=1` 或 `MXR=1 && X=1`；否则 page fault。
4. Store/atomic 权限：store 要求 `W=1`；否则 page fault。
5. Fetch/IUTLB 权限：fetch 要求 `X=1`；否则 page fault。
6. PFU 权限独立处理：PFU 不要求 `R=1`，也不要求 `MXR && X`，不检查 D；PFU 仍要求 A=1。
7. S-mode 访问 U page：`U=1 && effective_supervisor_mode && SUM=0` 触发 page fault。
8. U-mode 访问 S page：`U=0 && effective_user_mode` 触发 page fault。
9. effective machine mode 下，PTE U/S 权限检查按 M 态跳过。
10. 所有 leaf 请求都要求 `A=1`，包括 fetch/load/store/PFU。
11. Store/atomic 还要求 `D=1`。
12. 1G leaf 要求 `PPN[1:0]==0`；否则 page fault。
13. 2M leaf 要求 `PPN[0]==0`；否则 page fault。

可用如下伪代码建模：

```text
write_only_fault = W && !(R || (MXR && X))

leaf_fault =
    !V
 || write_only_fault
 || (is_load  && !R && !(MXR && X))
 || (is_store && !W)
 || (is_fetch && !X)
 || (U && effective_supervisor && !SUM)
 || (!U && effective_user)
 || !A
 || (is_store && !D)
 || (is_1G_leaf && PPN[1:0] != 0)
 || (is_2M_leaf && PPN[0] != 0)

pfu_leaf_fault =
    !V
 || write_only_fault
 || (U && effective_supervisor && !SUM)
 || (!U && effective_user)
 || !A
 || (is_1G_leaf && PPN[1:0] != 0)
 || (is_2M_leaf && PPN[0] != 0)
```

注意：PFU 仍受 `V`、write-only、U/S、A、大页对齐约束，但不按 load 检查 R/MXR/X，也不检查 D。

### 6.4 不检查项

以下项不在 PTW page fault 中检查：

1. PTE high reserved bits `PTE[58:38]` 非 0。
2. RSW 值。
3. strong-order/fetch meets strong order。该规则不由 MMU PTW 检查，可能由 IFU 或其他模块处理。
4. MAEE=0 时 PTE 扩展属性非 0。此时扩展属性被忽略，refill PMA 属性来自 sysmap。
5. sysmap malformed，即没有命中任何区域或多命中。设计假设 sysmap 配置不会出现该情况，UVM 可约束不产生。

## 7. MPRV、Privilege 与上下文采样

`regs_ptw_satp_ppn`、satp ASID、MXR、SUM、当前特权级、MPRV、MPP、MAEE 等状态不随请求统一锁存，而是在各使用点读取当前值：

1. `fst_pmp_pa` 生成时读取当前 `regs_ptw_satp_ppn`。
2. CHK 权限检查时读取当前 MXR/SUM/effective privilege。
3. refill 返回时 ASID 使用当前 satp ASID。
4. MAEE 在 leaf CHK 时决定是否进入 sysmap/跨页流程；一旦进入该流程，最终 refill 属性不因后续 MAEE 改变而回退。

如果一次 walk 中途 satp.ppn 或 ASID 改变但没有 abort，硬件不锁定 walk 开始时的根页表或 ASID，可能发生旧页表访问与新 ASID refill 的交错。软件通常通过 sfence/tlboper/abort 避免，UVM 可以约束不产生 satp.asid/satp.ppn 无 abort 改变的场景。

Privilege 规则：

1. Fetch/IUTLB 永远使用流水线真实特权级。
2. Load/Store/PFU 若 `MPRV=1`，使用 `mstatus.MPP/cp0_mmu_mpp` 作为 effective privilege；若 `MPRV=0`，使用流水线真实特权级。
3. `cp0_supv_mode/cp0_user_mode/cp0_mach_mode` 在 PTW 检查中应按 effective privilege 理解。
4. 纯 M 态且不做地址翻译时，上游保证不会进入 PTW。
5. 当 load/store/PFU 的 data effective privilege 为 M 时，data MMU 关闭，物理地址直接等于虚拟地址；该请求不会产生 DTLB miss、L2TLB miss 或 PTW source 请求。`priv=S/U, MPRV=1, MPP=M` 属于该类；`priv=M, MPRV=1, MPP=S/U` 则不属于该类，仍可按 S/U data effective privilege 进入翻译路径。
6. Fetch/IFU 不使用 `MPRV/MPP` 生成 effective privilege。真实流水线 `priv=S/U` 的 fetch 在 Sv39 下仍可能进入 PTW；真实流水线 `priv=M` 的 fetch 不进入 PTW。

## 8. Mbuf 与 LSU

### 8.1 Entry 结构与分配

mbuf 共 9 个 entry：

1. entry0-entry7：DTLB/LSU 来源，包括 load、store、PFU。
2. entry8：IUTLB/fetch 专用。

IFU 是阻塞式结构，同一时间只有一个 IFU 请求在 MMU/PTW 中处理，因此 entry8 不会溢出。DTLB 侧最多 8 个 PTW 请求，和 L2TLB miss buffer 数量一致；设计依赖上游保证不会出现分配指针指向 valid entry 的溢出场景。

mbuf 写入仲裁优先级：

```text
IUTLB > TWU0 > TWU1 > TWU2 > TWU3
```

IUTLB 请求固定写 entry8。Load/Store/PFU 写 entry0-entry7，按 one-hot/左移指针轮转分配，初始指向 entry0。

每个 entry 存储 `padder/pa`、`vpn`、`type`、`id`、`twu_idx`、`lvl`、返回数据寄存器、`get`、`on`、`lsu bus err flop` 等状态。`get` 表示已经拿到 LSU 数据但尚未送入目标 CHK；`on` 表示该 entry 当前在 LSU 中 outstanding。

### 8.2 LSU 发请求

LSU 接口没有 grant/ready。PTW 向 LSU 发请求时拉高 request valid，并保持物理地址稳定，直到 LSU data valid 返回。LSU 串行单 outstanding，不允许多 outstanding。

发 LSU 优先级：

1. entry8/IUTLB 优先。
2. entry0-entry7 按发送指针轮转。

mbuf 写 entry 与向 LSU 发出请求可以理解为相邻周期：写入 entry 后，如果条件允许，下一拍即可发给 LSU。

### 8.3 LSU 返回普通数据

LSU 返回 64 bit 数据，整个 64 bit 就是 PTE，不需要抽取子字段或处理端序。mbuf 根据 `on` 定位 outstanding entry。

返回处理：

1. 若目标 `twu_idx/lvl` 对应 CHK ready，mbuf 将 `vpn/type/id/PTE/twu_idx/lvl` 送回目标 TWU CHK，数据成功送入 CHK 后释放 entry。
2. 若目标 CHK 不 ready，mbuf 将数据保存到 entry 的数据寄存器，置 `get`，等待目标 CHK ready 后再发返回请求；该 entry 等待期间不阻塞其他 entry 发 LSU。
3. 如果保存了数据但尚未送入 CHK，此时发生 abort，则 entry valid 清掉，数据丢弃。

### 8.4 LSU bus error

LSU 返回 bus error 时，请求不进入 CHK，直接形成 access fault。处理流程：

1. mbuf 根据 `on` 定位原 entry。
2. 使用 entry 中的 `type/id` 发起写 mbuf access exception register 请求。
3. 若访问异常寄存器空闲且仲裁授权，写入成功后释放 entry。
4. 若异常寄存器 busy 或仲裁未授权，entry 保持 valid，置 `lsu bus err flop`，后续继续尝试写异常寄存器；在写入成功前 entry 不可复用。
5. 顶层 access fault 仲裁中，LSU bus error 优先于 4 个 TWU access fault。

同一个原始请求不会同时出现 LSU bus error access fault 和 CHK page fault，因为 bus error 后请求不进入 CHK。

## 9. Refill、异常寄存器与仲裁

每个 TWU 有一组 normal refill 寄存器、一组 page fault 寄存器、一组 access fault 寄存器。若对应寄存器已有有效请求且未被顶层仲裁接受，新 refill/异常到来时反压对应流水线，保持 valid/data，直到写入成功。

TWU 内部仲裁通用顺序：

```text
IUTLB > thd > scd > fst
```

normal refill 内部有 4 类来源：IUTLB、跨页检查状态机、`thd_chk`、`scd_chk`、`fst_chk`。最终优先级：

```text
IUTLB > 跨页检查状态机 > thd > scd > fst
```

跨页检查状态机完成后发 refill 请求，若 refill 寄存器未授权，则状态机/请求保持，直到真正写入 refill 寄存器；abort 可以屏蔽并清掉该请求。

顶层对 4 个 TWU 的仲裁先按 IUTLB/DTLB 分类，再按 TWU index 低优先。最终顶层输出仲裁：

```text
access fault > page fault > normal refill
```

访问异常源中：

```text
LSU bus error > 4 个 TWU access fault
```

没有专门防饥饿机制，但写回只需一个周期，PTW 中最多 9 个请求，且每个请求处理需要多个周期，长期饥饿不作为功能风险建模。

## 10. MAEE、Sysmap 与跨页降级

### 10.1 MAEE 开启

`MAEE=1` 时，PTW 直接使用 PTE 高位扩展属性 `{So,C,B,Sh,Sec}` 作为 refill `flg` 的 PMA/扩展属性部分。1G/2M/4K leaf 都不需要做 sysmap 跨页属性检查，也不做大页降级。

### 10.2 MAEE 关闭

`MAEE=0` 时，不使用 PTE 高位扩展属性，而是由 `ct_mmu_sysmap` 与 `sysmap.h` 中固定的 8 段物理地址区域和默认属性提供。sysmap 使用物理 PPN 所在 4K 块判断区域，输出 5-bit 属性 `{So,C,B,Sh,Sec}` 以及 one-hot hit。sysmap 区域不是运行时 CSR，而是编译期参数/头文件定义。

所有 page size 的 refill 扩展属性都必须来自 sysmap，包括：

1. 正常 4K leaf。
2. 正常 2M leaf。
3. 正常 1G leaf。
4. 1G 降级后的 2M。
5. 1G/2M 降级后的 4K。

MAEE 关闭时，4K 页虽然不做跨页降级，仍需要用最终物理 PPN 查询 sysmap 取得 PMA 属性。若 4K 是降级得到的，使用降级后的最终 PPN 查询。

### 10.3 Sysmap 假设

sysmap 不考虑无命中或多命中异常配置。设计假设每个 4K 物理块恰好落入一个区域；4K 页不可能跨 sysmap 区域边界，因为最小划分单位是 4K。

### 10.4 1G/2M 跨页检查公式

MAEE=0 且 leaf 为 1G/2M 时，需要检查该大页覆盖的首尾 4K PPN 是否落在同一个 sysmap 区域。

1G leaf：

```text
first_1G_ppn = {pte.ppn[2], 9'b0,    9'b0}
last_1G_ppn  = {pte.ppn[2], 9'h1ff,  9'h1ff}
```

2M leaf：

```text
first_2M_ppn = {pte.ppn[2], pte.ppn[1], 9'b0}
last_2M_ppn  = {pte.ppn[2], pte.ppn[1], 9'h1ff}
```

只比较 4K PPN 所在 sysmap 区域，offset 不参与，因为 sysmap 最小块按 4K。

### 10.5 不降级

如果首尾 4K PPN 命中同一个 sysmap 区域，则不降级，保持原 page size 与 PPN。refill 扩展属性取尾地址 sysmap 属性；因为首尾同区，取首地址或尾地址属性等价。

### 10.6 1G 降级为 2M

1G leaf 首尾 sysmap 区域不同，先降级为 2M：

```text
new_ppn_2M = {pte.ppn[2], vpn[1], 9'b0}
new_page_size = 2M
```

随后对降级后的 2M 再做首尾 sysmap 区域检查。如果该 2M 不跨区域，则最终 refill page size 为 2M，PPN 为 `{pte.ppn[2], vpn[1], 9'b0}`，扩展属性取该 2M 尾地址 sysmap 配置。

### 10.7 1G 降级为 4K

如果 1G 先降级为 2M 后，该 2M 仍跨 sysmap 区域，则继续降级为 4K：

```text
new_ppn_4K = {pte.ppn[2], vpn[1], vpn[0]}
new_page_size = 4K
```

最终不再访问下一级页表；权限、`G/U/X/W/R/V/A/D/RSW` 等仍来自原始 1G leaf PTE，只修改 PPN、page size、扩展属性。

### 10.8 2M 降级为 4K

2M leaf 首尾 sysmap 区域不同，降级为 4K：

```text
new_ppn_4K = {pte.ppn[2], pte.ppn[1], vpn[0]}
new_page_size = 4K
```

最终不再访问第三级页表；权限、`G/U/X/W/R/V/A/D/RSW` 等仍来自原始 2M leaf PTE，只修改 PPN、page size、扩展属性。

注意：1G/2M 对齐错误会先触发 page fault，不会进入跨页降级流程。因此早期 `{pte.ppn[2], vpn[1], pte.ppn[0]}` 的描述在对齐成立时等价于 `{pte.ppn[2], vpn[1], 9'b0}`，最终规范采用后者。

## 11. Reset、satp/PMP 变化与 Abort

### 11.1 reset

reset 清空 PDE cache，并 flush/清空 in-flight PTW 请求、TWU 六级流水、mbuf entry、refill 寄存器、page fault 寄存器、access fault 寄存器。

### 11.2 satp 改变

satp 任意字段改变会生成 PDE cache 清空激励，使第一级和第二级 PDE cache 所有 entry valid 在下一拍拉低。satp 改变本身不 flush in-flight PTW，不清 TWU/mbuf/refill/异常寄存器，也不要求 L2TLB 因此重发请求。

satp 改变通常伴随后续 `tlboper_ptw_abort`，但不保证同拍。若 satp.asid 或 satp.ppn 改变但没有 abort，旧 walk 可能与新 satp 交错；UVM 可以约束不生成该场景。

### 11.3 PMP 配置改变

PMP 配置改变由硬件自动触发 PDE cache 清空，但不 abort/flush in-flight PTW。PMP 改变后旧 in-flight walk 若返回非叶子 PTE 且无 page fault、未被 abort/flush 屏蔽，仍允许更新 PDE cache。

### 11.4 `tlboper_ptw_abort`

`tlboper_ptw_abort` 是 LSU TLB operation 窗口产生的单周期脉冲，用于避免 TLB invalidate/shootdown 与 PTW refill 并发导致旧翻译被重新装入。abort 行为：

1. 当拍清空全部 PDE cache。
2. 冲刷 PDE cache lookup 中的请求。
3. 阻止 PDE cache update 写入。
4. 清空 4 个 TWU 六级流水 valid。
5. 清空 mbuf entry valid。
6. 屏蔽 normal refill。
7. 清空尚未进入最终顶层授权路径的 page fault/access fault。
8. 清空 refill/page fault/access fault 待写路径。

只有 abort 到来前已经进入异常寄存器，并且 abort 当拍正在顶层仲裁且获得授权的异常可以上报。未进入异常寄存器、未获顶层授权的异常被冲刷。新形成异常不可见，包括 abort 同拍 LSU 返回 bus error。

### 11.5 Abort 与 LSU outstanding

LSU request valid 在 abort 前一拍已经为 1，是判断是否必须继续保持 LSU 请求等待返回的边界。

1. 如果 abort 到来时请求刚准备发出第一拍，前一拍 LSU request valid 不是 1，则该请求可直接屏蔽，不需要等待 LSU。
2. 如果 abort 前一拍 LSU request valid 已经为 1，则 PTW 必须继续保持 LSU request valid 和 PA 稳定，直到 LSU data valid 返回，避免破坏 LSU 接口语义。
3. 返回普通数据必须丢弃，不进入 CHK、不更新 PDE cache、不产生 refill。
4. abort 同拍 LSU data valid 返回普通数据，也丢弃。
5. abort 同拍 LSU data valid 返回 bus error，不上报，因为该 error 需要写 mbuf access exception register，而 abort 会阻止写入。
6. 若 LSU bus error 在 abort 到来前已经写入 mbuf access exception register，并在 abort 当拍参与顶层 access fault 仲裁且获授权，则可以上报。
7. PTW ready 在 flush 和必要的 outstanding 等待完成后恢复；L2TLB buffer 重发未完成请求。若某异常已在 abort 当拍成功上报并完成对应 L2TLB entry，该 entry 不会再次重发。

## 12. 完整处理流程

本节按 UVM 场景覆盖需求列出完整流程。`n` 表示 LSU 返回延迟。所有流程中 `vpn/type/id` 全程携带，最终按 `type/id` 返回或释放 miss buffer。

### 12.1 PDE cache 未命中，1G，无异常，不跨页

1. T0：L2TLB 拉高 PTW 请求，字段为 `vpn/type/id`。
2. T1：PTW accept 后进入 PDE cache，同时查第一级和第二级 PDE cache，均 miss；按 hash 选中目标 TWU。
3. T2：进入 `fst_pmp`，生成 `fst_pmp_pa={regs_ptw_satp_ppn,vpn[26:18],3'b0}`，PMP 组合返回 `pmp_mmu_flg`。
4. `fst_pmp` 按原始 type 做 PMP deny 判断；若通过，向 mbuf 写入 `pa/vpn/type/id/twu_idx/lvl=fst`。
5. mbuf entry 写入后，在 LSU 空闲时向 LSU 发 PTE 读取请求；LSU request valid 保持，PA 稳定，直到 data valid 返回。
6. LSU 返回第一级 PTE；若 `fst_chk` ready，数据进入 `fst_chk`；若不 ready，数据保存在 mbuf entry，置 `get`，等待 ready。
7. `fst_chk` 检查 PTE，发现第一级 PTE 是 1G leaf，且无 page fault。
8. 若 `MAEE=1`，直接以 PTE 扩展属性生成 refill；若 `MAEE=0`，还需按 12.4/12.6 的 sysmap 检查确定是否降级。当前“不跨页”场景假定无需降级。
9. 写 normal refill 寄存器，page size=`3'b100`，PPN 为 leaf PTE PPN，global 为 leaf G，flg 含扩展属性/RSW/D/A/U/X/W/R/V。
10. 顶层仲裁后返回：IUTLB -> L1ITLB+L2TLB；Load/Store -> L1DTLB+L2TLB；PFU -> L2TLB。释放 L2TLB miss buffer。

### 12.2 PDE cache 未命中，2M，无异常，不跨页

1. T0-Tn：先按 12.1 的第一级流程完成 `fst_pmp -> mbuf -> LSU -> fst_chk`。
2. `fst_chk` 检查第一级 PTE 为非叶子，且无 page fault。
3. mbuf 返回该非叶子 PTE 时，若未被 abort/flush 屏蔽，更新第一级 PDE cache，tag=`vpn[2]`，data=`fst_pte.ppn`。
4. `fst_chk` 将请求送入 `scd_pmp`，携带 `fst_pte.ppn`。
5. `scd_pmp` 生成 `scd_pmp_pa={fst_pte.ppn,vpn[17:9],3'b0}`，PMP 通过后写 mbuf。
6. mbuf 发 LSU 请求读取第二级 PTE，valid/PA 保持至返回。
7. LSU 返回后进入 `scd_chk` 或先保存在 mbuf entry 等待 ready。
8. `scd_chk` 检查第二级 PTE 为 2M leaf，且无 page fault。
9. 若 `MAEE=1` 直接 refill；若 `MAEE=0` 做 2M sysmap 首尾检查，当前“不跨页”场景假定不降级。
10. 写 refill，page size=`3'b010`，PPN 为 leaf PTE PPN，按 type/id 返回目标。

### 12.3 PDE cache 未命中，4K，无异常，不跨页

1. 先完成第一级 `fst_pmp -> mbuf -> LSU -> fst_chk`，第一级 PTE 非叶子无 page fault，更新第一级 PDE cache。
2. 进入 `scd_pmp`，地址 `{fst_pte.ppn,vpn[17:9],3'b0}`，PMP 通过后写 mbuf 并访问 LSU。
3. 第二级 PTE 返回后进入 `scd_chk`。
4. `scd_chk` 检查第二级 PTE 为非叶子且无 page fault；mbuf 返回时更新第二级 PDE cache，tag=`{vpn[2],vpn[1]}`，data=`scd_pte.ppn`。
5. 进入 `thd_pmp`，地址 `{scd_pte.ppn,vpn[8:0],3'b0}`，PMP 通过后写 mbuf 并访问 LSU。
6. 第三级 PTE 返回后进入 `thd_chk`。
7. `thd_chk` 检查第三级 PTE 为 4K leaf 且无 page fault。
8. `MAEE=1` 时使用 PTE 扩展属性；`MAEE=0` 时查询最终物理 PPN 的 sysmap 属性。
9. 写 refill，page size=`3'b001`，按 type/id 返回目标。

### 12.4 MAEE=0，1G 跨页后降级为 2M

1. 先按 12.1 走到 `fst_chk`，得到 1G leaf，page fault 检查通过。
2. 因 `cp0_mmu_maee=0`，`fst_chk` 不直接 refill，而是请求进入跨页检查状态机。
3. 状态机查询 1G 首尾 4K PPN：`first={pte.ppn[2],9'b0,9'b0}`，`last={pte.ppn[2],9'h1ff,9'h1ff}`。
4. sysmap 当拍返回首尾区域；若不同区域，判定 1G 跨区域。
5. 降级为 2M：`ppn={pte.ppn[2],vpn[1],9'b0}`，page size 改为 `2M`。
6. 对该 2M 再查询首尾 4K PPN；本场景假设首尾同一区域。
7. 停止降级，扩展属性取该 2M 尾地址 sysmap 属性。
8. 权限、A/D/G/U/X/W/R/V、RSW 仍来自原始 1G leaf PTE。
9. 跨页状态机发 normal refill 请求；写 refill 寄存器后经顶层仲裁返回。

### 12.5 MAEE=0，1G 跨页后降级为 4K

1. 先走到 `fst_chk` 得到 1G leaf，无 page fault。
2. 1G 首尾 sysmap 区域不同，先降级为 2M：`ppn={pte.ppn[2],vpn[1],9'b0}`。
3. 对降级后的 2M 首尾 4K PPN 再查 sysmap；本场景假设仍不同区域。
4. 继续降级为 4K：`ppn={pte.ppn[2],vpn[1],vpn[0]}`，page size=`4K`。
5. 不再访问第二级或第三级页表；这不是重新 walk，而是基于原 1G leaf PTE 修改最终 PPN/page size。
6. 扩展属性取最终 4K PPN 对应 sysmap 属性；其他权限字段来自原 1G leaf PTE。
7. 写 refill 寄存器，顶层仲裁后按原 type/id 返回。

### 12.6 MAEE=0，2M 跨页后降级为 4K

1. 先按 12.2 走到 `scd_chk`，得到 2M leaf，无 page fault。
2. 因 `MAEE=0`，进入跨页检查状态机。
3. 查询 2M 首尾 4K PPN：`first={pte.ppn[2],pte.ppn[1],9'b0}`，`last={pte.ppn[2],pte.ppn[1],9'h1ff}`。
4. 首尾区域不同，降级为 4K：`ppn={pte.ppn[2],pte.ppn[1],vpn[0]}`，page size=`4K`。
5. 不再访问第三级页表；权限字段来自原 2M leaf PTE。
6. 扩展属性取最终 4K PPN 对应 sysmap 属性。
7. 写 refill 并返回。

### 12.7 MAEE=0，1G/2M 跨页检查但不降级

1. 1G 在 `fst_chk` 检出 leaf；2M 在 `scd_chk` 检出 leaf。
2. 因 `MAEE=0`，进入跨页检查状态机。
3. 按 1G 或 2M 公式查询首尾 4K PPN 所在 sysmap 区域。
4. 如果首尾同一区域，page size 和 PPN 不变。
5. 扩展属性取尾地址 sysmap 属性；因为首尾同区，取首尾等价。
6. 状态机发 refill 请求，写 normal refill 寄存器后经顶层仲裁返回。

### 12.8 MAEE=0，4K leaf sysmap refill

1. 按 12.3 走到 `thd_chk`，得到 4K leaf，无 page fault。
2. 4K 不做跨页降级，但 `MAEE=0` 仍必须查 sysmap。
3. 将最终物理 PPN 写入 `no_maee_ppn` 或等价状态，下一拍送 sysmap。
4. sysmap 当拍返回 5-bit `{So,C,B,Sh,Sec}`。
5. refill 扩展属性使用 sysmap；G 单独作为 global/tag；RSW 和 D/A/U/X/W/R/V 进入 `flg`。
6. 写 refill 寄存器，经顶层仲裁返回。

### 12.9 第一级 PMP access fault

1. 请求 PDE cache miss 后进入目标 TWU。
2. `fst_pmp` 生成根级 PTE 地址 `{regs_ptw_satp_ppn,vpn[26:18],3'b0}`。
3. PMP deny 命中。
4. 请求不写 mbuf，不发 LSU，不进入 `fst_chk`。
5. `fst_pmp` 发写 access fault 寄存器请求，携带 `type/id`。
6. 顶层 access fault 仲裁后返回源端，释放 L2TLB miss buffer。

### 12.10 第二级 PMP access fault

1. 第一级 PMP 通过，LSU 返回第一级 PTE。
2. `fst_chk` 检查第一级 PTE 为非叶子且无 page fault。
3. 进入 `scd_pmp`，生成 `{fst_pte.ppn,vpn[17:9],3'b0}`。
4. PMP deny 命中。
5. 请求不写 mbuf、不读取第二级 PTE、不进入 `scd_chk`。
6. 写 access fault 寄存器，顶层仲裁后返回。

### 12.11 第三级 PMP access fault

1. 第一级和第二级均成功，`scd_chk` 得到第二级非叶子且无 page fault。
2. 进入 `thd_pmp`，生成 `{scd_pte.ppn,vpn[8:0],3'b0}`。
3. PMP deny 命中。
4. 请求不访问第三级 PTE，不进入 `thd_chk`。
5. 写 access fault 寄存器，顶层仲裁后返回。

### 12.12 第一级 CHK page fault

1. `fst_pmp` PMP 通过，请求经 mbuf/LSU 返回第一级 PTE。
2. 数据进入 `fst_chk`。
3. `fst_chk` 按本设计 page fault 规则检出异常，例如 `V=0`、write-only、1G 对齐错误、leaf 权限/A/D/U/S 错误等。
4. 写 page fault 寄存器，携带 `type/id`。
5. 不 refill，不进入 `scd_pmp`。
6. 顶层 page fault 仲裁后返回源端并释放 L2TLB miss buffer。

### 12.13 第二级 CHK page fault

1. 第一级 PTE 为非叶子无异常，进入 `scd_pmp`。
2. `scd_pmp` PMP 通过，mbuf/LSU 返回第二级 PTE。
3. 数据进入 `scd_chk`。
4. `scd_chk` 检出 page fault，例如 `V=0`、write-only、2M leaf 对齐错误、leaf 权限/A/D/U/S 错误等。
5. 写 page fault 寄存器，不进入 `thd_pmp`。
6. 顶层仲裁后返回。

### 12.14 第三级 CHK page fault

1. 前两级均为非叶子无异常。
2. `thd_pmp` PMP 通过，mbuf/LSU 返回第三级 PTE。
3. 数据进入 `thd_chk`。
4. 如果第三级 PTE 仍为非叶子形态 `R=0 && X=0`，触发 page fault。
5. 如果第三级 leaf 权限、A/D、U/S、V、write-only 等检查失败，也触发 page fault。
6. 写 page fault 寄存器，顶层仲裁后返回。

### 12.15 第一级 PDE cache 命中，最终 2M

1. T0：L2TLB 请求拉高。
2. T1：PDE cache 并行 lookup，第一级命中，第二级未命中或未选中。
3. 跳过 `fst_pmp/fst_chk`，携带第一级 PDE cache data PPN。
4. 进入 `scd_pmp`，生成 `{pde1.ppn,vpn[17:9],3'b0}`。
5. PMP 通过后写 mbuf，mbuf 发 LSU 读取第二级 PTE。
6. LSU 返回后进入 `scd_chk`。
7. `scd_chk` 检查第二级 PTE 为 2M leaf 且无 page fault。
8. 按 MAEE 规则直接 refill 或 sysmap 检查后 refill，page size=`2M`。
9. 顶层仲裁后返回。

### 12.16 第一级 PDE cache 命中，最终 4K

1. 第一级 PDE cache 命中，跳过第一级流水。
2. 进入 `scd_pmp`，地址 `{pde1.ppn,vpn[17:9],3'b0}`。
3. `scd_pmp -> mbuf -> LSU -> scd_chk` 读取并检查第二级 PTE。
4. `scd_chk` 检查第二级 PTE 为非叶子且无 page fault。
5. mbuf 返回该第二级非叶子 PTE 时，更新第二级 PDE cache，tag=`{vpn[2],vpn[1]}`，data=`scd_pte.ppn`。
6. 进入 `thd_pmp`，地址 `{scd_pte.ppn,vpn[8:0],3'b0}`。
7. `thd_pmp -> mbuf -> LSU -> thd_chk` 读取第三级 PTE。
8. `thd_chk` 得到 4K leaf 且无 page fault。
9. 按 MAEE 规则生成 4K refill 并返回。

### 12.17 第二级 PDE cache 命中，最终 4K

1. PDE cache lookup 命中第二级；若第一级也命中，仍选择第二级。
2. 跳过 `fst_pmp/fst_chk/scd_pmp/scd_chk`。
3. 直接进入 `thd_pmp`，使用第二级 PDE cache data PPN 生成 `{pde2.ppn,vpn[8:0],3'b0}`。
4. PMP 通过后写 mbuf，发 LSU 读取第三级 PTE。
5. LSU 返回后进入 `thd_chk`。
6. `thd_chk` 检查 4K leaf 且无 page fault。
7. 写 refill 寄存器，顶层仲裁后返回。

### 12.18 LSU bus error access fault

1. mbuf entry 已向 LSU 发出页表访问，entry `on` 表示 outstanding。
2. LSU 返回 bus error。
3. 请求不进入 CHK，不做 PTE page fault 检查。
4. mbuf 使用 entry 中的 `type/id` 发写 mbuf access exception register 请求。
5. 若寄存器/仲裁暂不可用，置 `lsu bus err flop`，entry 保持 valid，不释放。
6. 写异常寄存器成功后释放 entry。
7. 顶层 access fault 仲裁中，LSU bus error 优先于 4 个 TWU access fault。
8. access fault 返回源端，释放 L2TLB miss buffer。

### 12.19 Abort 且 LSU 有 outstanding

1. `tlboper_ptw_abort` 单周期到来。
2. 当拍清 PDE cache lookup/update、4 个 TWU 六级流水、mbuf valid、refill/page fault/access fault 待写路径；PDE cache 全部 invalid。
3. normal refill 全部屏蔽。
4. abort 前已经进入异常寄存器且当拍顶层仲裁获授权的异常可上报；其他异常被冲刷。
5. 如果 LSU request valid 在 abort 前一拍已经为 1，继续保持 LSU request valid 和 PA，直到 LSU data valid 返回。
6. 返回普通数据丢弃，不进 CHK、不更新 PDE cache、不产生 refill。
7. abort 同拍 LSU 返回 bus error 也不上报。
8. outstanding 返回并丢弃后，PTW ready 恢复；L2TLB 重发未完成请求。

### 12.20 PFU 成功

1. PFU 请求 `type=3'b100`，字段仍为 `vpn/type/id`。
2. PDE cache、xbar、PMP、mbuf、LSU、CHK 流程与普通 walk 相同，可以最终得到 1G/2M/4K。
3. PMP 按 load 类权限检查，即看 `pmp_mmu_flg[0]`，并受 M-mode L-bit skip 规则影响。
4. PTE 权限按 PFU 独立规则：要求 `A=1`，不要求 `R=1`，不要求 `MXR&&X`，不检查 `D`。
5. 成功写 normal refill 寄存器。
6. PFU 只 refill L2TLB，不 refill L1ITLB/L1DTLB。
7. `id[5:3]` 释放 L2TLB miss buffer；`id[2:0]` 不使用。

### 12.21 PFU 异常

1. PFU walk 中任一级 PMP deny，产生 access fault。
2. PFU walk 中任一级 CHK page fault，产生 page fault。
3. 异常寄存器只携带 `type/id` 和异常类别，不产生独立 prefetch cause。
4. 顶层仲裁后异常返回给 L2TLB。
5. L2TLB 将异常上报 LSU prefetch 端口，并释放 L2TLB miss buffer。

### 12.22 satp/PMP 改变清 PDE cache

1. satp 任意字段改变，或 PMP 配置改变，生成 PDE cache 清空激励。
2. 下一拍第一级和第二级 PDE cache 所有 entry valid 拉低。
3. 不 flush in-flight PTW 请求，不清 TWU/mbuf/refill/异常寄存器。
4. L2TLB 不需要因此重发。
5. 清空后旧 in-flight walk 若返回非叶子 PTE 且无 page fault、未被 abort/flush 屏蔽，仍允许重新更新 PDE cache。
6. 实际 satp 改变通常伴随 `tlboper_ptw_abort`，但不保证同拍；UVM 可以约束 satp.asid/satp.ppn 不在无 abort 下改变。

### 12.23 Load/Store/PFU，`MPRV=1 && MPP=M`

1. 该组合只影响 data/PFU 类访问，不影响 fetch/IFU。
2. 对 load/store/PFU，该组合使 data effective privilege 为 M，data MMU 关闭，物理地址直接等于虚拟地址。
3. 因为 data/PFU 不产生 DTLB/L2TLB miss，也不会产生 `l2tlb_ptw_req`，所以 PDE cache、xbar、PMP、mbuf、LSU、CHK 等 PTW source 流程均不可达。
4. UVM 不得构造或期待该组合下的 load/store/PFU PTW source refill/access-fault/page-fault；若 monitor 观察到此类 PTW accept，应归类为非法上游输入或 RTL/TB 集成错误，而不是合法 PTW 功能覆盖。
5. Fetch/IFU 在同一 CSR 配置下仍按真实流水线 privilege 判断是否进入 PTW：真实 `S/U` fetch 可进入 PTW，真实 `M` fetch 不进入 PTW。
6. PTW 内部 machine-mode PMP skip 规则仍只适用于合法进入 PTW 的请求上下文；不能用 `priv=S/U, MPRV=1, MPP=M` 的 data/PFU top-level source 请求来关闭该规则。

## 13. UVM 建模规则

### 13.1 Reference Model 与 Scoreboard

本节定义 PTW source-side reference model、scoreboard、consumer scoreboard 和现有 checker 的分工。第 13.1 节是后续实现 `mmu_ref_model.svh`、PTW refill/exception monitor、PDE cache monitor、scoreboard 和 signoff report 的可执行规格；如果现有 testbench 代码与本节冲突，以本节为准。

#### 13.1.1 Checker 分层与职责边界

PTW 验证必须拆成三层，不能用下游 L1DTLB/L2TLB 结果替代 PTW 源头检查：

| Checker | 必须检查 | 不能关闭 |
| --- | --- | --- |
| `ptw_source_ref_model` | 按本文 §1-§12 计算 PTW 请求的页表访问、PMP、PTE page fault、PDE cache、MAEE/sysmap/degrade、refill/exception 期望结果。 | 固定周期、逐拍 ready/valid、PLRU 位级更新、下游 L1 hit 行为。 |
| `ptw_source_sb` | 从 PTW/L2TLB 请求和 PTW 输出 monitor 捕获事务，按 `{type,id}` 匹配 ref model 期望，比较 `vpn/asid/page_size/ppn/global/flg/type/id/expt_kind/target`。 | IFU/LSU 最终 PA 正确性本身；L1DTLB busy/wakeup/MB 调度语义。 |
| `pde_cache_model/monitor` | 维护或观测 PDE cache lookup/update/clear，给 ref model 提供命中级别和 skip-level 依据，检查双命中选二级、update 条件、clear no-flush。 | 通用 TLB entry 替换、L2TLB bank 替换。 |
| `mmu_translation_sb` | IFU/LSU consumer-side 端到端 VA->PA/fault 比较，证明 PTW/L1/L2 输出被最终消费。 | PTW source-side 的 PTE/PMP/MAEE/PDE/abort 源头正确性；不能关闭 `PTW-FLOW-*` 的源头行为。 |
| `mmu_l1dtlb_spec_sb` | L1DTLB consumer-side refill、exception CAM、replay、preselect、busy/wakeup 等局部协议。 | PTW refill 字段生成、PFU 只 refill L2TLB、PMP/PTE fault 源头判断。 |
| `mmu_credit_sb` | outstanding、quiescent、drain、credit/no-overwrite 等系统 liveness 和资源约束。 | PTW 功能 golden result。 |
| SVA/monitor | ready/valid 保持、xbar hash、LSU single outstanding、仲裁优先级、abort 边界、PDE lookup/update race 等周期级性质。 | 事务级 leaf 权限、PTE 数据字段、sysmap/degrade golden result 的完整替代。 |

因此，关闭一个 PTW 测试点至少需要 `ptw_source_ref_model + ptw_source_sb` 或等价 source-side monitor/SVA 直接证据；`mmu_translation_sb` 和 `mmu_l1dtlb_spec_sb` 只能作为 consumer-side evidence。

#### 13.1.2 Reference Model 输入

PTW source-side reference model 的输入必须覆盖所有会影响 PTW 结果的动态状态。模型不得只用 IFU/LSU 最终 VA->PA transaction 反推 PTW 行为。

| 输入类别 | 必须字段 | 采样/使用规则 |
| --- | --- | --- |
| PTW request | `vpn[26:0]`、`type[2:0]`、`id[5:0]`、accept cycle、source | accept 时建立 in-flight request；匹配键为 `{type,id}`，并保存 `vpn` 用于后续各级地址计算。 |
| SATP | active satp PPN、ASID、mode/sel | `regs_ptw_satp_ppn` 在 `fst_pmp_pa` 生成时采样；ASID 在 refill 输出当拍采样；Bare/M-mode 不应进入 PTW。 |
| CSR/context | `MXR`、`SUM`、真实 privilege、`MPRV`、`MPP`、`MAEE` | MXR/SUM/effective privilege 在 CHK 使用点采样；MAEE 在 leaf/sysmap 入口使用；进入 sysmap/degrade 后不因后续 MAEE 改变回退。 |
| PMP state | 每个 PTW PMP port 的 `pmp_mmu_flg[3:0]`、grant/deny/wait observation | PMP 检查对象是 PTE 读取 PA，而不是最终翻译 PA；deny 按原始 request type 和 effective mode 计算。 |
| Page table memory | 每个 PTE PA 对应的 64-bit raw PTE、可选 bus error 注入 | 普通返回进入 CHK；bus error 直接产生 access fault，不做 PTE/page fault/refill/PDE update。 |
| Sysmap | 8 region hit、region flg、默认 flg、one-hot 假设 | MAEE=0 时所有 page size 的扩展属性来自 sysmap；无命中/多命中属于非法 stimulus，可约束或单独报 illegal。 |
| Abort/reset/tlboper | reset、`tlboper_ptw_abort`、satp change、PMP config change | reset/abort flush in-flight；satp/PMP change 只清 PDE cache，不 flush in-flight。 |
| DUT whitebox observation | PTW 请求/完成、arb、PMP、sysmap、PDE、mbuf/LSU、L1/L2 refill probes | 用于 scoreboard 匹配、调试、SVA/cover；不能把 DUT CHK 结论当 golden result。 |

Reference model 必须显式区分两类 API：

1. `translate()` 或现有 IFU/LSU end-to-end API：可继续服务 `mmu_translation_sb`，比较最终 PA/fault；该 API 若保留 passthrough/M-mode/Bare 行为，必须标记为 consumer model。
2. `predict_ptw(req, event_stream/context)` 或等价 PTW API：只服务 PTW source-side，输入为 `vpn/type/id` 和 PTW 上下文，不做 Bare passthrough，不使用最终 PA 的 PMP 检查，不把 PFU 当普通 load 权限建模。

#### 13.1.3 Reference Model 输出

PTW source-side model 对每个 accepted request 必须生成一个完整期望对象。建议数据结构如下，字段名可按代码风格调整，但语义必须完整：

```systemverilog
typedef enum {PTW_EXP_REFILL, PTW_EXP_PAGE_FAULT,
              PTW_EXP_ACCESS_FAULT, PTW_EXP_DROPPED} ptw_exp_kind_e;

typedef struct {
  logic [2:0] type;
  logic [5:0] id;
} ptw_req_key_t;

typedef struct {
  bit         valid;
  logic [26:0] vpn;
  logic [2:0]  type;
  logic [5:0]  id;
  time        accept_time;
  int unsigned source;
  logic [2:0] l2_eid;
  logic [2:0] l1_eid;
} ptw_req_ctx_t;

typedef struct {
  int unsigned level;          // fst/scd/thd
  logic [39:0] pte_addr;
  logic [27:0] base_ppn;
  logic [63:0] pte_raw;
  bit          pmp_checked;
  bit          pmp_deny;
  bit          bus_error;
  bit          leaf;
  bit          page_fault;
  bit          nonleaf_update;
} ptw_level_obs_t;

typedef struct {
  ptw_exp_kind_e kind;
  logic [2:0]    type;
  logic [5:0]    id;
  logic [26:0]   vpn;
  logic [15:0]   asid;
  logic [2:0]    page_size;
  logic [27:0]   ppn;
  bit            global;
  logic [13:0]   flg;          // exact width may follow RTL, but must include {So,C,B,Sh,Sec}, RSW, D/A/U/X/W/R/V and exclude G.
  bit            target_l2tlb;
  bit            target_l1itlb;
  bit            target_l1dtlb;
  bit            target_pfu;
  string         fault_kind;
  string         drop_reason;
  ptw_level_obs_t levels[$];
} ptw_expected_rsp_t;
```

`kind` 的含义：

1. `PTW_EXP_REFILL`：正常 refill。必须比较 `vpn/asid/page_size/ppn/global/flg/type/id/target`。
2. `PTW_EXP_PAGE_FAULT`：CHK page fault。必须比较 `type/id`、page-fault 类别和返回目标；不得期待 refill/PDE update。
3. `PTW_EXP_ACCESS_FAULT`：PMP deny 或 LSU bus error。必须比较 `type/id`、access-fault 类别和返回目标；不得期待 CHK/page fault/refill。
4. `PTW_EXP_DROPPED`：reset/abort flush、abort 后 LSU ordinary data discard、abort 同拍新 bus error 被屏蔽等。必须检查没有正常 refill 或新异常可见；若 L2TLB 后续重发，应作为新 request 重新建模。

#### 13.1.4 PTW Request 与 Matching 规则

Scoreboard 只做事务级最终匹配，不设固定周期上限。匹配键固定为：

```text
{type, id}
```

匹配规则：

1. 每个 PTW accept 生成一个 expected transaction，放入 associative map 或 per-key queue。
2. 同一个 `{type,id}` 在旧请求完成或被 abort/drop 前再次 accept 属于非法 stimulus；scoreboard 应报 illegal 或 fatal，除非测试明确验证上游非法输入。
3. IUTLB/fetch `id[2:0]` 固定/无效；PTW/L2TLB 仍携带完整 `id[5:0]`，consumer-side IUTLB 比较时忽略低 3 bit 的 L1DTLB entry 意义。
4. Load/Store 使用 `id[5:3]` 释放 L2TLB miss buffer，使用 `id[2:0]` 定位 L1DTLB miss entry；scoreboard 必须同时检查 L2 和 L1D consumer target。
5. PFU 使用 `type=3'b100`，成功只 refill L2TLB，不期待 L1ITLB/L1DTLB refill；异常返回 L2TLB/PFU 路径并释放 `id[5:3]`。
6. 返回顺序允许被 TWU、mbuf、LSU 延迟和顶层仲裁重排；scoreboard 不要求按 accept 顺序完成，只按 `{type,id}` 匹配。
7. 同周期多个候选输出的精确仲裁顺序交给 SVA/monitor；scoreboard 只要求最终 visible output 与对应 expected 一致。
8. 对于 access fault/page fault/refill 同时存在的输出类，最终 visible class 必须服从 `access fault > page fault > normal refill`；该优先级可由 SVA 做周期检查，scoreboard 在匹配时仍不得接受低优先级错误结果。

PTW request accept 事件必须用真实 ready/valid 握手定义，而不是只看 `l2tlb_ptw_req` 电平。当前 RTL 语义下可用：

```text
ptw_req_accept = l2tlb_ptw_req && ptw_jtlb_ready
```

若后续接口改名，应保持“request valid 且 PTW ready”的语义。`l2tlb_ptw_req=1` 但 `ptw_jtlb_ready=0` 时，scoreboard 不得创建新 expected；monitor/SVA 应检查该请求的 `vpn/type/id` 保持，直到 accept 或上游撤销于合法 flush/abort 场景。

PTW visible completion 事件必须区分三类：

| Completion class | Visible 条件 | Scoreboard 动作 |
| --- | --- | --- |
| normal refill | `ptw_l2tlb_ref_data_vld` 或 `arb_ptw_grant` 对应 PTW refill grant | 按 `{type,id}` 找到 `PTW_EXP_REFILL`，比较 tag/data/target。 |
| page fault | `ptw_l2tlb_ref_pgflt` | 按 `{type,id}` 找到 `PTW_EXP_PAGE_FAULT`，比较 fault class/target，不比较 refill data。 |
| access fault | `ptw_l2tlb_ref_acc_err` | 按 `{type,id}` 找到 `PTW_EXP_ACCESS_FAULT`，比较 fault class/target，不比较 refill data。 |

`ptw_l2tlb_cmplt` 是上述三类 completion 的 OR，只能用于触发匹配入口；不能单独说明 completion class。一个 completion 周期中若 class bit 多热，应由 SVA 报协议错误；scoreboard 不应任意择一。

#### 13.1.4.1 PTW Memory Channel 关联规则

PTW source-side model 必须把外部 PTE memory channel 纳入 transaction trace。现有 `ptw_mem_agent` 已有 `ap_req/ap_rsp/ap_drop`，scoreboard 应连接或等价实现：

1. `ap_req` 在 `mmu_lsu_data_req_accept` 时记录一次已接受 PTE read，字段至少包括 PTE PA、size、accept cycle。
2. `ap_rsp` 在 `lsu_mmu_data_vld || lsu_mmu_bus_error` 时记录一次 response，字段包括 PTE PA、raw PTE、bus_error、response cycle。
3. PTW memory channel 是 strict serial single-outstanding；若在 response 前再次 accept，属于 protocol error。
4. 对每个 expected level，scoreboard 应把 ref model 计算的 `pte_addr` 与实际 `ap_req.addr` 对齐。PDE hit 跳过的级别不得出现对应 memory request。
5. 普通 response 的 `pte_data` 必须作为 CHK raw PTE 输入保存到 `ptw_level_obs_t.pte_raw`；不能只从 shadow page table 重读，否则 bus error/late response/动态 PTE 修改会被掩盖。
6. bus error response 只产生 access fault expected，不得解码该周期 `pte_data`，不得允许后续 CHK/page fault/refill/PDE update。
7. reset drop 只能清除 memory-channel pending；PTW source-side request 是否 drop 仍按 reset/abort 事务规则处理。
8. `PTW_RSP_OOO` 或任何 out-of-order response 不是合法 PTW 协议；测试中出现时必须标 illegal/obsolete，不能作为正向功能关闭。

#### 13.1.5 Page Table Walk Golden Algorithm

PTW source-side model 必须按本文 §5、§6、§10、§11 的流程逐级执行，而不是调用一个只返回最终 PA 的简化 Sv39 函数。每级算法：

1. 根据 PDE cache lookup 结果决定起始级别：miss 从 `fst` 开始；一级 PDE hit 从 `scd` 开始；二级 PDE hit 从 `thd` 开始；双命中选择二级。
2. 对每个实际访问的级别生成 PTE PA：
   - `fst_pmp_pa={regs_ptw_satp_ppn, vpn[26:18], 3'b0}`
   - `scd_pmp_pa={prev_nonleaf_ppn, vpn[17:9], 3'b0}`
   - `thd_pmp_pa={prev_nonleaf_ppn, vpn[8:0], 3'b0}`
3. 先对 PTE PA 做 PMP 检查。PMP deny 时立即生成 `PTW_EXP_ACCESS_FAULT`，不读 PTE、不进入 CHK、不 page fault、不 refill、不更新 PDE cache。
4. PMP allow 后，经 mbuf/LSU 读取 64-bit raw PTE。普通 data 返回后进入对应 CHK；bus error 返回时生成 `PTW_EXP_ACCESS_FAULT`，不进入 CHK。
5. CHK 先按本设计 page fault 规则判断；page fault 时生成 `PTW_EXP_PAGE_FAULT`，不进入下一级、不 refill。
6. CHK 无 fault 且 PTE 为 non-leaf 时，按 PDE update 条件更新参考 PDE cache，并进入下一级 PMP；第三级 non-leaf 是 page fault。
7. CHK 无 fault 且 PTE 为 leaf 时，按 leaf level 得到初始 page size/PPN，然后执行 MAEE/sysmap/degrade，最后生成 `PTW_EXP_REFILL`。

模型不得加入以下标准 Sv39 额外检查：

1. high reserved bit `PTE[58:38]` 非 0 fault。
2. RSW fault。
3. strong-order/fetch meets strong order fault。
4. `W=1,R=0` 一律 fault 的标准 reserved 规则；本设计必须使用 `W && !(R || (MXR && X))`。
5. Store 额外要求 `R=1`；本设计 store leaf 权限只要求 `W=1`、`D=1`、`A=1` 和通用检查。
6. PFU 按 load 检查 R/MXR/X/D；本设计 PFU 不要求 R/MXR/X/D，但仍检查 V、write-only、U/S、A、1G/2M 对齐。

#### 13.1.6 PTE Decode 与 Refill 字段规则

Reference model 必须保存 raw PTE，并从 raw PTE 派生以下字段：

| 字段 | 来源 | 检查规则 |
| --- | --- | --- |
| `leaf` | `V && (R || X)` | W alone 不是 leaf。 |
| `write_only_fault` | `W && !(R || (MXR && X))` | 适用于 leaf 和 non-leaf；`W=1,R=0,X=1,MXR=1` 不 fault。 |
| `global` | 当前 leaf raw `G` | 非叶 G 不向下 OR；PDE cache 不存 G。 |
| `flg` permission | raw `D/A/U/X/W/R/V` | G 不进入 data flg。 |
| `flg` RSW | raw `RSW[1:0]` | RSW 不 fault，但必须进入 refill flg。 |
| `flg` ext attr | MAEE=1 时 raw `{So,C,B,Sh,Sec}`；MAEE=0 时 sysmap `{So,C,B,Sh,Sec}` | 顺序固定，MAEE=0 覆盖 raw attr。 |
| `page_size` | leaf level 或 degrade 结果 | fst leaf=1G，scd leaf=2M，thd leaf=4K；MAEE=0 可能把 1G/2M 降级。 |
| `ppn` | leaf PPN 或 degrade PPN | 1G/2M 对齐错误先 page fault，不进入 degrade。 |

正常 refill 比较必须包括：

1. `ptw_arb_vpn` 或等价 refill tag VPN 等于 request `vpn`。
2. ASID 等于 refill 当拍 active satp ASID。
3. `page_size` 编码为 1G=`3'b100`、2M=`3'b010`、4K=`3'b001`。
4. `ppn` 按 leaf/degrade 规则计算。
5. `global` 只等于 leaf G。
6. `flg` 包含 `{So,C,B,Sh,Sec}`、RSW、D/A/U/X/W/R/V，且不包含 G。
7. `type/id` 与 request 完整一致；consumer-side IUTLB 可忽略低 3 bit 的 L1 语义，但 PTW 输出携带字段仍要正确。
8. 返回目标符合 request type：fetch -> L1ITLB+L2TLB；load/store -> L1DTLB+L2TLB；PFU -> L2TLB only。

#### 13.1.6.1 Refill Tag/Data Bit Layout

Scoreboard 必须同时按语义字段和 RTL bit layout 解码 refill。当前参数为 `VPN_WIDTH=27`、`ASID_WIDTH=16`、`PGS_WIDTH=3`、`PPN_WIDTH=28`、`FLG_WIDTH=14`、`TAG_WIDTH=48`、`DATA_WIDTH=42`。规范性打包为：

```text
refill_tag[47]    = valid
refill_tag[46:20] = vpn[26:0]
refill_tag[19:4]  = asid[15:0]
refill_tag[3:1]   = page_size[2:0]
refill_tag[0]     = global

refill_data[41:14] = ppn[27:0]
refill_data[13:9]  = ext_attr[4:0] = {So,C,B,Sh,Sec}
refill_data[8:5]   = raw_pte[9:6]  = {RSW[1:0],D,A}
refill_data[4:0]   = raw_pte[4:0]  = {U,X,W,R,V}
```

由此得到：

```text
flg[13:9] = {So,C,B,Sh,Sec}
flg[8:7]  = RSW[1:0]
flg[6]    = D
flg[5]    = A
flg[4]    = U
flg[3]    = X
flg[2]    = W
flg[1]    = R
flg[0]    = V
```

`MAEE=1` 时，`ext_attr=raw_pte[63:59]`，normal refill data 为：

```text
{raw_pte[37:10], raw_pte[63:59], raw_pte[9:6], raw_pte[4:0]}
```

`MAEE=0` 时，`ext_attr=sysmap_mmu_flg[4:0]`，normal refill data 为：

```text
{final_ppn[27:0], sysmap_mmu_flg[4:0], raw_pte[9:6], raw_pte[4:0]}
```

其中 `final_ppn` 是原 leaf PPN 或 degrade 后 PPN。Scoreboard 必须检查：

1. `ptw_arb_ref_tag_din` 的 `valid/vpn/asid/page_size/global` 全字段。
2. `ptw_arb_ref_data_din` 的 `ppn/flg` 全字段。
3. `ptw_l2tlb_flg == ptw_arb_ref_data_din[13:0]`。
4. `ptw_l1dtlb_ref_ppn`、`ptw_l1itlb_ref_ppn` 等 consumer-facing PPN 来自 `refill_data[41:14]`。
5. `ptw_l1dtlb_ref_vpn`、`ptw_l1itlb_ref_vpn` 来自 `refill_tag[46:20]`。
6. G 只在 `refill_tag[0]`，不得出现在 `flg`；RSW 必须出现在 `flg[8:7]`。

#### 13.1.7 PMP 与 Access Fault Modeling

PTW source-side reference model 的 PMP 必须建模“页表项读取地址”的权限检查。不得用最终翻译 PA 做 PTW PMP 期望；最终 PA 的 PMP/PMA 检查属于 consumer/end-to-end 模型或下游模块。

PMP 检查规则：

```text
deny = (fetch && !pmp_mmu_flg[2]
     || load  && !pmp_mmu_flg[0]
     || store && !pmp_mmu_flg[1]
     || pfu   && !pmp_mmu_flg[0])
     && !(effective_machine_mode && !pmp_mmu_flg[3])
```

Scoreboard 必须覆盖和比较：

1. fst/scd/thd 每级 PTE PA 是否按当前级公式生成。
2. request type 到 PMP access kind 的映射：fetch->X、load->R、store/atomic->W、PFU->R。
3. `MPRV=1` 时 load/store/PFU 用 `MPP` 作为 effective privilege；fetch 用真实 privilege。
4. effective M-mode 且 `pmp_mmu_flg[3]==0` 时跳过 deny；`pmp_mmu_flg[3]==1` 时仍按权限位判断。
5. PMP deny 后不写 mbuf、不发 LSU、不进入 CHK、不 page fault、不更新 PDE cache。
6. PMP deny 生成 access fault，携带原始 `type/id`，返回目标按原 request type。

#### 13.1.8 PDE Cache Reference Model

PTW source-side model 必须维护一个参考 PDE cache，或从可靠 whitebox monitor 重建等价状态。要求：

```systemverilog
typedef struct {
  bit          valid;
  logic [17:0] tag;      // L1 uses vpn[2], L2 uses {vpn[2],vpn[1]}; exact width may be split by level.
  logic [27:0] ppn;
} pde_cache_entry_t;
```

参考 PDE cache 规则：

1. 两级各 16 entry，全相联。
2. 一级 tag=`vpn[2]`，data=第一级 non-leaf PTE PPN。
3. 二级 tag=`{vpn[2],vpn[1]}`，data=第二级 non-leaf PTE PPN。
4. lookup 在 request accept 后执行；同拍 lookup/update 时，lookup 使用旧值，update 下一拍生效。
5. 一级命中跳过 fst；二级命中跳过 fst/scd；双命中选择二级。
6. update 仅在 non-leaf PTE、无 page fault、无 bus error、未被 reset/abort/flush 屏蔽时发生。
7. page fault、PMP access fault、LSU bus error、leaf PTE、abort/drop 都不得更新 PDE cache。
8. reset 和 `tlboper_ptw_abort` 清空 PDE cache 并 flush in-flight。
9. satp 任意字段改变和 PMP 配置改变只清空 PDE cache，不 flush in-flight；旧 in-flight walk 后续返回 non-leaf 且未被 abort/flush 屏蔽时仍允许重新更新。
10. PLRU 位级变化不作为 source scoreboard 必须比较项；如果 directed test 需要替换 victim，可使用 whitebox monitor/SVA 检查 invalid-first/PLRU，否则 scoreboard 可通过观测 update entry 来同步参考状态。

PDE cache 相关测试点的关闭要求：scoreboard 负责最终 skip-level/refill/fault 结果；SVA/monitor 负责 double-hit、lookup/update race、clear timing、PLRU/victim、skip-level 没有误访问被跳过级别。

Reference model 的 PDE cache 状态更新顺序必须固定，避免同拍事件歧义：

1. 在 request accept 事件上，先用上一拍 committed PDE cache 状态计算 lookup hit/miss。
2. 同拍若存在 PDE cache update，不能影响该 request 的 lookup 结果；update 进入 next-state，下一拍才可命中。
3. reset 和 `tlboper_ptw_abort` 对 next-state 优先级最高：同拍 lookup request 被标 drop，update 被屏蔽，commit 后 PDE cache 全 invalid。
4. satp/PMP clear 对 PDE cache valid 的 commit 优先级高于普通 lookup，但不改变已在 TWU/mbuf 中的 expected；同拍/后续旧 in-flight non-leaf response 若未被 abort 屏蔽，仍可按普通 update 重新写入 next-state。
5. 若 scoreboard 使用 DUT PDE update monitor 同步状态，必须在日志中记录 update source level、tag、data、victim/entry、屏蔽原因；若缺少 victim/entry，至少要记录 abstract state 足以决定后续 hit/miss。

#### 13.1.9 MAEE、Sysmap 与 Degrade Model

MAEE/sysmap/degrade 必须在 PTW source-side ref model 中完整建模，不能只在 coverage 里观察。

`MAEE=1`：

1. 1G/2M/4K leaf 均直接使用 raw PTE `{So,C,B,Sh,Sec}`。
2. 不查 sysmap，不做 1G/2M 跨页降级。
3. 仍检查 1G/2M PPN 对齐、PTE 权限、A/D/U/S 等 page fault。

`MAEE=0`：

1. 所有 leaf page size 的 refill 扩展属性都来自 sysmap，包括普通 4K、普通 2M、普通 1G、降级后的 2M/4K。
2. 1G/2M 先完成 page fault 和 PPN 对齐检查；对齐错误直接 page fault，不进入 sysmap/degrade。
3. 1G 首尾 PPN 为 `{pte.ppn[2],9'b0,9'b0}` 和 `{pte.ppn[2],9'h1ff,9'h1ff}`。
4. 2M 首尾 PPN 为 `{pte.ppn[2],pte.ppn[1],9'b0}` 和 `{pte.ppn[2],pte.ppn[1],9'h1ff}`。
5. 首尾同 region 时不降级，属性取尾地址 region flg。
6. 1G 首尾跨 region 时先降级为 2M：`ppn={pte.ppn[2],vpn[1],9'b0}`；若该 2M 仍跨 region，再降级为 4K：`ppn={pte.ppn[2],vpn[1],vpn[0]}`。
7. 2M 首尾跨 region 时降级为 4K：`ppn={pte.ppn[2],pte.ppn[1],vpn[0]}`。
8. 降级不是继续访问下一级页表；权限、G、RSW、D/A/U/X/W/R/V 仍来自原始 leaf PTE。
9. 4K 不降级，但必须查询 final PPN 所在 sysmap region，并把 region flg 写入 refill flg。
10. 一旦进入 MAEE=0 sysmap/degrade 流程，后续 MAEE 改变不使该请求回退到 PTE attr 路径。

Sysmap 无命中或多命中是非法/受约束配置。若测试故意产生，scoreboard 应报告 illegal stimulus，而不是把它解释成 PTW page fault 或 access fault。

#### 13.1.10 Abort、Reset、Bus Error 与 Dropped Transaction

Reference model 必须把 abort/reset/drop 建模为 transaction state，而不是简单删除 expected。

| 事件 | Expected 处理 | 必须检查 |
| --- | --- | --- |
| reset | 所有 in-flight request -> `PTW_EXP_DROPPED(reset)`；PDE cache 清空。 | reset 后无 stale refill/exception/PDE update。 |
| `tlboper_ptw_abort` | 非已获顶层授权输出的 in-flight request -> `PTW_EXP_DROPPED(abort)`；PDE cache 清空。 | normal refill 被屏蔽；PDE update 被屏蔽；新形成异常不可见。 |
| abort 前已有异常寄存器且当拍获顶层授权 | 保留为 visible page/access fault。 | 只允许这类异常穿透 abort。 |
| abort 前一拍 LSU request valid 已为 1 | request 进入 wait-for-lsu-return/drop 状态。 | LSU request/PA 保持到 data valid；返回普通数据丢弃。 |
| abort 同拍 LSU ordinary data | `PTW_EXP_DROPPED(abort_data)`。 | 不进 CHK，不 refill，不更新 PDE。 |
| abort 同拍新 LSU bus error | `PTW_EXP_DROPPED(abort_bus_error)`。 | 不写新 access exception，不上报。 |
| abort 前 bus error 已写入 access exception register 且当拍 grant | visible `PTW_EXP_ACCESS_FAULT`。 | 允许上报一次；对应 L2 entry 不再期待重发。 |
| LSU bus error 无 abort | `PTW_EXP_ACCESS_FAULT(bus_error)`。 | 不 CHK、不 page fault、不 refill、不 PDE update；entry 释放等待异常寄存器写成功。 |

Scoreboard 不能把所有缺失输出都默默忽略。只有 reset/abort/drop 规则命中的 expected 才能从 pending map 中删除；其他 pending request 在 end-of-test 必须报未完成或超时。

#### 13.1.11 Scoreboard 观测点与 Monitor 要求

PTW source-side scoreboard 至少需要以下 monitor/probe 信息。字段名可使用现有 `mmu_dut_probes_if.sv` 或等价 transaction monitor：

| 观测类别 | 现有/建议 probe | 用途 |
| --- | --- | --- |
| PTW request | `l2tlb_ptw_req`、`l2tlb_ptw_id`、`l2tlb_ptw_type`、request `vpn` 或 L2MB entry VPN | 创建 expected；检查 type/id/vpn。 |
| PTW complete | `ptw_l2tlb_cmplt`、`ptw_l2tlb_id`、`ptw_l2tlb_type`、`ptw_l2tlb_ref_pgflt`、`ptw_l2tlb_ref_acc_err` | 匹配 page/access/refill completion。 |
| Refill arb | `ptw_arb_req`、`arb_ptw_grant`、`arb_pfu_grant`、`arb_l2tlb_req`、`ptw_arb_pgs`、`ptw_arb_vpn`、`ptw_arb_ref_tag_din` | 比较 refill class、page size、VPN/tag/global/ASID/flg。 |
| L1 refill | `ptw_l1i_ref_cmplt`、`ptw_l1d_ref_cmplt`、`ptw_l1d_ref_id`、`ptw_l1d_ref_ppn` | 检查 fetch/load/store 的 L1 target；PFU 不应触发 L1 refill。 |
| TWU status | `ptw_twu_ref_req`、`ptw_twu_pgflt_vec`、`ptw_twu_acc_err_vec`、`ptw_twu_mask`、`ptw_twu_data_ready` | debug、coverage、SVA wait/arb 证据。 |
| PDE/skip | `ptw_xbar_hit_lvl`、PDE update/clear/hit monitor、`ptw_mbuf_twu_lvl` | 重建 PDE lookup/update/skip-level；若现有 probe 不够，应补。 |
| PMP | `p13_pmp_vld_vec`、`p13_pmp_grant_vec`、`p13_pmp_deny_vec`、`p13_pmp_type_vec`、`p13_pmp_flg_vec`、`p13_pmp_pa_vec`、`p13_pmp_fetch_vec`、`pfu_pmp_flg4` | 比较 level/type/effective-mode/PTE PA deny。 |
| Sysmap/MAEE | `ptw_cp0_maee`、`maee_leaf_lvl*_hit`、`maee_csr_path_hit`、`maee_refill_path_hit`、`p13_sysmap_*`、`pfu_sysmap_flg4`、`p13_csr_refill_*` | 比较 MAEE path、degrade page size/PPN、flg order。 |
| LSU/mbuf | `ptw_lsu_data_req`、`ptw_lsu_data_req_grant`、`ptw_mbuf_entry_vld`、LSU data/bus-error monitor | bus error/drop/single outstanding/addr stable 证据。 |
| abort/reset | `tlboper_ptw_abort` 或等价内部 pulse、reset、tlboper state | drop、PDE clear、outstanding drain。 |

如果现有 probe 无法捕获某个 source-side 必需字段，SPEC 要求补 monitor，而不是降级为 consumer-only 检查。尤其是 `flg`、ASID、global、PDE update tag/data、raw PTE/level、abort pulse 与 LSU bus error 的关联必须可观察。

#### 13.1.12 事务级 Scoreboard 不检查项

PTW source-side scoreboard 不做以下检查，避免把 cycle-accurate 协议混进事务 golden：

1. 固定 T0/T1/T2 周期或固定 LSU latency。
2. ready/valid 每拍保持细节。
3. xbar 对每个请求逐拍 backpressure 的所有中间状态。
4. 同周期多个候选输出在 RTL 内部被授权前的临时组合优先级。
5. PLRU bit-level 翻转，除非 directed test 明确以 replacement 为目标。
6. L1DTLB/L1ITLB/L2TLB 内部 entry replacement、hit CAM、wakeup/busy。

这些项目必须由 assertion/monitor/coverage 检查，并在 signoff report 中与 source scoreboard 结果共同列出。

#### 13.1.13 Waiver、Illegal Stimulus 与 Consumer-only 规则

允许的 waiver 必须有明确作用域：

1. `mmu_translation_sb` 可以针对 L1DTLB exception replay、preselect、IFU completion timing 等 consumer-side 对齐窗口做 narrow waiver；这些 waiver 不能隐藏 PTW source-side `type/id/flg/page_size/fault_kind` mismatch。
2. `mmu_l1dtlb_spec_sb` 可以证明 refill/exception 被 L1DTLB 消费，但不能关闭 PTW source-side PTE/PMP/MAEE/PDE/abort 行为。
3. sysmap 无命中/多命中、Bare 请求进入 PTW、M-mode no-translation 请求进入 PTW、同 `{type,id}` 未完成前复用、PTW->LSU OOO response、mbuf overflow 覆盖 valid entry 等，默认属于 illegal stimulus。
4. 若某 directed test 专门验证 illegal/stress 行为，必须在 test name、log 和 scoreboard report 中标记，不得用于关闭正常 PTW requirement。
5. Consumer-only evidence 可以附在 `PTW-FLOW-*` 后作为补充，但不能替代 source-side expected match。

#### 13.1.14 End-of-test Signoff 与 Report

PTW source-side scoreboard report 必须至少输出以下计数和摘要：

1. accepted request 总数，按 type 分桶：fetch/load/store/PFU。
2. expected refill/page fault/access fault/drop 数量。
3. matched refill/page fault/access fault 数量。
4. mismatch 数量，按字段分桶：`vpn/asid/page_size/ppn/global/flg/type/id/target/fault_kind`。
5. pending/unmatched request 数量；end-of-test 非 0 即 fail，除非 reset/abort/drop waiver 明确命中。
6. illegal stimulus 数量和原因。
7. PDE cache hit/update/clear/drop 数量，按 L1/L2、double-hit、satp/PMP clear、abort clear 分桶。
8. PMP deny 数量，按 level/type/effective privilege 分桶。
9. PTE page fault 数量，按 level/fault_kind/type 分桶。
10. MAEE/sysmap/degrade 数量，按 MAEE=1/0、1G/2M/4K、1G->2M、1G->4K、2M->4K、4K sysmap 分桶。
11. LSU bus error 数量、abort dropped bus error 数量、abort outstanding drain 数量。
12. consumer-side matched/waived 数量，单独列出，不能混入 source-side pass 率。

每个 `PTW-AUD-*`、`PTW-FLOW-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*` 关闭时，报告必须能追溯到至少一个 source-side expected match 或 source-side SVA/monitor cover hit；否则状态只能是 open、consumer-only 或 waived。

每条 matched transaction 必须生成可追溯记录，建议字段如下：

```text
tc_id
scenario_id
requirement_ids[]      // PTW-AUD/PTW-FLOW/PDE-TP/MBUF-TP/MAEE-TP
request={accept_cycle,vpn,type,id,source}
context_samples={satp_ppn_cycle,asid_cycle,chk_priv_cycle,mxr,sum,mprv,mpp,maee}
pde={lookup_level,hit_l1,hit_l2,update_level,update_tag,update_ppn,clear_seen}
levels[]={
  level,pte_addr,pmp_flg,pmp_deny,mem_req_cycle,mem_rsp_cycle,
  raw_pte,bus_error,leaf,page_fault,fault_kind,nonleaf_update
}
maee_sysmap={maee_at_leaf,sysmap_hits,sysmap_flg,degrade_from,degrade_to,final_ppn}
expected={kind,type,id,vpn,asid,page_size,ppn,global,flg,target,drop_reason}
actual={kind,type,id,vpn,asid,page_size,ppn,global,flg,target}
result={matched,mismatch_field,waiver_id}
```

没有 `tc_id/scenario_id/requirement_ids` 的 match 只能计入 smoke，不得关闭具体测试点。没有 `levels[]` 的 match 只能证明最终输出，不得关闭 PTE PA、PMP level、PDE update、bus error 或 MAEE/degrade 类 requirement。

### 13.2 Assertion/Monitor

建议 assertion/monitor 检查：

1. PTW ready 低时 L2TLB valid 与字段稳定。
2. 每周期最多 accept 一个 L2TLB 请求。
3. xbar hash 选择正确 TWU。
4. PDE cache lookup/update 同拍读旧值、写下拍生效。
5. PDE cache 命中跳过正确流水级。
6. satp/PMP/tlboper/reset 对 PDE cache 与 in-flight 状态影响符合表格。
7. PMP deny 后不写 mbuf、不发 LSU、不进 CHK。
8. LSU request valid 拉高后 PA 稳定直到 data valid。
9. LSU 单 outstanding。
10. LSU bus error 不进 CHK，entry 释放等待异常寄存器写入成功。
11. abort 时 normal refill 被屏蔽。
12. abort 前已获顶层授权异常可见，新形成异常不可见。
13. 各仲裁优先级：TWU 内部、mbuf 写入、LSU bus error、顶层 access/page/refill。
14. MAEE=0 时 4K 也必须 sysmap refill。
15. 大页降级不再访问下一级页表。

### 13.3 UVM 约束

可约束不产生：

1. Bare 模式请求进入 PTW。
2. 纯 M 态、不做地址翻译的请求进入 PTW。
3. sysmap 无命中或多命中。
4. IUTLB 多 outstanding。
5. DTLB mbuf 超过 8 个 outstanding。
6. 同一 id 未完成前复用。
7. satp.asid/satp.ppn 无 abort 变化，除非专门验证该交错风险。
8. PTE high reserved bits 非 0 如果当前测试目标不是“不检查保留位”。

### 13.4 必须覆盖的功能场景

最低功能覆盖应包括：

1. PDE cache miss，1G/2M/4K success。
2. PDE cache miss，MAEE=0，1G 不降级、1G->2M、1G->4K。
3. PDE cache miss，MAEE=0，2M 不降级、2M->4K。
4. MAEE=0，4K sysmap refill。
5. PMP access fault at fst/scd/thd。
6. CHK page fault at fst/scd/thd。
7. LSU bus error。
8. 第一级 PDE cache hit，最终 2M。
9. 第一级 PDE cache hit，最终 4K，并更新第二级 PDE cache。
10. 第二级 PDE cache hit，最终 4K。
11. 两级 PDE cache 同时 hit，选择第二级。
12. satp 改变清 PDE cache 不 flush in-flight。
13. PMP 改变清 PDE cache 不 flush in-flight。
14. `tlboper_ptw_abort` 无 LSU outstanding。
15. `tlboper_ptw_abort` 有 LSU outstanding。
16. abort 同拍普通 LSU data 返回并丢弃。
17. abort 同拍 LSU bus error 返回且不上报。
18. abort 前异常寄存器已有异常且获顶层授权，异常可见。
19. PFU success。
20. PFU access fault/page fault。
21. Fetch with `MPRV=1 && MPP=M` still follows real pipeline privilege；load/store/PFU with `MPRV=1 && MPP=M` must be constrained as no PTW source/direct-map。
22. raw PTE G 不进 `flg`、RSW 进 `flg`、MAEE=0 sysmap 属性顺序 `{So,C,B,Sh,Sec}`。

### 13.5 PTW 测试点规格总则

本节把当前 verification plan、UVM 测试、SVA、covergroup、scoreboard 和后续必须补齐的 PTW 测试点统一收敛到本文。后续审核、实现、回归和签核以本节为 PTW 测试点真值；旧 verification plan 或旧 test name 如果与本文第 0 章和第 1-13 章冲突，按本节标记为删除、重归属、修改或拆分。

本节是静态规格和审核基线，不声称任何现有测试已经通过。关闭一个 PTW 测试点至少需要同时满足：

1. stimulus 确认命中目标条件，包括 request type、level、page size、PTE bit、PMP flg、MAEE/sysmap、MPRV/MPP、abort/LSU 时序等。
2. checker、scoreboard、monitor、SVA 或 covergroup 可观察 expected behavior，不允许只用 test name 关闭 requirement。
3. expected behavior 与本文 spec 一致，不额外套标准 Sv39 reserved bit、RSW、strong-order 等规则。
4. 对事务级行为使用 scoreboard/ref model 匹配最终结果；对周期级协议、仲裁、ready/valid 保持、lookup/update race、abort 边界使用 assertion/monitor。
5. 通过 L1DTLB/L2TLB 观测到 PTW 输出被消费，只能作为 consumer-side evidence；PTW source-side 的 PTE/PMP/PDE/MAEE/mbuf/abort 行为仍必须有 PTW 自己的检查点。

测试点状态使用以下术语：

| 状态 | 含义 |
| --- | --- |
| `keep` | 现有测试方向与 spec 一致，可保留，但仍需覆盖命中和 checker 证据。 |
| `modify` | 现有测试方向相关，但 stimulus、expected、命名、检查点或覆盖粒度需要修改。 |
| `split` | 现有测试混合多个独立 spec 行为，必须拆成多个 directed 场景。 |
| `delete` | 现有测试点与 spec 冲突，或验证非法协议，不能作为 PTW 正向功能关闭依据。 |
| `re-scope` | 现有测试点不属于 PTW source-side，转归 L1DTLB、L2TLB、system sysmap 或 PMP 模块。 |
| `add` | 本 spec 有明确 requirement，但当前 plan/UVM 未发现足够测试或观测点。 |
| `consumer-only` | 只证明 PTW 输出被下游消费，不能关闭 PTW 源头生成规则。 |

### 13.6 现有 PTW 相关 UVM 测试点归属

当前仓库中直接或间接 PTW 相关 suite 包括：

1. `mmu_verification/testbench/test/ptw_tests`
2. `mmu_verification/testbench/test/ptw_lsu_protocol_tests`
3. `mmu_verification/testbench/test/pmp_twu_tests_v6`
4. `mmu_verification/testbench/test/maee_twu_tests`
5. `mmu_verification/testbench/test/sysmap_tests`
6. `mmu_verification/testbench/test/tlbop_tests`
7. `mmu_verification/testbench/test/l1dtlb_tests`
8. `mmu_verification/testbench/test/l1itlb_tests`
9. `mmu_verification/testbench/test/l2tlb_tests`
10. `mmu_verification/testbench/test/basic_tests`、`flush_tests`、`bug_hunt_tests`、`perf_tests` 中含 PTW 交互的 smoke/stress。

现有测试点按 PTW requirement 归属如下：

| Requirement group | 现有 plan/UVM 测试点 | 当前归属与处理 |
| --- | --- | --- |
| SATP/root PPN 与上下文 | `test_ptw_satp_load_basic`、`test_ptw_satp_load_dual_switch`、`test_satp_switch_during_walk`、`test_satp_hotswap_concurrent` | `modify`。保留 SATP root PPN 使用点检查；`satp` 改变只清 PDE cache、不 flush in-flight，不能写成自动 abort。若专测无 abort 交错，expected 必须允许旧 walk 用新 ASID refill；普通随机可约束不生成该交错。 |
| 1G/2M/4K success walk | `test_ptw_map4k_directed`、`test_ptw_l0_pte_read_basic`、`test_huge_page_1g_direct`、`test_huge_page_2m_direct`、`test_huge_page_4k_full_walk`、`test_huge_page_mixed` | `keep + modify`。保留 smoke，但必须检查 page_size、PPN 拼接、flg、global、ASID、type/id 和返回目标；不能只检查最终 VA->PA。 |
| PDE cache hit/miss/replace/clear | `test_ptw_l2_pde_hit_direct`、`test_ptw_l2_pde_miss_walk`、`test_ptw_l2_pde_cache_replace`、`test_ptw_l1_pde_hit`、`test_ptw_l1_pde_miss_walk`、`test_ptw_l1_pde_cache_replace`、`test_pde_cache_l1_single_entry`、`test_pde_cache_l2_single_entry`、`test_pde_cache_clear_on_ptw_reset`、`test_mmu_pde_cache_hit_l2_skip_scd`、`test_mmu_pde_cache_hit_l3_skip_thd`、`test_mmu_pde_cache_full_miss_full_ptw` | `modify`。现有 smoke 只能证明可翻译，不能关闭双命中选第二级、lookup/update 同拍读旧、update 条件、satp/PMP clear no-flush、abort 屏蔽 update 等精确规则。 |
| Xbar/ready/backpressure | `test_xbar_1to4_distribution`、`test_xbar_twu_round_robin`、`test_mmu_ptw_ready_all_mask_low`、`test_mmu_ptw_ready_one_unblock`、`test_mmu_ptw_ready_l2tlb_stall`、`test_mmu_twu_idle_implies_no_mask`、`test_bug_014_xbar_cold_start` | `modify`。`round_robin` expected 必须改成 spec hash；ready low 时检查 L2TLB valid 和字段保持，unblock 后同一请求被 accept。 |
| TWU 并发、idle、wait | `test_twu_concurrent_4way`、`test_twu_concurrent_same_vpn`、`test_twu_idle_state`、`test_mmu_twu_idle_implies_no_mask`、`test_mmu_mbuf_multi_twu_independent_ready`、`test_twu_mask_pmp_wait_all4`、`test_twu_pmp_wait_stall` | `keep + modify`。保留并发/idle/等待方向；相同 VPN 不应假设 PTW mbuf 有通用去重，必须按实际协议和 L2TLB miss buffer 约束检查。 |
| PTE V/R/W/X/U/A/D/MXR/SUM/page fault | `test_pte_v_bit_zero`、`test_pte_rw_both_zero`、`test_pte_u_bit_sum_interaction`、`test_pte_x_bit_mxr_mix`、`test_ptw_l0_pte_permission_check`、`test_mmu_l1dtlb_dtlb_fault_ad_us_sum_001` | `split + modify`。每个 wrapper 必须显式设置 `fault_kind`、level、page size、access type、MXR/SUM/MPRV/MPP/effective privilege；禁止多个测试实际都落到默认 `V_OFF`。 |
| RSW/high reserved/G/flg | `test_pte_reserved_bits`、`test_pte_global_bit_asid`、L2TLB/L1TLB global/asid tests | `modify`。reserved/RSW 触发 fault 的 expected 必须删除。改成 RSW no-fault + flg 传播、high reserved ignored、raw G 只进 global/tag 且不进 data flg、非叶 G 不向下 OR。 |
| 1G/2M PPN 对齐 | `test_pte_misaligned_ppn_1g`、`test_pte_misaligned_ppn_2m`、`test_sysmap_phase13_pa_align_1g`、`test_sysmap_phase13_pa_align_2m_4k` | `modify`。必须真实构造巨页 leaf 错位；expected 是 page fault 且不进入 sysmap/degrade，不是 access fault。 |
| PMP/TWU access fault | `pmp_twu_tests_v6/*`、`test_ptw_pmp_before_lsu`、`test_ptw_pmp_deny_stop`、`test_ptw_pmp_deny_accflt`、`test_ptw_pmp_deny_no_refill`、`test_ptw_pmp_wait_no_lsu`、`test_ptw_pmp_pa_1g/2m/4k/zero`、`test_ptw_pmp_mmode_l0`、`test_ptw_pmp_fetch_zero`、`test_ptw_pmp_port_map_concurrent`、`test_mmu_twu_accerr_bypass_arb` | `modify`。保留 source-side PMP 方向；旧 “fetch zero/统一按 load/R bit” 口径删除，按原始 type：fetch 看 X、load/PFU 看 R、store 看 W；补 fst/scd/thd level 和 MPRV effective mode。 |
| Mbuf/LSU protocol | `test_pmbuf_serial_outstanding_001`、`test_pmbuf_addr_stable_001`、`test_pmbuf_no_tag_001`、`test_pmbuf_inorder_resp_001`、`test_pmbuf_ptr_hold_001`、`test_mmu_mbuf_ready_gate_no_early_vld`、`test_mmu_mbuf_have_no_resend`、`test_mmu_mbuf_multi_twu_independent_ready` | `keep + add`。保留 single outstanding、addr stable、no-tag/in-order、ptr hold；补 CHK not ready hold、bus error no CHK、abort outstanding 边界和 mbuf entry 分配优先级。 |
| Mbuf full/OOO legacy | `test_mbuf_credit_management`、`test_mbuf_full_backpressure`、`test_mbuf_ooo_response`、`ptw_mem_ooo_rsp_seq` | `delete/re-scope/modify`。PTW 不以 MBUF full backpressure 作为功能需求；PTW->LSU PTE 通道无 tag、单 outstanding，乱序返回不是合法协议。可重命名为 upstream credit/no-overwrite 或删除正向 expected。 |
| LSU bus error | `test_bus_error_terminate`、`ptw_mem_bus_error_inject_seq`、`test_mmu_twu_except_conflict_pgflt_accflt` | `modify`。检查 bus error 不进 CHK、不 page fault、不 refill、不 update PDE cache；写 access exception 成功前 entry 不释放；顶层 access fault 优先。 |
| Abort/tlboper/sfence | `test_sfence_abort_walk`、`test_mmu_sfence_during_walk`、`test_mmu_sfence_refill_conflict`、`test_mmu_sfence_lsu_trigger`、`test_mmu_sfence_lsu_done_handshake`、`test_mmu_phase6_rtu_flush_ptw`、`test_reset_during_ptw_walk` | `split + modify`。PTW source-side 使用 `tlboper_ptw_abort` 语义；拆成无 outstanding、有 outstanding、同拍 data、同拍 bus_error、已有异常寄存器 grant、PDE update blocked。L1/L2 TLB sfence invalidation 是 consumer/system evidence。 |
| Refill/page/access 仲裁 | `test_mmu_arb_refill_except_priority`、`test_mmu_twu_pgflt_bypass_arb`、`test_mmu_twu_accerr_bypass_arb`、`test_mmu_twu_except_conflict_pgflt_accflt`、`test_mmu_arb_grant_onehot_check`、`test_arb_no_double_grant`、`test_arb_work_conserving`、`test_arb_ptw_priority_highest`、`test_arb_reqq_preempt_lower`、`test_arb_tlboper_above_prefetch`、`test_arb_bank_conflict_resolution`、`test_arb_backpressure_mask`、`test_mmu_arb_pgs_bank_select`、`test_mmu_arb_vpn_match_tag_din`、`test_mmu_arb_multi_twu_fairness` | `keep + modify`。PTW 输出优先级固定为 access fault > page fault > refill；周期级仲裁优先级交 assertion/monitor，scoreboard 只按 type+id 做最终匹配。L2TLB bank/ReqQ/TLBOp 仲裁不应替代 PTW source-side 输出仲裁检查。 |
| MAEE/TWU | `test_mmu_twu_maee0_csr_path`、`test_mmu_twu_maee0_csr_symmetric`、`test_mmu_twu_maee1_direct_refill`、`test_mmu_twu_maee_dynamic_switch`、`test_bug_011_twu_2m_csr_cross` | `modify + add`。保留 MAEE path smoke；补 1G/2M/4K all sizes、THD/4K sysmap 可观测性、1G->4K、flag order、no-lower-walk、进入 sysmap 后 MAEE 改变不回退。 |
| Sysmap phase13/PTW-owned MAEE=0 path | `test_sysmap_phase13_flg_refill_region0/region7`、`test_sysmap_phase13_default_flag`、`test_sysmap_phase13_cross_1g_degrade`、`test_sysmap_phase13_cross_2m_degrade`、`test_sysmap_phase13_no_cross_no_degrade`、`test_sysmap_phase13_pa_align_1g`、`test_sysmap_phase13_pa_align_2m_4k`、`test_sysmap_phase13_4twu_concurrent` | `keep + modify`。这些可作为 PTW MAEE=0/sysmap/degrade evidence，但必须证明是 PTW leaf refill 属性路径，不是 system direct-map bypass。 |
| System sysmap/direct-map | `test_sysmap_hit_bypass_walk`、`test_sysmap_no_walk_required`、`test_sysmap_vs_ptw_priority`、`test_mmu_sysmap_priority_over_tlb`、`test_mmu_sysmap_tlb_fallback`、`test_mmu_sysmap_*` region/hit tests | `re-scope`。归 system sysmap/L1DTLB direct-map，不关闭 PTW MAEE=0 refill/degrade requirement。可作为 sysmap 配置正确性的辅助。 |
| PFU | `test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001`、LSU pipe2/PFU related scoreboard、PFU random/stress | `add + consumer-only`。当前缺少 PTW source-side PFU success/fault directed。必须补 PFU success 只 refill L2TLB、PFU page/access fault 返回 L2TLB、PFU PTE 权限不按 load 检查 R/MXR/D。 |
| L1DTLB consumer-side | `test_mmu_l1dtlb_dtlb_refill_001/002`、`test_mmu_l1dtlb_dtlb_mb_pgflt_001`、`test_mmu_l1dtlb_dtlb_access_fault_*`、`test_mmu_l1dtlb_dtlb_expt_id_map_001`、`test_mmu_l1dtlb_dtlb_refill_stale_id_001` | `consumer-only`。可证明 load/store PTW refill/page/access fault 被 L1DTLB 消费；不能关闭 PTW PTE/PMP/MAEE/PDE/mbuf/abort 源头规则。 |
| L1DTLB non-PTW | `DTLB_BUSY_*`、`DTLB_WAKEUP_*`、MB alloc/full/credit、WFI data hold、hit permission、STAMO bypass | `re-scope`。归 L1DTLB，不作为 PTW requirement closure。 |

旧 verification plan / traceability matrix 中的 PTW 编号逐项处理如下：

| Legacy ID | 旧测试点 | 本文归属 | 必须修正/关闭方向 |
| --- | --- | --- | --- |
| `PTW-001` | `test_ptw_satp_load_basic` | `modify` | 检查 `regs_ptw_satp_ppn` 在 `fst_pmp_pa` 使用点生效；不要求 request accept 时锁存全部 satp 状态。 |
| `PTW-002` | `test_ptw_satp_load_dual_switch` | `modify` | 双 satp 切换只能关闭后续 walk 使用新 root；in-flight walk 语义按 satp clear-only/abort 分拆。 |
| `PTW-003` | `test_ptw_l2_pde_hit_direct` | `modify` | 旧 “L2 PDE hit 1-cycle/无 LSU” 只能作为 smoke；需补二级 hit 跳 fst/scd、最终 thd、双命中优先二级。 |
| `PTW-004` | `test_ptw_l2_pde_miss_walk` | `modify` | miss 后必须覆盖 PTE PA 公式、PMP pass、LSU request、非叶 update 或 leaf refill。 |
| `PTW-005` | `test_ptw_l2_pde_cache_replace` | `modify` | 替换策略需按 invalid-first/PLRU victim、hit/write 更新 PLRU 关闭。 |
| `PTW-006` | `test_ptw_l1_pde_hit` | `modify` | 一级 hit 必须证明跳过 fst，进入 scd；不能只看最终成功。 |
| `PTW-007` | `test_ptw_l1_pde_miss_walk` | `modify` | 一级 miss/二级路径要区分 fst 非叶 update PDE1 和 scd/thd 后续。 |
| `PTW-008` | `test_ptw_l1_pde_cache_replace` | `modify` | 同 `PTW-005`，补一级 PDE PLRU/invalid/victim 检查。 |
| `PTW-009` | `test_ptw_l0_pte_read_basic` | `modify` | 三级 4K walk 必须检查 thd leaf、page_size=4K、PPN/flg/global/type/id。 |
| `PTW-010` | `test_ptw_l0_pte_permission_check` | `split` | 拆成 fetch/load/store/PFU 权限矩阵；PFU 不按 load 检查 R/MXR/D。 |
| `PTW-011` | `test_twu_concurrent_4way` | `keep + modify` | 可保留并发无死锁；还需按 xbar hash、TWU 独立 wait/valid、type/id 匹配检查。 |
| `PTW-012` | `test_twu_concurrent_same_vpn` | `modify` | 删除 “PMBUF same VPN dedup 必然单 LSU 读” 的强 expected，除非 RTL/spec 明确；按 L2TLB id 不复用和 PTW single outstanding 约束重写。 |
| `PTW-013` | `test_mbuf_credit_management` | `delete/modify` | 删除 MBUF full backpressure expected；改为 no-overwrite/upstream credit/entry allocation/LSU single outstanding。 |
| `PTW-014` | `test_mbuf_ooo_response` | `delete` | LSU OOO response 非合法 PTW 协议；不得作为正向功能测试。 |
| `PTW-015` | `test_pte_v_bit_zero` | `modify` | 保留 V=0 page fault，但显式 level/type/page size；必须是 page fault，不是 access fault。 |
| `PTW-016` | `test_pte_rw_both_zero` | `split` | 拆 non-leaf pointer、thd non-leaf、write-only、X-only；删除 “access fault” expected。 |
| `PTW-017` | `test_pte_reserved_bits` | `modify` | 改成 RSW/high reserved positive；不再期待 reserved/RSW fault。 |
| `PTW-018` | `test_pte_misaligned_ppn_2m` | `modify` | 真实 2M leaf `PPN[0] != 0`，page fault 且不 sysmap/degrade。 |
| `PTW-019` | `test_pte_misaligned_ppn_1g` | `modify` | 真实 1G leaf `PPN[1:0] != 0`，page fault 且不 sysmap/degrade。 |
| `PTW-020` | `test_pte_u_bit_sum_interaction` | `modify` | 显式 effective U/S/M、SUM、U bit；MPRV/MPP=M 下 U/S 检查跳过。 |
| `PTW-021` | `test_pte_x_bit_mxr_mix` | `modify` | 覆盖 load MXR、fetch X、write-only 与 PFU 独立规则；不能只测默认 V=0。 |
| `PTW-022` | `test_pte_global_bit_asid` | `split` | 拆 leaf G/global、non-leaf G no-OR、G 不进 flg、PDE hit 后 global 仍来自 leaf。 |
| `PTW-023` | `test_huge_page_1g_direct` | `keep + modify` | 1G success smoke 保留；补 page_size=1G、PPN 拼接、MAEE=0/1 属性来源。 |
| `PTW-024` | `test_huge_page_2m_direct` | `keep + modify` | 2M success smoke 保留；补 fst 非叶 update、scd leaf、page_size=2M、对齐。 |
| `PTW-025` | `test_huge_page_4k_full_walk` | `keep + modify` | 4K success smoke 保留；补 PDE1/PDE2 update、THD leaf、MAEE=0 4K sysmap。 |
| `PTW-026` | `test_huge_page_mixed` | `keep + modify` | 只能作为 mixed smoke；需绑定 1G/2M/4K cover bins 后才能关闭 flow。 |
| `PTW-027` | `test_satp_switch_during_walk` | `split` | 拆 satp clear-only no-flush、旧 walk 可 update、无 abort ASID/PPN 交错约束。 |
| `PTW-028` | `test_sfence_abort_walk` | `split` | 改为 `tlboper_ptw_abort` 矩阵：无 outstanding、有 outstanding、同拍 data/bus_error、已有异常 grant。 |
| `PTW-029` | `test_bus_error_terminate` | `modify` | 删除 “所有 TWU 获得错误”；按 mbuf entry 原始 type/id 上报 access fault。 |
| `PTW-030` | `test_wakeup_vector_dispatch` | `re-scope` | 归 L1DTLB/LSU wakeup consumer-side；不关闭 PTW source-side。 |
| `PTW-031` | `test_tlb_busy_stall` | `re-scope` | 归 L1DTLB busy/MB 管理；不关闭 PTW MBUF/ready。 |
| `PTW-032` | `test_pmp_deny_walk_abort` | `modify` | 归 PTW PMP deny；必须按 fst/scd/thd、original type、M-mode L-bit 检查 no LSU/no CHK/access fault。 |
| `PTW-033` | `test_sysmap_hit_bypass_walk` | `re-scope` | 归 system sysmap/direct-map；PTW 只测 MAEE=0 refill 属性和降级。 |
| `PTW-034` | `test_satp_multi_switch_stress` | `modify` | 只能作为 stress；需绑定 satp clear-only/abort/context cover bins 后关闭。 |
| `TWU-001` | `test_twu_idle_state` | `keep + modify` | 保留 idle smoke；补 mask/ready/valid hold cover，不能替代功能路径。 |
| `XBAR-001` | `test_xbar_1to4_distribution` | `modify` | 按 hash target 检查，不按 idle scan/round-robin。 |
| `XBAR-002` | `test_xbar_twu_round_robin` | `modify/delete` | 删除 round-robin expected，改 hash distribution/ready hold。 |
| `PDE-001` | `test_pde_cache_l2_single_entry` | `modify` | 绑定 `PDE-TP-003/004/009/010` 等精确规则。 |
| `PDE-002` | `test_pde_cache_l1_single_entry` | `modify` | 绑定 `PDE-TP-001/002/009/010` 等精确规则。 |
| `PDE-003` | `test_pde_cache_clear_on_ptw_reset` | `modify` | reset 清 PDE + flush in-flight；还需 satp/PMP clear no-flush 对照。 |
| `SYSMAP-PTW-001` | `test_sysmap_vs_ptw_priority` | `re-scope` | system sysmap 优先级，不关闭 PTW MAEE=0 refill/degrade。 |
| `SYSMAP-PTW-002` | `test_sysmap_multi_region_coverage` | `re-scope + auxiliary` | 可作为 sysmap 配置/flag 辅助，PTW 关闭需 leaf refill source-side evidence。 |
| `SYSMAP-PTW-003` | `test_sysmap_no_walk_required` | `re-scope` | direct-map no-walk，不属于 PTW walk requirement。 |
| `PERF-PTW-001` | `test_ptw_walk_latency` | `keep as perf` | 性能统计不关闭功能 requirement；latency 阈值不得替代 correctness。 |
| `RANDOM-PTW-001` | `test_ptw_random_walk_10k_seed` | `keep as random` | 只有绑定 `PTW-AUD-*`/`PTW-FLOW-*` cover bins 命中后才算 closure。 |

TC-GAP/F4 internal 条目按以下规则处理：

| Legacy gap ID | 包含测试点 | 本文归属 | 必须修正/关闭方向 |
| --- | --- | --- | --- |
| `TC-GAP-PTW-001` | `TC-TWU-CSR-FSM-001`、`TC-TWU-CSR-REFILL-001`、`TC-TWU-DATA-RDY-001` | `modify` | 归 TWU/MAEE/refill wait 检查；需绑定 leaf level、MAEE path、refill grant/wait，不替代 MAEE 4K/degrade correctness。 |
| `TC-GAP-PTW-002` | `TC-PMBUF-FFZ-001`、`TC-PMBUF-RR-001`、`TC-PMBUF-ITLB-SLOT-001`、`TC-PMBUF-MULTI-TWU-001`、`TC-PMBUF-DEDUP-001`、`TC-PMBUF-WB-FAIR-001` | `modify` | FFZ/RR/ITLB slot 可归 `MBUF-TP-001/002`；dedup 不是当前 PTW spec requirement，需删除强 expected 或转为 implementation-only coverage。 |
| `TC-GAP-PTW-003` | `TC-MBUF-FSM-001` | `keep + modify` | 作为 mbuf FSM/SVA coverage；必须与 CHK not ready、bus error、abort clear、entry release 条件交叉。 |
| `TC-GAP-PTW-004` | `TC-PDE-ASID-STALE-001`、`TC-PDE-MUX-001`、`TC-PDE-CLR-001` | `modify` | PDE cache 不存 ASID；“ASID match”旧口径删除，改 satp change clear-only、双命中 mux、reset/abort/satp/PMP clear 差异。 |
| `TC-GAP-PTW-005` | `TC-PMBUF-LSU-CHN-001`、`TC-PMBUF-MULTI-RESP-001`、`TC-PMBUF-NO-DEADLOCK-001` | `modify` | 归 LSU single outstanding/no tag/in-order/forward progress；multi-response 不能建模为合法 OOO。 |
| `TC-GAP-PTW-006` | `TC-TWU-ADDR-BOUND-001` | `keep as boundary` | 作为 VPN/PPN/PA 边界 smoke；需不引入 PPN 超范围检查。 |
| `TC-GAP-PTW-007` | `TC-AD-A-PGFLT-001`、`TC-AD-D-PGFLT-001`、`TC-AD-TRAP-ONLY-001` | `modify` | 归 `PTW-ADD-018/019/033`；A=0 all leaf fault，store D=0 fault，PFU 不检查 D。 |
| `TC-GAP-PTW-008` | `TC-PTW-ABORT-001`、`TC-PTW-ABORT-BCAST-001`、`TC-PMBUF-BUSERR-FAIR-001` | `split + modify` | 归 abort/LSU matrix；补 abort 同拍 data/bus_error、pre-existing exception visible、bus error no CHK。 |
| `TC-GAP-PTW-009` | `TC-SATP-WALK-CONSIST-001` | `modify` | 按 satp clear-only/in-flight not flushed 建模；普通 UVM 可约束 ASID/PPN change with abort。 |
| `TC-GAP-PTW-010` | `TC-PTW-BUSY-CONSIST-001`、`TC-PTW-WATCHDOG-001` | `keep as liveness/stress` | 不关闭具体功能；作为 no-deadlock/forward-progress 辅助。若 `tlb_busy` 指 L1DTLB busy，则重归属 L1DTLB。 |
| `TC-GAP-PTW-011` | `TC-PMP-MIDWALK-001`、`TC-SYSMAP-MIDWALK-001` | `modify` | PMP change 只清 PDE cache、不 flush；sysmap/MAEE 使用点采样，进入 sysmap 后不回退。 |
| `TC-GAP-PTW-012` | `TC-PTE-RSW-001`、`TC-MBUF-MULTI-LEVEL-001`、`TC-CSR-REFILL-PRIO-001` | `modify` | RSW 进 flg 且 no fault；multi-level 覆盖 fst/scd/thd lvl；CSR/refill priority 归 assertion/monitor。 |
| `TC-GAP-PTW-013` | `TC-WAKEUP-COMPLETE-BCAST-001` | `re-scope` | 归 L1DTLB wakeup consumer-side；不关闭 PTW requirement。 |

### 13.7 必须删除、重归属或改名的旧测试点

| Action ID | 现有项 | 问题 | 正确处理 |
| --- | --- | --- | --- |
| `PTW-DEL-001` | `PTW-013 test_mbuf_credit_management` 中 “MBUF 8 entry 满后反压新 TWU” | PTW spec 不定义 MBUF full backpressure。DTLB/PFU outstanding 由上游 credit/L2TLB miss buffer 约束，PTW mbuf 不以 full 作为新 request ready 需求。 | 删除 full-backpressure expected；若保留，改成 no-overflow、entry 不覆盖、upstream-bound 和 LSU single outstanding 检查。 |
| `PTW-DEL-002` | `test_mbuf_full_backpressure.svh` | 若 expected 为 PTW MBUF full -> backpressure，则与 spec 冲突；若实际测 L1DTLB MB full，则作用域错误。 | 从 PTW source-side closure 删除或重归属 L1DTLB；不得作为 PTW MBUF 需求关闭。 |
| `PTW-DEL-003` | `PTW-014 test_mbuf_ooo_response`、`test_mbuf_ooo_response.svh`、`ptw_mem_ooo_rsp_seq` | PTW->LSU PTE 通道无 tag、单 outstanding；乱序返回不是合法协议。 | 删除 OOO 正向功能目标；由 protocol SVA 关闭 no-tag、in-order、single-outstanding、addr-stable。 |
| `PTW-DEL-004` | `PTW-017 test_pte_reserved_bits` 旧 fault expected | high reserved bits 和 RSW 不触发 PTW page fault；RSW 进入 refill flg。 | 改成 positive tests：RSW no fault + flg propagation；high reserved ignored；MAEE=0 时扩展属性由 sysmap 覆盖。 |
| `PTW-DEL-005` | `PTW-030 test_wakeup_vector_dispatch` | `mmu_lsu_wakeup` 是 L1DTLB -> LSU 广播语义，不是 PTW requirement。 | 重归属 L1DTLB；PTW 只记录 refill/fault 被消费的 consumer-side evidence。 |
| `PTW-DEL-006` | `PTW-031 test_tlb_busy_stall` | `mmu_lsu_tlb_busy` 是 L1DTLB MB 在途/调度语义，不关闭 PTW ready/mbuf。 | 重归属 L1DTLB；从 PTW MBUF/ready closure 删除。 |
| `PTW-DEL-007` | `PTW-033 test_sysmap_hit_bypass_walk`、`SYSMAP-PTW-001/003` | sysmap hit 绕过 walk 是 system direct-map/sysmap 路径，不是 PTW MAEE=0 leaf refill 属性路径。 | 重归属 system sysmap；PTW 只保留 MAEE=0 sysmap flg、4K sysmap、1G/2M degrade。 |
| `PTW-DEL-008` | 旧 “PTW PMP fetch 恒 0/统一按 R-bit 检查” | PMP 权限必须跟随原始 request type，fetch 看 X、load/PFU 看 R、store 看 W。 | 修改 `test_ptw_pmp_fetch_zero` 名称/expected，变成 original-type permission/sideband 测试。 |
| `PTW-DEL-009` | `test_xbar_twu_round_robin` 的 round-robin expected | xbar 选择由 hash 定义，不是 round-robin。 | 改名为 hash distribution/coverage 或删除 round-robin 检查。 |
| `PTW-DEL-010` | PTE tests 中 “R=W=0 一律 access fault” | PTE fault 是 page fault；`R=0,W=0,X=0` 在 fst/scd 可为合法非叶，thd 非叶才 page fault；X-only leaf 可合法。 | 拆成 non-leaf、thd non-leaf、leaf permission/write-only matrix。 |

### 13.8 必须修改或拆分的现有测试点

| Action ID | 现有测试点 | 必须修改的内容 | 关闭标准 |
| --- | --- | --- | --- |
| `PTW-MOD-001` | `test_pte_rw_both_zero` | 拆成 fst/scd 合法非叶、thd 非叶 page fault、leaf write-only、X-only leaf、不同 access type。 | 每个子用例显式记录 PTE V/R/W/X、level、type、MXR，并比较 page fault/refill。 |
| `PTW-MOD-002` | 所有调用 `ptw_mem_illegal_pte_seq` 的 PTE wrapper | 不允许默认 `fault_kind="V_OFF"` 关闭其它 fault。每个 wrapper 必须显式设置 `fault_kind`、level、page size、type、MXR/SUM/MPRV/MPP。 | log/coverage 能证明目标 fault_kind 被命中。 |
| `PTW-MOD-003` | `page_table_builder.inject_fault()` | `RESERVED_BITS` 改名/拆分为 `RSW_NONZERO` 和 `HIGH_RESERVED_NONZERO`；实现 `MISALIGNED_1G/2M`、leaf/non-leaf、fst/scd/thd、PFU-specific PTE 构造。 | 不能再用 RSW 模拟 high reserved；misaligned 必须真实破坏 PPN 对齐。 |
| `PTW-MOD-004` | `mmu_ref_model.svh` / `ptw_source_ref_model` | 按本文 §13.1 更新或新增 PTW source-side API：不检查 reserved/RSW/strong-order；write-only 公式；store 不要求 R；PFU 不按 load 检查 R/MXR/D；PMP 检查 PTE PA 而非 final PA；RSW/G/flg；MAEE/sysmap/degrade；PDE cache；type/id 返回目标。 | Directed PTE/PFU/MAEE/PDE/PMP tests 不因旧标准 Sv39 或 consumer-only 模型误报/漏报。 |
| `PTW-MOD-005` | `test_pte_misaligned_ppn_1g/2m` | 明确 1G leaf 要 `PPN[1:0]==0`，2M leaf 要 `PPN[0]==0`；MAEE=0 时仍先 page fault。 | page fault 输出，无 sysmap/degrade/refill/下级访问。 |
| `PTW-MOD-006` | `test_pte_global_bit_asid` | 拆成 leaf G、non-leaf G、PDE hit 后 leaf G；检查 raw G 不进 data flg。 | global 等于当前 leaf G；非叶 G 不向下 OR。 |
| `PTW-MOD-007` | PDE cache smoke tests | 补双命中选第二级、lookup/update 同拍、非叶 no-fault update、page fault/bus error/abort 不 update、satp/PMP clear no-flush。 | PDE monitor/SVA 有对应 cover/assertion evidence。 |
| `PTW-MOD-008` | `test_satp_switch_during_walk`、`test_ptw_satp_load_dual_switch` | 区分 SATP 使用点、PDE clear-only 和 tlboper abort。 | satp 任意字段改变下一拍清 PDE valid；不 flush in-flight；普通 UVM 可约束 ASID/PPN 改变伴随 abort。 |
| `PTW-MOD-009` | `test_sfence_abort_walk` | 改名或描述为 `tlboper_ptw_abort`；拆出无 outstanding、有 outstanding、same-cycle data、same-cycle bus_error、pre-existing exception grant、PDE update blocked。 | abort 后无 stale refill/PDE update；LSU outstanding 保持到返回；新 bus error 不上报。 |
| `PTW-MOD-010` | `test_bus_error_terminate` | 不再写“所有关联 TWU 获得错误”。LSU bus error 只对应 mbuf entry 原始 type/id 的 access fault。 | bus error 不进 CHK、不 page fault、不 refill；entry 释放等待异常寄存器写成功；access fault 优先。 |
| `PTW-MOD-011` | `pmp_twu_tests_v6` legacy names | 改成 original type permission、fst/scd/thd level、MPRV effective mode、M-mode L=0/L=1。 | PMP deny 后无 mbuf/LSU/CHK；allow 后按正常 walk。 |
| `PTW-MOD-012` | `maee_twu_tests`、phase13 sysmap tests | 补 THD/4K 可观测性、1G->4K、flag order、no-lower-walk、进入 sysmap 后 MAEE 不回退。 | MAEE=0 all sizes 属性来自 sysmap；MAEE=1 all sizes 来自 PTE。 |
| `PTW-MOD-013` | `test_xbar_twu_round_robin`、`test_xbar_1to4_distribution` | round-robin expected 改为 hash：`vpn[1:0]^vpn[10:9]^vpn[19:18]^vpn[26:25]`。 | 目标 TWU 与 hash 一致；target not ready 时 ready low 且 request fields stable。 |
| `PTW-MOD-014` | L1DTLB PTW-related tests | `DTLB_REFILL_*`、`DTLB_MB_PGFLT_*`、`DTLB_ACCESS_FAULT_*` 标为 consumer-only；busy/wakeup/MB alloc/full 归 L1DTLB。 | PTW closure report 不用 consumer-only 代替 source-side checker。 |

### 13.9 必须新增的 PTW directed 测试点

| Testpoint ID | 建议测试名 | Spec 来源 | 必须驱动的场景 | Expected behavior / 必须观察点 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| `PTW-ADD-001` | `test_ptw_pte_rsw_no_fault_flg_001` | §1.4, §6.4 | leaf PTE `RSW[1:0] != 0`，其它权限合法；MAEE=0/1 各至少一组。 | 不产生 page/access fault；refill data `flg` 包含 RSW；RSW 不影响 global/tag。 | P0 |
| `PTW-ADD-002` | `test_ptw_pte_high_reserved_ignored_001` | §1.3, §6.4 | `PTE[58:38]` 非零，覆盖 leaf/non-leaf、MAEE=0/1。 | 不因 high reserved bits fault；MAEE=0 时扩展属性仍被 sysmap 覆盖。 | P0 |
| `PTW-ADD-003` | `test_ptw_pte_g_leaf_only_001` | §2.2, §3.1 | 非叶 G=1/leaf G=0，另组 leaf G=1，覆盖 PDE hit path。 | `global` 只等于 leaf G；raw G 不进入 data flg；PDE cache 不存 G。 | P0 |
| `PTW-ADD-004` | `test_ptw_req_type_success_targets_001` | §2.1-2.2 | fetch/load/store/PFU 成功 walk，覆盖 1G/2M/4K。 | fetch refill L1ITLB+L2TLB；load/store refill L1DTLB+L2TLB；PFU 只 refill L2TLB；type/id 正确释放源 MB。 | P0 |
| `PTW-ADD-005` | `test_ptw_req_type_exception_targets_001` | §2.3, §12.21 | 四类 type 分别触发 page fault 和 access fault。 | 异常只携带 fault class + type/id；PFU 异常返回 L2TLB 后由 L2TLB 上报 prefetch；IUTLB id[2:0] 忽略。 | P0 |
| `PTW-ADD-006` | `test_ptw_return_priority_type_id_001` | §2.3, §9 | 同拍存在 access fault、page fault、normal refill 候选；多个 type/id 可乱序完成。 | 顶层输出 `access fault > page fault > normal refill`；scoreboard 按 `type+id` 最终匹配，不按请求顺序或固定延迟。 | P1 |
| `PTW-ADD-007` | `test_ptw_pde_cache_double_hit_l2_wins_001` | §3.2, §12.17 | 第一级和第二级 PDE cache 同时 hit。 | 选择第二级，跳过 fst/scd，直接进入 thd；最终 4K refill；不使用一级命中 PPN。 | P0 |
| `PTW-ADD-008` | `test_ptw_pde_cache_lookup_update_race_001` | §3.3, §13.2 | 同周期 lookup 和 update 同 tag。 | lookup 看到旧值，update 下一拍可见；由 monitor/SVA 检查。 | P1 |
| `PTW-ADD-009` | `test_ptw_pde_cache_update_condition_001` | §3.3 | 非叶 no fault、非叶 page fault、leaf、LSU bus error、abort 返回。 | 只有非叶且无 page fault、未被 reset/abort/flush 屏蔽时 update；leaf/thd leaf/bus error/page fault/abort 不 update。 | P0 |
| `PTW-ADD-010` | `test_ptw_pde_cache_satp_pmp_clear_no_abort_001` | §3.4, §11.2-11.3, §12.22 | satp 任意字段改变、PMP 配置改变发生在 in-flight walk 中。 | 下一拍 PDE entry valid 清 0；不 flush TWU/mbuf/refill/expt；旧 walk 后续非叶 no-fault 允许重新 update。 | P0 |
| `PTW-ADD-011` | `test_ptw_pde_cache_abort_reset_matrix_001` | §3.4, §11.1, §11.4 | reset、`tlboper_ptw_abort`、satp change、PMP change 四类事件。 | reset/abort 清 PDE 并 flush in-flight；satp/PMP 只清 PDE；abort 阻止 lookup/update/refill。 | P0 |
| `PTW-ADD-012` | `test_ptw_xbar_hash_ready_hold_001` | §4, §13.2 | hash 目标 TWU not ready，覆盖单目标 mask、四路全 mask、非目标 TWU mask 不影响当前 hash 请求，L2TLB valid 保持多拍。 | hash 目标被 mask 时 PTW ready 拉低；非 hash 目标 mask 时当前请求可被 accept；L2TLB `vpn/type/id` 稳定；unmask 后同一请求被 accept；目标 TWU 符合 hash。 | P0 |
| `PTW-ADD-013` | `test_ptw_pmp_deny_by_level_no_lsu_001` | §5.1, §12.9-12.11 | fst/scd/thd 分别 PMP deny。 | 不写 mbuf、不发 LSU、不进 CHK、不 page fault、不 refill；最终 access fault 携带 type/id。 | P0 |
| `PTW-ADD-014` | `test_ptw_pmp_original_type_perm_001` | §5.1 | fetch/load/store/PFU 的 PMP flg 分别 deny/allow。 | fetch 看 X；load/PFU 看 R；store 看 W；effective M 且 L=0 bypass，L=1 仍按权限判断。 | P0 |
| `PTW-ADD-015` | `test_ptw_mprv_mpp_m_no_ptw_fetch_real_priv_001` | §7, §12.23 | load/store/PFU，`MPRV=1 && MPP=M`；fetch 同时设置 MPRV。 | data/PFU direct-map 且无 PTW source request；fetch 忽略 MPRV、按真实流水线 privilege 判断是否进入 PTW。 | P0 |
| `PTW-ADD-016` | `test_ptw_nonleaf_rule_by_level_001` | §6.1-6.2 | fst/scd/thd 非叶 `R=0,X=0`，覆盖 `V=0`、write-only、合法 pointer。 | fst/scd 合法 pointer 继续下一级；`V=0`/write-only page fault；thd 仍非叶 page fault。 | P0 |
| `PTW-ADD-017` | `test_ptw_write_only_mxr_matrix_001` | §6.3 | `W=1,R=0,X=0/1,MXR=0/1` 组合，fetch/load/store/PFU。 | 只在 `W && !(R || (MXR && X))` 时触发 write-only fault；`W=1,R=0,X=1,MXR=1` 不因 write-only fault 失败，后续按 access type 权限检查。 | P0 |
| `PTW-ADD-018` | `test_ptw_leaf_access_perm_matrix_001` | §6.3 | load R/MXR/X、store W/D、fetch X、PFU 独立规则。 | load 需 R 或 MXR&&X；store 需 W 和 D；fetch 需 X；PFU 不需 R/MXR/X/D 但需 A。 | P0 |
| `PTW-ADD-019` | `test_ptw_leaf_ad_us_sum_matrix_001` | §6.3, §7 | A=0、D=0、U/S/SUM、effective U/S/M 组合。 | 所有 leaf 要 A=1；store 要 D=1；S 访问 U 且 SUM=0 fault；U 访问 S fault；effective M 跳过 U/S。 | P0 |
| `PTW-ADD-020` | `test_ptw_huge_align_before_degrade_001` | §6.3, §10.8 | 1G/2M leaf PPN 错位且 MAEE=0，sysmap 首尾可能跨区。 | 先 page fault；不进入 sysmap/degrade；不 refill，不访问下一级。 | P0 |
| `PTW-ADD-021` | `test_ptw_mbuf_entry_alloc_priority_001` | §8.1 | IUTLB 与 DTLB/PFU 同拍写 mbuf，entry0-7 轮转，entry8 fetch 专用。 | IUTLB 优先写 entry8；DTLB/PFU 只用 entry0-7；指针 one-hot 左移；不覆盖 valid entry。 | P1 |
| `PTW-ADD-022` | `test_ptw_mbuf_chk_not_ready_hold_001` | §8.3 | LSU 普通 PTE 返回时目标 CHK not ready。 | mbuf 保存 64-bit PTE 并置 get；ready 后送回；不重复发 LSU；其它 entry 可继续推进。 | P1 |
| `PTW-ADD-023` | `test_ptw_lsu_bus_error_priority_001` | §8.4, §9, §12.18 | LSU bus error 与 TWU access fault/page fault/refill 并发。 | bus error 不进 CHK；写 access exception 后释放 entry；顶层 access fault 优先；不 update PDE。 | P0 |
| `PTW-ADD-024` | `test_ptw_abort_lsu_outstanding_matrix_001` | §11.4-11.5, §12.19 | abort 前一拍 req valid=0/1；abort 同拍 data_vld；abort 同拍 bus_error；已有异常寄存器 grant。 | 需要保持 req/PA 的场景保持到返回；普通 data 丢弃；新 bus_error 不上报；已获授权异常可见；无 refill/PDE update。 | P0 |
| `PTW-ADD-025` | `test_ptw_maee1_ext_attr_all_sizes_001` | §10.1 | MAEE=1，1G/2M/4K leaf PTE 扩展属性不同。 | refill 扩展属性来自 raw PTE `{So,C,B,Sh,Sec}`；不查 sysmap，不降级。 | P0 |
| `PTW-ADD-026` | `test_ptw_maee0_4k_sysmap_refill_001` | §10.2, §12.8 | MAEE=0，4K leaf，THD path。 | 4K 不降级但必须查 sysmap；refill 属性来自 sysmap；需要 THD/4K 直接可观测性。 | P0 |
| `PTW-ADD-027` | `test_ptw_maee0_1g_degrade_matrix_001` | §10.4-10.7 | 1G no-cross、1G->2M、1G->4K。 | 降级后 PPN/page_size 正确；不访问下一级页表；权限/G/RSW/A/D/U/X/W/R/V 来自原 1G leaf。 | P0 |
| `PTW-ADD-028` | `test_ptw_maee0_2m_degrade_matrix_001` | §10.4, §10.8 | 2M no-cross、2M->4K。 | page_size/PPN/flg 正确；不访问第三级页表；权限/G/RSW/A/D/U/X/W/R/V 来自原 2M leaf。 | P0 |
| `PTW-ADD-029` | `test_ptw_sysmap_flag_order_default_001` | §10.2-10.3 | 8 region flag、默认属性、MAEE=0 refill。 | refill 扩展属性顺序按 `{So,C,B,Sh,Sec}`；sysmap 无命中/多命中若不支持，需 constraint/waiver。 | P1 |
| `PTW-ADD-030` | `test_ptw_context_sampling_points_001` | §7, §13.1 | request accept 后改变 MXR/SUM/MAEE/ASID，在使用点前后组合。 | CHK 使用当前 MXR/SUM/effective privilege；refill ASID 用当前 satp；进入 sysmap 后 MAEE 改变不回退。 | P1 |
| `PTW-ADD-031` | `test_ptw_full_flow_trace_001..023` | §12.1-12.23, §13.4 | 将第 12 章 23 个完整流程逐条绑定到 test/cover/SVA。 | 每条 flow 有 stimulus、observable check、coverage bin 和 signoff 状态。 | P0 |
| `PTW-ADD-032` | `test_ptw_l1dtlb_consumer_trace_001` | §2.2-2.3 + L1DTLB audit | load/store PTW refill/page/access fault 被 L1DTLB 正确消费。 | 仅作为 consumer-side evidence；不替代 PTW source-side PTE/PMP/page-fault checker。 | P1 |
| `PTW-ADD-033` | `test_ptw_pfu_permission_matrix_001` | §6.3, §12.20-12.21 | PFU leaf PTE 覆盖 `R=0/X=0/MXR=0/D=0/A=0/U/S/SUM`。 | PFU 不要求 R/MXR/X/D；仍要求 V、A、write-only、U/S、大页对齐；异常返回 L2TLB。 | P0 |
| `PTW-ADD-034` | `test_ptw_refill_flg_bit_layout_001` | §1.4, §2.2, §10 | MAEE=1/0、RSW、G、D/A/U/X/W/R/V、sysmap flag 组合。 | data flg bit layout 与 spec 一致；G 只在 tag/global；RSW 在 flg 且不 fault；MAEE=0 属性来自 sysmap。 | P0 |
| `PTW-ADD-035` | `test_ptw_same_id_no_reuse_constraint_001` | §2.1, §13.3 | 同 id 未完成前尝试重复请求，或 random 约束检查。 | 正常 UVM 约束不复用 id；如做 negative，应证明上游不产生或被约束，不把 undefined 行为当 DUT fail。 | P2 |
| `PTW-ADD-036` | `test_ptw_bare_mode_no_request_constraint_001` | §1.1, §13.3 | Bare 模式下随机/约束检查 PTW request。 | 上游不向 PTW 发起 walk；若误入 PTW 不作为 PTW 功能 expected。 | P2 |

### 13.10 Requirement-driven PTW audit matrix

| Audit ID | PTW requirement | Spec source | Required scenario | Expected behavior | 现有 test/plan 映射 | 状态 | 必须动作 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `PTW-AUD-001` | RSW/high reserved/strong-order 不参与 PTW page fault | §0, §1.4, §6.4 | RSW 非零、高 reserved 非零、strong-order 属性组合 | 不 fault；RSW 进 refill flg；high reserved ignored | `test_pte_reserved_bits` | `modify` | 删除旧 fault expected，落地 `PTW-ADD-001/002/034`。 |
| `PTW-AUD-002` | raw G 只生成 global/tag | §2.2, §3.1 | 非叶 G=1/leaf G=0；leaf G=1；PDE hit | global=leaf G；data flg 无 G；不 OR 非叶 G | `test_pte_global_bit_asid` | `split` | 落地 `PTW-ADD-003/034`。 |
| `PTW-AUD-003` | 请求 type 成功返回目标 | §2.1-2.2 | fetch/load/store/PFU success | 目标分别为 L1ITLB+L2、L1DTLB+L2、L1DTLB+L2、L2 only | success smoke、L1DTLB consumer | `add` | 落地 `PTW-ADD-004`。 |
| `PTW-AUD-004` | 异常返回 type/id 与 PFU/IUTLB 规则 | §2.3, §12.21 | 各 type page/access fault；IUTLB id low bits | 异常按 type/id 定位；PFU 返回 L2TLB；IUTLB 忽略 L1 id | L1DTLB fault tests | `add` | 落地 `PTW-ADD-005/006`。 |
| `PTW-AUD-005` | PDE cache hit/miss/双命中选择 | §3.1-3.2 | miss、L1 hit、L2 hit、L1+L2 hit | L1 hit 跳 fst；L2 hit 跳 fst/scd；双 hit 选 L2 | PDE/ptw_l* tests | `modify` | 落地 `PTW-ADD-007`，补 skip-level monitor。 |
| `PTW-AUD-006` | PDE cache update 条件与时序 | §3.3, §13.2 | 非叶 no fault、fault、leaf、lookup/update same cycle | 只更新合法非叶；同拍 lookup 旧值；update 下拍生效 | PDE smoke/SVA mentions | `add` | 落地 `PTW-ADD-008/009`。 |
| `PTW-AUD-007` | reset/satp/PMP/abort 清理差异 | §3.4, §11 | 四类事件覆盖 in-flight walk | reset/abort flush；satp/PMP only clear PDE；old walk 可 update | `test_satp_switch_during_walk`、`test_sfence_abort_walk` | `split` | 落地 `PTW-ADD-010/011/024`。 |
| `PTW-AUD-008` | xbar hash 与 ready/backpressure | §4 | hash target not ready；non-target masked；all masked；unmask | hash 目标 mask -> ready low；非目标 mask 不阻塞当前请求；L2 fields hold；hash target 正确 | `XBAR-001/002`、ready tests | `modify` | 删除 round-robin/idle-first expected，落地 `PTW-ADD-012`。 |
| `PTW-AUD-009` | PMP 检查对象与 deny 终止 | §5.1, §12.9-12.11 | fst/scd/thd PTE PA 被 PMP deny | access fault；无 mbuf/LSU/CHK/page fault/refill | pmp_twu tests | `modify` | 落地 `PTW-ADD-013`。 |
| `PTW-AUD-010` | PMP 权限使用原始 request type | §5.1 | fetch/load/store/PFU flg deny | fetch X、load/PFU R、store W；M L-bit 规则 | `test_ptw_pmp_fetch_zero` 等 | `modify` | 落地 `PTW-ADD-014`。 |
| `PTW-AUD-011` | MPRV/MPP effective privilege | §7, §12.23 | data/PFU `MPRV=1 && MPP=M`；fetch with MPRV | data/PFU direct-map/no PTW source；fetch 按真实 privilege；其它 data MPRV 非 MPP=M 组合按 effective privilege。 | pmp/mmode tests、cp0_mprv_seq | `add` | 落地 `PTW-ADD-015/030`。 |
| `PTW-AUD-012` | 非叶 PTE page fault 规则 | §6.1-6.2 | fst/scd/thd 非叶、V=0、write-only | fst/scd 合法 pointer；thd 非叶 PF；其它不检查 | `test_pte_rw_both_zero` | `modify` | 落地 `PTW-ADD-016`。 |
| `PTW-AUD-013` | Leaf PTE 权限矩阵 | §6.3 | load/store/fetch/PFU、A/D/U/S/SUM/MXR/write-only | 按本设计规则 page fault 或 refill | PTE tests/ref model | `split` | 落地 `PTW-ADD-017/018/019/033`。 |
| `PTW-AUD-014` | 巨页 PPN 对齐优先于降级 | §6.3, §10.8 | MAEE=0 且 1G/2M PPN 错位 | page fault，不进入 sysmap/degrade | misaligned/sysmap align tests | `modify` | 落地 `PTW-ADD-020`。 |
| `PTW-AUD-015` | MBUF entry 分配与 LSU single outstanding | §8.1-8.2 | IUTLB/DTLB/PFU 并发；LSU delay | entry8/entry0-7 规则；req/PA stable；single outstanding | pmbuf protocol tests | `modify` | 删除 full/OOO 旧口径，落地 `PTW-ADD-021`。 |
| `PTW-AUD-016` | CHK not ready 与 bus error | §8.3-8.4, §12.18 | normal data when CHK not ready；bus_error | normal data hold/get；bus_error access fault，不进 CHK | `test_bus_error_terminate`、mbuf ready tests | `modify` | 落地 `PTW-ADD-022/023`。 |
| `PTW-AUD-017` | Abort LSU outstanding 边界 | §11.4-11.5, §12.19 | abort 与 req/data/bus_error/expt grant 竞态 | 按 spec 保持/丢弃/上报边界 | `test_sfence_abort_walk`、tlbop tests | `split` | 落地 `PTW-ADD-024`。 |
| `PTW-AUD-018` | MAEE=1 直接属性路径 | §10.1 | 1G/2M/4K MAEE=1 | PTE 扩展属性 refill，不 sysmap/降级 | `test_mmu_twu_maee1_direct_refill` | `modify` | 落地 `PTW-ADD-025`。 |
| `PTW-AUD-019` | MAEE=0 4K sysmap refill | §10.2, §12.8 | THD 4K leaf，MAEE=0 | 4K 也查 sysmap，属性来自 sysmap | MAEE/sysmap tests | `add` | 落地 `PTW-ADD-026`。 |
| `PTW-AUD-020` | MAEE=0 1G/2M 降级 | §10.4-10.8 | no-cross、1G->2M、1G->4K、2M->4K | 降级 PPN/page size；不访问下级页表；权限来自原 leaf | phase13 sysmap tests | `modify` | 落地 `PTW-ADD-027/028/029`。 |
| `PTW-AUD-021` | 上下文采样点 | §7, §13.1 | request accept 后改变 ASID/MXR/SUM/MAEE | 在使用点读取；进入 sysmap 后 MAEE 不回退 | hot-swap/stress | `add` | 落地 `PTW-ADD-030`。 |
| `PTW-AUD-022` | 第 12 章 23 条完整流程签核 | §12.1-12.23, §13.4 | 每条 flow 独立 scenario | 每条有 test/coverage/SVA/waiver | N/A | `add` | 落地 `PTW-ADD-031`。 |
| `PTW-AUD-023` | L1DTLB 间接消费 PTW 输出 | §2.2-2.3 + L1DTLB audit | load/store PTW refill/fault 被 L1DTLB install/expt 消费 | 只作为 consumer-side evidence | L1DTLB tests | `consumer-only` | 落地 `PTW-ADD-032`，不关闭 source-side 规则。 |

### 13.11 PTE 类测试点最小矩阵

所有 PTE 类 directed test 必须显式声明以下输入维度，不能通过单一 `ptw_mem_illegal_pte_seq` 默认配置间接代表：

| 维度 | 必须覆盖的值 |
| --- | --- |
| level | `fst`、`scd`、`thd`，并区分当前级 leaf/non-leaf。 |
| page size | 1G、2M、4K；1G/2M 必须覆盖 PPN aligned/misaligned。 |
| request type | fetch/IUTLB、load、store/atomic、PFU。 |
| PTE validity | `V=0`；合法 pointer；合法 leaf；write-only；X-only；R-only；RX；RW；RWX。 |
| permission bits | `R/W/X/U/G/A/D/RSW` 独立翻转和关键交叉。 |
| CSR/context | MXR=0/1、SUM=0/1、effective U/S/M、MPRV=0/1、MPP=U/S/M、MAEE=0/1。 |
| no-check bits | `PTE[58:38]` 非零、RSW 非零、MAEE=0 时 PTE 扩展属性非零。 |
| expected class | normal refill、page fault、access fault 三类必须明确，不允许把 PTE 权限 fault 写成 access fault。 |

PTE 类测试点至少包含以下 Boolean 规则 cover/check：

```text
leaf = V && (R || X)
write_only_fault = W && !(R || (MXR && X))

nonleaf_fault =
    !V
 || write_only_fault
 || (level == thd && !leaf)

leaf_fault_fetch =
    !V || write_only_fault || !X || us_fault || !A || huge_align_fault

leaf_fault_load =
    !V || write_only_fault || (!R && !(MXR && X)) || us_fault || !A || huge_align_fault

leaf_fault_store =
    !V || write_only_fault || !W || us_fault || !A || !D || huge_align_fault

leaf_fault_pfu =
    !V || write_only_fault || us_fault || !A || huge_align_fault
```

其中 `us_fault` 必须按 effective privilege 判断：effective M 跳过 U/S；effective S 访问 U page 且 SUM=0 fault；effective U 访问 S page fault。PFU 不要求 R/MXR/X/D。

### 13.12 PDE cache 类测试点最小矩阵

PDE cache 测试不能只检查第二次访问变快或最终翻译成功，必须覆盖：

| Testpoint | Required scenario | Expected |
| --- | --- | --- |
| `PDE-TP-001` | PDE miss -> fst 非叶 no-fault | 更新一级 PDE cache，tag=`vpn[2]`，data=`PTE.PPN`。 |
| `PDE-TP-002` | 一级 hit -> scd 非叶 no-fault | 跳过 fst，进入 scd；更新二级 PDE cache，tag=`{vpn[2],vpn[1]}`。 |
| `PDE-TP-003` | 二级 hit | 跳过 fst/scd，直接进入 thd。 |
| `PDE-TP-004` | 一级和二级同时 hit | 选择二级 hit，不校验一级/二级一致性。 |
| `PDE-TP-005` | leaf PTE 返回 | 不更新 PDE cache。 |
| `PDE-TP-006` | 非叶 PTE page fault | 不更新 PDE cache。 |
| `PDE-TP-007` | LSU bus error | 不更新 PDE cache，不进入 CHK。 |
| `PDE-TP-008` | abort 同拍/期间 LSU 返回非叶 | 不更新 PDE cache。 |
| `PDE-TP-009` | lookup/update 同拍同 tag | lookup 读旧值，update 下一拍生效。 |
| `PDE-TP-010` | satp/PMP change | 下一拍 PDE valid 清 0，不 flush in-flight；旧 in-flight walk 仍可重新 update。 |
| `PDE-TP-011` | reset/tlboper abort | 清 PDE cache 并 flush in-flight；abort 屏蔽 lookup/update/refill。 |
| `PDE-TP-012` | PLRU hit/write/victim | 命中和写入更新 PLRU；invalid entry 优先，否则使用 PLRU victim。 |

XBAR/ready 测试点至少覆盖：

| Testpoint | Required scenario | Expected |
| --- | --- | --- |
| `XBAR-TP-001` | 选择不同 VPN 使 hash 结果为 TWU0/1/2/3 | `xbar_twu_req` one-hot 等于 `vpn[1:0]^vpn[10:9]^vpn[19:18]^vpn[26:25]`，不按 idle-first/round-robin。 |
| `XBAR-TP-002` | hash 目标 TWU mask=1，其他 TWU mask=0 | `xbar_pde_ready/ptw_l2tlb_ready` 拉低；PDE/L2TLB 请求字段保持；不派发到其他 TWU。 |
| `XBAR-TP-003` | hash 目标 TWU mask=0，非目标 TWU mask=1 | 当前请求可 accept；只派发到 hash 目标；非目标 mask 不影响该请求。 |
| `XBAR-TP-004` | 四路 TWU 全 mask | ready 拉低；请求保持；unmask 后同一请求继续按 hash 派发。 |
| `XBAR-TP-005` | `tlboper_ptw_abort` 与 xbar dispatch/ready stall 交叉 | abort 屏蔽未 accept 请求和后续 lookup/update/refill；不产生双派发。 |
| `XBAR-TP-006` | CSV 旧 idle-first/pointer/round-robin 测试名保留运行 | expected 必须改为 hash/ready-hold 或标 `obsolete-by-spec`，不得要求 TWU0>1>2>3、pointer fallback 或 round-robin fairness。 |

### 13.13 Mbuf、LSU 与 abort 类测试点最小矩阵

| Testpoint | Required scenario | Expected |
| --- | --- | --- |
| `MBUF-TP-001` | IUTLB 和 TWU 同拍写 mbuf | IUTLB 优先，使用 entry8；DTLB/PFU 使用 entry0-7。 |
| `MBUF-TP-002` | DTLB/PFU 多次写 entry0-7 | 指针 one-hot 左移轮转，不覆盖未释放 entry。 |
| `MBUF-TP-003` | LSU request valid 拉高 | PA 和 request valid 保持到 `lsu_mmu_data_vld` 或 bus error。 |
| `MBUF-TP-004` | 多 entry 等待 LSU | PTW->LSU 单 outstanding，无 tag，无合法 OOO response。 |
| `MBUF-TP-005` | normal data 返回且 CHK ready | data+vpn/type/id/lvl/twu_idx 送对应 CHK，entry 释放。 |
| `MBUF-TP-006` | normal data 返回但 CHK not ready | data 寄存到 entry，置 get，ready 后一次性送 CHK，不重复发 LSU。 |
| `MBUF-TP-007` | bus error 返回 | 不进 CHK，不 page fault，不 refill，不 update PDE；写 access exception 成功后 entry 释放。 |
| `MBUF-TP-008` | bus error 与 TWU access/page/refill 并发 | 顶层 access fault 优先；LSU bus error access fault 优先于 TWU access fault。 |
| `MBUF-TP-009` | `tlboper_ptw_abort` 前一拍 LSU req valid=0 | flush in-flight，PTW ready 按无 outstanding 流程恢复。 |
| `MBUF-TP-010` | `tlboper_ptw_abort` 前一拍 LSU req valid=1 | 继续保持 LSU req/PA 到返回；返回普通 data 丢弃；不 CHK、不 update、不 refill。 |
| `MBUF-TP-011` | abort 同拍 LSU bus error 新形成 | 新 bus error 不写异常寄存器，不上报。 |
| `MBUF-TP-012` | abort 前异常已在异常寄存器且当拍获顶层授权 | 异常可见并按 type/id 返回。 |

### 13.14 MAEE、Sysmap 与降级测试点最小矩阵

| Testpoint | Required scenario | Expected |
| --- | --- | --- |
| `MAEE-TP-001` | MAEE=1，1G leaf | refill 属性来自 raw PTE[63:59]，不查 sysmap。 |
| `MAEE-TP-002` | MAEE=1，2M leaf | refill 属性来自 raw PTE[63:59]，不查 sysmap。 |
| `MAEE-TP-003` | MAEE=1，4K leaf | refill 属性来自 raw PTE[63:59]，不查 sysmap。 |
| `MAEE-TP-004` | MAEE=0，1G 首尾同区 | page_size 仍 1G，属性来自 sysmap，PPN 不降级。 |
| `MAEE-TP-005` | MAEE=0，1G 首尾跨区，选中 2M 不跨区 | 降级为 2M，PPN=`{pte.ppn[2],vpn[1],9'b0}`，属性取降级 2M sysmap。 |
| `MAEE-TP-006` | MAEE=0，1G -> 2M 后仍跨区 | 降级为 4K，PPN=`{pte.ppn[2],vpn[1],vpn[0]}`，属性取最终 4K sysmap。 |
| `MAEE-TP-007` | MAEE=0，2M 首尾同区 | page_size 仍 2M，属性来自 sysmap，PPN 不降级。 |
| `MAEE-TP-008` | MAEE=0，2M 首尾跨区 | 降级为 4K，PPN=`{pte.ppn[2],pte.ppn[1],vpn[0]}`，属性取最终 4K sysmap。 |
| `MAEE-TP-009` | MAEE=0，4K leaf | 不降级但必须查 sysmap，属性来自 final PPN 所在 region。 |
| `MAEE-TP-010` | 降级路径 | 不访问下一级页表；权限、G、RSW、A/D/U/X/W/R/V 来自原始 leaf PTE。 |
| `MAEE-TP-011` | 1G/2M PPN misaligned 且 MAEE=0 | 先 page fault，不查 sysmap，不降级。 |
| `MAEE-TP-012` | MAEE 在 sysmap/degrade 中途改变 | 最终 refill 仍按进入 sysmap/degrade 时的 MAEE=0 路径，不回退到 PTE 属性。 |
| `MAEE-TP-013` | sysmap flag order | refill 扩展属性顺序固定 `{So,C,B,Sh,Sec}`。 |

### 13.15 TB、scoreboard、SVA 与覆盖率必改测试点

| Infra ID | 范围 | 必须支持的测试点 | 关闭标准 |
| --- | --- | --- | --- |
| `PTW-INFRA-001` | `mmu_ref_model.svh` / `ptw_source_ref_model` | PTW source-side PTE/PFU/PMP/PDE/MAEE/degrade/type-id/refill field reference | 与本文 §6、§7、§10、§13.1 一致；不再把 `R=0,W=1` 直接套标准 reserved fault；PFU 不按 load 权限建模；PMP 检查 PTE PA；PDE cache 和 abort/drop 可建模。 |
| `PTW-INFRA-002` | `page_table_builder.svh`、`ptw_mem_sequences.svh` | PTE bit/level/page size/fault_kind 构造 | 支持 `RSW_NONZERO`、`HIGH_RESERVED_NONZERO`、`MISALIGNED_1G/2M`、PFU matrix、leaf/non-leaf/level 显式参数。 |
| `PTW-INFRA-003` | PTW refill/expt monitor / `ptw_source_sb` | `type/id/vpn/asid/page_size/ppn/global/flg/expt_kind/target/drop_reason` 捕获 | PTW normal refill、exception 和 abort/drop 都能按 source request 匹配；IUTLB consumer 比较忽略 id[2:0] 的 L1 语义；PFU 不要求 L1 refill；`mmu_translation_sb` 只作 consumer-side evidence。 |
| `PTW-INFRA-004` | PDE cache monitor/SVA | lookup hit level、double hit、skip level、update level/tag/data、clear source、race | `PDE-TP-*` 有 assert/cover evidence。 |
| `PTW-INFRA-005` | `mmu_ptw_lsu_protocol_sva.sv` | LSU single outstanding、addr stable、no tag/in-order、abort outstanding、bus_error no CHK | `MBUF-TP-*` 有 assertion pass 和 cover hit。 |
| `PTW-INFRA-006` | `mmu_pmp_twu_sva.sv` | PMP original type、level deny、M-mode L-bit、MPRV effective mode | `PTW-AUD-009/010/011` 有 level/type/effective-mode cover。 |
| `PTW-INFRA-007` | `mmu_maee_twu_sva.sv`、`mmu_sysmap_sva.sv`、whitebox cg | MAEE=0 4K THD path、degrade PPN/page_size、flag order、no-lower-walk | `MAEE-TP-*` 有 direct evidence，不能只靠 FST/SCD 推断 4K。 |
| `PTW-INFRA-008` | `mmu_arb_sva.sv`、TWU/top arbitration monitor | access/page/refill priority、grant onehot、work-conserving、wait hold | 仲裁优先级由 assertion/monitor 关闭；scoreboard 不做固定 cycle 顺序要求。 |
| `PTW-INFRA-009` | coverage gate / regression report | `PTW-AUD-*`、`PTW-ADD-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*` 绑定 | 每个 P0/P1 row 有 directed pass + cover/SVA hit，或 bug/waiver。 |

### 13.16 第 12 章完整流程签核矩阵

第 12 章每条完整流程必须绑定到测试、checker、coverage/SVA 或 waiver。最低签核要求如下：

| Flow ID | 第 12 章流程 | 必须 evidence |
| --- | --- | --- |
| `PTW-FLOW-001` | PDE miss，1G success | fst PMP pass、fst CHK leaf、page_size=1G、PPN/flg/global/type/id 正确。 |
| `PTW-FLOW-002` | PDE miss，2M success | fst 非叶 update PDE1、scd 2M leaf、page_size=2M。 |
| `PTW-FLOW-003` | PDE miss，4K success | fst/scd 非叶 update PDE1/PDE2、thd 4K leaf。 |
| `PTW-FLOW-004` | MAEE=0，1G->2M | 1G 跨区、2M 不跨区、PPN 降级、no lower walk。 |
| `PTW-FLOW-005` | MAEE=0，1G->4K | 连续降级，最终 PPN=`{pte.ppn[2],vpn[1],vpn[0]}`。 |
| `PTW-FLOW-006` | MAEE=0，2M->4K | 2M 跨区，最终 PPN=`{pte.ppn[2],pte.ppn[1],vpn[0]}`。 |
| `PTW-FLOW-007` | MAEE=0 no degrade | 1G/2M 首尾同区，page_size 不变，属性来自 sysmap。 |
| `PTW-FLOW-008` | MAEE=0 4K sysmap | THD 4K leaf 查 sysmap，flg 属性来自 sysmap。 |
| `PTW-FLOW-009` | fst PMP access fault | 不写 mbuf、不发 LSU、不 CHK，access fault。 |
| `PTW-FLOW-010` | scd PMP access fault | fst 非叶后 scd PMP deny，access fault。 |
| `PTW-FLOW-011` | thd PMP access fault | 前两级非叶后 thd PMP deny，access fault。 |
| `PTW-FLOW-012` | fst CHK page fault | fst PTE page fault，不进入 scd。 |
| `PTW-FLOW-013` | scd CHK page fault | scd PTE page fault，不进入 thd。 |
| `PTW-FLOW-014` | thd CHK page fault | 第三级非叶或 4K leaf fault。 |
| `PTW-FLOW-015` | L1 PDE hit -> 2M | 跳过 fst，进入 scd，最终 2M。 |
| `PTW-FLOW-016` | L1 PDE hit -> 4K | 跳过 fst，scd 非叶 update PDE2，最终 4K。 |
| `PTW-FLOW-017` | L2 PDE hit -> 4K | 双命中也选 L2，直接 thd。 |
| `PTW-FLOW-018` | LSU bus error | bus error access fault，不 CHK，bus error 优先。 |
| `PTW-FLOW-019` | abort with LSU outstanding | 保持 LSU req/PA 到返回，data 丢弃，新 bus error 不上报。 |
| `PTW-FLOW-020` | PFU success | PFU 只 refill L2TLB，PTE 权限按 PFU。 |
| `PTW-FLOW-021` | PFU exception | PFU access/page fault 返回 L2TLB。 |
| `PTW-FLOW-022` | satp/PMP clear PDE | 清 PDE cache，不 flush in-flight，旧 walk 可 update。 |
| `PTW-FLOW-023` | MPRV=1 && MPP=M | data/PFU direct-map/no PTW source；fetch 不受 MPRV，按真实流水线 privilege。 |

### 13.17 L1DTLB/L2TLB 间接测试点处理规则

1. `DTLB_REFILL_*`、`DTLB_MB_PGFLT_*`、`DTLB_ACCESS_FAULT_*` 可以证明 PTW 输出被 L1DTLB 消费，但不能证明 PTW 生成的 PPN/page_size/flg/global/type/id 正确，除非同时有 PTW source-side monitor 比较。
2. `DTLB_BUSY_*`、`DTLB_WAKEUP_*`、L1DTLB MB alloc/full/credit/WFI/stale refill discard 归 L1DTLB，不进入 PTW closure。
3. L2TLB ReqQ、bank conflict、TLBOp priority、RRPV、tag/data hit tests 只能证明 L2TLB 消费或仲裁行为；PTW refill source-side 字段、PFU only-L2 目标和 type/id release 仍需 PTW monitor/scoreboard。
4. IFU/IUTLB fetch fault/refill consumer tests 可作为 fetch type evidence；IUTLB id[2:0] 忽略、fetch MPRV 不生效、fetch PMP 看 X 仍需 PTW-specific checker。
5. System sysmap direct-map/bypass tests 归 sysmap/L1DTLB；PTW MAEE=0 只验证 leaf refill 属性来源和大页降级，不验证 sysmap hit 直接绕过页表 walk。

### 13.18 PTW focused regression 与签核准则

建议建立以下 focused regression 分组：

| Regression group | 必含内容 |
| --- | --- |
| `ptw_audit_pte_list` | `PTW-ADD-001..006`、`PTW-ADD-016..020`、`PTW-ADD-033/034`、修改后的 legacy PTE wrappers。 |
| `ptw_audit_pde_xbar_list` | `PTW-ADD-007..012`、`PTW-ADD-030`、PDE/xbar/ready legacy smoke。 |
| `ptw_audit_pmp_list` | `PTW-ADD-013..015`、`pmp_twu_tests_v6` 中改名后的 level/type/L-bit/MPRV tests。 |
| `ptw_audit_lsu_abort_list` | `PTW-ADD-021..024`、`ptw_lsu_protocol_tests`、修改后的 bus_error/abort tests。 |
| `ptw_audit_maee_sysmap_list` | `PTW-ADD-025..029`、`maee_twu_tests`、PTW-owned sysmap/degrade tests。 |
| `ptw_audit_flow_list` | `PTW-FLOW-001..023` representative tests 和 L1DTLB consumer-only evidence。 |

PTW 签核必须满足：

1. P0/P1 测试点 expected behavior 不得与本文 spec 冲突。
2. PTE fault/permission tests 必须显式声明 PTE bit、level、page size、access type、MXR/SUM/MPRV/MPP/effective privilege。
3. MAEE/sysmap tests 必须说明 MAEE 值、leaf size、sysmap 首尾 region、是否降级、最终 PPN/page_size/flg。
4. abort tests 必须说明 abort 与 LSU request/data/bus_error/expt register 的相对时序。
5. PDE cache tests 必须说明 hit level、update condition、clear source、是否 flush in-flight。
6. PMP tests 必须说明 level、PTE PA、request type、PMP flg、effective mode、L-bit。
7. Random/stress 只有绑定到 `PTW-AUD-*` 或 `PTW-FLOW-*` cover bin 命中后，才可作为关闭 evidence。
8. 每个未关闭项必须有 bug ID、waiver ID 或明确 owner；不允许空白、口头说明或 “可能被 random 覆盖”。

### 13.19 当前 UVM 文件级 PTW 测试点清单

本小节按当前仓库中的 suite/include 文件列出 PTW 相关测试点的文件级归属。审核时必须逐项勾选；若文件名未在本表出现但 stimulus 或 checker 触达 PTW source-side，则按 `PTW-AUD-*`/`PTW-FLOW-*` 追加到本小节或 waiver，不允许只归到 general random。

#### 13.19.1 `ptw_tests`

| UVM test file | 处理 | 必须绑定的 PTW 测试点/修正 |
| --- | --- | --- |
| `test_ptw_satp_load_basic.svh` | `modify` | `PTW-AUD-021`、`PTW-FLOW-001..003`；检查 root PPN 使用点，不锁存不存在的全上下文。 |
| `test_ptw_satp_load_dual_switch.svh` | `modify` | `PTW-AUD-007/021`；后续 walk 用新 root，in-flight 行为按 satp clear-only/abort 分拆。 |
| `test_satp_switch_during_walk.svh` | `split` | `PTW-ADD-010/030`、`PTW-FLOW-022`；satp 只清 PDE cache，不自动 flush TWU/mbuf。 |
| `test_sfence_abort_walk.svh` | `split` | `PTW-ADD-011/024`、`MBUF-TP-009..012`；改为 `tlboper_ptw_abort` 时序矩阵。 |
| `test_ptw_l0_pte_read_basic.svh` | `modify` | `PTW-FLOW-003/008`；4K full walk 需检查 thd leaf、page_size、PPN、flg/global/type/id。 |
| `test_ptw_l0_pte_permission_check.svh` | `split` | `PTW-ADD-016..019/033`；拆 fetch/load/store/PFU 权限矩阵。 |
| `test_pte_v_bit_zero.svh` | `modify` | `PTW-AUD-012/013`；显式 level/type，expected 为 page fault。 |
| `test_pte_rw_both_zero.svh` | `split` | `PTW-ADD-016/017`；区分合法非叶、thd 非叶、write-only、X-only。 |
| `test_pte_u_bit_sum_interaction.svh` | `modify` | `PTW-ADD-019/030`；覆盖 effective U/S/M、SUM、MPRV/MPP。 |
| `test_pte_x_bit_mxr_mix.svh` | `modify` | `PTW-ADD-017/018/033`；load MXR、fetch X、PFU 独立规则分开检查。 |
| `test_pte_reserved_bits.svh` | `modify` | `PTW-ADD-001/002/034`；删除 reserved/RSW fault expected，改 positive propagation。 |
| `test_pte_global_bit_asid.svh` | `split` | `PTW-ADD-003/034`；leaf G 只进 global/tag，非叶 G 不 OR，G 不进 flg。 |
| `test_pte_misaligned_ppn_1g.svh` | `modify` | `PTW-ADD-020`、`MAEE-TP-011`；真实 1G leaf `PPN[1:0] != 0`，page fault before sysmap。 |
| `test_pte_misaligned_ppn_2m.svh` | `modify` | `PTW-ADD-020`、`MAEE-TP-011`；真实 2M leaf `PPN[0] != 0`，page fault before sysmap。 |
| `test_huge_page_1g_direct.svh` | `keep + modify` | `PTW-FLOW-001/007`、`MAEE-TP-001/004`；检查 page_size=1G、PPN/flg/global。 |
| `test_huge_page_2m_direct.svh` | `keep + modify` | `PTW-FLOW-002/007`、`MAEE-TP-002/007`；检查 fst nonleaf update、scd leaf、2M 对齐。 |
| `test_huge_page_4k_full_walk.svh` | `keep + modify` | `PTW-FLOW-003/008`、`MAEE-TP-003/009`；补 MAEE=0 4K sysmap。 |
| `test_huge_page_mixed.svh` | `keep + modify` | `PTW-FLOW-001..008`；作为 mixed smoke，必须绑定 1G/2M/4K cover bins。 |
| `test_ptw_l1_pde_hit.svh` | `modify` | `PDE-TP-002`、`PTW-FLOW-015/016`；证明跳 fst 进 scd。 |
| `test_ptw_l1_pde_miss_walk.svh` | `modify` | `PDE-TP-001/002`；区分 fst 非叶 update PDE1 与后续 scd/thd。 |
| `test_ptw_l1_pde_cache_replace.svh` | `modify` | `PDE-TP-012`；invalid-first/PLRU victim/hit-write PLRU。 |
| `test_ptw_l2_pde_hit_direct.svh` | `modify` | `PDE-TP-003/004`、`PTW-FLOW-017`；二级 hit 跳 fst/scd，双命中选二级。 |
| `test_ptw_l2_pde_miss_walk.svh` | `modify` | `PDE-TP-001..003`；miss 后完整 PMP/LSU/CHK/update/refill 可观测。 |
| `test_ptw_l2_pde_cache_replace.svh` | `modify` | `PDE-TP-012`；二级 PDE PLRU/invalid/victim。 |
| `test_pde_cache_l1_single_entry.svh` | `modify` | `PDE-TP-001/002/009/010`；不能只看翻译成功。 |
| `test_pde_cache_l2_single_entry.svh` | `modify` | `PDE-TP-003/004/009/010`；补双命中与 lookup/update race。 |
| `test_pde_cache_clear_on_ptw_reset.svh` | `modify` | `PDE-TP-010/011`；reset/abort 与 satp/PMP clear-only 分开。 |
| `test_mmu_pde_cache_hit_l2_skip_scd.svh` | `modify` | `PDE-TP-003/004`；文件名口径需对齐：L2 PDE hit 应跳 fst/scd 进 thd。 |
| `test_mmu_pde_cache_hit_l3_skip_thd.svh` | `modify/rename` | 若指二级 PDE hit，不存在 “skip thd”；应改成 final thd path/4K leaf 检查。 |
| `test_mmu_pde_cache_full_miss_full_ptw.svh` | `keep + modify` | `PTW-FLOW-001..003`；full miss smoke 需绑定非叶 update 和 leaf refill fields。 |
| `test_xbar_1to4_distribution.svh` | `modify` | `PTW-ADD-012`；按 hash 分发，不按 idle scan 或 round-robin。 |
| `test_xbar_twu_round_robin.svh` | `modify/delete` | 删除 round-robin expected；重命名为 hash distribution/ready hold。 |
| `test_mmu_ptw_ready_all_mask_low.svh` | `keep + modify` | `PTW-ADD-012`；四路全 mask 时 ready low，同时补 hash 目标单独 mask 与非目标 mask 对照。 |
| `test_mmu_ptw_ready_one_unblock.svh` | `keep + modify` | `PTW-ADD-012`；unmask 后同一请求被 hash target accept。 |
| `test_mmu_ptw_ready_l2tlb_stall.svh` | `keep + modify` | `PTW-ADD-012`；valid/ready stall 期间 vpn/type/id 稳定。 |
| `test_twu_concurrent_4way.svh` | `keep + modify` | `PTW-AUD-003/008/015`；并发必须按 hash、type/id、独立 wait 检查。 |
| `test_twu_concurrent_same_vpn.svh` | `modify` | `PTW-ADD-035`；删除 same VPN dedup 强 expected，按 id 不复用约束。 |
| `test_twu_idle_state.svh` | `keep + modify` | `PTW-AUD-008`；idle/mask/ready/valid hold coverage。 |
| `test_mmu_twu_idle_implies_no_mask.svh` | `keep + modify` | `PTW-AUD-008`；idle 与 mask 语义只作 ready/dispatch evidence。 |
| `test_bus_error_terminate.svh` | `modify` | `PTW-ADD-023`、`MBUF-TP-007/008`、`PTW-FLOW-018`；bus error 不进 CHK、不 update PDE。 |
| `test_mmu_twu_pgflt_bypass_arb.svh` | `keep + modify` | `PTW-AUD-013`、`PTW-INFRA-008`；page fault 输出与仲裁分离检查。 |
| `test_mmu_twu_accerr_bypass_arb.svh` | `keep + modify` | `PTW-AUD-009/016`、`PTW-INFRA-008`；access fault 优先级与 type/id。 |
| `test_mmu_twu_except_conflict_pgflt_accflt.svh` | `modify` | `PTW-ADD-006/023`；同一请求 bus error 不会再进 CHK，跨请求仲裁按 access>page>refill。 |
| `test_mmu_arb_refill_except_priority.svh` | `keep + modify` | `PTW-ADD-006`、`PTW-INFRA-008`；access fault > page fault > refill。 |
| `test_mmu_arb_grant_onehot_check.svh` | `keep` | `PTW-INFRA-008`；grant onehot assertion/cover。 |
| `test_mmu_arb_multi_twu_fairness.svh` | `keep as liveness` | 不关闭具体功能 requirement；只作 no-starvation/forward-progress evidence。 |
| `test_mmu_arb_vpn_match_tag_din.svh` | `modify` | `PTW-ADD-004/034`；refill tag/vpn/asid/global/data flg 字段匹配。 |
| `test_mmu_arb_pgs_bank_select.svh` | `modify` | `PTW-FLOW-001..008`；page size 编码与 L2TLB bank 选择均需可观测。 |
| `test_arb_ptw_priority_highest.svh` | `keep + re-scope` | L2TLB/TLBOp/PFU 仲裁优先级 evidence；不替代 PTW 输出生成规则。 |
| `test_arb_tlboper_above_prefetch.svh` | `keep + re-scope` | L2TLB arbiter evidence；PTW 只取 abort/refill 交互部分。 |
| `test_arb_reqq_preempt_lower.svh` | `re-scope` | 归 L2TLB arbiter，作为 PTW consumer-side。 |
| `test_arb_backpressure_mask.svh` | `re-scope + auxiliary` | 归 L2TLB/arbiter backpressure；PTW ready/source-side 仍用 `PTW-ADD-012`。 |
| `test_arb_bank_conflict_resolution.svh` | `re-scope` | 归 L2TLB bank conflict。 |
| `test_arb_no_double_grant.svh` | `keep + auxiliary` | 仲裁 SVA evidence；不替代 PTW transaction checker。 |
| `test_arb_work_conserving.svh` | `keep as liveness` | 只作 forward-progress，不关闭 PTE/PMP/MAEE correctness。 |
| `test_arb_skew_index_generation.svh` | `re-scope` | 归 L2TLB bank/hash，不是 PTW xbar hash。 |
| `test_mbuf_credit_management.svh` | `delete/modify` | 删除 MBUF full backpressure expected；改 no-overwrite/upstream credit/entry allocation。 |
| `test_mbuf_full_backpressure.svh` | `delete/re-scope` | PTW spec 无 MBUF full backpressure；若测 L1DTLB MB full，转 L1DTLB。 |
| `test_mbuf_ooo_response.svh` | `delete` | LSU OOO response 非合法 PTW PTE 通道协议。 |
| `test_mmu_mbuf_ready_gate_no_early_vld.svh` | `keep + modify` | `MBUF-TP-005/006`；CHK not ready hold/get。 |
| `test_mmu_mbuf_have_no_resend.svh` | `keep + modify` | `MBUF-TP-006`；ready 后一次性送 CHK，不重复发 LSU。 |
| `test_mmu_mbuf_multi_twu_independent_ready.svh` | `keep + modify` | `MBUF-TP-001..006`；多 TWU 独立 ready，不得推导 OOO 合法。 |

#### 13.19.2 `ptw_lsu_protocol_tests`

| UVM test file | 处理 | 必须绑定的 PTW 测试点/修正 |
| --- | --- | --- |
| `test_pmbuf_serial_outstanding_001.svh` | `keep` | `MBUF-TP-003/004`；PTW->LSU single outstanding。 |
| `test_pmbuf_addr_stable_001.svh` | `keep` | `MBUF-TP-003`；LSU req/PA stable until data/bus_error。 |
| `test_pmbuf_no_tag_001.svh` | `keep` | `MBUF-TP-004`；无 tag 协议，禁止 OOO response。 |
| `test_pmbuf_inorder_resp_001.svh` | `keep` | `MBUF-TP-004`；in-order response/protocol SVA。 |
| `test_pmbuf_ptr_hold_001.svh` | `keep + modify` | `MBUF-TP-001/002/006/010`；补 entry 分配、CHK hold、abort outstanding。 |

#### 13.19.3 `pmp_twu_tests_v6`

| UVM test file | 处理 | 必须绑定的 PTW 测试点/修正 |
| --- | --- | --- |
| `test_twu_pmp_serial.svh` | `keep + modify` | `PTW-AUD-009`；fst/scd/thd PMP serialization。 |
| `test_twu_pmp_wait_stall.svh` | `keep + modify` | `PTW-AUD-009/008`；PMP wait 时 TWU mask/ready hold。 |
| `test_twu_pmp_grant_onehot.svh` | `keep` | `PTW-INFRA-006`；grant onehot assertion/cover。 |
| `test_twu_mask_pmp_wait_all4.svh` | `keep + modify` | `PTW-ADD-012/013`；4 TWU PMP wait all masked 是 ready low smoke；还需单 hash 目标 PMP wait 和非目标 wait 对照。 |
| `test_ptw_pmp_before_lsu.svh` | `keep + modify` | `PTW-ADD-013/014`；PMP deny must stop before mbuf/LSU。 |
| `test_ptw_pmp_deny_stop.svh` | `keep + modify` | `PTW-FLOW-009..011`；level-specific deny terminates walk。 |
| `test_ptw_pmp_deny_accflt.svh` | `keep + modify` | `PTW-ADD-013`；access fault class/type/id。 |
| `test_ptw_pmp_deny_no_refill.svh` | `keep + modify` | `PTW-ADD-013`；no refill/no CHK/no PDE update。 |
| `test_ptw_pmp_wait_no_lsu.svh` | `keep + modify` | `PTW-ADD-013`；PMP wait/deny before LSU req。 |
| `test_ptw_pmp_pa_1g.svh` | `keep + modify` | `PTW-AUD-009`；fst PTE PA formula and level coverage。 |
| `test_ptw_pmp_pa_2m.svh` | `keep + modify` | `PTW-AUD-009`；scd PTE PA formula。 |
| `test_ptw_pmp_pa_4k.svh` | `keep + modify` | `PTW-AUD-009`；thd PTE PA formula。 |
| `test_ptw_pmp_pa_zero.svh` | `keep as boundary` | PTE PA boundary smoke；不得引入 PPN 超范围 fault。 |
| `test_ptw_pmp_mmode_l0.svh` | `modify` | `PTW-ADD-014/015`；M-mode L-bit 和 MPRV effective M 分开。 |
| `test_ptw_pmp_fetch_zero.svh` | `modify` | `PTW-ADD-014`；按原始 request type 建模，fetch 查 X，load/PFU 查 R，store 查 W。 |
| `test_ptw_pmp_port_map_concurrent.svh` | `keep + modify` | `PTW-INFRA-006`；4 TWU PMP port map + level/type cover。 |

#### 13.19.4 `maee_twu_tests` 与 `sysmap_tests`

| UVM test file | 处理 | 必须绑定的 PTW 测试点/修正 |
| --- | --- | --- |
| `test_mmu_twu_maee0_csr_path.svh` | `modify` | `MAEE-TP-004..009`；MAEE=0 所有 page size 属性来自 sysmap。 |
| `test_mmu_twu_maee0_csr_symmetric.svh` | `modify` | `MAEE-TP-004..009/013`；补 1G/2M/4K 对称和 flag order。 |
| `test_mmu_twu_maee1_direct_refill.svh` | `modify` | `MAEE-TP-001..003`；MAEE=1 raw PTE 属性 all sizes。 |
| `test_mmu_twu_maee_dynamic_switch.svh` | `modify` | `PTW-ADD-030`、`MAEE-TP-012`；进入 sysmap/degrade 后 MAEE 改变不回退。 |
| `test_sysmap_phase13_flg_refill_region0.svh` | `keep + modify` | `MAEE-TP-009/013`；证明是 PTW leaf refill flg，不是 direct-map。 |
| `test_sysmap_phase13_flg_refill_region7.svh` | `keep + modify` | `MAEE-TP-009/013`；region7 PTW refill flg。 |
| `test_sysmap_phase13_default_flag.svh` | `modify` | `MAEE-TP-013`；默认 flag 只作配置辅助，PTW closure 需 refill source-side。 |
| `test_sysmap_phase13_cross_1g_degrade.svh` | `modify` | `MAEE-TP-005/006/010`；补 1G->4K 和 no lower walk。 |
| `test_sysmap_phase13_cross_2m_degrade.svh` | `modify` | `MAEE-TP-008/010`；2M->4K PPN/flg/page_size。 |
| `test_sysmap_phase13_no_cross_no_degrade.svh` | `modify` | `MAEE-TP-004/007`；no-cross 保持大页，属性来自 sysmap。 |
| `test_sysmap_phase13_pa_align_1g.svh` | `modify` | `MAEE-TP-011`；misaligned 先 page fault，不降级。 |
| `test_sysmap_phase13_pa_align_2m_4k.svh` | `modify` | `MAEE-TP-011`；2M misaligned page fault，4K 无大页对齐 fault。 |
| `test_sysmap_phase13_4twu_concurrent.svh` | `keep + modify` | `PTW-AUD-020`；4 TWU 并发 sysmap/degrade，type/id 独立匹配。 |
| `test_mmu_sysmap_pte_walk_addr.svh` | `auxiliary` | sysmap PTE walk address 可辅助 MAEE=0，但必须接 PTW leaf refill monitor。 |
| `test_mmu_sysmap_alignment.svh`、`test_mmu_sysmap_disabled.svh`、`test_mmu_sysmap_flag_r.svh`、`test_mmu_sysmap_flag_wxec.svh`、`test_mmu_sysmap_hit_boundary.svh`、`test_mmu_sysmap_hit_match.svh`、`test_mmu_sysmap_hit_unique.svh`、`test_mmu_sysmap_priority.svh`、`test_mmu_sysmap_priority_over_tlb.svh`、`test_mmu_sysmap_region_config.svh`、`test_mmu_sysmap_region_default.svh`、`test_mmu_sysmap_tlb_fallback.svh` | `re-scope + auxiliary` | 归 system sysmap/direct-map 配置与优先级；不关闭 PTW MAEE=0 refill/degrade。 |
| `test_sysmap_hit_bypass_walk.svh`、`test_sysmap_no_walk_required.svh`、`test_sysmap_vs_ptw_priority.svh`、`test_sysmap_multi_region_coverage.svh` | `re-scope` | direct-map/no-walk/system sysmap，不属于 PTW walk source-side。 |

#### 13.19.5 间接 PTW evidence suite

| Suite / test group | 处理 | PTW 审核用途 |
| --- | --- | --- |
| `basic_tests/test_ptw_map4k_directed.svh` | `keep + modify` | 4K smoke，可绑定 `PTW-FLOW-003/008`，但必须补 source-side fields。 |
| `basic_tests/test_mmu_phase6_rtu_flush_ptw.svh`、`flush_tests/test_reset_during_ptw_walk.svh` | `split + modify` | reset/RTU/tlboper abort evidence；按 `PTW-ADD-011/024` 拆边界。 |
| `basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh` | `keep as smoke` | 只能作集成 smoke，不关闭单点 requirement。 |
| `cp0_tests/test_mmu_csr_ptw_disable.svh`、`test_mmu_csr_satp_*.svh` | `auxiliary` | PTW enable/satp CSR 配置 evidence；PTW walk 语义仍由 `PTW-AUD-021` 关闭。 |
| `bug_hunt_tests/test_bug_001_twu_fst_fetch_type.svh` | `modify` | 归 `PTW-ADD-014/015`；fetch/data/PFU original type 与 MPRV 分开。 |
| `bug_hunt_tests/test_bug_002_thd_chk_4k_a_bit.svh`、`test_bug_003_thd_chk_leaf_refill.svh` | `modify` | 归 `PTW-ADD-018/019/026`；4K A-bit 与 THD leaf refill。 |
| `bug_hunt_tests/test_bug_011_twu_2m_csr_cross.svh` | `modify` | 归 `MAEE-TP-008/010`；2M cross degrade correctness。 |
| `bug_hunt_tests/test_bug_012_csr_grant_onehot.svh` | `keep` | `PTW-INFRA-008`；CSR/refill/degrade grant onehot。 |
| `bug_hunt_tests/test_bug_013_ptw_write_pipe_reset.svh` | `modify` | `PDE-TP-011`、`MBUF-TP-009..012`；reset/abort write pipe race。 |
| `bug_hunt_tests/test_bug_014_xbar_cold_start.svh` | `modify` | `PTW-ADD-012`；cold start hash/ready，不是 round-robin。 |
| `perf_tests/test_ptw_walk_latency.svh`、`test_ptw_4tws_full_wakeup_dense.svh` | `keep as perf` | 性能/压力 evidence，不关闭 correctness。 |
| `perf_tests/test_satp_hotswap_concurrent.svh`、`test_sfence_high_frequency.svh`、`test_error_rain_mixed_fault.svh`、`test_huge_4k_page_mix.svh` | `keep as stress` | 只有命中 `PTW-AUD-*`/`PTW-FLOW-*` coverage 后才算 PTW closure。 |
| `pmp_tests/test_pmp_deny_walk_abort.svh`、`test_mmu_pmp_pde_cache_flow.svh`、`test_mmu_pmp_*port*.svh` | `auxiliary + modify` | PMP 配置/端口辅助；PTW closure 仍需 `pmp_twu_tests_v6` source-side no-LSU/no-refill。 |
| `err_tests/test_lsu_access_fault_bus_error.svh`、`test_lsu_access_fault_pmp_deny.svh`、`test_pipe2_prefetch_err.svh`、IFU/LSU `pgflt` tests | `consumer-only` | 证明异常被下游消费；不关闭 PTW source-side fault 生成规则。 |
| `l1dtlb_tests/*refill*/*pgflt*/*access_fault*/*expt_id*/*stale_id*` | `consumer-only` | L1DTLB 消费 PTW load/store refill/fault evidence。 |
| `l1itlb_tests/*refill*/*pgflt*/*perm*/*abort*/*huge*` | `consumer-only` | IUTLB 消费 PTW fetch refill/fault evidence。 |
| `l2tlb_tests/*ptw*/*refill*/*bank_write_conflict_ptw*` | `consumer-only` | L2TLB 消费 PTW refill/PFU evidence；不替代 PTW source-side checker。 |

### 13.20 `MMU_Traceability_Matrix.csv` 原始 ID 闭环

`doc/MMU_Traceability_Matrix.csv` 是原始完整 MMU 测试点矩阵。该 CSV 中凡是 `Test_Case_ID`、`Sub_Feature_ID`、`Sub_Feature`、`Requirement` 或描述触达 PTW/TWU/PDE/PMBUF/MBUF/XBAR/PMP/SysMap/SATP/PTW-refill 的条目，都必须在本节有结论。本节只做 traceability closure：若 CSV 旧 expected 与本文 spec 冲突，以本文第 0-13 章为准，并将旧 ID 标成 `modify/delete/re-scope`，不允许按旧 expected 关闭。

#### 13.20.1 PTW source-side 与 F4/F4.NEW 条目

| CSV ID | 处理 | 当前 PTW spec 绑定与修正 |
| --- | --- | --- |
| `PTW-001`、`PTW-002` | `modify` | 绑定 `PTW-AUD-021`、`PTW-FLOW-001..003/022`；SATP root 使用点、satp clear-only 与 abort 分拆。 |
| `PTW-003`、`PTW-004`、`PTW-006`、`PTW-009` | `modify` | 绑定 `PDE-TP-001..004/009/010`、`PTW-FLOW-001..003/015..017`；PDE hit level、skip level、lookup/update、field check 必须可观测。 |
| `PTW-010`、`PTW-015`、`PTW-016`、`PTW-020`、`PTW-022`、`TC-AD-A-PGFLT-001`、`TC-AD-D-PGFLT-001`、`TC-AD-TRAP-ONLY-001`、`TC-PTE-RSW-001` | `split + modify` | 绑定 `PTW-ADD-001/003/016..019/033/034`；V/R/W/X/U/SUM/MXR/A/D/RSW/G 按 PTE 矩阵拆分，PFU 不按 load 检查 R/MXR/D，RSW no fault + flg。 |
| `PTW-023`、`PTW-024`、`PTW-025`、`PTW-026` | `keep + modify` | 绑定 `PTW-FLOW-001..008`、`MAEE-TP-001..010`；1G/2M/4K smoke 必须补 page_size/PPN/flg/global/MAEE/sysmap/degrade。 |
| `PTW-028`、`TC-PTW-ABORT-001`、`TC-PTW-ABORT-BCAST-001` | `split + modify` | 绑定 `PTW-ADD-011/024`、`MBUF-TP-009..012`；使用 `tlboper_ptw_abort`，覆盖 req/data/bus_error/已有异常 grant。 |
| `PTW-029`、`TC-MBUF-BUS-ERR-CONCURRENT-001`、`TC-MBUF-GET-NO-BUS-ERR-001`、`TC-MBUF-FSM-MUTEX-001`、`TC-PMBUF-BUSERR-FAIR-001` | `modify` | 绑定 `PTW-ADD-023`、`MBUF-TP-007/008`；bus error 不进 CHK、不 page fault、不 refill、不 update PDE；新 bus error 被 abort 屏蔽。 |
| `PTW-030`、`PTW-031`、`TC-WAKEUP-BCAST-001`、`TC-BUSY-SRC-DTLB-MB-001` | `re-scope` | wakeup/tlb_busy 归 L1DTLB consumer/LSU 协作；只能作为 consumer-side evidence，不关闭 PTW source-side。 |
| `PTW-013`、`TC-PMBUF-NO-OVERFLOW-001` | `modify` | 删除 MBUF full backpressure expected；改为 upstream one-to-one sizing、no-overwrite、entry allocation、LSU single outstanding evidence。 |
| `TC-PMBUF-FFZ-001`、`TC-PMBUF-RR-001`、`TC-PMBUF-ITLB-SLOT-001`、`TC-PMBUF-MULTI-TWU-001` | `modify` | 绑定 `MBUF-TP-001/002`；entry8 IUTLB 专用、entry0-7 DTLB/PFU 轮转、不覆盖 valid entry，multi-TWU one-hot 只作 entry ownership 检查。 |
| `TC-PMBUF-DEDUP-001` | `delete/implementation-only` | 当前 spec 无 PTW PMBUF same-VPN dedup requirement；如保留只能做 implementation coverage，不作为正向功能 expected。 |
| `TC-PMBUF-WB-FAIR-001`、`TC-PMBUF-NO-DEADLOCK-001` | `keep as liveness` | 只作为 no-deadlock/forward-progress 辅助；不关闭 PTE/PMP/MAEE/PDE correctness。 |
| `TC-PMBUF-LSU-CHN-001`、`TC-PMBUF-SERIAL-OUTSTANDING-001`、`TC-PMBUF-ADDR-STABLE-001`、`TC-PMBUF-NO-TAG-001`、`TC-PMBUF-INORDER-RESP-001`、`TC-PMBUF-PTR-HOLD-001`、`TC-PTW-LSU-PROTO-001` | `keep + modify` | 绑定 `MBUF-TP-003/004/010`；PTW->LSU single outstanding、no tag、in-order、PA stable、abort outstanding hold。 |
| `TC-PMBUF-MULTI-RESP-001` | `delete` | LSU 多 response/OOO response 非合法 PTW PTE 通道协议。 |
| `TC-MBUF-FSM-001`、`TC-MBUF-READY-GATE-001`、`TC-MBUF-HAVE-001`、`TC-MBUF-MULTI-TWU-READY-001`、`TC-MBUF-MULTI-LEVEL-001` | `modify` | 绑定 `MBUF-TP-005/006`、`PTW-FLOW-001..003/015..017`；CHK ready gate、have no resend、多 level walk 必须与 lvl/type/id/PDE update 交叉。 |
| `TC-PDE-ASID-STALE-001` | `modify` | PDE cache 不存 ASID；改为 satp change clear-only、in-flight 旧 walk 可 update、普通随机约束 no unsafe ASID/PPN change。 |
| `TC-PDE-MUX-001`、`TC-PDE-CLR-001`、`TC-PPLRU-ONEHOT-001`、`TC-PDE-CACHE-TIMING-001`、`TC-PDE-CACHE-LVL-001` | `modify` | 绑定 `PDE-TP-004/009/010/011/012`；双命中选二级、lookup 读旧、update 下拍、非叶 no-fault only、PLRU onehot。 |
| `TC-PDE-CACHE-HIT-L2-001`、`TC-PDE-CACHE-HIT-L3-001`、`TC-PDE-CACHE-MISS-001` | `modify/rename` | CSV 命名中的 L2/L3 与本文两级 PDE cache 口径需统一：一级 hit -> scd，二级 hit -> thd，全 miss -> fst；最终按 `PDE-TP-001..004` 关闭。 |
| `TC-TWU-CSR-FSM-001`、`TC-TWU-CSR-REFILL-001`、`TC-TWU-DATA-RDY-001`、`TC-CSR-REFILL-PRIO-001` | `modify` | 绑定 `MAEE-TP-*`、`PTW-INFRA-008`；CSR/sysmap/refill wait 与 grant onehot 只关闭时序/仲裁，不替代 MAEE/degrade correctness。 |
| `TC-TWU-PIPELINE-BACK2BACK-001`、`TC-TWU-MULTI-INFLIGHT-001` | `modify` | 绑定 `PTW-AUD-003/008/015`；验证 6-stage pipeline/back-to-back 时必须同时检查 hash target、mask/ready、type/id 和 mbuf ownership。 |
| `TC-TWU-PGFLT-BYPASS-001`、`TC-TWU-ACCERR-BYPASS-001`、`TC-TWU-EXCEPT-CONFLICT-001` | `modify` | 绑定 `PTW-ADD-005/006/023`；异常按 type/id 返回，access fault > page fault > refill，bus error 不再进入 CHK。 |
| `TC-ARB-GRANT-ONEHOT-001`、`TC-ARB-REFILL-EXCEPT-PRIO-001`、`TC-ARB-MULTI-TWU-FAIRNESS-001`、`TC-ARB-VPN-MATCH-001`、`TC-ARB-PGS-MATCH-001` | `keep + modify` | 绑定 `PTW-INFRA-008`、`PTW-ADD-004/006/034`；grant onehot/priority/field match 由 SVA/monitor 关闭，fairness 只作 liveness。 |
| `TC-TWU-ADDR-BOUND-001` | `keep as boundary` | VPN/PPN/PA 边界 smoke；不得加入 PPN 超范围 fault expected。 |
| `TC-SATP-WALK-CONSIST-001`、`TC-SATP-PTW-HAZARD-001` | `modify` | 绑定 `PTW-AUD-007/021`、`PTW-ADD-010/030`；satp change 清 PDE，不 flush in-flight；无 abort 的 ASID/PPN 交错可约束或 special-case scoreboard。 |
| `TC-PMP-MIDWALK-001`、`TC-SYSMAP-MIDWALK-001` | `modify` | 绑定 `PTW-AUD-020/021`；PMP change 只清 PDE，sysmap/MAEE 按使用点采样，进入 sysmap/degrade 后不回退。 |
| `TC-PTW-BUSY-CONSIST-001`、`TC-PTW-WATCHDOG-001` | `keep as liveness` | 只作 no-deadlock/watchdog evidence；若信号源为 L1DTLB busy，重归属 L1DTLB。 |
| `TC-BUG-001`、`TC-BUG-002`、`TC-BUG-003`、`TC-BUG-011`、`TC-BUG-012` | `modify` | 分别绑定 original type/MPRV、THD A-bit、leaf refill vs PDE update、2M sysmap/degrade、CSR grant onehot；不能按旧 RTL bug 文本直接关闭。 |
| `TC-RST-SEQ-001`、`TC-RST-MIDWALK-001`、`TC-RST-MB-CLR-001` | `modify` | 绑定 `PTW-ADD-011/024`、`PDE-TP-011`、`MBUF-TP-009..012`；reset 清 PDE/mbuf/valid 并 flush in-flight。 |

#### 13.20.2 XBAR/ready 原始矩阵冲突项

当前 RTL 和本文最终 spec 中 `one_to_four_xbar` 使用 VPN hash 选择唯一 TWU，ready 只由 hash 目标 TWU 的 mask 决定。CSV 中仍保留的 idle-first、pointer fallback、round-robin、公平性旧口径必须按下表处理。

| CSV ID | 处理 | 当前 PTW spec 绑定与修正 |
| --- | --- | --- |
| `XBAR-001`、`XBAR-002`、`TC-XBAR-IDLE-001`、`TC-XBAR-FAIR-001`、`TC-XBAR-DRAIN-001`、`TC-XBAR-MASK-LAT-001`、`TC-XBAR-FALLBACK-001`、`TC-XBAR-ABORT-001`、`TC-XBAR-DISPATCH-ABORT-001` | `modify/delete old expected` | 删除 idle scan、round-robin、公平轮转、drain/fallback 旧 expected；改为 `PTW-ADD-012`：hash target、target mask -> ready low、fields hold、abort 屏蔽 dispatch。 |
| `TC-PTW-READY-001`、`TC-PTW-READY-002`、`TC-PTW-READY-003`、`TC-TWU-IDLE-MASK-001`、`TC-TWU-MASK-SELF-001`、`TC-TWU-MASK-ALL-001` | `modify` | ready/mask 关闭标准改为：hash 目标被 mask 时 ready low；非 hash 目标 mask 不影响该请求；四路全 mask 是 ready low 的充分条件但不是唯一用例。 |
| `F4.NEW.15`、`TC-XBAR-IDLE-FIRST-001`、`TC-XBAR-POINTER-FALLBACK-001`、`TC-XBAR-MODE-SWITCH-001`、`TC-BUG-014` | `delete/obsolete-by-spec` | 旧 idle-first + pointer fallback 逻辑在当前 RTL 中已注释，不属于 PTW spec；若保留测试，必须改写为 hash cold-start/ready-hold coverage，不要求 TWU0>1>2>3 或 pointer 轮转。 |
| `F4.NEW.16`、`TC-MBUF-TWU-HAVE-GEN-001`、`F4.NEW.17`、`TC-TWU-BUSY-INCL-MBUF-HAVE-001` | `delete/obsolete-by-spec` | 当前 `mbuf_twu_have/twu_busy/twu_idle` 相关逻辑在 RTL 中已注释且不在本文 spec；不得作为 PTW signoff requirement。若后续 RTL 恢复，应重新进入 spec change review。 |

#### 13.20.3 MAEE/SysMap CSV 条目

| CSV ID | 处理 | 当前 PTW spec 绑定与修正 |
| --- | --- | --- |
| `TC-TWU-MAEE0-CSR-001`、`TC-TWU-MAEE0-CSR-002`、`TC-TWU-MAEE1-REFILL-001`、`TC-TWU-MAEE-SWITCH-001` | `modify` | 绑定 `MAEE-TP-001..013`；补 all sizes、4K sysmap、flag order、MAEE switch no rollback。 |
| `TC-SYSMAP-MAEE0-ATTR-001`、`TC-SYSMAP-MAEE0-ATTR-002`、`TC-SYSMAP-MAEE1-SKIP-CSR-001`、`TC-SYSMAP-FLG-REFILL-001`、`TC-SYSMAP-FLG-REGION0-001`、`TC-SYSMAP-FLG-REGION7-001` | `modify` | PTW-owned MAEE path；必须证明是 leaf refill flg source-side，不是 system direct-map。 |
| `TC-SYSMAP-CROSS-SAME-001`、`TC-SYSMAP-CROSS-1G-DIFF-001`、`TC-SYSMAP-CROSS-2M-DIFF-001`、`TC-SYSMAP-CROSS-PARTIAL-HIT-001` | `modify` | 绑定 `MAEE-TP-004..008`；sysmap malformed/no-hit/multi-hit 不是 PTW 正常输入，partial-hit 需要 constraint/waiver 或 default-flag implementation-only。 |
| `TC-SYSMAP-DEGRADE-1G2M-001`、`TC-SYSMAP-DEGRADE-2M4K-001`、`TC-SYSMAP-NO-DEGRADE-1G-001`、`TC-SYSMAP-NO-DEGRADE-2M-001` | `modify` | 绑定 `MAEE-TP-005..010`；降级只改 PPN/page_size/属性，不访问下级页表，权限来自原 leaf。 |
| `TC-SYSMAP-PA-ALIGN-1G-001`、`TC-SYSMAP-PA-ALIGN-2M-001`、`TC-SYSMAP-PA-ALIGN-4K-001` | `modify` | 绑定 `MAEE-TP-011`；1G/2M misaligned 先 page fault，4K 不存在大页对齐 fault。 |
| `TC-SYSMAP-4TWU-CONCURRENT-001`、`TC-SYSMAP-TWU-PORT-MAP-001` | `keep + modify` | 作为 4 TWU 并发 sysmap/degrade evidence，仍需 type/id 独立匹配和 source-side refill checker。 |
| `TC-SYSMAP-001`、`TC-SYSMAP-002`、`TC-SYSMAP-003`、`TC-SYSMAP-004`、`TC-SYSMAP-005`、`TC-SYSMAP-006`、`TC-SYSMAP-007`、`TC-SYSMAP-008`、`TC-SYSMAP-009`、`TC-SYSMAP-010`、`TC-SYSMAP-011`、`TC-SYSMAP-012`、`TC-SYSMAP-013` | `re-scope + auxiliary` | 归 system sysmap 配置/优先级/flag/region；`TC-SYSMAP-011` 可辅助 PTE walk PA protection，但 PTW closure 仍需 MAEE leaf refill evidence。 |
| `TC-SYSMAP-8PORT-001`、`TC-SYSMAP-PRIO-001`、`TC-SYSMAP-DEFAULT-001`、`TC-SYSMAP-EDGE-001`、`TC-SYSMAP-WIDTH-001`、`TC-SYSMAP-MEL-ALIGN-001`、`TC-SYSMAP-ALIGN-001`、`TC-SYSMAP-DISABLE-001`、`TC-SYSMAP-DEFAULT-FLAG-BIT-001`、`TC-SYSMAP-NO-HIT-DEFAULT-001` | `re-scope/auxiliary` | System sysmap robustness 或 implementation-only；PTW 正常 spec 假设 sysmap 配置合法，不用 malformed default 行为关闭 PTW。 |

#### 13.20.4 PMP/PTW-PMP CSV 条目

| CSV ID | 处理 | 当前 PTW spec 绑定与修正 |
| --- | --- | --- |
| `TC-TWU-PMP-SERIAL-001`、`TC-TWU-PMP-WAIT-STALL-001`、`TC-PTW-PMP-BEFORE-LSU-001`、`TC-PTW-PMP-DENY-STOP-REQ-001`、`TC-PTW-PMP-WAIT-NO-LSU-001` | `modify` | 绑定 `PTW-ADD-013/014`；PMP deny/wait 必须发生在 mbuf/LSU 前，覆盖 fst/scd/thd。 |
| `TC-TWU-PMP-GRANT-ONEHOT-001`、`TC-PTW-PMP-PA-1G-001`、`TC-PTW-PMP-PA-2M-001`、`TC-PTW-PMP-PA-4K-001`、`TC-PTW-PMP-PA-ZERO-001` | `keep + modify` | 绑定 `PTW-AUD-009/010`；PTE PA 公式/边界/level 与 PMP grant onehot。 |
| `TC-PTW-PMP-DENY-ACCFLT-001`、`TC-PTW-PMP-DENY-NO-REFILL-001`、`TC-PTW-PMP-MMODE-L0-001`、`TC-PTW-PMP-MMODE-L1-001` | `modify` | 绑定 `PTW-ADD-013..015`；M-mode L-bit 规则与 MPRV effective mode 分开检查。 |
| `TC-TWU-MASK-PMP-WAIT-001`、`TC-TWU-MASK-ALL4-PMP-001` | `modify` | PMP wait -> TWU mask；只作为 ready/mask evidence，不能替代 PMP deny correctness。 |
| `TC-PTW-PMP-FETCH-ZERO-001`、`TC-PTW-PMP-R-CHECK-001`、`TC-PTW-PMP-TYPO-BIND-001` | `modify/delete old expected` | CSV 旧“PTW PMP fetch 恒 0/统一 R check”不得作为最终 expected；按本文 original request type：fetch 看 X、load/PFU 看 R、store 看 W。typo binding 仅保留为 TB 接口绑定检查。 |
| `TC-PTW-PMP-PORT-MAP-001`、`TC-PTW-PMP-PORT-CONCURRENT-001`、`TC-PMP-PTW-MAP-001`、`TC-PMP-PDE-CACHE-001` | `auxiliary + modify` | PTW PMP port map/并发/PDE flow 辅助；source-side 关闭仍需 level/type/no-LSU/no-refill checker。 |
| `TC-PMP-001`、`TC-PMP-002`、`TC-PMP-003`、`TC-PMP-004`、`TC-PMP-005`、`TC-PMP-006`、`TC-PMP-007`、`TC-PMP-008`、`TC-PMP-009`、`TC-PMP-010`、`TC-PMP-011`、`TC-PMP-012`、`TC-PMP-013`、`TC-PMP-014` | `re-scope + auxiliary` | 归 PMP standalone；只作为 PMP flg/PA/deny/port 配置正确性的辅助，不关闭 PTW source-side。 |
| `TC-PMP-FLG-NEW-001`、`TC-PMP-FETCH-ASYM-001`、`TC-PMP-FETCH-NONSYM-001`、`TC-PMP-PA-CONSIST-001`、`TC-PMP-INDEP-001`、`TC-PMP-FLG-LXWR-ORDER-001` | `re-scope + auxiliary` | PMP standalone/ref-model 支撑项；PTW checker 使用 `{L,X,W,R}` flg 结果。 |
| `TC-PMP-TOR-CHAIN-001`、`TC-PMP-TOR-ZERO-LEN-001`、`TC-PMP-NAPOT-ALL-SIZES-001`、`TC-PMP-NAPOT-ILLEGAL-001`、`TC-PMP-NA4-UNSUPPORTED-001`、`TC-PMP-PRIORITY-LOWEST-IDX-001`、`TC-PMP-DEFAULT-M-ALLOW-001`、`TC-PMP-DEFAULT-U-DENY-001`、`TC-PMP-L-BIT-LOCK-001`、`TC-PMP-TOR-LOCK-DEP-001`、`TC-PMP-L-BIT-RESET-CLR-001`、`TC-PMP-MPRV-PORT2-IMMUNE-001`、`TC-PMP-MPRV-PORT3-FETCH-MASK-001`、`TC-PMP-PMPCFG2-ZERO-001` | `re-scope` | PMP block detail，不属于 PTW closure；若影响 `pmp_mmu_flg`，只通过 PMP agent/refmodel 输入正确性间接支撑 PTW。 |
| `TC-PMP-5PORT-REGRESS-001`、`TC-PMP-8PORT-SPEC-001`、`RISK-PMP-PORT-GAP-001`、`RISK-PMP-NA4-001`、`RISK-PMP-L-RESET-001`、`RISK-PMP-PMPCFG2-001` | `risk/re-scope` | 归 PMP risk tracking；PTW signoff 仅要求实际连接到 PTW 的 PMP flg/PA/deny 行为可观测并与当前 RTL 一致。 |

#### 13.20.5 L1DTLB/L2TLB/CSR/Perf 间接 evidence

| CSV ID | 处理 | 当前 PTW spec 绑定与修正 |
| --- | --- | --- |
| `DTLB_PMP_001`、`DTLB_SYSMAP_001` | `consumer-only/re-scope` | LSU/L1DTLB consumer 或 system direct-map；不能关闭 PTW PTE/PMP/sysmap source-side。 |
| `TC-PTWREF-CMPLT-ACCERR-001`、`TC-PTWREF-CMPLT-PGFLT-001` | `consumer-only` | L1DTLB 对 PTW access/page fault 的消费 evidence；PTW fault generation 仍由 `PTW-ADD-005/013/018/019/023` 关闭。 |
| `TC-L2TLB-PTW-CMPLT-001`、`TC-PTW-L2REF-NOVALID-001`、`TC-L2PTW-ID-CHAIN-001`、`TC-L2PTW-ID-MULTI-MISS-001` | `consumer-only + modify` | L2TLB/PTW id/refill completion 消费链 evidence；source-side 仍需 PTW monitor 捕获 type/id/vpn/asid/page_size/ppn/flg/expt_kind。 |
| `TC-TWU-PORT-MAP-001` | `auxiliary` | TWU port map/HPCP 辅助；不关闭 PTW functional correctness。 |
| `PERF-PTW-001`、`test_ptw_walk_latency`、`RANDOM-PTW-001`、`test_ptw_random_walk_10k_seed` | `keep as perf/random` | 只有命中 `PTW-AUD-*`/`PTW-FLOW-*` cover bins 后才算 closure；latency/seed pass 不替代 correctness。 |

### 13.21 PTW/L1DTLB SVA 断言规格

本小节把前文 PTW 测试点、L1DTLB consumer-side evidence 和当前仓库已有 SVA 统一收敛为可实现的断言规格。后续新增或修改 SVA 时必须以本小节为准；若本节与 §0-§12 功能规格冲突，优先按 §0-§12，随后同步修正本节。

#### 13.21.1 SVA 总原则

1. SVA 分为 PTW source-side、PTW consumer-routing、L1DTLB consumer-side 三类。PTW source-side 断言用于关闭 `PTW-AUD-*`、`PTW-FLOW-*`、`PDE-TP-*`、`MBUF-TP-*`、`MAEE-TP-*`；L1DTLB consumer-side 断言只能证明 PTW 输出被 L1DTLB 正确消费，不能替代 PTW 对 PTE/PMP/PDE/MAEE/mbuf/abort 源头行为的检查。
2. scoreboard 负责事务级最终结果；SVA 负责周期级协议、ready/valid 保持、onehot/priority、flush/abort 边界、字段路由、cache 更新时序和不可发生事件。
3. 每条 P0/P1 SVA 必须同时有正向 `cover property` 或 covergroup bin，用于证明 directed/random regression 实际命中过该断言的前件。assert pass 但 cover 未命中不能关闭测试点。
4. SVA 不应假设固定 walk 总延迟；允许 `##[0:$]` 或事务 scoreboard 处理长期等待。只有明确由 RTL 组合或一拍寄存定义的协议才能写 exact-cycle assertion。
5. reset 使用 `disable iff (!cpurst_b)`；`tlboper_ptw_abort` 不能被全局无脑放入 `disable iff`，因为 abort 本身是必须检查的功能事件。只有与 abort 无关的普通稳定性断言才可在 abort 时 disable。
6. 同一请求的身份键统一为 `type + id`。所有 refill、page fault、access fault、L1DTLB/L1ITLB/L2TLB completion 断言都必须检查 `type/id` 没有被仲裁或 flush 路径改写。
7. SVA 使用真实 RTL 信号或只读 probe，不允许为了断言改变功能逻辑。若内部信号未暴露，应优先用 `bind` 层级引用或只读 `probe_if`，不允许把 monitor-only 状态混入 DUT functional path。
8. 可约束非法输入的场景使用 `assume` 或 testbench constraint 标注，不作为 DUT fail：Bare 模式 PTW request、纯 M 态无翻译 request、sysmap malformed/no-hit/multi-hit、LSU OOO response、同 id 未完成前复用。

建议 SVA 文件和 bind 目标如下：

| SVA 文件/模块 | bind 目标 | 关闭范围 |
| --- | --- | --- |
| `mmu_ptw_top_sva.sv` | `ptw` | L2TLB request ready/hold、PTW output onehot、type/id 路由、access/page/refill class priority、abort 屏蔽 refill。 |
| `mmu_pde_cache_sva.sv` | `PDE_cache`、`L1PDE_cache`、`L2PDE_cache` | PDE lookup/update/clear/double-hit/PLRU/race。 |
| `mmu_ptw_xbar_sva.sv` | `one_to_four_xbar` | VPN hash、target mask ready、payload forwarding、abort dispatch block。 |
| `mmu_pmp_twu_sva.sv` | `twu` | PMP grant/deny/wait、original type permission、effective privilege、no LSU before PMP pass。 |
| `mmu_twu_chk_sva.sv` | `twu` | PTE leaf/nonleaf/page fault、PFU permission、G/RSW/flg、huge alignment、no lower walk。 |
| `mmu_ptw_lsu_protocol_sva.sv` | `ptw_mbuf` | MBUF entry ownership、LSU single outstanding、PA stable、bus error、CHK ready hold、abort outstanding。 |
| `mmu_maee_twu_sva.sv`、`mmu_sysmap_sva.sv` | `twu` | MAEE path select、sysmap flag substitution、4K sysmap、large-page degrade、no lower walk。 |
| `mmu_arb_sva.sv` 或 `mmu_ptw_arb_sva.sv` | `ptw`、`mmu_arb` | PTW top class priority、grant onehot、write pipe reset、field match。 |
| `mmu_l1dtlb_sva.sv` | `mmu_l1dtlb` 及子模块 | L1DTLB hit/miss/refill/fault/flush/install/scheduler consumer-side evidence。 |

统一 type/page size 常量：

```systemverilog
localparam logic [2:0] PTW_TYPE_LOAD  = 3'b010;
localparam logic [2:0] PTW_TYPE_FETCH = 3'b011;
localparam logic [2:0] PTW_TYPE_PFU   = 3'b100;
localparam logic [2:0] PTW_TYPE_STORE = 3'b110;

localparam logic [2:0] PTW_PGS_4K = 3'b001;
localparam logic [2:0] PTW_PGS_2M = 3'b010;
localparam logic [2:0] PTW_PGS_1G = 3'b100;
```

统一 helper：

```systemverilog
function automatic logic [3:0] ptw_hash_onehot(input logic [26:0] vpn);
  logic [1:0] h;
  h = vpn[1:0] ^ vpn[10:9] ^ vpn[19:18] ^ vpn[26:25];
  unique case (h)
    2'b00: ptw_hash_onehot = 4'b0001;
    2'b01: ptw_hash_onehot = 4'b0010;
    2'b10: ptw_hash_onehot = 4'b0100;
    2'b11: ptw_hash_onehot = 4'b1000;
    default: ptw_hash_onehot = 4'b0000;
  endcase
endfunction

function automatic bit ptw_type_is_l1d(input logic [2:0] typ);
  return (typ == PTW_TYPE_LOAD) || (typ == PTW_TYPE_STORE);
endfunction

function automatic bit ptw_type_is_l1i(input logic [2:0] typ);
  return typ == PTW_TYPE_FETCH;
endfunction

function automatic bit ptw_type_is_pfu(input logic [2:0] typ);
  return typ == PTW_TYPE_PFU;
endfunction

function automatic bit ptw_legal_pgs(input logic [2:0] pgs);
  return (pgs == PTW_PGS_4K) || (pgs == PTW_PGS_2M) || (pgs == PTW_PGS_1G);
endfunction
```

#### 13.21.2 L2TLB->PTW request、ready 与输入约束断言

| SVA ID | Priority | Bind | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- | --- |
| `PTW-SVA-REQ-001` | P0 | `ptw` | `l2tlb_ptw_req && !ptw_jtlb_ready` 时，`l2tlb_ptw_vpn/type/id` 必须保持稳定直到 ready。 | `PTW-AUD-008`、`XBAR-TP-002/004` |
| `PTW-SVA-REQ-002` | P0 | `ptw` | `ptw_jtlb_ready` 必须等于 `pde_cache_ready && !abort_flop` 或等价实现；abort outstanding 等待期间不提前 accept 新请求。 | `PTW-ADD-012/024` |
| `PTW-SVA-REQ-003` | P0 | `ptw` | 每周期最多 accept 一个 L2TLB request；accept 定义为 `l2tlb_ptw_req && ptw_jtlb_ready`。 | §4、`PTW-AUD-008` |
| `PTW-SVA-REQ-004` | P1 | `ptw` | accepted request 的 `type` 只能为 fetch/load/store/PFU；其他编码必须被 TB constraint 屏蔽或报 testbench error。 | §2.1 |
| `PTW-SVA-REQ-005` | P1 | `ptw` | IUTLB/fetch request 的 `id[2:0]` 固定为 0；L1 DTLB id 不参与 fetch scoreboard 匹配。 | `PTW-AUD-004` |
| `PTW-SVA-REQ-006` | P1 | TB/top | Bare 模式、纯 M 态无翻译模式下不得向 PTW 发 request；如果 test 选择负向注入，只能标为 illegal stimulus。 | `PTW-ADD-036` |

规范模板：

```systemverilog
property p_ptw_req_hold_when_not_ready;
  @(posedge forever_cpuclk) disable iff (!cpurst_b)
    (l2tlb_ptw_req && !ptw_jtlb_ready)
    |=> l2tlb_ptw_req
        && $stable(l2tlb_ptw_vpn)
        && $stable(l2tlb_ptw_type)
        && $stable(l2tlb_ptw_id);
endproperty

a_ptw_req_hold_when_not_ready: assert property (p_ptw_req_hold_when_not_ready);
cp_ptw_req_stall: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
  l2tlb_ptw_req && !ptw_jtlb_ready ##1 l2tlb_ptw_req && ptw_jtlb_ready);
```

#### 13.21.3 PDE cache 断言

PDE cache 断言必须绑定 `PDE_cache` 顶层，并在需要时绑定每个 `L1PDE_cache/L2PDE_cache` entry。断言不得只检查最终翻译成功，必须检查 hit level、tag/data、update 和 clear。

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-PDE-001` | P0 | `cpurst_b==0`、`regs_ptw_clr`、`pmp_regs_update`、`tlboper_ptw_abort` 后，所有 `L1PDE_entry_vld/L2PDE_entry_vld` 下一拍为 0。 | `PDE-TP-010/011`、`PTW-FLOW-022` |
| `PTW-SVA-PDE-002` | P0 | `tlboper_ptw_abort` 当拍屏蔽 `mbuf_cache_upd` 对 PDE cache 的写入；abort 之后不得留下由该拍 update 产生的新 valid entry。 | `PDE-TP-008/011` |
| `PTW-SVA-PDE-003` | P0 | `L2PDE_entry_hit_vld` 为 1 时，`L1PDE_xbar_hit_vld` 必须为 0，`L2PDE_xbar_hit_vld` 为 1；双命中选择二级 PDE cache。 | `PDE-TP-004` |
| `PTW-SVA-PDE-004` | P0 | 一级命中时 `xbar_twu_hit_level==2'b10`，二级命中时 `xbar_twu_hit_level==2'b01`，miss 时 `2'b00`。 | `PDE-TP-002/003/004` |
| `PTW-SVA-PDE-005` | P0 | 命中输出 `PDE_xbar_ppn` 必须等于被命中 entry 的 PPN；二级命中优先于一级命中。 | `PDE-TP-003/004` |
| `PTW-SVA-PDE-006` | P0 | `mbuf_cache_upd_lvl[1]` 只允许更新一级 PDE cache；`mbuf_cache_upd_lvl[0]` 只允许更新二级 PDE cache；两级 update vector 各自 onehot0。 | `PDE-TP-001/002/012` |
| `PTW-SVA-PDE-007` | P0 | leaf PTE、page fault、LSU bus error、abort/flush 屏蔽的 PTE 返回不得产生 `mbuf_cache_upd`。 | `PDE-TP-005/006/007/008` |
| `PTW-SVA-PDE-008` | P0 | lookup/update 同拍同 tag 时，lookup 使用旧 entry；新的 tag/data 至少下一拍才可被 lookup 命中。 | `PDE-TP-009` |
| `PTW-SVA-PDE-009` | P1 | 写入时 invalid entry 优先；无 invalid 时使用 PLRU victim；PLRU hit/write update onehot。 | `PDE-TP-012` |
| `PTW-SVA-PDE-010` | P1 | PDE cache entry 不携带 ASID/G/RSW/flg/permission；satp/PMP clear-only 后旧 in-flight 非叶返回仍可重新 update，除非被 abort/reset 屏蔽。 | `PTW-AUD-007` |

规范模板：

```systemverilog
a_pde_clear_all_entries: assert property (@(posedge pde_cache_clk)
  (!cpurst_b || regs_ptw_clr || pmp_regs_update || tlboper_ptw_abort)
  |=> (L1PDE_entry_vld == '0 && L2PDE_entry_vld == '0));

a_pde_double_hit_selects_l2: assert property (@(posedge pde_cache_clk) disable iff (!cpurst_b)
  PDE_xbar_req && (|L1PDE_entry_hit_idx) && (|L2PDE_entry_hit_idx)
  |-> (L2PDE_xbar_hit_vld && !L1PDE_xbar_hit_vld
       && (PDE_xbar_ppn == L2PDE_cache_hit_ppn)));

a_pde_update_onehot_by_level: assert property (@(posedge pde_cache_clk) disable iff (!cpurst_b)
  mbuf_cache_upd |-> ($onehot0(L1PDE_entry_upd) && $onehot0(L2PDE_entry_upd)
    && (!mbuf_cache_upd_lvl[1] || (|L1PDE_entry_upd && !(|L2PDE_entry_upd)))
    && (!mbuf_cache_upd_lvl[0] || (|L2PDE_entry_upd && !(|L1PDE_entry_upd)))));
```

#### 13.21.4 Xbar/ready/backpressure 断言

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-XBAR-001` | P0 | `xbar_twu_req` 必须等于 `ptw_hash_onehot(PDE_xbar_vpn)` 与 request/ready 条件的组合，不允许 idle-first、round-robin 或 pointer fallback。 | `XBAR-TP-001/006` |
| `PTW-SVA-XBAR-002` | P0 | hash 目标 `twu_mask=1` 时，`xbar_pde_ready=0`，`xbar_twu_req=0`。 | `XBAR-TP-002/004` |
| `PTW-SVA-XBAR-003` | P0 | 非 hash 目标 `twu_mask=1` 不得阻塞当前请求；hash 目标未 mask 时 ready 必须为 1。 | `XBAR-TP-003` |
| `PTW-SVA-XBAR-004` | P0 | `tlboper_ptw_abort` 当拍不得产生新的 `xbar_twu_req`。 | `XBAR-TP-005` |
| `PTW-SVA-XBAR-005` | P1 | 派发到 TWU 的 `vpn/type/id/ppn/hit_level` 必须等于 PDE cache 输出字段。 | `PTW-AUD-008` |
| `PTW-SVA-XBAR-006` | P1 | backpressure 期间 `PDE_xbar_req/vpn/type/id/ppn/hit_level` 保持稳定，直到 `xbar_pde_ready`。 | `PTW-AUD-008` |

规范模板：

```systemverilog
a_xbar_hash_dispatch: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
  (PDE_xbar_req && xbar_pde_ready && !tlboper_ptw_abort)
  |-> (xbar_twu_req == ptw_hash_onehot(PDE_xbar_vpn)));

a_xbar_target_mask_blocks_only_target: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
  PDE_xbar_req |-> (xbar_pde_ready == !((ptw_hash_onehot(PDE_xbar_vpn) & twu_mask) != 4'b0000)));
```

#### 13.21.5 PMP/TWU PMP-stage 断言

当前 `mmu_pmp_twu_sva.sv` 已覆盖 PMP grant onehot、wait->mask、deny->access fault、deny no refill、original type permission 和 MPRV effective mode。本 spec 要求保留这些断言，并补齐 level/PA 公式与 no-lower-side-effect。

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-PMP-001` | P0 | `pmp_grant` onehot0；同一 TWU 内 `fst/scd/thd` PMP stage 串行访问 PMP port。 | `PTW-AUD-009` |
| `PTW-SVA-PMP-002` | P0 | `fst/scd/thd_pmp_wait` 必须贡献到 `twu_mask`，并阻止同 stage 发 mbuf request。 | `PTW-AUD-008/009` |
| `PTW-SVA-PMP-003` | P0 | PMP deny 的 stage 不得发 `twu_mbuf_req`、不得产生同 type/id normal refill。 | `PTW-AUD-009/010` |
| `PTW-SVA-PMP-004` | P0 | PMP deny 必须转换为 access fault，且返回原始 `type/id`。 | `PTW-FLOW-009..011` |
| `PTW-SVA-PMP-005` | P0 | PMP deny 使用原始 request type：fetch 查 X，load/PFU 查 R，store 查 W。 | `PTW-ADD-014` |
| `PTW-SVA-PMP-006` | P0 | `mmu_pmp_fetch*` 必须只由 fetch type stage 拉高，不得把 PTW PTE bus read 统一当 load。 | `PTW-ADD-014` |
| `PTW-SVA-PMP-007` | P0 | effective M 且 `pmp_mmu_flg[3]==0` 时跳过 PMP deny；fetch 不受 MPRV，data/PFU 在 `MPRV=1` 时用 MPP。 | `PTW-ADD-015/030` |
| `PTW-SVA-PMP-008` | P0 | PTE PA 公式正确：fst=`{satp_ppn,vpn[26:18],3'b0}`，scd=`{parent_ppn,vpn[17:9],3'b0}`，thd=`{parent_ppn,vpn[8:0],3'b0}`。 | `PTW-AUD-009` |
| `PTW-SVA-PMP-009` | P1 | PMP pass 后才允许进入 mbuf；PMP wait/deny 期间不得产生 CHK/page fault。 | `PTW-AUD-009` |

#### 13.21.6 CHK/PTE/page fault 断言

PTE 规则既要由 reference model 检查，也要由 TWU CHK-stage SVA 保护关键 RTL 分支。SVA 可以直接检查 `ptw_flg` 或从 `mbuf_twu_data` 解码 raw PTE，但必须明确使用哪套 bit map。

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-CHK-001` | P0 | leaf 判定为 `V && (R || X)`；`W=1 && !(R || (MXR && X))` 为本设计 write-only fault。 | `PTW-AUD-012/013` |
| `PTW-SVA-CHK-002` | P0 | fst/scd 非叶合法 pointer 不得 page fault；thd 非叶必须 page fault。 | `PTW-ADD-016` |
| `PTW-SVA-CHK-003` | P0 | fetch leaf fault 公式：`!V || write_only || !X || us_fault || !A || huge_align_fault`。 | `PTW-ADD-017` |
| `PTW-SVA-CHK-004` | P0 | load leaf fault 公式：`!V || write_only || (!R && !(MXR && X)) || us_fault || !A || huge_align_fault`。 | `PTW-ADD-017` |
| `PTW-SVA-CHK-005` | P0 | store leaf fault 公式：`!V || write_only || !W || us_fault || !A || !D || huge_align_fault`。 | `PTW-ADD-017` |
| `PTW-SVA-CHK-006` | P0 | PFU leaf fault 公式：`!V || write_only || us_fault || !A || huge_align_fault`；PFU 不要求 R/MXR/X/D。 | `PTW-ADD-033` |
| `PTW-SVA-CHK-007` | P0 | effective M 跳过 U/S；effective S 访问 U page 且 `SUM=0` fault；effective U 访问 S page fault。 | `PTW-ADD-019/030` |
| `PTW-SVA-CHK-008` | P0 | 1G leaf `PPN[1:0]!=0` 或 2M leaf `PPN[0]!=0` 必须 page fault，且不得进入 sysmap/degrade/refill。 | `PTW-ADD-020`、`MAEE-TP-011` |
| `PTW-SVA-CHK-009` | P1 | `PTE[58:38]` 和 RSW 不参与 page fault；RSW 非零不能触发 page fault。 | `PTW-ADD-001/002` |
| `PTW-SVA-CHK-010` | P1 | raw G 不进入 data `flg`，只进入 tag/global；非叶 G 不向下 OR。 | `PTW-ADD-003/034` |
| `PTW-SVA-CHK-011` | P0 | page fault 请求不得产生 normal refill、PDE update 或下一级 PMP request。 | `PTW-FLOW-012..014` |

规范模板：

```systemverilog
function automatic bit ptw_us_fault(
  input bit pte_u,
  input bit eff_m,
  input bit eff_s,
  input bit eff_u,
  input bit sum
);
  return (!eff_m) && ((eff_s && pte_u && !sum) || (eff_u && !pte_u));
endfunction

function automatic bit ptw_leaf_fault_load(
  input bit v, r, w, x, u, a, d,
  input bit mxr, sum, eff_m, eff_s, eff_u,
  input bit huge_align_fault
);
  bit write_only;
  write_only = w && !(r || (mxr && x));
  return !v || write_only || (!r && !(mxr && x))
      || ptw_us_fault(u, eff_m, eff_s, eff_u, sum)
      || !a || huge_align_fault;
endfunction
```

#### 13.21.7 MBUF、LSU 与 abort 断言

当前 `mmu_ptw_lsu_protocol_sva.sv` 已覆盖 single outstanding、accepted request 地址匹配、response in-order、abort drop 边界的一部分。本 spec 要求补齐 entry 分配、CHK hold、bus error/no CHK、abort same-cycle bus error。

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-MBUF-001` | P0 | `mbuf_grant` onehot0；同拍有 IUTLB/fetch mbuf request 时优先写 entry8；DTLB/PFU 只写 entry0-7。 | `MBUF-TP-001/002` |
| `PTW-SVA-MBUF-002` | P0 | `tlboper_ptw_abort` 当拍不得 create 新 mbuf entry；已在第一拍之前的 request 可被屏蔽。 | `MBUF-TP-009` |
| `PTW-SVA-MBUF-003` | P0 | PTW->LSU single outstanding：pending 未返回时不得 accept 第二个 LSU PTE read。 | `MBUF-TP-003/004` |
| `PTW-SVA-MBUF-004` | P0 | LSU request valid 拉高后，PA/size/entry grant 保持到 `lsu_mmu_data_vld || lsu_mmu_bus_error`，除非进入定义好的 abort outstanding hold。 | `MBUF-TP-003/010` |
| `PTW-SVA-MBUF-005` | P0 | LSU response 只允许在 pending outstanding 存在时出现；合法 UVM 不产生 OOO response。 | `MBUF-TP-004` |
| `PTW-SVA-MBUF-006` | P0 | normal data 返回且对应 CHK ready 时，只向原 TWU/lvl 写回一次，`vpn/type/id/lvl/data` 保持原 entry payload。 | `MBUF-TP-005` |
| `PTW-SVA-MBUF-007` | P0 | normal data 返回但 CHK not ready 时，entry 置 get/hold，之后 ready 时只写回一次，不重复发 LSU。 | `MBUF-TP-006` |
| `PTW-SVA-MBUF-008` | P0 | LSU bus error 不得进入 CHK，不得 page fault，不得 normal refill，不得 update PDE cache；必须生成 access fault pending。 | `MBUF-TP-007/008`、`PTW-FLOW-018` |
| `PTW-SVA-MBUF-009` | P0 | bus error access fault 在写入异常寄存器/获 grant 前 entry 或 pending fault 不得丢失。 | `MBUF-TP-007/008` |
| `PTW-SVA-MBUF-010` | P0 | abort 前一拍 LSU req 已经为 1 时，继续保持 req/PA 到 data valid；普通 data 返回丢弃，不 CHK、不 PDE update、不 refill。 | `MBUF-TP-010` |
| `PTW-SVA-MBUF-011` | P0 | abort 同拍新形成 LSU bus error 不得上报 access fault，不得写入新的异常可见状态。 | `MBUF-TP-011` |
| `PTW-SVA-MBUF-012` | P0 | abort 前已经存在并在异常寄存器中的异常，若当拍获顶层授权，可以可见并完成对应 `type/id`。 | `MBUF-TP-012` |

规范模板：

```systemverilog
a_lsu_single_outstanding: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
  !(accept_event && pending_req && !response_event));

a_bus_error_no_chk_no_pde_update: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
  (lsu_mmu_bus_error && pending_req && !tlboper_ptw_abort)
  |-> (!mbuf_twu_data_vld && !mbuf_cache_upd));

a_abort_outstanding_drops_data: assert property (@(posedge mbuf_clk) disable iff (!cpurst_b)
  (pending_req && tlboper_ptw_abort && !response_event)
  |=> pending_aborted until_with response_event);
```

#### 13.21.8 Refill、异常、仲裁与返回目标断言

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-ARB-001` | P0 | PTW 顶层同周期结果 class onehot：normal refill、page fault、access fault 至多一种可见。 | `PTW-ADD-006` |
| `PTW-SVA-ARB-002` | P0 | class priority 固定为 `access fault > page fault > normal refill`。 | `PTW-AUD-017`、`PTW-INFRA-008` |
| `PTW-SVA-ARB-003` | P0 | `tlboper_ptw_abort` 当拍和 flush 窗口不得产生 normal refill；已有异常寄存器获 grant 的异常按 §11.4 允许。 | `PTW-ADD-024` |
| `PTW-SVA-ARB-004` | P0 | output `ptw_l2tlb_cmplt` 等于 L2TLB data/page/access 三类完成 OR；三类完成携带同一 `ptw_l2tlb_type/id`。 | `PTW-AUD-003/004` |
| `PTW-SVA-ARB-005` | P0 | load/store normal refill 必须同时到 L1DTLB 和 L2TLB；fetch normal refill 必须同时到 L1ITLB 和 L2TLB；PFU normal refill 只到 L2TLB。 | `PTW-ADD-004`、`PTW-FLOW-020` |
| `PTW-SVA-ARB-006` | P0 | load/store exception 必须到 L1DTLB 和 L2TLB completion；fetch exception 到 L1ITLB 和 L2TLB；PFU exception 只由 L2TLB/PFU path 消费。 | `PTW-ADD-005`、`PTW-FLOW-021` |
| `PTW-SVA-ARB-007` | P0 | normal refill page size 只能为 1G/2M/4K 编码；`vpn/asid/ppn/flg/global/type/id` 字段不得为 X。 | `PTW-ADD-004/034` |
| `PTW-SVA-ARB-008` | P1 | refill data `flg` bit layout 与 §1.4 一致：`[13:9]` 扩展属性，RSW 进入 flg，G 不进入 flg。 | `PTW-ADD-034` |
| `PTW-SVA-ARB-009` | P1 | refill ASID 使用 refill 返回当拍 `regs_ptw_cur_asid`，不是 request accept 时锁存值。 | `PTW-AUD-021` |

规范模板：

```systemverilog
a_ptw_result_class_onehot0: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
  $onehot0({ptw_l2tlb_ref_acc_err, ptw_l2tlb_ref_pgflt, ptw_l2tlb_ref_data_vld}));

a_ptw_access_priority: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
  acc_err_vld |-> (ptw_l2tlb_ref_acc_err && !ptw_l2tlb_ref_pgflt && !ptw_arb_req));

a_ptw_type_routes_l1_targets: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
  ptw_l2tlb_ref_data_vld |->
    ((!ptw_type_is_l1d(ptw_l2tlb_type) || ptw_l1dtlb_ref_pa_vld)
  && (!ptw_type_is_l1i(ptw_l2tlb_type) || ptw_l1itlb_ref_pa_vld)
  && (!ptw_type_is_pfu(ptw_l2tlb_type) || (!ptw_l1dtlb_ref_pa_vld && !ptw_l1itlb_ref_pa_vld))));
```

#### 13.21.9 MAEE、Sysmap 与大页降级断言

当前 `mmu_maee_twu_sva.sv` 只覆盖 FST/SCD leaf 的 MAEE path select；最终签核必须补 THD/4K leaf、degrade PPN/page_size 和 no-lower-walk。

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-MAEE-001` | P0 | MAEE=1 时，合法 leaf 直接产生 refill，不进入 CSR/sysmap path；1G/2M/4K 都必须覆盖。 | `MAEE-TP-001..003` |
| `PTW-SVA-MAEE-002` | P0 | MAEE=0 时，合法 leaf 必须进入 CSR/sysmap path；4K leaf 也必须查 sysmap。 | `MAEE-TP-004..009` |
| `PTW-SVA-MAEE-003` | P0 | MAEE path mutex：同一 stage 不得同时发 direct refill 和 CSR/sysmap refill request。 | `MAEE-TP-*` |
| `PTW-SVA-MAEE-004` | P0 | MAEE=0 refill 扩展属性必须来自 `sysmap_mmu_flg`，顺序为 `{So,C,B,Sh,Sec}`。 | `MAEE-TP-013` |
| `PTW-SVA-MAEE-005` | P0 | 1G 跨 sysmap region 时降级为 2M 或继续降级为 4K；2M 跨 region 时降级为 4K。 | `MAEE-TP-005/006/008` |
| `PTW-SVA-MAEE-006` | P0 | no-cross 时不得降级；原 page size 保持。 | `MAEE-TP-004/007` |
| `PTW-SVA-MAEE-007` | P0 | 降级只修改最终 PPN/page_size/属性，不访问下一级页表，不重新解释 leaf 权限。 | `MAEE-TP-010` |
| `PTW-SVA-MAEE-008` | P0 | 1G/2M PPN misaligned 时优先 page fault，不进入 sysmap/degrade。 | `MAEE-TP-011` |
| `PTW-SVA-MAEE-009` | P1 | 进入 sysmap/degrade 后，即使 `cp0_mmu_maee` 后续变化，当前 CSR refill 不回退到 PTE 属性路径。 | `MAEE-TP-012` |
| `PTW-SVA-MAEE-010` | P1 | `mmu_sysmap_pa*` 等于 sysmap adder PA 的 `[39:12]`，所有 TWU port 都覆盖。 | `MAEE-TP-*` |

#### 13.21.10 Reset、satp/PMP 改变与 abort 断言

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `PTW-SVA-CTX-001` | P0 | reset 清 PDE cache、TWU valid、mbuf entry、refill/exception visible state；PTW/L1TLB/L2TLB 输出 valid 拉低。 | §11.1 |
| `PTW-SVA-CTX-002` | P0 | `regs_ptw_clr` 或 `pmp_regs_update` 只清 PDE cache，不清 in-flight TWU/mbuf/refill/exception；旧 in-flight 后续非叶 no-fault 可重新 update PDE。 | §11.2-11.3 |
| `PTW-SVA-CTX-003` | P0 | `tlboper_ptw_abort` 清 PDE cache，并 flush 未完成 TWU/mbuf/refill normal path。 | §11.4 |
| `PTW-SVA-CTX-004` | P0 | abort 无 LSU outstanding 时，下一可接受窗口不得残留旧 request 的 refill/update。 | `MBUF-TP-009` |
| `PTW-SVA-CTX-005` | P0 | abort 有 LSU outstanding 时，ready 在必要等待期间保持低或不 accept 新 request；LSU response 到达并丢弃后 ready 可恢复。 | `MBUF-TP-010` |
| `PTW-SVA-CTX-006` | P1 | satp.asid/ppn 无 abort mid-walk 交错默认由 UVM constraint 禁止；若专测该交错，SVA 不应把旧 walk 使用新 ASID refill 判为 DUT fail。 | `PTW-AUD-021` |

#### 13.21.11 L1DTLB consumer-side SVA 更新要求

`mmu_l1dtlb_sva.sv` 已经覆盖大量 L1DTLB 行为。它们应在 PTW spec 中登记为 consumer-side evidence，防止审核时误把 L1DTLB 断言当作 PTW source-side 断言。

| L1DTLB SVA group | 当前/要求的断言 | PTW 审核用途 |
| --- | --- | --- |
| top reset/clear | `a_reset_clears_visible_state`、`a_regs_utlb_clr_clears_entries`、`a_tlboper_utlb_clr_clears_entries` | 证明 L1DTLB 可被清空；不证明 PTW abort 清 PDE/flush。 |
| hit/terminal response | `a_pipe0_hit_returns_t0`、`a_pipe1_hit_returns_t0`、`a_dual_hit_returns_both`、`a_page_fault_has_pa_vld` | 证明 L1DTLB hit/fault 对 LSU 可见；不证明 PTW leaf/PTE fault 生成正确。 |
| miss/MB alloc | `a_same_4k_miss_dedup_top`、`a_mb_cam_hit_no_alloc*`、`a_mb_full_no_alloc_top`、allocator one/two-free asserts | 归 L1DTLB MB 行为；不能关闭 PTW MBUF/PDE/LSU tests。 |
| L2TLB request scheduler | `a_l2_req_payload_known`、`a_l2_req_eid_in_range`、`a_l2_req_matches_mb_payload`、scheduler credit asserts | 证明 L1DTLB 发往 L2TLB/PTW 的 consumer chain 合法；PTW ready/hold 仍由 PTW SVA 检查。 |
| PTW refill install | `a_no_install_on_fault_refill_only`、`a_wfi_priority_over_ptw_l2`、`a_ptw_priority_over_l2`、`a_install_payload_known_legal` | 证明 PTW load/store refill 可被 L1DTLB install；PTW flg/global/asid/source correctness 仍需 PTW monitor。 |
| exception CAM | `a_expt_write*_fault_exclusive`、`a_no_dual_write_same_eid`、`a_abort_does_not_consume*`、`a_match*_key_uses_iid_vpn` | 证明 PTW load/store page/access fault 被 L1DTLB 按 eid/iid/vpn 消费；PTW fault class 生成仍需 PTW source-side。 |
| stale/flush/refill race | `a_wfg_flush_*`、`a_wfc_flush_*`、`a_wfi_flush_to_idle`、`cp_l1dtlb_c017_stale_or_abt_refill` | 证明 L1DTLB 自身 flush/stale refill 处理；不替代 PTW abort outstanding 断言。 |
| direct-map/STAMO | `a_direct_map_no_new_miss_top`、`a_stamo_no_*`、`a_stamo_bypass_not_miss` | 归 L1DTLB/system sysmap direct-map，不关闭 PTW MAEE=0 sysmap leaf refill。 |

必须新增或确认的 L1DTLB consumer SVA：

| SVA ID | Priority | 断言要求 | 绑定测试点 |
| --- | --- | --- | --- |
| `L1D-SVA-PTW-001` | P0 | `ptw_l1dtlb_ref_pa_vld` 只允许 load/store type 安装；PFU/fetch 不得写 L1DTLB data TLB。 | `PTW-ADD-004/032` |
| `L1D-SVA-PTW-002` | P0 | `ptw_l1dtlb_cmplt` 的 `ptw_l1tlb_id[2:0]` 必须命中 WFC/WFI 或 exception entry；stale id 不得 install 或 consume。 | L1DTLB stale id tests |
| `L1D-SVA-PTW-003` | P0 | PTW page fault 与 access fault 写入 expt CAM 时互斥，fault class 不丢失。 | `TC-PTWREF-CMPLT-*` |
| `L1D-SVA-PTW-004` | P1 | L1DTLB install 的 `vpn/ppn/pgs/flg` 与 PTW source-side monitor 捕获的同 `type/id` refill 一致。 | `PTW-ADD-032/034` |
| `L1D-SVA-PTW-005` | P1 | L1DTLB fault replay 对 LSU 返回 terminal response，不重新分配新的 PTW miss。 | `DTLB_MB_PGFLT_*`、`DTLB_ACCESS_FAULT_*` |

#### 13.21.12 现有 `mmu_l1dtlb_sva.sv` 逐项归属清单

本节列出当前 `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` 已有断言的文档归属。表中 `consumer-only` 表示只能作为 PTW 输出消费证据；`l1dtlb-owned` 表示完全归 L1DTLB 功能；`auxiliary` 表示可辅助 PTW 集成调试但不能关闭 PTW source-side requirement。

##### 13.21.12.1 `mmu_l1dtlb_sva` top-level 断言

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_reset_clears_visible_state` | `l1dtlb-owned` | L1DTLB visible state reset；PTW reset 仍用 `PTW-SVA-CTX-001`。 |
| `a_regs_utlb_clr_clears_entries`、`a_tlboper_utlb_clr_clears_entries` | `l1dtlb-owned` | L1DTLB entry clear；不证明 PTW PDE cache clear。 |
| `a_stamo_no_pipe0_bypass`、`a_stamo_no_new_miss_side_effect` | `l1dtlb-owned` | STAMO bypass；非 PTW。 |
| `a_abort0_not_miss`、`a_abort1_not_miss`、`a_abort*_no_expt_consume_top` | `l1dtlb-owned` | LSU pipe abort 不分配/不消费 L1DTLB exception；不同于 `tlboper_ptw_abort`。 |
| `a_expt_replay*_not_new_miss`、`a_expt_replay*_has_terminal_response` | `consumer-only` | 证明 L1DTLB exception replay 不再发 PTW miss。 |
| `a_pipe*_page_fault_has_pa_vld` | `consumer-only` | PTW/L1DTLB fault 被 LSU terminal response 消费；不证明 fault 公式。 |
| `a_wakeup_is_broadcast`、`a_wakeup_has_known_source`、`a_busy_mirrors_mb_valid` | `l1dtlb-owned` | DTLB wakeup/busy 行为。 |
| `a_pipe*_hit_returns_t0`、`a_dual_hit_returns_both` | `l1dtlb-owned` | L1DTLB hit path；非 PTW。 |
| `a_same_4k_miss_dedup_top`、`a_mb_cam_hit_no_alloc*`、`a_mb_full_no_alloc_top`、`a_one_free_dual_diff_at_most_one_alloc_top` | `l1dtlb-owned` | L1DTLB miss buffer allocation/dedup。 |
| `a_direct_map_no_new_miss_top` | `auxiliary` | system direct-map/L1DTLB evidence；不能关闭 PTW MAEE sysmap path。 |
| `a_legal_no_response_no_t0_terminal_top*` | `l1dtlb-owned` | no-response path 不产生 terminal response。 |
| `a_valid_entry_payload_known` | `l1dtlb-owned` | L1DTLB entry payload non-X。 |
| `a_va8_inv_clears_matching_entry`、`a_va8_inv_preserves_nonmatching_entry`、`a_clear_wins_install_same_entry` | `l1dtlb-owned` | VA8 invalidate/clear/install race；非 PTW PDE invalidate。 |
| `a_refill_entry_update_onehot`、`a_refill_payload_known`、`a_plru_refill_way_onehot` | `consumer-only` | 可证明 L1DTLB install 接收合法 refill；PTW refill 字段源头仍需 `PTW-SVA-ARB-*`。 |
| `a_mb_vld_matches_state`、`a_mb_ready_only_wfg`、`a_mb_wfc_matches_state`、`a_mb_wfi_matches_state`、`a_valid_mb_payload_known` | `l1dtlb-owned` | L1DTLB MB state decode。 |
| `a_l2_req_payload_known`、`a_l2_req_eid_in_range`、`a_l2_req_matches_mb_payload` | `auxiliary` | L1DTLB 发往 L2TLB 的 request payload；PTW request hold/ready 仍需 `PTW-SVA-REQ-*`。 |
| `a_expt_wr*_fault_exclusive`、`a_expt_wr*_has_fault_class`、`a_expt_wr*_payload_known`、`a_expt_wr*_id_in_range` | `consumer-only` | PTW/L2 fault 写入 L1DTLB exception CAM 的消费侧互斥和 payload。 |
| `a_l2_fault_is_page_fault_only` | `consumer-only` | L2 legacy fault 分类；不能证明 PTW access/page priority。 |
| `a_ptw_fault_requires_wfc_entry`、`a_l2_fault_requires_wfc_entry` | `consumer-only` | fault completion 必须匹配 L1DTLB waiting entry。 |
| `a_flush_blocks_new_side_effects` | `l1dtlb-owned` | RTU flush 对 L1DTLB side-effect 的限制。 |
| `a_hpc_miss_only_on_real_miss` | `auxiliary` | performance counter source 约束。 |

Top-level cover `cp_l1dtlb_c001..c026` 只用于证明 L1DTLB consumer/owning 场景被 hit。`cp_l1dtlb_c014_l2_req`、`cp_l1dtlb_c015_wfi_install`、`cp_l1dtlb_c016_fault_write`、`cp_l1dtlb_c019_expt_replay`、`cp_l1dtlb_c022_page_size_*` 可作为 PTW consumer-side 附加 evidence；其余多为 L1DTLB 自身 coverage。

##### 13.21.12.2 `mmu_l1dtlb_allocator_sva`

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_alloc_we_matches_grants`、`a_alloc_we_at_most_two` | `l1dtlb-owned` | L1DTLB MB allocation one/two port 数量。 |
| `a_no_free_no_grant` | `l1dtlb-owned` | L1DTLB MB full 行为；不等同 PTW MBUF full。 |
| `a_same_4k_dual_miss_dedup` | `l1dtlb-owned` | L1DTLB same-4K dedup；PTW PMBUF 无通用 dedup requirement。 |
| `a_two_free_dual_diff_allocates_both`、`a_single_req*_allocates_when_free` | `l1dtlb-owned` | L1DTLB allocator fairness/priority。 |
| `cp_l1dtlb_c004..c006_*` | `l1dtlb-owned` | allocator coverage；不关闭 PTW source-side。 |

##### 13.21.12.3 `mmu_l1dtlb_mb_entry_sva`

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_entry_vld_state_decode`、`a_entry_ready_state_decode`、`a_entry_wfc_state_decode`、`a_entry_wfi_state_decode` | `l1dtlb-owned` | L1DTLB MB FSM state decode。 |
| `a_alloc_latches_payload` | `l1dtlb-owned` | L1DTLB miss payload latch。 |
| `a_wfi_data_stable_without_grant` | `consumer-only` | 等待 install 的 refill payload 保持稳定。 |
| `a_fault_state_holds_until_replay_or_flush` | `consumer-only` | PTW fault 被 L1DTLB 保存到 replay/flush。 |
| `a_refill_fault_exclusive` | `consumer-only` | L1DTLB 入口看到 refill/page/access fault 互斥；PTW 顶层仍需 `PTW-SVA-ARB-001`。 |
| `a_refill_success_payload_legal` | `consumer-only` | 成功 refill page size/flg/ppn 合法；字段源头由 PTW monitor/SVA 关闭。 |
| `a_wfg_flush_*`、`a_wfc_flush_*`、`a_wfi_flush_to_idle` | `l1dtlb-owned` | L1DTLB RTU flush race。 |
| `cp_l1dtlb_c017_stale_or_abt_refill` | `consumer-only` | stale/abort refill consumer behavior。 |
| `cp_l1dtlb_c015_wfi_hold`、`cp_l1dtlb_c020_flush_race` | `l1dtlb-owned` | L1DTLB hold/flush coverage。 |

##### 13.21.12.4 `mmu_l1dtlb_scheduler_sva`

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_credit_in_range`、`a_reset_credit_max`、`a_no_req_without_credit_or_return`、`a_credit_*` | `l1dtlb-owned` | L1DTLB/L2TLB request credit；非 PTW ready。 |
| `a_req_payload_known`、`a_req_id_in_range` | `auxiliary` | L1DTLB 发往 L2TLB request 合法性。 |
| `a_issue_sel_onehot0`、`a_req_matches_issue_grant` | `l1dtlb-owned` | scheduler grant shape。 |
| `a_old_mb_priority_over_bypass`、`a_mb_req_payload_matches_entry`、`a_bypass*_req_matches_alloc` | `l1dtlb-owned` | L1DTLB scheduler priority and payload。 |
| `cp_l1dtlb_c014_*` | `auxiliary/l1dtlb-owned` | 可辅助证明 L1DTLB request source hit，但不关闭 PTW source-side。 |

##### 13.21.12.5 `mmu_l1dtlb_install_sva`

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_install_wakeup_shape`、`a_install_wakeup_on_install` | `consumer-only` | refill install 引发 wakeup。 |
| `a_no_install_on_fault_refill_only` | `consumer-only` | PTW/L2 fault completion 不得误 install。 |
| `a_grant_bus_onehot0`、`a_plru_way_onehot_on_refill` | `l1dtlb-owned` | install grant/PLRU shape。 |
| `a_wfi_priority_over_ptw_l2` | `l1dtlb-owned` | WFI pending data 优先于新 PTW/L2 refill。 |
| `a_ptw_priority_over_l2` | `consumer-only` | 同拍 PTW 与 L2 refill 时 PTW 优先，证明消费侧优先级。 |
| `a_l2_selected_when_no_wfi_ptw` | `l1dtlb-owned` | 无 WFI/PTW 时选择 L2 refill。 |
| `a_install_payload_known_legal` | `consumer-only` | install payload 合法；不证明 PTW flg bit layout。 |
| `cp_l1dtlb_c015_wfi_priority`、`cp_l1dtlb_c015_ptw_l2_collision`、`cp_l1dtlb_c018_install_release` | `consumer-only/l1dtlb-owned` | PTW refill 被 L1DTLB install 的覆盖证据。 |

##### 13.21.12.6 `mmu_l1dtlb_expt_cam_sva`

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_expt_write*_fault_exclusive` | `consumer-only` | page/access fault 写入互斥。 |
| `a_expt_write_payload_known`、`a_no_dual_write_same_eid` | `consumer-only` | fault payload/eid 写入合法。 |
| `a_no_dual_consume_same_entry` | `l1dtlb-owned` | exception CAM 消费 onehot。 |
| `a_abort_does_not_consume*` | `l1dtlb-owned` | LSU pipe abort 不消费 exception。 |
| `a_match*_has_fault_class`、`a_match*_key_uses_iid_vpn` | `consumer-only` | fault replay class/key 正确。 |
| `a_expt_wakeup_shape`、`a_expt_wakeup_on_consume` | `consumer-only` | exception replay wakeup。 |
| `a_flush_blocks_consume_next` | `l1dtlb-owned` | RTU flush 后不消费旧 exception。 |
| `cp_l1dtlb_c016_dual_expt_write`、`cp_l1dtlb_c019_expt_page_replay`、`cp_l1dtlb_c019_expt_access_replay` | `consumer-only` | PTW/L2 fault 被 L1DTLB exception CAM hit 的 coverage。 |

##### 13.21.12.7 `mmu_l1dtlb_hit_rd_sva`

| Assertion/Cover | 归属 | 说明 |
| --- | --- | --- |
| `a_hit_response_t0` | `l1dtlb-owned` | hit path terminal response。 |
| `a_page_fault_has_pa_vld` | `consumer-only` | page fault 对 LSU visible。 |
| `a_direct_map_terminal_response` | `auxiliary` | system direct-map/L1DTLB direct response。 |
| `a_expt_replay_not_new_miss`、`a_expt_replay_has_fault_class` | `consumer-only` | exception replay 不再产生 PTW miss。 |
| `a_tlb_hit_not_expt_hit_same_req` | `l1dtlb-owned` | hit 与 exception CAM mutual exclusion。 |
| `a_abort_blocks_miss` | `l1dtlb-owned` | LSU pipe abort。 |
| `a_stamo_bypass_not_miss`、`a_stamo_pa_source` | `l1dtlb-owned` | STAMO path。 |
| `a_access_fault_known_payload` | `consumer-only` | access fault payload non-X。 |
| `a_plru_hit_sample_known`、`a_valid_hit_only_from_valid_entry` | `l1dtlb-owned` | hit/PLRU consistency。 |
| `cp_l1dtlb_c010_page_fault`、`cp_l1dtlb_c021_access_fault` | `consumer-only` | fault visible coverage。 |
| `cp_l1dtlb_c002_single_hit`、`cp_l1dtlb_c011_direct_map`、`cp_l1dtlb_c012_*`、`cp_l1dtlb_c026_vabuf_changes` | `l1dtlb-owned/auxiliary` | L1DTLB own coverage。 |

#### 13.21.13 PTW source-side SVA 新增优先级清单

当前仓库已有 `mmu_pmp_twu_sva.sv`、`mmu_ptw_lsu_protocol_sva.sv`、`mmu_maee_twu_sva.sv`、`mmu_sysmap_sva.sv`、`mmu_arb_sva.sv`、`mmu_l1dtlb_sva.sv`。按本文 signoff 仍需优先新增或增强以下 source-side SVA：

| Priority | 新增/增强项 | 原因 |
| --- | --- | --- |
| P0 | `mmu_ptw_top_sva.sv`：`PTW-SVA-REQ-*`、`PTW-SVA-ARB-*`、`PTW-SVA-CTX-*` | 当前缺少 PTW 顶层 ready/type/id/target/priority/abort source-side 闭环。 |
| P0 | `mmu_pde_cache_sva.sv`：`PTW-SVA-PDE-*` | 当前 PDE cache 精确规则多在文档/测试计划中，缺 source-side assertion。 |
| P0 | `mmu_ptw_xbar_sva.sv`：`PTW-SVA-XBAR-*` | 旧 round-robin 口径已废弃，必须用 hash SVA 固化。 |
| P0 | `mmu_twu_chk_sva.sv`：`PTW-SVA-CHK-*` | PTE/PFU/page fault 是 PTW 核心源头规则，不能只靠 L1DTLB fault consumer。 |
| P0 | 增强 `mmu_ptw_lsu_protocol_sva.sv`：`PTW-SVA-MBUF-001/002/006..012` | 当前已有 single outstanding/addr stable，但 bus error、CHK hold、abort same-cycle 边界仍需更完整。 |
| P0 | 增强 `mmu_maee_twu_sva.sv`/`mmu_sysmap_sva.sv`：THD/4K sysmap、no-lower-walk、flag order、degrade PPN | 当前 MAEE SVA 明确只覆盖 FST/SCD；spec 要求 4K/THD。 |
| P1 | L1DTLB `L1D-SVA-PTW-004` 与 PTW monitor cross-check | 用于把 consumer install payload 与 PTW source monitor 关联，提升调试效率。 |

#### 13.21.14 SVA 与测试点闭环矩阵

| 测试点族 | 必须有的 SVA evidence | 不能用来替代的检查 |
| --- | --- | --- |
| `PTW-AUD-001/002` RSW/G/flg | `PTW-SVA-CHK-009/010`、`PTW-SVA-ARB-008` | L2TLB tag hit 或 L1DTLB install pass 不能单独证明 flg bit layout。 |
| `PTW-AUD-003/004` type/id target | `PTW-SVA-ARB-004..007`、`L1D-SVA-PTW-001..003` | 只看 L2TLB miss buffer release 不够，必须看 L1 target enable。 |
| `PTW-AUD-005/006/007` PDE | `PTW-SVA-PDE-001..010` | 第二次访问成功或更快不能关闭 PDE hit/update/race。 |
| `PTW-AUD-008` Xbar/ready | `PTW-SVA-REQ-001..003`、`PTW-SVA-XBAR-001..006` | 旧 round-robin/idle-first cover 必须作废。 |
| `PTW-AUD-009/010/011` PMP/MPRV | `PTW-SVA-PMP-001..009` | PMP standalone tests 只能辅助，不关闭 PTW no-LSU/no-refill。 |
| `PTW-AUD-012/013/014` PTE/page fault | `PTW-SVA-CHK-001..011` | L1DTLB pgflt consumer pass 不证明 PTE fault 公式正确。 |
| `PTW-AUD-015/016/017` MBUF/LSU/abort | `PTW-SVA-MBUF-001..012`、`PTW-SVA-CTX-003..005` | LSU memory model no-error smoke 不够，必须命中 bus_error/abort 时序。 |
| `PTW-AUD-018/019/020/021` MAEE/sysmap/context | `PTW-SVA-MAEE-001..010`、`PTW-SVA-CTX-002/006` | system sysmap bypass tests 不能关闭 PTW leaf refill 属性路径。 |
| `PTW-FLOW-001..023` | 对应 `PTW-SVA-*` cover hit 加 scoreboard final match | 只跑 directed test name 不能关闭 flow。 |
| L1DTLB consumer-only | `L1D-SVA-PTW-001..005`、现有 `mmu_l1dtlb_sva.sv` cover | 不能关闭 PTW source-side PTE/PMP/PDE/MAEE。 |

#### 13.21.15 SVA signoff 输出要求

1. 每个 SVA module 的 `final` block 或统一 report script 必须打印 cover hit，格式建议：

```text
PTW_SVA_COVER module=<module> name=<cover_name> hits=<N>
```

2. regression gate 至少检查：
   - 所有 P0 assert 0 fail。
   - P0/P1 directed test 对应 cover hit > 0。
   - 每个 `PTW-AUD-*`、`PTW-FLOW-*` 至少有一条 source-side SVA/monitor/scoreboard evidence。
   - consumer-only 项必须在报告中明确标注 `consumer-only`，不得自动提升为 PTW source-side closure。
3. 新增 SVA 若因 RTL 信号不可见暂时无法实现，必须在 signoff matrix 中登记 `waiver`，写明缺口、替代 monitor 和计划绑定信号。
4. SVA fail 的 triage 分类固定为：`RTL bug`、`TB illegal stimulus`、`SVA over-constraint`、`spec mismatch`。任何 `spec mismatch` 必须回改本文或 RTL，不允许只在 log 中口头解释。

## 14. 旧答案冲突与最终解释

1. 旧说法 “tlboper 只屏蔽当前 PDE cache 请求” 废弃；最终为清空全部 PDE cache 并 flush in-flight PTW。
2. 旧说法 “abort 期间异常都不屏蔽” 收窄；最终只有 abort 前已进入异常寄存器并在顶层仲裁获授权的异常可上报，新形成 LSU bus error 不上报。
3. 旧说法 “RSW 不进入 refill flg” 废弃；最终 RSW 进入 refill `flg`，但不参与 page fault。
4. 旧说法 “严格遵循标准 Sv39 全部检查” 废弃；最终按本设计 RTL/文字规则，不检查 reserved bits、RSW、strong-order。
5. 旧说法 “大页对齐不检查” 废弃；最终 1G/2M PPN 对齐错误触发 page fault。
6. 旧说法 “satp/PMP 清 PDE cache 后旧 walk 不应再更新 PDE cache” 废弃；最终允许旧 in-flight walk 重新更新，除非被 abort/flush 屏蔽。
7. 旧说法 “load/store/PFU 在 `MPRV=1 && MPP=M` 下可用 machine effective mode 走 PTW” 废弃；最终为 data/PFU direct-map/no PTW source，fetch 单独按真实流水线特权级判断。
8. 旧流程标题中 “第一级 PDE cache 命中最终 4K/2M” 反置的地方已修正：`scd_chk` leaf 是最终 2M；`scd_chk` 非叶子后进入 `thd_pmp/thd_chk` 是最终 4K。
9. 旧流程中第三级误写 `scd_pmp` 的地方统一解释为 `thd_pmp`。
10. 旧 sysmap 属性顺序里有 `{Sec,Sh,B,C,So}` 文字描述；最终 refill/sysmap 建模统一使用 `{So,C,B,Sh,Sec}`。

## 15. 原始澄清问答覆盖索引

本节按 `ptw_overview.md` 的问题编号列出覆盖关系，确保所有问答细节已经进入本文正式规则。若本节条目与前文正式规则看起来有差异，按前文正式规则理解，因为前文已经应用“后轮覆盖前轮”的收敛。

1. Q1：PTW 只支持 Sv39、三级页表、4KB 基页；Bare 模式由上游保证不进 PTW。
2. Q2：PTW 输入只有 27 bit VPN，不处理 offset、高位 VA、canonical 检查。
3. Q3：PTE PPN 为 28 bit，对应 40 bit PA，不存在超范围 PPN 检查。
4. Q4：`regs_ptw_satp_ppn` 是根页表 PPN；walk 中改变通常由后续 abort 收敛，否则存在硬件交错。
5. Q5：`vpn[2:0]` 与 Sv39 VPN[2:0] 一致。
6. Q6：L2TLB 请求字段为 `vpn/type/id`，type 和 id 编码已在第 2 章定义。
7. Q7：type 编码为 PFU `100`、IUTLB `011`、Load `010`、Store `110`。
8. Q8：`id[5:3]` 定位 L2TLB MB，`id[2:0]` 定位 L1DTLB MB，同 id 不提前复用。
9. Q9：正常 refill 返回 `ppn/flg/page_size/vpn/asid/global/type/id`。
10. Q10：同周期最终输出只允许一种，优先级 access fault > page fault > refill。
11. Q11：PDE cache entry 不含 ASID/global/权限/属性，PLRU 独立维护。
12. Q12：PDE cache 不按 ASID tag 隔离，依赖 satp 改变清空。
13. Q13：PDE cache 16 entry 全相联，tag 比较，单请求 lookup 无多请求仲裁。
14. Q14：一级 PDE cache data 是一级非叶子 PTE PPN，二级 data 是二级非叶子 PTE PPN。
15. Q15：两级 PDE cache 同时 hit 选择二级，不校验一致性。
16. Q16：PDE cache 命中跳过级别依赖填入时已通过 PMP/page fault 检查。
17. Q17：PDE cache update 要求非叶子、无 page fault、未被 abort/flush 屏蔽，不要求上下文仍有效。
18. Q18：`tlboper_ptw_abort` 全清 PDE cache，并 flush in-flight PTW，无按 VA/ASID 精确失效。
19. Q19：xbar hash 为 VPN 多段 XOR；内部 TWU 监控需精确预测 hash。
20. Q20：PTW ready 低时 L2TLB 保持 valid 和字段稳定。
21. Q21：PTW 每周期最多 accept 一个 L2TLB 请求。
22. Q22：TWU 接收条件受目标流水、mbuf、异常/refill 寄存器和跨页状态机反压影响。
23. Q23：PMP 检查页表项所在物理地址，不检查最终翻译 PA。
24. Q24：PMP deny 公式按 `pmp_mmu_flg[2/1/0/3]` 和 effective mode 建模。
25. Q25：PMP 访问类型与原始请求 type 相关。
26. Q26：PMP deny 和 LSU bus error 都返回 access fault；UVM 功能结果无需区分错误编码。
27. Q27：PMP access fault 后请求立即停止，不再可能 page fault。
28. Q28：仲裁中“高等级页表”表示更接近 leaf 的第三级优先。
29. Q29：page fault 最终按本设计规则，不额外套标准 Sv39 reserved/RSW/strong-order。
30. Q30：leaf 判定为 `V=1 && (R||X)`。
31. Q31：非叶子非法组合最终只保留 V=0、write-only、三级非叶子等检查。
32. Q32/Q89：大页对齐旧答错误，最终 1G PPN[1:0] 和 2M PPN[0] 必须为 0。
33. Q33：硬件不自动置 A/D，不满足直接 page fault。
34. Q34：MXR、SUM、privilege、MPRV 参与权限检查。
35. Q35：异常按 type 路由到对应模块，但异常类别只有 page/access 两类。
36. Q36：第三级非叶子必定 page fault。
37. Q37：mbuf 为 8 个 DTLB entry + 1 个 IUTLB entry，DTLB 指针轮转。
38. Q38：mbuf 写入 IUTLB 优先，IUTLB 专用 entry 依赖 IFU 单 outstanding 不溢出。
39. Q39：IUTLB 不会持续饥饿 DTLB，因为 IFU 阻塞式单请求。
40. Q40：LSU 单 outstanding，通过 `mbuf_on` 定位返回 entry。
41. Q41：`mbuf_on` 表示 entry 请求正在 LSU 中处理。
42. Q42：LSU 不允许多 outstanding。
43. Q43：LSU 返回 64 bit，全部为 PTE。
44. Q44：LSU 数据返回但 CHK 不 ready 时，entry 保存数据且不阻塞其他 LSU 请求。
45. Q45：MAEE 表示 PTE 携带内存属性机制，开启时使用 PTE 高位 `{So,C,B,Sh,Sec}`。
46. Q46/Q165：MAEE 关闭时属性来自 `ct_mmu_sysmap/sysmap.h`，最终顺序 `{So,C,B,Sh,Sec}`。
47. Q47：大页跨页检查判断最终物理页覆盖范围是否落在同一 sysmap 区域。
48. Q48/Q107/Q152：1G/2M first/last PPN 公式按第 10 章。
49. Q49/Q108：1G 降级 2M 最终 PPN 为 `{pte.ppn[2],vpn[1],9'b0}`。
50. Q50/Q109：2M 降级 4K 最终 PPN 为 `{pte.ppn[2],pte.ppn[1],vpn[0]}`。
51. Q51：降级后的权限、A/D/G/U 等来自原始大页 leaf PTE。
52. Q52：降级过程不再访问内存，只改写 PPN/page size/属性。
53. Q53/Q110：4K 不跨 sysmap，sysmap 异常配置不考虑。
54. Q54：跨页状态机 refill 请求未授权时保持，可被 abort 屏蔽。
55. Q55：每个 TWU 各有一组 page/access/refill 寄存器，busy 时反压流水。
56. Q56：顶层仲裁先按 IUTLB/DTLB，再按 TWU index 低优先。
57. Q57：无专门防饥饿，依靠请求数量有限和写回一拍。
58. Q58：异常也返回原始 type/id；IUTLB 低 id 返回但不用。
59. Q59/Q148/Q159/Q162：abort 期间只有已在异常寄存器且获顶层授权的异常可上报。
60. Q60：`tlboper_ptw_abort` 是单周期脉冲。
61. Q61：abort 清 in-flight valid。
62. Q62/Q147：abort 后 LSU 返回普通数据必须丢弃，不进 CHK/PDE/refill。
63. Q63：abort 屏蔽成功 refill，异常可见性用于精确异常和 miss 收尾，但已被后续规则收窄。
64. Q64：abort 后 L2TLB 重发未完成请求，已完成异常的 entry 不重发。
65. Q65/Q140：除 reset 外，flush/abort 来源主要为 `tlboper_ptw_abort`；satp/PMP 只清 PDE cache。
66. Q66-Q71：周期示例用于流水/monitor，scoreboard 只要求功能最终匹配。
67. Q67：PDE lookup、xbar、进入 PMP 可按连续阶段监控。
68. Q68：PMP flg 组合返回，仲裁失败保持流水。
69. Q69：mbuf 写入后可下一拍发 LSU。
70. Q70：CHK 一拍完成检查和请求发起建模。
71. Q71/Q118/Q144：scoreboard 不设固定周期上限。
72. Q72-Q75：术语统一为 PDE cache、第二级、经过、最终、CHK、arbiter、`thd_chk_wait`。
73. Q76：本文加入字段、状态、异常、优先级和 UVM checklist。
74. Q77：Bare 模式上游保证不向 PTW 发起 walk。
75. Q78/Q80：CP0/CSR 状态在使用点读取当前值，不随请求统一锁存。
76. Q79：satp.ppn 无 abort 改变可能产生硬件交错，软件应 fence/abort，UVM 可约束。
77. Q81：PFU 成功只 refill L2TLB。
78. Q82：PFU 触发异常会上报，不静默丢弃。
79. Q83：无独立 AMO type，store 覆盖 atomic。
80. Q84：IUTLB id 固定/低位忽略。
81. Q85/Q127/Q164/Q165：refill flg 包含扩展属性、RSW、D/A/U/X/W/R/V；G 只进 tag/global。
82. Q86：page size 编码 1G=`100`、2M=`010`、4K=`001`。
83. Q87：ASID 使用 refill 返回当拍 satp ASID。
84. Q88/Q128：PTE bit 定义和扩展属性位为 bit63-bit59。
85. Q90：PTE 高位保留位不检查。
86. Q91：MAEE 关闭时忽略 PTE 扩展属性。
87. Q92/Q131：write-only 规则允许 `W=1,R=0,X=1,MXR=1` 通过。
88. Q93/Q167：非叶子只检查 V=0、write-only、三级非叶子。
89. Q94-Q96/Q132/Q133：leaf 权限、A/D、PFU 独立规则按第 6 章。
90. Q97：satp 任意字段改变清 PDE cache。
91. Q98/Q124/Q160/Q161：tlboper abort 清全部 PDE cache，当前 RTL 已实现。
92. Q99：PDE cache PLRU 命中和写入更新，invalid entry 优先。
93. Q100：PDE lookup/update 同拍 lookup 看旧值，update 下拍生效。
94. Q101/Q138：PMP 配置改变硬件清 PDE cache，不 flush in-flight。
95. Q102：mbuf entry 在数据成功送入 CHK 后释放。
96. Q103：DTLB mbuf 分配指针依赖上游保证不会指向仍 valid entry。
97. Q104/Q121/Q145：LSU bus error 不进 CHK，写异常寄存器成功后释放 entry。
98. Q105/Q148/Q159：abort 同拍新 LSU bus error 不上报。
99. 额外 abort 数据保存问题：已保存但未送 CHK 的数据遇 abort 直接清 valid 丢弃。
100. Q111/Q149/Q150：MAEE=0 时所有 page size 包括 4K 都从 sysmap 取扩展属性。
101. Q112/Q123/Q153：大页不降级时属性取尾地址 sysmap，同区取首尾等价。
102. Q113：跨页检查结束后写 refill 寄存器，再顶层仲裁返回。
103. Q114：TWU 内部仲裁为 IUTLB > thd > scd > fst。
104. Q115：normal refill 仲裁为 IUTLB > 跨页状态机 > thd > scd > fst。
105. Q116：LSU bus error 在 access fault 源中优先于 4 个 TWU。
106. Q117：同一请求结构上不会同时 bus error 和 CHK page fault。
107. Q119/Q154/Q157/Q158：一级 PDE hit 的 2M/4K 流程已在 12.15/12.16 修正。
108. Q120/Q171/Q180：二级 PDE hit 进入 `thd_pmp`，第三级笔误统一改为 `thd_pmp`。
109. Q122/Q146/Q147：abort 与 LSU outstanding 边界以 abort 前一拍 LSU valid 是否为 1 判断。
110. Q125/Q160：当前无已知 RTL 待修项。
111. Q126：RTL 表达式是规范性依据；若文字和表达式冲突，按后续文字最终回答。
112. Q129：global 只来自 leaf PTE G，不 OR 上级 G。
113. Q130/Q174：RSW 进入 refill flg 但不参与异常。
114. Q134/Q173-Q179：MPRV/MPP effective privilege 规则按第 7 章。
115. Q135：page/access fault 只有两类标志，PFU 无独立 cause 编码。
116. Q136：satp 改变只清 PDE cache，不清 in-flight。
117. Q137/Q169：satp.asid/ppn 无 abort 改变由软件避免，UVM 可约束。
118. Q139：abort 同拍 PDE lookup/update 被冲刷，cache 最终 invalid。
119. Q141：IUTLB refill L1ITLB+L2TLB，Load/Store refill L1DTLB+L2TLB，PFU 只 L2TLB。
120. Q142：PFU 异常返回 L2TLB，再上报 LSU prefetch 端口。
121. Q143/Q172：返回有仲裁顺序，但 scoreboard 只按 type/id 最终匹配；仲裁交给 assertion。
122. Q151：MAEE 进入跨页/sysmap 后，最终属性不因后续 MAEE 改变回退。
123. Q155：satp/PMP 清 PDE cache 下一拍 valid 拉低，不影响 in-flight，不要求 L2TLB 重发。
124. Q156：PFU 成功/异常完整流程见 12.20/12.21。
125. Q163：MAEE=0 且 4K 走 sysmap 的 RTL 已修好。
126. Q166/Q176：reference model 不额外检查 standard Sv39 reserved/RSW/strong-order。
127. Q168/Q175：satp/PMP 清 cache 后旧 in-flight 非叶子仍可更新 PDE cache。
128. Q170：跨页流程标题以最终 page size 为准：1G->2M、1G->4K、2M->4K。
129. Q177：fetch 用真实特权，load/store/PFU 在 MPRV=1 用 MPP，否则真实特权。
130. Q178：最新修正覆盖旧答；`MPRV=1 && MPP=M` 时 load/store/PFU 不进入 PTW，物理地址直接等于虚拟地址。
131. Q179：最新修正覆盖旧答；不存在合法的 data/PFU MPRV machine effective PTW walk，fetch 仍按真实流水线特权级。

`ptw_overview.md` 中未单独列在上面的重复问题、标题修正、错别字修正和“已补充”回答，均已合并到本文对应章节；没有需要继续追加到原文末尾的新问题。

## 16. `ptw_overview.md` 原文归档

以下归档保留 `ptw_overview.md` 的当前全文，用于追溯问题来源和人工审核。若原文归档与本文前面的正式规格冲突，以前文正式规格和“最终采用规则”为准。

ptw模块的详细工作原理：（页表大小份：1G\2M\4K）（虚拟地址39bit（vpn[26:0],offset[11:0]），vpn为27bit，vpn[2]为vpn[26:18]、vpn[1]为vpn[17:9]、vpn[0]为vpn[8:0];物理地址40bit（ppn[27:0],offset[11:0]），ppn为28bit，ppn[2]为ppn[27:18]、ppn[1]为ppn[17:9]、ppn[0]为ppn[8:0]，satp寄存器的值会提供第一级页表去ptw的基地址，即regs_ptw_satp_ppn[PPN_WIDTH-1:0]）
    1.pde cahe的工作：第一级和第二季pde cache都是默认16个entry。第一级pde cache的tag是vpn[2]，data是相应的ppn，第二级pde cache的tag是vpn[2]和vpn[1]，data是相应的ppn。每个L2tlb的请求进来时，都会先进入pde cache模块同时检查两级pde cache，并且检查所有的entry，如果命中了第一级pde cache的某个entry，那么认为命中第一级pde cache，如果命中了第二级pde cache的某个entry，那么认为命中第二级pde cache，如果命中，则选出命中的entry中相应的ppn，如果两级都命中，则认为是命中了第二级pde cache，因为第二级更靠近叶子页表。如果命中了第一级pde cache，则可以跳过twu中的第一级流水线（fst-pmp和fst-chk），并且携带选出的ppn，生成下一级页表的物理地址，进行后续处理;如果命中了第二级pde cache，则可以跳过twu中的第一和第二级流水线（fst-pmp和fst-chk、scd-pmp和scd-chk），并且携带选出的ppn，生成下一级页表的物理地址，进行后续处理。
    2.xbar_one_to_four的工作：将进过pde cache的请求分发到4个twu中的某一个，通过请求的vpn经过哈希hash决定分发的twu，以达到将请求尽可能平均的分配到4个twu的功能。当xbar_one_to_four准备将请求发射到某个twu，但是该twu暂时无法接收新请求时，那么会拉低ptw ready，ptw拒绝接收来自L2TLB的新请求。避免冲刷掉该请求。
    3.twu中pmp类流水线的工作（每一级页表都有一个pmp流水线）：生成要访问的物理地址，并且将该物理地址发到pmp，pmp会放回flg，根据flg和请求的类型可以判断pmp检测是否提供，如果未提供会触发访问异常（fetch类型请求需要保证pmp_mmu_flg[2]为低，load类型请求需要保证pmp_mmu_flg[0]为低，store类型请求需要保证pmp_mmu_flg[1]为低，pfu类型请求需要保证pmp_mmu_flg[0]为低，如果是机器模式，并且pmp_mmu_flg[3]（L-bit for M-Mode）为低，则跨页跳过pmp检查），如果通过，会发请求和请求的物理地址padder以及相关信号vpn、type、id（这三个请求必须一直携带）、twu_idx、lvl（twu_idx：可以标记该请求是哪个twu发送的，mbuf返回时可以返回到对应的twu；lvl:请求要拿到的页表数据的级数，可以根据该级数决定返回到哪一级chk类流水线）到mbuf。
    4.twu中chk类流水线的工作（每一级页表都有一个chk流水线）：拿到lsu返回的数据时，mbuf会将数据返回到相应的twu，对应级别的chk流水线（根据twu_idx、lvl），chk流水线会进行检查，检查页表是否触发页表异常，并且检查页表是否是叶子页表。如果未触发页表异常，并且检查发现是叶子页表，那么会发出更新refill寄存器的请求。如果触发页表异常，会发出更新页表异常寄存器的请求，如果未触发页表异常并且不是叶子页表，那么会进入下一级的pmp流水线。
    5.在twu中的处理：每个twu每个时钟周期都可以接受一个请求（前提是twu可以接受的情况下）。重复的进行pmp流水线的处理、发请求到mbuf，然后发请求到lsu拿到相应级别的页表数据、进入chk流水线检查页表异常和叶子表项。有页表异常寄存器和访问异常寄存器和正常refill寄存器来缓存相应请求，然后再顶层进行仲裁返回到相应的位置。因为内存被分成8个区域，如果maee开启则直接使用页表数据中的属性，如果maee没开启则使用其在内存中其所在区域的默认属性配置，但是如果是大页表，则可能跨越8个区域之间的边界，占据两个区域，这时候无法判断使用这个区域的属性配置。所以如果maee开启则不需要考虑跨页检查，如果maee未开启并且是1G或2M页表则需要考虑跨页检查，如果是1G页表进入跨页检查，会将1G页表的首和尾地址发到sysmap模块，该模块会发返回这个地址是8个区域中的哪个，只有首尾地址都在同一个区域，才能证明他没跨越边界，这时候跨越正常回填了；如果他们不在同一个区域，则需要将1G页表降级为2M页表，ppn[1]也套用vpn[1]然后继续进行检查，如果未跨越，可以回填，如果跨越，则需要将2M页表降级为4K页表，ppn[0]也套用vpn[0],然后回填。
     6.mbuf的工作：接收各个twu的请求，进过仲裁后（itlb类型的请求优先），将请求更新进mbuf的entry中，mbuf有9个entry，8个给dtlb的请求，1个专门给itlb的请求，如果entry有效并且该entry的请求还没拿到lsu返回的数据，会根据发请求的指针，发送相应entry的物理地址（itlb的请求优先发）；lsu返回数据时会跟踪到相关的entry（通过mbuf_on去跟踪，因为mmu发请求到lsu拿数据是串行的，mmu发请求到lsu时会一直把请求有效信号拉高，并且请求的物理地址保持稳定，这是因为lsu与mmu的ptw是没有握手协议的，只有lsu返回数据有效信号，才会把mmu的请求有效信号拉低，如果mmu的ptw还有请求要发，则会继续把mmu的请求有效信号拉高，只是把物理地址换成下一个请求的物理地址，保持稳定），然后会检测要进入的该twu的该级chk流水线是否已经准备好，如果准备好，则发返回数据请求给twu，将数据返回给twu的chk流水线，如果没准备好，会把数据寄存到entry中的数据寄存器，等到准备好了才发返回数据请求给twu，将数据返回给twu的chk流水线。同时每次在拿到lsu返回的数据时，会检测是否满足更新进pde cache的条件（不是叶子表项并且不会触发页表异常），如果满足则把相应的vpn和ppn更新进pde cahe，根据lvl决定更新到哪一级pde cache。
     7.触发页表异常的处理：每个twu中的fst_chk、scd_chk、thd_chk流水线都会进行页表异常的检查，lsu在返回数据给mmu之后，都会进入chk类流水线进行页表异常检查，根据lsu返回的是哪一级页表的数据，来决定进入哪一级的chk流水线，如果在chkk类流水线检查发现触发了页表异常，会将该请求的类型和id（l1dtlb中mbuf的id）更新进页表异常寄存器，页表异常寄存器会发请求到顶层模块的仲裁器，对多个twu的请求进行仲裁，最总拿到仲裁的授权，将该页表异常上报到请求来源处，根据type决定上报到l1itlb还是l1dtlb，根据id中的L1TLB部分决定上报到l1dtlb中mbuf的哪个entry，根据id中的L2TLB部分去释放L2TLB中miss buffer的entry。
     8.触发访问异常的处理：每个twu中的fst_pmp、scd_pmp、thd_pmp流水线都会进行pmp的检查，如果pmp检查未通过，会触发访问异常；同时如果lsu返回数据的时候出现了总线错误，也会触发访问异常。如果在pmp类流水线检查未通过或者lsu出现总线异常会触发了访问异常，会将该请求的类型和id（l1dtlb中mbuf的id）更新进访问异常寄存器，访问异常寄存器会发请求到顶层模块的仲裁器，对多个twu的请求进行仲裁，最总拿到仲裁的授权，将该页表异常上报到请求来源处，根据type决定上报到l1itlb还是l1dtlb，根据id中的L1TLB部分决定上报到l1dtlb中mbuf的哪个entry。根据id中的L2TLB部分去释放L2TLB中miss buffer的entry。
    9.ptw ready信号：当xbar_one_to_four在分发请求到某个twu时，如果该twu暂时无法接受新请求，那么ptw就会拉低ready信号，不接受L2tlb的请求。避免请求被冲刷了。
    10.twu暂时无法接受新请求的情况：
      - twu屏蔽1-to-4 xbar模块发请求的情况：（防止请求冲突，数据被冲刷掉）（无法判断twu的落点在哪一级pmp）
        - 当pmp类流水线有wait信号时
        - Fst/ scd chk检查发现没有page fault和不是叶子表项，准备进入到下一级的PMP检查流水线时
    11.twu内部流水线停滞的情况：（都是为了防止冲刷掉其他请求，或者当前请求在该流水线的任务还未完成）
      - 1.fst_pmp_wait：
        - 当同时出现多个检查pmp的请求，fst_pmp的请求未被授权时
        - 当发出的写Mbuf的请求没有被Mbuf授权时
        - 当同时出现多个更新访问异常寄存器的请求，fst_pmp的请求未被授权时
      - 2.fst_chk_wait：
      - 当scd_pmp_wait拉高时，并且检查发现不是叶子表项时，防止覆盖掉scd_pmp的数据，fst_chk_wait拉高
      - 当发现是叶子表项并且maee开启，发出正常数据写回请求，fst_chk的请求未被授权时
      - 当同时出现多个更新页表异常寄存器的请求，fst_chk的请求未被授权时
      - 当发现是叶子表项并且maee未开启了，但是跨页处理不在空闲状态
    - - 3.scd_pmp_wait：
      - 当同时出现多个检查pmp的请求，scd_pmp的请求未被授权时
      - 当发出的写Mbuf的请求没有被Mbuf授权时
      - 当同时出现多个更新访问异常寄存器的请求，scd_pmp的请求未被授权时
    - - 4.scd_chk_wait：
      - 当thd_pmp_wait拉高时，并且检查发现不是叶子表项时，防止覆盖掉thd_pmp的数据，scd_chk_wait拉高
      - 当发现是叶子表项并且maee开启，发出正常数据写回请求，scd_chk的请求未被授权时
      - 当同时出现多个更新页表异常寄存器的请求，scd_chk的请求未被授权时
      - 当发现是叶子表项并且maee未开启了，但是跨页处理不在空闲状态
    - - 5.thd_pmp_wait：
      - 当同时出现多个检查pmp的请求，thd_pmp的请求未被授权时
      - 当发出的写Mbuf的请求没有被Mbuf授权时
      - 当同时出现多个更新访问异常寄存器的请求，thd_pmp的请求未被授权时
    - - 6.scd_chk_wait：
      - 当发现是叶子表项，同时出现其他回填的请求，thd_chk的请求未被授权时
      - 当同时出现多个更新页表异常寄存器的请求，thd_chk的请求未被授权时
    - 12.Abriter分布：
      - 1.TWU内部的abriter（itlb优先>高等级页表>低等级页表）
        - PMP检查的仲裁器（3个来源）（3级pmp流水线）
        - 正常数据写回refill的仲裁器（4个来源）（3级chk流水线和跨页检查状态机）
        - 进入跨页检查的仲裁器（2个来源）（第一级和第二级chk流水线）
        - 写入页表异常寄存器的仲裁器（3个来源）（3级chk流水线）
        - 写入访问异常寄存器的仲裁器（3个来源）（3级pmp流水线）
      - 2.TWU外部的abriter（对4个TWU的仲裁）（itlb优先>TWU索引低的优先）
        - 4个TWU发请求到mbuf，mbuf内容更新请求到entry的仲裁器（4个来源）（4个twu，在mbuf中）
        - 对4个TWU访问异常寄存器写回以及lsu触发总线错误的异常写回的仲裁器（5个来源）（4个twu和lsu总线异常触发的访问异常）
        - 对4个TWU页表异常寄存器写回的仲裁器（4个来源）（4个twu）
        - 对4个TWU正常数据写回的仲裁器（4个来源）（4个twu）
        - 对正常数据写回、访问异常写回、页表异常写回的仲裁器（3个来源）（保证每个时钟周期只返回一种结果）（访问异常写回>页表异常写回>正常数据写回）
    - 13.tlboper_ptw_abort对ptw的中断信号处理（因一致性/多核 shootdown、按 VA/ASID 或全 TLB 失效等需求，硬件要求立刻使一批或全部 TLB 项作废。这类请求与“正在进行的 miss 页表遍历”在时间上可能重叠；若此时仍允许本次 walk 的结果写入 jTLB，就会在已完成失效语义之后重新装入基于旧页表读出的映射，直接违背 shootdown 的顺序与可见性，造成陈旧翻译残留。因此在 LSU 已拉起 TLB 维护操作、但 tlboper 尚未稳定接管（tlb_lsu_oper && !tlb_lsu_oper_flop）的窗口内需要向 PTW 侧给出 tlboper_ptw_abort，从架构上强行切断“失效窗口内完成的 refill”与 TLB 的一致性假设，避免 invalidate 与 PTW 填表并发导致的错误可见性。）：
        - ptw中所有的请求都丢弃掉，pde cache的请求丢弃掉，4个twu的6级流水线都丢弃掉，mbuf的所有entry都无效化掉。回填请求也会被屏蔽，已经进入异常寄存器且正在顶层仲裁/已经被授权的异常请求则可以上报，但是未进入异常寄存器或者没拿到顶层仲裁授权的异常请求则被冲刷了。
        - 如果mbuf中有请求在lsu中处理，那么需要保持请求拉高，然后等待lsu返回数据有效信号，防止对后续请求造成影响。
        - 将所有请求冲刷掉并等待到lsu的返回信号后（只有之前发出请求到lsu中处理一半的情况下，才需要等待该信号），ptw ready才会拉高，然后让L2TLB的buffer重新发送所有的请求。
    - 14.L2TLB发来的请求附带信息：vpn、type（请求类型）、id[5:0](id[5:3]为L2TLB miss buffer的entry索引，id[2:0]为L1dTLB miss buffer的entry索引)（type和id一直伴随着请求的原因（不管是正常refill还是异常上报）是：请求返回的时候通过type决定去到哪个模块，fetch refill到itlb和L2TLB，然后通过id[5:3]去定位释放掉L2TLB miss buffer的entry，id[2:0]不会使用。load和store refill到dtlb和L2TLB，然后通过id[2:0]去定位到dtlb miss buffer的具体entry，通过id[5:3]去定位释放掉L2TLB miss buffer的entry。pfu只refill到L2TLB，通过id[5:3]去定位释放掉L2TLB miss buffer的entry，id[2:0]不会使用。）
    - 15.refill的数据包含tag和data，tag包含vpn、asid、page size和G位，data包括flg（除G位）、ppn。
    - 16.twu中流水线包含fst_pmp\fst_chk\scd_pmp\scd_chk\thd_pmp\thd_chk，pmp类流水线附带vpn、type、id、ppn（fst_pmp不携带ppn，用的是satp的基地址ppn），chk类流水线附带vpn、type、id和data（完整页表数据）。
    - 17.pmp类流水线发请求到mbuf附带信息包括：padder、vpn、type、id、lvl（属于哪一级，要访问哪一级页表）和twu_idx（发出请求的twu的索引）这些内容会一起被存储进mbuf的entry中，当该entry的请求别发送时，其on信号拉高，表示请求在途，当lsu返回数据有效信号时，会检查其定位到的twu的chk是否准备好了，如果准备好了，会发出返回的请求，拿到授权后，会携带着存储在entry中的信息和lsu返回的数据一起返回，其中twu_idx和lvl用于mbuf返回的时候，通过twu_idx索引到对应的twu，通过lvl定位到要进入哪一级的chk流水线。如果没有准备好，会将lsu的返回的数据更新进寄存器中，并且拉高get信号，表示已经拿到了lsu的数据，等待twu的chk准备好时，才拉高返回请求，等待授权，成功返回数据后都会释放掉该entry。如果lsu返回总线错误信号，那么会发出更新mbuf中访问异常寄存器的请求，拿到授权后会携带type和id更新进访问异常寄存器，同时释放掉该entry，如果没即使拿到授权，会更新进entry中的lsu bus err flop寄存器，等待mbuf中访问异常寄存器准备好时发除更新mbuf中访问异常寄存器的请求。
    - 18.pmp类流水线的请求更新进mbuf中entry的方式：mbuf中仲裁器会先选择twu中哪个请求更新进entry中（因为可能会同时多个twu发请求），仲裁优先级：itlb>twu0>twu1>twu2>twu3,得到授权后会携带请求极其信息，挑选entry更新，挑选entry的方式是：itlb的请求一直都是更新进entry8，这是专门给itlb类型请求的entry（不必担心溢出，因为itlb类型的请求同一时间一直只有一个，这是因为ifu的发请求方式的组设式的），如果是load、store、pfu的请求，会更新进entry0~7，这个通过指针的方式决定更新进哪个entry，指针初始值是1，即更新进entry0，每次更新后指针左移一位，下一次有请求到来时，更新进entry1，以此类推。更新进entry中时会将请求携带的vpn、padder、type、id、twu_idx、lvl都更新进entry中，当该entry的请求发射并且拿到lsu返回的信号时，会携带entry中的vpn、type、id以及lsu的页表数据返回到相应位置（根据twu_idx和lvl）（twu_idx：可以标记该请求是哪个twu发送的，mbuf返回时可以返回到对应的twu；lvl:请求要拿到的页表数据的级数，可以根据该级数决定返回到哪一级chk类流水线）
    - 19.mbuf中entry的发请求到lsu的方式：只要有entry的vld拉高，并且其没有get和lsu bus err flop（还没拿到lsu的返回），那么就会拉高发给lsu的请求信号，选padder时优先选itlb，即entry8的padder，优先拉高entry8的on，其他entry0~7同样使用指针的方式，指针初始值为1，先发送entry0的padder，在拿到lsu的返回后，指针左移一位，切换到entry1的padder。注意：在发请求的途中，padder不会改变，只有在拿到lsu的返回信号时，需要切换请求的padder时，padder才会变化。
    - 20.异常上报只需附带type和id去定位哪个模块的请求触发的异常，并且释放L2TLB miss buffer的entry，因为发生异常也认为是请求完成了。正常refill不仅得附带type和id去定位模块，还得携带refill的内容，refill给L2TLB需要完整的tag和data，refill给L1TLB则只需要vpn、page size和ppn、flg（除G位，refill 的flg包含5个扩展位：so、c、b、sh、sec，和2bit的rsw，以及riscv标准属性：D\A\U\X\W\R\V(我这里写的也是他们在refill的flg中的顺序)）。不需要asid是因为satp的值改变时会情况整个L1TLB，这种情况下更是不需要G位。
  


以下为各种情况下的流水线或状态机处理：（重要部分）
  1.以下为一个最终得到4k页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入thd_pmp流水线；T2n+8时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2n+8时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T3n+8时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T3n+9时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T3n+10时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》thd_pmp-》mbuf-》thd_chk-》refill）
  2.以下为一个最终得到2M页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T2n+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》refill）
   3.以下为一个最终得到1G页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》refill）
   4.以下为一个最总得到2M页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至2M）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查阶段，将1G块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为2M，并且ppn改变。Tn+6时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，不会触发跨页，则检查结束，page size和ppn也不会再次改变了。Tn+7时，状态机进入数据有效状态，发出跨页的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。
   5.以下为一个最总得到4K页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至4K）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为4K，并且ppn改变。Tn+6时，状态机进入数据有效状态，发出跨页的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+7时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。
   6.以下为一个最总得到1G页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至4K）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查阶段，将1G块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为2M，并且ppn改变。Tn+6时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为4K，并且ppn改变。Tn+7时，状态机进入数据有效状态，发出跨页的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。
   7.以下为一个在fst_chk流水线触发页表异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有页表异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表，但是同时也触发了页表异常，这时候会发请求更新到页表异常寄存器，Tn+5时，更新进页表异常寄存器，页表异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，可能是itlb，如果是dtlb会精确到其buffer的哪个entry（根据type和id）同时会释放掉L2TLB中miss buffer的相应entry。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》上报）
   7.以下为一个在fst_pmp流水线触发访问异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有访问异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，这时候pmp检查未通过，触发了访问异常。T3时，更新进访问异常寄存器，访问异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，可能是itlb，如果是dtlb会精确到其buffer的哪个entry（根据type和id中的L1TLB部分），同时会释放掉L2TLB中miss buffer的相应entry（根据id中的L2TLB部分）。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》上报）
   8.以下为一个最终得到4k页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查但是maee未开启）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入thd_pmp流水线；T2n+8时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2n+8时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T3n+8时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T3n+9时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，并且因为这时候maee未开启，会将要refill的ppn更新进no_maee_ppn寄存器中，T3n+10时，no_maee_ppn寄存器中的值会发给sysmap，当排sysmap返回该区域的扩展属性配置，refill寄存器的请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB，但是refill回去的flg的扩展属性部分会用sysmap返回该区域的扩展属性配置，而不是页表中的扩展属性配置。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》thd_pmp-》mbuf-》thd_chk-》refill）
   9.以下为一个最总得到1G页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查但是不降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查阶段，将1G块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，没触发跨页，page size不会降级，ppn也不会改变，Tn+6时，状态机进入数据有效状态，发出跨页检查的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。sysmap的配置用尾地址的sysmap的配置，但其实用首地址还是尾地址都无所谓，因为他们命中同一个区域，sysmap的配置也是一样的。
   10.以下为一个最总得到2M页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查但是未降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，不会触发跨页，page size不会降级，ppn不会改变。Tn+6时，状态机进入数据有效状态，发出跨页检查的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+7时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。sysmap的配置用尾地址的sysmap的配置，但其实用首地址还是尾地址都无所谓，因为他们命中同一个区域，sysmap的配置也是一样的。
   11.以下为一个第一级 PDE cache 命中后最终得到 2M 页的ptw请求处理的完整过程（第一级 PDE cache 命中）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时命中第一级 PDE cache，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，请求跳过fst，直接进入scd_pmp,进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；T3时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；Tn+4时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》scd_pmp-》mbuf-》scd_chk-》refill）
   12.以下为一个第一级 PDE cache 命中后最终得到 4K 页的ptw请求处理的完整过程（第一级 PDE cache 命中）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时命中第一级 PDE cache，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，请求跳过fst，直接进入scd_pmp,进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；T3时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；Tn+4时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到不是叶子页表。Tn+5时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T2n+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》scd_pmp-》mbuf-》scd_chk-》thd_pmp=》mbuf=》thd_chk=》refill）
   13.以下为一个PFU 请求成功 refill一个1G页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L2TLB，只回填到L2TLB，不会回填到L1TLB，根据type，因为不是fetch、load和store所以不会回填给L1TLB，id会索引到L2TLB中miss buffer的entry，释放掉该entry，因为请求已经成功完成，回填的内容中充当L2TLB的tag的是vpn、asid、page size和G位，充当data的是ppn、flg（除G位外的flg）。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》refill）
   14.以下为一个PFU 请求触发异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有页表异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到触发页表异常，这时候会发请求更新到页表异常寄存器，Tn+5时，更新进页表异常寄存器，页表异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，因为是pfu类型，不是fetch、load和store所以不会回填给L1TLB，会将异常上报到L2TLB，id会索引到L2TLB中miss buffer的entry，释放掉该entry，因为请求已经完成，后续L2TLB会把该异常上报到lsu的 pfu端口（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》异常上报）
## 待澄清问题

本节用于记录基于本 spec 审核和修改 UVM PTW 部分前需要明确的问题。后续回答这些问题后，应把答案补充回 spec 正文或本节对应条目下。

### 1. 基本架构与地址格式

1. 当前 PTW 是否只支持 Sv39、三级页表、4KB 基页？是否存在 Bare 模式、其他地址模式、或 satp.mode 非 Sv39 时 PTW 的预期行为？
答：当前ptw只支持Sv39，三级页表、4KB基页。存在bare模式和sv39地址模式。
2. 虚拟地址为 39 bit 时，输入到 PTW 的高位虚拟地址如果存在符号扩展或非 canonical 情况，应由 PTW 检查并报错，还是由 PTW 之前的模块保证不会出现？
答：输入到ptw的只有27bit的vpn，ptw输出ppn即可，offset部分是不会进入ptw的。不存在符号扩展或非 canonical 情况。所以是由 PTW 之前的模块保证不会出现。
3. 物理地址为 40 bit、PPN 为 28 bit 时，PTE 中 PPN 字段如果包含超出 40 bit 物理地址范围的信息，PTW 是否需要检查并触发页表异常？
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。PPN字段为28bit，所以不会出现超出 40 bit 物理地址范围的信息。
4. `regs_ptw_satp_ppn` 是否就是根页表物理页号？它在一次 walk 过程中如果发生变化，当前正在进行的请求使用旧值还是新值？
答：`regs_ptw_satp_ppn` 就是根页表物理页号。如果他在waclk过程中改变，通常是会有lsu发请求到tlboper，tlboper会发送abort信号到ptw，ptw执行中断信号处理。
5. spec 中 `vpn[2]`、`vpn[1]`、`vpn[0]` 的定义与 RISC-V Sv39 的 VPN[2:0] 是否完全一致？后续 UVM reference model 是否可以直接按 Sv39 语义建模？
答：spec 中 `vpn[2]`、`vpn[1]`、`vpn[0]` 的定义与 RISC-V Sv39 的 VPN[2:0] 完全一致。可以。

### 2. 请求输入与返回接口

6. L2TLB 发给 PTW 的请求字段完整包括哪些内容？除 vpn、type、id 之外，是否还有 ASID、VMID、privilege、access type、MXR/SUM/MPRV 等会影响检查或 refill 的字段？
答：L2TLB 发给 PTW 的请求字段完整包括vpn、type（PFU（arb_pfu_grant）固定为 3'b100；IUTLB（arb_iutlb_grant）为 3'b011；Load（arb_load_grant）为 3'b010；Store（arb_store_grant）为 3'b110）、id（l2tlb_ptw_id 是 mmu_l2tlb_mb 里 issue_eid 原样传出 的 6 bit 复合 ID，RTL 里固定拼成 {L2 段, L1 段}：高 3 bit [5:3] 表示 L2TLB Miss Buffer 槽位（新分配时是 dtlb_alloc_index，从缓冲就绪条目发出时是 entry_rdy_id），低 3 bit [2:0] 表示 L1 DTLB Miss Buffer 的 entry 编号（req_l1eid / entry_rdy_eid）；PTW 带着这 6 bit 走路，回填时再按同样划分把 L2 段对回本侧 MB、L1 段回到 L1 DTLB 对应 miss 项。）
7. `type` 的枚举值和含义是什么？它如何区分 itlb、dtlb load、dtlb store、dtlb atomic、或其他请求类型？
答：type（PFU（lsu端口2的预取端口）（arb_pfu_grant）固定为 3'b100；IUTLB（arb_iutlb_grant）为 3'b011；Load（arb_load_grant）为 3'b010；Store（arb_store_grant）为 3'b110）
8. L1DTLB mbuf 的 `id` 宽度、合法范围、复用规则是什么？同一个 id 是否可能在旧请求完成前被新请求复用？
答：id（l2tlb_ptw_id 是 mmu_l2tlb_mb 里 issue_eid 原样传出 的 6 bit 复合 ID，RTL 里固定拼成 {L2 段, L1 段}：高 3 bit [5:3] 表示 L2TLB Miss Buffer 槽位（新分配时是 dtlb_alloc_index，从缓冲就绪条目发出时是 entry_rdy_id），低 3 bit [2:0] 表示 L1 DTLB Miss Buffer 的 entry 编号（req_l1eid / entry_rdy_eid）；PTW 带着这 6 bit 走路，回填时再按同样划分把 L2 段对回本侧 MB、L1 段回到 L1 DTLB 对应 miss 项。）同一个 id 不可能在旧请求完成前被新请求复用。
9.  返回到 L1ITLB、L1DTLB、L2TLB 的正常 refill 字段完整包括哪些内容？例如 ppn、page size、权限位、属性位、异常位、id、type 是否都返回？
答：返回到 L1ITLB、L1DTLB、L2TLB 的正常 refill 字段完整包括ppn、flg、page size、vpn、asid（直接用当前进程的aisd，在satp寄存器存储着的asid）、global位、type、id。
10.  当访问异常、页表异常、正常 refill 对同一个原始请求同时或相邻周期产生时，最终只允许返回一种结果吗？优先级是否固定为访问异常高于页表异常高于正常 refill？
答：当访问异常、页表异常、正常 refill同时需要返回时，最终只允许返回一种结果。优先级固定为访问异常高于页表异常高于正常 refill。

### 3. PDE cache 行为

11. 第一级和第二级 PDE cache 的 entry 格式完整包含哪些字段？除了 valid、tag、ppn 之外，是否包含 ASID、global、权限、内存属性、替换信息？
答：不包含ASID、global、权限、内存属性。因为asid改变时pde cache会清空，这样就隐含了同一个asid的意思。替换信息每一级pde cache 有自己独立的plru算法模块来处理其替换。
12. PDE cache 是否按 ASID 或 satp 上下文隔离？如果 tag 只包含 vpn，切换地址空间时依靠什么机制避免旧 PDE cache 命中？
答：因为asid改变时pde cache会清空，这样就隐含了同一个asid的意思。
13. PDE cache 的替换策略是什么？16 个 entry 是全相联、直接映射还是组相联？命中和更新的仲裁规则是什么？
答：PDE cache 的替换策略是plru。16 个 entry是全相联，用寄存器堆搭建的。命中是用L2发来的请求附带的vpn对应部分跟pde cache的tag比较，如果相同则认为命中。（第一级pde cache用vpn[2]跟tag比较，第二级pde cache用vpn[2：1]跟tag比较）.没有仲裁规则，因为一个时钟周期最多接受一个L2tlb的请求，如果停滞了会不接受L2tlb的请求，这样不可能同时出现多个请求在查找pde cache，不需要仲裁。
14. 第一级 PDE cache 的 data 是哪一级非叶子 PTE 的 PPN？第二级 PDE cache 的 data 是哪一级非叶子 PTE 的 PPN？请明确 data 用于生成哪一级页表访问地址。
答：第一级 PDE cache 的 data 是第一级非叶子 PTE 的 PPN。第二级 PDE cache 的 data 是第二级非叶子 PTE 的 PPN。data都是用于生成下一级的页表访问地址。第一级 PDE cache 的 data用于生成第二级的页表访问地址。第二级 PDE cache 的 data用于生成第三级的页表访问地址。
15. 两级 PDE cache 同时命中时，选择第二级 PDE cache；这种情况下是否还需要校验第一级 PDE cache 与第二级 PDE cache 的一致性？
答：不需要。第二级 PDE cache更接着叶子页表。
16. PDE cache 命中后跳过对应 PMP 和 CHK 流水线。被跳过的非叶子 PTE 权限和合法性检查是否完全依赖当初填入 PDE cache 时已经完成？
答：是，更新进pde cache的页表都是通过pmp检查和页表异常检查的，只有通过了才可能会更新入pde cache中，所以cache中数据的时候不需要检查。
17. PDE cache 更新条件写为“不是叶子表项并且不会触发页表异常”。是否还要求该次访问没有访问异常、没有 abort、没有 flush、且对应上下文仍有效？
答：要求该次访问拿到的页表数据没有触发页表异常并且不是叶子表项，并且未被 abort/flush 屏蔽即可。satp/PMP 配置改变只清空 PDE cache、不 abort in-flight walk 时，不额外禁止旧 in-flight walk 返回后更新 PDE cache。
18. 当 `tlboper_ptw_abort` 或其他 TLB 维护操作发生时，PDE cache 是全清空还是只屏蔽当前请求？是否存在按 VA/ASID 精确失效 PDE cache 的行为？
答：PDE cache 全部清空，并清空ptw的所有请求，等到可以继续接受请求时，让L2重新所有请求。不存在按 VA/ASID 精确失效 PDE cache 的行为。清空全部 PDE cache + flush in-flight PTW 请求。

### 4. TWU 选择与 ready/backpressure

19. xbar_one_to_four 的 hash 函数具体是什么？UVM scoreboard 是否需要精确预测请求进入哪个 TWU，还是只需验证功能结果？
答：ash 函数具体是
assign twu_hash[1:0] =
    PDE_xbar_vpn[1:0]   ^
    PDE_xbar_vpn[10:9]  ^
    PDE_xbar_vpn[19:18] ^
    PDE_xbar_vpn[26:25];
  UVM scoreboard 需要精确预测请求进入哪个 TWU。
20. 当目标 TWU 无法接受请求导致 PTW ready 拉低时，L2TLB 需要保持请求字段稳定吗？是否存在 valid/ready 握手语义？
答：存在valid/ready 握手语义，PTW ready 拉低时，L2tlb认为该请求未被ptw接受，所以会继续拉高该请求。
21. 如果多个 L2TLB 请求连续到达，PTW 每周期最多接受一个请求，还是 itlb/dtlb 可并行进入？
答：PTW 每周期最多接受一个请求。由L2TLB发请求。
22. TWU “每个时钟周期都可以接受一个请求”的前提条件完整是什么？是否只受第一级 pmp/chk 路径状态影响，还是也受 mbuf、异常寄存器、refill 寄存器影响？
答：TWU “每个时钟周期都可以接受一个请求”的前提条件完整是当前在pde cache的请求要进过one_to_four_xbar.sv模块分发到某个twu，如果该twu可以接受新请求，则可以让L2tlb的新请求进入ptw。twu不能接受请求的情况上面已经提到。

### 5. PMP 检查与访问异常

23. PMP 检查的输入物理地址是否为页表项所在地址，而不是最终翻译出的物理地址？三层 PMP 检查都只检查读取页表内存的权限吗？
答：PMP 检查的是页表项所在物理地址地址的ppn部分，会精确到一个4k块，不是最终翻译出的物理地址。三层 PMP 检查都只检查读取页表内存的权限。
24.  PMP 返回的 `flg` 每一位含义是什么？针对 itlb、dtlb load、dtlb store 等请求，访问异常判定条件分别是什么？
答：assign fst_pmp_deny = (fst_pmp_fetch_type && !pmp_mmu_flg[2]
                    || fst_pmp_load_type  && !pmp_mmu_flg[0]
                    || fst_pmp_store_type && !pmp_mmu_flg[1]
                    || fst_pmp_pref_type  && !pmp_mmu_flg[0])
                    // L-bit for M-Mode
                       && !(fst_pmp_cp0_mach_mode && !pmp_mmu_flg[3]);
    以此为例，相应type对应的flg拉低，则未通过pmp检查。还有一个特殊情况pmp_mmu_flg[3]，如果机器模式下没有 L-bit for M-Mode可以跳过pmp检查。
25.  页表 walk 读取 PTE 时使用的 PMP 访问类型是 load、fetch、还是与原始请求类型相关？
答：与原始请求类型相关。
26.  PMP 检查未通过和 LSU 总线错误都归类为访问异常。两者返回给 TLB 的错误编码是否相同？UVM 是否需要区分来源？
答：两者返回给 TLB 的错误编码都是访问异常。异常附带的id不是错误编码，只是返回时L1TLB和L2TLB的miss buffer的该请求entry位置。
27.  如果某一级 PMP 已触发访问异常，该请求后续是否立即停止，不再发 mbuf/lsu 请求，也不再可能产生页表异常？
答：发生访问异常该请求结束并且会上报这个异常给tlb，tlb会上报该异常到上游，最总由软件处理。
28.  多个 PMP 流水线同时请求 PMP 仲裁时，spec 写“itlb 优先 > 高等级页表 > 低等级页表”。“高等级页表”是指第一级页表优先，还是更接近叶子的第三级页表优先？
答：高等级页表是指第三级页表优先。

### 6. PTE 检查与页表异常

29. CHK 流水线执行的页表异常检查规则完整是什么？是否严格遵循 RISC-V Sv39 PTE 的 V/R/W/X/U/G/A/D/RSW/PPN 保留位规则？
答：最终按本设计 RTL/文字规则建模，不额外套用标准 Sv39 的保留位、RSW、strong-order 检查。叶子 PTE 的 page fault 规则以第 94/95/96/131/132/133 题为准；非叶子 PTE 只在 `V=0`、write-only 规则命中、或第三级仍为非叶子 PTE 时触发 page fault，除此之外 U/G/A/D/RSW/高位保留位/扩展属性都不检查。
30. 叶子 PTE 的判定规则是否为 R/X/W 任一可用即叶子，还是存在本设计特有规则？
答：叶子 PTE 的判定规则是R/X 任一可用即叶子，并且vld有效。
31. 非叶子 PTE 中如果 D/A/U/W/R/X 等权限位存在非法组合，应触发页表异常还是忽略？
答：触发页表异常。但 非叶子 PTE和叶子页表的页表异常检查不太一致，有些只有在叶子页表的时候才触发的页表异常。非叶子 PTE只有在只可写情况下或者在第三级页表还被判断是非叶子 PTE时才触发页表异常。
32. megapage/superpage 对齐检查规则是什么？例如 1G 页要求 PPN[1:0] 为 0，2M 页要求 PPN[0] 为 0；如果不对齐是否页表异常？
答：这个应该是页表1结构在分配的时候久已经对齐了，ptw在读过来的时候页一定是对齐的，没做这个的检查。
33. A/D 位如何处理？硬件是否会自动置位 A/D，还是 A/D 不满足时直接页表异常？
答：硬件不会自动置位 A/D，A/D 不满足时直接页表异常。
34. MXR、SUM、当前特权级、MPRV 等状态是否参与叶子 PTE 权限检查？如果参与，相关输入信号在哪里定义？
答：参与。这些相关输入信号是由cp0模块输入进mmu的。
35. instruction page fault、load page fault、store page fault 是否根据请求 type 分别返回？当前 spec 只写“页表异常”，是否需要区分具体异常类型？
答：是。会根据触发异常的请求类型，将异常上报到相应模块，比如itlb类型的异常上报给itlb，load和store上报给dtlb。不区别具体异常类型，页表异常不区分是哪一种具体的异常。
36. 第三级 `thd_chk` 中“该请求必定是叶子表项”的说法是否表示第三级非叶子 PTE 必定触发页表异常？
答：是。如果在第三级chk还被判断是非叶子pte，那么必定触发页表异常。

### 7. Mbuf 与 LSU 交互

37. mbuf 的 9 个 entry 中，8 个 DTLB entry 和 1 个 ITLB entry 的分配规则是什么？DTLB entry 如何选择空闲项或处理满的情况？
答：原始来源是lsu的会进入8 个 DTLB entry，原始来源是ifu的会进入1 个 ITLB entry（因为ifu是阻塞式结构，同一时间只可能有一个ifu请求在mmu处理）。DTLB entry 是通过指针的方式更新入8 个 DTLB entry，新请求更新进entry中，指针久左移一位。不可能出现溢出的情况，因为L2TLB的miss buffer也是8个entry给dtlb的，最多只有8个dtlb请求进入ptw。所以mbuf只可能填满，不可能溢出，不需要处理溢出的情况。
38. 当 itlb 和 dtlb 请求同时竞争 mbuf 写入时，是否一定 itlb 优先？如果 itlb 专用 entry 已满，新的 itlb 请求如何 backpressure？
答：是一定 itlb 优先。因为ifu是阻塞式结构，同一时间只可能有一个ifu请求在mmu处理。所以itlb专用 entry 已满时，不可能有新的 itlb 请求。
39. mbuf 向 LSU 发请求时，itlb 请求优先；如果 itlb 请求持续存在，dtlb 是否可能饥饿？是否有公平性或轮转机制？
答：itlb 请求不可能持续存在。因为ifu是阻塞式结构，同一时间只可能有一个ifu请求在mmu处理。所以总有其处理好的时候
40. LSU 接口没有 grant/ready，PTW 请求 valid 拉高直到 LSU data valid 返回。若 LSU 返回错误或数据无效周期，mbuf 如何匹配返回到具体 entry？
答：mbuf将entry中的请求发给lsu的那一时刻就会标记该entry的请求在lsu中处理，lsu返回的时候就返回到该entry。因为lsu是串行执行的，同一时间只可能处理一个请求，只有该请求处理完成才能发出下一个请求。
41. `mbuf_on` 的精确定义是什么？它如何跟踪当前正在 LSU 中处理的 entry？
答：mbuf将entry中的请求发给lsu的那一时刻就会标记该entry的请求在lsu中处理，即mbuf_on拉高。其拉高说明该entry的请求正在 LSU 中处理。lsu返回时也是根据该信号跟踪到该entry。
42. LSU 是否保证按请求顺序返回？是否允许多 outstanding？当前 spec 似乎描述为串行单 outstanding，请确认。
答：不允许多 outstanding。lsu是串行执行的，同一时间只可能处理一个请求，只有该请求处理完成才能发出下一个请求。是串行单 outstanding。
43. LSU 返回的数据宽度、PTE 对齐、端序、以及从返回数据中取 PTE 的规则是什么？
答：lsu返回的数据位宽是64bit，就是页表数据，全部64bit都是页表数据，不需要抽取。
44. 当 LSU 返回数据但目标 CHK 流水线不 ready，mbuf 将数据寄存在 entry 中。此 entry 在等待期间是否阻塞后续 LSU 请求发出？
答：此 entry 在等待期间不阻塞后续 LSU 请求发出。

### 8. 跨页属性检查与降级

45. `maee` 的完整含义是什么？它打开时“直接使用页表数据中的属性”具体使用 PTE 的哪些属性位？
答：MAEE 表示处理器支持一种 「页表项里携带寻址/内存类型相关属性」 的机制——即在 PTE 的高位（你们图里的 So、C、B 等）编码 强序、可缓存、可缓冲 等 内存属性，MMU 在地址翻译时可用这些位决定访问语义；是否启用由 sxstatus（或同类控制寄存器）里的 MAEE 控制位（文档里常见为 bit 21）决定。它打开时“直接使用页表数据中的属性”具体使用pte的最高几位为扩展属性（依次为 So、C、B、Sh、Sec）
46. `maee` 关闭时，8 个内存区域默认属性由哪个模块或寄存器提供？属性字段有哪些？
答：在这套 RTL 里，maee（cp0_mmu_maee）关掉时，不走页表里扩展 PMA（PTE 高位），而是由 ct_mmu_sysmap + sysmap.h 里写死的 8 段物理地址区间与默认属性 提供：根据当前访问的物理地址落在哪一段（用 SYSMAP_BASE_ADDR0～SYSMAP_BASE_ADDR7 做区间比较、再 casez 选中 SYSMAP_FLG0～SYSMAP_FLG7），组合出 sysmap_mmu_flg（5 位） 和 8 路 one-hot 的 sysmap_mmu_hit；这些宏不是 CSR 运行时寄存器，而是 编译期参数（头文件里定义）。这 5 位与 MEL/jTLB 里 PMA 域同一套路，对应 Sec（安全敏感）、Sh（可共享）、B（可缓冲）、C（可缓存）、So（强序/设备序） 等存储属性，用来在 MMU off / MAEE 关闭 时决定 非分页路径或 PTW refill 里填充到 jTLB 的 PMA 片段（例如 ct_mmu_ptw.v 里 ptw_ref_pma 在 !cp0_mmu_maee 时取 sysmap_mmu_flg3[4:0]），从而约束 可缓存性、顺序、共享与安全性 等与 LSU/总线、cache、一致性相关的行为，而不是从本次 walk 读回的 PTE 扩展域取数。
47. “1G 或 2M 页表可能跨越 8 个区域边界”的边界检查，是检查最终物理页覆盖范围 `[base, end]` 是否落在同一个 sysmap 区域吗？
答：是。
48. 1G 页跨页检查时，首地址和尾地址如何计算？尾地址是页内最后一个 byte 地址，还是下一页起始地址减 1？
答：首地址是用1G页表的ppn[2]和全是0的ppn[1:0]，也就是1G块中的第一个4K块。尾地址是用1G页表的ppn[2]和全是1的ppn[1:0]，也就是1G块中的最后一个4K块。offset部分不考虑，因为内存地址划分的时候就是按4k为最小块的。
49. 1G 降级为 2M 时“ppn[1] 套用 vpn[1]”的精确计算公式是什么？是否表示最终 PPN = `{pte.ppn[2], vpn[1], pte.ppn[0]}` 或其他组合？
答：按道理来说1G页表的ppn[1]是全0，因为物理地址对齐，套用vpn[1]，则ppn[1]有数值了，物理地址变成2M对齐了。是表示最终 PPN = `{pte.ppn[2], vpn[1], pte.ppn[0]}`
50. 2M 降级为 4K 时“ppn[0] 套用 vpn[0]”的精确计算公式是什么？
答：按道理来说2M页表的ppn[0]是全0，因为物理地址对齐，套用vpn[0]，则ppn[0]有数值了，物理地址变成4K对齐了。是表示最终 PPN = `{pte.ppn[2], pte.ppn[1],vpn[0]}`.
51.  降级后的 2M 或 4K refill 使用的权限、属性、A/D/G/U 等字段来自原始大页叶子 PTE，还是需要重新访问下一级页表？
答：来自原始大页叶子 PTE。
52.  如果 1G 页跨区域后降级到 2M，2M 仍跨区域再降级到 4K，这整个过程是否不再访问内存，只在当前叶子 PTE 基础上改写 PPN 和 page size？
答：不再访问内存。只在当前叶子 PTE 基础上改写 PPN 和 page size。
53.  如果降级后的 4K 仍然跨 sysmap 区域边界，理论上不会发生；如果 sysmap 配置异常导致发生，应如何处理？
答：4K不可能跨越 sysmap 区域边界，因为划分的时候最小块就是4k。不考虑sysmap 配置异常的问题。硬件不考虑，这个因为是软件的处理。
54.  跨页检查状态机与正常 refill 仲裁失败时如何保持请求？是否可能被 abort 屏蔽？
答：因为refill是会更新到twu中的refill寄存器的，会寄存请求和需要refill的数据。只有refill请求被授权了，真正被refill了才会拉低寄存器的有效位。

### 9. 异常寄存器、refill 寄存器与仲裁

55. 每个 TWU 的页表异常寄存器、访问异常寄存器、正常 refill 寄存器各有几项？如果已有有效请求未被顶层仲裁接受，新异常或 refill 到来时如何 backpressure？
答:各有一组寄存器。会阻塞该流水线，拉高等待信号，直到被更新入寄存器。比如chk发refill请求，如果未更新入寄存器，会拉高该流水线的wait信号。
56. 顶层对 4 个 TWU 的异常和 refill 仲裁规则中，itlb 优先和 TWU index 低优先如何同时应用？是先按 itlb/dtlb 分类再按 TWU index，还是每个请求有统一优先级编码？
答：先按 itlb/dtlb 分类再按 TWU index，不过是同一个时钟周期完成的，在有itlb时，选择该请求上报，如果没有itlb，则按TWU index。
57. 访问异常写回、页表异常写回、正常 refill 写回三者的顶层优先级为访问异常 > 页表异常 > 正常 refill。若低优先级请求长期被高优先级请求压制，是否有防饥饿机制？
答：不太可能，因为写回只需要一个时钟周期，而请求处理需要多个时钟周期，而且最多只有9个请求在ptw中（L2TLB miss buffer的entry数量限制）。
58. 异常上报是否也需要返回原始 id 和 type？对 itlb 请求没有 L1DTLB mbuf id 时 id 字段如何处理？
答：异常上报也需要返回原始 id 和 type。对 itlb 请求没有 L1DTLB mbuf id 时 id 字段的L1TLB部分不会被使用。虽然会返回，但是不会使用。其中id字段的L2TLB部分会去释放掉L2TLB中miss buffer的相应entry。
59. `tlboper_ptw_abort` 期间“回填请求被屏蔽，但是异常上报请求不会”。这里异常上报包括 abort 前已经形成的异常寄存器，还是 abort 期间新形成的 LSU bus error 也会上报？
答：只有abort到来的那一个时钟周期，正在上报的异常才可以上报。如果twu0和twu1都出现访问异常，仲裁器给twu0授权，这时候来了abort，正在上报的twu0的异常可以上报，但是twu1的异常因为没被授权，会被冲刷掉。等L2TLB重新发这个请求然后触发异常后再上报。

### 10. Abort/Flush/一致性语义

60. `tlboper_ptw_abort` 的有效周期和握手语义是什么？它是单周期脉冲还是保持到 PTW 完成 flush？
答：tlboper_ptw_abort就是lsu发来tlboper请求的那一个时钟周期，是单周期脉冲。
61. abort 发生时，已经在 pmp/chk 流水线、mbuf entry、PDE cache lookup、refill 寄存器中的请求分别如何处理？请明确哪些清 valid，哪些只是屏蔽输出。
答：全部清 valid。
62. abort 发生时，如果 LSU 中已有未完成请求，spec 要求保持 LSU 请求拉高直到返回。返回后该数据是否必须丢弃且不能更新 PDE cache、不能进入 CHK、不能产生 refill？
答：是的，返回后该数据是否必须丢弃且不能更新 PDE cache、不能进入 CHK、不能产生 refill。
63. abort 期间异常上报不屏蔽。若 abort 的目标是维护 TLB 一致性，为什么异常仍需上报？这是架构要求还是为了避免请求源挂起？
答：可以从两层分开看，不必把「TLB 一致性 abort」和「异常是否上报」绑成一件事。
语义上（偏架构）：tlboper_ptw_abort 在做的事是：本次 miss 的 refill 不能再当成合法映射写进 TLB。它并不否定页表遍历过程中已经暴露出来的事实：例如 PTE 访存总线出错、PMP 拒绝、页表项非法导致的 page fault 等。这些属于「这次访问在架构上该不该完成、不能完成又该怎么告知软件」的问题。RISC‑V 这类模型里，缺页 / 访问错应对 faulting 指令保持精确、可见；若仅仅因为发生了 shootdown 就把 walk 里已经发现的 fault 吞掉，会变成「指令既不完成也不异常」，与特权规范里的精确异常语义不一致。
实现与活性（偏避免挂死）：发起 PTW 的那条 load/store/取指仍在等 miss 路径收尾：要么 refill 成功（此处可被 abort 屏蔽），要么 报 access fault / page fault，要么至少要有确定的 refill 完成/故障完成 握手。也就是说 挡住的是「带数据的合法 refill」，不是「故障完成」。若故障也被屏蔽，请求源可能长期得不到 异常注入或明确完成，从系统角度更容易出现 逻辑挂起或不可诊断状态。
一句话：abort 针对的是 「失效窗口里别装进过时翻译」；**异常上报针对的是 「这次页表访问本身是否合法、能否完成」，二者正交。既有 架构上精确异常 的要求，也有 miss 路径必须收尾、避免请求挂死 的工程动机；在本设计中体现为 只屏蔽成功 refill 数据有效，而不笼统屏蔽 fault 完成路径。
64.  abort 完成、PTW ready 重新拉高后，L2TLB buffer 会重新发送所有请求。PTW 如何保证旧请求不会和重发请求重复返回？
答：abort之后，现有ptw不会有任何请求可以返回（如果abort同一时钟周期有异常返回，那么会让L2 的buffer中该请求所在的entry完成，这样该请求就不会再次发送了），因此重发请求不会是第二次返回。
65.  除 `tlboper_ptw_abort` 外，是否还有 reset、sfence、satp 写入、TLB invalidate 等其他 flush/abort 来源？
答：没有。

### 11. 时序、流水线与验证边界

66. 文中的 T0/T1/T2 示例是否是固定流水级时序，还是只表达逻辑顺序？UVM scoreboard 是否需要 cycle-accurate 检查？
答：是4k页表再pde cahce没命中的时序，不过T0和T1是每个请求都要经历的，都会再T0请求信号拉高，然后T1查看pde cache。
67. pde cache lookup、xbar 分发、进入 fst_pmp 是三个连续周期还是可能同周期组合完成？
答：三个连续周期。
68. PMP 返回 `flg` 是组合返回还是下一周期返回？PMP 仲裁失败时流水线 valid/data 如何保持？
答：组合返回。如果有请求没拿到pmp仲裁的授权会拉高wait信号，让该请求在流水线中保留。
69. mbuf 写入 entry 和向 LSU 发出请求是否可能同周期完成？
答：比如T0拉高写入entry的updata信号，T1完成写入，然后T1可以向lsu发请求了。因此应该可以认为是的。
70.  CHK 流水线从 mbuf 接收 LSU 数据后，页表异常检查、叶子判断、发往下一级 PMP 或 refill 是否固定一周期完成？
答：一个时钟周期完成
71.  对于 UVM reference model，哪些行为必须精确到周期，哪些只需要事务级功能正确？
答：你执行判断清楚，后续让我审查。

### 12. 文档一致性与术语

72. 文档中 “pde cahe/cache”、“第二季/第二级”、“进过/经过”、“最总/最终”、“chkk/chk”、“abriter/arbiter”等术语是否需要统一，以便后续 AI 审核时减少误解？
答：需要统一，是我打错了。
73. 第 11 节内部编号最后一项写成“6.scd_chk_wait”，但描述内容是 `thd_chk`，是否应改为 `thd_chk_wait`？
答：是。
74. 第 10 节和第 11 节的列表缩进混杂，哪些条目属于“twu 屏蔽 xbar 请求”，哪些属于“twu 内部流水线停滞”，是否需要重排？
答：已经重排。
75. `fst/scd/thd` 分别对应第一级、第二级、第三级页表；“高等级页表/低等级页表”在仲裁语境中建议明确为 `fst/scd/thd` 优先级，是否同意？
答：同意
76. 后续作为 UVM 审核依据时，是否希望本 spec 增加一张“输入字段、输出字段、内部状态、异常类型、优先级”的表格，作为 scoreboard/reference model 的检查清单？
答：是。

## 第二轮待澄清问题

本轮问题基于已补充的答案和完整流程继续整理，重点是把 spec 收敛成后续可执行的 UVM reference model/scoreboard 规则。

### 13. 模式、上下文采样与全局状态

77. 前文回答“当前 PTW 只支持 Sv39”，同时又说“存在 bare 模式和 sv39 地址模式”。bare 模式下是否保证不会向 PTW 发起 walk 请求？如果 bare 模式下仍有请求进入 PTW，预期行为是丢弃、直接返回、报错，还是由上游保证不发生？
答：bare 模式下保证不会向 PTW 发起 walk 请求。由上游保证不发生。因为这时候的ppn就等于vpn。相当于是mmu不开启。
78. `regs_ptw_satp_ppn`、satp.asid、MXR、SUM、当前特权级、MPRV、MAEE 等 CP0/CSR 状态是在请求被 PTW accept 的周期采样并随请求携带，还是在各级 PMP/CHK/refill 使用时读取当前值？
答：这些状态都是直接连接到ptw模块的，ptw时时接收，但只有在像PMP/CHK/refill 才会使用。
79. 如果一次 walk 过程中 satp.ppn 改变但 ASID 不变，是否一定会产生 `tlboper_ptw_abort`？如果没有 abort，当前 walk 和 PDE cache 应按旧 satp.ppn 还是新 satp.ppn 行为？
答：一次 walk 途中如果只改 SATP 里的 PPN、ASID 不变，并不会因此必然产生 tlboper_ptw_abort，因为在这条实现里 abort 只跟 LSU 上来的 TLB shootdown（tlb_lsu_oper / lsu_mmu_tlb_*_inv）有关，CSR 写 SATP 并不驱动这条路径；有没有 abort 完全取决于这段时间里是否另外来了 coherence 之类的 invalidate。若没有 abort，PTW 也不会在硬件里替你“锁定 walk 开始时的那根指针”：ptw_fst_addr 组合用的是当前的 regs_ptw_satp_ppn，所以一旦 SATP 寄存器已经写成新根页号，之后凡是再走第一级页表地址公式（例如重新从根读）都会按新 PPN；而已经发往 LSU、尚未返回的根级访问仍然对着当初锁在 ptw_req_addr 上的旧物理地址，返回前后可能与已经更新的 SATP 语义交错；第二、三级地址主要来自上一级 PTE 里的 PPN，跟根指针无直接关系。硬件上可能发生；软件上若要正确，通常就用 SFENCE（及相关失效）把它收紧掉，而不是依赖「改 SATP 但不 fence」这种交叉。
80. 如果一次 walk 过程中 MXR/SUM/privilege/MPRV/MAEE 变化，PTW 是否会被 abort/flush？若不会，reference model 应按请求进入时的状态还是检查发生时的状态判断权限和属性？
答：不会。reference model 应按检查发生时的状态判断权限和属性。

### 14. 请求类型、PFU 与返回目标

81. PFU 类型 `3'b100` 的语义需要进一步明确：PFU walk 成功后会 refill 哪些结构？只 refill L2TLB，还是也可能 refill L1DTLB/L1ITLB？
答：只 refill L2TLB。
82. PFU 类型如果在 PMP 或 PTE 检查中触发访问异常/页表异常，是否会上报异常？还是作为预取请求静默丢弃并不产生架构可见异常？
答：会上报异常。
83. type 目前列出 PFU/IUTLB/Load/Store 四类。是否存在 atomic/amo 请求类型？如果没有，store 类型是否同时覆盖普通 store 和 atomic 的 D 位/PMP store 权限检查？
答：不存在 atomic/amo 请求类型。store 类型同时覆盖普通 store 和 atomic 的 D 位/PMP store 权限检查。
84. 对 IUTLB 请求，返回接口中的 `id` 字段虽然不会被使用，但其值是否有固定来源或固定填充值？scoreboard 是否应忽略 IUTLB 返回的 id？
答：固定为0.scoreboard 应忽略 IUTLB 返回的 id。
85. 正常 refill 字段中的 `flg` 具体位定义是什么？它是否同时包含 R/W/X/U/G/A/D、PMA 属性、strong order、cacheable、bufferable 等信息，还是这些字段分开返回？
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。refill `flg` 包含最高几位扩展属性、RSW、以及标准权限与状态位 D、A、U、X、W、R、V；G 位不进入 data `flg`，而是放在 tag/global 中。内部 `ptw_flg` 去掉 G 后才出现 `ptw_flg[5]=A`、`ptw_flg[6]=D`。
86.  `page size` 的输出编码是什么？例如 1G/2M/4K 分别用几 bit、什么取值表示？
答：1G是3’100，2M是010，4K是001。
87.  正常 refill 中的 ASID 写为“直接用当前 satp 中的 ASID”。这里的“当前”是请求进入 PTW 时的 ASID，还是 refill 返回当拍的 ASID？
答：refill 返回当拍的 ASID。

### 15. PTE 位级规则

88. 请给出 PTE 64 bit 的完整位定义表，包括 V/R/W/X/U/G/A/D/RSW、PPN[2:0]、保留位、以及 MAEE 扩展属性 So/C/B/Sh/Sec 的精确 bit 范围。
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。
89.  第 29 题回答列出 “huge page misalign” 会触发 page fault，但第 32 题回答说硬件没做对齐检查。请确认 1G 页 PPN[1:0] 非 0、2M 页 PPN[0] 非 0 时，PTW 是否实际触发页表异常？
答：会触发页表异常。32题的回答错误。在页表异常检查的时候会检查1G 页 PPN[1:0] 是否为 0、2M 页 PPN[0] 是否为 0 ，如果不是，则会触发页表异常。
90.  PTE 高位保留位非 0 时是否触发页表异常？MAEE 开启和关闭时，扩展属性位之外的保留位处理是否一致？
答：PTE 高位保留位必定为0，不做这方面的检查。一致。
91.  MAEE 关闭时，PTE 中 So/C/B/Sh/Sec 扩展属性位如果非 0，PTW 是忽略这些位、触发页表异常，还是仍保留到 refill 中但 PMA 使用 sysmap？
答：忽略这些位。
92.   “PTE write only” 的精确定义是否为 `W=1 && R=0`，不管 X 是 0 还是 1 都触发页表异常？
答：                     !(ptw_flg[1] || cp0_mmu_mxr && ptw_flg[3]) 
                        && ptw_flg[2]         // write only
      如果mxr拉高并且X是1，那么可以跳过只读的检查，否则W=1 && R=0就会触发页表异常。
93.非叶子 PTE 的合法性需要精确化：除 `V=1 && R=0 && W=0 && X=0` 之外，U/G/A/D/RSW/PPN/扩展属性哪些位会被检查，哪些位会被忽略？
答：只需检查只读情况，如上个问题所述。还需检查vld为低，如果页表vld为低也会触发页表异常。还需检查第三级页表，如果第三级页表的数据检查出是非叶子pte，也会触发页表异常。因为sv39中第三级页表已经是最后一级，正常情况下必定是叶子页表。
94.   叶子 PTE 权限检查请给出布尔规则：fetch/load/store/PFU 分别如何使用 R/W/X/U、MXR、SUM、privilege、MPRV、A/D、So 位决定 page fault？
答：assign ptw_page_flt = ((!ptw_flg[0]                       // not valid
                   ||  !(ptw_flg[1] || cp0_mmu_mxr && ptw_flg[3]) 
                        && ptw_flg[2]         // write only
                   ||  (!ptw_flg[1] && ptw_load_type     // match R
                       && !(cp0_mmu_mxr && ptw_flg[3])  
                   || !ptw_flg[2] && ptw_store_type     // match W
                   || !ptw_flg[3] && ptw_fetch_type     // match X
                   ||  ptw_flg[4] && cp0_supv_mode && !cp0_mmu_sum // S->U
                   || !ptw_flg[4] && cp0_user_mode      // U->S
                   || !ptw_flg[5]                       // A bit volation
                   || !ptw_flg[6] && ptw_store_type     // D bit volation
                   ||  ptw_hit_1g && lsu_data_flop[27:10] != 18'b0 // 1g align
                   ||  ptw_hit_2m && lsu_data_flop[18:10] != 9'b0  // 2m align
                     ) && ptw_leaf_vld)
                   || !ptw_flg[1] && !ptw_flg[3]        // thd req no R/X
                       && ptw_chk_thd);如上代码是完整的检查，部分哪一级流水线的检查。
95.    A/D 位规则是否为 fetch/load/PFU 要求 A=1，store 要求 A=1 且 D=1？IUTLB fetch 是否也要求 A=1？
答：fetch/load/PFU都要求A=1，store 要求 A=1 且 D=1。
96.    “fetch meets strong order” 触发 page fault 的规则需要明确：是 MAEE 开启时 PTE.So=1 且请求 type 为 IUTLB/fetch 触发，还是 MAEE 关闭时 sysmap.So=1 也会触发？
答：mmu中不做该检查，不需要考虑。（可能是ifu内部的检查）

### 16. PDE cache 精确行为

97. PDE cache 在 ASID 改变时会清空。请明确清空触发信号：是 satp.asid 改变、satp 任意字段改变、tlboper、reset，还是上游某个 flush 信号？
答：satp 任意字段改变。
98. `tlboper_ptw_abort` 发生时，PDE cache 是保持原有内容，只屏蔽当前 lookup/update 请求，对吗？如果页表内容被软件修改并通过 tlboper 失效 TLB，保留旧 PDE cache 是否是设计预期？
答：不对。现在应该是得tlboper_ptw_abort时也无效化所有的pde cache。
99.  PDE cache 的 PLRU 在命中时是否更新？在写入新 entry 时，如果存在 invalid entry，优先使用 invalid entry 还是仍按 PLRU victim？
答：命中时更新，写入时也更新。存在invalid entry说明satp的值修改了，优先invalid entry。
100. PDE cache lookup 与 PDE cache update 若同周期发生，读写同一个 entry 或同一个 tag 时的预期行为是什么？lookup 看旧值还是新值？
答：PDE cache lookup 与 PDE cache update 若同周期发生，这个新的数据在下一个时钟周期才会真正更新进entry中，所以这个时钟周期如果PDE cache lookup可以读出数据，但是下一个时钟周期tag就改变了，因为新的写入了。
101. PDE cache 更新的 PPN 来自非叶子 PTE。若该非叶子 PTE 的 PPN 指向的下一级页表地址 PMP 原本通过，但后续 PMP 配置变化，PDE cache 命中后会跳过被缓存级别的 PMP 检查；这是设计预期吗？是否依赖 PMP 变化时清空 PDE cache？
答：PMP 配置变化后也应该清空PDE cache。

### 17. Mbuf/LSU 与异常返回

102. mbuf entry 的释放时机是什么？LSU 返回数据时释放，数据成功送入 CHK 流水线时释放，还是该级 CHK 处理完成后释放？
答：mbuf entry 的释放时机是接收到的lsu数据成功返回到相应的twu的特点位置。所以是数据成功送入 CHK 流水线时释放。
103. DTLB mbuf 分配指针“左移一位”时，如果指向的 entry 仍 valid 但其他 entry 空闲，是否会跳过 valid entry 寻找空闲项，还是依赖上游保证不会发生？
答：不可能出现准备左移到的那个entry的valid仍有效，因为mbuf中entry数量等于ptw中最多存在的请求数量，所以mbuf只可能满，不可能溢出，故而不可能出现准备左移到的那个entry的valid仍有效的情况。
104. LSU 返回 bus error 时，请求是否不进入 CHK 流水线，而是直接形成访问异常？该 mbuf entry 是否同拍释放？
答：请求不进入 CHK 流水线，而是直接形成访问异常。该mbuf entry 在该异常被授权写入mbuf的访问异常寄存器中后就释放。
105. LSU 返回 bus error 与 `tlboper_ptw_abort` 同周期时，该访问异常是否属于“abort 当拍已经获得仲裁的异常可以上报”的范畴，还是 bus error 返回会被丢弃？
答：不属于，只有在tlboper_ptw_abort到来前正常写入mbuf的访问异常寄存器中的请求才能成功上报。
1.   当 LSU 返回数据但目标 CHK 不 ready，entry 保存数据且不阻塞其他 LSU 请求。若随后发生 abort，已保存但未送入 CHK 的数据是否直接清 valid 并丢弃？
答：是。

### 18. 跨页检查与 sysmap

107. 第 48 题回答中“首地址用 ppn[1:0] 全 1、尾地址用 ppn[1:0] 全 0”的表述看起来与“第一个/最后一个 4K 块”相反。请确认 1G/2M 跨页检查的 first/last 物理块 PPN 精确计算公式。
答：现在我已经修改
108. 1G 降级到 2M 的最终 PPN 是否应为 `{pte.ppn[2], vpn[1], 9'b0}`？当前回答 `{pte.ppn[2], vpn[1], pte.ppn[0]}` 在 PPN[0] 非 0 时会产生不同结果，请确认是否依赖 PPN[0] 一定为 0。
答：其实两则都一样，因为pte.ppn[0]就是全0，因为1G页表要物理地址对齐。如果不对齐已经触发页表异常了。
109. 2M 降级到 4K 的最终 PPN 是否为 `{pte.ppn[2], pte.ppn[1], vpn[0]}`；如果原 2M PTE 的 PPN[0] 非 0 且硬件不做对齐检查，是否仍完全覆盖为 vpn[0]？
答：2M PTE 的 PPN[0] 非 0会触发页表异常，不会进入跨页检查，而是上报异常，然后结束。
110. sysmap 如果没有命中任何区域，或者异常地命中多个区域，PTW 如何处理？是否触发访问异常、页表异常、使用默认属性，还是这种配置不考虑？
答：默认sysmap 不会发生没有命中任何区域，或者异常地命中多个区域的情况。不可能出现没有命中任何区域，或者异常地命中多个区域，因为划分区域的时候最小单元是4K，而发过去的是ppn，是对4K块的地址。因此不可能出现。
111. MAEE 关闭且 4K 叶子 PTE 不需要跨页降级时，是否仍需要访问 sysmap 取得 PMA 属性用于 refill？如果需要，请补充 4K 正常 refill 的 sysmap 查询时序。
答：是。仍然需要访问 sysmap 取得 PMA 属性用于 refill。（rtl已经修好）
1.   MAEE 关闭且 1G/2M 大页首尾落在同一个 sysmap 区域时，refill 的 PMA 属性取首地址、尾地址、还是两者相同后任取一个？
答：取尾地址，但是其实取首地址、尾地址都无所谓，因为他们命中同一个 sysmap 区域，他们的 PMA 属性是一样的。
1.   跨页检查状态机最终确定不跨页或完成降级后，进入 refill 寄存器和顶层仲裁的完整时序还没有写完。请补充从跨页检查结束到 refill 返回的后续周期。
答：已补充。

### 19. 仲裁优先级与 cycle 检查边界

114. TWU 内部“itlb 优先 > 高等级页表 > 低等级页表”中，高等级已确认是第三级优先。请明确各内部仲裁器的完整顺序是否都是 `itlb` 优先，然后 `thd > scd > fst`。
答：是。
115. 正常 refill 仲裁器有 4 个来源：fst/scd/thd CHK 和跨页检查状态机。跨页检查状态机相对 thd/scd/fst 的优先级是什么？
答：itlb>跨页检查状态机>thd>scd>fst。
116. 顶层访问异常仲裁器有 5 个来源：4 个 TWU 和 LSU bus error。LSU bus error 相对 4 个 TWU 访问异常寄存器的优先级是什么？
答：LSU bus error>4 个 TWU 访问异常寄存器
117. 如果同一个原始请求理论上可能在同周期出现 bus error 访问异常和 CHK 页表异常，是否访问异常一定覆盖页表异常？还是这种组合在结构上不会发生？
答：同一个原始请求不可能在同周期出现 bus error 访问异常和 CHK 页表异常，因为bus error 访问异常触发后，该请求就不会正常返回到twu的CHK流水线了，更不会触发CHK 页表异常。是拿到lsu返回的数据有效信号的下一个时钟周期请求才真正的进入chk流水线。
118. UVM scoreboard 是否需要检查 exact cycle，例如 T0/T1/T2 和每一级固定一拍；还是只要求在有限延迟内功能结果正确，cycle-accurate 留给 assertion/monitor 检查？
答：只要求在有限延迟内功能结果正确。

### 20. 建议补充的完整处理过程

119. 请补充“第一级 PDE cache 命中，最终得到 4K/2M 页”的完整流程，明确从 PDE cache 命中后进入哪一级 PMP、如何生成物理地址、是否更新第二级 PDE cache。
答：请求进入PDE cache后会同时查找第一级和第二级pde cache的所有entry，并行查找，如果有命中第一级PDE cache的某个entry则为命中第一级PDE cache，第二级同理。命中第一级PDE cache可以跳过fst pmp和fst chhk，直接进入scd pmp。命中第二级PDE cache可以直接进入thd pmp。并且在lsu返回其页表数据时如果为非叶子页表并且未触发异常（在mbuf中检查）也会更新第二级 PDE cache。
120.   请补充“第二级 PDE cache 命中，最终得到 4K 页”的完整流程，明确跳过 fst/scd 后如何进入 thd_pmp/thd_chk。
答：  T0时L2TLB的请求拉高，T1时，第二级 PDE cache 命中则跳过fst和scd，直接进入thd pmp，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+2时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；Tn+3时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+4时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。

121. 请补充“LSU 返回 bus error 触发访问异常”的完整流程，包括 mbuf entry、访问异常寄存器、顶层仲裁和返回源的处理。
答：T0时，LSU 返回 bus error ，会跟踪到请求entry，然后发出更新mbuf中的访问异常寄存器的请求，T1时，mbuf中的访问异常寄存器有效信号拉高，并且携带该请求的id和type，mbuf中的访问异常寄存器发出上报请求到顶层，仲裁后拿到授权后，将异常上报。
122.   请补充“abort 到来时 LSU 中有 outstanding 请求”的完整流程，包括 abort 当拍清哪些 valid、PTW ready 何时拉低/拉高、LSU 返回后如何丢弃数据、L2TLB 何时重发。
答：  如果abort 到来时请求刚刚准备要发出第一拍，那么直接屏蔽请求即可，不用担心lsu会接收到请求，如果abort 到来时请求已经在持有了段时间，不是发出的第一拍，那么需要保持请求拉高，直到lsu返回数据有效信号但是这个数据不会拿去干什么，直接丢失，然后ptw才能接收L2TLB重新发的请求，如果abort 到来时刚好收到lsu返回数据有效信号，那么也不需要保持请求拉高了。
123.请补充“maee 关闭但不需要降级的大页 refill”完整流程，即 1G/2M 首尾 sysmap 命中同一区域后如何选择 PMA、写入 refill 寄存器并返回。
答：已补充。

## 第三轮待澄清问题

本轮问题主要来自第二轮答案后的剩余边界和少量正文/答案之间的冲突。目标是让后续 UVM 审核能明确区分“最终 spec 预期行为”和“当前 RTL 可能还要修改的行为”。

### 21. Spec 版本与待修改 RTL

124. 文档中出现了“现在应该是得 tlboper_ptw_abort 时也无效化所有的 pde cache”和“rtl 要改下”等表述。后续 UVM 审核应以这些最新回答作为最终 spec 吗？如果当前 RTL 与这些回答不一致，是否应判定为 RTL bug？
答：tlboper_ptw_abort 时也无效化所有的 pde cache，我已经在rtl实现了，你直接按这些最新回答作为最终 spec 。
125. 对于已经发现需要修改 RTL 的点，是否希望在本文档中单独增加“已知 RTL 待修项”小节，避免后续 AI 审核时把旧 RTL 行为误认为 spec？
答：是
126. 文档中有些回答直接引用 RTL 表达式，例如 `ptw_page_flt`。这些 RTL 表达式是否就是规范性规则？如果后续文字描述和 RTL 表达式冲突，UVM reference model 应优先按哪一个建模？
答：是规范性规则。如果后续文字描述和 RTL 表达式冲突，UVM reference model 应优先按文字描述。

### 22. PTE/flg 位映射与权限规则

127. 请给出 `ptw_flg`/refill `flg` 的精确 bit map。现在文字说 flg 包含扩展属性和 D/A/G/U/X/W/R/V，但代码片段中 `ptw_flg[5]` 被当作 A、`ptw_flg[6]` 被当作 D，和标准 PTE bit 中 G/A/D 的位置不完全一致。scoreboard 应按 raw PTE bit 位置，还是按设计内部重新打包后的 `ptw_flg` 位置？
答：flg包含扩展属性和 D/A/G/U/X/W/R/V，这里的ptw_flg相比flg缺少了G位，所以`ptw_flg[5]` 被当作 A、`ptw_flg[6]` 被当作 D。scoreboard 应按 raw PTE bit 位置。
128. PTE 高位扩展属性 So/C/B/Sh/Sec 的精确 bit 编号和顺序是什么？例如是否为 bit[63:59]，且从高到低依次为 So、C、B、Sh、Sec？
答：从 最高位往低位 紧挨着排布在 bit 63～bit 59，顺序依次是：bit 63 为 So，bit 62 为 C，bit 61 为 B，bit 60 为 Sh，bit 59 为 Sec。
129. refill 返回的 `global` 位如何生成？只使用叶子 PTE 的 G 位，还是需要 OR 上任意上级非叶子 PTE 的 G 位？如果非叶子 G 位参与 global，PDE cache 不存 G 位时如何保证 PDE cache 命中路径仍能返回正确 global？
答：refill 返回的 `global` 位是页表flg中的G位，只使用叶子 PTE 的 G 位。
130. RSW[1:0] 是否完全忽略，既不参与异常判断，也不进入 refill `flg`？
答：RSW[1:0]就是一个保留位，不会对他做任何处理。但也进入refill `flg`。
131. “write only” 规则请再次确认：在本设计中 `W=1,R=0,X=1,MXR=1` 是否允许通过，不触发 page fault？这与标准 Sv39 常规规则不同，后续 reference model 需要按本设计还是按 RISC-V 标准建模？
答：本设计中 `W=1,R=0,X=1,MXR=1` 允许通过，不触发 page fault。后续 reference model 需要按本设计。
132. A 位检查请明确：对所有叶子 PTE，不论 fetch/load/store/PFU，是否都要求 A=1？第 95 题回答里 “load 要求 A=1（在 mxr 有效的情况下）” 是否应改为 “load 总是要求 A=1”？
答：对所有叶子 PTE，不论 fetch/load/store/PFU，都要求 A=1。我已经修改了第 95 题回答。
133. PFU 的 PTE 权限检查按 load 处理、fetch 处理，还是独立处理？例如 PFU 是否要求 R=1 或 `MXR && X=1`，是否要求 A=1，是否检查 D 位？
答：独立处理，就是按PFU类型处理。PFU不要求 R=1 或 `MXR && X=1`，要求 A=1，不检查 D 位。
134. MPRV 和 M-mode 对页表权限检查的影响还不够明确。`cp0_supv_mode` 和 `cp0_user_mode` 都为 0 的机器模式下，U/S 权限检查是否完全跳过？MPRV 是否已经被 CP0 转换成 `cp0_supv_mode/cp0_user_mode` 后再输入 PTW？
答：机器模式下，ppn等于ppn，不会有请求进入ptw，所以不考虑U/S 权限检查，不考虑该问题。
135. page fault 和 access fault 返回给上游时是否只有“页表异常/访问异常”两类标志，没有 instruction/load/store/prefetch cause 细分？PFU 异常是否也没有独立 cause 编码？
答：page fault 和 access fault 返回给上游时只有“页表异常/访问异常”两类标志。type和id只是用来让异常定位到请求的出处而已，不是异常的类型编码。比如type是fentch，那么就上报给itlb，如果type是load或store，那么就上报给dtlb，并且根据上报到精确的dtlb miss buffer的entry中。

### 23. 上下文变化、清空与一致性

136. satp 任意字段改变会清空 PDE cache。它是否也会清空 PTW 当前 in-flight 请求、TWU 流水线、mbuf、异常寄存器和 refill 寄存器？还是只清 PDE cache，不影响正在进行的 walk？
答：不会。satp 任意字段改变只会清空 PDE cache，不会做认为其他操作，不影响正在进行的 walk。
137. 如果 satp.asid 在一次 walk 中途改变，而该 walk 没有被 abort/flush，且 refill 返回当拍使用新 ASID，那么旧页表 walk 的结果是否可能以新 ASID refill？这是设计允许的行为，还是软件必须通过 sfence/tlboper 避免？
答：软件会跳过sfence/tlboper 避免，一般情况下satp.asid改变都会伴随着后续的abort。
138. PMP 配置变化后“也应该清空 PDE cache”。该清空是否由硬件信号自动触发？是否同时 abort/flush in-flight PTW 请求？如果只是软件约束，请说明 UVM 是否需要主动建模该事件。
答：该清空由硬件信号自动触发。只会清空PDE cache，不会abort/flush in-flight PTW 请求。
139. `tlboper_ptw_abort` 同拍如果发生 PDE cache lookup 或 PDE cache update，优先级如何定义？是先无效化再 lookup/update，使当拍不会命中/写入，还是当拍已完成的 lookup/update 可能生效但随后被清掉？
答：tlboper_ptw_abort时所有的请求都会被冲刷，在PDE cache lookup的请求会被冲刷掉，PDE cache update的请求也不会让他更新进pde cache，pde cache会被全部清空。当拍已完成的 lookup/update 可能生效但随后被清掉。
140. reset、satp 改变、PMP 配置改变、tlboper abort 这几类事件对 PDE cache、TWU、mbuf、refill/异常寄存器的影响是否可以整理成一张表？目前第 65 题说没有其他 abort 来源，但第 97/101 题又引入了 PDE cache 清空来源，容易混淆。
答：reset和tlboper abort 会清空PDE cache 并且abort/flush in-flight PTW 请求。satp 改变、PMP 配置改变只会清空PDE cache，不会做其他操作。

### 24. 返回目标、匹配与异常可见性

141. 请按 type 列出正常 refill 的目标：IUTLB 是否 refill L1ITLB 和 L2TLB？Load/Store 是否 refill L1DTLB 和 L2TLB？PFU 是否只 refill L2TLB？是否存在只 refill L1 不 refill L2 的情况？
答：IUTLB 是 refill L1ITLB 和 L2TLB，Load/Store 是 refill L1DTLB 和 L2TLB，PFU 只 refill L2TLB，不存在只 refill L1 不 refill L2 的情况
142. PFU 触发 page fault/access fault 时异常上报到哪里？因为 PFU 正常情况只 refill L2TLB，它的异常是否返回给 L2TLB miss buffer、LSU prefetch 端口，还是被上游静默处理？
答：它的异常返回给 L2TLB，然后L2TLB上报到LSU prefetch 端口。
143. PTW 返回可能因为多个 TWU 和不同页级并发而乱序。scoreboard 是否应完全按 `type + id` 匹配返回，而不检查请求返回顺序？对 IUTLB id 固定为 0 且同一时间只允许一个 IFU 请求，这个假设是否足够？
答：PTW 返回可能出现多个 TWU 和不同页级的请求要返回，但是仲裁部分会决定那个请求先返回，是有顺序的，不是乱序的。优先级同样是itlb优先，然后thd>scd>fst。
144. 第 118 题说 scoreboard 只要求有限延迟内功能正确。是否需要给出一个无 LSU 长延迟/无 backpressure 情况下的最大期望延迟，还是 scoreboard 不设固定周期上限，只做事务最终匹配？
答：scoreboard 不设固定周期上限，只做事务最终匹配。

### 25. Mbuf、LSU 与 abort 边界

145. LSU bus error 时，mbuf entry 在“访问异常被授权写入 mbuf 的访问异常寄存器后”释放。若访问异常寄存器暂时 busy 或仲裁未授权，该 mbuf entry 是否保持 valid 并阻塞对应 entry 复用？
答：若访问异常寄存器暂时 busy 或仲裁未授权会将该LSU bus error 的信号先寄存在LSU bus error flop寄存器中，然后尝试发请求，异常寄存器空闲并仲裁授权时就释放了，在这之前不会释放。
146. `tlboper_ptw_abort` 到来时“请求刚刚准备要发出第一拍”和“已经持有了一段时间”的边界请精确定义。是否以 LSU request valid 在 abort 前一拍已经为 1 作为是否必须继续保持 valid 等待返回的判断条件？
答：LSU request valid 在 abort 前一拍已经为 1 ，那么需要继续保持 valid 等待返回。可以以 LSU request valid 在 abort 前一拍已经为 1 作为必须继续保持 valid 等待返回的判断条件。
147. abort 当拍如果 LSU data valid 返回普通数据而非 bus error，且目标 CHK ready，是否仍必须丢弃数据，不进入 CHK、不更新 PDE cache、不产生 refill？
答：仍必须丢弃数据，不进入 CHK、不更新 PDE cache、不产生 refill。
148. abort 当拍如果 LSU data valid 返回 bus error，第 105 题说可上报。它是否一定因为 LSU bus error 优先级最高而获得访问异常仲裁，还是仍可能因最终输出仲裁/下游阻塞而被清掉？
答：abort 当拍如果 LSU data valid 返回 bus error，那么他得先更新进mbuf的访问异常寄存器，这需要一个时钟周期，而abort会阻止其更新进mbuf的访问异常寄存器导致异常不会上报。如果你是指abort 当拍mbuf的访问异常寄存器有异常要上报，那么进入顶层的仲裁，该仲裁的确是LSU bus error 优先级最高，是可以成功立刻上报的。

### 26. MAEE、sysmap 与跨页降级

149. MAEE 关闭时，所有 page size 的 refill `flg` 扩展属性是否都必须来自 sysmap，包括 4K、2M、1G、以及 1G/2M 降级后的 2M/4K？
答：MAEE 关闭时，所有 page size 的 refill `flg` 扩展属性都必须来自 sysmap，包括 4K、2M、1G、以及 1G/2M 降级后的 2M/4K。
150. 4K 页在 MAEE 关闭时查询 sysmap 使用的地址是最终物理 PPN，即叶子 PTE 的 PPN 吗？如果是降级得到的 4K，则使用降级后的最终 PPN 吗？
答：是的。是的。
151. MAEE 在 walk 中途改变且不会触发 abort。若 CHK 时 MAEE=0 进入跨页/sysmap 流程，但 refill 前 MAEE 变为 1，最终 refill 属性按进入跨页时的 MAEE=0，还是 refill 当拍的 MAEE=1？
答：最终 refill 属性按进入跨页时的 MAEE=0。是否进入跨页都是以当前maee的值为参考的，refill不会因为maee的值改变而改变要refill的值。进入跨页检查而导致要refill的数据改变是不可逆的，而且跨页检查也是不会中断的。
152. 1G/2M 跨页检查的 first/last PPN 已在正文中修改。请考虑把公式单独列出：1G first=`{pte.ppn[2], 9'b0, 9'b0}`、1G last=`{pte.ppn[2], 9'h1ff, 9'h1ff}`；2M first=`{pte.ppn[2], pte.ppn[1], 9'b0}`、2M last=`{pte.ppn[2], pte.ppn[1], 9'h1ff}`。这些公式是否正确？
答：正确。
153. 大页跨区域降级后，如果降级结果为 2M 且不再跨区域，refill 的 page size 为 2M，PPN 为 `{pte.ppn[2], vpn[1], 9'b0}`，属性取该 2M 尾地址 sysmap；请确认该组合规则。
答：正确。

### 27. 仍建议补充的完整流程

154. 请补充“第一级 PDE cache 命中后最终得到 2M 页”和“第一级 PDE cache 命中后最终得到 4K 页”的完整流程，尤其是 scd_pmp/thd_pmp 地址生成公式，以及 scd_chk 读到非叶子 PTE 后是否更新第二级 PDE cache。
答：已补充。
155. 请补充“satp 改变或 PMP 配置改变导致 PDE cache 清空”的完整流程，明确是否影响 in-flight PTW 请求，以及 L2TLB 是否需要重发。
答：satp 改变或 PMP 配置改变会生成一个激励信号，该激励信号会让pde cache中所有entry的valid在下一个时钟周期都拉低。不会影响in-flight PTW 请求。L2TLB 不需要重发。不过satp改变都伴随着tlboper_ptw_abort（不保证是他们是同一拍）。
156. 请补充“PFU 请求成功 refill”和“PFU 请求触发异常”的完整流程，明确目标、id、返回字段和异常可见性。
答：已补充。

## 第四轮待澄清问题

本轮只记录少量剩余校对点。PTW 主体行为已经基本清楚，下面这些主要用于避免后续 UVM 审核时因文档局部冲突而误判。

### 28. 文档局部一致性

157. 第 11、12 个完整流程的标题和内容疑似反了：第 11 个标题写“第一级 PDE cache 命中后最终得到 4K 页”，但流程在 `scd_chk` 检查到叶子后直接 refill，看起来应是最终得到 2M 页；第 12 个标题写“最终得到 2M 页”，但流程 `scd_chk` 非叶子后进入 `thd_pmp/thd_chk`，看起来应是最终得到 4K 页。请确认是否需要交换这两个标题。
答：我已经修改。
158. 第 119 题回答仍写“命中第一级 PDE cache 可以跳过 fst，直接进入 scd pmp”，但没有明确 scd_chk 读到非叶子 PTE 且无异常时，是否会把该第二级非叶子 PTE 更新进第二级 PDE cache。请确认：第一级 PDE cache 命中、随后 scd_chk 得到非叶子 PTE 时，是否仍按 `lvl=scd` 更新第二级 PDE cache？
答：会，我已经修改。当表示在scd_chk进行叶子表项和页表异常的检查才更新进pde cache，而是mbuf中有自己的叶子表项和页表异常的检查，当拿到lsu的返回时会进行检查，如果发现是非叶子页表，并且没有触发页表异常，那么会更新进pde cache。
159. 第 148 题回答修正了第 105 题语义：abort 当拍 LSU data valid 返回 bus error 时不会上报，因为 abort 阻止其写入 mbuf 访问异常寄存器；只有 abort 当拍之前已经在 mbuf 访问异常寄存器中、并正在顶层仲裁的异常可以上报。请确认后续以第 148 题为准。
答：确认，以第 148 题为准。
160. 第 125 题回答希望增加“已知 RTL 待修项”，但第 124 题又说 tlboper 清 PDE cache 已经在 RTL 实现。当前是否还存在已知 RTL 待修项？如果存在，请列出；如果不存在，后续 UVM 审核可不再维护该小节。
答：当前不存在，之前的tlboper 清 PDE cache 已经在 RTL 实现。

## 第五轮待澄清问题

本轮不是新增大机制，主要是把旧答案和最新答案之间仍可能让 UVM reference model/scoreboard 建模歧义的地方收敛掉。

### 29. 旧答案与最终 spec 优先级

161. 第 18 题仍写 `tlboper_ptw_abort` 只屏蔽当前 PDE cache 请求；但第 98/124/140/159 题已经确认 `tlboper_ptw_abort` 会清空全部 PDE cache，并且以最新回答作为最终 spec。请确认后续应把第 18 题旧答改成“清空全部 PDE cache + flush in-flight PTW 请求”，避免审核时读到旧答误判。
答：我已经修改。
162. 正文第 13 条写“回填请求会被屏蔽，但是异常上报的请求不会”；第 59/105/148/159 题又把异常上报限定为 abort 当拍之前已经进入异常寄存器且正在顶层仲裁/已经被授权的异常，新形成的 LSU bus error 不会上报。请确认正文第 13 条应改成这个更窄条件。
答：已修改。
163. 第 111 题仍保留“MAEE 关闭且 4K 页需要 sysmap refill，RTL 要改下”的表述，但第 160 题说当前不存在已知 RTL 待修项。请确认 4K 页 MAEE 关闭时走 sysmap 的 RTL 是否已经修好；如果还没修好，是否应恢复“已知 RTL 待修项”小节并把该项列进去。
答：已经修好。

### 30. flg/RSW/G 位映射

164. 正文第 20 条说 L1 refill 的 `flg` 包含 2bit RSW；第 130 题说 RSW[1:0] 不参与异常判断，也不进入 refill `flg`。请确认最终 refill `flg` 是否完全不包含 RSW；如果不包含，请把正文第 20 条里的 RSW 删除。
答：refill flg包含 RSW，但是其不参与异常判断。
165. 请区分 raw PTE bit、内部 `ptw_flg` bit、refill tag/data bit 三套映射。尤其需要确认：raw PTE 的 G bit 是否只单独返回为 `global`，不进入 data `flg`；内部 `ptw_flg` 是否去掉 G 后才出现 `ptw_flg[5]=A`、`ptw_flg[6]=D`；MAEE=0 时 sysmap 5bit 写入 refill `flg` 的 bit 顺序到底是 `{So,C,B,Sh,Sec}` 还是 `{Sec,Sh,B,C,So}`。
答：raw PTE的G位不进入data flg，而是放在tag中。内部 `ptw_flg` 是去掉 G 后才出现 `ptw_flg[5]=A`、`ptw_flg[6]=D`。是{So,C,B,Sh,Sec}。

### 31. Page fault 最终规则

166. 第 29 题说严格遵循 RISC-V Sv39，并列出 `fetch meets strong order`；但第 90/96/130/131 题确认保留位不检查、RSW 忽略、strong order 不由 MMU 检查、write-only/MXR 按本设计的非标准规则。请确认 UVM reference model 最终只按第 94/95/96/131/132/133 题的 RTL/文字规则建模，不再额外套用标准 Sv39 的保留位/RSW/strong-order 检查。
答： UVM reference model 最终只按第 94/95/96/131/132/133 题的 RTL/文字规则建模，不再额外套用标准 Sv39 的保留位/RSW/strong-order 检查。
167. 非叶子 PTE 的最终 page fault 规则请再收敛一次：是否仅为 `V=0`、write-only 规则、以及第三级仍为非叶子 PTE 这几类会触发 fault；除此之外 U/G/A/D/RSW/高位保留位/扩展属性都不检查？如果还有其他非叶子检查，请补完整布尔规则。
答：仅V=0`、write-only 规则、以及第三级仍为非叶子 PTE这几类会触发 fault。除此之外 U/G/A/D/RSW/高位保留位/扩展属性非叶子PTE都不检查。

### 32. 上下文改变与 PDE cache 更新

168. satp/PMP 配置改变只清空 PDE cache，不 abort in-flight walk。若清空之后，旧 in-flight walk 又返回一个非叶子 PTE 且无异常，是否允许它重新更新 PDE cache？第 17 题里的“对应上下文仍有效”是否表示 satp/PMP 已改变时必须禁止这次 PDE cache update？
答：允许它重新更新 PDE cache，但是satp配置改变一般情况下伴随着abort。PMP 配置一般情况下也不发生改变。不必须，后续会来abort进行处理。
169. 如果 satp.asid 或 satp.ppn 改变但没有 `tlboper_ptw_abort`，旧 walk 最终可能按 refill 当拍的新 ASID 返回。请确认这是软件必须避免、UVM 可以约束不生成的场景，还是 scoreboard 必须按硬件现状允许这种交错行为。
答：satp.asid 或 satp.ppn 改变一般伴随tlboper_ptw_abort。UVM 可以约束不生成的该场景。

### 33. 完整流程标题和流水级笔误

170. 完整流程第 4/5 个标题写“最终得到 1G/2M 页表”，但括号和正文分别描述“降级至 2M/4K”，最终 refill 的 page size 也应是降级后的 2M/4K。请确认这两个标题应分别改成“最终得到 2M 页表”和“最终得到 4K 页表”。
答：已修改。
171. 第 120 题以及若干完整流程中，进入 `thd_pmp` 后仍写 `assign scd_pmp_pa` 或“scd_pmp 发到 mbuf”。请确认这些只是笔误，规范应按当前流水级使用 `thd_pmp_pa/thd_pmp`。
答：是笔误，规范应按当前流水级使用 `thd_pmp_pa/thd_pmp`。

### 34. Scoreboard 与仲裁顺序

172. 第 118/144 题说 scoreboard 只做事务最终匹配、不设固定周期上限；第 143 题又强调 PTW 返回有仲裁顺序。请确认 scoreboard 是否需要检查同周期多个候选返回时的仲裁优先级，还是仲裁优先级交给 assertion/monitor，scoreboard 只按 `type + id` 匹配最终结果。
答：仲裁优先级交给 assertion/monitor，scoreboard 只按 `type + id` 匹配最终结果。。

### 35. Machine mode 请求约束

173. 第 24 题 PMP 检查里存在 machine mode 跳过 PMP 的规则，但第 134 题说机器模式下不会有请求进入 PTW。请确认 UVM 是否应约束不产生 `cp0_mach_mode` 下的 PTW 请求；如果不约束，reference model 是否仍按第 24 题的 machine-mode PMP skip 规则处理。
答：最新修正：fetch 使用流水线真实硬件特权级（M/S/U），不受 MPRV/MPP 影响；load/store/PFU 在 MPRV 有效时按 mstatus.MPP 作为 data effective privilege。当真实流水线为 S/U 且 `MPRV=1 && MPP=M` 时，load/store/PFU 走 data direct-map，物理地址直接等于虚拟地址，不会进入 PTW。纯 M 态同样不会进入 PTW。只有真实 S/U 的 fetch 在 Sv39 下仍可能进入 PTW。

## 第六轮待澄清问题

本轮只剩少量会影响 UVM reference model 输入状态采样和 refill 字段建模的点。PTW 主流程、PDE cache、mbuf/LSU、abort、MAEE/sysmap、异常/refill 返回目标已经基本收敛。

### 36. 旧答案同步与字段定义

174. 第 164 题已经确认 refill `flg` 包含 RSW，只是不参与异常判断；但第 130 题仍写 RSW 不进入 refill `flg`。请确认后续应以第 164 题为准，并把第 130 题旧答改为“RSW 进入 refill flg，但不参与 page fault 判断”。
答：确认后续应以第 164 题为准。以修改。
175. 第 168 题确认 satp/PMP 改变清空 PDE cache 后，旧 in-flight walk 返回的非叶子 PTE 仍允许重新更新 PDE cache；但第 17 题仍写 PDE cache 更新要求“对应上下文仍有效”。请确认后续应把第 17 题里的“对应上下文仍有效”删除或改成“未被 abort/flush 屏蔽即可”，否则 reference model 会误认为 satp/PMP 改变后必须禁止旧 walk 更新 PDE cache。
答：已修改。
176. 第 29 题旧答仍写“严格遵循 RISC-V Sv39”并列出 strong-order/page-fault 项；第 166/167 题已经确认最终按本设计 RTL/文字规则，不额外检查保留位、RSW、strong-order，非叶子 PTE 也只检查 `V=0`、write-only、第三级非叶子。请确认第 29 题旧答也应同步改成第 166/167 题的最终规则。
答：第 29 题旧答也应同步改成第 166/167 题的最终规则。

### 37. MPRV/MPP effective privilege

177. 第 173 题补充了 load/store/PFU 在 `MPRV=1` 时按 `mstatus.MPP` 作为有效特权级。请明确 reference model 应如何生成权限检查使用的 effective mode：fetch 是否永远用流水线真实特权级；load/store/PFU 是否在 `MPRV=1` 时用 `MPP`，否则用真实特权级；`cp0_supv_mode/cp0_user_mode/cp0_mach_mode` 输入到 PTW 时是否已经是这个 effective mode？
答：fetch 永远用流水线真实特权级，load/store/PFU 在 `MPRV=1` 时用 `MPP`，否则用真实特权；但当 load/store/PFU 的 effective privilege 因 `MPRV=1 && MPP=M` 变成 M 时，data MMU 关闭，VA=PA，不进入 PTW。
178. 旧问法：当 load/store/PFU 因 `MPRV=1 && MPP=M` 进入 PTW 且 PTW 选用 machine mode 状态时，PMP 检查是否按第 24 题的 machine-mode skip 规则执行，即 `cp0_mach_mode && !pmp_mmu_flg[3]` 时不触发 access fault？同一请求的 PTE U/S 权限检查是否也按 machine effective mode 跳过 S/U 检查？
答：最新修正覆盖旧答。load/store/PFU 在 `MPRV=1 && MPP=M` 时不会进入 PTW，因此不存在对该请求执行 PTW PMP/PTE U/S 检查的合法流程。
179. 旧问法：请补充或确认 “load/store/PFU，`MPRV=1 && MPP=M`，且发生 PTW walk” 的完整处理流程是否和普通 load/store/PFU walk 相同，只是在 PMP 检查和 PTE U/S 权限检查中使用 machine effective mode；正常 refill/异常返回目标仍按原始 `type + id` 返回到 DTLB/L2TLB 或 PFU 端口。
答：最新修正覆盖旧答。该 data/PFU PTW walk 不应发生；UVM 应约束为 no PTW source，并用 consumer/direct-map 证据检查 VA=PA 行为。fetch 不受 MPRV/MPP 影响，仍按真实流水线模式判断。

### 38. 文档笔误同步

180. 第 171 题确认 `thd_pmp` 后仍写 `scd_pmp 发到 mbuf` 属于笔误。正文完整流程第 1、第 12、第 120 题等位置仍能搜到这些残留表述。请确认这些位置后续都统一改成 `thd_pmp 发到 mbuf`，不改变 spec 行为。
答：这些位置后续都统一改成 `thd_pmp 发到 mbuf。后续发现你可自行修改。
