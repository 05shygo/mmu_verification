#!/usr/bin/env python3
"""Check URG coverage percentages for a named signoff scope."""

import argparse
import html
import json
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


METRIC_ALIASES: Dict[str, Sequence[str]] = {
    "line": ("line", "line coverage"),
    "branch": ("branch", "branch coverage"),
    "condition": ("condition", "cond", "condition coverage"),
    "toggle": ("toggle", "tgl", "toggle coverage"),
    "fsm": ("fsm", "fsm coverage"),
    "functional": ("functional", "group", "covergroup"),
    "assertion": ("assert", "assertion", "assertion coverage"),
}


JSON_METRIC_KEYS = {
    "line": "line",
    "branch": "branch",
    "condition": "cond",
    "toggle": "tgl",
    "fsm": "fsm",
    "functional": "functional",
    "assertion": "assertion",
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


def find_metric_json(report_dir: Path, scope_name: str, metric: str) -> Optional[Tuple[float, Path]]:
    metric_key = JSON_METRIC_KEYS.get(metric)
    if not metric_key:
        return None
    for path in sorted(report_dir.rglob("scope_coverage_summary.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
        except (OSError, json.JSONDecodeError):
            continue
        scopes = data.get("scopes", {})
        if not isinstance(scopes, dict):
            continue
        scope = scopes.get(scope_name)
        if scope is None:
            for candidate, value in scopes.items():
                if str(candidate).lower() == scope_name.lower():
                    scope = value
                    break
        if not isinstance(scope, dict):
            continue
        metrics = scope.get("metrics", {})
        if not isinstance(metrics, dict):
            continue
        entry = metrics.get(metric_key)
        if not isinstance(entry, dict):
            continue
        value = entry.get("percent")
        if value is None:
            continue
        try:
            pct = float(value)
        except (TypeError, ValueError):
            continue
        if 0.0 <= pct <= 100.0:
            return pct, path
    return None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check scope-specific URG coverage thresholds")
    parser.add_argument("--scope-name", required=True)
    parser.add_argument("--urg-report-dir", required=True)
    parser.add_argument(
        "--metrics",
        default="line,branch,toggle,fsm,functional,assertion",
        help=(
            "Comma/space separated metrics to gate. Supported metrics: "
            "line, branch, condition, toggle, fsm, functional, assertion"
        ),
    )
    parser.add_argument("--line-threshold", type=float, default=99.5)
    parser.add_argument("--branch-threshold", type=float, default=99.0)
    parser.add_argument("--condition-threshold", type=float, default=99.0)
    parser.add_argument("--toggle-threshold", type=float, default=98.0)
    parser.add_argument("--fsm-threshold", type=float, default=99.0)
    parser.add_argument("--functional-threshold", type=float, default=100.0)
    parser.add_argument("--assertion-threshold", type=float, default=100.0)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    report_dir = Path(args.urg_report_dir)
    requested_metrics: List[str] = []
    for metric in re.split(r"[,\s]+", args.metrics.strip()):
        if not metric:
            continue
        metric_l = metric.lower()
        if metric_l not in METRIC_ALIASES:
            print(f"ERROR: unsupported metric '{metric}'", file=sys.stderr)
            return 2
        if metric_l not in requested_metrics:
            requested_metrics.append(metric_l)
    if not requested_metrics:
        print("ERROR: no metrics selected", file=sys.stderr)
        return 2

    all_thresholds = {
        "line": args.line_threshold,
        "branch": args.branch_threshold,
        "condition": args.condition_threshold,
        "toggle": args.toggle_threshold,
        "fsm": args.fsm_threshold,
        "functional": args.functional_threshold,
        "assertion": args.assertion_threshold,
    }
    thresholds = {metric: all_thresholds[metric] for metric in requested_metrics}

    details: List[str] = []
    ok = True
    report_ready = report_dir.is_dir() and any(report_dir.rglob("*"))
    if not report_ready:
        ok = False
        details.append(f"URG report missing or empty: {report_dir}")

    for metric, threshold in thresholds.items():
        located = None
        if report_ready:
            located = find_metric_json(report_dir, args.scope_name, metric)
            if located is None:
                located = find_metric(report_dir, METRIC_ALIASES[metric])
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
