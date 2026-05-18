# PTW RTL 调试记录（ptw_rtl_debug）

本文档按**单次调试/变更**逐条记录 PTW 相关 RTL（含与之配套的 `twu.sv` 等）的修改，便于回溯与仿真对齐。

**每条记录均单独包含：**

- **记录时间**：该次变更对应的时刻（已提交的用提交时间；仅本地改动的用写入本条时的采集时间）。
- **版本号**：该次变更所对应的 Git 状态——已提交写 **commit 完整 hash（短 hash）**；未提交的写 **基准 commit +「工作区未提交」**。

---

## 调试记录 #1 — 提交 `ptw_rtl_updata`（含 PTW / MBUF / TWU 大改）

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-04 11:13:20 +0800（Git 提交时间） |
| **版本号** | `c125fa9fc3d0ab31547f575b8435898606d34a5c`（`c125fa9`） |
| **提交说明** | `ptw_rtl_updata` |
| **分支** | `main`（记录时相对 `origin/master` ahead 281 commits，以本机为准） |
| **涉及文件** | `mmu/rtl/ptw.sv`、`mmu/rtl/ptw_mbuf.sv`、`mmu/rtl/twu.sv`（统计：472 insertions, 286 deletions） |

### `ptw.sv` 要点

- 原「打拍后的 PTW 响应包」`ptw_rsp_*_q` 路径注释/移除，L2TLB / L1 侧改为组合与仲裁信号直连；旧打拍块保留在注释中备查。
- `ptw_l2tlb_id` / `ptw_l2tlb_type`：用 `always_comb` 按 `{pgflt_grant, acc_err_grant, ref_grant}` 优先级选择。
- `ptw_l2tlb_ref_data_vld`、`ref_pgflt`、`ref_acc_err`、`cmplt` 等与 `arb_ptw_grant` 等对齐，不再从 `ptw_rsp_*_q` 取数。
- 移除 PTW→LSU 的 `$display` 仿真打印 `always_ff`。

### `ptw_mbuf.sv` 要点

- MBUF 分配改为 `create_ptr` 移位 + `twu_itlb_sel` 写 `mbuf_entry_upd[8]`。
- LSU 侧改为 `req_on_ptr` / `req_ptr`；原 `point`、thermometer、priority-encode、`mbuf_ptr_nxt` 路径改为注释保留。
- `mmu_lsu_data_req_grant` 与 `mbuf_ptr_one`/`req_on_ptr` 相关；部分 TWU 端口与内部信号注释收缩。

### `twu.sv` 要点

与 PTW/MBUF 握手与数据路径配套（行级见 `git show c125fa9 -- mmu/rtl/twu.sv`）。

---

## 调试记录 #2 — 本地未提交：`ptw.sv` / `twu.sv` 信号声明补齐

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-04 11:20:33 +08:00（写入本条时采集；改动尚未 `git commit`） |
| **版本号** | 基准：`c125fa9fc3d0ab31547f575b8435898606d34a5c`（`c125fa9`）— **工作区未提交** |
| **涉及文件** | `mmu/rtl/ptw.sv`、`mmu/rtl/twu.sv` |
| **diff 规模** | `2 files changed, 3 insertions(+), 1 deletion(-)` |

### 修改摘要

- **`ptw.sv`**：为「PTW→LSU request trace」`always_ff` 块使用的寄存器补 `logic` 声明，避免隐式网或未声明信号：  
  `logic ptw_lsu_req_dbg_q;`、`logic [39:0] ptw_lsu_addr_dbg_q;`
- **`twu.sv`**：补 `logic twu_refill_vld;`（该信号在 `assign twu_arb_ref_req`、`twu_refill_idle` 及 refill 相关 `always_ff` 中已使用，此前缺少声明）。

---

## 调试记录 #3 — LSU PA 稳定性问题定位：ITLB 请求进入 PTW MBUF 后触发指针跳转

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-04 23:41:18 +08:00（写入本条时采集） |
| **版本号** | 基准：`d8ac1f92512707385517c8140c8c5ee2e65eea40`（`d8ac1f9`）— **工作区未提交** |
| **提交说明** | 无；本条为问题定位记录，记录时未对应新的 RTL 提交 |
| **分支** | `main` |
| **涉及模块** | `mmu/rtl/ptw.sv`、`mmu/rtl/ptw_mbuf.sv`、`mmu/rtl/twu.sv` |

### 问题现象

- LSU 侧请求已经发起后，其对应 `pa` 按协议应保持稳定，直到本次请求完成。
- 实际调试中观察到：当 PTW 正在服务 LSU 相关请求时，若中途插入一个 ITLB 请求进入 `ptw_mbuf`，MBUF 当前服务指针会切到 ITLB 专属 entry8。
- 指针跳转后，原本发给 LSU 的 `pa` 来源发生切换，导致 LSU 侧看到的 `pa` 不再稳定，表现为地址突变/跳变。

### 初步根因判断

- 问题本质不是 LSU 自身重新发起了新事务，而是 **PTW/MBUF 在同一未完成事务窗口内切换了取数/指针来源**。
- 若 LSU request 的 `pa` 直接或间接依赖当前 `mbuf` 指针，而不是依赖“请求发起当拍锁存下来的专属 entry / 专属 PA”，则 ITLB 新请求抢占后会把 LSU 事务的 `pa` 源头带偏。
- 该问题与 “请求已发出后，返回路径或保持路径仍继续跟随共享指针” 强相关，应重点检查：
  - `ptw_mbuf` 中 LSU request 对应的 `req_ptr` / `entry select` 是否在发起后被重新计算；
  - `ptw.sv` 中发往 LSU 的 `addr` / `pa` 是否已经在请求建立时锁存；
  - ITLB entry8 的选择优先级是否影响在途 LSU 事务的地址保持路径。

### 调试结论

- 需要保证 **LSU request 一旦建立，其 `pa`/地址来源必须与后续 ITLB/TWU 新入队动作解耦**。
- 更具体地说，后续新增的 ITLB 请求可以影响“下一拍要服务谁”，但**不能回写或改道当前已发出 LSU 请求的地址保持源**。
- 后续若修复此类问题，建议在变更记录中明确写清：
  - 是通过“锁存 LSU 专属 PA/entry”修复；
  - 还是通过“冻结 req_ptr / 发起后禁止被 ITLB entry8 抢占”修复；
  - 以及对应验证点是否覆盖 “LSU 请求进行中插入 ITLB 请求” 这一并发场景。

---

## 调试记录 #4 — `twu.sv` CSR 仲裁：`3'b001` 分支 grant 编码错误（`2'b10` → `2'b01`）

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-05 20:15:33 +08:00（写入本条时采集） |
| **版本号** | `833d737d88acd0046db7803057be638849c02d66`（`833d737`） |
| **提交说明** | 本条对应 RTL 修正：`mmu/rtl/twu.sv` CSR Arbiter；若你本地另有提交，请以当时 `git rev-parse HEAD` 为准更新版本号 |
| **涉及文件** | `mmu/rtl/twu.sv`（约 L994–L1001，`csr_grant` 组合逻辑） |

### Bug 内容

- **位置**：`CSR Arbiter` 中 `case({csr_itlb_sel, fst_csr_sel, scd_csr_sel})` 的分支 **`3'b001`**（仅 **`scd_csr_sel`** 为真：第二级 CSR 检查请求占用 CSR 端口）。
- **错误行为**：原实现将 **`csr_grant[1:0]` 写成 `2'b10`**，使 **`csr_grant[1]=1`**。由下述定义可知 **`csr_grant[1]` 对应 `fst_csr_grant`、`csr_grant[0]` 对应 `scd_csr_grant`**，因此在「仅 scd 请求 CSR」的场景下 **错误地把 grant 给了第一级（fst）通路**。
- **正确行为**：该场景应只授权 **第二级（scd）**，应 **`csr_grant[1:0] = 2'b01`**（`csr_grant[0]=1`），与后面 `csr_grant`→`csr_vpn`/`csr_type`/… 多路选择（`2'b01` 取 `scd_chk_csr_*`，`2'b10` 取 `fst_chk_csr_*`）一致。
- **影响**：在仅 scd 侧发起 CSR 相关事务时，grant 与数据多路选择不一致，可导致 **CSR 端口选中源与真实请求级不匹配**（表现为错误 VPN/类型/数据路径或与 PMP/PTW 联动相关的异常；具体以仿真与波形为准）。

### 修改摘要

- **`mmu/rtl/twu.sv` ~L998**：`3'b001 : csr_grant[1:0] = 2'b10;` → **`3'b001 : csr_grant[1:0] = 2'b01;`**

---

## 调试记录 #5 — PDE cache refill 前同 VPN 去重，避免多 entry 命中落入 `case default`

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-06 12:49:02 +08:00（补记本条时采集） |
| **版本号** | `2765fb3e4349274e2ba4174b2fed04faa89a9095`（`2765fb3`） |
| **提交说明** | `B_phase12` |
| **涉及文件** | `mmu/rtl/PDE_cache.sv`、`mmu/rtl/L1PDE_cache.sv`、`mmu/rtl/L2PDE_cache.sv` |

### Bug 内容

- **触发场景**：LSU0 / LSU1 几乎同时发起同一个 VPN 的 PTW 请求。两个请求进入 PTW 的时间相邻，第二个请求做 PDE cache 查询时，第一个请求 walk 出来的 PDE 还没有真正 refill 进 PDE cache。
- **错误链路**：
  - 第一个同 VPN 请求 miss 后进入 PTW，并在后续返回非叶子 PDE，准备通过 `mbuf_cache_upd` refill 到 PDE cache。
  - 第二个同 VPN 请求在第一个 PDE refill 可见之前也进入 PTW，因此不会命中第一个请求即将写入的 PDE cache entry，也会独立走出同一个 PDE refill。
  - 原 refill 逻辑只根据 `mbuf_cache_upd` 和 `mbuf_cache_upd_lvl` 触发 PLRU 分配，没有在写入前检查 cache 中是否已经存在相同 VPN 的 entry。
  - 因此同一个 L1/L2 PDE tag 可能被写进两个不同 entry，后续访问同 VPN 时 `L1PDE_entry_hit_idx` 或 `L2PDE_entry_hit_idx` 变成 multi-hot。
- **直接后果**：`PDE_cache.sv` 中根据 hit 向量选择 PPN 的 `case(L1PDE_entry_hit_idx[15:0])` / `case(L2PDE_entry_hit_idx[15:0])` 只覆盖 one-hot 编码；multi-hot 时落入 `default`，输出 PPN 被置 0，导致 PTW 后续取数/地址错误。

### 修复摘要

- **`L1PDE_cache.sv` / `L2PDE_cache.sv`**：为每个 entry 增加“更新前 VPN 比对”接口：
  - L1：`L1PDE_entry_before_upd_vpn` / `L1PDE_entry_before_upd_hit`
  - L2：`L2PDE_entry_before_upd_vpn` / `L2PDE_entry_before_upd_hit`
- **`PDE_cache.sv`**：在 refill 进入 PLRU 分配前，汇总所有 entry 的同 VPN 命中：
  - L1 用 `mbuf_cache_upd_vpn[26:18]` 做更新前比对；
  - L2 用 `mbuf_cache_upd_vpn[26:9]` 做更新前比对。
- **关键 gating**：
  - `L1PDE_plru_refill_vld = mbuf_cache_upd & mbuf_cache_upd_lvl[1] & !(|L1PDE_entry_before_upd_hit)`
  - `L2PDE_plru_refill_vld = mbuf_cache_upd & mbuf_cache_upd_lvl[0] & !(|L2PDE_entry_before_upd_hit)`
- 修复后，如果 PDE cache 中已经有相同 VPN/tag 的 entry，本次 refill 不再分配新 entry，从源头避免同 VPN 多 entry。

### 验证关注点

- 定向并发场景：LSU0 / LSU1 back-to-back 或同周期请求相同 VPN，第一笔 PDE refill 与第二笔 PTW 进入之间存在紧邻窗口。
- 波形检查：
  - 第二次相同 VPN PDE refill 到达时，`*_entry_before_upd_hit` 至少有一位为 1；
  - `*_plru_refill_vld` 被压低；
  - `L1PDE_entry_hit_idx` / `L2PDE_entry_hit_idx` 后续保持 one-hot，不出现 multi-hot；
  - PPN 选择不再走 `case default`。

---

## 调试记录 #6 — `ptw_mbuf.sv`：`tlboper_ptw_abort` 与 TWU→MBUF 入队互斥

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-07 22:20:47 +08:00（写入本条时采集） |
| **版本号** | 基准：`c3fd250ea41f613b39807bc813611704bf9d6534`（`c3fd250`，提交说明：`add function description`，提交时间：2026-05-07 18:15:22 +0800）— **`mmu/rtl/ptw_mbuf.sv` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/ptw_mbuf.sv`（约 L300、L311） |

### 背景与动机

- **`tlboper_ptw_abort` 有效时**，TLB 操作侧要求 PTW/MBUF 侧配合冲刷、中止在途 walk；该窗口内 **不能再接受会把新请求写入 MBUF 的更新**。
- **竞态**：`tlboper_ptw_abort` 到达的同一时刻，**TWU 仍可能对 MBUF 发起入队相关请求**（`|twu_mbuf_req[3:0]` 或 ITLB 选中 `twu_itlb_sel`）。若在 abort 有效时仍允许 **新建 LSU 侧 entry**（`create_en`）或 **更新 ITLB 专用 entry8**（`mbuf_entry_upd[8]`），会把本应随 abort 清掉的事务 **再次写入 MBUF**。
- **后果**：MBUF 内可能出现 **请求滞留**，与 abort 意图相悖，**无法保证 MBUF 被冲刷干净**。

### RTL 要点（与修改对应）

- **`create_en`（LSU 侧按 `create_ptr` 分配）**  
  - 在原有「有 TWU mbuf 请求且非 ITLB 选中」基础上，增加 **`& (!tlboper_ptw_abort)`**。  
  - **含义**：abort 有效时禁止本拍因 TWU 请求而移位 `create_ptr` / 置位 `mbuf_entry_upd[7:0]`，避免 abort 窗口内仍向 MBUF 灌入新 LSU entry。

- **`mbuf_entry_upd[8]`（ITLB 专属 entry8）**  
  - 由仅 `twu_itlb_sel` 改为 **`twu_itlb_sel & (!tlboper_ptw_abort)`**。  
  - **含义**：abort 有效时禁止本拍对 entry8 的更新，与上条一致，避免 ITLB 路径在 abort 同一窗口把状态写回 MBUF 造成滞留。

### 代码锚点（写入本条时工作区）

```systemverilog
assign create_en = |twu_mbuf_req[3:0] & (!twu_itlb_sel) & (!tlboper_ptw_abort);
// ...
assign mbuf_entry_upd[8] = twu_itlb_sel & (!tlboper_ptw_abort);
```

### 验证关注点

- 定向：`tlboper_ptw_abort` 与 `|twu_mbuf_req` / `twu_itlb_sel` **同拍或相邻拍** 重叠；确认该周期 **无** 新的 `create_en` 与 **无** `mbuf_entry_upd[8]`，且后续 MBUF 有效位/冲刷行为与 TLB oper 协议一致。

---

## 调试记录 #7 — `ptw_mbuf.sv`：`tlboper_ptw_abort` 与 LSU 请求保持、`req_ptr` 对齐、`mmu_lsu_data_req_grant` 门控；`one_to_four_xbar.sv`：`twu_req` 门控

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-07 22:26:52 +08:00（#7 主体首次写入）；**2026-05-07 22:35:08 +08:00**（增补 `mmu/rtl/one_to_four_xbar.sv` L99 说明） |
| **版本号** | 基准：`c3fd250ea41f613b39807bc813611704bf9d6534`（`c3fd250`，提交说明：`add function description`，提交时间：2026-05-07 18:15:22 +0800）— **`mmu/rtl/ptw_mbuf.sv` 相对该提交仍有工作区未提交改动**；**`mmu/rtl/one_to_four_xbar.sv` 写入本条增补时与 `HEAD` 一致（无未提交改动）** |
| **涉及文件** | `mmu/rtl/ptw_mbuf.sv`（约 L318–L330、L335–L343、L401）、`mmu/rtl/one_to_four_xbar.sv`（约 L99） |

### （1）`mmu_lsu_data_req` / `tlboper_ptw_abort_reg`（约 L318–L330）

- **现象需求**：遇到 `tlboper_ptw_abort` 时，若 **发往 LSU 的请求在本拍之前已经有效（已“出去”）**，MMU **无法知道 LSU 侧是否已经对该请求完成授权/接管**，因此 **不能把请求贸然拉低**，否则可能与 LSU 侧握手约定不一致。
- **做法**：在该情形下 **继续保持 `mmu_lsu_data_req` 拉高**，并 **等待 LSU 返回**（以 `lsu_mmu_data_vld` 等为完成/可见边界）；通过 **`tlboper_ptw_abort_reg`** 在「abort 已发生但尚未等到 LSU 返回」的窗口内 **维持请求有效**（与组合项 `| tlboper_ptw_abort_reg` 及寄存器置位/清除条件配套）。
- **例外**：若正处于 **本次发往 LSU 请求的“第一个时钟周期”**（`mmu_lsu_data_req_fst_time`），此时 LSU **尚不可能已经接受**该事务，可直接在该拍用 **`!(mmu_lsu_data_req_fst_time & tlboper_ptw_abort)`** **屏蔽请求**，无需承担“已授权未知”的问题。

### （2）`req_ptr` 与 `create_ptr` 同步（约 L335–L343）

- **背景**：`tlboper_ptw_abort` 会 **冲刷 MBUF 各 entry**；冲刷后后续会 **重新发请求**。
- **问题**：若 abort 后 **`req_ptr` 不与 `create_ptr[7:0]` 对齐**，重发时分配指针（`create_ptr`）与服务/仲裁指针（`req_ptr`）**脱节**，会导致 **面向 LSU 的请求逻辑上一直无法满足发出条件**（表现为请求 **长期发不出去**）。
- **做法**：在 **`tlboper_ptw_abort`** 或与 **`tlboper_ptw_abort_reg` 配套的返回窗口内**，将 **`req_ptr[7:0]` 更新为 `create_ptr[7:0]`**，保证冲刷后两指针一致，重发路径可用。

### （3）`mmu_lsu_data_req_grant`（约 L401）

- **与调试记录 #6 同一类道理**：在 **`tlboper_ptw_abort` 有效**时，对 grant 侧增加 **`& (!tlboper_ptw_abort)`**（写入本条时工作区如下），避免 abort 窗口内仍对各 entry 产生 **错误的 grant 脉冲**，与「abort 时禁止错误推进/错误认领」一致。

### （4）`one_to_four_xbar.sv` `twu_req[3:0]`（约 L99）

- **与 L401 / 调试记录 #6 同类**：`tlboper_ptw_abort` 有效时，须阻断 **PDE cache→TWU 侧按 hash 分发出去的端口请求**，否则 abort 窗口内仍可能对某一 **`twu_req[i]`** 产生 **误请求**，与 MBUF 冲刷、PTW 中止语义不一致。
- **实现**：在原有 **`PDE_xbar_req & (!twu_xbar_mask)`** 上增加 **`& (!tlboper_ptw_abort)`**，abort 有效拍 **`twu_req[3:0]` 保持全 0**（不与 `twu_req_hash` 相与出有效 one-hot）。

### 代码锚点（写入本条时工作区）

```systemverilog
assign mmu_lsu_data_req = (|(mbuf_entry_vld[8:0] & (~mbuf_entry_get[8:0]) & (~mbuf_entry_bus_err_flop[8:0])))
    & !(mmu_lsu_data_req_fst_time & tlboper_ptw_abort) | tlboper_ptw_abort_reg;

always@(posedge mbuf_clk or negedge cpurst_b)
begin
  if (!cpurst_b)
    tlboper_ptw_abort_reg <= 1'b0;
  else if(tlboper_ptw_abort & (!mmu_lsu_data_req_fst_time) & (!lsu_mmu_data_vld))
    tlboper_ptw_abort_reg <= 1'b1;
  else if(lsu_mmu_data_vld)
    tlboper_ptw_abort_reg <= 1'b0;
end

always@(posedge mbuf_clk or negedge cpurst_b)
begin
     if (!cpurst_b)
        req_ptr[7:0] <= 8'b1;
    else if((mmu_lsu_data_req_fst_time | lsu_mmu_data_vld) & tlboper_ptw_abort | tlboper_ptw_abort_reg & lsu_mmu_data_vld)
        req_ptr[7:0] <= create_ptr[7:0];
    else if (lsu_mmu_data_vld & (~req_on_ptr[8]))
        req_ptr[7:0] <= {req_ptr[6:0], req_ptr[7]};
end

assign mmu_lsu_data_req_grant[8:0] = {9{mmu_lsu_data_req & (!tlboper_ptw_abort)}} & mbuf_ptr_one[8:0];
```

`mmu/rtl/one_to_four_xbar.sv`：

```systemverilog
assign twu_req[3:0] = {4{PDE_xbar_req & (!twu_xbar_mask) & (!tlboper_ptw_abort)}} & twu_req_hash[3:0];
```

### 验证关注点

- abort **前已拉高** `mmu_lsu_data_req`：`tlboper_ptw_abort_reg` 置位后请求保持，直至 `lsu_mmu_data_vld` 等与协议一致的清除条件。
- abort **落在 `mmu_lsu_data_req_fst_time`**：本拍请求可被屏蔽，且 LSU 侧无不一致。
- entry 冲刷后 **`req_ptr` 与 `create_ptr`** 一致，重发场景下 `mmu_lsu_data_req` 可重新拉起。
- abort 有效拍 **`mmu_lsu_data_req_grant` 不应误有效**（与 #6 门控一致）。
- abort 有效拍 **`twu_req[3:0]` 为全 0**，不因 `PDE_xbar_req` / hash 向任一脚误打 TWU 请求（与 L401 同类门控）。

---

## 调试记录 #8 — `ptw.sv`：Refill 仲裁 `ptw_arb_req` 与 `tlboper_ptw_abort`（禁止 abort 窗口内回填）

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-07 22:42:21 +08:00（写入本条时采集） |
| **版本号** | `c3fd250ea41f613b39807bc813611704bf9d6534`（`c3fd250`，提交说明：`add function description`，提交时间：2026-05-07 18:15:22 +0800）；**`mmu/rtl/ptw.sv` 写入本条时与 `HEAD` 一致（无未提交改动）** |
| **涉及文件** | `mmu/rtl/ptw.sv`（Refill arbiter，约 L782） |

### 背景与动机

- **`tlboper_ptw_abort` 有效**表示 TLB 操作侧要求 **冲刷 PTW/MBUF 侧在途事务**，此时 **不应再走「向 L2TLB/下游回填（refill）」的仲裁请求**。
- **语义**：abort 时 **不能直接回填**；应先 **刷掉相关请求/状态**，再由 **L2 侧按协议重发**，避免在冲刷窗口内仍把 refill grant 推出去，与「全部清掉再重来」不一致。

### RTL 要点

- **`ptw_arb_req`**（Refill arbiter 总请求）在原有 **`(|twu_arb_ref_req)`、`(!arb_ptw_mask)`、`ref_grant`** 条件上增加 **`& (!tlboper_ptw_abort)`**。
- **含义**：`tlboper_ptw_abort` 为真时 **强制 `ptw_arb_req=0`**，refill 仲裁入口关闭，与 MBUF/TWU 侧其它 abort 门控（如调试记录 #6/#7）同一套「先停请求、再靠重发恢复」的思路。

### 代码锚点（写入本条时与 `HEAD` 一致）

```systemverilog
assign ptw_arb_req = (|twu_arb_ref_req[3:0]) & (!arb_ptw_mask) & (!tlboper_ptw_abort) & ref_grant;
```

### 验证关注点

- **`tlboper_ptw_abort` 有效拍**：`ptw_arb_req` 为 0；后续结合波形确认 **L2 重发**路径在冲刷完成后仍能重新拉起 refill 请求。
- 与 **`twu_arb_ref_req` / `ref_grant`** 叠加以外的场景：abort 不应仅依赖 TWU 侧自行拉低请求，**仲裁入口显式门控**可避免边界竞态下仍产生 refill。

---

## 调试记录 #9 — `mbuf_entry.sv`：`mbuf_all_clr` 时清除 `mbuf_on`（避免 L2 重发误判「已发 LSU」）

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-07 22:44:25 +08:00（写入本条时采集） |
| **版本号** | 基准：`c3fd250ea41f613b39807bc813611704bf9d6534`（`c3fd250`，提交说明：`add function description`，提交时间：2026-05-07 18:15:22 +0800）— **`mmu/rtl/mbuf_entry.sv` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/mbuf_entry.sv`（`mbuf_on` 时序逻辑，约 L99–L108） |

### 背景与动机

- **`mbuf_on`** 用于表征该 entry 是否已处于「已向 LSU 侧发起数据请求 / 在途」一类语义（置位条件包含 **`mmu_lsu_data_req_grant`**）。若 **`tlboper_ptw_abort` 触发全 entry 冲刷**时 **`mbuf_on` 未被可靠拉低**，entry 内会残留 **“好像已经发给 LSU 了”** 的状态。
- **后果**：后续 **L2TLB 重发**的新请求再占用 **同一 entry** 时，逻辑可能仍看到 **`mbuf_on` 为真**，从而 **误以为本轮事务已经发往 LSU**，导致握手/`mbuf_get` 等与真实事务阶段不一致。

### RTL 要点

- 在 **`mbuf_on`** 的 `always_ff` 中，对 **`mbuf_all_clr`**（与 MBUF 侧 **全体清除/冲刷** 对齐，abort 场景下会生效）增加 **`else if (mbuf_all_clr) mbuf_on <= 1'b0`**，优先级置于 LSU 返回清零等分支之外、与 **`mmu_lsu_data_req_grant` 置位**相区分。
- **含义**：一旦发生 **全清除**，**无条件清掉 `mbuf_on`**，保证冲刷后 entry **不带「已发 LSU」残留**，L2 重发进入该 slot 时从干净相位重新开始。

### 代码锚点（写入本条时工作区）

```systemverilog
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
```

### 验证关注点

- **`tlboper_ptw_abort` / `mbuf_all_clr` 有效后**：对应 entry **`mbuf_on` 为 0**；随后 L2 重发填充该 entry 时，**不应**在未重新 `mmu_lsu_data_req_grant` 前见到 **`mbuf_on==1`**。
- 与 **`mbuf_vld`** 等其它在 **`mbuf_all_clr`** 上同步清零的位（见同文件 L88–L96）一起核对，保证冲刷语义一致。

---

## 调试记录 #10 — `ptw_mbuf.sv`：PDE Cache 回填有效位 `pde_updata_data_vld` 与 `tlboper_ptw_abort`

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-08 13:06:09 +08:00（写入本条时采集） |
| **版本号** | 基准：`7adbcf2c75731ccdc109d26b18195a0c3a75dfc7`（`7adbcf2`，提交说明：`add l1dtlb function description`，提交时间：2026-05-08 00:06:33 +0800）— **`mmu/rtl/ptw_mbuf.sv` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/ptw_mbuf.sv`（Refill to PDE Cache，约 L657–L664；与下游 `mbuf_cache_upd`，约 L685 起） |

### 背景与动机

- **`mbuf_cache_upd`** 依赖 **`pde_updata_data_vld`**（与同拍锁存的 **`pde_updata_*`** 一起判定是否向 **PDE cache** 回填中间级 PDE）。
- **`tlboper_ptw_abort`** 有效时表示 **TLB 操作侧正在废止当前 PTW/MBUF 上下文**；若此时仍因 **`write_back_grant`** 把「刚从 LSU 写回、但已不该再视为本轮合法 walk 结果」的 PTE **视作可向 PDE cache 传播的更新**，会把 **旧页表层次下仍残留在 mbuf 路径上的数据** 灌进 **PDE cache**，与 **冲刷后应建立的页表结构** 不一致（**陈旧页表层级的更新污染 cache**）。

### RTL 要点

- 对 **`pde_updata_data_vld`** 的置位增加 **`& (!tlboper_ptw_abort)`**：**仅在非 abort 窗口**，`|write_back_grant[8:0]` 才拉高「本拍 PTE 回填语义有效」脉冲。
- **含义**：abort 有效拍 **不承认** 面向 PDE cache 的这拍 refill 有效门控，从源头阻断 **`mbuf_cache_upd`**（其与 **`pde_updata_data_vld`** 相与），避免 **abort 期间仍用旧 walk 结果更新 PDE cache**。

### 代码锚点（写入本条时工作区）

```systemverilog
always_ff @(posedge mbuf_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        pde_updata_data_vld <= 1'b0;
    else if(|write_back_grant[8:0] & (!tlboper_ptw_abort))
        pde_updata_data_vld <= 1'b1;
    else 
        pde_updata_data_vld <= 1'b0;
end
```

下游 **`assign mbuf_cache_upd = pde_updata_data_vld & ...`**（见同文件约 L685）与此对齐。

### 验证关注点

- **`tlboper_ptw_abort` 与 `|write_back_grant` 同拍**：**`pde_updata_data_vld` 应为 0**，且 **`mbuf_cache_upd`** 不因该拍 grant 误拉起。
- 冲刷结束、abort 解除后，正常 **`write_back_grant`** 路径仍可回填（需与 **调试记录 #6/#7** 其它 abort 门控一起看端到端）。

---

## 调试记录 #11 — `PDE_cache.sv`：`tlboper_ptw_abort` 并入 `pde_cache_clear`，废止时冲刷 PDE cache

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-08 21:44:20 +08:00（写入本条时采集） |
| **版本号** | 基准：`7adbcf2c75731ccdc109d26b18195a0c3a75dfc7`（`7adbcf2`，提交说明：`add l1dtlb function description`，提交时间：2026-05-08 00:06:33 +0800）— **`mmu/rtl/PDE_cache.sv` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/PDE_cache.sv`（`pde_cache_clear` 与 L1/L2 `L1PDE_cache` / `L2PDE_cache` 的 `.regs_ptw_clr` 连线，约 L151–L152、L162、L187） |

### 背景与动机

- **`tlboper_ptw_abort`** 有效时，若 **PDE cache 仍保持原有数组内容**，仅在仲裁侧 **屏蔽当拍 lookup/update**，则存在语义缺口：软件已通过改写页表并发起 **TLB 操作（tlboper）** 使 TLB 条目失效时，**PDE cache 中的中间级 PDE 仍可被后续 lookup 命中**，相当于仍保留 **废止前 walk 背景下缓存的 PDE**，与 **新页表内容** 不一致。
- 换言之：**仅 abort 当前 PTW 事务而不冲刷 PDE cache**，会在「软件改 PTE + TLB 失效」场景下 **残留陈旧 PDE cache**，与 **调试记录 #10**（`ptw_mbuf.sv` 侧在 abort 窗口关闭面向 PDE cache 的 refill 门控）互为表里：缓冲路径阻断旧数据写入 cache 后，**lookup 侧仍需在 abort 时使 cache 条目失效**，避免继续命中旧层次。

### RTL 要点

- 新增组合信号 **`pde_cache_clear`**：**`regs_ptw_clr | tlboper_ptw_abort`**，使 **寄存器侧全清** 与 **TLB 操作废止 PTW** 任一成立时，均向子模块传递「按 `regs_ptw_clr` 语义执行冲刷/清零」的请求。
- **`L1PDE_cache` / `L2PDE_cache` 实例** 原 **`.regs_ptw_clr(regs_ptw_clr)`** 改为 **`.regs_ptw_clr(pde_cache_clear)`**，保证 **`tlboper_ptw_abort`** 与软件显式 **`regs_ptw_clr`** 走 **同一套 PDE cache 冲刷路径**。

### 代码锚点（写入本条时工作区）

```systemverilog
logic pde_cache_clear;
assign pde_cache_clear = regs_ptw_clr | tlboper_ptw_abort;

// L1PDE_cache / L2PDE_cache 各 16 路 generate 内：
//     .regs_ptw_clr    (pde_cache_clear),
```

**当前 RTL** 在 **`pde_cache_clear`** 上另并入 **`pmp_regs_update`**（PMP CSR 配置变更时冲刷），见 **调试记录 #13**。

### 验证关注点

- **`tlboper_ptw_abort` 上升/有效窗口**：对应 ASID/上下文中 **L1/L2 PDE 条目应按 `regs_ptw_clr` 同类语义被清除或失效**，后续 lookup **不应**再命中废止前缓存的 PDE（除非 walk 重新填充）。
- **PDE cache 侧已在 abort 时冲刷**（**调试记录 #11**）；若 **`ptw_mbuf.sv`** 已撤销 **`pde_updata_data_vld` 上的 `(!tlboper_ptw_abort)` 门控**，则以 **PDE cache `pde_cache_clear` 含 `tlboper_ptw_abort`** 为权威，不再依赖 MBUF 侧门控阻挡 refill。

---

## 调试记录 #12 — `ptw_mbuf.sv`：`mbuf_bus_error` 与 `tlboper_ptw_abort`（总线异常上报与废止同拍/先后）

> **勘误**：本条代码锚点中 `tlboper_ptw_abort` 分支曾写为 `mbuf_bus_error <= 1'b1`，**已纠错**，见 **调试记录 #14**（废止时应 **清零**）。

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-08 22:06:15 +08:00（写入本条时采集） |
| **版本号** | 基准：`7adbcf2c75731ccdc109d26b18195a0c3a75dfc7`（`7adbcf2`，提交说明：`add l1dtlb function description`）— **`mmu/rtl/ptw_mbuf.sv` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/ptw_mbuf.sv`（`mbuf_bus_error` 脉冲，`always_ff`，约 L594–L604；与 `mbuf_bus_error_grant`、应答 TWU 路径配套） |

### 背景与语义

- **`tlboper_ptw_abort`** 表示 TLB 操作侧要 **废止当前 PTW/MBUF 上下文并清掉相关请求**；其中也包括 **本应向 TWU 上报的总线异常（bus error）路径**：未完成或未授权上报的异常 **不再保留**，与「全部取消」一致。
- **同周期竞合**：若 **总线异常上报已获得授权**（`|mbuf_bus_error_grant` 在该拍成立）**且与 `tlboper_ptw_abort` 同一时钟周期**，仲裁/时序上 **仍允许本拍完成「已授权」的上报**（`mbuf_bus_error` 可依 **`mbuf_bus_error_grant`** 分支置位）。
- **未及时上报的异常**：落在 abort **之后**、或 **尚未排到 grant** 的异常，随上下文废止 **一并取消**，不再单独往外冒泡。

### RTL 要点

- **`mbuf_bus_error`** 的 `always_ff` 中，在 **非复位** 条件下 **`else if(tlboper_ptw_abort)`** 将 **`mbuf_bus_error <= 1'b1`**：在废止拍拉高脉冲语义（与同拍 grant 等优先级配合；具体与 **`acc_err_mbuf_grant`** 清零分支的先后以最终实现为准）。
- 与 **`mbuf_bus_error_type` / `mbuf_bus_error_id`**（在 **`mbuf_bus_error_grant`** 上锁存 entry 侧类型与 ID）区分：**本条强调「abort 扫尾取消未上报异常」与「同拍仍可出现已授权上报」** 的设计意图。

### 代码锚点（写入本条时工作区）

```systemverilog
always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
        mbuf_bus_error <= 1'b0;
    end else if(tlboper_ptw_abort)
        mbuf_bus_error <= 1'b1;
    else if(|mbuf_bus_error_grant[8:0])begin
        mbuf_bus_error <= 1'b1;
    end else if(acc_err_mbuf_grant)begin
        mbuf_bus_error <= 1'b0;
    end
end
```

### 验证关注点

- **`tlboper_ptw_abort` 与 `|mbuf_bus_error_grant` 同拍**：确认是否符合预期（允许已授权上报 vs 一律按 abort 语义吞掉），与 TWU 侧可见 **`mbuf_twu_*`** / **`lsu_mmu_bus_error`** 连线一致。
- **abort 后**：无新的 **`mbuf_bus_error_grant`** 窗口时，**不应**再见到残留 entry 的 bus error 上报（除非协议另有「abort 后单独脉冲」定义）。

---

## 调试记录 #13 — `pmp_regs_update`：PMP 配置变更时冲刷 PDE cache

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-08 22:49:13 +08:00（写入本条时采集） |
| **版本号** | 基准：`7fa80e440557cdc492711f4b051bf14e660b2de0`（`7fa80e4`，提交说明：`rtldebug`，提交时间：2026-05-08 22:39:22 +0800）— **`mmu/rtl/PDE_cache.sv`、`mmu/rtl/ptw.sv`、`mmu/rtl/ct_mmu_top.v` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/ct_mmu_top.v`（顶层输入 `pmp_regs_update`，约 L178；实例化 PTW 约 L880）、`mmu/rtl/ptw.sv`（端口 `pmp_regs_update`，约 L65；`PDE_cache` 连线约 L285）、`mmu/rtl/PDE_cache.sv`（端口 `pmp_regs_update`，约 L44；`pde_cache_clear` 约 L153） |

### 背景与动机

- **PMP（Physical Memory Protection）寄存器配置变更**后，对 **同一物理页 / 同一 walk 路径** 的 **读写执行权限** 可能与变更前不同：原先在某级页表 walk 上 **已通过 PMP 检查** 的路径，在新配置下 **可能不再通过**。
- **PDE cache** 若仍保留变更前缓存的 **中间级 PDE**，后续 lookup 可能 **错误地 shortcut**，跳过本应在新 PMP 规则下重新执行的 **地址级 / 层级检查**，导致 **权限语义与真实 CSR 配置不一致**。
- 因此在 **`pmp_regs_update`** 有效（表示 **PMP 相关 CSR 已更新、配置变更需对 MMU 侧可见**）时，须与 **`regs_ptw_clr`、`tlboper_ptw_abort`** 一样参与 **`pde_cache_clear`**，**清空 PDE cache**，迫使后续 walk **重新取页表并走完整检查路径**。

### RTL 要点

- **`PDE_cache.sv`**：**`assign pde_cache_clear = regs_ptw_clr \| tlboper_ptw_abort \| pmp_regs_update;`**  
- **`ptw.sv`**：增加 **`pmp_regs_update`** 输入并传入 **`PDE_cache`**。  
- **`ct_mmu_top.v`**：自顶层接入 **`pmp_regs_update`** 并向下传给 **`ptw`**（与 PMP/CSR 侧一致；上游可由 `ct_pmp_top` 等对 CSR 写使能归纳产生，与局部 `wr_pmp_regs` 类组合信号区分）。

### 代码锚点（写入本条时工作区）

```systemverilog
// PDE_cache.sv
assign pde_cache_clear = regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update;

// ct_mmu_top.v / ptw.sv：端口与实例 .pmp_regs_update(pmp_regs_update)
```

### 验证关注点

- **`pmp_regs_update` 脉冲后**：L1/L2 PDE 阵列 **不应**再命中变更前缓存条目（除非后续 walk 重新 refill）。  
- 回归场景：**PMP 配置改写前后** 对 **同一 VPN/物理区域** 的访问，权限应与 **新 PMP** 一致；无「仅靠旧 PDE cache hit 绕过新规则」的路径。

---

## 调试记录 #14 — `ptw_mbuf.sv`：`tlboper_ptw_abort` 时 `mbuf_bus_error` 应清零而非拉高（修正 #12）

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-15 15:30:00 +08:00（写入本条时采集；RTL 改动尚未 `git commit`） |
| **版本号** | 基准：`51ce48ef1e8ae47c91b05c279c7536480b5d0bde`（`51ce48e`，提交说明：`ptw_uvm_updata`，提交时间：2026-05-15 14:56:31 +0800）— **`mmu/rtl/ptw_mbuf.sv` 相对该提交仍有工作区未提交改动** |
| **涉及文件** | `mmu/rtl/ptw_mbuf.sv`（`mbuf_bus_error` 时序逻辑，`always_ff`，约 L613–L623） |
| **关联记录** | **调试记录 #12** 曾按「abort 拍 `mbuf_bus_error <= 1'b1`」记述；本条为 **RTL 纠错**，以本条为准。 |

### Bug 内容

- **位置**：`mbuf_bus_error` 的 `always_ff` 中，`else if (tlboper_ptw_abort)` 分支（约 **L616–L617**）。
- **错误行为**：`tlboper_ptw_abort` 有效时将 **`mbuf_bus_error <= 1'b1`**，在 **TLB 操作废止（中断/冲刷）** 窗口内 **误把总线异常上报脉冲拉高**，语义上像是「abort 同时对外宣告 bus error」，与 **废止应取消、扫尾未上报异常** 的设计意图相反。
- **正确行为**：遇到 **`tlboper_ptw_abort`** 时应对 **`mbuf_bus_error` 做清空（`1'b0`）**，表示 **废止扫尾、不再保留/不再向外脉冲 bus error**；真正的 bus error 上报仍仅由 **`|mbuf_bus_error_grant`** 在 **非 abort 窗口** 置位；**`acc_err_mbuf_grant`** 分支继续负责在访问错误 grant 路径上拉低该脉冲。

### 修改摘要

- **`mmu/rtl/ptw_mbuf.sv` ~L617**：`tlboper_ptw_abort` 分支由 **`mbuf_bus_error <= 1'b1`** 改为 **`mbuf_bus_error <= 1'b0`**。

### 代码锚点（写入本条时工作区）

```systemverilog
always_ff @(posedge mbuf_clk or negedge cpurst_b)begin
    if(!cpurst_b)begin
        mbuf_bus_error <= 1'b0;
    end else if(tlboper_ptw_abort)
        mbuf_bus_error <= 1'b0;   // 废止时清空，勿误拉高
    else if(|mbuf_bus_error_grant[MBUF_ENTRY_NUM-1:0])begin
        mbuf_bus_error <= 1'b1;
    end else if(acc_err_mbuf_grant)begin
        mbuf_bus_error <= 1'b0;
    end
end
```

### 验证关注点

- **`tlboper_ptw_abort` 有效拍**：**`mbuf_bus_error` 应为 0**（除非同拍另有独立协议要求，以 TWU/`mbuf_entry_bus_err_req_mask` 连线为准）；**不应**因 abort 单独产生 **误报 bus error**。
- 与 **调试记录 #6/#7/#8**（abort 禁止入队、禁止 refill、PDE 冲刷）及 **#12 原「取消未上报异常」文字意图** 端到端一致：废止后 TWU/PTW source 侧不应看到 **由 abort 触发的虚假 `lsu_mmu_bus_error` / bus error 完成**。
- 定向：**abort 与 `mbuf_bus_error_grant` 相邻/重叠** 场景，确认仅 **grant 授权路径** 可置位 `mbuf_bus_error`，abort 路径只负责 **清零扫尾**。

---

## 调试记录 #15 — `PDE_cache`：L2 PMP 直连 access fault 时禁止向 TWU/xbar 分发命中请求

| 项目 | 内容 |
|------|------|
| **记录时间** | **门控修改**：2026-05-18 11:00:07 +0800（Git 提交时间）；**acc_err 检测/上报链**：2026-05-16 13:52:31 +0800（同系列提交 `7abc6bb`） |
| **版本号** | **`01d8f1fdc491dd429f1c5241cc22e93f1b5e1d60`（`01d8f1f`）** — 提交说明：`pdecache_pmpflg`；acc_err 端口与 L2PDE 判定见 **`7abc6bb7ca64c7244a6d0cedd914d656a655111e`（`7abc6bb`）** |
| **涉及文件** | `mmu/rtl/PDE_cache.sv`（主）、`mmu/rtl/L2PDE_cache.sv`（`L2PDE_entry_acc_err`）、`mmu/rtl/ptw.sv`（`PDE_cache_acc_err_*` 接入与 `acc_err_twu_grant[5]`） |
| **关联验证** | `test_ptw_l1_pde_hit` + PTW source SB（`PTW_SOURCE_MISMATCH` 中错误 PPN refill 与「fault 仍走 hit→TWU」相关场景） |

### 背景与动机

- L2 PDE cache **tag 命中**但 **L1/L2 `pmpflg` 检查不通过**时，应在 PDE cache 内 **直接上报 access fault**，**不应**再把该次事务当作正常 **PDE hit** 经 `one_to_four_xbar` **分发给任一路 TWU** 继续 walk/refill。
- 修改前：`PDE_xbar_req = ptw_req`，在 **`PDE_cache_acc_err_vld` 已有效** 时 xbar 仍可能 **`xbar_twu_req` 非零**，TWU 仍按 hit PPN 推进，与 **直连 fault 上报** 并行，易导致 **错误 refill PPN**（如 `exp=0x200c` / `act=0x2012` 类 `PTW_SOURCE_MISMATCH`）。

### 修改摘要（两处，均在 PDE cache 相关路径）

#### （1）异常检测与 `PDE_cache_acc_err_*` 输出（`7abc6bb`，`PDE_cache.sv` / `L2PDE_cache.sv`）

- **`L2PDE_cache.sv`**：`L2PDE_acc_err` 在 **entry 有效 + `ptw_req` + VPN tag 命中 + PMP 不通过** 时置位，经 **`L2PDE_entry_acc_err`** 送出。
- **`PDE_cache.sv` ~L261–286**：`|L2PDE_entry_acc_err|` → 锁存 **`PDE_cache_acc_err`**，并输出 **`PDE_cache_acc_err_vld/type/id`**；**`PDE_cache_acc_err_grant`** 清除脉冲。
- **`ptw.sv`（配套）**：`acc_err_vld` 并入 **`PDE_cache_acc_err_vld`**；access fault 仲裁 **`acc_err_twu_grant[5]`** 专用于 PDE cache 直连 fault（`twu_acc_err_sel[5]` / `case` `6'b100000` 取 `PDE_cache_acc_err_type/id`）。

#### （2）`PDE_xbar_req` 门控：仅无直连 fault 时才向 xbar/TWU 分发（`01d8f1f`，`PDE_cache.sv` ~L398）

- **原**：`assign PDE_xbar_req = ptw_req;`
- **新**：`assign PDE_xbar_req = ptw_req & (!PDE_cache_acc_err_vld);`
- **语义**：**`PDE_cache_acc_err_vld=1`** 时 **`PDE_xbar_req=0`** → `one_to_four_xbar` 内 **`twu_req[3:0]`** 为全 0 → **不向 TWU 打 PDE hit 请求**；fault 仅走 **`ptw` access fault 仲裁** 上报 L2TLB。
- **说明**：仍 **不用 `xbar_pde_ready` 门控 `PDE_xbar_req`**（避免与 xbar 组合环，见 L393–397 注释）；**`ptw_req`** 仍可在 `!xbar_pde_ready` 时保持，待 **`xbar_pde_ready=1`**（无 TWU mask 时 ready 常为 1）后清除，与 xbar 握手解耦。

### 代码锚点（当前 `HEAD` = `01d8f1f`）

```systemverilog
// L2PDE_cache.sv — PMP deny on L2 tag hit
assign L2PDE_acc_err = L2PDE_vld & ptw_req & (ptw_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0])
    & !((l1pmp_ok & l2pmp_ok) | cp0_mach_mode & !L2PDE_l1pmpflg[3] & !L2PDE_l2pmpflg[3]);
assign L2PDE_entry_acc_err = L2PDE_acc_err;

// PDE_cache.sv — fault 锁存与 xbar 分发门控
assign PDE_cache_acc_err_vld = PDE_cache_acc_err;
// always_ff: L2PDE_entry_acc_err_vld -> PDE_cache_acc_err; grant 清除

assign PDE_xbar_req = ptw_req & (!PDE_cache_acc_err_vld);

// one_to_four_xbar.sv — 随 PDE_xbar_req 自动为 0
assign twu_req[3:0] = {4{PDE_xbar_req & (!twu_xbar_mask)}} & twu_req_hash[3:0];
```

### 验证关注点

- **L2 PDE hit + PMP deny**：**`PDE_cache_acc_err_vld=1`** 期间 **`PDE_xbar_req=0`**、**`xbar_twu_req[*]=0`**；L2TLB 侧应看到 **access fault**（`acc_err_twu_grant[5]`），**不应**再出现基于错误 hit PPN 的 **TWU refill**。
- **L2 PDE hit + PMP allow**：**`PDE_cache_acc_err_vld=0`**，**`PDE_xbar_req`** 与修改前一致，正常 hash 分发到 TWU。
- **grant 后**：**`PDE_cache_acc_err_grant`** 清除 fault 后，下一笔 **`l2tlb_ptw_req`** 可重新走 hit 或 miss 路径。
- 回归：**`test_ptw_l1_pde_hit` SEED=606** 及 stage2 PMP deny 类用例；PTW source SB 不应再因「fault 与 hit 并行」产生 **PPN 类 `PTW_SOURCE_MISMATCH`**。

---

## 调试记录 #16 — `L1PDE_cache` / `L2PDE_cache`：update 前同 tag 去重未用 valid 门控，invalid entry 误挡 PDE refill

| 项目 | 内容 |
|------|------|
| **记录时间** | 2026-05-18 11:25:47 +08:00（定位并写入本条时采集） |
| **版本号** | 基准：`71e1ab830bf2e649920eafa660f6bc39c9176c63`（`71e1ab8`，提交说明：`pdecache_pmpflg`，提交时间：2026-05-18 11:23:22 +0800）— **本条仅记录 RTL bug 与建议修复；写入本条时尚未修改 RTL** |
| **涉及文件** | `mmu/rtl/L1PDE_cache.sv`（`L1PDE_entry_before_upd_hit`，约 L122）、`mmu/rtl/L2PDE_cache.sv`（`L2PDE_entry_before_upd_hit`，约 L138）、`mmu/rtl/PDE_cache.sv`（`L1PDE_plru_refill_vld` / `L2PDE_plru_refill_vld`，约 L344-L345） |
| **关联验证** | `test_ptw_pde_l2_pmp_l1_deny_accerr_001 SEED=606`：`stage8_l2_cached_l1pmp_deny_accerr_manual_window` 报 unexpected PTW memory activity；PDE SVA cover 中 `cp_pde_l1_pmp_hit=0`、`cp_pde_l2_deny_direct_accerr=0`。 |

### Bug 内容

- **位置**：`L1PDE_cache.sv` / `L2PDE_cache.sv` 中用于 refill 去重的 `*_entry_before_upd_hit`。
- **错误行为**：当前逻辑只比较 update VPN tag 与 entry tag，**没有检查 entry valid**：

```systemverilog
assign L1PDE_entry_before_upd_hit =
  (L1PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L1PDE_tag[TAG_WIDTH-1:0]);

assign L2PDE_entry_before_upd_hit =
  (L2PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]);
```

- **直接后果**：reset/clear 后 invalid entry 的 tag 默认为 0；当第一笔需要 refill 的 PDE tag 也为 0 时，invalid entry 被误判为 “before update hit”。`PDE_cache.sv` 又用该信号阻止 PLRU refill：

```systemverilog
assign L1PDE_plru_refill_vld =
  mbuf_cache_upd & mbuf_cache_upd_lvl[1] & (!(|L1PDE_entry_before_upd_hit));

assign L2PDE_plru_refill_vld =
  mbuf_cache_upd & mbuf_cache_upd_lvl[0] & (!(|L2PDE_entry_before_upd_hit));
```

因此合法的第一笔 PDE refill 会被 invalid entry 的假 hit 挡掉。

### 本次失败链路

- `test_ptw_pde_l2_pmp_l1_deny_accerr_001` 先用 `l1_prime_va=0x3860_0000` 建 L1 PDE；该 VPN 的 L1 PDE tag 为 0。
- reset 后 L1 PDE invalid entries 的 tag 也是 0，且 `L1PDE_entry_before_upd_hit` 未用 `L1PDE_vld` 门控，导致第一笔 L1 PDE update 被去重逻辑误挡。
- 后续第二笔 fetch 未能通过 L1 PDE hit 直接进入 SCD，而是重新 full walk；日志中可见再次读取 root / SCD / THD PTE。
- 最终 L2 entry 保存成允许 load 的 cached `l1pmpflg/l2pmpflg`，后续 load 正常 L2 hit 并读取 leaf PTE；direct accerr 不出现，UVM 的 no-extra-PTW-memory 检查报错。

### 建议修改

在 before-update tag hit 判定中加入 entry valid 门控：

```systemverilog
// L1PDE_cache.sv
assign L1PDE_entry_before_upd_hit =
  L1PDE_vld
  & (L1PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L1PDE_tag[TAG_WIDTH-1:0]);

// L2PDE_cache.sv
assign L2PDE_entry_before_upd_hit =
  L2PDE_vld
  & (L2PDE_entry_before_upd_vpn[TAG_WIDTH-1:0] == L2PDE_tag[TAG_WIDTH-1:0]);
```

### 验证关注点

- **reset/clear 后第一笔 tag=0 的 L1/L2 PDE refill**：invalid entry 不应阻止 refill；`*_plru_refill_vld` 应能正常拉高。
- **已有 valid 同 tag entry 的重复 refill**：仍应由 `*_entry_before_upd_hit` 阻止重复分配，避免同 tag 多 entry。
- 回归命令：

```bash
make -C mmu_verification run_check TEST_NAME=test_ptw_pde_l2_pmp_l1_deny_accerr_001 SEED=606 PLUS_ARGS="+EN_PTW_SOURCE_SB +EN_PTW_SOURCE_REF_MODEL +EN_PTW_SOURCE_MONITOR +EN_PTW_SOURCE_COV"
```

---

## 后续追加新记录的写法（模板）

复制下表，填 **#N+1**、时间与版本后写要点即可：

```markdown
## 调试记录 #N — （简短标题）

| 项目 | 内容 |
|------|------|
| **记录时间** | YYYY-MM-DD HH:mm:ss ±ZZZZ |
| **版本号** | 完整 hash（短 hash）；或 基准 hash + 工作区未提交 |
| **提交说明** | （若已提交） |
| **涉及文件** | 路径列表 |

### 修改摘要
- ...
```

---

## 核对命令

```bash
git rev-parse HEAD
git log -1 --format="%H %ci %s"
git status -- mmu/rtl/ptw.sv mmu/rtl/twu.sv
git diff mmu/rtl/ptw.sv mmu/rtl/twu.sv
```
