# 状态、通信与持久化

[← 返回架构主文档](../ARCHITECTURE.md)

CalculatorX 不使用第三方状态管理库，而是按生命周期和作用域选择 ArkUI 状态、EventHub、AppStorage、Preferences 或 RDB。

## 目录

- [1. 状态分层](#1-状态分层)
- [2. EventHub 事件表](#2-eventhub-事件表)
- [3. AppStorage](#3-appstorage)
- [4. PreferenceManager](#4-preferencemanager)
- [5. 启动初始化](#5-启动初始化)
- [6. 历史数据库](#6-历史数据库)
- [7. 设置写入](#7-设置写入)
- [8. 持久化选择准则](#8-持久化选择准则)

---

## 1. 状态分层

| 层级 | 机制 | 生命周期 | 适用数据 |
|------|------|----------|----------|
| 组件内部 | `@State` | 组件实例 | Shift、焦点、气泡、键盘显隐 |
| 父子组件 | `@Prop` / `@Link` | 组件树 | 回调、受控状态、列表项 |
| 瞬时跨层通信 | EventHub | 当前 UI 上下文 | 按键命令、撤销重做、异步响应 |
| 跨模块响应式状态 | AppStorage | 应用进程 | 主题、角度制、精度、持久化快照 |
| 跨启动键值 | Preferences | 磁盘 | 设置、绘图列表、汇率缓存 |
| 结构化历史 | RDB | 磁盘 | 可查询、可删除的计算记录 |

原则：局部状态保持局部；EventHub 不保存状态；AppStorage 不承担历史数据库职责。

## 2. EventHub 事件表

| 事件 | 发射方 | 监听方 | 作用 |
|------|--------|--------|------|
| `screen_handle_action` | 各计算器键盘 | FormulaScreen | action + Shift 状态 |
| `event_shift_change` | 各计算器模块 | Index/TopBar | 更新 Shift 徽章 |
| `screen_shift_consumed` | FormulaScreen | 各计算器模块 | S⇄D 等操作后复位 Shift |
| `event_math_insert` | Index/历史记录 | FormulaScreen | 回填输入或结果 |
| `event_math_undo` | TopBar/Index | FormulaScreen | MathLive undo |
| `event_math_redo` | TopBar/Index | FormulaScreen | MathLive redo |
| `request_graphing_data` | GraphingEditSheet | FormulaScreen | 请求 LaTeX 与 AST，携带 reqId |
| `temp_graph_ast_ready` | FormulaScreen | GraphingCalc/Canvas | 回传 AST，更新列表并重绘 |
| `response_graph_base64_ready` | FormulaScreen | GraphingCalc | 回传表达式预览 PNG |
| `wake_web_engines` | GraphingEditSheet | FormulaScreen | `onActive()` 唤醒 WebView |
| `sleep_web_engines` | GraphingCalc | FormulaScreen | `onInactive()` 休眠 WebView |
| `load_latex_to_editor` | GraphingEditSheet | FormulaScreen | 加载目标表达式 |
| `open_graphing_edit_sheet` | Canvas/外部 | GraphingCalc | 打开函数编辑面板 |
| `force_close_domain_keyboard` | GraphingCalc | GraphingEditSheet | 收起定义域键盘 |

新增事件时应明确：载荷格式、监听注册/注销位置、是否可能出现旧组件残留监听，以及异步返回如何关联请求。

## 3. AppStorage

### 全局设置与运行状态

| Key | 类型 | 主要消费者 |
|-----|------|------------|
| `isRad` | boolean | EngineService、TopBar、计算器模块 |
| `hapticFeedback` | boolean | HapticUtils、KeyGestureWrapper |
| `vibrationCurve` | number | HapticUtils |
| `decimalPrecision` | number | FormulaScreen |
| `colorModeIndex` | number | 全局主题和 Canvas |
| `answerOutputMode` | number | FormulaScreen |
| `navBarHeight` | number | 需要底部安全区的组件 |
| `activeBubbleId` | string | 各键盘 GridItem |
| `KEY_COMBINATION_SELECT` | number | InputTranslator、ScientificCalc |
| `KEY_PERMUTATION_SELECT` | number | InputTranslator、ScientificCalc |

### 模块快照

| Key | 类型 | 模块 |
|-----|------|------|
| `KEY_GRAPHING_FUNCTIONS` | JSON string | 函数图像列表 |
| `KEY_EXCHANGE_CURRENCY_LIST` | JSON string | 汇率货币列表/排序 |
| `KEY_EXCHANGE_ACTIVE_ID` | string | 汇率活动项 |
| `KEY_EXCHANGE_BASE_AMOUNT` | string | 汇率输入金额 |
| `KEY_EXCHANGE_RATES` | JSON string | 汇率字典 |
| `KEY_EXCHANGE_LAST_UPDATE` | number | 汇率缓存时间 |

## 4. PreferenceManager

[PreferenceManager.ets](../../entry/src/main/ets/utils/PreferenceManager.ets) 封装 HarmonyOS Preferences：

- `init(context)`：创建全局 Preferences 实例
- `set(key, value)`：`putSync` 后异步 `flush`
- `get(key, defaultValue)`：同步读取
- `loadAllToAppStorage()`：启动时批量发布响应式状态

配置键统一声明在 [CalculatorConfigs.ets](../../entry/src/main/ets/utils/CalculatorConfigs.ets) 的 `PreferenceConfigs`。

### 配置键与默认值

| Key | 默认值 | 说明 |
|-----|--------|------|
| `KEY_COLOR_MODE` | 2 | 浅色/深色/跟随系统 |
| `KEY_VIBRATION_CURVE` | 0 | 自动/清脆/轻柔/厚重 |
| `KEY_IS_RAD` | 代码当前默认值 | DEG/RAD |
| `KEY_DECIMAL_PRECISION` | 6 | 0–16 位小数 |
| `KEY_ANSWER_OUTPUT_MODE` | 0 | 自动/小数 |
| `KEY_COMBINATION_SELECT` | 1 | 五种组合数样式 |
| `KEY_PERMUTATION_SELECT` | 1 | 五种排列数样式 |
| `KEY_HAPTIC_FEEDBACK` | true | 振动总开关 |
| `KEY_STARTUP_PAGE` | 0 | 上次使用或指定模块 |
| `KEY_LAST_USED_MODULE` | `scientific` | 上次模块 ID |
| `KEY_GRAPHING_FUNCTIONS` | `[]` | 函数列表 JSON |
| `KEY_EXCHANGE_CURRENCY_LIST` | `[]` | 汇率列表 JSON |
| `KEY_EXCHANGE_ACTIVE_ID` | `1` | 汇率活动项 |
| `KEY_EXCHANGE_BASE_AMOUNT` | `100` | 汇率金额 |
| `KEY_EXCHANGE_RATES` | `{}` | 汇率缓存 JSON |
| `KEY_EXCHANGE_LAST_UPDATE` | 0 | 汇率时间戳 |

> 默认值应以当前源码为最终事实。修改默认值时同时检查 PreferenceManager 注入值、模块内兜底值和设置 UI。

## 5. 启动初始化

[EntryAbility.ets](../../entry/src/main/ets/entryability/EntryAbility.ets) 和 Index 的启动职责分开：

```text
EntryAbility
  → PreferenceManager.init()
  → loadAllToAppStorage()
  → 应用颜色模式
  → 加载 pages/Index
  → 设置全屏布局
  → 监听导航栏 avoidArea → navBarHeight

Index.aboutToAppear()
  → 注册字体
  → HistoryRepository.init(context)
  → 解析启动页面/上次模块
  → 注册壳级 EventHub 监听
```

顺序很重要：模块首次构建前，AppStorage 必须已经包含默认值或磁盘值。

## 6. 历史数据库

[HistoryRepository.ets](../../entry/src/main/ets/database/HistoryRepository.ets) 使用 RDB/SQLite，数据库文件为 `CalculatorXHistory.db`，表名为 `history`。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK AUTO | 自增 ID |
| `module_type` | TEXT | basic/scientific/matrix/equation/graph 等 |
| `input_content` | TEXT | 原始输入 LaTeX |
| `output_content` | TEXT | 结果 LaTeX |
| `input_base64` | TEXT | 输入 PNG |
| `output_base64` | TEXT | 输出 PNG |
| `extra_params` | TEXT | 模块扩展 JSON |
| `timestamp` | INTEGER | 毫秒时间戳 |

索引为 `(module_type, timestamp DESC)`。

### 写入路径

```text
FormulaScreen 计算成功
  → render.html 渲染输入/输出
  → arktsBridge.onImageReady(json)
  → HistoryRepository.insertRecord()
```

写入规则：

- 与同模块上一条 `input_content` 完全相同时去重
- 每次插入后清理，仅保留该模块最近 100 条
- 可通过逗号分隔 moduleType 转为 SQL `IN` 多模块查询

### 读取 UI

- HistorySheet：当前模块局部历史
- HistoryManager：跨模块全局历史
- UniversalHistoryList：日期分组、图片/文本渲染和滑动删除

点击输入或结果后由 Index 发出 `event_math_insert`，FormulaScreen 回填编辑器。

## 7. 设置写入

[Settings.ets](../../entry/src/main/ets/pages/settings/Settings.ets) 修改设置时应完成双写：

```text
用户选择
  → PreferenceManager.set(key, value)  # 跨启动
  → AppStorage 更新                    # 当前进程响应式刷新
```

只写 Preferences 会导致当前页面不立即响应；只写 AppStorage 会在重启后丢失。

## 8. 持久化选择准则

- 单个组件离开后无需保留：`@State`。
- 多个已挂载组件需要立即共享：AppStorage 或明确的父子 Link。
- 只是一条命令或通知：EventHub。
- 重启后需要恢复、数据量小且整块读写：Preferences。
- 需要排序、过滤、删除、限制数量或长期增长：RDB。

不要把大规模历史 JSON 塞入 Preferences，也不要为一个布尔 UI 状态建立数据库表。
