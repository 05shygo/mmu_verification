# Phase 8-B Preflight（Stage 0）— 可开工清单

> 依据：[MMU_UVM_BuildPlan_v3_final.md](MMU_UVM_BuildPlan_v3_final.md) §3.1 / §8.6–8.7、[MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md) §3 Phase 8、本仓库现网 `mmu_env` / 各 `*_sequences.svh`。
> 日期：2026-04-26

## 1. 虚拟定序器六路与 `m_env` 句柄对齐

| 虚拟定序器成员（`mmu_virtual_sequencer`） | 连接目标（`mmu_env`） | Agent `m_sequencer` |
|---------------------------------------------|------------------------|----------------------|
| `ifu_sqr` | `m_ifu.m_sequencer` | IFU |
| `lsu_sqr` | `m_lsu.m_sequencer` | LSU |
| `cp0_sqr` | `m_cp0.m_sequencer` | CP0 |
| `pmp_sqr` | `m_pmp.m_sequencer` | PMP |
| `sysmap_sqr` | `m_sysmap_cfg.m_sequencer` | SysMap |
| `misc_sqr` | `m_misc.m_sequencer` | Misc |
| *（无）* | *`m_ptw_mem` 为 responder* | ptw_mem **无定序器**；页表/故障经 `m_pt_mem.m_builder` 与 DUT 侧 walk 行为间接驱动 |

**阻塞项**：无 — 现网 6 个 active agent 均暴露 `m_sequencer`，`m_ptw_mem` 与 `m_pt_mem` 已在 `mmu_env` 中实例化并注入 responder/ref。

## 2. Phase 7 整体验收 → Phase 8 解锁

| 门闩 | 状态 |
|------|------|
| M7（covergroup + SVA + `make phase7` 口径） | ✅ 与 [MMU_Progress.md](MMU_Progress.md) 表一致，不阻塞 vseq 集成 |
| ref_model / translation_sb / invalidate_sb / credit_sb API 冻结 | ✅ 以现网头文件与 Phase 4–6 用例行为为准 |
| 硬件 `map_2m` / `map_1g` 完整语义的 Phase 4 要求 | **仍多为 stub/骨架**（见 `page_table_builder.svh` 注释）— `mmu_huge_page_mix_vseq` 采用 **仅 4K 混排** 并在映射表/注释中标 **局限与 F-ID**，不伪造 2M/1G 覆盖 |

## 3. 14 行 vseq → 基础 sequence / 配置步骤（草图 + 风险）

| # | vseq | 主要复用 / 配置步骤 | 风险与说明 |
|---|------|----------------------|------------|
| 1 | `mmu_smoke_vseq` | `cp0_tlb_allinv` → PMP allow → SysMap off → `cp0_reg_rw` SATP0 → `tlb_inv_all` SFENCE → `map_4k` 批量 → 短 `ifu` + LSU p0/1 | 低；对齐 `test_mmu_translation_sanity` 缩时版 |
| 2 | `mmu_concurrent_3pipe_vseq` | 同上建表后 `fork`：`lsu_mapped_va` p0 / p1 / `lsu_p2_sanity` 等，遵守 IFU 单未决 hold | 中；IFU/LSU 协议：IFU 保持顺序 |
| 3 | `mmu_ptw_thrash_vseq` | 多 4K 映射 + 大 VPN 步进/随机重访，强制 miss→PTW | 中；`num_txn` 约束深度 |
| 4 | `mmu_sfence_during_walk_vseq` | 冷 miss 流量 + 延迟窗口内 `tlb_inv_*` / SFENCE（对齐 Phase6 abort 时序思想） | 中；与 inv SVA 一致 |
| 5 | `mmu_asid_context_switch_vseq` | `m_builder.set_root` + 多 ASID `cp0_satp_switch` 交替 | 中；SATP 与 ref 镜像一致 |
| 6 | `mmu_huge_page_mix_vseq` | **2M/1G stub** → 仅 4K+多 pipe/IFU 混排；文档标局限 | 高已降级 |
| 7 | `mmu_rrpv_aging_vseq` | 长随机 IFU+LSU（`lsu_back2back` 等） | 低/中；DUT 可观测 RRPV 有限则在 Close 文档说明 |
| 8 | `mmu_l2tlb_bank_conflict_vseq` | VA[20:12] 扫行以拉散 bank/集合 | 低 |
| 9 | `mmu_satp_hotswap_vseq` | `cp0_satp_switch` / `cp0_satp_sel_toggle` + 每根 SATP 下重建/切换映射 | 中 |
|10 | `mmu_stress_all_ports_vseq` | `fork-join`：IFU+LSU 全 pipe+STAMO+轻量 `misc` | 中；须满足 credit 协议 |
|11 | `mmu_power_gating_vseq` | `misc_init`+HPCP；TB **无真 power gate** — 仅可达 DFT/idle 类激励 + 文档 | 低（声明型） |
|12 | `mmu_reset_midtransaction_vseq` | **非全芯片 reset**：`misc_rtu_flush` + 冷 miss/搬运（同 Phase6 RTU 用例） | 中；不用 `cpurst_b` 全 TB |
|13 | `mmu_error_rain_vseq` | `page_table_builder::inject_fault` + 可恢复重映射；PTW `m_bus_error_rate_permille` 低占空**可选** | 中；SB 与 ref 须一致 |
|14 | `mmu_perf_bench_vseq` | 长时混跑 + 统计钩（HPCP/PTW/txn） | 低 |

## 4. 退出（Stage 0）

- B 自审：上表六路/阻塞/高风险项可定位到具体文件与 API。  
- **无 blocking 层次名错误**；可进入 Stage 1 编码（`m_vseqr` 集成）。  

A 快速 eyeball：建议非强制。  

**A Review（M8 收口）**见 Stage 11 / `doc/phase8_m8_vseq_f_mapping.md`。
