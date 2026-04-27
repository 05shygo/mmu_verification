#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOC_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/doc"

LOG_DIR="${PROJECT_DIR}/output/logs"
REGRESS_DIR="${PROJECT_DIR}/output/regression"

PHASE11_R19_PROOF="${PHASE11_R19_PROOF:-}"
PHASE11_BUG015_REVIEW="${PHASE11_BUG015_REVIEW:-${DOC_DIR}/phase11_bug015_doc_review.md}"

PHASE11_BUG_SEED="${PHASE11_BUG_SEED:-94001}"
PHASE11_PROTOCOL_SEEDS="${PHASE11_PROTOCOL_SEEDS:-94101 94102 94103}"
PHASE11_V3_SEEDS="${PHASE11_V3_SEEDS:-94201 94202 94203}"
PHASE11_R20_SEEDS="${PHASE11_R20_SEEDS:-94301 94302 94303 94304 94305 94306 94307 94308 94309 94310}"

PHASE11_PROTOCOL_LIST="${PHASE11_PROTOCOL_LIST:-${PROJECT_DIR}/simu/mmu_ptw_lsu_protocol_list}"
PHASE11_V3_LIST="${PHASE11_V3_LIST:-${PROJECT_DIR}/simu/mmu_v3_regression_list}"
PHASE11_PROTOCOL_SUMMARY="${PHASE11_PROTOCOL_SUMMARY:-${REGRESS_DIR}/phase11_protocol/summary.txt}"
PHASE11_V3_SUMMARY="${PHASE11_V3_SUMMARY:-${REGRESS_DIR}/phase11_v3_gap/summary.txt}"

PHASE11_FAIL_TAIL="${PHASE11_FAIL_TAIL:-120}"
PHASE11_FAIL_SNIPPETS="${PHASE11_FAIL_SNIPPETS:-40}"
PHASE11_FAIL_MAX_LOGS="${PHASE11_FAIL_MAX_LOGS:-20}"

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

declare -A SEEN_LOGS=()
declare -a LOGS_TO_CHECK=()
declare -a MISSING_LOGS=()

LOG_STATUS=""
LOG_REASON=""
LOG_UVM_ERROR=""
LOG_UVM_FATAL=""
LOG_HIT_COUNT=""

add_log() {
  local path="$1"
  [[ -n "${path}" ]] || return 0
  if [[ -n "${SEEN_LOGS[$path]+x}" ]]; then
    return 0
  fi
  SEEN_LOGS["$path"]=1
  if [[ -f "${path}" ]]; then
    LOGS_TO_CHECK+=("${path}")
  else
    MISSING_LOGS+=("${path}")
  fi
}

extract_uvm_count() {
  local key="$1"
  local log="$2"
  awk -v key="$key" '
    $0 ~ ("^" key "[[:space:]]*:") {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+$/) {
          val = $i;
        }
      }
    }
    END {
      if (val == "") {
        print "";
      } else {
        print val;
      }
    }
  ' "${log}"
}

count_error_hits() {
  local log="$1"
  awk '
    /^UVM_ERROR[[:space:]]*:/ { next }
    /^UVM_FATAL[[:space:]]*:/ { next }
    /UVM_ERROR / || /UVM_FATAL / || /Error-/ || /Error:/ || /Fatal:/ || /ASSERT/ || /SVA/ || /TEST FAILED/ || /FAILED:/ {
      count++;
    }
    END {
      print count + 0;
    }
  ' "${log}"
}

print_error_hits() {
  local log="$1"
  local limit="$2"
  awk -v limit="$limit" '
    /^UVM_ERROR[[:space:]]*:/ { next }
    /^UVM_FATAL[[:space:]]*:/ { next }
    /UVM_ERROR / || /UVM_FATAL / || /Error-/ || /Error:/ || /Fatal:/ || /ASSERT/ || /SVA/ || /TEST FAILED/ || /FAILED:/ {
      printf("    %d:%s\n", NR, $0);
      shown++;
      if (shown >= limit) {
        exit;
      }
    }
  ' "${log}"
}

classify_log() {
  local log="$1"
  local summary_seen
  local eot_seen

  LOG_STATUS="PASS"
  LOG_REASON="UVM summary clean"
  LOG_UVM_ERROR="$(extract_uvm_count "UVM_ERROR" "${log}")"
  LOG_UVM_FATAL="$(extract_uvm_count "UVM_FATAL" "${log}")"
  LOG_HIT_COUNT="$(count_error_hits "${log}")"

  summary_seen=$(grep -c 'UVM Report Summary' "${log}" 2>/dev/null || true)
  eot_seen=$(grep -c -E 'UVM Report Summary|V C S   S i m u l a t i o n   R e p o r t|\$finish called|TEST COMPLETED' "${log}" 2>/dev/null || true)

  if [[ -n "${LOG_UVM_ERROR}" && -n "${LOG_UVM_FATAL}" ]]; then
    if [[ "${LOG_UVM_ERROR}" -ne 0 || "${LOG_UVM_FATAL}" -ne 0 ]]; then
      LOG_STATUS="FAIL"
      LOG_REASON="UVM summary reports UVM_ERROR=${LOG_UVM_ERROR} UVM_FATAL=${LOG_UVM_FATAL}"
    fi
  elif [[ "${LOG_HIT_COUNT}" -ne 0 ]]; then
    LOG_STATUS="FAIL"
    LOG_REASON="log contains error/fatal patterns but no final UVM summary counts"
  elif [[ "${eot_seen}" -eq 0 || "${summary_seen}" -eq 0 ]]; then
    LOG_STATUS="FAIL"
    LOG_REASON="log missing final UVM/VCS completion summary"
  fi
}

load_list_tests() {
  local list_file="$1"
  [[ -f "${list_file}" ]] || return 0
  sed -E 's/[[:space:]]*#.*$//' "${list_file}" | awk 'NF { print $1 }'
}

collect_logs_from_summary() {
  local summary_file="$1"
  [[ -f "${summary_file}" ]] || return 0
  awk '
    /^(FAIL|XPASS|XFAIL) / {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^log=/) {
          sub(/^log=/, "", $i);
          print $i;
        }
      }
    }
  ' "${summary_file}"
}

print_summary_failures() {
  local label="$1"
  local summary_file="$2"

  echo
  echo "=== ${label} summary ==="
  if [[ ! -f "${summary_file}" ]]; then
    echo "[WARN] summary not found: ${summary_file}"
    return 0
  fi

  grep -E '^(FAIL|XPASS|XFAIL) ' "${summary_file}" || echo "(no FAIL/XPASS/XFAIL lines in ${summary_file})"
}

report_compile_log() {
  local comp_log="${LOG_DIR}/comp_all.log"

  echo "=== compile log ==="
  if [[ ! -f "${comp_log}" ]]; then
    echo "[WARN] compile log not found: ${comp_log}"
    return 0
  fi

  if grep -nE 'Error-|Error:|Fatal:|\*E,' "${comp_log}" >/dev/null 2>&1; then
    echo "[FAIL] compile log contains error markers: ${comp_log}"
    grep -nE 'Error-|Error:|Fatal:|\*E,' "${comp_log}" | tail -n "${PHASE11_FAIL_SNIPPETS}" || true
    echo "--- tail -n ${PHASE11_FAIL_TAIL} ${comp_log}"
    tail -n "${PHASE11_FAIL_TAIL}" "${comp_log}" || true
  else
    echo "[PASS] no obvious compile error markers in ${comp_log}"
  fi
}

collect_candidate_logs() {
  local test_name
  local seed

  for test_name in "${BUG_TESTS[@]}"; do
    add_log "${LOG_DIR}/${test_name}_${PHASE11_BUG_SEED}.log"
  done

  while IFS= read -r test_name; do
    [[ -n "${test_name}" ]] || continue
    for seed in ${PHASE11_PROTOCOL_SEEDS}; do
      add_log "${LOG_DIR}/${test_name}_${seed}.log"
    done
  done < <(load_list_tests "${PHASE11_PROTOCOL_LIST}")

  for test_name in "${R20_TESTS[@]}"; do
    for seed in ${PHASE11_R20_SEEDS}; do
      add_log "${LOG_DIR}/${test_name}_${seed}.log"
    done
  done

  while IFS= read -r test_name; do
    [[ -n "${test_name}" ]] || continue
    for seed in ${PHASE11_V3_SEEDS}; do
      add_log "${LOG_DIR}/${test_name}_${seed}_cov.log"
    done
  done < <(load_list_tests "${PHASE11_V3_LIST}")

  while IFS= read -r test_name; do
    add_log "${test_name}"
  done < <(collect_logs_from_summary "${PHASE11_PROTOCOL_SUMMARY}")

  while IFS= read -r test_name; do
    add_log "${test_name}"
  done < <(collect_logs_from_summary "${PHASE11_V3_SUMMARY}")
}

report_failed_logs() {
  local log
  local failed_count=0

  echo
  echo "=== failing logs ==="
  for log in "${LOGS_TO_CHECK[@]}"; do
    classify_log "${log}"
    if [[ "${LOG_STATUS}" == "PASS" ]]; then
      continue
    fi

    failed_count=$((failed_count + 1))
    echo
    echo "[FAIL] ${log}"
    echo "  summary: UVM_ERROR=${LOG_UVM_ERROR:-N/A} UVM_FATAL=${LOG_UVM_FATAL:-N/A} error_hits=${LOG_HIT_COUNT}"
    echo "  reason : ${LOG_REASON}"
    if [[ "${LOG_HIT_COUNT}" -ne 0 ]]; then
      echo "  error snippets:"
      print_error_hits "${log}" "${PHASE11_FAIL_SNIPPETS}"
      if [[ "${LOG_HIT_COUNT}" -gt "${PHASE11_FAIL_SNIPPETS}" ]]; then
        echo "    ... truncated, total matched lines: ${LOG_HIT_COUNT}"
      fi
    fi
    echo "  tail:"
    tail -n "${PHASE11_FAIL_TAIL}" "${log}" || true

    if [[ "${failed_count}" -ge "${PHASE11_FAIL_MAX_LOGS}" ]]; then
      echo
      echo "[INFO] reached PHASE11_FAIL_MAX_LOGS=${PHASE11_FAIL_MAX_LOGS}; stop printing more failing logs."
      break
    fi
  done

  if [[ "${failed_count}" -eq 0 ]]; then
    echo "[PASS] no failing logs detected among collected Phase 11 artifacts."
  fi
}

report_missing_files() {
  local path

  echo
  echo "=== prerequisite files ==="
  if [[ -n "${PHASE11_R19_PROOF}" ]]; then
    if [[ -f "${PHASE11_R19_PROOF}" ]]; then
      echo "[PASS] R19 proof file exists: ${PHASE11_R19_PROOF}"
    else
      echo "[FAIL] R19 proof file missing: ${PHASE11_R19_PROOF}"
    fi
  else
    echo "[WARN] PHASE11_R19_PROOF not provided to failure viewer."
  fi

  if [[ -f "${PHASE11_BUG015_REVIEW}" ]]; then
    echo "[PASS] BUG015 review file exists: ${PHASE11_BUG015_REVIEW}"
  else
    echo "[FAIL] BUG015 review file missing: ${PHASE11_BUG015_REVIEW}"
  fi

  echo
  echo "=== missing runtime logs ==="
  if [[ "${#MISSING_LOGS[@]}" -eq 0 ]]; then
    echo "[PASS] no missing Phase 11 candidate logs."
    return 0
  fi

  for path in "${MISSING_LOGS[@]}"; do
    echo "[MISS] ${path}"
  done
}

main() {
  cd "${PROJECT_DIR}" || exit 2

  echo "Phase 11 failure viewer root : ${PROJECT_DIR}"
  echo "LOG_DIR                     : ${LOG_DIR}"
  echo "PHASE11_PROTOCOL_SUMMARY    : ${PHASE11_PROTOCOL_SUMMARY}"
  echo "PHASE11_V3_SUMMARY          : ${PHASE11_V3_SUMMARY}"
  echo "TAIL                        : ${PHASE11_FAIL_TAIL}"
  echo "SNIPPETS                    : ${PHASE11_FAIL_SNIPPETS}"

  collect_candidate_logs
  report_missing_files
  report_compile_log
  print_summary_failures "phase11_protocol" "${PHASE11_PROTOCOL_SUMMARY}"
  print_summary_failures "phase11_v3_gap" "${PHASE11_V3_SUMMARY}"
  report_failed_logs
}

main "$@"
