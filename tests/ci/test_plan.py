import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/ci"))
import plan
import result
from run import expected_suites

TOOLS = ["dsize", "portwho", "extract", "npmg"]


class ImpactTests(unittest.TestCase):
    def selected(self, paths, **kwargs):
        return plan.make_plan(paths, TOOLS, **kwargs)

    def test_tool_source_and_own_tests_select_only_owner(self):
        for path in ("tools/npmg/npmg.zsh", "tools/npmg/locales/en.sh", "tests/tools/npmg/completion.zsh", "tests/tools/npmg/install.sh"):
            with self.subTest(path=path):
                selected = self.selected([path])
                self.assertEqual(set(selected["reasons"]), {"tool-npmg", "integration"})
                self.assertEqual(set(selected["skipped"]), {"tool-dsize", "tool-portwho", "tool-extract"})

    def test_new_tool_needs_no_workflow_registration(self):
        selected = plan.make_plan(["scripts/tools.list", "tools/future/future.zsh"], TOOLS + ["future"], TOOLS)
        self.assertIn("tool-future", selected["reasons"])
        self.assertFalse(any("tool-" + tool in selected["reasons"] for tool in TOOLS))
        self.assertEqual(selected["contracts"], sorted(TOOLS))

    def test_shared_changes_select_all(self):
        for path in ("lib/i18n.sh", "scripts/loader.zsh.in", "scripts/build-installer.sh", "scripts/bootstrap.sh.in", "tests/common.sh", "tests/fixture.py", "tests/helpers/completion.zsh", "scripts/ci/plan.py", ".github/workflows/ci.yml", "future-unknown-file"):
            with self.subTest(path=path):
                selected = self.selected([path])
                self.assertTrue(all("tool-" + name in selected["reasons"] for name in TOOLS))
                self.assertTrue(set(plan.CORE) <= set(selected["reasons"]))

    def test_manager_changes_keep_real_contracts_without_tool_behavior(self):
        selected = self.selected(["lib/manager.sh"])
        self.assertEqual(selected["contracts"], sorted(TOOLS))
        self.assertTrue(set(plan.CORE) <= set(selected["reasons"]))
        self.assertFalse(any(target.startswith("tool-") for target in selected["reasons"]))

    def test_manager_locales_select_language(self):
        self.assertEqual(set(self.selected(["locales/zh-CN.sh"])["reasons"]), {"language"})

    def test_docs_and_generated_metadata_still_require_base(self):
        selected = self.selected(["README.md", "docs/development.md", "install.sh", "package.meta", "tools/npmg/package.meta"])
        self.assertEqual(selected["jobs"], [])
        self.assertEqual(set(selected["skipped"]), {"tool-" + name for name in TOOLS})

    def test_deleted_component_runs_removal_contracts(self):
        selected = plan.make_plan(["tools/npmg/npmg.zsh", "tests/tools/npmg/behavior.zsh"], TOOLS[:-1], TOOLS)
        self.assertIn("distribution", selected["reasons"])
        self.assertIn("manager", selected["reasons"])
        self.assertNotIn("tool-npmg", selected["reasons"])
        self.assertEqual(selected["contracts"], sorted(TOOLS[:-1]))

    def test_reordered_catalog_runs_assembly(self):
        self.assertIn("integration", self.selected(["scripts/tools.list"])["reasons"])

    def test_explicit_full_adds_both_platforms(self):
        selected = self.selected([], full_reason="manual", platforms=["macos-latest", "ubuntu-latest"])
        for tool in TOOLS:
            self.assertIn({"id": "tool-" + tool, "platform": "ubuntu-latest"}, selected["jobs"])

    def test_invalid_catalog_is_rejected(self):
        for text in ("", "mst.zsh", "init.zsh", "../bad.zsh", "x.zsh x.zsh", "X.zsh"):
            with self.assertRaises(ValueError):
                plan.catalog(text)


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.git("init", "-q")
        (self.root / "scripts").mkdir()
        (self.root / "scripts/tools.list").write_text("sample.zsh\n")
        self.base = self.commit("base")

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.DEVNULL).decode().strip()

    def commit(self, message):
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "-qm", message)
        return self.git("rev-parse", "HEAD")

    def test_source_then_provenance_push_covers_both_commits(self):
        (self.root / "source.zsh").write_text("source edit\n")
        self.commit("source")
        (self.root / "package.meta").write_text("provenance\n")
        head = self.commit("generated")
        self.assertEqual(plan.changed_paths(self.base, head, self.root), ["package.meta", "source.zsh"])

    def test_rename_and_delete_preserve_old_paths(self):
        (self.root / "old.zsh").write_text("old\n")
        (self.root / "deleted.zsh").write_text("delete\n")
        base = self.commit("files")
        (self.root / "old.zsh").rename(self.root / "new.zsh")
        (self.root / "deleted.zsh").unlink()
        head = self.commit("rename and delete")
        self.assertEqual(plan.changed_paths(base, head, self.root), ["deleted.zsh", "new.zsh", "old.zsh"])

    def test_successful_baseline_includes_unverified_previous_push(self):
        (self.root / "pending.zsh").write_text("failed or cancelled run\n")
        pending = self.commit("previous push")
        (self.root / "package.meta").write_text("later push\n")
        head = self.commit("current push")
        response = io.BytesIO(json.dumps({"workflow_runs": [{"id": 1, "head_sha": self.base}]}).encode())
        with patch.dict(os.environ, {"GITHUB_REPOSITORY": "owner/repo", "GITHUB_TOKEN": "test", "GITHUB_RUN_ID": "3"}), patch.object(plan.urllib.request, "urlopen", return_value=response):
            baseline = plan.successful_base(head, self.root)
        self.assertEqual(baseline, self.base)
        self.assertNotEqual(baseline, pending)
        self.assertIn("pending.zsh", plan.changed_paths(baseline, head, self.root))

    def test_api_failure_cannot_produce_incremental_baseline(self):
        with patch.dict(os.environ, {"GITHUB_REPOSITORY": "owner/repo", "GITHUB_TOKEN": "test"}), patch.object(plan.urllib.request, "urlopen", side_effect=OSError("rate limited")):
            self.assertIsNone(plan.successful_base(self.base, self.root))

    def test_pr_merge_base_covers_all_pr_commits_without_target_only_changes(self):
        self.git("checkout", "-qb", "feature")
        (self.root / "first.zsh").write_text("first PR commit\n")
        self.commit("first PR commit")
        (self.root / "second.zsh").write_text("second PR commit\n")
        head = self.commit("second PR commit")
        self.git("checkout", "-qb", "target", self.base)
        (self.root / "target-only.zsh").write_text("unrelated base branch change\n")
        target = self.commit("base branch advanced")
        base = self.git("merge-base", target, head)
        self.assertEqual(plan.changed_paths(base, head, self.root), ["first.zsh", "second.zsh"])

    def test_non_ancestor_success_after_force_push_is_not_a_baseline(self):
        self.git("checkout", "--orphan", "rewritten")
        (self.root / "other").write_text("rewritten history\n")
        head = self.commit("new root")
        response = io.BytesIO(json.dumps({"workflow_runs": [{"id": 1, "head_sha": self.base}]}).encode())
        with patch.dict(os.environ, {"GITHUB_REPOSITORY": "owner/repo", "GITHUB_TOKEN": "test", "GITHUB_RUN_ID": "3"}), patch.object(plan.urllib.request, "urlopen", return_value=response):
            self.assertIsNone(plan.successful_base(head, self.root))

    def test_missing_baseline_cli_falls_back_to_full(self):
        output = self.root / "plan.json"
        subprocess.run([sys.executable, str(ROOT / "scripts/ci/plan.py"), "--base", "missing-ref", "--output", str(output)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.assertTrue(json.loads(output.read_text())["full_reason"])


class GateTests(unittest.TestCase):
    def setUp(self):
        self.plan = plan.make_plan(["tools/npmg/npmg.zsh"], TOOLS)
        self.plan["head"] = "test-head"
        self.needs = {name: {"result": "success"} for name in ("plan", "base", "tests")}
        self.reports = []
        for job in [{"id": "base", "platform": "macos-latest"}] + self.plan["jobs"]:
            suites = expected_suites(job["id"], self.plan)
            self.reports.append({"head": "test-head", "target": job["id"], "platform": job["platform"], "status": "passed", "expected": suites,
                                 "suites": [{"name": suite, "status": "passed", "exit_code": 0} for suite in suites]})

    def test_complete_reports_pass(self):
        self.assertEqual(result.validate(self.plan, self.reports, self.needs), [])

    def test_missing_duplicate_stale_and_failed_reports_fail(self):
        for variation in ("missing", "duplicate", "stale", "failed", "empty-suites", "nonzero"):
            with self.subTest(variation=variation):
                reports = copy.deepcopy(self.reports)
                if variation == "missing":
                    reports.pop()
                elif variation == "duplicate":
                    reports.append(reports[-1])
                elif variation == "stale":
                    reports[-1]["head"] = "previous-head"
                elif variation == "failed":
                    reports[-1]["suites"][0]["status"] = "failed"
                elif variation == "empty-suites":
                    reports[-1]["suites"] = []
                elif variation == "nonzero":
                    reports[-1]["suites"][0]["exit_code"] = 1
                self.assertTrue(result.validate(self.plan, reports, self.needs))

    def test_cancelled_missing_and_unexpected_skipped_jobs_fail(self):
        for state in ("failure", "cancelled", "skipped", None):
            needs = copy.deepcopy(self.needs)
            needs["tests"]["result"] = state
            self.assertTrue(result.validate(self.plan, self.reports, needs))

    def test_docs_only_requires_base_and_explicit_matrix_skip(self):
        docs_plan = plan.make_plan(["README.md"], TOOLS)
        docs_plan["head"] = "test-head"
        self.needs["tests"]["result"] = "skipped"
        self.assertEqual(result.validate(docs_plan, self.reports[:1], self.needs), [])
        self.assertTrue(result.validate(docs_plan, [], self.needs))


if __name__ == "__main__":
    unittest.main()
