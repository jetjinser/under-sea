import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class DetectTests(unittest.TestCase):
    def test_version_key_orders_numerically(self):
        self.assertLess(run.version_key("1.9.0"), run.version_key("1.10.0"))
        self.assertEqual(run.version_key("v2.1.4"), (2, 1, 4))

    def test_tag_version_strips_prefix(self):
        self.assertEqual(run.tag_version("v7.8.12"), "7.8.12")
        self.assertEqual(run.tag_version("rust-v0.163.0"), "0.163.0")

    def test_manifest_validates(self):
        data = run.load_manifest(run.DEFAULT_MANIFEST)
        self.assertIn("kilocode", data["packages"])
        self.assertIn("marimo", data["packages"])

    def test_current_version_from_inline_regex(self):
        data = run.load_manifest(run.DEFAULT_MANIFEST)
        self.assertEqual(run.current_version(data["packages"]["marimo"]),
                         "0.25.2")

    def test_select_tag_filters_product_lines(self):
        tags = ["v1.19.4", "v2.1.4", "v2.0.0", "v1.20.0-beta"]
        self.assertEqual(run.select_tag(tags, r"^v1\."), "v1.19.4")
        self.assertEqual(run.select_tag(tags, r"^v2\."), "v2.1.4")
        self.assertEqual(
            run.select_tag(tags, r"^v1\.", allow_prerelease=True),
            "v1.20.0-beta")
        self.assertIsNone(run.select_tag(tags, r"^v3\."))


if __name__ == "__main__":
    unittest.main()
