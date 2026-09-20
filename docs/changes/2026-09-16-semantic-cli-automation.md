# Windows 语义 CLI 自动化

- 状态：已完成
- 类型：开发与测试工具
- 分支：`feature/calcx-cli`
- 完成日期：2026-09-16

## 变更摘要

将原有的单次 LaTeX 计算入口扩展为 CalculatorX 语义 CLI。其首要用途是批量提交 LaTeX 并取得结构化计算结果，减少重复手工输入；界面状态、语义点击、公式或设置准备和 JSON 场景用于辅助核心计算回归与必要的问题复现。

完整构建、安装、命令、场景和排障方式见 [Windows 语义 CLI 自动化](../calculation-cli-automation.md)。

## 行为变化

- `tools/calcx/runtime/calcx.ps1` 提供统一命令分派，并由仓库根目录的 `calcx.exe` 启动。
- 支持单次及批量计算、APP 启停、屏幕和控件读取、公式和设置读取、语义点击、返回、测试状态准备及场景执行。
- 普通 UI 命令复用已经启动的 APP；只有公式和设置准备为同步真实状态而受控重启。
- 真实点击按稳定 ID 查找当前控件，再根据 UI 树中的实时边界执行，不依赖截图、界面文字或硬编码坐标。
- 输出区分 `engine`、`setup`、`ui` 和 `ui-tree`，避免把直接准备状态误报为真实用户操作。

## 设计与实现

- 页面、导航、模块、公式区、普通按键和主要设置控件使用稳定、与本地化无关的语义 ID。
- debug 主包通过 `accessibilityDescription` 暴露公式与设置机器状态；release 返回空描述，正常无障碍文本保持不变。
- 公式准备使用仅 debug 消费的一次性偏好记录，消费后立即删除。
- 设置准备通过 `AbilityMonitor` 获取正式 `EntryAbility` 的 Context，避免 `ohosTest` 与 `entry` 偏好空间隔离导致写入无效。
- 场景执行器支持动作、等待、断言、变量替换、失败即停和继续收集。

## 兼容性与边界

- CLI 控制能力依赖单独安装的 `entry-ohosTest-signed.hap`，正式发布只分发主 HAP。
- CLI 不以命令数量或 UI 覆盖率作为完整度指标，不为便于人工检查、与核心计算关系较弱或自动化成本过高的场景扩张能力。
- 不实现长按滑动气泡、设置页滑块与复杂选择器、MathLive 光标、图像曲线视觉判断、系统权限弹窗、浏览器或像素级视觉自动化。
- `engine` 结果复用真实 MathLive、N-API 和 C++ 引擎，但不能替代按键与编辑器交互验证。

## 验证

- `entry@default/debug`、`entry@ohosTest/debug`、`entry@default/release` 构建成功。
- debug 主应用和测试 HAP 覆盖安装成功；单次 `1+1` 和批量 4/4 通过。
- 真实语义点击 `1 -> + -> 1 -> =` 得到 `2`。
- 首页、侧栏、基础/科学模块、设置页、历史页和返回导航通过。
- `navigation-smoke.json` 5/5、`calculation-ui-smoke.json` 6/6 通过。
- 设置准备按 `radian -> degree -> radian` 验证并恢复原值。
- release HAP 为 `debug=false`、`buildMode=release`，只声明正式 Ability，未命中测试协议标记。
- release UI 树不暴露公式/设置机器 JSON；恢复 debug 主包后状态可见。

## 主要文件

- `tools/calcx/runtime/calcx.ps1`
- `tools/calcx/runtime/CalcXCli.Common.psm1`
- `tools/calcx/runtime/commands/Invoke-CalcXUi.ps1`
- `tools/calcx/runtime/commands/Invoke-CalcXFormula.ps1`
- `tools/calcx/runtime/commands/Invoke-CalcXSetup.ps1`
- `tools/calcx/runtime/commands/Invoke-CalcXScenario.ps1`
- `entry/src/main/ets/utils/SemanticIds.ets`
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/components/FormulaScreen.ets`
- `entry/src/ohosTest/ets/test/CalculationCli.test.ets`
- `entry/src/ohosTest/ets/utils/CalculationTestBridge.ets`

## 发布说明素材

为开发测试新增 Windows 语义 CLI，可读取 CalculatorX 真机界面状态、按稳定控件 ID 操作普通界面并执行 JSON 回归场景；控制入口仍隔离在测试包中，不进入正式发布包。

[返回变更说明索引](README.md)
