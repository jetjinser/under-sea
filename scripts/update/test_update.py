import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_entry", Path(__file__).with_name("update.py"))
entry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entry)


class UpdateEntryTests(unittest.TestCase):
    def test_prepare_command_has_apply_verify(self):
        pkg = {"adapter": "pypi"}
        cmd = entry.prepare_command("marimo", pkg, "0.26.0", Path("/w"),
                                    True, True)
        self.assertIn("--apply", cmd)
        self.assertIn("--verify", cmd)
        self.assertEqual(cmd[cmd.index("--package") + 1], "marimo")

    def test_prepare_command_dry_run(self):
        cmd = entry.prepare_command("marimo", {"adapter": "pypi"},
                                    "0.26.0", Path("/w"), False, False)
        self.assertNotIn("--apply", cmd)
        self.assertNotIn("--verify", cmd)


if __name__ == "__main__":
    unittest.main()
