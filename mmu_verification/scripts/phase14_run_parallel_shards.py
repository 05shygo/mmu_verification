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
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Deque, Dict, Iterable, List, Optional, Tuple


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
    r"UVM_ERROR|UVM_FATAL|Error-|Error:|Fatal:|"
    r"ASSERT(?:ION)?\s+(?:FAIL|FAILED|FAILURE)|ASSERT.*(?:failed|violation)|"
    r"SVA|TEST FAILED|FAILED:|"
    r"CovErrorException|unexpected termination|signal:\s*Aborted|During dumping of toggle coverage data|"
    r"segmentation|SIGSEGV|core dumped|VCS internal error|Internal Error|"
    r"License checkout failed|Unable to checkout|No such feature exists|"
    r"run_cov simulation failed|coverage log contains fatal/crash/license pattern|"
    r"missing/empty compile baseline|No such file|Permission denied",
    re.IGNORECASE,
)

BENIGN_SUMMARY_RE = re.compile(r"^\s*UVM_(?:ERROR|FATAL)\s*:\s*0\b")
COMPLETION_RE = re.compile(
    r"UVM Report Summary|V C S\s+S i m u l a t i o n\s+R e p o r t|"
    r"Simulation completed|\$finish|TEST COMPLETED",
    re.IGNORECASE,
)
RETRYABLE_STARTUP_RE = re.compile(
    r"run_cov simulation failed:.*\brc=255\b|"
    r"\brc=255\b|"
    r"License checkout failed|Unable to checkout|"
    r"licensed number of users.*already reached|"
    r"license.*not available",
    re.IGNORECASE,
)
NON_RETRYABLE_SIM_RE = re.compile(
    r"UVM_ERROR\s+@|UVM_FATAL\s+@|"
    r"ASSERT(?:ION)?\s+(?:FAIL|FAILED|FAILURE)|ASSERT.*(?:failed|violation)|"
    r"SVA|TEST FAILED|FAILED:|"
    r"CovErrorException|unexpected termination|signal:\s*Aborted|"
    r"During dumping of toggle coverage data|segmentation|SIGSEGV|core dumped|"
    r"VCS internal error|Internal Error|No such feature exists|"
    r"No such file|Permission denied|error while loading shared libraries|"
    r"cannot open shared object file",
    re.IGNORECASE,
)
NON_RETRYABLE_STARTUP_RE = re.compile(
    r"No such file|Permission denied|error while loading shared libraries|"
    r"cannot open shared object file|No such feature exists",
    re.IGNORECASE,
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


def clean_path(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def write_marker(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def read_text(path: Path, max_bytes: int = 262144) -> str:
    if not path.is_file():
        return ""
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            return handle.read(max_bytes)
    except OSError:
        return ""


def has_tree_files(path: Path) -> bool:
    return path.is_dir() and any(item.is_file() for item in path.rglob("*"))


def validate_baseline(src: Path, stamp: Optional[Path] = None) -> None:
    if stamp is not None and not stamp.is_file():
        raise RuntimeError(f"compile-time coverage baseline stamp is missing: {stamp}")
    if not has_tree_files(src):
        raise RuntimeError(f"missing/empty compile baseline: {src}")


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
    tail_lines = [f"{lineno}:{line}" for lineno, line in tail]
    if tail and not any(COMPLETION_RE.search(line) for _, line in tail):
        _, last_line = tail[-1]
        if len(tail) <= 3 and last_line.startswith("Command:"):
            return [f"incomplete startup log: {len(tail)} line(s), no UVM/VCS completion marker"] + tail_lines
    return tail_lines


def sim_logs_for_row(row: Dict[str, str]) -> List[Path]:
    seed = row["seed"]
    log_dir = Path(row["log_dir"])
    return [log_dir / f"{test}_{seed}_cov.log" for test in shard_tests(Path(row["list"]))]


def startup_failure_reason(row: Dict[str, str]) -> str:
    driver_text = read_text(Path(row["driver_log"]))
    summary_text = read_text(Path(row["summary"]))
    sim_logs = sim_logs_for_row(row)
    sim_texts = [read_text(path) for path in sim_logs]
    combined = "\n".join([driver_text, summary_text, *sim_texts])

    if not RETRYABLE_STARTUP_RE.search(combined):
        return ""
    if NON_RETRYABLE_STARTUP_RE.search(combined):
        return ""
    if any(NON_RETRYABLE_SIM_RE.search(text) for text in sim_texts):
        return ""
    if any(COMPLETION_RE.search(text) for text in sim_texts):
        return ""

    has_explicit_license_pressure = bool(
        re.search(
            r"License checkout failed|Unable to checkout|"
            r"licensed number of users.*already reached|"
            r"license.*not available",
            combined,
            re.IGNORECASE,
        )
    )
    short_logs = []
    for path, text in zip(sim_logs, sim_texts):
        lines = [line for line in text.splitlines() if line.strip()]
        if not path.is_file() or len(lines) <= 3:
            short_logs.append(path.name)
    if short_logs and len(short_logs) == len(sim_logs):
        return (
            "startup/resource retry signature: rc=255 before UVM started; "
            "sim log is missing or only contains the VCS Command line"
        )
    if has_explicit_license_pressure:
        return "startup/resource retry signature: transient simulator license pressure"
    return ""


def retry_delay_s(args: argparse.Namespace, attempt_index: int, shard_id: str) -> float:
    base = max(0.0, float(args.startup_retry_delay))
    max_delay = max(base, float(args.startup_retry_max_delay))
    delay = min(max_delay, base * (2 ** max(0, attempt_index - 1))) if base else 0.0
    jitter = max(0.0, float(args.startup_retry_jitter))
    if jitter:
        match = re.search(r"(\d+)$", shard_id)
        shard_num = int(match.group(1)) if match else 0
        delay += ((shard_num + attempt_index * 17) % 1000) / 1000.0 * jitter
    return delay


def launch_delay_s(args: argparse.Namespace, shard_id: str) -> float:
    stagger = max(0.0, float(args.launch_stagger))
    if not stagger:
        return 0.0
    match = re.search(r"(\d+)$", shard_id)
    shard_num = int(match.group(1)) if match else 0
    return (shard_num % max(1, int(args.jobs))) * stagger


def format_failure(row: Dict[str, str], rc: int, max_logs: int = 2) -> str:
    tests = shard_tests(Path(row["list"]))
    tests_text = ",".join(tests) if tests else "<empty shard list>"
    lines = [
        f"{row['shard_id']}\trc={rc}\tseed={row['seed']}\ttests={tests_text}",
        f"  summary={row['summary']}",
        f"  driver_log={row['driver_log']}",
    ]
    reason = startup_failure_reason(row)
    if reason:
        lines.append(f"  diagnosis: {reason}")

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
    clean_path(base_vdb)
    clean_path(stamp)

    max_attempts = 1 + max(0, int(args.startup_retries))
    rc = 2
    try:
        clean_path(run_dir)
        run_dir.mkdir(parents=True, exist_ok=True)

        for attempt in range(1, max_attempts + 1):
            if attempt == 1:
                delay = launch_delay_s(args, shard_id)
                if delay:
                    time.sleep(delay)
            clean_path(run_dir)
            run_dir.mkdir(parents=True, exist_ok=True)
            clean_path(cov_vdb)
            clean_path(summary)
            for sim_log in sim_logs_for_row(row):
                clean_path(sim_log)

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
                f"COV_BASE_DB_DIR={args.cov_base_db_dir}",
                "COV_HARDLINK_GUARD=1",
                f"LOG_DIR={log_dir}",
                f"RUN_DIR={run_dir}",
            ]
            if args.cov_baseline_stamp:
                cmd.append(f"COV_BASELINE_STAMP={args.cov_baseline_stamp}")

            mode = "w" if attempt == 1 else "a"
            started = time.monotonic()
            with driver_log.open(mode, encoding="utf-8", errors="ignore") as handle:
                handle.write(
                    f"=== Phase14 parallel shard {shard_id} seed={seed} "
                    f"attempt={attempt}/{max_attempts} ===\n"
                )
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
            elapsed = time.monotonic() - started
            if rc == 0:
                break

            reason = startup_failure_reason(row)
            retryable = bool(reason) and elapsed <= float(args.startup_retry_max_runtime)
            if not retryable or attempt >= max_attempts:
                break

            delay = retry_delay_s(args, attempt, shard_id)
            with driver_log.open("a", encoding="utf-8", errors="ignore") as handle:
                handle.write(
                    f"PHASE14_STARTUP_RETRY shard={shard_id} seed={seed} "
                    f"attempt={attempt}/{max_attempts} rc={rc} "
                    f"elapsed_s={elapsed:.2f} delay_s={delay:.2f} reason={reason}\n"
                )
                handle.flush()
            time.sleep(delay)
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
    parser.add_argument("--cov-base-db-dir", required=True, help="Shared clean compile baseline VDB")
    parser.add_argument("--cov-baseline-stamp", default="", help="Compile baseline stamp checked by run_cov")
    parser.add_argument("--jobs", type=int, default=32, help="Concurrent shards")
    parser.add_argument("--make", default="make", help="Make executable")
    parser.add_argument("--verbosity", default="UVM_MEDIUM")
    parser.add_argument("--timeout", default="10000000")
    parser.add_argument("--uvm-err-only", default="0")
    parser.add_argument("--fail-fast", default="1")
    parser.add_argument("--launch-stagger", type=float, default=0.0, help="Seconds to stagger each initial shard launch")
    parser.add_argument("--startup-retries", type=int, default=0, help="Retries for rc=255 startup/resource failures")
    parser.add_argument("--startup-retry-delay", type=float, default=10.0, help="Initial retry delay in seconds")
    parser.add_argument("--startup-retry-max-delay", type=float, default=120.0, help="Maximum retry delay in seconds")
    parser.add_argument("--startup-retry-jitter", type=float, default=5.0, help="Deterministic retry jitter in seconds")
    parser.add_argument(
        "--startup-retry-max-runtime",
        type=float,
        default=20.0,
        help="Only retry startup failures whose failed attempt returned within this many seconds",
    )
    parser.add_argument("--fail-file", required=True, help="Output failure marker file")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        validate_baseline(
            Path(args.cov_base_db_dir),
            Path(args.cov_baseline_stamp) if args.cov_baseline_stamp else None,
        )
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
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
