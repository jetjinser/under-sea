import importlib.util
import io
import json
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
    def test_declared_l2_profiles_match_pinned_inventories(self):
        manifest = hermes.run.load_manifest(hermes.run.DEFAULT_MANIFEST)
        specs = {spec["module"]: spec for spec in
                 manifest["packages"]["hermes-agent"]["dependent_locks"]}
        for module, inventory_file in (
                ("hermes-integrations-lock", "hermes-integrations-inventory.json"),
                ("hermes-full-audio-lock", "hermes-full-audio-inventory.json")):
            spec = specs[module]
            inventory = json.loads((hermes.ROOT / "planning/archive" /
                                    inventory_file).read_text())
            self.assertEqual(spec["extras"], inventory["extras"])
            self.assertFalse(spec["verify"])
            if module == "hermes-full-audio-lock":
                components = json.loads((hermes.ROOT / spec["python_components"])
                                        .read_text())
                self.assertEqual(components,
                                 inventory["independent_python_components"])
                self.assertEqual(len(spec["source_audits"]), 1)
                self.assertTrue(spec["record_unbuildable"])

    def test_only_enabled_dependent_builds_run_during_verification(self):
        enabled = {"package": "interfaces"}
        source_only = {"package": "integrations", "verify": False}
        self.assertEqual(hermes.verification_specs([enabled, source_only]),
                         [enabled])

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

    def test_dependent_lock_generation_uses_declared_source_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "generated-hermes-interfaces-lock.scm"

            def fake_lock(command, **kwargs):
                Path(command[command.index("--output") + 1]).write_text(
                    "%hermes-python-sources\n%hermes-crate-sources")

            spec = {"module": "hermes-interfaces-lock",
                    "target": "modules/under-sea/packages/hermes-interfaces-lock.scm",
                    "extras": ["acp", "mcp"]}
            with mock.patch.object(hermes.subprocess, "run",
                                   side_effect=fake_lock) as run:
                result = hermes.regenerate_dependent_locks(
                    root / "hermes.tar", root / "source",
                    root, [spec])
            self.assertEqual(result[spec["target"]], output.read_text())
            command = run.call_args.args[0]
            self.assertEqual(command.count("--extra"), 2)
            self.assertIn("acp", command)
            self.assertIn("mcp", command)

    def test_dependent_lock_generation_forwards_component_audits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def fake_lock(command, **kwargs):
                Path(command[command.index("--output") + 1]).write_text(
                    "%hermes-python-sources\n%hermes-crate-sources\n"
                    "%hermes-source-unavailable-components")

            spec = {
                "module": "hermes-audio-lock",
                "target": "modules/hermes-audio-lock.scm",
                "python_components": "planning/audio-components.json",
                "source_audits": ["planning/porcupine-audit.json"],
                "record_unbuildable": True,
            }
            with mock.patch.object(hermes.subprocess, "run",
                                   side_effect=fake_lock) as run:
                hermes.regenerate_dependent_locks(
                    root / "hermes.tar", root / "source", root, [spec])

            command = run.call_args.args[0]
            self.assertEqual(command[command.index("--python-components") + 1],
                             str(hermes.ROOT / spec["python_components"]))
            self.assertEqual(command[command.index("--source-audit") + 1],
                             str(hermes.ROOT / spec["source_audits"][0]))
            self.assertIn("--record-unbuildable", command)

    def test_multi_lock_apply_rolls_back_on_replacement_error(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first, second = root / "first.scm", root / "second.scm"
            first.write_text("old first")
            second.write_text("old second")
            replace = hermes.os.replace
            calls = 0

            def fail_during_install(source, target):
                nonlocal calls
                calls += 1
                if calls == 4:
                    raise OSError("simulated second replacement failure")
                return replace(source, target)

            with mock.patch.object(hermes.os, "replace",
                                   side_effect=fail_during_install):
                with self.assertRaisesRegex(OSError, "simulated"):
                    hermes.atomic_write_many({first: "new first",
                                              second: "new second"})
            self.assertEqual(first.read_text(), "old first")
            self.assertEqual(second.read_text(), "old second")
            self.assertEqual(sorted(p.name for p in root.iterdir()),
                             ["first.scm", "second.scm"])


if __name__ == "__main__":
    unittest.main()
