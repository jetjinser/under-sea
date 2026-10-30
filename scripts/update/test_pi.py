import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_pi", Path(__file__).with_name("pi.py"))
pi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pi)

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class PiTests(unittest.TestCase):
    def test_entry_has_node_lock(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["pi"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["adapter"], "pi")
        self.assertEqual(pkg["lock"]["script"], "scripts/lock-pi.py")

    def test_render_pin_keeps_both_assets(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["pi"]
        rows = [
            ("%pi-source", "pi-1.0.4-source.tar.gz", "https://example/source", "a" * 64),
            ("%pi-install-lock", "lock.json", "https://example/lock", "b" * 64),
        ]
        text = pi.render_pin(pkg, "1.0.4", rows)
        self.assertIn('(define-public %pi-version "1.0.4")', text)
        self.assertIn('%pi-source', text)
        self.assertIn('%pi-install-lock', text)
        self.assertIn("a" * 64, text)
        self.assertIn("b" * 64, text)


if __name__ == "__main__":
    unittest.main()
