#!/usr/bin/env python3
"""Run PTW RTL code coverage flow.

The runner orchestrates existing Makefile targets. It does not reimplement VCS,
run_test.py, URG, or the Stage 4 parser. Use --dry-run for the Stage 5 no-license
acceptance path.
"""

import argparse
import datetime as _dt
import fnmatch
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


PROJECT_DIR = Path(__file__).resolve().parents[1]
STATE_SEQUENCE = [
    "INIT",
    "CHECK_ENV",
    "CHECK_TEST_REGISTRY",
    "CHECK_HIER_CFG",
    "CLEAN_OUTPUT",
    "COMPILE",
    "RUN_FUNCTIONAL_GATE",
    "RUN_COVERAGE_REGRESSIONS",
    "GENERATE_URG",
    "PARSE_REPORT",
    "WRITE_MANIFEST",
    "DONE",
    "FAILED",
]
FAIL_PATTERNS = [
    "UVM_FATAL",
    "Segmentation fault",
    "SIGSEGV",
    "VCS internal error",
    "CovErrorException",
    "License checkout failed",
    "Unable to checkout",
    "No such feature exists",
]


class RunnerError(RuntimeError):
    def __init__(self, reason: str, message: str, state: str = "INIT") -> None:
        super().__init__(message)
        self.reason = reason
        self.state = state


def now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).astimezone().isoformat(timespec="seconds")


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(PROJECT_DIR))
    except ValueError:
        return str(path)


def read_json(path: Path) -> Dict[str, object]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def strip_inline_comment(raw: str) -> str:
    out: List[str] = []
    in_single = False
    in_double = False
    for char in raw:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            break
        out.append(char)
    return "".join(out).strip()


def load_list(path: Path) -> List[Dict[str, str]]:
    entries: List[Dict[str, str]] = []
    if not path.is_file():
        raise RunnerError("list_missing", "regression list not found: {}".format(path), "CHECK_TEST_REGISTRY")
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_inline_comment(raw)
        if not line:
            continue
        tokens = shlex.split(line)
        if tokens:
            entries.append({"test": tokens[0], "plus_args": " ".join(tokens[1:])})
    if not entries:
        raise RunnerError("list_empty", "regression list has no tests: {}".format(path), "CHECK_TEST_REGISTRY")
    return entries


def registered_tests() -> List[str]:
    proc = subprocess.run(
        ["python3", "scripts/run_test.py", "--list"],
        cwd=str(PROJECT_DIR),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if proc.returncode != 0:
        raise RunnerError("registry_check_fail", proc.stderr or proc.stdout, "CHECK_TEST_REGISTRY")
    tests: List[str] = []
    in_tests = False
    for raw in proc.stdout.splitlines():
        line = raw.strip()
        if line == "Registered UVM tests:":
            in_tests = True
            continue
        if line == "Supported test directory aliases:":
            break
        if in_tests and line:
            tests.append(line)
    return tests


def git_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=str(PROJECT_DIR),
            stderr=subprocess.DEVNULL,
            universal_newlines=True,
        ).strip()
    except Exception:
        return "unknown"


def option_value(cmd: Sequence[object], option: str) -> Optional[str]:
    parts = [str(item) for item in cmd]
    for idx, item in enumerate(parts):
        if item == option and idx + 1 < len(parts):
            return parts[idx + 1]
    return None


def replace_option_value(cmd: Sequence[object], option: str, value: str) -> List[str]:
    parts = [str(item) for item in cmd]
    for idx, item in enumerate(parts):
        if item == option and idx + 1 < len(parts):
            parts[idx + 1] = value
            return parts
    return parts


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run PTW RTL code coverage flow")
    parser.add_argument("--profile", default="default", choices=["quick", "default", "full", "signoff"])
    parser.add_argument("--profile-file", default="scripts/ptw_code_coverage_profiles.json")
    parser.add_argument("--functional-gate-rules", default="scripts/ptw_functional_gate_rules.json")
    parser.add_argument("--cov-root", default="output/ptw_cov")
    parser.add_argument("--hier-cfg", default="scripts/ptw_cov_hier.cfg")
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--force-rebuild", action="store_true", default=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--functional-gate-mode", default="run", choices=["run", "reuse", "skip"])
    parser.add_argument("--functional-gate-evidence")
    parser.add_argument("--skip-functional-gate", action="store_true")
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--skip-run", action="store_true")
    parser.add_argument("--skip-urg", action="store_true")
    parser.add_argument("--parse-only", action="store_true")
    parser.add_argument("--keep-going-on-regress-fail", action="store_true")
    parser.add_argument("--timeout", default="10000000")
    parser.add_argument("--verbosity", default="UVM_MEDIUM")
    parser.add_argument("--uvm-err-only", default="0")
    parser.add_argument("--extra-plus-args", default="")
    return parser


class Runner:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        if args.skip_functional_gate:
            self.args.functional_gate_mode = "skip"
        self.profile_file = self.resolve(args.profile_file)
        self.gate_rules_file = self.resolve(args.functional_gate_rules)
        self.cov_root = self.resolve(args.cov_root)
        self.hier_cfg = self.resolve(args.hier_cfg)
        self.cov_db = self.cov_root / "simv_ptw.vdb"
        self.base_db = self.cov_root / "simv_ptw.compile.vdb"
        self.stamp = self.cov_root / ".simv_ptw.compile.stamp"
        self.urg_report = self.cov_root / "urgReport"
        self.merged_db = self.cov_root / "merged_ptw.vdb"
        self.urg_log = self.cov_root / "urg_ptw.log"
        self.run_log = self.cov_root / "run_ptw_code_coverage.log"
        self.manifest_path = self.cov_root / "ptw_cov_manifest.json"
        self.summary_md = self.cov_root / "ptw_code_coverage_summary.md"
        self.summary_json = self.cov_root / "ptw_code_coverage_summary.json"
        self.commands: List[Dict[str, object]] = []
        self.states: List[Dict[str, str]] = []
        self.errors: List[Dict[str, str]] = []
        self.coverage_runs: List[Dict[str, object]] = []
        self.expanded_entries: List[Dict[str, str]] = []
        self.deduped_entries: List[Dict[str, str]] = []
        self.start_time = now()
        self.final_result_line = ""
        self.functional_gate: Dict[str, object] = {}

    def resolve(self, raw: str) -> Path:
        path = Path(raw)
        return path if path.is_absolute() else PROJECT_DIR / path

    def log(self, text: str) -> None:
        self.cov_root.mkdir(parents=True, exist_ok=True)
        with self.run_log.open("a", encoding="utf-8") as handle:
            handle.write(text.rstrip() + "\n")

    def enter(self, state: str) -> None:
        self.states.append({"state": state, "time": now(), "event": "enter"})
        self.log("STATE {} enter".format(state))

    def leave(self, state: str) -> None:
        self.states.append({"state": state, "time": now(), "event": "leave"})
        self.log("STATE {} leave".format(state))

    def run_cmd(self, state: str, cmd: Sequence[str], check: bool = True) -> int:
        entry = {"state": state, "cmd": list(cmd), "dry_run": self.args.dry_run, "return_code": None}
        self.commands.append(entry)
        self.log("CMD [{}] {}".format(state, " ".join(shlex.quote(str(x)) for x in cmd)))
        if self.args.dry_run:
            entry["return_code"] = 0
            return 0
        proc = subprocess.run(list(cmd), cwd=str(PROJECT_DIR))
        entry["return_code"] = proc.returncode
        if check and proc.returncode != 0:
            raise RunnerError("command_failed", "command failed rc={} cmd={}".format(proc.returncode, cmd), state)
        return proc.returncode

    def validate_args(self) -> None:
        if self.args.jobs != 1:
            raise RunnerError("jobs_not_one", "--jobs must be 1 for aggregate run_cov flow", "INIT")
        if self.args.keep_going_on_regress_fail and self.args.profile == "signoff":
            raise RunnerError("signoff_keep_going_forbidden", "--keep-going-on-regress-fail is not allowed for signoff", "INIT")
        if self.args.parse_only and not self.urg_report.is_dir():
            raise RunnerError("parse_only_missing_urg", "--parse-only requires existing urgReport", "INIT")
        if self.args.skip_run and not self.nonempty_dir(self.cov_db):
            raise RunnerError("skip_run_missing_vdb", "--skip-run requires non-empty aggregate VDB", "INIT")
        if self.args.functional_gate_mode == "reuse" and not self.args.functional_gate_evidence:
            raise RunnerError("functional_gate_evidence_missing", "reuse mode requires --functional-gate-evidence", "INIT")

    def nonempty_dir(self, path: Path) -> bool:
        return path.is_dir() and any(path.rglob("*"))

    def check_hier_cfg(self) -> None:
        if not self.hier_cfg.is_file():
            raise RunnerError("hier_cfg_missing", "missing hier cfg: {}".format(self.hier_cfg), "CHECK_HIER_CFG")
        text = self.hier_cfg.read_text(encoding="utf-8", errors="ignore")
        if "+tree tb_top.u_dut.x_ct_mmu_ptw" not in text:
            raise RunnerError("non_ptw_hier_cfg", "COV_HIER_CFG is not PTW-only: {}".format(self.hier_cfg), "CHECK_HIER_CFG")
        if "+tree tb_top\n" in text or "+tree tb_top\r\n" in text:
            raise RunnerError("non_ptw_hier_cfg", "hier cfg contains full tb_top scope", "CHECK_HIER_CFG")

    def load_profile(self) -> Tuple[Dict[str, object], Dict[str, object]]:
        data = read_json(self.profile_file)
        profiles = data.get("profiles", {})
        if self.args.profile not in profiles:
            raise RunnerError("profile_invalid", "unknown profile {}".format(self.args.profile), "INIT")
        return data, profiles[self.args.profile]

    def expand_profile(self, profile: Dict[str, object]) -> None:
        registered = set(registered_tests())
        seen: Dict[Tuple[str, str], Dict[str, str]] = {}
        duplicate_errors: List[str] = []
        for run in profile.get("runs", []):
            list_rel = str(run["list"])
            list_path = self.resolve(list_rel)
            tests = load_list(list_path)
            seeds = [str(seed) for seed in run.get("seeds", [])]
            if not seeds:
                raise RunnerError("profile_invalid", "run has no seeds: {}".format(run.get("name")), "CHECK_TEST_REGISTRY")
            run_entries: List[Dict[str, str]] = []
            for item in tests:
                test = item["test"]
                if test not in registered:
                    raise RunnerError("test_not_registered", "{} not registered from {}".format(test, list_rel), "CHECK_TEST_REGISTRY")
                for seed in seeds:
                    entry = {
                        "test": test,
                        "seed": seed,
                        "list": list_rel,
                        "plus_args": item["plus_args"],
                        "run_name": str(run.get("name", "")),
                    }
                    key = (test, seed)
                    previous = seen.get(key)
                    if previous is not None:
                        if previous.get("plus_args", "") == item["plus_args"]:
                            self.deduped_entries.append({
                                "test": test,
                                "seed": seed,
                                "kept_from": previous["list"],
                                "dropped_from": list_rel,
                            })
                            continue
                        duplicate_errors.append("{} seed={} lists={} {}".format(test, seed, previous["list"], list_rel))
                        continue
                    seen[key] = entry
                    run_entries.append(entry)
                    self.expanded_entries.append(entry)
            for seed in seeds:
                list_base = Path(list_rel).name
                regress_name = "ptw_cov_{}_{}_{}".format(self.args.profile, list_base, seed)
                summary = PROJECT_DIR / "output" / "regression" / regress_name / "summary.txt"
                self.coverage_runs.append({
                    "name": run.get("name"),
                    "list": list_rel,
                    "seeds": [seed],
                    "regress_name": regress_name,
                    "regress_mode": "run_cov",
                    "summary": rel(summary),
                    "status": "PLANNED",
                    "purpose": run.get("purpose", ""),
                })
        if duplicate_errors:
            raise RunnerError("duplicate_cov_tag", "duplicate (test, seed) with different plusargs: {}".format("; ".join(duplicate_errors[:10])), "CHECK_TEST_REGISTRY")

    def clean_output(self) -> None:
        self.cov_root.mkdir(parents=True, exist_ok=True)
        keep = {self.run_log.name}
        patterns = ["*.vdb", "*.vdb.failed.*", "*.vdb.stale.*", "urgReport", "merged*", "urg_ptw.log",
                    "ptw_extract_code_coverage.log", "ptw_code_coverage_summary.md",
                    "ptw_code_coverage_summary.json", "ptw_cov_manifest.json", ".simv_ptw.compile.stamp"]
        for item in list(self.cov_root.iterdir()):
            if item.name in keep:
                continue
            if not any(fnmatch.fnmatch(item.name, pattern) for pattern in patterns):
                continue
            if self.args.dry_run:
                self.log("DRY_RUN clean candidate {}".format(item))
                continue
            try:
                if item.is_dir():
                    shutil.rmtree(str(item))
                else:
                    item.unlink()
            except OSError:
                stale = item.with_name(item.name + ".stale." + _dt.datetime.now().strftime("%Y%m%d_%H%M%S"))
                item.rename(stale)

    def cov_vars(self) -> List[str]:
        return [
            "COV_HIER_CFG={}".format(str(self.hier_cfg)),
            "COV_DIR={}".format(str(self.cov_root)),
            "COV_DB_DIR={}".format(str(self.cov_db)),
            "COV_BASE_DB_DIR={}".format(str(self.base_db)),
            "COV_BASELINE_STAMP={}".format(str(self.stamp)),
        ]

    def comp_cmd(self) -> List[str]:
        return ["make", "comp_all", "COV_FORCE_REBUILD=1"] + self.cov_vars()

    def regress_cmd(self, run: Dict[str, object]) -> List[str]:
        cmd = [
            "make", "regress",
            "LIST={}".format(run["list"]),
            "REGRESS_MODE=run_cov",
            "REGRESS_NAME={}".format(run["regress_name"]),
            "REGRESS_SEEDS={}".format(" ".join(run["seeds"])),
            "REGRESS_JOBS=1",
            "REGRESS_SUMMARY={}".format(str(PROJECT_DIR / run["summary"])),
            "UVM_ERR_ONLY={}".format(self.args.uvm_err_only),
            "UVM_CONFIG_DB_TRACE=0",
            "TIMEOUT={}".format(self.args.timeout),
            "VERBOSITY={}".format(self.args.verbosity),
        ]
        if self.args.extra_plus_args:
            cmd.append("PLUS_ARGS={}".format(self.args.extra_plus_args))
        return cmd + self.cov_vars()

    def urg_cmd(self) -> List[str]:
        return ["make", "cov"] + self.cov_vars() + [
            "URG_REPORT_DIR={}".format(str(self.urg_report)),
            "URG_MERGED_DB={}".format(str(self.merged_db)),
            "URG_LOG={}".format(str(self.urg_log)),
        ]

    def parser_cmd(self) -> List[str]:
        return [
            "python3", "scripts/ptw_extract_code_coverage.py",
            "--urg-report", str(self.urg_report),
            "--scope", "ptw_core",
            "--hier-cfg", str(self.hier_cfg),
            "--cov-db", str(self.cov_db),
            "--merged-db", str(self.merged_db),
            "--out-md", str(self.summary_md),
            "--out-json", str(self.summary_json),
            "--manifest", str(self.manifest_path),
            "--profile", self.args.profile,
        ]

    def build_functional_gate(self) -> Dict[str, object]:
        mode = self.args.functional_gate_mode
        rules = read_json(self.gate_rules_file)
        log_dir_raw = str(rules.get("run_mode", {}).get("canonical_log_dir", "output/ptw_functional_gate/logs"))
        log_dir_path = self.resolve(log_dir_raw)
        if mode == "skip":
            return {
                "status": "SKIPPED",
                "mode": "skip",
                "generated_at": now(),
                "git_commit": git_commit(),
                "gate_script": rules.get("gate_script"),
                "gate_command": [],
                "log_dirs": [],
                "log_pattern": rules.get("log_separation", {}).get("functional_log_pattern"),
                "closure_csv": None,
                "closure_report": None,
                "regressions": [],
                "evidence_source": None,
                "reason": "functional_gate_skipped",
            }
        if mode == "reuse":
            evidence_path = self.resolve(self.args.functional_gate_evidence)
            if not evidence_path.is_file():
                raise RunnerError("functional_gate_evidence_missing", "missing reuse evidence: {}".format(evidence_path), "RUN_FUNCTIONAL_GATE")
            evidence = read_json(evidence_path) if evidence_path.suffix.lower() == ".json" else {"status": "REUSED", "evidence_path": str(evidence_path)}
            status = str(evidence.get("status", "REUSED"))
            if status not in {"PASS", "REUSED"}:
                raise RunnerError("functional_gate_reuse_invalid", "reuse evidence is not PASS/REUSED", "RUN_FUNCTIONAL_GATE")
            gate = dict(evidence)
            gate["status"] = "REUSED"
            gate["mode"] = "reuse"
            gate["evidence_source"] = str(evidence_path)
            return gate
        regressions = []
        for item in rules.get("run_mode", {}).get("regressions", []):
            regressions.append({
                "role": item["role"],
                "list": item["list"],
                "seeds": item["seeds"],
                "regress_name": item["regress_name"],
                "regress_mode": "run_check",
                "log_dir": rel(log_dir_path),
                "summary": "output/regression/{}/summary.txt".format(item["regress_name"]),
            })
        gate_command = replace_option_value(
            rules.get("run_mode", {}).get("gate_command", []),
            "--log-dir",
            str(log_dir_path),
        )
        closure_csv = option_value(gate_command, "--csv")
        closure_report = option_value(gate_command, "--report")
        if not closure_csv or not closure_report:
            raise RunnerError(
                "functional_gate_rules_invalid",
                "run_mode.gate_command must include --csv and --report",
                "RUN_FUNCTIONAL_GATE",
            )
        return {
            "status": "PLANNED" if self.args.dry_run else "PASS",
            "mode": "run",
            "generated_at": now(),
            "git_commit": git_commit(),
            "gate_script": rules.get("gate_script"),
            "gate_command": gate_command,
            "log_dirs": [rel(log_dir_path)],
            "log_pattern": rules.get("log_separation", {}).get("functional_log_pattern"),
            "closure_csv": closure_csv,
            "closure_report": closure_report,
            "regressions": regressions,
            "evidence_source": "generated_by_runner",
        }

    def run_functional_gate(self) -> None:
        self.functional_gate = self.build_functional_gate()
        if self.args.functional_gate_mode != "run":
            return
        rules = read_json(self.gate_rules_file)
        log_dir_raw = str(rules.get("run_mode", {}).get("canonical_log_dir", "output/ptw_functional_gate/logs"))
        log_dir_path = self.resolve(log_dir_raw)
        if not self.args.dry_run:
            log_dir_path.mkdir(parents=True, exist_ok=True)
        for item in rules.get("run_mode", {}).get("regressions", []):
            cmd = [
                "make", "regress",
                "LIST={}".format(item["list"]),
                "REGRESS_MODE=run_check",
                "REGRESS_NAME={}".format(item["regress_name"]),
                "REGRESS_SEEDS={}".format(" ".join(item["seeds"])),
                "REGRESS_JOBS=1",
                "LOG_DIR={}".format(str(log_dir_path)),
                "UVM_ERR_ONLY=0",
                "UVM_CONFIG_DB_TRACE=0",
            ]
            self.run_cmd("RUN_FUNCTIONAL_GATE", cmd)
        self.run_cmd("RUN_FUNCTIONAL_GATE", self.functional_gate.get("gate_command", []))

    def check_regression_summary(self, run: Dict[str, object]) -> None:
        path = PROJECT_DIR / str(run["summary"])
        if not path.is_file():
            raise RunnerError("regression_summary_missing", "missing summary {}".format(path), "RUN_COVERAGE_REGRESSIONS")
        data: Dict[str, str] = {}
        for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if ":" in raw:
                key, value = raw.split(":", 1)
                data[key.strip()] = value.strip()
        if data.get("mode") != "run_cov" or data.get("failed_runs") != "0" or data.get("pass_rate") != "1.0000":
            raise RunnerError("coverage_regression_failed", "coverage regression summary is not clean: {}".format(path), "RUN_COVERAGE_REGRESSIONS")

    def scan_coverage_logs(self) -> None:
        log_dir = PROJECT_DIR / "output" / "logs"
        for entry in self.expanded_entries:
            path = log_dir / "{}_{}_cov.log".format(entry["test"], entry["seed"])
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for pattern in FAIL_PATTERNS:
                if pattern.lower() in text.lower():
                    raise RunnerError("coverage_log_fail", "{} contains {}".format(path, pattern), "RUN_COVERAGE_REGRESSIONS")

    def manifest(self, status: str, reason: str) -> Dict[str, object]:
        return {
            "schema_version": "ptw_code_coverage_manifest_v1",
            "status": status,
            "reason": reason,
            "profile": self.args.profile,
            "dry_run": self.args.dry_run,
            "git_commit": git_commit(),
            "start_time": self.start_time,
            "end_time": now(),
            "state_sequence": STATE_SEQUENCE,
            "states": self.states,
            "cov_hier_cfg": rel(self.hier_cfg),
            "cov_root": rel(self.cov_root),
            "cov_vars": {
                "PTW_COV_ROOT": rel(self.cov_root),
                "PTW_COV_DB": rel(self.cov_db),
                "PTW_COV_BASE_DB": rel(self.base_db),
                "PTW_COV_STAMP": rel(self.stamp),
                "PTW_URG_REPORT": rel(self.urg_report),
                "PTW_URG_MERGED_DB": rel(self.merged_db),
                "PTW_URG_LOG": rel(self.urg_log),
            },
            "functional_gate": self.functional_gate,
            "coverage_runs": self.coverage_runs,
            "run_manifest": {
                "profile": self.args.profile,
                "runs": self.coverage_runs,
                "deduped_entries": self.deduped_entries,
            },
            "expanded_run_count": len(self.expanded_entries),
            "deduped_entries": self.deduped_entries,
            "commands": self.commands,
            "errors": self.errors,
        }

    def write_manifest(self, status: str, reason: str) -> None:
        self.cov_root.mkdir(parents=True, exist_ok=True)
        self.manifest_path.write_text(json.dumps(self.manifest(status, reason), indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def final_line(self, status: str, reason: str) -> str:
        return "PTW_CODE_COVERAGE_RESULT status={} reason={} profile={} dry_run={} manifest={}".format(
            status, reason, self.args.profile, int(self.args.dry_run), rel(self.manifest_path)
        )

    def execute(self) -> int:
        self.cov_root.mkdir(parents=True, exist_ok=True)
        self.run_log.write_text("PTW code coverage runner start {}\n".format(self.start_time), encoding="utf-8")
        status = "FAIL"
        reason = "runner_failed"
        try:
            self.enter("INIT")
            self.validate_args()
            profile_data, profile = self.load_profile()
            self.leave("INIT")

            self.enter("CHECK_ENV")
            self.run_cmd("CHECK_ENV", ["make", "check_env"])
            self.leave("CHECK_ENV")

            self.enter("CHECK_TEST_REGISTRY")
            self.expand_profile(profile)
            self.leave("CHECK_TEST_REGISTRY")

            self.enter("CHECK_HIER_CFG")
            self.check_hier_cfg()
            self.leave("CHECK_HIER_CFG")

            self.enter("CLEAN_OUTPUT")
            if not self.args.parse_only:
                self.clean_output()
            self.leave("CLEAN_OUTPUT")

            self.enter("COMPILE")
            if not (self.args.skip_compile or self.args.parse_only):
                self.run_cmd("COMPILE", self.comp_cmd())
            self.leave("COMPILE")

            self.enter("RUN_FUNCTIONAL_GATE")
            self.run_functional_gate()
            self.leave("RUN_FUNCTIONAL_GATE")

            self.enter("RUN_COVERAGE_REGRESSIONS")
            if not (self.args.skip_run or self.args.parse_only):
                for run in self.coverage_runs:
                    rc = self.run_cmd("RUN_COVERAGE_REGRESSIONS", self.regress_cmd(run), check=not self.args.keep_going_on_regress_fail)
                    run["status"] = "PLANNED" if self.args.dry_run else "PASS" if rc == 0 else "FAIL"
                    if not self.args.dry_run and rc == 0:
                        self.check_regression_summary(run)
                if not self.args.dry_run:
                    self.scan_coverage_logs()
            self.leave("RUN_COVERAGE_REGRESSIONS")

            self.enter("GENERATE_URG")
            if not (self.args.skip_urg or self.args.parse_only):
                self.run_cmd("GENERATE_URG", self.urg_cmd())
            self.leave("GENERATE_URG")

            self.enter("PARSE_REPORT")
            self.write_manifest("RUNNING", "parse_pending")
            if not self.args.dry_run:
                self.run_cmd("PARSE_REPORT", self.parser_cmd())
                if self.summary_json.is_file():
                    parsed = read_json(self.summary_json)
                    result_status = str(parsed.get("status", "FAIL"))
                    result_reason = str(parsed.get("reason", "parser_result"))
                    self.final_result_line = self.result_line_from_summary(parsed)
                    status, reason = result_status, result_reason
                else:
                    raise RunnerError("parser_output_missing", "parser did not write {}".format(self.summary_json), "PARSE_REPORT")
            else:
                status, reason = "CONDITIONAL_PASS", "dry_run"
                self.final_result_line = self.final_line(status, reason)
            self.leave("PARSE_REPORT")

            self.enter("WRITE_MANIFEST")
            self.write_manifest(status, reason)
            self.leave("WRITE_MANIFEST")

            self.enter("DONE")
            self.leave("DONE")
            self.write_manifest(status, reason)
            print(self.final_result_line)
            return 0
        except RunnerError as exc:
            self.errors.append({"state": exc.state, "reason": exc.reason, "message": str(exc)})
            self.enter("FAILED")
            self.leave("FAILED")
            self.write_manifest("FAIL", exc.reason)
            line = self.final_line("FAIL", exc.reason)
            print(line)
            print("ERROR: {}".format(exc), file=sys.stderr)
            return 2

    def result_line_from_summary(self, summary: Dict[str, object]) -> str:
        metrics = summary.get("metrics", {})
        def pct(metric: str) -> str:
            value = metrics.get(metric, {}).get("pct") if isinstance(metrics.get(metric), dict) else None
            return "N/A" if value is None else "{:.2f}".format(float(value))
        return (
            "PTW_CODE_COVERAGE_RESULT status={status} reason={reason} scope={scope} "
            "profile={profile} confidence={confidence} headline={headline} line={line} "
            "condition={condition} branch={branch} fsm={fsm} toggle={toggle} assertion={assertion} "
            "functional_gate={fg} report={report}"
        ).format(
            status=summary.get("status", "FAIL"),
            reason=summary.get("reason", "unknown"),
            scope=summary.get("scope", "ptw_core"),
            profile=summary.get("profile", self.args.profile),
            confidence=summary.get("confidence", "unknown"),
            headline="N/A" if summary.get("ptw_code_coverage") is None else "{:.2f}".format(float(summary["ptw_code_coverage"])),
            line=pct("line"),
            condition=pct("condition"),
            branch=pct("branch"),
            fsm=pct("fsm"),
            toggle=pct("toggle"),
            assertion=pct("assertion"),
            fg=summary.get("functional_gate", {}).get("status", "UNKNOWN") if isinstance(summary.get("functional_gate"), dict) else "UNKNOWN",
            report=summary.get("paths", {}).get("urg_report", rel(self.urg_report)) if isinstance(summary.get("paths"), dict) else rel(self.urg_report),
        )


def main() -> int:
    args = build_parser().parse_args()
    return Runner(args).execute()


if __name__ == "__main__":
    sys.exit(main())
