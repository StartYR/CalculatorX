# CalculatorX 架构地图

本文档是 CalculatorX 的架构入口，面向新贡献者、人类开发者和 AI 编码助手。它只回答四个问题：

1. CalculatorX 是什么？
2. 系统由哪些层组成？
3. 一次操作如何穿过这些层？
4. 遇到需求或故障时应该继续阅读哪里？

具体模块、算法、状态键和排障细节在 [`docs/architecture/`](architecture/) 下的专题文档。

---

## 1. 一分钟理解项目

CalculatorX 是一款面向 **HarmonyOS NEXT** 的原生科学计算器，采用 ArkTS、WebView 与 C++ 协作的混合架构：

- **ArkUI / ArkTS**：应用壳、计算器键盘、交互、设置和数据调度
- **MathLive + Compute Engine**：LaTeX 编辑、数学排版和 MathJSON AST 生成
- **C++ N-API**：原生计算入口、模式路由和高性能数据传输
- **SymEngine + Giac**：常规符号运算与高级 CAS 运算
- **HarmonyOS Preferences + RDB**：设置、模块状态和历史记录持久化
- **HarmonyOS HTTP + Network Connection**：汇率数据拉取与网络检测

项目采用“**壳 + 插件**”的单页面模型。计算器模式不是独立路由页面，而是由主壳动态挂载的业务组件；设置、帮助、关于和全局历史等外围功能才使用页面路由。

```text
用户操作
   │
   ▼
ArkUI 壳与业务插件
   ├── 常规计算 ──► FormulaScreen ──► MathLive/MathJSON ──► N-API ──► C++ CAS
   ├── 函数图像 ──► 隐藏公式引擎 ──► C++ RPN 采样 ──► ArkUI Canvas
   └── 汇率换算 ──► HarmonyOS HTTP / 本地缓存 ──► ArkTS 交叉汇率计算
   │
   ▼
Preferences / RDB 持久化
```

---

## 2. 技术栈与职责边界

| 层级 | 技术 | 主要职责 |
|------|------|----------|
| 应用与 UI | ArkUI（ArkTS） | 壳、模块、手势、键盘、设置、业务编排 |
| 公式 Web 层 | MathLive、Compute Engine | LaTeX 编辑与排版、LaTeX → MathJSON AST |
| 截图 Web 层 | MathLive、html2canvas | 离屏生成历史记录和表达式预览 PNG |
| 原生桥接 | N-API | ArkTS ↔ C++ 调用、图像采样数据传输 |
| 符号计算 | SymEngine、Giac | 标准表达式、微积分、方程和矩阵运算 |
| 图像计算 | 自研 GraphingEngine | RPN 编译、自适应采样、隐函数提取 |
| 大数与格式 | Boost.Multiprecision、FastMath、FormatUtils | 超大数处理和 LaTeX 输出格式化 |
| 本地数据 | Preferences、RDB | 配置/模块状态、结构化历史记录 |
| 网络数据 | HarmonyOS HTTP、Network Connection | 汇率请求、联网状态判断和缓存调度 |

### 明确的层级边界

- ArkTS 负责业务状态和调度，不重复实现通用 CAS。
- WebView 负责数学输入和排版，不承担最终原生计算。
- C++ 接收结构化 MathJSON，而不是直接解析 LaTeX。
- 汇率是独立的 ArkTS 网络业务，不经过 FormulaScreen 或 C++ CAS。
- 局部交互状态留在组件内，只有跨模块共享状态进入 AppStorage。

---

## 3. 壳—插件 SPA

### 主壳

[Index.ets](../entry/src/main/ets/pages/Index.ets) 是全局主入口和模块枢纽，负责：

- 注册数学字体并初始化历史数据库
- 读取启动页面偏好或恢复上次使用模块
- 根据 `currentModule` 动态挂载业务插件
- 统一管理 TopBar、SideBarMenu 和 HistorySheet
- 监听全局撤销、重做、历史回填和 Shift 状态事件
- 控制侧边栏展开时的主内容缩放动画

### 业务插件

计算器模块都是独立 `@Component`，拥有自己的键盘布局、局部状态和交互逻辑：

| 模块 | 状态 | 主要入口 | 计算路径 |
|------|------|----------|----------|
| 基础计算 | 已实现 | `BasicCalc.ets` | FormulaScreen → C++ 标准模式 |
| 科学计算 | 已实现 | `ScientificCalc.ets` | FormulaScreen → SymEngine/Giac |
| 矩阵与向量 | 已实现 | `MatrixCalc.ets` | FormulaScreen → MatrixParser/Giac |
| 方程求解 | 已实现 | `EquationSolver.ets` | FormulaScreen → Giac `csolve()` |
| 函数图像 | 已实现 | `graphing/GraphingCalc.ets` | 隐藏 FormulaScreen → GraphingEngine → Canvas |
| 汇率换算 | 已实现 | `exchange/rates/ExchangeRate.ets` | HTTP/缓存 → ArkTS 交叉换算 |
| 统计分析 | 开发中 | `StatisticsCalc.ets` | 占位组件 |
| 单位转换 | 开发中 | `UnitConverter.ets` | 占位组件 |
| 进制转换 | 开发中 | `exchange/BaseConverter.ets` | 占位组件 |

模块的键盘、共享 UI 和交互机制详见 [模块与 UI](architecture/MODULES_AND_UI.md)。

---

## 4. 三条核心数据流

### 4.1 常规计算

```text
*Calc 键盘
  → EventHub: screen_handle_action
  → FormulaScreen.handleAction()
  → calculator.html 取得原始 LaTeX
  → EngineService 清洗特殊语法
  → Compute Engine 生成 MathJSON AST
  → N-API calculate(json, config)
  → engine.cpp 按 mode/precision 路由
  → SymEngine 或 Giac 计算
  → FormatUtils 输出 LaTeX
  → calculator.html 显示结果
  → render.html 离屏截图并写入历史数据库
```

这里最重要的决策是使用 MathLive/Compute Engine 将 LaTeX 转成 MathJSON，让 C++ 解析结构化 AST，而不是维护一套高复杂度 LaTeX 解析器。

完整清洗规则、模式路由、精度控制和 C++ 文件职责详见 [计算管线](architecture/COMPUTE_PIPELINE.md)。

### 4.2 函数图像

```text
GraphingEditSheet 编辑表达式
  → 隐藏 FormulaScreen 生成 AST
  → EngineService.calculateGraphPoints()
  → engine.cpp mode=3
  → GraphingEngine 编译为 RPN 指令
  → 按函数类型采样为 Float64Array
  → GraphingCanvas 绘制、平移和缩放
```

图形模块支持显函数、参数方程、极坐标、隐函数和独立点，最多叠加 10 条。完整算法与生命周期详见 [函数图像架构](architecture/GRAPHING.md)。

### 4.3 汇率换算

```text
ExchangeRate 启动或手动刷新
  → 网络状态检测 + 整点缓存判断
  → 必要时通过 HTTP 获取汇率字典
  → Preferences 缓存
  → 选择任意货币为输入基准
  → ArkTS 计算所有目标金额并实时刷新列表
```

汇率模块维护 172 种货币/资产白名单，支持搜索、A-Z 索引、增删排序和离线缓存。详见 [汇率架构](architecture/EXCHANGE.md)。

---

## 5. 通信与状态原则

项目不引入第三方状态管理库，使用四种机制分工：

| 机制 | 使用范围 | 示例 |
|------|----------|------|
| `@State` / `@Prop` / `@Link` | 组件内部或父子组件 | Shift、焦点、气泡、列表编辑状态 |
| EventHub | 跨层级的瞬时命令/事件 | 按键、撤销重做、历史回填、绘图 AST |
| AppStorage | 真正的跨模块共享状态 | 主题、角度制、精度、振动、模块持久化快照 |
| Preferences / RDB | 跨启动持久化 | 用户偏好、绘图/汇率状态、历史记录 |

设计原则：

- 局部业务状态不得无理由提升到 AppStorage。
- EventHub 用于事件，不作为长期数据仓库。
- Preferences 保存轻量键值和模块快照；RDB 保存可查询的历史记录。
- WebView 生命周期由宿主组件管理，隐藏不等于持续占用 GPU。

事件表、持久化键、数据库结构和启动初始化顺序详见 [状态与持久化](architecture/STATE_AND_STORAGE.md)。

---

## 6. 关键架构决策

### MathJSON 作为跨语言中间表示

LaTeX 适合输入和展示，但不适合作为 C++ 计算层的直接语法。项目通过 Compute Engine 生成 MathJSON AST，使解析器可以按节点递归处理数字、函数、矩阵和自定义运算符。

### 双 CAS 协同

- SymEngine：常规表达式和轻量符号计算，速度快、对象模型清晰。
- Giac：积分、极限、方程组、矩阵和复杂化简等高级能力。

`engine.cpp` 根据模式和表达式特征选择执行路径，而不是让所有输入无差别进入同一个引擎。

### 矩阵 MWrap 保护层

MathLive 对 `bmatrix` 的类型检查可能阻断矩阵 AST 生成。ArkTS 清洗阶段临时包装 `\operatorname{MWrap}`，转换完成后再剥离，以保护矩阵结构穿过 Web 层。

### 双 WebView

- `calculator.html`：用户可见的公式输入和结果显示。
- `render.html`：位于屏幕外的“暗房”，负责 PNG 缩略图。

历史截图不占用前台编辑器，函数图像还能按面板状态休眠/唤醒隐藏 WebView。

### 图像表达式预编译

函数绘图不逐点调用 SymEngine，而是将表达式预编译为 RPN 指令，通过轻量栈式虚拟机批量求值，并使用 `Float64Array` 传给 Canvas。

### 本地优先的汇率体验

汇率数据按自然小时缓存。无网络或请求失败时保留最近缓存，避免把联网故障扩大为模块不可用。

---

## 7. 持久化概览

### Preferences

保存两类数据：

- 全局配置：主题、角度制、精度、输出模式、振动、启动模块等
- 模块快照：函数列表、汇率列表、活动货币、金额、汇率字典和更新时间

应用启动时，[PreferenceManager.ets](../entry/src/main/ets/utils/PreferenceManager.ets) 将需要响应式消费的数据注入 AppStorage。

### RDB 历史记录

[HistoryRepository.ets](../entry/src/main/ets/database/HistoryRepository.ets) 使用 `CalculatorXHistory.db` 的 `history` 表保存：

- 模块类型
- 输入/输出 LaTeX
- 输入/输出 PNG
- 扩展参数
- 时间戳

记录按模块和时间建立索引；同模块连续相同输入自动去重，每个模块最多保留 100 条。

---

## 8. 核心目录

```text
entry/src/main/
├── ets/
│   ├── entryability/       # 应用启动、配置注入、窗口与安全区
│   ├── pages/              # 主壳及设置/帮助/历史等路由页面
│   ├── components/         # 业务插件和共享 UI
│   │   ├── graphing/       # 函数图像子系统
│   │   ├── exchange/       # 汇率及转换模块
│   │   └── common/         # 通用手势、历史列表和菜单积木
│   ├── utils/              # 引擎服务、输入翻译、配置和偏好
│   └── database/           # RDB 历史仓库
├── cpp/
│   ├── engine.cpp          # N-API 总入口和模式路由
│   ├── core/               # AST、Giac、矩阵、绘图和错误处理
│   └── utils/              # FastMath、格式化和日志
└── resources/rawfile/      # MathLive、Compute Engine、暗房和帮助站点
```

文件级职责请查看对应专题文档；遇到具体故障时直接进入 [故障定位指南](architecture/TROUBLESHOOTING.md)。

---

## 9. 专题文档索引

| 文档 | 什么时候读 |
|------|------------|
| [模块与 UI](architecture/MODULES_AND_UI.md) | 修改计算器键盘、壳、手势、共享组件或页面 |
| [计算管线](architecture/COMPUTE_PIPELINE.md) | 计算结果错误、LaTeX/AST、N-API、矩阵、方程或格式化 |
| [函数图像架构](architecture/GRAPHING.md) | 编辑函数、采样、Canvas、缩放平移或曲线异常 |
| [汇率架构](architecture/EXCHANGE.md) | 汇率请求、缓存、选择器、列表或换算异常 |
| [状态与持久化](architecture/STATE_AND_STORAGE.md) | EventHub、AppStorage、Preferences、历史数据库或启动初始化 |
| [故障定位指南](architecture/TROUBLESHOOTING.md) | 根据 bug 或需求快速找到调用链和文件 |

---

## 10. 维护约定

新增或调整功能时按影响范围更新文档：

- 改变系统分层、模块状态或核心数据流：更新本文件。
- 改变某个子系统的实现：只更新对应专题文档。
- 新增 EventHub 事件、AppStorage/Preferences 键：更新 `STATE_AND_STORAGE.md`。
- 改变调用链或故障入口：更新 `TROUBLESHOOTING.md`。
- 易变的动画时长、像素值和内部行数只在确有架构意义时记录。

主文档应保持“可在十分钟内读完”；专题文档负责保留实现深度。
