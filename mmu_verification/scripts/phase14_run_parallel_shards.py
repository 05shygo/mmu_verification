#!/usr/bin/env python3
"""Run Phase14 high-parallel shards with isolated VDBs and logs."""

import argparse
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


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
)


def parse_manifest(path: Path) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        parts = raw.rstrip("\n").split("\t")
        if len(parts) != len(FIELDS):
            raise ValueError(f"bad manifest row with {len(parts)} fields: {raw}")
        rows.append(dict(zip(FIELDS, parts)))
    if not rows:
        raise ValueError(f"manifest has no shards: {path}")
    return rows


def clean_path(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def copy_baseline(src: Path, dst: Path, stamp: Path) -> None:
    if not src.is_dir() or not any(src.rglob("*")):
        raise RuntimeError(f"missing/empty compile baseline: {src}")
    clean_path(dst)
    clean_path(stamp)
    try:
        shutil.copytree(src, dst, copy_function=os.link)
    except OSError:
        clean_path(dst)
        shutil.copytree(src, dst)
    stamp.parent.mkdir(parents=True, exist_ok=True)
    stamp.write_text("phase14 parallel shard baseline\n", encoding="utf-8")


def run_one(row: Dict[str, str], args: argparse.Namespace) -> Tuple[str, int]:
    shard_id = row["shard_id"]
    seed = row["seed"]
    shard_list = Path(row["list"])
    summary = Path(row["summary"])
    cov_vdb = Path(row["cov_vdb"])
    base_vdb = Path(row["base_vdb"])
    stamp = Path(row["stamp"])
    log_dir = Path(row["log_dir"])
    driver_log = Path(row["driver_log"])

    driver_log.parent.mkdir(parents=True, exist_ok=True)
    summary.parent.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    clean_path(cov_vdb)
    copy_baseline(Path(args.cov_base_db_dir), base_vdb, stamp)

    cmd = [
        args.make,
        "regress",
        f"LIST={shard_list}",
        "REGRESS_MODE=run_cov",
        f"REGRESS_NAME=phase14_parallel_{shard_id}",
        f"REGRESS_SUMMARY={summary}",
        f"REGRESS_SEEDS={seed}",
        "REGRESS_JOBS=1",
        f"REGRESS_FAIL_FAST={args.fail_fast}",
        "REGRESS_MIN_PASS_RATE=1.0",
        f"VERBOSITY={args.verbosity}",
        f"TIMEOUT={args.timeout}",
        f"UVM_ERR_ONLY={args.uvm_err_only}",
        f"COV_DB_DIR={cov_vdb}",
        f"COV_BASE_DB_DIR={base_vdb}",
        f"COV_BASELINE_STAMP={stamp}",
        f"LOG_DIR={log_dir}",
    ]

    with driver_log.open("w", encoding="utf-8", errors="ignore") as handle:
        handle.write(f"=== Phase14 parallel shard {shard_id} seed={seed} ===\n")
        handle.write(" ".join(cmd) + "\n")
        handle.flush()
        completed = subprocess.run(
            cmd,
            cwd=args.project_dir,
            stdout=handle,
            stderr=subprocess.STDOUT,
            env=os.environ.copy(),
        )
    return shard_id, completed.returncode


def write_fail_file(path: Path, failures: Iterable[Tuple[str, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for shard_id, rc in failures:
            handle.write(f"{shard_id}\trc={rc}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run Phase14 parallel shards")
    parser.add_argument("--manifest", required=True, help="Shard manifest from phase14_make_parallel_shards.py")
    parser.add_argument("--project-dir", required=True, help="MMU project directory")
    parser.add_argument("--cov-base-db-dir", required=True, help="Compile baseline VDB to copy per shard")
    parser.add_argument("--jobs", type=int, default=32, help="Concurrent shards")
    parser.add_argument("--make", default="make", help="Make executable")
    parser.add_argument("--verbosity", default="UVM_MEDIUM")
    parser.add_argument("--timeout", default="10000000")
    parser.add_argument("--uvm-err-only", default="0")
    parser.add_argument("--fail-fast", default="1")
    parser.add_argument("--fail-file", required=True, help="Output failure marker file")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    rows = parse_manifest(Path(args.manifest))
    jobs = max(1, args.jobs)
    fail_file = Path(args.fail_file)
    clean_path(fail_file)

    print(f"=== Phase14 parallel run: shards={len(rows)} jobs={jobs} ===")
    failures: List[Tuple[str, int]] = []
    with ThreadPoolExecutor(max_workers=jobs) as executor:
        future_to_shard = {executor.submit(run_one, row, args): row["shard_id"] for row in rows}
        for future in as_completed(future_to_shard):
            shard_id = future_to_shard[future]
            try:
                done_id, rc = future.result()
            except Exception as exc:
                done_id = shard_id
                rc = 2
                print(f"[FAIL] {done_id}: {exc}", file=sys.stderr)
            else:
                status = "PASS" if rc == 0 else "FAIL"
                print(f"[{status}] {done_id} rc={rc}")
            if rc != 0:
                failures.append((done_id, rc))

    if failures:
        write_fail_file(fail_file, failures)
        print(f"Phase14 parallel failures: {len(failures)}; see {fail_file}", file=sys.stderr)
        return 1
    print("Phase14 parallel shards completed cleanly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
