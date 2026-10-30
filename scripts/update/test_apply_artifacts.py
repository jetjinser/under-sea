import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_apply_artifacts", Path(__file__).with_name("apply_artifacts.py"))
apply = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply)


class ApplyArtifactsTests(unittest.TestCase):
    def test_installs_multiple_files_as_one_artifact_set(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "prepared"
            target = root / "target"
            source.mkdir()
            target.mkdir()
            (source / "lock.scm").write_text("new lock")
            (source / "uv.lock").write_text("new uv lock")
            (target / "lock.scm").write_text("old lock")
            (target / "uv.lock").write_text("old uv lock")

            apply.apply_artifacts(source, target, ["lock.scm", "uv.lock"])

            self.assertEqual((target / "lock.scm").read_text(), "new lock")
            self.assertEqual((target / "uv.lock").read_text(), "new uv lock")

    def test_missing_artifact_leaves_all_targets_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "prepared"
            target = root / "target"
            source.mkdir()
            target.mkdir()
            (source / "lock.scm").write_text("new lock")
            (target / "lock.scm").write_text("old lock")
            (target / "uv.lock").write_text("old uv lock")

            with self.assertRaises(FileNotFoundError):
                apply.apply_artifacts(source, target, ["lock.scm", "uv.lock"])

            self.assertEqual((target / "lock.scm").read_text(), "old lock")
            self.assertEqual((target / "uv.lock").read_text(), "old uv lock")


if __name__ == "__main__":
    unittest.main()
