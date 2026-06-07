# P7-B-01 — §10.1 黑盒 Covergroup 与 7 个 VIF 审计表

**范围**：[MMU_UVM_BuildPlan_v3_final.md](MMU_UVM_BuildPlan_v3_final.md) §10.1 表（行 2012–2022）与 `testbench/*/*_if.sv` 实现对照。

**结论**：VIF 位宽与 DUT/BuildPlan 一致；§10.1 所需信号在对应 interface 中**均有可用成员**。阻塞项**清零**（无待决 blocking gap）；实现上若某 coverpoint 用代理量（如 inv 的 PTW 进行中由 `mmu_lsu_tlb_busy` 代理、PMP「entry」映射到 8 端口之一），在对应 `*_covergroups.svh` 中已用注释标出。

---

## 1. 总表（采样事件 · Coverpoint · VIF/代理）

| BuildPlan Covergroup | 文件 | 触发（仿真侧） | Coverpoint / Cross（实现名） | VIF / 位域 |
| -------------------- | ---- | -------------- | ---------------------------- | ---------- |
| `cg_ifu_req` | ifu | `posedge clk` iff `ifu_mmu_va_vld` | `cp_va_seg` (va[62:39] 四档), `cp_abort` | `ifu_mmu_va[62:0]`, `ifu_mmu_abort` |
| `cg_ifu_rsp` | ifu | `posedge clk` iff `mmu_ifu_pavld` | `cp_pgflt`, `cp_deny`, `cp_sec`, `cp_ca`, `cx_pgflt_deny` | 对应 `mmu_ifu_*` |
| `cg_lsu_pipe0` / `cg_lsu_pipe1` / `cg_lsu_pipe2` | lsu | pipe0/1/2 各自 `va_vld`；pipe2 另含 `mmu_lsu_pa2_vld` 语义 | `cp_op`（LD=/ST=）, `cp_st_inst`, `cp_abort`, `cp_stall`/`cp_pa_vld`/`cp_pgflt`/`cp_access_fault`, pipe2: `cp_va2_vld`, `cp_pa2_vld`, `cp_pa2_err`, `cp_share2`, `cp_sec2`, crosses | `lsu_if` pipe0/1/2 域 |
| `cg_lsu_inv` | lsu | 任一 `lsu_mmu_tlb_*_inv` | `cp_kind`（四模式）, `cp_during_ptw`（`mmu_lsu_tlb_busy` 代理）, `cp_inv_lat`（到 `tlb_inv_done` 的周期分档）, `cx_kind_busy` | inv + `mmu_lsu_tlb_inv_done` + `mmu_lsu_tlb_busy` |
| `cg_cp0` | cp0 | `posedge clk` iff `wreg\|satp_wr\|priv/perm 变化` | `cp_priv`, `cp_mxr..satp_mode`, `cx_priv_mxr_sum_mprv` | `cp0_if` CSR/特权/广播 |
| `cg_pmp` | pmp | 每拍（或按需） | `cp_ent0..7`（flgs[0] 命中/有效）, `cp_acc0`, `cp_viol0`, `cx_ent_acc` | `pmp_if` `pmp_mmu_flg0..7` 等 |
| `cg_sysmap` | sysmap | `posedge clk` 上检测 **cfg 变更沿** | `cp_region_id`, `cp_attr` | `sysmap_cfg_if` `cfg_enable[]/cfg_flg[]`（无 RTL 网表） |
| `cg_hpcp` | misc | `posedge clk` iff `hpcp_mmu_cnt_en` | `cp_iutlb/dutlb/jtlb_miss` + `iff` 由选项保证 | `misc_if` HPCP 域 |
| `cg_ptw_rsp_kind` / `cg_rsp_delay_range` | ptw_mem | 响应完成拍 | `cp_kind` (normal/bus), `cp_delay` (req→vld/bus_err 周期间隔) | `ptw_mem_if` + CG 内延迟计数 |

---

## 2. 与表差异 / 非阻塞说明

| 项 | 说明 |
| -- | -- |
| IFU `va[62:39] 4 bin` | 对 24 位高地址做**四等分** bin（与 4 窗口一致）；非 4 个 one-hot 段类型。 |
| LSU `cp_op{LD,ST}` | 用 `!lsu_mmu_st_inst*` = LD、`*=1` = ST。 |
| LSU `cp_during_ptw` | 无显式 DUT 端口「正在 PTW」；采用 **`mmu_lsu_tlb_busy` 作代理**（L1DTLB MB 非空，BuildPlan/IF 注释与 Phase6 一致）。 |
| PMP `cp_entry_hit(0..7)` | 无单独「PMP entry 号」网表到 TB；**映射为 8 个 MMU 侧 PMP 端口的 `flg[0]` 有效/命中** 分量，满足「端口级」覆盖。 |
| SysMap | `sysmap_cfg_if` 为 **白盒配置影子**，与 driver `force` 路径一致，非 DUT 端口。 |

---

## 3. 与 A 侧合并（SVA）

- 5×`testbench/top/mmu_*.sv` + `credit_sva.sv` 已进 [mmu_verification/testbench/Files.f](mmu_verification/testbench/Files.f)（DUT 之后行），[tb_top.sv](mmu_verification/testbench/top/tb_top.sv) 内 `bind`；与 B 同一条 `make comp` 线。

## 4. 退出（P7-B-01）

- 本表 + 7 个 `*_covergroups.svh` 与上表 **可逐条对应**；无未关闭 **blocking** 缺失（未决走 JIRA/ waiver 的：无）。

