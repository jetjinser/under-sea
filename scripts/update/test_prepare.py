import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_prepare", Path(__file__).with_name("prepare.py"))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PrepareTests(unittest.TestCase):
    def test_render_base16_pin(self):
        pkg = {
            "pin_module": "demo-pin",
            "version_symbol": "%demo-version",
            "source_symbol": "%demo-source",
            "hash_format": "base16",
        }
        text = prepare.render_pin(
            pkg, "1.2.3", "https://example.invalid/demo-1.2.3.tgz",
            "demo-1.2.3.tgz", "abcd")
        self.assertIn("(define-module (under-sea packages demo-pin)", text)
        self.assertIn('(define-public %demo-version "1.2.3")', text)
        self.assertIn('(base16-string->bytevector "abcd")', text)

    def test_render_base32_pin(self):
        pkg = {
            "pin_module": "demo-pin",
            "version_symbol": "%demo-version",
            "source_symbol": "%demo-source",
            "hash_format": "base32",
        }
        text = prepare.render_pin(
            pkg, "1.2.3", "https://example.invalid/demo-1.2.3.tgz",
            "demo-1.2.3.tgz", "abcd")
        self.assertIn('(base32 "abcd")', text)


if __name__ == "__main__":
    unittest.main()
