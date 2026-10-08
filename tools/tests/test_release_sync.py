import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from release_sync import GITHUB_API, HttpClient, SyncError, cache_asset, secure_url, validate_asset


class Response:
    def __init__(self, body=b"package", status=200, headers=None):
        self.body = body
        self.status_code = status
        self.headers = headers or {}
        self.closed = False

    def iter_content(self, size):
        yield self.body

    def close(self):
        self.closed = True

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.client = HttpClient(GITHUB_API, "test-only-placeholder", attempts=1)
        self.asset = {"id": 123, "name": "app.hap", "size": 7, "updated_at": "2026-10-08",
                      "digest": "sha256:" + hashlib.sha256(b"package").hexdigest()}
        self.temporary = tempfile.TemporaryDirectory()
        self.cache = Path(self.temporary.name)

    def tearDown(self):
        self.client.close()
        self.temporary.cleanup()

    def test_redirect_does_not_forward_platform_token(self):
        redirect = Response(status=302, headers={"Location": "https://objects.example/file?signature=placeholder"})
        with patch.object(self.client, "request", side_effect=[redirect, Response()]) as request:
            self.client.binary(f"{GITHUB_API}/repos/owner/repo/releases/assets/123", "下载").close()
        self.assertIn("Authorization", request.call_args_list[0].kwargs["headers"])
        self.assertNotIn("Authorization", request.call_args_list[1].kwargs["headers"])
        self.assertTrue(redirect.closed)

    def test_corrupt_cache_is_downloaded_again(self):
        with patch.object(self.client, "binary", return_value=Response()) as download:
            path, _ = cache_asset(self.client, "owner/repo", self.asset, self.cache)
            path.write_bytes(b"changed")
            cache_asset(self.client, "owner/repo", self.asset, self.cache)
        self.assertEqual(download.call_count, 2)
        self.assertEqual(path.read_bytes(), b"package")

    def test_valid_cache_does_not_download_again(self):
        with patch.object(self.client, "binary", return_value=Response()) as download:
            cache_asset(self.client, "owner/repo", self.asset, self.cache)
            cache_asset(self.client, "owner/repo", self.asset, self.cache)
        self.assertEqual(download.call_count, 1)

    def test_digest_mismatch_leaves_no_completed_cache(self):
        with patch.object(self.client, "binary", return_value=Response(b"invalid")):
            with self.assertRaises(SyncError):
                cache_asset(self.client, "owner/repo", self.asset, self.cache)
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_changed_source_uses_different_cache(self):
        with patch.object(self.client, "binary", return_value=Response()):
            previous, _ = cache_asset(self.client, "owner/repo", self.asset, self.cache)
            changed, _ = cache_asset(self.client, "owner/repo", {**self.asset, "updated_at": "later"}, self.cache)
        self.assertNotEqual(previous, changed)

    def test_sensitive_http_exception_is_not_reported(self):
        import requests
        with patch.object(self.client.session, "request", side_effect=requests.ConnectionError("secret-url-and-token")):
            with self.assertRaises(SyncError) as error:
                self.client.request("GET", GITHUB_API, "读取")
        self.assertNotIn("secret", str(error.exception))

    def test_path_and_control_characters_are_rejected(self):
        for name in ("../app.hap", "folder\\app.hap", "app\r\n.hap"):
            with self.subTest(name=name), self.assertRaises(SyncError):
                validate_asset({**self.asset, "name": name})

    def test_insecure_redirect_is_rejected(self):
        with self.assertRaises(SyncError):
            secure_url("http://example.com/file")


if __name__ == "__main__":
    unittest.main()
