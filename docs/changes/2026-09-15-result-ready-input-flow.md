# 计算结果后的下一笔输入

- 状态：已完成
- 类型：功能、兼容性修复
- 分支：`feature/post-result-input-flow`
- 关联：[GitHub Issue #42](https://github.com/StartYR/CalculatorX/issues/42)
- 完成日期：2026-09-15

## 变更摘要

基础计算、科学计算和矩阵计算在成功计算后进入 `RESULT_READY` 状态。界面保留刚才的表达式与结果并让输入框失焦；用户随后可以从精确答案继续运算、开始一条新表达式，或返回原表达式继续编辑。

这项变更也修复了结果接续百分号时的 MathJSON 兼容问题。例如输入 `2+3=` 后按 `%` 会形成 `(5)%`，再次计算时会按百分数求值，不再返回 `Unknown_Error`。

## 用户可见行为

计算成功后，下一次操作按用途处理：

| 操作 | 行为 |
| --- | --- |
| 数字、常量、变量、函数、前置模板、`Ans`、历史回填 | 清除已完成的表达式与结果，开始新表达式 |
| `+`、`−`、`×`、`÷`、`mod`、`∘` 以及平方、幂、逆、阶乘、百分号等后缀操作 | 以括号包裹的精确 Ans 作为左操作数继续输入 |
| `AC` | 清空当前表达式与结果并恢复编辑，保留 Ans |
| 退格、方向键、撤销、重做、点击原表达式 | 回到原表达式继续编辑；退格使用计算前保留的光标位置 |
| `S⇄D` 及其长按选项 | 只切换结果显示形式，后续接续仍使用精确 Ans |
| 再次按 `=` | 重新计算当前表达式 |

计算失败时不会进入 `RESULT_READY`，用户仍可直接修改原表达式。

## 设计与实现

公式编辑器在 HTML 层维护 `EDITING` 和 `RESULT_READY` 两个状态，因为输入焦点、光标、点击和 MathLive 编辑命令都发生在这一层。成功结果通过 `completeCalculation()` 显示并进入结果就绪状态；普通结果显示仍使用 `showResult()`，供错误和格式转换路径调用。

ArkTS 层按输入语义传递三种行为：

- `EDIT_CURRENT`：继续编辑当前表达式；
- `START_NEW_EXPRESSION`：清除旧式后插入新内容；
- `CONTINUE_FROM_RESULT`：先插入括号包裹的 `lastAnsLatex`，再插入需要左操作数的按键内容。

`lastValidJson` 只在计算成功后保存。表达式变化或一次新计算开始时会立即清空，计算失败也不会留下可供 `S⇄D` 误用的旧 AST。历史记录的连续重复去重继续由 `HistoryRepository.insertRecord()` 在数据库层负责，界面层不增加第二套拦截。

MathLive 会把括号表达式后的 `%` 解析为带 `unexpected-command` 的 `Tuple`。`EngineService.unwrapMWrap()` 只在节点完整匹配该错误结构时将其转换为标准 `Percent` AST；普通 Tuple、其他解析错误和合法百分号节点保持原样。

## 兼容性与边界

- 新交互只在基础计算、科学计算和矩阵计算中启用。
- 方程求解和函数图像模式保持原有输入与执行语义。
- 结果接续使用实际的 `lastAnsLatex`，不依赖计算引擎识别字面量 `Ans`。
- 计算完成时只让输入框失焦，不移动光标；用户返回编辑时会回到先前位置。
- 本次没有调整键盘布局、公式区尺寸、历史数据库结构或 C++ 计算实现。

## 验证

- 已按阶段在设备上人工验证基础、科学和矩阵模式中的新式输入、结果接续、返回编辑、结果转换与重复计算，结果通过。
- 已针对百分号 AST 清洗检查 5 个应转换结构和 6 个不应转换结构，结果通过。
- 已通过 HTML 内联 JavaScript 语法检查和 `git diff --check`。
- 按项目规则未运行编译或构建；未对所有设备尺寸和系统版本组合进行覆盖测试。

## 主要文件

- [`FormulaScreen.ets`](../../entry/src/main/ets/components/FormulaScreen.ets)：模式开关、输入行为分类、Ans 接续以及结果状态数据管理。
- [`calculator.html`](../../entry/src/main/resources/rawfile/calculator.html)：编辑器状态、焦点恢复和三类输入行为的执行。
- [`EngineService.ets`](../../entry/src/main/ets/utils/EngineService.ets)：括号后缀百分号的严格 MathJSON 兼容转换。

## 发布说明素材

优化计算完成后的连续输入：基础、科学和矩阵模式现在会保留上一表达式与结果，数字或函数可直接开始下一笔，运算符和后缀操作可从上一答案继续计算，并支持返回原式编辑。同时修复了结果接续百分号可能出现 `Unknown_Error` 的问题。

[返回分支变更说明](README.md)
