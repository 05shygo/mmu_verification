#=============================================================================
# Makefile : MMU synthesis with Synopsys Fusion Compiler (fc_shell)
#            using ASAP7 7nm PDK (asap7sc7p5t_28, RVT/TT, 0.7V)
#
# Targets:
#   make smoke   - RTL parse/elaborate/link check (~2 min)
#   make quick   - medium-effort compile (~10-15 min)
#   make full    - compile_ultra (~30+ min)   [default]
#   make clean   - remove logs/reports/results
#   make clean_all - also remove generated tcl
#=============================================================================

TOP    := ct_mmu_top
CLK_NS ?= 1.4
FC_DIR := /x2025/GPrj1/IC1/mmu_verification/syn/fc

.PHONY: all smoke quick full clean clean_all help

all: full

help:
	@echo "Targets: smoke | quick | full | clean"
	@echo "Override clock:  make full CLK_NS=1.0"

smoke:
	cd $(FC_DIR) && CLK_NS=$(CLK_NS) ./run_fc.sh smoke

quick:
	cd $(FC_DIR) && CLK_NS=$(CLK_NS) ./run_fc.sh quick

full:
	cd $(FC_DIR) && CLK_NS=$(CLK_NS) ./run_fc.sh full

clean:
	rm -rf $(FC_DIR)/logs/* $(FC_DIR)/reports/* $(FC_DIR)/results/*

clean_all: clean
	rm -f $(FC_DIR)/scripts/compile_quick.tcl
