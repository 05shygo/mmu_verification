# MMU PTW/MBUF LSU ID、Grant、Abort Drain 与 PDE Cache/PLRU 更新说明

更新时间：2026-06-10

本文档记录 `mmu_new/rtl` 中 PTW/MBUF 相关 RTL 的全部行为性修改，并补充 PDE cache 连续更新路径的检查与修复说明。文档中的“原版代码”来自 `C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl`，“修改后代码”来自 `mmu_new/rtl`。

本次 RTL 修改遵循以下约束：

1. 不修改 LSU RTL。
2. MMU/PTW 发给 LSU 的页表项读取请求新增 4-bit request ID。
3. Request ID 直接使用 MBUF entry index。
4. LSU 返回 data 或 bus error 时新增 4-bit response ID，并要求等于原 request ID。
5. Response 按 ID 在 `ptw_mbuf` 中直接解码到对应 entry，不在每个 `mbuf_entry` 内再做比较。
6. 新增 LSU grant 握手，只有 `mmu_lsu_data_req && lsu_mmu_data_req_grant` 同拍成立，请求才算真正进入 LSU outstanding 队列。
7. Abort 时只清 entry `vld`，不直接清 entry `on`；已被 LSU grant 接收的 outstanding 请求必须等 response 回来后清 `on`。
8. Abort drain 期间禁止创建新 MBUF entry、禁止发新 LSU request、禁止 PDE cache 更新。
9. PDE cache 连续两拍 update 时，entry 写使能与 PLRU replacement way 必须同拍一致，不能使用上一拍 way。

## 1. 文件范围

### 1.1 原版代码基线

```text
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ct_mmu_top.v
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw.sv
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/mbuf_entry.sv
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/pplru.sv
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/PDE_cache.sv
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/L1PDE_cache.sv
C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/L2PDE_cache.sv
```

### 1.2 修改后代码位置

```text
mmu_new/rtl/ct_mmu_top.v
mmu_new/rtl/ptw.sv
mmu_new/rtl/ptw_mbuf.sv
mmu_new/rtl/mbuf_entry.sv
mmu_new/rtl/pplru.sv
mmu_new/rtl/PDE_cache.sv
mmu_new/rtl/L1PDE_cache.sv
mmu_new/rtl/L2PDE_cache.sv
```

### 1.3 实际修改文件

```text
mmu_new/rtl/ct_mmu_top.v
mmu_new/rtl/ptw.sv
mmu_new/rtl/ptw_mbuf.sv
mmu_new/rtl/mbuf_entry.sv
mmu_new/rtl/pplru.sv
```

### 1.4 已检查但本次无需改动的 PDE cache entry 文件

```text
mmu_new/rtl/PDE_cache.sv
mmu_new/rtl/L1PDE_cache.sv
mmu_new/rtl/L2PDE_cache.sv
```

`PDE_cache.sv`、`L1PDE_cache.sv`、`L2PDE_cache.sv` 的更新门控和 entry 写寄存器本身可以接受连续拍 update；连续更新错误来自 `pplru.sv` 中 replacement way 输出打一拍，具体见第 7 节。

## 2. 总体设计变化

### 2.1 原版设计模型

原版 PTW/MBUF 到 LSU 的页表项读取路径更接近“单 outstanding / 串行返回”模型：

1. `mmu_lsu_data_req` 表示有 entry 需要读页表项。
2. 没有 request ID。
3. LSU 返回只有全局 `lsu_mmu_data_vld`、`lsu_mmu_bus_error`、`lsu_mmu_data`。
4. 所有 MBUF entry 都能看到同一个 LSU response。
5. 请求推进依赖 `lsu_mmu_data_vld`。
6. Abort 会直接清 entry `on`。
7. PDE cache update 在非 abort 当拍可写，但没有考虑 abort 后 outstanding response drain。
8. PDE cache PLRU 的 refill way 输出来自上一拍寄存的 `refill_num_index`。

这种模型在多 outstanding PTW load 场景下会有根本问题：LSU response 回来后无法知道属于哪个 MBUF entry；如果所有 entry 都观察同一个 global response，就可能错误清 `on`、错误缓存 data、错误上报 bus error 或污染 PDE cache。

### 2.2 修改后设计模型

修改后建立明确的 request/response ID 契约：

```text
MBUF entry index
    -> mmu_lsu_data_req_id
    -> LSU outstanding queue
    -> lsu_mmu_data_id
    -> ptw_mbuf onehot decode
    -> corresponding mbuf_entry only
```

同时建立明确的 req/grant 契约：

```text
mmu_lsu_data_req = valid
lsu_mmu_data_req_grant = LSU accept
lsu_req_fire = mmu_lsu_data_req && lsu_mmu_data_req_grant
```

只有 `lsu_req_fire` 才表示请求真正进入 LSU outstanding 队列。`mbuf_entry.on` 只在对应 entry 的 `lsu_req_fire` 后置位，只在带相同 ID 的 LSU response 回来后清零。

### 2.3 修改原因总结

| 问题 | 原版行为 | 风险 | 修改后行为 |
| --- | --- | --- | --- |
| Request 无 ID | LSU 不知道返回属于哪个 entry | 多 outstanding 时 response 路由错误 | request 携带 `mmu_lsu_data_req_id` |
| Response 无 ID | 所有 entry 看同一个 response | 多 entry 同时受影响 | `ptw_mbuf` 按 `lsu_mmu_data_id` onehot 解码 |
| 无 LSU grant | req 拉高即可能被当作发出 | LSU 未接收时 entry 可能误置 `on` | 只有 `req && grant` 才 fire |
| grant 前请求不稳定 | 新高优先级 entry 可改变 addr | LSU 看到同一 req 下 addr/id 跳变 | `req_hold_ptr` 保持 addr/id |
| abort 直接清 `on` | outstanding 记录丢失 | LSU 后续 response 无法 drain | abort 只清 `vld`，`on` 等 response 清 |
| abort 后 response 仍可能写 cache | drain response 被当正常 data | PDE cache 污染 | `ptw_abort_drain` 屏蔽 cache update |
| PLRU refill way 打一拍 | PDE entry 写当前 data 用上一拍 way | 连续 update 覆盖/丢失 | `pplru` 当前 `write_num` 同拍输出 |

## 3. Top/PTW 接口新增 ID 与 Grant

### 3.1 修改原因

PTW/MBUF 允许多笔页表项读取 outstanding 后，LSU response 必须能回到发起请求的 MBUF entry。原版接口没有 request ID 和 response ID，也没有 LSU 接收确认信号，无法支持可靠的多 outstanding。

新增接口含义如下：

| 信号 | 方向 | 含义 |
| --- | --- | --- |
| `mmu_lsu_data_req_id[3:0]` | MMU -> LSU | PTW load request ID，等于 MBUF entry index |
| `lsu_mmu_data_id[3:0]` | LSU -> MMU | LSU response ID，必须等于对应 request ID |
| `lsu_mmu_data_req_grant` | LSU -> MMU | LSU 接收 request 的 grant/ready |

### 3.2 `ct_mmu_top.v` 原版代码

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ct_mmu_top.v
output logic           mmu_lsu_data_req,
output logic   [39:0]  mmu_lsu_data_req_addr,
output logic           mmu_lsu_data_req_size,

input logic            lsu_mmu_bus_error,
input logic            lsu_mmu_data_vld,
input logic   [63:0]   lsu_mmu_data,
```

原版 top 只暴露 request、addr、size 和 LSU 返回 data/error，没有 ID 和 grant。

### 3.3 `ct_mmu_top.v` 修改后代码

```systemverilog
// mmu_new/rtl/ct_mmu_top.v
output logic           mmu_lsu_data_req,
output logic   [39:0]  mmu_lsu_data_req_addr,
output logic           mmu_lsu_data_req_size,
// PTW 发给 LSU 的页表项读取请求 ID。
// 该 ID 由 PTW MBUF entry index 生成，用于支持多 outstanding 页表项读取。
output logic   [3 :0]  mmu_lsu_data_req_id,

input logic            lsu_mmu_bus_error,
input logic            lsu_mmu_data_vld,
input logic   [63:0]   lsu_mmu_data,
// LSU->PTW response id，必须等于当初 request 携带的 mmu_lsu_data_req_id。
input logic   [3 :0]   lsu_mmu_data_id,
// LSU 对 mmu_lsu_data_req 的 grant。只有 req/grant 同拍有效时，
// PTW MBUF 才把对应 entry 标记为 outstanding。
input logic            lsu_mmu_data_req_grant,
```

`ct_mmu_top` 内部 `ptw` 实例连接也新增了三个端口：

```systemverilog
// mmu_new/rtl/ct_mmu_top.v
.lsu_mmu_data_vld           (lsu_mmu_data_vld),
.lsu_mmu_data_id            (lsu_mmu_data_id),
.lsu_mmu_data_req_grant     (lsu_mmu_data_req_grant),
.mmu_lsu_data_req           (mmu_lsu_data_req),
.mmu_lsu_data_req_addr      (mmu_lsu_data_req_addr),
.mmu_lsu_data_req_id        (mmu_lsu_data_req_id),
.mmu_lsu_data_req_size      (mmu_lsu_data_req_size),
```

### 3.4 `ptw.sv` 原版代码

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw.sv
input  logic                   lsu_mmu_data_vld,
input  logic [DATA_WIDTH-1:0]  lsu_mmu_data,
input  logic                   lsu_mmu_bus_error,

output logic                   mmu_lsu_data_req,
output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,
output logic                   mmu_lsu_data_req_size,
```

### 3.5 `ptw.sv` 修改后代码

```systemverilog
// mmu_new/rtl/ptw.sv
parameter MBUF_ID_WIDTH = 4,

input  logic                   lsu_mmu_data_vld,
// LSU 返回 PTW load response 时带回的 MBUF entry id。
// PTW/MBUF 依赖该 id 把 data 或 bus error 路由回发起请求的 entry。
input  logic [MBUF_ID_WIDTH-1:0] lsu_mmu_data_id,
// LSU 对 PTW load request 的接收确认。只有 req/grant 同拍有效时，
// MBUF entry 才会置 on，并把该请求计入 outstanding。
input  logic                   lsu_mmu_data_req_grant,
input  logic [DATA_WIDTH-1:0]  lsu_mmu_data,
input  logic                   lsu_mmu_bus_error,

output logic                   mmu_lsu_data_req,
output logic [PADDR_WIDTH-1:0] mmu_lsu_data_req_addr,
// PTW 发给 LSU 的 request id，取自当前发起请求的 MBUF entry index。
// LSU 必须在 response 上带回同一个 id。
output logic [MBUF_ID_WIDTH-1:0] mmu_lsu_data_req_id,
output logic                   mmu_lsu_data_req_size,
```

`ptw` 对 `ptw_mbuf` 的实例化同步传递 ID 和 grant：

```systemverilog
// mmu_new/rtl/ptw.sv
.MBUF_ID_WIDTH                       (MBUF_ID_WIDTH      )
) u_ptw_mbuf(
    .lsu_mmu_data                    (lsu_mmu_data),
    .lsu_mmu_data_id                 (lsu_mmu_data_id),
    .lsu_mmu_data_req_grant          (lsu_mmu_data_req_grant),
    .lsu_mmu_bus_error               (lsu_mmu_bus_error),
    .mmu_lsu_data_req                (mmu_lsu_data_req),
    .mmu_lsu_data_req_addr           (mmu_lsu_data_req_addr),
    .mmu_lsu_data_req_id             (mmu_lsu_data_req_id),
    .mmu_lsu_data_req_size           (mmu_lsu_data_req_size),
```

### 3.6 行为解释

`ct_mmu_top` 和 `ptw` 不负责 ID 分配，也不负责 response ID 解码。它们只做端口扩展和信号透传。真正的 request ID 生成、grant hold、response route 都集中在 `ptw_mbuf` 中，这样可以保证同一个协议点只有一个实现位置，减少 entry 内重复比较逻辑。

## 4. `ptw_mbuf` Request 选择、ID 生成与 Grant Hold

### 4.1 原版请求逻辑

原版 `ptw_mbuf` 没有 LSU grant 输入，也没有 request ID。请求 valid 只由 entry 状态和 abort 状态组合生成：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
assign mmu_lsu_data_req =
    (|(mbuf_entry_vld[MBUF_ENTRY_NUM-1:0]
       & (~mbuf_entry_get[MBUF_ENTRY_NUM-1:0])
       & (~mbuf_entry_bus_err_flop[MBUF_ENTRY_NUM-1:0])))
    & !(mmu_lsu_data_req_fst_time & tlboper_ptw_abort)
    | tlboper_ptw_abort_reg;
```

原版 request pointer 依赖 LSU data valid 推进：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
assign req_on_ptr[MBUF_ENTRY_NUM-1] =
    mbuf_entry_vld[MBUF_ENTRY_NUM-1]
    & (~mbuf_entry_get[MBUF_ENTRY_NUM-1])
    & (~mbuf_entry_bus_err_flop[MBUF_ENTRY_NUM-1]);

always@(posedge mbuf_clk or negedge cpurst_b)
begin
     if (!cpurst_b)
        req_ptr[MBUF_ENTRY_NUM-2:0] <= {{(MBUF_ENTRY_NUM-2){1'b0}}, 1'b1};
    else if((mmu_lsu_data_req_fst_time | lsu_mmu_data_vld) & tlboper_ptw_abort
            | tlboper_ptw_abort_reg & lsu_mmu_data_vld)
        req_ptr[MBUF_ENTRY_NUM-2:0] <= create_ptr[MBUF_ENTRY_NUM-2:0];
    else if (lsu_mmu_data_vld & (~req_on_ptr[MBUF_ENTRY_NUM-1]))
        req_ptr[MBUF_ENTRY_NUM-2:0] <= {req_ptr[MBUF_ENTRY_NUM-3:0],
                                        req_ptr[MBUF_ENTRY_NUM-2]};
end
```

原版问题：

1. `req_on_ptr` 没有排除 `mbuf_entry_on`，同一个 entry 在 response 回来前可能再次参与 request 选择。
2. 请求推进依赖 `lsu_mmu_data_vld`，不适合 LSU 多 outstanding 或 request/response 解耦。
3. 没有 LSU grant，PTW 无法知道 LSU 是否真正接收了 request。
4. 没有 request hold，若 req 拉高但 LSU 未接收，后续更高优先级 entry 变化可能导致 addr/id 跳变。

### 4.2 修改后新增参数与端口

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
parameter MBUF_ID_WIDTH = 4

input  logic [MBUF_ID_WIDTH-1:0]    lsu_mmu_data_id,
// LSU 对 PTW load 请求的接收确认。
// 只有 mmu_lsu_data_req 和 lsu_mmu_data_req_grant 同拍为 1 时，
// 这笔页表项读取请求才算真正进入 LSU outstanding 队列。
input  logic                        lsu_mmu_data_req_grant,

output logic [MBUF_ID_WIDTH-1:0]    mmu_lsu_data_req_id,
```

### 4.3 修改后 pending 条件

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign mbuf_req_pending[MBUF_ENTRY_NUM-1:0] =
      mbuf_entry_vld[MBUF_ENTRY_NUM-1:0]
    & (~mbuf_entry_on[MBUF_ENTRY_NUM-1:0])
    & (~mbuf_entry_get[MBUF_ENTRY_NUM-1:0])
    & (~mbuf_entry_bus_err_flop[MBUF_ENTRY_NUM-1:0]);
```

修改原因：

1. `vld=1` 表示 entry 内有 TWU 发来的有效页表项读取任务。
2. `on=0` 表示该 entry 当前没有已经被 LSU grant 接收但尚未返回的请求。
3. `get=0` 表示没有已经收到但还没写回 TWU 的 data。
4. `bus_err_flop=0` 表示没有已经收到但还没上报的 bus error。

最关键的是排除 `mbuf_entry_on`。如果不排除，同一 entry 可以在上一笔 response 回来前再次发 request，而 request ID 又等于 entry index，会导致同一个 ID 对应多笔 LSU outstanding，response 无法唯一回到 entry。

### 4.4 修改后 request 选择

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
always_comb begin
    req_sel_ptr[MBUF_ENTRY_NUM-1:0] = {MBUF_ENTRY_NUM{1'b0}};
    if(mbuf_req_pending[MBUF_ENTRY_NUM-1]) begin
        req_sel_ptr[MBUF_ENTRY_NUM-1] = 1'b1;
    end else begin
        for(int req_i = 0; req_i < MBUF_ENTRY_NUM-1; req_i = req_i + 1) begin
            if(mbuf_req_pending[req_i] && !(|req_sel_ptr[MBUF_ENTRY_NUM-2:0]))
                req_sel_ptr[req_i] = 1'b1;
        end
    end
end
```

行为说明：

1. `entry[MBUF_ENTRY_NUM-1]` 是 legacy ITLB 优先 entry，保持最高优先级。
2. 其它 entry 使用低 index 优先的固定优先级。
3. 该选择只是候选选择；真正送到 LSU 的 entry 还会经过 `req_hold_ptr` 保持。

### 4.5 修改后 request hold

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign req_on_ptr[MBUF_ENTRY_NUM-1:0] = req_hold_vld
                                      ? req_hold_ptr[MBUF_ENTRY_NUM-1:0]
                                      : req_sel_ptr[MBUF_ENTRY_NUM-1:0];

assign mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0] =
    req_on_ptr[MBUF_ENTRY_NUM-1:0] & {MBUF_ENTRY_NUM{!ptw_abort_drain}};

assign mbuf_ptr[MBUF_ENTRY_NUM-1:0] = mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];
assign mmu_lsu_data_req = |mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];

assign lsu_req_fire = mmu_lsu_data_req & lsu_mmu_data_req_grant;

always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b) begin
        req_hold_vld <= 1'b0;
        req_hold_ptr[MBUF_ENTRY_NUM-1:0] <= {MBUF_ENTRY_NUM{1'b0}};
    end else if(ptw_abort_drain | lsu_req_fire) begin
        req_hold_vld <= 1'b0;
        req_hold_ptr[MBUF_ENTRY_NUM-1:0] <= {MBUF_ENTRY_NUM{1'b0}};
    end else if(mmu_lsu_data_req & (!req_hold_vld)) begin
        req_hold_vld <= 1'b1;
        req_hold_ptr[MBUF_ENTRY_NUM-1:0] <= mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];
    end
end
```

修改原因：

1. `mmu_lsu_data_req` 是 valid，不表示 LSU 已接收。
2. 如果 `grant=0`，本拍选择的 entry 必须被锁住。
3. 锁住后，`mmu_lsu_data_req_addr` 和 `mmu_lsu_data_req_id` 都来自同一个 `req_hold_ptr`。
4. grant 到来前，即使其它 entry 状态变化，当前 LSU request 的 addr/id 也不跳变。
5. `lsu_req_fire` 后清 hold，下一拍才允许选择新 entry。
6. abort/drain 时清 hold，表示未被 LSU grant 接收的 request 被取消，不进入 outstanding。

### 4.6 修改后 request ID 生成

原版只输出 addr：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
always_comb begin
    mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
    for(int i = 0; i < MBUF_ENTRY_NUM; i = i + 1) begin
        if(mmu_lsu_data_req_ptr[i])begin
            mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[i];
        end
    end
end
```

修改后同时输出 addr 和 id：

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
always_comb begin
    mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = {PADDR_WIDTH{1'b0}};
    mmu_lsu_data_req_id[MBUF_ID_WIDTH-1:0] = {MBUF_ID_WIDTH{1'b0}};
    for(int i = 0; i < MBUF_ENTRY_NUM; i = i + 1) begin
        if(mmu_lsu_data_req_ptr[i])begin
            mmu_lsu_data_req_addr[PADDR_WIDTH-1:0] = mbuf_entry_padder[i];
            // request id 直接使用 entry index。LSU 返回时必须带回同一个 id。
            // response 路由不在 entry 内做比较，而是在本模块上方直接把 id
            // 解码成 per-entry valid/error。
            mmu_lsu_data_req_id[MBUF_ID_WIDTH-1:0] = MBUF_ID_WIDTH'(i);
        end
    end
end
```

### 4.7 修改后 per-entry grant

原版内部生成的 `mmu_lsu_data_req_grant[entry]` 没有来自 LSU 的真实 grant：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
assign mmu_lsu_data_req_grant[MBUF_ENTRY_NUM-1:0] =
    {MBUF_ENTRY_NUM{mmu_lsu_data_req & (!tlboper_ptw_abort)}}
    & mbuf_ptr_one[MBUF_ENTRY_NUM-1:0];
```

修改后 per-entry grant 只在全局 req/grant fire 时产生：

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign mbuf_entry_req_grant[MBUF_ENTRY_NUM-1:0] =
    {MBUF_ENTRY_NUM{lsu_req_fire}}
    & mmu_lsu_data_req_ptr[MBUF_ENTRY_NUM-1:0];
```

行为说明：

1. `mbuf_entry_req_grant[i]` 是 onehot pulse。
2. 只有当前发 LSU request 的 entry 会看到 grant。
3. 该 pulse 送入 `mbuf_entry` 后置 `on`。
4. 未被 LSU grant 的 request 不会置 `on`，也不计入 outstanding。

## 5. Response ID 解码与 `mbuf_entry` 状态更新

### 5.1 原版 response 行为

原版每个 `mbuf_entry` 都直接观察全局 LSU response：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/mbuf_entry.sv
always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_on <= 1'b0;
    else if(mbuf_all_clr)
        mbuf_on <= 1'b0;
    else if(lsu_mmu_data_vld | lsu_mmu_bus_error)
        mbuf_on <= 1'b0;
    else if(mmu_lsu_data_req_grant)
        mbuf_on <= 1'b1;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_get <= 1'b0;
    else if(mbuf_all_clr | mbuf_entry_upd)
        mbuf_get <= 1'b0;
    else if(mbuf_on & lsu_mmu_data_vld & (!lsu_mmu_bus_error) & (!write_back_grant))
        mbuf_get <= 1'b1;
    else if(write_back_grant)
        mbuf_get <= 1'b0;
end
```

原版风险：

1. 任意 LSU data valid 都会让所有 `mbuf_on` entry 尝试清 `on`。
2. 任意 LSU data valid 都可能被多个 entry 当成自己的 data。
3. 任意 bus error 都可能被多个 entry 记录。
4. Abort 直接清 `on`，会丢失 LSU outstanding 记录。

### 5.2 修改后 `ptw_mbuf` 统一解码 response ID

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign lsu_mmu_resp_entry_dec[MBUF_ENTRY_NUM-1:0] =
    {{(MBUF_ENTRY_NUM-1){1'b0}}, 1'b1}
    << lsu_mmu_data_id[MBUF_ID_WIDTH-1:0];

assign lsu_mmu_data_vld_entry[MBUF_ENTRY_NUM-1:0] =
    {MBUF_ENTRY_NUM{lsu_mmu_data_vld}}
    & lsu_mmu_resp_entry_dec[MBUF_ENTRY_NUM-1:0];

assign lsu_mmu_bus_error_entry[MBUF_ENTRY_NUM-1:0] =
    {MBUF_ENTRY_NUM{lsu_mmu_bus_error}}
    & lsu_mmu_resp_entry_dec[MBUF_ENTRY_NUM-1:0];
```

解释：

1. `lsu_mmu_data_id == i` 时，只拉高 entry `i` 的 data valid 或 bus error。
2. 如果 LSU 错误返回 9..15 这类非法 ID，左移结果会移出 9-bit 向量，所有 entry valid/error 为 0，不会误写 entry。
3. 解码集中在 `ptw_mbuf`，`mbuf_entry` 不再做 ID 比较。

### 5.3 修改后 entry 实例连接

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
.lsu_mmu_data_vld        (lsu_mmu_data_vld_entry[MBUF_ent]),
.lsu_mmu_data            (lsu_mmu_data[DATA_WIDTH-1:0]),
.mmu_lsu_data_req_grant  (mbuf_entry_req_grant[MBUF_ent]),
.lsu_mmu_bus_error       (lsu_mmu_bus_error_entry[MBUF_ent]),
```

### 5.4 修改后 `mbuf_entry` 内部 response 信号

```systemverilog
// mmu_new/rtl/mbuf_entry.sv
logic                   lsu_mmu_resp_vld ;
logic                   lsu_mmu_data_routed;
logic                   lsu_mmu_err_routed ;

assign lsu_mmu_resp_vld    = lsu_mmu_data_vld | lsu_mmu_bus_error;
assign lsu_mmu_data_routed = lsu_mmu_data_vld & (!lsu_mmu_bus_error);
assign lsu_mmu_err_routed  = lsu_mmu_bus_error;
```

这里的 `lsu_mmu_data_vld` 和 `lsu_mmu_bus_error` 已经不是全局 response，而是 `ptw_mbuf` 解码后的 per-entry response。因此 `mbuf_entry` 只需要根据本 entry 的 routed response 更新状态。

### 5.5 修改后 `mbuf_on`

```systemverilog
// mmu_new/rtl/mbuf_entry.sv
always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_on <= 1'b0;
    // mbuf_on 表示“本 entry 已经有一笔请求被 LSU grant 接收，但 response 还
    // 没有回来”。abort 不能直接清 mbuf_on，否则 MMU 会丢失这笔已发出请求
    // 的 outstanding 记录；必须等 ptw_mbuf 按 LSU response id 解码后，把
    // response valid/error 直接送到本 entry，再由本 entry 清 on。
    else if(mbuf_on & lsu_mmu_resp_vld)
        mbuf_on <= 1'b0;
    // 只有 PTW/MBUF 侧的 req 和 LSU 的 grant 同时成立时，才认为请求真正发
    // 出。未 grant 的请求即使 mmu_lsu_data_req 曾经拉高，也不能置 mbuf_on。
    else if((!mbuf_all_clr) & mmu_lsu_data_req_grant)
        mbuf_on <= 1'b1;
end
```

关键变化：

1. 删除 abort 直接清 `on` 的行为。
2. `on` 只在本 entry 对应 response 回来后清零。
3. `on` 只在本 entry 对应 `req && grant` fire 后置位。

### 5.6 修改后 data 缓存与 bus error 缓存

```systemverilog
// mmu_new/rtl/mbuf_entry.sv
always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_get <= 1'b0;
    else if(mbuf_all_clr | mbuf_entry_upd)
        mbuf_get <= 1'b0;
    else if(mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
        mbuf_get <= 1'b1;
    else if(write_back_grant)
        mbuf_get <= 1'b0;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_bus_err_flop <= 1'b0;
    else if(mbuf_all_clr | mbuf_entry_upd)
        mbuf_bus_err_flop <= 1'b0;
    else if(mbuf_on & lsu_mmu_err_routed & (!mbuf_bus_error_grant))
        mbuf_bus_err_flop <= 1'b1;
    else if(mbuf_bus_error_grant)
        mbuf_bus_err_flop <= 1'b0;
end

always_ff @(posedge mbuf_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        mbuf_lsu_data[63:0] <= 64'b0;
    else if((!mbuf_all_clr) & mbuf_on & lsu_mmu_data_routed & (!write_back_grant))
        mbuf_lsu_data[63:0] <= lsu_mmu_data[63:0];
end
```

修改原因：

1. Data 和 bus error 都必须是本 entry 的 routed response 才能记录。
2. Abort 清 `vld/get/bus_err_flop` 后，后续 drain response 只用于清 `on`，不能再缓存 data 或上报 TWU。
3. `mbuf_lsu_data` 增加 `!mbuf_all_clr` 条件，避免 abort 当拍写入无效 data。

### 5.7 修改后 write-back request

原版：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/mbuf_entry.sv
assign write_back_req =
    mbuf_vld
    & (|(twu_data_ready[idx][PTE_LEVEL-1:0] & mbuf_lvl[PTE_LEVEL-1:0]))
    & (mbuf_on & lsu_mmu_data_vld & (!lsu_mmu_bus_error) | mbuf_get);

assign bus_err_write_back_req =
    mbuf_vld
    & (mbuf_on & lsu_mmu_bus_error | mbuf_bus_err_flop)
    & (!mbuf_entry_bus_err_req_mask);
```

修改后：

```systemverilog
// mmu_new/rtl/mbuf_entry.sv
assign write_back_req = mbuf_vld
                      & (!mbuf_all_clr)
                      & (|(twu_data_ready[idx][PTE_LEVEL-1:0] & mbuf_lvl[PTE_LEVEL-1:0]))
                      & ((mbuf_on & lsu_mmu_data_routed) | mbuf_get);

assign bus_err_write_back_req = mbuf_vld
                              & (!mbuf_all_clr)
                              & ((mbuf_on & lsu_mmu_err_routed) | mbuf_bus_err_flop)
                              & (!mbuf_entry_bus_err_req_mask);
```

修改原因：

1. 只有本 entry 的 routed response 才能触发 write back。
2. Abort 当拍 `mbuf_all_clr=1`，禁止继续向 TWU write back。
3. Drain 期间 entry `vld` 已经被 abort 清掉，因此后续 response 不会再进入 TWU/PDE cache 写回路径。

## 6. Abort / Drain 语义

### 6.1 原版 abort 行为

原版 `ptw_mbuf` abort drain 依赖 `lsu_mmu_data_vld` 单笔返回语义：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    tlboper_ptw_abort_reg <= 1'b0;
  else if(tlboper_ptw_abort & (!mmu_lsu_data_req_fst_time)
          & (!lsu_mmu_data_vld) & mbuf_entry_on_vld)
    tlboper_ptw_abort_reg <= 1'b1;
  else if(lsu_mmu_data_vld)
    tlboper_ptw_abort_reg <= 1'b0;
end
```

原版 `mbuf_entry` abort 直接清 `on`：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/mbuf_entry.sv
else if(mbuf_all_clr)
    mbuf_on <= 1'b0;
```

原版问题：

1. 多 outstanding 下，看到第一笔 LSU data valid 就退出 abort drain 是错误的。
2. 仍可能有其它 entry `on=1`，它们的 response 尚未回来。
3. 直接清 `on` 会丢失 outstanding 记录，后续 response 无法被准确 drain。

### 6.2 修改后 abort/drain 拆分

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign mbuf_all_clr = tlboper_ptw_abort;
assign ptw_abort_drain = tlboper_ptw_abort | tlboper_ptw_abort_reg;
```

语义：

1. `mbuf_all_clr` 是 abort 当拍单周期脉冲，只负责清 entry `vld/get/bus_err_flop`。
2. `ptw_abort_drain` 是内部 drain 状态，包括 abort 当拍和 abort 后等待 outstanding response 的所有周期。
3. `ptw_abort_drain` 期间禁止创建新 entry、禁止发新 LSU request、禁止 PDE cache 更新。
4. `ptw_abort_drain` 不直接清 `on`。

### 6.3 修改后 drain 状态寄存

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    tlboper_ptw_abort_reg <= 1'b0;
  // abort 当拍如果已经存在 outstanding entry.on，则进入 drain 状态。
  // 未 grant 的 hold/request 会在上面的 req_hold 逻辑里被取消，不会置 on。
  else if(tlboper_ptw_abort & mbuf_entry_on_vld)
    tlboper_ptw_abort_reg <= 1'b1;
  // drain 状态必须等所有 entry.on 都被 LSU response 按 ID 清掉后才能退出。
  // 不能因为看到第一笔 lsu_mmu_data_vld 就清 abort_reg，否则多 outstanding
  // 请求场景会丢失后续 response 的跟踪。
  else if(tlboper_ptw_abort_reg & (!mbuf_entry_on_vld))
    tlboper_ptw_abort_reg <= 1'b0;
end
```

### 6.4 修改后创建和 grant 屏蔽

原版创建条件只看 `tlboper_ptw_abort` 当拍：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
assign create_en = |twu_mbuf_req[3:0] & (!twu_itlb_sel) & (!tlboper_ptw_abort);
assign mbuf_entry_upd[MBUF_ENTRY_NUM-1] = twu_itlb_sel & (!tlboper_ptw_abort);
```

修改后在整个 drain 期间都屏蔽：

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign mbuf_grant[3:0] = mbuf_grant_raw[3:0] & {4{!ptw_abort_drain}};
assign create_en = |mbuf_grant[3:0] & (!twu_itlb_sel);
assign mbuf_entry_upd[MBUF_ENTRY_NUM-1] = twu_itlb_sel & (!ptw_abort_drain);
```

### 6.5 修改后 PTW top ready drain

原版 `ptw.sv` 的 abort ready 语义也依赖一笔 LSU response：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw.sv
else if(mbuf_entry_on_vld & tlboper_ptw_abort & !(lsu_mmu_bus_error | lsu_mmu_data_vld))
    abort_flop <= 1'b1;
else if(abort_flop & (lsu_mmu_bus_error | lsu_mmu_data_vld))
    abort_flop <= 1'b0;
```

修改后等待所有 entry `on` 清零：

```systemverilog
// mmu_new/rtl/ptw.sv
else if(mbuf_entry_on_vld & tlboper_ptw_abort)
    abort_flop <= 1'b1;
else if(abort_flop & (!mbuf_entry_on_vld))
    abort_flop <= 1'b0;
```

解释：

1. `ptw_jtlb_ready = pde_cache_ready & (!abort_flop)`。
2. Abort drain 期间不能接受新的 JTLB/PTW 请求。
3. 多 outstanding 下，必须等所有 entry `on` 被 ID response 清掉。

## 7. PDE Cache Update、L1/L2 Entry 与 PLRU 连续更新修复

### 7.1 检查目标

本节覆盖 `mbuf_cache_upd -> PDE_cache -> L1PDE_cache/L2PDE_cache -> pplru` 更新路径，重点检查连续两拍 PDE cache update 时：

1. valid/data 是否被覆盖或丢失。
2. 写使能是否每拍都能生效。
3. replacement way 是否稳定并与本拍 data 同步。
4. PLRU 是否每次 update 都推进。
5. L1/L2 两级 cache 是否存在互斥或门控问题。

### 7.2 `ptw_mbuf` 产生 `mbuf_cache_upd`

原版只屏蔽 abort 当拍：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw_mbuf.sv
always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        pde_updata_data_vld <= 1'b0;
    else if(|write_back_grant[MBUF_ENTRY_NUM-1:0] & (!tlboper_ptw_abort))
        pde_updata_data_vld <= 1'b1;
    else
        pde_updata_data_vld <= 1'b0;
end
```

修改后屏蔽完整 abort drain：

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        pde_updata_data_vld <= 1'b0;
    // 只有非 abort/drain 状态下、且 entry 正常 write back 给 TWU 的 data，才
    // 允许进入 PDE cache refill 判断。abort 当拍 entry.vld 已经被清掉，drain
    // 期间后续 LSU response 只用于清 entry.on，不能污染 PDE cache。
    else if(|write_back_grant[MBUF_ENTRY_NUM-1:0] & (!ptw_abort_drain))
        pde_updata_data_vld <= 1'b1;
    else
        pde_updata_data_vld <= 1'b0;
end
```

数据寄存：

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b) begin
        pde_updata_data_flop[DATA_WIDTH-1:0] <= {DATA_WIDTH{1'b0}};
        pde_updata_vpn[VPN_WIDTH-1:0] <= {VPN_WIDTH{1'b0}};
        pde_updata_lvl[PTE_LEVEL-1:0] <= {PTE_LEVEL{1'b0}};
        pde_updata_l1pmpflg[3:0] <= 4'b0;
        pde_updata_l2pmpflg[3:0] <= 4'b0;
    end else if(|write_back_grant[MBUF_ENTRY_NUM-1:0]) begin
        pde_updata_data_flop[DATA_WIDTH-1:0] <= mbuf_twu_data[DATA_WIDTH-1:0];
        pde_updata_vpn[VPN_WIDTH-1:0] <= mbuf_twu_vpn[VPN_WIDTH-1:0];
        pde_updata_lvl[PTE_LEVEL-1:0] <= mbuf_twu_lvl[PTE_LEVEL-1:0];
        pde_updata_l1pmpflg[3:0] <= mbuf_twu_pmpflg[3:0];
        pde_updata_l2pmpflg[3:0] <= mbuf_twu_pmpflg[7:4];
    end
end
```

`mbuf_cache_upd` 判断：

```systemverilog
// mmu_new/rtl/ptw_mbuf.sv
assign mbuf_cache_upd = pde_updata_data_vld
                      & pde_updata_data_flop[0]                    // V = 1
                      & (!(pde_updata_data_flop[1] | pde_updata_data_flop[3]
                           | pde_updata_data_flop[2] | pde_updata_lvl[0]));

assign mbuf_cache_upd_ppn[PPN_WIDTH-1:0] = pde_updata_data_flop[PPN_WIDTH+9:10];
assign mbuf_cache_upd_lvl[PTE_LEVEL-2:0] = pde_updata_lvl[PTE_LEVEL-1:1];
assign mbuf_cache_upd_vpn[VPN_WIDTH-1:0] = pde_updata_vpn[VPN_WIDTH-1:0];
assign mbuf_cache_upd_l1pmpflg[3:0] = pde_updata_l1pmpflg[3:0];
assign mbuf_cache_upd_l2pmpflg[3:0] = pde_updata_l2pmpflg[3:0];
```

连续更新分析：

1. `write_back_grant` 连续两拍有效时，`pde_updata_data_vld` 连续两拍有效。
2. `pde_updata_data_flop/vpn/lvl/pmpflg` 每拍随 `write_back_grant` 更新。
3. 因此 `mbuf_cache_upd*` 可以连续输出不同 data/vpn/lvl。
4. Abort drain 期间 `pde_updata_data_vld` 被屏蔽，所以 drain response 不会进入 PDE cache。

### 7.3 L1/L2 选择与互斥

`twu_mbuf_lvl` 是 `{fst, scd, thd}` onehot。`ptw_mbuf` 输出给 PDE cache 的 level 为：

```systemverilog
assign mbuf_cache_upd_lvl[PTE_LEVEL-2:0] = pde_updata_lvl[PTE_LEVEL-1:1];
```

当 `PTE_LEVEL=3`：

```text
pde_updata_lvl[2] = first level PDE  -> mbuf_cache_upd_lvl[1] -> L1PDE
pde_updata_lvl[1] = second level PDE -> mbuf_cache_upd_lvl[0] -> L2PDE
pde_updata_lvl[0] = third level PTE  -> 被 mbuf_cache_upd 条件排除
```

`PDE_cache.sv` 中 L1/L2 refill valid：

```systemverilog
// mmu_new/rtl/PDE_cache.sv
assign L1PDE_plru_refill_vld =
    (mbuf_cache_upd
     & mbuf_cache_upd_lvl[1]
     & (!(|L1PDE_entry_before_upd_hit[L1PDE_ENTRY_NUM-1:0])));

assign L2PDE_plru_refill_vld =
    (mbuf_cache_upd
     & mbuf_cache_upd_lvl[0]
     & (!(|L2PDE_entry_before_upd_hit[L2PDE_ENTRY_NUM-1:0])));
```

结论：

1. 正常 onehot level 下，单笔 update 不会同时写 L1 和 L2。
2. 第三级 PTE 不会作为 PDE cache refill。
3. `entry_before_upd_hit` 命中时不会 refill 新 way，避免同一个 PDE tag 产生重复 entry。
4. 如果同 tag 后续数据变化，当前设计依赖 TLB/cache clear 类操作失效旧 entry，而不是在 cache hit 时覆盖旧 entry。这是原有设计语义，本次保持不变。

### 7.4 L1/L2 entry 写入逻辑

L1 entry 原版与修改后逻辑一致：

```systemverilog
// mmu_new/rtl/L1PDE_cache.sv
assign L1PDE_entry_clk_en = regs_ptw_clr | L1PDE_entry_upd;

always @(posedge L1PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        L1PDE_vld <= 1'b0;
    else if(regs_ptw_clr)
        L1PDE_vld <= 1'b0;
    else if(L1PDE_entry_upd)
        L1PDE_vld <= 1'b1;
end

always @(posedge L1PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
        L1PDE_tag[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
        L1PDE_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
        L1PDE_l1pmpflg[3:0] <= 4'b0;
    end else if(L1PDE_entry_upd)begin
        L1PDE_tag[TAG_WIDTH-1:0] <= L1PDE_upd_vpn[TAG_WIDTH-1:0];
        L1PDE_ppn[PPN_WIDTH-1:0] <= L1PDE_upd_ppn[PPN_WIDTH-1:0];
        L1PDE_l1pmpflg[3:0] <= L1PDE_upd_l1pmpflg[3:0];
    end
end
```

L2 entry 原版与修改后逻辑一致：

```systemverilog
// mmu_new/rtl/L2PDE_cache.sv
assign L2PDE_entry_clk_en = regs_ptw_clr | L2PDE_entry_upd;

always @(posedge L2PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)
        L2PDE_vld <= 1'b0;
    else if(regs_ptw_clr)
        L2PDE_vld <= 1'b0;
    else if(L2PDE_entry_upd)
        L2PDE_vld <= 1'b1;
end

always @(posedge L2PDE_entry_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
        L2PDE_tag[TAG_WIDTH-1:0] <= {TAG_WIDTH{1'b0}};
        L2PDE_ppn[PPN_WIDTH-1:0] <= {PPN_WIDTH{1'b0}};
        L2PDE_l1pmpflg[3:0] <= 4'b0;
        L2PDE_l2pmpflg[3:0] <= 4'b0;
    end else if(L2PDE_entry_upd)begin
        L2PDE_tag[TAG_WIDTH-1:0] <= L2PDE_upd_vpn[TAG_WIDTH-1:0];
        L2PDE_ppn[PPN_WIDTH-1:0] <= L2PDE_upd_ppn[PPN_WIDTH-1:0];
        L2PDE_l1pmpflg[3:0] <= L2PDE_upd_l1pmpflg[3:0];
        L2PDE_l2pmpflg[3:0] <= L2PDE_upd_l2pmpflg[3:0];
    end
end
```

连续更新分析：

1. `LxPDE_entry_upd` 每拍有效时，对应 entry clock enable 每拍有效。
2. tag、ppn、pmp flags 与 valid 在同一 entry update pulse 写入。
3. L1/L2 entry 本身没有“必须隔拍写”的限制。
4. 连续更新是否正确，取决于 `PDE_cache` 给出的 `LxPDE_entry_upd` onehot 是否每拍对应正确 way。

### 7.5 PDE cache 到 PLRU 的原版连接

这段逻辑原版与修改后保持一致：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/PDE_cache.sv
assign L1PDE_entry_upd[L1PDE_ENTRY_NUM-1:0] =
    plru_L1PDE_ref_num[L1PDE_ENTRY_NUM-1:0]
    & {L1PDE_ENTRY_NUM{L1PDE_plru_refill_vld}};

assign L2PDE_entry_upd[L2PDE_ENTRY_NUM-1:0] =
    plru_L2PDE_ref_num[L2PDE_ENTRY_NUM-1:0]
    & {L2PDE_ENTRY_NUM{L2PDE_plru_refill_vld}};
```

这说明 `PDE_cache` 直接把 `pplru` 输出的 `plru_PDE_ref_num` 和本拍 refill valid 相与，作为本拍 entry 写使能。因此 `pplru` 输出的 replacement onehot 必须是本拍有效的 way，不能是上一拍 way。

### 7.6 原版 `pplru` 问题代码

原版 `pplru` 中，`write_num` 是本拍根据 valid entry 和 PLRU bits 选出的候选 way，但随后被打一拍到 `refill_num_index`：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/pplru.sv
logic [PDE_INDEX_WIDTH-1:0]       write_num;
logic [PDE_INDEX_WIDTH-1:0]       refill_num_index;

always_comb begin
    write_num[PDE_INDEX_WIDTH-1:0] = plru_num[PDE_INDEX_WIDTH-1:0];
    invalid_entry_found = 1'b0;

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if((!invalid_entry_found) && (!vld_entry_num[i])) begin
            write_num[PDE_INDEX_WIDTH-1:0] = i;
            invalid_entry_found = 1'b1;
        end
    end
end

always_ff @(posedge lru_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        refill_num_index[PDE_INDEX_WIDTH-1:0] <= {PDE_INDEX_WIDTH{1'b0}};
    else
        refill_num_index[PDE_INDEX_WIDTH-1:0] <= write_num[PDE_INDEX_WIDTH-1:0];
end

always_comb begin
    refill_num_onehot[PDE_ENTRY_NUM-1:0] = {PDE_ENTRY_NUM{1'b0}};

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if(refill_num_index[PDE_INDEX_WIDTH-1:0] == i)
            refill_num_onehot[i] = 1'b1;
    end
end

assign plru_PDE_ref_num[PDE_ENTRY_NUM-1:0] =
    refill_num_onehot[PDE_ENTRY_NUM-1:0];
```

原版 PLRU bits 更新也使用上一拍的 `refill_num_index`：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/pplru.sv
if(plru_write_updt) begin
    for(int level = 0; level < PDE_INDEX_WIDTH; level = level + 1) begin
        plru_bits_next[node] = !refill_num_index[PDE_INDEX_WIDTH-1-level];

        if(refill_num_index[PDE_INDEX_WIDTH-1-level])
            node = (node << 1) + 2;
        else
            node = (node << 1) + 1;
    end
end
```

### 7.7 原版连续更新错误场景

假设 `PDE_ENTRY_NUM=4`，初始所有 entry invalid，`mbuf_cache_upd` 连续两拍有效：

| 周期 | entry valid before edge | 本拍 `write_num` | 原版 `plru_PDE_ref_num` | 实际写入 |
| --- | --- | --- | --- | --- |
| cycle 0 | `0000` | way0 | way0 | data0 -> way0 |
| cycle 1 | `0001` | way1 | way0 | data1 -> way0，覆盖 data0 |
| cycle 2 | `0001` 或 `000?` | way1/way2 | way1 | 后续写入继续滞后 |

问题本质：

1. `PDE_cache` 同拍使用 `plru_PDE_ref_num` 作为 entry 写使能。
2. 原版 `plru_PDE_ref_num` 来自上一拍 `refill_num_index`。
3. 连续 update 时，本拍 data/vpn/ppn 已经是新数据，但写入 way 仍是上一拍 way。
4. PLRU bits 也按上一拍 way 推进，无法反映本拍真实写入位置。

### 7.8 修改后 `pplru` 代码

删除 `refill_num_index`，`plru_PDE_ref_num` 直接由本拍 `write_num` 组合生成：

```systemverilog
// mmu_new/rtl/pplru.sv
logic [PDE_INDEX_WIDTH-1:0]       write_num;

always_comb begin
    write_num[PDE_INDEX_WIDTH-1:0] = plru_num[PDE_INDEX_WIDTH-1:0];
    invalid_entry_found = 1'b0;

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if((!invalid_entry_found) && (!vld_entry_num[i])) begin
            write_num[PDE_INDEX_WIDTH-1:0] = i;
            invalid_entry_found = 1'b1;
        end
    end

    if((!invalid_entry_found) && (plru_num[PDE_INDEX_WIDTH-1:0] >= PDE_ENTRY_NUM))
        write_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
end

// refill 选路必须和 PDE entry 写使能同拍输出。若先打一拍再输出，
// 连续两拍 PDE_plru_refill_vld 会用上一拍 way 写 entry，导致第二笔覆盖第一笔。
always_comb begin
    refill_num_onehot[PDE_ENTRY_NUM-1:0] = {PDE_ENTRY_NUM{1'b0}};

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if(write_num[PDE_INDEX_WIDTH-1:0] == i)
            refill_num_onehot[i] = 1'b1;
    end
end

assign plru_PDE_ref_num[PDE_ENTRY_NUM-1:0] =
    refill_num_onehot[PDE_ENTRY_NUM-1:0];
```

PLRU bits 更新也改为使用本拍 `write_num`：

```systemverilog
// mmu_new/rtl/pplru.sv
if(plru_write_updt) begin

    // PLRU 推进使用和本拍 entry 写入完全相同的 write_num，
    // 保证连续 refill 时每一拍都按实际写入 way 更新替换树。
    for(int level = 0; level < PDE_INDEX_WIDTH; level = level + 1) begin
        plru_bits_next[node] = !write_num[PDE_INDEX_WIDTH-1-level];

        if(write_num[PDE_INDEX_WIDTH-1-level])
            node = (node << 1) + 2;
        else
            node = (node << 1) + 1;
    end
end
```

### 7.9 修改后连续更新行为

仍以 `PDE_ENTRY_NUM=4`、初始全 invalid、连续 refill 为例：

| 周期 | entry valid before edge | 本拍 `write_num` | 修改后 `plru_PDE_ref_num` | 实际写入 |
| --- | --- | --- | --- | --- |
| cycle 0 | `0000` | way0 | way0 | data0 -> way0 |
| cycle 1 | `0001` | way1 | way1 | data1 -> way1 |
| cycle 2 | `0011` | way2 | way2 | data2 -> way2 |
| cycle 3 | `0111` | way3 | way3 | data3 -> way3 |
| cycle 4 | `1111` | PLRU way | same PLRU way | replacement data -> selected way |

修复后满足：

1. Entry 写使能和本拍 update data/vpn/ppn 同步。
2. 连续两拍 update 不会复用上一拍 way。
3. PLRU 每次 refill 都按实际写入 way 推进。
4. cache 未满时优先填 invalid entry。
5. cache 满后使用 PLRU replacement way。

## 8. Debug Trace 更新

`ptw.sv` 中原有 PTW->LSU request trace 只打印 addr/size。修改后加入 id/grant，便于检查 grant 前 addr/id 是否稳定。

原版：

```systemverilog
// C910_RTL_FACTORY/gen_rtl/idu/mmu/rtl/ptw.sv
if(mmu_lsu_data_req
   && (!ptw_lsu_req_dbg_q || (mmu_lsu_data_req_addr != ptw_lsu_addr_dbg_q))) begin
    $display("[%0t][PTW LSU REQ] addr=0x%010h size=%0b satp_base=0x%07h",
             $time, mmu_lsu_data_req_addr, mmu_lsu_data_req_size, regs_ptw_satp_ppn);
end
```

修改后：

```systemverilog
// mmu_new/rtl/ptw.sv
logic [PADDR_WIDTH-1:0] ptw_lsu_addr_dbg_q;
logic [MBUF_ID_WIDTH-1:0] ptw_lsu_id_dbg_q;

if(mmu_lsu_data_req
   && (!ptw_lsu_req_dbg_q
       || (mmu_lsu_data_req_addr != ptw_lsu_addr_dbg_q)
       || (mmu_lsu_data_req_id != ptw_lsu_id_dbg_q))) begin
    $display("[%0t][PTW LSU REQ] addr=0x%010h id=0x%0h size=%0b grant=%0b satp_base=0x%07h",
             $time, mmu_lsu_data_req_addr, mmu_lsu_data_req_id, mmu_lsu_data_req_size,
             lsu_mmu_data_req_grant, regs_ptw_satp_ppn);
end

ptw_lsu_req_dbg_q <= mmu_lsu_data_req;
if(mmu_lsu_data_req) begin
    ptw_lsu_addr_dbg_q <= mmu_lsu_data_req_addr;
    ptw_lsu_id_dbg_q   <= mmu_lsu_data_req_id;
end
```

用途：

1. 检查 `grant=0` 时 req 仍为 1 的周期内 addr/id 是否保持不变。
2. 检查 `grant=1` 后下一笔 request 是否切换到新的 entry id。
3. 检查 LSU 返回 ID 与 request ID 是否能够对应到同一 entry。

## 9. 关键时序解释

### 9.1 正常 request/response 时序

```text
cycle N:
  MBUF 选中 entry i
  mmu_lsu_data_req      = 1
  mmu_lsu_data_req_id   = i
  mmu_lsu_data_req_addr = entry_i.paddr
  lsu_mmu_data_req_grant = 0
  req_hold_ptr 锁住 entry i
  entry_i.on 不置位

cycle N+1:
  mmu_lsu_data_req      = 1
  mmu_lsu_data_req_id   = i
  mmu_lsu_data_req_addr = entry_i.paddr
  lsu_mmu_data_req_grant = 1
  lsu_req_fire = 1
  entry_i.on <= 1

cycle M:
  lsu_mmu_data_vld = 1
  lsu_mmu_data_id  = i
  ptw_mbuf 解码 lsu_mmu_data_vld_entry[i] = 1
  entry_i 接收 data，entry_i.on <= 0
  其它 entry 不受影响
```

### 9.2 Abort drain 时序

```text
cycle A:
  tlboper_ptw_abort = 1
  mbuf_all_clr = 1
  所有 entry.vld 清 0
  entry.on 不清
  如果存在 entry.on=1，则 tlboper_ptw_abort_reg <= 1

cycle A+1 ... D:
  ptw_abort_drain = 1
  不创建新 MBUF entry
  不发新 LSU request
  不允许 PDE cache update
  已发出的 LSU response 继续按 ID 回来清对应 entry.on

cycle D:
  所有 entry.on 已清 0
  tlboper_ptw_abort_reg <= 0
  abort drain 结束
```

### 9.3 PDE cache 连续 update 时序

```text
cycle P:
  write_back_grant = 1
  pde_updata_* <= data0/vpn0/lvl0

cycle P+1:
  mbuf_cache_upd = 1 for data0
  pplru.write_num = way0
  LxPDE_entry_upd[way0] = 1
  entry way0 <= data0/vpn0
  PLRU 按 way0 推进
  同时 write_back_grant = 1
  pde_updata_* <= data1/vpn1/lvl1

cycle P+2:
  mbuf_cache_upd = 1 for data1
  pplru.write_num = way1 或当前 PLRU way
  LxPDE_entry_upd[way1] = 1
  entry way1 <= data1/vpn1
  PLRU 按 way1 推进
```

修复点是确保 `LxPDE_entry_upd[way]` 的 `way` 是本拍 `write_num`，不是上一拍 `refill_num_index`。

## 10. 验证结果

### 10.1 PDE cache 相关模块编译

执行命令：

```text
vlog -sv \
  mmu_new/rtl/pplru.sv \
  mmu_new/rtl/L1PDE_cache.sv \
  mmu_new/rtl/L2PDE_cache.sv \
  mmu_new/rtl/PDE_cache.sv
```

结果：

```text
Errors: 0, Warnings: 0
```

### 10.2 PPLRU 连续 refill 临时仿真

构造 4-entry `pplru` 临时 testbench，验证：

1. 初始全 invalid 时连续 refill 选择 way0、way1、way2、way3。
2. 全 valid 后连续 replacement，PLRU way 能继续推进。
3. 如果 replacement onehot 仍打一拍，第二拍会错误地再次选择 way0，testbench 会失败。

仿真结果：

```text
PPLRU consecutive refill test PASS
Errors: 0, Warnings: 0
```

临时 testbench 源文件已删除，只保留 RTL 修复。

### 10.3 核心链路编译

执行命令：

```text
vlog -sv +incdir+mmu_new/rtl \
  C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v \
  mmu_new/rtl/mbuf_entry.sv \
  mmu_new/rtl/ptw_mbuf.sv \
  mmu_new/rtl/pplru.sv \
  mmu_new/rtl/L1PDE_cache.sv \
  mmu_new/rtl/L2PDE_cache.sv \
  mmu_new/rtl/PDE_cache.sv \
  mmu_new/rtl/one_to_four_xbar.sv \
  mmu_new/rtl/twu.sv \
  mmu_new/rtl/ptw.sv \
  mmu_new/rtl/ct_mmu_top.v
```

结果：

```text
Top level modules:
    ct_mmu_top
Errors: 0, Warnings: 0
```

### 10.4 全目录编译说明

此前也执行过除 `ct_mmu_sysmap.v` 外的 `mmu_new/rtl` 目录编译：

```text
Errors: 0
Warnings: 约 32 个既有 warning
```

这些 warning 是既有 ModelSim `SVCHK` 类 warning，集中在非本次修改路径，和 PTW/MBUF ID、grant、abort drain、PDE cache/PLRU 修改无关。

`ct_mmu_sysmap.v` 未纳入全目录编译的原因是该文件依赖外部宏定义，例如 `PA_WIDTH`、`SYSMAP_FLG*`、`SYSMAP_BASE_ADDR*`。当前单独用 `vlog` 编译全目录时这些宏没有通过 include 或命令行完整传入，会触发既有宏缺失错误。

## 11. 最终行为结论

1. `mmu_lsu_data_req_id` 已从 `ct_mmu_top -> ptw -> ptw_mbuf` 完整透传。
2. `lsu_mmu_data_id` 已从 `ct_mmu_top -> ptw -> ptw_mbuf` 完整透传。
3. `lsu_mmu_data_req_grant` 已从 `ct_mmu_top -> ptw -> ptw_mbuf -> mbuf_entry` 完整进入 request fire 逻辑。
4. Request ID 直接等于 MBUF entry index。
5. LSU response ID 在 `ptw_mbuf` 中 onehot 解码，只送到对应 `mbuf_entry`。
6. `mbuf_entry` 内部不再做 response ID 比较。
7. Grant 前 request addr/id 通过 `req_hold_ptr` 保持稳定。
8. 未 grant 的 request 不置 `on`，不计入 outstanding。
9. Abort 只清 `vld/get/bus_err_flop`，不清 `on`。
10. Abort drain 等所有 outstanding `on` 被 LSU response 按 ID 清掉后退出。
11. Abort drain 期间不创建新 entry，不发新 LSU request，不更新 PDE cache。
12. `mbuf_cache_upd` 连续两拍时，`ptw_mbuf` valid/data/vpn/lvl 能连续输出。
13. L1/L2 PDE cache entry 写寄存器支持连续拍 update。
14. L1/L2 cache 由 onehot level 互斥选择，单笔 update 不会同时写两级。
15. `pplru` 已修复为本拍 `write_num` 同拍输出 replacement onehot，并用同一个 `write_num` 推进 PLRU。
16. 连续 PDE cache update 不会再因为上一拍 replacement way 导致覆盖或丢失。

