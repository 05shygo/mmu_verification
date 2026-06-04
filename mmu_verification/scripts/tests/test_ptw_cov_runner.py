import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


PROJECT_DIR = Path(__file__).resolve().parents[2]
SCRIPT = PROJECT_DIR / "scripts" / "run_ptw_code_coverage.py"
sys.path.insert(0, str(PROJECT_DIR / "scripts"))

import run_ptw_code_coverage


class PtwCovRunnerTest(unittest.TestCase):
    def run_runner(self, args, expect_rc=0):
        proc = subprocess.run(
            ["python3", str(SCRIPT)] + args,
            cwd=str(PROJECT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        self.assertEqual(proc.returncode, expect_rc, proc.stdout + proc.stderr)
        self.assertIn("PTW_CODE_COVERAGE_RESULT", proc.stdout)
        return proc

    def test_quick_dry_run_writes_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            cov_root = Path(tmp) / "ptw_cov"
            proc = self.run_runner([
                "--profile", "quick",
                "--dry-run",
                "--functional-gate-mode", "skip",
                "--cov-root", str(cov_root),
            ])
            self.assertIn("status=CONDITIONAL_PASS", proc.stdout)
            manifest = json.loads((cov_root / "ptw_cov_manifest.json").read_text())
            self.assertTrue(manifest["dry_run"])
            self.assertEqual(manifest["status"], "CONDITIONAL_PASS")
            self.assertEqual(manifest["expanded_run_count"], 10)
            self.assertEqual(len(manifest["coverage_runs"]), 2)
            self.assertEqual(manifest["functional_gate"]["status"], "SKIPPED")
            self.assertTrue((cov_root / "run_ptw_code_coverage.log").is_file())
            states = [item["state"] for item in manifest["states"] if item["event"] == "enter"]
            for required in [
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
            ]:
                self.assertIn(required, states)
            self.assertTrue(all(run["status"] == "PLANNED" for run in manifest["coverage_runs"]))

    def test_run_gate_manifest_uses_frozen_source_signoff_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            cov_root = Path(tmp) / "ptw_cov"
            self.run_runner([
                "--profile", "quick",
                "--dry-run",
                "--cov-root", str(cov_root),
            ])
            gate = json.loads((cov_root / "ptw_cov_manifest.json").read_text())["functional_gate"]
            self.assertEqual(gate["closure_csv"], "simu/ptw_source_closure_matrix.csv")
            self.assertEqual(gate["closure_report"], "../doc/ptw_uvm_review/ptw_source_signoff_report.md")

    def test_rejects_jobs_not_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            cov_root = Path(tmp) / "ptw_cov"
            proc = self.run_runner([
                "--profile", "quick",
                "--dry-run",
                "--jobs", "2",
                "--cov-root", str(cov_root),
            ], expect_rc=2)
            self.assertIn("reason=jobs_not_one", proc.stdout)
            manifest = json.loads((cov_root / "ptw_cov_manifest.json").read_text())
            self.assertEqual(manifest["status"], "FAIL")
            self.assertEqual(manifest["reason"], "jobs_not_one")

    def test_rejects_non_ptw_hier_cfg(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cov_root = root / "ptw_cov"
            bad_hier = root / "bad_cov_hier.cfg"
            bad_hier.write_text("+tree tb_top\n")
            proc = self.run_runner([
                "--profile", "quick",
                "--dry-run",
                "--functional-gate-mode", "skip",
                "--cov-root", str(cov_root),
                "--hier-cfg", str(bad_hier),
            ], expect_rc=2)
            self.assertIn("reason=non_ptw_hier_cfg", proc.stdout)

    def test_run_gate_creates_log_dir_before_regress(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rules = json.loads((PROJECT_DIR / "scripts" / "ptw_functional_gate_rules.json").read_text())
            rules["run_mode"]["canonical_log_dir"] = str(root / "functional_logs")
            rules["run_mode"]["regressions"] = [
                {
                    "role": "smoke",
                    "list": "simu/ptw_p0_smoke_list",
                    "seeds": ["606"],
                    "regress_name": "ptw_src_p0_smoke",
                }
            ]
            rules_path = root / "rules.json"
            rules_path.write_text(json.dumps(rules))

            args = run_ptw_code_coverage.build_parser().parse_args([
                "--profile", "quick",
                "--functional-gate-rules", str(rules_path),
                "--cov-root", str(root / "ptw_cov"),
            ])
            runner = run_ptw_code_coverage.Runner(args)

            def fake_run_cmd(state, cmd, check=True):
                if state == "RUN_FUNCTIONAL_GATE":
                    self.assertTrue((root / "functional_logs").is_dir())
                return 0

            with mock.patch.object(runner, "run_cmd", side_effect=fake_run_cmd):
                runner.run_functional_gate()
            self.assertTrue((root / "functional_logs").is_dir())

    def test_run_gate_uses_absolute_log_dir_for_make_and_gate_script(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rules = json.loads((PROJECT_DIR / "scripts" / "ptw_functional_gate_rules.json").read_text())
            rules["run_mode"]["canonical_log_dir"] = "output/ptw_functional_gate/logs"
            rules["run_mode"]["regressions"] = [
                {
                    "role": "smoke",
                    "list": "simu/ptw_p0_smoke_list",
                    "seeds": ["606"],
                    "regress_name": "ptw_src_p0_smoke",
                }
            ]
            rules_path = root / "rules.json"
            rules_path.write_text(json.dumps(rules))

            args = run_ptw_code_coverage.build_parser().parse_args([
                "--profile", "quick",
                "--functional-gate-rules", str(rules_path),
                "--cov-root", str(root / "ptw_cov"),
            ])
            runner = run_ptw_code_coverage.Runner(args)
            seen_cmds = []

            def fake_run_cmd(state, cmd, check=True):
                if state == "RUN_FUNCTIONAL_GATE":
                    seen_cmds.append(list(cmd))
                return 0

            with mock.patch.object(runner, "run_cmd", side_effect=fake_run_cmd):
                runner.run_functional_gate()

            expected_log_dir = str(PROJECT_DIR / "output" / "ptw_functional_gate" / "logs")
            self.assertIn(f"LOG_DIR={expected_log_dir}", seen_cmds[0])
            gate_cmd = seen_cmds[1]
            self.assertEqual(gate_cmd[gate_cmd.index("--log-dir") + 1], expected_log_dir)


if __name__ == "__main__":
    unittest.main()
