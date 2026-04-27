#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  phase11_scan_regression_logs.sh <list_file> "<seed0 seed1 ...>" <log_dir> [plain|cov]
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 2
fi

LIST_FILE="$1"
SEED_RAW="$2"
LOG_DIR="$3"
MODE="${4:-plain}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECKER="${PROJECT_DIR}/scripts/check_sim_status.sh"
SCAN_LOGS="${PROJECT_DIR}/scripts/scan_logs.pl"

if [[ ! -f "${LIST_FILE}" ]]; then
  echo "ERROR: list file not found: ${LIST_FILE}" >&2
  exit 2
fi

read -r -a SEEDS <<< "${SEED_RAW}"
if [[ ${#SEEDS[@]} -eq 0 ]]; then
  echo "ERROR: empty seed set" >&2
  exit 2
fi

mapfile -t TESTS < <(sed -E 's/[[:space:]]*#.*$//' "${LIST_FILE}" | awk 'NF { print $1 }')
if [[ ${#TESTS[@]} -eq 0 ]]; then
  echo "ERROR: no runnable tests found in ${LIST_FILE}" >&2
  exit 2
fi

LOGS=()
for test_name in "${TESTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    if [[ "${MODE}" == "cov" ]]; then
      LOGS+=("${LOG_DIR}/${test_name}_${seed}_cov.log")
    else
      LOGS+=("${LOG_DIR}/${test_name}_${seed}.log")
    fi
  done
done

if command -v perl >/dev/null 2>&1 && [[ -f "${SCAN_LOGS}" ]]; then
  if perl -MText::Table -e 1 >/dev/null 2>&1; then
    perl "${SCAN_LOGS}" -nopreresetwarn "${LOGS[@]}"
    exit $?
  fi
  echo "[phase11_scan_regression_logs] WARN: perl Text::Table missing; fallback to check_sim_status.sh"
else
  echo "[phase11_scan_regression_logs] WARN: perl or scan_logs.pl unavailable; fallback to check_sim_status.sh"
fi

MMU_LOG_MAX_MATCHES="${MMU_LOG_MAX_MATCHES:-20}" bash "${CHECKER}" "${LOGS[@]}"
