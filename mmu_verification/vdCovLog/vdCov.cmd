verdiWindowResize -win $_vdCoverage_1 "0" "27" "1707" "893"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
gui_open_cov  -hier /x2025/GPrj1/IC2/mmu_verification/mmu_verification/output/simv.vdb -testdir {} -test {} -merge MergedTest -db_max_tests 10 -fsm transition
gui_covtable_show -show  { Module List } -id  CoverageTable.1
gui_covtable_show -show  { Design Hierarchy } -id  CoverageTable.1
verdiDockWidgetSetCurTab -dock widgetDock_<ExclMgr>
verdiDockWidgetSetCurTab -dock widgetDock_Message
verdiDockWidgetSetCurTab -dock widgetDock_<Hvp>
verdiDockWidgetSetCurTab -dock widgetDock_<CovSrc.1>
gui_list_sort -id  CoverageTable.1   -list {covtblInstancesList} -descending  {Name}
gui_covtable_show -show  { Module List } -id  CoverageTable.1
gui_covtable_show -show  { Function Groups } -id  CoverageTable.1
gui_covtable_show -show  { Asserts } -id  CoverageTable.1
gui_covtable_show -show  { Statistics } -id  CoverageTable.1
gui_covtable_show -show  { Asserts } -id  CoverageTable.1
gui_covtable_show -show  { Statistics } -id  CoverageTable.1
gui_covtable_show -show  { Tests } -id  CoverageTable.1
gui_covtable_show -show  { Function Groups } -id  CoverageTable.1
gui_group_mode  -instance
gui_column_config -id  CoverageTable.1  -list  topo_covtblFGroupsList  -col  Instances  -show 
gui_column_config -id  CoverageTable.1  -list  topo_covtblFGroupsList  -col  Definition  -on   -show 
gui_group_filter_ccex -off
gui_group_mode  -definition
gui_column_config -id  CoverageTable.1  -list  topo_covtblFGroupsList  -col  Instances  -on   -show 
gui_column_config -id  CoverageTable.1  -list  topo_covtblFGroupsList  -col  Definition  -show 
gui_group_filter_ccex -off
gui_set_pref_value -category {ColumnCfg} -key {topo_covtblFGroupsList_V1.1_Group_pos} -value {4}
gui_set_pref_value -category {ColumnCfg} -key {topo_covtblFGroupsList_V1.1_Group_width} -value {200}
gui_set_pref_value -category {ColumnCfg} -key {topo_covtblFGroupsList_V1.1_Group} -value {true}
vdCovExit -noprompt
