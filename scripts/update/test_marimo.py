import unittest

import run


class MarimoLockTests(unittest.TestCase):
    def test_channel_inputs_and_pinned_overrides_are_declared(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["marimo"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["lock"]["kind"], "guix-inputs")
        self.assertEqual(pkg["lock"]["channel"], "channels.scm")
        self.assertIn("python-msgspec-0.22", pkg["lock"]["inputs"])
        self.assertIn("python-pymdown-extensions-10.21",
                      pkg["lock"]["inputs"])
        self.assertEqual(pkg["lock"]["overrides"],
                         "modules/under-sea/packages/marimo-deps.scm")


if __name__ == "__main__":
    unittest.main()
