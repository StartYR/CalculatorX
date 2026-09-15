# CalculatorX Windows 命令行计算自动化计划

## 1. 目标

在 Windows 电脑上通过 `hdc` 调用 CalculatorX 的 HarmonyOS 仪器化测试模块，输入一条 LaTeX 字符串以及明确的计算配置，并同步取得计算生成的 LaTeX 字符串，用于自动化回归测试。

目标调用形式：

```powershell
.\test\Invoke-CalcXCalculation.ps1 `
  -Latex '\frac{1}{2}+\frac{1}{3}' `
  -Mode standard `
  -Angle degree `
  -Precision auto
```

目标标准输出：

```json
{"ok":true,"inputLatex":"\\frac{1}{2}+\\frac{1}{3}","resultLatex":"\\frac{5}{6}","mode":"standard","angle":"degree","precision":"auto"}
```

该功能只服务于开发和自动化测试，不作为面向用户的应用功能。

## 2. 强制边界

1. 命令行入口、参数读取、测试 Ability、测试页面、结果回传代码只放在 `entry/src/ohosTest` 和项目根 `test` 中。
2. 正式发布使用 `entry/default/release`；不得把 `entry_test`、测试 Ability 或 Windows 调用协议打入正式 HAP。
3. 不向正式应用增加导出的测试 Ability、端口监听、Want 命令参数入口或后台服务。
4. 自动化计算必须复用项目现有的：
   - `entry/src/main/resources/rawfile/calculator.html`
   - `EngineService.cleanRawLatex()`
   - `EngineService.generateInjectJs()`
   - `EngineService.parseWebJsonResult()`
   - `EngineService.calculateNative()`
   - `libentry.so` 原生计算引擎
5. `ohosTest` 不得使用 `src/mock` 中的 `libentry.so` 模板 mock；测试产物必须解析到真实原生库。
6. 不在测试模块中复制或重新实现 LaTeX 清洗、MathJSON 转换或数学计算逻辑。
7. 命令行计算不写历史记录、不改变用户首选项、不触发振动，也不依赖设备当前保存的设置。
8. 所有请求显式携带模式、角度制和精度，保证结果可复现。
9. Windows 与设备之间的动态请求使用 URL-safe Base64 编码的 UTF-8 JSON，避免 PowerShell、`hdc shell` 和 LaTeX 反斜杠之间发生转义差异。
10. 计划编写时没有测试手机；设备到位前，所有设备验证必须标记为“待设备验证”，不得把构建成功表述为设备运行通过。设备到位后补做并单独记录运行证据。
11. 用户已明确授权本任务进行构建验证。若连续三次构建失败，且失败原因是无法确定正确的构建命令而不是代码错误，则停止构建尝试并等待用户手动构建。

## 3. 已确认的项目现状

- 应用包名：`com.startyi.calcx`。
- 项目已有 `entry/default` 与 `entry/ohosTest` 两个 target。
- `entry/src/ohosTest/module.json5` 原先只声明模板测试模块 `entry_test`；本方案在该 target 内补充 TestRunner、计算测试 Ability 和命令行协议。
- 正常界面的计算路径为：按键 Action → `InputTranslator` → `calculator.html` 中的 MathLive → MathJSON → `EngineService.calculateNative()` → C++/Giac → LaTeX。
- 当前 DevEco Studio 中的工具位置：
  - HDC：`E:\Program Files\HUAWEI\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`
  - Hvigor：`E:\Program Files\HUAWEI\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- 已读取到的 HDC 版本：`3.2.0f`。
- 计划阶段 `hdc list targets` 返回 `[Empty]`；2026-09-15 后续已连接一台设备并完成阶段 8。

## 4. 测试范围与非目标

### 4.1 本功能覆盖

- 输入 LaTeX 的清洗。
- 使用项目内 MathLive/Compute Engine 生成 MathJSON。
- MathJSON 交给真实 N-API/C++ 引擎计算。
- 标准、矩阵、方程三种会产生 LaTeX 结果的计算模式可显式选择。
- 角度/弧度、精度和输出模式的显式选择。
- 正常结果和 `Error:*` 结果的结构化返回。
- Windows 端超时、设备缺失、测试模块缺失和协议错误的退出码。

### 4.2 本功能不单独证明

- 某个可见按钮是否映射出了正确的 LaTeX。
- 光标、占位符、撤销/重做是否正确。
- `=`、`EXE`、`Ans`、`S⇄D` 和结果后继续输入的状态流是否正确。
- 历史记录、截图渲染和 UI 展示是否正确。
- 函数图像模式返回的是采样点数组而不是计算结果 LaTeX，不属于本协议；如需自动化应单独设计图像采样协议。

这些界面集成风险由后续少量 UI 冒烟测试覆盖，不能用直接 LaTeX 测试替代。

## 5. 设计方案

### 5.1 Windows 端

新增 `test/Invoke-CalcXCalculation.ps1`：

1. 接收 `Latex`、`Mode`、`Angle`、`Precision`、可选设备 ID、超时和可选 `HdcPath`。
2. 优先解析 PATH 中的 `hdc`；找不到时回退到本机已确认的 DevEco Studio 路径；仍找不到则返回明确错误。
3. 校验 `hdc list targets`，零设备时返回专用退出码；多设备且未指定设备 ID 时拒绝猜测目标。
4. 将请求序列化为紧凑 JSON，并转换为 URL-safe Base64。
5. 调用 `hdc shell aa test`，只运行动态计算测试用例，并通过 `-s calcxRequest <payload>` 传参。
6. 从测试输出中查找唯一一行 `CALCX_TEST_RESULT:<payload>`。
7. 解码并验证响应中的协议版本和请求 ID。
8. 成功时只向标准输出写一行 JSON；诊断信息写到错误流。
9. 计算错误、测试失败、超时和基础设施失败使用不同的非零退出码。

### 5.2 HarmonyOS 测试端

仅在 `entry/src/ohosTest` 中新增：

- TestRunner：初始化 Hypium，保留 `aa test` 的动态参数。
- 动态计算测试用例：解析 `calcxRequest`，启动测试 Ability，等待结果并输出固定协议标记。
- 测试 Ability 与测试页面：提供独立的 Web 运行环境，不进入正常首页。
- 测试桥：持有测试 WebViewController，在页面完成加载后接受一次或多次计算请求。
- 测试页面路由资源与测试模块声明。

测试 Web 页面加载现有 `$rawfile('calculator.html')`。页面完成后，测试桥执行：

```text
请求中的 LaTeX
  → EngineService.cleanRawLatex()
  → EngineService.generateInjectJs()
  → 测试 WebViewController.runJavaScript()
  → EngineService.parseWebJsonResult()
  → EngineService.calculateNative(config)
  → resultLatex
```

### 5.3 协议

请求 JSON 最低字段：

```json
{
  "protocolVersion": 1,
  "requestId": "uuid",
  "latex": "\\sin\\left(30\\right)",
  "mode": "standard",
  "angle": "degree",
  "precision": "auto"
}
```

成功响应：

```json
{
  "protocolVersion": 1,
  "requestId": "uuid",
  "ok": true,
  "inputLatex": "\\sin\\left(30\\right)",
  "normalizedLatex": "\\sin\\left(30\\right)",
  "mathJson": "[...]",
  "resultLatex": "\\frac{1}{2}",
  "mode": "standard",
  "angle": "degree",
  "precision": "auto"
}
```

失败响应保留 `requestId`，并提供稳定的错误阶段：

```json
{
  "protocolVersion": 1,
  "requestId": "uuid",
  "ok": false,
  "stage": "request|web-ready|latex-parse|native-calculate|response",
  "error": "..."
}
```

结果标记中的完整响应再次做 URL-safe Base64，防止测试输出中的换行、反斜杠或 Unicode 被破坏。

## 6. 分阶段实施与验证门

### 阶段 0：基线与工具确认

步骤：

1. 保存当前 Git 分支和工作树状态，识别并保护用户已有修改。
2. 使用绝对路径运行 `hdc version` 和 `hdc list targets`。
3. 使用 Hvigor `tasks`/`taskTree` 确认本项目 `ohosTest` 的准确任务名，不凭猜测连续试错。

验证目标：

- 用户已有修改未被覆盖。
- HDC 可执行；没有设备时明确记录为待验证。
- 获得唯一、可解释的测试构建命令候选。

### 阶段 1：建立测试运行骨架

步骤：

1. 补充 `OpenHarmonyTestRunner.ets`。
2. 将模板测试替换或扩展为计算 CLI 测试套。
3. 更新 `List.test.ets` 注册测试套。
4. 只传入最小参数并输出固定协议标记，暂不调用计算引擎。

验证目标：

- 所有新增 ArkTS 文件被 `ohosTest` target 正确发现。
- 静态检查确认生产目录没有测试命令入口。
- 测试 target 可构建；有设备时 `aa test` 能看到固定标记。

无设备时：跳过 `aa test` 运行，继续执行编译/打包验证。

### 阶段 2：测试 Ability、页面与 WebView 就绪

步骤：

1. 在 `ohosTest` 模块声明非导出的计算测试 Ability。
2. 添加测试页面及页面路由。
3. 测试页面加载项目现有 `calculator.html`。
4. `onPageEnd` 后将测试桥标记为 ready。
5. 设置等待超时，禁止无限等待 WebView。

验证目标：

- 测试 Ability、页面和资源引用可构建。
- 测试模块之外没有新增 Ability 声明。
- 有设备时，测试 Ability 能启动并在期限内进入 ready。

无设备时：记录 ready 生命周期未验证。

### 阶段 3：接入真实计算链路

步骤：

1. 对输入执行现有 `cleanRawLatex()`。
2. 在测试 WebView 中执行现有 `generateInjectJs()`。
3. 使用现有 `parseWebJsonResult()` 得到 MathJSON。
4. 将显式配置映射到现有 `CalcConfig`。
5. 调用现有 `calculateNative()` 并返回 LaTeX。
6. 不调用 UI 结果展示、历史记录、截图或振动路径。

验证目标：

- 没有复制 `EngineService` 或原生计算算法。
- 配置映射与 `FormulaScreen.getCalcMode()`、精度逻辑一致。
- 正常结果和异常结果均能生成结构化响应。
- 构建通过。

有设备时的最小样例：

- `1+1` → `2`
- `\frac{1}{2}+\frac{1}{3}` → `\frac{5}{6}`
- degree 下 `\sin\left(30\right)` → `\frac{1}{2}` 或项目当前的等价规范输出
- 非法表达式 → 稳定错误响应

### 阶段 4：Windows PowerShell 调用器

步骤：

1. 实现参数校验、HDC 定位和设备选择。
2. 实现 UTF-8 JSON 与 URL-safe Base64 编解码。
3. 实现 `aa test` 命令调用、超时、结果标记提取和退出码。
4. 日志与最终 JSON 分流，方便人类使用和 CI 解析。
5. 提供 `-HdcPath` 和 `-DeviceId`，避免依赖单一机器环境。

验证目标：

- 在没有设备时快速失败且错误清晰。
- 含反斜杠、引号、空格、中文和 Unicode 的请求能本地编码后无损解码。
- 多行或含特殊字符的响应不会破坏 JSON。
- PowerShell 语法检查通过。

### 阶段 5：计算路径一致性检查

步骤：

1. 对照 `FormulaScreen.executeCalculation()` 检查清洗、AST 和原生调用顺序。
2. 对照 `getCalcMode()` 检查模式数字。
3. 对照答案输出模式检查精度值，包括自动、小数和特殊转换值。
4. 静态确认测试端引用同一 `calculator.html` 和同一 `EngineService`。
5. 增加协议字段 `normalizedLatex` 与 `mathJson`，便于发现界面与命令行之间的输入差异。

验证目标：

- 对相同最终 LaTeX 和相同配置，两条路径进入同一 MathJSON/C++ 计算链路。
- 明确记录直接 LaTeX 测试不覆盖按键翻译与编辑器状态。

### 阶段 6：构建验证

步骤：

1. 先通过 `hvigorw tasks` 找到准确任务名。
2. 构建 `ohosTest` target。
3. 构建正式 `default/release` target。
4. 区分代码错误、配置错误、环境错误和未知命令错误。
5. 代码错误应修复后重试；仅当连续三次失败都属于“不知道正确构建命令”时停止。

验证目标：

- `ohosTest` target 编译/打包通过。
- 正式 `default/release` 编译/打包通过。
- 不把配置检查、静态扫描或 HDC 探测误称为设备运行验证。

### 阶段 7：正式包排除检查

步骤：

1. 定位正式 release HAP。
2. 使用 `7z l` 检查包内容，不直接解压到工作树。
3. 搜索 `entry_test`、计算测试 Ability、`CALCX_TEST_RESULT`、`calcxRequest` 和 PowerShell 脚本名称。
4. 检查正式 `module.json` 中不存在测试 Ability 和测试模块声明。

验证目标：

- 正式 HAP 中没有任何新增测试入口或命令协议实现。
- 正式应用仍只暴露原有 Ability。

### 阶段 8：设备运行验证

步骤：

1. 安装 debug 应用和 ohosTest HAP。
2. 执行 Windows 单表达式命令。
3. 执行正常、错误、超时、特殊字符和多次连续调用用例。
4. 同一输入分别使用命令行和真实界面，比较 `inputLatex`、`mathJson` 和 `resultLatex`。
5. 执行少量真实按键 UI 冒烟用例。

验证目标：

- Windows 能同步获得设备真实计算的 LaTeX。
- 冷启动和已启动状态均可运行。
- 相同最终 LaTeX、相同配置时，命令行和界面结果一致。
- 按键翻译与编辑器状态的代表性流程没有回归。

运行结果（2026-09-15）：

- debug 主应用与 `entry-ohosTest-signed.hap` 均已覆盖安装成功。
- 当前系统将 `aa test -s calcxRequest <payload>` 映射为参数键 `-s calcxRequest`；测试端已兼容该键和无前缀键。修正后 Windows 调用器能按请求 ID 取得结果。
- `1+1` → `2`；分数加法 → `\frac{5}{6}`；角度制下 `\sin\left(30\right)` → `\frac{1}{2}`；精度 4 下 `1\div3` → `0.3333`。
- 矩阵输入返回对应 `bmatrix` LaTeX；`x+1=2` 在方程模式返回 `x = 1`。
- 不完整分数返回结构化 `native-calculate` 错误并以退出码 `20` 结束；引号、空格、中文和 Unicode 输入经过传输后仍能在响应中原样关联，解析错误不会破坏协议。
- 连续 5 次调用均成功；强制停止应用进程后的冷启动调用成功。
- 用真实界面依次点按 `AC → 1 → + → 1 → =`，界面显示 `1+1` 和结果 `2`，与命令行结果一致。
- 命令行显式使用 `degree` 和精度 6 得到 `0.500000` 后，重新打开正式界面仍显示原有 `RAD`，验证测试配置未写回用户角度设置。
- UI 冒烟验证了一个代表性按键链路；没有把直接 LaTeX 测试扩大解释为全部光标、撤销、`Ans`、`S⇄D` 或结果后输入状态均已覆盖。
- 未人为制造 WebView 或原生引擎长时间卡死，因此进程超时后的强制终止分支尚无设备运行证据；超时参数范围和脚本实现已做静态检查。

## 7. 构建失败停止规则

构建尝试单独编号并记录：

| 尝试 | 命令 | 结果 | 分类 | 下一步 |
| --- | --- | --- | --- | --- |
| 1 | `entry@ohosTest/debug assembleHap`（阶段 1） | 成功 | `SUCCESS` | 进入阶段 2 |
| 2 | `entry@ohosTest/debug assembleHap`（阶段 2） | 测试 Ability 缺少两个必填启动窗口字段 | `CODE` | 补齐字段 |
| 3 | `entry@ohosTest/debug assembleHap`（阶段 2 修复后） | 成功 | `SUCCESS` | 进入阶段 3 |
| 4 | `entry@ohosTest/debug assembleHap`（真实链路接入后） | 成功 | `SUCCESS` | 实现 Windows 调用器 |
| 5 | `entry@ohosTest/debug assembleHap`（最终双 target 验证） | 成功 | `SUCCESS` | 构建正式包 |
| 6 | `entry@default/release assembleHap` | 成功 | `SUCCESS` | 检查正式 HAP |
| 7 | `entry@ohosTest/debug assembleHap`（移除原生库 mock 后） | 成功 | `SUCCESS` | 检查真实库解析 |
| 8 | `entry@default/debug assembleHap --parallel`（设备安装准备） | BiSheng 编译进程被系统信号终止 | `ENVIRONMENT` | 移除并行构建后重试 |
| 9 | `entry@default/debug assembleHap`（非并行增量） | 成功 | `SUCCESS` | 安装主应用 |
| 10 | `entry@ohosTest/debug assembleHap`（设备验证准备） | 成功 | `SUCCESS` | 安装测试 HAP |
| 11 | `entry@ohosTest/debug assembleHap`（修正 `aa test` 参数键） | 成功 | `SUCCESS` | 运行设备用例矩阵 |
| 12 | `entry@ohosTest/debug assembleHap`（收窄模式并完成最终测试代码） | 成功 | `SUCCESS` | 执行三模式回归 |
| 13 | `entry@default/release assembleHap`（设备验证后恢复正式产物） | 成功 | `SUCCESS` | 复查正式 HAP 隔离 |

阶段 0 的两次 `hvigorw tasks` 失败分别由缺失和错误的 `DEVECO_SDK_HOME` 引起，分类为 `ENVIRONMENT`；设置为 DevEco Studio 的 `sdk` 根目录后成功。没有发生 `COMMAND_UNKNOWN` 构建失败。

分类定义：

- `CODE`：ArkTS/C++/资源或配置由本次修改引起的错误。修复后可继续，不计入“未知构建命令三次”限制。
- `ENVIRONMENT`：SDK、签名、Node、依赖或权限问题。尽量做一次有证据的环境诊断，不反复盲试。
- `COMMAND_UNKNOWN`：无法判断正确 Hvigor 任务名、target 参数或构建命令格式。连续出现三次后立即停止构建。
- `SUCCESS`：构建成功。

## 8. 预期修改范围

计划内文件：

```text
test/
├── CALCULATION_CLI_AUTOMATION_PLAN.md
└── Invoke-CalcXCalculation.ps1

entry/src/ohosTest/
├── module.json5
├── ets/
│   ├── pages/CalculationTestPage.ets
│   ├── test/CalculationCli.test.ets
│   ├── test/List.test.ets
│   ├── testability/CalculationTestAbility.ets
│   ├── testrunner/OpenHarmonyTestRunner.ets
│   └── utils/CalculationTestBridge.ets
└── resources/base/profile/test_pages.json

entry/src/mock/mock-config.json5
```

如构建系统证实测试 target 不能直接访问 `src/main/resources/rawfile`，才考虑在 `src/ohosTest/resources/rawfile` 放置测试专用资源副本；采取该回退前必须先确认错误证据，并确保副本不会进入正式包。

默认不修改：

- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/components/FormulaScreen.ets`
- 所有正常计算按键组件
- C++ 计算引擎

若实际编译表明必须修改 `src/main` 才能让测试 target 调用现有资源或引擎，应先重新评估是否仍能满足正式包隔离；不能满足时停止扩大范围。

`entry/src/mock/mock-config.json5` 只允许移除 DevEco 模板生成的 `libentry.so` mock 映射，因为该映射会让 `ohosTest` 绕过真实 C++ 引擎；不得改写原生库或在 mock 中仿制计算结果。

## 9. 完成标准

已完成并确认：

- 计划内测试代码和 Windows 脚本已实现。
- Windows 脚本的本地协议编解码、参数校验、无设备失败路径和设备调用路径通过。
- `ohosTest` 与正式 release 构建通过，或依据用户规则在三次未知命令失败后停止。
- 正式 HAP 排除测试代码的静态/包内容检查通过。
- 未修改正常页面、按键和计算引擎。
- `aa test` 动态参数传递、测试 WebView ready、真实 N-API 执行、Windows 结果回传和代表性真实按键对照均已通过设备验证。

## 10. 回退策略

- 删除 `entry/src/ohosTest` 中本次新增的测试文件，并恢复 `module.json5`、`List.test.ets` 的局部改动，即可移除设备端测试功能。
- 删除 `test/Invoke-CalcXCalculation.ps1` 即可移除 Windows 调用器。
- 不修改正式 UI 和 C++ 引擎，因此回退不应影响用户数据、历史记录或发布功能。
- 不对用户已有的其他修改执行重置、清理或覆盖。

## 11. 实施结果（2026-09-15）

已完成：

- 阶段 0 至阶段 8 已完成。
- `hdc version` 为 `3.2.0f`；设备验证时 `hdc list targets` 返回唯一已连接设备。
- Windows 调用器实现了 URL-safe Base64、设备选择、超时、结果关联和稳定退出码。
- 测试端复用相同的 `calculator.html`、`EngineService` 四步调用和 `libentry.so` 导入。
- 已移除 DevEco 模板的 `libentry.so` mock 映射；测试字节码包含真实 `libentry.so` 模块引用，不再包含 `Libentry.mock`、`NativeMock` 或 `src/mock` 引用。
- `entry@ohosTest/debug` 构建成功。
- 设备验证结束后已重新构建 `entry@default/release`，输出目录中的正式 HAP 已恢复为 release 产物。
- 正式 release HAP 的 `module.json` 仅声明原有 `EntryAbility`；正式字节码未发现 `entry_test`、`CalculationTestAbility`、`CALCX_TEST_RESULT`、`calcxRequest` 或调用器名称。
- PowerShell 语法、自检和参数失败路径已通过；非法模式、角度制或超时均使用退出码 `2`，无设备时使用退出码 `11`。
- 阶段 8 的安装、`aa test` 参数传递、WebView ready 时序、真实 N-API 执行、结果回传、连续/冷启动调用和代表性 UI 对照均已通过。
- 函数图像模式已从本协议排除，因为正式图像链路返回 `Float64Array` 采样点而不是 LaTeX；保留该选项会造成错误契约。
- 没有故意让设备计算挂死，所以 Windows 进程超时后的强制终止仍是唯一未做设备运行验证的错误分支。

## 12. 使用方法

前提：设备上已经安装同一次构建产生且签名匹配的 CalculatorX debug 应用 HAP 和 `entry-ohosTest-signed.hap`。两者使用 `hdc install -r <HAP 路径>` 覆盖安装已在设备上验证。

单设备调用：

```powershell
.\test\Invoke-CalcXCalculation.ps1 `
  -Latex '\frac{1}{2}+\frac{1}{3}' `
  -Mode standard `
  -Angle radian `
  -Precision auto
```

多设备时增加：

```powershell
-DeviceId '<hdc list targets 返回的设备 ID>'
```

可选模式：`standard`、`matrix`、`equation`。可选精度：`auto` 对应界面的自动模式，`decimal-auto` 对应小数模式下的自动精度，也可使用 `0` 至 `15`。协议本地自检：

```powershell
.\test\Invoke-CalcXCalculation.ps1 -SelfTest
```

退出码：

| 退出码 | 含义 |
| --- | --- |
| `0` | 计算成功 |
| `2` | Windows 参数无效 |
| `10` | HDC 不可用或无法列出设备 |
| `11` | 没有设备或指定设备未连接 |
| `12` | 多设备但未指定设备 |
| `13` | 测试模块、`aa test` 或结果标记异常 |
| `14` | 设备测试超时 |
| `20` | 设备已返回结构化计算错误 |
| `21` | 其他协议或调用器错误 |
