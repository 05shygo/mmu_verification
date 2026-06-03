#===========================================================================
# Makefile for MMU Synthesis with Yosys 0.20 + ASAP7 PDK
#===========================================================================

# Tools
YOSYS      := /home/IC1/tools/yosys_install/bin/yosys
YOSYS_FLAGS := -q -l syn/logs/yosys.log

# Project paths
SYN_DIR    := /x2025/GPrj1/IC1/mmu_verification/syn
PDK_DIR    := /home/IC1/tools/asap7/asap7sc7p5t_28
LIB_DIR    := $(PDK_DIR)/LIB/NLDM

# Liberty files (RVT, TT corner, NLDM)
LIB_FILES := \
    $(LIB_DIR)/asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib \
    $(LIB_DIR)/asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib \
    $(LIB_DIR)/asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib \
    $(LIB_DIR)/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib \
    $(LIB_DIR)/asap7sc7p5t_OA_RVT_TT_nldm_211120.lib

# Output directories
REPORTS_DIR := $(SYN_DIR)/reports
RESULTS_DIR := $(SYN_DIR)/results
LOGS_DIR    := $(SYN_DIR)/logs

#===========================================================================
# Targets
#===========================================================================

.PHONY: all clean dirs synth reports check

all: dirs synth

# Create output directories
dirs:
	@mkdir -p $(REPORTS_DIR) $(RESULTS_DIR) $(LOGS_DIR)

# Run synthesis
synth: dirs
	@echo "=== Running Yosys synthesis: ct_mmu_top -> ASAP7 RVT TT ==="
	$(YOSYS) $(YOSYS_FLAGS) $(SYN_DIR)/scripts/mmu_synth.ys
	@echo "=== Synthesis complete. Outputs: ==="
	@ls -lh $(RESULTS_DIR)/

# Generate reports from synthesized netlist
reports: dirs
	@echo "=== Generating post-synthesis reports ==="
	$(YOSYS) -q -l $(LOGS_DIR)/yosys_reports.log -p \
		"read_verilog -sv $(RESULTS_DIR)/ct_mmu_top_netlist.v; \
		 read_liberty -lib $(LIB_FILES); \
		 stat -liberty; \
		 stat -width"

# Clean outputs
clean:
	rm -rf $(REPORTS_DIR)/* $(RESULTS_DIR)/* $(LOGS_DIR)/*

# Quick check: verify RTL files and tool availability
check:
	@echo "=== Checking RTL file availability ==="
	@test -f /x2025/GPrj1/IC1/mmu_verification/mmu/rtl/ct_mmu_top.v \
		&& echo "OK: ct_mmu_top.v" || echo "MISSING: ct_mmu_top.v"
	@test -f "/x2025/GPrj1/IC1/mmu_verification/mmu/rtl/relate rtl/clk/gated_clk_cell.v" \
		&& echo "OK: gated_clk_cell.v" || echo "MISSING: gated_clk_cell.v"
	@test -f "/x2025/GPrj1/IC1/mmu_verification/mmu/rtl/relate rtl/rtu/ct_rtu_compare_iid.v" \
		&& echo "OK: ct_rtu_compare_iid.v" || echo "MISSING: ct_rtu_compare_iid.v"
	@test -f $(YOSYS) && echo "OK: yosys" || echo "MISSING: yosys"
	@test -f $(LIB_DIR)/asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib \
		&& echo "OK: ASAP7 NLDM liberty files" || echo "MISSING: ASAP7 liberty files"
	@echo "---"
	@echo "RTL files in mmu/rtl/:" $$(find /x2025/GPrj1/IC1/mmu_verification/mmu/rtl/ -maxdepth 1 -name '*.v' -o -name '*.sv' | wc -l)
	@echo "---"
	$(YOSYS) --version 2>&1 | head -1
