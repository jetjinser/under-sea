import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_audit", Path(__file__).with_name("audit.py"))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AuditTests(unittest.TestCase):
    def test_current_inventory_is_clean(self):
        result = audit.audit()
        self.assertEqual(result["errors"], [])
        self.assertGreaterEqual(result["inventory"], 40)

    def test_status_expressions_are_classified(self):
        result = audit.audit(check_docs=True)
        self.assertEqual(result["errors"], [])

    def test_l2_and_l3_packages_require_declared_verification_gates(self):
        manifest = json.loads(audit.run.DEFAULT_MANIFEST.read_text())
        manifest["packages"]["hermes-agent-integrations"].pop("tests")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(manifest))
            result = audit.audit(path, check_docs=False)
        self.assertIn(
            "missing verification gates for hermes-agent-integrations at L3",
            result["errors"],
        )


if __name__ == "__main__":
    unittest.main()
