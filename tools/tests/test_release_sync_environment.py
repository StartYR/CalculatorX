from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release_sync_environment as environment


class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name).resolve()

    def tearDown(self):
        self.directory.cleanup()

    def test_missing_environment_does_not_launch_python(self):
        with patch.object(environment.subprocess, "run") as run:
            self.assertFalse(environment.environment_status(self.root)[0])
        run.assert_not_called()

    def test_healthy_environment_does_not_reinstall(self):
        with patch.object(environment, "environment_status", return_value=(True, "ready")), \
                patch.object(environment.venv, "EnvBuilder") as builder, \
                patch.object(environment.subprocess, "run") as run, redirect_stdout(io.StringIO()):
            self.assertEqual(environment.install_environment(self.root), 0)
        builder.assert_not_called()
        run.assert_not_called()

    def test_unrelated_directory_is_preserved(self):
        folder = self.root / ".venv"
        folder.mkdir()
        owned = folder / "user-data.txt"
        owned.write_text("retain", encoding="utf-8")
        with patch.object(environment.venv, "EnvBuilder") as builder, redirect_stdout(io.StringIO()):
            self.assertEqual(environment.install_environment(self.root), 1)
        self.assertEqual(owned.read_text(encoding="utf-8"), "retain")
        builder.assert_not_called()

    def test_failed_pip_returns_failure_and_keeps_environment(self):
        with patch.object(environment, "environment_status", return_value=(False, "missing")), \
                patch.object(environment.venv, "EnvBuilder") as builder, \
                patch.object(environment.subprocess, "run", return_value=Mock(returncode=1)), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(environment.install_environment(self.root), 1)
        builder.assert_called_once_with(with_pip=True)
        builder.return_value.create.assert_called_once_with(self.root / ".venv")

    def test_successful_setup_checks_environment_after_install(self):
        with patch.object(environment, "environment_status", side_effect=[(False, "missing"), (False, "missing"), (True, "ready")]), \
                patch.object(environment.venv, "EnvBuilder"), \
                patch.object(environment.subprocess, "run", return_value=Mock(returncode=0)) as run, \
                redirect_stdout(io.StringIO()):
            self.assertEqual(environment.install_environment(self.root), 0)
        self.assertEqual(run.call_args.args[0][-1], str(self.root / "tools" / "requirements-release-sync.txt"))

    def test_invalid_environment_process_is_reported_without_raw_error(self):
        interpreter = environment.environment_python(self.root)
        interpreter.parent.mkdir(parents=True)
        interpreter.touch()
        with patch.object(environment.subprocess, "run", side_effect=OSError("private-error")):
            ready, reason = environment.environment_status(self.root)
        self.assertFalse(ready)
        self.assertNotIn("private-error", reason)

    def test_check_rejects_interpreter_pointing_to_other_environment(self):
        interpreter = environment.environment_python(self.root)
        interpreter.parent.mkdir(parents=True)
        interpreter.touch()
        with patch.object(environment.subprocess, "run", return_value=Mock(returncode=0, stdout="C:/other/venv")):
            self.assertFalse(environment.environment_status(self.root)[0])

    def test_environment_creation_error_is_actionable(self):
        with patch.object(environment, "environment_status", return_value=(False, "missing")), \
                patch.object(environment.venv, "EnvBuilder", side_effect=OSError("private-error")), \
                redirect_stdout(io.StringIO()) as output:
            self.assertEqual(environment.install_environment(self.root), 1)
        self.assertIn("Python 安装", output.getvalue())
        self.assertNotIn("private-error", output.getvalue())

    def test_dependency_repair_does_not_overwrite_running_interpreter(self):
        with patch.object(environment, "environment_status", side_effect=[(False, "dependencies missing"),
                                                                         (True, "interpreter ready"),
                                                                         (True, "ready")]), \
                patch.object(environment.venv, "EnvBuilder") as builder, \
                patch.object(environment.subprocess, "run", return_value=Mock(returncode=0)) as run, \
                redirect_stdout(io.StringIO()):
            self.assertEqual(environment.install_environment(self.root), 0)
        builder.assert_not_called()
        self.assertIn("--force-reinstall", run.call_args.args[0])

    def test_failed_pip_repair_does_not_attempt_dependency_install(self):
        with patch.object(environment, "environment_status", side_effect=[(False, "dependencies missing"),
                                                                         (True, "interpreter ready")]), \
                patch.object(environment.venv, "EnvBuilder") as builder, \
                patch.object(environment.subprocess, "run", return_value=Mock(returncode=1)) as run, \
                redirect_stdout(io.StringIO()) as output:
            self.assertEqual(environment.install_environment(self.root), 1)
        builder.assert_not_called()
        self.assertEqual(run.call_count, 1)
        self.assertIn("pip 修复失败", output.getvalue())


if __name__ == "__main__":
    unittest.main()
