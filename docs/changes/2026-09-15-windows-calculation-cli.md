# Windows 命令行计算自动化

- 状态：已完成
- 类型：开发与测试工具
- 分支：`feature/calcx-cli`
- 完成日期：2026-09-15

## 变更摘要

新增 Windows PowerShell 调用器和仅存在于 `ohosTest` target 的设备端计算入口。维护者可以输入 LaTeX、模式、角度制和精度，通过 HDC 取得真实 MathLive、N-API 与 C++ 引擎生成的结构化 LaTeX 结果。

完整构建、安装、调用、退出码和排障方式见 [Windows 命令行计算自动化](../calculation-cli-automation.md)。

## 行为与实现

- Windows 请求和设备响应使用 UTF-8 JSON 与 URL-safe Base64。
- 每次请求带有关联 ID，调用器只接受协议版本和请求 ID 匹配的结果。
- 测试 WebView 复用正式 `calculator.html` 和 `EngineService` 四步计算链路。
- 测试 HAP 调用真实 `libentry.so`，不使用模板原生 mock。
- 支持 standard、matrix 和 equation；函数图像采样不属于 LaTeX 结果协议。
- 设备计算错误、基础设施错误和超时使用不同退出码。

## 兼容性与边界

- 正式 UI、按键和 C++ 引擎未因本功能修改。
- 命令行直接输入 LaTeX，不覆盖按键翻译、光标和编辑器状态测试。
- 测试代码不进入 `entry/default/release` HAP。
- 命令行计算不写历史记录或用户首选项。

## 验证

- `entry@ohosTest/debug` 和 `entry@default/release` 构建成功。
- debug 主应用和测试 HAP 在设备上覆盖安装成功。
- 基础、分数、角度、精度、矩阵、方程、非法表达式、特殊字符、连续调用和冷启动用例通过。
- 真实 UI 点按 `1+1=` 显示 `2`，与命令行结果一致。
- 测试 HAP 字节码保留 `libentry.so` 引用且不含 mock 标记。
- 正式 release HAP 只声明 `EntryAbility`，测试标记扫描为零；测试 HAP 的同一扫描能命中，正对照有效。
- PowerShell 语法、协议自检和 `git diff --check` 通过。
- 未故意制造设备长时间卡死，因此强制超时终止分支未做设备运行验证。

## 主要文件

- `tools/calcx/runtime/commands/Invoke-CalcXCalculation.ps1`
- `entry/src/ohosTest/ets/test/CalculationCli.test.ets`
- `entry/src/ohosTest/ets/utils/CalculationTestBridge.ets`
- `entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ets`
- `entry/src/ohosTest/ets/testability/CalculationTestAbility.ets`
- `entry/src/ohosTest/ets/pages/CalculationTestPage.ets`
- `entry/src/ohosTest/module.json5`
- `entry/src/mock/mock-config.json5`

## 发布说明素材

为开发测试新增 Windows 到 HarmonyOS 设备的 LaTeX 计算自动化入口，可验证真实 MathLive、N-API 与 C++ 计算链路；该入口仅存在于测试包，不进入正式应用。

[返回变更说明索引](README.md)
