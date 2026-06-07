# MMU Verification Plan v4.0 变更记录

> **基于版本**：MMU_VerificationPlan_v3.md（v3.0 Final）  
> **更新版本**：v4.0  
> **日期**：2026-04-22  
> **参考接口文档**：
> - `doc/L1DTLB_Interfaces.md`（L1 DTLB 接口规格，约 85 个信号，15 个接口组）
> - `doc/L2TLB_Interface.md`（L2 TLB 接口规格，35 个信号，Arbiter⟺L2TLB + PTW⟺L2TLB）

---

## 1. 错误修正

### 1.1 F5.2 仲裁优先级顺序错误（Critical Fix）

- **错误内容**：F5.2 原描述 `4 源优先级：PTW > L2ReqQ > TLBOper > Prefetch`，顺序有误。
- **正确内容**：`PTW > TLBOper > L2TLB Request Queue > PFU`
- **来源依据**：`doc/L2TLB_Interface.md` §3.3.1 仲裁优先级规格；F3.11/F3.33 已按正确顺序描述。
- **修改位置**：F5.2 描述字段。

### 1.2 F5.1 优先级描述文本错误

- **错误内容**：F5.1 原描述 `抢占 ReqQ/TLBOPER/Prefetch`，列举顺序与接口规格不一致。
- **正确内容**：`抢占 TLBOper/ReqQ/PFU`，RTL 注释同步修正为 `PTW > TLBOper > ReqQ > PFU`。
- **修改位置**：F5.1 描述字段与 RTL 参考字段。

---

## 2. 规格与 RTL 不一致标注（需设计方确认）

### 2.1 F2.17 — `mmu_lsu_tlb_wakeup[11:0]` 语义不一致

| 维度 | 内容 |
|------|------|
| 接口规格（L1DTLB_Interfaces.md §2.6.3） | 12 位独热编码，每 bit 对应一个 LSU 操作项，回填完成时拉高对应 bit（per-entry one-hot） |
| RTL 实现（mmu_l1dtlb_install.sv#L233-L235） | 广播信号：`mb_have_free=1` 时全 1（所有 bit 同时拉高） |
| 处理方式 | 在 F2.17 描述中添加 `[v4.0 规格与 RTL 不一致，需设计确认]` 标注，要求设计方明确最终行为语义 |

### 2.2 F2.18 — `mmu_lsu_tlb_busy` 触发条件不一致

| 维度 | 内容 |
|------|------|
| 接口规格（L1DTLB_Interfaces.md §2.6.3） | Miss Buffer **非空**时触发 busy（非空即拉高） |
| RTL 实现（mmu_l1dtlb.sv#L1229） | 仅在 Miss Buffer **全满**（`&mb_entry_vld`）时触发 |
| 处理方式 | 在 F2.18 描述中添加 `[v4.0 规格与 RTL 不一致，需设计确认]` 标注 |

---

## 3. 新增功能点（8 条）

### 3.1 F2 侧新增（4 条）

| F-ID | 优先级 | 标题 | 核心内容 | 接口依据 |
|------|--------|------|---------|---------|
| F2.NEW.3 | P1 | `dutlb_xx_mmu_off` MMU 关闭广播 | MMU 关闭时（`regs_mmu_en=0` 或 Machine 模式）L1DTLB 广播状态，通知下游模块；TC：TC-DTLB-MMU-OFF-001；Cov：cg_dtlb_mmu_off, sva_mmu_off_no_req | L1DTLB_Interfaces.md §2.6.3 |
| F2.NEW.4 | P1 | `dutlb_l2tlb_req_is_load` L2TLB 请求 Load 标志 | Miss 请求随 1-bit Load/Store 标志传递，L2TLB 据此实现 Load-before-Store 调度；TC：TC-DTLB-L2-IS-LOAD-001；Cov：cg_l2tlb_req_type | L1DTLB_Interfaces.md §2.3.1 |
| F2.NEW.5 | **P0** | L2TLB 回填双信号语义：`jtlb_dutlb_ref_pavld` vs `jtlb_dutlb_ref_cmplt` | `ref_cmplt=1, pavld=0` 表示 Page Fault；L1DTLB 只释放 MB Entry 不安装 PA；TC：TC-L2REF-CMPLT-NO-PAVLD-001；SVA：sva_l2ref_cmplt_pavld_excl | L1DTLB_Interfaces.md §2.3.2 |
| F2.NEW.6 | **P0** | PTW→L1DTLB 回填双信号语义：`ptw_l1dtlb_ref_pavld` vs `ptw_l1dtlb_ref_cmplt` | `ref_cmplt=1, ref_pavld=0` 表示 PTW 错误（acc_err/pgflt）；L1DTLB 不安装 PA 直接上报异常；TC：TC-PTWREF-CMPLT-ACCERR-001, TC-PTWREF-CMPLT-PGFLT-001；SVA：sva_ptw_ref_pavld_when_no_err | L1DTLB_Interfaces.md §2.4.1 |

### 3.2 F3 侧新增（4 条）

| F-ID | 优先级 | 标题 | 核心内容 | 接口依据 |
|------|--------|------|---------|---------|
| F3.NEW.2 | P1 | `arb_l2tlb_cmp_with_va` Tag 比较模式控制 | Arbiter 控制 L2TLB Tag 比较时是否使用完整 VA，按页大小（4KB/2MB/1GB）动态切换 VPN 有效比较位宽；TC：TC-L2TLB-CMP-VA-001~003；Cov：cg_l2tlb_cmp_mode, sva_cmp_with_va_per_pgs | L2TLB_Interface.md §3.2 |
| F3.NEW.3 | P1 | `l2tlb_arb_ptw_cmplt` PTW 操作完成通知 Arbiter | PTW Refill 写回后 L2TLB 产生 1 周期脉冲通知 Arbiter 释放资源；TC：TC-L2TLB-PTW-CMPLT-001；SVA：sva_ptw_cmplt_after_refill | L2TLB_Interface.md §3.1 |
| F3.NEW.4 | **P0** | PTW→L2TLB 回填双信号语义：`ptw_l2tlb_ref_cmplt` vs `ptw_l2tlb_ref_data_vld` | `ref_cmplt=1, ref_data_vld=0` 表示 Walk 完成但有错误（pgflt/acc_err）；L2TLB 仅释放 MB Entry 不写 Tag/Data；TC：TC-PTW-L2REF-NOVALID-001；SVA：sva_ptw_l2tlb_ref_cmplt_vld_legal | L2TLB_Interface.md §4.2 |
| F3.NEW.5 | **P0** | `l2tlb_ptw_id` 复合 ID 端到端完整性追踪 | 复合 ID = [L1EID \| L2EID]；PTW 完成后原样返回，L2TLB 用 L2EID 释放自身 MB Entry，用 L1EID 触发 L1DTLB 重查；多并发 Miss 时 ID 不交叉污染；TC：TC-L2PTW-ID-CHAIN-001, TC-L2PTW-ID-MULTI-MISS-001；SVA：sva_l2ptw_id_integrity | L2TLB_Interface.md §4.1/§4.2 |

**优先级汇总**：P0 共 4 条（F2.NEW.5, F2.NEW.6, F3.NEW.4, F3.NEW.5），P1 共 4 条。

---

## 4. 描述完善（6 条）

| F-ID | 完善内容 | 信息来源 |
|------|---------|---------|
| F2.3 | 新增 `credit_return` 接口说明：1-bit 脉冲信号（L2TLB 释放 credit 时拉高一拍）；L1DTLB 内部维护 3-bit 信用计数器跟踪可发送请求数量 | L1DTLB_Interfaces.md §2.3.1 |
| F2.12 | 新增 `jtlb_utlb_ref_pgs[2:0]` 说明：L2TLB 回填时携带 3-bit 页面大小编码（4KB/2MB/1GB），L1DTLB 据此存储正确页大小标识 | L1DTLB_Interfaces.md §2.3.2 |
| F3.4 | 新增 Tag 写入宽度说明：`arb_l2tlb_tag_din[47:0]`（48 bit），字段含 VPN、ASID、有效位、页大小标志 | L2TLB_Interface.md §3.2 |
| F3.5 | 新增 Data 写入宽度说明：`arb_l2tlb_data_din[41:0]`（42 bit），含 PPN 及权限/属性位 | L2TLB_Interface.md §3.2 |
| F3.12 | 新增 RRPV roundtrip 路径说明：L2TLB→Arbiter（`rrpv_updata[WAY_NUM×RRPV_WIDTH-1:0]`）→ L2TLB（`arb_l2tlb_rrpv_din`）；需验证此路径时序正确性及 wbuf 中间态一致性 | L2TLB_Interface.md §3.1/§3.2 |
| F3.13 | 新增复合 ID 语义说明：`l2tlb_ptw_id[L1EID_WIDTH+L2EID_WIDTH-1:0]` 高位=L1EID，低位=L2EID；通过 `ptw_l2tlb_ref_id` 原样返回并双向路由到 L1DTLB/L2TLB MB Entry | L2TLB_Interface.md §4.1/§4.2 |

---

## 5. 接口表补充（§2.3）

### 5.1 Row 3 信号补充

- **修改位置**：§2.3 外部接口分组表 Row 3（LSU Pipe0/1）
- **新增信号**：`mmu_lsu_sh{0,1}`（Shareable）、`mmu_lsu_so{0,1}`（StrongOrder）、`mmu_lsu_sec{0,1}`（Security/TrustZone）、`mmu_lsu_stall{0,1}`（流水线停顿）
- **来源**：L1DTLB_Interfaces.md §2.2.2/§2.2.4

### 5.2 Row 15 新增

- **新增行**：`| 15 | L1DTLB 状态广播 | OUT | dutlb_xx_mmu_off | v4.0 新增：L1DTLB 向下游广播 MMU 已关闭状态 |`
- **对应功能点**：F2.NEW.3

---

## 6. 影响分析

| 变更类型 | 数量 | 影响范围 |
|---------|------|---------|
| 错误修正（priority order） | 2 条（F5.1, F5.2） | 仲裁相关 TC 需检查对齐 |
| 规格/RTL 不一致（待确认） | 2 条（F2.17, F2.18） | 需设计方书面确认后更新 TC 期望行为 |
| 新增功能点 | 8 条（4×F2 + 4×F3） | 需新增对应 TC、covergroup、SVA；P0 共 4 条须优先实现 |
| 描述完善 | 6 条 | 不影响 TC 数量，完善现有 TC 约束边界 |
| 接口表补充 | 2 处 | §2.3 Row 3 + Row 15 |

---

## 7. 新增 TC 汇总

| TC-ID | 关联 F-ID | 优先级 | 简述 |
|-------|----------|--------|------|
| TC-DTLB-MMU-OFF-001 | F2.NEW.3 | P1 | MMU 关闭广播信号时序验证 |
| TC-DTLB-L2-IS-LOAD-001 | F2.NEW.4 | P1 | Load/Store 标志随 L2TLB 请求传递 |
| TC-L2REF-CMPLT-NO-PAVLD-001 | F2.NEW.5 | P0 | L2TLB 回填 cmplt=1 pavld=0（Page Fault）路径 |
| TC-PTWREF-CMPLT-ACCERR-001 | F2.NEW.6 | P0 | PTW Access Fault 时 ref_cmplt=1 ref_pavld=0 路径 |
| TC-PTWREF-CMPLT-PGFLT-001 | F2.NEW.6 | P0 | PTW Page Fault 时 ref_cmplt=1 ref_pavld=0 路径 |
| TC-L2TLB-CMP-VA-001/002/003 | F3.NEW.2 | P1 | 三种页大小下 cmp_with_va 控制位正确性 |
| TC-L2TLB-PTW-CMPLT-001 | F3.NEW.3 | P1 | PTW Refill 后 ptw_cmplt 脉冲时序 |
| TC-PTW-L2REF-NOVALID-001 | F3.NEW.4 | P0 | PTW→L2TLB 回填 cmplt=1 data_vld=0（pgflt/acc_err）路径 |
| TC-L2PTW-ID-CHAIN-001 | F3.NEW.5 | P0 | 复合 ID 端到端不变性追踪 |
| TC-L2PTW-ID-MULTI-MISS-001 | F3.NEW.5 | P0 | 多并发 Miss 时复合 ID 不交叉污染 |

---

## 8. 新增 SVA / Covergroup 汇总

| 名称 | 类型 | 关联 F-ID | 描述 |
|------|------|----------|------|
| `sva_mmu_off_no_req` | SVA | F2.NEW.3 | MMU 关闭时 L2TLB 不收到翻译请求 |
| `cg_dtlb_mmu_off` | CG | F2.NEW.3 | MMU on/off 状态覆盖 |
| `cg_l2tlb_req_type` | CG | F2.NEW.4 | Load/Store 请求类型覆盖 |
| `sva_l2ref_cmplt_pavld_excl` | SVA | F2.NEW.5 | `cmplt=0, pavld=1` 非法状态断言 |
| `cg_l2ref_dual_signal` | CG | F2.NEW.5 | L2TLB 回填双信号四种组合覆盖 |
| `sva_ptw_ref_pavld_when_no_err` | SVA | F2.NEW.6 | PTW 无错误时 ref_pavld 必须为 1 |
| `cg_ptw_ref_dual_signal` | CG | F2.NEW.6 | PTW→L1DTLB 回填双信号四种组合覆盖 |
| `sva_cmp_with_va_per_pgs` | SVA | F3.NEW.2 | 不同页大小下 cmp_with_va 正确性 |
| `cg_l2tlb_cmp_mode` | CG | F3.NEW.2 | cmp_with_va=0/1 × 三种页大小覆盖 |
| `sva_ptw_cmplt_after_refill` | SVA | F3.NEW.3 | Refill 写入后次周期 ptw_cmplt=1 |
| `cg_l2tlb_ptw_cmplt` | CG | F3.NEW.3 | ptw_cmplt 脉冲时序覆盖 |
| `sva_ptw_l2tlb_ref_cmplt_vld_legal` | SVA | F3.NEW.4 | `cmplt=0, data_vld=1` 非法状态断言 |
| `cg_ptw_l2ref_dual_signal` | CG | F3.NEW.4 | PTW→L2TLB 回填双信号四种组合覆盖 |
| `sva_l2ptw_id_integrity` | SVA | F3.NEW.5 | 复合 ID 全流程不变性断言 |
| `cg_l2ptw_id_coverage` | CG | F3.NEW.5 | ID 路由与多并发 Miss 场景覆盖 |
