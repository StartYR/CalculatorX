"""创建项目根目录 .venv 并安装 Release 同步依赖。"""

from pathlib import Path
import sys

from release_sync_environment import install_environment
from release_sync_terminal import report


if __name__ == "__main__":
    try:
        sys.exit(install_environment(Path(__file__).resolve().parents[1]))
    except KeyboardInterrupt:
        report("已中止环境安装，下次启动可重试", "warning")
        sys.exit(130)
