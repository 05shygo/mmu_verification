# Phase 8 M8 — Engineer A 审查项（vseq 与 ref_model / SB 接口）

> 供工程师 A 执行 TaskDivision Phase 8 退出表 **#4** 签字的核对清单。  
> B 方实现假定 **Phase 4–6 冻结** API；若审查中有偏差，在 MR/本文档中记录修订意见。

## 1. 参考模型与页表

- [ ] vseq 仅通过 `mmu_env::m_pt_mem::m_builder` 修改 shadow PT，与 DUT 侧 `m_ptw_mem.m_responder.set_page_table` 注入链一致。  
- [ ] `set_root` / `map_4k` / `inject_fault` / `invalidate` 调用与现网 `mmu_ref_model` 的 CSR+walk 行为一致。  
- [ ] **已知局限**：`map_2m` / `map_1g` 为 stub；`mmu_huge_page_mix_vseq` 已书面降级为 4K-only。  

## 2. 打分板

- [ ] 所有 vseq 在默认 `mmu_top_cfg` 下不引入 `mmu_translation_sb.m_mismatch`（`en_translation_sb=1` 时）。  
- [ ] `mmu_invalidate_sfence_matrix` 级 SFENCE 与 `sfence_during_walk` 行为不违 Phase 6 inv SVA 意图。  
- [ ] `mmu_credit_sb` 报告阶段仍为守恒 OK（`credit_l1i/l1d/ptw` 为 0 等），无激励侧协议违反。  

## 3. 统计（TaskDivision #3）

- [ ] 每条 vseq 结束 log 可 grep 到 `MMU_VSEQ_STATS` / `[MMU_VSEQ_TASKDIVISION#3]` 与 `mmu_perf` 报告。  
- [ ] 某字段为 0 时，在 Progress / waiver 中说明是「设计不观测」还是「未打满」。

**签字**：A ______________  日期 ______________  
