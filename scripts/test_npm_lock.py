import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "npm_lock", Path(__file__).with_name("npm_lock.py"))
npm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(npm)


class NpmLockTests(unittest.TestCase):
    def test_mirror_rewrites_npmjs_only(self):
        url = "https://registry.npmjs.org/recast/-/recast-0.23.19.tgz"
        self.assertEqual(npm.candidate_urls(url, ["https://mirror.example"]), [
            url,
            "https://mirror.example/recast/-/recast-0.23.19.tgz",
        ])
        other = "https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz"
        self.assertEqual(npm.candidate_urls(other, ["https://mirror.example"]), [other])


if __name__ == "__main__":
    unittest.main()
