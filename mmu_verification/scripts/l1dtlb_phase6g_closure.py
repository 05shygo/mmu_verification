#!/usr/bin/env python3
"""Phase 6G L1DTLB closure evidence checker.

This checker is intentionally stricter than a regression PASS summary.  It
requires clean UVM status, no unwaived scenario gates, required final-phase
scoreboard reports, nonzero target counters, and nonzero target SVA cover
matches for every manifest row.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


PROJECT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = PROJECT_DIR / "simu" / "l1dtlb_phase6g_evidence_manifest.tsv"
DEFAULT_LOG_DIR = PROJECT_DIR / "output" / "logs"
DEFAULT_REPORT = PROJECT_DIR / "output" / "regression" / "l1dtlb_phase6g_closure" / "closure_report.md"
DEFAULT_COMPILE_LOG = DEFAULT_LOG_DIR / "comp_fast.log"

BAD_LOG_PATTERNS = [
    re.compile(r"\bSCENARIO_GATE\b"),
    re.compile(r"\bUVM_ERROR\b(?!\s*:)"),
    re.compile(r"\bUVM_FATAL\b(?!\s*:)"),
    re.compile(r"\bASSERT(?:ION)?\b.*\b(?:FAIL|FAILED|failure)\b", re.IGNORECASE),
    re.compile(r"\bfailed at\b", re.IGNORECASE),
    re.compile(r"\bTEST FAILED\b", re.IGNORECASE),
    re.compile(r"\bCovErrorException\b"),
    re.compile(r"\bunexpected termination\b", re.IGNORECASE),
]

COMPILE_BAD_PATTERNS = [
    re.compile(r"\bError-"),
    re.compile(r"\bFatal:"),
    re.compile(r"\bUVM_ERROR\b"),
    re.compile(r"\bUVM_FATAL\b"),
    re.compile(r"\bundefined reference\b", re.IGNORECASE),
    re.compile(r"\bcompilation aborted\b", re.IGNORECASE),
]


class ManifestRow:
    def __init__(
        self,
        case_id: str,
        phase: str,
        test: str,
        seed: str,
        status: str,
        accepted_warnings: int,
        required_reports: List[str],
        required_counters: List[str],
        required_covers: List[str],
        related_ids: List[str],
        notes: str,
    ) -> None:
        self.case_id = case_id
        self.phase = phase
        self.test = test
        self.seed = seed
        self.status = status
        self.accepted_warnings = accepted_warnings
        self.required_reports = required_reports
        self.required_counters = required_counters
        self.required_covers = required_covers
        self.related_ids = related_ids
        self.notes = notes


class RowResult:
    def __init__(self, row: ManifestRow, log_path: Path) -> None:
        self.row = row
        self.log_path = log_path
        self.ok = True
        self.failures: List[str] = []
        self.warnings: List[str] = []
        self.report_hits: List[str] = []
        self.counter_hits: List[str] = []
        self.cover_hits: List[str] = []

    def fail(self, msg: str) -> None:
        self.ok = False
        self.failures.append(msg)


def parse_list(raw: str) -> List[str]:
    raw = raw.strip()
    if not raw:
        return []
    return [item.strip() for item in raw.split(";") if item.strip()]


def parse_manifest(path: Path) -> List[ManifestRow]:
    rows: List[ManifestRow] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for lineno, raw in enumerate(handle, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            fields = line.split("|")
            if len(fields) != 11:
                raise ValueError(f"{path}:{lineno}: expected 11 pipe-delimited fields, got {len(fields)}")
            try:
                accepted_warnings = int(fields[5])
            except ValueError as exc:
                raise ValueError(f"{path}:{lineno}: accepted_warnings is not an integer: {fields[5]!r}") from exc
            rows.append(
                ManifestRow(
                    case_id=fields[0].strip(),
                    phase=fields[1].strip(),
                    test=fields[2].strip(),
                    seed=fields[3].strip(),
                    status=fields[4].strip(),
                    accepted_warnings=accepted_warnings,
                    required_reports=parse_list(fields[6]),
                    required_counters=parse_list(fields[7]),
                    required_covers=parse_list(fields[8]),
                    related_ids=parse_list(fields[9].replace(",", ";")),
                    notes=fields[10].strip(),
                )
            )
    if not rows:
        raise ValueError(f"manifest has no evidence rows: {path}")
    return rows


def extract_uvm_counts(lines: Iterable[str]) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    pattern = re.compile(r"^(UVM_WARNING|UVM_ERROR|UVM_FATAL)\s*:\s*(\d+)\s*$")
    for line in lines:
        match = pattern.search(line.strip())
        if match:
            counts[match.group(1)] = int(match.group(2))
    return counts


def find_report_line(lines: List[str], report: str) -> Optional[str]:
    needle_a = f"::{report}]"
    needle_b = f"[{report}]"
    for line in reversed(lines):
        if "status=" not in line:
            continue
        if needle_a in line or needle_b in line:
            return line
    return None


def parse_counters(line: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for key, raw_value in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)=(-?\d+)\b", line):
        out[key] = int(raw_value)
    return out


def eval_counter(expr: str, report_lines: Dict[str, str]) -> Tuple[bool, str]:
    match = re.fullmatch(r"([A-Za-z0-9_]+):([A-Za-z0-9_]+)(>=|<=|>|<|=)(-?\d+)", expr)
    if not match:
        return False, f"bad counter expression: {expr}"
    report, field, op, raw_expected = match.groups()
    expected = int(raw_expected)
    line = report_lines.get(report)
    if line is None:
        return False, f"missing report for counter: {expr}"
    counters = parse_counters(line)
    if field not in counters:
        return False, f"missing counter {field} in {report}"
    actual = counters[field]
    ok = {
        ">": actual > expected,
        "<": actual < expected,
        ">=": actual >= expected,
        "<=": actual <= expected,
        "=": actual == expected,
    }[op]
    detail = f"{expr} actual={actual}"
    return ok, detail


def cover_match_count(lines: List[str], cover_name: str) -> int:
    total = 0
    for line in lines:
        if cover_name not in line:
            continue
        match = re.search(r"\b(\d+)\s+match\b", line)
        if match:
            total += int(match.group(1))
    return total


def eval_cover(expr: str, lines: List[str]) -> Tuple[bool, str]:
    match = re.fullmatch(r"([A-Za-z0-9_]+)(>=|<=|>|<|=)(-?\d+)", expr)
    if not match:
        return False, f"bad cover expression: {expr}"
    cover, op, raw_expected = match.groups()
    expected = int(raw_expected)
    actual = cover_match_count(lines, cover)
    ok = {
        ">": actual > expected,
        "<": actual < expected,
        ">=": actual >= expected,
        "<=": actual <= expected,
        "=": actual == expected,
    }[op]
    return ok, f"{expr} actual={actual}"


def check_bad_patterns(lines: List[str]) -> List[str]:
    hits: List[str] = []
    for lineno, line in enumerate(lines, 1):
        if line.startswith("UVM_ERROR :") or line.startswith("UVM_FATAL :"):
            continue
        for pattern in BAD_LOG_PATTERNS:
            if pattern.search(line):
                hits.append(f"{lineno}:{line.strip()}")
                break
        if len(hits) >= 12:
            break
    return hits


def check_row(row: ManifestRow, log_dir: Path) -> RowResult:
    log_path = log_dir / f"{row.test}_{row.seed}.log"
    result = RowResult(row=row, log_path=log_path)
    if not log_path.is_file():
        result.fail(f"missing log: {log_path}")
        return result

    lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    counts = extract_uvm_counts(lines)
    for key in ("UVM_WARNING", "UVM_ERROR", "UVM_FATAL"):
        if key not in counts:
            result.fail(f"missing final UVM count for {key}")
    if counts.get("UVM_ERROR", 1) != 0:
        result.fail(f"UVM_ERROR={counts.get('UVM_ERROR')}")
    if counts.get("UVM_FATAL", 1) != 0:
        result.fail(f"UVM_FATAL={counts.get('UVM_FATAL')}")
    warning_count = counts.get("UVM_WARNING", 999999)
    if warning_count > row.accepted_warnings:
        result.fail(f"UVM_WARNING={warning_count} exceeds accepted {row.accepted_warnings}")
    elif warning_count:
        result.warnings.append(f"accepted UVM_WARNING={warning_count}")

    bad_hits = check_bad_patterns(lines)
    if bad_hits:
        result.fail("unaccepted bad log pattern(s): " + " | ".join(bad_hits))

    report_lines: Dict[str, str] = {}
    for report in row.required_reports:
        line = find_report_line(lines, report)
        if line is None:
            result.fail(f"missing final report {report}")
        else:
            report_lines[report] = line
            result.report_hits.append(report)

    for expr in row.required_counters:
        ok, detail = eval_counter(expr, report_lines)
        if ok:
            result.counter_hits.append(detail)
        else:
            result.fail(detail)

    for expr in row.required_covers:
        ok, detail = eval_cover(expr, lines)
        if ok:
            result.cover_hits.append(detail)
        else:
            result.fail(detail)

    return result


def check_compile_log(path: Path) -> Tuple[bool, List[str]]:
    if not path.is_file():
        return False, [f"missing compile log: {path}"]
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    hits: List[str] = []
    for lineno, line in enumerate(lines, 1):
        for pattern in COMPILE_BAD_PATTERNS:
            if pattern.search(line):
                hits.append(f"{lineno}:{line.strip()}")
                break
        if len(hits) >= 12:
            break
    return not hits, hits


def write_report(
    path: Path,
    manifest: Path,
    log_dir: Path,
    compile_log: Optional[Path],
    compile_ok: Optional[bool],
    compile_issues: List[str],
    results: List[RowResult],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    total = len(results)
    passed = sum(1 for item in results if item.ok)
    future = sum(1 for item in results if item.row.status == "future_formal")
    failed = total - passed
    closure = "PASS" if failed == 0 and compile_ok is not False else "FAIL"

    with path.open("w", encoding="utf-8") as handle:
        handle.write("# L1DTLB Phase 6G Closure Report\n\n")
        handle.write(f"- status: {closure}\n")
        handle.write(f"- manifest: `{manifest}`\n")
        handle.write(f"- log_dir: `{log_dir}`\n")
        if compile_log is not None:
            handle.write(f"- compile_log: `{compile_log}`\n")
            handle.write(f"- compile_log_status: {'PASS' if compile_ok else 'FAIL'}\n")
        handle.write(f"- evidence_rows: {total}\n")
        handle.write(f"- passed_rows: {passed}\n")
        handle.write(f"- failed_rows: {failed}\n")
        handle.write(f"- future_formal_rows: {future}\n\n")

        if compile_issues:
            handle.write("## Compile Issues\n\n")
            for issue in compile_issues:
                handle.write(f"- {issue}\n")
            handle.write("\n")

        handle.write("## Evidence Matrix\n\n")
        handle.write("| Status | Case | Phase | Test | Seed | Disposition | Related IDs | Notes |\n")
        handle.write("| --- | --- | --- | --- | --- | --- | --- | --- |\n")
        for item in results:
            status = "PASS" if item.ok else "FAIL"
            related = ", ".join(item.row.related_ids)
            notes = item.row.notes.replace("|", "/")
            handle.write(
                f"| {status} | `{item.row.case_id}` | {item.row.phase} | `{item.row.test}` | "
                f"`{item.row.seed}` | {item.row.status} | {related} | {notes} |\n"
            )
        handle.write("\n")

        for item in results:
            handle.write(f"## {item.row.case_id}\n\n")
            handle.write(f"- log: `{item.log_path}`\n")
            handle.write(f"- status: {'PASS' if item.ok else 'FAIL'}\n")
            if item.warnings:
                handle.write(f"- accepted_warnings: {'; '.join(item.warnings)}\n")
            if item.report_hits:
                handle.write(f"- reports: {', '.join(item.report_hits)}\n")
            if item.counter_hits:
                handle.write("- counters:\n")
                for hit in item.counter_hits:
                    handle.write(f"  - `{hit}`\n")
            if item.cover_hits:
                handle.write("- covers:\n")
                for hit in item.cover_hits:
                    handle.write(f"  - `{hit}`\n")
            if item.failures:
                handle.write("- failures:\n")
                for failure in item.failures:
                    handle.write(f"  - {failure}\n")
            handle.write("\n")


def resolve_path(raw: str) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        path = PROJECT_DIR / path
    return path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check L1DTLB Phase 6G closure evidence logs")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST), help="Phase6G evidence manifest")
    parser.add_argument("--log-dir", default=str(DEFAULT_LOG_DIR), help="Simulation log directory")
    parser.add_argument("--report", default=str(DEFAULT_REPORT), help="Markdown closure report output")
    parser.add_argument("--compile-log", default=str(DEFAULT_COMPILE_LOG), help="Compile log to sanity-check")
    parser.add_argument("--skip-compile-log", action="store_true", help="Do not check compile log")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    manifest = resolve_path(args.manifest)
    log_dir = resolve_path(args.log_dir)
    report = resolve_path(args.report)
    compile_log = None if args.skip_compile_log else resolve_path(args.compile_log)

    try:
        rows = parse_manifest(manifest)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    compile_ok: Optional[bool] = None
    compile_issues: List[str] = []
    if compile_log is not None:
        compile_ok, compile_issues = check_compile_log(compile_log)

    results = [check_row(row, log_dir) for row in rows]
    write_report(report, manifest, log_dir, compile_log, compile_ok, compile_issues, results)

    total = len(results)
    passed = sum(1 for item in results if item.ok)
    failed = total - passed
    print(f"L1DTLB Phase6G closure: PASS={passed} FAIL={failed} TOTAL={total}")
    print(f"Report: {report}")
    if compile_ok is False:
        print(f"Compile log check failed: {compile_log}", file=sys.stderr)
    for item in results:
        if not item.ok:
            print(f"FAIL {item.row.case_id}: {'; '.join(item.failures)}", file=sys.stderr)
    return 0 if failed == 0 and compile_ok is not False else 1


if __name__ == "__main__":
    sys.exit(main())
