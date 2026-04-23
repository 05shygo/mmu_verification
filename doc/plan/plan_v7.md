# MMU 验证计划变更记录 v7.0

| 字段 | 内容 |
|------|------|
| 版本 | v7.0 |
| 日期 | 2026-04-23 |
| 基于 | MMU_VerificationPlan_v3.md v6.0 |
| 变更依据 | RTL 修改：mbuf_entry.sv + ptw_mbuf.sv 三处改动 |

---

## 一、协议澄清：lsu_mmu_bus_error 与 lsu_mmu_data_vld 并发语义

**背景**：v3.0 在 F4.22/F4.42a 中描述"bus_error 或 data_vld 之一返回"暗示两者互斥。

**更正（v7.0）**：RTL 精读（mbuf_entry.sv）确认：
- `lsu_mmu_bus_error=1` **必然伴随** `lsu_mmu_data_vld=1` **同拍**到来
- `lsu_mmu_data_vld=1` 是 PTW→LSU 串行握手的**唯一**完成信号
- 总线错误时 `lsu_mmu_data[63:0]` 无效，但握手完成信号 `data_vld` 仍拉高
- 影响功能点：F4.22、F4.35、F4.42a

---

## 二、RTL 变更说明

### 变更 1：mbuf_entry.sv — mbuf_get 逻辑修订

**修改**：`mbuf_get` 置 1 条件新增 `(!lsu_mmu_bus_error)` 门控

旧：`if(mbuf_on & lsu_mmu_data_vld & (!write_back_grant)) mbuf_get <= 1'b1;`

新：`if(mbuf_on & lsu_mmu_data_vld & (!lsu_mmu_bus_error) & (!write_back_grant)) mbuf_get <= 1'b1;`

**原因**：bus_error=1 与 data_vld=1 同拍到来时，若 mbuf_get 被置 1，后续 write_back_req 会使用无效数据回填 TWU，导致错误 PTE 写入 TLB。

### 变更 2：mbuf_entry.sv — write_back_req / bus_err_write_back_req 双路径

区分 mbuf_on=1（检查实时 LSU 信号）与 mbuf_on=0（检查寄存 flop 信号）两路：

```
write_back_req = mbuf_vld & level_match & (mbuf_on & data_vld & !bus_error | mbuf_get)
bus_err_write_back_req = mbuf_vld & (mbuf_on & bus_error | mbuf_bus_err_flop) & !mask
```

### 变更 3：ptw_mbuf.sv — PDE Cache 更新时序及条件重构

**旧实现**：mbuf_cache_upd 由 lsu_mmu_data_vld 直接组合驱动，使用 ptw_chk_thd 判断叶 PTE。

**新实现**：引入 4 个内部寄存器，`|write_back_grant[8:0]` 拉高后**次周期**驱动 mbuf_cache_upd：
- `pde_updata_data_vld` — `|write_back_grant` 后 1 拍的脉冲
- `pde_updata_data_flop[DATA_WIDTH-1:0]` — 锁存 `mbuf_twu_data`
- `pde_updata_vpn[VPN_WIDTH-1:0]` — 锁存 `mbuf_twu_vpn`
- `pde_updata_lvl[2:0]` — 锁存 `mbuf_twu_lvl`

新更新条件：

```
mbuf_cache_upd = pde_updata_data_vld
              & pde_updata_data_flop[0]    // V=1
              & (!pde_updata_data_flop[1]  // R=0 非叶
              &  !pde_updata_data_flop[3]) // X=0 非叶
              & (!(pde_updata_data_flop[2] // W=0
              |   pde_updata_lvl[0]));     // lvl[0]=0（FST或SCD，非THD/4K叶级）
```

级别编码：3'b100=FST/1G（允许更新），3'b010=SCD/2M（允许更新），3'b001=THD/4K（禁止更新）

---

## 三、验证计划修改点概要

| 功能点 | 修改类型 | 主要内容 |
|--------|---------|---------|
| F4.22 | 重写 | 并发协议修订；mbuf_get !bus_error 门控；双路 write_back 说明 |
| F4.35 | 扩充 | bus_error 并发合法过渡状态；sva_mbuf_get_bus_err_mutex |
| F4.42a | 修订 | 移除"或 lsu_mmu_data_bus_error"互斥暗示；改为并发语义 |
| F4.NEW.1 | 重写 | 寄存路径 + pde_updata_lvl[0] 条件 + 新 TC/SVA/cg |

---

## 四、新增测试用例规格

| TC ID | 优先级 | 功能点 | 场景 |
|-------|--------|--------|------|
| TC-MBUF-BUS-ERR-CONCURRENT-001 | P0 | F4.22/F4.35 | bus_error=data_vld=1 同拍（mbuf_on=1 期间）→ mbuf_get=0, bus_err_flop→1, bus_err_write_back_req 拉高 |
| TC-MBUF-GET-NO-BUS-ERR-001 | P0 | F4.22/F4.35 | data_vld=1 & bus_error=0 → mbuf_get 置 1，write_back_req 正常拉高 |
| TC-PDE-CACHE-TIMING-001 | P1 | F4.NEW.1 | write_back_grant 后恰好 1 周期 mbuf_cache_upd 按条件生效 |
| TC-PDE-CACHE-LVL-001 | P1 | F4.NEW.1 | THD 级（lvl=3'b001）时 mbuf_cache_upd=0；FST/SCD 有效非叶时 mbuf_cache_upd=1 |

---

## 五、新增 SVA 断言规格

| SVA 名称 | 功能点 | 断言逻辑 |
|---------|--------|---------|
| sva_bus_err_with_data_vld | F4.22 | `@(posedge clk) lsu_mmu_bus_error \|-> lsu_mmu_data_vld` |
| sva_mbuf_get_not_set_on_bus_err | F4.22/F4.35 | `@(posedge clk) (mbuf_on & lsu_mmu_bus_error) \|-> ##1 !mbuf_get` |
| sva_mbuf_get_bus_err_mutex | F4.35 | `@(posedge clk) !(mbuf_get & mbuf_bus_err_flop)` |
| sva_pde_cache_one_cycle_delay | F4.NEW.1 | `@(posedge clk) \|write_back_grant[8:0] \|-> ##1 pde_updata_data_vld` |
| sva_pde_cache_no_leaf_entry | F4.NEW.1 | `@(posedge clk) pde_updata_lvl[0] \|-> !mbuf_cache_upd` |

---

## 六、新增 Covergroup 规格

### cg_mbuf_bus_err_concurrent（关联 F4.22/F4.35）
- cp_response：覆盖 {bus_error, data_vld}：2'b11 并发 / 2'b01 正常 / 2'b00 空闲
- cx_concurrent_vs_get：cross(cp_response, mbuf_get)

### cg_pde_cache_timing（关联 F4.NEW.1）
- cp_lvl_bit0：覆盖 pde_updata_lvl[0]（leaf=1 / nonleaf=0）
- cx_lvl_vs_upd：cross(cp_lvl_bit0, mbuf_cache_upd)

---

## 七、风险

| 风险 ID | 风险描述 | 缓解措施 |
|---------|---------|---------|
| R-V7.1 | bus_error 并发语义需设计方书面确认 | 追加设计文档确认 |
| R-V7.2 | mbuf_bus_err_flop 清零时机需 RTL 精读确认 | 阅读 mbuf_entry.sv 完整 always_ff |
| R-V7.3 | pde_updata 寄存路径 reset 后及连续 grant 时的边界行为 | 增加边界 TC |
