#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOC_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/doc"

MAKE_BIN="${MAKE_BIN:-make}"

PHASE11_R19_PROOF="${PHASE11_R19_PROOF:-}"
PHASE11_BUG015_REVIEW="${PHASE11_BUG015_REVIEW:-${DOC_DIR}/phase11_bug015_doc_review.md}"
PHASE11_SKIP_COMPILE="${PHASE11_SKIP_COMPILE:-0}"
PHASE11_VERBOSITY="${VERBOSITY:-UVM_MEDIUM}"
PHASE11_TIMEOUT="${TIMEOUT:-10000000}"
PHASE11_UVM_ERR_ONLY="${UVM_ERR_ONLY:-0}"

PHASE11_BUG_SEED="${PHASE11_BUG_SEED:-94001}"
PHASE11_PROTOCOL_SEEDS="${PHASE11_PROTOCOL_SEEDS:-94101 94102 94103}"
PHASE11_V3_SEEDS="${PHASE11_V3_SEEDS:-94201 94202 94203}"
PHASE11_R20_SEEDS="${PHASE11_R20_SEEDS:-94301 94302 94303 94304 94305 94306 94307 94308 94309 94310}"

PHASE11_PROTOCOL_LIST="${PHASE11_PROTOCOL_LIST:-${PROJECT_DIR}/simu/mmu_ptw_lsu_protocol_list}"
PHASE11_V3_LIST="${PHASE11_V3_LIST:-${PROJECT_DIR}/simu/mmu_v3_regression_list}"
PHASE11_PROTOCOL_SUMMARY="${PHASE11_PROTOCOL_SUMMARY:-${PROJECT_DIR}/output/regression/phase11_protocol/summary.txt}"
PHASE11_V3_SUMMARY="${PHASE11_V3_SUMMARY:-${PROJECT_DIR}/output/regression/phase11_v3_gap/summary.txt}"

BUG_TESTS=(
  test_bug_005_l2_raw_vld_and_gate
  test_bug_006_l2_is_dtlb_store
  test_bug_007_rrpv_post_inv
  test_bug_008_pplru_entry0_first_hit
  test_bug_011_twu_2m_csr_cross
  test_bug_012_csr_grant_onehot
  test_bug_013_ptw_write_pipe_reset
  test_bug_014_xbar_cold_start
)

R20_TESTS=(
  test_bug_013_ptw_write_pipe_reset
  test_bug_014_xbar_cold_start
)

FAIL_COUNT=0

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

run_step() {
  local name="$1"
  shift
  echo
  echo "=== ${name} ==="
  if "$@"; then
    pass "${name}"
  else
    local rc=$?
    fail "${name} (rc=${rc})"
  fi
}

check_required_file() {
  local path="$1"
  [[ -n "${path}" && -f "${path}" ]]
}

step_compile() {
  if [[ "${PHASE11_SKIP_COMPILE}" == "1" ]]; then
    echo "Skipping compile because PHASE11_SKIP_COMPILE=1"
    return 0
  fi
  "${MAKE_BIN}" comp
}

step_r19_proof() {
  if [[ -z "${PHASE11_R19_PROOF}" ]]; then
    echo "PHASE11_R19_PROOF is empty"
    return 1
  fi
  check_required_file "${PHASE11_R19_PROOF}"
}

step_bug015_review() {
  check_required_file "${PHASE11_BUG015_REVIEW}"
}

step_bug_single_runs() {
  local rc=0
  local test_name
  for test_name in "${BUG_TESTS[@]}"; do
    echo "--- bug single run: ${test_name} seed=${PHASE11_BUG_SEED}"
    if ! "${MAKE_BIN}" run_check \
      TEST_NAME="${test_name}" \
      SEED="${PHASE11_BUG_SEED}" \
      VERBOSITY="${PHASE11_VERBOSITY}" \
      TIMEOUT="${PHASE11_TIMEOUT}" \
      UVM_ERR_ONLY="${PHASE11_UVM_ERR_ONLY}"; then
      rc=1
    fi
  done
  return "${rc}"
}

step_protocol_regression() {
  "${MAKE_BIN}" regress \
    LIST="${PHASE11_PROTOCOL_LIST}" \
    REGRESS_MODE=run_check \
    REGRESS_NAME=phase11_protocol \
    REGRESS_SUMMARY="${PHASE11_PROTOCOL_SUMMARY}" \
    REGRESS_SEEDS="${PHASE11_PROTOCOL_SEEDS}" \
    REGRESS_MIN_PASS_RATE=1.0 \
    VERBOSITY="${PHASE11_VERBOSITY}" \
    TIMEOUT="${PHASE11_TIMEOUT}" \
    UVM_ERR_ONLY="${PHASE11_UVM_ERR_ONLY}"
}

step_r20_focus() {
  local rc=0
  local test_name
  local seed
  for test_name in "${R20_TESTS[@]}"; do
    for seed in ${PHASE11_R20_SEEDS}; do
      echo "--- R20 focus: ${test_name} seed=${seed}"
      if ! "${MAKE_BIN}" run_check \
        TEST_NAME="${test_name}" \
        SEED="${seed}" \
        VERBOSITY="${PHASE11_VERBOSITY}" \
        TIMEOUT="${PHASE11_TIMEOUT}" \
        UVM_ERR_ONLY="${PHASE11_UVM_ERR_ONLY}"; then
        rc=1
      fi
    done
  done
  return "${rc}"
}

step_regress_v3_gap() {
  "${MAKE_BIN}" regress_v3_gap \
    PHASE11_V3_LIST="${PHASE11_V3_LIST}" \
    PHASE11_V3_SUMMARY="${PHASE11_V3_SUMMARY}" \
    PHASE11_V3_SEEDS="${PHASE11_V3_SEEDS}" \
    VERBOSITY="${PHASE11_VERBOSITY}" \
    TIMEOUT="${PHASE11_TIMEOUT}" \
    UVM_ERR_ONLY="${PHASE11_UVM_ERR_ONLY}"
}

step_makefile_target() {
  grep -Eq '^regress_v3_gap:' "${PROJECT_DIR}/Makefile"
}

main() {
  cd "${PROJECT_DIR}" || exit 2

  echo "Phase 11 exit check root: ${PROJECT_DIR}"
  echo "R19 proof             : ${PHASE11_R19_PROOF:-<missing>}"
  echo "BUG015 review record  : ${PHASE11_BUG015_REVIEW}"
  echo "Protocol seeds        : ${PHASE11_PROTOCOL_SEEDS}"
  echo "V3 regression seeds   : ${PHASE11_V3_SEEDS}"
  echo "R20 seeds             : ${PHASE11_R20_SEEDS}"

  run_step "compile" step_compile
  run_step "criterion 1 - R19 proof present" step_r19_proof
  run_step "criterion 4a - bug hunt single-test runs" step_bug_single_runs
  run_step "criterion 4b - BUG015 doc review record present" step_bug015_review
  run_step "criterion 5 - PTW->LSU protocol 3-seed regression" step_protocol_regression
  run_step "criterion 2 - R20 focused 10-seed check" step_r20_focus
  run_step "criterion 6a - Makefile regress_v3_gap target exists" step_makefile_target
  run_step "criterion 3+6b - v3 gap regression + integrated log scan" step_regress_v3_gap

  echo
  echo "========================================"
  if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "PHASE11_EXIT_CHECK: PASS"
    echo "========================================"
    exit 0
  fi

  echo "PHASE11_EXIT_CHECK: FAIL (${FAIL_COUNT} failed step(s))"
  echo "========================================"
  exit 1
}

main "$@"
