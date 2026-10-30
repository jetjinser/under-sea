import unittest

import run


class CodexSdkLockTests(unittest.TestCase):
    def test_sdk_is_dependent_l3_with_explicit_source_lock(self):
        sdk = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["codex-sdk"]
        self.assertEqual(sdk["autonomy"], "L3")
        self.assertFalse(sdk["independent"])
        self.assertEqual(sdk["depends_on"], "codex")
        self.assertEqual(sdk["lock"]["kind"], "guix-inputs")
        self.assertEqual(sdk["lock"]["channel"], "channels.scm")
        self.assertEqual(sdk["lock"]["source_lock"],
                         "modules/under-sea/packages/codex-sdk-lock.scm")
        self.assertIn("codex", sdk["lock"]["inputs"])
        self.assertIn("ESM entrypoint", sdk["lock"]["policy"])
        lock = (run.ROOT / sdk["lock"]["source_lock"]).read_text()
        self.assertIn("typescript-5.9.2.tgz", lock)
        self.assertIn("mcp-sdk-1.26.0-source.tar.gz", lock)


if __name__ == "__main__":
    unittest.main()
