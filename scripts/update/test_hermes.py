import importlib.util
import io
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "update_hermes", Path(__file__).with_name("hermes.py"))
hermes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hermes)

SAMPLE = '''\
(define-public %hermes-version "0.21.5")
(define-public %hermes-release "2026.9.24")
(define-public %hermes-source (origin (method url-fetch) (uri "https://old")
        (file-name "old.tar.gz")
        (sha256 (base16-string->bytevector "00"))))
(define-public %hermes-python-sources
  (list))
'''


class HermesTests(unittest.TestCase):
    def test_source_only_rewrite_keeps_lock(self):
        digest = "a" * 64
        text = hermes.render_lock(SAMPLE, "2026.10.1", "0.22.0", digest)

        self.assertIn('(define-public %hermes-version "0.22.0")', text)
        self.assertIn('(define-public %hermes-release "2026.10.1")', text)
        self.assertIn("refs/tags/v2026.10.1", text)
        self.assertIn(f'"{digest}"', text)
        self.assertIn("(define-public %hermes-python-sources", text)

    def test_invalid_digest_is_rejected(self):
        with self.assertRaises(ValueError):
            hermes.render_lock(SAMPLE, "2026.10.1", "0.22.0", "not-a-digest")

    def test_atomic_write_replaces_complete_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "hermes-lock.scm"
            target.write_text("old")
            target.chmod(0o640)
            hermes.atomic_write(target, "new lock")
            self.assertEqual(target.read_text(), "new lock")
            self.assertEqual(target.stat().st_mode & 0o777, 0o640)
            self.assertEqual([p.name for p in Path(directory).iterdir()],
                             [target.name])

    def test_extract_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "unsafe.tar"
            with tarfile.open(archive, "w") as tar:
                info = tarfile.TarInfo("../outside")
                info.size = 1
                tar.addfile(info, io.BytesIO(b"x"))
            with self.assertRaisesRegex(ValueError, "unsafe path"):
                hermes.extract_source(archive, Path(directory) / "out")

    def test_failed_lock_generation_has_no_repository_write(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "hermes.tar"
            with tarfile.open(archive, "w:gz") as tar:
                for name, data in (("hermes-agent-v/pyproject.toml",
                                    b"[project]\nversion='1'\n"),
                                   ("hermes-agent-v/uv.lock", b"")):
                    info = tarfile.TarInfo(name)
                    info.size = len(data)
                    tar.addfile(info, io.BytesIO(data))
            sentinel = root / "repository-lock.scm"
            sentinel.write_text("unchanged")
            with mock.patch.object(hermes.subprocess, "run",
                                   side_effect=RuntimeError("fetch failed")):
                with self.assertRaisesRegex(RuntimeError, "fetch failed"):
                    hermes.regenerate_lock(archive, root / "work")
            self.assertEqual(sentinel.read_text(), "unchanged")

    def test_lock_generation_writes_only_staging_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "hermes.tar"
            with tarfile.open(archive, "w:gz") as tar:
                for name, data in (("hermes-agent-v/pyproject.toml",
                                    b"[project]\nversion='1'\n"),
                                   ("hermes-agent-v/uv.lock", b"")):
                    info = tarfile.TarInfo(name)
                    info.size = len(data)
                    tar.addfile(info, io.BytesIO(data))

            def fake_lock(command, **kwargs):
                output = Path(command[command.index("--output") + 1])
                output.write_text("%hermes-version\n%hermes-python-sources")

            with mock.patch.object(hermes.subprocess, "run",
                                   side_effect=fake_lock) as run:
                result = hermes.regenerate_lock(archive, root / "work")
            self.assertIn("%hermes-python-sources", result)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0][
                run.call_args.args[0].index("--workers") + 1], "2")
            self.assertTrue((root / "work/generated-hermes-lock.scm").is_file())


if __name__ == "__main__":
    unittest.main()
