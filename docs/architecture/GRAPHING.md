# 函数图像架构

函数图像是 CalculatorX 中相对独立的高性能子系统。它复用公式编辑基础设施，但使用专门的 C++ 编译与采样引擎，不走普通计算结果管线。

## 1. 组件结构

```text
GraphingCalc
├── GraphingCanvas          # 坐标系、曲线和手势
├── GraphingEditSheet       # 函数列表与编辑面板
│   ├── FormulaScreen       # 隐藏 LaTeX ↔ AST 引擎
│   ├── GraphingKeyboard    # 按函数类型变化的键盘
│   └── DomainKeyboard      # 定义域数字键盘
└── 图例                    # 颜色与表达式 PNG
```

核心文件位于 [components/graphing/](../../entry/src/main/ets/components/graphing/)：

- `GraphingCalc.ets`：顶层状态、事件调度和 Sheet 生命周期
- `GraphingCanvas.ets`：Canvas 绘制与手势
- `GraphingEditSheet.ets`：列表 CRUD、焦点和编辑状态
- `GraphingKeyboard.ets`：专属公式键盘与定义域键盘
- `GraphingTypes.ets`：函数类型与持久化数据模型

## 2. 函数数据模型

`FunctionType` 定义五种类型：

| 类型 | 枚举 | 表达式 | 变量/定义域 |
|------|------|--------|-------------|
| 显函数 | `NORMAL` | `f(x)` | x |
| 参数方程 | `PARAMETRIC` | `x(t), y(t)` | t，可设 `[tMin,tMax]` |
| 极坐标 | `POLAR` | `r(θ)` | θ，可设定义域 |
| 隐函数 | `IMPLICIT` | `f(x,y)=0` | x、y |
| 独立点 | `POINT` | `(x,y)` | 两个常量表达式 |

`GraphFunctionItem` 保存：

- id、颜色、可见性和函数类型
- 主表达式的 LaTeX、AST、Base64 预览
- 伴生表达式的 LaTeX、AST、Base64 预览
- 参数/极坐标定义域

列表上限为 10 条；每次修改后序列化到 `KEY_GRAPHING_FUNCTIONS`。

## 3. 编辑数据流

GraphingEditSheet 不直接解析 LaTeX，而是把 FormulaScreen 当作隐藏编辑引擎：

```text
点击表达式行
  → switchEditorFocus()
  → 保存旧焦点: request_graphing_data(reqId)
  → wake_web_engines
  → load_latex_to_editor
  → GraphingKeyboard 通过 screen_handle_action 编辑
  → 点击确定/切换焦点
  → getFormula() + EngineService 清洗
  → Compute Engine 生成 AST
  → temp_graph_ast_ready(reqId, rawLatex, ast)
  → 更新 GraphFunctionItem 并重绘
```

`reqId` 编码列表索引和子表达式目标，用于区分参数方程或点的第一、第二表达式，避免异步回调写入错误对象。

同时，`render.html` 会生成表达式 PNG，通过 `response_graph_base64_ready` 更新图例预览。

## 4. 编辑面板与焦点

[GraphingEditSheet.ets](../../entry/src/main/ets/components/graphing/GraphingEditSheet.ets) 通过 `bindSheet` 展示：

- 颜色圆点点击切换可见性
- 按函数类型动态渲染单/双表达式和定义域行
- `FunctionTypeDialog` 新建五种类型并分配未使用颜色
- SwipeAction 左滑删除，并同步修正 activeIndex 和焦点
- FormulaScreen 与键盘位于底部键盘坞
- TextInput + DomainKeyboard 编辑定义域，包含光标感知插入/删除

`onWillDismiss` 按优先级处理返回：

1. 公式键盘开启：先保存当前表达式并收起。
2. 定义域键盘开启：先收起小键盘。
3. 无编辑状态：关闭 Sheet。

## 5. WebView 生命周期

隐藏 FormulaScreen 仍会占用 WebView/GPU，因此面板按状态主动管理：

- 面板关闭：`sleep_web_engines` → `webviewController.onInactive()`
- 打开或切换焦点：`wake_web_engines` → `webviewController.onActive()`
- 目标表达式切换：`load_latex_to_editor`

这使公式编辑器可以复用，而不会持续影响前台 Canvas。

## 6. C++ 路由与缓存

[engine.cpp](../../entry/src/main/cpp/engine.cpp) 在 `mode=3` 时提前拦截图像请求：

1. 解析包含 type、ast、ast2、定义域和视口的复合 payload。
2. 使用 `json_str + rad/deg` 查询全局 `graphing_cache`。
3. 缓存未命中时，将 AST 转为 SymEngine Expression。
4. 调用 `GraphingEngine.compile(expr1, expr2)` 编译 RPN。
5. 按 FunctionType 调用对应采样器。
6. 通过 N-API ArrayBuffer 返回 `Float64Array`。

缓存避免同一表达式在平移或缩放时重复解析和编译。

## 7. RPN 虚拟机

[GraphingEngine.cpp](../../entry/src/main/cpp/core/GraphingEngine.cpp) 将表达式树预编译为栈式指令序列。

主要指令类别：

- 变量：`VAR_X`、`VAR_Y`、`VAR_T`、`VAR_THETA`
- 常数：`CONST_VAL`
- 算术：ADD、SUB、MUL、DIV、POW
- 数学函数：三角、反三角、双曲、LN、LOG10、SQRT、ABS

`compileNode()` 递归遍历表达式；整数次幂对 2–8 次做乘法展开优化。`executeMachine()` 使用固定深度栈执行，无通用表达式替换开销。

编译阶段还根据函数类型选择求导变量，并生成符号导数指令，供显函数采样的极值探测使用。

## 8. 五种采样算法

| 采样器 | 类型 | 方法 |
|--------|------|------|
| `generatePointsFast` | 显函数 | 基准网格 + 导数雷达 + 弯曲误差 + 递归细分 |
| `generateParametric` | 参数方程 | t 定义域均匀采样，分别执行 x(t)、y(t) |
| `generatePolar` | 极坐标 | θ 均匀采样，转换为 `(r cosθ, r sinθ)` |
| `generatePoint` | 独立点 | 两个表达式各求值一次 |
| `generateImplicit` | 隐函数 | 150×150 网格 Marching Squares |

### 显函数自适应采样

`generatePointsFast()` 以约每 4px 一个探测点建立基准网格，并使用：

- 导数异号检测与二分法定位极值点
- 视口相关的弯曲误差阈值
- 最深 8 层递归细分
- 定义域边界二分逼近
- 奇点符号穿越检测和 NaN 断线

### 隐函数

Marching Squares 对每个网格单元计算四角符号，形成 4 位状态编码，通过线性插值定位零值线交点，并使用 NaN 分隔不连续线段。

## 9. Canvas 渲染

[GraphingCanvas.ets](../../entry/src/main/ets/components/graphing/GraphingCanvas.ets) 使用 `CanvasRenderingContext2D`：

- 网格步长按 1/2/5/10 数列自适应，保持最小屏幕间距
- 绘制坐标轴、刻度、标签和原点
- 遍历可见函数并请求 Float64Array
- 普通点对使用 `lineTo()`，NaN 时断开路径
- 仅含一组坐标时绘制实心独立点
- 深浅色模式切换网格、轴线和文字颜色

`isRenderPending` 与定时调度确保一帧最多重绘一次，避免手势高频事件淹没 UI 线程。

## 10. 平移与缩放

PanGesture 与 PinchGesture 通过 `GestureGroup(GestureMode.Parallel)` 并行：

- Pan 使用增量式 offset 累加。
- Pinch 以手势中心为锚点补偿坐标偏移。
- 缩放范围约为 `10⁻⁵` 到 `10⁷`。
- Pinch 结束后设置 `justEndedPinch`，Pan 跳过首帧，吸收一根手指先抬起造成的重心跳跃。

## 11. 关键事件

| 事件 | 作用 |
|------|------|
| `request_graphing_data` | 请求当前 LaTeX 和 AST |
| `temp_graph_ast_ready` | 回传 AST 并触发列表更新/重绘 |
| `response_graph_base64_ready` | 回传表达式 PNG |
| `wake_web_engines` | 唤醒隐藏 WebView |
| `sleep_web_engines` | 休眠隐藏 WebView |
| `load_latex_to_editor` | 切换编辑目标 |
| `open_graphing_edit_sheet` | 外部打开编辑面板 |
| `force_close_domain_keyboard` | 收起定义域键盘 |

## 12. 修改边界

- 新增函数类型通常需要同时修改 GraphingTypes、编辑布局、动态键盘、engine mode=3 路由、GraphingEngine 和 Canvas。
- 修改采样算法时保持 NaN 断线协议和 Float64Array 数据格式稳定。
- 修改异步编辑流程时保持 reqId 与双表达式目标的映射稳定。
- 修改手势时同时检查锚点补偿、Pinch/Pan 并行和帧率节流。
