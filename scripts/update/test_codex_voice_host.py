import unittest

import run


class CodexVoiceHostTests(unittest.TestCase):
    def test_voice_host_is_locked_dependent_l3(self):
        package = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["codex-voice-host"]
        self.assertEqual(package["autonomy"], "L3")
        self.assertFalse(package["independent"])
        self.assertEqual(package["depends_on"], "codex")
        lock = package["lock"]
        self.assertEqual(lock["kind"], "dependent")
        self.assertEqual(lock["parent"], "codex")
        self.assertEqual(lock["inherits"],
                         "modules/under-sea/packages/codex-lock.scm")
        self.assertEqual(lock["channel"], "channels.scm")
        self.assertIn("GStreamer", lock["policy"])
        smoke = (run.ROOT / "scripts/smoke-codex-voice-host.py").read_text()
        self.assertIn('"hello"', smoke)
        self.assertIn('"ready"', smoke)
        self.assertIn('"close"', smoke)
        self.assertIn('"closed"', smoke)


if __name__ == "__main__":
    unittest.main()
