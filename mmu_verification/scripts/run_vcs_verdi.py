#!/usr/bin/env python3

import argparse
import re
import subprocess
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
TEST_DIR = PROJECT_DIR / "testbench" / "test"
TOP_MODULE = "tb_top"
FILE_LIST_PATH = "testbench/Files.f"
DEFAULT_TEST_NAME = "mmu_base_test"


def find_registered_tests():
    pattern = re.compile(r"uvm_component_utils(?:_begin)?\s*\(\s*([A-Za-z_][A-Za-z0-9_$]*)")
    tests = set()
    for sv_file in TEST_DIR.rglob("*.svh"):
        text = sv_file.read_text(encoding="utf-8", errors="ignore")
        tests.update(pattern.findall(text))
    return sorted(tests)


def run_make(args):
    cmd = ["make"] + args
    try:
        return subprocess.run(cmd, cwd=PROJECT_DIR).returncode
    except FileNotFoundError as exc:
        missing = exc.filename or cmd[0]
        print(f"ERROR: required command not found in PATH: {missing}", file=sys.stderr)
        return 2


def build_parser():
    parser = argparse.ArgumentParser(description="MMU VCS/Verdi helper wrapper")
    parser.add_argument("test_name", nargs="?", default=DEFAULT_TEST_NAME, help="UVM test name to run")
    parser.add_argument("--seed", default="1", help="Simulation seed")
    parser.add_argument("--plus-args", default="", help="Extra plusargs passed through to Makefile")
    parser.add_argument("--list", action="store_true", help="List registered UVM tests and exit")
    parser.add_argument("--info", action="store_true", help="Print MMU compile wrapper info and exit")
    parser.add_argument("--compile-only", action="store_true", help="Run make comp and stop")
    parser.add_argument("--run-only", action="store_true", help="Skip compile and run the test only")
    parser.add_argument("--verdi-only", action="store_true", help="Open Verdi for the selected test")
    parser.add_argument("--open-verdi", action="store_true", help="Open Verdi after a successful run")
    parser.add_argument("--verdi-on-fail", action="store_true", help="Open Verdi if the run fails")
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    if args.list:
        for test_name in find_registered_tests():
            print(test_name)
        return 0

    if args.info:
        print(f"project_dir={PROJECT_DIR}")
        print(f"top_module={TOP_MODULE}")
        print(f"file_list={FILE_LIST_PATH}")
        return 0

    if args.verdi_only:
        return run_make(["verdi", f"TEST_NAME={args.test_name}"])

    if not args.run_only:
        rc = run_make(["comp"])
        if rc != 0:
            return rc
        if args.compile_only:
            return 0

    run_args = ["run", f"TEST_NAME={args.test_name}", f"SEED={args.seed}"]
    if args.plus_args:
        run_args.append(f"PLUS_ARGS={args.plus_args}")
    rc = run_make(run_args)

    if args.open_verdi or (args.verdi_on_fail and rc != 0):
        verdi_rc = run_make(["verdi", f"TEST_NAME={args.test_name}"])
        if rc == 0:
            rc = verdi_rc

    return rc


if __name__ == "__main__":
    sys.exit(main())
