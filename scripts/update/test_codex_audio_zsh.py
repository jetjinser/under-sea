import unittest

import run


class CodexAudioZshTests(unittest.TestCase):
    def test_aggregate_is_dependent_l3_with_component_smoke(self):
        package = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["codex-with-audio-and-zsh"]
        self.assertEqual(package["autonomy"], "L3")
        self.assertFalse(package["independent"])
        self.assertEqual(package["depends_on"], "codex")
        self.assertEqual(package["lock"]["kind"], "dependent")
        self.assertEqual(package["lock"]["channel"], "channels.scm")
        self.assertIn("codex-voice-host", package["lock"]["additional_inputs"])
        self.assertIn("codex-zsh", package["lock"]["additional_inputs"])
        smoke = (run.ROOT / "scripts/smoke-codex-audio-zsh.py").read_text()
        self.assertIn("is_symlink", smoke)
        self.assertIn("--version", smoke)
        self.assertIn("--build-commit", smoke)


if __name__ == "__main__":
    unittest.main()
