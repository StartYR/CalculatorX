# 计算管线

[← 返回架构主文档](../ARCHITECTURE.md)

本文档描述从用户输入到 C++ 计算、结果显示和历史入库的完整链路。系统总览见 [ARCHITECTURE.md](../ARCHITECTURE.md)。

## 目录

- [1. 端到端生命周期](#1-端到端生命周期)
- [2. ArkTS 输入与清洗](#2-arkts-输入与清洗)
- [3. Web 公式层](#3-web-公式层)
- [4. N-API 总入口](#4-n-api-总入口)
- [5. MathJSON AST 解析](#5-mathjson-ast-解析)
- [6. 矩阵管线](#6-矩阵管线)
- [7. SymEngine 与 Giac](#7-symengine-与-giac)
- [8. 精度与输出格式](#8-精度与输出格式)
- [9. 超大数](#9-超大数)
- [10. 业务异常](#10-业务异常)
- [11. 修改时的检查顺序](#11-修改时的检查顺序)

---

## 1. 端到端生命周期

以科学计算器点击 `=` 为例：

```text
ScientificCalc.handleButtonClick('=')
  → HapticUtils.playVibration()
  → EventHub: screen_handle_action
  → FormulaScreen.handleAction()
  → executeCalculation()
  → calculator.html: window.getFormula()
  → EngineService.cleanRawLatex()
  → Compute Engine: getValue('math-json')
  → EngineService.parseWebJsonResult()
  → testNapi.calculate(json, { isRad, precision, mode })
  → engine.cpp: Calculate()
  → parser.cpp / MatrixParser / giac_bridge / GraphingEngine
  → FormatUtils 生成结果 LaTeX
  → calculator.html: showResult()
  → render.html: exportLatexToPng()
  → HistoryRepository.insertRecord()
```

## 2. ArkTS 输入与清洗

### InputTranslator

[InputTranslator.ets](../../entry/src/main/ets/utils/InputTranslator.ets) 将 70+ 标准 ActionID 翻译为可插入 MathLive 的 LaTeX。它负责普通数字、函数、模板和排列组合显示样式的入口统一。

按键视觉资源和 ActionID 映射集中在 [CalculatorConfigs.ets](../../entry/src/main/ets/utils/CalculatorConfigs.ets)。

### FormulaScreen

[FormulaScreen.ets](../../entry/src/main/ets/components/FormulaScreen.ets) 从 `calculator.html` 取得原始 LaTeX，维护上次结果和合法 AST，并决定当前 `mode` 与 `precision`。

### EngineService 清洗

[EngineService.ets](../../entry/src/main/ets/utils/EngineService.ets) 在 AST 生成前规范化 MathLive 难以直接表达或 C++ 需要识别的结构：

- 五种排列/组合视觉样式 → `\operatorname{nCr}` / `\operatorname{nPr}`
- 度分秒 → `\operatorname{dms}(d,m,s)`
- 反余割、反正割、反余切 → 自定义反三角操作符
- 矩阵 → `\operatorname{MWrap}(...)`
- 矩阵上标 → 转置、共轭转置、求逆和矩阵乘方操作符
- 导数形式 → `\operatorname{diff}`
- 行列式 → `\operatorname{Det}`

`generateInjectJs()` 将清洗后的 LaTeX 放入隐藏 math-field，通过 Compute Engine 取得 MathJSON；`parseWebJsonResult()` 对 WebView 返回值做安全解析和 JSON 验证。

## 3. Web 公式层

### calculator.html

[calculator.html](../../entry/src/main/resources/rawfile/calculator.html) 加载 MathLive 和 Compute Engine，包含：

- `#math-input`：可编辑输入区
- `#math-result`：只读结果区
- `insertMath()`、`clearMath()`、`deleteMath()`、`getFormula()`、`showResult()`
- DMS 智能插入和输入拦截
- 光标跟踪、触摸滚动和自适应字号
- CSS 变量与系统深浅色适配

### render.html

[render.html](../../entry/src/main/resources/rawfile/render.html) 是屏幕外的离线渲染器：

```text
输入/输出 LaTeX
  → MathLive 排版
  → html2canvas 截图
  → Base64 PNG
  → arktsBridge.onImageReady()
  → HistoryRepository
```

历史列表因此不需要为每一条记录维持活跃 math-field。

## 4. N-API 总入口

[engine.cpp](../../entry/src/main/cpp/engine.cpp) 暴露：

```text
calculate(jsonStr, { isRad, precision, mode }) → string 或 Float64Array
```

### 模式路由

| mode | 模式 | 路由 |
|------|------|------|
| 0 | STANDARD | parseAST → SymEngine，必要时 Giac 接管 |
| 1 | MATRIX | MatrixParser / Giac 矩阵管道 |
| 2 | EQUATION | 未知数嗅探 → Giac `csolve()` |
| 3 | GRAPHING | GraphingEngine 编译和采样，返回 Float64Array |

方程模式会解析单个 `Equal` 或方程组 `List`，从 `x/y/z/u/v/w` 中检测实际未知数，构建 `csolve([eq...], [vars...])`，最后由 `formatEquationResult()` 美化。

标准模式先生成 SymEngine Expression，再检测积分、极限、求和、求积、GCD/LCM、导数、矩阵或深度根式化简等需要 Giac 的节点。

## 5. MathJSON AST 解析

[parser.cpp](../../entry/src/main/cpp/core/parser.cpp) / `parser.h` 使用递归下降方式把 MathJSON 节点转换为 SymEngine Expression。

`CalcContext` 携带：

- `isRad`：弧度/角度模式
- `preferExact`：精确输出偏好
- `hasDMS`：度分秒标记
- `mode`：计算模式

支持的节点包括：

- 标准算术：Add、Multiply、Power、Negate、Divide
- 数学函数：三角、反三角、双曲、Log、Exp、Sqrt、Abs、Factorial
- 自定义运算：nCr、nPr、dms、diff
- 矩阵运算：Det、Tr、TranOp、ConjTranOp、InvOp、MatPowOp
- MWrap 保护层

角度模式下，三角函数参数自动乘 `π/180`；弧度模式直接使用原值。

## 6. 矩阵管线

MathLive 对 `bmatrix` 的类型检查可能阻止合法矩阵穿过 AST 转换，因此使用临时保护协议：

```text
bmatrix LaTeX
  → EngineService 包装 MWrap
  → Compute Engine 生成 AST
  → unwrapMWrap() 恢复矩阵节点
  → MatrixParser 转二维数组/Giac 指令
  → Giac 执行矩阵运算
```

[MatrixParser.cpp](../../entry/src/main/cpp/core/MatrixParser.cpp) 负责矩阵 AST 到二维结构及 Giac 指令的转换；[giac_bridge.cpp](../../entry/src/main/cpp/core/giac_bridge.cpp) 负责最终 CAS 调用。

## 7. SymEngine 与 Giac

### SymEngine

适合标准代数表达式、轻量符号处理和快速 LaTeX 输出。解析器优先构造 SymEngine 对象，以保持常规计算路径轻量。

### Giac

[giac_bridge.cpp](../../entry/src/main/cpp/core/giac_bridge.cpp) 使用全局单例上下文，处理：

- 符号积分、极限、求和和求积
- 方程与方程组
- det、rank、rref、eigenvalues 等矩阵运算
- GCD/LCM
- 复杂根式化简

符号积分失败时可降级为 Romberg 数值积分，并对结果区间取中值。

## 8. 精度与输出格式

`precision` 同时承担小数位数和特殊输出模式：

| 值 | 含义 | 处理 |
|----|------|------|
| `-1` | 自动/精确 | 整数原样；根式可经 Giac 化简；其余输出符号 LaTeX |
| `-2` | 最大小数 | `eval_double`，最多 16 位 |
| `-3` | 精确分数 | 强制偏好精确形式 |
| `-4` | 带分数 | `formatFraction()` |
| `-5` | 度分秒 | `formatDMS()` |
| `>= 0` | 指定小数位 | `formatFloat(precision)` |

[FormatUtils.cpp](../../entry/src/main/cpp/utils/FormatUtils.cpp) 还负责：

- 去除浮点尾零
- 超大整数转科学记数法
- 方程组结果美化
- 全局 LaTeX 清理与乘法符号统一
- SymEngine 到 Giac 的语法适配

## 9. 超大数

[FastMath.cpp](../../entry/src/main/cpp/utils/FastMath.cpp) 针对阶乘和巨大幂结果：

- 通过数量级判断 64 位溢出
- 计算阶乘对数量级
- 构建科学记数法代数节点
- 使用 `MAGICBASETEN` 幽灵变量携带精确基数

这样可以表示远超物理存储范围的结果，而不尝试展开全部数字。

## 10. 业务异常

[ErrorHandler.h](../../entry/src/main/cpp/core/ErrorHandler.h) 定义 `CalcException` 和前端错误映射：

| 错误码 | 前端消息 | 典型场景 |
|--------|----------|----------|
| `DIV_BY_ZERO` | `Error:DivByZero` | 除数为零 |
| `DOMAIN_ERROR` | `Error:Domain` | 非法定义域、负数阶乘 |
| `OVERFLOW_ERROR` | `Error:Overflow` | 超出可处理物理极限 |
| `SYNTAX_ERROR` | `Error:Syntax` | AST 或表达式语法错误 |
| `TIMEOUT_ERROR` | `Error:Timeout` | 计算超时或引擎拒绝 |
| `DMS_FORMAT_ERROR` | `Error:DMSFormat` | 度分秒格式非法 |

`engine.cpp` 在统一 try-catch 中转换异常，避免 C++ 细节泄漏到 UI。

## 11. 修改时的检查顺序

- 按键插入不正确：模块键盘 → InputTranslator → calculator.html。
- MathJSON 结构不正确：EngineService 清洗 → Compute Engine 输出 → parser。
- 常规结果错误：parser → engine 路由 → FormatUtils。
- 高级符号结果错误：Giac 指令构造 → giac_bridge。
- 矩阵错误：MWrap → MatrixParser → Giac。
- S⇄D 错误：FormulaScreen 保存的 AST → precision → FormatUtils。
