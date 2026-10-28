import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_cargo", Path(__file__).with_name("cargo.py"))
cargo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cargo)


class CargoTests(unittest.TestCase):
    def test_adapter_imports(self):
        self.assertTrue(callable(cargo.extract_source))


if __name__ == "__main__":
    unittest.main()
