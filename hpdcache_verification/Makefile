## ----------------------------------------------------------------------------
## VCS + Verdi Makefile for HPDcache Verification (cleaned/fixed)
## ----------------------------------------------------------------------------

#===============================================================================
# Project Directories
#===============================================================================
PROJECT_DIR     ?= $(shell pwd)
HPDCACHE_DIR    ?= $(PROJECT_DIR)/modules/hpdcache
CV_DV_UTILS_DIR ?= $(PROJECT_DIR)/modules/dv_utils/lib/cv_dv_utils
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
CONFIG          ?= CONFIG1_HPC
TOP_MODULE      ?= top
TIMESCALE       ?= 1ns/1ps

ifeq ($(CONFIG),CONFIG1_HPC)
  CONFIG_FILE := $(PROJECT_DIR)/modules/hpdcache_params/hpdcache_params_pkg_config1_HPC.sv
else ifeq ($(CONFIG),CONFIG2_HPC)
  CONFIG_FILE := $(PROJECT_DIR)/modules/hpdcache_params/hpdcache_params_pkg_config2_HPC.sv
else ifeq ($(CONFIG),CONFIG3_EMBEDDED)
  CONFIG_FILE := $(PROJECT_DIR)/modules/hpdcache_params/hpdcache_params_pkg_config3_EMBEDDED.sv
else ifeq ($(CONFIG),CONFIG4_EMBEDDED)
  CONFIG_FILE := $(PROJECT_DIR)/modules/hpdcache_params/hpdcache_params_pkg_config4_EMBEDDED.sv
else
  CONFIG_FILE := $(PROJECT_DIR)/modules/hpdcache_params/hpdcache_params_pkg.sv
endif

#===============================================================================
# Test Configuration
#===============================================================================
TEST_NAME       ?= test_hpdcache_multiple_directed_addr
SEED            ?= random
VERBOSITY       ?= UVM_MEDIUM
TIMEOUT         ?= 10000000
PLUS_ARGS       ?=

#===============================================================================
# Include and Source Files
#===============================================================================
INCDIR          := +incdir+$(HPDCACHE_DIR)/rtl/include \
                   +incdir+$(PROJECT_DIR)/testbench/common \
                   +incdir+$(PROJECT_DIR)/testbench/env \
                   +incdir+$(PROJECT_DIR)/testbench/hpdcache_agent \
                   +incdir+$(PROJECT_DIR)/testbench/conf_and_perf_agent \
                   +incdir+$(PROJECT_DIR)/testbench/dram_mon \
                   +incdir+$(PROJECT_DIR)/testbench/hwpf_stride_cfg \
                   +incdir+$(PROJECT_DIR)/testbench/test \
                   +incdir+$(PROJECT_DIR)/testbench/top

RTL_FLIST       := -F $(HPDCACHE_DIR)/rtl/hpdcache.Flist
TB_FLIST        := -F $(PROJECT_DIR)/testbench/Files.f
DV_UTILS_FLIST  := -F $(CV_DV_UTILS_DIR)/uvm/Files.f

SRAM_BEHAV      := $(HPDCACHE_DIR)/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv \
                   $(HPDCACHE_DIR)/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv \
                   $(HPDCACHE_DIR)/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv

TOP_FILE        := $(PROJECT_DIR)/testbench/top/top_axi2mem.sv
TYPEDEF_INCL    := $(HPDCACHE_DIR)/rtl/include/hpdcache_typedef.svh

#===============================================================================
# Compile / Elab Options
#===============================================================================
COMMON_DEFINES  := +define+$(CONFIG) +define+AXI2MEM

# ????
# - ??? -work $(WORK_DIR)?VCS ??????
# - ???? -top
# - ?? cfgdb trace ????
# - ?? fsdb/kdb/debug
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
# Utility
#===============================================================================
DETECTED_TESTS_CMD = grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test 2>/dev/null | \
                     sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u

define CHECK_TEST_NAME
	@if ! ($(DETECTED_TESTS_CMD) | grep -x "$(TEST_NAME)" >/dev/null 2>&1); then \
		echo "ERROR: TEST_NAME='$(TEST_NAME)' is not a registered UVM test."; \
		echo ""; \
		echo "Valid tests detected:"; \
		($(DETECTED_TESTS_CMD) | sed 's/^/  - /') || true; \
		exit 2; \
	fi
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
	@echo "make comp / run / verdi / clean / list_tests"
	@echo "Example: make comp run TEST_NAME=test_hpdcache_multiple_directed_addr"

#===============================================================================
# Env / Setup
#===============================================================================
env:
	@echo "PROJECT_DIR=$(PROJECT_DIR)"
	@echo "HPDCACHE_DIR=$(HPDCACHE_DIR)"
	@echo "CV_DV_UTILS_DIR=$(CV_DV_UTILS_DIR)"
	@echo "OUTPUT_DIR=$(OUTPUT_DIR)"
	@echo "LOG_DIR=$(LOG_DIR)"
	@echo "WAVE_DIR=$(WAVE_DIR)"
	@echo "CONFIG=$(CONFIG)"
	@echo "TEST_NAME=$(TEST_NAME)"

check_env:
	@test -n "$(VCS_HOME)" || (echo "ERROR: VCS_HOME not set"; exit 1)
	@test -d "$(HPDCACHE_DIR)" || (echo "ERROR: HPDCACHE_DIR not found"; exit 1)
	@test -d "$(CV_DV_UTILS_DIR)" || (echo "ERROR: CV_DV_UTILS_DIR not found"; exit 1)

setup: check_env
	@mkdir -p $(OUTPUT_DIR) $(LOG_DIR) $(WAVE_DIR) $(COV_DIR) $(REGRESS_DIR)

#===============================================================================
# Compile
#===============================================================================
# ????? comp_all??????????/?????
comp: setup comp_all
	@echo "Compilation completed."

comp_all: setup
	@echo "===============================================================================" | tee $(LOG_DIR)/comp_all.log
	@echo "Compiling Design + TB (single vcs invocation)..." | tee -a $(LOG_DIR)/comp_all.log
	@echo "CONFIG=$(CONFIG), TOP=$(TOP_MODULE)" | tee -a $(LOG_DIR)/comp_all.log
	@echo "===============================================================================" | tee -a $(LOG_DIR)/comp_all.log
	$(VCS) $(VCS_ELAB_OPTS) \
		$(INCDIR) \
		$(COMMON_DEFINES) \
		$(CONFIG_FILE) \
		$(TYPEDEF_INCL) \
		$(RTL_FLIST) \
		$(SRAM_BEHAV) \
		$(DV_UTILS_FLIST) \
		$(TB_FLIST) \
		$(TOP_FILE) \
		-top $(TOP_MODULE) \
		$(PERF_OPTS) \
		-l $(LOG_DIR)/comp_all.log
	@echo "Build done: $(OUTPUT_DIR)/simv"

# ???? target???????? comp_all?
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

profile: setup
	$(CHECK_TEST_NAME)
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		-simprofile time \
		-l $(LOG_DIR)/$(TEST_NAME)_profile.log

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
# Regression
#===============================================================================
BASIC_TESTS := test_hpdcache_multiple_directed_addr \
               test_hpdcache_multiple_random_requests \
               test_hpdcache_multiple_load_store_requests

list_tests:
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
	@ls -l $(OUTPUT_DIR)/simv 2>/dev/null || true
	@ls -lt $(LOG_DIR)/*.log 2>/dev/null | head || true
	@ls -lt $(WAVE_DIR)/*.fsdb 2>/dev/null | head || true

info:
	@$(VCS) -ID 2>&1 | head -3 || true
	@$(VERDI) -version 2>&1 || true

print-%:
	@echo $* = $($*)
