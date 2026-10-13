"""Execution failures remain visible even when later suites pass."""
from pathlib import Path
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/ci"))
import run


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.report = Path(self.temporary.name)
        self.plan = {"head": "test-head", "tools": [], "contracts": []}

    def tearDown(self):
        self.temporary.cleanup()

    def test_failure_is_reported_and_later_suite_still_runs(self):
        suites = [("broken", [sys.executable, "-c", 'print("FAIL deliberate"); raise SystemExit(7)']),
                  ("later", [sys.executable, "-c", 'print("PASS later")'])]
        with patch.object(run, "definitions", return_value=suites), patch.dict(os.environ, {"GITHUB_ACTIONS": "", "GITHUB_STEP_SUMMARY": ""}):
            self.assertFalse(run.run_target("probe", self.plan, self.report, "local"))
        result = json.loads((self.report / "local-probe/result.json").read_text())
        self.assertEqual(result["status"], "failed")
        self.assertEqual([suite["exit_code"] for suite in result["suites"]], [7, 0])
        self.assertIn("FAIL deliberate", (self.report / "local-probe/broken/output.log").read_text())

    def test_timeout_is_a_failure_with_persistent_diagnostic(self):
        log = self.report / "timeout.log"
        status = run.execute([sys.executable, "-c", "import time; time.sleep(30)"], os.environ.copy(), log, 0.05)
        self.assertEqual(status, 124)
        self.assertIn("FAIL timeout", log.read_text())

    def test_tool_named_core_keeps_its_own_fixture(self):
        created = []

        def create(source, target, tool):
            created.append(tool)
            target.mkdir()
            return target

        suites = [("probe", [sys.executable, "-c", 'print("PASS fixtures")', "{tool_fixture:core}", "{fixture}"])]
        with patch.object(run, "definitions", return_value=suites), patch.object(run, "create_fixture", side_effect=create), patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": ""}):
            self.assertTrue(run.run_target("probe", self.plan, self.report, "local"))
        self.assertEqual(created, ["core", None])


if __name__ == "__main__":
    unittest.main()
