# L1TLB covp 未覆盖代码报告

本报告基于 `make covp` 生成的 URG 覆盖率报告：`mmu_verification/output/coverage/phase14_urgReport`。
- 原始 URG 数据源：`mmu_verification/output/coverage/phase14_merged.vdb`
- URG 命令：`urg -full64 -dir .../phase14_merged.vdb -elfile .../simu/exclude_v4.tgl -format both -report .../phase14_urgReport`
- 统计范围：`tb_top.u_dut.u_mmu_l1dtlb` 与 `tb_top.u_dut.x_mmu_l1itlb` 子树下的所有实例（含 SVA 与子模块）。

## 阅读说明

- 重复实例与参数化条目（如不同 entry index、不同 way、不同位段）按覆盖率类型、模块、源码行号和代码文本合并；`影响条目数` 表示合并前命中的原始条目数（即同一个未覆盖对象在多少个实例/参数化变体上出现）。
- 表格中 `行号` 为源码行号，`未覆盖代码/对象` 为 URG 指出的语句、表达式、信号、端口、状态迁移或 SVA 对象，`URG 细节` 保留原始覆盖率细节。
- 代码块只给出定位上下文，`>>` 标记 URG 对应的源码行；上下相邻行用于辅助判断该代码属于哪个 if/case/always/assert 块。
- 条件覆盖的 0/1 位串按表达式 term 顺序排列。
- Toggle 覆盖率在 URG 中通常没有可执行源码行；这里列出未翻转的端口/信号以及源码中匹配到的声明或赋值位置。
- `implicit_else` 是 VCS/URG 推导出的隐式 else 路径未覆盖，不一定对应 RTL 中显式写出的 `else` 行。
- 断言中 `Real Successes=0` 表示该 SVA 虽被 attempt 但未真正命中；cover 中 `Matches=0` 表示 cover 点未采样到。

## 代码列说明

- 如果 `未覆盖代码/对象` 是完整 RTL/SVA 语句，表示该语句在本次回归中没有达到 URG 统计要求。
- 如果显示 `EXPRESSION` 或 `SUB-EXPRESSION`，表示条件表达式中的某些取值组合没有被测到；`URG 细节` 中的 0/1 串按表达式 term 顺序排列。
- 如果显示 `signal[range] -> declaration`，左侧是未完整翻转的位段，右侧是源码中匹配到的声明或赋值，用来定位信号定义。
- `MISSING_ELSE after previous statement` 表示前一条条件语句的隐式 else/默认路径没有被覆盖。
- 断言/cover 条目中的 `RealSuccesses=0` 或 `Matches=0` 表示该 SVA 对象虽然可能被 attempt，但没有真正成功或命中。

## 汇总

| 覆盖类型 | 原始未覆盖记录数 | 合并后唯一代码对象数 |
| --- | ---: | ---: |
| 行覆盖 | 13 | 13 |
| 条件覆盖 | 482 | 86 |
| 分支覆盖（含 MISSING_ELSE）| 13 | 9 |
| FSM 状态迁移覆盖 | 2 | 2 |
| 翻转覆盖 - 端口 | 685 | 434 |
| 翻转覆盖 - 内部信号 | 1033 | 636 |
| 断言/cover 命中覆盖 | 26 | 10 |
| **合计** | **2254** | **1190** |

| 模块 | SCORE/LINE/COND/TOGGLE/FSM/BRANCH/ASSERT (%) | 未覆盖对象数 | 源码 |
| --- | --- | ---: | --- |
| `mmu_l1dtlb` | 86.97/95.22/83.62/71.98/--/97.06/-- | 938 | `mmu/rtl/mmu_l1dtlb.sv` |
| `mmu_l1dtlb_allocator` | 99.46/100.00/100.00/97.83/--/100.00/-- | 3 | `mmu/rtl/mmu_l1dtlb_allocator.sv` |
| `mmu_l1dtlb_mb_entry` | 93.03/95.45/87.67/89.90/100.00/92.11/-- | 28 | `mmu/rtl/mmu_l1dtlb_mb_entry.sv` |
| `mmu_l1dtlb_expt_cam` | 87.15/100.00/80.77/67.84/--/100.00/-- | 78 | `mmu/rtl/mmu_l1dtlb_expt_cam.sv` |
| `mmu_l1dtlb_hit_rd` | 88.93/100.00/78.66/77.06/--/100.00/-- | 225 | `mmu/rtl/mmu_l1dtlb_hit_rd.sv` |
| `mmu_l1dtlb_install` | 84.67/100.00/79.41/59.25/--/100.00/-- | 47 | `mmu/rtl/mmu_l1dtlb_install.sv` |
| `mmu_l1dtlb_scheduler` | 94.10/100.00/96.77/79.62/--/100.00/-- | 31 | `mmu/rtl/mmu_l1dtlb_scheduler.sv` |
| `mmu_l1itlb` | 81.90/92.06/78.65/73.53/77.78/87.50/-- | 461 | `mmu/rtl/mmu_l1itlb.sv` |
| `ct_mmu_iutlb_entry` | 96.28/100.00/97.44/87.69/--/100.00/-- | 21 | `mmu/rtl/ct_mmu_iutlb_entry.v` |
| `ct_mmu_iutlb_fst_entry` | 95.96/100.00/97.44/86.40/--/100.00/-- | 27 | `mmu/rtl/ct_mmu_iutlb_fst_entry.v` |
| `mmu_l1dtlb_sva` | 93.83/100.00/100.00/79.50/--/100.00/89.67 | 145 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| `mmu_l1dtlb_mb_entry_sva` | 93.95/100.00/100.00/90.78/--/--/85.00 | 10 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| `mmu_l1dtlb_expt_cam_sva` | 98.08/--/--/96.15/--/--/100.00 | 3 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| `mmu_l1dtlb_install_sva` | 88.61/100.00/100.00/54.43/--/--/100.00 | 36 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| `mmu_l1dtlb_hit_rd_sva` | 82.58/--/--/75.15/--/--/90.00 | 172 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| `mmu_l1dtlb_allocator_sva` | 94.27/100.00/--/99.48/--/--/83.33 | 3 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |
| `mmu_l1dtlb_scheduler_sva` | 91.35/100.00/--/74.06/--/--/100.00 | 26 | `mmu_verification/testbench/top/mmu_l1dtlb_sva.sv` |

## 主要未覆盖模式分析

### 行覆盖缺口（语句从未执行）

- `mmu_l1dtlb` `mmu/rtl/mmu_l1dtlb.sv:987` `entry_ref_ppn   = jtlb_utlb_ref_ppn;`

`mmu/rtl/mmu_l1dtlb.sv:987`

```systemverilog
       984:                     entry_ref_acflt = ptw_l1tlb_acc_err;
       985:     		            entry_ref_pgs   = ptw_l1tlb_ref_pgs;
       986:                 end else if (is_jtlb_refill) begin
       987: >>                  entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
```

- `mmu_l1dtlb` `mmu/rtl/mmu_l1dtlb.sv:988` `entry_ref_flg   = jtlb_utlb_ref_flg;`

`mmu/rtl/mmu_l1dtlb.sv:988`

```systemverilog
       985:     		            entry_ref_pgs   = ptw_l1tlb_ref_pgs;
       986:                 end else if (is_jtlb_refill) begin
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988: >>                  entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
```

- `mmu_l1dtlb` `mmu/rtl/mmu_l1dtlb.sv:989` `entry_ref_pgflt = jtlb_dutlb_pgflt;`

`mmu/rtl/mmu_l1dtlb.sv:989`

```systemverilog
       986:                 end else if (is_jtlb_refill) begin
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989: >>                  entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
```

- `mmu_l1dtlb` `mmu/rtl/mmu_l1dtlb.sv:990` `entry_ref_acflt = 1'b0;`

`mmu/rtl/mmu_l1dtlb.sv:990`

```systemverilog
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990: >>                  entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
       993:                 end
```

- `mmu_l1dtlb` `mmu/rtl/mmu_l1dtlb.sv:991` `entry_ref_pgs   = jtlb_utlb_ref_pgs;`

`mmu/rtl/mmu_l1dtlb.sv:991`

```systemverilog
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991: >>  		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
       993:                 end
       994:             end
```

- `mmu_l1dtlb_mb_entry` `mmu/rtl/mmu_l1dtlb_mb_entry.sv:200` `state_nxt = STATE_IDLE;`

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:200`

```systemverilog
       197:             STATE_WFI: begin
       198:                 if (abort_this_cyc) begin
       199:                     // Flush occurred while waiting to install
       200: >>                  state_nxt = STATE_IDLE;
       201:                 end else if (refill_gnt) begin
       202:                     // Finally granted permission to write to L1TLB
       203:                     state_nxt = STATE_IDLE;
```

- `mmu_l1dtlb_mb_entry` `mmu/rtl/mmu_l1dtlb_mb_entry.sv:216` `state_nxt = STATE_IDLE;`

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:216`

```systemverilog
       213:     
       214:             STATE_ACFLT: begin
       215:                 if (abort_this_cyc)
       216: >>                  state_nxt = STATE_IDLE;
       217:                 else if (expt_hit)
       218:                     state_nxt = STATE_IDLE;
       219:             end
```

- `mmu_l1dtlb_mb_entry` `mmu/rtl/mmu_l1dtlb_mb_entry.sv:228` `default: state_nxt = STATE_IDLE;`

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:228`

```systemverilog
       225:                 end
       226:             end
       227:             
       228: >>          default: state_nxt = STATE_IDLE;
       229:         endcase
       230:     end
       231:     
```

- `mmu_l1itlb` `mmu/rtl/mmu_l1itlb.sv:753` `ref_nxt_st[2:0] = ABT;`

`mmu/rtl/mmu_l1itlb.sv:753`

```systemverilog
       750:             end
       751:             WFG: begin
       752:               if(ifu_mmu_abort && credit_cnt != 1'b0)
       753: >>              ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755:                 ref_nxt_st[2:0] = IDLE;
       756:               else if(credit_cnt != 1'b0)
```

- `mmu_l1itlb` `mmu/rtl/mmu_l1itlb.sv:755` `ref_nxt_st[2:0] = IDLE;`

`mmu/rtl/mmu_l1itlb.sv:755`

```systemverilog
       752:               if(ifu_mmu_abort && credit_cnt != 1'b0)
       753:                 ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755: >>              ref_nxt_st[2:0] = IDLE;
       756:               else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
       758:               else
```

- `mmu_l1itlb` `mmu/rtl/mmu_l1itlb.sv:759` `ref_nxt_st[2:0] = WFG;`

`mmu/rtl/mmu_l1itlb.sv:759`

```systemverilog
       756:               else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
       758:               else
       759: >>              ref_nxt_st[2:0] = WFG;
       760:             end
       761:             WFC: begin
       762:               if(ifu_mmu_abort && l1itlb_ref_cmplt)
```

- `mmu_l1itlb` `mmu/rtl/mmu_l1itlb.sv:763` `ref_nxt_st[2:0] = IDLE;`

`mmu/rtl/mmu_l1itlb.sv:763`

```systemverilog
       760:             end
       761:             WFC: begin
       762:               if(ifu_mmu_abort && l1itlb_ref_cmplt)
       763: >>              ref_nxt_st[2:0] = IDLE;
       764:               else if(ifu_mmu_abort)
       765:                 ref_nxt_st[2:0] = ABT;
       766:               else if(l1itlb_ref_cmplt && (ptw_l1tlb_pgflt || jtlb_iutlb_pgflt))
```

- `mmu_l1itlb` `mmu/rtl/mmu_l1itlb.sv:783` `ref_nxt_st[2:0] = IDLE;`

`mmu/rtl/mmu_l1itlb.sv:783`

```systemverilog
       780:                 ref_nxt_st[2:0] = ABT;
       781:             end
       782:             default: begin
       783: >>             ref_nxt_st[2:0] = IDLE;
       784:             end
       785:         endcase
       786:     // &CombEnd; @310
```

### 条件覆盖缺口（按表达式模式聚合）

| 模块 | 行号 | 表达式（已聚合参数化条目） | 未覆盖组合（采样） | 影响条目数 |
| --- | ---: | --- | --- | ---: |
| `mmu_l1dtlb` | 1190 | `SUB-EXPRESSION (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[2].hit0_1g)` | 1 0 Not Covered; 1 1 Not Covered | 56 |
| `mmu_l1dtlb` | 1194 | `SUB-EXPRESSION (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[2].hit1_1g)` | 1 0 Not Covered; 1 1 Not Covered | 56 |
| `mmu_l1dtlb` | 1190 | `EXPRESSION ((l1dtlb_ent_pgs[2][0] & u_l1dtlb_ent[2].hit0_4k) | (l1dtlb_ent_pgs[2][1] & u_l1dtlb_ent[2].hit0_2m) | (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[...` | 0 0 1 Not Covered; 0 1 0 Not Covered | 46 |
| `mmu_l1dtlb` | 1194 | `EXPRESSION ((l1dtlb_ent_pgs[2][0] & u_l1dtlb_ent[2].hit1_4k) | (l1dtlb_ent_pgs[2][1] & u_l1dtlb_ent[2].hit1_2m) | (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[...` | 0 0 1 Not Covered; 0 1 0 Not Covered | 46 |
| `mmu_l1dtlb` | 1190 | `SUB-EXPRESSION (l1dtlb_ent_pgs[7][1] & u_l1dtlb_ent[7].hit0_2m)` | 1 0 Not Covered; 1 1 Not Covered | 36 |
| `mmu_l1dtlb` | 1194 | `SUB-EXPRESSION (l1dtlb_ent_pgs[7][1] & u_l1dtlb_ent[7].hit1_2m)` | 1 0 Not Covered; 1 1 Not Covered | 36 |
| `mmu_l1dtlb` | 1116 | `EXPRESSION (tlboper_utlb_inv_va_req && l1dtlb_ent_vld[2] && (lsu_mmu_tlb_va[7:0] == l1dtlb_ent_vpn[2][7:0]))` | 1 1 1 Not Covered | 28 |
| `mmu_l1dtlb` | 1120 | `EXPRESSION (regs_utlb_clr | tlboper_utlb_clr | ctc_inv_va_hit_clr[2])` | 0 0 1 Not Covered | 28 |
| `mmu_l1dtlb` | 958 | `EXPRESSION (ptw_l1dtlb_ref_cmplt && (ptw_l1dtlb_ref_id == 2[(EID_WIDTH - 1):0]))` | 0 1 Not Covered | 12 |
| `mmu_l1dtlb` | 957 | `EXPRESSION (jtlb_dutlb_ref_cmplt && (jtlb_dutlb_ref_id == 3[(EID_WIDTH - 1):0]))` | 1 1 Not Covered | 10 |
| `mmu_l1dtlb` | 969 | `EXPRESSION (gen_mb_entries[3].is_jtlb_refill || gen_mb_entries[3].is_ptw_refill)` | 1 0 Not Covered | 10 |
| `mmu_l1itlb` | 551 | `SUB-EXPRESSION (((!iutlb_flg_aft_bypass[0])) || (((!iutlb_flg_aft_bypass[1])) && iutlb_flg_aft_bypass[2]) || ((!iutlb_flg_aft_bypass[3])) || (iutlb_flg_aft...` | 0 0 0 0 0 0 0 0 1 Not Covered; 0 0 0 0 0 1 0 0 0 Not Covered; 0 0 0 0 1 0 0 0 0 Not Covered; ... 共 7 种组合 | 7 |
| `mmu_l1dtlb` | 315 | `EXPRESSION (jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt && mb_entry_vld[jtlb_dutlb_ref_id] && (mb_entry_state[jtlb_dutlb_ref_id] == MB_STATE_WFC) && ((!rt...` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered; 1 1 1 1 0 Not Covered | 6 |
| `mmu_l1dtlb_hit_rd` | 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[0])) || (((!dutlb_fin_flg[1])) && dutlb_fin_flg[2]) || (((!dutlb_fin_flg[1])) && dutlb_read_type_x && ( ! (cp0_mmu_mxr && ...` | 0 0 0 0 0 0 0 1 Not Covered; 0 0 0 0 0 0 1 0 Not Covered; 0 0 0 1 0 0 0 0 Not Covered; ... 共 5 种组合 | 5 |
| `mmu_l1dtlb` | 305 | `EXPRESSION (ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err) && mb_entry_vld[ptw_l1dtlb_ref_id] && (mb_entry_state[ptw_l1dtlb_ref_id] == ...` | 0 1 1 1 1 Not Covered; 1 1 0 1 1 Not Covered | 4 |
| `mmu_l1dtlb` | 802 | `EXPRESSION (miss0_vld_q && ((!miss0_abort_q)) && miss1_vld_q && ((!miss1_abort_q)) && (miss0_vpn_q == miss1_vpn_q))` | 1 0 1 1 1 Not Covered; 1 1 1 0 1 Not Covered | 4 |
| `mmu_l1dtlb_hit_rd` | 165 | `EXPRESSION (((lsu_mmu_va_x[(VPN_WIDTH + 11)] && ((!(&lsu_mmu_va_x[63:(VPN_WIDTH + 12)])))) || (((!lsu_mmu_va_x[(VPN_WIDTH + 11)])) && ((|lsu_mmu_va_x[6...` | 1 0 1 Not Covered; 1 1 0 Not Covered; 1 1 1 Not Covered | 3 |
| `mmu_l1dtlb_hit_rd` | 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[2])) && ((!dutlb_read_type_x)))` | 1 1 Not Covered; 1 0 Not Covered | 3 |
| `mmu_l1dtlb_install` | 103 | `EXPRESSION (jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt && mb_entry_vld[id_jtlb] && ((!req_jtlb_expt)) && ((!req_jtlb_aborted)))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered; 1 1 1 1 0 Not Covered | 3 |
| `mmu_l1itlb` | 551 | `SUB-EXPRESSION (iutlb_flg_aft_bypass[4] && cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered; 1 1 0 Not Covered; 1 1 1 Not Covered | 3 |
| `mmu_l1dtlb` | 817 | `EXPRESSION (miss0_vld_q && ((!miss0_abort_q)) && ((!mb_hit0)) && ((!rtu_yy_xx_flush)))` | 1 0 1 1 Not Covered | 2 |
| `mmu_l1dtlb` | 817 | `EXPRESSION (miss1_vld_q && ((!miss1_abort_q)) && ((!mb_hit1)) && ((!same_4k_miss01)) && ((!rtu_yy_xx_flush)))` | 1 0 1 1 1 Not Covered | 2 |
| `mmu_l1dtlb_mb_entry` | 283 | `EXPRESSION (alloc_fire && issue_sel && issue_grant)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l1dtlb_mb_entry` | 288 | `EXPRESSION ((state_r == STATE_WFG) && issue_sel && issue_grant)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l1dtlb_hit_rd` | 165 | `SUB-EXPRESSION ((lsu_mmu_va_x[(VPN_WIDTH + 11)] && ((!(&lsu_mmu_va_x[63:(VPN_WIDTH + 12)])))) || (((!lsu_mmu_va_x[(VPN_WIDTH + 11)])) && ((|lsu_mmu_va_x[63...` | 0 1 Not Covered; 1 0 Not Covered | 2 |
| `mmu_l1dtlb_hit_rd` | 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[1])) && dutlb_read_type_x && ( ! (cp0_mmu_mxr && dutlb_fin_flg[3]) ))` | 1 0 1 Not Covered; 1 1 1 Not Covered | 2 |
| `mmu_l1dtlb_hit_rd` | 301 | `EXPRESSION (lsu_va_chg || lsu_mmu_va_vld_x || (pmp_flg_vld ^ lsu_mmu_va_vld_x))` | 0 1 0 Not Covered; 1 0 0 Not Covered | 2 |
| `mmu_l1dtlb_install` | 100 | `EXPRESSION (ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt && mb_entry_vld[id_ptw] && ((!req_ptw_expt)) && ((!req_ptw_aborted)))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered | 2 |
| `mmu_l1dtlb_scheduler` | 214 | `EXPRESSION (bypass_req_vld && credit_avail && ((!mb_req_vld)))` | 1 0 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l1itlb` | 520 | `EXPRESSION (iutlb_bypass_vld || iutlb_hit_vld || iutlb_disable_vld || iutlb_acc_flt || iutlb_ref_pgflt || iutlb_va_illegal)` | 0 0 1 0 0 0 Not Covered; 1 0 0 0 0 0 Not Covered | 2 |
| `mmu_l1itlb` | 551 | `SUB-EXPRESSION (((!iutlb_flg_aft_bypass[4])) && cp0_user_mode && regs_mmu_en)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l1itlb` | 566 | `SUB-EXPRESSION (((!pmp_mmu_flg2[2])) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg2[3]))) ) && pmp_flg_vld)` | 1 0 1 Not Covered; 1 1 1 Not Covered | 2 |
| `mmu_l1itlb` | 727 | `EXPRESSION (ifu_mmu_va_vld && ((!iutlb_addr_hit_vld)) && ((!iutlb_off_hit)) && ((!cp0_mmu_no_op_req)))` | 1 1 0 1 Not Covered; 1 1 1 0 Not Covered | 2 |
| `mmu_l1itlb` | 752 | `EXPRESSION (ifu_mmu_abort && (credit_cnt != 1'b0))` | 1 0 Not Covered; 1 1 Not Covered | 2 |
| `mmu_l1dtlb_mb_entry` | 120 | `EXPRESSION (alloc_vld && ((!abort_this_cyc)))` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_mb_entry` | 134 | `EXPRESSION (issue_sel && issue_grant)` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_mb_entry` | 144 | `EXPRESSION (issue_sel && issue_grant)` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_mb_entry` | 150 | `EXPRESSION (issue_sel && issue_grant)` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_mb_entry` | 257 | `EXPRESSION (alloc_fire && (state_r == STATE_IDLE))` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_expt_cam` | 95 | `EXPRESSION (lsu_mmu_va1_vld && hit1_any && ((!lsu_mmu_abort1)))` | 1 1 0 Not Covered | 1 |
| `mmu_l1dtlb_expt_cam` | 96 | `EXPRESSION (hit0_any && hit1_any && (hit0_idx == hit1_idx))` | 1 1 1 Not Covered | 1 |
| `mmu_l1dtlb_expt_cam` | 98 | `EXPRESSION (consume1 && ((!same_hit_entry)))` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_expt_cam` | 130 | `EXPRESSION (expt_wr0_vld && expt_wr1_vld && (expt_wr0_eid == expt_wr1_eid))` | 1 1 1 Not Covered | 1 |
| `mmu_l1dtlb_expt_cam` | 155 | `EXPRESSION (expt_wr1_vld && ((!same_wr_eid)))` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 146 | `EXPRESSION (dutlb_hit_vld | dutlb_disable_vld | dutlb_va_illegal | dutlb_expt_match)` | 0 0 1 0 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 165 | `SUB-EXPRESSION (lsu_mmu_va_x[(VPN_WIDTH + 11)] && ((!(&lsu_mmu_va_x[63:(VPN_WIDTH + 12)]))))` | 1 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 165 | `SUB-EXPRESSION (((!lsu_mmu_va_x[(VPN_WIDTH + 11)])) && ((|lsu_mmu_va_x[63:(VPN_WIDTH + 12)])))` | 1 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 170 | `EXPRESSION (((((!dutlb_fin_flg[0])) || (((!dutlb_fin_flg[1])) && dutlb_fin_flg[2]) || (((!dutlb_fin_flg[1])) && dutlb_read_type_x && ( ! (cp0_mmu_mxr &...` | 0 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 170 | `SUB-EXPRESSION (dutlb_fin_flg[4] && cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[4])) && cp0_user_mode)` | 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 170 | `SUB-EXPRESSION (expt_match_x && expt_pgflt_x)` | 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 183 | `EXPRESSION (dutlb_page_fault && ((!dutlb_off_hit)))` | 1 0 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 185 | `EXPRESSION ((expt_match_x && expt_acflt_x) || jtlb_acc_fault_flop || (((!pmp_mmu_flg_x[0])) && (pmp_read_type || dutlb_ori_read_x) && ( ! (cp0_mach_mod...` | 0 1 0 0 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 185 | `SUB-EXPRESSION (expt_match_x && expt_acflt_x)` | 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 185 | `SUB-EXPRESSION (((!pmp_mmu_flg_x[0])) && (pmp_read_type || dutlb_ori_read_x) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg_x[3]))) ) && pmp_flg_vld)` | 1 1 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 185 | `SUB-EXPRESSION (((!pmp_mmu_flg_x[1])) && ((!pmp_read_type)) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg_x[3]))) ) && pmp_flg_vld)` | 1 1 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 194 | `EXPRESSION ((expt_match_x && expt_acflt_x) || jtlb_acc_fault_flop)` | 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 194 | `SUB-EXPRESSION (expt_match_x && expt_acflt_x)` | 0 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 209 | `EXPRESSION (lsu_mmu_va_vld_x & ((!dutlb_entry_hit_vld)) & ((!dutlb_va_illegal)) & ((!lsu_mmu_abort_x)) & ((!dutlb_off_hit)) & ((!dutlb_expt_match)))` | 1 1 0 1 1 1 Not Covered | 1 |
| `mmu_l1dtlb_hit_rd` | 216 | `EXPRESSION (lsu_mmu_va_vld_x & ((!dutlb_entry_hit_vld)) & ((!dutlb_va_illegal)) & ((!dutlb_off_hit)) & ((!dutlb_expt_match)))` | 1 1 0 1 1 Not Covered | 1 |
| ... | ... | （其余 26 个聚合模式见下方分模块详情） | ... | ... |

### FSM 状态迁移缺口

| 模块 | FSM | 未覆盖迁移 | 行号 |
| --- | --- | --- | ---: |
| `mmu_l1itlb` | `ref_cur_st` | `WFG->IDLE` | 735 |
| `mmu_l1itlb` | `ref_cur_st` | `WFG->ABT` | 753 |

`mmu/rtl/mmu_l1itlb.sv:735` (ref_cur_st FSM 的 `WFG->IDLE` 迁移):

```systemverilog
       731:     
       732:     always @(posedge iutlb_clk or negedge cpurst_b)
       733:     begin
       734:       if (!cpurst_b)
       735: >>      ref_cur_st[2:0] <= 3'b0;
       736:       else
       737:         ref_cur_st[2:0] <= ref_nxt_st[2:0];
       738:     end
       739:     
```

### 断言/cover 命中缺口（按名称模式聚合）

| 模块 | 名称（已聚合） | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | --- | ---: | ---: | ---: |
| `mmu_l1dtlb_sva` | `gen_l1dtlb_entry_sva[10].a_va8_inv_clears_matching_entry` | assertion | 206452807 | 0 | 14 |
| `mmu_l1dtlb_sva` | `gen_l1dtlb_entry_sva[11].a_clear_wins_install_same_entry` | assertion | 206452807 | 0 | 4 |
| `mmu_l1dtlb_sva` | `cp_l1dtlb_c001_reset_then_miss` | cover | 206452807 | 0 | 1 |
| `mmu_l1dtlb_mb_entry_sva` | `a_idle_flush_blocks_alloc` | assertion | 1651622456 | 0 | 1 |
| `mmu_l1dtlb_mb_entry_sva` | `a_wfi_data_stable_without_grant` | assertion | 1651622456 | 0 | 1 |
| `mmu_l1dtlb_mb_entry_sva` | `a_wfi_flush_to_idle` | assertion | 1651622456 | 0 | 1 |
| `mmu_l1dtlb_hit_rd_sva` | `a_expt_entry_overlap_is_terminal_replay` | assertion | 412905614 | 0 | 1 |
| `mmu_l1dtlb_hit_rd_sva` | `cp_l1dtlb_expt_entry_overlap_replay` | cover | 412905614 | 0 | 1 |
| `mmu_l1dtlb_allocator_sva` | `a_same_4k_dual_miss_dedup` | assertion | 206452807 | 0 | 1 |
| `mmu_l1dtlb_allocator_sva` | `cp_l1dtlb_c004_same_vpn_dedup` | cover | 206452807 | 0 | 1 |

### 翻转覆盖 - 端口（按信号模式聚合）

| 模块 | 端口（已聚合参数化位段） | 影响条目数 | Toggle No | 1->0 No | 0->1 No | 方向 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `mmu_l1dtlb_hit_rd` | `entry_ppn_vec[15]` | 34 | 34 | 34 | 1 | INPUT |
| `mmu_l1dtlb_hit_rd_sva` | `entry_ppn_vec[15]` | 34 | 34 | 34 | 1 | INPUT |
| `mmu_l1dtlb_sva` | `entry_ppn[0][15]` | 33 | 33 | 33 | 0 | INPUT |
| `mmu_l1dtlb_hit_rd` | `entry_flg_vec[0]` | 16 | 16 | 16 | 14 | INPUT |
| `mmu_l1dtlb_sva` | `entry_ppn[0][27:24]` | 16 | 16 | 16 | 0 | INPUT |
| `mmu_l1dtlb_hit_rd_sva` | `entry_flg_vec[0]` | 16 | 16 | 16 | 14 | INPUT |
| `mmu_l1dtlb_install` | `mb_entry_vpn[2][11]` | 13 | 13 | 13 | 0 | INPUT |
| `mmu_l1dtlb_scheduler` | `mb_entry_vpn[2][11]` | 13 | 13 | 13 | 0 | INPUT |
| `mmu_l1dtlb_sva` | `mb_entry_vpn[2][11]` | 13 | 13 | 13 | 0 | INPUT |
| `mmu_l1dtlb_sva` | `l1dtlb_ent_vpn[0][11]` | 13 | 13 | 13 | 0 | INPUT |
| `mmu_l1dtlb_install_sva` | `mb_entry_vpn[2][11]` | 13 | 13 | 13 | 0 | INPUT |
| `mmu_l1dtlb_scheduler_sva` | `mb_entry_vpn[2][11]` | 13 | 13 | 13 | 0 | INPUT |
| `mmu_l1dtlb_sva` | `entry_ppn[3][20:18]` | 12 | 12 | 12 | 0 | INPUT |
| `mmu_l1dtlb_sva` | `l1dtlb_ent_pgs[5][1]` | 10 | 10 | 10 | 0 | INPUT |
| `mmu_l1dtlb_scheduler` | `mb_entry_store[3]` | 4 | 4 | 4 | 1 | INPUT |
| `mmu_l1dtlb_sva` | `mb_entry_store[3]` | 4 | 4 | 4 | 1 | INPUT |
| `mmu_l1dtlb_scheduler_sva` | `mb_entry_store[3]` | 4 | 4 | 4 | 1 | INPUT |
| `mmu_l1dtlb_sva` | `entry_ppn[1][20:19]` | 3 | 3 | 3 | 0 | INPUT |
| `mmu_l1dtlb_install` | `mb_entry_iid[5][0]` | 2 | 2 | 2 | 0 | INPUT |
| `mmu_l1dtlb_scheduler` | `mb_entry_iid[5][0]` | 2 | 2 | 2 | 0 | INPUT |
| `ct_mmu_iutlb_fst_entry` | `utlb_entry_ppn[15]` | 2 | 2 | 2 | 0 | OUTPUT |
| `mmu_l1dtlb_sva` | `mb_entry_iid[5][0]` | 2 | 2 | 2 | 0 | INPUT |
| `mmu_l1dtlb_scheduler_sva` | `mb_entry_iid[5][0]` | 2 | 2 | 2 | 0 | INPUT |
| `mmu_l1dtlb` | `cpurst_b` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l1dtlb` | `pad_yy_icg_scan_en` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l1dtlb` | `cp0_mmu_mpp[0]` | 1 | 1 | 0 | 1 | INPUT |
| `mmu_l1dtlb` | `hpcp_mmu_cnt_en` | 1 | 1 | 0 | 1 | INPUT |
| `mmu_l1dtlb` | `mmu_lsu_stall0` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l1dtlb` | `mmu_lsu_stall1` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l1dtlb` | `pmp_mmu_flg1[3]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l1dtlb` | `sysmap_mmu_flg0[0]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l1dtlb` | `sysmap_mmu_flg1[0]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l1dtlb` | `ptw_l1tlb_ref_vpn[26]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l1dtlb` | `ptw_l1tlb_ref_ppn[23:21]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l1dtlb` | `biu_mmu_smp_disable` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l1dtlb` | `dutlb_top_ref_cur_st[2:0]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l1dtlb` | `dutlb_top_ref_type` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l1dtlb` | `dutlb_top_scd_updt` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l1dtlb` | `jtlb_utlb_ref_ppn[20]` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l1dtlb` | `jtlb_utlb_ref_ppn[23:21]` | 1 | 1 | 1 | 1 | INPUT |
| ... | ... （其余 394 个模式见下方分模块详情） | ... | ... | ... | ... | ... |

### 翻转覆盖 - 内部信号（按信号模式聚合）

| 模块 | 信号（已聚合参数化位段） | 影响条目数 | Toggle No | 1->0 No | 0->1 No |
| --- | --- | ---: | ---: | ---: | ---: |
| `mmu_l1dtlb` | `entry_ppn_vec[15]` | 34 | 34 | 34 | 1 |
| `mmu_l1dtlb` | `entry_ppn[0][15]` | 33 | 33 | 33 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_ppn[0][15]` | 33 | 33 | 33 | 0 |
| `mmu_l1dtlb_expt_cam` | `ent[2].vpn[18]` | 22 | 22 | 22 | 8 |
| `mmu_l1dtlb` | `entry_ppn[0][27:24]` | 16 | 16 | 16 | 0 |
| `mmu_l1dtlb` | `entry_flg_vec[0]` | 16 | 16 | 16 | 14 |
| `mmu_l1dtlb` | `l1dtlb_ent_ppn[0][27:24]` | 16 | 16 | 16 | 0 |
| `mmu_l1dtlb` | `entry_flg[1][6:5]` | 15 | 15 | 15 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_flg[1][6:5]` | 15 | 15 | 15 | 0 |
| `mmu_l1dtlb` | `entry_flg[2][10:9]` | 14 | 14 | 14 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_flg[2][10:9]` | 14 | 14 | 14 | 0 |
| `mmu_l1dtlb` | `entry_flg[3][3:0]` | 13 | 13 | 13 | 0 |
| `mmu_l1dtlb` | `mb_entry_vpn[2][11]` | 13 | 13 | 13 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_vpn[0][11]` | 13 | 13 | 13 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_flg[3][3:0]` | 13 | 13 | 13 | 0 |
| `mmu_l1dtlb` | `entry_ppn[3][20:18]` | 12 | 12 | 12 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_ppn[3][20:18]` | 12 | 12 | 12 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_pgs[5][1]` | 10 | 10 | 10 | 0 |
| `mmu_l1dtlb` | `gen_mb_entries[0].entry_ref_ppn[23:21]` | 8 | 8 | 8 | 8 |
| `mmu_l1dtlb` | `gen_mb_entries[1].entry_ref_ppn[20]` | 7 | 7 | 7 | 0 |
| `mmu_l1dtlb` | `gen_mb_entries[1].entry_ref_ppn[27:24]` | 7 | 7 | 7 | 0 |
| `mmu_l1dtlb` | `gen_mb_entries[2].alloc_vpn_i[12]` | 7 | 7 | 7 | 7 |
| `mmu_l1dtlb_expt_cam` | `ent[5].iid[0]` | 7 | 7 | 7 | 4 |
| `mmu_l1dtlb_expt_cam` | `ent[2].acflt` | 6 | 6 | 6 | 5 |
| `mmu_l1dtlb` | `gen_mb_entries[3].alloc_vpn_i[26:11]` | 5 | 5 | 5 | 5 |
| `mmu_l1dtlb` | `gen_mb_entries[3].is_jtlb_refill` | 5 | 5 | 5 | 5 |
| `mmu_l1dtlb` | `gen_mb_entries[3].entry_ref_acflt` | 5 | 5 | 5 | 5 |
| `mmu_l1dtlb_expt_cam` | `ent[3].pgflt` | 5 | 5 | 5 | 0 |
| `mmu_l1dtlb_expt_cam` | `ent[3].vpn[26:11]` | 5 | 5 | 5 | 5 |
| `mmu_l1dtlb` | `mb_entry_store[3]` | 4 | 4 | 4 | 1 |
| `mmu_l1itlb` | `entry16_vpn[11]` | 4 | 4 | 4 | 1 |
| `mmu_l1dtlb` | `entry_ppn[1][20:19]` | 3 | 3 | 3 | 0 |
| `mmu_l1dtlb` | `l1dtlb_ent_ppn[1][20:19]` | 3 | 3 | 3 | 0 |
| `mmu_l1dtlb_expt_cam` | `ent[2].vpn[2:0]` | 3 | 3 | 3 | 1 |
| `mmu_l1dtlb_expt_cam` | `hit0_vec[3]` | 3 | 3 | 3 | 3 |
| `mmu_l1itlb` | `entry0_ppn[11]` | 3 | 3 | 3 | 0 |
| `mmu_l1itlb` | `entry16_ppn[13]` | 3 | 3 | 3 | 0 |
| `mmu_l1itlb` | `entry3_ppn[10]` | 3 | 3 | 3 | 1 |
| `mmu_l1itlb` | `entry4_ppn[13]` | 3 | 3 | 3 | 0 |
| `mmu_l1itlb` | `entry6_ppn[11]` | 3 | 3 | 3 | 1 |
| ... | ... （其余 596 个模式见下方分模块详情） | ... | ... | ... | ... |

---

## 结论与覆盖建议

### 翻转覆盖薄弱模块（按未翻转对象数排序）

| 模块 | 未翻转对象数 | 模块级 TOGGLE 覆盖率 |
| --- | ---: | ---: |
| `mmu_l1dtlb` | 546 | 71.98 |
| `mmu_l1itlb` | 411 | 73.53 |
| `mmu_l1dtlb_hit_rd` | 190 | 77.06 |
| `mmu_l1dtlb_hit_rd_sva` | 170 | 75.15 |
| `mmu_l1dtlb_sva` | 126 | 79.50 |
| `mmu_l1dtlb_expt_cam` | 73 | 67.84 |
| `mmu_l1dtlb_install` | 40 | 59.25 |
| `mmu_l1dtlb_install_sva` | 36 | 54.43 |
| `mmu_l1dtlb_scheduler` | 27 | 79.62 |
| `ct_mmu_iutlb_fst_entry` | 26 | 86.40 |

### 条件覆盖薄弱模块（按未覆盖表达式数排序）

| 模块 | 未覆盖表达式数 | 模块级 COND 覆盖率 |
| --- | ---: | ---: |
| `mmu_l1dtlb` | 382 | 83.62 |
| `mmu_l1itlb` | 38 | 78.65 |
| `mmu_l1dtlb_hit_rd` | 35 | 78.66 |
| `mmu_l1dtlb_mb_entry` | 9 | 87.67 |
| `mmu_l1dtlb_install` | 7 | 79.41 |
| `mmu_l1dtlb_expt_cam` | 5 | 80.77 |
| `mmu_l1dtlb_scheduler` | 4 | 96.77 |
| `ct_mmu_iutlb_entry` | 1 | 97.44 |
| `ct_mmu_iutlb_fst_entry` | 1 | 97.44 |

### 主要结论

- **L1TLB 整体未覆盖对象集中在 `mmu_l1dtlb`、`mmu_l1itlb`、`mmu_l1dtlb_sva`、`mmu_l1dtlb_hit_rd`/`mmu_l1dtlb_hit_rd_sva` 等模块**，主要表现为：
  - **翻转覆盖（TOGGLE）缺口最多**：参数化 entry/bit 位段（如 `l1dtlb_ent_ppn[N][...]`、`l1dtlb_ent_vpn[N][...]`、`mb_entry_vpn[N][...]`）大多只在 0/1 号 entry 上翻转过，高位 entry（N=8..15）从未被写入或翻转，反映现有定向用例未遍历所有 16 个 entry。
  - **条件覆盖（COND）缺口**主要在 `mmu_l1dtlb` 主模块：例如 line 305/315 的 PTW/JTLB refill 完成 + 页错误/访问错误 + entry valid + WFC 状态 + 非 flush 的多 term 与表达式，部分 term 组合（如 pgflt||acc_err=0 同时 vld=0、state 非 WFC、flush=1）从未同时命中；line 957/958/969 的 `ref_id == N` 等值比较在 entry 2..7/3..7 上从未命中；line 1116/1120/1190 的 invalidation/比较表达式在高位 entry 上从未命中。
  - **行覆盖（LINE）缺口**集中在 `mmu_l1dtlb` 行 987-991（`is_jtlb_refill` 分支内 `entry_ref_*` 赋值），即 JTLB refill 路径从未真正执行；`mmu_l1itlb` 行 1192-1194（iUTLB 异常处理）也从未走到。
  - **FSM 迁移缺口**：`mmu_l1itlb` 中 `ref_cur_st`（iUTLB refill 状态机：IDLE/WFG/WFC/ABT）的 `WFG -> IDLE` 与 `WFG -> ABT` 两条迁移未覆盖，即在 WFG（等待 PTW 授权）状态下收到 `ifu_mmu_abort` 的回 idle / 转 ABT 的两条 abort 路径从未激励。
  - **断言/cover 命中缺口**：`mmu_l1dtlb_sva` 中 19 个 `gen_l1dtlb_entry_sva[N].a_va8_inv_clears_matching_entry` 在 entry 8..15 上从未成功；`mmu_l1dtlb_hit_rd_sva` 中大量 cover 点（`cp_*`）Matches=0，反映特定 hit/read 时序场景未采样到。

### 建议的定向激励

1. **遍历所有 16 个 dutlb entry**：构造用例让 entry 0..15 都被 install/refill/hit/invalidate 一次，可一次性闭合大量 entry 参数化的 TOGGLE/COND/cover 缺口（`l1dtlb_ent_*[N]`、`mb_entry_*[N]`、`gen_l1dtlb_entry_sva[N].*`）。
2. **JTLB/UTLB refill 路径**：当前 line 987-991 JTLB refill 分支从未执行，需要构造 utlb refill 触发 dutlb entry 更新的场景。
3. **PTW refill 异常组合**：针对 line 305/315 的多 term 表达式，构造 ptw_l1dtlb_ref_cmplt=1 同时 pgflt/accerr/vld/state/flush 不同取值的定向序列，覆盖 `0 1 1 1 1`、`1 1 0 1 1` 等缺失组合。
4. **iUTLB WFG 状态 abort 路径**：让 iUTLB miss 进入 WFG（等待 PTW 授权）后收到 `ifu_mmu_abort`，且分别配合 `credit_cnt != 0`（转 ABT）与 `credit_cnt == 0`（回 IDLE），覆盖 `ref_cur_st` 的两条缺失迁移。
5. **VA8 invalidation 命中 entry 8..15**：让 `tlboper_utlb_inv_va_req` 命中 dutlb entry 8..15 的 VPN，闭合 line 1116 与 `a_va8_inv_clears_matching_entry[N]` 缺口。
6. **`cpurst_b` 复位时序**：多个 SVA 模块 `cpurst_b` 端口 Toggle=No（1->0=No），说明测试中从未触发真正的复位下沿（功率/复位测试可补充）。

---

## 分模块详情

## 模块 `mmu_l1dtlb`

源码：`mmu/rtl/mmu_l1dtlb.sv`
原始未覆盖记录数：`938`；合并后唯一代码对象数：`244`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 987 | `entry_ref_ppn   = jtlb_utlb_ref_ppn;` | 0/N |
| 988 | `entry_ref_flg   = jtlb_utlb_ref_flg;` | 0/N |
| 989 | `entry_ref_pgflt = jtlb_dutlb_pgflt;` | 0/N |
| 990 | `entry_ref_acflt = 1'b0;` | 0/N |
| 991 | `entry_ref_pgs   = jtlb_utlb_ref_pgs;` | 0/N |

`mmu/rtl/mmu_l1dtlb.sv:987`

```systemverilog
       983:                     entry_ref_pgflt = ptw_l1tlb_pgflt;
       984:                     entry_ref_acflt = ptw_l1tlb_acc_err;
       985:     		            entry_ref_pgs   = ptw_l1tlb_ref_pgs;
       986:                 end else if (is_jtlb_refill) begin
       987: >>                  entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
```

`mmu/rtl/mmu_l1dtlb.sv:988`

```systemverilog
       984:                     entry_ref_acflt = ptw_l1tlb_acc_err;
       985:     		            entry_ref_pgs   = ptw_l1tlb_ref_pgs;
       986:                 end else if (is_jtlb_refill) begin
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988: >>                  entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
```

`mmu/rtl/mmu_l1dtlb.sv:989`

```systemverilog
       985:     		            entry_ref_pgs   = ptw_l1tlb_ref_pgs;
       986:                 end else if (is_jtlb_refill) begin
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989: >>                  entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
       993:                 end
```

`mmu/rtl/mmu_l1dtlb.sv:990`

```systemverilog
       986:                 end else if (is_jtlb_refill) begin
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990: >>                  entry_ref_acflt = 1'b0;
       991:     		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
       993:                 end
       994:             end
```

`mmu/rtl/mmu_l1dtlb.sv:991`

```systemverilog
       987:                     entry_ref_ppn   = jtlb_utlb_ref_ppn;
       988:                     entry_ref_flg   = jtlb_utlb_ref_flg;
       989:                     entry_ref_pgflt = jtlb_dutlb_pgflt;
       990:                     entry_ref_acflt = 1'b0;
       991: >>  		            entry_ref_pgs   = jtlb_utlb_ref_pgs;
       992:                     //entry_ref_acflt = jtlb_dutlb_acc_err;
       993:                 end
       994:             end
       995:     
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 305 | `EXPRESSION (ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err) && mb_entry_vld[ptw_l1dtlb_ref_id] && (mb_entry_state[ptw_l1dtlb_ref_id] == MB_STATE_WFC) && ((!...` | 0 1 1 1 1 Not Covered; 1 1 0 1 1 Not Covered | 4 |
| 315 | `EXPRESSION (jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt && mb_entry_vld[jtlb_dutlb_ref_id] && (mb_entry_state[jtlb_dutlb_ref_id] == MB_STATE_WFC) && ((!rtu_yy_xx_flush))))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered; 1 1 1 1 0 Not Covered | 6 |
| 802 | `EXPRESSION (miss0_vld_q && ((!miss0_abort_q)) && miss1_vld_q && ((!miss1_abort_q)) && (miss0_vpn_q == miss1_vpn_q))` | 1 0 1 1 1 Not Covered; 1 1 1 0 1 Not Covered | 4 |
| 817 | `EXPRESSION (miss0_vld_q && ((!miss0_abort_q)) && ((!mb_hit0)) && ((!rtu_yy_xx_flush)))` | 1 0 1 1 Not Covered | 2 |
| 817 | `EXPRESSION (miss1_vld_q && ((!miss1_abort_q)) && ((!mb_hit1)) && ((!same_4k_miss01)) && ((!rtu_yy_xx_flush)))` | 1 0 1 1 1 Not Covered | 2 |
| 957 | `EXPRESSION (jtlb_dutlb_ref_cmplt && (jtlb_dutlb_ref_id == 3[(EID_WIDTH - 1):0]))` | 1 1 Not Covered | 10 |
| 958 | `EXPRESSION (ptw_l1dtlb_ref_cmplt && (ptw_l1dtlb_ref_id == 2[(EID_WIDTH - 1):0]))` | 0 1 Not Covered | 12 |
| 969 | `EXPRESSION (gen_mb_entries[3].is_jtlb_refill || gen_mb_entries[3].is_ptw_refill)` | 1 0 Not Covered | 10 |
| 1116 | `EXPRESSION (tlboper_utlb_inv_va_req && l1dtlb_ent_vld[2] && (lsu_mmu_tlb_va[7:0] == l1dtlb_ent_vpn[2][7:0]))` | 1 1 1 Not Covered | 28 |
| 1120 | `EXPRESSION (regs_utlb_clr | tlboper_utlb_clr | ctc_inv_va_hit_clr[2])` | 0 0 1 Not Covered | 28 |
| 1190 | `EXPRESSION ((l1dtlb_ent_pgs[2][0] & u_l1dtlb_ent[2].hit0_4k) | (l1dtlb_ent_pgs[2][1] & u_l1dtlb_ent[2].hit0_2m) | (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[2].hit0_1g)))` | 0 0 1 Not Covered; 0 1 0 Not Covered | 46 |
| 1190 | `SUB-EXPRESSION (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[2].hit0_1g)` | 1 0 Not Covered; 1 1 Not Covered | 56 |
| 1190 | `SUB-EXPRESSION (l1dtlb_ent_pgs[7][1] & u_l1dtlb_ent[7].hit0_2m)` | 1 0 Not Covered; 1 1 Not Covered | 36 |
| 1194 | `EXPRESSION ((l1dtlb_ent_pgs[2][0] & u_l1dtlb_ent[2].hit1_4k) | (l1dtlb_ent_pgs[2][1] & u_l1dtlb_ent[2].hit1_2m) | (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[2].hit1_1g)))` | 0 0 1 Not Covered; 0 1 0 Not Covered | 46 |
| 1194 | `SUB-EXPRESSION (l1dtlb_ent_pgs[2][2] & u_l1dtlb_ent[2].hit1_1g)` | 1 0 Not Covered; 1 1 Not Covered | 56 |
| 1194 | `SUB-EXPRESSION (l1dtlb_ent_pgs[7][1] & u_l1dtlb_ent[7].hit1_2m)` | 1 0 Not Covered; 1 1 Not Covered | 36 |

`mmu/rtl/mmu_l1dtlb.sv:305`

```systemverilog
       302:     assign dutlb_read_type0 = dutlb_ori_read0;
       303:     assign dutlb_read_type1 = dutlb_ori_read1;
       304:     
       305: >>  assign expt_wr0_vld   = ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err)
       306:                           && mb_entry_vld[ptw_l1dtlb_ref_id]
       307:                           && (mb_entry_state[ptw_l1dtlb_ref_id] == MB_STATE_WFC)
       308:                           && !rtu_yy_xx_flush;
```

`mmu/rtl/mmu_l1dtlb.sv:315`

```systemverilog
       312:     assign expt_wr0_pgflt = ptw_l1tlb_pgflt;
       313:     assign expt_wr0_acflt = ptw_l1tlb_acc_err;
       314:     
       315: >>  assign expt_wr1_vld   = jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt
       316:                           && mb_entry_vld[jtlb_dutlb_ref_id]
       317:                           && (mb_entry_state[jtlb_dutlb_ref_id] == MB_STATE_WFC)
       318:                           && !rtu_yy_xx_flush;
```

`mmu/rtl/mmu_l1dtlb.sv:802`

```systemverilog
       799:         mb_hit1 = |mb_hit1_vec;
       800:     end
       801:     
       802: >>  assign same_4k_miss01 = miss0_vld_q && !miss0_abort_q
       803:                           && miss1_vld_q && !miss1_abort_q
       804:                           && (miss0_vpn_q == miss1_vpn_q);
       805:     
```

`mmu/rtl/mmu_l1dtlb.sv:817`

```systemverilog
       814:         .VPN_WIDTH(VPN_WIDTH),
       815:         .IID_WIDTH(IID_WIDTH),
       816:         .PORT_WIDTH(1)
       817: >>  ) x_allocator (
       818:         .cpurst_b(cpurst_b),
       819:         .forever_cpuclk(forever_cpuclk),
       820:         
```

`mmu/rtl/mmu_l1dtlb.sv:957`

```systemverilog
       954:             logic is_ptw_refill;
       955:             
       956:             // Check ID match for both sources
       957: >>          assign is_jtlb_refill = jtlb_dutlb_ref_cmplt && (jtlb_dutlb_ref_id == i[EID_WIDTH-1:0]);
       958:             assign is_ptw_refill  = ptw_l1dtlb_ref_cmplt && (ptw_l1dtlb_ref_id == i[EID_WIDTH-1:0]);
       959:     
       960:     	logic [PGS_WIDTH-1:0]   entry_ref_pgs;
```

`mmu/rtl/mmu_l1dtlb.sv:958`

```systemverilog
       955:             
       956:             // Check ID match for both sources
       957:             assign is_jtlb_refill = jtlb_dutlb_ref_cmplt && (jtlb_dutlb_ref_id == i[EID_WIDTH-1:0]);
       958: >>          assign is_ptw_refill  = ptw_l1dtlb_ref_cmplt && (ptw_l1dtlb_ref_id == i[EID_WIDTH-1:0]);
       959:     
       960:     	logic [PGS_WIDTH-1:0]   entry_ref_pgs;
       961:             logic                   entry_ref_vld;
```

`mmu/rtl/mmu_l1dtlb.sv:969`

```systemverilog
       966:     
       967:             // Combine Valid (collision possible logic handled by ID check, 
       968:             // usually ID collision implies logic error elsewhere, but OR is safe)
       969: >>          assign entry_ref_vld = is_jtlb_refill || is_ptw_refill;
       970:     
       971:             // Data Mux: Select data source based on who is refilling
       972:             always_comb begin
```

`mmu/rtl/mmu_l1dtlb.sv:1116`

```systemverilog
      1113:             // Invalidation Logic (VA Match)
      1114:             //----------------------------------------------------------
      1115:             // Clear entry if invalidation request matches the partial VPN (bits [7:0])
      1116: >>          assign ctc_inv_va_hit_clr[l1dtlb_ent] = tlboper_utlb_inv_va_req
      1117:                                                   && l1dtlb_ent_vld[l1dtlb_ent]
      1118:                                                   && (lsu_mmu_tlb_va[7:0] == l1dtlb_ent_vpn[l1dtlb_ent][7:0]); 
      1119:     
```

`mmu/rtl/mmu_l1dtlb.sv:1120`

```systemverilog
      1117:                                                   && l1dtlb_ent_vld[l1dtlb_ent]
      1118:                                                   && (lsu_mmu_tlb_va[7:0] == l1dtlb_ent_vpn[l1dtlb_ent][7:0]); 
      1119:     
      1120: >>          assign l1dtlb_entry_clr[l1dtlb_ent] = regs_utlb_clr 
      1121:                                                 | tlboper_utlb_clr 
      1122:                                                 | ctc_inv_va_hit_clr[l1dtlb_ent];
      1123:             
```

`mmu/rtl/mmu_l1dtlb.sv:1190`

```systemverilog
      1187:             // Select the correct comparator result based on the stored Page Size (pgs)
      1188:             // Assuming encoding: pgs[0]=4K, pgs[1]=2M, pgs[2]=1G
      1189:             
      1190: >>          assign l1dtlb_vpn_match0[l1dtlb_ent] = (l1dtlb_ent_pgs[l1dtlb_ent][0] & hit0_4k) 
      1191:                                                  | (l1dtlb_ent_pgs[l1dtlb_ent][1] & hit0_2m)
      1192:                                                  | (l1dtlb_ent_pgs[l1dtlb_ent][2] & hit0_1g);
      1193:     
```

`mmu/rtl/mmu_l1dtlb.sv:1194`

```systemverilog
      1191:                                                  | (l1dtlb_ent_pgs[l1dtlb_ent][1] & hit0_2m)
      1192:                                                  | (l1dtlb_ent_pgs[l1dtlb_ent][2] & hit0_1g);
      1193:     
      1194: >>          assign l1dtlb_vpn_match1[l1dtlb_ent] = (l1dtlb_ent_pgs[l1dtlb_ent][0] & hit1_4k) 
      1195:                                                  | (l1dtlb_ent_pgs[l1dtlb_ent][1] & hit1_2m)
      1196:                                                  | (l1dtlb_ent_pgs[l1dtlb_ent][2] & hit1_1g);
      1197:     
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 980 | `980                    if (is_ptw_refill) begin` | 0 1 Not Covered |
| 980 | `980                    if (is_ptw_refill) begin` | 0 1 Not Covered |
| 980 | `980                    if (is_ptw_refill) begin` | 0 1 Not Covered |
| 980 | `980                    if (is_ptw_refill) begin` | 0 1 Not Covered |
| 980 | `980                    if (is_ptw_refill) begin` | 0 1 Not Covered |

`mmu/rtl/mmu_l1dtlb.sv:980`

```systemverilog
       976:                 entry_ref_pgflt = 1'b0;
       977:                 entry_ref_acflt = 1'b0;
       978:     	          entry_ref_pgs   = jtlb_utlb_ref_pgs;
       979:     
       980: >>              if (is_ptw_refill) begin
       981:                     entry_ref_ppn   = ptw_l1tlb_ref_ppn;
       982:                     entry_ref_flg   = ptw_l1tlb_ref_flg;
       983:                     entry_ref_pgflt = ptw_l1tlb_pgflt;
       984:                     entry_ref_acflt = ptw_l1tlb_acc_err;
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input  logic         cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 23 | `pad_yy_icg_scan_en -> input  logic         pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 27 | `cp0_mmu_mpp[0] -> input  logic [1:0]   cp0_mmu_mpp,` | Toggle=No, 1->0=Yes, 0->1=No | INPUT | 1 |
| 34 | `hpcp_mmu_cnt_en -> input  logic         hpcp_mmu_cnt_en,` | Toggle=No, 1->0=Yes, 0->1=No | INPUT | 1 |
| 53 | `mmu_lsu_stall0 -> output logic         mmu_lsu_stall0,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 72 | `mmu_lsu_stall1 -> output logic         mmu_lsu_stall1,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 86 | `pmp_mmu_flg1[3] -> input  logic [3:0]   pmp_mmu_flg1,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 89 | `sysmap_mmu_flg0[0] -> input  logic [4:0]   sysmap_mmu_flg0,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 90 | `sysmap_mmu_flg1[0] -> input  logic [4:0]   sysmap_mmu_flg1,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 106 | `ptw_l1tlb_ref_vpn[26] -> input  logic [26:0]  ptw_l1tlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 107 | `ptw_l1tlb_ref_ppn[23:21] -> input  logic [27:0]  ptw_l1tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 130 | `biu_mmu_smp_disable -> input  logic         biu_mmu_smp_disable,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 133 | `dutlb_top_ref_cur_st[2:0] -> output logic [2:0]   dutlb_top_ref_cur_st,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 134 | `dutlb_top_ref_type -> output logic         dutlb_top_ref_type,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 135 | `dutlb_top_scd_updt -> output logic         dutlb_top_scd_updt,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 142 | `jtlb_utlb_ref_ppn[20] -> input  logic [27:0]  jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 142 | `jtlb_utlb_ref_ppn[23:21] -> input  logic [27:0]  jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 142 | `jtlb_utlb_ref_ppn[27:24] -> input  logic [27:0]  jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |

`mmu/rtl/mmu_l1dtlb.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter NUM_ENTRY  = 16
        18:     )(
        19:         // Clock and Reset
        20: >>      input  logic         cpurst_b,
        21:         input  logic         forever_cpuclk,
        22:         input  logic         utlb_clk,
        23:         input  logic         pad_yy_icg_scan_en,
```

`mmu/rtl/mmu_l1dtlb.sv:23` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        20:         input  logic         cpurst_b,
        21:         input  logic         forever_cpuclk,
        22:         input  logic         utlb_clk,
        23: >>      input  logic         pad_yy_icg_scan_en,
        24:         
        25:         // SysReg
        26:         input  logic         cp0_mmu_icg_en,
```

`mmu/rtl/mmu_l1dtlb.sv:27` (声明 `cp0_mmu_mpp`)

```systemverilog
        24:         
        25:         // SysReg
        26:         input  logic         cp0_mmu_icg_en,
        27: >>      input  logic [1:0]   cp0_mmu_mpp,
        28:         input  logic         cp0_mmu_mprv,
        29:         input  logic         cp0_mmu_mxr,
        30:         input  logic         cp0_mmu_sum,
```

`mmu/rtl/mmu_l1dtlb.sv:34` (声明 `hpcp_mmu_cnt_en`)

```systemverilog
        31:         input  logic [1:0]   cp0_yy_priv_mode,
        32:         input  logic         regs_mmu_en,
        33:         input  logic         regs_utlb_clr,
        34: >>      input  logic         hpcp_mmu_cnt_en,
        35:         
        36:         // LSU Interface - Port 0
        37:         input  logic         lsu_mmu_va0_vld,
```

`mmu/rtl/mmu_l1dtlb.sv:53` (声明 `mmu_lsu_stall0`)

```systemverilog
        50:         output logic         mmu_lsu_access_fault0,
        51:         output logic         mmu_lsu_page_fault0,
        52:         output logic         mmu_lsu_sec0,
        53: >>      output logic         mmu_lsu_stall0,
        54:         
        55:         // LSU Interface - Port 1
        56:         input  logic         lsu_mmu_va1_vld,
```

`mmu/rtl/mmu_l1dtlb.sv:72` (声明 `mmu_lsu_stall1`)

```systemverilog
        69:         output logic         mmu_lsu_access_fault1,
        70:         output logic         mmu_lsu_page_fault1,
        71:         output logic         mmu_lsu_sec1,
        72: >>      output logic         mmu_lsu_stall1,
        73:         
        74:         // STAMO
        75:         input  logic         lsu_mmu_stamo_vld,
```

`mmu/rtl/mmu_l1dtlb.sv:86` (声明 `pmp_mmu_flg1`)

```systemverilog
        83:         output logic [27:0]  mmu_pmp_pa0,
        84:         output logic [27:0]  mmu_pmp_pa1,
        85:         input  logic [3:0]   pmp_mmu_flg0,
        86: >>      input  logic [3:0]   pmp_mmu_flg1,
        87:         
        88:         // SystemMap
        89:         input  logic [4:0]   sysmap_mmu_flg0,
```

`mmu/rtl/mmu_l1dtlb.sv:89` (声明 `sysmap_mmu_flg0`)

```systemverilog
        86:         input  logic [3:0]   pmp_mmu_flg1,
        87:         
        88:         // SystemMap
        89: >>      input  logic [4:0]   sysmap_mmu_flg0,
        90:         input  logic [4:0]   sysmap_mmu_flg1,
        91:         output logic [27:0]  mmu_sysmap_pa0,
        92:         output logic [27:0]  mmu_sysmap_pa1,
```

`mmu/rtl/mmu_l1dtlb.sv:90` (声明 `sysmap_mmu_flg1`)

```systemverilog
        87:         
        88:         // SystemMap
        89:         input  logic [4:0]   sysmap_mmu_flg0,
        90: >>      input  logic [4:0]   sysmap_mmu_flg1,
        91:         output logic [27:0]  mmu_sysmap_pa0,
        92:         output logic [27:0]  mmu_sysmap_pa1,
        93:         
```

`mmu/rtl/mmu_l1dtlb.sv:106` (声明 `ptw_l1tlb_ref_vpn`)

```systemverilog
       103:         input  logic         ptw_l1dtlb_ref_pavld,
       104:         input  logic         ptw_l1dtlb_ref_cmplt,
       105:         input  logic [2:0]   ptw_l1dtlb_ref_id,
       106: >>      input  logic [26:0]  ptw_l1tlb_ref_vpn,
       107:         input  logic [27:0]  ptw_l1tlb_ref_ppn,
       108:         input  logic         ptw_l1tlb_acc_err,
       109:         input  logic         ptw_l1tlb_pgflt,
```

`mmu/rtl/mmu_l1dtlb.sv:107` (声明 `ptw_l1tlb_ref_ppn`)

```systemverilog
       104:         input  logic         ptw_l1dtlb_ref_cmplt,
       105:         input  logic [2:0]   ptw_l1dtlb_ref_id,
       106:         input  logic [26:0]  ptw_l1tlb_ref_vpn,
       107: >>      input  logic [27:0]  ptw_l1tlb_ref_ppn,
       108:         input  logic         ptw_l1tlb_acc_err,
       109:         input  logic         ptw_l1tlb_pgflt,
       110:         input  logic [13:0]  ptw_l1tlb_ref_flg,
```

`mmu/rtl/mmu_l1dtlb.sv:130` (声明 `biu_mmu_smp_disable`)

```systemverilog
       127:         //output logic         dutlb_arb_cmplt,
       128:         
       129:         //input  logic         arb_dutlb_grant,
       130: >>      input  logic         biu_mmu_smp_disable,
       131:         
       132:         output logic         dutlb_ptw_wfc,
       133:         output logic [2:0]   dutlb_top_ref_cur_st,
```

`mmu/rtl/mmu_l1dtlb.sv:133` (声明 `dutlb_top_ref_cur_st`)

```systemverilog
       130:         input  logic         biu_mmu_smp_disable,
       131:         
       132:         output logic         dutlb_ptw_wfc,
       133: >>      output logic [2:0]   dutlb_top_ref_cur_st,
       134:         output logic         dutlb_top_ref_type,
       135:         output logic         dutlb_top_scd_updt,
       136:         output logic         dutlb_xx_mmu_off,
```

`mmu/rtl/mmu_l1dtlb.sv:134` (声明 `dutlb_top_ref_type`)

```systemverilog
       131:         
       132:         output logic         dutlb_ptw_wfc,
       133:         output logic [2:0]   dutlb_top_ref_cur_st,
       134: >>      output logic         dutlb_top_ref_type,
       135:         output logic         dutlb_top_scd_updt,
       136:         output logic         dutlb_xx_mmu_off,
       137:         
```

`mmu/rtl/mmu_l1dtlb.sv:135` (声明 `dutlb_top_scd_updt`)

```systemverilog
       132:         output logic         dutlb_ptw_wfc,
       133:         output logic [2:0]   dutlb_top_ref_cur_st,
       134:         output logic         dutlb_top_ref_type,
       135: >>      output logic         dutlb_top_scd_updt,
       136:         output logic         dutlb_xx_mmu_off,
       137:         
       138:         input  logic         jtlb_dutlb_ref_pavld,
```

`mmu/rtl/mmu_l1dtlb.sv:142` (声明 `jtlb_utlb_ref_ppn`)

```systemverilog
       139:         input  logic         jtlb_dutlb_ref_cmplt,
       140:         input  logic [2:0]   jtlb_dutlb_ref_id,
       141:         input  logic [26:0]  jtlb_utlb_ref_vpn,
       142: >>      input  logic [27:0]  jtlb_utlb_ref_ppn,
       143:         //input  logic         jtlb_dutlb_acc_err,
       144:         input  logic         jtlb_dutlb_pgflt,
       145:         input  logic [13:0]  jtlb_utlb_ref_flg,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 156 | `mb_clk_en -> logic mb_clk, mb_clk_en;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 157 | `sched_clk_en -> logic sched_clk, sched_clk_en;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 158 | `dplru_clk_en -> logic dplru_clk, dplru_clk_en;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 159 | `dutlb_clk_en -> logic dutlb_clk, dutlb_clk_en;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 210 | `entry_flg[0][0] -> logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 210 | `entry_flg[0][6:4] -> logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 210 | `entry_flg[1][2:0] -> logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 210 | `entry_flg[1][6:5] -> logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 15 |
| 210 | `entry_flg[2][10:9] -> logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 14 |
| 210 | `entry_flg[3][3:0] -> logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 13 |
| - | `Other bits of entry_flg[15:0][13:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 212 | `entry_ppn[0][15] -> logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 33 |
| 212 | `entry_ppn[0][27:24] -> logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 16 |
| 212 | `entry_ppn[1][20:19] -> logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 212 | `entry_ppn[3][11:10] -> logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 212 | `entry_ppn[3][20:18] -> logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 12 |
| - | `Other bits of entry_ppn[15:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 213 | `l1dtlb_ent_pgs[5][1] -> logic [NUM_ENTRY-1:0][PGS_WIDTH-1:0] l1dtlb_ent_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 10 |
| 213 | `l1dtlb_ent_pgs[6][1:0] -> logic [NUM_ENTRY-1:0][PGS_WIDTH-1:0] l1dtlb_ent_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of l1dtlb_ent_pgs[15:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 217 | `utlb_refill_vpn[26] -> logic [VPN_WIDTH-1:0]    utlb_refill_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 218 | `utlb_refill_ppn[23:21] -> logic [PPN_WIDTH-1:0]    utlb_refill_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 237 | `mb_entry_vpn[2][11] -> logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 13 |
| 237 | `mb_entry_vpn[2][20:19] -> logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 237 | `mb_entry_vpn[5][1:0] -> logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of mb_entry_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 238 | `mb_entry_iid[3][1:0] -> logic [MB_DEPTH-1:0][IID_WIDTH-1:0]    mb_entry_iid;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 238 | `mb_entry_iid[5][0] -> logic [MB_DEPTH-1:0][IID_WIDTH-1:0]    mb_entry_iid;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| - | `Other bits of mb_entry_iid[7:0][6:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 239 | `mb_entry_pgs[2][0] -> logic [MB_DEPTH-1:0][PGS_WIDTH-1:0]    mb_entry_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of mb_entry_pgs[7:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 257 | `issue_req -> logic                  issue_req;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 258 | `issue_vpn[26:0] -> logic [VPN_WIDTH-1:0]  issue_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 259 | `issue_eid[2:0] -> logic [EID_WIDTH-1:0]  issue_eid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 289 | `expt_hit_vec[7:3] -> logic [MB_DEPTH-1:0] expt_hit_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 297 | `expt_wr1_acflt -> logic expt_wr0_acflt, expt_wr1_acflt;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[0] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 16 |
| 513 | `entry_flg_vec[6:4] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[16:14] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[20:19] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[22:21] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[30:28] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[34:33] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[36:35] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[38:37] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[45:42] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[48:47] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[50:49] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[52:51] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[59:56] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[62:61] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[64:63] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[66:65] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[73:70] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[76:75] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[78:77] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[80:79] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[87:84] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[90:89] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[92:91] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[94:93] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[101:98] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[104:103] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[106:105] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[108:107] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[115:112] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[118:117] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[120:119] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[122:121] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[129:126] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[132:131] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[134:133] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[136:135] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[143:140] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[146:145] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[148:147] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[150:149] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[157:154] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[160:159] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[162:161] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[164:163] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[171:168] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[174:173] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[176:175] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[178:177] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[185:182] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[188:187] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[190:189] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[192:191] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[199:196] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[202:201] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[204:203] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[206:205] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[213:210] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[216:215] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 513 | `entry_flg_vec[218:217] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 513 | `entry_flg_vec[220:219] -> logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[15] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 34 |
| 514 | `entry_ppn_vec[23:21] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[27:24] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[48:47] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[51:49] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[55:52] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[76:75] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[79:77] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[83:80] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[95:94] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[104:102] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[107:105] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[111:108] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[132:130] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[135:133] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[139:136] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[160:158] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[163:161] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[167:164] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[179:178] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[188:186] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[191:189] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[195:192] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[207:206] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[216:214] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[219:217] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[223:220] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[235:234] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[244:243] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[247:245] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[251:248] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[263:262] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[272:270] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[275:273] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[279:276] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[291:290] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[300:298] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[303:301] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[307:304] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[319:318] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[328:326] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[331:329] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[335:332] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[347:346] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[356:354] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[359:357] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[363:360] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[375:374] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[384:382] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[387:385] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[391:388] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[403:402] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[412:410] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[415:413] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[419:416] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[431:430] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[440:438] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 514 | `entry_ppn_vec[443:441] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 514 | `entry_ppn_vec[447:444] -> logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 559 | `lsu_mmu_stamo_vld0 -> logic lsu_mmu_stamo_vld0;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 560 | `lsu_mmu_stamo_pa0[27:0] -> logic [PPN_WIDTH-1:0] lsu_mmu_stamo_pa0;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 781 | `mb_hit0_vec[7:3] -> logic [MB_DEPTH-1:0] mb_hit0_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 782 | `mb_hit1_vec[7:3] -> logic [MB_DEPTH-1:0] mb_hit1_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 850 | `mb_entry_store[3] -> logic [MB_DEPTH-1:0] mb_entry_store;` | Toggle=No, 1->0=No, 0->1=No | 4 |
| 901 | `mb_entry_ppn[0][19] -> logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 901 | `mb_entry_ppn[2][6:0] -> logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 901 | `mb_entry_ppn[2][18:9] -> logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of mb_entry_ppn[7:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 902 | `mb_entry_flg[2][3:0] -> logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 902 | `mb_entry_flg[2][6:5] -> logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 902 | `mb_entry_flg[2][13:9] -> logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of mb_entry_flg[7:0][13:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 903 | `mb_entry_wfi[7:3] -> logic [MB_DEPTH-1:0]                mb_entry_wfi;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1082 | `utlb_upd_vpn[26] -> logic [VPN_WIDTH-1:0] utlb_upd_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1083 | `utlb_upd_ppn[23:21] -> logic [PPN_WIDTH-1:0] utlb_upd_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1091 | `ctc_inv_va_hit_clr[15:2] -> logic [15:0] ctc_inv_va_hit_clr;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1096 | `l1dtlb_ent_vpn[0][11] -> logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 13 |
| 1096 | `l1dtlb_ent_vpn[0][24:22] -> logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 1096 | `l1dtlb_ent_vpn[1][25:23] -> logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 1096 | `l1dtlb_ent_vpn[2][25:22] -> logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 1096 | `l1dtlb_ent_vpn[3][10:9] -> logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 1096 | `l1dtlb_ent_vpn[3][23:22] -> logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of l1dtlb_ent_vpn[15:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1097 | `l1dtlb_ent_ppn[0][15] -> logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 33 |
| 1097 | `l1dtlb_ent_ppn[0][27:24] -> logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 16 |
| 1097 | `l1dtlb_ent_ppn[1][20:19] -> logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 1097 | `l1dtlb_ent_ppn[3][11:10] -> logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 1097 | `l1dtlb_ent_ppn[3][20:18] -> logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 12 |
| - | `Other bits of l1dtlb_ent_ppn[15:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 1098 | `l1dtlb_ent_flg[0][0] -> logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 1098 | `l1dtlb_ent_flg[0][6:4] -> logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 1098 | `l1dtlb_ent_flg[1][2:0] -> logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 1098 | `l1dtlb_ent_flg[1][6:5] -> logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 15 |
| 1098 | `l1dtlb_ent_flg[2][10:9] -> logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 14 |
| 1098 | `l1dtlb_ent_flg[3][3:0] -> logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 13 |
| - | `Other bits of l1dtlb_ent_flg[15:0][13:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_mb_entries[0].entry_ref_ppn[23:21]` | Toggle=No, 1->0=No, 0->1=No | 8 |
| - | `gen_mb_entries[1].alloc_vpn_i[26:25]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_mb_entries[1].entry_ref_ppn[20]` | Toggle=No, 1->0=No, 0->1=Yes | 7 |
| - | `gen_mb_entries[1].entry_ref_ppn[27:24]` | Toggle=No, 1->0=No, 0->1=Yes | 7 |
| - | `gen_mb_entries[2].alloc_vpn_i[12]` | Toggle=No, 1->0=No, 0->1=No | 7 |
| - | `gen_mb_entries[2].alloc_vpn_i[26:21]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_mb_entries[3].alloc_vpn_i[26:11]` | Toggle=No, 1->0=No, 0->1=No | 5 |
| - | `gen_mb_entries[3].is_jtlb_refill` | Toggle=No, 1->0=No, 0->1=No | 5 |
| - | `gen_mb_entries[3].entry_ref_acflt` | Toggle=No, 1->0=No, 0->1=No | 5 |
| - | `gen_mb_entries[4].alloc_iid_i[1]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_mb_entries[4].alloc_store_i` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1dtlb.sv:156` (声明 `mb_clk_en`)

```systemverilog
       153:     //!************************************************
       154:     //! Clock Generation
       155:     //!************************************************
       156: >>  logic mb_clk, mb_clk_en;
       157:     logic sched_clk, sched_clk_en;
       158:     logic dplru_clk, dplru_clk_en;
       159:     logic dutlb_clk, dutlb_clk_en;
```

`mmu/rtl/mmu_l1dtlb.sv:157` (声明 `sched_clk_en`)

```systemverilog
       154:     //! Clock Generation
       155:     //!************************************************
       156:     logic mb_clk, mb_clk_en;
       157: >>  logic sched_clk, sched_clk_en;
       158:     logic dplru_clk, dplru_clk_en;
       159:     logic dutlb_clk, dutlb_clk_en;
       160:     
```

`mmu/rtl/mmu_l1dtlb.sv:158` (声明 `dplru_clk_en`)

```systemverilog
       155:     //!************************************************
       156:     logic mb_clk, mb_clk_en;
       157:     logic sched_clk, sched_clk_en;
       158: >>  logic dplru_clk, dplru_clk_en;
       159:     logic dutlb_clk, dutlb_clk_en;
       160:     
       161:     logic cp0_mach_mode, cp0_supv_mode, cp0_user_mode;
```

`mmu/rtl/mmu_l1dtlb.sv:159` (声明 `dutlb_clk_en`)

```systemverilog
       156:     logic mb_clk, mb_clk_en;
       157:     logic sched_clk, sched_clk_en;
       158:     logic dplru_clk, dplru_clk_en;
       159: >>  logic dutlb_clk, dutlb_clk_en;
       160:     
       161:     logic cp0_mach_mode, cp0_supv_mode, cp0_user_mode;
       162:     logic [1:0] cp0_priv_mode;
```

`mmu/rtl/mmu_l1dtlb.sv:210` (声明 `entry_flg`)

```systemverilog
       207:     //! TLB Entry Signals (16+1 entries)
       208:     //!************************************************
       209:     logic [NUM_ENTRY-1:0]               entry_vld;
       210: >>  logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;
       211:     logic [NUM_ENTRY-1:0]               entry_hit0, entry_hit1;
       212:     logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;
       213:     logic [NUM_ENTRY-1:0][PGS_WIDTH-1:0] l1dtlb_ent_pgs;
```

`mmu/rtl/mmu_l1dtlb.sv:212` (声明 `entry_ppn`)

```systemverilog
       209:     logic [NUM_ENTRY-1:0]               entry_vld;
       210:     logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;
       211:     logic [NUM_ENTRY-1:0]               entry_hit0, entry_hit1;
       212: >>  logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;
       213:     logic [NUM_ENTRY-1:0][PGS_WIDTH-1:0] l1dtlb_ent_pgs;
       214:     //! TLB Refill/Install Signals
       215:     logic                    utlb_refill_vld;
```

`mmu/rtl/mmu_l1dtlb.sv:213` (声明 `l1dtlb_ent_pgs`)

```systemverilog
       210:     logic [NUM_ENTRY-1:0][FLG_WIDTH-1:0] entry_flg;
       211:     logic [NUM_ENTRY-1:0]               entry_hit0, entry_hit1;
       212:     logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn;
       213: >>  logic [NUM_ENTRY-1:0][PGS_WIDTH-1:0] l1dtlb_ent_pgs;
       214:     //! TLB Refill/Install Signals
       215:     logic                    utlb_refill_vld;
       216:     logic [3:0]              utlb_refill_idx;
```

`mmu/rtl/mmu_l1dtlb.sv:217` (声明 `utlb_refill_vpn`)

```systemverilog
       214:     //! TLB Refill/Install Signals
       215:     logic                    utlb_refill_vld;
       216:     logic [3:0]              utlb_refill_idx;
       217: >>  logic [VPN_WIDTH-1:0]    utlb_refill_vpn;
       218:     logic [PPN_WIDTH-1:0]    utlb_refill_ppn;
       219:     logic [FLG_WIDTH-1:0]    utlb_refill_flg;
       220:     logic [2:0]		 utlb_refill_pgs;
```

`mmu/rtl/mmu_l1dtlb.sv:218` (声明 `utlb_refill_ppn`)

```systemverilog
       215:     logic                    utlb_refill_vld;
       216:     logic [3:0]              utlb_refill_idx;
       217:     logic [VPN_WIDTH-1:0]    utlb_refill_vpn;
       218: >>  logic [PPN_WIDTH-1:0]    utlb_refill_ppn;
       219:     logic [FLG_WIDTH-1:0]    utlb_refill_flg;
       220:     logic [2:0]		 utlb_refill_pgs;
       221:     
```

`mmu/rtl/mmu_l1dtlb.sv:237` (声明 `mb_entry_vpn`)

```systemverilog
       234:     //!************************************************
       235:     logic [MB_DEPTH-1:0]                   mb_entry_vld;
       236:     logic [MB_DEPTH-1:0][2:0]              mb_entry_state;
       237: >>  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;
       238:     logic [MB_DEPTH-1:0][IID_WIDTH-1:0]    mb_entry_iid;
       239:     logic [MB_DEPTH-1:0][PGS_WIDTH-1:0]    mb_entry_pgs;
       240:     //logic [MB_DEPTH-1:0]                   mb_entry_port_id;
```

`mmu/rtl/mmu_l1dtlb.sv:238` (声明 `mb_entry_iid`)

```systemverilog
       235:     logic [MB_DEPTH-1:0]                   mb_entry_vld;
       236:     logic [MB_DEPTH-1:0][2:0]              mb_entry_state;
       237:     logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;
       238: >>  logic [MB_DEPTH-1:0][IID_WIDTH-1:0]    mb_entry_iid;
       239:     logic [MB_DEPTH-1:0][PGS_WIDTH-1:0]    mb_entry_pgs;
       240:     //logic [MB_DEPTH-1:0]                   mb_entry_port_id;
       241:     logic [MB_DEPTH-1:0]                   mb_entry_issued;
```

`mmu/rtl/mmu_l1dtlb.sv:239` (声明 `mb_entry_pgs`)

```systemverilog
       236:     logic [MB_DEPTH-1:0][2:0]              mb_entry_state;
       237:     logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]    mb_entry_vpn;
       238:     logic [MB_DEPTH-1:0][IID_WIDTH-1:0]    mb_entry_iid;
       239: >>  logic [MB_DEPTH-1:0][PGS_WIDTH-1:0]    mb_entry_pgs;
       240:     //logic [MB_DEPTH-1:0]                   mb_entry_port_id;
       241:     logic [MB_DEPTH-1:0]                   mb_entry_issued;
       242:     logic [MB_DEPTH-1:0]                   mb_entry_ready;
```

`mmu/rtl/mmu_l1dtlb.sv:257` (声明 `issue_req`)

```systemverilog
       254:     logic [EID_WIDTH-1:0] alloc_sel0, alloc_sel1;
       255:     
       256:     // Scheduler outputs
       257: >>  logic                  issue_req;
       258:     logic [VPN_WIDTH-1:0]  issue_vpn;
       259:     logic [EID_WIDTH-1:0]  issue_eid;
       260:     logic                  dutlb_l2tlb_req_store;
```

`mmu/rtl/mmu_l1dtlb.sv:258` (声明 `issue_vpn`)

```systemverilog
       255:     
       256:     // Scheduler outputs
       257:     logic                  issue_req;
       258: >>  logic [VPN_WIDTH-1:0]  issue_vpn;
       259:     logic [EID_WIDTH-1:0]  issue_eid;
       260:     logic                  dutlb_l2tlb_req_store;
       261:     
```

`mmu/rtl/mmu_l1dtlb.sv:259` (声明 `issue_eid`)

```systemverilog
       256:     // Scheduler outputs
       257:     logic                  issue_req;
       258:     logic [VPN_WIDTH-1:0]  issue_vpn;
       259: >>  logic [EID_WIDTH-1:0]  issue_eid;
       260:     logic                  dutlb_l2tlb_req_store;
       261:     
       262:     
```

`mmu/rtl/mmu_l1dtlb.sv:289` (声明 `expt_hit_vec`)

```systemverilog
       286:     logic expt_match0, expt_match1;
       287:     logic expt_pgflt0, expt_pgflt1;
       288:     logic expt_acflt0, expt_acflt1;
       289: >>  logic [MB_DEPTH-1:0] expt_hit_vec;
       290:     logic [11:0] expt_wakeup;
       291:     logic [11:0] install_wakeup;
       292:     logic expt_wr0_vld, expt_wr1_vld;
```

`mmu/rtl/mmu_l1dtlb.sv:297` (声明 `expt_wr1_acflt`)

```systemverilog
       294:     logic [IID_WIDTH-1:0] expt_wr0_iid, expt_wr1_iid;
       295:     logic [VPN_WIDTH-1:0] expt_wr0_vpn, expt_wr1_vpn;
       296:     logic expt_wr0_pgflt, expt_wr1_pgflt;
       297: >>  logic expt_wr0_acflt, expt_wr1_acflt;
       298:     logic miss0_is_store;
       299:     logic miss1_is_store;
       300:     assign dutlb_ori_read0 = !lsu_mmu_st_inst0;
```

`mmu/rtl/mmu_l1dtlb.sv:513` (声明 `entry_flg_vec`)

```systemverilog
       510:     // The Hit Read module uses flattened vectors for parameterized ports.
       511:     // We need to pack the 2D arrays (entry_flg, entry_ppn) into 1D vectors.
       512:     
       513: >>  logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;
       514:     logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;
       515:     
       516:     genvar k;
```

`mmu/rtl/mmu_l1dtlb.sv:514` (声明 `entry_ppn_vec`)

```systemverilog
       511:     // We need to pack the 2D arrays (entry_flg, entry_ppn) into 1D vectors.
       512:     
       513:     logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec;
       514: >>  logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec;
       515:     
       516:     genvar k;
       517:     generate
```

`mmu/rtl/mmu_l1dtlb.sv:559` (声明 `lsu_mmu_stamo_vld0`)

```systemverilog
       556:     end
       557:     `endif
       558:     `endif
       559: >>  logic lsu_mmu_stamo_vld0;
       560:     logic [PPN_WIDTH-1:0] lsu_mmu_stamo_pa0;
       561:     
       562:     assign lsu_mmu_stamo_vld0 = 1'b0;
```

`mmu/rtl/mmu_l1dtlb.sv:560` (声明 `lsu_mmu_stamo_pa0`)

```systemverilog
       557:     `endif
       558:     `endif
       559:     logic lsu_mmu_stamo_vld0;
       560: >>  logic [PPN_WIDTH-1:0] lsu_mmu_stamo_pa0;
       561:     
       562:     assign lsu_mmu_stamo_vld0 = 1'b0;
       563:     assign lsu_mmu_stamo_pa0[PPN_WIDTH-1:0] = {PPN_WIDTH{1'b0}};
```

`mmu/rtl/mmu_l1dtlb.sv:781` (声明 `mb_hit0_vec`)

```systemverilog
       778:     logic mb_hit0;
       779:     logic mb_hit1;
       780:     logic same_4k_miss01;
       781: >>  logic [MB_DEPTH-1:0] mb_hit0_vec;
       782:     logic [MB_DEPTH-1:0] mb_hit1_vec;
       783:     
       784:     // ------------------------------------------------------------
```

`mmu/rtl/mmu_l1dtlb.sv:782` (声明 `mb_hit1_vec`)

```systemverilog
       779:     logic mb_hit1;
       780:     logic same_4k_miss01;
       781:     logic [MB_DEPTH-1:0] mb_hit0_vec;
       782: >>  logic [MB_DEPTH-1:0] mb_hit1_vec;
       783:     
       784:     // ------------------------------------------------------------
       785:     // Check if T1 requests match any existing valid MB entry
```

`mmu/rtl/mmu_l1dtlb.sv:850` (声明 `mb_entry_store`)

```systemverilog
       847:     //!************************************************
       848:     //! Scheduler Instance
       849:     //!************************************************
       850: >>  logic [MB_DEPTH-1:0] mb_entry_store;
       851:     mmu_l1dtlb_scheduler #(
       852:         .MB_DEPTH   (MB_DEPTH),
       853:         .VPN_WIDTH  (VPN_WIDTH),
```

`mmu/rtl/mmu_l1dtlb.sv:901` (声明 `mb_entry_ppn`)

```systemverilog
       898:     //!************************************************
       899:     //! New Signals for WFI/Install Logic
       900:     //!************************************************
       901: >>  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;
       902:     logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;
       903:     logic [MB_DEPTH-1:0]                mb_entry_wfi;
       904:     logic [MB_DEPTH-1:0]                refill_gnt_bus; // From Install
```

`mmu/rtl/mmu_l1dtlb.sv:902` (声明 `mb_entry_flg`)

```systemverilog
       899:     //! New Signals for WFI/Install Logic
       900:     //!************************************************
       901:     logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;
       902: >>  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;
       903:     logic [MB_DEPTH-1:0]                mb_entry_wfi;
       904:     logic [MB_DEPTH-1:0]                refill_gnt_bus; // From Install
       905:     
```

`mmu/rtl/mmu_l1dtlb.sv:903` (声明 `mb_entry_wfi`)

```systemverilog
       900:     //!************************************************
       901:     logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn;
       902:     logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg;
       903: >>  logic [MB_DEPTH-1:0]                mb_entry_wfi;
       904:     logic [MB_DEPTH-1:0]                refill_gnt_bus; // From Install
       905:     
       906:     //!************************************************
```

`mmu/rtl/mmu_l1dtlb.sv:1082` (声明 `utlb_upd_vpn`)

```systemverilog
      1079:     
      1080:     // 2. Global Update Signals (Shared Bus from Install Module)
      1081:     // These are wire aliases for readability, matching the Install module outputs
      1082: >>  logic [VPN_WIDTH-1:0] utlb_upd_vpn;
      1083:     logic [PPN_WIDTH-1:0] utlb_upd_ppn;
      1084:     logic [FLG_WIDTH-1:0] utlb_upd_flg;
      1085:     
```

`mmu/rtl/mmu_l1dtlb.sv:1083` (声明 `utlb_upd_ppn`)

```systemverilog
      1080:     // 2. Global Update Signals (Shared Bus from Install Module)
      1081:     // These are wire aliases for readability, matching the Install module outputs
      1082:     logic [VPN_WIDTH-1:0] utlb_upd_vpn;
      1083: >>  logic [PPN_WIDTH-1:0] utlb_upd_ppn;
      1084:     logic [FLG_WIDTH-1:0] utlb_upd_flg;
      1085:     
      1086:     assign utlb_upd_vpn = utlb_refill_vpn;
```

`mmu/rtl/mmu_l1dtlb.sv:1091` (声明 `ctc_inv_va_hit_clr`)

```systemverilog
      1088:     assign utlb_upd_flg = utlb_refill_flg;
      1089:     
      1090:     // 3. Entry Generation Loop
      1091: >>  logic [15:0] ctc_inv_va_hit_clr;
      1092:     logic [15:0]  l1dtlb_entry_clr;
      1093:     logic [15:0]  l1dtlb_ent_clk_en;
      1094:     logic [15:0]  l1dtlb_entry_clk;
```

`mmu/rtl/mmu_l1dtlb.sv:1096` (声明 `l1dtlb_ent_vpn`)

```systemverilog
      1093:     logic [15:0]  l1dtlb_ent_clk_en;
      1094:     logic [15:0]  l1dtlb_entry_clk;
      1095:     logic [15:0]  l1dtlb_ent_vld;
      1096: >>  logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;
      1097:     logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;
      1098:     logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;
      1099:     logic [15:0]  l1dtlb_vpn_match0;
```

`mmu/rtl/mmu_l1dtlb.sv:1097` (声明 `l1dtlb_ent_ppn`)

```systemverilog
      1094:     logic [15:0]  l1dtlb_entry_clk;
      1095:     logic [15:0]  l1dtlb_ent_vld;
      1096:     logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;
      1097: >>  logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;
      1098:     logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;
      1099:     logic [15:0]  l1dtlb_vpn_match0;
      1100:     logic [15:0]  l1dtlb_vpn_match1;
```

`mmu/rtl/mmu_l1dtlb.sv:1098` (声明 `l1dtlb_ent_flg`)

```systemverilog
      1095:     logic [15:0]  l1dtlb_ent_vld;
      1096:     logic [15:0][VPN_WIDTH-1:0]  l1dtlb_ent_vpn;
      1097:     logic [15:0][PPN_WIDTH-1:0]  l1dtlb_ent_ppn;
      1098: >>  logic [15:0][FLG_WIDTH-1:0]  l1dtlb_ent_flg;
      1099:     logic [15:0]  l1dtlb_vpn_match0;
      1100:     logic [15:0]  l1dtlb_vpn_match1;
      1101:     
```

## 模块 `mmu_l1dtlb_allocator`

源码：`mmu/rtl/mmu_l1dtlb_allocator.sv`
原始未覆盖记录数：`3`；合并后唯一代码对象数：`3`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 15 | `cpurst_b -> input  logic                    cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `req0_port_id -> input  logic [PORT_WIDTH-1:0]   req0_port_id,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 28 | `req1_port_id -> input  logic [PORT_WIDTH-1:0]   req1_port_id,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/mmu_l1dtlb_allocator.sv:15` (声明 `cpurst_b`)

```systemverilog
        12:         parameter PORT_WIDTH = 1
        13:     )(
        14:         //! Clock and Reset
        15: >>      input  logic                    cpurst_b,
        16:         input  logic                    forever_cpuclk,
        17:         
        18:         //! Port 0 Request
```

`mmu/rtl/mmu_l1dtlb_allocator.sv:22` (声明 `req0_port_id`)

```systemverilog
        19:         input  logic                    req0_vld,
        20:         input  logic [VPN_WIDTH-1:0]    req0_vpn,
        21:         input  logic [IID_WIDTH-1:0]    req0_iid,
        22: >>      input  logic [PORT_WIDTH-1:0]   req0_port_id,
        23:         
        24:         //! Port 1 Request
        25:         input  logic                    req1_vld,
```

`mmu/rtl/mmu_l1dtlb_allocator.sv:28` (声明 `req1_port_id`)

```systemverilog
        25:         input  logic                    req1_vld,
        26:         input  logic [VPN_WIDTH-1:0]    req1_vpn,
        27:         input  logic [IID_WIDTH-1:0]    req1_iid,
        28: >>      input  logic [PORT_WIDTH-1:0]   req1_port_id,
        29:         
        30:         //! Miss Buffer Valid Status
        31:         input  logic [MB_DEPTH-1:0]     mb_vld,
```

## 模块 `mmu_l1dtlb_mb_entry`

源码：`mmu/rtl/mmu_l1dtlb_mb_entry.sv`
原始未覆盖记录数：`28`；合并后唯一代码对象数：`26`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 200 | `state_nxt = STATE_IDLE;` | 0/N |
| 216 | `state_nxt = STATE_IDLE;` | 0/N |
| 228 | `default: state_nxt = STATE_IDLE;` | 0/N |

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:200`

```systemverilog
       196:     
       197:             STATE_WFI: begin
       198:                 if (abort_this_cyc) begin
       199:                     // Flush occurred while waiting to install
       200: >>                  state_nxt = STATE_IDLE;
       201:                 end else if (refill_gnt) begin
       202:                     // Finally granted permission to write to L1TLB
       203:                     state_nxt = STATE_IDLE;
       204:                 end
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:216`

```systemverilog
       212:             end
       213:     
       214:             STATE_ACFLT: begin
       215:                 if (abort_this_cyc)
       216: >>                  state_nxt = STATE_IDLE;
       217:                 else if (expt_hit)
       218:                     state_nxt = STATE_IDLE;
       219:             end
       220:             
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:228`

```systemverilog
       224:                     state_nxt = STATE_IDLE;
       225:                 end
       226:             end
       227:             
       228: >>          default: state_nxt = STATE_IDLE;
       229:         endcase
       230:     end
       231:     
       232:     //!************************************************
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 120 | `EXPRESSION (alloc_vld && ((!abort_this_cyc)))` | 1 0 Not Covered | 1 |
| 134 | `EXPRESSION (issue_sel && issue_grant)` | 1 0 Not Covered | 1 |
| 144 | `EXPRESSION (issue_sel && issue_grant)` | 1 0 Not Covered | 1 |
| 150 | `EXPRESSION (issue_sel && issue_grant)` | 1 0 Not Covered | 1 |
| 257 | `EXPRESSION (alloc_fire && (state_r == STATE_IDLE))` | 1 0 Not Covered | 1 |
| 283 | `EXPRESSION (alloc_fire && issue_sel && issue_grant)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| 288 | `EXPRESSION ((state_r == STATE_WFG) && issue_sel && issue_grant)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:120`

```systemverilog
       117:     // Only an RTU pipeline flush aborts pending refill state. TLB clear/invalidate
       118:     // operations target already-installed TLB entries, not in-flight refill data.
       119:     assign abort_this_cyc = rtu_yy_xx_flush;
       120: >>  assign alloc_fire = alloc_vld && !abort_this_cyc;
       121:     
       122:     //!************************************************
       123:     //! State Machine
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:134`

```systemverilog
       131:             STATE_IDLE: begin
       132:                 if (alloc_fire) begin
       133:                     // [FIX 2]: Check for immediate Bypass Grant
       134: >>                  if (issue_sel && issue_grant) begin
       135:                         state_nxt = STATE_WFC; // Bypass: Skip WFG, go directly to Wait Complete
       136:                     end else begin
       137:                         state_nxt = STATE_WFG; // Normal: Go to Wait Grant
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:144`

```systemverilog
       141:             
       142:             STATE_WFG: begin
       143:                 if (abort_this_cyc) begin
       144: >>                  if (issue_sel && issue_grant) begin
       145:                         // Race condition: Granted and Aborted same cycle -> go to ABT
       146:                         state_nxt = STATE_ABT;
       147:                     end else begin
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:150`

```systemverilog
       147:                     end else begin
       148:                         state_nxt = STATE_IDLE;
       149:                     end
       150: >>              end else if (issue_sel && issue_grant) begin
       151:                     // Successfully issued to L2TLB
       152:                     state_nxt = STATE_WFC;
       153:                 end
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:257`

```systemverilog
       254:     	pgs_r	  <= '0;
       255:         end else begin
       256:             // Allocation Phase: Capture Request Info
       257: >>          if (alloc_fire && state_r == STATE_IDLE) begin
       258:                 vpn_r     <= alloc_vpn;
       259:                 iid_r     <= alloc_iid;
       260:     //            port_id_r <= alloc_port_id;
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:283`

```systemverilog
       280:             issued_r <= 1'b0;
       281:         end else if (state_r == STATE_IDLE) begin
       282:             // [FIX]: Set issued flag if bypassed immediately
       283: >>          if (alloc_fire && issue_sel && issue_grant) begin
       284:                 issued_r <= 1'b1;
       285:             end else begin
       286:                 issued_r <= 1'b0;
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:288`

```systemverilog
       285:             end else begin
       286:                 issued_r <= 1'b0;
       287:             end
       288: >>      end else if (state_r == STATE_WFG && issue_sel && issue_grant) begin
       289:             // Set issued flag if issued from WFG
       290:             issued_r <= 1'b1;
       291:         end
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 130 | `130            case (state_r)` | STATE_WFI - - - - - - - - - - - 1 - - - - - - Not Covered |
| 130 | `130            case (state_r)` | STATE_ACFLT - - - - - - - - - - - - - - - 1 - - Not Covered |
| 130 | `130            case (state_r)` | default - - - - - - - - - - - - - - - - - - Not Covered |

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:130`

```systemverilog
       126:     
       127:     always_comb begin
       128:         state_nxt = state_r;
       129:         
       130: >>      case (state_r)
       131:             STATE_IDLE: begin
       132:                 if (alloc_fire) begin
       133:                     // [FIX 2]: Check for immediate Bypass Grant
       134:                     if (issue_sel && issue_grant) begin
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 18 | `cpurst_b -> input  logic                     cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `pad_yy_icg_scan_en -> input  logic                     pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 40 | `refill_ppn[23:21] -> input  logic [PPN_WIDTH-1:0]     refill_ppn,        // Data payload` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 55 | `entry_ppn[8] -> output logic [PPN_WIDTH-1:0]     entry_ppn,         // Output latched PPN` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 55 | `entry_ppn[27:20] -> output logic [PPN_WIDTH-1:0]     entry_ppn,         // Output latched PPN` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 56 | `entry_flg[4] -> output logic [FLG_WIDTH-1:0]     entry_flg,         // Output latched Flags` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 56 | `entry_flg[8:7] -> output logic [FLG_WIDTH-1:0]     entry_flg,         // Output latched Flags` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 58 | `entry_pgs[2] -> output logic [2:0]		     entry_pgs,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:18` (声明 `cpurst_b`)

```systemverilog
        15:         parameter PORT_WIDTH = 1
        16:     )(
        17:         //! Clock and Reset
        18: >>      input  logic                     cpurst_b,
        19:         input  logic                     forever_cpuclk,
        20:         input  logic                     mb_clk,
        21:         input  logic                     cp0_mmu_icg_en,
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:22` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        19:         input  logic                     forever_cpuclk,
        20:         input  logic                     mb_clk,
        21:         input  logic                     cp0_mmu_icg_en,
        22: >>      input  logic                     pad_yy_icg_scan_en,
        23:     
        24:         //! Allocate Interface (from Allocator/Mux)
        25:         input  logic                     alloc_vld,
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:40` (声明 `refill_ppn`)

```systemverilog
        37:         input  logic                     refill_gnt,        // Permission to write to L1TLB RAM
        38:         input  logic                     refill_pgflt,
        39:         input  logic                     refill_acflt,
        40: >>      input  logic [PPN_WIDTH-1:0]     refill_ppn,        // Data payload
        41:         input  logic [FLG_WIDTH-1:0]     refill_flg,        // Data payload
        42:         input  logic [2:0]		     refill_pgs,
        43:         input  logic                     expt_hit,
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:55` (声明 `entry_ppn`)

```systemverilog
        52:         output logic                     entry_vld,
        53:         output logic [2:0]               entry_state,
        54:         output logic [VPN_WIDTH-1:0]     entry_vpn,
        55: >>      output logic [PPN_WIDTH-1:0]     entry_ppn,         // Output latched PPN
        56:         output logic [FLG_WIDTH-1:0]     entry_flg,         // Output latched Flags
        57:         output logic [IID_WIDTH-1:0]     entry_iid,
        58:         output logic [2:0]		     entry_pgs,
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:56` (声明 `entry_flg`)

```systemverilog
        53:         output logic [2:0]               entry_state,
        54:         output logic [VPN_WIDTH-1:0]     entry_vpn,
        55:         output logic [PPN_WIDTH-1:0]     entry_ppn,         // Output latched PPN
        56: >>      output logic [FLG_WIDTH-1:0]     entry_flg,         // Output latched Flags
        57:         output logic [IID_WIDTH-1:0]     entry_iid,
        58:         output logic [2:0]		     entry_pgs,
        59:         //output logic [PORT_WIDTH-1:0]    entry_port_id,
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:58` (声明 `entry_pgs`)

```systemverilog
        55:         output logic [PPN_WIDTH-1:0]     entry_ppn,         // Output latched PPN
        56:         output logic [FLG_WIDTH-1:0]     entry_flg,         // Output latched Flags
        57:         output logic [IID_WIDTH-1:0]     entry_iid,
        58: >>      output logic [2:0]		     entry_pgs,
        59:         //output logic [PORT_WIDTH-1:0]    entry_port_id,
        60:         output logic                     entry_store,       // New: Store attribute output
        61:         output logic                     entry_issued,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 84 | `ppn_r[8] -> logic [PPN_WIDTH-1:0]   ppn_r;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 84 | `ppn_r[27:20] -> logic [PPN_WIDTH-1:0]   ppn_r;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 85 | `flg_r[4] -> logic [FLG_WIDTH-1:0]   flg_r;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 85 | `flg_r[8:7] -> logic [FLG_WIDTH-1:0]   flg_r;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 87 | `pgs_r[2] -> logic [2:0]		pgs_r;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:84` (声明 `ppn_r`)

```systemverilog
        81:     //!************************************************
        82:     logic [2:0]             state_r;
        83:     logic [VPN_WIDTH-1:0]   vpn_r;
        84: >>  logic [PPN_WIDTH-1:0]   ppn_r;
        85:     logic [FLG_WIDTH-1:0]   flg_r;
        86:     logic [IID_WIDTH-1:0]   iid_r;
        87:     logic [2:0]		pgs_r;
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:85` (声明 `flg_r`)

```systemverilog
        82:     logic [2:0]             state_r;
        83:     logic [VPN_WIDTH-1:0]   vpn_r;
        84:     logic [PPN_WIDTH-1:0]   ppn_r;
        85: >>  logic [FLG_WIDTH-1:0]   flg_r;
        86:     logic [IID_WIDTH-1:0]   iid_r;
        87:     logic [2:0]		pgs_r;
        88:     //logic [PORT_WIDTH-1:0]  port_id_r;
```

`mmu/rtl/mmu_l1dtlb_mb_entry.sv:87` (声明 `pgs_r`)

```systemverilog
        84:     logic [PPN_WIDTH-1:0]   ppn_r;
        85:     logic [FLG_WIDTH-1:0]   flg_r;
        86:     logic [IID_WIDTH-1:0]   iid_r;
        87: >>  logic [2:0]		pgs_r;
        88:     //logic [PORT_WIDTH-1:0]  port_id_r;
        89:     logic                   store_r;    // New: Register to hold store attribute
        90:     logic                   issued_r;
```

## 模块 `mmu_l1dtlb_expt_cam`

源码：`mmu/rtl/mmu_l1dtlb_expt_cam.sv`
原始未覆盖记录数：`78`；合并后唯一代码对象数：`31`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 95 | `EXPRESSION (lsu_mmu_va1_vld && hit1_any && ((!lsu_mmu_abort1)))` | 1 1 0 Not Covered | 1 |
| 96 | `EXPRESSION (hit0_any && hit1_any && (hit0_idx == hit1_idx))` | 1 1 1 Not Covered | 1 |
| 98 | `EXPRESSION (consume1 && ((!same_hit_entry)))` | 1 0 Not Covered | 1 |
| 130 | `EXPRESSION (expt_wr0_vld && expt_wr1_vld && (expt_wr0_eid == expt_wr1_eid))` | 1 1 1 Not Covered | 1 |
| 155 | `EXPRESSION (expt_wr1_vld && ((!same_wr_eid)))` | 1 0 Not Covered | 1 |

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:95`

```systemverilog
        92:       assign hit1_idx = first_one_idx(hit1_use_vec);
        93:     
        94:       assign consume0 = lsu_mmu_va0_vld && hit0_any && !lsu_mmu_abort0;
        95: >>    assign consume1 = lsu_mmu_va1_vld && hit1_any && !lsu_mmu_abort1;
        96:       assign same_hit_entry = hit0_any && hit1_any && (hit0_idx == hit1_idx);
        97:       assign consume0_eff = consume0;
        98:       assign consume1_eff = consume1 && !same_hit_entry;
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:96`

```systemverilog
        93:     
        94:       assign consume0 = lsu_mmu_va0_vld && hit0_any && !lsu_mmu_abort0;
        95:       assign consume1 = lsu_mmu_va1_vld && hit1_any && !lsu_mmu_abort1;
        96: >>    assign same_hit_entry = hit0_any && hit1_any && (hit0_idx == hit1_idx);
        97:       assign consume0_eff = consume0;
        98:       assign consume1_eff = consume1 && !same_hit_entry;
        99:     
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:98`

```systemverilog
        95:       assign consume1 = lsu_mmu_va1_vld && hit1_any && !lsu_mmu_abort1;
        96:       assign same_hit_entry = hit0_any && hit1_any && (hit0_idx == hit1_idx);
        97:       assign consume0_eff = consume0;
        98: >>    assign consume1_eff = consume1 && !same_hit_entry;
        99:     
       100:       always_comb begin
       101:         expt_hit_vec = '0;
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:130`

```systemverilog
       127:       //  expt_wakeup = {12{expt_wr0_vld | expt_wr1_vld}};//{12{consume0_eff || consume1_eff}};
       128:       //end
       129:     
       130: >>    assign same_wr_eid = expt_wr0_vld && expt_wr1_vld
       131:                         && (expt_wr0_eid == expt_wr1_eid);
       132:     
       133:       int k;
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:155`

```systemverilog
       152:           if (consume1_eff)
       153:             ent[hit1_idx].vld <= 1'b0;
       154:     
       155: >>        if (expt_wr1_vld && !same_wr_eid) begin
       156:             ent[expt_wr1_eid].vld   <= 1'b1;
       157:             ent[expt_wr1_eid].iid   <= expt_wr1_iid;
       158:             ent[expt_wr1_eid].vpn   <= expt_wr1_vpn;
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 7 | `rst_b -> input  logic                 rst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 24 | `expt_wr1_acflt -> input  logic                 expt_wr1_acflt,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 41 | `expt_hit_vec[7:3] -> output logic [CAM_DEPTH-1:0] expt_hit_vec` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:7` (声明 `rst_b`)

```systemverilog
         4:       parameter int VPN_WIDTH = 27
         5:     ) (
         6:       input  logic                 clk,
         7: >>    input  logic                 rst_b,
         8:       input  logic                 rtu_yy_xx_flush,
         9:       input  logic                 tlboper_utlb_clr,
        10:       input  logic                 tlboper_utlb_inv_va_req,
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:24` (声明 `expt_wr1_acflt`)

```systemverilog
        21:       input  logic [IID_WIDTH-1:0] expt_wr1_iid,
        22:       input  logic [VPN_WIDTH-1:0] expt_wr1_vpn,
        23:       input  logic                 expt_wr1_pgflt,
        24: >>    input  logic                 expt_wr1_acflt,
        25:     
        26:       input  logic                 lsu_mmu_va0_vld,
        27:       input  logic                 lsu_mmu_abort0,
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:41` (声明 `expt_hit_vec`)

```systemverilog
        38:       output logic                 expt_match1,
        39:       output logic                 expt_pgflt1,
        40:       output logic                 expt_acflt1,
        41: >>    output logic [CAM_DEPTH-1:0] expt_hit_vec
        42:       //output logic [11:0]          expt_wakeup
        43:     );
        44:     
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| - | `ent[1].vpn[26:25]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `ent[2].acflt` | Toggle=No, 1->0=No, 0->1=No | 6 |
| - | `ent[2].vpn[2:0]` | Toggle=No, 1->0=No, 0->1=No | 3 |
| - | `ent[2].vpn[10:8]` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `ent[2].vpn[15:11]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `ent[2].vpn[17:16]` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `ent[2].vpn[18]` | Toggle=No, 1->0=No, 0->1=No | 22 |
| - | `ent[2].vpn[26:20]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `ent[2].iid[1:0]` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| - | `ent[3].pgflt` | Toggle=No, 1->0=No, 0->1=Yes | 5 |
| - | `ent[3].vpn[26:11]` | Toggle=No, 1->0=No, 0->1=No | 5 |
| - | `ent[3].iid[2:0]` | Toggle=No, 1->0=No, 0->1=No | 2 |
| - | `ent[4].vpn[2:1]` | Toggle=No, 1->0=No, 0->1=No | 2 |
| - | `ent[5].iid[0]` | Toggle=No, 1->0=No, 0->1=No | 7 |
| - | `ent[5].iid[2:1]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 70 | `hit0_vec[3] -> logic [CAM_DEPTH-1:0] hit0_vec, hit1_vec;` | Toggle=No, 1->0=No, 0->1=No | 3 |
| 70 | `hit1_vec[3] -> logic [CAM_DEPTH-1:0] hit0_vec, hit1_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 70 | `hit1_vec[6:5] -> logic [CAM_DEPTH-1:0] hit0_vec, hit1_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 71 | `hit0_use_vec[5:3] -> logic [CAM_DEPTH-1:0] hit0_use_vec, hit1_use_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 71 | `hit0_use_vec[7] -> logic [CAM_DEPTH-1:0] hit0_use_vec, hit1_use_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 71 | `hit1_use_vec[6:3] -> logic [CAM_DEPTH-1:0] hit0_use_vec, hit1_use_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 75 | `same_hit_entry -> logic consume0, consume1, same_hit_entry;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 77 | `same_wr_eid -> logic same_wr_eid;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:70` (声明 `hit0_vec`)

```systemverilog
        67:         end
        68:       endfunction
        69:     
        70: >>    logic [CAM_DEPTH-1:0] hit0_vec, hit1_vec;
        71:       logic [CAM_DEPTH-1:0] hit0_use_vec, hit1_use_vec;
        72:     
        73:       logic hit0_any, hit1_any;
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:71` (声明 `hit0_use_vec`)

```systemverilog
        68:       endfunction
        69:     
        70:       logic [CAM_DEPTH-1:0] hit0_vec, hit1_vec;
        71: >>    logic [CAM_DEPTH-1:0] hit0_use_vec, hit1_use_vec;
        72:     
        73:       logic hit0_any, hit1_any;
        74:       logic [$clog2(CAM_DEPTH)-1:0] hit0_idx, hit1_idx;
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:75` (声明 `same_hit_entry`)

```systemverilog
        72:     
        73:       logic hit0_any, hit1_any;
        74:       logic [$clog2(CAM_DEPTH)-1:0] hit0_idx, hit1_idx;
        75: >>    logic consume0, consume1, same_hit_entry;
        76:       logic consume0_eff, consume1_eff;
        77:       logic same_wr_eid;
        78:     
```

`mmu/rtl/mmu_l1dtlb_expt_cam.sv:77` (声明 `same_wr_eid`)

```systemverilog
        74:       logic [$clog2(CAM_DEPTH)-1:0] hit0_idx, hit1_idx;
        75:       logic consume0, consume1, same_hit_entry;
        76:       logic consume0_eff, consume1_eff;
        77: >>    logic same_wr_eid;
        78:     
        79:       int j;
        80:       always_comb begin
```

## 模块 `mmu_l1dtlb_hit_rd`

源码：`mmu/rtl/mmu_l1dtlb_hit_rd.sv`
原始未覆盖记录数：`225`；合并后唯一代码对象数：`165`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 146 | `EXPRESSION (dutlb_hit_vld | dutlb_disable_vld | dutlb_va_illegal | dutlb_expt_match)` | 0 0 1 0 Not Covered | 1 |
| 165 | `EXPRESSION (((lsu_mmu_va_x[(VPN_WIDTH + 11)] && ((!(&lsu_mmu_va_x[63:(VPN_WIDTH + 12)])))) || (((!lsu_mmu_va_x[(VPN_WIDTH + 11)])) && ((|lsu_mmu_va_x[63:(VPN_WIDTH + 12)])...` | 1 0 1 Not Covered; 1 1 0 Not Covered; 1 1 1 Not Covered | 3 |
| 165 | `SUB-EXPRESSION ((lsu_mmu_va_x[(VPN_WIDTH + 11)] && ((!(&lsu_mmu_va_x[63:(VPN_WIDTH + 12)])))) || (((!lsu_mmu_va_x[(VPN_WIDTH + 11)])) && ((|lsu_mmu_va_x[63:(VPN_WIDTH + 12)]))...` | 0 1 Not Covered; 1 0 Not Covered | 2 |
| 165 | `SUB-EXPRESSION (lsu_mmu_va_x[(VPN_WIDTH + 11)] && ((!(&lsu_mmu_va_x[63:(VPN_WIDTH + 12)]))))` | 1 1 Not Covered | 1 |
| 165 | `SUB-EXPRESSION (((!lsu_mmu_va_x[(VPN_WIDTH + 11)])) && ((|lsu_mmu_va_x[63:(VPN_WIDTH + 12)])))` | 1 1 Not Covered | 1 |
| 170 | `EXPRESSION (((((!dutlb_fin_flg[0])) || (((!dutlb_fin_flg[1])) && dutlb_fin_flg[2]) || (((!dutlb_fin_flg[1])) && dutlb_read_type_x && ( ! (cp0_mmu_mxr && dutlb_fin_flg[3]) ...` | 0 0 1 Not Covered | 1 |
| 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[0])) || (((!dutlb_fin_flg[1])) && dutlb_fin_flg[2]) || (((!dutlb_fin_flg[1])) && dutlb_read_type_x && ( ! (cp0_mmu_mxr && dutlb_fin_flg[3]) ))...` | 0 0 0 0 0 0 0 1 Not Covered; 0 0 0 0 0 0 1 0 Not Covered; 0 0 0 1 0 0 0 0 Not Covered; ... 共 5 种 | 5 |
| 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[1])) && dutlb_read_type_x && ( ! (cp0_mmu_mxr && dutlb_fin_flg[3]) ))` | 1 0 1 Not Covered; 1 1 1 Not Covered | 2 |
| 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[2])) && ((!dutlb_read_type_x)))` | 1 1 Not Covered; 1 0 Not Covered | 3 |
| 170 | `SUB-EXPRESSION (dutlb_fin_flg[4] && cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered | 1 |
| 170 | `SUB-EXPRESSION (((!dutlb_fin_flg[4])) && cp0_user_mode)` | 0 1 Not Covered | 1 |
| 170 | `SUB-EXPRESSION (expt_match_x && expt_pgflt_x)` | 0 1 Not Covered | 1 |
| 183 | `EXPRESSION (dutlb_page_fault && ((!dutlb_off_hit)))` | 1 0 Not Covered | 1 |
| 185 | `EXPRESSION ((expt_match_x && expt_acflt_x) || jtlb_acc_fault_flop || (((!pmp_mmu_flg_x[0])) && (pmp_read_type || dutlb_ori_read_x) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg_...` | 0 1 0 0 Not Covered | 1 |
| 185 | `SUB-EXPRESSION (expt_match_x && expt_acflt_x)` | 0 1 Not Covered | 1 |
| 185 | `SUB-EXPRESSION (((!pmp_mmu_flg_x[0])) && (pmp_read_type || dutlb_ori_read_x) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg_x[3]))) ) && pmp_flg_vld)` | 1 1 0 1 Not Covered | 1 |
| 185 | `SUB-EXPRESSION (((!pmp_mmu_flg_x[1])) && ((!pmp_read_type)) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg_x[3]))) ) && pmp_flg_vld)` | 1 1 0 1 Not Covered | 1 |
| 194 | `EXPRESSION ((expt_match_x && expt_acflt_x) || jtlb_acc_fault_flop)` | 0 1 Not Covered | 1 |
| 194 | `SUB-EXPRESSION (expt_match_x && expt_acflt_x)` | 0 1 Not Covered | 1 |
| 209 | `EXPRESSION (lsu_mmu_va_vld_x & ((!dutlb_entry_hit_vld)) & ((!dutlb_va_illegal)) & ((!lsu_mmu_abort_x)) & ((!dutlb_off_hit)) & ((!dutlb_expt_match)))` | 1 1 0 1 1 1 Not Covered | 1 |
| 216 | `EXPRESSION (lsu_mmu_va_vld_x & ((!dutlb_entry_hit_vld)) & ((!dutlb_va_illegal)) & ((!dutlb_off_hit)) & ((!dutlb_expt_match)))` | 1 1 0 1 1 Not Covered | 1 |
| 261 | `EXPRESSION (dutlb_off_hit | ((!lsu_mmu_va_vld_x)) | dutlb_va_illegal | dutlb_expt_match | dutlb_stamo_pre_sel)` | 0 0 1 0 0 Not Covered | 1 |
| 267 | `EXPRESSION (lsu_mmu_stamo_vld_x & ((!dutlb_expt_match)))` | 1 0 Not Covered | 1 |
| 301 | `EXPRESSION (lsu_va_chg || lsu_mmu_va_vld_x || (pmp_flg_vld ^ lsu_mmu_va_vld_x))` | 0 1 0 Not Covered; 1 0 0 Not Covered | 2 |

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:146`

```systemverilog
       143:     assign dutlb_hit_vld = lsu_mmu_va_vld_x && dutlb_addr_hit;
       144:     assign dutlb_disable_vld = lsu_mmu_va_vld_x && dutlb_off_hit;
       145:     
       146: >>  assign mmu_lsu_pa_vld_x = dutlb_hit_vld
       147:                             | dutlb_disable_vld
       148:     			| dutlb_va_illegal
       149:                             | dutlb_expt_match;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:165`

```systemverilog
       162:     //----------------------------------------------------------
       163:     //                  Exception Checking
       164:     //----------------------------------------------------------
       165: >>  assign dutlb_va_illegal = ( lsu_mmu_va_x[VPN_WIDTH+11] && !(&lsu_mmu_va_x[63:VPN_WIDTH+12])
       166:                              || !lsu_mmu_va_x[VPN_WIDTH+11] &&  (|lsu_mmu_va_x[63:VPN_WIDTH+12])
       167:                               )
       168:                               && !dutlb_off_hit && lsu_mmu_va_vld_x;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:170`

```systemverilog
       167:                               )
       168:                               && !dutlb_off_hit && lsu_mmu_va_vld_x;
       169:     
       170: >>  assign dutlb_page_fault = ( !dutlb_fin_flg[0]
       171:                              || !dutlb_fin_flg[1] && dutlb_fin_flg[2]
       172:                              || !dutlb_fin_flg[1] && dutlb_read_type_x && !(cp0_mmu_mxr && dutlb_fin_flg[3])
       173:                              || !dutlb_fin_flg[2] && !dutlb_read_type_x
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:183`

```systemverilog
       180:                               || expt_match_x && expt_pgflt_x
       181:                               || dutlb_va_illegal;
       182:     
       183: >>  assign mmu_lsu_page_fault_x = dutlb_page_fault && !dutlb_off_hit;
       184:     
       185:     assign mmu_lsu_access_fault_x = (expt_match_x && expt_acflt_x)
       186:                                 || jtlb_acc_fault_flop
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:185`

```systemverilog
       182:     
       183:     assign mmu_lsu_page_fault_x = dutlb_page_fault && !dutlb_off_hit;
       184:     
       185: >>  assign mmu_lsu_access_fault_x = (expt_match_x && expt_acflt_x)
       186:                                 || jtlb_acc_fault_flop
       187:                                 || !pmp_mmu_flg_x[0] && (pmp_read_type || dutlb_ori_read_x)
       188:                                    && !(cp0_mach_mode && !pmp_mmu_flg_x[3])
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:194`

```systemverilog
       191:                                    && !(cp0_mach_mode && !pmp_mmu_flg_x[3])
       192:                                    && pmp_flg_vld;
       193:     
       194: >>  assign dutlb_acc_flt_x = (expt_match_x && expt_acflt_x) || jtlb_acc_fault_flop;
       195:     
       196:     // PLRU Update
       197:     always @(posedge dplru_clk or negedge cpurst_b) begin
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:209`

```systemverilog
       206:     // L1TLB Miss Determination
       207:     // An exception CAM replay consumes an existing miss-buffer fault entry.  It is
       208:     // not a new DTLB miss and must not allocate another miss-buffer entry.
       209: >>  assign dutlb_miss_vld_x = lsu_mmu_va_vld_x
       210:                             & !dutlb_entry_hit_vld
       211:                             & !dutlb_va_illegal
       212:                             & !lsu_mmu_abort_x
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:216`

```systemverilog
       213:                             & !dutlb_off_hit
       214:                             & !dutlb_expt_match;
       215:     
       216: >>  assign dutlb_miss_vld_short_x = lsu_mmu_va_vld_x
       217:                                   & !dutlb_entry_hit_vld
       218:                                   & !dutlb_va_illegal
       219:                                   & !dutlb_off_hit
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:261`

```systemverilog
       258:     
       259:     // Pre-select logic: MMU is off OR VA not valid OR STAMO
       260:     // Removed specific checks for Entry 16 or Huge pages.
       261: >>  assign dutlb_pre_sel = dutlb_off_hit
       262:                          | !lsu_mmu_va_vld_x
       263:                          | dutlb_va_illegal
       264:                          | dutlb_expt_match
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:267`

```systemverilog
       264:                          | dutlb_expt_match
       265:                          | dutlb_stamo_pre_sel;
       266:     
       267: >>  assign dutlb_stamo_pre_sel = lsu_mmu_stamo_vld_x & !dutlb_expt_match;
       268:     
       269:     assign dutlb_pre_pa[PPN_WIDTH-1:0] = dutlb_stamo_pre_sel ? lsu_mmu_stamo_pa_x[PPN_WIDTH-1:0]
       270:                                                              : dutlb_off_pa[PPN_WIDTH-1:0];
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:301`

```systemverilog
       298:     //                  PMP & Buffer Clock
       299:     //----------------------------------------------------------
       300:     assign lsu_va_chg = lsu_mmu_va_vld_x;
       301: >>  assign pabuf_clk_en = lsu_va_chg
       302:                       || lsu_mmu_va_vld_x
       303:                       || pmp_flg_vld ^ lsu_mmu_va_vld_x;
       304:     
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 14 | `cpurst_b -> input  logic         cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[0] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 16 |
| 30 | `entry_flg_vec[6:4] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[16:14] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[20:19] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[22:21] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[30:28] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[34:33] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[36:35] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[38:37] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[45:42] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[48:47] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[50:49] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[52:51] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[59:56] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[62:61] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[64:63] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[66:65] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[73:70] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[76:75] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[78:77] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[80:79] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[87:84] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[90:89] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[92:91] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[94:93] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[101:98] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[104:103] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[106:105] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[108:107] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[115:112] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[118:117] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[120:119] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[122:121] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[129:126] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[132:131] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[134:133] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[136:135] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[143:140] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[146:145] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[148:147] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[150:149] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[157:154] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[160:159] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[162:161] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[164:163] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[171:168] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[174:173] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[176:175] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[178:177] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[185:182] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[188:187] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[190:189] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[192:191] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[199:196] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[202:201] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[204:203] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[206:205] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[213:210] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[216:215] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 30 | `entry_flg_vec[218:217] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `entry_flg_vec[220:219] -> input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[15] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 34 |
| 32 | `entry_ppn_vec[23:21] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[27:24] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[48:47] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[51:49] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[55:52] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[76:75] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[79:77] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[83:80] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[95:94] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[104:102] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[107:105] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[111:108] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[132:130] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[135:133] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[139:136] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[160:158] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[163:161] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[167:164] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[179:178] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[188:186] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[191:189] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[195:192] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[207:206] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[216:214] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[219:217] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[223:220] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[235:234] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[244:243] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[247:245] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[251:248] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[263:262] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[272:270] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[275:273] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[279:276] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[291:290] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[300:298] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[303:301] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[307:304] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[319:318] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[328:326] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[331:329] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[335:332] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[347:346] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[356:354] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[359:357] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[363:360] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[375:374] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[384:382] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[387:385] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[391:388] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[403:402] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[412:410] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[415:413] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[419:416] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[431:430] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[440:438] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `entry_ppn_vec[443:441] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `entry_ppn_vec[447:444] -> input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 35 | `pad_yy_icg_scan_en -> input  logic         pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 39 | `biu_mmu_smp_disable -> input  logic         biu_mmu_smp_disable,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 74 | `mmu_lsu_stall_x -> output logic         mmu_lsu_stall_x,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 82 | `sysmap_mmu_flg_x[0] -> input  logic [4 :0]  sysmap_mmu_flg_x,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:14` (声明 `cpurst_b`)

```systemverilog
        11:         parameter NUM_ENTRY = 16  // Configurable Entry Count
        12:     )(
        13:         //! Clock and Reset
        14: >>      input  logic         cpurst_b,
        15:         input  logic         forever_cpuclk,
        16:         input  logic         dplru_clk,
        17:         input  logic         dutlb_clk,
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:30` (声明 `entry_flg_vec`)

```systemverilog
        27:         //! Parameterized L1DTLB Entry Interface
        28:         // Flattened arrays for easier port connection
        29:         input  logic [NUM_ENTRY-1:0]                entry_vld_vec,
        30: >>      input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec, 
        31:         input  logic [NUM_ENTRY-1:0]                entry_hit_vec,
        32:         input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,
        33:     
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:32` (声明 `entry_ppn_vec`)

```systemverilog
        29:         input  logic [NUM_ENTRY-1:0]                entry_vld_vec,
        30:         input  logic [NUM_ENTRY*FLG_WIDTH-1:0]      entry_flg_vec, 
        31:         input  logic [NUM_ENTRY-1:0]                entry_hit_vec,
        32: >>      input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,
        33:     
        34:         // Miscellaneous
        35:         input  logic         pad_yy_icg_scan_en,
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:35` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        32:         input  logic [NUM_ENTRY*PPN_WIDTH-1:0]      entry_ppn_vec,
        33:     
        34:         // Miscellaneous
        35: >>      input  logic         pad_yy_icg_scan_en,
        36:         //input  logic [6 :0]  refill_id_flop,
        37:     
        38:         // DUTLB Control
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:39` (声明 `biu_mmu_smp_disable`)

```systemverilog
        36:         //input  logic [6 :0]  refill_id_flop,
        37:     
        38:         // DUTLB Control
        39: >>      input  logic         biu_mmu_smp_disable,
        40:         input  logic         dutlb_expt_for_taken,
        41:         input  logic         expt_match_x,
        42:         input  logic         expt_pgflt_x,
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:74` (声明 `mmu_lsu_stall_x`)

```systemverilog
        71:         output logic         mmu_lsu_ca_x,
        72:         output logic         mmu_lsu_sh_x,
        73:         output logic         mmu_lsu_so_x,
        74: >>      output logic         mmu_lsu_stall_x,
        75:         output logic         mmu_lsu_sec_x,
        76:         output logic         mmu_lsu_access_fault_x,
        77:         output logic         mmu_lsu_page_fault_x,
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:82` (声明 `sysmap_mmu_flg_x`)

```systemverilog
        79:         // PMP & SysMap & UTLB Req
        80:         input  logic [3 :0]  pmp_mmu_flg_x,
        81:         output logic [27:0]  mmu_pmp_pa_x,
        82: >>      input  logic [4 :0]  sysmap_mmu_flg_x,
        83:         output logic [27:0]  mmu_sysmap_pa_x,
        84:         output logic [26:0]  utlb_req_vpn_x
        85:     );
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 90 | `dutlb_entry_flg[0] -> logic [13:0]  dutlb_entry_flg;` | Toggle=No, 1->0=No, 0->1=No | 2 |
| 90 | `dutlb_entry_flg[6:5] -> logic [13:0]  dutlb_entry_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 91 | `dutlb_entry_pa[23:21] -> logic [27:0]  dutlb_entry_pa;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 92 | `dutlb_pa_buf[27] -> logic [27:0]  dutlb_pa_buf;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 93 | `jtlb_acc_fault_flop -> logic         jtlb_acc_fault_flop;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 102 | `dutlb_fin_flg[0] -> logic [13:0]  dutlb_fin_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 102 | `dutlb_fin_flg[6:5] -> logic [13:0]  dutlb_fin_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 104 | `dutlb_fin_pgs[2:1] -> logic [2 :0]  dutlb_fin_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 106 | `dutlb_inst_id_hit -> logic         dutlb_inst_id_hit;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 107 | `dutlb_off_flg[9:0] -> logic [13:0]  dutlb_off_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 109 | `dutlb_off_pgs[2:0] -> logic [2 :0]  dutlb_off_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 112 | `dutlb_pre_flg[9:0] -> logic [13:0]  dutlb_pre_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 114 | `dutlb_pre_pgs[2:0] -> logic [2 :0]  dutlb_pre_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 117 | `dutlb_req_id_older -> logic         dutlb_req_id_older;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 118 | `dutlb_va_illegal -> logic         dutlb_va_illegal;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 120 | `mmu_lsu_page_size_x[2:1] -> logic [2 :0]  mmu_lsu_page_size_x;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:90` (声明 `dutlb_entry_flg`)

```systemverilog
        87:     parameter VPN_PERLEL = 9;
        88:     
        89:     // Internal Signals
        90: >>  logic [13:0]  dutlb_entry_flg;
        91:     logic [27:0]  dutlb_entry_pa;
        92:     logic [27:0]  dutlb_pa_buf;
        93:     logic         jtlb_acc_fault_flop;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:91` (声明 `dutlb_entry_pa`)

```systemverilog
        88:     
        89:     // Internal Signals
        90:     logic [13:0]  dutlb_entry_flg;
        91: >>  logic [27:0]  dutlb_entry_pa;
        92:     logic [27:0]  dutlb_pa_buf;
        93:     logic         jtlb_acc_fault_flop;
        94:     logic         pmp_flg_vld;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:92` (声明 `dutlb_pa_buf`)

```systemverilog
        89:     // Internal Signals
        90:     logic [13:0]  dutlb_entry_flg;
        91:     logic [27:0]  dutlb_entry_pa;
        92: >>  logic [27:0]  dutlb_pa_buf;
        93:     logic         jtlb_acc_fault_flop;
        94:     logic         pmp_flg_vld;
        95:     logic         pmp_read_type;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:93` (声明 `jtlb_acc_fault_flop`)

```systemverilog
        90:     logic [13:0]  dutlb_entry_flg;
        91:     logic [27:0]  dutlb_entry_pa;
        92:     logic [27:0]  dutlb_pa_buf;
        93: >>  logic         jtlb_acc_fault_flop;
        94:     logic         pmp_flg_vld;
        95:     logic         pmp_read_type;
        96:     
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:102` (声明 `dutlb_fin_flg`)

```systemverilog
        99:     logic [NUM_ENTRY-1:0] dutlb_entry_hit;
       100:     logic         dutlb_entry_hit_vld;
       101:     logic         dutlb_expt_match;
       102: >>  logic [13:0]  dutlb_fin_flg;
       103:     logic [27:0]  dutlb_fin_pa;
       104:     logic [2 :0]  dutlb_fin_pgs;
       105:     logic         dutlb_hit_vld;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:104` (声明 `dutlb_fin_pgs`)

```systemverilog
       101:     logic         dutlb_expt_match;
       102:     logic [13:0]  dutlb_fin_flg;
       103:     logic [27:0]  dutlb_fin_pa;
       104: >>  logic [2 :0]  dutlb_fin_pgs;
       105:     logic         dutlb_hit_vld;
       106:     logic         dutlb_inst_id_hit;
       107:     logic [13:0]  dutlb_off_flg;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:106` (声明 `dutlb_inst_id_hit`)

```systemverilog
       103:     logic [27:0]  dutlb_fin_pa;
       104:     logic [2 :0]  dutlb_fin_pgs;
       105:     logic         dutlb_hit_vld;
       106: >>  logic         dutlb_inst_id_hit;
       107:     logic [13:0]  dutlb_off_flg;
       108:     logic [27:0]  dutlb_off_pa;
       109:     logic [2 :0]  dutlb_off_pgs;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:107` (声明 `dutlb_off_flg`)

```systemverilog
       104:     logic [2 :0]  dutlb_fin_pgs;
       105:     logic         dutlb_hit_vld;
       106:     logic         dutlb_inst_id_hit;
       107: >>  logic [13:0]  dutlb_off_flg;
       108:     logic [27:0]  dutlb_off_pa;
       109:     logic [2 :0]  dutlb_off_pgs;
       110:     logic         dutlb_page_fault;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:109` (声明 `dutlb_off_pgs`)

```systemverilog
       106:     logic         dutlb_inst_id_hit;
       107:     logic [13:0]  dutlb_off_flg;
       108:     logic [27:0]  dutlb_off_pa;
       109: >>  logic [2 :0]  dutlb_off_pgs;
       110:     logic         dutlb_page_fault;
       111:     logic         dutlb_pmp_chk_vld;
       112:     logic [13:0]  dutlb_pre_flg;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:112` (声明 `dutlb_pre_flg`)

```systemverilog
       109:     logic [2 :0]  dutlb_off_pgs;
       110:     logic         dutlb_page_fault;
       111:     logic         dutlb_pmp_chk_vld;
       112: >>  logic [13:0]  dutlb_pre_flg;
       113:     logic [27:0]  dutlb_pre_pa;
       114:     logic [2 :0]  dutlb_pre_pgs;
       115:     logic         dutlb_pre_sel;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:114` (声明 `dutlb_pre_pgs`)

```systemverilog
       111:     logic         dutlb_pmp_chk_vld;
       112:     logic [13:0]  dutlb_pre_flg;
       113:     logic [27:0]  dutlb_pre_pa;
       114: >>  logic [2 :0]  dutlb_pre_pgs;
       115:     logic         dutlb_pre_sel;
       116:     logic         dutlb_stamo_pre_sel;
       117:     logic         dutlb_req_id_older;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:117` (声明 `dutlb_req_id_older`)

```systemverilog
       114:     logic [2 :0]  dutlb_pre_pgs;
       115:     logic         dutlb_pre_sel;
       116:     logic         dutlb_stamo_pre_sel;
       117: >>  logic         dutlb_req_id_older;
       118:     logic         dutlb_va_illegal;
       119:     logic         lsu_va_chg;
       120:     logic [2 :0]  mmu_lsu_page_size_x;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:118` (声明 `dutlb_va_illegal`)

```systemverilog
       115:     logic         dutlb_pre_sel;
       116:     logic         dutlb_stamo_pre_sel;
       117:     logic         dutlb_req_id_older;
       118: >>  logic         dutlb_va_illegal;
       119:     logic         lsu_va_chg;
       120:     logic [2 :0]  mmu_lsu_page_size_x;
       121:     logic         pabuf_clk;
```

`mmu/rtl/mmu_l1dtlb_hit_rd.sv:120` (声明 `mmu_lsu_page_size_x`)

```systemverilog
       117:     logic         dutlb_req_id_older;
       118:     logic         dutlb_va_illegal;
       119:     logic         lsu_va_chg;
       120: >>  logic [2 :0]  mmu_lsu_page_size_x;
       121:     logic         pabuf_clk;
       122:     logic         pabuf_clk_en;
       123:     logic [NUM_ENTRY-1:0] vpn_hit;
```

## 模块 `mmu_l1dtlb_install`

源码：`mmu/rtl/mmu_l1dtlb_install.sv`
原始未覆盖记录数：`47`；合并后唯一代码对象数：`31`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 100 | `EXPRESSION (ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt && mb_entry_vld[id_ptw] && ((!req_ptw_expt)) && ((!req_ptw_aborted)))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered | 2 |
| 103 | `EXPRESSION (jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt && mb_entry_vld[id_jtlb] && ((!req_jtlb_expt)) && ((!req_jtlb_aborted)))` | 1 1 0 1 1 Not Covered; 1 1 1 0 1 Not Covered; 1 1 1 1 0 Not Covered | 3 |
| 134 | `EXPRESSION (req_ptw_vld && ((!req_wfi_vld)))` | 1 0 Not Covered | 1 |
| 135 | `EXPRESSION (req_jtlb_vld && ((!req_wfi_vld)) && ((!req_ptw_vld)))` | 1 0 1 Not Covered | 1 |

`mmu/rtl/mmu_l1dtlb_install.sv:100`

```systemverilog
        97:     assign req_jtlb_aborted = (mb_entry_state[id_jtlb] == STATE_ABT);
        98:     
        99:     // Validity Check: Complete + Valid MB + Not Exception + Not Aborted
       100: >>  assign req_ptw_vld = ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt && 
       101:                          mb_entry_vld[id_ptw] && !req_ptw_expt && !req_ptw_aborted;
       102:     
       103:     assign req_jtlb_vld = jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt && 
```

`mmu/rtl/mmu_l1dtlb_install.sv:103`

```systemverilog
       100:     assign req_ptw_vld = ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt && 
       101:                          mb_entry_vld[id_ptw] && !req_ptw_expt && !req_ptw_aborted;
       102:     
       103: >>  assign req_jtlb_vld = jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt && 
       104:                           mb_entry_vld[id_jtlb] && !req_jtlb_expt && !req_jtlb_aborted;
       105:     
       106:     //!************************************************
```

`mmu/rtl/mmu_l1dtlb_install.sv:134`

```systemverilog
       131:     
       132:     // Strict Priority Logic
       133:     assign sel_wfi  = req_wfi_vld;
       134: >>  assign sel_ptw  = req_ptw_vld  && !req_wfi_vld;
       135:     assign sel_jtlb = req_jtlb_vld && !req_wfi_vld && !req_ptw_vld;
       136:     
       137:     assign utlb_refill_vld = sel_ptw || sel_jtlb || sel_wfi;
```

`mmu/rtl/mmu_l1dtlb_install.sv:135`

```systemverilog
       132:     // Strict Priority Logic
       133:     assign sel_wfi  = req_wfi_vld;
       134:     assign sel_ptw  = req_ptw_vld  && !req_wfi_vld;
       135: >>  assign sel_jtlb = req_jtlb_vld && !req_wfi_vld && !req_ptw_vld;
       136:     
       137:     assign utlb_refill_vld = sel_ptw || sel_jtlb || sel_wfi;
       138:     
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 16 | `cpurst_b -> input  logic                     cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `mb_entry_vpn[2][11] -> input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 13 |
| 22 | `mb_entry_vpn[2][20:19] -> input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `mb_entry_vpn[5][1:0] -> input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 23 | `mb_entry_iid[3][1:0] -> input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 23 | `mb_entry_iid[5][0] -> input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 2 |
| - | `Other bits of mb_entry_iid[7:0][6:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 24 | `mb_entry_pgs[2][0] -> input  logic [MB_DEPTH-1:0][2:0]	       mb_entry_pgs,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_pgs[7:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 28 | `mb_entry_ppn[0][19] -> input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 28 | `mb_entry_ppn[2][6:0] -> input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 28 | `mb_entry_ppn[2][18:9] -> input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_ppn[7:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 29 | `mb_entry_flg[2][3:0] -> input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 29 | `mb_entry_flg[2][6:5] -> input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 29 | `mb_entry_flg[2][13:9] -> input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_flg[7:0][13:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `mb_entry_wfi[7:3] -> input  logic [MB_DEPTH-1:0]                mb_entry_wfi,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 40 | `jtlb_utlb_ref_ppn[20] -> input  logic [PPN_WIDTH-1:0]     jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 40 | `jtlb_utlb_ref_ppn[23:21] -> input  logic [PPN_WIDTH-1:0]     jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 40 | `jtlb_utlb_ref_ppn[27:24] -> input  logic [PPN_WIDTH-1:0]     jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 50 | `ptw_l1tlb_ref_vpn[26] -> input  logic [26:0]              ptw_l1tlb_ref_vpn, // 27 bits matches VPN_WIDTH` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 51 | `ptw_l1tlb_ref_ppn[23:21] -> input  logic [27:0]              ptw_l1tlb_ref_ppn, // 28 bits matches PPN_WIDTH` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 60 | `utlb_refill_vpn[26] -> output logic [VPN_WIDTH-1:0]     utlb_refill_vpn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 61 | `utlb_refill_ppn[23:21] -> output logic [PPN_WIDTH-1:0]     utlb_refill_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |

`mmu/rtl/mmu_l1dtlb_install.sv:16` (声明 `cpurst_b`)

```systemverilog
        13:         parameter IID_WIDTH  = 7
        14:     )(
        15:         // Clock and Reset
        16: >>      input  logic                     cpurst_b,
        17:         input  logic                     install_clk,
        18:         
        19:         // Miss Buffer Entry Status
```

`mmu/rtl/mmu_l1dtlb_install.sv:22` (声明 `mb_entry_vpn`)

```systemverilog
        19:         // Miss Buffer Entry Status
        20:         input  logic [MB_DEPTH-1:0]                mb_entry_vld,
        21:         input  logic [MB_DEPTH-1:0][2:0]           mb_entry_state,
        22: >>      input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
        23:         input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
        24:         input  logic [MB_DEPTH-1:0][2:0]	       mb_entry_pgs,
        25:         //input  logic [MB_DEPTH-1:0]                mb_entry_port_id,
```

`mmu/rtl/mmu_l1dtlb_install.sv:23` (声明 `mb_entry_iid`)

```systemverilog
        20:         input  logic [MB_DEPTH-1:0]                mb_entry_vld,
        21:         input  logic [MB_DEPTH-1:0][2:0]           mb_entry_state,
        22:         input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
        23: >>      input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
        24:         input  logic [MB_DEPTH-1:0][2:0]	       mb_entry_pgs,
        25:         //input  logic [MB_DEPTH-1:0]                mb_entry_port_id,
        26:         
```

`mmu/rtl/mmu_l1dtlb_install.sv:24` (声明 `mb_entry_pgs`)

```systemverilog
        21:         input  logic [MB_DEPTH-1:0][2:0]           mb_entry_state,
        22:         input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
        23:         input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
        24: >>      input  logic [MB_DEPTH-1:0][2:0]	       mb_entry_pgs,
        25:         //input  logic [MB_DEPTH-1:0]                mb_entry_port_id,
        26:         
        27:         // WFI Data
```

`mmu/rtl/mmu_l1dtlb_install.sv:28` (声明 `mb_entry_ppn`)

```systemverilog
        25:         //input  logic [MB_DEPTH-1:0]                mb_entry_port_id,
        26:         
        27:         // WFI Data
        28: >>      input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
        29:         input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
        30:         input  logic [MB_DEPTH-1:0]                mb_entry_wfi,
        31:         
```

`mmu/rtl/mmu_l1dtlb_install.sv:29` (声明 `mb_entry_flg`)

```systemverilog
        26:         
        27:         // WFI Data
        28:         input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
        29: >>      input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
        30:         input  logic [MB_DEPTH-1:0]                mb_entry_wfi,
        31:         
        32:         // Grant Output
```

`mmu/rtl/mmu_l1dtlb_install.sv:30` (声明 `mb_entry_wfi`)

```systemverilog
        27:         // WFI Data
        28:         input  logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
        29:         input  logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
        30: >>      input  logic [MB_DEPTH-1:0]                mb_entry_wfi,
        31:         
        32:         // Grant Output
        33:         output logic [MB_DEPTH-1:0]                mb_refill_gnt_bus,
```

`mmu/rtl/mmu_l1dtlb_install.sv:40` (声明 `jtlb_utlb_ref_ppn`)

```systemverilog
        37:         input  logic                     jtlb_dutlb_ref_cmplt,
        38:         input  logic [2:0]               jtlb_dutlb_ref_id,
        39:         input  logic [VPN_WIDTH-1:0]     jtlb_utlb_ref_vpn,
        40: >>      input  logic [PPN_WIDTH-1:0]     jtlb_utlb_ref_ppn,
        41:         input  logic [FLG_WIDTH-1:0]     jtlb_utlb_ref_flg,
        42:         input  logic                     jtlb_dutlb_pgflt,
        43:         input  logic [2:0]		     l2tlb_l1dtlb_ref_pgs,
```

`mmu/rtl/mmu_l1dtlb_install.sv:50` (声明 `ptw_l1tlb_ref_vpn`)

```systemverilog
        47:         input  logic                     ptw_l1dtlb_ref_pavld,
        48:         input  logic                     ptw_l1dtlb_ref_cmplt,
        49:         input  logic [2:0]               ptw_l1dtlb_ref_id,
        50: >>      input  logic [26:0]              ptw_l1tlb_ref_vpn, // 27 bits matches VPN_WIDTH
        51:         input  logic [27:0]              ptw_l1tlb_ref_ppn, // 28 bits matches PPN_WIDTH
        52:         input  logic                     ptw_l1tlb_acc_err,
        53:         input  logic                     ptw_l1tlb_pgflt,
```

`mmu/rtl/mmu_l1dtlb_install.sv:51` (声明 `ptw_l1tlb_ref_ppn`)

```systemverilog
        48:         input  logic                     ptw_l1dtlb_ref_cmplt,
        49:         input  logic [2:0]               ptw_l1dtlb_ref_id,
        50:         input  logic [26:0]              ptw_l1tlb_ref_vpn, // 27 bits matches VPN_WIDTH
        51: >>      input  logic [27:0]              ptw_l1tlb_ref_ppn, // 28 bits matches PPN_WIDTH
        52:         input  logic                     ptw_l1tlb_acc_err,
        53:         input  logic                     ptw_l1tlb_pgflt,
        54:         input  logic [13:0]              ptw_l1tlb_ref_flg, // 14 bits matches FLG_WIDTH
```

`mmu/rtl/mmu_l1dtlb_install.sv:60` (声明 `utlb_refill_vpn`)

```systemverilog
        57:         // TLB Entry Array Update Interface
        58:         output logic                     utlb_refill_vld,
        59:         output logic [3:0]               utlb_refill_idx,
        60: >>      output logic [VPN_WIDTH-1:0]     utlb_refill_vpn,
        61:         output logic [PPN_WIDTH-1:0]     utlb_refill_ppn,
        62:         output logic [FLG_WIDTH-1:0]     utlb_refill_flg,
        63:         output logic [2:0]		     utlb_refill_pgs,
```

`mmu/rtl/mmu_l1dtlb_install.sv:61` (声明 `utlb_refill_ppn`)

```systemverilog
        58:         output logic                     utlb_refill_vld,
        59:         output logic [3:0]               utlb_refill_idx,
        60:         output logic [VPN_WIDTH-1:0]     utlb_refill_vpn,
        61: >>      output logic [PPN_WIDTH-1:0]     utlb_refill_ppn,
        62:         output logic [FLG_WIDTH-1:0]     utlb_refill_flg,
        63:         output logic [2:0]		     utlb_refill_pgs,
        64:         
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 110 | `id_wfi[2] -> logic [EID_WIDTH-1:0] id_wfi;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1dtlb_install.sv:110` (声明 `id_wfi`)

```systemverilog
       107:     //! 2. Identify WFI Request
       108:     //!************************************************
       109:     logic       req_wfi_vld;
       110: >>  logic [EID_WIDTH-1:0] id_wfi;
       111:     
       112:     // Priority Encoder for WFI (Find First Set)
       113:     always_comb begin
```

## 模块 `mmu_l1dtlb_scheduler`

源码：`mmu/rtl/mmu_l1dtlb_scheduler.sv`
原始未覆盖记录数：`31`；合并后唯一代码对象数：`14`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 145 | `EXPRESSION (credit_avail & ((|mb_entry_ready)))` | 0 1 Not Covered | 1 |
| 213 | `EXPRESSION (mb_req_vld && credit_avail)` | 1 0 Not Covered | 1 |
| 214 | `EXPRESSION (bypass_req_vld && credit_avail && ((!mb_req_vld)))` | 1 0 1 Not Covered; 1 1 0 Not Covered | 2 |

`mmu/rtl/mmu_l1dtlb_scheduler.sv:145`

```systemverilog
       142:     // --- Issue selection (combinational) ---
       143:     assign sel_high_table = |high_table_oh;
       144:     assign sel_low_table  = |no_ptr_mask_oh;
       145: >>  assign update_en      = credit_avail & (|mb_entry_ready);
       146:     
       147:     always_comb begin
       148:         casez ({sel_high_table, sel_low_table})
```

`mmu/rtl/mmu_l1dtlb_scheduler.sv:213`

```systemverilog
       210:     logic sel_mb;
       211:     logic sel_bypass;
       212:     
       213: >>  assign sel_mb     = mb_req_vld && credit_avail;
       214:     assign sel_bypass = bypass_req_vld && credit_avail && !mb_req_vld; 
       215:     
       216:     // Output Mux
```

`mmu/rtl/mmu_l1dtlb_scheduler.sv:214`

```systemverilog
       211:     logic sel_bypass;
       212:     
       213:     assign sel_mb     = mb_req_vld && credit_avail;
       214: >>  assign sel_bypass = bypass_req_vld && credit_avail && !mb_req_vld; 
       215:     
       216:     // Output Mux
       217:     always_comb begin
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 16 | `cpurst_b -> input  logic                     cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `mb_entry_vpn[2][11] -> input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 13 |
| 22 | `mb_entry_vpn[2][20:19] -> input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `mb_entry_vpn[5][1:0] -> input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 23 | `mb_entry_iid[3][1:0] -> input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 23 | `mb_entry_iid[5][0] -> input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 2 |
| - | `Other bits of mb_entry_iid[7:0][6:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 24 | `mb_entry_store[3] -> input  logic [MB_DEPTH-1:0]                mb_entry_store, // NEW: Store attribute array` | Toggle=No, 1->0=No, 0->1=No | INPUT | 4 |

`mmu/rtl/mmu_l1dtlb_scheduler.sv:16` (声明 `cpurst_b`)

```systemverilog
        13:         parameter CREDIT_MAX = 8      // Default credit matching L2 reqq depth
        14:     )(
        15:         //! Clock and Reset
        16: >>      input  logic                     cpurst_b,
        17:         input  logic                     sched_clk,
        18:     
        19:         //! Miss Buffer Status
```

`mmu/rtl/mmu_l1dtlb_scheduler.sv:22` (声明 `mb_entry_vpn`)

```systemverilog
        19:         //! Miss Buffer Status
        20:         input  logic [MB_DEPTH-1:0]                mb_entry_vld,
        21:         input  logic [MB_DEPTH-1:0]                mb_entry_ready, // State == WFG
        22: >>      input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
        23:         input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
        24:         input  logic [MB_DEPTH-1:0]                mb_entry_store, // NEW: Store attribute array
        25:         
```

`mmu/rtl/mmu_l1dtlb_scheduler.sv:23` (声明 `mb_entry_iid`)

```systemverilog
        20:         input  logic [MB_DEPTH-1:0]                mb_entry_vld,
        21:         input  logic [MB_DEPTH-1:0]                mb_entry_ready, // State == WFG
        22:         input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
        23: >>      input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
        24:         input  logic [MB_DEPTH-1:0]                mb_entry_store, // NEW: Store attribute array
        25:         
        26:         //! Bypass Inputs (From Allocator/T1 Stage)
```

`mmu/rtl/mmu_l1dtlb_scheduler.sv:24` (声明 `mb_entry_store`)

```systemverilog
        21:         input  logic [MB_DEPTH-1:0]                mb_entry_ready, // State == WFG
        22:         input  logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
        23:         input  logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
        24: >>      input  logic [MB_DEPTH-1:0]                mb_entry_store, // NEW: Store attribute array
        25:         
        26:         //! Bypass Inputs (From Allocator/T1 Stage)
        27:         input  logic                     alloc_gnt0,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 57 | `credit_cnt[4] -> logic [$clog2(CREDIT_MAX+1):0] credit_cnt;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 88 | `therm_ptr[7] -> wire  [MB_DEPTH-1:0]     therm_ptr;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1dtlb_scheduler.sv:57` (声明 `credit_cnt`)

```systemverilog
        54:     //!************************************************
        55:     //! Credit Counter Management
        56:     //!************************************************
        57: >>  logic [$clog2(CREDIT_MAX+1):0] credit_cnt;
        58:     logic                          credit_avail;
        59:     logic                          req_fire;
        60:     
```

`mmu/rtl/mmu_l1dtlb_scheduler.sv:88` (声明 `therm_ptr`)

```systemverilog
        85:     logic [MB_DEPTH-1:0]     priority_oh_next;
        86:     
        87:     // Thermometer / intermediate nets
        88: >>  wire  [MB_DEPTH-1:0]     therm_ptr;
        89:     wire  [MB_DEPTH-1:0]     high_table_mask;
        90:     wire  [MB_DEPTH-1:0]     high_table_therm;
        91:     logic [MB_DEPTH-1:0]     high_table_oh;
```

## 模块 `mmu_l1itlb`

源码：`mmu/rtl/mmu_l1itlb.sv`
原始未覆盖记录数：`461`；合并后唯一代码对象数：`424`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 753 | `ref_nxt_st[2:0] = ABT;` | 0/N |
| 755 | `ref_nxt_st[2:0] = IDLE;` | 0/N |
| 759 | `ref_nxt_st[2:0] = WFG;` | 0/N |
| 763 | `ref_nxt_st[2:0] = IDLE;` | 0/N |
| 783 | `ref_nxt_st[2:0] = IDLE;` | 0/N |

`mmu/rtl/mmu_l1itlb.sv:753`

```systemverilog
       749:                 ref_nxt_st[2:0] = IDLE;
       750:             end
       751:             WFG: begin
       752:               if(ifu_mmu_abort && credit_cnt != 1'b0)
       753: >>              ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755:                 ref_nxt_st[2:0] = IDLE;
       756:               else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
```

`mmu/rtl/mmu_l1itlb.sv:755`

```systemverilog
       751:             WFG: begin
       752:               if(ifu_mmu_abort && credit_cnt != 1'b0)
       753:                 ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755: >>              ref_nxt_st[2:0] = IDLE;
       756:               else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
       758:               else
       759:                 ref_nxt_st[2:0] = WFG;
```

`mmu/rtl/mmu_l1itlb.sv:759`

```systemverilog
       755:                 ref_nxt_st[2:0] = IDLE;
       756:               else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
       758:               else
       759: >>              ref_nxt_st[2:0] = WFG;
       760:             end
       761:             WFC: begin
       762:               if(ifu_mmu_abort && l1itlb_ref_cmplt)
       763:                 ref_nxt_st[2:0] = IDLE;
```

`mmu/rtl/mmu_l1itlb.sv:763`

```systemverilog
       759:                 ref_nxt_st[2:0] = WFG;
       760:             end
       761:             WFC: begin
       762:               if(ifu_mmu_abort && l1itlb_ref_cmplt)
       763: >>              ref_nxt_st[2:0] = IDLE;
       764:               else if(ifu_mmu_abort)
       765:                 ref_nxt_st[2:0] = ABT;
       766:               else if(l1itlb_ref_cmplt && (ptw_l1tlb_pgflt || jtlb_iutlb_pgflt))
       767:                 ref_nxt_st[2:0] = PGFLT;
```

`mmu/rtl/mmu_l1itlb.sv:783`

```systemverilog
       779:               else
       780:                 ref_nxt_st[2:0] = ABT;
       781:             end
       782:             default: begin
       783: >>             ref_nxt_st[2:0] = IDLE;
       784:             end
       785:         endcase
       786:     // &CombEnd; @310
       787:     end
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 459 | `SUB-EXPRESSION (ifu_mmu_va_vld && ((!iutlb_addr_hit)) && ((!iutlb_off_hit)))` | 1 1 0 Not Covered | 1 |
| 510 | `EXPRESSION (ifu_mmu_va_vld && iutlb_off_hit)` | 1 1 Not Covered | 1 |
| 520 | `EXPRESSION (iutlb_bypass_vld || iutlb_hit_vld || iutlb_disable_vld || iutlb_acc_flt || iutlb_ref_pgflt || iutlb_va_illegal)` | 0 0 1 0 0 0 Not Covered; 1 0 0 0 0 0 Not Covered | 2 |
| 533 | `EXPRESSION (iutlb_flg_aft_bypass[11] || ((!iutlb_flg_aft_bypass[13])))` | 1 0 Not Covered | 1 |
| 548 | `EXPRESSION (((ifu_mmu_va[(VPN_WIDTH + 10)] && ((!(&ifu_mmu_va[62:(VPN_WIDTH + 11)])))) || (((!ifu_mmu_va[(VPN_WIDTH + 10)])) && ((|ifu_mmu_va[62:(VPN_WIDTH + 11)])))) && (...` | 1 0 1 Not Covered | 1 |
| 548 | `SUB-EXPRESSION ((ifu_mmu_va[(VPN_WIDTH + 10)] && ((!(&ifu_mmu_va[62:(VPN_WIDTH + 11)])))) || (((!ifu_mmu_va[(VPN_WIDTH + 10)])) && ((|ifu_mmu_va[62:(VPN_WIDTH + 11)])))))` | 0 1 Not Covered | 1 |
| 548 | `SUB-EXPRESSION (ifu_mmu_va[(VPN_WIDTH + 10)] && ((!(&ifu_mmu_va[62:(VPN_WIDTH + 11)]))))` | 1 0 Not Covered | 1 |
| 548 | `SUB-EXPRESSION (((!ifu_mmu_va[(VPN_WIDTH + 10)])) && ((|ifu_mmu_va[62:(VPN_WIDTH + 11)])))` | 1 1 Not Covered | 1 |
| 551 | `SUB-EXPRESSION (((!iutlb_flg_aft_bypass[0])) || (((!iutlb_flg_aft_bypass[1])) && iutlb_flg_aft_bypass[2]) || ((!iutlb_flg_aft_bypass[3])) || (iutlb_flg_aft_bypass[4] && cp0_su...` | 0 0 0 0 0 0 0 0 1 Not Covered; 0 0 0 0 0 1 0 0 0 Not Covered; 0 0 0 0 1 0 0 0 0 Not Covered; ... 共 7 种 | 7 |
| 551 | `SUB-EXPRESSION (((!iutlb_flg_aft_bypass[1])) && iutlb_flg_aft_bypass[2])` | 1 1 Not Covered | 1 |
| 551 | `SUB-EXPRESSION (iutlb_flg_aft_bypass[4] && cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered; 1 1 0 Not Covered; 1 1 1 Not Covered | 3 |
| 551 | `SUB-EXPRESSION (((!iutlb_flg_aft_bypass[4])) && cp0_user_mode && regs_mmu_en)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| 566 | `EXPRESSION (jtlb_acc_fault_flop || (((!pmp_mmu_flg2[2])) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg2[3]))) ) && pmp_flg_vld))` | 0 1 Not Covered | 1 |
| 566 | `SUB-EXPRESSION (((!pmp_mmu_flg2[2])) && ( ! (cp0_mach_mode && ((!pmp_mmu_flg2[3]))) ) && pmp_flg_vld)` | 1 0 1 Not Covered; 1 1 1 Not Covered | 2 |
| 566 | `SUB-EXPRESSION (cp0_mach_mode && ((!pmp_mmu_flg2[3])))` | 1 0 Not Covered | 1 |
| 727 | `EXPRESSION (ifu_mmu_va_vld && ((!iutlb_addr_hit_vld)) && ((!iutlb_off_hit)) && ((!cp0_mmu_no_op_req)))` | 1 1 0 1 Not Covered; 1 1 1 0 Not Covered | 2 |
| 752 | `EXPRESSION (ifu_mmu_abort && (credit_cnt != 1'b0))` | 1 0 Not Covered; 1 1 Not Covered | 2 |
| 752 | `SUB-EXPRESSION (credit_cnt != 1'b0)` | 0 Not Covered | 1 |
| 756 | `EXPRESSION (credit_cnt != 1'b0)` | 0 Not Covered | 1 |
| 762 | `EXPRESSION (ifu_mmu_abort && l1itlb_ref_cmplt)` | 1 1 Not Covered | 1 |
| 766 | `EXPRESSION (l1itlb_ref_cmplt && (ptw_l1tlb_pgflt || jtlb_iutlb_pgflt))` | 0 1 Not Covered | 1 |
| 829 | `EXPRESSION (iutlb_refill_vld && hpcp_mmu_cnt_en)` | 1 0 Not Covered | 1 |
| 2064 | `EXPRESSION (ifu_mmu_va_vld && iutlb_addr_hit_vld && ((!iutlb_addr_hit)) && ((!iutlb_off_hit)))` | 1 1 1 0 Not Covered | 1 |
| 2252 | `SUB-EXPRESSION (iutlb_hit_vld || iutlb_disable_vld)` | 0 1 Not Covered | 1 |
| 2270 | `EXPRESSION (iutlb_hit_vld || iutlb_disable_vld)` | 0 1 Not Covered | 1 |

`mmu/rtl/mmu_l1itlb.sv:459`

```systemverilog
       456:     //==========================================================
       457:     //                  Gate Cell
       458:     //==========================================================
       459: >>  assign iutlb_clk_en = ifu_mmu_va_vld && !iutlb_addr_hit && !iutlb_off_hit
       460:                        || iutlb_refill_on
       461:                        || jtlb_acc_fault
       462:                        || jtlb_acc_fault_flop
```

`mmu/rtl/mmu_l1itlb.sv:510`

```systemverilog
       507:     //assign iutlb_bypass_vld  = iutlb_refill_cmplt;
       508:     assign iutlb_bypass_vld  = 1'b0;
       509:     assign iutlb_off_hit     = !regs_mmu_en || cp0_mach_mode;
       510: >>  assign iutlb_disable_vld = ifu_mmu_va_vld && iutlb_off_hit;
       511:     
       512:     //----------------------------------------------------------
       513:     //                  Interface to IFU
```

`mmu/rtl/mmu_l1itlb.sv:520`

```systemverilog
       517:     // 2. utlb refill cmplt, no matter exception or not
       518:     // 3. mmu is disabled
       519:     // &Force("output", "mmu_ifu_pavld"); @94
       520: >>  assign mmu_ifu_pavld = iutlb_bypass_vld
       521:                         || (iutlb_hit_vld
       522:                              || iutlb_disable_vld
       523:                              || iutlb_acc_flt
```

`mmu/rtl/mmu_l1itlb.sv:533`

```systemverilog
       530:     
       531:     // flags judgement
       532:     // pmas to ifu: bufferable, security, cacheable
       533: >>  assign mmu_ifu_buf      = iutlb_flg_aft_bypass[11]
       534:                           || !iutlb_flg_aft_bypass[13]; //when !so, always buf
       535:     
       536:     assign mmu_ifu_sec      = iutlb_flg_aft_bypass[9];
```

`mmu/rtl/mmu_l1itlb.sv:548`

```systemverilog
       545:     // page fault when ifu meets strong order
       546:     // page fault when tfatal and tmiss from jTLB
       547:     // page fault when ifu high va not legal
       548: >>  assign iutlb_va_illegal = (ifu_mmu_va[VPN_WIDTH+10] && !(&ifu_mmu_va[62:VPN_WIDTH+11])
       549:                           ||  !ifu_mmu_va[VPN_WIDTH+10] &&  (|ifu_mmu_va[62:VPN_WIDTH+11]))
       550:                               && !iutlb_off_hit && ifu_mmu_va_vld;
       551:     assign iutlb_page_fault = (!iutlb_flg_aft_bypass[0]
```

`mmu/rtl/mmu_l1itlb.sv:551`

```systemverilog
       548:     assign iutlb_va_illegal = (ifu_mmu_va[VPN_WIDTH+10] && !(&ifu_mmu_va[62:VPN_WIDTH+11])
       549:                           ||  !ifu_mmu_va[VPN_WIDTH+10] &&  (|ifu_mmu_va[62:VPN_WIDTH+11]))
       550:                               && !iutlb_off_hit && ifu_mmu_va_vld;
       551: >>  assign iutlb_page_fault = (!iutlb_flg_aft_bypass[0]
       552:                             || !iutlb_flg_aft_bypass[1] && iutlb_flg_aft_bypass[2]
       553:                             || !iutlb_flg_aft_bypass[3]
       554:                             ||  iutlb_flg_aft_bypass[4] && cp0_supv_mode && !cp0_mmu_sum 
```

`mmu/rtl/mmu_l1itlb.sv:566`

```systemverilog
       563:     
       564:     // access deny when pmp check fail
       565:     // &Force("bus", "pmp_mmu_flg2", 3, 0); @140
       566: >>  assign mmu_ifu_deny = jtlb_acc_fault_flop
       567:                        // L-bit for M-Mode
       568:                        || !pmp_mmu_flg2[2] && !(cp0_mach_mode && !pmp_mmu_flg2[3])
       569:                            && pmp_flg_vld; 
```

`mmu/rtl/mmu_l1itlb.sv:727`

```systemverilog
       724:     
       725:     //  When utlb miss and mmu is enabled, utlb refill SM will
       726:     //  be started
       727: >>  assign iutlb_miss_vld = ifu_mmu_va_vld && !iutlb_addr_hit_vld
       728:                                            //&& !iutlb_page_fault
       729:                                            && !iutlb_off_hit
       730:                                            && !cp0_mmu_no_op_req;
```

`mmu/rtl/mmu_l1itlb.sv:752`

```systemverilog
       749:                 ref_nxt_st[2:0] = IDLE;
       750:             end
       751:             WFG: begin
       752: >>            if(ifu_mmu_abort && credit_cnt != 1'b0)
       753:                 ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755:                 ref_nxt_st[2:0] = IDLE;
```

`mmu/rtl/mmu_l1itlb.sv:756`

```systemverilog
       753:                 ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755:                 ref_nxt_st[2:0] = IDLE;
       756: >>            else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
       758:               else
       759:                 ref_nxt_st[2:0] = WFG;
```

`mmu/rtl/mmu_l1itlb.sv:762`

```systemverilog
       759:                 ref_nxt_st[2:0] = WFG;
       760:             end
       761:             WFC: begin
       762: >>            if(ifu_mmu_abort && l1itlb_ref_cmplt)
       763:                 ref_nxt_st[2:0] = IDLE;
       764:               else if(ifu_mmu_abort)
       765:                 ref_nxt_st[2:0] = ABT;
```

`mmu/rtl/mmu_l1itlb.sv:766`

```systemverilog
       763:                 ref_nxt_st[2:0] = IDLE;
       764:               else if(ifu_mmu_abort)
       765:                 ref_nxt_st[2:0] = ABT;
       766: >>            else if(l1itlb_ref_cmplt && (ptw_l1tlb_pgflt || jtlb_iutlb_pgflt))
       767:                 ref_nxt_st[2:0] = PGFLT;
       768:               else if(l1itlb_ref_cmplt)
       769:                 ref_nxt_st[2:0] = IDLE;
```

`mmu/rtl/mmu_l1itlb.sv:829`

```systemverilog
       826:     //                         || (ref_cur_st[2:0] == ABT) && l1itlb_ref_cmplt;
       827:     
       828:     // for hpcp
       829: >>  assign iutlb_miss_cnt = iutlb_refill_vld && hpcp_mmu_cnt_en;
       830:     
       831:     always @(posedge iutlb_clk or negedge cpurst_b) begin
       832:       if (!cpurst_b)
```

`mmu/rtl/mmu_l1itlb.sv:2064`

```systemverilog
      2061:     assign iutlb_addr_hit     = iutlb_entry_hit[0]  || iutlb_entry_hit[8]
      2062:                              || iutlb_entry_hit[16] || iutlb_entry_hit[24]; 
      2063:     
      2064: >>  assign iutlb_swp_en       = ifu_mmu_va_vld && iutlb_addr_hit_vld && !iutlb_addr_hit
      2065:                              && !iutlb_off_hit;
      2066:     
      2067:     //==========================================================
```

`mmu/rtl/mmu_l1itlb.sv:2252`

```systemverilog
      2249:     //----------------------------------------------------------
      2250:     // to cut off the timing from dutlb abort to access fault
      2251:     assign iutlb_acc_flt  = ptw_l1tlb_acc_err && iutlb_refill_on;
      2252: >>  assign jtlb_acc_fault = iutlb_acc_flt
      2253:                         || (iutlb_hit_vld || iutlb_disable_vld) && iutlb_flg_aft_bypass[13];
      2254:     
      2255:     always @(posedge iutlb_clk or negedge cpurst_b)
```

`mmu/rtl/mmu_l1itlb.sv:2270`

```systemverilog
      2267:     //----------------------------------------------------------
      2268:     // to cut off the timing from final-pa to pmp check
      2269:     // pa buffer clock
      2270: >>  assign iutlb_pa_vld = iutlb_hit_vld || iutlb_disable_vld;
      2271:     //assign pabuf_clk_en = iutlb_pa_vld ^ pmp_flg_vld
      2272:     //                    || iutlb_hit_vld && (iutlb_hit_pa_fst[PPN_WIDTH-1:0] !=
      2273:     //                             iutlb_pa_buf[PPN_WIDTH-1:0])
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 742 | `742            case (ref_cur_st)` | WFG - - 1 - - - - - - - Not Covered |
| 742 | `742            case (ref_cur_st)` | WFG - - 0 1 - - - - - - Not Covered |
| 742 | `742            case (ref_cur_st)` | WFG - - 0 0 0 - - - - - Not Covered |
| 742 | `742            case (ref_cur_st)` | WFC - - - - - 1 - - - - Not Covered |
| 742 | `742            case (ref_cur_st)` | default - - - - - - - - - - Not Covered |

`mmu/rtl/mmu_l1itlb.sv:742`

```systemverilog
       738:     end
       739:     
       740:     // &CombBeg; @259
       741:     always_comb begin
       742: >>      case (ref_cur_st)
       743:             IDLE: begin
       744:               if(ifu_mmu_abort)
       745:                 ref_nxt_st[2:0] = IDLE;
       746:               else if(iutlb_miss_vld)
```

### FSM 状态迁移覆盖

| FSM | 未覆盖迁移 | 行号 |
| --- | --- | ---: |
| `ref_cur_st` | `WFG->IDLE` | 735 |
| `ref_cur_st` | `WFG->ABT` | 753 |

`mmu/rtl/mmu_l1itlb.sv:735` (FSM `ref_cur_st` 的 `WFG->IDLE` 迁移)

```systemverilog
       730:                                            && !cp0_mmu_no_op_req;
       731:     
       732:     always @(posedge iutlb_clk or negedge cpurst_b)
       733:     begin
       734:       if (!cpurst_b)
       735: >>      ref_cur_st[2:0] <= 3'b0;
       736:       else
       737:         ref_cur_st[2:0] <= ref_nxt_st[2:0];
       738:     end
       739:     
       740:     // &CombBeg; @259
```

`mmu/rtl/mmu_l1itlb.sv:753` (FSM `ref_cur_st` 的 `WFG->ABT` 迁移)

```systemverilog
       748:               else
       749:                 ref_nxt_st[2:0] = IDLE;
       750:             end
       751:             WFG: begin
       752:               if(ifu_mmu_abort && credit_cnt != 1'b0)
       753: >>              ref_nxt_st[2:0] = ABT;
       754:               else if(ifu_mmu_abort)
       755:                 ref_nxt_st[2:0] = IDLE;
       756:               else if(credit_cnt != 1'b0)
       757:                 ref_nxt_st[2:0] = WFC;
       758:               else
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 13 | `cpurst_b -> input  logic         cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 27 | `pad_yy_icg_scan_en -> input  logic         pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 33 | `ifu_mmu_va[62] -> input  logic [62:0]  ifu_mmu_va,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 37 | `mmu_ifu_pa[23:20] -> output logic [27:0]  mmu_ifu_pa,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 37 | `mmu_ifu_pa[27:25] -> output logic [27:0]  mmu_ifu_pa,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 47 | `mmu_pmp_pa2[15] -> output logic [27:0]  mmu_pmp_pa2,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 47 | `mmu_pmp_pa2[27:20] -> output logic [27:0]  mmu_pmp_pa2,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 48 | `pmp_mmu_flg2[3] -> input  logic [3 :0]  pmp_mmu_flg2,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 54 | `sysmap_mmu_flg2[0] -> input  logic [4 :0]  sysmap_mmu_flg2,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 59 | `hpcp_mmu_cnt_en -> input  logic         hpcp_mmu_cnt_en,` | Toggle=No, 1->0=Yes, 0->1=No | INPUT | 1 |
| 90 | `ptw_l1tlb_ref_vpn[26] -> input  logic [26:0]  ptw_l1tlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 91 | `ptw_l1tlb_ref_ppn[23:21] -> input  logic [27:0]  ptw_l1tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 100 | `jtlb_utlb_ref_ppn[20] -> input  logic [27:0]  jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 100 | `jtlb_utlb_ref_ppn[23:21] -> input  logic [27:0]  jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 100 | `jtlb_utlb_ref_ppn[27:24] -> input  logic [27:0]  jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |

`mmu/rtl/mmu_l1itlb.sv:13` (声明 `cpurst_b`)

```systemverilog
        10:     //!**********************************************
        11:     //! Clock and Reset
        12:     //!**********************************************
        13: >>  input  logic         cpurst_b,               
        14:     input  logic         forever_cpuclk,         
        15:     input  logic         utlb_clk,               
        16:     
```

`mmu/rtl/mmu_l1itlb.sv:27` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        24:     input  logic         regs_mmu_en,            
        25:     input  logic         regs_utlb_clr,          
        26:     
        27: >>  input  logic         pad_yy_icg_scan_en,     
        28:     
        29:     //!**************************************************
        30:     //! IFU <=> MMU Interface
```

`mmu/rtl/mmu_l1itlb.sv:33` (声明 `ifu_mmu_va`)

```systemverilog
        30:     //! IFU <=> MMU Interface
        31:     //!**************************************************
        32:     input  logic         ifu_mmu_va_vld,         
        33: >>  input  logic [62:0]  ifu_mmu_va,             
        34:     input  logic         ifu_mmu_abort,          
        35:     
        36:     output logic         mmu_ifu_pavld,          
```

`mmu/rtl/mmu_l1itlb.sv:37` (声明 `mmu_ifu_pa`)

```systemverilog
        34:     input  logic         ifu_mmu_abort,          
        35:     
        36:     output logic         mmu_ifu_pavld,          
        37: >>  output logic [27:0]  mmu_ifu_pa,             
        38:     output logic         mmu_ifu_buf,            
        39:     output logic         mmu_ifu_ca,             
        40:     output logic         mmu_ifu_deny,           
```

`mmu/rtl/mmu_l1itlb.sv:47` (声明 `mmu_pmp_pa2`)

```systemverilog
        44:     //!**************************************************
        45:     //! PMP
        46:     //!**************************************************
        47: >>  output logic [27:0]  mmu_pmp_pa2,            
        48:     input  logic [3 :0]  pmp_mmu_flg2,           
        49:     
        50:     //!**************************************************
```

`mmu/rtl/mmu_l1itlb.sv:48` (声明 `pmp_mmu_flg2`)

```systemverilog
        45:     //! PMP
        46:     //!**************************************************
        47:     output logic [27:0]  mmu_pmp_pa2,            
        48: >>  input  logic [3 :0]  pmp_mmu_flg2,           
        49:     
        50:     //!**************************************************
        51:     //! System Map
```

`mmu/rtl/mmu_l1itlb.sv:54` (声明 `sysmap_mmu_flg2`)

```systemverilog
        51:     //! System Map
        52:     //!**************************************************
        53:     output logic [27:0]  mmu_sysmap_pa2,
        54: >>  input  logic [4 :0]  sysmap_mmu_flg2,        
        55:     
        56:     //!**************************************************
        57:     //! HPCP ??
```

`mmu/rtl/mmu_l1itlb.sv:59` (声明 `hpcp_mmu_cnt_en`)

```systemverilog
        56:     //!**************************************************
        57:     //! HPCP ??
        58:     //!**************************************************
        59: >>  input  logic         hpcp_mmu_cnt_en,        
        60:     output logic         mmu_hpcp_iutlb_miss,    
        61:     
        62:     //!**************************************************
```

`mmu/rtl/mmu_l1itlb.sv:90` (声明 `ptw_l1tlb_ref_vpn`)

```systemverilog
        87:     
        88:         input  logic         ptw_l1itlb_ref_pavld,
        89:         input  logic         ptw_l1itlb_ref_cmplt,
        90: >>      input  logic [26:0]  ptw_l1tlb_ref_vpn,
        91:         input  logic [27:0]  ptw_l1tlb_ref_ppn,
        92:         input  logic         ptw_l1tlb_acc_err,
        93:         input  logic         ptw_l1tlb_pgflt,
```

`mmu/rtl/mmu_l1itlb.sv:91` (声明 `ptw_l1tlb_ref_ppn`)

```systemverilog
        88:         input  logic         ptw_l1itlb_ref_pavld,
        89:         input  logic         ptw_l1itlb_ref_cmplt,
        90:         input  logic [26:0]  ptw_l1tlb_ref_vpn,
        91: >>      input  logic [27:0]  ptw_l1tlb_ref_ppn,
        92:         input  logic         ptw_l1tlb_acc_err,
        93:         input  logic         ptw_l1tlb_pgflt,
        94:         input  logic [13:0]  ptw_l1tlb_ref_flg,
```

`mmu/rtl/mmu_l1itlb.sv:100` (声明 `jtlb_utlb_ref_ppn`)

```systemverilog
        97:     input  logic         jtlb_iutlb_ref_pavld,   //! L2TLB Refill Valid
        98:     input  logic         jtlb_iutlb_ref_cmplt,   
        99:     input  logic [26:0]  jtlb_utlb_ref_vpn,      
       100: >>  input  logic [27:0]  jtlb_utlb_ref_ppn,      
       101:     input  logic [13:0]  jtlb_utlb_ref_flg,      
       102:     input  logic [2 :0]  jtlb_utlb_ref_pgs,      
       103:     //input  logic         jtlb_iutlb_acc_err,     
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 110 | `iutlb_pa_buf[15] -> logic     [27:0]  iutlb_pa_buf;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 110 | `iutlb_pa_buf[27:20] -> logic     [27:0]  iutlb_pa_buf;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 120 | `entry0_flg[3:0] -> logic    [13:0]  entry0_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 120 | `entry0_flg[4] -> logic    [13:0]  entry0_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 120 | `entry0_flg[9:5] -> logic    [13:0]  entry0_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 123 | `entry0_ppn[11] -> logic    [27:0]  entry0_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 123 | `entry0_ppn[23:20] -> logic    [27:0]  entry0_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 123 | `entry0_ppn[27:25] -> logic    [27:0]  entry0_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 128 | `entry0_vpn[15] -> logic    [26:0]  entry0_vpn;` | Toggle=No, 1->0=No, 0->1=No | 2 |
| 129 | `entry10_flg[3:0] -> logic    [13:0]  entry10_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 129 | `entry10_flg[4] -> logic    [13:0]  entry10_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 129 | `entry10_flg[6:5] -> logic    [13:0]  entry10_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 129 | `entry10_flg[8:7] -> logic    [13:0]  entry10_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 129 | `entry10_flg[10:9] -> logic    [13:0]  entry10_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 131 | `entry10_pgs[0] -> logic    [2 :0]  entry10_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 131 | `entry10_pgs[2:1] -> logic    [2 :0]  entry10_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 132 | `entry10_ppn[11:10] -> logic    [27:0]  entry10_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 132 | `entry10_ppn[15:13] -> logic    [27:0]  entry10_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 132 | `entry10_ppn[19:18] -> logic    [27:0]  entry10_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 132 | `entry10_ppn[23:20] -> logic    [27:0]  entry10_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 132 | `entry10_ppn[24] -> logic    [27:0]  entry10_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 132 | `entry10_ppn[27:25] -> logic    [27:0]  entry10_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 137 | `entry11_flg[3:0] -> logic    [13:0]  entry11_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 137 | `entry11_flg[4] -> logic    [13:0]  entry11_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 137 | `entry11_flg[6:5] -> logic    [13:0]  entry11_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 137 | `entry11_flg[8:7] -> logic    [13:0]  entry11_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 137 | `entry11_flg[10:9] -> logic    [13:0]  entry11_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 139 | `entry11_pgs[0] -> logic    [2 :0]  entry11_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 139 | `entry11_pgs[2:1] -> logic    [2 :0]  entry11_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 140 | `entry11_ppn[11:10] -> logic    [27:0]  entry11_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 140 | `entry11_ppn[15:13] -> logic    [27:0]  entry11_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 140 | `entry11_ppn[19:18] -> logic    [27:0]  entry11_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 140 | `entry11_ppn[23:20] -> logic    [27:0]  entry11_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 140 | `entry11_ppn[24] -> logic    [27:0]  entry11_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 140 | `entry11_ppn[27:25] -> logic    [27:0]  entry11_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 145 | `entry12_flg[3:0] -> logic    [13:0]  entry12_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 145 | `entry12_flg[4] -> logic    [13:0]  entry12_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 145 | `entry12_flg[6:5] -> logic    [13:0]  entry12_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 145 | `entry12_flg[8:7] -> logic    [13:0]  entry12_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 145 | `entry12_flg[10:9] -> logic    [13:0]  entry12_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 147 | `entry12_pgs[0] -> logic    [2 :0]  entry12_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 147 | `entry12_pgs[2:1] -> logic    [2 :0]  entry12_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 148 | `entry12_ppn[11:10] -> logic    [27:0]  entry12_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 148 | `entry12_ppn[15:13] -> logic    [27:0]  entry12_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 148 | `entry12_ppn[19:18] -> logic    [27:0]  entry12_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 148 | `entry12_ppn[23:20] -> logic    [27:0]  entry12_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 148 | `entry12_ppn[24] -> logic    [27:0]  entry12_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 148 | `entry12_ppn[27:25] -> logic    [27:0]  entry12_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 153 | `entry13_flg[3:0] -> logic    [13:0]  entry13_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 153 | `entry13_flg[4] -> logic    [13:0]  entry13_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 153 | `entry13_flg[6:5] -> logic    [13:0]  entry13_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 153 | `entry13_flg[8:7] -> logic    [13:0]  entry13_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 153 | `entry13_flg[10:9] -> logic    [13:0]  entry13_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 155 | `entry13_pgs[1] -> logic    [2 :0]  entry13_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 156 | `entry13_ppn[11:10] -> logic    [27:0]  entry13_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 156 | `entry13_ppn[15:13] -> logic    [27:0]  entry13_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 156 | `entry13_ppn[19] -> logic    [27:0]  entry13_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 156 | `entry13_ppn[23:20] -> logic    [27:0]  entry13_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 156 | `entry13_ppn[27:25] -> logic    [27:0]  entry13_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 161 | `entry14_flg[3:0] -> logic    [13:0]  entry14_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 161 | `entry14_flg[4] -> logic    [13:0]  entry14_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 161 | `entry14_flg[6:5] -> logic    [13:0]  entry14_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 161 | `entry14_flg[8:7] -> logic    [13:0]  entry14_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 161 | `entry14_flg[10:9] -> logic    [13:0]  entry14_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 163 | `entry14_pgs[0] -> logic    [2 :0]  entry14_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 163 | `entry14_pgs[2:1] -> logic    [2 :0]  entry14_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 164 | `entry14_ppn[11:10] -> logic    [27:0]  entry14_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 164 | `entry14_ppn[15:13] -> logic    [27:0]  entry14_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 164 | `entry14_ppn[19:18] -> logic    [27:0]  entry14_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 164 | `entry14_ppn[27:20] -> logic    [27:0]  entry14_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 169 | `entry15_flg[3:0] -> logic    [13:0]  entry15_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 169 | `entry15_flg[4] -> logic    [13:0]  entry15_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 169 | `entry15_flg[6:5] -> logic    [13:0]  entry15_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 169 | `entry15_flg[8:7] -> logic    [13:0]  entry15_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 169 | `entry15_flg[10:9] -> logic    [13:0]  entry15_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `entry15_pgs[0] -> logic    [2 :0]  entry15_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 171 | `entry15_pgs[2:1] -> logic    [2 :0]  entry15_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 172 | `entry15_ppn[11:10] -> logic    [27:0]  entry15_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 172 | `entry15_ppn[15:13] -> logic    [27:0]  entry15_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 172 | `entry15_ppn[19:18] -> logic    [27:0]  entry15_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 172 | `entry15_ppn[27:20] -> logic    [27:0]  entry15_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 177 | `entry16_flg[3:0] -> logic    [13:0]  entry16_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 177 | `entry16_flg[4] -> logic    [13:0]  entry16_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 177 | `entry16_flg[6:5] -> logic    [13:0]  entry16_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 177 | `entry16_flg[8:7] -> logic    [13:0]  entry16_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 177 | `entry16_flg[10:9] -> logic    [13:0]  entry16_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 179 | `entry16_pgs[2] -> logic    [2 :0]  entry16_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 180 | `entry16_ppn[13] -> logic    [27:0]  entry16_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 180 | `entry16_ppn[19:18] -> logic    [27:0]  entry16_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 180 | `entry16_ppn[23:20] -> logic    [27:0]  entry16_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 180 | `entry16_ppn[27:25] -> logic    [27:0]  entry16_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 185 | `entry16_vpn[11] -> logic    [26:0]  entry16_vpn;` | Toggle=No, 1->0=No, 0->1=No | 4 |
| 186 | `entry17_flg[3:0] -> logic    [13:0]  entry17_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 186 | `entry17_flg[4] -> logic    [13:0]  entry17_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 186 | `entry17_flg[6:5] -> logic    [13:0]  entry17_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 186 | `entry17_flg[8:7] -> logic    [13:0]  entry17_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 186 | `entry17_flg[10:9] -> logic    [13:0]  entry17_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 188 | `entry17_pgs[0] -> logic    [2 :0]  entry17_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 188 | `entry17_pgs[2:1] -> logic    [2 :0]  entry17_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 189 | `entry17_ppn[1] -> logic    [27:0]  entry17_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 189 | `entry17_ppn[11:10] -> logic    [27:0]  entry17_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 189 | `entry17_ppn[15:13] -> logic    [27:0]  entry17_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 189 | `entry17_ppn[19:18] -> logic    [27:0]  entry17_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 189 | `entry17_ppn[27:20] -> logic    [27:0]  entry17_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 194 | `entry18_flg[3:0] -> logic    [13:0]  entry18_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 194 | `entry18_flg[4] -> logic    [13:0]  entry18_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 194 | `entry18_flg[6:5] -> logic    [13:0]  entry18_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 194 | `entry18_flg[8:7] -> logic    [13:0]  entry18_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 194 | `entry18_flg[10:9] -> logic    [13:0]  entry18_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 196 | `entry18_pgs[0] -> logic    [2 :0]  entry18_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 196 | `entry18_pgs[2:1] -> logic    [2 :0]  entry18_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 197 | `entry18_ppn[11:10] -> logic    [27:0]  entry18_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 197 | `entry18_ppn[15:13] -> logic    [27:0]  entry18_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 197 | `entry18_ppn[19:18] -> logic    [27:0]  entry18_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 197 | `entry18_ppn[27:20] -> logic    [27:0]  entry18_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 202 | `entry19_flg[3:0] -> logic    [13:0]  entry19_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 202 | `entry19_flg[4] -> logic    [13:0]  entry19_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 202 | `entry19_flg[6:5] -> logic    [13:0]  entry19_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 202 | `entry19_flg[8:7] -> logic    [13:0]  entry19_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 202 | `entry19_flg[10:9] -> logic    [13:0]  entry19_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 204 | `entry19_pgs[0] -> logic    [2 :0]  entry19_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 204 | `entry19_pgs[2:1] -> logic    [2 :0]  entry19_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 205 | `entry19_ppn[11:10] -> logic    [27:0]  entry19_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 205 | `entry19_ppn[15:13] -> logic    [27:0]  entry19_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 205 | `entry19_ppn[19:18] -> logic    [27:0]  entry19_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 205 | `entry19_ppn[27:20] -> logic    [27:0]  entry19_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 210 | `entry1_flg[4] -> logic    [13:0]  entry1_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 210 | `entry1_flg[8:7] -> logic    [13:0]  entry1_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 212 | `entry1_pgs[2] -> logic    [2 :0]  entry1_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 213 | `entry1_ppn[15] -> logic    [27:0]  entry1_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 213 | `entry1_ppn[19:18] -> logic    [27:0]  entry1_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 213 | `entry1_ppn[23:20] -> logic    [27:0]  entry1_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 213 | `entry1_ppn[27:25] -> logic    [27:0]  entry1_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 218 | `entry20_flg[3:0] -> logic    [13:0]  entry20_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 218 | `entry20_flg[4] -> logic    [13:0]  entry20_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 218 | `entry20_flg[6:5] -> logic    [13:0]  entry20_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 218 | `entry20_flg[8:7] -> logic    [13:0]  entry20_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 218 | `entry20_flg[10:9] -> logic    [13:0]  entry20_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 220 | `entry20_pgs[0] -> logic    [2 :0]  entry20_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 220 | `entry20_pgs[2:1] -> logic    [2 :0]  entry20_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 221 | `entry20_ppn[9] -> logic    [27:0]  entry20_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 221 | `entry20_ppn[11:10] -> logic    [27:0]  entry20_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 221 | `entry20_ppn[15:13] -> logic    [27:0]  entry20_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 221 | `entry20_ppn[19:18] -> logic    [27:0]  entry20_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 221 | `entry20_ppn[27:20] -> logic    [27:0]  entry20_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 226 | `entry21_flg[3:0] -> logic    [13:0]  entry21_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 226 | `entry21_flg[4] -> logic    [13:0]  entry21_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 226 | `entry21_flg[6:5] -> logic    [13:0]  entry21_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 226 | `entry21_flg[8:7] -> logic    [13:0]  entry21_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 226 | `entry21_flg[10:9] -> logic    [13:0]  entry21_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 228 | `entry21_pgs[0] -> logic    [2 :0]  entry21_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 228 | `entry21_pgs[2:1] -> logic    [2 :0]  entry21_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 229 | `entry21_ppn[1:0] -> logic    [27:0]  entry21_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 229 | `entry21_ppn[9] -> logic    [27:0]  entry21_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 229 | `entry21_ppn[11:10] -> logic    [27:0]  entry21_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 229 | `entry21_ppn[15:13] -> logic    [27:0]  entry21_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 229 | `entry21_ppn[19:18] -> logic    [27:0]  entry21_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 229 | `entry21_ppn[27:20] -> logic    [27:0]  entry21_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `entry22_flg[3:0] -> logic    [13:0]  entry22_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `entry22_flg[4] -> logic    [13:0]  entry22_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `entry22_flg[6:5] -> logic    [13:0]  entry22_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 234 | `entry22_flg[8:7] -> logic    [13:0]  entry22_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 234 | `entry22_flg[10:9] -> logic    [13:0]  entry22_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 236 | `entry22_pgs[0] -> logic    [2 :0]  entry22_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 236 | `entry22_pgs[2:1] -> logic    [2 :0]  entry22_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 237 | `entry22_ppn[9] -> logic    [27:0]  entry22_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 237 | `entry22_ppn[11:10] -> logic    [27:0]  entry22_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 237 | `entry22_ppn[15:13] -> logic    [27:0]  entry22_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 237 | `entry22_ppn[19:18] -> logic    [27:0]  entry22_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 237 | `entry22_ppn[27:20] -> logic    [27:0]  entry22_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 242 | `entry23_flg[3:0] -> logic    [13:0]  entry23_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 242 | `entry23_flg[4] -> logic    [13:0]  entry23_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 242 | `entry23_flg[6:5] -> logic    [13:0]  entry23_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 242 | `entry23_flg[8:7] -> logic    [13:0]  entry23_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 242 | `entry23_flg[10:9] -> logic    [13:0]  entry23_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 244 | `entry23_pgs[0] -> logic    [2 :0]  entry23_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 244 | `entry23_pgs[2:1] -> logic    [2 :0]  entry23_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 245 | `entry23_ppn[1:0] -> logic    [27:0]  entry23_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 245 | `entry23_ppn[9] -> logic    [27:0]  entry23_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 245 | `entry23_ppn[11:10] -> logic    [27:0]  entry23_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 245 | `entry23_ppn[15:13] -> logic    [27:0]  entry23_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 245 | `entry23_ppn[19:18] -> logic    [27:0]  entry23_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 245 | `entry23_ppn[27:20] -> logic    [27:0]  entry23_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 250 | `entry24_flg[3:0] -> logic    [13:0]  entry24_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 250 | `entry24_flg[4] -> logic    [13:0]  entry24_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 250 | `entry24_flg[6:5] -> logic    [13:0]  entry24_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 250 | `entry24_flg[8:7] -> logic    [13:0]  entry24_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 250 | `entry24_flg[10:9] -> logic    [13:0]  entry24_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 252 | `entry24_pgs[2] -> logic    [2 :0]  entry24_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 253 | `entry24_ppn[11:10] -> logic    [27:0]  entry24_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 253 | `entry24_ppn[15] -> logic    [27:0]  entry24_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 253 | `entry24_ppn[19:18] -> logic    [27:0]  entry24_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 253 | `entry24_ppn[23:20] -> logic    [27:0]  entry24_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 253 | `entry24_ppn[27:25] -> logic    [27:0]  entry24_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 258 | `entry24_vpn[26:25] -> logic    [26:0]  entry24_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 259 | `entry25_flg[3:0] -> logic    [13:0]  entry25_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 259 | `entry25_flg[4] -> logic    [13:0]  entry25_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 259 | `entry25_flg[6:5] -> logic    [13:0]  entry25_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 259 | `entry25_flg[8:7] -> logic    [13:0]  entry25_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 259 | `entry25_flg[10:9] -> logic    [13:0]  entry25_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 261 | `entry25_pgs[0] -> logic    [2 :0]  entry25_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 261 | `entry25_pgs[2:1] -> logic    [2 :0]  entry25_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 262 | `entry25_ppn[1:0] -> logic    [27:0]  entry25_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 262 | `entry25_ppn[9] -> logic    [27:0]  entry25_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 262 | `entry25_ppn[11:10] -> logic    [27:0]  entry25_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 262 | `entry25_ppn[15:13] -> logic    [27:0]  entry25_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 262 | `entry25_ppn[19:18] -> logic    [27:0]  entry25_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 262 | `entry25_ppn[27:20] -> logic    [27:0]  entry25_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 267 | `entry26_flg[3:0] -> logic    [13:0]  entry26_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 267 | `entry26_flg[4] -> logic    [13:0]  entry26_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 267 | `entry26_flg[6:5] -> logic    [13:0]  entry26_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 267 | `entry26_flg[8:7] -> logic    [13:0]  entry26_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 267 | `entry26_flg[10:9] -> logic    [13:0]  entry26_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 269 | `entry26_pgs[0] -> logic    [2 :0]  entry26_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 269 | `entry26_pgs[2:1] -> logic    [2 :0]  entry26_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 270 | `entry26_ppn[9] -> logic    [27:0]  entry26_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 270 | `entry26_ppn[11:10] -> logic    [27:0]  entry26_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 270 | `entry26_ppn[15:13] -> logic    [27:0]  entry26_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 270 | `entry26_ppn[19:18] -> logic    [27:0]  entry26_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 270 | `entry26_ppn[27:20] -> logic    [27:0]  entry26_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 275 | `entry27_flg[3:0] -> logic    [13:0]  entry27_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 275 | `entry27_flg[4] -> logic    [13:0]  entry27_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 275 | `entry27_flg[6:5] -> logic    [13:0]  entry27_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 275 | `entry27_flg[8:7] -> logic    [13:0]  entry27_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 275 | `entry27_flg[10:9] -> logic    [13:0]  entry27_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 277 | `entry27_pgs[0] -> logic    [2 :0]  entry27_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 277 | `entry27_pgs[2:1] -> logic    [2 :0]  entry27_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 278 | `entry27_ppn[1:0] -> logic    [27:0]  entry27_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 278 | `entry27_ppn[9] -> logic    [27:0]  entry27_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 278 | `entry27_ppn[11:10] -> logic    [27:0]  entry27_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 278 | `entry27_ppn[15:13] -> logic    [27:0]  entry27_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 278 | `entry27_ppn[19:18] -> logic    [27:0]  entry27_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 278 | `entry27_ppn[27:20] -> logic    [27:0]  entry27_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 283 | `entry28_flg[3:0] -> logic    [13:0]  entry28_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 283 | `entry28_flg[4] -> logic    [13:0]  entry28_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 283 | `entry28_flg[6:5] -> logic    [13:0]  entry28_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 283 | `entry28_flg[8:7] -> logic    [13:0]  entry28_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 283 | `entry28_flg[10:9] -> logic    [13:0]  entry28_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 285 | `entry28_pgs[0] -> logic    [2 :0]  entry28_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 285 | `entry28_pgs[2:1] -> logic    [2 :0]  entry28_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 286 | `entry28_ppn[9] -> logic    [27:0]  entry28_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 286 | `entry28_ppn[11:10] -> logic    [27:0]  entry28_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 286 | `entry28_ppn[15:13] -> logic    [27:0]  entry28_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 286 | `entry28_ppn[19:18] -> logic    [27:0]  entry28_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 286 | `entry28_ppn[27:20] -> logic    [27:0]  entry28_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `entry29_flg[3:0] -> logic    [13:0]  entry29_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 291 | `entry29_flg[4] -> logic    [13:0]  entry29_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `entry29_flg[6:5] -> logic    [13:0]  entry29_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 291 | `entry29_flg[8:7] -> logic    [13:0]  entry29_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `entry29_flg[10:9] -> logic    [13:0]  entry29_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 293 | `entry29_pgs[0] -> logic    [2 :0]  entry29_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 293 | `entry29_pgs[2:1] -> logic    [2 :0]  entry29_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 294 | `entry29_ppn[1:0] -> logic    [27:0]  entry29_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 294 | `entry29_ppn[9] -> logic    [27:0]  entry29_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 294 | `entry29_ppn[11:10] -> logic    [27:0]  entry29_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 294 | `entry29_ppn[15:13] -> logic    [27:0]  entry29_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 294 | `entry29_ppn[19:18] -> logic    [27:0]  entry29_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 294 | `entry29_ppn[27:20] -> logic    [27:0]  entry29_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 299 | `entry2_flg[4] -> logic    [13:0]  entry2_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 299 | `entry2_flg[8:7] -> logic    [13:0]  entry2_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 301 | `entry2_pgs[2] -> logic    [2 :0]  entry2_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `entry2_ppn[23:20] -> logic    [27:0]  entry2_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 302 | `entry2_ppn[27:25] -> logic    [27:0]  entry2_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 307 | `entry30_flg[3:0] -> logic    [13:0]  entry30_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 307 | `entry30_flg[4] -> logic    [13:0]  entry30_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 307 | `entry30_flg[6:5] -> logic    [13:0]  entry30_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 307 | `entry30_flg[8:7] -> logic    [13:0]  entry30_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 307 | `entry30_flg[10:9] -> logic    [13:0]  entry30_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 309 | `entry30_pgs[0] -> logic    [2 :0]  entry30_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 309 | `entry30_pgs[2:1] -> logic    [2 :0]  entry30_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 310 | `entry30_ppn[9] -> logic    [27:0]  entry30_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 310 | `entry30_ppn[11:10] -> logic    [27:0]  entry30_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 310 | `entry30_ppn[15:13] -> logic    [27:0]  entry30_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 310 | `entry30_ppn[19:18] -> logic    [27:0]  entry30_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 310 | `entry30_ppn[27:20] -> logic    [27:0]  entry30_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 315 | `entry31_flg[3:0] -> logic    [13:0]  entry31_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 315 | `entry31_flg[4] -> logic    [13:0]  entry31_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 315 | `entry31_flg[6:5] -> logic    [13:0]  entry31_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 315 | `entry31_flg[8:7] -> logic    [13:0]  entry31_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 315 | `entry31_flg[10:9] -> logic    [13:0]  entry31_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `entry31_pgs[0] -> logic    [2 :0]  entry31_pgs;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 317 | `entry31_pgs[2:1] -> logic    [2 :0]  entry31_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 318 | `entry31_ppn[1:0] -> logic    [27:0]  entry31_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 318 | `entry31_ppn[9] -> logic    [27:0]  entry31_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 318 | `entry31_ppn[11:10] -> logic    [27:0]  entry31_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 318 | `entry31_ppn[15:13] -> logic    [27:0]  entry31_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 318 | `entry31_ppn[19:18] -> logic    [27:0]  entry31_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 318 | `entry31_ppn[27:20] -> logic    [27:0]  entry31_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 323 | `entry3_flg[4] -> logic    [13:0]  entry3_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 323 | `entry3_flg[8:7] -> logic    [13:0]  entry3_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 325 | `entry3_pgs[2] -> logic    [2 :0]  entry3_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 326 | `entry3_ppn[10] -> logic    [27:0]  entry3_ppn;` | Toggle=No, 1->0=No, 0->1=No | 3 |
| 326 | `entry3_ppn[19:18] -> logic    [27:0]  entry3_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 326 | `entry3_ppn[23:20] -> logic    [27:0]  entry3_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 326 | `entry3_ppn[27:25] -> logic    [27:0]  entry3_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 331 | `entry4_flg[4] -> logic    [13:0]  entry4_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 331 | `entry4_flg[8:7] -> logic    [13:0]  entry4_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 333 | `entry4_pgs[2] -> logic    [2 :0]  entry4_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 334 | `entry4_ppn[13] -> logic    [27:0]  entry4_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 334 | `entry4_ppn[19:18] -> logic    [27:0]  entry4_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 334 | `entry4_ppn[23:20] -> logic    [27:0]  entry4_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 334 | `entry4_ppn[27:25] -> logic    [27:0]  entry4_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 339 | `entry5_flg[4] -> logic    [13:0]  entry5_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 339 | `entry5_flg[8:7] -> logic    [13:0]  entry5_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 341 | `entry5_pgs[2] -> logic    [2 :0]  entry5_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 342 | `entry5_ppn[11:10] -> logic    [27:0]  entry5_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 342 | `entry5_ppn[15] -> logic    [27:0]  entry5_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 342 | `entry5_ppn[19:18] -> logic    [27:0]  entry5_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 342 | `entry5_ppn[23:20] -> logic    [27:0]  entry5_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 342 | `entry5_ppn[27:25] -> logic    [27:0]  entry5_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 347 | `entry6_flg[4] -> logic    [13:0]  entry6_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 347 | `entry6_flg[8:7] -> logic    [13:0]  entry6_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 349 | `entry6_pgs[2] -> logic    [2 :0]  entry6_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 350 | `entry6_ppn[11] -> logic    [27:0]  entry6_ppn;` | Toggle=No, 1->0=No, 0->1=No | 3 |
| 350 | `entry6_ppn[19:18] -> logic    [27:0]  entry6_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 350 | `entry6_ppn[23:20] -> logic    [27:0]  entry6_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 350 | `entry6_ppn[27:25] -> logic    [27:0]  entry6_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 355 | `entry7_flg[4] -> logic    [13:0]  entry7_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 355 | `entry7_flg[8:7] -> logic    [13:0]  entry7_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 357 | `entry7_pgs[2] -> logic    [2 :0]  entry7_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 358 | `entry7_ppn[10] -> logic    [27:0]  entry7_ppn;` | Toggle=No, 1->0=No, 0->1=No | 3 |
| 358 | `entry7_ppn[19:18] -> logic    [27:0]  entry7_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 358 | `entry7_ppn[23:20] -> logic    [27:0]  entry7_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 358 | `entry7_ppn[27:25] -> logic    [27:0]  entry7_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 363 | `entry8_flg[3:0] -> logic    [13:0]  entry8_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 363 | `entry8_flg[4] -> logic    [13:0]  entry8_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 363 | `entry8_flg[6:5] -> logic    [13:0]  entry8_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 363 | `entry8_flg[8:7] -> logic    [13:0]  entry8_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 363 | `entry8_flg[10:9] -> logic    [13:0]  entry8_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 365 | `entry8_pgs[2] -> logic    [2 :0]  entry8_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 366 | `entry8_ppn[10] -> logic    [27:0]  entry8_ppn;` | Toggle=No, 1->0=No, 0->1=No | 3 |
| 366 | `entry8_ppn[19:18] -> logic    [27:0]  entry8_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 366 | `entry8_ppn[23:20] -> logic    [27:0]  entry8_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 366 | `entry8_ppn[27:25] -> logic    [27:0]  entry8_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 371 | `entry8_vpn[26] -> logic    [26:0]  entry8_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 372 | `entry9_flg[4] -> logic    [13:0]  entry9_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 372 | `entry9_flg[8:7] -> logic    [13:0]  entry9_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 374 | `entry9_pgs[2] -> logic    [2 :0]  entry9_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 375 | `entry9_ppn[13] -> logic    [27:0]  entry9_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 375 | `entry9_ppn[19:18] -> logic    [27:0]  entry9_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 375 | `entry9_ppn[23:20] -> logic    [27:0]  entry9_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 375 | `entry9_ppn[27:25] -> logic    [27:0]  entry9_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 382 | `flg_fin[4] -> logic    [13:0]  flg_fin;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 389 | `iutlb_bypass_vld -> logic            iutlb_bypass_vld;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 392 | `iutlb_disable_vld -> logic            iutlb_disable_vld;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 394 | `iutlb_flg_aft_bypass[4] -> logic    [13:0]  iutlb_flg_aft_bypass;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 395 | `iutlb_hit_flg_fst[4] -> logic    [13:0]  iutlb_hit_flg_fst;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 396 | `iutlb_hit_flg_scd[4] -> logic    [13:0]  iutlb_hit_flg_scd;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 396 | `iutlb_hit_flg_scd[8:7] -> logic    [13:0]  iutlb_hit_flg_scd;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 397 | `iutlb_hit_pa_fst[23:20] -> logic    [27:0]  iutlb_hit_pa_fst;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 397 | `iutlb_hit_pa_fst[27:25] -> logic    [27:0]  iutlb_hit_pa_fst;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 398 | `iutlb_hit_pa_scd[23:20] -> logic    [27:0]  iutlb_hit_pa_scd;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 398 | `iutlb_hit_pa_scd[27:25] -> logic    [27:0]  iutlb_hit_pa_scd;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 404 | `iutlb_off_flg[9:0] -> logic    [13:0]  iutlb_off_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 407 | `iutlb_off_pgs[2:0] -> logic    [2 :0]  iutlb_off_pgs;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 408 | `iutlb_pa_aft_bypass[23:20] -> logic    [27:0]  iutlb_pa_aft_bypass;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 408 | `iutlb_pa_aft_bypass[27:25] -> logic    [27:0]  iutlb_pa_aft_bypass;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 422 | `pa_fin[23:20] -> logic    [27:0]  pa_fin;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 422 | `pa_fin[27:25] -> logic    [27:0]  pa_fin;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 428 | `utlb_fst_swp_flg[4] -> logic    [13:0]  utlb_fst_swp_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 428 | `utlb_fst_swp_flg[8:7] -> logic    [13:0]  utlb_fst_swp_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 430 | `utlb_fst_swp_ppn[23:20] -> logic    [27:0]  utlb_fst_swp_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 430 | `utlb_fst_swp_ppn[27:25] -> logic    [27:0]  utlb_fst_swp_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 433 | `utlb_swp_flg[4] -> logic    [13:0]  utlb_swp_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 433 | `utlb_swp_flg[8:7] -> logic    [13:0]  utlb_swp_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 436 | `utlb_swp_ppn[23:20] -> logic    [27:0]  utlb_swp_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 436 | `utlb_swp_ppn[27:25] -> logic    [27:0]  utlb_swp_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 437 | `utlb_swp_vpn[26] -> logic    [26:0]  utlb_swp_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 438 | `utlb_upd_flg[4] -> logic    [13:0]  utlb_upd_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 440 | `utlb_upd_ppn[23:20] -> logic    [27:0]  utlb_upd_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 440 | `utlb_upd_ppn[27:25] -> logic    [27:0]  utlb_upd_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 441 | `utlb_upd_vpn[26] -> logic    [26:0]  utlb_upd_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l1itlb.sv:110` (声明 `iutlb_pa_buf`)

```systemverilog
       107:     
       108:     logic     [3 :0]  iutlb_fst_wen;          
       109:     logic             iutlb_miss;             
       110: >>  logic     [27:0]  iutlb_pa_buf;           
       111:     logic     [31:0]  iutlb_plru_read_hit;    
       112:     logic             jtlb_acc_fault_flop;    
       113:     logic             pmp_flg_vld;            
```

`mmu/rtl/mmu_l1itlb.sv:120` (声明 `entry0_flg`)

```systemverilog
       117:     logic            cp0_mach_mode;          
       118:     logic            cp0_supv_mode;          
       119:     logic            cp0_user_mode;          
       120: >>  logic    [13:0]  entry0_flg;             
       121:     logic            entry0_hit;             
       122:     logic    [2 :0]  entry0_pgs;             
       123:     logic    [27:0]  entry0_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:123` (声明 `entry0_ppn`)

```systemverilog
       120:     logic    [13:0]  entry0_flg;             
       121:     logic            entry0_hit;             
       122:     logic    [2 :0]  entry0_pgs;             
       123: >>  logic    [27:0]  entry0_ppn;             
       124:     logic            entry0_swp;             
       125:     logic            entry0_swp_on;          
       126:     logic            entry0_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:128` (声明 `entry0_vpn`)

```systemverilog
       125:     logic            entry0_swp_on;          
       126:     logic            entry0_upd;             
       127:     logic            entry0_vld;             
       128: >>  logic    [26:0]  entry0_vpn;             
       129:     logic    [13:0]  entry10_flg;            
       130:     logic            entry10_hit;            
       131:     logic    [2 :0]  entry10_pgs;            
```

`mmu/rtl/mmu_l1itlb.sv:129` (声明 `entry10_flg`)

```systemverilog
       126:     logic            entry0_upd;             
       127:     logic            entry0_vld;             
       128:     logic    [26:0]  entry0_vpn;             
       129: >>  logic    [13:0]  entry10_flg;            
       130:     logic            entry10_hit;            
       131:     logic    [2 :0]  entry10_pgs;            
       132:     logic    [27:0]  entry10_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:131` (声明 `entry10_pgs`)

```systemverilog
       128:     logic    [26:0]  entry0_vpn;             
       129:     logic    [13:0]  entry10_flg;            
       130:     logic            entry10_hit;            
       131: >>  logic    [2 :0]  entry10_pgs;            
       132:     logic    [27:0]  entry10_ppn;            
       133:     logic            entry10_swp;            
       134:     logic            entry10_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:132` (声明 `entry10_ppn`)

```systemverilog
       129:     logic    [13:0]  entry10_flg;            
       130:     logic            entry10_hit;            
       131:     logic    [2 :0]  entry10_pgs;            
       132: >>  logic    [27:0]  entry10_ppn;            
       133:     logic            entry10_swp;            
       134:     logic            entry10_swp_on;         
       135:     logic            entry10_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:137` (声明 `entry11_flg`)

```systemverilog
       134:     logic            entry10_swp_on;         
       135:     logic            entry10_upd;            
       136:     logic            entry10_vld;            
       137: >>  logic    [13:0]  entry11_flg;            
       138:     logic            entry11_hit;            
       139:     logic    [2 :0]  entry11_pgs;            
       140:     logic    [27:0]  entry11_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:139` (声明 `entry11_pgs`)

```systemverilog
       136:     logic            entry10_vld;            
       137:     logic    [13:0]  entry11_flg;            
       138:     logic            entry11_hit;            
       139: >>  logic    [2 :0]  entry11_pgs;            
       140:     logic    [27:0]  entry11_ppn;            
       141:     logic            entry11_swp;            
       142:     logic            entry11_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:140` (声明 `entry11_ppn`)

```systemverilog
       137:     logic    [13:0]  entry11_flg;            
       138:     logic            entry11_hit;            
       139:     logic    [2 :0]  entry11_pgs;            
       140: >>  logic    [27:0]  entry11_ppn;            
       141:     logic            entry11_swp;            
       142:     logic            entry11_swp_on;         
       143:     logic            entry11_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:145` (声明 `entry12_flg`)

```systemverilog
       142:     logic            entry11_swp_on;         
       143:     logic            entry11_upd;            
       144:     logic            entry11_vld;            
       145: >>  logic    [13:0]  entry12_flg;            
       146:     logic            entry12_hit;            
       147:     logic    [2 :0]  entry12_pgs;            
       148:     logic    [27:0]  entry12_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:147` (声明 `entry12_pgs`)

```systemverilog
       144:     logic            entry11_vld;            
       145:     logic    [13:0]  entry12_flg;            
       146:     logic            entry12_hit;            
       147: >>  logic    [2 :0]  entry12_pgs;            
       148:     logic    [27:0]  entry12_ppn;            
       149:     logic            entry12_swp;            
       150:     logic            entry12_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:148` (声明 `entry12_ppn`)

```systemverilog
       145:     logic    [13:0]  entry12_flg;            
       146:     logic            entry12_hit;            
       147:     logic    [2 :0]  entry12_pgs;            
       148: >>  logic    [27:0]  entry12_ppn;            
       149:     logic            entry12_swp;            
       150:     logic            entry12_swp_on;         
       151:     logic            entry12_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:153` (声明 `entry13_flg`)

```systemverilog
       150:     logic            entry12_swp_on;         
       151:     logic            entry12_upd;            
       152:     logic            entry12_vld;            
       153: >>  logic    [13:0]  entry13_flg;            
       154:     logic            entry13_hit;            
       155:     logic    [2 :0]  entry13_pgs;            
       156:     logic    [27:0]  entry13_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:155` (声明 `entry13_pgs`)

```systemverilog
       152:     logic            entry12_vld;            
       153:     logic    [13:0]  entry13_flg;            
       154:     logic            entry13_hit;            
       155: >>  logic    [2 :0]  entry13_pgs;            
       156:     logic    [27:0]  entry13_ppn;            
       157:     logic            entry13_swp;            
       158:     logic            entry13_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:156` (声明 `entry13_ppn`)

```systemverilog
       153:     logic    [13:0]  entry13_flg;            
       154:     logic            entry13_hit;            
       155:     logic    [2 :0]  entry13_pgs;            
       156: >>  logic    [27:0]  entry13_ppn;            
       157:     logic            entry13_swp;            
       158:     logic            entry13_swp_on;         
       159:     logic            entry13_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:161` (声明 `entry14_flg`)

```systemverilog
       158:     logic            entry13_swp_on;         
       159:     logic            entry13_upd;            
       160:     logic            entry13_vld;            
       161: >>  logic    [13:0]  entry14_flg;            
       162:     logic            entry14_hit;            
       163:     logic    [2 :0]  entry14_pgs;            
       164:     logic    [27:0]  entry14_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:163` (声明 `entry14_pgs`)

```systemverilog
       160:     logic            entry13_vld;            
       161:     logic    [13:0]  entry14_flg;            
       162:     logic            entry14_hit;            
       163: >>  logic    [2 :0]  entry14_pgs;            
       164:     logic    [27:0]  entry14_ppn;            
       165:     logic            entry14_swp;            
       166:     logic            entry14_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:164` (声明 `entry14_ppn`)

```systemverilog
       161:     logic    [13:0]  entry14_flg;            
       162:     logic            entry14_hit;            
       163:     logic    [2 :0]  entry14_pgs;            
       164: >>  logic    [27:0]  entry14_ppn;            
       165:     logic            entry14_swp;            
       166:     logic            entry14_swp_on;         
       167:     logic            entry14_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:169` (声明 `entry15_flg`)

```systemverilog
       166:     logic            entry14_swp_on;         
       167:     logic            entry14_upd;            
       168:     logic            entry14_vld;            
       169: >>  logic    [13:0]  entry15_flg;            
       170:     logic            entry15_hit;            
       171:     logic    [2 :0]  entry15_pgs;            
       172:     logic    [27:0]  entry15_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:171` (声明 `entry15_pgs`)

```systemverilog
       168:     logic            entry14_vld;            
       169:     logic    [13:0]  entry15_flg;            
       170:     logic            entry15_hit;            
       171: >>  logic    [2 :0]  entry15_pgs;            
       172:     logic    [27:0]  entry15_ppn;            
       173:     logic            entry15_swp;            
       174:     logic            entry15_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:172` (声明 `entry15_ppn`)

```systemverilog
       169:     logic    [13:0]  entry15_flg;            
       170:     logic            entry15_hit;            
       171:     logic    [2 :0]  entry15_pgs;            
       172: >>  logic    [27:0]  entry15_ppn;            
       173:     logic            entry15_swp;            
       174:     logic            entry15_swp_on;         
       175:     logic            entry15_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:177` (声明 `entry16_flg`)

```systemverilog
       174:     logic            entry15_swp_on;         
       175:     logic            entry15_upd;            
       176:     logic            entry15_vld;            
       177: >>  logic    [13:0]  entry16_flg;            
       178:     logic            entry16_hit;            
       179:     logic    [2 :0]  entry16_pgs;            
       180:     logic    [27:0]  entry16_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:179` (声明 `entry16_pgs`)

```systemverilog
       176:     logic            entry15_vld;            
       177:     logic    [13:0]  entry16_flg;            
       178:     logic            entry16_hit;            
       179: >>  logic    [2 :0]  entry16_pgs;            
       180:     logic    [27:0]  entry16_ppn;            
       181:     logic            entry16_swp;            
       182:     logic            entry16_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:180` (声明 `entry16_ppn`)

```systemverilog
       177:     logic    [13:0]  entry16_flg;            
       178:     logic            entry16_hit;            
       179:     logic    [2 :0]  entry16_pgs;            
       180: >>  logic    [27:0]  entry16_ppn;            
       181:     logic            entry16_swp;            
       182:     logic            entry16_swp_on;         
       183:     logic            entry16_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:185` (声明 `entry16_vpn`)

```systemverilog
       182:     logic            entry16_swp_on;         
       183:     logic            entry16_upd;            
       184:     logic            entry16_vld;            
       185: >>  logic    [26:0]  entry16_vpn;            
       186:     logic    [13:0]  entry17_flg;            
       187:     logic            entry17_hit;            
       188:     logic    [2 :0]  entry17_pgs;            
```

`mmu/rtl/mmu_l1itlb.sv:186` (声明 `entry17_flg`)

```systemverilog
       183:     logic            entry16_upd;            
       184:     logic            entry16_vld;            
       185:     logic    [26:0]  entry16_vpn;            
       186: >>  logic    [13:0]  entry17_flg;            
       187:     logic            entry17_hit;            
       188:     logic    [2 :0]  entry17_pgs;            
       189:     logic    [27:0]  entry17_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:188` (声明 `entry17_pgs`)

```systemverilog
       185:     logic    [26:0]  entry16_vpn;            
       186:     logic    [13:0]  entry17_flg;            
       187:     logic            entry17_hit;            
       188: >>  logic    [2 :0]  entry17_pgs;            
       189:     logic    [27:0]  entry17_ppn;            
       190:     logic            entry17_swp;            
       191:     logic            entry17_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:189` (声明 `entry17_ppn`)

```systemverilog
       186:     logic    [13:0]  entry17_flg;            
       187:     logic            entry17_hit;            
       188:     logic    [2 :0]  entry17_pgs;            
       189: >>  logic    [27:0]  entry17_ppn;            
       190:     logic            entry17_swp;            
       191:     logic            entry17_swp_on;         
       192:     logic            entry17_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:194` (声明 `entry18_flg`)

```systemverilog
       191:     logic            entry17_swp_on;         
       192:     logic            entry17_upd;            
       193:     logic            entry17_vld;            
       194: >>  logic    [13:0]  entry18_flg;            
       195:     logic            entry18_hit;            
       196:     logic    [2 :0]  entry18_pgs;            
       197:     logic    [27:0]  entry18_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:196` (声明 `entry18_pgs`)

```systemverilog
       193:     logic            entry17_vld;            
       194:     logic    [13:0]  entry18_flg;            
       195:     logic            entry18_hit;            
       196: >>  logic    [2 :0]  entry18_pgs;            
       197:     logic    [27:0]  entry18_ppn;            
       198:     logic            entry18_swp;            
       199:     logic            entry18_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:197` (声明 `entry18_ppn`)

```systemverilog
       194:     logic    [13:0]  entry18_flg;            
       195:     logic            entry18_hit;            
       196:     logic    [2 :0]  entry18_pgs;            
       197: >>  logic    [27:0]  entry18_ppn;            
       198:     logic            entry18_swp;            
       199:     logic            entry18_swp_on;         
       200:     logic            entry18_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:202` (声明 `entry19_flg`)

```systemverilog
       199:     logic            entry18_swp_on;         
       200:     logic            entry18_upd;            
       201:     logic            entry18_vld;            
       202: >>  logic    [13:0]  entry19_flg;            
       203:     logic            entry19_hit;            
       204:     logic    [2 :0]  entry19_pgs;            
       205:     logic    [27:0]  entry19_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:204` (声明 `entry19_pgs`)

```systemverilog
       201:     logic            entry18_vld;            
       202:     logic    [13:0]  entry19_flg;            
       203:     logic            entry19_hit;            
       204: >>  logic    [2 :0]  entry19_pgs;            
       205:     logic    [27:0]  entry19_ppn;            
       206:     logic            entry19_swp;            
       207:     logic            entry19_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:205` (声明 `entry19_ppn`)

```systemverilog
       202:     logic    [13:0]  entry19_flg;            
       203:     logic            entry19_hit;            
       204:     logic    [2 :0]  entry19_pgs;            
       205: >>  logic    [27:0]  entry19_ppn;            
       206:     logic            entry19_swp;            
       207:     logic            entry19_swp_on;         
       208:     logic            entry19_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:210` (声明 `entry1_flg`)

```systemverilog
       207:     logic            entry19_swp_on;         
       208:     logic            entry19_upd;            
       209:     logic            entry19_vld;            
       210: >>  logic    [13:0]  entry1_flg;             
       211:     logic            entry1_hit;             
       212:     logic    [2 :0]  entry1_pgs;             
       213:     logic    [27:0]  entry1_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:212` (声明 `entry1_pgs`)

```systemverilog
       209:     logic            entry19_vld;            
       210:     logic    [13:0]  entry1_flg;             
       211:     logic            entry1_hit;             
       212: >>  logic    [2 :0]  entry1_pgs;             
       213:     logic    [27:0]  entry1_ppn;             
       214:     logic            entry1_swp;             
       215:     logic            entry1_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:213` (声明 `entry1_ppn`)

```systemverilog
       210:     logic    [13:0]  entry1_flg;             
       211:     logic            entry1_hit;             
       212:     logic    [2 :0]  entry1_pgs;             
       213: >>  logic    [27:0]  entry1_ppn;             
       214:     logic            entry1_swp;             
       215:     logic            entry1_swp_on;          
       216:     logic            entry1_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:218` (声明 `entry20_flg`)

```systemverilog
       215:     logic            entry1_swp_on;          
       216:     logic            entry1_upd;             
       217:     logic            entry1_vld;             
       218: >>  logic    [13:0]  entry20_flg;            
       219:     logic            entry20_hit;            
       220:     logic    [2 :0]  entry20_pgs;            
       221:     logic    [27:0]  entry20_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:220` (声明 `entry20_pgs`)

```systemverilog
       217:     logic            entry1_vld;             
       218:     logic    [13:0]  entry20_flg;            
       219:     logic            entry20_hit;            
       220: >>  logic    [2 :0]  entry20_pgs;            
       221:     logic    [27:0]  entry20_ppn;            
       222:     logic            entry20_swp;            
       223:     logic            entry20_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:221` (声明 `entry20_ppn`)

```systemverilog
       218:     logic    [13:0]  entry20_flg;            
       219:     logic            entry20_hit;            
       220:     logic    [2 :0]  entry20_pgs;            
       221: >>  logic    [27:0]  entry20_ppn;            
       222:     logic            entry20_swp;            
       223:     logic            entry20_swp_on;         
       224:     logic            entry20_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:226` (声明 `entry21_flg`)

```systemverilog
       223:     logic            entry20_swp_on;         
       224:     logic            entry20_upd;            
       225:     logic            entry20_vld;            
       226: >>  logic    [13:0]  entry21_flg;            
       227:     logic            entry21_hit;            
       228:     logic    [2 :0]  entry21_pgs;            
       229:     logic    [27:0]  entry21_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:228` (声明 `entry21_pgs`)

```systemverilog
       225:     logic            entry20_vld;            
       226:     logic    [13:0]  entry21_flg;            
       227:     logic            entry21_hit;            
       228: >>  logic    [2 :0]  entry21_pgs;            
       229:     logic    [27:0]  entry21_ppn;            
       230:     logic            entry21_swp;            
       231:     logic            entry21_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:229` (声明 `entry21_ppn`)

```systemverilog
       226:     logic    [13:0]  entry21_flg;            
       227:     logic            entry21_hit;            
       228:     logic    [2 :0]  entry21_pgs;            
       229: >>  logic    [27:0]  entry21_ppn;            
       230:     logic            entry21_swp;            
       231:     logic            entry21_swp_on;         
       232:     logic            entry21_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:234` (声明 `entry22_flg`)

```systemverilog
       231:     logic            entry21_swp_on;         
       232:     logic            entry21_upd;            
       233:     logic            entry21_vld;            
       234: >>  logic    [13:0]  entry22_flg;            
       235:     logic            entry22_hit;            
       236:     logic    [2 :0]  entry22_pgs;            
       237:     logic    [27:0]  entry22_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:236` (声明 `entry22_pgs`)

```systemverilog
       233:     logic            entry21_vld;            
       234:     logic    [13:0]  entry22_flg;            
       235:     logic            entry22_hit;            
       236: >>  logic    [2 :0]  entry22_pgs;            
       237:     logic    [27:0]  entry22_ppn;            
       238:     logic            entry22_swp;            
       239:     logic            entry22_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:237` (声明 `entry22_ppn`)

```systemverilog
       234:     logic    [13:0]  entry22_flg;            
       235:     logic            entry22_hit;            
       236:     logic    [2 :0]  entry22_pgs;            
       237: >>  logic    [27:0]  entry22_ppn;            
       238:     logic            entry22_swp;            
       239:     logic            entry22_swp_on;         
       240:     logic            entry22_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:242` (声明 `entry23_flg`)

```systemverilog
       239:     logic            entry22_swp_on;         
       240:     logic            entry22_upd;            
       241:     logic            entry22_vld;            
       242: >>  logic    [13:0]  entry23_flg;            
       243:     logic            entry23_hit;            
       244:     logic    [2 :0]  entry23_pgs;            
       245:     logic    [27:0]  entry23_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:244` (声明 `entry23_pgs`)

```systemverilog
       241:     logic            entry22_vld;            
       242:     logic    [13:0]  entry23_flg;            
       243:     logic            entry23_hit;            
       244: >>  logic    [2 :0]  entry23_pgs;            
       245:     logic    [27:0]  entry23_ppn;            
       246:     logic            entry23_swp;            
       247:     logic            entry23_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:245` (声明 `entry23_ppn`)

```systemverilog
       242:     logic    [13:0]  entry23_flg;            
       243:     logic            entry23_hit;            
       244:     logic    [2 :0]  entry23_pgs;            
       245: >>  logic    [27:0]  entry23_ppn;            
       246:     logic            entry23_swp;            
       247:     logic            entry23_swp_on;         
       248:     logic            entry23_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:250` (声明 `entry24_flg`)

```systemverilog
       247:     logic            entry23_swp_on;         
       248:     logic            entry23_upd;            
       249:     logic            entry23_vld;            
       250: >>  logic    [13:0]  entry24_flg;            
       251:     logic            entry24_hit;            
       252:     logic    [2 :0]  entry24_pgs;            
       253:     logic    [27:0]  entry24_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:252` (声明 `entry24_pgs`)

```systemverilog
       249:     logic            entry23_vld;            
       250:     logic    [13:0]  entry24_flg;            
       251:     logic            entry24_hit;            
       252: >>  logic    [2 :0]  entry24_pgs;            
       253:     logic    [27:0]  entry24_ppn;            
       254:     logic            entry24_swp;            
       255:     logic            entry24_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:253` (声明 `entry24_ppn`)

```systemverilog
       250:     logic    [13:0]  entry24_flg;            
       251:     logic            entry24_hit;            
       252:     logic    [2 :0]  entry24_pgs;            
       253: >>  logic    [27:0]  entry24_ppn;            
       254:     logic            entry24_swp;            
       255:     logic            entry24_swp_on;         
       256:     logic            entry24_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:258` (声明 `entry24_vpn`)

```systemverilog
       255:     logic            entry24_swp_on;         
       256:     logic            entry24_upd;            
       257:     logic            entry24_vld;            
       258: >>  logic    [26:0]  entry24_vpn;            
       259:     logic    [13:0]  entry25_flg;            
       260:     logic            entry25_hit;            
       261:     logic    [2 :0]  entry25_pgs;            
```

`mmu/rtl/mmu_l1itlb.sv:259` (声明 `entry25_flg`)

```systemverilog
       256:     logic            entry24_upd;            
       257:     logic            entry24_vld;            
       258:     logic    [26:0]  entry24_vpn;            
       259: >>  logic    [13:0]  entry25_flg;            
       260:     logic            entry25_hit;            
       261:     logic    [2 :0]  entry25_pgs;            
       262:     logic    [27:0]  entry25_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:261` (声明 `entry25_pgs`)

```systemverilog
       258:     logic    [26:0]  entry24_vpn;            
       259:     logic    [13:0]  entry25_flg;            
       260:     logic            entry25_hit;            
       261: >>  logic    [2 :0]  entry25_pgs;            
       262:     logic    [27:0]  entry25_ppn;            
       263:     logic            entry25_swp;            
       264:     logic            entry25_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:262` (声明 `entry25_ppn`)

```systemverilog
       259:     logic    [13:0]  entry25_flg;            
       260:     logic            entry25_hit;            
       261:     logic    [2 :0]  entry25_pgs;            
       262: >>  logic    [27:0]  entry25_ppn;            
       263:     logic            entry25_swp;            
       264:     logic            entry25_swp_on;         
       265:     logic            entry25_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:267` (声明 `entry26_flg`)

```systemverilog
       264:     logic            entry25_swp_on;         
       265:     logic            entry25_upd;            
       266:     logic            entry25_vld;            
       267: >>  logic    [13:0]  entry26_flg;            
       268:     logic            entry26_hit;            
       269:     logic    [2 :0]  entry26_pgs;            
       270:     logic    [27:0]  entry26_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:269` (声明 `entry26_pgs`)

```systemverilog
       266:     logic            entry25_vld;            
       267:     logic    [13:0]  entry26_flg;            
       268:     logic            entry26_hit;            
       269: >>  logic    [2 :0]  entry26_pgs;            
       270:     logic    [27:0]  entry26_ppn;            
       271:     logic            entry26_swp;            
       272:     logic            entry26_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:270` (声明 `entry26_ppn`)

```systemverilog
       267:     logic    [13:0]  entry26_flg;            
       268:     logic            entry26_hit;            
       269:     logic    [2 :0]  entry26_pgs;            
       270: >>  logic    [27:0]  entry26_ppn;            
       271:     logic            entry26_swp;            
       272:     logic            entry26_swp_on;         
       273:     logic            entry26_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:275` (声明 `entry27_flg`)

```systemverilog
       272:     logic            entry26_swp_on;         
       273:     logic            entry26_upd;            
       274:     logic            entry26_vld;            
       275: >>  logic    [13:0]  entry27_flg;            
       276:     logic            entry27_hit;            
       277:     logic    [2 :0]  entry27_pgs;            
       278:     logic    [27:0]  entry27_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:277` (声明 `entry27_pgs`)

```systemverilog
       274:     logic            entry26_vld;            
       275:     logic    [13:0]  entry27_flg;            
       276:     logic            entry27_hit;            
       277: >>  logic    [2 :0]  entry27_pgs;            
       278:     logic    [27:0]  entry27_ppn;            
       279:     logic            entry27_swp;            
       280:     logic            entry27_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:278` (声明 `entry27_ppn`)

```systemverilog
       275:     logic    [13:0]  entry27_flg;            
       276:     logic            entry27_hit;            
       277:     logic    [2 :0]  entry27_pgs;            
       278: >>  logic    [27:0]  entry27_ppn;            
       279:     logic            entry27_swp;            
       280:     logic            entry27_swp_on;         
       281:     logic            entry27_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:283` (声明 `entry28_flg`)

```systemverilog
       280:     logic            entry27_swp_on;         
       281:     logic            entry27_upd;            
       282:     logic            entry27_vld;            
       283: >>  logic    [13:0]  entry28_flg;            
       284:     logic            entry28_hit;            
       285:     logic    [2 :0]  entry28_pgs;            
       286:     logic    [27:0]  entry28_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:285` (声明 `entry28_pgs`)

```systemverilog
       282:     logic            entry27_vld;            
       283:     logic    [13:0]  entry28_flg;            
       284:     logic            entry28_hit;            
       285: >>  logic    [2 :0]  entry28_pgs;            
       286:     logic    [27:0]  entry28_ppn;            
       287:     logic            entry28_swp;            
       288:     logic            entry28_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:286` (声明 `entry28_ppn`)

```systemverilog
       283:     logic    [13:0]  entry28_flg;            
       284:     logic            entry28_hit;            
       285:     logic    [2 :0]  entry28_pgs;            
       286: >>  logic    [27:0]  entry28_ppn;            
       287:     logic            entry28_swp;            
       288:     logic            entry28_swp_on;         
       289:     logic            entry28_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:291` (声明 `entry29_flg`)

```systemverilog
       288:     logic            entry28_swp_on;         
       289:     logic            entry28_upd;            
       290:     logic            entry28_vld;            
       291: >>  logic    [13:0]  entry29_flg;            
       292:     logic            entry29_hit;            
       293:     logic    [2 :0]  entry29_pgs;            
       294:     logic    [27:0]  entry29_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:293` (声明 `entry29_pgs`)

```systemverilog
       290:     logic            entry28_vld;            
       291:     logic    [13:0]  entry29_flg;            
       292:     logic            entry29_hit;            
       293: >>  logic    [2 :0]  entry29_pgs;            
       294:     logic    [27:0]  entry29_ppn;            
       295:     logic            entry29_swp;            
       296:     logic            entry29_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:294` (声明 `entry29_ppn`)

```systemverilog
       291:     logic    [13:0]  entry29_flg;            
       292:     logic            entry29_hit;            
       293:     logic    [2 :0]  entry29_pgs;            
       294: >>  logic    [27:0]  entry29_ppn;            
       295:     logic            entry29_swp;            
       296:     logic            entry29_swp_on;         
       297:     logic            entry29_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:299` (声明 `entry2_flg`)

```systemverilog
       296:     logic            entry29_swp_on;         
       297:     logic            entry29_upd;            
       298:     logic            entry29_vld;            
       299: >>  logic    [13:0]  entry2_flg;             
       300:     logic            entry2_hit;             
       301:     logic    [2 :0]  entry2_pgs;             
       302:     logic    [27:0]  entry2_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:301` (声明 `entry2_pgs`)

```systemverilog
       298:     logic            entry29_vld;            
       299:     logic    [13:0]  entry2_flg;             
       300:     logic            entry2_hit;             
       301: >>  logic    [2 :0]  entry2_pgs;             
       302:     logic    [27:0]  entry2_ppn;             
       303:     logic            entry2_swp;             
       304:     logic            entry2_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:302` (声明 `entry2_ppn`)

```systemverilog
       299:     logic    [13:0]  entry2_flg;             
       300:     logic            entry2_hit;             
       301:     logic    [2 :0]  entry2_pgs;             
       302: >>  logic    [27:0]  entry2_ppn;             
       303:     logic            entry2_swp;             
       304:     logic            entry2_swp_on;          
       305:     logic            entry2_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:307` (声明 `entry30_flg`)

```systemverilog
       304:     logic            entry2_swp_on;          
       305:     logic            entry2_upd;             
       306:     logic            entry2_vld;             
       307: >>  logic    [13:0]  entry30_flg;            
       308:     logic            entry30_hit;            
       309:     logic    [2 :0]  entry30_pgs;            
       310:     logic    [27:0]  entry30_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:309` (声明 `entry30_pgs`)

```systemverilog
       306:     logic            entry2_vld;             
       307:     logic    [13:0]  entry30_flg;            
       308:     logic            entry30_hit;            
       309: >>  logic    [2 :0]  entry30_pgs;            
       310:     logic    [27:0]  entry30_ppn;            
       311:     logic            entry30_swp;            
       312:     logic            entry30_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:310` (声明 `entry30_ppn`)

```systemverilog
       307:     logic    [13:0]  entry30_flg;            
       308:     logic            entry30_hit;            
       309:     logic    [2 :0]  entry30_pgs;            
       310: >>  logic    [27:0]  entry30_ppn;            
       311:     logic            entry30_swp;            
       312:     logic            entry30_swp_on;         
       313:     logic            entry30_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:315` (声明 `entry31_flg`)

```systemverilog
       312:     logic            entry30_swp_on;         
       313:     logic            entry30_upd;            
       314:     logic            entry30_vld;            
       315: >>  logic    [13:0]  entry31_flg;            
       316:     logic            entry31_hit;            
       317:     logic    [2 :0]  entry31_pgs;            
       318:     logic    [27:0]  entry31_ppn;            
```

`mmu/rtl/mmu_l1itlb.sv:317` (声明 `entry31_pgs`)

```systemverilog
       314:     logic            entry30_vld;            
       315:     logic    [13:0]  entry31_flg;            
       316:     logic            entry31_hit;            
       317: >>  logic    [2 :0]  entry31_pgs;            
       318:     logic    [27:0]  entry31_ppn;            
       319:     logic            entry31_swp;            
       320:     logic            entry31_swp_on;         
```

`mmu/rtl/mmu_l1itlb.sv:318` (声明 `entry31_ppn`)

```systemverilog
       315:     logic    [13:0]  entry31_flg;            
       316:     logic            entry31_hit;            
       317:     logic    [2 :0]  entry31_pgs;            
       318: >>  logic    [27:0]  entry31_ppn;            
       319:     logic            entry31_swp;            
       320:     logic            entry31_swp_on;         
       321:     logic            entry31_upd;            
```

`mmu/rtl/mmu_l1itlb.sv:323` (声明 `entry3_flg`)

```systemverilog
       320:     logic            entry31_swp_on;         
       321:     logic            entry31_upd;            
       322:     logic            entry31_vld;            
       323: >>  logic    [13:0]  entry3_flg;             
       324:     logic            entry3_hit;             
       325:     logic    [2 :0]  entry3_pgs;             
       326:     logic    [27:0]  entry3_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:325` (声明 `entry3_pgs`)

```systemverilog
       322:     logic            entry31_vld;            
       323:     logic    [13:0]  entry3_flg;             
       324:     logic            entry3_hit;             
       325: >>  logic    [2 :0]  entry3_pgs;             
       326:     logic    [27:0]  entry3_ppn;             
       327:     logic            entry3_swp;             
       328:     logic            entry3_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:326` (声明 `entry3_ppn`)

```systemverilog
       323:     logic    [13:0]  entry3_flg;             
       324:     logic            entry3_hit;             
       325:     logic    [2 :0]  entry3_pgs;             
       326: >>  logic    [27:0]  entry3_ppn;             
       327:     logic            entry3_swp;             
       328:     logic            entry3_swp_on;          
       329:     logic            entry3_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:331` (声明 `entry4_flg`)

```systemverilog
       328:     logic            entry3_swp_on;          
       329:     logic            entry3_upd;             
       330:     logic            entry3_vld;             
       331: >>  logic    [13:0]  entry4_flg;             
       332:     logic            entry4_hit;             
       333:     logic    [2 :0]  entry4_pgs;             
       334:     logic    [27:0]  entry4_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:333` (声明 `entry4_pgs`)

```systemverilog
       330:     logic            entry3_vld;             
       331:     logic    [13:0]  entry4_flg;             
       332:     logic            entry4_hit;             
       333: >>  logic    [2 :0]  entry4_pgs;             
       334:     logic    [27:0]  entry4_ppn;             
       335:     logic            entry4_swp;             
       336:     logic            entry4_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:334` (声明 `entry4_ppn`)

```systemverilog
       331:     logic    [13:0]  entry4_flg;             
       332:     logic            entry4_hit;             
       333:     logic    [2 :0]  entry4_pgs;             
       334: >>  logic    [27:0]  entry4_ppn;             
       335:     logic            entry4_swp;             
       336:     logic            entry4_swp_on;          
       337:     logic            entry4_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:339` (声明 `entry5_flg`)

```systemverilog
       336:     logic            entry4_swp_on;          
       337:     logic            entry4_upd;             
       338:     logic            entry4_vld;             
       339: >>  logic    [13:0]  entry5_flg;             
       340:     logic            entry5_hit;             
       341:     logic    [2 :0]  entry5_pgs;             
       342:     logic    [27:0]  entry5_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:341` (声明 `entry5_pgs`)

```systemverilog
       338:     logic            entry4_vld;             
       339:     logic    [13:0]  entry5_flg;             
       340:     logic            entry5_hit;             
       341: >>  logic    [2 :0]  entry5_pgs;             
       342:     logic    [27:0]  entry5_ppn;             
       343:     logic            entry5_swp;             
       344:     logic            entry5_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:342` (声明 `entry5_ppn`)

```systemverilog
       339:     logic    [13:0]  entry5_flg;             
       340:     logic            entry5_hit;             
       341:     logic    [2 :0]  entry5_pgs;             
       342: >>  logic    [27:0]  entry5_ppn;             
       343:     logic            entry5_swp;             
       344:     logic            entry5_swp_on;          
       345:     logic            entry5_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:347` (声明 `entry6_flg`)

```systemverilog
       344:     logic            entry5_swp_on;          
       345:     logic            entry5_upd;             
       346:     logic            entry5_vld;             
       347: >>  logic    [13:0]  entry6_flg;             
       348:     logic            entry6_hit;             
       349:     logic    [2 :0]  entry6_pgs;             
       350:     logic    [27:0]  entry6_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:349` (声明 `entry6_pgs`)

```systemverilog
       346:     logic            entry5_vld;             
       347:     logic    [13:0]  entry6_flg;             
       348:     logic            entry6_hit;             
       349: >>  logic    [2 :0]  entry6_pgs;             
       350:     logic    [27:0]  entry6_ppn;             
       351:     logic            entry6_swp;             
       352:     logic            entry6_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:350` (声明 `entry6_ppn`)

```systemverilog
       347:     logic    [13:0]  entry6_flg;             
       348:     logic            entry6_hit;             
       349:     logic    [2 :0]  entry6_pgs;             
       350: >>  logic    [27:0]  entry6_ppn;             
       351:     logic            entry6_swp;             
       352:     logic            entry6_swp_on;          
       353:     logic            entry6_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:355` (声明 `entry7_flg`)

```systemverilog
       352:     logic            entry6_swp_on;          
       353:     logic            entry6_upd;             
       354:     logic            entry6_vld;             
       355: >>  logic    [13:0]  entry7_flg;             
       356:     logic            entry7_hit;             
       357:     logic    [2 :0]  entry7_pgs;             
       358:     logic    [27:0]  entry7_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:357` (声明 `entry7_pgs`)

```systemverilog
       354:     logic            entry6_vld;             
       355:     logic    [13:0]  entry7_flg;             
       356:     logic            entry7_hit;             
       357: >>  logic    [2 :0]  entry7_pgs;             
       358:     logic    [27:0]  entry7_ppn;             
       359:     logic            entry7_swp;             
       360:     logic            entry7_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:358` (声明 `entry7_ppn`)

```systemverilog
       355:     logic    [13:0]  entry7_flg;             
       356:     logic            entry7_hit;             
       357:     logic    [2 :0]  entry7_pgs;             
       358: >>  logic    [27:0]  entry7_ppn;             
       359:     logic            entry7_swp;             
       360:     logic            entry7_swp_on;          
       361:     logic            entry7_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:363` (声明 `entry8_flg`)

```systemverilog
       360:     logic            entry7_swp_on;          
       361:     logic            entry7_upd;             
       362:     logic            entry7_vld;             
       363: >>  logic    [13:0]  entry8_flg;             
       364:     logic            entry8_hit;             
       365:     logic    [2 :0]  entry8_pgs;             
       366:     logic    [27:0]  entry8_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:365` (声明 `entry8_pgs`)

```systemverilog
       362:     logic            entry7_vld;             
       363:     logic    [13:0]  entry8_flg;             
       364:     logic            entry8_hit;             
       365: >>  logic    [2 :0]  entry8_pgs;             
       366:     logic    [27:0]  entry8_ppn;             
       367:     logic            entry8_swp;             
       368:     logic            entry8_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:366` (声明 `entry8_ppn`)

```systemverilog
       363:     logic    [13:0]  entry8_flg;             
       364:     logic            entry8_hit;             
       365:     logic    [2 :0]  entry8_pgs;             
       366: >>  logic    [27:0]  entry8_ppn;             
       367:     logic            entry8_swp;             
       368:     logic            entry8_swp_on;          
       369:     logic            entry8_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:371` (声明 `entry8_vpn`)

```systemverilog
       368:     logic            entry8_swp_on;          
       369:     logic            entry8_upd;             
       370:     logic            entry8_vld;             
       371: >>  logic    [26:0]  entry8_vpn;             
       372:     logic    [13:0]  entry9_flg;             
       373:     logic            entry9_hit;             
       374:     logic    [2 :0]  entry9_pgs;             
```

`mmu/rtl/mmu_l1itlb.sv:372` (声明 `entry9_flg`)

```systemverilog
       369:     logic            entry8_upd;             
       370:     logic            entry8_vld;             
       371:     logic    [26:0]  entry8_vpn;             
       372: >>  logic    [13:0]  entry9_flg;             
       373:     logic            entry9_hit;             
       374:     logic    [2 :0]  entry9_pgs;             
       375:     logic    [27:0]  entry9_ppn;             
```

`mmu/rtl/mmu_l1itlb.sv:374` (声明 `entry9_pgs`)

```systemverilog
       371:     logic    [26:0]  entry8_vpn;             
       372:     logic    [13:0]  entry9_flg;             
       373:     logic            entry9_hit;             
       374: >>  logic    [2 :0]  entry9_pgs;             
       375:     logic    [27:0]  entry9_ppn;             
       376:     logic            entry9_swp;             
       377:     logic            entry9_swp_on;          
```

`mmu/rtl/mmu_l1itlb.sv:375` (声明 `entry9_ppn`)

```systemverilog
       372:     logic    [13:0]  entry9_flg;             
       373:     logic            entry9_hit;             
       374:     logic    [2 :0]  entry9_pgs;             
       375: >>  logic    [27:0]  entry9_ppn;             
       376:     logic            entry9_swp;             
       377:     logic            entry9_swp_on;          
       378:     logic            entry9_upd;             
```

`mmu/rtl/mmu_l1itlb.sv:382` (声明 `flg_fin`)

```systemverilog
       379:     logic            entry9_vld;             
       380:     logic    [31:0]  entry_hit;              
       381:     logic    [31:0]  entry_vld;              
       382: >>  logic    [13:0]  flg_fin;                
       383:     logic            iplru_clk;              
       384:     logic            iplru_clk_en;           
       385:     logic            iplru_upd_en;           
```

`mmu/rtl/mmu_l1itlb.sv:389` (声明 `iutlb_bypass_vld`)

```systemverilog
       386:     logic            iutlb_acc_flt;          
       387:     logic            iutlb_addr_hit;         
       388:     logic            iutlb_addr_hit_vld;     
       389: >>  logic            iutlb_bypass_vld;       
       390:     logic            iutlb_clk;              
       391:     logic            iutlb_clk_en;           
       392:     logic            iutlb_disable_vld;      
```

`mmu/rtl/mmu_l1itlb.sv:392` (声明 `iutlb_disable_vld`)

```systemverilog
       389:     logic            iutlb_bypass_vld;       
       390:     logic            iutlb_clk;              
       391:     logic            iutlb_clk_en;           
       392: >>  logic            iutlb_disable_vld;      
       393:     logic    [31:0]  iutlb_entry_hit;        
       394:     logic    [13:0]  iutlb_flg_aft_bypass;   
       395:     logic    [13:0]  iutlb_hit_flg_fst;      
```

`mmu/rtl/mmu_l1itlb.sv:394` (声明 `iutlb_flg_aft_bypass`)

```systemverilog
       391:     logic            iutlb_clk_en;           
       392:     logic            iutlb_disable_vld;      
       393:     logic    [31:0]  iutlb_entry_hit;        
       394: >>  logic    [13:0]  iutlb_flg_aft_bypass;   
       395:     logic    [13:0]  iutlb_hit_flg_fst;      
       396:     logic    [13:0]  iutlb_hit_flg_scd;      
       397:     logic    [27:0]  iutlb_hit_pa_fst;       
```

`mmu/rtl/mmu_l1itlb.sv:395` (声明 `iutlb_hit_flg_fst`)

```systemverilog
       392:     logic            iutlb_disable_vld;      
       393:     logic    [31:0]  iutlb_entry_hit;        
       394:     logic    [13:0]  iutlb_flg_aft_bypass;   
       395: >>  logic    [13:0]  iutlb_hit_flg_fst;      
       396:     logic    [13:0]  iutlb_hit_flg_scd;      
       397:     logic    [27:0]  iutlb_hit_pa_fst;       
       398:     logic    [27:0]  iutlb_hit_pa_scd;       
```

`mmu/rtl/mmu_l1itlb.sv:396` (声明 `iutlb_hit_flg_scd`)

```systemverilog
       393:     logic    [31:0]  iutlb_entry_hit;        
       394:     logic    [13:0]  iutlb_flg_aft_bypass;   
       395:     logic    [13:0]  iutlb_hit_flg_fst;      
       396: >>  logic    [13:0]  iutlb_hit_flg_scd;      
       397:     logic    [27:0]  iutlb_hit_pa_fst;       
       398:     logic    [27:0]  iutlb_hit_pa_scd;       
       399:     logic    [2 :0]  iutlb_hit_pgs_fst;      
```

`mmu/rtl/mmu_l1itlb.sv:397` (声明 `iutlb_hit_pa_fst`)

```systemverilog
       394:     logic    [13:0]  iutlb_flg_aft_bypass;   
       395:     logic    [13:0]  iutlb_hit_flg_fst;      
       396:     logic    [13:0]  iutlb_hit_flg_scd;      
       397: >>  logic    [27:0]  iutlb_hit_pa_fst;       
       398:     logic    [27:0]  iutlb_hit_pa_scd;       
       399:     logic    [2 :0]  iutlb_hit_pgs_fst;      
       400:     logic    [2 :0]  iutlb_hit_pgs_scd;      
```

`mmu/rtl/mmu_l1itlb.sv:398` (声明 `iutlb_hit_pa_scd`)

```systemverilog
       395:     logic    [13:0]  iutlb_hit_flg_fst;      
       396:     logic    [13:0]  iutlb_hit_flg_scd;      
       397:     logic    [27:0]  iutlb_hit_pa_fst;       
       398: >>  logic    [27:0]  iutlb_hit_pa_scd;       
       399:     logic    [2 :0]  iutlb_hit_pgs_fst;      
       400:     logic    [2 :0]  iutlb_hit_pgs_scd;      
       401:     logic            iutlb_hit_vld;          
```

`mmu/rtl/mmu_l1itlb.sv:404` (声明 `iutlb_off_flg`)

```systemverilog
       401:     logic            iutlb_hit_vld;          
       402:     logic            iutlb_miss_cnt;         
       403:     logic            iutlb_miss_vld;         
       404: >>  logic    [13:0]  iutlb_off_flg;          
       405:     logic            iutlb_off_hit;          
       406:     logic    [27:0]  iutlb_off_pa;           
       407:     logic    [2 :0]  iutlb_off_pgs;          
```

`mmu/rtl/mmu_l1itlb.sv:407` (声明 `iutlb_off_pgs`)

```systemverilog
       404:     logic    [13:0]  iutlb_off_flg;          
       405:     logic            iutlb_off_hit;          
       406:     logic    [27:0]  iutlb_off_pa;           
       407: >>  logic    [2 :0]  iutlb_off_pgs;          
       408:     logic    [27:0]  iutlb_pa_aft_bypass;    
       409:     logic            iutlb_pa_vld;           
       410:     logic            iutlb_page_fault;       
```

`mmu/rtl/mmu_l1itlb.sv:408` (声明 `iutlb_pa_aft_bypass`)

```systemverilog
       405:     logic            iutlb_off_hit;          
       406:     logic    [27:0]  iutlb_off_pa;           
       407:     logic    [2 :0]  iutlb_off_pgs;          
       408: >>  logic    [27:0]  iutlb_pa_aft_bypass;    
       409:     logic            iutlb_pa_vld;           
       410:     logic            iutlb_page_fault;       
       411:     logic            iutlb_plru_read_hit_vld; 
```

`mmu/rtl/mmu_l1itlb.sv:422` (声明 `pa_fin`)

```systemverilog
       419:     logic            iutlb_va_illegal;       
       420:     logic            iutlb_wfc;              
       421:     logic            jtlb_acc_fault;         
       422: >>  logic    [27:0]  pa_fin;                 
       423:     logic    [26:0]  pa_offset;              
       424:     logic            pabuf_clk;              
       425:     logic            pabuf_clk_en;           
```

`mmu/rtl/mmu_l1itlb.sv:428` (声明 `utlb_fst_swp_flg`)

```systemverilog
       425:     logic            pabuf_clk_en;           
       426:     logic    [2 :0]  pgs_fin;                
       427:     logic    [31:0]  plru_iutlb_ref_num;     
       428: >>  logic    [13:0]  utlb_fst_swp_flg;       
       429:     logic    [2 :0]  utlb_fst_swp_pgs;       
       430:     logic    [27:0]  utlb_fst_swp_ppn;       
       431:     logic    [26:0]  utlb_fst_swp_vpn;       
```

`mmu/rtl/mmu_l1itlb.sv:430` (声明 `utlb_fst_swp_ppn`)

```systemverilog
       427:     logic    [31:0]  plru_iutlb_ref_num;     
       428:     logic    [13:0]  utlb_fst_swp_flg;       
       429:     logic    [2 :0]  utlb_fst_swp_pgs;       
       430: >>  logic    [27:0]  utlb_fst_swp_ppn;       
       431:     logic    [26:0]  utlb_fst_swp_vpn;       
       432:     logic    [26:0]  utlb_req_vpn;           
       433:     logic    [13:0]  utlb_swp_flg;           
```

`mmu/rtl/mmu_l1itlb.sv:433` (声明 `utlb_swp_flg`)

```systemverilog
       430:     logic    [27:0]  utlb_fst_swp_ppn;       
       431:     logic    [26:0]  utlb_fst_swp_vpn;       
       432:     logic    [26:0]  utlb_req_vpn;           
       433: >>  logic    [13:0]  utlb_swp_flg;           
       434:     logic            utlb_swp_on;            
       435:     logic    [2 :0]  utlb_swp_pgs;           
       436:     logic    [27:0]  utlb_swp_ppn;           
```

`mmu/rtl/mmu_l1itlb.sv:436` (声明 `utlb_swp_ppn`)

```systemverilog
       433:     logic    [13:0]  utlb_swp_flg;           
       434:     logic            utlb_swp_on;            
       435:     logic    [2 :0]  utlb_swp_pgs;           
       436: >>  logic    [27:0]  utlb_swp_ppn;           
       437:     logic    [26:0]  utlb_swp_vpn;           
       438:     logic    [13:0]  utlb_upd_flg;           
       439:     logic    [2 :0]  utlb_upd_pgs;           
```

`mmu/rtl/mmu_l1itlb.sv:437` (声明 `utlb_swp_vpn`)

```systemverilog
       434:     logic            utlb_swp_on;            
       435:     logic    [2 :0]  utlb_swp_pgs;           
       436:     logic    [27:0]  utlb_swp_ppn;           
       437: >>  logic    [26:0]  utlb_swp_vpn;           
       438:     logic    [13:0]  utlb_upd_flg;           
       439:     logic    [2 :0]  utlb_upd_pgs;           
       440:     logic    [27:0]  utlb_upd_ppn;           
```

`mmu/rtl/mmu_l1itlb.sv:438` (声明 `utlb_upd_flg`)

```systemverilog
       435:     logic    [2 :0]  utlb_swp_pgs;           
       436:     logic    [27:0]  utlb_swp_ppn;           
       437:     logic    [26:0]  utlb_swp_vpn;           
       438: >>  logic    [13:0]  utlb_upd_flg;           
       439:     logic    [2 :0]  utlb_upd_pgs;           
       440:     logic    [27:0]  utlb_upd_ppn;           
       441:     logic    [26:0]  utlb_upd_vpn;           
```

`mmu/rtl/mmu_l1itlb.sv:440` (声明 `utlb_upd_ppn`)

```systemverilog
       437:     logic    [26:0]  utlb_swp_vpn;           
       438:     logic    [13:0]  utlb_upd_flg;           
       439:     logic    [2 :0]  utlb_upd_pgs;           
       440: >>  logic    [27:0]  utlb_upd_ppn;           
       441:     logic    [26:0]  utlb_upd_vpn;           
       442:     
       443:     logic credit_cnt;
```

`mmu/rtl/mmu_l1itlb.sv:441` (声明 `utlb_upd_vpn`)

```systemverilog
       438:     logic    [13:0]  utlb_upd_flg;           
       439:     logic    [2 :0]  utlb_upd_pgs;           
       440:     logic    [27:0]  utlb_upd_ppn;           
       441: >>  logic    [26:0]  utlb_upd_vpn;           
       442:     
       443:     logic credit_cnt;
       444:     
```

## 模块 `ct_mmu_iutlb_entry`

源码：`mmu/rtl/ct_mmu_iutlb_entry.v`
原始未覆盖记录数：`21`；合并后唯一代码对象数：`21`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 187 | `SUB-EXPRESSION (utlb_pgs[2] && vpn2_hit)` | 1 0 Not Covered | 1 |

`mmu/rtl/ct_mmu_iutlb_entry.v:187`

```systemverilog
       184:     assign vpn0_hit  = utlb_req_vpn[VPN_WIDTH-1-2*9:0] 
       185:                         == utlb_vpn[VPN_WIDTH-1-2*9:0];
       186:     
       187: >>  assign utlb_hit  = utlb_pgs[0] && vpn2_hit && vpn1_hit && vpn0_hit
       188:                     || utlb_pgs[1] && vpn2_hit && vpn1_hit
       189:                     || utlb_pgs[2] && vpn2_hit;
       190:     
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input  logic         cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `pad_yy_icg_scan_en -> input  logic         pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 31 | `utlb_swp_flg[4] -> input  logic [13:0]  utlb_swp_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 31 | `utlb_swp_flg[8:7] -> input  logic [13:0]  utlb_swp_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 33 | `utlb_swp_ppn[23:20] -> input  logic [27:0]  utlb_swp_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 33 | `utlb_swp_ppn[27:25] -> input  logic [27:0]  utlb_swp_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 34 | `utlb_swp_vpn[26] -> input  logic [26:0]  utlb_swp_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 35 | `utlb_upd_flg[4] -> input  logic [13:0]  utlb_upd_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 37 | `utlb_upd_ppn[23:20] -> input  logic [27:0]  utlb_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 37 | `utlb_upd_ppn[27:25] -> input  logic [27:0]  utlb_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 38 | `utlb_upd_vpn[26] -> input  logic [26:0]  utlb_upd_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 39 | `utlb_entry_flg[4] -> output logic [13:0]  utlb_entry_flg,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 39 | `utlb_entry_flg[8:7] -> output logic [13:0]  utlb_entry_flg,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 42 | `utlb_entry_ppn[23:20] -> output logic [27:0]  utlb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 42 | `utlb_entry_ppn[27:25] -> output logic [27:0]  utlb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |

`mmu/rtl/ct_mmu_iutlb_entry.v:20` (声明 `cpurst_b`)

```systemverilog
        17:     module ct_mmu_iutlb_entry(
        18:     // &Ports; @25
        19:     input  logic         cp0_mmu_icg_en,         
        20: >>  input  logic         cpurst_b,               
        21:     input  logic [26:0]  lsu_mmu_tlb_va,         
        22:     input  logic         pad_yy_icg_scan_en,     
        23:     input  logic         regs_utlb_clr,          
```

`mmu/rtl/ct_mmu_iutlb_entry.v:22` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        19:     input  logic         cp0_mmu_icg_en,         
        20:     input  logic         cpurst_b,               
        21:     input  logic [26:0]  lsu_mmu_tlb_va,         
        22: >>  input  logic         pad_yy_icg_scan_en,     
        23:     input  logic         regs_utlb_clr,          
        24:     input  logic         tlboper_utlb_clr,       
        25:     input  logic         tlboper_utlb_inv_va_req, 
```

`mmu/rtl/ct_mmu_iutlb_entry.v:31` (声明 `utlb_swp_flg`)

```systemverilog
        28:     input  logic         utlb_entry_swp_on,      
        29:     input  logic         utlb_entry_upd,         
        30:     input  logic [26:0]  utlb_req_vpn,           
        31: >>  input  logic [13:0]  utlb_swp_flg,           
        32:     input  logic [2 :0]  utlb_swp_pgs,           
        33:     input  logic [27:0]  utlb_swp_ppn,           
        34:     input  logic [26:0]  utlb_swp_vpn,           
```

`mmu/rtl/ct_mmu_iutlb_entry.v:33` (声明 `utlb_swp_ppn`)

```systemverilog
        30:     input  logic [26:0]  utlb_req_vpn,           
        31:     input  logic [13:0]  utlb_swp_flg,           
        32:     input  logic [2 :0]  utlb_swp_pgs,           
        33: >>  input  logic [27:0]  utlb_swp_ppn,           
        34:     input  logic [26:0]  utlb_swp_vpn,           
        35:     input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
```

`mmu/rtl/ct_mmu_iutlb_entry.v:34` (声明 `utlb_swp_vpn`)

```systemverilog
        31:     input  logic [13:0]  utlb_swp_flg,           
        32:     input  logic [2 :0]  utlb_swp_pgs,           
        33:     input  logic [27:0]  utlb_swp_ppn,           
        34: >>  input  logic [26:0]  utlb_swp_vpn,           
        35:     input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
```

`mmu/rtl/ct_mmu_iutlb_entry.v:35` (声明 `utlb_upd_flg`)

```systemverilog
        32:     input  logic [2 :0]  utlb_swp_pgs,           
        33:     input  logic [27:0]  utlb_swp_ppn,           
        34:     input  logic [26:0]  utlb_swp_vpn,           
        35: >>  input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
        38:     input  logic [26:0]  utlb_upd_vpn,           
```

`mmu/rtl/ct_mmu_iutlb_entry.v:37` (声明 `utlb_upd_ppn`)

```systemverilog
        34:     input  logic [26:0]  utlb_swp_vpn,           
        35:     input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37: >>  input  logic [27:0]  utlb_upd_ppn,           
        38:     input  logic [26:0]  utlb_upd_vpn,           
        39:     output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
```

`mmu/rtl/ct_mmu_iutlb_entry.v:38` (声明 `utlb_upd_vpn`)

```systemverilog
        35:     input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
        38: >>  input  logic [26:0]  utlb_upd_vpn,           
        39:     output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
        41:     output logic [2 :0]  utlb_entry_pgs,         
```

`mmu/rtl/ct_mmu_iutlb_entry.v:39` (声明 `utlb_entry_flg`)

```systemverilog
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
        38:     input  logic [26:0]  utlb_upd_vpn,           
        39: >>  output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
        41:     output logic [2 :0]  utlb_entry_pgs,         
        42:     output logic [27:0]  utlb_entry_ppn,         
```

`mmu/rtl/ct_mmu_iutlb_entry.v:42` (声明 `utlb_entry_ppn`)

```systemverilog
        39:     output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
        41:     output logic [2 :0]  utlb_entry_pgs,         
        42: >>  output logic [27:0]  utlb_entry_ppn,         
        43:     output logic         utlb_entry_vld         
        44:     
        45:      );
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 49 | `utlb_flg[4] -> logic     [13:0]  utlb_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 49 | `utlb_flg[8:7] -> logic     [13:0]  utlb_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 51 | `utlb_ppn[23:20] -> logic     [27:0]  utlb_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 51 | `utlb_ppn[27:25] -> logic     [27:0]  utlb_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 53 | `utlb_vpn[26] -> logic     [26:0]  utlb_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/ct_mmu_iutlb_entry.v:49` (声明 `utlb_flg`)

```systemverilog
        46:     
        47:     
        48:     // &Regs; @26
        49: >>  logic     [13:0]  utlb_flg;               
        50:     logic     [2 :0]  utlb_pgs;               
        51:     logic     [27:0]  utlb_ppn;               
        52:     logic             utlb_vld;               
```

`mmu/rtl/ct_mmu_iutlb_entry.v:51` (声明 `utlb_ppn`)

```systemverilog
        48:     // &Regs; @26
        49:     logic     [13:0]  utlb_flg;               
        50:     logic     [2 :0]  utlb_pgs;               
        51: >>  logic     [27:0]  utlb_ppn;               
        52:     logic             utlb_vld;               
        53:     logic     [26:0]  utlb_vpn;               
        54:     
```

`mmu/rtl/ct_mmu_iutlb_entry.v:53` (声明 `utlb_vpn`)

```systemverilog
        50:     logic     [2 :0]  utlb_pgs;               
        51:     logic     [27:0]  utlb_ppn;               
        52:     logic             utlb_vld;               
        53: >>  logic     [26:0]  utlb_vpn;               
        54:     
        55:     // &Wires; @27
        56:     logic            ctc_inv_va_hit_clr;     
```

## 模块 `ct_mmu_iutlb_fst_entry`

源码：`mmu/rtl/ct_mmu_iutlb_fst_entry.v`
原始未覆盖记录数：`27`；合并后唯一代码对象数：`25`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 188 | `SUB-EXPRESSION (utlb_pgs[0] && vpn2_hit && vpn1_hit && vpn0_hit)` | 1 0 1 1 Not Covered | 1 |

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:188`

```systemverilog
       185:     assign vpn0_hit  = utlb_req_vpn[VPN_WIDTH-1-2*9:0] 
       186:                         == utlb_vpn[VPN_WIDTH-1-2*9:0];
       187:     
       188: >>  assign utlb_hit  = utlb_pgs[0] && vpn2_hit && vpn1_hit && vpn0_hit
       189:                     || utlb_pgs[1] && vpn2_hit && vpn1_hit
       190:                     || utlb_pgs[2] && vpn2_hit;
       191:     
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input  logic         cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `pad_yy_icg_scan_en -> input  logic         pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `utlb_fst_swp_flg[4] -> input  logic [13:0]  utlb_fst_swp_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 30 | `utlb_fst_swp_flg[8:7] -> input  logic [13:0]  utlb_fst_swp_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `utlb_fst_swp_ppn[23:20] -> input  logic [27:0]  utlb_fst_swp_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 32 | `utlb_fst_swp_ppn[27:25] -> input  logic [27:0]  utlb_fst_swp_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 35 | `utlb_upd_flg[4] -> input  logic [13:0]  utlb_upd_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 37 | `utlb_upd_ppn[23:20] -> input  logic [27:0]  utlb_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 37 | `utlb_upd_ppn[27:25] -> input  logic [27:0]  utlb_upd_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 38 | `utlb_upd_vpn[26] -> input  logic [26:0]  utlb_upd_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 39 | `utlb_entry_flg[3:0] -> output logic [13:0]  utlb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 39 | `utlb_entry_flg[4] -> output logic [13:0]  utlb_entry_flg,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 39 | `utlb_entry_flg[9:5] -> output logic [13:0]  utlb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 42 | `utlb_entry_ppn[15] -> output logic [27:0]  utlb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 2 |
| 42 | `utlb_entry_ppn[23:20] -> output logic [27:0]  utlb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 42 | `utlb_entry_ppn[27:25] -> output logic [27:0]  utlb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 44 | `utlb_entry_vpn[26] -> output logic [26:0]  utlb_entry_vpn` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:20` (声明 `cpurst_b`)

```systemverilog
        17:     module ct_mmu_iutlb_fst_entry(
        18:     // &Ports; @25
        19:     input  logic         cp0_mmu_icg_en,         
        20: >>  input  logic         cpurst_b,               
        21:     input  logic [26:0]  lsu_mmu_tlb_va,         
        22:     input  logic         pad_yy_icg_scan_en,     
        23:     input  logic         regs_utlb_clr,          
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:22` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        19:     input  logic         cp0_mmu_icg_en,         
        20:     input  logic         cpurst_b,               
        21:     input  logic [26:0]  lsu_mmu_tlb_va,         
        22: >>  input  logic         pad_yy_icg_scan_en,     
        23:     input  logic         regs_utlb_clr,          
        24:     input  logic         tlboper_utlb_clr,       
        25:     input  logic         tlboper_utlb_inv_va_req, 
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:30` (声明 `utlb_fst_swp_flg`)

```systemverilog
        27:     input  logic         utlb_entry_swp,         
        28:     input  logic         utlb_entry_swp_on,      
        29:     input  logic         utlb_entry_upd,         
        30: >>  input  logic [13:0]  utlb_fst_swp_flg,       
        31:     input  logic [2 :0]  utlb_fst_swp_pgs,       
        32:     input  logic [27:0]  utlb_fst_swp_ppn,       
        33:     input  logic [26:0]  utlb_fst_swp_vpn,       
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:32` (声明 `utlb_fst_swp_ppn`)

```systemverilog
        29:     input  logic         utlb_entry_upd,         
        30:     input  logic [13:0]  utlb_fst_swp_flg,       
        31:     input  logic [2 :0]  utlb_fst_swp_pgs,       
        32: >>  input  logic [27:0]  utlb_fst_swp_ppn,       
        33:     input  logic [26:0]  utlb_fst_swp_vpn,       
        34:     input  logic [26:0]  utlb_req_vpn,           
        35:     input  logic [13:0]  utlb_upd_flg,           
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:35` (声明 `utlb_upd_flg`)

```systemverilog
        32:     input  logic [27:0]  utlb_fst_swp_ppn,       
        33:     input  logic [26:0]  utlb_fst_swp_vpn,       
        34:     input  logic [26:0]  utlb_req_vpn,           
        35: >>  input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
        38:     input  logic [26:0]  utlb_upd_vpn,           
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:37` (声明 `utlb_upd_ppn`)

```systemverilog
        34:     input  logic [26:0]  utlb_req_vpn,           
        35:     input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37: >>  input  logic [27:0]  utlb_upd_ppn,           
        38:     input  logic [26:0]  utlb_upd_vpn,           
        39:     output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:38` (声明 `utlb_upd_vpn`)

```systemverilog
        35:     input  logic [13:0]  utlb_upd_flg,           
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
        38: >>  input  logic [26:0]  utlb_upd_vpn,           
        39:     output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
        41:     output logic [2 :0]  utlb_entry_pgs,         
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:39` (声明 `utlb_entry_flg`)

```systemverilog
        36:     input  logic [2 :0]  utlb_upd_pgs,           
        37:     input  logic [27:0]  utlb_upd_ppn,           
        38:     input  logic [26:0]  utlb_upd_vpn,           
        39: >>  output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
        41:     output logic [2 :0]  utlb_entry_pgs,         
        42:     output logic [27:0]  utlb_entry_ppn,         
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:42` (声明 `utlb_entry_ppn`)

```systemverilog
        39:     output logic [13:0]  utlb_entry_flg,         
        40:     output logic         utlb_entry_hit,         
        41:     output logic [2 :0]  utlb_entry_pgs,         
        42: >>  output logic [27:0]  utlb_entry_ppn,         
        43:     output logic         utlb_entry_vld,         
        44:     output logic [26:0]  utlb_entry_vpn         
        45:     
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:44` (声明 `utlb_entry_vpn`)

```systemverilog
        41:     output logic [2 :0]  utlb_entry_pgs,         
        42:     output logic [27:0]  utlb_entry_ppn,         
        43:     output logic         utlb_entry_vld,         
        44: >>  output logic [26:0]  utlb_entry_vpn         
        45:     
        46:      );
        47:     
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 50 | `utlb_flg[3:0] -> logic     [13:0]  utlb_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 50 | `utlb_flg[4] -> logic     [13:0]  utlb_flg;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 50 | `utlb_flg[9:5] -> logic     [13:0]  utlb_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 52 | `utlb_ppn[15] -> logic     [27:0]  utlb_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| 52 | `utlb_ppn[23:20] -> logic     [27:0]  utlb_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 52 | `utlb_ppn[27:25] -> logic     [27:0]  utlb_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 54 | `utlb_vpn[26] -> logic     [26:0]  utlb_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:50` (声明 `utlb_flg`)

```systemverilog
        47:     
        48:     
        49:     // &Regs; @26
        50: >>  logic     [13:0]  utlb_flg;               
        51:     logic     [2 :0]  utlb_pgs;               
        52:     logic     [27:0]  utlb_ppn;               
        53:     logic             utlb_vld;               
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:52` (声明 `utlb_ppn`)

```systemverilog
        49:     // &Regs; @26
        50:     logic     [13:0]  utlb_flg;               
        51:     logic     [2 :0]  utlb_pgs;               
        52: >>  logic     [27:0]  utlb_ppn;               
        53:     logic             utlb_vld;               
        54:     logic     [26:0]  utlb_vpn;               
        55:     
```

`mmu/rtl/ct_mmu_iutlb_fst_entry.v:54` (声明 `utlb_vpn`)

```systemverilog
        51:     logic     [2 :0]  utlb_pgs;               
        52:     logic     [27:0]  utlb_ppn;               
        53:     logic             utlb_vld;               
        54: >>  logic     [26:0]  utlb_vpn;               
        55:     
        56:     // &Wires; @27
        57:     logic            ctc_inv_va_hit_clr;     
```

## 模块 `mmu_l1dtlb_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`145`；合并后唯一代码对象数：`32`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input logic cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 57 | `mb_entry_vpn[2][11] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 13 |
| 57 | `mb_entry_vpn[2][20:19] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 57 | `mb_entry_vpn[5][1:0] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 58 | `mb_entry_iid[3][1:0] -> input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 58 | `mb_entry_iid[5][0] -> input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 2 |
| - | `Other bits of mb_entry_iid[7:0][6:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 62 | `mb_entry_wfi[7:3] -> input logic [MB_DEPTH-1:0]                 mb_entry_wfi,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 63 | `mb_entry_store[3] -> input logic [MB_DEPTH-1:0]                 mb_entry_store,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 4 |
| 66 | `l1dtlb_ent_vpn[0][11] -> input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 13 |
| 66 | `l1dtlb_ent_vpn[0][24:22] -> input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 66 | `l1dtlb_ent_vpn[1][25:23] -> input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 66 | `l1dtlb_ent_vpn[2][25:22] -> input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 66 | `l1dtlb_ent_vpn[3][10:9] -> input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 66 | `l1dtlb_ent_vpn[3][23:22] -> input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of l1dtlb_ent_vpn[15:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 67 | `entry_ppn[0][15] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 33 |
| 67 | `entry_ppn[0][27:24] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 16 |
| 67 | `entry_ppn[1][20:19] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 3 |
| 67 | `entry_ppn[3][11:10] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 67 | `entry_ppn[3][20:18] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 12 |
| - | `Other bits of entry_ppn[15:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 68 | `l1dtlb_ent_pgs[5][1] -> input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 10 |
| 68 | `l1dtlb_ent_pgs[6][1:0] -> input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of l1dtlb_ent_pgs[15:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 114 | `utlb_refill_vpn[26] -> input logic [VPN_WIDTH-1:0] utlb_refill_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 115 | `utlb_refill_ppn[23:21] -> input logic [PPN_WIDTH-1:0] utlb_refill_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 134 | `expt_wr1_acflt -> input logic expt_wr1_acflt` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter int CREDIT_MAX  = 8
        18:     ) (
        19:         input logic forever_cpuclk,
        20: >>      input logic cpurst_b,
        21:     
        22:         input logic regs_utlb_clr,
        23:         input logic rtu_yy_xx_flush,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:57` (声明 `mb_entry_vpn`)

```systemverilog
        54:     
        55:         input logic [MB_DEPTH-1:0]                 mb_entry_vld,
        56:         input logic [MB_DEPTH-1:0][2:0]            mb_entry_state,
        57: >>      input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,
        58:         input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:58` (声明 `mb_entry_iid`)

```systemverilog
        55:         input logic [MB_DEPTH-1:0]                 mb_entry_vld,
        56:         input logic [MB_DEPTH-1:0][2:0]            mb_entry_state,
        57:         input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,
        58: >>      input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
        61:         input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:62` (声明 `mb_entry_wfi`)

```systemverilog
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
        61:         input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
        62: >>      input logic [MB_DEPTH-1:0]                 mb_entry_wfi,
        63:         input logic [MB_DEPTH-1:0]                 mb_entry_store,
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:63` (声明 `mb_entry_store`)

```systemverilog
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
        61:         input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
        62:         input logic [MB_DEPTH-1:0]                 mb_entry_wfi,
        63: >>      input logic [MB_DEPTH-1:0]                 mb_entry_store,
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
        66:         input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:66` (声明 `l1dtlb_ent_vpn`)

```systemverilog
        63:         input logic [MB_DEPTH-1:0]                 mb_entry_store,
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
        66: >>      input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
        67:         input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,
        68:         input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,
        69:         input logic [NUM_ENTRY-1:0]                entry_hit0,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:67` (声明 `entry_ppn`)

```systemverilog
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
        66:         input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
        67: >>      input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,
        68:         input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,
        69:         input logic [NUM_ENTRY-1:0]                entry_hit0,
        70:         input logic [NUM_ENTRY-1:0]                entry_hit1,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:68` (声明 `l1dtlb_ent_pgs`)

```systemverilog
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
        66:         input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
        67:         input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,
        68: >>      input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,
        69:         input logic [NUM_ENTRY-1:0]                entry_hit0,
        70:         input logic [NUM_ENTRY-1:0]                entry_hit1,
        71:     
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:114` (声明 `utlb_refill_vpn`)

```systemverilog
       111:     
       112:         input logic utlb_refill_vld,
       113:         input logic [3:0] utlb_refill_idx,
       114: >>      input logic [VPN_WIDTH-1:0] utlb_refill_vpn,
       115:         input logic [PPN_WIDTH-1:0] utlb_refill_ppn,
       116:         input logic [2:0] utlb_refill_pgs,
       117:         input logic [NUM_ENTRY-1:0] entry_upd,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:115` (声明 `utlb_refill_ppn`)

```systemverilog
       112:         input logic utlb_refill_vld,
       113:         input logic [3:0] utlb_refill_idx,
       114:         input logic [VPN_WIDTH-1:0] utlb_refill_vpn,
       115: >>      input logic [PPN_WIDTH-1:0] utlb_refill_ppn,
       116:         input logic [2:0] utlb_refill_pgs,
       117:         input logic [NUM_ENTRY-1:0] entry_upd,
       118:         input logic plru_refill_updt,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:134` (声明 `expt_wr1_acflt`)

```systemverilog
       131:         input logic [IID_WIDTH-1:0] expt_wr1_iid,
       132:         input logic [VPN_WIDTH-1:0] expt_wr1_vpn,
       133:         input logic expt_wr1_pgflt,
       134: >>      input logic expt_wr1_acflt
       135:     );
       136:     
       137:       localparam logic [2:0] MB_STATE_IDLE = 3'b000;
```

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `gen_l1dtlb_entry_sva[10].a_va8_inv_clears_matching_entry` | assertion | 206452807 | 0 | 14 |
| `gen_l1dtlb_entry_sva[11].a_clear_wins_install_same_entry` | assertion | 206452807 | 0 | 4 |
| `cp_l1dtlb_c001_reset_then_miss` | cover | 206452807 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:286` (`a_va8_inv_clears_matching_entry`)

```systemverilog
       282:                                && !$isunknown(l1dtlb_ent_vpn[ent_i])
       283:                                && !$isunknown(l1dtlb_ent_pgs[ent_i])
       284:                                && legal_pgs(l1dtlb_ent_pgs[ent_i])));
       285:     
       286: >>        a_va8_inv_clears_matching_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       287:             (tlboper_utlb_inv_va_req
       288:              && entry_vld[ent_i]
       289:              && (l1dtlb_ent_vpn[ent_i][7:0] == lsu_mmu_tlb_va[7:0]))
       290:             |=> !entry_vld[ent_i]);
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:301` (`a_clear_wins_install_same_entry`)

```systemverilog
       297:              && !tlboper_utlb_clr
       298:              && !entry_upd[ent_i])
       299:             |=> entry_vld[ent_i]);
       300:     
       301: >>        a_clear_wins_install_same_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       302:             (((regs_utlb_clr || tlboper_utlb_clr)
       303:               || (tlboper_utlb_inv_va_req
       304:                   && entry_vld[ent_i]
       305:                   && (l1dtlb_ent_vpn[ent_i][7:0] == lsu_mmu_tlb_va[7:0])))
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:413` (`cp_l1dtlb_c001_reset_then_miss`)

```systemverilog
       409:         mmu_hpcp_dutlb_miss |-> (dutlb_miss_vld0 || dutlb_miss_vld1));
       410:     
       411:       // C001-C027 representative cover points.  Several complex rows are also
       412:       // measured in the whitebox covergroup and traceability matrix.
       413: >>    cp_l1dtlb_c001_reset_then_miss: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       414:         $rose(cpurst_b) ##[1:64] (dutlb_miss_vld0 || dutlb_miss_vld1));
       415:     
       416:       cp_l1dtlb_c002_dual_hit: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       417:         lsu_mmu_va0_vld && lsu_mmu_va1_vld && (|entry_hit0) && (|entry_hit1));
```

## 模块 `mmu_l1dtlb_mb_entry_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`10`；合并后唯一代码对象数：`10`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input logic cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 624 | `refill_ppn[23:21] -> input logic [PPN_WIDTH-1:0] refill_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 67 | `entry_ppn[8] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 67 | `entry_ppn[27:20] -> input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 633 | `entry_flg[4] -> input logic [FLG_WIDTH-1:0] entry_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 633 | `entry_flg[8:7] -> input logic [FLG_WIDTH-1:0] entry_flg,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 635 | `entry_pgs[2] -> input logic [2:0] entry_pgs,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter int CREDIT_MAX  = 8
        18:     ) (
        19:         input logic forever_cpuclk,
        20: >>      input logic cpurst_b,
        21:     
        22:         input logic regs_utlb_clr,
        23:         input logic rtu_yy_xx_flush,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:624` (声明 `refill_ppn`)

```systemverilog
       621:         input logic refill_gnt,
       622:         input logic refill_pgflt,
       623:         input logic refill_acflt,
       624: >>      input logic [PPN_WIDTH-1:0] refill_ppn,
       625:         input logic [FLG_WIDTH-1:0] refill_flg,
       626:         input logic [2:0] refill_pgs,
       627:         input logic expt_hit,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:67` (声明 `entry_ppn`)

```systemverilog
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
        66:         input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
        67: >>      input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,
        68:         input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,
        69:         input logic [NUM_ENTRY-1:0]                entry_hit0,
        70:         input logic [NUM_ENTRY-1:0]                entry_hit1,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:633` (声明 `entry_flg`)

```systemverilog
       630:         input logic [2:0] entry_state,
       631:         input logic [VPN_WIDTH-1:0] entry_vpn,
       632:         input logic [PPN_WIDTH-1:0] entry_ppn,
       633: >>      input logic [FLG_WIDTH-1:0] entry_flg,
       634:         input logic [IID_WIDTH-1:0] entry_iid,
       635:         input logic [2:0] entry_pgs,
       636:         input logic entry_store,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:635` (声明 `entry_pgs`)

```systemverilog
       632:         input logic [PPN_WIDTH-1:0] entry_ppn,
       633:         input logic [FLG_WIDTH-1:0] entry_flg,
       634:         input logic [IID_WIDTH-1:0] entry_iid,
       635: >>      input logic [2:0] entry_pgs,
       636:         input logic entry_store,
       637:         input logic entry_issued,
       638:         input logic entry_ready,
```

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `a_idle_flush_blocks_alloc` | assertion | 1651622456 | 0 | 1 |
| `a_wfi_data_stable_without_grant` | assertion | 1651622456 | 0 | 1 |
| `a_wfi_flush_to_idle` | assertion | 1651622456 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:674` (`a_idle_flush_blocks_alloc`)

```systemverilog
       670:     	    |=> (entry_vpn == $past(alloc_vpn)
       671:     	      && entry_iid == $past(alloc_iid)
       672:     	      && entry_store == $past(alloc_store)));
       673:     
       674: >>  	  a_idle_flush_blocks_alloc: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
       675:     	    (alloc_vld && rtu_yy_xx_flush && entry_state == STATE_IDLE)
       676:     	    |=> entry_state == STATE_IDLE);
       677:     
       678:       a_wfi_data_stable_without_grant: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:678` (`a_wfi_data_stable_without_grant`)

```systemverilog
       674:     	  a_idle_flush_blocks_alloc: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
       675:     	    (alloc_vld && rtu_yy_xx_flush && entry_state == STATE_IDLE)
       676:     	    |=> entry_state == STATE_IDLE);
       677:     
       678: >>    a_wfi_data_stable_without_grant: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
       679:         (entry_state == STATE_WFI && !refill_gnt && !rtu_yy_xx_flush)
       680:         |=> (entry_state == STATE_WFI
       681:           && entry_vpn == $past(entry_vpn)
       682:           && entry_ppn == $past(entry_ppn)
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:715` (`a_wfi_flush_to_idle`)

```systemverilog
       711:     
       712:       a_wfc_flush_refill_to_idle: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
       713:         (entry_state == STATE_WFC && rtu_yy_xx_flush && refill_vld) |=> entry_state == STATE_IDLE);
       714:     
       715: >>    a_wfi_flush_to_idle: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
       716:         (entry_state == STATE_WFI && rtu_yy_xx_flush) |=> entry_state == STATE_IDLE);
       717:     
       718:       cp_l1dtlb_c017_stale_or_abt_refill: cover property (@(posedge mb_clk) disable iff (!cpurst_b)
       719:         (entry_state inside {STATE_IDLE, STATE_PGFLT, STATE_ACFLT, STATE_ABT}) && refill_vld);
```

## 模块 `mmu_l1dtlb_expt_cam_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`3`；合并后唯一代码对象数：`3`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 1017 | `rst_b -> input logic rst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 134 | `expt_wr1_acflt -> input logic expt_wr1_acflt` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1045 | `expt_hit_vec[7:3] -> input logic [CAM_DEPTH-1:0] expt_hit_vec` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1017` (声明 `rst_b`)

```systemverilog
      1014:         parameter int VPN_WIDTH = 27
      1015:     ) (
      1016:         input logic clk,
      1017: >>      input logic rst_b,
      1018:         input logic rtu_yy_xx_flush,
      1019:         input logic expt_wr0_vld,
      1020:         input logic [$clog2(CAM_DEPTH)-1:0] expt_wr0_eid,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:134` (声明 `expt_wr1_acflt`)

```systemverilog
       131:         input logic [IID_WIDTH-1:0] expt_wr1_iid,
       132:         input logic [VPN_WIDTH-1:0] expt_wr1_vpn,
       133:         input logic expt_wr1_pgflt,
       134: >>      input logic expt_wr1_acflt
       135:     );
       136:     
       137:       localparam logic [2:0] MB_STATE_IDLE = 3'b000;
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1045` (声明 `expt_hit_vec`)

```systemverilog
      1042:         input logic expt_match1,
      1043:         input logic expt_pgflt1,
      1044:         input logic expt_acflt1,
      1045: >>      input logic [CAM_DEPTH-1:0] expt_hit_vec
      1046:     );
      1047:     
      1048:       // A009/A014/A027/A052/A056/A057/A058/A060: exception CAM contract.
```

## 模块 `mmu_l1dtlb_install_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`36`；合并后唯一代码对象数：`24`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input logic cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 57 | `mb_entry_vpn[2][11] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 13 |
| 57 | `mb_entry_vpn[2][20:19] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 57 | `mb_entry_vpn[5][1:0] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 870 | `mb_entry_ppn[0][19] -> input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 870 | `mb_entry_ppn[2][6:0] -> input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 870 | `mb_entry_ppn[2][18:9] -> input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_ppn[7:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 871 | `mb_entry_flg[2][3:0] -> input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 871 | `mb_entry_flg[2][6:5] -> input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 871 | `mb_entry_flg[2][13:9] -> input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_flg[7:0][13:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 872 | `mb_entry_pgs[2][0] -> input logic [MB_DEPTH-1:0][2:0] mb_entry_pgs,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_pgs[7:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 62 | `mb_entry_wfi[7:3] -> input logic [MB_DEPTH-1:0]                 mb_entry_wfi,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 879 | `jtlb_utlb_ref_ppn[20] -> input logic [PPN_WIDTH-1:0] jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 879 | `jtlb_utlb_ref_ppn[23:21] -> input logic [PPN_WIDTH-1:0] jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 879 | `jtlb_utlb_ref_ppn[27:24] -> input logic [PPN_WIDTH-1:0] jtlb_utlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 886 | `ptw_l1tlb_ref_vpn[26] -> input logic [VPN_WIDTH-1:0] ptw_l1tlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 887 | `ptw_l1tlb_ref_ppn[23:21] -> input logic [PPN_WIDTH-1:0] ptw_l1tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 114 | `utlb_refill_vpn[26] -> input logic [VPN_WIDTH-1:0] utlb_refill_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 115 | `utlb_refill_ppn[23:21] -> input logic [PPN_WIDTH-1:0] utlb_refill_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter int CREDIT_MAX  = 8
        18:     ) (
        19:         input logic forever_cpuclk,
        20: >>      input logic cpurst_b,
        21:     
        22:         input logic regs_utlb_clr,
        23:         input logic rtu_yy_xx_flush,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:57` (声明 `mb_entry_vpn`)

```systemverilog
        54:     
        55:         input logic [MB_DEPTH-1:0]                 mb_entry_vld,
        56:         input logic [MB_DEPTH-1:0][2:0]            mb_entry_state,
        57: >>      input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,
        58:         input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:870` (声明 `mb_entry_ppn`)

```systemverilog
       867:         input logic [MB_DEPTH-1:0] mb_entry_vld,
       868:         input logic [MB_DEPTH-1:0][2:0] mb_entry_state,
       869:         input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
       870: >>      input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
       871:         input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
       872:         input logic [MB_DEPTH-1:0][2:0] mb_entry_pgs,
       873:         input logic [MB_DEPTH-1:0] mb_entry_wfi,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:871` (声明 `mb_entry_flg`)

```systemverilog
       868:         input logic [MB_DEPTH-1:0][2:0] mb_entry_state,
       869:         input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
       870:         input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
       871: >>      input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
       872:         input logic [MB_DEPTH-1:0][2:0] mb_entry_pgs,
       873:         input logic [MB_DEPTH-1:0] mb_entry_wfi,
       874:         input logic [MB_DEPTH-1:0] mb_refill_gnt_bus,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:872` (声明 `mb_entry_pgs`)

```systemverilog
       869:         input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
       870:         input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
       871:         input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
       872: >>      input logic [MB_DEPTH-1:0][2:0] mb_entry_pgs,
       873:         input logic [MB_DEPTH-1:0] mb_entry_wfi,
       874:         input logic [MB_DEPTH-1:0] mb_refill_gnt_bus,
       875:         input logic jtlb_dutlb_ref_pavld,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:62` (声明 `mb_entry_wfi`)

```systemverilog
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
        61:         input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
        62: >>      input logic [MB_DEPTH-1:0]                 mb_entry_wfi,
        63:         input logic [MB_DEPTH-1:0]                 mb_entry_store,
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:879` (声明 `jtlb_utlb_ref_ppn`)

```systemverilog
       876:         input logic jtlb_dutlb_ref_cmplt,
       877:         input logic [2:0] jtlb_dutlb_ref_id,
       878:         input logic [VPN_WIDTH-1:0] jtlb_utlb_ref_vpn,
       879: >>      input logic [PPN_WIDTH-1:0] jtlb_utlb_ref_ppn,
       880:         input logic [FLG_WIDTH-1:0] jtlb_utlb_ref_flg,
       881:         input logic jtlb_dutlb_pgflt,
       882:         input logic [2:0] l2tlb_l1dtlb_ref_pgs,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:886` (声明 `ptw_l1tlb_ref_vpn`)

```systemverilog
       883:         input logic ptw_l1dtlb_ref_pavld,
       884:         input logic ptw_l1dtlb_ref_cmplt,
       885:         input logic [2:0] ptw_l1dtlb_ref_id,
       886: >>      input logic [VPN_WIDTH-1:0] ptw_l1tlb_ref_vpn,
       887:         input logic [PPN_WIDTH-1:0] ptw_l1tlb_ref_ppn,
       888:         input logic ptw_l1tlb_acc_err,
       889:         input logic ptw_l1tlb_pgflt,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:887` (声明 `ptw_l1tlb_ref_ppn`)

```systemverilog
       884:         input logic ptw_l1dtlb_ref_cmplt,
       885:         input logic [2:0] ptw_l1dtlb_ref_id,
       886:         input logic [VPN_WIDTH-1:0] ptw_l1tlb_ref_vpn,
       887: >>      input logic [PPN_WIDTH-1:0] ptw_l1tlb_ref_ppn,
       888:         input logic ptw_l1tlb_acc_err,
       889:         input logic ptw_l1tlb_pgflt,
       890:         input logic [FLG_WIDTH-1:0] ptw_l1tlb_ref_flg,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:114` (声明 `utlb_refill_vpn`)

```systemverilog
       111:     
       112:         input logic utlb_refill_vld,
       113:         input logic [3:0] utlb_refill_idx,
       114: >>      input logic [VPN_WIDTH-1:0] utlb_refill_vpn,
       115:         input logic [PPN_WIDTH-1:0] utlb_refill_ppn,
       116:         input logic [2:0] utlb_refill_pgs,
       117:         input logic [NUM_ENTRY-1:0] entry_upd,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:115` (声明 `utlb_refill_ppn`)

```systemverilog
       112:         input logic utlb_refill_vld,
       113:         input logic [3:0] utlb_refill_idx,
       114:         input logic [VPN_WIDTH-1:0] utlb_refill_vpn,
       115: >>      input logic [PPN_WIDTH-1:0] utlb_refill_ppn,
       116:         input logic [2:0] utlb_refill_pgs,
       117:         input logic [NUM_ENTRY-1:0] entry_upd,
       118:         input logic plru_refill_updt,
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 920 | `wfi_id[2] -> logic [$clog2(MB_DEPTH)-1:0] wfi_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:920` (声明 `wfi_id`)

```systemverilog
       917:         legal_pgs = (pgs == 3'b001) || (pgs == 3'b010) || (pgs == 3'b100);
       918:       endfunction
       919:     
       920: >>    logic [$clog2(MB_DEPTH)-1:0] wfi_id;
       921:       assign wfi_id = first_wfi(mb_entry_wfi);
       922:     
       923:       // A016/A048/A049/A050/A051/A066: install arbitration and update payload.
```

## 模块 `mmu_l1dtlb_hit_rd_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`172`；合并后唯一代码对象数：`124`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input logic cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[0] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 16 |
| 1113 | `entry_flg_vec[6:4] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[16:14] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[20:19] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[22:21] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[30:28] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[34:33] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[36:35] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[38:37] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[45:42] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[48:47] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[50:49] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[52:51] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[59:56] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[62:61] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[64:63] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[66:65] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[73:70] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[76:75] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[78:77] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[80:79] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[87:84] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[90:89] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[92:91] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[94:93] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[101:98] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[104:103] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[106:105] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[108:107] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[115:112] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[118:117] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[120:119] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[122:121] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[129:126] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[132:131] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[134:133] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[136:135] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[143:140] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[146:145] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[148:147] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[150:149] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[157:154] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[160:159] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[162:161] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[164:163] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[171:168] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[174:173] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[176:175] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[178:177] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[185:182] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[188:187] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[190:189] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[192:191] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[199:196] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[202:201] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[204:203] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[206:205] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[213:210] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[216:215] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1113 | `entry_flg_vec[218:217] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1113 | `entry_flg_vec[220:219] -> input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[15] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 34 |
| 1115 | `entry_ppn_vec[23:21] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[27:24] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[48:47] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[51:49] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[55:52] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[76:75] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[79:77] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[83:80] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[95:94] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[104:102] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[107:105] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[111:108] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[132:130] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[135:133] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[139:136] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[160:158] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[163:161] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[167:164] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[179:178] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[188:186] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[191:189] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[195:192] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[207:206] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[216:214] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[219:217] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[223:220] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[235:234] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[244:243] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[247:245] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[251:248] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[263:262] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[272:270] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[275:273] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[279:276] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[291:290] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[300:298] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[303:301] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[307:304] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[319:318] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[328:326] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[331:329] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[335:332] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[347:346] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[356:354] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[359:357] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[363:360] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[375:374] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[384:382] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[387:385] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[391:388] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[403:402] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[412:410] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[415:413] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[419:416] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[431:430] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[440:438] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1115 | `entry_ppn_vec[443:441] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 1115 | `entry_ppn_vec[447:444] -> input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 1135 | `mmu_lsu_stall_x -> input logic mmu_lsu_stall_x,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter int CREDIT_MAX  = 8
        18:     ) (
        19:         input logic forever_cpuclk,
        20: >>      input logic cpurst_b,
        21:     
        22:         input logic regs_utlb_clr,
        23:         input logic rtu_yy_xx_flush,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1113` (声明 `entry_flg_vec`)

```systemverilog
      1110:         input logic cp0_supv_mode,
      1111:         input logic cp0_user_mode,
      1112:         input logic [NUM_ENTRY-1:0] entry_vld_vec,
      1113: >>      input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,
      1114:         input logic [NUM_ENTRY-1:0] entry_hit_vec,
      1115:         input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,
      1116:         input logic expt_match_x,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1115` (声明 `entry_ppn_vec`)

```systemverilog
      1112:         input logic [NUM_ENTRY-1:0] entry_vld_vec,
      1113:         input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,
      1114:         input logic [NUM_ENTRY-1:0] entry_hit_vec,
      1115: >>      input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,
      1116:         input logic expt_match_x,
      1117:         input logic expt_pgflt_x,
      1118:         input logic expt_acflt_x,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1135` (声明 `mmu_lsu_stall_x`)

```systemverilog
      1132:         input logic mmu_lsu_ca_x,
      1133:         input logic mmu_lsu_sh_x,
      1134:         input logic mmu_lsu_so_x,
      1135: >>      input logic mmu_lsu_stall_x,
      1136:         input logic mmu_lsu_sec_x,
      1137:         input logic mmu_lsu_access_fault_x,
      1138:         input logic mmu_lsu_page_fault_x,
```

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `a_expt_entry_overlap_is_terminal_replay` | assertion | 412905614 | 0 | 1 |
| `cp_l1dtlb_expt_entry_overlap_replay` | cover | 412905614 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1172` (`a_expt_entry_overlap_is_terminal_replay`)

```systemverilog
      1168:       // RTL gives exception-CAM replay priority via dutlb_pre_sel.  A replay may
      1169:       // coincide with a stale/independent TLB entry hit for the same VPN; the
      1170:       // required behavior is that the request is completed as the replayed fault
      1171:       // and does not allocate a new miss or source stale entry PA.
      1172: >>    a_expt_entry_overlap_is_terminal_replay: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
      1173:         (lsu_mmu_va_vld_x && (|entry_hit_vec) && expt_match_x)
      1174:         |-> (mmu_lsu_pa_vld_x && !dutlb_miss_vld_x && !dutlb_miss_vld_short_x
      1175:              && (mmu_lsu_pa_x == mmu_sysmap_pa_x)));
      1176:     
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:1177` (`cp_l1dtlb_expt_entry_overlap_replay`)

```systemverilog
      1173:         (lsu_mmu_va_vld_x && (|entry_hit_vec) && expt_match_x)
      1174:         |-> (mmu_lsu_pa_vld_x && !dutlb_miss_vld_x && !dutlb_miss_vld_short_x
      1175:              && (mmu_lsu_pa_x == mmu_sysmap_pa_x)));
      1176:     
      1177: >>    cp_l1dtlb_expt_entry_overlap_replay: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
      1178:         lsu_mmu_va_vld_x && (|entry_hit_vec) && expt_match_x);
      1179:     
      1180:       a_abort_blocks_miss: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
      1181:         (lsu_mmu_va_vld_x && lsu_mmu_abort_x) |-> !dutlb_miss_vld_x);
```

## 模块 `mmu_l1dtlb_allocator_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`3`；合并后唯一代码对象数：`3`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input logic cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter int CREDIT_MAX  = 8
        18:     ) (
        19:         input logic forever_cpuclk,
        20: >>      input logic cpurst_b,
        21:     
        22:         input logic regs_utlb_clr,
        23:         input logic rtu_yy_xx_flush,
```

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `a_same_4k_dual_miss_dedup` | assertion | 206452807 | 0 | 1 |
| `cp_l1dtlb_c004_same_vpn_dedup` | cover | 206452807 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:573` (`a_same_4k_dual_miss_dedup`)

```systemverilog
       569:     
       570:       a_no_free_no_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       571:         (&mb_vld) |-> (!gnt0 && !gnt1 && alloc_we == '0));
       572:     
       573: >>    a_same_4k_dual_miss_dedup: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       574:         (req0_vld && req1_vld && (req0_vpn == req1_vpn) && (free_count(mb_vld) != 0))
       575:         |-> (gnt0 && !gnt1 && $countones(alloc_we) == 1));
       576:     
       577:       a_two_free_dual_diff_allocates_both: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:587` (`cp_l1dtlb_c004_same_vpn_dedup`)

```systemverilog
       583:     
       584:       a_single_req1_allocates_when_free: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       585:         (!req0_vld && req1_vld && (free_count(mb_vld) != 0)) |-> gnt1);
       586:     
       587: >>    cp_l1dtlb_c004_same_vpn_dedup: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       588:         req0_vld && req1_vld && (req0_vpn == req1_vpn) && gnt0 && !gnt1);
       589:     
       590:       cp_l1dtlb_c005_dual_diff_two_free: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
       591:         req0_vld && req1_vld && (req0_vpn != req1_vpn) && gnt0 && gnt1);
```

## 模块 `mmu_l1dtlb_scheduler_sva`

源码：`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv`
原始未覆盖记录数：`26`；合并后唯一代码对象数：`10`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input logic cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 57 | `mb_entry_vpn[2][11] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 13 |
| 57 | `mb_entry_vpn[2][20:19] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 57 | `mb_entry_vpn[5][1:0] -> input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| - | `Other bits of mb_entry_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 58 | `mb_entry_iid[3][1:0] -> input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 58 | `mb_entry_iid[5][0] -> input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 2 |
| - | `Other bits of mb_entry_iid[7:0][6:0]` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 63 | `mb_entry_store[3] -> input logic [MB_DEPTH-1:0]                 mb_entry_store,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 4 |
| 759 | `credit_cnt[4] -> input logic [$clog2(CREDIT_MAX+1):0] credit_cnt` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:         parameter int CREDIT_MAX  = 8
        18:     ) (
        19:         input logic forever_cpuclk,
        20: >>      input logic cpurst_b,
        21:     
        22:         input logic regs_utlb_clr,
        23:         input logic rtu_yy_xx_flush,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:57` (声明 `mb_entry_vpn`)

```systemverilog
        54:     
        55:         input logic [MB_DEPTH-1:0]                 mb_entry_vld,
        56:         input logic [MB_DEPTH-1:0][2:0]            mb_entry_state,
        57: >>      input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,
        58:         input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:58` (声明 `mb_entry_iid`)

```systemverilog
        55:         input logic [MB_DEPTH-1:0]                 mb_entry_vld,
        56:         input logic [MB_DEPTH-1:0][2:0]            mb_entry_state,
        57:         input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,
        58: >>      input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,
        59:         input logic [MB_DEPTH-1:0]                 mb_entry_issued,
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
        61:         input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:63` (声明 `mb_entry_store`)

```systemverilog
        60:         input logic [MB_DEPTH-1:0]                 mb_entry_ready,
        61:         input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
        62:         input logic [MB_DEPTH-1:0]                 mb_entry_wfi,
        63: >>      input logic [MB_DEPTH-1:0]                 mb_entry_store,
        64:     
        65:         input logic [NUM_ENTRY-1:0]                entry_vld,
        66:         input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
```

`mmu_verification/testbench/top/mmu_l1dtlb_sva.sv:759` (声明 `credit_cnt`)

```systemverilog
       756:         input logic dutlb_arb_store,
       757:         input logic [MB_DEPTH-1:0] issue_sel,
       758:         input logic issue_grant_out,
       759: >>      input logic [$clog2(CREDIT_MAX+1):0] credit_cnt
       760:     );
       761:     
       762:       function automatic logic [$clog2(MB_DEPTH)-1:0] first_ready(input logic [MB_DEPTH-1:0] v);
```

