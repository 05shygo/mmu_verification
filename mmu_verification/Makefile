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

# Fast pass: 42 次与 phase8 相同，但关闭大量 UVM_INFO/WARNING 终端输出（仍保留 [UVM_ERROR]/Report summary）
#   + 只检查 UVM 报告里 ERROR/FATAL 是否为 0（不强制 MMU_VSEQ_STATS 行，适合先扫错）
# 用法：已编译过可  make phase8_run_matrix_fast phase8_check_errfatal
#       全量       make phase8_quick   （= comp + fast 矩阵 + errfatal 检查）
# 不隐式 comp — 与 phase8_run_matrix 相同但 UVM_ERR_ONLY=1+VERBOSITY=UVM_NONE；先 make comp 一次即可反复跑
phase8_run_matrix_fast:
	@set -e; for v in $(PHASE8_VSEQS); do \
	  for s in $(PHASE8_SEEDS); do \
	    echo "=== Phase8 fast vseq=$$v SEED=$$s (UVM_ERR_ONLY) ==="; \
	    $(MAKE) run TEST_NAME=$(PHASE8_TEST) SEED=$$s TIMEOUT=120000000 UVM_ERR_ONLY=1 \
	      VERBOSITY=UVM_NONE PLUS_ARGS="+VSEQ_NAME=$$v" ; \
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
        run run_gui run_batch debug profile verdi wave run_cov cov merge_cov \
        clean clean_all clean_wave clean_cov list_tests status info print-% \
        phase5 phase5_fast phase5_run_5seed phase5_run_3seed phase5_check \
        phase5_scan_logs phase5_ptw4k phase5_fullgate print-phase5 \
        phase6 phase6_fast phase6_run_matrix phase6_check print-phase6 \
        phase6_rtu_ptw phase6_rtu_ptw_fast phase6_rtu_ptw_run phase6_rtu_ptw_check \
        print-phase6-rtu-ptw phase6_full phase6_full_fast \
        phase7 phase7_cov print-phase7 \
        print-phase8 phase8_run_matrix phase8_run_matrix_fast phase8_check \
        phase8_check_errfatal phase8_scan_errfatal phase8_quick

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
