#!/usr/bin/env python3
"""Merge Phase14 high-parallel shard summaries into the canonical summary."""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple


INT_KEYS = (
    "total_runs",
    "passed_runs",
    "failed_runs",
    "xfail_expected_runs",
    "xpass_unexpected_runs",
    "effective_passed_runs",
)


def parse_words(raw: str) -> List[str]:
    return [item for item in re.split(r"[,\s]+", raw.strip()) if item]


def strip_comment(raw: str) -> str:
    return raw.split("#", 1)[0].strip()


def count_tests(list_path: Path) -> int:
    total = 0
    for raw in list_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if strip_comment(raw):
            total += 1
    return total


def parse_manifest(path: Path) -> List[Dict[str, str]]:
    fields = (
        "shard_id",
        "seed",
        "list",
        "summary",
        "cov_vdb",
        "base_vdb",
        "stamp",
        "log_dir",
        "driver_log",
    )
    rows: List[Dict[str, str]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        parts = raw.rstrip("\n").split("\t")
        if len(parts) != len(fields):
            raise ValueError(f"bad manifest row with {len(parts)} fields: {raw}")
        rows.append(dict(zip(fields, parts)))
    if not rows:
        raise ValueError(f"manifest has no shards: {path}")
    return rows


def parse_summary(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        data[key.strip()] = value.strip()
    return data


def detail_lines(path: Path) -> List[str]:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    for idx, line in enumerate(lines):
        if not line.strip():
            return lines[idx + 1 :]
    return []


def load_summary(row: Dict[str, str], mode: str) -> Tuple[Dict[str, int], List[str], List[str]]:
    path = Path(row["summary"])
    shard_id = row["shard_id"]
    seed = row["seed"]
    errors: List[str] = []
    if not path.is_file():
        return ({key: 0 for key in INT_KEYS}, [], [f"{shard_id}: missing summary: {path}"])

    data = parse_summary(path)
    if data.get("mode") != mode:
        errors.append(f"{shard_id}: mode={data.get('mode')} expected={mode}")
    if " ".join(parse_words(data.get("seeds", ""))) != seed:
        errors.append(f"{shard_id}: seeds={data.get('seeds')} expected={seed}")

    counts: Dict[str, int] = {}
    for key in INT_KEYS:
        raw_value = data.get(key, "0")
        try:
            counts[key] = int(raw_value)
        except ValueError:
            errors.append(f"{shard_id}: {key}={raw_value} is not an integer")
            counts[key] = 0
    return counts, detail_lines(path), errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Merge Phase14 parallel summaries")
    parser.add_argument("--list", required=True, help="Phase14 full regression list")
    parser.add_argument("--seeds", required=True, help="Phase14 seed list")
    parser.add_argument("--manifest", required=True, help="Parallel shard manifest")
    parser.add_argument("--summary", required=True, help="Merged summary output path")
    parser.add_argument("--mode", default="run_cov", help="Expected regression mode")
    parser.add_argument("--min-pass-rate", type=float, default=1.0)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    list_path = Path(args.list)
    summary_path = Path(args.summary)
    seeds = parse_words(args.seeds)
    rows = parse_manifest(Path(args.manifest))
    expected_total = count_tests(list_path) * len(seeds)

    totals = {key: 0 for key in INT_KEYS}
    all_details: List[str] = []
    errors: List[str] = []

    for row in rows:
        counts, details, shard_errors = load_summary(row, args.mode)
        errors.extend(shard_errors)
        for key in INT_KEYS:
            totals[key] += counts[key]
        all_details.extend(details)

    total_runs = totals["total_runs"]
    effective_passed = totals["effective_passed_runs"]
    pass_rate = (effective_passed / total_runs) if total_runs else 0.0
    if total_runs != expected_total:
        errors.append(f"merged total_runs={total_runs} expected={expected_total}")

    summary_path.parent.mkdir(parents=True, exist_ok=True)
    with summary_path.open("w", encoding="utf-8") as handle:
        handle.write("MMU regression summary\n")
        handle.write(f"list: {list_path}\n")
        handle.write(f"mode: {args.mode}\n")
        handle.write(f"seeds: {' '.join(seeds)}\n")
        for key in INT_KEYS:
            handle.write(f"{key}: {totals[key]}\n")
        handle.write(f"pass_rate: {pass_rate:.4f}\n")
        handle.write(f"min_pass_rate: {args.min_pass_rate:.4f}\n")
        handle.write("\n")
        for line in all_details:
            handle.write(f"{line}\n")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"Merged summary written with errors: {summary_path}", file=sys.stderr)
        return 1
    print(f"Merged Phase14 parallel summary: {summary_path}")
    return 0 if pass_rate >= args.min_pass_rate else 1


if __name__ == "__main__":
    sys.exit(main())
