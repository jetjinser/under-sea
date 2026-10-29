import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_camofox", Path(__file__).with_name("camofox.py"))
camofox = importlib.util.module_from_spec(spec)
spec.loader.exec_module(camofox)

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class CamofoxTests(unittest.TestCase):
    def test_entry_has_node_lock(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["camofox-browser"]
        self.assertEqual(pkg["autonomy"], "L2")
        self.assertEqual(pkg["adapter"], "github")
        self.assertEqual(pkg["lock"]["script"], "scripts/lock-camofox.py")


if __name__ == "__main__":
    unittest.main()
