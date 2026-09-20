# CalculatorX CLI 启动器与工具目录

- 状态：已完成
- 类型：重构与开发工具
- 分支：`refactor/calcx-cli`
- 完成日期：2026-09-20

## 变更摘要

Windows 语义 CLI 现在可构建为 `calcx.exe` 并安装为当前用户命令。原先分散在仓库根目录和 `test/` 下的主机侧 CLI 文件已统一迁移到 `tools/calcx/`，设备侧 `entry/src/ohosTest/` 保持不变。

完整构建、安装、调用和卸载方式见 [Windows 语义 CLI 自动化](../calculation-cli-automation.md)。

## 行为变化

- 日常调用从 `calcx.ps1 ...` 简化为 `calcx ...`。
- `calcx.exe` 按自身位置加载相邻 `runtime/calcx.ps1`，不保存仓库或开发者机器的绝对路径。
- 启动器保持调用者当前工作目录，透传命令行参数、标准输入输出和 PowerShell 退出码。
- 用户级安装默认位于 `%LOCALAPPDATA%\CalculatorX\CLI`，无需管理员权限。
- 构建产物和中间目录位于 `tools/calcx/dist/` 与 `tools/calcx/.build/`，均不纳入 Git。

## 设计与实现

- 原生启动器使用 Win32 `CreateProcessW` 调用 PowerShell 7，并按 Windows 参数解析规则转义 LaTeX、空格、引号和反斜杠。
- 构建脚本使用 CMake、Ninja 与 MinGW g++ 生成 Windows 可执行文件，并把 PowerShell 运行时复制为完整的便携目录。
- 安装和卸载脚本负责复制或移除完整运行时，并精确添加或删除当前用户 `PATH` 中的安装目录。
- 两个脚本均支持 `-SkipPathUpdate`，便于 CI 或维护者在隔离目录中验证而不改变用户环境。

## 兼容性与边界

- CLI 仍依赖 PowerShell 7、HDC、debug 主 HAP 与单独安装的 ohosTest HAP。
- Windows 启动器只负责定位和转发，不复制计算、协议或 UI 自动化逻辑。
- 本次目录整理不改变正式 HarmonyOS 应用及 release 包边界。
- JSON 用例和场景路径仍按调用者当前工作目录解析；文档中的仓库相对路径示例应从仓库根目录执行。

## 验证

- CMake、Ninja 与 MinGW g++ Release 构建成功。
- 通过构建后启动器执行协议自检和批量协议自检，退出码为 `0`。
- 帮助命令可从仓库外层级的工作目录执行，且当前目录保持不变。
- 非法命令退出码为 `2`；缺少运行时或找不到 `pwsh.exe` 时退出码为 `21`。
- 在隔离目录完成安装、运行和卸载，确认安装内容可独立运行、临时目录被清理且用户 `PATH` 未变化。
- 所有 CLI PowerShell 文件通过 AST 解析。
- `entry@ohosTest/debug` 构建并安装成功；通过新启动器执行单次 `1+1` 得到 `2`，批量引擎用例 4/4 通过。
- 导航场景 5/5、公式计算场景 6/6 通过；完全走语义点击的 `1 → + → 1 → =` 也从真实界面读取到结果 `2`。

## 主要文件

- `tools/calcx/launcher/main.cpp`
- `tools/calcx/launcher/CMakeLists.txt`
- `tools/calcx/runtime/`
- `tools/calcx/scripts/Build-CalcXLauncher.ps1`
- `tools/calcx/scripts/Install-CalcXCli.ps1`
- `tools/calcx/scripts/Uninstall-CalcXCli.ps1`
- `tools/calcx/tests/`
- `docs/calculation-cli-automation.md`

## 发布说明素材

开发测试用 Windows CLI 现可安装为 `calcx` 命令，启动器与运行时统一收纳于 `tools/calcx/`；正式应用功能和发布包不受影响。

[返回变更说明索引](README.md)
