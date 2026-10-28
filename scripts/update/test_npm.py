import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_npm", Path(__file__).with_name("npm.py"))
npm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(npm)


class NpmTests(unittest.TestCase):
    def test_extract_source_is_callable(self):
        self.assertTrue(callable(npm.extract_source))


if __name__ == "__main__":
    unittest.main()
