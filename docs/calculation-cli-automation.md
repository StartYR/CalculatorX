# Windows 语义 CLI 自动化

本文档说明如何在 Windows PowerShell 7 中从仓库根目录通过 `.\calcx` 驱动 CalculatorX 真机测试。CLI 面向自动化回归、问题复现和 AI Agent；它不是正式应用面向普通用户的命令行功能，也不是追求界面全覆盖的通用自动化框架。

CLI 的首要目标是省去重复的手工公式输入，以批量方式向真实计算链路提交 LaTeX 表达式并取得结构化结果，从而高效判断解析和计算逻辑是否正确。界面状态、语义点击、测试状态准备和 JSON 场景是为核心计算回归、必要的问题复现与少量关键交互提供的辅助能力，不与批量计算具有同等扩展优先级。

是否增加一项 CLI 能力，应优先判断它能否显著减少高频、重复的人工测试，并且能否稳定地产生适合自动断言的结果。滑块、复杂选择器、长按拖拽、视觉表现等便于人工检查、与核心计算逻辑关系较弱或自动化成本明显偏高的场景，默认继续人工测试；未被 CLI 覆盖不表示功能或测试体系不完整。

## 1. 能力模型

CLI 将操作分为三条互不冒充的路径：

| `executionPath` | 用途 | 是否经过真实界面 |
| --- | --- | --- |
| `engine` | 直接提交 LaTeX，快速验证 MathLive、N-API 和 C++ 计算链路 | 否 |
| `setup` | 直接准备公式或白名单设置，构造测试前置状态 | 部分 |
| `ui` / `ui-tree` | 读取系统组件树、按语义 ID 点击、返回和验证用户可见状态 | 是 |

直接计算链路为：

```text
仓库根目录 calcx.exe
  -> tools/calcx/runtime/calcx.ps1
  -> hdc shell aa test
  -> entry_test / CalculationTestAbility
  -> calculator.html / MathLive Compute Engine
  -> EngineService
  -> libentry.so / C++ 计算引擎
  -> CALCX_TEST_RESULT
  -> Windows JSON 输出
```

`engine` 复用正式应用的 `calculator.html`、`EngineService` 和 `libentry.so`，但不经过可见按键、`InputTranslator` 和 MathLive 编辑状态。因此，同一最终 LaTeX 和配置应得到与正式界面相同的计算结果；按键映射、光标、撤销、`Ans`、`S⇄D` 或结果后继续输入仍应通过 `ui` 路径或人工操作验证。

`ui click` 先从当前 UI 树按稳定 ID 唯一定位控件，再读取当前边界并点击其中心。调用方不依赖截图、不传屏幕坐标，也不依赖中文或英文显示文本。

## 2. 前置条件

- Windows PowerShell 7。
- 已安装 DevEco Studio、HarmonyOS SDK 和 HDC。
- 设备已连接并授权调试，能出现在 `hdc list targets` 中。
- 设备上安装了同一次构建产生且签名匹配的 debug 主应用 HAP 和 `entry-ohosTest-signed.hap`。
- 在仓库根目录执行命令；仓库已经包含 `calcx.exe`，无需安装或修改用户 `PATH`。

先检查工具和设备：

```powershell
hdc version
hdc list targets
```

调用器依次从 `PATH`、`DEVECO_SDK_HOME`、`HARMONYOS_SDK_HOME`、DevEco 相关环境变量和 Windows 安装信息查找 HDC。仍无法找到时使用 `-HdcPath`；多台设备并存时使用 `-DeviceId`。

## 3. CLI 入口与重新构建

根目录的 `calcx.exe` 是纳入 Git 的轻量 Windows 启动器，实际命令分派仍由 `tools/calcx/runtime/calcx.ps1` 完成。启动器按自身位置定位运行时，不保存仓库绝对路径；其他开发者克隆仓库后无需执行安装脚本。

PowerShell 不会默认从当前目录查找命令，因此使用：

```powershell
.\calcx -SelfTest
.\calcx help
```

CMD 会自动查找当前目录，可以使用 `calcx "1+1"`，但不推荐将 CMD 用于复杂 LaTeX。CMD 会预先解释 `%`、`^`、`&`、`|`、`<`、`>` 和引号等字符，启动器无法恢复已经被 Shell 改写的参数；本文档统一使用 PowerShell 示例。

修改 PowerShell 命令、协议或场景时不需要重新编译。只有修改 `tools/calcx/launcher/` 下的启动器源码时，才需要准备 CMake、Ninja 和位于 `PATH` 中的 MinGW g++，然后在仓库根目录执行：

```powershell
.\tools\calcx\scripts\Build-CalcXLauncher.ps1 -Clean
```

构建脚本会覆盖仓库根目录的 `calcx.exe`；中间产物位于被 Git 忽略的 `tools/calcx/.build/`。重新生成启动器后应提交新的根目录 EXE，并重新执行本地自检和真机回归。

## 4. 应用构建与安装

可在 DevEco Studio 中分别构建 `entry/default/debug` 和 `entry/ohosTest/debug`。从终端构建时，将 `$devEcoHome` 指向本机 DevEco Studio 安装目录：

```powershell
$devEcoHome = '<DevEco Studio 安装目录>'
$env:DEVECO_SDK_HOME = Join-Path $devEcoHome 'sdk'
$hvigor = Join-Path $devEcoHome 'tools\hvigor\bin\hvigorw.bat'

& $hvigor `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  assembleHap `
  --analyze=normal `
  --incremental `
  --no-daemon

& $hvigor `
  --mode module `
  -p product=default `
  -p module=entry@ohosTest `
  -p buildMode=debug `
  assembleHap `
  --analyze=normal `
  --incremental `
  --no-daemon
```

安装两个 HAP：

```powershell
$device = '<hdc list targets 返回的设备 ID>'

hdc -t $device install -r `
  .\entry\build\default\outputs\default\entry-default-signed.hap

hdc -t $device install -r `
  .\entry\build\default\outputs\ohosTest\entry-ohosTest-signed.hap
```

修改正式 ArkTS、资源、`EngineService` 或原生引擎后应重新构建并安装两者。只修改 `ohosTest` 时通常只需重建并覆盖安装测试 HAP。构建模式会复用同一正式 HAP 路径，因此 release 构建后若要继续运行 CLI，应重新构建并安装 debug 主包。

## 5. 最短调用方式

在仓库根目录直接输入 LaTeX：

```powershell
.\calcx '1+1'
```

等价的完整写法：

```powershell
.\calcx engine calculate '1+1'
```

分数、角度制和精度：

```powershell
.\calcx engine calculate '\frac{1}{2}+\frac{1}{3}'
.\calcx engine calculate '\sin\left(30\right)' -Angle degree
.\calcx engine calculate '1\div3' -Precision 4
```

公共选项：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-Mode` | `standard` | `standard`、`matrix` 或 `equation` |
| `-Angle` | `radian` | `radian` 或 `degree` |
| `-Precision` | `auto` | `auto`、`decimal-auto` 或 `0` 至 `15` |
| `-DeviceId` | 自动选择唯一设备 | 多设备时必须指定 |
| `-HdcPath` | 自动查找 | HDC 可执行文件路径 |
| `-TimeoutSeconds` | 依命令而定 | 允许范围通常为 5 至 300 秒 |

## 6. 应用生命周期与状态读取

```powershell
.\calcx app status
.\calcx app start
.\calcx app stop

.\calcx screen get
.\calcx screen controls
.\calcx screen find calc.key.equals
.\calcx formula get
.\calcx settings get
```

`app start` 启动真实 `EntryAbility`。随后执行 `screen`、`formula get`、`settings get`、`ui click` 或 `ui back` 不会主动关闭或重启 APP，可以连续发送命令。每条命令会重新导出当前 UI 树，避免复用过期页面状态。

`screen get` 返回当前 Ability、页面、计算模块、弹层、公式、设置和语义控件数量。`screen controls` 返回带稳定 ID 的控件列表，包括类型、文本、描述、边界、可见性、启用、可点击和选中状态。

公式和设置机器状态只在 debug 主包中写入 `accessibilityDescription`。release 下这些描述为空，避免屏幕阅读器朗读机器 JSON；普通无障碍文本和稳定控件 ID 不受影响。

## 7. 语义点击与导航

```powershell
.\calcx ui click nav.sidebar.open
.\calcx ui click module.scientific
.\calcx ui click calc.key.1
.\calcx ui click calc.key.plus
.\calcx ui click calc.key.equals
.\calcx ui back
```

首版稳定 ID 包括：

- 页面：`app.page.index`、`app.page.settings`、`app.page.history`。
- 公式区：`calc.formula`。
- 导航：`nav.sidebar.open`、`nav.settings`、`nav.history.page`、`nav.history.sheet`、`nav.undo`、`nav.redo`。
- 模块：`module.basic`、`module.scientific`、`module.graphing`、`module.equation`、`module.matrix`、`module.statistics`、`module.unit`、`module.base`、`module.exchange`。
- 普通按键：`calc.key.0` 至 `calc.key.9`、`calc.key.plus`、`calc.key.minus`、`calc.key.multiply`、`calc.key.divide`、`calc.key.equals`、`calc.key.clear` 等。
- 设置控件：`settings.angle`、`settings.answer-output`、`settings.decimal-precision`、`settings.combination-style`、`settings.permutation-style`、`settings.startup-page`、`settings.color-mode`、`settings.haptic-feedback`、`settings.vibration-curve`。
- 弹层：`overlay.sidebar`、`overlay.sidebar.dismiss`。

点击白名单只接受 `nav.*`、`module.*`、`calc.key.*`、`settings.*` 和 `overlay.sidebar.dismiss`。目标必须在当前 UI 树中唯一、可见且启用；目标缺失或重复时不会退化为文字匹配或任意坐标点击。

不支持长按滑动气泡、拖拽、MathLive 光标精细控制、滑块与复杂选择器的完整操作、系统权限弹窗、外部浏览器、图像曲线正确性判断或像素级视觉验证。这些场景除非将来成为高频、稳定且直接影响核心计算正确性的回归路径，否则不应仅为了提高 CLI 覆盖率而实现。

## 8. 公式与设置准备

直接把完整 LaTeX 放入真实主界面：

```powershell
.\calcx formula set '\frac{1}{2}+\frac{1}{3}'
.\calcx formula clear
```

`formula set/clear` 属于 `setup` 路径。它会先停止 APP，通过测试包写入一次性公式记录，再启动真实 `EntryAbility`；正式 UI 消费后立即删除该记录，并从 UI 树核对实际输入。因此这两条命令会有一次受控重启，不能用来证明逐键输入行为正确。

直接准备白名单设置：

```powershell
.\calcx setup settings set angle degree
.\calcx setup settings set decimal-precision 4
.\calcx setup settings set haptic-feedback false
```

支持的设置和值：

| 设置键 | 允许值 |
| --- | --- |
| `angle` | `degree`、`radian` |
| `answer-output` | `auto`、`decimal` |
| `decimal-precision` | `auto`、`0` 至 `15` |
| `haptic-feedback` | `true`、`false` |
| `vibration-curve` | `0` 至 `3` |
| `startup-page` | `0` 至 `9` |
| `color-mode` | `light`、`dark`、`system` |
| `combination-style` | `0` 至 `4` |
| `permutation-style` | `0` 至 `4` |

设置准备同样会停止并重启 APP。测试模块通过 `AbilityMonitor` 取得新创建的正式 `EntryAbility`，使用它的真实 Context 写入偏好；不能用 `ohosTest` 自己的 Context，因为两个模块的 Preferences 空间相互隔离。命令成功后仍应使用 `settings get` 或实际设置页面核对。

## 9. 批量计算

默认用例文件位于 `tools/calcx/tests/cases/engine-smoke.json`：

```powershell
.\calcx engine batch .\tools\calcx\tests\cases\engine-smoke.json
```

格式：

```json
{
  "items": [
    { "latex": "1+1" },
    { "latex": "\\sin\\left(30\\right)", "angle": "degree" },
    { "latex": "1\\div3", "precision": "4" }
  ]
}
```

批量模式在一次测试会话和一次 WebView 初始化中顺序执行项目。每项具有独立 `requestId` 和结果，单项失败不会阻止其余项目，最终汇总决定进程退出码。

## 10. JSON 场景

仓库提供两个真机冒烟场景：

```powershell
.\calcx scenario run .\tools\calcx\tests\scenarios\navigation-smoke.json
.\calcx scenario run .\tools\calcx\tests\scenarios\calculation-ui-smoke.json
```

场景文件支持 `app.start`、`app.status`、`screen.get`、`screen.controls`、`screen.find`、`formula.get`、`formula.set`、`formula.clear`、`settings.get`、`ui.click`、`ui.back`、`engine.calculate`、`setup.settings.set`、`assert` 和 `wait`。顶层 `variables` 可通过 `${name}` 插入字符串。

示例：

```json
{
  "version": 1,
  "name": "calculation-ui-smoke",
  "steps": [
    { "command": "formula.set", "latex": "1+1" },
    { "command": "wait", "path": "formula.inputLatex", "equals": "1+1" },
    { "command": "ui.click", "target": "calc.key.equals" },
    { "command": "wait", "path": "formula.resultLatex", "equals": "2" }
  ]
}
```

默认遇到首个失败即停止。添加 `-ContinueOnFailure` 可继续收集后续失败。标准输出为逐步 NDJSON，末行是汇总对象。

场景中的普通读取和点击复用已经启动的 APP；只有 `formula set/clear` 和 `setup settings set` 为同步正式状态而有意重启。

## 11. 输出、退出码与 CI

成功时标准输出为紧凑 JSON 或 NDJSON，诊断信息写入标准错误。所有结构化响应包含协议版本、请求 ID、`ok` 和执行路径。

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功 |
| `2` | Windows 参数、场景或白名单值无效 |
| `10` | HDC 不可用或无法列出设备 |
| `11` | 没有设备，或指定设备未连接 |
| `12` | 连接了多台设备但未指定设备 |
| `13` | APP、测试模块、`aa test`、UI 输入或结果标记异常 |
| `14` | 等待设备、页面或进程超时 |
| `15` | 语义目标不存在或不唯一 |
| `16` | 语义目标不可见、禁用或不可点击 |
| `20` | 设备返回结构化业务失败或场景断言失败 |
| `21` | 其他协议或调用器错误 |

Hypium 用例失败时，部分系统上的 `hdc shell aa test` 仍可能返回进程退出码 `0`。调用器会继续验证固定结果标记、协议版本、请求 ID 和响应 `ok`；CI 也应同时检查 PowerShell 退出码与 JSON。

仅验证 Windows 端参数、JSON、UTF-8 和 URL-safe Base64：

```powershell
.\calcx -SelfTest
```

## 12. debug 与 release 隔离

CLI 控制能力依赖单独安装的 `entry-ohosTest-signed.hap`。发布时只分发 `entry@default/release` 的正式 HAP，不分发测试 HAP。

正式应用中保留稳定控件 ID 和正常无障碍文本；公式、设置等机器 JSON 描述由 `applicationInfo.debug` 门控，release 返回空描述。一次性公式记录也只在 debug 主包中消费。

发布构建：

```powershell
& $hvigor `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=release `
  assembleHap `
  --analyze=normal `
  --incremental `
  --no-daemon
```

正式 HAP 的 `module.json` 应满足：

- `app.debug` 为 `false`，`app.buildMode` 为 `release`。
- 模块名为 `entry`，主 Ability 为 `EntryAbility`。
- 不存在 `entry_test`、`CalculationTestAbility` 或其他测试 Ability。

正式字节码不应包含 `OpenHarmonyTestRunner`、`CALCX_TEST_RESULT`、`calcxRequest` 等测试协议标记。测试 HAP 则应包含这些标记和真实 `libentry.so` 引用，同时不包含 `Libentry.mock`、`NativeMock` 或 `src/mock`，以此作为扫描正对照。

## 13. 常见问题

### UI 命令提示 APP 不在当前组件树

先执行 `.\calcx app start`。UI 命令不会为了隐藏状态问题而自动重启 APP。

### 公式或设置字段显示 `UNAVAILABLE`

确认设备安装的是 debug 主包，并等待 WebView 就绪。release 主包有意不暴露机器 JSON 描述，因此页面和控件仍可识别，但公式和设置详细状态不可用。

### 没有返回 `CALCX_TEST_RESULT`

检查主应用和测试 HAP 是否都已安装，以及 bundle、测试模块和 TestRunner 是否仍分别为 `com.startyi.calcx`、`entry_test` 和 `/ets/testrunner/OpenHarmonyTestRunner`。

### 安装测试 HAP 时提示版本降级

不要只判断 `hdc install` 的进程退出码；部分安装失败仍可能返回 `0`，必须同时检查输出中是否出现 `install bundle successfully` 或 `error`。如果提示 `install version downgrade`，重新构建当前源码的 `entry@ohosTest/debug`，确保它与设备上的主应用版本一致，再覆盖安装。

### 请求参数在测试端为空

当前 API 24 设备实测中，`aa test -s calcxRequest <payload>` 对应的参数键可能是 `-s calcxRequest`。测试端同时兼容带前缀和不带前缀的键。升级 SDK 后若问题复现，应只记录参数键和长度，不输出完整动态请求。

### 设置写入后正式界面没有变化

不要使用 `ohosTest` 模块自己的 Context 写正式设置；它与 `entry` 的偏好空间隔离。当前实现通过 `AbilityMonitor` 获取真实 `EntryAbility` Context，修改后重启并由 UI 树复核。

### 正式界面与直接计算结果不同

先比较 `inputLatex`、`normalizedLatex`、`mathJson` 和配置：最终 LaTeX 不同通常属于按键映射或编辑器状态差异；MathJSON 与配置相同但结果不同，应检查主包与测试 HAP 是否来自同一次构建，以及测试 HAP 是否误用了原生 mock。

## 14. 维护与验证清单

主要实现位置：

- Windows 启动器：`tools/calcx/launcher/`。
- 启动器构建脚本：`tools/calcx/scripts/Build-CalcXLauncher.ps1`。
- PowerShell 入口：`tools/calcx/runtime/calcx.ps1`。
- 公共 HDC、协议和 UI 树解析：`tools/calcx/runtime/CalcXCli.Common.psm1`。
- 具体命令实现：`tools/calcx/runtime/commands/`。
- 批量用例与场景：`tools/calcx/tests/`。
- 设备协议：`entry/src/ohosTest/ets/test/CalculationCli.test.ets`、`entry/src/ohosTest/ets/utils/CalculationTestBridge.ets`。
- 稳定 ID：`entry/src/main/ets/utils/SemanticIds.ets` 及各 UI 组件。
- debug 状态描述：`entry/src/main/ets/pages/Index.ets`、`entry/src/main/ets/components/FormulaScreen.ets`。

修改后按受影响范围验证：

1. 所有 PowerShell 文件执行 AST 解析，并通过构建后的 `calcx.exe -SelfTest`。
2. 修改计算协议、MathLive 转换、`EngineService` 或原生引擎时，优先运行引擎批量用例；这也是 CLI 最核心的回归入口。
3. 只有修改公式准备、语义 ID、页面导航或其他 UI 辅助能力时，才运行对应的 UI 场景，并抽样真实逐键输入与 `engine` 结果对照。
4. 需要设备验证时，构建并安装 `entry@default/debug` 与 `entry@ohosTest/debug`。
5. 修改发布边界时，重建 `entry@default/release` 并执行 HAP 隔离检查。

## 15. 已验证基线

### 程序员首版接口（2026-09-23）

`screen get` 新增 `programmer`，从 debug UI 的 `base.programmer` 读取，未挂载模块时为 null。结构为 `{ data, error, integerConfirmed, floatConfirmed }`；`data.settings` 含模式、进制、字长和符号解释，`data.bits` 为整数 HEX，另含表达式、标志、C-in、`floatBits` 和浮点输入。release 不暴露该 JSON。

稳定操作包括 `base.mode.integer/float`、`base.radix.2/8/10/16`、`base.float.width.16/32/64`、`base.signed`、`base.carry` 与 `base.key.*`。按键沿用科学键盘的可读后缀（如 `plus`、`equals`、`clear`），浮点指数键为 `base.key.exponent`。剪贴板及逐 bit 点击未加入 CLI 白名单。

```powershell
pwsh -NoProfile -File tools/test-programmer-cli.ps1
.\calcx scenario run tools/calcx/tests/scenarios/programmer-ui-smoke.json
```

第一个命令只验证主机侧解析、白名单与场景结构，已经通过；第二个需要应用处于首页及兼容设备，当前尚未执行。它覆盖进入模块、整数 `1 + 2`、切换进制、binary32 的 `1` 位模式，不代替长按或光感视觉验收。核心完整回归使用 `node tools/test-programmer.mjs`，不走 CAS 计算协议。

### 既有设备基线

2026-09-16 的真机基线：

- HDC `3.2.0f`，HarmonyOS API 24 测试运行时。
- `entry@default/debug`、`entry@ohosTest/debug` 和 `entry@default/release` 均构建成功。
- 单次 `1+1` 返回 `2`；引擎批量 4/4 通过。
- 真实语义点击 `1 -> + -> 1 -> =` 返回 `2`。
- 首页、侧栏、基础/科学模块、设置页、历史页和返回导航可识别并操作。
- `navigation-smoke.json` 5/5、`calculation-ui-smoke.json` 6/6 通过。
- 设置准备按 `radian -> degree -> radian` 验证，最终恢复为 `radian`。
- release 主 HAP 为 `debug=false`、`buildMode=release`，只包含正式 Ability，未命中测试协议标记。
- release UI 树不暴露公式/设置机器 JSON；恢复 debug 主包后完整状态重新可见。
- 未自动验证长按滑动、MathLive 光标、图像曲线、系统弹窗、浏览器或视觉表现，这些属于明确排除项。

2026-09-20 完成 `calcx.exe` 与 `tools/calcx/` 迁移后再次验证：启动器本地自检通过；真机单次 `1+1`、引擎批量 4/4、导航场景 5/5、公式计算场景 6/6 通过；真实语义点击 `1 → + → 1 → =` 的界面结果仍为 `2`。

[返回项目 README](../README.md)
