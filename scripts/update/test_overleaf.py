import unittest

import run


class OverleafAutonomyTests(unittest.TestCase):
    def test_toolkit_and_wrapper_have_scoped_l3_contracts(self):
        packages = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
        toolkit = packages["overleaf-toolkit"]
        wrapper = packages["overleaf-ctl"]
        self.assertEqual(toolkit["autonomy"], "L3")
        self.assertEqual(toolkit["lock"]["strategy"], "none")
        self.assertIn("Container images are external", toolkit["lock"]["reason"])
        self.assertEqual(wrapper["autonomy"], "L3")
        self.assertEqual(wrapper["depends_on"], "overleaf-toolkit")
        self.assertEqual(wrapper["lock"]["kind"], "guix-inputs")
        self.assertIn("docker-compose", wrapper["lock"]["inputs"])
        self.assertIn("make verify-overleaf", wrapper["tests"])


if __name__ == "__main__":
    unittest.main()
