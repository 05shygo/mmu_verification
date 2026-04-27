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
SIMU_DIR        ?= $(PROJECT_DIR)/simu
CORE_V_VERIF    ?= $(PROJECT_DIR)/modules/dv_utils
CV_DV_UTILS_DIR ?= $(CORE_V_VERIF)/lib/cv_dv_utils
OUTPUT_DIR      ?= $(PROJECT_DIR)/output
LOG_DIR         ?= $(OUTPUT_DIR)/logs
WAVE_DIR        ?= $(OUTPUT_DIR)/waves
COV_DIR         ?= $(OUTPUT_DIR)/coverage
REGRESS_DIR     ?= $(OUTPUT_DIR)/regression

# VCS and any subordinate make in output/csrc must see the same file-list paths
# as this Makefile. Stale csrc with -Mupdate can also produce "cc -o .o" / make [.o] errors
# — if that appears: `make clean` then rebuild, or use PERF_OPTS without -Mupdate.
export PROJECT_DIR MMU_RTL_DIR RELATE_RTL_DIR MMU_PARAMS_DIR TB_DIR
export CORE_V_VERIF CV_DV_UTILS_DIR OUTPUT_DIR

#===============================================================================
# Tool Configuration
#===============================================================================
VCS             ?= vcs
VERDI           ?= verdi
URG             ?= urg
PYTHON          ?= python3

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
LOG_STATUS_MAX_HITS ?= 20
LOG_CHECKER     ?= bash $(PROJECT_DIR)/scripts/check_sim_status.sh

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
# Phase 6 regression (MMU_UVM_TaskDivision.md §6 exit criteria)
#   - SFENCE.VMA 4 modes × 100 txns × 3 seeds
#   - invalidate_sb summary must show mismatch=0 and N_invalidations>0
#===============================================================================
PHASE6_TEST       ?= test_mmu_invalidate_sfence_matrix
PHASE6_SEEDS      ?= 61001 61002 61003
PHASE6_MODES      ?= 0 1 2 3
PHASE6_INV_NUM    ?= 100
PHASE6_LOGS       := $(foreach m,$(PHASE6_MODES),$(foreach s,$(PHASE6_SEEDS),$(LOG_DIR)/$(PHASE6_TEST)_m$(m)_s$(s).log))

# Phase 6 — TaskDivision §6 criterion #4: RTU flush vs cold miss / PTW window
#   test prints [abort_check] per iteration + final summary (status=PASS)
PHASE6_RTU_PTW_TEST   ?= test_mmu_phase6_rtu_flush_ptw
PHASE6_RTU_PTW_SEEDS  ?= 62001 62002 62003
PHASE6_RTU_PTW_LOGS   := $(foreach s,$(PHASE6_RTU_PTW_SEEDS),$(LOG_DIR)/$(PHASE6_RTU_PTW_TEST)_$(s).log)

#===============================================================================
# Include and Source Files
#===============================================================================
# Phase 9 suites are included from test_pkg.sv using directory-qualified paths,
# but each suite pulls in leaf tests via bare filenames. VCS resolves those
# against +incdir, so collect every suite directory here to make nested
# `include "test_*.svh"` robust for all generated test groups.
TEST_SUITE_DIRS := $(sort $(dir $(wildcard $(TB_DIR)/test/*/*_suite.svh)))
TEST_SUITE_INCDIR := $(foreach d,$(TEST_SUITE_DIRS),+incdir+$(patsubst %/,%,$(d)))

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
                   $(TEST_SUITE_INCDIR) \
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
                   +define+PA_WIDTH=40 \
                   +define+MMU_EXPT_TRACE_ONCE_EN \
                   -Mdir=$(OUTPUT_DIR)/csrc \
                   -o $(OUTPUT_DIR)/simv

# Parallel VCS only. Omit -Mupdate: incremental csrc makefiles can emit invalid
# targets (e.g. .o) and "cc -o .o" on path/env hiccups; full comp is the safe default.
PERF_OPTS       := -j4

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
                   +UVM_CONFIG_DB_TRACE \
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

COV_TAG         ?= $(TEST_NAME)_$(SEED)
COV_OPTS        := -cm line+cond+fsm+tgl+branch+assert \
                   -cm_name $(COV_TAG) \
                   -cm_dir $(COV_DIR)/$(COV_TAG).vdb \
                   -cm_hier $(PROJECT_DIR)/scripts/cov_hier.cfg

#===============================================================================
# Phase 10 - regression wrappers and coverage baseline
#===============================================================================
REGRESS_SCRIPT            ?= $(PROJECT_DIR)/scripts/run_test.py
REGRESS_MODE              ?= run_check
REGRESS_NAME              ?= adhoc
REGRESS_SEEDS             ?= 1
REGRESS_MIN_PASS_RATE     ?= 1.0
REGRESS_SUMMARY           ?= $(REGRESS_DIR)/$(REGRESS_NAME)/summary.txt
REGRESS_SMOKE_LIST        ?= $(SIMU_DIR)/mmu_smoke_list
REGRESS_NIGHTLY_LIST      ?= $(SIMU_DIR)/mmu_nightly_list
REGRESS_SMOKE_SEEDS       ?= 91001
REGRESS_NIGHTLY_SEEDS     ?= 92001 92002 92003 92004 92005
REGRESS_V3_NAME           ?= v3_gap
REGRESS_V3_LIST           ?= $(SIMU_DIR)/mmu_v3_regression_list
REGRESS_V3_SEEDS          ?= 93001 93002 93003
REGRESS_V3_MIN_PASS_RATE  ?= 1.0
REGRESS_V3_SUMMARY        ?= $(REGRESS_DIR)/$(REGRESS_V3_NAME)/summary.txt

#===============================================================================
# Phase 11 - v3.0 gap-driven regression
#===============================================================================
PHASE11_R19_PROOF         ?=
PHASE11_BUG015_REVIEW     ?= $(PROJECT_DIR)/../doc/phase11_bug015_doc_review.md
PHASE11_SKIP_COMPILE      ?= 0
PHASE11_BUG_SEED          ?= 94001
PHASE11_PROTOCOL_SEEDS    ?= 94101 94102 94103
PHASE11_V3_SEEDS          ?= 94201 94202 94203
PHASE11_R20_SEEDS         ?= 94301 94302 94303 94304 94305 94306 94307 94308 94309 94310
PHASE11_PROTOCOL_LIST     ?= $(SIMU_DIR)/mmu_ptw_lsu_protocol_list
PHASE11_V3_LIST           ?= $(SIMU_DIR)/mmu_v3_regression_list
PHASE11_PROTOCOL_SUMMARY  ?= $(REGRESS_DIR)/phase11_protocol/summary.txt
PHASE11_V3_SUMMARY        ?= $(REGRESS_DIR)/phase11_v3_gap/summary.txt

#===============================================================================
# Phase 7 — Covergroup + SVA 联跑与覆盖率 HTML（doc/MMU_Progress M7 / TaskDivision §7）
#  phase7:  comp 后 3 个 TEST_NAME 各 run 一次，log 中 UVM_ERROR/FATAL=0
#  phase7_cov: 同上以 run_cov 落 .vdb，再 urg → $(COV_DIR)/urgReport
#===============================================================================
print-phase7:
	@echo "PHASE7_TESTS = $(PHASE7_TESTS)"
	@echo "PHASE7_SEED  = $(PHASE7_SEED)"
	@echo "PHASE7_LOGS  = 3x $(LOG_DIR)/<test>_$(PHASE7_SEED).log"

# Windows/Git Bash: use MSYS/MinGW 或 WSL 中 make；核心为三次 sim + grep 0/0
phase7: comp
	@set -e; for t in $(PHASE7_TESTS); do \
		echo "=== phase7: $$t SEED=$(PHASE7_SEED) ==="; \
		$(MAKE) run TEST_NAME=$$t SEED=$(PHASE7_SEED); \
	done
	@set -e; for t in $(PHASE7_TESTS); do \
		f="$(LOG_DIR)/$${t}_$(PHASE7_SEED).log"; \
		test -f "$$f" || (echo "Missing $$f"; exit 1); \
		grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f UVM_ERROR"; exit 1); \
		grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f UVM_FATAL"; exit 1); \
	done
	@echo "=== phase7 OK: 3 tests UVM_ERROR=0 UVM_FATAL=0 (review simv for SVA/ASSERT summary) ==="

phase7_cov: comp
	@set -e; for t in $(PHASE7_TESTS); do \
		$(MAKE) run_cov TEST_NAME=$$t SEED=$(PHASE7_SEED); \
	done
	$(MAKE) cov
	@echo "=== phase7_cov: see URG under $(COV_DIR)/urgReport (or URG_OPTS -report) ==="

#===============================================================================
# Phase 8 — 14 vseq matrix (M8 TaskDivision #2: 3 seeds × 14 vseq = 42 runs)
#===============================================================================
print-phase8:
	@echo "PHASE8_TEST=$(PHASE8_TEST)  SEEDS=$(PHASE8_SEEDS)"
	@echo "Log pattern: $(LOG_DIR)/phase8_<VSEQ>_s<SEED>.log (copied from $(PHASE8_TEST)_<SEED>.log)"

print-phase11:
	@echo "PHASE11_R19_PROOF      = $(PHASE11_R19_PROOF)"
	@echo "PHASE11_BUG015_REVIEW  = $(PHASE11_BUG015_REVIEW)"
	@echo "PHASE11_SKIP_COMPILE   = $(PHASE11_SKIP_COMPILE)"
	@echo "PHASE11_BUG_SEED       = $(PHASE11_BUG_SEED)"
	@echo "PHASE11_PROTOCOL_SEEDS = $(PHASE11_PROTOCOL_SEEDS)"
	@echo "PHASE11_V3_SEEDS       = $(PHASE11_V3_SEEDS)"
	@echo "PHASE11_R20_SEEDS      = $(PHASE11_R20_SEEDS)"
	@echo "PHASE11_PROTOCOL_LIST  = $(PHASE11_PROTOCOL_LIST)"
	@echo "PHASE11_V3_LIST        = $(PHASE11_V3_LIST)"
	@echo "PHASE11_V3_SUMMARY     = $(PHASE11_V3_SUMMARY)"

# Large TIMEOUT: long PTW settle for thrash/perf
phase8_run_matrix: comp
	@set -e; for v in $(PHASE8_VSEQS); do \
	  for s in $(PHASE8_SEEDS); do \
	    echo "=== Phase8 vseq=$$v SEED=$$s ==="; \
	    $(MAKE) run TEST_NAME=$(PHASE8_TEST) SEED=$$s TIMEOUT=120000000 \
	      PLUS_ARGS="+VSEQ_NAME=$$v" ; \
	    cp -f "$(LOG_DIR)/$(PHASE8_TEST)_$$s.log" "$(LOG_DIR)/phase8_$${v}_s$$s.log"; \
	  done; \
	done

phase8_check:
	@set -e; for v in $(PHASE8_VSEQS); do \
	  for s in $(PHASE8_SEEDS); do \
	    f="$(LOG_DIR)/phase8_$${v}_s$$s.log"; \
	    test -f "$$f" || (echo "Missing $$f (run phase8_run_matrix first)"; exit 1); \
	    grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f UVM_ERROR"; exit 1); \
	    grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f UVM_FATAL"; exit 1); \
	    grep -E 'MMU_VSEQ_STATS' "$$f" >/dev/null 2>&1 || (echo "WARN: $$f missing MMU_VSEQ_STATS (TaskDivision #3)"; true); \
	  done; \
	done
	@echo "phase8_check: 42 log files UVM_ERROR=0 UVM_FATAL=0 (grep [MMU_VSEQ_TASKDIVISION#3] for stats)"

phase8: phase8_run_matrix phase8_check
	@echo "=== phase8: M8 matrix done (42 runs). Review SVA/ASSERT 0 in logs if required for sign-off. ==="

# Fast pass: 42 次与 phase8 相同，但 +UVM_ERR_ONLY 关闭大量 UVM_INFO/WARNING（[UVM_ERROR]/UVM 结尾 Report 应仍在）
# 用法：已编译过可  make phase8_run_matrix_fast phase8_check_errfatal
#       全量       make phase8_quick   （= comp + fast 矩阵 + errfatal 检查）
# 不隐式 comp — 同矩阵但 +UVM_ERR_ONLY（少打 INFO/WARN）。**不要**设 VERBOSITY=UVM_NONE：部分 VCS+UVM 会吞掉结尾 UVM Report 里的 UVM_ERROR:0 行，导致 phase8_check_errfatal 假失败。
phase8_run_matrix_fast:
	@set -e; for v in $(PHASE8_VSEQS); do \
	  for s in $(PHASE8_SEEDS); do \
	    echo "=== Phase8 fast vseq=$$v SEED=$$s (UVM_ERR_ONLY) ==="; \
	    $(MAKE) run TEST_NAME=$(PHASE8_TEST) SEED=$$s TIMEOUT=120000000 UVM_ERR_ONLY=1 \
	      PLUS_ARGS="+VSEQ_NAME=$$v" ; \
	    cp -f "$(LOG_DIR)/$(PHASE8_TEST)_$$s.log" "$(LOG_DIR)/phase8_$${v}_s$$s.log"; \
	  done; \
	done

# 只判 err/fatal 摘要=0；不要求 MMU_VSEQ_STATS（签核前再用 phase8_check 全项）
phase8_check_errfatal:
	@set -e; for v in $(PHASE8_VSEQS); do \
	  for s in $(PHASE8_SEEDS); do \
	    f="$(LOG_DIR)/phase8_$${v}_s$$s.log"; \
	    test -f "$$f" || (echo "Missing $$f (run phase8_run_matrix or phase8_run_matrix_fast first)"; exit 1); \
	    grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f UVM_ERROR"; exit 1); \
	    grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f UVM_FATAL"; exit 1); \
	  done; \
	done
	@echo "phase8_check_errfatal: 42 (or N) matrix logs — UVM_ERROR=0 UVM_FATAL=0 in report summary (no MMU_VSEQ_STATS gate)."

# 不重新仿真：在已有 phase8_*.log 上秒级列出错/非零 FATAL 的文件
phase8_scan_errfatal:
	@echo "--- logs with UVM_ERROR count != 0 in final report (empty = none) ---"
	@set -e; for f in $(LOG_DIR)/phase8_*.log; do \
	  test -f "$$f" || continue; \
	  grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || echo "$$f"; \
	done; echo "---"; \
	echo "--- logs with UVM_FATAL count != 0 (empty = none) ---"; \
	for f in $(LOG_DIR)/phase8_*.log; do \
	  test -f "$$f" || continue; \
	  grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || echo "$$f"; \
	done; echo "done (phase8_scan_errfatal)."

phase8_quick: comp phase8_run_matrix_fast phase8_check_errfatal
	@echo "=== phase8_quick: 42 fast runs + err/fatal only.  Run 'make phase8_check' for full M8 (incl. MMU_VSEQ_STATS). ==="

#===============================================================================
# Test Name Check
# A TEST_NAME can be either:
#   1) an exact UVM test class name registered via `uvm_component_utils, or
#   2) a test directory alias such as basic_tests / l1itlb_tests to run every
#      registered test under that directory sequentially with the same seed.
#===============================================================================
DETECTED_TESTS_CMD = grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test 2>/dev/null | \
                     sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u
TEST_GROUP_DIRS   := $(filter-out phase9_common,$(notdir $(patsubst %/,%,$(wildcard $(TB_DIR)/test/*/))))

define CHECK_TEST_NAME
	@if ! ( \
		($(DETECTED_TESTS_CMD) | grep -x "$(TEST_NAME)" >/dev/null 2>&1) || \
		(printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1) \
	); then \
		echo "ERROR: TEST_NAME='$(TEST_NAME)' is neither a registered UVM test nor a supported test directory alias."; \
		echo "  Use 'make list_tests' to view exact UVM test names."; \
		echo "  Supported directory aliases: $(TEST_GROUP_DIRS)"; \
		exit 2; \
	fi
endef

#===============================================================================
# Phony
#===============================================================================
# Phase 7 — 3 个现网用例 + UVM/断言门禁（P7-B-12 推荐，与 P7B01 表一致）
PHASE7_TESTS ?= test_mmu_translation_sanity test_mmu_invalidate_sfence_matrix test_ptw_map4k_directed
PHASE7_SEED  ?= 71001

#===============================================================================
# Phase 8 — M8 virtual sequences (MMU_UVM_TaskDivision.md §3 Phase 8)
#  test_mmu_vseq_runner +VSEQ_NAME=<class> +VSEQ_NUM_TXN optional
#  phase8_matrix: 14 vseq × PHASE8_SEEDS (default 3) → logs phase8_<vseq>_s<seed>.log
#===============================================================================
PHASE8_TEST   ?= test_mmu_vseq_runner
PHASE8_SEEDS  ?= 81001 81002 81003
PHASE8_VSEQS  ?= mmu_smoke_vseq mmu_concurrent_3pipe_vseq mmu_ptw_thrash_vseq \
	mmu_sfence_during_walk_vseq mmu_asid_context_switch_vseq mmu_huge_page_mix_vseq \
	mmu_rrpv_aging_vseq mmu_l2tlb_bank_conflict_vseq mmu_satp_hotswap_vseq \
	mmu_stress_all_ports_vseq mmu_power_gating_vseq mmu_reset_midtransaction_vseq \
	mmu_error_rain_vseq mmu_perf_bench_vseq

.PHONY: all help setup check_env env comp comp_all comp_rtl comp_tb elab \
        run run_check fast_check check_log run_gui run_batch debug profile verdi wave run_cov cov merge_cov \
        clean clean_all clean_wave clean_cov list_tests status info print-% \
        phase5 phase5_fast phase5_run_5seed phase5_run_3seed phase5_check \
        phase5_scan_logs phase5_ptw4k phase5_fullgate print-phase5 \
        phase6 phase6_fast phase6_run_matrix phase6_check print-phase6 \
        phase6_rtu_ptw phase6_rtu_ptw_fast phase6_rtu_ptw_run phase6_rtu_ptw_check \
        print-phase6-rtu-ptw phase6_full phase6_full_fast \
        phase7 phase7_cov print-phase7 \
        print-phase8 phase8_run_matrix phase8_run_matrix_fast phase8_check \
        phase8_check_errfatal phase8_scan_errfatal phase8_quick \
        regress regress_smoke regress_nightly print-regress \
        print-phase11 regress_v3_gap phase11_exit_check phase11_show_failures

all: comp run

# Fast: compile without debug + run without FSDB/waves (fastest iteration loop)
fast: comp_fast run_batch

print-regress:
	@echo "SIMU_DIR               = $(SIMU_DIR)"
	@echo "REGRESS_SCRIPT         = $(REGRESS_SCRIPT)"
	@echo "REGRESS_MODE           = $(REGRESS_MODE)"
	@echo "REGRESS_NAME           = $(REGRESS_NAME)"
	@echo "REGRESS_SEEDS          = $(REGRESS_SEEDS)"
	@echo "REGRESS_MIN_PASS_RATE  = $(REGRESS_MIN_PASS_RATE)"
	@echo "REGRESS_SUMMARY        = $(REGRESS_SUMMARY)"
	@echo "REGRESS_SMOKE_LIST     = $(REGRESS_SMOKE_LIST)"
	@echo "REGRESS_NIGHTLY_LIST   = $(REGRESS_NIGHTLY_LIST)"
	@echo "REGRESS_V3_NAME        = $(REGRESS_V3_NAME)"
	@echo "REGRESS_V3_LIST        = $(REGRESS_V3_LIST)"
	@echo "REGRESS_V3_SEEDS       = $(REGRESS_V3_SEEDS)"
	@echo "REGRESS_V3_SUMMARY     = $(REGRESS_V3_SUMMARY)"
	@echo "REGRESS_V3_MIN_PASS_RATE = $(REGRESS_V3_MIN_PASS_RATE)"

regress: setup
	@test -f "$(REGRESS_SCRIPT)" || (echo "ERROR: regression wrapper missing: $(REGRESS_SCRIPT)"; exit 2)
	@test -n "$(LIST)" || (echo "ERROR: LIST is empty. Example: make regress LIST=simu/mmu_smoke_list"; exit 2)
	$(PYTHON) "$(REGRESS_SCRIPT)" \
		--reg-list "$(LIST)" \
		--mode "$(REGRESS_MODE)" \
		--seeds "$(REGRESS_SEEDS)" \
		--verbosity "$(VERBOSITY)" \
		--timeout "$(TIMEOUT)" \
		--uvm-err-only "$(UVM_ERR_ONLY)" \
		--plus-args "$(PLUS_ARGS)" \
		--summary "$(REGRESS_SUMMARY)" \
		--min-pass-rate "$(REGRESS_MIN_PASS_RATE)"

regress_smoke: comp
	@$(MAKE) regress \
		LIST="$(REGRESS_SMOKE_LIST)" \
		REGRESS_MODE=run_check \
		REGRESS_NAME=smoke \
		REGRESS_SEEDS="$(REGRESS_SMOKE_SEEDS)" \
		REGRESS_MIN_PASS_RATE=1.0

regress_nightly: comp
	@set +e; \
	$(MAKE) regress \
		LIST="$(REGRESS_NIGHTLY_LIST)" \
		REGRESS_MODE=run_cov \
		REGRESS_NAME=nightly \
		REGRESS_SEEDS="$(REGRESS_NIGHTLY_SEEDS)" \
		REGRESS_MIN_PASS_RATE=0.5; \
	rc=$$?; \
	set -e; \
	if ls "$(COV_DIR)"/*.vdb >/dev/null 2>&1; then \
		$(MAKE) cov; \
	else \
		echo "No coverage databases found under $(COV_DIR); skipping URG."; \
	fi; \
	exit $$rc

regress_v3_gap: comp
	@set +e; \
	$(MAKE) regress \
		LIST="$(PHASE11_V3_LIST)" \
		REGRESS_MODE=run_cov \
		REGRESS_NAME=phase11_v3_gap \
		REGRESS_SUMMARY="$(PHASE11_V3_SUMMARY)" \
		REGRESS_SEEDS="$(PHASE11_V3_SEEDS)" \
		REGRESS_MIN_PASS_RATE=1.0 \
		VERBOSITY="$(VERBOSITY)" \
		TIMEOUT="$(TIMEOUT)" \
		UVM_ERR_ONLY="$(UVM_ERR_ONLY)"; \
	reg_rc=$$?; \
	set -e; \
	set +e; \
	bash $(PROJECT_DIR)/scripts/phase11_scan_regression_logs.sh "$(PHASE11_V3_LIST)" "$(PHASE11_V3_SEEDS)" "$(LOG_DIR)" cov; \
	scan_rc=$$?; \
	set -e; \
	if ls "$(COV_DIR)"/*.vdb >/dev/null 2>&1; then \
		$(MAKE) cov; \
	else \
		echo "No coverage databases found under $(COV_DIR); skipping URG."; \
	fi; \
	if [ $$reg_rc -ne 0 ]; then \
		echo "regress_v3_gap: underlying regression returned $$reg_rc"; \
	fi; \
	if [ $$scan_rc -ne 0 ]; then \
		echo "regress_v3_gap: scan_logs/check_sim_status returned $$scan_rc"; \
	fi; \
	if [ $$reg_rc -ne 0 ] || [ $$scan_rc -ne 0 ]; then \
		exit 1; \
	fi

phase11_exit_check:
	@PHASE11_R19_PROOF='$(PHASE11_R19_PROOF)' \
	PHASE11_BUG015_REVIEW='$(PHASE11_BUG015_REVIEW)' \
	PHASE11_BUG_SEED='$(PHASE11_BUG_SEED)' \
	PHASE11_PROTOCOL_SEEDS='$(PHASE11_PROTOCOL_SEEDS)' \
	PHASE11_V3_SEEDS='$(PHASE11_V3_SEEDS)' \
	PHASE11_R20_SEEDS='$(PHASE11_R20_SEEDS)' \
	PHASE11_PROTOCOL_LIST='$(PHASE11_PROTOCOL_LIST)' \
	PHASE11_V3_LIST='$(PHASE11_V3_LIST)' \
	PHASE11_PROTOCOL_SUMMARY='$(PHASE11_PROTOCOL_SUMMARY)' \
	PHASE11_V3_SUMMARY='$(PHASE11_V3_SUMMARY)' \
	PHASE11_SKIP_COMPILE='$(PHASE11_SKIP_COMPILE)' \
	VERBOSITY='$(VERBOSITY)' \
	TIMEOUT='$(TIMEOUT)' \
	UVM_ERR_ONLY='$(UVM_ERR_ONLY)' \
	bash $(PROJECT_DIR)/scripts/phase11_exit_check.sh

phase11_show_failures:
	@PHASE11_R19_PROOF='$(PHASE11_R19_PROOF)' \
	PHASE11_BUG015_REVIEW='$(PHASE11_BUG015_REVIEW)' \
	PHASE11_BUG_SEED='$(PHASE11_BUG_SEED)' \
	PHASE11_PROTOCOL_SEEDS='$(PHASE11_PROTOCOL_SEEDS)' \
	PHASE11_V3_SEEDS='$(PHASE11_V3_SEEDS)' \
	PHASE11_R20_SEEDS='$(PHASE11_R20_SEEDS)' \
	PHASE11_PROTOCOL_LIST='$(PHASE11_PROTOCOL_LIST)' \
	PHASE11_V3_LIST='$(PHASE11_V3_LIST)' \
	PHASE11_PROTOCOL_SUMMARY='$(PHASE11_PROTOCOL_SUMMARY)' \
	PHASE11_V3_SUMMARY='$(PHASE11_V3_SUMMARY)' \
	PHASE11_FAIL_TAIL='$(PHASE11_FAIL_TAIL)' \
	PHASE11_FAIL_SNIPPETS='$(PHASE11_FAIL_SNIPPETS)' \
	PHASE11_FAIL_MAX_LOGS='$(PHASE11_FAIL_MAX_LOGS)' \
	bash $(PROJECT_DIR)/scripts/phase11_show_failures.sh

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
	@if $(PERL) -MText::Table -e 1 >/dev/null 2>&1; then \
		$(PERL) $(PROJECT_DIR)/scripts/scan_logs.pl $(PHASE5_LOGS); \
	else \
		echo "[phase5_scan_logs] WARN: perl module Text::Table missing; fallback to grep UVM_ERROR/UVM_FATAL scan."; \
		if grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*[1-9]|UVM_FATAL[[:space:]]*:[[:space:]]*[1-9]' $(PHASE5_LOGS) >/dev/null 2>&1; then \
			echo "[phase5_scan_logs] FAIL: non-zero UVM_ERROR/UVM_FATAL summary found."; \
			exit 1; \
		else \
			echo "[phase5_scan_logs] PASS (fallback): all logs show UVM_ERROR=0 and UVM_FATAL=0"; \
		fi; \
	fi

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

# Final closeout gate: phase5 + ptw directed + scan logs (with fallback)
phase5_fullgate: phase5 phase5_ptw4k phase5_scan_logs
	@echo "=== phase5_fullgate finished OK (phase5 + ptw4k + scan_logs) ==="

#===============================================================================
# Phase 6 regression
#===============================================================================
print-phase6:
	@echo "PHASE6_TEST    = $(PHASE6_TEST)"
	@echo "PHASE6_MODES   = $(PHASE6_MODES)"
	@echo "PHASE6_SEEDS   = $(PHASE6_SEEDS)"
	@echo "PHASE6_INV_NUM = $(PHASE6_INV_NUM)"
	@echo "PHASE6_LOGS    = $(PHASE6_LOGS)"

phase6_run_matrix:
	@set -e; for m in $(PHASE6_MODES); do \
	  for s in $(PHASE6_SEEDS); do \
		echo "=== $(PHASE6_TEST) INV_MODE=$$m INV_NUM=$(PHASE6_INV_NUM) SEED=$$s ==="; \
		$(MAKE) run TEST_NAME=$(PHASE6_TEST) SEED=$$s PLUS_ARGS="+INV_MODE=$$m +INV_NUM=$(PHASE6_INV_NUM)"; \
		cp -f "$(LOG_DIR)/$(PHASE6_TEST)_$$s.log" "$(LOG_DIR)/$(PHASE6_TEST)_m$${m}_s$${s}.log"; \
	  done; \
	done

phase6_check:
	@set -e; for f in $(PHASE6_LOGS); do \
		test -f "$$f" || (echo "Missing log: $$f  (run phase6_run_matrix first)"; exit 1); \
		grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — UVM_ERROR is not 0"; exit 1); \
		grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — UVM_FATAL is not 0"; exit 1); \
		grep -E 'Invalidate SB summary:.*N_invalidations=[1-9][0-9]*.*mismatch=0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — invalidate summary missing or mismatch!=0"; exit 1); \
	done
	@echo "phase6_check: all matrix logs show UVM_ERROR=0 UVM_FATAL=0 and Invalidate SB mismatch=0 with non-zero invalidations"

phase6: comp phase6_run_matrix phase6_check
	@echo "=== phase6 finished OK (comp + 4 modes x 3 seeds x $(PHASE6_INV_NUM) txns + checks) ==="

phase6_fast: comp_fast phase6_run_matrix phase6_check
	@echo "=== phase6_fast finished OK (comp_fast + matrix + checks) ==="

print-phase6-rtu-ptw:
	@echo "PHASE6_RTU_PTW_TEST  = $(PHASE6_RTU_PTW_TEST)"
	@echo "PHASE6_RTU_PTW_SEEDS = $(PHASE6_RTU_PTW_SEEDS)"
	@echo "PHASE6_RTU_PTW_LOGS  = $(PHASE6_RTU_PTW_LOGS)"

# TaskDivision §6 #4: RTU flush + in-flight translation/PTW stress (3 seeds)
phase6_rtu_ptw_run:
	@set -e; for s in $(PHASE6_RTU_PTW_SEEDS); do \
	  echo "=== $(PHASE6_RTU_PTW_TEST) SEED=$$s ==="; \
	  $(MAKE) run TEST_NAME=$(PHASE6_RTU_PTW_TEST) SEED=$$s; \
	done

phase6_rtu_ptw_check:
	@set -e; for f in $(PHASE6_RTU_PTW_LOGS); do \
	  test -f "$$f" || (echo "Missing log: $$f  (run phase6_rtu_ptw_run first)"; exit 1); \
	  grep -E 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — UVM_ERROR is not 0"; exit 1); \
	  grep -E 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — UVM_FATAL is not 0"; exit 1); \
	  grep -E '\[abort_check\] summary:.*status=PASS' "$$f" >/dev/null 2>&1 || (echo "FAIL: $$f — missing [abort_check] summary PASS"; exit 1); \
	done
	@echo "phase6_rtu_ptw_check: UVM 0/0 and [abort_check] summary in all $(PHASE6_RTU_PTW_TEST) seed logs"

phase6_rtu_ptw: comp phase6_rtu_ptw_run phase6_rtu_ptw_check
	@echo "=== phase6_rtu_ptw finished OK (comp + $(words $(PHASE6_RTU_PTW_SEEDS)) seeds + abort_check) ==="

phase6_rtu_ptw_fast: comp_fast phase6_rtu_ptw_run phase6_rtu_ptw_check
	@echo "=== phase6_rtu_ptw_fast finished OK (comp_fast + RTU/PTW seeds + checks) ==="

# Full Phase 6 sign-off: invalidate matrix (§6 #2–3) + RTU/PTW (§6 #4); single compile
phase6_full: comp phase6_run_matrix phase6_check phase6_rtu_ptw_run phase6_rtu_ptw_check
	@echo "=== phase6_full finished OK (SFENCE matrix + RTU/PTW abort_check) ==="

phase6_full_fast: comp_fast phase6_run_matrix phase6_check phase6_rtu_ptw_run phase6_rtu_ptw_check
	@echo "=== phase6_full_fast finished OK ==="

#===============================================================================
# Help
#===============================================================================
help:
	@echo "Usage:"
	@echo "  make check_env                     # VCS in PATH? (comp/comp_fast run this first)"
	@echo "  make comp                          # Compile + elaborate"
	@echo "  make run TEST_NAME=<uvm_test|test_dir>  # Run one test, or every test under a directory alias"
	@echo "  make run_check TEST_NAME=<uvm_test|test_dir> SEED=<n>  # Run then auto-judge PASS/FAIL"
	@echo "  make fast_check TEST_NAME=<uvm_test|test_dir> SEED=<n> # comp_fast + run_check"
	@echo "  make all                           # comp + run"
	@echo "  make verdi TEST_NAME=<test>        # Open Verdi waveform"
	@echo "  make clean                         # Remove build artifacts"
	@echo "  make list_tests                    # List registered UVM tests"
	@echo ""
	@echo "Key variables:"
	@echo "  TEST_NAME=$(TEST_NAME)  SEED=$(SEED)  VERBOSITY=$(VERBOSITY)"
	@echo "  UVM_ERR_ONLY=$(UVM_ERR_ONLY)  (1=errors only on console)"
	@echo "  Example: make run TEST_NAME=test_mmu_translation_sanity UVM_ERR_ONLY=1"
	@echo "  Example: make run_check TEST_NAME=l2tlb_tests SEED=1 UVM_ERR_ONLY=1"
	@echo "  Example: make fast_check TEST_NAME=test_mmu_translation_sanity SEED=1 UVM_ERR_ONLY=1"
	@echo "  Group example: make run TEST_NAME=basic_tests SEED=1"
	@echo "  PLUS_ARGS: e.g. PLUS_ARGS=+MMU_LSU_MON_DBG  (P1 RSP bus snapshot, lsu_monitor.svh)"
	@echo ""
	@echo "Phase 10 (MMU_UVM_TaskDivision.md §10):"
	@echo "  make regress LIST=simu/mmu_smoke_list                 # generic regression list runner"
	@echo "  make regress_smoke                                    # smoke list, 100% pass gate"
	@echo "  make regress_nightly                                  # nightly list, multi-seed + URG baseline"
	@echo "  make regress_v3_gap                                   # Phase 11 v3 gap list + xfail + scan_logs"
	@echo "  make print-regress                                    # show regression defaults"
	@echo "  Override: REGRESS_SEEDS='1 2 3' REGRESS_MIN_PASS_RATE=0.5"
	@echo "  List format: one test per line; optional per-line PLUS_ARGS after the test name;"
	@echo "               optional xfail marker: xfail or xfail=<reason>"
	@echo ""
	@echo "Phase 11 (MMU_UVM_TaskDivision.md §11):"
	@echo "  make print-phase11                                    # show Phase11 file/seed defaults"
	@echo "  make regress_v3_gap                                   # 3-seed v3 union + integrated log scan"
	@echo "  make phase11_exit_check PHASE11_R19_PROOF=<jira.png>  # full Phase11 exit check, final PASS/FAIL"
	@echo "  make phase11_show_failures                            # inspect compile/regression fail logs"
	@echo "  Optional: PHASE11_BUG015_REVIEW=../doc/<closed_review>.md"
	@echo ""
	@echo "Phase 5 (MMU_UVM_TaskDivision.md §5):"
	@echo "  make print-phase5              # show PHASE5_TEST / default seeds / log path pattern"
	@echo "  make phase5_fast               # comp_fast + 5+3 SEEDs + UVM 0/0 检查（日常）"
	@echo "  make phase5                    # comp + 5+3 SEEDs + UVM 0/0 检查（签核/CI）"
	@echo "  make phase5_run_5seed         # 仅 5 个 SEED 回归（需已有 simv）"
	@echo "  make phase5_run_3seed         # 仅 3 个 SEED 回归"
	@echo "  make phase5_check             # 仅检查 8 个 log 中 UVM_ERROR/FATAL=0"
	@echo "  make phase5_scan_logs         # 可选：scan_logs.pl 扫 8 个 log（缺 Text::Table 自动降级）"
	@echo "  make phase5_ptw4k             # 可选：test_ptw_map4k_directed 定向一条"
	@echo "  make phase5_fullgate          # phase5 + phase5_ptw4k + phase5_scan_logs"
	@echo "  覆盖: PHASE5_TEST=test_mmu_translation_sanity  PHASE5_SEEDS5/SEEDS3 可改"
	@echo ""
	@echo "Phase 6 (MMU_UVM_TaskDivision.md §6):"
	@echo "  make print-phase6              # show mode/seed matrix and logs"
	@echo "  make phase6_fast               # comp_fast + (4 modes x 3 seeds) + checks"
	@echo "  make phase6                    # comp + (4 modes x 3 seeds) + checks"
	@echo "  make phase6_run_matrix         # only run matrix (requires simv)"
	@echo "  make phase6_check              # check UVM 0/0 + invalidate summary"
	@echo "  make print-phase6-rtu-ptw     # show RTU-flush/PTW test + seeds + logs"
	@echo "  make phase6_rtu_ptw            # comp + 3-seed RTU flush vs PTW + [abort_check] grep"
	@echo "  make phase6_rtu_ptw_fast     # comp_fast + same"
	@echo "  make phase6_full               # one comp: SFENCE matrix + RTU/PTW (full §6 make gate)"
	@echo "  make phase6_full_fast"
	@echo "  Optional: make run TEST_NAME=test_mmu_phase6_misc_inv_smoke  # misc+inv smoke"
	@echo "  Override: PHASE6_INV_NUM=100  PHASE6_SEEDS='...'  PHASE6_RTU_PTW_SEEDS='...'"
	@echo ""
	@echo "Phase 8 / M8 (virtual sequences, TaskDivision.md §3 Phase 8):"
	@echo "  make print-phase8              # PHASE8_TEST / SEEDS / log naming"
	@echo "  make run TEST_NAME=test_mmu_vseq_runner PLUS_ARGS=+VSEQ_NAME=mmu_smoke_vseq"
	@echo "  make phase8                    # comp + 14×3 + full phase8_check (incl. MMU_VSEQ_STATS)"
	@echo "  make phase8_quick              # comp + 42 runs w/ UVM_ERR_ONLY + phase8_check_errfatal (只扫 err/fatal)"
	@echo "  make phase8_run_matrix_fast    # 仅 42 次快速跑（需已有 simv 时可去掉 comp 依赖：先 make comp）"
	@echo "  make phase8_scan_errfatal      # 不仿真，只扫已有 phase8_*.log 里 ERROR/FATAL 是否非 0"
	@echo "  Override: PHASE8_SEEDS='s1 s2 s3'  PHASE8_VSEQS='mmu_smoke_vseq ...'"

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

# VCS (Synopsys) must be on PATH or passed as a full path: make comp VCS=/.../bin/vcs
# Without this, comp fails with: /bin/sh: vcs: command not found (exit 127) — an environment issue, not RTL.
check_env:
	@which "$(VCS)" >/dev/null 2>&1 || test -x "$(VCS)" || ( \
	  echo ""; \
	  echo "ERROR: VCS not found: make variable VCS=$(VCS)"; \
	  echo "  (Shell exit 127 = command not found. Install Synopsys VCS or fix PATH.)"; \
	  echo "  1) From mmu_verification:  source setup_env.sh   # after setup.local.sh with VCS_HOME if needed"; \
	  echo "  2) Or:  export VCS_HOME=<install> && export PATH=\$$VCS_HOME/bin:\$$PATH"; \
	  echo "  3) Or:  make comp VCS=/path/to/vcs"; \
	  echo "  See also: setup.local.sh.example"; \
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

comp_all: setup check_env
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

comp_fast: setup check_env
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
	@if printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1; then \
		set -e; \
		tests=`grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test/$(TEST_NAME) 2>/dev/null | \
		  sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u`; \
		test -n "$$tests" || (echo "ERROR: directory alias '$(TEST_NAME)' has no registered UVM tests."; exit 2); \
		echo "Running test group $(TEST_NAME), seed=$(SEED)"; \
		for t in $$tests; do \
			echo "=== [$(TEST_NAME)] $$t SEED=$(SEED) ==="; \
			$(MAKE) run TEST_NAME=$$t SEED=$(SEED) VERBOSITY="$(VERBOSITY)" TIMEOUT="$(TIMEOUT)" UVM_ERR_ONLY="$(UVM_ERR_ONLY)" PLUS_ARGS='$(PLUS_ARGS)'; \
		done; \
		echo "Completed test group $(TEST_NAME), seed=$(SEED)"; \
	else \
		echo "Running $(TEST_NAME), seed=$(SEED)"; \
		cd $(OUTPUT_DIR) && ./simv \
			$(RUN_OPTS) \
			$(SEED_OPTS) \
			$(FSDB_OPTS) \
			-l $(LOG_DIR)/$(TEST_NAME)_$(SEED).log; \
		echo "Simulation completed. Log: $(LOG_DIR)/$(TEST_NAME)_$(SEED).log"; \
	fi

run_check: setup
	$(CHECK_TEST_NAME)
	@if printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1; then \
		tests=`grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test/$(TEST_NAME) 2>/dev/null | \
		  sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u`; \
		test -n "$$tests" || { echo "ERROR: directory alias '$(TEST_NAME)' has no registered UVM tests."; exit 2; }; \
		set +e; \
		$(MAKE) run TEST_NAME=$(TEST_NAME) SEED=$(SEED) VERBOSITY="$(VERBOSITY)" TIMEOUT="$(TIMEOUT)" UVM_ERR_ONLY="$(UVM_ERR_ONLY)" PLUS_ARGS='$(PLUS_ARGS)'; \
		run_rc=$$?; \
		set -e; \
		logs=""; \
		for t in $$tests; do \
			logs="$$logs $(LOG_DIR)/$${t}_$(SEED).log"; \
		done; \
	else \
		set +e; \
		$(MAKE) run TEST_NAME=$(TEST_NAME) SEED=$(SEED) VERBOSITY="$(VERBOSITY)" TIMEOUT="$(TIMEOUT)" UVM_ERR_ONLY="$(UVM_ERR_ONLY)" PLUS_ARGS='$(PLUS_ARGS)'; \
		run_rc=$$?; \
		set -e; \
		logs="$(LOG_DIR)/$(TEST_NAME)_$(SEED).log"; \
	fi; \
	set +e; \
	MMU_LOG_MAX_MATCHES=$(LOG_STATUS_MAX_HITS) $(LOG_CHECKER) $$logs; \
	log_rc=$$?; \
	set -e; \
	if [ $$run_rc -ne 0 ]; then \
		echo "run_check: underlying run target returned $$run_rc"; \
	fi; \
	if [ $$run_rc -ne 0 ] || [ $$log_rc -ne 0 ]; then \
		exit 1; \
	fi

fast_check: comp_fast run_check

check_log:
	@test -n "$(LOG)" || (echo "Usage: make check_log LOG=$(LOG_DIR)/<test>.log"; exit 2)
	@MMU_LOG_MAX_MATCHES=$(LOG_STATUS_MAX_HITS) $(LOG_CHECKER) "$(LOG)"

run_gui: setup
	$(CHECK_TEST_NAME)
	@if printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1; then \
		echo "ERROR: run_gui does not support directory alias TEST_NAME='$(TEST_NAME)'."; \
		echo "  Use 'make run TEST_NAME=$(TEST_NAME) SEED=$(SEED)' for batch execution, or pass an exact UVM test name to run_gui."; \
		exit 2; \
	fi
	cd $(OUTPUT_DIR) && ./simv \
		$(RUN_OPTS) \
		$(SEED_OPTS) \
		$(FSDB_OPTS) \
		$(GUI_OPTS) \
		-l $(LOG_DIR)/$(TEST_NAME)_gui.log

run_batch: setup
	$(CHECK_TEST_NAME)
	@if printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1; then \
		set -e; \
		tests=`grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test/$(TEST_NAME) 2>/dev/null | \
		  sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u`; \
		test -n "$$tests" || (echo "ERROR: directory alias '$(TEST_NAME)' has no registered UVM tests."; exit 2); \
		echo "Running batch test group $(TEST_NAME), seed=$(SEED)"; \
		for t in $$tests; do \
			echo "=== [$(TEST_NAME)] $$t SEED=$(SEED) batch ==="; \
			$(MAKE) run_batch TEST_NAME=$$t SEED=$(SEED) VERBOSITY="$(VERBOSITY)" TIMEOUT="$(TIMEOUT)" UVM_ERR_ONLY="$(UVM_ERR_ONLY)" PLUS_ARGS='$(PLUS_ARGS)'; \
		done; \
		echo "Completed batch test group $(TEST_NAME), seed=$(SEED)"; \
	else \
		cd $(OUTPUT_DIR) && ./simv \
			$(RUN_OPTS) \
			$(SEED_OPTS) \
			-l $(LOG_DIR)/$(TEST_NAME)_batch.log; \
	fi

run_cov: setup
	$(CHECK_TEST_NAME)
	@if printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1; then \
		set -e; \
		tests=`grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test/$(TEST_NAME) 2>/dev/null | \
		  sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u`; \
		test -n "$$tests" || (echo "ERROR: directory alias '$(TEST_NAME)' has no registered UVM tests."; exit 2); \
		echo "Running coverage test group $(TEST_NAME), seed=$(SEED)"; \
		for t in $$tests; do \
			echo "=== [$(TEST_NAME)] $$t SEED=$(SEED) cov ==="; \
			$(MAKE) run_cov TEST_NAME=$$t SEED=$(SEED) VERBOSITY="$(VERBOSITY)" TIMEOUT="$(TIMEOUT)" UVM_ERR_ONLY="$(UVM_ERR_ONLY)" PLUS_ARGS='$(PLUS_ARGS)'; \
		done; \
		echo "Completed coverage test group $(TEST_NAME), seed=$(SEED)"; \
	else \
		cd $(OUTPUT_DIR) && ./simv \
			$(RUN_OPTS) \
			$(SEED_OPTS) \
			$(COV_OPTS) \
			-l $(LOG_DIR)/$(COV_TAG)_cov.log; \
	fi

debug: setup
	$(CHECK_TEST_NAME)
	@if printf '%s\n' $(TEST_GROUP_DIRS) | grep -x "$(TEST_NAME)" >/dev/null 2>&1; then \
		set -e; \
		tests=`grep -Rho "uvm_component_utils([^)]*)" $(PROJECT_DIR)/testbench/test/$(TEST_NAME) 2>/dev/null | \
		  sed -E 's/.*uvm_component_utils\(([^)]*)\).*/\1/' | sort -u`; \
		test -n "$$tests" || (echo "ERROR: directory alias '$(TEST_NAME)' has no registered UVM tests."; exit 2); \
		echo "Running debug test group $(TEST_NAME), seed=$(SEED)"; \
		for t in $$tests; do \
			echo "=== [$(TEST_NAME)] $$t SEED=$(SEED) debug ==="; \
			$(MAKE) debug TEST_NAME=$$t SEED=$(SEED) TIMEOUT="$(TIMEOUT)" UVM_ERR_ONLY="$(UVM_ERR_ONLY)" PLUS_ARGS='$(PLUS_ARGS)'; \
		done; \
		echo "Completed debug test group $(TEST_NAME), seed=$(SEED)"; \
	else \
		cd $(OUTPUT_DIR) && ./simv \
			$(RUN_OPTS) \
			$(SEED_OPTS) \
			$(FSDB_OPTS) \
			+UVM_VERBOSITY=UVM_DEBUG \
			-l $(LOG_DIR)/$(TEST_NAME)_debug.log; \
	fi

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
list_tests:
	@echo "Registered UVM tests:"
	@($(DETECTED_TESTS_CMD) | sed 's/^/  - /') || true
	@echo "Supported test directory aliases:"
	@printf '  - %s\n' $(TEST_GROUP_DIRS)

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
