# MMU_VerificationPlan v6.0 — 变更记录

> **基准版本**：v5.0（MMU_Interfaces.md + MMU_PTW_Interface.md 接口对齐）
> **升级依据**：
> - `doc/MMU_Interfaces.md`（MMU 系统完整接口，含 PMP/sysmap 端口映射）
> - 用户补充说明 ①：**PMP 检查是 PTW 每次发 LSU 请求的前提**——PTW 必须先完成 PMP 权限检查，通过后才允许向 LSU 发出 PTE 加载请求。
> - 用户补充说明 ②：**sysmap 用于 PTW 模块的 CSR 属性获取**——MAEE=1 时直接使用页表数据中的属性字段，MAEE=0 时需通过 sysmap 查询 PA 所在内存区域（8 个区域之一）的默认属性；若 PA 跨越内存划分边界则强制页大小降级。
> - RTL 精读：`mmu/rtl/twu.sv`、`mmu/rtl/ptw.sv`、`mmu/rtl/ct_mmu_sysmap.v`、`mmu/rtl/sysmap.h`
>
> **修改文件**：`lc_test_plan_doc/MMU_VerificationPlan_v3.md`
> **日期**：2026-04-22

---

## 一、§2.3 接口表修改（Row 8 PMP 补注）

### 1.1 Row 8（PMP）— v6.0 补注：PTW 端口映射精化 + RTL typo 标注

**修改位置**：§2.3 Row 8 "作用" 列末尾（在 v5.0 [需设计确认] 注记之后追加）

**修改内容**：

- **PTW TWU 端口映射精化**（来自 RTL ptw.sv 精读）：
  - `mmu_pmp_pa3` / `pmp_mmu_flg3` → **twu_one**（ptw.sv:L291/L300）
  - `mmu_pmp_pa5` / `pmp_mmu_flg5` → **twu_two**（ptw.sv:L344/L353）
  - `mmu_pmp_pa6` / `pmp_mmu_flg6` → **twu_three**（ptw.sv:L397/L406）
  - `mmu_pmp_pa7` / `pmp_mmu_flg7` → **twu_four**（ptw.sv:L450/L459）
  - 端口号为 **3/5/6/7**（非 4/5/6/7），与 v5.0 注记中的 `pa4-7` 存在不一致，保留 `[需设计确认]` 标注

- **PTW PMP fetch 信号恒为 0**：PTW 读页表属于数据 Load，`mmu_pmp_fecth{3,5,6,7}` 对所有 PTW 端口恒为 0，PMP 使用 R-bit（flg[0]）检查；`mmu_pmp_fetch4` 已注释掉（v2.0 注记保留）

- **RTL 拼写 typo 标注**：`ptw.sv:L62` 端口名为 `mmu_pmp_fecth7`（缺少字母 `c`），其他端口 `mmu_pmp_fetch3/5/6` 拼写正确；testbench 接口绑定必须使用 typo 名称（详见 F7.NEW.8）

- **PMP 前置约束引用**：PTW 在 PMP 检查通过前不得向 LSU 发请求（详见 F7.NEW.3）

**来源**：`mmu/rtl/ptw.sv:L52-64`，用户补充说明 ①

---

### 1.2 §2.3 v6.0 接口补充段落

在 §2.3 接口表之后（v5.0 接口补充注记之后）追加 **v6.0 接口补充** 说明段落，内容如下：

1. **MAEE 双路选路**：`cp0_mmu_maee=1` → TWU 使用 PTE 扩展属性字段（`fst_chk_refill_req`），跳过 CSR FSM；`cp0_mmu_maee=0` → 进入 CSR FSM，通过 sysmap 获取默认内存区域属性（`fst_chk_csr_req`）（来自 twu.sv:L413/L424/L553/L560）

2. **sysmap CSR 属性替换**：MAEE=0 时，sysmap 返回的 `sysmap_mmu_flg[4:0]` 替换 CSR refill data 中 PTE 的 flag 字段（bit[60:56]），5-bit 编码：Sec/So/Buf/Ca/Sh（来自 twu.sv:L1086 + sysmap.h）

3. **PMP 前置于 LSU 请求**：TWU 每级（FST/SCD/THD）在发现叶 PTE 后，先发 PMP 检查请求，等 PMP 检查通过（`!pmp_deny`）后才允许下一步 LSU 请求；PMP deny → 直接 Access Fault，不发 LSU（来自 twu.sv:L243-246/L372-376/L961-964）

4. **sysmap 跨界检测**：CSR FSM 内 CRS1 阶段捕获大页起始地址 hit 向量（`twu_hit_num`），CRS2 阶段比较末尾地址 hit 向量；两次 hit 不同 → `twu_csr_cross=1` → 强制页大小降级（1G→2M 或 2M→4K）（来自 twu.sv:L1040-1055）

5. **PTW PMP 端口分配**：4 TWU 各独立 PMP 端口（pa3/5/6/7），`mmu_pmp_fecth7` RTL 拼写 typo 记录（来自 ptw.sv:L62；testbench 绑定必须使用 typo 名）

---

## 二、新增功能点——F4 侧（3 条）

### F4.NEW.12（P0）— TWU MAEE 双路属性选路

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L413, L424, L553, L560 |
| **TC** | TC-TWU-MAEE0-CSR-001, TC-TWU-MAEE0-CSR-002, TC-TWU-MAEE1-REFILL-001, TC-TWU-MAEE-SWITCH-001 |
| **SVA / 覆盖组** | sva_twu_maee_paths_mutex, cg_maee_leaf_level |

**描述**：

TWU 发现叶 PTE 时，根据 `cp0_mmu_maee` 单 bit 决定属性来源路径，两路互斥：

- **（A）MAEE=1 路径（扩展属性使能）**：触发 `fst_chk_refill_req = fst_chk_vld & fst_chk_leaf_vld & cp0_mmu_maee & (!fst_chk_page_flt)`（twu.sv:L413），直接使用 PTE 中的扩展属性字段（bit[63:8]）进行回填，**跳过 CSR FSM** 与 sysmap 查询。

- **（B）MAEE=0 路径（默认内存区域属性）**：触发 `fst_chk_csr_req = fst_chk_vld & fst_chk_leaf_vld & (!cp0_mmu_maee) & (!fst_chk_page_flt)`（twu.sv:L424），进入 CSR FSM（IDLE → 1G_CRS1 → 1G_CRS2 → ... → CSR_DATA_VLD），查询 sysmap 区域属性，用 `sysmap_mmu_flg[4:0]` 替换回填数据中的 flag 字段（见 F6.NEW.2）。

SCD/THD 级对称（twu.sv:L553/L560）。

**验证关注点**：
1. MAEE=1 时 `fst_chk_csr_req` 必须为 0（断言互斥）
2. MAEE=0 时 `fst_chk_refill_req` 必须为 0
3. 动态切换 MAEE：翻译途中切换 MAEE 不得导致属性乱序（依赖 CSR 写序列化）
4. MAEE=1 时 SCD/THD 级同样对称跳过 CSR FSM（交叉 F4.28 CSR FSM）

---

### F4.NEW.13（P0）— PMP 三级序列化检查——PTW 发 LSU 请求的前提

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L243-246, L961-964, L1001-1014 |
| **TC** | TC-TWU-PMP-SERIAL-001, TC-TWU-PMP-WAIT-STALL-001, TC-PTW-PMP-BEFORE-LSU-001, TC-PTW-PMP-DENY-STOP-REQ-001 |
| **SVA / 覆盖组** | sva_pmp_check_before_lsu_req, sva_pmp_deny_no_refill, cg_pmp_per_level_result |

**描述**：

TWU 每级（FST/SCD/THD）发现叶 PTE 时必须先发起 PMP 权限检查；同一 TWU 只有一个 PMP 端口，三级通过 `pmp_grant[2:0]` one-hot 分时复用（见 F4.NEW.14）。

**关键约束**：`fst_pmp_wait / scd_pmp_wait / thd_pmp_wait` 在 PMP 检查返回前阻塞对应流水级，且 `twu_mask = fst_pmp_wait | scd_pmp_wait | thd_pmp_wait | ...`（twu.sv:L243-246）——PMP 等待期间 TWU 整体阻塞。

**与 LSU 请求的顺序关系**：`mmu_lsu_data_req`（PTW 向 LSU 请求 PTE 加载）只能在当前级 PMP 检查**通过**（`!pmp_deny`）后才允许推进；PMP deny 时直接报 Access Fault（`twu_jtlb_ref_acc_err`），不发 LSU 请求（见 F7.NEW.3/F7.NEW.5）。

**验证关注点**：
1. FST 级 PMP deny 时，不得出现后续 SCD/THD 的 LSU 请求
2. 三级序列化顺序：FST PMP 完成 → SCD PMP → THD PMP，不得乱序
3. PMP wait 期间 `twu_mask=1`，xbar 不派发新请求（交叉 F4.NEW.6/F7.NEW.6）
4. PMP 检查通过后的 MBUF 请求时序（交叉 F4.NEW.10）

---

### F4.NEW.14（P1）— `pmp_grant[2:0]` one-hot 仲裁控制 `mmu_pmp_pa` 多路选择

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv:L1001-1014 |
| **TC** | TC-TWU-PMP-GRANT-ONEHOT-001, TC-PTW-PMP-PA-1G-001, TC-PTW-PMP-PA-2M-001, TC-PTW-PMP-PA-4K-001 |
| **SVA / 覆盖组** | sva_pmp_grant_onehot, cg_pmp_grant_level |

**描述**：

TWU 内部 `pmp_grant[2:0]` 为 one-hot 信号，控制向 PMP 模块发出的物理地址 `mmu_pmp_pa[27:0]` 的多路选择（twu.sv:L1001-1014）：

| pmp_grant | 页级 | mmu_pmp_pa 格式 |
|-----------|------|-----------------|
| `3'b100` | FST / 1G 叶 | `{satp_ppn[27:0], fst_pmp_vpn[26:18], 3'b0}`（1G 对齐，低 18 bit = 0） |
| `3'b010` | SCD / 2M 叶 | `{scd_pmp_ppn[27:0], scd_pmp_vpn[17:9], 3'b0}`（2M 对齐，低 9 bit = 0） |
| `3'b001` | THD / 4K 叶 | `{thd_pmp_ppn[27:0], thd_pmp_vpn[8:0], 3'b0}`（4K 对齐，全 28 bit 有效） |
| `3'b000` | 无有效请求 | 全零 |

`mmu_pmp_fecth` 同样受 `pmp_grant` 控制；PTW 数据读恒为 0（见 F7.NEW.7）。

**验证关注点**：
1. `pmp_grant[2:0]` 同周期最多 1 bit 有效（断言 one-hot）
2. 三种页大小 PA 格式位域正确（交叉 F7.NEW.4）
3. grant=3'b000 时 `mmu_pmp_pa` 为全零，不产生误判
4. PMP 模块接收 PA 后，`pmp_mmu_flg[3:0]` 在约定拍数内返回（时序约束，交叉 F7.NEW.3）

---

## 三、新增功能点——F6 侧（7 条）

### F6.NEW.1（P0）— MAEE 控制 TWU 进入 sysmap CSR 路径还是 PTE 直通路径

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L413, L424, L553, L560; ptw.sv |
| **TC** | TC-SYSMAP-MAEE0-ATTR-001, TC-SYSMAP-MAEE0-ATTR-002, TC-SYSMAP-MAEE1-SKIP-CSR-001 |
| **SVA / 覆盖组** | sva_twu_maee_paths_mutex, cg_maee_path |

**描述**：

当 `cp0_mmu_maee=0`（默认内存区域属性模式）时，TWU 在检测到叶 PTE 后不直接回填，而是触发 CSR FSM 请求（`fst_chk_csr_req`），通过 sysmap 查询 PA 所在的 8 个内存区域中的哪个，并获取该区域的默认属性（`sysmap_mmu_flg[4:0]`）；当 `cp0_mmu_maee=1`（扩展内存属性使能）时，直接使用 PTE 中的属性字段（`fst_chk_refill_req`），CSR FSM 不进入。

**核心意义**：sysmap 是 MAEE=0 时 PTW 叶 PTE 属性的唯一来源，决定最终回填到 TLB 中的内存属性（Cacheable/Bufferable/Shareable/Security/StrongOrder）。

**验证关注点**：
1. `cp0_mmu_maee=0` 时每次叶 PTE 发现都触发 sysmap 查询
2. `cp0_mmu_maee=1` 时 CSR FSM 不进入（`fst_chk_csr_req=0`）
3. 三种叶级别（FST/SCD/THD）分别触发 `fst/scd/thd_chk_csr_req`（对称结构）
4. MAEE 切换后已在飞请求的属性一致性（交叉 F4.NEW.12）

---

### F6.NEW.2（P0）— `sysmap_mmu_flg[4:0]` 替换 CSR refill data 中的 flag 字段

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1086; sysmap.h |
| **TC** | TC-SYSMAP-FLG-REFILL-001, TC-SYSMAP-FLG-REGION0-001, TC-SYSMAP-FLG-REGION7-001 |
| **SVA / 覆盖组** | cg_sysmap_flg_per_region, sva_csr_refill_flg_matches_sysmap |

**描述**：

MAEE=0 路径（CSR FSM）完成后，TWU 构造回填数据时用 `sysmap_mmu_flg[4:0]` **替换** PTE 中原始属性字段（bit[60:56]）：

```
csr_refill_data = {csr_data_flop[PPN+9:10], sysmap_mmu_flg[4:0], csr_data_flop[9:6], csr_data_flop[4:0]}
```
（twu.sv:L1086）

**sysmap flag 5-bit 编码**（sysmap.h）：

| bit | 含义 | 缩写 |
|-----|------|------|
| bit[4] | Security | Sec |
| bit[3] | StrongOrder | So |
| bit[2] | Bufferable | Buf |
| bit[1] | Cacheable | Ca |
| bit[0] | Shareable | Sh |

**各 region 默认 flag 值**：SYSMAP0/4/5/7 = `5'b01111`；SYSMAP1/2/6 = `5'b10000`；SYSMAP3 = `5'b01101`；无命中默认 = `5'b10011`（见 F6.NEW.7）。

**验证关注点**：
1. TLB 回填后属性字段与 sysmap 对应 region flag 位对位一致
2. MAEE=1 时回填数据**不包含** sysmap flag（由 PTE 原始属性填充）
3. 覆盖 8 个 region 的不同 flag 组合，确认属性正确传播到 IFU/LSU 输出

---

### F6.NEW.3（P0）— 跨界检测算法——两相 sysmap hit 比较

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1050-1055 |
| **TC** | TC-SYSMAP-CROSS-SAME-001, TC-SYSMAP-CROSS-1G-DIFF-001, TC-SYSMAP-CROSS-2M-DIFF-001, TC-SYSMAP-CROSS-PARTIAL-HIT-001 |
| **SVA / 覆盖组** | sva_sysmap_cross_degrade, cg_sysmap_cross_1g, cg_sysmap_cross_2m |

**描述**：

在 CSR FSM 的两阶段检查（CRS1/CRS2）中，sysmap 分别对大页的**起始地址**和**末尾地址** PA 进行区域查询，通过比较两次 hit 向量判断大页是否跨越内存区域边界：

- **CRS1 阶段**（TWU 状态 `1G_CRS1` 或 `2M_CRS1`）：捕获 `twu_hit_num[7:0] <= sysmap_mmu_hit[7:0]`（大页起始地址所在 region）（twu.sv:L1050-1053）
- **CRS2 阶段**（`1G_CRS2` 或 `2M_CRS2`）：再次查询大页末尾地址，计算 `twu_csr_cross = twu_crs2_chk && (twu_hit_num[7:0] != sysmap_mmu_hit[7:0])`（twu.sv:L1055）——两次 hit 向量不同即跨界

**跨界场景**：1G 页起始在 region A、末尾在 region B（或无命中）→ 跨界 → 触发降级（见 F6.NEW.4）。

**验证关注点**：
1. 不跨界：两次 hit 相同，`twu_csr_cross=0`，页大小保持（交叉 F6.NEW.4）
2. 1G 跨界：hit 不同，`twu_csr_cross=1`，触发 1G→2M 降级
3. 2M 跨界：同样检测，触发 2M→4K 降级
4. 一次 hit 有效一次无命中（无命中→默认 flag），也视为跨界
5. 4K 页不进入 CSR FSM，无需跨界检测（交叉 F4.28）

---

### F6.NEW.4（P0）— sysmap 跨界触发强制页大小降级

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1040-1048 |
| **TC** | TC-SYSMAP-DEGRADE-1G2M-001, TC-SYSMAP-DEGRADE-2M4K-001, TC-SYSMAP-NO-DEGRADE-1G-001, TC-SYSMAP-NO-DEGRADE-2M-001 |
| **SVA / 覆盖组** | sva_sysmap_cross_degrade, cg_sysmap_degrade_pgs |

**描述**：

跨界检测（见 F6.NEW.3）结果为 `twu_csr_cross=1` 时，TWU 强制降低页大小，以保证整个翻译区域属于同一内存 region（属性一致性约束）。降级逻辑（`csr_refill_pgs[2:0]` 寄存器更新，twu.sv:L1040-1048）：

- **初始赋值**：`csr_refill_pgs = {csr_grant[1:0], 1'b0}`（1G → `3'b100`，2M → `3'b010`）
- **1G 跨界降级**：`if (ptw_crs2_1g && ptw_chk_cross) csr_refill_pgs <= 3'b010`（降为 2M）
- **2M 跨界降级**：`if (ptw_crs2_2m && ptw_chk_cross) csr_refill_pgs <= 3'b001`（降为 4K）
- **不跨界**：维持原页大小

降级后回填到 L2TLB 的 `pgs` 字段使用降级后的值，确保 TLB 命中时覆盖范围不跨 region 边界。

**验证关注点**：
1. 1G 跨界 → 回填 pgs=`3'b010`（2M）而非 `3'b100`（1G）
2. 2M 跨界 → 回填 pgs=`3'b001`（4K）
3. 不跨界 1G/2M → 回填 pgs 保持 `3'b100`/`3'b010`
4. 降级后 PTW 仍使用正确的 PTE 数据（PPN 不变，仅 pgs 降级）
5. 降级次数统计覆盖（与 F4.18 巨页降级交叉）

---

### F6.NEW.5（P1）— PTW 向 sysmap 发送的 PA 按页级对齐

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv, ptw.sv |
| **TC** | TC-SYSMAP-PA-ALIGN-1G-001, TC-SYSMAP-PA-ALIGN-2M-001, TC-SYSMAP-PA-ALIGN-4K-001 |
| **SVA / 覆盖组** | cg_sysmap_pa_align |

**描述**：

TWU 在 CRS1/CRS2 阶段向 sysmap 发送的物理地址 `mmu_sysmap_pa[27:0]` 根据当前叶级别对齐：

| 叶级别 | PA 对齐 | 低位清零 |
|--------|---------|---------|
| FST（1G 叶） | 1G 对齐 | bit[17:0] = 0 |
| SCD（2M 叶） | 2M 对齐 | bit[8:0] = 0 |
| THD（4K 叶） | 4K 对齐 | 全 28 bit 有效 |

CRS1 发送起始地址，CRS2 发送末尾地址（起始 + 页大小 - 4K），确保跨界检测地址范围完整，不溢出下一个 4K 边界。PA 对齐格式与 PMP PA 一致（交叉 F7.NEW.4）。

**验证关注点**：
1. 1G 页 PA 低 18 bit 恒为 0
2. 2M 页 PA 低 9 bit 恒为 0
3. 4K 页 PA 全 28 bit 有效
4. CRS2 末尾地址正确（不溢出，不越过下一 4K 边界）
5. sysmap PA 与 PMP PA 对齐格式一致（交叉 F7.NEW.4）

---

### F6.NEW.6（P1）— 4 TWU 实例各自独立 sysmap 端口并发查询

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P1 |
| **RTL 参考** | ptw.sv:L289-290, L342-343, L395-396, L448-449 |
| **TC** | TC-SYSMAP-4TWU-CONCURRENT-001, TC-SYSMAP-TWU-PORT-MAP-001 |
| **SVA / 覆盖组** | cg_sysmap_4twu_concurrent |

**描述**：

`ptw.sv` 中 4 个 TWU 实例分别连接到独立的 sysmap PA/flg/hit 端口：

| TWU 实例 | PA 端口 | flg 端口 | hit 端口 |
|----------|---------|---------|---------|
| twu_one | `mmu_sysmap_pa3` | `sysmap_mmu_flg3` | `sysmap_mmu_hit3` |
| twu_two | `mmu_sysmap_pa5` | `sysmap_mmu_flg5` | `sysmap_mmu_hit5` |
| twu_three | `mmu_sysmap_pa6` | `sysmap_mmu_flg6` | `sysmap_mmu_hit6` |
| twu_four | `mmu_sysmap_pa7` | `sysmap_mmu_flg7` | `sysmap_mmu_hit7` |

端口号为 **3/5/6/7**（非连续，非 4/5/6/7）。4 路完全独立，允许 4 个 TWU 在同一周期各自进行不同 PA 的 sysmap 查询，互不阻塞。

**注意**：sysmap 为纯组合逻辑，4 路查询同周期结果独立有效，无内部仲裁。

**验证关注点**：
1. 4 TWU 同周期并发 sysmap 查询时，各路 hit/flg 独立正确
2. 端口号 3/5/6/7 映射关系正确（TWU one=3，TWU two=5，TWU three=6，TWU four=7）
3. sysmap 实例为纯组合逻辑，4 路查询无冲突（与 F6.NEW.3 跨界检测交叉）

---

### F6.NEW.7（P2）— sysmap 无命中时默认 flag = `5'b10011`

| 属性 | 内容 |
|------|------|
| **模块** | `ct_mmu_sysmap` |
| **优先级** | P2 |
| **RTL 参考** | ct_mmu_sysmap.v:L155 |
| **TC** | TC-SYSMAP-NO-HIT-DEFAULT-001, TC-SYSMAP-DEFAULT-FLAG-BIT-001 |
| **SVA / 覆盖组** | cg_sysmap_default_flag |

**描述**：

当物理地址 PA 不属于已配置的 8 个 region 中的任何一个时（`casez` default 分支，ct_mmu_sysmap.v:L155），sysmap 返回默认 flag `5'b10011`（Sec=0/So=1/Buf=0/Ca=0/Sh=1，含义：可共享、不可缓存、强排序，保守属性配置）。

此默认值在 MAEE=0 时会被回填到 TLB 属性字段，影响所有未在 sysmap 中配置的物理地址区域的内存属性。

**验证关注点**：
1. PA 落在所有 region 范围外时 `sysmap_mmu_flg = 5'b10011`
2. 所有 8 个 sysmap hit 均为 0 时 `sysmap_mmu_hit[7:0] = 8'b0`（与 F6.3 hit 唯一性交叉）
3. 无命中 + MAEE=0 时 TLB 回填属性为 So=1/不可缓存（不产生不安全的缓存行）

---

## 四、新增功能点——F7 侧（7 条）

### F7.NEW.3（P0）— PMP 检查是 PTW 发 LSU 请求的前提——顺序约束

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L243-246 |
| **TC** | TC-PTW-PMP-BEFORE-LSU-001, TC-PTW-PMP-DENY-STOP-REQ-001, TC-PTW-PMP-WAIT-NO-LSU-001 |
| **SVA / 覆盖组** | sva_pmp_check_before_lsu_req, sva_no_lsu_req_during_pmp_wait |

**描述**：

PTW 每次向 LSU 发起 PTE 数据读请求（`mmu_lsu_data_req=1`）之前，必须已完成对应级别的 PMP 权限检查。机制：当 TWU 在某级（FST/SCD/THD）发现叶 PTE 且需要继续 walk 时，先通过 `pmp_grant[2:0]` 发出 PMP 请求，在 `fst/scd/thd_pmp_wait` 阻塞对应流水级期间，**任何新的 `mmu_lsu_data_req` 不得拉高**；PMP 检查通过（`!pmp_deny`）后，才允许推进流水线并最终发出 LSU 读请求。

PMP deny 时：直接报 Access Fault，不产生 LSU 请求（见 F7.NEW.5）。此顺序约束通过 `twu_mask` 信号（包含 `pmp_wait` 分量，见 F7.NEW.6）体现，防止 xbar 向阻塞中的 TWU 派发新请求，间接阻止提前发出 LSU 访问。

**验证关注点**：
1. 在 `pmp_wait=1` 的任意周期，`mmu_lsu_data_req` 必须为 0（SVA 断言）
2. PMP 返回后的下一周期，LSU 请求可合法拉高
3. PMP deny 场景下，整个 TWU 流水线不产生 LSU 请求，并报 Access Fault（交叉 F4.NEW.13/F7.NEW.5）

---

### F7.NEW.4（P0）— PTW 各级 PMP 检查的 PA 格式——页级对齐

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L1001-1014 |
| **TC** | TC-PTW-PMP-PA-1G-001, TC-PTW-PMP-PA-2M-001, TC-PTW-PMP-PA-4K-001, TC-PTW-PMP-PA-ZERO-001 |
| **SVA / 覆盖组** | sva_pmp_grant_onehot, cg_pmp_pa_format |

**描述**：

TWU 每个流水级向 PMP 发送的物理地址 `mmu_pmp_pa[27:0]` 格式由 `pmp_grant[2:0]` 多路选择（twu.sv:L1001-1014）：

| pmp_grant | 叶级别 | PA 格式 | 对齐 |
|-----------|--------|---------|------|
| `3'b100` | FST / 1G | `{satp_ppn[27:0], fst_pmp_vpn[26:18], 3'b0}` | 1G 对齐（低 18 bit = 0） |
| `3'b010` | SCD / 2M | `{scd_pmp_ppn[27:0], scd_pmp_vpn[17:9], 3'b0}` | 2M 对齐（低 9 bit = 0） |
| `3'b001` | THD / 4K | `{thd_pmp_ppn[27:0], thd_pmp_vpn[8:0], 3'b0}` | 4K 对齐（全 28 bit 有效） |
| `3'b000` | 无有效请求 | 全零 | — |

PMP 据此判断对应物理地址的访问权限（R/W/X/L），反馈 `pmp_mmu_flg[3:0]`。PA 对齐格式与 sysmap PA 格式一致（交叉 F6.NEW.5）。

**验证关注点**：
1. grant=3'b100 时 PA 低 18 bit 为 0
2. grant=3'b010 时 PA 低 9 bit 为 0
3. grant=3'b001 时 PA 全 28 bit 有效
4. PA 与 `mmu_lsu_data_req_addr[39:0]` 高 28 bit 一致性（交叉 F7.4/F7.10）
5. PMP 模块在同一周期仅接受一路 PA（per-TWU 单端口，交叉 F4.NEW.14）

---

### F7.NEW.5（P0）— PMP deny → TWU Access Fault → L2TLB 异常直通

| 属性 | 内容 |
|------|------|
| **模块** | `twu` → `mmu_l2tlb` |
| **优先级** | P0 |
| **RTL 参考** | twu.sv:L372-376, L961-964; mmu_l2tlb.sv |
| **TC** | TC-PTW-PMP-DENY-ACCFLT-001, TC-PTW-PMP-DENY-NO-REFILL-001, TC-PTW-PMP-MMODE-L0-001, TC-PTW-PMP-MMODE-L1-001 |
| **SVA / 覆盖组** | sva_pmp_deny_acc_fault, sva_pmp_deny_no_lsu_req, cg_pmp_deny_by_level |

**描述**：

PMP 返回 `pmp_mmu_flg[3:0]` 后，TWU 根据访问类型检查权限（twu.sv:L372-376）：

```
pmp_deny = (fetch && !flg[2]) || (load && !flg[0]) || (store && !flg[1]) || (pref && !flg[0])
```

**M-mode 特殊规则**：处于 M-mode 且 L-bit（flg[3]）=0 时，PMP 检查被绕过（Sv39 规范）；L=1 时检查生效。

PMP deny 时：
1. TWU 不发出 LSU 请求、不进行回填
2. 记录 Access Fault：`twu_acc_err_vld <= 1'b1`（twu.sv:L961-964）
3. 通过 `twu_jtlb_ref_acc_err` + `twu_jtlb_ref_acc_err_id[6:0]` + `twu_jtlb_ref_acc_err_type[2:0]` **直接发往 L2TLB，绕过 mmu_arb**（交叉 F4.NEW.9）

**PTW 访问页表为数据 Load**，使用 R-bit（flg[0]）检查，R=0 则产生 Access Fault。

**验证关注点**：
1. PTW 访问 R=0 的 PMP region → Access Fault，不产生 LSU 请求（交叉 F7.NEW.3）
2. M-mode + L=0 → PMP 检查被绕过，不产生 Access Fault
3. M-mode + L=1 → PMP 检查生效
4. Access Fault 后对应 miss entry 正确释放（与 F4.48/F4.NEW.9 交叉）
5. Access Fault 与 Page Fault 互斥（同一次遍历只报一种异常）

---

### F7.NEW.6（P1）— PMP wait 状态触发 `twu_xbar_mask`

| 属性 | 内容 |
|------|------|
| **模块** | `twu` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv:L243-246; ptw.sv |
| **TC** | TC-TWU-MASK-PMP-WAIT-001, TC-TWU-MASK-ALL4-PMP-001 |
| **SVA / 覆盖组** | sva_pmp_wait_implies_mask, cg_twu_mask_cause |

**描述**：

`twu_mask`（接口规格对外名 `twu_xbar_mask`）的生成逻辑包含所有 PMP 等待状态分量（twu.sv:L243-246）：

```
twu_mask = fst_pmp_wait | scd_pmp_wait | thd_pmp_wait
         | (fst_chk_vld & !fst_leaf & !scd_pmp_wait)
         | (scd_chk_vld & !scd_leaf & !thd_pmp_wait)
```

其中 `fst/scd/thd_pmp_wait` 在对应级别 PMP 检查请求已发出但尚未获得 grant 时为高。

**传播链**：PMP wait → `twu_mask=1` → `ptw_l2tlb_ready` 在全部 4 TWU mask 时拉低（见 F4.NEW.6）→ L2TLB 停止发送新 PTW 请求。

**与 `twu_idle` 的区别**：`twu_mask` 反映"正在 PMP 检查中"；`twu_idle=1` 时 `twu_mask=0`，但反之不成立（交叉 F4.NEW.7）。

**验证关注点**：
1. PMP wait 期间 `twu_mask` 必须为 1
2. PMP grant 返回后的下一周期 `twu_mask` 可降低（若无其他阻塞）
3. 4 TWU 全 PMP wait 时 `ptw_l2tlb_ready=0`（压力场景，交叉 F4.NEW.6）

---

### F7.NEW.7（P1）— PTW PMP 端口 `mmu_pmp_fecth` 恒为 0

| 属性 | 内容 |
|------|------|
| **模块** | `twu` + `ptw` |
| **优先级** | P1 |
| **RTL 参考** | twu.sv:L1001-1014; ptw.sv:L61-64 |
| **TC** | TC-PTW-PMP-FETCH-ZERO-001, TC-PTW-PMP-R-CHECK-001 |
| **SVA / 覆盖组** | sva_ptw_pmp_fetch_zero |

**描述**：

PTW 通过 TWU 发起的 PMP 检查属于**数据读取**（Load PTE from memory），因此 `mmu_pmp_fecth`（注意 typo，详见 F7.NEW.8）对所有 4 个 PTW PMP 端口（pa3/5/6/7）恒为 0。`pmp_mmu_flg[2]`（X bit）在 `pmp_deny` 计算中用于 fetch type，PTW 不使用该路径，而是检查 `pmp_mmu_flg[0]`（R bit，因为 PTE 是 Load 操作）。

**验证关注点**：
1. 所有 PTW PMP 检查场景下，`mmu_pmp_fecth{3,5,6,7}` 均为 0
2. PMP 模块接收 fetch=0 后，使用 R-bit 而非 X-bit 进行权限判断
3. R=0 且 fetch=0（数据访问）→ 产生 Access Fault（交叉 F7.NEW.5）

---

### F7.NEW.8（P1）— RTL 拼写 typo：`mmu_pmp_fecth7`

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P1 |
| **RTL 参考** | ptw.sv:L62 |
| **TC** | TC-PTW-PMP-TYPO-BIND-001 |
| **SVA / 覆盖组** | — |

**描述**：

`ptw.sv` 第 62 行端口声明为 `output logic mmu_pmp_fecth7`（缺少字母 `c`，应为 `mmu_pmp_fetch7`），而其他端口 `mmu_pmp_fetch3/5/6`（ptw.sv:L61-64）拼写正确。此 RTL typo 必须在 testbench 接口绑定时使用**错误拼写名称** `mmu_pmp_fecth7`，否则端口连接失败（仿真时 0 驱动信号）。实例化时 twu_four 内部也使用 typo 名（ptw.sv:L459-460）。

**验证关注点**：
1. UVM pmp_agent 中 port7（twu_four）的 fetch 监控端口绑定必须使用 `mmu_pmp_fecth7` 而非 `mmu_pmp_fetch7`
2. 建议在 UVM interface 中添加 `// RTL typo: should be fetch7` 注释标记以提醒后续维护者
3. 建议向设计团队提交 typo 修复 ECO（不影响功能，仅命名问题）

---

### F7.NEW.9（P1）— PTW 4 TWU PMP 端口分配（pa3/5/6/7）

| 属性 | 内容 |
|------|------|
| **模块** | `ptw` |
| **优先级** | P1 |
| **RTL 参考** | ptw.sv:L52-64, L291, L300, L344, L353, L397, L406, L450, L459 |
| **TC** | TC-PTW-PMP-PORT-MAP-001, TC-PTW-PMP-PORT-CONCURRENT-001 |
| **SVA / 覆盖组** | cg_ptw_pmp_port_map |

**描述**：

PTW PMP 端口分配（ptw.sv 确认）：

| TWU 实例 | PA 端口 | flg 端口 | fetch 端口 | RTL 行号 |
|----------|---------|---------|-----------|----------|
| twu_one | `mmu_pmp_pa3` | `pmp_mmu_flg3` | `mmu_pmp_fetch3` | L291/L300 |
| twu_two | `mmu_pmp_pa5` | `pmp_mmu_flg5` | `mmu_pmp_fetch5` | L344/L353 |
| twu_three | `mmu_pmp_pa6` | `pmp_mmu_flg6` | `mmu_pmp_fetch6` | L397/L406 |
| twu_four | `mmu_pmp_pa7` | `pmp_mmu_flg7` | `mmu_pmp_fecth7` ⚠ | L450/L459 |

**关键注意**：端口号为 **3/5/6/7**（非 4/5/6/7），与 LSU/IFU 端口（pa0/1/2）不连续；pa4 功能归属存在歧义（`MMU_Interfaces.md §2.4.2` 与 `MMU_PTW_Interface.md` 描述出入，保留 `[⚠ 需设计确认]` 标注）。

**验证关注点**：
1. `pmp_mmu_flg3` 反馈给 twu_one（非 twu_two），端口映射不得错位
2. UVM pmp_agent 必须按正确映射驱动各端口（交叉 F7.NEW.8 typo）
3. 4 TWU 同时发出 PMP 请求时，4 路 pa/flg 信号独立正确（交叉 F7.1 并发独立性）
4. sysmap 端口与 PMP 端口映射一致（均为 3/5/6/7，交叉 F6.NEW.6）

---

## 五、设计待确认事项（v6.0 新增）

### DA-003（P0）— PMP 端口 3 / pa3 归属最终确认

| 项目 | 内容 |
|------|------|
| **继承自** | v5.0 DA-001 |
| **问题描述** | v6.0 RTL 精读（ptw.sv:L291）确认 PTW 使用 pa3，但 `MMU_Interfaces.md §2.4.2` 仍显示 pa3=IFU 取指；两者冲突，保留 `[⚠ 需设计确认]` 标注。 |
| **影响范围** | 若 pa3=PTW，则 IFU PMP 端口编号需重新确认；UVM pmp_agent 端口映射表须同步修正。 |
| **建议** | 设计方给出最终 Port 0~7 功能分配表（含 pa4 归属），并修正接口规格文档。 |

---

## 六、修改统计

| 类别 | 数量 |
|------|------|
| §2.3 接口表 Row 级修改 | 1 处（Row 8 PMP 补注） |
| §2.3 注记追加 | 1 处（v6.0 段落） |
| 新增功能点 F4 侧 | 3 条（F4.NEW.12 / F4.NEW.13 / F4.NEW.14） |
| 新增功能点 F6 侧 | 7 条（F6.NEW.1 ~ F6.NEW.7） |
| 新增功能点 F7 侧 | 7 条（F7.NEW.3 ~ F7.NEW.9） |
| **合计新增功能点** | **17 条** |
| 新增 TC | 40 条 |
| 新增 SVA / 覆盖组 | 20 条 |
| 设计待确认项 | 1 项（DA-003，继承并精化 v5.0 DA-001） |

### 新增 TC 汇总

| 类别 | TC 编号 |
|------|---------|
| MAEE 双路选路 | TC-TWU-MAEE0-CSR-001/002, TC-TWU-MAEE1-REFILL-001, TC-TWU-MAEE-SWITCH-001 |
| PMP 三级序列化 | TC-TWU-PMP-SERIAL-001, TC-TWU-PMP-WAIT-STALL-001, TC-PTW-PMP-BEFORE-LSU-001, TC-PTW-PMP-DENY-STOP-REQ-001 |
| PMP PA 格式 | TC-TWU-PMP-GRANT-ONEHOT-001, TC-PTW-PMP-PA-1G-001, TC-PTW-PMP-PA-2M-001, TC-PTW-PMP-PA-4K-001, TC-PTW-PMP-PA-ZERO-001 |
| sysmap 路径控制 | TC-SYSMAP-MAEE0-ATTR-001/002, TC-SYSMAP-MAEE1-SKIP-CSR-001 |
| sysmap flag 替换 | TC-SYSMAP-FLG-REFILL-001, TC-SYSMAP-FLG-REGION0-001, TC-SYSMAP-FLG-REGION7-001 |
| sysmap 跨界检测 | TC-SYSMAP-CROSS-SAME-001, TC-SYSMAP-CROSS-1G-DIFF-001, TC-SYSMAP-CROSS-2M-DIFF-001, TC-SYSMAP-CROSS-PARTIAL-HIT-001 |
| sysmap 降级 | TC-SYSMAP-DEGRADE-1G2M-001, TC-SYSMAP-DEGRADE-2M4K-001, TC-SYSMAP-NO-DEGRADE-1G-001, TC-SYSMAP-NO-DEGRADE-2M-001 |
| sysmap PA 对齐 | TC-SYSMAP-PA-ALIGN-1G-001, TC-SYSMAP-PA-ALIGN-2M-001, TC-SYSMAP-PA-ALIGN-4K-001 |
| sysmap 并发 | TC-SYSMAP-4TWU-CONCURRENT-001, TC-SYSMAP-TWU-PORT-MAP-001 |
| sysmap 无命中 | TC-SYSMAP-NO-HIT-DEFAULT-001, TC-SYSMAP-DEFAULT-FLAG-BIT-001 |
| PMP deny → Access Fault | TC-PTW-PMP-WAIT-NO-LSU-001, TC-PTW-PMP-DENY-ACCFLT-001, TC-PTW-PMP-DENY-NO-REFILL-001, TC-PTW-PMP-MMODE-L0-001, TC-PTW-PMP-MMODE-L1-001 |
| PMP wait → twu_mask | TC-TWU-MASK-PMP-WAIT-001, TC-TWU-MASK-ALL4-PMP-001 |
| PTW fetch=0 | TC-PTW-PMP-FETCH-ZERO-001, TC-PTW-PMP-R-CHECK-001 |
| RTL typo 绑定 | TC-PTW-PMP-TYPO-BIND-001 |
| PTW 端口映射 | TC-PTW-PMP-PORT-MAP-001, TC-PTW-PMP-PORT-CONCURRENT-001 |

### 新增 SVA / 覆盖组汇总

| 信号 / 模块 | SVA / cg 名称 |
|-------------|--------------|
| MAEE 路径互斥 | sva_twu_maee_paths_mutex, cg_maee_leaf_level, cg_maee_path |
| PMP 检查先于 LSU | sva_pmp_check_before_lsu_req, sva_no_lsu_req_during_pmp_wait |
| PMP deny 无 LSU | sva_pmp_deny_no_refill, sva_pmp_deny_no_lsu_req |
| PMP grant one-hot | sva_pmp_grant_onehot, cg_pmp_grant_level, cg_pmp_per_level_result |
| PMP PA 格式 | cg_pmp_pa_format |
| sysmap CSR refill 匹配 | sva_csr_refill_flg_matches_sysmap, cg_sysmap_flg_per_region |
| sysmap 跨界降级 | sva_sysmap_cross_degrade, cg_sysmap_cross_1g, cg_sysmap_cross_2m, cg_sysmap_degrade_pgs |
| sysmap PA 对齐 | cg_sysmap_pa_align |
| sysmap 并发查询 | cg_sysmap_4twu_concurrent |
| sysmap 无命中默认 | cg_sysmap_default_flag |
| PMP deny → Access Fault | sva_pmp_deny_acc_fault, cg_pmp_deny_by_level |
| PMP wait → mask | sva_pmp_wait_implies_mask, cg_twu_mask_cause |
| PTW fetch 恒零 | sva_ptw_pmp_fetch_zero |
| PTW 端口映射 | cg_ptw_pmp_port_map |
