from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


class LauncherTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).resolve().parents[1] / "release-sync.py"
        spec = importlib.util.spec_from_file_location("release_sync_launcher", path)
        cls.launcher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.launcher)
        cls.root = path.parents[1]

    def test_missing_environment_can_be_declined(self):
        with patch.object(self.launcher, "environment_status", return_value=(False, "missing")), \
                patch("builtins.input", return_value="n"), \
                patch.object(self.launcher.subprocess, "run") as run, redirect_stdout(io.StringIO()):
            self.assertFalse(self.launcher.ensure_environment(self.root))
        run.assert_not_called()

    def test_enter_initializes_then_enters_ready_environment(self):
        with patch.object(self.launcher, "environment_status", side_effect=[(False, "missing"), (True, "ready")]), \
                patch("builtins.input", return_value=""), \
                patch.object(self.launcher.subprocess, "run", return_value=Mock(returncode=0)) as run, \
                redirect_stdout(io.StringIO()):
            self.assertTrue(self.launcher.ensure_environment(self.root))
        self.assertEqual(Path(run.call_args.args[0][-1]).name, "setup-release-sync.py")

    def test_initialization_failure_offers_retry_without_running_sync(self):
        with patch.object(self.launcher, "environment_status", return_value=(False, "missing")), \
                patch("builtins.input", side_effect=["", ""]), \
                patch.object(self.launcher.subprocess, "run", return_value=Mock(returncode=1)) as run, \
                redirect_stdout(io.StringIO()):
            self.assertFalse(self.launcher.ensure_environment(self.root))
        self.assertEqual(run.call_count, 1)

    def test_initialization_can_be_retried(self):
        with patch.object(self.launcher, "environment_status", side_effect=[(False, "missing"),
                                                                           (False, "missing"), (True, "ready")]), \
                patch("builtins.input", side_effect=["", "y", ""]), \
                patch.object(self.launcher.subprocess, "run", side_effect=[Mock(returncode=1), Mock(returncode=0)]), \
                redirect_stdout(io.StringIO()):
            self.assertTrue(self.launcher.ensure_environment(self.root))

    def test_empty_tag_and_force_answer_select_all_without_force(self):
        with patch("builtins.input", side_effect=["1", "", "", "0"]), \
                patch.object(self.launcher, "run_sync", return_value=0) as run, redirect_stdout(io.StringIO()):
            self.assertEqual(self.launcher.interactive_menu(self.root), 0)
        run.assert_called_once_with(self.root, ["--all"])

    def test_preview_passes_tag_and_force_then_returns_to_menu(self):
        with patch("builtins.input", side_effect=["2", " v1.6.5 ", "y", "0"]), \
                patch.object(self.launcher, "run_sync", return_value=0) as run, redirect_stdout(io.StringIO()):
            self.assertEqual(self.launcher.interactive_menu(self.root), 0)
        run.assert_called_once_with(self.root, ["--tag", "v1.6.5", "--force", "--dry-run"])

    def test_invalid_answers_are_reprompted(self):
        with patch("builtins.input", side_effect=["9", "1", "v1", "invalid", "n", "0"]), \
                patch.object(self.launcher, "run_sync", return_value=0) as run, redirect_stdout(io.StringIO()):
            self.assertEqual(self.launcher.interactive_menu(self.root), 0)
        run.assert_called_once_with(self.root, ["--tag", "v1"])

    def test_failed_sync_returns_to_menu_and_reports_failure(self):
        with patch("builtins.input", side_effect=["1", "v1", "", "0"]), \
                patch.object(self.launcher, "run_sync", return_value=1), redirect_stdout(io.StringIO()) as output:
            self.assertEqual(self.launcher.interactive_menu(self.root), 0)
        self.assertIn("未全部成功", output.getvalue())

    def test_cli_parameters_pass_through_and_preserve_exit_code(self):
        arguments = ["--tag", "v1", "--verify-only", "--platform", "gitee"]
        with patch.object(self.launcher, "ensure_environment", return_value=True), \
                patch.object(self.launcher, "run_sync", return_value=7) as run, \
                patch.object(self.launcher, "interactive_menu") as menu:
            self.assertEqual(self.launcher.main(arguments), 7)
        run.assert_called_once_with(self.root, arguments)
        menu.assert_not_called()

    def test_sync_uses_argument_array_without_shell_interpolation(self):
        tag = "v1 & echo unsafe"
        with patch.object(self.launcher.subprocess, "run", return_value=Mock(returncode=0)) as run:
            self.assertEqual(self.launcher.run_sync(self.root, ["--tag", tag]), 0)
        self.assertEqual(run.call_args.args[0][-1], tag)
        self.assertNotIn("shell", run.call_args.kwargs)
        self.assertEqual(run.call_args.kwargs["cwd"], self.root)

    def test_eof_exits_menu(self):
        with patch.object(self.launcher, "ensure_environment", return_value=True), \
                patch("builtins.input", side_effect=EOFError), redirect_stdout(io.StringIO()):
            self.assertEqual(self.launcher.main([]), 0)


if __name__ == "__main__":
    unittest.main()
