import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)

LEVEL = {"L0": 0, "L1": 1, "L2": 2, "L3": 3, "L4": 4}
CODEX_COMPONENTS = {
    "codex-code-mode-host",
}


class DependentLevelTests(unittest.TestCase):
    def test_dependents_do_not_exceed_parent_level(self):
        packages = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
        for name, pkg in packages.items():
            if pkg.get("independent", True):
                continue
            parent = packages[pkg["depends_on"]]
            self.assertLessEqual(
                LEVEL[pkg["autonomy"]], LEVEL[parent["autonomy"]],
                f"{name} is above its parent {pkg['depends_on']}")

    def test_unreviewed_codex_components_stay_conservative(self):
        packages = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
        for name in CODEX_COMPONENTS:
            self.assertEqual(packages[name]["autonomy"], "L2")

    def test_codex_base_inherits_parent_lock(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["codex-base"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["depends_on"], "codex")
        self.assertEqual(pkg["lock"]["kind"], "dependent")
        self.assertEqual(pkg["lock"]["parent"], "codex")
        self.assertEqual(pkg["lock"]["inherits"],
                         "modules/under-sea/packages/codex-lock.scm")

    def test_pi_standalone_inherits_parent_lock(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"][
            "pi-standalone"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["depends_on"], "pi")
        self.assertEqual(pkg["lock"]["kind"], "dependent")
        self.assertEqual(pkg["lock"]["parent"], "pi")
        self.assertEqual(pkg["lock"]["inherits"],
                         "modules/under-sea/packages/pi-node-lock.scm")
        self.assertIn("bun-for-hermes@1.4.2",
                      pkg["lock"]["additional_inputs"][0])


if __name__ == "__main__":
    unittest.main()
