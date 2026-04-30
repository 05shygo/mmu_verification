#!/usr/bin/env bash

set -uo pipefail

URG_BIN="${URG:-urg}"
COV_DB_DIR="${COV_DB_DIR:?COV_DB_DIR is required}"
COV_DIR="${COV_DIR:?COV_DIR is required}"
LOG_DIR="${LOG_DIR:-}"
URG_REPORT_DIR="${URG_REPORT_DIR:?URG_REPORT_DIR is required}"
URG_MERGED_DB="${URG_MERGED_DB:?URG_MERGED_DB is required}"
URG_LOG="${URG_LOG:-${COV_DIR}/urg_report.log}"
URG_ALLOW_PARTIAL_MERGE="${URG_ALLOW_PARTIAL_MERGE:-1}"
URG_BATCH_SIZE="${URG_BATCH_SIZE:-12}"
URG_VDB_GLOB="${URG_VDB_GLOB:-}"
RUN_URG_REPORT_VERSION="2026-04-30-direct-seeded-runtime-vdb-v6"

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

runtime_vdb_has_metadata() {
  local vdb="$1"

  find "${vdb}" -mindepth 1 \
    \( -name "snps" -o -name "testdata" -o -name "cm.decl_info" -o -name "*.db" \) \
    -print -quit | grep -q .
}

runtime_vdb_has_design_context_hint() {
  local vdb="$1"

  find "${vdb}" -mindepth 1 \
    \( -name "cm.decl_info" -o -name "scope" -o -name "design" -o -name "hierarchy*" -o -name "module*" \) \
    -print -quit | grep -q .
}

runtime_vdb_has_files() {
  local vdb="$1"

  find "${vdb}" -type f -print -quit | grep -q .
}

cov_log_for_vdb() {
  local vdb="$1"
  local base

  [[ -n "${LOG_DIR}" ]] || return 1
  base="${vdb##*/}"
  base="${base%.vdb}"
  printf '%s/%s_cov.log\n' "${LOG_DIR}" "${base}"
}

print_log_matches() {
  local log="$1"
  local pattern="$2"

  [[ -s "${log}" ]] || return 1
  grep -Ein -m 8 "${pattern}" "${log}" | sed 's/^/  /'
}

preflight_runtime_vdbs() {
  local vdb
  local base
  local cov_log
  local hard_fail=0
  local log_issue_pattern
  local log_done_pattern

  log_issue_pattern='UVM_FATAL[[:space:]].*@|Segmentation fault|segmentation violation|SIGSEGV|core dumped|VCS internal error|Internal Error|License checkout failed|Unable to checkout|No such feature exists|Simulation timeout|UVM_TIMEOUT|timed out|TIMEOUT.*(hit|expired|reached)|killed|Killed'
  log_done_pattern='UVM Report Summary|V C S[[:space:]]+S i m u l a t i o n[[:space:]]+R e p o r t|Simulation completed|\$finish'

  echo
  echo "Preflighting runtime VDBs before URG..."
  for vdb in "${RUNTIME_VDBS[@]}"; do
    base="${vdb##*/}"
    echo "  VDB: ${vdb}"

    if [[ ! -d "${vdb}" ]]; then
      echo "ERROR: selected runtime VDB is not a directory: ${vdb}"
      hard_fail=1
      continue
    fi
    if ! runtime_vdb_has_files "${vdb}"; then
      echo "ERROR: selected runtime VDB is empty: ${vdb}"
      hard_fail=1
    elif ! runtime_vdb_has_metadata "${vdb}"; then
      echo "WARNING: selected runtime VDB has files but no obvious Synopsys VDB metadata: ${vdb}"
    elif ! runtime_vdb_has_design_context_hint "${vdb}"; then
      echo "WARNING: selected runtime VDB has no obvious design-context metadata."
      echo "         If URG reports 'No context available', regenerate it with 'make run_cov' so"
      echo "         the per-test VDB is seeded from ${COV_DB_DIR} before simulation."
    fi

    if cov_log="$(cov_log_for_vdb "${vdb}")"; then
      if [[ -s "${cov_log}" ]]; then
        echo "  cov log: ${cov_log}"
        if print_log_matches "${cov_log}" "${log_issue_pattern}"; then
          echo "ERROR: coverage log contains fatal/crash/license/timeout pattern for ${base}"
          hard_fail=1
        elif ! grep -Eiq "${log_done_pattern}" "${cov_log}"; then
          echo "WARNING: coverage log has no normal UVM/VCS completion marker: ${cov_log}"
        fi
      else
        echo "WARNING: expected coverage log is missing or empty: ${cov_log}"
      fi
    fi
  done

  if [[ "${hard_fail}" -ne 0 ]]; then
    die "runtime VDB preflight failed; fix the run_cov output before invoking URG"
  fi
}

print_vdb_diagnostics() {
  local vdb="$1"
  local cov_log

  echo "  VDB path: ${vdb}"
  if [[ -d "${vdb}" ]]; then
    echo "  VDB file count: $(find "${vdb}" -type f 2>/dev/null | wc -l)"
    echo "  VDB top-level entries:"
    find "${vdb}" -mindepth 1 -maxdepth 2 -print 2>/dev/null | sed 's/^/    /' | head -30
  else
    echo "  VDB directory is missing."
  fi

  if cov_log="$(cov_log_for_vdb "${vdb}")" && [[ -s "${cov_log}" ]]; then
    echo "  Coverage log: ${cov_log}"
    echo "  Relevant coverage log lines:"
    if ! grep -Ein -m 12 'UVM_(FATAL|ERROR)|Segmentation fault|SIGSEGV|core dumped|VCS internal error|Internal Error|License checkout failed|Unable to checkout|No such feature exists|Simulation timeout|UVM_TIMEOUT|timed out|TIMEOUT.*(hit|expired|reached)|No context available|UCAPI|coverage|cm_dir|cm_name' "${cov_log}" | sed 's/^/    /'; then
      echo "    (no fatal/crash/license/coverage hint found)"
    fi
  fi
}

report_unreadable_vdbs() {
  local vdb

  [[ ${#BAD_VDBS[@]} -gt 0 ]] || return 0

  echo
  echo "Unreadable runtime VDB diagnostics:"
  for vdb in "${BAD_VDBS[@]}"; do
    print_vdb_diagnostics "${vdb}"
  done
  echo
  echo "Required fix for unreadable runtime-only VDBs:"
  echo "  This VDB was generated without usable URG design context, or was copied from"
  echo "  a work database in a shape URG cannot reopen as a standalone runtime VDB."
  echo "  Re-run the selected test with 'make run_cov TEST_NAME=<test> SEED=<seed>' so"
  echo "  run_cov first seeds ${COV_DIR}/<test>_<seed>.vdb from the compile-time"
  echo "  design VDB, then runs simv with -cm_dir pointing directly at that final VDB."
  echo "  Then re-run make cov with the same URG_VDB_GLOB."
}

collect_runtime_vdbs() {
  local design_real
  local vdb
  local vdb_real
  local base

  [[ -d "${COV_DIR}" ]] || die "coverage directory not found: ${COV_DIR}"

  if [[ -d "${COV_DB_DIR}" ]]; then
    design_real="$(cd "${COV_DB_DIR}" && pwd -P)" || die "cannot resolve ${COV_DB_DIR}"
  else
    design_real=""
  fi

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
    if [[ -n "${design_real}" && "${vdb_real}" == "${design_real}" ]]; then
      echo "Skipping compile-time design database from runtime list: ${vdb}"
      continue
    fi
    RUNTIME_VDBS+=("${vdb}")
  done
  shopt -u nullglob

  [[ ${#RUNTIME_VDBS[@]} -gt 0 ]] || \
    die "no runtime coverage databases found under ${COV_DIR}; run 'make run_cov TEST_NAME=<test> SEED=<seed>' first"
}

validate_design_vdb() {
  [[ -d "${COV_DB_DIR}" ]] || die "coverage design database not found: ${COV_DB_DIR}"
  if ! find "${COV_DB_DIR}" -type f -print -quit | grep -q .; then
    die "coverage design database appears empty: ${COV_DB_DIR}. Re-run 'make comp' with coverage-enabled compile."
  fi
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
  local -a merge_dir_args=()
  local -a report_dir_args=()

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  merge_dir_args=(-dir "${COV_DB_DIR}" "${vdbs[@]}")
  report_dir_args=(-dir "${URG_MERGED_DB}")

  run_urg "${label}: merge" \
    "${URG_BIN}" -full64 "${merge_dir_args[@]}" \
      -dbname "${URG_MERGED_DB}" || return 1

  run_urg "${label}: report" \
    "${URG_BIN}" -full64 "${report_dir_args[@]}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_one_step_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")
  local -a dir_args=()

  remove_artifact "${URG_REPORT_DIR}"
  remove_artifact "${URG_MERGED_DB}"

  dir_args=(-dir "${COV_DB_DIR}" "${vdbs[@]}")

  run_urg "${label}" \
    "${URG_BIN}" -full64 "${dir_args[@]}" \
      -dbname "${URG_MERGED_DB}" \
      -format both \
      -report "${URG_REPORT_DIR}" || return 1

  report_is_ready
}

try_runtime_only_report() {
  local label="$1"
  shift
  local -a vdbs=("$@")
  local -a dir_args=()

  remove_artifact "${URG_REPORT_DIR}"

  dir_args=(-dir "${vdbs[@]}")

  run_urg "${label}" \
    "${URG_BIN}" -full64 "${dir_args[@]}" \
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

    local -a batch_dir_args=()
    batch_dir_args=(-dir "${vdbs[@]:start:batch_len}")
    run_urg "${label}: batch ${batch_idx}" \
      "${URG_BIN}" -full64 "${batch_dir_args[@]}" \
        -dbname "${batch_db}" || {
          rc=1
          break
        }

    start="${end}"
    batch_idx=$((batch_idx + 1))
  done

  if [[ "${rc}" -eq 0 ]]; then
    local -a merge_dir_args=()
    merge_dir_args=(-dir "${batch_dbs[@]}")
    run_urg "${label}: merge batches" \
      "${URG_BIN}" -full64 "${merge_dir_args[@]}" \
        -dbname "${URG_MERGED_DB}" || rc=1
  fi

  if [[ "${rc}" -eq 0 ]]; then
    local -a report_dir_args=()
    report_dir_args=(-dir "${URG_MERGED_DB}")
    run_urg "${label}: report" \
      "${URG_BIN}" -full64 "${report_dir_args[@]}" \
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

    local -a batch_dir_args=()
    batch_dir_args=(-dir "${COV_DB_DIR}" "${vdbs[@]:start:batch_len}")
    run_urg "${label}: batch ${batch_idx}" \
      "${URG_BIN}" -full64 "${batch_dir_args[@]}" \
        -dbname "${batch_db}" || {
          rc=1
          break
        }

    start="${end}"
    batch_idx=$((batch_idx + 1))
  done

  if [[ "${rc}" -eq 0 ]]; then
    local -a merge_dir_args=()
    merge_dir_args=(-dir "${COV_DB_DIR}" "${batch_dbs[@]}")
    run_urg "${label}: merge batches" \
      "${URG_BIN}" -full64 "${merge_dir_args[@]}" \
        -dbname "${URG_MERGED_DB}" || rc=1
  fi

  if [[ "${rc}" -eq 0 ]]; then
    local -a report_dir_args=()
    report_dir_args=(-dir "${URG_MERGED_DB}")
    run_urg "${label}: report" \
      "${URG_BIN}" -full64 "${report_dir_args[@]}" \
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
  local have_design_vdb=0

  if [[ -d "${COV_DB_DIR}" ]] && find "${COV_DB_DIR}" -type f -print -quit | grep -q .; then
    have_design_vdb=1
  fi

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
    if [[ "${have_design_vdb}" -eq 1 ]]; then
      local -a design_probe_dir_args=()
      design_probe_dir_args=(-dir "${COV_DB_DIR}" "${vdb}")
      if run_urg "probe ${base} (design-context)" \
        "${URG_BIN}" -full64 "${design_probe_dir_args[@]}" \
          -dbname "${probe_db}" \
          -format text \
          -report "${probe_report}"; then
        probe_mode="design-context"
      fi
    else
      echo "Skipping design-context probe because coverage design DB is missing/empty: ${COV_DB_DIR}"
    fi

    if [[ -z "${probe_mode}" ]]; then
      remove_artifact "${probe_db}"
      remove_artifact "${probe_report}"

      local -a runtime_probe_dir_args=()
      runtime_probe_dir_args=(-dir "${vdb}")
      if run_urg "probe ${base} (runtime-only)" \
        "${URG_BIN}" -full64 "${runtime_probe_dir_args[@]}" \
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
  local preflight_rc
  local design_rc

  prepare_output
  collect_runtime_vdbs

  {
    echo "run_urg_report version: ${RUN_URG_REPORT_VERSION}"
    echo "Coverage design DB: ${COV_DB_DIR}"
    if [[ -n "${LOG_DIR}" ]]; then
      echo "Coverage log dir: ${LOG_DIR}"
    fi
    echo "Runtime VDB count: ${#RUNTIME_VDBS[@]}"
    if [[ -n "${URG_VDB_GLOB}" ]]; then
      echo "Runtime VDB glob filter: ${URG_VDB_GLOB}"
    fi
    printf '  %s\n' "${RUNTIME_VDBS[@]}"
    echo "URG log: ${URG_LOG}"
  } | tee -a "${URG_LOG}"

  preflight_runtime_vdbs 2>&1 | tee -a "${URG_LOG}"
  preflight_rc=${PIPESTATUS[0]}
  if [[ "${preflight_rc}" -ne 0 ]]; then
    return "${preflight_rc}"
  fi

  if try_runtime_only_report "self-contained runtime direct report" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated from self-contained runtime VDB(s): ${URG_REPORT_DIR}"
    return 0
  fi

  if try_runtime_only_batched_report "self-contained runtime batched" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated from self-contained runtime VDB(s) using batched merge: ${URG_REPORT_DIR}"
    return 0
  fi

  validate_design_vdb 2>&1 | tee -a "${URG_LOG}"
  design_rc=${PIPESTATUS[0]}
  if [[ "${design_rc}" -ne 0 ]]; then
    echo "WARNING: coverage design DB is missing/empty; skipping design-context compatibility merges." | tee -a "${URG_LOG}"
    echo "         Run 'make comp' to regenerate ${COV_DB_DIR}, then re-run 'make run_cov' for old runtime-only VDBs." | tee -a "${URG_LOG}"
    probe_runtime_vdbs
    report_unreadable_vdbs
    echo
    echo "ERROR: URG could not generate ${URG_REPORT_DIR} from the selected runtime VDB(s)." | tee -a "${URG_LOG}"
    return "${design_rc}"
  fi

  if try_two_step_report "design-context compatibility two-step" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated with design-context compatibility merge: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_one_step_report "design-context compatibility one-step" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated with design-context compatibility merge: ${URG_REPORT_DIR}"
    return 0
  fi

  if try_batched_report "design-context compatibility batched" "${RUNTIME_VDBS[@]}"; then
    echo "URG report generated with design-context compatibility batched merge: ${URG_REPORT_DIR}"
    return 0
  fi

  probe_runtime_vdbs
  report_unreadable_vdbs
  if [[ ${#GOOD_VDBS[@]} -gt 0 && "${URG_ALLOW_PARTIAL_MERGE}" == "1" ]]; then
    echo
    echo "WARNING: excluding ${#BAD_VDBS[@]} unreadable runtime VDB(s) from URG merge."
    for idx in "${!GOOD_VDBS[@]}"; do
      printf '  good (%s): %s\n' "${GOOD_VDB_PROBE_MODES[$idx]}" "${GOOD_VDBS[$idx]}"
    done
    if [[ ${#BAD_VDBS[@]} -gt 0 ]]; then
      printf '  bad: %s\n' "${BAD_VDBS[@]}"
    fi
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
