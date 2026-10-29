import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)

LEVEL = {"L0": 0, "L1": 1, "L2": 2, "L3": 3, "L4": 4}
CODEX_COMPONENTS = {
    "codex-base",
    "codex-with-audio-and-zsh",
    "codex-sdk",
    "codex-voice-host",
    "codex-code-mode-host",
    "codex-zsh",
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

    def test_codex_components_stay_conservative(self):
        packages = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
        for name in CODEX_COMPONENTS:
            self.assertEqual(packages[name]["autonomy"], "L2")


if __name__ == "__main__":
    unittest.main()
