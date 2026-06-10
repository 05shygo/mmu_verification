import subprocess
import tempfile
import unittest
import json
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[2]
SCRIPT = PROJECT_DIR / "scripts" / "scope_coverage_gate.py"


class ScopeCoverageGateTest(unittest.TestCase):
    def run_gate(self, report_dir):
        return subprocess.run(
            [
                "python3",
                str(SCRIPT),
                "--scope-name",
                "UNIT",
                "--urg-report-dir",
                str(report_dir),
            ],
            cwd=str(PROJECT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )

    def test_passes_when_all_metrics_meet_thresholds(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "urgReport"
            report.mkdir()
            (report / "dashboard.txt").write_text(
                "\n".join(
                    [
                        "line 100/100 100.00%",
                        "branch 100/100 100.00%",
                        "toggle 100/100 100.00%",
                        "fsm 100/100 100.00%",
                        "functional 100/100 100.00%",
                        "assertion 100/100 100.00%",
                    ]
                )
            )
            proc = self.run_gate(report)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertIn("SCOPE_COVERAGE_RESULT scope=UNIT status=PASS", proc.stdout)

    def test_fails_when_metric_is_below_threshold(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "urgReport"
            report.mkdir()
            (report / "dashboard.txt").write_text(
                "\n".join(
                    [
                        "line 100/100 100.00%",
                        "branch 98/100 98.00%",
                        "toggle 100/100 100.00%",
                        "fsm 100/100 100.00%",
                        "functional 100/100 100.00%",
                        "assertion 100/100 100.00%",
                    ]
                )
            )
            proc = self.run_gate(report)
            self.assertEqual(proc.returncode, 1)
            self.assertIn("branch: FAIL", proc.stdout)

    def test_fails_when_report_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = self.run_gate(Path(tmp) / "missing")
            self.assertEqual(proc.returncode, 1)
            self.assertIn("URG report missing or empty", proc.stdout)

    def test_selected_metrics_ignore_unrequested_metrics(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "urgReport"
            report.mkdir()
            (report / "dashboard.txt").write_text(
                "\n".join(
                    [
                        "line 0/100 0.00%",
                        "branch 0/100 0.00%",
                        "condition 95/100 95.00%",
                        "toggle 95/100 95.00%",
                        "fsm 95/100 95.00%",
                        "functional 95/100 95.00%",
                        "assertion 0/100 0.00%",
                    ]
                )
            )
            proc = subprocess.run(
                [
                    "python3",
                    str(SCRIPT),
                    "--scope-name",
                    "UNIT",
                    "--urg-report-dir",
                    str(report),
                    "--metrics",
                    "functional,fsm,toggle,condition",
                    "--functional-threshold",
                    "95.0",
                    "--fsm-threshold",
                    "95.0",
                    "--toggle-threshold",
                    "95.0",
                    "--condition-threshold",
                    "95.0",
                ],
                cwd=str(PROJECT_DIR),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertIn("functional: PASS 95.00%", proc.stdout)
            self.assertIn("fsm: PASS 95.00%", proc.stdout)
            self.assertIn("toggle: PASS 95.00%", proc.stdout)
            self.assertIn("condition: PASS 95.00%", proc.stdout)
            self.assertNotIn("line:", proc.stdout)
            self.assertNotIn("branch:", proc.stdout)
            self.assertNotIn("assertion:", proc.stdout)

    def test_scope_json_summary_takes_precedence_over_ambiguous_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "urgReport"
            report.mkdir()
            (report / "scope_coverage_summary.json").write_text(
                json.dumps(
                    {
                        "scopes": {
                            "UNIT": {
                                "metrics": {
                                    "cond": {"percent": 96.0},
                                    "tgl": {"percent": 97.0},
                                    "fsm": {"percent": 98.0},
                                    "functional": {"percent": 99.0},
                                }
                            }
                        }
                    }
                )
            )
            (report / "scope_coverage_report.html").write_text(
                "<tr><td>line</td><td>1.00%</td><td>condition</td><td>2.00%</td></tr>"
            )
            proc = subprocess.run(
                [
                    "python3",
                    str(SCRIPT),
                    "--scope-name",
                    "UNIT",
                    "--urg-report-dir",
                    str(report),
                    "--metrics",
                    "functional,fsm,toggle,condition",
                    "--functional-threshold",
                    "95.0",
                    "--fsm-threshold",
                    "95.0",
                    "--toggle-threshold",
                    "95.0",
                    "--condition-threshold",
                    "95.0",
                ],
                cwd=str(PROJECT_DIR),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertIn("functional: PASS 99.00%", proc.stdout)
            self.assertIn("fsm: PASS 98.00%", proc.stdout)
            self.assertIn("toggle: PASS 97.00%", proc.stdout)
            self.assertIn("condition: PASS 96.00%", proc.stdout)


if __name__ == "__main__":
    unittest.main()
