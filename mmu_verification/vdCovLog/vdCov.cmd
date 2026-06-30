verdiWindowResize -win $_vdCoverage_1 "0" "27" "1920" "906"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier /x2025/GPrj1/IC1/mmu_verification/mmu_verification/output/coverage/phase14_merged.vdb -testdir {} -test {/x2025/GPrj1/IC1/mmu_verification/mmu_verification/output/coverage/phase14_merged/test} -merge MergedTest -db_max_tests 10 -fsm transition
gui_set_pref_value -category {ColumnCfg} -key {covtblAssertList_Match} -value {false}
gui_set_pref_value -category {ColumnCfg} -key {covtblAssertList_Success} -value {false}
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb   }
gui_copy_selected  -id  CoverageTable.1 
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.u_mmu_l1dtlb  {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[0].x_mb_entry}
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[1].x_mb_entry}
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l1itlb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[3].x_mb_entry}  tb_top.u_dut.x_mmu_l1itlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l1itlb.x_ct_mmu_iplru
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l1itlb.x_ct_mmu_iplru
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l1itlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_arb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_data_array
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_data_array
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_mb
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_mb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_rrpv_wbuf
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_rrpv_wbuf
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_mb
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb.x_l2tlb_mb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l1itlb  tb_top.u_dut.x_mmu_l2tlb.u_l2tlb_ptw_ooo_sva   }
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_l2tlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_5
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_ct_mmu_sysmap_5
gui_list_collapse -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.x_mmu_arb
gui_list_select -id CoverageTable.1 -list covtblInstancesList { tb_top.u_dut.x_mmu_l2tlb.u_l2tlb_ptw_ooo_sva  tb_top.u_dut.u_mmu_l1dtlb   }
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} tb_top.u_dut.u_mmu_l1dtlb
gui_list_expand -id  CoverageTable.1   -list {covtblInstancesList} {tb_top.u_dut.u_mmu_l1dtlb.gen_mb_entries[2].x_mb_entry}
gui_set_pref_value -category {ColumnCfg} -key {covtblInstancesList_V1.1_Name_width} -value {289}
vdCovExit -noprompt
