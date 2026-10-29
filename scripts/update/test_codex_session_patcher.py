import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class CodexSessionPatcherTests(unittest.TestCase):
    def test_entry_has_no_dependency_lock(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"][
            "codex-session-patcher"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["lock"]["strategy"], "none")


if __name__ == "__main__":
    unittest.main()
