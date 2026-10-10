"""Release 附件同步的环境检查与交互入口。"""

from pathlib import Path
import subprocess
import sys

from release_sync_environment import environment_python, environment_status
from release_sync_terminal import report


def ask_yes_no(prompt: str, default: bool) -> bool:
    while True:
        answer = input(prompt).strip().lower()
        if not answer:
            return default
        if answer in ("y", "yes", "是"):
            return True
        if answer in ("n", "no", "否"):
            return False
        report("请输入 y 或 n，也可直接回车选择默认值", "warning")


def ensure_environment(root: Path) -> bool:
    while True:
        ready, reason = environment_status(root)
        if ready:
            return True
        report(reason, "warning")
        if not ask_yes_no("是否创建或修复 .venv 并安装脚本依赖？此操作需要联网下载依赖。[Y/n]：", True):
            report("已取消环境初始化", "warning")
            return False
        # 修复损坏的环境时，使用基础解释器，避免替换正在运行的虚拟环境解释器。
        interpreter = getattr(sys, "_base_executable", None) or sys.executable
        result = subprocess.run([interpreter, "-X", "utf8", str(root / "tools" / "setup-release-sync.py")])
        if result.returncode == 0:
            ready, reason = environment_status(root)
            if ready:
                return True
            report(f"初始化后检查失败：{reason}", "error")
        if not ask_yes_no("初始化未成功，是否重试？[y/N]：", False):
            return False


def run_sync(root: Path, arguments: list[str]) -> int:
    command = [str(environment_python(root)), "-X", "utf8",
               str(root / "tools" / "sync-release-assets.py"), *arguments]
    return subprocess.run(command, cwd=root).returncode


def interactive_menu(root: Path) -> int:
    while True:
        print("\nCalculatorX Release 附件同步\n1. 同步附件\n2. 预览同步计划\n0. 退出", flush=True)
        choice = input("请选择操作：").strip()
        if choice == "0":
            return 0
        if choice not in ("1", "2"):
            report("请输入 1、2 或 0", "warning")
            continue
        tag = input("请输入 Tag（例如 v1.6.5，直接回车处理全部已发布版本）：").strip()
        if any(ord(character) < 32 for character in tag):
            report("Tag 不能包含控制字符", "error")
            continue
        force = ask_yes_no("是否替换同名文件？[y/N]：", False)
        arguments = ["--tag", tag] if tag else ["--all"]
        if force:
            arguments.append("--force")
        if choice == "2":
            arguments.append("--dry-run")
        print(f"\n{'预览' if choice == '2' else '同步'}范围：{tag or '全部已发布版本（含预发布版）'}")
        print("同名附件：" + ("全部替换" if force else "跳过，不校验内容"))
        print("缺失附件：补传；多余附件：删除（平台生成的源码包除外）", flush=True)
        result = run_sync(root, arguments)
        if result == 0:
            report("操作完成", "success")
        elif result in (130, -2):
            report("操作已中止", "warning")
        else:
            report(f"操作未全部成功（退出码 {result}），请查看上方错误后重试", "error")


def main(argv=None) -> int:
    root = Path(__file__).resolve().parents[1]
    arguments = sys.argv[1:] if argv is None else argv
    try:
        if not ensure_environment(root):
            return 1
        return run_sync(root, arguments) if arguments else interactive_menu(root)
    except EOFError:
        print("\n输入已结束，退出")
        return 0
    except KeyboardInterrupt:
        report("\n已中止", "warning")
        return 130
    except OSError:
        report("无法启动环境安装或同步脚本，请检查 Python 和目录权限", "error")
        return 1


if __name__ == "__main__":
    sys.exit(main())
