#!/usr/bin/env python3

import argparse
import html
import re
import sys
from pathlib import Path
from typing import List, Optional, Sequence, Tuple


PREFERRED_FILES = {
    "groups.txt": 0,
    "groups.html": 1,
    "dashboard.txt": 2,
    "dashboard.html": 3,
    "index.html": 4,
}
TEXT_SUFFIXES = {".txt", ".html", ".htm"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gate Phase 12 covergroup percentages from an URG text/html report"
    )
    parser.add_argument("--report-dir", required=True, help="URG report directory")
    parser.add_argument(
        "--threshold",
        required=True,
        type=float,
        help="Minimum required percentage for every group",
    )
    parser.add_argument(
        "--groups",
        nargs="+",
        required=True,
        help="Covergroup names to check",
    )
    return parser.parse_args()


def iter_report_files(report_dir: Path) -> List[Path]:
    files = [
        path
        for path in report_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES
    ]

    def key(path: Path) -> Tuple[int, int, str]:
        preferred_rank = PREFERRED_FILES.get(path.name.lower(), 99)
        return preferred_rank, len(path.parts), str(path)

    return sorted(files, key=key)


def sanitize_text(raw_text: str) -> str:
    unescaped = html.unescape(raw_text)
    no_tags = re.sub(r"<[^>]+>", " ", unescaped)
    return re.sub(r"\s+", " ", no_tags)


def parse_score_value(text: str) -> Optional[float]:
    match = re.search(r"(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])", text)
    if match is None:
        return None

    try:
        value = float(match.group(1))
    except ValueError:
        return None

    if 0.0 <= value <= 100.0:
        return value
    return None


def candidate_urg_table_scores(raw_text: str, group_name: str) -> List[float]:
    """Extract SCORE from URG groups.html table rows.

    URG group-list HTML reports place SCORE in the second <td> of the group row
    and do not append a literal percent sign. Parsing the row avoids confusing
    the bottom color legend (0%, 10%, ..., 100%) with the covergroup score.
    """
    row_re = re.compile(r"<tr\b[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
    cell_re = re.compile(r"<td\b[^>]*>(.*?)</td>", re.IGNORECASE | re.DOTALL)

    values: List[float] = []
    for row_match in row_re.finditer(raw_text):
        row = row_match.group(1)
        if group_name not in html.unescape(row):
            continue

        cells = [sanitize_text(cell) for cell in cell_re.findall(row)]
        if len(cells) < 2 or group_name not in cells[0]:
            continue

        value = parse_score_value(cells[1])
        if value is not None:
            values.append(value)

    return values


def candidate_text_row_scores(text: str, group_name: str) -> List[float]:
    """Extract SCORE from text rows where the first number after the name is score."""
    values: List[float] = []
    for raw_line in text.splitlines():
        line = sanitize_text(raw_line)
        if group_name not in line:
            continue

        tail = line.split(group_name, 1)[1]
        value = parse_score_value(tail)
        if value is not None:
            values.append(value)

    return values


def candidate_percentages(text: str, group_name: str) -> List[float]:
    escaped = re.escape(group_name)
    patterns = (
        re.compile(escaped + r"[\s\S]{0,240}?(\d+(?:\.\d+)?)\s*%", re.IGNORECASE),
        re.compile(r"(\d+(?:\.\d+)?)\s*%[\s\S]{0,240}?" + escaped, re.IGNORECASE),
    )

    values: List[float] = []
    for pattern in patterns:
        for match in pattern.findall(text):
            try:
                value = float(match)
            except ValueError:
                continue
            if 0.0 <= value <= 100.0:
                values.append(value)
    return values


def locate_group_percentage(report_dir: Path, group_name: str) -> Optional[Tuple[float, Path]]:
    for path in iter_report_files(report_dir):
        raw_text = path.read_text(encoding="utf-8", errors="ignore")
        sanitized = sanitize_text(raw_text)

        values = candidate_urg_table_scores(raw_text, group_name)
        if not values:
            values = candidate_text_row_scores(raw_text, group_name)
        if not values:
            values = candidate_text_row_scores(sanitized, group_name)
        if not values:
            values = candidate_percentages(raw_text, group_name)
        if not values:
            values = candidate_percentages(sanitized, group_name)
        if values:
            return max(values), path
    return None


def gate_groups(report_dir: Path, threshold: float, groups: Sequence[str]) -> int:
    print(f"Phase 12 coverage gate: report_dir={report_dir} threshold={threshold:.2f}%")

    missing: List[str] = []
    failed: List[str] = []

    for group_name in groups:
        located = locate_group_percentage(report_dir, group_name)
        if located is None:
            print(f"[FAIL] {group_name}: not found in {report_dir}")
            missing.append(group_name)
            continue

        percentage, source_path = located
        status = "PASS" if percentage >= threshold else "FAIL"
        print(
            f"[{status}] {group_name}: {percentage:.2f}% "
            f"(threshold {threshold:.2f}%, source {source_path})"
        )
        if percentage < threshold:
            failed.append(group_name)

    if missing or failed:
        print(
            "PHASE12_COV_GATE: FAIL "
            f"(missing={len(missing)} below_threshold={len(failed)})"
        )
        return 1

    print("PHASE12_COV_GATE: PASS")
    return 0


def main() -> int:
    args = parse_args()
    report_dir = Path(args.report_dir).resolve()

    if not report_dir.is_dir():
        print(f"ERROR: report directory not found: {report_dir}", file=sys.stderr)
        return 2

    return gate_groups(report_dir, args.threshold, args.groups)


if __name__ == "__main__":
    sys.exit(main())
