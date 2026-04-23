#!/usr/bin/env python3

import os
import subprocess
import argparse
import re
from pathlib import Path

# --- Configuration ---
VCS_OPTIONS = [
    "-full64",
    "-sverilog",
    "+v2k",
    "-timescale=1ns/1ps",
    "-debug_access+all",  # Enable all debug capabilities for Verdi
    "+define+VCS_SIM",    # Define for any VCS-specific code
    "-L-EARLY",           # For certain libraries, if needed
    # Add UVM source files and necessary incdirs
    "+incdir+$UVM_HOME",
    "$UVM_HOME/uvm_pkg.sv",
    "$UVM_HOME/dpi/uvm_dpi.cc",
    "-lca" # Limited Customer Availability features, often needed for advanced UVM
]

SIMV_OPTIONS = [
    "+UVM_NO_RELNOTES",
]

FILE_LIST_PATH = "testbench/Files.f"
TEST_DIR = Path("testbench/test")
OUTPUT_DIR = Path("output_vcs")

def get_all_tests():
    """Scans the test directory to find all test names from .svh files."""
    tests = []
    for svh_file in sorted(TEST_DIR.rglob('*.svh')):
        # Exclude base classes or non-test files
        if 'test_base' not in svh_file.name:
            # Extract test name from filename
            test_name = svh_file.stem
            tests.append(test_name)
    return tests

def run_simulation(test_name, compile_only=False):
    """Compiles the environment and runs a single test."""
    print(f"--- Starting process for test: {test_name} ---")

    # --- Environment Check ---
    for var in ['PROJECT_DIR', 'UVM_HOME']:
        if var not in os.environ:
            print(f"[ERROR] Environment variable '{var}' is not set. Please source your setup script.")
            return False

    # --- Compilation ---
    # We compile only once. We can check if simv exists.
    simv_path = Path("simv")
    if not simv_path.exists():
        print("[INFO] 'simv' not found. Starting compilation...")
        
        # Create output directory for logs
        OUTPUT_DIR.mkdir(exist_ok=True)
        compile_log = OUTPUT_DIR / "compile.log"

        # Construct VCS command
        hpdcache_rtl_incdir = f"+incdir+{os.environ['PROJECT_DIR']}/modules/hpdcache/rtl/include"
        hpdcache_pkg_file = f"{os.environ['PROJECT_DIR']}/modules/hpdcache_params/hpdcache_params_pkg.sv"
        hpdcache_flist = f"{os.environ['PROJECT_DIR']}/modules/hpdcache/rtl/hpdcache.Flist"

        vcs_cmd = (
            ["vcs"] +
            VCS_OPTIONS +
            [hpdcache_rtl_incdir] +
            [hpdcache_pkg_file] +
            ["-f", hpdcache_flist] +
            ["-f", FILE_LIST_PATH] +
            ["-o", str(simv_path)] +
            ["-l", str(compile_log)]
        )
        
        # Add DV_UTILS path if it exists
        dv_utils_path = Path(os.environ['PROJECT_DIR']) / "modules/dv_utils/src"
        if dv_utils_path.exists():
            vcs_cmd.insert(1, f"+incdir+{dv_utils_path}")

        print(f"[CMD] {' '.join(vcs_cmd)}")

        try:
            subprocess.run(vcs_cmd, check=True, universal_newlines=True)
            print(f"[SUCCESS] Compilation finished successfully. Log: {compile_log}")
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print(f"[ERROR] Compilation failed. Check the log for details: {compile_log}")
            print(f"  > {e}")
            return False
    else:
        print("[INFO] 'simv' executable already exists. Skipping compilation.")

    if compile_only:
        return True

    # --- Simulation ---
    print(f"[INFO] Starting simulation for test: {test_name}")
    run_log = OUTPUT_DIR / f"{test_name}.log"
    fsdb_file = OUTPUT_DIR / f"{test_name}.fsdb"

    # Construct simv command
    simv_cmd = (
        [f"./{simv_path}"] +
        SIMV_OPTIONS +
        [f"+UVM_TESTNAME={test_name}"] +
        [f"+vcs+fsdbon+{fsdb_file}"] + # FSDB dumping command
        ["-l", str(run_log)]
    )

    print(f"[CMD] {' '.join(simv_cmd)}")

    try:
        subprocess.run(simv_cmd, check=True, universal_newlines=True)
        print(f"[SUCCESS] Simulation for '{test_name}' finished. Log: {run_log}, Waveform: {fsdb_file}")
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"[ERROR] Simulation for '{test_name}' failed. Check the log for details: {run_log}")
        print(f"  > {e}")
        return False
        
    return True


def main():
    parser = argparse.ArgumentParser(description="Run VCS+Verdi simulations for the hpdcache project.")
    parser.add_argument(
        "test_name",
        nargs='?',
        default=None,
        help="Optional: The name of a single test to run. If not provided, all tests will be run."
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List all available tests and exit."
    )
    parser.add_argument(
        "--compile",
        action="store_true",
        help="Compile only, do not run simulation."
    )

    args = parser.parse_args()

    all_tests = get_all_tests()

    if args.list:
        print("--- Available Tests ---")
        for test in all_tests:
            print(test)
        return

    if args.test_name:
        if args.test_name in all_tests:
            run_simulation(args.test_name, args.compile)
        else:
            print(f"[ERROR] Test '{args.test_name}' not found.")
            print("Use --list to see all available tests.")
    else:
        print(f"--- Running all {len(all_tests)} tests ---")
        successful_runs = 0
        failed_runs = []
        for i, test in enumerate(all_tests):
            print(f"\n[{i+1}/{len(all_tests)}] === TEST: {test} ===")
            if run_simulation(test, args.compile):
                successful_runs += 1
            else:
                failed_runs.append(test)
        
        print("\n--- Summary ---")
        print(f"Total tests: {len(all_tests)}")
        print(f"Successful: {successful_runs}")
        print(f"Failed: {len(failed_runs)}")
        if failed_runs:
            print("Failed tests:")
            for test in failed_runs:
                print(f"  - {test}")


if __name__ == "__main__":
    main()
