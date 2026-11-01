import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_bun", Path(__file__).with_name("bun.py"))
bun = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bun)

scripts = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(scripts))
lock_spec = importlib.util.spec_from_file_location(
    "lock_opencode", scripts / "lock-opencode.py")
lock_opencode = importlib.util.module_from_spec(lock_spec)
lock_spec.loader.exec_module(lock_opencode)


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
                "output": "modules/under-sea/packages/opencode-v1-lock.scm",
                "module": "(under-sea packages opencode-v1-lock)",
                "prefix": "opencode-v1",
            }
        }
        cmd = bun.lock_command(pkg, "/c", "/t", "/b", "/o")
        self.assertIn("--module", cmd)
        self.assertIn("--prefix", cmd)
        self.assertIn("--previous-lock", cmd)
        self.assertEqual(cmd[-1], "opencode-v1")

    def test_previous_lock_hash_reuse_requires_same_label_and_url(self):
        digest = "a" * 64
        lock = f'''(define origins
  (list "pkg@1@@@1"
    (origin (method url-fetch) (uri "https://example.test/pkg.tgz")
      (file-name "pkg.tgz")
      (sha256 (base16-string->bytevector "{digest}")))))'''
        previous = lock_opencode.parse_previous_lock(lock)
        self.assertEqual(previous, {
            "pkg@1@@@1": ("https://example.test/pkg.tgz", digest)})
        self.assertEqual(lock_opencode.reusable_hash(
            previous, "pkg@1@@@1", "https://example.test/pkg.tgz"), digest)
        self.assertIsNone(lock_opencode.reusable_hash(
            previous, "pkg@2@@@1", "https://example.test/pkg.tgz"))
        self.assertIsNone(lock_opencode.reusable_hash(
            previous, "pkg@1@@@1", "https://example.test/changed.tgz"))

    def test_local_tarball_dependencies_use_immutable_source_tag(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "packages/app/vendor").mkdir(parents=True)
            (root / "packages/app/vendor/client.tgz").write_bytes(b"fixture")
            (root / "packages/app/package.json").write_text(
                '{"dependencies":{"@example/client":"file:vendor/client.tgz"}}')
            self.assertEqual(
                bun.local_tarball_dependencies(root, "owner/repo", "v1.2.3"),
                [("@example/client",
                  "https://raw.githubusercontent.com/owner/repo/v1.2.3/"
                  "packages/app/vendor/client.tgz")])

    def test_local_tarball_dependency_ignores_missing_files_and_directories(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "package.json").write_text(
                '{"dependencies":{"missing":"file:missing.tgz",'
                '"directory":"file:folder"}}')
            (root / "folder").mkdir()
            self.assertEqual(bun.local_tarball_dependencies(root, "o/r", "v1"), [])


if __name__ == "__main__":
    unittest.main()
