import json
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[2]
SCRIPT = PROJECT_DIR / "scripts" / "check_ptw_code_cov_signoff.py"


class PtwSignoffCheckTest(unittest.TestCase):
    def run_check(self, path):
        return subprocess.run(
            ["python3", str(SCRIPT), "--summary-json", str(path)],
            cwd=str(PROJECT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )

    def write_summary(self, root, status="PASS", gate_status="PASS", profile="signoff"):
        path = root / "summary.json"
        path.write_text(
            json.dumps(
                {
                    "profile": profile,
                    "status": status,
                    "reason": "unit",
                    "functional_gate": {"status": gate_status},
                }
            )
            + "\n"
        )
        return path

    def test_passes_for_signoff_pass_with_gate_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self.write_summary(Path(tmp))
            proc = self.run_check(path)
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
            self.assertIn("status=PASS", proc.stdout)

    def test_fails_for_conditional_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self.write_summary(Path(tmp), status="CONDITIONAL_PASS", gate_status="SKIPPED")
            proc = self.run_check(path)
            self.assertEqual(proc.returncode, 1)
            self.assertIn("summary_status=CONDITIONAL_PASS", proc.stdout)
            self.assertIn("functional_gate=SKIPPED", proc.stdout)

    def test_fails_for_missing_summary(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = self.run_check(Path(tmp) / "missing.json")
            self.assertEqual(proc.returncode, 1)
            self.assertIn("summary_missing", proc.stdout)


if __name__ == "__main__":
    unittest.main()
