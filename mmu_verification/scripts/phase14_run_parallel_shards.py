#!/usr/bin/env python3
"""Run Phase14 high-parallel shards with isolated VDBs and logs."""

import argparse
from collections import deque
import os
import re
import shutil
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Deque, Dict, Iterable, List, Tuple


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

ERROR_RE = re.compile(
    r"UVM_ERROR|UVM_FATAL|Error-|Error:|Fatal:|ASSERT|SVA|TEST FAILED|FAILED:|"
    r"CovErrorException|unexpected termination|signal:\s*Aborted|During dumping of toggle coverage data|"
    r"segmentation|SIGSEGV|core dumped|VCS internal error|Internal Error|"
    r"License checkout failed|Unable to checkout|No such feature exists|"
    r"run_cov simulation failed|coverage log contains fatal/crash/license pattern|"
    r"missing/empty compile baseline|No such file|Permission denied",
    re.IGNORECASE,
)

BENIGN_SUMMARY_RE = re.compile(r"^\s*UVM_(?:ERROR|FATAL)\s*:\s*0\b")


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


def clean_path(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def write_marker(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def strip_inline_comment(line: str) -> str:
    out: List[str] = []
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


def shard_tests(list_path: Path) -> List[str]:
    tests: List[str] = []
    try:
        lines = list_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError as exc:
        return [f"<could not read {list_path}: {exc}>"]

    for raw in lines:
        line = strip_inline_comment(raw)
        if not line:
            continue
        try:
            tokens = shlex.split(line)
        except ValueError:
            tokens = line.split()
        if tokens:
            tests.append(tokens[0])
    return tests


def summary_failure_lines(summary_path: Path, limit: int = 16) -> List[str]:
    if not summary_path.is_file():
        return [f"summary missing: {summary_path}"]

    wanted: List[str] = []
    try:
        lines = summary_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError as exc:
        return [f"could not read summary {summary_path}: {exc}"]

    for line in lines:
        stripped = line.strip()
        if (
            stripped.startswith("total_runs:")
            or stripped.startswith("passed_runs:")
            or stripped.startswith("failed_runs:")
            or stripped.startswith("effective_passed_runs:")
            or stripped.startswith("pass_rate:")
            or stripped.startswith("FAIL ")
            or stripped.startswith("XPASS ")
            or stripped.startswith("XFAIL ")
            or stripped.startswith("rc=")
            or stripped.startswith("cmd=")
        ):
            wanted.append(stripped)
        if len(wanted) >= limit:
            break
    return wanted


def collect_log_snippets(path: Path, match_limit: int = 12, tail_limit: int = 8) -> List[str]:
    if not path.is_file():
        return [f"missing log: {path}"]

    matches: List[str] = []
    tail: Deque[Tuple[int, str]] = deque(maxlen=tail_limit)
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            for lineno, raw in enumerate(handle, 1):
                line = raw.rstrip("\n")
                tail.append((lineno, line))
                if BENIGN_SUMMARY_RE.search(line):
                    continue
                if ERROR_RE.search(line) and len(matches) < match_limit:
                    matches.append(f"{lineno}:{line}")
    except OSError as exc:
        return [f"could not read log {path}: {exc}"]

    if matches:
        return matches
    return [f"{lineno}:{line}" for lineno, line in tail]


def sim_logs_for_row(row: Dict[str, str]) -> List[Path]:
    seed = row["seed"]
    log_dir = Path(row["log_dir"])
    return [log_dir / f"{test}_{seed}_cov.log" for test in shard_tests(Path(row["list"]))]


def format_failure(row: Dict[str, str], rc: int, max_logs: int = 2) -> str:
    tests = shard_tests(Path(row["list"]))
    tests_text = ",".join(tests) if tests else "<empty shard list>"
    lines = [
        f"{row['shard_id']}\trc={rc}\tseed={row['seed']}\ttests={tests_text}",
        f"  summary={row['summary']}",
        f"  driver_log={row['driver_log']}",
    ]

    for item in summary_failure_lines(Path(row["summary"])):
        lines.append(f"  summary: {item}")

    lines.append("  driver snippets:")
    for item in collect_log_snippets(Path(row["driver_log"]), match_limit=8, tail_limit=6):
        lines.append(f"    {item}")

    for sim_log in sim_logs_for_row(row)[:max_logs]:
        lines.append(f"  sim log snippets: {sim_log}")
        for item in collect_log_snippets(sim_log, match_limit=10, tail_limit=6):
            lines.append(f"    {item}")
    return "\n".join(lines)


def copy_baseline(src: Path, dst: Path, stamp: Path) -> None:
    if not src.is_dir() or not any(src.rglob("*")):
        raise RuntimeError(f"missing/empty compile baseline: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    stamp.parent.mkdir(parents=True, exist_ok=True)
    clean_path(dst)
    clean_path(stamp)
    try:
        shutil.copytree(src, dst, copy_function=os.link)
    except OSError:
        clean_path(dst)
        shutil.copytree(src, dst)
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
    run_dir = Path(row["run_dir"])
    running_marker = driver_log.parent / ".running"
    done_marker = driver_log.parent / ".done"
    passed_marker = driver_log.parent / ".passed"
    failed_marker = driver_log.parent / ".failed"

    driver_log.parent.mkdir(parents=True, exist_ok=True)
    summary.parent.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    for marker in (running_marker, done_marker, passed_marker, failed_marker):
        clean_path(marker)
    write_marker(running_marker, f"shard={shard_id}\nseed={seed}\n")
    cov_vdb.parent.mkdir(parents=True, exist_ok=True)
    try:
        clean_path(run_dir)
        run_dir.mkdir(parents=True, exist_ok=True)
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
            "UVM_CONFIG_DB_TRACE=0",
            f"COV_DB_DIR={cov_vdb}",
            f"COV_BASE_DB_DIR={base_vdb}",
            f"COV_BASELINE_STAMP={stamp}",
            f"LOG_DIR={log_dir}",
            f"RUN_DIR={run_dir}",
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
        rc = completed.returncode
    except Exception as exc:
        clean_path(running_marker)
        write_marker(done_marker, f"shard={shard_id}\nseed={seed}\nrc=2\nexception={exc}\n")
        write_marker(failed_marker, f"shard={shard_id}\nseed={seed}\nexception={exc}\n")
        raise

    clean_path(running_marker)
    write_marker(done_marker, f"shard={shard_id}\nseed={seed}\nrc={rc}\n")
    if rc == 0:
        write_marker(passed_marker, f"shard={shard_id}\nseed={seed}\n")
    else:
        write_marker(failed_marker, f"shard={shard_id}\nseed={seed}\nrc={rc}\n")
    return shard_id, rc


def write_fail_file(
    path: Path,
    failures: Iterable[Tuple[str, int]],
    rows_by_shard: Dict[str, Dict[str, str]],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for shard_id, rc in failures:
            row = rows_by_shard.get(shard_id)
            if row is None:
                handle.write(f"{shard_id}\trc={rc}\n")
            else:
                handle.write(format_failure(row, rc))
                handle.write("\n\n")


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
    rows_by_shard = {row["shard_id"]: row for row in rows}
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
        write_fail_file(fail_file, failures, rows_by_shard)
        print(f"Phase14 parallel failures: {len(failures)}; see {fail_file}", file=sys.stderr)
        for shard_id, rc in failures[:10]:
            row = rows_by_shard.get(shard_id)
            if row is not None:
                print(format_failure(row, rc, max_logs=1), file=sys.stderr)
        if len(failures) > 10:
            print(f"... truncated, remaining failures={len(failures) - 10}", file=sys.stderr)
        return 1
    print("Phase14 parallel shards completed cleanly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
