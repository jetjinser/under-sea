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

    def test_select_tag_allows_rust_prefix_but_filters_alpha(self):
        tags = ["rust-v0.163.0", "rust-v0.166.0-alpha.6"]
        self.assertEqual(run.select_tag(tags, r"^rust-v[0-9]"), "rust-v0.163.0")

    def test_select_tag_can_allow_server_suffixes(self):
        tags = ["v14.0.8-server", "v14.0.9-server", "v14.1.0-beta-server"]
        self.assertEqual(
            run.select_tag(tags, r"^v[0-9].*-server$", allow_prerelease=True),
            "v14.1.0-beta-server")

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
