import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "update_prepare", Path(__file__).with_name("prepare.py"))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PrepareTests(unittest.TestCase):
    def test_dependent_package_rejects_generic_pin_only_update(self):
        with self.assertRaisesRegex(ValueError, "refusing a pin-only rewrite"):
            prepare.reject_dependent_pin_only_update({"adapter": "dependent"})

    def test_normal_package_can_use_generic_pin_update(self):
        self.assertIsNone(prepare.reject_dependent_pin_only_update(
            {"adapter": "github"}))

    def test_render_base16_pin(self):
        pkg = {
            "pin_module": "demo-pin",
            "version_symbol": "%demo-version",
            "source_symbol": "%demo-source",
            "hash_format": "base16",
        }
        text = prepare.render_pin(
            pkg, "1.2.3", "https://example.invalid/demo-1.2.3.tgz",
            "demo-1.2.3.tgz", "abcd")
        self.assertIn("(define-module (under-sea packages demo-pin)", text)
        self.assertIn('(define-public %demo-version "1.2.3")', text)
        self.assertIn('(base16-string->bytevector "abcd")', text)

    def test_render_base32_pin(self):
        pkg = {
            "pin_module": "demo-pin",
            "version_symbol": "%demo-version",
            "source_symbol": "%demo-source",
            "hash_format": "base32",
        }
        text = prepare.render_pin(
            pkg, "1.2.3", "https://example.invalid/demo-1.2.3.tgz",
            "demo-1.2.3.tgz", "abcd")
        self.assertIn('(base32 "abcd")', text)

    def test_render_git_commit_pin(self):
        pkg = {
            "pin_module": "agent-cat-pin",
            "package": "agent-cat",
            "version_symbol": "%agent-cat-version",
            "commit_symbol": "%agent-cat-commit",
            "source_symbol": "%agent-cat-source",
            "upstream": {
                "repo": "jwiegley/agent-cat",
                "version_prefix": "0.0.0-0.",
                "version_length": 7,
            },
        }
        commit = "e6d0cad4b9ff27d0e46aeaef522adafb7a7ee1a8"
        text = prepare.render_git_pin(pkg, commit, "hash")
        self.assertIn('(define-public %agent-cat-version "0.0.0-0.e6d0cad")', text)
        self.assertIn(f'(define-public %agent-cat-commit "{commit}")', text)
        self.assertIn('(url "https://github.com/jwiegley/agent-cat")', text)
        self.assertIn('(base32 "hash")', text)

    def test_git_commit_source_hashes_checked_out_nar(self):
        pkg = {"upstream": {"repo": "jwiegley/agent-cat"}}
        commit = "e6d0cad4b9ff27d0e46aeaef522adafb7a7ee1a8"
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(prepare.subprocess, "run") as run, \
                    mock.patch.object(
                        prepare.subprocess, "check_output",
                        side_effect=[commit, "nar-hash"]) as output:
                digest = prepare.git_commit_source(pkg, commit, Path(tmp))
        self.assertEqual(digest, "nar-hash")
        self.assertEqual(run.call_count, 2)
        hash_cmd = output.call_args_list[1].args[0]
        self.assertIn("--serializer=nar", hash_cmd)
        self.assertIn("--exclude-vcs", hash_cmd)
        self.assertEqual(hash_cmd[-1], str(Path(tmp) / "source"))



if __name__ == "__main__":
    unittest.main()
