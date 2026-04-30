#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOC_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/doc"

MAKE_BIN="${MAKE_BIN:-make}"
PYTHON_BIN="${PYTHON_BIN:-${PYTHON:-python3}}"

PHASE12_SCENE_MATRIX="${PHASE12_SCENE_MATRIX:-${DOC_DIR}/phase12_scene_matrix.md}"
PHASE12_STAGE_MANIFEST="${PHASE12_STAGE_MANIFEST:-${DOC_DIR}/phase12_b_stage_manifest.csv}"
PHASE12_COVERGROUP_MATRIX="${PHASE12_COVERGROUP_MATRIX:-${DOC_DIR}/phase12_covergroup_matrix.md}"
PHASE12_A_HANDOFF="${PHASE12_A_HANDOFF:-${DOC_DIR}/phase12_a_handoff.md}"
PHASE12_EXIT_CHECKLIST="${PHASE12_EXIT_CHECKLIST:-${DOC_DIR}/phase12_exit_checklist.md}"
PHASE12_A_REVIEW_NOTE="${PHASE12_A_REVIEW_NOTE:-${DOC_DIR}/phase12_a_review.md}"

PHASE12_LIST="${PHASE12_LIST:-${PROJECT_DIR}/simu/mmu_v4_phase12_list}"
PHASE12_SEEDS="${PHASE12_SEEDS:-95101 95102 95103}"
PHASE12_EXPECTED_SEEDS="${PHASE12_EXPECTED_SEEDS:-95101 95102 95103}"
PHASE12_SUMMARY="${PHASE12_SUMMARY:-${PROJECT_DIR}/output/regression/phase12_v4/summary.txt}"
PHASE12_URG_REPORT="${PHASE12_URG_REPORT:-${PROJECT_DIR}/output/coverage/urgReport}"
PHASE12_COV_DIR="${PHASE12_COV_DIR:-$(dirname "${PHASE12_URG_REPORT}")}"
PHASE12_LOG_DIR="${PHASE12_LOG_DIR:-${PROJECT_DIR}/output/logs}"

PHASE12_SKIP_COMPILE="${PHASE12_SKIP_COMPILE:-0}"
PHASE12_SKIP_REGRESSION="${PHASE12_SKIP_REGRESSION:-0}"
PHASE12_SKIP_CLEAN_COV="${PHASE12_SKIP_CLEAN_COV:-0}"
PHASE12_MAEE_MIN_HITS="${PHASE12_MAEE_MIN_HITS:-20}"
PHASE12_CG_MIN_PERCENT="${PHASE12_CG_MIN_PERCENT:-50}"
PHASE12_REGRESS_JOBS="${PHASE12_REGRESS_JOBS:-4}"
PHASE12_FAIL_FAST="${PHASE12_FAIL_FAST:-1}"
PHASE12_UVM_ERR_ONLY="${PHASE12_UVM_ERR_ONLY:-${UVM_ERR_ONLY:-1}}"

PHASE12_COV_GATE_PY="${PHASE12_COV_GATE_PY:-${PROJECT_DIR}/scripts/phase12_cov_gate.py}"
PHASE12_LOG_SCAN="${PHASE12_LOG_SCAN:-${PROJECT_DIR}/scripts/phase11_scan_regression_logs.sh}"

PHASE12_MAEE_SVA="${PHASE12_MAEE_SVA:-${PROJECT_DIR}/testbench/top/mmu_maee_twu_sva.sv}"
PHASE12_PMP_SVA="${PHASE12_PMP_SVA:-${PROJECT_DIR}/testbench/top/mmu_pmp_twu_sva.sv}"
PHASE12_TB_TOP="${PHASE12_TB_TOP:-${PROJECT_DIR}/testbench/top/tb_top.sv}"
PHASE12_FILES_F="${PHASE12_FILES_F:-${PROJECT_DIR}/testbench/Files.f}"
PHASE12_MAKEFILE="${PHASE12_MAKEFILE:-${PROJECT_DIR}/Makefile}"

FAIL_COUNT=0
declare -a PHASE12_TESTS=()
declare -a PHASE12_SEED_ARR=()

MAEE_ASSERTS=(
  sva_twu_maee_paths_mutex
  sva_maee0_triggers_csr_req
  sva_maee1_skips_csr_fsm
)

MAEE_COVERS=(
  cp_twu_maee_paths_mutex
  cp_maee0_triggers_csr_req
  cp_maee1_skips_csr_fsm
)

# Phase 12 签核 9 个白盒 covergroup（与 doc/MMU_UVM_TaskDivision.md §Phase 12 退出准则 #5
# 及 doc/phase12_covergroup_matrix.md 一致；修改时须同步更新文档与 phase12_cov_gate 调用方）
PHASE12_CGS=(
  cg_ptw_ready_transition
  cg_twu_idle_vs_mask_state
  cg_xbar_hit_level
  cg_twu_except_while_arb_busy
  cg_twu_data_ready_per_stage
  cg_arb_grant_type
  cg_ptw_arb_pgs_type
  cg_maee_leaf_level
  cg_maee_path
)

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
    if [[ "${PHASE12_FAIL_FAST}" == "1" ]]; then
      echo
      echo "PHASE12_EXIT_CHECK: FAIL_FAST after ${name} (rc=${rc})"
      exit "${rc}"
    fi
  fi
}

check_required_file() {
  local path="$1"
  [[ -n "${path}" && -f "${path}" ]]
}

normalize_words() {
  awk '{$1=$1; print}' <<< "$1"
}

load_phase12_tests() {
  if [[ ${#PHASE12_TESTS[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ ! -f "${PHASE12_LIST}" ]]; then
    echo "Phase 12 list missing: ${PHASE12_LIST}"
    return 1
  fi

  mapfile -t PHASE12_TESTS < <(sed -E 's/[[:space:]]*#.*$//' "${PHASE12_LIST}" | awk 'NF { print $1 }')
  if [[ ${#PHASE12_TESTS[@]} -eq 0 ]]; then
    echo "No runnable tests found in ${PHASE12_LIST}"
    return 1
  fi
}

load_phase12_seeds() {
  if [[ ${#PHASE12_SEED_ARR[@]} -gt 0 ]]; then
    return 0
  fi

  read -r -a PHASE12_SEED_ARR <<< "${PHASE12_SEEDS}"
  if [[ ${#PHASE12_SEED_ARR[@]} -eq 0 ]]; then
    echo "Phase 12 seed set is empty"
    return 1
  fi
}

summary_value() {
  local key="$1"
  awk -F': *' -v key="$key" '$1 == key { print $2; exit }' "${PHASE12_SUMMARY}"
}

maee_hits_for_prop() {
  local prop="$1"
  shift
  awk -v prop="$prop" '
    index($0, "PHASE12_MAEE_COVER") && index($0, "prop=" prop) {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^hits=/) {
          split($i, parts, "=")
          sum += parts[2] + 0
        }
      }
    }
    END {
      print sum + 0
    }
  ' "$@"
}

step_required_docs() {
  local path
  for path in \
    "${PHASE12_SCENE_MATRIX}" \
    "${PHASE12_STAGE_MANIFEST}" \
    "${PHASE12_COVERGROUP_MATRIX}" \
    "${PHASE12_A_HANDOFF}" \
    "${PHASE12_EXIT_CHECKLIST}"
  do
    if ! check_required_file "${path}"; then
      echo "Missing required doc: ${path}"
      return 1
    fi
  done
}

step_review_note_present() {
  if ! check_required_file "${PHASE12_A_REVIEW_NOTE}"; then
    echo "Missing A-side review note: ${PHASE12_A_REVIEW_NOTE}"
    return 1
  fi
}

step_phase12_scope() {
  local seed_string
  local expected_seed_string

  load_phase12_tests || return 1
  load_phase12_seeds || return 1

  if [[ ${#PHASE12_TESTS[@]} -ne 22 ]]; then
    echo "Expected 22 runnable tests, found ${#PHASE12_TESTS[@]} in ${PHASE12_LIST}"
    return 1
  fi

  seed_string="$(normalize_words "${PHASE12_SEEDS}")"
  expected_seed_string="$(normalize_words "${PHASE12_EXPECTED_SEEDS}")"
  if [[ "${seed_string}" != "${expected_seed_string}" ]]; then
    echo "Expected Phase 12 seeds '${expected_seed_string}', got '${seed_string}'"
    return 1
  fi
}

step_maee_sva_static() {
  local name

  if ! check_required_file "${PHASE12_MAEE_SVA}"; then
    echo "Missing MAEE SVA file: ${PHASE12_MAEE_SVA}"
    return 1
  fi

  for name in "${MAEE_ASSERTS[@]}"; do
    if ! grep -Eq "^[[:space:]]*${name}:[[:space:]]*assert property" "${PHASE12_MAEE_SVA}"; then
      echo "Missing MAEE assert property: ${name}"
      return 1
    fi
  done

  for name in "${MAEE_COVERS[@]}"; do
    if ! grep -Eq "^[[:space:]]*${name}:[[:space:]]*cover property" "${PHASE12_MAEE_SVA}"; then
      echo "Missing MAEE cover property: ${name}"
      return 1
    fi
    if ! grep -Fq "prop=${name}" "${PHASE12_MAEE_SVA}"; then
      echo "Missing MAEE cover hit print for ${name}"
      return 1
    fi
  done
}

step_phase12_integration_static() {
  if ! check_required_file "${PHASE12_FILES_F}"; then
    echo "Missing Files.f: ${PHASE12_FILES_F}"
    return 1
  fi
  if ! check_required_file "${PHASE12_TB_TOP}"; then
    echo "Missing tb_top.sv: ${PHASE12_TB_TOP}"
    return 1
  fi
  if ! check_required_file "${PHASE12_MAKEFILE}"; then
    echo "Missing Makefile: ${PHASE12_MAKEFILE}"
    return 1
  fi

  grep -Fq 'mmu_maee_twu_sva.sv' "${PHASE12_FILES_F}" || {
    echo "Files.f does not include mmu_maee_twu_sva.sv"
    return 1
  }
  grep -Fq 'mmu_pmp_twu_sva.sv' "${PHASE12_FILES_F}" || {
    echo "Files.f does not include mmu_pmp_twu_sva.sv"
    return 1
  }
  grep -Eq 'bind[[:space:]]+twu[[:space:]]+mmu_maee_twu_sva' "${PHASE12_TB_TOP}" || {
    echo "tb_top.sv does not bind mmu_maee_twu_sva onto twu"
    return 1
  }
  grep -Eq '^regress_v4_maee_ptw:' "${PHASE12_MAKEFILE}" || {
    echo "Makefile missing regress_v4_maee_ptw target"
    return 1
  }
}

step_pmp_skeleton_static() {
  if ! check_required_file "${PHASE12_PMP_SVA}"; then
    echo "Missing PMP/TWU SVA file: ${PHASE12_PMP_SVA}"
    return 1
  fi
  grep -Eq '^[[:space:]]*module[[:space:]]+mmu_pmp_twu_sva' "${PHASE12_PMP_SVA}" || {
    echo "mmu_pmp_twu_sva.sv missing module declaration"
    return 1
  }
  grep -Eq '^[[:space:]]*endmodule' "${PHASE12_PMP_SVA}" || {
    echo "mmu_pmp_twu_sva.sv missing endmodule"
    return 1
  }
}

step_cov_parser_present() {
  check_required_file "${PHASE12_COV_GATE_PY}"
}

step_compile() {
  if [[ "${PHASE12_SKIP_COMPILE}" == "1" ]]; then
    echo "Skipping compile because PHASE12_SKIP_COMPILE=1"
    return 0
  fi
  "${MAKE_BIN}" comp
}

step_clean_cov() {
  if [[ "${PHASE12_SKIP_REGRESSION}" == "1" ]]; then
    echo "Skipping clean_cov because PHASE12_SKIP_REGRESSION=1"
    return 0
  fi
  if [[ "${PHASE12_SKIP_CLEAN_COV}" == "1" ]]; then
    echo "Skipping clean_cov because PHASE12_SKIP_CLEAN_COV=1"
    return 0
  fi
  "${MAKE_BIN}" clean_cov
}

step_regression() {
  if [[ "${PHASE12_SKIP_REGRESSION}" == "1" ]]; then
    echo "Skipping regression because PHASE12_SKIP_REGRESSION=1"
    return 0
  fi

  "${MAKE_BIN}" regress \
    LIST="${PHASE12_LIST}" \
    REGRESS_MODE=run_cov \
    REGRESS_NAME=phase12_v4 \
    REGRESS_SUMMARY="${PHASE12_SUMMARY}" \
    REGRESS_SEEDS="${PHASE12_SEEDS}" \
    REGRESS_JOBS="${PHASE12_REGRESS_JOBS}" \
    REGRESS_MIN_PASS_RATE=1.0 \
    VERBOSITY="${VERBOSITY:-UVM_MEDIUM}" \
    TIMEOUT="${TIMEOUT:-10000000}" \
    UVM_ERR_ONLY="${PHASE12_UVM_ERR_ONLY}"
}

step_log_scan() {
  if [[ ! -f "${PHASE12_LOG_SCAN}" ]]; then
    echo "Missing log scan helper: ${PHASE12_LOG_SCAN}"
    return 1
  fi

  bash "${PHASE12_LOG_SCAN}" "${PHASE12_LIST}" "${PHASE12_SEEDS}" "${PHASE12_LOG_DIR}" cov
}

step_cov_report() {
  "${MAKE_BIN}" cov \
    COV_DIR="${PHASE12_COV_DIR}" \
    URG_REPORT_DIR="${PHASE12_URG_REPORT}" \
    URG_MERGED_DB="${PHASE12_COV_DIR}/merged.vdb" || return 1

  if [[ ! -d "${PHASE12_URG_REPORT}" ]]; then
    echo "URG report directory was not generated: ${PHASE12_URG_REPORT}"
    return 1
  fi
}

step_summary_gate() {
  local expected_total
  local total_runs
  local failed_runs
  local xpass_runs
  local pass_rate
  local mode
  local seeds
  local normalized_seeds

  load_phase12_tests || return 1
  load_phase12_seeds || return 1

  if ! check_required_file "${PHASE12_SUMMARY}"; then
    echo "Missing regression summary: ${PHASE12_SUMMARY}"
    return 1
  fi

  expected_total=$((${#PHASE12_TESTS[@]} * ${#PHASE12_SEED_ARR[@]}))
  total_runs="$(summary_value total_runs)"
  failed_runs="$(summary_value failed_runs)"
  xpass_runs="$(summary_value xpass_unexpected_runs)"
  pass_rate="$(summary_value pass_rate)"
  mode="$(summary_value mode)"
  seeds="$(summary_value seeds)"
  normalized_seeds="$(normalize_words "${seeds}")"

  [[ "${mode}" == "run_cov" ]] || {
    echo "Summary mode must be run_cov, got '${mode}'"
    return 1
  }
  [[ "${normalized_seeds}" == "$(normalize_words "${PHASE12_SEEDS}")" ]] || {
    echo "Summary seed set mismatch: '${seeds}'"
    return 1
  }
  [[ "${total_runs}" == "${expected_total}" ]] || {
    echo "Expected total_runs=${expected_total}, got '${total_runs}'"
    return 1
  }
  [[ "${failed_runs}" == "0" ]] || {
    echo "Expected failed_runs=0, got '${failed_runs}'"
    return 1
  }
  [[ "${xpass_runs}" == "0" ]] || {
    echo "Expected xpass_unexpected_runs=0, got '${xpass_runs}'"
    return 1
  }
  [[ "${pass_rate}" == "1.0000" ]] || {
    echo "Expected pass_rate=1.0000, got '${pass_rate}'"
    return 1
  }
}

step_maee_cover_gate() {
  local prop
  local log
  local logs=()
  local hits

  load_phase12_tests || return 1
  load_phase12_seeds || return 1

  for test_name in "${PHASE12_TESTS[@]}"; do
    for seed in "${PHASE12_SEED_ARR[@]}"; do
      log="${PHASE12_LOG_DIR}/${test_name}_${seed}_cov.log"
      if [[ ! -f "${log}" ]]; then
        echo "Missing regression log: ${log}"
        return 1
      fi
      logs+=("${log}")
    done
  done

  for prop in "${MAEE_COVERS[@]}"; do
    hits="$(maee_hits_for_prop "${prop}" "${logs[@]}")"
    echo "MAEE cover aggregate: ${prop} -> ${hits}"
    if [[ "${hits}" -lt "${PHASE12_MAEE_MIN_HITS}" ]]; then
      echo "Cover property ${prop} below threshold ${PHASE12_MAEE_MIN_HITS}"
      return 1
    fi
  done
}

step_covergroup_gate() {
  local log
  local probe_idle_hits=0

  load_phase12_tests || return 1
  load_phase12_seeds || return 1

  for test_name in "${PHASE12_TESTS[@]}"; do
    for seed in "${PHASE12_SEED_ARR[@]}"; do
      log="${PHASE12_LOG_DIR}/${test_name}_${seed}_cov.log"
      if [[ ! -f "${log}" ]]; then
        echo "Missing regression log: ${log}"
        return 1
      fi
      if grep -Fq "whitebox CG idle" "${log}" \
        || grep -Fq "MMU_DUT_PROBES_VIF not in config_db" "${log}"; then
        echo "Whitebox covergroup probe not bound in log: ${log}"
        probe_idle_hits=$((probe_idle_hits + 1))
      fi
    done
  done

  if [[ "${probe_idle_hits}" -ne 0 ]]; then
    echo "Detected ${probe_idle_hits} run(s) where mmu_env_cg_whitebox was idle."
    return 1
  fi

  "${PYTHON_BIN}" "${PHASE12_COV_GATE_PY}" \
    --report-dir "${PHASE12_URG_REPORT}" \
    --threshold "${PHASE12_CG_MIN_PERCENT}" \
    --groups "${PHASE12_CGS[@]}"
}

main() {
  cd "${PROJECT_DIR}" || exit 2

  echo "Phase 12 exit check root : ${PROJECT_DIR}"
  echo "Phase 12 list            : ${PHASE12_LIST}"
  echo "Phase 12 seeds           : ${PHASE12_SEEDS}"
  echo "Phase 12 summary         : ${PHASE12_SUMMARY}"
  echo "Phase 12 URG report      : ${PHASE12_URG_REPORT}"
  echo "Phase 12 coverage dir    : ${PHASE12_COV_DIR}"
  echo "Phase 12 review note     : ${PHASE12_A_REVIEW_NOTE}"
  echo "Phase 12 regress jobs    : ${PHASE12_REGRESS_JOBS}"
  echo "Phase 12 fail fast       : ${PHASE12_FAIL_FAST}"
  echo "Phase 12 UVM err only    : ${PHASE12_UVM_ERR_ONLY}"
  echo "MAKE_BIN                 : ${MAKE_BIN}"
  echo "PYTHON_BIN               : ${PYTHON_BIN}"

  run_step "criterion 1 - frozen docs present" step_required_docs
  run_step "criterion 2 - A-side review note present" step_review_note_present
  run_step "criterion 3 - Phase 12 list and seed scope" step_phase12_scope
  run_step "criterion 4 - MAEE SVA static definition" step_maee_sva_static
  run_step "criterion 5 - PMP skeleton static definition" step_pmp_skeleton_static
  run_step "criterion 6 - Phase 12 integration wiring" step_phase12_integration_static
  run_step "criterion 7 - coverage gate helper present" step_cov_parser_present
  run_step "criterion 8 - compile" step_compile
  run_step "criterion 9 - clean coverage artifacts" step_clean_cov
  run_step "criterion 10 - Phase 12 3-seed regression" step_regression
  run_step "criterion 11 - integrated log scan" step_log_scan
  run_step "criterion 12 - URG report generation" step_cov_report
  run_step "criterion 13 - regression summary gate" step_summary_gate
  run_step "criterion 14 - MAEE cover hit gate" step_maee_cover_gate
  run_step "criterion 15 - covergroup percentage gate" step_covergroup_gate

  echo
  echo "========================================"
  if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "PHASE12_EXIT_CHECK: PASS"
    echo "========================================"
    exit 0
  fi

  echo "PHASE12_EXIT_CHECK: FAIL (${FAIL_COUNT} failed step(s))"
  echo "========================================"
  exit 1
}

main "$@"
