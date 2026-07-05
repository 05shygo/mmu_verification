#=============================================================================
# MMU Synthesis : ct_mmu_top -> ASAP7 (asap7sc7p5t_28, RVT/TT, 0.7V)
# Tool          : Synopsys Fusion Compiler (fc_shell) - DC-compatible flow
#=============================================================================

# -------------------------------------------------------------------------
# 0. User-tunable knobs
# -------------------------------------------------------------------------
set ::CLK_PERIOD_NS     1.4       ;# 714 MHz target (realistic for ASAP7 RVT 0.7V)
set ::TOP               ct_mmu_top
set ::USE_SRAM_BLACKBOX 0         ;# 1 = SRAMs as hard IP (fast); 0 = synth to FFs
set ::COMPILE_EFFORT    "ultra"   ;# ultra | medium | high
set ::FC_DIR            /x2025/GPrj1/IC1/mmu_verification/syn/fc
set ::RPT_DIR           $::FC_DIR/reports
set ::RES_DIR           $::FC_DIR/results
set ::LOG_DIR           $::FC_DIR/logs

foreach d [list $::RPT_DIR $::RES_DIR $::LOG_DIR] { file mkdir $d }

# -------------------------------------------------------------------------
# 1. Library setup (fc_shell launched with -no_init, so load explicitly)
# -------------------------------------------------------------------------
source $::FC_DIR/.synopsys_fc.setup

# -------------------------------------------------------------------------
# 2. Timestamp banner
# -------------------------------------------------------------------------
redirect -tee -file $::LOG_DIR/compile.log {
    echo "============================================================"
    echo " MMU synthesis: $::TOP  (ASAP7 7nm RVT/TT)"
    echo " Clock target : $::CLK_PERIOD_NS ns  ([expr {1000.0/$::CLK_PERIOD_NS}] MHz)"
    echo " SRAM mode    : [expr {$::USE_SRAM_BLACKBOX ? "blackbox(hard IP)" : "behavioral(->FF)"}]"
    echo " Effort       : $::COMPILE_EFFORT"
    echo " Start        : [exec date]"
    echo "============================================================"
}

echo "target_library = [llength $target_library] libs"
echo "link_library   = [llength $link_library] entries"

# -------------------------------------------------------------------------
# 3. Read RTL
#    Notes:
#      - SV files use 'logic', packed arrays -> use sverilog format.
#      - Preprocessed syn_*.sv files replace their original counterparts
#        (they flatten packed structs so the same flow as the Yosys run).
#      - MMU_EXPT_TRACE_ONCE_EN is a real `ifdef macro -> must define it.
#      - PA_WIDTH is a `define used by ct_mmu_sysmap.v (ADDR_WIDTH = `PA_WIDTH-12).
# -------------------------------------------------------------------------
set rtl_root /x2025/GPrj1/IC1/mmu_verification/mmu/rtl
set syn_src  /x2025/GPrj1/IC1/mmu_verification/syn/scripts

# 3a. plain Verilog sources (analyze first, then we elaborate top)
# NOTE: use ORIGINAL RTL (FC/Presto has full SV support) -- the syn_*.sv
#       preprocessed copies were divergent (added port connections that the
#       original submodules don't declare).  Only mmu_l2tlb_rrpv_wbuf needs
#       the flattened copy because of a Presto slice-of-slice limitation.
define_name_rules simple_names -allowed "a-z A-Z 0-9 _" -first_restricted "_"
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
]

# 3b. SRAM wrappers + leaf memory models
analyze -format sverilog [list \
    $rtl_root/ct_spsram_256x196.v \
    $rtl_root/ct_spsram_256x84.v \
    $rtl_root/ct_spram_wrapper.sv \
]
if {$::USE_SRAM_BLACKBOX} {
    # Treat SRAMs as hard IP (fast, ASIC-correct)
    analyze -format sverilog $::FC_DIR/scripts/sram_blackboxes.v
    # Mark the empty stubs as blackboxes (Tcl-level; the '// synopsys' pragma
    # trips Presto VER-294, and unmarked empty modules give LNK-094).
    foreach pat {ct_f_spsram_256x196 ct_f_spsram_256x84 mmu_fpga_ram} {
        set cc [get_lib_cells -quiet "WORK/${pat}*"]
        if {[llength $cc] > 0} {
            set_attribute -name is_black_box -value true -objects $cc
        }
    }
    echo "INFO: SRAM leaves blackboxed -> ct_f_spsram_256x196/84, mmu_fpga_ram"
} else {
    # Synthesize behavioral SRAM models (large FF arrays, slow)
    analyze -format sverilog [list \
        $syn_src/syn_mmu_fpga_ram.sv \
        $syn_src/ct_f_spsram_behav.v \
    ]
    echo "INFO: SRAM leaves will be synthesized -> FF arrays"
}

# 3c. Top-level
analyze -format sverilog $rtl_root/ct_mmu_top.v

# -------------------------------------------------------------------------
# 4. Elaborate + promote top module
#    (FC uses set_top_module instead of the legacy DC 'link' command.)
# -------------------------------------------------------------------------
elaborate $::TOP
set_top_module $::TOP
current_design $::TOP

# Mark SRAM hard-macro instances dont_touch so compile leaves them alone.
# Guard with -quiet + size check so an empty collection is not fatal.
if {$::USE_SRAM_BLACKBOX} {
    set _dt [get_cells -hier -quiet -filter "ref_name =~ ct_f_spsram_* || ref_name =~ mmu_fpga_ram"]
    if {[sizeof_collection $_dt] > 0} {
        set_dont_touch $_dt
        echo "INFO: set_dont_touch on [sizeof_collection $_dt] SRAM macro cells"
    } else {
        echo "WARN: no SRAM macro cells found to lock (ok if behavioral)"
    }
}

# -------------------------------------------------------------------------
# 5. Constraints
# -------------------------------------------------------------------------
# Clock-gating setup (auto ICG insertion on eligible enables).
# FC uses set_app_option; the DC-style set_clock_gating_style does not exist.
if {[catch {set_app_option -name clock_gate.clock_gating_integrated_cell \
                       -value {ICGx1_ASAP7_75t_R*}} cgerr]} {
    echo "WARN: clock_gate app_option not set ($cgerr) -- using defaults"
}
if {[catch {set_app_option -name clock_gate.clock_gating_style -value integrated} e2]} {}
if {[catch {set_app_option -name clock_gate.clock_gating_setup -value 0.2} e3]} {}
if {[catch {set_app_option -name clock_gate.clock_gating_hold  -value 0.1} e4]} {}

source $::FC_DIR/scripts/constraints.sdc

# keep hard macros / SRAMs hierarchical during compile (guard against empty)
set _hm [get_cells -hier -quiet -filter "is_hard_macro == true"]
if {[sizeof_collection $_hm] > 0} {
    set_dont_touch $_hm
}

# -------------------------------------------------------------------------
# 6. Pre-compile reports (non-fatal; wrapped in catch)
# -------------------------------------------------------------------------
if {[catch {redirect -tee -file $::RPT_DIR/pre_compile.check_timing { check_timing }} e1]} {
    echo "WARN: pre-compile check_timing skipped: $e1"
}
if {[catch {redirect -file $::RPT_DIR/pre_compile.report_cell { report_reference }} e2]} {
    echo "WARN: pre-compile report skipped: $e2"
}

# -------------------------------------------------------------------------
# 7. Compile
#    FC's compile_fusion needs a pre-built NDM library (built via Library
#    Manager + lc_shell, which is not installed here).  The DC-compatible
#    'compile' command works directly with .lib target_library and does NOT
#    require NDM technology data -- so we use it.  This delivers a mapped
#    gate-level netlist with full ASAP7 cell timing.
# -------------------------------------------------------------------------
if {$::COMPILE_EFFORT eq "ultra" || $::COMPILE_EFFORT eq "high"} {
    # 'compile' with top-level map effort; -gate_clock inserts ICGs.
    compile -map_effort high -area_effort high -gate_clock
} else {
    compile -map_effort $::COMPILE_EFFORT -area_effort $::COMPILE_EFFORT -gate_clock
}

# -------------------------------------------------------------------------
# 8. Post-compile reports (each wrapped in catch -- one bad report must not
#    abort the write-out of the netlist)
# -------------------------------------------------------------------------
set _reports {
    timing.max      { report_timing -delay max -nworst 10 -max_paths 50 -sort_by slack }
    timing.max.full { report_timing -delay max -nworst 5 -max_paths 20 }
    timing.summary  { report_timing -summary -delay max }
    area            { report_area -hierarchy -nosplit }
    reference       { report_reference }
    power           { report_power -analysis_effort medium }
    qor             { report_qor }
    constraints     { report_constraints -all_violators }
}
foreach {tag cmd} $_reports {
    if {[catch {redirect -file $::RPT_DIR/$tag $cmd} _re]} {
        echo "WARN: report '$tag' skipped: $_re"
    }
}

# -------------------------------------------------------------------------
# 9. Write out netlist + DDC
# -------------------------------------------------------------------------
change_names -rules simple_names -hierarchy
write -format verilog -hierarchy -output $::RES_DIR/${::TOP}_netlist.v
write -format ddc     -hierarchy -output $::RES_DIR/${::TOP}.ddc
write_sdc $::RES_DIR/${::TOP}.sdc

# -------------------------------------------------------------------------
# 10. Summary
# -------------------------------------------------------------------------
redirect -tee -file $::RPT_DIR/final.summary {
    echo "============================================================"
    echo " SYNTHESIS SUMMARY : $::TOP @ ASAP7 RVT/TT"
    echo " Clock period : $::CLK_PERIOD_NS ns"
    echo " Finish       : [exec date]"
    echo "============================================================"
    report_qor
    report_timing -summary -delay max
    report_area -hierarchy
}

echo "============================================================"
echo " DONE.  Results in $::RES_DIR, reports in $::RPT_DIR"
echo "============================================================"
quit
