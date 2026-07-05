#=============================================================================
# SDC constraints for ct_mmu_top (ASAP7 7nm)
# Clock target: 714 MHz (1.4 ns period) -- realistic for ASAP7 0.7V RVT.
# Override CLK_PERIOD_NS in compile.tcl to retarget.
#=============================================================================

# ---- Clock -----------------------------------------------------------------
set CLK_NAME   "forever_cpuclk"
set CLK_PORT   "forever_cpuclk"
set CLK_PERIOD $::CLK_PERIOD_NS

create_clock -name $CLK_NAME -period $CLK_PERIOD [get_ports $CLK_PORT]
set_clock_uncertainty 0.050 [get_clocks $CLK_NAME]
set_clock_latency      0.000 [get_clocks $CLK_NAME]
set_clock_transition   0.050 [get_clocks $CLK_NAME]

# ---- I/O delays (30% of clock period) -------------------------------------
set_input_delay  [expr {$CLK_PERIOD * 0.30}] -clock $CLK_NAME [all_inputs]
set_output_delay [expr {$CLK_PERIOD * 0.30}] -clock $CLK_NAME [all_outputs]

# do not delay the clock / reset / static scan pins
set_input_delay 0.000 -clock $CLK_NAME [get_ports forever_cpuclk]
set_input_delay 0.000 -clock $CLK_NAME [get_ports cpurst_b]
set_input_delay 0.000 -clock $CLK_NAME [get_ports pad_yy_icg_scan_en]
set_input_delay 0.000 -clock $CLK_NAME [get_ports cp0_mmu_icg_en]
set_input_delay 0.000 -clock $CLK_NAME [get_ports biu_mmu_smp_disable]

# ---- Driving / load assumptions (ASAP7 RVT cells) -------------------------
# driving cell: ASAP7 BUFx4 (output pin Y).  Wrapped in catch -- the lib must
# be resolvable from link_library; if not, a default drive is used.
if {[catch {set_driving_cell -lib_cell BUFx4_ASAP7_75t_R -pin Y [all_inputs]} _drvmsg]} {
    echo "WARN: set_driving_cell failed ($_drvmsg); using default drive"
    set_driving_cell 0 [all_inputs]
}
# output load: ~4 FO4 of BUFx4 (~0.0024 pF per input; use 0.01 pF conservative)
set_load 0.01 [all_outputs]

# ---- Reset / static-signal false paths ------------------------------------
set_false_path -from [get_ports cpurst_b]
set_case_analysis 0 [get_ports pad_yy_icg_scan_en]

# ---- Idealize reset (async) -----------------------------------------------
set_ideal_network [get_ports cpurst_b]
