import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_verify", Path(__file__).with_name("verify.py"))
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerifyTests(unittest.TestCase):
    def test_build_plan_includes_dependents(self):
        data = {
            "packages": {
                "demo": {
                    "module": "demo", "package": "demo",
                    "dependents": [{"module": "other", "package": "other"}],
                }
            }
        }
        self.assertEqual(verify.build_plan(data, "demo"), [
            ("demo", "demo", "primary"),
            ("other", "other", "dependent"),
        ])

    def test_hermes_source_update_verifies_interfaces(self):
        data = verify.run.load_manifest(verify.run.DEFAULT_MANIFEST)
        self.assertEqual(verify.build_plan(data, "hermes-agent"), [
            ("hermes", "hermes-agent", "primary"),
            ("hermes", "hermes-agent-interfaces", "dependent"),
            ("hermes-browser-backends", "hermes-browser-backend-playwright",
             "dependent"),
        ])


if __name__ == "__main__":
    unittest.main()
