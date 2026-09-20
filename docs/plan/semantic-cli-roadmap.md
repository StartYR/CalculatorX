# CalculatorX 语义 CLI 实施路线图

- 状态：已完成（2026-09-16）
- 类型：开发与自动化测试基础设施
- 编写日期：2026-09-16
- 适用环境：Windows PowerShell、HDC、HarmonyOS 测试包
- 目标使用者：项目维护者、自动化测试和 AI Agent
- 核心优先级：批量提交 LaTeX 并验证计算结果；UI 自动化仅作为必要辅助

## 1. 计划定位

本计划统一替代原“Windows CLI 调用优化计划”。原计划中的仓库相对路径短命令、单次计算兼容、批量计算、状态隔离和正式包隔离全部保留，并在此基础上增加可行性高、实现难度中等或较低的语义 UI 自动化能力。

最终目标不是构建一个可以操纵所有系统界面的万能机器人，而是为 CalculatorX 自有核心功能提供稳定、结构化、无需截图识别的测试控制面，使 AI Agent 能够：

- 获取当前页面和计算模块；
- 获取输入区、结果区、设置和可用控件的语义状态；
- 通过稳定控件 ID 执行普通点击、页面返回和模块切换；
- 直接输入 LaTeX、执行计算并取得结构化结果；
- 读取和调整 CalculatorX 自有设置；
- 以批量或场景文件方式执行完整测试流程；
- 明确区分真实 UI 操作、测试环境准备和直接引擎调用。

其中，批量输入 LaTeX、取得结构化计算结果并判断计算逻辑是否正确，是 CLI 的首要用途。其他能力只有在能够明显减少高频重复操作、直接支撑核心计算回归或稳定复现重要问题时才值得扩展。便于人工测试、业务重要性较低、难以形成稳定断言或实现成本明显偏高的界面操作，不以 CLI 覆盖为目标；不能把命令数量或 UI 覆盖率当作完整度指标。

## 2. 实施范围

### 2.1 必须完成

#### 命令入口

- `tools/calcx/` 提供可构建、可安装的 `calcx.exe` 入口与 PowerShell 运行时。
- 使用 `$PSScriptRoot` 定位仓库文件，不写入机器专属项目绝对路径。
- 保留单次 LaTeX 作为首个位置参数的既有调用兼容性。
- 标准输出保持机器可解析，诊断信息写入标准错误。
- 所有命令具有稳定退出码、协议版本和请求 ID。

#### 应用与页面状态

- 启动 CalculatorX 测试环境。
- 判断当前前台应用是否为 CalculatorX。
- 获取当前 Ability、页面路径和主要弹层状态。
- 判断当前计算模块，例如 scientific、basic、matrix、equation、statistics、unit、base、exchange 或 graphing。
- 获取当前页面可操作控件列表及其稳定 ID、类型、文本、可见性、启用状态和选中状态。

#### 计算器状态

- 获取输入区 LaTeX。
- 获取结果区 LaTeX。
- 获取当前编辑状态，例如编辑中或结果就绪。
- 获取角度制、精度、输出格式和 Shift 等影响计算的核心状态。
- 直接插入完整 LaTeX，避免依赖复杂的光标和组合手势完成测试准备。
- 继续支持 standard、matrix 和 equation 的直接计算协议。
- 支持一批表达式在一次测试会话内顺序计算。

#### 普通 UI 操作

- 本节能力用于必要的计算输入、关键导航和问题复现，不要求覆盖所有可交互控件。
- 按稳定语义 ID 点击普通按键。
- 点击侧边栏、设置入口、历史入口和普通菜单项。
- 切换计算模块。
- 执行返回操作。
- 仅在直接支撑核心回归且自动化收益明确时操作选择器、开关和按钮。
- 等待页面、控件或计算状态达到指定条件。

#### 设置

- 读取受支持的设置项和值。
- 通过测试准备接口直接设置白名单内的配置，用于快速构造测试环境。
- 对两种修改方式作出明确标记，禁止把直接写入配置当作 UI 验证通过。
- 设置页面自身的滑块、复杂选择器和视觉反馈默认由人工验证；只有相关交互成为核心计算回归的必要环节时，才增加对应 UI 命令。

#### 场景执行

- 从 JSON 场景文件读取一组动作和断言。
- 一次启动后顺序执行场景，减少 APP 反复启动和退出。
- 每一步返回动作、前后状态、耗时、结果和失败原因。
- 支持失败即停止和继续收集后续失败两种策略。

### 2.2 明确不做

以下能力不纳入本计划，也不作为 CLI 完整度的验收条件：

- 长按后滑动选择气泡按键。
- 精细控制 MathLive 光标、选区、拖拽和复杂编辑手势。
- 完整操纵设置页滑块、复杂选择器或其他低频控件。
- 通过 CLI 判断函数图像是否绘制正确。
- 自动处理系统权限弹窗、系统设置页或外部浏览器。
- 验证控件遮挡、颜色、字体、阴影、动画和像素级布局。
- 用组件树替代所有人工视觉验收。
- 对任意 ArkUI 节点执行未列入白名单的反射式操作。
- 在设备上开放网络端口或长期运行无认证的控制服务。

这些场景分别使用以下替代方式：

- 复杂公式和光标输入：直接插入完整 LaTeX。
- 图像正确性：校验计算数据并由人工抽样观察画布。
- 系统界面和浏览器：人工验证。
- 视觉质量：人工检查或独立的视觉测试流程。

## 3. 核心原则

### 3.1 三条测试路径必须分开

CLI 对外暴露三类命令，输出中必须标明 `executionPath`：

| 路径 | 用途 | 是否经过真实 UI |
| --- | --- | --- |
| `engine` | 快速验证数学计算链路 | 否 |
| `setup` | 快速准备设置、模块或输入状态 | 否或部分 |
| `ui` | 验证用户实际可见和可点击的交互 | 是 |

例如：

```powershell
calcx engine calculate '1+1'
calcx setup settings set angle degree
calcx ui click settings.angle.degree
```

`setup` 成功只能证明测试环境被正确准备，不能证明对应设置控件能够显示和响应。需要验证 UI 时必须使用 `ui` 路径。

### 3.2 语义状态与实际渲染交叉验证

单纯读取应用内部变量可能出现“状态已改变，但 UI 没有正确渲染”的假通过。因此状态快照应标明来源，并尽量同时包含：

- 系统 UI 测试框架观察到的组件树信息；
- CalculatorX 内部提供的计算、设置和 WebView 语义状态。

关键断言应优先使用双重证据。例如切换到科学计算后，同时确认：

- 应用内部 `currentModule` 为 `scientific`；
- 科学计算页面的稳定根节点和代表性按键实际存在。

### 3.3 稳定 ID 不依赖界面文字

控件定位不使用屏幕坐标，也不把中文或英文显示文字作为唯一定位依据。所有纳入自动化范围的核心控件应使用稳定、唯一、与本地化无关的语义 ID。

命名示例：

```text
app.page.index
app.page.settings
nav.sidebar.open
nav.settings
module.scientific
calc.input
calc.result
calc.key.1
calc.key.plus
calc.key.equals
settings.angle.degree
settings.angle.radian
```

显示文本可以作为诊断字段，但不能代替稳定 ID。

### 3.4 不复制业务逻辑

CLI 不维护第二套计算、设置或页面规则。所有实际行为继续调用正式实现：

- 计算继续经过 MathLive、`EngineService` 和 `libentry.so`。
- UI 点击继续触发现有 `.onClick()`、`.onTouch()`、事件总线和路由逻辑。
- 设置继续使用现有 `PreferenceManager` 和 AppStorage 机制。
- 页面和模块状态继续以正式组件为权威来源。

### 3.5 等待条件替代固定休眠

除框架稳定所需的最小轮询间隔外，不使用固定的长时间 `sleep` 判断成功。动作之后使用明确条件等待，例如：

- 页面根节点出现；
- 当前模块变更；
- 输入 LaTeX 发生变化；
- 结果状态变为 ready；
- 设置值持久化完成；
- 目标控件变为可见且可点击。

所有等待都有超时、阶段名称和结构化错误。

## 4. 建议命令模型

最终命令名称可在原型验证后微调，但语义边界应保持稳定。

### 4.1 应用生命周期

```powershell
calcx app status
calcx app start
calcx app stop
```

`app start` 应启动真实主界面，而不是仅启动独立计算测试页。重复执行时应识别 APP 已运行，避免不必要的重新启动。

### 4.2 屏幕与状态

```powershell
calcx screen get
calcx screen controls
calcx screen find calc.key.equals
calcx settings get
calcx formula get
```

建议的 `screen get` 输出：

```json
{
  "protocolVersion": 1,
  "ok": true,
  "screen": {
    "ability": "EntryAbility",
    "route": "index",
    "module": "scientific",
    "overlays": []
  },
  "formula": {
    "inputLatex": "1+1",
    "resultLatex": "2",
    "editorState": "RESULT_READY"
  },
  "settings": {
    "angle": "radian",
    "precision": "auto"
  },
  "controls": []
}
```

原始组件树可作为诊断输出，但 AI Agent 的主要接口应是经过规范化的语义快照，而不是依赖平台内部节点格式。

### 4.3 普通操作

```powershell
calcx ui click nav.sidebar.open
calcx ui click module.scientific
calcx ui click calc.key.1
calcx ui click calc.key.plus
calcx ui click calc.key.equals
calcx ui back
```

点击命令必须：

1. 按稳定 ID 查找组件；
2. 确认组件存在、可见、启用且可点击；
3. 通过 UI 测试框架发送点击；
4. 等待界面稳定；
5. 返回点击前后关键状态。

### 4.4 公式与计算

```powershell
calcx formula set '\frac{1}{2}+\frac{1}{3}'
calcx formula clear
calcx engine calculate '1+1'
calcx engine batch .\tools\calcx\tests\cases\engine-smoke.json
```

`formula set` 用于直接准备真实界面的公式输入区；`engine calculate` 用于绕过 UI 的高频计算回归。两者必须使用不同命令和 `executionPath`。

### 4.5 设置

```powershell
calcx settings get angle
calcx setup settings set angle degree
calcx ui click settings.angle.degree
```

直接设置接口只允许预定义键和值，禁止通过 CLI 写入任意 Preferences 键。

### 4.6 等待与断言

```powershell
calcx wait screen.module scientific -TimeoutSeconds 10
calcx assert formula.resultLatex '2'
calcx assert control.exists calc.key.equals
```

断言失败必须返回非零退出码，并在 JSON 中报告期望值、实际值和数据来源。

### 4.7 场景文件

```powershell
calcx scenario run .\tools\calcx\tests\scenarios\scientific-basic.json
```

场景示例：

```json
{
  "name": "scientific-basic",
  "steps": [
    { "command": "app.start" },
    { "command": "ui.click", "target": "nav.sidebar.open" },
    { "command": "ui.click", "target": "module.scientific" },
    { "command": "formula.set", "latex": "1+1" },
    { "command": "ui.click", "target": "calc.key.equals" },
    { "command": "assert", "path": "formula.resultLatex", "equals": "2" }
  ]
}
```

场景执行应尽量只启动一次 APP 和一次测试会话。若平台限制无法让多次独立命令共享测试会话，场景模式作为批量自动化的权威入口，单命令模式用于调试。

## 5. 协议与数据模型

### 5.1 通用请求

```json
{
  "protocolVersion": 1,
  "requestId": "uuid",
  "command": "ui.click",
  "arguments": {
    "target": "calc.key.equals"
  },
  "timeoutMs": 10000
}
```

### 5.2 通用响应

```json
{
  "protocolVersion": 1,
  "requestId": "uuid",
  "ok": true,
  "executionPath": "ui",
  "stage": "completed",
  "before": {},
  "after": {},
  "durationMs": 120
}
```

### 5.3 错误分类

至少区分：

- Windows 参数错误；
- HDC 或设备不可用；
- APP 未安装或未运行；
- 测试包不可用；
- 页面或组件不存在；
- 组件不可见、禁用或不可点击；
- 页面等待超时；
- WebView 状态读取失败；
- 设置键或值不在白名单；
- 计算失败；
- 协议版本不匹配；
- 场景步骤失败。

错误响应不得只返回笼统的 `failed`，必须包含阶段、目标和可执行的诊断信息。

## 6. 计划修改边界

实际实施预计涉及：

### Windows 端

- 新增 `tools/calcx/runtime/calcx.ps1` 统一分派入口。
- 复用并扩展 `tools/calcx/runtime/commands/Invoke-CalcXCalculation.ps1`。
- 根据职责决定是否拆分公共协议和 UI 调用器，避免单个脚本无限膨胀。
- 新增场景格式和本地协议测试。

### 测试模块

- 在 `entry/src/ohosTest` 中增加语义 UI 命令处理和场景执行用例。
- 使用 HarmonyOS UI 测试驱动读取组件和执行普通点击。
- 保留当前计算测试入口，并共享请求校验、Base64 编解码和结果标记规范。

### 正式 UI 源码

- 为纳入测试范围的页面根节点和普通控件补充稳定 ID。
- 为图标型控件补充合理的无障碍文本或描述。
- 为 `Index`、`FormulaScreen` 和设置状态提供最小语义快照。
- 不加入外部可调用的网络服务、导出 Ability 或任意命令执行入口。

稳定 ID 和无障碍语义属于界面元数据；具有控制能力的测试驱动和协议必须继续隔离在测试包中。若实现时发现某项内部状态桥接必然进入 release，需要先设计可验证的构建期开关，并重新检查正式包隔离。

## 7. 分阶段实施与验证目标

### 阶段 0：设备能力探测

步骤：

1. 在当前设备运行官方 UI 布局导出命令。
2. 检查是否能读取 CalculatorX 的 bundle、Ability、页面路径和原生组件树。
3. 确认 Web 公式区在组件树中的可见范围和属性边界。
4. 编写最小 UiTest 原型，查找一个普通原生控件并执行一次点击。
5. 验证 UiTest 点击是否能触发 `KeyGestureWrapper` 的现有触摸处理。
6. 观察测试会话对真实 `EntryAbility` 生命周期的影响。

验证目标：

- 不依赖截图即可识别当前前台页面。
- 至少一个稳定标识控件能够被查找并点击。
- 明确单命令和场景模式能否复用已启动 APP。
- 若底层能力与预期不同，在扩展源码前调整设计，不继续堆叠接口。

### 阶段 1：便携入口和协议核心

步骤：

1. 新增使用启动器自身位置定位 `runtime/calcx.ps1` 的 `calcx.exe`。
2. 建立统一命令解析、请求 ID、协议版本、超时和退出码。
3. 保留旧计算脚本和位置参数兼容性。
4. 统一 HDC、设备选择、Base64 和 JSON 处理。
5. 增加本地 `-SelfTest`，不连接设备即可验证协议往返。

验证目标：

- 仓库克隆到任意目录后均可运行。
- 仓库脚本没有机器专属项目绝对路径。
- 新旧计算入口产生相同结果和退出码。
- 非法命令不会发送到设备。

### 阶段 2：批量计算

步骤：

1. 保留协议版本 1 的单请求行为。
2. 定义批量请求信封和每项独立请求 ID。
3. 在一次测试会话内顺序调用现有计算桥接。
4. 每项结果独立输出，避免超长单行结果。
5. 设置批次数量、单条长度和总负载上限。
6. 一条计算失败时继续处理其余项目，并在最终汇总中标记失败。

验证目标：

- 一批表达式只加载一次计算测试 WebView。
- 批量与单次结果逐项一致。
- standard、matrix、equation、角度制和精度可以混合。
- 特殊字符和错误结果不会破坏其他响应。
- 不写入正式历史和用户设置。

### 阶段 3：稳定语义 ID

步骤：

1. 制定并冻结第一版 ID 命名表。
2. 为主页、设置页、侧边栏和主要弹层增加根节点 ID。
3. 为基础与科学计算的普通按键增加 ID。
4. 为设置入口、模块入口、返回按钮和普通选择控件增加 ID。
5. 为图标型按钮增加无障碍文本。
6. 检查 ID 唯一性和本地化稳定性。

验证目标：

- 同一页面不存在重复 ID。
- 切换语言、主题和屏幕尺寸时 ID 不变。
- UI 测试可以只使用语义 ID 定位核心控件。
- 语义元数据不改变现有布局和点击行为。

### 阶段 4：只读屏幕快照

步骤：

1. 实现 `app status`、`screen get`、`screen controls`、`formula get` 和 `settings get`。
2. 规范化平台组件树，不直接把平台内部结构作为稳定协议。
3. 从 `Index` 获取当前模块。
4. 从 `FormulaScreen` 和 calculator WebView 获取输入、结果和编辑状态。
5. 从 AppStorage 与 `PreferenceManager` 获取受支持设置。
6. 为每个字段标记 `ui-tree`、`app-state` 或 `web-state` 来源。

验证目标：

- 能区分主页、设置页、历史页和主要弹层。
- 能准确返回当前模块、输入、结果和核心设置。
- 页面切换后不会返回前一页面的过期快照。
- WebView 未就绪时返回明确状态，不伪造空字符串为有效值。

### 阶段 5：普通 UI 控制

步骤：

1. 实现 `ui click` 和 `ui back`。
2. 点击前验证组件存在、可见、启用和可点击。
3. 点击后等待预期状态变化或界面稳定。
4. 覆盖侧边栏、模块切换、普通计算按键和设置页普通控件。
5. 明确拒绝长按气泡、拖拽和坐标直通命令。

验证目标：

- `1 + 1 =` 可完全通过普通语义点击完成并得到 `2`。
- 打开侧边栏、切换模块、进入设置和返回可重复执行。
- 目标不存在时不会误点其他控件。
- 不使用截图识别或硬编码屏幕坐标。

### 阶段 6：公式与设置准备接口

步骤：

1. 实现 `formula set` 和 `formula clear`。
2. 实现白名单设置的 `setup settings set`。
3. 更新正式 UI 内存状态和持久化状态，避免界面与存储不一致。
4. 所有准备命令返回 `executionPath: setup`。
5. 为相同设置提供至少一个真实 UI 操作对照用例。

验证目标：

- 复杂 LaTeX 可直接进入真实输入区并被 `formula get` 原样读回。
- 设置修改后 UI、AppStorage 和 Preferences 一致。
- 未列入白名单的键和值被拒绝。
- 准备命令不会被报告为 UI 点击通过。

### 阶段 7：场景执行器

步骤：

1. 定义场景 JSON Schema 和版本。
2. 支持动作、等待、断言和变量引用。
3. 支持失败停止与继续收集。
4. 输出逐步 NDJSON 和最终汇总。
5. 场景执行时复用一次 APP 启动和尽可能少的测试会话。
6. 提供科学计算、设置切换、模块导航和错误恢复示例。

验证目标：

- AI Agent 只需生成场景 JSON，无需处理 HDC 细节。
- 每个失败都能定位到具体步骤、命令和状态差异。
- 场景重复执行结果稳定。
- 执行完成后不会遗留无法关闭的测试窗口或会话。

### 阶段 8：隔离、回归和文档

步骤：

1. 对单次计算、批量计算、屏幕读取和 UI 点击执行回归。
2. 检查正式 release HAP 不包含测试 Ability、命令处理器和结果标记。
3. 检查测试 HAP 正确包含 UI 测试和真实 `libentry.so` 引用。
4. 更新正式操作文档、退出码、故障排查和维护清单。
5. 将本计划标记为完成，并记录未实施的排除项。

验证目标：

- 正式界面正常操作不受影响。
- 未安装测试 HAP 时不存在 CLI 控制入口。
- release HAP 不包含测试协议和驱动实现。
- 语义 ID 和无障碍属性不会改变产品行为。
- 文档中的每条示例命令均与实际参数一致。

## 8. 验收矩阵

| 场景 | 引擎路径 | 准备路径 | UI 路径 | 必须验证 |
| --- | --- | --- | --- | --- |
| `1+1` 得到 `2` | 是 | 可选 | 是 | 是 |
| 分数 LaTeX | 是 | 是 | 只点等号 | 是 |
| degree 三角函数 | 是 | 是 | 按需人工抽样 | 是 |
| 指定精度 | 是 | 是 | 按需人工抽样 | 是 |
| matrix | 是 | 是 | 模块切换 | 是 |
| equation | 是 | 是 | 模块切换 | 是 |
| 非法表达式 | 是 | 是 | 不要求 | 是 |
| 当前页面识别 | 不适用 | 不适用 | 只读快照 | 是 |
| 当前按键枚举 | 不适用 | 不适用 | 只读快照 | 是 |
| 侧边栏与设置导航 | 不适用 | 不适用 | 是 | 是 |
| 设置读取与修改 | 不适用 | 是 | 默认人工验证 | 仅作为计算前置状态时 |
| 混合成功与失败场景 | 是 | 是 | 是 | 是 |
| APP 只启动一次的场景 | 不适用 | 不适用 | 是 | 是 |

## 9. 安全与发布边界

- CLI 只用于开发和测试设备。
- 不允许通过 CLI 执行任意 ArkTS、JavaScript、Shell 或 Preferences 写入。
- 所有命令和参数使用显式白名单。
- 测试 Ability 保持非导出。
- 不开启网络监听端口。
- 不把设备 ID、用户目录、SDK 路径或签名信息写入仓库。
- 输出不得包含用户隐私数据、历史记录全文或认证信息，除非用例明确使用人工构造的测试数据。
- 清空历史、恢复设置等破坏性测试操作必须使用独立测试数据，并提供明确命令名和确认开关。
- 发布时只分发正式 HAP，不分发 `entry-ohosTest-signed.hap`。

## 10. 验证边界

本次实施由用户明确授权执行构建和真机测试，因此在静态检查之外完成了 debug、ohosTest 和 release 构建，以及设备端回归。后续维护默认根据项目规则和当次授权决定是否构建。每一阶段至少完成：

1. PowerShell AST 语法检查。
2. 协议和 JSON Schema 本地自检。
3. 参数、Base64、特殊字符和退出码测试。
4. 稳定 ID 重复扫描。
5. 机器专属绝对路径扫描。
6. `git diff --check` 和文档链接检查。

设备验证必须区分：

- 构建成功；
- 测试 HAP 安装成功；
- CLI 命令实际执行成功；
- 真实 UI 行为与语义状态一致；
- 正式 release 包隔离验证成功。

## 11. 实施结果

各阶段均已按计划落地并取得对应验证证据：

| 阶段 | 实施结果 | 验证结果 |
| --- | --- | --- |
| 0 设备能力探测 | 使用 `uitest dumpLayout` 读取组件树，按实时控件边界执行点击 | 页面、模块和普通控件可在不截图的情况下识别；真实点击有效 |
| 1 便携入口和协议 | 新增 `calcx.exe` 与 `tools/calcx/runtime/`，公共逻辑按启动器位置定位 | 本地自检通过，仓库文件未写入项目绝对路径 |
| 2 批量计算 | 新增批量请求和 `engine-smoke.json` | 同一测试会话 4/4 通过 |
| 3 稳定语义 ID | 为页面、公式、导航、模块、设置和普通按键补充稳定 ID | UI 树可唯一查找并点击目标 |
| 4 只读屏幕快照 | 实现 APP、屏幕、控件、公式和设置读取 | debug 真机返回页面、模块、公式和设置状态 |
| 5 普通 UI 控制 | 实现白名单语义点击和返回 | `1 -> + -> 1 -> =` 得到 `2`；导航场景 5/5 通过 |
| 6 公式与设置准备 | 实现一次性公式注入及白名单设置写入 | 公式场景 6/6 通过；角度制往返并恢复为 `radian` |
| 7 场景执行器 | 支持动作、等待、断言、变量和失败策略 | 两个仓库内场景均通过 |
| 8 隔离、回归和文档 | 完成 debug、ohosTest、release 构建与 HAP 审计 | release 无测试 Ability/协议标记，机器 JSON 描述为空；debug 恢复后状态可见 |

实现中确认了一项平台边界：`ohosTest` 模块 Context 与正式 `entry` 的 Preferences 空间隔离。设置准备必须先停止 APP、注册 `AbilityMonitor`、启动并取得新创建的正式 `EntryAbility`，再使用其 Context 写入和落盘，最后重启并从 UI 树验证。

公式准备采用一次性偏好记录，只有 debug 主包会写入和消费，正式 UI 消费后立即删除。公式和设置机器状态也只在 debug 下放入 `accessibilityDescription`；release 保留正常界面及稳定 ID，但不向屏幕阅读器暴露机器 JSON。

## 12. 完成标准

满足以下条件后，本计划视为完成：

- 任意合作者可从任意克隆路径构建并安装 `calcx`，安装后可在任意工作目录运行。
- 现有单次计算 CLI 保持兼容，批量计算可复用一次测试会话。
- CLI 能稳定识别 CalculatorX 当前页面、模块、输入、结果、设置和核心控件。
- 普通核心控件可按语义 ID 点击，不依赖截图和硬编码坐标。
- AI Agent 可通过批量命令完成主要计算回归，并通过场景 JSON 覆盖必要的公式准备和关键交互。
- UI、setup 和 engine 三条路径不会相互冒充。
- 所有排除项在文档中保持明确，不因“完全体 CLI”目标被重新引入。
- 正式 release 包不包含测试控制入口。
- 正式操作文档、协议、退出码和排障信息与实现一致。

## 13. 实施顺序结论

严格按以下顺序推进：

1. 设备能力探测。
2. 相对路径短命令和统一协议。
3. 批量计算。
4. 稳定语义 ID。
5. 只读屏幕快照。
6. 普通 UI 点击。
7. 公式和设置准备接口。
8. 场景执行器。
9. release 隔离检查和正式文档更新。

任一阶段未达到验证目标时，先修正该阶段，不提前扩展后续能力。复杂手势、设置页滑块与复杂选择器、MathLive 光标、图像视觉、系统界面和视觉回归始终保持在范围之外，除非它们以后成为高频且直接影响核心计算正确性的自动化需求。

[返回 CLI 正式操作文档](../calculation-cli-automation.md)
