## ----------------------------------------------------------------------------
## VCS + Verdi Makefile for MMU UVM Verification
## Based on hpdcache_verification/Makefile (stripped of hpdcache-specific parts)
## Phase 1: dv_utils + tb_top only; DUT added in Phase 2
## ----------------------------------------------------------------------------

#===============================================================================
# Project Directories
#===============================================================================
PROJECT_DIR     ?= $(shell pwd)
MMU_RTL_DIR     ?= $(PROJECT_DIR)/../mmu/rtl
RELATE_RTL_DIR  ?= $(PROJECT_DIR)/../mmu/rtl/relate\ rtl
MMU_PARAMS_DIR  ?= $(PROJECT_DIR)/modules/mmu_params
TB_DIR          ?= $(PROJECT_DIR)/testbench
CORE_V_VERIF    ?= $(PROJECT_DIR)/modules/dv_utils
CV_DV_UTILS_DIR ?= $(CORE_V_VERIF)/lib/cv_dv_utils
OUTPUT_DIR      ?= $(PROJECT_DIR)/output
LOG_DIR         ?= $(OUTPUT_DIR)/logs
WAVE_DIR        ?= $(OUTPUT_DIR)/waves
COV_DIR         ?= $(OUTPUT_DIR)/coverage
REGRESS_DIR     ?= $(OUTPUT_DIR)/regression

#===============================================================================
# Tool Configuration
#===============================================================================
VCS             ?= vcs
VERDI           ?= verdi
URG             ?= urg

#===============================================================================
# UVM Configuration
#===============================================================================
UVM_VERSION     ?= 1.2

#===============================================================================
# Design Configuration
#===============================================================================
TOP_MODULE      ?= tb_top
TIMESCALE       ?= 1ns/1ps

#===============================================================================
# Test Configuration
#===============================================================================
# Phase 1 default: UVM built-in base test (0-cycle exit smoke test)
TEST_NAME       ?= uvm_test_top
SEED            ?= random
VERBOSITY       ?= UVM_MEDIUM
TIMEOUT         ?= 10000000
PLUS_ARGS       ?=

#===============================================================================
# Include and Source Files
#===============================================================================
INCDIR          := +incdir+$(TB_DIR)/common \
                   +incdir+$(TB_DIR)/env \
                   +incdir+$(TB_DIR)/test \
                   +incdir+$(TB_DIR)/top \
                   +incdir+$(TB_DIR)/ifu_agent \
                   +incdir+$(TB_DIR)/lsu_agent \
                   +incdir+$(TB_DIR)/cp0_agent \
                   +incdir+$(TB_DIR)/ptw_mem_agent \
                   +incdir+$(TB_DIR)/pmp_agent \
                   +incdir+$(TB_DIR)/sysmap_cfg_agent \
                   +incdir+$(TB_DIR)/misc_agent \
                   +incdir+$(MMU_PARAMS_DIR) \
                   +incdir+$(CV_DV_UTILS_DIR)/uvm

# Phase 2: RTL + interfaces + packages (all in Files.f)
TB_FLIST        := -F $(TB_DIR)/Files.f

TOP_FILE        := $(TB_DIR)/top/tb_top.sv

#===============================================================================
# Compile / Elab Options
#===============================================================================
VCS_ELAB_OPTS   := -full64 \
                   -sverilog \
                   -timescale=$(TIMESCALE) \
                   -ntb_opts uvm-$(UVM_VERSION) \
                   -lca \
                   -kdb \
                   -debug_access+all \
                   -debug_region+cell+encrypt \
                   +vcs+fsdbon \
                   +UVM_CONFIG_DB_TRACE \
                   +define+MB_WIDTH=8 \
                   -Mdir=$(OUTPUT_DIR)/csrc \
                   -o $(OUTPUT_DIR)/simv

PERF_OPTS       := -j4 -Mupdate

#===============================================================================
# Simulation Options
#===============================================================================
RUN_OPTS        := +UVM_TESTNAME=$(TEST_NAME) \
                   +UVM_VERBOSITY=$(VERBOSITY) \
                   +TIMEOUT=$(TIMEOUT) \
                   $(PLUS_ARGS) \
                   +UVM_CONFIG_DB_TRACE

ifeq ($(SEED),random)
  SEED_OPTS     := +ntb_random_seed_automatic
else
  SEED_OPTS     := +ntb_random_seed=$(SEED)
endif

FSDB_OPTS       := +fsdbfile+$(WAVE_DIR)/$(TEST_NAME).fsdb \
                   +fsdb+autoflush \
                   +fsdb+functions \
                   +fsdb+mda

GUI_OPTS        := -gui=verdi +fsdb+sva_success

#===============================================================================
# Verdi / Coverage
#===============================================================================
VERDI_BASE_OPTS := -nologo -full64 \
                   -ssf $(WAVE_DIR)/$(TEST_NAME).fsdb \
                   -logdir $(LOG_DIR)/verdi

URG_OPTS        := -dir $(COV_DIR)/*.vdb \
                   -format both \
                   -report $(COV_DIR)/urgReport

COV_OPTS        := -cm line+cond+fsm+tgl+branch+assert \
                   -cm_name $(TEST_NAME) \
                   -cm_dir $(COV_DIR)/$(TEST_NAME).vdb \
                   -cm_hier $(PROJECT_DIR)/scripts/cov_hier.cfg

#===============================================================================
# Test Name Check
# NOTE: CHECK_TEST_NAME is disabled in Phase 1 because only uvm_test_top
#       (UVM built-in) is used. Re-enable from Phase 3 onward when
#       project-specific tests are registered via `uvm_component_utils.
#===============================================================================
# DETECTED_TESTS_CMD = grep -Rho "uvm_component_utils([^)]*)" \
#                      $(PROJECT_DIR)/testbench/test 2>/dev/null | \
#                      sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u
#
# define CHECK_TEST_NAME
# 	@if ! ($(DETECTED_TESTS_CMD) | grep -x "$(TEST_NAME)" >/dev/null 2>&1); then \
# 		echo "ERROR: TEST_NAME='$(TEST_NAME)' is not a registered UVM test."; \
# 		exit 2; \
# 	fi
# endef
define CHECK_TEST_NAME
endef

#===============================================================================
# Phony
#===============================================================================
.PHONY: all help setup check_env env comp comp_all comp_rtl comp_tb elab \
        run run_gui run_batch debug profile verdi wave run_cov cov merge_cov \
        clean clean_all clean_wave clean_cov list_tests status info print-%

all: comp run

#===============================================================================
# Help
#===============================================================================
help:
	@echo "Usage:"
	@echo "  make comp                          # Compile + elaborate"
	@echo "  make run TEST_NAME=uvm_test_top    # Run simulation"
	@echo "  make all                           # comp + run"
	@echo "  make verdi TEST_NAME=<test>        # Open Verdi waveform"
	@echo "  make clean                         # Remove build artifacts"
	@echo "  make list_tests                    # List registered UVM tests"
	@echo ""
	@echo "Key variables:"
	@echo "  TEST_NAME=$(TEST_NAME)  SEED=$(SEED)  VERBOSITY=$(VERBOSITY)"

#===============================================================================
# Env / Setup
#===============================================================================
env:
	@echo "PROJECT_DIR      = $(PROJECT_DIR)"
	@echo "MMU_RTL_DIR      = $(MMU_RTL_DIR)"
	@echo "CORE_V_VERIF     = $(CORE_V_VERIF)"
	@echo "CV_DV_UTILS_DIR  = $(CV_DV_UTILS_DIR)"
	@echo "OUTPUT_DIR       = $(OUTPUT_DIR)"
	@echo "TOP_MODULE       = $(TOP_MODULE)"
	@echo "TEST_NAME        = $(TEST_NAME)"

check_env:
	@which vcs >/dev/null 2>&1 || \
	  (echo ""; \
	   echo "ERROR: 'vcs' not found in PATH."; \
	   echo "  bash users: cp setup.local.sh.example setup.local.sh  # set VCS_HOME, then re-source setup_env.sh"; \
	   echo "  csh  users: cp setup.local.csh.example setup.local.csh  # set VCS_HOME, then re-source setup_env.csh"; \
	   echo ""; exit 1)
	@test -d "$(CORE_V_VERIF)" || (echo "ERROR: CORE_V_VERIF not found: $(CORE_V_VERIF)"; exit 1)
	@test -d "$(CV_DV_UTILS_DIR)" || (echo "ERROR: CV_DV_UTILS_DIR not found: $(CV_DV_UTILS_DIR)"; exit 1)

setup:
	@mkdir -p $(OUTPUT_DIR) $(LOG_DIR) $(WAVE_DIR) $(COV_DIR) $(REGRESS_DIR)

#===============================================================================
# Compile
#===============================================================================
comp: setup comp_all
	@echo "Compilation completed."

comp_all: setup
	@echo "==============================================================================="
	@echo "Compiling MMU UVM TB (Phase 2: DUT + interfaces + packages)..."
	@echo "TOP_MODULE=$(TOP_MODULE)  UVM_VERSION=$(UVM_VERSION)"
	@echo "MMU_RTL_DIR=$(MMU_RTL_DIR)"
	@echo "RELATE_RTL_DIR=$(RELATE_RTL_DIR)"
	@echo "==============================================================================="
	CORE_V_VERIF=$(CORE_V_VERIF) \
	MMU_RTL_DIR=$(MMU_RTL_DIR) \
	RELATE_RTL_DIR="$(RELATE_RTL_DIR)" \
	MMU_PARAMS_DIR=$(MMU_PARAMS_DIR) \
	TB_DIR=$(TB_DIR) \
	CV_DV_UTILS_DIR=$(CV_DV_UTILS_DIR) \
	$(VCS) $(VCS_ELAB_OPTS) \
		$(INCDIR) \
		$(TB_FLIST) \
		$(TOP_FILE) \
		-top $(TOP_MODULE) \
		$(PERF_OPTS) \
		-l $(LOG_DIR)/comp_all.log
	@echo "Build done: $(OUTPUT_DIR)/simv"

comp_rtl: comp_all
comp_tb:  comp_all

elab:
	@echo "simv is generated by comp_all (compile+elab in one step)."

#===============================================================================
# Run
#===============================================================================
run: setup
	$(CHECK_TEST_NAME)
	@echo "Running $(TEST_NAME), seed=$(SEED)"
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		$(FSDB_OPTS) \
		-l $(LOG_DIR)/$(TEST_NAME)_$(SEED).log
	@echo "Simulation completed. Log: $(LOG_DIR)/$(TEST_NAME)_$(SEED).log"

run_gui: setup
	$(CHECK_TEST_NAME)
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		$(FSDB_OPTS) \
		$(GUI_OPTS) \
		-l $(LOG_DIR)/$(TEST_NAME)_gui.log

run_batch: setup
	$(CHECK_TEST_NAME)
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		-l $(LOG_DIR)/$(TEST_NAME)_batch.log

run_cov: setup
	$(CHECK_TEST_NAME)
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		$(COV_OPTS) \
		-l $(LOG_DIR)/$(TEST_NAME)_cov.log

debug: setup
	$(CHECK_TEST_NAME)
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		$(FSDB_OPTS) \
		+UVM_VERBOSITY=UVM_DEBUG \
		-l $(LOG_DIR)/$(TEST_NAME)_debug.log

#===============================================================================
# Wave
#===============================================================================
verdi:
	@if [ ! -f "$(WAVE_DIR)/$(TEST_NAME).fsdb" ]; then \
		echo "ERROR: FSDB not found: $(WAVE_DIR)/$(TEST_NAME).fsdb"; \
		exit 2; \
	fi
	@if [ -f "$(WAVE_DIR)/signal.rc" ]; then \
		$(VERDI) $(VERDI_BASE_OPTS) -sswr $(WAVE_DIR)/signal.rc & \
	else \
		$(VERDI) $(VERDI_BASE_OPTS) & \
	fi

wave: verdi

#===============================================================================
# Coverage
#===============================================================================
cov:
	$(URG) $(URG_OPTS)

merge_cov:
	$(URG) -dir $(COV_DIR)/*.vdb -dbname $(COV_DIR)/merged.vdb -report $(COV_DIR)/merged_report

#===============================================================================
# Test List
#===============================================================================
DETECTED_TESTS_CMD = grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test 2>/dev/null | \
                     sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u

list_tests:
	@echo "Registered UVM tests:"
	@($(DETECTED_TESTS_CMD) | sed 's/^/  - /') || true

#===============================================================================
# Clean
#===============================================================================
clean:
	rm -rf $(OUTPUT_DIR)/simv* \
	       $(OUTPUT_DIR)/csrc \
	       $(OUTPUT_DIR)/*.daidir \
	       $(LOG_DIR)/*.log \
	       AN.DB DVEfiles ucli.key vc_hdrs.h .vlogansetup* novas* verdiLog

clean_wave:
	rm -rf $(WAVE_DIR)/*.fsdb $(WAVE_DIR)/*.vpd $(WAVE_DIR)/*.rc

clean_cov:
	rm -rf $(COV_DIR)/*.vdb $(COV_DIR)/urgReport $(COV_DIR)/merged*

clean_all: clean clean_wave clean_cov
	rm -rf $(OUTPUT_DIR) $(REGRESS_DIR)

#===============================================================================
# Utils
#===============================================================================
status:
	@ls -l $(OUTPUT_DIR)/simv 2>/dev/null || echo "simv not built yet"
	@ls -lt $(LOG_DIR)/*.log 2>/dev/null | head || true
	@ls -lt $(WAVE_DIR)/*.fsdb 2>/dev/null | head || true

info:
	@$(VCS) -ID 2>&1 | head -3 || true
	@$(VERDI) -version 2>&1 || true

print-%:
	@echo "$* = $($*)"
