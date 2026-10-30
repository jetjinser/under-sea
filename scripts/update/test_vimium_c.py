import unittest

import run


class VimiumCTests(unittest.TestCase):
    def test_lock_records_channel_pinned_build_inputs(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["vimium-c"]
        self.assertEqual(pkg["source_method"], "git-fetch")
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["lock"]["kind"], "guix-inputs")
        self.assertEqual(pkg["lock"]["channel"], "channels.scm")
        self.assertEqual(pkg["lock"]["inputs"], ["node", "node-typescript"])
        self.assertNotIn("candidate", pkg["lock"])

    def test_npm_archive_lock_is_not_declared_as_a_build_input(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["vimium-c"]
        self.assertNotIn("generated-node", pkg["lock"]["kind"])


if __name__ == "__main__":
    unittest.main()
