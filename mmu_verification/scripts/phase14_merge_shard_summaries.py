#!/usr/bin/env python3
"""Merge Phase 14 per-seed regression summaries into the canonical summary."""

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
        line = strip_comment(raw)
        if line:
            total += 1
    return total


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


def shard_summary_path(shard_dir: Path, seed: str) -> Path:
    return shard_dir / f"seed_{seed}" / "summary.txt"


def load_shard(
    shard_dir: Path,
    seed: str,
    mode: str,
    expected_tests: int,
) -> Tuple[Dict[str, int], List[str], List[str]]:
    path = shard_summary_path(shard_dir, seed)
    errors: List[str] = []
    if not path.is_file():
        return ({key: 0 for key in INT_KEYS}, [], [f"missing shard summary: {path}"])

    data = parse_summary(path)
    if data.get("mode") != mode:
        errors.append(f"{path}: mode={data.get('mode')} expected={mode}")
    if " ".join(parse_words(data.get("seeds", ""))) != seed:
        errors.append(f"{path}: seeds={data.get('seeds')} expected={seed}")
    if data.get("total_runs") != str(expected_tests):
        errors.append(f"{path}: total_runs={data.get('total_runs')} expected={expected_tests}")

    counts: Dict[str, int] = {}
    for key in INT_KEYS:
        raw_value = data.get(key, "0")
        try:
            counts[key] = int(raw_value)
        except ValueError:
            errors.append(f"{path}: {key}={raw_value} is not an integer")
            counts[key] = 0

    return counts, detail_lines(path), errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Merge Phase 14 shard summaries")
    parser.add_argument("--list", required=True, help="Phase 14 regression list")
    parser.add_argument("--seeds", required=True, help="Seed list used for the full run")
    parser.add_argument("--shard-dir", required=True, help="Directory containing seed_<seed>/summary.txt")
    parser.add_argument("--summary", required=True, help="Merged summary output path")
    parser.add_argument("--mode", default="run_cov", help="Expected regression mode")
    parser.add_argument("--min-pass-rate", type=float, default=1.0, help="Merged minimum pass rate")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    list_path = Path(args.list)
    shard_dir = Path(args.shard_dir)
    summary_path = Path(args.summary)
    seeds = parse_words(args.seeds)

    if not list_path.is_file():
        print(f"ERROR: missing list: {list_path}", file=sys.stderr)
        return 2
    if not seeds:
        print("ERROR: no seeds provided", file=sys.stderr)
        return 2

    expected_tests = count_tests(list_path)
    totals = {key: 0 for key in INT_KEYS}
    all_details: List[str] = []
    errors: List[str] = []

    for seed in seeds:
        counts, details, shard_errors = load_shard(shard_dir, seed, args.mode, expected_tests)
        errors.extend(shard_errors)
        for key in INT_KEYS:
            totals[key] += counts[key]
        if details:
            all_details.extend(details)

    total_runs = totals["total_runs"]
    effective_passed = totals["effective_passed_runs"]
    pass_rate = (effective_passed / total_runs) if total_runs else 0.0
    expected_total = expected_tests * len(seeds)
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

    print(f"Merged Phase14 summary: {summary_path}")
    return 0 if pass_rate >= args.min_pass_rate else 1


if __name__ == "__main__":
    sys.exit(main())
