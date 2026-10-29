import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_hermes", Path(__file__).with_name("hermes.py"))
hermes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hermes)

SAMPLE = '''\
(define-public %hermes-version "0.21.5")
(define-public %hermes-release "2026.9.24")
(define-public %hermes-source (origin (method url-fetch) (uri "https://old")
        (file-name "old.tar.gz")
        (sha256 (base16-string->bytevector "00"))))
(define-public %hermes-python-sources
  (list))
'''


class HermesTests(unittest.TestCase):
    def test_source_only_rewrite_keeps_lock(self):
        digest = "a" * 64
        text = hermes.render_lock(SAMPLE, "2026.10.1", "0.22.0", digest)

        self.assertIn('(define-public %hermes-version "0.22.0")', text)
        self.assertIn('(define-public %hermes-release "2026.10.1")', text)
        self.assertIn("refs/tags/v2026.10.1", text)
        self.assertIn(f'"{digest}"', text)
        self.assertIn("(define-public %hermes-python-sources", text)

    def test_invalid_digest_is_rejected(self):
        with self.assertRaises(ValueError):
            hermes.render_lock(SAMPLE, "2026.10.1", "0.22.0", "not-a-digest")


if __name__ == "__main__":
    unittest.main()
