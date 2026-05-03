#!/usr/bin/env python3
"""Print actionable details for an existing Phase14 parallel failed run."""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

from phase14_run_parallel_shards import format_failure, parse_manifest


FAIL_LINE_RE = re.compile(r"^(?P<shard>shard_\d+)\s+rc=(?P<rc>\d+)\b")


def parse_fail_file(path: Path) -> List[Tuple[str, int]]:
    failures: List[Tuple[str, int]] = []
    if not path.is_file():
        return failures

    seen = set()
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        match = FAIL_LINE_RE.search(raw.strip())
        if not match:
            continue
        shard_id = match.group("shard")
        if shard_id in seen:
            continue
        seen.add(shard_id)
        failures.append((shard_id, int(match.group("rc"))))
    return failures


def marker_failures(rows: List[Dict[str, str]]) -> List[Tuple[str, int]]:
    failures: List[Tuple[str, int]] = []
    for row in rows:
        marker = Path(row["driver_log"]).parent / ".failed"
        if not marker.is_file():
            continue
        rc = 1
        text = marker.read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"\brc=(\d+)\b", text)
        if match:
            rc = int(match.group(1))
        failures.append((row["shard_id"], rc))
    return failures


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Show Phase14 parallel shard failures")
    parser.add_argument("--manifest", required=True, help="Parallel manifest.tsv")
    parser.add_argument("--fail-file", required=True, help="Parallel .run_failed file")
    parser.add_argument("--limit", type=int, default=0, help="Maximum failures to print, 0 means all")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    rows = parse_manifest(Path(args.manifest))
    rows_by_shard = {row["shard_id"]: row for row in rows}
    failures = parse_fail_file(Path(args.fail_file))
    source = str(args.fail_file)
    if not failures:
        failures = marker_failures(rows)
        source = ".failed markers"

    if not failures:
        print(f"No failed Phase14 parallel shards found in {args.fail_file}")
        return 0

    limit = args.limit if args.limit > 0 else len(failures)
    print(f"Phase14 parallel failures: {len(failures)} (source: {source})")
    for shard_id, rc in failures[:limit]:
        row = rows_by_shard.get(shard_id)
        if row is None:
            print(f"{shard_id}\trc={rc}\tmissing from manifest")
            continue
        print(format_failure(row, rc))
        print("")
    if len(failures) > limit:
        print(f"... truncated, remaining failures={len(failures) - limit}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
