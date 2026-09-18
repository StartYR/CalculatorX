# 📅 CalculatorX 更新日志 (Changelog)

本文件记录正式版本中面向用户的重要变化，不逐条罗列提交。

## [v1.6.5] - 2026-09-19

### ✨ 体验优化 (Improvements)

- 优化计算完成后的连续输入：基础、科学和矩阵模式现在会保留上一表达式与结果，数字或函数按键可直接开始新一笔计算，运算符与后缀操作可自动接续上一答案，并支持点击表达式返回原式编辑；同时修复了结果接续百分号可能出现 `Unknown_Error` 的问题。（[result-ready-input-flow.md](./changes/2026-09-15-result-ready-input-flow.md)）
- 目标 API 升级至 26，为主页 TopBar、历史记录、数学说明、货币选择、常用弹窗和原生长按菜单接入系统沉浸光感；最低兼容 API 仍为 23，不适合材质化的键盘、遮罩和局部视觉模糊继续保留原有效果。（[api-26-immersive-light.md](./changes/2026-09-18-api-26-immersive-light.md)）
- 优化历史记录、货币选择和侧边栏的沉浸光感体验：半模态标题栏与货币搜索框获得更自然的自适应模糊，历史日期分组可稳定吸附在标题栏下方，并修复搜索框阴影裁剪及标题间距、对比度等细节问题。（[immersive-sheet-and-sidebar.md](./changes/2026-09-19-immersive-sheet-and-sidebar.md)）

### 🛠️ 工程与测试 (Engineering)

- 为开发测试新增 Windows 到 HarmonyOS 设备的 LaTeX 计算自动化入口，可验证真实 MathLive、N-API 与 C++ 计算链路；该入口仅存在于测试包，不进入正式应用。（[windows-calculation-cli.md](./changes/2026-09-15-windows-calculation-cli.md)）
- 为开发测试新增 Windows 语义 CLI，可读取 CalculatorX 真机界面状态、按稳定控件 ID 操作普通界面并执行 JSON 回归场景；控制入口仍隔离在测试包中，不进入正式发布包。（[semantic-cli-automation.md](./changes/2026-09-16-semantic-cli-automation.md)）


## 缺失版本说明
从 `v1.6.5` 开始，每次发布新版本时，根据两个 Tag 之间新增的[分支变更说明](./changes/README.md)整理版本摘要，并将最新版本写在现有记录上方；同一份摘要可用于 [GitHub Releases](https://github.com/StartYR/CalculatorX/releases)。版本号遵循[语义化版本 2.0.0](https://semver.org/lang/zh-CN/) 规范，内容分类参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

重要或具有代表性的更新条目可以附上对应的详细变更说明，并以便于识别的文档名作为链接文字；链接文字可以省略文件名中的日期前缀。不要求每一条记录都添加链接。

`v1.3.1` 至 `v1.6.4` 期间没有持续维护本文件，暂不追溯补写。下方保留已有的早期版本记录。


## [1.3.0 Beta] - 2026-06

### 🚀 新增特性 (Features)

* **基础计算（Basic Calculation)**：新增基础计算功能
* **动态状态岛 (Dynamic Status Island)**：重构顶部控制栏 (`TopBar.ets`)，新增基于裁剪与过渡动画的翻转状态提示（支持实时显示模块名称、`⇪ SHIFT` 激活状态及 `RAD/DEG` 徽章）。

### 🛠️ 架构重构 (Refactoring)
* **壳与插件架构 (SPA 改造)**：将原本重达 600 行的 `Index.ets` 彻底拆分为“纯粹的导航枢纽”。将原有的科学计算器相关的双 Webview、双键盘抽象为完全独立的业务组件 `<ScientificCalc />`。
* **逻辑层彻底剥离**：
  * 新增 `utils/EngineService.ets`：统一接管原本写在 UI 层的极度复杂的正则清洗、MathJSON AST 提取以及与底层 C++ `libentry.so` 引擎的 N-API 通信逻辑。
  * 新增 `utils/HapticUtils.ets`：将按键反馈从 UI 交互中解耦，形成全局统一的马达震感（Hard/Sharp/Soft）控制服务。
* **事件总线解耦 (EventHub)**：在 `Index.ets` 与 `<ScientificCalc />` 之间引入 `eventHub.emit` 进行无耦合广播通信，彻底隔离全局事件与局部运算状态。
* **历史记录**：历史记录界面的删除按钮根据当前页面是否为空来显示，并且点击以后只删除当前页面的历史记录。

### 📝 文档完善 (Documentation)
* **重塑项目落地页**：全面升级 `README.md`，优化排版并补充快速上手指南与架构大纲，强化软著及版权声明。
* **确立开发宪法**：新增 `CONTRIBUTING.md` (开发者协作规范)，明确功能新增的“三步走” SOP、目录隔离铁律以及 Git 提交规范。
* **沉淀底层架构**：新增 `architecture.md` (系统架构指南)，透视图解“壳-插件”模型与跨端数据生命周期流转。

## [1.2.0] - 2026-06-24

- 新增历史记录功能。
- 新增侧边栏切换其他功能。
- 新增顶部栏。


## [1.1.0]

- 实现更高级的求和求积。
- 输入输出可以自适应字体大小。
- 输入输出超出屏幕界限时，可以滑动显示。
- 加入更多的字母功能键（a, b, c, d, m, n）。


## [1.0.0] - 正式版本 (Initial Release)

* 引入 Giac 引擎，添加高等数学计算的支持，包括：求导、积分、极限



## [v0.2.0] 更新内容
* 将答案换行显示。
* 添加“设置”功能。
* 支持深浅模式手动切换。
* 支持自定义答案输出格式（自动/小数）。
* 支持排列组合的显示样式，同时生效于按键显示与屏幕显示。
* 支持触感反馈，自定义振动风格。
* 添加“关于”界面。
* 添加“使用帮助”、“隐私政策”、“用户协议”
* 引入 `FastMath` ，实现在 $O(1)$ 时间复杂度下对宇宙级大数（最高 $10^{10^{19}}$）的极速解析与运算。
* 构建 `ErrorHandler` 异常拦截机制。


## [v0.1.1] - 第一版发布 🚀

这是 CalculatorPro 的首个核心里程碑版本。此版本彻底打通了从前端 UI、Web 容器到 C++ 底层计算机代数系统 (CAS) 的全链路架构，实现了从简单的“数值计算”向“精确符号推导”的跨越。

<img width="220.8" height="236.2" alt="file-20260531143150952" src="https://github.com/user-attachments/assets/34e35440-ae15-43be-8966-896458e21fc0" />

### ✨ 核心特性 (Key Features)

#### 🎨 原生级 UI 与沉浸式交互
* **系统级组件重构**：采用鸿蒙原生组件，带来丝滑的点击光效。
* **触觉反馈 (Haptics)**：加入按键震动反馈。
* **深浅色模式 (Dark/Light Mode)**：适配系统级深/浅主题切换。
* **多功能键盘状态机**：支持 ⇧Shift 键平滑切换科学计算与基础运算面板。

#### 📐 出版级数学公式渲染

* 集成 `MathLive` 本地沙箱引擎，支持复杂嵌套公式（如积分、多层分数、高次根号）的实时高清渲染。
* 实现输入即所得的 $\LaTeX$ 视觉排版。

#### 🧠 工业级代数引擎 (SymEngine)
* **数学推导系统**。底层通过 N-API 成功交叉编译并静态链接了专业的计算机代数系统 **SymEngine** 与高性能大数库 **Boost**。
* **精确符号推导**：拒绝精度丢失，$\sqrt{8}$ 自动提取平方因子；支持常数 $\pi$ 与 $e$ 的代数保留。
* **多项式展开与化简**：支持诸如 `(x+1)^2` 自动展开为 $1 + 2x + x^2$ 并以标准 $\LaTeX$ 返回。
* **极速跨语言通信**：创新性地利用 Web 容器进行数据降维（LaTeX -> MathJSON），由 C++ 原生解析 AST 语法树，实现毫秒级响应。
