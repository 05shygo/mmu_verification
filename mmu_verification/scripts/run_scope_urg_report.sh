#!/usr/bin/env bash
set -u

URG_BIN="urg"
INPUT_VDB=""
BASE_VDB=""
REPORT_DIR=""
LOG_FILE=""
METRICS=""
XML_FALLBACK="${SCOPE_XML_FALLBACK:-auto}"
FALLBACK_SCRIPT=""
FALLBACK_SCOPE=""
PYTHON_BIN="${PYTHON:-python3}"
HIER_ARGS=()

usage() {
  cat <<'USAGE'
Usage: run_scope_urg_report.sh --input-vdb VDB --report-dir DIR --log LOG [options]

Options:
  --urg BIN             URG executable, default: urg
  --base-vdb VDB        Optional compile-context VDB
  --metrics METRICS     URG metric string, for example line+cond+fsm+tgl+branch+assert
  --hier PATH           Hierarchy scope, may be repeated
  --fallback-script PY   XML fallback report generator
  --fallback-scope NAME  Scope name passed to the fallback generator
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --urg)
      URG_BIN="$2"
      shift 2
      ;;
    --input-vdb)
      INPUT_VDB="$2"
      shift 2
      ;;
    --base-vdb)
      BASE_VDB="$2"
      shift 2
      ;;
    --report-dir)
      REPORT_DIR="$2"
      shift 2
      ;;
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    --metrics)
      METRICS="$2"
      shift 2
      ;;
    --hier)
      HIER_ARGS+=("-hier" "$2")
      shift 2
      ;;
    --fallback-script)
      FALLBACK_SCRIPT="$2"
      shift 2
      ;;
    --fallback-scope)
      FALLBACK_SCOPE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

has_files() {
  [[ -d "$1" ]] && find "$1" -type f -print -quit 2>/dev/null | grep -q .
}

require_arg() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "ERROR: missing required argument ${name}" >&2
    usage >&2
    exit 2
  fi
}

quote_cmd() {
  local out=""
  local arg
  for arg in "$@"; do
    printf -v out '%s %q' "$out" "$arg"
  done
  printf '%s\n' "${out# }"
}

run_attempt() {
  local label="$1"
  shift
  local rc=1

  rm -rf "$REPORT_DIR"
  {
    echo ""
    echo "=== URG scope attempt: ${label} ==="
    echo "Command: $(quote_cmd "$@")"
  } >> "$LOG_FILE"

  "$@" >> "$LOG_FILE" 2>&1
  rc=$?

  {
    echo "=== URG scope attempt '${label}' rc=${rc} ==="
    if has_files "$REPORT_DIR"; then
      echo "Report ready: ${REPORT_DIR}"
    else
      echo "Report missing or empty: ${REPORT_DIR}"
    fi
  } >> "$LOG_FILE"

  if [[ "$rc" -eq 0 ]] && has_files "$REPORT_DIR"; then
    return 0
  fi
  return "$rc"
}

try_xml_fallback_report() {
  local rc=1

  [[ "$XML_FALLBACK" == "auto" ]] || return 1
  [[ -n "$FALLBACK_SCRIPT" ]] || return 1
  [[ -n "$FALLBACK_SCOPE" ]] || return 1
  [[ -f "$FALLBACK_SCRIPT" ]] || return 1

  rm -rf "$REPORT_DIR"
  {
    echo ""
    echo "=== Scope XML fallback report ==="
    echo "WARNING: all official URG scoped report attempts failed; generating XML-derived fallback."
    echo "Command: $(quote_cmd "$PYTHON_BIN" "$FALLBACK_SCRIPT" --vdb "$INPUT_VDB" --scope "$FALLBACK_SCOPE" --report-dir "$REPORT_DIR")"
  } >> "$LOG_FILE"

  "$PYTHON_BIN" "$FALLBACK_SCRIPT" \
    --vdb "$INPUT_VDB" \
    --scope "$FALLBACK_SCOPE" \
    --report-dir "$REPORT_DIR" >> "$LOG_FILE" 2>&1
  rc=$?

  {
    echo "=== Scope XML fallback rc=${rc} ==="
    if has_files "$REPORT_DIR"; then
      echo "Fallback report ready: ${REPORT_DIR}"
    else
      echo "Fallback report missing or empty: ${REPORT_DIR}"
    fi
  } >> "$LOG_FILE"

  if [[ "$rc" -eq 0 ]] && has_files "$REPORT_DIR"; then
    return 0
  fi
  return "$rc"
}

require_arg "--input-vdb" "$INPUT_VDB"
require_arg "--report-dir" "$REPORT_DIR"
require_arg "--log" "$LOG_FILE"

if ! has_files "$INPUT_VDB"; then
  echo "ERROR: input VDB missing or empty: ${INPUT_VDB}" >&2
  exit 2
fi

mkdir -p "$(dirname "$REPORT_DIR")" "$(dirname "$LOG_FILE")" || exit 2
: > "$LOG_FILE" || exit 2

METRIC_ARGS=()
if [[ -n "$METRICS" ]]; then
  METRIC_ARGS=("-metric" "$METRICS")
fi

last_rc=1

run_attempt "scope direct report" \
  "$URG_BIN" -full64 -dir "$INPUT_VDB" \
  "${METRIC_ARGS[@]}" "${HIER_ARGS[@]}" \
  -format both -report "$REPORT_DIR"
last_rc=$?
if [[ "$last_rc" -eq 0 ]]; then
  exit 0
fi

if has_files "$BASE_VDB"; then
  run_attempt "compile-context + scope report (-dir list)" \
    "$URG_BIN" -full64 -dir "$BASE_VDB" "$INPUT_VDB" \
    "${METRIC_ARGS[@]}" "${HIER_ARGS[@]}" \
    -format both -report "$REPORT_DIR"
  last_rc=$?
  if [[ "$last_rc" -eq 0 ]]; then
    exit 0
  fi

  run_attempt "compile-context + scope report (-dir repeated)" \
    "$URG_BIN" -full64 -dir "$BASE_VDB" -dir "$INPUT_VDB" \
    "${METRIC_ARGS[@]}" "${HIER_ARGS[@]}" \
    -format both -report "$REPORT_DIR"
  last_rc=$?
  if [[ "$last_rc" -eq 0 ]]; then
    exit 0
  fi
else
  {
    echo ""
    echo "=== compile-context attempts skipped ==="
    echo "Base VDB missing or empty: ${BASE_VDB}"
  } >> "$LOG_FILE"
fi

if try_xml_fallback_report; then
  echo "WARNING: URG scoped report failed; XML fallback report generated: ${REPORT_DIR}" >&2
  echo "         See ${LOG_FILE} for URG failure evidence and fallback details." >&2
  exit 0
fi

echo "ERROR: URG could not generate scoped report: ${REPORT_DIR}" >&2
echo "       See ${LOG_FILE}" >&2
exit "$last_rc"
