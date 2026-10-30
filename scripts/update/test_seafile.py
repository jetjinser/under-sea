import unittest

import run


class SeafileLockTests(unittest.TestCase):
    def test_client_and_server_keep_distinct_libsearpc_source_locks(self):
        packages = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
        lock_path = run.ROOT / "modules/under-sea/packages/seafile-lock.scm"
        lock = lock_path.read_text()
        client = packages["seafile"]
        server = packages["seafile-server"]
        for pkg in (client, server):
            self.assertEqual(pkg["autonomy"], "L3")
            self.assertEqual(pkg["adapter"], "github")
            self.assertEqual(pkg["lock"]["kind"], "guix-inputs")
            self.assertEqual(pkg["lock"]["channel"], "channels.scm")
            self.assertEqual(pkg["lock"]["source_lock"],
                             "modules/under-sea/packages/seafile-lock.scm")
        self.assertIn("libsearpc 3.2.0", client["lock"]["inputs"])
        self.assertIn("libsearpc 3.3.0", server["lock"]["inputs"])
        self.assertIn('%libsearpc-client-version "3.2.0"', lock)
        self.assertIn('%libsearpc-server-version "3.3.0"', lock)
        self.assertIn("3a4548697a498c951bd421248bcbdb1873f7616d", lock)


if __name__ == "__main__":
    unittest.main()
