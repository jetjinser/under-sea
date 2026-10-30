import hashlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lock_lib


class HttpResponse(io.BytesIO):
    status = 200

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


class LockLibTests(unittest.TestCase):
    def test_pypi_source_uses_urllib_and_verifies_digest(self):
        data = b"source archive"
        expected = hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            with mock.patch.object(
                    lock_lib.urllib.request, "urlopen",
                    return_value=HttpResponse(data)) as open_url:
                result = lock_lib.fetch((
                    "https://files.pythonhosted.org/packages/source.tar.gz",
                    "source.tar.gz", expected, len(data)), cache)
            self.assertEqual(result[2].read_bytes(), data)
            self.assertEqual(open_url.call_args.kwargs["timeout"], 1800)

    def test_pypi_source_rejects_checksum_mismatch(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(
                    lock_lib.urllib.request, "urlopen",
                    return_value=HttpResponse(b"wrong archive")), \
                 mock.patch.object(lock_lib.time, "sleep"):
                with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
                    lock_lib.fetch((
                        "https://files.pythonhosted.org/packages/source.tar.gz",
                        "source.tar.gz", "0" * 64, len(b"wrong archive")),
                        Path(directory))

    def test_crate_archive_uses_urllib_and_verifies_digest(self):
        data = b"crate archive"
        expected = hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(
                    lock_lib.urllib.request, "urlopen",
                    return_value=HttpResponse(data)) as open_url:
                result = lock_lib.fetch((
                    "https://static.crates.io/crates/example/example-1.0.crate",
                    "example-1.0.crate", expected, None), Path(directory))
            self.assertEqual(result[2].read_bytes(), data)
            self.assertEqual(open_url.call_args.kwargs["timeout"], 1800)


if __name__ == "__main__":
    unittest.main()
