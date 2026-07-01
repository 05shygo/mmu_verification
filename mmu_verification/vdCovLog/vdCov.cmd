verdiWindowResize -win $_vdCoverage_1 "0" "27" "1920" "906"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier /x2025/GPrj1/IC1/mmu_verification/mmu_verification/output/coverage/phase14_merged.vdb -testdir {} -test {/x2025/GPrj1/IC1/mmu_verification/mmu_verification/output/coverage/phase14_merged/test} -merge MergedTest -db_max_tests 10 -fsm transition
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[0].x_mb_entry}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[0].x_mb_entry.x_mb_entry_gateclk}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[0].x_mb_entry.x_mb_entry_gateclk}  -column {} 
gui_covdetail_select -id  CovDetail.1   -name   Toggle
gui_list_select -id CovDetail.1 -list tgl { external_en   }
gui_list_action -id  CovDetail.1 -list {tgl} external_en
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_src_highlight_item -id CovSrc.1 -lfrom 16 -idxfrom 7 -fileIdFrom 0 -lto 16 -idxto 21 -fileIdTo 0 -selection {gated_clk_cell} -selectionId 0 -replace 0
gui_copy_selected_src  -id  CovSrc.1 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[0].x_mb_entry.x_mb_entry_gateclk}  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[1].x_mb_entry}
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[1].x_mb_entry}
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[1].x_mb_entry}
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[1].x_mb_entry}
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[0].x_mb_entry}
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} {FSM}
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} -descending  {FSM}
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb  -column {FSM} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}
gui_list_expand -id CoverageTable.1   {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}  -column {FSM} 
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}  tb_top.u_dut.x_mmu_l1itlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l1itlb
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l1itlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l1itlb  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}
gui_list_expand -id CoverageTable.1   {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  -column {} 
gui_covdetail_select -id  CovDetail.1   -name   Toggle
gui_list_select -id CovDetail.1 -list tgl { {entry_flg[13:0]}   }
gui_list_action -id  CovDetail.1 -list {tgl} {entry_flg[13:0]}
gui_list_select -id CovDetail.1 -list tgl { {entry_flg[13:0]}  {entry_pgs[2:0]}   }
gui_list_action -id  CovDetail.1 -list {tgl} {entry_pgs[2:0]}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry.x_mb_entry_gateclk}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry.x_mb_entry_gateclk}  -column {Toggle} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry.x_mb_entry_gateclk}  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}
gui_list_expand -id CoverageTable.1   {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}  -column {} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry.x_mb_entry_gateclk}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry.x_mb_entry_gateclk}  -column {} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry.x_mb_entry_gateclk}  tb_top.u_dut.x_mmu_l1itlb   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l1itlb  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  -column {} 
gui_list_select -id CovDetail.1 -list tgl { cpurst_b  {alloc_vpn[26:0]}   }
gui_list_action -id  CovDetail.1 -list {tgl} {alloc_vpn[26:0]}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  tb_top.u_dut.x_ct_mmu_ptw   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw
gui_list_expand -id CoverageTable.1   tb_top.u_dut.x_ct_mmu_ptw
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw  -column {} 
gui_src_highlight_item -id CovSrc.1 -lfrom 27 -idxfrom 35 -fileIdFrom 0 -lto 27 -idxto 43 -fileIdTo 0 -selection {cpurst_b} -selectionId 0 -replace 0
gui_copy_selected_src  -id  CovSrc.1 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_ptw  tb_top.u_dut.x_ct_mmu_ptw.x_ptw_gateclk   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw.x_ptw_gateclk  -column {} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_ptw.x_ptw_gateclk  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb  -column {} 
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb  -column {Toggle} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  -column {Toggle} 
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb  tb_top.u_dut.x_mmu_l1itlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l1itlb  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_rrpv_wbuf
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_tag_array
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_tag_array
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb  -column {} 
gui_covdetail_select -id  CovDetail.1   -name   FSM
gui_list_select -id CovDetail.1 -list fsmnames { pfu_cur_st   }
gui_list_action -id  CovDetail.1 -list {fsmnames} pfu_cur_st
gui_tbl_select -id CovDetail.1   { {0,2,0,2} }
gui_list_action -id   CovSrc.1  -list {fsm list}  pfu_cur_st#PFU_CHK->PFU_IDLE
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb  -column {Condition} 
gui_src_highlight_item -id CovSrc.1 -lfrom 553 -idxfrom 11 -fileIdFrom 0 -lto 553 -idxto 25 -fileIdTo 0 -selection {rrpv_write_ptw} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 553 -idxfrom 28 -fileIdFrom 0 -lto 553 -idxto 41 -fileIdTo 0 -selection {arb_l2tlb_req} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 553 -idxfrom 11 -fileIdFrom 0 -lto 553 -idxto 25 -fileIdTo 0 -selection {rrpv_write_ptw} -selectionId 0 -replace 0
gui_covtable_show -show  { Module List } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Module List } -id  CoverageTable.1  -test  MergedTest
gui_list_select -id CoverageTable.1 -list covtblModulesList { /axi_if   } -type { Module  }
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /axi_if
gui_list_expand -id CoverageTable.1   /axi_if
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /axi_if  -type {Module}  -column {} 
gui_list_collapse -id  CoverageTable.1   -list {covtblModulesList} /axi_if
gui_list_select -id CoverageTable.1 -list covtblModulesList { /axi_if  /ct_mmu_iplru   } -type { Module Module  }
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iplru
gui_list_expand -id CoverageTable.1   /ct_mmu_iplru
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /ct_mmu_iplru  -type {Module}  -column {} 
gui_list_collapse -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iplru
gui_list_select -id CoverageTable.1 -list covtblModulesList { /ct_mmu_iplru  /ct_mmu_iutlb_fst_entry   } -type { Module Module  }
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iutlb_fst_entry
gui_list_expand -id CoverageTable.1   /ct_mmu_iutlb_fst_entry
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /ct_mmu_iutlb_fst_entry  -type {Module}  -column {} 
gui_list_collapse -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iutlb_fst_entry
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Asserts } -id  CoverageTable.1  -test  MergedTest
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} Assertion
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} {Cover Property}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} {Cover Sequence}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} Total
gui_list_select -id CoverageTable.1 -list covtblAssertList_flat { {/lsu_agent_pkg.\lsu_abort_seq::body .unnamed$$_0.unnamed$$_2}   }
gui_list_action -id  CoverageTable.1 -list {covtblAssertList_flat} {/lsu_agent_pkg.\lsu_abort_seq::body .unnamed$$_0.unnamed$$_2}  -column {Assert} 
gui_list_select -id CoverageTable.1 -list covtblAssertList_flat { {/lsu_agent_pkg.\lsu_abort_seq::body .unnamed$$_0.unnamed$$_2}  {/lsu_agent_pkg.\lsu_stamo_seq::body .unnamed$$_0.unnamed$$_2}   }
gui_list_action -id  CoverageTable.1 -list {covtblAssertList_flat} {/lsu_agent_pkg.\lsu_stamo_seq::body .unnamed$$_0.unnamed$$_2}  -column {Assert} 
gui_assert_filter   -showAssertion   -showCS   -condFilter   all 
gui_assert_filter   -showAssertion   -showCP   -showCS   -condFilter   all 
gui_assert_filter   -showAssertion   -showCS   -condFilter   all 
gui_assert_filter   -showAssertion   -condFilter   all 
gui_assert_filter   -showAssertion   -showCP   -condFilter   all 
gui_assert_filter   -showAssertion   -showCP   -showCS   -condFilter   all 
gui_covtable_show -show  { Statistics } -id  CoverageTable.1  -test  MergedTest
gui_list_expand -id  CoverageTable.1   -list {covtblStatModuleList} Assert
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} Assertion
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} {Cover Property}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} {Cover Sequence}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} Total
gui_covtable_show -show  { Tests } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Statistics } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
