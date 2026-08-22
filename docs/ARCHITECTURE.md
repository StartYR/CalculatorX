# 🏛️ CalculatorX 系统架构指南

本文档面向 CalculatorX 的新贡献者（人类或 AI），旨在提供一份**不看源代码即可理解项目全貌**的架构地图。阅读本文后，你应该能够根据 bug 描述或功能需求，精确定位到需要修改的具体文件。

---

## 目录

1. [项目总览](#1-项目总览)
2. [核心架构：壳-插件 SPA 模型](#2-核心架构壳-插件-spa-模型)
3. [通信与状态管理](#3-通信与状态管理)
4. [计算生命周期：一次完整计算的数据流](#4-计算生命周期一次完整计算的数据流)
5. [模块详解](#5-模块详解)
6. [C++ 引擎层](#6-c-引擎层)
7. [Web 渲染层](#7-web-渲染层)
8. [数据持久化层](#8-数据持久化层)
9. [设置与配置系统](#9-设置与配置系统)
10. [核心目录结构](#10-核心目录结构)

---

## 1. 项目总览

CalculatorX 是一款基于**鸿蒙 Next (HarmonyOS)** 的科学计算器应用，采用 ArkTS + C++ (N-API) 混合架构。

### 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | ArkUI (ArkTS) — 鸿蒙原生声明式 UI |
| Web 渲染引擎 | MathLive（LaTeX 数学公式排版）+ Compute Engine（MathJSON AST） |
| 符号计算引擎 | SymEngine（C++ 原生代数系统）+ Giac（CAS 符号引擎） |
| 大数运算 | Boost.Multiprecision + 自研 FastMath |
| 本地存储 | HarmonyOS Preferences（配置）+ RDB 关系型数据库（历史记录） |
| 网络数据 | HarmonyOS HTTP + Network Connection（汇率拉取与网络状态检测） |
| 跨层通信 | N-API（ArkTS ↔ C++）、Webview JS Bridge（ArkTS ↔ Web） |

### 已实现功能

- **基础计算**：四则运算、百分数、Ans 调用
- **科学计算**：三角函数/反三角、双曲函数、对数、指数、阶乘、排列组合、微积分（求导/定积分/不定积分/极限）、求和求积、GCD/LCM、度分秒
- **矩阵计算**：矩阵创建（1×1 到 6×6）、四则运算、求逆、转置、共轭转置、行列式、特征值、秩、rref、迹、乘方
- **方程求解**：一元方程、多元方程组（最多 6 元），支持 x/y/z/u/v/w 为未知数
- **函数图像**：5 种函数类型（显函数/参数方程/极坐标/隐函数/点）、多函数叠加（最多 10 条）、颜色区分、图例显示、双指缩放与拖拽平移、定义域自定义、函数列表持久化
- **汇率换算**：172 种法定货币、贵金属及数字资产，支持多币种同步换算、搜索与 A-Z 索引、列表增删排序、整点缓存、手动刷新和离线缓存
- **设置**：深浅色模式、角度制切换、答案输出格式（自动/小数/分数/带分数/度分秒）、排列组合显示样式、振动反馈强度、启动页面、小数精度
- **历史记录**：按模块分类存储计算图文，支持插入表达式/结果、单条滑动删除、按模块清空

---

## 2. 核心架构：壳-插件 SPA 模型

CalculatorX 采用**单页面应用 (SPA) + 壳与插件**架构，不使用传统的路由跳转来切换计算器模式。

```
┌──────────────────────────────────────────┐
│  Index.ets (壳 Shell)                    │
│  ┌────────────────────────────────────┐  │
│  │  TopBar (全局悬浮控制栏)             │  │
│  │  - 菜单按钮 / 撤销 / 重做 / 历史      │  │
│  │  - 动态状态岛（模块名 + RAD/DEG）     │  │
│  ├────────────────────────────────────┤  │
│  │  动态插槽 (currentModule 驱动)       │  │
│  │  ┌──────────────────────────────┐  │  │
│  │  │ ScientificCalc / BasicCalc / │  │  │
│  │  │ MatrixCalc / EquationSolver /│  │  │
│  │  │ GraphingCalc / ExchangeRate  │  │  │
│  │  └──────────────────────────────┘  │  │
│  ├────────────────────────────────────┤  │
│  │  SideBarMenu (侧边栏抽屉)            │  │
│  │  HistorySheet (历史半模态抽屉)        │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### 壳 (Shell) — `pages/Index.ets`

[Index.ets](../entry/src/main/ets/pages/Index.ets) 是全局唯一的主入口，负责：

1. **启动初始化**：注册字体（Cambria Math、Cambria Italic）、初始化 `HistoryRepository` 数据库、通过 `PreferenceManager` 加载全部配置到 AppStorage
2. **启动页路由**：根据用户设置的"启动页面"偏好决定默认加载哪个模块，或恢复上次使用的模块
3. **动态模块挂载**：通过 `currentModule` 状态变量和 `if-else` 链实现模块的无缝切换（无路由跳转延迟）
4. **全局 UI 渲染**：TopBar（悬浮顶栏）、SideBarMenu（侧边栏）、HistorySheet（历史半模态抽屉）都在此层管理
5. **侧边栏动画**：开启侧边栏时，主内容区缩小至 92% 并圆角，形成卡片透视效果

### 插件 (Plugins) — `components/*Calc.ets`

每个计算器模块是**完全独立的 @Component**，拥有自己的：

- **按钮布局**（Grid 排列）
- **键盘组件**（@Component struct，如 `TopKeyItem`、`BottomKeyItem`）
- **局部状态**（`@State isShift`、shift 切换逻辑）
- **FormulaScreen 调用**（统一的公式屏幕组件，通过 `moduleType` 属性区分行为）

模块列表详见[第 5 节](#5-模块详解)。

---

## 3. 通信与状态管理

### 3.1 事件总线 (EventHub)

跨组件、跨层级通信使用 `getContext(this).eventHub`，**不引入第三方状态管理库**。

| 事件名 | 发射方 | 监听方 | 用途 |
|--------|--------|--------|------|
| `screen_handle_action` | 各 *Calc 键盘 | FormulaScreen | 传递按键 action + isShift 状态 |
| `event_shift_change` | 各 *Calc (shift 切换) | Index (→TopBar) | 通知顶栏更新 Shift 徽章显示 |
| `screen_shift_consumed` | FormulaScreen (S⇄D 长按) | 各 *Calc | 通知外部复位 Shift 键状态 |
| `event_math_insert` | Index (历史记录点击) | FormulaScreen | 从历史记录回填公式到屏幕 |
| `event_math_undo` | Index (TopBar 撤销按钮) | FormulaScreen | 触发 MathLive 的 undo 命令 |
| `event_math_redo` | Index (TopBar 重做按钮) | FormulaScreen | 触发 MathLive 的 redo 命令 |
| `request_graphing_data` | GraphingEditSheet（确认/切换焦点） | FormulaScreen | 请求提取当前编辑器的 LaTeX + AST，附带 reqId 编码（index + subTarget×10000） |
| `temp_graph_ast_ready` | FormulaScreen（AST 提取完成） | GraphingCalc、GraphingCanvas | 传递 reqId + rawLatex + AST，触发函数列表更新和画布重绘 |
| `response_graph_base64_ready` | FormulaScreen（PNG 渲染完成） | GraphingCalc | 传递 reqId + Base64 PNG，更新函数项的预览图 |
| `wake_web_engines` | GraphingEditSheet（焦点切换） | FormulaScreen | 唤醒 WebView（从 onInactive 恢复），准备公式编辑 |
| `sleep_web_engines` | GraphingCalc（面板关闭） | FormulaScreen | 休眠 WebView（调用 onInactive），释放 GPU 资源 |
| `load_latex_to_editor` | GraphingEditSheet（切换焦点） | FormulaScreen | 将指定 LaTeX 源码加载到隐藏 math-field 编辑器 |
| `open_graphing_edit_sheet` | GraphingCanvas / 外部 | GraphingCalc | 打开编辑面板 bindSheet |
| `force_close_domain_keyboard` | GraphingCalc（面板返回拦截） | GraphingEditSheet | 收起定义域小键盘输入框 |

### 3.2 AppStorage（全局状态）

只有**真正的跨模块共享属性**才放入 AppStorage。通过 `@StorageProp` / `@StorageLink` 装饰器消费。

| Key | 类型 | 来源 | 消费者 |
|-----|------|------|--------|
| `isRad` | boolean | PreferenceManager | EngineService (计算配置)、TopBar (徽章显示)、各 *Calc (R/D 切换) |
| `hapticFeedback` | boolean | PreferenceManager | HapticUtils、KeyGestureWrapper |
| `vibrationCurve` | number | PreferenceManager | HapticUtils |
| `decimalPrecision` | number | PreferenceManager | FormulaScreen (S⇄D 精度控制) |
| `colorModeIndex` | number | PreferenceManager | 全局颜色模式 |
| `answerOutputMode` | number | PreferenceManager | FormulaScreen (0=自动, 其他=小数) |
| `navBarHeight` | number | EntryAbility | 各组件底部安全区 padding |
| `activeBubbleId` | string | KeyGestureWrapper | 各 *Calc GridItem (zIndex 提权) |
| `KEY_COMBINATION_SELECT` | number | PreferenceManager | InputTranslator (组合数样式)、ScientificCalc 键盘图标 |
| `KEY_PERMUTATION_SELECT` | number | PreferenceManager | InputTranslator (排列数样式)、ScientificCalc 键盘图标 |
| `KEY_GRAPHING_FUNCTIONS` | string (JSON) | PreferenceManager | GraphingCalc（函数列表持久化，含表达式 AST/颜色/可见性） |
| `KEY_EXCHANGE_CURRENCY_LIST` | string (JSON) | PreferenceManager | ExchangeRate（当前货币列表及排序） |
| `KEY_EXCHANGE_ACTIVE_ID` | string | PreferenceManager | ExchangeRate（当前作为输入基准的列表项） |
| `KEY_EXCHANGE_BASE_AMOUNT` | string | PreferenceManager | ExchangeRate（当前基准金额） |
| `KEY_EXCHANGE_RATES` | string (JSON) | PreferenceManager | ExchangeRate（最近一次成功获取的汇率字典） |
| `KEY_EXCHANGE_LAST_UPDATE` | number | PreferenceManager | ExchangeRate（汇率缓存时间戳） |

### 3.3 @State / @Prop / @Link（局部状态）

各 *Calc 组件内部的状态（如 `isShift`、`isBubbleVisible`、`activeBubbleIndex` 等）完全由 `@State` 封锁在组件内部。**严禁**将业务状态泄漏到 AppStorage。

---

## 4. 计算生命周期：一次完整计算的数据流

以用户在科学计算器点击 `=` 为例，数据在四层之间流转：

```
┌──────────────────────────────────────────────────────────────┐
│ 步骤 1: 按键捕获 (ScientificCalc → FormulaScreen)              │
│                                                              │
│   ScientificCalc.handleButtonClick('=')                      │
│     → HapticUtils.playVibration('=')   // 马达震动            │
│     → eventHub.emit('screen_handle_action', '=', isShift)    │
│     → FormulaScreen.handleAction('=', false)                 │
│         → executeCalculation()                               │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│ 步骤 2: 提取 LaTeX (FormulaScreen → Calculator.html WebView)  │
│                                                              │
│   webviewController.runJavaScript('window.getFormula()')     │
│   ← math-field.value  (原始 LaTeX，如 \sin\left(x\right))     │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│ 步骤 3: 正则清洗 (EngineService.cleanRawLatex)                 │
│                                                              │
│   - 组合/排列 5 种样式 → 统一为 \operatorname{nCr/nPr}          │
│   - 度分秒 → \operatorname{dms}(d,m,s)                        │
│   - 反三角函数 → \operatorname{Arccsc/Arcsec/Arccot}           │
│   - 矩阵包装 → \operatorname{MWrap}(...) 绕过类型检查           │
│   - 矩阵上标 → \operatorname{TranOp/ConjTranOp/InvOp/MatPowOp}│
│   - 微积分导数 \frac{d}{dx} → \operatorname{diff}             │
│   - 行列式 \det → \operatorname{Det}                          │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────┐
│ 步骤 4: LaTeX → MathJSON AST (FormulaScreen → WebView)         │
│                                                               │
│   EngineService.generateInjectJs(cleanedLatex)                │
│   → JS: 创建隐藏 math-field → 设置 value → getValue('math-json')│
│   → 返回 MathJSON 格式的 AST 字符串                              │
│   → EngineService.parseWebJsonResult() 安全解析并验证 JSON       │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│ 步骤 5: N-API 调用 C++ 引擎 (EngineService → libentry.so)      │
│                                                              │
│   EngineService.calculateNative(jsonStr, config)             │
│     → unwrapMWrap() 剥离矩阵包装层                             │
│     → testNapi.calculate(jsonStr, {isRad, precision, mode})  │
│     → engine.cpp: Calculate() N-API 入口                      │
│         → json::parse 解析 AST                                │
│         → parser.cpp: parseAST() 递归下降解析                  │
│             - 数字/符号/函数 → SymEngine Expression            │
│             - 矩阵 → Giac 指令                                │
│             - 方程组 → csolve()                               │
│         → 精度分发:                                           │
│             precision=-1/-3: 符号/精确模式                     │
│             precision=-4: 带分数格式化                         │
│             precision=-5: DMS 度分秒                          │
│             precision>=0: 指定小数位数                         │
│         → FormatUtils 格式化输出 LaTeX                         │
│     ← 返回结果 LaTeX 字符串                                    │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│ 步骤 6: 显示结果 + 后台渲染入库                                  │
│                                                              │
│   webviewController.runJavaScript('showResult(latex)')       │
│   → 结果显示在前端 math-field (自适应字号缩放)                    │
│                                                              │
│   同时:                                                       │
│   renderWebController.runJavaScript('exportLatexToPng(...)') │
│   → render.html (暗房 WebView) 用 html2canvas 生成 PNG         │
│   → arktsBridge.onImageReady() 回调                           │
│   → HistoryRepository.insertRecord() 静默入库                  │
│      (含自动去重: 与上一条相同则跳过; 按模块保留最多 100 条)         │
└───────────────────────────────────────────────────────────────┘
```

### 关键设计决策

- **WebView 降维**：利用 MathLive 将 LaTeX 转为 MathJSON AST，使得 C++ 引擎无需解析 LaTeX 语法（LaTeX 解析极其复杂），而是解析结构化的 JSON 树
- **MWrap 保护层**：矩阵的 `bmatrix` 在 MathLive 中会触发类型检查报错，通过在清洗阶段包装 `\operatorname{MWrap}` 绕过限制，在 `unwrapMWrap()` 中还原
- **双引擎协同**：常规计算走 SymEngine（快速、轻量），高级符号计算（积分、极限、方程组、矩阵运算）走 Giac
- **暗房渲染 (render.html)**：历史记录的数学公式截图在一个隐藏的 WebView 中离线生成，完全不影响前台计算性能

---

## 5. 模块详解

### 5.1 模块切换机制

[SideBarMenu.ets](../entry/src/main/ets/components/SideBarMenu.ets) 将模块分为四个组：

- **模式**：基础计算、科学计算
- **进阶**：函数图像、方程求解、矩阵与向量、统计分析
- **转换**：单位转换、进制转换、汇率
- **参考**：公式库、科学常数、帮助

用户点击菜单项 → `onModuleSelect(moduleId)` 回调 → [Index.ets](../entry/src/main/ets/pages/Index.ets) 的 `currentModule` 状态更新 → `if-else` 链自动切换渲染的组件。同时 `PreferenceManager.set(KEY_LAST_USED_MODULE, module)` 静默记忆当前模块。

### 5.2 已实现的模块

#### ScientificCalc（科学计算器）

[ScientificCalc.ets](../entry/src/main/ets/components/ScientificCalc.ets)

- **键盘布局**：上键盘 6×5（30 键，支持 Shift 切换第二功能）+ 下键盘 5×5（25 键）
- **Shift 机制**：`⇧Shift` 键切换 `@State isShift`，顶栏通过 `event_shift_change` 事件同步显示 "⇧ SHIFT" 徽章
- **按键组件**：`TopKeyItem`（带 Shift 副功能悬浮文字 + 长按气泡菜单）+ `BottomKeyItem`（基础按键）
- **包容的运算符**：三角函数（sin/cos/tan + 反函数 + 双曲 + 倒数三角）、对数、阶乘、排列组合、微积分（积分/求导/极限/求和/求积）、GCD/LCM、度分秒、科学记数法
- **S⇄D 格式切换**：小数 ↔ 分数 ↔ 带分数 ↔ 度分秒，支持长按弹出格式选择气泡
- **状态管理**：`isShift`（Shift 模式）、通过 EventHub 与 FormulaScreen 通信

#### BasicCalc（基础计算器）

[BasicCalc.ets](../entry/src/main/ets/components/BasicCalc.ets)

- **键盘布局**：5×4（20 键），大圆形按钮
- **包容的运算符**：四则运算、百分数、Ans、退格（支持长按连续删除）
- **无 Shift**：最简化的单层键盘
- FormulaScreen 的 `moduleType='basic'` → `getCalcMode()` 返回 0（标准模式）

#### MatrixCalc（矩阵与线性代数）

[MatrixCalc.ets](../entry/src/main/ets/components/MatrixCalc.ets)

- **键盘布局**：6×5（30 键），带 Shift 切换
- **矩阵创建**：点击 `Dim` 按钮弹出矩阵维度选择器 `DimDialog`（1×1 到 6×6 的网格预览），确认后生成 `\begin{bmatrix}...\end{bmatrix}` LaTeX 模板，通过 eventHub 发送给 FormulaScreen
- **Shift 第二功能**：det（行列式）、MatPow（矩阵乘方）、ConjTran（共轭转置）、rref、eig（特征值）、rank、tr（迹）
- **直接功能**：M⁻¹（求逆）、Mᵀ（转置）、Mᴴ（共轭转置）、单位矩阵 I、行列式、叉乘（∘）
- FormulaScreen 的 `moduleType='matrix'` → `getCalcMode()` 返回 1（矩阵模式），触发 C++ 引擎的 Giac 矩阵运算路由

#### EquationSolver（方程求解器）

[EquationSolver.ets](../entry/src/main/ets/components/EquationSolver.ets)

- **键盘布局**：上键盘 3×6（18 键，带 Shift）+ 下键盘 5×5（25 键）
- **方程组模板**：`cases` 键长按弹出方程组行数选择（2-6 行），生成 `\begin{cases}...\end{cases}` LaTeX
- **未知数变量**：x/y/z/u/v/w（共 6 个），支持多元
- **运算符**：`=`（拼接等式）、`EXE`（执行求解）
- FormulaScreen 中 `=` 键走 `insertToWeb('=')`，`EXE` 键走 `executeCalculation()`
- FormulaScreen 的 `moduleType='equation'` → `getCalcMode()` 返回 2（方程模式），触发 C++ 引擎的 Giac `csolve()` 路由

#### GraphingCalc（函数图像）

[GraphingCalc.ets](../entry/src/main/ets/components/graphing/GraphingCalc.ets) 是图形计算器的顶层枢纽，组合 4 个子组件形成完整功能闭环。

**架构概览**：

```
GraphingCalc (顶层枢纽)
├── GraphingCanvas       ← 核心画布：Canvas 渲染 + 手势交互
├── GraphingEditSheet    ← 编辑面板 (bindSheet)：函数列表管理
│   ├── FormulaScreen    ←   隐藏式 WebView 引擎（LaTeX ↔ AST 转换）
│   ├── TopKeyItem / BottomKeyItem ← 专属键盘
│   └── DomainKeyboard   ←   定义域数字小键盘
└── 左上角图例           ←   函数颜色 + 表达式预览
```

**5 种函数类型**（[GraphingTypes.ets](../entry/src/main/ets/components/graphing/GraphingTypes.ets) 中的 `FunctionType` 枚举）：

| 类型 | 枚举值 | 特征 |
|------|--------|------|
| 普通显函数 f(x) | NORMAL (0) | 单一 x 变量 |
| 参数方程 x(t), y(t) | PARAMETRIC (1) | 双表达式，变量 t，可设定义域 [tMin, tMax] |
| 极坐标 r(θ) | POLAR (2) | 单表达式，变量 θ，可设定义域 |
| 隐函数 f(x,y)=0 | IMPLICIT (3) | 单表达式，双变量 x/y |
| 独立点 (x,y) | POINT (4) | 双表达式（x 坐标 + y 坐标） |

**核心子组件**：

- **[GraphingCanvas.ets](../entry/src/main/ets/components/graphing/GraphingCanvas.ets)** — 核心画布：
  - 使用 ArkUI `Canvas` 组件 + `CanvasRenderingContext2D` 进行 2D 绘制
  - 坐标系渲染：自适应步长网格（`minSpacingPx=40` → 智能选择 1/2/5/10 倍数）、坐标轴、刻度标签、原点标记 "0"
  - 函数曲线绘制：遍历 `functionList`，对每条可见函数调用 `EngineService.calculateGraphPoints()` 获取 `Float64Array` 采样点，通过 `ctx.lineTo()` 连线；遇到 NaN 自动断线（处理渐近线/奇点）
  - 独立点处理：当采样结果仅 2 个坐标时，绘制实心圆点而非连线
  - 手势交互：`PanGesture`（拖拽平移，增量式 offsetX/Y 累加）+ `PinchGesture`（双指缩放，以手势中心为锚点的几何补偿，缩放范围 [10⁻⁵, 10⁷]），两种手势通过 `GestureGroup(GestureMode.Parallel)` 并行
  - 避震机制：Pinch 结束后设置 `justEndedPinch=true`，Pan 检测到此标志时跳过首帧位移，吸收单指抬起时的重心跳跃
  - 帧率节流：`isRenderPending` 标志 + `setTimeout` 确保每帧最多一次重绘
  - 自适应深色模式：网格颜色/坐标轴颜色/文字颜色根据 `colorModeIndex` 动态切换
  - 监听 `temp_graph_ast_ready` 事件自动触发重绘

- **[GraphingEditSheet.ets](../entry/src/main/ets/components/graphing/GraphingEditSheet.ets)** — 编辑面板：
  - 通过 `bindSheet` 从底部弹出，支持 dragBar 和返回拦截（`onWillDismiss` 智能判断：键盘开着→抢救数据收起键盘、小键盘开着→收起小键盘、都没开→直接关闭）
  - 函数列表：最多 10 条（`MAX_FUNCTIONS = 10`），每条显示颜色圆点（点击切换可见性）+ 动态表达式行（根据函数类型渲染不同布局）+ 可选定义域行（参数方程/极坐标）
  - 焦点管理：`switchEditorFocus()` 在切换表达式编辑行时，先保存当前焦点数据（`request_graphing_data`），再唤醒引擎（`wake_web_engines`）并加载新 LaTeX（`load_latex_to_editor`）
  - 定义域编辑：`TextInput` 组件 + 自定义 `DomainKeyboard`（纯数字键盘），含光标感知的插入/删除逻辑和值同步
  - 新建函数：`FunctionTypeDialog` 自定义弹窗，5 种类型可选，自动分配未使用的颜色
  - 左滑删除：`SwipeAction` + 智能状态转移（同步调整 activeIndex 和编辑焦点，防止数据污染）
  - 底部键盘坞：`translate({ y: isKeyboardShow ? 0 : '100%' })` 动画滑入/滑出，内嵌 `FormulaScreen`（隐藏式引擎）+ 上下键盘 Grid

- **[GraphingKeyboard.ets](../entry/src/main/ets/components/graphing/GraphingKeyboard.ets)** — 专属键盘：
  - 上键盘 6×3：`getDynamicTopButtons()` 根据当前函数类型动态生成按键矩阵（普通函数独占 x，参数方程独占 t，极坐标独占 θ，隐函数双变量 x/y，点坐标无变量）
  - 下键盘 5×4：固定数字/运算符键盘，`确定` 键触发数据保存并收起键盘，`关闭` 键收起键盘
  - Shift 层：三角函数反函数、√³、|x|、x³、lg
  - `DomainKeyboard`：定义域专用的 4×4 纯数字小键盘（0-9 + 小数点 + 负号 + 退格 + AC + 确定），毛玻璃背景 + 圆角
  - 所有按键复用 `KeyGestureWrapper`，支持震动反馈

- **[GraphingTypes.ets](../entry/src/main/ets/components/graphing/GraphingTypes.ets)** — 类型定义：
  - `FunctionType` 枚举（5 种类型）
  - `GraphFunctionItem` 接口：id、color、isVisible、type、主表达式（latex/base64/ast）、伴生表达式（latex2/base64_2/ast2）、定义域边界（tMin/tMax）

**数据持久化**：
- `graphingFunctionsJson` 通过 `@StorageLink` 绑定到 AppStorage 的 `KEY_GRAPHING_FUNCTIONS`
- `saveFunctions()` 方法在每次修改后自动调用 `PreferenceManager.set()` 落盘
- 启动时从 JSON 反序列化恢复函数列表，空列表自动创建默认空项

**引擎休眠/唤醒机制**：
- GraphingCalc 复用 `FormulaScreen`（`moduleType='graphing'`）作为隐藏的 LaTeX→AST 转换引擎
- 面板关闭时发送 `sleep_web_engines` → FormulaScreen 调用 `webviewController.onInactive()` 释放 GPU 资源
- 面板打开/焦点切换时发送 `wake_web_engines` → FormulaScreen 调用 `webviewController.onActive()` 恢复渲染

#### ExchangeRate（汇率换算）

[ExchangeRate.ets](../entry/src/main/ets/components/exchange/rates/ExchangeRate.ets) 是汇率模块的顶层控制器。该模块不经过 FormulaScreen 或 C++ CAS，而是在 ArkTS 层完成网络调度、交叉汇率计算和列表交互。

**架构概览**：

```text
ExchangeRate（主视图与状态中枢）
├── CurrencySelector   ← 货币搜索、常用分组与 A-Z 索引
├── ExchangeKeyboard   ← 金额输入专属 4×4 数字键盘
├── CurrencyData       ← 172 种货币/资产的静态白名单与 O(1) 查询字典
├── ExchangeTypes      ← 列表项及网络响应类型
├── HarmonyOS HTTP     ← 从远端 API 拉取以 USD 为基准的汇率字典
└── PreferenceManager  ← 列表、选中项、金额、汇率与更新时间持久化
```

**实时换算模型**：

- 默认展示 USD、CNY、HKD、EUR、GBP、JPY、KRW 七种货币，任意卡片都可以切换为当前输入基准
- 汇率字典以 USD 为共同基准，目标金额按 `输入金额 ÷ 基准货币汇率 × 目标货币汇率` 实时计算
- 输出保留最多 4 位小数并去除尾随零；切换基准货币时会把当前换算结果反写为新基准金额，保持数值连续
- [ExchangeKeyboard.ets](../entry/src/main/ets/components/exchange/rates/ExchangeKeyboard.ets) 提供数字、小数点、AC、退格、确定和收起按键，复用 `KeyGestureWrapper` 与全局触感反馈

**货币列表与选择器**：

- [CurrencyData.ets](../entry/src/main/ets/components/exchange/rates/CurrencyData.ets) 维护 172 种法定货币、贵金属和数字资产的代码、中文名、符号与搜索关键词，并构建 `CURRENCY_MAP` 供主列表 O(1) 查询
- [CurrencySelector.ets](../entry/src/main/ets/components/exchange/rates/CurrencySelector.ets) 通过 `bindSheet` 以大型半模态页展示，默认包含 11 种常用货币分组和 A-Z 字母索引
- 搜索同时匹配货币代码、中文名、符号和中英文关键词；中文支持按字符模糊匹配，正则异常时自动降级为基础包含搜索
- 主列表支持添加货币、左滑删除和拖拽排序；修改后的列表顺序与当前输入项会自动持久化

**网络刷新与缓存**：

- `handleRefresh()` 是统一刷新入口：先通过 `connection.hasDefaultNetSync()` 检测网络，再判断缓存是否仍处于同一自然小时
- 缓存跨越整点或不存在时，使用 HarmonyOS HTTP 请求远端汇率 API；连接和读取超时均为 10 秒，请求令牌由 [ApiConfig.ets](../entry/src/main/ets/utils/ApiConfig.ets) 集中提供
- 请求成功后保存完整汇率字典和更新时间；请求失败或无网络时保留本地缓存，并通过状态文字和 Toast 向用户反馈
- `module.json5` 声明 `ohos.permission.INTERNET` 与 `ohos.permission.GET_NETWORK_INFO`，分别用于汇率请求和网络状态检测

**持久化状态**：

| Key | 内容 |
|-----|------|
| `KEY_EXCHANGE_CURRENCY_LIST` | 货币列表及用户排序（JSON） |
| `KEY_EXCHANGE_ACTIVE_ID` | 当前输入基准列表项 ID |
| `KEY_EXCHANGE_BASE_AMOUNT` | 当前输入金额 |
| `KEY_EXCHANGE_RATES` | 最近一次成功获取的汇率字典（JSON） |
| `KEY_EXCHANGE_LAST_UPDATE` | 最近一次成功刷新或缓存确认的时间戳 |

### 5.3 占位模块（开发中）

以下组件的 `build()` 仅渲染 "当前模块正在开发中..." 文本：
- [StatisticsCalc.ets](../entry/src/main/ets/components/StatisticsCalc.ets) — 统计分析
- [UnitConverter.ets](../entry/src/main/ets/components/UnitConverter.ets) — 单位转换
- [BaseConverter.ets](../entry/src/main/ets/components/exchange/BaseConverter.ets) — 进制转换

### 5.4 共享组件

#### FormulaScreen（公式屏幕）

[FormulaScreen.ets](../entry/src/main/ets/components/FormulaScreen.ets) 是连接 UI 键盘与计算引擎的**核心中枢**。大部分 *Calc 组件都复用它。

- **双 WebView 架构**：
  - `webviewController` → `calculator.html`（前台公式编辑 + 结果显示）
  - `renderWebController` → `render.html`（后台"暗房"，离屏渲染 PNG 缩略图）
- **事件监听**（在 `aboutToAppear` 中注册）：
  - `screen_handle_action`：接收来自各 *Calc 键盘的按键指令
  - `event_math_insert`：从历史记录回填
  - `event_math_undo` / `event_math_redo`：撤销/重做
  - `request_graphing_data`：图形模块请求提取当前编辑器的 LaTeX + AST（含 reqId 编码）
  - `sleep_web_engines` / `wake_web_engines`：图形面板关闭/打开时的 GPU 资源管理
  - `load_latex_to_editor`：图形模块切换焦点时加载目标 LaTeX 到隐藏编辑器
- **内部状态**：
  - `lastAnsLatex`：上一次计算结果（供 `Ans` 键调用）
  - `lastValidJson`：上一次合法的 AST（供 `S⇄D` 重新计算）
  - `isTempDecimal`：当前是否处于小数显示模式
- **`handleAction()` 方法**：约 130 行的 switch/if-else，覆盖所有特殊按键逻辑：
  - 编辑：AC、⌫、方向键移动光标
  - 状态切换：R/D（角度弧度切换）、⇧Shift
  - 计算：`=`（执行计算）、`EXE`（方程求解）
  - S⇄D：短按切换小数/分数，长按展开子菜单（小数/分数/带分数/度分秒）
  - Ans：插入上一步结果
- **`getCalcMode()` 方法**：将 `moduleType` 映射为 C++ 引擎的 `CalcMode`：
  - `matrix` → 1, `equation` → 2, `graphing` → 3, 其余 → 0 (STANDARD)
  - mode=3 时不会走标准计算流程，而是在 `engine.cpp` 中被**函数图像专属拦截路由**接管
- **JavaScript 代理 `arktsBridge`**：`render.html` 中的 `html2canvas` 生成图片后，通过 `arktsBridge.onImageReady(jsonStr)` 回调 ArkTS 端，触发 `HistoryRepository.insertRecord()`

#### KeyGestureWrapper（手势包装器）

[KeyGestureWrapper.ets](../entry/src/main/ets/components/common/KeyGestureWrapper.ets) 是**所有按键的底层交互引擎**，统管五种长按策略：

| 策略 | 触发条件 | 行为 |
|------|---------|------|
| `CONTINUOUS` | 退格、方向键 | 长按 300ms 后每 80ms 重复触发 |
| `NATIVE_MENU` | Ans 键 | 弹出系统原生上下文菜单 |
| `SLIDE_BUBBLE` | sin/cos/tan、cases、S⇄D、sqrt | 弹出横向气泡菜单，手指滑动选择，松开触发 |
| `DIRECT_SHIFT` | 有 shiftBtn 的键 | 长按直接发射 Shift 第二功能 |
| `NONE` | 其余所有键 | 无长按行为，仅短按 |

气泡菜单包含碰撞检测：当气泡超出屏幕边缘时自动计算 `bubbleOffsetX` 进行平移补偿。

#### TopBar（顶部悬浮控制栏）

[TopBar.ets](../entry/src/main/ets/components/TopBar.ets)

- **左侧**：菜单按钮（打开 SideBarMenu）、撤销按钮
- **中间**：动态状态岛 — 正常模式显示模块中文名 + "RAD/DEG" 角度制徽章，Shift 模式显示 "⇧ SHIFT"
- **右侧**：重做按钮、历史记录按钮（打开 HistorySheet）
- **视觉**：毛玻璃效果（`backgroundBlurStyle`），胶囊型按钮，半透明背景

#### SideBarMenu（侧边栏菜单）

[SideBarMenu.ets](../entry/src/main/ets/components/SideBarMenu.ets)

- 全屏透明遮罩 + 左侧 70% 宽度抽屉面板
- 支持**手势滑动关闭**（PanGesture + dragOffsetX 跟手 + 弹性回弹）
- 菜单项由 `MenuComponents` 的基础积木组装
- 点击菜单项自动收起侧边栏并通知 Index 切换模块

#### HistorySheet（历史半模态抽屉）

[HistorySheet.ets](../entry/src/main/ets/components/HistorySheet.ets)

- 通过 `bindSheet` 绑定到 TopBar 的历史按钮
- 内嵌 `UniversalHistoryList` 组件
- 支持帮助引导弹窗（首次用户了解如何插入历史记录）
- 支持清空当前模块所有历史记录（带二次确认弹窗）
- 点击表达式区 → 通过 `onItemClick` → Index → `event_math_insert` → FormulaScreen 回填

#### UniversalHistoryList（通用历史记录列表）

[UniversalHistoryList.ets](../entry/src/main/ets/components/common/UniversalHistoryList.ets)

- 被 `HistorySheet`（局部）和 `HistoryManager`（全局页面）共同复用
- 自动按日期分组（今天/昨天/X月X日），使用 `ListItemGroup` + `StickyHeader`
- 每个记录项：模块图标 + 输入区（可点击插入表达式）+ 结果区（可点击插入结果）
- 支持滑动删除（SwipeAction + 弹簧效果）
- LaTeX 内容优先渲染 Base64 图片（`Image` 组件），无图片时用 `Text` 渲染 LaTeX 原文
- 自适应深色模式（`colorFilter` 图片反色）

#### MenuComponents（菜单积木）

[MenuComponents.ets](../entry/src/main/ets/components/common/MenuComponents.ets)

纯 UI 无状态组件库：`GroupHeader`（分组标题）、`ItemDivider`（分割线）、`MenuButton`（带图标/副标题/右箭头的菜单行）、`MenuGroup`（卡片容器）。被 `SideBarMenu` 和设置页面复用。

---

## 6. C++ 引擎层

### 6.1 整体架构

C++ 代码位于 [entry/src/main/cpp/](../entry/src/main/cpp/)，通过 CMake 构建为 `libentry.so`，经由 N-API 暴露给 ArkTS 层。

```
entry/src/main/cpp/
├── CMakeLists.txt          # 构建脚本，静态链接 Giac + SymEngine + Boost
├── engine.cpp              # N-API 入口，全局计算路由与精度分发
├── core/
│   ├── parser.cpp/.h       # MathJSON AST → SymEngine Expression 递归下降解析器
│   ├── MatrixParser.cpp/.h # 矩阵 AST 解析（Matrix → 二维数组 → Giac 指令）
│   ├── giac_bridge.cpp/.h  # Giac CAS 桥接层（符号求值/方程/积分）
│   └── ErrorHandler.h      # 业务异常状态机（除零/定义域/溢出/语法/超时/DMS格式）
├── utils/
│   ├── FastMath.cpp/.h     # O(1) 超大数运算（10^10^19 级别）
│   ├── FormatUtils.cpp/.h  # 输出格式化（DMS/分数/科学记数法/浮点精度/LaTeX美化）
│   └── Logger.h            # C++ 端日志宏
├── third_party/            # 静态链接依赖（tar.gz 源码包）
│   ├── giac-1.9.0.tar.gz
│   ├── symengine-0.11.2.tar.gz
│   └── boost_1_82_0.tar.gz
├── include/                # 头文件依赖
│   ├── json.hpp            # nlohmann/json (JSON for Modern C++)
│   └── gmp.h               # GNU Multiple Precision
└── libs/arm64-v8a/         # 预编译静态库
    ├── libgmp.a
    └── libgmp·.a
```

### 6.2 核心文件详解

#### engine.cpp — N-API 入口与路由

[engine.cpp](../entry/src/main/cpp/engine.cpp) 是唯一暴露给 ArkTS 的接口。

- **暴露函数**：`calculate(jsonStr: string, config: {isRad, precision, mode}) → string`
- **核心流程**：
  1. 解析 JSON 输入和配置参数
  2. 如果 `mode === 3`（函数图像模式）→ **专属拦截路由**：
     - 解析复合 JSON payload（type/ast/ast2/tMin/tMax/yMin/yMax）
     - 缓存穿透：以 `json_str + (isRad ? "_rad" : "_deg")` 为 key 查 `graphing_cache`，命中直接复用编译好的 RPN 虚拟机
     - 未命中则调用 `parseAST()` 解析主表达式和伴生表达式（仅 PARAMETRIC/POINT 需要），`engine.compile(expr1, expr2)` 编译为 RPN 指令序列
     - 根据 func_type 分发给 5 种采样器 → 返回 `Float64Array`（N-API 零拷贝 ArrayBuffer）
  3. 如果 `mode === 2`（方程模式）→ **专属拦截路由**：
     - 拆解 `List`（方程组）或解析单一 `Equal`（一元方程）
     - 嗅探未知数（x/y/z/u/v/w），有多少检测多少
     - 组装 Giac 指令 `csolve([eq1,eq2,...], [x,y,...])`
     - 调用 `evaluateWithGiac()` 求解
     - 通过 `formatEquationResult()` 美化输出
  4. 否则走**标准解析流程**：`parseAST(ast, ctx)` → SymEngine Expression
  5. 检测是否需要 Giac 接管（积分/极限/求和/求积/GCD/LCM/导数/矩阵运算/根号化简）→ 如果命中则走 Giac 管道
  6. 根据 `precision` 参数分发输出格式

- **精度控制码 (`precision`)**：

| 值 | 含义 | 处理方式 |
|----|------|---------|
| -1 | 自动/精确 | 整数→原样输出，有根号→Giac simplify，其余→SymEngine latex |
| -2 | 最大小数 | eval_double + formatFloat(16位) |
| -3 | 精确-分数 | 同 -1 逻辑（`preferExact=true`） |
| -4 | 带分数 | formatFraction() 将假分数转为带分数 LaTeX |
| -5 | 度分秒 | eval_double + formatDMS() |
| ≥0 | 指定位数 | eval_double + formatFloat(precision) |

#### parser.cpp/.h — AST 递归下降解析器

[parser.h](../entry/src/main/cpp/core/parser.h) / [parser.cpp](../entry/src/main/cpp/core/parser.cpp)

- **`CalcContext` 结构体**：携带 `isRad`（弧度制）、`preferExact`（精确模式）、`hasDMS`（DMS 标记）、`mode`（计算模式）
- **`parseAST(json, ctx)`**：递归下降解析 MathJSON 树，将每个节点转换为 SymEngine Expression
- 支持所有 MathJSON 标准函数：`Add/Multiply/Power/Negate/Divide`、`Sin/Cos/Tan` 及其反函数、`Log/Exp/Sqrt`、`Factorial`、`Abs` 等
- 支持自定义操作符：`nCr/nPr`（排列组合）、`dms`（度分秒）、`diff`（求导）、`Det/Tr/TranOp/ConjTranOp/InvOp/MatPowOp`（矩阵操作）
- 支持 `MWrap` 矩阵包装（与 EngineService 清洗层配合）
- 三角函数自动处理角度/弧度转换（`isRad=false` 时乘 `π/180`）

#### giac_bridge.cpp/.h — Giac CAS 桥接

[giac_bridge.h](../entry/src/main/cpp/core/giac_bridge.h) / [giac_bridge.cpp](../entry/src/main/cpp/core/giac_bridge.cpp)

- **`evaluateWithGiac(expression)`**：将字符串表达式发送给 Giac 引擎求值，返回 LaTeX 结果
- **用途**：符号积分/极限/求和/求积、矩阵运算（det/rank/rref/eigenvals）、方程求解（csolve）、GCD/LCM、根号深度化简
- Giac 引擎作为全局单例初始化，避免重复创建上下文
- 积分失败时自动降级为 Romberg 数值积分，并对结果区间取中值

#### GraphingEngine.cpp/.h — 函数图像渲染引擎

[GraphingEngine.h](../entry/src/main/cpp/core/GraphingEngine.h) / [GraphingEngine.cpp](../entry/src/main/cpp/core/GraphingEngine.cpp)

专为函数图像设计的**极速采样引擎**，核心思想是"预编译 → 批量求值"，避免逐点调用 SymEngine 求值的开销。

**RPN 虚拟机架构**：
- **26 种指令操作码** (`OpCode` 枚举)：VAR_X/VAR_Y/VAR_T/VAR_THETA（多变量加载）、CONST_VAL（常数压栈）、ADD/SUB/MUL/DIV/POW（算术）、SIN/COS/TAN/ASIN/ACOS/ATAN/SINH/COSH/TANH/LN/LOG10/SQRT/ABS（数学函数）
- **`compileNode()`**：递归下降遍历 SymEngine AST，将表达式树编译为 RPN 指令序列。含整数次幂优化（x²→MUL、x³→MUL+MUL、x⁴⁻⁸→循环展开）
- **`compile(expr1, expr2)`**：双核编译 — 同时编译主表达式和伴生表达式的指令序列 + 导数指令序列。智能推断求导变量（参数方程用 t、极坐标用 θ、其余用 x）
- **`executeMachine(x, y, t, theta, inst_list)`**：128 深度栈式虚拟机，单次求值仅包含 switch 分发和栈操作，无函数调用开销

**5 种采样器**（在 `engine.cpp` 的 mode=3 路由中按 func_type 分发）：

| 采样器 | 对应类型 | 算法 |
|--------|---------|------|
| `generatePointsFast(xMin, xMax, n)` | 显函数 f(x) | **自适应递归采样**：基准网格（每 4px 一个探测点）→ 导数雷达检测极值点（二分法锁定 x_peak）→ 弯曲误差阈值（视口宽度/1000）→ 深度 8 递归细分 → 奇点断崖自动 NaN 断线 |
| `generateParametric(tMin, tMax, n)` | 参数方程 | 均匀步进采样（最少 500 点），evaluate() 取 x(t)，evaluate_2() 取 y(t) |
| `generatePolar(θMin, θMax, n)` | 极坐标 | 均匀步进采样（最少 500 点），evaluate() 取 r(θ)，直角坐标转换 (r·cos θ, r·sin θ) |
| `generatePoint()` | 独立点 | 直接求值一次 → 返回单个 (x, y) 坐标对 |
| `generateImplicit(xMin, xMax, yMin, yMax, res)` | 隐函数 | **Marching Squares**：150×150 网格采样 → 4 位状态编码（16 种零值线拓扑）→ 线性插值定位零点 → 分段线段输出（NaN 断线） |

**关键设计**：
- **全局缓存**：`engine.cpp` 中维护 `static unordered_map<string, GraphingEngine> graphing_cache`，key 为 `json_str + (isRad ? "_rad" : "_deg")`，避免重复解析和编译同一表达式
- **导数雷达**：`compile()` 阶段自动用 SymEngine 符号求导，生成 `deriv_instructions`。`generatePointsFast()` 在相邻采样点导数异号时，二分法定位极值点并强制插入采样
- **极限边界嗅探**：`generatePointsFast()` 在定义域边界（如 sqrt(x) 跨过 x=0）使用 20 次二分法逼近精确边界，注入 NaN 切断脏线
- **零拷贝传输**：采样结果 `vector<double>` 通过 N-API `napi_create_arraybuffer` 直接在共享内存中创建 `Float64Array`，ArkTS 端零解析开销直接传给 Canvas 绘图
- **奇点断崖检测**（`sampleRecursive` depth≥8 时）：符号穿越检测（y1×y2<0）+ 40 次二分法锁定奇点 x 坐标 → 注入 NaN 断开连线

#### ErrorHandler.h — 业务异常系统

[ErrorHandler.h](../entry/src/main/cpp/core/ErrorHandler.h)

- **`CalcException`**：自定义异常类，携带 `CalcErrorCode` 和详细消息
- **错误码映射**：

| CalcErrorCode | 前端显示 | 触发场景 |
|---------------|---------|---------|
| DIV_BY_ZERO | Error:DivByZero | 除数为零 |
| DOMAIN_ERROR | Error:Domain | 负数开偶次根 / 负数阶乘 |
| OVERFLOW_ERROR | Error:Overflow | 超出 64 位物理极限 |
| SYNTAX_ERROR | Error:Syntax | 语法/解析错误 |
| TIMEOUT_ERROR | Error:Timeout | 计算超时 / 引擎拒绝运算 |
| DMS_FORMAT_ERROR | Error:DMSFormat | 度分秒格式错误 |

所有异常在 `engine.cpp` 的 try-catch 中统一捕获，通过 `getFrontEndMessage()` 返回给前端。

#### FastMath — 超大数 O(1) 运算

[FastMath.h](../entry/src/main/cpp/utils/FastMath.h) / [FastMath.cpp](../entry/src/main/cpp/utils/FastMath.cpp)

- **场景**：阶乘 1000! 等结果远超 64 位整数范围（9e18）
- **方法**：
  - `checkOverflow(magnitude)`：检测是否溢出
  - `getFactorialMagnitude(n)`：计算阶乘的对数量级
  - `buildBigScientificNode(magnitude)`：构建科学记数法表示的代数节点，引入幽灵变量 `MAGICBASETEN`，精确基数为 10 位有效数字
- 在 `parser.cpp` 中，阶乘和大数次方计算时自动调用

#### FormatUtils — 输出格式化

[FormatUtils.h](../entry/src/main/cpp/utils/FormatUtils.h) / [FormatUtils.cpp](../entry/src/main/cpp/utils/FormatUtils.cpp)

- `formatDMS(float_val, isRad)`：将浮点数转为度分秒 LaTeX（`12^{\circ}34^{\prime}56^{\prime\prime}`）
- `formatFraction(s)`：将假分数转为带分数 LaTeX
- `formatFloat(val, precision)`：浮点数格式化（去尾零、科学记数法检测）
- `formatLargeIntegerToScientific(intStr)`：超大整数转科学记数法
- `formatEquationResult(raw_latex, var_names)`：方程组结果格式化（移除 Giac 内部符号、美化 `=` 分隔）
- `applyGlobalUIFormatting(result_msg)`：全局 LaTeX 美化（移除临时修饰符、归一化乘法符号）
- `adaptSymEngineToGiac(str)`：语法适配（`**` → `^`、`sqrt` → 标准形式等）

---

## 7. Web 渲染层

### calculator.html — 前台公式编辑与显示

[calculator.html](../entry/src/main/resources/rawfile/calculator.html)

- **核心库**：`compute-engine.min.js`（MathJSON 引擎）+ `mathlive.min.js`（LaTeX 排版）
- **双 math-field 布局**：
  - `#math-input`：可编辑输入区（用户在此输入公式）
  - `#math-result`：只读结果区（显示计算结果，淡入动画）
- **暴露给 ArkTS 的 JS 函数**：
  - `window.insertMath(latex)`：插入 LaTeX 到光标位置，带度分秒智能拦截（禁止在秒后输入数字）
  - `window.clearMath()`：清空输入和结果
  - `window.deleteMath()`：退格删除
  - `window.getFormula()`：返回当前输入区的原始 LaTeX
  - `window.showResult(latex)`：显示结果 LaTeX（带自适应字号缩放）
  - `window.keepCaretInView()`：光标自动追踪（横向+纵向滚动）
  - `window.insertDMS()`：智能度分秒插入（自动循环 ° → ' → "）
- **自适应字号算法**（`autoScaleFontSize`）：根据容器宽高与公式渲染尺寸的比值，动态缩放字体（输入 3.0-2.0rem，结果 3.0-2.0rem）
- **自定义触摸滚动**：劫持 `pointerdown/move/up` 实现公式区域的平滑滑动，与 MathLive 的光标点击互斥
- **主题**：CSS 变量 + `prefers-color-scheme` 媒体查询自适应深色/浅色模式

### render.html — 暗房离线渲染

[render.html](../entry/src/main/resources/rawfile/render.html)

- **定位**：在 FormulaScreen 中以 `position({ x: -5000, y: -5000 })` 放置在屏幕外，用户完全不可见
- **依赖**：`mathlive.min.js` + `html2canvas.min.js`
- **功能**：接收 LaTeX 输入和输出，渲染为 `math-field`，用 `html2canvas` 截图为 Base64 PNG
- **回调**：通过 `arktsBridge.onImageReady(jsonStr)` 将图片数据传回 ArkTS 端 → `HistoryRepository.insertRecord()`

### 辅助资源

- `mathlive-fonts.css` / `mathlive-static.css`：MathLive 字体和样式
- `fonts/`：KaTeX 数学字体（WOFF2 格式）+ Cambria Math/Italic
- `icons/`：自定义 SVG 数学符号图标（组合/排列/矩阵/方程模板/通用数学符号）
- `docs/`：应用的 Nextra 静态帮助文档站点（包含数学功能使用指南、界面说明、FAQ、隐私政策等）

### 函数图像的 WebView 复用

函数图像模块**不直接显示** `calculator.html` 的 math-field，而是将 `FormulaScreen` 作为隐藏的**纯 LaTeX↔AST 转换引擎**使用：

- `FormulaScreen({ moduleType: 'graphing' })` 仅在 `GraphingEditSheet` 的键盘坞中占 64px 高度，用户不可见
- 当用户编辑函数表达式时，按键通过 `screen_handle_action` 事件发送到隐藏 WebView 完成公式编辑
- 当用户点击"确定"或切换焦点时，`request_graphing_data` 触发：`getFormula()` → 清洗 → `generateInjectJs()` → AST 提取 → `temp_graph_ast_ready` 事件
- 同时调用 `render.html` 的 `exportLatexToPng()` 生成表达式预览图 → `response_graph_base64_ready` 事件
- 引擎休眠/唤醒：面板关闭时 `onInactive()` 释放 WebView GPU 资源，打开时 `onActive()` 恢复，确保不影响前台 Canvas 渲染性能

---

## 8. 数据持久化层

### 8.1 HistoryRepository — 历史记录数据库

[HistoryRepository.ets](../entry/src/main/ets/database/HistoryRepository.ets)

- **数据库**：SQLite 关系型数据库，文件 `CalculatorXHistory.db`
- **表结构**（单表 `history`）：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK AUTO | 自增主键 |
| module_type | TEXT NOT NULL | 模块标识（scientific/basic/matrix/equation/graph...） |
| input_content | TEXT NOT NULL | 用户输入（原始 LaTeX） |
| output_content | TEXT NOT NULL | 计算结果（C++ 引擎返回的 LaTeX） |
| input_base64 | TEXT | 输入公式的 PNG 截图 |
| output_base64 | TEXT | 输出结果的 PNG 截图 |
| extra_params | TEXT | 扩展槽（JSON 字符串，如坐标轴边界/矩阵阶数） |
| timestamp | INTEGER NOT NULL | 毫秒时间戳 |

- **索引**：`(module_type, timestamp DESC)` 复合索引，优化按模块和时间查询的性能
- **关键特性**：
  - **自动去重**：插入时查询同一模块上一条记录的 `input_content`，若完全相同则静默跳过，返回已有记录 ID
  - **自动清理**：每次插入后执行 DELETE 保留每个模块最多 100 条记录
  - **多模块查询**：支持逗号分隔的 moduleType（如 `'basic,scientific'`），内部转换为 SQL `IN` 查询
- **初始化时机**：在 `Index.aboutToAppear()` 中调用 `HistoryRepository.init(context)`，确保在应用启动时完成建表

### 8.2 PreferenceManager — 用户偏好

[PreferenceManager.ets](../entry/src/main/ets/utils/PreferenceManager.ets)

- **存储**：HarmonyOS `@kit.ArkData` Preferences API（key-value 持久化）
- **模式**：单例模式，启动时在 `EntryAbility` 中初始化
- **写入**：`set(key, value)` 自动落盘（`putSync` + `flush`）
- **读取**：`get(key, defaultValue)` 同步读取
- **批量注入**：`loadAllToAppStorage()` 将全局配置、函数图像数据和汇率模块状态一次性发布到 AppStorage
- **配置键**（在 `CalculatorConfigs.PreferenceConfigs` 中定义）：

| Key | 默认值 | 说明 |
|-----|--------|------|
| KEY_COLOR_MODE | 2 | 0=浅色, 1=深色, 2=跟随系统 |
| KEY_VIBRATION_CURVE | 0 | 0=自动, 1=清脆, 2=轻柔, 3=厚重 |
| KEY_IS_RAD | false | false=DEG, true=RAD |
| KEY_DECIMAL_PRECISION | 6 | 小数位数 (0-16) |
| KEY_ANSWER_OUTPUT_MODE | 0 | 0=自动, 1=小数 |
| KEY_COMBINATION_SELECT | 1 | 组合数显示样式 (0-4) |
| KEY_PERMUTATION_SELECT | 1 | 排列数显示样式 (0-4) |
| KEY_HAPTIC_FEEDBACK | true | 振动总开关 |
| KEY_STARTUP_PAGE | 0 | 0=上次使用, 1-9=指定模块 |
| KEY_LAST_USED_MODULE | 'scientific' | 上次使用的模块 ID |
| KEY_GRAPHING_FUNCTIONS | '[]' | 函数图像列表持久化（JSON 序列化的 GraphFunctionItem 数组） |
| KEY_EXCHANGE_CURRENCY_LIST | '[]' | 汇率模块的货币列表及排序（JSON；空列表由模块恢复默认七种货币） |
| KEY_EXCHANGE_ACTIVE_ID | '1' | 当前输入基准列表项 ID |
| KEY_EXCHANGE_BASE_AMOUNT | '100' | 当前输入金额 |
| KEY_EXCHANGE_RATES | '{}' | 最近一次成功获取的汇率字典（JSON） |
| KEY_EXCHANGE_LAST_UPDATE | 0 | 汇率缓存的最后更新时间戳 |

---

## 9. 设置与配置系统

### 9.1 页面路由

设置相关页面通过 `router.pushUrl` 导航：

| 页面 | 路由 | 文件 |
|------|------|------|
| 设置主页 | `pages/settings/Settings` | [Settings.ets](../entry/src/main/ets/pages/settings/Settings.ets) |
| 关于 | `pages/settings/About` | [About.ets](../entry/src/main/ets/pages/settings/About.ets) |
| 鸣谢 | `pages/settings/Credits` | [Credits.ets](../entry/src/main/ets/pages/settings/Credits.ets) |
| 帮助文档 | `pages/HelpDocs` | [HelpDocs.ets](../entry/src/main/ets/pages/HelpDocs.ets) |
| 文档查看器 | `pages/DocViewer` | [DocViewer.ets](../entry/src/main/ets/pages/DocViewer.ets) |
| 全局历史 | `pages/history/HistoryManager` | [HistoryManager.ets](../entry/src/main/ets/pages/history/HistoryManager.ets) |

### 9.2 Settings 页面

[Settings.ets](../entry/src/main/ets/pages/settings/Settings.ets) 包含以下设置项：
- **颜色模式**：浅色 / 深色 / 跟随系统（`colorModeIndex`）
- **角度单位**：角度制 (DEG) / 弧度制 (RAD)（`isRad`）
- **触感反馈**：开关 + 振动风格选择（`hapticFeedback` / `vibrationCurve`）
- **排列显示样式** / **组合显示样式**：各 5 种（`KEY_COMBINATION_SELECT` / `KEY_PERMUTATION_SELECT`）
- **答案输出格式**：自动 / 小数（`answerOutputMode`）
- **小数精度**：0-16 位（`decimalPrecision`）
- **启动页面**：上次使用 / 指定模块（`KEY_STARTUP_PAGE`）

设置项通过 `PreferenceManager.set(key, value)` 持久化，并同步更新 `AppStorage` 中的对应值。

### 9.3 EntryAbility — 应用启动入口

[EntryAbility.ets](../entry/src/main/ets/entryability/EntryAbility.ets)

- **初始化顺序**：
  1. 从 Preferences 读取全部配置
  2. 注入 AppStorage（供全局 `@StorageProp` 消费）
  3. 应用颜色模式（setColorMode）
  4. 加载 `pages/Index` 主页面
  5. 设置全屏布局
  6. 读取并监听导航条高度 → `navBarHeight`
- **全屏避让**：通过 `avoidAreaChange` 监听系统导航栏变化，动态更新 `navBarHeight`，各组件底部 padding 据此适配

### 9.4 计算器配置中心

[CalculatorConfigs.ets](../entry/src/main/ets/utils/CalculatorConfigs.ets) 是纯配置/常量/工具函数模块，无状态：
- SVG 图标资源常量和 `MathIcons` 静态类
- 排列/组合各 5 种样式的 `MathStyleOption` 数组
- `getActionId()`：将 Icon Resource 或字符串映射为标准化 actionID
- `getFontFamily/FontSize/FontColor/BgColor()`：根据按键类型返回对应视觉样式
- `RoutePath`：路由路径常量
- `PreferenceConfigs`：偏好设置、函数图像和汇率持久化的 key 名常量

---

## 10. 目录结构

```text
entry/src/main/
├── ets/                                    # 📱 ArkTS 前端逻辑与视图层
│   ├── entryability/
│   │   └── EntryAbility.ets                # 应用入口：初始化偏好、加载主页、全屏布局、导航条避让
│   ├── entrybackupability/
│   │   └── EntryBackupAbility.ets          # 备份扩展能力（占位，待实现云备份）
│   │
│   ├── pages/                              # 🧭 全局页面与骨架层 (Shell)
│   │   ├── Index.ets                       # 主枢纽：动态挂载业务插件、全局事件监听、侧边栏/历史抽屉管理
│   │   ├── DocViewer.ets                   # 文档查看器（显示应用内文档/隐私政策/用户协议等）
│   │   ├── HelpDocs.ets                    # 帮助文档页面（加载 rawfile/docs 的 Nextra 静态站点）
│   │   ├── history/
│   │   │   └── HistoryManager.ets          # 全局全屏历史检索页：底部 Tab 切换（全部/计算/方程/绘图/矩阵/转换/更多），支持复制到剪贴板
│   │   └── settings/
│   │       ├── Settings.ets                # 设置主页：颜色模式/角度制/震动/排列组合样式/输出格式/精度/启动页
│   │       ├── About.ets                   # 关于页面：版本号、开源许可、开发者信息
│   │       └── Credits.ets                 # 鸣谢页面：第三方库与贡献者列表
│   │
│   ├── components/                         # 🧩 独立业务插件与 UI 积木层
│   │   ├── ScientificCalc.ets              # 科学计算器插件：6×5 上键盘(Shift)+5×5 下键盘，三角函数/微积分/求和求积/排列组合
│   │   ├── BasicCalc.ets                   # 基础计算器插件：5×4 大圆按钮，四则运算/百分数/Ans/长按连续退格
│   │   ├── MatrixCalc.ets                  # 矩阵与向量插件：6×5 键盘(Shift)，维度和类型网格选择器(1×1 到 6×6)
│   │   ├── EquationSolver.ets              # 方程求解插件：3×6 上键盘(Shift)+5×5 下键盘，方程组模板(2-6行)，8个未知数变量
│   │   ├── graphing/                       # 📈 函数图像子系统 (5 种函数类型，10 条上限，多函数叠加)
│   │   │   ├── GraphingCalc.ets            # 顶层枢纽：状态管理、事件调度、图例渲染、bindSheet 生命周期控制
│   │   │   ├── GraphingCanvas.ets          # 核心画布：Canvas 坐标系渲染、Float64Array 零拷贝绘图、Pan/Pinch 手势交互
│   │   │   ├── GraphingEditSheet.ets       # 编辑面板：函数列表 CRUD、焦点切换、定义域编辑、类型选择弹窗
│   │   │   ├── GraphingKeyboard.ets        # 专属键盘：动态变量布局(按函数类型)、Shift 层、定义域数字小键盘
│   │   │   └── GraphingTypes.ets           # 类型声明：FunctionType 枚举(5 种)、GraphFunctionItem 接口
│   │   ├── exchange/
│   │   │   ├── rates/
│   │   │   │   ├── ExchangeRate.ets        # 汇率顶层控制器：交叉换算、网络刷新、缓存、列表 CRUD/排序与持久化
│   │   │   │   ├── CurrencySelector.ets    # 货币选择半模态页：搜索、常用分组、A-Z 索引与选中高亮
│   │   │   │   ├── ExchangeKeyboard.ets    # 汇率专属 4×4 数字键盘：金额输入、AC、退格、确定/收起
│   │   │   │   ├── CurrencyData.ets        # 172 种货币/资产静态白名单：代码、中文名、符号与搜索关键词
│   │   │   │   └── ExchangeTypes.ets       # 汇率列表项与 API 响应类型声明
│   │   │   ├── BaseConverter.ets           # 进制转换插件（占位，开发中）
│   │   │   └── UnitConverter.ets           # 单位转换插件（占位，开发中）
│   │   ├── StatisticsCalc.ets              # 统计分析插件（占位，开发中）
│   │   ├── FormulaScreen.ets               # 全能公式屏幕：双 WebView 中枢，事件监听/按键分发/计算调度/结果入库闭环
│   │   ├── TopBar.ets                      # 顶部悬浮控制栏：动态状态岛(模块名+RAD/DEG/Shift徽章)，毛玻璃胶囊按钮
│   │   ├── SideBarMenu.ets                 # 手势驱动侧边栏：模式/进阶/转换/参考四组菜单，滑动关闭+弹性回弹
│   │   ├── HistorySheet.ets                # 局部历史半模态抽屉：bindSheet 绑定，支持清空当前模块历史
│   │   └── common/
│   │       ├── KeyGestureWrapper.ets       # 万能按键手势基座：CONTINUOUS/NATIVE_MENU/SLIDE_BUBBLE/DIRECT_SHIFT/NONE 五策略
│   │       ├── UniversalHistoryList.ets    # 通用历史记录列表：日期分组/图文混排/滑动删除，被 HistorySheet 和 HistoryManager 共享
│   │       └── MenuComponents.ets          # 纯 UI 积木库：GroupHeader/ItemDivider/MenuButton/MenuGroup
│   │
│   ├── utils/                              # 🧠 核心服务与纯逻辑层
│   │   ├── EngineService.ets               # CAS 引擎中枢：5 大正则清洗(度分秒/排列组合/矩阵包装/反三角/微积分)、JS 注入生成、N-API 调度
│   │   ├── InputTranslator.ets             # 按键翻译中枢：70+ ActionID → 标准 LaTeX(含排列组合 5 种样式路由)
│   │   ├── HapticUtils.ets                 # 触控震感中心：Auto/Sharp/Soft/Hard 四档马达曲线，按键类型自适应
│   │   ├── CalculatorConfigs.ets           # 全局配置中心：SVG 资源常量、MathStyleOption 数据结构、RoutePath 路由、视觉函数(getFont/BgColor/FontSize/FontColor)、PreferenceConfigs 键名
│   │   ├── ApiConfig.ets                    # 网络 API 配置中心：提供汇率请求令牌
│   │   ├── PreferenceManager.ets           # 偏好管理单例：Preferences 读写自动落盘、全部配置批量注入 AppStorage
│   │   └── Logger.ets                      # 日志门面：封装 hilog，统一 domain/prefix
│   │
│   └── database/
│       └── HistoryRepository.ets           # RDB 调度中心：建表建索引、插入(自动去重+自动清理100条上限)、按模块查询(支持IN多模块)、清空、单条删除
│
├── cpp/                                    # ⚙️ C++ 计算机代数系统引擎层
│   ├── CMakeLists.txt                      # N-API 构建脚本：静态链接 Giac 1.9.0 + SymEngine 0.11.2 + Boost 1.82.0
│   ├── engine.cpp                          # N-API 唯一入口: calculate()，全局路由(图像拦截→ GraphingEngine 采样 / 方程拦截→ Giac csolve / 标准→ parseAST + 精度分发)
│   ├── core/
│   │   ├── parser.cpp/.h                   # AST 递归下降解析器：MathJSON → SymEngine Expression，角度/弧度转换，DMS/矩阵/排列组合/微积分特殊节点
│   │   ├── MatrixParser.cpp/.h             # 矩阵 AST 解析：JSON Matrix → 二维数组 → Giac 矩阵指令
│   │   ├── giac_bridge.cpp/.h              # Giac CAS 桥接：符号积分/极限/方程/矩阵运算/Romberg 数值积分降级
│   │   ├── GraphingEngine.cpp/.h           # 函数渲染引擎：RPN 虚拟机(26 指令)、符号导数雷达、自适应递归采样、Marching Squares 隐函数
│   │   └── ErrorHandler.h                  # 异常状态机：6 种业务错误码(DIV_BY_ZERO/DOMAIN/OVERFLOW/SYNTAX/TIMEOUT/DMS) → 前端友好信息
│   ├── utils/
│   │   ├── FastMath.cpp/.h                 # 极速超大数运算：O(1) 阶乘/幂运算(10^10^19 级)，幽灵变量 MAGICBASETEN 传递精确基数
│   │   ├── FormatUtils.cpp/.h              # 统一格式化：DMS/带分数/科学记数法/浮点数精度/方程组结果/全局 LaTeX 美化/SymEngine→Giac 语法适配
│   │   └── Logger.h                        # C++ 端日志宏(LOGI/LOGE)，对接 hilog
│   ├── include/
│   │   ├── json.hpp                        # nlohmann/json 单头文件 JSON 库
│   │   └── gmp.h                           # GNU Multiple Precision 大数库头文件
│   ├── libs/arm64-v8a/libgmp.a             # GMP 预编译静态库
│   ├── third_party/                        # 第三方依赖源码包 (静态链接)
│   └── types/libentry/                     # N-API 类型声明 (供 ArkTS 侧导入)
│       ├── Index.d.ts
│       └── oh-package.json5
│
├── resources/rawfile/                      # 🌐 本地 Web 沙箱与静态资源
│   ├── calculator.html                     # MathLive 容器：双 math-field(输入+结果)、自适应字号、光标追踪、DMS 智能插入、自定义触摸滚动
│   ├── render.html                         # 暗房容器：离屏 math-field + html2canvas → Base64 PNG → arktsBridge 回调入库
│   ├── compute-engine.min.js               # MathJSON 计算引擎 (Cortex JS)
│   ├── mathlive.min.js                     # MathLive 数学排版引擎
│   ├── html2canvas.min.js                  # HTML→Canvas 截图库 (用于历史记录缩略图)
│   ├── fonts/                              # 数学字体 (WOFF2 + TTF)
│   ├── icons/                              # 自定义 SVG 数学图标
│   └── docs/                               # Nextra 静态帮助文档站点 (_next/ + HTML 页面)
│
└── module.json5                            # 模块配置：abilities 声明、权限、包名等
```

---

## 附录 A：快速定位指南

### 按问题类型定位

| 问题类型 | 首先查看的文件 |
|---------|--------------|
| 按键无响应 | `KeyGestureWrapper.ets`（手势）、对应 `*Calc.ets`（按键发射）、`FormulaScreen.ets`（handleAction） |
| 计算结果错误 | `EngineService.ets`（正则清洗是否正确）、`engine.cpp`（C++ 路由与精度分发）、`parser.cpp`（AST 解析） |
| LaTeX 显示异常 | `calculator.html`（MathLive 渲染）、`InputTranslator.ets`（LaTeX 翻译是否正确） |
| 矩阵/向量报错 | `EngineService.ets`（MWrap 包装/矩阵清洗）、`MatrixParser.cpp`（矩阵 AST 解析）、`giac_bridge.cpp`（Giac 矩阵运算） |
| 方程求解报错 | `engine.cpp`（方程独占路由）、`giac_bridge.cpp`（csolve 调用） |
| 函数图像不显示/曲线错误 | `GraphingCanvas.ets`（Canvas 绘制逻辑）、`GraphingEngine.cpp`（采样器/编译）、`engine.cpp`（mode=3 路由、缓存） |
| 函数图像手势异常 | `GraphingCanvas.ets`（PanGesture/PinchGesture 处理、避震逻辑） |
| 函数编辑/焦点切换问题 | `GraphingEditSheet.ets`（焦点管理、switchEditorFocus）、`FormulaScreen.ets`（graphing 事件处理） |
| 汇率数值/刷新异常 | `ExchangeRate.ets`（换算公式、网络调度与缓存）、`ApiConfig.ets`（请求配置）、`CurrencyData.ets`（支持币种） |
| 汇率选择/列表交互异常 | `CurrencySelector.ets`（搜索、分组与索引）、`ExchangeRate.ets`（增删排序与选中状态）、`ExchangeKeyboard.ets`（金额输入） |
| 历史记录问题 | `HistoryRepository.ets`（数据库操作）、`render.html`（截图生成）、`FormulaScreen.ets`（arktsBridge 回调）、`UniversalHistoryList.ets`（列表渲染） |
| 设置不生效 | `PreferenceManager.ets`（读写）、`EntryAbility.ets`（初始化）、`Settings.ets`（UI 设置项） |
| 侧边栏/顶栏 UI 问题 | `SideBarMenu.ets`、`TopBar.ets`、`Index.ets`（全局布局） |
| 震动反馈异常 | `HapticUtils.ets`（vibrator 调用）、`KeyGestureWrapper.ets`（长按震动触发） |
| 角度/弧度切换问题 | `engine.cpp`（isRad 参数传递）、`parser.cpp`（角度弧度转换逻辑）、对应 *Calc 的 R/D 按钮 |

### 按功能模块定位

| 功能 | 核心文件（按调用链排序） |
|------|------------------------|
| 科学计算 | `ScientificCalc.ets` → `FormulaScreen.ets` → `InputTranslator.ets` → `EngineService.ets` → `engine.cpp` → `parser.cpp` |
| 基础计算 | `BasicCalc.ets` → `FormulaScreen.ets` → `EngineService.ets` → `engine.cpp` |
| 矩阵运算 | `MatrixCalc.ets` → `FormulaScreen.ets` → `EngineService.ets` → `engine.cpp` → `MatrixParser.cpp` → `giac_bridge.cpp` |
| 方程求解 | `EquationSolver.ets` → `FormulaScreen.ets` → `EngineService.ets` → `engine.cpp`(mode=2) → `giac_bridge.cpp`(csolve) |
| 函数图像 | `GraphingCalc.ets` → `GraphingEditSheet.ets` → `FormulaScreen.ets`(graphing 模式) → `EngineService.calculateGraphPoints()` → `engine.cpp`(mode=3) → `GraphingEngine.cpp`(RPN 采样器) → `GraphingCanvas.ets`(Canvas 绘制) |
| 汇率换算 | `ExchangeRate.ets` → `CurrencySelector.ets` / `ExchangeKeyboard.ets` → HarmonyOS HTTP / `CurrencyData.ets` → `PreferenceManager.ets` |
| S⇄D 格式切换 | `FormulaScreen.ets`(handleAction/recalculateWithPrecision) → `engine.cpp`(precision 控制码) → `FormatUtils.cpp` |
| 历史记录存取 | `FormulaScreen.ets`(arktsBridge.onImageReady) → `HistoryRepository.ets` → `UniversalHistoryList.ets` / `HistorySheet.ets` / `HistoryManager.ets` |
| 全局状态管理 | `PreferenceManager.ets` + `EntryAbility.ets`（初始化） + `CalculatorConfigs.ets`（键名定义） + 各 `*Calc.ets`（AppStorage 消费） |
