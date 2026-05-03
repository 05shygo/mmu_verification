#!/usr/bin/env python3
"""Create Phase14 high-parallel regression shard lists and manifest."""

import argparse
import shlex
from pathlib import Path
from typing import List


def strip_inline_comment(line: str) -> str:
    out = []
    in_single = False
    in_double = False
    for char in line:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            break
        out.append(char)
    return "".join(out).strip()


def parse_words(raw: str) -> List[str]:
    return [item for item in raw.replace(",", " ").split() if item]


def load_entries(path: Path) -> List[str]:
    entries: List[str] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_inline_comment(raw)
        if not line:
            continue
        tokens = shlex.split(line)
        if tokens:
            entries.append(line)
    if not entries:
        raise ValueError(f"no runnable entries in {path}")
    return entries


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Create Phase14 parallel shards")
    parser.add_argument("--list", required=True, help="Phase14 full regression list")
    parser.add_argument("--seeds", required=True, help="Phase14 seed list")
    parser.add_argument("--shard-dir", required=True, help="Output shard directory")
    parser.add_argument("--cov-prefix", required=True, help="Coverage VDB path prefix")
    parser.add_argument("--log-dir", required=True, help="Common simulation log directory")
    parser.add_argument("--manifest", required=True, help="Output TSV manifest")
    parser.add_argument("--runs-per-shard", type=int, default=1, help="Tests per shard per seed")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    list_path = Path(args.list)
    shard_dir = Path(args.shard_dir)
    manifest_path = Path(args.manifest)
    log_dir = Path(args.log_dir)
    cov_prefix = Path(args.cov_prefix)
    runs_per_shard = max(1, args.runs_per_shard)

    entries = load_entries(list_path)
    seeds = parse_words(args.seeds)
    if not seeds:
        raise ValueError("empty seed list")

    shard_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    cov_prefix.parent.mkdir(parents=True, exist_ok=True)

    rows: List[List[str]] = []
    shard_index = 0
    for seed in seeds:
        for offset in range(0, len(entries), runs_per_shard):
            shard_entries = entries[offset : offset + runs_per_shard]
            shard_id = f"shard_{shard_index:04d}"
            one_dir = shard_dir / shard_id
            one_dir.mkdir(parents=True, exist_ok=True)

            shard_list = one_dir / "list.txt"
            shard_summary = one_dir / "summary.txt"
            driver_log = one_dir / "driver.log"
            run_dir = one_dir / "run"
            shard_cov = Path(f"{cov_prefix}_{shard_index:04d}.vdb")
            shard_base = Path(f"{cov_prefix}_{shard_index:04d}.compile.vdb")
            shard_stamp = Path(f"{cov_prefix}_{shard_index:04d}.compile.stamp")

            shard_list.write_text("\n".join(shard_entries) + "\n", encoding="utf-8")
            rows.append(
                [
                    shard_id,
                    seed,
                    str(shard_list),
                    str(shard_summary),
                    str(shard_cov),
                    str(shard_base),
                    str(shard_stamp),
                    str(log_dir),
                    str(driver_log),
                    str(run_dir),
                ]
            )
            shard_index += 1

    with manifest_path.open("w", encoding="utf-8") as handle:
        handle.write("# shard_id\tseed\tlist\tsummary\tcov_vdb\tbase_vdb\tstamp\tlog_dir\tdriver_log\trun_dir\n")
        for row in rows:
            handle.write("\t".join(row) + "\n")

    print(
        "Phase14 parallel shards: "
        f"tests={len(entries)} seeds={len(seeds)} runs_per_shard={runs_per_shard} shards={len(rows)}"
    )
    print(f"Manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
