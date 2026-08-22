# 故障定位指南

[← 返回架构主文档](../ARCHITECTURE.md)

本指南按“现象 → 首查文件 → 下游链路”组织，用于在不遍历全仓库的情况下快速找到修改点。

## 目录

- [1. 按问题类型](#1-按问题类型)
- [2. 函数图像](#2-函数图像)
- [3. 汇率](#3-汇率)
- [4. 按功能调用链](#4-按功能调用链)
- [5. 文件索引](#5-文件索引)
- [6. 定位原则](#6-定位原则)

---

## 1. 按问题类型

| 问题 | 首先检查 |
|------|----------|
| 按键无响应 | `KeyGestureWrapper.ets` → 对应模块键盘 → `FormulaScreen.handleAction()` |
| 长按/气泡错误 | `KeyGestureWrapper.ets` 的策略、碰撞补偿和 `activeBubbleId` |
| 触感反馈异常 | `HapticUtils.ets` → KeyGestureWrapper/模块键盘传参 |
| LaTeX 插入错误 | 模块 action → `InputTranslator.ets` → `calculator.html` |
| 公式显示或滚动异常 | `calculator.html` 的 MathLive、字号和 pointer 逻辑 |
| 普通计算结果错误 | `EngineService.ets` 清洗 → `engine.cpp` 路由 → `parser.cpp` |
| S⇄D 格式错误 | `FormulaScreen` 的 lastValidJson/precision → `FormatUtils.cpp` |
| 角度/弧度错误 | AppStorage `isRad` → EngineService config → `parser.cpp` |
| 矩阵报错 | EngineService MWrap → `MatrixParser.cpp` → `giac_bridge.cpp` |
| 方程求解报错 | `engine.cpp` mode=2/未知数嗅探 → `giac_bridge.cpp` csolve |
| 积分/极限等 CAS 错误 | parser 特殊节点 → Giac 指令 → `giac_bridge.cpp` |
| 超大数结果错误 | `FastMath.cpp` → parser 阶乘/幂分支 → FormatUtils |
| C++ 错误消息不正确 | `ErrorHandler.h` → `engine.cpp` try-catch |
| 历史不入库 | `render.html` → arktsBridge → `HistoryRepository.insertRecord()` |
| 历史显示异常 | `UniversalHistoryList.ets` → Base64/文本兜底 → 深色 filter |
| 历史回填异常 | HistorySheet/Manager → Index → `event_math_insert` → FormulaScreen |
| 设置不生效 | `Settings.ets` 双写 → PreferenceManager → AppStorage 消费者 |
| 启动模块错误 | KEY_STARTUP_PAGE/KEY_LAST_USED_MODULE → EntryAbility/Index |
| 底部安全区错误 | EntryAbility avoidArea → `navBarHeight` → 目标组件 padding |
| 侧边栏/顶栏错误 | `Index.ets` → `SideBarMenu.ets` / `TopBar.ets` |

## 2. 函数图像

| 问题 | 检查链路 |
|------|----------|
| 表达式保存到错误行 | GraphingEditSheet `reqId` 编码 → FormulaScreen 回调 → activeIndex |
| 切换焦点丢数据 | `switchEditorFocus()` → `request_graphing_data` → `load_latex_to_editor` |
| 键盘变量不正确 | FunctionType → `GraphingKeyboard.getDynamicTopButtons()` |
| 曲线完全不显示 | AST 是否存在 → EngineService payload → engine mode=3 → GraphingEngine compile |
| 曲线形状错误 | RPN `compileNode/executeMachine` → 对应采样器 → Canvas 坐标转换 |
| 渐近线被错误连接 | `sampleRecursive` 奇点检测 → NaN 断线 → Canvas path 重启 |
| 极值被削平 | 符号导数编译 → 导数异号雷达 → 递归深度/误差阈值 |
| 隐函数缺线 | Marching Squares 网格、状态编码和线性插值 |
| 平移跳动 | Pan 增量 offset 与 `isAuto...` 状态 |
| 缩放中心漂移 | Pinch 锚点补偿、scale 范围和 offset 更新顺序 |
| 抬起一指时画布跳跃 | `justEndedPinch` 首帧吸收逻辑 |
| 面板关闭后仍占 GPU | sleep/wake 事件 → FormulaScreen onInactive/onActive |
| 图例预览不更新 | render.html → `response_graph_base64_ready` → GraphFunctionItem base64 |
| 函数列表重启后丢失 | KEY_GRAPHING_FUNCTIONS → PreferenceManager → save/loadFunctions |

## 3. 汇率

| 问题 | 检查链路 |
|------|----------|
| 数值明显不正确 | `rateMap` 是否含代码 → USD 基准假设 → `getConvertedAmount()` |
| 所有缺失币种都像 1:1 | ExchangeRate 对缺失 rate 的 1 倍兜底 → API 返回代码 |
| 无法刷新 | INTERNET/GET_NETWORK_INFO 权限 → connection 探网 → ApiConfig → HTTP 响应 |
| 总是使用缓存 | `lastUpdateTimeStamp` → `isCacheValid()` 自然小时比较 |
| 离线时数据消失 | KEY_EXCHANGE_RATES 注入 → loadData JSON 解析 |
| 货币搜不到 | CurrencyData 白名单/keywords → CurrencySelector 正则与降级搜索 |
| A-Z 索引错位 | getGroupedCurrencies 顺序 → List firstIndex → AlphabetIndexer selected |
| 切换输入币金额跳变 | `setActiveCurrency()` 是否先读取旧换算结果再更新 activeId |
| 删除/排序后重启还原 | `saveData()` → KEY_EXCHANGE_CURRENCY_LIST |
| 金额输入异常 | ExchangeKeyboard ActionID → `handleKeyboardInput()` 小数点/长度限制 |
| 键盘遮挡卡片 | mainListBottomSpace → scrollToIndex → isAutoScrolling |

## 4. 按功能调用链

| 功能 | 调用链 |
|------|--------|
| 科学计算 | `ScientificCalc` → `FormulaScreen` → `InputTranslator` → `EngineService` → `engine.cpp` → `parser.cpp` |
| 基础计算 | `BasicCalc` → `FormulaScreen` → `EngineService` → `engine.cpp` |
| 矩阵 | `MatrixCalc` → `FormulaScreen` → `EngineService` → `engine.cpp` → `MatrixParser` → `giac_bridge` |
| 方程 | `EquationSolver` → `FormulaScreen` → `EngineService` → `engine.cpp` mode=2 → `giac_bridge` |
| 函数图像 | `GraphingCalc` → `GraphingEditSheet` → 隐藏 `FormulaScreen` → `EngineService` → `engine.cpp` mode=3 → `GraphingEngine` → `GraphingCanvas` |
| 汇率 | `ExchangeRate` → `CurrencySelector` / `ExchangeKeyboard` → HTTP / `CurrencyData` → PreferenceManager |
| 格式切换 | `FormulaScreen.recalculateWithPrecision` → `engine.cpp` precision → `FormatUtils` |
| 历史写入 | `FormulaScreen` → `render.html` → arktsBridge → `HistoryRepository` |
| 历史读取 | `HistoryRepository` → `UniversalHistoryList` → HistorySheet/HistoryManager |
| 全局设置 | `Settings` → PreferenceManager + AppStorage → 各消费者 |

## 5. 文件索引

### ArkTS 壳与 UI

| 文件 | 职责 |
|------|------|
| `pages/Index.ets` | 主壳、模块挂载、全局 UI 和事件 |
| `components/FormulaScreen.ets` | 计算调度和双 WebView |
| `components/TopBar.ets` | 全局控制栏和状态岛 |
| `components/SideBarMenu.ets` | 模块菜单和抽屉手势 |
| `components/HistorySheet.ets` | 当前模块历史 |
| `components/common/KeyGestureWrapper.ets` | 所有按键手势 |
| `components/common/UniversalHistoryList.ets` | 历史列表渲染 |

### ArkTS 服务

| 文件 | 职责 |
|------|------|
| `utils/EngineService.ets` | LaTeX 清洗、MathJSON 和 N-API 调度 |
| `utils/InputTranslator.ets` | ActionID → LaTeX |
| `utils/CalculatorConfigs.ets` | 图标、视觉、路由和配置键 |
| `utils/PreferenceManager.ets` | Preferences 与 AppStorage 注入 |
| `utils/HapticUtils.ets` | 触感反馈 |
| `utils/ApiConfig.ets` | 汇率 API 配置 |
| `database/HistoryRepository.ets` | 历史 RDB |

### C++

| 文件 | 职责 |
|------|------|
| `cpp/engine.cpp` | N-API 入口、模式和精度路由 |
| `cpp/core/parser.cpp` | MathJSON 递归解析 |
| `cpp/core/MatrixParser.cpp` | 矩阵 AST 与 Giac 指令 |
| `cpp/core/giac_bridge.cpp` | 高级 CAS 桥接 |
| `cpp/core/GraphingEngine.cpp` | RPN 编译和五种采样器 |
| `cpp/core/ErrorHandler.h` | 业务错误映射 |
| `cpp/utils/FastMath.cpp` | 超大数 |
| `cpp/utils/FormatUtils.cpp` | 输出格式化 |

### Web

| 文件 | 职责 |
|------|------|
| `resources/rawfile/calculator.html` | MathLive 输入和结果显示 |
| `resources/rawfile/render.html` | 离屏 PNG |
| `resources/rawfile/compute-engine.min.js` | MathJSON 引擎 |
| `resources/rawfile/mathlive.min.js` | 数学编辑排版 |
| `resources/rawfile/html2canvas.min.js` | 截图 |

## 6. 定位原则

先确认问题发生在哪个边界：

```text
输入错误？   → 键盘 / InputTranslator / MathLive
结构错误？   → EngineService / MathJSON / parser
计算错误？   → engine 路由 / SymEngine / Giac
显示错误？   → FormatUtils / calculator.html
状态错误？   → 组件 State / EventHub / AppStorage
重启后错误？ → Preferences / RDB 初始化与兼容
```

尽量先修复产生错误数据的上游，不要只在最终 UI 中遮盖异常。
