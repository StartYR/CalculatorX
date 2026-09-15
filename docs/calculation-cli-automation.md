# Windows 命令行计算自动化

本文档说明如何在 Windows 上通过 HDC 调用 CalculatorX 的 HarmonyOS 测试模块，输入 LaTeX，并同步取得计算结果 LaTeX。该入口用于自动化回归、计算引擎验证和问题复现，不是正式应用面向用户的命令行功能。

## 1. 能力与边界

调用链如下：

```text
Invoke-CalcXCalculation.ps1
  → hdc shell aa test
  → entry_test / CalculationTestAbility
  → calculator.html / MathLive Compute Engine
  → EngineService
  → libentry.so / C++ 计算引擎
  → CALCX_TEST_RESULT
  → Windows JSON 输出
```

测试端复用正式应用的以下实现：

- `entry/src/main/resources/rawfile/calculator.html`
- `EngineService.cleanRawLatex()`
- `EngineService.generateInjectJs()`
- `EngineService.parseWebJsonResult()`
- `EngineService.calculateNative()`
- `libentry.so` 原生计算引擎

因此，相同最终 LaTeX 和相同配置会进入与正式界面相同的 MathJSON 和 C++ 计算链路。命令行入口不经过可见按键、`InputTranslator` 和 MathLive 编辑状态，所以它不能单独证明按键映射、光标、撤销、`Ans`、`S⇄D` 或结果后继续输入行为正确；涉及这些功能时仍需补充 UI 测试。

命令行计算不会写入历史记录、修改用户首选项或触发振动。测试 Ability 仅存在于 `entry/ohosTest` target，正式 `entry/default/release` HAP 不包含该入口。

## 2. 前置条件

- Windows PowerShell 7。
- 已安装 DevEco Studio、HarmonyOS SDK 和 HDC。
- 设备已连接、已授权调试，并能出现在 `hdc list targets` 中。
- 设备上安装了同一次构建产生且签名匹配的 debug 主应用 HAP 和 `entry-ohosTest-signed.hap`。
- 当前协议支持 `standard`、`matrix` 和 `equation`。函数图像返回采样点数组，不属于 LaTeX 结果协议。

先检查工具和设备：

```powershell
hdc version
hdc list targets
```

如果 HDC 不在 `PATH` 中，可在调用时使用 `-HdcPath`。脚本也会检查 `DEVECO_SDK_HOME`，并回退到本项目开发时使用的 DevEco Studio 默认位置。

## 3. 构建与安装测试包

可直接在 DevEco Studio 中分别构建 `entry/default/debug` 和 `entry/ohosTest/debug`。需要从终端构建时，先按本机安装位置调整 `$devEcoHome`：

```powershell
$devEcoHome = 'E:\Program Files\HUAWEI\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $devEcoHome 'sdk'
$hvigor = Join-Path $devEcoHome 'tools\hvigor\bin\hvigorw.bat'

& $hvigor `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  assembleHap `
  --analyze=normal `
  --incremental

& $hvigor `
  --mode module `
  -p product=default `
  -p module=entry@ohosTest `
  -p buildMode=debug `
  assembleHap `
  --analyze=normal `
  --incremental
```

如果原生编译进程因系统信号或资源不足终止，不要立即判断为代码错误。确认错误不含编译诊断后，关闭并行构建并重试。构建命令不明确时先使用 Hvigor 的任务列表确认，不连续猜测任务名。

安装两个 HAP：

```powershell
$device = '<hdc list targets 返回的设备 ID>'

hdc -t $device install -r `
  .\entry\build\default\outputs\default\entry-default-signed.hap

hdc -t $device install -r `
  .\entry\build\default\outputs\ohosTest\entry-ohosTest-signed.hap
```

只更新测试代码时，通常只需重新构建并覆盖安装 `entry-ohosTest-signed.hap`。修改正式资源、`EngineService` 或原生引擎后，应重新构建并安装两者，避免主应用与测试模块版本不一致。

## 4. 调用方法

在项目根目录执行：

```powershell
.\test\Invoke-CalcXCalculation.ps1 `
  -Latex '\frac{1}{2}+\frac{1}{3}' `
  -Mode standard `
  -Angle radian `
  -Precision auto
```

单设备时可以省略 `-DeviceId`。存在多台设备时必须显式选择：

```powershell
.\test\Invoke-CalcXCalculation.ps1 `
  -Latex '1+1' `
  -DeviceId '<设备 ID>'
```

HDC 不在 `PATH` 时：

```powershell
.\test\Invoke-CalcXCalculation.ps1 `
  -Latex '1+1' `
  -HdcPath 'E:\Program Files\HUAWEI\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
```

只检查 Windows 端 JSON、UTF-8 和 URL-safe Base64 编解码：

```powershell
.\test\Invoke-CalcXCalculation.ps1 -SelfTest
```

## 5. 参数

| 参数 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `Latex` | 是 | 无 | 1 至 4096 个字符的 LaTeX；可作为第一个位置参数传入 |
| `Mode` | 否 | `standard` | `standard`、`matrix` 或 `equation` |
| `Angle` | 否 | `radian` | `radian` 或 `degree` |
| `Precision` | 否 | `auto` | `auto`、`decimal-auto` 或 `0` 至 `15` |
| `DeviceId` | 否 | 自动选择唯一设备 | 多设备时必须提供 |
| `TimeoutSeconds` | 否 | `30` | 允许范围为 5 至 300 秒 |
| `HdcPath` | 否 | 自动查找 | HDC 可执行文件路径 |
| `SelfTest` | 否 | 关闭 | 只执行本地协议自检，不连接设备 |

精度映射与正式界面一致：

- `auto` → 原生精度 `-1`，优先精确/符号结果。
- `decimal-auto` → 原生精度 `-2`，最多输出 16 位小数。
- `0` 至 `15` → 指定小数位数。

## 6. 输出与 CI 使用

成功时，标准输出只有一行紧凑 JSON：

```json
{"protocolVersion":1,"requestId":"...","ok":true,"inputLatex":"1+1","normalizedLatex":"1+1","mathJson":"[\"Add\",1,1]","resultLatex":"2","mode":"standard","angle":"radian","precision":"auto"}
```

主要字段：

| 字段 | 含义 |
| --- | --- |
| `protocolVersion` | Windows 与测试模块之间的协议版本 |
| `requestId` | 本次请求的关联 ID，用于排除其他日志中的旧结果 |
| `ok` | 计算是否成功 |
| `inputLatex` | 调用方传入的原始 LaTeX |
| `normalizedLatex` | `EngineService` 清洗后的 LaTeX |
| `mathJson` | MathLive 生成的 MathJSON，可用于定位输入差异 |
| `resultLatex` | 原生引擎返回的结果 LaTeX |
| `stage` / `error` | 失败阶段和错误信息，仅失败时出现 |

诊断信息写入标准错误。CI 应同时检查进程退出码和 JSON 中的 `ok`，不能只依赖 HDC 自身的退出码：

```powershell
$output = & .\test\Invoke-CalcXCalculation.ps1 `
  -Latex '1+1' `
  -Mode standard `
  -Angle radian `
  -Precision auto
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
  throw "CalculatorX device calculation failed with exit code $exitCode"
}

$result = $output | ConvertFrom-Json
if (-not $result.ok -or $result.resultLatex -ne '2') {
  throw 'Unexpected CalculatorX calculation result'
}
```

## 7. 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 计算成功 |
| `2` | Windows 参数无效 |
| `10` | HDC 不可用或无法列出设备 |
| `11` | 没有设备，或指定设备未连接 |
| `12` | 连接了多台设备但未指定设备 |
| `13` | 测试模块、`aa test` 或结果标记异常 |
| `14` | Windows 等待设备测试超时 |
| `20` | 设备返回结构化计算错误 |
| `21` | 其他协议或调用器错误 |

Hypium 用例失败时，某些系统上的 `hdc shell aa test` 仍可能返回进程退出码 `0`。调用器会按固定结果标记、协议版本、请求 ID 和 `ok` 字段判断最终状态。

## 8. 建议回归用例

| 场景 | 参数或输入 | 已验证结果 |
| --- | --- | --- |
| 基础运算 | `1+1` | `2` |
| 分数 | `\frac{1}{2}+\frac{1}{3}` | `\frac{5}{6}` |
| 角度制 | degree 下 `\sin\left(30\right)` | `\frac{1}{2}` |
| 指定精度 | precision 4 下 `1\div3` | `0.3333` |
| 矩阵 | `\begin{bmatrix}1&2\\3&4\end{bmatrix}` | 对应 `bmatrix` LaTeX |
| 方程 | equation 下 `x+1=2` | `x = 1` |
| 非法表达式 | 不完整的 `\frac` | 退出码 `20` 和结构化错误 |
| 字符传输 | 反斜杠、引号、空格、中文、Unicode | 请求与响应关联保持完整 |
| 生命周期 | 连续调用、强制停止应用后调用 | 均成功 |

计算引擎回归之外，至少保留一个代表性 UI 冒烟用例。例如真实点按 `AC → 1 → + → 1 → =`，确认界面表达式与结果分别为 `1+1` 和 `2`，再与命令行结果比较。

## 9. 正式包隔离检查

发布构建必须使用 `entry@default/release`，且只分发正式 HAP，不分发 `entry-ohosTest-signed.hap`。构建后检查：

```powershell
$devEcoHome = 'E:\Program Files\HUAWEI\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $devEcoHome 'sdk'
$hvigor = Join-Path $devEcoHome 'tools\hvigor\bin\hvigorw.bat'

& $hvigor `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=release `
  assembleHap `
  --analyze=normal `
  --incremental
```

正式 HAP 的 `module.json` 应满足：

- `app.debug` 为 `false`。
- `app.buildMode` 为 `release`。
- 模块名为 `entry`，主 Ability 为 `EntryAbility`。
- 不存在 `entry_test` 或 `CalculationTestAbility`。

还应检查正式字节码中不存在以下标记：

```text
entry_test
CalculationTestAbility
OpenHarmonyTestRunner
CALCX_TEST_RESULT
calcxRequest
Invoke-CalcXCalculation
```

可使用 7-Zip 将 `module.json` 和 `ets/modules.abc` 提取到新建临时目录，再用 `rg -a` 扫描。使用同样方法检查测试 HAP 应能命中测试标记，作为扫描有效性的正对照。

## 10. 常见问题

### 没有返回 `CALCX_TEST_RESULT`

依次检查：

1. 主应用和测试 HAP 是否都已安装。
2. bundle、测试模块和 TestRunner 是否仍分别为 `com.startyi.calcx`、`entry_test` 和 `/ets/testrunner/OpenHarmonyTestRunner`。
3. 测试 Ability 是否能加载 `pages/CalculationTestPage`。
4. `calculator.html` 是否能在测试 WebView 中完成加载。

### 请求被判断为非法 Base64

当前设备实测中，`aa test -s calcxRequest <payload>` 对应的参数键是 `-s calcxRequest`，而不是 `calcxRequest`。测试端同时兼容两种键。升级 SDK 或修改 TestRunner 后若问题复现，应先只打印参数键和各值长度确认映射，不要把完整请求写入日志。

### 测试构建成功，但没有调用真实 C++ 引擎

检查 `entry/src/mock/mock-config.json5`。如果 `libentry.so` 被映射到模板 mock，`ohosTest` 会绕过真实原生模块。当前文件应保持不含该映射；重建测试 HAP 后，字节码应包含 `libentry.so` 引用，并且不包含 `Libentry.mock`、`NativeMock` 或 `src/mock` 标记。

### HDC 返回 0，但测试实际失败

不要直接把 HDC 退出码当成 Hypium 结果。调用器会解析带请求 ID 的结构化响应，并把设备计算失败映射为退出码 `20`；自定义 CI 封装也应保留这层判断。

### 正式界面与命令行结果不同

先比较响应中的 `inputLatex`、`normalizedLatex` 和 `mathJson`：

- 最终 LaTeX 不同：检查按键映射、`InputTranslator` 和编辑器状态。
- LaTeX 相同但 MathJSON 不同：检查 `calculator.html`、MathLive 版本或资源是否一致。
- MathJSON 与配置均相同但结果不同：检查主应用与测试 HAP 是否来自同一次构建，以及是否误用了原生 mock。

## 11. 维护清单

修改协议或测试入口时同步检查：

- Windows 常量：`test/Invoke-CalcXCalculation.ps1`。
- 请求校验与结果标记：`entry/src/ohosTest/ets/test/CalculationCli.test.ets`。
- 模式、精度和计算链路：`entry/src/ohosTest/ets/utils/CalculationTestBridge.ets`。
- TestRunner：`entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ets`。
- 测试 Ability 与页面：`entry/src/ohosTest/ets/testability/`、`entry/src/ohosTest/ets/pages/`。
- 测试模块声明：`entry/src/ohosTest/module.json5`。
- 原生 mock 排除：`entry/src/mock/mock-config.json5`。

协议字段发生不兼容变化时提升 `protocolVersion`，并同时修改 Windows 与设备端。增加模式时，必须确认该模式返回的是 LaTeX 字符串；图像采样等其他返回类型应使用独立协议。

每次修改后至少执行：

1. PowerShell 语法检查和 `-SelfTest`。
2. 构建并安装 `entry@ohosTest/debug`。
3. 运行基础、错误、特殊字符和连续调用用例。
4. 修改正式计算代码时补充一个真实 UI 对照。
5. 发布前重新构建 `entry@default/release` 并检查正式包隔离。

## 12. 已验证基线

2026-09-15 的设备验证基线：

- HDC `3.2.0f`。
- HarmonyOS API 24 测试运行时。
- standard、matrix、equation 三种模式通过。
- 角度制、指定精度、非法输入、特殊字符、连续调用和冷启动通过。
- 真实 UI `1+1` 与命令行结果一致。
- 命令行显式配置未写回正式界面设置。
- 测试 HAP 使用真实 `libentry.so`，正式 release HAP 不含测试入口。
- 未故意制造 WebView 或原生引擎长时间卡死；强制超时终止分支尚无设备运行证据。

[返回项目 README](../README.md)
