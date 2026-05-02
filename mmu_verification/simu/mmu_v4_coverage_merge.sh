#!/usr/bin/env bash
set -uo pipefail

# Phase 14 coverage merge/report wrapper.
# This script does not run simulation. It consumes the aggregate VDB produced by
# run_cov regressions and writes Phase 14-specific URG artifacts.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
COV_DB_DIR="${COV_DB_DIR:-${PROJECT_DIR}/output/simv.vdb}"
COV_BASE_DB_DIR="${COV_BASE_DB_DIR:-${PROJECT_DIR}/output/simv.compile.vdb}"
COV_DIR="${COV_DIR:-${PROJECT_DIR}/output/coverage}"
LOG_DIR="${LOG_DIR:-${PROJECT_DIR}/output/logs}"
URG_REPORT_DIR="${URG_REPORT_DIR:-${COV_DIR}/phase14_urgReport}"
URG_MERGED_DB="${URG_MERGED_DB:-${COV_DIR}/phase14_merged.vdb}"
URG_LOG="${URG_LOG:-${COV_DIR}/phase14_urg.log}"
SUMMARY="${PHASE14_COVERAGE_SUMMARY:-${COV_DIR}/phase14_coverage_merge_summary.txt}"
ISSUE_TRACKER="${PHASE14_ISSUE_TRACKER:-${PROJECT_DIR}/../doc/MMU_Phase14_IssueTracker.md}"
EXCLUDE_V4="${PHASE14_EXCLUDE_V4:-${PROJECT_DIR}/simu/exclude_v4.do}"
RUN_URG="${PROJECT_DIR}/scripts/run_urg_report.sh"

mkdir -p "${COV_DIR}" "$(dirname "${SUMMARY}")"

{
  echo "MMU Phase 14 coverage merge"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "project_dir=${PROJECT_DIR}"
  echo "cov_db_dir=${COV_DB_DIR}"
  echo "cov_base_db_dir=${COV_BASE_DB_DIR}"
  echo "urg_report_dir=${URG_REPORT_DIR}"
  echo "urg_merged_db=${URG_MERGED_DB}"
  echo "urg_log=${URG_LOG}"
  echo "issue_tracker=${ISSUE_TRACKER}"
  echo "exclude_v4=${EXCLUDE_V4}"
} > "${SUMMARY}"

if [[ ! -f "${RUN_URG}" ]]; then
  echo "ERROR: missing URG wrapper: ${RUN_URG}" | tee -a "${SUMMARY}" >&2
  exit 2
fi

if [[ ! -f "${ISSUE_TRACKER}" ]]; then
  echo "ERROR: missing Phase 14 issue tracker: ${ISSUE_TRACKER}" | tee -a "${SUMMARY}" >&2
  exit 2
fi

if [[ ! -f "${EXCLUDE_V4}" ]]; then
  echo "ERROR: missing Phase 14 exclude policy: ${EXCLUDE_V4}" | tee -a "${SUMMARY}" >&2
  exit 2
fi

set +e
URG="${URG:-urg}" \
COV_DB_DIR="${COV_DB_DIR}" \
COV_BASE_DB_DIR="${COV_BASE_DB_DIR}" \
COV_DIR="${COV_DIR}" \
LOG_DIR="${LOG_DIR}" \
URG_REPORT_DIR="${URG_REPORT_DIR}" \
URG_MERGED_DB="${URG_MERGED_DB}" \
URG_LOG="${URG_LOG}" \
URG_ALLOW_CONTEXTLESS_MERGE="${URG_ALLOW_CONTEXTLESS_MERGE:-1}" \
URG_VDB_GLOB="${URG_VDB_GLOB:-}" \
bash "${RUN_URG}"
rc=$?
set -e

{
  echo "urg_rc=${rc}"
  if [[ -d "${URG_REPORT_DIR}" ]] && find "${URG_REPORT_DIR}" -type f -print -quit | grep -q .; then
    echo "urg_report_status=present"
  else
    echo "urg_report_status=missing"
    echo "urg_issue=MMU-P14-ISSUE-001"
  fi
} >> "${SUMMARY}"

exit "${rc}"
