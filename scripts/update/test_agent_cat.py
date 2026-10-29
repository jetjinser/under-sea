import importlib.util
import unittest
from pathlib import Path
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class AgentCatTests(unittest.TestCase):
    def test_entry_is_detect_only(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["agent-cat"]
        self.assertEqual(pkg["autonomy"], "L1")
        self.assertEqual(pkg["adapter"], "git-commit")
        self.assertTrue(pkg["upstream"]["track_commit"])

    def test_commit_change_is_reported(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["agent-cat"]
        with mock.patch.object(run, "git_head", return_value="e6d0cad4b9ff27d0e46aeaef522adafb7a7ee1a8"):
            row = run.detect_package("agent-cat", pkg)
        self.assertEqual(row["status"], "outdated")
        self.assertEqual(row["current_commit"], "c90ce63bc18d50f54dc76d7961a16e2bb8ea74a2")


if __name__ == "__main__":
    unittest.main()
