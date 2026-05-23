#!/usr/bin/env python3
"""Replay L2TLB Phase 6G evidence manifest rows."""

import argparse
import subprocess
import sys
import time
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
LOG_DIR = PROJECT_DIR / "output" / "logs"


class ManifestRow:
    def __init__(self, fields, line_no):
        self.line_no = line_no
        self.case_id = fields[0].strip()
        self.phase = fields[1].strip()
        self.test = fields[2].strip()
        self.seed = fields[3].strip()
        self.status = fields[4].strip()
        self.accepted_warnings = fields[5].strip()
        self.required_reports = fields[6].strip()
        self.required_counters = fields[7].strip()
        self.required_covers = fields[8].strip()
        self.related_ids = fields[9].strip()
        self.notes = fields[10].strip()


class ReplayResult:
    def __init__(self, row, command, rc, duration_s, dry_run):
        self.row = row
        self.command = command
        self.rc = rc
        self.duration_s = duration_s
        self.dry_run = dry_run

    @property
    def passed(self):
        return self.rc == 0

    @property
    def log_path(self):
        if self.command_mode() == "run_cov":
            return LOG_DIR / ("%s_%s_cov.log" % (self.row.test, self.row.seed))
        return LOG_DIR / ("%s_%s.log" % (self.row.test, self.row.seed))

    def command_mode(self):
        for item in self.command:
            if item in ("run", "run_check", "run_cov", "run_batch", "debug"):
                return item
        return "run_check"


def parse_status_set(raw):
    return set(item.strip() for item in raw.replace(",", " ").split() if item.strip())


def resolve_path(raw, must_exist=False):
    path = Path(raw)
    if path.is_absolute():
        return path
    cwd_path = (Path.cwd() / path).resolve()
    project_path = (PROJECT_DIR / path).resolve()
    if must_exist:
        if cwd_path.exists():
            return cwd_path
        return project_path
    return cwd_path


def load_manifest(path, statuses):
    rows = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_no, raw in enumerate(handle, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            fields = line.split("|", 10)
            if len(fields) != 11:
                raise ValueError("%s:%d: expected 11 pipe-delimited fields" % (path, line_no))
            row = ManifestRow(fields, line_no)
            if row.status in statuses:
                if not row.test or not row.seed:
                    raise ValueError("%s:%d: missing test or seed" % (path, line_no))
                rows.append(row)
    if not rows:
        raise ValueError("No manifest rows selected from %s" % path)
    return rows


def build_command(args, row):
    cmd = [
        "make",
        args.mode,
        "TEST_NAME=%s" % row.test,
        "SEED=%s" % row.seed,
        "VERBOSITY=%s" % args.verbosity,
        "TIMEOUT=%s" % args.timeout,
        "UVM_ERR_ONLY=%s" % args.uvm_err_only,
        "UVM_CONFIG_DB_TRACE=%s" % args.uvm_config_db_trace,
        "RUN_DIR=%s" % args.run_dir,
    ]
    if args.plus_args:
        cmd.append("PLUS_ARGS=%s" % args.plus_args)
    if args.log_status_max_hits:
        cmd.append("LOG_STATUS_MAX_HITS=%s" % args.log_status_max_hits)
    return cmd


def run_row(args, row):
    cmd = build_command(args, row)
    print("=== l2tlb phase6g replay: %s %s seed=%s status=%s ===" % (row.case_id, row.test, row.seed, row.status))
    if args.dry_run:
        print("DRY-RUN: %s" % " ".join(cmd))
        return ReplayResult(row, cmd, 0, 0.0, True)
    start = time.monotonic()
    completed = subprocess.run(cmd, cwd=str(PROJECT_DIR))
    duration_s = time.monotonic() - start
    return ReplayResult(row, cmd, completed.returncode, duration_s, False)


def write_summary(path, manifest, statuses, results, dry_run):
    path.parent.mkdir(parents=True, exist_ok=True)
    total = len(results)
    passed = sum(1 for item in results if item.passed)
    failed = total - passed
    with path.open("w", encoding="utf-8") as handle:
        handle.write("L2TLB Phase6G manifest replay summary\n")
        handle.write("manifest: %s\n" % manifest)
        handle.write("statuses: %s\n" % " ".join(sorted(statuses)))
        handle.write("dry_run: %s\n" % ("1" if dry_run else "0"))
        handle.write("total_rows: %d\n" % total)
        handle.write("passed_rows: %d\n" % passed)
        handle.write("failed_rows: %d\n" % failed)
        handle.write("\n")
        for result in results:
            status = "PASS" if result.passed else "FAIL"
            row = result.row
            handle.write(
                "%s case=%s phase=%s test=%s seed=%s disposition=%s duration_s=%.2f log=%s\n"
                % (status, row.case_id, row.phase, row.test, row.seed, row.status, result.duration_s, result.log_path)
            )
            handle.write("  cmd=%s\n" % " ".join(result.command))
            if not result.passed:
                handle.write("  rc=%d\n" % result.rc)


def build_parser():
    parser = argparse.ArgumentParser(description="Replay L2TLB Phase6G evidence manifest rows")
    parser.add_argument("--manifest", required=True, help="Phase6G evidence manifest")
    parser.add_argument("--summary", required=True, help="Replay summary path")
    parser.add_argument("--mode", default="run_check", choices=("run", "run_check", "run_cov"), help="Make target")
    parser.add_argument(
        "--statuses",
        default="closure,negative,debug,waived,future_exact_model",
        help="Manifest statuses to replay. Include blocked explicitly when investigating the open timeout/fairness failure.",
    )
    parser.add_argument("--verbosity", default="UVM_MEDIUM")
    parser.add_argument("--timeout", default="10000000")
    parser.add_argument("--uvm-err-only", default="1")
    parser.add_argument("--uvm-config-db-trace", default="0")
    parser.add_argument("--run-dir", default=str(PROJECT_DIR / "output"))
    parser.add_argument("--plus-args", default="")
    parser.add_argument("--log-status-max-hits", default="")
    parser.add_argument("--fail-fast", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    manifest = resolve_path(args.manifest, must_exist=True)
    summary = resolve_path(args.summary)
    args.run_dir = str(resolve_path(args.run_dir))

    statuses = parse_status_set(args.statuses)
    try:
        rows = load_manifest(manifest, statuses)
    except (OSError, ValueError) as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 2

    results = []
    for row in rows:
        result = run_row(args, row)
        results.append(result)
        if args.fail_fast and not result.passed:
            print("=== l2tlb phase6g replay fail-fast: %s seed=%s rc=%d ===" % (row.test, row.seed, result.rc))
            break

    write_summary(summary, manifest, statuses, results, args.dry_run)
    passed = sum(1 for item in results if item.passed)
    failed = len(results) - passed
    print("L2TLB Phase6G replay: PASS=%d FAIL=%d TOTAL=%d" % (passed, failed, len(results)))
    print("Summary: %s" % summary)
    return 0 if results and failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
