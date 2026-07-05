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
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  tb_top.u_dut.x_ct_mmu_ptw   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_ptw  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}
gui_list_expand -id CoverageTable.1   {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  -column {} 
gui_covdetail_select -id  CovDetail.1   -name   Toggle
gui_list_select -id CovDetail.1 -list tgl { {alloc_vpn[26:0]}   }
gui_list_action -id  CovDetail.1 -list {tgl} {alloc_vpn[26:0]}
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  tb_top.u_dut.x_ct_mmu_ptw   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_ptw  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry.u_l1dtlb_mb_entry_sva}   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry.u_l1dtlb_mb_entry_sva}  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  -column {} 
gui_list_select -id CovDetail.1 -list tgl { {alloc_vpn[26:0]}  {entry_vpn[26:0]}   }
gui_list_select -id CovDetail.1 -list tgl { {entry_vpn[26:0]}  {entry_ppn[27:0]}   }
gui_list_select -id CovDetail.1 -list tgl { {entry_ppn[27:0]}  {pgs_r[2:0]}   }
gui_list_action -id  CovDetail.1 -list {tgl} {pgs_r[2:0]}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  tb_top.misc_if_inst   }
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_ptw
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.misc_if_inst  tb_top.u_dut.x_ct_mmu_tlboper   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_tlboper  tb_top.u_dut.x_ct_mmu_sysmap_3   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_sysmap_3  tb_top.u_dut.x_ct_mmu_tlboper   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_tlboper  tb_top.ifu_if_inst   }
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} {Condition}
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} -descending  {Condition}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.ifu_if_inst  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb  -column {} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  tb_top.u_dut.u_mmu_l1dtlb.u_l1dtlb_vabuf_sva   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb.u_l1dtlb_vabuf_sva  tb_top.u_dut.u_mmu_l1dtlb.x_allocator   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb.x_allocator
gui_list_expand -id CoverageTable.1   tb_top.u_dut.u_mmu_l1dtlb.x_allocator
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb.x_allocator  -column {Assert} 
gui_covdetail_select -id  CovDetail.1   -name   Condition
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb.x_allocator  tb_top.u_dut.u_mmu_l1dtlb.x_scheduler   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb.x_scheduler
gui_list_expand -id CoverageTable.1   tb_top.u_dut.u_mmu_l1dtlb.x_scheduler
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb.x_scheduler  -column {} 
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 24 -fileIdFrom 0 -lto 145 -idxto 36 -fileIdTo 0 -selection {credit_avail} -selectionId 0 -replace 0
gui_cov_src_double_click -id CovSrc.1 -line 145 -col 32 -insert 0 -file /x2025/GPrj1/IC1/mmu_verification/mmu_verification/../mmu/rtl/mmu_l1dtlb_scheduler.sv
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 24 -fileIdFrom 0 -lto 145 -idxto 36 -fileIdTo 0 -selection {credit_avail} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 41 -fileIdFrom 0 -lto 145 -idxto 55 -fileIdTo 0 -selection {mb_entry_ready} -selectionId 0 -replace 0
gui_cov_src_double_click -id CovSrc.1 -line 145 -col 45 -insert 0 -file /x2025/GPrj1/IC1/mmu_verification/mmu_verification/../mmu/rtl/mmu_l1dtlb_scheduler.sv
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 41 -fileIdFrom 0 -lto 145 -idxto 55 -fileIdTo 0 -selection {mb_entry_ready} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 24 -fileIdFrom 0 -lto 145 -idxto 36 -fileIdTo 0 -selection {credit_avail} -selectionId 0 -replace 0
gui_cov_src_double_click -id CovSrc.1 -line 145 -col 29 -insert 0 -file /x2025/GPrj1/IC1/mmu_verification/mmu_verification/../mmu/rtl/mmu_l1dtlb_scheduler.sv
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 24 -fileIdFrom 0 -lto 145 -idxto 36 -fileIdTo 0 -selection {credit_avail} -selectionId 0 -replace 0
gui_list_select -id CovDetail.1 -list vector { 01   }
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_src_highlight_item -id CovSrc.1 -lfrom 145 -idxfrom 24 -fileIdFrom 0 -lto 145 -idxto 36 -fileIdTo 0 -selection {credit_avail} -selectionId 0 -replace 0
gui_list_select -id CovDetail.1 -list cond { {(credit_avail & ((|mb_entry_ready)))}  {(bypass_req_vld && credit_avail && ((!mb_req_vld)))}   }
gui_list_action -id  CovDetail.1 -list {cond} {(bypass_req_vld && credit_avail && ((!mb_req_vld)))}
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_src_highlight_item -id CovSrc.1 -lfrom 213 -idxfrom 20 -fileIdFrom 0 -lto 213 -idxto 30 -fileIdTo 0 -selection {mb_req_vld} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 213 -idxfrom 20 -fileIdFrom 0 -lto 213 -idxto 30 -fileIdTo 0 -selection {mb_req_vld} -selectionId 0 -replace 0
gui_cov_src_double_click -id CovSrc.1 -line 213 -col 25 -insert 0 -file /x2025/GPrj1/IC1/mmu_verification/mmu_verification/../mmu/rtl/mmu_l1dtlb_scheduler.sv
gui_src_highlight_item -id CovSrc.1 -lfrom 213 -idxfrom 20 -fileIdFrom 0 -lto 213 -idxto 30 -fileIdTo 0 -selection {mb_req_vld} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 220 -idxfrom 26 -fileIdFrom 0 -lto 220 -idxto 38 -fileIdTo 0 -selection {mb_entry_vpn} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 213 -idxfrom 20 -fileIdFrom 0 -lto 213 -idxto 30 -fileIdTo 0 -selection {mb_req_vld} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 213 -idxfrom 34 -fileIdFrom 0 -lto 213 -idxto 46 -fileIdTo 0 -selection {credit_avail} -selectionId 0 -replace 0
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb.x_scheduler  tb_top.u_dut.u_mmu_l1dtlb.x_scheduler.u_l1dtlb_scheduler_sva   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb.x_scheduler.u_l1dtlb_scheduler_sva  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}  -column {} 
gui_covdetail_select -id  CovDetail.1   -name   Toggle
gui_list_select -id CovDetail.1 -list tgl { {alloc_vpn[26:0]}   }
gui_list_action -id  CovDetail.1 -list {tgl} {alloc_vpn[26:0]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26:20]}   }
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26:20]}  {alloc_vpn[19:15]}   }
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[19:15]}  {alloc_vpn[26:20]}   }
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26:20]}  {alloc_vpn[19:15]}   }
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[19:15]}  {alloc_vpn[14:13]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[14]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26:20]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[26]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[26:20]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[14]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[14:13]}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[6].x_mb_entry}  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  -column {} 
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26:20]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[26]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[26:20]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26:20]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[26]}
gui_list_select -id CovDetail.1 -list tglDetail { {alloc_vpn[26]}   }
gui_list_action -id  CovDetail.1 -list {tglDetail} {alloc_vpn[26:20]}
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[7].x_mb_entry}  tb_top   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top  -column {Assert} 
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top  -column {Assert} 
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top  -column {Branch} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top  tb_top.u_dut   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut  -column {} 
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb  tb_top.u_dut   }
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut  tb_top.u_dut.x_ct_mmu_sysmap_3   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_3
gui_list_expand -id CoverageTable.1   tb_top.u_dut.x_ct_mmu_sysmap_3
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_3  -column {Condition} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_sysmap_3  tb_top.u_dut.x_ct_mmu_sysmap_3.x_ct_mmu_sysmap_hit_7   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_3.x_ct_mmu_sysmap_hit_7  -column {FSM} 
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_3.x_ct_mmu_sysmap_hit_7  -column {Condition} 
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
gui_src_highlight_item -id CovSrc.1 -lfrom 35 -idxfrom 7 -fileIdFrom 0 -lto 35 -idxto 23 -fileIdTo 0 -selection {sysmap_mmu_hit_x} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 35 -idxfrom 26 -fileIdFrom 0 -lto 35 -idxto 42 -fileIdTo 0 -selection {addr_ge_bottom_x} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 35 -idxfrom 26 -fileIdFrom 0 -lto 35 -idxto 42 -fileIdTo 0 -selection {addr_ge_bottom_x} -selectionId 0 -replace 0
gui_cov_src_double_click -id CovSrc.1 -line 35 -col 34 -insert 0 -file /x2025/GPrj1/IC1/mmu_verification/mmu_verification/../mmu/rtl/ct_mmu_sysmap_hit.v
gui_src_highlight_item -id CovSrc.1 -lfrom 35 -idxfrom 26 -fileIdFrom 0 -lto 35 -idxto 42 -fileIdTo 0 -selection {addr_ge_bottom_x} -selectionId 0 -replace 0
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_5
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_5
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_sysmap_3.x_ct_mmu_sysmap_hit_7  tb_top.u_dut.x_ct_mmu_sysmap_3   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_3  -column {} 
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_3
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_sysmap_3  tb_top.u_dut.x_mmu_l2tlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb
gui_list_expand -id CoverageTable.1   tb_top.u_dut.x_mmu_l2tlb
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb  -column {} 
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb  tb_top.u_dut.x_ct_mmu_regs   }
gui_list_action -id  CoverageTable.1 -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_regs  -column {Toggle} 
gui_src_highlight_item -id CovSrc.1 -lfrom 24 -idxfrom 21 -fileIdFrom 0 -lto 24 -idxto 35 -fileIdTo 0 -selection {cp0_mmu_cskyee} -selectionId 0 -replace 0
gui_src_highlight_item -id CovSrc.1 -lfrom 36 -idxfrom 21 -fileIdFrom 0 -lto 36 -idxto 33 -fileIdTo 0 -selection {mmu_cp0_data} -selectionId 0 -replace 0
gui_cov_src_double_click -id CovSrc.1 -line 36 -col 25 -insert 0 -file /x2025/GPrj1/IC1/mmu_verification/mmu_verification/../mmu/rtl/ct_mmu_regs.v
gui_src_highlight_item -id CovSrc.1 -lfrom 36 -idxfrom 21 -fileIdFrom 0 -lto 36 -idxto 33 -fileIdTo 0 -selection {mmu_cp0_data} -selectionId 0 -replace 0
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_ct_mmu_regs  tb_top.u_dut   }
gui_covtable_show -show  { Asserts } -id  CoverageTable.1  -test  MergedTest
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} Assertion
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} {Cover Property}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} {Cover Sequence}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertInstList} Total
gui_covtable_show -show  { Function Groups } -id  CoverageTable.1  -test  MergedTest
gui_list_sort -id  CoverageTable.1   -list {covtblFGroupsList} -descending  {Group}
gui_list_sort -id  CoverageTable.1   -list {covtblFGroupsList} {Group}
gui_covtable_show -show  { Module List } -id  CoverageTable.1  -test  MergedTest
gui_list_select -id CoverageTable.1 -list covtblModulesList { /axi_if   } -type { Module  }
gui_list_select -id CoverageTable.1 -list covtblModulesList { /axi_if  /ct_mmu_iplru   } -type { Module Module  }
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iplru
gui_list_expand -id CoverageTable.1   /ct_mmu_iplru
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /ct_mmu_iplru  -type {Module}  -column {} 
gui_list_select -id CoverageTable.1 -list covtblModulesList { /ct_mmu_iplru  /ct_mmu_iutlb_entry   } -type { Module Module  }
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iutlb_entry
gui_list_expand -id CoverageTable.1   /ct_mmu_iutlb_entry
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /ct_mmu_iutlb_entry  -type {Module}  -column {} 
gui_list_collapse -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_iutlb_entry
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_l2tlb_rrpv_array
gui_list_select -id CoverageTable.1 -list covtblModulesList { /ct_mmu_iutlb_entry  /ct_mmu_l2tlb_rrpv_array/tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_rrpv_array   } -type { Module Scope  }
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /ct_mmu_l2tlb_rrpv_array/tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_rrpv_array  -type {Scope}  -column {} 
gui_list_select -id CoverageTable.1 -list covtblModulesList { /ct_mmu_l2tlb_rrpv_array/tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_rrpv_array  /ct_mmu_l2tlb_data_array   } -type { Scope Module  }
gui_list_expand -id  CoverageTable.1   -list {covtblModulesList} /ct_mmu_l2tlb_data_array
gui_list_expand -id CoverageTable.1   /ct_mmu_l2tlb_data_array
gui_list_action -id  CoverageTable.1 -list {covtblModulesList} /ct_mmu_l2tlb_data_array  -type {Module}  -column {} 
gui_covtable_show -show  { Tests } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Statistics } -id  CoverageTable.1  -test  MergedTest
gui_list_expand -id  CoverageTable.1   -list {covtblStatModuleList} Assert
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} Assertion
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} {Cover Property}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} {Cover Sequence}
gui_list_expand -id  CoverageTable.1   -list {covtblStatAssertDefList} Total
gui_covtable_show -show  { Module List } -id  CoverageTable.1  -test  MergedTest
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1  -test  MergedTest
verdiDockWidgetSetCurTab -dock widgetDock_<ExclMgr>
verdiDockWidgetSetCurTab -dock widgetDock_Message
verdiDockWidgetSetCurTab -dock widgetDock_<ExclMgr>
verdiDockWidgetSetCurTab -dock widgetDock_Message
