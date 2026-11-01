import importlib.util
from unittest import mock
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import run

spec = importlib.util.spec_from_file_location(
    "update_helium", Path(__file__).with_name("helium.py"))
helium = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helium)


class HeliumTests(unittest.TestCase):
    def test_components_are_read_from_source(self):
        result = helium.report(helium.DEFAULT_SOURCE, network=False)
        self.assertEqual(result["level"], "L3")
        self.assertEqual(result["components"]["helium_version"], "0.19.4.1")
        self.assertEqual(result["components"]["chromium_version"], "155.0.8059.84")
        self.assertEqual(result["components"]["assets"]["ublock"], "1.75.0")
        self.assertIn("helium_revision", result["components"])
        self.assertEqual(len(result["component_inventory"]), 9)
        self.assertTrue(all(len(row["sha256"]) == 52
                            for row in result["component_inventory"].values()))

    def test_complete_current_transaction_is_a_noop(self):
        candidate = helium.component_inventory(helium.DEFAULT_SOURCE)
        result = helium.transaction(helium.DEFAULT_SOURCE, candidate)
        self.assertFalse(result["applied"])
        self.assertEqual(result["changed"], {})
        self.assertEqual(len(result["unchanged"]), 9)

    def test_candidate_inputs_can_omit_hashes_and_resolve_known_asset_urls(self):
        original = helium.component_inventory(helium.DEFAULT_SOURCE)
        candidate = {name: dict(row) for name, row in original.items()}
        for row in candidate.values():
            row.pop("sha256")
        normalized = helium.validate_candidate_inputs(candidate)
        urls = helium.candidate_urls(normalized)
        self.assertEqual(set(urls), {"search_engines", "onboarding", "ublock", "esbuild"})
        self.assertIn("202609082320", urls["search_engines"])
        self.assertIn("1.75.0", urls["ublock"])
        with tempfile.TemporaryDirectory() as directory:
            resolved = helium.resolve_candidate_hashes(
                helium.DEFAULT_SOURCE, candidate, directory)
        self.assertTrue(all(len(row["sha256"]) == 52 for row in resolved.values()))
        self.assertEqual({name: row["sha256"] for name, row in resolved.items()},
                         {name: row["sha256"] for name, row in original.items()})

    def test_candidate_hash_resolution_keeps_chromium_review_gate_but_resolves_other_sources(self):
        candidate = helium.component_inventory(helium.DEFAULT_SOURCE)
        candidate["helium"]["version"] = "0.20.3.1"
        candidate["helium_linux"]["version"] = "0.20.3.1"
        candidate["helium"]["revision"] = "a" * 40
        candidate["helium_linux"]["revision"] = "b" * 40
        candidate["chromium_base"]["version"] = "156.0.8078.79"
        candidate["chromium_linux_x64"]["version"] = "156.0.8078.79"
        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(helium, "guix_git_hash", return_value="a" * 52), \
                mock.patch.object(helium, "fetch_file", side_effect=lambda url, path: path), \
                mock.patch.object(helium, "guix_file_hash", return_value="b" * 52):
            resolved = helium.resolve_candidate_hashes(
                helium.DEFAULT_SOURCE, candidate, directory)
        self.assertNotIn("sha256", resolved["chromium_base"])
        self.assertNotIn("sha256", resolved["chromium_linux_x64"])
        self.assertEqual(resolved["helium"]["sha256"], "a" * 52)
        review = helium.candidate_review(helium.DEFAULT_SOURCE, resolved)
        self.assertIn("resolved locally with Guix hash", review["markdown"])
        self.assertIn("not fetched; prepared-tarball review required", review["markdown"])
        with self.assertRaisesRegex(ValueError, "expected fields"):
            helium.transaction(helium.DEFAULT_SOURCE, resolved)

    def test_discovery_uses_latest_tags_and_pinned_source_metadata(self):
        versions = "156.0.8078.79\n"
        deps = '''[search_engines_data]
version = 202610310900
url = https://example.test/search-%(version)s.tgz
sha256 = 0123456789abcdef

[onboarding]
version = 202610301200
url = https://example.test/onboarding-%(version)s.tgz
sha256 = abcdef0123456789

[ublock_origin]
version = 1.76.0
url = https://example.test/ublock-%(version)s.zip
sha256 = fedcba9876543210
'''
        with mock.patch.object(helium, "latest_tag_revision", side_effect=[
                ("0.20.3", "a" * 40), ("0.20.3.1", "b" * 40)]), \
                mock.patch.object(helium, "remote_text", side_effect=[versions, deps]):
            candidate, info = helium.discover_candidate(helium.DEFAULT_SOURCE)
        self.assertEqual(candidate["helium"]["revision"], "a" * 40)
        self.assertEqual(candidate["helium_linux"]["revision"], "b" * 40)
        self.assertEqual(candidate["chromium_base"]["version"], "156.0.8078.79")
        self.assertEqual(candidate["search_engines"]["release"], "202610310900")
        self.assertEqual(candidate["onboarding"]["release"], "202610301200")
        self.assertEqual(candidate["ublock"]["version"], "1.76.0")
        self.assertEqual(info["helium_linux_tag"], "0.20.3.1")
        self.assertTrue(info["review_required"])
        self.assertEqual(info["upstream_artifacts"]["onboarding"]["sha256"],
                         "abcdef0123456789")
        review = helium.candidate_review(helium.DEFAULT_SOURCE, candidate, info)
        self.assertTrue(review["chromium_changed"])
        self.assertEqual(review["changed_components"], 7)
        self.assertIn("Chromium prepared tarballs", review["markdown"])
        self.assertIn("upstream-declared SHA-256 `abcdef0123456789`", review["markdown"])

    def test_candidate_review_shows_hashes_and_sources(self):
        candidate = helium.component_inventory(helium.DEFAULT_SOURCE)
        report = helium.candidate_review(helium.DEFAULT_SOURCE, candidate)
        self.assertFalse(report["chromium_changed"])
        self.assertEqual(report["changed_components"], 0)
        self.assertIn("current `1i56njrm2g5qf5pads55w2q8j7vb5hzlp7v97plzzyini2scxkw9`",
                      report["markdown"])
        self.assertIn("https://github.com/imputnet/helium/commit/", report["markdown"])

    def test_latest_tag_revision_prefers_peeled_annotated_tag_commit(self):
        output = """aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/0.20.3.1
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/0.20.3.1^{}
"""
        with mock.patch.object(helium.subprocess, "check_output", return_value=output):
            self.assertEqual(
                helium.latest_tag_revision("owner/repo", r"^[0-9]"),
                ("0.20.3.1", "b" * 40))

    def test_apply_updates_all_origins_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "helium.scm"
            shutil.copyfile(helium.DEFAULT_SOURCE, source)
            candidate = helium.component_inventory(source)
            candidate["helium"]["revision"] = "a" * 40
            candidate["helium"]["sha256"] = "b" * 52
            candidate["helium"]["version"] = "0.20.0.1"
            candidate["helium_linux"]["revision"] = "c" * 40
            candidate["helium_linux"]["sha256"] = "d" * 52
            candidate["helium_linux"]["version"] = "0.20.0.1"
            candidate["debian"]["revision"] = "debian/155.0.8059.84-1"
            candidate["debian"]["sha256"] = "e" * 52
            candidate["search_engines"]["release"] = "202611010000"
            candidate["search_engines"]["sha256"] = "f" * 52
            candidate["onboarding"]["release"] = "202611010001"
            candidate["onboarding"]["sha256"] = "g" * 52
            candidate["ublock"]["version"] = "1.76.0"
            candidate["ublock"]["sha256"] = "h" * 52
            candidate["esbuild"]["version"] = "0.29.0"
            candidate["esbuild"]["sha256"] = "i" * 52
            result = helium.transaction(source, candidate, apply=True)
            self.assertTrue(result["applied"])
            self.assertEqual(set(result["changed"]),
                             set(helium.CANDIDATE_FIELDS) -
                             {"chromium_base", "chromium_linux_x64"})
            self.assertEqual(helium.component_inventory(source), candidate)

    def test_incomplete_or_chromium_candidate_refuses_without_partial_edit(self):
        original = helium.DEFAULT_SOURCE.read_bytes()
        candidate = helium.component_inventory(helium.DEFAULT_SOURCE)
        candidate.pop("esbuild")
        with self.assertRaisesRegex(ValueError, "exactly the nine"):
            helium.transaction(helium.DEFAULT_SOURCE, candidate, apply=True)
        candidate = helium.component_inventory(helium.DEFAULT_SOURCE)
        candidate["chromium_base"]["sha256"] = "b" * 52
        with self.assertRaisesRegex(ValueError, "human merge"):
            helium.transaction(helium.DEFAULT_SOURCE, candidate, apply=True)
        self.assertEqual(helium.DEFAULT_SOURCE.read_bytes(), original)

    def test_chromium_change_applies_only_with_explicit_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "helium.scm"
            shutil.copyfile(helium.DEFAULT_SOURCE, source)
            candidate = helium.component_inventory(source)
            for name in ("chromium_base", "chromium_linux_x64"):
                candidate[name]["version"] = "156.0.8078.79"
                candidate[name]["sha256"] = "b" * 52
            with self.assertRaisesRegex(ValueError, "human merge"):
                helium.transaction(source, candidate, apply=True)
            result = helium.transaction(
                source, candidate, apply=True, accept_chromium_change=True)
            self.assertTrue(result["applied"])
            self.assertEqual(helium.component_inventory(source), candidate)
            self.assertIn("chromium_base", result["changed"])
            self.assertIn("chromium_linux_x64", result["changed"])

    def test_report_and_transaction_show_all_nine_component_changes(self):
        result = helium.report(helium.DEFAULT_SOURCE, network=False)
        candidate = result["component_inventory"]
        candidate["helium"]["revision"] = "a" * 40
        candidate["helium"]["sha256"] = "b" * 52
        transaction = helium.transaction(helium.DEFAULT_SOURCE, candidate)
        self.assertEqual(set(transaction["changed"]), {"helium"})
        self.assertIn("old", transaction["changed"]["helium"])
        self.assertIn("new", transaction["changed"]["helium"])

    def test_version_key_orders_releases(self):
        self.assertGreater(
            helium.version_key("0.20.2.1"), helium.version_key("0.19.4.1"))

    def test_manifest_uses_l3_atomic_adapter(self):
        package = run.load_manifest(run.DEFAULT_MANIFEST)["packages"]["helium"]
        self.assertEqual(package["autonomy"], "L3")
        self.assertTrue(package["independent"])
        self.assertEqual(package["adapter"], "helium")
        self.assertEqual(package["lock"]["components"], 9)


if __name__ == "__main__":
    unittest.main()
