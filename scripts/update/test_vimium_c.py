import json
import unittest
from pathlib import Path

import run


class VimiumCTests(unittest.TestCase):
    def test_lock_is_a_git_fetch_candidate(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["vimium-c"]
        self.assertEqual(pkg["source_method"], "git-fetch")
        self.assertEqual(pkg["autonomy"], "L2")
        self.assertEqual(pkg["lock"]["kind"], "generated-node")
        self.assertTrue(pkg["lock"]["candidate"])
        self.assertTrue((run.ROOT / pkg["lock"]["output"]).is_file())

    def test_inventory_has_runtime_sources(self):
        inventory = json.loads(
            (run.ROOT / "planning/vimium-c-node-inventory.json").read_text())
        self.assertEqual(inventory["lockfileVersion"], 2)
        self.assertEqual(len(inventory["selected"]), 160)
        self.assertEqual(inventory["native_candidates"], [])


if __name__ == "__main__":
    unittest.main()
