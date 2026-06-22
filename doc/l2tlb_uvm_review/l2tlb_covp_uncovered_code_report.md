# L2TLB covp 未覆盖代码报告

本报告基于 `make covp` 生成的 URG 覆盖率报告：`mmu_verification/output/coverage/phase14_urgReport`。
- 原始 URG 数据源：`mmu_verification/output/coverage/phase14_merged.vdb`
- URG 命令：`urg -full64 -dir .../phase14_merged.vdb -elfile .../simu/exclude_v4.tgl -format both -report .../phase14_urgReport`
- 统计范围：`tb_top.u_dut.x_mmu_l2tlb` 子树下的所有实例（含 SVA 与子模块）。

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
| 行覆盖 | 2 | 2 |
| 条件覆盖 | 90 | 47 |
| 分支覆盖（含 MISSING_ELSE）| 2 | 2 |
| FSM 状态迁移覆盖 | 2 | 2 |
| 翻转覆盖 - 端口 | 120 | 83 |
| 翻转覆盖 - 内部信号 | 174 | 120 |
| 断言/cover 命中覆盖 | 7 | 7 |
| **合计** | **397** | **263** |

| 模块 | SCORE/LINE/COND/TOGGLE/FSM/BRANCH/ASSERT (%) | 未覆盖对象数 | 源码 |
| --- | --- | ---: | --- |
| `mmu_l2tlb` | 88.94/99.43/90.67/85.18/71.43/98.00/-- | 242 | `mmu/rtl/mmu_l2tlb.sv` |
| `mmu_l2tlb_reqq` | 97.24/100.00/97.63/91.32/--/100.00/-- | 21 | `mmu/rtl/mmu_l2tlb_reqq.sv` |
| `mmu_l2tlb_reqq_entry` | 93.67/100.00/100.00/74.67/--/100.00/-- | 8 | `mmu/rtl/mmu_l2tlb_reqq_entry.sv` |
| `mmu_l2tlb_replacement_policy` | 99.96/100.00/100.00/99.84/--/100.00/-- | 1 | `mmu/rtl/mmu_l2tlb_replacement_policy.sv` |
| `mmu_l2tlb_rrpv_wbuf` | 93.99/100.00/76.19/99.78/--/100.00/-- | 8 | `mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv` |
| `mmu_l2tlb_mb` | 95.53/100.00/93.06/89.04/--/100.00/-- | 29 | `mmu/rtl/mmu_l2tlb_mb.sv` |
| `mmu_l2tlb_mb_entry` | 95.08/100.00/94.12/86.19/--/100.00/-- | 11 | `mmu/rtl/mmu_l2tlb_mb_entry.sv` |
| `ct_mmu_l2tlb_rrpv_array` | 99.62/--/--/99.62/--/--/-- | 1 | `mmu/rtl/ct_mmu_l2tlb_rrpv_array.sv` |
| `ct_mmu_l2tlb_tag_array` | 90.21/--/--/90.21/--/--/-- | 49 | `mmu/rtl/ct_mmu_l2tlb_tag_array.sv` |
| `ct_mmu_l2tlb_data_array` | 91.47/--/--/91.47/--/--/-- | 20 | `mmu/rtl/ct_mmu_l2tlb_data_array.sv` |
| `mmu_l2tlb_rrpv_sva` | 96.00/--/--/--/--/--/96.00 | 1 | `mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv` |
| `mmu_l2tlb_mb_sva` | 86.96/--/--/--/--/--/86.96 | 3 | `mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv` |
| `mmu_l2tlb_rrpv_wbuf_sva` | 89.66/--/--/--/--/--/89.66 | 3 | `mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv` |

## 主要未覆盖模式分析

### 行覆盖缺口（语句从未执行）

- `mmu_l2tlb` `mmu/rtl/mmu_l2tlb.sv:1368` `pfu_nxt_st[1:0] = PFU_DENY;`

`mmu/rtl/mmu_l2tlb.sv:1368`

```systemverilog
      1365:         PFU_CHK: 
      1366:         begin
      1367:             if(l2tlb_pfu_deny)
      1368: >>              pfu_nxt_st[1:0] = PFU_DENY;
      1369:             else
      1370:                 pfu_nxt_st[1:0] = PFU_OK;
      1371:         end
```

- `mmu_l2tlb` `mmu/rtl/mmu_l2tlb.sv:1382` `pfu_nxt_st[1:0] = PFU_IDLE;`

`mmu/rtl/mmu_l2tlb.sv:1382`

```systemverilog
      1379:         end
      1380:         default:
      1381:         begin
      1382: >>          pfu_nxt_st[1:0] = PFU_IDLE;
      1383:         end
      1384:     endcase
      1385:     // &CombEnd; @950
```

### 条件覆盖缺口（按表达式模式聚合）

| 模块 | 行号 | 表达式（已聚合参数化条目） | 未覆盖组合（采样） | 影响条目数 |
| --- | ---: | --- | --- | ---: |
| `mmu_l2tlb` | 814 | `EXPRESSION (final_way_hit_kid0[0] & final_way_hit_kid1[0] & final_way_hit_kid2[0] & ((final_way_hit_kid3[0] & final_way_hit_kid4[0]) | final_way_hit_ki...` | 1 1 0 1 Not Covered; 1 0 1 1 Not Covered; 0 1 1 1 Not Covered | 11 |
| `mmu_l2tlb` | 814 | `SUB-EXPRESSION (final_way_hit_kid3[0] & final_way_hit_kid4[0])` | 1 0 Not Covered | 8 |
| `mmu_l2tlb` | 816 | `EXPRESSION (final_way_vld[0] & ((!final_way_g[0])) & (final_way_asid[0][(ASID_WIDTH - 1):0] == tlboper_l2tlb_inv_asid[(ASID_WIDTH - 1):0]))` | 1 0 1 Not Covered | 7 |
| `mmu_l2tlb` | 769 | `EXPRESSION (raw_way_g[0] || tlboper_l2tlb_cmp_noasid)` | 1 0 Not Covered | 5 |
| `mmu_l2tlb` | 1409 | `EXPRESSION (((!final_hit_flg[0])) || (((!final_hit_flg[1])) && final_hit_flg[2]) || (((!final_hit_flg[1])) && ( ! (cp0_mmu_mxr && final_hit_flg[3]) )) ...` | 0 0 0 0 0 1 0 Not Covered; 0 0 1 0 0 0 0 Not Covered; 0 1 0 0 0 0 0 Not Covered; ... 共 4 种组合 | 4 |
| `mmu_l2tlb_reqq` | 203 | `EXPRESSION (fb_valid && (fb_trans_id == 4[(ID_W - 1):0]))` | 0 1 Not Covered | 4 |
| `mmu_l2tlb_rrpv_wbuf` | 129 | `SUB-EXPRESSION (((!push_new_entry)) || ((!fifo_full)) || pop_do)` | 0 0 0 Not Covered; 0 0 1 Not Covered; 1 0 0 Not Covered | 3 |
| `mmu_l2tlb` | 553 | `EXPRESSION (arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b101) & arb_l2tlb_write)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l2tlb` | 1041 | `EXPRESSION (arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b101) & arb_l2tlb_write)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l2tlb` | 1204 | `SUB-EXPRESSION (final_vld & ((!cp0_mmu_ptw_en)) & l2tlb_miss & (final_acc_type[1:0] == 2'b10))` | 0 1 1 1 Not Covered; 1 1 0 1 Not Covered | 2 |
| `mmu_l2tlb` | 1409 | `SUB-EXPRESSION (final_hit_flg[4] && cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered; 1 1 0 Not Covered | 2 |
| `mmu_l2tlb` | 1409 | `SUB-EXPRESSION (final_hit_flg[13] || ((!final_hit_flg[12])))` | 0 0 Not Covered; 1 0 Not Covered | 2 |
| `mmu_l2tlb` | 1409 | `SUB-EXPRESSION (sysmap_mmu_flg4[4] || ((!sysmap_mmu_flg4[3])))` | 0 1 Not Covered; 1 0 Not Covered | 2 |
| `mmu_l2tlb` | 1418 | `SUB-EXPRESSION (lsu_mmu_va2_vld && l1dtlb_xx_mmu_off && (sysmap_mmu_flg4[4] || ((!sysmap_mmu_flg4[3]))))` | 0 1 1 Not Covered; 1 1 1 Not Covered | 2 |
| `mmu_l2tlb` | 1418 | `SUB-EXPRESSION (sysmap_mmu_flg4[4] || ((!sysmap_mmu_flg4[3])))` | 0 1 Not Covered; 1 0 Not Covered | 2 |
| `mmu_l2tlb` | 555 | `EXPRESSION (arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b1) & arb_l2tlb_write & arb_l2tlb_tag_din[(TAG_WIDTH - 1)])` | 0 1 1 1 Not Covered | 1 |
| `mmu_l2tlb` | 869 | `EXPRESSION ((final_hit_sum[2:0] == 3'b1) & final_cmp_with_va & ((!final_par_fail)))` | 1 1 0 Not Covered | 1 |
| `mmu_l2tlb` | 870 | `EXPRESSION (final_cmp_with_va & ((!final_tlb_miss)) & ((!final_tlb_hit)) & ((!final_par_fail)))` | 1 1 1 0 Not Covered | 1 |
| `mmu_l2tlb` | 872 | `EXPRESSION ((final_vld & final_cmp_with_va & final_tlb_miss) | final_par_fail)` | 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 934 | `EXPRESSION (final_vld & final_cmp_with_va & ((final_acc_type[2:0] == 3'b010) | (final_acc_type[2:0] == 3'b110) | (final_acc_type[2:0] == 3'b011)))` | 1 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 939 | `EXPRESSION (final_vld & final_cmp_with_va & (final_acc_type[2:0] == 3'b100))` | 1 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 1005 | `EXPRESSION (mb_issue_req & cp0_mmu_ptw_en)` | 1 0 Not Covered | 1 |
| `mmu_l2tlb` | 1021 | `SUB-EXPRESSION (final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid)` | 1 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 1031 | `EXPRESSION (final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid)` | 1 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 1167 | `EXPRESSION (final_vld & final_cmp_with_va & ((!final_par_fail)) & (((!cp0_mmu_ptw_en)) | ((!final_tlb_miss))))` | 1 1 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 1186 | `SUB-EXPRESSION (final_vld & ((!cp0_mmu_ptw_en)) & l2tlb_miss & (final_acc_type[2:0] == 3'b011))` | 0 1 1 1 Not Covered | 1 |
| `mmu_l2tlb` | 1234 | `SUB-EXPRESSION (cp0_mach_mode && ((!pmp_mmu_flg4[3])))` | 1 0 Not Covered | 1 |
| `mmu_l2tlb` | 1409 | `SUB-EXPRESSION (((!final_hit_flg[1])) && final_hit_flg[2])` | 1 1 Not Covered | 1 |
| `mmu_l2tlb` | 1409 | `SUB-EXPRESSION (((!final_hit_flg[1])) && ( ! (cp0_mmu_mxr && final_hit_flg[3]) ))` | 1 0 Not Covered | 1 |
| `mmu_l2tlb` | 1409 | `SUB-EXPRESSION (((!final_hit_flg[4])) && cp0_user_mode)` | 0 1 Not Covered | 1 |
| `mmu_l2tlb` | 1418 | `EXPRESSION ((final_vld && (final_tlb_hit_mult || (((!cp0_mmu_ptw_en)) && l2tlb_miss)) && (final_acc_type[2:0] == 3'b100)) || (final_pa_vld && (final_ac...` | 0 0 1 0 Not Covered | 1 |
| `mmu_l2tlb` | 1418 | `SUB-EXPRESSION (ptw_l2tlb_ref_flg[13] || ((!ptw_l2tlb_ref_flg[12])) || ptw_l2tlb_ref_pgflt || ptw_l2tlb_ref_acc_err)` | 0 0 1 0 Not Covered | 1 |
| `mmu_l2tlb_rrpv_wbuf` | 129 | `EXPRESSION (push_req && (((!push_new_entry)) || ((!fifo_full)) || pop_do))` | 1 0 Not Covered | 1 |
| `mmu_l2tlb_rrpv_wbuf` | 134 | `EXPRESSION (count == DEPTH)` | 1 Not Covered | 1 |
| `mmu_l2tlb_mb` | 135 | `SUB-EXPRESSION (req_valid & req_is_dtlb & ((!mb_dtlb_full)))` | 1 1 0 Not Covered | 1 |
| `mmu_l2tlb_mb` | 215 | `EXPRESSION (entry_rdy_vec[4] | ffr_therm[(4 - 1)])` | 1 0 Not Covered | 1 |
| `mmu_l2tlb_mb` | 215 | `EXPRESSION (entry_rdy_vec[5] | ffr_therm[(5 - 1)])` | 1 0 Not Covered | 1 |
| `mmu_l2tlb_mb` | 215 | `EXPRESSION (entry_rdy_vec[6] | ffr_therm[(6 - 1)])` | 1 0 Not Covered | 1 |
| `mmu_l2tlb_mb` | 215 | `EXPRESSION (entry_rdy_vec[7] | ffr_therm[(7 - 1)])` | 1 0 Not Covered | 1 |
| `mmu_l2tlb_mb` | 215 | `EXPRESSION (entry_rdy_vec[8] | ffr_therm[(8 - 1)])` | 1 0 Not Covered | 1 |
| `mmu_l2tlb_mb` | 220 | `EXPRESSION (ffr_therm[4] & ((~ffr_therm[(4 - 1)])))` | 1 1 Not Covered | 1 |
| `mmu_l2tlb_mb` | 220 | `EXPRESSION (ffr_therm[5] & ((~ffr_therm[(5 - 1)])))` | 1 1 Not Covered | 1 |
| `mmu_l2tlb_mb` | 220 | `EXPRESSION (ffr_therm[6] & ((~ffr_therm[(6 - 1)])))` | 1 1 Not Covered | 1 |
| `mmu_l2tlb_mb` | 220 | `EXPRESSION (ffr_therm[7] & ((~ffr_therm[(7 - 1)])))` | 1 1 Not Covered | 1 |
| `mmu_l2tlb_mb` | 220 | `EXPRESSION (ffr_therm[8] & ((~ffr_therm[(8 - 1)])))` | 1 1 Not Covered | 1 |
| `mmu_l2tlb_mb` | 227 | `EXPRESSION (req_valid & ((|alloc_en_vec)))` | 0 1 Not Covered | 1 |
| `mmu_l2tlb_mb_entry` | 110 | `EXPRESSION (fb_match_id && fb_hit)` | 1 0 Not Covered | 1 |

### FSM 状态迁移缺口

| 模块 | FSM | 未覆盖迁移 | 行号 |
| --- | --- | --- | ---: |
| `mmu_l2tlb` | `pfu_cur_st` | `PFU_CHK->PFU_DENY` | 1368 |
| `mmu_l2tlb` | `pfu_cur_st` | `PFU_CHK->PFU_IDLE` | 1347 |

`mmu/rtl/mmu_l2tlb.sv:1368` (pfu_cur_st FSM 的 `PFU_CHK->PFU_DENY` 迁移):

```systemverilog
      1364:         end
      1365:         PFU_CHK: 
      1366:         begin
      1367:             if(l2tlb_pfu_deny)
      1368: >>              pfu_nxt_st[1:0] = PFU_DENY;
      1369:             else
      1370:                 pfu_nxt_st[1:0] = PFU_OK;
      1371:         end
      1372:         PFU_DENY: 
```

### 断言/cover 命中缺口（按名称模式聚合）

| 模块 | 名称（已聚合） | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | --- | ---: | ---: | ---: |
| `mmu_l2tlb_rrpv_sva` | `c_l2tlb_ptw_reselect_under_backpressure` | cover | 206452807 | 0 | 1 |
| `mmu_l2tlb_mb_sva` | `a_dtlb_full_no_overwrite` | assertion | 206452807 | 0 | 1 |
| `mmu_l2tlb_mb_sva` | `a_itlb_full_no_overwrite` | assertion | 206452807 | 0 | 1 |
| `mmu_l2tlb_mb_sva` | `c_mb_issue_reselect_under_backpressure` | cover | 206452807 | 0 | 1 |
| `mmu_l2tlb_rrpv_wbuf_sva` | `a_cam_hit_only_push_may_accept_when_full` | assertion | 206452807 | 0 | 1 |
| `mmu_l2tlb_rrpv_wbuf_sva` | `a_true_full_blocks_new_entry_without_pop` | assertion | 206452807 | 0 | 1 |
| `mmu_l2tlb_rrpv_wbuf_sva` | `c_rrpv_wbuf_true_full_block` | cover | 206452807 | 0 | 1 |

### 翻转覆盖 - 端口（按信号模式聚合）

| 模块 | 端口（已聚合参数化位段） | 影响条目数 | Toggle No | 1->0 No | 0->1 No | 方向 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `ct_mmu_l2tlb_tag_array` | `l2tlb_tag_dout[0]` | 25 | 25 | 25 | 25 | OUTPUT |
| `ct_mmu_l2tlb_data_array` | `l2tlb_data_dout[130]` | 10 | 10 | 10 | 10 | OUTPUT |
| `mmu_l2tlb` | `arb_l2tlb_tag_din[18]` | 2 | 2 | 2 | 2 | INPUT |
| `mmu_l2tlb` | `mmu_lsu_pa2[10]` | 2 | 2 | 2 | 1 | OUTPUT |
| `mmu_l2tlb` | `mmu_pmp_pa4[10]` | 2 | 2 | 2 | 1 | OUTPUT |
| `ct_mmu_l2tlb_tag_array` | `l2tlb_tag_din[18]` | 2 | 2 | 2 | 2 | INPUT |
| `mmu_l2tlb` | `cpurst_b` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l2tlb` | `pad_yy_icg_scan_en` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb` | `cp0_mmu_mpp[0]` | 1 | 1 | 0 | 1 | INPUT |
| `mmu_l2tlb` | `regs_l2tlb_cur_asid[15:5]` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l2tlb` | `l2tlb_arb_pfu_miss_mb_full` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `queue_arb_acc_type[1]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `arb_l2tlb_data_din[37:35]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb` | `ptw_l2tlb_ref_vpn[26]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb` | `ptw_l2tlb_ref_ppn[23:21]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb` | `l2tlb_l1tlb_ref_ppn[20]` | 1 | 1 | 1 | 0 | OUTPUT |
| `mmu_l2tlb` | `l2tlb_l1tlb_ref_ppn[23:21]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `l2tlb_l1tlb_ref_ppn[27:24]` | 1 | 1 | 1 | 0 | OUTPUT |
| `mmu_l2tlb` | `mmu_lsu_pa2[27:20]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `mmu_lsu_sec2` | 1 | 1 | 1 | 0 | OUTPUT |
| `mmu_l2tlb` | `tlboper_xx_pgs[2:1]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb` | `l2tlb_tlbr_asid[14]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `l2tlb_tlbr_ppn[20]` | 1 | 1 | 1 | 0 | OUTPUT |
| `mmu_l2tlb` | `l2tlb_tlbr_ppn[23:21]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `l2tlb_tlbr_ppn[27:24]` | 1 | 1 | 1 | 0 | OUTPUT |
| `mmu_l2tlb` | `l2tlb_tlbr_vpn[26]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `pmp_mmu_flg4[3]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb` | `mmu_pmp_pa4[27:20]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb` | `sysmap_mmu_flg4[0]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq` | `cpurst_b` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l2tlb_reqq` | `pad_yy_icg_scan_en` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq` | `d_req_type[1:0]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq` | `issue_type[1]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb_reqq` | `fb_miss_retry` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq_entry` | `cpurst_b` | 1 | 1 | 1 | 0 | INPUT |
| `mmu_l2tlb_reqq_entry` | `pad_yy_icg_scan_en` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq_entry` | `alloc_type[1:0]` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq_entry` | `fb_miss_retry` | 1 | 1 | 1 | 1 | INPUT |
| `mmu_l2tlb_reqq_entry` | `entry_out_asid[15:0]` | 1 | 1 | 1 | 1 | OUTPUT |
| `mmu_l2tlb_reqq_entry` | `entry_out_type[1:0]` | 1 | 1 | 1 | 0 | OUTPUT |
| ... | ... （其余 43 个模式见下方分模块详情） | ... | ... | ... | ... | ... |

### 翻转覆盖 - 内部信号（按信号模式聚合）

| 模块 | 信号（已聚合参数化位段） | 影响条目数 | Toggle No | 1->0 No | 0->1 No |
| --- | --- | ---: | ---: | ---: | ---: |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[0]` | 25 | 25 | 25 | 25 |
| `mmu_l2tlb` | `l2tlb_data_dout_bus[130]` | 10 | 10 | 10 | 10 |
| `mmu_l2tlb_mb` | `gen_entries[0].local_alloc_l2_queue_id[3:0]` | 9 | 9 | 9 | 9 |
| `mmu_l2tlb_reqq` | `gen_entries[1].local_alloc_type[1:0]` | 8 | 8 | 8 | 8 |
| `mmu_l2tlb` | `final_way_ppn[1][10]` | 3 | 3 | 3 | 0 |
| `mmu_l2tlb` | `raw_tag[18]` | 2 | 2 | 2 | 2 |
| `mmu_l2tlb` | `final_way_asid[1][0]` | 2 | 2 | 2 | 0 |
| `mmu_l2tlb` | `final_way_flg[1][4]` | 2 | 2 | 2 | 0 |
| `mmu_l2tlb` | `pfu_pa_buf[10]` | 2 | 2 | 2 | 1 |
| `mmu_l2tlb` | `l2tlb_reqq_fb_miss_retry` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `arb_l2tlb_req_internal` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `arb_l2tlb_vpn_internal[26:0]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `arb_l2tlb_trans_id_internal[3:0]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `arb_l2tlb_eid_internal[2:0]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `arb_l2tlb_type[2:0]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `fb_hit` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `fb_miss_alloc` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `fb_miss_retry` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[19:16]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[59:55]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[67:63]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[152:151]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[156:155]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[163:159]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[211:204]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[238:236]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[245:244]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[252:251]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[255:254]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[259:257]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[268:267]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[283:282]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[286:285]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[292:291]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[296:295]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[307:303]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[334:332]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[355:351]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_tag_dout_bus[382:381]` | 1 | 1 | 1 | 1 |
| `mmu_l2tlb` | `l2tlb_data_dout_bus[41:34]` | 1 | 1 | 1 | 1 |
| ... | ... （其余 80 个模式见下方分模块详情） | ... | ... | ... | ... |

---

## 结论与覆盖建议

### 翻转覆盖薄弱模块（按未翻转对象数排序）

| 模块 | 未翻转对象数 | 模块级 TOGGLE 覆盖率 |
| --- | ---: | ---: |
| `mmu_l2tlb` | 168 | 85.18 |
| `ct_mmu_l2tlb_tag_array` | 49 | 90.21 |
| `ct_mmu_l2tlb_data_array` | 20 | 91.47 |
| `mmu_l2tlb_reqq` | 17 | 91.32 |
| `mmu_l2tlb_mb` | 17 | 89.04 |
| `mmu_l2tlb_mb_entry` | 10 | 86.19 |
| `mmu_l2tlb_reqq_entry` | 8 | 74.67 |
| `mmu_l2tlb_rrpv_wbuf` | 3 | 99.78 |
| `mmu_l2tlb_replacement_policy` | 1 | 99.84 |
| `ct_mmu_l2tlb_rrpv_array` | 1 | 99.62 |

### 条件覆盖薄弱模块（按未覆盖表达式数排序）

| 模块 | 未覆盖表达式数 | 模块级 COND 覆盖率 |
| --- | ---: | ---: |
| `mmu_l2tlb` | 68 | 90.67 |
| `mmu_l2tlb_mb` | 12 | 93.06 |
| `mmu_l2tlb_rrpv_wbuf` | 5 | 76.19 |
| `mmu_l2tlb_reqq` | 4 | 97.63 |
| `mmu_l2tlb_mb_entry` | 1 | 94.12 |

### 主要结论

- **L2TLB 整体未覆盖对象主要集中在 `mmu_l2tlb` 主模块**，其他子模块（reqq/mb/rrpv_wbuf 等）缺口较少。主要表现为：
  - **翻转覆盖（TOGGLE）缺口最多**：`ct_mmu_l2tlb_tag_array` 的 `l2tlb_tag_dout[0]`（25 个位段）、`ct_mmu_l2tlb_data_array` 的 `l2tlb_data_dout[130]`（10 个位段）等 SRAM 输出位从未翻转；`mmu_l2tlb` 内部 `l2tlb_*_ppn[27:20]`、`mmu_lsu_pa2[27:20]`、`mmu_pmp_pa4[27:20]` 等高位 PPN 位段未翻转，反映现有用例使用的高位物理地址不够分散。
  - **条件覆盖（COND）缺口**集中在 `mmu_l2tlb` line 814（`final_way_hit_kid0..4` 多 way 命中表达式，影响 11 个实例）、line 1409（`final_hit_flg`/权限检查组合，影响多种权限/异常组合）、line 553/555/1041（`arb_l2tlb_acc_type == 3'b101/3'b1` 等 arbiter 写/安装类型）、line 769（`raw_way_g[0] || tlboper_l2tlb_cmp_noasid` 全局匹配/asid 比较旁路）、line 1005/1021/1031（`mb_issue_req/final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid` PTW miss miss 流水）。
  - **行覆盖（LINE）缺口**：line 1368 `pfu_nxt_st = PFU_DENY` 与 line 1382 FSM default `pfu_nxt_st = PFU_IDLE`，对应 PFU（预取单元）的 deny 与异常返回路径。
  - **FSM 迁移缺口**：`pfu_cur_st` 的 `PFU_CHK -> PFU_DENY` 与 `PFU_CHK -> PFU_IDLE`，对应 prefetch check 后拒绝/直接回 idle 的迁移。
  - **断言/cover 命中缺口**：`mmu_l2tlb_rrpv_wbuf_sva` 的 3 个 assertion/cover（`a_cam_hit_only_push_may_accept_when_full`、`a_true_full_blocks_new_entry_without_pop`、`c_rrpv_wbuf_true_full_block`）从未命中，反映 rrpv_wbuf 真满 + CAM 命中/新 entry 的场景未构造；`mmu_l2tlb_mb_sva` 的 dtlb/itlb full 不可覆盖 assertion 与 mb issue backpressure cover 未命中。

### 建议的定向激励

1. **高位 PPN/PA 翻转**：构造用例让 `l2tlb_*_ppn[27:20]`、`mmu_lsu_pa2[27:20]`、`mmu_pmp_pa4[27:20]`、`ptw_l2tlb_ref_ppn[23:21]` 等高位物理地址位段经历 0->1 与 1->0；同时让 `ct_mmu_l2tlb_tag_array`/`data_array` 各数据位都被实际写入并读出。
2. **多 way 命中组合**：针对 line 814 `final_way_hit_kid0..4` 的 5-way 命中表达式，构造不同 way 命中分布的用例，覆盖 `1 1 0 1`、`1 0 1 1`、`0 1 1 1` 等组合。
3. **PFU deny 路径**：激励 `l2tlb_pfu_deny=1`，覆盖 FSM `PFU_CHK -> PFU_DENY` 迁移以及 line 1368 的 `pfu_nxt_st = PFU_DENY`；并构造 FSM 异常状态回到 `PFU_IDLE`（覆盖 line 1382 default）。
4. **权限/异常 flg 组合**：针对 line 1409 `final_hit_flg` 与 `sysmap_mmu_flg4` 的多 term 组合，构造 sum/mxr/supv/user 不同权限与权限错误同时命中的场景。
5. **arbiter 写/安装类型**：激励 `arb_l2tlb_acc_type == 3'b101`（write/install）、`3'b1`（write tag）配合 `arb_l2tlb_write=1` 与 `arb_l2tlb_tag_din[TAG_WIDTH-1]` 的 0/1 组合，闭合 line 553/555/1041。
6. **rrpv_wbuf 满场景**：构造 rrpv_wbuf 真满（`fifo_full`/`count==DEPTH`）时 CAM 命中 push、新 entry push、pop 的组合，闭合 `a_cam_hit_only_push_may_accept_when_full`、`a_true_full_blocks_new_entry_without_pop`、`c_rrpv_wbuf_true_full_block`。
7. **MB dtlb/itlb full**：构造 L2TLB miss buffer dtlb/itlb 满（`mb_dtlb_full`/`mb_itlb_full`）后不再被覆盖的场景，闭合 `a_dtlb_full_no_overwrite`、`a_itlb_full_no_overwrite`、`c_mb_issue_reselect_under_backpressure`。

---

## 分模块详情

## 模块 `mmu_l2tlb`

源码：`mmu/rtl/mmu_l2tlb.sv`
原始未覆盖记录数：`242`；合并后唯一代码对象数：`162`。

### 行覆盖

说明：这里列出执行次数不足的 RTL/SVA 语句；后面的代码块用 `>>` 标出对应源码行。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 1368 | `pfu_nxt_st[1:0] = PFU_DENY;` | 0/N |
| 1382 | `pfu_nxt_st[1:0] = PFU_IDLE;` | 0/N |

`mmu/rtl/mmu_l2tlb.sv:1368`

```systemverilog
      1364:         end
      1365:         PFU_CHK: 
      1366:         begin
      1367:             if(l2tlb_pfu_deny)
      1368: >>              pfu_nxt_st[1:0] = PFU_DENY;
      1369:             else
      1370:                 pfu_nxt_st[1:0] = PFU_OK;
      1371:         end
      1372:         PFU_DENY: 
```

`mmu/rtl/mmu_l2tlb.sv:1382`

```systemverilog
      1378:             pfu_nxt_st[1:0] = PFU_IDLE;
      1379:         end
      1380:         default:
      1381:         begin
      1382: >>          pfu_nxt_st[1:0] = PFU_IDLE;
      1383:         end
      1384:     endcase
      1385:     // &CombEnd; @950
      1386:     end
```

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 553 | `EXPRESSION (arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b101) & arb_l2tlb_write)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| 555 | `EXPRESSION (arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b1) & arb_l2tlb_write & arb_l2tlb_tag_din[(TAG_WIDTH - 1)])` | 0 1 1 1 Not Covered | 1 |
| 769 | `EXPRESSION (raw_way_g[0] || tlboper_l2tlb_cmp_noasid)` | 1 0 Not Covered | 5 |
| 814 | `EXPRESSION (final_way_hit_kid0[0] & final_way_hit_kid1[0] & final_way_hit_kid2[0] & ((final_way_hit_kid3[0] & final_way_hit_kid4[0]) | final_way_hit_kid5[0]))` | 1 1 0 1 Not Covered; 1 0 1 1 Not Covered; 0 1 1 1 Not Covered | 11 |
| 814 | `SUB-EXPRESSION (final_way_hit_kid3[0] & final_way_hit_kid4[0])` | 1 0 Not Covered | 8 |
| 816 | `EXPRESSION (final_way_vld[0] & ((!final_way_g[0])) & (final_way_asid[0][(ASID_WIDTH - 1):0] == tlboper_l2tlb_inv_asid[(ASID_WIDTH - 1):0]))` | 1 0 1 Not Covered | 7 |
| 869 | `EXPRESSION ((final_hit_sum[2:0] == 3'b1) & final_cmp_with_va & ((!final_par_fail)))` | 1 1 0 Not Covered | 1 |
| 870 | `EXPRESSION (final_cmp_with_va & ((!final_tlb_miss)) & ((!final_tlb_hit)) & ((!final_par_fail)))` | 1 1 1 0 Not Covered | 1 |
| 872 | `EXPRESSION ((final_vld & final_cmp_with_va & final_tlb_miss) | final_par_fail)` | 0 1 Not Covered | 1 |
| 934 | `EXPRESSION (final_vld & final_cmp_with_va & ((final_acc_type[2:0] == 3'b010) | (final_acc_type[2:0] == 3'b110) | (final_acc_type[2:0] == 3'b011)))` | 1 0 1 Not Covered | 1 |
| 939 | `EXPRESSION (final_vld & final_cmp_with_va & (final_acc_type[2:0] == 3'b100))` | 1 0 1 Not Covered | 1 |
| 1005 | `EXPRESSION (mb_issue_req & cp0_mmu_ptw_en)` | 1 0 Not Covered | 1 |
| 1021 | `SUB-EXPRESSION (final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid)` | 1 0 1 Not Covered | 1 |
| 1031 | `EXPRESSION (final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid)` | 1 0 1 Not Covered | 1 |
| 1041 | `EXPRESSION (arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b101) & arb_l2tlb_write)` | 0 1 1 Not Covered; 1 1 0 Not Covered | 2 |
| 1167 | `EXPRESSION (final_vld & final_cmp_with_va & ((!final_par_fail)) & (((!cp0_mmu_ptw_en)) | ((!final_tlb_miss))))` | 1 1 0 1 Not Covered | 1 |
| 1186 | `SUB-EXPRESSION (final_vld & ((!cp0_mmu_ptw_en)) & l2tlb_miss & (final_acc_type[2:0] == 3'b011))` | 0 1 1 1 Not Covered | 1 |
| 1204 | `SUB-EXPRESSION (final_vld & ((!cp0_mmu_ptw_en)) & l2tlb_miss & (final_acc_type[1:0] == 2'b10))` | 0 1 1 1 Not Covered; 1 1 0 1 Not Covered | 2 |
| 1234 | `SUB-EXPRESSION (cp0_mach_mode && ((!pmp_mmu_flg4[3])))` | 1 0 Not Covered | 1 |
| 1409 | `EXPRESSION (((!final_hit_flg[0])) || (((!final_hit_flg[1])) && final_hit_flg[2]) || (((!final_hit_flg[1])) && ( ! (cp0_mmu_mxr && final_hit_flg[3]) )) || (final_hit_flg[4]...` | 0 0 0 0 0 1 0 Not Covered; 0 0 1 0 0 0 0 Not Covered; 0 1 0 0 0 0 0 Not Covered; ... 共 4 种 | 4 |
| 1409 | `SUB-EXPRESSION (((!final_hit_flg[1])) && final_hit_flg[2])` | 1 1 Not Covered | 1 |
| 1409 | `SUB-EXPRESSION (((!final_hit_flg[1])) && ( ! (cp0_mmu_mxr && final_hit_flg[3]) ))` | 1 0 Not Covered | 1 |
| 1409 | `SUB-EXPRESSION (final_hit_flg[4] && cp0_supv_mode && ((!cp0_mmu_sum)))` | 1 0 1 Not Covered; 1 1 0 Not Covered | 2 |
| 1409 | `SUB-EXPRESSION (((!final_hit_flg[4])) && cp0_user_mode)` | 0 1 Not Covered | 1 |
| 1409 | `SUB-EXPRESSION (final_hit_flg[13] || ((!final_hit_flg[12])))` | 0 0 Not Covered; 1 0 Not Covered | 2 |
| 1409 | `SUB-EXPRESSION (sysmap_mmu_flg4[4] || ((!sysmap_mmu_flg4[3])))` | 0 1 Not Covered; 1 0 Not Covered | 2 |
| 1418 | `EXPRESSION ((final_vld && (final_tlb_hit_mult || (((!cp0_mmu_ptw_en)) && l2tlb_miss)) && (final_acc_type[2:0] == 3'b100)) || (final_pa_vld && (final_acc_type[2:0] == 3'b10...` | 0 0 1 0 Not Covered | 1 |
| 1418 | `SUB-EXPRESSION (lsu_mmu_va2_vld && l1dtlb_xx_mmu_off && (sysmap_mmu_flg4[4] || ((!sysmap_mmu_flg4[3]))))` | 0 1 1 Not Covered; 1 1 1 Not Covered | 2 |
| 1418 | `SUB-EXPRESSION (sysmap_mmu_flg4[4] || ((!sysmap_mmu_flg4[3])))` | 0 1 Not Covered; 1 0 Not Covered | 2 |
| 1418 | `SUB-EXPRESSION (ptw_l2tlb_ref_flg[13] || ((!ptw_l2tlb_ref_flg[12])) || ptw_l2tlb_ref_pgflt || ptw_l2tlb_ref_acc_err)` | 0 0 1 0 Not Covered | 1 |

`mmu/rtl/mmu_l2tlb.sv:553`

```systemverilog
       550:         
       551:         // Write when WBUF has data and is granted
       552:         assign rrpv_write_en = rrpv_write_ptw | rrpv_write_lookup | rrpv_write_tlboper;
       553: >>      assign rrpv_write_ptw = arb_l2tlb_req & arb_l2tlb_acc_type == 3'b101 & arb_l2tlb_write;
       554:         assign rrpv_write_lookup = !wbuf_empty && wbuf_pop_grant;
       555:         assign rrpv_write_tlboper = arb_l2tlb_req
       556:                                   & (arb_l2tlb_acc_type == 3'b001)
```

`mmu/rtl/mmu_l2tlb.sv:555`

```systemverilog
       552:         assign rrpv_write_en = rrpv_write_ptw | rrpv_write_lookup | rrpv_write_tlboper;
       553:         assign rrpv_write_ptw = arb_l2tlb_req & arb_l2tlb_acc_type == 3'b101 & arb_l2tlb_write;
       554:         assign rrpv_write_lookup = !wbuf_empty && wbuf_pop_grant;
       555: >>      assign rrpv_write_tlboper = arb_l2tlb_req
       556:                                   & (arb_l2tlb_acc_type == 3'b001)
       557:                                   & arb_l2tlb_write
       558:                                   & arb_l2tlb_tag_din[TAG_WIDTH-1];
```

`mmu/rtl/mmu_l2tlb.sv:769`

```systemverilog
       766:                                              && raw_way_vld[i];// && ta_cmp_va;
       767:                 assign raw_way_hit_kid3[i] = (raw_way_asid[i][VPN_PERLEL*1-1:0]   == asid_for_va_hit[VPN_PERLEL*1-1:0]);
       768:                 assign raw_way_hit_kid4[i] = (raw_way_asid[i][ASID_WIDTH-1:VPN_PERLEL*1]  == asid_for_va_hit[ASID_WIDTH-1:VPN_PERLEL*1]);
       769: >>              assign raw_way_hit_kid5[i] =  raw_way_g[i] || tlboper_l2tlb_cmp_noasid;
       770:     
       771:     
       772:                //way final hit logic
```

`mmu/rtl/mmu_l2tlb.sv:814`

```systemverilog
       811:                     end
       812:                 end
       813:     
       814: >>              assign final_way_hit[i] = final_way_hit_kid0[i] & final_way_hit_kid1[i] & final_way_hit_kid2[i] 
       815:                                  & (final_way_hit_kid3[i] & final_way_hit_kid4[i] | final_way_hit_kid5[i]);
       816:                 assign final_way_asid_hit[i] = final_way_vld[i]
       817:                                              & !final_way_g[i]
```

`mmu/rtl/mmu_l2tlb.sv:816`

```systemverilog
       813:     
       814:                 assign final_way_hit[i] = final_way_hit_kid0[i] & final_way_hit_kid1[i] & final_way_hit_kid2[i] 
       815:                                  & (final_way_hit_kid3[i] & final_way_hit_kid4[i] | final_way_hit_kid5[i]);
       816: >>              assign final_way_asid_hit[i] = final_way_vld[i]
       817:                                              & !final_way_g[i]
       818:                                              & (final_way_asid[i][ASID_WIDTH-1:0] == tlboper_l2tlb_inv_asid[ASID_WIDTH-1:0]);
       819:                 assign final_way_sel[i] = final_way_hit[i] | tlboper_way_sel[i]   ;// | tlb operation
```

`mmu/rtl/mmu_l2tlb.sv:869`

```systemverilog
       866:         assign l2tlb_arb_par_clr  = final_par_fail;
       867:     
       868:         assign final_tlb_miss     = (final_hit_sum[2:0] == 3'b000);
       869: >>      assign final_tlb_hit      = (final_hit_sum[2:0] == 3'b001) & final_cmp_with_va & !final_par_fail;
       870:         assign final_tlb_hit_mult = final_cmp_with_va & !final_tlb_miss & !final_tlb_hit & !final_par_fail;
       871:     
       872:         assign l2tlb_miss = (final_vld & final_cmp_with_va & final_tlb_miss | final_par_fail); //|| final_vld && final_cmp_va && !final_tlb_miss && final_par_fail;
```

`mmu/rtl/mmu_l2tlb.sv:870`

```systemverilog
       867:     
       868:         assign final_tlb_miss     = (final_hit_sum[2:0] == 3'b000);
       869:         assign final_tlb_hit      = (final_hit_sum[2:0] == 3'b001) & final_cmp_with_va & !final_par_fail;
       870: >>      assign final_tlb_hit_mult = final_cmp_with_va & !final_tlb_miss & !final_tlb_hit & !final_par_fail;
       871:     
       872:         assign l2tlb_miss = (final_vld & final_cmp_with_va & final_tlb_miss | final_par_fail); //|| final_vld && final_cmp_va && !final_tlb_miss && final_par_fail;
       873:     
```

`mmu/rtl/mmu_l2tlb.sv:872`

```systemverilog
       869:         assign final_tlb_hit      = (final_hit_sum[2:0] == 3'b001) & final_cmp_with_va & !final_par_fail;
       870:         assign final_tlb_hit_mult = final_cmp_with_va & !final_tlb_miss & !final_tlb_hit & !final_par_fail;
       871:     
       872: >>      assign l2tlb_miss = (final_vld & final_cmp_with_va & final_tlb_miss | final_par_fail); //|| final_vld && final_cmp_va && !final_tlb_miss && final_par_fail;
       873:     
       874:         assign l2tlb_mb_req = l2tlb_miss;
       875:     
```

`mmu/rtl/mmu_l2tlb.sv:934`

```systemverilog
       931:         //==========================================================
       932:         logic [L2EID_WIDTH-1:0] l2mb_feedback_eid;
       933:     
       934: >>      assign final_reqq_req = final_vld
       935:                                & final_cmp_with_va
       936:                                & ((final_acc_type[2:0] == 3'b010)
       937:                                |  (final_acc_type[2:0] == 3'b110)
```

`mmu/rtl/mmu_l2tlb.sv:939`

```systemverilog
       936:                                & ((final_acc_type[2:0] == 3'b010)
       937:                                |  (final_acc_type[2:0] == 3'b110)
       938:                                |  (final_acc_type[2:0] == 3'b011));
       939: >>      assign final_pfu_req  = final_vld
       940:                                & final_cmp_with_va
       941:                                & (final_acc_type[2:0] == 3'b100);
       942:     
```

`mmu/rtl/mmu_l2tlb.sv:1005`

```systemverilog
      1002:     
      1003:     
      1004:         // Connect MB Outputs to Top-Level PTW Interface
      1005: >>      assign l2tlb_ptw_req  = mb_issue_req & cp0_mmu_ptw_en;
      1006:         assign l2tlb_ptw_vpn  = mb_issue_vpn;
      1007:         // Pad 2-bit type to 3-bit if necessary (e.g. {1'b0, type}) or direct map
      1008:         // Assuming mb_issue_type is already 3 bits based on MB param logic inside MB,
```

`mmu/rtl/mmu_l2tlb.sv:1021`

```systemverilog
      1018:                                 & (final_tlb_hit_mult
      1019:                                 |  (l2tlb_miss & !cp0_mmu_ptw_en));
      1020:         assign final_reqq_retry = final_reqq_miss & cp0_mmu_ptw_en & !mb_alloc_valid;
      1021: >>      assign final_reqq_done  = final_reqq_hit
      1022:                                 | final_reqq_fault
      1023:                                 | (final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid);
      1024:     
```

`mmu/rtl/mmu_l2tlb.sv:1031`

```systemverilog
      1028:         
      1029:         // ReqQ entries retire on any terminal result. Only a PTW-enabled miss that
      1030:         // cannot allocate an L2 miss-buffer entry is replayed.
      1031: >>      assign l2tlb_reqq_fb_miss_alloc = final_reqq_miss & cp0_mmu_ptw_en & mb_alloc_valid;////////////////////////////////////add logic mb response to reqq
      1032:         assign l2tlb_reqq_fb_miss_retry = final_reqq_retry;
      1033:     
      1034:         assign l2tlb_arb_pfu_miss_mb_full = final_pfu_req
```

`mmu/rtl/mmu_l2tlb.sv:1041`

```systemverilog
      1038:     
      1039:     
      1040:         assign ptw_req = (final_acc_type == 3'b000) & final_vld;
      1041: >>      assign l2tlb_arb_ptw_cmplt = arb_l2tlb_req & (arb_l2tlb_acc_type == 3'b101) & arb_l2tlb_write;
      1042:     
      1043:         mmu_l2tlb_replacement_policy#(
      1044:         .WAY_NUM      (WAY_NUM),
```

`mmu/rtl/mmu_l2tlb.sv:1167`

```systemverilog
      1164:     
      1165:     
      1166:     
      1167: >>      assign final_l1tlb_cmplt        = final_vld & final_cmp_with_va & !final_par_fail
      1168:                                         & (!cp0_mmu_ptw_en //&& read_cur_1g
      1169:                                         | !final_tlb_miss);
      1170:     
```

`mmu/rtl/mmu_l2tlb.sv:1186`

```systemverilog
      1183:         //assign l2tlb_l1itlb_acc_err   = ptw_l2tlb_ref_acc_err
      1184:         //                                   & ptw_l2tlb_imiss;
      1185:         
      1186: >>      assign l2tlb_l1itlb_pgflt     = //ptw_l2tlb_ref_pgflt
      1187:                                         //   & ptw_l2tlb_imiss
      1188:                                         final_vld & final_tlb_hit_mult
      1189:                                            & (final_acc_type[2:0] == 3'b011)
```

`mmu/rtl/mmu_l2tlb.sv:1204`

```systemverilog
      1201:                                       //| ptw_l2tlb_ref_data_vld
      1202:                                       //     & ptw_l2tlb_dmiss;
      1203:         
      1204: >>      assign l2tlb_l1dtlb_pgflt     = //ptw_l2tlb_ref_pgflt
      1205:                                         //   & ptw_l2tlb_dmiss
      1206:                                         final_vld & final_tlb_hit_mult 
      1207:                                            & (final_acc_type[1:0] == 2'b10)
```

`mmu/rtl/mmu_l2tlb.sv:1234`

```systemverilog
      1231:         assign cp0_mach_mode = cp0_priv_mode[1:0] == 2'b11;
      1232:         
      1233:         // &Force("bus", "pmp_mmu_flg4", 3, 0); @1040
      1234: >>      assign l2tlb_pfu_deny = !pmp_mmu_flg4[0]
      1235:                              && !(cp0_mach_mode && !pmp_mmu_flg4[3]);  // L-bit for M-Mode
      1236:         
      1237:         // result to lsu pfu
```

`mmu/rtl/mmu_l2tlb.sv:1409`

```systemverilog
      1406:                                || ptw_l2tlb_ref_cmplt && ptw_l2tlb_pmiss
      1407:                                || lsu_mmu_va2_vld && l1dtlb_xx_mmu_off ;//&& (arb_top_cur_st[1:0] == 2'b0);
      1408:     
      1409: >>  assign l2tlb_pfu_flag_fault =  !final_hit_flg[0]
      1410:                                || !final_hit_flg[1] && final_hit_flg[2]
      1411:                                || !final_hit_flg[1] && !(cp0_mmu_mxr && final_hit_flg[3])
      1412:                                ||  final_hit_flg[4] && cp0_supv_mode && !cp0_mmu_sum
```

`mmu/rtl/mmu_l2tlb.sv:1418`

```systemverilog
      1415:                                || (cp0_mmu_maee ? (final_hit_flg[13] || !final_hit_flg[12])
      1416:                                                 : (sysmap_mmu_flg4[4] || !sysmap_mmu_flg4[3]));
      1417:     
      1418: >>  assign l2tlb_pfu_acc_fault = final_vld && (final_tlb_hit_mult 
      1419:                                            || !cp0_mmu_ptw_en && l2tlb_miss)
      1420:                                      && (final_acc_type[2:0] == 3'b100)
      1421:                                || final_pa_vld && (final_acc_type[2:0] == 3'b100)
```

### 分支覆盖

说明：这里列出 if/case/三目表达式分支没有完全走到的位置；`URG 细节` 给出未覆盖组合。

| 行号 | 未覆盖代码/对象 | URG 细节 |
| ---: | --- | --- |
| 1354 | `1354       case (pfu_cur_st[1:0])` | PFU_CHK - - 1 Not Covered |
| 1354 | `1354       case (pfu_cur_st[1:0])` | default - - - Not Covered |

`mmu/rtl/mmu_l2tlb.sv:1354`

```systemverilog
      1350:     end 
      1351:     
      1352:     // &CombBeg; @918
      1353:     always_comb begin
      1354: >>  case (pfu_cur_st[1:0])
      1355:         PFU_IDLE: 
      1356:         begin
      1357:             if(l2tlb_pfu_cmplt)
      1358:                 if(l2tlb_pfu_acc_fault)
```

### FSM 状态迁移覆盖

| FSM | 未覆盖迁移 | 行号 |
| --- | --- | ---: |
| `pfu_cur_st` | `PFU_CHK->PFU_DENY` | 1368 |
| `pfu_cur_st` | `PFU_CHK->PFU_IDLE` | 1347 |

`mmu/rtl/mmu_l2tlb.sv:1368` (FSM `pfu_cur_st` 的 `PFU_CHK->PFU_DENY` 迁移)

```systemverilog
      1363:                 pfu_nxt_st[1:0] = PFU_IDLE;
      1364:         end
      1365:         PFU_CHK: 
      1366:         begin
      1367:             if(l2tlb_pfu_deny)
      1368: >>              pfu_nxt_st[1:0] = PFU_DENY;
      1369:             else
      1370:                 pfu_nxt_st[1:0] = PFU_OK;
      1371:         end
      1372:         PFU_DENY: 
      1373:         begin
```

`mmu/rtl/mmu_l2tlb.sv:1347` (FSM `pfu_cur_st` 的 `PFU_CHK->PFU_IDLE` 迁移)

```systemverilog
      1342:               PFU_OK   = 2'b11;
      1343:     
      1344:     always_ff@(posedge l2tlb_clk or negedge cpurst_b)
      1345:     begin
      1346:       if (!cpurst_b)
      1347: >>      pfu_cur_st[1:0] <= PFU_IDLE;
      1348:       else
      1349:         pfu_cur_st[1:0] <= pfu_nxt_st[1:0];
      1350:     end 
      1351:     
      1352:     // &CombBeg; @918
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 29 | `cpurst_b -> input  logic                    cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 31 | `pad_yy_icg_scan_en -> input  logic                    pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 38 | `cp0_mmu_mpp[0] -> input  logic [1  :0]            cp0_mmu_mpp,` | Toggle=No, 1->0=Yes, 0->1=No | INPUT | 1 |
| 44 | `regs_l2tlb_cur_asid[15:5] -> input  logic [15 :0]            regs_l2tlb_cur_asid,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 51 | `l2tlb_arb_pfu_miss_mb_full -> output logic                    l2tlb_arb_pfu_miss_mb_full,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 60 | `queue_arb_acc_type[1] -> output logic [TYPE_WIDTH-1:0]   queue_arb_acc_type,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 84 | `arb_l2tlb_tag_din[18] -> input  logic [47 :0]            arb_l2tlb_tag_din,      // Tag Write Data` | Toggle=No, 1->0=No, 0->1=No | INPUT | 2 |
| 85 | `arb_l2tlb_data_din[37:35] -> input  logic [41 :0]            arb_l2tlb_data_din,     // Data Write Data` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 127 | `ptw_l2tlb_ref_vpn[26] -> input  logic [26 :0]            ptw_l2tlb_ref_vpn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 129 | `ptw_l2tlb_ref_ppn[23:21] -> input  logic [27 :0]            ptw_l2tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 162 | `l2tlb_l1tlb_ref_ppn[20] -> output logic [27 :0]            l2tlb_l1tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 162 | `l2tlb_l1tlb_ref_ppn[23:21] -> output logic [27 :0]            l2tlb_l1tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 162 | `l2tlb_l1tlb_ref_ppn[27:24] -> output logic [27 :0]            l2tlb_l1tlb_ref_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 189 | `mmu_lsu_pa2[10] -> output logic [27 :0]            mmu_lsu_pa2,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 2 |
| 189 | `mmu_lsu_pa2[27:20] -> output logic [27 :0]            mmu_lsu_pa2,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 192 | `mmu_lsu_sec2 -> output logic                    mmu_lsu_sec2,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 204 | `tlboper_xx_pgs[2:1] -> input  logic [2  :0]            tlboper_xx_pgs,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 216 | `l2tlb_tlbr_asid[14] -> output logic [15 :0]            l2tlb_tlbr_asid,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 220 | `l2tlb_tlbr_ppn[20] -> output logic [27 :0]            l2tlb_tlbr_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 220 | `l2tlb_tlbr_ppn[23:21] -> output logic [27 :0]            l2tlb_tlbr_ppn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 220 | `l2tlb_tlbr_ppn[27:24] -> output logic [27 :0]            l2tlb_tlbr_ppn,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 221 | `l2tlb_tlbr_vpn[26] -> output logic [26 :0]            l2tlb_tlbr_vpn,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 226 | `pmp_mmu_flg4[3] -> input  logic [3  :0]            pmp_mmu_flg4,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 227 | `mmu_pmp_pa4[10] -> output logic [27 :0]            mmu_pmp_pa4,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 2 |
| 227 | `mmu_pmp_pa4[27:20] -> output logic [27 :0]            mmu_pmp_pa4,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 232 | `sysmap_mmu_flg4[0] -> input  logic [4  :0]            sysmap_mmu_flg4,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/mmu_l2tlb.sv:29` (声明 `cpurst_b`)

```systemverilog
        26:         //!************************************************
        27:         //! Clock and Reset
        28:         //!************************************************
        29: >>      input  logic                    cpurst_b,
        30:         input  logic                    forever_cpuclk,
        31:         input  logic                    pad_yy_icg_scan_en,
        32:     
```

`mmu/rtl/mmu_l2tlb.sv:31` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        28:         //!************************************************
        29:         input  logic                    cpurst_b,
        30:         input  logic                    forever_cpuclk,
        31: >>      input  logic                    pad_yy_icg_scan_en,
        32:     
        33:         //!************************************************
        34:         //! SysReg Interface
```

`mmu/rtl/mmu_l2tlb.sv:38` (声明 `cp0_mmu_mpp`)

```systemverilog
        35:         //!************************************************
        36:         input  logic                    cp0_mmu_icg_en,
        37:         input  logic                    cp0_mmu_maee,
        38: >>      input  logic [1  :0]            cp0_mmu_mpp,
        39:         input  logic                    cp0_mmu_mprv,
        40:         input  logic                    cp0_mmu_mxr,
        41:         input  logic                    cp0_mmu_ptw_en,
```

`mmu/rtl/mmu_l2tlb.sv:44` (声明 `regs_l2tlb_cur_asid`)

```systemverilog
        41:         input  logic                    cp0_mmu_ptw_en,
        42:         input  logic                    cp0_mmu_sum,
        43:         input  logic [1  :0]            cp0_yy_priv_mode,
        44: >>      input  logic [15 :0]            regs_l2tlb_cur_asid,
        45:     
        46:         //!*****************************************************
        47:         //! Arbiter <=> L2TLB Interface (Modified)
```

`mmu/rtl/mmu_l2tlb.sv:51` (声明 `l2tlb_arb_pfu_miss_mb_full`)

```systemverilog
        48:         //!*****************************************************
        49:         //pfu <=> arb
        50:         output logic [VPN_WIDTH-1:0]    l2tlb_arb_pfu_vpn,
        51: >>      output logic                    l2tlb_arb_pfu_miss_mb_full,
        52:         output logic                    l2tlb_arb_rrpv_wbuf_full,
        53:         
        54:     
```

`mmu/rtl/mmu_l2tlb.sv:60` (声明 `queue_arb_acc_type`)

```systemverilog
        57:         output logic [VPN_WIDTH-1:0]    queue_arb_vpn,
        58:         output logic [L1EID_WIDTH-1:0]  queue_arb_eid,//l1dtlb miss buffer entry id
        59:         output logic [TRANS_ID_WIDTH-1:0] queue_arb_trans_id,//l2tlb request queue entry id
        60: >>      output logic [TYPE_WIDTH-1:0]   queue_arb_acc_type,
        61:         //output logic                    queue_arb_is_dtlb,
        62:     
        63:         //for ptw write req
```

`mmu/rtl/mmu_l2tlb.sv:84` (声明 `arb_l2tlb_tag_din`)

```systemverilog
        81:         input  logic                    arb_l2tlb_write,        // Global Write Enable
        82:         //input  logic [WAY_NUM-1:0]      arb_l2tlb_way_sel,      // [MOD] 8-bit Way Select (for TLBWI/Refill)
        83:         
        84: >>      input  logic [47 :0]            arb_l2tlb_tag_din,      // Tag Write Data
        85:         input  logic [41 :0]            arb_l2tlb_data_din,     // Data Write Data
        86:         input  logic                    arb_l2tlb_cmp_with_va,
        87:         
```

`mmu/rtl/mmu_l2tlb.sv:85` (声明 `arb_l2tlb_data_din`)

```systemverilog
        82:         //input  logic [WAY_NUM-1:0]      arb_l2tlb_way_sel,      // [MOD] 8-bit Way Select (for TLBWI/Refill)
        83:         
        84:         input  logic [47 :0]            arb_l2tlb_tag_din,      // Tag Write Data
        85: >>      input  logic [41 :0]            arb_l2tlb_data_din,     // Data Write Data
        86:         input  logic                    arb_l2tlb_cmp_with_va,
        87:         
        88:         // Skew Indices (8 Independent Hashed Indices)
```

`mmu/rtl/mmu_l2tlb.sv:127` (声明 `ptw_l2tlb_ref_vpn`)

```systemverilog
       124:         input  logic                    ptw_l2tlb_ref_data_vld,
       125:         input  logic [13 :0]            ptw_l2tlb_ref_flg,
       126:         input  logic                    ptw_l2tlb_ref_pgflt,
       127: >>      input  logic [26 :0]            ptw_l2tlb_ref_vpn,
       128:         input  logic [2  :0]            ptw_l2tlb_ref_pgs,
       129:         input  logic [27 :0]            ptw_l2tlb_ref_ppn,
       130:         input  logic [L1EID_WIDTH+L2EID_WIDTH-1:0] ptw_l2tlb_ref_id,
```

`mmu/rtl/mmu_l2tlb.sv:129` (声明 `ptw_l2tlb_ref_ppn`)

```systemverilog
       126:         input  logic                    ptw_l2tlb_ref_pgflt,
       127:         input  logic [26 :0]            ptw_l2tlb_ref_vpn,
       128:         input  logic [2  :0]            ptw_l2tlb_ref_pgs,
       129: >>      input  logic [27 :0]            ptw_l2tlb_ref_ppn,
       130:         input  logic [L1EID_WIDTH+L2EID_WIDTH-1:0] ptw_l2tlb_ref_id,
       131:     
       132:         // PTW Ready (Needed for Miss Buffer)
```

`mmu/rtl/mmu_l2tlb.sv:162` (声明 `l2tlb_l1tlb_ref_ppn`)

```systemverilog
       159:     
       160:         output logic [13 :0]            l2tlb_l1tlb_ref_flg,
       161:         output logic [2  :0]            l2tlb_l1tlb_ref_pgs,
       162: >>      output logic [27 :0]            l2tlb_l1tlb_ref_ppn,
       163:         output logic [26 :0]            l2tlb_l1tlb_ref_vpn,
       164:         output logic                    l2tlb_top_utlb_pavld, //for ct_mmu_top generate clk_en
       165:         
```

`mmu/rtl/mmu_l2tlb.sv:189` (声明 `mmu_lsu_pa2`)

```systemverilog
       186:         input  logic                    l1dtlb_xx_mmu_off,
       187:         input  logic [27 :0]            lsu_mmu_va2,
       188:         input  logic                    lsu_mmu_va2_vld,
       189: >>      output logic [27 :0]            mmu_lsu_pa2,
       190:         output logic                    mmu_lsu_pa2_err,
       191:         output logic                    mmu_lsu_pa2_vld,
       192:         output logic                    mmu_lsu_sec2,
```

`mmu/rtl/mmu_l2tlb.sv:192` (声明 `mmu_lsu_sec2`)

```systemverilog
       189:         output logic [27 :0]            mmu_lsu_pa2,
       190:         output logic                    mmu_lsu_pa2_err,
       191:         output logic                    mmu_lsu_pa2_vld,
       192: >>      output logic                    mmu_lsu_sec2,
       193:         output logic                    mmu_lsu_share2,
       194:     
       195:         //!*****************************************************
```

`mmu/rtl/mmu_l2tlb.sv:204` (声明 `tlboper_xx_pgs`)

```systemverilog
       201:         input  logic [15 :0]            tlboper_l2tlb_inv_asid,
       202:         input  logic                    tlboper_l2tlb_tlbwr_on,
       203:         input  logic                    tlboper_l2tlb_invasid_on,
       204: >>      input  logic [2  :0]            tlboper_xx_pgs,
       205:         input  logic                    tlboper_ptw_abort,
       206:         //input  logic                    tlboper_xx_pgs_en,
       207:     
```

`mmu/rtl/mmu_l2tlb.sv:216` (声明 `l2tlb_tlbr_asid`)

```systemverilog
       213:         output logic [WAY_NUM-1:0]      l2tlb_tlboper_sel,         // [MOD] 8-bit Way Select Feedback
       214:         output logic                    l2tlb_tlboper_va_hit,
       215:     
       216: >>      output logic [15 :0]            l2tlb_tlbr_asid,
       217:         output logic [13 :0]            l2tlb_tlbr_flg,
       218:         output logic                    l2tlb_tlbr_g,
       219:         output logic [2  :0]            l2tlb_tlbr_pgs,
```

`mmu/rtl/mmu_l2tlb.sv:220` (声明 `l2tlb_tlbr_ppn`)

```systemverilog
       217:         output logic [13 :0]            l2tlb_tlbr_flg,
       218:         output logic                    l2tlb_tlbr_g,
       219:         output logic [2  :0]            l2tlb_tlbr_pgs,
       220: >>      output logic [27 :0]            l2tlb_tlbr_ppn,
       221:         output logic [26 :0]            l2tlb_tlbr_vpn,
       222:     
       223:         //!*****************************************************
```

`mmu/rtl/mmu_l2tlb.sv:221` (声明 `l2tlb_tlbr_vpn`)

```systemverilog
       218:         output logic                    l2tlb_tlbr_g,
       219:         output logic [2  :0]            l2tlb_tlbr_pgs,
       220:         output logic [27 :0]            l2tlb_tlbr_ppn,
       221: >>      output logic [26 :0]            l2tlb_tlbr_vpn,
       222:     
       223:         //!*****************************************************
       224:         //! PMP (Physical Memory Protection) Interface
```

`mmu/rtl/mmu_l2tlb.sv:226` (声明 `pmp_mmu_flg4`)

```systemverilog
       223:         //!*****************************************************
       224:         //! PMP (Physical Memory Protection) Interface
       225:         //!*****************************************************
       226: >>      input  logic [3  :0]            pmp_mmu_flg4,
       227:         output logic [27 :0]            mmu_pmp_pa4,
       228:     
       229:         //!*****************************************************
```

`mmu/rtl/mmu_l2tlb.sv:227` (声明 `mmu_pmp_pa4`)

```systemverilog
       224:         //! PMP (Physical Memory Protection) Interface
       225:         //!*****************************************************
       226:         input  logic [3  :0]            pmp_mmu_flg4,
       227: >>      output logic [27 :0]            mmu_pmp_pa4,
       228:     
       229:         //!*****************************************************
       230:         //! System Map Interface
```

`mmu/rtl/mmu_l2tlb.sv:232` (声明 `sysmap_mmu_flg4`)

```systemverilog
       229:         //!*****************************************************
       230:         //! System Map Interface
       231:         //!*****************************************************
       232: >>      input  logic [4  :0]            sysmap_mmu_flg4,
       233:         output logic [27 :0]            mmu_sysmap_pa4
       234:     );
       235:     
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 112 | `l2tlb_reqq_fb_miss_retry -> //output logic                    l2tlb_reqq_fb_miss_retry, // Miss & Retry needed (Buffer Full)` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 264 | `arb_l2tlb_req_internal -> logic                       arb_l2tlb_req_internal; // Rename to avoid conflict if input` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 265 | `arb_l2tlb_vpn_internal[26:0] -> logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 266 | `arb_l2tlb_trans_id_internal[3:0] -> logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 267 | `arb_l2tlb_eid_internal[2:0] -> logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 268 | `arb_l2tlb_type[2:0] -> logic [TYPE_WIDTH-1:0]      arb_l2tlb_type;    // Derived from reqq` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 286 | `fb_hit -> logic                       fb_hit;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 287 | `fb_miss_alloc -> logic                       fb_miss_alloc;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 288 | `fb_miss_retry -> logic                       fb_miss_retry;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[0] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 25 |
| 291 | `l2tlb_tag_dout_bus[19:16] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[59:55] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[67:63] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[152:151] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[156:155] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[163:159] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[211:204] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[238:236] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[245:244] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[252:251] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[255:254] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[259:257] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[268:267] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[283:282] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[286:285] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[292:291] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[296:295] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[307:303] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[334:332] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[355:351] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 291 | `l2tlb_tag_dout_bus[382:381] -> logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[41:34] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[83:76] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[121:119] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[130] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 10 |
| 292 | `l2tlb_data_dout_bus[167:160] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[209:201] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[251:243] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[293:286] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 292 | `l2tlb_data_dout_bus[335:328] -> logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 296 | `req_alloc_valid -> logic                       req_alloc_valid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `Other bits of raw_way_pgs[7:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `Other bits of raw_way_asid[7:0][15:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 329 | `raw_way_g[0] -> logic [WAY_NUM-1:0]                 raw_way_g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 329 | `raw_way_g[4:3] -> logic [WAY_NUM-1:0]                 raw_way_g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 329 | `raw_way_g[7:6] -> logic [WAY_NUM-1:0]                 raw_way_g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `Other bits of raw_way_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 347 | `raw_trans_id[3:0] -> logic [TRANS_ID_WIDTH-1:0]  raw_trans_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 348 | `raw_tag[18] -> logic [TAG_WIDTH-1:0]       raw_tag;` | Toggle=No, 1->0=No, 0->1=No | 2 |
| 361 | `final_trans_id[3:0] -> logic [TRANS_ID_WIDTH-1:0]  final_trans_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 362 | `final_tag[3:2] -> logic [TAG_WIDTH-1:0]       final_tag;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 362 | `final_tag[18] -> logic [TAG_WIDTH-1:0]       final_tag;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 362 | `final_tag[27:26] -> logic [TAG_WIDTH-1:0]       final_tag;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 362 | `final_tag[37:32] -> logic [TAG_WIDTH-1:0]       final_tag;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 362 | `final_tag[46:39] -> logic [TAG_WIDTH-1:0]       final_tag;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `Other bits of final_way_vpn[7:0][26:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `Other bits of final_way_pgs[7:0][2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 371 | `final_way_asid[1][0] -> logic [WAY_NUM-1:0][ASID_WIDTH-1:0] final_way_asid;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| - | `Other bits of final_way_asid[7:0][15:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 372 | `final_way_g[1:0] -> logic [WAY_NUM-1:0]         final_way_g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 372 | `final_way_g[4:3] -> logic [WAY_NUM-1:0]         final_way_g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 372 | `final_way_g[7:6] -> logic [WAY_NUM-1:0]         final_way_g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 373 | `final_way_ppn[1][10] -> logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 3 |
| 373 | `final_way_ppn[2][27:24] -> logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| - | `Other bits of final_way_ppn[7:0][27:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 374 | `final_way_flg[1][4] -> logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;` | Toggle=No, 1->0=No, 0->1=Yes | 2 |
| - | `Other bits of final_way_flg[7:0][13:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 377 | `final_hit_sum[2] -> logic [2:0]                 final_hit_sum;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 378 | `final_par_fail -> logic                       final_par_fail;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 382 | `final_cmp_va -> logic                       final_cmp_va;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 395 | `final_reqq_retry -> logic                       final_reqq_retry;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 400 | `raw_vpn_2m[8:0] -> logic [VPN_WIDTH-1:0]       raw_vpn_2m;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 401 | `raw_vpn_1g[17:0] -> logic [VPN_WIDTH-1:0]       raw_vpn_1g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 409 | `ta_vld -> logic                       ta_vld;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 413 | `final_vpn_2m[26:18] -> logic [VPN_WIDTH-1:0]       final_vpn_2m;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 414 | `final_vpn_1g[26:9] -> logic [VPN_WIDTH-1:0]       final_vpn_1g;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 415 | `final_vpn_masked[26:25] -> logic [VPN_WIDTH-1:0]       final_vpn_masked;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 433 | `ref_ppn[20] -> logic [PPN_WIDTH-1:0]       ref_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 433 | `ref_ppn[23:21] -> logic [PPN_WIDTH-1:0]       ref_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 433 | `ref_ppn[27:24] -> logic [PPN_WIDTH-1:0]       ref_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 436 | `pfu_ref_ppn[20] -> logic [PPN_WIDTH-1:0]       pfu_ref_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 436 | `pfu_ref_ppn[23:21] -> logic [PPN_WIDTH-1:0]       pfu_ref_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 436 | `pfu_ref_ppn[27:24] -> logic [PPN_WIDTH-1:0]       pfu_ref_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 455 | `l2tlb_pfu_deny -> logic                       l2tlb_pfu_deny;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 458 | `ptw_pa2[20] -> logic [PPN_WIDTH-1:0]       ptw_pa2;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 458 | `ptw_pa2[23:21] -> logic [PPN_WIDTH-1:0]       ptw_pa2;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 458 | `ptw_pa2[27:24] -> logic [PPN_WIDTH-1:0]       ptw_pa2;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 459 | `l2tlb_pfu_pa[20] -> logic [PPN_WIDTH-1:0]       l2tlb_pfu_pa;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 459 | `l2tlb_pfu_pa[23:21] -> logic [PPN_WIDTH-1:0]       l2tlb_pfu_pa;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 459 | `l2tlb_pfu_pa[27:24] -> logic [PPN_WIDTH-1:0]       l2tlb_pfu_pa;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 464 | `pfu_pa_buf[10] -> logic [PPN_WIDTH-1:0]       pfu_pa_buf;` | Toggle=No, 1->0=No, 0->1=No | 2 |
| 464 | `pfu_pa_buf[27:20] -> logic [PPN_WIDTH-1:0]       pfu_pa_buf;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 465 | `pfu_sec_buf -> logic                       pfu_sec_buf;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 179 | `d_req_type[1:0] -> //input  logic [TYPE_WIDTH-1:0]    d_req_type,` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 866 | `l2tlb_arb_par_clr -> assign l2tlb_arb_par_clr  = final_par_fail;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 879 | `final_idx_vpn[26] -> logic [VPN_WIDTH-1:0]  final_idx_vpn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 881 | `final_idx_asid[14] -> logic [ASID_WIDTH-1:0] final_idx_asid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 884 | `final_hit_ppn[20] -> logic [PPN_WIDTH-1:0]  final_hit_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 884 | `final_hit_ppn[23:21] -> logic [PPN_WIDTH-1:0]  final_hit_ppn;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 884 | `final_hit_ppn[27:24] -> logic [PPN_WIDTH-1:0]  final_hit_ppn;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |

`mmu/rtl/mmu_l2tlb.sv:112` (声明 `l2tlb_reqq_fb_miss_retry`)

```systemverilog
       109:         //output logic [TRANS_ID_WIDTH-1:0] l2tlb_reqq_fb_id,       // Transaction ID
       110:         //output logic                    l2tlb_reqq_fb_hit,        // Hit
       111:         //output logic                    l2tlb_reqq_fb_miss_alloc, // Miss & Buffer Allocated
       112: >>      //output logic                    l2tlb_reqq_fb_miss_retry, // Miss & Retry needed (Buffer Full)
       113:     
       114:         //!*****************************************************
       115:         //! PTW (Page Table Walker) <=> JTLB Interface
```

`mmu/rtl/mmu_l2tlb.sv:264` (声明 `arb_l2tlb_req_internal`)

```systemverilog
       261:         logic                       l2tlb_reqq_fb_miss_retry;
       262:     
       263:         // 1. Wires: Reqq -> Pipeline (Simulating the old Arbiter inputs)
       264: >>      logic                       arb_l2tlb_req_internal; // Rename to avoid conflict if input
       265:         logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;
       266:         logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;
       267:         logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;
```

`mmu/rtl/mmu_l2tlb.sv:265` (声明 `arb_l2tlb_vpn_internal`)

```systemverilog
       262:     
       263:         // 1. Wires: Reqq -> Pipeline (Simulating the old Arbiter inputs)
       264:         logic                       arb_l2tlb_req_internal; // Rename to avoid conflict if input
       265: >>      logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;
       266:         logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;
       267:         logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;
       268:         logic [TYPE_WIDTH-1:0]      arb_l2tlb_type;    // Derived from reqq
```

`mmu/rtl/mmu_l2tlb.sv:266` (声明 `arb_l2tlb_trans_id_internal`)

```systemverilog
       263:         // 1. Wires: Reqq -> Pipeline (Simulating the old Arbiter inputs)
       264:         logic                       arb_l2tlb_req_internal; // Rename to avoid conflict if input
       265:         logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;
       266: >>      logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;
       267:         logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;
       268:         logic [TYPE_WIDTH-1:0]      arb_l2tlb_type;    // Derived from reqq
       269:         logic                       arb_l2tlb_is_dtlb;
```

`mmu/rtl/mmu_l2tlb.sv:267` (声明 `arb_l2tlb_eid_internal`)

```systemverilog
       264:         logic                       arb_l2tlb_req_internal; // Rename to avoid conflict if input
       265:         logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;
       266:         logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;
       267: >>      logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;
       268:         logic [TYPE_WIDTH-1:0]      arb_l2tlb_type;    // Derived from reqq
       269:         logic                       arb_l2tlb_is_dtlb;
       270:         
```

`mmu/rtl/mmu_l2tlb.sv:268` (声明 `arb_l2tlb_type`)

```systemverilog
       265:         logic [VPN_WIDTH-1:0]       arb_l2tlb_vpn_internal;
       266:         logic [TRANS_ID_WIDTH-1:0]  arb_l2tlb_trans_id_internal;
       267:         logic [L1EID_WIDTH-1:0]     arb_l2tlb_eid_internal;
       268: >>      logic [TYPE_WIDTH-1:0]      arb_l2tlb_type;    // Derived from reqq
       269:         logic                       arb_l2tlb_is_dtlb;
       270:         
       271:         // Pipeline Grant Logic
```

`mmu/rtl/mmu_l2tlb.sv:286` (声明 `fb_hit`)

```systemverilog
       283:         logic                       mb_alloc_en;       // Enable MB allocation on miss
       284:         
       285:         // 4. Feedback Wires
       286: >>      logic                       fb_hit;
       287:         logic                       fb_miss_alloc;
       288:         logic                       fb_miss_retry;
       289:     
```

`mmu/rtl/mmu_l2tlb.sv:287` (声明 `fb_miss_alloc`)

```systemverilog
       284:         
       285:         // 4. Feedback Wires
       286:         logic                       fb_hit;
       287: >>      logic                       fb_miss_alloc;
       288:         logic                       fb_miss_retry;
       289:     
       290:         // Tag Array Read Data
```

`mmu/rtl/mmu_l2tlb.sv:288` (声明 `fb_miss_retry`)

```systemverilog
       285:         // 4. Feedback Wires
       286:         logic                       fb_hit;
       287:         logic                       fb_miss_alloc;
       288: >>      logic                       fb_miss_retry;
       289:     
       290:         // Tag Array Read Data
       291:         logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;
```

`mmu/rtl/mmu_l2tlb.sv:291` (声明 `l2tlb_tag_dout_bus`)

```systemverilog
       288:         logic                       fb_miss_retry;
       289:     
       290:         // Tag Array Read Data
       291: >>      logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;
       292:         logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus; 
       293:         logic [WAY_NUM*RRPV_WIDTH-1:0] l2tlb_rrpv_dout_bus; 
       294:     
```

`mmu/rtl/mmu_l2tlb.sv:292` (声明 `l2tlb_data_dout_bus`)

```systemverilog
       289:     
       290:         // Tag Array Read Data
       291:         logic [TAG_WIDTH*WAY_NUM-1:0]  l2tlb_tag_dout_bus;
       292: >>      logic [DATA_WIDTH*WAY_NUM-1:0] l2tlb_data_dout_bus; 
       293:         logic [WAY_NUM*RRPV_WIDTH-1:0] l2tlb_rrpv_dout_bus; 
       294:     
       295:         logic                       mb_alloc_valid;
```

`mmu/rtl/mmu_l2tlb.sv:296` (声明 `req_alloc_valid`)

```systemverilog
       293:         logic [WAY_NUM*RRPV_WIDTH-1:0] l2tlb_rrpv_dout_bus; 
       294:     
       295:         logic                       mb_alloc_valid;
       296: >>      logic                       req_alloc_valid;
       297:         //logic [47:0]     l2tlb_tag_dout_w0;
       298:         //logic [47:0]     l2tlb_tag_dout_w1;
       299:         //logic [47:0]     l2tlb_tag_dout_w2;
```

`mmu/rtl/mmu_l2tlb.sv:329` (声明 `raw_way_g`)

```systemverilog
       326:         logic [WAY_NUM-1:0]                 raw_way_vld;
       327:         logic [WAY_NUM-1:0][PGS_WIDTH-1:0]            raw_way_pgs; 
       328:         logic [WAY_NUM-1:0][ASID_WIDTH-1:0] raw_way_asid; 
       329: >>      logic [WAY_NUM-1:0]                 raw_way_g;
       330:         
       331:         logic [WAY_NUM-1:0][VPN_WIDTH-1:0]  raw_vpn_masked;
       332:         logic [WAY_NUM-1:0][VPN_WIDTH-1:0]  raw_way_vpn;
```

`mmu/rtl/mmu_l2tlb.sv:347` (声明 `raw_trans_id`)

```systemverilog
       344:         // Register definitions
       345:         logic                       raw_vld;
       346:         logic [VPN_WIDTH-1:0]       raw_vpn;
       347: >>      logic [TRANS_ID_WIDTH-1:0]  raw_trans_id;
       348:         logic [TAG_WIDTH-1:0]       raw_tag;
       349:         logic [EID_WIDTH-1:0]       raw_eid;
       350:         logic [TRANS_ID_WIDTH-1:0]  raw_queue_id;
```

`mmu/rtl/mmu_l2tlb.sv:348` (声明 `raw_tag`)

```systemverilog
       345:         logic                       raw_vld;
       346:         logic [VPN_WIDTH-1:0]       raw_vpn;
       347:         logic [TRANS_ID_WIDTH-1:0]  raw_trans_id;
       348: >>      logic [TAG_WIDTH-1:0]       raw_tag;
       349:         logic [EID_WIDTH-1:0]       raw_eid;
       350:         logic [TRANS_ID_WIDTH-1:0]  raw_queue_id;
       351:         logic [WAY_NUM-1:0]         raw_way_mask;
```

`mmu/rtl/mmu_l2tlb.sv:361` (声明 `final_trans_id`)

```systemverilog
       358:     
       359:         logic                       final_vld;
       360:         logic [VPN_WIDTH-1:0]       final_vpn;
       361: >>      logic [TRANS_ID_WIDTH-1:0]  final_trans_id;
       362:         logic [TAG_WIDTH-1:0]       final_tag;
       363:         logic [EID_WIDTH-1:0]       final_eid;
       364:         logic [TRANS_ID_WIDTH-1:0]  final_queue_id;
```

`mmu/rtl/mmu_l2tlb.sv:362` (声明 `final_tag`)

```systemverilog
       359:         logic                       final_vld;
       360:         logic [VPN_WIDTH-1:0]       final_vpn;
       361:         logic [TRANS_ID_WIDTH-1:0]  final_trans_id;
       362: >>      logic [TAG_WIDTH-1:0]       final_tag;
       363:         logic [EID_WIDTH-1:0]       final_eid;
       364:         logic [TRANS_ID_WIDTH-1:0]  final_queue_id;
       365:         logic                       final_cmp_with_va;
```

`mmu/rtl/mmu_l2tlb.sv:371` (声明 `final_way_asid`)

```systemverilog
       368:         logic [WAY_NUM-1:0]         final_way_vld;
       369:         logic [WAY_NUM-1:0][VPN_WIDTH-1:0] final_way_vpn;
       370:         logic [WAY_NUM-1:0][PGS_WIDTH-1:0] final_way_pgs;
       371: >>      logic [WAY_NUM-1:0][ASID_WIDTH-1:0] final_way_asid;
       372:         logic [WAY_NUM-1:0]         final_way_g;
       373:         logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;
       374:         logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;
```

`mmu/rtl/mmu_l2tlb.sv:372` (声明 `final_way_g`)

```systemverilog
       369:         logic [WAY_NUM-1:0][VPN_WIDTH-1:0] final_way_vpn;
       370:         logic [WAY_NUM-1:0][PGS_WIDTH-1:0] final_way_pgs;
       371:         logic [WAY_NUM-1:0][ASID_WIDTH-1:0] final_way_asid;
       372: >>      logic [WAY_NUM-1:0]         final_way_g;
       373:         logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;
       374:         logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;
       375:     
```

`mmu/rtl/mmu_l2tlb.sv:373` (声明 `final_way_ppn`)

```systemverilog
       370:         logic [WAY_NUM-1:0][PGS_WIDTH-1:0] final_way_pgs;
       371:         logic [WAY_NUM-1:0][ASID_WIDTH-1:0] final_way_asid;
       372:         logic [WAY_NUM-1:0]         final_way_g;
       373: >>      logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;
       374:         logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;
       375:     
       376:         logic [2:0]                 l2tlb_cur_pgs [WAY_NUM-1:0];
```

`mmu/rtl/mmu_l2tlb.sv:374` (声明 `final_way_flg`)

```systemverilog
       371:         logic [WAY_NUM-1:0][ASID_WIDTH-1:0] final_way_asid;
       372:         logic [WAY_NUM-1:0]         final_way_g;
       373:         logic [WAY_NUM-1:0][PPN_WIDTH-1:0] final_way_ppn;
       374: >>      logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;
       375:     
       376:         logic [2:0]                 l2tlb_cur_pgs [WAY_NUM-1:0];
       377:         logic [2:0]                 final_hit_sum;
```

`mmu/rtl/mmu_l2tlb.sv:377` (声明 `final_hit_sum`)

```systemverilog
       374:         logic [WAY_NUM-1:0][FLG_WIDTH-1:0] final_way_flg;
       375:     
       376:         logic [2:0]                 l2tlb_cur_pgs [WAY_NUM-1:0];
       377: >>      logic [2:0]                 final_hit_sum;
       378:         logic                       final_par_fail;
       379:         logic                       final_tlb_miss;
       380:         logic                       final_tlb_hit;
```

`mmu/rtl/mmu_l2tlb.sv:378` (声明 `final_par_fail`)

```systemverilog
       375:     
       376:         logic [2:0]                 l2tlb_cur_pgs [WAY_NUM-1:0];
       377:         logic [2:0]                 final_hit_sum;
       378: >>      logic                       final_par_fail;
       379:         logic                       final_tlb_miss;
       380:         logic                       final_tlb_hit;
       381:         logic                       final_tlb_hit_mult;
```

`mmu/rtl/mmu_l2tlb.sv:382` (声明 `final_cmp_va`)

```systemverilog
       379:         logic                       final_tlb_miss;
       380:         logic                       final_tlb_hit;
       381:         logic                       final_tlb_hit_mult;
       382: >>      logic                       final_cmp_va;
       383:         
       384:         logic                       l2tlb_mb_req;
       385:         
```

`mmu/rtl/mmu_l2tlb.sv:395` (声明 `final_reqq_retry`)

```systemverilog
       392:         logic                       final_reqq_hit;
       393:         logic                       final_reqq_miss;
       394:         logic                       final_reqq_fault;
       395: >>      logic                       final_reqq_retry;
       396:         logic                       final_reqq_done;
       397:         logic                       final_miss_needs_ptw;
       398:     
```

`mmu/rtl/mmu_l2tlb.sv:400` (声明 `raw_vpn_2m`)

```systemverilog
       397:         logic                       final_miss_needs_ptw;
       398:     
       399:         logic [VPN_WIDTH-1:0]       raw_vpn_4k;
       400: >>      logic [VPN_WIDTH-1:0]       raw_vpn_2m;
       401:         logic [VPN_WIDTH-1:0]       raw_vpn_1g;
       402:     
       403:         logic [ASID_WIDTH-1:0]      asid_for_va_hit;
```

`mmu/rtl/mmu_l2tlb.sv:401` (声明 `raw_vpn_1g`)

```systemverilog
       398:     
       399:         logic [VPN_WIDTH-1:0]       raw_vpn_4k;
       400:         logic [VPN_WIDTH-1:0]       raw_vpn_2m;
       401: >>      logic [VPN_WIDTH-1:0]       raw_vpn_1g;
       402:     
       403:         logic [ASID_WIDTH-1:0]      asid_for_va_hit;
       404:     
```

`mmu/rtl/mmu_l2tlb.sv:409` (声明 `ta_vld`)

```systemverilog
       406:         logic                       l2tlb_clk;
       407:         
       408:         // Missing wires inferred from usage
       409: >>      logic                       ta_vld; 
       410:         logic                       pfu_idle_st;
       411:         
       412:         logic [VPN_WIDTH-1:0]       final_vpn_4k;
```

`mmu/rtl/mmu_l2tlb.sv:413` (声明 `final_vpn_2m`)

```systemverilog
       410:         logic                       pfu_idle_st;
       411:         
       412:         logic [VPN_WIDTH-1:0]       final_vpn_4k;
       413: >>      logic [VPN_WIDTH-1:0]       final_vpn_2m;
       414:         logic [VPN_WIDTH-1:0]       final_vpn_1g;
       415:         logic [VPN_WIDTH-1:0]       final_vpn_masked;
       416:     
```

`mmu/rtl/mmu_l2tlb.sv:414` (声明 `final_vpn_1g`)

```systemverilog
       411:         
       412:         logic [VPN_WIDTH-1:0]       final_vpn_4k;
       413:         logic [VPN_WIDTH-1:0]       final_vpn_2m;
       414: >>      logic [VPN_WIDTH-1:0]       final_vpn_1g;
       415:         logic [VPN_WIDTH-1:0]       final_vpn_masked;
       416:     
       417:         //==========================================================
```

`mmu/rtl/mmu_l2tlb.sv:415` (声明 `final_vpn_masked`)

```systemverilog
       412:         logic [VPN_WIDTH-1:0]       final_vpn_4k;
       413:         logic [VPN_WIDTH-1:0]       final_vpn_2m;
       414:         logic [VPN_WIDTH-1:0]       final_vpn_1g;
       415: >>      logic [VPN_WIDTH-1:0]       final_vpn_masked;
       416:     
       417:         //==========================================================
       418:         //              Missing Logic Definitions (Patch)
```

`mmu/rtl/mmu_l2tlb.sv:433` (声明 `ref_ppn`)

```systemverilog
       430:         // 3. Refill / Bypass Signals (Refill Result Mux)
       431:         logic [VPN_WIDTH-1:0]       ref_vpn;
       432:         logic [PGS_WIDTH-1:0]       ref_pgs;
       433: >>      logic [PPN_WIDTH-1:0]       ref_ppn;
       434:         logic [FLG_WIDTH-1:0]       ref_flg;
       435:     
       436:         logic [PPN_WIDTH-1:0]       pfu_ref_ppn;
```

`mmu/rtl/mmu_l2tlb.sv:436` (声明 `pfu_ref_ppn`)

```systemverilog
       433:         logic [PPN_WIDTH-1:0]       ref_ppn;
       434:         logic [FLG_WIDTH-1:0]       ref_flg;
       435:     
       436: >>      logic [PPN_WIDTH-1:0]       pfu_ref_ppn;
       437:         logic [PGS_WIDTH-1:0]       pfu_ref_pgs;
       438:         logic [FLG_WIDTH-1:0]       pfu_ref_flg;
       439:     
```

`mmu/rtl/mmu_l2tlb.sv:455` (声明 `l2tlb_pfu_deny`)

```systemverilog
       452:         logic                       l2tlb_pfu_cmplt;
       453:         logic                       l2tlb_pfu_flag_fault;
       454:         logic                       l2tlb_pfu_acc_fault;
       455: >>      logic                       l2tlb_pfu_deny; 
       456:         // 7. PFU Physical Address Calculation
       457:         logic [VPN_WIDTH-1:0]       pa_offset;
       458:         logic [PPN_WIDTH-1:0]       ptw_pa2;
```

`mmu/rtl/mmu_l2tlb.sv:458` (声明 `ptw_pa2`)

```systemverilog
       455:         logic                       l2tlb_pfu_deny; 
       456:         // 7. PFU Physical Address Calculation
       457:         logic [VPN_WIDTH-1:0]       pa_offset;
       458: >>      logic [PPN_WIDTH-1:0]       ptw_pa2;
       459:         logic [PPN_WIDTH-1:0]       l2tlb_pfu_pa;
       460:         logic                       l2tlb_pfu_sec;
       461:         logic                       l2tlb_pfu_share;
```

`mmu/rtl/mmu_l2tlb.sv:459` (声明 `l2tlb_pfu_pa`)

```systemverilog
       456:         // 7. PFU Physical Address Calculation
       457:         logic [VPN_WIDTH-1:0]       pa_offset;
       458:         logic [PPN_WIDTH-1:0]       ptw_pa2;
       459: >>      logic [PPN_WIDTH-1:0]       l2tlb_pfu_pa;
       460:         logic                       l2tlb_pfu_sec;
       461:         logic                       l2tlb_pfu_share;
       462:     
```

`mmu/rtl/mmu_l2tlb.sv:464` (声明 `pfu_pa_buf`)

```systemverilog
       461:         logic                       l2tlb_pfu_share;
       462:     
       463:         // 8. PFU Buffers (Flops)
       464: >>      logic [PPN_WIDTH-1:0]       pfu_pa_buf;
       465:         logic                       pfu_sec_buf;
       466:         logic                       pfu_share_buf;
       467:         logic			pfu_ok_st;
```

`mmu/rtl/mmu_l2tlb.sv:465` (声明 `pfu_sec_buf`)

```systemverilog
       462:     
       463:         // 8. PFU Buffers (Flops)
       464:         logic [PPN_WIDTH-1:0]       pfu_pa_buf;
       465: >>      logic                       pfu_sec_buf;
       466:         logic                       pfu_share_buf;
       467:         logic			pfu_ok_st;
       468:         logic			pfu_deny_st;
```

`mmu/rtl/mmu_l2tlb.sv:179` (声明 `d_req_type`)

```systemverilog
       176:         input  logic [VPN_WIDTH-1:0]     d_req_vpn,
       177:         //input  logic [ASID_WIDTH-1:0]    d_req_asid,
       178:         input  logic [L1EID_WIDTH-1:0]   d_req_eid,
       179: >>      //input  logic [TYPE_WIDTH-1:0]    d_req_type,
       180:         input  logic		     d_req_is_load,
       181:         output logic                     d_credit_return,
       182:     
```

`mmu/rtl/mmu_l2tlb.sv:866` (声明 `l2tlb_arb_par_clr`)

```systemverilog
       863:                                     + {2'b0,final_way_hit[4]} + {2'b0,final_way_hit[5]} + {2'b0,final_way_hit[6]} + {2'b0,final_way_hit[7]};
       864:     
       865:         assign final_par_fail     = 1'b0; 
       866: >>      assign l2tlb_arb_par_clr  = final_par_fail;
       867:     
       868:         assign final_tlb_miss     = (final_hit_sum[2:0] == 3'b000);
       869:         assign final_tlb_hit      = (final_hit_sum[2:0] == 3'b001) & final_cmp_with_va & !final_par_fail;
```

`mmu/rtl/mmu_l2tlb.sv:879` (声明 `final_idx_vpn`)

```systemverilog
       876:         //==========================================================
       877:         // Variable Definition for Select Logic
       878:         //==========================================================
       879: >>      logic [VPN_WIDTH-1:0]  final_idx_vpn;
       880:         logic [PGS_WIDTH-1:0]  final_idx_pgs;
       881:         logic [ASID_WIDTH-1:0] final_idx_asid;
       882:         logic                  final_idx_g;
```

`mmu/rtl/mmu_l2tlb.sv:881` (声明 `final_idx_asid`)

```systemverilog
       878:         //==========================================================
       879:         logic [VPN_WIDTH-1:0]  final_idx_vpn;
       880:         logic [PGS_WIDTH-1:0]  final_idx_pgs;
       881: >>      logic [ASID_WIDTH-1:0] final_idx_asid;
       882:         logic                  final_idx_g;
       883:     
       884:         logic [PPN_WIDTH-1:0]  final_hit_ppn;
```

`mmu/rtl/mmu_l2tlb.sv:884` (声明 `final_hit_ppn`)

```systemverilog
       881:         logic [ASID_WIDTH-1:0] final_idx_asid;
       882:         logic                  final_idx_g;
       883:     
       884: >>      logic [PPN_WIDTH-1:0]  final_hit_ppn;
       885:         logic [FLG_WIDTH-1:0]  final_hit_flg;
       886:         logic [PGS_WIDTH-1:0]  final_hit_pgs;
       887:     
```

## 模块 `mmu_l2tlb_reqq`

源码：`mmu/rtl/mmu_l2tlb_reqq.sv`
原始未覆盖记录数：`21`；合并后唯一代码对象数：`11`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 203 | `EXPRESSION (fb_valid && (fb_trans_id == 4[(ID_W - 1):0]))` | 0 1 Not Covered | 4 |

`mmu/rtl/mmu_l2tlb_reqq.sv:203`

```systemverilog
       200:                     .ASID_W         (ASID_W),
       201:                     .EID_W          (EID_W),
       202:                     .TYPE_W         (TYPE_W)
       203: >>              ) x_reqq_entry (
       204:                     // Global
       205:                     .cp0_mmu_icg_en     (cp0_mmu_icg_en),
       206:                     .cpurst_b           (cpurst_b),
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 30 | `cpurst_b -> input  logic                cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 32 | `pad_yy_icg_scan_en -> input  logic                pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 49 | `d_req_type[1:0] -> input  logic [TYPE_W-1:0]   d_req_type,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 63 | `issue_type[1] -> output logic [TYPE_W-1:0]   issue_type,//00 is itlb,01 is load,11 is store` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 74 | `fb_miss_retry -> input  logic                fb_miss_retry` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/mmu_l2tlb_reqq.sv:30` (声明 `cpurst_b`)

```systemverilog
        27:     )(
        28:         // Global Signals
        29:         input  logic                cp0_mmu_icg_en,
        30: >>      input  logic                cpurst_b,
        31:         input  logic                reqq_clk,
        32:         input  logic                pad_yy_icg_scan_en,
        33:     
```

`mmu/rtl/mmu_l2tlb_reqq.sv:32` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        29:         input  logic                cp0_mmu_icg_en,
        30:         input  logic                cpurst_b,
        31:         input  logic                reqq_clk,
        32: >>      input  logic                pad_yy_icg_scan_en,
        33:     
        34:         //-------------------------------------------------------------------------
        35:         // 1. L1 ITLB Interface (Allocate Entry 0)
```

`mmu/rtl/mmu_l2tlb_reqq.sv:49` (声明 `d_req_type`)

```systemverilog
        46:         input  logic [VPN_W-1:0]    d_req_vpn,
        47:         //input  logic [ASID_W-1:0]   d_req_asid,
        48:         input  logic [EID_W-1:0]    d_req_eid,
        49: >>      input  logic [TYPE_W-1:0]   d_req_type,
        50:         output logic                d_credit_return,
        51:     
        52:         //-------------------------------------------------------------------------
```

`mmu/rtl/mmu_l2tlb_reqq.sv:63` (声明 `issue_type`)

```systemverilog
        60:         output logic [VPN_W-1:0]    issue_vpn,
        61:         //output logic [ASID_W-1:0]   issue_asid,
        62:         output logic [EID_W-1:0]    issue_eid,
        63: >>      output logic [TYPE_W-1:0]   issue_type,//00 is itlb,01 is load,11 is store
        64:         
        65:         input  logic                issue_grant,      // Grant from Arbiter
        66:     
```

`mmu/rtl/mmu_l2tlb_reqq.sv:74` (声明 `fb_miss_retry`)

```systemverilog
        71:         input  logic [ID_W-1:0]     fb_trans_id,
        72:         input  logic                fb_hit,
        73:         input  logic                fb_miss_alloc,
        74: >>      input  logic                fb_miss_retry
        75:     );
        76:     
        77:     
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 94 | `bypass_grant_vec[8:4] -> logic [TOTAL_DEPTH-1:0]     bypass_grant_vec; // Grant to entry allocated by bypass issue` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 105 | `entry_rdy_asid[15:0] -> logic [ASID_W-1:0]          entry_rdy_asid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_entries[0].local_alloc_eid[2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_entries[0].local_alloc_type[2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_entries[1].local_alloc_type[1:0]` | Toggle=No, 1->0=No, 0->1=No | 8 |

`mmu/rtl/mmu_l2tlb_reqq.sv:94` (声明 `bypass_grant_vec`)

```systemverilog
        91:         // Arbitration Control
        92:         logic [TOTAL_DEPTH-1:0]     ffr_oh;           // Find First Ready One-Hot
        93:         logic [TOTAL_DEPTH-1:0]     entry_grant_vec;  // Grant to specific entry
        94: >>      logic [TOTAL_DEPTH-1:0]     bypass_grant_vec; // Grant to entry allocated by bypass issue
        95:     
        96:         // Internal Payload Arrays (to collect data from instances)
        97:         logic [VPN_W-1:0]           entry_out_vpn   [TOTAL_DEPTH-1:0];
```

`mmu/rtl/mmu_l2tlb_reqq.sv:105` (声明 `entry_rdy_asid`)

```systemverilog
       102:         // Intermediate Mux Signals
       103:         logic                       entry_ready;
       104:         logic [VPN_W-1:0]           entry_rdy_vpn;
       105: >>      logic [ASID_W-1:0]          entry_rdy_asid;
       106:         logic [EID_W-1:0]           entry_rdy_eid;
       107:         logic [TYPE_W-1:0]          entry_rdy_type;
       108:         logic [ID_W-1:0]            entry_rdy_id;
```

## 模块 `mmu_l2tlb_reqq_entry`

源码：`mmu/rtl/mmu_l2tlb_reqq_entry.sv`
原始未覆盖记录数：`8`；合并后唯一代码对象数：`8`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 16 | `cpurst_b -> input  logic                cpurst_b,               // Active Low Async Reset` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 18 | `pad_yy_icg_scan_en -> input  logic                pad_yy_icg_scan_en,     // Scan Test Enable` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 25 | `alloc_type[1:0] -> input  logic [TYPE_W-1:0]   alloc_type,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 37 | `fb_miss_retry -> input  logic                fb_miss_retry,          // L2TLB Miss & Buffer Full (Retry)` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 46 | `entry_out_asid[15:0] -> output logic [ASID_W-1:0]   entry_out_asid,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 48 | `entry_out_type[1:0] -> output logic [TYPE_W-1:0]   entry_out_type` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:16` (声明 `cpurst_b`)

```systemverilog
        13:     )(
        14:         // Global Signals
        15:         input  logic                cp0_mmu_icg_en,         // Clock Gating Enable from CP0
        16: >>      input  logic                cpurst_b,               // Active Low Async Reset
        17:         input  logic                reqq_clk,               // Global Clock
        18:         input  logic                pad_yy_icg_scan_en,     // Scan Test Enable
        19:     
```

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:18` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        15:         input  logic                cp0_mmu_icg_en,         // Clock Gating Enable from CP0
        16:         input  logic                cpurst_b,               // Active Low Async Reset
        17:         input  logic                reqq_clk,               // Global Clock
        18: >>      input  logic                pad_yy_icg_scan_en,     // Scan Test Enable
        19:     
        20:         // Allocation Interface (Write)
        21:         input  logic                entry_alloc_en,         // Write Enable (Allocate)
```

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:25` (声明 `alloc_type`)

```systemverilog
        22:         input  logic [VPN_W-1:0]    alloc_vpn,
        23:         //input  logic [ASID_W-1:0]   alloc_asid,
        24:         input  logic [EID_W-1:0]    alloc_eid,
        25: >>      input  logic [TYPE_W-1:0]   alloc_type,
        26:     
        27:         // Issue Interface (Read/Status)
        28:         input  logic                issue_grant,            // Arbiter grants this entry (Normal Issue)
```

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:37` (声明 `fb_miss_retry`)

```systemverilog
        34:         input  logic                fb_match_id,            // Feedback ID matches this entry
        35:         input  logic                fb_hit,                 // L2TLB Hit
        36:         input  logic                fb_miss_alloc,          // L2TLB Miss & Buffer Allocated
        37: >>      input  logic                fb_miss_retry,          // L2TLB Miss & Buffer Full (Retry)
        38:     
        39:         // Output Status & Payload
        40:         output logic                entry_vld,              // Entry is Valid
```

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:46` (声明 `entry_out_asid`)

```systemverilog
        43:         
        44:         // Flattened Payload Output
        45:         output logic [VPN_W-1:0]    entry_out_vpn,
        46: >>      output logic [ASID_W-1:0]   entry_out_asid,
        47:         output logic [EID_W-1:0]    entry_out_eid,
        48:         output logic [TYPE_W-1:0]   entry_out_type
        49:     );
```

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:48` (声明 `entry_out_type`)

```systemverilog
        45:         output logic [VPN_W-1:0]    entry_out_vpn,
        46:         output logic [ASID_W-1:0]   entry_out_asid,
        47:         output logic [EID_W-1:0]    entry_out_eid,
        48: >>      output logic [TYPE_W-1:0]   entry_out_type
        49:     );
        50:     
        51:         // &Regs; 
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 56 | `entry_asid[15:0] -> logic [ASID_W-1:0]  entry_asid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 58 | `entry_type[1:0] -> logic [TYPE_W-1:0]  entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:56` (声明 `entry_asid`)

```systemverilog
        53:         // Register Definitions
        54:         //-------------------------------------------------------------------------
        55:         logic [VPN_W-1:0]   entry_vpn;
        56: >>      logic [ASID_W-1:0]  entry_asid;
        57:         logic [EID_W-1:0]   entry_eid;
        58:         logic [TYPE_W-1:0]  entry_type;
        59:     
```

`mmu/rtl/mmu_l2tlb_reqq_entry.sv:58` (声明 `entry_type`)

```systemverilog
        55:         logic [VPN_W-1:0]   entry_vpn;
        56:         logic [ASID_W-1:0]  entry_asid;
        57:         logic [EID_W-1:0]   entry_eid;
        58: >>      logic [TYPE_W-1:0]  entry_type;
        59:     
        60:         logic               r_vld;
        61:         logic               r_sent;
```

## 模块 `mmu_l2tlb_replacement_policy`

源码：`mmu/rtl/mmu_l2tlb_replacement_policy.sv`
原始未覆盖记录数：`1`；合并后唯一代码对象数：`1`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 8 | `rst_n -> input   logic				rst_n	  ,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |

`mmu/rtl/mmu_l2tlb_replacement_policy.sv:8` (声明 `rst_n`)

```systemverilog
         5:     
         6:     )(
         7:         input   logic				clk	  ,
         8: >>      input   logic				rst_n	  , 
         9:     	
        10:        // Control signals 
        11:         input   logic				access_vld, 
```

## 模块 `mmu_l2tlb_rrpv_wbuf`

源码：`mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv`
原始未覆盖记录数：`8`；合并后唯一代码对象数：`6`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 129 | `EXPRESSION (push_req && (((!push_new_entry)) || ((!fifo_full)) || pop_do))` | 1 0 Not Covered | 1 |
| 129 | `SUB-EXPRESSION (((!push_new_entry)) || ((!fifo_full)) || pop_do)` | 0 0 0 Not Covered; 0 0 1 Not Covered; 1 0 0 Not Covered | 3 |
| 134 | `EXPRESSION (count == DEPTH)` | 1 Not Covered | 1 |

`mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv:129`

```systemverilog
       126:         assign push_new_bank  = push_vld & ~push_hit_comb;
       127:         assign push_new_entry = |push_new_bank;
       128:         assign pop_do         = pop_grant && !empty;
       129: >>      assign push_accept    = push_req && (!push_new_entry || !fifo_full || pop_do);
       130:     
       131:         //=========================================================================
       132:         // 2. FIFO Logic (Circular Buffer)
```

`mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv:134`

```systemverilog
       131:         //=========================================================================
       132:         // 2. FIFO Logic (Circular Buffer)
       133:         //=========================================================================
       134: >>      assign fifo_full = (count == DEPTH);
       135:         assign full      = (count >= ARB_STALL_LEVEL);
       136:         assign empty     = (count == 0);
       137:     
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 21 | `rst_n -> input  logic                     rst_n,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |

`mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv:21` (声明 `rst_n`)

```systemverilog
        18:         parameter DEPTH       = 4  // Depth of Write Buffer
        19:     	)(
        20:         input  logic                     clk,
        21: >>      input  logic                     rst_n,
        22:     
        23:         //-------------------------------------------------------------------------
        24:         // 1. Push Interface (From SRRIP Update Logic)
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 81 | `count[3] -> logic [$clog2(DEPTH):0]   count;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 92 | `fifo_full -> logic               fifo_full;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv:81` (声明 `count`)

```systemverilog
        78:         // FIFO Pointers
        79:         logic [$clog2(DEPTH)-1:0] wr_ptr;
        80:         logic [$clog2(DEPTH)-1:0] rd_ptr;
        81: >>      logic [$clog2(DEPTH):0]   count;
        82:     
        83:         // Bypass logic signals
        84:         logic [WAY_NUM-1:0] lookup_hit_comb;
```

`mmu/rtl/mmu_l2tlb_rrpv_wbuf.sv:92` (声明 `fifo_full`)

```systemverilog
        89:         logic               push_new_entry;
        90:         logic               push_accept;
        91:         logic               pop_do;
        92: >>      logic               fifo_full;
        93:     
        94:         localparam int ARB_STALL_LEVEL = (DEPTH > 3) ? (DEPTH - 3) : DEPTH;
        95:     
```

## 模块 `mmu_l2tlb_mb`

源码：`mmu/rtl/mmu_l2tlb_mb.sv`
原始未覆盖记录数：`29`；合并后唯一代码对象数：`21`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 135 | `SUB-EXPRESSION (req_valid & req_is_dtlb & ((!mb_dtlb_full)))` | 1 1 0 Not Covered | 1 |
| 215 | `EXPRESSION (entry_rdy_vec[4] | ffr_therm[(4 - 1)])` | 1 0 Not Covered | 1 |
| 215 | `EXPRESSION (entry_rdy_vec[5] | ffr_therm[(5 - 1)])` | 1 0 Not Covered | 1 |
| 215 | `EXPRESSION (entry_rdy_vec[6] | ffr_therm[(6 - 1)])` | 1 0 Not Covered | 1 |
| 215 | `EXPRESSION (entry_rdy_vec[7] | ffr_therm[(7 - 1)])` | 1 0 Not Covered | 1 |
| 215 | `EXPRESSION (entry_rdy_vec[8] | ffr_therm[(8 - 1)])` | 1 0 Not Covered | 1 |
| 220 | `EXPRESSION (ffr_therm[4] & ((~ffr_therm[(4 - 1)])))` | 1 1 Not Covered | 1 |
| 220 | `EXPRESSION (ffr_therm[5] & ((~ffr_therm[(5 - 1)])))` | 1 1 Not Covered | 1 |
| 220 | `EXPRESSION (ffr_therm[6] & ((~ffr_therm[(6 - 1)])))` | 1 1 Not Covered | 1 |
| 220 | `EXPRESSION (ffr_therm[7] & ((~ffr_therm[(7 - 1)])))` | 1 1 Not Covered | 1 |
| 220 | `EXPRESSION (ffr_therm[8] & ((~ffr_therm[(8 - 1)])))` | 1 1 Not Covered | 1 |
| 227 | `EXPRESSION (req_valid & ((|alloc_en_vec)))` | 0 1 Not Covered | 1 |

`mmu/rtl/mmu_l2tlb_mb.sv:135`

```systemverilog
       132:     
       133:         // DTLB Allocation Enable
       134:         assign mb_dtlb_full = &entry_vld_vec[TOTAL_DEPTH-1:1]; // Fixed range index
       135: >>      assign alloc_en_vec[TOTAL_DEPTH-1:1] = (req_valid & req_is_dtlb & !mb_dtlb_full) ? dtlb_alloc_oh : {DTLB_DEPTH{1'b0}};
       136:     
       137:         //=========================================================================
       138:         // 2. Entry Instantiation
```

`mmu/rtl/mmu_l2tlb_mb.sv:215`

```systemverilog
       212:             genvar k; // Use different loop variable
       213:             assign ffr_therm[0] = entry_rdy_vec[0]; 
       214:             for(k = 1; k < TOTAL_DEPTH; k++) begin : gene_therm
       215: >>              assign ffr_therm[k] = entry_rdy_vec[k] | ffr_therm[k-1];
       216:             end
       217:     
       218:             assign ffr_oh[0] = ffr_therm[0];
```

`mmu/rtl/mmu_l2tlb_mb.sv:220`

```systemverilog
       217:     
       218:             assign ffr_oh[0] = ffr_therm[0];
       219:             for(k = 1; k < TOTAL_DEPTH; k++) begin : gene_onehot
       220: >>              assign ffr_oh[k] = ffr_therm[k] & ~ffr_therm[k-1];
       221:             end
       222:         endgenerate
       223:          
```

`mmu/rtl/mmu_l2tlb_mb.sv:227`

```systemverilog
       224:         assign entry_grant_vec = ffr_oh & {TOTAL_DEPTH{ptw_ready}};
       225:         assign bypass_grant_vec = alloc_en_vec & {TOTAL_DEPTH{ptw_ready & !entry_ready}};
       226:         assign entry_ready     = |entry_rdy_vec; 
       227: >>      assign req_alloc_valid = req_valid & |alloc_en_vec;
       228:         assign issue_req       = entry_ready | req_alloc_valid;
       229:     
       230:         //=========================================================================
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 19 | `cpurst_b -> input  logic                      cpurst_b,` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 21 | `pad_yy_icg_scan_en -> input  logic                      pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/mmu_l2tlb_mb.sv:19` (声明 `cpurst_b`)

```systemverilog
        16:     )(
        17:         // Global Signals
        18:         input  logic                      cp0_mmu_icg_en,
        19: >>      input  logic                      cpurst_b,
        20:         input  logic                      reqq_clk,
        21:         input  logic                      pad_yy_icg_scan_en,
        22:     
```

`mmu/rtl/mmu_l2tlb_mb.sv:21` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        18:         input  logic                      cp0_mmu_icg_en,
        19:         input  logic                      cpurst_b,
        20:         input  logic                      reqq_clk,
        21: >>      input  logic                      pad_yy_icg_scan_en,
        22:     
        23:         input  logic                      tlboper_ptw_abort,
        24:     
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 75 | `entry_rdy_vec[8:4] -> logic [TOTAL_DEPTH-1:0]     entry_rdy_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 79 | `ffr_oh[8:4] -> logic [TOTAL_DEPTH-1:0]     ffr_oh;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 80 | `entry_grant_vec[8:4] -> logic [TOTAL_DEPTH-1:0]     entry_grant_vec;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 92 | `entry_rdy_eid[2:0] -> logic [L1EID_WIDTH-1:0]     entry_rdy_eid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 233 | `entry_rdy_id[3:2] -> logic [L2EID_WIDTH-1:0] entry_rdy_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_entries[0].local_alloc_l1eid[2:0]` | Toggle=No, 1->0=No, 0->1=No | 1 |
| - | `gen_entries[0].local_alloc_l2_queue_id[3:0]` | Toggle=No, 1->0=No, 0->1=No | 9 |

`mmu/rtl/mmu_l2tlb_mb.sv:75` (声明 `entry_rdy_vec`)

```systemverilog
        72:         
        73:         // Entry Status Vectors
        74:         logic [TOTAL_DEPTH-1:0]     entry_vld_vec;
        75: >>      logic [TOTAL_DEPTH-1:0]     entry_rdy_vec;
        76:         logic [TOTAL_DEPTH-1:0]     entry_dealloc_vec;
        77:         
        78:         // Arbitration Control
```

`mmu/rtl/mmu_l2tlb_mb.sv:79` (声明 `ffr_oh`)

```systemverilog
        76:         logic [TOTAL_DEPTH-1:0]     entry_dealloc_vec;
        77:         
        78:         // Arbitration Control
        79: >>      logic [TOTAL_DEPTH-1:0]     ffr_oh;           
        80:         logic [TOTAL_DEPTH-1:0]     entry_grant_vec; 
        81:         logic [TOTAL_DEPTH-1:0]     bypass_grant_vec;
        82:         logic                       entry_ready;
```

`mmu/rtl/mmu_l2tlb_mb.sv:80` (声明 `entry_grant_vec`)

```systemverilog
        77:         
        78:         // Arbitration Control
        79:         logic [TOTAL_DEPTH-1:0]     ffr_oh;           
        80: >>      logic [TOTAL_DEPTH-1:0]     entry_grant_vec; 
        81:         logic [TOTAL_DEPTH-1:0]     bypass_grant_vec;
        82:         logic                       entry_ready;
        83:     
```

`mmu/rtl/mmu_l2tlb_mb.sv:92` (声明 `entry_rdy_eid`)

```systemverilog
        89:     
        90:         // Mux Signals
        91:         logic [VPN_WIDTH-1:0]       entry_rdy_vpn;
        92: >>      logic [L1EID_WIDTH-1:0]     entry_rdy_eid;
        93:         logic [PTW_TYPE_WIDTH-1:0]  entry_rdy_type;
        94:         logic                       entry_rdy_is_dtlb;
        95:     
```

`mmu/rtl/mmu_l2tlb_mb.sv:233` (声明 `entry_rdy_id`)

```systemverilog
       230:         //=========================================================================
       231:         // 4. Output Mux Logic
       232:         //=========================================================================
       233: >>      logic [L2EID_WIDTH-1:0] entry_rdy_id;
       234:         always_comb begin
       235:             entry_rdy_vpn     = {VPN_WIDTH{1'b0}};
       236:             entry_rdy_eid     = {L1EID_WIDTH{1'b0}};
```

## 模块 `mmu_l2tlb_mb_entry`

源码：`mmu/rtl/mmu_l2tlb_mb_entry.sv`
原始未覆盖记录数：`11`；合并后唯一代码对象数：`11`。

### 条件覆盖

说明：这里列出组合表达式中未覆盖到的 term 取值组合；`URG 细节` 中的位串对应表达式里的 term 顺序。参数化条目（如不同 entry index）已聚合，`影响条目数` 表示同一表达式模式命中的实例数。

| 行号 | 未覆盖代码/对象 | URG 细节（采样） | 影响条目数 |
| ---: | --- | --- | ---: |
| 110 | `EXPRESSION (fb_match_id && fb_hit)` | 1 0 Not Covered | 1 |

`mmu/rtl/mmu_l2tlb_mb_entry.sv:110`

```systemverilog
       107:         // 2. Valid Bit Logic
       108:         //=========================================================================
       109:         // Deallocate when feedback returns Success (Hit or Alloc Miss Buffer)
       110: >>      assign entry_clr = fb_match_id && fb_hit;
       111:     
       112:         always @(posedge entry_clk or negedge cpurst_b) begin
       113:             if (!cpurst_b)
```

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 20 | `cpurst_b -> input  logic                cpurst_b,               // Active Low Async Reset` | Toggle=No, 1->0=No, 0->1=Yes | INPUT | 1 |
| 22 | `pad_yy_icg_scan_en -> input  logic                pad_yy_icg_scan_en,     // Scan Test Enable` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 31 | `alloc_queue_id[3:0] -> input  logic [QUE_ID_WIDTH-1:0] alloc_queue_id,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 53 | `entry_out_l1eid[2] -> output logic [L1EID_WIDTH-1:0]    entry_out_l1eid,` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |
| 54 | `entry_out_queue_id[3:0] -> output logic [QUE_ID_WIDTH-1:0] entry_out_queue_id,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 55 | `entry_out_type[0] -> output logic [PTW_TYPE_WIDTH-1:0]   entry_out_type` | Toggle=No, 1->0=No, 0->1=Yes | OUTPUT | 1 |

`mmu/rtl/mmu_l2tlb_mb_entry.sv:20` (声明 `cpurst_b`)

```systemverilog
        17:     )(
        18:         // Global Signals
        19:         input  logic                cp0_mmu_icg_en,         // Clock Gating Enable from CP0
        20: >>      input  logic                cpurst_b,               // Active Low Async Reset
        21:         input  logic                reqq_clk,               // Global Clock
        22:         input  logic                pad_yy_icg_scan_en,     // Scan Test Enable
        23:         input  logic                tlboper_ptw_abort,       // PTW Abort
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:22` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        19:         input  logic                cp0_mmu_icg_en,         // Clock Gating Enable from CP0
        20:         input  logic                cpurst_b,               // Active Low Async Reset
        21:         input  logic                reqq_clk,               // Global Clock
        22: >>      input  logic                pad_yy_icg_scan_en,     // Scan Test Enable
        23:         input  logic                tlboper_ptw_abort,       // PTW Abort
        24:     
        25:         // Allocation Interface (Write)
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:31` (声明 `alloc_queue_id`)

```systemverilog
        28:         //input  logic [ASID_W-1:0]   alloc_asid,
        29:         input  logic [L1EID_WIDTH-1:0]    alloc_l1eid,
        30:         input  logic [PTW_TYPE_WIDTH-1:0]   alloc_type,
        31: >>      input  logic [QUE_ID_WIDTH-1:0] alloc_queue_id,
        32:     
        33:         // Issue Interface (Read/Status)
        34:         input  logic                issue_grant,            // Arbiter grants this entry (Normal Issue)
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:53` (声明 `entry_out_l1eid`)

```systemverilog
        50:         // Flattened Payload Output
        51:         output logic [VPN_WIDTH-1:0]    entry_out_vpn,
        52:         //output logic [ASID_W-1:0]   entry_out_asid,
        53: >>      output logic [L1EID_WIDTH-1:0]    entry_out_l1eid,
        54:         output logic [QUE_ID_WIDTH-1:0] entry_out_queue_id,
        55:         output logic [PTW_TYPE_WIDTH-1:0]   entry_out_type
        56:     );
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:54` (声明 `entry_out_queue_id`)

```systemverilog
        51:         output logic [VPN_WIDTH-1:0]    entry_out_vpn,
        52:         //output logic [ASID_W-1:0]   entry_out_asid,
        53:         output logic [L1EID_WIDTH-1:0]    entry_out_l1eid,
        54: >>      output logic [QUE_ID_WIDTH-1:0] entry_out_queue_id,
        55:         output logic [PTW_TYPE_WIDTH-1:0]   entry_out_type
        56:     );
        57:     
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:55` (声明 `entry_out_type`)

```systemverilog
        52:         //output logic [ASID_W-1:0]   entry_out_asid,
        53:         output logic [L1EID_WIDTH-1:0]    entry_out_l1eid,
        54:         output logic [QUE_ID_WIDTH-1:0] entry_out_queue_id,
        55: >>      output logic [PTW_TYPE_WIDTH-1:0]   entry_out_type
        56:     );
        57:     
        58:         // &Regs; 
```

### 翻转覆盖 - 内部信号

说明：这里列出模块内部信号上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位信号定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 影响条目数 |
| ---: | --- | --- | ---: |
| 64 | `entry_eid[2:0] -> logic [L1EID_WIDTH-1:0]   entry_eid;` | Toggle=No, 1->0=No, 0->1=No | 1 |
| 65 | `entry_type[0] -> logic [PTW_TYPE_WIDTH-1:0]  entry_type;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 70 | `entry_l1eid[2] -> logic [L1EID_WIDTH-1:0] entry_l1eid;` | Toggle=No, 1->0=No, 0->1=Yes | 1 |
| 71 | `entry_queue_id[3:0] -> logic [QUE_ID_WIDTH-1:0] entry_queue_id;` | Toggle=No, 1->0=No, 0->1=No | 1 |

`mmu/rtl/mmu_l2tlb_mb_entry.sv:64` (声明 `entry_eid`)

```systemverilog
        61:         //-------------------------------------------------------------------------
        62:         logic [VPN_WIDTH-1:0]   entry_vpn;
        63:         //logic [ASID_W-1:0]  entry_asid;
        64: >>      logic [L1EID_WIDTH-1:0]   entry_eid;
        65:         logic [PTW_TYPE_WIDTH-1:0]  entry_type;
        66:     
        67:         logic               r_vld;
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:65` (声明 `entry_type`)

```systemverilog
        62:         logic [VPN_WIDTH-1:0]   entry_vpn;
        63:         //logic [ASID_W-1:0]  entry_asid;
        64:         logic [L1EID_WIDTH-1:0]   entry_eid;
        65: >>      logic [PTW_TYPE_WIDTH-1:0]  entry_type;
        66:     
        67:         logic               r_vld;
        68:         logic               r_sent;
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:70` (声明 `entry_l1eid`)

```systemverilog
        67:         logic               r_vld;
        68:         logic               r_sent;
        69:     
        70: >>      logic [L1EID_WIDTH-1:0] entry_l1eid;
        71:         logic [QUE_ID_WIDTH-1:0] entry_queue_id;
        72:         // &Wires;
        73:         //-------------------------------------------------------------------------
```

`mmu/rtl/mmu_l2tlb_mb_entry.sv:71` (声明 `entry_queue_id`)

```systemverilog
        68:         logic               r_sent;
        69:     
        70:         logic [L1EID_WIDTH-1:0] entry_l1eid;
        71: >>      logic [QUE_ID_WIDTH-1:0] entry_queue_id;
        72:         // &Wires;
        73:         //-------------------------------------------------------------------------
        74:         // Wire Definitions
```

## 模块 `ct_mmu_l2tlb_rrpv_array`

源码：`mmu/rtl/ct_mmu_l2tlb_rrpv_array.sv`
原始未覆盖记录数：`1`；合并后唯一代码对象数：`1`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 8 | `pad_yy_icg_scan_en -> input                             pad_yy_icg_scan_en,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/ct_mmu_l2tlb_rrpv_array.sv:8` (声明 `pad_yy_icg_scan_en`)

```systemverilog
         5:     )(
         6:       input                             cp0_mmu_icg_en,
         7:       input                             forever_cpuclk,
         8: >>    input                             pad_yy_icg_scan_en,
         9:     
        10:       input   [WAY_NUM-1:0]             l2tlb_rrpv_cen,   // Chip enable per way
        11:       input   [WAY_NUM-1:0]             l2tlb_rrpv_wen,   // Write enable per way
```

## 模块 `ct_mmu_l2tlb_tag_array`

源码：`mmu/rtl/ct_mmu_l2tlb_tag_array.sv`
原始未覆盖记录数：`49`；合并后唯一代码对象数：`24`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 13 | `l2tlb_tag_din[18] -> input   [1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1-1:0] l2tlb_tag_din,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 2 |
| 14 | `l2tlb_tag_dout[0] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 25 |
| 14 | `l2tlb_tag_dout[19:16] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[59:55] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[67:63] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[152:151] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[156:155] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[163:159] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[211:204] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[238:236] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[245:244] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[252:251] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[255:254] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[259:257] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[268:267] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[283:282] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[286:285] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[292:291] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[296:295] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[307:303] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[334:332] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[355:351] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `l2tlb_tag_dout[382:381] -> output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 15 | `pad_yy_icg_scan_en -> input                             pad_yy_icg_scan_en` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/ct_mmu_l2tlb_tag_array.sv:13` (声明 `l2tlb_tag_din`)

```systemverilog
        10:       input   [WAY_NUM-1:0]             l2tlb_tag_cen,   // Chip enable per way
        11:       input   [WAY_NUM-1:0]             l2tlb_tag_wen,   // Write enable per way
        12:       input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_tag_idx,   // Flattened skewed index
        13: >>    input   [1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1-1:0] l2tlb_tag_din,
        14:       output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,
        15:       input                             pad_yy_icg_scan_en
        16:     );
```

`mmu/rtl/ct_mmu_l2tlb_tag_array.sv:14` (声明 `l2tlb_tag_dout`)

```systemverilog
        11:       input   [WAY_NUM-1:0]             l2tlb_tag_wen,   // Write enable per way
        12:       input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_tag_idx,   // Flattened skewed index
        13:       input   [1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1-1:0] l2tlb_tag_din,
        14: >>    output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,
        15:       input                             pad_yy_icg_scan_en
        16:     );
        17:     
```

`mmu/rtl/ct_mmu_l2tlb_tag_array.sv:15` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        12:       input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_tag_idx,   // Flattened skewed index
        13:       input   [1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1-1:0] l2tlb_tag_din,
        14:       output  [WAY_NUM*(1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1)-1:0] l2tlb_tag_dout,
        15: >>    input                             pad_yy_icg_scan_en
        16:     );
        17:     
        18:     // Width: VLD(1) + VPN(27) + ASID(16) + PGS(3) + Global(1) = 48 bits
```

## 模块 `ct_mmu_l2tlb_data_array`

源码：`mmu/rtl/ct_mmu_l2tlb_data_array.sv`
原始未覆盖记录数：`20`；合并后唯一代码对象数：`11`。

### 翻转覆盖 - 端口

说明：这里列出 TLB 实例端口上未发生完整 0->1 或 1->0 翻转的信号或位段。`未覆盖代码/对象` 列给出 `位段 -> 源码声明` 用于定位端口定义。参数化位段已聚合，`影响条目数` 表示同一信号模式命中的位段/实例数。

| 行号 | 未覆盖代码/对象 | URG 细节 | 方向 | 影响条目数 |
| ---: | --- | --- | --- | ---: |
| 12 | `l2tlb_data_din[37:35] -> input   [PPN_WIDTH+FLG_WIDTH-1:0] l2tlb_data_din,` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |
| 13 | `l2tlb_data_dout[41:34] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[83:76] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[121:119] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[130] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 10 |
| 13 | `l2tlb_data_dout[167:160] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[209:201] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[251:243] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[293:286] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 13 | `l2tlb_data_dout[335:328] -> output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,` | Toggle=No, 1->0=No, 0->1=No | OUTPUT | 1 |
| 14 | `pad_yy_icg_scan_en -> input                             pad_yy_icg_scan_en` | Toggle=No, 1->0=No, 0->1=No | INPUT | 1 |

`mmu/rtl/ct_mmu_l2tlb_data_array.sv:12` (声明 `l2tlb_data_din`)

```systemverilog
         9:       input   [WAY_NUM-1:0]             l2tlb_data_cen,  // Chip enable per way
        10:       input   [WAY_NUM-1:0]             l2tlb_data_wen,  // Write enable per way
        11:       input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_data_idx,  // Flattened skewed index
        12: >>    input   [PPN_WIDTH+FLG_WIDTH-1:0] l2tlb_data_din,
        13:       output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,
        14:       input                             pad_yy_icg_scan_en
        15:     );
```

`mmu/rtl/ct_mmu_l2tlb_data_array.sv:13` (声明 `l2tlb_data_dout`)

```systemverilog
        10:       input   [WAY_NUM-1:0]             l2tlb_data_wen,  // Write enable per way
        11:       input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_data_idx,  // Flattened skewed index
        12:       input   [PPN_WIDTH+FLG_WIDTH-1:0] l2tlb_data_din,
        13: >>    output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,
        14:       input                             pad_yy_icg_scan_en
        15:     );
        16:     
```

`mmu/rtl/ct_mmu_l2tlb_data_array.sv:14` (声明 `pad_yy_icg_scan_en`)

```systemverilog
        11:       input   [WAY_NUM*ADDR_WIDTH-1:0]  l2tlb_data_idx,  // Flattened skewed index
        12:       input   [PPN_WIDTH+FLG_WIDTH-1:0] l2tlb_data_din,
        13:       output  [WAY_NUM*(PPN_WIDTH+FLG_WIDTH)-1:0] l2tlb_data_dout,
        14: >>    input                             pad_yy_icg_scan_en
        15:     );
        16:     
        17:     // Width: PPN(28) + Flags(14) = 42 bits
```

## 模块 `mmu_l2tlb_rrpv_sva`

源码：`mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv`
原始未覆盖记录数：`1`；合并后唯一代码对象数：`1`。

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `c_l2tlb_ptw_reselect_under_backpressure` | cover | 206452807 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l2tlb_rrpv_sva.sv:179` (`c_l2tlb_ptw_reselect_under_backpressure`)

```systemverilog
       175:            && $past(l2tlb_ptw_req && !ptw_ready)
       176:            && (l2tlb_ptw_id == $past(l2tlb_ptw_id)))
       177:             |-> ($stable(l2tlb_ptw_type) && $stable(l2tlb_ptw_vpn)));
       178:     
       179: >>    c_l2tlb_ptw_reselect_under_backpressure: cover property (@(posedge forever_cpuclk)
       180:         disable iff (!cpurst_b || !l2tlb_sva_past_valid)
       181:           l2tlb_ptw_req && !ptw_ready
       182:           && $past(l2tlb_ptw_req && !ptw_ready)
       183:           && (l2tlb_ptw_id != $past(l2tlb_ptw_id)));
```

## 模块 `mmu_l2tlb_mb_sva`

源码：`mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv`
原始未覆盖记录数：`3`；合并后唯一代码对象数：`3`。

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `a_dtlb_full_no_overwrite` | assertion | 206452807 | 0 | 1 |
| `a_itlb_full_no_overwrite` | assertion | 206452807 | 0 | 1 |
| `c_mb_issue_reselect_under_backpressure` | cover | 206452807 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv:93` (`a_dtlb_full_no_overwrite`)

```systemverilog
        89:       a_dtlb_alloc_partition: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
        90:         (req_valid && req_is_dtlb && !(&entry_vld_vec[TOTAL_DEPTH-1:1]))
        91:           |-> (!alloc_en_vec[0] && $onehot(alloc_en_vec[TOTAL_DEPTH-1:1])));
        92:     
        93: >>    a_dtlb_full_no_overwrite: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
        94:         (req_valid && req_is_dtlb && (&entry_vld_vec[TOTAL_DEPTH-1:1]))
        95:           |-> (!req_alloc_valid && (alloc_en_vec[TOTAL_DEPTH-1:1] == '0)));
        96:     
        97:       a_dtlb_alloc_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
```

`mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv:85` (`a_itlb_full_no_overwrite`)

```systemverilog
        81:       a_itlb_alloc_entry0_only: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
        82:         (req_valid && !req_is_dtlb && !entry_vld_vec[0])
        83:           |-> (alloc_en_vec[0] && !(|alloc_en_vec[TOTAL_DEPTH-1:1])));
        84:     
        85: >>    a_itlb_full_no_overwrite: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
        86:         (req_valid && !req_is_dtlb && entry_vld_vec[0])
        87:           |-> (!req_alloc_valid && !alloc_en_vec[0]));
        88:     
        89:       a_dtlb_alloc_partition: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
```

`mmu_verification/testbench/top/mmu_l2tlb_mb_sva.sv:135` (`c_mb_issue_reselect_under_backpressure`)

```systemverilog
       131:            && $past(issue_req && !ptw_ready)
       132:            && (issue_eid == $past(issue_eid)))
       133:             |-> ($stable(issue_vpn) && $stable(issue_type) && $stable(issue_is_dtlb)));
       134:     
       135: >>    c_mb_issue_reselect_under_backpressure: cover property (@(posedge reqq_clk)
       136:         disable iff (!cpurst_b || !l2mb_sva_past_valid)
       137:           issue_req && !ptw_ready
       138:           && $past(issue_req && !ptw_ready)
       139:           && (issue_eid != $past(issue_eid)));
```

## 模块 `mmu_l2tlb_rrpv_wbuf_sva`

源码：`mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv`
原始未覆盖记录数：`3`；合并后唯一代码对象数：`3`。

### 断言/cover 命中覆盖

说明：`Real Successes=0` 表示 assert 在测试中虽然被尝试但从未真正成立；`Matches=0` 表示 cover 点未采样到。

| 名称 | 类型 | Attempts | Successes/Matches | 影响条目数 |
| --- | --- | ---: | ---: | ---: |
| `a_cam_hit_only_push_may_accept_when_full` | assertion | 206452807 | 0 | 1 |
| `a_true_full_blocks_new_entry_without_pop` | assertion | 206452807 | 0 | 1 |
| `c_rrpv_wbuf_true_full_block` | cover | 206452807 | 0 | 1 |

`mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv:111` (`a_cam_hit_only_push_may_accept_when_full`)

```systemverilog
       107:       // they do not increase occupancy.
       108:       a_true_full_blocks_new_entry_without_pop: assert property (@(posedge clk) disable iff (!rst_n)
       109:         (push_req && push_new_entry && fifo_full && !pop_do) |-> !push_accept);
       110:     
       111: >>    a_cam_hit_only_push_may_accept_when_full: assert property (@(posedge clk) disable iff (!rst_n)
       112:         (push_req && !push_new_entry && fifo_full) |-> push_accept);
       113:     
       114:       a_push_accept_implies_request: assert property (@(posedge clk) disable iff (!rst_n)
       115:         push_accept |-> push_req);
```

`mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv:108` (`a_true_full_blocks_new_entry_without_pop`)

```systemverilog
       104:     
       105:       // A new FIFO slot may not be accepted when the FIFO is truly full unless a
       106:       // pop happens in the same cycle. CAM-hit-only updates are allowed because
       107:       // they do not increase occupancy.
       108: >>    a_true_full_blocks_new_entry_without_pop: assert property (@(posedge clk) disable iff (!rst_n)
       109:         (push_req && push_new_entry && fifo_full && !pop_do) |-> !push_accept);
       110:     
       111:       a_cam_hit_only_push_may_accept_when_full: assert property (@(posedge clk) disable iff (!rst_n)
       112:         (push_req && !push_new_entry && fifo_full) |-> push_accept);
```

`mmu_verification/testbench/top/mmu_l2tlb_rrpv_wbuf_sva.sv:170` (`c_rrpv_wbuf_true_full_block`)

```systemverilog
       166:     
       167:       c_rrpv_wbuf_full_seen: cover property (@(posedge clk) disable iff (!rst_n)
       168:         full);
       169:     
       170: >>    c_rrpv_wbuf_true_full_block: cover property (@(posedge clk) disable iff (!rst_n)
       171:         push_req && push_new_entry && fifo_full && !pop_do && !push_accept);
       172:     
       173:       c_rrpv_wbuf_full_release: cover property (@(posedge clk) disable iff (!rst_n)
       174:         full && pop_do);
```

