#!/usr/bin/env python3
"""Phase 14 closure/signoff gate.

The gate checks artifacts produced by Makefile targets. It does not compile or
run simulation by itself.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


SIGNOFF_IDS = {f"S{i}" for i in range(1, 12)}
ALLOWED_SIGNOFF_STATUS = {"Pass", "Waived", "Accepted"}
WAIVER_STATUS = {"Waived", "Accepted"}
ISSUE_RE = re.compile(r"MMU-P14-ISSUE-\d{3}")
FAIL_PATTERNS = re.compile(
    r"UVM_FATAL\s+@|UVM_ERROR\s+@|Segmentation fault|segmentation violation|SIGSEGV|"
    r"core dumped|VCS internal error|Internal Error|CovErrorException|"
    r"unexpected termination|signal:\s+Aborted|During dumping of toggle coverage data|"
    r"error while loading shared libraries|cannot open shared object file|"
    r"License checkout failed|Unable to checkout|No such feature exists",
    re.IGNORECASE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check Phase 14 closure artifacts")
    parser.add_argument("--list", required=True, help="Phase 14 full regression list")
    parser.add_argument("--seeds", required=True, help="Phase 14 seed set")
    parser.add_argument("--summary", required=True, help="Regression summary path")
    parser.add_argument("--log-dir", required=True, help="Simulation log directory")
    parser.add_argument("--urg-report-dir", required=True, help="Phase 14 URG report directory")
    parser.add_argument("--issue-tracker", required=True, help="Phase 14 issue tracker")
    parser.add_argument("--signoff-matrix", required=True, help="Phase 14 signoff matrix")
    parser.add_argument("--exclude-v4", required=True, help="Phase 14 exclude/waiver file")
    parser.add_argument("--regress-rc", default="0", help="regress_v4_full return code")
    parser.add_argument("--coverage-merge-rc", default="0", help="phase14_coverage_merge return code")
    parser.add_argument("--line-threshold", type=float, default=99.5)
    parser.add_argument("--branch-threshold", type=float, default=99.0)
    parser.add_argument("--toggle-threshold", type=float, default=98.0)
    parser.add_argument("--fsm-threshold", type=float, default=99.0)
    parser.add_argument("--functional-threshold", type=float, default=100.0)
    parser.add_argument("--assertion-threshold", type=float, default=100.0)
    parser.add_argument(
        "--dut-instance",
        default="u_dut",
        help=(
            "DUT top-level instance name in hierarchy.txt whose subtree is the "
            "authoritative code-coverage aggregate used by the gate. Default: u_dut."
        ),
    )
    return parser.parse_args()


def print_result(ok: bool, name: str, detail: str = "") -> None:
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    if detail:
        for line in detail.splitlines():
            print(f"       {line}")


def parse_seeds(raw: str) -> List[str]:
    return [item for item in re.split(r"[,\s]+", raw.strip()) if item]


def strip_comment(raw: str) -> str:
    return raw.split("#", 1)[0].strip()


def load_list(path: Path) -> Tuple[List[str], List[str]]:
    tests: List[str] = []
    bad_lines: List[str] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        tokens = line.split()
        tests.append(tokens[0])
        if any(token == "xfail" or token.startswith("xfail=") for token in tokens[1:]):
            bad_lines.append(raw.strip())
    return tests, bad_lines


def parse_summary(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        data[key.strip()] = value.strip()
    return data


def normalize_words(raw: str) -> str:
    return " ".join(raw.split())


def log_paths(log_dir: Path, tests: Sequence[str], seeds: Sequence[str]) -> List[Path]:
    return [log_dir / f"{test}_{seed}_cov.log" for test in tests for seed in seeds]


def scan_logs(paths: Iterable[Path]) -> Tuple[bool, List[str]]:
    details: List[str] = []
    ok = True
    for path in paths:
        if not path.is_file():
            ok = False
            details.append(f"missing log: {path}")
            if len(details) >= 20:
                break
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        match = FAIL_PATTERNS.search(text)
        if match:
            ok = False
            details.append(f"{path}: fatal/error pattern '{match.group(0)}'")
            if len(details) >= 20:
                break
    return ok, details


def parse_issue_tracker(path: Path) -> Tuple[set, List[str]]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    issue_ids = set(ISSUE_RE.findall(text))
    blocking_open: List[str] = []
    for raw in text.splitlines():
        if not raw.startswith("| MMU-P14-ISSUE-"):
            continue
        cells = [cell.strip() for cell in raw.strip().strip("|").split("|")]
        if len(cells) < 8:
            continue
        issue_id, status, blocking = cells[0], cells[6], cells[7]
        if status == "Open" and blocking == "Yes":
            blocking_open.append(issue_id)
    return issue_ids, blocking_open


def parse_markdown_table(path: Path) -> List[List[str]]:
    rows: List[List[str]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line.startswith("|") or "---" in line:
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        rows.append(cells)
    return rows


def parse_signoff_matrix(path: Path) -> Dict[str, Dict[str, str]]:
    rows = parse_markdown_table(path)
    matrix: Dict[str, Dict[str, str]] = {}
    for cells in rows:
        if not cells or cells[0] not in SIGNOFF_IDS:
            continue
        while len(cells) < 7:
            cells.append("")
        matrix[cells[0]] = {
            "status": cells[2],
            "evidence": cells[3],
            "issue": cells[4],
            "reviewer": cells[5],
            "review": cells[6],
        }
    return matrix


def check_signoff_matrix(matrix: Dict[str, Dict[str, str]], issue_ids: set) -> Tuple[bool, List[str]]:
    details: List[str] = []
    ok = True
    missing = sorted(SIGNOFF_IDS - set(matrix))
    if missing:
        ok = False
        details.append("missing signoff rows: " + ", ".join(missing))
    for signoff_id in sorted(set(matrix)):
        row = matrix[signoff_id]
        status = row["status"]
        if status not in ALLOWED_SIGNOFF_STATUS:
            ok = False
            details.append(f"{signoff_id}: invalid/pending status '{status}'")
        if not row["evidence"] or row["evidence"].upper() == "TBD":
            ok = False
            details.append(f"{signoff_id}: missing evidence")
        if status in WAIVER_STATUS:
            refs = set(ISSUE_RE.findall(row["issue"]))
            if not refs:
                ok = False
                details.append(f"{signoff_id}: {status} requires an issue reference")
            elif not refs <= issue_ids:
                ok = False
                details.append(f"{signoff_id}: unknown issue refs {sorted(refs - issue_ids)}")
            if not row["reviewer"] or row["reviewer"].upper() == "TBD" or row["reviewer"] == "-":
                ok = False
                details.append(f"{signoff_id}: {status} requires second reviewer")
            if row["review"] not in {"Reviewed", "Approved"}:
                ok = False
                details.append(f"{signoff_id}: {status} requires review status Reviewed/Approved")
    return ok, details


def check_exclude_refs(path: Path, issue_ids: set) -> Tuple[bool, List[str]]:
    details: List[str] = []
    ok = True
    for idx, raw in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "coverage exclude" not in stripped:
            continue
        refs = set(ISSUE_RE.findall(stripped))
        if not refs:
            ok = False
            details.append(f"line {idx}: active exclusion missing MMU-P14-ISSUE-NNN")
        elif not refs <= issue_ids:
            ok = False
            details.append(f"line {idx}: unknown issue refs {sorted(refs - issue_ids)}")
    return ok, details


# --- Authoritative URG aggregate coverage parser -----------------------------
#
# The previous implementation scanned every .txt/.html file in the report
# directory and returned the MAXIMUM percentage found near each metric keyword.
# That cherry-picked the single best-covered module and reported it as if it
# were the design aggregate (e.g. it returned 100.00% for every metric while
# URG's own dashboard total was line 95.56% / toggle 70.22%). That made the
# gate a false positive and masked real coverage gaps.
#
# The replacement reads URG's own aggregate rows by aligning the column header
# to the data row:
#   primary   -> the DUT instance subtree (default "u_dut") from hierarchy.txt,
#                i.e. the actual MMU RTL, excluding UVM testbench code.
#   secondary -> URG "Total Coverage Summary" from dashboard.txt (incl. TB),
#                shown as context so reviewers can see both views.
# URG hierarchy/summary column order is fixed: SCORE LINE COND TOGGLE FSM
# BRANCH ASSERT [, NAME|GROUP].
HIER_COLUMN_ORDER = ("SCORE", "LINE", "COND", "TOGGLE", "FSM", "BRANCH", "ASSERT")
METRIC_COLUMN = {
    "line": "LINE",
    "branch": "BRANCH",
    "toggle": "TOGGLE",
    "fsm": "FSM",
    "cond": "COND",
    "assert": "ASSERT",
    "assertion": "ASSERT",
}


def _parse_pct(token: str) -> Optional[float]:
    if not token or token == "--":
        return None
    try:
        value = float(token)
    except ValueError:
        return None
    return value if 0.0 <= value <= 100.0 else None


def _row_to_columns(tokens: Sequence[str], columns: Sequence[str]) -> Dict[str, float]:
    result: Dict[str, float] = {}
    for col, tok in zip(columns, tokens):
        pct = _parse_pct(tok)
        if pct is not None:
            result[col] = pct
    return result


def find_dut_instance_coverage(report_dir: Path, dut_instance: str) -> Dict[str, float]:
    """Return the DUT instance subtree coverage from hierarchy.txt.

    Matches the data row whose trailing instance-name token equals
    ``dut_instance``. URG hierarchy lists short instance names (not full
    paths), so the match is unique. Returns an empty dict if not found.
    """
    hierarchy = report_dir / "hierarchy.txt"
    if not hierarchy.is_file():
        return {}
    for raw in hierarchy.read_text(encoding="utf-8", errors="ignore").splitlines():
        tokens = raw.split()
        if len(tokens) < len(HIER_COLUMN_ORDER) + 1:
            continue
        if tokens[-1] != dut_instance:
            continue
        return _row_to_columns(tokens[: len(HIER_COLUMN_ORDER)], HIER_COLUMN_ORDER)
    return {}


def find_dashboard_total(report_dir: Path) -> Dict[str, float]:
    """Return URG 'Total Coverage Summary' aggregate from dashboard.txt.

    Locates the header row (``SCORE ... GROUP``) that follows the
    'Total Coverage Summary' heading and aligns it to the next numeric row.
    """
    dashboard = report_dir / "dashboard.txt"
    if not dashboard.is_file():
        return {}
    lines = dashboard.read_text(encoding="utf-8", errors="ignore").splitlines()
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == "Total Coverage Summary":
            start = idx
            break
    if start is None:
        return {}
    header: Optional[Sequence[str]] = None
    for line in lines[start + 1 : start + 6]:
        tokens = line.split()
        if not tokens:
            continue
        if header is None:
            if tokens[0] == "SCORE" and "GROUP" in tokens:
                header = tokens
            continue
        if _parse_pct(tokens[0]) is not None and len(tokens) == len(header):
            return _row_to_columns(tokens, header)
    return {}


def resolve_aggregate_coverage(
    report_dir: Path, dut_instance: str
) -> Tuple[Dict[str, float], Dict[str, float], str]:
    """Resolve authoritative aggregate coverage for the gate.

    Returns ``(primary, total_context, source_label)``. ``primary`` is the DUT
    instance subtree when available, otherwise the dashboard total. ``total``
    is always the dashboard total (may be empty if dashboard.txt is absent).
    """
    dut = find_dut_instance_coverage(report_dir, dut_instance)
    total = find_dashboard_total(report_dir)
    if dut:
        return dut, total, f"hierarchy.txt:{dut_instance} (DUT instance subtree)"
    return total, total, "dashboard.txt:Total Coverage Summary"


def _fmt_coverage_row(label: str, values: Dict[str, float], source: str) -> str:
    cols = ("LINE", "BRANCH", "COND", "TOGGLE", "FSM", "ASSERT")
    parts = [
        f"{col}=" + ("--" if values.get(col) is None else f"{values[col]:.2f}%")
        for col in cols
    ]
    return f"{label}: {' '.join(parts)} source={source}"


def matrix_allows(matrix: Dict[str, Dict[str, str]], signoff_id: str) -> bool:
    row = matrix.get(signoff_id, {})
    return row.get("status") in WAIVER_STATUS and bool(ISSUE_RE.findall(row.get("issue", "")))


def check_coverage(
    report_dir: Path,
    matrix: Dict[str, Dict[str, str]],
    thresholds: Dict[str, Tuple[float, str, Sequence[str]]],
    dut_instance: str = "u_dut",
) -> Tuple[bool, List[str]]:
    ok = True
    details: List[str] = []
    report_ready = report_dir.is_dir() and any(report_dir.rglob("*"))
    if not report_ready:
        ok = False
        details.append(f"URG report missing: {report_dir}")
    primary, total, source = (
        resolve_aggregate_coverage(report_dir, dut_instance) if report_ready else ({}, {}, "")
    )
    if primary:
        details.append(_fmt_coverage_row("DUT coverage (authoritative)", primary, source))
    if total:
        details.append(
            _fmt_coverage_row(
                "Total (incl. testbench)",
                total,
                "dashboard.txt:Total Coverage Summary",
            )
        )
    for metric_name, (threshold, signoff_id, _aliases) in thresholds.items():
        column = METRIC_COLUMN.get(metric_name)
        value = primary.get(column) if column else None
        if value is None:
            if matrix_allows(matrix, signoff_id):
                details.append(f"{metric_name}: waived by {signoff_id} (not reported in authoritative aggregate)")
                continue
            ok = False
            details.append(
                f"{metric_name}: not found in authoritative aggregate and {signoff_id} is not waived"
            )
            continue
        total_value = total.get(column)
        total_note = (
            f" (total {total_value:.2f}% incl TB)"
            if total_value is not None and total_value != value
            else ""
        )
        if value >= threshold:
            details.append(f"{metric_name}: {value:.2f}% >= {threshold:.2f}% source={source}{total_note}")
        elif matrix_allows(matrix, signoff_id):
            details.append(f"{metric_name}: {value:.2f}% below {threshold:.2f}% but waived by {signoff_id}{total_note}")
        else:
            ok = False
            details.append(f"{metric_name}: {value:.2f}% below {threshold:.2f}% source={source}{total_note}")
    return ok, details


def main() -> int:
    args = parse_args()
    list_path = Path(args.list)
    summary_path = Path(args.summary)
    log_dir = Path(args.log_dir)
    report_dir = Path(args.urg_report_dir)
    issue_tracker = Path(args.issue_tracker)
    signoff_matrix = Path(args.signoff_matrix)
    exclude_v4 = Path(args.exclude_v4)

    results: List[bool] = []

    print("========================================")
    print("PHASE14 CLOSURE EXIT CHECK")
    print("========================================")
    print(f"list              : {list_path}")
    print(f"seeds             : {args.seeds}")
    print(f"summary           : {summary_path}")
    print(f"urg_report        : {report_dir}")
    print(f"issue_tracker     : {issue_tracker}")
    print(f"signoff_matrix    : {signoff_matrix}")
    print(f"exclude_v4        : {exclude_v4}")
    print(f"regress_rc        : {args.regress_rc}")
    print(f"coverage_merge_rc : {args.coverage_merge_rc}")
    print()

    required_files = [list_path, summary_path, issue_tracker, signoff_matrix, exclude_v4]
    files_ok = all(path.is_file() for path in required_files)
    print_result(files_ok, "required Phase 14 artifact files exist", "\n".join(str(path) for path in required_files))
    results.append(files_ok)
    if not files_ok:
        print("PHASE14_EXIT_CHECK: FAIL")
        return 1

    seeds = parse_seeds(args.seeds)
    tests, xfail_lines = load_list(list_path)
    list_ok = len(seeds) == 5 and bool(tests) and not xfail_lines and len(tests) == len(set(tests))
    list_detail = f"tests={len(tests)} seeds={len(seeds)} duplicates={len(tests) - len(set(tests))}"
    if xfail_lines:
        list_detail += "\nxfail lines:\n" + "\n".join(xfail_lines[:10])
    print_result(list_ok, "full list is 5-seed runnable with no xfail/duplicates", list_detail)
    results.append(list_ok)

    summary = parse_summary(summary_path)
    expected_total = len(tests) * len(seeds)
    regress_ok = (
        args.regress_rc == "0"
        and summary.get("mode") == "run_cov"
        and normalize_words(summary.get("seeds", "")) == normalize_words(args.seeds)
        and summary.get("total_runs") == str(expected_total)
        and summary.get("failed_runs") == "0"
        and summary.get("xpass_unexpected_runs") == "0"
        and summary.get("pass_rate") == "1.0000"
    )
    print_result(
        regress_ok,
        "full regression summary is 100% PASS",
        (
            f"expected_total={expected_total} mode={summary.get('mode')} "
            f"total={summary.get('total_runs')} failed={summary.get('failed_runs')} "
            f"xpass={summary.get('xpass_unexpected_runs')} pass_rate={summary.get('pass_rate')}"
        ),
    )
    results.append(regress_ok)

    logs_ok, log_details = scan_logs(log_paths(log_dir, tests, seeds))
    print_result(logs_ok, "full regression logs are present and clean", "\n".join(log_details[:20]))
    results.append(logs_ok)

    issue_ids, blocking_open = parse_issue_tracker(issue_tracker)
    tracker_ok = bool(issue_ids) and not blocking_open
    print_result(tracker_ok, "issue tracker has no unconditional blocking Open item", "\n".join(blocking_open))
    results.append(tracker_ok)

    matrix = parse_signoff_matrix(signoff_matrix)
    matrix_ok, matrix_details = check_signoff_matrix(matrix, issue_ids)
    print_result(matrix_ok, "signoff matrix has final statuses and required review", "\n".join(matrix_details[:30]))
    results.append(matrix_ok)

    exclude_ok, exclude_details = check_exclude_refs(exclude_v4, issue_ids)
    print_result(exclude_ok, "exclude_v4 active exclusions reference tracker IDs", "\n".join(exclude_details[:20]))
    results.append(exclude_ok)

    thresholds = {
        "line": (args.line_threshold, "S3", ("line", "line coverage")),
        "branch": (args.branch_threshold, "S3", ("branch", "branch coverage")),
        "toggle": (args.toggle_threshold, "S3", ("toggle", "tgl", "toggle coverage")),
        "fsm": (args.fsm_threshold, "S3", ("fsm", "fsm coverage")),
        "assertion": (args.assertion_threshold, "S5", ("assert", "assertion", "assertion coverage")),
    }
    coverage_ok, coverage_details = check_coverage(report_dir, matrix, thresholds, args.dut_instance)
    if args.coverage_merge_rc != "0" and not (matrix_allows(matrix, "S3") or matrix_allows(matrix, "S4") or matrix_allows(matrix, "S5")):
        coverage_ok = False
        coverage_details.insert(0, f"coverage merge returned rc={args.coverage_merge_rc}")
    print_result(coverage_ok, "VerificationPlan section 9 coverage criteria are met or reviewed/waived", "\n".join(coverage_details[:30]))
    results.append(coverage_ok)

    print()
    print("========================================")
    if all(results):
        print("PHASE14_EXIT_CHECK: PASS")
        print("========================================")
        return 0

    print(f"PHASE14_EXIT_CHECK: FAIL ({results.count(False)} failed criterion/criteria)")
    print("========================================")
    return 1


if __name__ == "__main__":
    sys.exit(main())
