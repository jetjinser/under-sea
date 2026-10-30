import unittest

import run


class StrataLockTests(unittest.TestCase):
    def test_hip_package_uses_audited_guix_input_lock(self):
        pkg = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["strata"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["upstream"]["type"], "github")
        self.assertEqual(pkg["adapter"], "github")
        self.assertEqual(pkg["lock"]["kind"], "guix-inputs")
        self.assertEqual(pkg["lock"]["channel"], "channels.scm")
        lock_path = run.ROOT / pkg["lock"]["source_lock"]
        self.assertTrue(lock_path.is_file())
        lock = lock_path.read_text()
        self.assertIn("3cf03257f219afbe7334045ff7c6a06ac68c627d", lock)
        self.assertIn("c076d7534afa0e5d0ec2a0d425b11e791c16f3de0d727221aea071cef156a280",
                      lock)

    def test_cuda_backend_inherits_lock_and_names_extra_toolchain(self):
        packages = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]
        pkg = packages["strata-cuda"]
        self.assertEqual(pkg["autonomy"], "L3")
        self.assertEqual(pkg["depends_on"], "strata")
        self.assertEqual(pkg["lock"]["kind"], "dependent")
        self.assertEqual(pkg["lock"]["parent"], "strata")
        self.assertEqual(pkg["lock"]["inherits"],
                         "modules/under-sea/packages/strata-lock.scm")
        extra = pkg["lock"]["additional_inputs"]
        self.assertIn("cuda-toolkit 13.0.2 from pinned guix-hpc-non-free channel",
                      extra)
        self.assertTrue(any("libcuda.so.1" in item and "never bundled" in item
                            for item in extra))


if __name__ == "__main__":
    unittest.main()
