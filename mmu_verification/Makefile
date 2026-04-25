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
RELATE_RTL_DIR  ?= $(PROJECT_DIR)/../mmu/rtl/relate_rtl
RELATE_RTL_REAL ?= $(PROJECT_DIR)/../mmu/rtl/relate rtl
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
TEST_NAME       ?= mmu_base_test
SEED            ?= random
VERBOSITY       ?= UVM_MEDIUM
TIMEOUT         ?= 10000000
# 1 = quiet console: only UVM_ERROR / UVM_FATAL (+UVM_ERR_ONLY, see test_base.svh)
UVM_ERR_ONLY    ?= 0
PLUS_ARGS       ?=

ifeq ($(UVM_ERR_ONLY),1)
  ERR_ONLY_OPTS := +UVM_ERR_ONLY
else
  ERR_ONLY_OPTS :=
endif

#===============================================================================
# Phase 5 sign-off (doc/MMU_UVM_TaskDivision.md §5 exit criteria)
#   - #2: IFU  multi-seed  → 5 fixed seeds, same end-to-end test
#   - #3: LSU p0/p1/p2/stamo ≥20 each → covered by that test
#   - #4: miss→PTW→refill 3 seeds   → 3 additional seeds, same test
#   - #5..8: UVM 0/0 in logs; optional scan_logs | optional Phase 4 PTW
#  Override: make phase5 PHASE5_SEEDS5="1 2 3 4 5" PHASE5_SEEDS3="6 7 8"
#===============================================================================
PHASE5_TEST      ?= test_mmu_translation_sanity
# five seeds: criterion #2 (×100 IFU) + #3 (LSU) per TaskDivision
PHASE5_SEEDS5    ?= 10001 10002 10003 10004 10005
# three seeds:  criterion #4 (miss/PTW/refill mix, same testbench scenario)
PHASE5_SEEDS3    ?= 20101 20102 20103
PHASE4_PTW_TEST  ?= test_ptw_map4k_directed
PHASE5_LOGS      := $(foreach s,$(PHASE5_SEEDS5) $(PHASE5_SEEDS3),$(LOG_DIR)/$(PHASE5_TEST)_$(s).log)
PERL             ?= perl

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
                   +define+PA_WIDTH=40 \
                   +define+MMU_EXPT_TRACE_ONCE_EN \
                   -Mdir=$(OUTPUT_DIR)/csrc \
                   -o $(OUTPUT_DIR)/simv

PERF_OPTS       := -j4 -Mupdate

#===============================================================================
# Fast compile: drop debug/KDB/FSDB for 3-5x speedup (no wave support)
#===============================================================================
VCS_FAST_OPTS   := -full64 \
                   -sverilog \
                   -timescale=$(TIMESCALE) \
                   -ntb_opts uvm-$(UVM_VERSION) \
                   -lca \
                   +define+PA_WIDTH=40 \
                   +define+MMU_EXPT_TRACE_ONCE_EN \
                   -Mdir=$(OUTPUT_DIR)/csrc \
                   -o $(OUTPUT_DIR)/simv

#===============================================================================
# Simulation Options
#===============================================================================
RUN_OPTS        := +UVM_TESTNAME=$(TEST_NAME) \
                   +UVM_VERBOSITY=$(VERBOSITY) \
                   +TIMEOUT=$(TIMEOUT) \
                   $(ERR_ONLY_OPTS) \
                   $(PLUS_ARGS)

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
        clean clean_all clean_wave clean_cov list_tests status info print-% \
        phase5 phase5_fast phase5_run_5seed phase5_run_3seed phase5_check \
        phase5_scan_logs phase5_ptw4k print-phase5

all: comp run

# Fast: compile without debug + run without FSDB/waves (fastest iteration loop)
fast: comp_fast run_batch

#===============================================================================
# Phase 5 regression (MMU_UVM_TaskDivision.md §5 — 一次签核)
#  phase5: comp + 5 seeds + 3 seeds + UVM ERROR/FATAL 报告检查
#  phase5_fast: 同上但 comp_fast（开发迭代，签核可改用 phase5 全量 comp）
#===============================================================================
print-phase5:
	@echo "PHASE5_TEST    = $(PHASE5_TEST)"
	@echo "PHASE5_SEEDS5  = $(PHASE5_SEEDS5)"
	@echo "PHASE5_SEEDS3  = $(PHASE5_SEEDS3)"
	@echo "PHASE5_LOGS     = (8 files) $(LOG_DIR)/$(PHASE5_TEST)_<seed>.log"

phase5_run_5seed:
	@set -e; for s in $(PHASE5_SEEDS5); do \
		echo "=== $(PHASE5_TEST)  SEED=$$s  (5-seed tranche) ==="; \
		$(MAKE) run TEST_NAME=$(PHASE5_TEST) SEED=$$s; \
	done

phase5_run_3seed:
	@set -e; for s in $(PHASE5_SEEDS3); do \
		echo "=== $(PHASE5_TEST)  SEED=$$s  (3-seed tranche) ==="; \
		$(MAKE) run TEST_NAME=$(PHASE5_TEST) SEED=$$s; \
	done

# TaskDivision #5-8: 在报告摘要中须为 UVM_ERROR:0, UVM_FATAL:0
phase5_check:
	@set -e; for f in $(PHASE5_LOGS); do \
		test -f "$$f" || (echo "Missing log: $$f  (run phase5_run_5seed phase5_run_3seed first)"; exit 1); \
		grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — UVM_ERROR is not 0"; exit 1); \
		grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — UVM_FATAL is not 0"; exit 1); \
	done
	@echo "phase5_check: UVM report summary — ERROR=0 and FATAL=0 in all 8 $(PHASE5_TEST) seed logs"

# Optional: scripts/scan_logs.pl (stricter, may count warnings — use waivers if needed)
phase5_scan_logs:
	@test -f $(PROJECT_DIR)/scripts/scan_logs.pl || (echo "No scripts/scan_logs.pl"; exit 1)
	@set -e; for f in $(PHASE5_LOGS); do test -f "$$f" || (echo "Missing: $$f"; exit 1); done
	$(PERL) $(PROJECT_DIR)/scripts/scan_logs.pl $(PHASE5_LOGS)

# Optional: Phase 4 reference PTW/页表 定向（与 Phase 5 端到端互补）
phase5_ptw4k:
	$(MAKE) run TEST_NAME=$(PHASE4_PTW_TEST) SEED=30001

# Full gate: full compile + 8 sims + UVM 0/0 检查
phase5: comp phase5_run_5seed phase5_run_3seed phase5_check
	@echo "=== phase5 finished OK (comp + 5+3 seeds + UVM 0/0) ==="
	@echo "     Optional: make phase5_scan_logs   |   make phase5_ptw4k"

# Same, but comp_fast
phase5_fast: comp_fast phase5_run_5seed phase5_run_3seed phase5_check
	@echo "=== phase5_fast finished OK (comp_fast + 5+3 seeds + UVM 0/0) ==="

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
	@echo "  UVM_ERR_ONLY=$(UVM_ERR_ONLY)  (1=errors only on console)"
	@echo "  Example: make run TEST_NAME=... UVM_ERR_ONLY=1"
	@echo "  PLUS_ARGS: e.g. PLUS_ARGS=+MMU_LSU_MON_DBG  (P1 RSP bus snapshot, lsu_monitor.svh)"
	@echo ""
	@echo "Phase 5 (MMU_UVM_TaskDivision.md §5):"
	@echo "  make print-phase5              # show PHASE5_TEST / default seeds / log path pattern"
	@echo "  make phase5_fast               # comp_fast + 5+3 SEEDs + UVM 0/0 检查（日常）"
	@echo "  make phase5                    # comp + 5+3 SEEDs + UVM 0/0 检查（签核/CI）"
	@echo "  make phase5_run_5seed         # 仅 5 个 SEED 回归（需已有 simv）"
	@echo "  make phase5_run_3seed         # 仅 3 个 SEED 回归"
	@echo "  make phase5_check             # 仅检查 8 个 log 中 UVM_ERROR/FATAL=0"
	@echo "  make phase5_scan_logs         # 可选：scan_logs.pl 扫 8 个 log"
	@echo "  make phase5_ptw4k             # 可选：test_ptw_map4k_directed 定向一条"
	@echo "  覆盖: PHASE5_TEST=test_mmu_translation_sanity  PHASE5_SEEDS5/SEEDS3 可改"

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
	@# Create no-space symlink for 'relate rtl' directory (VCS can't handle spaces in .f paths)
	@ln -sfn "$(RELATE_RTL_REAL)" $(RELATE_RTL_DIR) 2>/dev/null || true

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

comp_fast: setup
	@echo "=== Fast compile (no debug/KDB/FSDB — ~3-5x faster) ==="
	CORE_V_VERIF=$(CORE_V_VERIF) \
	MMU_RTL_DIR=$(MMU_RTL_DIR) \
	RELATE_RTL_DIR="$(RELATE_RTL_DIR)" \
	MMU_PARAMS_DIR=$(MMU_PARAMS_DIR) \
	TB_DIR=$(TB_DIR) \
	CV_DV_UTILS_DIR=$(CV_DV_UTILS_DIR) \
	$(VCS) $(VCS_FAST_OPTS) \
		$(INCDIR) \
		$(TB_FLIST) \
		$(TOP_FILE) \
		-top $(TOP_MODULE) \
		$(PERF_OPTS) \
		-l $(LOG_DIR)/comp_fast.log
	@echo "Fast build done: $(OUTPUT_DIR)/simv"

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
