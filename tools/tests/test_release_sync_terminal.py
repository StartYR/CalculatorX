from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release_sync_terminal as terminal


class TerminalTests(unittest.TestCase):
    def test_redirected_output_has_only_results_without_animation_or_color(self):
        output = io.StringIO()
        with redirect_stdout(output):
            with terminal.TransferProgress("下载 package.hap", 100) as progress:
                for amount in (10, 50, 100):
                    progress.update(amount)
            terminal.report("完成", "success")
        self.assertEqual(output.getvalue(), "完成\n")

    def test_known_total_uses_equals_and_spaces_without_dashes(self):
        progress = terminal.TransferProgress("上传 gitcode", 100)
        progress.update(59)
        rendered = progress.render(100)
        bar = rendered.split("[")[1].split("]")[0]
        self.assertTrue(bar.startswith("="))
        self.assertTrue(bar.endswith(" "))
        self.assertNotIn("-", bar)
        self.assertIn("59%", rendered)

    def test_unknown_and_zero_size_are_handled_without_fake_percent_or_division_error(self):
        progress = terminal.TransferProgress("验证", None)
        progress.update(1024 * 1024)
        self.assertIn("1.0 MiB", progress.render(100))
        self.assertNotIn("%", progress.render(100))
        progress.set_total(0)
        self.assertIn("100%", progress.render(100))

    def test_long_chinese_label_fits_narrow_terminal(self):
        progress = terminal.TransferProgress("验证 GitCode / " + "安装包" * 30 + ".hap", 100)
        progress.update(59)
        for columns in (12, 40, 80, 120):
            self.assertLessEqual(terminal.text_width(progress.render(columns)), columns - 1)

    def test_spinner_keeps_animating_without_new_bytes_and_stops_after_exit(self):
        output = io.StringIO()
        seen_last_frame = threading.Event()
        original_write = output.write

        def record(value):
            result = original_write(value)
            if "  \\ " in value:
                seen_last_frame.set()
            return result

        with redirect_stdout(output), patch.object(terminal, "supports_ansi", return_value=True), \
                patch.object(output, "write", side_effect=record):
            with terminal.TransferProgress("下载", 100) as progress:
                self.assertTrue(seen_last_frame.wait(2))
            finished = output.getvalue()
            self.assertFalse(progress.thread.is_alive())
        self.assertIn("  | ", finished)
        self.assertIn("  / ", finished)
        self.assertIn("  - ", finished)
        self.assertIn("  \\ ", finished)
        self.assertNotIn("\n", finished)
        self.assertTrue(finished.endswith("\r\033[2K"))

    def test_error_during_transfer_clears_line_and_leaves_readable_error(self):
        output = io.StringIO()
        with redirect_stdout(output), patch.object(terminal, "supports_ansi", return_value=True), \
                patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RuntimeError):
                with terminal.TransferProgress("上传", 100):
                    raise RuntimeError("失败")
            terminal.report("上传失败", "error")
        self.assertIsNone(terminal.console.active)
        self.assertIn("\r\033[2K\033[31m上传失败\033[0m\n", output.getvalue())

    def test_warning_is_preserved_while_live_progress_continues(self):
        output = io.StringIO()
        with redirect_stdout(output), patch.object(terminal, "supports_ansi", return_value=True), \
                patch.dict(os.environ, {}, clear=True):
            with terminal.TransferProgress("下载", 100):
                terminal.report("重试", "warning")
        self.assertEqual(output.getvalue().count("重试"), 1)
        self.assertIn("\033[33m重试\033[0m\n\r\033[2K", output.getvalue())

    def test_success_and_error_and_warning_have_respective_colors(self):
        output = io.StringIO()
        with redirect_stdout(output), patch.object(terminal, "supports_ansi", return_value=True), \
                patch.dict(os.environ, {}, clear=True):
            for level in ("success", "error", "warning"):
                terminal.report(level, level)
        self.assertEqual(output.getvalue(), "\033[32msuccess\033[0m\n\033[31merror\033[0m\n"
                         "\033[33mwarning\033[0m\n")

    def test_no_color_disables_color_without_disabling_live_progress(self):
        output = io.StringIO()
        with redirect_stdout(output), patch.object(terminal, "supports_ansi", return_value=True), \
                patch.dict(os.environ, {"NO_COLOR": "1"}):
            with terminal.TransferProgress("下载", 100):
                terminal.report("完成", "success")
        self.assertIn("完成\n", output.getvalue())
        self.assertIn("\r\033[2K", output.getvalue())
        self.assertNotIn("\033[32m", output.getvalue())

    def test_dumb_terminal_uses_plain_text(self):
        stream = io.StringIO()
        with patch.object(stream, "isatty", return_value=True), patch.dict(os.environ, {"TERM": "dumb"}):
            self.assertFalse(terminal.supports_ansi(stream))


if __name__ == "__main__":
    unittest.main()
