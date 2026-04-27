#!/usr/bin/env python3

import argparse
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional


PROJECT_DIR = Path(__file__).resolve().parents[1]
TEST_DIR = PROJECT_DIR / "testbench" / "test"
LOG_DIR = PROJECT_DIR / "output" / "logs"
DEFAULT_TEST_NAME = "mmu_base_test"
DEFAULT_MODE = "run_check"
VALID_MODES = {"run", "run_check", "run_batch", "run_cov", "debug"}
SKIP_TESTS = {"test_base", "phase9_generated_test_base"}


@dataclass
class RegressionEntry:
    test_name: str
    plus_args: str = ""


@dataclass
class RegressionResult:
    test_name: str
    seed: str
    mode: str
    plus_args: str
    passed: bool
    duration_s: float
    command: List[str]
    log_path: Optional[Path]
    return_code: int


def find_registered_tests() -> List[str]:
    pattern = re.compile(r"uvm_component_utils(?:_begin)?\s*\(\s*([A-Za-z_][A-Za-z0-9_$]*)")
    tests = set()
    for sv_file in TEST_DIR.rglob("*.svh"):
        text = sv_file.read_text(encoding="utf-8", errors="ignore")
        tests.update(pattern.findall(text))
    return sorted(test for test in tests if test not in SKIP_TESTS)


def find_test_aliases() -> List[str]:
    aliases = []
    for path in sorted(TEST_DIR.iterdir()):
        if path.is_dir() and path.name != "phase9_common":
            aliases.append(path.name)
    return aliases


def collect_alias_tests(alias: str) -> List[str]:
    alias_dir = TEST_DIR / alias
    if not alias_dir.is_dir():
        return []
    pattern = re.compile(r"uvm_component_utils(?:_begin)?\s*\(\s*([A-Za-z_][A-Za-z0-9_$]*)")
    tests = set()
    for sv_file in alias_dir.rglob("*.svh"):
        text = sv_file.read_text(encoding="utf-8", errors="ignore")
        tests.update(pattern.findall(text))
    return sorted(test for test in tests if test not in SKIP_TESTS)


def parse_seed_list(raw: str) -> List[str]:
    seeds = [item for item in re.split(r"[,\s]+", raw.strip()) if item]
    return seeds or ["1"]


def combine_plus_args(global_plus_args: str, local_plus_args: str) -> str:
    parts = [part.strip() for part in (global_plus_args, local_plus_args) if part and part.strip()]
    return " ".join(parts)


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


def load_regression_list(list_path: Path) -> List[RegressionEntry]:
    if not list_path.is_file():
        raise FileNotFoundError(f"Regression list not found: {list_path}")

    entries: List[RegressionEntry] = []
    with list_path.open("r", encoding="utf-8", errors="ignore") as handle:
        for raw in handle:
            line = strip_inline_comment(raw)
            if not line:
                continue
            tokens = shlex.split(line)
            if not tokens:
                continue
            entries.append(RegressionEntry(test_name=tokens[0], plus_args=" ".join(tokens[1:])))

    if not entries:
        raise ValueError(f"Regression list is empty after filtering comments: {list_path}")

    return entries


def resolve_log_path(test_name: str, seed: str, mode: str) -> Optional[Path]:
    if mode == "run_cov":
        return LOG_DIR / f"{test_name}_{seed}_cov.log"
    if mode in {"run", "run_check"}:
        return LOG_DIR / f"{test_name}_{seed}.log"
    if mode == "run_batch":
        return LOG_DIR / f"{test_name}_batch.log"
    if mode == "debug":
        return LOG_DIR / f"{test_name}_debug.log"
    return None


def resolve_log_paths(test_name: str, seed: str, mode: str) -> List[Path]:
    aliases = set(find_test_aliases())
    if mode == "run_cov" and test_name in aliases:
        return [LOG_DIR / f"{leaf}_{seed}_cov.log" for leaf in collect_alias_tests(test_name)]
    log_path = resolve_log_path(test_name, seed, mode)
    return [log_path] if log_path is not None else []


def make_cmd(
    mode: str,
    test_name: str,
    seed: str,
    verbosity: str,
    timeout: str,
    uvm_err_only: str,
    plus_args: str,
) -> List[str]:
    cmd = [
        "make",
        mode,
        f"TEST_NAME={test_name}",
        f"SEED={seed}",
        f"VERBOSITY={verbosity}",
        f"TIMEOUT={timeout}",
        f"UVM_ERR_ONLY={uvm_err_only}",
    ]
    if plus_args:
        cmd.append(f"PLUS_ARGS={plus_args}")
    return cmd


def run_command(cmd: List[str]) -> int:
    try:
        completed = subprocess.run(cmd, cwd=PROJECT_DIR)
    except FileNotFoundError as exc:
        missing = exc.filename or cmd[0]
        raise RuntimeError(f"Required command not found in PATH: {missing}") from exc
    return completed.returncode


def resolve_user_path(raw_path: str) -> Path:
    path = Path(raw_path)
    if not path.is_absolute():
        path = PROJECT_DIR / path
    return path


def run_single(
    mode: str,
    test_name: str,
    seed: str,
    verbosity: str,
    timeout: str,
    uvm_err_only: str,
    plus_args: str,
) -> RegressionResult:
    cmd = make_cmd(mode, test_name, seed, verbosity, timeout, uvm_err_only, plus_args)
    start = time.monotonic()
    rc = run_command(cmd)
    log_paths = resolve_log_paths(test_name, seed, mode)
    log_path = log_paths[0] if len(log_paths) == 1 else None

    if rc == 0 and mode == "run_cov" and log_paths:
        for cov_log in log_paths:
            check_cmd = ["make", "check_log", f"LOG={cov_log}"]
            rc = run_command(check_cmd)
            if rc != 0:
                cmd = cmd + ["&&"] + check_cmd
                break

    duration_s = time.monotonic() - start
    return RegressionResult(
        test_name=test_name,
        seed=seed,
        mode=mode,
        plus_args=plus_args,
        passed=(rc == 0),
        duration_s=duration_s,
        command=cmd,
        log_path=log_path,
        return_code=rc,
    )


def write_summary(
    summary_path: Path,
    list_path: Optional[Path],
    mode: str,
    seeds: Iterable[str],
    results: List[RegressionResult],
    min_pass_rate: float,
) -> None:
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    total = len(results)
    passed = sum(1 for item in results if item.passed)
    failed = total - passed
    pass_rate = (passed / total) if total else 0.0

    with summary_path.open("w", encoding="utf-8") as handle:
        handle.write("MMU regression summary\n")
        if list_path is not None:
            handle.write(f"list: {list_path}\n")
        handle.write(f"mode: {mode}\n")
        handle.write(f"seeds: {' '.join(seeds)}\n")
        handle.write(f"total_runs: {total}\n")
        handle.write(f"passed_runs: {passed}\n")
        handle.write(f"failed_runs: {failed}\n")
        handle.write(f"pass_rate: {pass_rate:.4f}\n")
        handle.write(f"min_pass_rate: {min_pass_rate:.4f}\n")
        handle.write("\n")
        for result in results:
            status = "PASS" if result.passed else "FAIL"
            log_path = str(result.log_path) if result.log_path is not None else "-"
            handle.write(
                f"{status} test={result.test_name} seed={result.seed} "
                f"mode={result.mode} duration_s={result.duration_s:.2f} log={log_path}\n"
            )
            if not result.passed:
                handle.write(f"  rc={result.return_code} cmd={' '.join(result.command)}\n")


def run_regression(
    list_path: Path,
    mode: str,
    seeds: List[str],
    verbosity: str,
    timeout: str,
    uvm_err_only: str,
    global_plus_args: str,
    summary_path: Path,
    min_pass_rate: float,
) -> int:
    entries = load_regression_list(list_path)
    results: List[RegressionResult] = []

    for entry in entries:
        for seed in seeds:
            plus_args = combine_plus_args(global_plus_args, entry.plus_args)
            print(f"=== regression: {entry.test_name} seed={seed} mode={mode} ===")
            result = run_single(
                mode=mode,
                test_name=entry.test_name,
                seed=seed,
                verbosity=verbosity,
                timeout=timeout,
                uvm_err_only=uvm_err_only,
                plus_args=plus_args,
            )
            results.append(result)

    write_summary(summary_path, list_path, mode, seeds, results, min_pass_rate)

    total = len(results)
    passed = sum(1 for item in results if item.passed)
    pass_rate = (passed / total) if total else 0.0
    print(f"Summary: {passed}/{total} passed, pass_rate={pass_rate:.2%}")
    print(f"Summary file: {summary_path}")
    return 0 if total and pass_rate >= min_pass_rate else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="MMU test and regression wrapper")
    parser.add_argument("--test-name", default=DEFAULT_TEST_NAME, help="UVM test name or supported group alias")
    parser.add_argument("--seed", default="1", help="Seed for a single test run")
    parser.add_argument("--plus-args", default="", help="Extra plusargs passed through to Makefile")
    parser.add_argument("--verbosity", default="UVM_MEDIUM", help="UVM verbosity passed through to Makefile")
    parser.add_argument("--timeout", default="10000000", help="Simulation timeout passed through to Makefile")
    parser.add_argument("--uvm-err-only", default="0", help="Pass 1 to add +UVM_ERR_ONLY")
    parser.add_argument("--mode", default=DEFAULT_MODE, choices=sorted(VALID_MODES), help="Make target to execute")
    parser.add_argument("--reg-list", help="Regression list file under the MMU project")
    parser.add_argument("--seeds", default="1", help="Whitespace or comma separated seed list for regression mode")
    parser.add_argument("--summary", help="Summary file path for regression mode")
    parser.add_argument("--min-pass-rate", type=float, default=1.0, help="Minimum pass rate before returning failure")
    parser.add_argument("--list", action="store_true", help="List registered tests and directory aliases")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.list:
        print("Registered UVM tests:")
        for name in find_registered_tests():
            print(name)
        print("")
        print("Supported test directory aliases:")
        for alias in find_test_aliases():
            print(alias)
        return 0

    if args.reg_list:
        summary = resolve_user_path(args.summary) if args.summary else PROJECT_DIR / "output" / "regression" / "adhoc" / "summary.txt"
        try:
            return run_regression(
                list_path=resolve_user_path(args.reg_list),
                mode=args.mode,
                seeds=parse_seed_list(args.seeds),
                verbosity=args.verbosity,
                timeout=args.timeout,
                uvm_err_only=args.uvm_err_only,
                global_plus_args=args.plus_args,
                summary_path=summary,
                min_pass_rate=args.min_pass_rate,
            )
        except (FileNotFoundError, RuntimeError, ValueError) as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2

    try:
        result = run_single(
            mode=args.mode,
            test_name=args.test_name,
            seed=str(args.seed),
            verbosity=args.verbosity,
            timeout=args.timeout,
            uvm_err_only=args.uvm_err_only,
            plus_args=args.plus_args,
        )
        return 0 if result.passed else result.return_code
    except (FileNotFoundError, RuntimeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
