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
