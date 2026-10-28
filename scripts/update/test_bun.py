import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_bun", Path(__file__).with_name("bun.py"))
bun = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bun)


class BunTests(unittest.TestCase):
    def test_native_inventory(self):
        lock = '''
        (origin (method url-fetch)
          (uri "https://registry.npmjs.org/@opentui/core-linux-x64/-/core-linux-x64-1.tgz"))
        (origin (method url-fetch)
          (uri "https://registry.npmjs.org/typescript/-/typescript-5.tgz"))
        '''
        self.assertEqual(
            bun.native_inventory(lock, ["@opentui/core-linux-x64"]),
            ["@opentui/core-linux-x64"])

    def test_lock_command_has_variant_flags(self):
        pkg = {
            "lock": {
                "script": "scripts/lock-opencode.py",
                "module": "(under-sea packages opencode-v1-lock)",
                "prefix": "opencode-v1",
            }
        }
        cmd = bun.lock_command(pkg, "/c", "/t", "/b", "/o")
        self.assertIn("--module", cmd)
        self.assertIn("--prefix", cmd)
        self.assertEqual(cmd[-1], "opencode-v1")


if __name__ == "__main__":
    unittest.main()
