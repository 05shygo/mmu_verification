#!/usr/bin/env python3
"""Merge Phase14 high-parallel shard VDBs with URG."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List


def _popen_text_stdio_kwargs():
    """Text mode for captured stdout (``text=`` requires Python 3.7+)."""
    if sys.version_info >= (3, 7):
        return {"text": True, "errors": "ignore"}
    if sys.version_info >= (3, 6):
        return {"universal_newlines": True, "encoding": "utf-8", "errors": "ignore"}
    return {"universal_newlines": True}


FIELDS = (
    "shard_id",
    "seed",
    "list",
    "summary",
    "cov_vdb",
    "base_vdb",
    "stamp",
    "log_dir",
    "driver_log",
    "run_dir",
)


def parse_manifest(path: Path) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        parts = raw.rstrip("\n").split("\t")
        if len(parts) == len(FIELDS) - 1:
            parts.append(str(Path(parts[-1]).parent / "run"))
        elif len(parts) != len(FIELDS):
            raise ValueError(f"bad manifest row with {len(parts)} fields: {raw}")
        rows.append(dict(zip(FIELDS, parts)))
    if not rows:
        raise ValueError(f"manifest has no shards: {path}")
    return rows


def has_files(path: Path) -> bool:
    return path.is_dir() and any(path.rglob("*"))


def clean_dir(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def run_and_tee(cmd: List[str], log_path: Path) -> int:
    with log_path.open("a", encoding="utf-8", errors="ignore") as log:
        log.write("\n$ " + " ".join(cmd) + "\n")
        log.flush()
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            **_popen_text_stdio_kwargs(),
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            print(line, end="")
            log.write(line)
        return proc.wait()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Merge Phase14 parallel VDBs with URG")
    parser.add_argument("--manifest", required=True, help="Parallel shard manifest")
    parser.add_argument("--urg", default="urg", help="URG executable")
    parser.add_argument("--merged-db", required=True, help="Output merged VDB")
    parser.add_argument("--report-dir", required=True, help="Output URG report directory")
    parser.add_argument("--log", required=True, help="URG merge log")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    rows = parse_manifest(Path(args.manifest))
    vdbs = [Path(row["cov_vdb"]) for row in rows]
    missing = [str(path) for path in vdbs if not has_files(path)]
    if missing:
        print("ERROR: missing/empty parallel shard VDBs:", file=sys.stderr)
        for path in missing[:20]:
            print(f"  {path}", file=sys.stderr)
        if len(missing) > 20:
            print(f"  ... truncated, total missing={len(missing)}", file=sys.stderr)
        return 1

    merged_db = Path(args.merged_db)
    report_dir = Path(args.report_dir)
    log_path = Path(args.log)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(f"Phase14 parallel VDB count: {len(vdbs)}\n", encoding="utf-8")

    clean_dir(merged_db)
    clean_dir(report_dir)

    merge_cmd = [args.urg, "-full64", "-dir", *[str(path) for path in vdbs], "-dbname", str(merged_db)]
    rc = run_and_tee(merge_cmd, log_path)
    if rc != 0:
        return rc

    report_cmd = [args.urg, "-full64", "-dir", str(merged_db), "-format", "both", "-report", str(report_dir)]
    rc = run_and_tee(report_cmd, log_path)
    if rc != 0:
        return rc

    if not has_files(report_dir):
        print(f"ERROR: URG report missing after parallel merge: {report_dir}", file=sys.stderr)
        return 1
    print(f"Phase14 parallel URG report: {report_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
