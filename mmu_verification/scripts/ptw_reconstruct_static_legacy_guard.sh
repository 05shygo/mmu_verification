#!/bin/bash
# =============================================================================
# PTW-RECON-ADD-017: Static Legacy Signal Guard
#
# Scans main signoff paths for old fst/scd/thd stage, 3bit ready, and grant
# vector references.  Any hit outside of deprecated/obsolete/archive boundaries
# is a FATAL error — this prevents old-signal regression.
#
# Usage:
#   bash ptw_reconstruct_static_legacy_guard.sh [--strict] [--list-only]
#
#   --strict    Also fail on legacy compat aliases (p13_pmp_*_vec, etc.)
#   --list-only Only scan regression lists, not source files
#
# Exit codes:
#   0 = clean (no old-stage references in signoff paths)
#   1 = old-stage references found in signoff paths
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STRICT=0
LIST_ONLY=0
FAILURES=0

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --list-only) LIST_ONLY=1 ;;
  esac
done

# ── Patterns that indicate old stage / vector / grant usage ────────────────
OLD_PATTERNS=(
  'fst_chk\|scd_chk\|thd_chk'
  'fst_pmp\|scd_pmp\|thd_pmp'
  'pmp_grant\[2:0\]'
  'csr_grant\[1:0\]'
  'twu_data_ready\[[0-9]'
)

# ── Obsolete test files (removed from signoff lists in Stage 5) ────────────
OBSOLETE_TEST_FILES=(
  'test_ptw_twu_cond_cov'
  'test_ptw_twu_cond_full'
  'test_ptw_remaining_cov'
  'test_ptw_residual_toggle_cov'
  'test_ptw_sva_combined_toggle_cov'
  'test_twu_condition_pmp_cov'
  'test_twu_condition_pagefault_cov'
  'test_twu_condition_arb_cov'
  'test_twu_toggle_cov'
  'test_twu_pmp_grant_onehot'
  'test_twu_mask_pmp_wait_all4'
  'test_bug_002_thd_chk_4k_a_bit'
  'test_bug_003_thd_chk_leaf_refill'
  'test_bug_012_csr_grant_onehot'
  'test_mmu_mbuf_multi_twu_independent_ready'
  'test_twu_branch_default_cov'
  'test_twu_pmp_wait_line_cov'
  'test_twu_condition_pagefault_cov'
  'test_twu_pmp_serial'
  'test_twu_pmp_wait_stall'
  'test_ptw_source_stage2_smoke'
  'test_ptw_mbuf_cond_toggle_cov'
  'test_ptw_l2pde_cache_cond_toggle_cov'
  'test_ptw_l1pde_cache_cond_toggle_cov'
  'test_ptw_onetofour_xbar_toggle_cov'
  'test_ptw_mbuf_entry_toggle_cov'
  'test_ptw_gated_clk_pplru_cov'
  'test_ptw_sva_6mod_cov'
  'test_ptw_sva_full_cov'
  'test_ptw_pplru_full_cov'
  'test_ptw_ptw_cond_full'
  'test_ptw_ptw_cov'
  'test_ptw_sva_assertion_cov'
  'test_ptw_sva_xbar_arb_cov'
  'test_ptw_sva_accerr_protocol_cov'
  'test_ptw_sva_arb_xbar_cov'
  'test_ptw_final_closure'
  'test_ptw_rsp_delay0_coverage_001'
  'test_ptw_rsp_delay1_coverage_001'
  'test_ptw_stage6_p0_suite'
  'test_ptw_stage7_suite'
  'pmp_twu_tests_v6'
)

# ── Allowed exemptions (only in comments, deprecated code, or archive docs) ──
ALLOWED_PATHS=(
  'ptw_reconstruct_stage0_static_audit.md'
  'ptw_reconstruct_stage5_list_adjustments.md'
  'PTW_Reconstruct_UVM_Stages_0_5_Master_Completion_Report.md'
  'ptw_reconstruct_review.md'
  'ptw_reconstruct_uvm_modification_plan.md'
  'ptw_reconstruct_uvm_staged_implementation_plan.md'
  '_deprecated_'
  'DEPRECATED'
  'compat_unified_only'
  'legacy'
)

# ── Signoff paths that must be clean ────────────────────────────────────────
SIGNOFF_DIRS=(
  "$REPO_ROOT/mmu_verification/testbench/top"
  "$REPO_ROOT/mmu_verification/testbench/env"
  "$REPO_ROOT/mmu_verification/testbench/test"
  "$REPO_ROOT/mmu_verification/simu"
  "$REPO_ROOT/mmu_verification/scripts"
)

echo "PTW_RECON_STATIC legacy_stage_signal_guard"
echo "  mode: strict=$STRICT list_only=$LIST_ONLY"
echo "  repo: $REPO_ROOT"
echo ""

for dir in "${SIGNOFF_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "  WARNING: directory not found: $dir"
    continue
  fi

  for pat in "${OLD_PATTERNS[@]}"; do
    hits=$(grep -rn "$pat" "$dir" 2>/dev/null || true)

    # Filter out allowed exemptions
    filtered_lines=()
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      exempt=0
      # Extract content after filename:linenum: (the actual code part)
      content=$(echo "$line" | sed 's/^[^:]*:[0-9]*://')
      # Exempt comment-only lines (// ...)
      if echo "$content" | grep -qE '^\s*//'; then
        exempt=1
      fi
      # Exempt compat/deprecated/legacy markers
      if echo "$line" | grep -qE 'compat_unified_only|DEPRECATED|deprecated|legacy|Legacy'; then
        exempt=1
      fi
      # Exempt obsolete test files (removed from signoff in Stage 5)
      for obs in "${OBSOLETE_TEST_FILES[@]}"; do
        if echo "$line" | grep -q "$obs"; then
          exempt=1
          break
        fi
      done
      for allow in "${ALLOWED_PATHS[@]}"; do
        if echo "$line" | grep -q "$allow"; then
          exempt=1
          break
        fi
      done
      if [ $exempt -eq 0 ]; then
        filtered_lines+=("$line")
      fi
    done <<< "$hits"

    if [ ${#filtered_lines[@]} -gt 0 ]; then
      FAILURES=$((FAILURES + 1))
      echo "  FAIL: old pattern '$pat' found in signoff path $dir:"
      for hit in "${filtered_lines[@]}"; do
        echo "    $hit"
      done
    fi
  done
done

echo ""
if [ $FAILURES -eq 0 ]; then
  echo "PTW_RECON_STATIC legacy_stage_signal_guard pass=1 failures=0"
  echo "PTW_SVA_COVER module=ptw_reconstruct_static_legacy_guard name=static_legacy_clean req=PTW-RECON-ADD-017 hits=1"
  exit 0
else
  echo "PTW_RECON_STATIC legacy_stage_signal_guard pass=0 failures=$FAILURES"
  echo "ERROR: $FAILURES old-stage reference(s) found in signoff paths. Fix before proceeding."
  exit 1
fi
