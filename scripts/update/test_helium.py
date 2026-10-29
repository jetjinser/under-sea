import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_helium", Path(__file__).with_name("helium.py"))
helium = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helium)


class HeliumTests(unittest.TestCase):
    def test_components_are_read_from_source(self):
        result = helium.report(helium.DEFAULT_SOURCE, network=False)
        self.assertEqual(result["level"], "L1")
        self.assertEqual(result["components"]["helium_version"], "0.19.4.1")
        self.assertEqual(result["components"]["chromium_version"], "155.0.8059.84")
        self.assertEqual(result["components"]["assets"]["ublock"], "1.75.0")
        self.assertIn("helium_revision", result["components"])

    def test_version_key_orders_releases(self):
        self.assertGreater(
            helium.version_key("0.20.2.1"), helium.version_key("0.19.4.1"))


if __name__ == "__main__":
    unittest.main()
