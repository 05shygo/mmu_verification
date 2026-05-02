#!/usr/bin/env bash

set -uo pipefail

URG_BIN="${URG:-urg}"
COV_DB_DIR="${COV_DB_DIR:?COV_DB_DIR is required}"
COV_DIR="${COV_DIR:?COV_DIR is required}"
LOG_DIR="${LOG_DIR:-}"
URG_REPORT_DIR="${URG_REPORT_DIR:?URG_REPORT_DIR is required}"
URG_MERGED_DB="${URG_MERGED_DB:?URG_MERGED_DB is required}"
URG_LOG="${URG_LOG:-${COV_DIR}/urg_report.log}"
URG_VDB_GLOB="${URG_VDB_GLOB:-}"
URG_ALLOW_CONTEXTLESS_MERGE="${URG_ALLOW_CONTEXTLESS_MERGE:-0}"
COV_BASE_DB_DIR="${COV_BASE_DB_DIR:-}"
if [[ -z "${COV_BASE_DB_DIR}" && "${COV_DB_DIR}" == *.vdb ]]; then
  COV_BASE_DB_DIR="${COV_DB_DIR%.vdb}.compile.vdb"
fi
RUN_URG_REPORT_VERSION="2026-05-02-aggregate-vdb-context-required-v11"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

is_unsafe_path() {
  local path="$1"
  [[ -z "${path}" || "${path}" == "/" || "${path}" == "." ]]
}

remove_artifact() {
  local path="$1"
  local stale

  if is_unsafe_path "${path}"; then
    die "unsafe path '${path}'"
  fi
  [[ -e "${path}" ]] || return 0

  stale="${path}.stale.$(date +%Y%m%d_%H%M%S).$$"
  if mv "${path}" "${stale}" 2>/dev/null; then
    rm -rf "${stale}" 2>/dev/null || \
      echo "WARNING: left stale coverage artifact at ${stale}; close the process holding it and remove it later."
  elif rm -rf "${path}" 2>/dev/null; then
    :
  else
    die "could not clean stale coverage artifact ${path}"
  fi
}

log_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

run_urg() {
  local label="$1"
  local rc
  shift

  {
    echo
    echo "=== URG attempt: ${label} ==="
    log_cmd "$@"
  } | tee -a "${URG_LOG}"

  "$@" 2>&1 | tee -a "${URG_LOG}"
  rc=${PIPESTATUS[0]}
  echo "=== URG attempt '${label}' rc=${rc} ===" | tee -a "${URG_LOG}"
  return "${rc}"
}

validate_aggregate_vdb() {
  [[ -d "${COV_DB_DIR}" ]] || die "aggregate coverage database not found: ${COV_DB_DIR}"
  if ! find "${COV_DB_DIR}" -type f -print -quit | grep -q .; then
    die "aggregate coverage database appears empty: ${COV_DB_DIR}. Re-run 'make comp' and 'make run_cov'."
  fi
}

has_compile_context_vdb() {
  [[ -n "${COV_BASE_DB_DIR}" ]] || return 1
  [[ -d "${COV_BASE_DB_DIR}" ]] || return 1
  find "${COV_BASE_DB_DIR}" -type f -print -quit | grep -q .
}

prepare_output() {
  mkdir -p "${COV_DIR}" "$(dirname "${URG_REPORT_DIR}")" "$(dirname "${URG_MERGED_DB}")" "$(dirname "${URG_LOG}")" || \
    die "could not create coverage output directories"
  : > "${URG_LOG}" || die "could not write URG log: ${URG_LOG}"
  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"
}

report_is_ready() {
  [[ -d "${URG_REPORT_DIR}" ]] && find "${URG_REPORT_DIR}" -type f -print -quit | grep -q .
}

try_direct_report() {
  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  run_urg "aggregate VDB direct report" \
    "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_two_step_report() {
  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  run_urg "aggregate VDB merge" \
    "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" \
      -dbname "${URG_MERGED_DB}" || return 1

  run_urg "aggregate merged VDB report" \
    "${URG_BIN}" -full64 -dir "${URG_MERGED_DB}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_context_direct_report() {
  has_compile_context_vdb || return 1

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  run_urg "compile-context + aggregate VDB direct report" \
    "${URG_BIN}" -full64 -dir "${COV_BASE_DB_DIR}" -dir "${COV_DB_DIR}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_context_two_step_report() {
  has_compile_context_vdb || return 1

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  run_urg "compile-context + aggregate VDB merge" \
    "${URG_BIN}" -full64 -dir "${COV_BASE_DB_DIR}" -dir "${COV_DB_DIR}" \
      -dbname "${URG_MERGED_DB}" || return 1

  run_urg "context merged VDB report" \
    "${URG_BIN}" -full64 -dir "${URG_MERGED_DB}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

main() {
  prepare_output
  validate_aggregate_vdb

  {
    echo "run_urg_report version: ${RUN_URG_REPORT_VERSION}"
    echo "Coverage aggregate DB: ${COV_DB_DIR}"
    if has_compile_context_vdb; then
      echo "Coverage compile context DB: ${COV_BASE_DB_DIR}"
    else
      echo "Coverage compile context DB: unavailable (${COV_BASE_DB_DIR:-unset})"
    fi
    if [[ -n "${LOG_DIR}" ]]; then
      echo "Coverage log dir: ${LOG_DIR}"
    fi
    if [[ -n "${URG_VDB_GLOB}" ]]; then
      echo "WARNING: URG_VDB_GLOB='${URG_VDB_GLOB}' is ignored by aggregate-VDB flow."
    fi
    echo "Allow contextless URG merge fallback: ${URG_ALLOW_CONTEXTLESS_MERGE}"
    echo "URG report dir: ${URG_REPORT_DIR}"
    echo "URG merged DB: ${URG_MERGED_DB}"
    echo "URG log: ${URG_LOG}"
  } | tee -a "${URG_LOG}"

  if try_direct_report; then
    echo "URG report generated from aggregate coverage VDB: ${URG_REPORT_DIR}"
    return 0
  fi

  if ! has_compile_context_vdb; then
    echo
    echo "ERROR: aggregate VDB direct report failed and compile context VDB is unavailable."
    echo "       Expected compile context VDB: ${COV_BASE_DB_DIR:-unset}"
    echo "       Rebuild coverage context with: make clean && make comp"
    echo "       Then rerun: make cov"
    return 1
  fi

  if try_context_direct_report; then
    echo "URG report generated from aggregate coverage VDB with compile context: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_context_two_step_report; then
    echo "URG report generated from context merged coverage VDB: ${URG_REPORT_DIR}"
    return 0
  fi

  if [[ "${URG_ALLOW_CONTEXTLESS_MERGE}" == "1" ]]; then
    if try_two_step_report; then
      echo "URG report generated from aggregate merged coverage VDB: ${URG_REPORT_DIR}"
      return 0
    fi
  fi

  echo
  echo "ERROR: URG could not generate ${URG_REPORT_DIR}."
  echo "       See ${URG_LOG} for the exact Synopsys error."
  return 1
}

main "$@"
