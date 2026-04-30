#!/usr/bin/env bash

set -uo pipefail

URG_BIN="${URG:-urg}"
COV_DB_DIR="${COV_DB_DIR:?COV_DB_DIR is required}"
COV_DIR="${COV_DIR:?COV_DIR is required}"
URG_REPORT_DIR="${URG_REPORT_DIR:?URG_REPORT_DIR is required}"
URG_MERGED_DB="${URG_MERGED_DB:?URG_MERGED_DB is required}"
URG_LOG="${URG_LOG:-${COV_DIR}/urg_report.log}"
URG_ALLOW_PARTIAL_MERGE="${URG_ALLOW_PARTIAL_MERGE:-1}"
URG_BATCH_SIZE="${URG_BATCH_SIZE:-12}"
URG_VDB_GLOB="${URG_VDB_GLOB:-}"
RUN_URG_REPORT_VERSION="2026-04-30-pgflt-vdb-filter-v2"

declare -a RUNTIME_VDBS=()
declare -a GOOD_VDBS=()
declare -a BAD_VDBS=()
declare -a GOOD_VDB_PROBE_MODES=()

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

collect_runtime_vdbs() {
  local design_real
  local vdb
  local vdb_real
  local base

  [[ -d "${COV_DB_DIR}" ]] || die "coverage design database not found: ${COV_DB_DIR}"
  [[ -d "${COV_DIR}" ]] || die "coverage directory not found: ${COV_DIR}"

  design_real="$(cd "${COV_DB_DIR}" && pwd -P)" || die "cannot resolve ${COV_DB_DIR}"

  shopt -s nullglob
  for vdb in "${COV_DIR}"/*.vdb; do
    [[ -d "${vdb}" ]] || continue
    base="${vdb##*/}"
    case "${base}" in
      merged.vdb|merged_*.vdb|*.nfs_busy.*|.urg_probe_*.vdb|.urg_batch_*.vdb)
        echo "Skipping non-runtime coverage database: ${vdb}"
        continue
        ;;
    esac
    if [[ -n "${URG_VDB_GLOB}" ]]; then
      case "${base}" in
        ${URG_VDB_GLOB})
          ;;
        *)
          echo "Skipping runtime coverage database outside URG_VDB_GLOB='${URG_VDB_GLOB}': ${vdb}"
          continue
          ;;
      esac
    fi

    vdb_real="$(cd "${vdb}" && pwd -P)" || continue
    if [[ "${vdb_real}" == "${design_real}" ]]; then
      echo "Skipping compile-time design database from runtime list: ${vdb}"
      continue
    fi
    RUNTIME_VDBS+=("${vdb}")
  done
  shopt -u nullglob

  [[ ${#RUNTIME_VDBS[@]} -gt 0 ]] || \
    die "no runtime coverage databases found under ${COV_DIR}; run 'make run_cov TEST_NAME=<test> SEED=<seed>' first"
}

prepare_output() {
  mkdir -p "${COV_DIR}" "$(dirname "${URG_REPORT_DIR}")" "$(dirname "${URG_MERGED_DB}")" "$(dirname "${URG_LOG}")" || \
    die "could not create coverage output directories"
  : > "${URG_LOG}" || die "could not write URG log: ${URG_LOG}"
  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"
}

report_is_ready() {
  [[ -d "${URG_REPORT_DIR}" ]] && find "${URG_REPORT_DIR}" -type f | grep -q .
}

try_two_step_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  run_urg "${label}: merge" \
    "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" "${vdbs[@]}" \
      -dbname "${URG_MERGED_DB}" || return 1

  run_urg "${label}: report" \
    "${URG_BIN}" -full64 -dir "${URG_MERGED_DB}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_one_step_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  run_urg "${label}" \
    "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" "${vdbs[@]}" \
      -dbname "${URG_MERGED_DB}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_runtime_only_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")

  remove_artifact "${URG_REPORT_DIR}"

  run_urg "${label}" \
    "${URG_BIN}" -full64 -dir "${vdbs[@]}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_runtime_only_batched_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")
  local -a batch_dbs=()
  local batch_idx=0
  local start=0
  local end
  local batch_len
  local count
  local batch_db
  local rc=0

  if ! [[ "${URG_BATCH_SIZE}" =~ ^[0-9]+$ ]] || [[ "${URG_BATCH_SIZE}" -le 0 ]]; then
    URG_BATCH_SIZE=12
  fi

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  count=${#vdbs[@]}
  while [[ "${start}" -lt "${count}" ]]; do
    end=$((start + URG_BATCH_SIZE))
    if [[ "${end}" -gt "${count}" ]]; then
      end="${count}"
    fi
    batch_len=$((end - start))

    batch_db="${COV_DIR}/.urg_batch_${batch_idx}.vdb"
    remove_artifact "${batch_db}"
    batch_dbs+=("${batch_db}")

    run_urg "${label}: batch ${batch_idx}" \
      "${URG_BIN}" -full64 -dir "${vdbs[@]:start:batch_len}" \
        -dbname "${batch_db}" || {
          rc=1
          break
        }

    start="${end}"
    batch_idx=$((batch_idx + 1))
  done

  if [[ "${rc}" -eq 0 ]]; then
    run_urg "${label}: merge batches" \
      "${URG_BIN}" -full64 -dir "${batch_dbs[@]}" \
        -dbname "${URG_MERGED_DB}" || rc=1
  fi

  if [[ "${rc}" -eq 0 ]]; then
    run_urg "${label}: report" \
      "${URG_BIN}" -full64 -dir "${URG_MERGED_DB}" \
        -format both \
        -report "${URG_REPORT_DIR}" || rc=1
  fi

  for batch_db in "${batch_dbs[@]}"; do
    remove_artifact "${batch_db}"
  done

  [[ "${rc}" -eq 0 ]] && report_is_ready
}

try_batched_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")
  local -a batch_dbs=()
  local batch_idx=0
  local start=0
  local end
  local batch_len
  local count
  local batch_db
  local rc=0

  if ! [[ "${URG_BATCH_SIZE}" =~ ^[0-9]+$ ]] || [[ "${URG_BATCH_SIZE}" -le 0 ]]; then
    URG_BATCH_SIZE=12
  fi

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  count=${#vdbs[@]}
  while [[ "${start}" -lt "${count}" ]]; do
    end=$((start + URG_BATCH_SIZE))
    if [[ "${end}" -gt "${count}" ]]; then
      end="${count}"
    fi
    batch_len=$((end - start))

    batch_db="${COV_DIR}/.urg_batch_${batch_idx}.vdb"
    remove_artifact "${batch_db}"
    batch_dbs+=("${batch_db}")

    run_urg "${label}: batch ${batch_idx}" \
      "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" "${vdbs[@]:start:batch_len}" \
        -dbname "${batch_db}" || {
          rc=1
          break
        }

    start="${end}"
    batch_idx=$((batch_idx + 1))
  done

  if [[ "${rc}" -eq 0 ]]; then
    run_urg "${label}: merge batches" \
      "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" "${batch_dbs[@]}" \
        -dbname "${URG_MERGED_DB}" || rc=1
  fi

  if [[ "${rc}" -eq 0 ]]; then
    run_urg "${label}: report" \
      "${URG_BIN}" -full64 -dir "${URG_MERGED_DB}" \
        -format both \
        -report "${URG_REPORT_DIR}" || rc=1
  fi

  for batch_db in "${batch_dbs[@]}"; do
    remove_artifact "${batch_db}"
  done

  [[ "${rc}" -eq 0 ]] && report_is_ready
}

probe_runtime_vdbs() {
  local vdb
  local base
  local probe_db
  local probe_report
  local probe_mode

  GOOD_VDBS=()
  BAD_VDBS=()
  GOOD_VDB_PROBE_MODES=()

  echo
  echo "Isolating runtime VDBs after URG context failure..."
  for vdb in "${RUNTIME_VDBS[@]}"; do
    base="${vdb##*/}"
    probe_db="${COV_DIR}/.urg_probe_${base}"
    probe_report="${COV_DIR}/.urg_probe_${base}.report"
    remove_artifact "${probe_db}"
    remove_artifact "${probe_report}"

    probe_mode=""
    if run_urg "probe ${base} (design-context)" \
      "${URG_BIN}" -full64 -dir "${COV_DB_DIR}" "${vdb}" \
        -dbname "${probe_db}" \
        -format text \
        -report "${probe_report}"; then
      probe_mode="design-context"
    else
      remove_artifact "${probe_db}"
      remove_artifact "${probe_report}"

      if run_urg "probe ${base} (runtime-only)" \
        "${URG_BIN}" -full64 -dir "${vdb}" \
          -format text \
          -report "${probe_report}"; then
        probe_mode="runtime-only"
      fi
    fi

    if [[ -n "${probe_mode}" ]]; then
      echo "VDB probe PASS (${probe_mode}): ${vdb}"
      GOOD_VDBS+=("${vdb}")
      GOOD_VDB_PROBE_MODES+=("${probe_mode}")
    else
      echo "VDB probe FAIL: ${vdb}"
      BAD_VDBS+=("${vdb}")
    fi

    remove_artifact "${probe_db}"
    remove_artifact "${probe_report}"
  done
}

main() {
  collect_runtime_vdbs
  prepare_output

  {
    echo "run_urg_report version: ${RUN_URG_REPORT_VERSION}"
    echo "Coverage design DB: ${COV_DB_DIR}"
    echo "Runtime VDB count: ${#RUNTIME_VDBS[@]}"
    if [[ -n "${URG_VDB_GLOB}" ]]; then
      echo "Runtime VDB glob filter: ${URG_VDB_GLOB}"
    fi
    printf '  %s\n' "${RUNTIME_VDBS[@]}"
    echo "URG log: ${URG_LOG}"
  } | tee -a "${URG_LOG}"

  if try_two_step_report "design-context two-step" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_one_step_report "design-context one-step" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_batched_report "design-context batched" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated with batched merge: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_runtime_only_report "runtime-only direct report" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated without external design DB: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_runtime_only_batched_report "runtime-only batched" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated without external design DB using batched merge: ${URG_REPORT_DIR}"
    return 0
  fi

  probe_runtime_vdbs
  if [[ ${#GOOD_VDBS[@]} -gt 0 && "${URG_ALLOW_PARTIAL_MERGE}" == "1" ]]; then
    echo
    echo "WARNING: excluding ${#BAD_VDBS[@]} unreadable runtime VDB(s) from URG merge."
    for idx in "${!GOOD_VDBS[@]}"; do
      printf '  good (%s): %s\n' "${GOOD_VDB_PROBE_MODES[$idx]}" "${GOOD_VDBS[$idx]}"
    done
    printf '  bad: %s\n' "${BAD_VDBS[@]}"
    if try_two_step_report "partial valid-vdb two-step" "${GOOD_VDBS[@]}" ||
       try_one_step_report "partial valid-vdb one-step" "${GOOD_VDBS[@]}" ||
       try_batched_report "partial valid-vdb batched" "${GOOD_VDBS[@]}" ||
       try_runtime_only_report "partial valid-vdb runtime-only" "${GOOD_VDBS[@]}" ||
       try_runtime_only_batched_report "partial valid-vdb runtime-only batched" "${GOOD_VDBS[@]}"; then
      echo "URG report generated from ${#GOOD_VDBS[@]} valid runtime VDB(s): ${URG_REPORT_DIR}"
      return 0
    fi
  fi

  echo
  echo "ERROR: URG could not generate ${URG_REPORT_DIR}."
  echo "       See ${URG_LOG} for the exact Synopsys error and the VDB probe results."
  return 1
}

main "$@"
