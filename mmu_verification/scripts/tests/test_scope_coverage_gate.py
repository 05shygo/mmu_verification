import subprocess
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main()
