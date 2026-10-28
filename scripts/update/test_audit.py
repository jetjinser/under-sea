import importlib.util
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


if __name__ == "__main__":
    unittest.main()
