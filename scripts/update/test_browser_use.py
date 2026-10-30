import importlib.util
import hashlib
import io
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "update_browser_use", Path(__file__).with_name("browser_use.py"))
browser_use = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser_use)


class BrowserUseUpdateTests(unittest.TestCase):
    def test_exact_pypi_release_requires_source_distribution(self):
        payload = json.dumps({
            "info": {"version": "0.13.13"},
            "urls": [{"packagetype": "sdist"}],
        }).encode()
        with mock.patch.object(browser_use.urllib.request, "urlopen",
                               return_value=io.BytesIO(payload)) as open_url:
            self.assertEqual(browser_use.pypi_release("browser-use", "0.13.13"),
                             "0.13.13")
        self.assertIn("/browser-use/0.13.13/json", open_url.call_args.args[0].full_url)

    def test_pypi_network_error_is_reported(self):
        with mock.patch.object(browser_use.urllib.request, "urlopen",
                               side_effect=OSError("network unavailable")):
            with self.assertRaisesRegex(SystemExit, "cannot query PyPI"):
                browser_use.pypi_release("browser-use", "0.13.11")

    def test_lock_generator_exports_selected_root_version(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "uv.lock"
            output = root / "browser-lock.scm"
            cache = root / "cache"
            cache.mkdir()
            archive = cache / "browser-use-0.13.13.tar.gz"
            project = b"[build-system]\nrequires=[]\nbuild-backend='setuptools.build_meta'\n"
            with tarfile.open(archive, "w:gz") as tar:
                member = tarfile.TarInfo("browser-use-0.13.13/pyproject.toml")
                member.size = len(project)
                tar.addfile(member, io.BytesIO(project))
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            lock.write_text(
                '[[package]]\nname = "browser-use"\nversion = "0.13.13"\n'
                'source = { registry = "https://pypi.org/simple" }\n'
                'sdist = { url = "https://files.pythonhosted.org/packages/browser-use-0.13.13.tar.gz", '
                f'hash = "sha256:{digest}", size = {archive.stat().st_size} }}\n')
            subprocess.run([
                sys.executable,
                str(browser_use.ROOT / "scripts/lock-hermes-browser.py"),
                str(lock), "--root", "browser-use", "--module", "browser-lock",
                "--version-symbol", "%browser-use-version",
                "--output", str(output), "--cache", str(cache),
            ], check=True, cwd=browser_use.ROOT, capture_output=True, text=True)
            generated = output.read_text()
            self.assertIn('(define-public %browser-use-version "0.13.13")',
                          generated)
            self.assertIn('(list "browser-use" "0.13.13"', generated)

    def test_project_version_changes_without_changing_profile(self):
        project = (browser_use.ROOT /
                   "planning/hermes-browser-use-plan/pyproject.toml").read_text()
        extras = ["examples", "aws", "oci", "video"]
        rendered = browser_use.render_project(
            project, "browser-use", "0.13.13", extras)
        self.assertIn("browser-use[examples,aws,oci,video]==0.13.13", rendered)
        self.assertIn('orjson==3.11.4', rendered)

    def test_camoufox_project_uses_geoip_and_gui_profile(self):
        project = (browser_use.ROOT /
                   "planning/hermes-camoufox-plan/pyproject.toml").read_text()
        extras = ["geoip", "gui"]
        rendered = browser_use.render_project(
            project, "camoufox", "0.5.9", extras)
        self.assertIn("camoufox[geoip,gui]==0.5.9", rendered)
        self.assertIn('playwright==1.62.0', rendered)

    def test_profile_mismatch_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "do not match"):
            browser_use.render_project(
                'dependencies = ["browser-use[aws]==1.2.3"]',
                "browser-use",
                "1.2.4", ["examples", "aws", "oci", "video"])

    def test_pinned_uv_version_is_checked(self):
        with mock.patch.object(browser_use.subprocess, "check_output",
                               return_value="uv 0.10.12\n"):
            self.assertEqual(browser_use.check_uv_version("uv", "0.10.12"),
                             "uv 0.10.12")
        with mock.patch.object(browser_use.subprocess, "check_output",
                               return_value="uv 0.11.0\n"):
            with self.assertRaisesRegex(SystemExit, "uv 0.10.12"):
                browser_use.check_uv_version("uv", "0.10.12")

    def test_uv_lock_pins_the_exact_guix_provided_python(self):
        command = browser_use.uv_lock_command(
            "uv", Path("/tmp/project"), Path("/tmp/cache"))
        self.assertEqual(command[command.index("--python") + 1], sys.executable)
        self.assertNotIn("3.12", command)

    def test_uv_fallback_resolves_from_pinned_guix_channel(self):
        output = "/gnu/store/vw3ml5g0yy64a2hrrxr39387xban4v27-uv-0.10.12\n"
        with mock.patch.dict(browser_use.os.environ, {}, clear=True), \
             mock.patch.object(browser_use.shutil, "which", return_value=None), \
             mock.patch.object(browser_use.subprocess, "check_output",
                               return_value=output) as build:
            executable = browser_use.uv_executable()
        self.assertEqual(executable, output.strip() + "/bin/uv")
        self.assertIn("(@ (gnu packages build-tools) uv)", build.call_args.args[0])

    def test_manifest_tracks_pypi_runtime_and_candidate_lock(self):
        manifest = json.loads(
            (browser_use.ROOT / "planning/update-manifest.json").read_text())
        package = manifest["packages"][
            "hermes-agent-browser-backend-browser-use"]
        self.assertEqual(package["upstream"],
                         {"type": "pypi", "project": "browser-use"})
        self.assertEqual(package["adapter"], "browser-use")
        self.assertTrue(package["lock"]["candidate"])
        self.assertEqual(package["lock"]["uv_version"], "0.10.12")
        self.assertEqual(package["lock"]["module"], "hermes-browser-lock")
        self.assertEqual(package["lock"]["output"],
                         "modules/under-sea/packages/hermes-browser-lock.scm")
        command = browser_use.lock_command(
            package["lock"], Path("uv.lock"), Path("lock.scm"),
            Path("cache"))
        self.assertEqual(
            command[command.index("--cargo-lock-overrides") + 1],
            str(browser_use.ROOT / "planning/archive/tiktoken-cargo-overrides.json"))

    def test_camoufox_tracks_its_own_pypi_lock_profile(self):
        manifest = json.loads(
            (browser_use.ROOT / "planning/update-manifest.json").read_text())
        package = manifest["packages"][
            "hermes-agent-browser-backend-camoufox"]
        self.assertEqual(package["upstream"],
                         {"type": "pypi", "project": "camoufox"})
        self.assertEqual(package["adapter"], "uv-profile")
        self.assertEqual(package["lock"]["extras"], ["geoip", "gui"])
        self.assertTrue(package["lock"]["candidate"])
        self.assertEqual(package["lock"]["module"], "hermes-camoufox-lock")


if __name__ == "__main__":
    unittest.main()
