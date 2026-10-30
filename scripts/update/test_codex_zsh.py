import unittest

import run


class CodexZshLockTests(unittest.TestCase):
    def test_zsh_is_dependent_l3_with_exact_source_and_patch(self):
        package = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["codex-zsh"]
        self.assertEqual(package["module"], "codex-zsh")
        self.assertEqual(package["autonomy"], "L3")
        self.assertFalse(package["independent"])
        self.assertEqual(package["depends_on"], "codex")
        lock = package["lock"]
        self.assertEqual(lock["kind"], "dependent")
        self.assertEqual(lock["parent"], "codex")
        self.assertEqual(lock["channel"], "channels.scm")
        source_lock = run.ROOT / lock["source_lock"]
        contents = source_lock.read_text()
        self.assertIn("77045ef899e53b9598bebc5a41db93a548a40ca6", contents)
        self.assertIn("696b7d923b8071554d00e811afb9a08fcad4baada796f7314d12ecd72d06152c", contents)
        package_source = (run.ROOT / "modules/under-sea/packages/codex-zsh.scm").read_text()
        self.assertIn("smoke-exec-wrapper", package_source)


if __name__ == "__main__":
    unittest.main()
