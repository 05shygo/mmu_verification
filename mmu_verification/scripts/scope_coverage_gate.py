#!/usr/bin/env python3
"""Check URG coverage percentages for a named signoff scope."""

import argparse
import html
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


METRIC_ALIASES: Dict[str, Sequence[str]] = {
    "line": ("line", "line coverage"),
    "branch": ("branch", "branch coverage"),
    "toggle": ("toggle", "tgl", "toggle coverage"),
    "fsm": ("fsm", "fsm coverage"),
    "functional": ("functional", "group", "covergroup"),
    "assertion": ("assert", "assertion", "assertion coverage"),
}


def sanitize(raw: str) -> str:
    no_tags = re.sub(r"<[^>]+>", " ", html.unescape(raw))
    lines = [re.sub(r"[ \t\r\f\v]+", " ", line).strip() for line in no_tags.splitlines()]
    return "\n".join(line for line in lines if line)


def iter_report_texts(report_dir: Path) -> Iterable[Tuple[Path, str]]:
    for path in sorted(report_dir.rglob("*")):
        if path.is_file() and path.suffix.lower() in {".txt", ".html", ".htm"}:
            yield path, sanitize(path.read_text(encoding="utf-8", errors="ignore"))


def find_metric(report_dir: Path, aliases: Sequence[str]) -> Optional[Tuple[float, Path]]:
    best: Optional[Tuple[float, Path]] = None
    alias_re = "|".join(re.escape(alias) for alias in aliases)
    patterns = (
        re.compile(rf"\b(?:{alias_re})\b[^\d%]{{0,80}}(\d+(?:\.\d+)?)\s*%", re.IGNORECASE),
        re.compile(rf"\b(?:{alias_re})\b[^\d%]{{0,80}}(\d+(?:\.\d+)?)(?![\d.])", re.IGNORECASE),
        re.compile(rf"(\d+(?:\.\d+)?)\s*%[^\n]{{0,80}}\b(?:{alias_re})\b", re.IGNORECASE),
    )
    for path, text in iter_report_texts(report_dir):
        for line in text.splitlines():
            for pattern in patterns:
                for match in pattern.findall(line):
                    value = float(match)
                    if 0.0 <= value <= 100.0 and (best is None or value > best[0]):
                        best = (value, path)
    return best


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check scope-specific URG coverage thresholds")
    parser.add_argument("--scope-name", required=True)
    parser.add_argument("--urg-report-dir", required=True)
    parser.add_argument("--line-threshold", type=float, default=99.5)
    parser.add_argument("--branch-threshold", type=float, default=99.0)
    parser.add_argument("--toggle-threshold", type=float, default=98.0)
    parser.add_argument("--fsm-threshold", type=float, default=99.0)
    parser.add_argument("--functional-threshold", type=float, default=100.0)
    parser.add_argument("--assertion-threshold", type=float, default=100.0)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    report_dir = Path(args.urg_report_dir)
    thresholds = {
        "line": args.line_threshold,
        "branch": args.branch_threshold,
        "toggle": args.toggle_threshold,
        "fsm": args.fsm_threshold,
        "functional": args.functional_threshold,
        "assertion": args.assertion_threshold,
    }

    details: List[str] = []
    ok = True
    report_ready = report_dir.is_dir() and any(report_dir.rglob("*"))
    if not report_ready:
        ok = False
        details.append(f"URG report missing or empty: {report_dir}")

    for metric, threshold in thresholds.items():
        located = find_metric(report_dir, METRIC_ALIASES[metric]) if report_ready else None
        if located is None:
            ok = False
            details.append(f"{metric}: missing")
            continue
        value, source = located
        status = "PASS" if value >= threshold else "FAIL"
        if status == "FAIL":
            ok = False
        details.append(f"{metric}: {status} {value:.2f}% threshold={threshold:.2f}% source={source}")

    status = "PASS" if ok else "FAIL"
    print(f"SCOPE_COVERAGE_RESULT scope={args.scope_name} status={status} report={report_dir}")
    for detail in details:
        print(f"  {detail}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
