#=============================================================================
# Library preparation : ASAP7 RVT/TT .lib + LEF  ->  NDM library
#=============================================================================
set PDK_DIR  "/home/IC1/tools/asap7/asap7sc7p5t_28"
set NLDM_DIR "$PDK_DIR/LIB/NLDM"
set LEF_DIR   "$PDK_DIR/LEF"
set TECH_LEF  "$PDK_DIR/techlef_misc/asap7_tech_1x_201209.lef"
set OUT_DIR   "/x2025/GPrj1/IC1/mmu_verification/syn/fc/lib_prep"

set CELL_LEFS [list "$LEF_DIR/asap7sc7p5t_28_R_1x_220121a.lef"]

set LIBS [list \
    $NLDM_DIR/asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib \
    $NLDM_DIR/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib \
    $NLDM_DIR/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib    \
    $NLDM_DIR/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib     \
    $NLDM_DIR/asap7sc7p5t_OA_RVT_TT_nldm_211120.lib     \
]

# 1. create empty workspace (NO -technology; tech comes from the tech LEF)
create_workspace asap7_rvt_tt

# 2. read LEFs: tech + cell physical. tech LEF establishes routing layers/sites
if {[catch {read_lef [concat $TECH_LEF $CELL_LEFS]} lefmsg]} {
    echo "ERROR read_lef: $lefmsg"
} else {
    echo "read_lef OK"
}

# 3. read timing (.lib)
if {[catch {read_lib $LIBS} libmsg]} {
    echo "ERROR read_lib: $libmsg"
} else {
    echo "read_lib OK"
}

# 4. check + commit -> NDM
check_workspace
commit_workspace -force -output $OUT_DIR/asap7_rvt_tt.ndm

echo "============================================================"
echo " NDM written to: $OUT_DIR/asap7_rvt_tt.ndm"
echo "============================================================"
quit
