#=============================================================================
# smoke.tcl : RTL read + elaborate + link sanity check (NO compile)
# Goal: verify all source files parse, hierarchy resolves, no undefined
#       references -- before committing to a long compile_ultra run.
#=============================================================================
set ::CLK_PERIOD_NS     1.4
set ::TOP               ct_mmu_top
set ::USE_SRAM_BLACKBOX 1
set ::FC_DIR            /x2025/GPrj1/IC1/mmu_verification/syn/fc
set ::LOG_DIR           $::FC_DIR/logs
file mkdir $::LOG_DIR

# source library setup
source $::FC_DIR/.synopsys_fc.setup

echo "============================================================"
echo " SMOKE TEST : RTL parse + elaborate + link"
echo "============================================================"
set t0 [clock seconds]

set rtl_root /x2025/GPrj1/IC1/mmu_verification/mmu/rtl
set syn_src  /x2025/GPrj1/IC1/mmu_verification/syn/scripts

if {[catch {
    analyze -format sverilog -define MMU_EXPT_TRACE_ONCE_EN -define PA_WIDTH=40 [list \
        $rtl_root/sysmap.h \
        $rtl_root/ct_mmu_dplru.v \
        $rtl_root/ct_mmu_dutlb_entry.v \
        $rtl_root/ct_mmu_dutlb_huge_entry.v \
        $rtl_root/ct_mmu_iplru.v \
        $rtl_root/ct_mmu_iutlb_entry.v \
        $rtl_root/ct_mmu_iutlb_fst_entry.v \
        $rtl_root/ct_mmu_l2tlb_data_array.sv \
        $rtl_root/ct_mmu_l2tlb_rrpv_array.sv \
        $rtl_root/ct_mmu_l2tlb_tag_array.sv \
        $rtl_root/ct_mmu_regs.v \
        $rtl_root/ct_mmu_sysmap_hit.v \
        $rtl_root/ct_mmu_sysmap.v \
        $rtl_root/ct_mmu_tlboper.v \
        $rtl_root/L1PDE_cache.sv \
        $rtl_root/L2PDE_cache.sv \
        $rtl_root/mbuf_entry.sv \
        $rtl_root/mmu_arb.sv \
        $rtl_root/mmu_l1dtlb_allocator.sv \
        $rtl_root/mmu_l1dtlb_expt_cam.sv \
        $rtl_root/mmu_l1dtlb_hit_rd.sv \
        $rtl_root/mmu_l1dtlb_install.sv \
        $rtl_root/mmu_l1dtlb_mb_entry.sv \
        $rtl_root/mmu_l1dtlb_scheduler.sv \
        $rtl_root/mmu_l1dtlb.sv \
        $rtl_root/mmu_l1itlb.sv \
        $rtl_root/mmu_l2tlb_mb_entry.sv \
        $rtl_root/mmu_l2tlb_mb.sv \
        $rtl_root/mmu_l2tlb_replacement_policy.sv \
        $rtl_root/mmu_l2tlb_reqq_entry.sv \
        $rtl_root/mmu_l2tlb_reqq.sv \
        $::FC_DIR/scripts/mmu_l2tlb_rrpv_wbuf_fc.sv \
        $rtl_root/mmu_l2tlb.sv \
        $rtl_root/one_to_four_xbar.sv \
        $rtl_root/PDE_cache.sv \
        $rtl_root/pplru.sv \
        $rtl_root/ptw_mbuf.sv \
        $rtl_root/ptw.sv \
        $rtl_root/twu.sv \
        $rtl_root/relate_rtl/clk/gated_clk_cell.v \
        $rtl_root/relate_rtl/rtu/ct_rtu_compare_iid.v \
        $rtl_root/ct_spsram_256x196.v \
        $rtl_root/ct_spsram_256x84.v \
        $rtl_root/ct_spram_wrapper.sv \
        $::FC_DIR/scripts/sram_blackboxes.v \
        $rtl_root/ct_mmu_top.v \
    ]
} err]} {
    echo "ERROR during analyze: $err"
}

# Mark empty SRAM stubs as blackboxes (Tcl-level, avoids LNK-094)
foreach pat {ct_f_spsram_256x196 ct_f_spsram_256x84 mmu_fpga_ram} {
    set cc [get_lib_cells -quiet "WORK/${pat}*"]
    if {[llength $cc] > 0} {
        set_attribute -name is_black_box -value true -objects $cc
    }
}

echo "(1/3) analyze OK"

if {[catch {elaborate $::TOP} err]} {
    echo "ERROR during elaborate: $err"
}
# verify the top design now exists in the design DB
if {[llength [get_designs -quiet $::TOP]] == 0} {
    echo "******************************************************"
    echo " FATAL: $::TOP not found after elaborate."
    echo "        Search log for 'VER-' / 'Presto analyze failed'."
    echo "******************************************************"
    exit 1
}
echo "(2/3) elaborate OK"

# FC uses set_top_module to promote the elaborated block; DC-style link
# is replaced.  current_design makes it the active design for queries.
set_top_module $::TOP
current_design $::TOP
echo "(3/3) set_top_module OK"

set t1 [clock seconds]
echo "============================================================"
echo " SMOKE TEST PASSED  ([expr {$t1-$t0}] s)"
echo " Design : $::TOP"
echo " Cells  : [llength [get_cells -hier]]"
echo " Nets   : [llength [get_nets -hier]]"
echo " Ports  : [llength [all_inputs]] inputs / [llength [all_outputs]] outputs"
echo " Black-box cells:"
foreach_in_collection c [get_cells -hier -filter "is_hard_macro == true || is_black_box == true"] {
    echo "   [get_object_name $c]  (ref=[get_attribute $c ref_name])"
}
echo "============================================================"
quit
