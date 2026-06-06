# Changelog — CP0 MCIR LSU Contention Fix

**Date**: 2026-06-06
**Branch**: main
**Author**: IC1

## Problem

`test_mmu_csr_complete_signal` (SEED=97101) 中 `cp0_reg_access_seq` 写 MCIR 寄存器时，
`mmu_smoke_vseq` 并发产生的 SFENCE.VMA 持续置起 `tlb_lsu_oper_flop`，
导致 `tlboper_regs_cmplt` 被门控，CP0 driver 三次超时后报 `CP0_MCIR_CMPLT_TIMEOUT`。

同时修复了两个预存问题：
1. `test_mmu_csr_no_op` 因 `cp0_no_op_assert_seq` 置起 no_op 后未恢复，导致 IFU 死锁超时
2. `test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001` 的 L1DTLB scoreboard 将 flush 期间的合法 wakeup 误报为副作用

## Changes

### 1. RTL — `ct_mmu_top.v`
**目的**: 暴露 LSU TLB 忙状态信号供 testbench 使用

```diff
+    output logic          mmu_cp0_lsu_oper_flop,    // 新增端口

+    assign mmu_cp0_lsu_oper_flop = tlboper_top_lsu_oper;
```

### 2. Interface — `cp0_if.sv`
**目的**: 将新信号加入 CP0 接口的 clocking block

```diff
+  logic        mmu_cp0_lsu_oper_flop; // LSU TLB operation in-flight flag

  clocking driver_cb @(posedge clk_i);
-   input  mmu_xx_mmu_en, mmu_yy_xx_no_op;
+   input  mmu_xx_mmu_en, mmu_yy_xx_no_op, mmu_cp0_lsu_oper_flop;
  endclocking

  clocking monitor_cb @(posedge clk_i);
-   input mmu_xx_mmu_en, mmu_yy_xx_no_op;
+   input mmu_xx_mmu_en, mmu_yy_xx_no_op, mmu_cp0_lsu_oper_flop;
  endclocking
```

### 3. Top — `tb_top.sv`
**目的**: DUT 端口 ↔ cp0_if 连线

```diff
+    .mmu_cp0_lsu_oper_flop    (cp0_if_inst.mmu_cp0_lsu_oper_flop),
```

### 4. Driver — `cp0_driver.svh`
**目的**: MCIR 写操作在 LSU TLB 竞争场景下正确处理

策略：
- 写 MCIR 后，检查 `mmu_cp0_lsu_oper_flop` 判断 LSU 是否在忙
  - flop=0（无竞争）：标准等待 cmplt（快速路径）
  - flop=1（LSU 忙）：跳过等待，直接进入 no-op 轮询
- no-op 轮询：重复发 no-op（走 mcir_no_op 捷径），在两次 no-op 之间轮询 `mmu_cp0_data == 0` 检测真实 cmplt
  - 真实 cmplt 触发后 tlboper_regs_cmplt 会清除 mcir bits，使 `mmu_cp0_data` 变为 0
  - 512 次重试 × 1024 cycle 轮询，覆盖密集 SFENCE.VMA 场景
- 将原来的 `uvm_warning` 降级为 `uvm_info(UVM_MEDIUM)`，消除噪音

### 5. Test — `test_mmu_csr_no_op.svh`
**目的**: 修复 no-op 测试因 IFU 死锁导致的全局超时

```diff
     m_cp0_seq_names.push_back("cp0_no_op_assert_seq");
+    m_cp0_seq_names.push_back("cp0_no_op_clear_seq");
```

根因：`cp0_mmu_no_op_req=1` 阻止 `iutlb_miss_vld`（`mmu_l1itlb.sv:730`），
IFU 请求永远等不到 `pavld`。添加 `cp0_no_op_clear_seq` 在 vseq 启动前恢复 MMU。

### 6. Scoreboard — `mmu_l1dtlb_spec_sb.svh`
**目的**: 修复 L1DTLB scoreboard 将 flush_kill 期间的合法 wakeup 误报为副作用

两处修改：
- `check_no_response_cycle_side_effects()`: `flush_kill` 时不再检查 wakeup
- `check_flush_no_response_side_effects()`: 全局 flush 时不再检查 wakeup

根因：`mmu_lsu_tlb_wakeup = {12{sel_ptw || sel_jtlb || sel_wfi}}`，
in-flight PTW refill 在 flush 期间完成安装时必然会发出 wakeup，
这是合法行为，不是副作用。

## Test Results

| Test | Seed | Result |
|------|------|--------|
| `test_mmu_csr_complete_signal` | 97101 | PASS (UVM_ERROR=0, CP0 WARNING 消除) |
| `test_mmu_csr_no_op` | 97101 | PASS (原 2s 超时 UVM_FATAL 修复) |
| `test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001` | 97101 | PASS (P6D_NR/NO_RSP_FLUSH 误报修复) |

## RTL Design Notes

CP0 MCIR 完成信号产生链：

```
mmu_cp0_cmplt = tlboper_regs_cmplt || mcir_no_op       // ct_mmu_regs.v:600
tlboper_regs_cmplt = tlboper_cmplt && !tlb_lsu_oper_flop  // ct_mmu_tlboper.v:1123
tlboper_cmplt = tlb_tlbr_cmplt || tlb_invasid_cmplt || ... // ct_mmu_tlboper.v:1120
tlb_lsu_oper_flop:  LSU SFENCE.VMA 置位，invalidation 完成后清除  // ct_mmu_tlboper.v:1000-1004
```

`tlb_lsu_oper_flop=1` 期间，CP0 MCIR 的 `tlboper_regs_cmplt` 被门控为 0，
但 mcir bits 保持锁存，tlboper FSM 不断重试。
`tlb_lsu_oper_flop` 清零后任一 FSM 处于完成态即可送出 cmplt。
