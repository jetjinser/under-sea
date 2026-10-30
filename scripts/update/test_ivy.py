import unittest

import run


class IvyAutonomyTests(unittest.TestCase):
    def test_z3_runtime_has_channel_locked_inputs_and_scoped_ceiling(self):
        ivy = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["python-ms-ivy"]
        self.assertEqual(ivy["autonomy"], "L3")
        self.assertEqual(ivy["lock"]["kind"], "guix-inputs")
        self.assertEqual(ivy["lock"]["channel"], "channels.scm")
        self.assertIn("z3", ivy["lock"]["inputs"])
        self.assertIn("python-tarjan", ivy["lock"]["inputs"])
        self.assertIn("ivyc backend", ivy["lock"]["policy"])


if __name__ == "__main__":
    unittest.main()
