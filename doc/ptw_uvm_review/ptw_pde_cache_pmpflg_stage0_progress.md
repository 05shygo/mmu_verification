# PTW PDE Cache PMP Flag Stage 0 Progress

## 当前状态

`PMPFLG_STAGE_DONE stage=0 name=semantic_freeze_and_probe_audit`

状态：done

本阶段只完成语义冻结和信号审计，没有修改 RTL/UVM SystemVerilog 源码，没有新增 tests，没有修改 regression list。

## 完成内容

1. 读取并对齐以下输入：
   - `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_design_change.md`
   - `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_uvm_implementation_plan.md`
   - `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_staged_implementation_plan.md`
   - `doc/ptw_uvm_review/ptwspec.md`
2. 审计 RTL 文件：
   - `mmu/rtl/L1PDE_cache.sv`
   - `mmu/rtl/L2PDE_cache.sv`
   - `mmu/rtl/PDE_cache.sv`
   - `mmu/rtl/mbuf_entry.sv`
   - `mmu/rtl/ptw_mbuf.sv`
   - `mmu/rtl/twu.sv`
   - `mmu/rtl/ptw.sv`
3. 审计 UVM probe、monitor 和 SVA 当前观测能力：
   - `mmu_verification/testbench/env/mmu_dut_probes_if.sv`
   - `mmu_verification/testbench/top/tb_top.sv`
   - `mmu_verification/testbench/env/ptw_source_types.svh`
   - `mmu_verification/testbench/env/ptw_source_monitor.svh`
   - `mmu_verification/testbench/env/ptw_pde_cache_model.svh`
   - `mmu_verification/testbench/top/mmu_pde_cache_sva.sv`
   - `mmu_verification/testbench/top/mmu_ptw_top_sva.sv`
4. 新增 Stage 0 probe map/gap 文档：
   - `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md`

## 主要结论

1. RTL 已存在 L1/L2 PDE cached pmpflg 存储和 permission-qualified hit 逻辑。
2. RTL 已存在 L2 tag-hit cached PMP deny direct accerr path，并通过 `PDE_cache_acc_err_vld/type/id/grant` 接入 PTW access fault arbitration。
3. MBUF/TWU pmpflg payload 链路已存在：`twu_mbuf_pmpflg` -> `mbuf_entry_pmpflg` -> `mbuf_twu_pmpflg` -> `mbuf_cache_upd_l1pmpflg/l2pmpflg`。
4. 当前 UVM probe 只接了旧 PDE hit/update/clear/update_vec；尚未接 pmpflg payload、raw tag hit、cached entry pmpflg、direct accerr vld/type/id/grant。
5. `pmp_regs_update` 当前在 `tb_top.sv` DUT instance 被 tie 为 `1'b0`，对应 PMP config clear/repopulate 仍是 testbench/probe gap。

## 新增文件

| 文件 | 用途 |
| --- | --- |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md` | Stage 0 语义冻结、RTL/UVM signal map、probe 方案、SVA bind 方案、gap 表、后续阶段文件边界。 |
| `doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_progress.md` | 本阶段进度记录。 |

## 修改文件

仅新增 markdown 文档。未修改 SystemVerilog、Python、list 或 RTL 文件。

## Open Items

| Gap | 后续阶段 |
| --- | --- |
| pmpflg update/MBUF payload 未接入 monitor probe | 阶段 2 |
| direct accerr vld/type/id/grant 未接入 monitor probe | 阶段 2 |
| raw tag hit 和 cached pmpflg per entry 需要 bind 或额外 probe | 阶段 2/6 |
| PDE direct accerr priority/type-id/pending clear SVA 尚未实现 | 阶段 6 |
| `pmp_regs_update` testbench tie-off | 后续涉及 PMP config clear/repopulate 的阶段必须先处理 |

## Exit Check Commands

```powershell
rg -n "L1PDE.*pmp|L2PDE.*pmp|PDE_cache_acc_err|mbuf.*pmpflg|twu_mbuf_pmpflg" mmu/rtl
rg -n "pde_cache|pmpflg|acc_err|L1PDE|L2PDE" mmu_verification/testbench/env mmu_verification/testbench/top
Test-Path doc/ptw_uvm_review/ptw_pde_cache_pmpflg_stage0_probe_map.md
git diff --name-only -- "*.sv" "*.svh"
```
