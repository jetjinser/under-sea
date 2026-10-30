import unittest

import run


class CodexCodeModeHostTests(unittest.TestCase):
    def test_host_is_source_locked_dependent_l3(self):
        package = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["codex-code-mode-host"]
        self.assertEqual(package["autonomy"], "L3")
        self.assertFalse(package["independent"])
        self.assertEqual(package["depends_on"], "codex")
        lock = package["lock"]
        self.assertEqual(lock["kind"], "dependent")
        self.assertEqual(lock["parent"], "codex")
        self.assertEqual(lock["channel"], "channels.scm")
        self.assertEqual(lock["source_lock"],
                         "modules/under-sea/packages/codex-v8-lock.scm")
        self.assertTrue(any("Clang/LLVM 23" in item
                            for item in lock["additional_inputs"]))
        source_lock = (run.ROOT / lock["source_lock"]).read_text()
        self.assertIn("%codex-v8-crate-sources", source_lock)
        smoke = (run.ROOT / "scripts/check-codex.py").read_text()
        self.assertIn("codex-code-mode-host", smoke)
        self.assertIn("--help", smoke)


if __name__ == "__main__":
    unittest.main()
