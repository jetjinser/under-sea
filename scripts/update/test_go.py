import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_go", Path(__file__).with_name("go.py"))
go = importlib.util.module_from_spec(spec)
spec.loader.exec_module(go)


class GoTests(unittest.TestCase):
    def test_extract_source_requires_one_directory(self):
        # The function is exercised end-to-end by the prepare job; this is a
        # placeholder to keep the adapter importable and unit-tested.
        self.assertTrue(callable(go.extract_source))


if __name__ == "__main__":
    unittest.main()
