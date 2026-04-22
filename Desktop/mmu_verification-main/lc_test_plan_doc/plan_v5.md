# MMU_VerificationPlan v5.0 — 变更记录

> **基准版本**：v4.0（接口规格对齐 L1DTLB + L2TLB）
> **升级依据**：`doc/MMU_Interfaces.md`（完整 MMU 系统接口，含 CP0/IFU/LSU/PMP/RTU/HPCP 等）+ `doc/MMU_PTW_Interface.md`（PTW 模块接口，含 PTW 顶层/TWU/MBUF/PDE Cache）
> **修改文件**：`lc_test_plan_doc/MMU_VerificationPlan_v3.md`
> **日期**：2026-04-22

---

## 一、§2.3 接口表修改（5 处 Row 级补全）

### 1.1 Row 1（CP0/CSR）— 补充 MMU→CP0 响应信号

**问题**：原文使用 `mmu_cp0_*` 通配符，遗漏了 MMU 向 CP0 回传的三路独立响应信号。

**修改内容**：
- 展开 CP0 输入侧 15 个信号（含 `cp0_mmu_ptw_en`、`cp0_mmu_maee`、`cp0_mmu_mxr`、`cp0_mmu_sum`、`cp0_mmu_mpp[1:0]`、`cp0_mmu_mprv`、`cp0_mmu_wdata[63:0]`、`cp0_mmu_wreg`、`cp0_mmu_tlb_all_inv`、`cp0_mmu_satp_sel`、`cp0_mmu_reg_num[1:0]`、`cp0_mmu_cskyee`、`cp0_mmu_icg_en`、`cp0_mmu_no_op_req`、`cp0_yy_priv_mode[1:0]`）
- 补充 MMU→CP0 响应输出三路信号：
  - `mmu_cp0_cmplt`（操作完成脉冲）
  - `mmu_cp0_data[63:0]`（CSR 读出数据，64-bit）
  - `mmu_cp0_satp_data[63:0]`（SATP 寄存器当前值，64-bit）

**来源**：`doc/MMU_Interfaces.md §2.1.2`

---

### 1.2 Row 3（LSU Pipe0/1）— 补充 Buf/Ca/PageFault/AccessFault 信号

**问题**：v4.0 已补充 sh/so/sec/stall，但 `mmu_lsu_pa{0,1}_*` 通配符仍遗漏 4 路属性信号。

**修改内容**：
- 展开 LSU Pipe0/1 请求侧完整信号（含 `lsu_mmu_va{0,1}[63:0]`（64-bit 完整 VA）、`lsu_mmu_id{0,1}[6:0]`（7-bit 请求 ID）等）
- 补充 MMU→LSU Pipe0/1 响应输出 4 路新信号：
  - `mmu_lsu_buf{0,1}`（Bufferable 属性）
  - `mmu_lsu_ca{0,1}`（Cacheable 属性）
  - `mmu_lsu_page_fault{0,1}`（Page Fault，页表异常）
  - `mmu_lsu_access_fault{0,1}`（Access Fault，PMP 检查失败或总线错误）

**来源**：`doc/MMU_Interfaces.md §2.3.2 / §2.3.4`

---

### 1.3 Row 4（LSU Pipe2 prefetch）— 展开 `pa2_*` 通配符

**问题**：原文 `mmu_lsu_pa2_*` 通配符遗漏了两个独立信号，且信号名 `mmu_lsu_share2` 与 Pipe0/1 的 `sh0/sh1` 命名规则不同，易混淆。

**修改内容**：
- 展开为具名信号列表：`mmu_lsu_pa2_vld`、`mmu_lsu_pa2[27:0]`、`mmu_lsu_sec2`
- 新增：
  - `mmu_lsu_pa2_err`（翻译错误合并指示：Page Fault 或 Access Fault）
  - `mmu_lsu_share2`（Shareable 属性；**注意**：此信号名为 `share2` 而非 `sh2`，与 Pipe0/1 的 `sh{0,1}` 命名规则不一致）

**来源**：`doc/MMU_Interfaces.md §2.3.5`

---

### 1.4 Row 7（LSU Data / PTW 取 PTE 通道）— 补注 `data_req_size` 语义

**问题**：
1. 信号列表中 `mmu_lsu_data_req/addr/size` 用斜杠缩写，未标注 size 语义。
2. `mmu_lsu_wakeup[11:0]` 信号名缺少 `_tlb_` 中缀（应为 `mmu_lsu_tlb_wakeup[11:0]`）。

**修改内容**：
- 展开信号列表为：`mmu_lsu_data_req`、`mmu_lsu_data_req_addr[39:0]`（40-bit PA）、`mmu_lsu_data_req_size`（**1-bit：0=32-bit / 1=64-bit**）、`lsu_mmu_data[63:0]`、`lsu_mmu_data_vld`、`lsu_mmu_bus_error`、`mmu_lsu_tlb_busy`、`mmu_lsu_tlb_wakeup[11:0]`、`mmu_lsu_mmu_en`
- 在描述末尾追加 v5.0 补注：`mmu_lsu_data_req_size` 为 1-bit（0=32-bit 请求，1=64-bit 请求）
- 修正 `mmu_lsu_wakeup[11:0]` → `mmu_lsu_tlb_wakeup[11:0]`（补全 `_tlb_` 中缀）

**来源**：`doc/MMU_Interfaces.md §2.3.8`

---

### 1.5 Row 8（PMP）— 补充端口功能分配注释

**问题**：原文 `mmu_pmp_pa{0-7}` 通配符未注明各端口的功能映射，验证时无法确认 LSU/IFU/PTW 的对应关系。

**修改内容**：
- 展开输入标志：`pmp_mmu_flg{0-7}[3:0]`，注明 bit[0]=R，bit[1]=W，bit[2]=X，bit[3]=L（锁定）
- 展开 PA 输出端口功能分配：
  - `mmu_pmp_pa0` = LSU Pipe 0
  - `mmu_pmp_pa1` = LSU Pipe 1
  - `mmu_pmp_pa2` = LSU Pipe 2（预取）
  - `mmu_pmp_pa3` = IFU 取指
  - `mmu_pmp_pa4-7` = PTW 扩展（`mmu_pmp_pa7`/`mmu_pmp_fetch7` 为 PTW 第四扩展端口）
- 注：`mmu_pmp_fetch4` 已注释掉（F7.NEW.1，v2.0 注记）

**⚠ 设计待确认（标注 [需设计确认]）**：
> `MMU_Interfaces.md §2.4.2` 显示 pa3=IFU 取指；而 `MMU_PTW_Interface.md` 显示 PTW 使用端口 3/5/6/7（而非 4/5/6/7）。两份文档存在出入，需设计方给出最终端口分配表。

**来源**：`doc/MMU_Interfaces.md §2.4.2` + `doc/MMU_PTW_Interface.md`

---

## 二、§2.3 接口注记追加（v5.0 段落）

在原 `v3.0 接口补充` 注记之后追加 `v5.0 接口补充` 段落，汇总以下内容：
1. CP0 响应三路信号补全（来源 §2.1.2）
2. LSU Pipe0/1 响应属性补全（来源 §2.3.2/§2.3.4）
3. LSU Pipe2 通配符展开（来源 §2.3.5）
4. `mmu_lsu_data_req_size` 语义（1-bit，0=32b/1=64b，来源 §2.3.8）
5. PMP 端口功能分配（pa0=LSU Pipe 0, pa1=LSU Pipe 1, pa2=LSU Pipe 2, pa3=IFU, pa4-7=PTW，来源 §2.4.2；含 `[需设计确认]` 注记）
6. RTU 接口确认（`rtu_mmu_bad_vpn[26:0]`/`rtu_mmu_expt_vld`/`rtu_yy_xx_flush`，来源 §2.5）
7. HPCP 接口确认（`mmu_hpcp_dutlb/iutlb/jtlb_miss` 为单周期脉冲，来源 §2.6）

---

## 三、现有功能点修订（2 处）

### 3.1 F4.6 — `twu_xbar_mask` 接口名澄清

**修改位置**：F4.6 描述字段末尾（追加在 `twu_mask 与 MBUF 满无关` 之后）

**修改内容**：
- 澄清 RTL 内部 wire `twu_mask` 的对外接口规格端口名为 `twu_xbar_mask`（TWU 向 xbar 输出的自阻塞掩码），两者对应关系明确
- 说明 `twu_idle`（TWU 完全空闲，6 级流水全空、CSR FSM 为 IDLE）与 `!twu_xbar_mask`（仅表示当前不阻塞）**语义不等价**，交叉引用 F4.NEW.7
- 补充：4 个 TWU 全部 `twu_xbar_mask=1` 时 `ptw_l2tlb_ready` 拉低，交叉引用 F4.NEW.6
- RTL 注记列更新：`twu.sv:output twu_mask（接口规格对外名 twu_xbar_mask）`

**来源**：`doc/MMU_PTW_Interface.md`

---

### 3.2 F4.52 — `twu_xbar_mask` 接口名 + `ptw_l2tlb_ready` 交叉引用

**修改位置**：F4.52 描述字段末尾（追加在 `mask 解除 → 轮转指针正确恢复` 之后）

**修改内容**：
1. 接口规格文档中 `twu_mask` 对外端口名为 `twu_xbar_mask`，RTL 内部 wire 为 `twu_mask`
2. 当 4 个 TWU 全部 `twu_xbar_mask=1` 时，`ptw_l2tlb_ready` 拉低（交叉引用 F4.NEW.6）
3. 四路全停等待时 `twu_req_point_r` 指针不复位（防冷启动偏向，交叉引用 F5.NEW.3）
4. `twu_idle`（完全空闲）与 `!twu_xbar_mask`（未阻塞）语义不等价（交叉引用 F4.NEW.7）

**来源**：`doc/MMU_PTW_Interface.md`

---

## 四、新增功能点（7 条）

### F4.NEW.6（P0）— `ptw_l2tlb_ready` PTW→L2TLB 反压机制

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P0 |
| **RTL 参考** | ptw.sv, twu.sv, one_to_four_xbar.sv |
| **TC** | TC-PTW-READY-001/002/003 |
| **覆盖组** | sva_ptw_l2tlb_ready_when_all_mask, cg_ptw_ready_transition |

**描述**：  
PTW 向 L2TLB 暴露 `ptw_l2tlb_ready` 反压信号。当且仅当 4 个 TWU 的 `twu_xbar_mask` 全部为高时，`ptw_l2tlb_ready` 拉低，通知 L2TLB 暂停发送新的 PTW 请求（`jtlb_ptw_req`）；任意一路 TWU 退出阻塞态则恢复高电平。

**验证关注点**：
1. 全部 4 TWU 同时 mask=1 时，ready 在同周期或下一周期拉低（不得延迟两拍以上）
2. 只要有任意一路 TWU mask=0，ready 保持高电平
3. L2TLB 在 ready=0 时不发送新请求（协议约束）
4. ready 拉低期间已接受的 outstanding 请求继续完成，不应被撤销

---

### F4.NEW.7（P1）— `twu_idle` 与 `twu_xbar_mask` 语义区分

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv, ptw.sv |
| **TC** | TC-TWU-IDLE-MASK-001 |
| **覆盖组** | sva_twu_idle_implies_no_mask, cg_twu_idle_vs_mask_state |

**描述**：  
- `twu_idle`：TWU 完全空闲（6 级流水全空、MBUF 无在途请求、CSR FSM 为 IDLE，即 `twu_busy=0`）  
- `twu_xbar_mask`（对应 RTL wire `twu_mask`）：当前流水线阻塞，无法接受新 xbar 派发的 PDE 请求

**逻辑关系**：`twu_idle=1` 蕴含 `twu_xbar_mask=0`，但反之不成立（TWU 可有在途请求但仍可接收新派发）。

**验证关注点**：
1. 断言 `twu_idle=1` 时 `twu_xbar_mask` 必须为 0
2. TWU 处于"有在途请求但未 mask"状态下，xbar 仍可派发新 PDE 请求
3. `ptw_l2tlb_ready` 计算应基于 `twu_xbar_mask`，而非 `twu_idle`

---

### F4.NEW.8（P1）— `xbar_twu_hit_level[2:0]` PDE Cache 命中级别编码

| 属性 | 内容 |
|------|------|
| **模块** | `one_to_four_xbar` + PDE Cache |
| **优先级** | P1 |
| **RTL 参考** | L1PDE_cache.sv, L2PDE_cache.sv, PDE_cache.sv, one_to_four_xbar.sv, twu.sv |
| **TC** | TC-PDE-CACHE-HIT-L3-001, TC-PDE-CACHE-HIT-L2-001, TC-PDE-CACHE-MISS-001 |
| **覆盖组** | cg_xbar_hit_level, sva_twu_skip_stage_on_hit |

**描述**：  
xbar 向被派发 TWU 传送 3-bit 命中级别 `xbar_twu_hit_level[2:0]` = `{L3PDE_hit_vld, L2PDE_hit_vld, L1PDE_hit_vld}`，决定 TWU 流水线入口：
- `3'b100`（L3PDE 命中）→ 直接进入 THD_PMP 阶段
- `3'b010`（L2PDE 命中）→ 进入 SCD_PMP 阶段  
- `3'b001` 或 `3'b000`（L1PDE 命中/全 Miss）→ 进入 FST_PMP 阶段

新增信号补充：`PDE_xbar_bank_sel[2:0]`（命中时的 bank 选择，用于多路 PDE Cache 组织）。

**验证关注点**：
1. 三种命中场景下 TWU 正确跳过对应级别 PMP 检查
2. `PDE_xbar_bank_sel` 正确路由 PDE 数据到对应 bank
3. 全 Miss 时 TWU 正常启动完整三级 PTW
4. PDE Cache 命中数据无 stale 污染（与 F4.38/F4.39 交叉）

---

### F4.NEW.9（P0）— TWU→L2TLB 异常直通旁路路径

| 属性 | 内容 |
|------|------|
| **模块** | `twu` → `mmu_l2tlb` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv, mmu_l2tlb.sv |
| **TC** | TC-TWU-PGFLT-BYPASS-001, TC-TWU-ACCERR-BYPASS-001, TC-TWU-EXCEPT-CONFLICT-001 |
| **覆盖组** | sva_twu_except_bypasses_arb, sva_twu_pgflt_acc_mutex, cg_twu_except_while_arb_busy |

**描述**：  
TWU 发现页表遍历异常时，**异常通知直接从 TWU 发往 L2TLB，绕过 mmu_arb**，无需争用 Arbiter 总线。

两类独立异常直通路径：
- **（A）Page Fault 路径**：`twu_jtlb_ref_pgflt` + `twu_jtlb_ref_pgflt_id[6:0]` + `twu_jtlb_ref_pgflt_type[2:0]`
- **（B）Access Error 路径**：`twu_jtlb_ref_acc_err` + `twu_jtlb_ref_acc_err_id[6:0]` + `twu_jtlb_ref_acc_err_type[2:0]`

对比：正常 PTE 回填走 TWU→Arbiter→L2TLB；异常通知直连 TWU→L2TLB。

**验证关注点**：
1. Arbiter 被其他 TWU 占用时，本 TWU 产生异常 → 异常通知即时（同周期或下一周期）到达 L2TLB
2. 正常回填信号与异常通知信号同时有效时，L2TLB 接收方仲裁逻辑正确
3. `twu_jtlb_ref_acc_err` 与 `twu_jtlb_ref_pgflt` 的互斥性（同一次遍历不能同时报两种异常）
4. 异常后对应 miss entry 及时释放，无 miss buffer 泄漏（与 F4.48 交叉）

---

### F4.NEW.10（P1）— `twu_data_ready[2:0]` MBUF→TWU 数据分发门控

| 属性 | 内容 |
|------|------|
| **模块** | `twu` ↔ MBUF |
| **优先级** | P1 |
| **RTL 参考** | ptw_mbuf.sv, twu.sv, mbuf_entry.sv |
| **TC** | TC-MBUF-READY-GATE-001, TC-MBUF-HAVE-001, TC-MBUF-MULTI-TWU-READY-001 |
| **覆盖组** | sva_mbuf_waits_twu_ready, cg_twu_data_ready_per_stage, sva_mbuf_have_no_resend |

**描述**：  
MBUF 从 LSU 收到 PTE 数据后，等待 TWU 侧 `twu_data_ready[2:0]` 就绪信号再分发：
- bit[0]：FST_PMP 级就绪（等待 L2 PDE 读结果）
- bit[1]：SCD_PMP 级就绪（等待 L1 PDE 读结果）
- bit[2]：THD_PMP 级就绪（等待 L0 叶 PTE 读结果）

另有 `mbuf_twu_have`：MBUF 已有对应 VPN 缓存时通知 TWU 无需重发 LSU 请求（与 F4.36 去重交叉）。

**验证关注点**：
1. `twu_data_ready` 对应 bit=0 时 MBUF 不提前发出 `mbuf_twu_data_vld`
2. TWU 流水线流速与 MBUF 分发时序一致（无空泡、无数据竞争）
3. `mbuf_twu_have=1` 时 TWU 不重发 LSU 请求
4. 多 TWU 共享同一 MBUF entry 时，各 TWU `twu_data_ready` 独立控制接收时刻

---

### F4.NEW.11（P1）— Arbiter→TWU 三通道 grant 仲裁

| 属性 | 内容 |
|------|------|
| **模块** | `mmu_arb` → `twu` |
| **优先级** | P1 |
| **RTL 参考** | mmu_arb.sv, twu.sv, mmu_l2tlb.sv |
| **TC** | TC-ARB-GRANT-ONEHOT-001, TC-ARB-REFILL-EXCEPT-PRIO-001, TC-ARB-MULTI-TWU-FAIRNESS-001 |
| **覆盖组** | sva_arb_twu_grant_onehot, cg_arb_grant_type, sva_twu_din_stable_on_grant |

**描述**：  
Arbiter 向 TWU 发送三类独立 grant 信号（非单一总线）：
- **`refill_arb_twu_grant`**：正常 PTE 回填授权，允许 TWU 写 L2TLB SRAM
- **`acc_err_twu_grant`**：访问错误通知授权
- **`pgflt_twu_grant`**：Page Fault 通知授权

三路 grant 同周期最多一路有效（one-hot）。

TWU→Arbiter 请求信号：`twu_arb_ref_req`、`twu_arb_ref_type[2:0]`、`twu_arb_ref_data_din`、`twu_arb_ref_tag_din`、`twu_arb_ref_pgs[2:0]`、`twu_arb_ref_id[6:0]`。

**验证关注点**：
1. 三路 grant 同周期 one-hot（断言 `refill + acc_err + pgflt ≤ 1`）
2. 多 TWU 同时 refill 请求时，Arbiter round-robin 调度，不能饿死任何 TWU
3. exception grant 与 refill grant 的相对优先级
4. grant 回来时 TWU din 数据稳定（与 F5.NEW.2 双级流水 reset 竞争交叉）

---

### F5.16（P1）— `ptw_arb_ref_vpn` PTW→Arbiter 独立 VPN 字段

| 属性 | 内容 |
|------|------|
| **模块** | `mmu_arb` |
| **优先级** | P1 |
| **RTL 参考** | mmu_arb.sv, ptw.sv |
| **TC** | TC-ARB-VPN-MATCH-001, TC-ARB-PGS-MATCH-001 |
| **覆盖组** | sva_ptw_arb_vpn_matches_tag, cg_ptw_arb_pgs_type |

**描述**：  
PTW 向 Arbiter 发起 L2TLB 回填请求时，除 `ptw_arb_data_din` 和 `ptw_arb_tag_din` 外，还单独传递 `ptw_arb_ref_vpn`（VPN 独立字段，用于 Arbiter 端 skew hash/bank 选择，避免 Arbiter 解包 tag_din 产生额外时序路径延长）。

完整 PTW→Arbiter 信号集：
- `ptw_arb_req`（请求有效）
- `ptw_arb_data_din`（data SRAM 写入数据）
- `ptw_arb_tag_din`（tag SRAM 写入数据）
- `ptw_arb_pgs[2:0]`（页大小：4K/2M/1G 编码，与 F2.12 一致）
- `ptw_arb_ref_vpn`（独立 VPN 字段）

**验证关注点**：
1. `ptw_arb_ref_vpn` 与 `ptw_arb_tag_din` 中编码的 VPN 字段位对位一致性（防不一致导致写错 bank）
2. `ptw_arb_pgs` 与 `ptw_arb_data_din` 中叶 PTE 编码页类型一致性
3. `arb_ptw_grant` 回来时三路 din 信号在一拍内稳定驱动（与 F5.NEW.2 交叉）

---

## 五、设计待确认事项

### DA-001（P0）— PMP 端口 3 分配冲突

| 项目 | 内容 |
|------|------|
| **涉及功能点** | §2.3 Row 8, F7 section |
| **问题描述** | `MMU_Interfaces.md §2.4.2` 显示 pa3=IFU 取指；而 `MMU_PTW_Interface.md` 显示 PTW 使用 PMP 输入端口 3/5/6 和输出端口 3/5/6/7（而非 4/5/6/7）。两份文档的 PMP 端口 3 分配存在出入。 |
| **影响范围** | 如果 pa3=PTW（而非 IFU），则 IFU PMP 检查端口编号需重新确认，影响 F7 系统侧 PMP 功能点的验证约束。 |
| **建议** | 设计方给出最终端口分配表（Port 0~7 的功能归属）；暂时在 §2.3 Row 8 中标注 `[需设计确认]`。 |

### DA-002（P1）— `jtlb_ptw_id[6:0]` 与复合 ID 宽度

| 项目 | 内容 |
|------|------|
| **涉及功能点** | F3.NEW.5 |
| **问题描述** | `MMU_PTW_Interface.md` 显示 `jtlb_ptw_id[6:0]` 为 7-bit 单字段；而 v4.0 F3.NEW.5 描述了 `l2tlb_ptw_id[L1EID_WIDTH+L2EID_WIDTH-1:0]` 复合 ID。7-bit 可能是复合 ID 的总宽度（如 4b L1EID + 3b L2EID = 7b）。 |
| **建议** | 设计方确认 `jtlb_ptw_id` 的 bit 字段划分；F3.NEW.5 现有描述保留，补注总线宽度为 7-bit。 |

---

## 六、修改统计

| 类别 | 数量 |
|------|------|
| §2.3 接口表 Row 级修改 | 5 处 |
| §2.3 注记追加 | 1 处（v5.0 段落）|
| 现有功能点修订（F4.6/F4.52） | 2 处 |
| 新增功能点（F4.NEW.6-11 + F5.16） | 7 条 |
| 新增 TC | 16 条（TC-PTW-READY-001~003, TC-TWU-IDLE-MASK-001, TC-PDE-CACHE-HIT-L3/L2/MISS, TC-TWU-PGFLT-BYPASS-001, TC-TWU-ACCERR-BYPASS-001, TC-TWU-EXCEPT-CONFLICT-001, TC-MBUF-READY-GATE-001, TC-MBUF-HAVE-001, TC-MBUF-MULTI-TWU-READY-001, TC-ARB-GRANT-ONEHOT-001, TC-ARB-REFILL-EXCEPT-PRIO-001, TC-ARB-MULTI-TWU-FAIRNESS-001, TC-ARB-VPN-MATCH-001, TC-ARB-PGS-MATCH-001）|
| 新增 SVA / 覆盖组 | 14 条 |
| 设计待确认项 | 2 项（DA-001/DA-002）|
