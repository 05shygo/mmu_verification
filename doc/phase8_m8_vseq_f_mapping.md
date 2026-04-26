# Phase 8 M8 — vseq ↔ VerificationPlan 功能点（F）映射

> 14 行一一对应 [MMU_UVM_TaskDivision.md](MMU_UVM_TaskDivision.md) Phase 8 退出表 #5。  
> 功能点 ID 以 [MMU_VerificationPlan_final.md](MMU_VerificationPlan_final.md) §6.3 为准（代表性 F 号）。  
> 2026-04-26 收口。

| vseq 类 | 代表性 F / 功能主题 | 说明 |
|--------|---------------------|------|
| `mmu_smoke_vseq` | F1–F3 翻译路径 | 缩短版 CSR→PMP→SysMap→4K 表 + IFU/LSU 混合 |
| `mmu_concurrent_3pipe_vseq` | F2 多通道 / LSU 并发 | 单 LSU 序列内 p0/p1/p2 轮询，避免多序列串行在单 sqr 上 |
| `mmu_ptw_thrash_vseq` | F4 PTW / miss | 大量 4K 映射 + 随机冷访问 |
| `mmu_sfence_during_walk_vseq` | F6 失效 + walk 窗 | 冷 LD 与 `sfence_vma_stress` 重叠 |
| `mmu_asid_context_switch_vseq` | F3 ASID / SATP | `cp0_satp_switch` 变 ASID + LD |
| `mmu_huge_page_mix_vseq` | F5/F6 大页 *（降规）* | `map_2m/1g` stub — **仅 4K 混排**，见 vseq 内 `UVM_INFO` |
| `mmu_rrpv_aging_vseq` | F7 替换/老化 | 长时 IFU+LSU 映射表访问（RRPV 白盒可观测性依 DUT/Phase 9） |
| `mmu_l2tlb_bank_conflict_vseq` | F7 L2 组织 | 扫 VPN[20:12] 分散访问（bank skew 争用 *意图*） |
| `mmu_satp_hotswap_vseq` | F3 根/模式 | SATP 写 + `satp_sel` toggle + LD |
| `mmu_stress_all_ports_vseq` | 跨 F1–F3 | `fork`：IFU ∥ interleave3，后接 STAMO；misc 初始化 |
| `mmu_power_gating_vseq` | 低功耗/时钟 *（降规）* | TB 无真 power gate — misc + HPCP + 短激励 |
| `mmu_reset_midtransaction_vseq` | F9 flush/abort | **软**路径：`misc_rtu_flush` + 冷 LD（非 `cpurst_b` 全片复位） |
| `mmu_error_rain_vseq` | F4/F10 fault | `inject_fault` + `map_4k` 恢复 + 已映射区 IFU/LSU（总线 err 率留 0 以免 ref 失配） |
| `mmu_perf_bench_vseq` | 性能统计 F11 | 长时 IFU+LSU 映射访问（`+VSEQ_NUM_TXN`） |

**42-run 产物路径**：`mmu_verification/output/logs/phase8_<VSEQ_NAME>_s<SEED>.log`（`make phase8` 自 `test_mmu_vseq_runner_<SEED>.log` 复制）。

**A 签字（ref_model / SB API）**：见同目录 [phase8_m8_a_review.md](phase8_m8_a_review.md)。
