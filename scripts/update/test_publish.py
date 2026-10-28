import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_publish", Path(__file__).with_name("publish.py"))
publish = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publish)


class PublishTests(unittest.TestCase):
    def test_plan_is_package_specific(self):
        result = publish.plan("marimo", "0.26.0")
        self.assertEqual(result["branch"], "update/marimo-0.26.0")
        self.assertIn("marimo: update to 0.26.0", result["commit"])
        self.assertIn("--apply --verify", result["prepare"])


if __name__ == "__main__":
    unittest.main()
