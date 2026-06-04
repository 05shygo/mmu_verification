import json
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[2]
SCRIPT = PROJECT_DIR / "scripts" / "ptw_extract_code_coverage.py"
HIER_CFG = PROJECT_DIR / "scripts" / "ptw_cov_hier.cfg"


class PtwCovParserTest(unittest.TestCase):
    def run_parser(self, report_dir, profile="signoff", manifest=None):
        out_json = report_dir.parent / "summary.json"
        out_md = report_dir.parent / "summary.md"
        cmd = [
            "python3",
            str(SCRIPT),
            "--urg-report",
            str(report_dir),
            "--scope",
            "ptw_core",
            "--hier-cfg",
            str(HIER_CFG),
            "--out-md",
            str(out_md),
            "--out-json",
            str(out_json),
            "--profile",
            profile,
        ]
        if manifest is not None:
            cmd += ["--manifest", str(manifest)]
        proc = subprocess.run(
            cmd,
            cwd=str(PROJECT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("PTW_CODE_COVERAGE_RESULT", proc.stdout)
        return json.loads(out_json.read_text()), out_md.read_text(), proc.stdout

    def write_manifest(self, root, status="PASS"):
        path = root / "manifest.json"
        path.write_text(
            json.dumps(
                {
                    "functional_gate": {
                        "status": status,
                        "mode": "run",
                        "generated_at": "2026-06-03T00:00:00+08:00",
                        "git_commit": "unit-test",
                        "gate_command": ["python3", "scripts/ptw_stage8_signoff_gate.py"],
                        "gate_script": "scripts/ptw_stage8_signoff_gate.py",
                        "log_dirs": ["output/ptw_functional_gate/logs"],
                        "closure_csv": "output/ptw_stage8_cov_collect/ptw_source_closure_matrix.csv",
                        "closure_report": "output/ptw_stage8_cov_collect/ptw_source_coverage_report.md",
                        "regressions": [],
                    },
                    "run_manifest": {
                        "profile": "signoff",
                        "runs": [
                            {
                                "list": "simu/ptw_code_coverage_list",
                                "seeds": ["606"],
                                "regress_name": "ptw_cov_unit",
                                "summary": "output/regression/ptw_cov_unit/summary.txt",
                                "status": "PASS",
                            }
                        ],
                        "deduped_entries": [],
                    },
                }
            )
            + "\n"
        )
        return path

    def test_hit_total_report_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = root / "urgReport"
            report.mkdir()
            (report / "dashboard.txt").write_text(
                "\n".join(
                    [
                        "Scope tb_top.u_dut.x_ct_mmu_ptw",
                        "Total Coverage: 99.25%",
                        "line 1200/1205 99.59%",
                        "condition 800/806 99.26%",
                        "branch 610/615 99.19%",
                        "fsm 20/20 100.00%",
                        "toggle 4210/4280 98.36%",
                        "assertion 50/50 100.00%",
                    ]
                )
            )
            (report / "hierarchy.txt").write_text("tb_top.u_dut.x_ct_mmu_ptw 99.25\n")
            (report / "modlist.txt").write_text("ct_mmu_ptw 99.25 99.59 99.26 99.19 100.00 98.36\n")
            manifest = self.write_manifest(root)
            data, md, stdout = self.run_parser(report, manifest=manifest)
            self.assertEqual(data["status"], "PASS")
            self.assertEqual(data["reason"], "all_thresholds_met")
            self.assertEqual(data["headline_method"], "urg_total_score")
            self.assertEqual(data["confidence"], "high")
            self.assertEqual(data["scope_check"]["status"], "PASS")
            self.assertIn("## Metrics", md)
            self.assertIn("functional_gate=PASS", stdout)

    def test_scope_rejects_non_ptw_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = root / "urgReport"
            report.mkdir()
            (report / "dashboard.txt").write_text(
                "\n".join(
                    [
                        "Scope tb_top.u_dut.x_ct_mmu_l1dtlb",
                        "line 1200/1205 99.59%",
                        "condition 800/806 99.26%",
                        "branch 610/615 99.19%",
                        "fsm 20/20 100.00%",
                        "toggle 4210/4280 98.36%",
                        "assertion 50/50 100.00%",
                    ]
                )
            )
            (report / "hierarchy.txt").write_text("tb_top.u_dut.x_ct_mmu_l1dtlb 99.25\n")
            data, _, _ = self.run_parser(report)
            self.assertEqual(data["status"], "FAIL")
            self.assertEqual(data["reason"], "scope_invalid")
            self.assertEqual(data["scope_check"]["status"], "FAIL")
            self.assertTrue(data["scope_check"]["rejected_scopes"])

    def test_html_percentage_fallback_conditional(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = root / "urgReport"
            report.mkdir()
            (report / "index.html").write_text(
                """
                <html><body>
                <div>tb_top.u_dut.x_ct_mmu_ptw</div>
                <table>
                <tr><td>Line Coverage</td><td>99.70%</td></tr>
                <tr><td>Condition Coverage</td><td>99.20%</td></tr>
                <tr><td>Branch Coverage</td><td>99.10%</td></tr>
                <tr><td>FSM Coverage</td><td>100.00%</td></tr>
                <tr><td>Toggle Coverage</td><td>98.60%</td></tr>
                <tr><td>Assertion Coverage</td><td>100.00%</td></tr>
                </table>
                </body></html>
                """
            )
            data, _, stdout = self.run_parser(report, profile="default")
            self.assertEqual(data["status"], "CONDITIONAL_PASS")
            self.assertEqual(data["reason"], "functional_gate_skipped")
            self.assertEqual(data["headline_method"], "percent_average")
            self.assertEqual(data["confidence"], "medium")
            self.assertIn("functional_gate=SKIPPED", stdout)


if __name__ == "__main__":
    unittest.main()
