import hashlib
import importlib.util
import io
import json
import os
from contextlib import nullcontext, redirect_stderr, redirect_stdout
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from release_sync import (
    GITHUB_API, GITEE_API, GITCODE_API, SyncLock, HttpClient, Mirror, SyncError,
    ProgressFile, downloaded_asset, release_assets, secure_url, sync_asset, validate_asset,
)


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

    def json(self):
        return json.loads(self.body)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.client = HttpClient(GITHUB_API, "test-only-placeholder", attempts=1)
        self.asset = {"id": 123, "name": "app.hap", "size": 7, "updated_at": "2026-10-08",
                      "digest": "sha256:" + hashlib.sha256(b"package").hexdigest()}
        self.temporary = tempfile.TemporaryDirectory()
        self.work_dir = Path(self.temporary.name)
        self.temp_redirect = patch("release_sync.tempfile.tempdir", str(self.work_dir))
        self.temp_redirect.start()

    def tearDown(self):
        self.client.close()
        self.temp_redirect.stop()
        self.temporary.cleanup()

    def test_redirect_does_not_forward_platform_token(self):
        redirect = Response(status=302, headers={"Location": "https://objects.example/file?signature=placeholder"})
        with patch.object(self.client, "request", side_effect=[redirect, Response()]) as request:
            self.client.binary(f"{GITHUB_API}/repos/owner/repo/releases/assets/123", "下载").close()
        self.assertIn("Authorization", request.call_args_list[0].kwargs["headers"])
        self.assertNotIn("Authorization", request.call_args_list[1].kwargs["headers"])
        self.assertTrue(redirect.closed)

    def test_download_is_validated_and_deleted_after_context(self):
        with patch.object(self.client, "binary", return_value=Response()):
            with downloaded_asset(self.client, "owner/repo", self.asset) as (path, digest):
                self.assertEqual(path.read_bytes(), b"package")
                self.assertEqual(digest, self.asset["digest"].split(":")[1])
                self.assertEqual([item.name for item in path.parent.iterdir()], ["asset.bin"])
        self.assertFalse(path.parent.exists())
        self.assertEqual(list(self.work_dir.iterdir()), [])

    def test_separate_runs_always_download_fresh_source(self):
        with patch.object(self.client, "binary", return_value=Response()) as download:
            with downloaded_asset(self.client, "owner/repo", self.asset) as (previous, _):
                self.assertTrue(previous.exists())
            with downloaded_asset(self.client, "owner/repo", self.asset) as (current, _):
                self.assertFalse(previous.exists())
                self.assertNotEqual(previous, current)
        self.assertEqual(download.call_count, 2)
        self.assertEqual(list(self.work_dir.iterdir()), [])

    def test_digest_mismatch_leaves_no_temporary_file(self):
        with patch.object(self.client, "binary", return_value=Response(b"invalid")):
            with self.assertRaises(SyncError):
                with downloaded_asset(self.client, "owner/repo", self.asset):
                    self.fail("摘要不符时不能交给上传流程")
        self.assertEqual(list(self.work_dir.iterdir()), [])

    def test_consumer_failure_cleans_up_temporary_file(self):
        with patch.object(self.client, "binary", return_value=Response()):
            with self.assertRaises(RuntimeError):
                with downloaded_asset(self.client, "owner/repo", self.asset):
                    raise RuntimeError("上传失败")
        self.assertEqual(list(self.work_dir.iterdir()), [])

    def test_keyboard_interrupt_cleans_up_temporary_file(self):
        with patch.object(self.client, "binary", return_value=Response()):
            with self.assertRaises(KeyboardInterrupt):
                with downloaded_asset(self.client, "owner/repo", self.asset):
                    raise KeyboardInterrupt
        self.assertEqual(list(self.work_dir.iterdir()), [])

    def test_retry_restarts_partial_file_and_cleans_up_after_use(self):
        import requests

        class InterruptedResponse(Response):
            def iter_content(self, size):
                yield b"pack"
                raise requests.ConnectionError("private-signed-url")

        self.client.attempts = 2
        with patch.object(self.client, "binary", side_effect=[InterruptedResponse(), Response()]) as download, \
                patch("release_sync.time.sleep"), redirect_stdout(io.StringIO()):
            with downloaded_asset(self.client, "owner/repo", self.asset) as (path, _):
                self.assertEqual(path.read_bytes(), b"package")
        self.assertEqual(download.call_count, 2)
        self.assertEqual(list(self.work_dir.iterdir()), [])

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

    def test_interrupted_download_does_not_leave_temporary_file(self):
        import requests
        class InterruptedResponse(Response):
            def iter_content(self, size):
                yield b"pack"
                raise requests.ConnectionError("private-signed-url")
        response = InterruptedResponse()
        with patch.object(self.client, "binary", return_value=response):
            with self.assertRaises(SyncError) as error:
                with downloaded_asset(self.client, "owner/repo", self.asset):
                    self.fail("中断的下载不能交给上传流程")
        self.assertNotIn("private", str(error.exception))
        self.assertEqual(list(self.work_dir.iterdir()), [])
        self.assertTrue(response.closed)

    def test_attachment_list_is_paginated(self):
        first = [{**self.asset, "id": index + 1, "name": f"app-{index}.hap"} for index in range(100)]
        with patch.object(self.client, "json", side_effect=[first, [self.asset]]) as request:
            assets = release_assets(self.client, "owner/repo", {"id": 42}, [])
        self.assertEqual(len(assets), 101)
        self.assertEqual(request.call_args_list[1].kwargs["params"]["page"], 2)

    def test_write_requests_are_never_automatically_retried(self):
        self.client.attempts = 3
        with patch.object(self.client.session, "request", return_value=Response(status=503)) as request:
            response = self.client.request("POST", GITHUB_API, "上传")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(request.call_count, 1)

    def test_rate_limit_uses_bounded_retry_after(self):
        self.client.attempts = 2
        with patch.object(self.client.session, "request", side_effect=[
                Response(status=429, headers={"Retry-After": "999"}), Response()]), \
                patch("release_sync.time.sleep") as sleep:
            self.client.request("GET", GITHUB_API, "读取").close()
        sleep.assert_called_once_with(30)

    def test_malformed_signed_url_does_not_escape_safe_errors(self):
        with self.assertRaises(SyncError):
            secure_url("https://[invalid/file?signature=placeholder")


class MirrorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.work_dir = Path(self.temporary.name)
        self.path = self.work_dir / "source.bin"
        self.path.write_bytes(b"package")
        self.digest = hashlib.sha256(b"package").hexdigest()
        self.asset = {"id": 123, "name": "app.hap", "size": 7}
        self.existing = {"id": 456, "name": "app.hap", "browser_download_url": "https://files.example/app.hap"}
        self.client = HttpClient(GITCODE_API, "test-only-placeholder", attempts=1)
        self.mirror = Mirror("gitcode", "owner/repo", self.client)

    def tearDown(self):
        self.client.close()
        self.temporary.cleanup()

    def sync(self, **kwargs):
        return sync_asset(self.mirror, "v1", self.asset, self.path, self.digest, **kwargs)

    def test_same_name_skips_without_downloading_even_if_bytes_differ(self):
        with patch.object(self.mirror, "find", return_value=self.existing), \
                patch.object(self.client, "binary") as download, \
                patch.object(self.mirror, "upload") as upload, patch.object(self.mirror, "delete") as delete:
            self.assertIn("未校验内容", self.sync())
        download.assert_not_called()
        upload.assert_not_called()
        delete.assert_not_called()

    def test_verify_only_detects_changed_content_without_mutations(self):
        with patch.object(self.mirror, "find", return_value=self.existing), \
                patch.object(self.client, "binary", return_value=Response(b"changed")), \
                patch.object(self.mirror, "upload") as upload, patch.object(self.mirror, "delete") as delete:
            with self.assertRaisesRegex(SyncError, "SHA-256 不符"):
                self.sync(verify_only=True)
        upload.assert_not_called()
        delete.assert_not_called()

    def test_timeout_after_success_queries_and_verifies_without_retry(self):
        with patch.object(self.mirror, "find", side_effect=[None, self.existing]), \
                patch.object(self.client, "binary", return_value=Response()), \
                patch.object(self.mirror, "upload", side_effect=SyncError("网络超时")) as upload:
            self.assertIn("SHA-256 已验证", self.sync())
        self.assertEqual(upload.call_count, 1)

    def test_unconfirmed_upload_is_not_blindly_retried(self):
        with patch.object(self.mirror, "find", return_value=None), \
                patch.object(self.mirror, "upload", side_effect=SyncError("网络超时")) as upload, \
                patch("release_sync.time.sleep"):
            with self.assertRaisesRegex(SyncError, "远端尚未确认"):
                self.sync()
        self.assertEqual(upload.call_count, 1)

    def test_upload_bytes_are_checked(self):
        with patch.object(self.mirror, "find", side_effect=[None, self.existing]), \
                patch.object(self.client, "binary", return_value=Response(b"changed")), \
                patch.object(self.mirror, "upload"):
            with self.assertRaisesRegex(SyncError, "SHA-256 不符"):
                self.sync()

    def test_verify_only_does_not_create_missing_attachment(self):
        with patch.object(self.mirror, "find", return_value=None), patch.object(self.mirror, "upload") as upload:
            with self.assertRaisesRegex(SyncError, "目标附件缺失"):
                self.sync(verify_only=True)
        upload.assert_not_called()

    def test_force_replaces_identical_attachment_without_old_download(self):
        order = []
        with patch.object(self.mirror, "find", side_effect=[self.existing, {**self.existing, "id": 789}]), \
                patch.object(self.client, "binary", return_value=Response()) as download, \
                patch.object(self.mirror, "delete", side_effect=lambda *args: order.append("delete")), \
                patch.object(self.mirror, "upload", side_effect=lambda *args: order.append("upload")):
            self.assertIn("SHA-256 已验证", self.sync(force=True))
        self.assertEqual(order, ["delete", "upload"])
        self.assertEqual(download.call_count, 1)

    def test_force_validates_source_before_deleting(self):
        self.path.write_bytes(b"corrupt")
        with patch.object(self.mirror, "find", return_value=self.existing), \
                patch.object(self.mirror, "delete") as delete:
            with self.assertRaisesRegex(SyncError, "本地源文件校验失败"):
                self.sync(force=True)
        delete.assert_not_called()

    def test_force_waits_for_new_attachment_id(self):
        with patch.object(self.mirror, "find", side_effect=[self.existing, self.existing,
                                                          {**self.existing, "id": 789}]), \
                patch.object(self.client, "binary", return_value=Response()) as download, \
                patch.object(self.mirror, "delete"), patch.object(self.mirror, "upload"), \
                patch("release_sync.time.sleep"):
            self.assertIn("上传成功", self.sync(force=True))
        self.assertEqual(download.call_count, 1)

    def test_gitcode_upload_uses_signed_headers_and_raw_file(self):
        signed_headers = {"x-obs-callback": "test-placeholder", "Content-Type": "application/octet-stream"}
        def upload_request(method, url, action, **kwargs):
            self.assertEqual(method, "PUT")
            self.assertEqual(kwargs["headers"], signed_headers)
            self.assertNotIn("Authorization", kwargs["headers"])
            self.assertEqual(kwargs["data"].read(), b"package")
            return Response()
        with patch.object(self.client, "json", return_value={"url": "https://objects.example/upload",
                                                            "headers": signed_headers}), \
                patch.object(self.client, "request", side_effect=upload_request):
            self.mirror.upload("v1", self.asset, self.path)

    def test_gitee_upload_streams_multipart_with_original_filename(self):
        mirror = Mirror("gitee", "owner/repo", self.client)
        def check_request(method, url, action, **kwargs):
            self.assertEqual(method, "POST")
            self.assertIn("multipart/form-data", kwargs["headers"]["Content-Type"])
            body = kwargs["data"].read()
            self.assertIn(b'filename="app.hap"', body)
            self.assertIn(b"package", body)
            return Response()
        with patch.object(mirror, "release", return_value={"id": 42}), \
                patch.object(self.client, "request", side_effect=check_request):
            mirror.upload("v1", self.asset, self.path)

    def test_gitcode_source_archives_are_not_uploads(self):
        with patch.object(self.mirror, "release", return_value={"assets": [
                {"name": "v1.zip", "type": "source"}, {**self.existing, "type": "attach"}]}):
            self.assertEqual(self.mirror.assets("v1"), [{**self.existing, "type": "attach"}])

    def test_duplicate_remote_names_are_rejected(self):
        with patch.object(self.mirror, "assets", return_value=[self.existing, self.existing]):
            with self.assertRaisesRegex(SyncError, "多个同名附件"):
                self.mirror.find("v1", "app.hap")

    def test_sync_lock_prevents_second_process(self):
        lock = SyncLock(self.work_dir / "sync.lock")
        try:
            with self.assertRaises(SyncError):
                SyncLock(self.work_dir / "sync.lock")
        finally:
            lock.close()
        SyncLock(self.work_dir / "sync.lock").close()

    def test_upload_progress_retains_length_and_position(self):
        import requests
        with self.path.open("rb") as file:
            progress = ProgressFile(file, "上传")
            request = requests.Request("PUT", "https://objects.example/upload", data=progress).prepare()
            self.assertEqual(request.headers["Content-Length"], "7")
            self.assertNotIn("Transfer-Encoding", request.headers)
            self.assertEqual(progress.read(3), b"pac")
            self.assertEqual(progress.tell(), 3)


class CliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).resolve().parents[1] / "sync-release-assets.py"
        spec = importlib.util.spec_from_file_location("sync_release_assets_cli", path)
        cls.cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.cli)

    def test_empty_tag_is_rejected_before_any_network_request(self):
        with patch.object(sys, "argv", ["sync-release-assets.py", "--tag", ""]), \
                patch.object(self.cli, "HttpClient") as client, redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                self.cli.main()
        self.assertEqual(error.exception.code, 2)
        client.assert_not_called()

    def test_one_platform_failure_does_not_stop_other_platform(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(self.cli, "SYNC_LOCK_PATH", Path(directory) / ".release-sync.lock"), \
                patch.object(sys, "argv", ["sync-release-assets.py", "--tag", "v1"]), \
                patch.object(self.cli, "HttpClient", return_value=Mock()), \
                patch.object(self.cli, "get_token", return_value="test-only-placeholder"), \
                patch.object(self.cli, "releases", return_value=[{"tag_name": "v1"}]), \
                patch.object(self.cli, "release_assets", return_value=[{"name": "app.hap"}]), \
                patch.object(Mirror, "assets", return_value=[]), \
                patch.object(self.cli, "downloaded_asset", return_value=nullcontext((Path(directory) / "source.bin", "digest"))), \
                patch.object(self.cli, "sync_asset", side_effect=[SyncError("上传失败"), "成功"]) as sync, \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(self.cli.main(), 1)
            self.assertFalse((Path(directory) / ".release-sync.lock").exists())
        self.assertEqual(sync.call_count, 2)
        self.assertEqual(sync.call_args_list[1].args[0].platform, "gitcode")

    def test_preview_does_not_download_create_lock_or_modify_remote(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(self.cli, "SYNC_LOCK_PATH", Path(directory) / ".release-sync.lock"), \
                patch.object(sys, "argv", ["sync-release-assets.py", "--tag", "v1", "--dry-run"]), \
                patch.object(self.cli, "HttpClient", return_value=Mock()), \
                patch.object(self.cli, "get_token", return_value="test-only-placeholder"), \
                patch.object(self.cli, "releases", return_value=[{"tag_name": "v1"}]), \
                patch.object(self.cli, "release_assets", return_value=[{"name": "app.hap", "size": 7}]), \
                patch.object(Mirror, "assets", return_value=[]), \
                patch.object(self.cli, "downloaded_asset") as download, patch.object(self.cli, "sync_asset") as sync, \
                redirect_stdout(io.StringIO()):
            self.assertEqual(self.cli.main(), 0)
            self.assertFalse((Path(directory) / ".release-sync.lock").exists())
        download.assert_not_called()
        sync.assert_not_called()

    def run_release(self, assets, targets, options=(), download_error=None, sync_results=None):
        self.gitee = Mock(platform="gitee")
        self.gitcode = Mock(platform="gitcode")
        self.gitee.assets.return_value = targets
        self.gitcode.assets.return_value = targets
        args = Mock(source="owner/repo", asset=[], force=False, verify_only=False,
                    dry_run=False)
        for name, value in options:
            setattr(args, name, value)
        with patch.object(self.cli, "release_assets", return_value=assets), \
                patch.object(self.cli, "downloaded_asset", return_value=nullcontext((Path("source.bin"), "digest")),
                             side_effect=download_error) as download, \
                patch.object(self.cli, "sync_asset", side_effect=sync_results) as sync, \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            result = self.cli.sync_release(Mock(), [self.gitee, self.gitcode], {"tag_name": "v1"}, args)
        return result, download, sync

    def test_default_same_names_never_downloads_any_binary(self):
        result, download, sync = self.run_release([{"name": "app.hap"}], [{"name": "app.hap"}])
        self.assertEqual(result, 0)
        download.assert_not_called()
        sync.assert_not_called()

    def test_missing_asset_downloads_source_once_for_both_platforms(self):
        result, download, sync = self.run_release([{"name": "app.hap"}], [])
        self.assertEqual(result, 0)
        self.assertEqual(download.call_count, 1)
        self.assertEqual(sync.call_count, 2)

    def test_filtered_sync_preserves_unselected_source_assets(self):
        source = [{"name": "app.hap"}, {"name": "debug.hap"}]
        target = source + [{"name": "extra.hap", "id": 99}]
        result, download, _ = self.run_release(source, target, [("asset", ["app.hap"])])
        self.assertEqual(result, 0)
        download.assert_not_called()
        self.gitee.delete.assert_called_once_with("v1", target[-1])
        self.gitcode.delete.assert_called_once_with("v1", target[-1])

    def test_failed_platform_upload_suppresses_only_its_pruning(self):
        extra = {"name": "extra.hap"}
        result, _, sync = self.run_release([{"name": "app.hap"}], [extra],
                                          sync_results=[SyncError("上传失败"), "成功"])
        self.assertEqual(result, 1)
        self.assertEqual(sync.call_count, 2)
        self.gitee.delete.assert_not_called()
        self.gitcode.delete.assert_called_once_with("v1", extra)

    def test_source_download_failure_prevents_force_deletion_and_pruning(self):
        result, _, sync = self.run_release([{"name": "app.hap"}],
                                          [{"name": "app.hap"}, {"name": "extra.hap"}],
                                          [("force", True)], download_error=SyncError("下载失败"))
        self.assertEqual(result, 1)
        sync.assert_not_called()
        self.gitee.delete.assert_not_called()
        self.gitcode.delete.assert_not_called()

    def test_empty_source_release_prunes_uploaded_assets(self):
        extra = {"name": "extra.hap"}
        result, download, _ = self.run_release([], [extra])
        self.assertEqual(result, 0)
        download.assert_not_called()
        self.gitee.delete.assert_called_once_with("v1", extra)

    def test_preview_shows_extra_without_mutating(self):
        result, download, sync = self.run_release([{"name": "app.hap"}], [{"name": "extra.hap"}],
                                                 [("dry_run", True), ("force", True)])
        self.assertEqual(result, 0)
        download.assert_not_called()
        sync.assert_not_called()
        self.gitee.delete.assert_not_called()
        self.gitcode.delete.assert_not_called()

    def test_verify_only_never_prunes(self):
        result, _, _ = self.run_release([{"name": "app.hap"}], [{"name": "extra.hap"}],
                                       [("verify_only", True)])
        self.assertEqual(result, 0)
        self.gitee.delete.assert_not_called()
        self.gitcode.delete.assert_not_called()

    def test_duplicate_names_prevent_all_mutations(self):
        result, download, sync = self.run_release([], [{"name": "app.hap"}, {"name": "app.hap"}])
        self.assertEqual(result, 2)
        download.assert_not_called()
        sync.assert_not_called()
        self.gitee.delete.assert_not_called()

    def test_pruning_occurs_after_every_selected_asset_is_synced(self):
        events = []
        mirror = Mock(platform="gitee")
        mirror.assets.return_value = [{"name": "extra.hap"}]
        mirror.delete.side_effect = lambda *args: events.append("delete")
        args = Mock(source="owner/repo", asset=[], force=False, verify_only=False,
                    dry_run=False)
        with patch.object(self.cli, "release_assets", return_value=[{"name": "app.hap"}, {"name": "debug.hap"}]), \
                patch.object(self.cli, "downloaded_asset", return_value=nullcontext((Path("source.bin"), "digest"))), \
                patch.object(self.cli, "sync_asset", side_effect=lambda *args: events.append("sync") or "成功"), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(self.cli.sync_release(Mock(), [mirror], {"tag_name": "v1"}, args), 0)
        self.assertEqual(events, ["sync", "sync", "delete"])

    def test_missing_filter_aborts_before_target_inventory_or_mutations(self):
        mirror = Mock(platform="gitee")
        args = Mock(source="owner/repo", asset=["missing.hap"])
        with patch.object(self.cli, "release_assets", return_value=[{"name": "app.hap"}]), \
                redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(SyncError, "指定附件不存在"):
                self.cli.sync_release(Mock(), [mirror], {"tag_name": "v1"}, args)
        mirror.assets.assert_not_called()
        mirror.delete.assert_not_called()

    def test_terminal_colors_distinguish_success_error_and_paused_pruning(self):
        output = io.StringIO()
        errors = io.StringIO()
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(self.cli, "SYNC_LOCK_PATH", Path(directory) / ".release-sync.lock"), \
                patch.object(self.cli, "HttpClient", return_value=Mock()), \
                patch.object(self.cli, "get_token", return_value="test-only-placeholder"), \
                patch.object(self.cli, "releases", return_value=[{"tag_name": "v1"}]), \
                patch.object(self.cli, "release_assets", return_value=[{"name": "app.hap"}]), \
                patch.object(Mirror, "assets", return_value=[]), \
                patch.object(self.cli, "downloaded_asset", return_value=nullcontext((Path(directory) / "source.bin", "digest"))), \
                patch.object(self.cli, "sync_asset", side_effect=[SyncError("上传失败"), "上传成功，SHA-256 已验证"]), \
                patch("release_sync_terminal.supports_ansi", return_value=True), \
                patch.dict(os.environ, {}, clear=True), redirect_stdout(output), redirect_stderr(errors):
            self.assertEqual(self.cli.main(["--tag", "v1"]), 1)
        self.assertIn("\033[32m  gitcode：app.hap — 上传成功，SHA-256 已验证\033[0m", output.getvalue())
        self.assertIn("\033[33m  gitee：本轮有失败，暂停删除多余附件\033[0m", output.getvalue())
        self.assertIn("\033[31m处理结束：1 项失败\033[0m", output.getvalue())
        self.assertIn("\033[31m  gitee / app.hap 失败：上传失败\033[0m", errors.getvalue())

    def test_redirected_verified_sync_keeps_compact_results_without_control_codes(self):
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(self.cli, "SYNC_LOCK_PATH", Path(directory) / ".release-sync.lock"), \
                patch.object(self.cli, "HttpClient", return_value=Mock()), \
                patch.object(self.cli, "get_token", return_value="test-only-placeholder"), \
                patch.object(self.cli, "releases", return_value=[{"tag_name": "v1"}]), \
                patch.object(self.cli, "release_assets", return_value=[{"name": "app.hap"}]), \
                patch.object(Mirror, "assets", return_value=[]), \
                patch.object(self.cli, "downloaded_asset", return_value=nullcontext((Path(directory) / "source.bin", "digest"))), \
                patch.object(self.cli, "sync_asset", return_value="上传成功，SHA-256 已验证"), redirect_stdout(output):
            self.assertEqual(self.cli.main(["--tag", "v1"]), 0)
        self.assertEqual(len(output.getvalue().splitlines()), 4)
        self.assertNotIn("\033", output.getvalue())
        self.assertNotIn("\r", output.getvalue())

    def test_each_asset_is_shared_by_platforms_then_deleted_before_next_asset(self):
        source = [{"id": 123, "name": "app.hap", "size": 7}, {"id": 124, "name": "debug.hap", "size": 7}]
        observed = {}
        client = HttpClient(GITHUB_API, attempts=1)
        mirrors = [Mock(platform="gitee"), Mock(platform="gitcode")]
        for mirror in mirrors:
            mirror.assets.return_value = []
        args = Mock(source="owner/repo", asset=[], force=False, verify_only=False, dry_run=False)

        def upload(mirror, tag, asset, path, *args):
            if asset["name"] not in observed:
                self.assertTrue(all(not previous.exists() for previous in observed.values()))
                observed[asset["name"]] = path
            self.assertEqual(path, observed[asset["name"]])
            self.assertEqual(path.read_bytes(), b"package")
            return "成功"

        try:
            with tempfile.TemporaryDirectory() as directory, \
                    patch("release_sync.tempfile.tempdir", directory), \
                    patch.object(client, "binary", return_value=Response()) as download, \
                    patch.object(self.cli, "release_assets", return_value=source), \
                    patch.object(self.cli, "sync_asset", side_effect=upload) as sync, redirect_stdout(io.StringIO()):
                self.assertEqual(self.cli.sync_release(client, mirrors, {"tag_name": "v1"}, args), 0)
                self.assertEqual(list(Path(directory).iterdir()), [])
            self.assertEqual(download.call_count, 2)
            self.assertEqual(sync.call_count, 4)
        finally:
            client.close()

    def test_upload_failure_or_interrupt_leaves_no_payload_or_sync_lock(self):
        for failure, expected in ((SyncError("上传失败"), 1), (KeyboardInterrupt(), 130)):
            with self.subTest(failure=type(failure).__name__), tempfile.TemporaryDirectory() as directory:
                client = HttpClient(GITHUB_API, attempts=1)
                source = {"id": 123, "name": "app.hap", "size": 7}
                try:
                    with patch("release_sync.tempfile.tempdir", directory), \
                            patch.object(self.cli, "SYNC_LOCK_PATH", Path(directory) / ".release-sync.lock"), \
                            patch.object(self.cli, "HttpClient", return_value=client), \
                            patch.object(client, "binary", return_value=Response()), \
                            patch.object(self.cli, "get_token", return_value="test-only-placeholder"), \
                            patch.object(self.cli, "releases", return_value=[{"tag_name": "v1"}]), \
                            patch.object(self.cli, "release_assets", return_value=[source]), \
                            patch.object(Mirror, "assets", return_value=[]), \
                            patch.object(self.cli, "sync_asset", side_effect=failure), \
                            redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                        self.assertEqual(self.cli.main(["--tag", "v1"]), expected)
                    self.assertEqual(list(Path(directory).iterdir()), [])
                finally:
                    client.close()

    def test_removed_cache_options_are_rejected_before_network(self):
        for options in (["--cache-dir", "unused"], ["--download-only"]):
            with self.subTest(options=options), patch.object(self.cli, "HttpClient") as client, \
                    redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    self.cli.main(["--tag", "v1", *options])
            self.assertEqual(error.exception.code, 2)
            client.assert_not_called()


if __name__ == "__main__":
    unittest.main()
