import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_report", Path(__file__).with_name("report.py"))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ReportTests(unittest.TestCase):
    def test_report_counts_inventory(self):
        data = report.report()
        self.assertEqual(data["inventory"], 45)
        self.assertEqual(sum(data["levels"].values()), 45)
        self.assertIn("L0", data["levels"])
        self.assertEqual(data["independent_l2_plus"], 24)
        self.assertEqual(data["dependent_l2_plus"], 15)


if __name__ == "__main__":
    unittest.main()
