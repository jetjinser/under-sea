import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_run", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class PrepareScriptTests(unittest.TestCase):
    def test_dependent_packages_cannot_fall_back_to_pin_only_updates(self):
        with self.assertRaisesRegex(ValueError, "generic pin-only updater is unsafe"):
            run.prepare_script({"adapter": "dependent"})

    def test_lock_aware_adapters_select_their_update_scripts(self):
        self.assertEqual(run.prepare_script({"adapter": "hermes-dependent"}),
                         "hermes.py")
        self.assertEqual(run.prepare_script({"adapter": "browser-use"}),
                         "browser_use.py")
        self.assertEqual(run.prepare_script({"adapter": "uv-profile"}),
                         "browser_use.py")
        self.assertEqual(run.prepare_script({"adapter": "camofox"}),
                         "camofox.py")


if __name__ == "__main__":
    unittest.main()
