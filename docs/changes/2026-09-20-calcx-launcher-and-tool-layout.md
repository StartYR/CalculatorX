# CalculatorX CLI 启动器与工具目录

- 状态：已完成
- 类型：重构与开发工具
- 分支：`refactor/calcx-cli`
- 完成日期：2026-09-20

## 变更摘要

Windows 语义 CLI 现在通过纳入 Git 的根目录 `calcx.exe` 启动。原先分散在仓库根目录和 `test/` 下的主机侧 CLI 文件已统一迁移到 `tools/calcx/`，设备侧 `entry/src/ohosTest/` 保持不变。开发者克隆仓库后无需安装命令或修改用户 `PATH`。

完整调用、重新构建和真机准备方式见 [Windows 语义 CLI 自动化](../calculation-cli-automation.md)。

## 行为变化

- PowerShell 从仓库根目录使用 `.\calcx ...`；CMD 可使用 `calcx ...`，但复杂 LaTeX 推荐 PowerShell。
- `calcx.exe` 按自身位置加载 `tools/calcx/runtime/calcx.ps1`，不保存仓库或开发者机器的绝对路径。
- 启动器保持调用者当前工作目录，透传命令行参数、标准输入输出和 PowerShell 退出码。
- 根目录 `calcx.exe` 纳入 Git；编译中间目录 `tools/calcx/.build/` 不纳入 Git。

## 设计与实现

- 原生启动器使用 Win32 `CreateProcessW` 调用 PowerShell 7，并按 Windows 参数解析规则转义 LaTeX、空格、引号和反斜杠。
- 构建脚本使用 CMake、Ninja 与 MinGW g++ 生成 Windows 可执行文件，并直接覆盖仓库根目录的 `calcx.exe`。
- PowerShell 运行时保持独立；修改命令、协议、用例或场景不需要重新编译启动器。
- 不提供安装或卸载脚本，也不修改当前用户或系统 `PATH`。

## 兼容性与边界

- CLI 仍依赖 PowerShell 7、HDC、debug 主 HAP 与单独安装的 ohosTest HAP。
- Windows 启动器只负责定位和转发，不复制计算、协议或 UI 自动化逻辑。
- CMD 会预先解释部分 LaTeX 常用字符，因此仅作为简单命令的兼容入口，不作为文档主要示例。
- 本次目录整理不改变正式 HarmonyOS 应用及 release 包边界。
- JSON 用例和场景路径按仓库根目录解析；所有文档示例均从根目录执行。

## 验证

- CMake、Ninja 与 MinGW g++ Release 构建成功。
- PowerShell `.\calcx -SelfTest` 的协议自检和批量协议自检通过，退出码为 `0`。
- CMD 可在根目录通过 `calcx help` 找到启动器；PowerShell 裸命令 `calcx` 仍按自身机制拒绝从当前目录隐式执行。
- 非法命令退出码为 `2`；缺少运行时或找不到 `pwsh.exe` 时退出码为 `21`。
- 所有 CLI PowerShell 文件通过 AST 解析。
- `entry@ohosTest/debug` 构建并安装成功；通过新启动器执行单次 `1+1` 得到 `2`，批量引擎用例 4/4 通过。
- 导航场景 5/5、公式计算场景 6/6 通过；完全走语义点击的 `1 → + → 1 → =` 也从真实界面读取到结果 `2`。

## 主要文件

- `tools/calcx/launcher/main.cpp`
- `tools/calcx/launcher/CMakeLists.txt`
- `tools/calcx/runtime/`
- `tools/calcx/scripts/Build-CalcXLauncher.ps1`
- `tools/calcx/tests/`
- `calcx.exe`
- `docs/calculation-cli-automation.md`

## 发布说明素材

开发测试用 Windows CLI 现在可从仓库根目录直接运行，PowerShell 使用 `.\calcx`，无需安装或修改 `PATH`；正式应用功能和发布包不受影响。

[返回变更说明索引](README.md)
