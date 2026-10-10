"""Release 同步工具的终端进度与彩色结果，仅依赖标准库。"""

import ctypes
from ctypes import wintypes
import os
import shutil
import sys
import threading
import unicodedata


COLORS = {"success": "32", "error": "31", "warning": "33"}


def supports_ansi(stream) -> bool:
    if not stream.isatty() or os.environ.get("TERM") == "dumb":
        return False
    if os.name != "nt":
        return True
    try:
        import msvcrt

        library = ctypes.WinDLL("kernel32", use_last_error=True)
        library.GetConsoleMode.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        library.GetConsoleMode.restype = wintypes.BOOL
        library.SetConsoleMode.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        library.SetConsoleMode.restype = wintypes.BOOL
        handle = msvcrt.get_osfhandle(stream.fileno())
        mode = wintypes.DWORD()
        # Windows 控制台需要启用 VT；不支持时回退为普通文本。
        return bool(library.GetConsoleMode(handle, ctypes.byref(mode))
                    and library.SetConsoleMode(handle, mode.value | 0x0004))
    except (OSError, ValueError, AttributeError):
        return False


def text_width(value: str) -> int:
    return sum(0 if unicodedata.combining(character) else
               2 if unicodedata.east_asian_width(character) in ("W", "F") else 1 for character in value)


def fit_text(value: str, width: int) -> str:
    if text_width(value) <= width:
        return value
    suffix = "..." if width >= 3 else ""
    result = ""
    for character in value:
        if text_width(result + character) > width - len(suffix):
            break
        result += character
    return result + suffix


class Console:
    def __init__(self):
        self.lock = threading.RLock()
        self.active = None

    def report(self, message: str, level: str = "info", file=None) -> None:
        stream = sys.stdout if file is None else file
        with self.lock:
            if self.active:
                self.active.clear()
            if level in COLORS and "NO_COLOR" not in os.environ and supports_ansi(stream):
                message = f"\033[{COLORS[level]}m{message}\033[0m"
            print(message, file=stream, flush=True)
            if self.active:
                self.active.draw()


console = Console()
report = console.report


class TransferProgress:
    """传输线程只更新字节数，独立渲染线程维持动画并在退出时清理。"""

    def __init__(self, action: str, total: int | None):
        self.action = action
        self.total = total
        self.transferred = 0
        self.frame = 0
        self.stream = None
        self.thread = None
        self.stop = threading.Event()

    def __enter__(self):
        self.stream = sys.stdout
        if supports_ansi(self.stream):
            with console.lock:
                console.active = self
                self.draw()
            self.thread = threading.Thread(target=self.animate, name="release-sync-progress", daemon=True)
            self.thread.start()
        return self

    def __exit__(self, *args):
        self.stop.set()
        if self.thread:
            self.thread.join()
        with console.lock:
            if console.active is self:
                self.clear()
                console.active = None

    def update(self, transferred: int) -> None:
        with console.lock:
            self.transferred = transferred

    def set_total(self, total: int | None) -> None:
        with console.lock:
            self.total = total

    def render(self, columns: int) -> str:
        available = max(columns - 1, 1)
        amount = f"{self.transferred / (1024 * 1024):.1f} MiB"
        if self.total is not None:
            ratio = min(max(self.transferred / self.total, 0), 1) if self.total else 1
            bar_width = max(4, min(24, columns // 4))
            filled = int(bar_width * ratio)
            amount = (f"[{'=' * filled}{' ' * (bar_width - filled)}] {ratio:.0%}  "
                      f"{amount} / {self.total / (1024 * 1024):.1f} MiB")
        spinner = "|/-\\"[self.frame % 4]
        label_width = available - text_width(amount) - 6
        if label_width < 4:
            # 窄窗口优先保留状态和字节数，避免进度行折行污染历史输出。
            amount = f"{self.transferred / (1024 * 1024):.1f} MiB"
            label_width = max(0, available - len(amount) - 6)
        return fit_text(f"  {spinner} {fit_text(self.action, label_width)}  {amount}", available)

    def draw(self) -> None:
        columns = shutil.get_terminal_size(fallback=(100, 24)).columns
        self.stream.write("\r\033[2K" + self.render(columns))
        self.stream.flush()
        self.frame += 1

    def clear(self) -> None:
        self.stream.write("\r\033[2K")
        self.stream.flush()

    def animate(self) -> None:
        while not self.stop.wait(0.1):
            try:
                with console.lock:
                    if console.active is self:
                        self.draw()
            except (OSError, ValueError):
                self.stop.set()
