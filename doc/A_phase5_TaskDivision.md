# Phase 5 A 任务实施计划

## 概述
Phase 5 A 的工作：misc_agent 八件套 + mmu_credit_sb + mmu_perf_mon + env 更新。
共 10 个新文件 + 3 个修改文件 = 13 项，不超过 15 不需要拆分。

---

## 新建文件（10 个）

### misc_agent（8 个，misc_if.sv 已存在）
- `testbench/misc_agent/misc_txn.svh`
- `testbench/misc_agent/misc_sequencer.svh`
- `testbench/misc_agent/misc_driver.svh`
- `testbench/misc_agent/misc_monitor.svh`
- `testbench/misc_agent/misc_sequences.svh`
- `testbench/misc_agent/misc_covergroups.svh`
- `testbench/misc_agent/misc_agent.svh`
- `testbench/misc_agent/misc_agent_pkg.sv`

### env（2 个）
- `testbench/env/mmu_credit_sb.svh`
- `testbench/env/mmu_perf_mon.svh`

## 修改文件（3 个）
- `testbench/env/mmu_env_pkg.sv`
- `testbench/env/mmu_env.svh`
- `testbench/Files.f`

---

## 关键设计决策

### misc_driver
- `rtu_yy_xx_flush`：单周期脉冲（MISC_RTU_FLUSH op），通过 driver_cb 驱动
- `biu_mmu_smp_disable`：静态配置（build/connect_phase 后固定），MISC_SMP_DISABLE op
- `hpcp_mmu_cnt_en`：MISC_HPCP_CNT_EN op，level 信号
- `pad_yy_icg_scan_en`：默认 0（仿真不使用 DFT），MISC_DFT_SCAN_EN op
- 参考 dv_utils pulse_gen_driver 使用模式

### misc_monitor
- `ap_hpcp`：每个时钟沿采样 mmu_hpcp_dutlb_miss / iutlb_miss / jtlb_miss，变化时发布 misc_txn
- `ap_debug`：采样 mmu_had_debug_info 变化

### mmu_credit_sb
- 使用 `uvm_tlm_analysis_fifo` 接收 8 个 AP 流
- run_phase：fork 8 个线程，各自 get() 消费，更新计数器
- 容量守恒检查：
  - credit_l1i: ifu_req → -1, ifu_rsp → +1, 上界 L1_ITLB_ENTRIES=16
  - credit_l1d: lsu_p0/p1 req → -1, rsp → +1
  - l2_reqq_cnt: lsu_p0/p1 req → +1, rsp → +1, 上界 L2_REQQ_DEPTH=9
  - ptw_mbuf_cnt: ptw_req → +1, ptw_rsp → +1, 上界 PTW_MBUF_DEPTH=4
- report_phase：断言所有计数器 == 0

### mmu_perf_mon（骨架）
- 统计字段声明（n_ifu_req/miss, n_lsu_req/miss[3], walk_latency_sum）
- FIFOs 建立，run_phase fork 消费（统计留 TODO）
- report_phase 打印统计

### mmu_env 更新
build_phase 新增：
- `m_misc = misc_agent::type_id::create("m_misc", this)`
- `m_credit_sb = mmu_credit_sb::type_id::create("m_credit_sb", this)`
- `m_perf = mmu_perf_mon::type_id::create("m_perf", this)`

connect_phase 新增（fan-out 模式）：
- ifu ap_req/rsp → credit_sb AF FIFOs
- lsu ap_pipe0/1 req/rsp → credit_sb AF FIFOs
- ptw_mem ap_req/rsp → credit_sb AF FIFOs
- ifu ap_rsp → perf_mon af_ifu_rsp
- lsu ap_pipe0/1/2 rsp → perf_mon 对应 AF FIFOs
- misc ap_hpcp → perf_mon af_hpcp

### AP 名称对照（来自已有文件）
| Monitor | AP 名 |
|---------|-------|
| ifu_monitor | ap_req, ap_rsp |
| lsu_monitor | ap_pipe0_req/rsp, ap_pipe1_req/rsp, ap_pipe2_req/rsp, ap_inv, ap_stamo |
| ptw_mem_monitor | ap_req, ap_rsp |
| misc_monitor (新) | ap_hpcp, ap_debug |

---

## 执行顺序
1. misc_txn.svh（无依赖）
2. misc_sequencer.svh（依赖 misc_txn）
3. misc_covergroups.svh（依赖 misc_if）
4. misc_driver.svh（依赖 misc_txn, misc_if）
5. misc_monitor.svh（依赖 misc_txn, misc_if）
6. misc_sequences.svh（依赖 misc_txn）
7. misc_agent.svh（依赖前 6 项）
8. misc_agent_pkg.sv（include 顺序：txn→cg→seq→driver→monitor→sequences→agent）
9. mmu_credit_sb.svh（依赖 ifu_txn, lsu_txn, ptw_mem_txn, mmu_params_pkg）
10. mmu_perf_mon.svh（依赖 ifu_txn, lsu_txn, misc_txn）
11. mmu_env_pkg.sv 更新（追加 import misc_agent_pkg + includes）
12. mmu_env.svh 更新（新增 m_misc/m_credit_sb/m_perf + 连线）
13. Files.f 更新（添加 misc_agent_pkg.sv 条目）

---

## 退出准则（Phase 5 剩余项）
- make comp 0 errors（含 misc_agent + credit_sb + perf_mon）
- misc_agent 八件套编译通过；rtu_flush/biu_smp_disable 在 sanity 用例中实际驱动
- mmu_credit_sb 仿真结束信用守恒计数 = 0
