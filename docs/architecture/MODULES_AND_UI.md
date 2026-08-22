# 模块与 UI 架构

[← 返回架构主文档](../ARCHITECTURE.md)

本文档描述 CalculatorX 的 ArkUI 壳、业务插件、共享组件和移动端交互。系统总览见 [ARCHITECTURE.md](../ARCHITECTURE.md)。

## 目录

- [1. 壳与模块切换](#1-壳与模块切换)
- [2. 已实现业务插件](#2-已实现业务插件)
- [3. 开发中模块](#3-开发中模块)
- [4. FormulaScreen](#4-formulascreen)
- [5. 通用按键交互](#5-通用按键交互)
- [6. 全局共享组件](#6-全局共享组件)
- [7. 页面与启动 UI](#7-页面与启动-ui)
- [8. 修改边界](#8-修改边界)

---

## 1. 壳与模块切换

[Index.ets](../../entry/src/main/ets/pages/Index.ets) 是唯一主壳。它通过 `currentModule` 和 `if-else` 组件分支挂载计算器模式，不使用页面路由切换核心业务。

```text
Index
├── TopBar                 # 全局控制与状态岛
├── currentModule 插槽     # 当前业务插件
├── SideBarMenu            # 模块选择抽屉
└── HistorySheet           # 当前模块历史半模态页
```

模块切换流程：

```text
SideBarMenu 点击菜单项
  → onModuleSelect(moduleId)
  → Index.currentModule 更新
  → 对应 @Component 挂载
  → KEY_LAST_USED_MODULE 持久化
```

侧边栏将入口划分为四组：

- 模式：基础计算、科学计算
- 进阶：函数图像、方程求解、矩阵与向量、统计分析
- 转换：单位转换、进制转换、汇率
- 参考：公式库、科学常数、帮助

设置、帮助、关于、鸣谢、文档查看器和全局历史属于外围页面，通过 `router.pushUrl` 导航。

## 2. 已实现业务插件

### ScientificCalc

[ScientificCalc.ets](../../entry/src/main/ets/components/ScientificCalc.ets) 是功能最完整的通用计算器：

- 上键盘 6×5，支持 Shift 第二功能；下键盘 5×5
- 三角、反三角、双曲、倒数三角、对数和指数
- 阶乘、排列组合、GCD/LCM、科学记数法和度分秒
- 导数、积分、极限、求和与求积
- S⇄D 在小数、分数、带分数和度分秒间切换
- `event_shift_change` 将 Shift 状态同步给 TopBar

`TopKeyItem` 负责带副功能的上层按键和气泡菜单，`BottomKeyItem` 负责基础按键。业务动作通过 `screen_handle_action` 交给 FormulaScreen。

### BasicCalc

[BasicCalc.ets](../../entry/src/main/ets/components/BasicCalc.ets) 提供 5×4 大圆按钮布局：

- 四则运算、百分数和 Ans
- 退格支持长按连续删除
- 无 Shift 层，使用 FormulaScreen 标准模式

### MatrixCalc

[MatrixCalc.ets](../../entry/src/main/ets/components/MatrixCalc.ets) 面向矩阵和线性代数：

- 6×5 键盘和 Shift 层
- `DimDialog` 创建 1×1 至 6×6 的 `bmatrix` 模板
- 求逆、转置、共轭转置、行列式和矩阵乘方
- rank、rref、trace 和 eigenvalues
- `moduleType='matrix'` 映射到 C++ `mode=1`

矩阵跨 Web/C++ 的 MWrap 机制和 Giac 路由见 [计算管线](COMPUTE_PIPELINE.md)。

### EquationSolver

[EquationSolver.ets](../../entry/src/main/ets/components/EquationSolver.ets) 支持一元和多元方程：

- 上键盘 3×6，带 Shift；下键盘 5×5
- `cases` 长按生成 2–6 行方程组模板
- 支持 `x/y/z/u/v/w` 六个未知数
- `=` 只插入等式，`EXE` 执行求解
- `moduleType='equation'` 映射到 C++ `mode=2`

### GraphingCalc

[GraphingCalc.ets](../../entry/src/main/ets/components/graphing/GraphingCalc.ets) 组合 Canvas、编辑面板、隐藏公式引擎和专属键盘，支持五种函数类型及最多十条叠加。

该模块有独立的编辑、采样和渲染架构，详见 [GRAPHING.md](GRAPHING.md)。

### ExchangeRate

[ExchangeRate.ets](../../entry/src/main/ets/components/exchange/rates/ExchangeRate.ets) 是独立的联网换算模块，不进入 FormulaScreen/C++ CAS。它包含货币选择、金额输入、列表管理、缓存和实时换算。

完整设计见 [EXCHANGE.md](EXCHANGE.md)。

## 3. 开发中模块

以下组件目前只呈现开发中占位内容：

- [StatisticsCalc.ets](../../entry/src/main/ets/components/StatisticsCalc.ets)：统计分析
- [UnitConverter.ets](../../entry/src/main/ets/components/UnitConverter.ets)：单位转换
- [BaseConverter.ets](../../entry/src/main/ets/components/exchange/BaseConverter.ets)：进制转换

## 4. FormulaScreen

[FormulaScreen.ets](../../entry/src/main/ets/components/FormulaScreen.ets) 是键盘、WebView、C++ 引擎和历史记录之间的业务中枢。

### 双 WebView

- `webviewController` 加载 `calculator.html`，负责前台公式编辑和结果显示。
- `renderWebController` 加载 `render.html`，在屏幕外生成 PNG。

### 核心状态

- `lastAnsLatex`：上一次结果，供 Ans 插入
- `lastValidJson`：上一次合法 AST，供 S⇄D 重新计算
- `isTempDecimal`：当前是否临时显示小数

### 动作分发

`handleAction()` 统一处理：

- AC、退格和光标移动
- RAD/DEG 切换
- `=` 与方程 `EXE`
- S⇄D 短按和长按菜单
- Ans 插入
- 普通 ActionID → InputTranslator → LaTeX

### 模式映射

| moduleType | mode | 行为 |
|------------|------|------|
| matrix | 1 | 矩阵路由 |
| equation | 2 | 方程路由 |
| graphing | 3 | 图像采样路由 |
| 其他 | 0 | 标准计算 |

## 5. 通用按键交互

[KeyGestureWrapper.ets](../../entry/src/main/ets/components/common/KeyGestureWrapper.ets) 是所有计算器按键的手势基座。

| 策略 | 典型按键 | 行为 |
|------|----------|------|
| `CONTINUOUS` | 退格、方向键 | 长按后连续触发 |
| `NATIVE_MENU` | Ans | 系统上下文菜单 |
| `SLIDE_BUBBLE` | sin/cos/tan、cases、S⇄D、sqrt | 长按出现横向气泡，滑动选择 |
| `DIRECT_SHIFT` | 有 Shift 副功能的键 | 长按直接触发副功能 |
| `NONE` | 普通键 | 仅短按 |

气泡菜单会根据屏幕边缘计算水平补偿。`activeBubbleId` 用于跨 GridItem 提升当前气泡的 zIndex，避免被相邻按键遮挡。

触感由 [HapticUtils.ets](../../entry/src/main/ets/utils/HapticUtils.ets) 统一控制，支持自动、清脆、轻柔和厚重四种曲线。

## 6. 全局共享组件

### TopBar

[TopBar.ets](../../entry/src/main/ets/components/TopBar.ets) 包含菜单、撤销、重做和历史按钮。中间状态岛显示模块名称、RAD/DEG，Shift 激活时切换为 Shift 徽章。视觉采用毛玻璃和胶囊按钮。

### SideBarMenu

[SideBarMenu.ets](../../entry/src/main/ets/components/SideBarMenu.ets) 是左侧抽屉，支持遮罩点击和 PanGesture 跟手关闭。展开时 Index 主内容缩小并圆角化。

### HistorySheet

[HistorySheet.ets](../../entry/src/main/ets/components/HistorySheet.ets) 是当前模块历史半模态页，支持清空、滑动删除以及点击输入/结果回填 FormulaScreen。

### UniversalHistoryList

[UniversalHistoryList.ets](../../entry/src/main/ets/components/common/UniversalHistoryList.ets) 被局部历史和全局历史复用：

- 按今天、昨天或日期分组
- StickyHeader
- 输入和结果分区点击
- Base64 PNG 优先、LaTeX 文本兜底
- 深色模式图片反色
- SwipeAction 删除

### MenuComponents

[MenuComponents.ets](../../entry/src/main/ets/components/common/MenuComponents.ets) 提供无状态 UI 积木：`GroupHeader`、`ItemDivider`、`MenuButton` 和 `MenuGroup`。

## 7. 页面与启动 UI

| 页面 | 文件 | 职责 |
|------|------|------|
| 主页面 | `pages/Index.ets` | SPA 壳与模块挂载 |
| 设置 | `pages/settings/Settings.ets` | 主题、角度、振动、精度、输出和启动页 |
| 关于 | `pages/settings/About.ets` | 版本和开发者信息 |
| 鸣谢 | `pages/settings/Credits.ets` | 第三方库与贡献者 |
| 帮助 | `pages/HelpDocs.ets` | 加载本地 Nextra 站点 |
| 文档查看 | `pages/DocViewer.ets` | 隐私、协议等应用内文档 |
| 全局历史 | `pages/history/HistoryManager.ets` | 跨模块历史检索和复制 |

[EntryAbility.ets](../../entry/src/main/ets/entryability/EntryAbility.ets) 在加载 Index 前完成偏好注入、颜色模式应用、全屏布局和导航栏安全区监听。

## 8. 修改边界

- 新增计算器模式：添加独立组件、SideBarMenu 入口、Index 挂载分支和模块名称映射。
- 新增普通数学按键：通常同时检查模块键盘、InputTranslator、FormulaScreen 和 C++ parser。
- 新增长按行为：优先扩展 KeyGestureWrapper 策略，而不是在单个按钮中重复实现。
- 修改全局顶栏或历史抽屉：从 Index 的回调和 EventHub 边界开始检查。
