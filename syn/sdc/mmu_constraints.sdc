#===========================================================================
# MMU Timing Constraints
# Target: ASAP7 7nm, 1 GHz (period 1000 ps)
# Note: Yosys abc does not read SDC directly. This file is for downstream
# STA tools (e.g., OpenSTA). To constrain abc, use the -D <ps> flag.
#===========================================================================

# Clock definition
create_clock -name forever_cpuclk -period 1.000 [get_ports forever_cpuclk]

# Input delay (30% of clock period)
set_input_delay  -clock forever_cpuclk  0.300  [all_inputs]
# Exclude clock and reset from input delay
set_input_delay  -clock forever_cpuclk  0.000  [get_ports forever_cpuclk]
set_input_delay  -clock forever_cpuclk  0.000  [get_ports cpurst_b]
set_input_delay  -clock forever_cpuclk  0.000  [get_ports pad_yy_icg_scan_en]

# Output delay (30% of clock period)
set_output_delay -clock forever_cpuclk  0.300  [all_outputs]

# Clock uncertainty (jitter + skew margin)
set_clock_uncertainty  0.050  [get_clocks forever_cpuclk]

# Asynchronous reset -- false path
set_false_path -from [get_ports cpurst_b]

# Scan enable is static during functional mode
set_case_analysis 0 [get_ports pad_yy_icg_scan_en]
