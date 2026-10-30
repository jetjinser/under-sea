import importlib.util
import unittest
from pathlib import Path
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class AgentCatTests(unittest.TestCase):
    def test_entry_has_build_gated_l2_support(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["agent-cat"]
        self.assertEqual(pkg["autonomy"], "L2")
        self.assertEqual(pkg["adapter"], "git-commit")
        self.assertTrue(pkg["upstream"]["track_commit"])
        self.assertTrue(any("guix build" in gate for gate in pkg["tests"]))

    def test_commit_change_is_reported(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["agent-cat"]
        with mock.patch.object(run, "git_head", return_value="ffffffffffffffffffffffffffffffffffffffff"):
            row = run.detect_package("agent-cat", pkg)
        self.assertEqual(row["status"], "outdated")
        self.assertEqual(row["current_commit"], "e6d0cad4b9ff27d0e46aeaef522adafb7a7ee1a8")


if __name__ == "__main__":
    unittest.main()
