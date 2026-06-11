verdiWindowResize -win $_vdCoverage_1 "0" "20" "1707" "893"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier /x2025/GPrj1/IC2/mmu_verification/mmu_verification/output/simv.vdb -testdir {} -test {} -merge MergedTest -db_max_tests 10 -fsm transition
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} { }
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} {Name}
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} { }
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} {Score}
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} {Name}
gui_covtable_show -id  CoverageTable.1  -cumulative  0
gui_covtable_show -id  CoverageTable.1  -cumulative  0
gui_column_config -id  CoverageTable.1  -list  covtblInstancesList  -show 
verdiDockWidgetSetCurTab -dock widgetDock_<ExclMgr>
verdiDockWidgetSetCurTab -dock widgetDock_Message
vdCovExit -noprompt
