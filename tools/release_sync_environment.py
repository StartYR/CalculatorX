"""仅使用标准库检查和安装 Release 同步工具的本地环境。"""

from pathlib import Path
import subprocess
import sys
import venv


MINIMUM_PYTHON = (3, 10)
INTERPRETER_CHECK = """
from pathlib import Path
import sys
if sys.version_info < (3, 10) or sys.prefix == sys.base_prefix:
    sys.exit(1)
"""
DEPENDENCY_CHECK = """
import requests
import requests_toolbelt
from importlib.metadata import version
def parts(name):
    return tuple(int(part) for part in version(name).split('.')[:3])
if not ((2, 32, 5) <= parts('requests') < (3,) and (1, 0, 0) <= parts('requests-toolbelt') < (2,)):
    sys.exit(1)
"""


def environment_python(root: Path) -> Path:
    return root / ".venv" / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")


def environment_status(root: Path, check_dependencies: bool = True) -> tuple[bool, str]:
    environment = root / ".venv"
    if environment.resolve() != environment.absolute():
        return False, ".venv 指向其他目录，请使用项目内独立的虚拟环境"
    interpreter = environment_python(root)
    if not interpreter.is_file():
        return False, "未找到可用的 Python 虚拟环境"
    check = INTERPRETER_CHECK + (DEPENDENCY_CHECK if check_dependencies else "")
    check += "\nprint(str(Path(sys.prefix).resolve()))\n"
    try:
        result = subprocess.run([str(interpreter), "-X", "utf8", "-c", check],
                                capture_output=True, text=True, encoding="utf-8", timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return False, "虚拟环境的 Python 无法运行"
    if result.returncode or Path(result.stdout.strip()) != environment.resolve():
        return False, "虚拟环境版本、依赖或目录无效，需要修复"
    return True, "环境已就绪"


def install_environment(root: Path) -> int:
    if sys.version_info < MINIMUM_PYTHON:
        print("需要 Python 3.10 或更新版本")
        return 1
    environment = root / ".venv"
    if environment.resolve() != environment.absolute():
        print("无法安装：.venv 指向其他目录，请先处理此目录链接")
        return 1
    if environment.exists() and not (environment / "pyvenv.cfg").is_file():
        if not environment.is_dir() or any(environment.iterdir()):
            print("无法安装：.venv 已存在但不是虚拟环境，请先重命名该目录，再重新运行")
            return 1
    ready, _ = environment_status(root)
    if ready:
        print(".venv 环境已就绪，无需重复安装")
        return 0
    try:
        interpreter_ready, _ = environment_status(root, check_dependencies=False)
        if not interpreter_ready:
            print("创建或修复 .venv 虚拟环境……", flush=True)
            # 不清空已有目录，保留其中的其他依赖和文件。
            venv.EnvBuilder(with_pip=True).create(environment)
        else:
            result = subprocess.run([str(environment_python(root)), "-m", "ensurepip", "--upgrade"])
            if result.returncode:
                print("pip 修复失败，请检查 Python 安装和目录权限")
                return 1
        print("安装 Release 同步依赖（需要联网）……", flush=True)
        # 解释器正常时只修复依赖，避免 Windows 覆盖正在运行的 python.exe。
        repair = ["--force-reinstall"] if interpreter_ready else []
        result = subprocess.run([str(environment_python(root)), "-m", "pip", "install", *repair, "-r",
                                 str(root / "tools" / "requirements-release-sync.txt")])
        if result.returncode:
            print("依赖安装失败，请检查网络、pip 配置和磁盘空间后重试")
            return 1
    except (OSError, subprocess.SubprocessError):
        print("环境创建失败，请检查 Python 安装、目录权限和磁盘空间")
        return 1
    ready, reason = environment_status(root)
    print(".venv 初始化完成" if ready else f"环境检查失败：{reason}")
    return 0 if ready else 1
